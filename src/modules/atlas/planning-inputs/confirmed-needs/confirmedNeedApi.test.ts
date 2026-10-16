import {
  createReviewConfirmedNeedApi,
  createReviewConfirmedNeedFixture,
} from "./reviewConfirmedNeedApi";
import { confirmedNeedCorrectionPreviewFromResult } from "./confirmedNeedModel";
import { describe, expect, it, vi } from "vitest";
import type { AtlasRpcResult } from "../../connection/atlasRpc";
import {
  confirmedNeedCorrectionPreviewRequest,
  confirmedNeedCorrectionCommandRequest,
  confirmedNeedApprovalRequest,
  confirmedNeedCommandRequest,
  confirmedNeedPreviewRequest,
  confirmedNeedReadRequest,
  confirmedNeedReleaseRequest,
  confirmedNeedPurchaseHandoffRequest,
  confirmedNeedValidationRequest,
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

describe("released Need correction transport", () => {
  const payload = {
    need_generation_run_id: "run",
    expected_need_generation_run_version: 3,
    confirmed_need_batch_id: "batch",
    expected_confirmed_need_batch_version: 6,
    confirmed_need_line_id: "line",
    expected_current_revision_id: "released-revision",
    expected_current_decision_id: "released-decision",
    proposed_confirmed_quantity: "99999999999999.123456",
    reason_code: "OPERATIONAL_QUANTITY_ADJUSTMENT" as const,
    reason_note: "Bếp điều chỉnh",
  };
  it("preserves exact decimals and closes both envelopes without browser child orchestration", async () => {
    const invoke = vi.fn().mockResolvedValue(success),
      api = createConfirmedNeedApi({ invoke });
    const withExtra = { ...payload, ignored: "drop" };
    const preview = confirmedNeedCorrectionPreviewRequest(
      "subject",
      "correlation",
      withExtra,
    );
    expect(preview).toEqual({
      contract_version: "CONFIRMED-NEED-CORRECTION.v1",
      requested_by_auth_subject: "subject",
      correlation_id: "correlation",
      payload,
    });
    await api.previewCorrection(preview);
    const command = confirmedNeedCorrectionCommandRequest(
      "subject",
      "correlation",
      payload,
      "a".repeat(64),
    );
    expect(command.expected_version).toBe(
      command.payload.expected_confirmed_need_batch_version,
    );
    expect(command.payload.proposed_confirmed_quantity).toBe(
      "99999999999999.123456",
    );
    expect(command.reason_note).toBe(payload.reason_note);
    const frozen = structuredClone(command);
    await api.correct(command);
    await api.correct(command);
    expect(command).toEqual(frozen);
    expect(invoke.mock.calls.map(([name]) => name)).toEqual([
      "atlas_api.get_confirmed_need_correction_preview",
      "atlas_api.correct_confirmed_need",
      "atlas_api.correct_confirmed_need",
    ]);
  });
  it.each([
    { expected_current_revision_id: null },
    { expected_current_decision_id: null },
    { proposed_confirmed_quantity: 12.5 },
    { proposed_confirmed_quantity: "1.1234567" },
    { reason_note: " " },
  ])("rejects invalid released target or quantity/reason %o", (change) => {
    expect(() =>
      confirmedNeedCorrectionPreviewRequest("subject", "correlation", {
        ...payload,
        ...change,
      } as never),
    ).toThrow();
  });
});

describe("legacy review correction caller", () => {
  it("implements the same exact methods and preserves other released line identities", async () => {
    const state = createReviewConfirmedNeedFixture(2);
    state.authoritative_batch_status = "RELEASED_FOR_PURCHASE_HANDOFF";
    state.batch_status = "RELEASED_FOR_PURCHASE_HANDOFF";
    state.lines.forEach((line, index) => {
      line.current_decision_id = `released-decision-${index}`;
      line.confirmed_quantity_after = line.proposed_confirmed_quantity;
    });
    const api = createReviewConfirmedNeedApi("ready", {
        initialFixture: state,
      }),
      line = state.lines[0]!;
    const request = confirmedNeedCorrectionPreviewRequest(
      "actor",
      "correlation",
      {
        need_generation_run_id: state.need_generation_source.run_id,
        expected_need_generation_run_version:
          state.need_generation_source.run_version,
        confirmed_need_batch_id: state.confirmed_need_batch_id,
        expected_confirmed_need_batch_version: state.batch_version,
        confirmed_need_line_id: line.confirmed_need_line_id,
        expected_current_revision_id: line.current_revision_id,
        expected_current_decision_id: line.current_decision_id!,
        proposed_confirmed_quantity: "12.500001",
        reason_code: "OTHER",
        reason_note: "Bếp yêu cầu",
      },
    );
    const preview = confirmedNeedCorrectionPreviewFromResult(
      await api.previewCorrection(request),
      request.payload,
    );
    expect(preview).not.toBeNull();
    const command = confirmedNeedCorrectionCommandRequest(
        "actor",
        "correlation",
        preview!.target,
        preview!.proposal_fingerprint,
      ),
      answer = await api.correct(command);
    expect(await api.correct(command)).toEqual(answer);
    expect(answer.kind).toBe("success");
    if (answer.kind !== "success") throw Error();
    const read = answer.response
      .authoritative_readback as unknown as typeof state;
    expect(read.lines[0]!.confirmed_quantity_after).toBe("12.500001");
    expect(read.lines[1]).toEqual(state.lines[1]);
  });
});
