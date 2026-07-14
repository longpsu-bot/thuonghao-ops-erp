# Decision — PD-05 Dispatch starts from Planning requirements and fulfilment evidence

**Status:** Proposed in corrective PR

**Date:** 2026-07-14

## Context

The first PD-05 Dispatch and Delivery contract treated `WarehouseRelease` as the mandatory upstream trigger for Dispatch.

Product-owner review clarified that this is not correct for Thượng Hảo's operating model. Morning operations often happen between roughly 02:00 and 08:00, and not every dispatch line is physically stored in Warehouse before delivery. Supplier-delivered goods may be received, checked, staged, and handed to drivers in the same operating window.

OPS v1 already reflects a clearer rule: Planning finalizes what and how many go where; Procurement finalizes how those requirements are fulfilled; Warehouse confirms physical fulfilment only when warehouse stock is used.

## Decision

PD-05 Dispatch and Delivery must start from a Planning-owned `DispatchRequirement`, not a mandatory Warehouse Release.

Procurement owns `FulfilmentAllocation` for how each requirement line is fulfilled.

Physical fulfilment evidence may come from:

- supplier receiving / cross-dock evidence;
- warehouse stock release evidence;
- future production release evidence.

`WarehouseRelease` remains valid, but it is only evidence for the warehouse-stock portion of a Procurement allocation.

## Ownership rule

```text
Planning releases what, how many, where, and by when.
Procurement allocates how the requirement will be fulfilled.
Supplier, warehouse, or future production records physical fulfilment evidence.
Dispatch confirms transport and destination outcome.
```

## Consequences

- Dispatch can support both school catering and wholesale needs.
- Warehouse is not forced into every dispatch line.
- Warehouse Release does not become a customer delivery obligation.
- Supplier-direct and cross-dock fulfilment can be represented without fake warehouse stock movement.
- Future Production Release can be added without redesigning Dispatch.
- The Dispatch foundation must include both school catering and wholesale examples, and both supplier/cross-dock and warehouse-stock fulfilment evidence examples.

## Boundaries preserved

- Planning owns the dispatch requirement.
- Procurement owns fulfilment allocation.
- Warehouse owns stock custody and stock release evidence only where warehouse stock is used.
- Dispatch owns trip/load/delivery confirmation.
- QA, Production, Finance, Supabase, Retool, backend, credentials, and production data remain out of scope for the prototype contract.
