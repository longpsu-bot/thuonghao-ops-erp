# Decision D-046 — Ingredient-derived Planning Operational Proposal

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
   `ceil(grouped_raw_requirement / ingredient.order_step) * ingredient.order_step`,
   where `grouped_raw_requirement` is the persisted exact
   `theoretical_quantity`.
3. Confirmed operational need is explicit human authority recorded by H1B1
   decision evidence.

Materialization resolves the exact active Ingredient and its versioned
`purchase_unit_id`/`order_step` set-wise across grouped identities. The
Ingredient purchase Unit must equal the controlled Unit and `order_step` must
be positive. It quantizes the aggregate once, never individual contributions.
There is no conversion, dimension default, global default, or guessed fallback.

Materialization also resolves exactly one H1A policy for the exact controlled
Unit and service date. H1A does not produce the proposal: it remains the minimum
human confirmation quantum. The Ingredient rounding step must be an exact
positive integer multiple of the H1A step so every generated proposal is
representable at confirmation. Missing/invalid Ingredient configuration,
missing/ambiguous H1A resolution, or incompatible steps reject the whole
materialization before any Confirmed Need write.

The rule applies to initial materialization and successor correction
materialization. Existing revisions and old-semantics Drafts are not rewritten;
an old Draft can adopt the new rule only through the approved explicit
correction/regeneration path. D-040 remains authoritative when an unchanged,
policy-compatible successor legitimately carries an existing human decision.

## System derivation versus human confirmation

System proposal derivation is not a human adjustment. If raw `0.025500 kg`
under Ingredient step `0.100000 kg` yields proposal `0.100000 kg`, accepting it
creates `UNCHANGED_PROPOSAL_ACCEPTED` with `PROPOSAL_ACCEPTED`. It does not
create `PLANNING_STEP_ADJUSTMENT`.

Human confirmation remains fail closed. Operator-entered quantity must already
be an exact whole number of the effective policy step under exact decimal
arithmetic. The client may provide immediate step-aware feedback using decimal
strings, but neither client nor backend rounds, ceilings, truncates, trims, or
returns a replacement quantity for invalid input. For example, when the
Ingredient-derived proposal is `1.500000 kg`, Ingredient step is `0.500000 kg`,
and H1A is `0.010000 kg`, human confirmation `1.370000 kg` is valid while
`1.375000 kg` is rejected. A real valid change uses
`ADJUSTED_QUANTITY_CONFIRMED` and
`OPERATIONAL_QUANTITY_ADJUSTMENT` with the required note.

This explicitly reconciles H1A-P06: its rejection rule governs operator-entered
confirmation, while D-046 governs the earlier deterministic system proposal.

## Presentation and evidence

The Confirmed Need workbench presents `Nhu cầu tính`, `Đề xuất vận hành`, and
`Số lượng xác nhận` separately. The proposal shows `Làm tròn` from the
snapshotted Ingredient step; the input shows `Bước xác nhận` from H1A. Fresh
lines (`current_decision_id = null`) are not historical merely because a value
has six-decimal precision. Read-only historical protection is limited to actual
authoritative decisions that cannot safely round-trip through the current
step-aware editor.

First Save semantics under D-037 do not change: every fresh line receives an
explicit first decision, unchanged proposals remain `PROPOSAL_ACCEPTED`, and a
real operator change remains an operational adjustment. The system proposal is
explained by raw quantity plus the Ingredient rounding snapshot and creates no
decision row itself.

## Consequences and boundaries

The existing Confirmed Need aggregate and revision storage are reused. The
revision gains nullable `proposal_rounding_step` and
`proposal_rounding_ingredient_version` evidence columns: legacy revisions stay
null, while every new `NEED_GENERATION` revision snapshots both values. No
proposal table, aggregate, lifecycle, new public endpoint, fallback policy,
production seed, or generic rules engine is introduced. Reusing
`Ingredient.order_step` does not move human confirmation authority to
Procurement or alter downstream purchase semantics. Source membership,
theoretical lines, decisions, released
history, security boundaries, RLS, timeouts, retry behavior, Purchase Handoff,
Procurement, Warehouse, Dispatch, Retool, and OPS v1 semantics are unchanged.

Implementation is by one forward migration replacing the bounded private
materializer while preserving its signature, owner, security-definer posture,
empty search path, and grants. The migration rewrites no existing business row.
Rollback after deployment requires a reviewed forward migration; it must not
rewrite materialized or human-authorized history.

See the [implementation task](../implementation-tasks/TASK-PLANNING-OPERATIONAL-PROPOSAL-01.md).
