import type {
  RecipeCompositionLine,
  RecipeReference,
  RecipeWorkflowSelection,
} from "../bridges/dishRecipe";

export type RecipeLineDraft = {
  id: string;
  ingredientId: string;
  quantity: string;
  unitId: string;
  note: string;
};
export type RecipeDraft = { basis: string; lines: RecipeLineDraft[] };
export function parseQuantity(value: string): number | null {
  const text = value.trim();
  if (!/^\d+(?:[.,]\d+)?$/.test(text)) return null;
  const number = Number(text.replace(",", "."));
  return Number.isFinite(number) && number > 0 ? number : null;
}
export function canonicalScopes(scopes: RecipeReference[]) {
  return ["v1-school-type-1", "v1-school-type-2"].flatMap((code) => {
    const matches = scopes.filter(
      (s) => s.school_type_code === code && s.school_type_status === "ACTIVE",
    );
    return matches.length === 1 ? matches : [];
  });
}
export function recipeDraftFor(
  selection: Pick<RecipeWorkflowSelection, "basis_portions" | "composition">,
): RecipeDraft {
  return {
    basis: String(selection.basis_portions),
    lines: selection.composition
      .filter((l) => l.line_disposition === "PRESENT")
      .map((l) => ({
        id: l.recipe_line_id,
        ingredientId: l.ingredient_id,
        quantity: String(l.quantity_per_basis).replace(".", ","),
        unitId: l.unit_id,
        note: l.operational_note ?? "",
      })),
  };
}
export function validRecipeDraft(
  draft: RecipeDraft,
  refs: {
    ingredients: { ingredient_id: string; ingredient_status: string }[];
    units: { unit_id: string; unit_status: string }[];
  },
) {
  return (
    /^\d+$/.test(draft.basis.trim()) &&
    Number.isSafeInteger(Number(draft.basis)) &&
    Number(draft.basis) > 0 &&
    draft.lines.length > 0 &&
    draft.lines.length <= 500 &&
    new Set(draft.lines.map((l) => l.ingredientId)).size ===
      draft.lines.length &&
    new Set(draft.lines.map((l) => l.id)).size === draft.lines.length &&
    draft.lines.every(
      (l) =>
        parseQuantity(l.quantity) !== null &&
        refs.ingredients.some(
          (i) =>
            i.ingredient_id === l.ingredientId &&
            i.ingredient_status === "ACTIVE",
        ) &&
        refs.units.some(
          (u) => u.unit_id === l.unitId && u.unit_status === "ACTIVE",
        ),
    )
  );
}
export function recipePayload(
  selection: Pick<
    RecipeWorkflowSelection,
    "dish_id" | "school_type_id" | "recipe_version_id"
  >,
  draft: RecipeDraft,
) {
  return {
    dish_id: selection.dish_id,
    school_type_id: selection.school_type_id,
    recipe_version_id: selection.recipe_version_id,
    basis_portions: Number(draft.basis),
    lines: draft.lines.map((l) => ({
      recipe_line_id: l.id,
      ingredient_id: l.ingredientId,
      quantity_per_basis: parseQuantity(l.quantity)!,
      unit_id: l.unitId,
      operational_note: l.note.trim() || null,
    })),
  };
}
type LineFacts = Pick<
  RecipeCompositionLine,
  | "recipe_line_id"
  | "ingredient_id"
  | "quantity_per_basis"
  | "unit_id"
  | "operational_note"
>;
export function sameComposition(a: LineFacts[], b: LineFacts[]) {
  const facts = (lines: LineFacts[]) =>
    lines
      .map((l) => [
        l.recipe_line_id,
        l.ingredient_id,
        String(l.quantity_per_basis),
        l.unit_id,
        l.operational_note?.trim() || null,
      ])
      .sort((x, y) => String(x[0]).localeCompare(String(y[0])));
  return JSON.stringify(facts(a)) === JSON.stringify(facts(b));
}
