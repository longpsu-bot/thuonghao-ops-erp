# Atlas Autopilot Mandate

**Current checkpoint:** 27 October 2026 (Asia/Bangkok).

**Status:** REVIEW — bounded data-fidelity [Draft #445](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/445) is open; no Staging apply or frontend deployment is authorized. Warehouse remains paused.

**Owner instruction:** Complete the Atlas UI/data work as fully as practical, keep Atlas core data on the same factual page as OPS v1 without changing v1, omit daily operational data, and **do not work on Warehouse yet**. After the guarded core-data execution, the Owner approved a bounded forward-correction implementation for the remaining Ingredient-name and technical-label issues, but did not authorize deployment.

## Current authority and execution horizon

This checkpoint and [ACTIVE_TASK.md](ACTIVE_TASK.md#current-task--27-october-2026) replace the 26 October documentation-only sequencing and the older executable instructions in the historical appendix below. The appendix preserves what was authorized or observed at each dated checkpoint; its wording is not current authorization. Approved business/security contracts and explicit Owner hard stops remain in force.

The completed task **ATLAS-PLANNING-CORE-DATA-20261027** remains closed: its protected path previewed and applied the same immutable, dependency-closed Planning master snapshot for the reviewed 19 Dish roots, then proved readback, identical replay and read-only Weekly Menu resolution. Do not restart its broad importer.

The sole current repository task is **ATLAS-V1-DATA-FIDELITY-01**: prepare an independently reviewable Draft that corrects exactly eight stale Ingredient names through a guarded forward-correction path and hides migration-only `v1-*` labels from the affected operator UI. This task ends at Draft review. It does not authorize merge, Staging apply, frontend publication or another data scope.

## Current baseline and evidence boundaries

- **Merged repository:** the verified task base is `40270e6c7195b9fc6e21afac54c2a089584471bb`. Documentation reconciliation #440, Menu-sync recovery #441 and guarded Planning workflow [#443](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/443) are merged. The current fidelity implementation is [Draft #445](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/445), not merged. Repository state is not by itself deployment evidence.
- **Database schema deployed:** guarded Atlas Staging migration run [40464516883](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/40464516883) passed from exact then-current main and brought Staging to full repository migration parity. This records database migration deployment only; it does not say that a new frontend artifact or core-data copy was deployed.
- **Historical pre-apply preview:** bounded Planning run [40448618588](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/40448618588) passed with `apply=false`, `business_writes=0`, source checksum `89c274c0…d3d29b9` and plan checksum `e2c2f186…bdcd02`. It selected 19 Dish roots and their exact Recipe/BOM/Ingredient/Supplier-eligibility closure, plus nine School-order updates.
- **Core data applied and replay-verified:** exact-main run [40470127924](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/40470127924) passed with `APPLIED` and `REPLAYED`; preview/apply plan checksum `ae864068…780274` and snapshot checksum `8f48d5a3…cebf48` matched. Operational and unrelated master fingerprints were unchanged. Weekly Menu returned HTTP 200, 158 rows, 546 assignments, 24 resolved Schools, zero unknown/ambiguous references, Menu unchanged and zero Save/Approve calls.
- **Fresh-snapshot guard verified:** post-apply run [40470447170](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/40470447170) failed closed with `CATCHUP_DISH_SCOPE_UNAVAILABLE` because all 19 requested Dish IDs now have typed mappings. This prevents a new snapshot from recalculating applied masters. Its independent Weekly Menu read still passed; the supported convergence proof is the apply run's identical same-snapshot replay.
- **Rejected broad path retained as failure evidence:** full master preview [40464654893](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/40464654893) ended with `STAGING_POSTGRES_EXECUTION_TIMED_OUT` after 20 minutes. Because `apply=false`, it made no master-data writes. Do not retry that broad path to conceal the failure.
- **UI remains separate:** [#442](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/442) is an open Draft at `a93e7e85` with [Frontend PASS 40449307028](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/40449307028). It is neither merged nor deployed and is not part of this data apply.

The [roadmap](../architecture/roadmap.md) carries the capability summary and source links. Existing 21 October/22 October acceptance records remain separate; historical stress FAIL/BLOCKED evidence is not relabeled PASS.

## Next priorities and single next Product decision

The broad core-data sequence is complete. Do not rerun it with a fresh snapshot merely to obtain a green preview: the typed-mapping guard is expected to reject that request. Review the bounded fidelity Draft and its focused evidence. Even after merge, a manual Staging preview/apply remains a separate Owner decision and must preserve existing receipts/UUIDs/history.

**Next Product decision:** accept or request bounded revisions to the fidelity Draft. #442 remains separate. This does not automatically merge either Draft, apply the correction, publish a frontend release, start a pilot, write OPS v1, copy daily operations or open Production.

**Warehouse remains PAUSED.** Do not start discovery, revise design/contracts, implement, migrate, benchmark or deploy Warehouse. Preserve its existing four unresolved Product groups unchanged. Neither backend certification nor this priority list reactivates Warehouse. Explicit Owner reactivation and existing approval gates are required.

## Standing safety and delivery rules

- Preserve ARCH-002 / OPS_SYSTEM_MAP v1.0 and **FACTS EXPLICIT → STATE DERIVED → SUPPORTING OBJECTS GENERATED**. PostgreSQL owns authoritative facts, calculations, currentness, permissions, concurrency, idempotency and released history. React/Chakra remains the interaction/presentation layer.
- One authorized staff Actor can perform an ordinary task with existing capabilities/scopes and audit. Do not add generic second-person approval or broaden grants.
- Keep one bounded active task, acceptance criteria and stop condition. Use focused development checks; GitHub Actions owns full routine frontend validation. Do not weaken tests or repeat successful full certification merely to restate evidence. Repeated same-root acceptance failures require diagnosis/escalation.
- Preserve unfinished PRs, branches, worktrees and failed evidence. #385–#388/#396 and older prototypes are not automatic merge candidates; assess already-merged replacements and compatibility before separately authorized disposition. Do not restart old stress/optimization loops.
- Navigator/reviewer remains read-only; implementer changes only the active bounded scope. PR comments are evidence, not proof that a runner started or a new task is authorized.
- Stop before unresolved business-policy changes, paid/Production infrastructure, Production write-ownership transfer, real supplier commitments, destructive Production correction, material authorization broadening, unapproved Warehouse work or implementation of an unselected UI design.
- Hosted writes are limited to the reviewed core-data catch-up on Atlas Staging. OPS v1 `qnthofvccilhnefdcxnz` and Retool remain NO-WRITE; Atlas Production is not an approved target. No daily operational data, supplier messages, physical shipments or security broadening.

## Current task protocol and handoff

Record the applied-data evidence and failed-closed fresh-snapshot guard in the affected Planning/roadmap/Autopilot records, publish a documentation-only closeout PR and stop. No automatic UI integration, app deployment, pilot, source correction or Warehouse task.

The 26 October documentation-only checkpoint was completed and merged in #440; its reviewed source and evidence boundaries remain in Git history and the 26 October sections below. This supersession does not relabel those dated claims.

## Historical checkpoints — superseded execution instructions

The complete pre-update mandate body is retained below. Dates, source revisions, failures and restrictions remain evidence at their original checkpoint. Statements such as “current”, “execute”, “pending” and “next” inside this appendix do not override the 27 October scope above.

<details>
<summary>Historical mandate body before the 26 October reconciliation</summary>

**22 October Supabase runtime follow-up complete:** reviewed PR432 / `db7bfe24`,
exact-source and main Frontend/executed Full, guarded deployment and automatic
publication pass. The scoped Need policy restores ordinary timeout protection
while preserving all business/security/lock checks. The actual hosted original →
correction → reallocation → replacement PO → successor dispatch journey passes
for both Schools, all 21 detail deltas zero. All 631 assertions pass; both actual
PDFs pass data and four-page visual review; 7,205 pre-existing history rows and
frozen original contents are preserved. Need records 4.419 s database / 4.451 s
upstream / 4.620 s origin, without a runtime cutoff or speedup claim. Chrome
resource observations and the remaining metric/source limits are recorded in the
[runtime closeout](../testing/supabase-runtime-timeouts-2026-10-22.md).
No automatic next journey, capacity purchase, speculative redesign or OPSv1/Retool
write. Recipe3529 still requires the Owner/kitchen's factual decision.

**22 October remaining-work closeout complete:** implementation, independent
review, exact-source Frontend/executed Full and guarded Staging release pass
through PR430/`43f4a2b1`. The certified app is published through the separately
approved upload route; all nine live file hashes match. Both final actual PDFs
pass data/visual review across four pages; all 14 native Excel pages were also
reviewed. Two Schools match, all 22 detail deltas are zero, and the final document,
function/security and migration/role fingerprints match the baseline. The failed
checksum setting is restored exactly and the temporary Wrangler login is removed.
Automatic bootstrap recovery and resource-policy evidence remain unproven;
Recipe3529 requires the Owner/kitchen's factual decision.
See the [source-qualified closeout](../testing/journey-closeout-2026-10-21.md).
No automatic new business journey, Recipe substitution, Warehouse work,
OPSv1/Retool writes, dependency upgrade or speculative architecture change.

**21 October bounded cycle completed:** reviewed PR 426/main `484c34c3`, exact-main
Frontend/executed Full and guarded Staging deployment pass. Both original and
corrected 23 October hosted flows finish with 22 exact zero deltas, preserved
frozen contents and readable captured Unit names. Runtime observations and
remaining presentation/resource-policy work are recorded in the
[execution report](../testing/need-generation-unit-label-improvements-2026-10-21.md).
This is completion of the stated scope, not authorization for a new redesign.

**21 October bounded Need/Unit improvement:** execute the Owner-approved
[plan](../superpowers/plans/2026-10-21-need-generation-unit-label-improvements.md)
and current [active-task supersession](ACTIVE_TASK.md). Record runtime without an
arbitrary generation acceptance limit; retain all correctness, history and
security gates. Exact-source certification and guarded deployment precede one
fresh, labeled hosted Staging rehearsal including the correction/replacement
journey. Preserve existing released evidence, OPSv1/Retool NO-WRITE, synced
sources and all unrelated work; no real Supplier communication or physical dispatch.

**20 October functional stabilization supersession:** the Owner authorizes the [current campaign](../testing/atlas-functional-stabilization-2026-10-20.md) and its active bounded repair batches. This supersedes historical task sequencing and merge/deployment exclusions below only within this campaign. Preserve architecture/business/security contracts, all unrelated work, hosted business data read-only, disposable-only transactional tests and guarded exact-revision integration/deployment.

**19 October B2-only supersession:** the Owner explicitly authorizes the bounded
[optional Ingredient-code task](../implementation-tasks/TASK-ATLAS-B2-PO-INGREDIENT-CODE-OPTIONAL-01.md)
in its independent exact-base worktree. This replaces the inherited B1-only
baton for this branch. Preserve historical PO reproduction and all Supplier,
quantity, source and security requirements. Endpoint: one verified stacked Draft
and STOP for Owner review. No automatic next task, ancestor integration, benchmark
interference, hosted writes, real commitments, merge or deployment.

**18 October Product-model closeout:** the [active B1 amendment](../implementation-tasks/TASK-ATLAS-B1-PRODUCT-MODEL-CLOSEOUT.md)
on existing #402 supersedes older Pantry operator labels/COMPLETE instructions.
Only bounded source-read/presentation/coverage work is active. Historical
reconciliation is a separately reported gate; no hosted write, B2/C or promotion.

**18 October B1-only supersession:** The latest explicit Owner brief activates
the bounded Pantry two-source implementation under [ACTIVE_TASK.md](ACTIVE_TASK.md)
and its linked contract delta. Older UI-only/queued statements below remain
historical evidence; they do not override this B1 authorization. No B2/C, merge,
deployment, hosted write or next-task promotion is authorized.

Status: **School follow-up development/browser/source review PASS — exact-head normal CI pending**

**Current bounded activation:** Owner explicitly releases Task A `ATLAS-UI392-CI-REPAIR-01` in the current thread, even while recovery-policy #393 is Draft/unmerged. This exception does not merge/adopt that policy or activate Task B. [Active task](ACTIVE_TASK.md#product-priority-and-work-authorization) pins the six known seams, focused-first checks, two-attempt same-root stop and review/normal-CI gate. Preserve prior failed evidence. No #388 command/change/integration, Warehouse/parked Draft work, new business semantics, merge or deployment. Earlier blanket STOP applies outside this exact repair.

**Explicit School follow-up authorization — 16 October 2026:** The Owner now authorizes only decisive cost diagnosis/repair of the School dirty sign-out test and the proven mobile School Cancel focus fallback on the existing #392 branch from `50005ac8`. Previous failed strategies/evidence stay preserved; do not repeat the clean-Menu isolation. Preserve the entire journey/assertions and 5-second test budget. First measure exact lookup/change/rerender boundaries; add a failing focus regression before the smallest runtime focus repair. At most two fresh same-root repair attempts, then stop with evidence. Root browser and independent source review precede any push. PR #393 is still Draft/unmerged; this is a thread exception, not policy adoption. No Task B/#388 command or change, dependency/API/business change, merge/deployment, hosted write, Warehouse or parked-Draft work.

Original approval: 14 October 2026.  
**Product priority amendment: 16 October 2026.**  
Current execution horizon: **finish only the explicitly reauthorized School follow-up, then STOP**. The complete unchanged-5s journey now passes in 3,640 ms after measured query reuse/scoping and actual native dialog-exit observation; the mobile chooser focus regression also passes. The runtime delta is one focus-restoration call, with guards/owner lifecycle unchanged. Root confirms natural mobile/desktop Cancel and explicit discard/PXK retention. Prior failed strategies/evidence remain preserved. [Active handoff](ACTIVE_TASK.md#product-priority-and-work-authorization) records the source-qualified result and 44/44 affected-suite PASS and pending normal exact-head CI gate. No timeout change, full local certification, manual CI retry, Task B/#388 command/change/integration, merge or deployment. #393 remains Draft/unmerged; #385–#387/Warehouse stay parked, hosted Atlas read-only, OPSv1/Retool NO-WRITE.

The six standing Owner delivery rules are delivery/value first; bounded scope/acceptance/completion; mandatory failure stops and escalation; focused development checks separated from release certification; preservation of unfinished PRs/evidence; and explicit PASS/FAIL/BLOCKED with actionable handoffs. [The active task](ACTIVE_TASK.md#product-priority-and-work-authorization) defines current acceptance. One consolidated diagnosis/correction is allowed; if the same acceptance failure recurs twice, stop with root cause and actionable FAIL rather than indefinite retries. These are delivery rules, not replacements for the existing security/Product hard stops.

## Control plane

GitHub repository `longpsu-bot/thuonghao-ops-erp` is the shared handoff between OPS Product/Architecture and local Atlas implementation. **Do not rely on chat memory as task authority.** Read `docs/autopilot/ACTIVE_TASK.md` and the linked [Issue #389](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/389) first.

At this checkpoint the active loop is deliberately shortened:

```text
Owner design priority → verified checkout → skill/source audit
→ rendered alternatives (2–3) → independent visual critique
→ Owner selects a design → STOP until explicit selection
```

After Owner visual selection, normal bounded implementation / read-only audit / targeted CI / Product review / merge may resume. **No automatic unrelated task promotion or Staging deployment.** The four UI issues and bounded Need correction are explicitly authorized; they require no renewed design-selection ritual.

## Roles

OPS Product/Architecture selects product priorities and can approve bounded routine GitHub changes within the standing safety rules. The navigator/Terra role remains **read-only for implementation work**; the implementer/Sol/Codex owns bounded design prototype and code writes in its separately verified worktree. The independent visual reviewer must examine **rendered** evidence, not only source/style tests. If preferred names/models are unavailable, preserve role separation.

GitHub issue/PR comments do **not** by themselves launch Codex or interrupt an already-running local process. Do not claim automated execution without an actual connected runner confirmation.

## One staff member per operational task

`ONE_STAFF_PER_OPERATIONAL_TASK` remains in force. An authorized Actor can perform a normal operation with existing capabilities and exact scopes; don't add a generic second-person approval flow. Capability, relational scope, immutable evidence, audit and approved exception overrides remain mandatory. This design task makes **no** staff grants or permission changes.

## Hard Product stops (unchanged)

Stop before:

1. new/changed unresolved business policy;
2. paid or Production infrastructure;
3. first Production write-ownership transfer from OPS v1;
4. irreversible real supplier PO/PXK commitments;
5. destructive Production data correction;
6. material authorization broadening;
7. final Warehouse business design approval;
8. **production implementation of an unselected Atlas UI design.** Owner selected C; that selection gate is satisfied for the current bounded corrections, not unrelated design changes.

## Environment boundary

- Atlas Staging `rnzxmxiiqgtdevzregff`: **read-only for this active design phase**; prior approved bounded Staging processes remain historical evidence.
- OPS v1 Supabase `qnthofvccilhnefdcxnz`: hard NO-WRITE.
- Retool: continuity/workflow evidence; NO-WRITE.
- Atlas Production: not an approved target. No creation.

## Architecture

Use `OPS_SYSTEM_MAP v1.0` and **FACTS EXPLICIT — STATE DERIVED — SUPPORTING OBJECTS GENERATED**. PostgreSQL still owns authority for business facts, calculations, state derivation, currentness, concurrency, permissions, idempotency and released document history. Design skills cannot override business contracts. Chakra UI v3 remains the existing presentation foundation; typography, tab geometry, composition and information hierarchy are open to ambitious Product-directed redesign.

## Anti-overengineering rule

- Do **not** run further Warehouse contracts/migrations, broad performance studies, 8-cycle Need correction probes, repeated full-repo CI, extra autonomous agent loops, synthetic load programs or new architecture layers solely to “move Autopilot forward”.
- Do **not** merge/deploy Draft PRs #385–#388; preserve their state and existing evidence. #385–#387 remain parked; #388 alone has bounded remediation authority after stable UX.
- Read/use existing proofs instead of re-proving unchanged contracts. For **design-only** work, require real rendered comparison and focused checks—not a new certification infrastructure.
- Keep one active task in `ACTIVE_TASK.md` and a single explicit next Product decision. No automatic endless backlog execution; wait for Owner selection after D2.

## Active-task protocol

1. Read `AGENTS.md`, this file, `docs/autopilot/ACTIVE_TASK.md`, relevant approved contracts and the current `origin/main`.
2. Verify canonical workspace before implementation (`git rev-parse`, `git remote -v`, `git fetch origin`, `git status --short`, `pnpm ops:workspace`). Do not disturb dirty Codex checkouts.
3. Execute **only D1/D2**, create Draft artifacts for review, then stop for Owner selection.
4. Later task authorization requires an explicit update to this mandate/active baton, not extrapolation from an old roadmap.

</details>
