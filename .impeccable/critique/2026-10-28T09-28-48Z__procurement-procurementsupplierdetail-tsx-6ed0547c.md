---
target: Atlas Allocation further review, baseline d6bf66f6 and bounded corrections
total_score: 27
max_score: 40
na_heuristics:
p0_count: 0
p1_count: 0
target_identity: "file:E:\\Project\\OPS ERP\\thuonghao-ops-erp\\src\\vnext\\atlas\\procurement\\ProcurementSupplierDetail.tsx"
target_fingerprint: "sha256:c3697496fe5dd7e3deef4b3d87a0be2645112f1863e8616001b675c007816991"
target_path: "E:\\Project\\OPS ERP\\thuonghao-ops-erp\\src\\vnext\\atlas\\procurement\\ProcurementSupplierDetail.tsx"
timestamp: 2026-10-28T09-28-48Z
slug: procurement-procurementsupplierdetail-tsx-6ed0547c
---

# Atlas Allocation: further design review — 28 October 2026

Method: dual-agent (A: /root/allocation_review_design · B: /root/allocation_review_evidence).

This review assessed `d6bf66f6`, then drove the bounded corrections recorded below. The score describes that reviewed baseline, not a certification of the corrected UI. Scope is the Allocation list, selected editor and directly affected tests. Warehouse, backend authority, permissions, calculations, commands and persistence are outside scope.

The desktop decision layer is specific to Atlas: confirmed need, exact reconciliation and eligible supplier splits explain the actual task. The narrow input layer was still a generic scrolling form. Row alignment alone had not resolved the screen hierarchy.

| Heuristic        | Baseline score | Main observation                                                         |
| ---------------- | -------------: | ------------------------------------------------------------------------ |
| System status    |            3/4 | Exact balance and dirty state are clear; scope disappeared on phones.    |
| Real-world match |            3/4 | Procurement terms are useful; source-date labels need care.              |
| User control     |            3/4 | Guarded Close/Discard preserves work.                                    |
| Consistency      |            3/4 | Shared tokens are coherent; mobile cells retained desktop artifacts.     |
| Error prevention |            3/4 | Exact arithmetic, eligibility and command guards hold.                   |
| Recognition      |            3/4 | Baselines help; hidden scope required memory.                            |
| Efficiency       |            2/4 | Empty notes and the tall footer consumed comparison space.               |
| Minimalism       |            2/4 | Nested phone frames and supporting fields had too much weight.           |
| Recovery         |            3/4 | Quantity errors and exit recovery are explicit.                          |
| Help             |            2/4 | Existing contextual help works; source inconsistencies limit evaluation. |
| **Total**        |      **27/40** | **Before the corrections below.**                                        |

## Findings and resolution

1. **P2 — Phone editing displaced its scope.** `scrollIntoView` and an `80dvh` editor competed with the owner's scroll viewport. At 390px the outer panel scrolled 76px and clipped almost all of the scope header. The editor now uses the remaining workspace height; initial focus uses `preventScroll`. Scope stays visible and outer scroll remains zero.
2. **P2 — The mobile fact grid orphaned status.** Automatic placement separated quantity, supplier and status, while desktop separators remained. Explicit grid areas now pair quantity/status for the single-date record, retain a coherent dated layout, and remove narrow separators.
3. **P2 — Add/Remove lost keyboard focus.** Unmounting the active control left focus on BODY. Add now focuses its quantity; Remove focuses an adjacent quantity or Add when the last draft row is removed. Opening a note focuses its textarea.
4. **P2 — Footer and nested frame competed with editing.** The phone footer was 131px. One action row is now 77px, retaining 44px targets. Removing the inner phone border/padding gives the editor one working plane and increases its 390px-width work area from 348px to 368px.
5. **P2 — Empty notes had primary visual weight.** Each expanded empty note occupied about 89px. The Owner chose notes on demand for narrow screens. Saved notes remain open; an empty note uses a quiet 44px disclosure and stays open after editing/clearing. Wide desktop note columns remain visible.

Keep the 340px desktop need directory, shared column headings, aligned quantity/note controls, exact reconciliation, complete accessible quantity context and existing Save/exit/recovery guards.

## Source-qualified observations

The fixture's workbench date is 07/09/2026 while its selected source date is 10/09/2026. It also displays an aggregate mismatch warning alongside a balanced row. These facts are preserved. They do not establish a production calculation bug, and this change does not invent the warning's business scope or reconcile data through styling.

P3 remaining copy observation: a derived-default state repeats supplier priority (`Mặc định #1`) and baseline (`Mặc định: 100 kg`). They are distinct facts; no wording was changed in this pass.

## Verification and limits

- Deterministic detector: zero findings across the three target files. This did not detect the original visual/interaction defects.
- Chromium at 1920, 1440, 1366, 1024, 650, 390 and 360px: no page errors or document horizontal overflow; editor fits, scope is visible and outer scroll stays zero.
- Wide quantity/note tops align. Add, Remove, note disclosure, balanced drafts, dirty Cancel and Discard/Close pass. Browser review did not invoke Save. The longer acceptance command also remains reachable.
- Focused editor/workbench/table checks pass (116 assertions/tests reported by that run), affected navigation/UNKNOWN regressions pass (10), and final saved-note/disclosure/last-row-focus cases pass (2 targeted cases). Typecheck, formatting, vNext boundary and whitespace checks pass.
- Independent finish review found no remaining material issue in the supplied fixed states. This is bounded acceptance, not blanket Atlas approval.
- No physical phone, screen-reader speech, other-browser, high-density supplier or hosted-workflow certification. Existing source inconsistencies remain disclosed.

Owner preference question answered: empty notes open on demand. No further preference decision is needed for this bounded correction.
