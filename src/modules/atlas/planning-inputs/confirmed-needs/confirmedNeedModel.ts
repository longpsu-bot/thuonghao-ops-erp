import type { AtlasRpcResult, JsonValue } from "../../connection/atlasRpc";

export type ConfirmedNeedIssue = {
  code: string;
  message: string;
  issue_id?: string;
  validation_line_id?: string | null;
  confirmed_need_line_id?: string | null;
  severity?: "BLOCKING" | "WARNING";
  sort_position?: number;
};

export const confirmedNeedValidationBlockingCodes = [
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
] as const;

export const confirmedNeedValidationWarningCodes = [
  "ZERO_CONFIRMED_QUANTITY",
  "UPSTREAM_WARNING_RETAINED",
] as const;

export type ConfirmedNeedValidationIssue = Omit<
  ConfirmedNeedIssue,
  "code" | "severity"
> &
  (
    | {
        code: (typeof confirmedNeedValidationBlockingCodes)[number];
        severity: "BLOCKING";
      }
    | {
        code: (typeof confirmedNeedValidationWarningCodes)[number];
        severity: "WARNING";
      }
  );

export type ConfirmedNeedValidationSummary = {
  latest_attempt_id: string | null;
  latest_attempt_number: number | null;
  latest_outcome: "VALIDATED" | "BLOCKED" | null;
  evaluated_version: number | null;
  resulting_version: number | null;
  evaluated_actor: { id: string; name: string } | null;
  evaluated_at: string | null;
  validated_actor: { id: string; name: string } | null;
  validated_at: string | null;
  validation_fingerprint: string | null;
  blocking_count: number;
  warning_count: number;
  grouped_issues: {
    blocking: ConfirmedNeedValidationIssue[];
    warnings: ConfirmedNeedValidationIssue[];
  };
};

export type ConfirmedNeedLifecycleActor = { id: string; name: string };

export type ConfirmedNeedApprovalSummary = {
  current_snapshot_id: string | null;
  approved_version: number | null;
  source_validated_version: number | null;
  validation_attempt_id: string | null;
  validation_attempt_fingerprint: string | null;
  validated_fact_fingerprint: string | null;
  approved_actor: ConfirmedNeedLifecycleActor | null;
  approved_at: string | null;
  line_count: number;
  warning_count: number;
};

export type ConfirmedNeedReleaseSummary = {
  current_release_id: string | null;
  approval_snapshot_id: string | null;
  source_approved_version: number | null;
  resulting_released_version: number | null;
  released_actor: ConfirmedNeedLifecycleActor | null;
  released_at: string | null;
};

export type ConfirmedNeedLifecycleHistoryItem = {
  evidence_kind: "VALIDATION" | "APPROVAL" | "RELEASE";
  evidence_id: string;
  outcome: string;
  source_version: number;
  resulting_version: number;
  actor: ConfirmedNeedLifecycleActor;
  occurred_at: string;
  reason_code: string;
  warning_count: number;
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

export const confirmedNeedReasonLabels = {
  PROPOSAL_ACCEPTED: "Chấp nhận đề xuất",
  PLANNING_STEP_ADJUSTMENT: "Điều chỉnh theo bước lượng",
  OPERATIONAL_QUANTITY_ADJUSTMENT: "Điều chỉnh vận hành",
  OTHER: "Lý do khác",
} as const satisfies Record<ConfirmedNeedDraftLine["reason_code"], string>;

export type ConfirmedNeedReasonCode = ConfirmedNeedDraftLine["reason_code"];

export function confirmedNeedReasonLabel(code: string | null | undefined) {
  return code && code in confirmedNeedReasonLabels
    ? confirmedNeedReasonLabels[code as ConfirmedNeedReasonCode]
    : "Chưa chọn lý do";
}

export function confirmedNeedReasonCodeFromLabel(value: string) {
  return (Object.entries(confirmedNeedReasonLabels).find(
    ([, label]) => label === value,
  )?.[0] ?? null) as ConfirmedNeedReasonCode | null;
}

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
  confirmation_state:
    "CARRIED_FORWARD" | "CHANGED" | "NEW" | "UNREVIEWED" | "CONFIRMED_CURRENT";
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
  validation_issues: {
    blocking: ConfirmedNeedValidationIssue[];
    warnings: ConfirmedNeedValidationIssue[];
  };
  decision_history: ConfirmedNeedDecisionHistory[];
};

export function initialConfirmedNeedDraft(
  line: ConfirmedNeedLine,
): ConfirmedNeedDraftLine {
  const currentDecision = line.decision_history.find(
    (decision) => decision.decision_id === line.current_decision_id,
  );
  const reasonCode = currentDecision?.reason_code;
  return {
    selected: line.current_decision_id === null,
    exact_quantity:
      line.confirmed_quantity_after ?? line.proposed_confirmed_quantity,
    reason_code:
      reasonCode && reasonCode in confirmedNeedReasonLabels
        ? (reasonCode as ConfirmedNeedReasonCode)
        : line.confirmed_quantity_after &&
            !exactDecimalEqual(
              line.confirmed_quantity_after,
              line.proposed_confirmed_quantity,
            )
          ? "PLANNING_STEP_ADJUSTMENT"
          : "PROPOSAL_ACCEPTED",
    reason_note: currentDecision?.reason_note ?? "",
  };
}

export type ConfirmedNeedWorkbenchData = {
  confirmed_need_batch_id: string;
  source_kind: "NEED_GENERATION";
  batch_status: string;
  batch_version: number;
  authoritative_batch_status: string;
  editing_allowed: boolean;
  validation_allowed: boolean;
  validation_disabled_reason: string | null;
  validation: ConfirmedNeedValidationSummary;
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
    carried_forward: number;
    needs_review: number;
    changed: number;
    new: number;
    removed: number;
  };
  blockers: ConfirmedNeedIssue[];
  warnings: ConfirmedNeedIssue[];
  allowed_actions: {
    preview_confirmation: boolean;
    confirm_quantities: boolean;
    approve_confirmed_needs: boolean;
    release_confirmed_needs_for_purchase_handoff: boolean;
    save_confirmed_needs: boolean;
    release_confirmed_needs: boolean;
  };
  disabled_reason_codes: {
    approve_confirmed_needs: string | null;
    release_confirmed_needs_for_purchase_handoff: string | null;
    save_confirmed_needs: string | null;
    release_confirmed_needs: string | null;
  };
  disabled_reasons: {
    preview_confirmation: string | null;
    confirm_quantities: string | null;
    approve_confirmed_needs: string | null;
    release_confirmed_needs_for_purchase_handoff: string | null;
    save_confirmed_needs: string | null;
    release_confirmed_needs: string | null;
  };
  approval: ConfirmedNeedApprovalSummary;
  release: ConfirmedNeedReleaseSummary;
  facts_changed_since_validation: boolean | null;
  facts_changed_since_approval: boolean | null;
  lifecycle_history: ConfirmedNeedLifecycleHistoryItem[];
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

export function normalizeConfirmedNeedQuantity(value: string) {
  const trimmed = value.trim();
  const normalized =
    trimmed.includes(",") && !trimmed.includes(".")
      ? trimmed.replace(",", ".")
      : trimmed;
  if (!/^(0|[1-9][0-9]{0,13})(\.[0-9]{1,6})?$/.test(normalized)) return null;
  return normalized;
}

function decimalParts(value: string) {
  const normalized = normalizeConfirmedNeedQuantity(value);
  if (!normalized) return null;
  const [integer, fraction = ""] = normalized.split(".");
  return BigInt(`${integer}${fraction.padEnd(6, "0")}`);
}

export function subtractExactDecimals(left: string, right: string) {
  const leftValue = decimalParts(left);
  const rightValue = decimalParts(right);
  if (leftValue === null || rightValue === null) return null;
  const difference = leftValue - rightValue;
  if (difference === 0n) return "0";
  const sign = difference < 0n ? "-" : "+";
  const absolute = (difference < 0n ? -difference : difference)
    .toString()
    .padStart(7, "0");
  const integer = absolute.slice(0, -6).replace(/^0+(?=\d)/, "");
  const fraction = absolute.slice(-6).replace(/0+$/, "");
  return `${sign}${integer}${fraction ? `.${fraction}` : ""}`;
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

export function confirmedNeedLifecycleRequiresRefresh(result: AtlasRpcResult) {
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
  if (result.kind === "backend_error")
    return result.error.error_code === "CAPABILITY_DENIED"
      ? "Bạn không có quyền truy cập nhu cầu xác nhận này."
      : result.error.safe_message;
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

export function confirmedNeedConfirmationStateLabel(
  state: ConfirmedNeedLine["confirmation_state"],
) {
  const labels: Record<ConfirmedNeedLine["confirmation_state"], string> = {
    CARRIED_FORWARD: "Giữ nguyên",
    CHANGED: "Cần rà soát",
    NEW: "Mới",
    UNREVIEWED: "Cần rà soát",
    CONFIRMED_CURRENT: "Đã lưu",
  };
  return labels[state];
}

export function jsonRecord(value: JsonValue | undefined) {
  return record(value);
}
