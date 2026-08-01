# TASK-PANTRY-NG-01 — Need Generation Direct Ingredient Amendment

- **Status:** Contract and decision complete; implementation not started
- **Exact baseline:** `b7b44923769dc690a51871365a8ef81eed396946`
- **Branch:** `docs/pantry-ng-01-direct-ingredient-contribution`
- **Product Owner approval date:** 01/08/2026
- **Decision register ID:** D-028
- **Canonical decision:** [Decision PANTRY-NG-01](../decisions/decision-pantry-ng-01-need-generation-direct-ingredient.md)
- **Architecture amendment:** [PANTRY-NG-01 direct-ingredient amendment](../architecture/pantry-ng-01-need-generation-direct-ingredient-amendment.md)

## 1. Outcome

PANTRY-NG-01 completes the product-decision and architecture-contract work for direct Pantry Ingredient contributions to Need Generation. Decisions `PNG-P01` through `PNG-P12` are accepted and registered canonically in the decision document.

There is no executable delta. Current H0A5b SQL remains Recipe-only, RMVP-03B remains a handoff-only readiness implementation and Pantry Need Generation implementation has not started.

## 2. Exact authorized nine-path manifest

1. `docs/architecture/pantry-ng-01-need-generation-direct-ingredient-amendment.md`
2. `docs/decisions/decision-pantry-ng-01-need-generation-direct-ingredient.md`
3. `docs/implementation-tasks/TASK-PANTRY-NG-01-need-generation-direct-ingredient-amendment.md`
4. `docs/architecture/planning-domain-need-generation-contract.md`
5. `docs/architecture/pantry-01-planning-owned-pantry-source-contract.md`
6. `docs/architecture/task-003-source-of-need-contract.md`
7. `docs/decisions/decision-pa-06e-h0a5-need-generation-lineage.md`
8. `docs/architecture/roadmap.md`
9. `docs/decisions/decision-register.md`

No other path is authorized.

## 3. Documentation-only scope

The task:

- records D-028;
- defines the closed `RECIPE_DERIVED` / `PANTRY_DIRECT` contribution model;
- defines exact Pantry input, quantity, Unit, atomicity, zero-line, correction, issue and release semantics;
- records the Confirmed Need compatibility requirement for exact Pantry Delivery Location; and
- marks RMVP-03B merged while leaving connected Need Generation incomplete.

It does not describe SQL, commands, APIs, React or tests as implemented.

## 4. Decisions accepted

The sole complete registry is [PNG-P01 through PNG-P12](../decisions/decision-pantry-ng-01-need-generation-direct-ingredient.md#3-canonical-decisions). In summary, they establish closed source families, one combined run, exact Pantry input binding, one atomic contribution relation, exact quantity/Unit pass-through, positive and zero-line behavior, stable-line predecessor/removal rules, blocked reintroduction, a minimal closed issue amendment, one release boundary, Confirmed Need compatibility and a separately authorized implementation boundary.

## 5. Validation performed

Local documentation validation for the exact nine-path manifest consists of:

- `git diff --check`;
- targeted Prettier check for all nine Markdown files;
- repository-local link and path inspection;
- stale-statement and placeholder search;
- exact-manifest and executable-delta inspection; and
- final workspace status inspection.

No local Supabase stack, database reset, pgTAP suite, Auth provisioning, browser RPC acceptance or full frontend suite is run for this documentation-only task. GitHub Actions at the pushed exact head remains the authoritative CI result.

## 6. Proposed future implementation sequence

A separately authorized implementation should proceed in this order:

1. inventory exact H0A5b and H0C physical constraints at its own approved baseline;
2. approve the exact migration manifest, altered relations/columns, guards, indexes and rollback/forward-fix path;
3. implement the typed Pantry input triple and closed contribution-family checks without weakening Recipe-derived invariants;
4. implement exact active/removal/predecessor, issue and every-and-only release enforcement;
5. amend Confirmed Need materialization compatibility to preserve exact Pantry Delivery Location and immutable contribution membership;
6. define and implement exclusive focused pgTAP families with exact plans;
7. separately authorize any command/read API and security delta; and
8. separately authorize any connected React work after backend contracts merge.

No step above is authorized by PANTRY-NG-01 itself.

## 7. Explicit exclusions

Excluded are SQL, migrations, tests, RPCs, APIs, React/TypeScript, generated files, workflow changes, package changes, seeds, hosted Supabase, Retool, OPS v1/v2, production data, credentials, capability bindings, Pantry fulfilment, supplier decisions, Warehouse decisions, Purchase Handoff, Procurement and Dispatch.
