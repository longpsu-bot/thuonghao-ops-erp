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
Complete current Atlas batch + local draft
→ export
→ edit SỐ LƯỢNG / GHI CHÚ
→ validate whole workbook against current Atlas and export evidence
→ apply all accepted changes to the local draft
→ explicit Lưu
→ existing transactional backend command
```

Import performs **zero business writes**. No automatic Save, release, generation, supplier selection or downstream command follows import.

**Staff-workflow clarification:** the Product Owner reports that staff note the supplier in `GHI CHÚ` during review. V1 therefore treats this column as a free operator annotation, including a proposed supplier, **separate from the governed Confirmed Need reason note**. The default proposed here asks for an adjustment explanation in Atlas after import. Product still reviews this separation and its lack of backend annotation persistence; no new persisted note object is authorized.

## 2. Scope and physical layout (questions 6.1–6.6)

### Scope

One workbook represents **one complete existing Confirmed Need batch and its exact service period**, not a filtered screen projection. One worksheet represents each service date with at least one current line. Dates ascend; `_ATLAS_META` is last and very hidden. No empty date sheets, summary sheet, hidden omitted data sheet, or extra user sheet is part of V1.

The maximum practical span is **7 inclusive calendar days**. This is an artifact limit proposed for operator review, not a new Planning policy or permission to generate multi-day Need. The current exact-day workbench therefore exports one day. A retained eligible multi-day batch may use several date sheets only if its entire current batch is available and remains editable under existing authority. A 2-date synthetic retained-batch shape is used in the specimen. V1 does not combine unrelated daily batches or create a new weekly aggregate. A collection format would require a separate contract and explicit approval.

All pages of the backend read must be loaded consistently and reconcile to the authoritative total. Inconsistent versions during pagination block export/import. Never export only searched, checked, selected-school or visible rows. A date with zero lines is absent from the sheet set but remains within the exact batch period.

Worksheet name: exact ISO date `YYYY-MM-DD`; date is also bound per row. Excel names and table names must be unique. File name: `PhieuDiCho_YYYY-MM-DD_YYYY-MM-DD_ATLAS_V1.xlsx`. A file rename has no import significance. The committed review filename is deliberately `atlas-shopping-list-v1-example.xlsx`.

### Row grain and location comprehension

One data row is one current stable Confirmed Need line, identified by its stable UUID. Its operational grain is batch + service date + School + Delivery Location + Ingredient + controlled Unit (Customer lineage stays in Atlas). Two identical Ingredient display names must not collapse. Distinct locations, Units or Ingredient UUIDs remain distinct even if visible labels coincide. No subtotals, spacer rows, School-band rows, `X` markers or merged cells occur inside the Table.

School appears **on every line**. This intentionally improves the supplied right-hand first-line-only layout: filtering, copying, page continuation and sorting retain context. A medium top border at the initial School boundary provides separation without an extra row. Borders are presentation; identity never depends on them.

When a School has more than one Delivery Location on the same date, its locked `TRƯỜNG` cell contains the canonical School name, a newline, and `Điểm giao: <canonical location name>` on **every** such row. This makes otherwise identical rows understandable without adding an editable field. With one location, show only the School name. Duplicate canonical location names within that School/date make this five-column export ambiguous and block export pending master-data correction or a separately approved display amendment. Do not silently label using an identifier or aggregate the locations.

After applying that location presentation, distinct lines on the same date must have distinct visible `(TRƯỜNG, THÀNH PHẦN, ĐVT)` tuples. If different Ingredient/School/Unit identities still produce the same tuple, **block export**, never merge rows or invent a technical code. The current authorized read has no operator-facing Ingredient code to disambiguate them. Product/master-data review must provide a meaningful canonical display distinction through a separately approved change before those lines are exportable. Identical Ingredient names across visibly distinct Schools/locations are allowed and retain their stable identities. The specimen uses distinguishable labels; the isolated validator includes an ambiguous-label negative control.

### Visible columns

| Column | Exact label | Value                                                           | Editable? |
| ------ | ----------- | --------------------------------------------------------------- | --------- |
| A      | TRƯỜNG      | Canonical School display; location suffix only as defined above | No        |
| B      | THÀNH PHẦN  | Canonical Ingredient name                                       | No        |
| C      | ĐVT         | Controlled Unit code                                            | No        |
| D      | SỐ LƯỢNG    | Exact current local draft quantity                              | Yes       |
| E      | GHI CHÚ     | Local shopping annotation, including a proposed supplier        | Yes       |

Choose **SỐ LƯỢNG**, not `SL`, for clarity. `THÀNH PHẦN` and `ĐVT` retain staff vocabulary. All normal operator headings, help and errors are Vietnamese. Technical hidden keys are exempt. No additional operator-editable column is legitimate in this bounded artifact; reason type, identity, policy and status stay in Atlas.

### Deterministic export order

1. `service_date` ascending.
2. Canonical School display order, if supplied through an authorized reference/read.
3. Original complete Confirmed Need source sequence within that School/date.
4. Stable line UUID for any remaining tie.

Capture source sequence before grouping; never derive it from visible row numbers at import. Current RMVP-05 shaped lines do not expose a School display-order field. Until a separately reviewed read supplies it, preserve the complete supplied School first-occurrence order and line order exactly; do not claim that this fallback implements canonical display order or fetch raw legacy data. Missing/tied display ranks preserve that first-occurrence order. Do not introduce a new lexical School sort. The synthetic fixture includes display ranks and deliberately disagrees with lexical order. Import accepts any row order; exporter restores the canonical ordering next time.

## 3. Hidden evidence (questions 6.7–6.9)

### Workbook metadata

`_ATLAS_META!A1:B10` is a closed two-column key/value map, each key exactly once, serialized as text. Its state is `veryHidden`, with no formulas or business status/policy. Key order is fixed for export; import may accept reordered keys when the exact closed set and values remain valid.

| Key                     | Required value and use                                                           |
| ----------------------- | -------------------------------------------------------------------------------- |
| contract_name           | Literal `ATLAS_SHOPPING_LIST`                                                    |
| contract_version        | Literal `ATLAS_SHOPPING_LIST_V1`                                                 |
| workbook_marker         | Fresh random UUID per real export; fixed UUID only in the deterministic specimen |
| exported_at             | RFC 3339 UTC timestamp; support evidence, not freshness authority                |
| service_period_start    | Exact batch period start, ISO date                                               |
| service_period_end      | Exact batch period end, ISO date                                                 |
| confirmed_need_batch_id | Exact current aggregate UUID                                                     |
| batch_version           | Positive decimal integer as text; checked against current backend readback       |
| need_generation_run_id  | Exact current source run UUID                                                    |
| release_snapshot_id     | Exact Need Generation release snapshot UUID; not Confirmed Need release state    |

Marker uniqueness binds row sets to the particular exported artifact; it is not a signature or authorization credential. Metadata values never override backend facts. Source and period must be checked independently even if the batch version happens to match.

### Row evidence and classification

Hidden F:Q are members of the **same Excel Table** as A:E. All row evidence cells are locked text, including exact decimal quantity and blank/null decision evidence.

| Current field / concept            | V1 key / destination                               | Classification                       | Reason                                                                          |
| ---------------------------------- | -------------------------------------------------- | ------------------------------------ | ------------------------------------------------------------------------------- |
| Batch ID                           | `confirmed_need_batch_id` in metadata              | REQUIRED, WORKBOOK-LEVEL             | Exact aggregate; row repetition redundant                                       |
| Batch version                      | `batch_version` in metadata                        | REQUIRED, WORKBOOK-LEVEL             | Whole-batch stale detection                                                     |
| Need Generation run                | `need_generation_run_id` in metadata               | REQUIRED, WORKBOOK-LEVEL             | Wrong source detection                                                          |
| Source release snapshot            | `release_snapshot_id` in metadata                  | REQUIRED, WORKBOOK-LEVEL             | Exact source release binding                                                    |
| Stable Confirmed Need line         | `__line_id` (G)                                    | REQUIRED, ROW-LEVEL                  | Mapping, duplicates and missing-set checks                                      |
| Current revision UUID              | `__revision_id` (H)                                | REQUIRED, ROW-LEVEL                  | Stale revision                                                                  |
| Revision number                    | Omitted                                            | REDUNDANT                            | UUID already identifies immutable revision; number remains in Atlas             |
| Current decision UUID/null         | `__decision_id` (I)                                | REQUIRED, ROW-LEVEL                  | Stale decision; empty text means null                                           |
| Decision number                    | Omitted                                            | REDUNDANT                            | UUID/null is sufficient; number remains in Atlas                                |
| Service date                       | `__service_date` (J)                               | REQUIRED, ROW-LEVEL                  | Must match canonical line and containing worksheet                              |
| School UUID                        | `__school_id` (K)                                  | REQUIRED, ROW-LEVEL                  | Validate immutable identity cross-check                                         |
| Delivery Location UUID             | `__location_id` (L)                                | REQUIRED, ROW-LEVEL                  | Preserve distinct operational targets                                           |
| Ingredient UUID                    | `__ingredient_id` (M)                              | REQUIRED, ROW-LEVEL                  | No name-based retargeting                                                       |
| Controlled Unit UUID               | `__unit_id` (N)                                    | REQUIRED, ROW-LEVEL                  | No code-based conversion or retargeting                                         |
| Exact exported quantity            | `__exported_quantity` (O)                          | REQUIRED, ROW-LEVEL                  | AUD-003 equality baseline; never a replacement quantity                         |
| Exported reason code               | `__exported_reason_code` (P)                       | REQUIRED, ROW-LEVEL                  | Preserve original local draft decision meaning                                  |
| Exported shopping annotation (new) | `__exported_note` (Q)                              | REQUIRED, ROW-LEVEL                  | Detect note-only edit and prevent old file overwriting a newer local annotation |
| Old constant workbook marker       | Replaced by format ID plus `__workbook_marker` (F) | REQUIRED, ROW-LEVEL + WORKBOOK-LEVEL | Format and export-instance identity are different concerns                      |
| Lifecycle, H1A policy and step     | Not stored                                         | REDUNDANT as XLSX authority          | Resolve from current Atlas; cannot be edited/imported                           |

School/Ingredient/Unit IDs are derivable from stable line identity but deliberately retained as row-bound cross-checks. They are not alternate lookup keys. Conversely revision/decision numbers add no independent check beyond their UUIDs and current backend bindings.

### Trusted export baseline and reopening

A future exporter must retain an ephemeral in-memory export manifest keyed by marker: metadata, expected complete row IDs, canonical visible labels and each exported local quantity/reason code/governed reason note/shopping annotation. Governed reason notes remain in the existing Atlas draft; they are not replaced by workbook annotations. This manifest and an ancillary annotation map keyed by stable line UUID are local supporting evidence, not persisted business state or supplier allocation. Import compares hidden baselines against the manifest and independently checks every canonical identity against a fresh complete backend read. A workbook-supplied checksum would not make its baseline trustworthy.

When the local export manifest is unavailable (for example after browser restart), **quantity edits cannot be imported**. The workbook does not carry a trustworthy exported governed reason-note/entry-flag baseline, so V1 does not reconstruct the coupled Confirmed Need draft. A narrowly allowed annotation-only recovery requires every visible quantity and O baseline to equal current saved backend/default quantity, P to equal the saved/default reason code, all currentness checks to pass, and every row marker to equal the workbook marker. Preserve the current local quantity, entry flag, reason code and governed explanation exactly. Lost unsaved governed notes/flags cannot be proven from the file and are never restored or treated as a saved baseline. Any differing file quantity/exported quantity/reason rejects the whole import and requires a fresh export from the current session. A future durable export-evidence mechanism would need separate Product/architecture approval.

Atlas has no authoritative supplier-annotation baseline to reconstruct: for this annotation-only recovery, treat each visible `GHI CHÚ` as an explicit free annotation from the selected file, without trusting Q as historical truth. It may populate an empty annotation map or agree with current values; a differing nonempty local annotation rejects the whole import. This permits staff to retain/share supplier notes without inventing backend authority. No new backend token, table, RPC or signing infrastructure is authorized. Coordinated malicious rewrites cannot be authenticated cryptographically in this design; backend authorization and Save validation remain decisive. An unchanged file quantity can never replace a newer current local draft.

### Compatibility

Export writes both fixed format keys to metadata. Import requires those exact values, expected sheets, header labels, full Table range and technical columns. Unsupported future versions, missing metadata, malformed IDs and extra schema fields fail closed with Vietnamese guidance to export a new file.

The current pre-contract marker `ATLAS_CONFIRMED_NEED_SHOPPING_LIST_V1` does **not** identify the proposed V1. It is not accepted by the future V1 parser. Retool workbooks, the supplied side-by-side review workbook, CSV/XLS/XLSM and the superseded `CONFIRMED_NEED_XLSX.v1` concept are not accepted. No label aliases or silent format guessing. Current production behavior is unchanged until a separately approved cutover. Operator migration: finish supported existing drafts or export a fresh V1 workbook; do not upgrade old files in place.

## 4. Table, protection and visual template (questions 6.10–6.11)

Use a real structured Table named `AtlasNeed_YYYYMMDD`, covering **A3:Q(last data row)**, including all hidden identities. No totals row; Table filters are present before protection. A visible-only Table would allow sorting names/quantities independently of identities and is forbidden. Table membership does not itself make import safe: verify the actual XML cells and the complete canonical row set, including filtered/hidden data. Reject any nonempty data row outside the expected Table, any extra sheet or a truncated/expanded Table. Trailing empty formatted cells are ignored.

Table benefits: complete-column filter range, full-row sort association, stable formatting and an explicit data boundary. Table risks: automatic row insertion, totals/column changes and protected sorting restrictions. Protection blocks ordinary structural changes; validation rejects them even when protection is removed. No reliance on Excel's visible row number or Table-relative index for identity.

Protect date worksheets with the public operator-safety password `ATLAS_SHOPPING_LIST_V1`. Protect workbook structure against accidental sheet addition/rename/deletion. Lock A:C, F:Q, title/help/header and all cells outside the data region; unlock only D/E data cells. Allow selecting locked and unlocked cells and using existing filters. Deny formatting, inserting/deleting rows/columns, hyperlinks, objects, scenarios, pivot-table changes and **sorting while protected**.

Excel will not sort a protected range containing locked identity cells even when its `sort` permission flag is set. V1 therefore does not advertise protected sorting. An operator who intentionally unprotects with the disclosed password may sort the **entire Table**; the resulting workbook is importable if all evidence remains bound correctly. Do not unlock identities to make sort work. Import does not require the protection flag to survive another editor; it validates content independently. Filtering that merely hides rows is valid; deleting filtered rows or importing a visible-only copy is incomplete and rejected. Microsoft's [worksheet protection guidance](https://support.microsoft.com/en-au/excel/protect-a-worksheet?nochrome=true) distinguishes changing existing filter criteria from creating/removing AutoFilter and confirms the locked-cell sort limitation. Native Excel reports `AllowFiltering=true` for this specimen, but the COM `Range.AutoFilter` command was rejected on its protected Table; staff dropdown filtering is an explicit Product review check. Do not claim this COM check proves protected filtering works or unlock identity/header cells to hide that limitation.

Protection, hidden columns and the very-hidden sheet are **not security mechanisms**. The metadata sheet and workbook structure should be protected as operator guidance; every identity and eligibility check remains outside Excel.

### Print and appearance

Preserve the right-hand reference's continuous table. Use a restrained Soft Mineral translation: white paper, eucalyptus header `#35564C`, dark text `#2A3330`, subtle horizontal rules `#DCE4E0`, medium School-start rule `#567A71`, pale amber editable cells `#F8F1DF`. No decorative summaries, logos, School banners, macros, VBA or conditional business calculations.

- A1:E1 merged date/title only, outside Table: `PHIẾU ĐI CHỢ · Thứ Hai (20/04/2026)`.
- A2:E2 compact Vietnamese editing/persistence instruction in 9-point Arial over three lines; explicitly states GHI CHÚ stays in the file/session and Atlas Lưu does not persist it, plus text-entry instructions for large/comma quantities and a warning to keep the exporting Atlas session open for quantity edits. Specimen identifies itself as `Mẫu minh họa`.
- Row 3 headers, first data row 4; freeze first three rows; gridlines hidden.
- Arial 11 body/header and 17 title for ordinary staff Excel compatibility. This intentionally replaces the current 18-point Times New Roman body for more usable notes and six-decimal quantities.
- Column widths A:E: `38 / 53 / 8 / 16 / 33` Excel character units. Wrap School, Ingredient and note; right-align quantities; center Unit. Increase height when needed; no shrink-to-fit. Specimen data rows are 34 points.
- A4 landscape, fit to one page wide and unlimited pages tall; margins `0.25 / 0.25 / 0.4 / 0.4` inches (left/right/top/bottom); print area A1:E(last row), repeated rows 1:3, page-number footer.
- Prefer page breaks at School boundaries when a whole group fits; large groups may continue across pages with repeated headers and School on every row. No one-page-high compression. Filter state affects Excel printing, so clear filters when printing all lines.

The committed specimen has explicit School-boundary page breaks and native print configuration. Automated range renders and OOXML inspection are evidence; staff Excel print preview, filter/edit and full-Table sorting remain part of Product review, not claimed native-Excel certification.

## 5. Quantity and note rules (questions 6.12–6.13)

Canonical domain quantity: exact nonnegative decimal text, at most 14 integer and 6 fractional digits (`numeric(20,6)`). Preserve original exact exported baseline in O as text. Display up to six fractional digits, no imposed rounding. Numeric cells use invariant `0.######` (integer cells may use `0` to avoid a dangling decimal separator in renderers). Excel's locale decides the displayed decimal separator.

For values safely within Excel's 15-significant-digit numeric domain, the writer may serialize the exact canonical decimal directly into numeric cell XML. Do not establish authority through binary arithmetic. Values outside that safe domain must be text cells preserving exact digits, right-aligned; the quantity column width must grow if required. The specimen finalizer writes exact `<v>` decimal text directly and never calculates a quantity via `float`/`Number`. Its hidden quantity is always text.

Excel may interpret keyboard input using workstation locale **before saving XML**: on some installations typing `1,234` in a numeric cell can become `1234`. V1 cannot recover that typing intent. The comma/dot grammar below applies to text cells; numeric cells mean the decimal actually stored in XML. Never use grouping separators. To guarantee comma/dot text parsing or preserve an entry above 15 significant digits, enter a leading apostrophe (for example `'1,25`) or use the cell already exported as text. The apostrophe is Excel's text-entry prefix, not part of the saved value. Unsafe-domain exported quantities must also have text format `@` so replacement typing remains text. A large new quantity with 14 integer and 2 fractional digits must be entered as text; a numeric value already rounded by Excel cannot reliably reveal lost digits. Reject numeric XML evidence above 15 significant digits rather than claim Excel preserves it; backend entry rules still apply to every accepted exact value. Staff locale behavior and these entry instructions require Product review.

Importer captures numeric XML decimal text **before** binary conversion. Normalize numeric source exponent notation losslessly to ordinary decimal when needed; the resulting value must remain within the canonical domain. Operator text accepts one comma **or** one dot as decimal separator: `1,25` and `1.25` mean the same quantity. Trim outer whitespace. No thousands separators, mixed separators (`1.234,56`), internal whitespace, percentages, fraction/date cells, boolean/error values, formula results, NaN or infinity. Text scientific notation is rejected. Text `1,234` means the decimal 1.234, not 1234; a real edit with three decimals fails the current operator-entry rule. Blank is invalid, never zero.

Compare decimals using integer coefficients/scales or exact strings, with trailing fractional zeros ignored for equality. **No epsilon, binary floating-point authority, rounding, ceiling or truncation.** An unchanged six-decimal quantity is export evidence, not a new entry. Preserve the current local draft quantity and `quantity_entered` flag; do not replay the file baseline over it.

A genuine quantity edit must satisfy **both** the retained AUD-003 maximum two fractional digits for new operator entries and exact representability as an integer multiple of the line's current effective Planning step. No workbook policy/step is imported. Missing/ambiguous policy, inactive Unit, stale source, or nonrepresentability blocks the entire apply. The backend remains the final authority and repeats all checks at explicit Save. `0` is valid when explicit and representable; negative quantities are rejected.

Real quantity edit → draft reason `OPERATIONAL_QUANTITY_ADJUSTMENT` → **nonblank governed adjustment explanation required before Lưu**. Supplier text in `GHI CHÚ` does not satisfy that rule. Import accepts an otherwise structurally/current/entry-valid quantity into the local draft, clears the explanation for that newly changed quantity, and exposes the existing reason-note requirement in Atlas. `Lưu` remains unavailable until the operator explicitly supplies a valid explanation. This changes only the proposed future annotation mapping, not RMVP-05 persistence. Do not infer `OTHER`, substitution, removal, a policy change or a different decision kind from prose. RMVP-05 owns the eventual decision kind. A quantity edited back to the canonical proposal may require existing direct-edit reason normalization before Save; import must not invent a new accepted adjustment decision for equal-to-proposal. The draft may remain blocked by that existing check until the operator resolves it in Atlas; show this clearly.

Annotation changes count as unsaved supporting work in the future navigation/date-change/unmount guard, independently of Confirmed Need business dirty state. Warn before discarding them; allow explicit discard or retaining them through a new XLSX export. Do not imply that Confirmed Need Lưu saves them. Session close or abrupt browser termination cannot guarantee recovery. This is a future UX requirement only, not connected work in this PR.

Note-only edit updates only the **local shopping-annotation map**, preserving the Confirmed Need quantity, entry flag, reason code and governed reason note. It creates no confirmation decision and no Save payload. An unchanged workbook note preserves a newer local annotation (V1 improvement using Q baseline). Normalize CRLF to LF and trim outer whitespace for comparison; empty cell explicitly clears the local annotation. Blank notes round-trip. Even on a first unchanged proposal, a supplier annotation has no effect on RMVP-05's null-note decision rule because it never enters `reason_note`. No text-to-Supplier matching, supplier creation, allocation, Procurement instruction or automatic assignment occurs. A future exporter in the same session includes the local annotations again; closing the session can lose them unless the operator retains the XLSX. **Explicit Confirmed Need Lưu does not persist supplier annotations.** Persisting them or copying them into an authorized Procurement decision needs separate Product approval and existing Procurement commands. This is a generated supporting annotation, not a new business fact/store.

Treat `(quantity, reason_code, governed reason_note)` as one coupled Confirmed Need draft for conflict detection. If the file quantity changed and **any** of that local tuple changed after export, reject the entire import, even when both quantities now agree. Preserve the newer local explanation; do not silently replace it with OPERATIONAL or blank text. The operator can resolve the edit in Atlas and re-export. When the manifest is unavailable, no file quantity edit is permitted at all; only the annotation-only recovery above applies. If no coupled local field changed, apply the file quantity as OPERATIONAL with a pending explicit explanation as described above. For the separate annotation field, differing concurrent local/file edits reject; agreeing annotation edits avoid duplicate changes. File quantity and local annotation edits can combine without altering newer governed reason notes. If quantity is unchanged in the file, preserve any newer local quantity and reason/explanation. Report quantity-draft changes and annotation changes separately so a supplier-note edit does not imply a pending Confirmed Need business Save.

## 6. Validation and atomic application (questions 6.14–6.20)

Validation order:

1. Parse XLSX ZIP safely with the V1 caps below; reject corrupt packages, macros, external links, unexpected embedded executable content and formula cells in contractual ranges. Never evaluate workbook formulas.
2. Require the exact version, metadata map, worksheet date set, header labels and full Tables; reject extra nonempty sheets/rows/columns and schema drift.
3. Obtain complete current authorized Atlas evidence without writing. Require exact batch, version, period, run and source snapshot. Require editable `DRAFT_REVIEW` or `REOPENED`, current sources and applicable allowed actions; reject released, invalidated or unauthorized state.
4. Check every current line **exactly once**, no omissions/unknowns/duplicates. Check marker, revision, decision/null, containing sheet/date, School, Location, Ingredient and Unit against canonical evidence. Check locked visible labels against the trusted export labels; if those labels changed in current Atlas, request a fresh export. No identity retargeting by a label.
5. Verify hidden baselines against trusted export evidence (or the narrowly allowed current-saved annotation-only recovery). Compute exact file edits and local conflicts. Validate quantity entries and effective Planning-step eligibility; treat shopping notes solely as free annotations. Ordinary identity-free blank cells outside the Table have no deletion meaning.
6. Construct isolated candidate quantity-draft and annotation maps. Publish both together only after whole-workbook structural/currentness/entry checks succeed. A pending governed adjustment explanation is shown in Atlas and blocks Save, not structural import. Guard against context/date/draft/annotation epoch changing during parse or refresh; discard obsolete results. Keep existing drafts and annotations byte-for-byte on rejection.

V1 resource limits: compressed file at most 10 MiB; at most 128 ZIP entries; at most 50 MiB total uncompressed bytes; any one XML part at most 20 MiB; at most 10,000 data lines total and 7 date sheets plus metadata. Reject duplicate ZIP paths, path traversal, encrypted entries, DTD/entity declarations, and ratios above 200:1 for an entry larger than 1 MiB. Parse only ordinary XLSX OPC workbook, worksheets, Tables, styles, shared strings, document properties, theme and their relationship/content-type parts. Reject macros, external relationships/links, OLE/embeddings, ActiveX, controls, custom XML, drawings/images, signatures and unexpected OPC parts. Internal native printer-settings parts may be present as non-executable print configuration. Standard Excel's internal calcChain part may be present but never evaluated; formula cells are rejected. These are artifact limits, not business policy; caps or allowed part families require an explicit contract revision if changed. A legitimate batch exceeding the caps is not exported as a truncated workbook.

**NO partial import.** Deleting a row does not mean zero; missing expected lines reject the entire workbook. Added spreadsheet rows cannot create Confirmed Needs; unknown rows reject. Duplicates reject even when identical. Reordering complete Table rows and filtering rows are accepted; moving a row to another date sheet or copying one from a different marker rejects. Visible School/Ingredient/Unit edits reject even when hidden identities still match. The next export always restores canonical presentation.

Released/history state in V1: **neither exportable as an editable V1 nor importable**. This preserves current connected gating. A separately approved read-only immutable historical document could be useful but is not included or implemented here. Never infer lifecycle from workbook content. A workbook exported before release cannot be imported after release; after governed reopen its version/revision/source evidence must pass anew, generally requiring a new export.

Successful import changes only local quantity drafts and supporting annotations. Explicit `Lưu` remains the sole authorized Confirmed Need persistence boundary and requires the governed explanation; it does not persist supplier annotations. Import never changes status, commits, confirms, approves, releases or writes into Procurement, Reconciliation or Dispatch.

## 7. Acceptance matrix

These are **future V1 conformance requirements**, not a claim that connected V1 behavior has been implemented or tested. `Export valid?` describes the original source/export eligibility, except where the row describes an attempted export. Every import uses the complete currently authorized target context. Backend write refers to import time; a later explicit successful Save has its ordinary backend effects.

| Scenario                                                                        | Export valid?                     | Import valid?                                           | Draft changes?                       | Backend write? | Expected result                                                        |
| ------------------------------------------------------------------------------- | --------------------------------- | ------------------------------------------------------- | ------------------------------------ | -------------- | ---------------------------------------------------------------------- |
| Untouched round trip                                                            | Yes                               | Yes                                                     | No                                   | No             | Preserve exact current draft and entry flags                           |
| Quantity edit, blank GHI CHÚ                                                    | Yes                               | Yes, if two-decimal/step-valid                          | Quantity/reason; explanation pending | No             | Require governed explanation in Atlas before Save                      |
| Quantity edit, existing supplier note                                           | Yes                               | Yes, if two-decimal/step-valid                          | Quantity/reason; explanation pending | No             | Supplier name is not an adjustment reason                              |
| Note-only edit on existing adjusted decision                                    | Yes                               | Yes                                                     | Annotation only                      | No             | Preserve all Confirmed Need decision draft fields                      |
| Supplier note added to first unchanged proposal                                 | Yes                               | Yes                                                     | Annotation only                      | No             | No decision/Save payload/supplier assignment                           |
| Quantity + note edit                                                            | Yes                               | Yes, if valid                                           | Quantity/reason + annotation         | No             | Apply both locally; governed explanation still required in Atlas       |
| Quantity changed back to proposal                                               | Yes                               | Yes if entry/step valid                                 | Quantity/reason                      | No             | Existing equal-proposal reason feedback can block Save until resolved  |
| Clear GHI CHÚ                                                                   | Yes                               | Yes                                                     | Clear annotation only                | No             | Does not clear any governed adjustment/correction note                 |
| Sort full Table rows after deliberate unprotect                                 | Yes                               | Yes                                                     | No                                   | No             | Technical cells move with their row; protected sort unavailable        |
| Filter rows without deleting them                                               | Yes                               | Yes                                                     | No                                   | No             | Read hidden and visible rows, not visible subset                       |
| Delete row / visible-only copy                                                  | Yes before deletion               | No                                                      | No                                   | No             | Incomplete controlled artifact; no inferred zero                       |
| Duplicate row                                                                   | Yes before duplication            | No                                                      | No                                   | No             | Duplicate stable line blocks all apply                                 |
| Add unknown row                                                                 | Yes before addition               | No                                                      | No                                   | No             | No new Need; reject                                                    |
| Stale batch version                                                             | Yes when exported                 | No                                                      | No                                   | No             | Refresh and export again                                               |
| Stale current revision                                                          | Yes when exported                 | No                                                      | No                                   | No             | Reject even if batch ID matches                                        |
| Stale current decision                                                          | Yes when exported                 | No                                                      | No                                   | No             | Reject null/non-null or UUID mismatch                                  |
| Wrong Need Generation run or snapshot                                           | Yes before corruption             | No                                                      | No                                   | No             | Exact source mismatch                                                  |
| Unsupported future/wrong/missing contract version                               | No as V1                          | No                                                      | No                                   | No             | Closed version gate; no format guessing                                |
| Corrupt XLSX                                                                    | No as received                    | No                                                      | No                                   | No             | Safe Vietnamese parse failure                                          |
| Change visible School name                                                      | Yes before change                 | No                                                      | No                                   | No             | Locked-reference mismatch, no retarget                                 |
| Change visible Ingredient name                                                  | Yes before change                 | No                                                      | No                                   | No             | Locked-reference mismatch, no retarget                                 |
| Change visible Unit or hidden Unit UUID                                         | Yes before change                 | No                                                      | No                                   | No             | Unit mismatch; no conversion                                           |
| Six-decimal untouched quantity 1.234567                                         | Yes                               | Yes                                                     | No                                   | No             | Exact equality; no phantom edit                                        |
| Exact numeric/comma/dot equality with baseline                                  | Yes                               | Yes                                                     | No                                   | No             | Equivalent representation is not entry                                 |
| Real edit to 1.234568 / >2 decimal places                                       | Yes before edit                   | No                                                      | No                                   | No             | Current operator-entry precision restriction preserved                 |
| Two-decimal edit not on Planning step                                           | Yes before edit                   | No                                                      | No                                   | No             | Reject exact nonrepresentability; no rounding                          |
| Zero                                                                            | Yes                               | Yes if entry/step rules pass                            | Quantity/reason if changed           | No             | Explicit zero; explanation required before Save, no row deletion       |
| Negative or blank quantity                                                      | No if invalid at export           | No                                                      | No                                   | No             | Invalid entry; no negative or inferred zero                            |
| Released batch                                                                  | No as editable V1                 | No                                                      | No                                   | No             | Current lifecycle gating preserved                                     |
| Workbook from another service period                                            | Yes in its own context            | No here                                                 | No                                   | No             | Exact period mismatch                                                  |
| Row moved to another date worksheet                                             | Yes before move                   | No                                                      | No                                   | No             | Row/date/sheet binding mismatch                                        |
| Row copied from another export of same batch                                    | Yes at source                     | No                                                      | No                                   | No             | Per-export marker mismatch                                             |
| Same Ingredient label at visibly distinct School/location                       | Yes, location display unambiguous | Yes                                                     | Only edited stable line              | No             | Preserve every original row; never group by names                      |
| Local coupled quantity/reason edit + file quantity edit, including equal result | Yes                               | No                                                      | No                                   | No             | Preserve newer local reason/explanation; re-export                     |
| Ambiguous identical visible tuple on one date                                   | No                                | No as V1                                                | No                                   | No             | Block export; never merge distinct identities                          |
| Newer local quantity/note; file untouched                                       | Yes                               | Yes                                                     | No                                   | No             | Preserve local draft, including note                                   |
| Conflicting file/local edit of same field                                       | Yes                               | No                                                      | No                                   | No             | Whole-import conflict; retain local work                               |
| Tampered hidden quantity/reason/note baseline                                   | Yes before change                 | No with trusted evidence                                | No                                   | No             | Never accept workbook baseline as business authority                   |
| Browser restarted, quantity unchanged/saved; supplier notes retained in file    | Yes                               | Yes if all checks pass and no local annotation conflict | Annotations only                     | No             | Preserve all governed draft fields; visible notes are free annotations |
| Browser restarted, file quantity edit or lost unsaved quantity/reason code      | Yes at export                     | No                                                      | No                                   | No             | Re-export; no file-only quantity/reason authority                      |
| Old Atlas or Retool workbook                                                    | No as V1                          | No                                                      | No                                   | No             | Fresh V1 export required at cutover                                    |
| Formula cell in quantity/note/metadata                                          | No as V1                          | No                                                      | No                                   | No             | Do not evaluate or trust cached formula results                        |
| UI filtered export request                                                      | Only full-batch export            | No for subset artifact                                  | No                                   | No             | Ignore screen projection; export complete set                          |

## 8. Decision index for task questions

| Question              | Frozen proposal                                                                      | Detail                |
| --------------------- | ------------------------------------------------------------------------------------ | --------------------- |
| 6.1 Scope             | Complete single existing batch, exact period up to 7 days, date sheets, fixed names  | §2 Scope              |
| 6.2 Grain             | Stable line; date/School/location/Ingredient/controlled Unit, never name aggregation | §2 Row grain          |
| 6.3 Visible columns   | TRƯỜNG, THÀNH PHẦN, ĐVT, SỐ LƯỢNG, GHI CHÚ                                           | §2 Visible columns    |
| 6.4 Editable          | Quantity and shopping annotation only                                                | §2 Visible columns    |
| 6.5 School            | Every line, locked location suffix when needed; ambiguous tuples block export        | §2 Row grain          |
| 6.6 Order             | Date, available canonical School rank, original source sequence, stable UUID         | §2 Ordering           |
| 6.7 Row identity      | Required F:Q evidence; revision/decision numbers redundant                           | §3 Classification     |
| 6.8 Metadata          | Very-hidden closed _ATLAS_META map, no authority                                     | §3 Metadata           |
| 6.9 Version           | Exact ATLAS_SHOPPING_LIST_V1, reject legacy/future drift                             | §3 Compatibility      |
| 6.10 Table            | Full A:Q structured Table including identities                                       | §4 Table              |
| 6.11 Protection       | Select/filter permissions, D/E edits, no protected sorting; safety only              | §4 Protection         |
| 6.12 Quantity         | Exact decimals; six-place display, unchanged evidence, two-place/step-valid edits    | §5 Quantity           |
| 6.13 Notes            | Supplier annotation separate from governed reason; quantity explanation in Atlas     | §5 Notes              |
| 6.14 Deletion         | Reject incomplete artifact, never infer zero                                         | §6 Validation         |
| 6.15 Additions        | Unknown rows rejected; cannot create Needs                                           | §6 Validation         |
| 6.16 Sort/filter      | Accept intact full-row identities, including hidden/filtered rows                    | §4 and §6             |
| 6.17 Visible text     | Reject canonical label mismatch, no retargeting                                      | §6 step 4             |
| 6.18 Released/history | Neither editable V1 export nor import; reference format excluded                     | §6 Lifecycle          |
| 6.19 Partial import   | None; atomic complete artifact and local conflict validation                         | §6 Atomic application |
| 6.20 Persistence      | Local draft/annotations only; explicit Lưu saves governed decisions only             | §1 and §6             |

## 9. Specimen, reproduction and review gate

[Specimen](examples/atlas-shopping-list-v1-example.xlsx): 2 service dates, 3 synthetic schools, 13 distinct Ingredient identities and labels, 80 lines, multiple lines per School, integer/one-decimal/six-decimal/zero quantities, long School/Ingredient names, blank and existing notes, multiple locations and separate ambiguous-label rejection coverage. No production data was copied. UUIDs and timestamp are deliberately fixed in this review fixture only. Repeated groups and native page breaks exercise continuation/print layout.

No repository policy prohibits XLSX binaries; `.gitignore` has no XLSX exclusion. Commit this small deterministic binary and its fixture/generator, not the supplied business workbook or Retool source dumps. The generator uses the supplied bundled `@oai/artifact-tool` for authoring; the standard-library Python finalizer supplies native protection, hiding, exact numeric XML and print configuration absent from the documented artifact API. Neither is imported by the app. No new repository dependency.

PowerShell reproduction from the repository root (substitute the dependency paths returned by the workspace dependency loader on another host):

```powershell
$taskNode = 'C:/Users/HOME/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node.exe'
$taskPython = 'C:/Users/HOME/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
$env:ATLAS_ARTIFACT_NODE_MODULES = 'C:/Users/HOME/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules'
& $taskPython docs/xlsx/examples/make-fixture.py
& $taskNode docs/xlsx/examples/generate-specimen.mjs docs/xlsx/examples/atlas-shopping-list-v1-example.xlsx
& $taskPython docs/xlsx/examples/finalize-specimen.py
& $taskPython docs/xlsx/examples/validate-specimen.py
```

The artifact tool may create an `.xlsx.inspect.ndjson` sidecar; keep it outside version control. An optional third argument to the JS builder writes range-preview PNGs outside the repository. Regeneration depends on the bundled tool version; deterministic fixture and normalized XML/ZIP are tested, and byte reproducibility is recorded in the task record. No claim of determinism across different artifact-tool releases.

Product review must approve the proposed wording/layout, repeated School labels/location suffix, seven-day exact-single-batch scope, protected-sort limitation, strict compatibility and local baseline/conflict behavior. It must approve supplier annotations being separate from governed reasons and remaining local/workbook-only, with explicit adjustment explanation in Atlas before Save. Decide separately whether persisted supplier notes, historical read-only export or multi-daily-batch collection is needed. The matrix already freezes V1 behavior for those cases; optional extensions are excluded, not parser ambiguities.

**Stop here.** No connected importer/exporter implementation or merge is authorized by this design task. Product approval of this contract/specimen precedes a separately bounded implementation PR.
