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
- ✅ PA-05E bounded Procurement command family — completed on `main` with exact full-line supplier allocation, separate all-lines-per-supplier purchase-order release, a dedicated least-privilege runtime, and 78 focused pgTAP assertions
- ✅ PA-05B-H2 multi-line Dispatch execution correction — merged with atomic multi-line load, full-line trip departure revalidation, Planning-owned destination enforcement, multi-line successful delivery, trip-wide scope authorization, and 128 focused pgTAP assertions
- ✅ PA-05F bounded Dispatch setup command family — implemented with fully evidenced exact-pair plan admission, disjoint assigned-trip subsets, Planning-derived stops, one plan-version increment per trip, the reused hardened Dispatch runtime, and 51 focused pgTAP assertions
- ✅ PA-05B-H3 successful Dispatch trip closure — implemented under Issue #93 with exact trip/stop/membership/load/delivery reconciliation, preserved `DELIVERED` status, one completion stamp/version increment, one closure event, one audit event, and 46 focused pgTAP assertions
- ✅ PA-05C-H2 current command timeline scope — implemented under Issue #102 with the existing private resolver, exact current aggregate vocabulary, same-trip upstream scope resolution, five minimum SELECT/RLS additions, and 46 focused pgTAP assertions
- ⬜ PA-05G backend end-to-end acceptance — authoritative source-to-trip-closure path using PA-05D, PA-05E, PA-05B Evidence, PA-05F, PA-05B-H2, PA-05B-H3, and the existing read surface
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
→ source-owned supplier evidence and exact applications
→ Dispatch plan/trip/stop setup
→ exact multi-line load
→ full-line departure
→ successful multi-line delivery
→ successful trip closure
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
→ PA-05B-H2 multi-line Dispatch execution correction
→ PA-05F Evidence-gated Dispatch setup command family
→ PA-05B-H3 successful trip closure
→ PA-05C-H2 current command timeline scope compatibility
→ PA-05G backend end-to-end acceptance
→ PA-06 React connection
→ rehearsal and operator validation
→ separately approved production rollout
```

PA-01 through PA-03 are approved documentation and architecture baselines. PA-04 is the merged first executable database foundation. PA-05A, PA-05B, PA-05C, PA-05B-H1, PA-05D, PA-05E, PA-05B-H2, PA-05F, and PA-05B-H3 are completed on `main`; PA-05C-H2 is implemented by this bounded change. The reviewed 18-function API now covers the Planning release chain, Procurement allocation and supplier PO, supplier Evidence, Evidence-gated Dispatch Plan and assigned-trip setup, atomic multi-line load, trip-wide departure, stop-level multi-line delivery, exact successful trip closure, trace, readiness, blockers, and current aggregate-compatible audit reads. PA-05G remains the next pure command-authored backend acceptance gate, followed by PA-06. Controlled production seed/reference data, legacy rehearsal, deployment, Warehouse, school catering, and broader write-command coverage remain separately approved work.

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
