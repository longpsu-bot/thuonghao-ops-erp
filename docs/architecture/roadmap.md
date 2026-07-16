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

Goal: define, review, and incrementally implement the authoritative Atlas persistence boundary without linking or mutating production systems.

- ✅ PA-01 Atlas Persistence Contract — canonical identity, classifications, aggregates, snapshots/revisions, evidence, transactions, authorization, audit, read models, and legacy boundary
- ✅ PA-02 physical schema and constraint design — namespaces, table catalog, line identity, revisions/snapshots, evidence applications, quantity/time rules, transaction matrix, indexes, access preview, read models, legacy staging, and first supplier-direct slice
- ✅ PA-03 authorization, RLS, command surface, and transaction safety design — actor/capability scopes, dedicated API functions, revoke-first grants, RLS, idempotency, optimistic concurrency, locking/isolation, safe errors, reporting/storage/integration security, and first-slice test design
- ✅ PA-04 supplier-direct Slice 1 migration foundation — merged with private schemas, typed traceability, evidence applications, forced RLS, revoke-first privileges, private read models, and local pgTAP verification
- ✅ PA-05A supplier-direct command/RPC contract design — completed on main with business-command names, envelopes, authorization, idempotency, locking, events/audit, and shaped-read contracts
- ✅ PA-05B bounded SQL command implementation — merged with actor/receipt helpers, five evidence-to-delivery commands, one shaped trace, and security/concurrency/invariant tests
- ✅ PA-05C authorized read API wrappers — shaped, capability/scope-filtered readiness, blocker, and audit-timeline functions
- ✅ PA-05B-H1 / issue #82 — runtime-role hardening completed: separate Evidence and Dispatch command owners, read-only read owner, revoke-first access, and effective-privilege pgTAP audit
- ✅ PA-05D bounded Planning command family — completed on `main` with four Planning commands, a dedicated least-privilege runtime, exact source-to-requirement lineage, and focused pgTAP coverage
- 🟡 PA-05E bounded Procurement command family — implemented on the Issue #88 review branch with exact full-line supplier allocation, separate all-lines-per-supplier purchase-order release, a dedicated least-privilege runtime, and focused pgTAP coverage; pending review and merge
- ⬜ PA-05F bounded Dispatch setup command family — dispatch plan, requirement admission, trip, and stop setup
- ⬜ PA-05G backend end-to-end acceptance — authoritative source-to-delivery path using the PA-05D through PA-05F prerequisites and existing PA-05B/PA-05C surface
- ⬜ PA-06 React connection — after PA-05G under the product owner's backend-first sequencing decision
- ⬜ Controlled seed/reference data — separately approved after backend acceptance; not required for rolled-back local fixtures
- ⬜ First connected wholesale supplier-direct vertical slice
- ⬜ Legacy migration rehearsal and operator validation
- ⬜ Separately approved staged rollout

Backend completion boundary:

```text
Wholesale source
→ Planning release chain
→ Procurement allocation and supplier PO
→ Dispatch plan/trip/stop setup
→ supplier evidence
→ load
→ departure
→ successful delivery
→ authorized trace/readiness/blockers/audit
```

Persistence gate:

```text
Approved PA-01 contract
→ PA-02 schema and constraint design
→ PA-03 authorization / RLS / command and transaction safety
→ PA-04 supplier-direct migration foundation and private derived read models
→ PA-05A command/RPC contract design
→ PA-05B bounded Evidence/Dispatch execution commands and security tests
→ PA-05C authorized shaped read API wrappers
→ PA-05B-H1 runtime-role hardening
→ PA-05D Planning command family
→ PA-05E Procurement command family
→ PA-05F Dispatch setup command family
→ PA-05G backend end-to-end acceptance
→ PA-06 React connection
→ rehearsal and operator validation
→ separately approved production rollout
```

PA-01 through PA-03 are approved documentation and architecture baselines. PA-04 is the merged first executable database foundation. PA-05A, PA-05B, PA-05C, PA-05B-H1, and PA-05D are completed on `main`; the reviewed 13-function API covers the Planning release chain, supplier Evidence, load/departure/successful delivery, trace, readiness, blockers, and audit reads. PA-05E adds two Procurement-owned commands for exact supplier allocation and released supplier purchase orders, bringing the reviewed surface to 15 functions. PA-05F will remove the remaining Dispatch-setup fixture prerequisite. PA-05G is the gate at which the supplier-direct wholesale Slice 1 backend may be called complete. PA-06 follows that acceptance gate under the product owner's current sequencing decision. Controlled production seed/reference data, legacy rehearsal, deployment, Warehouse, school catering, and broader write-command coverage remain separately approved work.

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
