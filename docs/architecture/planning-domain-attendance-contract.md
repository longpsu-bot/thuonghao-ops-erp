# PD-01.2 — Planning Domain Attendance Contract

**Status:** MVP contract v0.1
**Domain:** Planning
**Business owner:** Tổ Kế hoạch
**Parent architecture:** ARCH-001 — OPS ERP Business Architecture

## 1. Purpose

Attendance is the Planning-owned source of portion counts used by need generation. Weekly Menu answers **what** each school is planned to eat; Attendance answers **how many** student and teacher portions are expected for each school and service date.

Need Generation may consume an attendance version only when the related Weekly Menu and Attendance inputs are both controlled and approved. Attendance is a planning input, not an ingredient calculation. It must preserve source, corrections, approval, and handoff traceability so an operator can explain which counts were used.

This contract re-expresses the useful business intent of OPS v1 as an explicit Planning object. It does not copy the Retool screen or prescribe the final database schema.

## 2. Ownership and business objects

Planning owns Attendance import, validation, correction, approval, reopening, and handoff. Stable IDs identify operational records; dates, schools, portions, sources, versions, and events carry business meaning.

### 2.1 AttendanceBatch

Represents one controlled attendance submission for a service period, normally a school week.

Required attributes:

- `attendance_batch_id`
- `period_start` and `period_end`
- `source_type`, `source_name`, and `source_signature`
- `status`
- `rows_count` and `issue_count`
- `imported_by` and `imported_at`
- `approved_by` and `approved_at` when approved
- `version`

A batch is the unit of validation, approval, and handoff. Re-importing or correcting data creates a new version or explicit change history; it must not silently rewrite an approved snapshot.

### 2.2 AttendanceLine

Represents the portion count for one school on one service date.

Required attributes:

- `attendance_line_id`
- `attendance_batch_id`
- `service_date`
- `school_id`
- `student_portions`
- `teacher_portions`
- `status`
- `source_row_ref`
- `created_by`, `created_at`, `updated_by`, and `updated_at`

The business uniqueness key for MVP is `school_id + service_date`. Student and teacher portions are separate facts because they may have different operational meaning or downstream rules. Zero is valid when the source explicitly records no portions; negative values are invalid.

### 2.3 AttendanceIssue

Represents a validation result attached to a batch or line.

Required attributes:

- `attendance_issue_id`
- `attendance_batch_id`
- `attendance_line_id` when line-specific
- `severity` (`BLOCKING` or `WARNING`)
- `issue_code`
- `message`
- `is_blocking`
- `resolved_at` and `resolved_by` when resolved

Validation severity is a domain fact. The UI may group or label issues, but it must not turn a warning into an approval bypass or hide a blocking issue.

### 2.4 AttendanceChange

Represents an auditable command result or lifecycle event. It records event ID, event type, actor, timestamp, affected line, before/after summary, and reason where required. It must be sufficient to explain imported values, edited portions, approval, reopening, and the version handed to need generation.

### 2.5 Approved snapshot and version

Approval records the approved batch version, approver, timestamp, and stable line identities. A `Used for Need Generation` handoff references that approved version. Later corrections create an explicit reopened version and must not silently demote or mutate the approved or used snapshot.

## 3. Lifecycle

```text
Draft
  → Validated
  → Approved
  → Used for Need Generation
```

Correction path:

```text
Approved / Used for Need Generation
  → Reopened by command with reason
  → Draft
  → Validated
  → Approved
```

### Draft

The batch has been imported or edited but is not yet approved. It may contain blocking issues.

### Validated

Validation has completed with no unresolved blocking issues. Warnings may remain and must be visible to the approver.

### Approved

Planning accepts the batch version as the authoritative attendance input for the service period. Approval creates a protected snapshot.

### Used for Need Generation

The approved batch version has been handed to the downstream need-generation process. This state records handoff; it does not mean that Attendance owns or calculates ingredient needs.

### Reopened

A previously approved or used batch was explicitly reopened with a reason. Reopening preserves the prior approved snapshot and permits correction through the normal Draft → Validated → Approved path.

## 4. Commands

Commands are the only approved way to change Attendance state.

### ImportAttendance

Imports a source payload containing period, source metadata, rows, and actor. It normalizes rows into AttendanceLine records, creates a Draft AttendanceBatch, records row count and source signature, and emits `AttendanceImported`. Dates, schools, and portion values are validated before approval; invalid rows produce issues rather than disappearing.

### ValidateAttendance

Evaluates the batch against reference data and period rules. It refreshes AttendanceIssue records and emits `AttendanceValidated` when no blocking issues remain, or `AttendanceValidationFailed` otherwise. It may run only for Draft, Reopened, or an idempotent Validated batch. It must not demote Approved or Used for Need Generation; correction requires ReopenAttendance first.

### EditAttendanceLine

Corrects a line's school/date/portion facts in Draft or Reopened state. It invalidates the previous validation result as needed, records before/after values in AttendanceChange, and emits `AttendanceLineEdited`. Editing an Approved or Used batch is rejected until ReopenAttendance succeeds.

### ApproveAttendance

Approves a Validated batch only when no blocking issues remain and the actor has Planning approval authority. It records an approved version snapshot and emits `AttendanceApproved`. Approval is rejected while any blocking issue is unresolved.

### ReopenAttendance

Reopens an Approved or Used for Need Generation batch by explicit command. A reason code or note is required. The command preserves the prior approved snapshot, records actor/time/reason, moves the editable working version to Reopened, and emits `AttendanceReopened`. It must not silently alter downstream released documents.

### MarkAttendanceUsedForNeedGeneration

Hands an Approved batch version to Need Generation. The command references the approved AttendanceBatch version, records the handoff actor/time, changes status to Used for Need Generation, and emits `AttendanceUsedForNeedGeneration`. It is rejected from Draft, Validated, Reopened, or an already used version.

## 5. Events

Minimum event set:

- `AttendanceImported`
- `AttendanceValidated`
- `AttendanceValidationFailed`
- `AttendanceLineEdited`
- `AttendanceApproved`
- `AttendanceReopened`
- `AttendanceUsedForNeedGeneration`

Each event carries event ID, AttendanceBatch ID, affected line IDs where relevant, actor, timestamp, and before/after or reason details appropriate to the command. Events explain state transitions; they do not replace the approved snapshot or read models.

## 6. Read models

Read models serve the UI and are not an alternative command path.

### AttendanceWorkbench

The primary Planning workspace. It shows the service period, batch status, school/date portion summary, validation state, changed school-days, and available actions.

### AttendanceValidationIssues

Groups blocking issues and warnings by severity, service date, school, and issue type. It shows whether each issue is unresolved and what correction is required.

### AttendanceChangeHistory

Explains imported values, edited student/teacher portions, actor, timestamp, approval version, reopen reason, and the version used for handoff.

### AttendanceApprovalSummary

Manager-facing summary showing imported rows, changed school-days, unresolved warnings, approved by/at, approved version, and handoff status.

## 7. MVP validation rules

The following are blocking unless a later approved rule explicitly changes their classification:

- unknown or inactive school reference;
- service date outside the selected service period;
- duplicate `school_id + service_date` line;
- negative student portions;
- negative teacher portions;
- invalid or structurally unreadable source row;
- approval attempted while a blocking issue is unresolved.

Warnings may include an omitted expected school-day, unusual zero portions, or a source value that differs from a prior approved version. Warnings must remain visible and may require acknowledgement according to later approval policy.

Additional lifecycle rules:

- approved attendance cannot be edited without ReopenAttendance;
- attendance used for need generation cannot be silently demoted or overwritten;
- a used batch correction creates a new explicit version or revision path and preserves the used snapshot;
- Attendance validation and approval do not calculate ingredient quantities.

## 8. Domain boundaries and downstream relationship

Planning owns Attendance. Attendance references schools and service dates and may be consumed with an approved Weekly Menu, but Attendance does not own or edit Weekly Menu.

Attendance does not generate ingredient needs by itself. Need Generation is a downstream Planning capability that requires controlled Weekly Menu and Attendance inputs and applies its own approved calculation rules.

Attendance does not assign suppliers, create purchase orders, or edit warehouse, dispatch, finance, recipe, BOM, or QA objects. It does not silently rewrite released downstream documents. Other domains may read an approved or handed-off version through an explicit contract, but may not redefine Attendance facts.

## 9. Decision-first UX

The default workbench answers: **Can Planning approve or hand off this attendance batch for need generation?**

Primary view shows only:

- week or service period;
- approval status;
- blocking issue count;
- warning count;
- changed school-day count;
- approve action;
- handoff / use-for-need-generation action.

School/date lines, portion details, validation explanations, and correction controls are expandable. Audit and history are not shown by default; they are available through a detail or explain view. React coordinates interaction but must not calculate authoritative need quantities.

## 10. OPS v1 compatibility notes

The following OPS v1 structures are reference evidence, not a prescribed Atlas schema:

- `daily_orders` currently represents service-date and school attendance/order headers;
- `daily_orders_audit` preserves audit evidence;
- `app_upsert_daily_orders_bulk(...)` supports bulk updates;
- default attendance values may be synchronized from school settings;
- downstream purchase-assignment rebalance can be triggered by `daily_orders` insert, update, or delete.

Atlas should preserve the intent—bulk import, defaults, corrections, audit, and downstream impact visibility—through explicit Attendance commands and read models. It should not copy Retool page structure or treat current tables and triggers as the final domain contract.

## 11. Out of scope and implementation readiness

PD-01.2 does not implement React UI, Supabase migrations or RPCs, Retool changes, production-data changes, supplier assignment, purchase orders, warehouse, dispatch, finance, recipe, BOM, QA, or ingredient need calculation.

The next bounded implementation task may provide an in-memory or backend command boundary, validation tests, and a minimal Attendance workbench. It must preserve this lifecycle, approved-version traceability, and the requirement that Need Generation consumes both controlled Weekly Menu and Attendance inputs.
