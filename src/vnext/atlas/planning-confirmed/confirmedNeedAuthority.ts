import type {
  ConfirmedNeedWorkbenchData,
  PlanningInputPreflightData,
} from "../bridges/confirmedNeed";
export function validPreflight(
  p: PlanningInputPreflightData | null,
  date: string,
): p is PlanningInputPreflightData {
  return Boolean(
    p &&
    p.period_start === date &&
    p.period_end === date &&
    ["READY", "BLOCKED"].includes(p.readiness_state) &&
    ["CURRENT", "OUTDATED", "NOT_GENERATED", "LEGACY_OVERLAP"].includes(
      p.downstream_currentness,
    ),
  );
}
export function validBatch(
  b: ConfirmedNeedWorkbenchData | null,
  p: PlanningInputPreflightData,
  date: string,
): b is ConfirmedNeedWorkbenchData {
  return Boolean(
    b &&
    b.confirmed_need_batch_id === p.current_need?.confirmed_need_batch_id &&
    b.need_generation_source?.run_id ===
      p.current_need?.need_generation_run_id &&
    b.service_period?.period_start <= date &&
    b.service_period.period_end >= date &&
    Array.isArray(b.lines) &&
    b.lines.length > 0 &&
    b.lines.every(
      (l) =>
        l.service_date === date &&
        l.current_revision_id &&
        l.ingredient &&
        l.school &&
        l.delivery_location &&
        l.controlled_unit,
    ) &&
    new Set(b.lines.map((l) => l.confirmed_need_line_id)).size ===
      b.lines.length &&
    b.allowed_actions &&
    b.pagination &&
    !b.pagination.has_more &&
    b.pagination.total_lines === b.lines.length &&
    Number.isInteger(b.batch_version),
  );
}
export function correctionBlocked(p: PlanningInputPreflightData | null) {
  return (
    p?.downstream_currentness === "OUTDATED" &&
    p.current_need?.confirmed_need_batch_status ===
      "RELEASED_FOR_PURCHASE_HANDOFF"
  );
}
export function noDemand(p: PlanningInputPreflightData | null) {
  return (
    p?.issues.some((i) => i.issue_code === "NO_NEED_SOURCE_FOR_SERVICE_DATE") ??
    false
  );
}
export function preflightMessage(p: PlanningInputPreflightData | null) {
  if (!p) return "Chưa tải được dữ liệu cho ngày phục vụ.";
  if (p.downstream_currentness === "LEGACY_OVERLAP")
    return "Ngày này thuộc nhu cầu đã lập trước đây. Nhu cầu lịch sử vẫn có hiệu lực; không thể tạo đè tại đây.";
  if (correctionBlocked(p))
    return "Nhu cầu đã được chuyển sang mua hàng. Cần dùng quy trình điều chỉnh hiện có; không thể cập nhật trực tiếp tại đây.";
  if (noDemand(p)) return "Không có nhu cầu cần lập cho ngày này.";
  if (p.readiness_state === "BLOCKED")
    return (
      preflightIssueCopy[
        p.issues.find((i) => i.severity === "BLOCKING")?.issue_code ?? ""
      ] ?? "Cần kiểm tra dữ liệu nguồn trước khi tạo nhu cầu."
    );
  if (p.downstream_currentness === "OUTDATED")
    return "Dữ liệu nguồn đã thay đổi sau lần tính gần nhất.";
  return "Dữ liệu đã sẵn sàng.";
}

// Presentation mapping only; returned backend issue evidence is kept intact.
const preflightIssueCopy: Record<string, string> = {
  MISSING_WEEKLY_MENU_APPROVAL_SNAPSHOT:
    "Chưa có thực đơn đã lưu cho ngày này.",
  MISSING_ATTENDANCE_APPROVAL_SNAPSHOT:
    "Chưa có sĩ số đã xác nhận cho ngày này.",
  MISSING_PANTRY_APPROVAL_SNAPSHOT:
    "Chưa có dữ liệu Hàng đặt riêng đã xác nhận cho ngày này.",
  ATTENDANCE_MISSING: "Cần lưu sĩ số trước khi tạo nhu cầu.",
  SOURCE_SNAPSHOT_OWNERSHIP_MISMATCH:
    "Dữ liệu nguồn không thuộc đúng phạm vi cần xử lý.",
  WEEKLY_MENU_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD:
    "Thực đơn đã lưu chưa có ngày này.",
  ATTENDANCE_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD:
    "Sĩ số đã lưu chưa có ngày này.",
  PANTRY_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD:
    "Hàng đặt riêng đã xác nhận chưa có ngày này.",
  STALE_OR_MISMATCHED_SNAPSHOT_BINDING:
    "Dữ liệu nguồn đã thay đổi. Hãy làm mới trước khi tiếp tục.",
  REQUEST_WITHOUT_CURRENT_READY_EVALUATION:
    "Dữ liệu nguồn chưa sẵn sàng để tạo nhu cầu.",
  MENU_SCHOOL_DATE_WITHOUT_ATTENDANCE:
    "Có thực đơn nhưng chưa có sĩ số cho trường và ngày này.",
  ATTENDANCE_SCHOOL_DATE_WITHOUT_MENU:
    "Có sĩ số nhưng chưa có thực đơn cho trường và ngày này.",
  ZERO_ATTENDANCE_FOR_PLANNED_MENU:
    "Thực đơn đã có nhưng tổng sĩ số của trường và ngày này bằng 0.",
  AMBIGUOUS_WEEKLY_MENU_SOURCE:
    "Có nhiều thực đơn phù hợp. Cần kiểm tra nguồn trước khi tiếp tục.",
  STALE_WEEKLY_MENU_SOURCE:
    "Thực đơn đã thay đổi. Hãy làm mới trước khi tiếp tục.",
  AMBIGUOUS_ATTENDANCE_SOURCE:
    "Có nhiều bản sĩ số phù hợp. Cần kiểm tra nguồn trước khi tiếp tục.",
  STALE_ATTENDANCE_SOURCE: "Sĩ số đã thay đổi. Hãy làm mới trước khi tiếp tục.",
  AMBIGUOUS_PANTRY_SOURCE:
    "Có nhiều bản Hàng đặt riêng phù hợp. Cần kiểm tra nguồn trước khi tiếp tục.",
  STALE_PANTRY_SOURCE:
    "Hàng đặt riêng đã thay đổi. Hãy làm mới trước khi tiếp tục.",
};
export function mondayOf(date: string) {
  const day = new Date(`${date}T12:00:00Z`);
  day.setUTCDate(day.getUTCDate() - ((day.getUTCDay() + 6) % 7));
  return day.toISOString().slice(0, 10);
}
export function weekDates(week: string) {
  return Array.from({ length: 7 }, (_, i) => {
    const d = new Date(`${week}T12:00:00Z`);
    d.setUTCDate(d.getUTCDate() + i);
    return d.toISOString().slice(0, 10);
  });
}
