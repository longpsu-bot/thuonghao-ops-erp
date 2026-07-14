# PD-02 Procurement Integration and Architecture Conformance Review

**Status:** Implemented in this PR; pending review and merge

**Scope:** Procurement Foundation integration/conformance review only

**Architecture baseline:** ARCH-001 — OPS ERP Business Architecture; ARCH-002 — Atlas System Map

## Summary

The PD-02 Procurement Foundation conforms to the approved architecture and Procurement domain contract. Released Planning demand crosses the boundary through Purchase Handoff as a versioned, read-only demand reference. Procurement then owns supplier assignment, allocation approval, purchase-order drafting and release, supplier response, and controlled correction history.

This review required no domain redesign and adds no business capability. The implementation remains an in-memory prototype whose purpose is to prove domain shape, lifecycle gates, traceability, read models, and operator workflow before authoritative backend implementation.

## OPS_SYSTEM_MAP alignment

The implementation follows the ARCH-002 operating sequence:

```text
Planning
  Purchase Handoff released to Procurement
    → Procurement
      supplier assignment
      → allocation validation and approval
      → supplier-grouped PO drafts
      → PO release to supplier
      → supplier confirmation
        → readiness marker for a future Warehouse handoff
```

- Planning remains the owner of approved demand and the Purchase Handoff release.
- Procurement consumes only a released handoff and creates supplier-facing commitments through explicit commands.
- A supplier-confirmed PO may become ready for a future Warehouse handoff, but Procurement creates no receipt, received quantity, stock movement, or Warehouse command.
- Reporting-oriented workbench state is derived from domain read models and does not become an alternative write path.

## Contract alignment

The foundation is domain-first and contract-first. Its business objects map to the approved Supplier, SupplierAssignment, PurchaseAllocationBatch/Line, PurchaseOrder/Draft/Line, SupplierConfirmation, revision, issue, change, and released-snapshot concepts.

Lifecycle changes occur through named domain commands. Validation rejects unreleased handoffs, altered Planning demand, ineligible or inactive suppliers, incomplete allocations, premature PO release, and supplier confirmation before release. Approval and supplier release preserve snapshots; replacement, reopening, and cancellation preserve prior released history and require controlled paths.

The event/change history records object identity, actor, time, before/after status, affected lines, reasons where applicable, and source trace where applicable. No contradiction was found between the foundation, `procurement-domain-contract.md`, ARCH-001, or ARCH-002.

## Planning → Procurement handoff trace

For every Procurement allocation and PO line, the reviewed chain preserves:

```text
Purchase Handoff batch + released version
→ Purchase Handoff line
→ Confirmed Need batch and line
→ Need Generation run
→ Planning Input set
→ source trace
→ approved confirmed quantity and unit
```

`CreatePurchaseAllocationFromHandoff` copies the released handoff line identity, Confirmed Need identity, source trace, approved quantity/unit reference, service date, and delivery context. Supplier assignment adds a Procurement decision without changing those values. PO drafting then carries the allocation, handoff, Confirmed Need, and source-trace references into each supplier-facing line. Allocation approval and PO release snapshots retain stable line identities and quantities.

The integration tests exercise this boundary from handoff validation/release through allocation, approval, PO drafting, PO supplier release, and supplier confirmation. They compare the source Planning references at every downstream stage and confirm the source handoff remains unchanged.

## Procurement-owned responsibilities verified

- Supplier identity appears only after the Procurement assignment command; Purchase Handoff lines contain neither supplier nor PO ownership.
- Allocation quantity is a Procurement decision constrained by the immutable Planning demand reference.
- Allocation validation and approval precede PO drafting.
- A draft PO is internal and has no release snapshot; only a validated PO can be released as a supplier-facing commitment.
- Supplier confirmation is attributable and can only be recorded against a released PO.
- Revisions, replacements, reopening, and cancellation preserve released history instead of silently rewriting it.

## Explicit domain boundaries preserved

The Procurement module contains no Warehouse receipt, received quantity, stock movement, Dispatch, QA execution, Finance, or Accounting state. `READY_FOR_WAREHOUSE_RECEIVING` and its timestamp express only that the supplier commitment is ready for a future downstream handoff; they do not execute receiving.

No Supabase migration, RPC, Edge Function, backend integration, credential, production-data access, or Retool change is part of the foundation or this review. Planning demand is not recalculated or edited by Procurement.

## Operator workflow review

The workbench is decision-first: it answers whether released demand can safely become supplier commitments and surfaces the source handoff, assignment completeness, blockers/warnings, PO state, supplier response, and next available action.

React owns interaction and local prototype state only. Buttons invoke domain commands and are gated by the `ProcurementWorkbench` read model. The existing UI tests exercise the sequence from supplier assignment through supplier confirmation and prove that approval, draft creation, PO release, and confirmation cannot be selected before their domain prerequisites. Business validation remains in the domain command functions rather than hidden in React.

## Known prototype limitations

- State is fixture-backed and in memory; it is not authoritative persistence.
- Authentication, authorization, transactional concurrency, PostgreSQL privileges, and RLS are not implemented in this prototype.
- The prototype requires one full supplier allocation per demand line; approved split and overage policies are intentionally absent.
- Supplier master data, eligibility, contact, price freshness, and delivery terms are fixtures rather than production integrations.
- Supplier communication is represented by lifecycle state only; no message or external PO transmission occurs.
- Warehouse receiving and downstream reconciliation do not exist in this module.

## Recommended next steps before PD-03 Warehouse

1. Review and merge this conformance baseline without expanding PD-02 scope.
2. Define the bounded Warehouse domain contract and the exact input snapshot it may consume from supplier-confirmed Procurement commitments.
3. Specify backend command, authorization, transaction, RLS, and idempotency requirements before moving either domain from in-memory prototypes to authoritative persistence.
4. Keep split/overage policy, supplier performance, and external supplier communication as separately approved Procurement tasks rather than prerequisites for this review.

## No production or downstream behavior added

This review adds tests and documentation only. It adds no backend, Supabase, Retool, credentials, production data, Procurement capability, supplier scoring, split/overage behavior, Warehouse receiving, Dispatch, QA execution, Finance, or Accounting behavior.
