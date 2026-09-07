# PD-05 — Dispatch and Delivery Domain Contract

**Status:** Amended after product-owner review; pending review and merge

**Domain:** Dispatch and Delivery

**Capability:** Move planning-released delivery requirements to kitchens, schools, wholesale customers, and other approved destinations with explicit fulfilment evidence, loading, delivery, exception, return, and closure handling.

**Upstream evidence:** OPS v1 Supabase + Retool exports may be used as qualitative business evidence only.

**Architecture baseline:** ARCH-001 — OPS ERP Business Architecture; ARCH-002 — Atlas System Map

## Product-owner correction

The original PD-05 contract was too warehouse-centric. It incorrectly implied that every dispatch starts from a `WarehouseRelease`.

The corrected ownership rule is:

```text
Planning releases what, how many, and where goods must go.
Procurement decides how the released requirement will be fulfilled.
Warehouse only confirms the portion it fulfils from warehouse-controlled stock.
Dispatch transports fulfilled requirements and confirms destination outcomes.
```

`WarehouseRelease` remains valid, but only as one fulfilment-evidence type. It must not become the mandatory dispatch trigger.

## Mission

Dispatch and Delivery coordinates the physical movement of goods after Planning has released a delivery obligation and Procurement has allocated fulfilment. It converts a planning-owned `DispatchRequirement`, procurement-owned fulfilment allocation, and physical fulfilment evidence into trip/load execution, stop-level delivery outcomes, exceptions, returns, and closure evidence.

Dispatch answers:

```text
Which planning-released requirements need transport?
Which fulfilment evidence is available for loading?
Who or what route is responsible?
What was loaded?
What was delivered?
What failed, returned, or remained unresolved?
What evidence proves destination outcome?
```

## Corrected source-of-need model

The form and contract must adapt to the source of need. Planning is the owner of the delivery obligation, but the source of that obligation may differ.

```text
Source of need
├── SCHOOL_CATERING
└── WHOLESALE
```

For school catering, the requirement may trace to:

```text
schoolId
serviceDate
meal/session
weekly menu
attendance
recipeVersionId / BOM
Need Generation / Confirmed Need / Purchase Handoff trace
```

For wholesale, the requirement may trace to:

```text
customerId
customer order reference
requested product/item lines
manual quantity and unit
requested delivery date/location
```

Both sources must converge into the same Planning-owned dispatch requirement shape before Procurement fulfilment and Dispatch execution.

```text
School catering need ─┐
                      ├─→ DispatchRequirement
Wholesale need ───────┘
```

## Critical boundary

Planning confirms:

```text
What must go where, by when, and in what quantity.
```

Procurement confirms:

```text
How the requirement will be fulfilled, including supplier PO and/or warehouse-stock allocation.
```

Warehouse confirms only when responsible for warehouse-controlled stock:

```text
The warehouse-stock portion was issued from warehouse custody as evidence of fulfilling the allocated requirement.
```

Dispatch and Delivery confirms:

```text
Fulfilled goods were loaded, transported, delivered, failed, returned, or otherwise resolved at destination.
```

These are separate business facts. `WarehouseRelease` is not a dispatch requirement. `DeliveryConfirmation` is not a warehouse stock movement. Procurement allocation is not physical fulfilment evidence.

## Corrected end-to-end flow

```text
Planning
→ DispatchRequirement
→ Procurement FulfilmentAllocation
→ Physical fulfilment evidence
   ├── SupplierReceivingEvidence / SupplierDeliveryEvidence
   ├── WarehouseStockRelease
   └── Future ProductionRelease
→ DispatchLoad
→ DispatchTrip
→ DeliveryConfirmation / DeliveryException
→ Trip closure
```

## Ownership and boundaries

### Planning owns delivery obligation

Planning owns:

- source-of-need classification;
- school-catering or wholesale demand reference;
- destination/customer/school requirement;
- required item, quantity, and unit;
- service date or requested delivery date;
- requirement release status;
- Planning trace and release evidence.

Planning does not own supplier assignment, PO fulfilment, warehouse stock release, dispatch loading, driver trip execution, or destination confirmation.

### Procurement owns fulfilment allocation

Procurement owns:

- allocation of a Planning requirement to supplier PO, warehouse stock, or mixed fulfilment;
- supplier and PO references;
- requested stock-from-warehouse quantity when warehouse stock is used;
- fulfilment readiness policy;
- supplier confirmation / procurement fulfilment context where applicable.

Procurement does not own physical warehouse stock movement, supplier receiving evidence, driver loading, trip execution, or destination delivery confirmation.

### Warehouse owns warehouse-stock fulfilment evidence

Warehouse owns:

- receiving evidence where goods physically arrive at warehouse or staging area;
- stock custody;
- stock reservation where warehouse stock is allocated;
- picking where storage stock is used;
- `WarehouseStockRelease` as evidence that the warehouse fulfilled its allocated portion;
- return-to-stock confirmation where returned goods re-enter warehouse custody.

Warehouse does not own Planning dispatch requirements, Procurement allocation, driver trip execution, or destination delivery confirmation.

### Dispatch owns transport and destination outcome

Dispatch owns:

- dispatch plan;
- dispatch trip;
- trip assignment references;
- load confirmation against fulfilled requirements;
- delivery stop sequence;
- destination delivery confirmation;
- failed delivery, shortage, refusal, damage, or return evidence;
- dispatch and delivery status changes;
- dispatch closure.

Dispatch does not own:

- Admin school, ingredient, recipe, supplier, or delivery-location master data;
- Planning demand approval, Need Generation, Confirmed Need, or Purchase Handoff release;
- Procurement supplier allocation, purchase commitments, PO release, or supplier confirmation;
- Warehouse receiving, stock lots, stock movement, picking, or warehouse stock release;
- Production execution, kitchen portioning, QA approval, or food-safety inspection;
- Finance/Accounting invoices, settlement, costing, or accounting entries;
- HR/payroll, vehicle maintenance, routing optimization, GPS/live tracking, Supabase migrations, backend persistence, credentials, production data, or Retool changes in the prototype stage.

## Upstream inputs

Dispatch consumes approved references and snapshots. It does not rewrite them.

Minimum upstream inputs:

- `DispatchRequirement` — Planning-owned delivery obligation.
- `DispatchRequirementLine` — item/product/ingredient, required quantity, unit, destination, source-of-need trace.
- `FulfilmentAllocation` — Procurement-owned sourcing decision for the requirement line.
- `FulfilmentAllocationLine` — supplier PO, warehouse stock, mixed, or future production fulfilment allocation.
- `FulfilmentEvidence` — physical evidence that the allocated quantity is available to load.
- Admin school/customer reference — destination identity and active/inactive status.
- Admin delivery-location reference — stable destination reference.
- Admin operational notes — delivery constraints, contact references, gate notes, or service rules.
- Planning, Procurement, Warehouse, recipe, and PO references — trace context only, not mutable source facts.

`WarehouseRelease`, `WarehouseReleaseLine`, and `WarehouseHandoffEvidence` are accepted only when the fulfilment allocation uses warehouse-controlled stock. They are not mandatory for supplier-direct, cross-dock, or future production fulfilment.

## Business objects

### DispatchRequirement

A Planning-owned delivery obligation stating what must be delivered, where, when, and in what quantity.

Typical attributes:

- dispatchRequirementId;
- sourceOfNeed: `SCHOOL_CATERING` or `WHOLESALE`;
- serviceDate or requestedDeliveryDate;
- schoolId/customerId;
- deliveryLocationId;
- requirementStatus;
- planningReleaseId/reference;
- source trace.

### DispatchRequirementLine

A line-level requirement released by Planning.

Typical attributes:

- dispatchRequirementLineId;
- dispatchRequirementId;
- item/product/ingredient reference;
- requiredQuantity;
- requiredUnit;
- destination stop reference where known;
- source-of-need trace;
- immutable Planning release snapshot.

### FulfilmentAllocation

A Procurement-owned plan for how a DispatchRequirement will be fulfilled.

Typical attributes:

- fulfilmentAllocationId;
- dispatchRequirementId;
- allocationStatus;
- allocatedBy/allocatedAt;
- procurement trace;
- readiness state.

### FulfilmentAllocationLine

Line-level allocation showing which physical source will fulfil a requirement quantity.

Typical attributes:

- fulfilmentAllocationLineId;
- dispatchRequirementLineId;
- fulfilmentSourceType: `SUPPLIER_PO`, `WAREHOUSE_STOCK`, `MIXED`, or future `PRODUCTION_RELEASE`;
- supplierId where applicable;
- purchaseOrderLineId where applicable;
- warehouseStockReservationId / warehouseReleaseId where applicable;
- allocatedQuantity;
- allocatedUnit.

### FulfilmentEvidence

An abstract evidence category proving that a fulfilment allocation is physically ready for dispatch loading.

Allowed evidence examples:

- `SupplierReceivingEvidence` — supplier-delivered goods physically received or staged for dispatch;
- `SupplierDeliveryEvidence` — supplier direct/cross-dock fulfilment accepted for dispatch;
- `WarehouseStockRelease` — warehouse stock issued on behalf of a Procurement allocation;
- future `ProductionRelease` — production/kitchen output released for dispatch.

Fulfilment evidence must point back to the fulfilment allocation line it satisfies. It does not change the Planning requirement quantity or Procurement allocation quantity.

### DispatchPlan

A plan grouping Planning-released requirements and fulfilled quantities into planned trips for a service day, customer group, route, or dispatch wave.

Typical attributes:

- dispatchPlanId;
- serviceDate;
- planningWindow or dispatchWave;
- dispatchRequirementIds;
- fulfilmentAllocationIds;
- planStatus;
- createdBy/createdAt;
- audit notes.

### DispatchTrip

A specific movement execution unit under a DispatchPlan.

Typical attributes:

- dispatchTripId;
- dispatchPlanId;
- tripStatus;
- assigned route/reference;
- driverAssignmentId/reference;
- vehicleAssignmentId/reference;
- departure timestamp;
- completion timestamp;
- unresolved exception count.

### DispatchStop

A destination stop within a DispatchTrip.

Typical attributes:

- dispatchStopId;
- dispatchTripId;
- stopSequence;
- schoolId/customerId;
- deliveryLocationId;
- plannedArrivalWindow;
- stopStatus;
- deliveryConfirmationId where applicable.

### DispatchLoad

The load record confirming that fulfilled requirement quantities were accepted for dispatch movement.

Typical attributes:

- dispatchLoadId;
- dispatchTripId;
- dispatchRequirementId;
- fulfilmentAllocationId;
- loadedBy/acceptedBy references;
- loadedAt;
- loadStatus.

### DispatchLoadLine

A line-level loaded quantity corresponding to a DispatchRequirementLine and one or more fulfilment evidence records.

Typical attributes:

- dispatchLoadLineId;
- dispatchLoadId;
- dispatchRequirementLineId;
- fulfilmentAllocationLineId;
- fulfilmentEvidenceId;
- item/product/ingredient reference;
- loadedQuantity;
- loadedUnit;
- source trace;
- target stop/destination reference.

### DriverAssignment / VehicleAssignment

References used by Dispatch to identify the person or vehicle responsible for a trip. These are references only. PD-05 does not manage HR, payroll, licensing, fleet maintenance, fuel, or GPS tracking.

### DeliveryConfirmation

Stop-level evidence that goods were delivered, partially delivered, rejected, or otherwise resolved at destination.

Typical attributes:

- deliveryConfirmationId;
- dispatchStopId;
- confirmedAt;
- confirmedBy;
- receivedBy/reference;
- deliveryOutcome;
- deliveryEvidenceIds;
- notes.

### DeliveryConfirmationLine

Line-level delivered quantity corresponding to a DispatchLoadLine.

Typical attributes:

- deliveryConfirmationLineId;
- deliveryConfirmationId;
- dispatchLoadLineId;
- deliveredQuantity;
- returnedQuantity;
- exceptionQuantity;
- unit;
- evidence reference.

### DeliveryException

A recorded delivery problem requiring resolution before trip closure or later investigation.

Examples:

- destination closed;
- receiver unavailable;
- shortage;
- overage;
- damaged goods;
- refused goods;
- wrong location;
- late delivery;
- temperature/condition concern where QA is notified but not approved by Dispatch.

### ReturnToWarehouse / ReturnEvidence

Evidence that goods not delivered, refused, or otherwise unresolved were returned to warehouse custody or handed to an approved resolution path. This does not by itself create a Warehouse stock movement; Warehouse must confirm any stock re-entry through Warehouse-owned commands.

### DeliveryEvidence

Proof attached to a delivery, exception, or return.

Examples:

- receiver signature/reference;
- timestamp;
- photo reference;
- note;
- handover confirmation;
- exception attachment reference.

### DispatchStatusChange

Auditable event for changing plan, trip, stop, load, delivery, or exception status.

### DispatchAuditEvent

Append-only operational evidence for dispatch decisions, handoffs, edits, and exception handling.

## Commands

Planning-side and Procurement-side commands are listed here as upstream contract references, not Dispatch-owned commands:

- `ReleaseDispatchRequirement` — Planning-owned.
- `AllocateFulfilmentForDispatchRequirement` — Procurement-owned.
- `RecordFulfilmentEvidence` — owned by the physically responsible party: supplier receiving/cross-dock, Warehouse, or future Production.

Dispatch-owned commands:

- `CreateDispatchPlanFromRequirements`
- `AssignDispatchTrip`
- `AssignDriverOrVehicleReference`
- `ConfirmDispatchLoad`
- `RecordDispatchDeparture`
- `ConfirmDeliveryStop`
- `RecordDeliveryException`
- `RecordReturnToWarehouse`
- `CompleteDispatchTrip`
- `RecordDispatchAuditEvent`

## Events

Upstream events consumed by Dispatch:

- `DispatchRequirementReleased`
- `FulfilmentAllocationCreated`
- `FulfilmentEvidenceRecorded`
- `WarehouseStockReleased` where warehouse stock is used
- `SupplierReceivingEvidenceRecorded` where supplier or cross-dock fulfilment is used

Dispatch-owned events:

- `DispatchPlanCreated`
- `DispatchTripAssigned`
- `DriverVehicleReferenceAssigned`
- `DispatchLoadConfirmed`
- `DispatchDeparted`
- `DeliveryStopConfirmed`
- `DeliveryExceptionRecorded`
- `ReturnToWarehouseRecorded`
- `DispatchTripCompleted`
- `DispatchAuditEventRecorded`

## Lifecycle

### DispatchRequirement

```text
DRAFT
→ RELEASED_BY_PLANNING
→ ALLOCATED_FOR_FULFILMENT
→ FULFILMENT_READY
→ DISPATCHED
→ DELIVERED / CLOSED_WITH_EXCEPTION
```

Planning owns release. Procurement owns allocation. Dispatch owns dispatched and delivery outcome states. No domain may silently rewrite another domain's released fact.

### DispatchPlan / DispatchTrip

```text
PLANNED
→ ASSIGNED
→ LOADED
→ IN_TRANSIT
→ PARTIALLY_DELIVERED
→ DELIVERED
→ CLOSED_WITH_EXCEPTION
```

Allowed closure outcomes:

- `DELIVERED` — all required stops and lines have acceptable confirmations.
- `CLOSED_WITH_EXCEPTION` — one or more lines or stops remain exception-resolved with evidence.
- `CANCELLED` — trip was cancelled before departure with explicit reason and no hidden Warehouse or Planning mutation.
- `VOIDED` — administrative correction where the dispatch record is invalid and must be superseded; voiding must be auditable and cannot delete history.

### DeliveryStop

```text
PENDING
→ LOADED
→ IN_TRANSIT
→ DELIVERED
→ PARTIALLY_DELIVERED
→ FAILED
→ RETURNED
→ RESOLVED_WITH_EXCEPTION
```

## Validation blockers

Dispatch commands must block at least:

- missing `DispatchRequirement` reference;
- DispatchRequirement not released by Planning;
- missing source-of-need classification;
- missing destination/customer/school reference;
- missing delivery location;
- inactive school/customer or delivery location without explicit override evidence;
- missing Procurement fulfilment allocation;
- fulfilment allocation quantity less than required quantity where full dispatch is required;
- fulfilment allocation references Supplier PO but has no supplier receiving/cross-dock evidence where evidence is required;
- fulfilment allocation references Warehouse stock but has no WarehouseStockRelease evidence;
- WarehouseStockRelease used for a line not allocated to warehouse stock;
- missing dispatch trip assignment when required;
- missing driver/vehicle reference when required;
- load confirmation without valid fulfilment evidence;
- loaded quantity greater than fulfilled quantity;
- delivered quantity greater than loaded quantity;
- delivered quantity plus returned/exception quantity not reconciling to loaded quantity where closure requires reconciliation;
- delivery confirmation without evidence where evidence is required;
- closing a trip with unresolved exceptions;
- return recorded without return evidence;
- attempting to change Planning requirement quantity by editing Dispatch;
- attempting to change Procurement allocation or PO by editing Dispatch;
- attempting to change Warehouse stock movement by editing Dispatch;
- attempting to treat Dispatch confirmation as Warehouse receipt, QA approval, Production execution approval, Procurement confirmation, or Finance/Accounting settlement.

## Warnings

Dispatch may warn without blocking where appropriate:

- source of need is wholesale and delivery requirements were manually entered;
- source of need is school catering and delivery requirements trace to a recent menu or attendance change;
- delivery location has operational notes requiring manual review;
- planned stop sequence differs from the usual route pattern;
- driver or vehicle reference is manually entered rather than selected from future master data;
- supplier/cross-dock fulfilment was received close to dispatch departure time;
- delivery confirmation was late but still accepted;
- partial delivery has a linked exception and return path;
- destination accepted goods with note requiring downstream review.

## Future read model

`DispatchDeliveryWorkbench`

Decision questions:

```text
Are Planning-released requirements fulfilled, assigned, loaded, delivered, or unresolved?
Which stops require operator attention before the trip can close?
```

The workbench should show:

- source of need: school catering or wholesale;
- dispatch requirement and line status;
- Planning release reference;
- Procurement fulfilment allocation;
- supplier PO / warehouse stock / future production source;
- fulfilment evidence readiness;
- dispatch plan and trip status;
- load lines and source trace;
- stop sequence;
- destination/customer/school;
- delivery location and operational notes;
- required vs allocated vs fulfilled vs loaded vs delivered vs returned vs exception quantities;
- driver/vehicle reference;
- delivery evidence;
- unresolved blockers and warnings;
- downstream boundary note.

Boundary note:

```text
Dispatch confirms transport and destination outcome. Planning owns the delivery requirement. Procurement owns fulfilment allocation. Warehouse owns warehouse-stock release evidence only when warehouse stock is used. Dispatch does not rewrite Warehouse stock, Planning demand, Procurement commitments, Admin master data, QA approval, Production execution, or Finance/Accounting settlement.
```

## Cross-domain trace rules

Dispatch records must preserve enough upstream identifiers to support traceability:

- dispatchRequirementId;
- dispatchRequirementLineId;
- sourceOfNeed;
- planningReleaseId / confirmedNeedLineId / purchaseHandoffLineId where applicable;
- wholesale customer order reference where applicable;
- fulfilmentAllocationId;
- fulfilmentAllocationLineId;
- fulfilmentEvidenceId;
- supplierReceivingEvidenceId / supplierDeliveryEvidenceId where applicable;
- warehouseReleaseId / warehouseReleaseLineId / warehouseHandoffEvidenceId where warehouse stock is used;
- goodsReceiptLineId / stockLotId where available from Warehouse snapshot;
- procurement commitment or PO reference where already present in fulfilment allocation trace;
- schoolId/customerId;
- deliveryLocationId.

Dispatch may copy immutable snapshot fields needed for delivery evidence, but it must not mutate upstream source records.

## OPS v1 and Retool boundary

OPS v1 Retool screens/apps are evidence of current operations only. The existing OPS v1 pattern already distinguishes Planning finalization, Procurement fulfilment, and physical receiving/release evidence. The Atlas contract must preserve that business rule rather than forcing every dispatch line through Warehouse.

This contract does not add Retool code, Retool queries, Retool pages, or Retool integration.

## Technology boundary

This contract adds no implementation. Future production work must be separately approved for:

- database schema;
- backend commands;
- transaction boundaries;
- authorization and RLS;
- idempotency;
- audit retention;
- file/evidence storage;
- external notification or route integration.

## MVP exclusions

PD-05 does not include:

- automatic route optimization;
- GPS/live tracking;
- driver payroll;
- vehicle maintenance;
- fuel management;
- finance settlement;
- QA approval;
- production execution;
- warehouse stock re-entry after return without Warehouse-owned confirmation;
- making WarehouseRelease mandatory for supplier-direct or cross-dock dispatch lines.

## Recommended next step

After this amendment is reviewed and merged, create a bounded in-memory Dispatch and Delivery foundation. The first implementation should prove only the minimum corrected flow:

```text
DispatchRequirement
→ FulfilmentAllocation
→ FulfilmentEvidence
→ DispatchPlan
→ DispatchTrip
→ DispatchLoad
→ DeliveryStop
→ DeliveryConfirmation / DeliveryException
→ Trip closure
```

The foundation must include at least two source examples:

- school catering requirement;
- wholesale requirement.

It must also include at least two fulfilment examples:

- supplier/cross-dock fulfilment evidence;
- warehouse-stock release evidence.

No backend persistence or production-data integration should be added until the in-memory foundation and integration review prove the domain boundary.

## D-044 bounded School PXK amendment

The connected School workflow adds one pre-transport release aggregate at
`service_date + school_id + delivery_location_id`. Its derived preview answers what
the School must receive from current Confirmed Need, while exact allocation and
released supplier-PO sources prove that current supplier commitments cover it.

Explicit `ReleaseSchoolDispatchDocument` generates immutable header, line, display
snapshot, and typed source evidence. A correction derives replacement-required; the
prior PXK remains current until explicit successor release atomically supersedes it.
Both numbers and contents remain exportable. This amendment does not invoke or
require `DispatchPlan`, `DispatchTrip`, `DispatchLoad`, receipt, cross-dock, stock,
lot, reservation, pick, vehicle, or driver facts and does not alter the older
supplier-direct execution contracts above.
