# Decision PA-06E-H0A4 — Planning Input Readiness

**Status:** Accepted for H0A4 design; persistence not implemented
**Date:** 2026-07-20
**Issue:** GitHub Issue #125
**Scope:** PA-06E-H0A4a documentation and decision closure only

## Context

H0A3a and H0A3b provide the prerequisite immutable Weekly Menu and Attendance approval snapshots. The existing Planning Input Readiness contract established a logical gate, but left implementation-critical ambiguity around root grain, source binding, period compatibility, evaluation history, lifecycle, issue classification, warning acknowledgement, and downstream handoff.

Those decisions must be closed before H0A4 persistence is designed. This decision does not authorize that persistence.

## Decision

### 1. One stable root per exact inclusive period

Create or resolve one stable Planning Input Set root for each exact inclusive `(period_start, period_end)` pair. Re-evaluation of the same pair retains that root and creates the next positive immutable evaluation version. School, source type, source version, customer, location, and evaluator are not part of the root grain.

### 2. Immutable evaluation evidence

Every evaluation is append-only and belongs to one stable root. It owns:

- a positive root-local evaluation version;
- an immutable result of `NOT_READY` or `READY`;
- direct typed source-snapshot bindings; and
- its complete immutable blocking/warning issue set.

The stable root owns only the exact period, current lifecycle status, and one exact current-evaluation pointer. Prior evaluations and issues remain queryable after re-evaluation, invalidation, request, and later upstream approvals.

### 3. Direct typed bindings to exact approval snapshots

Each evaluation has at most one direct typed Weekly Menu approval-snapshot binding and at most one direct typed Attendance approval-snapshot binding. Each binding proves exact snapshot ID, stable source root, positive approved source version, and typed ownership. `READY` and `NEED_GENERATION_REQUESTED` require both. `NOT_READY` may lack one or both when immutable blocking issues explain why.

Generic/polymorphic input-reference rows, hashes, JSON lineage, status strings, or untyped identifiers are rejected as authoritative source bindings.

### 4. Period containment, not equality

The exact evaluated period must be wholly contained in each bound source snapshot period. A seven-day Weekly Menu may therefore support a smaller evaluated subset. An H0A3b Attendance snapshot may cover any valid inclusive period but must contain every evaluated day. A partial overlap, disjoint period, or uncovered day is blocking. Multiple same-type snapshots cannot be combined for coverage.

### 5. Closed lifecycle

The only root states are `NOT_READY`, `READY`, `NEED_GENERATION_REQUESTED`, and `INVALIDATED`.

Valid creation/transitions are:

- first evaluation -> `NOT_READY` or `READY`, evaluation version 1;
- `NOT_READY` -> `NOT_READY` or `READY` by a new evaluation version;
- `INVALIDATED` -> `NOT_READY` or `READY` by a new evaluation version;
- `READY` -> `NEED_GENERATION_REQUESTED`, preserving the exact current evaluation;
- `READY` -> `INVALIDATED`, preserving the exact current evaluation; and
- `NEED_GENERATION_REQUESTED` -> `INVALIDATED`, preserving the exact current evaluation.

Everything else is rejected. A later upstream approval does not rewrite or automatically invalidate H0A4 evidence. Invalidation is a later explicit command-driven action; there are no automatic cross-domain triggers.

### 6. Compatibility issues

Blocking conditions and their stable codes are exactly:

- `MISSING_WEEKLY_MENU_APPROVAL_SNAPSHOT` — missing Weekly Menu approval snapshot;
- `MISSING_ATTENDANCE_APPROVAL_SNAPSHOT` — missing Attendance approval snapshot;
- `SOURCE_SNAPSHOT_OWNERSHIP_MISMATCH` — source snapshot not belonging to the claimed typed source root/version;
- `WEEKLY_MENU_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD` — Weekly Menu period not fully covering the evaluated period;
- `ATTENDANCE_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD` — Attendance period not fully covering the evaluated period;
- `STALE_OR_MISMATCHED_SNAPSHOT_BINDING` — stale or mismatched snapshot binding; and
- `REQUEST_WITHOUT_CURRENT_READY_EVALUATION` — request state without one exact current `READY` evaluation, both exact bindings, and zero blocking issues.

Warnings and their stable codes are exactly:

- `MENU_SCHOOL_DATE_WITHOUT_ATTENDANCE` — Menu School/date with no Attendance line;
- `ATTENDANCE_SCHOOL_DATE_WITHOUT_MENU` — Attendance School/date with no Menu line; and
- `ZERO_ATTENDANCE_FOR_PLANNED_MENU` — zero Attendance portions for a School/date with a planned Menu.

Warnings alone do not block readiness. They are computed from source snapshot facts inside the evaluated period. H0A4 introduces no expected-School catalogue, completeness assumption, omitted-day rule, default, slot policy, or active-School rule.

### 7. Warning acknowledgement is deferred

H0A4 persists immutable visible warnings only. It introduces no acknowledgement table/status, actor/time, waiver, override, exception, acceptance field, or hidden implicit acknowledgement. A future acknowledgement workflow requires its own approved decision and migration.

### 8. Downstream handoff is evidence only

`NEED_GENERATION_REQUESTED` records handoff of the exact current immutable evaluation. It performs no ingredient calculation and creates no Recipe/BOM resolution, Need Generation run, Theoretical Need, Confirmed Need, Procurement rebalance, or other downstream state. H0A5 may consume, but never edit, the exact current evaluation and bindings.

## Alternatives considered

| Question                | Selected                                              | Rejected                               | Reason                                                                                                                               |
| ----------------------- | ----------------------------------------------------- | -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| Source/evaluated period | containment                                           | exact equality                         | Equality would reject valid evaluated subsets of the fixed seven-day Menu and valid broader Attendance periods.                      |
| Re-evaluation identity  | stable period root plus immutable evaluation versions | a new root per evaluation              | A stable root gives one controlled lifecycle/current pointer while append-only versions preserve evidence.                           |
| Source reference        | two direct typed snapshot FK families                 | generic/polymorphic reference relation | Typed relations let PostgreSQL enforce snapshot/root/version ownership and prevent cross-type or JSON-only lineage.                  |
| Source changes          | explicit command-driven invalidation                  | automatic cross-domain triggers        | Explicit invalidation keeps ownership and audit boundaries clear and avoids hidden coupling to upstream writes.                      |
| Warning acknowledgement | defer                                                 | implement acknowledgement now          | Product policy, authority, waiver meaning, and evidence requirements are not approved and are unnecessary for a nonblocking warning. |

## Consequences

- H0A4b can design a narrow persistence foundation without guessing grain or lifecycle.
- The stable root has mutable current control fields, while evaluation evidence, typed bindings, and issues are immutable.
- Readiness history remains explainable even after new upstream approvals or a new evaluation.
- The model cannot silently mix source versions or assemble coverage from multiple snapshots.
- Warning acknowledgement and all command/API/security details remain blocked pending separate approval.

## Future H0A4b verification boundary

H0A4b must add three independently runnable pgTAP suites with exclusive invariant ownership:

1. `pa_06e_h0a4b_planning_input_readiness_structure_security.sql` — structure and security;
2. `pa_06e_h0a4b_planning_input_readiness_evaluation_source_snapshot_integrity.sql` — evaluation and source-snapshot integrity; and
3. `pa_06e_h0a4b_planning_input_readiness_lifecycle_issues_invalidation.sql` — lifecycle, issues, and invalidation.

Each suite must own its transaction, fixtures, exact `plan(N)`, `finish()`, and rollback; run as one exact-path `supabase test db ... --local` workflow command; and report `Files=1`, its exact assertion count, and `Result: PASS`. The H0A4b issue must declare each `N` before implementation. Prior migration tests must remain unchanged.

## Excluded authority

This decision creates no physical schema, migration, SQL, RPC, trigger, API/event contract, authorization rule, reason taxonomy, UI, hosted change, production-data change, Need Generation calculation, Recipe/BOM behavior, Theoretical Need, Confirmed Need, or Procurement behavior.
