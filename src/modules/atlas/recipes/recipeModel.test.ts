import { describe, expect, it } from "vitest";
import {
  dishRecipeCopyFromResult,
  dishRecipeOperatorWorkbenchFromResult,
  emptyRecipeWorkbench,
  recipeWorkbenchFromResult,
} from "./recipeModel";

describe("recipe workbench response parsing", () => {
  it("reads the authoritative nested workbench envelope", () => {
    const workbench = emptyRecipeWorkbench();
    expect(
      recipeWorkbenchFromResult({
        kind: "success",
        response: {
          success: true,
          workbench,
        },
      }),
    ).toEqual(workbench);
  });

  it("fails closed when a required collection is missing", () => {
    expect(
      recipeWorkbenchFromResult({
        kind: "success",
        response: {
          success: true,
          workbench: {
            dishes: [],
          },
        },
      }),
    ).toBeNull();
  });

  it("parses a guarded effective Dish Recipe operator workbench", () => {
    const workbench = {
      dish: {
        dish_id: "dish-1",
        dish_name: "Canh rau",
        dish_type_name: "Canh",
        dish_status: "ACTIVE",
      },
      context_kind: "SYSTEM_SCHOOL_TYPE",
      as_of_date: "2026-09-05",
      school_id: null,
      school_type_id: "school-type-1",
      selected_recipe: {
        dish_id: "dish-1",
        recipe_id: "recipe-1",
        recipe_version_id: "recipe-version-1",
        selection_scope: "GENERAL",
        basis_portions: 100,
      },
      basis_portions: 100,
      editable_state: "LOCKED_RELEASED",
      is_editable: false,
      is_operationally_locked: true,
      current_effective_bom: [],
      school_exception_count: 2,
      allowed_actions: ["CREATE_CHANGE_ORDER"],
      blockers: [],
      warnings: [],
      history_periods: [],
    };

    expect(
      dishRecipeOperatorWorkbenchFromResult({
        kind: "success",
        response: { success: true, workbench },
      }),
    ).toEqual(workbench);
    expect(
      dishRecipeOperatorWorkbenchFromResult({
        kind: "success",
        response: {
          success: true,
          workbench: { ...workbench, history_periods: null },
        },
      }),
    ).toBeNull();
  });

  it("parses Dish-copy results and rejects malformed scope rows", () => {
    const result = {
      success: true as const,
      contract_version: "RECIPE-EFFECTIVE.v1",
      command_id: "command-1",
      correlation_id: "correlation-1",
      idempotency_status: "COMPLETED",
      scope_results: [
        {
          school_type_id: "school-type-1",
          scope_name: "Tiểu học",
          status: "COPIED",
          source_recipe_id: "source-recipe-1",
          source_recipe_version_id: "source-version-1",
          source_selection_scope: "GENERAL",
          target_recipe_id: "target-recipe-1",
          target_recipe_version_id: "target-version-1",
        },
      ],
    };
    expect(
      dishRecipeCopyFromResult({ kind: "success", response: result }),
    ).toEqual(result);
    expect(
      dishRecipeCopyFromResult({
        kind: "success",
        response: { ...result, scope_results: [{ status: 1 }] },
      }),
    ).toBeNull();
  });
});
