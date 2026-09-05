# Recipe Effective Product Model Correction

Status: Product and architecture design approved on 2026-09-05 for continuation of Draft PR #257.

Reviewed head: `2eafafb2a312d9e7a8301809a2d42c303bae49ef`.

This specification supersedes the conflicting Recipe-selection, Dish-copy, operator-state, and history-applicability parts of `2026-09-05-recipe-effective-workbench-design.md`. The stable effective-line targeting, precedence, temporal ledger, and backend-shaped history work already present on PR #257 remain authoritative unless changed explicitly below.

## Product model

Every newly created Atlas Dish owns exactly two normal active Recipe roots:

```text
Dish
├── TIỂU HỌC Recipe  (school_type_code = v1-school-type-1)
└── TRUNG HỌC Recipe (school_type_code = v1-school-type-2)
```

Each root is general to every School of its School Type. School-specific differences are represented only by `SCHOOL` and `SCHOOL_DISH` Recipe Composition Change Orders. A normal Dish does not use a nullable School-Type Recipe as a fallback or create a School-specific base Recipe.

The existing partial unique index on active `(dish_id, school_type_id)` Recipes supplies the at-most-one half of the invariant. The corrected `create_dish` command supplies the at-least-one half for new Dishes. This correction does not add a global constraint over legacy data.

## Canonical School-Type identity

Backend behavior identifies the two normal Recipe scopes only by stable catalog code:

1. `v1-school-type-1` — TIỂU HỌC
2. `v1-school-type-2` — TRUNG HỌC

Display name and capitalization are not identity. Tests use uppercase `TIỂU HỌC` and `TRUNG HỌC` labels to prove that behavior remains code-driven.

Each command or read that needs the canonical pair requires exactly one active School-Type row for each code. A missing or inactive canonical row is an invariant/readiness blocker; the backend does not substitute another type by name.

## Atomic Dish creation

`atlas_api.create_dish(jsonb)` retains its `RMVP-02A.v1` envelope, authorization, capability, scope, optimistic version, idempotency, receipt, event, audit, and safe-error behavior.

After authorization and idempotency replay resolution, the command:

1. resolves and locks the two active canonical School Types by code;
2. fails without a Dish write unless both exist;
3. inserts the Dish;
4. inserts one active Recipe root for each canonical type; and
5. completes the existing Dish-created receipt/event/audit transaction.

It creates no Recipe Version, BOM, line, validation, or release evidence. Recipe readiness remains a separate lifecycle concern. Any School-Type or Recipe-root insertion failure rolls back the Dish and both roots. Successful `affected_aggregate_ids` includes `dish_id` and an ordered `recipe_ids` array containing `school_type_id`, `school_type_code`, and `recipe_id` for both canonical scopes.

Controlled legacy imports and existing rows are not silently backfilled by this command.

## Typed-only RECIPE-EFFECTIVE selection

`atlas_core.recipe_effective_select_base_recipe(dish_id, school_type_id)` requires a nonnull active canonical School Type and exactly one active Recipe root in that exact typed scope with exactly one current `RELEASED_FOR_PLANNING` Recipe Version.

The selector never reads a Recipe whose `school_type_id is null`. It returns a blocking result for:

- absent or inactive/noncanonical School-Type context;
- missing active typed Recipe root;
- missing eligible released typed Recipe Version; or
- ambiguous eligible typed Recipe state.

The selected scope is `SCHOOL_TYPE`. The system read, target-context read, Dish operator read, effective history, and Dish-level copy all use this selector. School context first derives School Type from the authoritative active School and then uses the same selector.

Existing RMVP-02B compatibility APIs may retain their pre-PR selection behavior through the renamed legacy resolver. Compatibility must not reintroduce NULL fallback into any `RECIPE-EFFECTIVE.v1` result or command.

## Existing data and cutover

Atlas Staging contains legacy NULL-general and synthetic Recipe shapes. This correction performs no hosted write, backfill, deletion, status rewrite, or global constraint validation against those rows.

Before enabling `RECIPE-EFFECTIVE.v1` for a legacy Dish, a controlled cutover must reconcile that Dish to exactly one active Recipe root for each canonical code, place eligible BOM evidence under the correct typed roots, resolve duplicates or gaps, and retain immutable Recipe Version lineage. NULL-general rows may remain as compatibility history until a separately approved retirement plan exists, but the new contract ignores them.

## System-effective Dish copy

`atlas_api.copy_dish_recipes(jsonb)` retains `RECIPE-EFFECTIVE.v1`, adds required `payload.as_of_date`, and requires distinct active source and target Dishes plus the expected target Dish version and nonblank reason.

For each canonical scope in code order, the command resolves:

```text
typed released base Recipe
→ SYSTEM_INGREDIENT
→ SYSTEM_DISH
→ source system-effective BOM at as_of_date
```

It never supplies a School ID and therefore never applies `SCHOOL` or `SCHOOL_DISH`. Both source scopes must resolve `READY`. Both corresponding active target Recipe roots must already exist. A missing source or target scope is `INVARIANT_VIOLATION`; the command does not return `SOURCE_NOT_AVAILABLE` and does not create a Recipe root opportunistically.

Inside the one outer command transaction, each resolved PRESENT effective line is materialized into a new target Recipe Version using existing stable Recipe-line/version lineage rules:

- reuse target stable lines by Ingredient when continuing prior target evidence;
- create new stable target lines for new Ingredients;
- append explicit removed-line successors for prior target Ingredients absent from the snapshot;
- preserve prior Recipe Versions and immutable line revisions;
- reject an unfinished conflicting target version; and
- leave the newly copied version in the existing editable copy lifecycle rather than silently validating or releasing it.

The target version is a snapshot. Later source-rule creation, correction, expiration, or cancellation cannot change it. Source Recipe/BOM and adjustment roots/revisions are never mutated or copied as target adjustment facts.

Each target Recipe Version `source_evidence` records:

- `source_kind = RECIPE_EFFECTIVE_COPY`;
- `source_dish_id`;
- `source_school_type_id` and `source_school_type_code`;
- `copy_as_of_date`;
- selected source `recipe_id` and `recipe_version_id`;
- distinct contributing `SYSTEM_INGREDIENT` and `SYSTEM_DISH` adjustment/revision identities; and
- the outer command ID and operator reason.

The whole two-scope materialization runs in one subtransaction. Any invariant, lifecycle, reference, or write failure rolls back both scopes. The D-038 approved-Menu lock is acquired/rechecked before writes and blocks the entire copy. Exact replay and changed-content idempotency conflict remain authoritative at the outer receipt.

The support-level `copy_recipe_version` API remains callable and unchanged; it is not the business source or child command for `copy_dish_recipes`.

## Operator edit and action state

`get_dish_recipe_operator_workbench` derives state from the authoritative Dish lifecycle, active typed Recipe root/version, and `uiq03a_dish_used_operationally(dish_id)`.

- Before approved-Menu use, the state is `EDITABLE_BASE`, `is_editable` is true, and the base Recipe editor is the normal modification path.
- After approved-Menu use, the state is `LOCKED_CHANGE_ORDER`, `is_editable` is false, the current effective BOM is read-only, and Lệnh điều chỉnh is the normal modification path.

`COPY_DISH_RECIPES` is advertised only when the Dish is an eligible unlocked target and the command would not be rejected by the D-038 lock. `CREATE_CHANGE_ORDER` is advertised only for a locked READY effective context. React may narrow these actions but never widen them.

## Material history applicability

Candidate effective-history boundaries may be discovered from potentially applicable adjustment roots, but a root belongs to a Dish history only if its adjustment identity appears in actual resolver lineage for that Dish in at least one effective period.

This rule removes unrelated global `SYSTEM_INGREDIENT` changes from the Dish history. It retains evidence for a contributing root even after correction or cancellation. Adjacent boundaries with identical effective BOM state may be coalesced into one operator panel. Coalescing never deletes or rewrites adjustment revisions: all correction/cancellation evidence remains reachable through the immutable Lệnh điều chỉnh ledger/detail and backend revision history.

`school_exception_count` is the distinct count of currently applicable `SCHOOL` or `SCHOOL_DISH` adjustment roots whose IDs occur in resolved lineage for the selected Dish context. A system School-Type view evaluates active Schools of that type; a School view evaluates only that School. Unrelated School Ingredient changes do not count.

## Preserved behavior

The correction must retain:

- `RECIPE_LINE` versus `ADJUSTMENT_LINE` effective targets;
- SYSTEM_DISH modification of prior SYSTEM_DISH ADD lines;
- SCHOOL_DISH modification of SYSTEM_DISH ADD lines;
- SCHOOL_DISH modification of earlier SCHOOL_DISH ADD lines;
- Preview-to-Create target identity round-trip;
- system-versus-School precedence;
- backend-derived `is_effective_now`; and
- backend-shaped full-BOM history periods.

Fixtures for those behaviors use the canonical typed Recipe pair rather than NULL-general fallback.

## Security and exclusions

Use the existing schemas, capabilities, runtime roles, forced RLS, fixed empty search paths, authenticated Actor resolution, global scope authority, optimistic concurrency, receipts, events, audit, and D-038 locks. Do not add a capability, runtime role, table, generic workflow, or browser access to private schemas. Public SECURITY DEFINER functions retain explicit schema qualification and authenticated-only execution.

No Weekly Menu behavior, Attendance, Need Generation formula, Pantry, Confirmed Need, Procurement, PO, Warehouse, Dispatch, hosted data, Retool, OPS v1, deployment, or merge is in scope.

## Acceptance and verification

Test-first coverage must prove requirements A–P from the approved correction brief, including pair creation, code-based uppercase catalog handling, typed-only missing-scope blockers, two-scope system-effective snapshot copy, School-layer exclusion, source immutability, later-rule independence, transaction rollback, target lock, lifecycle-derived operator state, history relevance, exception-count relevance, and all preserved targeting behaviors.

Run the existing focused PR #257 pgTAP suites, affected Dish-creation suites, relevant API/model Vitest, typecheck, formatting, security-catalog checks, and `git diff --check`. After targeted GREEN and correction completion, transition PR #257 from Draft to Ready so the repository-owned Supabase Full Integration workflow runs. Do not merge or deploy.

## Design self-review

- The two-root invariant applies to new command-created Dishes and Dishes treated as valid by the new contract, not as an immediate global cleanup constraint.
- Stable School-Type codes are the only canonical scope identity.
- Recipe Versions remain absent at Dish creation and immutable once materialized.
- Copy is a system-effective snapshot, not a base-version delegation or adjustment clone.
- History panel coalescing is separate from immutable revision evidence.
- Compatibility is isolated without mutating Staging or weakening the new typed-only contract.
