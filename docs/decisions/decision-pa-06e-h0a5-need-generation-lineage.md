# Decision PA-06E-H0A5 — Need Generation Run and Theoretical Lineage

**Status:** Accepted for the bounded H0A5a design under Issue #129; H0A5b persistence remains separately authorized work

**Date:** 2026-07-21

**Issue:** [#129](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/129)

**Owner:** Planning, consuming Admin and Recipe evidence read-only

**Implementation task:** [TASK-PA-06E-H0A5a](../implementation-tasks/TASK-PA-06E-H0A5a-need-generation-decision.md)

**Parent architecture:** [PA-06E-H0 School-Catering Persistence and Materialization](../architecture/pa-06e-h0-school-catering-persistence-and-materialization-contract.md)

## 1. Context and governing method

H0A2 supplies stable Recipe and RecipeLine identities, immutable RecipeVersion and RecipeLineRevision evidence, the fixed `PROPORTIONAL_PER_BASIS` calculation kind, and explicit `REMOVED` recipe-line successors. H0A3a and H0A3b supply immutable Weekly Menu and Attendance approval snapshots and stable source-line identities. H0A4b supplies one stable exact-period Planning Input Set, one exact current immutable evaluation, and direct typed Weekly Menu and Attendance snapshot bindings.

Need Generation must now convert that exact controlled evidence into immutable, atomic Theoretical Need contributions without allowing the old TypeScript prototype, Retool, or OPS v1 to invent identity, selection, arithmetic, conversion, grouping, or correction policy.

The decision follows OPS_SYSTEM_MAP v1.0:

```text
Mission
→ Business Capability
→ Business Domain
→ Business Object
→ Business Contract
→ Command/Event
→ Read Model
→ Application
→ Technology
```

The selected placement is:

| Layer               | H0A5 decision                                                                                                                                          |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Mission             | Preserve an explainable school-catering quantity from exact controlled inputs to later Planning confirmation.                                          |
| Business capability | Generate, validate, release, invalidate, and correct theoretical ingredient contributions.                                                             |
| Business domain     | Planning owns the run, generated facts, issues, and release evidence; Admin/Recipe retain ownership of referenced facts.                               |
| Business object     | Need Generation run, run input snapshot, fixed calculation-contract revision, typed Recipe uses, Theoretical Need lines, issues, and release snapshot. |
| Business contract   | This decision and the amended PD-01.6 contract.                                                                                                        |
| Command/event       | Deferred. H0A5a and H0A5b add no callable command, reason, event, receipt, or audit contract.                                                          |
| Read model          | Deferred. H0A5a and H0A5b add no browser or public read surface.                                                                                       |
| Application         | None. The prototype is non-authoritative evidence only.                                                                                                |
| Technology          | A later bounded private PostgreSQL persistence slice with focused pgTAP; no SQL is authorized here.                                                    |

The retained OPS v1/Retool evidence shows effective-needs views and direct joins to Schools, Ingredients, overrides, Suppliers, and Purchase Assignments, including downstream rebalance. It contains no authoritative immutable run, run-owned input snapshot, released atomic membership, typed predecessor chain, or calculation-contract revision. View rows, ingredient aggregates, Retool rows, family/group tokens, names, concatenated strings, UI overrides, and direct `public` SQL are therefore rejected as Atlas identity or authority.

## 2. Decision

### 2.1 One run is one generation attempt

```text
one NeedGenerationRun
= one accepted generation attempt
for one exact PlanningInputSet
and one exact current immutable readiness evaluation
```

The run is not split by School, Menu line, Attendance line, Dish, Recipe, RecipeLine, Ingredient, Unit, or output contribution. It cannot combine Planning Input Sets or readiness evaluations. Its inclusive period is inherited exactly from its Planning Input Set root and is not independently selectable.

An accepted generation attempt creates a new run. A request rejected before the readiness gate is not a run and cannot create a partial input snapshot. Recalculation never refreshes or reuses a prior run; it creates a distinct successor run.

The run root is a mutable positive-version aggregate only for lifecycle control and controlled counts. Its generated lines, input evidence, typed source relations, and individual issue facts are immutable. Release creates separate immutable release evidence. Invalidation preserves every prior fact and never deletes or rewrites a released calculation.

#### Generation entry gate

Generation succeeds past its entry gate only when, in one authoritative transaction:

- the exact Planning Input Set root is `NEED_GENERATION_REQUESTED`, not merely `READY`;
- the root still points to the exact evaluation named by the request;
- that immutable evaluation result is `READY`;
- its positive `evaluation_version` is exact;
- both direct Weekly Menu and Attendance approval-snapshot/root/version families are populated;
- both source families still satisfy the H0A4b current-version, latest-snapshot, allowed upstream-state, and period-containment rules; and
- the evaluation contains zero blocking readiness issues.

The stable Need Generation classifications for entry rejection are `READINESS_ROOT_NOT_REQUESTED`, `CURRENT_READINESS_EVALUATION_NOT_READY`, `STALE_READINESS_EVALUATION`, and `STALE_READINESS_SOURCE_SNAPSHOT`. Because a rejected request cannot own a complete immutable run input snapshot, those classifications remain pre-run failure classifications until a later command/receipt contract decides how rejection evidence is persisted. They are not copied H0A4 issue rows.

#### Run correction chain

Runs for one Planning Input Set form at most one linear correction chain:

- the first run has no predecessor and is attempt 1;
- each later recalculation names exactly the current terminal run as its direct predecessor and advances the positive Planning-Input-Set-local attempt ordinal by one;
- the predecessor must already be `INVALIDATED` before the successor is created;
- the predecessor and successor use the same `planning_input_set_id` and therefore the same immutable period;
- a successor may bind a later exact readiness evaluation of that same Planning Input Set;
- one predecessor has at most one successor, so a correction fork is rejected;
- a run cannot name itself, a later run, an unrelated Planning Input Set, or a run from another period;
- the strictly increasing local attempt ordinal and direct-predecessor ownership reject cycles; and
- after a successor exists, the predecessor is nonterminal and cannot be validated, released, resurrected, or reused.

Only the current terminal run in the correction chain may advance to `VALIDATED` or `RELEASED_FOR_CONFIRMATION`. A prior release remains historical after invalidation, but it is never made current again.

### 2.2 One immutable run-owned input snapshot

Every run owns exactly one immutable input-snapshot header plus bounded typed child/use relations. Together they bind directly and relationally to:

- exact `planning_input_set_id`;
- exact `planning_input_evaluation_id` and positive `evaluation_version`;
- exact Weekly Menu approval snapshot, Weekly Menu root, and Weekly Menu version copied from that evaluation;
- exact Attendance approval snapshot, Attendance root, and Attendance version copied from that evaluation;
- one mandatory exact immutable calculation-contract revision;
- every selected Recipe root and exact RecipeVersion;
- every stable RecipeLine and exact RecipeLineRevision actually used;
- the exact SchoolType value used for Recipe precedence when the Menu School has one; and
- every exact conversion-rule revision actually used, of which there are none in the source-unit H0A5b slice.

The snapshot header must use a typed ownership reference to the exact H0A4b evaluation tuple. Its Menu and Attendance triples must equal the evaluation's triples through composite relational enforcement; a run cannot substitute another snapshot, root, or version. The run does not have a `planningInputSetVersion` because the merged H0A4b root has no version, and it does not have a generic `readinessSnapshotId` because the exact evaluation ID/version is the authoritative readiness identity.

Recipe selection is recorded as immutable typed run-use evidence, normally one selection fact per exact Weekly Menu approval-snapshot line. The relation records the exact Menu snapshot line, stable Menu line, School, Dish, SchoolType used when present, selected Recipe, and exact selected RecipeVersion. Recipe composition use is recorded through exact stable RecipeLine and RecipeLineRevision references. Copying current Recipe names or mutable fields is never the only evidence.

The selected physical direction is a bounded combination:

1. direct typed cardinality-one columns on the run input snapshot and atomic theoretical line; and
2. typed Recipe-selection, Recipe-composition-use, and future conversion-use child relations where one run owns many facts.

A generic input registry, polymorphic text owner, caller-authored object type, JSON-only trace, hash-only relation, name match, family token, or concatenated ID is rejected. Hashes may support diagnostics but never replace typed relationships. Input evidence remains queryable after upstream reopen/correction, run invalidation, or successor creation.

### 2.3 Fixed MVP calculation contract and numeric semantics

The exact fixed MVP formula is:

```text
portions
= AttendanceSnapshotLine.student_portions
+ AttendanceSnapshotLine.teacher_portions

theoretical source quantity
= portions
× exact RecipeLineRevision.quantity_per_basis
÷ exact released RecipeVersion.basis_portions
```

The operation order is multiply, then divide. Student and teacher portions are summed before calculation. The Attendance values come only from the exact immutable Attendance approval-snapshot line. Recipe quantity, line disposition, and basis come only from the exact immutable released Recipe evidence selected for the run.

Numeric behavior is closed as follows:

1. Cast each nonnegative Attendance integer to `bigint`, then add, so integer addition cannot overflow at the PostgreSQL `integer` boundary.
2. Require `basis_portions > 0`. Require an `ACTIVE` source RecipeLineRevision to be the H0A2 `PRESENT` disposition with strictly positive `quantity_per_basis`. A theoretical `REMOVED` successor uses exact H0A2 `REMOVED` evidence and its exact zero quantity.
3. Evaluate `(portions::numeric * quantity_per_basis::numeric) / basis_portions::numeric` in PostgreSQL `numeric` with no intermediate typmod cast, truncation, JavaScript number, or client-side arithmetic.
4. Reject a negative, non-finite, failed, or otherwise invalid intermediate result.
5. Coerce exactly once at the storage boundary to `numeric(20,6)`. PostgreSQL numeric scale coercion is the selected technical representation rule: excess fractional digits round to scale 6, with numeric ties away from zero. This is not a configurable Planning rounding or purchase-unit rounding policy.
6. If the final value cannot fit the 14 integer digits and 6 fractional digits of `numeric(20,6)`, generation records `NEGATIVE_OR_INVALID_CALCULATION_RESULT` and fails closed for that run. There is no clamp, saturation, fallback, or epsilon comparison.

Operational theoretical quantity is stored as `numeric(20,6)`. Any persisted rule or conversion factor uses `numeric(24,12)` and must be strictly positive when applicable. The MVP proportional formula has no configurable multiplier; its exact H0A2 quantity and integer basis remain the authoritative operands. No hidden intermediate factor may replace the selected expression.

Zero portions produce one `ACTIVE` zero-quantity contribution for every otherwise eligible `PRESENT` RecipeLineRevision and one `ZERO_ACTIVE_THEORETICAL_QUANTITY` warning per such contribution. Zero never means omission or removal. A positive exact result that scale-coerces to zero is also an `ACTIVE` zero with the same warning; its typed trace preserves the nonzero operands.

The mandatory calculation-contract revision identifies the approved fixed formula kind, operand order, source fields, numeric types/scales, final coercion behavior, and contract version. It is not an expression language, formula text supplied by a caller, or generic formula engine. A different formula or numeric policy requires a later approved revision and new runs; it never recalculates existing lines.

No yield, allowance, waste, supplier rule, purchase packaging, purchase-unit conversion, procurement normalization, or additional rounding formula is part of H0A5. React and Retool may display results but are never authoritative arithmetic engines.

### 2.4 Recipe selection precedence and eligibility

For each exact Weekly Menu approval-snapshot line, resolve the Menu School's exact typed SchoolType when one is present and select:

```text
one eligible Recipe for the exact SchoolType
→ otherwise one eligible general Recipe
→ otherwise blocking issue
```

Caller selection, UI order, display order, name order, UUID order, or “first row” is never authoritative. A general Recipe is considered only when there is no eligible exact typed Recipe. One eligible typed Recipe overrides any eligible general Recipe.

A Recipe is eligible for new generation only when all of the following are true:

- the exact Menu Dish exists, is `ACTIVE`, and `requires_need_generation = true`;
- the Recipe belongs to that exact Dish;
- the Recipe is `ACTIVE`;
- its scope is either the exact SchoolType or null for the general fallback;
- it has one exact current `RELEASED_FOR_PLANNING` RecipeVersion;
- that version has a strictly positive basis;
- its required composition is complete under H0A2;
- every composition contribution used by generation has one exact immutable RecipeLineRevision in that released version; and
- every newly generated `ACTIVE` contribution references an active valid Ingredient and Unit.

Historical `LOCKED` RecipeVersions remain valid only to interpret old runs. New generation never selects a locked superseded version. A current active Recipe root without an eligible current released composition does not outrank an eligible fallback Recipe. If no eligible candidate exists because a candidate lacks a usable released composition, the exact blocker explains that condition instead of silently selecting historical or partial data.

More than one eligible exact typed Recipe is `AMBIGUOUS_ELIGIBLE_RECIPE`. If there is no eligible typed Recipe, more than one eligible general Recipe is the same blocker. There is no operator choice inside Need Generation.

H0A5 adds no expected-School/day or active-School/SchoolType policy. The exact typed School and SchoolType selection fact is captured for explanation, while H0A5 does not reinterpret the upstream approved Menu. Inactive Dish, Recipe, Ingredient, or Unit references block new generation as classified below but never erase or invalidate historical released calculation evidence automatically.

### 2.5 Source Unit and conversion boundary

The selected H0A5 rule is source-unit output:

- every Theoretical Need line retains the exact Unit from its RecipeLineRevision;
- the calculation Unit equals that source Unit;
- no conversion is performed;
- no purchase Unit, supplier-specific Unit, Procurement normalization, or rounding is performed; and
- conversion-rule revision is absent only because the from/to Units are identical and no conversion occurs.

The first H0A5b persistence slice must not create a production conversion family or conversion values. It also must not add an untyped nullable conversion UUID merely as a placeholder. If a differing controlled calculation Unit is requested, generation fails with `MISSING_REQUIRED_CONVERSION_RULE` until a separate approved immutable conversion-rule family and typed relation are migrated.

A future conversion revision, before it can be used, must bind through typed FKs to one exact from Unit, one exact to Unit, one strictly positive finite `numeric(24,12)` factor, one exact approved relational scope, an immutable revision identity, and unambiguous effective applicability. It may not use names, an implicit path, a current-row lookup without revision evidence, fallback scope, supplier policy, or caller-authored scope type. Every used future conversion must be linked from the run input evidence and the exact theoretical line. Those future requirements do not block a source-unit-only H0A5b.

The mandatory calculation-contract revision and optional conversion-rule revision are different concepts. Every run has the former. A line has the latter only when a real conversion occurs; the source-unit H0A5b slice has none.

### 2.6 Atomic Theoretical Need contribution grain and typed source shape

One immutable Theoretical Need line represents one exact source combination equivalent to:

```text
Need Generation run
+ exact Weekly Menu approval-snapshot line
+ exact Attendance approval-snapshot line
+ selected Recipe
+ exact selected RecipeVersion
+ stable RecipeLine
+ exact RecipeLineRevision
+ exact Ingredient
+ exact source Unit
+ exact calculation-contract revision
+ exact conversion-rule revision when one is used
```

The line also retains the stable Weekly Menu line and stable Attendance line carried by the two snapshot lines. Those stable anchors support correction matching while the exact snapshot-line IDs preserve the actual facts used.

The selected physical direction is direct typed source columns for the mandatory one-to-one anchors, supported by the run-owned typed use relations from section 2.2. A separate generic one-ID `theoretical_need_line_sources` registry is rejected. If H0A5b uses small typed child relations for index or ownership reasons, each relation must have a fixed source family and typed FK; it cannot be a polymorphic source row.

Within one run, the complete atomic anchor is unique with null conversion treated deterministically. Duplicate Menu/Attendance/RecipeLine source anchors are rejected even when names, quantities, or generated order differ. Theoretical line identity is an opaque UUID and never derives from names, order, hashes, family tokens, or concatenated source strings.

No aggregation occurs by Ingredient, School, date, Dish, Menu line, Recipe, or RecipeLine. Several released atomic contributions may later be members of one H0B1 operational Confirmed Need line revision, but H0A5 performs no grouping, confirmation, supplier assignment, or Procurement action.

### 2.7 Correction predecessor and disposition semantics

The Theoretical Need disposition set is closed:

```text
ACTIVE
REMOVED
```

`ACTIVE` quantity is nonnegative. `ACTIVE` zero is a real contribution and is warning-bearing; it is never removal. `REMOVED` quantity is exactly zero, requires exactly one direct predecessor Theoretical Need line, and requires one exact released H0A2 RecipeLineRevision whose `line_disposition = 'REMOVED'`. A first-run or genuinely new contribution cannot enter as `REMOVED`.

Predecessor matching is allowed only between directly linked predecessor/successor runs and requires compatible stable anchors:

- same stable Weekly Menu line;
- same stable Attendance line;
- same stable RecipeLine;
- same Planning Input Set and period through the run chain; and
- exact current snapshot and revision evidence on each side.

The exact Menu snapshot line, Attendance snapshot line, RecipeVersion, RecipeLineRevision, Ingredient, Unit, and quantity may differ between the two facts because those are the facts being corrected. The stable anchors, not ingredient/name/order coincidence, establish continuity.

Required outcomes are:

| Correction                                                           | Successor rule                                                                                          |
| -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| Quantity correction on the same stable RecipeLine                    | Exactly one successor points to the prior line.                                                         |
| Ingredient correction on the same stable RecipeLine                  | Exactly one successor points to the prior line; old and new Ingredient facts remain separately visible. |
| Attendance correction on the same stable Attendance line             | Each compatible RecipeLine contribution has exactly one successor.                                      |
| New stable RecipeLine contribution                                   | New `ACTIVE` line with no predecessor.                                                                  |
| Released H0A2 RecipeLine removal                                     | One zero `REMOVED` line with exactly one predecessor and exact `REMOVED` revision evidence.             |
| Previously `REMOVED` line while the stable RecipeLine remains absent | Retained as immutable historical evidence and need not be repeated in later runs.                       |

One predecessor has at most one successor. Same-run predecessor, unrelated run-chain predecessor, unrelated period or Planning Input Set, cross-Menu/Attendance/RecipeLine wiring, fork, split, and merge are rejected. A successor cannot merge two predecessors, and two successors cannot split one predecessor.

Every prior `ACTIVE` contribution in the direct predecessor run must have exactly one compatible active or removed successor unless it is proven outside the successor's source scope by a separately approved typed rule. H0A5 approves no such omission rule, so silent omission blocks release. Menu/Dish replacement, removed Menu or Attendance lines, or Recipe-family changes that cannot preserve the required stable anchors do not receive an inferred removal; they fail closed pending a later approved correction policy.

A prior `REMOVED` contribution remains immutable historical evidence with exact zero quantity, its exact predecessor, and its exact released H0A2 removal evidence. It may be absent from a later run only while the same stable RecipeLine remains absent or otherwise outside the selected `PRESENT` composition. It is not automatically a predecessor for a new active contribution.

Omission of a prior `REMOVED` contribution is valid only while the same stable RecipeLine does not reappear as `PRESENT` in the selected released Recipe composition.

Reintroduction of the same stable RecipeLine after a prior `REMOVED` theoretical contribution is unsupported in the first H0A5b slice. For one directly linked predecessor/successor Need Generation run pair on the same Planning Input Set and immutable period, when the direct predecessor run contains a `REMOVED` theoretical contribution and the successor selects an H0A2 `PRESENT` RecipeLineRevision for that same stable RecipeLine:

- the reappearing contribution is not genuinely new;
- no `ACTIVE` line is created without a predecessor;
- no `REMOVED → ACTIVE` predecessor relation is inferred;
- the run records `UNSUPPORTED_REINTRODUCTION_AFTER_REMOVAL` and remains `GENERATED` with a blocker;
- validation and release are prohibited; and
- the run requires explicit invalidation before a later approved contract extension can generate the reintroduction successfully.

The restriction is established only by the direct run chain plus exact typed Planning Input Set, period, stable RecipeLine, predecessor `REMOVED` theoretical disposition, and successor H0A2 `PRESENT` revision evidence. It must not be inferred from Ingredient identity or name, line or Recipe display order, quantity equality, hashes, JSON, UI state, or OPS v1 effective-needs rows.

A later separately approved decision may introduce explicit reintroduction support. It must define whether `REMOVED → ACTIVE` is one-to-one correction identity, exact predecessor ownership, release membership, issue and lifecycle effects, H0B1 contribution interpretation, and focused migration and pgTAP changes. H0A5a does not authorize that extension.

### 2.8 Closed issue and rejection catalog

Need Generation owns only readiness-entry, run, Recipe-selection, calculation, source-lineage, predecessor, and release classifications. It does not copy H0A4 warnings into mutable Need Generation issues. Where the same business observation matters to calculation, Need Generation records its own exact result, such as one zero `ACTIVE` contribution warning.

Each persisted issue belongs to one exact run and optionally one exact theoretical line plus typed context. An issue row is immutable after insertion. A later system transaction may append a newly discovered validation or release-integrity issue, but it may not edit, acknowledge, waive, resolve, reclassify, or delete an issue. A run with a newly appended blocker cannot progress and requires invalidation plus a successor. Duplicate contextual issue facts are rejected.

The catalog is closed at exactly 35 codes:

| Issue code                                          | Severity | Exact condition                                                                                                                                                                                          |
| --------------------------------------------------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `READINESS_ROOT_NOT_REQUESTED`                      | BLOCKING | The exact Planning Input Set root is not `NEED_GENERATION_REQUESTED` at generation entry.                                                                                                                |
| `CURRENT_READINESS_EVALUATION_NOT_READY`            | BLOCKING | The root's exact current immutable evaluation result is not `READY` or has blockers.                                                                                                                     |
| `STALE_READINESS_EVALUATION`                        | BLOCKING | The expected evaluation ID/version is not the root's exact current evaluation.                                                                                                                           |
| `STALE_READINESS_SOURCE_SNAPSHOT`                   | BLOCKING | Either evaluation-bound Menu or Attendance root/version/snapshot is no longer current under H0A4b at generation time.                                                                                    |
| `MISSING_ATTENDANCE_SNAPSHOT_LINE`                  | BLOCKING | One planned Menu School/date lacks the exact Attendance approval-snapshot line needed by the formula.                                                                                                    |
| `MISSING_ELIGIBLE_RECIPE`                           | BLOCKING | No active exact-scope or general Recipe candidate exists for the exact Dish.                                                                                                                             |
| `AMBIGUOUS_ELIGIBLE_RECIPE`                         | BLOCKING | More than one eligible candidate exists in the selected exact-scope tier or, when that tier is empty, the general tier.                                                                                  |
| `MISSING_OR_INCOMPLETE_RELEASED_RECIPE_COMPOSITION` | BLOCKING | Candidate roots exist but no selected candidate has one exact current released and complete composition.                                                                                                 |
| `INVALID_NONPOSITIVE_RECIPE_BASIS`                  | BLOCKING | The selected exact RecipeVersion basis is missing, invalid, or not strictly positive.                                                                                                                    |
| `MISSING_EXACT_RECIPE_LINE_REVISION`                | BLOCKING | A required stable RecipeLine lacks its exact immutable revision in the selected released version.                                                                                                        |
| `INACTIVE_OR_INVALID_DISH`                          | BLOCKING | The exact Dish is missing, inactive, mismatched, or not eligible for Need Generation.                                                                                                                    |
| `INACTIVE_OR_INVALID_RECIPE`                        | BLOCKING | The selected Recipe is missing, inactive, cross-Dish/cross-scope, or otherwise invalid for new generation.                                                                                               |
| `INACTIVE_OR_INVALID_INGREDIENT`                    | BLOCKING | A newly generated contribution's exact Ingredient is missing or inactive.                                                                                                                                |
| `INACTIVE_OR_INVALID_UNIT`                          | BLOCKING | A newly generated contribution's exact source Unit is missing or inactive.                                                                                                                               |
| `MISSING_REQUIRED_CONVERSION_RULE`                  | BLOCKING | A differing calculation Unit is requested without one exact eligible typed conversion revision.                                                                                                          |
| `INVALID_CONVERSION_FACTOR`                         | BLOCKING | A required conversion factor is missing, nonpositive, non-finite, ambiguous, wrong-direction, wrong-scope, or wrong-version.                                                                             |
| `NEGATIVE_OR_INVALID_CALCULATION_RESULT`            | BLOCKING | Arithmetic fails, overflows final `numeric(20,6)`, or produces a negative/non-finite/invalid result.                                                                                                     |
| `MISSING_TYPED_SOURCE_TRACE`                        | BLOCKING | Any mandatory direct typed input, selection, snapshot-line, RecipeLine, revision, Ingredient, Unit, or rule relation is absent or cross-wired.                                                           |
| `DUPLICATE_ATOMIC_SOURCE_ANCHOR`                    | BLOCKING | More than one line in the run claims the same complete atomic source anchor.                                                                                                                             |
| `INVALID_PREDECESSOR`                               | BLOCKING | A predecessor is same-run, unrelated, cross-period/input-set, non-direct, anchor-incompatible, or otherwise invalid.                                                                                     |
| `PREDECESSOR_FORK`                                  | BLOCKING | One prior theoretical line or run is claimed by more than one direct successor.                                                                                                                          |
| `UNSUPPORTED_SPLIT`                                 | BLOCKING | One predecessor contribution would need multiple successor contributions.                                                                                                                                |
| `UNSUPPORTED_MERGE`                                 | BLOCKING | One successor contribution would need multiple predecessors.                                                                                                                                             |
| `SILENT_PREDECESSOR_OMISSION`                       | BLOCKING | A prior `ACTIVE` contribution has no exact compatible `ACTIVE` or valid `REMOVED` successor.                                                                                                             |
| `INVALID_REMOVAL_EVIDENCE`                          | BLOCKING | A `REMOVED` line is new, nonzero, lacks one predecessor, or lacks exact released H0A2 `REMOVED` revision evidence.                                                                                       |
| `UNSUPPORTED_REINTRODUCTION_AFTER_REMOVAL`          | BLOCKING | A directly linked successor Need Generation run selects a `PRESENT` RecipeLineRevision for a stable RecipeLine whose corresponding theoretical contribution in the direct predecessor run was `REMOVED`. |
| `ZERO_ACTIVE_THEORETICAL_QUANTITY`                  | WARNING  | An otherwise valid `ACTIVE` contribution stores exactly zero; zero Attendance is the expected case.                                                                                                      |
| `RELEASE_ATTEMPTED_WITH_BLOCKING_ISSUES`            | BLOCKING | Release is attempted while any run blocker exists.                                                                                                                                                       |
| `RELEASE_MEMBERSHIP_MISSING`                        | BLOCKING | A releasable run line is absent from the release snapshot.                                                                                                                                               |
| `RELEASE_MEMBERSHIP_EXTRA`                          | BLOCKING | The release snapshot contains a row that is not one releasable line of the run.                                                                                                                          |
| `RELEASE_MEMBERSHIP_ALTERED`                        | BLOCKING | Quantity, Unit, disposition, predecessor, or typed source facts differ from the immutable generated line.                                                                                                |
| `RELEASE_MEMBERSHIP_DUPLICATED`                     | BLOCKING | One run line appears more than once in release membership.                                                                                                                                               |
| `RELEASE_MEMBERSHIP_CROSS_RUN`                      | BLOCKING | A release member belongs to another run or correction chain.                                                                                                                                             |
| `RELEASE_MEMBERSHIP_WRONG_VERSION`                  | BLOCKING | Header or member does not bind the exact released run version.                                                                                                                                           |
| `RELEASE_ISSUE_SUMMARY_MISMATCH`                    | BLOCKING | Release issue membership/counts do not equal every-and-only immutable issue facts at release.                                                                                                            |

All stale-input, eligibility, invalid-factor/result, lineage, predecessor, split/merge, removal, unsupported reintroduction, and incomplete-release failures are blocking. The sole H0A5 warning is `ZERO_ACTIVE_THEORETICAL_QUANTITY`. Warnings alone do not prevent validation or release. H0A5 introduces no acknowledgement, waiver, override, or operator-editable resolution workflow.

### 2.9 Closed lifecycle and run-version behavior

The run status set is exactly:

```text
GENERATED
VALIDATED
RELEASED_FOR_CONFIRMATION
INVALIDATED
```

Valid transitions and version effects are exactly:

| Current                     | Next                        | Preconditions and immutable effect                                                                             | Run version                                                   |
| --------------------------- | --------------------------- | -------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| creation                    | `GENERATED`                 | Entry gate passes; create one run, complete input snapshot, immutable lines, and generation issues atomically. | Start at 1.                                                   |
| `GENERATED`                 | `VALIDATED`                 | Current terminal run; zero blockers; complete calculation, typed lineage, predecessor, and count evidence.     | Increment exactly once.                                       |
| `GENERATED`                 | `INVALIDATED`               | Preserve input, lines, issues, and any validation-attempt evidence.                                            | Increment exactly once.                                       |
| `VALIDATED`                 | `RELEASED_FOR_CONFIRMATION` | Current terminal run; zero blockers; create one complete immutable release snapshot in the same transaction.   | Increment exactly once; release binds this resulting version. |
| `VALIDATED`                 | `INVALIDATED`               | Preserve validation and all immutable facts.                                                                   | Increment exactly once.                                       |
| `RELEASED_FOR_CONFIRMATION` | `INVALIDATED`               | Preserve release header, release lines, issue membership, sources, and prior lifecycle evidence.               | Increment exactly once.                                       |

Every other transition is rejected. Same-state updates, direct `GENERATED → RELEASED_FOR_CONFIRMATION`, resurrection of `INVALIDATED`, and transition of a nonterminal predecessor are invalid. A failed validation or release attempt does not change status. If it appends one new immutable integrity issue, the controlled run version and counts advance exactly once in that future transaction; otherwise no run field changes.

Generation issues are immutable evidence rather than a queue to resolve in place. Therefore a `GENERATED` run with a blocker cannot later become valid by editing an issue or line; it must be invalidated and replaced by a successor run.

No upstream trigger automatically changes a run. Menu, Attendance, readiness, Recipe, Dish, Ingredient, Unit, calculation-contract, or future conversion changes do not rewrite or automatically invalidate H0A5 evidence. A later separately approved command may invalidate explicitly. Commands, authorization, reasons, events, receipts, audit, and APIs are outside H0A5a/H0A5b.

Release does not create Confirmed Need. It only exposes an immutable Planning-owned result for later H0B1/H0C consumption.

### 2.10 Immutable release boundary

The physical concepts remain separate:

1. mutable positive-version run control;
2. immutable generated Theoretical Need lines;
3. immutable run input snapshot and typed run-use relations;
4. immutable/append-only run issues;
5. at most one immutable release snapshot header per run;
6. immutable release snapshot lines containing every-and-only releasable line; and
7. typed release-to-issue membership and typed line/source ownership sufficient for downstream FKs.

The release header binds one exact run and the resulting `RELEASED_FOR_CONFIRMATION` run version, exact input-snapshot identity, release actor, release timestamp, generated-line count, disposition counts, blocking/warning counts, and complete issue summary.

Release lines bind every-and-only immutable Theoretical Need line of the released run, including valid `ACTIVE` zero and valid `REMOVED` lines. They preserve or relationally prove exact quantity, source Unit, disposition, predecessor, calculation-contract revision, optional conversion revision, and every mandatory typed source anchor. Composite ownership and deferred completeness enforcement must reject missing, extra, altered, duplicate, cross-run, and wrong-version membership.

Typed release-to-issue membership records every-and-only issue fact included in the release summary. A successful release has zero blockers; warning membership remains exact. After release, no line, source, issue, header, or membership may be updated or deleted.

The snapshot remains queryable after invalidation and successor generation. H0B1 may consume only exact release snapshot lines through typed FKs and cannot edit H0A5 evidence. Mutable run lines alone are not a release boundary.

### 2.11 Minimum H0A5b physical decomposition

H0A5b must be implementable without reopening business identity or lineage. It must define exact SQL names in its own issue before coding, but its minimum object families are now closed:

| Physical family                      | Required responsibility                                                                                                                                                                       |
| ------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Need Generation run root             | Opaque run ID, exact Planning Input Set/evaluation ownership, period inheritance, positive attempt ordinal, direct run predecessor, closed status, positive version, controlled counts/times. |
| Run input snapshot                   | One immutable header with the exact evaluation and both exact readiness source triples plus mandatory calculation-contract revision.                                                          |
| Calculation-contract root/revision   | Stable governed identity and immutable approved fixed-formula/numeric revision; no formula DSL.                                                                                               |
| Typed Recipe selection/use relations | Exact Menu snapshot line, stable Menu line, School/SchoolType selection fact, Recipe, RecipeVersion, stable RecipeLine, and RecipeLineRevision use.                                           |
| Theoretical Need lines               | Immutable atomic quantity/disposition/predecessor facts with direct typed source anchors.                                                                                                     |
| Typed source ownership relations     | Only bounded typed relations required to enforce the exact one-to-one source families; no generic registry.                                                                                   |
| Generation issues                    | Immutable run/optional-line-owned facts with the closed catalog and deterministic context uniqueness.                                                                                         |
| Release snapshot header              | One immutable exact released run/version, counts, actor/time, input identity, and issue summary.                                                                                              |
| Release snapshot lines               | Every-and-only immutable line membership with exact typed ownership and source facts.                                                                                                         |
| Release issue membership             | Every-and-only immutable issue membership supporting the exact summary.                                                                                                                       |
| Run and line predecessor keys        | One linear run successor chain and one-to-one theoretical contribution correction with no fork/cycle/split/merge.                                                                             |
| Conversion boundary                  | No conversion family or row in source-unit H0A5b; a later approved typed revision family and FKs are mandatory before any conversion.                                                         |

H0A5b adds no API function, command, role, capability, policy vocabulary, event, reason, receipt, read surface, generated type, UI, or production data. Private-schema ownership, forced RLS, zero policies, revoke-first privileges, restrictive foreign keys, and leading indexes must follow the merged Atlas security baseline.

### 2.12 Domain and downstream boundaries

Need Generation references but never edits the Planning Input Set/evaluation, Menu, Attendance, School, Dish, Recipe, RecipeVersion, RecipeLine, RecipeLineRevision, Ingredient, Unit, calculation-contract revision, or future conversion revision.

Confirmed Need remains the later Planning review and approval gate. H0A5 does not create, group, confirm, adjust, or approve Confirmed Need. Procurement must not consume theoretical lines directly, must not rebalance them, and has read-only access only through a later approved typed boundary. H0A5 creates no Purchase Assignment, supplier, purchase, Warehouse, Dispatch, QA, Production, or Finance behavior.

## 3. Alternatives considered

| Question               | Selected                                                                         | Rejected                                                              | Reason                                                                                                        |
| ---------------------- | -------------------------------------------------------------------------------- | --------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| Recalculation identity | One new linear successor run per accepted generation attempt.                    | Reuse or refresh one mutable run.                                     | Distinct immutable inputs/lines/releases and a nonforking correction chain preserve every attempt.            |
| Calculation contract   | One mandatory fixed-formula immutable revision.                                  | Generic formula engine or caller expression.                          | The exact proportional-per-basis formula and numeric semantics are reviewable and reproducible without a DSL. |
| Recipe selection       | Exact eligible SchoolType Recipe, then eligible general Recipe.                  | General-only, caller-selected, display-first, or arbitrary first row. | Typed scope is deterministic and the issue explicitly closes the precedence.                                  |
| Unit output            | Exact RecipeLineRevision source Unit.                                            | Automatic controlled/purchase/supplier Unit conversion.               | H0A5 has no approved conversion family or Procurement authority and needs no conversion for source output.    |
| Output grain           | One atomic contribution per exact Menu/Attendance/RecipeLine source combination. | Ingredient, School/date, or Menu/Recipe aggregation.                  | Stable source correction and later contribution membership require atomic facts.                              |
| Source lineage         | Direct typed columns plus bounded typed use relations.                           | Generic registry, polymorphic text, JSON, hash, name, or token trace. | PostgreSQL can enforce exact ownership and history through typed FKs.                                         |
| Removal                | Explicit zero `REMOVED` successor with exact H0A2 removal evidence.              | Silent omission or zero-as-removal.                                   | The old and new facts remain explainable and active zero retains its distinct meaning.                        |
| Release boundary       | Separate immutable release header, line membership, and issue membership.        | Mutable run lines or status alone.                                    | H0B1 needs one complete typed, historical, every-and-only consumption boundary.                               |
| Upstream change        | Explicit later command-driven invalidation.                                      | Automatic cross-domain invalidation triggers.                         | Source ownership remains decoupled and old run/release evidence never changes implicitly.                     |

No material H0A5 business alternative remains open. Exact SQL names, command contracts, authorization, and a future conversion implementation are deliberately later technical/operational tasks and do not alter the selected source-unit H0A5b model.

## 4. Future H0A5b test architecture

H0A5a creates no migration or pgTAP. The later H0A5b issue must declare exact suite filenames and exact `plan(N)` counts before implementation. Each suite must own an independent transaction, deterministic noncolliding fixtures, `finish()`, rollback, one exact-path workflow command, `Files=1`, its exact assertion count, and `Result: PASS`. It must not modify or repartition H0A1–H0A4 tests.

Every future invariant belongs to exactly one family:

| Exclusive invariant family                                     | Sole ownership                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| -------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **H0A5 structure/security**                                    | Exact relation/column/type/default/check/FK/index/trigger catalog; UUID identity; `numeric(20,6)` quantities and `numeric(24,12)` factors; ownership; enabled/forced RLS; zero policies; fail-closed grants/default privileges; private function posture; no API/role/capability/seed/conversion/public/`ops_v2`/command surface.                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| **H0A5 run/input/recipe/calculation integrity**                | One run per exact Planning Input Set/evaluation; period inheritance; generation-entry readiness binding/currentness; one immutable input snapshot; exact Menu/Attendance equality with H0A4b; mandatory calculation revision; exact Recipe precedence and eligibility; typed Recipe/RecipeLine use; student-plus-teacher arithmetic; basis/factor/result validity; one final numeric cast; source-Unit rule; differing-Unit rejection.                                                                                                                                                                                                                                                                                                                                          |
| **H0A5 theoretical-line/source/predecessor/release integrity** | Atomic uniqueness; direct typed source completeness; immutable lines/use relations; exact quantity/unit/disposition; theoretical predecessor matching/nonforking; new/ingredient/quantity/removal outcomes; split/merge/silent-omission rejection; prior removed-line immutability and permitted omission while absent; reintroduced `PRESENT` stable RecipeLine rejection without a new or inferred-predecessor line; exact `UNSUPPORTED_REINTRODUCTION_AFTER_REMOVAL` blocker; validation/release rejection; unrelated genuinely new stable RecipeLines remaining valid without predecessors; one immutable release header; every-and-only release line and issue membership; exact values/source/predecessor/summary; release immutability and typed downstream FK boundary. |
| **H0A5 lifecycle/issues/invalidation/history**                 | Run attempt ordinal and linear run predecessor chain; terminal-run rule; closed lifecycle and every version increment; blocker/warning catalog and severity; issue immutability/context/counts; validation/release gates; explicit invalidation; retained generated/input/issue/release history; successor creation; no resurrection; and absence of automatic upstream invalidation triggers.                                                                                                                                                                                                                                                                                                                                                                                  |

No assertion may be claimed by two families. The H0A5b issue must enumerate the exact invariant-to-suite assignment and count before SQL is written.

## 5. Consequences, security, and rollback

- H0A5b can implement a private persistence foundation without guessing run grain, readiness identity, Recipe precedence, arithmetic, Unit behavior, contribution identity, correction semantics, issue severity, lifecycle, or release membership.
- The old prototype's `planningInputSetVersion`, generic `readinessSnapshotId`, first-active-Recipe selection, JavaScript floating arithmetic, concatenated source trace, per-portion shortcut, and mutable line status are explicitly non-authoritative.
- Exact typed lineage and immutable release membership make later H0B1 grouping possible without making H0A5 own confirmation grain.
- Source corrections require explicit new evidence and a successor run; no upstream change silently rewrites or invalidates history.
- Private tables remain inaccessible to browser/API roles. No service-role credential, hosted Supabase access, or production data is needed.
- H0A5a changes documentation only. Rollback is a normal Git revert. It has no schema, data, deployment, or operational rollback effect.

## 6. Excluded authority

This decision creates no SQL, migration, pgTAP, workflow command, RPC, trigger, RLS policy, role, capability, reason, event, receipt, audit contract, safe-error envelope, read model, generated type, React behavior, Retool change, OPS v1 change, hosted Supabase action, production data, credential, deployment, Confirmed Need behavior, Procurement behavior, Warehouse behavior, Dispatch behavior, QA, Production, or Finance behavior.

H0A5b persistence, any future conversion family, all commands/authorization/API work, H0B1, H0C, and H1 remain separate tasks.
