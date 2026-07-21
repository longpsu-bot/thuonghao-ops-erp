# Decision PA-06E-H0A5b — Need Generation Persistence

**Status:** Implemented under Issue #131; pending independent governance review

**Date:** 2026-07-21

**Issue:** [#131](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/131)

**Exact baseline:** `07c8360ea6fb70148428c549c7534d2b202958f4`

**Design authority:** [Decision PA-06E-H0A5 — Need Generation Run and Theoretical Lineage](decision-pa-06e-h0a5-need-generation-lineage.md)

**Contract:** [PD-01.6 — Planning Domain Need Generation Contract](../architecture/planning-domain-need-generation-contract.md)

## Decision

Atlas persists Need Generation in the private `atlas_planning` schema as one fixed calculation-contract family, one accepted run per exact requested Planning Input Set/current evaluation, immutable typed source evidence, atomic Theoretical Need contributions, immutable classified issues, and an immutable release boundary.

The physical catalog is exactly:

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

No generic source registry, polymorphic source pair, JSON lineage, event/audit table, command receipt, acknowledgement, waiver, override, Confirmed Need relation, Procurement relation, or downstream aggregate is introduced.

## Calculation contract and authoritative arithmetic

The root code is fixed to `school_catering_proportional_per_basis`. Immutable revisions are fixed to:

- formula kind `STUDENT_TEACHER_PORTIONS_X_RECIPE_QTY_DIV_BASIS`;
- quantity precision 20 and scale 6;
- factor precision 24 and scale 12;
- final coercion `POSTGRES_NUMERIC_SCALE_HALF_AWAY_FROM_ZERO`.

PostgreSQL alone evaluates:

```text
(student_portions::bigint + teacher_portions::bigint)::numeric
× quantity_per_basis::numeric
÷ basis_portions::numeric
```

The result is coerced exactly once to `numeric(20,6)`. The output Unit is the exact RecipeLineRevision Unit. There is no conversion, yield, allowance, waste, Planning rounding, purchase rounding, JavaScript arithmetic, binary floating point, clamp, or fallback.

## Entry and typed ownership

At transaction end, a new run requires:

- root status `NEED_GENERATION_REQUESTED`;
- the exact current `READY` evaluation with zero readiness blockers;
- the exact current/latest approved Menu and Attendance root/version/snapshot triples;
- complete source-period containment;
- an input snapshot repeating those exact bindings;
- the exact current calculation-contract revision.

Recipe selection is deterministic: eligible exact SchoolType Recipe first, otherwise eligible general Recipe, otherwise a blocker. Every selected released RecipeVersion has every-and-only its exact H0A2 RecipeLineRevision composition represented in typed use rows, including `PRESENT` and `REMOVED` revisions. A Dish with `requires_need_generation = false` produces no selection, line, or issue.

## Atomic lineage and correction history

Each `theoretical_need_lines` row is one immutable atomic contribution. Direct typed FKs retain its run, input snapshot, Recipe selection/use, Menu snapshot and stable line, Attendance snapshot and stable line, School, date, Dish, Recipe, RecipeVersion, RecipeLine, RecipeLineRevision, Ingredient, Unit, and calculation root/revision.

`ACTIVE` quantity is nonnegative. Exact zero requires exactly one `ZERO_ACTIVE_THEORETICAL_QUANTITY` warning. `REMOVED` quantity is zero, carries exact H0A2 `REMOVED` evidence, and points to one compatible line in the direct predecessor run. Predecessors cannot self-link, fork, split, merge, cross a period/input set, or skip a prior active contribution silently.

A genuinely new stable RecipeLine is `ACTIVE` without a predecessor. A removed line may remain absent while its stable RecipeLine remains absent. If the stable line reappears as H0A2 `PRESENT`, no line is created, no `REMOVED → ACTIVE` predecessor is inferred, and `UNSUPPORTED_REINTRODUCTION_AFTER_REMOVAL` blocks validation and release.

## Issues, lifecycle, and release

The persisted catalog is the exact 31-code post-entry subset of H0A5a. The four pre-run readiness failure classifications are not stored because rejected entry leaves no run. Every stored code is `BLOCKING` except `ZERO_ACTIVE_THEORETICAL_QUANTITY`, the sole `WARNING`. Issues are immutable and nondeletable; stored counts equal exact owned rows.

Run states are exactly `GENERATED`, `VALIDATED`, `RELEASED_FOR_CONFIRMATION`, and `INVALIDATED`. Allowed transitions are:

```text
GENERATED → VALIDATED
GENERATED → INVALIDATED
VALIDATED → RELEASED_FOR_CONFIRMATION
VALIDATED → INVALIDATED
RELEASED_FOR_CONFIRMATION → INVALIDATED
```

Every transition increments version exactly once. A failed validation or release may append issues and update only counts, version, and `updated_at` while status remains unchanged. A blocker prevents validation and release.

One released run/version owns one immutable release header and every-and-only its theoretical-line and immutable-issue membership. Cross-run, wrong-version, missing, extra, altered, duplicated, or later-admitted membership fails closed.

## Enforcement and security

The private guard catalog is exactly:

1. `atlas_planning.pa_06e_h0a5b_calculation_contract_guard()`
2. `atlas_planning.pa_06e_h0a5b_need_generation_run_guard()`
3. `atlas_planning.pa_06e_h0a5b_immutable_evidence_guard()`
4. `atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()`

Every one of the 11 relations has one ordinary `<relation>_guard` trigger and one `DEFERRABLE INITIALLY DEFERRED` `<relation>_integrity` constraint trigger: exactly 22 triggers. Transaction-end enforcement owns circular root/snapshot and contract/revision pointers, readiness/currentness, counts, every-and-only composition, typed source equality, predecessor completeness, unsupported reintroduction, and release completeness.

All relations and functions are owned by `atlas_owner`. Functions are invoker-security with `search_path = ''`. RLS is enabled and forced on every relation with zero policies. `PUBLIC`, `anon`, `authenticated`, and `service_role` receive no relation privileges or function execution. All FKs use `ON DELETE RESTRICT` and operational composite FKs have leading indexes. UUID identities are database-generated and no production row is seeded. The canonical `atlas_api` surface remains exactly 18 functions.

## Verification

Four independently runnable suites own exclusive invariant families:

| Suite                                                 |    Plan |
| ----------------------------------------------------- | ------: |
| Structure/security                                    |      44 |
| Run/input/Recipe/calculation integrity                |      60 |
| Theoretical-line/source/predecessor/release integrity |      76 |
| Lifecycle/issues/invalidation/history                 |      64 |
| **H0A5b total**                                       | **244** |

CI registers the four suites after H0A4b and before PA-05G. The complete registered database target is 15 files and 882 assertions.

## Exclusions and migration boundary

H0A5b adds no command, authorization, reason/event, safe-error mapping, read model, RPC, browser surface, role/capability, generated type, React change, hosted Supabase action, Retool action, production data, Confirmed Need behavior, Procurement behavior, or supported removed-line reintroduction.

Before operational use, the unshipped additive migration can be reverted normally. After generated or released immutable evidence exists, corrections are forward-only; historical identities and release membership must be preserved.
