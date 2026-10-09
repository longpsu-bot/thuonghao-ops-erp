# Document System V1 authority gaps

Status: **Outward-code and PO-label decisions remain OPEN.** The Owner authorized
the bounded School Cooking Group amendment on 9 October 2026; its implementation
and verification are recorded in the existing task. This records decisions inside
ATLAS-DOCUMENT-SYSTEM-01 / Draft PR #360.

School Cooking Group / “Nấu tại”: **APPROVED BOUNDED CLASS C AMENDMENT**.
The current optional authority and minimum released pair are implemented and
verified. V1 membership adoption still requires actual retained reconciliation.
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

Released PO Ingredient names and Unit codes are currently resolved from mutable
Master Data; later wrappers add no snapshots for these labels. This conflicts
with section 8 of the
[Planning–Procurement business freeze](../architecture/planning-procurement-business-freeze.md).
The base read also exposes a mutable location label, but official School-detail
export uses release-captured School and location labels from `school_breakdown`.
Supplier name, School/location labels and exact released quantities remain
authoritative; Ingredient/Unit label immutability cannot be claimed.

The conflict was reported before continuing. The Owner explicitly authorized:
**“Proceed with PO presentation only; keep authority gaps blocked.”** This allows
layout and download coordination over the unchanged read; it does not approve a
backend correction or waive the frozen-read rule for product acceptance.
PXK already reads frozen issuer/address, School/location and line labels from its
[release contract](../api/school-dispatch-release.md).

## Cooking-group identity and membership

Read-only V1 exporters use `po_export_groups`, `po_export_group_members` and
`dispatch_export_grouped`: `entity_key`, `entity_type`, `group_name_xlsx`,
`delivery_info`, `sub_delivery`. These establish a reconciliation need, not values
that can be imported without comparison. Actual retained PO/Dispatch membership
values are unavailable in the repository. The
[reconciliation matrix](../testing/artifacts/atlas-document-system-01/cooking-group-revision/v1-reconciliation.csv)
therefore contains column headings only. V1 adoption remains blocked. A PO versus
Dispatch disagreement must be reported as `COOKING_GROUP_RECONCILIATION_REQUIRED`;
no name, address, contract-type or issuer heuristic resolves it.

The Owner's bounded amendment defines one Admin authority: Cooking Group master
records and zero or one current group per School. New PO School breakdowns and
PXK headers capture group ID/name at release. Historical rows are not backfilled.
Exporters read captured pairs only; absent pairs omit `NẤU TẠI`. Two Schools in
one group remain distinct recipients. Dispatch entity ZIP can use the captured
group ID to coordinate downloads while preserving each School/location release.
See the [API contract](../api/school-cooking-groups.md) and
[existing task](../implementation-tasks/TASK-ATLAS-DOCUMENT-SYSTEM-01.md) for the
forward migration and acceptance evidence.

## Bounded Class C decisions required

Owner approval must still settle the following before their implementation:

1. Define item/supplier outward-code meanings and the explicit legacy mapping;
   decide which code/label/address facts must freeze at PO release.
2. Reconcile actual retained V1 PO and Dispatch membership before adopting data.
   The current optional Admin membership and frozen document pair are authorized;
   no effective dating or membership lifecycle is required by this amendment.
3. Approve a versioned read/snapshot correction for PO labels and any added facts,
   including historical compatibility. Historical documents must be identified
   as unavailable where facts were never captured; no fabricated backfill.
4. Decide supplier/destination address semantics and whether the exposed export
   scope should expand beyond the current selected date/Schools.

The freeze's Class C gate remains for the open decisions. The cooking-group
amendment adds one forward migration and shaped Admin APIs; it does not alter
release lifecycles, quantities or production data. No Staging deployment or Live
OPS query/write is authorized. Rollback effects are stated in the existing task;
future deployment would require a forward correction, never deletion of captured
historical facts.
