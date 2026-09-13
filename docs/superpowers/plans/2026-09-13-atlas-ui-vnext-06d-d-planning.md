# Atlas UI vNext 06D-D Planning Sources Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove and expose complete Weekly Menu Dish Type columns and make Pantry lines visibly carry School context with aligned controls and truthful optional-note/required-reason semantics.

**Architecture:** Do not assume the PPT Menu screenshot proves a renderer bug: current `PlanningMenuStage` already filters ACTIVE `dish_types` and sorts by `display_order`; the current review fixture contains only one active type. First strengthen fixtures/tests; change production Menu rendering only where the stronger test exposes a real gap, chiefly sticky School identity and local horizontal scrolling. Pantry already carries `school_id` on `PantryDraftRow` and has full School/default-delivery-location facts in `pantryData.schools`; expose those existing facts on each line through the existing `editPantryRow` draft path.

**Tech Stack:** React 19.2.7, TypeScript 7.0.2, Chakra UI 3.37.0, Vitest 4.1.10, Testing Library, existing Planning/Pantry APIs/models, pnpm 11.7.0.

**Spec:** `docs/superpowers/specs/2026-09-13-atlas-ui-vnext-06d-interaction-affordance-design.md`

## Global Constraints

- Requires reviewed 06D-A/B/C heads.
- No Weekly Menu, Attendance, Pantry, Need Generation, or downstream backend contract changes.
- Menu columns are driven only by active authoritative `dish_types`, sorted by `display_order`.
- Do not hide active Dish Types to fit width; scrolling belongs inside the workbench surface.
- Preserve existing Menu/Attendance/Pantry Preview/Review freeze and authoritative save/readback semantics.
- Pantry School change is a draft edit only until the existing save command; no new read/write API call is introduced.
- Preserve `note_rule` business semantics: `OPTIONAL` note is optional; `REQUIRED` is a required **reason**; `PROHIBITED` rejects note content. Improve labels/copy without weakening validation.
- Never silently delete a prohibited note when purpose changes; the operator must clear the invalid value explicitly.
- PR #286 remains untouched.

---

### Task 1: Prove all active Dish Types render before changing Menu logic

**Files:**
- Modify: `src/vnext/atlas/planning/planningReviewFixtures.ts`
- Modify: `src/vnext/atlas/planning/PlanningSourcesWorkbench.test.tsx`
- Modify: `src/vnext/atlas/planning/PlanningMenuStage.tsx` only if the strengthened test proves a real renderer defect.

**Interfaces:**
- Consumes: `PlanningInputsWorkbenchData.dish_types`, `.dishes`, existing Menu draft rows.
- Produces: deterministic review fixture with five active Dish Types plus one inactive type.

- [ ] **Step 1: Expand the Planning fixture, not the production renderer**

Use complete `PlanningDishType` rows; every fixture row includes `source_header_aliases` and `version` because those are required by the current model:

```ts
dish_types: [
  {
    dish_type_id: "type-main",
    dish_type_code: "main",
    dish_type_name: "Món mặn",
    source_header_aliases: ["Món mặn"],
    display_order: 1,
    dish_type_status: "ACTIVE",
    version: 1,
  },
  {
    dish_type_id: "type-soup",
    dish_type_code: "soup",
    dish_type_name: "Món canh",
    source_header_aliases: ["Món canh"],
    display_order: 2,
    dish_type_status: "ACTIVE",
    version: 1,
  },
  {
    dish_type_id: "type-stir",
    dish_type_code: "stir_fry",
    dish_type_name: "Món xào",
    source_header_aliases: ["Món xào"],
    display_order: 3,
    dish_type_status: "ACTIVE",
    version: 1,
  },
  {
    dish_type_id: "type-veg",
    dish_type_code: "vegetable",
    dish_type_name: "Rau",
    source_header_aliases: ["Rau"],
    display_order: 4,
    dish_type_status: "ACTIVE",
    version: 1,
  },
  {
    dish_type_id: "type-dessert",
    dish_type_code: "dessert",
    dish_type_name: "Tráng miệng",
    source_header_aliases: ["Tráng miệng"],
    display_order: 5,
    dish_type_status: "ACTIVE",
    version: 1,
  },
  {
    dish_type_id: "type-old",
    dish_type_code: "old",
    dish_type_name: "Loại cũ",
    source_header_aliases: [],
    display_order: 99,
    dish_type_status: "INACTIVE",
    version: 1,
  },
],
```

Add minimal Dish references needed for realistic selectors. Do not create Menu assignments for every active type; at least one active type deliberately stays unassigned so the empty-state cell can be tested.

- [ ] **Step 2: Add the completeness regression**

Render the Menu job and assert the existing first header plus every active Dish Type in order:

```tsx
expect(
  within(table)
    .getAllByRole("columnheader")
    .map((cell) => cell.textContent),
).toEqual([
  "Trường / điểm giao",
  "Món mặn",
  "Món canh",
  "Món xào",
  "Rau",
  "Tráng miệng",
]);
expect(within(table).queryByText("Loại cũ")).not.toBeInTheDocument();
```

Assert an unassigned active type visibly renders the existing `—` empty cell rather than disappearing as a column.

- [ ] **Step 3: Run the test before touching `PlanningMenuStage.tsx`**

```bash
pnpm exec vitest run src/vnext/atlas/planning/PlanningSourcesWorkbench.test.tsx
```

Expected branch:
- if all active columns PASS, document that the PPT omission came from incomplete review fixture evidence and do not rewrite the active-type mapping;
- if a real active column is omitted or misordered, fix only the demonstrated defect.

- [ ] **Step 4: Preserve the existing authoritative mapping**

The production logic remains:

```ts
const types =
  c.data?.dish_types
    .filter((type) => type.dish_type_status === "ACTIVE")
    .sort((a, b) => a.display_order - b.display_order) ?? [];
```

Do not replace it with hard-coded Vietnamese columns.

- [ ] **Step 5: Commit fixture/test evidence separately**

```bash
git add src/vnext/atlas/planning/planningReviewFixtures.ts src/vnext/atlas/planning/PlanningSourcesWorkbench.test.tsx src/vnext/atlas/planning/PlanningMenuStage.tsx
git commit -m "test(atlas): cover complete weekly menu dish types"
```

If production Menu code did not change, omit `PlanningMenuStage.tsx` from the actual staged files and state that the strengthened fixture proved current rendering completeness.

---

### Task 2: Keep School identity visible while Menu Dish Type columns scroll

**Files:**
- Modify: `src/vnext/atlas/planning/PlanningMenuStage.tsx`
- Modify: `src/vnext/atlas/planning/PlanningSourcesWorkbench.test.tsx`
- Modify: `src/vnext/atlas/planning/PlanningSourcesWorkbench.stories.tsx` only if existing stories do not expose the expanded fixture.

**Interfaces:**
- Consumes: Task 1 active-type list.
- Produces: local horizontal scrolling with a sticky first School column.

- [ ] **Step 1: Add structural assertions**

Give the Menu working surface stable markers and assert:

```tsx
expect(screen.getByTestId("weekly-menu-scroll")).toHaveAttribute(
  "data-horizontal-scroll",
  "local",
);
expect(
  within(table).getByRole("columnheader", { name: "Trường / điểm giao" }),
).toHaveAttribute("data-sticky-column", "school");
```

- [ ] **Step 2: Run and confirm red**

```bash
pnpm exec vitest run src/vnext/atlas/planning/PlanningSourcesWorkbench.test.tsx
```

Expected: FAIL on the new structural contract.

- [ ] **Step 3: Implement local scroll + sticky School column**

Keep the existing local `Box overflow="auto"`; add `data-testid="weekly-menu-scroll"` and a table minimum width sufficient for all active columns. The first header remains `Trường / điểm giao`:

```tsx
<Table.ColumnHeader
  data-sticky-column="school"
  position="sticky"
  left="0"
  zIndex="2"
  bg="bg.toolbar"
>
  Trường / điểm giao
</Table.ColumnHeader>
```

School body cells use `position="sticky"`, `left="0"`, `zIndex="1"`, and `bg="bg.workbench"`. If a selected/dirty state applies later, that state must remain visually stronger than the default sticky-cell background.

- [ ] **Step 4: Run the test and browser-check narrow width**

```bash
pnpm exec vitest run src/vnext/atlas/planning/PlanningSourcesWorkbench.test.tsx
pnpm typecheck
```

At 360×800, verify horizontal scrolling stays inside the Menu surface and the document itself does not gain horizontal overflow.

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

**Interfaces:**
- Consumes: `PantryDraftRow.school_id`, `c.pantryData?.schools`, `PantrySchool.default_delivery_location`, `c.editPantryRow(index, patch)`.
- Produces: row-level School selector labelled `Trường dòng N`; location helper comes from the selected `PantrySchool.default_delivery_location.location_name`.

- [ ] **Step 1: Add a failing row-School test**

For the first Pantry line:

```tsx
const school = await screen.findByRole("combobox", {
  name: "Trường dòng 1",
});
expect(school).toHaveValue("school-a");
expect(screen.getByText("Bếp Bình Mỹ")).toBeVisible();
```

Change to another active School and assert it remains a local draft edit until Preview/Save:

```tsx
const readsBefore = pantryApi.getWorkbench.mock.calls.length;
fireEvent.change(school, { target: { value: "school-b" } });
expect(pantryApi.getWorkbench).toHaveBeenCalledTimes(readsBefore);
expect(pantryApi.preview).not.toHaveBeenCalled();
expect(pantryApi.saveCompleted).not.toHaveBeenCalled();
```

Then open existing Preview and assert the preview request's existing canonical row payload carries `school_id: "school-b"`.

- [ ] **Step 2: Add per-School mode continuity coverage**

When changing a row from School A to School B, assert the regrouped line appears under B and the existing group-level mode selector shows B's current `school_id + service_date` mode from `c.modes`; do not copy A's mode into B.

- [ ] **Step 3: Run and confirm red**

```bash
pnpm exec vitest run src/vnext/atlas/planning/PlanningSourcesWorkbench.test.tsx
```

Expected: FAIL because Pantry currently exposes School only in the group header and add-line selector, not on each line.

- [ ] **Step 4: Add the School column using current Pantry data**

The first columns become:

```text
Trường / điểm giao
Nguyên liệu / Đơn vị
Mục đích
Số lượng
Ghi chú / Lý do
Tham chiếu
Thao tác
```

Inside each line, derive:

```ts
const selectedSchool = c.pantryData?.schools.find(
  (school) => school.school_id === r.school_id,
);
```

Render:

```tsx
<NativeSelect.Root disabled={!c.canEdit}>
  <NativeSelect.Field
    aria-label={`Trường dòng ${index + 1}`}
    value={r.school_id}
    onChange={(event) =>
      c.editPantryRow(index, { school_id: event.target.value })
    }
  >
    {c.pantryData?.schools
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
  {selectedSchool?.default_delivery_location.location_name}
</Text>
```

Keep the existing School grouping row and group-level mode selector because direct-need mode is authoritative at `school_id + service_date`, not line level. After changing School, normal rerender moves the row to the correct group; do not duplicate the mode selector on each line.

- [ ] **Step 5: Run and commit**

```bash
pnpm exec vitest run src/vnext/atlas/planning/PlanningSourcesWorkbench.test.tsx
pnpm typecheck
git add src/vnext/atlas/planning/PlanningPantryStage.tsx src/vnext/atlas/planning/PlanningSourcesWorkbench.test.tsx
git commit -m "feat(atlas): show school context on pantry lines"
```

---

### Task 4: Distinguish optional notes from required reasons and stabilize Pantry row alignment

**Files:**
- Modify: `src/vnext/atlas/planning/usePlanningSources.ts`
- Modify: `src/vnext/atlas/planning/PlanningPantryStage.tsx`
- Modify: `src/vnext/atlas/planning/PlanningSourcesWorkbench.test.tsx`

**Interfaces:**
- Consumes: `PantryPurpose.note_rule: "OPTIONAL" | "REQUIRED" | "PROHIBITED"`.
- Produces: truthful label/error copy while preserving the exact validation rule.

- [ ] **Step 1: Replace note-rule expectations with business-language tests**

Cover:

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

Add a PROHIBITED-with-existing-note case: the input remains enabled until the operator clears the invalid value; the UI must not clear it automatically.

- [ ] **Step 2: Run and confirm red**

```bash
pnpm exec vitest run src/vnext/atlas/planning/PlanningSourcesWorkbench.test.tsx
```

Expected: FAIL on existing note copy/behavior and row layout.

- [ ] **Step 3: Preserve validation semantics and rename only the REQUIRED business concept**

In `usePlanningSources.ts`, keep the existing conditions and use:

```ts
if (purpose.note_rule === "REQUIRED" && !row.note.trim())
  errors.note = "Nhập lý do cho mục đích này.";
if (purpose.note_rule === "PROHIBITED" && row.note.trim())
  errors.note = "Mục đích này không cho phép ghi chú.";
```

Do not weaken `PROHIBITED` or `REQUIRED` validation.

- [ ] **Step 4: Render dynamic field semantics without silent data loss**

```ts
const noteRequired = purpose?.note_rule === "REQUIRED";
const noteProhibited = purpose?.note_rule === "PROHIBITED";
const hasExistingNote = Boolean(r.note.trim());
const noteDisabled = !c.canEdit || (noteProhibited && !hasExistingNote);
const noteLabel = noteRequired ? "Lý do" : "Ghi chú";
```

Use `aria-label={`${noteLabel} dòng ${index + 1}`}` and `required={noteRequired}`. If PROHIBITED has an existing value, leave the field editable so the operator can clear it; once empty, disable it and show `Không áp dụng cho mục đích này.`.

- [ ] **Step 5: Reserve feedback geometry per editable cell**

Keep one stable row alignment. Where `Field.ErrorText` collapses to zero height, add a consistent feedback slot beneath the control:

```tsx
<Box minH="var(--atlas-layout-pantry-feedback, 18px)">
  {error ? (
    <Text textStyle="helper" color="status.danger">{error}</Text>
  ) : helper ? (
    <Text textStyle="helper" color="fg.muted">{helper}</Text>
  ) : null}
</Box>
```

A quantity error must not vertically shift School, Ingredient or Purpose controls in the same row.

- [ ] **Step 6: Surface `Bỏ` as a real low-emphasis command**

Use `variant="tertiary"` for textual `Bỏ` unless it is intentionally converted to an icon-only control with an accessible label. Keep the remove behavior unchanged.

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
