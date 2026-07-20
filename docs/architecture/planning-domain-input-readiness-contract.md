# PD-01.4 — Planning Domain Input Readiness Contract

**Status:** Contract v0.2; H0A4a decisions accepted, persistence deferred to H0A4b
**Domain:** Planning
**Business owner:** Tổ Kế hoạch
**Parent architecture:** ARCH-001 — OPS ERP Business Architecture
**Decision:** [Decision PA-06E-H0A4 — Planning Input Readiness](../decisions/decision-pa-06e-h0a4-planning-input-readiness.md)

## 1. Purpose

Planning Input Readiness is the Planning-owned compatibility gate between approved Weekly Menu and Attendance evidence and a later Need Generation capability.

```text
one exact approved Weekly Menu snapshot
+ one exact approved Attendance snapshot
+ full containment of the evaluated period in both source periods
+ no blocking compatibility issue
= READY
```

This contract does not calculate ingredients or create downstream operational data. It makes one exact, immutable readiness decision explainable and reusable without allowing later source changes to rewrite history.

## 2. Authoritative object model

### 2.1 Stable Planning Input Set root

There is exactly one stable `PlanningInputSet` root for each exact inclusive `(period_start, period_end)` pair. The root is not split by School, customer, source type, source version, location, or evaluator. Re-evaluating the same exact period retains the root.

The root owns controlled current state only:

- its exact inclusive evaluated period;
- current lifecycle status;
- one exact current-evaluation pointer; and
- the minimum metadata needed by a later authorized implementation.

The period is immutable after root creation. A different period creates or resolves a different root. H0A4 does not decide whether one future Need Generation run may cover one or many schools, dates, or locations.

### 2.2 Immutable readiness evaluation

Each evaluation creates a new immutable evaluation for the stable root with a positive, root-local `evaluation_version`. Version 1 is the first evaluation; every permitted re-evaluation uses the next positive version. An evaluation records:

- the exact stable root and evaluation version;
- an immutable result of `NOT_READY` or `READY`;
- evaluation actor and time when a later command contract supplies them;
- the two direct typed source-snapshot bindings described below; and
- the complete immutable issue set for that evaluation.

The root's current-evaluation pointer may advance to the newly inserted evaluation in the same future transaction. Prior evaluations remain addressable and must not be updated or deleted.

`NEED_GENERATION_REQUESTED` and `INVALIDATED` are root lifecycle states, not rewritten evaluation results. A root in either state still points to the exact evaluation whose evidence caused the transition.

### 2.3 Direct typed source-snapshot bindings

Every evaluation has two distinct, typed relational binding slots:

1. at most one exact Weekly Menu approval snapshot; and
2. at most one exact Attendance approval snapshot.

Each present binding proves the exact immutable snapshot ID, its stable source root, its positive approved source version, and typed ownership between them. The future database design must enforce those relations with typed foreign keys, including composite ownership where required by the approved upstream snapshot schemas.

The selected model does not use a generic or polymorphic input-reference relation. A hash, JSON payload, source name, date, status string, or untyped `(input_type, input_id, input_version)` tuple is not an authoritative binding.

`READY` and `NEED_GENERATION_REQUESTED` require both exact bindings. A `NOT_READY` evaluation may omit one or both bindings only when its immutable blocking issues explain each absence or incompatibility. An attempted mismatched source root/version is never accepted as an authoritative binding.

### 2.4 Immutable evaluation issues

Every readiness issue belongs to exactly one immutable evaluation, not merely to the stable root. Issues are append-only evidence and are never refreshed, resolved in place, reassigned to a later evaluation, or deleted. Re-evaluation creates a new issue set on the next evaluation version.

An issue has one severity, `BLOCKING` or `WARNING`, an approved issue code, a safe explanation, and optional typed School/date/source context when applicable. A later implementation may choose physical names, but it must preserve evaluation ownership and immutability.

## 3. Evaluated-period compatibility

All periods are inclusive and valid only when `period_start <= period_end`.

For each source snapshot, compatibility is containment rather than period equality:

```text
source_period_start <= evaluated_period_start
and source_period_end >= evaluated_period_end
```

- The Weekly Menu source may cover its exact seven-day Monday-through-Sunday week while the evaluated period is any wholly contained subset.
- The Attendance source may use any exact inclusive period allowed by H0A3b, but that single snapshot must wholly contain the evaluated period.
- Partial overlap, disjoint periods, or any uncovered evaluated day is blocking.
- Multiple Menu or Attendance snapshots must not be combined to manufacture coverage.

Period containment proves only the temporal compatibility of the two source snapshots. It does not assert that every School/date combination exists.

## 4. Closed lifecycle

The root status set is closed:

- `NOT_READY`
- `READY`
- `NEED_GENERATION_REQUESTED`
- `INVALIDATED`

The only valid creations and transitions are:

| Current state               | Operation               | Next state                  | Evaluation effect                               |
| --------------------------- | ----------------------- | --------------------------- | ----------------------------------------------- |
| no root/current evaluation  | first evaluation        | `NOT_READY` or `READY`      | create version 1 and point the root to it       |
| `NOT_READY`                 | re-evaluation           | `NOT_READY` or `READY`      | create the next version and advance the pointer |
| `INVALIDATED`               | re-evaluation           | `NOT_READY` or `READY`      | create the next version and advance the pointer |
| `READY`                     | request Need Generation | `NEED_GENERATION_REQUESTED` | retain the same exact current evaluation        |
| `READY`                     | explicit invalidation   | `INVALIDATED`               | retain the same exact current evaluation        |
| `NEED_GENERATION_REQUESTED` | explicit invalidation   | `INVALIDATED`               | retain the same exact current evaluation        |

Every other transition is rejected. In particular:

- `READY` or `NEED_GENERATION_REQUESTED` cannot be re-evaluated directly; it must first be explicitly invalidated;
- `NOT_READY` cannot request Need Generation or transition directly to `INVALIDATED`;
- `INVALIDATED` cannot request Need Generation;
- request and invalidation do not increment the evaluation version; and
- no lifecycle operation may mutate the current or prior evaluation, its bindings, or its issues.

Need Generation request is a handoff marker only. It requires one exact current evaluation whose immutable result is `READY`, both exact source bindings, and zero blocking issues.

Later approval, reopen, correction, or replacement of an upstream Weekly Menu or Attendance root does not automatically alter a Planning Input Set. A later authorized command may explicitly invalidate the affected `READY` or `NEED_GENERATION_REQUESTED` root, with its reason/event/authorization contract defined outside H0A4a. There are no automatic cross-domain source triggers.

## 5. Compatibility issue classification

### 5.1 Blocking issues

The following stable classifications block `READY` and Need Generation request:

| Issue code                                           | Exact condition                                                                                          |
| ---------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `MISSING_WEEKLY_MENU_APPROVAL_SNAPSHOT`              | no exact Weekly Menu approval snapshot is available for the evaluation                                   |
| `MISSING_ATTENDANCE_APPROVAL_SNAPSHOT`               | no exact Attendance approval snapshot is available for the evaluation                                    |
| `SOURCE_SNAPSHOT_OWNERSHIP_MISMATCH`                 | a source snapshot does not belong to the claimed typed source root and approved version                  |
| `WEEKLY_MENU_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD` | the Weekly Menu snapshot period does not wholly contain the evaluated period                             |
| `ATTENDANCE_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD`  | the Attendance snapshot period does not wholly contain the evaluated period                              |
| `STALE_OR_MISMATCHED_SNAPSHOT_BINDING`               | a caller expectation or candidate binding does not match the exact snapshot/root/version being evaluated |
| `REQUEST_WITHOUT_CURRENT_READY_EVALUATION`           | request state lacks one exact current `READY` evaluation, both exact bindings, or zero blocking issues   |

A database constraint that rejects an impossible typed binding and a readiness issue that explains the failed compatibility decision are complementary future safeguards. Neither permits an invalid reference to become authoritative evidence.

### 5.2 Warnings

The following stable classifications are warnings and do not block readiness by themselves:

| Issue code                            | Exact condition                                                                 |
| ------------------------------------- | ------------------------------------------------------------------------------- |
| `MENU_SCHOOL_DATE_WITHOUT_ATTENDANCE` | a Menu School/date within the evaluated period has no Attendance snapshot line  |
| `ATTENDANCE_SCHOOL_DATE_WITHOUT_MENU` | an Attendance School/date within the evaluated period has no Menu snapshot line |
| `ZERO_ATTENDANCE_FOR_PLANNED_MENU`    | a School/date has a planned Menu and zero total Attendance portions             |

These warnings compare only facts actually present in the two bound immutable snapshots within the evaluated period. H0A4 does not invent an expected-School catalogue, required School/day completeness rule, omitted-day meaning, defaults, slot policy, or active-School policy.

### 5.3 Warning acknowledgement is deferred

Warnings remain immutable and visible, but they do not block readiness and have no acknowledgement workflow in H0A4. H0A4 introduces no acknowledgement table or status, actor/time record, waiver, override, exception, or implicit acceptance field. Any future acknowledgement requirement needs a separate approved decision and migration.

## 6. Upstream and downstream boundaries

Weekly Menu and Attendance retain ownership of their roots, working versions, approval snapshots, and snapshot lines. Readiness references but never edits those objects.

`NEED_GENERATION_REQUESTED` records only that the exact current readiness evidence was handed off. H0A4 does not:

- calculate ingredient quantities;
- resolve Recipe/BOM revisions;
- create or release a Need Generation run;
- create Theoretical Need or Confirmed Need;
- assign suppliers or rebalance Procurement;
- mutate Warehouse, Dispatch, Finance, or source Planning data; or
- expose browser-authored authoritative state.

Future H0A5 may consume the exact current immutable evaluation and its two typed bindings. It must not edit H0A4 evidence and must fail closed if the current root state/evaluation does not satisfy the approved handoff contract.

## 7. Read behavior and decision-first UX

Read models may show the evaluated period, root status, current evaluation version/result, exact source snapshot/root/version evidence, issue counts, issue details, evaluation metadata, and handoff/invalidation history. Historical evaluation versions and their issue sets must remain queryable.

The primary question is: **Can Planning request Need Generation for this exact period?** UI visibility is not authorization or integrity enforcement. React may coordinate interaction, but authoritative lifecycle and binding rules belong to the future backend design.

## 8. Retool evidence and compatibility

The retained OPS v1 evidence records a Weekly Menu week/date-range selector, a separate Attendance date picker, an Attendance XLSX path that can represent one service date, legacy public writes, and hidden downstream rebalance reactions. It does not show a controlled combined readiness object. Atlas preserves the useful business facts—explicit period selection, source visibility, and handoff—while rejecting public writes, implicit rebalance, mutable source inference, and Retool page structure as authority. This qualitative review used retained repository/Issue evidence only; H0A4a did not inspect or change hosted Retool or Supabase state.

## 9. Future H0A4b persistence and tests

H0A4a authorizes no SQL. A later H0A4b issue must name the migration and predefine at least these three independently runnable pgTAP suites:

1. **Structure and security** — proposed file `supabase/tests/pa_06e_h0a4b_planning_input_readiness_structure_security.sql`. Owns relation/column/constraint presence, positive and unique version structure, direct typed FK structure, private-schema posture, RLS/grants, and absence of unintended runtime write access.
2. **Evaluation and source-snapshot integrity** — proposed file `supabase/tests/pa_06e_h0a4b_planning_input_readiness_evaluation_source_snapshot_integrity.sql`. Owns the unique exact-period root grain, one-or-zero typed binding per source family, exact snapshot/root/version ownership, period containment, `READY` binding requirements, rejection of multi-snapshot coverage, and current-evaluation pointer ownership.
3. **Lifecycle, issues, and invalidation** — proposed file `supabase/tests/pa_06e_h0a4b_planning_input_readiness_lifecycle_issues_invalidation.sql`. Owns the complete transition matrix, evaluation-version advancement rules, request/invalidation version preservation, immutable evaluation/issue history, blocking/warning classifications, request gate, explicit invalidation behavior, re-evaluation after invalidation, and absence of automatic cross-domain triggers.

Every invariant must have exactly one owning suite. Each suite must own its transaction, deterministic fixtures, exact `plan(N)`, `finish()`, and rollback; run independently as `supabase test db <exact-suite-path> --local`; and report `Files=1`, its exact assertion count, and `Result: PASS`. The H0A4b issue must replace `N` with a declared assertion count for each suite before implementation. H0A4b must add new tests and must not modify earlier migration tests to make its design pass.

## 10. H0A4a implementation boundary

This decision slice changes documentation only. It adds no migration, schema object, SQL, RPC, trigger, function, event, API registry entry, RLS policy, grant, runtime role, generated type, React behavior, package, hosted Supabase/Retool state, production data, or H0A5 behavior.

Command names, command parameters, authorization, actor attribution, reason taxonomy, events, safe errors, API contracts, and final physical names remain for separately approved implementation work.
