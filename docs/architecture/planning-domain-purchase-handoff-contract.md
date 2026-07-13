# PD-01.10 — Planning Domain Purchase Handoff Contract

**Status:** MVP contract v0.1  
**Domain:** Planning  
**Business owner:** Tổ Kế hoạch  
**Parent architecture:** ARCH-001 — OPS ERP Business Architecture

## 1. Purpose

Purchase Handoff is the Planning-owned release boundary that turns approved Confirmed Need into a controlled demand queue for Procurement.

Confirmed Need answers what demand Planning has approved. Purchase Handoff answers which approved demand lines are released to Procurement for later supplier assignment and purchase order work.

This contract does not assign suppliers, create purchase orders, approve supplier splits, receive warehouse goods, create dispatch documents, finance purchases, perform QA, or edit recipe/BOM data.

Core business rule:

```text
Approved Confirmed Need
+ valid purchase handoff checks
= Released demand queue for Procurement
```

The output of this contract is not a purchase order. Procurement owns supplier assignment and PO creation after handoff.

## 2. Ownership and business objects

Planning owns the handoff until release. Procurement owns execution after release. Purchase Handoff references approved confirmed need lines; it does not redefine Planning-approved quantities.

### 2.1 PurchaseHandoffBatch

Represents one controlled handoff batch for a service period.

Required attributes:

- `purchase_handoff_batch_id`
- `confirmed_need_batch_id`
- `period_start` and `period_end`
- `status`
- `confirmed_need_reference`
- `line_count`
- `blocking_issue_count` and `warning_count`
- `prepared_by` and `prepared_at`
- `validated_by` and `validated_at` when validated
- `released_by` and `released_at` when released
- `version`

The batch is the unit of validation and release to Procurement.

### 2.2 PurchaseHandoffLine

Represents one released or pending demand line for Procurement intake.

Required attributes:

- `purchase_handoff_line_id`
- `purchase_handoff_batch_id`
- `confirmed_need_line_id`
- `service_date`
- `school_id` when relevant
- `ingredient_id`
- `quantity`
- `purchase_unit`
- `delivery_requirement` when available
- `source_trace_id`
- `status`

A handoff line is demand intake for Procurement. It must not contain supplier selection unless a later Procurement contract explicitly owns that assignment.

### 2.3 PurchaseDemandReference

Represents the trace from Procurement-facing demand back to Planning approval.

Required attributes:

- `confirmed_need_batch_id`
- `confirmed_need_line_id`
- `need_generation_run_id`
- `planning_input_set_id`
- `source_trace_id`
- approved confirmed quantity and unit

This reference preserves explainability from purchase demand back to Planning decisions.

### 2.4 PurchaseHandoffIssue

Represents a blocking issue or warning in the handoff.

Required attributes:

- `purchase_handoff_issue_id`
- `purchase_handoff_batch_id`
- `purchase_handoff_line_id` when line-specific
- `severity` (`BLOCKING` or `WARNING`)
- `issue_code`
- `message`
- `is_blocking`

Blocking issues prevent release to Procurement.

### 2.5 PurchaseHandoffChange

Represents an auditable command result or lifecycle event. It records event ID, event type, actor, timestamp, affected line, before/after status, and reason where required.

### 2.6 Released handoff snapshot and version

Release records the handoff batch version, confirmed need source version, released line identities, quantities, purchase units, actor, timestamp, and issue summary. Later Planning changes require explicit invalidation or a new handoff version and must not silently overwrite released demand.

## 3. Lifecycle

```text
Prepared
  → Validated
  → Released to Procurement
```

Correction path:

```text
Validated / Released to Procurement
  → Reopened or Invalidated with reason
  → Prepared
  → Validated
```

### Prepared

A handoff batch has been created from approved Confirmed Need. Blocking issues may still exist.

### Validated

The handoff batch has no unresolved blocking issues and is ready for release to Procurement.

### Released to Procurement

Planning has released the demand queue to Procurement. Procurement may now own supplier assignment and purchase order execution under future Procurement-domain contracts.

### Reopened / Invalidated

A previously validated or released handoff is explicitly reopened or invalidated because source confirmed demand changed or a handoff issue requires correction. Prior released snapshots remain preserved.

## 4. Commands

Commands are the only approved way to change Purchase Handoff state.

### PreparePurchaseHandoffFromConfirmedNeeds

Creates a Prepared handoff batch from an Approved or Released for Purchase Handoff ConfirmedNeedBatch. It copies stable confirmed need references into handoff lines and emits `PurchaseHandoffPrepared`.

The command is rejected if the confirmed need batch is not approved or released for handoff.

### ValidatePurchaseHandoff

Evaluates handoff lines for required purchase-facing data and issues. It emits `PurchaseHandoffValidated` when no blocking issues remain, or `PurchaseHandoffValidationFailed` otherwise.

### ReleasePurchaseHandoffToProcurement

Releases a Validated handoff batch to Procurement. It records actor, timestamp, released version, and line identities. It emits `PurchaseHandoffReleasedToProcurement`.

The command is rejected when the batch is not Validated or has unresolved blocking issues.

### InvalidatePurchaseHandoff

Invalidates a Prepared, Validated, or Released handoff when the referenced confirmed need version changes or a handoff blocker is discovered. It records actor, timestamp, reason, and affected source. It emits `PurchaseHandoffInvalidated`.

Invalidation does not rewrite purchase orders or downstream Procurement documents. That behavior belongs to Procurement-domain contracts.

## 5. Events

Minimum event set:

- `PurchaseHandoffPrepared`
- `PurchaseHandoffValidated`
- `PurchaseHandoffValidationFailed`
- `PurchaseHandoffReleasedToProcurement`
- `PurchaseHandoffInvalidated`

Each event carries event ID, PurchaseHandoffBatch ID, confirmed need reference, actor, timestamp, issue summary, and reason where applicable.

## 6. Read models

Read models serve the UI and are not an alternative command path.

### PurchaseHandoffWorkbench

Primary Planning workspace for this step. It shows service period, confirmed need status, handoff status, issue counts, demand line count, and release action.

### PurchaseHandoffIssues

Groups blocking issues and warnings by service date, ingredient, unit, confirmed need line, and issue code.

### PurchaseDemandQueue

Shows Procurement-facing demand lines with ingredient, quantity, purchase unit, delivery requirement, and source confirmed need reference. It does not assign suppliers or create POs.

### PurchaseHandoffSummary

Manager-facing summary showing confirmed need source version, handoff line count, blocking/warning counts, prepared by/at, validated by/at, and released by/at.

### PurchaseHandoffHistory

Explains preparation, validation, failure, release, and invalidation events.

## 7. MVP validation rules

The following are blocking unless a later approved rule explicitly changes their classification:

- Confirmed Need batch is missing or not Approved / Released for Purchase Handoff.
- Handoff line lacks stable reference to a confirmed need line.
- Ingredient reference is missing.
- Ingredient is not orderable and no explicit resolution marker exists.
- Purchase unit is missing.
- Handoff quantity is negative.
- Release attempted while blocking issues remain.
- Release attempted from a non-Validated batch.
- Released handoff is silently overwritten by later Planning changes.
- Procurement receives Not Ready, invalidated, or unvalidated handoff data.

Warnings may include zero quantity lines excluded from purchase, unusual unit conversion, missing delivery requirement, or demand version differs from a prior handoff for the same service period.

## 8. Domain boundaries and downstream relationship

Purchase Handoff belongs to Planning until release.

After release, Procurement owns supplier assignment, supplier split decisions, purchase orders, supplier communication, and purchase execution.

Purchase Handoff does not select suppliers, create POs, mutate warehouse stock, create dispatch documents, perform QA, create finance records, or edit recipe/BOM data.

Purchase Handoff preserves demand traceability from Confirmed Need. It does not redefine approved Planning quantity.

## 9. Decision-first UX

The default workbench answers: **Can Planning release approved demand to Procurement?**

Primary view shows only:

- service period;
- confirmed need status;
- handoff status;
- blocking issue count;
- warning count;
- demand line count;
- release to Procurement action.

Expandable detail shows:

- ingredient and unit details;
- handoff quantities;
- delivery requirements;
- source confirmed need line references;
- blocking issue details;
- release history.

Audit and history are not shown by default; they are available through a detail or explain view.

## 10. OPS v1 compatibility notes

The following OPS v1 structures are reference evidence, not a prescribed Atlas schema:

- purchase assignments and purchase feed views show the downstream shape Procurement needs;
- existing supplier assignment behavior belongs to Procurement, not the Planning handoff contract;
- current effective needs and purchase feeds are business evidence, not final Atlas schema.

Atlas should preserve the intent: approved demand can be handed to Procurement with stable traceability, but supplier and PO execution remain outside Planning.

## 11. Out of scope and implementation readiness

PD-01.10 does not implement React UI, Supabase migrations or RPCs, Retool changes, production-data changes, supplier assignment, purchase orders, warehouse, dispatch, finance, QA, or recipe/BOM editing.

The next bounded implementation task may provide an in-memory Purchase Handoff domain, tests, and a minimal demand queue workbench. It must preserve the separation between Planning demand release and Procurement execution.
