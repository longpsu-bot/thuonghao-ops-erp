# Atlas Confirmed Need — Phiếu đi chợ XLSX V1

**Status: READY_FOR_PRODUCT_REVIEW — proposed contract, not Product approval.**
Task: `ATLAS-SHOPPING-LIST-XLSX-CONTRACT-01`.
Baseline: `d81b60ca63349794d28b0dcc5d34f5fd3e1ebfa1` (PR #345).
Format: `ATLAS_SHOPPING_LIST_V1`.

This is the single proposed human-readable format contract. The [schema](atlas-shopping-list-xlsx-v1.schema.json), [specimen](examples/atlas-shopping-list-v1-example.xlsx), [source comparison](atlas-shopping-list-xlsx-v1-evidence.md), and [task record](../implementation-tasks/TASK-ATLAS-SHOPPING-LIST-XLSX-CONTRACT-01.md) accompany it. No production module consumes these files. Approval and a separate bounded implementation task are required before changing connected behavior.

## 1. Authority and boundary

Apply current main, [ARCH-002 / OPS_SYSTEM_MAP v1.0](../architecture/arch-002-atlas-system-map.md), [Atlas model convergence](../decisions/decision-atlas-model-convergence.md), [RMVP-05](../api/rmvp-05-connected-confirmed-need-review.md), its AUD-003 amendment, [D-037 Save v2](../api/confirmed-need-save-release-v2.md), and the [Atlas design language](../ui/atlas-vnext-design-language-v1.md). [D-041](../decisions/decision-register.md) preserves historical multi-day chains while new generation is exact-day. Retool and the attachment are workflow/layout evidence only.

**FACTS EXPLICIT — STATE DERIVED — SUPPORTING OBJECTS GENERATED.**

The XLSX is a generated operator artifact. It cannot create or retarget a School, Ingredient, controlled Unit, Need, Delivery Location, policy, lifecycle, or confirmed backend fact. Hidden evidence is an assertion to validate, not authority. Local draft changes are proposals; the existing authoritative `Lưu` command rechecks permission, currentness, exact quantities, policy, reasons and optimistic concurrency.

```text
Complete saved/current daily Confirmed Need facts (1–7 dates; no unsaved local draft)
→ generate one workbook
→ edit SỐ LƯỢNG; use GHI CHÚ as working paper
→ reopen Atlas at any time and validate the whole workbook against fresh daily authority
→ apply accepted quantity changes to the local Confirmed Need draft
→ explicit Lưu
→ existing transactional backend command
```

Import performs **zero business writes**. No automatic Save, release, generation, supplier selection or downstream command follows import.

`GHI CHÚ` starts with derived first-preferred Supplier advice and remains paper/spreadsheet working space. Atlas V1 never imports or persists it. It is neither Supplier allocation nor the governed Confirmed Need reason note.

## 2. Scope and physical layout (questions 6.1–6.6)

### Scope

One workbook is a **generated collection of 1–7 service dates**. Each date has exactly one worksheet and its own authoritative Confirmed Need batch; the dates and batch IDs need not share a weekly Planning object. Dates ascend; `_ATLAS_META` is last and very hidden. Represented dates may be nonconsecutive, but each has current lines and a complete daily batch. The limit is seven **represented service dates**, not a new Planning calendar-span policy. There are no empty, summary, omitted-data or extra user sheets.

The workbook creates no weekly Confirmed Need batch, weekly Planning aggregate, persisted lifecycle object or cross-date transaction. It only collects existing daily facts. All pages of each daily authorized read must be loaded consistently and reconcile to that day's authoritative total. Inconsistent versions during pagination block export/import. Never export only searched, checked, selected-school or visible rows.

Export uses saved/current authoritative facts only. If the workbench has an unsaved local draft, block Export with a clear instruction to `Lưu` or discard/reload before exporting. The XLSX never captures an unsaved React draft. Export eligibility is checked for every represented daily batch; if any date is ineligible, block the complete collection.

Worksheet name: exact ISO date `YYYY-MM-DD`; date is also bound per row. Excel names and table names must be unique. File name: `PhieuDiCho_YYYY-MM-DD_YYYY-MM-DD_ATLAS_V1.xlsx`. A file rename has no import significance. The committed review filename is deliberately `atlas-shopping-list-v1-example.xlsx`.

### Row grain and location comprehension

One data row is one current stable Confirmed Need line, identified by its stable UUID. Its operational grain is batch + service date + School + Delivery Location + Ingredient + controlled Unit (Customer lineage stays in Atlas). Two identical Ingredient display names must not collapse. Distinct locations, Units or Ingredient UUIDs remain distinct even if visible labels coincide. No subtotals, spacer rows, School-band rows, `X` markers or merged cells occur inside the Table.

Within each contiguous School group, print the canonical School name in the first row and leave subsequent School cells blank. Do not merge data cells. A medium black top rule and bold School name mark each new group. If a group spans printed pages, the first row of each continuation page prints `<School> (tiếp)`; for a School with multiple Delivery Locations on that date it also prints the subordinate `Điểm giao: <canonical location name>` line. Following rows on that page are blank again. These labels and borders are presentation only. Every row carries independent hidden School, Delivery Location, Ingredient, Unit and stable line identity. A complete-Table sort can change visual grouping without changing import mapping.

When a School has more than one Delivery Location on the same date, keep each location contiguous and use a separate visual subgroup. Its first `TRƯỜNG` cell contains the canonical School name, a newline, and `Điểm giao: <canonical location name>`; following cells in that subgroup are blank. With one location, show only the School name. Hidden location ID remains on every row. Duplicate canonical location names within that School/date make this five-column export ambiguous and block export pending master-data correction or a separately approved display amendment. Do not silently label using an identifier or aggregate the locations.

After applying that location presentation, distinct lines on the same date must have distinct visible `(TRƯỜNG, THÀNH PHẦN, ĐVT)` tuples. If different Ingredient/School/Unit identities still produce the same tuple, **block export**, never merge rows or invent a technical code. The current authorized read has no operator-facing Ingredient code to disambiguate them. Product/master-data review must provide a meaningful canonical display distinction through a separately approved change before those lines are exportable. Identical Ingredient names across visibly distinct Schools/locations are allowed and retain their stable identities. The specimen uses distinguishable labels; the isolated validator includes an ambiguous-label negative control.

### Visible columns

| Column | Exact label | Value                                                                                                    | Editable?          |
| ------ | ----------- | -------------------------------------------------------------------------------------------------------- | ------------------ |
| A      | TRƯỜNG      | First-row School / blank continuation / print-only `(tiếp)` label; location suffix only as defined above | No                 |
| B      | THÀNH PHẦN  | Canonical Ingredient name                                                                                | No                 |
| C      | ĐVT         | Controlled Unit code                                                                                     | No                 |
| D      | SỐ LƯỢNG    | Exact current local draft quantity                                                                       | Yes                |
| E      | GHI CHÚ     | First eligible preferred Supplier name at export, or blank; staff working space; never imported          | Working paper only |

Choose **SỐ LƯỢNG**, not `SL`, for clarity. `THÀNH PHẦN` and `ĐVT` retain staff vocabulary. All normal operator headings, help and errors are Vietnamese. Technical hidden keys are exempt. No additional operator-editable column is legitimate in this bounded artifact; reason type, identity, policy and status stay in Atlas.

### Deterministic export order

1. `service_date` ascending.
2. Canonical School display order, if supplied through an authorized reference/read.
3. Original complete Confirmed Need source sequence within that School/date.
4. Stable line UUID for any remaining tie.

Capture source sequence before grouping; never derive it from visible row numbers at import. Current RMVP-05 shaped lines do not expose a School display-order field. Until a separately reviewed read supplies it, preserve the complete supplied School first-occurrence order and line order exactly; do not claim that this fallback implements canonical display order or fetch raw legacy data. Missing/tied display ranks preserve that first-occurrence order. Do not introduce a new lexical School sort. The synthetic fixture includes display ranks and deliberately disagrees with lexical order. Import accepts any row order; exporter restores the canonical ordering next time.

## 3. Hidden evidence (questions 6.7–6.9)

### Workbook metadata

`_ATLAS_META` is very hidden and closed. A1:B6 contains six workbook-wide text key/value pairs: `contract_name` = `ATLAS_SHOPPING_LIST`, `contract_version` = `ATLAS_SHOPPING_LIST_V1`, fresh `workbook_marker` UUID, UTC `exported_at`, and ISO `service_period_start` / `service_period_end`. The period is the inclusive collection bound, not a batch period. Marker and timestamp are provenance, never authorization or freshness proof.

A8:E8 contains the exact headers `service_date`, `confirmed_need_batch_id`, `batch_version`, `need_generation_run_id`, `release_snapshot_id`. Rows 9 onward hold one record per date worksheet, ascending and unique. The version is a positive integer serialized as text; the run and release snapshot identify that day's Need Generation source, not Confirmed Need release state. This is **per-date evidence**, never one workbook-level batch/source claim. No extra metadata keys, rows or formulas are accepted. Every date sheet must have exactly one record and vice versa. Import validates all values against fresh authorized reads.

### Row evidence and classification

Hidden F:O are locked text members of the **same Excel Table** as A:E. Each retained field has one purpose:

| Column | Field                 | Purpose                                                                                         |
| ------ | --------------------- | ----------------------------------------------------------------------------------------------- |
| F      | `__workbook_marker`   | Bind every row to the workbook envelope; detect mixed exports.                                  |
| G      | `__line_id`           | Stable Confirmed Need line lookup; detect missing, extra and duplicate rows.                    |
| H      | `__revision_id`       | Detect a changed current revision.                                                              |
| I      | `__decision_id`       | Detect a changed current decision; empty text means null.                                       |
| J      | `__service_date`      | Bind the row to its worksheet and the date's batch record.                                      |
| K      | `__school_id`         | Verify School identity despite blank repeated visible cells.                                    |
| L      | `__location_id`       | Preserve the exact Delivery Location without visible technical codes.                           |
| M      | `__ingredient_id`     | Prevent name-based Ingredient retargeting.                                                      |
| N      | `__unit_id`           | Prevent display-code-based Unit conversion or retargeting.                                      |
| O      | `__exported_quantity` | Exact saved quantity baseline; compare with fresh authoritative quantity before interpreting D. |

The date record supplies batch ID/version/run/snapshot without repeating four fields on every line. Row date, stable line and row-bound IDs link each row unambiguously to that record. Neither hidden cells nor the marker are trusted authority; fresh backend state and Save remain decisive. This unsigned workbook does not cryptographically prove its export history against coordinated technical rewriting; backend authorization and Save checks still apply. Revision/decision numbers, exported reason and exported note are omitted because they add no needed V1 quantity-edit evidence. Lifecycle, policy, step, Supplier and governed reason remain in Atlas.

### Durable reopening

No browser-session manifest, local annotation map, same-session baseline or annotation-only recovery exists in V1. After closing/reloading Atlas, staff may import the same untouched or quantity-edited workbook while **every** daily authoritative fact required for the quantity edit still matches. The importer re-reads complete saved/current daily batches, source lineage, revisions, decisions, identities and quantities. If any represented date changed, reject the complete workbook and instruct the operator to export a fresh `Phiếu đi chợ`. A file-supplied checksum or hidden value is not a substitute for that read. Unsaved local drafts are never treated as exported authority.

### Compatibility

Export writes both fixed format keys to metadata. Import requires those exact values, expected sheets, header labels, full Table range and technical columns. Unsupported future versions, missing metadata, malformed IDs and extra schema fields fail closed with Vietnamese guidance to export a new file.

The current pre-contract marker `ATLAS_CONFIRMED_NEED_SHOPPING_LIST_V1` does **not** identify the proposed V1. It is not accepted by the future V1 parser. Retool workbooks, the supplied side-by-side review workbook, CSV/XLS/XLSM and the superseded `CONFIRMED_NEED_XLSX.v1` concept are not accepted. No label aliases or silent format guessing. Current production behavior is unchanged until a separately approved cutover. Operator migration: finish supported existing drafts or export a fresh V1 workbook; do not upgrade old files in place.

## 4. Table, protection and visual template (questions 6.10–6.11)

Use a real structured Table named `AtlasNeed_YYYYMMDD`, covering **A3:O(last data row)**, including all hidden identities. No totals row; Table filters are present before protection. A visible-only Table would allow sorting names/quantities independently of identities and is forbidden. Table membership does not itself make import safe: verify the actual XML cells and the complete canonical row set, including filtered/hidden data. Reject any nonempty data row outside the expected Table, any extra sheet or a truncated/expanded Table. Trailing empty formatted cells are ignored.

Table benefits: complete-column filter range, full-row sort association, stable formatting and an explicit data boundary. Table risks: automatic row insertion, totals/column changes and protected sorting restrictions. Protection blocks ordinary structural changes; validation rejects them even when protection is removed. No reliance on Excel's visible row number or Table-relative index for identity.

Protect date worksheets with the public operator-safety password `ATLAS_SHOPPING_LIST_V1`. Protect workbook structure against accidental sheet addition/rename/deletion. Lock A:C, F:O, date title/header and all cells outside the data region; unlock only D/E data cells. Allow selecting locked and unlocked cells and expose existing filter controls where Excel permits. Deny formatting, inserting/deleting rows/columns, hyperlinks, objects, scenarios, pivot-table changes and **sorting while protected**.

Excel will not sort a protected range containing locked identity cells even when its `sort` permission flag is set. V1 does not advertise protected sorting. An operator who intentionally unprotects with the disclosed password may sort the **entire Table**; the result is importable if row bindings and complete set remain valid. Do not unlock identities to make sort work. Filtering only hides rows; import reads all rows. Native Excel reports `AllowFiltering=true`, while a COM protected-Table criteria change was rejected. Cross-version protected filtering is **BEST_EFFORT**, not a V1 business guarantee or Product approval blocker. Identity safety never depends on filtering or sorting.

Protection, hidden columns and the very-hidden sheet are **not security mechanisms**. The metadata sheet and workbook structure should be protected as operator guidance; every identity and eligibility check remains outside Excel.

### Print and appearance

The supplied workbook's **right-hand** table is the visual benchmark; its left-hand table is not. Recover its date hierarchy, Times typography, compact five-column proportion, bold first School, blank School continuation cells and strong black separators. Do not copy its gray header fill, wrong A:H print area or accidental A1:Q1048575 used range. This V1 is a white-paper, black-text, black-rule working form; color carries no information. No Atlas green, beige input tint, stripes, logo, instruction block or dashboard treatment appears on the printed area.

- A1:E1 contains only the centered date, for example `Thứ Hai (20/04/2026)`, Times New Roman 20 pt bold in a 32 pt row. Row 2 is a controlled 5 pt gap. Row 3 contains the five exact white/black, centered, 16 pt bold headings in a 33 pt row; first data row is 4. Freeze rows 1:3 and hide gridlines.
- Times New Roman 16 pt is the body and School size; School starts are bold. Supplier suggestions in E are subordinate 14 pt. The bounded body-height system is **29 pt normal / 31 pt School start or continuation / 42 pt explicit two-line exception**, with a hard 44 pt maximum. The synthetic print cases deliberately mark the long School and Ingredient; supplier length never selects row height. Connected export must measure fit or use approved presentation classes, never character-count row growth or silent clipping.
- Visible widths A:E are `26 / 39 / 7 / 11 / 25` Excel character units. The School width keeps the subordinate Delivery Location label on two lines; Ingredient remains widest, Unit/Quantity compact, and Note accommodates the first Supplier plus pen annotation. Wrap only A/B/E; center C, right-align D, left-align E, and vertically center the body. `1,234567` remains visible.
- Ordinary rows use thin black horizontal and column rules. A new School/location subgroup uses a medium black top rule and bold School name at the same bounded baseline. Header top/bottom and the outer form edge are medium black. Avoid decorative fills.
- A4 portrait, fit one page wide with unlimited pages tall; margins `0.28 / 0.28 / 0.35 / 0.35` inches (left/right/top/bottom), minimal header/footer margins, page-number footer. Print area is exactly `A1:E<last-real-row>`; hidden F:O never prints. Repeat rows 1:3 on every page so date and headings remain obvious.
- The explicit page model budgets `841.89 − 72 × (0.35 + 0.35) − 12 footer − 32 title − 5 gap − 33 headings = 709.49 pt` for body rows. Keep groups of up to eight rows together if they cannot fit in the remaining body space. A larger group may begin in the remaining space if at least three rows fit; otherwise move it to the next page. Split at the last whole row that fits. At a within-group break put `<School> (tiếp)` on the first following row, bold and 31 pt unless its Ingredient or the required subordinate multi-location line needs the fixed 42 pt two-line class. The specimen's five-line Tân Định group stays together and Tân Bình spans pages. Excel automatic breaks for other data sizes require the same continuation-label logic in connected implementation.

The committed specimen and native Excel PDF must be reviewed together. Page-break geometry is part of this design contract, not inferred from OOXML assertions alone. Filter state affects printing; clear filters to print all lines.

### Preferred Supplier suggestion

Derive `GHI CHÚ` from existing `atlas_admin.supplier_eligibilities` and `atlas_admin.suppliers` at the line's service date. Require active Supplier and eligibility, inclusive `effective_from`, exclusive optional `effective_to`; order surviving relationships by authoritative ascending priority and use the unique first Supplier's canonical `supplier_name`. Absent, null or tied first priority gives a clean blank suggestion pending authoritative data correction. Display only the name: no `NCC dự kiến:` prefix, alternatives, warning, eligibility status or allocation claim. The fixture covers one/three eligible Suppliers, inactive Supplier/eligibility, future/expired top priority and none. The suggestion is not a saved preference, allocation or Procurement decision. **FUTURE CONNECTED IMPLEMENTATION REQUIREMENT:** expose this derived first Supplier through an authorized shaped read at the Confirmed Need export boundary, without a browser direct-table read or schema/RPC change in this PR.

## 5. Quantity and working-paper rules (questions 6.12–6.13)

Canonical quantity is exact nonnegative decimal text with at most 14 integer and 6 fractional digits (`numeric(20,6)`). Column O preserves the saved exact baseline as text; D displays up to six fractional digits without rounding. Safe values may be numeric XML with exact decimal `<v>` text; values beyond Excel's 15-significant-digit domain must be text. Never establish authority through binary arithmetic. The specimen finalizer writes exact XML decimals. A future importer captures numeric XML before binary conversion and normalizes exponent notation losslessly. Text permits one comma **or** one dot decimal separator; never grouping separators, mixed separators, formulas, dates, percentages, blank, negatives, NaN or infinity. Excel may reinterpret keyboard input before saving; a leading apostrophe forces text entry when needed.

Compare exact decimal coefficients/scales, ignoring trailing fractional zeros. No epsilon, rounding, ceiling or truncation. If D equals current saved quantity, preserve the local draft and entry flag. A genuine quantity edit must have at most two fractional digits (AUD-003) and be an exact multiple of the current effective Planning step. Resolve policy, Unit and source from fresh Atlas authority. `0` is an explicit valid edit when representable; blank is never zero. Backend Save repeats final validation.

Only `SỐ LƯỢNG` may become an imported business proposal. Never import School, Delivery Location, Ingredient, Unit, Supplier, allocation, `GHI CHÚ`, lifecycle/status, reason classification or policy. A changed quantity updates the local Confirmed Need quantity draft under existing RMVP-05 rules. The operator must provide the governed adjustment reason/explanation Atlas requires before `Lưu`; the XLSX neither carries nor recreates that note. `GHI CHÚ` cannot satisfy it. A return to the canonical proposal follows existing reason-normalization behavior; import does not invent a decision kind or bypass Save checks.

`GHI CHÚ` initially shows the first preferred Supplier's name derived at export. Staff may write, type, strike through or annotate it as working paper. Its content is ignored on import and never persisted by Shopping List V1. It is not business authority, Supplier allocation, a Confirmed Need `reason_note` or a Procurement instruction. Supplier allocation remains a Procurement responsibility. Supplier master changes after export do not retarget or invalidate an otherwise current quantity row.

## 6. Validation and whole-workbook application (questions 6.14–6.20)

1. Parse the XLSX safely and validate the exact V1 contract/version, metadata shape, 1–7 date sheets, full Tables, headers and technical columns. Reject formulas and unexpected executable or external parts.
2. Load fresh complete authorized saved/current Confirmed Need state for **every represented date and batch**. Check editability, allowed action, batch ID/version and Need Generation run/release evidence independently for each date. Reconcile complete paginated reads to authoritative totals.
3. Match each row by stable hidden line identity. Verify marker, containing worksheet/date, daily batch, current revision/decision, School, Delivery Location, Ingredient, Unit, exact saved exported quantity and canonical visible reference labels. Require every-and-only current row set for each date. Do not use visible text, position, filters or sorting for lookup.
4. Compare D with current authoritative quantity exactly. Validate real edits against current entry precision and Planning step. Ignore E entirely, including export-time Supplier name drift. If any currentness, structure, identity, precision or policy check fails, reject the **entire workbook** and tell the operator to export a fresh `Phiếu đi chợ` where stale.
5. If a represented date already has an unsaved local Confirmed Need draft, block import with `Lưu` or discard/reload guidance; do not overwrite or merge it with file edits. Otherwise build isolated local quantity-draft proposals for all represented dates. Publish them together only after every check succeeds; perform **no backend write**. Preserve existing drafts on rejection. Guard against the active context or local draft changing during asynchronous parsing/readback; stale in-flight work is discarded or retried. The operator reviews and explicitly `Lưu`s through existing transactional commands.

This is local-draft atomicity, **not** a cross-date database transaction. A stale date 2 rejects current dates 1 and 3 as part of the same workbook. No fuzzy reconciliation or partial application. A workbook exported before a batch is released becomes ineligible after release; governed reopening still requires all current evidence to match. V1 excludes released/history export as an editable workbook. A clean saved state is mandatory for export; an unsaved local draft blocks Export until `Lưu` or discard/reload.

Resource limits: compressed file ≤10 MiB; ≤128 ZIP entries; ≤50 MiB total uncompressed; any XML part ≤20 MiB; ≤10,000 data lines; ≤7 date sheets plus metadata. Reject duplicate ZIP paths, path traversal, encryption, DTD/entities and >200:1 ratios for entries above 1 MiB. Parse ordinary XLSX OPC parts only; reject macros, external links, OLE/embeddings, ActiveX, controls, custom XML, drawings/images, signatures and unexpected parts. Native printer settings and standard calcChain may be present, but no formula is evaluated. Never truncate an oversized daily set to fit limits.

## 7. Acceptance matrix

These are future connected V1 requirements. The isolated specimen validator models the multi-date identity/currentness outcomes; production behavior is not implemented by this PR. All accepted imports write **local draft only**; backend writes happen only on later explicit `Lưu`.

| Case                                                                                      | V1 result                                                                                           |
| ----------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| Export from clean saved/current 1–7 daily batches                                         | Complete workbook, one date sheet and per-date authority record for each selected date.             |
| Export with unsaved local workbench draft                                                 | Block with instruction to `Lưu` or discard/reload first.                                            |
| Import unchanged workbook after browser restart                                           | Accept with no Atlas draft change if all daily facts are current; no manifest needed.               |
| Import valid quantity edit after browser restart                                          | Accept local quantity proposal only; governed reason/explanation still required before `Lưu`.       |
| Import while a represented date has an unsaved local draft                                | Block with `Lưu` or discard/reload guidance; preserve the draft.                                    |
| Three dates current/current/current                                                       | Accept whole workbook.                                                                              |
| Three dates current/stale/current                                                         | Reject whole workbook; no draft changes; export fresh.                                              |
| Wrong batch identity for one date                                                         | Reject whole workbook.                                                                              |
| Wrong revision or decision for one row                                                    | Reject whole workbook.                                                                              |
| Missing daily sheet or extra daily sheet                                                  | Reject whole workbook.                                                                              |
| Missing row, duplicate row or extra row                                                   | Reject whole workbook; no inferred zero or new Need.                                                |
| Row moved to another date sheet                                                           | Reject whole workbook despite intact hidden line ID.                                                |
| Complete-row Table sorting                                                                | Accept if every visible/hidden binding and row set remains intact; protected sort is unavailable.   |
| Edit `GHI CHÚ` only                                                                       | Accept; **no Atlas draft change** and no persisted note.                                            |
| Edit printed Supplier name only                                                           | Accept; no Atlas draft change or allocation. Supplier projection drift alone never stales quantity. |
| Edit quantity only                                                                        | Accept local quantity draft only if exact entry/step/currentness checks pass.                       |
| Edit quantity plus `GHI CHÚ`                                                              | Same local quantity draft as if `GHI CHÚ` were untouched.                                           |
| Tamper visible School, Ingredient or Unit, hidden identity, exported baseline or metadata | Reject whole workbook.                                                                              |
| Invalid precision, Planning step, numeric XML or formula                                  | Reject whole workbook.                                                                              |
| Released/unauthorized batch, mixed export markers or obsolete version                     | Reject whole workbook.                                                                              |
| Filter rows without deleting them                                                         | Accept if complete Table data remains; filtering is best effort.                                    |
| Old Atlas or Retool workbook                                                              | Reject as V1; export a fresh V1 file.                                                               |

## 8. Decision index

| Concern          | Frozen V1 decision                                                                                                                  |
| ---------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| Scope            | Generated 1–7 date collection; each worksheet binds to its own authoritative daily Confirmed Need batch.                            |
| Authority        | Saved/current daily facts only; no weekly batch, aggregate, lifecycle object or cross-date command.                                 |
| Metadata         | Six workbook-wide fields plus exact per-date batch/version/run/snapshot table.                                                      |
| Row identity     | F:O marker, stable line, revision, decision, date, School, Location, Ingredient, Unit, exact quantity baseline.                     |
| Import           | SỐ LƯỢNG only; fresh complete read after restart; no browser manifest; whole workbook or no local changes.                          |
| GHI CHÚ          | Export-time first Supplier name plus working space; never imported/persisted.                                                       |
| Reason           | Governed adjustment explanation entered in Atlas before explicit Save.                                                              |
| Location display | One location: School only; multiple: School then subordinate `Điểm giao: <Tên điểm giao>`; ambiguous canonical labels block export. |
| Filtering        | Protected filter controls best effort; identity independent of filters/sorting.                                                     |
| Print            | Calibrated 29/31/42 pt rows, ≤44 pt cap, widths `26/39/7/11/25`; black rules and A4 composition retained.                           |

## 9. Specimen, reproduction and review gate

[Specimen](examples/atlas-shopping-list-v1-example.xlsx): three dates and three **distinct daily batch IDs**, 59 synthetic lines, three Schools and 25 Ingredient identities. The first two date sheets preserve the accepted 44-line/12-line print cases, including `Tân Bình (tiếp)`; the third date has three lines for multi-date currentness tests. It includes integer, decimal, six-decimal and zero quantities, long School/Ingredient/Supplier names and active/effective Supplier selection cases. The hidden Table is F:O, and `_ATLAS_META` contains six global fields plus three per-date records. All data is synthetic. The validator checks every-and-only rows, exact authority bindings, note-ignored quantity outcomes, multi-date stale/wrong-batch/missing/extra/transplant rejection and the retained print-layout validators.

The deterministic binary, fixture, generator, finalizer and validator are design evidence only. No production module consumes them. The builder uses the bundled `@oai/artifact-tool`; the standard-library Python finalizer supplies native hiding, protection, exact XML decimals and print configuration. No repository dependency or backend object is added. Reproduce from the repository root with the bundled Node/Python paths returned by `load_workspace_dependencies`:

```powershell
$taskPython = 'C:/Users/hp/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
$taskNode = 'C:/Users/hp/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node.exe'
$env:ATLAS_ARTIFACT_NODE_MODULES = 'C:/Users/hp/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules'
& $taskPython docs/xlsx/examples/make-fixture.py
& $taskNode docs/xlsx/examples/generate-specimen.mjs docs/xlsx/examples/atlas-shopping-list-v1-example.xlsx
& $taskPython docs/xlsx/examples/finalize-specimen.py
& $taskPython docs/xlsx/examples/validate-specimen.py
```

The print scale was calibrated against native Excel A4 PDFs of the prior specimen and the supplied right-hand staff table. The final synthetic specimen prints four pages with complete long School, Ingredient and Supplier labels, a two-line Delivery Location label and visible `1,234567`; the date/heading repetition, borders and page structure remain. Extreme real names and page breaks are connected-exporter implementation acceptance tests, not open V1 Product decisions. Future connected work may need an authorized shaped read for 1–7 daily batches and preferred Supplier projection; this PR adds no migration, view, RPC or production code. Product approval of this contract/specimen and CI are still required before merging #347; this task keeps it Draft and does not merge.
