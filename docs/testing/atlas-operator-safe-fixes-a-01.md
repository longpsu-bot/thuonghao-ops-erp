# Operator safe fixes — PR A local validation

Date: 15 October 2026

Starting main: `d102b2f1b083005d6553867fa5ccdf8c988a0316`

Status: local verification; Draft PR/review/CI pending. No merge, deployment or hosted database write is authorized by this task.

## Scope and preserved authority

The Owner's 15 October operator brief authorizes A1/A3/A4 first: Weekly Menu landing, readable supplier PO list/detail and School-column XLSX wrapping. A2 human Unit labels remain a separate contract follow-up; B/C/D and Warehouse implementation are excluded. Existing authorization, quantities, currentness, immutable releases, source identity, unknown-outcome locks and thirteen persistent owners remain in place. ExcelJS remains the production workbook author.

All three initial workspace references now use the existing `planning` owner. Identity remount and existing date/week seeds remain unchanged. Tests that exercise School drafts navigate to that owner explicitly; no close/sign-out guard is removed.

The PO list stays full width when its selected detail expands below it. Existing heading focus and originating-row focus return are retained. Counts distinguish created roots, Drafts, released roots and existing attention states. Supplier release feedback names one supplier/document after successful readback; failed readback retains the existing uncertain/locked outcome. Export/ZIP and Preparation are not presented as supplier release.

Recipient counts use distinct supplied School UUIDs, not delivery-location names. A complete supplied breakdown shows its first two names with an explicit expansion. Current Draft projections can lack frozen School breakdowns: empty or partial coverage shows a controlled unavailable/incomplete School message and the known delivery locations instead of a false zero/complete count. Search includes supplied School names. The realistic 17-order fixture has 16 Drafts with unavailable School breakdowns and one released order with three distinct Schools sharing a location. The missing Draft School projection remains in A2; this PR invents no backend data.

## Browser and focused tests

[Browser report](artifacts/atlas-operator-safe-fixes-a-01/browser-report.json) records the local production App's existing fixture entry at 1280×900, 1440×900 and 1920×1080. Fixture login and a fresh mount open only Weekly Menu. The PO list retains full width on selection; no document horizontal overflow, cell spill or overlapping actions was detected. School expansion, detail focus/return, Draft release and released-only export gates pass. Zero hosted requests or business commands were executed. This is fixture UI evidence, not live authentication or hosted business acceptance.

Selected captures: [1280 list](artifacts/atlas-operator-safe-fixes-a-01/orders-1280.png), [1440 detail](artifacts/atlas-operator-safe-fixes-a-01/order-detail-1440.png), [1920 list](artifacts/atlas-operator-safe-fixes-a-01/orders-1920.png).

Test-first controls reproduced the old School landing, missing state/recipient summary, generic release feedback, unavailable Draft coverage/School search and incorrect physical width/height expectations. Focused passing results total 188 across 12 files: 42 App/persistent-owner/page-transition/thirteen-owner checks, 21 convergence/Procurement-exit/auth checks, 27 PO-stage/export checks, 47 Procurement-controller checks and 51 School-measurement/PO-export checks. The PH preservation control also passed against the original layout; it is not claimed as an orphan reproduction. Local type checking passes. The targeted Impeccable layout detector returned no findings; final browser inspection covers the later unavailable-Draft copy/data correction. Final formatting/whitespace results are recorded in the PR. GitHub owns full routine validation.

## Native Excel diagnosis and result

The original calibration used an unstyled blank ExcelJS workbook resolved by native Excel as Arial 11/8px maximum digit width. Production exports emit a styled Normal font of Calibri 11/7px. Consequently the former model predicted 240pt for the original School C width while native Excel measured 210pt. This overestimated usable width and underestimated some long School heights. The existing calibration tool now requires a read-only production calibration workbook, emits a styled probe and rejects a different Normal font/size. All 15 native/predicted width samples are recorded, with maximum rounding difference 0.75pt within the existing native width QA tolerance of 0.76pt. The independent printed glyph clearance remains 0.5pt.

Only calibration provenance changed in the metric file. Original regular/bold Times New Roman 14pt glyph maps are retained verbatim and their numeric values/font hashes match the native remeasurement. The fixed Owner rule `28 + 16 × (measured lines − 1)` and measurement algorithm remain unchanged. `details_ing` transfers six existing width units from note padding to School C: native 210→241.5pt, while F becomes 168pt and retains its conservative note-height budget. Total column width, page orientation/scale, source font, canonical strings and quantity/lineage authority are unchanged.

The fixture includes exact PH1/PH2/PH3 canonical labels with distinct UUIDs. All 14 School input labels, including four artificial long specimens, are identical to baseline; the existing generator's optional baseline manifest prevents calibration from shortening its synthetic labels. [Source fact comparison](artifacts/atlas-operator-safe-fixes-a-01/source-facts-comparison.json) preserves hidden ITEM identities/exact quantities and metadata source payloads across all four workbooks, excluding physical row numbers that pagination may change.

- [Native open/save/reopen evidence](artifacts/atlas-operator-safe-fixes-a-01/native-open-save-report.json): four workbooks, 742 exact text/metadata checks; clean source files unchanged.
- [Native width/height observations](artifacts/atlas-operator-safe-fixes-a-01/native-width-report.json): 31 rows, maximum physical-width error 0pt. Five artificial long rows exceed the fixed height under screen AutoFit; AutoFit remains advisory and does not replace printed glyph evidence or alter the approved height rule.
- [Screen sizing comparison](artifacts/atlas-operator-safe-fixes-a-01/native-screen-sizing.json): PH1/PH2/PH3 original cells require 37.5pt/two screen lines against 28pt allocated; final width requires 18.75pt/one line. Native **printing already kept each PH label on one line in baseline**; no printed orphan failure is claimed.
- [Strict PO-only printed acceptance](artifacts/atlas-operator-safe-fixes-a-01/native-po-acceptance.json): 28 School rows pass full text and unchanged 0.5pt geometry clearance, including six PH occurrences without standalone suffix-number lines. Baseline had five PO School geometry failures; final PO has zero. Root inspected all six PO page images. Selected [baseline](artifacts/atlas-operator-safe-fixes-a-01/po-baseline-page-1.png), [final page 1](artifacts/atlas-operator-safe-fixes-a-01/po-final-page-1.png) and [final page 2](artifacts/atlas-operator-safe-fixes-a-01/po-final-page-2.png) show the bounded School-layout result.

## Known limits and integration boundary

The **combined four-workbook printed gate remains FAIL** at a pre-existing Dispatch long-School header A6 right clearance of 0.42pt versus the unchanged 0.5pt minimum. [Durable failed-case evidence](artifacts/atlas-operator-safe-fixes-a-01/native-known-failures.json) records five baseline PO failures plus that PXK failure, followed by zero final PO failures and the same PXK failure. This PR does not change the Dispatch producer or relax/drop that case. The numeric width/height report does not imply the combined acceptance script passed.

The pre-existing `Ngày dùng` header label wraps/clips its second line in both PO detail directions; baseline and final have the same issue, while the date value remains visible. This is outside the bounded School-column correction. The whole page is not certified flawless, and arbitrary labels/other Office-font-printer environments are not guaranteed.

Historical 108/109 reports and prior document certifications remain unchanged. No Unit-label contract change, backend migration, real PO release, hosted fixture, staff assignment, OPS-v1/Retool/Production write or Warehouse work occurred. A reviewed Draft and exact-head CI do not authorize merge/deployment under the current brief.
