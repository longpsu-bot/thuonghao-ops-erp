# PD-05 — Dispatch and Delivery Domain Contract

**Status:** Drafted in this PR; pending review and merge

**Domain:** Dispatch and Delivery

**Capability:** Move warehouse-released goods to kitchens, schools, and other approved destinations with explicit load, delivery, exception, return, and evidence handling.

**Upstream evidence:** OPS v1 Supabase + Retool exports may be used as qualitative business evidence only.

**Architecture baseline:** ARCH-001 — OPS ERP Business Architecture; ARCH-002 — Atlas System Map

## Mission

Dispatch and Delivery coordinates the post-warehouse physical movement of goods. It converts a confirmed `WarehouseRelease` and warehouse handoff evidence into assigned trips, loaded goods, stop-level delivery outcomes, exceptions, returns, and closure evidence.

Dispatch answers:

```text
Which released goods need to be moved?
Who or what route is responsible?
What was loaded?
What was delivered?
What failed, returned, or remained unresolved?
What evidence proves custody changed after Warehouse release?
```

## Critical boundary

Warehouse confirms:

```text
Goods left warehouse-controlled stock custody.
```

Dispatch and Delivery confirms:

```text
Goods were transported and delivered, failed, returned, or otherwise resolved at destination.
```

These are separate business facts. `WarehouseRelease` is not a destination delivery confirmation. `DeliveryConfirmation` is not a warehouse stock movement.

## Upstream inputs

Dispatch consumes approved references and snapshots. It does not rewrite them.

Minimum upstream inputs:

- `WarehouseRelease` — evidence that goods were released from controlled warehouse custody.
- `WarehouseReleaseLine` — released item, quantity, unit, lot/source trace, and fulfilment target.
- `WarehouseHandoffEvidence` — who accepted custody after warehouse release and when.
- Admin school/customer reference — destination identity and active/inactive status.
- Admin delivery-location reference — stable destination reference.
- Admin operational notes — delivery constraints, contact references, gate notes, or service rules.
- Planning, Procurement, and recipe references — trace context only, not mutable source facts.

Optional future inputs may include driver, vehicle, or route master data, but PD-05 does not create HR, payroll, vehicle maintenance, routing optimization, or GPS/live tracking domains.

## Ownership and boundaries

Dispatch owns:

- dispatch plan;
- dispatch trip;
- trip assignment references;
- load confirmation from warehouse handoff;
- delivery stop sequence;
- destination delivery confirmation;
- failed delivery, shortage, refusal, damage, or return evidence;
- dispatch and delivery status changes;
- dispatch closure.

Dispatch does not own:

- Admin school, ingredient, recipe, supplier, or delivery-location master data;
- Planning demand approval or Need Generation;
- Procurement supplier allocation, purchase commitments, PO release, or supplier confirmation;
- Warehouse receiving, stock lots, stock movement, picking, or warehouse release;
- Production execution, kitchen portioning, QA approval, or food-safety inspection;
- Finance/Accounting invoices, settlement, costing, or accounting entries;
- HR/payroll, vehicle maintenance, routing optimization, GPS/live tracking, Supabase migrations, backend persistence, credentials, production data, or Retool changes in the prototype stage.

## Business objects

### DispatchPlan

A plan grouping one or more warehouse releases into planned trips for a service day, customer group, route, or dispatch wave.

Typical attributes:

- dispatchPlanId;
- serviceDate;
- planningWindow or dispatchWave;
- sourceWarehouseId/reference;
- warehouseReleaseIds;
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

The load record confirming that Warehouse-released goods were accepted for dispatch movement.

Typical attributes:

- dispatchLoadId;
- dispatchTripId;
- warehouseReleaseId;
- warehouseHandoffEvidenceId;
- loadedBy/acceptedBy references;
- loadedAt;
- loadStatus.

### DispatchLoadLine

A line-level loaded quantity derived from `WarehouseReleaseLine`.

Typical attributes:

- dispatchLoadLineId;
- dispatchLoadId;
- warehouseReleaseLineId;
- item/ingredient/product reference;
- loadedQuantity;
- loadedUnit;
- lot/source trace;
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

- `CreateDispatchPlanFromWarehouseRelease`
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

- missing `WarehouseRelease` reference;
- WarehouseRelease not released from warehouse custody;
- missing Warehouse handoff evidence;
- missing destination/customer/school reference;
- missing delivery location;
- inactive school or delivery location without explicit override evidence;
- missing dispatch trip assignment when required;
- missing driver/vehicle reference when required;
- load confirmation without a valid WarehouseReleaseLine;
- delivered quantity greater than loaded quantity;
- delivered quantity plus returned/exception quantity not reconciling to loaded quantity where closure requires reconciliation;
- delivery confirmation without evidence where evidence is required;
- closing a trip with unresolved exceptions;
- return recorded without return evidence;
- attempting to change Warehouse stock movement by editing Dispatch;
- attempting to treat Dispatch confirmation as Warehouse receipt, QA approval, Production execution approval, Procurement confirmation, or Finance/Accounting settlement.

## Warnings

Dispatch may warn without blocking where appropriate:

- delivery location has operational notes requiring manual review;
- planned stop sequence differs from the usual route pattern;
- driver or vehicle reference is manually entered rather than selected from future master data;
- delivery confirmation was late but still accepted;
- partial delivery has a linked exception and return path;
- destination accepted goods with note requiring downstream review.

## Future read model

`DispatchDeliveryWorkbench`

Decision questions:

```text
Are released goods assigned, loaded, delivered, or unresolved?
Which stops require operator attention before the trip can close?
```

The workbench should show:

- dispatch plan and trip status;
- WarehouseRelease and WarehouseHandoffEvidence references;
- load lines and source trace;
- stop sequence;
- destination/customer/school;
- delivery location and operational notes;
- loaded vs delivered vs returned vs exception quantities;
- driver/vehicle reference;
- delivery evidence;
- unresolved blockers and warnings;
- downstream boundary note.

Boundary note:

```text
Dispatch confirms transport and destination outcome. It does not rewrite Warehouse stock, Planning demand, Procurement commitments, Admin master data, QA approval, Production execution, or Finance/Accounting settlement.
```

## Cross-domain trace rules

Dispatch records must preserve enough upstream identifiers to support traceability:

- warehouseReleaseId;
- warehouseReleaseLineId;
- warehouseHandoffEvidenceId;
- goodsReceiptLineId / stockLotId where available from Warehouse snapshot;
- procurement commitment or PO reference where already present in Warehouse release trace;
- confirmedNeedLineId / purchaseHandoffLineId where already present in upstream trace;
- schoolId/customerId;
- deliveryLocationId.

Dispatch may copy immutable snapshot fields needed for delivery evidence, but it must not mutate upstream source records.

## OPS v1 and Retool boundary

OPS v1 Retool screens/apps are evidence of current operations only. They are not the target domain architecture. This contract does not add Retool code, Retool queries, Retool pages, or Retool integration.

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
- warehouse stock re-entry after return without Warehouse-owned confirmation.

## Recommended next step

After this contract is reviewed and merged, create a bounded in-memory Dispatch and Delivery foundation. The first implementation should prove only the minimum flow:

```text
WarehouseRelease
→ DispatchPlan
→ DispatchTrip
→ DispatchLoad
→ DeliveryStop
→ DeliveryConfirmation / DeliveryException
→ Trip closure
```

No backend persistence or production-data integration should be added until the in-memory foundation and integration review prove the domain boundary.