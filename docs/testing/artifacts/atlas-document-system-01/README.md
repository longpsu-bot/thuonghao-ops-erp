# Atlas document-system review specimens

Synthetic fixture data only. The 12 XLSX files at this level are clean, editable
review deliverables. The eight PDFs are actual production pdfmake output.
`native-qa/` contains separate `NATIVE-SAVE-TEST-ONLY.xlsx` round-trip copies and
28 worksheet PDFs printed by installed Microsoft Excel 16.0. Do not use these
fixtures as business records or import them into live OPS.

`manifest.json` records captured cells and clean hashes. `excel-report.json`
records normal open/save/reopen, 419 exact text checks, native page breaks and
repeat headers. `pdf-text-report.json` reconciles expected visible strings for
all 36 PDF documents. `visual-review-01.png` through `visual-review-19.png` show
every one of the 151 printed pages. The independent reviewer inspected sheets
15–19 plus Attendance/PXK in 03; implementation inspected the remainder.

`determinism-report.json` records identical normalized bytes for 19 specimens
and identical captured Shopping cells/print geometry. Shopping's existing random
protection salts remain unchanged; its source exporter and V2/A+ parser are
preserved. ZIP timestamps and Shopping fixture modified-time normalization are
review-artifact metadata only.

From the repository root:

```powershell
node scripts/certify-atlas-document-system.mjs
node scripts/certify-atlas-document-system.mjs docs/testing/artifacts/atlas-document-system-01 --verify-determinism
& scripts/certify-atlas-document-system-excel.ps1 -OutputDirectory docs/testing/artifacts/atlas-document-system-01
python scripts/review-atlas-document-system.py
```

Run native QA after the final deterministic generation. Python needs PyMuPDF and
Pillow; native QA needs installed Excel and does not modify the clean originals.
PDF review also asserts supplier/destination context on each preliminary quantity
page and complete PXK signature groups on each signature page.

Representative cases: two suppliers, one/multiple Schools, distinct locations for
the same School, released/superseded snapshots, long Vietnamese labels/addresses,
60 lines, `99999999999999.123456`, a 492-character/240-newline PO note, unresolved
preliminary recommendations, blank Attendance portions, preserved Shopping A+.

Technical review passes. Owner visual/product acceptance remains pending,
including retained Roboto for production PDFs and a separate reviewer-only final
page in the large preliminary summary specimen. No global document freeze.
