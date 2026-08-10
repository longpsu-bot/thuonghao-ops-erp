import type { AtlasRpcResult, JsonValue } from "../../connection/atlasRpc";

export type NeedGenerationIssue = {
  need_generation_issue_id: string;
  issue_code: string;
  message: string;
  school_id: string | null;
  service_date: string | null;
  ingredient_id: string | null;
  unit_id: string | null;
  theoretical_need_line_id: string | null;
};

export type NeedGenerationGroup = {
  service_date: string;
  customer_id: string;
  school_id: string;
  school_name: string;
  delivery_location_id: string;
  delivery_location_name: string;
  ingredient_id: string;
  ingredient_name: string;
  unit_id: string;
  unit_name: string;
  total_theoretical_quantity: number;
  recipe_derived_quantity: number;
  pantry_direct_quantity: number;
  active_contribution_count: number;
  removed_contribution_count: number;
  warning_count: number;
};

export type NeedGenerationDetail = {
  theoretical_need_line_id: string;
  contribution_family: "RECIPE_DERIVED" | "PANTRY_DIRECT";
  theoretical_quantity: number;
  unit_id: string;
  unit_name: string;
  disposition: "ACTIVE" | "REMOVED";
  dish_name?: string;
  recipe_id?: string;
  pantry_purpose?: string;
  pantry_source_reference?: string;
  warning_references: { issue_code: string; message: string }[];
};

export type NeedGenerationRun = {
  need_generation_run_id: string;
  attempt_ordinal: number;
  predecessor_need_generation_run_id: string | null;
  status:
    "GENERATED" | "VALIDATED" | "RELEASED_FOR_CONFIRMATION" | "INVALIDATED";
  version: number;
  generated_line_count: number;
  blocking_issue_count: number;
  warning_count: number;
  generated_at: string;
  validated_at: string | null;
  released_at: string | null;
  invalidated_at: string | null;
  release_snapshot_id?: string | null;
};

export type NeedGenerationWorkbenchData = {
  period: { period_start: string; period_end: string };
  planning_input_set: {
    planning_input_set_id: string;
    readiness_status: string;
    current_evaluation_id: string;
  } | null;
  current_evaluation: {
    planning_input_evaluation_id: string;
    evaluation_version: number;
    evaluation_result: string;
    blocking_issue_count: number;
    warning_count: number;
    evaluated_at: string;
  } | null;
  source_evidence: Record<
    "weekly_menu" | "attendance" | "pantry",
    Record<string, JsonValue>
  >;
  terminal_run_id: string | null;
  selected_run: NeedGenerationRun | null;
  blocking_issues: NeedGenerationIssue[];
  warnings: NeedGenerationIssue[];
  grouped_requirements: NeedGenerationGroup[];
  atomic_detail: NeedGenerationDetail[];
  run_history: NeedGenerationRun[];
  materialization: {
    confirmed_need_batch_id: string | null;
    confirmed_need_batch_version: number | null;
    confirmed_need_status: string | null;
    materialization_mode: "INITIAL" | "CORRECTION" | "NONE";
  };
  allowed_actions: {
    create: boolean;
    validate: boolean;
    release: boolean;
    materialize: boolean;
    invalidate: boolean;
  };
  disabled_reasons: Record<string, string | null>;
  pagination: {
    offset: number;
    limit: number;
    total_groups: number;
    has_more: boolean;
  };
};

function record(value: unknown): Record<string, JsonValue> | null {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? (value as Record<string, JsonValue>)
    : null;
}

function parseWorkbench(value: JsonValue | undefined) {
  const workbench = record(value);
  if (
    !workbench ||
    !record(workbench.period) ||
    !record(workbench.allowed_actions) ||
    !record(workbench.pagination) ||
    !Array.isArray(workbench.grouped_requirements) ||
    !Array.isArray(workbench.blocking_issues) ||
    !Array.isArray(workbench.warnings) ||
    !Array.isArray(workbench.run_history)
  )
    return null;
  return workbench as unknown as NeedGenerationWorkbenchData;
}

export function needGenerationWorkbenchFromResult(result: AtlasRpcResult) {
  return result.kind === "success"
    ? parseWorkbench(result.response.workbench)
    : null;
}

export function needGenerationReadbackFromResult(result: AtlasRpcResult) {
  if (result.kind !== "success") return null;
  const readback = record(result.response.authoritative_readback);
  return parseWorkbench(
    readback?.need_generation ?? result.response.authoritative_readback,
  );
}

export function needGenerationResultAllowsExactRetry(result: AtlasRpcResult) {
  return (
    result.kind === "transport_error" ||
    (result.kind === "backend_error" &&
      result.error.retryable === true &&
      result.error.error_code === "RETRYABLE_CONCURRENCY_FAILURE")
  );
}

export function needGenerationResultIsStale(result: AtlasRpcResult) {
  return (
    result.kind === "backend_error" &&
    ["STALE_VERSION", "STALE_SOURCE_BINDING"].includes(result.error.error_code)
  );
}

export function needGenerationResultMessage(result: AtlasRpcResult) {
  if (result.kind === "success")
    return (
      (typeof result.response.safe_operator_message === "string"
        ? result.response.safe_operator_message
        : null) ?? "Atlas đã đọc lại nhu cầu có thẩm quyền."
    );
  if (result.kind === "auth_error")
    return "Phiên làm việc đã hết. Vui lòng đăng nhập lại.";
  if (result.kind === "transport_error")
    return "Chưa xác định kết quả lệnh. Atlas không tự gửi lại; hãy tải lại dữ liệu có thẩm quyền trước khi thực hiện hành động khác.";
  if (result.kind === "client_error")
    return "Ứng dụng đã chặn yêu cầu ngoài danh mục Need Generation.";
  const messages: Record<string, string> = {
    READINESS_NOT_REQUESTED:
      "Hãy quay lại Sẵn sàng đầu vào và yêu cầu tạo nhu cầu trước.",
    CURRENT_EVALUATION_NOT_READY:
      "Đánh giá đầu vào hiện tại chưa READY hoặc còn lỗi chặn.",
    STALE_SOURCE_BINDING:
      "Bằng chứng nguồn đã thay đổi. Atlas đang tải lại trạng thái.",
    NEED_GENERATION_RUN_ALREADY_ACTIVE:
      "Kỳ này đã có lần tạo nhu cầu đang hoạt động.",
    NEED_GENERATION_HAS_BLOCKERS:
      "Không thể tiếp tục khi lần tạo nhu cầu còn lỗi chặn.",
    DOWNSTREAM_CORRECTION_REQUIRED:
      "Dữ liệu phía sau đã cam kết; cần quy trình điều chỉnh riêng.",
    RETRYABLE_CONCURRENCY_FAILURE:
      "Có xung đột tạm thời. Có thể thử lại đúng yêu cầu đã giữ nguyên.",
    IDEMPOTENCY_CONFLICT: "Mã lệnh đã thuộc một ý định khác; không gửi lại.",
  };
  return messages[result.error.error_code] ?? result.error.safe_message;
}

export function formatQuantity(value: number) {
  return new Intl.NumberFormat("vi-VN", {
    maximumFractionDigits: 6,
  }).format(value);
}
