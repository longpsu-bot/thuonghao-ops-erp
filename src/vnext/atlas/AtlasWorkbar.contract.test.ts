import { readFileSync } from "node:fs";
import { expect, it } from "vitest";

it.each([
  "schools/SchoolDefaultsWorkbench.tsx",
  "planning/PlanningSourcesWorkbench.tsx",
  "planning-confirmed/ConfirmedNeedWorkbench.tsx",
  "procurement/ProcurementWorkbench.tsx",
  "dispatch/SchoolPxkWorkbench.tsx",
  "master-data/IngredientSupplierWorkbench.tsx",
  "recipes/DishRecipeWorkbench.tsx",
  "recipes/ChangeOrderWorkbench.tsx",
  "reconciliation/SchoolFulfilmentWorkbench.tsx",
])(
  "keeps %s refresh inside a shared action group without vertical offsets",
  (file) => {
    const source = readFileSync(new URL(file, import.meta.url), "utf8");
    expect(source).toMatch(/<AtlasWorkbar[\s>]/);
    expect(source).toMatch(
      /<AtlasWorkbarActions[\s\S]*?<AtlasRefreshButton[\s\S]*?<\/AtlasWorkbarActions>/,
    );
    expect(source).not.toMatch(/pt=\{[^}]*26px|pt="26px"/);
  },
);
