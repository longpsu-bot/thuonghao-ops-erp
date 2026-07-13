# PD-01.4 — Planning Domain Input Readiness Contract

**Status:** MVP contract v0.1  
**Domain:** Planning  
**Business owner:** Tổ Kế hoạch  
**Parent architecture:** ARCH-001 — OPS ERP Business Architecture

## 1. Purpose

Planning Input Readiness is the Planning-owned gate that determines whether a service period has controlled inputs for Need Generation.

Weekly Menu answers **what food is planned**. Attendance answers **how many portions are needed**. Input Readiness answers **whether those approved inputs are compatible and ready to be handed to Need Generation**.

This contract does not define ingredient calculation. It does not create needs, supplier assignments, purchase orders, warehouse documents, or dispatch documents. It only defines the readiness gate between approved Planning inputs and a later Need Generation capability.

Core business rule:

```text
Approved Weekly Menu
+ Approved Attendance
= Ready for Need Generation
```

The rule is simple, but the gate must be explicit because future Need Generation must never run from uncontrolled, mismatched, silently edited, or partially approved inputs.

## 2. Ownership and business objects

Planning owns the readiness decision. Weekly Menu and Attendance remain separate Planning objects with their own lifecycles and approvals. Input Readiness references their approved versions; it does not edit them.

### 2.1 PlanningInputSet

Represents one readiness evaluation for a service period.

Required attributes:

- `planning_input_set_id`
- `period_start` and `period_end`
- `status`
- `weekly_menu_reference`
- `attendance_reference`
- `blocking_issue_count` and `warning_count`
- `evaluated_by` and `evaluated_at`
- `requested_by` and `requested_at` when Need Generation is requested
- `version`

The set is the unit of readiness evaluation and future Need Generation handoff. It should reference stable approved input versions, not only dates or mutable display rows.

### 2.2 PlanningInputReference

Represents a versioned reference to an upstream Planning input.

Required attributes:

- `input_type` (`WEEKLY_MENU` or `ATTENDANCE`)
- `input_id`
- `input_version`
- `input_status`
- `period_start` and `period_end`
- `approved_by` and `approved_at` when available
- `handoff_status` when available

The reference is intentionally lightweight. It is enough for Planning to prove which Weekly Menu and Attendance versions were evaluated.

### 2.3 PlanningInputReadinessIssue

Represents a blocking issue or warning created by the readiness evaluation.

Required attributes:

- `readiness_issue_id`
- `planning_input_set_id`
- `severity` (`BLOCKING` or `WARNING`)
- `issue_code`
- `message`
- `input_type` when the issue is tied to a specific input
- `school_id` and `service_date` when coverage-specific
- `is_blocking`

Blocking issues prevent Need Generation request. Warnings remain visible to Planning and may require acknowledgement later, but the MVP gate may still proceed if no blocking issue exists.

### 2.4 PlanningInputReadinessChange

Represents an auditable command result or lifecycle event. It records event ID, event type, actor, timestamp, affected input references, before/after readiness status, and reason where applicable.

### 2.5 Readiness snapshot and version

When readiness passes, the system records the evaluated Weekly Menu version, Attendance version, readiness result, issue summary, actor, and timestamp. When Need Generation is requested, it must reference this readiness snapshot. Later changes to Weekly Menu or Attendance invalidate the prior readiness result unless the input set is explicitly re-evaluated.

## 3. Lifecycle

```text
Not Ready
  → Ready
  → Need Generation Requested
```

Correction path:

```text
Ready / Need Generation Requested
  → Invalidated by input change or explicit reopen
  → Not Ready
  → Ready
```

### Not Ready

One or both Planning inputs are missing, not approved, incompatible, or have blocking readiness issues.

### Ready

Weekly Menu and Attendance are both controlled, approved or already handed off, compatible for the service period, and free from blocking readiness issues.

### Need Generation Requested

Planning has requested Need Generation from a ready input set. This is a handoff state only. It does not mean ingredient needs have been calculated inside this contract.

### Invalidated

A previously ready or requested set becomes invalid because one referenced input was reopened, revised, replaced, or otherwise changed. The system must not silently reuse the old readiness result after input revision.

## 4. Commands

Commands are the only approved way to change readiness state.

### EvaluatePlanningInputReadiness

Evaluates Weekly Menu and Attendance references for a service period. It checks existence, approval state, period compatibility, blocking issues, and school/date coverage. It creates or updates a PlanningInputSet, refreshes readiness issues, and emits one of:

- `PlanningInputReadinessPassed`
- `PlanningInputReadinessFailed`

It may run repeatedly before Need Generation is requested. It must not mutate Weekly Menu or Attendance.

### RequestNeedGenerationFromInputs

Requests Need Generation using a Ready PlanningInputSet. It records the readiness snapshot, actor, timestamp, Weekly Menu reference, and Attendance reference. It emits `NeedGenerationRequestedFromPlanningInputs`.

The command is rejected when the set is Not Ready, Invalidated, missing an approved input reference, or has blocking readiness issues.

### InvalidatePlanningInputReadiness

Invalidates a previously Ready or Need Generation Requested input set when a referenced Weekly Menu or Attendance version changes, reopens, or is replaced. It records actor, timestamp, reason, and affected input reference. It emits `PlanningInputReadinessInvalidated`.

Invalidation does not cancel or rewrite released downstream documents. Later behavior for already generated needs must be defined by the Need Generation and Confirmed Need contracts.

## 5. Events

Minimum event set:

- `PlanningInputReadinessEvaluated`
- `PlanningInputReadinessPassed`
- `PlanningInputReadinessFailed`
- `PlanningInputReadinessInvalidated`
- `NeedGenerationRequestedFromPlanningInputs`

Each event carries event ID, PlanningInputSet ID, input references, actor, timestamp, readiness result, issue summary, and reason where applicable. Events explain the readiness decision; they do not perform ingredient calculation.

## 6. Read models

Read models serve the UI and are not an alternative command path.

### PlanningInputReadinessWorkbench

The primary Planning workspace for this step. It shows the service period, Weekly Menu status, Attendance status, readiness status, issue counts, input versions, and available action.

### PlanningInputReadinessIssues

Groups blocking issues and warnings by input type, service date, school, and issue code. It should make mismatches obvious without forcing the user to inspect all menu and attendance lines.

### PlanningInputReadinessSummary

Manager-facing summary showing evaluated input versions, approval actors/timestamps, blocking and warning counts, readiness result, and whether Need Generation has been requested.

### PlanningInputReadinessHistory

Explains evaluations, readiness failures, readiness passes, invalidations, and Need Generation requests, including the actor and timestamp for each event.

## 7. MVP readiness rules

The following are blocking unless a later approved rule explicitly changes their classification:

- Weekly Menu is missing for the service period.
- Attendance is missing for the service period.
- Weekly Menu is not `APPROVED` or already marked for need generation.
- Attendance is not `APPROVED` or already marked used for need generation.
- Weekly Menu has unresolved blocking issues.
- Attendance has unresolved blocking issues.
- Weekly Menu and Attendance service periods are not the same and no explicit compatibility rule exists.
- Attendance contains a school/date that cannot be matched to the service period being evaluated.
- A referenced approved input version has changed after readiness was evaluated.
- Need Generation is requested from a Not Ready or Invalidated set.

Warnings may include:

- Attendance exists for a school/date with no planned menu line.
- Menu exists for a school/date with no attendance line.
- Zero portions for a school/date with a planned menu.
- Input versions differ from a previously evaluated set for the same service period.

The MVP may allow warnings while keeping them visible. Later policy may require acknowledgement for selected warnings.

## 8. Domain boundaries and downstream relationship

Planning Input Readiness belongs to Planning.

It references Weekly Menu and Attendance, but it does not own or edit either object. It does not import menus, import attendance, correct portions, approve attendance, approve menus, or reopen upstream inputs.

It does not calculate ingredient needs. Need Generation is the next bounded Planning capability and must define its own rules for deriving theoretical needs from approved input versions.

It does not assign suppliers, create purchase orders, mutate warehouse stock, create dispatch documents, edit recipe/BOM, perform QA, or create finance/accounting records.

Other domains may later read the readiness result or downstream generated needs, but they may not redefine whether Planning inputs were ready.

## 9. Decision-first UX

The default workbench answers: **Can Planning request Need Generation for this service period?**

Primary view shows only:

- service period;
- Weekly Menu status;
- Attendance status;
- readiness status;
- blocking issue count;
- warning count;
- request Need Generation action.

Expandable detail shows:

- referenced Weekly Menu version;
- referenced Attendance version;
- mismatched school/date coverage;
- blocking issue details;
- warning details;
- evaluated by/at;
- request actor/time.

Audit and history are not shown by default; they are available through a detail or explain view.

React may coordinate this interaction, but it must not calculate authoritative ingredient needs.

## 10. OPS v1 compatibility notes

The following OPS v1 structures are reference evidence, not a prescribed Atlas schema:

- Weekly Menu currently flows through `daily_orders`, `daily_order_dishes`, and related menu sync functions.
- Attendance currently lives around `daily_orders` and `app_upsert_daily_orders_bulk(...)`.
- Existing downstream purchase-assignment rebalance reacts to changes in planning sources.
- OPS v1 exposes separate operational screens for menu and attendance; Atlas should preserve the business intent while giving Planning a clearer readiness gate.

Atlas should preserve the intent: controlled source inputs, visible blocking conditions, explicit handoff, and traceable downstream impact. It should not copy Retool page structure or treat current tables and triggers as the final domain contract.

## 11. Out of scope and implementation readiness

PD-01.4 does not implement React UI, Supabase migrations or RPCs, Retool changes, production-data changes, Need Generation calculation, supplier assignment, purchase orders, warehouse, dispatch, finance, recipe, BOM, QA, or accounting behavior.

The next bounded implementation task may provide an in-memory readiness domain, read models, tests, and a minimal Planning readiness workbench. It must preserve this contract's core rule: Need Generation can only be requested from explicitly ready, versioned Planning inputs.
