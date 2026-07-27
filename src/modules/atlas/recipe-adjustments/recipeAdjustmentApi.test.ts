import { describe, expect, it, vi } from "vitest";
import type { AtlasRpcName, AtlasRpcRequest } from "../connection/atlasRpc";
import {
  RECIPE_ADJUSTMENT_RPC_FUNCTIONS,
  createRecipeAdjustmentApi,
  recipeAdjustmentCommandRequest,
  recipeAdjustmentReadRequest,
} from "./recipeAdjustmentApi";

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
      reason_code: "RULE_CORRECTION",
      reason_note: "Điều chỉnh theo biên bản vận hành.",
      payload: { adjustment_id: "adjustment-1" },
    });
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  it("maps the six operator actions to the reviewed RPC registry", async () => {
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
    await api.resolve("subject-1", "read-2", {
      as_of_date: "2026-07-27",
    });
    await api.preview("subject-1", "read-3", {
      as_of_date: "2026-07-27",
    });
    await api.create(command);
    await api.supersede(command);
    await api.cancel(command);

    expect(calls.map(([name]) => name)).toEqual([
      RECIPE_ADJUSTMENT_RPC_FUNCTIONS.getWorkbench,
      RECIPE_ADJUSTMENT_RPC_FUNCTIONS.resolve,
      RECIPE_ADJUSTMENT_RPC_FUNCTIONS.preview,
      RECIPE_ADJUSTMENT_RPC_FUNCTIONS.create,
      RECIPE_ADJUSTMENT_RPC_FUNCTIONS.supersede,
      RECIPE_ADJUSTMENT_RPC_FUNCTIONS.cancel,
    ]);
  });
});
