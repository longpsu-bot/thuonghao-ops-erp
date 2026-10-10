# Operational document XLSX parsing metadata

Owner request, 9 October 2026: hide Ingredient IDs and other parsing information
using the existing Shopping List presentation convention. This bounded follow-up
applies to released PO and PXK Excel exports, including grouped/ZIP outputs.

Business document numbers, frozen `Mã hàng` / `Mã NCC`, revision/status labels,
School bands, `Nấu tại`, notes and exact printed quantities remain visible.
Technical replacement references move to metadata; printed replacement labels
remain readable. PDF output contains no technical replacement IDs.

This is an output-only contract. It does not add an import command or authorize
business writes. Shopping List V2/A+ and its strict import contract are unchanged.
Hidden data is a presentation convention, not an access-control mechanism.

## Hidden row columns

PO uses G:N, with headers at row 9 in details and row 10 in the summary. PXK uses
I:P with headers at row 10. Every column is hidden, width 1 and text-formatted.
The visible print areas retain PO A:F and PXK A:H.

| Offset | Header                | Value                                      |
| ------ | --------------------- | ------------------------------------------ |
| 1      | `__document_id`       | Released PO / PXK ID                       |
| 2      | `__ingredient_id`     | Immutable row Ingredient ID                |
| 3      | `__unit_id`           | Immutable row Unit ID                      |
| 4      | `__school_id`         | School ID; null on a PO summary            |
| 5      | `__location_id`       | Delivery location ID; null on a PO summary |
| 6      | `__cooking_group_id`  | Captured Cooking Group ID or null          |
| 7      | `__exported_quantity` | Exact source quantity string               |
| 8      | `__row_kind`          | `ITEM` or `CONTINUATION`                   |

Group bands, spacers and signature rows have no row metadata. A continuation
retains the same identity, quantity and sources as its item; it carries no printed
quantity. Parsers count only `ITEM` rows to avoid double-counting. PO summary
rows retain all underlying source lines, including lines aggregated across Schools.
School detail rows retain their own exact School quantity; source `ordered_quantity`
retains the separate underlying PO line quantity.

## Very-hidden metadata sheet

`_ATLAS_META` is the final worksheet with state `veryHidden`, reserved independently
of School names. A single sheet covers every document in a grouped workbook.

- A1: `contract_version`; B1: `ATLAS_OPERATIONAL_DOCUMENT_V1`.
- Row 2 headers: `record_kind`, `document_id`, `sheet_name`, `row_number`,
  `payload_json`.
- Rows 3 onward: one `DOCUMENT` record per released document and one `ROW_SOURCE`
  record per source associated with a physical item/continuation row. Payloads
  contain scalar snapshot values as JSON, preserving IDs and exact quantities as
  strings. Separate source records avoid concatenating unbounded ID arrays in one
  Excel cell.

PO document payloads retain PO/revision/predecessor/replacement IDs, Supplier ID,
frozen Supplier code, document number, release time, date, status, revision number
and workbook mode. Each source payload retains stable PO line/revision IDs,
allocation family/revision/split IDs, delivery location, exact ordered quantity and
frozen Ingredient code. The PO document record has blank `sheet_name`; its sources
associate each selected visible view with the same released document.

PXK document payloads retain release/predecessor IDs, School/location/cooking-group
IDs, version, document number, date, status, source fingerprint and release time.
Source payloads retain the released line ID plus the shaped read's exact confirmed
need/allocation/PO lineage and `covered_quantity`. Historical absent line IDs are
explicit JSON null; no identity is invented. A line without source records gets
one association containing its nullable released line ID.

Consumers resolve `ROW_SOURCE` by `(document_id, sheet_name, row_number)` and
inspect `document_type` (`PO` or `PXK`) in the corresponding `DOCUMENT` payload.
Metadata derives solely from the already-authorized released shaped read. It
does not query current Master Data, change release guards, or grant backend access.

## Validation and rollback

Focused tests cover all PO modes, summary aggregation, continuation rows, PXK
single/grouped/ZIP exports, nullable historical line IDs and reserved sheet names.
Native Excel checks preserve hidden columns, very-hidden state and exact text
through open/save/reopen; rendered PDF checks retain accepted print geometry.
No migration, schema, privilege, RLS or API read changes are required. Rollback is
a frontend exporter revert; immutable releases and Shopping imports are unaffected.
