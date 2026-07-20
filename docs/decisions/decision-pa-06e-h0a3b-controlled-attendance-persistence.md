# Decision PA-06E-H0A3b — Controlled Attendance Persistence

**Status:** Accepted for the bounded Issue #123 foundation

**Date:** 2026-07-20

**Owner:** Planning

**Parent contracts:** [Planning Domain Attendance](../architecture/planning-domain-attendance-contract.md) and [PA-06E-H0 School-Catering Persistence and Materialization](../architecture/pa-06e-h0-school-catering-persistence-and-materialization-contract.md)

## Decision

Issue #123 establishes the smallest private PostgreSQL foundation for controlled Attendance. It persists:

- one stable `atlas_planning.attendance_batches` root per exact inclusive period tuple;
- stable `attendance_lines` with typed School and exact integer student/teacher portions;
- one immutable approval snapshot per positive Attendance version; and
- immutable snapshot lines that exactly copy every and only `ACTIVE` line accepted at approval.

Attendance belongs to Planning and answers how many student and teacher portions are expected for each School and service date. It does not perform ingredient calculation.

## Stable root and working-line decision

The Attendance root retains its UUID and exact inclusive period through import, correction, approval, use for Need Generation, and reopen. Any period with `period_end >= period_start` is valid; no Monday or fixed seven-day rule is introduced. Source type, source name, and source signature are nonblank, row count is nonnegative, and version is positive.

Source type, source name, source signature, row count, imported actor/time, and `updated_at` describe the current working version. They may change only during same-state `DRAFT` or `REOPENED` refreshes, without changing version or approval history. Every lifecycle transition preserves those facts exactly, and same-state `VALIDATED`, `APPROVED`, and `USED_FOR_NEED_GENERATION` records are immutable.

Every root enters as `DRAFT`. The only accepted transitions are:

```text
DRAFT → VALIDATED → APPROVED → USED_FOR_NEED_GENERATION
                           ↘
       APPROVED / USED_FOR_NEED_GENERATION → REOPENED → DRAFT
```

Reopen advances exactly one version; all other transitions preserve version. `APPROVED → USED_FOR_NEED_GENERATION` preserves source/import and approval actor/time/snapshot evidence. Reopen preserves all prior approval evidence. A later approval must use a distinct snapshot for the later version.

A stable line belongs permanently to one Attendance batch. Its unique assignment is:

```text
Attendance batch + School + service date → student portions + teacher portions
```

The date must fall inside the root period. Student and teacher portions are exact nonnegative integers and may be zero. School/date, portions, `ACTIVE`/`INVALID` status, optional nonblank source-row reference, and update actor/time may change only while the root is `DRAFT` or `REOPENED`; line UUID, batch, creator, and creation time remain fixed. School references are restrictive and remain valid for historical identity whether the referenced School is active or inactive. H0A3b decides no active-School policy.

## Approval snapshot decision

Approval is represented by one immutable snapshot header for the exact current positive Attendance version. The snapshot actor and timestamp must exactly match the root's latest approval evidence.

Snapshot lines carry the stable line ID plus exact batch/version, School, service date, student portions, teacher portions, and optional source-row reference. Composite keys prove ownership declaratively. Minimum private guards reject:

- snapshot creation outside the exact current `VALIDATED` version;
- missing `ACTIVE` lines;
- `INVALID` or extra lines;
- altered copied fields;
- cross-batch or wrong-version ownership;
- duplicate stable lines or duplicate School/date assignments; and
- snapshot update or deletion.

An `APPROVED` or `USED_FOR_NEED_GENERATION` root must reference its complete exact current-version snapshot. Reopening makes working lines mutable without changing earlier snapshots. A later approval creates a new immutable snapshot while all earlier approvals remain queryable and protected by restrictive relationships.

## Security and boundary decision

All four relations and four private guards are owned by `atlas_owner`. Relations have RLS enabled and forced with zero policies. `PUBLIC`, `anon`, `authenticated`, and `service_role` receive no table, sequence, or private-function privilege. Private guards use empty `search_path` values, and established fail-closed default privileges remain unchanged.

H0A3b adds no `atlas_api` function, runtime owner, role, capability, membership, policy, seed, generated type, package, read model, RPC, React surface, Retool write, public/`ops_v2` relation, hosted Supabase action, production data, credential, or deployment behavior. The canonical 18-function API registry remains exact.

Retained OPS v1, Retool, spreadsheets, and the TypeScript Attendance prototype are qualitative evidence only. Atlas does not copy, write, synchronize, or infer portion defaults from them in this task.

## Independent pgTAP ownership decision

H0A3b verification is divided into three independently runnable files with non-overlapping invariant ownership:

- `supabase/tests/pa_06e_h0a3b_attendance_structure_security.sql` owns 28 structure/security assertions: exact schema, columns, constraints, restrictive indexed foreign keys, private guards/triggers, ownership, RLS, grants, search paths, API registry, and zero authorization seeds.
- `supabase/tests/pa_06e_h0a3b_attendance_lifecycle_mutability.sql` owns 78 lifecycle/mutability assertions: inclusive periods, DRAFT-first creation, exact transitions and versions, source refresh/preservation, frozen states, stable identity, exact portions, and DRAFT/REOPENED line mutation.
- `supabase/tests/pa_06e_h0a3b_attendance_approval_snapshot_integrity.sql` owns 40 approval-history assertions: exact current-version snapshots, completeness and field-copy rejection, actor/time/root binding, use/reopen preservation, later approval, and immutable historical snapshots.

Each suite owns its transaction and fixtures and passes independently after a clean reset. The 146 assertions are combined supplemental coverage only; no invariant is claimed by more than one suite.

## Deferred decisions

The following remain separate work:

- import, validate, edit, approve, use, and reopen commands;
- actor authorization, capabilities, reasons, warnings, acknowledgements, issues, events, audit, and receipts;
- same-signature, drift, omitted-School/day, default-portion, and active-School policies;
- Planning Input Set, readiness, Need Generation, Recipe application, ingredient calculation, Confirmed Need, and downstream correction;
- read APIs, generated types, React, Retool, migration/backfill, hosted execution, and production rollout.

Any later task requiring these choices must obtain its own explicit contract and issue rather than broadening this foundation.

## Migration and rollback effect

The migration is additive and seeds no row. Before operational data or dependent migrations exist, an unshipped migration can be reverted normally. After use, approval history must not be deleted or rewritten; an unsafe path must be revoked and forward-fixed through another reviewed migration.
