# PD-03 — Warehouse Domain Contract

**Status:** Drafted in this PR; pending review and merge

**Domain:** Warehouse

**Upstream domain:** Procurement

**Downstream domains:** Dispatch and Delivery, Production and Quality, Finance/Reporting through read models only

**Architecture baseline:** ARCH-001 — OPS ERP Business Architecture; ARCH-002 — Atlas System Map

## Purpose

Warehouse converts supplier-confirmed Procurement commitments and physical goods arrival into controlled stock evidence and warehouse release decisions.

Core rule:

```text
Supplier-confirmed Procurement commitment
+ physical receiving evidence
+ discrepancy handling
= controlled warehouse stock and fulfilment readiness
```

Warehouse does not decide what should be purchased, who the supplier is, what the supplier committed to deliver, or how payable/accounting treatment is calculated. It records what physically arrived, what was accepted, what was rejected or short, what stock identity was created, and what can be picked or released for downstream fulfilment.

## Ownership and boundaries

Warehouse owns:

- goods receipt from supplier commitments;
- receiving session and receiving line evidence;
- accepted, rejected, missing, excess, and substituted quantities observed at receiving;
- lot/batch/stock identity where relevant;
- stock availability and warehouse location visibility;
- quarantine / hold markers for goods that cannot be used yet;
- internal fulfilment requests and reservation decisions after receiving;
- picking, packing, and warehouse release readiness for Dispatch or Production;
- warehouse stock count and inventory adjustment evidence;
- warehouse discrepancy history and operator audit trail.

Warehouse does not own:

- Planning demand, menus, attendance, recipes, or BOM decisions;
- Confirmed Need or Purchase Handoff quantities;
- supplier assignment or purchase allocation;
- supplier-facing PO creation, release, confirmation, replacement, or cancellation;
- supplier commercial policy, pricing approval, payable, invoice, settlement, or accounting entry;
- QA inspection result authority, food-safety approval, or corrective-action ownership;
- Dispatch route planning, driver handoff, delivery confirmation, or returns execution;
- production/kitchen execution or portioning;
- Retool diagnostic apps or OPS v1 table shapes.

## Required upstream input snapshot

Warehouse may start receiving only from a Procurement output that represents a supplier-confirmed commitment ready for Warehouse handoff.

Minimum upstream snapshot:

```text
Purchase Order
- purchaseOrderId
- purchaseOrderVersion
- status = READY_FOR_WAREHOUSE_RECEIVING or equivalent released-and-confirmed marker
- supplierId
- supplier confirmation reference
- release snapshot reference
- service period / delivery date
- delivery requirement

Purchase Order Line
- purchaseOrderLineId
- purchaseAllocationLineId
- purchaseHandoffLineId
- confirmedNeedLineId
- needGenerationRunId or equivalent source reference
- planningInputSetId or equivalent source reference
- sourceTraceId
- ingredientId
- ordered / supplier-confirmed quantity
- purchase unit
- delivery location reference
```

Warehouse must preserve those upstream references on every receiving and stock line. Warehouse may record physical receiving results against the upstream line, but it must not rewrite Procurement's supplier commitment or Planning's approved demand.

## Business objects

### ReceivingPlan

A non-authoritative worklist derived from supplier-confirmed Procurement commitments. It helps operators see what is expected to arrive.

It is not a PO, not a supplier confirmation, and not stock.

### ReceivingSession

A controlled event representing one warehouse receiving operation. It records who received, when, where, from which supplier, and against which Procurement commitment.

### ReceivingLine

Line-level physical receiving evidence against a purchase order line. It records expected quantity, received quantity, accepted quantity, rejected quantity, missing quantity, excess quantity, substitution notes, and discrepancy status.

### GoodsReceipt

The released receiving document. It is the warehouse evidence that goods were physically received and accepted/rejected under a controlled receiving session.

A GoodsReceipt may create stock for accepted quantities. It must preserve the supplier-confirmed PO references and receiving evidence.

### WarehouseDiscrepancy

A controlled exception record for shortage, overage, damage, wrong item, unit mismatch, late delivery, missing supplier document, or other receiving problem.

Warehouse records the discrepancy. Resolution may require Procurement, QA, Finance, or Dispatch depending on the issue, but Warehouse does not silently fix upstream commitments.

### StockLot / StockPosition

Warehouse-owned stock identity and availability. It records ingredient, accepted quantity, unit, storage location, lot/batch/expiry where applicable, source GoodsReceipt, source PO line, and stock status.

### StockReservation

A warehouse decision to reserve available stock for an internal fulfilment request, production need, school/kitchen requirement, or dispatch preparation.

### PickList

A warehouse work instruction to pick stock for a downstream fulfilment target. It is not a Dispatch route and does not confirm delivery.

### PickLine

Line-level picking instruction and execution evidence. It records required, reserved, picked, short, substituted, or cancelled quantities.

### WarehouseRelease

A controlled release from Warehouse to the next domain. It may release goods to Dispatch, Production, or another approved downstream fulfilment process.

WarehouseRelease is a warehouse handoff document. It does not confirm delivery, production usage, QA approval, invoice, or accounting settlement.

### InventoryAdjustment

A controlled stock correction for count difference, damage, expiry, write-off, unit conversion correction, or other approved inventory adjustment.

### StockCount

A warehouse stock verification event. It records counted quantities, variances, and adjustment recommendations.

### WarehouseIssue

A blocker or warning that prevents or qualifies a warehouse action.

### WarehouseChange

Append-only event/audit record for warehouse command execution, status changes, discrepancy creation/resolution markers, release, cancellation, and adjustment.

## Lifecycles

### ReceivingSession lifecycle

```text
PREPARED
→ IN_PROGRESS
→ VALIDATED
→ RELEASED_AS_GOODS_RECEIPT
```

Correction path:

```text
VALIDATED or RELEASED_AS_GOODS_RECEIPT
→ REOPENED with reason
→ IN_PROGRESS or CORRECTED
→ VALIDATED
```

Cancellation path:

```text
PREPARED or IN_PROGRESS
→ CANCELLED with reason
```

### GoodsReceipt lifecycle

```text
DRAFT
→ VALIDATED
→ RELEASED
```

After release, a GoodsReceipt must not be silently rewritten. Corrections require an explicit correction, reversal, or adjustment path with audit history.

### StockLot / StockPosition lifecycle

```text
PENDING_ACCEPTANCE
→ AVAILABLE
→ RESERVED
→ PICKED
→ RELEASED
```

Exception statuses:

```text
ON_HOLD
QUARANTINED
DAMAGED
EXPIRED
ADJUSTED
CANCELLED
```

### PickList lifecycle

```text
PREPARED
→ VALIDATED
→ PICKING
→ PICKED
→ RELEASED_FROM_WAREHOUSE
```

Correction path:

```text
PICKING or PICKED
→ REOPENED with reason
→ PICKING
```

### InventoryAdjustment lifecycle

```text
DRAFT
→ VALIDATED
→ APPROVED
→ POSTED
```

Inventory adjustment is warehouse-owned stock correction evidence. It must not redefine upstream Procurement or Planning facts.

## Commands

Warehouse commands must be explicit and auditable.

### Receiving commands

- `CreateReceivingSessionFromSupplierConfirmedPO`
- `StartReceivingSession`
- `RecordReceivingLine`
- `RecordReceivingDiscrepancy`
- `ValidateReceivingSession`
- `ReleaseGoodsReceipt`
- `ReopenReceivingSession`
- `CancelReceivingSession`

### Stock commands

- `CreateStockFromGoodsReceipt`
- `PlaceStockOnHold`
- `ReleaseStockHold`
- `MoveStockLocation`
- `ReserveStock`
- `ReleaseReservation`

### Picking and warehouse release commands

- `CreatePickListFromFulfilmentNeed`
- `ValidatePickList`
- `RecordPickLine`
- `ReleaseGoodsFromWarehouse`
- `ReopenPickList`
- `CancelPickList`

### Stock count and adjustment commands

- `CreateStockCount`
- `RecordStockCountLine`
- `ValidateStockCount`
- `CreateInventoryAdjustment`
- `ApproveInventoryAdjustment`
- `PostInventoryAdjustment`

## Events

Warehouse events should be append-only and traceable.

- `ReceivingSessionCreated`
- `ReceivingSessionStarted`
- `ReceivingLineRecorded`
- `ReceivingDiscrepancyRecorded`
- `ReceivingSessionValidated`
- `ReceivingValidationFailed`
- `GoodsReceiptReleased`
- `ReceivingSessionReopened`
- `ReceivingSessionCancelled`
- `StockLotCreated`
- `StockPlacedOnHold`
- `StockHoldReleased`
- `StockMoved`
- `StockReserved`
- `ReservationReleased`
- `PickListCreated`
- `PickListValidated`
- `PickLineRecorded`
- `WarehouseReleaseCreated`
- `GoodsReleasedFromWarehouse`
- `PickListReopened`
- `PickListCancelled`
- `StockCountCreated`
- `StockCountLineRecorded`
- `InventoryAdjustmentCreated`
- `InventoryAdjustmentApproved`
- `InventoryAdjustmentPosted`

## Read models

### WarehouseReceivingWorkbench

Decision question:

```text
Can Warehouse safely receive these supplier-confirmed goods into controlled stock?
```

Shows:

- supplier-confirmed PO reference;
- supplier and delivery window;
- expected lines and quantities;
- received, accepted, rejected, missing, and excess quantities;
- discrepancy count;
- QA hold / quarantine markers if present;
- next available receiving action;
- source Planning and Procurement trace.

### StockVisibility

Shows:

- ingredient;
- stock lot / stock position;
- available quantity;
- reserved quantity;
- held or quarantined quantity;
- warehouse location;
- expiry / batch if applicable;
- source GoodsReceipt and PO line references.

### WarehouseDiscrepancyReview

Shows receiving discrepancies and their status, including issues needing Procurement, QA, Finance, or Dispatch follow-up.

### PickListWorkbench

Decision question:

```text
Can Warehouse safely pick and release these goods for the next domain?
```

Shows reservation, picking, shortage, substitution, and release status.

### WarehouseReleaseSummary

Shows released goods by destination, downstream handoff target, source stock, source receipt, and source Procurement trace.

### WarehouseChangeHistory

Shows command/event history by warehouse object, actor, timestamp, status transition, affected line, reason, and upstream source trace.

## MVP validation rules

### Receiving blockers

- Purchase Order is missing.
- Purchase Order is not supplier-confirmed / ready for Warehouse handoff.
- Purchase Order release snapshot is missing.
- Supplier confirmation reference is missing.
- Purchase Order line reference is missing.
- Purchase Allocation / Purchase Handoff / Confirmed Need / source trace reference is missing.
- Receiving line references an ingredient different from the supplier-confirmed PO line.
- Received quantity is negative.
- Accepted quantity is negative.
- Rejected quantity is negative.
- Accepted + rejected quantity exceeds received quantity without explicit discrepancy reason.
- Received quantity exceeds supplier-confirmed quantity without overage discrepancy.
- Received quantity is lower than supplier-confirmed quantity without shortage discrepancy.
- Purchase unit is missing or mismatched without unit conversion evidence.
- Attempt to edit Planning-approved demand.
- Attempt to edit Procurement supplier commitment.
- Attempt to create Dispatch delivery confirmation directly.
- Attempt to create QA approval directly.
- Attempt to create invoice, payable, or accounting entry directly.

### Receiving warnings

- Late supplier arrival.
- Missing supplier document.
- Partial delivery.
- Overage delivery.
- Damaged goods.
- Expiry date close to threshold.
- Lot/batch information missing where normally required.
- Storage location not assigned.
- QA hold recommended.
- Supplier has recent receiving discrepancies.

### Stock blockers

- Stock source GoodsReceipt is missing or unreleased.
- Accepted quantity is zero or negative.
- Stock lot lacks required source PO line or source trace.
- Quantity movement would make available stock negative.
- Reservation exceeds available stock.
- Stock on hold is being picked without hold release.
- Expired or damaged stock is being released without approved exception.

### Picking and release blockers

- Fulfilment source is missing.
- Stock reservation is missing.
- Pick quantity exceeds reserved quantity.
- Pick line lacks stock lot reference.
- Warehouse release lacks destination / downstream handoff target.
- Attempt to confirm delivery directly.
- Attempt to record production consumption directly.

### Adjustment blockers

- Adjustment reason is missing.
- Adjustment approval is missing where required.
- Adjustment would create unexplained negative stock.
- Adjustment attempts to rewrite a GoodsReceipt, PO, or Planning demand instead of recording a warehouse correction.

## Domain boundaries with neighboring domains

### Procurement → Warehouse

Procurement provides supplier-confirmed commitments and release snapshots. Warehouse receives physical goods against them.

Warehouse may record shortage, overage, rejection, or discrepancy. Warehouse must not change supplier assignment, PO quantity, supplier confirmation, or Procurement release history.

### Warehouse → Dispatch and Delivery

Warehouse releases goods for downstream movement. Dispatch owns route planning, driver handoff, vehicle loading confirmation where applicable, delivery confirmation, failed delivery, and returns execution.

WarehouseRelease is not proof of delivery.

### Warehouse → Production and Quality

Warehouse may place stock on hold, quarantine stock, or expose goods requiring QA. QA owns inspection outcome, food-safety approval, corrective action, and quality release decisions where applicable.

Warehouse does not approve food safety by itself.

### Warehouse → Finance and Reporting

Warehouse receiving and discrepancy records may support payable, settlement, cost variance, or supplier performance reporting. Finance owns invoice, payable, settlement, accounting entry, and commercial treatment.

Warehouse does not decide payment.

## Decision-first UX

The Warehouse UI should not start from tables. It should start from operator decisions:

1. Can we receive this supplier-confirmed delivery?
2. What physically arrived compared with the supplier commitment?
3. What can be accepted into stock?
4. What must be rejected, held, quarantined, or escalated?
5. What stock is available for fulfilment?
6. Can we pick and release goods safely to the next domain?

Primary receiving view:

- expected supplier delivery;
- receiving session status;
- line-level expected / received / accepted / rejected / missing / excess quantities;
- discrepancy indicators;
- source Procurement and Planning trace;
- next available command.

Primary stock view:

- ingredient and lot;
- available / reserved / held quantities;
- storage location;
- expiry / batch if applicable;
- source receipt and PO trace;
- downstream reservation/release status.

## OPS v1 compatibility notes

OPS v1 Supabase and Retool behavior may be used as qualitative business evidence only. Current purchase, receiving, dispatch, and stock-like behavior should not be copied as final Atlas schema or UI structure.

Known useful OPS v1 evidence includes:

- supplier delivery and PO confirmation intent;
- dispatch/warehouse handoff forms;
- manual exception handling patterns;
- need for traceable quantities and supplier discrepancy visibility.

However, Atlas Warehouse must be designed from the domain contract, not from Retool page layout or current table convenience.

## Out of scope for this contract PR

- React implementation.
- TypeScript domain implementation.
- Tests.
- Supabase migrations.
- PostgreSQL schema or RLS.
- RPCs.
- Edge Functions.
- Backend integration.
- Credentials.
- Production data.
- Retool changes.
- Dispatch implementation.
- QA execution.
- Finance or Accounting.
- Supplier performance scoring.
- Automatic stock optimization.
- Generic workflow engine.

## Implementation readiness criteria

A future Warehouse foundation PR may proceed only after this contract is reviewed and merged. The implementation should remain in-memory first and should prove:

- receiving can start only from supplier-confirmed Procurement commitments;
- receiving lines preserve Procurement and Planning source trace;
- discrepancies do not rewrite upstream objects;
- accepted goods can create warehouse-owned stock identity;
- held/quarantined/rejected goods cannot be released as available stock without the correct command path;
- picking and warehouse release do not become Dispatch delivery confirmation;
- no Finance, QA, Dispatch, Retool, Supabase, backend, credential, or production-data behavior is introduced.

## Core boundary statement

```text
Procurement owns supplier commitment.
Warehouse owns physical receiving and stock evidence.
Dispatch owns delivery execution.
QA owns food-safety and quality decisions.
Finance owns payable and accounting treatment.
```
