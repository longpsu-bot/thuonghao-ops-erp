# PD-01.1 — Planning Domain Weekly Menu Contract

**Status:** MVP Contract v0.1  
**Domain:** Planning  
**Business owner:** Tổ Kế hoạch  
**Parent architecture:** ARCH-001 — OPS ERP Business Architecture  
**MVP objective:** Planning can import, review, correct, approve, and hand off the weekly menu for need generation.

---

## 1. Purpose

Weekly Menu is the first Planning Domain object in the Atlas MVP.

Its job is to turn the weekly school menu into a controlled planning input before attendance, recipe/BOM calculation, confirmed need, purchasing, warehouse, and dispatch workflows depend on it.

In OPS v1, the weekly menu is operationally important but technically coupled to Google Sheets, Retool, Supabase tables, and downstream rebalance behavior. Atlas should preserve the business intent while making the Weekly Menu a clear Planning object with explicit commands, validation, status, and traceability.

Weekly Menu must answer four business questions:

1. Which school is eating which dish on which service date?
2. Is the menu valid enough to generate needs?
3. Who approved this menu as the source for planning?
4. What changed after import or approval?

---

## 2. OPS v1 reference behavior

This contract is based on the current OPS v1 behavior, not on an idealized greenfield model.

Current OPS v1 reference path:

```text
Google Sheet weekly menu
  -> Retool menuAssign page
  -> q_menu_gsheet
  -> js_menu_syncWeek
  -> q_menu_sync_week
  -> public.fn_upsert_weekly_menu(...)
  -> daily_orders / daily_order_dishes
  -> downstream planning and purchase recalculation behavior
```

Current Supabase concepts to preserve as business knowledge:

- `daily_orders` stores school/date order headers.
- `daily_order_dishes` stores dish assignments for each order.
- `menu_import_weeks` stores import metadata such as week, source, sheet name, signature, row count, imported time, and imported user.
- `fn_upsert_weekly_menu(...)` detects same-signature imports, changed school-days, and replaces dish assignments only for changed days.
- Current sync behavior can trigger downstream purchase assignment rebalance for changed school-days.
- Dish changes can affect actual need overrides for affected ingredients, with pantry-specific protection logic.

Atlas should not blindly copy this structure. The correct interpretation is:

> OPS v1 proves the business workflow. Atlas must re-express it as an explicit Planning Domain contract.

---

## 3. MVP scope

Included in PD-01.1:

- Import weekly menu from a source payload.
- Normalize school/date/dish assignments.
- Validate menu rows before approval.
- Allow controlled correction of menu lines.
- Approve menu for planning.
- Reopen an approved menu by command when corrections are required.
- Request need generation from an approved menu.
- Track source, status, actor, timestamp, and change history.

Excluded from PD-01.1:

- Recipe editing.
- BOM editing.
- Attendance editing.
- Confirmed Need implementation.
- Supplier assignment.
- Purchase order generation.
- Warehouse receiving or dispatch.
- Financial or accounting behavior.
- Full replacement of all OPS v1 menu tooling.

---

## 4. Business ownership

Weekly Menu belongs to the **Planning Domain**.

Planning owns:

- menu import;
- menu correction;
- menu validation review;
- menu approval;
- menu reopening;
- handoff to need generation.

Planning does not own:

- dish master data;
- recipe versions;
- BOM details;
- supplier selection;
- stock availability;
- warehouse fulfilment;
- invoice or payment data.

The Recipe Domain owns dish, recipe, recipe version, and BOM governance. Weekly Menu may reference dishes, but it must not redefine dishes or recipes.

---

## 5. Core business objects

### 5.1 WeeklyMenu

Represents one service week of menu planning.

Required business attributes:

- `weekly_menu_id`
- `week_start`
- `week_end`
- `source_type`
- `source_name`
- `source_signature`
- `status`
- `rows_count`
- `issue_count`
- `imported_by`
- `imported_at`
- `approved_by`
- `approved_at`
- `version`

`weekly_menu_id` must be a stable operational identity. Business meaning should come from relationships and attributes, not from encoding meaning into the ID.

### 5.2 WeeklyMenuLine

Represents one dish assignment for one school, one date, and one menu slot.

Recommended normalized meaning:

```text
school + service_date + menu_slot + dish
```

A UI may show this as a weekly grid, but the business contract should treat each assignment as a line.

Required business attributes:

- `weekly_menu_line_id`
- `weekly_menu_id`
- `service_date`
- `school_id`
- `menu_slot`
- `dish_id`
- `status`
- `source_row_ref`
- `created_by`
- `created_at`
- `updated_by`
- `updated_at`

The current Google Sheet-style slots can map to `menu_slot`, for example:

- soup / canh;
- savory / mặn;
- stir-fry / xào;
- dessert / tráng miệng;
- afternoon snack / buổi xế.

The exact slot names may evolve, but the normalized object must remain stable.

### 5.3 WeeklyMenuIssue

Represents a validation issue found during import, edit, approval, or need generation request.

Required business attributes:

- `weekly_menu_issue_id`
- `weekly_menu_id`
- `weekly_menu_line_id` when line-specific
- `severity`
- `issue_code`
- `message`
- `is_blocking`
- `resolved_at`
- `resolved_by`

---

## 6. Lifecycle

Recommended MVP lifecycle:

```text
Draft
  -> Validated
  -> Approved
  -> Need Generation Requested
```

Correction path:

```text
Approved
  -> Reopened
  -> Draft
  -> Validated
  -> Approved
```

### Draft

The weekly menu has been imported or manually edited but is not yet approved.

### Validated

The menu has no blocking validation issues. Warnings may still exist.

### Approved

Planning accepts this menu as the authoritative input for need generation.

### Need Generation Requested

Planning has requested downstream need generation from an approved menu.

This state does not mean needs are correct forever. It only means the approved menu has been handed off to the next Planning process.

### Reopened

A previously approved menu was reopened for correction. Reopening must be explicit and traceable.

---

## 7. Commands

Commands are the only approved way to change Weekly Menu state.

### ImportWeeklyMenu

Purpose: import a weekly menu from an external source.

Input:

- `week_start`
- `source_type`
- `source_name`
- `source_signature`
- `rows`
- `actor_id`

Rules:

- `week_start` must resolve to the intended service week.
- row dates must be inside the week.
- school references must resolve to known schools.
- dish references must resolve to known dishes or create blocking issues.
- duplicate school/date/slot assignments must create blocking issues unless explicitly resolved.
- same-signature import may be skipped only if no database drift or line difference is detected.

Effects:

- create or update WeeklyMenu in Draft state;
- normalize rows into WeeklyMenuLine records;
- create WeeklyMenuIssue records;
- record source signature and row count;
- emit `WeeklyMenuImported`.

### ValidateWeeklyMenu

Purpose: evaluate whether a menu is ready for approval.

Rules:

- blocking issues prevent approval;
- warnings may be approved with acknowledgement;
- missing recipe/BOM readiness may be warning or blocking depending on need generation requirement.

Effects:

- update validation issue list;
- move Draft to Validated only when no blocking issues remain;
- emit `WeeklyMenuValidated` or `WeeklyMenuValidationFailed`.

### EditWeeklyMenuLine

Purpose: correct a school/date/slot dish assignment.

Rules:

- Planning may edit Draft or Reopened menus.
- Editing an Approved menu requires `ReopenWeeklyMenu` first.
- Editing a dish reference must not modify the dish master, recipe, or BOM.

Effects:

- update the line;
- invalidate previous validation result if needed;
- emit `WeeklyMenuLineEdited`.

### ApproveWeeklyMenu

Purpose: make the weekly menu authoritative for planning.

Rules:

- allowed only when no blocking validation issues remain;
- actor must have Planning approval permission;
- approval must snapshot the approved version.

Effects:

- set status to Approved;
- set approved actor and timestamp;
- emit `WeeklyMenuApproved`.

### ReopenWeeklyMenu

Purpose: allow controlled correction after approval.

Rules:

- must require a reason code or note;
- must preserve the previously approved version for traceability;
- must not silently mutate downstream released documents.

Effects:

- move Approved or Need Generation Requested menu to Reopened/Draft;
- emit `WeeklyMenuReopened`.

### RequestPlanningNeedGeneration

Purpose: hand the approved menu to downstream Planning need generation.

Rules:

- allowed only from Approved state;
- must reference the approved WeeklyMenu version;
- must not allow React/UI to calculate authoritative needs directly.

Effects:

- emit `PlanningNeedGenerationRequested`;
- make approved menu available to CalculatedNeed / ConfirmedNeed workflow.

---

## 8. Events

Minimum event set:

- `WeeklyMenuImported`
- `WeeklyMenuValidated`
- `WeeklyMenuValidationFailed`
- `WeeklyMenuLineEdited`
- `WeeklyMenuApproved`
- `WeeklyMenuReopened`
- `PlanningNeedGenerationRequested`

Each event should carry:

- event ID;
- event type;
- WeeklyMenu ID;
- affected WeeklyMenuLine IDs where relevant;
- actor;
- timestamp;
- before/after summary where relevant;
- reason code or note where required.

---

## 9. Read models

Read models serve the UI. They are not the authoritative command model.

### WeeklyMenuWorkbench

Primary Planning workspace.

Shows:

- week;
- menu status;
- schools;
- service dates;
- assigned dishes by slot;
- validation state;
- changed lines;
- actions available to the operator.

### WeeklyMenuValidationIssues

Shows blocking issues and warnings.

Grouped by:

- issue severity;
- service date;
- school;
- menu slot;
- issue type.

### WeeklyMenuChangeHistory

Shows who changed what and when.

Must support explaining:

- imported value;
- edited value;
- approval state;
- reopen reason;
- final value used for need generation.

### WeeklyMenuApprovalSummary

Manager-facing summary.

Shows:

- imported rows;
- changed school-days;
- unresolved warnings;
- approved by/at;
- generated-needs status.

---

## 10. Validation rules

Blocking issues should include:

- service date outside selected week;
- missing or unknown school;
- missing or unknown dish where a dish is required;
- inactive school;
- inactive dish;
- duplicate school/date/slot assignment;
- invalid source payload;
- attempt to approve menu with unresolved blocking issues.

Warnings should include:

- school has no menu on an expected service day;
- dish has no active recipe for the relevant school type;
- dish has incomplete BOM;
- imported menu differs from previously approved version;
- same dish appears in multiple slots where this may be suspicious;
- empty rows or ignored rows in the source payload.

The exact blocking/warning classification may evolve during implementation, but the system must separate validation severity from UI display.

---

## 11. UX rules

Weekly Menu UX must follow ARCH-001:

```text
Decision
  -> Detail
  -> Explain / Audit
```

### Primary decision view

The primary view should answer:

> Can Planning approve this weekly menu for need generation?

Show only decision-critical information:

- week;
- status;
- blocking issue count;
- warning count;
- changed school-day count;
- approval action;
- need generation action.

### Operational detail

Expandable detail should show:

- school/day grid;
- menu slots;
- dish assignments;
- validation issues;
- changed lines.

### Explain / audit

Deep detail should show:

- source row;
- imported value;
- edited value;
- actor;
- timestamp;
- approval/reopen history;
- downstream need generation reference.

The default UI must not expose all traceability details at once.

---

## 12. Domain boundaries

Weekly Menu may trigger downstream work, but it does not own downstream work.

Allowed:

- reference dishes;
- validate dish readiness;
- request need generation;
- preserve source and change history.

Not allowed:

- edit recipes;
- edit BOM lines;
- calculate final confirmed need in React;
- assign suppliers;
- create purchase orders;
- mutate warehouse stock;
- rewrite released downstream documents silently.

Post-approval changes must create explicit commands and events. If downstream planning, purchase, or dispatch has already been released, corrections must become revisions or compensating actions rather than silent overwrites.

---

## 13. Relationship to existing Supabase schema

The current schema already contains useful operational structures:

- `daily_orders`
- `daily_order_dishes`
- `menu_import_weeks`
- `fn_upsert_weekly_menu(...)`

These should be treated as OPS v1 reference implementation and possible compatibility layer, not as the final Atlas domain model.

Implementation may initially reuse these tables/functions where practical, but it must respect the new contract:

- Weekly Menu is a controlled Planning object.
- Import and approval are separate business steps.
- Need generation is requested by command.
- UI reads prepared read models.
- Authoritative state changes happen through commands/RPCs, not direct table editing from React.

---

## 14. MVP success criteria

PD-01.1 is successful when Planning can:

1. import one weekly menu;
2. see whether the menu is valid;
3. understand blocking issues and warnings;
4. correct menu lines;
5. approve the weekly menu;
6. reopen the approved menu with traceability;
7. request need generation from the approved version;
8. explain which source menu produced downstream needs.

This contract is not complete ERP design. It is the minimum stable contract needed to start Weekly Menu implementation without letting Codex invent the domain.

---

## 15. Implementation implications for the next task

The next implementation task should be bounded as:

```text
Planning Domain Sprint 1
PD-01.1 Weekly Menu Foundation
```

Expected implementation scope:

- add or adapt backend contract for Weekly Menu;
- expose a Weekly Menu workbench read model;
- add command boundary for import/validate/approve/reopen/request generation;
- add tests for validation, state transition, and traceability behavior;
- add minimal Atlas UI only after the command/read model contract is clear.

Do not include:

- supplier assignment;
- PO generation;
- warehouse receiving;
- finance;
- generic workflow engine;
- full document handbook.

---

## 16. Open questions

These should not block the MVP contract, but should be resolved during implementation:

1. Who can approve or reopen a weekly menu?
2. Should same-signature import auto-skip, or should Planning explicitly confirm no changes?
3. Which validation warnings block need generation?
4. How should Saturday/non-standard service days be represented?
5. Should Google Sheet remain an import source during MVP, or should Atlas become the primary menu entry UI immediately?
6. What is the cutoff point after which menu changes require manager approval?

---

## 17. Design conclusion

Weekly Menu should become the first controlled Planning object in Atlas.

OPS v1 already proves the workflow. Atlas must now make it explicit:

```text
Import
  -> Validate
  -> Correct
  -> Approve
  -> Request Need Generation
```

This is small enough for MVP, but strong enough to protect downstream Planning, Procurement, and Warehouse workflows.
