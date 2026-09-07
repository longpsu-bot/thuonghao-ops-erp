# ARCH-002 — Atlas System Map

**Status:** Approved baseline v1.0
**Scope:** Operating architecture and feature-placement rules
**Parent:** ARCH-001 — OPS ERP Business Architecture

## Purpose

ARCH-002 is the official Atlas system map. It defines how a business requirement becomes an owned capability, a contract, an implementation, and an operator-facing application.

```text
Mission
→ Business Capability
→ Business Domain
→ Business Object
→ Business Contract
→ Command / Event
→ Read Model
→ Application
→ Technology
```

The sequence must not be reversed. Atlas does not begin with a Retool page, React component, database table, or framework and then invent business meaning afterward.

## Mission

Atlas converts the operational knowledge accumulated in OPS v1 into a scalable ERP for Thượng Hảo. The system should let the company operate through explicit ownership, controlled handoffs, traceable decisions, and simple daily work rather than tribal knowledge or management intervention.

OPS v1 remains an operational knowledge base and compatibility reference. It is not the final Atlas domain model, application structure, or user-interface template.

## Core rules

1. Domain first: capability and owner are clear before implementation.
2. Contract first: objects, lifecycle, commands, events, read models, validations, and exclusions are agreed before coding.
3. One object, one owner: other domains may reference or request changes but may not silently redefine another domain's object.
4. Commands change state and events explain outcomes.
5. Read models serve decisions; UI does not reconstruct ERP rules from raw records.
6. Decision-first UX: show enough to decide, allow expansion to explain, and keep audit/history outside the default view.
7. Released history is preserved through revision, reopening, invalidation, or compensating action.
8. React coordinates presentation and interaction; authoritative calculations and state transitions belong to controlled backend/domain commands.
9. Delivery uses small, reviewable issues and pull requests.

## Domain map

### Planning

**Owner:** Tổ Kế hoạch

```text
Weekly Menu
+ Attendance
+ Direct / Pantry Requests
→ Planning Input Readiness
→ Need Generation
→ Confirmed Need
→ Purchase Handoff
```

Planning owns demand up to release to Procurement. It does not assign suppliers, create purchase orders, receive goods, dispatch goods, or perform accounting.

For the connected School flow approved by D-044, School is the authoritative
operational recipient for both catering-derived and direct Ingredient Need. Direct
Need composition mode is an explicit fact at School + service date; it is not
inferred from Purpose, customer compatibility data, or UI routing.

### Recipe

Recipe owns dishes, recipes, recipe versions, BOMs, and controlled formula changes. Planning may reference recipe/BOM versions but must not edit them implicitly.

### Procurement

**Owner:** Thu mua

Procurement converts released purchase demand into supplier commitments. It owns supplier assignment, allocation, purchase orders, supplier confirmation, and procurement replacement.

### Warehouse

**Owner:** Kho

Warehouse receives, stores, picks, fulfils, dispatches, and counts stock. It may fulfil demand from stock but may not redefine demand.

D-044's first School Phiếu xuất kho is intentionally narrower than future stock
execution. It releases immutable School/date/location fulfilment evidence from
current Need, allocation, and released supplier commitments without requiring or
creating stock, receipt, lot, reservation, pick, movement, trip, vehicle, driver, or
load facts.

### Dispatch and Delivery

**Owner:** Kho vận / Điều phối

Dispatch and Delivery move released goods to kitchens, schools, and other destinations. They consume released fulfilment and replacement snapshots and must not infer substitutions silently.

The bounded School Phiếu xuất kho does not activate the older DispatchPlan,
DispatchTrip, DispatchLoad, or DeliveryStop lifecycle. Those remain separate future
capabilities and are not prerequisites for the normal School PXK path.

### Production and Quality

Production owns preparation, cooking, portioning, and waste. Quality owns inspection, food safety, complaints, holds, recalls, and corrective action.

### Finance, Reporting, and Administration

Finance may later own invoices, payments, settlement, costing, and financial reporting. Reporting reads across domains but does not own operational decisions. Administration owns permissions and master-data setup, not daily approvals.

## Canonical traceability

```text
Purchase Handoff Line
← Confirmed Need Line
← Theoretical Need Line
← Planning Input Set
← Weekly Menu / Attendance / Direct or Pantry Request
← Recipe / BOM version where applicable
```

Every material record should answer where it came from, which version was used, who acted, when, why, and which downstream records consumed it.

## Delivery workflow

```text
Business need
→ Contract
→ GitHub issue
→ Bounded implementation branch
→ Tests and validation
→ Pull request
→ Review
→ Merge
→ Integration or next capability
```

Implementation agents execute approved contracts. They must not expand domain ownership, introduce production backend behavior, or invent authoritative calculations without an explicit task.

## Parallel implementation

Independent modules may be implemented in parallel when each has an approved contract, each PR owns separate modules, upstream dependencies are represented by small typed references or fixtures, no PR changes shared contracts unilaterally, and final wiring is deferred to a bounded integration PR.

Parallel work does not permit duplicate ownership or hidden coupling.

## Technology placement

- React + TypeScript: application and interaction layer.
- Supabase + PostgreSQL: future authoritative persistence, transactions, RLS, and backend commands.
- Retool: OPS v1 reference plus selected diagnostic/support tooling.
- GitHub: source of truth for architecture, contracts, issues, code, tests, and review history.
- Codex: bounded implementation assistant operating from approved repository instructions.

## Architecture stability

ARCH-001 and ARCH-002 form the frozen Atlas MVP baseline. They change only when a verified business requirement cannot fit the model, implementation exposes a fundamental defect, or the product owner explicitly approves a change. Theoretical refinement alone is not sufficient reason to redesign the baseline.
