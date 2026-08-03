import { describe, expect, it, vi } from "vitest";
import type { AtlasRpcResult } from "../../connection/atlasRpc";
import {
  confirmedNeedCommandRequest,
  confirmedNeedPreviewRequest,
  confirmedNeedReadRequest,
  createConfirmedNeedApi,
} from "./confirmedNeedApi";
import { exactDecimalEqual } from "./confirmedNeedModel";

const success: AtlasRpcResult = {
  kind: "success",
  response: { success: true },
};

describe("RMVP-05 API adapter", () => {
  it("builds the exact review envelope with bounded pagination and filters", () => {
    expect(
      confirmedNeedReadRequest(
        "subject",
        "correlation",
        "batch-1",
        {
          service_date: "2026-08-03",
          school_id: null,
          delivery_location_id: null,
          ingredient_id: "ingredient-1",
          decision_state: "UNREVIEWED",
        },
        10,
        100,
      ),
    ).toEqual({
      contract_version: "RMVP-05.v1",
      requested_by_auth_subject: "subject",
      correlation_id: "correlation",
      payload: {
        confirmed_need_batch_id: "batch-1",
        filters: {
          service_date: "2026-08-03",
          school_id: null,
          delivery_location_id: null,
          ingredient_id: "ingredient-1",
          decision_state: "UNREVIEWED",
        },
        line_offset: 10,
        line_limit: 100,
      },
    });
  });

  it("preserves decimal strings through preview and the exact retry command", async () => {
    const lines = [
      {
        confirmed_need_line_id: "line-1",
        expected_current_revision_id: "revision-1",
        expected_current_decision_id: null,
        proposed_confirmed_quantity: "9007199254740.250000",
        reason_code: "PLANNING_STEP_ADJUSTMENT" as const,
        reason_note: null,
      },
    ];
    const preview = confirmedNeedPreviewRequest(
      "subject",
      "correlation",
      "batch-1",
      4,
      lines,
    );
    expect(preview.payload.lines[0]?.proposed_confirmed_quantity).toBe(
      "9007199254740.250000",
    );

    const command = confirmedNeedCommandRequest(
      "subject",
      "correlation",
      "batch-1",
      4,
      "a".repeat(64),
      lines,
    );
    const invoke = vi.fn().mockResolvedValue(success);
    const api = createConfirmedNeedApi({ invoke });
    await api.confirm(command);
    await api.confirm(command);
    expect(invoke.mock.calls[0]?.[1]).toBe(command);
    expect(invoke.mock.calls[1]?.[1]).toBe(command);
    expect(command.payload.lines[0]?.proposed_confirmed_quantity).toBe(
      "9007199254740.250000",
    );
  });

  it("compares equivalent exact decimal strings without binary floating point", () => {
    expect(exactDecimalEqual("10.250000", "10.25")).toBe(true);
    expect(exactDecimalEqual("10.250001", "10.25")).toBe(false);
    expect(exactDecimalEqual("1e1", "10.000000")).toBe(false);
  });

  it("routes exactly the three RMVP-05 public APIs", async () => {
    const invoke = vi.fn().mockResolvedValue(success);
    const api = createConfirmedNeedApi({ invoke });
    await api.getReview("subject", "correlation", "batch-1", {
      service_date: null,
      school_id: null,
      delivery_location_id: null,
      ingredient_id: null,
      decision_state: null,
    });
    const preview = confirmedNeedPreviewRequest(
      "subject",
      "correlation",
      "batch-1",
      1,
      [],
    );
    await api.preview(preview);
    await api.confirm(
      confirmedNeedCommandRequest(
        "subject",
        "correlation",
        "batch-1",
        1,
        "a".repeat(64),
        [],
      ),
    );
    expect(invoke.mock.calls.map(([name]) => name)).toEqual([
      "atlas_api.get_confirmed_need_review",
      "atlas_api.preview_confirmed_need_confirmation",
      "atlas_api.confirm_need_quantities",
    ]);
  });
});
