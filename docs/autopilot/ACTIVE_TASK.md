# Atlas Autopilot — Active Task

Task: ATLAS-OPERATOR-CONFIRMED-NEED-CORRECTION-C-DESIGN-01
Status: DESIGN_REVIEW_ONLY — proposed architectural spec prepared for human written-spec review; implementation is not authorized.
Navigator/reviewer: Terra, read-only
Implementer/document author: Sol 6.1
Starting main: d102b2f1b083005d6553867fa5ccdf8c988a0316
Atlas Staging: rnzxmxiiqgtdevzregff — accepted migration 109; no hosted database action in this task
OPS v1 / Retool / Production: no writes or commitments

## Authority — 15 October 2026

The Product Owner's operator fixes brief C and subsequent instruction to proceed authorize investigation/design of the existing append-only post-handoff correction workflow. D-044 already accepts School Need correction after PO/PXK, complete affected supplier/date replacement, the existing zero cancellation-required guard and explicit PXK successor release. The [proposed C architecture](../superpowers/specs/2026-10-15-operator-confirmed-need-correction-design.md) preserves that meaning; its new interface, continuity, locks and catalog reach remain PROPOSED technical design.

Root released this documentation-only Draft after Terra's TEMP design review while independent B CI continues. This does not authorize C code, migrations, tests, configuration or an implementation plan. Human written-spec review under the architectural brainstorming gate and a new bounded implementation baton are required before implementation. Do not interpret another routine continue as authority to skip that gate.

## Exact document scope

- This baton.
- `docs/superpowers/specs/2026-10-15-operator-confirmed-need-correction-design.md` — PROPOSED design and review obligations.
- Clearly PROPOSED dated pointers in existing `docs/api/confirmed-need-save-release-v2.md`, `docs/api/school-catering-procurement.md` and `docs/api/school-dispatch-release.md`; existing implemented contracts remain authoritative.

No app, SQL, test, config, workflow, dependency, A2/B implementation, historical 108/109 proof or Warehouse change. No merge, manual deployment or hosted database write is authorized/performed; automatic Pages previews from existing CI are not backend deployment/acceptance evidence. No actual staff grants, real supplier/PO/PXK commitments, Production or OPS v1/Retool writes.

## Required technical review

Review the closed correction preview/atomic reopen-plus-Save interfaces; the exact runtime EXECUTE proposal without new human authority; separate prospective Preparation eligibility and official post-release/Handoff applicability; strict full-family immutable Need revision/decision membership across every adjacent predecessor; pending source versus authoritative zero; and the migration 105 retained-PH lock omission. All advisory/source/run roots and CN batches must be ordered before target-first child locks, with complete later Supplier/Handoff/family locks and fresh proof after waits. Existing Save/Handoff/PO/PXK entry-point compatibility is an explicit obligation, not a completed proof.

The spec lists required authenticated public-path RED/GREEN, true lock-wait, immutable history, unaffected Supplier/day and PO/PXK identity proofs for a future implementation. None ran in this documentation-only task. Current released editing guards, raw fingerprints, RLS, capabilities/scopes and existing Preparation GLOBAL gate remain intact.

## Parallel Drafts and deferred work

[B Draft PR #387](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/387) is frozen at `2f915590175582dffb5831c8629f7e97b48fb3d8`. Exact-head [Frontend 38687613166](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/38687613166) and [Supabase Smoke 38687613193](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/38687613193) passed. [Full Integration 38687678513](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/38687678513) remains pending at handoff; do not assert a later result. Prior B failures remain documented in that branch. If B fails again, commit/clean this docs task and return for bounded B fix authority; do not mutate B while C edits are uncommitted.

PR #385/#386 remain separate operator Drafts; C assumes neither their schema nor B's batch API exists on main. Operator D remains deferred. The [Warehouse packet](../architecture/warehouse-receiving-minimum-design.md) remains READY FOR PRODUCT REVIEW with four UNDECIDED groups and no implementation approval. Existing 109 acceptance/read-gate reports remain historical; this task performs no repeat probes.

## Completion and next gate

Format and check relative links plus exact-range whitespace; commit/push a separate Draft architectural PR and attach it. No tests are added or rerun for prose. Keep the documentation Draft for human review. The next allowed action is written-spec review/clarification, not runtime implementation, merge, manual deployment or hosted writes.
