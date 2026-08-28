# Planning Workbench Visual Refinement V2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Execute sequentially in one Codex agent; do not spawn parallel agents or subagents.

**Goal:** Refine the functionally accepted Planning workbench into the approved Hybrid-C enterprise operations layout: calm page frame, one slim sticky operating rail, stable primary action placement, denser Menu/Attendance/Pantry surfaces, and a table-first Confirmed Need workspace.

**Architecture:** Build on PR #236 rather than replacing its functional work. `PlanningInputsWorkbench` continues to own week/date/step/school display scope and dirty coordination. A new `PlanningOperatingRail` owns sticky presentation only. Menu/Attendance keep parent-owned command handlers. Pantry and Confirmed Need keep their write authority inside their existing child workbenches and project their current action into the rail through a React portal. No backend state, lifecycle logic, command scope, calculation, or API is moved into the rail.

**Tech Stack:** React 19.2.7, React DOM 19.2.7, TypeScript 7.0.2, Mantine 9.2.2, Phosphor Icons 2.1.10, Vitest 4.1.10, existing `atlasTheme` and `src/styles.css`; no new dependencies.

**Spec:** `docs/superpowers/specs/2026-08-28-planning-workbench-visual-refinement-v2-design.md`

## Global Constraints

- Continue on existing branch `feat/planning-compact-workbench-ux-v1` and PR #236.
- The implementation-plan commit must have parent `54034af359ff0ed1749d043bdddef6c26f6b7565` unless the branch moved only because this plan was committed. Before application-code work, fetch origin and verify `origin/main` is still compatible; if Planning changed materially, stop and report drift.
- `OPS_SYSTEM_MAP v1.0` / ARCH-002 remains authoritative.
- Atlas Staging/backend contracts are frozen for this work. Do not change `supabase/`, migrations, `atlas_api`, Edge Functions, staging packages, or deployment scripts.
- Do not change Retool, Live OPS, Procurement, Purchase Handoff domain behavior, Need Generation domain behavior, lifecycle states, authoritative calculations, or direct database access.
- Do not add dependencies or modify lockfiles.
- Automatic Pantry/Pantry Rules remains deferred.
- Preserve the existing Atlas palette, typography, sidebar/shell, `atlasTheme`, semantic colors, controls, focus behavior, and global tokens. V2 is layout/component/styling refinement, not a new design system.
- School selection remains display scope only. It must not narrow authoritative Menu, Attendance, Pantry, or Confirmed Need write payloads.
- Preserve PR #235: operational Confirmed Need detail/actions may mount only for the globally selected service date; no-demand dates cannot retain another day's editor/actions.
- Use TDD for every behavioral/structural task: focused RED, smallest implementation, focused GREEN, then commit.
- Use focused local tests during implementation. GitHub Actions owns full frontend certification.
- Keep PR #236 draft through implementation and hosted V2 review. Do not merge or mark ready until user approves the exact-head hosted result.

## File Map

**Create**

- `src/modules/atlas/planning-inputs/PlanningOperatingRail.tsx`
- `src/modules/atlas/planning-inputs/PlanningOperatingRail.test.tsx`
- `src/modules/atlas/planning-inputs/PlanningRailActionPortal.tsx`

**Modify**

- `src/modules/atlas/planning-inputs/PlanningInputsWorkbench.tsx`
- `src/modules/atlas/planning-inputs/PlanningInputsWorkbench.test.tsx`
- `src/modules/atlas/planning-inputs/PlanningWorkflowBar.tsx` only if needed for compact rail semantics/classes; do not change workflow meaning.
- `src/modules/atlas/planning-inputs/PlanningWorkflowBar.test.tsx` only for structural accessibility changes.
- `src/modules/atlas/planning-inputs/PlanningSchoolScopeControl.tsx` only for visual compaction; behavior must remain unchanged.
- `src/modules/atlas/planning-inputs/pantry/PantryWorkbench.tsx`
- `src/modules/atlas/planning-inputs/pantry/PantryWorkbench.test.tsx`
- `src/modules/atlas/planning-inputs/need-generation/NeedGenerationWorkbench.tsx`
- `src/modules/atlas/planning-inputs/need-generation/NeedGenerationWorkbench.test.tsx`
- `src/modules/atlas/planning-inputs/confirmed-needs/ConfirmedNeedReviewWorkbench.tsx`
- `src/modules/atlas/planning-inputs/confirmed-needs/ConfirmedNeedReviewWorkbench.test.tsx`
- `src/modules/atlas/planning-inputs/confirmed-needs/PlanningInputsConfirmedNeedTab.test.tsx`
- `src/modules/atlas/AtlasApp.test.tsx` only if the existing shell integration assertion needs the new rail/action structure.
- `src/styles.css`
- `docs/superpowers/specs/2026-08-28-planning-workbench-visual-refinement-v2-design.md` status line only: change to `Approved for implementation`.

---

## Task 1 — Build the sticky operating rail and action portal

**Files:**

- Create: `src/modules/atlas/planning-inputs/PlanningRailActionPortal.tsx`
- Create: `src/modules/atlas/planning-inputs/PlanningOperatingRail.tsx`
- Create: `src/modules/atlas/planning-inputs/PlanningOperatingRail.test.tsx`
- Modify: `src/modules/atlas/planning-inputs/PlanningInputsWorkbench.tsx`
- Modify: `src/modules/atlas/planning-inputs/PlanningInputsWorkbench.test.tsx`
- Modify: `src/styles.css`

### Step 1.1 — Write failing rail/portal tests

- [ ] Add `PlanningOperatingRail.test.tsx` proving:
  - one accessible region `Thanh điều hành Lập nhu cầu` contains week, service date, school control, exactly one workflow tablist, and action host;
  - active workflow behavior is delegated through the existing `PlanningWorkflowBar` callback;
  - a direct parent action renders inside `aria-label="Hành động bước hiện tại"`;
  - `PlanningRailActionPortal` can render a child-owned action into that same action host;
  - no second tablist or duplicate primary-action host is rendered.
- [ ] Extend `PlanningInputsWorkbench.test.tsx` so the page title exists outside the rail and the week/date/school/workflow controls live inside the rail.

Run:

```bash
pnpm exec vitest run \
  src/modules/atlas/planning-inputs/PlanningOperatingRail.test.tsx \
  src/modules/atlas/planning-inputs/PlanningInputsWorkbench.test.tsx
```

Expected RED: new components missing and old header/context/workflow structure does not satisfy the rail assertions.

### Step 1.2 — Implement the portal bridge

- [ ] Create `PlanningRailActionPortal.tsx` using `createPortal` from `react-dom`.
- [ ] Keep the portal as presentation plumbing only; it must not store command state or callbacks outside the child that owns them.
- [ ] Use this interface:

```tsx
import {
  createContext,
  useContext,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import { createPortal } from "react-dom";

type PlanningRailActionContextValue = {
  host: HTMLDivElement | null;
  setHost: (node: HTMLDivElement | null) => void;
};

const PlanningRailActionContext =
  createContext<PlanningRailActionContextValue | null>(null);

export function PlanningRailActionProvider({
  children,
}: {
  children: ReactNode;
}) {
  const [host, setHost] = useState<HTMLDivElement | null>(null);
  const value = useMemo(() => ({ host, setHost }), [host]);
  return (
    <PlanningRailActionContext.Provider value={value}>
      {children}
    </PlanningRailActionContext.Provider>
  );
}

export function PlanningRailActionHost({ children }: { children?: ReactNode }) {
  const value = useContext(PlanningRailActionContext);
  if (!value)
    throw new Error(
      "PlanningRailActionHost requires PlanningRailActionProvider.",
    );
  return (
    <div
      ref={value.setHost}
      className="planning-operating-actions"
      aria-label="Hành động bước hiện tại"
    >
      {children}
    </div>
  );
}

export function PlanningRailActionPortal({
  children,
}: {
  children: ReactNode;
}) {
  const value = useContext(PlanningRailActionContext);
  if (!value)
    throw new Error(
      "PlanningRailActionPortal requires PlanningRailActionProvider.",
    );
  return value.host ? createPortal(children, value.host) : null;
}
```

### Step 1.3 — Implement `PlanningOperatingRail`

- [ ] Props:

```tsx
type PlanningOperatingRailProps<T extends string> = {
  weekControl: ReactNode;
  serviceDateControl: ReactNode;
  schoolControl: ReactNode;
  workflowItems: PlanningWorkflowItem<T>[];
  activeId: T;
  onStepChange: (id: T) => void;
  secondaryActions?: ReactNode;
  actions?: ReactNode;
};
```

- [ ] Render three zones:
  - `.planning-operating-context`
  - `.planning-operating-workflow` containing `PlanningWorkflowBar`
  - `.planning-operating-action-zone` containing compact secondary actions plus `PlanningRailActionHost`
- [ ] Add `role="region" aria-label="Thanh điều hành Lập nhu cầu"`.
- [ ] Do not embed business/action eligibility logic in this component.

### Step 1.4 — Recompose the parent shell

- [ ] Wrap the Planning workbench in `PlanningRailActionProvider`.
- [ ] Keep one calm `WorkbenchHeader` above the rail with title `Lập nhu cầu theo tuần` and one concise context sentence only.
- [ ] Remove the separate permanent `planning-context-bar` + standalone workflow row composition. Week, global service date, school scope, workflow, refresh, and primary action now appear through the rail.
- [ ] Move the global `serviceDateFilter` selector into the rail and keep it authoritative for Menu/Attendance/Confirmed presentation.
- [ ] Keep `Làm mới` as a compact secondary rail control; it must continue to call the existing authoritative refresh path.
- [ ] For Menu/Attendance, pass the existing command handler as the rail's direct `actions` prop. Do not duplicate it in local toolbars.

Menu/Attendance rail action state:

- before a valid review exists: `Xem thay đổi`;
- after existing preview + correction-impact rules allow save: `Lưu`;
- any current backend/stale/busy disabling reason remains respected.

### Step 1.5 — Add minimum rail CSS

- [ ] Add scoped local variables under `.planning-inputs-workbench`:

```css
.planning-inputs-workbench {
  --planning-rail-height: 54px;
  --planning-control-height: 32px;
  --planning-row-height: 40px;
  --planning-header-row-height: 36px;
  --planning-cell-inline: 12px;
  --planning-gap: 10px;
}
```

- [ ] Make `.planning-operating-rail` sticky, surface-colored, bordered, and visually restrained.
- [ ] Default top offset `0`; when review mode renders `.atlas-review-bar`, use the existing 58 px review-bar offset rather than changing the review shell.
- [ ] Do not alter global Atlas tokens.

### Step 1.6 — Verify and commit

Run:

```bash
pnpm exec vitest run \
  src/modules/atlas/planning-inputs/PlanningOperatingRail.test.tsx \
  src/modules/atlas/planning-inputs/PlanningWorkflowBar.test.tsx \
  src/modules/atlas/planning-inputs/PlanningSchoolScopeControl.test.tsx \
  src/modules/atlas/planning-inputs/PlanningInputsWorkbench.test.tsx
```

Expected GREEN.

Commit:

```bash
git add src/modules/atlas/planning-inputs src/styles.css
git commit -m "feat: add Planning sticky operating rail"
```

---

## Task 2 — Make Menu and Attendance true dense work surfaces

**Files:**

- Modify: `src/modules/atlas/planning-inputs/PlanningInputsWorkbench.tsx`
- Modify: `src/modules/atlas/planning-inputs/PlanningInputsWorkbench.test.tsx`
- Modify: `src/styles.css`

### Step 2.1 — Write failing Menu/Attendance density and scope tests

- [ ] Require Menu to use one primary dense work surface and an internal table-scroll wrapper; no duplicate local `Xem thay đổi`/`Lưu` buttons remain.
- [ ] Require the global service-date rail control to determine visible Menu rows while preview/save still receives all authoritative `menuRows`.
- [ ] Add/extend an Attendance fixture with at least two service dates and three schools.
- [ ] Require visible Attendance rows to match both global service date and parent school scope.
- [ ] Preview Attendance after editing one visible row and assert hidden date/school rows remain in the authoritative preview payload.
- [ ] Require Attendance column labels to express the approved roster presentation:
  - `Trường`
  - `Học sinh mặc định`
  - `Học sinh thực tế`
  - `Giáo viên`
  - `Tổng suất`
- [ ] Keep stage-local workflow status regression green.

Run:

```bash
pnpm exec vitest run src/modules/atlas/planning-inputs/PlanningInputsWorkbench.test.tsx
```

Expected RED for new structure/date/column assertions.

### Step 2.2 — Recompose Menu

- [ ] Remove the local service-date selector because the global rail owns the selected service date.
- [ ] Keep source/import controls only where they materially support Menu editing.
- [ ] Keep school as the left anchor and configured dish-type/slot columns in governed order.
- [ ] Wrap the grid in one internal overflow surface; if CSS permits, make the school column sticky inside the grid.
- [ ] Keep blockers/warnings visible; keep signatures/history/technical evidence under `Chi tiết hỗ trợ`.
- [ ] Review output/correction impact remains behaviorally unchanged but visually adjacent/subordinate to the grid.

### Step 2.3 — Recompose Attendance

- [ ] Derive `visibleAttendanceRows` using **both**:
  - `schoolInPlanningScope(line.school_id, schoolScopeIds)`
  - `line.service_date === serviceDateFilter`
- [ ] Continue using complete `attendanceRows` for preview and save.
- [ ] For each visible row, find the matching default row in `data.default_attendance_preview` and render default student portions separately from editable actual student portions.
- [ ] Keep teacher portions editable/current as today and derive total from current student + teacher portions.
- [ ] Remove the redundant date column because the global rail already shows the selected service date.
- [ ] Do not add KPI cards.

### Step 2.4 — Move the primary actions fully into the rail

- [ ] Menu/Attendance local toolbars may contain import/paste/discard controls, but not duplicated review/save primary actions.
- [ ] Preserve exact existing preview/correction-impact/save guards. The rail is only a different rendering location.

### Step 2.5 — Apply dense table classes and commit

- [ ] Use shared Planning classes rather than per-screen magic values.
- [ ] Target 36–38 px headers, 38–42 px rows, 32–34 px inputs, 12–14 px horizontal cell padding.

Run:

```bash
pnpm exec vitest run \
  src/modules/atlas/planning-inputs/PlanningInputsWorkbench.test.tsx \
  src/modules/atlas/AtlasApp.test.tsx
```

Expected GREEN.

Commit:

```bash
git add src/modules/atlas/planning-inputs/PlanningInputsWorkbench.tsx \
  src/modules/atlas/planning-inputs/PlanningInputsWorkbench.test.tsx \
  src/modules/atlas/AtlasApp.test.tsx src/styles.css
git commit -m "refactor: densify Planning Menu and Attendance"
```

---

## Task 3 — Densify Pantry and project its owned action into the rail

**Files:**

- Modify: `src/modules/atlas/planning-inputs/pantry/PantryWorkbench.tsx`
- Modify: `src/modules/atlas/planning-inputs/pantry/PantryWorkbench.test.tsx`
- Modify: `src/styles.css`

### Step 3.1 — Write failing Pantry rail-action tests

- [ ] Wrap Pantry tests that exercise rail actions in `PlanningRailActionProvider` + `PlanningRailActionHost`.
- [ ] Require `Xem thay đổi` to appear in the rail host before review and `Lưu` to occupy the same slot when the existing preview/correction-impact state allows save.
- [ ] Require no duplicate Pantry review/save buttons in the local toolbar.
- [ ] Keep existing tests proving:
  - hidden rows preserve original authoritative indexes;
  - preview/save includes hidden authoritative rows;
  - scoped new-row default is correct;
  - `Xác nhận toàn tuần không có bổ sung` remains whole-week scope.

Run:

```bash
pnpm exec vitest run src/modules/atlas/planning-inputs/pantry/PantryWorkbench.test.tsx
```

Expected RED for portal/action-placement assertions.

### Step 3.2 — Portal the existing Pantry primary action

- [ ] Import `PlanningRailActionPortal`.
- [ ] Render exactly one rail primary action from Pantry's own current state:
  - `Xem thay đổi` until the existing `preview?.can_save && correctionImpact?.save_allowed` save gate is satisfied;
  - `Lưu` once that exact gate is satisfied;
  - retain existing busy/stale/catalog blockers and disabled semantics.
- [ ] Do not hoist `preview`, `correctionImpact`, `rows`, or write callbacks to the parent.
- [ ] Keep `Thêm dòng`, the whole-week zero control, and other row-entry controls in the local compact toolbar as secondary/local operations.

### Step 3.3 — Recompose Pantry as one dense exception table

- [ ] Keep columns based on current governed data: school, service date, ingredient, quantity, unit, purpose/reason, note/action where already present.
- [ ] Remove unnecessary panel nesting/vertical explanatory chrome while retaining blockers and operator notices.
- [ ] Keep parent school scope as visibility/choice filter only; full `rows` continue to drive preview/save.
- [ ] Do not filter Pantry by the global service date; Pantry remains a week-level object.
- [ ] Do not add Automatic Pantry controls or status.

### Step 3.4 — Verify and commit

Run:

```bash
pnpm exec vitest run \
  src/modules/atlas/planning-inputs/pantry/PantryWorkbench.test.tsx \
  src/modules/atlas/planning-inputs/PlanningInputsWorkbench.test.tsx
```

Expected GREEN.

Commit:

```bash
git add src/modules/atlas/planning-inputs/pantry src/styles.css
git commit -m "refactor: densify Pantry workbench actions"
```

---

## Task 4 — Turn embedded Need Generation into the compact daily navigator

**Files:**

- Modify: `src/modules/atlas/planning-inputs/need-generation/NeedGenerationWorkbench.tsx`
- Modify: `src/modules/atlas/planning-inputs/need-generation/NeedGenerationWorkbench.test.tsx`
- Modify: `src/modules/atlas/planning-inputs/confirmed-needs/PlanningInputsConfirmedNeedTab.test.tsx`
- Modify: `src/styles.css`

### Step 4.1 — Write failing embedded-navigator tests

- [ ] For `embeddedInConfirmedNeed`, require a compact region `Tổng quan nhu cầu theo ngày` with date rows, short operator state, and one small navigation/action affordance.
- [ ] Require the selected day row to expose `aria-current="date"` and restrained selected styling class.
- [ ] Require embedded mode to omit large Need Generation headings, explanatory cards, duplicate week context, and any command ceremony that belongs to the standalone Need Generation surface.
- [ ] Keep tests for no-source day wording and existing daily review/open actions.
- [ ] In the integrated Confirmed Need tab test, retain PR #235 ordering: selecting/opening a daily Need realigns the global date before actionable review detail appears.

Run:

```bash
pnpm exec vitest run \
  src/modules/atlas/planning-inputs/need-generation/NeedGenerationWorkbench.test.tsx \
  src/modules/atlas/planning-inputs/confirmed-needs/PlanningInputsConfirmedNeedTab.test.tsx
```

Expected RED for compact embedded structure assertions.

### Step 4.2 — Add an embedded presentation branch only

- [ ] Do not change preflight calls, Need Generation commands, status mapping, or `onConfirmedNeedSelected` semantics.
- [ ] Reuse existing daily helpers (`dailyOperatorStatus`, `dailyReviewAction`, existing preflight state) to render the compact navigator.
- [ ] Keep the standalone Need Generation workbench behavior intact.
- [ ] Ensure embedded mode is navigation/context, not a second authority.

### Step 4.3 — Style the navigator

- [ ] Desktop left-pane target: ~300–330 px at 1366 px and ~320–360 px at larger desktops.
- [ ] Compact row height, minimal borders, selected Atlas-blue treatment, no dashboard cards/charts.

### Step 4.4 — Verify and commit

Run:

```bash
pnpm exec vitest run \
  src/modules/atlas/planning-inputs/need-generation/NeedGenerationWorkbench.test.tsx \
  src/modules/atlas/planning-inputs/confirmed-needs/PlanningInputsConfirmedNeedTab.test.tsx
```

Expected GREEN.

Commit:

```bash
git add src/modules/atlas/planning-inputs/need-generation \
  src/modules/atlas/planning-inputs/confirmed-needs/PlanningInputsConfirmedNeedTab.test.tsx \
  src/styles.css
git commit -m "refactor: compact Confirmed Need daily navigator"
```

---

## Task 5 — Make Confirmed Need summary-light and table-first

**Files:**

- Modify: `src/modules/atlas/planning-inputs/confirmed-needs/ConfirmedNeedReviewWorkbench.tsx`
- Modify: `src/modules/atlas/planning-inputs/confirmed-needs/ConfirmedNeedReviewWorkbench.test.tsx`
- Modify: `src/modules/atlas/planning-inputs/confirmed-needs/PlanningInputsConfirmedNeedTab.test.tsx`
- Modify: `src/styles.css`

### Step 5.1 — Write failing table-first and action tests

- [ ] Require the right pane order:
  1. selected-date title/context;
  2. one slim summary strip;
  3. blockers/warnings and hidden-dirty notice only when applicable;
  4. compact filters;
  5. line-item table;
  6. collapsed support/details.
- [ ] Require the summary strip to use governed counts/state only, e.g. total, needs review, confirmed, adjusted, operator-facing status. Do **not** test invented mixed-unit quantity totals.
- [ ] Require no ingredient-group rows unless governed group metadata exists; current fixture should remain flat.
- [ ] Require the operational table to expose current governed fields compactly:
  - ingredient with discoverable school/delivery context;
  - unit;
  - calculated/theoretical quantity;
  - editable confirmed quantity;
  - difference;
  - reason/note affordance.
- [ ] Add checkbox test for `Chỉ hiển thị dòng có chênh lệch`; it filters `visibleLines` using current draft quantity vs `proposed_confirmed_quantity` only.
- [ ] Assert filtering does not alter `changedLines` or save payload.
- [ ] Require fake export UI/explanation to be absent.
- [ ] Require Save/Release actions to appear in the rail host, not local footer:
  - show `Lưu` when `changedLines.length > 0` and existing save rules govern enabled state;
  - when there are no pending changes, show `Chuyển sang lên đơn` only according to existing release eligibility;
  - preserve disabled reason/title for backend denial/stale/busy state.
- [ ] Keep hidden-dirty/full-save and PR #235 tests green.

Run:

```bash
pnpm exec vitest run \
  src/modules/atlas/planning-inputs/confirmed-needs/ConfirmedNeedReviewWorkbench.test.tsx \
  src/modules/atlas/planning-inputs/confirmed-needs/PlanningInputsConfirmedNeedTab.test.tsx
```

Expected RED.

### Step 5.2 — Remove dashboard/placeholder chrome

- [ ] Remove the large `confirmed-need-hero` treatment and any card-like KPI presentation.
- [ ] Remove `exportExplanation` and the unsupported Export action entirely. Do not implement export.
- [ ] Retain one compact selected-date title and one horizontal count/state strip.
- [ ] Do not add aggregate quantities across mixed units.

### Step 5.3 — Implement difference-only display filtering

- [ ] Add local boolean state, e.g. `showDifferencesOnly`.
- [ ] Define a pure predicate from the current draft:

```ts
const hasDraftDifference = (
  line: ConfirmedNeedLine,
  draft: ConfirmedNeedDraftLine,
) => !exactDecimalEqual(draft.exact_quantity, line.proposed_confirmed_quantity);
```

- [ ] Apply it only to `visibleLines` after school/date/status/search display filters.
- [ ] Never use this filtered list for save; save continues to map the full `changedLines`.

### Step 5.4 — Recompose the line table

- [ ] Remove the redundant operational date column when the selected global date already identifies the batch/day.
- [ ] Use `theoretical_quantity` as the calculated need column.
- [ ] Keep the editable confirmation input bound to `draft.exact_quantity` and current validation rules.
- [ ] Keep displayed difference using existing exact decimal helper against `proposed_confirmed_quantity`; do not alter domain semantics.
- [ ] Make school + delivery location discoverable via compact secondary text under ingredient (or another equally compact existing-data treatment), so multi-school rows are unambiguous without a separate school filter.
- [ ] Keep reason select/note validation behavior. Visually compress it; do not weaken required-note rules.
- [ ] Keep blockers/warnings visible and support/history visually subordinate.

### Step 5.5 — Portal Save/Release without moving authority

- [ ] Import `PlanningRailActionPortal`.
- [ ] Keep `save`, `release`, `canSave`, `canRelease`, `releaseConfirmation`, `refreshRequired`, and backend disabled reasons owned inside `ConfirmedNeedReviewWorkbench`.
- [ ] Render the current primary action into the rail. Do not duplicate local Save/Release buttons.
- [ ] Release confirmation UI remains child-owned; the rail button only opens the existing confirmation flow.

### Step 5.6 — Verify and commit

Run:

```bash
pnpm exec vitest run \
  src/modules/atlas/planning-inputs/confirmed-needs/ConfirmedNeedReviewWorkbench.test.tsx \
  src/modules/atlas/planning-inputs/confirmed-needs/PlanningInputsConfirmedNeedTab.test.tsx \
  src/modules/atlas/planning-inputs/PlanningInputsWorkbench.test.tsx
```

Expected GREEN.

Commit:

```bash
git add src/modules/atlas/planning-inputs/confirmed-needs src/styles.css
git commit -m "refactor: make Confirmed Need table-first"
```

---

## Task 6 — Consolidate Planning CSS, certify behavior, and prepare exact-head V2 review

**Files:**

- Modify: `src/styles.css`
- Modify: `docs/superpowers/specs/2026-08-28-planning-workbench-visual-refinement-v2-design.md`
- Modify any V2 test file above only for genuine integration fixes discovered by final focused certification.
- Update PR #236 body after exact-head evidence exists.

### Step 6.1 — Consolidate rather than layer more overrides

- [ ] Review existing Planning-specific CSS sections and merge obsolete V1 selectors into the V2 structure instead of appending another override block.
- [ ] Shared targets:
  - rail 52–56 px;
  - toolbar 44–48 px;
  - table header 36–38 px;
  - standard row 38–42 px;
  - controls 32–34 px;
  - 12–14 px cell horizontal padding;
  - 8–12 px internal gaps;
  - 16–20 px workbench gutter.
- [ ] Keep page header calm and non-sticky; rail sticky.
- [ ] At 1366×768: no page-level horizontal overflow, Confirmed Need remains split where practical, tables own any horizontal scrolling.
- [ ] At 1920×1080: use extra space for rows/columns, not larger controls.
- [ ] At <=900 px: rail may scroll/wrap as one controlled region, Confirmed Need stacks, tables scroll internally.
- [ ] Preserve current focus-visible and reduced-motion behavior.
- [ ] Do not change `:root`, global palette variables, sidebar, shell, typography, global radii, or global shadows.

### Step 6.2 — Update the approved spec status

- [ ] Change only the stale status line from `Approved visual direction; pending user spec sign-off` to `Approved for implementation`.
- [ ] Do not rewrite approved design content during implementation unless a real contradiction is discovered; if so, stop and report.

### Step 6.3 — Run focused V2 certification

Run exactly:

```bash
pnpm exec vitest run \
  src/modules/atlas/planning-inputs/PlanningOperatingRail.test.tsx \
  src/modules/atlas/planning-inputs/PlanningWorkflowBar.test.tsx \
  src/modules/atlas/planning-inputs/PlanningSchoolScopeControl.test.tsx \
  src/modules/atlas/planning-inputs/PlanningInputsWorkbench.test.tsx \
  src/modules/atlas/planning-inputs/pantry/PantryWorkbench.test.tsx \
  src/modules/atlas/planning-inputs/need-generation/NeedGenerationWorkbench.test.tsx \
  src/modules/atlas/planning-inputs/confirmed-needs/ConfirmedNeedReviewWorkbench.test.tsx \
  src/modules/atlas/planning-inputs/confirmed-needs/PlanningInputsConfirmedNeedTab.test.tsx \
  src/modules/atlas/AtlasApp.test.tsx

pnpm typecheck

git diff --check
```

Expected: zero test failures, typecheck exit 0, diff check clean.

- [ ] Run Prettier only on changed files, including the V2 spec and this plan.
- [ ] Do **not** run local Supabase full-integration suites for this frontend-only V2 refinement.

### Step 6.4 — Boundary audit

Run:

```bash
git diff --name-only 54034af359ff0ed1749d043bdddef6c26f6b7565...HEAD
git diff --name-only e683d775c8756da8af089164eb3793b0792dd6ee...HEAD
```

Expected V2 delta: Planning frontend/components/tests, Planning-scoped CSS, V2 spec status, and V2 plan only.

Hard fail if V2 introduces:

- `supabase/`
- `.github/`
- migrations
- Edge Functions
- deployment scripts
- Retool exports
- Procurement/Purchase Handoff implementation
- dependency manifests/lockfiles
- global Atlas theme-token redesign.

### Step 6.5 — Commit final cleanup and push

Commit only if there are final Task-6 changes:

```bash
git add src docs/superpowers
git commit -m "style: finish Planning workbench visual refinement v2"
git push origin feat/planning-compact-workbench-ux-v1
```

### Step 6.6 — GitHub Actions and PR body

- [ ] Keep PR #236 draft.
- [ ] Wait for exact-head GitHub Actions:
  - `Frontend CI / Format, typecheck, test, build`
  - existing Qodana workflow
  - existing Supabase Smoke/Integration workflow behavior
  - Cloudflare Pages preview
- [ ] Report the separate `Qodana for JS` check accurately as neutral/informational if it remains so; do not call it green.
- [ ] Update PR #236 body with:
  - V2 spec path and implementation-plan path;
  - exact V2 base/head SHAs;
  - task-by-task RED/GREEN evidence;
  - focused validation results;
  - exact-head CI status;
  - boundary audit;
  - statement that Atlas colors/theme/shell are preserved;
  - statement that primary actions moved visually but command ownership/authority did not;
  - PR #235 date-safety status;
  - Automatic Pantry still deferred;
  - hosted visual-review checklist below.

### Step 6.7 — Hosted V2 review gate — do not merge

Use the exact-head Cloudflare preview at both **1366×768** and **1920×1080**.

Verify manually:

- calm title area scrolls away;
- one slim sticky operating rail remains visible;
- week/date/school/workflow context is readable without dominating the page;
- one stable far-right primary-action location across all four steps;
- no duplicate primary actions in local workbenches;
- no page-level horizontal overflow;
- Menu shows materially more useful rows/columns above the fold;
- Attendance is compact and the selected global date visibly scopes the roster while writes remain complete;
- Pantry is a dense week-level exception table and whole-week zero wording is unambiguous;
- Confirmed Need has compact daily navigator + large table-first right pane;
- Confirmed Need has no decorative KPI cards, fake export, or inferred ingredient grouping;
- hidden dirty edits remain warned/preserved;
- no-demand date cannot retain stale detail/actions;
- current Atlas colors, typography, controls, sidebar and shell are unchanged;
- browser console has no new warnings/errors attributable to V2.

**Stop here.** Do not mark ready and do not merge until the user reviews the exact-head hosted V2 UI and explicitly approves it.

---

## Final Implementation Report Format

Return only:

1. branch and exact head SHA;
2. PR #236 URL and draft state;
3. V2 implementation base SHA;
4. changed-file summary;
5. task-by-task RED/GREEN evidence;
6. focused test/typecheck/Prettier/diff-check results;
7. GitHub Actions results/pending state;
8. boundary audit;
9. visual-system preservation audit;
10. Menu/Attendance/Pantry/Confirmed Need structural summary;
11. PR #235 regression status;
12. exact-head Cloudflare preview URL;
13. hosted review items still awaiting user approval.

Do not claim V2 is complete or ready to merge before fresh exact-head verification and hosted user acceptance.
