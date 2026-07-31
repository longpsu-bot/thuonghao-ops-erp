# Decision PA-06E-H0A4b — Planning Input Readiness Persistence

**Status:** Accepted Issue #127 foundation; Pantry binding amended by
PANTRY-RDY-02 on the bounded task branch, pending review and merge

**Date:** 2026-07-20

**Owner:** Planning

**Controlling design:** [Decision PA-06E-H0A4 — Planning Input Readiness](decision-pa-06e-h0a4-planning-input-readiness.md)

**Persistence amendment:** [Decision PANTRY-RDY-02 — Pantry-Bound Readiness Persistence](decision-pantry-rdy-02-readiness-persistence.md)

## Decision

Issue #127 establishes the minimum private PostgreSQL persistence for the accepted H0A4 readiness model:

- one stable `planning_input_sets` root per exact inclusive period;
- immutable `planning_input_evaluations` with positive, contiguous root-local versions;
- one direct typed Weekly Menu approval-snapshot/root/version binding and one direct typed Attendance approval-snapshot/root/version binding per evaluation; and
- immutable `planning_input_evaluation_issues` owned by one exact evaluation/root/version.

The root has no separate version. Its only mutable control is the exact current evaluation pointer, readiness status, and update time. It cannot commit without a current evaluation, cannot cross roots or skip evaluation versions, and cannot be deleted. Evaluation and issue rows cannot be changed or deleted.

## Readiness and warning decision

`READY` requires both source bindings, exact current approved or handed-off upstream versions and latest snapshots, complete containment of the evaluated period, and zero blocking issues. `NOT_READY` requires at least one blocker and the exact applicable missing-source, insufficient-period, or stale-binding evidence. Stored counts must equal their issue rows.

Warnings are nonblocking and are every-and-only the three accepted observations found in both bound immutable snapshot families inside the evaluated period: Menu without Attendance, Attendance without Menu, and zero Attendance for a planned Menu. No expected-School/day catalogue, omitted-day rule, default, slot rule, active-School policy, acknowledgement, waiver, or override is introduced.

## Lifecycle and invalidation decision

The physical lifecycle is exactly the accepted H0A4a matrix. A first evaluation establishes `NOT_READY` or `READY`. Only `NOT_READY` or `INVALIDATED` may receive the exact next evaluation. `READY` may become `NEED_GENERATION_REQUESTED` or `INVALIDATED` without replacing its evaluation, and a requested root may become `INVALIDATED` without replacing evidence. Every other transition fails.

Request revalidates the current READY evaluation against both exact current source snapshots. Upstream correction never changes H0A4 rows automatically. Explicit invalidation preserves the historical evaluation, and later re-evaluation creates the next immutable version. No trigger is added to an upstream relation.

## Security and boundary decision

The three relations and four private guard functions are `atlas_owner` owned. All relations have enabled and forced RLS with zero policies. `PUBLIC`, `anon`, `authenticated`, and `service_role` have no new relation, sequence, or private-function privilege. The guards use empty search paths and are invoker-security. The established 18-function `atlas_api` surface and fail-closed default privileges remain unchanged.

H0A4b and PANTRY-RDY-02 add no command, read API, authorization vocabulary,
reason/event/audit/receipt contract, runtime role, generated type, UI, seed,
hosted action, or downstream calculation. Those remain separately authorized
work.

## PANTRY-RDY-02 amendment

PANTRY-RDY-02 preserves all three H0A4b relations, the stable root grain,
immutable sequential evaluation/issue history, and the closed lifecycle. It
adds the exact nullable Pantry batch/version/snapshot family, typed composite
ownership, and fail-closed current-approval/period checks for every new
`READY` evaluation and Need Generation request.

The request and deferred integrity guards are replaced in place. The evaluation
and issue guards, all six readiness triggers, the three existing
materialization SELECT policies, and every role/API/capability/grant boundary
remain unchanged. Historical evaluations are not backfilled and may retain
null Pantry fields, but cannot authorize a new request.

The canonical readiness suite plans change from `29/45/48` to `36/59/57`, or
from 122 to 152 focused assertions, without adding a suite.

## Migration and rollback effect

Both migrations are additive and seed no row. Before operational use an
unshipped amendment may be reverted through a local rebuild. After use,
immutable readiness and source history must be preserved; any correction is a
reviewed forward migration, not deletion or rewrite.
