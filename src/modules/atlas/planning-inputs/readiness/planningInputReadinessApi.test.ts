import { describe, expect, it, vi } from "vitest";
import type { AtlasRpcResult } from "../../connection/atlasRpc";
import {
  createPlanningInputReadinessApi,
  planningInputReadinessCommandRequest,
  planningInputReadinessReadRequest,
} from "./planningInputReadinessApi";

const success: AtlasRpcResult = {
  kind: "success",
  response: { success: true },
};

describe("RMVP-03B API adapter", () => {
  it("builds the exact read envelope without decoding the history cursor", () => {
    const selection = {
      weekly_menu: {
        weekly_menu_id: "menu-1",
        weekly_menu_version: 2,
        weekly_menu_approval_snapshot_id: "snapshot-1",
      },
      attendance: null,
      pantry: null,
    };
    expect(
      planningInputReadinessReadRequest(
        "subject-1",
        "correlation-1",
        "2026-08-03",
        "2026-08-09",
        selection,
        17,
        "opaque-backend-value==",
      ),
    ).toEqual({
      contract_version: "RMVP-03B.v1",
      requested_by_auth_subject: "subject-1",
      correlation_id: "correlation-1",
      payload: {
        period_start: "2026-08-03",
        period_end: "2026-08-09",
        source_selection: selection,
        history_limit: 17,
        history_cursor: "opaque-backend-value==",
      },
    });
  });

  it("builds exact absent-root and existing-root command expectations", () => {
    expect(
      planningInputReadinessCommandRequest(
        "subject-1",
        "correlation-1",
        {
          expectedRootStatus: "ABSENT",
          expectedCurrentEvaluationId: null,
          expectedCurrentEvaluationVersion: null,
        },
        "READINESS_EVALUATION_REQUESTED",
        null,
        {
          period_start: "2026-08-03",
          period_end: "2026-08-09",
          source_candidates: {
            weekly_menu: null,
            attendance: null,
            pantry: null,
          },
        },
      ),
    ).toMatchObject({
      contract_version: "RMVP-03B.v1",
      requested_by_auth_subject: "subject-1",
      expected_root_status: "ABSENT",
      expected_current_evaluation_id: null,
      expected_current_evaluation_version: null,
      reason_code: "READINESS_EVALUATION_REQUESTED",
      reason_note: null,
    });
  });

  it("routes exactly the four reviewed APIs and preserves an exact retry request", async () => {
    const invoke = vi.fn().mockResolvedValue(success);
    const api = createPlanningInputReadinessApi({ invoke });
    await api.getWorkbench(
      "subject",
      "correlation",
      "2026-08-03",
      "2026-08-09",
    );
    const command = planningInputReadinessCommandRequest(
      "subject",
      "correlation",
      {
        expectedRootStatus: "READY",
        expectedCurrentEvaluationId: "evaluation-1",
        expectedCurrentEvaluationVersion: 3,
      },
      "PLANNING_REVIEW_CORRECTION",
      "Cần đánh giá lại.",
      {
        planning_input_set_id: "set-1",
        period_start: "2026-08-03",
        period_end: "2026-08-09",
      },
    );
    await api.evaluate(command);
    await api.requestNeedGeneration(command);
    await api.invalidate(command);
    await api.invalidate(command);

    expect(invoke.mock.calls.map(([name]) => name)).toEqual([
      "atlas_api.get_planning_input_readiness_workbench",
      "atlas_api.evaluate_planning_input_readiness",
      "atlas_api.request_planning_input_need_generation",
      "atlas_api.invalidate_planning_input_readiness",
      "atlas_api.invalidate_planning_input_readiness",
    ]);
    expect(invoke.mock.calls[3]?.[1]).toBe(command);
    expect(invoke.mock.calls[4]?.[1]).toBe(command);
  });

  it("keeps the Need Generation handoff payload source-free", () => {
    const request = planningInputReadinessCommandRequest(
      "subject",
      "correlation",
      {
        expectedRootStatus: "READY",
        expectedCurrentEvaluationId: "evaluation-1",
        expectedCurrentEvaluationVersion: 1,
      },
      "NEED_GENERATION_HANDOFF_REQUESTED",
      null,
      {
        planning_input_set_id: "set-1",
        period_start: "2026-08-03",
        period_end: "2026-08-09",
      },
    );
    expect(request.payload).toEqual({
      planning_input_set_id: "set-1",
      period_start: "2026-08-03",
      period_end: "2026-08-09",
    });
    expect(request.payload).not.toHaveProperty("source_candidates");
    expect(request.payload).not.toHaveProperty("source_selection");
  });
});
