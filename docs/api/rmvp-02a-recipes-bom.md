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

## Additive RMVP-02A.v2 operator contract

D-038 preserves every v1 entry point above and adds exactly:

```text
atlas_api.save_recipe(request jsonb)
atlas_api.release_recipe(request jsonb)
```

The v2 command envelope uses the shared identifiers, current positive `expected_version`, authenticated/requested subject match, timestamp, and idempotency key. `reason_note` is `null`; the exact reason codes are `RECIPE_SAVED` and `RECIPE_PUT_INTO_USE`.

### V2 workbench selection and eligibility

`get_dish_recipe_workbench` remains one physical function. A v1 request returns its unchanged v1 shape. A v2 request payload accepts only optional `dish_id` and `school_type_id` and returns the normal v1 catalogs/history plus:

```json
{
  "selected_recipe": {
    "dish_id": "uuid",
    "school_type_id": null,
    "recipe_id": "uuid-or-null",
    "recipe_version_id": "uuid-or-null",
    "expected_version": 2,
    "in_use_recipe_version_id": "uuid-or-null",
    "business_status": "NOT_SAVED|SAVED|IN_USE|NEEDS_ATTENTION",
    "basis_portions": 100,
    "composition": [],
    "allowed_actions": {
      "save_recipe": true,
      "release_recipe": false
    },
    "disabled_reason_codes": {
      "save_recipe": null,
      "release_recipe": "RELEASE_SAVE_REQUIRED"
    },
    "disabled_reasons": {
      "save_recipe": null,
      "release_recipe": "Hãy lưu công thức trước khi đưa vào sử dụng."
    }
  }
}
```

Eligibility resolves the active Actor, exact capability and active `GLOBAL` scope, Dish/Recipe/reference lifecycle, current saved version, and release-ready composition. React may change `true` to `false` for local dirty/invalid/busy/unknown state; it may never promote backend `false`.

### `save_recipe`

- Capability: `master_data.recipes.write`.
- Payload keys: exact `dish_id`, nullable `school_type_id`, nullable/current `recipe_version_id`, positive integer `basis_portions`, and the complete present `lines` array.
- Each line contains stable `recipe_line_id`, active `ingredient_id`, positive exact `quantity_per_basis`, active `unit_id`, and nullable `operational_note`.
- Maximum 500 submitted lines; duplicate stable line or Ingredient identities fail closed.
- No existing Recipe: create root and editable first draft, then store the complete composition.
- Existing editable draft: replace its complete composition and preserve currentness.
- Released current Recipe: create the correct successor internally, map exact predecessor Recipe Line Revisions, retain omitted predecessor lines as explicit `REMOVED` draft evidence, and preserve the prior release unchanged.
- Success returns `authoritative_readback`; after-summary explicitly records `released_for_planning: false`.

### `release_recipe`

- Capability: `master_data.recipes.release`; `master_data.recipes.validate` remains a distinct v1 compatibility/internal capability and is not additionally required from the human caller.
- Payload key: exact current saved `recipe_version_id`.
- Rechecks current version, latest-version currentness, active Dish/Recipe, active Ingredient/Unit references, positive quantities, required non-empty composition, and exact predecessor coverage.
- If the saved version is a draft, atomically materializes immutable Recipe Line Revisions and deterministic validation evidence before release.
- Releases the current Recipe for future Planning and locks the prior effective Recipe under retained integrity rules.
- Returns `effect: FUTURE_PLANNING_REFERENCE_ONLY` and `historical_planning_recalculated: false`.

Both commands use existing command receipts, idempotent replay, Admin domain/audit events, fixed empty `search_path`, least-privilege runtime ownership, stale-version failure, and no automatic browser retry after an unknown transport outcome.
