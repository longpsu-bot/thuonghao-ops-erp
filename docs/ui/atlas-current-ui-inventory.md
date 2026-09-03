# Atlas Current UI Inventory

**Status:** Accepted ATLAS-ACT-01A inventory

**Accepted on:** 06/08/2026

**Reviewed baseline:** `f3197bb5a7b571378a41ae5056a73a84ad57d583`

**School-catering Procurement amendment:** PR-C connects the reviewed Procurement
API boundary to the Atlas shell. The original inventory remains the authority for
the earlier UI-quality program; this amendment records the newly connected surface.

**Purpose:** identify the connected surfaces that should be stabilized before CMD-03 without redefining business behavior or polishing prototypes that will change later.

## 1. Evidence basis

This inventory uses:

- current repository components and tests;
- merged Admin and Planning implementation records;
- Storybook and UI Review Export;
- retained Retool exports as workflow-density evidence only.

It is not a pixel-level audit. Each implementation slice publishes its own before/after findings and review evidence.

## 2. Shared application foundation

| Area                | Current evidence                            | Direction                                                                            |
| ------------------- | ------------------------------------------- | ------------------------------------------------------------------------------------ |
| Shell/navigation    | `src/modules/atlas/AtlasApp.tsx`            | Keep structure; standardize hierarchy, environment label and state presentation.     |
| Connection/Auth     | `src/modules/atlas/connection/`             | Preserve safety boundary; staging identity remains ATLAS-ACT-01B work.               |
| Shared components   | `src/modules/atlas/WorkbenchComponents.tsx` | Reuse and extend only where two connected surfaces share a pattern.                  |
| Styling             | `src/styles.css`                            | Add semantic tokens and bounded component sections; do not rewrite CSS architecture. |
| Storybook/UI export | repository configuration and workflow       | Use for repeatable visual review.                                                    |
| Tests               | module component tests and Vitest           | Preserve behavior; add focused accessibility and state tests where changed.          |

## 3. Connected Planning scope

### Planning Inputs shell

Primary path:

```text
src/modules/atlas/planning-inputs/PlanningInputsWorkbench.tsx
```

It composes the complete current Planning journey and is the first representative consumer of shared shell/state patterns.

The connected operator projection is one sidebar destination, `Lập nhu cầu`, with one compact dynamic page title for the active job and four calm task tabs:

```text
Thực đơn
→ Sĩ số
→ Bổ sung
→ Xác nhận nhu cầu
```

PLANNING-UX-CLOSEOUT-01 completes the pre-freeze operational pass. Menu is a
read-only source projection; Attendance and Pantry are table-first editing jobs. Preview is attached beside
the active table on wide screens and stacks below it at 900 px. The operating
rail owns the single contextual primary action. Search remains display-only so
complete-write payloads retain hidden rows. Support evidence stays collapsed as
`Nguồn & lịch sử`, and Need Generation remains embedded within the confirmed
job instead of becoming a fifth destination.

PLANNING-CONTEXT-AND-CONFIRMED-NEED-UX-REFINEMENT and its single-working-date
amendment continue Draft PR #250. Planning follows **Week → working service date
→ School scope → workflow job**. The parent owns the only working date. Its
accessible `Ngày phục vụ` control shows weekday + date with stronger border,
background and typography than Week/School. Context and workflow are separate
semantic rows; four equal jobs, Refresh and the contextual CTA form the second
row and reflow locally on narrow screens.

Menu, Attendance, Pantry and Confirmed Need consume that same date. Pantry adds
rows on the working date and filters only presentation; its full weekly draft
and preview/save payload survive date changes. Row-level date choosers are absent
in the embedded Pantry surface. Menu remains read-only and Google-governed.

Confirmed Need opens the current batch for the selected date directly. The
embedded seven-day navigator, `Chọn ngày xác nhận`, separate selected-day panel,
`Mở xác nhận` action and internal Date filter are removed. Missing/no-need,
outdated, blocked and released states retain their existing authoritative
meaning; the existing Need Generation action appears only when supported. No
empty Confirmed Need table is added to a no-need date. Search, status and
unsaved-differences filters remain. Backend preflight, calculations, lifecycle,
Save, release and pending-Handoff recovery are unchanged.

Date changes use the existing dirty confirmation. Cancelling retains quantities,
reasons and the shared date. Accepting discards the old Confirmed Need draft,
even when two dates refer to one historical batch. Late generation responses
cannot reopen a previous date. A sole batch elsewhere in the week no longer
silently changes the working date. Standalone Need Generation review stories
supply their own controlled date props; there is no local selected-date state
inside the workbench.

Confirmed quantity entry permits at most **two decimal places**. Dot and comma
input remain supported; invalid precision is preserved verbatim, explained and
blocks Save. Outgoing quantities remain exact dot-decimal strings. Persisted
`numeric(20,6)`, exact equality/BigInt arithmetic and Planning Quantity Policy
are unchanged. Trailing zeroes are removed only for input presentation:
`10.000000 → 10`, `10.500000 → 10,5`, `10.250000 → 10,25`. Historical values
with greater meaningful precision remain exact and visibly read-only, including
their adjustment controls; they are never rounded or silently rewritten.
Untouched saved historical decisions do not enter another row's Save payload.
Standalone Confirmed Need stories retain released, unknown-save,
refresh-required and pending-handoff recovery coverage.

### Weekly Menu and Attendance

WEEKLY-MENU-GOOGLE-AUTHORITY-UI (base `4b67d7af25a5b1a4acc57ad89f468b5370d655da`)
records the approved v1 product-authority clarification: **Google Sheet is the
sole Weekly Menu authoring authority. Atlas / Supabase owns the governed
synchronized operational snapshot, validation, audit and downstream consumption.**

The shared Planning rail contains only service week, service date, School scope,
four equal workflow jobs, routine Refresh and the current contextual action.
Service week displays Monday–Sunday while retaining the existing `week_start`
contract. Selecting any date resolves to that governed week.

Only `Thực đơn tuần` has a compact `Google Sheets · Nguồn chính thức` strip,
immediately below the rail and above its table/issues. Zero configured active
sources gives an explanatory disabled sync icon; one source fetches directly;
multiple active sources open a compact chooser within the Menu strip. Workbook,
file selection, the old `Nhập thực đơn` toolbar and manual Dish assignment are
absent from the operator UI. Dish names are read-only business content. Other
Planning jobs have no Google source control.

Fetch parses a local canonical candidate without committing. `Xem thay đổi`
requests backend preview/correction-impact evidence; `Lưu` invokes the existing
authoritative completion command with the complete candidate and source
signatures, then adopts authoritative readback. School/date display filters do
not truncate that payload. `Bỏ bản đồng bộ` restores persisted rows. Technical
source facts remain in `Nguồn & lịch sử`; historical source types and retained
Workbook parsers/backend contracts remain readable and unchanged.

**The physical Google Sheet layout is not the Atlas business contract.** Supported
Sheet layouts are semantic adapters into one canonical Weekly Menu contract:
School + service date + Dish Type/Menu slot + Dish. Required semantic headers
such as `Tên trường` / `Ngày`, Dish Type names/codes, `source_header_aliases`,
harmless leading-row tolerance and canonical validation remain the compatibility
boundary. Explicit template version/profile hardening is deferred; this slice
adds no template engine, profile metadata, migration or DB → Google writeback.

Retained OPS v1 behavior is workflow evidence only: a Google source is normalized
to stable rows, invalid references are surfaced, signatures distinguish unchanged
content from drift, and synchronization is explicit. Atlas retains backend
preview, signature checks and no-change command semantics; Retool client SQL and
client write architecture are not copied. The historical RMVP-03A architecture
spec remains a record of its earlier coexistence UI, not the current v1 Menu
authoring policy.

Primary paths:

```text
src/modules/atlas/planning-inputs/weekly-menu/
src/modules/atlas/planning-inputs/attendance/
```

Quality priorities:

- consistent period controls and approval evidence;
- clear draft versus approved state;
- shared loading, empty, stale and read-only treatment;
- bounded tables on narrow screens.

### Pantry

Primary path:

```text
src/modules/atlas/planning-inputs/pantry/
```

Quality priorities:

- distinguish approved zero-line evidence from empty or missing data;
- align line editing, issues and lifecycle evidence with other Planning tabs;
- improve purpose/reference presentation without changing reference authority.

### Planning Input Readiness

Primary path:

```text
src/modules/atlas/planning-inputs/readiness/
```

Quality priorities:

- exception-first blocker/warning hierarchy;
- concise source-binding summary;
- reduced competition among issues, history and actions;
- consistent disabled-action reasons.

### Need Generation

Primary path:

```text
src/modules/atlas/planning-inputs/need-generation/
```

Quality priorities:

- contextual currentness and next action inside Confirmed Need rather than a peer tab;
- clear separation of run facts, issues and materialization evidence;
- one operational row for the complete Confirmed Need identity, with Recipe/Pantry contribution detail disclosed underneath;
- shared action and confirmation presentation.

### Confirmed Need

Primary path:

```text
src/modules/atlas/planning-inputs/confirmed-needs/
```

This is the reference implementation for backend-authorized lifecycle behavior through validation, approval and release.

Quality priorities:

- reuse shared current-state, notice, action and evidence patterns;
- improve line density and row evidence detail;
- retain exact disabled reasons, late-response protection and refresh-before-retry behavior;
- certify narrow-screen use.

Planning delivery priority: **UI-QUALITY-02**.

## 3A. Connected school-catering Procurement scope

Primary path:

```text
src/modules/atlas/procurement/
```

The enabled sidebar destination is `Kế hoạch mua hàng`. It consumes the
school-catering backend path only:

```text
Planning Confirmed Need release
→ Purchase Handoff release
→ Allocation Family
→ complete supplier split
→ supplier/date Purchase Order DRAFT
→ immutable release with a backend-generated official number
```

The operator surface has exactly two modes, `Phân bổ NCC` and `Đơn mua`; its
compact active title is `Phân bổ nhà cung ứng` or `Đơn mua`. Allocation uses one
row per authoritative family, keeps raw Handoff
contributions behind disclosure, and treats recommendations and rebalance
proposals as advisory until the operator explicitly confirms a complete family
snapshot. The PO stage is read-only for supplier and quantity, materializes a
bounded date range, preserves blocked-date exceptions beside usable dates,
regenerates stale DRAFTs through the approved command, and releases one PO per
independent command.

Persistent command results own replay, retryable, stale, blocked and unknown
outcome recovery. An unknown write outcome locks further mutation until an
authoritative readback. The connected surface contains no direct table access,
official-number input, automatic write retry, or automatic redistribution after
supplier ineligibility.

PROCUREMENT-UX-CLOSEOUT-01 makes the family editor discoverable through an
explicit `Phân bổ NCC` or `Xem phân bổ` row action. The attached editor renders
only participating suppliers, adds eligible replacements explicitly, treats
quantity as the operator input, and keeps recommendations plus rebalance values
in visibly separate proposal surfaces until the operator applies and saves
them. Successful saves always reload the authoritative family snapshot before
the persisted allocation is shown again. `Đóng` dismisses the attached editor
without mutation, and `Nguồn & lịch sử` retains collapsed lineage evidence.

Each PO row exposes `Xem đơn`; the Supplier name is business content rather than
the hidden navigation target. With no selected PO, the range-level action is
`Tạo đơn mua`. A selected stale DRAFT exposes only regeneration, a selected
clean DRAFT exposes only release, and a selected released PO exposes no lifecycle
mutation. `Đóng` returns to range context.

ATLAS-OPS-UI-FREEZE-CLOSEOUT-01 compacts only the Procurement masters sharing
desktop width with an open detail. Closed and stacked tables retain their
complete scanning projection. Bulk recommendation confirmation is secondary;
the family editor emphasizes exact demand, assigned quantity and remainder.
Row actions expose selection, focus the attached heading and restore focus on
Close. PO version/numbering support stays under `Nguồn & lịch sử`, while the
official released number and actionable warnings stay visible. Planning keeps
four tasks with quieter healthy statuses and accessible state descriptions.
Planning and Procurement use the shared `RefreshButton` for routine workbar
refresh: a secondary 36 × 36 circular `ArrowClockwise` control with
`aria-label` and `title` set to `Làm mới dữ liệu`. Refresh handlers and existing
disabled conditions stay in each workbench. Stale/unknown-outcome refresh,
retry and handoff recovery actions retain explicit text.
Persisted Supplier removal is **Deferred Product/Contract clarification —
non-blocking for Planning + Procurement freeze**. It is not implemented.
The staging Purchase Handoff failure remains a separate integration blocker
for `PLANNING-PROCUREMENT-HANDOFF-RECOVERY-01` after #249.
See the [audit and dispositions](atlas-ops-ui-freeze-closeout-01.md).

For an immutable `RELEASED_TO_SUPPLIER` PO, `Xuất XLSX` is the primary output
and `Xuất PDF` is secondary. Both are generated in a focused Procurement export
module solely from the released PO read-model snapshot, including its official
number, immutable `supplier_name_snapshot`, service date, released revision,
exact line quantities and delivery-location breakdown. The default workbook is
an A4 portrait `PHIẾU ĐẶT HÀNG` with `Tổng`, `Theo trường`, and `Theo hàng`
sheets. Exactly representable governed quantities are numeric cells; unsafe
values remain exact text. Draft and stale POs expose no output action.

This school-catering path is separate from PA-05E supplier-direct wholesale.
PA-05E keeps its whole-line allocation and wholesale CMD-06 contract; it is not
adapted or replaced by this workbench.

## 4. Connected Admin scope

### Schools

Primary path:

```text
src/modules/atlas/admin/schools/
```

Quality priorities:

- consistent list/detail shell;
- clear create/edit/read-only modes;
- field validation and effective-state presentation;
- responsive list/detail behavior.

### Ingredients and Suppliers

Primary path:

```text
src/modules/atlas/admin/ingredients-suppliers/
```

Quality priorities:

- clearly separate Ingredient, Supplier and relationship information within one workbench;
- preserve dense relationship tables and stable identity fields;
- align active/inactive state, validation and confirmations.

This UI scope does not authorize supplier allocation or purchase-order behavior.

### Dishes and Recipes

Primary path:

```text
src/modules/atlas/admin/dishes-recipes/
```

Quality priorities:

- stronger hierarchy among Dish, Recipe Version, BOM, adjustment and effective result;
- consistent version/snapshot evidence;
- bounded detail and table regions;
- clear primary action for the current lifecycle state.

Admin delivery priority: **UI-QUALITY-03**.

## 5. Explicitly deferred UI scope

Warehouse, Dispatch and other unconnected prototypes are not part of the
pre-CMD-03 polish gate. The historical Procurement prototype remains excluded;
only `src/modules/atlas/procurement/` is now a connected Atlas surface.

They remain useful architecture and workflow evidence, but polishing them now would create rework before their backend contracts are connected. Their UI quality work should accompany later connected slices.

## 6. Cross-cutting strengths to preserve

- React and TypeScript module boundaries;
- backend-safe RPC shaping;
- Supabase Auth subject authority;
- no automatic write retry;
- substantial component-test coverage;
- Vietnamese task labels;
- visible exception and lifecycle concepts;
- Storybook and UI Review Export;
- late-response protection in connected flows.

The quality program consolidates these strengths rather than replacing the application structure.

## 7. Cross-cutting debt

Repeated current patterns include:

- workbench header/context/action layout;
- notices and operational states;
- current lifecycle and disabled reasons;
- confirmations;
- Actor/time/version evidence;
- issue and history lists;
- responsive table containment.

A pattern becomes shared only when at least two connected surfaces need the same semantic behavior. Large workbench files may extract presentation components or local hooks only when business behavior and API boundaries remain unchanged.

The large common stylesheet should gain semantic variables and clear component sections, not be replaced by a new styling system.

## 8. Retool comparison boundary

Retool informs:

- operational field density;
- important filters and selectors;
- exception visibility;
- explicit save/refresh actions;
- familiar Vietnamese task wording.

Retool must not be copied as:

- direct browser SQL;
- component-state business authority;
- page/component hierarchy;
- authorization design;
- visual styling.

## 9. Delivery sequence

| Slice             | Scope                                               | Proof point                                                                                 |
| ----------------- | --------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| UI-QUALITY-01     | Shell, semantic tokens and proven shared primitives | Shell plus one Planning wrapper adopt the foundation with zero business delta.              |
| UI-QUALITY-02     | Connected Planning                                  | Complete Planning journey has consistent states, actions, evidence and responsive behavior. |
| UI-QUALITY-03     | Connected Admin                                     | Schools, Ingredients/Suppliers and Dishes/Recipes use a consistent master-data pattern.     |
| Staging rehearsal | Cross-module acceptance                             | Real Auth/security and operator journey pass through Confirmed Need release.                |

## 10. Required output from each UI slice

- exact surfaces reviewed;
- before/after issue inventory;
- exact changed-path manifest;
- shared components introduced or reused;
- focused and regression tests;
- Storybook/UI Review Export result where applicable;
- review notes at 360/768/1280 pixels;
- keyboard/focus/accessibility result;
- explicit zero business migration/API/contract delta;
- deferred issues and ownership.
