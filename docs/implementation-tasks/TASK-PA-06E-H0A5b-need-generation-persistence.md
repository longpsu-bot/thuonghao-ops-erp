# TASK-PA-06E-H0A5b — Need Generation Persistence

**Status:** Implemented under Issue #131; pending independent governance review

**GitHub issue:** [#131](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/131)

**Starting baseline:** `07c8360ea6fb70148428c549c7534d2b202958f4`

**Task branch:** `backend/pa-06e-h0a5b-need-generation-persistence`

**Decision:** [Decision PA-06E-H0A5b — Need Generation Persistence](../decisions/decision-pa-06e-h0a5b-need-generation-persistence.md)

## Objective

Persist the accepted H0A5a contract without reopening its run grain, readiness binding, Recipe precedence, arithmetic, Unit behavior, atomic lineage, predecessor/removal behavior, issue taxonomy, lifecycle, or release boundary.

## Implemented scope

One additive migration creates exactly these private `atlas_planning` relations:

1. `need_generation_calculation_contracts`
2. `need_generation_calculation_contract_revisions`
3. `need_generation_runs`
4. `need_generation_input_snapshots`
5. `need_generation_recipe_selections`
6. `need_generation_recipe_line_uses`
7. `theoretical_need_lines`
8. `need_generation_issues`
9. `need_generation_release_snapshots`
10. `need_generation_release_snapshot_lines`
11. `need_generation_release_snapshot_issues`

The migration creates exactly four private guards:

1. `pa_06e_h0a5b_calculation_contract_guard()`
2. `pa_06e_h0a5b_need_generation_run_guard()`
3. `pa_06e_h0a5b_immutable_evidence_guard()`
4. `pa_06e_h0a5b_need_generation_integrity_guard()`

Each relation owns one ordinary guard trigger and one initially deferred constraint trigger, for exactly 22 triggers. No upstream source relation receives an H0A5b trigger.

## Acceptance behavior

- The calculation-contract root is fixed to `school_catering_proportional_per_basis`; revisions fix `STUDENT_TEACHER_PORTIONS_X_RECIPE_QTY_DIV_BASIS`, quantity precision/scale 20/6, factor precision/scale 24/12, and `POSTGRES_NUMERIC_SCALE_HALF_AWAY_FROM_ZERO`.
- One run binds one exact requested Planning Input Set and exact current READY evaluation.
- The immutable input snapshot repeats exact Menu, Attendance, and calculation-revision triples.
- Recipe precedence is exact eligible SchoolType, otherwise exact eligible general, otherwise blocker.
- Every selected RecipeVersion captures every-and-only its exact typed H0A2 composition.
- PostgreSQL evaluates student-plus-teacher portions multiplied by Recipe quantity and divided by basis, with one final `numeric(20,6)` coercion.
- Every output is one atomic contribution with complete direct typed lineage and the RecipeLineRevision source Unit.
- Every eligible `PRESENT` RecipeLine use with exact Attendance owns one matching `ACTIVE` line unless an exact permitted blocker explains the omission; an empty stored count cannot mask missing output.
- Initial generation accepts only active Ingredient and Unit references. Inactive references create no active line and require their exact blockers, while later reference deactivation leaves historical generated and released evidence unchanged.
- Active, removed, new, predecessor, silent-omission, and unsupported-reintroduction behavior is fail closed.
- The exact persisted 31-code issue catalog has one warning and immutable issue evidence.
- Lifecycle is closed to four states and exact version increments.
- Release requires one immutable complete header, line membership, and issue membership.

## Security

All 11 relations and four functions are `atlas_owner` owned. Relations have RLS enabled and forced, zero policies, and zero direct `PUBLIC` or API-role privileges. Functions are invoker-security with empty search paths and zero forbidden execution grants. All FKs are restrictive; composite operational FKs have leading indexes. No API, role, capability, policy, production seed, sequence-backed business identity, or public/`ops_v2` surface is added. The 18-function `atlas_api` registry is unchanged.

## Test decomposition

Exactly four independent pgTAP files own disjoint families:

| File                                                                      | Family                                 |    Plan |
| ------------------------------------------------------------------------- | -------------------------------------- | ------: |
| `pa_06e_h0a5b_need_generation_structure_security.sql`                     | Structure/security                     |      44 |
| `pa_06e_h0a5b_need_generation_run_input_recipe_calculation_integrity.sql` | Run/input/Recipe/calculation           |      60 |
| `pa_06e_h0a5b_theoretical_line_source_predecessor_release_integrity.sql`  | Theoretical/source/predecessor/release |      76 |
| `pa_06e_h0a5b_need_generation_lifecycle_issues_invalidation_history.sql`  | Lifecycle/issues/invalidation/history  |      64 |
|                                                                           | **H0A5b**                              | **244** |

Each suite owns its transaction, extension setup, deterministic fixtures, exact plan, `finish()`, and rollback. CI registers the four commands after H0A4b and before PA-05G. Final registered regression target: 15 files, 882 assertions.

## Exclusions

The task does not add a generic registry, conversion family, generic formula engine, supported reintroduction, command/event/receipt/audit surface, authorization, runtime role, capability, API/RPC/view, generated type, application change, Confirmed Need, Procurement, downstream aggregation, hosted action, Retool access, production row, or seed.

## Migration and correction boundary

The migration is additive. Before operational use it can be reverted as an unshipped change. After immutable generated or released evidence exists, repair is forward-only and must preserve historical run, source, line, predecessor, issue, and release identities.

## Validation record

- Governance-correction evidence rejects a complete `PRESENT` composition with exact Attendance and no theoretical output, rejects new active lines for inactive Ingredient or Unit references, accepts only the corresponding exact no-line blockers, and proves later reference deactivation is non-retroactive.
- Four independent clean-reset runs passed at `Files=1`, `Tests=44/60/76/64`, and `Result: PASS`; combined H0A5b evidence is 244/244.
- A final clean reset replayed every migration and the registered sequence passed exactly 15 files and 882/882 assertions.
- Affected-schema lint completed without errors; only the documented pre-existing `atlas_core.pa_05d_safe_date` and `atlas_api.confirm_successful_delivery` warnings remain.
- The migration-to-local structural diff for `atlas_planning`, `atlas_admin`, `atlas_core`, and `atlas_api` is empty.
- Exact catalog checks report 11 relations, four guards, 22 triggers, 69 restrictive foreign keys, zero missing leading indexes, zero policies, zero forbidden grants, zero upstream H0A5b triggers, and the unchanged 18-function `atlas_api` registry.
- Local advisors report no H0A5b error or warning. Their H0A5b informational results are the intended 11 `rls_enabled_no_policy` findings and 69 `unused_index` findings for the new empty relations; the catalog audit separately proves every operational FK has its required leading index.
- Frozen install, formatting, typecheck, 41 frontend test files/265 assertions, production build, whitespace checks, and canonical-workspace verification pass. The existing nonblocking Vite chunk-size advisory remains.
- No hosted Supabase, Retool, production-data, credential, deployment, generated-type, API, RPC, role, capability, seed, or application action occurred.
