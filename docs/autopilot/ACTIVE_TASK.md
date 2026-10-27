# Atlas Autopilot — Active Task

## Current task — 27 October 2026

**Task:** ATLAS-PLANNING-CORE-DATA-20261027 — guarded Planning master convergence on Atlas Staging.

**Status:** Workflow implementation and review; apply only after merge and required CI.

**Owner authorization:** Complete the Atlas UI/data work, port only core School/effective Dish/Recipe data from OPS v1 without changing v1, omit daily operations, and **do not work on Warehouse yet**. The Owner then authorized the safest complete guarded Staging execution.

**Verified starting main:** `4acb1c60ba21b032e68d5a3d52589d006369919d`.

**Authorized checkout:** `E:/Project/OPS ERP/thuonghao-ops-erp`; clean, origin matches the real repository, HEAD equals fetched `origin/main`. The workspace script's older D-drive warning does not replace the explicit task-authorized checkout.

This is the sole active implementation task. The historical appendix preserves previous instructions/checkpoints, including failures; none is a current instruction to resume unrelated work. The [current mandate](ATLAS-AUTOPILOT.md#current-authority-and-execution-horizon) and AGENTS.md govern.

## Allowed scope and acceptance

Expected files:

- `.github/workflows/atlas-staging-master-data-load.yml`
- `scripts/atlas-staging-master-load-workflow.test.mjs`
- `docs/implementation-tasks/TASK-ATLAS-PLANNING-MASTER-RANGE-01.md`
- `docs/runbooks/master-data-rehearsal-import.md`
- `docs/architecture/roadmap.md`
- `docs/autopilot/ATLAS-AUTOPILOT.md`
- `docs/autopilot/ACTIVE_TASK.md`

Acceptance:

- Reuse the existing Planning catch-up runner; do not add a second importer or dependency.
- Keep preview read-only. Apply must require exact current `main`, exact Staging target, full migration parity, the immutable same-run snapshot and plan checksum, and the existing active migration Actor.
- Hard-bound the hosted apply to Dish legacy IDs `2065,2077,2078,2079,2080,2082,2083,2084,2085,2086,2087,2088,2089,2090,2091,2093,2094,2095,2097`; dependencies close mechanically under existing contracts.
- Require transactional apply, authoritative readback, identical replay and a read-only real Google Weekly Menu check. Upload only safe reports; delete the raw snapshot from runner temp on every outcome.
- Record merged, migration-deployed, data-previewed and data-applied states separately. Do not call core data applied until the hosted run succeeds and the artifact is inspected.
- Preserve the empty source Recipe for Dish `2065` as typed root evidence only; do not invent a Recipe version/BOM.
- Keep OPS v1 strictly read-only, exclude all daily operational data and keep Warehouse paused.
- Pass focused tests and formatting; publish one Draft PR and require normal CI/product review before merge.

No new schema migration, API/contract, dependency, lifecycle, calculation, permission/RLS, frontend release, daily operational copy, pilot, physical operation, OPS-v1/Retool write or Warehouse work is included. Security/business authority and released documents remain unchanged. Master apply has no destructive rollback: preserve receipts/UUIDs/history and use a separately reviewed forward correction if reconciliation later finds a factual error.

## Evidence at the 27 October execution checkpoint

| Layer                     | Recorded result and boundary                                                                                                                                                                                                                            |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Merged repository         | `4acb1c60`; #440 documentation reconciliation and #441 Menu-sync recovery are merged. Merge does not establish deployment.                                                                                                                              |
| Database migrations       | Atlas Staging run [40464516883](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/40464516883) passed and established full repository migration parity. This is a database-schema deployment, not a core-data apply or frontend deployment. |
| Bounded core-data preview | Run [40448618588](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/40448618588) passed with `apply=false` and zero writes; 19 Dish roots, their exact dependency closure and nine School-order updates were planned.                       |
| Broad full-load preview   | Run [40464654893](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/40464654893) failed safely with `STAGING_POSTGRES_EXECUTION_TIMED_OUT`; `apply=false`, so no master writes.                                                             |
| Core-data apply           | **NOT YET APPLIED** at this checkpoint. The workflow change must merge and CI pass first.                                                                                                                                                               |
| Separate UI Draft         | #442 at `a93e7e85`; Frontend CI passed. It remains Draft, unmerged and undeployed.                                                                                                                                                                      |

The [roadmap](../architecture/roadmap.md) carries the full queue/capability summary. The migration and preview workflow runs above are direct hosted evidence; they do not imply application publication or Production readiness.

## Next Product decision and stop condition

After the workflow PR passes review and CI, merge that PR, fetch the exact new main SHA and dispatch the Planning path with `planning_preview=true`, `apply=true`, `diagnostic_boundary=false` and target `rnzxmxiiqgtdevzregff`. Inspect the safe artifact for `APPLIED`, reconciled readback and `REPLAYED`, then dispatch a fresh `apply=false` post-apply preview. A changed plan, blocker, timeout/uncertain apply or non-`NO_CHANGE` replay stops the task.

**Warehouse: PAUSED by explicit Owner instruction.** No discovery, design revision, implementation, migrations, benchmarks or deployment; no automatic reactivation after handoff. The four Product groups remain undecided and unchanged.

Endpoint: core-data apply and replay succeed, Weekly Menu remains read-only with zero unresolved School/Dish identities, a post-apply preview is converged, and the final evidence explicitly distinguishes merge, migration deployment and data apply. No UI merge, frontend deployment, pilot, source correction or Warehouse work follows automatically.

The 26 October documentation-only task completed through #440. Its exact `c9641522` review evidence remains in that PR/Git history and is not relabeled by this active supersession.

## Historical active-task record — superseded execution instructions

The entire pre-update body is preserved below. Its “current”, “Task A”, “pending”, “next” and executable passages describe earlier authorizations only. Failures, screenshots/DOM limitations, revisions and migration observations remain qualified to those checkpoints. They do not override the 27 October task above.

<details>
<summary>Historical active-task body before the 26 October reconciliation</summary>

**22 October — bounded Supabase runtime closeout complete:** reviewed PR432 /
`db7bfe24`, exact-source and main Frontend/executed Full, guarded Staging deployment
and automatic app publication pass. Need now has its scoped completion policy;
ordinary authenticated requests regain the existing eight-second default and
lock protection is retained. The actual 20 October original → correction →
reallocation → replacement PO → successor dispatch journey passes: two Schools,
21 exact zero deltas, 23 completed receipts and 631 assertions. Both actual PDFs
pass data/visual review across four pages. All 7,205 pre-existing history rows
and all frozen original document contents are preserved. Need records 4.419 s
database / 4.451 s upstream / 4.620 s origin, without a duration acceptance gate
or speedup claim. Chrome resource inspection is source-qualified; historic
metrics and two dashboard tiles remain unavailable. See the
[investigation and closeout](../testing/supabase-runtime-timeouts-2026-10-22.md).
No automatic new journey or speculative capacity/query change. OPSv1/Retool remain
read-only; Recipe3529 remains an Owner/kitchen factual decision.

**22 October closeout complete:** Need/Unit improvements and the full hosted
original/correction/replacement journey pass. Reviewed Attendance, PO-impact and
export repairs are merged through PR428–430. Exact-source Frontend/executed Full,
main Frontend and guarded Staging deployment pass. Certified `43f4a2b1` is live
through an explicitly approved upload to the existing app; all nine live file
hashes match. Both actual successor PDFs pass data/visual review across four
pages. Both Schools match and all 22 detail deltas are zero. The final 989-row
document and 493-function/security/migration fingerprint matches the baseline.
The failed checksum-setting experiment is restored exactly; the separately
approved temporary Wrangler login is removed and reports unauthenticated.
The [closeout report](../testing/journey-closeout-2026-10-21.md) retains runtime
variation, failed attempts and the automatic-bootstrap/resource-policy limits.
Recipe3529 still needs a factual Owner/kitchen decision. No new business writes,
Recipe substitution, OPSv1/Retool writes or architecture expansion in closeout.

**21 October completion:** PR 426 is merged as `484c34c3`; exact-main Frontend
and executed Full Integration pass; guarded deployment `39591313934` passes with
133 migrations. The fresh 23 October hosted original → correction → reallocation
→ replacement PO → successor dispatch journey passes for both Schools, all 22
detail deltas zero. Need completes on its first attempt at 4.094 s upstream /
4.270 s origin; no arbitrary latency gate or hosted percentage claim. Captured
Hũ/Quả/Cái labels are visible. All 638 history/lineage and 117 export-data checks
pass. See [evidence and remaining work](../testing/need-generation-unit-label-improvements-2026-10-21.md)
for presentation minors, an unverified PO impact-loading observation, Recipe3529
and the disclosed prior Staging timeout0 lease. No hosted setting change,
OPSv1/Retool write, real Supplier message or physical shipment.

**21 October Need runtime / Unit-label authorization:** the Owner approved and
requested execution of [the bounded improvement plan](../superpowers/plans/2026-10-21-need-generation-unit-label-improvements.md)
in the verified canonical `E:/Project/OPS ERP/thuonghao-ops-erp` checkout. This
supersedes older checkout, hosted read-only and generation speed-target horizons
for this task. Observe runtime without an arbitrary acceptance limit; preserve
all semantic, security and history checks. Independent review, exact-source CI,
merge and guarded Staging deployment precede one fresh, clearly labeled hosted
rehearsal including correction, reallocation and replacement PO/PXKs. Existing
21 October released evidence is preserved. OPSv1/Retool and synced sources stay
read-only; no real Supplier communication, physical dispatch, Warehouse work,
dependency upgrade or speculative redesign is authorized.

**20 October functional stabilization supersession:** the Owner explicitly authorizes the autonomous campaign recorded in [the stabilization ledger](../testing/atlas-functional-stabilization-2026-10-20.md), using the confirmed D: checkout and fresh latest-main repair branches. Prior task-only horizons below are historical. Bounded fixes may proceed through independent review, exact-revision checks, merge and guarded Staging deployment; hosted business data remains read-only and transactional journeys run only in disposable environments. ARCH-002, existing business/security contracts, OPS v1/Retool NO-WRITE and unapproved-module exclusions remain in force.

**19 October B2 authorization (this independent stacked Draft only):** execute
`ATLAS-B2-PO-INGREDIENT-CODE-OPTIONAL-01` from exact `689398e12f3911182862c76a964434c8776b6bec`
on `feat/atlas-b2-po-ingredient-code-optional`, targeting
`fix/atlas-ci-auth-01-test-boundary`. The explicit Owner brief supersedes older
B1-only restrictions for this task. Follow the [contract delta](../implementation-tasks/TASK-ATLAS-B2-PO-INGREDIENT-CODE-OPTIONAL-01.md).
Preserve #392/#401/#402/#404 and immutable historical PO reproduction. Run
focused tests and exact-head Frontend/Smoke/actually executed Full Integration.
No benchmark interference, automatic rebase, merge, deployment, hosted mutation,
real supplier commitment, C, Dispatch or Warehouse work. Stop for Product review.

**18 October Product-model closeout:** continue existing #402 from `7f1343a`
under the [latest Owner-approved bounded contract](../implementation-tasks/TASK-ATLAS-B1-PRODUCT-MODEL-CLOSEOUT.md).
This amends current Pantry labels, source disclosure and coverage evidence only.
Preserve historical COMPLETE; report current scopes requiring reconciliation.
No B2/C, hosted mutation, merge, deployment or automatic next task.

**18 October B1 authorization supersession (this stacked Draft only):** The Owner
explicitly authorizes `ATLAS-B1-PANTRY-TWO-SOURCE` from verified #401 head
`4419033c2e4637fefb651d4ba395f4993a4e3599`, targeting its existing branch. Execute
only the [B1 contract delta and plan](../implementation-tasks/TASK-ATLAS-B1-PANTRY-TWO-SOURCE.md).
Earlier queued/UI-only restrictions below are historical for this bounded task.
Preserve #392/#401 and all historical evidence; no B2/C, merge, deployment, hosted
write, Warehouse work or automatic next task. Stop for Product review.

Task: **ATLAS-UI392-CI-REPAIR-01 — Task A only**

Status: **School follow-up development/browser/source review PASS — exact-head normal CI pending**

Product authorization: **16 October 2026** — Owner explicitly redirected priority from overextended Autopilot/backend work to Atlas UX/UI design.  
Source: [approved GitHub Issue #389](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/389) and [execution brief](../implementation-tasks/TASK-ATLAS-UX-ART-DIRECTION-02.md).  
Starting main at transition: `d102b2f1b083005d6553867fa5ccdf8c988a0316`. Re-read current `origin/main` before task execution.

**Explicit School follow-up authorization — 16 October 2026:** The Owner now authorizes only decisive cost diagnosis/repair of the School dirty sign-out test and the proven mobile School Cancel focus fallback on the existing #392 branch from `50005ac8`. Previous failed strategies/evidence stay preserved; do not repeat the clean-Menu isolation. Preserve the entire journey/assertions and 5-second test budget. First measure exact lookup/change/rerender boundaries; add a failing focus regression before the smallest runtime focus repair. At most two fresh same-root repair attempts, then stop with evidence. Root browser and independent source review precede any push. PR #393 is still Draft/unmerged; this is a thread exception, not policy adoption. No Task B/#388 command or change, dependency/API/business change, merge/deployment, hosted write, Warehouse or parked-Draft work.

## Product priority and work authorization

**Task A activation exception — 16 October 2026:** The Owner explicitly authorizes `ATLAS-UI392-CI-REPAIR-01` in this thread on the existing PR #392 branch, despite recovery-policy PR #393 (`dd6ca59f`) remaining Draft/unmerged. This is a bounded thread exception, not a claim that the policy was merged/adopted into main and not permission to merge/cherry-pick the whole plan. Read-only source: `origin/docs/atlas-autopilot-tiered-recovery-20261016:docs/autopilot/ATLAS-RECOVERY-392-388-2026-10-16.md`. Verified start `0880db42`, main `3667966a`, canonical user-authorized E: checkout; preserve all prior failures.

Scope: reproduce/repair the pnpm registry oracle, exact Ingredient owner/status identity, School dirty sign-out/Close timing, Need→Allocation navigation/date/no-hidden-Save, prior PXK Cancel focus, and the authoritative Pantry fixture UUID so all 38 assertions run. Classify test-source, async/environment and proven runtime defects separately. Use focused tests first and deterministic observable state/events; no timeout increase, skip/xfail, dependency/framework, new migration or business/permission change. At most two bounded attempts for the same root failure, then STOP with minimal reproduction/decision. One consolidated source/evidence review, Root browser1366/390 and Terra review precede one coherent push/normal exact-head CI. No local full certification loop.

Task B/#388 is NOT active: preserve exact `11cda965` and its runtime/evidence without commands, changes or integration. #385–#387/Warehouse remain parked; hosted Atlas read-only and OPSv1/Retool NO-WRITE. No merge/deployment. The historical STOP checkpoint below remains evidence; only this named Task A repair is superseded by explicit Owner authorization.

**16 October — bounded delivery supersession:** Owner explicitly authorizes resolution of the [four recorded UI issues](../ui/atlas-owner-review-issues-2026-10-16.md) in PR #392, followed by bounded remediation of the approved Need correction in Draft #388 after UX is stable. This supersedes the earlier recording-only status and broad Need-remediation pause, not the remaining safety stops. Keep #388 Draft and its unfinished work/evidence; #385–#387 remain parked. Warehouse stays paused, hosted Atlas access remains read-only, and OPSv1/Retool remain NO-WRITE. No merge or deployment.

**Current School follow-up checkpoint:** the complete dirty-signout/Cancel/Discard/signout journey passes in **3,640 ms** under its unchanged 5-second limit. Reuse the already-observed School fields, scope exact controls with explicit visibility assertions, and complete only the genuinely closed dialog's native exit before asserting actual removal. No initial owner, business assertion or guard is removed. The one-line runtime correction restores the persistent narrow chooser before invoking the existing owner Close callback. A new regression fails before/passes after that change; Root's natural-exit browser checks confirm mobile chooser focus, desktop Close focus, retained draft and independent PXK preservation on explicit School discard. The nearest App/Shell suite passes all 44 tests; TypeScript and UI boundary pass. Normal exact-head CI remains the integration gate; no readiness claim yet.

**Previous checkpoint at `50005ac8`: PARTIAL / BLOCKED.** Its two failed strategies, original School block and all logs remain preserved in the [historical classification](../ui/atlas-ux-review-2026-10-16.md#task-a-partial-repair--school-blocked). The new authorization above supersedes only that School stop. Precise phase measurements establish cumulative query/visibility and exit work, not an application hang or a single 2.8-second rerender. Browser screenshot capture remains unavailable; the new checks are DOM interaction evidence, not screenshot or all-state certification. Previous Pantry38 and six passing cases remain qualified to their earlier source image.

Publish one reviewed School-only checkpoint to existing Draft #392 after the affected suite/static checks. Observe normal exact-head CI; no manual rerun, automatic promotion, full local certification or further strategy. Operational 8s/20s/1s and disclosed nested 5s limits are untouched. PR #393 remains Draft/unmerged. #388 `11cda965`, Task B, #385–#387 and Warehouse remain inactive/preserved. No merge/deploy.

Standing Owner delivery rules:

1. Prioritize delivery, operational readiness and measurable business value over endless optimization.
2. Define scope, acceptance criteria and completion conditions for every bounded task.
3. Stop repeated failures for root-cause analysis/escalation; no indefinite retry loop.
4. Separate development from certification: fast focused checks during implementation, full certification at the appropriate release gate.
5. Preserve unfinished PRs and evidence without merging, deploying or discarding them.
6. Report explicit PASS/FAIL/BLOCKED outcomes and actionable handoffs.

**Current UI acceptance:** actual fresh-login/default preview selects Weekly Menu; meaningful supported column headers replace the four standalone sorting selectors while preserving comparators/exact values/keyboard access/`aria-sort`; Pantry purpose removal and optional notes work across validation/Save under an explicit minimal compatibility amendment reviewed before SQL changes, retaining historical purpose/evidence; Confirmed Need summary/count/filter/actions form one compact aligned toolbar at 1344/1366 and 390 with all actions/scopes/guards retained. Use existing components and no new dependencies. Completion requires one consolidated diagnosis/correction, focused/static checks, independent review, browser evidence and normal exact-head CI. If the same acceptance failure recurs twice, stop with root cause and actionable FAIL rather than starting another cycle. Need correction then follows its approved design and a bounded remediation scope; this is not authority for general backend, certification or Warehouse work.

**16 October — ERP-density course correction, same PR #392:** Owner explicitly prioritizes the compact OPSv1-like workbench pattern. Restore visible desktop columns/dense rows and catalogue-primary/task-sized detail geometry for the five recent lists; keep mobile stacking, 44px targets, Recipe chooser exception, C tabs and PO document workplane. Slim the existing labelled sort control without changing axes/comparators. No controller/model/API/backend/Warehouse changes or parked Draft integration.

**16 October — Recipes, Adjustments and compact sort controls, same PR #392:** Owner authorizes the next C presentation batch. Preserve the existing recipe chooser, all quantities/Units/notes, effective composition, immutable Adjustment history, permissions, frozen Review and explicit Save. Replace standalone sort groups in Schools, Suppliers, Ingredients and Allocation with one labelled framed control using existing axes and ordering. No controller/model/API/schema/dependency changes; backend/Warehouse and #385–#388 remain parked.

**16 October — Ingredients and Supplier Allocation, same PR #392:** Owner explicitly authorizes the next compact C catalogue/family-directory and broad existing-editor batch, including mobile sort reachability and unchanged exact quantity/recipient evidence. Preserve separate recommendation/rebalance Apply and explicit Save, lifecycle/priority Review, selection/focus, dirty and UNKNOWN locks. No controller/model/API/SQL/dependency changes or #387 integration. Backend/Warehouse and #385–#388 remain parked. Track final exact-head normal CI to completion.

**16 October — next bounded UI batch, same PR #392:** Owner authorizes Schools/default attendance and Supplier catalog/detail to adopt compact C composition at laptop and narrow widths, plus short PO/PXK export button labels with adjacent scope explanation. Preserve all identities, ordering, commands, permissions, drafts, recovery and export arrays; no controllers, API, schema, dependencies or Warehouse changes. Other owners remain outside this batch. Correct the reproduced App range-read test race without weakening its retained-range assertions.

**16 October follow-up — same unmerged PR #392:** Owner requested explicit PO XLSX/PDF exports and a wider UI review. Bounded corrections include real PDF ZIP production, Supplier Close focus, unknown initial Procurement data versus successful empty data, the sloped-tab CI oracle, and current v3 UI-agent guidance. [Review and remaining work](../ui/atlas-ux-review-2026-10-16.md). This does not complete all workbench redesigns or resume parked backend/Warehouse work.

**16 October 2026 — Owner selected C and explicitly authorized implementation.** The D1/D2 selection gate is satisfied by [Draft #391](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/391), head `6ac8f388ce14bc991058371e1232b094e733f6b3`. Implement only connected sloped tabs and supplier-rail PO presentation under the [bounded C scope](../ui/atlas-c-workspace-po-implementation.md). Preserve real thirteen-owner state, API clients, business guards, immutable documents and export semantics. Backend/Warehouse and #385–#388 remain parked. No merge or deployment is authorized.

**Stop creating additional backend performance/certification, Warehouse, or general cutover work merely to advance Autopilot.** Concentrate on making Atlas genuinely legible, efficient, aesthetically polished and practical for staff. This transition **supersedes Issue #389's older “wait until all #385–#388 are closed” start condition**: the design phase may proceed NOW while those existing Drafts are preserved. It does **not** approve their merges, alter their source code, or claim their business behavior is deployed.

Authoritative business and security boundaries remain unchanged: `OPS_SYSTEM_MAP v1.0`, **FACTS EXPLICIT — STATE DERIVED — SUPPORTING OBJECTS GENERATED**, Chakra UI v3, thirteen persistent workbench owners, current Planning/Procurement contracts and immutable released documents.

### Current parallel work — PARKED, not discarded

- [#385](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/385): login/PO states/XLSX wrapping, Draft, review/integration later.
- [#386](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/386): human Unit labels and draft School evidence, Draft, migration not deployed.
- [#387](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/387): bulk supplier allocation, Draft, migration not deployed.
- [#388](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/388): post-release Need correction, **INCOMPLETE Draft** with genuine 250-family multi-cycle performance failure. No forced success, CI weakening, merge or Staging deployment. Bounded remediation after stable UX is now authorized by the delivery supersession above; preserve the Draft and prior evidence.
- Older UI prototype Drafts remain archival references, not automatic implementation candidates.

Do not reset/delete local worktrees, commits, stashes, branches or PRs. Before any integration of these branches, independently assess compatibility and exact-head tests. **Do not wait for them to merge before producing design alternatives.**

## Completed discovery: two design deliverables

### Checkpoint D1 — skills, genuine current UI review, and design diagnosis

1. Verify the canonical local checkout in accordance with `AGENTS.md` (remote, clean worktree, current main, `pnpm ops:workspace`). If no authenticated local Codex/desktop runner is available, stop at GitHub handoff; do not claim that local implementation began.
2. Inspect the current Chakra application source and rendered populated workbenches, especially `src/vnext/atlas/AtlasVNextShell.tsx`, `src/vnext/atlas/procurement/ProcurementOrdersStage.tsx` and Procurement Allocation, plus existing UI agents and `.agents/skills`.
3. Audit external design skills by reviewing source/license/scripts/security. Prefer Anthropic Frontend Design, Emil Design Engineering, Impeccable and Vercel Web Design Guidelines as distinct creative/finishing/review inputs. Anthropic Design Plugin is **Claude-only optional**, not a directly installed Codex feature. Never blindly execute install commands, add paid services or unreviewed dependencies. Record what is and is not actually available.
4. Identify real shortcomings in visual hierarchy, dense layout, control alignment, crowded PO table, supplier detail, tab identity, weak visual rhythm and laptop viewport ergonomics. OPS v1 Retool is workflow vocabulary evidence only.
5. Produce a concise design diagnosis and skill provenance. **No Supabase, Retool, hosted data, API, RLS, migrations, business logic or production UI mutation.**

### Checkpoint D2 — visible, competing designs

Create **2–3 materially different rendered, comparable prototypes** for:

- The **connected angled/sloped-edge tab strip** inspired by the Owner's reference; active tab seamlessly joined to the white workplane, neutral inactive tabs, 13-workbench horizontal overflow, close/dirty/focus semantics retained.
- **Supplier-first PO workbench:** compact scannable orders, truthful draft/released/export state, document numbers and next action; disclose long School breakdown, exact quantities/Units and notes in usable detail rather than concatenated cells.
- Optionally show how the same design language improves Supplier Allocation while preserving the already-implemented backend supplier recommendation/explicit Save distinction.

Demonstrate populated Vietnamese operational examples and important states at **1366×768** first, then 1440, 1920, 768 and 390 widths where relevant. Provide screenshots/contact sheet and concise trade-offs. The alternatives should be genuinely different designs rather than trivial recolors.

**Selection gate satisfied:** Owner selected C on 16 October 2026. Only the bounded presentation implementation recorded above is authorized; no other design alternative, backend horizon or Warehouse work is opened.

## Do not overbuild or over-certify

- One bounded design task; no Warehouse, backend, supplier commitments or unrelated cleanup.
- No repetitive multi-agent audit loops, new “proof infrastructure”, synthetic 50-School database pipelines, redundant Full CI runs or new business state machinery during D1/D2.
- Use existing fixtures and read-only evidence. A focused lint/format or static/preview smoke check is enough for a docs/prototype-only Draft.
- Independent design critique should identify **visual defects**, not just repeat typecheck status. Involve visual designer before implementation.
- Deliver one coherent Draft PR or evidence package for D1/D2, not numerous nested PRs. Do not merge a visual direction before Owner selection.

## Current environment and the parked previous task

Atlas Staging: `rnzxmxiiqgtdevzregff` — **read-only during this design task**, accepted migration 109.  
OPS v1 Supabase: `qnthofvccilhnefdcxnz` — NO WRITES. Retool: NO WRITES.  
Warehouse minimum receiving design [PR #384](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/384) merged 14 October; its [proposed design](../architecture/warehouse-receiving-minimum-design.md) and [proposed decision](../decisions/decision-atlas-warehouse-receiving-minimum.md) remain **UNAPPROVED FOR IMPLEMENTATION**. Preserve its four unresolved Product groups; it is not the current active task.

The historical 14 October Warehouse baton is preserved by Git history. This change updates only sequencing; it does not retroactively change that work's acceptance evidence.

## Required handoff

Return exact current baseline, verified canonical workspace, skill-source/provenance results, 2–3 visual directions, populated screenshots, top critical UX defects, conflicts/unknowns and a **STOP — AWAIT OWNER VISUAL SELECTION** verdict. Do not autonomously continue into a runtime implementation or another task.

</details>
