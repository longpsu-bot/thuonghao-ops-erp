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

The connected operator projection is one sidebar destination, `Lập nhu cầu`, with the page title `Lập nhu cầu theo tuần` and four task tabs:

```text
Thực đơn
→ Sĩ số
→ Nhu cầu bổ sung
→ Xác nhận nhu cầu
```

Need Generation remains a Planning domain and backend command boundary, but it is not a peer operator destination. Inside `Xác nhận nhu cầu`, the normal daily projection is limited to `Ngày phục vụ`, one translated `Trạng thái`, and `Việc cần làm`. A row control reviews/selects the date (or directly opens an existing current Confirmed Need); only the separate contextual `Tạo nhu cầu` / `Cập nhật nhu cầu` primary action invokes the command. The ordinary Confirmed Need table is the single operational quantity projection; source readiness/evidence, grouped theoretical Recipe/Pantry contributions, versions, and run history remain support detail.

### Weekly Menu and Attendance

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

The operator surface has exactly two stages, `Phân bổ nhà cung ứng` and `Đơn
mua`. Allocation uses one row per authoritative family, keeps raw Handoff
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
