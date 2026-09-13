# Atlas UI vNext 06D-D Planning Sources Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove and expose complete Weekly Menu Dish Type columns and make Pantry lines visibly carry School context with aligned controls and truthful optional-note/required-reason semantics.

**Architecture:** Do not assume the PPT Menu screenshot proves a renderer bug: the current Menu component already maps active `dish_types`, while the review fixture currently contains only one active type. First strengthen fixtures/tests; change production Menu rendering only where the strengthened test exposes a real gap, chiefly sticky School identity and local horizontal scrolling. Pantry keeps the existing backend line model (`school_id` is already on `PantryDraftRow`); the UI simply exposes that authoritative fact on every row and patches it through the existing `editPantryRow` path.

**Tech Stack:** React 19.2.7, TypeScript 7.0.2, Chakra UI 3.37.0, Vitest 4.1.10, Testing Library, existing Planning/Pantry bridge APIs, pnpm 11.7.0.

**Spec:** `docs/superpowers/specs/2026-09-13-atlas-ui-vnext-06d-interaction-affordance-design.md`

## Global Constraints

- Requires reviewed 06D-A/B/C heads.
- No Weekly Menu, Attendance, Pantry, Need Generation, or downstream backend contract changes.
- Menu columns are driven only by active authoritative `dish_types`, sorted by `display_order`.
- Do not hide active Dish Types to fit width; scrolling belongs inside the workbench surface.
- Preserve existing Menu/Attendance/Pantry Preview/Review freeze and authoritative save/readback semantics.
- Pantry School change is a draft edit only until the existing save command; no new read/write API call is introduced.
- Preserve `note_rule` business semantics: `OPTIONAL` note is optional; `REQUIRED` is a required **reason**; `PROHIBITED` rejects note content. Improve labels/copy without weakening validation.
- Never silently delete a prohibited note when purpose changes; the operator must clear the value explicitly.
- PR #286 remains untouched.

---

### Task 1: Prove all active Dish Types render before changing Menu logic

**Files:**
- Modify: `src/vnext/atlas/planning/planningReviewFixtures.ts`
- Modify: `src/vnext/atlas/planning/PlanningSourcesWorkbench.test.tsx`
- Modify: `src/vnext/atlas/planning/PlanningMenuStage.tsx` only if the strengthened test exposes a real rendering/layout gap.

**Interfaces:**
- Consumes: existing `snapshot.dish_types`, `snapshot.dishes`, Menu draft rows.
- Produces: deterministic review fixture with at least five active Dish Types plus one inactive type.

- [ ] **Step 1: Expand the Planning fixture, not the production renderer**

In `planningReviewFixtures.ts`, replace the one-type fixture with a representative catalogue:

```ts
dish_types: [
  { dish_type_id: "type-main", dish_type_code: "main", dish_type_name: "Món mặn", display_order: 1, dish_type_status: "ACTIVE" },
  { dish_type_id: "type-soup", dish_type_code: "soup", dish_type_name: "Món canh", display_order: 2, dish_type_status: "ACTIVE" },
  { dish_type_id: "type-stir", dish_type_code: "stir_fry", dish_type_name: "Món xào", display_order: 3, dish_type_status: "ACTIVE" },
  { dish_type_id: "type-veg", dish_type_code: "vegetable", dish_type_name: "Rau", display_order: 4, dish_type_status: "ACTIVE" },
  { dish_type_id: "type-dessert", dish_type_code: "dessert", dish_type_name: "Tráng miệng", display_order: 5, dish_type_status: "ACTIVE" },
  { dish_type_id: "type-old", dish_type_code: "old", dish_type_name: "Loại cũ", display_order: 99, dish_type_status: "INACTIVE" },
],
```

Add minimal Dish references needed for realistic selectors. Do not create fake Menu assignments for every type; at least one active type must deliberately remain empty.

- [ ] **Step 2: Add the completeness regression**

In `PlanningSourcesWorkbench.test.tsx`, render the Menu job and assert the headers in order:

```tsx
expect(within(table).getAllByRole("columnheader").map((x) => x.textContent)).toEqual([
  "Trường",
  "Món mặn",
  "Món canh",
  "Món xào",
  "Rau",
  "Tráng miệng",
]);
expect(within(table).queryByText("Loại cũ")).not.toBeInTheDocument();
```

Assert an unassigned active type has an explicit `—` state or empty selector placeholder that is visibly distinct from a missing column.

- [ ] **Step 3: Run the test before touching `PlanningMenuStage.tsx`**

```bash
pnpm exec vitest run src/vnext/atlas/planning/PlanningSourcesWorkbench.test.tsx
```

Expected possibilities:
- PASS for all type columns: record that the PPT omission was fixture/review-evidence incompleteness; do not rewrite the mapping logic.
- FAIL because a real active column is omitted or ordered incorrectly: fix only the demonstrated defect.

- [ ] **Step 4: If needed, preserve the existing authoritative mapping shape**

The production logic should remain conceptually:

```ts
const types = (c.data?.dish_types ?? [])
  .filter((type) => type.dish_type_status === "ACTIVE")
  .sort((a, b) => a.display_order - b.display_order);
```

Do not replace it with a hard-coded Vietnamese column list.

- [ ] **Step 5: Commit fixture/test evidence separately**

```bash
git add src/vnext/atlas/planning/planningReviewFixtures.ts src/vnext/atlas/planning/PlanningSourcesWorkbench.test.tsx src/vnext/atlas/planning/PlanningMenuStage.tsx
git commit -m "test(atlas): cover complete weekly menu dish types"
```

If production Menu code did not need a change, keep the commit test/fixture-only and state that explicitly in the commit body.

---

### Task 2: Keep School identity visible while Menu Dish Type columns scroll

**Files:**
- Modify: `src/vnext/atlas/planning/PlanningMenuStage.tsx`
- Modify: `src/vnext/atlas/planning/PlanningSourcesWorkbench.test.tsx`
- Modify: `src/vnext/atlas/planning/PlanningSourcesWorkbench.stories.tsx` only if existing stories do not show the expanded type fixture.

**Interfaces:**
- Consumes: Task 1 active type list.
- Produces: local horizontal scrolling with sticky first School column.

- [ ] **Step 1: Add structural assertions**

Give the Menu working surface stable markers and assert:

```tsx
expect(screen.getByTestId("weekly-menu-scroll")).toHaveAttribute(
  "data-horizontal-scroll",
  "local",
);
expect(within(table).getByRole("columnheader", { name: "Trường" }))
  .toHaveAttribute("data-sticky-column", "school");
```

- [ ] **Step 2: Run and confirm red**

```bash
pnpm exec vitest run src/vnext/atlas/planning/PlanningSourcesWorkbench.test.tsx
```

Expected: FAIL on the new structural contract.

- [ ] **Step 3: Implement local scroll + sticky School column**

Use the existing workbench `Box overflow="auto"`; add a `data-testid` and a table `minW` based on content rather than viewport hiding. For School header/cells:

```tsx
<Table.ColumnHeader
  data-sticky-column="school"
  position="sticky"
  left="0"
  zIndex="2"
  bg="bg.toolbar"
>
  Trường
</Table.ColumnHeader>
```

School body cells use `position="sticky"`, `left="0"`, `zIndex="1"`, and `bg="bg.workbench"`; selected/dirty row background must still win when applicable.

- [ ] **Step 4: Run test and browser-check narrow width**

```bash
pnpm exec vitest run src/vnext/atlas/planning/PlanningSourcesWorkbench.test.tsx
pnpm typecheck
```

At 360×800, verify scroll stays inside the Menu surface and the document itself does not gain horizontal overflow.

- [ ] **Step 5: Commit**

```bash
git add src/vnext/atlas/planning/PlanningMenuStage.tsx src/vnext/atlas/planning/PlanningSourcesWorkbench.test.tsx src/vnext/atlas/planning/PlanningSourcesWorkbench.stories.tsx
git commit -m "feat(atlas): keep school context visible in weekly menu"
```

---

### Task 3: Put authoritative School/location context on every Pantry line

**Files:**
- Modify: `src/vnext/atlas/planning/PlanningSourcesWorkbench.test.tsx`
- Modify: `src/vnext/atlas/planning/PlanningPantryStage.tsx`
- Modify: `src/vnext/atlas/planning/usePlanningSources.ts` only if a display helper is needed; do not change backend payload shape.

**Interfaces:**
- Consumes: `PantryDraftRow.school_id`, `c.schools`, `c.editPantryRow(index, patch)` and existing derived delivery-location data.
- Produces: row-level School selector labelled `Trường dòng N`; location helper derived from the selected School.

- [ ] **Step 1: Add a failing row-School test**

For the first Pantry line:

```tsx
const school = await screen.findByRole("combobox", { name: "Trường dòng 1" });
expect(school).toHaveValue("school-a");
expect(screen.getByText("Bếp Bình Mỹ")).toBeVisible();
```

Change to another active School and assert the draft row moves to that School context without a backend read/write:

```tsx
fireEvent.change(school, { target: { value: "school-b" } });
expect(pantryApi.getWorkbench).toHaveBeenCalledTimes(initialReadCount);
expect(pantryApi.saveCompleted).not.toHaveBeenCalled();
```

Then open Preview and assert the preview request contains the changed `school_id` using the existing line payload shape.

- [ ] **Step 2: Add per-School mode continuity coverage**

When changing a row from School A to School B, assert the displayed/derived Pantry mode follows B's existing school/date mode fact; do not copy A's mode into B.

- [ ] **Step 3: Run and confirm red**

```bash
pnpm exec vitest run src/vnext/atlas/planning/PlanningSourcesWorkbench.test.tsx
```

Expected: FAIL because Pantry currently exposes School only through grouping/context, not a line selector.

- [ ] **Step 4: Add the School column to the existing Pantry table**

The first columns become:

```text
Trường / điểm giao
Nguyên liệu / đơn vị
Mục đích
Số lượng
Ghi chú / Lý do
Tham chiếu
Thao tác
```

Render:

```tsx
<NativeSelect.Root>
  <NativeSelect.Field
    aria-label={`Trường dòng ${rowIndex + 1}`}
    value={row.school_id}
    onChange={(event) =>
      c.editPantryRow(rowIndex, { school_id: event.target.value })
    }
  >
    {c.schools
      .filter((school) => school.school_status === "ACTIVE")
      .map((school) => (
        <option key={school.school_id} value={school.school_id}>
          {school.school_name}
        </option>
      ))}
  </NativeSelect.Field>
  <NativeSelect.Indicator />
</NativeSelect.Root>
<Text textStyle="helper" color="fg.muted">
  {selectedSchool?.delivery_location_name}
</Text>
```

Keep the existing School grouping header/mode selector if it is still the clearest place for the per-School/date mode. A changed row naturally moves group on rerender; do not duplicate the mode selector on every line.

- [ ] **Step 5: Run and commit**

```bash
pnpm exec vitest run src/vnext/atlas/planning/PlanningSourcesWorkbench.test.tsx
pnpm typecheck
git add src/vnext/atlas/planning/PlanningPantryStage.tsx src/vnext/atlas/planning/PlanningSourcesWorkbench.test.tsx src/vnext/atlas/planning/usePlanningSources.ts
git commit -m "feat(atlas): show school context on pantry lines"
```

---

### Task 4: Distinguish optional notes from required reasons and stabilize Pantry row alignment

**Files:**
- Modify: `src/vnext/atlas/planning/usePlanningSources.ts`
- Modify: `src/vnext/atlas/planning/PlanningPantryStage.tsx`
- Modify: `src/vnext/atlas/planning/PlanningSourcesWorkbench.test.tsx`

**Interfaces:**
- Consumes: purpose `note_rule: "OPTIONAL" | "REQUIRED" | "PROHIBITED"`.
- Produces truthful label/error copy while preserving the exact validation rule.

- [ ] **Step 1: Replace the current note-rule expectations with business-language tests**

Add/adjust the parameterized tests:

```tsx
// OPTIONAL
expect(screen.getByLabelText("Ghi chú dòng 1")).not.toBeRequired();
expect(screen.queryByText(/Nhập lý do/)).not.toBeInTheDocument();

// REQUIRED
expect(screen.getByLabelText("Lý do dòng 1")).toBeRequired();
expect(screen.getByText("Nhập lý do cho mục đích này.")).toBeVisible();

// PROHIBITED with empty note
expect(screen.getByLabelText("Ghi chú dòng 1")).toBeDisabled();
expect(screen.getByText("Không áp dụng cho mục đích này.")).toBeVisible();
```

Add a prohibited-with-existing-note case: the input must remain enabled until the operator clears the invalid value; the UI must not clear it automatically.

- [ ] **Step 2: Run and confirm red**

```bash
pnpm exec vitest run src/vnext/atlas/planning/PlanningSourcesWorkbench.test.tsx
```

Expected: FAIL on old `Cần ghi chú...` copy and current row layout.

- [ ] **Step 3: Keep validation semantics but rename the REQUIRED error**

In `usePlanningSources.ts`, preserve the existing conditions and change only operator copy:

```ts
if (purpose.note_rule === "REQUIRED" && !row.note.trim())
  errors.note = "Nhập lý do cho mục đích này.";
if (purpose.note_rule === "PROHIBITED" && row.note.trim())
  errors.note = "Mục đích này không cho phép ghi chú.";
```

Do not weaken `PROHIBITED` or `REQUIRED` validation.

- [ ] **Step 4: Render dynamic field semantics without silent data loss**

Compute:

```ts
const noteRequired = purpose?.note_rule === "REQUIRED";
const noteProhibited = purpose?.note_rule === "PROHIBITED";
const hasExistingNote = Boolean(row.note.trim());
const noteDisabled = noteProhibited && !hasExistingNote;
```

Render the label as `Lý do` for REQUIRED, otherwise `Ghi chú`. If PROHIBITED has an existing value, leave it editable so the operator can clear it; once empty, disable it and show `Không áp dụng cho mục đích này.`.

- [ ] **Step 5: Reserve help/error geometry per cell**

Wrap each editable control in a `Field.Root` or equivalent stable vertical stack with a reserved helper/error line:

```tsx
<Box minH="var(--atlas-layout-pantry-feedback, 18px)">
  {error ? (
    <Text textStyle="helper" color="status.danger">{error}</Text>
  ) : helper ? (
    <Text textStyle="helper" color="fg.muted">{helper}</Text>
  ) : null}
</Box>
```

Use one row grid/table alignment; a quantity error must not vertically shift the School or Purpose control in the same row.

- [ ] **Step 6: Surface `Bỏ` as a real low-emphasis command**

Change the textual remove action from `utility` to `tertiary` unless it is represented as an icon-only control with an accessible label.

- [ ] **Step 7: Run and commit**

```bash
pnpm exec vitest run src/vnext/atlas/planning/PlanningSourcesWorkbench.test.tsx
pnpm typecheck
git add src/vnext/atlas/planning/usePlanningSources.ts src/vnext/atlas/planning/PlanningPantryStage.tsx src/vnext/atlas/planning/PlanningSourcesWorkbench.test.tsx
git commit -m "feat(atlas): clarify pantry line editing semantics"
```

---

### Task 5: Planning slice certification

**Files:**
- No product additions unless a regression is proven.

- [ ] **Step 1: Run Planning VNext and Review-safety suites**

```bash
pnpm exec vitest run src/vnext/atlas/planning src/vnext/atlas/AtlasConvergence.test.tsx src/vnext/atlas/AtlasModuleExit.test.tsx
```

Expected: PASS, including frozen Preview/Review refresh behavior.

- [ ] **Step 2: Run structural/build checks**

```bash
pnpm ui:vnext:typegen
pnpm ui:vnext:check
pnpm typecheck
pnpm build-storybook
git diff --check
```

Expected: PASS.

- [ ] **Step 3: Browser-review the two Planning PPT findings**

At 1366×768, 1440×900, 1920×1080 and 360×800 verify:

```text
Menu: all active Dish Type columns visible/scrollable; inactive type absent; School remains visible
Pantry: School/location visible per line; line controls align; REQUIRED shows Lý do; OPTIONAL shows Ghi chú; PROHIBITED never silently clears text
No document-wide horizontal overflow
No console errors
```

## 06D-D Exit Gate

```text
Menu type completeness         PASS
Sticky/local Menu scrolling    PASS
Pantry School-per-line         PASS
Pantry note/reason semantics   PASS
Planning Review safety         PASS
Backend/API/schema changes     ZERO
```
