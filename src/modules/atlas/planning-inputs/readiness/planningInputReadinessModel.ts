import type { AtlasRpcResult, JsonValue } from "../../connection/atlasRpc";
import type {
  ReadinessRootStatus,
  ReadinessCommandExpectation,
} from "./planningInputReadinessApi";

export type ReadinessDecision =
  | "NOT_EVALUATED"
  | "NOT_READY"
  | "READY"
  | "NEED_GENERATION_REQUESTED"
  | "INVALIDATED";
export type ReadinessSourceKind = "weekly_menu" | "attendance" | "pantry";
export type ReadinessSelectionState =
  "SELECTED" | "MISSING" | "AMBIGUOUS" | "STALE";

export type ReadinessCandidate = {
  weekly_menu_id?: string;
  weekly_menu_version?: number;
  weekly_menu_approval_snapshot_id?: string;
  attendance_batch_id?: string;
  attendance_version?: number;
  attendance_approval_snapshot_id?: string;
  pantry_need_batch_id?: string;
  pantry_need_batch_version?: number;
  pantry_need_approval_snapshot_id?: string;
  source_period: { period_start: string; period_end: string };
  source_status: string;
  latest_approval: boolean;
  source_current: boolean;
  approved_by_actor_id: string;
  approved_by_display_name: string;
  approved_at: string;
  line_count: number;
  coverage: "COVERS" | "DOES_NOT_COVER" | "NOT_APPLICABLE";
  no_additions_confirmed?: boolean;
  pantry_evidence_kind?:
    "POSITIVE_LINES" | "EXPLICIT_ZERO_LINES" | "INVALID_ZERO_EVIDENCE";
};

export type ReadinessSourceEvidence = {
  selection_state: ReadinessSelectionState;
  coverage: "COVERS" | "DOES_NOT_COVER" | "NOT_APPLICABLE";
  source_current: boolean;
  selected: ReadinessCandidate | null;
  candidates: ReadinessCandidate[];
  pantry_evidence_kind?:
    | "POSITIVE_LINES"
    | "EXPLICIT_ZERO_LINES"
    | "INVALID_ZERO_EVIDENCE"
    | "MISSING"
    | null;
  safe_message: string;
};

export type ReadinessIssue = {
  planning_input_readiness_issue_id: string;
  severity: "BLOCKING" | "WARNING";
  issue_code: string;
  safe_message: string;
  input_type: string | null;
  school_id: string | null;
  service_date: string | null;
};

export type ReadinessRoot = {
  planning_input_set_id: string;
  readiness_status: Exclude<ReadinessRootStatus, "ABSENT">;
  current_evaluation_id: string;
  created_at: string;
  updated_at: string;
};

export type ReadinessEvaluation = {
  planning_input_evaluation_id: string;
  evaluation_version: number;
  evaluation_result: "NOT_READY" | "READY";
  blocking_issue_count: number;
  warning_count: number;
  evaluated_by_actor_id: string;
  evaluated_by_display_name: string;
  evaluated_at: string;
  source_bindings: Record<ReadinessSourceKind, JsonValue>;
  issues: { blockers: ReadinessIssue[]; warnings: ReadinessIssue[] };
};

export type ReadinessHistoryItem = {
  history_kind: "EVALUATION" | "NEED_GENERATION_REQUEST" | "INVALIDATION";
  history_item_id: string;
  occurred_at: string;
  evaluation?: Omit<ReadinessEvaluation, "issues"> & {
    historical_pantry_state?: "PRE_PANTRY_NULL_BINDING" | "BOUND";
    can_authorize_need_generation_request?: boolean;
    issues: ReadinessIssue[];
  };
  actor_display_name?: string;
  prior_status?: string;
  next_status?: string;
  reason_code?: string | null;
  reason_note?: string | null;
};

export type PlanningInputReadinessWorkbenchData = {
  period: {
    period_start: string;
    period_end: string;
    inclusive: true;
    monday_week_convenience: { week_start: string; week_end: string };
  };
  decision: ReadinessDecision;
  root: ReadinessRoot | null;
  current_evaluation: ReadinessEvaluation | null;
  source_evidence: Record<ReadinessSourceKind, ReadinessSourceEvidence>;
  allowed_actions: {
    can_evaluate: boolean;
    can_request_need_generation: boolean;
    can_invalidate: boolean;
    invalidation_reason_codes: string[];
    disabled_reasons: string[];
  };
  history_items: ReadinessHistoryItem[];
  history_next_cursor: string | null;
  history_has_more: boolean;
};

export type PlanningInputPreflightIssue = {
  severity: "BLOCKING" | "WARNING";
  issue_code: string;
  message: string;
  input_type: string | null;
  school_id: string | null;
  service_date: string | null;
};

export type PlanningInputPreflightData = {
  period_start: string;
  period_end: string;
  readiness_state: "READY" | "BLOCKED";
  source_evidence: Record<ReadinessSourceKind, ReadinessSourceEvidence>;
  issues: PlanningInputPreflightIssue[];
  blocking_issue_count: number;
  downstream_currentness: "CURRENT" | "OUTDATED" | "NOT_GENERATED";
  current_need: {
    confirmed_need_batch_id: string;
    confirmed_need_batch_status: string;
    confirmed_need_batch_version: number;
    need_generation_run_id: string;
    need_generation_run_version: number;
    need_generation_run_status: string;
  } | null;
};

function record(value: unknown): Record<string, JsonValue> | null {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? (value as Record<string, JsonValue>)
    : null;
}

function parsedWorkbench(value: JsonValue | undefined) {
  const workbench = record(value);
  if (
    !workbench ||
    !record(workbench.period) ||
    !record(workbench.source_evidence) ||
    !record(workbench.allowed_actions) ||
    !Array.isArray(workbench.history_items)
  )
    return null;
  return workbench as unknown as PlanningInputReadinessWorkbenchData;
}

export function planningInputReadinessWorkbenchFromResult(
  result: AtlasRpcResult,
) {
  return result.kind === "success"
    ? parsedWorkbench(result.response.workbench)
    : null;
}

export function planningInputReadinessReadbackFromResult(
  result: AtlasRpcResult,
) {
  return result.kind === "success"
    ? parsedWorkbench(result.response.authoritative_readback)
    : null;
}

export function planningInputPreflightFromResult(result: AtlasRpcResult) {
  if (result.kind !== "success") return null;
  const direct = record(result.response.preflight);
  const readback = record(result.response.authoritative_readback);
  const nested = readback ? record(readback.preflight) : null;
  const preflight = direct ?? nested;
  if (
    !preflight ||
    !record(preflight.source_evidence) ||
    !Array.isArray(preflight.issues)
  )
    return null;
  return preflight as unknown as PlanningInputPreflightData;
}

export function readinessCandidateTriple(
  source: ReadinessSourceKind,
  candidate: ReadinessCandidate,
): Record<string, JsonValue> {
  if (source === "weekly_menu")
    return {
      weekly_menu_id: candidate.weekly_menu_id ?? null,
      weekly_menu_version: candidate.weekly_menu_version ?? null,
      weekly_menu_approval_snapshot_id:
        candidate.weekly_menu_approval_snapshot_id ?? null,
    };
  if (source === "attendance")
    return {
      attendance_batch_id: candidate.attendance_batch_id ?? null,
      attendance_version: candidate.attendance_version ?? null,
      attendance_approval_snapshot_id:
        candidate.attendance_approval_snapshot_id ?? null,
    };
  return {
    pantry_need_batch_id: candidate.pantry_need_batch_id ?? null,
    pantry_need_batch_version: candidate.pantry_need_batch_version ?? null,
    pantry_need_approval_snapshot_id:
      candidate.pantry_need_approval_snapshot_id ?? null,
  };
}

export function readinessCandidateKey(
  source: ReadinessSourceKind,
  candidate: ReadinessCandidate,
) {
  return JSON.stringify(readinessCandidateTriple(source, candidate));
}

export function readinessSourceSelection(
  workbench: PlanningInputReadinessWorkbenchData,
): Record<string, JsonValue> {
  return Object.fromEntries(
    (["weekly_menu", "attendance", "pantry"] as const).map((source) => {
      const evidence = workbench.source_evidence[source];
      return [
        source,
        evidence.selected
          ? readinessCandidateTriple(source, evidence.selected)
          : null,
      ];
    }),
  );
}

export function readinessExpectation(
  workbench: PlanningInputReadinessWorkbenchData,
): ReadinessCommandExpectation {
  return workbench.root && workbench.current_evaluation
    ? {
        expectedRootStatus: workbench.root.readiness_status,
        expectedCurrentEvaluationId:
          workbench.current_evaluation.planning_input_evaluation_id,
        expectedCurrentEvaluationVersion:
          workbench.current_evaluation.evaluation_version,
      }
    : {
        expectedRootStatus: "ABSENT",
        expectedCurrentEvaluationId: null,
        expectedCurrentEvaluationVersion: null,
      };
}

export function pantryReadinessEvidenceLabel(
  evidence: ReadinessSourceEvidence,
) {
  if (
    evidence.selection_state === "MISSING" ||
    evidence.pantry_evidence_kind === "MISSING"
  )
    return "Chưa có bằng chứng Pantry đã phê duyệt.";
  if (
    evidence.pantry_evidence_kind === "EXPLICIT_ZERO_LINES" ||
    evidence.selected?.pantry_evidence_kind === "EXPLICIT_ZERO_LINES"
  )
    return "Không có bổ sung Pantry — đã xác nhận rõ ràng.";
  if (
    evidence.pantry_evidence_kind === "POSITIVE_LINES" ||
    evidence.selected?.pantry_evidence_kind === "POSITIVE_LINES"
  )
    return `${evidence.selected?.line_count ?? 0} dòng Pantry đã phê duyệt.`;
  return "Bằng chứng Pantry cần được chọn lại.";
}

export function invalidationReasonRequiresNote(reasonCode: string) {
  return [
    "PLANNING_REVIEW_CORRECTION",
    "NEED_GENERATION_REQUEST_WITHDRAWN",
  ].includes(reasonCode);
}

export function mergeReadinessHistory(
  current: PlanningInputReadinessWorkbenchData,
  continuation: PlanningInputReadinessWorkbenchData,
) {
  const seen = new Set<string>();
  const history_items = [
    ...current.history_items,
    ...continuation.history_items,
  ].filter((item) => {
    const key = `${item.history_kind}:${item.history_item_id}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
  return { ...continuation, history_items };
}

export function historicalPantryMessage(item: ReadinessHistoryItem) {
  return item.evaluation?.historical_pantry_state === "PRE_PANTRY_NULL_BINDING"
    ? "Đánh giá lịch sử trước khi Pantry được ràng buộc; không thể dùng để yêu cầu tạo nhu cầu."
    : null;
}

export function readinessResultMessage(result: AtlasRpcResult) {
  if (result.kind === "success")
    return (
      (typeof result.response.safe_operator_message === "string"
        ? result.response.safe_operator_message
        : null) ?? "Atlas đã đọc lại trạng thái sẵn sàng có thẩm quyền."
    );
  if (result.kind === "auth_error")
    return "Phiên làm việc đã hết. Vui lòng đăng nhập lại.";
  if (result.kind === "transport_error")
    return "Chưa xác định kết quả lệnh. Atlas không tự động gửi lại; hãy kiểm tra trạng thái có thẩm quyền.";
  if (result.kind === "client_error")
    return "Ứng dụng đã chặn yêu cầu ngoài danh mục RMVP-03B.";
  const messages: Record<string, string> = {
    CAPABILITY_DENIED: "Bạn không có quyền điều khiển trạng thái sẵn sàng.",
    AMBIGUOUS_SOURCE_CANDIDATE: "Hãy chọn đúng một bằng chứng cho mỗi nguồn.",
    STALE_SOURCE_CANDIDATE: "Bằng chứng nguồn đã cũ. Hãy tải lại.",
    STALE_ROOT_STATE: "Trạng thái sẵn sàng đã thay đổi. Atlas đang tải lại.",
    STALE_CURRENT_EVALUATION:
      "Đánh giá hiện tại đã thay đổi. Atlas đang tải lại.",
    RETRYABLE_CONCURRENCY_FAILURE:
      "Có xung đột tạm thời. Có thể gửi lại đúng yêu cầu đã giữ nguyên.",
    IDEMPOTENCY_CONFLICT:
      "Mã lệnh đã được dùng cho một ý định khác; không gửi lại.",
    NEED_GENERATION_HANDOFF_ALREADY_CONSUMED:
      "Yêu cầu tạo nhu cầu đã được sử dụng và không thể rút lại.",
    REASON_NOTE_REQUIRED: "Cần nhập ghi chú cho lý do đã chọn.",
  };
  return messages[result.error.error_code] ?? result.error.safe_message;
}

export function readinessResultIsStale(result: AtlasRpcResult) {
  return (
    result.kind === "backend_error" &&
    [
      "STALE_ROOT_STATE",
      "STALE_CURRENT_EVALUATION",
      "STALE_SOURCE_CANDIDATE",
      "RETRYABLE_CONCURRENCY_FAILURE",
    ].includes(result.error.error_code)
  );
}

export function readinessResultAllowsExactRetry(result: AtlasRpcResult) {
  return (
    result.kind === "backend_error" &&
    result.error.error_code === "RETRYABLE_CONCURRENCY_FAILURE"
  );
}

export function readinessDecisionLabel(decision: ReadinessDecision) {
  const labels: Record<ReadinessDecision, string> = {
    NOT_EVALUATED: "CHƯA ĐÁNH GIÁ",
    NOT_READY: "CHƯA SẴN SÀNG",
    READY: "SẴN SÀNG",
    NEED_GENERATION_REQUESTED: "ĐÃ YÊU CẦU TẠO NHU CẦU",
    INVALIDATED: "ĐÃ VÔ HIỆU",
  };
  return labels[decision];
}
