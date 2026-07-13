# PD-01.8 — Planning Domain Confirmed Need Contract

**Status:** MVP contract v0.1  
**Domain:** Planning  
**Business owner:** Tổ Kế hoạch  
**Parent architecture:** ARCH-001 — OPS ERP Business Architecture

## 1. Purpose

Confirmed Need is the Planning-owned approval gate that converts generated theoretical needs into approved, traceable demand.

Need Generation produces theoretical lines. Confirmed Need answers which final quantities Planning accepts after review, exception handling, and controlled adjustment.

This contract does not assign suppliers, create purchase orders, receive warehouse goods, dispatch goods, finance purchases, perform QA, or edit recipe/BOM data.

Core business rule:

```text
Released generated theoretical needs
+ Planning review / controlled adjustment
= Approved confirmed demand
```

The output of this contract is approved demand for Purchase Handoff, not a purchase order.

## 2. Ownership and business objects

Planning owns Confirmed Need. Need Generation remains the source of calculated theoretical lines. Confirmed Need references generated lines and records Planning's approval and adjustments.

### 2.1 ConfirmedNeedBatch

Represents one controlled review and approval batch for a service period.

Required attributes:

- `confirmed_need_batch_id`
- `need_generation_run_id`
- `period_start` and `period_end`
- `status`
- `source_generation_reference`
- `line_count`
- `blocking_issue_count` and `warning_count`
- `created_by` and `created_at`
- `approved_by` and `approved_at` when approved
- `released_by` and `released_at` when released for Purchase Handoff
- `version`

The batch is the unit of validation, approval, and release to Purchase Handoff.

### 2.2 ConfirmedNeedLine

Represents one Planning-approved demand line or one line awaiting approval.

Required attributes:

- `confirmed_need_line_id`
- `confirmed_need_batch_id`
- `theoretical_need_line_id`
- `service_date`
- `school_id`
- `dish_id` when applicable
- `ingredient_id`
- `theoretical_quantity`
- `confirmed_quantity`
- `unit`
- `source_trace_id`
- `status`

The confirmed line is the stable demand identity that downstream handoff should reference. It must preserve the original theoretical source trace even when Planning adjusts the quantity.

### 2.3 ConfirmedNeedSourceReference

Represents the trace from a confirmed line to upstream generation and inputs.

Required attributes:

- `need_generation_run_id`
- `theoretical_need_line_id`
- `planning_input_set_id`
- `weekly_menu_reference`
- `attendance_reference`
- `recipe_bom_reference` when available

This reference enables an operator to explain why the demand exists and how it was derived.

### 2.4 ConfirmedNeedAdjustment

Represents a controlled Planning adjustment.

Required attributes:

- `confirmed_need_adjustment_id`
- `confirmed_need_line_id`
- `adjusted_by` and `adjusted_at`
- `reason_code` or `reason_note`
- `before_quantity`
- `after_quantity`
- `unit`

Every manual quantity change must be attributable and reviewable.

### 2.5 ConfirmedNeedIssue

Represents a blocking issue or warning in confirmation.

Required attributes:

- `confirmed_need_issue_id`
- `confirmed_need_batch_id`
- `confirmed_need_line_id` when line-specific
- `severity` (`BLOCKING` or `WARNING`)
- `issue_code`
- `message`
- `is_blocking`

Blocking issues prevent approval.

### 2.6 ConfirmedNeedChange

Represents an auditable command result or lifecycle event. It records event ID, event type, actor, timestamp, affected line, before/after summary, and reason where required.

### 2.7 Approved snapshot and version

Approval records the approved batch version, approved confirmed line identities, quantities, actor, timestamp, and issue summary. Later corrections create a new explicit version or reopened path and must not silently alter the approved snapshot.

## 3. Lifecycle

```text
Draft Review
  → Validated
  → Approved
  → Released for Purchase Handoff
```

Correction path:

```text
Approved / Released for Purchase Handoff
  → Reopened with reason
  → Draft Review
  → Validated
  → Approved
```

### Draft Review

Confirmed lines have been created from generated theoretical needs and may be reviewed or adjusted by Planning.

### Validated

The batch has no unresolved blocking issues. Warnings may remain visible.

### Approved

Planning accepts the confirmed quantities as the approved demand for the service period.

### Released for Purchase Handoff

The approved confirmed demand has been released to the Purchase Handoff capability. This is not Procurement execution and does not create supplier assignments or purchase orders.

### Reopened

A previously approved or released batch is explicitly reopened with a reason. The prior approved snapshot remains preserved.

## 4. Commands

Commands are the only approved way to change Confirmed Need state.

### CreateConfirmedNeedsFromGeneration

Creates a Draft Review batch from a Need Generation run that is Released for Confirmation. It copies theoretical lines into confirmed lines, sets initial confirmed quantity equal to theoretical quantity, records source references, and emits `ConfirmedNeedsCreated`.

The command is rejected if the source generation run is not Released for Confirmation.

### ValidateConfirmedNeeds

Evaluates confirmed lines and issues. It emits `ConfirmedNeedsValidated` when no blocking issues remain, or `ConfirmedNeedValidationFailed` otherwise.

### AdjustConfirmedNeedLine

Changes a confirmed quantity in Draft Review or Reopened state. It requires actor, timestamp, reason code or note, before quantity, and after quantity. It emits `ConfirmedNeedLineAdjusted`.

Adjustments after approval are rejected unless `ReopenConfirmedNeeds` succeeds first.

### ApproveConfirmedNeeds

Approves a Validated batch when no blocking issues remain. It records approved snapshot/version and emits `ConfirmedNeedsApproved`.

### ReopenConfirmedNeeds

Reopens an Approved or Released for Purchase Handoff batch with an explicit reason. It preserves the prior approved snapshot and emits `ConfirmedNeedsReopened`.

### ReleaseConfirmedNeedsForPurchaseHandoff

Releases an Approved batch to Purchase Handoff. It records actor, timestamp, released version, and confirmed line identities. It emits `ConfirmedNeedsReleasedForPurchaseHandoff`.

The command is rejected when the batch is not Approved.

## 5. Events

Minimum event set:

- `ConfirmedNeedsCreated`
- `ConfirmedNeedsValidated`
- `ConfirmedNeedValidationFailed`
- `ConfirmedNeedLineAdjusted`
- `ConfirmedNeedsApproved`
- `ConfirmedNeedsReopened`
- `ConfirmedNeedsReleasedForPurchaseHandoff`

Each event carries event ID, ConfirmedNeedBatch ID, affected line IDs where relevant, actor, timestamp, and before/after or reason details appropriate to the command.

## 6. Read models

Read models serve the UI and are not an alternative command path.

### ConfirmedNeedWorkbench

Primary Planning workspace for this step. It shows service period, source generation status, confirmed need status, issue counts, changed line count, and available actions.

### ConfirmedNeedIssues

Groups blocking issues and warnings by service date, school, dish, ingredient, source line, and issue code.

### ConfirmedNeedLineReview

Shows theoretical quantity, confirmed quantity, unit, adjustment marker, source trace, and line status.

### ConfirmedNeedAdjustmentHistory

Explains each manual change with actor, timestamp, reason, before quantity, and after quantity.

### ConfirmedNeedApprovalSummary

Manager-facing summary showing source generation version, line counts, adjustment counts, unresolved warnings, approved by/at, approved version, and release status.

## 7. MVP validation rules

The following are blocking unless a later approved rule explicitly changes their classification:

- Source Need Generation run is missing or not Released for Confirmation.
- Confirmed line lacks source trace to the theoretical need line.
- Confirmed quantity is negative.
- Manual adjustment lacks reason code or note.
- Manual adjustment lacks before/after quantity evidence.
- Approval attempted while blocking issues remain.
- Release for Purchase Handoff attempted from a non-Approved batch.
- Approved or released confirmed needs are modified without reopening.
- Approved or released confirmed needs are silently overwritten by regenerated theoretical needs.

Warnings may include large adjustment variance, zero confirmed quantity for a generated line, or source generation version differs from a previous confirmation batch.

## 8. Domain boundaries and downstream relationship

Confirmed Need belongs to Planning.

It owns Planning approval of demand quantities. It does not recalculate theoretical needs; that remains Need Generation.

Confirmed Need does not assign suppliers, create purchase orders, mutate warehouse stock, create dispatch documents, perform QA, create finance records, or edit recipe/BOM data.

Purchase Handoff may later consume approved confirmed demand references, but it must not redefine the approved Planning quantity.

## 9. Decision-first UX

The default workbench answers: **Can Planning approve and release this confirmed demand for Purchase Handoff?**

Primary view shows only:

- service period;
- source generation status;
- confirmed need status;
- blocking issue count;
- warning count;
- changed line count;
- approve action;
- release for Purchase Handoff action.

Expandable detail shows:

- source theoretical lines;
- confirmed quantity details;
- adjustment reasons;
- variance indicators;
- blocking issue details;
- approval and release history.

Audit and history are not shown by default; they are available through a detail or explain view.

## 10. OPS v1 compatibility notes

The following OPS v1 structures are reference evidence, not a prescribed Atlas schema:

- actual/effective needs and override behavior show useful business intent;
- hand-entered or override values must remain traceable and reasoned;
- purchase assignment feeds are downstream evidence and should not be treated as Confirmed Need ownership.

Atlas should preserve the intent: calculated demand can be reviewed, adjusted with reason, approved, and released without losing source trace.

## 11. Out of scope and implementation readiness

PD-01.8 does not implement React UI, Supabase migrations or RPCs, Retool changes, production-data changes, supplier assignment, purchase orders, warehouse, dispatch, finance, QA, or recipe/BOM editing.

The next bounded implementation task may provide an in-memory Confirmed Need domain, tests, and a minimal review workbench. It must preserve the rule that Confirmed Need is the approved demand gate before Procurement.
