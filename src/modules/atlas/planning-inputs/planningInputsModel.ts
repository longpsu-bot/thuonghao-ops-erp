import type { AtlasRpcResult, JsonValue } from "../connection/atlasRpc";

export type PlanningIssue = {
  code: string;
  message: string;
  source_row_reference: string | null;
};

export type PlanningIssues = {
  blockers: PlanningIssue[];
  warnings: PlanningIssue[];
};

export type PlanningSchool = {
  school_id: string;
  school_code: string;
  school_name: string;
  school_status: "ACTIVE" | "INACTIVE";
  display_order: number;
  school_type_id: string | null;
  default_student_portions: number;
  default_teacher_portions: number;
};

export type PlanningDish = {
  dish_id: string;
  dish_code: string;
  dish_name: string;
  dish_category?: string | null;
  dish_type_id: string | null;
  dish_type_code: string | null;
  dish_type_name: string | null;
  dish_status: "DRAFT" | "ACTIVE" | "INACTIVE";
  display_order: number;
  requires_need_generation: boolean;
};

export type PlanningDishType = {
  dish_type_id: string;
  dish_type_code: string;
  dish_type_name: string;
  source_header_aliases: string[];
  display_order: number;
  dish_type_status: "ACTIVE" | "INACTIVE";
  version: number;
};

export type WeeklyMenuGoogleSource = {
  weekly_menu_google_source_id: string;
  source_code: string;
  source_name: string;
  source_status: "ACTIVE" | "INACTIVE";
  display_order: number;
};

export type MenuLine = {
  weekly_menu_line_id?: string;
  school_id: string;
  service_date: string;
  menu_slot_code: string;
  dish_id: string;
  line_status?: "ACTIVE" | "INVALID";
  source_row_reference: string | null;
};

export type AttendanceLine = {
  attendance_line_id?: string;
  school_id: string;
  service_date: string;
  student_portions: number;
  teacher_portions: number;
  line_status?: "ACTIVE" | "INVALID";
  source_row_reference: string | null;
};

export type ApprovalHistory = {
  approval_snapshot_id: string;
  version: number;
  approved_by_actor_id: string;
  approved_by_display_name: string;
  approved_at: string;
  line_count: number;
};

export type ChangeHistory = {
  audit_event_id: string;
  event_type: string;
  version_before: number | null;
  version_after: number | null;
  actor_id: string;
  actor_display_name: string;
  reason_code: string | null;
  reason_note: string | null;
  occurred_at: string;
};

export type WeeklyMenuRecord = {
  weekly_menu_id: string;
  week_start: string;
  week_end: string;
  source_type: string;
  source_name: string;
  source_signature: string;
  weekly_menu_status:
    | "DRAFT"
    | "VALIDATED"
    | "APPROVED"
    | "NEED_GENERATION_REQUESTED"
    | "REOPENED";
  row_count: number;
  version: number;
  latest_approved_at: string | null;
  latest_approval_snapshot_id: string | null;
  lines: MenuLine[];
  issues: PlanningIssues;
  change_history: ChangeHistory[];
  approval_history: ApprovalHistory[];
};

export type AttendanceRecord = {
  attendance_batch_id: string;
  period_start: string;
  period_end: string;
  source_type: string;
  source_name: string;
  source_signature: string;
  attendance_status:
    | "DRAFT"
    | "VALIDATED"
    | "APPROVED"
    | "USED_FOR_NEED_GENERATION"
    | "REOPENED";
  row_count: number;
  version: number;
  latest_approved_at: string | null;
  latest_approval_snapshot_id: string | null;
  lines: AttendanceLine[];
  issues: PlanningIssues;
  change_history: ChangeHistory[];
  approval_history: ApprovalHistory[];
};

export type PlanningInputsWorkbenchData = {
  week_start: string;
  week_end: string;
  dish_types: PlanningDishType[];
  google_sheet_sources: WeeklyMenuGoogleSource[];
  schools: PlanningSchool[];
  dishes: PlanningDish[];
  weekly_menu: WeeklyMenuRecord | null;
  attendance: AttendanceRecord | null;
  readiness: {
    weekly_menu_approved: boolean;
    attendance_approved: boolean;
    weekly_menu_approval_snapshot_id: string | null;
    attendance_approval_snapshot_id: string | null;
    ready: boolean;
    warnings: PlanningIssue[];
  };
  default_attendance_preview: AttendanceLine[];
};

export type PlanningPreview<T> = {
  week_start: string;
  week_end: string;
  canonical_rows: T[];
  source_signature: string;
  source_row_count: number;
  row_count: number;
  normalized_assignment_count?: number;
  normalized_row_count?: number;
  comparison: {
    new_assignments?: number;
    changed_assignments?: number;
    unchanged_assignments?: number;
    omitted_prior_assignments?: number;
    new_rows?: number;
    changed_rows?: number;
    unchanged_rows?: number;
    omitted_prior_rows?: number;
    changed_school_days: {
      school_id: string;
      service_date: string;
    }[];
  };
  issues: PlanningIssues;
  can_save: boolean;
};

function isRecord(value: unknown): value is Record<string, JsonValue> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export function planningWorkbenchFromResult(
  result: AtlasRpcResult,
): PlanningInputsWorkbenchData | null {
  if (result.kind !== "success" || !isRecord(result.response.workbench))
    return null;
  const workbench = result.response.workbench;
  if (
    !Array.isArray(workbench.schools) ||
    !Array.isArray(workbench.dishes) ||
    !Array.isArray(workbench.dish_types) ||
    !Array.isArray(workbench.google_sheet_sources) ||
    !Array.isArray(workbench.default_attendance_preview) ||
    !isRecord(workbench.readiness)
  )
    return null;
  return workbench as unknown as PlanningInputsWorkbenchData;
}

export function planningPreviewFromResult<T>(
  result: AtlasRpcResult,
): PlanningPreview<T> | null {
  if (result.kind !== "success" || !isRecord(result.response.preview))
    return null;
  const preview = result.response.preview;
  if (!Array.isArray(preview.canonical_rows) || !isRecord(preview.issues))
    return null;
  return preview as unknown as PlanningPreview<T>;
}

export function planningReadbackFromResult(
  result: AtlasRpcResult,
): PlanningInputsWorkbenchData | null {
  if (
    result.kind !== "success" ||
    !isRecord(result.response.authoritative_readback)
  )
    return null;
  const readback = result.response.authoritative_readback;
  const planningInputs = isRecord(readback.planning_inputs)
    ? readback.planning_inputs
    : readback;
  return planningInputs as unknown as PlanningInputsWorkbenchData;
}

export type PlanningSourceKind = "weekly_menu" | "attendance" | "pantry";
export type PlanningDownstreamCurrentness =
  "CURRENT" | "OUTDATED" | "NOT_GENERATED";

export function planningSourceSaveOutcome(
  source: PlanningSourceKind,
  currentness: PlanningDownstreamCurrentness,
) {
  const savedMessages: Record<PlanningSourceKind, string> = {
    weekly_menu: "Đã lưu thực đơn.",
    attendance: "Đã lưu số suất ăn.",
    pantry: "Đã lưu nhu cầu bổ sung.",
  };
  const consequenceMessages: Record<PlanningDownstreamCurrentness, string> = {
    NOT_GENERATED: "Dữ liệu này sẽ được dùng khi tạo nhu cầu.",
    CURRENT: "Nhu cầu hiện tại vẫn khớp với dữ liệu đã lưu.",
    OUTDATED: "Nhu cầu hiện tại cần cập nhật theo dữ liệu vừa lưu.",
  };
  return {
    savedMessage: savedMessages[source],
    consequenceMessage: consequenceMessages[currentness],
  };
}

export function planningResultMessage(result: AtlasRpcResult): string {
  if (result.kind === "success") {
    const backendMessage =
      typeof result.response.safe_operator_message === "string"
        ? result.response.safe_operator_message
        : null;
    if (backendMessage) return backendMessage;
    if (result.response.idempotency_status === "NO_CHANGE")
      return "Dữ liệu chuẩn hóa không thay đổi; Atlas không ghi thêm.";
    return "Đã hoàn tất và tải lại dữ liệu mới nhất.";
  }
  if (result.kind === "auth_error")
    return "Phiên làm việc đã hết. Vui lòng đăng nhập lại.";
  if (result.kind === "transport_error")
    return "Không thể kết nối với Atlas; không giả định thao tác đã thành công.";
  if (result.kind === "client_error")
    return "Thao tác chưa có trong danh mục API đã duyệt.";
  const messages: Record<string, string> = {
    CAPABILITY_DENIED: "Bạn không có quyền thực hiện thao tác này.",
    STALE_VERSION: "Dữ liệu đã thay đổi. Hãy tải lại trước khi lưu.",
    STALE_SOURCE_SIGNATURE:
      "Nguồn dữ liệu đã thay đổi. Hãy xem trước và tải lại.",
    RETRYABLE_CONCURRENCY_FAILURE:
      "Dữ liệu đang được cập nhật. Có thể thử lại đúng yêu cầu.",
    VALIDATION_FAILED: "Cần xử lý hết lỗi chặn trước khi tiếp tục.",
    CHECKSUM_MISMATCH:
      "Checksum không khớp nội dung chuẩn hóa. Hãy xem trước lại.",
    INVARIANT_VIOLATION:
      "Thao tác không phù hợp trạng thái hiện tại của dữ liệu.",
  };
  return (
    messages[result.error.error_code] ??
    result.error.safe_message ??
    "Atlas đã từ chối thao tác một cách an toàn."
  );
}

export function mondayOf(date: Date) {
  const result = new Date(date);
  const day = result.getDay();
  result.setDate(result.getDate() - (day === 0 ? 6 : day - 1));
  const year = result.getFullYear();
  const month = String(result.getMonth() + 1).padStart(2, "0");
  const localDate = String(result.getDate()).padStart(2, "0");
  return `${year}-${month}-${localDate}`;
}

export function viDate(value: string) {
  const [year, month, day] = value.slice(0, 10).split("-");
  return year && month && day ? `${day}/${month}/${year}` : value;
}

export function activeMenuRows(menu: WeeklyMenuRecord | null): MenuLine[] {
  return (menu?.lines ?? []).filter(
    (line) => (line.line_status ?? "ACTIVE") === "ACTIVE",
  );
}

export function activeAttendanceRows(
  attendance: AttendanceRecord | null,
): AttendanceLine[] {
  return (attendance?.lines ?? []).filter(
    (line) => (line.line_status ?? "ACTIVE") === "ACTIVE",
  );
}

function attendanceLineKey(
  line: Pick<AttendanceLine, "school_id" | "service_date">,
) {
  return `${line.school_id}|${line.service_date}`;
}

export function attendanceWorkingRows(
  attendance: AttendanceRecord | null,
  defaultRows: AttendanceLine[],
): AttendanceLine[] {
  const rows = new Map<string, AttendanceLine>();
  for (const line of defaultRows) rows.set(attendanceLineKey(line), line);
  for (const line of activeAttendanceRows(attendance))
    rows.set(attendanceLineKey(line), line);
  return Array.from(rows.values());
}

export function attendanceNeedsConfirmation(
  attendance: AttendanceRecord | null,
  defaultRows: AttendanceLine[],
) {
  const persistedPairs = new Set(
    activeAttendanceRows(attendance).map(attendanceLineKey),
  );
  return defaultRows.some(
    (line) => !persistedPairs.has(attendanceLineKey(line)),
  );
}

export type MenuReviewChange = {
  school_id: string;
  service_date: string;
  menu_slot_code: string;
  previous_dish_id: string | null;
  proposed_dish_id: string | null;
};

export function menuReviewChanges(
  previousRows: MenuLine[],
  proposedRows: MenuLine[],
): MenuReviewChange[] {
  const key = (line: MenuLine) =>
    `${line.school_id}|${line.service_date}|${line.menu_slot_code}`;
  const previous = new Map(previousRows.map((line) => [key(line), line]));
  const proposed = new Map(proposedRows.map((line) => [key(line), line]));
  return Array.from(new Set([...previous.keys(), ...proposed.keys()]))
    .map((rowKey) => {
      const before = previous.get(rowKey);
      const after = proposed.get(rowKey);
      return {
        school_id: after?.school_id ?? before!.school_id,
        service_date: after?.service_date ?? before!.service_date,
        menu_slot_code: after?.menu_slot_code ?? before!.menu_slot_code,
        previous_dish_id: before?.dish_id ?? null,
        proposed_dish_id: after?.dish_id ?? null,
      };
    })
    .filter((change) => change.previous_dish_id !== change.proposed_dish_id)
    .sort(
      (left, right) =>
        left.service_date.localeCompare(right.service_date) ||
        left.school_id.localeCompare(right.school_id) ||
        left.menu_slot_code.localeCompare(right.menu_slot_code),
    );
}

export type AttendanceReviewChange = {
  school_id: string;
  service_date: string;
  previous_student_portions: number | null;
  proposed_student_portions: number | null;
  previous_teacher_portions: number | null;
  proposed_teacher_portions: number | null;
};

export function attendanceReviewChanges(
  previousRows: AttendanceLine[],
  proposedRows: AttendanceLine[],
): AttendanceReviewChange[] {
  const previous = new Map(
    previousRows.map((line) => [attendanceLineKey(line), line]),
  );
  const proposed = new Map(
    proposedRows.map((line) => [attendanceLineKey(line), line]),
  );
  return Array.from(new Set([...previous.keys(), ...proposed.keys()]))
    .map((rowKey) => {
      const before = previous.get(rowKey);
      const after = proposed.get(rowKey);
      return {
        school_id: after?.school_id ?? before!.school_id,
        service_date: after?.service_date ?? before!.service_date,
        previous_student_portions: before?.student_portions ?? null,
        proposed_student_portions: after?.student_portions ?? null,
        previous_teacher_portions: before?.teacher_portions ?? null,
        proposed_teacher_portions: after?.teacher_portions ?? null,
      };
    })
    .filter(
      (change) =>
        change.previous_student_portions !== change.proposed_student_portions ||
        change.previous_teacher_portions !== change.proposed_teacher_portions,
    )
    .sort(
      (left, right) =>
        left.service_date.localeCompare(right.service_date) ||
        left.school_id.localeCompare(right.school_id),
    );
}

function normalizedSearchText(value: string) {
  return value
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "")
    .replace(/\u0111/g, "d")
    .replace(/\u0110/g, "D")
    .toLocaleLowerCase("vi")
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

function isSubsequence(needle: string, haystack: string) {
  let index = 0;
  for (const character of haystack) {
    if (character === needle[index]) index += 1;
    if (index === needle.length) return true;
  }
  return needle.length === 0;
}

export function fuzzyTextMatch(query: string, ...values: string[]) {
  const terms = normalizedSearchText(query).split(" ").filter(Boolean);
  if (!terms.length) return true;
  const haystack = normalizedSearchText(values.join(" "));
  return terms.every(
    (term) => haystack.includes(term) || isSubsequence(term, haystack),
  );
}
