# PD-05.2 — Dispatch integration and operator-workflow review

**Status:** Implemented in this PR; pending review and merge

**Scope:** In-memory Dispatch and Delivery integration and operator-workflow review only

**Authority:** ARCH-001, ARCH-002, the Dispatch and Delivery Domain Contract, the Procurement Fulfilment Allocation Contract Amendment, and their ownership decisions

## Purpose

This review verifies that the Dispatch foundation can support the real 02:00–08:00 morning operation as a decision-first workflow. It strengthens fixture-backed read models, operator attention, tests, and presentation without adding persistence or new domain ownership.

The reviewed ownership model is:

```text
Planning releases what, how many, where, and by when.
Procurement allocates how the requirement will be fulfilled.
Supplier or Warehouse records physical fulfilment evidence for its portion.
Dispatch confirms transport, destination outcome, exception, or return resolution.
```

No contradiction with the approved contracts or architecture baseline was found. No architecture redesign is required.

## Current status

The workbench now maps each Planning requirement independently to its Procurement allocation, physical evidence, plan, trip, stop, load, destination outcome, exception, return evidence, and closure readiness. It no longer assumes that every requirement belongs to the first plan or trip, and it surfaces unplanned or unassigned requirements in the attention queue.

The foundation is ready for MVP vertical-slice review at the in-memory prototype boundary. It is not ready for production persistence or operational cutover.

## End-to-end operator workflow

```text
Planning-released DispatchRequirement
→ Procurement-owned FulfilmentAllocation
→ Supplier/cross-dock or WarehouseStockRelease evidence
→ DispatchPlan
→ DispatchTrip
→ DispatchLoad
→ DeliveryStop
→ DeliveryConfirmation / DeliveryException
→ ReturnEvidence where required
→ Trip closure
```

### 02:00–08:00 morning mapping

| Time window    | Operator decision                               | Evidence shown                                                                                         | Ownership boundary                                                             |
| -------------- | ----------------------------------------------- | ------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------ |
| 02:00–03:00    | What must go where and by when?                 | Planning release, source of need, requirement status, quantity, destination, delivery location         | Dispatch reads the Planning snapshot and cannot recalculate or edit it         |
| 02:00–04:30    | How will each line be fulfilled?                | Procurement allocation and supplier/warehouse split                                                    | Dispatch reads the allocation and cannot create or revise supplier commitments |
| 03:30–05:30    | Is every allocated portion physically ready?    | Supplier receiving/cross-dock evidence or WarehouseStockRelease evidence                               | The physical source owns its evidence; Dispatch only validates it for loading  |
| 04:00–05:45    | What can be assigned and loaded?                | Plan, trip, driver/vehicle references, stop sequence, fulfilled versus loaded quantity                 | Dispatch owns assignment and source-backed load confirmation                   |
| 05:00–08:00    | What departed and what happened at destination? | Departure, delivery evidence, delivered/returned/exception quantities                                  | Dispatch owns transport and destination outcome                                |
| Before closure | What remains unresolved?                        | Missing evidence, unassigned trip, missing load/delivery evidence, exceptions, returns, reconciliation | Closure is blocked until every stop is delivered or resolved with evidence     |

## Decision questions

The workbench answers:

1. What does Planning require?
2. How did Procurement allocate fulfilment?
3. Which supplier/cross-dock or Warehouse evidence exists?
4. What is ready to load?
5. What is assigned to a trip, driver, and vehicle?
6. What has been delivered?
7. What has partial-delivery, exception, or return risk?
8. What blocks trip closure?

## Happy path

1. Planning requirement is released with a stable source, quantity, unit, destination, and delivery location.
2. Procurement allocation reconciles the full requirement to supplier PO, warehouse stock, or both.
3. Each allocation portion has matching physical evidence of sufficient quantity.
4. Dispatch assigns a plan, trip, stop sequence, driver reference, and vehicle reference.
5. Dispatch confirms load quantities without exceeding fulfilled quantities.
6. The trip departs only after every stop has a source-backed load.
7. Delivery confirmation includes evidence and quantities do not exceed the load.
8. Every stop is delivered and the trip closes as `DELIVERED`.

The normal fixtures cover school catering through supplier/cross-dock evidence, school catering through Warehouse stock release evidence, and wholesale through supplier receiving evidence.

## Exception paths

- **Missing evidence:** the requirement is not ready to load.
- **Mixed evidence incomplete:** every supplier and warehouse portion must have its own matching evidence.
- **Trip unassigned:** the requirement remains visible and cannot disappear from the morning queue.
- **Load not confirmed:** departure and closure remain blocked.
- **Delivery evidence missing:** a destination outcome cannot be accepted as complete.
- **Delivered quantity exceeds loaded quantity:** the read model flags the reconciliation defect and domain commands reject it.
- **Partial or failed delivery:** an explicit exception is required for the unresolved quantity.
- **Return required:** return evidence resolves the Dispatch exception path but does not create Warehouse stock re-entry.
- **Inactive destination or location:** explicit override evidence is required before planning Dispatch execution.

## Source-of-need coverage

| Source of need    | Planning trace                                      | Dispatch treatment                                                         |
| ----------------- | --------------------------------------------------- | -------------------------------------------------------------------------- |
| `SCHOOL_CATERING` | Confirmed school catering need and Planning release | Uses the same allocation, evidence, trip, load, stop, and closure controls |
| `WHOLESALE`       | Wholesale customer order trace and Planning release | Bypasses recipe explosion upstream but uses the same Dispatch controls     |

## Fulfilment-source coverage

| Source            | Required evidence                                            | Dispatch rule                                                |
| ----------------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| `SUPPLIER_PO`     | Supplier receiving or cross-dock evidence                    | Warehouse release is not required                            |
| `WAREHOUSE_STOCK` | `WarehouseStockRelease` evidence                             | Evidence is valid only for a warehouse-stock allocation line |
| `MIXED`           | Evidence for every supplier and warehouse allocation portion | Full-load readiness requires all portions to be evidenced    |

## Handoff rules

- `DispatchRequirement` and its quantity remain Planning-owned immutable inputs.
- `FulfilmentAllocation` and supplier/warehouse split remain Procurement-owned immutable inputs.
- Supplier receiving/cross-dock evidence and WarehouseStockRelease remain source-owned physical facts.
- Dispatch owns plan, trip, reference assignment, load confirmation, departure, stop outcome, delivery exception, return evidence, and closure.
- Delivery confirmation is not a Warehouse receipt, stock movement, Procurement confirmation, QA approval, Production approval, invoice, settlement, or accounting record.

## Operator blockers

The attention queue exposes:

- inactive destination or delivery location without override evidence;
- missing physical fulfilment evidence;
- mixed fulfilment with one source portion missing evidence;
- trip, driver, or vehicle not assigned;
- load not confirmed;
- delivery evidence missing;
- delivered quantity greater than loaded quantity;
- unresolved delivery exception;
- required return evidence missing;
- trip closure blocked.

## Cross-domain boundary review

Tests confirm Dispatch cannot recalculate Planning need, edit Planning requirement quantity, edit Procurement allocation, create a supplier PO, create supplier receiving evidence, create WarehouseStockRelease, post Warehouse stock movement, approve QA, approve Production execution, create an invoice, settlement, or accounting record, optimize routes, track live GPS, manage driver payroll, or manage vehicle maintenance.

## Non-goals

This review adds no Supabase migration, PostgreSQL schema, RLS policy, RPC, Edge Function, backend integration, credential, production-data access, Retool change, Planning recalculation, Procurement allocation implementation, Warehouse movement implementation, supplier receiving implementation, Production/QA behavior, Finance/Accounting behavior, HR/payroll, fleet maintenance, route optimization, GPS/live tracking, or generic workflow engine.

## Known prototype limitations

- State remains fixture-backed and in memory.
- Driver, vehicle, route, supplier, school, customer, location, and evidence values are references only.
- Authentication, authorization, concurrency, idempotency, transaction boundaries, evidence-file storage, and notification are not implemented.
- Read-model validation demonstrates operator decisions but is not authoritative backend enforcement.
- Return evidence resolves the Dispatch path only; Warehouse must separately confirm any stock re-entry.

## Migration and rollback effects

There is no database or production-data migration. Rollback consists of reverting the read-model, fixtures, workbench, focused tests, this review document, and status documentation.

## Recommendation for next step

Review the Dispatch foundation as part of an MVP vertical slice across Planning, Procurement, physical fulfilment evidence, and Dispatch. Validate the 02:00–08:00 screen with real operators before specifying authoritative persistence, authorization, transactions, RLS, idempotency, and evidence storage in a separately approved task.

## Conclusion

The Dispatch foundation is ready for MVP vertical-slice review because the operator workflow is understandable, every requirement is independently traceable through allocation and evidence to destination outcome, and cross-domain boundaries are explicit. This conclusion applies only to the in-memory prototype boundary.
