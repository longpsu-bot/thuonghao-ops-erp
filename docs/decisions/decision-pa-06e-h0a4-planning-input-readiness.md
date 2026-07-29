# Decision PA-06E-H0A4 — Planning Input Readiness

**Status:** Accepted H0A4 design and H0A4b baseline; source-binding authority amended by accepted PANTRY-RDY-01, Pantry persistence deferred to PANTRY-RDY-02
**Date:** 2026-07-20
**Amendment date:** 2026-07-29
**Issue:** GitHub Issue #125
**Scope:** H0A4 design plus the documentation-only PANTRY-RDY-01 source-binding amendment
**Amendment:** [Decision PANTRY-RDY-01 — Pantry Binding for Planning Input Readiness](decision-pantry-rdy-01-planning-input-readiness.md)

## Context

H0A3a and H0A3b provide immutable Weekly Menu and Attendance approval snapshots. PANTRY-02 now also provides immutable exact Pantry approval snapshots, including explicit zero-line approval evidence. Planning Input Readiness therefore requires three source families for new readiness and request decisions.

The original H0A4 decisions closed root grain, lifecycle, evaluation history, warning, and handoff ambiguity before H0A4b persistence. PANTRY-RDY-01 amends only source binding and related readiness, containment, issue, and request-eligibility rules. It does not authorize the later Pantry persistence amendment.

## Decision

### 1. One stable root per exact inclusive period

Create or resolve one stable Planning Input Set root for each exact inclusive `(period_start, period_end)` pair. Re-evaluation of the same pair retains that root and creates the next positive immutable evaluation version. School, source type, source version, customer, location, and evaluator are not part of the root grain.

### 2. Immutable evaluation evidence

Every evaluation is append-only and belongs to one stable root. It owns:

- a positive root-local evaluation version;
- an immutable result of `NOT_READY` or `READY`;
- three direct typed source-snapshot binding families; and
- its complete immutable blocking/warning issue set.

The stable root owns only the exact period, current lifecycle status, and one exact current-evaluation pointer. Prior evaluations and issues remain queryable after re-evaluation, invalidation, request, and later upstream approvals.

### 3. Direct typed bindings to exact approval snapshots

Each evaluation has at most one direct typed Weekly Menu approval-snapshot binding, at most one direct typed Attendance approval-snapshot binding, and at most one direct typed Pantry approval-snapshot binding. Each binding proves exact snapshot ID, stable source root, positive approved source version, and typed ownership.

The Pantry family is exactly `pantry_need_batch_id`, `pantry_need_approval_snapshot_id`, and `approved_batch_version`; those fields are all absent or all present. Every new `READY` evaluation and every new Need Generation request requires all three families. `NOT_READY` may lack an unavailable family when immutable blocking issues explain why. Missing Pantry is not no additions.

Generic/polymorphic input-reference rows, hashes, JSON lineage, status strings, or untyped identifiers are rejected as authoritative source bindings.

### 4. Period containment, not equality

The exact evaluated period must be wholly contained in each bound source snapshot period. A seven-day Weekly Menu or Monday-through-Sunday Pantry batch may therefore support a smaller evaluated subset. An H0A3b Attendance snapshot may cover any valid inclusive period but must contain every evaluated day. A partial overlap, disjoint period, or uncovered day is blocking. Multiple same-type snapshots cannot be combined for coverage.

Both an approved positive-line Pantry snapshot and an approved explicit zero-line snapshot with `no_additions_confirmed = true`, `line_count = 0`, and zero snapshot-line rows are valid evidence. A zero-line snapshot is not missing evidence and creates no zero-quantity line.

A Pantry snapshot supports a new `READY` evaluation only while its batch is `APPROVED`, the batch's current version equals the snapshot approved version, its latest-approval pointer identifies that snapshot, and typed ownership and containment pass. Draft, Validated, Reopened, and superseded Pantry evidence is ineligible.

### 5. Closed lifecycle

The only root states are `NOT_READY`, `READY`, `NEED_GENERATION_REQUESTED`, and `INVALIDATED`.

Valid creation/transitions are:

- first evaluation -> `NOT_READY` or `READY`, evaluation version 1;
- `NOT_READY` -> `NOT_READY` or `READY` by a new evaluation version;
- `INVALIDATED` -> `NOT_READY` or `READY` by a new evaluation version;
- `READY` -> `NEED_GENERATION_REQUESTED`, preserving the exact current evaluation;
- `READY` -> `INVALIDATED`, preserving the exact current evaluation; and
- `NEED_GENERATION_REQUESTED` -> `INVALIDATED`, preserving the exact current evaluation.

Everything else is rejected. A later upstream Weekly Menu, Attendance, or Pantry approval does not rewrite or automatically invalidate readiness evidence. Invalidation is an explicit command-driven action; there are no automatic cross-domain triggers. A corrected Pantry approval requires a successor evaluation on the same exact-period root after explicit invalidation where required by the lifecycle.

### 6. Compatibility issues

Blocking conditions and their stable codes are exactly:

- `MISSING_WEEKLY_MENU_APPROVAL_SNAPSHOT` — missing Weekly Menu approval snapshot;
- `MISSING_ATTENDANCE_APPROVAL_SNAPSHOT` — missing Attendance approval snapshot;
- `MISSING_PANTRY_APPROVAL_SNAPSHOT` — missing exact approved Pantry snapshot;
- `SOURCE_SNAPSHOT_OWNERSHIP_MISMATCH` — source snapshot not belonging to the claimed typed source root/version;
- `WEEKLY_MENU_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD` — Weekly Menu period not fully covering the evaluated period;
- `ATTENDANCE_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD` — Attendance period not fully covering the evaluated period;
- `PANTRY_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD` — Pantry batch week not fully covering the evaluated period;
- `STALE_OR_MISMATCHED_SNAPSHOT_BINDING` — stale or mismatched snapshot binding; and
- `REQUEST_WITHOUT_CURRENT_READY_EVALUATION` — request state without one exact current `READY` evaluation, all three exact bindings, and zero blocking issues.

Issue context permits `input_type = 'PANTRY'`.

Warnings and their stable codes are exactly:

- `MENU_SCHOOL_DATE_WITHOUT_ATTENDANCE` — Menu School/date with no Attendance line;
- `ATTENDANCE_SCHOOL_DATE_WITHOUT_MENU` — Attendance School/date with no Menu line; and
- `ZERO_ATTENDANCE_FOR_PLANNED_MENU` — zero Attendance portions for a School/date with a planned Menu.

Warnings alone do not block readiness. These three Menu/Attendance warnings remain unchanged, and no Pantry cross-source warning is added. They are computed from source snapshot facts inside the evaluated period. H0A4 introduces no expected-School catalogue, completeness assumption, omitted-day rule, default, slot policy, or active-School rule.

### 7. Warning acknowledgement is deferred

H0A4 persists immutable visible warnings only. It introduces no acknowledgement table/status, actor/time, waiver, override, exception, acceptance field, or hidden implicit acknowledgement. A future acknowledgement workflow requires its own approved decision and migration.

### 8. Downstream handoff is evidence only

`NEED_GENERATION_REQUESTED` records handoff of the exact current immutable evaluation. A new request requires all three exact current approved bindings and fails closed when the Pantry binding no longer identifies the batch's exact current approved snapshot. It performs no ingredient calculation and creates no Recipe/BOM resolution, Need Generation run, Pantry contribution, Theoretical Need, Confirmed Need, Procurement rebalance, or other downstream state. Later authorized behavior may consume, but never edit, the exact current evaluation and bindings.

### 9. Historical compatibility

Historical readiness evaluations created before PANTRY-RDY-02 remain immutable and may retain null Pantry binding fields. They remain valid historical evidence but cannot authorize a new Need Generation request after the Pantry readiness amendment.

A current Planning Input Set relying on such an evaluation must be explicitly invalidated and re-evaluated with one exact approved Pantry snapshot. No historical Pantry binding may be fabricated or backfilled.

## Alternatives considered

| Question                | Selected                                              | Rejected                               | Reason                                                                                                                               |
| ----------------------- | ----------------------------------------------------- | -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| Source/evaluated period | containment                                           | exact equality                         | Equality would reject valid evaluated subsets of the fixed seven-day Menu and valid broader Attendance periods.                      |
| Re-evaluation identity  | stable period root plus immutable evaluation versions | a new root per evaluation              | A stable root gives one controlled lifecycle/current pointer while append-only versions preserve evidence.                           |
| Source reference        | three direct typed snapshot FK families               | generic/polymorphic reference relation | Typed relations let PostgreSQL enforce snapshot/root/version ownership and prevent cross-type or JSON-only lineage.                  |
| Source changes          | explicit command-driven invalidation                  | automatic cross-domain triggers        | Explicit invalidation keeps ownership and audit boundaries clear and avoids hidden coupling to upstream writes.                      |
| Warning acknowledgement | defer                                                 | implement acknowledgement now          | Product policy, authority, waiver meaning, and evidence requirements are not approved and are unnecessary for a nonblocking warning. |

## Consequences

- PANTRY-RDY-02 can amend the existing narrow persistence without changing grain or lifecycle.
- The stable root has mutable current control fields, while evaluation evidence, typed bindings, and issues are immutable.
- Readiness history remains explainable even after new upstream approvals or a new evaluation.
- The model cannot silently mix source versions or assemble coverage from multiple snapshots.
- Missing Pantry cannot be silently interpreted as no additions, while an explicit approved zero-line snapshot remains valid evidence.
- Warning acknowledgement and all command/API/security details remain blocked pending separate approval.

## Existing H0A4b and future PANTRY-RDY-02 boundary

H0A4b implemented three independently runnable pgTAP suites with exclusive invariant ownership:

1. `pa_06e_h0a4b_planning_input_readiness_structure_security.sql` — structure and security;
2. `pa_06e_h0a4b_planning_input_readiness_evaluation_source_snapshot_integrity.sql` — evaluation and source-snapshot integrity; and
3. `pa_06e_h0a4b_planning_input_readiness_lifecycle_issues_invalidation.sql` — lifecycle, issues, and invalidation.

PANTRY-RDY-01 changes none of them. A later PANTRY-RDY-02 may add one migration and must update those same three suites in place. It adds no relation, public API, capability, role or runtime role, scope kind, policy, automatic source trigger, fourth readiness relation, or fourth overlapping readiness test suite.

## Excluded authority

PANTRY-RDY-01 creates no physical schema, migration, SQL, RPC, trigger, API/event contract, authorization rule, reason taxonomy, UI, hosted change, production-data change, Need Generation calculation or Pantry contribution, Recipe/BOM behavior, Theoretical Need, Confirmed Need, Purchase Handoff, Procurement, Warehouse, Dispatch, Wholesale, OPS v1/v2, or Retool behavior.

## H0A4b implementation status

Issue #127 implements the original persistence boundary in [Decision PA-06E-H0A4b](decision-pa-06e-h0a4b-planning-input-readiness-persistence.md). Its migration, tests, and implementation record remain unchanged by PANTRY-RDY-01. The Pantry persistence delta requires separately authorized PANTRY-RDY-02.
