# PD-01.6 — Planning Domain Need Generation Contract

**Status:** MVP contract v0.1  
**Domain:** Planning  
**Business owner:** Tổ Kế hoạch  
**Parent architecture:** ARCH-001 — OPS ERP Business Architecture

## 1. Purpose

Need Generation is the Planning-owned capability that converts a ready Planning input set into traceable theoretical need lines.

Planning Input Readiness answers whether approved Weekly Menu and Attendance inputs are controlled and compatible. Need Generation answers what theoretical ingredients and quantities are required before Planning confirms the final demand.

This contract does not approve procurement demand. It does not assign suppliers, create purchase orders, mutate warehouse stock, create dispatch documents, edit recipe/BOM data, perform QA, or create finance records.

Core business rule:

```text
Ready PlanningInputSet
+ approved calculation rules
+ referenced recipe/BOM data
= Theoretical needs for confirmation
```

The output of this contract is not purchase-ready. It must be reviewed by the later Confirmed Need capability.

## 2. Ownership and business objects

Planning owns the Need Generation run and generated theoretical lines. Recipe/BOM data remains owned by the Recipe domain. Need Generation references recipe/BOM versions; it does not edit them.

### 2.1 NeedGenerationRun

Represents one generation attempt for a service period.

Required attributes:

- `need_generation_run_id`
- `planning_input_set_id`
- `period_start` and `period_end`
- `status`
- `input_snapshot`
- `generated_line_count`
- `blocking_issue_count` and `warning_count`
- `generated_by` and `generated_at`
- `validated_by` and `validated_at` when validated
- `released_by` and `released_at` when released for confirmation
- `version`

The run is the unit of generation, validation, and release for confirmation. It must reference stable input versions rather than mutable UI rows.

### 2.2 NeedGenerationInputSnapshot

Represents the exact Planning inputs and calculation references used by a run.

Required attributes:

- `planning_input_set_id`
- `weekly_menu_id` and `weekly_menu_version`
- `attendance_batch_id` and `attendance_version`
- `readiness_snapshot_id` or equivalent readiness version
- `calculation_rule_version`
- referenced recipe/BOM version metadata where available

This snapshot is required so future users can explain why a theoretical line was produced.

### 2.3 TheoreticalNeedLine

Represents one generated theoretical need line before Planning confirmation.

Required attributes:

- `theoretical_need_line_id`
- `need_generation_run_id`
- `service_date`
- `school_id`
- `dish_id`
- `recipe_id` and `recipe_version` when available
- `bom_line_id` when available
- `ingredient_id`
- `quantity`
- `unit`
- `source_trace_id`
- `calculation_trace`
- `status`

A theoretical line is a calculation result, not an approved demand line. It can feed Confirmed Need, but Procurement must not consume it directly.

### 2.4 NeedGenerationIssue

Represents a blocking issue or warning created during generation or validation.

Required attributes:

- `need_generation_issue_id`
- `need_generation_run_id`
- `theoretical_need_line_id` when line-specific
- `severity` (`BLOCKING` or `WARNING`)
- `issue_code`
- `message`
- `school_id`, `service_date`, `dish_id`, `recipe_id`, `ingredient_id` when applicable
- `is_blocking`

Blocking issues prevent release for confirmation.

### 2.5 NeedGenerationChange

Represents an auditable command result or lifecycle event. It records event ID, event type, actor, timestamp, affected run or line, before/after status, and reason where applicable.

### 2.6 Generated snapshot and version

When generated needs are released for confirmation, the system records the run version, input snapshot, generated theoretical line identities, issue summary, actor, and timestamp. Later recalculation creates a new explicit run or version and must not silently overwrite a released generated snapshot.

## 3. Lifecycle

```text
Not Generated
  → Generated
  → Validated
  → Released for Confirmation
```

Correction path:

```text
Generated / Validated / Released for Confirmation
  → Invalidated by input or recipe/BOM revision
  → Not Generated
  → Generated
```

### Not Generated

A ready input set exists, but no theoretical needs have been produced for the selected service period and version.

### Generated

The system has produced theoretical lines and issues. Blocking issues may still exist.

### Validated

Generated theoretical lines have no unresolved blocking issues. Warnings may remain visible to Planning.

### Released for Confirmation

Planning has released the generated theoretical run to Confirmed Need review. This does not mean the quantities are approved for Procurement.

### Invalidated

A generated run became stale because the readiness snapshot, Weekly Menu, Attendance, calculation rule, or recipe/BOM references changed. The prior output remains traceable, but it must not be reused as current without explicit re-generation.

## 4. Commands

Commands are the only approved way to change Need Generation state.

### GenerateTheoreticalNeedsFromInputs

Consumes a Ready or Need Generation Requested PlanningInputSet. It snapshots input references, applies approved calculation rules, references recipe/BOM data, creates theoretical need lines, creates issues, and emits `TheoreticalNeedsGenerated`.

The command is rejected when the input set is Not Ready or Invalidated.

### ValidateGeneratedNeeds

Evaluates generated lines and issues. It emits `NeedGenerationValidated` when no blocking issues remain, or `NeedGenerationValidationFailed` otherwise. It may not silently recalculate released generated needs.

### ReleaseGeneratedNeedsForConfirmation

Releases a Validated generation run to Confirmed Need. It records actor, timestamp, released version, and line identities. It emits `GeneratedNeedsReleasedForConfirmation`.

The command is rejected when the run is not Validated or has unresolved blocking issues.

### InvalidateGeneratedNeeds

Invalidates a Generated, Validated, or Released for Confirmation run when referenced inputs, calculation rules, or recipe/BOM versions change. It records actor, timestamp, reason, and affected reference. It emits `NeedGenerationInvalidated`.

Invalidation does not rewrite Confirmed Need, Purchase Handoff, or any later released documents.

## 5. Events

Minimum event set:

- `TheoreticalNeedsGenerated`
- `NeedGenerationValidated`
- `NeedGenerationValidationFailed`
- `GeneratedNeedsReleasedForConfirmation`
- `NeedGenerationInvalidated`

Each event carries event ID, NeedGenerationRun ID, input snapshot reference, actor, timestamp, issue summary, and reason where applicable.

## 6. Read models

Read models serve the UI and are not an alternative command path.

### NeedGenerationWorkbench

Primary Planning workspace for this step. It shows service period, input readiness status, generation status, issue counts, generated line count, and release action.

### NeedGenerationIssues

Groups blocking issues and warnings by service date, school, dish, recipe, BOM line, ingredient, and issue code.

### TheoreticalNeedsReview

Shows generated theoretical lines with source trace, quantity, unit, recipe/BOM reference, and calculation trace. It supports explanation, not procurement execution.

### NeedGenerationSummary

Manager-facing summary showing input versions, generated line count, blocking/warning counts, generated by/at, validated by/at, and released by/at.

### NeedGenerationHistory

Explains generation, validation, failure, release, and invalidation events.

## 7. MVP validation rules

The following are blocking unless a later approved rule explicitly changes their classification:

- PlanningInputSet is missing, Not Ready, or Invalidated.
- Weekly Menu or Attendance version differs from the readiness snapshot.
- Missing active recipe for a planned dish that requires calculation.
- Missing BOM lines for a required recipe.
- Missing or inactive ingredient reference unless explicitly allowed by policy.
- Generated theoretical quantity is negative.
- Generated line lacks source trace to input and recipe/BOM references.
- Release for confirmation attempted while blocking issues remain.
- Released generated needs are recalculated or overwritten without explicit invalidation and new version/run.

Warnings may include zero theoretical quantity, recipe/BOM version differs from previously used version, or non-blocking inactive metadata that requires later review.

## 8. Domain boundaries and downstream relationship

Need Generation belongs to Planning.

It references Weekly Menu, Attendance, Readiness, Recipe, and BOM data, but it does not own or edit those objects.

Need Generation does not approve demand. Confirmed Need is the later Planning approval gate that can review, adjust, approve, and release demand.

Need Generation does not assign suppliers, create purchase orders, mutate warehouse stock, create dispatch documents, perform QA, create finance records, or edit recipe/BOM data.

Procurement must not consume theoretical lines directly as approved demand.

## 9. Decision-first UX

The default workbench answers: **Can Planning release generated theoretical needs for confirmation?**

Primary view shows only:

- service period;
- readiness/input status;
- generation status;
- blocking issue count;
- warning count;
- generated line count;
- release for confirmation action.

Expandable detail shows:

- input snapshot versions;
- generated line details;
- missing recipe/BOM/ingredient blockers;
- calculation trace;
- issue explanations;
- generation and validation history.

Audit and history are not shown by default; they are available through a detail or explain view.

React may coordinate interaction, but it must not hide authoritative calculation rules inside UI components.

## 10. OPS v1 compatibility notes

The following OPS v1 structures are reference evidence, not a prescribed Atlas schema:

- theoretical needs currently derive from planning sources and effective BOM views/functions;
- effective BOM behavior is business evidence for recipe/BOM resolution;
- current purchase-assignment rebalance is downstream behavior and must not be treated as Need Generation ownership.

Atlas should preserve the intent: controlled inputs, traceable calculation, explicit generation, visible blockers, and no direct jump from theoretical lines to procurement execution.

## 11. Out of scope and implementation readiness

PD-01.6 does not implement React UI, Supabase migrations or RPCs, Retool changes, production-data changes, Confirmed Need implementation, supplier assignment, purchase orders, warehouse, dispatch, finance, QA, or recipe/BOM editing.

The next bounded implementation task may provide an in-memory Need Generation domain, tests, and a minimal review workbench. It must preserve the rule that generated theoretical needs are not confirmed purchase demand.
