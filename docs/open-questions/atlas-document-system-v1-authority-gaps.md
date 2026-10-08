# Document System V1 authority gaps — pending Owner decision

Status: **Class C proposal, NOT APPROVED; implementation blocked.** This records
decisions inside ATLAS-DOCUMENT-SYSTEM-01 / Draft PR #360, not a new task or API.
The [Owner fidelity review](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/360#issuecomment-6053928763)
remains NOT ACCEPTED. CI and visual checks cannot approve these business facts.

## Released outward codes

The PO read model and [released read contract](../api/school-catering-procurement.md)
provide supplier ID/name and `current_revision.supplier_name_snapshot`; lines
provide Ingredient ID/name and Unit ID/code. They do **not** provide a frozen
supplier outward code, item outward code, supplier address, or typed delivery
address on the School breakdown. `delivery_location_snapshot = "Nhiều điểm giao"`
is a display summary, not an address.

The owner sample contains supplier code 53 and legacy numeric Ingredient codes
1082, 956, 957 and 1053. These are not proven equivalent to Atlas master codes.
Atlas master codes may use generated `ingredient-<uuid>` / `supplier-<uuid>`
values; [RMVP-01](../architecture/rmvp-01-independent-atlas-master-data.md) does
not establish their legacy outward-code meaning. IDs are never printed in code
cells and current master data is never consulted to supply released codes.
The restored summary retains its code column and prints explicit missing-code
notices. Empty code cells therefore represent a reported authority gap, not
silent omission or invented codes.

Evidence: `schoolCateringProcurementModel.ts` PO types; migrations
`20260831120000_school_catering_purchase_orders.sql` (released read and location
summary), `20260914105238_atlas_document_output_snapshots.sql` (School breakdown
and supplier name snapshot), and `20261001094403_procurement_supplier_line_note.sql`
(note/status wrapper). The wrappers do not add immutable outward codes.

## PO labels contradict the approved frozen-read rule

The base released PO read still joins current Ingredient names, Unit codes and
delivery-location names. The later breakdown/note wrappers do not freeze those
display fields. This conflicts with section 8 of the
[Planning–Procurement business freeze](../architecture/planning-procurement-business-freeze.md).
Supplier name snapshot and exact released quantities remain authoritative;
Ingredient/Unit/location label immutability cannot be claimed.

The conflict was reported before continuing. The Owner explicitly authorized:
**“Proceed with PO presentation only; keep authority gaps blocked.”** This allows
layout and download coordination over the unchanged read; it does not approve a
backend correction or waive the frozen-read rule for product acceptance.
PXK already reads frozen issuer/address, School/location and line labels from its
[release contract](../api/school-dispatch-release.md).

## Cooking-group identity and membership

Read-only V1 exporters use `po_export_groups`, `po_export_group_members` and
`dispatch_export_grouped`: `entity_key`, `entity_type`, `group_name_xlsx`,
`delivery_info`, `sub_delivery`. Current PO breakdowns and PXK releases capture
School and delivery-location identities/order, not this group identity or
membership. Generic proposed SchoolGroup filtering and legacy `contract_type`
do not establish released cooking-group membership. Contract type determines an
issuer fact in the import design; it is not a grouping rule.

The revision groups only captured School/location IDs and preserves each release.
Equal names do not merge entities. Date/entity ZIP means date or captured
School/location, never an inferred company cooking group.

## Bounded Class C decisions required

Owner approval must settle the following before implementation:

1. Define item/supplier outward-code meanings and the explicit legacy mapping;
   decide which code/label/address facts must freeze at PO release.
2. Define cooking-group identity, recipient grain, membership authority and
   effective date. Decide whether group membership freezes with the document or
   merely coordinates downloads; no name/contract-type heuristic is proposed.
3. Approve a versioned read/snapshot correction for PO labels and any added facts,
   including historical compatibility. Historical documents must be identified
   as unavailable where facts were never captured; no fabricated backfill.
4. Decide supplier/destination address semantics and whether the exposed export
   scope should expand beyond the current selected date/Schools.

The freeze's Class C gate applies. No migration, API envelope, release lifecycle,
master lookup, production data, Backend 02C or live Supabase/Retool change is
included. Rollback of this revision is exporter/UI presentation only.
