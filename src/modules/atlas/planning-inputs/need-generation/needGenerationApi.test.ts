import { describe, expect, it, vi } from "vitest";
import type { AtlasRpcResult } from "../../connection/atlasRpc";
import {
  confirmedNeedMaterializationRequest,
  createNeedGenerationApi,
  needGenerationCommandRequest,
  needGenerationExecutionRequest,
  needGenerationReadRequest,
} from "./needGenerationApi";

const success: AtlasRpcResult = {
  kind: "success",
  response: { success: true },
};

describe("RMVP-04 API adapter", () => {
  it("builds one daily RMVP-04.v3 generation intent and does not chain v1 lifecycle RPCs", async () => {
    const invoke = vi.fn().mockResolvedValue(success);
    const api = createNeedGenerationApi({ invoke });
    const request = needGenerationExecutionRequest(
      "subject",
      "correlation",
      3,
      "2026-08-03",
      "run-2",
    );

    const result = await api.execute(request);

    expect(request).toMatchObject({
      contract_version: "RMVP-04.v3",
      expected_version: 3,
      reason_code: "NEED_GENERATION_EXECUTED",
      payload: {
        service_date: "2026-08-03",
        expected_current_need_generation_run_id: "run-2",
      },
    });
    expect(result).toBe(success);
    expect(invoke.mock.calls).toEqual([
      ["atlas_api.execute_need_generation", request],
    ]);
  });

  it("builds the exact paged read envelope", () => {
    expect(
      needGenerationReadRequest(
        "subject",
        "correlation",
        "2026-08-03",
        "2026-08-09",
        null,
        {
          service_date: null,
          school_id: "school-1",
          ingredient_id: null,
          contribution_family: "PANTRY_DIRECT",
        },
        100,
        100,
        null,
      ),
    ).toEqual({
      contract_version: "RMVP-04.v1",
      requested_by_auth_subject: "subject",
      correlation_id: "correlation",
      payload: {
        period_start: "2026-08-03",
        period_end: "2026-08-09",
        need_generation_run_id: null,
        filters: {
          service_date: null,
          school_id: "school-1",
          ingredient_id: null,
          contribution_family: "PANTRY_DIRECT",
        },
        group_offset: 100,
        group_limit: 100,
      },
    });
  });

  it("keeps generation inputs source-free and preserves one exact retry object", async () => {
    const invoke = vi.fn().mockResolvedValue(success);
    const api = createNeedGenerationApi({ invoke });
    const request = needGenerationCommandRequest(
      "subject",
      "correlation",
      4,
      "NEED_GENERATION_CREATED",
      null,
      {
        planning_input_set_id: "set-1",
        planning_input_evaluation_id: "evaluation-1",
        period_start: "2026-08-03",
        period_end: "2026-08-09",
      },
    );
    expect(request.payload).not.toHaveProperty("weekly_menu_id");
    expect(request.payload).not.toHaveProperty("quantity");
    await api.create(request);
    await api.create(request);
    expect(invoke.mock.calls[0]?.[1]).toBe(request);
    expect(invoke.mock.calls[1]?.[1]).toBe(request);
  });

  it("routes the five RMVP-04 APIs and existing CMD-15 without inventing a materializer", async () => {
    const invoke = vi.fn().mockResolvedValue(success);
    const api = createNeedGenerationApi({ invoke });
    const command = needGenerationCommandRequest(
      "subject",
      "correlation",
      1,
      "NEED_GENERATION_VALIDATED",
      null,
      { need_generation_run_id: "run-1" },
    );
    await api.getWorkbench(
      "subject",
      "correlation",
      "2026-08-03",
      "2026-08-09",
      null,
      {
        service_date: null,
        school_id: null,
        ingredient_id: null,
        contribution_family: null,
      },
      0,
      100,
      null,
    );
    await api.create(command);
    await api.validate(command);
    await api.release(command);
    await api.invalidate(command);
    const materialize = confirmedNeedMaterializationRequest(
      "subject",
      "correlation",
      1,
      "run-1",
      3,
      null,
    );
    await api.materialize(materialize);
    expect(invoke.mock.calls.map(([name]) => name)).toEqual([
      "atlas_api.get_need_generation_workbench",
      "atlas_api.create_need_generation_run",
      "atlas_api.validate_need_generation_run",
      "atlas_api.release_need_generation_run",
      "atlas_api.invalidate_need_generation_run",
      "atlas_api.create_confirmed_needs_from_generation",
    ]);
    expect(materialize.contract_version).toBe("PA-06E-H0C.v1");
  });
});
