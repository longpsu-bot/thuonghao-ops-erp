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
