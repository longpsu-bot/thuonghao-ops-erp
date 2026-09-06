# RMVP-02A Recipe and BOM API contract

## Shared envelope

All entry points accept one `request jsonb` and return `jsonb`. The contract version is `RMVP-02A.v1`.

Reads require `contract_version`, `requested_by_auth_subject`, `correlation_id`, and `payload`. Commands additionally require `command_id`, `idempotency_key`, positive `expected_version`, `requested_at`, `reason_code`, and `reason_note`.

The backend checks the authenticated subject against the requested subject, resolves an active Actor, capability, and global scope, and never trusts browser-supplied actor identity.

MASTER-DATA-CREATION-UX-02 aligns the shared command validator with RMVP-02B:
`requested_at <= transaction_timestamp() + interval '60 seconds'`.
The upper bound is inclusive. Invalid timestamps and offsets greater than 60
seconds return `VALIDATION_FAILED` on `requested_at`. Client timestamps, request
bytes, hashing, authorization, versions, and receipt/replay semantics are unchanged.

Successful commands return affected aggregate IDs, the new aggregate version, event IDs, audit IDs, authoritative workbench readback, warnings, blockers, and a safe operator message. Safe errors include an error code, message, retryability, field errors, blocking references, and actual version where relevant.

## Read

### `get_dish_recipe_workbench`

- Capability: `master_data.recipes.read`
- Owner: `atlas_read_runtime`
- Returns a nested `workbench` with the Dish Type catalog; Dishes with `dish_type_id`, resolved type code, and resolved type name; Recipe roots; Recipe Versions and compositions; active/inactive School Type references; Ingredient references; and Unit references.
- It never exposes private relations directly.

## Dish and Recipe-root commands

| Command                | Capability                  | Expected version | Effect                                                                                                       |
| ---------------------- | --------------------------- | ---------------: | ------------------------------------------------------------------------------------------------------------ |
| `create_dish`          | `master_data.recipes.write` |              `1` | Atomically creates one `ACTIVE` Dish and its two active canonical typed Recipe roots, with no RecipeVersion. |
| `update_dish`          | `master_data.recipes.write` |     Dish version | Updates bounded Dish attributes and active `dish_type_id`; stable code is immutable and there is no delete.  |
| `set_dish_lifecycle`   | `master_data.recipes.write` |     Dish version | Applies an allowed Dish lifecycle transition.                                                                |
| `set_recipe_lifecycle` | `master_data.recipes.write` |   Recipe version | Activates or inactivates a Recipe root without rewriting history.                                            |

## Recipe Version and BOM commands

| Command                               | Capability                     |              Expected version | Effect                                                                          |
| ------------------------------------- | ------------------------------ | ----------------------------: | ------------------------------------------------------------------------------- |
| `create_recipe_draft`                 | `master_data.recipes.write`    |                  Dish version | Creates the first general or School Type Recipe Version draft.                  |
| `create_recipe_successor_version`     | `master_data.recipes.write`    | source Recipe Version version | Creates a successor draft with exact version and line predecessors.             |
| `replace_recipe_draft_composition`    | `master_data.recipes.write`    |        Recipe Version version | Atomically replaces the complete draft basis and line set.                      |
| `validate_recipe_version`             | `master_data.recipes.validate` |        Recipe Version version | Materializes immutable Recipe Line Revisions and marks the version `VALIDATED`. |
| `release_recipe_version_for_planning` | `master_data.recipes.release`  |        Recipe Version version | Releases validated composition and locks the prior release.                     |
| `copy_recipe_version`                 | `master_data.recipes.write`    |           target Dish version | Copies one materialized Recipe Version for controlled/support callers.          |

Draft replacement accepts at most 500 lines. `PRESENT` requires an active Ingredient, active Unit, and positive exact numeric quantity. `REMOVED` requires the exact predecessor revision, predecessor Ingredient and Unit, and zero quantity. Every previously present predecessor line must be retained or explicitly removed.

Copy accepts only validated, released, or locked materialized source composition. It never copies a mutable draft and never validates or releases the target automatically.

### `copy_dish_recipes` — normal Dish-level copy

- Contract: `RECIPE-EFFECTIVE.v1`.
- Capability: existing `master_data.recipes.write`; owner: `atlas_master_data_command_runtime`.
- Required command payload: `source_dish_id`, `target_dish_id`, and explicit `as_of_date`; the standard command envelope also requires caller-stable `command_id`, `idempotency_key`, target Dish `expected_version`, timestamp, reason code, and nonblank reason note.
- Supported v1 scopes are identified only by the active School-Type codes `v1-school-type-1` and `v1-school-type-2`, evaluated in that deterministic order. Display names and capitalization are not identity.

For each supported scope, the backend requires the exact active typed Recipe root and exactly one current `RELEASED_FOR_PLANNING` Recipe Version. It resolves the source BOM at `as_of_date` through the closed system path `typed base Recipe -> SYSTEM_INGREDIENT -> SYSTEM_DISH`; it never applies `SCHOOL` or `SCHOOL_DISH`. A nullable GENERAL Recipe is never a fallback for this contract. Both source scopes must be `READY`, and both active typed target Recipe roots must already exist.

The outer command is the sole transactional authority. It materializes both resolved PRESENT BOMs into new DRAFT Recipe Versions under the two pre-provisioned target roots, preserves prior version/line history, emits explicit removed-line successors when needed, and records source Recipe, date, system-adjustment lineage, outer command, and reason provenance. It does not invoke the retained support-level `copy_recipe_version` command and never copies source adjustment rows as target facts. Any missing scope, unfinished conflicting target version, reference failure, or write failure rolls back both scopes. Approved-Menu use of the target Dish returns the existing operational-lock rejection before writes. Exact replay returns the stored authoritative result; reusing an idempotency key with changed request content returns `IDEMPOTENCY_CONFLICT`.

`dish_type_id` is authoritative for Menu eligibility. Create/update rejects an unknown or inactive type. Normal creation acquires a normalized-name transaction lock, and the partial unique index remains the final race-safe guard against duplicate active Dish names. The support lifecycle command also requires an active mapped type when activating a historical row. `dish_category` remains optional compatibility text and is never interpreted as the authoritative type.

## Workbook import command

### `apply_recipe_import`

- Capability: `master_data.recipes.import`
- Owner: `atlas_master_data_command_runtime`
- Payload: `canonical_json` and lowercase 64-character `workbook_checksum`
- Maximum: 5,000 canonical BOM rows and 2,000,000 canonical JSON characters
- Effect: one atomic, draft-only import with typed reconciliation evidence

The command verifies SHA-256, source identities, uniqueness, scope consistency, positive basis/quantity, and existing active School Type, Ingredient, and Unit references. Missing references, duplicate stable identities, or reconciliation mismatch reject without partial target writes. An identical completed checksum returns `REPLAYED_IMPORT` with zero inserts or updates.

## Safe error catalogue

The bounded public errors include:

- `VALIDATION_FAILED`
- `AUTH_SUBJECT_MISMATCH`
- `ACTOR_NOT_FOUND`
- `ACTOR_INACTIVE`
- `CAPABILITY_DENIED`
- `SCOPE_DENIED`
- `NOT_FOUND`
- `STALE_VERSION`
- `CONFLICT`
- `INVARIANT_VIOLATION`
- `IDEMPOTENCY_KEY_REUSED`
- `RETRYABLE_CONCURRENCY_FAILURE`
- `INTERNAL_COMMAND_FAILURE`
- `INTERNAL_READ_FAILURE`

No response returns credentials, SQL text, private row dumps, or an exception stack.

## Business-only Dish creation amendment

Normal `create_dish` calls supply `dish_name`, active `dish_type_id`, and optional
`dish_category` and `operational_notes`. The connected Atlas form neither exposes
nor submits `dish_code`, `display_order`, or `requires_need_generation`.

The operational-note label explicitly says `Ghi chú vận hành (không bắt buộc)`.
Blank notes remain valid; they do not block Dish creation.

For omitted keys, the v1 backend generates `dish-` followed by a complete random
UUID, defaults `display_order` to `0`, and defaults `requires_need_generation` to
`true`. Code generation happens after authorization and idempotency replay
resolution. The existing unique code constraint protects the persisted code;
replaying creation returns the original Dish identity and code readback. The code
does not derive from the editable Dish name. Explicit invalid/null metadata is
still rejected rather than interpreted as omission.

After authorization and replay resolution, creation resolves the active canonical
School Types by stable code, transaction-locks their canonical identities, and
inserts the Dish plus exactly one active Recipe root for each code in the same
transaction. A missing/inactive canonical type or either root-insert failure rolls
back the entire creation. No RecipeVersion is created. Successful
`affected_aggregate_ids` includes the Dish ID and an ordered `recipe_ids` array
with each `school_type_id`, `school_type_code`, and server-generated `recipe_id`.
The exactly-two invariant applies to newly command-created Dishes and Dishes
treated as valid by `RECIPE-EFFECTIVE.v1`; this change does not add a global
constraint or rewrite legacy rows.

Controlled callers may continue supplying normalized unique codes and valid
ordering and explicit `requires_need_generation: true`. Explicit false returns
`VALIDATION_FAILED` with `payload.requires_need_generation` field feedback; it is
never silently coerced. Local RMVP-02A, RMVP-02B, and Planning assembly verifiers
retain the explicit-code path. The historical column remains stored, but it is
non-authoritative for demand participation; existing values are not rewritten.

Normal creation persists the Dish as `ACTIVE` at version 1 and creates both
canonical roots without creating a RecipeVersion. Initial and later Recipe Saves
author RecipeVersion evidence only: they do not change Dish status, increment the
Dish version, or emit `DishActivated`. Historical `DRAFT` remains schema-compatible
for controlled support; normal authoring does not depend on a DRAFT-to-ACTIVE
transition. `INACTIVE` is support/archive availability, not a Recipe editing
state. Newly created active Dishes participate in Need Generation only when used
on an approved Menu with a valid released Recipe. Committed sources retain
explicit inactive-Dish blockers and correction behavior, never silent demand
removal.

For `RECIPE-EFFECTIVE.v1`, the canonical typed root is also the base-authoring
context. An unlocked root with no RecipeVersion, a DRAFT or VALIDATED version, or
an unlocked released version remains `EDITABLE_BASE`; strict effective readiness
is not a prerequisite for first-time authoring. Once approved-Menu evidence locks
the Dish, the state is `LOCKED_CHANGE_ORDER` and the strict typed selector must be
`READY` before Change Order creation is advertised. Legacy nullable GENERAL or
synthetic Recipe rows remain pre-cutover compatibility evidence and are ignored by
the new contract until separately remediated.

This is a derived operator model: the authoritative Dish remains `ACTIVE` in
both editable and locked states. Recipe readiness comes from released typed
Recipe evidence, while editability comes only from
`atlas_core.uiq03a_dish_used_operationally(dish_id)` and approved Weekly Menu
evidence. There is no persisted readiness or Recipe-lock flag and no normal
Activate/Deactivate UI dependency.

## Additive RMVP-02A.v2 creation-and-lock contract

D-038 preserves every v1 entry point above and adds the physically callable functions:

```text
atlas_api.save_recipe(request jsonb)
atlas_api.release_recipe(request jsonb)
```

The v2 command envelope retains authenticated/requested-subject match, command/correlation/idempotency identifiers, positive current `expected_version`, timestamp, and fixed reason code. Normal React creation invokes only `save_recipe`; `release_recipe` is retained for compatibility/support.

### V2 workbench selection and lock readback

A v1 `get_dish_recipe_workbench` request keeps the v1 shape. A v2 payload accepts only optional `dish_id` and `school_type_id` and adds:

```json
{
  "selected_recipe": {
    "dish_id": "uuid",
    "school_type_id": null,
    "recipe_id": "uuid-or-null",
    "recipe_version_id": "uuid-or-null",
    "expected_version": 4,
    "in_use_recipe_version_id": "uuid-or-null",
    "business_status": "NOT_SAVED|SAVED|AVAILABLE|LOCKED|NEEDS_ATTENTION",
    "locked_for_normal_editing": true,
    "lock_reason": "Món này đã có trong thực đơn đã duyệt. Muốn thay đổi công thức, hãy dùng Điều chỉnh.",
    "basis_portions": 100,
    "composition": [],
    "allowed_actions": {
      "save_recipe": false,
      "release_recipe": false
    },
    "disabled_reason_codes": {
      "save_recipe": "SAVE_OPERATIONALLY_LOCKED",
      "release_recipe": "RELEASE_ALREADY_IN_USE"
    },
    "disabled_reasons": {
      "save_recipe": "Món này đã có trong thực đơn đã duyệt. Muốn thay đổi công thức, hãy dùng Điều chỉnh.",
      "release_recipe": "Công thức đã sẵn sàng cho Lập nhu cầu."
    }
  }
}
```

`locked_for_normal_editing` is true exactly when the Dish exists in immutable `atlas_planning.weekly_menu_approval_snapshot_lines`. This approved-Menu commitment evidence is the Atlas equivalent of the retained OPS v1 order-use trigger. Recipe creation, Save, validation, and release do not set the approved-Menu lock.

Eligibility also resolves active Actor, exact capability and active `GLOBAL` scope, Dish/Recipe/reference lifecycle, and current version. React may restrict backend `true` for local invalid, dirty, busy, or unknown-outcome state; it may never promote backend `false`.

### `save_recipe`

- Capability: `master_data.recipes.write`.
- Payload: exact `dish_id`, nullable `school_type_id`, nullable/current `recipe_version_id`, positive integer `basis_portions`, and complete present `lines`.
- Each line has stable target `recipe_line_id`, active `ingredient_id`, positive exact `quantity_per_basis`, active `unit_id`, and nullable `operational_note`; maximum 500; duplicate line or Ingredient identity fails closed.
- The function locks the Dish, rechecks committed approved-Menu use, and returns `INVARIANT_VIOLATION` with the safe Change-Order direction before any Recipe/version/line mutation after that commitment.
- For a pre-commit Dish, it creates/reuses the Recipe scope, preserves exact predecessor lineage and explicit removed-line evidence when advancing internal versions, materializes immutable line revisions, and releases the saved composition for future Planning atomically.
- Success readback reports `business_status: AVAILABLE`, `locked_for_normal_editing: false`, `released_for_planning: true`, and `operationally_used: false`.
- Save is idempotent, concurrency checked, and never recalculates historical Planning evidence.

### `release_recipe`

- Capability: `master_data.recipes.release`.
- Physical v2 compatibility/support entry point; it is absent from the normal application workflow.
- Retains currentness, deterministic validation/materialization, release, receipt, event, audit, and immutable-history guarantees for controlled callers.
- Does not define committed approved-Menu use and does not set the approved-Menu lock.

Both v2 commands use fixed empty `search_path`, least-privilege runtime ownership, safe errors, and no automatic browser retry after an unknown transport result. Every RMVP-02A.v1 API remains callable.

### Dish-wide lock coverage

The single canonical predicate is `atlas_core.uiq03a_dish_used_operationally(uuid)`. Weekly Menu approval and every relevant base Recipe/BOM mutation acquire the same deterministic transaction lock before the snapshot or mutation decision. Once the predicate is true, `create_recipe_draft`, `create_recipe_successor_version`, `replace_recipe_draft_composition`, `validate_recipe_version`, `release_recipe_version_for_planning`, `save_recipe`, `release_recipe`, `copy_recipe_version`, `copy_dish_recipes`, and any `apply_recipe_import` scope targeting that Dish return `INVARIANT_VIOLATION` with the safe Điều chỉnh direction before business writes.

`update_dish`, the support/legacy `set_dish_lifecycle`, and `set_recipe_lifecycle` are not part of this generic composition lock. They retain the bounded metadata and lifecycle semantics, capability checks, optimistic concurrency, lifecycle validation, event, audit, and immutable-history guarantees already accepted in RMVP-02A.v1. Normal Recipe UI does not depend on Dish lifecycle controls. The application still exposes no ordinary editing of existing catalog records, and this correction adds no Dish metadata Change Order. RMVP-02B adjustment APIs remain unchanged.
