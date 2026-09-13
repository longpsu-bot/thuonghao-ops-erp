# Atlas UI vNext 06D-C Recipe Safety and Lock UX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent confusing duplicate-Ingredient `ADD` Change Orders and make base Recipe lock state plus the correct forward action unmistakable in the Recipe workbench.

**Architecture:** Add a pure frontend duplicate-target classifier over the already-authoritative effective target list; the backend command contract stays unchanged. For lock UX, derive catalogue lock state only from existing `RecipeVersionRecord` lifecycle facts, and route `Tạo lệnh điều chỉnh` through the existing Recipe capability peer-tab switch rather than creating a new navigation or command layer.

**Tech Stack:** React 19.2.7, TypeScript 7.0.2, Chakra UI 3.37.0, Vitest 4.1.10, Testing Library, existing Recipe APIs/models, pnpm 11.7.0.

**Spec:** `docs/superpowers/specs/2026-09-13-atlas-ui-vnext-06d-interaction-affordance-design.md`

## Global Constraints

- Requires 06D-A shared button/date grammar and 06D-B reviewed head.
- Frontend safety may be stricter than backend; backend Recipe/Adjustment commands, schema, RLS and RPC signatures are frozen.
- `ADD` duplicate protection applies to Recipe Change Orders, not ordinary base-Recipe authoring.
- Never silently change an operator's action from `ADD` to `ADJUST_QUANTITY`.
- Single exact duplicate target may be converted only after the operator clicks `Chuyển sang Điều chỉnh định lượng`.
- Multiple effective target lines for the same Ingredient are ambiguous: block `ADD`, explain the ambiguity, and require manual target selection in `ADJUST_QUANTITY`; never guess.
- Lock state must come from authoritative Recipe lifecycle/read data, not from visual heuristics or Menu history inference.
- Keep Recipe navigator/editor geometry and existing command/currentness/UNKNOWN protections.
- PR #286 remains untouched.

---

### Task 1: Classify duplicate ADD targets as none, single, or ambiguous

**Files:**
- Modify: `src/vnext/atlas/recipes/changeOrderModel.ts`
- Modify: `src/vnext/atlas/recipes/changeOrderModel.test.ts`

**Interfaces:**
- Consumes: `ChangeDraft`, `EffectiveTargetContext`, `EffectiveTargetLine` from existing Adjustment models.
- Produces:

```ts
export type DuplicateAddTarget =
  | { kind: "none" }
  | { kind: "single"; line: EffectiveTargetLine }
  | { kind: "ambiguous"; lines: EffectiveTargetLine[] };

export function duplicateAddTarget(
  draft: ChangeDraft,
  targets: EffectiveTargetContext | null,
): DuplicateAddTarget;
```

- [ ] **Step 1: Write pure failing unit tests**

Use the existing `changeOrderReviewFixtures.ts` effective targets, including Hành lá at 0.2 kg. Cover:

```ts
expect(duplicateAddTarget(
  { ...draft, action: "ADD", ingredientId: "ingredient-new" },
  targets,
)).toEqual({ kind: "none" });

expect(duplicateAddTarget(
  { ...draft, action: "ADD", ingredientId: "ingredient-2" },
  targets,
)).toMatchObject({
  kind: "single",
  line: { ingredient_id: "ingredient-2", quantity_per_basis: "0.2" },
});
```

Create a local test target context with two lines sharing one `ingredient_id` and assert `kind: "ambiguous"` with both lines preserved in source order.

Also assert a non-ADD action always returns `none`.

- [ ] **Step 2: Run the unit test and confirm red**

```bash
pnpm exec vitest run src/vnext/atlas/recipes/changeOrderModel.test.ts
```

Expected: FAIL because `duplicateAddTarget` does not exist.

- [ ] **Step 3: Implement the classifier without changing backend request shaping**

Implement exactly:

```ts
export function duplicateAddTarget(
  draft: ChangeDraft,
  targets: EffectiveTargetContext | null,
): DuplicateAddTarget {
  if (draft.action !== "ADD" || !draft.ingredientId || !targets)
    return { kind: "none" };
  const lines = targets.lines.filter(
    (line) => line.ingredient_id === draft.ingredientId,
  );
  if (lines.length === 0) return { kind: "none" };
  if (lines.length === 1) return { kind: "single", line: lines[0]! };
  return { kind: "ambiguous", lines };
}
```

Do not alter `recipeAdjustmentRequest` or server action enums.

- [ ] **Step 4: Make preview validity reject duplicate ADD**

Update the existing frontend validity predicate so `ADD` is previewable only when the effective target list has loaded and `duplicateAddTarget(...).kind === "none"`. Keep all existing field/unit/quantity validation.

If the existing validity function signature lacks targets, add `targets: EffectiveTargetContext | null` to the function and update only its current callers/tests; do not introduce hidden module state.

- [ ] **Step 5: Run and commit**

```bash
pnpm exec vitest run src/vnext/atlas/recipes/changeOrderModel.test.ts
pnpm typecheck
git add src/vnext/atlas/recipes/changeOrderModel.ts src/vnext/atlas/recipes/changeOrderModel.test.ts
git commit -m "feat(atlas): guard duplicate recipe add targets"
```

---

### Task 2: Give the operator an explicit transition from duplicate ADD to quantity adjustment

**Files:**
- Modify: `src/vnext/atlas/recipes/useChangeOrderWorkbench.ts`
- Modify: `src/vnext/atlas/recipes/ChangeOrderEditor.tsx`
- Modify: `src/vnext/atlas/AtlasConvergence.test.tsx`
- Modify: `src/vnext/atlas/recipes/changeOrderReviewFixtures.ts` only if an extra ambiguous fixture is required.

**Interfaces:**
- Consumes: `duplicateAddTarget`, existing `targetKey(line)` helper/current target-key format, current `updateDraft` path.
- Produces controller fields:

```ts
duplicateAdd: DuplicateAddTarget;
switchDuplicateAddToAdjust(): void;
```

- [ ] **Step 1: Add an integration test for the single-target case**

Render `RecipeCapability` in `initialJob="changes"` with `createChangeOrderFixture("ACTIVE")`. Select `ADD`, select Hành lá, enter `13`, and assert:

```tsx
expect(screen.getByText(/Hành lá đã có trong công thức/i)).toBeVisible();
expect(screen.getByText(/0,2 kg/i)).toBeVisible();
expect(screen.getByRole("button", { name: "Xem tác động" })).toBeDisabled();
```

Click:

```tsx
fireEvent.click(screen.getByRole("button", {
  name: "Chuyển sang Điều chỉnh định lượng",
}));
```

Then assert action is `ADJUST_QUANTITY`, the exact existing target is selected, and the typed `13` quantity remains the proposed quantity. Assert zero preview/create API calls occurred before the explicit click.

- [ ] **Step 2: Add an ambiguous-target test**

Use a fixture whose effective target list contains two rows for one Ingredient. Assert the UI says the Ingredient appears on multiple effective lines, keeps `Xem tác động` disabled, and does **not** expose an automatic switch button that chooses a target.

The operator can manually change the action to `Điều chỉnh định lượng` and choose the correct target from the existing target selector.

- [ ] **Step 3: Run the integration test and confirm red**

```bash
pnpm exec vitest run src/vnext/atlas/AtlasConvergence.test.tsx src/vnext/atlas/recipes/changeOrderModel.test.ts
```

Expected: FAIL because the duplicate warning/controller transition does not exist.

- [ ] **Step 4: Expose duplicate state and explicit transition in the controller**

Compute:

```ts
const duplicateAdd = duplicateAddTarget(draft, targets);
```

Implement:

```ts
const switchDuplicateAddToAdjust = () => {
  if (duplicateAdd.kind !== "single") return;
  updateDraft({
    action: "ADJUST_QUANTITY",
    targetKey: targetKey(duplicateAdd.line),
    ingredientId: "",
    substituteId: "",
    replaceQuantity: "",
    // preserve draft.quantity exactly
  });
  setPreview(null);
};
```

Use the controller's existing field names exactly; if `updateDraft` merges one partial object, do not recreate the draft manually.

- [ ] **Step 5: Render the safety signal in the editor**

For `duplicateAdd.kind === "single"`, render a warning/information surface immediately below the Ingredient selection:

```tsx
<Text fontWeight="semibold">Nguyên liệu đã có trong công thức</Text>
<Text>
  {duplicateAdd.line.ingredient_name} hiện có {formatQuantity(duplicateAdd.line.quantity_per_basis)} {duplicateAdd.line.unit_name}.
</Text>
<Button variant="secondary" onClick={c.switchDuplicateAddToAdjust}>
  Chuyển sang Điều chỉnh định lượng
</Button>
```

For `ambiguous`, render:

`Nguyên liệu đã xuất hiện ở nhiều dòng hiệu lực. Chọn Điều chỉnh định lượng và chọn đúng thành phần cần sửa.`

Do not fabricate a target.

- [ ] **Step 6: Run and commit**

```bash
pnpm exec vitest run src/vnext/atlas/AtlasConvergence.test.tsx src/vnext/atlas/recipes/changeOrderModel.test.ts
pnpm typecheck
git add src/vnext/atlas/recipes/useChangeOrderWorkbench.ts src/vnext/atlas/recipes/ChangeOrderEditor.tsx src/vnext/atlas/AtlasConvergence.test.tsx src/vnext/atlas/recipes/changeOrderReviewFixtures.ts
git commit -m "feat(atlas): guide duplicate adds to quantity adjustment"
```

---

### Task 3: Derive and expose base Recipe lock state in the catalogue

**Files:**
- Modify: `src/vnext/atlas/recipes/changeOrderModel.ts` only if shared formatting belongs there; otherwise keep lock helper with Recipe workbench code.
- Modify: `src/vnext/atlas/recipes/DishCatalogue.tsx`
- Modify: `src/vnext/atlas/recipes/DishRecipeWorkbench.test.tsx`
- Modify: `src/vnext/atlas/recipes/DishRecipeWorkbench.tsx`

**Interfaces:**
- Consumes: `c.catalog.recipes`, `c.catalog.recipe_versions`, `RecipeVersionRecord.version_number`, `recipe_version_status`.
- Produces:

```ts
type DishBaseRecipeState = "LOCKED" | "EDITABLE" | "MISSING";
function dishBaseRecipeState(c: DishRecipeController, dishId: string): DishBaseRecipeState;
```

`LOCKED` means at least one active Recipe root for the Dish has its latest authoritative RecipeVersion in `LOCKED`. `EDITABLE` means Recipe data exists and no current latest version is LOCKED. `MISSING` means no Recipe exists.

- [ ] **Step 1: Add catalogue lock-state tests**

Using existing Recipe review fixtures, assert the full catalogue displays:

```text
🔒 Công thức gốc đã khóa
Chỉnh qua Lệnh điều chỉnh
```

for the locked scenario, and action label `Xem công thức`.

For the editable scenario, assert `Sửa công thức` and no locked copy.

- [ ] **Step 2: Add selected-editor lock-copy test**

Change the existing locked Recipe test from the old implicit copy to the exact approved message:

```text
Công thức này đã được sử dụng trong vận hành. Công thức gốc chỉ đọc; thay đổi tiếp theo được thực hiện bằng Lệnh điều chỉnh.
```

Keep assertions proving quantity/composition controls remain read-only.

- [ ] **Step 3: Run and confirm red**

```bash
pnpm exec vitest run src/vnext/atlas/recipes/DishRecipeWorkbench.test.tsx
```

Expected: FAIL on action labels and explicit lock copy.

- [ ] **Step 4: Implement lock-state derivation from current RecipeVersion facts**

For each recipe root of a Dish, find its highest `version_number`; inspect only that current version. Do not treat any historical LOCKED predecessor as the current state if a later version exists.

Example helper:

```ts
const latestByRecipe = new Map<string, RecipeVersionRecord>();
for (const version of c.catalog.recipe_versions) {
  const current = latestByRecipe.get(version.recipe_id);
  if (!current || version.version_number > current.version_number)
    latestByRecipe.set(version.recipe_id, version);
}
const recipeIds = c.catalog.recipes
  .filter((r) => r.dish_id === dishId && r.recipe_status === "ACTIVE")
  .map((r) => r.recipe_id);
```

Then return LOCKED/EDITABLE/MISSING as defined above.

- [ ] **Step 5: Render surfaced catalogue actions**

Use `variant="tertiary"` for `Sửa công thức` / `Xem công thức`. Keep compact mobile navigator `Chọn` link-like only if it is purely navigation; otherwise use tertiary there too.

- [ ] **Step 6: Run and commit**

```bash
pnpm exec vitest run src/vnext/atlas/recipes/DishRecipeWorkbench.test.tsx
pnpm typecheck
git add src/vnext/atlas/recipes/DishCatalogue.tsx src/vnext/atlas/recipes/DishRecipeWorkbench.tsx src/vnext/atlas/recipes/DishRecipeWorkbench.test.tsx
git commit -m "feat(atlas): make recipe lock state explicit"
```

---

### Task 4: Route locked Recipe operators directly to the existing Change Order peer job

**Files:**
- Modify: `src/vnext/atlas/recipes/RecipeCapability.tsx`
- Modify: `src/vnext/atlas/recipes/DishRecipeWorkbench.tsx`
- Modify: `src/vnext/atlas/recipes/DishRecipeWorkbench.test.tsx`
- Modify: `src/vnext/atlas/AtlasConvergence.test.tsx`

**Interfaces:**
- Produces optional prop:

```ts
onOpenChangeOrders?: () => void;
```

on `DishRecipeWorkbench`.

- [ ] **Step 1: Write the peer-navigation regression**

Render `RecipeCapability` in a locked Recipe scenario. Select the locked Dish and click `Tạo lệnh điều chỉnh`. Assert:

```tsx
expect(screen.getByRole("tab", { name: "Lệnh điều chỉnh" }))
  .toHaveAttribute("aria-selected", "true");
expect(await screen.findByText(/Lệnh điều chỉnh công thức/i)).toBeVisible();
```

No backend mutation should be called by navigation.

- [ ] **Step 2: Run and confirm red**

```bash
pnpm exec vitest run src/vnext/atlas/recipes/DishRecipeWorkbench.test.tsx src/vnext/atlas/AtlasConvergence.test.tsx
```

Expected: FAIL because no locked-editor peer action exists.

- [ ] **Step 3: Wire the existing capability switch with exit safety**

In `RecipeCapability.tsx`, create one helper used by both tab changes and the new action:

```ts
const switchJob = (next: "recipes" | "changes") => {
  if (next !== job) active.current?.requestExit(() => setJob(next));
};
```

Pass:

```tsx
<DishRecipeWorkbench
  ...
  onOpenChangeOrders={() => switchJob("changes")}
/>
```

Do not create a router or duplicate capability state.

- [ ] **Step 4: Render the locked forward action**

In the locked base Recipe view:

```tsx
<Button variant="secondary" onClick={onOpenChangeOrders}>
  Tạo lệnh điều chỉnh
</Button>
```

Show it only when the base Recipe is locked. Editable Recipe remains focused on `Lưu công thức`.

- [ ] **Step 5: Run and commit**

```bash
pnpm exec vitest run src/vnext/atlas/recipes/DishRecipeWorkbench.test.tsx src/vnext/atlas/AtlasConvergence.test.tsx
pnpm typecheck
git add src/vnext/atlas/recipes/RecipeCapability.tsx src/vnext/atlas/recipes/DishRecipeWorkbench.tsx src/vnext/atlas/recipes/DishRecipeWorkbench.test.tsx src/vnext/atlas/AtlasConvergence.test.tsx
git commit -m "feat(atlas): route locked recipes to change orders"
```

---

### Task 5: Recipe slice certification

**Files:**
- No new product files unless tests prove a regression.

- [ ] **Step 1: Run all Recipe VNext tests**

```bash
pnpm exec vitest run src/vnext/atlas/recipes src/vnext/atlas/AtlasConvergence.test.tsx src/vnext/atlas/AtlasModuleExit.test.tsx
```

Expected: PASS.

- [ ] **Step 2: Run structural/build checks**

```bash
pnpm ui:vnext:typegen
pnpm ui:vnext:check
pnpm typecheck
pnpm build-storybook
git diff --check
```

Expected: PASS.

- [ ] **Step 3: Review the two PPT Recipe states in browser**

At 1366×768 and 360×800 verify:

```text
Duplicate ADD → warning, preview blocked, explicit transition only
Locked catalogue row → lock is obvious before opening
Locked editor → exact read-only explanation + Tạo lệnh điều chỉnh
Editable row/editor → Sửa/Lưu remains available and not mislabeled
Business actions → surfaced button treatment, not plain text
```

## 06D-C Exit Gate

```text
Duplicate ADD single target     PASS
Duplicate ADD ambiguous target  PASS
No silent command conversion    PASS
Recipe lock catalogue/editor    PASS
Peer Change Order navigation    PASS
Backend/API/schema changes      ZERO
```
