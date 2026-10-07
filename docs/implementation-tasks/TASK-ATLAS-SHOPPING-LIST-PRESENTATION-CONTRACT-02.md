# ATLAS-SHOPPING-LIST-PRESENTATION-CONTRACT-02

Date: 2026-10-07. Starting SHA: `5116dffe2482641970ace0874ddfc8fb3992a13d`.
Base main: `cffb17189b11e861c5d7dff6e761335940e46a45`.
Continue branch `fix/atlas-shopping-list-unit-display-01`, Draft [PR #355](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/355). No new PR or automatic merge.

## Approved boundary and implementation sequence

Owner approval authorizes the School-band structure and three provisional geometry specimens. It does not approve final geometry or business freeze. Allowed files are the existing Shopping List codec, layout, contract/schema, focused tests, certification scripts and affected documents. No frontend redesign, module/API/business-rule change, dependency, migration, schema/data write, Retool or live OPS change is permitted.

- [x] Verify canonical checkout, clean tree, origin, branch/head/base and workspace check.
- [x] Read current contract/history, trace export/package/import/service and all layout callers.
- [x] Add failing V2/School-band/hidden School-name regressions, implement the structural amendment, preserve the existing Unit resolver and exact quantity/local proposal path.
- [x] Read the actual authorized Staging export for 2026-09-17 in a read-only transaction: 248 lines, 20 Schools, version 3, complete offset-zero page, Supplier advice. No synthetic substitution.
- [x] Generate A/B/C with the production codec, inspect complete flat identities, test unchanged and changed quantity imports, and native Excel normal Open/SaveAs/reopen.
- [x] Normalize/inspect all native PDFs as A4, compare representative pages and hidden-column records.
- [x] Run the requested local checks and independent review. Push this bounded amendment on the existing branch; exact-head Frontend CI remains mandatory and its result is recorded in PR checks.
- [x] Prepare all seven artifacts for Owner selection; remain Draft, freeze recommendation HOLD.
- [ ] Owner chooses final geometry; final hosted acceptance is a subsequent task.

## Contract ruling

The prior V1 spec describes a fixed Table/envelope and the importer compares `contract_version` exactly. There is no governance rule permitting a structural amendment to silently reuse V1. This task therefore uses **ATLAS_SHOPPING_LIST_V2**, rejects V1, and keeps `legacyAccepted=false`. The existing schema/spec/evidence paths are retained for document continuity; their current amendment is V2. The old V1 example/fixture remains historical and must be re-exported for import.

Business contract is unchanged: saved authoritative Confirmed Need basis, stable IDs and lineage, exact quantities, complete-workbook/currentness validation, local proposals only, explicit operator Save. The existing backend export read/API remains callable without a backend contract or migration change; workbook V2 is its presentation/import artifact version.

Presentation changes: rows 1–3 frozen, global row-3 headings retained, separate SCHOOL_BAND/ DATA_LINE rows, no merged Table cells, DATA_LINE A blank, repeated hidden School ID/Name, neutral dominant bands, explicit continuation bands at generated page starts. P/Q append `__row_kind`/`__school_name`; F:O retain their identities. Canonical School ID is identity; changed ID fails `STALE_IDENTITY`, changed name fails `REFERENCE_CHANGED`.

## Geometry and tests

A/B/C retain the same Times New Roman sizes, 96% print scale, A4 portrait print area A:E, headers `TRƯỜNG | THÀNH PHẦN | ĐVT | SỐ LƯỢNG | GHI CHÚ`, no row striping. Widths redistribute old School space into Ingredient, Unit and Note. A has the tightest rows; B balances row height and text clearance; C adds Ingredient/Unit clearance and handwriting height. The fixed page width means C trades some Note width for those gains; comparison reports that trade explicitly. `SỐ LƯỢNG` fits all candidates; recommendation is to retain it, with no silent switch to SL.

`PRINT_OVERFLOW` remains a presentation guard derived from usable candidate widths and bounded row heights. The previous 35.5 pt and combined 84-character assumptions are superseded, not business invariants. All eight real Units remain unchanged. No per-Unit mapping or abbreviation exists.

Protection remains: band/reference/evidence cells locked, DATA_LINE D/E editable, protected sort disabled. The established public-password unprotect/unhide/copy/reprotect workflow is used for technical-column inspection; no permission/security boundary relies on workbook protection. Quantity-only imports never import GHI CHÚ.

Focused checks cover V2 metadata/Table structure, frozen/print headers, band styling, 248-row production specimens, deterministic continuations, flat data, tamper cases, Unit resolver, precision, whole-workbook atomic import, stale versions and zero command calls. ExcelJS's reader drops manual breaks on rewrite; the isolated QA edit restores the exported break IDs. Production import fails closed when breaks/continuations do not match. Native Excel preservation is verified separately.

## Verification evidence

- Five exact Shopping List suites: **111 tests PASS**, including XLSX/package/import, precision, service, V2 conformance and School-band cases. Band ID retargeting to another existing School returns `STALE_IDENTITY`, using the following authoritative business line rather than a name as the identity check.
- UI boundary, typecheck, build, workspace and whitespace checks pass. Build retains existing chunk-size/static ExcelJS import warnings.
- Local full-suite attempts on Windows stalled without completed test output, including the retry with default dependency directories and ignored `.superpowers` snapshots excluded. No local full-suite PASS is claimed and no tracked test or CI setting was changed. GitHub's full Frontend CI on the final head is the required certification gate.
- Native Excel A/B/C normal Open, isolated SaveAs/reopen, unhide/flat-copy and changed-quantity import pass. The production artifacts remain unchanged by native save.
- A/B/C PDFs: **12/13/15 pages**, **20** initial School bands each, **6/9/10** continuations, **1** wrapped Ingredient row and **32** wrapped DATA_LINE rows each, **0** wrapped bands. All **248** data rows reconcile; physical A4/content/bounds checks pass with no clipping or cropping.
- Independent code/architecture/Ponytail review found one overstrict unused-continuation width guard. A failing regression reproduced it; the exporter now measures only actual emitted band labels. The reviewer confirmed no remaining Important or Critical findings.
- Recommendation B is provisional; the evidence/spec/comparison explicitly disclose B/C's final two-line continuation page. `SỐ LƯỢNG` remains the recommended header. No row striping, per-Unit map, new XLSX abstraction or duplicate grouping planner.

## Safety and rollback

New Supabase migrations, hosted schema changes, business writes, Retool changes and live OPS changes: **0**. Staging remains 92 migrations, tip `20261006112515_atlas_recipe_purchase_unit_read`. No Save, Preview, release or business command is invoked during specimen generation/import.

Rollback is a frontend/codec/document revert with no database rollback. V2 files require the matching V2 importer; rolling back requires re-export, not accidental legacy acceptance. Final geometry, hosted export/import acceptance and Owner final print review remain open. Planning/Procurement freeze recommendation: **HOLD**.
