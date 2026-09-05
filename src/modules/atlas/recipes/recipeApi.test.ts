import { describe, expect, it, vi } from "vitest";
import type { AtlasRpcName, AtlasRpcRequest } from "../connection/atlasRpc";
import {
  RECIPE_RPC_FUNCTIONS,
  createRecipeApi,
  dishRecipeCopyRequest,
  dishRecipeOperatorRequest,
  recipeCommandRequest,
  recipeReadRequest,
  recipeWorkflowCommandRequest,
} from "./recipeApi";

describe("recipe API contract", () => {
  it("builds the bounded RMVP-02A read envelope", () => {
    expect(recipeReadRequest("subject-1", "correlation-1")).toEqual({
      contract_version: "RMVP-02A.v2",
      requested_by_auth_subject: "subject-1",
      correlation_id: "correlation-1",
      payload: {},
    });
  });

  it("builds the two human-level RMVP-02A.v2 command envelopes", () => {
    vi.spyOn(crypto, "randomUUID").mockReturnValue(
      "10000000-0000-4000-8000-000000000002",
    );
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2026-08-11T02:00:00.000Z"));

    expect(
      recipeWorkflowCommandRequest("subject-1", "correlation-1", 3, "save", {
        dish_id: "dish-1",
        lines: [],
      }),
    ).toMatchObject({
      contract_version: "RMVP-02A.v2",
      expected_version: 3,
      reason_code: "RECIPE_SAVED",
      reason_note: null,
    });
    expect(
      recipeWorkflowCommandRequest("subject-1", "correlation-1", 4, "release", {
        recipe_version_id: "version-1",
      }),
    ).toMatchObject({
      contract_version: "RMVP-02A.v2",
      expected_version: 4,
      reason_code: "RECIPE_PUT_INTO_USE",
      reason_note: null,
    });

    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  it("builds a unique, versioned command envelope", () => {
    vi.spyOn(crypto, "randomUUID").mockReturnValue(
      "10000000-0000-4000-8000-000000000001",
    );
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2026-07-27T02:00:00.000Z"));

    expect(
      recipeCommandRequest("subject-1", "correlation-1", 4, "SAVE_BOM", {
        recipe_version_id: "version-1",
        lines: [],
      }),
    ).toMatchObject({
      contract_version: "RMVP-02A.v1",
      command_id: "10000000-0000-4000-8000-000000000001",
      correlation_id: "correlation-1",
      idempotency_key: "save_bom:10000000-0000-4000-8000-000000000001",
      expected_version: 4,
      requested_by_auth_subject: "subject-1",
      requested_at: "2026-07-27T02:00:00.000Z",
      reason_code: "SAVE_BOM",
      payload: {
        recipe_version_id: "version-1",
        lines: [],
      },
    });

    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  it("maps every public recipe method to exactly one reviewed RPC", async () => {
    const calls: Array<[AtlasRpcName, AtlasRpcRequest]> = [];
    const api = createRecipeApi({
      invoke: vi.fn(async (name, request) => {
        calls.push([name, request]);
        return {
          kind: "success" as const,
          response: { success: true as const },
        };
      }),
    });
    const command = recipeCommandRequest(
      "subject-1",
      "correlation-1",
      1,
      "TEST",
      {},
    );

    await api.getWorkbench("subject-1", "correlation-read");
    await api.createDish(command);
    await api.updateDish(command);
    await api.setDishLifecycle(command);
    await api.setRecipeLifecycle(command);
    await api.createDraft(command);
    await api.createSuccessor(command);
    await api.replaceComposition(command);
    await api.validateVersion(command);
    await api.releaseVersion(command);
    const workflowCommand = recipeWorkflowCommandRequest(
      "subject-1",
      "correlation-1",
      1,
      "save",
      {},
    );
    await api.saveRecipe(workflowCommand);
    await api.releaseRecipe({
      ...workflowCommand,
      reason_code: "RECIPE_PUT_INTO_USE",
    });
    await api.copyVersion(command);
    await api.applyImport(command);

    expect(calls.map(([name]) => name)).toEqual([
      RECIPE_RPC_FUNCTIONS.getWorkbench,
      RECIPE_RPC_FUNCTIONS.createDish,
      RECIPE_RPC_FUNCTIONS.updateDish,
      RECIPE_RPC_FUNCTIONS.setDishLifecycle,
      RECIPE_RPC_FUNCTIONS.setRecipeLifecycle,
      RECIPE_RPC_FUNCTIONS.createDraft,
      RECIPE_RPC_FUNCTIONS.createSuccessor,
      RECIPE_RPC_FUNCTIONS.replaceComposition,
      RECIPE_RPC_FUNCTIONS.validateVersion,
      RECIPE_RPC_FUNCTIONS.releaseVersion,
      RECIPE_RPC_FUNCTIONS.saveRecipe,
      RECIPE_RPC_FUNCTIONS.releaseRecipe,
      RECIPE_RPC_FUNCTIONS.copyVersion,
      RECIPE_RPC_FUNCTIONS.applyImport,
    ]);
  });

  it("builds effective operator reads for exactly one context", () => {
    expect(
      dishRecipeOperatorRequest(
        "subject-1",
        "operator-1",
        "2026-09-05",
        "dish-1",
        { kind: "system", schoolTypeId: "school-type-1" },
      ),
    ).toEqual({
      contract_version: "RECIPE-EFFECTIVE.v1",
      requested_by_auth_subject: "subject-1",
      correlation_id: "operator-1",
      payload: {
        as_of_date: "2026-09-05",
        dish_id: "dish-1",
        school_type_id: "school-type-1",
      },
    });
  });

  it("preserves caller-supplied Dish-copy replay identities", () => {
    expect(
      dishRecipeCopyRequest({
        authSubject: "subject-1",
        correlationId: "copy-correlation",
        commandId: "10000000-0000-4000-8000-000000000010",
        idempotencyKey: "copy-dish:stable-key",
        requestedAt: "2026-09-05T02:00:00.000Z",
        expectedVersion: 4,
        reasonCode: "COPY_DISH_RECIPES",
        reasonNote: "Sao chép công thức đã xác nhận.",
        sourceDishId: "dish-source",
        targetDishId: "dish-target",
      }),
    ).toEqual({
      contract_version: "RECIPE-EFFECTIVE.v1",
      command_id: "10000000-0000-4000-8000-000000000010",
      correlation_id: "copy-correlation",
      idempotency_key: "copy-dish:stable-key",
      expected_version: 4,
      requested_by_auth_subject: "subject-1",
      requested_at: "2026-09-05T02:00:00.000Z",
      reason_code: "COPY_DISH_RECIPES",
      reason_note: "Sao chép công thức đã xác nhận.",
      payload: {
        source_dish_id: "dish-source",
        target_dish_id: "dish-target",
      },
    });
  });

  it("maps effective operator and Dish-copy calls to reviewed RPCs", async () => {
    const calls: Array<[AtlasRpcName, AtlasRpcRequest]> = [];
    const api = createRecipeApi({
      invoke: vi.fn(async (name, request) => {
        calls.push([name, request]);
        return {
          kind: "success" as const,
          response: { success: true as const },
        };
      }),
    });
    const copyRequest = dishRecipeCopyRequest({
      authSubject: "subject-1",
      correlationId: "copy-correlation",
      commandId: "10000000-0000-4000-8000-000000000010",
      idempotencyKey: "copy-dish:stable-key",
      requestedAt: "2026-09-05T02:00:00.000Z",
      expectedVersion: 4,
      reasonCode: "COPY_DISH_RECIPES",
      reasonNote: "Sao chép công thức đã xác nhận.",
      sourceDishId: "dish-source",
      targetDishId: "dish-target",
    });

    await api.getEffectiveWorkbench(
      "subject-1",
      "operator-1",
      "2026-09-05",
      "dish-1",
      { kind: "school", schoolId: "school-1" },
    );
    await api.copyDishRecipes(copyRequest);

    expect(calls.map(([name]) => name)).toEqual([
      RECIPE_RPC_FUNCTIONS.getEffectiveWorkbench,
      RECIPE_RPC_FUNCTIONS.copyDishRecipes,
    ]);
    expect(calls[1]?.[1]).toBe(copyRequest);
  });
});
