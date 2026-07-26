import { describe, expect, it, vi } from "vitest";
import type { AtlasRpcRequest, AtlasRpcResult } from "../connection/atlasRpc";
import {
  createMasterDataApi,
  MASTER_DATA_RPC_FUNCTIONS,
  type MasterDataCommandRequest,
} from "./masterDataApi";

const success: AtlasRpcResult = {
  kind: "success",
  response: { success: true },
};

describe("RMVP-01 master-data API adapter", () => {
  it("maps exactly two reads and seven writes to the reviewed RPC registry", () => {
    expect(MASTER_DATA_RPC_FUNCTIONS).toEqual({
      getSchools: "atlas_api.get_school_master_data",
      getIngredientsAndSuppliers:
        "atlas_api.get_ingredient_supplier_master_data",
      updateSchoolDefaults: "atlas_api.update_school_portion_defaults",
      createIngredient: "atlas_api.create_ingredient",
      updateIngredient: "atlas_api.update_ingredient",
      setIngredientLifecycle: "atlas_api.set_ingredient_lifecycle",
      createSupplier: "atlas_api.create_supplier",
      updateSupplier: "atlas_api.update_supplier",
      replacePriorities: "atlas_api.replace_ingredient_supplier_priorities",
    });
  });

  it("builds bounded read envelopes and forwards frozen commands unchanged", async () => {
    const invoke = vi.fn().mockResolvedValue(success);
    const api = createMasterDataApi({ invoke });
    await api.getSchools("subject-1", "correlation-1");
    expect(invoke).toHaveBeenNthCalledWith(
      1,
      "atlas_api.get_school_master_data",
      {
        contract_version: "RMVP-01.v1",
        requested_by_auth_subject: "subject-1",
        correlation_id: "correlation-1",
        payload: {},
      },
    );

    const request = {
      contract_version: "RMVP-01.v1",
      command_id: "command-1",
      correlation_id: "correlation-1",
      idempotency_key: "ingredient:command-1",
      expected_version: 2,
      requested_by_auth_subject: "subject-1",
      requested_at: "2026-07-26T08:00:00.000Z",
      reason_code: "INGREDIENT_UPDATE",
      reason_note: null,
      payload: { ingredient_id: "ingredient-1" },
    } satisfies MasterDataCommandRequest;
    await api.updateIngredient(request);
    expect(invoke).toHaveBeenNthCalledWith(
      2,
      "atlas_api.update_ingredient",
      request,
    );
    expect(invoke.mock.calls[1]?.[1]).toBe(request);
  });

  it("preserves safe transport results for permission, stale, and session handling", async () => {
    const results: AtlasRpcResult[] = [
      {
        kind: "backend_error",
        error: {
          success: false,
          error_code: "CAPABILITY_DENIED",
          safe_message: "Denied.",
        },
      },
      {
        kind: "backend_error",
        error: {
          success: false,
          error_code: "STALE_VERSION",
          safe_message: "Stale.",
          expected_version: 1,
          actual_version: 2,
        },
      },
      {
        kind: "auth_error",
        diagnostic: {
          code: "SESSION_EXPIRED",
          safeMessage: "Expired.",
        },
      },
    ];
    const invoke = vi
      .fn<(name: string, request: AtlasRpcRequest) => Promise<AtlasRpcResult>>()
      .mockResolvedValueOnce(results[0]!)
      .mockResolvedValueOnce(results[1]!)
      .mockResolvedValueOnce(results[2]!);
    const api = createMasterDataApi({
      invoke: invoke as never,
    });
    await expect(api.getSchools("subject-1", "correlation-1")).resolves.toBe(
      results[0],
    );
    await expect(api.getSchools("subject-1", "correlation-1")).resolves.toBe(
      results[1],
    );
    await expect(api.getSchools("subject-1", "correlation-1")).resolves.toBe(
      results[2],
    );
  });
});
