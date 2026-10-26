# Atlas Autopilot Mandate

**Current checkpoint:** 26 October 2026 (Asia/Bangkok).

**Status:** ACTIVE — documentation reconciliation only; STOP at review handoff.

**Owner instruction:** Update the roadmap and Autopilot documents to reflect current state and next priorities, preserve historical evidence, separate merged from deployed work, and **do not work on Warehouse yet**.

## Current authority and execution horizon

This checkpoint and [ACTIVE_TASK.md](ACTIVE_TASK.md#current-task--26-october-2026) replace the older sequencing, pending-CI statuses and executable instructions in the historical appendix below. The appendix preserves what was authorized/observed at each dated checkpoint; its wording is not current authorization. Approved business/security contracts and explicit Owner hard stops remain in force.

The only active task is **ATLAS-ROADMAP-AUTOPILOT-20261026**: update these three Markdown documents from repository/GitHub evidence, validate the bounded diff, publish a documentation review PR and STOP. Do not implement, merge or deploy #438/#439, apply #437's migration, start a pilot, replay a journey, repair source data or resume an older Draft under this task.

## Current baseline and evidence boundaries

- **Merged repository:** reviewed `origin/main` is `c9641522721430def56eea96750c364cdc06584a`. Backend convergence 02B/02C/02D (#357/#359/#361), thirteen-owner workspace (#358), operational document system (#360), later Planning/Procurement corrections and scoped Need runtime policy (#432) are merged. UI changes #434–#436 and optional weekly additions #437 are also merged; merge does not establish deployment.
- **Last recorded deployed/accepted Staging:** `db7bfe24`, target `rnzxmxiiqgtdevzregff`, 22 October, 134 migrations/tip `20261022071412`; guarded deployment and automatic app publication passed. The original/correction/reallocation/replacement-PO/successor-dispatch journey passed for two Schools, 21 zero detail deltas, 631 assertions and both actual PDFs over four pages. All 7,205 pre-existing history rows and frozen originals were preserved. Source: [runtime closeout](../testing/supabase-runtime-timeouts-2026-10-22.md). This is dated evidence, not a fresh live inspection or Production acceptance.
- **Merged but deployment not evidenced here:** #434–#437. [#437](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/437) passed final-source Frontend/executed Full; its record excludes hosted migration application/deployment. Later main is not assumed live.
- **Open Draft review queue:** [#438](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/438), head `baef3078`, [Frontend PASS 40205644208](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/40205644208); [#439](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/439), head `d7802b22`, [Frontend PASS 40244573064](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/40244573064). Both remain unmerged as verified 26 October; Product acceptance/integration are distinct from CI. No deployment evidence is supplied for either Draft.

The [roadmap](../architecture/roadmap.md) carries the capability summary and source links. Existing 21 October/22 October acceptance records remain separate; historical stress FAIL/BLOCKED evidence is not relabeled PASS.

## Next priorities and single next Product decision

**Next Product decision:** accept or request bounded revisions to #438/#439. This records the review queue, not authorization to change or integrate those branches.

After separate authorization: establish one accepted combined release and exact Staging/app parity with rollback; prepare a bounded staff pilot of the existing Planning–Procurement workflow; resolve Recipe3529's factual Owner/kitchen decision and explicit cutover requirements. The approximately 5–10 working-day pilot is an earlier proposal, not a scheduled activity. No production transfer is approved here.

**Warehouse remains PAUSED.** Do not start discovery, revise design/contracts, implement, migrate, benchmark or deploy Warehouse. Preserve its existing four unresolved Product groups unchanged. Neither backend certification nor this priority list reactivates Warehouse. Explicit Owner reactivation and existing approval gates are required.

## Standing safety and delivery rules

- Preserve ARCH-002 / OPS_SYSTEM_MAP v1.0 and **FACTS EXPLICIT → STATE DERIVED → SUPPORTING OBJECTS GENERATED**. PostgreSQL owns authoritative facts, calculations, currentness, permissions, concurrency, idempotency and released history. React/Chakra remains the interaction/presentation layer.
- One authorized staff Actor can perform an ordinary task with existing capabilities/scopes and audit. Do not add generic second-person approval or broaden grants.
- Keep one bounded active task, acceptance criteria and stop condition. Use focused development checks; GitHub Actions owns full routine frontend validation. Do not weaken tests or repeat successful full certification merely to restate evidence. Repeated same-root acceptance failures require diagnosis/escalation.
- Preserve unfinished PRs, branches, worktrees and failed evidence. #385–#388/#396 and older prototypes are not automatic merge candidates; assess already-merged replacements and compatibility before separately authorized disposition. Do not restart old stress/optimization loops.
- Navigator/reviewer remains read-only; implementer changes only the active bounded scope. PR comments are evidence, not proof that a runner started or a new task is authorized.
- Stop before unresolved business-policy changes, paid/Production infrastructure, Production write-ownership transfer, real supplier commitments, destructive Production correction, material authorization broadening, unapproved Warehouse work or implementation of an unselected UI design.
- Hosted Atlas is read-only for this task. OPS v1 `qnthofvccilhnefdcxnz` and Retool remain NO-WRITE; Atlas Production is not an approved target. No business data, supplier messages, physical shipments or security changes.

## Current task protocol and handoff

Verify the user-authorized checkout/current main under AGENTS.md. Edit only `docs/architecture/roadmap.md`, this file and `docs/autopilot/ACTIVE_TASK.md`. Check formatting, local links, whitespace, historical retention and status consistency; push the bounded documentation branch and let normal PR CI run. Report the PR, exact source, validation and unverified deployment boundary. **STOP — await Owner review; no automatic next task.**

## Historical checkpoints — superseded execution instructions

The complete pre-update mandate body is retained below. Dates, source revisions, failures and restrictions remain evidence at their original checkpoint. Statements such as “current”, “execute”, “pending” and “next” inside this appendix do not override the 26 October scope above.

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
