import type {
  AtlasRpcResult,
  AtlasSafeBackendError,
  AtlasSuccessEnvelope,
  JsonValue,
} from "../../connection/atlasRpc";
import type { AtlasReviewScenario } from "../../review/reviewMode";
import type {
  ConfirmedNeedMaterializationRequest,
  NeedGenerationApi,
  NeedGenerationCommandRequest,
  NeedGenerationExecutionRequest,
} from "./needGenerationApi";
import type { NeedGenerationWorkbenchData } from "./needGenerationModel";

const clone = <T>(value: T): T => structuredClone(value);
const setId = "c4100000-0000-0000-0000-000000000001";
const evaluationId = "c4200000-0000-0000-0000-000000000001";
const runId = "c4300000-0000-0000-0000-000000000001";

function success(data: Record<string, JsonValue>): AtlasRpcResult {
  return {
    kind: "success",
    response: { success: true, ...data } as AtlasSuccessEnvelope,
  };
}

function error(errorCode: string): AtlasRpcResult {
  return {
    kind: "backend_error",
    error: {
      success: false,
      error_code: errorCode,
      safe_message: "Yêu cầu xem thử Need Generation đã bị từ chối an toàn.",
      retryable: errorCode === "RETRYABLE_CONCURRENCY_FAILURE",
    } as AtlasSafeBackendError,
  };
}

function fixture(
  periodStart: string,
  periodEnd: string,
): NeedGenerationWorkbenchData {
  return {
    period: { period_start: periodStart, period_end: periodEnd },
    planning_input_set: {
      planning_input_set_id: setId,
      readiness_status: "NEED_GENERATION_REQUESTED",
      current_evaluation_id: evaluationId,
    },
    current_evaluation: {
      planning_input_evaluation_id: evaluationId,
      evaluation_version: 1,
      evaluation_result: "READY",
      blocking_issue_count: 0,
      warning_count: 0,
      evaluated_at: "2026-08-02T02:00:00.000Z",
    },
    source_evidence: {
      weekly_menu: { version: 1, line_count: 3 },
      attendance: { version: 1, line_count: 3 },
      pantry: { version: 1, line_count: 1 },
    },
    terminal_run_id: null,
    selected_run: null,
    blocking_issues: [],
    warnings: [],
    grouped_requirements: [],
    atomic_detail: [],
    run_history: [],
    materialization: {
      confirmed_need_batch_id: null,
      confirmed_need_batch_version: null,
      confirmed_need_status: null,
      materialization_mode: "NONE",
    },
    allowed_actions: {
      create: true,
      validate: false,
      release: false,
      materialize: false,
      invalidate: false,
    },
    disabled_reasons: {
      create: null,
      validate: "Tạo nhu cầu trước.",
      release: "Kiểm tra nhu cầu trước.",
      materialize: "Phát hành nhu cầu trước.",
      invalidate: "Chưa có lần tạo nhu cầu.",
    },
    pagination: { offset: 0, limit: 100, total_groups: 0, has_more: false },
  };
}

function generated(state: NeedGenerationWorkbenchData) {
  const run = {
    need_generation_run_id: runId,
    attempt_ordinal: 1,
    predecessor_need_generation_run_id: null,
    status: "GENERATED" as const,
    version: 1,
    generated_line_count: 2,
    blocking_issue_count: 0,
    warning_count: 1,
    generated_at: "2026-08-02T02:05:00.000Z",
    validated_at: null,
    released_at: null,
    invalidated_at: null,
  };
  return {
    ...state,
    terminal_run_id: runId,
    selected_run: run,
    warnings: [
      {
        need_generation_issue_id: "review-zero-warning",
        issue_code: "ZERO_ACTIVE_THEORETICAL_QUANTITY",
        message: "Một đóng góp công thức tính ra bằng 0.",
        school_id: "school-a",
        service_date: state.period.period_start,
        ingredient_id: "ingredient-a",
        unit_id: "unit-kg",
        theoretical_need_line_id: "line-warning",
      },
    ],
    grouped_requirements: [
      {
        service_date: state.period.period_start,
        customer_id: "customer-a",
        school_id: "school-a",
        school_name: "Trường Atlas A",
        delivery_location_id: "location-school",
        delivery_location_name: "Bếp Trường Atlas A",
        ingredient_id: "ingredient-a",
        ingredient_name: "Gạo",
        unit_id: "unit-kg",
        unit_name: "kg",
        total_theoretical_quantity: 23.5,
        recipe_derived_quantity: 21,
        pantry_direct_quantity: 2.5,
        active_contribution_count: 2,
        removed_contribution_count: 0,
        warning_count: 0,
      },
    ],
    atomic_detail: [
      {
        theoretical_need_line_id: "line-recipe",
        contribution_family: "RECIPE_DERIVED" as const,
        theoretical_quantity: 21,
        unit_id: "unit-kg",
        unit_name: "kg",
        disposition: "ACTIVE" as const,
        dish_name: "Cơm",
        recipe_id: "recipe-a",
        warning_references: [],
      },
      {
        theoretical_need_line_id: "line-pantry",
        contribution_family: "PANTRY_DIRECT" as const,
        theoretical_quantity: 2.5,
        unit_id: "unit-kg",
        unit_name: "kg",
        disposition: "ACTIVE" as const,
        pantry_purpose: "Bổ sung vận hành",
        pantry_source_reference: "Phiếu bổ sung 24/08",
        warning_references: [],
      },
    ],
    run_history: [run],
    allowed_actions: {
      create: false,
      validate: true,
      release: false,
      materialize: false,
      invalidate: true,
    },
    disabled_reasons: {
      create: "Đã có lần tạo nhu cầu đang hoạt động.",
      validate: null,
      release: "Kiểm tra nhu cầu trước.",
      materialize: "Phát hành nhu cầu trước.",
      invalidate: null,
    },
    pagination: { offset: 0, limit: 100, total_groups: 1, has_more: false },
  } satisfies NeedGenerationWorkbenchData;
}

function commandResult(
  request:
    | NeedGenerationCommandRequest
    | NeedGenerationExecutionRequest
    | ConfirmedNeedMaterializationRequest,
  state: NeedGenerationWorkbenchData,
): AtlasRpcResult {
  return success({
    contract_version: request.contract_version,
    command_id: request.command_id,
    correlation_id: request.correlation_id,
    idempotency_status: "COMPLETED",
    safe_operator_message: "Lệnh xem thử đã hoàn tất.",
    authoritative_readback: clone(state) as unknown as JsonValue,
  });
}

export function createReviewNeedGenerationApi(
  scenario: AtlasReviewScenario,
): NeedGenerationApi {
  let state = fixture("2026-08-03", "2026-08-09");
  const receipts = new Map<string, AtlasRpcResult>();

  const failure = () => {
    if (scenario === "permission_denied") return error("CAPABILITY_DENIED");
    if (scenario === "server_error")
      return {
        kind: "transport_error",
        diagnostic: {
          code: "NETWORK_FAILURE",
          safeMessage: "Dịch vụ xem thử không phản hồi.",
        },
      } satisfies AtlasRpcResult;
    return null;
  };

  const withReceipt = (
    request:
      | NeedGenerationCommandRequest
      | NeedGenerationExecutionRequest
      | ConfirmedNeedMaterializationRequest,
    mutate: () => void,
  ) => {
    const prior = receipts.get(request.command_id);
    if (prior) return clone(prior);
    if (scenario === "menu_retryable")
      return error("RETRYABLE_CONCURRENCY_FAILURE");
    mutate();
    const result = commandResult(request, state);
    receipts.set(request.command_id, clone(result));
    return result;
  };

  return {
    async execute(request) {
      const failed = failure();
      if (failed) return failed;
      const prior = receipts.get(request.command_id);
      if (prior) return clone(prior);
      state = generated(state);
      if (state.selected_run) {
        state.selected_run = {
          ...state.selected_run,
          status: "RELEASED_FOR_CONFIRMATION",
          version: 3,
          validated_at: "2026-08-02T02:06:00.000Z",
          released_at: "2026-08-02T02:07:00.000Z",
          release_snapshot_id: "c4400000-0000-0000-0000-000000000001",
        };
        state.run_history = [state.selected_run];
      }
      state.materialization = {
        confirmed_need_batch_id: "c4500000-0000-0000-0000-000000000001",
        confirmed_need_batch_version: 1,
        confirmed_need_status: "DRAFT_REVIEW",
        materialization_mode: "NONE",
      };
      state.allowed_actions = {
        create: false,
        validate: false,
        release: false,
        materialize: false,
        invalidate: false,
      };
      const result = success({
        contract_version: "RMVP-04.v3",
        command_id: request.command_id,
        correlation_id: request.correlation_id,
        idempotency_status: "COMPLETED",
        affected_aggregate_ids: {
          need_generation_run_id:
            state.selected_run?.need_generation_run_id ?? null,
          confirmed_need_batch_id:
            state.materialization.confirmed_need_batch_id,
        },
        downstream_currentness: "CURRENT",
        safe_operator_message:
          "Đã tạo nhu cầu và Phiếu nhu cầu xác nhận trong một giao dịch.",
        result_counts: {
          needs_review_count: 4,
          carried_forward_count: 63,
        },
        authoritative_readback: {
          preflight: {
            period_start: request.payload.service_date,
            period_end: request.payload.service_date,
            readiness_state: "READY",
            source_evidence: clone(state.source_evidence),
            issues: [],
            blocking_issue_count: 0,
            downstream_currentness: "CURRENT",
            current_need: {
              need_generation_run_id:
                state.selected_run?.need_generation_run_id ?? null,
              need_generation_run_version: state.selected_run?.version ?? null,
              confirmed_need_batch_id:
                state.materialization.confirmed_need_batch_id,
              confirmed_need_batch_version:
                state.materialization.confirmed_need_batch_version,
              confirmed_need_batch_status:
                state.materialization.confirmed_need_status,
            },
          },
          need_generation: clone(state) as unknown as JsonValue,
        },
      });
      receipts.set(request.command_id, clone(result));
      return result;
    },
    async getWorkbench(
      _subject,
      correlationId,
      periodStart,
      periodEnd,
      _runId,
      _filters,
      groupOffset,
      groupLimit,
      detailGroup,
    ) {
      const failed = failure();
      if (failed) return failed;
      if (
        state.period.period_start !== periodStart ||
        state.period.period_end !== periodEnd
      )
        state = fixture(periodStart, periodEnd);
      state.pagination = {
        ...state.pagination,
        offset: groupOffset,
        limit: groupLimit,
      };
      const workbench = clone(state);
      if (!detailGroup) workbench.atomic_detail = [];
      return success({
        contract_version: "RMVP-04.v1",
        correlation_id: correlationId,
        workbench: workbench as unknown as JsonValue,
      });
    },
    async create(request) {
      return withReceipt(request, () => {
        state = generated(state);
      });
    },
    async validate(request) {
      return withReceipt(request, () => {
        if (!state.selected_run) return;
        state.selected_run = {
          ...state.selected_run,
          status: "VALIDATED",
          version: 2,
          validated_at: "2026-08-02T02:06:00.000Z",
        };
        state.run_history = [state.selected_run];
        state.allowed_actions = {
          create: false,
          validate: false,
          release: true,
          materialize: false,
          invalidate: true,
        };
      });
    },
    async release(request) {
      return withReceipt(request, () => {
        if (!state.selected_run) return;
        state.selected_run = {
          ...state.selected_run,
          status: "RELEASED_FOR_CONFIRMATION",
          version: 3,
          released_at: "2026-08-02T02:07:00.000Z",
          release_snapshot_id: "c4400000-0000-0000-0000-000000000001",
        };
        state.run_history = [state.selected_run];
        state.materialization.materialization_mode = "INITIAL";
        state.allowed_actions = {
          create: false,
          validate: false,
          release: false,
          materialize: true,
          invalidate: true,
        };
      });
    },
    async invalidate(request) {
      return withReceipt(request, () => {
        if (!state.selected_run) return;
        state.selected_run = {
          ...state.selected_run,
          status: "INVALIDATED",
          version: state.selected_run.version + 1,
          invalidated_at: "2026-08-02T02:08:00.000Z",
        };
        state.run_history = [state.selected_run];
        state.allowed_actions = {
          create: true,
          validate: false,
          release: false,
          materialize: false,
          invalidate: false,
        };
      });
    },
    async materialize(request) {
      return withReceipt(request, () => {
        state.materialization = {
          confirmed_need_batch_id: "c4500000-0000-0000-0000-000000000001",
          confirmed_need_batch_version: 1,
          confirmed_need_status: "DRAFT_REVIEW",
          materialization_mode: "NONE",
        };
        state.allowed_actions.materialize = false;
      });
    },
  };
}
