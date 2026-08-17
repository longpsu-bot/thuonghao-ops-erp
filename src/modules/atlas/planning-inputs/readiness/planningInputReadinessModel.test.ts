import { describe, expect, it } from "vitest";
import type { AtlasRpcResult } from "../../connection/atlasRpc";
import {
  historicalPantryMessage,
  invalidationReasonRequiresNote,
  mergeReadinessHistory,
  pantryReadinessEvidenceLabel,
  planningInputReadinessReadbackFromResult,
  planningInputReadinessWorkbenchFromResult,
  readinessCandidateTriple,
  readinessResultAllowsExactRetry,
  readinessResultMessage,
  type PlanningInputReadinessWorkbenchData,
  type ReadinessCandidate,
  type ReadinessSourceEvidence,
} from "./planningInputReadinessModel";

const candidate: ReadinessCandidate = {
  weekly_menu_id: "menu-1",
  weekly_menu_version: 5,
  weekly_menu_approval_snapshot_id: "snapshot-1",
  source_period: { period_start: "2026-08-03", period_end: "2026-08-09" },
  source_status: "APPROVED",
  latest_approval: true,
  source_current: true,
  approved_by_actor_id: "actor-1",
  approved_by_display_name: "Operator",
  approved_at: "2026-08-01T00:00:00Z",
  line_count: 12,
  coverage: "COVERS",
};

function evidence(
  pantryKind: ReadinessSourceEvidence["pantry_evidence_kind"],
  selected: ReadinessCandidate | null,
): ReadinessSourceEvidence {
  return {
    selection_state: selected ? "SELECTED" : "MISSING",
    coverage: selected ? "COVERS" : "NOT_APPLICABLE",
    source_current: Boolean(selected),
    selected,
    candidates: selected ? [selected] : [],
    pantry_evidence_kind: pantryKind,
    safe_message: "safe",
  };
}

function workbench(
  history: PlanningInputReadinessWorkbenchData["history_items"] = [],
): PlanningInputReadinessWorkbenchData {
  const selected = evidence(null, candidate);
  return {
    period: {
      period_start: "2026-08-03",
      period_end: "2026-08-09",
      inclusive: true,
      monday_week_convenience: {
        week_start: "2026-08-03",
        week_end: "2026-08-09",
      },
    },
    decision: "NOT_EVALUATED",
    root: null,
    current_evaluation: null,
    source_evidence: {
      weekly_menu: selected,
      attendance: selected,
      pantry: evidence("POSITIVE_LINES", {
        ...candidate,
        pantry_need_batch_id: "pantry-1",
        pantry_need_batch_version: 2,
        pantry_need_approval_snapshot_id: "pantry-snapshot-1",
        pantry_evidence_kind: "POSITIVE_LINES",
      }),
    },
    allowed_actions: {
      can_evaluate: true,
      can_request_need_generation: false,
      can_invalidate: false,
      invalidation_reason_codes: [],
      disabled_reasons: [],
    },
    history_items: history,
    history_next_cursor: null,
    history_has_more: false,
  };
}

describe("RMVP-03B authoritative model", () => {
  it("accepts only authoritative workbench/readback success members", () => {
    const value = workbench();
    const read: AtlasRpcResult = {
      kind: "success",
      response: { success: true, workbench: value as never },
    };
    const command: AtlasRpcResult = {
      kind: "success",
      response: { success: true, authoritative_readback: value as never },
    };
    expect(planningInputReadinessWorkbenchFromResult(read)).toBe(value);
    expect(planningInputReadinessReadbackFromResult(command)).toBe(value);
    expect(
      planningInputReadinessWorkbenchFromResult({
        kind: "backend_error",
        error: { success: false, error_code: "SAFE", safe_message: "safe" },
      }),
    ).toBeNull();
  });

  it("submits only the exact typed source triple", () => {
    expect(readinessCandidateTriple("weekly_menu", candidate)).toEqual({
      weekly_menu_id: "menu-1",
      weekly_menu_version: 5,
      weekly_menu_approval_snapshot_id: "snapshot-1",
    });
    expect(
      readinessCandidateTriple("weekly_menu", candidate),
    ).not.toHaveProperty("line_count");
  });

  it("distinguishes positive, explicit-zero, and missing additional demand", () => {
    expect(
      pantryReadinessEvidenceLabel(
        evidence("POSITIVE_LINES", {
          ...candidate,
          line_count: 7,
          pantry_evidence_kind: "POSITIVE_LINES",
        }),
      ),
    ).toBe("7 dòng Nhu cầu bổ sung đã lưu.");
    expect(
      pantryReadinessEvidenceLabel(
        evidence("EXPLICIT_ZERO_LINES", {
          ...candidate,
          line_count: 0,
          no_additions_confirmed: true,
          pantry_evidence_kind: "EXPLICIT_ZERO_LINES",
        }),
      ),
    ).toMatch(/Đã xác nhận tuần này không có Nhu cầu bổ sung/);
    expect(pantryReadinessEvidenceLabel(evidence("MISSING", null))).toMatch(
      /Chưa có Nhu cầu bổ sung/,
    );
  });

  it("appends opaque-cursor pages without duplicate history", () => {
    const firstItem = {
      history_kind: "EVALUATION" as const,
      history_item_id: "history-1",
      occurred_at: "2026-08-02T00:00:00Z",
    };
    const secondItem = {
      history_kind: "INVALIDATION" as const,
      history_item_id: "history-2",
      occurred_at: "2026-08-01T00:00:00Z",
    };
    const first = {
      ...workbench([firstItem]),
      history_has_more: true,
      history_next_cursor: "opaque==",
    };
    const continuation = {
      ...workbench([firstItem, secondItem]),
      decision: "INVALIDATED" as const,
    };
    const merged = mergeReadinessHistory(first, continuation);
    expect(merged.history_items.map((item) => item.history_item_id)).toEqual([
      "history-1",
      "history-2",
    ]);
    expect(merged.decision).toBe("INVALIDATED");
  });

  it("labels historical null-Pantry evidence and conditional note rules", () => {
    expect(
      historicalPantryMessage({
        history_kind: "EVALUATION",
        history_item_id: "history-1",
        occurred_at: "2026-08-01T00:00:00Z",
        evaluation: {
          planning_input_evaluation_id: "evaluation-1",
          evaluation_version: 1,
          evaluation_result: "READY",
          blocking_issue_count: 0,
          warning_count: 0,
          evaluated_by_actor_id: "actor-1",
          evaluated_by_display_name: "Operator",
          evaluated_at: "2026-08-01T00:00:00Z",
          source_bindings: {
            weekly_menu: null,
            attendance: null,
            pantry: null,
          },
          issues: [],
          historical_pantry_state: "PRE_PANTRY_NULL_BINDING",
          can_authorize_need_generation_request: false,
        },
      }),
    ).toMatch(/không thể dùng để tạo nhu cầu/);
    expect(invalidationReasonRequiresNote("PLANNING_REVIEW_CORRECTION")).toBe(
      true,
    );
    expect(invalidationReasonRequiresNote("UPSTREAM_SOURCE_CHANGED")).toBe(
      false,
    );
  });

  it("permits exact retry only for the accepted retryable concurrency error", () => {
    const retryable: AtlasRpcResult = {
      kind: "backend_error",
      error: {
        success: false,
        error_code: "RETRYABLE_CONCURRENCY_FAILURE",
        safe_message: "safe",
        retryable: true,
      },
    };
    expect(readinessResultAllowsExactRetry(retryable)).toBe(true);
    expect(readinessResultMessage(retryable)).toMatch(/nội dung yêu cầu/);
    expect(
      readinessResultAllowsExactRetry({
        kind: "transport_error",
        diagnostic: {
          code: "NETWORK_FAILURE",
          safeMessage: "safe",
        },
      }),
    ).toBe(false);
  });

  it("uses business-language readiness messages without implementation jargon", () => {
    const backend = (errorCode: string, safeMessage = "safe") =>
      ({
        kind: "backend_error",
        error: {
          success: false,
          error_code: errorCode,
          safe_message: safeMessage,
        },
      }) satisfies AtlasRpcResult;
    const messages = [
      readinessResultMessage({
        kind: "client_error",
        diagnostic: { code: "RPC_NOT_ALLOWED", safeMessage: "safe" },
      }),
      readinessResultMessage(backend("CAPABILITY_DENIED")),
      readinessResultMessage(backend("AMBIGUOUS_SOURCE_CANDIDATE")),
      readinessResultMessage(backend("STALE_SOURCE_CANDIDATE")),
      readinessResultMessage(backend("STALE_ROOT_STATE")),
      readinessResultMessage(backend("STALE_CURRENT_EVALUATION")),
      readinessResultMessage(backend("RETRYABLE_CONCURRENCY_FAILURE")),
      readinessResultMessage(backend("IDEMPOTENCY_CONFLICT")),
      readinessResultMessage(
        backend("NEED_GENERATION_HANDOFF_ALREADY_CONSUMED"),
      ),
      readinessResultMessage(
        backend("UNMAPPED", "RMVP-03B candidate evaluation evidence READY"),
      ),
    ];

    expect(messages).toEqual(
      expect.arrayContaining([
        "Ứng dụng không thể kiểm tra trạng thái dữ liệu đầu vào.",
        "Có nhiều dữ liệu phù hợp. Hãy kiểm tra lại dữ liệu đầu vào.",
        "Dữ liệu đầu vào đã thay đổi. Hãy tải lại trước khi tiếp tục.",
        "Yêu cầu tạo nhu cầu này đã được sử dụng và không thể rút lại.",
      ]),
    );
    for (const message of messages) {
      expect(message).not.toMatch(
        /RMVP-03B|READY|candidate|evaluation|evidence|đánh giá|bằng chứng/i,
      );
    }
  });

  it("keeps authentication, stale-state, retry, conflict, and transport outcomes distinct", () => {
    const backend = (errorCode: string) =>
      ({
        kind: "backend_error",
        error: { success: false, error_code: errorCode, safe_message: "safe" },
      }) satisfies AtlasRpcResult;

    expect(
      readinessResultMessage({
        kind: "auth_error",
        diagnostic: { code: "SESSION_EXPIRED", safeMessage: "safe" },
      }),
    ).toMatch(/đăng nhập lại/i);
    expect(readinessResultMessage(backend("CAPABILITY_DENIED"))).toMatch(
      /không có quyền/i,
    );
    expect(readinessResultMessage(backend("STALE_ROOT_STATE"))).toMatch(
      /Trạng thái dữ liệu đã thay đổi/,
    );
    expect(
      readinessResultMessage(backend("RETRYABLE_CONCURRENCY_FAILURE")),
    ).toMatch(/Có thể thử lại/);
    expect(readinessResultMessage(backend("IDEMPOTENCY_CONFLICT"))).toMatch(
      /không còn khớp/,
    );
    expect(
      readinessResultMessage({
        kind: "transport_error",
        diagnostic: { code: "NETWORK_FAILURE", safeMessage: "safe" },
      }),
    ).toMatch(/không tự động gửi lại/i);
  });
});
