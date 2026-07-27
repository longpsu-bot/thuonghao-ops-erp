import { describe, expect, it } from "vitest";
import type { JsonValue } from "../connection/atlasRpc";
import type { RecipeAdjustmentCommandRequest } from "./recipeAdjustmentApi";
import type {
  RecipeAdjustmentAction,
  RecipeAdjustmentScope,
} from "./recipeAdjustmentModel";
import { createReviewRecipeAdjustmentApi } from "./reviewRecipeAdjustmentApi";

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
  return {
    adjustment_id: `adjustment-${index}`,
    revision_id: `revision-${index}`,
    adjustment_line_id: `adjustment-line-${index}`,
    scope_kind: scope,
    action_kind: action,
    school_id: "school-1",
    dish_id: "dish-1",
    target_ingredient_id: "ingredient-1",
    target_recipe_line_id: "recipe-line-1",
    substitute_ingredient_id: "ingredient-2",
    quantity_per_basis: 12.5,
    unit_id: "unit-1",
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
