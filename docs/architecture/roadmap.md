# Atlas Roadmap

**Purpose:** A concise view of delivery order and current status. Contracts and GitHub issues remain the detailed source of scope.

## Status legend

- ✅ Complete or merged baseline
- 🟡 In progress
- ⬜ Not started
- ↘️ Deferred from MVP sequence

## Foundation

- ✅ Repository governance and workspace guard
- ✅ ARCH-001 — OPS ERP Business Architecture
- ✅ ARCH-002 — Atlas System Map
- ✅ Atlas Vision
- ✅ Contract-first and bounded-PR workflow

## PD-01 — Planning

Goal: transform controlled customer and internal inputs into approved demand released to Procurement.

- ✅ Weekly Menu contract and foundation
- ✅ Attendance contract and foundation
- ✅ Planning Input Readiness contract and foundation
- ✅ Need Generation contract
- ✅ Need Generation foundation
- ✅ Confirmed Need contract
- ✅ Confirmed Need foundation
- ✅ Purchase Handoff contract
- ✅ Purchase Handoff foundation
- ✅ Planning integration and operator-workflow review

Planning completion boundary:

```text
Weekly Menu / Attendance / Other controlled sources
→ Planning Input Readiness
→ Need Generation
→ Confirmed Need
→ Purchase Handoff released to Procurement
```

## PD-02 — Procurement

Goal: convert released purchase demand and dispatch requirements into controlled supplier commitments and fulfilment allocations.

- ✅ Procurement domain contract
- ✅ Procurement foundation
- ✅ Procurement integration and operator-workflow review
- ✅ Procurement fulfilment allocation amendment
- ⬜ Production supplier assignment and policy
- ⬜ Purchase allocation split and overage handling
- ⬜ Production purchase orders and external supplier communication
- ⬜ Production supplier confirmation and exception handling
- ⬜ Supplier-performance support

Procurement fulfilment boundary:

```text
Planning releases what, how many, where, and by when.
Procurement allocates how the requirement will be fulfilled.
Supplier, warehouse, or future production records physical fulfilment evidence.
Dispatch confirms transport, destination outcome, exception, or return resolution.
```

Procurement owns `FulfilmentAllocation` and `FulfilmentAllocationLine`. It does not own Planning requirement quantities, Warehouse stock release evidence, supplier physical receiving evidence, Dispatch loading, or delivery confirmation.

## PD-03 — Warehouse

Goal: receive, hold, fulfil, pick, and release goods with controlled stock traceability.

- ✅ Warehouse domain contract
- ✅ Warehouse in-memory foundation (goods receipt, discrepancies, stock/lot identity)
- ✅ Warehouse integration and operator-workflow review
- ✅ Warehouse Stock Release contract
- ✅ Warehouse Stock Release in-memory foundation (reservation, picking, custody release, movement posting, on-hand reduction)
- ⬜ Inventory adjustment and stock count

## PD-04 — Admin / Master Data Management

Goal: maintain the master data required for Atlas MVP launch and OPS v1 replacement.

- ✅ Admin / Master Data Management domain contract
- ✅ School info management foundation (in-memory prototype)
- ✅ Ingredients & Suppliers management foundation (in-memory prototype)
- ✅ Dishes & Recipes management foundation (in-memory consolidated workbench)
- ✅ Admin integration and operator-workflow review

Admin MVP boundary:

```text
Schools
+ Ingredients & Suppliers
+ Dishes & Recipes
= clean master data for Planning, Procurement, and Warehouse
```

Recipe UI decision:

```text
Dishes & Recipes should be one consolidated Atlas workbench.
OPS v1 Retool screen/layer separation is evidence only, not a target domain split.
```

## PD-05 — Dispatch and Delivery

Goal: move Planning-released, Procurement-fulfilled requirements to schools, wholesale customers, kitchens, and other destinations with explicit loading, delivery, exception, and return evidence.

- ✅ Dispatch and Delivery contract
- ✅ Dispatch and Delivery bounded in-memory foundation
- ✅ Dispatch planning and reference assignment prototype
- ✅ Load and delivery confirmation prototype
- ✅ Delivery exception, return evidence, and closure prototype
- ✅ Dispatch integration and operator-workflow review
- ✅ MVP vertical-slice operator review
- ✅ MVP morning chaos simulation

Dispatch boundary:

```text
Planning releases what, how many, where, and by when.
Procurement allocates how the requirement will be fulfilled.
Supplier or warehouse evidence proves physical fulfilment.
Dispatch confirms transport, destination outcome, exception, or return resolution.
```

Source-of-need rule:

```text
School catering and wholesale requirements must both converge into Planning-owned DispatchRequirement lines before Procurement fulfilment and Dispatch execution.
WarehouseRelease is only one fulfilment-evidence type, not the mandatory dispatch trigger.
```

## PA — Persistence architecture

Goal: define and review the authoritative Atlas persistence boundary before any PostgreSQL or Supabase implementation.

- 🟡 PA-01 Atlas Persistence Contract — canonical identity, classifications, aggregates, snapshots/revisions, evidence, transactions, authorization, audit, read models, and legacy boundary documented in the current PR
- ⬜ PA-02 physical schema design
- ⬜ RLS and command-authorization design
- ⬜ Transactional command/RPC implementation
- ⬜ Controlled seed/reference data
- ⬜ First connected wholesale supplier-direct vertical slice
- ⬜ Legacy migration rehearsal and operator validation
- ⬜ Separately approved staged rollout

Persistence gate:

```text
Approved PA-01 contract
→ PA-02 schema and constraint design
→ authorization / RLS
→ transactional commands and derived read models
→ rehearsal and operator validation
→ separately approved production rollout
```

PA-01 is documentation and architecture only. It does not authorize a migration, database object, backend integration, credential, legacy extraction, production-data change, or cutover.

## Deferred — Production and Quality

Goal: support kitchen execution, portioning, food safety, inspection, waste, and corrective action.

- ↘️ Production domain contract deferred from current MVP sequence
- ↘️ Quality domain contract deferred from current MVP sequence
- ↘️ Production planning and execution deferred from current MVP sequence
- ↘️ Inspection and food-safety controls deferred from current MVP sequence
- ↘️ Waste and exception handling deferred from current MVP sequence

## Deferred — Finance and Reporting

Goal: add costing, invoices, settlement, management reporting, and cross-domain analysis without redefining operational ownership.

- ↘️ Finance contract deferred from current MVP sequence
- ↘️ Cost and price analysis deferred from current MVP sequence
- ↘️ Invoice and settlement deferred from current MVP sequence
- ↘️ Management reporting deferred from current MVP sequence
- ↘️ Cross-domain operational reporting deferred from current MVP sequence

## Delivery rule

A domain advances through:

```text
Contract
→ Issue
→ Bounded implementation PR
→ Validation
→ Review
→ Merge
→ Integration and operator review
```

The roadmap changes when delivery status changes or the product owner approves a scope change. It is not a substitute for contracts or issues.
