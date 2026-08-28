# Planning Workbench Visual Refinement V2

**Status:** Approved visual direction; pending user spec sign-off  
**Date:** 2026-08-28  
**Implementation baseline:** `82260b0608e280e6d49696a9a620add14f17b2bd` on PR #236  
**Governing architecture:** `OPS_SYSTEM_MAP v1.0` / `ARCH-002`

This spec supersedes only the visual/layout portions of `2026-08-28-planning-compact-workbench-ux-design.md`. All functional, command-authority, multi-school, and PR #235 safety invariants from V1 remain mandatory.

## Goal

Turn the functionally correct Planning UI into a disciplined enterprise operations workbench. The redesign improves composition, density, scanability, and action placement without changing backend contracts, business behavior, lifecycle semantics, command scope, or the current Atlas visual identity.

Approved direction: **Hybrid C** — calm outer frame + dense work surfaces.

The operator experience should read as: **the same Atlas application, but substantially cleaner, denser, and easier to operate**.

## Authority and boundaries

Atlas Staging remains backend/domain authority. At this checkpoint it has 51 repository migrations, latest migration `20260826011050`, 92 `atlas_api` functions, and one active hosted school. The hosted one-school fixture must not constrain the multi-school UX; review fixtures/tests remain the proof for arbitrary school subsets.

Retool remains operator-workflow/density evidence only. Its Planning/Purchase app still contains `attendance`, `menuAssign`, `PurchasePlanner`, `PantryScheduleSetup`, a multi-school selector, and `Đặt hàng tự động`. These support dense operational tables and multi-school work, but Retool visual styling, direct SQL, and state authority must not be copied into Atlas.

This task is frontend-only. Do not change Supabase schema/migrations, `atlas_api`, Edge Functions, Live OPS, Retool, Need Generation, Procurement/Purchase Handoff behavior, lifecycle states, authoritative calculations, dependencies, or Automatic Pantry/Pantry Rules.

If implementation appears to require a backend/schema/API change, stop and return to design review.

## Approved composition

The user approved a table-first desktop mockup. This written spec is the durable implementation contract for that visual direction.

```text
Page title + one-line context (scrolls away)
────────────────────────────────────────────────────────────
STICKY OPERATING RAIL
Week · Service date · School scope │ 1 Menu 2 Attendance 3 Pantry 4 Confirmed │ Primary action
────────────────────────────────────────────────────────────
Active workbench
  compact toolbar
  dense table/data surface
  actionable warning/blocker only when needed
  collapsed support details

Confirmed Need only:
┌ Daily navigator ┐ ┌ Selected-date confirmation workbench ┐
│ compact dates   │ │ slim summary                         │
│ short states    │ │ compact warning                      │
│                 │ │ filters                              │
│                 │ │ DENSE LINE-ITEM TABLE                │
└─────────────────┘ └──────────────────────────────────────┘
```

The mockup is authoritative for composition, hierarchy, density, sticky-context behavior, and table-first character — not for fields that current governed read models do not provide.

Do not invent ingredient groups, unsupported exports, new totals requiring backend work, or any other data just because it appeared in a concept image.

## Visual system is frozen

This is **not** a theme redesign.

Preserve current Atlas:

- dark navy sidebar and shell;
- light workspace surfaces;
- typography family/hierarchy;
- CSS variables and `atlasTheme`;
- Atlas primary blue;
- existing green/amber/red semantics;
- current button, input, table, border, radius, shadow, focus, and icon language.

No gradients, decorative KPI cards, oversized illustrations, new typography system, or Planning-specific palette. New CSS should be Planning-scoped wherever practical. No global theme token changes are expected.

## Page frame

### Calm page header

The normal Planning page title appears once at the top and scrolls away.

Content:
- `Lập nhu cầu theo tuần`;
- one concise explanatory sentence;
- existing global user/application controls from the shell.

Target vertical budget: approximately **64–76 px** within Planning content.

Do not duplicate week/date/school/workflow/action context in this title block.

### Slim sticky operating rail

One sticky operating rail sits directly below the page header and remains visible while workbench tables scroll.

Target desktop height: **52–56 px**.

It contains three zones:

**Left — operating context**
- week selector/range;
- global service date;
- parent multi-school display scope.

**Center — workflow**
- exactly four steps: `Thực đơn`, `Sĩ số`, `Bổ sung`, `Xác nhận nhu cầu`;
- step number + label + one short status/count;
- active step uses current Atlas blue;
- text remains sufficient without color.

**Right — stable action slot**
- one primary action in a consistent location;
- at most two compact secondary controls when existing behavior requires them;
- no invented commands.

For Menu/Attendance/Pantry, the primary action mirrors the existing review/save sequence: `Xem thay đổi` when review is required, then `Lưu` when the current review is valid. For Confirmed Need, use `Lưu` while dirty and `Chuyển sang lên đơn` only when existing release eligibility permits it. If blocked/stale/unknown, show the current state/reason rather than a fake next action.

Do not create a second permanent status row.

## Shared workbench grammar

All four steps use the same visual grammar:

1. minimal step heading/context only if needed;
2. compact toolbar;
3. primary table/data surface;
4. inline blockers/warnings only when actionable;
5. collapsed `Chi tiết hỗ trợ` at the bottom.

Avoid nested panel-on-card-on-panel layouts. Prefer one primary bordered work surface per step.

Desktop density targets:

- toolbar: **44–48 px**;
- table header: **36–38 px**;
- standard row: **38–42 px**;
- grouping row: **32–36 px** if governed grouping exists;
- in-table controls: **32–34 px**;
- cell horizontal padding: **12–14 px**;
- compact gaps: **8–12 px**;
- outer workbench gutter: **16–20 px**.

At **1366×768**, target roughly **9–12 useful rows** visible where content allows. At 1920×1080, show more rows rather than enlarging controls.

Primary action remains in the sticky rail and should not be duplicated in the local toolbar.

Technical evidence — signatures, checksums, history, raw ids, correction chain, verbose diagnostics — remains collapsed under `Chi tiết hỗ trợ` unless it is actively blocking the operator.

## Step 1 — Thực đơn

Menu is a dense operational grid, not a dashboard.

Use one visible school row per selected service date, with school anchored left and governed dish/menu-slot columns in configured order. Dish cells remain editable using existing controls.

Keep toolbar controls limited to current source/import/search functions that materially help the operator. Do not add school filters locally; parent school scope is authoritative display scope.

If dish columns exceed width, allow horizontal scrolling **inside the table surface only**. Prefer a sticky school column if practical. The overall page must not horizontally overflow.

Review output should be compact and adjacent to the table, not a second large dashboard panel.

## Step 2 — Sĩ số

Attendance is a compact editable roster.

Preferred columns:
- Trường;
- Học sinh mặc định;
- Học sinh thực tế;
- Giáo viên;
- Tổng suất;
- concise status/issue indicator if useful.

Editable numeric controls align consistently. Defaults vs actual values should remain clear without large color blocks.

A single slim summary strip is acceptable if useful, but no KPI cards. Existing default-derived behavior, explicit-zero semantics, review-before-save behavior, and authoritative payload rules remain unchanged.

## Step 3 — Bổ sung

Pantry is a week-level exception/adjustment table.

Preferred columns:
- Trường;
- Ngày phục vụ;
- Nguyên liệu;
- Số lượng;
- Đơn vị;
- Lý do/mục đích;
- Trạng thái;
- row action if currently needed.

Toolbar may contain compact search/filter controls and `Thêm dòng` as a secondary action.

The week-global zero-addition control remains explicit:

`Xác nhận toàn tuần không có bổ sung`

It must never appear scoped to only the selected schools.

School scope affects visibility/choices only; complete week-level rows remain in review/save payloads. No Automatic Pantry visual or behavior is added.

## Step 4 — Xác nhận nhu cầu

Confirmed Need is the most table-first surface in Planning.

### Desktop split

Use a narrow left daily navigator and a large right selected-date workbench.

Left pane width target:
- **300–330 px** around a 1366 px viewport;
- **320–360 px** at larger desktop sizes.

The left pane contains only:
- `Tổng quan theo ngày`;
- optional compact search if useful;
- date rows with short state and small navigation affordance.

No large cards/charts. Selected date uses restrained Atlas blue selection.

Opening a day remains navigation/context only and must preserve PR #235: global service date realigns before operational detail mounts.

### Right pane order

1. selected-date title;
2. one slim summary strip;
3. compact warning/blocker strip only when needed;
4. compact filter toolbar;
5. line-item table occupying most vertical space;
6. pagination/row-count control if applicable;
7. collapsed support/details.

### Summary strip

Use one horizontal strip, never separate KPI cards.

Always-safe fields include governed line count and current operator-facing state. Optional calculated/confirmed/variance totals may appear only if the complete authoritative line set is already loaded and the aggregate is a transparent presentation calculation. Do not add backend work solely to support summary numbers.

### Filters

Use only current loaded data: ingredient/search, current confirmation state, date if locally needed, and optionally `Chỉ hiển thị dòng có chênh lệch` if it can be computed directly from current line + draft values.

Do not reintroduce an internal school selector. Do not infer ingredient grouping from names. If governed group metadata does not exist, render a flat table.

### Table

The table is the visual center of the screen.

Preferred order using current governed fields:
- Nguyên liệu;
- Đơn vị;
- current calculated/proposed quantity fields as contract allows;
- Xác nhận (editable);
- Chênh lệch;
- Lý do/ghi chú in the most compact form compatible with validation rules;
- row detail/action affordance.

School/delivery-location context must remain discoverable in multi-school views. If not full columns, use a compact secondary line or row detail only when lines remain unambiguous.

Variance color is semantic support only; numbers/text remain sufficient.

Hidden dirty edits remain intact. The existing warning about unsaved changes outside the school display scope stays immediately above the table as one compact strip. Save continues to use the complete authoritative changed-line set.

`Chuyển sang lên đơn` appears only in the fixed rail action slot and only when existing release rules permit it.

## Responsive behavior

Primary targets: **1366×768** and **1920×1080**.

At 1366×768:
- no page-level horizontal overflow;
- sticky rail remains compact;
- Confirmed Need should remain split side-by-side if practical;
- tables use internal overflow only where necessary.

At 1920×1080:
- do not enlarge controls proportionally;
- use the extra space for more rows and useful column width.

At approximately **900 px and below**:
- the sticky rail may horizontally scroll as one region or use a controlled two-line form;
- Confirmed Need daily navigator stacks above detail;
- tables may scroll internally;
- no separate mobile workflow is introduced.

## Component boundaries

Do not turn `PlanningInputsWorkbench.tsx` into a larger styling monolith.

Expected responsibilities:
- `PlanningInputsWorkbench`: page/week/date/step/school state and dirty coordination;
- `PlanningOperatingRail` (new or extracted): sticky context + workflow + action slot;
- `PlanningWorkflowBar`: workflow presentation inside the rail;
- `PlanningSchoolScopeControl`: behavior preserved, visual tightening only;
- Menu/Attendance: current behavior wrapped in shared dense shell;
- `PantryWorkbench`: current behavior, dense shared shell;
- `ConfirmedNeedReviewWorkbench`: table-first right pane;
- daily Need overview: narrow left navigator;
- Planning-scoped CSS: geometry/density/sticky behavior.

Targeted extraction is encouraged only when it makes these boundaries clearer. Avoid unrelated refactors.

## Functional invariants that must remain green

- school selection is display scope only;
- Menu/Attendance preview and Save use complete authoritative working rows;
- Pantry remains week-global and includes hidden authoritative rows;
- Confirmed Need Save includes all changed lines, including hidden dirty lines;
- global selected service date remains authoritative for operational Confirmed Need detail;
- no-demand dates cannot retain stale editors/actions;
- existing dirty-change confirmation/disarm behavior remains intact;
- browser roles use governed `atlas_api`, never private tables;
- visual filtering never enables an action;
- Automatic Pantry remains deferred.

## Error/content quality

The redesign may improve placement/hierarchy of backend-safe messages but must not silently rewrite backend semantics.

Two pre-existing hosted content issues remain out of this visual scope unless separately authorized:
- one Confirmed Need blocker in English;
- one lifecycle message with mojibake.

## Automated acceptance

Tests should protect behavior/structure rather than pixels.

At minimum prove:
1. exactly one workflow `tablist`;
2. separate scrolling page-title region and sticky operating rail;
3. rail contains week, date, school scope, workflow, and primary-action slot;
4. primary action follows existing review/save/release eligibility only;
5. multi-school scope remains persistent/display-only across all steps;
6. Menu/Attendance authoritative payload tests remain green;
7. Pantry hidden-row/full-payload/whole-week-zero tests remain green;
8. Confirmed Need hidden-dirty/full-save tests remain green;
9. PR #235 date/no-demand tests remain green;
10. support evidence collapsed by default, blockers visible;
11. no Automatic Pantry controls;
12. no backend calls, migrations, dependencies, or global theme changes introduced.

## Hosted visual acceptance

Before merge, review exact-head Cloudflare preview at **1366×768** and **1920×1080**.

Accept only if:
- it is unmistakably the same Atlas visual system;
- title area is calm and non-duplicative;
- one slim sticky operating rail remains visible;
- primary action stays in a stable far-right location;
- no page-level horizontal overflow;
- tables show materially more useful information above the fold than current PR #236;
- Menu, Attendance, and Pantry feel like the same product family;
- Confirmed Need is clearly table-first, not dashboard-like;
- daily navigator remains compact;
- support evidence is visually subordinate;
- no new console warnings/errors attributable to the change;
- hosted one-school Staging remains usable;
- three-school review fixtures demonstrate arbitrary multi-school behavior.

## Delivery strategy

PR #236 remains the functional baseline and has been returned to draft while V2 is designed/implemented.

V2 should build on PR #236 rather than discard its tested multi-school and safety work. The implementation plan must treat this primarily as a **layout/component/styling refactor with preservation tests**, not another workflow/domain feature.

No merge is authorized until the V2 hosted visual review is complete and the user approves the result.
