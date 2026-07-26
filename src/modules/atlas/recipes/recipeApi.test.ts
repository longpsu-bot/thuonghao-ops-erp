import { describe, expect, it, vi } from "vitest";
import type { AtlasRpcName, AtlasRpcRequest } from "../connection/atlasRpc";
import {
  RECIPE_RPC_FUNCTIONS,
  createRecipeApi,
  recipeCommandRequest,
  recipeReadRequest,
} from "./recipeApi";

describe("recipe API contract", () => {
  it("builds the bounded RMVP-02A read envelope", () => {
    expect(recipeReadRequest("subject-1", "correlation-1")).toEqual({
      contract_version: "RMVP-02A.v1",
      requested_by_auth_subject: "subject-1",
      correlation_id: "correlation-1",
      payload: {},
    });
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
      RECIPE_RPC_FUNCTIONS.copyVersion,
      RECIPE_RPC_FUNCTIONS.applyImport,
    ]);
  });
});
