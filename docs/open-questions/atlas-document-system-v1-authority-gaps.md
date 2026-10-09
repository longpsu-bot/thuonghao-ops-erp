# Document System V1 authority gaps

Status: **PO label/code authority RESOLVED; supplier address OPEN.** The Owner's
9 October 2026 final closeout instruction authorizes the correction in existing
ATLAS-DOCUMENT-SYSTEM-01 / Draft PR #360. Product/visual acceptance remains with
the Owner. Earlier presentation-only restrictions are superseded for this bounded
correction; they do not authorize deployment or V1 data adoption.

## Released outward codes — RESOLVED

Ingredient and Supplier now have nullable explicit `document_code` facts, authored
through their existing governed Admin editors and versioned commands. The exact
import contracts establish `v1-ingredient-<n>` and `v1-supplier-<n>` as retained
legacy IDs. The forward migration populates only codes matching
`^v1-ingredient-[1-9][0-9]*$` / `^v1-supplier-[1-9][0-9]*$`, using the suffix as
text: `1082`, `956`, `957`, `1053`, supplier `53`. The same exact provenance rule
applies to future imported inserts. No name, UUID, ordering or other-prefix
inference is permitted; unrelated technical codes remain untransformed.

Atlas-native document codes are explicit governed facts. Null remains valid in
Master Data, but blocks future official PO release. Authored codes must be
trimmed, nonblank, at most 200 characters and contain no control characters,
technical V1 prefix or UUID. Codes retain text identity, including leading zeroes;
technical identities never supply official code cells.

See [Master Data authority](../architecture/rmvp-01-independent-atlas-master-data.md)
and [PO contract](../api/school-catering-procurement.md).

## Released PO labels — RESOLVED

Future release freezes `supplier_document_code_snapshot` with the existing
supplier name, and line `ingredient_document_code_snapshot`,
`ingredient_name_snapshot`, `unit_code_snapshot`. The release transaction locks
the participating Master Data facts and validates codes before issuing the
supplier commitment. A replacement captures its own current facts; predecessor
evidence remains immutable, including after supersession.

Released/superseded reads and all official XLSX/PDF modes and supplier/date ZIPs
use these snapshots exclusively. Existing School bands, optional `Nấu tại`, exact
quantities, frozen supplier notes and School/location snapshots remain in effect.

Historical releases are not backfilled from current masters. They remain readable
with explicit missing evidence and derived `document_snapshot_complete: false`;
official regeneration fails closed with:
“Không đủ dữ liệu chứng từ lịch sử để tái xuất chính thức.” Missing historical
labels cannot be presented as captured truth. PXK already freezes its labels and
its accepted authority is unchanged.

## Cooking Group / Nấu tại — RESOLVED

The accepted optional current Admin membership and immutable released group
ID/name are implemented. Two Schools in one group remain distinct recipients;
absent captured pairs omit `NẤU TẠI`. The [Cooking Group API](../api/school-cooking-groups.md)
and existing task record its accepted amendment.

Actual retained V1 PO/Dispatch memberships are unavailable. The
[reconciliation matrix](../testing/artifacts/atlas-document-system-01/cooking-group-revision/v1-reconciliation.csv)
truthfully contains headings only. This is a **CUTOVER_DATA_CONFIGURATION_GATE**,
not an architecture blocker. Before real grouped operation, Schools must be
explicitly configured in Atlas Admin or reconciled from approved retained
evidence. A PO/Dispatch disagreement requires
`COOKING_GROUP_RECONCILIATION_REQUIRED`; no heuristic resolves it.

## Supplier address — OPEN

Retained V1 supplier `contact_details` is source-only/unmapped. Atlas has no
approved supplier-address fact in this document contract. Free-form text is not
parsed. `delivery_location_snapshot = "Nhiều điểm giao"` is a display summary,
not a typed address. This closeout does not invent or validate address semantics,
and cannot claim complete V1 fidelity while this genuine gap remains.

## Delivery and remaining gates

[Existing task](../implementation-tasks/TASK-ATLAS-DOCUMENT-SYSTEM-01.md) and
[closeout evidence](../testing/artifacts/atlas-document-system-01/po-identity-closeout/README.md)
record validation and rollback effects. Repository migrations: 96. Owner-verified
Staging baseline: 94, tip
`20261008015340_atlas_backend_convergence_02b_allocation`. Neither PR migration
is deployed. No Staging/Live OPS query or write, Retool mutation, merge or data
adoption is authorized. Any later rollback must preserve authored codes and
historical release evidence through a reviewed forward correction.

The existing local four-second Need target miss remains unrelated and open;
the eight-second hard regression guard is retained. Final clean cycles pass it,
but discarded attempts expose local profiling/elapsed timing variability; those
failures remain recorded and the cause is open. A pre-existing Admin lifecycle
save/readback guard issue is outside this bounded identity revision; the new code
save/readback path and its tests are corrected without redesigning lifecycle.
