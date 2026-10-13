# Atlas Procurement Cutover Rehearsal Plan

> Execute inline using the existing verification workflow.

Goal: certify the released 2026-10-12 Procurement state through authenticated hosted HTTP, then normal connected operator reads.

Authority: Product's two-phase request and authorization to use a temporary protected GitHub Actions runner.

## Scope

Only scripts/atlas-procurement-cutover*.mjs, focused harness tests, this record, and conditional wiring in the existing Planning Performance workflow.
No application edits, dependencies, migrations, deployment, preparation, allocation saves, PO commands, Supplier changes, Retool, or OPS v1.
The runner checks out certified main a9230321161ce62da3572b3d5ae9f3d78f71ac42; its separate workflow revision supplies the harness after clean preflight.

## Execution

- [x] Test rejection of wrong quantities, notes, contribution lineage, duplicate identity, mismatched authority, timeout, and changed snapshots.
- [x] Run Phase A with the existing protected identity and hosted RPC; require HTTP/business success, 236 exact accepted rows, <8000ms, and unchanged authoritative snapshots.
- [ ] Stop on Phase A failure with evidence; make no repair.
- [x] On Phase A pass, run the connected frontend's normal read/navigation/refresh/reopen journey for the selected date, reconcile 17 Draft POs/236 lines, inspect high/low line-count POs, and inspect export eligibility.
- [x] Record disabled official Draft exports explicitly; never release a PO to enable export.
- [x] Capture screenshots, safe logs, before/after hashes and final report; stop for Product review of remaining acceptance gaps.

Security: use existing protected test credentials and browser-safe key for HTTP; Management SQL is BEGIN READ ONLY / ROLLBACK evidence only. Never upload credentials or session tokens.
Migration/rollback: none; temporary runner branch is not merged into main.

Phase A: [run 38464714450](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/38464714450), HTTP 200 / success, 4866.216588ms, 236 rows.
Exact accepted sorted rows MD5 48e433c45fac665d873103542408a484; business facts MD5 d55edbee74200aa3e02e8fc94ca8787d.
All fact/receipt/event/audit/Supplier snapshots equal before/after. 11 focused harness assertions pass.
Phase B reuses that successful run's protected artifact; it rechecks unchanged Staging facts before launching the hosted frontend and never replays a business command.
Operator read interception rejects every RPC outside the declared read allowlist.
Official PO XLSX/PDF/ZIP require released snapshots; all 17 accepted POs are Draft. Shopping List export/import require editable Confirmed Need and are disabled after Purchase Handoff release.
These existing state gates are verified through UI, not bypassed to manufacture downloads.

## Final operator evidence and acceptance limits

[Run 38467478461](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/38467478461) completed the real authenticated connected UI read journey.
Supplier Allocation returned 236 exact accepted rows at 3186.866 / 3637.565 / 3465.952 / 3463.308ms.
Refresh, leave/return, browser reload/session persistence and reopen passed.
The PO read took 4294.608ms, with 17 distinct Supplier/date Draft POs and 236 distinct lines.
Every line's Supplier, quantity, Ingredient, Unit, destination, Supplier note and exact source split match the accepted allocation response.
Representative PO details passed: AN THÀNH ĐÔ (148 lines) and HOÀNG PHÁT FOOD (1 line).
All 14 observed application RPCs returned HTTP 200/business success; no frontend exceptions, console errors or attempted business commands were observed.
Before/after complete fact and ledger snapshots match, including 164 receipts, 574 domain events, 574 audit events and Supplier records.

The protected frontend target remains the existing immutable 06e87532 deployment at a51759a1ae3c5d38e957b3824ee5c38c33e69205.
It predates the accepted School-first changes: the deployed Procurement table still starts with Ingredient, followed by School/location.
This was recorded as D UI/version debt and the remaining safe read rehearsal continued; the School-first acceptance is not asserted.
Official PO exports are unavailable for these Drafts, and Shopping List export is visibly disabled for released Confirmed Need.
The pinned frontend also has no ZIP PO control. No downloads were generated and successful export execution is not asserted.

TASK_STATUS: Product review required for the intended connected frontend version and applicable export acceptance scope.
ATLAS_PROCUREMENT_CUTOVER_REHEARSAL: PASS is not declared.
Retool and OPS v1 unchanged; preparation not rerun; no PO release/cancellation/replacement; no migrations or frontend deployment.
The temporary harness is confined to this unmerged branch, with 17 focused passing tests. No PR was created.

Two initial browser attempts stopped inside the recorder, not inside Atlas business logic: an element-returning DOM readiness check and CORS preflight response capture.
A later navigation attempt occurred while Atlas's initial School read exit guard was active.
Diagnostics identified these harness conditions; the final run waits for normal read readiness and uses the pinned frontend's actual controls.
These failed attempts changed no business fact, receipt, event, audit record or Supplier fact.
