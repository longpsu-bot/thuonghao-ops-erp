# PD-01.4 — Planning Domain Input Readiness Contract

**Status:** Implemented on draft PR; pending independent review and merge
**Domain:** Planning
**Business owner:** Tổ Kế hoạch
**Parent architecture:** ARCH-001 — OPS ERP Business Architecture
**Decision:** [Decision PA-06E-H0A4 — Planning Input Readiness](../decisions/decision-pa-06e-h0a4-planning-input-readiness.md)
**Amendment:** [PANTRY-RDY-01 — Planning Input Readiness Pantry-Binding Amendment](pantry-rdy-01-planning-input-readiness-amendment.md)

## 1. Purpose

Planning Input Readiness is the Planning-owned compatibility gate between approved Weekly Menu, Attendance, and Pantry evidence and a later Need Generation capability.

```text
one exact approved Weekly Menu snapshot
+ one exact approved Attendance snapshot
+ one exact approved Pantry snapshot
+ full containment of the evaluated period in all three source periods
+ no blocking compatibility issue
= READY
```

Missing Pantry evidence is not interpreted as no additions. An approved explicit zero-line Pantry snapshot is valid controlled evidence. This contract does not calculate ingredients or create downstream operational data. It makes one exact, immutable readiness decision explainable and reusable without allowing later source changes to rewrite history.

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
- the three direct typed source-snapshot binding families described below; and
- the complete immutable issue set for that evaluation.

The root's current-evaluation pointer may advance to the newly inserted evaluation in the same future transaction. Prior evaluations remain addressable and must not be updated or deleted.

`NEED_GENERATION_REQUESTED` and `INVALIDATED` are root lifecycle states, not rewritten evaluation results. A root in either state still points to the exact evaluation whose evidence caused the transition.

### 2.3 Direct typed source-snapshot bindings

Every evaluation has three distinct, typed relational binding families:

1. at most one exact Weekly Menu approval snapshot; and
2. at most one exact Attendance approval snapshot; and
3. at most one exact Pantry approval snapshot.

Each present binding proves the exact immutable snapshot ID, its stable source root, its positive approved source version, and typed ownership between them. The future database design must enforce those relations with typed foreign keys, including composite ownership where required by the approved upstream snapshot schemas.

The Pantry family is exactly `pantry_need_batch_id`, `pantry_need_approval_snapshot_id`, and `approved_batch_version`. Those fields are all absent or all present. A present Pantry binding must prove exact snapshot/batch/version ownership.

The selected model does not use a generic or polymorphic input-reference relation. A hash, JSON payload, source name, date, status string, or untyped `(input_type, input_id, input_version)` tuple is not an authoritative binding.

Every new `READY` evaluation and every new Need Generation request requires all three exact bindings. A `NOT_READY` evaluation may omit an unavailable binding only when its immutable blocking issues explain each absence or incompatibility. An attempted mismatched source root/version is never accepted as authoritative evidence.

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
- The Pantry source covers one Monday-through-Sunday batch week, and that single snapshot must wholly contain the evaluated period.
- Partial overlap, disjoint periods, or any uncovered evaluated day is blocking.
- Multiple Menu, Attendance, or Pantry snapshots must not be combined to manufacture coverage.

Period containment proves only the temporal compatibility of the three source snapshots. It does not assert that every School/date combination exists.

Both an approved positive-line Pantry snapshot and an approved explicit zero-line snapshot are valid evidence. The zero-line form requires `no_additions_confirmed = true`, `line_count = 0`, and zero snapshot-line rows. It is not missing evidence and creates no zero-quantity line.

A Pantry snapshot supports a new `READY` evaluation only while its batch is `APPROVED`, the batch's current version equals the snapshot's `approved_batch_version`, the latest-approval pointer identifies that snapshot, and typed ownership and period containment pass. Draft, Validated, Reopened, and superseded Pantry evidence is ineligible.

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

Need Generation request is a handoff marker only. It requires one exact current evaluation whose immutable result is `READY`, all three exact source bindings, and zero blocking issues.

Later approval, reopen, correction, or replacement of an upstream Weekly Menu, Attendance, or Pantry root does not automatically alter a Planning Input Set. A later authorized command may explicitly invalidate the affected `READY` or `NEED_GENERATION_REQUESTED` root, with its reason/event/authorization contract defined outside this contract. There are no automatic cross-domain source triggers.

A new Need Generation request must fail closed if any bound source is no longer the exact current approved snapshot. For Pantry, the batch must remain `APPROVED`, its current version must equal the bound `approved_batch_version`, and its latest-approval pointer must equal the bound snapshot.

## 5. Compatibility issue classification

### 5.1 Blocking issues

The following stable classifications block `READY` and Need Generation request:

| Issue code                                           | Exact condition                                                                                             |
| ---------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `MISSING_WEEKLY_MENU_APPROVAL_SNAPSHOT`              | no exact Weekly Menu approval snapshot is available for the evaluation                                      |
| `MISSING_ATTENDANCE_APPROVAL_SNAPSHOT`               | no exact Attendance approval snapshot is available for the evaluation                                       |
| `MISSING_PANTRY_APPROVAL_SNAPSHOT`                   | no exact approved Pantry snapshot is available for the evaluation                                           |
| `SOURCE_SNAPSHOT_OWNERSHIP_MISMATCH`                 | a source snapshot does not belong to the claimed typed source root and approved version                     |
| `WEEKLY_MENU_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD` | the Weekly Menu snapshot period does not wholly contain the evaluated period                                |
| `ATTENDANCE_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD`  | the Attendance snapshot period does not wholly contain the evaluated period                                 |
| `PANTRY_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD`      | the Pantry batch week does not wholly contain the evaluated period                                          |
| `STALE_OR_MISMATCHED_SNAPSHOT_BINDING`               | a caller expectation or candidate binding does not match the exact snapshot/root/version being evaluated    |
| `REQUEST_WITHOUT_CURRENT_READY_EVALUATION`           | request state lacks one exact current `READY` evaluation, all three exact bindings, or zero blocking issues |

A database constraint that rejects an impossible typed binding and a readiness issue that explains the failed compatibility decision are complementary future safeguards. Neither permits an invalid reference to become authoritative evidence.

Issue context permits `input_type = 'PANTRY'` in addition to the existing source values.

### 5.2 Warnings

The following stable Menu/Attendance classifications remain the only warnings and do not block readiness by themselves:

| Issue code                            | Exact condition                                                                 |
| ------------------------------------- | ------------------------------------------------------------------------------- |
| `MENU_SCHOOL_DATE_WITHOUT_ATTENDANCE` | a Menu School/date within the evaluated period has no Attendance snapshot line  |
| `ATTENDANCE_SCHOOL_DATE_WITHOUT_MENU` | an Attendance School/date within the evaluated period has no Menu snapshot line |
| `ZERO_ATTENDANCE_FOR_PLANNED_MENU`    | a School/date has a planned Menu and zero total Attendance portions             |

These warnings compare only facts actually present in the bound Weekly Menu and Attendance snapshots within the evaluated period. PANTRY-RDY-01 adds no Pantry cross-source warning. This contract does not invent an expected-School catalogue, required School/day completeness rule, omitted-day meaning, defaults, slot policy, or active-School policy.

### 5.3 Warning acknowledgement is deferred

Warnings remain immutable and visible, but they do not block readiness and have no acknowledgement workflow in H0A4. H0A4 introduces no acknowledgement table or status, actor/time record, waiver, override, exception, or implicit acceptance field. Any future acknowledgement requirement needs a separate approved decision and migration.

## 6. Upstream and downstream boundaries

Weekly Menu, Attendance, and Pantry retain ownership of their roots, working versions, approval snapshots, and snapshot lines. Readiness references but never edits those objects.

`NEED_GENERATION_REQUESTED` records only that the exact current readiness evidence was handed off. H0A4 does not:

- calculate ingredient quantities;
- resolve Recipe/BOM revisions;
- create or release a Need Generation run;
- create Theoretical Need or Confirmed Need;
- assign suppliers or rebalance Procurement;
- mutate Warehouse, Dispatch, Finance, or source Planning data; or
- expose browser-authored authoritative state.

Future authorized Need Generation behavior may consume the exact current immutable evaluation and its three typed bindings. It must not edit readiness evidence and must fail closed if the current root state, evaluation, or any bound current approval does not satisfy the approved handoff contract.

### 6.1 Historical compatibility

Historical readiness evaluations created before PANTRY-RDY-02 remain immutable and may retain null Pantry binding fields.

Under the merged PANTRY-RDY-02 executable database authority, those evaluations remain valid historical evidence but cannot authorize a new Need Generation request.

For a current root:

- `READY` or `NEED_GENERATION_REQUESTED` must be explicitly invalidated before a successor evaluation can bind Pantry;
- `NOT_READY` may be re-evaluated directly to its next evaluation version with Pantry evidence; and
- `INVALIDATED` may be re-evaluated directly with Pantry evidence.

No historical Pantry binding may be fabricated or backfilled.

## 7. Read behavior and decision-first UX

Read models may show the evaluated period, root status, current evaluation version/result, exact Weekly Menu, Attendance, and Pantry snapshot/root/version evidence, issue counts, issue details, evaluation metadata, and handoff/invalidation history. Historical evaluation versions and their issue sets must remain queryable.

The primary question is: **Can Planning request Need Generation for this exact period?** UI visibility is not authorization or integrity enforcement. React may coordinate interaction, but authoritative lifecycle and binding rules belong to the future backend design.

## 8. Retool evidence and compatibility

The retained OPS v1 evidence records a Weekly Menu week/date-range selector, a separate Attendance date picker, an Attendance XLSX path that can represent one service date, legacy public writes, and hidden downstream rebalance reactions. It does not show a controlled combined readiness object. Atlas preserves the useful business facts—explicit period selection, source visibility, and handoff—while rejecting public writes, implicit rebalance, mutable source inference, and Retool page structure as authority. This qualitative review used retained repository/Issue evidence only; H0A4a did not inspect or change hosted Retool or Supabase state.

## 9. H0A4b persistence amended by PANTRY-RDY-02

PANTRY-RDY-01 remains the accepted business and architecture authority.
PANTRY-RDY-02 implements that authority in migration
`20260730231951_pantry_rdy_02_readiness_persistence.sql`, merged through PR
#163 as `70c380f49c148a1207574aabc5aefcb44cf30074`.

H0A4b implemented the original two-source persistence foundation in migration
`20260720135755_pa_06e_h0a4b_planning_input_readiness_persistence.sql`.
PANTRY-RDY-02 adds the three nullable Pantry columns, exact all-null-or-present
constraint, typed snapshot ownership unique/FK, leading index, issue
extensions, and in-place request/integrity guard amendments without adding a
relation, function, trigger, API, role, capability, policy, grant, seed, or
backfill.

The same three canonical independently runnable pgTAP suites remain the sole
readiness suites:

1. **Structure and security** — `plan(36)` in
   `supabase/tests/pa_06e_h0a4b_planning_input_readiness_structure_security.sql`.
   It owns schema, constraints, ownership FK/index, object and security posture,
   no source trigger, and zero seed/backfill.
2. **Evaluation and source-snapshot integrity** — `plan(59)` in
   `supabase/tests/pa_06e_h0a4b_planning_input_readiness_evaluation_source_snapshot_integrity.sql`.
   It owns all three source families, current approval, positive/zero Pantry
   evidence, containment, `READY`/`NOT_READY` completeness, and immutable
   history.
3. **Lifecycle, issues, and invalidation** — `plan(57)` in
   `supabase/tests/pa_06e_h0a4b_planning_input_readiness_lifecycle_issues_invalidation.sql`.
   It owns issue vocabulary, unchanged warnings, request behavior, lifecycle,
   null-Pantry history, explicit invalidation, no automatic source mutation,
   and no downstream write.

The focused total is 152 assertions. The detailed implementation record is
[TASK-PANTRY-RDY-02](../implementation-tasks/TASK-PANTRY-RDY-02-readiness-persistence.md).

### 9.1 RMVP-03B connected command and read implementation

RMVP-03B-02 implements the accepted connected database authority without
changing the persistence contract above. Migration
`20260731212845_rmvp_03b_connected_planning_input_readiness.sql` adds exactly
four authenticated `atlas_api` functions: one authoritative workbench read,
evaluation, Need Generation request handoff, and explicit invalidation. It
adds one unbound `planning.input_readiness.write` capability, bounded private
helpers, least-privilege grants, and RLS policies over existing relations.

The implementation adds no relation, view, role, runtime role, scope kind,
lifecycle state, or trigger. Request remains a handoff marker only, and every
RMVP-03B path leaves Need Generation and all downstream operational facts
unchanged. The focused API/security suite owns 84 assertions in addition to
the unchanged persistence plans `36/59/57`. See the
[bounded implementation record](../implementation-tasks/TASK-RMVP-03B-connected-planning-input-readiness-implementation.md).

## 10. Implementation boundary

PANTRY-RDY-02 changes private persistence enforcement only. It creates no
command, RPC, event, API registry entry, RLS policy, grant, runtime role,
generated type, React behavior, package, hosted Supabase/Retool state,
production data, or Need Generation behavior.

Command names, command parameters, authorization, actor attribution, reason
taxonomy, events, safe errors, API contracts, and operator UX are accepted
through [RMVP-03B Connected Planning Input Readiness](rmvp-03b-connected-planning-input-readiness.md)
and its [canonical accepted decision registry](../decisions/decision-rmvp-03b-connected-planning-input-readiness.md),
approved on 31/07/2026 and registered as D-027. The separately authorized
RMVP-03B-02 task implements the database/API authority and connected React
fourth tab on its bounded branch; final validation and independent review
remain pending.
