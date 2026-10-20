import { describe, expect, it, vi } from "vitest";
import type { AtlasRpcResult } from "../../connection/atlasRpc";
import {
  confirmedNeedApprovalRequest,
  confirmedNeedCommandRequest,
  confirmedNeedPreviewRequest,
  confirmedNeedReadRequest,
  confirmedNeedReleaseRequest,
  confirmedNeedPurchaseHandoffRequest,
  confirmedNeedValidationRequest,
  confirmedNeedSaveV3Request,
  createConfirmedNeedApi,
} from "./confirmedNeedApi";
import {
  confirmedNeedValidationBlockingCodes,
  confirmedNeedValidationWarningCodes,
  exactDecimalEqual,
} from "./confirmedNeedModel";

const success: AtlasRpcResult = {
  kind: "success",
  response: { success: true },
};

describe("K3 explicit released correction request", () => {
  it("preserves exact changed quantities, five read bindings and replay identity", async () => {
    const binding = {
      expected_confirmed_need_release_id: "release-original",
      expected_purchase_handoff_batch_id: "handoff-original",
      expected_purchase_handoff_revision_id: "handoff-revision",
      expected_purchase_handoff_version: 7,
      expected_source_fingerprint: "a".repeat(64),
    };
    const lines = [
      {
        confirmed_need_line_id: "line-1",
        expected_current_revision_id: "revision-1",
        expected_current_decision_id: "decision-1",
        proposed_confirmed_quantity: "110.000000",
        reason_code: "OPERATIONAL_QUANTITY_ADJUSTMENT" as const,
        reason_note: "Bếp điều chỉnh sĩ số",
      },
    ];
    const request = confirmedNeedSaveV3Request(
      "actor",
      "correlation",
      "batch",
      12,
      lines,
      binding,
    );
    expect(request.contract_version).toBe("RMVP-05.v3");
    expect(request.payload).toEqual({
      confirmed_need_batch_id: "batch",
      lines,
      correction: binding,
    });
    expect(Object.keys(request.payload.correction)).toHaveLength(5);
    const invoke = vi.fn().mockResolvedValue(success);
    const api = createConfirmedNeedApi({ invoke });
    await api.save(request);
    await api.save(request);
    expect(invoke.mock.calls[0]).toEqual([
      "atlas_api.save_confirmed_needs",
      request,
    ]);
    expect(invoke.mock.calls[1]![1]).toBe(request);
    expect(request.idempotency_key).toContain(request.command_id);
  });
  it("keeps the complete nullable Handoff triple supplied by the read", () => {
    const request = confirmedNeedSaveV3Request(
      "actor",
      "correlation",
      "batch",
      12,
      [],
      {
        expected_confirmed_need_release_id: "release-original",
        expected_purchase_handoff_batch_id: null,
        expected_purchase_handoff_revision_id: null,
        expected_purchase_handoff_version: null,
        expected_source_fingerprint: "b".repeat(64),
      },
    );
    expect(
      request.payload.correction.expected_purchase_handoff_batch_id,
    ).toBeNull();
    expect(
      request.payload.correction.expected_purchase_handoff_revision_id,
    ).toBeNull();
    expect(
      request.payload.correction.expected_purchase_handoff_version,
    ).toBeNull();
  });
});

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

  it("builds the exact RMVP-06 complete-batch validation envelope", () => {
    const request = confirmedNeedValidationRequest(
      "subject",
      "correlation",
      "batch-1",
      7,
      "  kiểm tra cuối ca  ",
    );
    expect(request).toMatchObject({
      contract_version: "RMVP-06.v1",
      correlation_id: "correlation",
      expected_version: 7,
      requested_by_auth_subject: "subject",
      reason_code: "BATCH_VALIDATION_REQUESTED",
      reason_note: "kiểm tra cuối ca",
      payload: { confirmed_need_batch_id: "batch-1" },
    });
    expect(request.idempotency_key).toBe(
      `confirmed-need-validation:${request.command_id}`,
    );
  });

  it("builds the two exact closed RMVP-07 lifecycle envelopes", () => {
    const approval = confirmedNeedApprovalRequest(
      "subject",
      "correlation-approval",
      "batch-1",
      3,
      "  ca sáng  ",
    );
    expect(approval).toMatchObject({
      contract_version: "RMVP-07.v1",
      correlation_id: "correlation-approval",
      expected_version: 3,
      requested_by_auth_subject: "subject",
      reason_code: "CONFIRMED_NEED_APPROVAL_REQUESTED",
      reason_note: "ca sáng",
      payload: { confirmed_need_batch_id: "batch-1" },
    });
    expect(approval.idempotency_key).toBe(
      `confirmed-need-approval:${approval.command_id}`,
    );

    const release = confirmedNeedReleaseRequest(
      "subject",
      "correlation-release",
      "batch-1",
      4,
    );
    expect(release).toMatchObject({
      contract_version: "RMVP-07.v1",
      correlation_id: "correlation-release",
      expected_version: 4,
      requested_by_auth_subject: "subject",
      reason_code: "CONFIRMED_NEED_RELEASE_REQUESTED",
      reason_note: null,
      payload: { confirmed_need_batch_id: "batch-1" },
    });
    expect(release.idempotency_key).toBe(
      `confirmed-need-release:${release.command_id}`,
    );
  });

  it("routes the RMVP-05, RMVP-06, and two RMVP-07 APIs", async () => {
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
    await api.validate(
      confirmedNeedValidationRequest("subject", "correlation", "batch-1", 1),
    );
    await api.approve(
      confirmedNeedApprovalRequest("subject", "correlation", "batch-1", 2),
    );
    await api.release(
      confirmedNeedReleaseRequest("subject", "correlation", "batch-1", 3),
    );
    expect(invoke.mock.calls.map(([name]) => name)).toEqual([
      "atlas_api.get_confirmed_need_review",
      "atlas_api.preview_confirmed_need_confirmation",
      "atlas_api.confirm_need_quantities",
      "atlas_api.validate_confirmed_needs",
      "atlas_api.approve_confirmed_needs",
      "atlas_api.release_confirmed_needs_for_purchase_handoff",
    ]);
  });

  it("builds and routes the exact Planning-owned school-catering Handoff envelope", async () => {
    const request = confirmedNeedPurchaseHandoffRequest(
      "subject",
      "correlation-handoff",
      "batch-1",
      8,
    );
    expect(request).toMatchObject({
      contract_version: "SCHOOL-CATERING-HANDOFF.v1",
      correlation_id: "correlation-handoff",
      expected_version: 8,
      requested_by_auth_subject: "subject",
      reason_code: "SCHOOL_CATERING_PURCHASE_HANDOFF_RELEASED",
      reason_note: null,
      payload: { confirmed_need_batch_id: "batch-1" },
    });
    expect(request.idempotency_key).toBe(
      `school-catering-handoff:${request.command_id}`,
    );

    const invoke = vi.fn().mockResolvedValue(success);
    const api = createConfirmedNeedApi({ invoke });
    await api.releasePurchaseHandoff(request);
    expect(invoke.mock.calls).toEqual([
      ["atlas_api.release_school_catering_purchase_handoff", request],
    ]);
  });
});

describe("RMVP-06 validation registry", () => {
  it("exposes the complete approved 19 blocking and two warning codes in canonical order", () => {
    expect(confirmedNeedValidationBlockingCodes).toEqual([
      "NO_CURRENT_LINES",
      "CURRENT_LINE_SET_INVALID",
      "CURRENT_REVISION_MISSING",
      "CURRENT_REVISION_AMBIGUOUS",
      "CURRENT_DECISION_MISSING",
      "CURRENT_DECISION_AMBIGUOUS",
      "DECISION_REVISION_MISMATCH",
      "SOURCE_RELEASE_NOT_CURRENT",
      "CONTRIBUTION_MEMBERSHIP_INVALID",
      "THEORETICAL_TOTAL_MISMATCH",
      "CONTROLLED_UNIT_INACTIVE",
      "PLANNING_POLICY_MISSING",
      "PLANNING_POLICY_AMBIGUOUS",
      "PLANNING_POLICY_NOT_ELIGIBLE",
      "DECISION_POLICY_MISMATCH",
      "CONFIRMED_QUANTITY_INVALID",
      "ADJUSTMENT_REASON_INCOMPLETE",
      "SOURCE_BLOCKER_PRESENT",
      "CURRENT_FACTS_CHANGED",
    ]);
    expect(confirmedNeedValidationWarningCodes).toEqual([
      "ZERO_CONFIRMED_QUANTITY",
      "UPSTREAM_WARNING_RETAINED",
    ]);
  });
});
