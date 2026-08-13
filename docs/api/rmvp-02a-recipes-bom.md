# RMVP-02A Recipe and BOM API contract

## Shared envelope

All entry points accept one `request jsonb` and return `jsonb`. The contract version is `RMVP-02A.v1`.

Reads require `contract_version`, `requested_by_auth_subject`, `correlation_id`, and `payload`. Commands additionally require `command_id`, `idempotency_key`, positive `expected_version`, `requested_at`, `reason_code`, and `reason_note`.

The backend checks the authenticated subject against the requested subject, resolves an active Actor, capability, and global scope, and never trusts browser-supplied actor identity.

Successful commands return affected aggregate IDs, the new aggregate version, event IDs, audit IDs, authoritative workbench readback, warnings, blockers, and a safe operator message. Safe errors include an error code, message, retryability, field errors, blocking references, and actual version where relevant.

## Read

### `get_dish_recipe_workbench`

- Capability: `master_data.recipes.read`
- Owner: `atlas_read_runtime`
- Returns a nested `workbench` with the Dish Type catalog; Dishes with `dish_type_id`, resolved type code, and resolved type name; Recipe roots; Recipe Versions and compositions; active/inactive School Type references; Ingredient references; and Unit references.
- It never exposes private relations directly.

## Dish and Recipe-root commands

| Command                | Capability                  | Expected version | Effect                                                                                                      |
| ---------------------- | --------------------------- | ---------------: | ----------------------------------------------------------------------------------------------------------- |
| `create_dish`          | `master_data.recipes.write` |              `1` | Creates one `DRAFT` Dish with unique normalized code and active `dish_type_id`.                             |
| `update_dish`          | `master_data.recipes.write` |     Dish version | Updates bounded Dish attributes and active `dish_type_id`; stable code is immutable and there is no delete. |
| `set_dish_lifecycle`   | `master_data.recipes.write` |     Dish version | Applies an allowed Dish lifecycle transition.                                                               |
| `set_recipe_lifecycle` | `master_data.recipes.write` |   Recipe version | Activates or inactivates a Recipe root without rewriting history.                                           |

## Recipe Version and BOM commands

| Command                               | Capability                     |              Expected version | Effect                                                                          |
| ------------------------------------- | ------------------------------ | ----------------------------: | ------------------------------------------------------------------------------- |
| `create_recipe_draft`                 | `master_data.recipes.write`    |                  Dish version | Creates the first general or School Type Recipe Version draft.                  |
| `create_recipe_successor_version`     | `master_data.recipes.write`    | source Recipe Version version | Creates a successor draft with exact version and line predecessors.             |
| `replace_recipe_draft_composition`    | `master_data.recipes.write`    |        Recipe Version version | Atomically replaces the complete draft basis and line set.                      |
| `validate_recipe_version`             | `master_data.recipes.validate` |        Recipe Version version | Materializes immutable Recipe Line Revisions and marks the version `VALIDATED`. |
| `release_recipe_version_for_planning` | `master_data.recipes.release`  |        Recipe Version version | Releases validated composition and locks the prior release.                     |
| `copy_recipe_version`                 | `master_data.recipes.write`    |           target Dish version | Copies materialized composition into a traceable target draft.                  |

Draft replacement accepts at most 500 lines. `PRESENT` requires an active Ingredient, active Unit, and positive exact numeric quantity. `REMOVED` requires the exact predecessor revision, predecessor Ingredient and Unit, and zero quantity. Every previously present predecessor line must be retained or explicitly removed.

Copy accepts only validated, released, or locked materialized source composition. It never copies a mutable draft and never validates or releases the target automatically.

`dish_type_id` is authoritative for Menu eligibility. Create/update rejects an unknown or inactive type. Dish activation also requires an active mapped type. `dish_category` remains optional compatibility text and is never interpreted as the authoritative type.

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

The single canonical predicate is `atlas_core.uiq03a_dish_used_operationally(uuid)`. Weekly Menu approval and every relevant base Recipe/BOM mutation acquire the same deterministic transaction lock before the snapshot or mutation decision. Once the predicate is true, `create_recipe_draft`, `create_recipe_successor_version`, `replace_recipe_draft_composition`, `validate_recipe_version`, `release_recipe_version_for_planning`, `save_recipe`, `release_recipe`, `copy_recipe_version`, and any `apply_recipe_import` scope targeting that Dish return `INVARIANT_VIOLATION` with the safe Điều chỉnh direction before business writes.

`update_dish`, `set_dish_lifecycle`, and `set_recipe_lifecycle` are not part of this generic composition lock. They retain the bounded metadata and lifecycle semantics, capability checks, optimistic concurrency, lifecycle validation, event, audit, and immutable-history guarantees already accepted in RMVP-02A.v1. The application still exposes no ordinary editing of existing catalog records, and this correction adds no Dish metadata Change Order. RMVP-02B adjustment APIs remain unchanged.
