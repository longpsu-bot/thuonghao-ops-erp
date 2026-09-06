import { describe, expect, it, vi } from "vitest";
import type { AtlasRpcName, AtlasRpcRequest } from "../connection/atlasRpc";
import {
  RECIPE_ADJUSTMENT_RPC_FUNCTIONS,
  createRecipeAdjustmentApi,
  recipeAdjustmentCommandRequest,
  recipeEffectiveTargetContextRequest,
  recipeAdjustmentOperatorReadRequest,
  recipeAdjustmentReadRequest,
  systemEffectiveRecipeRequest,
} from "./recipeAdjustmentApi";
import {
  adjustmentPreviewFromResult,
  adjustmentWorkbenchFromResult,
  effectiveTargetContextFromResult,
} from "./recipeAdjustmentModel";
import { createReviewRecipeAdjustmentApi } from "./reviewRecipeAdjustmentApi";

describe("Recipe adjustment API contract", () => {
  it("builds explicit RMVP-02B read and command envelopes", () => {
    expect(
      recipeAdjustmentReadRequest("subject-1", "correlation-1", {
        as_of_date: "2026-07-27",
      }),
    ).toEqual({
      contract_version: "RMVP-02B.v1",
      requested_by_auth_subject: "subject-1",
      correlation_id: "correlation-1",
      payload: { as_of_date: "2026-07-27" },
    });
    expect(
      recipeAdjustmentOperatorReadRequest(
        "subject-1",
        "correlation-2",
        "2026-08-14",
      ),
    ).toEqual({
      contract_version: "RMVP-02B.v2",
      requested_by_auth_subject: "subject-1",
      correlation_id: "correlation-2",
      payload: { as_of_date: "2026-08-14" },
    });

    vi.spyOn(crypto, "randomUUID").mockReturnValue(
      "10000000-0000-4000-8000-000000000001",
    );
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2026-07-27T02:00:00.000Z"));
    expect(
      recipeAdjustmentCommandRequest(
        "subject-1",
        "correlation-1",
        3,
        "RULE_CORRECTION",
        "Điều chỉnh theo biên bản vận hành.",
        { adjustment_id: "adjustment-1" },
      ),
    ).toMatchObject({
      contract_version: "RMVP-02B.v1",
      command_id: "10000000-0000-4000-8000-000000000001",
      idempotency_key: "rule_correction:10000000-0000-4000-8000-000000000001",
      expected_version: 3,
      requested_at: "2026-07-27T02:00:00.000Z",
      reason_code: "RULE_CORRECTION",
      reason_note: "Điều chỉnh theo biên bản vận hành.",
      payload: { adjustment_id: "adjustment-1" },
    });
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  it("keeps all six v1 APIs and adds one bounded v2 operator read", async () => {
    const calls: Array<[AtlasRpcName, AtlasRpcRequest]> = [];
    const api = createRecipeAdjustmentApi({
      invoke: vi.fn(async (name, request) => {
        calls.push([name, request]);
        return {
          kind: "success" as const,
          response: { success: true as const },
        };
      }),
    });
    const command = recipeAdjustmentCommandRequest(
      "subject-1",
      "correlation-1",
      1,
      "TEST",
      "Kiểm tra hợp đồng.",
      {},
    );
    await api.getWorkbench("subject-1", "read-1");
    await api.getOperatorWorkbench("subject-1", "read-operator", "2026-08-14");
    await api.resolve("subject-1", "read-2", {
      as_of_date: "2026-07-27",
    });
    await api.preview("subject-1", "read-3", {
      as_of_date: "2026-07-27",
    });
    await api.create(command);
    await api.supersede(command);
    await api.cancel(command);

    for (const [, request] of calls.slice(-3)) {
      expect(request).toBe(command);
    }

    expect(calls.map(([name]) => name)).toEqual([
      RECIPE_ADJUSTMENT_RPC_FUNCTIONS.getWorkbench,
      RECIPE_ADJUSTMENT_RPC_FUNCTIONS.getOperatorWorkbench,
      RECIPE_ADJUSTMENT_RPC_FUNCTIONS.resolve,
      RECIPE_ADJUSTMENT_RPC_FUNCTIONS.preview,
      RECIPE_ADJUSTMENT_RPC_FUNCTIONS.create,
      RECIPE_ADJUSTMENT_RPC_FUNCTIONS.supersede,
      RECIPE_ADJUSTMENT_RPC_FUNCTIONS.cancel,
    ]);
  });

  it("builds explicit RECIPE-EFFECTIVE system and target-context reads", () => {
    expect(
      systemEffectiveRecipeRequest(
        "subject-1",
        "correlation-system",
        "2026-09-05",
        "dish-1",
        "school-type-1",
      ),
    ).toEqual({
      contract_version: "RECIPE-EFFECTIVE.v1",
      requested_by_auth_subject: "subject-1",
      correlation_id: "correlation-system",
      payload: {
        as_of_date: "2026-09-05",
        dish_id: "dish-1",
        school_type_id: "school-type-1",
      },
    });

    expect(
      recipeEffectiveTargetContextRequest(
        "subject-1",
        "correlation-school",
        "2026-09-05",
        "dish-1",
        { kind: "school", schoolId: "school-1" },
      ),
    ).toEqual({
      contract_version: "RECIPE-EFFECTIVE.v1",
      requested_by_auth_subject: "subject-1",
      correlation_id: "correlation-school",
      payload: {
        as_of_date: "2026-09-05",
        dish_id: "dish-1",
        school_id: "school-1",
      },
    });
  });

  it("maps effective reads to their reviewed RPCs", async () => {
    const calls: Array<[AtlasRpcName, AtlasRpcRequest]> = [];
    const api = createRecipeAdjustmentApi({
      invoke: vi.fn(async (name, request) => {
        calls.push([name, request]);
        return {
          kind: "success" as const,
          response: { success: true as const },
        };
      }),
    });

    await api.resolveSystem(
      "subject-1",
      "system-read",
      "2026-09-05",
      "dish-1",
      "school-type-1",
    );
    await api.getEffectiveTargetContext(
      "subject-1",
      "target-read",
      "2026-09-05",
      "dish-1",
      { kind: "system", schoolTypeId: "school-type-1" },
    );

    expect(calls.map(([name]) => name)).toEqual([
      RECIPE_ADJUSTMENT_RPC_FUNCTIONS.resolveSystem,
      RECIPE_ADJUSTMENT_RPC_FUNCTIONS.getEffectiveTargetContext,
    ]);
  });

  it("parses target rows only when exact context and stable target XOR are shaped", () => {
    const targetContext = {
      as_of_date: "2026-09-05",
      dish_id: "dish-1",
      school_id: null,
      school_type_id: "school-type-1",
      selected_recipe: {
        dish_id: "dish-1",
        recipe_id: "recipe-1",
        recipe_version_id: "version-1",
        selection_scope: "SCHOOL_TYPE",
        basis_portions: 100,
      },
      basis_portions: 100,
      effective_lines: [
        {
          ingredient_id: "ingredient-base",
          ingredient_name: "Thịt heo hiệu lực",
          quantity_per_basis: 8,
          unit_id: "unit-1",
          unit_name: "kg",
          target_kind: "RECIPE_LINE",
          target_recipe_line_id: "recipe-line-1",
          adjustment_line_id: null,
          target_id: "recipe-line-1",
          source_layer: "RELEASED_RECIPE_VERSION",
        },
        {
          ingredient_id: "ingredient-1",
          ingredient_name: "Hành lá",
          quantity_per_basis: 2,
          unit_id: "unit-1",
          unit_name: "kg",
          target_kind: "ADJUSTMENT_LINE",
          target_recipe_line_id: null,
          adjustment_line_id: "adjustment-line-1",
          target_id: "adjustment-line-1",
          source_layer: "SYSTEM_DISH",
        },
      ],
      warnings: [],
      blockers: [],
    };

    expect(
      effectiveTargetContextFromResult({
        kind: "success",
        response: { success: true, target_context: targetContext },
      }),
    ).toEqual(targetContext);
    expect(
      effectiveTargetContextFromResult({
        kind: "success",
        response: {
          success: true,
          target_context: { ...targetContext, effective_lines: [{}] },
        },
      }),
    ).toBeNull();

    for (const malformedLine of [
      {
        ...targetContext.effective_lines[0],
        adjustment_line_id: "adjustment-line-conflict",
      },
      {
        ...targetContext.effective_lines[1],
        target_recipe_line_id: "recipe-line-conflict",
      },
      {
        ...targetContext.effective_lines[1],
        target_id: "wrong-target-id",
      },
    ]) {
      expect(
        effectiveTargetContextFromResult({
          kind: "success",
          response: {
            success: true,
            target_context: {
              ...targetContext,
              effective_lines: [malformedLine],
            },
          },
        }),
      ).toBeNull();
    }

    expect(
      effectiveTargetContextFromResult({
        kind: "success",
        response: {
          success: true,
          target_context: {
            ...targetContext,
            school_id: "school-1",
            school_type_id: null,
          },
        },
      }),
    ).toBeNull();
    expect(
      effectiveTargetContextFromResult({
        kind: "success",
        response: {
          success: true,
          target_context: {
            ...targetContext,
            selected_recipe: { recipe_id: "partial" },
          },
        },
      }),
    ).toBeNull();
  });

  it("rejects malformed previews instead of authorizing a write", () => {
    const composition = {
      status: "READY",
      as_of_date: "2026-09-05",
      school_id: "school-1",
      dish_id: "dish-1",
      historical: false,
      selected_recipe: {
        dish_id: "dish-1",
        recipe_id: "recipe-1",
        recipe_version_id: "version-1",
        selection_scope: "SCHOOL_TYPE",
        basis_portions: 100,
      },
      lines: [],
      warnings: [],
      blockers: [],
    };
    const preview = {
      as_of_date: "2026-09-05",
      school_id: "school-1",
      dish_id: "dish-1",
      proposed_adjustment: {
        scope_kind: "SCHOOL_DISH",
        action_kind: "REMOVE",
      },
      before: composition,
      after: composition,
      affected_line_count: 1,
      can_save: true,
      warnings: [],
      blockers: [],
    };

    expect(
      adjustmentPreviewFromResult({
        kind: "success",
        response: { success: true, preview },
      }),
    ).toEqual(preview);
    expect(
      adjustmentPreviewFromResult({
        kind: "success",
        response: {
          success: true,
          preview: { ...preview, can_save: "yes" },
        },
      }),
    ).toBeNull();
    expect(
      adjustmentPreviewFromResult({
        kind: "success",
        response: {
          success: true,
          preview: {
            ...preview,
            before: { ...composition, lines: [{}] },
          },
        },
      }),
    ).toBeNull();
  });

  it("accepts nullable legacy issuance and rejects malformed temporal authority", async () => {
    const result = await createReviewRecipeAdjustmentApi(
      "ready",
    ).getOperatorWorkbench("subject-1", "correlation-1", "2026-09-05");
    const parsed = adjustmentWorkbenchFromResult(result);

    expect(parsed).not.toBeNull();
    expect(parsed?.operator_rows[0]?.display_revision).toMatchObject({
      issuance_kind: "LEGACY_UNATTRIBUTED",
      issued_at: null,
      issued_by_actor_name: null,
    });

    if (result.kind !== "success") throw new Error("Expected review fixture");
    const workbench = structuredClone(result.response.workbench) as Record<
      string,
      unknown
    >;
    const rows = workbench.operator_rows as Array<Record<string, unknown>>;
    rows[0] = { ...rows[0], is_effective_now: "yes" };
    expect(
      adjustmentWorkbenchFromResult({
        kind: "success",
        response: { success: true, workbench } as never,
      }),
    ).toBeNull();
  });
});
