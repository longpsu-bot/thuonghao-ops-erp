# Atlas UI vNext 06D-B Master Data Workbenches Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the owner-approved School Defaults and Ingredient/Supplier workbench refinements while preserving existing master-data commands, authoritative readback, dirty guards, and backend contracts.

**Architecture:** School Defaults becomes a direct bulk-edit surface: drafts are validated locally, `Lưu thay đổi` freezes the current valid delta and calls the existing bulk save/readback path without an intermediate Review panel. Ingredient/Supplier remains one capability with two peer catalogues; opening create/edit keeps the catalogue visible in a stable desktop 62/38 split and animates only the attached detail content using 06D-A's shared `detailEnter` style.

**Tech Stack:** React 19.2.7, TypeScript 7.0.2, Chakra UI 3.37.0, Vitest 4.1.10, Testing Library, Storybook 10.5, pnpm 11.7.0.

**Spec:** `docs/superpowers/specs/2026-09-13-atlas-ui-vnext-06d-interaction-affordance-design.md`

## Global Constraints

- Requires 06D-A shared interaction foundation: 8px controls, `tertiary`, `detailEnter`, popup-enabled `AtlasDateInput`.
- No Supabase schema/migration/RLS/RPC/API changes and no hosted writes.
- Keep School `display_order` and `school_status` from the existing authorized read; never display UUIDs as sequence numbers.
- School save must keep the existing bulk-save command, optimistic-currentness checks, UNKNOWN/readback lock, and authoritative reread.
- School normal Refresh continues preserving local drafts; only the obsolete School Review surface is removed.
- Ingredient/Supplier creation and update commands remain unchanged; statuses and supplier priorities remain authoritative backend facts.
- Desktop master/detail is 62/38 when detail is open; no grid-width animation. Narrow view stacks.
- Use surfaced command variants from 06D-A; keep `utility` only where behavior is truly navigation/icon-like.
- Start from the 06D-A reviewed head, not from Draft PR #286.

---

### Task 1: Replace School Defaults Review with truthful direct save

**Files:**
- Modify: `src/vnext/atlas/schools/SchoolDefaultsWorkbench.test.tsx`
- Modify: `src/vnext/atlas/schools/useSchoolDefaultsWorkbench.ts`
- Modify: `src/vnext/atlas/schools/SchoolDefaultsWorkbench.tsx`
- Modify: `src/vnext/atlas/AtlasConvergence.test.tsx`

**Interfaces:**
- Consumes: existing `createSchoolDefaultsReview(schools, drafts)`, `api.bulkUpdateSchoolDefaults(...)`, existing readback/recovery helpers.
- Produces: `save(): Promise<void>` callable directly from dirty edit state; no public `review/openReview/closeReview` state on the School controller.

- [ ] **Step 1: Rewrite the School happy-path test before implementation**

Replace the test that opens `Xem thay đổi` with a direct-save scenario:

```tsx
const input = await screen.findByRole("textbox", {
  name: "Học sinh mặc định — Trường Mầm non Ánh Dương",
});
fireEvent.change(input, { target: { value: "123" } });

expect(screen.queryByText("Thay đổi sĩ số mặc định")).not.toBeInTheDocument();
fireEvent.click(screen.getByRole("button", { name: "Lưu thay đổi" }));

await waitFor(() => expect(api.bulkUpdateSchoolDefaults).toHaveBeenCalledTimes(1));
await waitFor(() => expect(api.getSchools).toHaveBeenCalledTimes(2));
expect(screen.getByText(/Đã lưu/i)).toBeVisible();
```

Assert the command payload still includes the exact prior authoritative `expected_version` and the edited student/teacher values.

- [ ] **Step 2: Add direct-save safety tests**

Cover these cases in the same test file:

```text
invalid blank/non-integer draft → Lưu thay đổi disabled, zero writes
explicit 0 → valid and included in payload
hidden dirty row after filtering → still included in the frozen save delta
refresh with dirty draft → read occurs and draft remains
UNKNOWN/readback lock → duplicate save blocked; Tải lại để xác nhận remains available
stale response → no optimistic success; current data recovery remains available
```

- [ ] **Step 3: Update the 06B convergence assertion**

In `AtlasConvergence.test.tsx`, replace the School-specific frozen-Review tests with direct-save safety:

```tsx
expect(screen.queryByRole("complementary", {
  name: "Thay đổi sĩ số mặc định",
})).not.toBeInTheDocument();
expect(button("Làm mới dữ liệu")).toBeEnabled();
expect(button("Lưu thay đổi")).toBeEnabled();
```

Keep the Menu/Attendance/Pantry Review-refresh tests untouched.

- [ ] **Step 4: Run the School tests and confirm red**

```bash
pnpm exec vitest run src/vnext/atlas/schools/SchoolDefaultsWorkbench.test.tsx src/vnext/atlas/AtlasConvergence.test.tsx
```

Expected: FAIL because the current workbench still exposes `Xem thay đổi` and requires `review` before `save()`.

- [ ] **Step 5: Collapse the controller to a direct save path**

In `useSchoolDefaultsWorkbench.ts`, remove `review`, `openReview`, and `closeReview`. At the beginning of `save()`, freeze the current valid delta synchronously before the first `await`:

```ts
const changes = createSchoolDefaultsReview(load.schools, drafts);
if (!changes.length || invalidDraftCount > 0 || saving || lock) return;

const payload = changes.map((row) => ({
  school_id: row.school_id,
  expected_version: row.expected_version,
  default_student_portions: row.new_student_portions,
  default_teacher_portions: row.new_teacher_portions,
}));
```

Then run the existing authoritative bulk save and readback logic with `payload`. Preserve existing UNKNOWN/stale/readback classifications verbatim.

- [ ] **Step 6: Remove the Review UI and wire the direct command**

In `SchoolDefaultsWorkbench.tsx`:

```tsx
<Button
  variant="businessPrimary"
  disabled={
    c.loading || c.saving || Boolean(c.lock) || c.dirtyCount === 0 ||
    c.invalidDraftCount > 0
  }
  loading={c.saving}
  onClick={() => void c.save()}
>
  Lưu thay đổi
</Button>
```

Delete Review focus refs, Review panel, Review-only editing disablement, and the redundant explanatory sentence under the h1. Keep ordinary Refresh enabled with valid dirty drafts.

- [ ] **Step 7: Run the focused tests**

```bash
pnpm exec vitest run src/vnext/atlas/schools/SchoolDefaultsWorkbench.test.tsx src/vnext/atlas/AtlasConvergence.test.tsx
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add src/vnext/atlas/schools/SchoolDefaultsWorkbench.tsx src/vnext/atlas/schools/useSchoolDefaultsWorkbench.ts src/vnext/atlas/schools/SchoolDefaultsWorkbench.test.tsx src/vnext/atlas/AtlasConvergence.test.tsx
git commit -m "feat(atlas): simplify school defaults save flow"
```

---

### Task 2: Make School identity, display order, and lifecycle explicit

**Files:**
- Modify: `src/vnext/atlas/schools/SchoolDefaultsWorkbench.test.tsx`
- Modify: `src/vnext/atlas/schools/SchoolDefaultsWorkbench.tsx`
- Modify: `src/vnext/atlas/schools/SchoolDefaultsWorkbench.stories.tsx` only if the existing fixture does not visibly include an inactive School.

**Interfaces:**
- Consumes: `SchoolMasterData.display_order`, `SchoolMasterData.school_status`, `school_type_name`.
- Produces: table columns `#`, `Trường`, `Loại trường`, `Trạng thái`, `Điểm giao`, `Học sinh mặc định`, `Giáo viên mặc định`.

- [ ] **Step 1: Add the failing table-identity test**

Assert the column headers and row values:

```tsx
expect(within(table).getAllByRole("columnheader").map((x) => x.textContent)).toEqual([
  "#",
  "Trường",
  "Loại trường",
  "Trạng thái",
  "Điểm giao",
  "Học sinh mặc định",
  "Giáo viên mặc định",
]);
expect(within(table).getByText("Đang hoạt động")).toBeVisible();
expect(within(table).getByText("Ngừng hoạt động")).toBeVisible();
```

For a known fixture row, assert the `#` cell equals `String(school.display_order)` rather than its filtered row index.

- [ ] **Step 2: Run the test and confirm red**

```bash
pnpm exec vitest run src/vnext/atlas/schools/SchoolDefaultsWorkbench.test.tsx
```

Expected: FAIL because current status is hidden in helper text and there is no `#` column.

- [ ] **Step 3: Render explicit cells**

Add the columns directly from authoritative fields:

```tsx
<Table.Cell fontVariantNumeric="tabular-nums">
  {school.display_order}
</Table.Cell>
<Table.Cell>
  <Badge variant={school.school_status === "ACTIVE" ? "success" : "neutral"}>
    {school.school_status === "ACTIVE" ? "Đang hoạt động" : "Ngừng hoạt động"}
  </Badge>
</Table.Cell>
```

Remove the appended `· Ngừng hoạt động` helper suffix so lifecycle has one unambiguous location.

- [ ] **Step 4: Verify filtering does not renumber rows**

Filter to a school whose `display_order` is not 1 and assert its visible `#` remains the authoritative order value.

- [ ] **Step 5: Run and commit**

```bash
pnpm exec vitest run src/vnext/atlas/schools/SchoolDefaultsWorkbench.test.tsx
pnpm typecheck
git add src/vnext/atlas/schools/SchoolDefaultsWorkbench.tsx src/vnext/atlas/schools/SchoolDefaultsWorkbench.test.tsx src/vnext/atlas/schools/SchoolDefaultsWorkbench.stories.tsx
git commit -m "feat(atlas): expose school status and display order"
```

---

### Task 3: Stabilize Ingredient/Supplier attached master-detail geometry

**Files:**
- Modify: `src/vnext/atlas/master-data/IngredientSupplierWorkbench.test.tsx`
- Modify: `src/vnext/atlas/master-data/IngredientSupplierWorkbench.tsx`
- Modify: `src/vnext/atlas/master-data/IngredientCatalogue.tsx`
- Modify: `src/vnext/atlas/master-data/SupplierCatalogue.tsx`
- Modify: `src/vnext/atlas/master-data/IngredientDetail.tsx`
- Modify: `src/vnext/atlas/master-data/SupplierDetail.tsx`
- Modify: `src/vnext/atlas/master-data/IngredientPriorityEditor.tsx` only for surfaced close/action affordance when it shares this detail grammar.

**Interfaces:**
- Consumes: shared `animationStyle="detailEnter"`, `tertiary` button variant.
- Produces: stationary workbench with desktop `62fr / 38fr` while detail is open and stacked detail below desktop.

- [ ] **Step 1: Add failing geometry and selection tests**

In `IngredientSupplierWorkbench.test.tsx`, select `Rau muống` and assert:

```tsx
const split = screen.getByTestId("ingredient-supplier-master-detail");
expect(split).toHaveAttribute("data-detail-open", "true");
expect(screen.getByText("Rau muống", { selector: "tr *" }).closest("tr"))
  .toHaveAttribute("aria-selected", "true");
expect(screen.getByRole("region", { name: /Chi tiết nguyên liệu/i })).toBeVisible();
```

Add a creation test proving `Tạo nguyên liệu` opens the same attached detail region rather than a different modal/surface.

- [ ] **Step 2: Add the no-container-animation contract**

Assert the split container does not carry the detail animation while the detail content does:

```tsx
expect(split).not.toHaveAttribute("data-detail-animation", "true");
expect(screen.getByTestId("master-detail-content")).toHaveAttribute(
  "data-detail-animation",
  "true",
);
```

- [ ] **Step 3: Run focused tests and confirm red**

```bash
pnpm exec vitest run src/vnext/atlas/master-data/IngredientSupplierWorkbench.test.tsx
```

Expected: FAIL on the new structural markers/action treatments.

- [ ] **Step 4: Make the split explicit and stationary**

Give the existing Grid a stable testable contract:

```tsx
<Grid
  data-testid="ingredient-supplier-master-detail"
  data-detail-open={detailOpen || undefined}
  templateColumns={{
    base: "minmax(0, 1fr)",
    lg: detailOpen ? "minmax(0, 62fr) minmax(320px, 38fr)" : "minmax(0, 1fr)",
  }}
>
```

Do not add `transition` or `animation` to this Grid.

Wrap only the mounted detail content:

```tsx
<Box
  key={`${tab}:${selectedId ?? "create"}`}
  data-testid="master-detail-content"
  data-detail-animation="true"
  animationStyle="detailEnter"
>
  {detail}
</Box>
```

- [ ] **Step 5: Keep selection visible and make textual commands surfaced**

Catalogue row actions such as `Xem / sửa` use `variant="tertiary"`. Detail close controls labelled `Đóng chi tiết` use `tertiary` unless icon-only. Preserve selected-row `aria-selected` and attention rail.

Do not change the create/update API calls or dirty-exit dialog behavior.

- [ ] **Step 6: Verify narrow-stack behavior through Storybook**

At 360×800, ensure the catalogue and detail stack without document-wide horizontal overflow and that the detail has an explicit close/back control. No new drawer is introduced.

- [ ] **Step 7: Run and commit**

```bash
pnpm exec vitest run src/vnext/atlas/master-data/IngredientSupplierWorkbench.test.tsx
pnpm typecheck
pnpm build-storybook
git add src/vnext/atlas/master-data/IngredientSupplierWorkbench.tsx src/vnext/atlas/master-data/IngredientSupplierWorkbench.test.tsx src/vnext/atlas/master-data/IngredientCatalogue.tsx src/vnext/atlas/master-data/SupplierCatalogue.tsx src/vnext/atlas/master-data/IngredientDetail.tsx src/vnext/atlas/master-data/SupplierDetail.tsx src/vnext/atlas/master-data/IngredientPriorityEditor.tsx
git commit -m "feat(atlas): stabilize master data detail workbench"
```

---

### Task 4: Master-data slice certification

**Files:**
- No production file additions unless a regression is proven.

**Interfaces:**
- Produces the reviewed 06D-B baseline consumed by Recipe and Planning plans.

- [ ] **Step 1: Run master-data and shared regression suites**

```bash
pnpm exec vitest run src/vnext/atlas/schools src/vnext/atlas/master-data src/vnext/atlas/AtlasConvergence.test.tsx src/vnext/atlas/AtlasModuleExit.test.tsx
```

Expected: PASS.

- [ ] **Step 2: Run VNext structural checks**

```bash
pnpm ui:vnext:typegen
pnpm ui:vnext:check
pnpm typecheck
pnpm build-storybook
git diff --check
```

Expected: PASS.

- [ ] **Step 3: Browser-review the two owner PPT states**

Review School Defaults and Ingredient/Supplier at:

```text
1366×768
1440×900
1920×1080
360×800
```

Acceptance:
- School shows `#` and explicit lifecycle for every row;
- direct `Lưu thay đổi` is visually dominant and truthful;
- no School Review panel remains;
- Ingredient/Supplier detail is attached/stable and selected master row remains visible;
- textual row/detail commands have visible button surfaces;
- no console error or document-wide horizontal overflow.

## 06D-B Exit Gate

```text
School direct-save safety       PASS
School order/status visibility  PASS
Master-detail geometry          PASS
Dirty/UNKNOWN/stale guards      PASS
Master-data tests               PASS
Backend/API/schema changes      ZERO
```
