# OPS v1 PO detail spacing — 7 November 2026

Owner request: remove one of the two blank Excel rows between Supplier row 6 and
the PO detail table header at row 9. The canonical D: checkout was clean and a
new branch was created from latest `origin/main`, preserving the previous branch.

Scope: `js_export_po_xlsx_grouped` in the actual Retool OPS v1 `PurchasePlanner`
page, app `eee6beba-176a-11f1-bbee-4b1ba5ff10c1`. The current PO Excel router uses
this exporter. Both detail layouts (`Theo hàng`, `Theo trường`) move their header,
merges and styling to row 8, start their content at row 9, and repeat rows 1–8
when printing. Row 7 stays blank. The summary sheet retains its Supplier-code
row 7 and existing layout.

No query, database, business quantity, School label, export grouping, Supplier,
Unit, note, PDF or Dispatch change is included. The preceding Bình Mỹ label
hotfix remains intact.

`before.json` retains the exact live exporter source. `patch.mjs` generates only
the two bounded row-offset changes and refuses an unknown source. Its `rollback`
restores the original only if the current complete source equals the patched
text. Stop on source drift rather than overwriting somebody else's edits.

Acceptance: a fresh real PO workbook has exactly one blank row after the Supplier
line, with its detail header at row 8; all corresponding body cells, quantities,
merges and styles match the original shifted up one row. Summary output remains
identical. Compare actual existing-document exports before/after, and inspect the
Tài Tài example from the Owner's screenshot. No PO creation/confirmation is needed.

Validation and hosted-application evidence are recorded on the audit PR. Routine
Frontend CI belongs to GitHub Actions; no local full frontend suite is required
for this presentation-only Retool exporter patch.

Applied to the live Retool exporter and copied back after Save with exact source
equality (42,452 characters). A fresh user-mode export of existing 10 November
POs was compared against the retained original export: all 16 workbooks passed.
All 32 detail sheets have identical cell values, styles and merged regions after
the one-row offset; print areas and repeated title rows move consistently.
All 16 summary worksheets remain byte-identical. The Tài Tài sample is included.
Apply/rollback round-trip and unknown-source rejection also passed. Raw operational
exports stay outside Git in this chat's artifact directory.
