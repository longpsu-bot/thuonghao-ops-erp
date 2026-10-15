import { describe, it, expect } from "vitest";
import {
  confirmedNeedCorrectionPreviewFromResult,
  confirmedNeedCorrectionOutcome,
} from "./confirmedNeedModel";
import {
  confirmedNeedCorrectionCommandRequest,
  type ConfirmedNeedCorrectionPayload,
} from "./confirmedNeedApi";
import type { AtlasRpcResult } from "../../connection/atlasRpc";
const target: ConfirmedNeedCorrectionPayload = {
  need_generation_run_id: "run",
  expected_need_generation_run_version: 3,
  confirmed_need_batch_id: "batch",
  expected_confirmed_need_batch_version: 6,
  confirmed_need_line_id: "line",
  expected_current_revision_id: "r",
  expected_current_decision_id: "d",
  proposed_confirmed_quantity: "11.250000",
  reason_code: "OTHER",
  reason_note: "Bếp yêu cầu",
};
function response(): AtlasRpcResult {
  return {
    kind: "success",
    response: {
      success: true,
      contract_version: "CONFIRMED-NEED-CORRECTION.v1",
      read_name: "get_confirmed_need_correction_preview",
      write_certainty: "NO_WRITE",
      target,
      proposal_fingerprint: "a".repeat(64),
      quantity: { before: "10.250000", after: "11.250000", delta: "1.000000" },
      family: {
        service_date: "2026-11-02",
        delivery_location_id: "location",
        ingredient_id: "ingredient",
        unit_id: "unit",
        quantity_before: "10.250000",
        quantity_after: "11.250000",
        contributions: [
          {
            confirmed_need_batch_id: "batch",
            confirmed_need_line_id: "line",
            revision_id: "r",
            decision_id: "d",
            school_id: "school",
            customer_id: "customer",
            delivery_location_id: "location",
            quantity: "10.250000",
            source_membership: [],
          },
        ],
      },
      display: {
        ingredient_name: "Gạo",
        delivery_location_name: "Bếp",
        unit_name: "Kilogram",
        schools: [
          {
            confirmed_need_line_id: "line",
            school_id: "school",
            school_name: "Trường A",
            customer_id: "customer",
            customer_name: "Khối trường",
            delivery_location_id: "location",
          },
        ],
      },
      allowed_actions: { correct: true },
      disabled_reasons: { correct: null },
      procurement_details_coverage: "AUTHORIZED_DETAILS_ONLY",
      procurement_details: [],
      purchase_order_coverage: "AUTHORIZED_DOCUMENTS_ONLY",
      purchase_orders: [],
    },
  };
}
describe("correction response boundary", () => {
  it("retains exact server delta/full-family/coverage and a disabled authority response", () => {
    const value = response();
    expect(
      confirmedNeedCorrectionPreviewFromResult(value, target)?.quantity.delta,
    ).toBe("1.000000");
    if (value.kind === "success") {
      value.response.allowed_actions = { correct: false };
      value.response.disabled_reasons = {
        correct: "CORRECTION_AUTHORITY_REQUIRED",
      };
    }
    expect(
      confirmedNeedCorrectionPreviewFromResult(value, target)?.allowed_actions
        .correct,
    ).toBe(false);
  });
  it.each(["contract", "target", "quantity", "contribution", "coverage"])(
    "rejects malformed %s",
    (field) => {
      const value = response();
      if (value.kind !== "success") throw Error();
      if (field === "contract") value.response.contract_version = "wrong";
      if (field === "target")
        value.response.target = {
          ...target,
          expected_current_decision_id: null,
        };
      if (field === "quantity")
        value.response.quantity = {
          before: 10,
          after: "11.250000",
          delta: "1.000000",
        };
      if (field === "contribution") value.response.family = null;
      if (field === "coverage")
        value.response.purchase_order_coverage = "COMPLETE";
      expect(
        confirmedNeedCorrectionPreviewFromResult(value, target),
      ).toBeNull();
    },
  );
  it.each([
    "revision_id",
    "decision_id",
    "confirmed_need_batch_id",
    "delivery_location_id",
  ])("binds selected immutable contribution %s", (field) => {
    const value = response();
    if (value.kind !== "success") throw Error();
    const family = value.response.family as {
      contributions: Record<string, unknown>[];
    };
    family.contributions[0]![field] = "other";
    expect(confirmedNeedCorrectionPreviewFromResult(value, target)).toBeNull();
  });
  it("recognizes committed exact replay without a write-certainty field", () => {
    const request = confirmedNeedCorrectionCommandRequest(
      "subject",
      "correlation",
      target,
      "a".repeat(64),
    );
    expect(
      confirmedNeedCorrectionOutcome(
        {
          kind: "success",
          response: {
            success: true,
            contract_version: "CONFIRMED-NEED-CORRECTION.v1",
            command_name: "correct_confirmed_need",
            command_id: request.command_id,
            confirmed_need_batch_id: "batch",
            receipt_id: "receipt",
            idempotency_status: "COMPLETED",
            resulting_batch_version: 8,
            child_command_ids: ["prepare", "save"],
          },
        },
        request,
      ),
    ).toEqual({ kind: "committed", version: 8 });
  });
  it("distinguishes transport unknown from known retry/stale and never assumes malformed success committed", () => {
    const request = confirmedNeedCorrectionCommandRequest(
      "subject",
      "correlation",
      target,
      "a".repeat(64),
    );
    const error = {
      kind: "backend_error",
      error: {
        success: false,
        error_code: "RETRYABLE_CONCURRENCY_FAILURE",
        safe_message: "Retry",
        write_certainty: "NO_COMMITTED_CHANGE",
        retryable: true,
      },
    } as AtlasRpcResult;
    expect(confirmedNeedCorrectionOutcome(error, request).kind).toBe(
      "retryable",
    );
    if (error.kind === "backend_error")
      error.error.error_code = "STALE_CORRECTION_PROPOSAL";
    expect(confirmedNeedCorrectionOutcome(error, request).kind).toBe("stale");
    expect(
      confirmedNeedCorrectionOutcome(
        { kind: "success", response: { success: true } },
        request,
      ).kind,
    ).toBe("unknown");
  });
});
