# PURCHASE-REVIEW-CONFIRM-RELEASE-01 implementation evidence

## Delivery scope

Branch: `feat/purchase-review-confirm-release-v1`.

Base: `93af319d3a9e133614e2221202c114c0d586018e` (`origin/main` verified at task start). The explicitly authorized checkout is `E:/Project/OPS ERP/thuonghao-ops-erp`. Implementation stays in Planning, school-catering Procurement, their private source adapters, tests, documentation and CI registration. One implementation agent and exactly two read-only auditors were used. Both final audits report no remaining actionable blocker.

The [approved design](../superpowers/specs/2026-09-03-purchase-review-confirm-release-design.md), [execution plan](../superpowers/plans/2026-09-03-purchase-review-confirm-release.md), [Procurement API amendment](../api/school-catering-procurement.md#purchase-review-confirm-release-01-amendment) and [Confirmed Need amendment](../api/confirmed-need-save-release-v2.md#purchase-review-and-confirmed-allocation-amendment) describe the implemented boundary. No hosted, Atlas Staging, Retool or live OPS write was performed. Warehouse and released-PO amendments remain out of scope.

## Implemented decisions

- Generated review and XLSX use current generated quantities only and create zero operational or acceptance facts.
- Saved confirmed quantities, never generated fallback, drive explicit pre-Handoff supplier allocation in the existing four Allocation Family relations.
- Typed revision/contribution XOR preserves exact confirmed revision/decision or Handoff line evidence. No table, capability or application role was added.
- Need correction retains saved splits as stale; rebalance remains advisory until Apply and Save.
- Planning continuation is navigation-only and carries the exact working date.
- One transactional backend preparation command guards release, creates real Handoff evidence, appends allocation successors without recomputing splits, and prepares official drafts. Existing independent PO release owns official numbering and immutable supplier commitment.
- Superseded reads cannot update a new scope. Unknown outcome/readback failure locks mutations; pending exact retry blocks fresh writes and is discarded on scope/stage change or explicit refresh.

## Database verification

All suites below ran against local PostgreSQL with rollback-isolated fixtures on 2026-09-03. No reset of the user's local database was used. The harness expands repository-local SQL includes because the standard pgTAP container does not mount `supabase/local`.

| Suite                                                   | Passing assertions |
| ------------------------------------------------------- | -----------------: |
| `purchase_review_confirm_release.sql`                   |                 76 |
| `purchase_handoff_clock_skew.sql`                       |                  6 |
| `rmvp_05_connected_confirmed_need_review.sql`           |                 41 |
| `rmvp_06_connected_confirmed_need_validation.sql`       |                 65 |
| `rmvp_07_connected_confirmed_need_approval_release.sql` |                 67 |
| `d037_confirmed_need_save_release_boundary.sql`         |                 33 |
| `school_catering_handoff_allocation.sql`                |                 88 |
| `school_catering_planning_correction.sql`               |                 18 |
| `school_catering_purchase_orders.sql`                   |                 67 |
| `atlas_current_platform_security_catalog.sql`           |                 22 |
| **Total**                                               |            **483** |

The first-class public-command scenario proves generated100 → saved120 → saved72/48 → saved125 → stale retained72/48 → explicit75/50 → Handoff successor → PO quantities75/50 → independent release and backend numbering. It also proves incomplete-source refusal, no eligible supplier, historical tied priority, scope denial, exact replay/conflict, stale batch/family/fingerprint, precision rejection, released-before-Handoff recovery, plural Handoff lineage, exact PO coverage, legacy Handoff read compatibility and released snapshot immutability. Existing PO regressions independently retain unaffected supplier/date roots. Historical ambiguity/multi-Handoff fixtures use isolated, rolled-back seed contexts; real allocation and preparation commands run with normal guards.

`pnpm exec supabase db diff --local --schema atlas_core,atlas_planning,atlas_procurement,atlas_api` successfully applied every migration, including the new one, to a fresh separate shadow database and reported **No schema changes found**. This verifies fresh migration application without resetting the working database.

## Frontend and workbook verification

Focused Vitest: **310 tests in 16 files passed**, covering the changed Atlas shell/RPC registry, Procurement directory, Confirmed Need directory, Planning Inputs workbench, certification contract and local allocation helper. Typecheck and diff whitespace check passed. Touched supported files were formatted with Prettier.

The full-shell regression proves Save120 → Procurement120 (not generated100) → return to the same Planning date. Deferred-read tests reproduce the superseded-readback race; retry tests prove only the retained recovery action remains enabled. Existing released PO XLSX/PDF tests pass unchanged.

The v1 reference is the read-only 2026-02-27 Retool snapshot's `lib/js_exportPOZip.js`, not an invented workbook template. The new preliminary export preserves its two-sheet summary/detail arrangement, A4 portrait fit-to-width, repeated rows1–9, Times New Roman, table borders and supplier/School bands. Documented adaptations are one selected-date workbook instead of official per-supplier ZIP, preliminary headings, exact text quantities, wider correction/quantity columns, and blank unavailable business codes. No logo/address was fabricated. Both sheets were imported and visually rendered with the bundled spreadsheet renderer; labels, warning rows and correction space are legible. The renderer trims trailing decimal zeroes visually, while workbook readback tests verify the exact stored decimal text, including values beyond JavaScript's safe integer range.

To reproduce an inspection workbook, set `PURCHASE_REVIEW_QA_XLSX` to a temporary absolute output path and run the `GeneratedPurchaseReview.test.tsx` suite. This opt-in test artifact is synthetic and not an operational document.

## Browser QA

Synthetic Storybook stories share one in-memory Planning/Procurement state machine and call its public-shaped APIs to seed six states. All six states were inspected at **1366×768, 1920×1080, 900×900, 650×900 and 360×800**. All **30 measurements** had document scroll width equal to client width. Dense tables retain their own bounded horizontal scroll, not page overflow.

| State           | Observed result                                                                                                |
| --------------- | -------------------------------------------------------------------------------------------------------------- |
| Generated100    | Preliminary banner, supplier suggestion and XLSX action; open focuses heading, close returns focus to trigger. |
| Confirmed120    | Saved quantity and reason remain editable; one navigation-only continuation action.                            |
| Allocated72/48  | Confirmed120, allocated120, remaining0; participants-only editor; panel close returns focus to its row action. |
| Stale after125  | Retains72/48; remaining5; separate75/50 proposal; Save/preparation blocked until explicit acceptance.          |
| Official drafts | Two supplier drafts; selected detail shows75; one independent release action; no official number/export yet.   |
| Released POs    | Official number, immutable75 detail, XLSX/PDF outputs; no release action.                                      |

Keyboard Enter on preparation reaches official drafts and focuses the `Đơn mua` heading. Mobile screenshots confirmed readable supplier inputs, exact balances, proposal text and full-width action controls. Browser inspection caught and fixed new preview/preparation button contrast. Recovery regressions separately protect one primary action when retry is pending.

Additional full-Atlas-shell browser checks at1366×768 and360×800 verified Save120 → same-date Procurement120 → return to Planning with saved120 and the original date. Planning continuation now focuses the destination allocation heading; a red-first full-shell regression protects this without changing mobile sidebar focus return. Settled document widths match client widths in both layouts (1366 and345 respectively).

Console caveat: Storybook's internal documentation type-converter logs `Cannot read properties of undefined (reading 'filter')` from `storybook_internal_docs-tools.js`. No inspected diagnostic originated in the product component code and the stories rendered/operated. This tooling diagnostic is disclosed rather than reported as a clean console or a proven baseline defect.

## Migration, security and rollback

Migration: `20260903072648_purchase_review_confirm_release.sql`. It extends existing revisions/contributions, adds four shaped APIs and private adapters, guards release/promotion/PO consumers, and makes the bounded Handoff clock tolerance explicit. Existing Handoff rows retain their source and evidence. The exact security catalog remains 107 forced-RLS tables, 29 capabilities and 11 application roles; public API count becomes103. Runtime SET/CREATE grants used during migration are explicitly removed. React receives no service-role credentials or table access.

Before any confirmed-source allocation exists, reversal still requires a reviewed compensating migration restoring affected function/trigger definitions and grants. Once typed confirmed or promoted history exists, **do not drop source columns or rewrite/delete history**; use a forward fix. Reverting only the frontend is not a complete rollback because backend release now requires saved allocation. No production migration/rollback was executed.

B1: controlled local requests show browser timestamps at server−1second, +1second and +60seconds reach source validation; +61seconds, malformed identity and extra payload remain rejected. This does **not** establish the historical Staging incident's cause. Internal preparation children use backend timestamps. Historical incident diagnosis remains unproven, not silently declared solved.

## CI and review boundary

The Draft PR must remain unmerged. Frontend CI owns the broad suite; Draft Supabase Smoke now includes the new regression suites and include-aware existing release tests. Full Supabase Integration keeps its normal ready-for-review/main trigger policy. CI status and exact delivered head belong to the PR/check runs, not a self-referential hash inside this document. Passing local checks are not a claim that hosted CI passed or that this branch is ready to merge.

The first CI run passed Frontend CI and its bounded pgTAP step, then exposed a local verifier transport defect: the pinned Supabase CLI prepares one statement and rejects the helper's three top-level fixture inserts. A follow-up wraps those same local-only inserts in one atomic `DO` block, flattens newlines for the Windows pnpm shim and preserves stderr diagnostics. The helper regressions failed before this fix and passed afterward (80 focused helper/certification assertions). The exact generated fixture SQL also passed the pinned CLI inside an outer rollback-isolated subtransaction. No production migration or business command changed.
