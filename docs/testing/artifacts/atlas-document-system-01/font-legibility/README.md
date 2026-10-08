# V1 font legibility follow-up — PR #360

Owner follow-up on 8 October 2026: compare the small printed fonts with V1 and
improve where needed. Presentation-only continuation of `f044514`, same Draft PR.

## Measured reference and chosen sizes

The original owner PO and grouped Dispatch workbooks were printed in native Excel
and compared at the same physical scale. [Comparison image](font-comparison.png)
shows V1, the previous production PDF, and this revision; the
[font report](font-comparison.json) records extracted PDF sizes.

| Document   | V1 native printed body/quantity | Previous production PDF     | Revised production PDF | Revised XLSX font |
| ---------- | ------------------------------- | --------------------------- | ---------------------- | ----------------- |
| PO detail  | 13.68 pt                        | 10 pt                       | 14 pt                  | 14 pt             |
| PO summary | 14.04 pt                        | 10 pt                       | 14 pt                  | 14 pt             |
| PXK        | 15 pt                           | 11 pt body / 12 pt quantity | 15 pt                  | 16 pt             |

PO table headers now use 16 pt in both formats. PXK table headers and signatures
use 15 pt in production PDF and 16 pt in Excel. The native V1-equivalent output
measures 13.32 pt for PO detail quantities, 14.04 pt for PO summary, and 14.76 pt
for PXK, close to the original V1 prints. Company/address/title and supplemental
metadata retain their separate hierarchy; preliminary quantities now match its
existing 14 pt body text.

## Layout and preserved precision

The compact exact-string quantity rule remains unchanged: trim fractional
trailing zeros, keep all significant digits, record more than two remaining
decimal places as precision exceptions. Text cells stay right aligned with
`@` format. Item descriptions retain the extra space requested by the Owner.

Ordinary forms remain portrait. Long exact quantities use landscape in native
PO, PXK, grouped Dispatch and preliminary exports; only the wide summary view
changes orientation inside an all-view PO PDF. The native landscape form uses a
139-column width budget and fixed 100% scale to keep readable fonts and honor
manual breaks. Excel fit-to-page ignores manual breaks. PXK keeps its leading
spacer rows, signature roles, instructions and handwriting area together; the
landscape leading gap is shorter to avoid an empty final page.

Normal V1-equivalent PO stays 2 / 3 / 1 native pages (Theo hàng / Theo trường /
Tổng); the production PDF now also uses 2 / 3 / 1. Normal PXK stays two native
pages and one production PDF page, with room for handwriting. Larger stress
fixtures use more pages than the previous small fonts. Their repeated identity,
grouping and signature context is checked; page-count identity across formats
is not claimed.

## Regenerated specimens and validation

- PO [all XLSX](V1-equivalent-3F-all.xlsx) / [PDF](V1-equivalent-3F-all.pdf).
- PO [Tổng XLSX](V1-equivalent-3F-sum.xlsx) / [PDF](V1-equivalent-3F-sum.pdf).
- PO [Theo hàng XLSX](V1-equivalent-3F-details_ing.xlsx) / [PDF](V1-equivalent-3F-details_ing.pdf).
- PO [Theo trường XLSX](V1-equivalent-3F-details_school.xlsx) / [PDF](V1-equivalent-3F-details_school.pdf).
- PXK [XLSX](V1-equivalent-PXK-13.xlsx) / [PDF](V1-equivalent-PXK-13.pdf).
- Mixed/large [PO](PO-quantity-display.xlsx), [PXK](PXK-quantity-display.xlsx),
  [preliminary](Purchase-review-quantity-display.xlsx).
- [Manifest and precision ledger](manifest.json), [native Excel report](excel-report.json),
  [PDF text report](pdf-text-report.json), and all `visual-review-*` contact sheets.

The manifest records 20 clean XLSX, 15 production PDFs and three existing-mode
ZIPs. Native Excel opens/saves/reopens all 20 workbooks, verifies 574 exact-text
cells, preserves clean originals and reports zero horizontal cropping. Independent
Decimal checks reconcile 562 source-backed quantity cells in 18 native-saved
workbooks, including all 386 precision exception occurrences and comments.
The three distinct synthetic exception values are `1.234567`, `12.345678` and
`99999999999999.123456`; V1-equivalent fixtures have zero exceptions.
No live production-data audit is claimed.

Printed quantities and totals remain mathematically identical to their source,
including the PO `12.390000` and PXK `100000000000426.165678` conservation tests.
All 15 production XLSX/PDF quantity parity certifications pass. Native PDF QA
checks expected text, complete signatures, at least 100 pt handwriting clearance
and no header-only Dispatch/PXK pages. All 56 production/native documents and
230 pages are rendered into 29 contact sheets for visual review. The stressed
native PXK/grouped sheet now uses nine pages with no empty table page; its
production PDF uses four. The large PO uses 21 / 9 / 8 native pages across its
three views and 20 production PDF pages.

Focused exporter/presentation/package/UI tests: seven files, 64 PASS.
Shopping regressions: five files, 113 PASS; clean V2/A+ import has zero changes.
Format, typecheck and build pass; build retains existing bundle warnings. Required
final-head GitHub CI is tracked on the same Draft PR after push.

## Boundaries and Owner acceptance

No backend, schema, API, calculations, allocation validation, saved Confirmed Need,
released snapshots, immutable history, source identity, Units, grouping, supplier
notes, status or filename/ZIP modes change. Security authority is unaffected.
No migration or production writes; rollback is a presentation revert.

Shopping List V2/A+ remains unchanged, including its accepted import and display
precision. Its six-decimal strings can still look different from these documents;
any change needs a separate contract-aware revision.

Class C codes, cooking groups, addresses and immutable labels remain open.
Production PDF retains existing Roboto; licensed Times New Roman PDF assets and
full V1 fidelity remain Owner decisions. Preliminary reviewer-only final-page
behavior remains disclosed. Technical QA does not grant Owner visual acceptance;
PR #360 remains Draft and unmerged.
