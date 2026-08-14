import { describe, expect, it } from "vitest";
import type { JsonValue } from "../connection/atlasRpc";
import type { RecipeAdjustmentCommandRequest } from "./recipeAdjustmentApi";
import type {
  RecipeAdjustmentPreview,
  RecipeAdjustmentAction,
  RecipeAdjustmentScope,
} from "./recipeAdjustmentModel";
import { createReviewRecipeAdjustmentApi } from "./reviewRecipeAdjustmentApi";

const fixtureIds = {
  school: "11000000-0000-4000-8000-000000000001",
  dish: "13000000-0000-4000-8000-000000000001",
  pumpkinLine: "16000000-0000-4000-8000-000000000001",
  porkLine: "16000000-0000-4000-8000-000000000002",
  pumpkin: "17000000-0000-4000-8000-000000000001",
  pork: "17000000-0000-4000-8000-000000000002",
  carrot: "17000000-0000-4000-8000-000000000003",
  potato: "17000000-0000-4000-8000-000000000004",
  kilogram: "18000000-0000-4000-8000-000000000001",
};

const combinations: Array<{
  scope: RecipeAdjustmentScope;
  action: RecipeAdjustmentAction;
}> = [
  { scope: "SYSTEM_INGREDIENT", action: "REPLACE" },
  { scope: "SYSTEM_DISH", action: "ADD" },
  { scope: "SYSTEM_DISH", action: "REPLACE" },
  { scope: "SYSTEM_DISH", action: "ADJUST_QUANTITY" },
  { scope: "SYSTEM_DISH", action: "REMOVE" },
  { scope: "SCHOOL", action: "REPLACE" },
  { scope: "SCHOOL", action: "REMOVE" },
  { scope: "SCHOOL_DISH", action: "ADD" },
  { scope: "SCHOOL_DISH", action: "REPLACE" },
  { scope: "SCHOOL_DISH", action: "ADJUST_QUANTITY" },
  { scope: "SCHOOL_DISH", action: "REMOVE" },
];

function proposal(
  scope: RecipeAdjustmentScope,
  action: RecipeAdjustmentAction,
  index: number,
): Record<string, JsonValue> {
  const targetsIngredient =
    scope === "SYSTEM_INGREDIENT" || scope === "SCHOOL" || action === "ADD";
  return {
    adjustment_id: `adjustment-${index}`,
    revision_id: `revision-${index}`,
    adjustment_line_id: `adjustment-line-${index}`,
    scope_kind: scope,
    action_kind: action,
    school_id: fixtureIds.school,
    dish_id: fixtureIds.dish,
    target_ingredient_id: targetsIngredient ? fixtureIds.pumpkin : null,
    target_recipe_line_id: targetsIngredient ? null : fixtureIds.pumpkinLine,
    substitute_ingredient_id: fixtureIds.potato,
    quantity_per_basis: 12.5,
    unit_id: fixtureIds.kilogram,
    effective_from: "2026-07-27",
  };
}

function command(
  payload: Record<string, JsonValue>,
  index: number,
): RecipeAdjustmentCommandRequest {
  return {
    contract_version: "RMVP-02B.v1",
    command_id: `command-${index}`,
    correlation_id: `correlation-${index}`,
    idempotency_key: `review-matrix:${index}`,
    expected_version: 1,
    requested_by_auth_subject: "review-operator",
    requested_at: "2026-07-27T02:00:00.000Z",
    reason_code: "REVIEW_MATRIX",
    reason_note: "Kiểm tra đầy đủ danh mục phạm vi và hành động.",
    payload,
  };
}

describe("Recipe adjustment review matrix", () => {
  it("replaces the selected pork line with potato and preserves 8 kg", async () => {
    const api = createReviewRecipeAdjustmentApi("ready");
    const result = await api.preview("review-operator", "targeted-preview", {
      as_of_date: "2026-07-27",
      school_id: fixtureIds.school,
      dish_id: fixtureIds.dish,
      proposed_adjustment: {
        ...proposal("SYSTEM_INGREDIENT", "REPLACE", 100),
        target_ingredient_id: fixtureIds.pork,
        substitute_ingredient_id: fixtureIds.potato,
        quantity_per_basis: null,
        unit_id: null,
      },
    });

    expect(result.kind).toBe("success");
    if (result.kind !== "success") return;
    const preview = result.response
      .preview as unknown as RecipeAdjustmentPreview;
    const pumpkinBefore = preview.before.lines.find(
      (line) => line.base_recipe_line_id === fixtureIds.pumpkinLine,
    )!;
    const pumpkinAfter = preview.after.lines.find(
      (line) => line.base_recipe_line_id === fixtureIds.pumpkinLine,
    )!;
    const porkBefore = preview.before.lines.find(
      (line) => line.base_recipe_line_id === fixtureIds.porkLine,
    )!;
    const porkAfter = preview.after.lines.find(
      (line) => line.base_recipe_line_id === fixtureIds.porkLine,
    )!;

    expect(pumpkinBefore.final_ingredient_id).toBe(fixtureIds.pumpkin);
    expect(pumpkinAfter).toMatchObject({
      final_ingredient_id: fixtureIds.pumpkin,
      final_quantity_per_basis: 20,
    });
    expect(porkBefore).toMatchObject({
      final_ingredient_id: fixtureIds.pork,
      final_quantity_per_basis: 8,
    });
    expect(porkAfter).toMatchObject({
      final_ingredient_id: fixtureIds.potato,
      final_quantity_per_basis: 8,
      final_unit_id: fixtureIds.kilogram,
    });
    expect(pumpkinAfter.final_ingredient_id).not.toBe(fixtureIds.carrot);
    expect(preview).toMatchObject({ can_save: true, affected_line_count: 1 });
  });

  it("blocks review preview safely when its deterministic target is missing", async () => {
    const api = createReviewRecipeAdjustmentApi("ready");
    const result = await api.preview("review-operator", "missing-target", {
      as_of_date: "2026-07-27",
      school_id: fixtureIds.school,
      dish_id: fixtureIds.dish,
      proposed_adjustment: {
        ...proposal("SYSTEM_INGREDIENT", "REPLACE", 101),
        target_ingredient_id: "17000000-0000-4000-8000-999999999999",
        quantity_per_basis: null,
        unit_id: null,
      },
    });

    expect(result.kind).toBe("success");
    if (result.kind !== "success") return;
    const preview = result.response
      .preview as unknown as RecipeAdjustmentPreview;
    expect(preview).toMatchObject({
      can_save: false,
      affected_line_count: 0,
      blockers: [{ code: "REVIEW_TARGET_NOT_FOUND" }],
    });
    expect(preview.after.lines).toEqual(preview.before.lines);
  });

  it("previews and saves every allowed scope/action combination in memory", async () => {
    const api = createReviewRecipeAdjustmentApi("ready");

    for (const [index, combination] of combinations.entries()) {
      const payload = proposal(
        combination.scope,
        combination.action,
        index + 1,
      );
      const preview = await api.preview("review-operator", `preview-${index}`, {
        as_of_date: "2026-07-27",
        school_id: "school-1",
        dish_id: "dish-1",
        proposed_adjustment: payload,
      });
      expect(preview.kind).toBe("success");
      if (preview.kind === "success") {
        expect(preview.response.preview).toMatchObject({
          can_save: true,
          affected_line_count: 1,
        });
      }

      const saved = await api.create(command(payload, index + 1));
      expect(saved.kind).toBe("success");
    }

    const readback = await api.getWorkbench("review-operator", "matrix-read");
    expect(readback.kind).toBe("success");
    if (readback.kind === "success") {
      expect(
        (readback.response.workbench as { adjustments: unknown[] }).adjustments,
      ).toHaveLength(22);
    }
  });
});
