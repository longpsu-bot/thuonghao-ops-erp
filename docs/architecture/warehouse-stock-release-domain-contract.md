# PD-03.2 — Warehouse Stock Release Domain Contract

**Status:** Drafted in this PR; pending review and merge

**Domain:** Warehouse

**Capability:** Stock release, warehouse dispatch confirmation, and on-hand stock movement

**Upstream capability:** PD-03 Warehouse receiving / controlled stock identity

**Downstream domain:** Dispatch and Delivery, or another explicitly approved fulfilment domain

**Architecture baseline:** ARCH-001 — OPS ERP Business Architecture; ARCH-002 — Atlas System Map

## Purpose

Warehouse Stock Release extends the Warehouse domain from controlled stock receipt into controlled outbound stock movement.

Core rule:

```text
Available warehouse stock
+ reservation / picking evidence
+ warehouse release confirmation
= goods released from warehouse custody and auditable stock reduction
```

Warehouse confirms that goods left warehouse-controlled stock custody. Warehouse does not confirm that goods arrived at a destination.

## Core boundary statement

```text
WarehouseRelease confirms goods were released from warehouse-controlled stock and handed off for downstream movement; it does not confirm destination delivery.
```

## Ownership and boundaries

Warehouse owns:

- on-hand stock visibility derived from released GoodsReceipt / StockLot evidence;
- available, reserved, picked, released, held, quarantined, damaged, and adjusted stock status;
- stock reservation against an approved fulfilment need;
- pick list and pick line execution evidence;
- warehouse release confirmation;
- stock movement ledger entries that reduce on-hand stock after release;
- warehouse handoff evidence to Dispatch, Production, or another approved downstream domain;
- release blockers, warnings, cancellations, reopen events, and audit trail.

Warehouse does not own:

- route planning, driver assignment, vehicle assignment, or trip execution;
- destination delivery confirmation;
- school, kitchen, or customer acceptance confirmation;
- failed-delivery or transport-return execution as Dispatch facts;
- QA inspection outcome, food-safety approval, or corrective-action ownership;
- invoice, payable, settlement, costing, or accounting entry;
- supplier assignment, supplier confirmation, PO release, or supplier reconciliation;
- Planning demand, Confirmed Need, Purchase Handoff, recipe, BOM, menu, or attendance decisions;
- Retool diagnostic apps, Supabase schema, backend persistence, credentials, or production data.

## Required input objects

Warehouse Stock Release may start only from stock that already exists inside Warehouse as controlled on-hand evidence.

Minimum input snapshot:

```text
StockLot / StockPosition
- stockLotId / stockPositionId
- goodsReceiptId
- receivingSessionId or equivalent receipt reference
- purchaseOrderId
- purchaseOrderVersion
- purchaseOrderLineId
- purchaseAllocationLineId
- purchaseHandoffLineId
- confirmedNeedLineId
- needGenerationRunId
- planningInputSetId
- sourceTraceId
- supplierId
- supplierConfirmationReference
- releaseSnapshotReference
- ingredientId
- quantity on hand
- available quantity
- reserved quantity
- purchase unit
- warehouse location
- lot/batch/expiry where applicable
- stock status
```

Every reservation, pick line, release line, and stock movement must preserve the upstream trace back to GoodsReceipt, Procurement, and Planning.

## Business objects

### OnHandStock / StockPosition

Warehouse-owned stock availability by ingredient, lot, location, status, and trace source. This object answers what stock Warehouse currently controls.

### StockReservation

A Warehouse decision to reserve available stock for an approved fulfilment need. It reduces available-to-pick stock but does not yet prove that goods physically left the warehouse.

### PickList

A warehouse work instruction to pick stock for a downstream fulfilment target. It is not a Dispatch route and does not confirm delivery.

### PickLine

Line-level pick instruction and execution evidence. It records required quantity, reserved quantity, picked quantity, short quantity, substituted quantity if allowed, source stock lot, and release readiness.

### WarehouseRelease

A controlled warehouse handoff document confirming goods were released from Warehouse custody. It is the outbound counterpart to GoodsReceipt.

WarehouseRelease is not proof of delivery.

### WarehouseReleaseLine

Line-level release evidence against picked stock. It records source stock lot, picked quantity, released quantity, destination / downstream handoff target, and full upstream trace.

### StockMovement

Append-only inventory ledger event that changes warehouse stock quantity. For this contract, the key movement type is:

```text
RELEASE_FROM_WAREHOUSE = negative stock movement caused by WarehouseRelease
```

StockMovement is the authoritative stock-balance evidence. It must never silently rewrite the original GoodsReceipt or StockLot source facts.

### WarehouseHandoffEvidence

Evidence that goods left Warehouse custody and were handed to a downstream actor, such as a driver, dispatch team, production team, or authorized receiver for the next domain.

It may record handoff actor, handoff time, package count, release document reference, notes, and evidence reference. It does not prove destination delivery.

### WarehouseReleaseIssue

A blocker or warning for outbound stock release, such as insufficient stock, held stock, expired stock, missing pick evidence, missing handoff target, unit mismatch, missing trace, or release quantity mismatch.

### WarehouseReleaseChange

Append-only audit record for release commands, status changes, stock movement posting, cancellation, reopen, and correction.

## Lifecycles

### StockReservation lifecycle

```text
PREPARED
→ VALIDATED
→ RESERVED
→ RELEASED_TO_PICK
```

Cancellation path:

```text
PREPARED / VALIDATED / RESERVED
→ CANCELLED with reason
```

### PickList lifecycle

```text
PREPARED
→ VALIDATED
→ PICKING
→ PICKED
→ READY_FOR_WAREHOUSE_RELEASE
```

Correction path:

```text
PICKING / PICKED / READY_FOR_WAREHOUSE_RELEASE
→ REOPENED with reason
→ PICKING
```

### WarehouseRelease lifecycle

```text
DRAFT
→ VALIDATED
→ RELEASED_FROM_WAREHOUSE
→ STOCK_MOVEMENT_POSTED
```

After stock movement is posted, WarehouseRelease must not be silently rewritten. Corrections require explicit reversal, adjustment, reopen, or cancellation path with audit history.

### StockMovement lifecycle

```text
PREPARED
→ VALIDATED
→ POSTED
```

Posted StockMovement is append-only inventory evidence.

## Commands

Warehouse release commands must be explicit, typed, and auditable.

### Reservation commands

- `CreateStockReservation`
- `ValidateStockReservation`
- `ReleaseStockReservationToPick`
- `CancelStockReservation`

### Picking commands

- `CreatePickListFromReservation`
- `ValidatePickList`
- `StartPicking`
- `RecordPickLine`
- `MarkPickListReadyForRelease`
- `ReopenPickList`
- `CancelPickList`

### Release commands

- `CreateWarehouseReleaseFromPickList`
- `ValidateWarehouseRelease`
- `RecordWarehouseHandoffEvidence`
- `ReleaseGoodsFromWarehouse`
- `PostReleaseStockMovement`
- `ReopenWarehouseRelease`
- `CancelWarehouseRelease`

## Events

Warehouse release events should be append-only and traceable.

- `StockReservationCreated`
- `StockReservationValidated`
- `StockReserved`
- `StockReservationReleasedToPick`
- `StockReservationCancelled`
- `PickListCreated`
- `PickListValidated`
- `PickingStarted`
- `PickLineRecorded`
- `PickListReadyForRelease`
- `PickListReopened`
- `PickListCancelled`
- `WarehouseReleaseCreated`
- `WarehouseReleaseValidated`
- `WarehouseHandoffEvidenceRecorded`
- `GoodsReleasedFromWarehouse`
- `ReleaseStockMovementPosted`
- `WarehouseReleaseReopened`
- `WarehouseReleaseCancelled`

## Stock movement and on-hand update rules

Warehouse stock balance must be derived from append-only movement evidence, not silent field mutation.

Conceptual ledger:

```text
GoodsReceipt accepted quantity       → RECEIVE_STOCK             +Q
WarehouseRelease posted quantity     → RELEASE_FROM_WAREHOUSE   -Q
InventoryAdjustment posted quantity  → ADJUST_STOCK             ±Q
```

Required rules:

- Release quantity must be greater than zero.
- Release quantity must not exceed picked quantity.
- Picked quantity must not exceed reserved or available quantity without explicit approved exception.
- Held, quarantined, damaged, or expired stock cannot be released without the required command path.
- Posted `RELEASE_FROM_WAREHOUSE` StockMovement reduces available/on-hand stock.
- Stock movement must preserve GoodsReceipt, StockLot, Purchase Order, Purchase Handoff, Confirmed Need, Need Generation, Planning Input Set, and source trace references.
- Corrections must be represented as additional movements or explicit reversals, not silent edits.

## Read models

### OnHandInventoryView

Decision question:

```text
What stock does Warehouse currently control and what is available to release?
```

Shows:

- ingredient;
- lot / batch / expiry;
- warehouse location;
- on-hand quantity;
- available quantity;
- reserved quantity;
- held / quarantined / damaged quantity;
- source GoodsReceipt and upstream trace.

### StockReservationWorkbench

Decision question:

```text
Can this fulfilment need reserve stock without violating stock custody rules?
```

Shows available stock, requested quantity, reservation status, blockers, and trace.

### PickListWorkbench

Decision question:

```text
Can Warehouse pick the reserved stock correctly?
```

Shows required, reserved, picked, short, substituted, and blocked quantities.

### WarehouseReleaseWorkbench

Decision question:

```text
Can Warehouse release these picked goods from stock custody?
```

Shows pick readiness, release quantity, handoff target, evidence status, stock movement readiness, and downstream boundary warning.

### StockMovementLedger

Shows append-only stock movements by ingredient, stock lot, location, movement type, quantity delta, actor, timestamp, release/receipt/adjustment reference, and upstream trace.

## Validation rules

### Reservation blockers

- Stock lot is missing.
- Source GoodsReceipt / StockLot trace is missing.
- Requested quantity is zero or negative.
- Requested quantity exceeds available stock.
- Stock is held, quarantined, damaged, expired, or cancelled.
- Fulfilment target is missing.
- Unit mismatch lacks conversion evidence.

### Picking blockers

- Reservation is missing or not released to pick.
- Pick line lacks stock lot reference.
- Pick quantity is zero or negative.
- Pick quantity exceeds reserved quantity without explicit exception.
- Picked stock trace is incomplete.
- Picked stock is held, quarantined, damaged, expired, or cancelled.

### Warehouse release blockers

- PickList is missing or not ready for release.
- WarehouseReleaseLine lacks source stock lot.
- Release quantity is zero or negative.
- Release quantity exceeds picked quantity.
- Handoff target is missing.
- Handoff evidence is missing where required.
- Stock movement cannot be posted.
- Attempt to confirm destination delivery.
- Attempt to create Dispatch route, driver trip, or vehicle assignment.
- Attempt to create QA approval.
- Attempt to create invoice, payable, settlement, or accounting entry.
- Attempt to mutate Procurement commitment or Planning demand.

### Warnings

- Partial release.
- Substitution evidence present.
- Release after expected dispatch window.
- Handoff evidence incomplete but not mandatory for the release context.
- Stock close to expiry.
- Release depends on future Dispatch confirmation.

## Domain boundary with Dispatch and Delivery

Warehouse may create a WarehouseRelease and handoff evidence. Dispatch consumes the release as an input.

Warehouse must not:

- plan route;
- assign driver or vehicle;
- confirm arrival;
- confirm destination acceptance;
- record failed delivery as a transport fact;
- record delivery return as a completed Dispatch event.

Dispatch later owns delivery execution and destination confirmation.

## Domain boundary with QA

Warehouse may block or hold stock and expose quality warnings. QA owns inspection outcome, food-safety approval, rejection reason policy, corrective action, and QA release decision where applicable.

Warehouse release must not be treated as QA approval.

## Domain boundary with Finance and Accounting

Warehouse release and stock movement evidence may support cost, inventory, settlement, supplier performance, or variance reports later. Finance owns payable, invoice, settlement, costing policy, and accounting entries.

Warehouse release must not create payment or accounting treatment.

## OPS v1 compatibility notes

OPS v1 Supabase and Retool behavior may be used only as qualitative business evidence. Atlas Warehouse Stock Release must be designed from this contract, not by copying Retool page layout, current table convenience, or dispatch forms.

## Out of scope for this contract PR

- TypeScript implementation.
- React implementation.
- Tests, unless only documentation references require them.
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
- Supplier reconciliation.
- Supplier scoring.
- Stock optimization.
- Generic workflow engine.
- Changes to ARCH-001 or ARCH-002.

## Implementation readiness criteria

A future Warehouse Stock Release foundation PR may proceed only after this contract is reviewed and merged. The implementation should remain in-memory first and prove:

- stock can be released only from controlled available stock;
- reservation, picking, release, and stock movement preserve full upstream trace;
- Warehouse release reduces on-hand stock through append-only movement evidence;
- Warehouse release does not become destination delivery confirmation;
- Warehouse release does not create QA, Finance, Dispatch, Supabase, Retool, backend, credential, or production-data behavior.

## Open questions for later implementation

- Which fulfilment requests are valid release targets before Dispatch is implemented?
- Should release require handoff evidence in MVP, or allow evidence-later status?
- Should substitutions be allowed in Stock Release MVP or deferred?
- What are the minimum package / container / driver handoff fields?
- How should returns from Dispatch be modeled: Warehouse return receipt, Dispatch failed delivery, or both with separate events?
- Which stock movement ledger fields will become database constraints when Supabase persistence begins?
