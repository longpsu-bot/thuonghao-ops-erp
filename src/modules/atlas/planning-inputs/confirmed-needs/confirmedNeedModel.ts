import type { AtlasRpcResult, JsonValue } from "../../connection/atlasRpc";

export type ConfirmedNeedIssue = {
  code: string;
  message: string;
};

export type ConfirmedNeedDraftLine = {
  selected: boolean;
  exact_quantity: string;
  reason_code:
    | "PROPOSAL_ACCEPTED"
    | "PLANNING_STEP_ADJUSTMENT"
    | "OPERATIONAL_QUANTITY_ADJUSTMENT"
    | "OTHER";
  reason_note: string;
};

export type ConfirmedNeedDecisionHistory = {
  decision_id: string;
  decision_number: number;
  predecessor_decision_id: string | null;
  decision_kind: string;
  revision_id: string;
  theoretical_quantity_before: string;
  proposed_quantity_before: string;
  confirmed_quantity_after: string;
  planning_tick_count: string;
  reason_code: string;
  reason_note: string | null;
  policy_revision_id: string;
  decided_at: string;
  batch_version: number;
};

export type ConfirmedNeedLine = {
  confirmed_need_line_id: string;
  current_revision_id: string;
  current_revision_number: number;
  service_date: string;
  customer: { id: string; name: string };
  school: { id: string; name: string };
  delivery_location: { id: string; name: string };
  ingredient: { id: string; name: string };
  controlled_unit: {
    id: string;
    code: string;
    name: string;
    status: "ACTIVE" | "INACTIVE";
  };
  theoretical_quantity: string;
  proposed_confirmed_quantity: string;
  current_decision_id: string | null;
  current_decision_number: number | null;
  current_decision_kind: string | null;
  confirmed_quantity_after: string | null;
  effective_policy: {
    root_id: string;
    revision_id: string;
    revision_number: number;
    planning_step: string;
    status: string;
    effective_from: string;
    effective_to: string | null;
  } | null;
  source_membership_count: number;
  source_stale: boolean;
  blockers: ConfirmedNeedIssue[];
  warnings: ConfirmedNeedIssue[];
  decision_history: ConfirmedNeedDecisionHistory[];
};

export type ConfirmedNeedWorkbenchData = {
  confirmed_need_batch_id: string;
  source_kind: "NEED_GENERATION";
  batch_status: string;
  batch_version: number;
  need_generation_source: {
    run_id: string;
    run_version: number;
    release_snapshot_id: string;
  };
  service_period: { period_start: string; period_end: string };
  line_counts: {
    total: number;
    unreviewed: number;
    confirmed: number;
    adjusted: number;
  };
  blockers: ConfirmedNeedIssue[];
  warnings: ConfirmedNeedIssue[];
  allowed_actions: {
    preview_confirmation: boolean;
    confirm_quantities: boolean;
  };
  disabled_reasons: {
    preview_confirmation: string | null;
    confirm_quantities: string | null;
  };
  pagination: {
    offset: number;
    limit: number;
    total_lines: number;
    has_more: boolean;
  };
  lines: ConfirmedNeedLine[];
};

export type ConfirmedNeedPreviewLine = {
  confirmed_need_line_id: string;
  current_revision_id: string;
  current_revision_number: number;
  current_decision_id?: string;
  current_decision_number?: number;
  controlled_unit_id: string;
  controlled_unit_status: "ACTIVE" | "INACTIVE";
  theoretical_quantity_before: string;
  proposed_quantity_before: string;
  confirmed_quantity_after: string;
  decision_kind: string;
  reason_code: string;
  reason_note?: string;
  policy_root_id: string;
  policy_revision_id: string;
  policy_revision_number: number;
  planning_step: string;
  planning_tick_count: string;
  successor_revision_required: boolean;
  blockers: ConfirmedNeedIssue[];
  warnings: ConfirmedNeedIssue[];
};

export type ConfirmedNeedPreview = {
  success: boolean;
  error_code?: string | null;
  confirmed_need_batch_id: string;
  expected_batch_version: number;
  actual_batch_version: number;
  ordered_preview_lines: ConfirmedNeedPreviewLine[];
  blockers: ConfirmedNeedIssue[];
  warnings: ConfirmedNeedIssue[];
  preview_hash: string | null;
  write_certainty: "NO_WRITE";
};

export function exactDecimalEqual(left: string, right: string) {
  const canonical = (value: string) => {
    if (!/^(0|[1-9][0-9]{0,13})(\.[0-9]{1,6})?$/.test(value)) return null;
    const [integer, fraction = ""] = value.split(".");
    const significantFraction = fraction.replace(/0+$/, "");
    return significantFraction ? `${integer}.${significantFraction}` : integer;
  };
  const canonicalLeft = canonical(left);
  return canonicalLeft !== null && canonicalLeft === canonical(right);
}

export function confirmedNeedPreviewIsStale(preview: ConfirmedNeedPreview) {
  return [
    "STALE_CONFIRMED_NEED_BATCH",
    "STALE_CONFIRMED_NEED_LINE",
    "STALE_CONFIRMED_NEED_DECISION",
    "STALE_PLANNING_QUANTITY_POLICY",
  ].includes(preview.error_code ?? "");
}

function record(value: unknown): Record<string, unknown> | null {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : null;
}

export function confirmedNeedWorkbenchFromResult(
  result: AtlasRpcResult,
): ConfirmedNeedWorkbenchData | null {
  if (result.kind !== "success") return null;
  const value = record(result.response.workbench);
  return value as ConfirmedNeedWorkbenchData | null;
}

export function confirmedNeedPreviewFromResult(
  result: AtlasRpcResult,
): ConfirmedNeedPreview | null {
  if (result.kind !== "success") return null;
  const value = record(result.response.preview);
  return value as ConfirmedNeedPreview | null;
}

export function confirmedNeedReadbackFromResult(
  result: AtlasRpcResult,
): ConfirmedNeedWorkbenchData | null {
  if (result.kind !== "success") return null;
  const value = record(result.response.authoritative_readback);
  return value as ConfirmedNeedWorkbenchData | null;
}

export function confirmedNeedResultIsStale(result: AtlasRpcResult) {
  return (
    result.kind === "backend_error" &&
    [
      "STALE_CONFIRMED_NEED_BATCH",
      "STALE_CONFIRMED_NEED_LINE",
      "STALE_CONFIRMED_NEED_DECISION",
      "STALE_PLANNING_QUANTITY_POLICY",
      "PREVIEW_MISMATCH",
    ].includes(result.error.error_code)
  );
}

export function confirmedNeedResultAllowsExactRetry(result: AtlasRpcResult) {
  return (
    result.kind === "transport_error" ||
    (result.kind === "backend_error" && result.error.retryable === true)
  );
}

export function confirmedNeedResultMessage(result: AtlasRpcResult) {
  if (result.kind === "success")
    return (
      result.response.safe_operator_message ??
      "Đã cập nhật dữ liệu xác nhận nhu cầu."
    );
  if (result.kind === "backend_error") return result.error.safe_message;
  if (result.kind === "auth_error")
    return "Phiên làm việc đã hết. Vui lòng đăng nhập lại.";
  return result.diagnostic.safeMessage;
}

export function exactQuantityDisplay(value: string | null) {
  if (value === null) return "—";
  const [integer, fraction] = value.split(".");
  const grouped = integer.replace(/\B(?=(\d{3})+(?!\d))/g, ".");
  const trimmed = fraction?.replace(/0+$/, "");
  return trimmed ? `${grouped},${trimmed}` : grouped;
}

export function jsonRecord(value: JsonValue | undefined) {
  return record(value);
}
