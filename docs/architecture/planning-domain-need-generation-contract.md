# PD-01.6 — Planning Domain Need Generation Contract

**Status:** MVP contract v0.5; H0A5b and PANTRY-NG-02 persistence merged; RMVP-04 connected command/read/application implementation is in draft review

**Domain:** Planning

**Business owner:** Tổ Kế hoạch

**Parent architecture:** ARCH-001 — OPS ERP Business Architecture

**Decision:** [Decision PA-06E-H0A5 — Need Generation Run and Theoretical Lineage](../decisions/decision-pa-06e-h0a5-need-generation-lineage.md)

**Pantry amendment:** [PANTRY-NG-01 — Need Generation Direct Ingredient Amendment](pantry-ng-01-need-generation-direct-ingredient-amendment.md)

**Pantry decision:** [Decision PANTRY-NG-01](../decisions/decision-pantry-ng-01-need-generation-direct-ingredient.md)

## 1. Purpose

Need Generation converts one exact requested Planning input set into immutable, atomic theoretical ingredient contributions for later Planning confirmation. For the connected school-catering path, `service_date` is the authority grain: new Planning Input Sets, runs, and generated Confirmed Need batches use `period_start = period_end = service_date`. A week remains an input, navigation, and review projection only.

```text
one exact Planning Input Set
+ its exact current READY evaluation
+ exact immutable Menu, Attendance and Pantry evidence
+ exact eligible Recipe evidence
+ one approved fixed calculation-contract revision
= one controlled Need Generation run
+ atomic RECIPE_DERIVED and PANTRY_DIRECT Theoretical Need contributions
+ one immutable release snapshot when released
```

Planning Input Readiness answers whether exact approved Menu, Attendance and Pantry evidence is controlled and compatible. Need Generation answers which exact theoretical ingredient contributions result from that evidence. Recipe-derived contributions use the unchanged fixed Recipe calculation. Pantry-direct contributions copy exact approved Ingredient quantities without Recipe explosion. Confirmed Need remains the later Planning approval gate.

Need Generation does not confirm demand, group operational requirements, assign suppliers, rebalance Purchase Assignments, create purchase orders, mutate Warehouse stock, create Dispatch documents, edit Recipe/BOM data, perform QA/Production, or create Finance records.

## 2. Ownership and authoritative objects

Planning owns the run, run input snapshot, Theoretical Need lines, Need Generation issues, release snapshot and referenced Pantry evidence. Admin and Recipe retain ownership of every referenced School, Delivery Location, Dish, Recipe, RecipeVersion, RecipeLine, RecipeLineRevision, Ingredient, and Unit.

### 2.1 NeedGenerationRun

One run is one accepted generation attempt for one exact Planning Input Set and one exact current immutable H0A4b evaluation. It inherits the exact inclusive Planning Input Set period and cannot combine input sets or evaluations. For new connected school-catering generation, that exact period is one service date (`D..D`), so each date owns an independent linear run chain. A run is never split per School, Menu line, Recipe line, Ingredient, or contribution.

Historical multi-day runs remain immutable compatibility facts. They are not split, rewritten, deleted, or reinterpreted by the daily contract.

The run is a positive-version mutable control root. Generation starts at version 1. Each valid lifecycle transition increments the version exactly once. Generated facts are not mutable through that root.

Recalculation creates a new run after explicit predecessor invalidation. Runs for one Planning Input Set form at most one linear correction chain with a positive local attempt ordinal, one direct predecessor, at most one direct successor, no fork, no cycle, no self-link, and no cross-period/input-set link. Only the current terminal run may validate or release.

### 2.2 NeedGenerationInputSnapshot

Every run owns one immutable input-snapshot header and bounded typed use relations. They bind:

- exact Planning Input Set;
- exact Planning Input Evaluation and positive evaluation version;
- exact Weekly Menu approval snapshot/root/version inherited from that evaluation;
- exact Attendance approval snapshot/root/version inherited from that evaluation;
- exact Pantry approval snapshot/batch/version inherited from that evaluation, including a valid zero-line snapshot;
- one mandatory exact calculation-contract revision;
- exact selected Recipes and RecipeVersions;
- exact stable RecipeLines and RecipeLineRevisions used; and
- each exact future conversion revision actually used.

The merged H0A4b root has no `planningInputSetVersion`, and the exact evaluation ID/version replaces the prototype's generic `readinessSnapshotId`. Composite typed ownership must prevent substitution of any readiness-bound source snapshot. The Pantry family is exactly `pantry_need_batch_id`, `pantry_need_batch_version`, and `pantry_need_approval_snapshot_id`; every member is mandatory on a new Need Generation input snapshot.

Recipe selection evidence records exact typed IDs, including the Menu snapshot line, stable Menu line, School, SchoolType used when present, Dish, selected Recipe, and selected RecipeVersion. Composition-use evidence records each stable RecipeLine and exact RecipeLineRevision.

No generic input/reference registry, polymorphic text owner, caller-authored object type, JSON-only lineage, hash-only relation, name identity, token, or concatenated string is authoritative.

### 2.3 CalculationContractRevision

Every run binds one immutable approved revision identifying the fixed proportional-per-basis formula, operand order, source fields, numeric semantics, final storage coercion, and contract version.

It is not a generic formula engine, expression language, caller-supplied expression, yield/allowance rule, rounding policy, conversion rule, supplier rule, or Procurement rule.

### 2.4 TheoreticalNeedLine

Every line has one closed contribution source family:

```text
RECIPE_DERIVED
PANTRY_DIRECT
```

For `RECIPE_DERIVED`, one line remains one immutable atomic contribution for the exact combination of:

```text
run
+ Weekly Menu approval-snapshot line
+ Attendance approval-snapshot line
+ selected Recipe and RecipeVersion
+ stable RecipeLine and exact RecipeLineRevision
+ Ingredient
+ RecipeLineRevision source Unit
+ calculation-contract revision
+ conversion-rule revision when used
```

The line also retains the stable Weekly Menu and Attendance line anchors carried by the exact snapshot lines. Its opaque UUID is not derived from source strings. The complete atomic anchor is unique within the run with null conversion treated deterministically.

For `PANTRY_DIRECT`, every-and-only positive approved Pantry snapshot line whose `service_date` is between the exact run `period_start` and `period_end`, inclusive, creates one immutable `ACTIVE` atomic contribution for:

```text
run
+ exact Pantry approval snapshot
+ exact Pantry approval-snapshot line
+ stable Pantry line
+ exact School and Delivery Location
+ exact service date
+ exact Ingredient and approved Unit
```

An active Pantry-direct line has no Menu, Attendance, Dish, Recipe, RecipeVersion, RecipeLine, RecipeLineRevision or Recipe calculation-contract provenance. A valid Pantry-direct `REMOVED` line retains the successor Pantry snapshot header and stable Pantry line but has no fabricated current snapshot-line row. Strict conditional family checks must keep both lineage families mutually exclusive without weakening any existing Recipe-derived invariant.

Lines are not aggregated by Ingredient, School/date, Delivery Location, Unit, Pantry Purpose, Menu line, Recipe or RecipeLine. H0B1 may later group several released contributions inside one Confirmed Need line revision, but H0A5 performs no grouping or confirmation.

The line disposition is exactly `ACTIVE` or `REMOVED`. Quantity uses exact PostgreSQL `numeric(20,6)` in the exact source Unit. Pantry Purpose and approved source evidence remain reachable through the exact typed Pantry snapshot-line lineage and are never caller-authored identity.

### 2.5 NeedGenerationIssue

Each persisted issue belongs to one exact run and optionally one exact line plus typed context. Individual issue rows are immutable. New system-discovered validation/release-integrity issues may be appended by a later authorized transaction, but an issue cannot be edited, acknowledged, waived, overridden, resolved in place, reclassified, or deleted.

Need Generation owns only readiness-entry, run, Recipe-selection, calculation, theoretical-lineage, predecessor, and release classifications. It does not copy H0A4 warnings as mutable Need Generation issues.

### 2.6 NeedGenerationReleaseSnapshot

Release creates one immutable header for the exact resulting released run version, exact input snapshot, release actor/time, line/disposition counts, and exact issue summary.

Immutable release lines contain every-and-only releasable Theoretical Need line, including valid `ACTIVE` zero and valid `REMOVED` lines. Typed issue membership contains every-and-only issue in the release summary. Missing, extra, altered, duplicate, cross-run, wrong-version, or wrong-summary membership is invalid.

The release snapshot remains queryable after invalidation and successor generation. H0B1 consumes exact release rows through typed FKs and cannot edit H0A5 evidence.

## 3. Generation entry and readiness binding

Generation requires all of the following to remain true in one transaction:

- Planning Input Set root status is `NEED_GENERATION_REQUESTED`, not merely `READY`;
- the root's current pointer equals the exact expected evaluation;
- the immutable evaluation result is `READY` with zero blockers;
- its exact Menu, Attendance and Pantry source families are populated, including the Pantry header for valid controlled absence;
- all three upstream root versions and latest approval snapshots still equal the evaluation bindings;
- upstream statuses remain allowed by H0A4b; and
- all three source periods still contain the exact evaluated period.

`READY` is a readiness result, not the Need Generation entry state. A rejected precondition cannot create a partial run or incomplete input snapshot. H0A5 never edits the root, evaluation, bindings, or issues. The Pantry triple remains mandatory when its approved snapshot contains zero lines and when a positive approved snapshot contains zero positive lines inside the exact run period.

## 4. Fixed MVP formula and numeric contract

For each planned Menu line with one exact Attendance line and one selected eligible Recipe composition:

```text
portions
= student_portions + teacher_portions

theoretical source quantity
= portions
× exact RecipeLineRevision.quantity_per_basis
÷ exact released RecipeVersion.basis_portions
```

Rules:

1. Student and teacher portions come from the exact immutable Attendance approval-snapshot line and are summed before calculation.
2. Cast each integer portion to `bigint` before addition.
3. Recipe quantity, disposition, and positive basis come from the exact selected immutable released Recipe evidence.
4. Evaluate multiply then divide in PostgreSQL `numeric` without an intermediate typmod cast, truncation, binary float, or client arithmetic.
5. Coerce once to `numeric(20,6)`. PostgreSQL numeric scale coercion is the selected technical representation rule, including ties away from zero.
6. Reject invalid, negative, non-finite, failed, or final-storage-overflow results. Do not clamp or compare with epsilon.
7. Any persisted rule or conversion factor uses strictly positive `numeric(24,12)` when applicable. The fixed MVP formula has no configurable multiplier.
8. Zero portions create one warning-bearing `ACTIVE` zero line per otherwise valid `PRESENT` RecipeLineRevision. Zero is not omission or removal.

No Planning or purchase rounding, purchase-unit normalization, supplier rule, yield, allowance, waste, or generic formula engine is introduced. React and Retool are not authoritative calculators.

### 4.1 Pantry direct quantity pass-through

The fixed Recipe formula above remains unchanged and applies only to `RECIPE_DERIVED`.

For one active `PANTRY_DIRECT` contribution:

```text
theoretical_quantity
= exact Pantry approval-snapshot-line requested_quantity
```

The Unit, Ingredient, School, Delivery Location and service date equal the exact approved Pantry snapshot-line facts. PostgreSQL copies the strictly positive quantity exactly into `numeric(20,6)`. Pantry direct contribution performs no Attendance arithmetic, Recipe calculation, conversion, rounding, yield, waste, supplier rule, Warehouse rule or client arithmetic, and it does not claim that the Recipe calculation-contract revision produced the quantity.

Every positive Pantry snapshot line inside the exact inclusive run period produces exactly one active contribution. Positive lines outside that period remain historical source evidence through the bound Pantry snapshot header but create no theoretical line or Need Generation issue for the run, do not increment `generated_line_count` and are not release members.

A valid approved zero-line Pantry snapshot remains input-header evidence, produces no Pantry contribution or placeholder and is not an issue. Separately, an approved snapshot may contain positive lines but zero positive lines inside the exact run period; this valid period-filtered case retains the same exact header, is neither missing Pantry nor an explicit zero-line snapshot, and creates zero active Pantry contributions from the out-of-period lines. Absent an in-period predecessor obligation, it creates zero Pantry-direct theoretical lines; only required in-period `REMOVED` successor evidence under section 7.2 may still exist. A run may still contain Recipe-derived contributions.

## 5. Recipe selection

For each exact Menu snapshot line:

```text
one eligible Recipe for the Menu School's exact SchoolType
→ otherwise one eligible general Recipe
→ otherwise blocking issue
```

When the School has no SchoolType, the exact typed tier is empty and the general tier is evaluated. One eligible exact typed Recipe overrides an eligible general Recipe. General is used only when no exact typed Recipe is eligible.

A candidate is eligible only when:

- the exact Dish is `ACTIVE` and requires Need Generation;
- the Recipe belongs to that Dish, has the matching exact/null scope, and is `ACTIVE`;
- one exact current RecipeVersion is `RELEASED_FOR_PLANNING`;
- the basis is strictly positive;
- the exact released composition is complete;
- every required stable RecipeLine has the exact immutable RecipeLineRevision used; and
- active generated contributions reference valid active Ingredients and Units.

Historical `LOCKED` RecipeVersions explain old runs only and are not selected for new generation. Multiple eligible candidates in the chosen tier are blocking. Caller choice, UI/display order, names, UUID ordering, and arbitrary first-row selection are rejected.

H0A5 adds no expected-School/day or active-School/SchoolType policy. Later reference changes do not erase old calculation evidence.

## 6. Unit and conversion boundary

H0A5 output stays in the exact RecipeLineRevision source Unit. The calculation Unit equals that Unit, so the source-unit H0A5b slice uses no conversion and binds no conversion revision.

H0A5b must not create a conversion family, production conversion values, or an untyped placeholder UUID. A requested differing Unit fails closed until a separately approved immutable conversion family exists.

Every future used conversion must have typed exact from/to Unit FKs, a strictly positive finite `numeric(24,12)` factor, one exact approved relational scope, immutable revision identity, unambiguous effective applicability, and typed links from both run input evidence and the exact line. Names, implicit paths, current-row lookups without revision evidence, supplier fallback, and generic text scope are invalid.

Calculation-contract revision is mandatory for every run. Conversion-rule revision is present only when a real conversion occurs.

## 7. Typed source and correction lineage

### 7.1 Recipe-derived lineage

Mandatory cardinality-one source anchors are direct typed columns on the atomic line, supported by bounded typed run-use relations. A generic one-ID source registry is rejected.

Across directly linked successor runs, predecessor continuity requires the same stable Weekly Menu line, stable Attendance line, stable RecipeLine, Planning Input Set, and period. Exact snapshot lines, RecipeVersion/Revision, Ingredient, Unit, and quantity may change because those are correction facts.

Required correction behavior:

- quantity correction on the same stable RecipeLine has exactly one predecessor;
- Ingredient correction on the same stable RecipeLine has exactly one predecessor, while old/new Ingredient facts remain visible;
- an Attendance correction on the same stable Attendance line preserves one-to-one compatible RecipeLine continuity;
- a genuinely new stable RecipeLine contribution is `ACTIVE` with no predecessor;
- an explicit removal is `REMOVED`, exact zero, has exactly one predecessor, and binds one exact released H0A2 `REMOVED` RecipeLineRevision; and
- a prior `REMOVED` contribution remains immutable exact-zero historical evidence with its exact predecessor and H0A2 removal evidence, and need not be repeated while the same stable RecipeLine remains absent or outside the selected `PRESENT` composition.

One predecessor has at most one successor. Same-run, unrelated-chain, cross-period/input-set, cross-anchor, fork, split, and merge links are invalid. Every prior `ACTIVE` contribution must have one exact compatible `ACTIVE` or valid `REMOVED` successor. Silent omission is blocking. Menu/Dish/Recipe-family replacement that cannot preserve stable anchors is not treated as implicit removal.

Omission of a prior `REMOVED` contribution is valid only while the same stable RecipeLine does not reappear as `PRESENT` in the selected released Recipe composition.

Reintroduction of the same stable RecipeLine after a prior `REMOVED` theoretical contribution is unsupported in the first H0A5b slice. When one directly linked successor run for the same Planning Input Set and immutable period selects an H0A2 `PRESENT` RecipeLineRevision for the same stable RecipeLine whose direct-predecessor-run contribution was `REMOVED`, generation:

- does not treat the stable RecipeLine as genuinely new;
- does not create an `ACTIVE` line without a predecessor;
- does not infer a `REMOVED → ACTIVE` predecessor relation;
- records the `BLOCKING` classification `UNSUPPORTED_REINTRODUCTION_AFTER_REMOVAL`;
- keeps the run in `GENERATED` and prevents validation and release; and
- requires explicit invalidation and a later separately approved contract extension before the reintroduction can be generated successfully.

Only the exact typed direct run chain, Planning Input Set, period, stable RecipeLine, predecessor theoretical `REMOVED` disposition, and successor H0A2 `PRESENT` revision establish this case. Ingredient identity or name, line ordering, quantity equality, Recipe display order, hashes, JSON, UI state, and OPS v1 effective-needs rows do not.

A later separately approved decision may add explicit reintroduction support only after defining whether `REMOVED → ACTIVE` is one-to-one correction identity, exact predecessor ownership, release membership, issue and lifecycle effects, H0B1 contribution interpretation, and focused migration and pgTAP changes. H0A5a does not authorize that extension.

### 7.2 Pantry-direct lineage

Across directly linked successor runs for the same Planning Input Set and immutable exact period, predecessor and removal membership includes only stable Pantry lines represented by positive approved snapshot lines whose `service_date` is inside that period. The same in-period stable `PantryNeedLine` has exactly one compatible Pantry-direct predecessor. Quantity, Purpose, note, source reference, server-resolved Unit and exact snapshot-line facts may change while the stable Pantry line preserves continuity. A genuinely new stable Pantry line in the successor's in-period approved-line set creates one `ACTIVE` contribution without a predecessor.

A stable Pantry line that was active inside the exact period in the predecessor but is omitted from the successor's in-period approved-line set creates exactly one zero `REMOVED` contribution. It binds the same stable Pantry line, one predecessor and the successor Pantry approval snapshot as controlled absence; it does not fabricate a current snapshot-line row. Every prior active Pantry contribution inside that immutable run-period scope requires one compatible active or removed successor. Silent omission, fork, split, merge, cross-period/input-set or unrelated-line wiring inside the scope is blocking.

Positive snapshot lines outside the exact immutable run period do not participate in predecessor or removal completeness. They are not omissions, do not require predecessors, create neither `ACTIVE` nor `REMOVED` successors and do not trigger silent-omission or removal issues.

`REMOVED → ACTIVE` reintroduction of the same stable Pantry line is unsupported in the first slice. The existing `UNSUPPORTED_REINTRODUCTION_AFTER_REMOVAL` blocker applies, no active line is admitted as new or given an inferred predecessor, and validation/release remain prohibited pending invalidation and separate approval.

## 8. Issue classification

The exact closed catalog and severity are defined in [Decision PA-06E-H0A5](../decisions/decision-pa-06e-h0a5-need-generation-lineage.md#28-closed-issue-and-rejection-catalog).

The current Recipe-only H0A5 catalog contains exactly 35 design classifications, of which H0A5b persists the 31 post-entry codes. PANTRY-NG-01 preserves that catalog and adds only three Pantry-specific blocking codes: `MISSING_PANTRY_INPUT_BINDING`, `INVALID_PANTRY_SNAPSHOT_MEMBERSHIP`, and `PANTRY_APPROVED_QUANTITY_UNIT_MISMATCH`. Exact conditions and reuse mappings are canonical in [PNG-P10](../decisions/decision-pantry-ng-01-need-generation-direct-ingredient.md#png-p10--closed-issue-and-validation-effects).

`UNSUPPORTED_REINTRODUCTION_AFTER_REMOVAL` remains `BLOCKING` for Recipe-derived reintroduction and also applies when a directly linked Pantry successor reintroduces the same stable Pantry line after a removed contribution.

All stale-input, eligibility, factor/result, lineage, predecessor, removal, unsupported reintroduction, split/merge, Pantry input/membership/quantity/Unit and release failures are `BLOCKING`. `ZERO_ACTIVE_THEORETICAL_QUANTITY` remains the sole Recipe-derived H0A5 `WARNING`; it does not authorize zero Pantry lines. Pantry adds no warning. Warnings alone do not block validation or release.

## 9. Closed lifecycle

The status set is exactly:

```text
GENERATED
VALIDATED
RELEASED_FOR_CONFIRMATION
INVALIDATED
```

Allowed transitions are exactly:

```text
GENERATED → VALIDATED
GENERATED → INVALIDATED
VALIDATED → RELEASED_FOR_CONFIRMATION
VALIDATED → INVALIDATED
RELEASED_FOR_CONFIRMATION → INVALIDATED
```

Generation creates version 1. Each valid transition increments exactly once. Release binds the resulting released run version. All other transitions, same-state mutation, direct resurrection, and nonterminal predecessor progression are rejected.

Validation requires the current terminal run, zero blockers, and complete every-and-only calculation, typed source, predecessor and count evidence across both contribution families. Release requires `VALIDATED`, zero blockers, and one every-and-only immutable release snapshot. Release does not create Confirmed Need.

Invalidation preserves all evidence and does not automatically create a successor. Recalculation creates a new run after invalidation. Menu, Attendance, readiness, Recipe, Dish, Ingredient, Unit, calculation-contract, or future conversion changes do not rewrite or automatically invalidate a run.

Actual operations/commands, actor authorization, reasons, events, receipts, safe errors, and API/read surfaces remain later tasks.

## 10. Release and downstream boundary

Release membership includes every-and-only immutable Recipe-derived and Pantry-direct run line and proves exact contribution family, quantity, Unit, disposition, predecessor and typed source facts. Recipe-derived members retain calculation and optional conversion revisions. Pantry-direct members retain exact Pantry snapshot/stable-line lineage, exact current snapshot line when active, and exact School, Delivery Location, service date and Ingredient. Release issue membership proves the exact combined summary. Release facts are immutable after creation and remain retained after invalidation or successor generation.

Confirmed Need remains a later Planning-owned aggregate and approval gate. Existing materialization may consume both families through the existing `NEED_GENERATION` source kind and may group multiple released atomic contributions only through immutable membership and exact totals when the complete operational identity matches. A Pantry-direct member contributes its exact Pantry Delivery Location; materialization must not silently substitute the School's current default. H0A5 performs no grouping, review, adjustment, approval, or release to Procurement.

Procurement cannot edit or consume unreleased theoretical lines as approved demand. Purchase Assignment rebalance is downstream Procurement behavior and is not part of Need Generation.

## 11. OPS v1 and prototype compatibility

OPS v1 effective-needs views and Retool direct joins are qualitative evidence only. They do not define a run, input snapshot, atomic line, predecessor, release snapshot, calculation rule, conversion rule, API, or ID.

The TypeScript prototype remains a non-authoritative UI/domain demonstration. H0A5 supersedes its Ready-or-requested entry, root version, generic readiness ID, first active Recipe, `number` arithmetic, quantity-per-portion shortcut, concatenated trace, mutable line status, and line-array release membership assumptions.

## 12. H0A5b persistence and tests

H0A5b currently implements the Recipe-derived persistence model in migration `20260721070121_pa_06e_h0a5b_need_generation_persistence.sql`. Its four independently runnable pgTAP suites remain the current Recipe-only authority for structure/security, run/input/Recipe/calculation, theoretical-line/source/predecessor/release, and lifecycle/issues/invalidation/history.

PANTRY-NG-01 changes documentation only. Current H0A5b SQL has no contribution-family discriminator, no Pantry input triple and Recipe-mandatory theoretical-line columns. It therefore remains Recipe-only until a separately authorized migration and focused pgTAP amendment merge.

That later implementation task must define exact physical names and exact `plan(N)` counts before coding for exclusive invariant families covering:

1. H0A5 structure/security;
2. H0A5 run/input/recipe/calculation integrity;
3. H0A5 theoretical-line/source/predecessor/release integrity; and
4. H0A5 lifecycle/issues/invalidation/history.

Every invariant has one owner only. Each suite owns its transaction, deterministic noncolliding fixtures, exact plan, `finish()`, rollback, one exact-path workflow command, `Files=1`, exact assertion count, and `Result: PASS`. H0A1–H0A4 tests remain unchanged.

Only the H0A5 theoretical-line/source/predecessor/release integrity suite owns assertions that a prior removed line may be omitted while the stable RecipeLine remains absent, the prior removed line remains immutable, a reintroduced `PRESENT` stable RecipeLine is neither accepted as new nor given an inferred predecessor, the exact blocker is required, validation and release fail, and unrelated genuinely new stable RecipeLines remain valid without predecessors.

## 13. Scope and migration effect

PANTRY-NG-01 changes documentation only. It creates no migration, SQL, pgTAP, workflow, function, RPC, role, capability, policy, event, reason, receipt, API/read model, generated type, React behavior, package, Retool change, OPS v1 change, hosted Supabase action, production data, credential, deployment, Confirmed Need, Procurement, Warehouse, Dispatch, QA, Production, or Finance behavior.

Documentation rollback is a normal Git revert. The Pantry persistence amendment and every command/runtime/application/downstream change require separate authorization.
