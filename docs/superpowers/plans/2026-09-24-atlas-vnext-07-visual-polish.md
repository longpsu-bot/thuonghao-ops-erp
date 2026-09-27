# Atlas vNext 07 Visual Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development while implementing each task. Execute the tasks in order; do not delegate or spawn additional agents.

**Goal:** Apply the approved workbench identity and bounded responsive table geometry slice across the Atlas shell, Schools, Ingredients/Suppliers, Recipes and Procurement without changing business behavior.

**Architecture:** Keep business controllers, bridges and contracts untouched. Add one presentation-only table viewport primitive because four connected workbenches require the same named, keyboard-reachable local overflow boundary; keep minimum widths, heights and sticky-cell state screen-owned. Compose the existing Chakra primitives into a consistent context → visible H1 → tabs → toolbar hierarchy while preserving distinct primary and secondary tab tiers.

**Tech Stack:** React 19, TypeScript, Chakra UI 3, Vitest, Testing Library, Vite review fixture, Playwright.

**Spec:** `docs/ui/atlas-vnext-07-visual-polish-direction.md`

## Global Constraints

- No backend, Supabase, Retool, API, lifecycle, quantity, permission, persistence or Planning-certification change.
- Do not modify `src/vnext/atlas/AtlasTaskTabs.ts` or any Planning component.
- Do not add pagination, virtualisation, backend search, result slicing or a new dependency.
- Preserve all editable School rows and the full Ingredient dataset.
- Primary operator-job tabs and secondary/local tabs remain different hierarchy tiers.
- Keep `src/vnext/atlas/system.ts` changes minimal; add no token or recipe unless at least two connected surfaces demonstrably require it.
- `AtlasTableViewport`, if created, is presentation-only and owns no data, columns, filtering, sorting, pagination, selection, business state or API behavior.
- Use a semantically coherent Procurement `ready` scenario for final visual evidence; record the contradictory manual-split fixture as follow-up evidence rather than changing production semantics.
- Preserve existing focus return, dirty-exit, stale/unknown outcome, disabled action and reduced-motion behavior.
- No product React/CSS change may precede a failing focused test that demonstrates the intended observable structure or accessibility behavior.

## Review Focus

1. A keyboard user can focus each table viewport, scroll it horizontally, and continue tabbing without a focus trap.
2. Sticky identity cells retain an opaque background for normal, selected and dirty rows and never cover visible focus.
3. A filter yielding zero Ingredients reports `0 / <total> nguyên liệu` while preserving the established empty-result message.
4. Procurement stage changes focus the visible stage H1 without weakening the primary tab treatment.
5. At 390px, account actions and primary workbench actions remain reachable while all horizontal overflow stays inside named table regions.

---

### Task 1: Shared named table viewport

**Files:**

- Create: `src/vnext/atlas/AtlasTableViewport.tsx`
- Create: `src/vnext/atlas/AtlasTableViewport.test.tsx`

**Interfaces:**

- Consumes: Chakra `Box` and `BoxProps`.
- Produces: `AtlasTableViewport({ label, children, ...boxProps })`, a named `role="region"` with `tabIndex={0}`, `minW="0"` and local overflow.

- [ ] **Step 1: Write the failing accessibility test**

```tsx
it("creates a named keyboard-reachable local scroll region", () => {
  render(
    <AtlasVNextProvider>
      <AtlasTableViewport label="Danh sách kiểm tra">
        <table>
          <tbody>
            <tr>
              <td>Nội dung</td>
            </tr>
          </tbody>
        </table>
      </AtlasTableViewport>
    </AtlasVNextProvider>,
  );
  const region = screen.getByRole("region", { name: "Danh sách kiểm tra" });
  expect(region).toHaveAttribute("tabindex", "0");
  expect(region).toHaveStyle({ overflow: "auto" });
  region.focus();
  expect(region).toHaveFocus();
  expect(within(region).getByText("Nội dung")).toBeVisible();
});
```

- [ ] **Step 2: Verify the test fails because the component does not exist**

Run: `pnpm exec vitest run src/vnext/atlas/AtlasTableViewport.test.tsx --maxWorkers=1`

Expected: FAIL because `AtlasTableViewport` cannot be imported.

- [ ] **Step 3: Implement the minimal presentation primitive**

```tsx
import { Box, type BoxProps } from "@chakra-ui/react";
import type { ReactNode } from "react";

export interface AtlasTableViewportProps extends Omit<BoxProps, "children"> {
  label: string;
  children: ReactNode;
}

export function AtlasTableViewport({
  label,
  children,
  ...props
}: AtlasTableViewportProps) {
  return (
    <Box
      role="region"
      aria-label={label}
      tabIndex={0}
      minW="var(--atlas-layout-zero, 0)"
      overflow="auto"
      {...props}
    >
      {children}
    </Box>
  );
}
```

Do not add table data, selection or geometry defaults beyond the local viewport contract.

- [ ] **Step 4: Run the focused test and verify it passes**

Run: `pnpm exec vitest run src/vnext/atlas/AtlasTableViewport.test.tsx --maxWorkers=1`

Expected: 1 file passed.

### Task 2: Visible workbench identity and compact shell

**Files:**

- Modify: `src/vnext/atlas/AtlasVNextShell.tsx`
- Modify: `src/vnext/atlas/AtlasVNextShell.test.tsx`
- Modify: `src/vnext/atlas/master-data/IngredientSupplierWorkbench.tsx`
- Modify: `src/vnext/atlas/master-data/IngredientSupplierWorkbench.test.tsx`
- Modify: `src/vnext/atlas/recipes/RecipeCapability.tsx`
- Modify: `src/vnext/atlas/recipes/RecipeCapability.test.tsx`
- Modify: `src/vnext/atlas/procurement/ProcurementWorkbench.tsx`
- Modify: `src/vnext/atlas/procurement/ProcurementWorkbench.test.tsx`

**Interfaces:**

- Consumes: existing Chakra layout and existing tab/controller behavior.
- Produces: visible context/H1 hierarchy while keeping the same tabs, navigation and commands.

- [ ] **Step 1: Add failing structural tests**

Add tests that assert observable hierarchy rather than private component names:

```tsx
const heading = screen.getByRole("heading", {
  level: 1,
  name: "Phân bổ nhà cung ứng",
});
expect(heading).toBeVisible();
expect(
  screen.getByText("Kế hoạch mua hàng").compareDocumentPosition(heading) &
    Node.DOCUMENT_POSITION_FOLLOWING,
).toBeTruthy();
expect(
  heading.compareDocumentPosition(screen.getByRole("tablist")) &
    Node.DOCUMENT_POSITION_FOLLOWING,
).toBeTruthy();
```

Also assert that switching to `Đơn mua` moves focus to the visible `Đơn mua` H1. For Ingredients and Recipes, assert the visible H1 precedes their quieter local tablist. For the shell, assert service date, operator identity and `Đăng xuất` remain in one labelled session header region after the compact composition change.

- [ ] **Step 2: Run the four focused files and verify the new assertions fail for the intended hierarchy**

Run:

```powershell
pnpm exec vitest run `
  src/vnext/atlas/AtlasVNextShell.test.tsx `
  src/vnext/atlas/master-data/IngredientSupplierWorkbench.test.tsx `
  src/vnext/atlas/recipes/RecipeCapability.test.tsx `
  src/vnext/atlas/procurement/ProcurementWorkbench.test.tsx `
  --maxWorkers=1
```

Expected: existing tests pass; new identity-order/visible-heading assertions fail.

- [ ] **Step 3: Implement the approved identity order**

- Procurement: render muted `Kế hoạch mua hàng`, a visible stage-specific H1, then the existing primary job tabs. Keep the heading ref/focus behavior on the visible H1.
- Ingredients/Suppliers: render muted module context, current-job H1, then the existing quiet line tabs.
- Recipes: preserve `Công thức` as module identity, render the current local-job title before the quiet line tabs, and avoid duplicate top padding inside the embedded Recipe workbench.
- Shell: retain the 60px mobile navigation row; reduce only the secondary/session header padding and gap, constrain the user label with ellipsis, and keep the date, identity and sign-out action visible and semantically grouped.
- Do not alter navigation labels, tab variants, controller transitions or Planning consumers.

- [ ] **Step 4: Re-run the four focused files**

Expected: all identity, focus and existing behavior tests pass.

### Task 3: Bounded responsive table geometry and result context

**Files:**

- Modify: `src/vnext/atlas/schools/SchoolDefaultsWorkbench.tsx`
- Modify: `src/vnext/atlas/schools/SchoolDefaultsWorkbench.test.tsx`
- Modify: `src/vnext/atlas/master-data/IngredientSupplierWorkbench.tsx`
- Modify: `src/vnext/atlas/master-data/IngredientCatalogue.tsx`
- Modify: `src/vnext/atlas/master-data/IngredientSupplierWorkbench.test.tsx`
- Modify: `src/vnext/atlas/recipes/DishRecipeWorkbench.tsx`
- Modify: `src/vnext/atlas/recipes/DishCatalogue.tsx`
- Modify: `src/vnext/atlas/recipes/DishRecipeWorkbench.test.tsx`
- Modify: `src/vnext/atlas/procurement/ProcurementWorkbench.tsx`
- Modify: `src/vnext/atlas/procurement/ProcurementAllocationTable.tsx`
- Modify: `src/vnext/atlas/procurement/ProcurementWorkbench.test.tsx`
- Reuse: `src/vnext/atlas/AtlasTableViewport.tsx`

**Interfaces:**

- Consumes: `AtlasTableViewport` from Task 1 and existing controller values.
- Produces: named local table regions, screen-owned width/height rules and sticky identity cells.

- [ ] **Step 1: Add failing focused tests for the approved contracts**

Schools:

```tsx
const region = screen.getByRole("region", {
  name: "Bảng sĩ số mặc định theo trường",
});
expect(region).toHaveAttribute("tabindex", "0");
expect(region).toContainElement(
  screen.getByRole("table", { name: "Sĩ số mặc định theo trường" }),
);
expect(region).not.toContainElement(
  screen.getByRole("button", { name: "Lưu thay đổi" }),
);
```

Ingredients:

```tsx
expect(screen.getByText("360 nguyên liệu")).toBeVisible();
fireEvent.change(screen.getByLabelText("Tìm nguyên liệu"), {
  target: { value: "không tồn tại" },
});
expect(screen.getByText("0 / 360 nguyên liệu")).toBeVisible();
expect(
  screen.getByRole("region", { name: "Danh mục nguyên liệu" }),
).toHaveAttribute("tabindex", "0");
```

Recipes and Procurement: assert each table is inside a correctly named focusable region. Assert Recipe catalogue retains a minimum width equivalent to approximately 720px and Procurement approximately 1,020px through rendered style or the stable CSS variable applied to the table.

- [ ] **Step 2: Run the four module test files and verify the new tests fail for missing regions/count/geometry**

Run:

```powershell
pnpm exec vitest run `
  src/vnext/atlas/schools/SchoolDefaultsWorkbench.test.tsx `
  src/vnext/atlas/master-data/IngredientSupplierWorkbench.test.tsx `
  src/vnext/atlas/recipes/DishRecipeWorkbench.test.tsx `
  src/vnext/atlas/procurement/ProcurementWorkbench.test.tsx `
  --maxWorkers=1
```

- [ ] **Step 3: Implement screen-owned table geometry**

- Schools: replace the unlabelled overflow wrapper with `AtlasTableViewport`; use a responsive bounded max height, keep summary/Save immediately above it, keep every row, retain local x-scroll and sticky header, and keep School identity sticky at narrow widths when visual verification confirms it is useful.
- Ingredients: use the shared viewport without changing full-data rendering; preserve existing max-height containment/sticky header; show `<visible> nguyên liệu` when unfiltered and `<visible> / <total> nguyên liệu` when filtering reduces the result; make Ingredient identity/header sticky at narrow widths with selected-row background preserved.
- Recipes: wrap the Dish catalogue table in the shared viewport, set the non-compact table minimum width near 720px, and keep Dish identity/header sticky at narrow widths. Preserve compact open-Dish navigation behavior.
- Procurement: replace or compose the existing scroll area with the shared named viewport, set the table minimum width near 1,020px, keep the Ingredient identity/header sticky at narrow widths, and make the workbench fill available height without adding filler content.
- Use opaque `bg.workbench`/`bg.selected` cells and suitable z-index so sticky cells do not reveal scrolled content or cover focus.
- Do not add global system tokens unless the exact same value is consumed by two surfaces; prefer local CSS custom-property fallbacks already used by Atlas.

- [ ] **Step 4: Run the module tests and the shared viewport test**

Expected: all focused files pass, including the existing interaction and dirty-state suites.

### Task 4: Coherent review fixture, responsive capture and targeted validation

**Files:**

- Modify: `src/vnext/atlas/atlasApplicationReviewFixtures.ts`
- Modify: `src/vnext/atlas/AtlasVNextApp.review.tsx`
- Create: `src/vnext/atlas/atlasApplicationReviewFixtures.test.ts`
- Modify only if required by formatting/type errors: files already listed in Tasks 1–3

**Interfaces:**

- Consumes: existing `createProcurementReviewFixture("ready")`.
- Produces: a fixture-only `?scenario=ready` review route; production entry remains unchanged.

- [ ] **Step 1: Add a failing fixture test**

Extend `createAtlasApplicationFixture` with an optional Procurement review scenario while keeping `manual_split` as the default. Test the real fixture API and assert that the `ready` scenario returns `preparation.ready === true`, `preparation.allowed === true`, no blockers and a BALANCED row. The test must call the fixture API rather than inspect source text.

- [ ] **Step 2: Verify the fixture test fails before changing the factory**

Run the focused fixture test with `--maxWorkers=1`.

- [ ] **Step 3: Implement fixture-only scenario selection**

- `createAtlasApplicationFixture(procurementScenario = "manual_split")` passes the selected scenario to `createProcurementReviewFixture`.
- `AtlasVNextApp.review.tsx` accepts only known review scenarios needed here (`ready` and existing `unknown`) and otherwise preserves the default.
- Do not change production entrypoints or Procurement controller semantics.

- [ ] **Step 4: Run targeted automated validation**

Run:

```powershell
pnpm exec vitest run `
  src/vnext/atlas/AtlasTableViewport.test.tsx `
  src/vnext/atlas/AtlasVNextShell.test.tsx `
  src/vnext/atlas/AtlasVNextShell.navigation.test.tsx `
  src/vnext/atlas/schools/SchoolDefaultsWorkbench.test.tsx `
  src/vnext/atlas/master-data/IngredientSupplierWorkbench.test.tsx `
  src/vnext/atlas/recipes/RecipeCapability.test.tsx `
  src/vnext/atlas/recipes/DishRecipeWorkbench.test.tsx `
  src/vnext/atlas/procurement/ProcurementWorkbench.test.tsx `
  src/vnext/atlas/atlasApplicationReviewFixtures.test.ts `
  --maxWorkers=1
pnpm typecheck
pnpm ui:vnext:check
git diff --check
```

Expected: all targeted commands exit 0. GitHub Actions remains owner of the complete routine frontend suite.

- [ ] **Step 5: Render and inspect all responsive surfaces**

Use `atlas-vnext-review.html`; for Procurement navigate with `?scenario=ready`. Capture Shell/Schools, Ingredients/Suppliers, Recipes and Procurement at 1440×900, 1280×800, 768×1024 and 390×844.

Confirm:

- zero console warnings/errors;
- zero document-wide horizontal overflow;
- all table overflow remains inside named regions;
- School summary/Save remains outside and above the bounded viewport;
- all 360 Ingredients remain rendered and result context is correct;
- Recipe columns no longer collapse word by word at 390px;
- Procurement shows a visible stage H1 and coherent ready state;
- sticky cells have opaque state-correct backgrounds and do not cover focus;
- mobile navigation/session actions remain reachable.

- [ ] **Step 6: Self-review and commit**

Review the diff against the Spec and Global Constraints. Commit the implementation and plan with a bounded message such as:

```powershell
git add -- docs/superpowers/plans/2026-09-24-atlas-vnext-07-visual-polish.md src/vnext/atlas
git commit -m "feat(ui): polish Atlas workbench geometry"
```

Do not push; the parent session performs finish review and final publication.
