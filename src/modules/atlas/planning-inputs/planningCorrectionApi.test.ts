import { describe, expect, it, vi } from "vitest";
import type { AtlasRpcResult } from "../connection/atlasRpc";
import {
  createPlanningCorrectionApi,
  planningCorrectionImpactFromResult,
  safeNoDownstreamImpact,
  type PlanningCorrectionChain,
} from "./planningCorrectionApi";

const success: AtlasRpcResult = {
  kind: "success",
  response: { success: true },
};

const chain: PlanningCorrectionChain = {
  need_generation_run_id: "run-1",
  need_generation_run_version: 3,
  run_status: "RELEASED_FOR_CONFIRMATION",
  period_start: "2026-08-17",
  period_end: "2026-08-17",
  is_legacy_range: false,
  confirmed_need_batch_id: "batch-1",
  confirmed_need_batch_version: 5,
  confirmed_need_status: "RELEASED_FOR_PURCHASE_HANDOFF",
  planning_release_occurred: true,
  active_purchase_handoff_exists: false,
  later_downstream_commitment_exists: false,
};

describe("PLANNING-CORRECTION.v1 adapter", () => {
  it("routes the one impact read with exact proposed source facts", async () => {
    const invoke = vi.fn().mockResolvedValue(success);
    const api = createPlanningCorrectionApi({ invoke });

    await api.impact("subject", "correlation", "ATTENDANCE", {
      week_start: "2026-08-17",
      rows: [{ service_date: "2026-08-17", student_portions: 101 }],
    });

    expect(invoke).toHaveBeenCalledWith(
      "atlas_api.get_planning_source_correction_impact",
      {
        contract_version: "PLANNING-CORRECTION.v1",
        requested_by_auth_subject: "subject",
        correlation_id: "correlation",
        payload: {
          source_kind: "ATTENDANCE",
          source_payload: {
            week_start: "2026-08-17",
            rows: [{ service_date: "2026-08-17", student_portions: 101 }],
          },
        },
      },
    );
  });

  it("routes one reasoned, version-bound correction command", async () => {
    const invoke = vi.fn().mockResolvedValue(success);
    const api = createPlanningCorrectionApi({ invoke });

    await api.prepare("subject", "correlation", chain, "Mở lại để sửa nguồn.");

    const [name, request] = invoke.mock.calls[0] ?? [];
    expect(name).toBe("atlas_api.prepare_planning_source_correction");
    expect(request).toMatchObject({
      contract_version: "PLANNING-CORRECTION.v1",
      correlation_id: "correlation",
      expected_version: 3,
      requested_by_auth_subject: "subject",
      reason_code: "PLANNING_SOURCE_CORRECTION_PREPARED",
      reason_note: "Mở lại để sửa nguồn.",
      payload: {
        need_generation_run_id: "run-1",
        confirmed_need_batch_id: "batch-1",
        expected_confirmed_need_batch_version: 5,
      },
    });
    expect(request.command_id).toBeTruthy();
    expect(request.idempotency_key).toContain("planning-correction:");
  });

  it("parses only a bounded successful impact and has an explicit safe fallback", () => {
    const impact = safeNoDownstreamImpact("PANTRY");
    expect(impact).toEqual({
      source_kind: "PANTRY",
      material_change: false,
      affected_service_dates: [],
      date_impacts: [],
      save_allowed: true,
      save_blocker_code: null,
    });
    expect(
      planningCorrectionImpactFromResult({
        kind: "success",
        response: { success: true, impact },
      }),
    ).toEqual(impact);
    expect(
      planningCorrectionImpactFromResult({
        kind: "success",
        response: { success: true, impact: { save_allowed: true } },
      }),
    ).toBeNull();
  });
});
