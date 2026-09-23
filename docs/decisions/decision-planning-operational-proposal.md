# Decision D-046 — Policy-derived Planning Operational Proposal

**Status:** Accepted

**Date:** 23/09/2026

**Approval:** Product Owner, task authorization
`PLANNING-OPERATIONAL-PROPOSAL-01`.

## Decision

Atlas keeps three quantity meanings distinct in school-catering Confirmed Need:

1. `theoretical_quantity` is the exact raw calculated requirement after all
   released contributions are aggregated to the seven-part operational
   identity. It is never rounded or overwritten.
2. The non-authoritative Draft proposal stored in the existing
   `confirmed_quantity` field is derived by PostgreSQL as
   `ceil(theoretical_quantity / planning_step) * planning_step`.
3. Confirmed operational need is explicit human authority recorded by H1B1
   decision evidence.

Materialization resolves exactly one H1A policy for the exact controlled Unit
and service date, set-wise across grouped identities. It quantizes the aggregate
once, never individual contributions. Missing, ineffective, or ambiguous policy
resolution rejects the whole materialization with no partial Confirmed Need
write. There is no dimension, Ingredient, global, conversion, or guessed
fallback.

The rule applies to initial materialization and successor correction
materialization. Existing revisions and old-semantics Drafts are not rewritten;
an old Draft can adopt the new rule only through the approved explicit
correction/regeneration path. D-040 remains authoritative when an unchanged,
policy-compatible successor legitimately carries an existing human decision.

## System derivation versus human confirmation

System proposal derivation is not a human adjustment. If raw `0.025500 kg`
under step `0.010000 kg` yields proposal `0.030000 kg`, accepting `0.030000`
creates `UNCHANGED_PROPOSAL_ACCEPTED` with `PROPOSAL_ACCEPTED`. It does not
create `PLANNING_STEP_ADJUSTMENT`.

Human confirmation remains fail closed. Operator-entered quantity must already
be an exact whole number of the effective policy step under exact decimal
arithmetic. The client may provide immediate step-aware feedback using decimal
strings, but neither client nor backend rounds, ceilings, truncates, trims, or
returns a replacement quantity for invalid input. A real change from `0.03` to
`0.04` uses `ADJUSTED_QUANTITY_CONFIRMED` and
`OPERATIONAL_QUANTITY_ADJUSTMENT` with the required note.

This explicitly reconciles H1A-P06: its rejection rule governs operator-entered
confirmation, while D-046 governs the earlier deterministic system proposal.

## Presentation and evidence

The Confirmed Need workbench presents `Nhu cầu tính`, `Đề xuất vận hành`, and
`Số lượng xác nhận` separately and shows the effective Planning step. Fresh
lines (`current_decision_id = null`) are not historical merely because a value
has six-decimal precision. Read-only historical protection is limited to actual
authoritative decisions that cannot safely round-trip through the current
step-aware editor.

First Save semantics under D-037 do not change: every fresh line receives an
explicit first decision, unchanged proposals remain `PROPOSAL_ACCEPTED`, and a
real operator change remains an operational adjustment. The system proposal is
explained by raw quantity plus policy and creates no decision row itself.

## Consequences and boundaries

The existing Confirmed Need aggregate and storage are reused. No proposal table,
aggregate, lifecycle, public API, fallback policy, production seed, or generic
rules engine is introduced. Planning policy remains distinct from Procurement
purchase/order steps. Source membership, theoretical lines, decisions, released
history, security boundaries, RLS, timeouts, retry behavior, Purchase Handoff,
Procurement, Warehouse, Dispatch, Retool, and OPS v1 semantics are unchanged.

Implementation is by one forward migration replacing the bounded private
materializer while preserving its signature, owner, security-definer posture,
empty search path, and grants. The migration rewrites no existing business row.
Rollback after deployment requires a reviewed forward migration; it must not
rewrite materialized or human-authorized history.

See the [implementation task](../implementation-tasks/TASK-PLANNING-OPERATIONAL-PROPOSAL-01.md).
