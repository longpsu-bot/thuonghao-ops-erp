import type {
  AtlasRpcResult,
  AtlasSafeBackendError,
  AtlasSuccessEnvelope,
  JsonValue,
} from "../../connection/atlasRpc";
import type { AtlasReviewScenario } from "../../review/reviewMode";
import type {
  PlanningInputReadinessApi,
  PlanningInputReadinessCommandRequest,
} from "./planningInputReadinessApi";
import type {
  PlanningInputReadinessWorkbenchData,
  ReadinessCandidate,
  ReadinessHistoryItem,
  ReadinessIssue,
  ReadinessSourceEvidence,
} from "./planningInputReadinessModel";

const now = "2026-08-01T04:00:00.000Z";
const actorId = "b6000000-0000-0000-0000-000000000001";
const setId = "b6100000-0000-0000-0000-000000000001";
const evaluationId = "b6200000-0000-0000-0000-000000000001";
const clone = <T>(value: T): T => structuredClone(value);

const success = (data: Record<string, JsonValue>): AtlasRpcResult => ({
  kind: "success",
  response: { success: true, ...data } as AtlasSuccessEnvelope,
});

const backendError = (errorCode: string): AtlasRpcResult => ({
  kind: "backend_error",
  error: {
    success: false,
    error_code: errorCode,
    safe_message: "Yêu cầu xem thử sẵn sàng đã bị từ chối an toàn.",
    retryable: errorCode === "RETRYABLE_CONCURRENCY_FAILURE",
  } as AtlasSafeBackendError,
});

function candidate(
  kind: "weekly_menu" | "attendance" | "pantry",
  periodStart: string,
  periodEnd: string,
  suffix = "1",
  pantryZero = false,
): ReadinessCandidate {
  const common = {
    source_period: { period_start: periodStart, period_end: periodEnd },
    source_status: "APPROVED",
    latest_approval: true,
    source_current: true,
    approved_by_actor_id: actorId,
    approved_by_display_name: "Điều phối viên xem thử",
    approved_at: now,
    line_count: pantryZero ? 0 : 12,
    coverage: "COVERS" as const,
  };
  if (kind === "weekly_menu")
    return {
      ...common,
      weekly_menu_id: `b6300000-0000-0000-0000-00000000000${suffix}`,
      weekly_menu_version: 3,
      weekly_menu_approval_snapshot_id: `b6310000-0000-0000-0000-00000000000${suffix}`,
    };
  if (kind === "attendance")
    return {
      ...common,
      attendance_batch_id: `b6400000-0000-0000-0000-00000000000${suffix}`,
      attendance_version: 2,
      attendance_approval_snapshot_id: `b6410000-0000-0000-0000-00000000000${suffix}`,
    };
  return {
    ...common,
    pantry_need_batch_id: `b6500000-0000-0000-0000-00000000000${suffix}`,
    pantry_need_batch_version: 4,
    pantry_need_approval_snapshot_id: `b6510000-0000-0000-0000-00000000000${suffix}`,
    no_additions_confirmed: pantryZero,
    pantry_evidence_kind: pantryZero ? "EXPLICIT_ZERO_LINES" : "POSITIVE_LINES",
  };
}

function evidence(
  candidateValue: ReadinessCandidate | null,
  options: {
    state?: ReadinessSourceEvidence["selection_state"];
    candidates?: ReadinessCandidate[];
    pantry?: boolean;
  } = {},
): ReadinessSourceEvidence {
  const state = options.state ?? (candidateValue ? "SELECTED" : "MISSING");
  return {
    selection_state: state,
    coverage: candidateValue?.coverage ?? "NOT_APPLICABLE",
    source_current: state === "SELECTED",
    selected: candidateValue,
    candidates: options.candidates ?? (candidateValue ? [candidateValue] : []),
    ...(options.pantry
      ? {
          pantry_evidence_kind:
            state === "MISSING"
              ? "MISSING"
              : candidateValue?.pantry_evidence_kind,
        }
      : {}),
    safe_message:
      state === "AMBIGUOUS"
        ? "Chọn một bằng chứng đã phê duyệt."
        : state === "STALE"
          ? "Bằng chứng đã chọn không còn hiện hành."
          : state === "MISSING"
            ? "Không có bằng chứng đã phê duyệt giao với kỳ."
            : "Bằng chứng hiện hành đã được chọn.",
  };
}

function emptyActions(canEvaluate: boolean) {
  return {
    can_evaluate: canEvaluate,
    can_request_need_generation: false,
    can_invalidate: false,
    invalidation_reason_codes: [] as string[],
    disabled_reasons: canEvaluate
      ? ["Cần đánh giá trước khi yêu cầu tạo nhu cầu."]
      : ["Cần giải quyết lựa chọn nguồn trước khi đánh giá."],
  };
}

function fixture(
  scenario: AtlasReviewScenario,
  periodStart: string,
  periodEnd: string,
): PlanningInputReadinessWorkbenchData {
  const weekly = candidate("weekly_menu", periodStart, periodEnd);
  const attendance = candidate("attendance", periodStart, periodEnd);
  const pantry = candidate(
    "pantry",
    periodStart,
    periodEnd,
    "1",
    scenario === "attendance_zero",
  );
  const missing = scenario === "empty";
  const ambiguous = scenario === "menu_duplicate";
  const stale = scenario === "stale" || scenario === "menu_stale";
  return {
    period: {
      period_start: periodStart,
      period_end: periodEnd,
      inclusive: true,
      monday_week_convenience: {
        week_start: periodStart,
        week_end: periodEnd,
      },
    },
    decision: "NOT_EVALUATED",
    root: null,
    current_evaluation: null,
    source_evidence: {
      weekly_menu: missing
        ? evidence(null)
        : ambiguous
          ? evidence(null, {
              state: "AMBIGUOUS",
              candidates: [
                weekly,
                candidate("weekly_menu", periodStart, periodEnd, "2"),
              ],
            })
          : stale
            ? evidence(weekly, { state: "STALE" })
            : evidence(weekly),
      attendance: missing ? evidence(null) : evidence(attendance),
      pantry: missing
        ? evidence(null, { pantry: true })
        : evidence(pantry, { pantry: true }),
    },
    allowed_actions: emptyActions(!ambiguous && !stale),
    history_items: [],
    history_next_cursor: null,
    history_has_more: false,
  };
}

function issue(code: string, message: string): ReadinessIssue {
  return {
    planning_input_readiness_issue_id: `review-${code}`,
    severity: "BLOCKING",
    issue_code: code,
    safe_message: message,
    input_type: null,
    school_id: null,
    service_date: null,
  };
}

function commandResult(
  request: PlanningInputReadinessCommandRequest,
  workbench: PlanningInputReadinessWorkbenchData,
  message: string,
): AtlasRpcResult {
  return success({
    contract_version: "RMVP-03B.v1",
    command_id: request.command_id,
    correlation_id: request.correlation_id,
    idempotency_status: "COMPLETED",
    affected_aggregate_ids: {
      planning_input_set_id: setId,
      planning_input_evaluation_id: evaluationId,
    },
    new_versions: {
      current_evaluation_version:
        workbench.current_evaluation?.evaluation_version ?? 1,
    },
    emitted_event_ids: ["b6600000-0000-0000-0000-000000000001"],
    audit_event_ids: ["b6700000-0000-0000-0000-000000000001"],
    safe_operator_message: message,
    authoritative_readback: clone(workbench) as unknown as JsonValue,
  });
}

export function createReviewPlanningInputReadinessApi(
  scenario: AtlasReviewScenario,
): PlanningInputReadinessApi {
  let state = fixture(scenario, "2026-08-03", "2026-08-09");
  const receipts = new Map<string, AtlasRpcResult>();

  const scenarioFailure = () => {
    if (
      scenario === "permission_denied" ||
      scenario === "menu_permission_denied" ||
      scenario === "attendance_permission_denied"
    )
      return backendError("CAPABILITY_DENIED");
    if (scenario === "server_error")
      return {
        kind: "transport_error",
        diagnostic: {
          code: "NETWORK_FAILURE",
          safeMessage: "Dịch vụ xem thử sẵn sàng không phản hồi.",
        },
      } satisfies AtlasRpcResult;
    return null;
  };

  const withReceipt = (
    request: PlanningInputReadinessCommandRequest,
    operation: () => AtlasRpcResult,
  ) => {
    const prior = receipts.get(request.command_id);
    if (prior) return clone(prior);
    if (scenario === "menu_retryable" || scenario === "attendance_retryable")
      return backendError("RETRYABLE_CONCURRENCY_FAILURE");
    const result = operation();
    receipts.set(request.command_id, clone(result));
    return result;
  };

  return {
    async getWorkbench(
      _authSubject,
      _correlationId,
      periodStart,
      periodEnd,
      sourceSelection,
      historyLimit,
      historyCursor,
    ) {
      const failure = scenarioFailure();
      if (failure) return failure;
      if (
        state.period.period_start !== periodStart ||
        state.period.period_end !== periodEnd
      )
        state = fixture(scenario, periodStart, periodEnd);
      if (sourceSelection) {
        for (const source of ["weekly_menu", "attendance", "pantry"] as const) {
          const supplied = sourceSelection[source];
          if (
            !supplied ||
            typeof supplied !== "object" ||
            Array.isArray(supplied)
          )
            continue;
          const match = state.source_evidence[source].candidates.find(
            (item) =>
              JSON.stringify(supplied) ===
              JSON.stringify(
                source === "weekly_menu"
                  ? {
                      weekly_menu_id: item.weekly_menu_id,
                      weekly_menu_version: item.weekly_menu_version,
                      weekly_menu_approval_snapshot_id:
                        item.weekly_menu_approval_snapshot_id,
                    }
                  : source === "attendance"
                    ? {
                        attendance_batch_id: item.attendance_batch_id,
                        attendance_version: item.attendance_version,
                        attendance_approval_snapshot_id:
                          item.attendance_approval_snapshot_id,
                      }
                    : {
                        pantry_need_batch_id: item.pantry_need_batch_id,
                        pantry_need_batch_version:
                          item.pantry_need_batch_version,
                        pantry_need_approval_snapshot_id:
                          item.pantry_need_approval_snapshot_id,
                      },
              ),
          );
          if (match)
            state.source_evidence[source] = evidence(match, {
              pantry: source === "pantry",
              candidates: state.source_evidence[source].candidates,
            });
        }
        state.allowed_actions.can_evaluate = Object.values(
          state.source_evidence,
        ).every((item) =>
          ["SELECTED", "MISSING"].includes(item.selection_state),
        );
      }
      const limit = historyLimit ?? 25;
      const offset = historyCursor === "review-history-page-2" ? limit : 0;
      const items = state.history_items.slice(offset, offset + limit);
      const hasMore = offset + limit < state.history_items.length;
      return success({
        workbench: {
          ...clone(state),
          history_items: items,
          history_has_more: hasMore,
          history_next_cursor: hasMore ? "review-history-page-2" : null,
        } as unknown as JsonValue,
      });
    },
    async evaluate(request) {
      const failure = scenarioFailure();
      if (failure) return failure;
      return withReceipt(request, () => {
        const evidence = Object.values(state.source_evidence);
        const ready = evidence.every(
          (item) =>
            item.selection_state === "SELECTED" &&
            item.source_current &&
            item.coverage === "COVERS",
        );
        const blockers = ready
          ? []
          : [issue("MISSING_APPROVED_SOURCE", "Thiếu nguồn đã phê duyệt.")];
        state.decision = ready ? "READY" : "NOT_READY";
        state.root = {
          planning_input_set_id: setId,
          readiness_status: state.decision,
          current_evaluation_id: evaluationId,
          created_at: now,
          updated_at: now,
        };
        state.current_evaluation = {
          planning_input_evaluation_id: evaluationId,
          evaluation_version: 1,
          evaluation_result: ready ? "READY" : "NOT_READY",
          blocking_issue_count: blockers.length,
          warning_count: 0,
          evaluated_by_actor_id: actorId,
          evaluated_by_display_name: "Điều phối viên xem thử",
          evaluated_at: now,
          source_bindings: request.payload.source_candidates as Record<
            "weekly_menu" | "attendance" | "pantry",
            JsonValue
          >,
          issues: { blockers, warnings: [] },
        };
        const history: ReadinessHistoryItem = {
          history_kind: "EVALUATION",
          history_item_id: evaluationId,
          occurred_at: now,
          evaluation: {
            ...state.current_evaluation,
            issues: blockers,
            historical_pantry_state: "BOUND",
            can_authorize_need_generation_request: ready,
          },
        };
        state.history_items = [history];
        state.allowed_actions = {
          can_evaluate: !ready,
          can_request_need_generation: ready,
          can_invalidate: ready,
          invalidation_reason_codes: ready
            ? ["PLANNING_REVIEW_CORRECTION"]
            : [],
          disabled_reasons: ready
            ? []
            : ["Cần đánh giá READY trước khi yêu cầu tạo nhu cầu."],
        };
        return commandResult(
          request,
          state,
          ready
            ? "Ba nguồn đã sẵn sàng."
            : "Đánh giá đã ghi nhận các nguồn còn thiếu.",
        );
      });
    },
    async requestNeedGeneration(request) {
      const failure = scenarioFailure();
      if (failure) return failure;
      return withReceipt(request, () => {
        if ("source_candidates" in request.payload)
          return backendError("VALIDATION_FAILED");
        state.decision = "NEED_GENERATION_REQUESTED";
        if (state.root) {
          state.root.readiness_status = "NEED_GENERATION_REQUESTED";
          state.root.updated_at = now;
        }
        state.history_items.unshift({
          history_kind: "NEED_GENERATION_REQUEST",
          history_item_id: "b6800000-0000-0000-0000-000000000001",
          occurred_at: now,
          actor_display_name: "Điều phối viên xem thử",
          prior_status: "READY",
          next_status: "NEED_GENERATION_REQUESTED",
          reason_code: request.reason_code,
          reason_note: request.reason_note,
        });
        state.allowed_actions = {
          can_evaluate: false,
          can_request_need_generation: false,
          can_invalidate: true,
          invalidation_reason_codes: [
            "PLANNING_REVIEW_CORRECTION",
            "NEED_GENERATION_REQUEST_WITHDRAWN",
          ],
          disabled_reasons: ["Yêu cầu tạo nhu cầu đã được ghi nhận."],
        };
        return commandResult(
          request,
          state,
          "Đã ghi nhận yêu cầu tạo nhu cầu; chưa tạo dữ liệu đầu ra.",
        );
      });
    },
    async invalidate(request) {
      const failure = scenarioFailure();
      if (failure) return failure;
      return withReceipt(request, () => {
        state.decision = "INVALIDATED";
        if (state.root) {
          state.root.readiness_status = "INVALIDATED";
          state.root.updated_at = now;
        }
        state.history_items.unshift({
          history_kind: "INVALIDATION",
          history_item_id: "b6900000-0000-0000-0000-000000000001",
          occurred_at: now,
          actor_display_name: "Điều phối viên xem thử",
          prior_status: request.expected_root_status,
          next_status: "INVALIDATED",
          reason_code: request.reason_code,
          reason_note: request.reason_note,
        });
        state.allowed_actions = {
          can_evaluate: true,
          can_request_need_generation: false,
          can_invalidate: false,
          invalidation_reason_codes: [],
          disabled_reasons: ["Cần đánh giá lại sau khi vô hiệu."],
        };
        return commandResult(
          request,
          state,
          "Trạng thái sẵn sàng đã được vô hiệu rõ ràng.",
        );
      });
    },
  };
}
