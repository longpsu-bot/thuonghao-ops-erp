# RMVP-02B Recipe adjustment and effective BOM API

## Shared envelope

All entry points are `atlas_api` functions accepting one `request jsonb` and returning `jsonb`. The contract is `RMVP-02B.v1`.

Reads require `contract_version`, `requested_by_auth_subject`, `correlation_id`, and `payload`. Commands additionally require `command_id`, `idempotency_key`, positive `expected_version`, `requested_at`, `reason_code`, and a required `reason_note`.

The authenticated JWT subject must equal `requested_by_auth_subject`. The backend resolves the active Actor, capability, and global scope; browser-supplied actor identity is never authoritative.

Success returns the contract/correlation identity, shaped result or authoritative readback, safe operator message, warnings, and blockers. Command success also returns command, affected aggregate, version, domain-event, audit-event, and idempotency evidence.

## Reads

### `get_recipe_adjustment_workbench`

- Capability: `master_data.recipe_adjustments.read`
- Owner: `atlas_read_runtime`
- Returns the closed scope/action catalog, precedence, Schools, Dishes, School Types, Ingredients, Units, stable Recipe Line references, adjustment roots, and ordered revision lineage.

### `resolve_effective_recipe_composition`

- Capability: `master_data.recipe_adjustments.read`
- Owner: `atlas_read_runtime`
- Required payload: `as_of_date`, `school_id`, `dish_id`
- Optional support payload: `historical_recipe_version_id`
- Returns `resolution` with status, exact context, historical label, selected Recipe evidence, atomic effective lines, warnings, and blockers.

Current authority always selects the exact School Type release before the general release and never accepts a caller-selected version. An explicitly named historical version is support-only and visibly warned.

### `preview_recipe_composition_adjustment`

- Capability: `master_data.recipe_adjustments.write`
- Owner: `atlas_read_runtime`
- Required payload: `as_of_date`, `dish_id`, `proposed_adjustment`
- Context payload: `school_id` when the proposal or operator outcome is School-specific
- Optional correction payload: `replaces_adjustment_id`
- Returns `preview` containing the normalized proposal, current `before`, hypothetical `after`, affected-line count, `can_save`, warnings, and blockers.
- Effect: no write.

## Proposal contract

Every proposal includes stable `adjustment_id`, stable `revision_id`, `scope_kind`, `action_kind`, `effective_from`, optional half-open `effective_to`, reason evidence, and the typed fields required by its scope/action.

| Scope/action                  | Required typed payload                                                                                                                   |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `SYSTEM_INGREDIENT/REPLACE`   | `target_ingredient_id`, `substitute_ingredient_id`                                                                                       |
| `SYSTEM_DISH/ADD`             | `dish_id`, optional `school_type_id`, `target_ingredient_id`, `adjustment_line_id`, positive `quantity_per_basis`, `unit_id`             |
| `SYSTEM_DISH/REPLACE`         | `dish_id`, optional `school_type_id`, `target_recipe_line_id`, `substitute_ingredient_id`; optional positive quantity plus explicit Unit |
| `SYSTEM_DISH/ADJUST_QUANTITY` | `dish_id`, optional `school_type_id`, `target_recipe_line_id`, positive `quantity_per_basis`                                             |
| `SYSTEM_DISH/REMOVE`          | `dish_id`, optional `school_type_id`, `target_recipe_line_id`                                                                            |
| `SCHOOL/REPLACE`              | `school_id`, `target_ingredient_id`, `substitute_ingredient_id`                                                                          |
| `SCHOOL/REMOVE`               | `school_id`, `target_ingredient_id`                                                                                                      |
| `SCHOOL_DISH/ADD`             | `school_id`, `dish_id`, `target_ingredient_id`, `adjustment_line_id`, positive `quantity_per_basis`, `unit_id`                           |
| `SCHOOL_DISH/REPLACE`         | `school_id`, `dish_id`, `target_recipe_line_id`, `substitute_ingredient_id`; optional positive quantity plus explicit Unit               |
| `SCHOOL_DISH/ADJUST_QUANTITY` | `school_id`, `dish_id`, `target_recipe_line_id`, positive `quantity_per_basis`                                                           |
| `SCHOOL_DISH/REMOVE`          | `school_id`, `dish_id`, `target_recipe_line_id`                                                                                          |

Omitted fields must be null. `REPLACE` preserves quantity and Unit unless both a positive quantity and explicit Unit are supplied. `ADJUST_QUANTITY` preserves Ingredient and Unit. `REMOVE` accepts no substitute, quantity, or Unit. All referenced master data must be active.

## Commands

### `create_recipe_composition_adjustment`

- Capability: `master_data.recipe_adjustments.write`
- Owner: `atlas_master_data_command_runtime`
- Expected version: `1`
- Payload: proposal fields plus required `as_of_date`, `preview_school_id`, and `preview_dish_id`
- Effect: serializes the exact typed target, revalidates the preview context, resolves the hypothetical effective composition, creates one stable root and revision 1, then emits event/audit/readback.

An exact request replay returns the original completed receipt. A reused idempotency key with different content fails closed.

### `supersede_recipe_composition_adjustment`

- Capability: `master_data.recipe_adjustments.write`
- Owner: `atlas_master_data_command_runtime`
- Expected version: current root version
- Required payload: `adjustment_id`, new `revision_id`, exact `predecessor_revision_id`, `effective_from`, optional `effective_to`, action payload, `as_of_date`, `preview_school_id`, `preview_dish_id`
- Effect: serializes the exact typed target, then locks the root, verifies the exact current active predecessor, validates and resolves the successor, appends the next revision, and increments the root version.

Scope, action, and stable target identity cannot change. One predecessor can have only one successor.

### `cancel_recipe_composition_adjustment`

- Capability: `master_data.recipe_adjustments.cancel`
- Owner: `atlas_master_data_command_runtime`
- Expected version: current root version
- Required payload: `adjustment_id`, new `revision_id`, exact `predecessor_revision_id`, `effective_from`
- Effect: appends a dated `CANCELLED` revision, preserves every prior row, and increments the root version.

The cancellation date must be within the current effective period. Earlier dates continue to resolve the prior applicable revision; dates from cancellation onward omit that rule.

## Safe blockers and errors

Business blockers include invalid scope/action or typed target, invalid half-open period, inactive or missing reference, overlapping exact target, self-replacement, ambiguous or missing Recipe selection, stale Recipe Line target, ambiguous replacement, cycle, and duplicate final Ingredient.

Public error codes include `VALIDATION_FAILED`, `AUTH_SUBJECT_MISMATCH`, `ACTOR_NOT_FOUND`, `ACTOR_INACTIVE`, `CAPABILITY_DENIED`, `SCOPE_DENIED`, `NOT_FOUND`, `STALE_VERSION`, `CONFLICT`, `INVARIANT_VIOLATION`, `IDEMPOTENCY_CONFLICT`, `RETRYABLE_CONCURRENCY_FAILURE`, `INTERNAL_COMMAND_FAILURE`, and `INTERNAL_READ_FAILURE`.

Responses never expose credentials, SQL, private relation dumps, or exception stacks.

## Additive operator read — `RMVP-02B.v2`

### `get_recipe_adjustment_operator_workbench`

- Capability: `master_data.recipe_adjustments.read`
- Owner: `atlas_read_runtime`
- Required envelope contract: `RMVP-02B.v2`
- Required payload: explicit `as_of_date`; the function does not use `CURRENT_DATE`
- Compatibility: all six `RMVP-02B.v1` functions above remain unchanged and callable

The response retains the approved scope/action catalog, precedence and human-reference catalogs needed by the Application. In `RMVP-02B.v2` only, each Ingredient catalog entry also exposes its configured `purchase_unit_id` and `purchase_unit_name`; the v1 read shape is unchanged. Released Recipe lines are shaped with current Ingredient name, quantity and Unit so operators can select by business meaning rather than stable identity. The Application preserves a selected Recipe line's historical Unit, derives ADD and quantity-bearing REPLACE Units from the selected Ingredient purchase Unit, and blocks preview when that required master-data Unit is missing.

`operator_rows` returns one narrow row per stable adjustment with internal IDs and optimistic version for the existing commands, the frozen scope/action identity, a display revision, an authoritative content revision, the exact current command revision, ordered immutable business history, issuance provenance and one server-derived `temporal_state`. For a cancelled root, `display_revision` remains the cancellation evidence while `content_revision` is the latest preceding non-cancellation revision whose business payload was cancelled; React does not infer this lineage.

- `ACTIVE`
- `SCHEDULED`
- `ACTIVE_CHANGE_SCHEDULED`
- `ACTIVE_CANCELLATION_SCHEDULED`
- `ACTIVE_RESUMED`
- `EXPIRED`
- `CANCELLED`

`temporal_state_date` supplies the scheduled first-effect, correction or cancellation date when relevant. React maps these states to Vietnamese operator labels but does not reconstruct temporal applicability from root lifecycle and revision dates.

Native issuance uses the relevant immutable revision `created_at` and Actor display name. A revision imported without original OPS v1 attribution returns `issuance_kind: LEGACY_UNATTRIBUTED`, `issued_at: null`, and a null issuer name. The Atlas import timestamp is not represented as business issuance, and the Atlas importer is not represented as the original business issuer.
