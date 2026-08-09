# Decision D-036 — Planning Completion and Commitment Boundaries

**Status:** Accepted

**Date:** 09/08/2026

## Context

Weekly Menu, Attendance, Pantry, Planning Input Readiness, Need Generation,
and Confirmed Need materialization currently expose backend lifecycle steps as
separate operator actions. Retained OPS v1 evidence supports a simpler mental
model: edit operational facts, save them, and let downstream Planning use the
saved result. Atlas must preserve stronger validation, lineage, immutable
history, authorization, and audit without asking operators to administer
deterministic system work.

No accepted current business requirement requires a different person to
validate or approve Weekly Menu, Attendance, or Pantry after the responsible
operator completes the input.

## Decision

Atlas adopts this governing principle:

> **Humans approve business commitments. Systems validate deterministic system work.**

An operator-visible transition is justified only when it records human-authored
input completion, a real business decision, or a necessary exception or
correction.

For Weekly Menu, Attendance, and Pantry, one successful **Save** is the normal
completion boundary. The backend must atomically validate the submitted facts,
persist the authoritative current version, create the immutable completion
snapshot and lineage evidence required downstream, record receipt/event/audit
evidence, and return authoritative readback. Separate normal **Validate** and
**Approve** clicks are removed from the future operator contract unless a later
approved business requirement proves a distinct human decision or approver.

Planning Input Readiness remains backend authority and immutable diagnostic
evidence, but not a normal operator lifecycle. The backend automatically derives
`READY` or `BLOCKED` from the current completed Menu, Attendance, and Pantry
evidence. Ambiguous, missing, and stale evidence remains visible for correction.
Normal **Evaluate Readiness** and **Request Need Generation** clicks are removed.

Need Generation becomes one operator command: **Tạo nhu cầu**, or **Cập nhật nhu
cầu** when replacing an outdated derived result. In one backend transaction it
must bind the current inputs, derive readiness, generate all authoritative
facts, validate integrity, create the immutable released theoretical Need, and
materialize or correct Confirmed Need. If any invariant blocks the operation,
the transaction creates no misleading current downstream result and returns the
blockers. Create, Validate, Release, and CMD-15 materialization are not separate
normal human decisions.

Confirmed Need is the first human review and commitment boundary after
deterministic Need Generation. Planning reviews or corrects quantities there and
completes/releases the batch for Purchase Handoff under the separately governed
Confirmed Need contract. This decision does not redesign Confirmed Need.

A later upstream Save creates a successor source version. Prior released source,
generation, Confirmed Need, receipt, event, audit, and lineage evidence remains
immutable. The current read model marks or derives the affected downstream
result as outdated and presents one **Cập nhật nhu cầu** correction path. A
successor generation and Confirmed Need correction must preserve predecessor
lineage and obey the existing downstream correction boundary.

## Consequences

- Readiness's normal preflight is absorbed into `Tạo nhu cầu`; readiness history,
  ambiguity resolution, blockers, and support evidence remain contextual detail.
- The separate `Sẵn sàng đầu vào` primary destination should be retired after
  contract implementation and UI cutover, not before.
- Source-specific write capabilities and `planning.inputs.approve` are replaced
  in the normal input-completion path by one simpler Planning-input completion
  capability when the same operator owns completion. Readiness write authority
  and CMD-15 materialization cease to be independent operator capabilities.
- Need Generation retains one operator execution capability; its deterministic
  substeps become backend-internal.
- Existing versions, snapshots, lifecycle rows, command receipts, domain events,
  audit events, immutable generation evidence, release membership, predecessor
  lineage, and correction history are retained.
- The new behavior requires versioned backend contracts and forward migrations.
  It must not be simulated by sequential browser calls to existing commands.

D-036 amends D-023, D-024, D-026, D-027, and D-029 only at their normal
operator-command and completion boundaries. Their accepted ownership, typed
references, validation rules, immutable evidence, security, lineage, and
historical-preservation decisions remain in force. D-030 and D-031 remain the
authority for the current Confirmed Need boundary until separately amended.

## Implementation boundary

This decision authorizes documentation only. `PLANNING-CONTRACT-01` must define
the versioned atomic commands, currentness/staleness projection, compatibility
and capability migration before `UI-QUALITY-02AB-UX` changes the application.
No API, migration, SQL, React, Retool, hosted Supabase, or production behavior is
changed by D-036.
