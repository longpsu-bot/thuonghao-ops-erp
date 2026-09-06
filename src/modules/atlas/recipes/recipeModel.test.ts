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
        selection_scope: "SCHOOL_TYPE",
        basis_portions: 100,
      },
      basis_portions: 100,
      base_authoring: {
        dish_id: "dish-1",
        school_type_id: "school-type-1",
        recipe_id: "recipe-1",
        recipe_version_id: "recipe-version-1",
        expected_version: 1,
        in_use_recipe_version_id: "recipe-version-1",
        business_status: "LOCKED",
        locked_for_normal_editing: true,
        lock_reason: "Approved Menu evidence exists.",
        basis_portions: 100,
        composition: [],
        allowed_actions: { save_recipe: false, release_recipe: false },
        disabled_reason_codes: {
          save_recipe: "SAVE_OPERATIONALLY_LOCKED",
          release_recipe: "RELEASE_ALREADY_IN_USE",
        },
        disabled_reasons: {
          save_recipe: "Use a Change Order.",
          release_recipe: "Already released.",
        },
      },
      effective_readiness: { status: "READY", blockers: [], warnings: [] },
      editable_state: "LOCKED_CHANGE_ORDER",
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

  it("parses root-only editable base authoring before effective readiness", () => {
    const workbench = {
      dish: {
        dish_id: "dish-new",
        dish_name: "Canh mới",
        dish_type_name: "Canh",
        dish_status: "ACTIVE",
      },
      context_kind: "SYSTEM_SCHOOL_TYPE",
      as_of_date: "2026-09-05",
      school_id: null,
      school_type_id: "school-type-1",
      selected_recipe: null,
      basis_portions: 100,
      base_authoring: {
        dish_id: "dish-new",
        school_type_id: "school-type-1",
        recipe_id: "recipe-new",
        recipe_version_id: null,
        expected_version: 1,
        in_use_recipe_version_id: null,
        business_status: "NOT_SAVED",
        locked_for_normal_editing: false,
        lock_reason: null,
        basis_portions: 100,
        composition: [],
        allowed_actions: { save_recipe: true, release_recipe: false },
        disabled_reason_codes: {
          save_recipe: null,
          release_recipe: "RELEASE_SAVE_REQUIRED",
        },
        disabled_reasons: {
          save_recipe: null,
          release_recipe: "Save first.",
        },
      },
      effective_readiness: {
        status: "BLOCKED",
        blockers: [
          { code: "RECIPE_SELECTION_BLOCKED", message: "No release." },
        ],
        warnings: [],
      },
      editable_state: "EDITABLE_BASE",
      is_editable: true,
      is_operationally_locked: false,
      current_effective_bom: [],
      school_exception_count: 0,
      allowed_actions: ["COPY_DISH_RECIPES"],
      blockers: [{ code: "RECIPE_SELECTION_BLOCKED", message: "No release." }],
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
          workbench: { ...workbench, is_editable: false },
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
          school_type_code: "v1-school-type-1",
          scope_name: "Tiểu học",
          status: "COPIED",
          source_recipe_id: "source-recipe-1",
          source_recipe_version_id: "source-version-1",
          source_selection_scope: "SCHOOL_TYPE",
          target_recipe_id: "target-recipe-1",
          target_recipe_version_id: "target-version-1",
        },
        {
          school_type_id: "school-type-2",
          school_type_code: "v1-school-type-2",
          scope_name: "Trung học",
          status: "COPIED",
          source_recipe_id: "source-recipe-2",
          source_recipe_version_id: "source-version-2",
          source_selection_scope: "SCHOOL_TYPE",
          target_recipe_id: "target-recipe-2",
          target_recipe_version_id: "target-version-2",
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
    expect(
      dishRecipeCopyFromResult({
        kind: "success",
        response: {
          ...result,
          scope_results: [
            {
              ...result.scope_results[0],
              status: "SOURCE_NOT_AVAILABLE",
            },
          ],
        },
      }),
    ).toBeNull();
  });
});
