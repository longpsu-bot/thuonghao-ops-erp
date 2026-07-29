import type { AtlasRpcResult, JsonValue } from "../../connection/atlasRpc";

export type PantryIssue = {
  code: string;
  message: string;
  source_row_reference: string | null;
  field: string | null;
};

export type PantryPurpose = {
  pantry_need_purpose_id: string;
  purpose_code: string;
  purpose_name_vi: string;
  purpose_description: string;
  note_rule: "OPTIONAL" | "REQUIRED" | "PROHIBITED";
  purpose_status: "ACTIVE" | "INACTIVE";
  display_order: number;
  version: number;
};

export type PantrySchool = {
  school_id: string;
  school_code: string;
  school_name: string;
  school_status: string;
  display_order: number;
  customer_id: string;
  customer_name: string;
  default_delivery_location: {
    delivery_location_id: string;
    location_code: string;
    location_name: string;
    address_text: string;
    timezone_name: string;
  };
};

export type PantryIngredient = {
  ingredient_id: string;
  ingredient_code: string;
  ingredient_name: string;
  ingredient_status: string;
  purchase_unit: {
    unit_id: string;
    unit_code: string;
    unit_name: string;
  };
};

export type PantryDraftRow = {
  service_date: string;
  school_id: string;
  ingredient_id: string;
  pantry_need_purpose_id: string;
  requested_quantity: string;
  note: string;
  source_request_reference: string;
  source_row_reference: string;
};

export type PantryLine = PantryDraftRow & {
  pantry_need_line_id: string;
  school_code: string;
  school_name: string;
  delivery_location_id: string;
  delivery_location_code?: string;
  delivery_location_name: string;
  ingredient_code: string;
  ingredient_name: string;
  unit_id: string;
  unit_code: string;
  unit_name: string;
  purpose_code: string;
  purpose_name_vi: string;
  purpose_description?: string;
  purpose_note_rule?: string;
  requested_quantity: string | number;
  line_status: "ACTIVE" | "INVALID";
  updated_at: string;
};

export type PantryApprovalSnapshot = {
  pantry_need_approval_snapshot_id: string;
  approved_batch_version: number;
  approved_by_actor_id: string;
  approved_by_display_name: string;
  approved_at: string;
  source_signature: string;
  no_additions_confirmed: boolean;
  line_count: number;
  blocker_summary: PantryIssue[];
  warning_summary: PantryIssue[];
  lines: JsonValue[];
};

export type PantryChange = {
  audit_event_id: string;
  event_type: string;
  version_before: number | null;
  version_after: number;
  actor_id: string;
  actor_display_name: string;
  reason_code: string;
  reason_note: string | null;
  occurred_at: string;
};

export type PantryBatch = {
  pantry_need_batch_id: string;
  week_start: string;
  week_end: string;
  pantry_need_batch_status: "DRAFT" | "VALIDATED" | "APPROVED" | "REOPENED";
  version: number;
  source_type: "MANUAL_ATLAS";
  source_name: "Nhập thủ công Atlas";
  source_signature: string;
  no_additions_confirmed: boolean;
  requesting_actor_id: string;
  requesting_actor_name: string;
  creation_method: "MANUAL_ATLAS";
  latest_approved_by_actor_id: string | null;
  latest_approved_at: string | null;
  latest_approval_snapshot_id: string | null;
  created_at: string;
  updated_at: string;
  active_lines: PantryLine[];
  invalid_lines: PantryLine[];
  issues: { blockers: PantryIssue[]; warnings: PantryIssue[] };
  approval_history: PantryApprovalSnapshot[];
  change_history: PantryChange[];
};

export type PantryWorkbenchData = {
  week_start: string;
  week_end: string;
  source_method: {
    source_type: "MANUAL_ATLAS";
    source_name: "Nhập thủ công Atlas";
  };
  purposes: PantryPurpose[];
  schools: PantrySchool[];
  ingredients: PantryIngredient[];
  catalog_issues: { blockers: PantryIssue[]; warnings: PantryIssue[] };
  batch: PantryBatch | null;
  allowed_actions: {
    can_preview: boolean;
    can_save: boolean;
    can_validate: boolean;
    can_approve: boolean;
    can_reopen: boolean;
  };
};

export type PantryPreview = {
  week_start: string;
  week_end: string;
  source_type: "MANUAL_ATLAS";
  source_name: "Nhập thủ công Atlas";
  source_signature: string;
  no_additions_confirmed: boolean;
  canonical_rows: JsonValue[];
  issues: { blockers: PantryIssue[]; warnings: PantryIssue[] };
  comparison: {
    status: "NEW" | "NO_CHANGE" | "REPLACEMENT";
    current_batch_id: string | null;
    current_version: number | null;
    current_status: string | null;
    current_source_signature: string | null;
    new_lines: JsonValue[];
    changed_lines: JsonValue[];
    unchanged_lines: JsonValue[];
    omitted_lines: JsonValue[];
    changed_school_dates: JsonValue[];
  };
  can_save: boolean;
};

function objectValue(value: JsonValue | undefined) {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value
    : null;
}

export function pantryWorkbenchFromResult(
  result: AtlasRpcResult,
): PantryWorkbenchData | null {
  if (result.kind !== "success") return null;
  const workbench = objectValue(result.response.workbench);
  return workbench as unknown as PantryWorkbenchData | null;
}

export function pantryPreviewFromResult(
  result: AtlasRpcResult,
): PantryPreview | null {
  if (result.kind !== "success") return null;
  const preview = objectValue(result.response.preview);
  return preview as unknown as PantryPreview | null;
}

export function pantryReadbackFromResult(
  result: AtlasRpcResult,
): PantryWorkbenchData | null {
  return pantryWorkbenchFromResult(result);
}

export function pantryResultMessage(result: AtlasRpcResult) {
  if (result.kind === "success")
    return (
      (typeof result.response.safe_operator_message === "string"
        ? result.response.safe_operator_message
        : null) ?? "Thao tác Pantry đã hoàn tất."
    );
  if (result.kind === "auth_error")
    return "Phiên làm việc đã hết. Vui lòng đăng nhập lại.";
  if (result.kind === "transport_error")
    return "Không thể kết nối dịch vụ Pantry.";
  if (result.kind === "client_error")
    return "Ứng dụng đã chặn một yêu cầu Pantry không hợp lệ.";
  const messages: Record<string, string> = {
    CAPABILITY_DENIED: "Bạn không có quyền thực hiện thao tác Pantry này.",
    AUTH_SUBJECT_MISMATCH: "Phiên người dùng không khớp yêu cầu.",
    STALE_VERSION: "Tuần Pantry đã thay đổi. Hãy tải lại trước khi tiếp tục.",
    STALE_SOURCE_SIGNATURE:
      "Chữ ký nguồn Pantry đã thay đổi. Hãy xem trước lại.",
    INVALID_LIFECYCLE_STATE:
      "Thao tác không hợp lệ với trạng thái Pantry hiện tại.",
    INVARIANT_VIOLATION:
      "Dữ liệu Pantry còn lỗi chặn. Hãy sửa và xem trước lại.",
  };
  return messages[result.error.error_code] ?? result.error.safe_message;
}

export function pantryRowsFromBatch(
  batch: PantryBatch | null,
): PantryDraftRow[] {
  return (batch?.active_lines ?? []).map((line) => ({
    service_date: line.service_date,
    school_id: line.school_id,
    ingredient_id: line.ingredient_id,
    pantry_need_purpose_id: line.pantry_need_purpose_id,
    requested_quantity: String(line.requested_quantity),
    note: line.note ?? "",
    source_request_reference: line.source_request_reference ?? "",
    source_row_reference: line.source_row_reference ?? "",
  }));
}
