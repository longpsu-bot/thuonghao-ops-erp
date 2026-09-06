# RMVP-02B Recipe adjustment and effective BOM API

## Shared envelope

All entry points are `atlas_api` functions accepting one `request jsonb` and returning `jsonb`. The contract is `RMVP-02B.v1`.

Reads require `contract_version`, `requested_by_auth_subject`, `correlation_id`, and `payload`. Commands additionally require `command_id`, `idempotency_key`, positive `expected_version`, `requested_at`, `reason_code`, and a required `reason_note`.

The authenticated JWT subject must equal `requested_by_auth_subject`. The backend resolves the active Actor, capability, and global scope; browser-supplied actor identity is never authoritative.

Create, Supersede, and Cancel share `atlas_core.rmvp_02b_validate_command_request`.
Its timestamp upper bound is inclusive:
`requested_at <= transaction_timestamp() + interval '60 seconds'`.
This permits small positive browser clock skew, matching the established Planning
and Purchase Handoff policy. Invalid timestamps and timestamps beyond that bound
remain `VALIDATION_FAILED` on `requested_at`. All other envelope, reason,
authorization, version, predecessor, and receipt rules remain unchanged. The
browser sends its original timestamp; the established request hash continues to
exclude `requested_at` and correlation identity.

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

### Additive `RECIPE-EFFECTIVE.v1` reads

All three reads require `contract_version: RECIPE-EFFECTIVE.v1`, `requested_by_auth_subject`, `correlation_id`, and an explicit payload. They use the existing `master_data.recipe_adjustments.read` capability, are owned by `atlas_read_runtime`, have fixed empty `search_path`, and expose no private relations.

| Function                                      | Required payload                          | Shaped result                                                                                                                                                                                                   |
| --------------------------------------------- | ----------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `resolve_system_effective_recipe_composition` | `as_of_date`, `dish_id`, `school_type_id` | `resolution` using the exact canonical typed Recipe selector and only `SYSTEM_INGREDIENT` then `SYSTEM_DISH`; no nullable GENERAL fallback, representative School, or School layer.                             |
| `get_recipe_effective_target_context`         | date, Dish, exactly one context identity  | `target_context` with selected Recipe, basis, warnings/blockers, and PRESENT effective lines containing names, quantity, Unit, source layer, `target_kind`, `target_id`, and the corresponding stable identity. |
| `get_dish_recipe_operator_workbench`          | date, Dish, exactly one context identity  | Dish/name/type, context, selected base Recipe and basis, lock state, current effective BOM, school-exception count, actions, blockers/warnings, and backend-shaped full-BOM `history_periods`.                  |

The exclusive context identity is `school_type_id` for a system view or `school_id` for a School view. Both or neither returns `VALIDATION_FAILED`. The School path derives School Type from the authoritative School. The shared selector accepts only active canonical codes `v1-school-type-1` and `v1-school-type-2`, requires the exact typed active root and released version, and returns a blocker rather than reading a nullable GENERAL Recipe. System resolution applies only system layers; School resolution applies the same system layers followed by `SCHOOL` and `SCHOOL_DISH`. React consumes the shaped result and does not select a Recipe, infer a date, or replay revisions.

The operator workbench separates `base_authoring` from `effective_readiness`.
Unlocked canonical roots remain `EDITABLE_BASE` through no-version, DRAFT,
VALIDATED, and released authoring states. Approved-Menu use produces
`LOCKED_CHANGE_ORDER`; that read-only path requires a `READY` released typed
Recipe before `CREATE_CHANGE_ORDER` is offered. `school_exception_count` counts
distinct currently applicable `SCHOOL` or `SCHOOL_DISH` roots whose identities
materially occur in resolver lineage for the selected Dish context, not every
adjustment associated with a School of the same type.

The Dish-copy command requires an explicit `as_of_date`, resolves both canonical
typed scopes through only `SYSTEM_INGREDIENT` and `SYSTEM_DISH`, and snapshots the
result into the two existing target roots without overwriting RecipeVersion
history. School-specific layers are excluded. Nullable GENERAL and synthetic
legacy Recipes remain isolated behind the pre-existing RMVP-02B compatibility
resolver and are never selected by `RECIPE-EFFECTIVE.v1`.

### `preview_recipe_composition_adjustment`

- Capability: `master_data.recipe_adjustments.write`
- Owner: `atlas_read_runtime`
- Required payload: `as_of_date`, `dish_id`, `proposed_adjustment`
- Context payload for `SYSTEM_DISH`: exact active canonical `school_type_id`; `school_id` must be absent or null
- Context payload for `SYSTEM_INGREDIENT`, `SCHOOL`, and `SCHOOL_DISH`: existing explicit `school_id` impact-preview context
- Optional correction payload: `replaces_adjustment_id`
- Returns `preview` containing the normalized proposal, current `before`, hypothetical `after`, affected-line count, `can_save`, warnings, and blockers.
- Effect: no write.

For `SYSTEM_DISH`, the proposal's `dish_id` and `school_type_id` must exactly match the outer reviewed context. Preview resolves the exact typed released Recipe followed by `SYSTEM_INGREDIENT` and `SYSTEM_DISH` only. It does not select or accept a representative School, apply a School layer, or fall back to a nullable GENERAL Recipe. Both before and hypothetical after use this same system-only authority.

## Proposal contract

Every proposal includes stable `adjustment_id`, stable `revision_id`, `scope_kind`, `action_kind`, `effective_from`, optional half-open `effective_to`, reason evidence, and the typed fields required by its scope/action.

| Scope/action                  | Required typed payload                                                                                                                           |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| `SYSTEM_INGREDIENT/REPLACE`   | `target_ingredient_id`, `substitute_ingredient_id`                                                                                               |
| `SYSTEM_DISH/ADD`             | `dish_id`, canonical `school_type_id`, `target_ingredient_id`, `adjustment_line_id`, positive `quantity_per_basis`, `unit_id`                    |
| `SYSTEM_DISH/REPLACE`         | `dish_id`, canonical `school_type_id`, exactly one stable line target, `substitute_ingredient_id`; optional positive quantity plus explicit Unit |
| `SYSTEM_DISH/ADJUST_QUANTITY` | `dish_id`, canonical `school_type_id`, exactly one stable line target, positive `quantity_per_basis`                                             |
| `SYSTEM_DISH/REMOVE`          | `dish_id`, canonical `school_type_id`, exactly one stable line target                                                                            |
| `SCHOOL/REPLACE`              | `school_id`, `target_ingredient_id`, `substitute_ingredient_id`                                                                                  |
| `SCHOOL/REMOVE`               | `school_id`, `target_ingredient_id`                                                                                                              |
| `SCHOOL_DISH/ADD`             | `school_id`, `dish_id`, `target_ingredient_id`, `adjustment_line_id`, positive `quantity_per_basis`, `unit_id`                                   |
| `SCHOOL_DISH/REPLACE`         | `school_id`, `dish_id`, exactly one stable line target, `substitute_ingredient_id`; optional positive quantity plus explicit Unit                |
| `SCHOOL_DISH/ADJUST_QUANTITY` | `school_id`, `dish_id`, exactly one stable line target, positive `quantity_per_basis`                                                            |
| `SCHOOL_DISH/REMOVE`          | `school_id`, `dish_id`, exactly one stable line target                                                                                           |

Omitted fields must be null. `REPLACE` preserves quantity and Unit unless both a positive quantity and explicit Unit are supplied. `ADJUST_QUANTITY` preserves Ingredient and Unit. `REMOVE` accepts no substitute, quantity, or Unit. All referenced master data must be active.

For every non-ADD `SYSTEM_DISH` or `SCHOOL_DISH` proposal, “exactly one stable line target” means XOR: `target_recipe_line_id` for a base Recipe line or `adjustment_line_id` for a line created by an applicable prior ADD. Both or neither is invalid. Validation, advisory locking, active-rule duplicate/overlap identity, Preview, Create, Supersede, and resolution all use the same identity. Consequently a School-Dish rule can target a PRESENT system-added line, and a later School-Dish rule can target a PRESENT earlier School-Dish addition, without weakening conflict or concurrency guards.

## Commands

### `create_recipe_composition_adjustment`

- Capability: `master_data.recipe_adjustments.write`
- Owner: `atlas_master_data_command_runtime`
- Expected version: `1`
- Payload for `SYSTEM_DISH`: proposal fields plus required `as_of_date`, `preview_school_type_id`, and `preview_dish_id`; `preview_school_id` must be absent or null
- Payload for existing School-context paths: proposal fields plus required `as_of_date`, `preview_school_id`, and `preview_dish_id`
- Effect: serializes the exact typed target, revalidates the preview context, resolves the hypothetical effective composition, creates one stable root and revision 1, then emits event/audit/readback.

An exact request replay returns the original completed receipt. A reused idempotency key with different content fails closed.

### `supersede_recipe_composition_adjustment`

- Capability: `master_data.recipe_adjustments.write`
- Owner: `atlas_master_data_command_runtime`
- Expected version: current root version
- Required common payload: `adjustment_id`, new `revision_id`, exact `predecessor_revision_id`, `effective_from`, optional `effective_to`, action payload, `as_of_date`, and `preview_dish_id`
- Reviewed context for a `SYSTEM_DISH` root: exact `preview_school_type_id`; `preview_school_id` must be absent or null
- Reviewed context for existing School-context roots: exact `preview_school_id`
- Effect: serializes the exact typed target, then locks the root, verifies the exact current active predecessor, validates and resolves the successor, appends the next revision, and increments the root version.

Scope, action, and stable target identity cannot change. One predecessor can have only one successor.

Create and Supersede revalidate the system context inside the command transaction. The full request payload, including `preview_school_type_id`, remains covered by the established request hash, replay, conflict, locking, optimistic-version, receipt, event, audit, and safe-error behavior. Mixed School and School-Type preview identities fail closed. No new API family, business object, lifecycle, capability, table, role, or RLS policy is introduced. Existing `SCHOOL`, `SCHOOL_DISH`, and explicitly named `SYSTEM_INGREDIENT` impact-preview behavior remains unchanged.

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
- Compatibility: all six `RMVP-02B.v1` functions remain callable; valid existing School contexts are unchanged, while Preview/Create/Supersede add the typed `SYSTEM_DISH` context described above

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

Each row also returns backend-derived `is_effective_now` independently from `effective_from` and `effective_to`. It is true for contributing `ACTIVE`, `ACTIVE_RESUMED`, `ACTIVE_CHANGE_SCHEDULED`, and `ACTIVE_CANCELLATION_SCHEDULED` states, and false for `SCHEDULED`, `EXPIRED`, and `CANCELLED`. React does not infer this boolean from dates.

### Effective Recipe history shape

`get_dish_recipe_operator_workbench` returns `history_periods[]`. Each period has `period_from`, half-open nullable `period_to`, `resolution_status`, the complete PRESENT `effective_bom`, applicable `change_orders`, warnings, and blockers. Boundaries are the selected Recipe release date plus the union of applicable immutable revision `effective_from` and nonnull `effective_to` dates, so simultaneous Change Orders share one boundary. Every Change Order tag includes adjustment/revision identity, revision and business-event status, scope, action, effective dates, reason code/text, issuer, and issued timestamp. System history contains system layers only; School history contains all applicable system and School layers. React never replays revision rows to manufacture a historical BOM.

Native issuance uses the relevant immutable revision `created_at` and Actor display name. A revision imported without original OPS v1 attribution returns `issuance_kind: LEGACY_UNATTRIBUTED`, `issued_at: null`, and a null issuer name. The Atlas import timestamp is not represented as business issuance, and the Atlas importer is not represented as the original business issuer.

## Dish lifecycle eligibility amendment

Effective composition resolution requires an ACTIVE Dish and the existing
eligible released Recipe selection. The persisted `requires_need_generation`
flag is legacy metadata and is not an eligibility condition. Inactive Dishes
retain `DISH_NOT_ELIGIBLE`; Recipe selection precedence, adjustment resolution,
quantities, and historical evidence rules are unchanged.
