# Printed quantity precision — PR #360

Owner decision on 8 October 2026; presentation-only continuation of reviewed head
`03580da349047881c247601538b3685f817ccbfb`. Keep the same PR Draft for Owner acceptance.

## Rule and scope

`formatExactDocumentQuantity` validates an exact nonnegative decimal string and
removes only fractional trailing zeros. Integers print without a decimal suffix;
`39.700000` prints `39.7`, `12.340000` prints `12.34`, and `0.050000` prints `0.05`.
No significant digit is rounded or truncated. More than two remaining decimal
places is a precision exception: `12.345678` remains `12.345678`.

The shared Excel cell writer uses formatted text, `@`, right alignment and no
wrapping. Exceptional cells carry a `PRECISION_EXCEPTION` comment with their exact
source string for Product review. PO and PXK PDFs use the same formatter; their
exception values are reconciled with the workbook and recorded in the ledger.
No exception triggers a command, changes a business status, or alters a snapshot.

Coverage: official PO `all`, `sum`, `details_ing`, `details_school` XLSX/PDF and
existing supplier/date ZIP; single School PXK XLSX/PDF; grouped/date/entity Dispatch
XLSX and ZIP; preliminary purchase review `Tổng` and `Chi tiết` XLSX/native PDF.
Preliminary and grouped Dispatch retain their existing export formats; no new
production PDF workflow is introduced.

The Owner's follow-up gives item descriptions more space and reduces routine
quantity columns. Native PO detail and preliminary forms move saved quantity
width to the item column; native PO summary and PXK preserve other columns while
moving their width savings to descriptions. PDF PO quantity allowance starts at
60 points rather than 110. Large/exceptional quantities still expand their column
to remain exact and on one line; description columns never shrink below their
reviewed native baseline. Fonts, Units, grouping, notes, statuses and filename/ZIP
modes are preserved.

## Native specimens and checks

- PO V1-equivalent [all XLSX](V1-equivalent-3F-all.xlsx) / [production PDF](V1-equivalent-3F-all.pdf).
- PO summary [XLSX](V1-equivalent-3F-sum.xlsx) / [production PDF](V1-equivalent-3F-sum.pdf) / [native Excel PDF](native-qa/V1-equivalent-3F-sum-sheet-1.pdf).
- PO Theo hàng [XLSX](V1-equivalent-3F-details_ing.xlsx) / [production PDF](V1-equivalent-3F-details_ing.pdf) / [native Excel PDF](native-qa/V1-equivalent-3F-details_ing-sheet-1.pdf).
- PO Theo trường [XLSX](V1-equivalent-3F-details_school.xlsx) / [production PDF](V1-equivalent-3F-details_school.pdf) / [native Excel PDF](native-qa/V1-equivalent-3F-details_school-sheet-1.pdf).
- PXK 13 items [XLSX](V1-equivalent-PXK-13.xlsx) / [production PDF](V1-equivalent-PXK-13.pdf) / [native Excel PDF](native-qa/V1-equivalent-PXK-13-sheet-1.pdf).
- Mixed normal/exception/large PO [XLSX](PO-quantity-display.xlsx) / [PDF](PO-quantity-display.pdf), PXK [XLSX](PXK-quantity-display.xlsx) / [PDF](PXK-quantity-display.pdf), preliminary [XLSX](Purchase-review-quantity-display.xlsx).

[Manifest](manifest.json) captures original exact source quantity arrays, printed
cells, checksums, all 386 precision-exception occurrences and 15 XLSX/PDF quantity
parity checks. Specimen certification independently compares source and output
quantities using integer micro-units; it derives exceptions by a remainder modulo
10,000, rather than using the production formatter or cell comments as expected
values. This catches rounded, lost or duplicated quantities. Row identity/order
remains covered by the existing exporter tests and visual checks.

[Native Excel report](excel-report.json): 20 clean workbooks open/save/reopen,
574 exact-text checks, retained right alignment/text format, zero horizontal
cropping, and unchanged clean originals. [PDF report](pdf-text-report.json) covers
56 production/native documents, 164 pages with zero missing expected strings.
All 48 common documents have no page-count increase; the large PO Theo trường
native print improves from five pages to four. V1 native PO stays 2/3/1 pages and
PXK stays two pages; their production PDFs stay 1/2/1 and one page respectively.
All 21 `visual-review-*`
contact sheets and the full-resolution detail images provide visual evidence.
Native save copies are QA-only; use the clean top-level XLSX for review.

The V1-equivalent PO summary remains exactly `375.000000`, `147.000000`,
`1630.000000`, `39.700000` before presentation, printed `375`, `147`, `1630`, `39.7`.
V1-equivalent PO/PXK have **zero precision exceptions**. The 386 recorded
occurrences are synthetic stress/mixed values: `1.234567`, `12.345678`, and
`99999999999999.123456`. No live production-data audit is claimed.

Tests retain independent literal exact-value and conservation assertions, including
the PO `12.390000` total and PXK `100000000000426.165678` total before/after
presentation. Focused exporter/download/Shopping/Confirmed Need checks: 251 PASS;
format, typecheck and build pass. Required final-head GitHub CI is recorded on
Draft PR #360 after push. Build retains the preexisting bundle-size warnings.

## Shopping List and open Product decisions

Shopping List V2/A+ exporter, parser, codec, metadata and geometry are unchanged.
Its accepted editable quantity-import contract keeps existing display precision,
including six padded decimal places where the baseline supplies them. Consequently
its printed quantities can look different from these purchasing/dispatch forms.
Changing that display requires a separate contract-aware revision with exact
round-trip/import acceptance; this PR does not apply the print helper there.
The clean specimen import reports zero changed lines.

Existing Class C decisions on outward codes, cooking groups, PO immutable labels,
addresses and label authority remain open and unchanged. Licensed Times New Roman
PDF assets/Roboto visual differences and full V1 fidelity remain Owner decisions.
The previously disclosed native PXK signature page and preliminary reviewer-only
page remain baseline behavior; this revision must not add unwanted breaks.

No migration, API/Allocation validation change, saved Need/release/history rewrite,
or security/RLS change. Rollback is a presentation revert; it needs no database
or production-data operation.

## Reproduction

```powershell
node scripts/certify-atlas-document-system.mjs docs/testing/artifacts/atlas-document-system-01/quantity-precision --v1-reference-dir 'E:/Project/OPS ERP/Template'
& scripts/certify-atlas-document-system-excel.ps1 -OutputDirectory docs/testing/artifacts/atlas-document-system-01/quantity-precision
python scripts/review-atlas-document-system.py docs/testing/artifacts/atlas-document-system-01/quantity-precision
```

Owner reference workbooks remain read-only; their hashes are retained in the manifest.
