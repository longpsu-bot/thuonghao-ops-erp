# Atlas UI vNext 06D — Interaction Affordance and Workbench Polish Design

**Date:** 2026-09-13  
**Status:** Owner-approved written design; implementation planning complete; source implementation not started  
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
- 8 px radius;
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
- 8 px radius;
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
- 8 px radius;
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

Normal interactive controls use exactly **8 px** radius. Workbench containers retain 6 px radius.

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

Keep `AtlasDateInput` as the shared interface, but compose Chakra `DateInput` with Chakra `DatePicker`. Business values remain canonical `YYYY-MM-DD`; operators get both segmented keyboard editing and a popup Vietnamese calendar.

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
- overlay must remain inside Atlas's themed/scoped portal boundary;
- no date-framework replacement or new date dependency.

### 5.4 Date ranges

06D does **not** introduce a generic range-picker abstraction. Existing business range controls continue to use their current start/end values, with each `AtlasDateInput` gaining the same calendar popup. Canonical start/end values and command contracts stay unchanged.

## 6. PPT Slide 1 — School Defaults

### 6.1 Operator job

Maintain School default student/teacher portions and quickly understand which Schools are active.

### 6.2 Required changes

- remove repetitive explanatory copy under `Sĩ số mặc định` when it adds no decision value;
- expose a simple visible sequence/order column (`#`) based on authoritative `display_order`, not database identity or filtered row index;
- expose a visible `Trạng thái` column so inactive Schools are identifiable row-by-row;
- use operator labels `Đang hoạt động` / `Ngừng hoạt động`;
- retain dense table behavior.

### 6.3 Save interaction

The intermediate School Review panel is removed.

Target flow:

`dirty valid values → Lưu thay đổi → existing authoritative bulk save → authoritative readback → success/error feedback`.

Requirements:

- `Lưu thay đổi` is the truthful primary command;
- invalid drafts block save;
- explicit `0` remains valid;
- hidden dirty rows are included in the frozen save delta;
- ordinary Refresh may still run while drafts exist and must preserve/reconcile those drafts according to the existing School behavior;
- UNKNOWN/readback/stale protections remain unchanged;
- no new backend lifecycle or command is created.

## 7. PPT Slide 2 — Ingredient/Supplier master-detail

### 7.1 Problem

Selecting an Ingredient/Supplier currently causes a visually abrupt table compression and editor appearance. The workbench feels like a pop-out form rather than a stable operational surface.

### 7.2 Target geometry

Desktop detail-open geometry is fixed at the existing master/detail rule:

`62% catalogue / 38% attached detail`.

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
- local detail-content transition only: **160 ms** fade plus `translateY(6px → 0)`, ease-out;
- reduced motion removes that local animation;
- workbench shell stays stationary;
- narrow view stacks catalogue/detail while preserving explicit close/back context.

## 8. PPT Slide 3 — Recipe ADD duplicate safety

### 8.1 Problem

A new operator `ADD` can select an Ingredient already present in the effective Recipe, producing two visible lines for the same Ingredient and creating substantial confusion.

### 8.2 Frontend safety rule

For 06D:

> A **new** `ADD` means adding an Ingredient not already present in the current effective Recipe context.

When a new ADD selects an Ingredient already present:

- block Preview/Create in the UI;
- explain that the Ingredient already exists and show current quantity/unit;
- if exactly one effective target line exists, offer `Chuyển sang Điều chỉnh định lượng`;
- after that explicit click, change to `ADJUST_QUANTITY` and preselect the exact target;
- preserve the operator-entered proposed quantity;
- never silently convert the command kind.

If multiple effective lines use the same Ingredient:

- block new ADD;
- explain the ambiguity;
- require the operator to choose `Đổi định lượng` and select the exact line manually;
- never guess a target.

Correction of an already-issued ADD root is not treated as a new duplicate ADD. Existing correction semantics/action identity remain intact.

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

- editable Recipe: `Sửa công thức`;
- locked Recipe: `Xem công thức` + `Tạo lệnh điều chỉnh`.

Inside the locked editor/read view, clearly state:

`Công thức này đã được sử dụng trong vận hành. Công thức gốc chỉ đọc; thay đổi tiếp theo được thực hiện bằng Lệnh điều chỉnh.`

`Tạo lệnh điều chỉnh` switches to the existing peer job/tab through existing exit safety; it performs no hidden command.

Do not expose unnecessary version/fingerprint terminology.

## 10. PPT Slide 5 — Weekly Menu Dish Type columns

### 10.1 Evidence interpretation

Current production `PlanningMenuStage` already renders ACTIVE Dish Types from the authoritative catalogue in `display_order`. The PPT screenshot showed only one type because the review fixture/evidence had only one active type. 06D must therefore **prove completeness with representative fixtures before rewriting renderer logic**.

### 10.2 Target behavior

Render all active Dish Types in configured display order as columns.

Example:

```text
Trường / điểm giao   Món mặn   Món canh   Món xào   Rau   Tráng miệng ...
----------------------------------------------------------------------------
Bình Mỹ              ...       ...        ...       ...   ...
Tân Thành            ...       ...        ...       ...   ...
```

Requirements:

- active Dish Type catalogue is rendering authority;
- inactive Dish Types are absent;
- empty assignment remains an explicit `—` cell;
- School identity column stays visible/sticky where practical;
- Dish Type columns may scroll horizontally inside the workbench;
- do not hide categories to fit width;
- preserve existing Weekly Menu command/approval semantics;
- do not hard-code Vietnamese Dish Type columns.

This is a Product acceptance completeness requirement; implementation may be fixture/test + layout only if the current dynamic mapping already passes the stronger test.

## 11. PPT Slide 6 — Pantry line ergonomics

### 11.1 School identity belongs on the line

Each Pantry draft line already carries authoritative `school_id`. 06D makes that fact visible/editable on every line using existing Pantry School data and the existing draft-edit path.

Example:

```text
Trường / điểm giao   Nguyên liệu   Mục đích   Số lượng   Ghi chú/Lý do
─────────────────────────────────────────────────────────────────────────
[Bình Mỹ▼]            [Gạo thơm▼]   [Bổ sung▼] [ 5.0 ]    [...]
```

The existing School grouping row remains useful because `direct_need_mode` belongs to `school_id + service_date` and stays group-level. Changing a line's School moves it to the corresponding group on rerender; it does not create a new command or copy another School's mode.

### 11.2 Alignment

Use one consistent table/grid alignment for row controls. Validation/help text must reserve stable feedback space so an error in one cell does not vertically shift neighboring controls.

### 11.3 Notes vs reasons

Use the existing `note_rule` authority truthfully:

- `OPTIONAL` → label `Ghi chú`, optional;
- `REQUIRED` → label `Lý do`, required;
- `PROHIBITED` → no note allowed.

For `PROHIBITED`, never silently delete an existing invalid note when purpose changes. Keep it editable until the operator clears it; once empty, disable the field and show a neutral `Không áp dụng cho mục đích này.` helper.

Required-copy target:

`Nhập lý do cho mục đích này.`

Do not weaken backend validation.

## 12. Existing frozen interaction rules retained

06D must preserve unless this spec explicitly overrides them:

- Soft Mineral palette;
- compact operational density;
- table-first workbenches;
- one dominant business action;
- quiet healthy state / exception-first when relevant;
- Review frozen-refresh semantics for workflows that retain Review/Preview;
- recovery message families;
- shared Refresh 36×36 behavior, 800 ms spin, 200 ms completion lift;
- `prefers-reduced-motion` behavior;
- primary page transition: 60 ms exit, 180 ms entry, no horizontal slide/scale/stagger;
- frontend may be stricter than backend for safety, never looser;
- disabled controls remain neutral/readable.

School Defaults is explicitly no longer a Review-based flow; therefore the generic frozen-Review rule does not apply to School Defaults after 06D.

## 13. Component-level target map

Expected shared components affected conceptually:

- `src/vnext/atlas/system.ts`
- `src/vnext/atlas/AtlasVNextProvider.tsx`
- `src/vnext/atlas/AtlasDateInput.tsx`
- `src/vnext/atlas/AtlasDesignLanguageReference.tsx`
- relevant workbench tests/stories.

Owner-review workbenches:

- `src/vnext/atlas/schools/**`
- `src/vnext/atlas/master-data/**`
- `src/vnext/atlas/recipes/**`
- `src/vnext/atlas/planning/**`

Cross-workbench command-affordance audit may touch PXK/Reconciliation/Procurement controls only to apply shared button roles; it must not change those domains' behavior.

## 14. Testing and review contract

Implementation follows TDD at each bounded slice.

Required acceptance layers:

1. focused component/model tests for each changed interaction;
2. existing dirty/UNKNOWN/stale/readback/exit safety tests remain green;
3. `ui:vnext:typegen`, `ui:vnext:check`, TypeScript and Storybook/build checks;
4. final `pnpm certify:frontend` once after convergence;
5. exact-head disposable Supabase Full Integration once after convergence to prove backend boundary unchanged;
6. browser visual review at `1366×768`, `1440×900`, `1920×1080`, `360×800`;
7. explicit PASS/FAIL against all six owner PPT findings and calendar/button requirements;
8. zero hosted business writes.

If local resource-sensitive tests time out, compare against the pre-change baseline under equivalent conditions before changing timeout budgets or unrelated source.

## 15. Delivery sequence

Implement sequentially:

```text
06D-A Shared interaction foundation
  ↓
06D-B Master Data workbenches
  ↓
06D-C Recipe safety + lock UX
  ↓
06D-D Planning/Menu/Pantry
  ↓
06D-E Cross-workbench convergence + certification
```

Recommended implementation packaging is one Draft source PR with reviewable checkpoint commits for A/B/C/D/E. Do not use parallel agents because these slices share Chakra primitives and convergence tests.

## 16. Relationship to PR #286 and production activation

PR #286 remains frozen Draft/open/unmerged throughout 06D.

After 06D is accepted and separately merged to `main`, #286 may be rebased/recreated onto the new exact `main` and re-certified. #286 must preserve its three-file entrypoint intent; any domain/workbench changes in that PR are scope drift.

06D does not create Atlas Production, change production environment authority, provision users, import master data, or merge #286.

## 17. Exit criteria

06D is Product-acceptance ready only when:

```text
Vietnamese popup calendar         PASS
Button/command affordance         PASS
School Defaults                   PASS
Ingredient/Supplier               PASS
Recipe duplicate-ADD safety       PASS
Recipe lock clarity               PASS
Weekly Menu type completeness     PASS
Pantry line ergonomics            PASS
All seven workbenches regression  PASS
Four-viewpoint visual acceptance  PASS
Full frontend certification       PASS
Exact-head Supabase integration   PASS
Backend/API/schema changes        ZERO
Hosted business writes            ZERO
```

Final state:

`UI_PRODUCT_ACCEPTANCE_READY`

That state does not authorize merging #286 or activating an Atlas Production backend.
