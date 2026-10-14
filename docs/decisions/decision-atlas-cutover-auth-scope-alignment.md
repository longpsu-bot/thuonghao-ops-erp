# Cutover authorization uses exact relational scope at bounded document surfaces

**Decision:** ATLAS-AUTH-SCOPE-ALIGNMENT-01

**Status:** Product-approved cutover correction; implementation under Draft PR review

**Correction date:** 14 October 2026

**Baseline:** main `54b074da1f1049b87f9403682348b2dc7cec7573`, Staging migration 107

## Problem

Several connected Procurement/PXK surfaces already had exact School/customer/delivery-location predicates, but a preceding call to the generic Actor authorizer supplied null scope targets. Null targets can only satisfy `GLOBAL`, so relational actors were rejected before the stronger exact guard could run.

A separate mismatch made Generated Purchase Review check `confirmed_need_review.read` although its accepted contract assigns `procurement.school_catering.read`.

PO read already attempted whole-document filtering, but only by delivery location. That is insufficient when multiple Schools share a location.

## Decision

Capability and relational scope remain separate checks.

- Generated Purchase Review requires `procurement.school_catering.read` and retains relational row filtering.
- PXK read/reconciliation and PXK release preserve their existing dispatch capabilities. A generic null-target `SCOPE_DENIED` does not preempt the exact School/location guard; capability errors still fail immediately.
- A Supplier/date School-catering PO is atomic for authorization. Non-`GLOBAL` read or release is allowed only when the Actor has relational authority for **every** School/delivery-location contribution represented by the whole PO. Partial visibility or partial release is forbidden.
- `GLOBAL` remains valid.
- Purchase Preparation remains a complete single-date aggregate command with its existing `GLOBAL` requirement.

No generic authorizer behavior changes. No role, capability, scope kind, business grouping, document lifecycle or RLS meaning changes.

## Derived whole-PO scope

The private PO predicate derives scope from authoritative current PO evidence:

current PO revision → PO line source split → canonical positive supplier/contribution interval overlap (`school_catering_po_school_breakdown`) → Handoff/Confirmed Need lineage → exact customer, School and delivery location.

The scope calculation uses the same represented School quantities as the official PO. A School with zero overlap in that supplier split does not belong to its authorization object. Every line must have complete quantity coverage; missing or incomplete lineage fails closed for a relational Actor. Customer identity comes from captured Confirmed Need lineage, not later master-data ownership. Active, currently effective `SCHOOL` scopes match the exact represented School ID; sharing a default delivery location does not confer another School's authority. Explicit `CUSTOMER` and `DELIVERY_LOCATION` scopes retain their corresponding relational coverage.

The helper is supporting authorization logic, not business state. It is `SECURITY INVOKER` so the existing shaped-read or Procurement command runtime remains the RLS execution identity while evaluating private lineage and Actor scopes. Browser roles cannot execute it. Only those two runtimes receive execute privilege.

## Compatibility and rollback

The existing PXK/reconciliation predicate also accepts the scoped School's default delivery location. This task preserves that approved caller boundary; it does not claim School-ID isolation when Schools share that default. Whether to narrow the inherited dispatch predicate requires a separate Product scope decision. The explicit whole-PO rule above is enforced locally without rewriting the shared authorizer.

Existing `GLOBAL` operators preserve behavior. Relational operators gain only the access already described by accepted contracts and only where all exact rows/documents are covered.

Migration 108 is forward-only. Before hosted deployment it can be discarded with its branch. After deployment, any rollback must be a reviewed forward migration that preserves least privilege; do not restore the accidental GLOBAL-only short-circuit or permit partial PO visibility.

OPS v1 and Retool remain unchanged.
