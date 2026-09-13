# Atlas UI vNext 06D — Interaction Affordance and Workbench Polish Design

**Date:** 2026-09-13  
**Status:** Owner-approved design direction in chat; written-spec review pending  
**Baseline:** `197e9003ac9aebabfdf8ab08f46b5571881085ae`  
**Cutover candidate kept frozen:** Draft PR #286 at `1f4d3b4738d600d721727b2e42ebc36254fe6118`  
**Task family:** `ATLAS-UI-VNEXT-06D-OPERATOR-AFFORDANCE-AND-WORKBENCH-POLISH-CLOSEOUT`

## 1. Purpose

Atlas vNext is technically cutover-ready at the entrypoint level, but Product acceptance remains blocked because the operator interface is still too visually quiet and several workbench interactions remain confusing or incomplete.

06D is a frontend-only Product/UX closeout. It improves interaction affordance, visual hierarchy, and selected workbench ergonomics without changing business authority, backend contracts, Supabase schema, RLS, RPCs, command semantics, Retool, or hosted data.

The governing principle remains:

> **FACTS EXPLICIT — STATE DERIVED — SUPPORTING OBJECTS GENERATED.**

UI implication:

> **BUSINESS CAPABILITY → OPERATOR JOB / DECISION → COMMAND / READ MODEL → SCREEN / INTERACTION.**

06D must improve how existing authority is presented. It must not change authority to compensate for poor UI.

## 2. Evidence and authority

### 2.1 Business authority

Use existing Atlas backend/domain contracts and current Staging schema as authoritative. Staging remains at migration frontier:

`20260908225248_purchase_preparation_replacement_frontier`.

No backend redesign is authorized.

### 2.2 Retool evidence

OPS v1 Retool remains behavioral evidence only. Preserve useful operator properties:

- direct job names;
- compact/dense tables;
- explicit toolbar actions;
- stable date/School context;
- direct operator mental model.

Reject:

- browser-owned SQL;
- browser-owned business authority;
- optimistic success without authoritative readback;
- raw technical IDs;
- obsolete visual limitations.

Retool uses visible controls such as `Refresh` and `Thêm nhà cung ứng` in compact table toolbars. 06D should recover this explicit action affordance without copying Retool architecture.

### 2.3 Owner PPT review

The six-slide owner review is an explicit Product acceptance input. The six findings are part of 06D scope, not optional polish.

## 3. Global non-goals

06D MUST NOT:

- change Supabase schema, migrations, RLS, RPC signatures, Edge Functions, or business APIs;
- change Recipe/Menu locking authority;
- change Planning, Confirmed Need, Procurement, PO, PXK, or Reconciliation semantics;
- create new persisted lifecycle/status concepts;
- add dual-write or synchronization behavior;
- change the production environment contract;
- merge or modify PR #286 as part of this design slice;
- introduce a generic dashboard, wizard, notification center, page builder, or new component framework;
- replace Chakra UI;
- copy Retool implementation patterns such as browser SQL.

## 4. Global interaction grammar

### 4.1 Button hierarchy

The current system has correct semantic variants but overuses the transparent `utility` treatment. Ordinary operator commands must visibly look clickable at rest.

Use these roles:

#### Primary

For exactly one dominant valid business command when one exists.

Examples:

- `Lưu thay đổi`
- `Xác nhận`
- `Phát hành đơn`
- `Phát hành phiếu xuất kho`

Treatment:

- solid eucalyptus background (`action.primary.default`);
- white/inverse text;
- approximately 8 px radius;
- semibold label;
- clear hover and pressed states;
- optional meaningful leading icon.

#### Secondary

For explicit supporting commands.

Examples:

- `Áp dụng`
- `Xem trước`
- `Thêm`
- `Xuất XLSX`
- `Xuất PDF`

Treatment:

- subtle filled or lightly tinted workbench surface;
- visible border;
- approximately 8 px radius;
- foreground primary/default text;
- clear hover state.

#### Tertiary

For low-emphasis but real commands.

Examples:

- `Xem`
- `Sửa`
- `Đóng`
- `Kiểm tra`

Treatment:

- non-transparent subtle surface at rest;
- visible control shape;
- approximately 8 px radius;
- stronger hover fill;
- no plain-text appearance for a real button.

#### Icon utility

For compact universally recognizable utilities only.

Examples:

- Refresh;
- calendar trigger;
- close icon.

Treatment:

- explicit compact shaped control at rest;
- minimum 36×36 target where established;
- icon-only controls require accessible labels/tooltips;
- hover/pressed/focus states remain clear.

#### Destructive

For destructive/cancellation commands only.

Treatment:

- restrained danger surface/border;
- never used merely to attract attention.

### 4.2 Transparent actions

Transparent text treatment is reserved for true link/navigation-like affordances, not normal business commands.

Existing `variant="utility"` usages must be audited. Textual actions such as `Xem / sửa`, `Đóng`, `Xuất`, `Kiểm tra`, and similar commands should generally move to Secondary or Tertiary according to business importance.

Do not mechanically convert shell navigation or row navigation that is intentionally link-like.

### 4.3 Geometry

Change control radius from the current 6 px visual language toward approximately **8 px** for buttons and interactive controls.

Do not use pill-shaped controls by default.

Keep existing dense 36/40 px control heights unless a specific component requires otherwise.

### 4.4 Interaction states

All interactive controls must have distinct:

- rest;
- hover;
- pressed;
- focus-visible;
- disabled.

Pressed treatment may use a slightly darker surface and/or restrained ~1 px visual depression. Avoid heavy shadows.

Disabled controls keep the frozen grammar:

- neutral/readable;
- `bg.subtle`;
- `fg.muted`;
- `border.subtle`;
- full opacity;
- no active hover;
- unavailable cursor where appropriate.

### 4.5 Tables

Tables stay dense and operational, but hierarchy must be stronger:

- header background distinct from body;
- stronger header weight;
- consistent numeric alignment;
- predictable column spacing;
- restrained row separators;
- visible hover and selected-row treatment;
- selected rows keep the existing attention rail where applicable;
- row actions must look like controls, not incidental text.

Do not add cards around ordinary tables.

## 5. Vietnamese calendar control

### 5.1 Problem

Current `AtlasDateInput` is segmented `DateInput` with `locale="vi-VN"` and correct `dd/mm/yyyy` presentation, but no popup calendar exists.

### 5.2 Target

Replace the shared date interaction with a sanctioned Atlas date picker that keeps canonical business values as `YYYY-MM-DD` and presents a popup Vietnamese calendar.

Visible field example:

```text
Ngày phục vụ
┌──────────────────────┐
│ 13/09/2026        📅 │
└──────────────────────┘
```

Calendar example:

```text
‹      Tháng 9 2026      ›
T2 T3 T4 T5 T6 T7 CN
   1  2  3  4  5  6
7  8  9 10 11 12 [13]
14 15 16 17 18 19 20
...
              Hôm nay
```

### 5.3 Required behavior

- popup calendar, not browser-native date UI;
- Vietnamese month/day labels;
- Monday-first week;
- visible `dd/mm/yyyy` with leading zeros;
- canonical controlled value remains `YYYY-MM-DD`;
- clicking field or calendar icon opens popup;
- selected date clearly highlighted;
- today gets a distinct but subtler marker;
- keyboard navigation works;
- focus returns correctly after selection/close;
- disabled/frozen states follow neutral disabled grammar;
- popup remains within viewport on desktop and mobile;
- no date-framework replacement unless Chakra's supported primitives cannot satisfy the contract and a separate decision is approved.

### 5.4 Date ranges

Where the business scope is truly a date range, the UI may use one coherent range picker rather than two unrelated primitive inputs, provided canonical `YYYY-MM-DD` boundaries and existing commands remain unchanged.

Do not force a range picker onto single-day commands.

## 6. PPT Slide 1 — School Defaults

### 6.1 Operator job

Maintain School default student/teacher portions and quickly understand which Schools are active.

### 6.2 Required changes

- remove repetitive explanatory copy under `Sĩ số mặc định` when it adds no decision value;
- expose a simple visible sequence/order column (`#`) based on presentation/display order, not database identity;
- expose a visible `Trạng thái` column so inactive Schools are identifiable row-by-row;
- use operator labels such as `Đang hoạt động` / `Ngừng hoạt động`;
- retain dense table behavior.

### 6.3 Save interaction

Preferred target:

- dirty values → `Lưu thay đổi` → authoritative save → authoritative readback → success/error feedback.

Do not rename `Xem thay đổi` to `Lưu thay đổi` if the control still only opens another review stage.

The extra Review step for ordinary School default bulk edits should be removed if implementation verification confirms no existing business contract requires it. This is a UI flow simplification only; the backend command/readback remains authoritative.

If removal of Review would violate an existing safety contract discovered during implementation, STOP and flag `DECISION_REQUIRED_SCHOOL_DEFAULTS_REVIEW` rather than silently changing authority.

## 7. PPT Slide 2 — Ingredient/Supplier master-detail

### 7.1 Problem

Selecting an Ingredient/Supplier currently causes a visually abrupt table compression and editor appearance. The workbench feels like a pop-out form rather than a stable operational surface.

### 7.2 Target geometry

Desktop:

```text
┌──────────────────────────────────────────────────────────────┐
│ Search / Status / Refresh / + Tạo nguyên liệu                │
├───────────────────────────────────────┬──────────────────────┤
│ Ingredient catalogue                  │ Chi tiết nguyên liệu │
│ selected row highlighted              │ editor               │
│                                       │                      │
│                                       │ [Lưu thay đổi]       │
└───────────────────────────────────────┴──────────────────────┘
```

Requirements:

- stable attached master/detail geometry;
- selected catalogue row remains visible/highlighted;
- creation and editing use the same detail surface;
- no full-workbench width animation;
- local detail-content transition only: approximately 120–180 ms fade plus ~6 px movement;
- workbench shell stays stationary;
- narrow view may stack catalogue/detail while preserving back/close context.

This refines the earlier geometry rule: master/detail is job-relative. Ingredient/Supplier is a genuine master/detail task, so an attached split is appropriate.

## 8. PPT Slide 3 — Recipe ADD duplicate safety

### 8.1 Problem

An operator can issue `ADD` for an Ingredient already present in the effective Recipe, producing two visible lines for the same Ingredient and creating substantial confusion.

### 8.2 Frontend safety rule

For 06D:

> `ADD` means adding an Ingredient not already present in the current effective Recipe context.

When an operator selects an Ingredient already present:

- block the `ADD` command in the UI;
- explain that the Ingredient already exists and show the current quantity;
- offer `Chuyển sang Điều chỉnh định lượng`;
- preselect the existing Recipe line/target when switching;
- require the operator to explicitly confirm the command kind change.

Do **not** silently convert `ADD` into `ADJUST_QUANTITY`.

This may be stricter than the backend, which is acceptable for frontend safety.

If real business evidence demonstrates a legitimate repeated-line use case for the same Ingredient, stop and raise a separate Product decision rather than weakening this rule during 06D.

## 9. PPT Slide 4 — Recipe catalogue and lock semantics

### 9.1 Catalogue hierarchy

Strengthen:

- header contrast;
- column grouping/alignment;
- lifecycle/lock visibility;
- action affordance;
- row selection/hover.

### 9.2 Lock communication

When a base Recipe is locked after approved operational use, operators must immediately understand both state and next action.

Preferred language:

```text
🔒 Công thức gốc đã khóa
Chỉnh qua Lệnh điều chỉnh
```

Actions:

- unused/editable Recipe: `Sửa công thức`;
- locked Recipe: `Xem công thức` + `Tạo lệnh điều chỉnh`.

Inside the locked editor/read view, clearly state:

`Công thức này đã được sử dụng trong vận hành. Công thức gốc chỉ đọc; thay đổi tiếp theo được thực hiện bằng Lệnh điều chỉnh.`

Do not expose unnecessary version/fingerprint terminology.

## 10. PPT Slide 5 — Weekly Menu Dish Type columns

### 10.1 Problem

The Menu grid must not omit authoritative active Dish Types simply to fit the viewport.

### 10.2 Target behavior

Render all active Dish Types in configured display order as columns.

Example:

```text
Trường       Món mặn    Món canh    Món xào    Rau    Tráng miệng ...
---------------------------------------------------------------------
Bình Mỹ      ...        ...         ...        ...    ...
Tân Thành    ...        ...         ...        ...    ...
```

Requirements:

- active Dish Type catalogue is the rendering authority;
- empty assignment displays an explicit empty cell/state;
- School identity column remains sticky/preserved where practical;
- Dish Type columns may scroll horizontally;
- do not hide categories to fit width;
- preserve existing Weekly Menu command/approval semantics.

This is a functional completeness requirement, not cosmetic polish.

## 11. PPT Slide 6 — Pantry line ergonomics

### 11.1 School identity belongs on the line

Each Pantry line must visibly carry its own School/location identity rather than relying only on a page-level selector.

Example:

```text
Trường      Nguyên liệu     Mục đích       Số lượng    Đơn vị    Ghi chú
────────────────────────────────────────────────────────────────────────
[Bình Mỹ▼]  [Gạo thơm▼]     [Bổ sung▼]      [  5.0 ]    kg        [...]
```

The page-level School scope may remain as:

- filter;
- bulk/default prefill for new lines;
- contextual narrowing.

But the authoritative visible line context must remain clear.

Implementation must preserve the existing backend Pantry authority and line identity. No schema change is authorized.

### 11.2 Alignment

Use one consistent grid for all row controls.

Validation/help text must reserve space or render without causing neighboring fields to jump vertically.

### 11.3 Notes vs reasons

`Ghi chú` is always optional for normal Pantry lines.

Do not show hidden mandatory rules such as `Cần ghi chú cho mục đích này` unless an existing business contract explicitly requires a reason.

When a true business command requires justification, label it explicitly as:

`Lý do` — required.

Do not overload optional `Ghi chú` as an implicit required reason.

## 12. Existing frozen interaction rules retained

06D must preserve unless this spec explicitly overrides them:

- Soft Mineral palette;
- compact operational density;
- table-first workbenches;
- one dominant business action;
- quiet healthy state / exception-first when relevant;
- Review frozen-refresh semantics;
- recovery message families;
- shared Refresh 36×36 behavior, 800 ms spin, 200 ms completion lift;
- `prefers-reduced-motion` behavior;
- primary page transition: 60 ms exit, 180 ms entry, no horizontal slide/scale/stagger;
- frontend may be stricter than backend for safety, never looser;
- disabled controls remain neutral/readable.

## 13. Component-level target map

Expected shared components affected conceptually:

- `src/vnext/atlas/system.ts`
- `src/vnext/atlas/AtlasDateInput.tsx` (may be renamed/refactored only if imports remain bounded and migration is complete)
- `src/vnext/atlas/AtlasRefreshButton.tsx`
- shared button usages across vNext workbenches
- shared table/component styling where appropriate.

Expected domain surfaces:

- School Defaults;
- Ingredient/Supplier;
- Recipe base + Change Orders;
- Planning Sources / Weekly Menu / Pantry;
- Procurement;
- PXK;
- Reconciliation.

The exact implementation file list must be derived from repository inspection. Do not use this section as permission for broad refactoring.

## 14. Implementation slices

06D should be implemented in small bounded slices even if one final PR is used.

### 06D-A — Shared interaction system

- Vietnamese popup calendar;
- button hierarchy and visible rest surfaces;
- radius/state rules;
- table/header hierarchy;
- targeted audit of utility-button usage.

### 06D-B — Master Data

- School Defaults owner-review fixes;
- Ingredient/Supplier stable master-detail.

### 06D-C — Recipe

- duplicate ADD frontend guard;
- stronger catalogue hierarchy;
- lock semantics and action clarity.

### 06D-D — Planning Sources

- complete Dish Type columns;
- Pantry School-per-line/context/alignment/note semantics.

### 06D-E — Cross-workbench consistency

- review all seven modules against shared button/calendar/table grammar;
- do not invent screen-specific variants without need.

## 15. Testing and acceptance

### 15.1 Unit/component tests

Add or update focused tests for:

- `AtlasDatePicker` Vietnamese labels, ISO round-trip, opening/closing, selection, keyboard focus, disabled behavior;
- button variant rest/hover/disabled contract where testable;
- School status/order/save flow;
- stable Ingredient/Supplier selection/detail flow;
- Recipe duplicate ADD block and explicit switch to quantity adjustment;
- locked Recipe actions;
- Weekly Menu active Dish Type column completeness/order;
- Pantry School line visibility/editing and optional note behavior.

Do not increase timeouts merely to make tests pass.

### 15.2 Existing regressions

Run all existing vNext connected regressions and preserve certified business behavior.

No existing backend/domain test may be weakened.

### 15.3 Visual review

Review deterministic local/review-mode scenarios at minimum:

- 1366×768;
- 1440×900;
- 1920×1080;
- 360×800.

Check:

- all seven modules;
- calendar popup containment;
- button affordance at rest;
- no page-level horizontal overflow except intentional table/grid scroll containers;
- dense table usability;
- Ingredient/Supplier master-detail geometry;
- Recipe locked/unlocked states;
- Weekly Menu multi-Dish-Type horizontal behavior;
- Pantry row grid and validation alignment;
- keyboard/focus paths;
- reduced motion.

### 15.4 Build/certification

At implementation completion require existing frontend certification commands, boundary checks, typegen/typecheck/build/Storybook, formatting and diff whitespace checks according to repository conventions.

Supabase Full Integration is not required merely because 06D changes UI. It should be run only if the implementation unexpectedly touches shared connection/backend boundaries, which would itself be scope drift requiring review.

## 16. Scope-drift gates

STOP and report rather than implement if any of these become necessary:

- Supabase migration;
- RPC/API signature change;
- RLS/grant change;
- new persisted business state;
- Recipe command semantics change;
- Pantry schema/authority change;
- Weekly Menu approval semantics change;
- production environment change;
- Retool modification;
- change to PR #286 entrypoint candidate during 06D implementation.

Classify such a discovery as `VNEXT06D_SCOPE_DRIFT` and request Product/Architecture review.

## 17. Relationship to production cutover

Current states remain distinct:

```text
06C technical entrypoint candidate:
ENTRYPOINT_CANDIDATE_READY

06D Product/UI acceptance:
PENDING IMPLEMENTATION
```

PR #286 remains Draft/open/unmerged while 06D is designed and implemented.

After 06D is merged to `main` and certified:

1. rebase/update PR #286 onto the new main baseline;
2. rerun exact-head Frontend CI;
3. rerun applicable cutover certification and rollback proof;
4. visually verify the exact-head normal-site candidate;
5. require explicit owner authorization before merging #286.

## 18. Definition of done

06D is complete only when:

- Vietnamese popup calendar replaces segmented-only date interaction across the sanctioned shared path;
- real operator buttons visibly look like buttons at rest;
- utility variant is no longer misused for ordinary textual commands;
- School Defaults exposes row order/status and has a direct, truthful save flow;
- Ingredient/Supplier uses stable attached master/detail geometry;
- Recipe duplicate-Ingredient ADD is safely blocked with explicit route to quantity adjustment;
- Recipe lock state and allowed actions are obvious;
- Weekly Menu displays all active Dish Types in configured order;
- Pantry lines visibly carry School context, remain aligned, and `Ghi chú` is optional;
- all seven modules conform to the shared interaction grammar;
- existing business contracts and backend authority remain unchanged;
- four target viewports pass visual acceptance;
- connected/frontend regression and build certification pass;
- PR #286 remains unmerged until separately re-certified and authorized.
