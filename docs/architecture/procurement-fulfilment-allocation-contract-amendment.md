# PD-02.x — Procurement Fulfilment Allocation Contract Amendment

**Status:** Drafted in this PR; pending review and merge

**Domain:** Procurement

**Capability:** Allocate Planning-released dispatch requirements to supplier PO, warehouse stock, mixed fulfilment, or future production fulfilment without rewriting Planning demand and without creating physical fulfilment evidence inside Procurement.

**Amends:** `docs/architecture/procurement-domain-contract.md`

**Related decision:** `docs/decisions/decision-pd-05-dispatch-demand-fulfilment-ownership.md`

## Purpose

This amendment clarifies Procurement ownership after the corrected PD-05 Dispatch and Delivery contract.

The corrected cross-domain rule is:

```text
Planning releases what, how many, where, and by when.
Procurement allocates how the requirement will be fulfilled.
Supplier, warehouse, or future production records physical fulfilment evidence.
Dispatch confirms transport and destination outcome.
```

The existing Procurement contract already owns supplier assignment, supplier allocation, purchase allocation review, PO drafting, PO release, supplier confirmation, and revisions. This amendment makes explicit that Procurement also owns the fulfilment-allocation decision for Planning-released dispatch requirements.

## Corrected ownership

Planning owns:

- `DispatchRequirement`;
- `DispatchRequirementLine`;
- source of need, such as `SCHOOL_CATERING` or `WHOLESALE`;
- required item, quantity, unit, destination, and service/delivery date;
- Planning release status and immutable Planning trace.

Procurement owns:

- `FulfilmentAllocation`;
- `FulfilmentAllocationLine`;
- how each released requirement line will be fulfilled;
- supplier PO allocation;
- warehouse-stock allocation request;
- mixed fulfilment split;
- future production-release request reference;
- allocation status and Procurement change evidence.

The physical party owns fulfilment evidence:

- supplier receiving or cross-dock evidence for supplier-direct fulfilment;
- `WarehouseStockRelease` for warehouse-stock fulfilment;
- future `ProductionRelease` for production/kitchen output.

Dispatch owns:

- trip planning;
- load confirmation against fulfilled requirements;
- stop sequence;
- delivery confirmation;
- delivery exceptions and return evidence;
- trip closure.

## Business objects

### FulfilmentAllocation

A Procurement-owned object that states how a Planning-released `DispatchRequirement` will be fulfilled.

Typical attributes:

- `fulfilmentAllocationId`;
- `dispatchRequirementId`;
- `purchaseHandoffBatchId` or Planning release reference where applicable;
- `allocationStatus`;
- `serviceDate` or requested delivery date;
- `allocatedBy` / `allocatedAt`;
- `approvedBy` / `approvedAt` where required;
- `version`;
- Procurement trace and change evidence.

`FulfilmentAllocation` must preserve the Planning requirement reference. It may decide fulfilment source, but it must not change the Planning-required quantity, unit, destination, school, customer, or service/delivery date.

### FulfilmentAllocationLine

A Procurement-owned line showing which source will fulfil a Planning requirement line.

Typical attributes:

- `fulfilmentAllocationLineId`;
- `fulfilmentAllocationId`;
- `dispatchRequirementLineId`;
- `sourceOfNeed`: `SCHOOL_CATERING` or `WHOLESALE`;
- `itemId` / `ingredientId` / product reference;
- `requiredQuantity` and `requiredUnit` copied as immutable Planning reference;
- `allocatedQuantity` and `allocatedUnit`;
- `fulfilmentSourceType`;
- `supplierId` where supplier PO is used;
- `purchaseOrderLineId` where supplier PO is used;
- `warehouseStockRequestId` or `warehouseReservationId` where warehouse stock is used;
- future `productionReleaseRequestId` where production fulfilment is used;
- `allocationStatus`;
- `sourceTraceId`.

`FulfilmentAllocationLine` is not a PO line, warehouse stock movement, supplier receiving record, dispatch load line, QA approval, or accounting record.

## Fulfilment source types

### SUPPLIER_PO

The requirement line is fulfilled through a supplier-facing purchase order.

Procurement owns:

- supplier selection;
- PO line reference;
- supplier confirmation state;
- commercial commitment and revision history.

Procurement does not own:

- physical receiving;
- cross-dock handoff;
- goods condition evidence;
- dispatch loading.

Physical evidence should later be recorded as supplier receiving / supplier delivery / cross-dock evidence by the responsible receiving or fulfilment process.

### WAREHOUSE_STOCK

The requirement line is fulfilled from warehouse-controlled stock.

Procurement owns:

- the decision to request warehouse stock for the requirement line;
- allocated quantity and unit;
- the warehouse stock request reference.

Warehouse owns:

- stock reservation where required;
- picking;
- `WarehouseStockRelease`;
- stock movement and stock reduction;
- evidence that the warehouse fulfilled its allocated portion.

`WarehouseStockRelease` is evidence for the warehouse-stock allocation portion only. It is not the dispatch trigger and does not define the customer delivery requirement.

### MIXED

The requirement line is split across multiple fulfilment sources.

Example:

```text
Planning requirement:
35 kg rice → School A

Procurement fulfilment allocation:
25 kg → supplier PO
10 kg → warehouse stock
```

Rules:

- each allocation line must preserve the same Planning requirement line reference;
- split quantities must reconcile to the Planning-required quantity unless an approved shortage/overage policy allows otherwise;
- each physical source must later produce its own fulfilment evidence;
- Dispatch may load only quantities supported by physical fulfilment evidence.

### PRODUCTION_RELEASE — future

Future production or kitchen output may fulfil a requirement line.

This contract reserves the source type but does not implement Production, QA, kitchen execution, or production release.

## Commands

### AllocateFulfilmentForDispatchRequirement

Allocates a Planning-released dispatch requirement to fulfilment sources.

Rules:

- source `DispatchRequirement` must be released by Planning;
- each line must preserve the Planning-owned requirement quantity, unit, destination, and source trace;
- allocation source must be one of `SUPPLIER_PO`, `WAREHOUSE_STOCK`, `MIXED`, or future `PRODUCTION_RELEASE`;
- supplier PO allocation must reference a valid supplier / PO path according to Procurement lifecycle;
- warehouse-stock allocation must create or reference a warehouse stock request but must not create stock movement or release evidence;
- mixed allocation must reconcile split quantities;
- no Dispatch trip, load, delivery confirmation, warehouse stock movement, supplier receiving evidence, QA approval, production execution, invoice, settlement, or accounting entry is created.

Emits:

- `FulfilmentAllocationCreated`

### ReviseFulfilmentAllocation

Revises a fulfilment allocation before physical fulfilment evidence or according to a controlled correction path.

Rules:

- reason is required;
- previous allocation must remain traceable;
- released PO changes still use Procurement revision/cancellation paths;
- warehouse-stock allocations with stock already released require a Warehouse-owned correction path;
- dispatched or delivered quantities cannot be silently rewritten.

Emits:

- `FulfilmentAllocationRevised`

## Events

Minimum event additions:

- `FulfilmentAllocationCreated`
- `FulfilmentAllocationLineAllocated`
- `FulfilmentAllocationRevised`
- `FulfilmentAllocationReadyForEvidence`

These events carry:

- event ID;
- fulfilment allocation ID;
- requirement line IDs;
- fulfilment source type;
- supplier / PO / warehouse request references where applicable;
- allocated quantity and unit;
- actor;
- timestamp;
- reason where applicable;
- source trace.

## Lifecycle

```text
DRAFT
→ ALLOCATED
→ VALIDATED
→ READY_FOR_PHYSICAL_FULFILMENT
→ EVIDENCE_PENDING
→ EVIDENCE_RECORDED
→ READY_FOR_DISPATCH
```

Correction path:

```text
ALLOCATED / VALIDATED / READY_FOR_PHYSICAL_FULFILMENT
→ REVISED_WITH_REASON
→ ALLOCATED
```

Once physical fulfilment evidence, dispatch loading, or delivery confirmation exists, Procurement must not silently rewrite the allocation. Corrections must preserve prior allocation facts and route to the responsible domain for physical evidence or delivery outcome corrections.

## Validation blockers

Procurement fulfilment allocation must block at least:

- missing released `DispatchRequirement`;
- requirement line not released by Planning;
- missing source-of-need classification;
- missing destination/customer/school reference inherited from Planning;
- allocation quantity is negative;
- allocation quantity exceeds Planning requirement without approved overage rule;
- split quantity does not reconcile for `MIXED` fulfilment;
- supplier PO source without valid supplier / PO path;
- warehouse-stock source without warehouse request reference;
- attempt to change Planning requirement quantity, unit, destination, or source-of-need;
- attempt to create `WarehouseStockRelease` directly from Procurement;
- attempt to record supplier receiving or cross-dock physical evidence inside Procurement;
- attempt to create Dispatch load, delivery confirmation, QA approval, Production release, invoice, settlement, or accounting entry.

## Read-model implication

The Procurement workbench should eventually answer an additional decision question:

```text
How will each Planning-released dispatch requirement be fulfilled?
```

It should show:

- dispatch requirement reference;
- source of need: school catering or wholesale;
- required quantity and destination from Planning;
- fulfilment source split;
- supplier / PO references;
- warehouse stock request references;
- allocation readiness;
- physical evidence status as read-only downstream evidence;
- blockers and warnings.

The read model must not let Procurement operators edit Planning requirement quantities, create Warehouse stock movements, or confirm Dispatch delivery.

## Boundary with PD-05 Dispatch

Dispatch consumes:

```text
DispatchRequirement
+ FulfilmentAllocation
+ FulfilmentEvidence
```

Dispatch does not decide fulfilment source. If evidence is missing, Dispatch shows a blocker or warning; it does not allocate supplier or warehouse stock on its own.

## OPS v1 evidence

OPS v1 already separates the business rule in practice:

- Planning finalizes what and how many go where;
- Procurement finalizes what and how many from PO / supplier / warehouse stock fulfil the requirement;
- Warehouse confirms physical fulfilment only when warehouse stock is used;
- Dispatch confirms movement and destination outcome.

Retool pages and Supabase structures remain qualitative evidence only. This amendment does not copy Retool page structure or create a final Supabase schema.

## Scope exclusions

This amendment adds no:

- TypeScript implementation;
- React UI;
- tests;
- Supabase migration;
- PostgreSQL schema;
- RLS;
- RPC;
- Edge Function;
- backend integration;
- credentials;
- production data;
- Retool change;
- Planning recalculation;
- Warehouse implementation;
- Dispatch implementation;
- Production/QA;
- Finance/Accounting;
- route optimization;
- GPS/live tracking;
- generic workflow engine.

## Recommended next step

After this amendment is reviewed and merged, the next Dispatch foundation should consume the corrected chain:

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

No Dispatch implementation should create Procurement fulfilment allocation internally.
