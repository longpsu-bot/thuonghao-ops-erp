# Planning Compact Workbench UX V1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Execute sequentially in one Codex agent; do not spawn parallel agents or subagents.

**Goal:** Implement the approved Model B Planning UX: one compact workflow/status bar, persistent multi-school display scope, cleaner progressive disclosure, and a denser Confirmed Need layout without changing backend contracts or command authority.

**Architecture:** Keep `PlanningInputsWorkbench` as the parent coordinator for week, service date, active workflow step, and school display scope. Filtering is presentation-only: source workbenches retain complete authoritative rows for preview/save, Pantry retains its week-level batch semantics, and Confirmed Need save continues to use all changed lines even when some are hidden by display scope. Reuse existing preflight/read-model state for workflow labels; do not add APIs or reconstruct domain truth in React.

**Tech Stack:** React 19, TypeScript 7, Mantine 9.2.2, Vitest 4.1.10, existing Phosphor icons and `src/styles.css`; no new dependencies.

**Spec:** `docs/superpowers/specs/2026-08-28-planning-compact-workbench-ux-design.md`

## Global Constraints

- Start implementation branch `feat/planning-compact-workbench-ux-v1` from the commit containing this plan, not from an older `main` SHA.
- `OPS_SYSTEM_MAP v1.0` / `ARCH-002` remains authoritative.
- Atlas Staging/backend contracts are frozen for this task. Do not change `supabase/`, `atlas_api`, migrations, Edge Functions, or deployment scripts.
- Do not change Retool, Live OPS, Procurement, Purchase Handoff, or Need Generation domain behavior.
- Automatic Pantry/Pantry Rules remains deferred; do not add a clickable coming-soon action or fake automation state.
- School selection is a **display scope only**. It may filter rendered rows/options, but it must not truncate authoritative source save payloads, change preflight semantics, or turn a week-global command into a school-local command.
- Preserve PR #235 invariant: the operational Confirmed Need batch date must equal the globally selected service date.
- Use TDD for every behavioral task: add failing test, run it and record RED, make the smallest implementation, rerun GREEN, then commit.
- Prefer focused local tests; GitHub Actions owns full frontend certification.
- Do not run full local Supabase/backend suites for this frontend-only work.

---

## Task 1 — Add school display-scope primitives and align review fixtures

**Files:**

- Create: `src/modules/atlas/planning-inputs/planningSchoolScope.ts`
- Create: `src/modules/atlas/planning-inputs/PlanningSchoolScopeControl.tsx`
- Create: `src/modules/atlas/planning-inputs/PlanningSchoolScopeControl.test.tsx`
- Modify: `src/modules/atlas/planning-inputs/reviewPlanningInputsApi.ts`
- Modify: `src/modules/atlas/planning-inputs/pantry/reviewPantryApi.ts`
- Modify: `src/modules/atlas/planning-inputs/confirmed-needs/reviewConfirmedNeedApi.ts`
- Modify fixture-specific expectations in existing Pantry/Confirmed Need tests only where names/ids change.

### Step 1.1 — Write failing scope-helper/control tests

- [ ] Add tests proving:
  - empty selection means `Tất cả trường`;
  - selecting two of three schools reports `2 trường`;
  - selecting all schools normalizes back to `[]`;
  - invalid school ids are dropped when catalog changes;
  - search finds school code or Vietnamese school name;
  - `Chọn tất cả` returns to all-school display scope.

Use a three-school fixture:

```ts
const schools = [
  {
    school_id: "review-planning-school-1",
    school_code: "TH001",
    school_name: "Trường Tiểu học Nguyễn Du",
    display_order: 1,
  },
  {
    school_id: "review-planning-school-2",
    school_code: "TH002",
    school_name: "Trường Tiểu học Trần Quốc Toản",
    display_order: 2,
  },
  {
    school_id: "review-planning-school-3",
    school_code: "TH003",
    school_name: "Trường Mầm non Hoa Hồng",
    display_order: 3,
  },
];
```

Run:

```bash
pnpm exec vitest run src/modules/atlas/planning-inputs/PlanningSchoolScopeControl.test.tsx
```

Expected RED: module/control missing or assertions fail.

### Step 1.2 — Implement pure scope helpers

- [ ] Create `planningSchoolScope.ts` with exactly these semantics:

```ts
import type { PlanningSchool } from "./planningInputsModel";

export type PlanningSchoolOption = Pick<
  PlanningSchool,
  "school_id" | "school_code" | "school_name" | "display_order"
>;

export function normalizePlanningSchoolScope(
  selectedIds: string[],
  schools: PlanningSchoolOption[],
) {
  const orderedIds = schools
    .slice()
    .sort(
      (a, b) =>
        a.display_order - b.display_order ||
        a.school_name.localeCompare(b.school_name, "vi"),
    )
    .map((school) => school.school_id);
  const allowed = new Set(orderedIds);
  const valid = Array.from(new Set(selectedIds)).filter((id) =>
    allowed.has(id),
  );
  if (valid.length === 0 || valid.length === orderedIds.length) return [];
  return orderedIds.filter((id) => valid.includes(id));
}

export function schoolInPlanningScope(schoolId: string, selectedIds: string[]) {
  return selectedIds.length === 0 || selectedIds.includes(schoolId);
}

export function planningSchoolScopeLabel(
  selectedIds: string[],
  schools: PlanningSchoolOption[],
) {
  if (!selectedIds.length) return "Tất cả trường";
  if (selectedIds.length === 1)
    return (
      schools.find((school) => school.school_id === selectedIds[0])
        ?.school_name ?? "1 trường"
    );
  return `${selectedIds.length} trường`;
}
```

### Step 1.3 — Implement the searchable multi-school control

- [ ] Create `PlanningSchoolScopeControl.tsx` with props:

```ts
type PlanningSchoolScopeControlProps = {
  schools: PlanningSchoolOption[];
  selectedSchoolIds: string[];
  onChange: (ids: string[]) => void;
};
```

Use only existing Mantine primitives (`Popover`, `Button`, `Checkbox`, `TextInput`, optional `ScrollArea`). Requirements:

- button `aria-label="Phạm vi trường"`;
- button text from `planningSchoolScopeLabel`;
- searchable list sorted by `display_order`, then Vietnamese name;
- checkboxes allow arbitrary subset;
- selecting every school emits `[]`;
- `Chọn tất cả` emits `[]`;
- no new package.

### Step 1.4 — Align review-only school identities

- [ ] In `reviewPlanningInputsApi.ts`, make school 3 ACTIVE and preserve ids/names:
  - `review-planning-school-1` — Nguyễn Du
  - `review-planning-school-2` — Trần Quốc Toản
  - `review-planning-school-3` — Hoa Hồng
- [ ] In `reviewPantryApi.ts`, expose the same three school ids in the Pantry catalog. Existing Pantry line(s) may remain on school 1.
- [ ] In `reviewConfirmedNeedApi.ts`, replace review-only school ids/names with the same canonical ids. For generated `lineCount >= 3`, ensure at least one line belongs to school 3.
- [ ] Update only assertions broken by these review-fixture identity changes.

### Step 1.5 — Verify and commit

Run:

```bash
pnpm exec vitest run \
  src/modules/atlas/planning-inputs/PlanningSchoolScopeControl.test.tsx \
  src/modules/atlas/planning-inputs/pantry/PantryWorkbench.test.tsx \
  src/modules/atlas/planning-inputs/confirmed-needs/ConfirmedNeedReviewWorkbench.test.tsx
```

Expected GREEN.

Commit:

```bash
git add src/modules/atlas/planning-inputs

git commit -m "test: align Planning multi-school review fixtures"
```

---

## Task 2 — Replace plain tabs with the unified workflow/status bar and parent school scope

**Files:**

- Create: `src/modules/atlas/planning-inputs/PlanningWorkflowBar.tsx`
- Create: `src/modules/atlas/planning-inputs/PlanningWorkflowBar.test.tsx`
- Modify: `src/modules/atlas/planning-inputs/PlanningInputsWorkbench.tsx`
- Modify: `src/modules/atlas/planning-inputs/PlanningInputsWorkbench.test.tsx`
- Modify: `src/styles.css`

### Step 2.1 — Write failing workflow-bar tests

- [ ] Add tests requiring exactly four `role="tab"` items with step number, label, short status and active state.
- [ ] Add parent-workbench tests requiring:
  - one workflow/status row only;
  - `Phạm vi trường` defaults to `Tất cả trường`;
  - selecting schools 1 + 2 yields `2 trường`;
  - selected school scope persists when switching all four tabs and changing service date within the same week;
  - Menu and Attendance hide school 3 under a two-school scope;
  - hidden Menu/Attendance rows remain present in preview/save payloads.

Run:

```bash
pnpm exec vitest run \
  src/modules/atlas/planning-inputs/PlanningWorkflowBar.test.tsx \
  src/modules/atlas/planning-inputs/PlanningInputsWorkbench.test.tsx
```

Expected RED.

### Step 2.2 — Implement the pure workflow bar

- [ ] Create these types:

```ts
export type PlanningWorkflowTone = "ok" | "warning" | "danger" | "neutral";

export type PlanningWorkflowItem<T extends string = string> = {
  id: T;
  step: 1 | 2 | 3 | 4;
  label: string;
  status: string;
  tone: PlanningWorkflowTone;
};
```

Component props:

```ts
type PlanningWorkflowBarProps<T extends string> = {
  items: PlanningWorkflowItem<T>[];
  activeId: T;
  onChange: (id: T) => void;
};
```

Render a single `role="tablist"`. Each item must expose its label and status in accessible text. Active state uses `aria-selected` and a scoped class; color is supplementary.

### Step 2.3 — Add parent-owned school display scope

- [ ] In `PlanningInputsWorkbench.tsx` add:

```ts
const [schoolScopeIds, setSchoolScopeIds] = useState<string[]>([]);
```

- [ ] Derive sorted active schools from `data.schools`.
- [ ] Normalize current selection whenever the active-school catalog changes. If nothing valid remains, return to `[]`.
- [ ] Put `PlanningSchoolScopeControl` in the compact workbench header next to week/date context.
- [ ] Remove local `schoolSearch` / `attendanceSchoolSearch` as primary school filtering controls; keep unrelated search/filter behavior.
- [ ] Filter only rendered Menu/Attendance school rows using `schoolInPlanningScope`.
- [ ] Do **not** filter `menuRows`, `attendanceRows`, preview requests or save requests.

### Step 2.4 — Derive workflow statuses from existing state only

- [ ] Build four `PlanningWorkflowItem<TabId>` values in the parent. Do not add reads.

Menu/Attendance:

- dirty / derived attendance confirmation / DRAFT / VALIDATED / REOPENED → `Cần lưu` or `Chưa lưu` with warning tone;
- APPROVED / NEED_GENERATION_REQUESTED / USED_FOR_NEED_GENERATION → `Sẵn sàng` with ok tone;
- missing → `Chưa có` with neutral/warning tone.

Pantry from selected service date preflight `source_evidence.pantry`:

- selected positive evidence → `${line_count} mục`;
- explicit zero evidence → `Không bổ sung`;
- missing → `Chưa có`;
- ambiguous/stale/invalid → `Cần xử lý`.

Confirmed Need from selected service date preflight:

- blocker `NO_NEED_SOURCE_FOR_SERVICE_DATE` → `Không có nhu cầu cần lập`;
- `DRAFT_REVIEW` → `Chờ xác nhận`;
- `REOPENED` → `Cần xác nhận lại`;
- `VALIDATED` → `Đã kiểm tra`;
- `APPROVED` → `Đã xác nhận`;
- `RELEASED_FOR_PURCHASE_HANDOFF` → `Đã chuyển sang lên đơn`;
- blocked otherwise → `Cần xử lý`;
- ready + `NOT_GENERATED` → `Sẵn sàng`.

Reuse wording from the existing Need Generation UI; do not create domain lifecycle values.

### Step 2.5 — Verify and commit

Run:

```bash
pnpm exec vitest run \
  src/modules/atlas/planning-inputs/PlanningWorkflowBar.test.tsx \
  src/modules/atlas/planning-inputs/PlanningInputsWorkbench.test.tsx
```

Expected GREEN.

Commit:

```bash
git add src/modules/atlas/planning-inputs/PlanningWorkflowBar.tsx \
  src/modules/atlas/planning-inputs/PlanningWorkflowBar.test.tsx \
  src/modules/atlas/planning-inputs/PlanningInputsWorkbench.tsx \
  src/modules/atlas/planning-inputs/PlanningInputsWorkbench.test.tsx \
  src/styles.css

git commit -m "feat: add compact Planning workflow scope"
```

---

## Task 3 — Apply school display scope to Pantry without changing week-level writes

**Files:**

- Modify: `src/modules/atlas/planning-inputs/pantry/PantryWorkbench.tsx`
- Modify: `src/modules/atlas/planning-inputs/pantry/PantryWorkbench.test.tsx`
- Modify: `src/modules/atlas/planning-inputs/PlanningInputsWorkbench.tsx`

### Step 3.1 — Write failing Pantry display-scope tests

- [ ] Render a Pantry fixture with three schools and at least two rows in different schools.
- [ ] Require an external two-school scope to hide the third-school row.
- [ ] Edit a visible row and prove the original row index is updated, not a filtered-array index.
- [ ] Preview/save and assert the request still contains the hidden authoritative row.
- [ ] Add a row while school scope is explicit and assert its default school is the first school inside the current display scope.
- [ ] Require the week-global checkbox label: `Xác nhận toàn tuần không có bổ sung`.

Run:

```bash
pnpm exec vitest run src/modules/atlas/planning-inputs/pantry/PantryWorkbench.test.tsx
```

Expected RED.

### Step 3.2 — Add display-scope prop and filter only rendering

- [ ] Extend props:

```ts
schoolScopeIds?: string[];
```

Default to `[]`.

- [ ] Derive:

```ts
const scopedSchools = data.schools.filter((school) =>
  schoolInPlanningScope(school.school_id, schoolScopeIds),
);

const visibleRowEntries = rows
  .map((row, index) => ({ row, index }))
  .filter(({ row }) => schoolInPlanningScope(row.school_id, schoolScopeIds));
```

- [ ] Render `visibleRowEntries`, but call `updateRow(index, ...)` with the original index.
- [ ] Restrict per-row school options to `scopedSchools` when an explicit scope exists.
- [ ] `addRow()` defaults to first scoped school if scoped; otherwise first catalog school.
- [ ] Keep `previewRows`, correction-impact payload, and save payload on full `rows`.
- [ ] Rename checkbox copy to `Xác nhận toàn tuần không có bổ sung`; behavior stays week-global.
- [ ] Pass `schoolScopeIds` from the parent.

### Step 3.3 — Verify and commit

Run:

```bash
pnpm exec vitest run \
  src/modules/atlas/planning-inputs/pantry/PantryWorkbench.test.tsx \
  src/modules/atlas/planning-inputs/PlanningInputsWorkbench.test.tsx
```

Expected GREEN.

Commit:

```bash
git add src/modules/atlas/planning-inputs/pantry \
  src/modules/atlas/planning-inputs/PlanningInputsWorkbench.tsx

git commit -m "feat: scope Pantry display by selected schools"
```

---

## Task 4 — Apply external school scope to Confirmed Need and protect hidden dirty edits

**Files:**

- Modify: `src/modules/atlas/planning-inputs/confirmed-needs/ConfirmedNeedReviewWorkbench.tsx`
- Modify: `src/modules/atlas/planning-inputs/confirmed-needs/ConfirmedNeedReviewWorkbench.test.tsx`
- Modify: `src/modules/atlas/planning-inputs/confirmed-needs/PlanningInputsConfirmedNeedTab.test.tsx` only where the global school control replaces an internal school control expectation.
- Modify: `src/modules/atlas/planning-inputs/PlanningInputsWorkbench.tsx`

### Step 4.1 — Write failing Confirmed Need scope tests

- [ ] Require `schoolScopeIds` to filter visible lines across at least three review schools.
- [ ] Change quantities in two schools, then narrow the display scope so one dirty line is hidden.
- [ ] Require visible notice exactly:

`Có 1 thay đổi chưa lưu ngoài phạm vi trường đang hiển thị. Lưu vẫn áp dụng cho toàn bộ thay đổi hiện tại.`

- [ ] Save and assert request contains **both** changed lines, including the hidden one.
- [ ] Prove search, date, and confirmation-state filters continue to compose with external school scope.
- [ ] Keep all PR #235 date-alignment tests green.

Run:

```bash
pnpm exec vitest run \
  src/modules/atlas/planning-inputs/confirmed-needs/ConfirmedNeedReviewWorkbench.test.tsx \
  src/modules/atlas/planning-inputs/confirmed-needs/PlanningInputsConfirmedNeedTab.test.tsx
```

Expected RED.

### Step 4.2 — Replace internal school filter with external display scope

- [ ] Extend props:

```ts
schoolScopeIds?: string[];
```

Default to `[]`.

- [ ] Remove the internal single-school `schoolFilter` state and `Trường` select.
- [ ] Filter `visibleLines` with `schoolInPlanningScope(line.school.id, schoolScopeIds)` before local date/status/search filters.
- [ ] Derive context label from the available schools and `planningSchoolScopeLabel`.
- [ ] Derive:

```ts
const hiddenDirtyCount = changedLines.filter(
  (line) => !schoolInPlanningScope(line.school.id, schoolScopeIds),
).length;
```

- [ ] Show the approved warning whenever `hiddenDirtyCount > 0`.
- [ ] Keep `save()` mapped over full `changedLines`; never `visibleLines`.
- [ ] Pass `schoolScopeIds` from the parent.
- [ ] Do not alter date-selection state or batch-resolution logic from PR #235.

### Step 4.3 — Verify and commit

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
git add src/modules/atlas/planning-inputs/confirmed-needs \
  src/modules/atlas/planning-inputs/PlanningInputsWorkbench.tsx

git commit -m "feat: scope Confirmed Need display safely"
```

---

## Task 5 — Finish compact layout, progressive disclosure, and certification

**Files:**

- Modify: `src/modules/atlas/planning-inputs/PlanningInputsWorkbench.tsx`
- Modify: `src/modules/atlas/planning-inputs/PlanningInputsWorkbench.test.tsx`
- Modify: `src/modules/atlas/planning-inputs/confirmed-needs/ConfirmedNeedReviewWorkbench.tsx` only for structural/support disclosure classes if needed.
- Modify: `src/styles.css`

### Step 5.1 — Write final structural tests

- [ ] Require only one permanent workflow/status navigation row.
- [ ] Require support evidence/history to be inside collapsed `Chi tiết hỗ trợ` disclosure while blockers/actionable warnings remain visible.
- [ ] Require Confirmed Need desktop DOM to contain separate daily overview and review regions.
- [ ] Require no `Bổ sung tự động`, `Pantry Rules`, or equivalent clickable action.
- [ ] Keep existing four-tab accessibility expectations and all PR #235 date-safety tests.

Run:

```bash
pnpm exec vitest run \
  src/modules/atlas/planning-inputs/PlanningInputsWorkbench.test.tsx \
  src/modules/atlas/planning-inputs/confirmed-needs/PlanningInputsConfirmedNeedTab.test.tsx
```

Expected RED for the new structural assertions.

### Step 5.2 — Implement compact page structure

- [ ] Keep one compact header containing title, week context, multi-school control, refresh and only supported secondary actions.
- [ ] Render only `PlanningWorkflowBar` as permanent step/status navigation.
- [ ] For Menu, Attendance and Pantry, use full main width with compact toolbar/action groups.
- [ ] For Confirmed Need use:

```tsx
<div className="planning-confirmed-layout">
  <aside className="planning-confirmed-daily" aria-label="Tổng quan nhu cầu theo ngày">
    <NeedGenerationWorkbench ... embeddedInConfirmedNeed />
  </aside>
  <section className="planning-confirmed-review" aria-label="Chi tiết xác nhận nhu cầu">
    {/* aligned selected-date status + ConfirmedNeedReviewWorkbench */}
  </section>
</div>
```

The daily overview remains navigation/context, not authority.

- [ ] Move signatures/checksums, approval/change history, technical source evidence, correction-chain evidence and verbose diagnostics under existing/new `details` with summary `Chi tiết hỗ trợ` unless the evidence is an active blocker.
- [ ] Do not hide blocking errors or actionable warnings.
- [ ] Do not introduce new business actions.

### Step 5.3 — Add scoped responsive CSS

- [ ] Add/adjust scoped classes for:
  - `.planning-workflow-bar`
  - `.planning-workflow-tab`
  - `.planning-school-scope-control`
  - `.planning-compact-header`
  - `.planning-confirmed-layout`
  - `.planning-confirmed-daily`
  - `.planning-confirmed-review`
- [ ] Desktop target: useful at 1366×768 and 1920×1080.
- [ ] At `max-width: 900px`, stack the Confirmed Need split layout and allow the workflow bar to scroll horizontally or wrap in one controlled navigation region.
- [ ] Preserve existing focus-visible and reduced-motion accessibility behavior.

### Step 5.4 — Run focused certification

Run:

```bash
pnpm exec vitest run \
  src/modules/atlas/planning-inputs/PlanningSchoolScopeControl.test.tsx \
  src/modules/atlas/planning-inputs/PlanningWorkflowBar.test.tsx \
  src/modules/atlas/planning-inputs/PlanningInputsWorkbench.test.tsx \
  src/modules/atlas/planning-inputs/pantry/PantryWorkbench.test.tsx \
  src/modules/atlas/planning-inputs/confirmed-needs/ConfirmedNeedReviewWorkbench.test.tsx \
  src/modules/atlas/planning-inputs/confirmed-needs/PlanningInputsConfirmedNeedTab.test.tsx

pnpm typecheck

pnpm exec prettier --check \
  src/modules/atlas/planning-inputs/planningSchoolScope.ts \
  src/modules/atlas/planning-inputs/PlanningSchoolScopeControl.tsx \
  src/modules/atlas/planning-inputs/PlanningSchoolScopeControl.test.tsx \
  src/modules/atlas/planning-inputs/PlanningWorkflowBar.tsx \
  src/modules/atlas/planning-inputs/PlanningWorkflowBar.test.tsx \
  src/modules/atlas/planning-inputs/PlanningInputsWorkbench.tsx \
  src/modules/atlas/planning-inputs/PlanningInputsWorkbench.test.tsx \
  src/modules/atlas/planning-inputs/reviewPlanningInputsApi.ts \
  src/modules/atlas/planning-inputs/pantry/PantryWorkbench.tsx \
  src/modules/atlas/planning-inputs/pantry/PantryWorkbench.test.tsx \
  src/modules/atlas/planning-inputs/pantry/reviewPantryApi.ts \
  src/modules/atlas/planning-inputs/confirmed-needs/ConfirmedNeedReviewWorkbench.tsx \
  src/modules/atlas/planning-inputs/confirmed-needs/ConfirmedNeedReviewWorkbench.test.tsx \
  src/modules/atlas/planning-inputs/confirmed-needs/reviewConfirmedNeedApi.ts \
  src/modules/atlas/planning-inputs/confirmed-needs/PlanningInputsConfirmedNeedTab.test.tsx \
  src/styles.css \
  docs/superpowers/specs/2026-08-28-planning-compact-workbench-ux-design.md \
  docs/superpowers/plans/2026-08-28-planning-compact-workbench-ux.md

git diff --check
```

Do not run full backend/Supabase tests locally.

### Step 5.5 — Boundary audit

Run:

```bash
git diff --name-only e683d775c8756da8af089164eb3793b0792dd6ee...HEAD
```

Expected: only Planning frontend/review-fixture files, `src/styles.css`, and the approved spec/plan. The diff must contain no:

- `supabase/`
- `.github/`
- deployment scripts
- Retool exports
- Procurement/Purchase Handoff implementation files.

Also search the diff for accidental automatic-Pantry implementation terms; documentation may mention the deferral, application code must not add a clickable automation feature.

### Step 5.6 — Commit, push, and open PR

Commit final layout/certification changes:

```bash
git add src docs/superpowers

git commit -m "feat: refine Planning compact workbench UX"

git push -u origin feat/planning-compact-workbench-ux-v1
```

Open PR with title:

`Planning: simplify compact workbench and multi-school scope`

PR body must state:

- presentation/interaction-only Planning refinement;
- one unified workflow/status bar;
- multi-school selection is display-only and cannot narrow authoritative write payloads;
- PR #235 date-safety invariant preserved;
- automatic Pantry deferred;
- no backend, migration, Retool, Production, Procurement, or Need Generation behavior change;
- focused test/typecheck/format/diff results;
- GitHub Actions owns full frontend certification.

Do not merge in the implementation session.

---

## Post-PR Review Gate

Before merge:

- [ ] Review the exact-head diff for accidental command-scope changes.
- [ ] Require exact-head `Format, typecheck, test, build` success.
- [ ] Review Qodana findings only for changes introduced by this PR; do not widen scope to unrelated legacy findings.
- [ ] Use Cloudflare PR preview for staff review at 1366×768 and 1920×1080.
- [ ] Verify one-row workflow navigation, school subset persistence, Menu/Attendance/Pantry/Confirmed Need filtering, hidden-dirty notice, and PR #235 date safety.

After merge and Cloudflare production deployment, perform a final hosted Staging review. Current hosted Staging may still have only one active school; if so, use the PR review fixture/preview to prove multi-school interaction and use hosted Staging to prove the production one-school case and all accepted operational invariants.
