# PANTRY-RDY-01 — Planning Input Readiness Pantry-Binding Amendment

- **Status:** Accepted
- **Approval date:** 2026-07-29
- **Domain:** Planning
- **Business owner:** Tổ Kế hoạch
- **Canonical decision:** [Decision PANTRY-RDY-01](../decisions/decision-pantry-rdy-01-planning-input-readiness.md)
- **Amends:** [PD-01.4 Planning Domain Input Readiness Contract](planning-domain-input-readiness-contract.md)

## 1. Purpose

This amendment makes an exact approved Pantry snapshot the mandatory third
source for every new `READY` evaluation and every new Need Generation request.
It preserves the stable exact-period Planning Input Set root, immutable
evaluation history, closed lifecycle, and evidence-only handoff boundary.

Missing Pantry evidence is blocking. It is never interpreted as no additions.
An approved explicit zero-line Pantry snapshot is positive controlled evidence
that no additions were requested for its week.

This amendment creates no calculation or downstream operational fact.

## 2. Three direct typed source families

Every readiness evaluation has three distinct direct typed source-binding
families:

1. Weekly Menu approval snapshot, root, and approved version;
2. Attendance approval snapshot, root, and approved version; and
3. Pantry approval snapshot, batch, and approved batch version.

The Pantry family is exactly:

- `pantry_need_batch_id`;
- `pantry_need_approval_snapshot_id`; and
- `approved_batch_version`.

Those three fields are all absent or all present. When present, the binding
must prove that the immutable approval snapshot belongs to the exact Pantry
batch at the recorded approved batch version.

A generic or polymorphic input-reference relation, JSON-only payload, hash-only
claim, status string, or untyped `(input_type, input_id, input_version)` tuple
is not authoritative source evidence.

For a new `READY` evaluation and a new Need Generation request, all three exact
bindings are mandatory and the evaluation must contain zero blocking issues.
A `NOT_READY` evaluation may omit an unavailable family only when its immutable
blocking issue explains the missing or incompatible evidence.

## 3. Pantry eligibility and period containment

One Pantry snapshot is eligible for a new `READY` evaluation only when:

- its batch is currently `APPROVED`;
- the batch's current version equals the snapshot's
  `approved_batch_version`;
- the batch's latest-approval pointer equals the selected
  `pantry_need_approval_snapshot_id`;
- snapshot, batch, and version ownership are exact; and
- the Pantry batch week wholly contains the evaluated inclusive period.

Draft, Validated, Reopened, and superseded Pantry evidence is ineligible for a
new evaluation. Partial period overlap, a disjoint period, or an uncovered
evaluated day is blocking. Multiple Pantry snapshots cannot be combined to
manufacture coverage.

The existing containment rules remain unchanged for Weekly Menu and Attendance.
All three source periods must independently contain the evaluated period.

## 4. Positive and explicit zero-line Pantry evidence

Two Pantry approval shapes are equally valid readiness evidence:

- an approved positive-line snapshot containing every-and-only approved active
  Pantry line; and
- an approved explicit zero-line snapshot with
  `no_additions_confirmed = true`, `line_count = 0`, and zero snapshot-line
  rows.

An explicit zero-line snapshot is neither missing evidence nor a quantity line.
It creates no zero-quantity Pantry line and authorizes no inferred contribution.
An empty draft, an absent approval, or an unconfirmed empty line set is not
equivalent evidence.

## 5. Issues and warnings

The blocking issue catalog gains exactly:

- `MISSING_PANTRY_APPROVAL_SNAPSHOT`; and
- `PANTRY_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD`.

Pantry also uses the existing shared blockers where applicable:

- `SOURCE_SNAPSHOT_OWNERSHIP_MISMATCH`;
- `STALE_OR_MISMATCHED_SNAPSHOT_BINDING`; and
- `REQUEST_WITHOUT_CURRENT_READY_EVALUATION`.

Issue context permits `input_type = 'PANTRY'`.

The three existing warnings remain unchanged:

- `MENU_SCHOOL_DATE_WITHOUT_ATTENDANCE`;
- `ATTENDANCE_SCHOOL_DATE_WITHOUT_MENU`; and
- `ZERO_ATTENDANCE_FOR_PLANNED_MENU`.

This amendment adds no Pantry cross-source warning, expected-School catalogue,
omitted-day rule, default, acknowledgement, waiver, or override.

## 6. Immutability, invalidation, and request eligibility

Prior evaluations, source bindings, issues, results, and versions remain
immutable. Reapproval or correction of a Pantry batch never rewrites readiness
evidence. A later accepted Pantry approval requires an explicit invalidation
where the current lifecycle permits it, followed by a successor evaluation on
the same exact-period root.

No automatic Pantry-to-readiness trigger is authorized. Upstream source changes
do not mutate or automatically invalidate a Planning Input Set.

A new Need Generation request must revalidate that all three bindings still
identify the exact current approved source snapshots and that the evaluation
remains the root's exact current `READY` evaluation with zero blockers. It
fails closed when the Pantry batch is not `APPROVED`, its current version
differs, its latest approval pointer differs, typed ownership fails, or the
evaluated period is not contained.

## 7. Historical compatibility

Readiness evaluations created before PANTRY-RDY-02 remain immutable and may
retain null Pantry binding fields. They remain valid historical evidence, but
after this amendment they cannot authorize a new Need Generation request.

A current Planning Input Set relying on a pre-amendment evaluation must be
explicitly invalidated and re-evaluated with one exact approved Pantry
snapshot. No historical Pantry binding may be fabricated or backfilled.

## 8. No downstream calculation

PANTRY-RDY-01 stops at readiness evidence. It does not:

- read Pantry snapshot lines into a calculation;
- create a Pantry Need Generation contribution;
- resolve Recipe/BOM evidence for Pantry;
- create or release a Need Generation run;
- create Theoretical Need, Confirmed Need, or Purchase Handoff;
- select supplier or Warehouse fulfilment;
- mutate Procurement, Warehouse, Dispatch, or Wholesale; or
- modify OPS v1/v2, Retool, hosted Supabase, or production data.

The Pantry Need Generation amendment remains a separate, not-started product
decision.

## 9. Future PANTRY-RDY-02 implementation boundary

This document authorizes no implementation. A later separately authorized
PANTRY-RDY-02 is limited to one migration and must add zero relations, public
APIs, capabilities, roles or runtime roles, scope kinds, policies, and
automatic source triggers.

Its expected physical delta is:

- three nullable Pantry binding columns on
  `atlas_planning.planning_input_evaluations`;
- an all-null-or-all-present constraint;
- a direct composite ownership foreign key;
- a supporting Pantry snapshot unique constraint only when required;
- a leading Pantry-binding index;
- the two issue-code extensions and `input_type = 'PANTRY'`;
- in-place amendments to the existing readiness guards; and
- in-place amendments to the three canonical readiness pgTAP suites.

No fourth readiness relation or fourth overlapping readiness test suite is
authorized. The existing H0A4b migration, tests, and implementation record
remain unchanged in PANTRY-RDY-01.

## 10. Supersession boundary

PANTRY-RDY-01 supersedes parent statements that define exactly two readiness
source families or require only Weekly Menu and Attendance for `READY` or a new
Need Generation request. Every other parent authority remains in force,
including the stable root, immutable evaluations and issues, closed lifecycle,
explicit invalidation, warning acknowledgement deferral, and evidence-only
handoff semantics.
