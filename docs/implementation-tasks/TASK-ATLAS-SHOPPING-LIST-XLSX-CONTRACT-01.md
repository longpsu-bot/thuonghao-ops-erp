# TASK-ATLAS-SHOPPING-LIST-XLSX-CONTRACT-01

## Status and authority

**TASK_STATUS: READY_FOR_PRODUCT_REVIEW.** Proposed V1 contract and redesigned synthetic specimen, not Product approval. Existing Draft PR #347 only; do not merge or implement connected XLSX yet.

PR head before this Product print-rhythm correction: `8652de34bb50e8f4a9b4abc7c4b5580795efac75`. Branch: `design/atlas-shopping-list-xlsx-contract-01`, based on exact fetched `origin/main` `d81b60ca63349794d28b0dcc5d34f5fd3e1ebfa1`. The Product Owner explicitly authorized the real `D:/Project/Repo/OPS/thuonghao-ops-erp` checkout for this continuation. An Excel lock file was found at the first verification; work paused until the operator closed the workbook. Git root, origin, clean starting status, branch and `pnpm ops:workspace` then passed before edits. Other worktrees were not edited.

Allowed paths: this record and `docs/xlsx/` contract, evidence, schema, synthetic fixture, generator/finalizer/validator and one final XLSX. Prohibited: production Shopping List exporter/parser, connected UI, Supabase/RLS/RPC/migrations, Retool, OPS v1, hosted business data, dependencies and unrelated modules.

## Product design decision applied

The supplied `DanhSachMuaHang_2026-04-20_2026-04-25_ALL(1).xlsx` was inspected read-only at SHA256 `88b67577e8a06057c9d61b10ef8aeed9d587ed688733f0b06dbf8f5e54de612e`. Native Excel 16 exported its **right-hand** region to two A4 portrait PDF pages for comparison. The right region has one centered 20 pt Times date, 18 pt Times headings/body, roughly 23.25 pt ordinary rows, bold first School, blank School cells below, black group rules and compact column proportions. The reference's saved print area points at left A:H and its used range reaches row 1,048,575; both are defects.

The original #347 specimen was printed before revision. Its Arial 11 text, dark Atlas header, beige D/E cells, 38/53/8/16/33 widths, 46 pt instructional row, School on every row and landscape composition read as an app export. The subsequent `8652de3` specimen corrected the visual grammar but is now explicitly **rejected Product evidence**: 15 pt universal body, a 39 pt header, a 36 pt title plus 9 pt gap, character-count-driven 29–96 pt rows, supplier-driven height growth, and a 42 pt continuation minimum made baselines uneven. Its 4.45/5 self-score did not detect this defect and is not an acceptance gate.

The print system is now defined once in the schema layout annotation: Times New Roman 18 pt date, 13 pt headings, 14 pt body/School and 12 pt Supplier; title/header heights 29 pt and a 5 pt gap; body classes 24 pt normal, 26 pt School start/continuation, 34 pt deliberate two-line exception, hard maximum 36 pt. Widths A:E are `22 / 39 / 6.5 / 10.5 / 23`. Supplier length never chooses row height. The long School and Ingredient use the explicit two-line class. First School row is bold with a medium rule; later School cells are blank. The first active/effective Supplier appears alone in GHI CHÚ or the cell is blank. Outer and School rules establish hierarchy without tall section rows.

## Specimen and validation evidence

The fixture has 56 entirely synthetic lines over two dates, three Schools and 25 Ingredient identities. The first date has 44 lines: 14 in the first group, five in small Tân Định and 25 in Tân Bình. The five-line group stays together on page 1; Tân Bình starts there and continues on page 2. It covers integer, decimal, six-decimal and zero quantities, long School/Ingredient/Supplier names, one/three eligible Suppliers, inactive Supplier/eligibility, future and expired priority-one relationships, and no Supplier. Every row retains marker, line/revision/decision/date, School/Location/Ingredient/Unit IDs, exact exported quantity, reason and suggestion baseline in hidden F:Q. No business data was copied into Git.

The isolated validator checks the closed schema, exact row set, all row-bound identities, suggestion selection, no alternative-name leak, typography and wrap columns, School labels and rules, hidden columns, Table range, bounded used range, A4 portrait, print area, repeat titles, body-height classes, page budget and continuation breaks. It rejects 30/30 negative controls, including an oversize row and an off-system 25 pt row. A complete-row reorder check proves ID fields stay attached to each line. Independent regeneration produced identical SHA256 `43d07f303d3e7a38729d908ed38d50eb0c757b83ef90fc7a6fa84e23a6f3fac7`; final file size is 15,168 bytes. This is specimen verification, not the future connected importer test suite.

Native Excel 16 opened the final XLSX without a reported repair. D4 quantity and E4 note edits saved to a disposable copy. A deliberate full A:Q Table sort after unprotecting, then SaveCopyAs, changed row order while preserving every visible/hidden tuple for all 44 first-date lines by stable line UUID. The committed specimen was not saved by Excel. Protected sorting remains unavailable by design. Excel reports `ProtectContents=True` and `AllowFiltering=True`, but COM `Range.AutoFilter` rejected a criteria change on the protected Table; the actual dropdown interaction remains a Product/staff check.

Native Excel PDF review: **three A4 portrait pages**, two for 2026-04-20 and one for 2026-04-21. Page 1 has 28 lines, including all five Tân Định lines and nine Tân Bình lines; page 2 starts `Tân Bình (tiếp)` at 26 pt and has the remaining 16 lines; page 3 has the second date's 12 lines. Every page includes its date and five headings. Full-page images and a temporary three-page contact sheet were inspected, then page 1 was compared side-by-side with the preferred right-hand reference. The long School, Ingredient and Supplier strings were recovered in full from their printed PDF columns, and `1,234567` is visible with no `####`. The reference uses larger text; Atlas uses a steadier baseline with clear School boundaries while fitting Supplier suggestions. The partial second and third pages reflect the fixture's remaining/date-specific line counts, not height inflation. Staff note cells remain white and writable. Only A:E prints; F:Q do not. Excel reports print areas `$A$1:$E$47` and `$A$1:$E$15`, title rows `$1:$3`, and bounded used ranges `$A$1:$Q$47` and `$A$1:$Q$15`.

Focused repository checks: `pnpm ui:vnext:check` passed; `pnpm typecheck` passed; the requested Shopping List and precision Vitest invocation reported **5 files / 42 tests passed** at the default timeout when run alone. An initial run concurrent with typecheck had five timeouts; the serial repeat passed without changing thresholds or tests. `pnpm ops:workspace`, affected-file Prettier check and `git diff --check` passed. GitHub Actions owns the routine full frontend workflow on the updated PR.

### Measured print rhythm

| Measure                                                |            Final specimen |
| ------------------------------------------------------ | ------------------------: |
| Normal / School / two-line height                      |           24 / 26 / 34 pt |
| Maximum / distinct body heights                        |                 34 pt / 3 |
| Normal / School / two-line row count                   |                45 / 5 / 6 |
| Single-line-height share                               |             50/56 = 89.3% |
| A4 body budget after repeated rows, margins and footer |                 716.49 pt |
| First date rows / pages                                |                    44 / 2 |
| Rows per page                                          |              28 / 16 / 12 |
| Body-height use per page                               |        716 / 386 / 312 pt |
| Remaining body budget per page                         | 0.49 / 330.49 / 404.49 pt |

The body budget is `841.89 − 72 × (0.35 + 0.35) − 12 − 29 − 5 − 29 = 716.49 pt`. Page 1 leaves just 0.49 pt before its controlled break. The largest remaining area, 404.49 pt on the 12-line second-date sheet, is an input-size remainder; no small-group move creates a large packing gap. Supplier text may occupy two lines inside a 24 pt normal row, but does not promote it to a taller class. The six reported wrapped rows are the deliberately classified 34 pt School/Ingredient exceptions, not an estimate from string length. Product acceptance remains pending; no numeric self-score substitutes for full-page review.

## Security, rollback and remaining decisions

No schema, migration, API, backend privilege, RLS, production importer/exporter or connected UI change. No migration rollback is required. Reverting the proposed contract/specimen is documentation-only. Hidden and protected cells are operator guidance, not security; the future importer must use fresh authorized backend evidence, complete-set/currentness validation and no partial apply. Import applies only to a local draft; explicit `Lưu` remains the sole backend business write.

**FUTURE CONNECTED IMPLEMENTATION REQUIREMENT:** an authorized shaped read must expose the derived first active/effective Supplier at the Confirmed Need export boundary. This PR does not add that read or another preferred-Supplier fact.

Product review remains required for the form, multi-location subgroup wording, protected filter behavior, exact-single-batch/seven-day scope, strict compatibility, local manifest/restart limits, Supplier annotation persistence choice and controlled page-break behavior in connected export. Historical export and multi-daily-batch collection remain separate decisions. Do not merge #347 until product/architecture review and current GitHub Actions pass.

SUPABASE_WRITES: 0. RETOOL_WRITES: 0. OPS_V1_WRITES: 0. HOSTED_BUSINESS_WRITES: 0.
