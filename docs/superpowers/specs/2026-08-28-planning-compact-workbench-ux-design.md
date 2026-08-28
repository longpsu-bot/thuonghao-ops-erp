# Planning Compact Workbench UX V1

**Status:** Proposed implementation design  
**Date:** 2026-08-28  
**Baseline:** `e683d775c8756da8af089164eb3793b0792dd6ee`  
**Governing architecture:** `OPS_SYSTEM_MAP v1.0` / `ARCH-002`  
**Selected direction:** Model B — Compact Workbench, refined with one unified workflow/status bar and multi-school display scope.

## Goal

Make the accepted Planning workflow cleaner and faster for daily operators without reopening backend contracts or changing Planning ownership.

The operator journey remains:

`Thực đơn → Sĩ số → Nhu cầu bổ sung → Xác nhận nhu cầu → Purchase Handoff`

This change is presentation and interaction only. React may reorganize, summarize, filter, and progressively disclose existing read models; it must not recalculate readiness, Need Generation, quantities, lifecycle state, or command authority.

## Current authority and boundaries

Atlas Staging is the backend/domain authority. At design time it has 51 repository migrations and 92 `atlas_api` functions. Live OPS has no Atlas schemas or Atlas API functions and remains out of scope.

Retool remains an operator-vocabulary and production-flow reference only. The retained Planning/Purchase app contains `PurchasePlanner`, Attendance, Menu assignment, and `PantryScheduleSetup` / `Đặt hàng tự động`; those patterns may inform wording and workflow density but must not be copied as Atlas architecture, direct SQL, or state authority.

Automatic Pantry/Pantry Rules are explicitly deferred. V1 does not add rule tables, schedules, automation, APIs, jobs, or a fake actionable placeholder.

## Chosen information architecture

### 1. Compact page header

Keep one compact header for the Planning workbench:

- page title: `Lập nhu cầu theo tuần`;
- week selector / date range;
- multi-school display-scope selector;
- secondary page actions such as refresh and supported export;
- staging/non-production identity remains visible outside the operational content.

Do not dedicate a separate permanent row to source statuses.

### 2. One unified workflow/status bar

Replace the existing status summary row plus separate four-tab row with one four-item workflow tab bar.

Each tab contains:

- step number;
- operator-facing name;
- one short status or count;
- active-state styling.

Canonical labels:

1. `Thực đơn`
2. `Sĩ số`
3. `Bổ sung`
4. `Xác nhận nhu cầu`

Example compact states are `Sẵn sàng`, `Cần lưu`, `1 mục`, `Chờ xác nhận`, `Không có nhu cầu cần lập`, or `Đã chuyển sang lên đơn`. These are presentation mappings of existing authoritative state; the UI must not invent new lifecycle states.

The active tab uses the primary/blue emphasis. Complete/current states use success styling, attention states use warning styling, and blocked/waiting states use the existing danger/neutral semantics as appropriate. Color is supplementary; text remains sufficient.

### 3. Multi-school display scope

Planning must not be designed around one school.

The header school control is a searchable multi-select over schools already returned in the governed Planning read models. It supports:

- default `Tất cả trường`;
- selecting any subset of two or more schools;
- selecting one school when an operator intentionally wants a narrow view;
- `Chọn tất cả` and returning to all-school scope;
- compact summary text: `Tất cả trường`, one school name, or `N trường`.

The selected school scope persists while switching among the four Planning tabs and changing service dates inside the same week. When the loaded school catalog changes, invalid selections are dropped; if no valid selected school remains, the UI returns to `Tất cả trường`.

This is a **display scope**, not a new backend command scope. It must never truncate authoritative save payloads, alter preflight semantics, or make a week-global command appear school-local.

Tests must use fixtures with at least three schools even though current hosted Staging contains only one active school.

### 4. Display-scope behavior by step

**Thực đơn:** filter rendered school/day rows by the multi-school display scope. Existing complete-replacement/save semantics remain unchanged; hidden schools remain part of authoritative source state.

**Sĩ số:** filter rendered school rows by the same display scope. Default-derived and saved Attendance behavior remains unchanged.

**Bổ sung:** Pantry remains capable of rows for multiple schools. The display scope filters visible rows and school choices without changing the week-level Pantry batch contract. The existing `không có bổ sung` confirmation remains week-global and must be labeled/positioned so a filtered view cannot imply that it applies only to selected schools.

**Xác nhận nhu cầu:** filter Confirmed Need lines by the multi-school display scope. The current selected service-date safety invariant remains mandatory: the active Confirmed Need batch date must equal the global selected service date. School filtering must not affect that invariant.

If unsaved Confirmed Need changes become hidden by a school filter, the drafts remain intact and the UI must state that unsaved changes exist outside the current display scope. Save semantics continue to operate on the authoritative changed-line set, not only currently visible lines.

### 5. Main workspace layout

The active tab controls the main workspace. Do not render four large peer panels at once.

For `Thực đơn`, `Sĩ số`, and `Bổ sung`, use the full main width for the active workbench, with compact filter/actions near the top and support material collapsed.

For `Xác nhận nhu cầu`, use a split desktop layout:

- left: `Tổng quan theo ngày`, showing date, short status, and the allowed open action;
- right: selected date Confirmed Need summary, filters, and editable table.

The daily overview is navigation/context for Confirmed Need; it is not a second authority. Opening a daily Need continues to realign the global selected service date before mounting its operational detail.

### 6. Progressive disclosure

Default operator view should contain only what is necessary to decide or act.

Move these behind `Chi tiết hỗ trợ` / existing disclosure controls unless they are required to unblock the operator:

- signatures/checksums;
- approval/change history;
- technical source evidence;
- correlation/technical identifiers;
- correction-chain evidence;
- verbose diagnostics.

Blocking errors and actionable warnings remain visible in the active workbench.

Do not expose raw IDs as primary labels when a governed display name exists.

### 7. Toolbars and actions

Each active step gets one compact action area. Avoid repeated labels and stacked action groups when controls can be grouped naturally.

Primary action rules remain unchanged:

- source steps use existing review/save boundaries;
- Confirmed Need uses existing save and release boundaries;
- disabled reasons remain backend-authorized;
- no action becomes enabled because of visual filtering alone.

Do not add actions that are not currently supported. Export controls should appear only where the implementation actually supports export.

### 8. Automatic Pantry is later

Retool's `PantryScheduleSetup` / `Đặt hàng tự động` confirms a real operator concept, but Atlas V1 does not implement it in this UX task.

A future capability should be designed as Pantry Rules / automatic supplementation, likely generating predictable additions while manual Pantry becomes the exception/override surface. That requires its own contract and design review.

This implementation must not add a clickable `coming soon` control that suggests automation exists.

## Interaction invariants

The implementation must preserve these accepted behaviors:

- global selected service date is authoritative for operational Confirmed Need detail;
- 25/08-style no-demand dates never retain another day's operational editor/actions;
- dirty-edit confirmation prevents silent loss when changing date/week/tab where existing behavior already requires it;
- display filtering never changes domain truth or command authority;
- switching school display scope never resets saved source data;
- browser roles continue to call governed `atlas_api`, never private Atlas tables.

## Responsive target

Desktop operations are the primary target. The layout must remain usable at 1366×768 and 1920×1080 without introducing a second horizontal status row.

At narrower widths, the unified workflow bar may scroll horizontally or wrap in a controlled way, and the Confirmed Need split layout may stack. No new mobile-specific workflow is required in V1.

## Expected implementation surface

The implementation should stay in the existing Planning frontend modules and shared styling. Expected areas include:

- `PlanningInputsWorkbench.tsx` and its tests;
- `ConfirmedNeedReviewWorkbench.tsx` and its tests where controlled multi-school filtering is needed;
- `PantryWorkbench.tsx` only if required to respect the parent display scope without changing the Pantry contract;
- existing Planning/shared CSS or theme files.

Do not change Supabase migrations, `atlas_api`, Retool, Production, Procurement, or Need Generation behavior.

If implementation discovers that multi-school display filtering requires a backend contract or schema change, stop and return to design review instead of widening scope.

## Acceptance tests

At minimum, automated tests must prove:

1. exactly four workflow tabs remain and the old duplicate status/tab presentation is gone;
2. each unified tab exposes a short operator-facing state from existing data;
3. multi-school selector defaults to all schools and can select multiple schools;
4. school scope persists across the four tabs;
5. menu, attendance, Pantry, and Confirmed Need rendered rows respect display scope without changing authoritative payload semantics;
6. fixtures exercise at least three schools;
7. Confirmed Need date-alignment regressions from PR #235 remain green;
8. school filtering cannot leave hidden dirty Confirmed Need changes unacknowledged;
9. no new backend call, migration, or automatic Pantry capability is introduced;
10. existing frontend certification (format, typecheck, tests, build, diff check) passes in GitHub Actions.

## Hosted review gate

After merge and Cloudflare deployment, review the actual hosted Staging UI with a multi-school fixture or hosted dataset when available. The final UX review should confirm:

- only one workflow/status navigation row exists;
- current task and state are obvious at a glance;
- operators can work with all schools or an arbitrary school subset;
- no control implies a one-school architectural restriction;
- no display filter changes domain status or command meaning;
- support/technical evidence no longer dominates the default view;
- the accepted Planning operational invariants remain intact.
