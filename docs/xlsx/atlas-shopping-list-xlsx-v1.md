# Atlas Confirmed Need — Phiếu đi chợ XLSX V2

**Status: STRUCTURE AND A+ PRESENTATION GEOMETRY OWNER-APPROVED; HOSTED ACCEPTANCE PENDING.**
Current amendment: `ATLAS-SHOPPING-LIST-PRESENTATION-CONTRACT-02`, 2026-10-07.
Same Draft [PR #355](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/355).
Current format: **ATLAS_SHOPPING_LIST_V2**.

This amendment supersedes V1's School-on-data-row presentation, F:O-only Table, 35.5 pt Unit width, combined 84-character print envelope and unrestricted row-order import. The document/schema filenames remain for history continuity. The [V1 example](examples/atlas-shopping-list-v1-example.xlsx) and fixture are historical, not accepted V2 inputs. Current specimens use the real authorized 17 September Staging export. See [schema](atlas-shopping-list-xlsx-v1.schema.json), [evidence](atlas-shopping-list-xlsx-v1-evidence.md) and [task record](../implementation-tasks/TASK-ATLAS-SHOPPING-LIST-PRESENTATION-CONTRACT-02.md).

## Business contract — unchanged

Apply [ARCH-002](../architecture/arch-002-atlas-system-map.md), [Atlas model convergence](../decisions/decision-atlas-model-convergence.md), [RMVP-05](../api/rmvp-05-connected-confirmed-need-review.md), its AUD-003 precision amendment, [D-037 Save v2](../api/confirmed-need-save-release-v2.md) and D-041 exact-day generation.

**FACTS EXPLICIT — STATE DERIVED — SUPPORTING OBJECTS GENERATED.**

The workbook is generated from complete saved/current authoritative daily Confirmed Need facts. It cannot create/retarget School, Ingredient, Unit, Delivery Location, policy, Need lineage, lifecycle or a persisted confirmed quantity. Export blocks incomplete/stale authority and unsaved local drafts in the connected workbench. Every authorized page must retain coherent batch/version/source evidence.

A workbook collects 1–7 distinct represented service dates, each with one complete daily batch, one date worksheet and one daily metadata record. This creates no weekly aggregate. Current connected UI remains exact-day: a valid multi-date workbook receives `MULTI_DATE_UI_DEFERRED_BY_EXACT_DAY_WORKBENCH` before local apply.

Quantity remains exact up to six decimal places, including explicit zero. D exports the shortest exact text representation without rounding; raw numeric XML edits are read before binary conversion. Exact equality to the authoritative baseline preserves the local draft. A real edit must satisfy existing two-decimal entry and current Planning-step/policy rules. Existing governed reason requirements and optimistic concurrency remain backend-authoritative at explicit Save.

`GHI CHÚ` initially contains authorized export-time first-preferred Supplier advice. It is editable working paper, ignored on import, never Supplier allocation or governed reason-note evidence. Supplier advice drift alone does not stale import. Existing local drafts must be clean; whole-workbook failure applies nothing.

```text
Complete saved/current Confirmed Need
→ generate XLSX
→ edit DATA_LINE D; use E as working paper
→ reopen Atlas and validate the entire workbook against fresh authority
→ apply accepted quantity edits to local proposals only
→ explicit Lưu
→ existing transactional backend command
```

Import executes **zero business writes**, Save/Preview/release/generation commands or downstream operations.

## Presentation contract — V2

Each date sheet preserves:

- A1:E1 merged date title, row 2 spacer.
- Row 3 global header: `TRƯỜNG | THÀNH PHẦN | ĐVT | SỐ LƯỢNG | GHI CHÚ`.
- Frozen pane `state=frozen, ySplit=3`; print titles `1:3`.
- A4 portrait, Times New Roman, 96% scale, bounded A:E print area.
- One Excel Table from A3:Q through the complete body, no totals and no band merges.
- Hidden F:Q and veryHidden `_ATLAS_META`; locked identity/reference cells and structure.
- Only DATA_LINE D/E are working cells; every School band is locked. Protected sort remains false.

There are exactly two explicit hidden row kinds:

| Kind        | Visible A                                                    | Visible B:E                                                                | Hidden evidence                                                             |
| ----------- | ------------------------------------------------------------ | -------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| SCHOOL_BAND | Canonical School name; generated continuation adds ` (tiếp)` | Blank, same neutral fill/strong top-bottom border across A:E               | Marker, date, School ID/name, row kind; all line-specific fields blank      |
| DATA_LINE   | Blank                                                        | Ingredient name, shared Unit display, exact quantity, Supplier advice/note | Complete existing identity/baseline plus row kind and canonical School name |

One initial School band precedes each represented School's data. School lines are contiguous beneath the appropriate band. A continuation is a separate SCHOOL_BAND at the first body row of a generated new page, labelled `SCHOOL NAME (tiếp)`. No fake line ID is created. Band cells suppress internal vertical rules, use bold School text and a neutral gray fill; grayscale readability carries the grouping. No automatic row striping or web branding.

Export retains authorized source School first-occurrence order and the original line sequence within each School. The current read exposes no canonical School display-rank field. No lexical sort or name special case is invented. Import permits row reordering within a School only when grouping and generated pagination remain valid; a full Table sort that scatters bands/data fails closed.

The Owner retained `SỐ LƯỢNG` in final A+; no change to `SL`.

## Shared Unit display

`shoppingListUnitDisplay(controlled_unit)` remains the sole resolver: trimmed human-facing code first, otherwise trimmed human name. Technical adoption codes, UUIDs, placeholders and control characters are not display labels. No suitable label blocks export as `INVALID_UNIT_DISPLAY`.

Examples: kg/Kilogram → kg; v1-unit-_/Miếng → Miếng; v1-unit-_/Quả → Quả. No abbreviation map, truncation, per-Unit override or Unit-fact mutation. Export, geometry, ambiguity checks and import use the same label; hidden Unit ID stays exact.

## Hidden row evidence and flat copying

| Column | Field                 | Rule                                                          |
| ------ | --------------------- | ------------------------------------------------------------- |
| F      | `__workbook_marker`   | Every body row matches the metadata marker                    |
| G      | `__line_id`           | Unique stable DATA_LINE identity                              |
| H      | `__revision_id`       | Exact current revision                                        |
| I      | `__decision_id`       | Exact current decision; empty means null                      |
| J      | `__service_date`      | Sheet/date/current line binding                               |
| K      | `__school_id`         | Canonical School identity                                     |
| L      | `__location_id`       | Exact Delivery Location lineage; no visible subgroup          |
| M      | `__ingredient_id`     | Exact current Ingredient identity                             |
| N      | `__unit_id`           | Exact controlled Unit identity                                |
| O      | `__exported_quantity` | Exact saved authoritative baseline                            |
| P      | `__row_kind`          | SCHOOL_BAND or DATA_LINE; never inferred from blank IDs       |
| Q      | `__school_name`       | Canonical validated snapshot, repeated on every business line |

SCHOOL_BAND G/H/I/L/M/N/O must be blank. No ingredient, quantity or working note is allowed in B:E. Every DATA_LINE carries its own K/Q and all lineage even though A is blank. Unprotect with the public contract password `ATLAS_SHOPPING_LIST_V2`, unhide F:Q, copy only DATA_LINE rows, then rehide/reprotect. This preserves the existing unhide/protection workflow; protection is accidental-edit assistance, not an authorization boundary.

School ID is the identity key. A changed K raises `STALE_IDENTITY`; a changed Q with correct ID raises `REFERENCE_CHANGED`. Band visible name and hidden name must also match fresh canonical School name. School renaming requires a fresh export.

## Closed envelope and compatibility

Metadata A1:B7 contains exactly `contract_name`, `contract_version`, `workbook_marker`, `exported_at`, `service_period_start`, `service_period_end`, `geometry_variant`. Version must equal `ATLAS_SHOPPING_LIST_V2`; geometry must equal `A+`. Earlier A/B/C V2 specimens are superseded and require re-export; the structural version remains V2 and the existing geometry field is the exact print-compatibility discriminator. A8:E8 retains daily headers; rows 9 onward contain service_date, confirmed_need_batch_id, batch_version, need_generation_run_id and release_snapshot_id. Every daily sheet/record is unique and exact.

V1 was fixed/version-discriminated; no pre-final governance rule authorizes silently reusing V1 for new row semantics. Therefore V2 is the compatibility ruling and **legacyAccepted remains false**. The backend export-read contract is unchanged.

Whole-workbook import validates ZIP/resource limits, permitted package parts, exact sheet/Table/metadata set and headers, no formulas/executable/external/merged Table cells, no nonempty outside-envelope cells, complete DATA_LINE count/set, School-band grouping and generated continuation/page-break structure, all IDs/currentness, visible Ingredient/Unit, blank DATA_LINE A and hidden School name. Only then do changed quantities become local proposals. Missing/fake/duplicate/relabeled business lines fail `LINE_SET_MISMATCH`; no business line may precede its initial band or appear under a foreign School.

Pagination validates the existing declared row-height classes and geometry, independent of edited D/E text or later Supplier advice drift. Native Excel on the certification host quantizes height by at most 0.1 pt; 0.15 pt tolerance only normalizes that representation drift. Different height classes/resized rows or altered continuation positions fail closed. ExcelJS alone drops manual breaks on rewriting: certification restores the exported break IDs for its isolated edit; native Excel persistence is checked separately.

The workbook is unsigned. Hidden evidence is not trusted authority or cryptographic provenance; fresh authorization/currentness and explicit Save remain decisive. No browser session manifest is required.

## Final A+ geometry — Owner decision, 2026-10-07

The Owner reviewed actual A/B/C PDFs and native files, selected A's vertical density and transferred one width unit (6 pt) from Note to Unit. All three had identical wrapping; extra B/C height did not earn additional text capacity. A+ is now the only export/import geometry. The provisional geometry selection code has been removed; historical A/B/C metrics remain in the evidence record, not runtime alternatives.

| A+ setting                  | Final value      |
| --------------------------- | ---------------- |
| A/B/C/D/E width units       | 14/31/10/16/23   |
| Native full widths, pt      | 84/186/60/96/138 |
| Normal / wrapped / band, pt | 28/44/28         |
| Body hard cap, pt           | 44               |
| Usable Unit / Note, pt      | 54.5/132.5       |
| Font sizes and print scale  | Unchanged; 96%   |
| Quantity header             | SỐ LƯỢNG         |

Logical width uses native Carlito 11 Normal-style 6 pt per width unit with 5.5 pt text allowance, before print scaling. The real maximum Unit advance is `Miếng` = 46.99512 pt at 18 pt, leaving approximately 7.5 pt clearance. All eight current Units fit unchanged: kg, Cái, Miếng, Quả, Cốc, Hộp, Gói, Trái. `PRINT_OVERFLOW` remains for unsupported glyphs, Unit/quantity beyond usable columns, School beyond band width, text needing more than two lines or page-width overflow. No text shrinkage, arbitrary abbreviation or master-data constraint.

Fresh read-only Staging authority still returns 248 lines, 20 Schools and batch version 3. Native A+ PDF remains **12 physical A4 pages**, **6 continuation bands**, **1 wrapped Ingredient**, **32 wrapped DATA_LINE**, **0 wrapped bands**, with no new wrapping, overflow, clipping or cropping. Data rows/page remain **21,22,21,21,22,23,21,22,23,21,21,10**. These results satisfy the Owner's conditional geometry-finalization decision; hosted export/import acceptance and Planning/Procurement business freeze remain separate gates. Freeze recommendation: **HOLD**.

### Clean deliverable versus edited QA copy

The final clean `ShoppingList-SchoolBand-APlus-2026-09-17.xlsx` is generated directly by the production codec from fresh authoritative facts. Every visible quantity is checked against its exact saved baseline. The first `Cá basa phi lê` exports visible `228.01` and hidden `228.010000`. Its corresponding PDF is produced from a read-only native Excel open; all 248 PDF quantities and Unit labels reconcile with the clean file.

Before any edit/unhide/native-save test, copy the clean XLSX to `ShoppingList-SchoolBand-APlus-2026-09-17-QUANTITY-EDIT-TEST-ONLY.xlsx`. Only that copy is edited from `228.01` to `12,5`, with baseline unchanged. Native save/reopen and import produce exactly one local proposal; clean import produces none. A SHA-256 comparison proves the clean export is byte-for-byte unchanged after QA. Earlier `-native.xlsx` specimens were intentionally edited QA copies, not clean Product deliverables; their naming was insufficiently explicit and is superseded by this separation.

## Validation and rollback

Focused tests cover pane/header/Table structure, bands and continuations, row-kind integrity, repeated hidden identities/name, all ten required tamper cases, stale batch/source/revision/decision, Unit display, exact precision, complete atomic import and zero command calls. The production-codec specimen and native Excel scripts additionally reconcile all 248 business lines, unhide/copy records, normal Open without repair, SaveAs/reopen, changed/unchanged imports, physical A4 PDF dimensions, rows/page, complete Ingredient text and printable bounds.

No migration/schema/business-data/Retool/live OPS change. Rollback is a frontend/codec/document revert; files must be re-exported for the matching importer. No database rollback is needed.
