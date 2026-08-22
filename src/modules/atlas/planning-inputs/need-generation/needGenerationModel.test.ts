import { describe, expect, it } from "vitest";
import type { AtlasRpcResult } from "../../connection/atlasRpc";
import {
  formatQuantity,
  needGenerationReadbackFromResult,
  needGenerationContinuitySummaryFromResult,
  needGenerationResultAllowsExactRetry,
  needGenerationResultIsStale,
  needGenerationResultMessage,
  needGenerationWorkbenchFromResult,
} from "./needGenerationModel";

const workbench = {
  period: { period_start: "2026-08-03", period_end: "2026-08-09" },
  allowed_actions: {},
  pagination: {},
  grouped_requirements: [],
  blocking_issues: [],
  warnings: [],
  run_history: [],
};

describe("RMVP-04 authoritative model", () => {
  it("accepts shaped workbench and command readback only from success results", () => {
    const read: AtlasRpcResult = {
      kind: "success",
      response: { success: true, workbench: workbench as never },
    };
    const command: AtlasRpcResult = {
      kind: "success",
      response: {
        success: true,
        authoritative_readback: workbench as never,
      },
    };
    expect(needGenerationWorkbenchFromResult(read)).toBe(workbench);
    expect(needGenerationReadbackFromResult(command)).toBe(workbench);
  });

  it("distinguishes exact retry outcomes from stale outcomes", () => {
    const retryable: AtlasRpcResult = {
      kind: "backend_error",
      error: {
        success: false,
        error_code: "RETRYABLE_CONCURRENCY_FAILURE",
        safe_message: "safe",
        retryable: true,
      },
    };
    const stale: AtlasRpcResult = {
      kind: "backend_error",
      error: {
        success: false,
        error_code: "STALE_SOURCE_BINDING",
        safe_message: "safe",
      },
    };
    expect(needGenerationResultAllowsExactRetry(retryable)).toBe(true);
    expect(needGenerationResultIsStale(retryable)).toBe(false);
    expect(needGenerationResultAllowsExactRetry(stale)).toBe(false);
    expect(needGenerationResultIsStale(stale)).toBe(true);
  });

  it("formats backend quantities without recalculating them", () => {
    expect(formatQuantity(12.345678)).toBe("12,345678");
    expect(formatQuantity(0)).toBe("0");
  });

  it("accepts only complete authoritative continuity counts", () => {
    expect(
      needGenerationContinuitySummaryFromResult({
        kind: "success",
        response: {
          success: true,
          result_counts: {
            needs_review_count: 4,
            carried_forward_count: 63,
          },
        },
      }),
    ).toEqual({ needsReview: 4, carriedForward: 63 });
    expect(
      needGenerationContinuitySummaryFromResult({
        kind: "success",
        response: {
          success: true,
          result_counts: { needs_review_count: 4 },
        },
      }),
    ).toBeNull();
  });

  it("uses business-language generation messages without implementation jargon", () => {
    const backend = (
      errorCode: string,
      retryable = false,
      safeMessage = "safe",
    ) =>
      ({
        kind: "backend_error",
        error: {
          success: false,
          error_code: errorCode,
          safe_message: safeMessage,
          retryable,
        },
      }) satisfies AtlasRpcResult;
    const messages = [
      needGenerationResultMessage({
        kind: "client_error",
        diagnostic: { code: "RPC_NOT_ALLOWED", safeMessage: "safe" },
      }),
      needGenerationResultMessage(backend("CAPABILITY_DENIED")),
      needGenerationResultMessage(backend("READINESS_NOT_REQUESTED")),
      needGenerationResultMessage(backend("CURRENT_EVALUATION_NOT_READY")),
      needGenerationResultMessage(backend("STALE_VERSION")),
      needGenerationResultMessage(backend("STALE_SOURCE_BINDING")),
      needGenerationResultMessage(
        backend("NEED_GENERATION_RUN_ALREADY_ACTIVE"),
      ),
      needGenerationResultMessage(backend("NEED_GENERATION_HAS_BLOCKERS")),
      needGenerationResultMessage(backend("DOWNSTREAM_CORRECTION_REQUIRED")),
      needGenerationResultMessage(
        backend("RETRYABLE_CONCURRENCY_FAILURE", true),
      ),
      needGenerationResultMessage(backend("IDEMPOTENCY_CONFLICT")),
      needGenerationResultMessage(
        backend("UNMAPPED", false, "Need Generation READY Bằng chứng nguồn"),
      ),
    ];

    expect(messages).toEqual(
      expect.arrayContaining([
        "Ứng dụng không thể thực hiện yêu cầu tạo nhu cầu này.",
        "Dữ liệu đầu vào chưa sẵn sàng để tạo nhu cầu.",
        "Dữ liệu nguồn đã thay đổi. Hãy tải lại trước khi tiếp tục.",
        "Kỳ này đã có nhu cầu đang được xử lý.",
        "Nhu cầu đã được chuyển sang lên đơn và cần quy trình điều chỉnh riêng.",
      ]),
    );
    for (const message of messages) {
      expect(message).not.toMatch(/Need Generation|READY|Bằng chứng nguồn/i);
    }
  });

  it("keeps authentication, capability, stale, retry, conflict, downstream, and transport outcomes distinct", () => {
    const backend = (errorCode: string, retryable = false) =>
      ({
        kind: "backend_error",
        error: {
          success: false,
          error_code: errorCode,
          safe_message: "safe",
          retryable,
        },
      }) satisfies AtlasRpcResult;

    expect(
      needGenerationResultMessage({
        kind: "auth_error",
        diagnostic: { code: "SESSION_EXPIRED", safeMessage: "safe" },
      }),
    ).toMatch(/đăng nhập lại/i);
    expect(needGenerationResultMessage(backend("CAPABILITY_DENIED"))).toMatch(
      /không có quyền/i,
    );
    expect(needGenerationResultMessage(backend("STALE_VERSION"))).toMatch(
      /Nhu cầu đã thay đổi/,
    );
    expect(
      needGenerationResultMessage(
        backend("RETRYABLE_CONCURRENCY_FAILURE", true),
      ),
    ).toMatch(/Có thể thử lại/);
    expect(
      needGenerationResultMessage(backend("IDEMPOTENCY_CONFLICT")),
    ).toMatch(/không còn khớp/);
    expect(
      needGenerationResultMessage(backend("DOWNSTREAM_CORRECTION_REQUIRED")),
    ).toMatch(/quy trình điều chỉnh riêng/);
    expect(
      needGenerationResultMessage({
        kind: "backend_error",
        error: {
          success: false,
          error_code: "VALIDATION_FAILED",
          safe_message: "safe",
          field_errors: [
            { field: "requested_at", message: "bounded clock skew" },
          ],
        },
      }),
    ).toMatch(/Thời gian trên thiết bị/);
    expect(
      needGenerationResultMessage({
        kind: "transport_error",
        diagnostic: { code: "NETWORK_FAILURE", safeMessage: "safe" },
      }),
    ).toMatch(/không tự gửi lại/i);
  });
});
