# Atlas Autopilot — Active Task

Task: ATLAS-OPERATOR-CONFIRMED-NEED-CORRECTION-C-DESIGN-01
Status: PLANNING — human written-spec approval recorded; TEMP implementation plan awaits Root/Terra technical review; only the bounded CI assertion correction below is authorized.
Navigator/reviewer: Terra, read-only
Implementer/document author: Sol 6.1
Starting main: d102b2f1b083005d6553867fa5ccdf8c988a0316
Atlas Staging: rnzxmxiiqgtdevzregff — accepted migration 109; no hosted database action in this task
OPS v1 / Retool / Production: no writes or commitments

## Authority — 15 October 2026

The Product Owner's operator fixes brief C and subsequent instruction to proceed authorize the existing append-only post-handoff correction workflow. On 15 October the user approved the reviewed spec: “if this mean PO/Dispatch can still re released after need correction then approve”. Root clarified the accepted meaning: valid affected positive POs can be explicitly released as reviewed complete replacements; Dispatch can be explicitly released as successors; old released documents remain preserved; true zero retains the existing cancellation-required guard. This matches spec `340721a49788163416176db816477168895f3442` and adds no automatic release chain or staff authority. D-044 already accepts School Need correction after PO/PXK, complete affected supplier/date replacement, the existing zero cancellation-required guard and explicit PXK successor release. The [proposed C architecture](../superpowers/specs/2026-10-15-operator-confirmed-need-correction-design.md) preserves that meaning; its interface, continuity, locks and exact catalog implementation remain subject to the implementation-plan technical review before code.

Human written-spec review is complete. Root authorized TEMP implementation planning and preparation of this baton, keeping the same C branch/PR. No C runtime implementation, migration or business test is authorized until Root/Terra review that concrete plan and release the bounded coding baton. The user may approve reviewed work in ordinary language; no prescribed approval phrase or repeated confirmation is required.

## Exact document scope

- This baton.
- `docs/superpowers/specs/2026-10-15-operator-confirmed-need-correction-design.md` — PROPOSED design and review obligations.
- Clearly PROPOSED dated pointers in existing `docs/api/confirmed-need-save-release-v2.md`, `docs/api/school-catering-procurement.md` and `docs/api/school-dispatch-release.md`; existing implemented contracts remain authoritative.

No app, SQL, test, config, workflow, dependency, A2/B implementation, historical 108/109 proof or Warehouse change. No merge, manual deployment or hosted database write is authorized/performed; automatic Pages previews from existing CI are not backend deployment/acceptance evidence. No actual staff grants, real supplier/PO/PXK commitments, Production or OPS v1/Retool writes.

## Bounded CI assertion correction — separately authorized

C design Frontend [38689177469](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/38689177469) failed one existing focus assertion in `src/modules/atlas/planning-inputs/PlanningInputsWorkbench.test.tsx:127`: the Sĩ số review region was present while focus remained on Lưu. Terra traced mount-effect focus and independently passed the tracked 38-case file locally; the timing failure was not locally reproduced. Root authorized only replacing the immediate `expect(review).toHaveFocus()` with `await waitFor(() => expect(review).toHaveFocus())`, using the existing import/default timeout. Preserve every other focus/removal assertion; no app changes, sleeps, timeout increases or test weakening. Commit this authority amendment before that one-line test edit. This exception does not release C runtime implementation.

## Required technical review

Review the closed correction preview/atomic reopen-plus-Save interfaces; the exact runtime EXECUTE proposal without new human authority; separate prospective Preparation eligibility and official post-release/Handoff applicability; strict full-family immutable Need revision/decision membership across every adjacent predecessor; pending source versus authoritative zero; and the migration 105 retained-PH lock omission. All advisory/source/run roots and CN batches must be ordered before target-first child locks, with complete later Supplier/Handoff/family locks and fresh proof after waits. Existing Save/Handoff/PO/PXK entry-point compatibility is an explicit obligation, not a completed proof.

The spec lists required authenticated public-path RED/GREEN, true lock-wait, immutable history, unaffected Supplier/day and PO/PXK identity proofs for a future implementation. None ran in this documentation-only task. Current released editing guards, raw fingerprints, RLS, capabilities/scopes and existing Preparation GLOBAL gate remain intact.

## Parallel Drafts and deferred work

[B Draft PR #387](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/387) is frozen at `2f915590175582dffb5831c8629f7e97b48fb3d8`. Exact-head [Frontend 38687613166](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/38687613166) and [Supabase Smoke 38687613193](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/38687613193) passed. [Full Integration 38687678513](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/38687678513) passed at the subsequent observed checkpoint. Prior B failures remain documented in that branch. If B fails again, commit/clean this docs task and return for bounded B fix authority; do not mutate B while C edits are uncommitted.

PR #385/#386 remain separate operator Drafts; C assumes neither their schema nor B's batch API exists on main. Operator D remains deferred. The [Warehouse packet](../architecture/warehouse-receiving-minimum-design.md) remains READY FOR PRODUCT REVIEW with four UNDECIDED groups and no implementation approval. Existing 109 acceptance/read-gate reports remain historical; this task performs no repeat probes.

## Completion and next gate

Format and check relative links plus exact-range whitespace; commit/push a separate Draft architectural PR and attach it. No tests are added for prose. Run only the authorized tracked 38-case PlanningInputsWorkbench file for the CI assertion correction, excluding ignored mirrors, then format/check and push the Draft. Continue the TEMP implementation plan for Root/Terra review; C runtime implementation, merge, manual deployment and hosted writes remain outside this phase.
