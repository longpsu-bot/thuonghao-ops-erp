# Decision — PD-02 Procurement owns fulfilment allocation

**Status:** Proposed in corrective PR

**Date:** 2026-07-14

## Context

After the corrected PD-05 Dispatch and Delivery contract, Dispatch no longer starts from mandatory `WarehouseRelease`. Dispatch starts from Planning-released requirements, Procurement fulfilment allocation, and physical fulfilment evidence.

To prevent Dispatch from absorbing sourcing logic, Procurement ownership must explicitly include fulfilment allocation.

## Decision

Procurement owns `FulfilmentAllocation` and `FulfilmentAllocationLine`.

Procurement decides how each Planning-released dispatch requirement line is fulfilled:

- supplier PO;
- warehouse stock;
- mixed supplier and warehouse fulfilment;
- future production release.

Procurement does not create the physical evidence. Supplier receiving/cross-dock evidence, Warehouse stock release evidence, and future Production release evidence are recorded by the physically responsible domain or process.

## Ownership rule

```text
Planning releases what, how many, where, and by when.
Procurement allocates how the requirement will be fulfilled.
Supplier, warehouse, or future production records physical fulfilment evidence.
Dispatch confirms transport and destination outcome.
```

## Consequences

- Dispatch can support both school catering and wholesale without owning sourcing decisions.
- Warehouse Release is only evidence for warehouse-stock allocation, not the Dispatch trigger.
- Supplier-direct and cross-dock fulfilment can be represented without fake warehouse stock movement.
- Procurement can split one Planning requirement line across supplier PO and warehouse stock.
- Future Production Release can be added without redesigning Procurement or Dispatch.

## Boundaries preserved

- Planning owns the dispatch requirement and requirement quantity.
- Procurement owns fulfilment allocation and supplier commercial commitment.
- Warehouse owns stock custody, stock movement, and warehouse-stock release evidence.
- Supplier receiving/cross-dock evidence is physical fulfilment evidence, not Procurement allocation.
- Dispatch owns load, trip, delivery confirmation, exception, and closure.
- QA, Production execution, Finance, Supabase, Retool, backend, credentials, and production data remain out of scope for the prototype contract.
