# ATLAS-C-K3-OPERATOR-INTEGRATION-01

Status: **BLOCKED — primary 100 → 110 → 90 connected journey PASS; shared-School/two-Supplier PO/PXK reads exceed the unchanged 8s budget. Owner scope decision required. No activation approval.**

Publication checkpoint: the Owner subsequently requested **“Please push”**. The current implementation is committed and pushed as a work-in-progress checkpoint under that instruction. The execution, connected-browser and exact-head CI gates below remain incomplete; this publication does not establish acceptance or readiness. No K3 Draft PR is created at this checkpoint.

Authority: [Owner read-contract amendment, 20 October 2026](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/400#issuecomment-6277838544), [K2 Product review](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/409#issuecomment-6265983563), ARCH-002 and the original K3 operator integration brief.

Continuation authority: [Owner Procurement read amendment, 20 October 2026](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/400#issuecomment-6279713889). This supersedes the historical STOP below only for the existing Allocation read and, if needed, Preparation advisory. The Owner explicitly directs preservation and continuation of the existing uncommitted tree.

Pinned parent: Draft #409, `8adc0803a450192931ece3192642051ca05cc5e2`.
Task branch: `feat/atlas-c-k3-operator-integration-01`.
Verified authorized checkout: `D:/Project/Repo/OPS/thuonghao-ops-erp`.
The starting tree was clean; all six pre-existing stashes and other worktrees are preserved.
The Owner explicitly authorizes this parent instead of `origin/main` and supersedes the historical B2 Autopilot baton for this task only.

## 20 October continuation on the confirmed E: checkout

The Owner confirmed `E:/Project/OPS ERP/thuonghao-ops-erp` after multiple checkouts
were found. The real repository, origin, clean tree and workspace check were
verified; the existing remote K3 branch was recovered at exactly
`6eeb4c62281c3f5adb07f112e1a1b5bebae0f530`. No K2 work was recreated. The old
six stashes and old-machine screenshot/log paths below were not recovered or
represented as new evidence. The workspace checker's old D: path warning is
historical; the Owner explicitly selected this E: checkout.

Fresh evidence lives at
`C:/Users/HOME/.codex/visualizations/2026/10/20/01a15714-e483-7401-b5b2-3d22a62c27bc/k3-continuation/`.
Its runtime references this checkout's migrations/functions through junctions;
it is not another source checkout. New `atlas-k3-local-01` containers/volumes and
ports 56321/56322 were absent/free before provisioning. Only that disposable
project was initialized. The existing `thuonghao-ops-erp` stack was untouched.
Node 24.18.0 and pnpm 11.25.0 satisfy the pinned major versions; the repository CLI
is Supabase 2.111.0 (the unrelated global 2.75.0 CLI was not used).

### CI baseline and bounded corrections

Both manual workflows ran at the exact recovered SHA, attempt 1:

- [Frontend CI 39358400901](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/39358400901)
  **FAIL**: the existing business-only bridge imported `confirmedNeedCorrection`
  without its exact module entry in the UI-boundary checker. Focused RED reproduced
  the missing entry; the minimal allowlist change and bridge-only regression pass
  **47/47**. Direct legacy-view imports remain forbidden.
- [Supabase Integration 39358404879](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/39358404879)
  **Smoke FAIL; Full Integration FAIL; both actually executed**. Both stopped at
  ordinary Purchase Review assertion 29: K3 had replaced the retained incomplete
  Need guidance with the generic corrected-source blocker. The same local RED was
  reproduced. Forward migration `20261020022939_atlas_k3_ordinary_allocation_blocker.sql`
  restores only ordinary wording, retaining corrected-source guidance. No existing
  migration, writer, privilege, policy or timeout was changed.

The expanded K2 execution first stopped because pgTAP could not infer the type of
two unknown literals captured with `\gset`. Explicit text casts preserve the exact
assertions. Its next run exposed an incorrect new count expectation: the B1 fixture
authors five families (Ingredients 2001–2004 and 2016), not two. Independent source
review and a rolled-back diagnostic verified all five exact date/location/Unit
keys. The assertion now requires that exact set. K1's unsupported-source corruption
is rejected by the retained integrity guard with SQLSTATE `23514` before a read;
the test requires that exact result, while missing/invalid Handoff cases still
require actual authenticated blocked reads. D037's declared plan is corrected from
37 to 39 for its two already-added K3 assertions. No assertion was skipped or
timeout raised. Earlier failed logs remain alongside the GREEN logs.

Fresh focused SQL GREEN: Purchase Review **193**, K2 mixed-source **125**, K1
correction/eligibility **125**, receipts **50**, security catalog **30**, D037 **39**
(**562 assertions**). Format and typecheck pass. A first local Vitest attempt found
an archived `.superpowers` source copy and timed out before assertions; the bounded
canonical-source invocation excludes local scratch copies and uses one worker.
This is not a repository/CI exclusion. A fresh independent read-only whole-change
and focused read/security review found no actionable correctness/security issue.
Full local frontend/PostgreSQL certification was not repeated.

### Fresh connected primary journey — PASS

Real Chrome at 1366×768 and 390×844 used actual authenticated loopback requests.
All business responses came from the disposable backend. The original issued
Need was 100 kg rice plus unchanged 3 kg beans. A reason was required before
review; Cancel received initial review focus. The reason and quantity survived a
tab switch. Reason-only dirty close required explicit continuation/discard.

| Document | Backend number | Rice | Predecessor | Final state |
| --- | --- | --- | --- | --- |
| PO-001 | `PO-20261102-1720C7322722417B` | 100 kg | none | SUPERSEDED |
| PO-002 | `PO-20261102-8F3DE618CC494D9B` | 110 kg | PO-001 | SUPERSEDED |
| PO-003 | `PO-20261102-4697749D2BC045D1` | 90 kg | PO-002 | RELEASED_TO_SUPPLIER |

Each complete document also retains beans 3 kg. The browser explicitly accepted
the affected Supplier allocation, ran successful Preparation, created the complete
replacement Draft and separately released each new numbered PO. Beans remained
`BALANCED` under the exact original `PURCHASE_HANDOFF` fingerprint/contributors;
corrected rice used authentic `CONFIRMED_NEED`. The 90 kg proposal made prior
110 kg acceptance stale and Preparation not ready until explicit reacceptance.

The 90 kg correction committed successfully and then its real HTTP response was
deliberately dropped. The UI locked, disabled further writes and required a fresh
read. Recovery returned authoritative 110 → 90 / −20 with genuine predecessor
revision/decision IDs without resending. A later explicit exact-receipt probe
returned the identical stored result; changed-payload reuse returned
`IDEMPOTENCY_CONFLICT`, and a new stale request returned
`STALE_CONFIRMED_NEED_BATCH`. An initial diagnostic incorrectly double-wrapped the
RPC envelope and received `VALIDATION_FAILED`; that attempt is retained separately,
not counted as stale/replay proof. A distinct synthetic Actor with its fixture
membership revoked authenticated successfully but received `CAPABILITY_DENIED`
for review/Save and `AUTH_SUBJECT_MISMATCH` for another Actor's request. Full reload
retained authentication and fresh 90 kg history. Mobile root overflow was zero.

PO-001/002/003 were exported as actual XLSX/PDF files. Re-exporting PO-001 and
PO-002 after replacement preserves all business cells and `ROW_SOURCE` content.
Only `_ATLAS_META!E3` DOCUMENT metadata changes its live root `status` and
`replaced_by_purchase_order_id`, as required by the existing
[metadata contract](../api/operational-document-xlsx-metadata.md). Raw ZIP contents
and files are therefore **not** claimed identical; no exporter semantics changed.
The original PXK `PXK-20261102-BA0B42587D0440E3` retains its exact original release,
100/3 quantities and source history. The read truthfully requires a separately
authorized successor; none was created or released. The two unrelated B1 Supplier
documents remained issued at version 2 with no successors throughout this primary
journey, before the separately recorded B1 test below began.

Key artifacts: `browser-rpc.jsonl`, `unknown-90-actual-command.json`,
`browser-stale-replay.json`, `distinct-actor-denials.json`,
`historical-export-cell-differences.json`, `pxk-final.json`,
`browser-final-summary.json`, screenshots `01-` through `20-`, and the downloaded
PO/PXK exports. These are new local evidence; none of the old-machine evidence was
re-executed by implication.

### Required B1 connected case — BLOCKED, exact next decision

The second connected browser used the synthetic B1 Actor on 19 September 2050:
School A's actual R20+B5+H3 28 kg was corrected to 30; School B's 20 kg remained
unchanged. The five-family read correctly retained four untouched Handoff families.
Explicit Supplier splits 32/18 accepted the shared 50 kg family; Preparation
succeeded. The first complete Supplier A replacement Draft was created. The next
PO shaped read failed with PostgreSQL `57014` at the unchanged 8s public limit;
the PXK impact read also timed out. The UI blocked continuation. Supplier B's
replacement was not created, and **neither B1 replacement was released**.

The exact captured `get_school_catering_purchase_orders` request was reproduced
under `authenticated` in a rolled-back SQL session with the same 8s limit:
**8251 ms, statement timeout**. The trace reaches the unchanged PO read wrapper →
commitment state → Draft currentness → canonical family proof → live Planning
preflight → effective composition / `rmvp_02b_resolve_selected_composition`.
Memory at the failure measurement: total **15.83 GiB**, available **1.50 GiB**,
committed **72%**, PagesInput/s **0**, PageReads/s **0**. This does not establish a
paging cause or a leak; it establishes a reproducible workload-dependent read
failure. Initial available memory was 2.48 GiB; a build-time sample was 1.08 GiB.

Evidence: `b1-browser-rpc.jsonl`, `b1-timeout-responses.json`,
`b1-failed-order-read-request.json`, `b1-order-read-reproduction.log`,
`b1-resource-failure.json`, and `b1-03-po-read-timeout-blocked.png`.

**STOP for Owner scope review:** K3 authorizes only the existing Confirmed Need
review extension, Allocation shaped read and Preparation advisory. It does not
authorize changing PO/PXK shaped reads, shared currentness guards or effective
composition resolution. The next decision must explicitly bound permitted
performance work on that existing call path, preserving live canonical source
checks, exact School membership, whole Supplier/date coverage, writers,
privileges, immutable history and the 8s public budget. Do not release or rebuild
the pending Draft to bypass the read gate. A preservation checkpoint and its CI
results are not complete K3 acceptance; no K3 Draft PR is justified yet.

### Continuation manifest and rollback

The original 42-file manifest below is preserved. Three additional implementation
files bring the parent-relative manifest to **45 files**:

- `scripts/check-atlas-vnext-ui-boundary.mjs`
- `scripts/check-atlas-vnext-ui-boundary.test.mjs`
- `supabase/migrations/20261020022939_atlas_k3_ordinary_allocation_blocker.sql`

The continuation also updates the existing K1/K2/D037 tests, this task report,
the existing Procurement API contract and existing plan. The third migration is
a forward-only read-message repair with no data backfill or rollback mutation;
a reviewed forward rollback may restore the preceding read definition while
preserving all business facts. No hosted writes, deployment, merge, ancestor
changes, actual Supplier contact or real commitments occurred.

## Scope and constraints

Add advisory backend-derived `correct_released_confirmed_needs` eligibility and matching safe Vietnamese disabled reasons to the existing review response. Preserve the five v3 correction bindings, v2 actions and the existing v3 writer. Then connect explicit correction, canonical readback, existing Allocation acceptance, Preparation, complete replacement Draft and independent PO Release, historical export and PXK impact.

Only the existing review extension and the newly approved `atlas_api.get_confirmed_supplier_allocation_workbench(jsonb)` / `atlas_core.purchase_review_preparation_status(date,uuid)` may change in SQL. No new public RPC, persistence, role, capability, grant, RLS policy, trigger, lifecycle, writer, receipt or lock changes. No arithmetic or business authorization in React. Keep 8-second public budgets and the existing 20-second Preparation budget. Preserve frozen PO/PXK facts and complete Supplier/date coverage.

No merge, rebase, force-push, hosted migration/deployment, OPS v1/Retool write, real Supplier commitment/contact, Warehouse implementation or document polish. Missing privileges or expanded domain authority require an exact STOP report.

## Execution and evidence ledger

1. **Read contract**: authenticated red tests; one forward migration; focused SQL/security/K1/K2 regressions; independent read/security review before UI integration.
2. **Operator wiring**: typed v3 builder, separate correction mode/reason/review, fresh canonical result and existing Procurement/PXK continuation; focused API/controller/UI tests.
3. **Connected acceptance**: disposable exact-stack local Supabase and authenticated browser at 1366×768 and 390×844; record 100 → 110 → PO-002 → 90 → PO-003, exports, PXK, context/Actor guards and UNKNOWN recovery.
4. **Delivery**: independent review, focused checks, commit/push, one Draft stacked on #409; exact-head Frontend, Smoke and actually executed Full Integration. Record failures as well as final outcomes.

Disposable runtime configuration and logs live outside the repository in this chat's artifact directory. The runtime references this checkout's migrations and functions; it is not another implementation checkout. Existing local databases are not reset or migrated.

### Read-contract gate

- Disposable Supabase project/container: `atlas-k3-local-01` / `supabase_db_atlas-k3-local-01`; API `http://127.0.0.1:56321`, database port 56322. Started from the complete pinned migration chain. The first startup failed an optional postgres-meta health check and removed its incomplete containers; the second explicitly excluded optional services and succeeded. Existing projects were untouched.
- Forward migration: `20261019220351_atlas_k3_correction_review_eligibility.sql`, generated by the pinned CLI. Only `atlas_core.d037_extend_workbench(jsonb,uuid)` changes. Before/after catalog comparison proves every other Atlas function (including v3 writer), policy, role, role membership and relation ACL/RLS unchanged.
- Authenticated RED: 18 missing/new-read-semantics assertions failed on the pinned definition. An initial test-helper JWT restoration error was corrected and the 18 actual missing-feature failures were reproduced before installing the amendment. Expanded GREEN: 117 assertions, retaining all original K1 protections.
- Independent static read/security review PASS. Its nonblocking request for an explicit distinct current decision before recognizing a post-release successor was incorporated. No new privilege is needed. Downstream availability is documented as Procurement review navigation, never permission or document readiness.
- Six actual Menu/Attendance/Pantry source-vs-Save interleavings PASS, with positive advisory read before the race. Existing timeout/lock guarantees remain. Ten retained K2 PO-release concurrency/replay/UNKNOWN cases PASS.
- Retained focused SQL suites PASS: K2 93, receipt integrity 50, ordinary D037 (including no-Handoff binding assertions) 37, whole-platform security catalog 30, school-catering PO 161, School PXK 134, Purchase Review 193.
- Frontend exact-request/projection tests have a recorded RED/GREEN check. Initial local filename filters also discovered historical `.worktrees` suites; subsequent focused commands explicitly exclude `.worktrees` so only the authorized checkout supplies test code. This is a local invocation correction, not a CI/test configuration relaxation.
- Controller RED: six assertions failed for the absent explicit correction flow; GREEN: six pass, covering explicit entry, absent/false action, required reason, changed-only v3 payload, canonical readback, reason-only dirty scope guard and UNKNOWN no-retry recovery.
- Independent implementation review identified three concrete gaps before connected rehearsal: the legacy v2 lifecycle blocker denied real released v3 entry; genuine K1 REOPENED batches admitted ordinary editing despite v2 Save=false; and incoming Allocation scope could abandon UNKNOWN recovery. Backend-faithful regression tests reproduced all three and the fixes passed all 57 Confirmed Need/Procurement controller tests. No writer or authority change was required.
- Minimal continuation/presentation seams now preserve selected School/date scope, guard retained dirty allocation, explicitly accept balanced stale-source splits, show existing PO predecessor/successor links and read current PXK effects without releasing a successor. Focused seam tests pass. Issued PO scope association is explicitly School/date/location membership; the read does not claim exact Need-release-to-PO lineage that the public DTO does not expose.
- Two broader local UI invocations were stopped during severe host paging (74–154 MB free RAM); the first reported three timing failures in existing PXK scenarios. Logs remain non-green; no timeout, assertion or test configuration was changed. Focused checks continue and exact-head normal CI is still mandatory. The task-owned backend was stopped during UI validation; unrelated local stacks remain untouched pending the user's resource preference.

Logs and snapshots: `C:/Users/hp/.codex/visualizations/2026/10/19/01a154a3-b9ad-7f12-8d4a-a3d195f68fc4/k3-local/` (including `read-red.log`, `read-green-1.log`, `read-expanded-2.log`, `catalog-before.json`, `catalog-after.json`, `read-write-races.json`, `k2-races.log`, `frontend-red-verified.log`, `frontend-green-verified.log`, `controller-red.log`, `controller-green-1.log`). The first two read logs intentionally preserve earlier failed attempts.

### Historical connected rehearsal and STOP

The pinned CLI successfully reset **only** `atlas-k3-local-01` through the complete final migration chain, including `20261019220351`. The source checkout remained on the K3 branch; the CLI's external runtime branch label `main` is not a source checkout change. The disposable fixture passed 35 prerequisite assertions and provisioned three synthetic Auth users. Its first provisioning attempt rolled back because converting temporary tables without schema qualification selected `pg_catalog`; the provisioner now qualifies its disposable tables in `public`. Both attempts are retained.

The Vite development module graph stalled during memory pressure. A local production build succeeded in 16.89 seconds and was served at `http://127.0.0.1:5177`, connected through a loopback recording proxy to the real task Supabase API. The proxy forwards actual authenticated requests; its optional one-response-drop mechanism was **not armed or exercised** before the STOP. No browser mocks supplied business responses.

Real browser results at 1366×768:

- Authenticated operator `b6000000-0000-0000-0000-000000000101` opened the released 100 kg Need; quantity was read-only and the distinct backend-authorized correction action was available.
- Review stayed disabled after entering 110 without a reason. A human reason enabled the explicit review, which showed exactly 100 → 110 and focused Cancel initially.
- One actual `RMVP-05.v3` command `43ffa943-21f3-497e-a1d0-f10de13f5843` succeeded. Fresh preflight and review displayed 110, authoritative 100 → 110 / variance10, reason, immutable history and pending Procurement. No new PO was issued.
- The 110 kg Supplier split and note were explicitly accepted. The untouched 3 kg beans family was also advertised as `STALE_REBALANCE_AVAILABLE`, with `save_allocation=true`. Its explicit same-quantity acceptance succeeded.
- Both returned rows then said `BALANCED`; `preparation.ready=true`, `allowed=true`, blockers `[]`. Actual Preparation command `752cf593-b552-4179-baa0-ffc85dc0f9b6` rejected with `PREPARATION_BLOCKED`, nested `SOURCE_CHANGED` for beans family `826896ca-b2b8-49fc-8316-11bbb7f0f392`, revision `051ff091-70e4-41ab-a576-21142e142536`. A fresh read still advertised ready/allowed. No Preparation retry or recovery write was attempted.
- PO-001 remains the sole 2 November PO: `c80030b9-759d-4192-a945-816972f7ae14`, official number `PO-20261102-C80030B9759D4192`, frozen rice100 and beans3. It remained exportable. Before/after XLSX archive entry contents are **all identical**; raw ZIP bytes differ because the export containers have different timestamps. See `po001-export-comparison.json`.
- Existing PXK `PXK-20261102-7B6EB15625E440D5` remains historical; fresh public read shows `BLOCKED`. No PXK successor was created. The same connected PO/PXK state was inspected and captured at 390×844.

The independent reviewer confirmed the exact incompatibility:

1. K2's `school_catering_family_projection` selects corrected Need only for proved affected families; untouched beans must retain original Handoff (`20261019090134_atlas_k2_corrected_need_purchase_orders.sql`, lines431–455).
2. `get_confirmed_supplier_allocation_workbench` switches to Handoff only while batch status is `RELEASED_FOR_PURCHASE_HANDOFF`; K1 changes it to `REOPENED`, so the read instead supplies current-Need bindings for untouched beans (`20260903072648_purchase_review_confirm_release.sql`, lines273–277). Save accepts that source; the canonical Preparation frontier rejects it.
3. The older public Procurement read exposes canonical fingerprints and documented contribution-source XOR, but enumerates only released Handoff keys. It omits legitimate pre-Handoff families (`20260831090000_school_catering_handoff_allocation.sql`, lines518–527). Its School labels/filter use default-location membership, so it cannot replace the exact contributing-School read.
4. Pairing these reads cannot safely classify an unmatched ordinary pre-release `REOPENED` family versus a post-release `REOPENED` family with missing/invalid Handoff. The independent review initially judged pairing feasible, then withdrew that conclusion after verifying key enumeration. Neither quantities nor navigation origin supplies this missing authority. Adding a Need-review dependency would change Procurement's Planning-read capability requirements.

**Owner decision needed:** authorize a narrowly bounded Procurement shaped-read correction that projects each family's canonical server-selected operational source and exact writer binding, explicitly distinguishes safe pre-release authority from unavailable post-release evidence, retains exact contributing School scope, and aligns Preparation advisory with the same canonical frontier. Preserve all existing writers, privileges, RLS, roles, capabilities, history, receipts and locking. Add authenticated ordinary DRAFT/pre-release REOPENED, affected/same-total-changed, untouched retained-Handoff, invalid/missing Handoff, multi-School, permission and race regressions before resuming K3. If this cannot be achieved under current privileges, report the exact incompatibility instead of expanding them.

This is outside the 20 October approval's **Confirmed Need review only** amendment. No speculative paired adapter, additional SQL amendment, writer modification or raw-SQL recovery was implemented. PO-002/PO-003, post-replacement historical exports, distinct-Actor/UNKNOWN browser cases and complete B1 operator acceptance remain blocked. No push or Draft PR was created because coherent completion has not been established. Exact-head Frontend CI, Smoke and executed Full Integration remain outstanding, not claimed as green.

Final STOP checks: TypeScript build/typecheck exits0 (`typecheck-final-stop.log`); task-owned source formatting and `git diff --check` pass. HEAD remains the pinned parent `8adc0803a450192931ece3192642051ca05cc5e2`; all K3 changes are deliberately retained **uncommitted** on `feat/atlas-c-k3-operator-integration-01`, consistent with the requested coherent-completion publication gate. Six original stash hashes are retained in the local source manifest. No ancestor PR or branch was changed.

Evidence: `browser-rpc.jsonl`, `canonical-procurement-read.json`, `browser-exact-reset.log`, `browser-fixture.log`, `browser-build.log`, `01-issued-100-desktop.jpg` through `09-pxk-blocked-mobile-detail.jpg`, browser snapshots06/07, actual downloaded XLSX files and the comparison JSON. Focused final controller evidence: `review-recovery-green.log` (57 pass) and `exact-retry-pxk-green.log` (50 pass). Exact v3 retry identity has its own reproduced RED/GREEN regression. Existing unrelated Supabase stacks and all six stashes were preserved; the optional resource question was not treated as approval.

### Procurement read continuation under the new Owner decision

- Before edits, the exact pinned HEAD/branch/parent were verified; every file in the 39-file stop manifest matched its SHA-256 and all six stash hashes remained identical. The historical PO-001 export and all earlier failed/timed-out logs remain intact.
- Actual authenticated reproduction: Preparation command `d3141393-a347-49d1-8455-62b1929e3e40`, using the read's exact date/batch/version, returned `PREPARATION_BLOCKED` / `SOURCE_CHANGED` for beans family `826896ca-b2b8-49fc-8316-11bbb7f0f392`. The read reported both rows `BALANCED` and Preparation ready/allowed. Rice's read/canonical fingerprint matched; beans used CN fingerprint `3bb4591abaefde366bd16ca85983a83f213e52ea22471eb1eab2219a9dc43763` instead of canonical original Handoff `6617e118c7fd2fe1fdda853053302ee507a87e88669d2691eb2a7cd4912e1391`. Deterministic before/after snapshots of 16 upstream/Need/Handoff tables were identical. This proves a read mismatch rather than an upstream mutation or frontend request substitution.
- Test-first SQL reproduction failed five source-kind/fingerprint/contributor/state/Preparation assertions before the new migration. The same exact read-dispatched unchanged 3 kg acceptance and Preparation then passed. The current migration also exposes the valid 90 kg CN proposal without treating old 110 kg acceptance as current. Independent review is in progress; no resumed browser acceptance is claimed yet.
- Broader checks remain non-green pending completion. Retained evidence includes a combined K2 probe statement timing out at the unchanged 8s ceiling, an existing B1 Preparation timeout, an incomplete later K2 plan, and the 236-family ordinary fixture's Save timeout. Independent fault probes now execute in separate statements with the same 8s limit and all assertions retained. Only task API containers were paused to reduce resource use; unrelated stacks were left running.
- New evidence: `k3-local/procurement-read-amendment/` under the artifact directory above, including `live-red.json`, exact request/response, installed definitions, upstream snapshots, `k2-read-red.log`, `k2-read-green-1.log` (undefined-column implementation fault, fixed), `k2-read-green-2.log`, `k2-read-expanded-red.log`, and `ordinary-released-red.log`. No failed attempt is relabeled as a full pass.
- Subsequent independent static review PASS: exact typed membership and compatible source version, authentic 90 kg editable proposal, preserved ordinary Handoff lineage, unavailable legacy-source blockers, matching original legacy key enumeration, and existing authoritative cancellation discriminator. The read skips the duplicate legacy projection only when its existing deduplication would append no rows. No writer, privilege, role, RLS, receipt or lock change is needed.
- The final source revision has **not** passed execution. Default fixture setup, the unchanged public v3 preflight, and even the DDL watcher exceeded the existing 8s budget while available host memory fell to about 68 MB. One diagnostic session disabled JIT locally to distinguish compilation overhead; it also timed out and is **not operational acceptance**. No runtime setting was persisted and no test timeout/assertion was weakened. Logs `ordinary-lineage-red-2.log` prove the ordinary lineage regression before its source fix; `b1-cancel-red.log`, `b1-live-rollback-cancel-red.log`, `b1-cancel-diagnostic-red*.log` and `k1-history-procurement-red.log` retain the subsequent incomplete attempts. Cancellation and final negative-case GREEN remain pending.
- New and touched K2 savepoint assertions capture observations with `\\gset` and assert after rollback, preserving valid TAP numbering. Existing fault cases remain; each independent case retains the same 8s statement limit. The isolated `atlas_k3_read_tests` database and `atlas_k3_browser_probe` clone are disposable test resources in the task container. The original browser database was never reset; temporary read/command probes rolled back. Task API services were restarted after the SQL attempts. The two unrelated Supabase stacks remain untouched; permission to pause them temporarily was requested because of memory pressure.
- Browser endpoint remains 100 → 110 with PO-001/PXK history preserved; no new PO-002/PO-003 or post-amendment acceptance is claimed. Exact-head Frontend, Smoke and Full Integration are outstanding. Before the Owner's subsequent push instruction, HEAD remained the pinned `8adc0803a450192931ece3192642051ca05cc5e2` and all 42 files were uncommitted. The publication checkpoint above records the later instruction; no K3 PR exists.

## Acceptance matrix

| Case | Required result                                                                                               | Current evidence                                                             |
| ---- | ------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| A1   | Ordinary v2 Save/Release and initial PO unchanged                                                             | Fresh ordinary/D037 SQL PASS; released 100 kg browser baseline preserved |
| A2   | Authorized reasoned 100 → 110 correction, truthful readback, no new PO yet                                    | Fresh authenticated browser PASS |
| A3   | Explicit split acceptance, Preparation, whole PO-002/110, new number, immutable PO-001 export                 | Fresh primary browser PASS; export lifecycle metadata distinction recorded above |
| A4   | Same connected session, 110 → 90, whole PO-003, immutable linked history                                      | Fresh primary browser PASS, including committed-response loss and recovery |
| A5   | R20+B5+H3 → confirmed30, two Suppliers/Schools/shared location, removed Supplier and complete date membership | SQL PASS; browser BLOCKED after first full replacement Draft by PO/PXK read timeout |
| A6   | Stale/currentness/membership/scope/capability rejection, no locally fabricated action                         | Fresh SQL and stale/Actor/capability browser denials PASS; historical races retained |
| A7   | Distinct Actors, replay, UNKNOWN, refresh/reload, dirty School/date/tab guards and rollback                   | Fresh primary browser recovery/replay/Actor/dirty-close PASS; SQL rollback/context checks PASS |
| A8   | Authoritative PXK effects/history and independent successor, unrelated School isolation                       | Primary PXK history/successor guidance PASS; B1 PXK impact read BLOCKED |
| A9   | Authenticated disposable exact-stack browser, desktop/mobile screenshots and step logs                        | Primary desktop/mobile PASS; complete B1 operator acceptance BLOCKED |
| A10  | Focused checks and exact-head Frontend, Smoke, executed Full Integration                                      | Focused checks PASS; recovered-head CI failures retained; preservation-head results in handoff |

## Reproducible browser protocol

Start with an authenticated staff Actor in the disposable local database. Open the already-issued 100 kg Need; inspect source/PO identity and explicit permitted correction. Enter 110 kg and a human reason, review old/new values, Save once and refresh canonical reads. Verify pending allocation and unchanged issued PO. Open Allocation in the exact School/date context, explicitly accept affected splits, run existing Preparation, review the complete replacement and separately release PO-002. Inspect history/export and PXK consequences. Reload and repeat at 90 kg to PO-003. Preserve original numbers, snapshots and export content. Repeat representative permission, stale-source, second-Actor, dirty navigation and lost-response scenarios on desktop/mobile; record exact IDs and observed results.

## Migration and rollback

The approved amendment is additive and read-only; no backfill or historical mutation. A reviewed forward rollback can restore the parent review definition without deleting correction/PO/PXK history. Application rollback must keep v3-corrected chains fail-closed and preserve UNKNOWN recovery. Exact migration, file manifest, tests, review findings and open risks will be recorded as execution progresses.

## Affected file manifest at STOP

The following task-owned files are preserved on the bounded K3 branch. No ancestor PR is changed.

- `docs/api/confirmed-need-save-release-v2.md`
- `docs/implementation-tasks/TASK-ATLAS-C-K3-OPERATOR-INTEGRATION-01.md`
- `docs/superpowers/plans/2026-10-20-atlas-c-k3-operator-integration.md`
- `scripts/provision-local-atlas-k3-browser.mjs`
- `scripts/test-local-atlas-c-k1-concurrency.mjs`
- `src/modules/atlas/planning-inputs/confirmed-needs/confirmedNeedApi.test.ts`
- `src/modules/atlas/planning-inputs/confirmed-needs/confirmedNeedApi.ts`
- `src/modules/atlas/planning-inputs/confirmed-needs/confirmedNeedCorrection.test.ts`
- `src/modules/atlas/planning-inputs/confirmed-needs/confirmedNeedCorrection.ts`
- `src/modules/atlas/planning-inputs/confirmed-needs/confirmedNeedModel.ts`
- `src/modules/atlas/planning-inputs/confirmed-needs/confirmedNeedReadAuthority.ts`
- `src/vnext/atlas/AtlasVNextApp.tsx`
- `src/vnext/atlas/AtlasWorkbenchRegistry.tsx`
- `src/vnext/atlas/bridges/confirmedNeed.ts`
- `src/vnext/atlas/dispatch/SchoolPxkWorkbench.tsx`
- `src/vnext/atlas/dispatch/useSchoolPxkWorkbench.test.tsx`
- `src/vnext/atlas/dispatch/useSchoolPxkWorkbench.ts`
- `src/vnext/atlas/planning-confirmed/ConfirmedNeedCorrection.tsx`
- `src/vnext/atlas/planning-confirmed/ConfirmedNeedIssuedOrders.tsx`
- `src/vnext/atlas/planning-confirmed/ConfirmedNeedTable.tsx`
- `src/vnext/atlas/planning-confirmed/ConfirmedNeedWorkbench.test.tsx`
- `src/vnext/atlas/planning-confirmed/ConfirmedNeedWorkbench.tsx`
- `src/vnext/atlas/planning-confirmed/confirmedNeedReviewFixtures.ts`
- `src/vnext/atlas/planning-confirmed/useConfirmedNeedCorrection.test.tsx`
- `src/vnext/atlas/planning-confirmed/useConfirmedNeedDraft.ts`
- `src/vnext/atlas/planning-confirmed/useConfirmedNeedWorkbench.ts`
- `src/vnext/atlas/procurement/ProcurementOrdersStage.test.tsx`
- `src/vnext/atlas/procurement/ProcurementOrdersStage.tsx`
- `src/vnext/atlas/procurement/ProcurementPxkImpact.test.tsx`
- `src/vnext/atlas/procurement/ProcurementPxkImpact.tsx`
- `src/vnext/atlas/procurement/ProcurementSupplierDetail.test.tsx`
- `src/vnext/atlas/procurement/ProcurementSupplierDetail.tsx`
- `src/vnext/atlas/procurement/ProcurementWorkbench.test.tsx`
- `src/vnext/atlas/procurement/ProcurementWorkbench.tsx`
- `src/vnext/atlas/procurement/useProcurementWorkbench.test.tsx`
- `src/vnext/atlas/procurement/useProcurementWorkbench.ts`
- `supabase/migrations/20261019220351_atlas_k3_correction_review_eligibility.sql`
- `supabase/tests/atlas_c_need_correction_authority.sql`
- `supabase/tests/d037_confirmed_need_save_release_boundary.sql`

The approved continuation adds these three files to the preserved 39-file manifest (42 affected files total). Existing K1 tests and this task report also receive the continuation evidence above.

- `docs/api/school-catering-procurement.md`
- `supabase/migrations/20261020004031_atlas_k3_allocation_source_read_parity.sql`
- `supabase/tests/atlas_k2_corrected_need_purchase_orders.sql`
