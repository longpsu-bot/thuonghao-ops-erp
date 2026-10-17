# Issue 400 — partial UX checkpoint, 18 October 2026

Status: **BLOCKED for complete Workstream A acceptance. Draft preservation only.**

Authority: [Owner work order #400](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/400), superseding the older priorities in the inherited Autopilot files. Source is Draft [#392](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/392), exact head `6f9f288c76cfa48691fca2f4968ce03185502bb2`. Branch: `codex/atlas-400-ux-closeout`. This is a dependent frontend delta, not an independently deployable main-based release. Preserve #392, #393, #388 and #396 unchanged. Do not merge or deploy.

## Included delta

- Allocation dirty Cancel returns focus to the surviving Close control; Discard returns it to the initiating row button, with the persistent heading as fallback when that row no longer exists. Dirty-state, UNKNOWN recovery and backend commands are unchanged.
- The deliberate Preparation action is named **Chuẩn bị đơn mua**. Adjacent accessible copy explains Planning/Handoff and draft PO effects and distinguishes explicit **Phát hành đơn mua** supplier commitment. Navigation does not invoke Preparation.
- School picker rows no longer flex-shrink into overlapping labels. Labels wrap, the popover has a viewport maximum width, and an empty search reports no matches. Existing accent-insensitive search, UUIDs, counts, Select All/Clear and explicit Apply remain. Existing target sizing is inherited; measured desktop row height was approximately 21 CSS pixels, not a claimed 36 pixels.
- Allocation uses explicit content widths, including a 148px action column and 170px status column. With a date column, widths total 1118px against a 1120px minimum. Frozen action/recipient and local horizontal scrolling remain.
- Confirmed Need rows show their service date and exact saved quantity beside the existing editor. The existing desktop/mobile table, frozen recipient and horizontal focus reveal remain. This does **not** resolve the complete 390px quantity-context requirement.
- Actual supplier-split and recipe-line deletion use named trash controls. Ingredient code copy now says **Mã nội bộ (không bắt buộc)**. Supplier document-code guards and PO/backend export eligibility remain unchanged.
- Local-only `scenario=ux400` review data provides 50 Schools (49 reference names plus an explicitly synthetic School 50). Other workbenches retain their independent existing fixtures. This is UI evidence, not connected backend lineage proof.

Changed implementation files: `AtlasSchoolScope.tsx`, `AtlasVNextApp.review.tsx`, `master-data/IngredientDetail.tsx`, `planning-confirmed/ConfirmedNeedTable.tsx`, `procurement/ProcurementAllocationTable.tsx`, `procurement/ProcurementSupplierDetail.tsx`, `procurement/ProcurementWorkbench.tsx`, `recipes/BaseRecipeEditor.tsx`. Focused tests accompany these changes; this report is the documentation delta.

## Verification and evidence limits

The canonical authorized D: checkout, origin, clean initial worktree, branch baseline and `pnpm ops:workspace` were verified before changes. Existing worktrees and six stashes were preserved. No new dependencies, APIs, SQL, permissions or business authority were introduced.

The Allocation regression reached the actual Discard assertion and failed before the runtime fix because focus landed on BODY. It passed after the fix. Chrome keyboard Cancel/Discard also returned focus to Close/the original row button after the surfaces disappeared, preserving the unsaved exact quantity on Cancel. A new School test exercises 50 stable UUIDs, accent-insensitive search, empty results and explicit Apply. A Confirmed Need test checks date/recipient/Ingredient/Unit/saved and edited exact values after sorting. Preparation tests assert no call on opening/closing detail and exactly one call after the deliberate action.

An eight-file local run returned **167 PASS / 6 FAIL** (173 tests). Five failures reached the unchanged 5-second test limit; the sixth expected the old recipient text without the newly visible date. That text oracle was updated to retain all recipient assertions and include the date. A focused follow-up returned **16 PASS / 2 FAIL / 98 not selected by the name filter**. The date oracle, School Apply/Cancel, Ingredient sort and Supplier focus cases passed. The new Confirmed Need identity case and existing clipped-control reveal case hit the unchanged 5-second limit. Local verification is therefore **FAIL**, not a blanket PASS. The repeated reveal timeout is preserved; no further local tuning/retry is authorized in this checkpoint. TypeScript, UI boundary, changed-file formatting and diff whitespace checks passed. Exact-head ordinary Frontend CI is recorded on the dependent Draft PR. No timeout was increased, no registered test was disabled, and no full local certification loop was run. Focused commands excluded other pre-existing `.worktrees` checkouts from discovery; they did not exclude tests in the authorized checkout.

Independent source review found a status-column squeeze in the first Allocation width candidate. Explicit status/date/content widths corrected it. The reviewer then reported no remaining Critical/Important regression in the revised source, suitable only for a partial Draft subject to tests/CI. An unverified mobile stacking candidate was removed after review identified a possible loss of visible identity inside the existing 28dvh dirty-editor viewport.

Local artifacts are under:

`C:/Users/hp/.codex/visualizations/2026/10/17/01a14bb2-0dab-7f32-9c8f-404034947526/atlas-400-ux/`

| Artifact                                                                                      | What it proves / limitation                                                                                                                             |
| --------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `allocation-focus-before.json`                                                                | Before fix: BODY focus after Discard.                                                                                                                   |
| `allocation-focus-after-1366.json`, `allocation-focus-after-1366.jpg`                         | After fix: initiating button focused; DOM viewport 1366×768, screenshot 1366×769.                                                                       |
| `hosted-baseline-school50.jpg`                                                                | User-supplied preview loads, 50 connected Schools reproduce overlap. Read-only; no sync, Save, Preparation or release. Screenshot 1779×814.             |
| `school50-local-1366.jpg`                                                                     | Local 50-School labels separated; DOM 1366×768. Clipped screenshot is 1365×767, not exact target evidence.                                              |
| `school50-viewport-request1440-actual1366.jpg`, `school50-viewport-request390-actual1366.jpg` | Failed viewport requests: DOM stayed 1366×768; screenshots 1366×625. **Do not use as 1440/mobile acceptance.**                                          |
| `allocation-range-final.jpg`                                                                  | Revised populated range: readable date/status/full action labels at actual DOM 1779×814 after reset. Independent fixtures; not end-to-end date lineage. |
| `AtlasSearchSelect.PARKED.tsx`, `pantry-mobile-search-PARKED.patch`                           | Failed/unverified Pantry candidate, removed from active source after two repeated typing-regression failures.                                           |
| `confirmed-mobile-PARKED.patch`                                                               | Removed mobile candidate, retained only as diagnostic history.                                                                                          |

The earlier `atlas-400-pickup-blocked/` artifacts remain historical evidence of the initial browser/focus-test strategy stop. The Owner subsequently reconnected Chrome. They are not overwritten by this checkpoint.

## Stop and remaining work

Two consecutive multi-character Pantry combobox regressions failed after a bounded correction. The strategy was stopped and its implementation/tests were parked together outside the repository. There is no accepted 400-Ingredient combobox result and no proven environment-only explanation. Do not restart that tuning loop as if it passed.

| Workstream  | Verdict                          | Remaining acceptance / release implications                                                                                                                                                                                                                                   |
| ----------- | -------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| A — UX/UI   | **BLOCKED (partial Draft only)** | A3 School-once/category/400-Ingredient authoring; A5 group-first Schools jobs; all editable mobile quantities and sorting/filtering/validation/Save/Discard association; exact 1366/1440/390 populated dirty/UNKNOWN visual evidence. Pantry row deletion remains unfinished. |
| B1 — Pantry | **BLOCKED / not started**        | Versioned purpose-separated persistence and distinct 5+3 source lines, Need/contribution lineage, history compatibility, migration dependencies and Full Integration. No frontend purpose inference or ADDITIVE/COMPLETE repurposing.                                         |
| B2 — PO     | **BLOCKED / not started**        | Optional Ingredient code in release/replacement/snapshot/export guards and all real XLSX/PDF/ZIP modes; Supplier code still required. UI helper copy alone is not this contract change.                                                                                       |
| C — Need/PO | **BLOCKED / not started**        | One-page architecture delta after A/B checkpoints, audited 100→110→90 and whole new-number replacements, security/concurrency/performance proofs. No new authority is approved by this UX delta. Receiving SOP remains Draft.                                                 |

No new business-outcome approval is requested. The next bounded technical plan must account for the preserved two-failure stop and browser viewport evidence limitations. Any genuinely new authority/lifecycle/permission or commitment semantics still requires the explicit architecture decision described in #400. Warehouse/receiving/payment implementation remains outside scope.

## CI, migrations and rollback

The ordinary required workflow is **Frontend CI / Format, typecheck, test, build**. A stacked Draft targeting the preserved #392 branch requires dispatching the existing unmodified workflow on this exact new branch head; no custom certification workflow replaces it. Do not call the Draft merge-ready even if CI passes while Product acceptance remains blocked.

At source #392, ordinary Frontend CI and Supabase Smoke passed; Full Integration was **SKIPPED**, not PASS. Those results do not certify this new head or B/C. This delta adds no migration and does not justify a backend Full Integration run. Inherited Pantry v4 and migration-109 compatibility remains unresolved for hosted release; no Staging/OPS1/Retool writes occurred.

Rollback of this delta is a frontend commit revert. It performs no data rewrite, schema rollback, released-document mutation or supplier commitment. That statement does not certify deployment compatibility of the inherited #392 branch.
