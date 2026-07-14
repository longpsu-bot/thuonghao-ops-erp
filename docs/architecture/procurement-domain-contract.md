# PD-02 — Procurement Domain Contract

**Status:** MVP contract v0.1  
**Domain:** Procurement  
**Business owner:** Thu mua  
**Parent architecture:** ARCH-001 — OPS ERP Business Architecture; ARCH-002 — Atlas System Map  
**Scope:** Procurement domain contract only. No implementation, backend integration, Supabase migration, Retool change, production data, or purchase-order execution code.

## 1. Purpose

Procurement converts released Planning demand into controlled supplier-facing purchasing commitments.

Planning has already answered what the business needs. Procurement answers how that released demand should be assigned, allocated, committed to suppliers, revised when needed, and handed forward for Warehouse Receiving.

Core business rule:

```text
Released Purchase Handoff demand
+ supplier assignment / allocation
+ Procurement review
= controlled supplier purchase commitments
```

Procurement must not redefine Planning-approved demand. It consumes released Purchase Handoff references and creates supplier-facing commitments from them.

The output of this domain is not warehouse receipt, dispatch confirmation, quality approval, invoice approval, or accounting entry. Those belong to later domains.

## 2. Ownership and boundaries

Procurement owns:

- supplier assignment;
- supplier allocation;
- purchase allocation review;
- purchase order drafting;
- purchase order release to supplier;
- supplier confirmation;
- supplier rejection handling;
- supplier replacement before receiving;
- purchase-order revision before receiving;
- Procurement change history.

Procurement does not own:

- Planning-approved demand quantities;
- Weekly Menu;
- Attendance;
- Need Generation;
- Confirmed Need;
- Purchase Handoff source truth;
- recipe or BOM governance;
- warehouse receiving;
- stock movement;
- dispatch;
- kitchen QA;
- finance/accounting records.

Planning owns demand. Procurement owns supplier commitment. Warehouse later owns receiving and stock. Finance later owns payable/accounting treatment.

## 3. Business objects

### 3.1 Supplier

Represents a vendor that can provide ingredients or goods.

Required attributes:

- `supplier_id`
- `supplier_name`
- `status`
- `allowed_ingredient_ids` or category eligibility
- `default_delivery_terms`
- `contact_reference`
- `created_at`
- `updated_at`

Supplier status controls whether the supplier may be assigned. Inactive, suspended, or unapproved suppliers must not receive released purchase commitments.

### 3.2 SupplierAssignment

Represents a Procurement decision that a supplier may fulfill a specific released demand line or ingredient group.

Required attributes:

- `supplier_assignment_id`
- `purchase_handoff_line_id`
- `confirmed_need_line_id`
- `ingredient_id`
- `supplier_id`
- `assignment_status`
- `assigned_quantity`
- `purchase_unit`
- `assigned_by`
- `assigned_at`
- `reason_code` or `reason_note` when manual
- `source_trace_id`

SupplierAssignment must preserve the released Planning demand reference. It may decide who supplies the demand, but it must not change the Planning-approved quantity.

### 3.3 PurchaseAllocationBatch

Represents one Procurement review batch for a service period or demand release.

Required attributes:

- `purchase_allocation_batch_id`
- `purchase_handoff_batch_id`
- `period_start`
- `period_end`
- `status`
- `line_count`
- `blocking_issue_count`
- `warning_count`
- `prepared_by`
- `prepared_at`
- `approved_by` and `approved_at` when approved
- `released_by` and `released_at` when released to PO drafting
- `version`

The allocation batch is the unit of validation, approval, and release to purchase-order drafting.

### 3.4 PurchaseAllocationLine

Represents one demand line after Procurement assignment or allocation.

Required attributes:

- `purchase_allocation_line_id`
- `purchase_allocation_batch_id`
- `purchase_handoff_line_id`
- `confirmed_need_line_id`
- `ingredient_id`
- `demand_quantity`
- `allocated_quantity`
- `purchase_unit`
- `supplier_id`
- `allocation_status`
- `source_trace_id`
- `purchase_demand_reference`

A PurchaseAllocationLine references Planning demand but does not own the Planning quantity. It records Procurement’s supplier allocation decision.

### 3.5 PurchaseOrderDraft

Represents a grouped draft purchase order before release to supplier.

Required attributes:

- `purchase_order_draft_id`
- `purchase_allocation_batch_id`
- `supplier_id`
- `service_period`
- `delivery_requirement`
- `status`
- `line_count`
- `blocking_issue_count`
- `warning_count`
- `created_by`
- `created_at`
- `version`

A draft may be edited by Procurement before release. It is not yet a supplier commitment.

### 3.6 PurchaseOrder

Represents a supplier-facing purchasing commitment after release.

Required attributes:

- `purchase_order_id`
- `purchase_order_draft_id`
- `supplier_id`
- `status`
- `released_by`
- `released_at`
- `supplier_confirmed_by` and `supplier_confirmed_at` when confirmed
- `cancelled_by` and `cancelled_at` when cancelled
- `version`

A released PurchaseOrder is a controlled document. It must not be silently overwritten. Later corrections require revision, replacement, reopening, or cancellation path.

### 3.7 PurchaseOrderLine

Represents one supplier-facing commitment line.

Required attributes:

- `purchase_order_line_id`
- `purchase_order_id`
- `purchase_allocation_line_id`
- `purchase_handoff_line_id`
- `confirmed_need_line_id`
- `ingredient_id`
- `supplier_id`
- `quantity`
- `purchase_unit`
- `delivery_date`
- `delivery_location_reference`
- `status`
- `source_trace_id`

PurchaseOrderLine must preserve trace back to Purchase Handoff and Confirmed Need.

### 3.8 SupplierConfirmation

Represents supplier response to a released purchase order.

Required attributes:

- `supplier_confirmation_id`
- `purchase_order_id`
- `supplier_id`
- `confirmation_status`
- `confirmed_by`
- `confirmed_at`
- `confirmed_line_summary`
- `rejected_line_summary`
- `reason_note` when rejected or changed

Supplier confirmation records whether the supplier accepts, partially accepts, rejects, or requests revision.

### 3.9 ProcurementReplacement / SupplierRevision

Represents a controlled replacement or revision when the original supplier or commitment cannot proceed.

Required attributes:

- `procurement_revision_id`
- `original_purchase_order_id`
- `affected_purchase_order_line_ids`
- `old_supplier_id`
- `new_supplier_id` when applicable
- `before_quantity`
- `after_quantity`
- `purchase_unit`
- `reason_code` or `reason_note`
- `revised_by`
- `revised_at`
- `source_trace_id`

A replacement must preserve the original commitment and explain the change. It must not silently rewrite the released purchase order.

### 3.10 ProcurementIssue

Represents a blocker or warning during allocation, PO drafting, release, confirmation, or revision.

Required attributes:

- `procurement_issue_id`
- `purchase_allocation_batch_id` or `purchase_order_id`
- `line_id` when line-specific
- `severity`
- `issue_code`
- `message`
- `is_blocking`
- `resolved_by`
- `resolved_at`

### 3.11 ProcurementChange

Represents an auditable command result or lifecycle event.

Required attributes:

- `procurement_change_id`
- `event_type`
- `business_object_type`
- `business_object_id`
- `actor_id`
- `at`
- `before_status`
- `after_status`
- `affected_line_ids`
- `reason_code` or `reason_note`
- `source_trace_id`

### 3.12 Released purchase snapshot and version

Released purchase documents are snapshots. A released PurchaseOrder records:

- released version;
- supplier identity;
- line identities;
- source Planning demand references;
- quantities and units;
- release actor and timestamp;
- confirmation state;
- revision/cancellation history.

Later changes create explicit revisions, replacements, or cancellations. They must not silently alter released history.

## 4. Lifecycle

### 4.1 Purchase Allocation lifecycle

```text
Prepared
→ Validated
→ Approved
→ Released to PO Drafting
```

Correction path:

```text
Approved / Released to PO Drafting
→ Reopened with reason
→ Prepared
→ Validated
→ Approved
```

### 4.2 Purchase Order lifecycle

```text
Draft
→ Validated
→ Released to Supplier
→ Supplier Confirmed
→ Ready for Warehouse Receiving
```

Correction path:

```text
Released / Supplier Confirmed
→ Revised / Reopened / Cancelled with reason
→ new version or replacement path
```

### 4.3 Status meaning

**Prepared**  
Procurement has loaded released Purchase Handoff demand and may assign suppliers.

**Validated**  
Allocation or PO draft has no unresolved blocking issues.

**Approved**  
Procurement accepts the supplier allocation as ready for PO drafting.

**Released to PO Drafting**  
Allocation has been released to create supplier-specific PO drafts.

**Draft**  
PO exists internally but has not been sent to supplier.

**Released to Supplier**  
PO has been issued externally. It is now a supplier-facing commitment.

**Supplier Confirmed**  
Supplier has accepted the PO or accepted specific lines.

**Ready for Warehouse Receiving**  
Supplier commitment is confirmed enough for Warehouse to prepare receiving.

**Revised / Reopened / Cancelled**  
A controlled correction path with reason and preserved prior released snapshot.

## 5. Commands

Commands are the only approved way to change Procurement state.

### CreatePurchaseAllocationFromHandoff

Creates a PurchaseAllocationBatch from a released Purchase Handoff batch.

Rules:

- source Purchase Handoff must be released;
- all lines must preserve Purchase Handoff and Confirmed Need references;
- Planning demand quantities must be copied as demand references, not redefined;
- no supplier commitment is created yet.

Emits:

- `PurchaseAllocationCreated`

### AssignSupplierToDemandLine

Assigns a supplier to one or more demand lines.

Rules:

- supplier must be active and eligible;
- assigned quantity cannot exceed released demand unless an approved Procurement rule allows split/overage;
- assignment must preserve the demand reference;
- changing supplier after approval requires revision or reopen path.

Emits:

- `SupplierAssigned`

### ValidatePurchaseAllocation

Validates supplier coverage, supplier eligibility, quantity allocation, purchase units, duplicate allocation, and blockers.

Emits:

- `PurchaseAllocationValidated`
- `PurchaseAllocationValidationFailed`

### ApprovePurchaseAllocation

Approves a validated allocation batch.

Rules:

- no blocking issues;
- approved snapshot must be recorded;
- approval does not create a supplier-facing PO yet.

Emits:

- `PurchaseAllocationApproved`

### CreatePurchaseOrderDrafts

Creates supplier-grouped PO drafts from an approved allocation batch.

Rules:

- allocation batch must be approved or released to PO drafting;
- draft grouping must preserve allocation-line identity;
- no supplier communication occurs yet.

Emits:

- `PurchaseOrderDraftCreated`

### ValidatePurchaseOrder

Validates a PO draft before release.

Rules:

- supplier must be active;
- PO lines must reference allocation lines;
- quantities and units must be present;
- delivery requirement must be valid enough for supplier release.

Emits:

- `PurchaseOrderValidated`
- `PurchaseOrderValidationFailed`

### ReleasePurchaseOrderToSupplier

Releases a validated PO to supplier.

Rules:

- PO must be validated;
- no unresolved blocking issues;
- release snapshot must be created;
- released PO cannot be silently edited.

Emits:

- `PurchaseOrderReleasedToSupplier`

### RecordSupplierConfirmation

Records supplier acceptance, partial acceptance, rejection, or requested change.

Rules:

- PO must be released to supplier;
- confirmation must be attributable;
- partial or rejected confirmation must create visible issue or revision requirement.

Emits:

- `SupplierConfirmed`
- `SupplierPartiallyConfirmed`
- `SupplierRejected`

### ReviseSupplierAssignment

Revises supplier assignment before or after PO drafting according to lifecycle rules.

Rules:

- reason required;
- previous assignment must be preserved;
- released PO changes require revision or cancellation path.

Emits:

- `SupplierAssignmentRevised`

### ReplaceSupplier

Replaces supplier for one or more affected lines.

Rules:

- reason required;
- old supplier and new supplier must be recorded;
- affected PO and allocation lines must remain traceable;
- downstream Warehouse must later receive the revised commitment, not the old one.

Emits:

- `SupplierReplacementRecorded`

### ReopenPurchaseOrder

Reopens a released or confirmed PO for controlled correction when allowed.

Rules:

- reason required;
- released snapshot preserved;
- reopened PO cannot erase supplier confirmation history.

Emits:

- `PurchaseOrderReopened`

### CancelPurchaseOrder

Cancels a released PO or draft according to allowed lifecycle state.

Rules:

- reason required;
- cancellation snapshot preserved;
- cancelled PO must not be used for Warehouse Receiving;
- replacement path may be required.

Emits:

- `PurchaseOrderCancelled`

## 6. Events

Minimum event set:

- `PurchaseAllocationCreated`
- `SupplierAssigned`
- `PurchaseAllocationValidated`
- `PurchaseAllocationValidationFailed`
- `PurchaseAllocationApproved`
- `PurchaseAllocationReleasedToPODrafting`
- `PurchaseOrderDraftCreated`
- `PurchaseOrderValidated`
- `PurchaseOrderValidationFailed`
- `PurchaseOrderReleasedToSupplier`
- `SupplierConfirmed`
- `SupplierPartiallyConfirmed`
- `SupplierRejected`
- `SupplierAssignmentRevised`
- `SupplierReplacementRecorded`
- `PurchaseOrderReopened`
- `PurchaseOrderCancelled`

Each event carries:

- event ID;
- object ID;
- object type;
- affected line IDs;
- actor;
- timestamp;
- before status;
- after status;
- reason when applicable;
- source demand trace when applicable.

## 7. Read models

Read models serve the UI and are not alternative command paths.

### ProcurementWorkbench

Primary Procurement workspace.

Answers:

```text
Can Procurement safely convert released Planning demand into supplier commitments?
```

Shows:

- service period;
- Purchase Handoff reference;
- demand line count;
- supplier assignment completeness;
- blocker count;
- warning count;
- PO draft status;
- PO release status;
- next available action.

### SupplierAssignmentReview

Shows demand lines grouped by ingredient, supplier eligibility, assigned supplier, allocation quantity, unit, and unresolved issues.

### PurchaseAllocationIssues

Groups blockers and warnings by supplier, ingredient, delivery date, allocation line, and issue code.

### PurchaseOrderDraftReview

Shows draft POs by supplier with line counts, quantities, delivery requirements, blocker count, warning count, and release eligibility.

### SupplierConfirmationQueue

Shows released POs waiting for supplier response, partially confirmed POs, rejected lines, and required replacement actions.

### ProcurementChangeHistory

Explains supplier assignment, allocation approval, PO release, supplier confirmation, replacement, reopening, cancellation, and revision history.

### ProcurementReleaseSummary

Manager-facing summary showing allocation status, PO release status, supplier confirmation progress, unresolved risks, and downstream Warehouse readiness.

## 8. MVP validation rules

Blocking issues include:

- source Purchase Handoff is missing or not released;
- demand line missing Purchase Handoff reference;
- demand line missing Confirmed Need reference;
- source trace missing;
- supplier missing;
- supplier inactive;
- supplier not eligible for ingredient or category;
- purchase unit missing;
- allocation quantity is negative;
- allocation quantity exceeds demand without approved split/overage rule;
- zero quantity included in PO release without explicit exclusion rule;
- duplicate supplier allocation without split rule;
- PO release attempted with unresolved blockers;
- supplier confirmation recorded for unreleased PO;
- attempt to change Planning-approved demand quantity;
- attempt to create Warehouse receiving directly from Procurement allocation before released supplier commitment.

Warnings may include:

- unusual supplier change;
- supplier concentration risk;
- stale price reference;
- supplier has recent rejection or quality issue;
- large quantity for one supplier;
- delivery time risk;
- incomplete contact or delivery instructions;
- PO differs from previous supplier pattern for the same ingredient.

Warnings remain visible and may later require acknowledgement according to policy.

## 9. Domain boundaries and downstream relationship

Procurement consumes Planning’s released Purchase Handoff demand. It may allocate demand to suppliers and create supplier commitments. It may not edit, recalculate, or redefine Planning demand.

Warehouse later consumes released and supplier-confirmed purchase commitments for receiving. Warehouse owns received quantity, lot condition, shortage, overage, and stock movement.

Finance later reads confirmed procurement and receiving records to support payable/accounting workflows. Finance does not own Procurement lifecycle.

QA may later flag supplier or ingredient quality issues. QA issues may affect supplier eligibility, but QA is not part of this Procurement MVP contract.

Reporting may read across Planning, Procurement, Warehouse, QA, and Finance, but Reporting does not own source-of-truth state transitions.

## 10. Decision-first UX

The default Procurement workspace answers:

```text
Can Procurement safely convert this released demand into supplier commitments?
```

Primary view shows:

- service period;
- Purchase Handoff batch reference;
- supplier assignment completeness;
- unassigned demand count;
- blocker count;
- warning count;
- PO draft count;
- released PO count;
- supplier confirmation status;
- next action.

Expandable detail shows:

- source Planning demand trace;
- ingredient-level demand;
- supplier assignment rationale;
- supplier eligibility;
- supplier confirmation history;
- replacement/revision history;
- PO line detail;
- unresolved risk explanation.

Audit and history are not shown by default. They remain available through detail or explain views.

React may coordinate this interaction but must not own authoritative supplier assignment, PO release, or supplier confirmation logic.

## 11. OPS v1 compatibility notes

OPS v1 provides business evidence for Procurement behavior through current purchase assignment, supplier, PO, and order workflows.

Relevant OPS v1 intent includes:

- released needs feed purchase assignment work;
- ingredients may have supplier relationships;
- purchase assignments may need rebalance or revision;
- purchase orders are grouped by supplier and service period;
- supplier confirmation and replacement need visibility;
- downstream dispatch or warehouse documents should reflect the released purchasing decision.

OPS v1 Retool and Supabase structures are evidence, not final Atlas design.

Atlas should not copy Retool page structure. Atlas should not treat current Supabase tables, views, functions, or Edge Functions as the final Procurement schema. The contract should preserve business intent while defining cleaner domain ownership, lifecycle, commands, events, and read models.

## 12. Out of scope

This contract does not implement:

- React screens;
- Supabase migrations;
- RPCs;
- Edge Functions;
- backend integration;
- Retool changes;
- credentials;
- production data access;
- Warehouse Receiving;
- Dispatch;
- QA execution;
- Finance or Accounting;
- supplier scoring;
- automated optimization;
- generic workflow engine.

This PR is contract-only.

## 13. Implementation readiness

A later bounded implementation task may provide an in-memory Procurement foundation with:

- Purchase Allocation domain model;
- Supplier Assignment command model;
- Purchase Order Draft model;
- validation tests;
- decision-first Procurement workbench;
- no backend integration;
- no production data;
- no Warehouse or Finance behavior.

That implementation must preserve the core boundary:

```text
Planning owns demand.
Procurement owns supplier commitment.
Warehouse owns receiving.
Finance owns payable/accounting treatment.
```
