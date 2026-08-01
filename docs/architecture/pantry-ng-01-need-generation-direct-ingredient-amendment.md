# PANTRY-NG-01 — Need Generation Direct Ingredient Amendment

- **Status:** Product and architecture contract accepted; implementation not started
- **Product Owner approval date:** 01/08/2026
- **Exact baseline:** `b7b44923769dc690a51871365a8ef81eed396946`
- **Domain:** Planning
- **Decision authority:** [Decision PANTRY-NG-01](../decisions/decision-pantry-ng-01-need-generation-direct-ingredient.md)
- **Task record:** [TASK-PANTRY-NG-01](../implementation-tasks/TASK-PANTRY-NG-01-need-generation-direct-ingredient-amendment.md)

## 1. Purpose and scope

This amendment defines how exact approved Pantry Ingredient quantities contribute directly to Need Generation without Recipe explosion. It creates the product and architecture contract for a later bounded implementation; it adds no SQL, command, API, UI or hosted-system behavior.

The governing outcome is:

```text
exact approved Menu + Attendance evidence
+ exact approved Pantry evidence
+ eligible Recipe evidence for Recipe-derived contributions
= one combined Need Generation run
+ immutable atomic Recipe-derived and Pantry-direct contributions
+ one immutable release snapshot when released
```

The complete decisions are canonical only in [PNG-P01 through PNG-P12](../decisions/decision-pantry-ng-01-need-generation-direct-ingredient.md#3-canonical-decisions).

## 2. OPS_SYSTEM_MAP placement

| Layer               | PANTRY-NG-01 placement                                                                                                                                                                                                                                                                 |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Mission             | Capture every operational Ingredient need before purchasing.                                                                                                                                                                                                                           |
| Business capability | Convert approved Planning inputs into controlled theoretical demand.                                                                                                                                                                                                                   |
| Business domain     | Planning.                                                                                                                                                                                                                                                                              |
| Business objects    | `PantryNeedApprovalSnapshot`, `PantryNeedApprovalSnapshotLine`, `NeedGenerationRun`, `NeedGenerationInputSnapshot`, `TheoreticalNeedLine`, `NeedGenerationIssue`, `NeedGenerationReleaseSnapshot`.                                                                                     |
| Business contract   | Each approved positive Pantry line inside the exact inclusive run period contributes its exact Ingredient quantity; explicit zero-line and valid zero-in-period cases retain header evidence; Pantry bypasses Recipe explosion but not readiness, generation, release or confirmation. |
| Command/event       | Not implemented in PANTRY-NG-01.                                                                                                                                                                                                                                                       |
| Read model          | Not implemented in PANTRY-NG-01.                                                                                                                                                                                                                                                       |
| Application         | No React or Retool change.                                                                                                                                                                                                                                                             |
| Technology          | Future bounded PostgreSQL amendment defined as a ceiling only; no executable change.                                                                                                                                                                                                   |

This placement prevents legacy query structure or UI behavior from defining Planning identity, calculation or lifecycle authority.

## 3. Current-state conflict

The merged baseline contains two individually valid but not yet connected facts:

1. PANTRY-RDY-02 and RMVP-03B bind the exact Pantry batch/version/approval-snapshot triple to the current `READY` evaluation and Need Generation request handoff.
2. H0A5b persistence is Recipe-only: its input snapshot directly repeats only Menu and Attendance evidence, and every theoretical line requires Menu, Attendance, Dish, Recipe, RecipeVersion, RecipeLine, RecipeLineRevision and calculation-contract evidence.

Consequently, current SQL cannot create a Pantry-direct theoretical contribution without violating H0A5b typed constraints or fabricating Recipe lineage. PANTRY-NG-01 resolves the product and architecture conflict while leaving the database unchanged.

## 4. Approved Pantry-to-Need-Generation chain

```text
PantryNeedBatch at exact approved version
→ exact PantryNeedApprovalSnapshot
→ zero or more exact PantryNeedApprovalSnapshotLine rows
→ exact Pantry triple on the current READY evaluation
→ the same exact Pantry triple on NeedGenerationInputSnapshot
→ one PANTRY_DIRECT atomic contribution per positive snapshot line inside the exact inclusive run period
→ combined Need Generation validation and release
→ contribution-based Confirmed Need materialization and later review
```

Pantry remains a Planning source. It is not a Dish, Recipe, Recipe override, Wholesale Order, Warehouse request, supplier assignment or fulfilment route.

## 5. Typed input-snapshot amendment

Every future Need Generation input snapshot must carry:

```text
pantry_need_batch_id
pantry_need_batch_version
pantry_need_approval_snapshot_id
```

The triple equals the current readiness evaluation exactly. Generation must recheck current batch status, version, latest approval pointer, week containment, typed snapshot ownership and header invariants in the same authoritative transaction. The header remains mandatory for both an explicit zero-line snapshot and a positive snapshot with zero positive lines inside the exact run period.

No generic source registry, polymorphic type/ID pair, JSON payload, source token or caller-authored label can replace the typed triple.

## 6. Closed contribution-family model

The atomic relation uses exactly `RECIPE_DERIVED` and `PANTRY_DIRECT`.

- `RECIPE_DERIVED` retains all current H0A5 Menu, Attendance, Recipe/BOM, fixed-calculation and source-Unit invariants.
- `PANTRY_DIRECT` retains exact Pantry snapshot/stable-line lineage, binds an exact snapshot line when active and has no Recipe-derived line or calculation evidence.

The families are mutually exclusive and share the existing run, line disposition, issue, validation and release boundaries. Existing Recipe-only columns may become conditionally nullable only behind strict family checks; Recipe-derived integrity cannot be weakened.

## 7. Quantity, Unit and positive-line behavior

For every-and-only positive approved Pantry snapshot line whose `service_date` is between the exact run `period_start` and `period_end`, inclusive:

```text
one approved Pantry snapshot line
→ one ACTIVE PANTRY_DIRECT theoretical line

theoretical_quantity
= requested_quantity copied exactly as numeric(20,6)

theoretical Unit
= exact approved Pantry snapshot-line Unit
```

School, Delivery Location, service date and Ingredient also equal the exact approved line. Pantry Purpose and supporting evidence remain reachable through the typed snapshot-line reference.

Positive approved Pantry snapshot lines outside the exact period remain historical source evidence through the bound Pantry snapshot header. They create no theoretical line or Need Generation issue for the run, do not increment `generated_line_count` and are not release members.

There is no Attendance multiplication, Recipe basis division, Recipe explosion, yield, waste, conversion, rounding, supplier/warehouse rule or client arithmetic. Pantry lines are never grouped inside Need Generation, including when they share Ingredient, School, location, date, Unit or Purpose.

Recipe-derived and Pantry-direct contributions may coexist with identical later operational identity; they remain distinct atomic facts.

## 8. Zero-contribution Pantry header behavior

A Pantry snapshot is controlled zero-line evidence only when `line_count = 0`, `no_additions_confirmed = true` and no snapshot-line row exists.

Need Generation retains that exact header, produces no Pantry-direct line and raises no missing-source or controlled-absence issue. It creates no zero placeholder and invents no Ingredient, Unit, School, location or Purpose. Recipe-derived contributions may still make the combined run nonempty.

An approved Pantry snapshot that contains positive lines but zero positive lines inside the exact inclusive run period is also valid. It is period-filtered membership, not missing Pantry and not the explicit zero-line form. Need Generation retains the exact header and creates zero `ACTIVE` Pantry-direct contributions from the out-of-period lines, with no placeholder, issue, count increment or release member. Absent an in-period predecessor obligation, it creates zero Pantry-direct theoretical lines; only required in-period `REMOVED` successor evidence under the next section may still exist.

## 9. Predecessor, removal and reintroduction behavior

Stable `PantryNeedLine` identity carries continuity across directly linked runs for the same input set and immutable exact period. Predecessor and removal membership includes only stable Pantry lines represented by positive approved snapshot lines whose `service_date` is inside that period. The same in-period stable line has one predecessor even when quantity, Unit, Purpose, note or source reference changes. A genuinely new in-period stable line has no predecessor.

Omission of a formerly active in-period stable Pantry line from the successor's in-period approved-line set is explicit removal: create one exact-zero `REMOVED` contribution with one predecessor, the same stable Pantry line and the successor Pantry snapshot header as controlled absence. It has no fabricated current snapshot-line row. Every prior active Pantry contribution inside that immutable run-period scope requires one active or removed successor; silent omission, fork, split, merge or cross-chain wiring inside the scope is blocking.

Positive snapshot lines outside the exact immutable run period do not participate in predecessor or removal completeness. They are not omissions, do not require predecessors, create neither `ACTIVE` nor `REMOVED` successors and do not trigger silent-omission or removal issues.

Reintroduction after `REMOVED` is unsupported in the first slice. It uses the existing `UNSUPPORTED_REINTRODUCTION_AFTER_REMOVAL` blocker, remains unreleasable and requires invalidation plus a separately approved extension.

## 10. Issue and validation effects

Existing precise H0A5 classifications remain authoritative for stale readiness source evidence, missing typed trace, predecessor/removal failures, unsupported reintroduction and release-membership failures.

PANTRY-NG-01 adds only:

- `MISSING_PANTRY_INPUT_BINDING` — `BLOCKING`;
- `INVALID_PANTRY_SNAPSHOT_MEMBERSHIP` — `BLOCKING`; and
- `PANTRY_APPROVED_QUANTITY_UNIT_MISMATCH` — `BLOCKING`.

Their exact conditions are defined in [PNG-P10](../decisions/decision-pantry-ng-01-need-generation-direct-ingredient.md#png-p10--closed-issue-and-validation-effects). There is no Pantry warning. `ZERO_ACTIVE_THEORETICAL_QUANTITY` remains Recipe-derived only.

Validation and release require complete every-and-only evidence across both source families. Counts and issue summaries apply to the combined run.

## 11. Release and Confirmed Need compatibility

The existing Need Generation release snapshot remains the sole boundary. It includes every-and-only Recipe-derived and Pantry-direct active/removed theoretical lines plus exact issue membership. Pantry release explainability retains contribution family, Pantry snapshot/stable-line lineage, current snapshot line when active, operational dimensions, quantity, disposition and predecessor.

Confirmed Need continues to consume these rows through its existing `NEED_GENERATION` source family. Materialization may group Pantry and Recipe contributions only when their complete operational identity matches and immutable contribution membership proves the exact total.

For Pantry direct contributions, the operational destination is the exact approved Pantry Delivery Location. A later materialization amendment must not substitute the School's current default location. If a Recipe-derived contribution resolves to another location, the two contributions belong to different operational groups.

This amendment does not approve or adjust Confirmed Need and does not release Purchase Handoff or create Procurement, supplier, Warehouse or Dispatch behavior.

## 12. Future persistence ceiling

A later separately authorized implementation must remain bounded to extending the existing H0A5b and H0C-compatible model needed to enforce this contract. At minimum it must define, before coding:

- exact input-snapshot Pantry columns and typed ownership;
- the contribution-family discriminator and mutually exclusive line columns;
- active and removed Pantry lineage checks and indexes;
- exact guard/integrity amendments for combined every-and-only generation;
- the three added issue codes and typed Pantry issue context;
- combined release completeness and immutable membership;
- Pantry-aware Confirmed Need destination and membership compatibility;
- migration and forward-fix behavior;
- exact pgTAP ownership and plan counts;
- any command, read, React and grant delta.

The ceiling prohibits a parallel Pantry aggregate, generic source registry, generic calculation engine, new lifecycle, Pantry-only release, speculative Pantry API name, supplier routing, Warehouse logic or production/hosted action. Exact physical relations, columns, commands and security changes remain decisions for that later task.

## 13. Explicit non-goals

PANTRY-NG-01 does not implement or authorize:

- SQL, migration, RPC, API, read model, React, Retool, test, seed or deployment changes;
- alteration of existing migrations;
- a Need Generation command or UI;
- Confirmed Need approval, adjustment or release;
- Purchase Handoff, Procurement, supplier, Warehouse, Dispatch, OPS v1/v2 or production behavior;
- hosted Supabase project changes;
- `adjustments_add_pantry_need`, `createPantryNeed`, a generic source registry or a generic calculation engine.

## 14. Rollback meaning

This task changes documentation only. Rollback is a normal Git revert of the nine authorized Markdown paths. There is no schema, data, API, deployment or hosted-system rollback effect.
