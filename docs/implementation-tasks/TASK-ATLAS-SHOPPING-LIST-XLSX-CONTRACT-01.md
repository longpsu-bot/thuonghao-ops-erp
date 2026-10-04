# TASK-ATLAS-SHOPPING-LIST-XLSX-CONTRACT-01

## Status and authority

**TASK_STATUS: READY_FOR_PRODUCT_REVIEW.** Proposed V1 contract and redesigned synthetic specimen, not Product approval. Existing Draft PR #347 only; do not merge or implement connected XLSX yet.

PR head before the Product redesign: `df565d2f3b90dcee0f2da222c8cca2101d3a5f73`. Branch: `design/atlas-shopping-list-xlsx-contract-01`, based on exact fetched `origin/main` `d81b60ca63349794d28b0dcc5d34f5fd3e1ebfa1`. The Product Owner explicitly authorized the real `D:/Project/Repo/OPS/thuonghao-ops-erp` checkout for this continuation. Git root, origin, clean starting status, branch and `pnpm ops:workspace` passed before edits. Other worktrees were not edited.

Allowed paths: this record and `docs/xlsx/` contract, evidence, schema, synthetic fixture, generator/finalizer/validator and one final XLSX. Prohibited: production Shopping List exporter/parser, connected UI, Supabase/RLS/RPC/migrations, Retool, OPS v1, hosted business data, dependencies and unrelated modules.

## Product design decision applied

The supplied `DanhSachMuaHang_2026-04-20_2026-04-25_ALL(1).xlsx` was inspected read-only at SHA256 `88b67577e8a06057c9d61b10ef8aeed9d587ed688733f0b06dbf8f5e54de612e`. Native Excel 16 exported its **right-hand** region to two A4 portrait PDF pages for comparison. The right region has one centered 20 pt Times date, 18 pt Times headings/body, roughly 23.25 pt ordinary rows, bold first School, blank School cells below, black group rules and compact column proportions. The reference's saved print area points at left A:H and its used range reaches row 1,048,575; both are defects.

The original #347 specimen was printed before revision. Its Arial 11 text, dark Atlas header, beige D/E cells, 38/53/8/16/33 widths, 46 pt instructional row, School on every row and landscape composition read as an app export and made School text dominate scanning. It retained valuable technical identity and exact-quantity safeguards.

The revised form uses Times New Roman 20 pt title, 15 pt headings/body, white paper, black text/rules, a 39 pt heading row, 29 pt ordinary rows and measured wrapping expansion. Supplier rows gain extra height for handwritten notes. Widths A:E are `17.5 / 35 / 7.5 / 13 / 20`. First School row is bold with a medium rule; later School cells are blank. A long School row expands to 96 pt; the continuation row says `Tân Bình (tiếp)` and retains the height needed by its supplier text. Only the first active/effective Supplier by authoritative priority appears in GHI CHÚ, with no prefix or alternatives. No valid Supplier gives a blank cell. A4 portrait print area is the exact A:E staff table and date/headings repeat on every page.

## Specimen and validation evidence

The fixture has 56 entirely synthetic lines over two dates, three Schools and 25 Ingredient identities. The first date has a 14-line medium group, a five-line small group moved to the next page, and a 25-line oversized group that spans pages. It covers integer, decimal, six-decimal and zero quantities, long School/Ingredient/Supplier names, one/three eligible Suppliers, inactive Supplier/eligibility, future and expired priority-one relationship, and no Supplier. Every row retains marker, line/revision/decision/date, School/Location/Ingredient/Unit IDs, exact exported quantity, reason and suggestion baseline in hidden F:Q. No business data was copied into Git.

The isolated validator checks the closed schema, exact row set, all row-bound identities, suggestion selection, no alternative-name leak, Times/black/white styling, School labels and rules, hidden columns, Table range, bounded used range, A4 portrait, print area, repeat titles and continuation breaks. It rejects 28/28 negative controls. A complete-row reorder check proves ID fields stay attached to each line. Independent regeneration produced identical SHA256 `28055a41a740d615ee7041a1e34543f8b8a5e36074c83bcd6a89816ed3e96b84`; final file size is 14,844 bytes. This is specimen verification, not the future connected importer test suite.

Native Excel 16 opened the final XLSX without a reported repair. D4 quantity and E4 note edits saved to a disposable copy. A deliberate full A:Q Table sort after unprotecting, then SaveCopyAs, changed row order while preserving every visible/hidden tuple for all 44 first-date lines by stable line UUID. The committed specimen was not saved by Excel. Protected sorting remains unavailable by design. Excel reports `ProtectContents=True` and `AllowFiltering=True`, but COM `Range.AutoFilter` rejected a criteria change on the protected Table; the actual dropdown interaction remains a Product/staff check.

Native Excel PDF review: **four A4 portrait pages**, three for 2026-04-20 and one for 2026-04-21. Page 1 has only the long-name medium School; page 2 starts with the intact small Tân Định group and then Tân Bình; page 3 starts `Tân Bình (tiếp)`; page 4 has the second date's two Schools. Every page includes its date and five headings. Long School/Ingredient/Supplier text wraps without overlap after the second design pass; `1,234567` is visible with no `####`. Staff note cells remain white and writable. Only A:E prints; F:Q do not. Excel reports print areas `$A$1:$E$47` and `$A$1:$E$15`, title rows `$1:$3`, and bounded used ranges `$A$1:$Q$47` and `$A$1:$Q$15`. The file size is small and open/scroll performance was normal.

Focused repository checks: `pnpm ui:vnext:check` passed; `pnpm typecheck` passed; the requested Shopping List and precision Vitest invocation reported **5 files / 42 tests passed**; `pnpm ops:workspace`, affected-file Prettier check and `git diff --check` passed. GitHub Actions owns the routine full frontend workflow on the updated PR.

### Visual self-review

| Criterion                | Score / 5 | Rationale                                                    |
| ------------------------ | --------: | ------------------------------------------------------------ |
| Date/title hierarchy     |         5 | Quiet centered date on every page.                           |
| Column-header hierarchy  |         4 | Strong black rules; full SỐ LƯỢNG wraps cleanly.             |
| School-group readability |         5 | Bold first label, blank continuation cells, strong boundary. |
| Ingredient scanning      |         5 | Widest data column and compact School/Unit/Quantity columns. |
| Quantity readability     |         4 | Six-decimal quantity visible and right aligned.              |
| Handwriting space        |         4 | 29 pt ordinary rows, expandable white note cells.            |
| Supplier suggestion      |         4 | One name, no prefix or alternatives, long name wraps.        |
| Page density             |         4 | Small group moves intact without half-page waste.            |
| Continuation clarity     |         5 | Repeated date/headings and explicit Tân Bình (tiếp).         |
| Monochrome quality       |         5 | Black text/rules on white with zero color semantics.         |
| Professional finish      |         4 | Restrained operational form, no UI tint/instruction band.    |

Average: **4.45 / 5**; no criterion below 4. This is a self-review, not Product acceptance.

## Security, rollback and remaining decisions

No schema, migration, API, backend privilege, RLS, production importer/exporter or connected UI change. No migration rollback is required. Reverting the proposed contract/specimen is documentation-only. Hidden and protected cells are operator guidance, not security; the future importer must use fresh authorized backend evidence, complete-set/currentness validation and no partial apply. Import applies only to a local draft; explicit `Lưu` remains the sole backend business write.

**FUTURE CONNECTED IMPLEMENTATION REQUIREMENT:** an authorized shaped read must expose the derived first active/effective Supplier at the Confirmed Need export boundary. This PR does not add that read or another preferred-Supplier fact.

Product review remains required for the form, multi-location subgroup wording, protected filter behavior, exact-single-batch/seven-day scope, strict compatibility, local manifest/restart limits, Supplier annotation persistence choice and controlled page-break behavior in connected export. Historical export and multi-daily-batch collection remain separate decisions. Do not merge #347 until product/architecture review and current GitHub Actions pass.

SUPABASE_WRITES: 0. RETOOL_WRITES: 0. OPS_V1_WRITES: 0. HOSTED_BUSINESS_WRITES: 0.
