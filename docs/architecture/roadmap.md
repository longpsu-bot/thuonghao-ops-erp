# Atlas Roadmap

**Purpose:** A concise view of delivery order and current status. Contracts and GitHub issues remain the detailed source of scope.

## Status legend

- ✅ Complete or merged baseline
- 🟡 In progress
- ⬜ Not started

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
- 🟡 Planning integration and operator-workflow review — implemented in this PR, pending review and merge

Planning completion boundary:

```text
Weekly Menu / Attendance / Other controlled sources
→ Planning Input Readiness
→ Need Generation
→ Confirmed Need
→ Purchase Handoff released to Procurement
```

## PD-02 — Procurement

Goal: convert released purchase demand into controlled supplier commitments.

- ⬜ Procurement domain contract
- ⬜ Supplier assignment
- ⬜ Purchase allocation and split handling
- ⬜ Purchase orders and revisions
- ⬜ Supplier confirmation and exception handling
- ⬜ Supplier-performance support

## PD-03 — Warehouse

Goal: receive, hold, fulfil, pick, and release goods with controlled stock traceability.

- ⬜ Warehouse domain contract
- ⬜ Goods receipt and discrepancies
- ⬜ Stock / lot visibility
- ⬜ Internal fulfilment
- ⬜ Picking and warehouse dispatch
- ⬜ Inventory adjustment and stock count

## PD-04 — Production and Quality

Goal: support kitchen execution, portioning, food safety, inspection, waste, and corrective action.

- ⬜ Production domain contract
- ⬜ Quality domain contract
- ⬜ Production planning and execution
- ⬜ Inspection and food-safety controls
- ⬜ Waste and exception handling

## PD-05 — Dispatch and Delivery

Goal: move released goods to kitchens, schools, and other destinations with explicit handoffs and exceptions.

- ⬜ Dispatch and Delivery contract
- ⬜ Dispatch planning
- ⬜ Driver handoff
- ⬜ Delivery confirmation
- ⬜ Delivery exception and return handling

## PD-06 — Finance and Reporting

Goal: add costing, invoices, settlement, management reporting, and cross-domain analysis without redefining operational ownership.

- ⬜ Finance contract
- ⬜ Cost and price analysis
- ⬜ Invoice and settlement
- ⬜ Management reporting
- ⬜ Cross-domain operational reporting

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
