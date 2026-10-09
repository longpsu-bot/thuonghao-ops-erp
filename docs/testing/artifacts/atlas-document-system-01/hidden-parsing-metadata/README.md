# Hidden parsing metadata specimens

Fixture-only PO/PXK specimens generated through the production exporters on
9 October 2026. No database connection or operational write.

- Four PO modes (all, summary, Ingredient details, School details), plus PXK single
  and grouped Excel workbooks: six workbooks, five PDF companions.
- Hidden row columns retain technical identities, exact quantities and row kinds.
  `_ATLAS_META` remains very-hidden; every physical item/continuation row keeps its
  released source associations. Business document codes remain visible.
- `manifest.json` records exact source/printed quantity parity, hidden fields,
  very-hidden sheet text and specimen hashes. `determinism-report.json` confirms
  identical repeat-generation hashes after fixture ZIP timestamp normalization.
- `excel-report.json` records native Excel open/save/reopen, exact hidden and
  visible text, hidden column state, very-hidden sheet state and print pagination.
  `native-qa/*-NATIVE-SAVE-TEST-ONLY.xlsx` are save/reopen verification copies;
  the root XLSX files remain unchanged.
- `pdf-text-report.json` covers every PDF/native print page with no missing
  expected visible strings. The two contact sheets display all 16 pages.
- Focused automated validation: 88 tests in six files pass; TypeScript passes.
  Shopping List V2/A+, backend schema/security and prior closeout evidence remain
  unchanged.

Reproduce from the repository root:

```powershell
node scripts/certify-atlas-document-system.mjs docs/testing/artifacts/atlas-document-system-01/hidden-parsing-metadata --hidden-parsing-review
node scripts/certify-atlas-document-system.mjs docs/testing/artifacts/atlas-document-system-01/hidden-parsing-metadata --hidden-parsing-review --verify-determinism
powershell -NoProfile -File scripts/certify-atlas-document-system-excel.ps1 -OutputDirectory docs/testing/artifacts/atlas-document-system-01/hidden-parsing-metadata
```

The existing PDF review script requires the configured PyMuPDF/Pillow runtime.
See [the parsing contract](../../../../api/operational-document-xlsx-metadata.md).
