# PD-03 — Warehouse integration and architecture conformance review

**Status:** Implemented in this PR; pending review and merge  
**Scope:** Procurement → Warehouse handoff and the in-memory Warehouse foundation  
**Authority:** ARCH-001, ARCH-002, Procurement Domain Contract, Warehouse Domain Contract

## Summary

This review verifies that the merged Warehouse foundation consumes only a supplier-confirmed Procurement commitment, records Warehouse-owned physical receiving evidence, and preserves the approved Planning and Procurement source trace. It adds conformance documentation and focused tests only; it does not add Warehouse capability.

## OPS_SYSTEM_MAP alignment

ARCH-001 and ARCH-002 require explicit domain ownership, command-driven state change, decision-first read models, stable traceability, and React as an interaction layer rather than the source of authoritative decisions. The review confirms the Warehouse workbench invokes typed domain commands in sequence and exposes the next valid action instead of reconstructing receiving transitions in UI handlers.

## Contract alignment

Warehouse starts only from a `READY_FOR_WAREHOUSE_RECEIVING` Purchase Order with a release snapshot and supplier confirmation. It creates `ReceivingSession`, `ReceivingLine`, `GoodsReceipt`, and `StockLot` evidence while preserving the complete upstream snapshot on every line. Physical quantities, discrepancies, lots, locations, and warehouse warnings are Warehouse-owned evidence; no command updates the Purchase Order, allocation, Purchase Handoff, Confirmed Need, or Planning Input Set.

## Procurement → Warehouse handoff trace

Each receiving, receipt, and stock line retains:

- Purchase Order ID and version, supplier, supplier-confirmation reference, and release-snapshot reference.
- Purchase Order, allocation, handoff, and Confirmed Need line IDs.
- Need-generation run, Planning Input Set, source trace, ingredient, supplier-confirmed quantity, and purchase unit.

The integration test starts from the supplier-confirmed Procurement fixture and verifies this snapshot survives receipt release and stock creation unchanged.

## Warehouse-owned responsibilities verified

Warehouse records physical received/accepted/rejected quantities, location and lot evidence, shortage/overage/damage/document discrepancies, release of a goods receipt, and stock identity from accepted goods. A missing supplier document remains a Warehouse warning; it does not alter the supplier commitment.

## Explicit domain boundaries preserved

- Procurement retains supplier assignment, Purchase Order release, confirmation, and commercial commitment.
- Planning retains approved demand and its source facts.
- Dispatch delivery confirmation is not created by receiving, receipt release, or stock creation.
- QA approval and food-safety decisions are not created; Warehouse can only expose warnings or hold recommendations.
- Finance, payable, invoice, settlement, and accounting entries are not created.
- No Supabase, PostgreSQL, RLS, RPC, Edge Function, Retool, credential, backend, or production-data behavior is introduced.

## Operator workflow review

The decision-first workbench asks whether the supplier-confirmed goods can safely become controlled stock. It exposes only the next command in the fixture-backed path: start session, record evidence, record discrepancy, validate, release receipt, then create stock. Tests verify later actions are unavailable before their command prerequisites.

## Known prototype limitations

- State is fixture-backed and in memory, with no authorization, persistence, concurrency, or transactional backend enforcement.
- Supplier communication, QA execution, Dispatch, Finance, picking, allocation, and production execution remain outside this foundation.
- Warnings and hold recommendations are evidence for future owning domains, not their decisions.

## Recommended next steps after PD-03 review

1. Review and merge this conformance baseline.
2. Define the next separately approved Warehouse capability, if needed, without expanding this review PR.
3. Specify backend transactions, authorization, RLS, and idempotency before any production persistence work.

## No production or downstream behavior added

This review adds documentation and tests only. It adds no new Warehouse capability and no Supabase, Retool, backend, credential, production-data, Dispatch, QA execution, Finance, Accounting, supplier scoring, stock optimization, or generic workflow-engine behavior.
