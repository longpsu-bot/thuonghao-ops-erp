import {
  useCallback,
  createContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  useContext,
  type ComponentType,
  type ComponentProps,
} from "react";
import { Box, Button, MantineProvider, Paper } from "@mantine/core";
import {
  ArrowClockwise,
  CloudArrowDown,
  Eye,
  FloppyDisk,
  UploadSimple,
} from "@phosphor-icons/react";
import { atlasTheme } from "../../../theme";
import type { AtlasAuthState } from "../connection/authSession";
import type { AtlasRpcResult, JsonValue } from "../connection/atlasRpc";
import {
  Chip,
  CompactTable,
  OperationalState,
  Panel,
  WorkbenchHeader,
} from "../WorkbenchComponents";
import {
  attendanceCompletionRequest,
  type PlanningInputsApi,
  weeklyMenuCompletionRequest,
} from "./planningInputsApi";
import {
  activeAttendanceRows,
  activeMenuRows,
  attendanceNeedsConfirmation,
  attendanceReviewChanges,
  attendanceWorkingRows,
  fuzzyTextMatch,
  menuReviewChanges,
  mondayOf,
  planningPreviewFromResult,
  planningReadbackFromResult,
  planningResultMessage,
  planningSourceSaveOutcome,
  planningWorkbenchFromResult,
  viDate,
  type AttendanceLine,
  type ChangeHistory,
  type MenuLine,
  type PlanningInputsWorkbenchData,
  type PlanningIssue,
  type PlanningPreview,
  type AttendanceRecord,
  type WeeklyMenuRecord,
} from "./planningInputsModel";
import {
  parseAttendancePaste,
  parseMenuMatrix,
  parseMenuWorkbook,
  type SourceMatrix,
} from "./planningInputsWorkbook";
import { PantryWorkbench } from "./pantry/PantryWorkbench";
import type { PantryApi } from "./pantry/pantryApi";
import { createPlanningInputReadinessApi } from "./readiness/planningInputReadinessApi";
import {
  planningInputPreflightFromResult,
  type PlanningInputPreflightData,
} from "./readiness/planningInputReadinessModel";
import { NeedGenerationWorkbench } from "./need-generation/NeedGenerationWorkbench";
import type { NeedGenerationApi } from "./need-generation/needGenerationApi";
import { ConfirmedNeedReviewWorkbench } from "./confirmed-needs/ConfirmedNeedReviewWorkbench";
import type { ConfirmedNeedApi } from "./confirmed-needs/confirmedNeedApi";
import { PlanningCorrectionImpactPanel } from "./PlanningCorrectionImpactPanel";
import {
  planningCorrectionImpactFromResult,
  safeNoDownstreamImpact,
  type PlanningCorrectionChain,
  type PlanningCorrectionImpact,
} from "./planningCorrectionApi";

type TabId =
  "menu" | "attendance" | "pantry" | "need-generation" | "confirmed-needs";
type LoadState = "idle" | "loading" | "ready" | "error";
type ConfirmedNeedProjectionResolution =
  "idle" | "loading" | "ready" | "denied" | "error";
type DailyConfirmedNeedSelection = {
  serviceDate: string;
  batchId: string;
};
type MenuSourceType = "MANUAL" | "WORKBOOK_IMPORT" | "GOOGLE_SHEET";
type GoogleFetchState = {
  status: "idle" | "fetching" | "success" | "error";
  sourceName?: string;
  sheetName?: string;
  fetchedAt?: string;
  sourceRowCount?: number;
  errorCode?: string;
};

export type AtlasDatePickerInputProps = {
  label: string;
  "aria-label": string;
  value: string;
  valueFormat: string;
  locale: string;
  firstDayOfWeek: 1;
  onChange: (value: string | Date | null) => void;
};

export const AtlasDatePickerInputContext =
  createContext<ComponentType<AtlasDatePickerInputProps> | null>(null);

function statusTone(status?: string) {
  if (
    [
      "APPROVED",
      "NEED_GENERATION_REQUESTED",
      "USED_FOR_NEED_GENERATION",
    ].includes(status ?? "")
  )
    return "ok" as const;
  if (status === "VALIDATED") return "neutral" as const;
  return "warning" as const;
}

function statusLabel(status?: string) {
  const labels: Record<string, string> = {
    DRAFT: "CHƯA LƯU HOÀN TẤT",
    VALIDATED: "CẦN LƯU HOÀN TẤT",
    APPROVED: "ĐÃ LƯU",
    REOPENED: "ĐANG CHỈNH SỬA",
    NEED_GENERATION_REQUESTED: "ĐÃ LƯU",
    USED_FOR_NEED_GENERATION: "ĐÃ LƯU",
  };
  return status ? (labels[status] ?? status) : "CHƯA CÓ";
}

function googleResultMessage(result: AtlasRpcResult) {
  if (result.kind === "success")
    return "Đã tải nguồn Google Sheet để xem trước.";
  if (result.kind === "auth_error")
    return "Phiên làm việc đã hết. Vui lòng đăng nhập lại.";
  if (result.kind === "transport_error")
    return "Không thể kết nối bộ đồng bộ Google Sheet.";
  if (result.kind === "client_error")
    return "Bộ đồng bộ Google Sheet chưa sẵn sàng trong môi trường này.";
  const messages: Record<string, string> = {
    CAPABILITY_DENIED: "Bạn không có quyền đọc nguồn Kế hoạch.",
    GOOGLE_SOURCE_UNAVAILABLE:
      "Nguồn Google Sheet không tồn tại hoặc đã ngừng hoạt động.",
    WEEKLY_SHEET_MISSING: "Không tìm thấy trang tính của tuần đã chọn.",
    EMPTY_SHEET: "Trang tính của tuần đã chọn không có dữ liệu.",
    GOOGLE_CREDENTIAL_MISSING:
      "Bộ đồng bộ chưa được cấu hình thông tin xác thực Google.",
    SPREADSHEET_INACCESSIBLE: "Bộ đồng bộ không thể đọc bảng tính đã cấu hình.",
    GOOGLE_UPSTREAM_RETRYABLE:
      "Google Sheets tạm thời không sẵn sàng. Có thể thử lại.",
    CONNECTOR_UNAVAILABLE: "Bộ đồng bộ Google Sheet hiện không sẵn sàng.",
  };
  return messages[result.error.error_code] ?? result.error.safe_message;
}

function recordValue(value: JsonValue | undefined) {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value
    : null;
}

function issueMessage(issue: PlanningIssue) {
  const messages: Record<string, string> = {
    EMPTY_WEEKLY_MENU: "Thực đơn tuần chưa có phân công hợp lệ.",
    EMPTY_ATTENDANCE: "Sĩ số tuần chưa có dòng hợp lệ.",
    INVALID_SCHOOL_ID: "Dòng dữ liệu chưa xác định được trường.",
    UNKNOWN_SCHOOL: "Trường tham chiếu không tồn tại.",
    INACTIVE_SCHOOL: "Trường tham chiếu đã ngừng hoạt động.",
    INVALID_DISH_ID: "Dòng dữ liệu chưa xác định được món ăn.",
    UNKNOWN_DISH: "Món ăn tham chiếu không tồn tại.",
    INACTIVE_DISH: "Món ăn tham chiếu đã ngừng hoạt động.",
    INVALID_SERVICE_DATE: "Ngày phục vụ không hợp lệ.",
    SERVICE_DATE_OUTSIDE_WEEK: "Ngày phục vụ nằm ngoài tuần đã chọn.",
    INVALID_MENU_SLOT: "Ô thực đơn không thuộc Loại món được cấu hình.",
    UNKNOWN_DISH_TYPE: "Loại món của ô thực đơn không tồn tại.",
    INACTIVE_DISH_TYPE: "Loại món của ô thực đơn đã ngừng hoạt động.",
    UNMAPPED_DISH_TYPE: "Món ăn chưa được gán Loại món.",
    DISH_TYPE_MISMATCH: "Món ăn không khớp Loại món của cột thực đơn.",
    DUPLICATE_MENU_ASSIGNMENT: "Trùng trường, ngày và ô thực đơn.",
    DUPLICATE_ATTENDANCE_ASSIGNMENT: "Trùng trường và ngày trong sĩ số.",
    INVALID_STUDENT_PORTIONS:
      "Số suất học sinh phải là số nguyên không âm được nhập rõ ràng.",
    INVALID_TEACHER_PORTIONS:
      "Số suất giáo viên phải là số nguyên không âm được nhập rõ ràng.",
    RECIPE_NOT_READY:
      "Món ăn chưa có công thức phát hành phù hợp cho loại trường.",
    EFFECTIVE_BOM_BLOCKED:
      "Thành phần công thức hiệu lực của món ăn hiện đang bị chặn.",
    SUSPICIOUS_DUPLICATE_DISH:
      "Một món ăn xuất hiện ở nhiều ô trong cùng trường và ngày.",
    IGNORED_BLANK_SOURCE_ROWS: "Đã bỏ qua các dòng nguồn trống vô hại.",
    DIFFERS_FROM_APPROVED_MENU:
      "Phân công khác lần phê duyệt thực đơn gần nhất.",
    OMITS_APPROVED_MENU_ASSIGNMENT:
      "Bản nháp bỏ một phân công trong lần phê duyệt gần nhất.",
    ZERO_TOTAL_PORTIONS: "Tổng suất học sinh và giáo viên của dòng này bằng 0.",
    PORTIONS_DIFFER_FROM_DEFAULT: "Số suất khác mặc định hiện tại của trường.",
    DIFFERS_FROM_APPROVED_ATTENDANCE:
      "Số suất khác lần phê duyệt sĩ số gần nhất.",
    OMITS_APPROVED_ATTENDANCE:
      "Bản nháp bỏ một dòng trong lần phê duyệt gần nhất.",
    MENU_ASSIGNMENT_WITHOUT_ATTENDANCE:
      "Có phân công thực đơn nhưng chưa có dòng sĩ số tương ứng.",
    ATTENDANCE_WITHOUT_MENU_ASSIGNMENT:
      "Có dòng sĩ số nhưng chưa có phân công thực đơn tương ứng.",
  };
  return messages[issue.code] ?? issue.message;
}

function Issues({
  title,
  issues,
  tone,
}: {
  title: string;
  issues: PlanningIssue[];
  tone: "danger" | "warning";
}) {
  if (!issues.length) return null;
  return (
    <section className={`planning-issues ${tone}`}>
      <strong>
        {title} ({issues.length})
      </strong>
      <ul>
        {issues.map((item, index) => (
          <li key={`${item.code}:${item.source_row_reference}:${index}`}>
            {issueMessage(item)}
            {item.source_row_reference && (
              <small>{item.source_row_reference}</small>
            )}
          </li>
        ))}
      </ul>
    </section>
  );
}

function SourceSummary({
  source,
}: {
  source: WeeklyMenuRecord | AttendanceRecord | null;
}) {
  if (!source) return null;
  const latest = source.approval_history[0];
  return (
    <details className="planning-evidence">
      <summary>Bằng chứng nguồn hiện tại</summary>
      <section
        className="planning-source-summary"
        aria-label="Bằng chứng nguồn"
      >
        <div>
          <span>Nguồn</span>
          <b>{source.source_name}</b>
        </div>
        <div>
          <span>Chữ ký nguồn</span>
          <code>{source.source_signature}</code>
        </div>
        <div>
          <span>Phiên bản / dòng</span>
          <b>
            {source.version} / {source.row_count}
          </b>
        </div>
        <div>
          <span>Phê duyệt gần nhất</span>
          <b>
            {latest
              ? `${latest.approved_by_display_name} · ${new Date(latest.approved_at).toLocaleString("vi-VN")}`
              : "Chưa có"}
          </b>
        </div>
      </section>
    </details>
  );
}

function TechnicalPreviewSummary<T>({
  preview,
  kind,
  schools,
}: {
  preview: PlanningPreview<T> | null;
  kind: "menu" | "attendance";
  schools: PlanningInputsWorkbenchData["schools"];
}) {
  if (!preview) return null;
  const comparison = preview.comparison ?? { changed_school_days: [] };
  const counts =
    kind === "menu"
      ? [
          ["Mới", comparison.new_assignments ?? 0],
          ["Đổi", comparison.changed_assignments ?? 0],
          ["Không đổi", comparison.unchanged_assignments ?? 0],
          ["Bỏ khỏi bản nháp", comparison.omitted_prior_assignments ?? 0],
        ]
      : [
          ["Mới", comparison.new_rows ?? 0],
          ["Đổi", comparison.changed_rows ?? 0],
          ["Không đổi", comparison.unchanged_rows ?? 0],
          ["Bỏ khỏi bản nháp", comparison.omitted_prior_rows ?? 0],
        ];
  return (
    <details className="planning-preview-summary">
      <summary>Chi tiết đối chiếu kỹ thuật</summary>
      <div className="planning-preview-counts">
        {counts.map(([label, value]) => (
          <span key={label}>
            {label}: <b>{value}</b>
          </span>
        ))}
      </div>
      <code>{preview.source_signature}</code>
      {comparison.changed_school_days?.length > 0 && (
        <p>
          Trường/ngày thay đổi:{" "}
          {comparison.changed_school_days
            .map((day) => {
              const school = schools.find(
                (item) => item.school_id === day.school_id,
              );
              return `${school?.school_name ?? day.school_id} · ${viDate(day.service_date)}`;
            })
            .join("; ")}
        </p>
      )}
    </details>
  );
}

function ReviewSummary<T>({
  preview,
  kind,
  schools,
  dishes,
  dishTypes,
  previousMenuRows,
  previousAttendanceRows,
}: {
  preview: PlanningPreview<T> | null;
  kind: "menu" | "attendance";
  schools: PlanningInputsWorkbenchData["schools"];
  dishes: PlanningInputsWorkbenchData["dishes"];
  dishTypes: PlanningInputsWorkbenchData["dish_types"];
  previousMenuRows: MenuLine[];
  previousAttendanceRows: AttendanceLine[];
}) {
  if (!preview) return null;
  const menuChanges =
    kind === "menu"
      ? menuReviewChanges(
          previousMenuRows,
          preview.canonical_rows as MenuLine[],
        )
      : [];
  const attendanceChanges =
    kind === "attendance"
      ? attendanceReviewChanges(
          previousAttendanceRows,
          preview.canonical_rows as AttendanceLine[],
        )
      : [];
  const schoolName = (schoolId: string) =>
    schools.find((school) => school.school_id === schoolId)?.school_name ??
    schoolId;
  const dishName = (dishId: string | null) =>
    dishId
      ? (dishes.find((dish) => dish.dish_id === dishId)?.dish_name ?? dishId)
      : "—";
  const dishTypeName = (dishTypeCode: string) =>
    dishTypes.find((dishType) => dishType.dish_type_code === dishTypeCode)
      ?.dish_type_name ?? dishTypeCode;
  const quantity = (value: number | null) =>
    value === null ? "—" : Number.isFinite(value) ? value : "Cần nhập";

  return (
    <section
      className="planning-review"
      aria-label={
        kind === "menu" ? "Xem thay đổi thực đơn" : "Xem thay đổi sĩ số"
      }
    >
      <div className="planning-review-heading">
        <strong>Xem thay đổi</strong>
        <span>Đã rà soát với dữ liệu hiện đang lưu</span>
      </div>
      {kind === "menu" && menuChanges.length > 0 && (
        <div className="planning-review-table-scroll">
          <CompactTable
            headers={[
              "Trường",
              "Ngày phục vụ",
              "Bữa / Loại món",
              "Món trước",
              "Món sẽ lưu",
              "Thay đổi",
            ]}
          >
            {menuChanges.map((change) => (
              <tr
                key={`${change.school_id}:${change.service_date}:${change.menu_slot_code}`}
              >
                <th scope="row">{schoolName(change.school_id)}</th>
                <td>{viDate(change.service_date)}</td>
                <td>{dishTypeName(change.menu_slot_code)}</td>
                <td>{dishName(change.previous_dish_id)}</td>
                <td>{dishName(change.proposed_dish_id)}</td>
                <td>
                  {change.previous_dish_id === null
                    ? "Thêm"
                    : change.proposed_dish_id === null
                      ? "Bỏ"
                      : "Đổi"}
                </td>
              </tr>
            ))}
          </CompactTable>
        </div>
      )}
      {kind === "attendance" && attendanceChanges.length > 0 && (
        <div className="planning-review-table-scroll">
          <CompactTable
            headers={[
              "Trường",
              "Ngày phục vụ",
              "Học sinh trước",
              "Học sinh sẽ lưu",
              "Giáo viên trước",
              "Giáo viên sẽ lưu",
            ]}
          >
            {attendanceChanges.map((change) => (
              <tr key={`${change.school_id}:${change.service_date}`}>
                <th scope="row">{schoolName(change.school_id)}</th>
                <td>{viDate(change.service_date)}</td>
                <td>{quantity(change.previous_student_portions)}</td>
                <td>{quantity(change.proposed_student_portions)}</td>
                <td>{quantity(change.previous_teacher_portions)}</td>
                <td>{quantity(change.proposed_teacher_portions)}</td>
              </tr>
            ))}
          </CompactTable>
        </div>
      )}
      {((kind === "menu" && menuChanges.length === 0) ||
        (kind === "attendance" && attendanceChanges.length === 0)) && (
        <p className="planning-review-empty">
          Không có khác biệt nghiệp vụ so với dữ liệu hiện đang lưu.
        </p>
      )}
      <TechnicalPreviewSummary
        preview={preview}
        kind={kind}
        schools={schools}
      />
    </section>
  );
}

function History({
  entries,
}: {
  entries: {
    approval_snapshot_id: string;
    version: number;
    approved_by_display_name: string;
    approved_at: string;
    line_count: number;
  }[];
}) {
  if (!entries.length) return null;
  return (
    <details className="planning-history">
      <summary>Lịch sử phê duyệt ({entries.length})</summary>
      <ul>
        {entries.map((entry) => (
          <li key={entry.approval_snapshot_id}>
            <b>Phiên bản {entry.version}</b> · {entry.line_count} dòng ·{" "}
            {entry.approved_by_display_name} ·{" "}
            {new Date(entry.approved_at).toLocaleString("vi-VN")}
          </li>
        ))}
      </ul>
    </details>
  );
}

function changeLabel(eventType: string) {
  const labels: Record<string, string> = {
    WeeklyMenuDraftCreated: "Tạo bản nháp thực đơn",
    WeeklyMenuDraftReplaced: "Thay nội dung bản nháp thực đơn",
    WeeklyMenuValidated: "Xác thực thực đơn",
    WeeklyMenuApproved: "Phê duyệt thực đơn",
    WeeklyMenuReopened: "Mở lại thực đơn",
    AttendanceDraftCreated: "Tạo bản nháp số suất ăn",
    AttendanceDraftReplaced: "Thay nội dung bản nháp số suất ăn",
    AttendanceValidated: "Xác thực số suất ăn",
    AttendanceApproved: "Phê duyệt số suất ăn",
    AttendanceReopened: "Mở lại số suất ăn",
  };
  return labels[eventType] ?? eventType;
}

function ChangeTimeline({ entries }: { entries: ChangeHistory[] }) {
  if (!entries.length) return null;
  return (
    <details className="planning-history">
      <summary>Nhật ký thay đổi ({entries.length})</summary>
      <ul>
        {entries.map((entry) => (
          <li key={entry.audit_event_id}>
            <b>{changeLabel(entry.event_type)}</b> · phiên bản{" "}
            {entry.version_before ?? "—"} → {entry.version_after ?? "—"} ·{" "}
            {entry.actor_display_name} ·{" "}
            {new Date(entry.occurred_at).toLocaleString("vi-VN")}
            {entry.reason_note && <small>{entry.reason_note}</small>}
          </li>
        ))}
      </ul>
    </details>
  );
}

function weekEndOf(weekStart: string) {
  return addLocalCalendarDays(weekStart, 6);
}

function dailyServiceDates(weekStart: string, weekEnd: string) {
  const dates: string[] = [];
  const cursor = new Date(`${weekStart}T00:00:00Z`);
  const end = new Date(`${weekEnd}T00:00:00Z`);
  while (cursor <= end && dates.length < 7) {
    dates.push(cursor.toISOString().slice(0, 10));
    cursor.setUTCDate(cursor.getUTCDate() + 1);
  }
  return dates;
}

function confirmedNeedDateStatus(preflight: PlanningInputPreflightData) {
  if (preflight.downstream_currentness === "LEGACY_OVERLAP")
    return "Vướng nhu cầu cũ đang có hiệu lực";
  const currentNeed = preflight.current_need;
  if (!currentNeed)
    return preflight.readiness_state === "BLOCKED"
      ? "Chưa có nhu cầu · nguồn cần xử lý"
      : "Chưa tạo nhu cầu";
  const released =
    currentNeed.confirmed_need_batch_status === "RELEASED_FOR_PURCHASE_HANDOFF";
  if (preflight.downstream_currentness === "OUTDATED")
    return released
      ? "Đã chuyển sang lên đơn · nguồn đã thay đổi"
      : "Nhu cầu cần cập nhật";
  if (released) return "Đã chuyển sang lên đơn";
  if (
    ["DRAFT_REVIEW", "REOPENED"].includes(
      currentNeed.confirmed_need_batch_status,
    )
  )
    return "Cần rà soát";
  return "Có nhu cầu xác nhận";
}

function addLocalCalendarDays(isoDate: string, days: number) {
  const [year, month, day] = isoDate.split("-").map(Number);
  const shifted = new Date(year!, month! - 1, day! + days);
  return `${shifted.getFullYear()}-${String(shifted.getMonth() + 1).padStart(2, "0")}-${String(shifted.getDate()).padStart(2, "0")}`;
}

function localMondayOfIso(isoDate: string) {
  const [year, month, day] = isoDate.split("-").map(Number);
  return mondayOf(new Date(year!, month! - 1, day!));
}

function emptyData(weekStart: string): PlanningInputsWorkbenchData {
  return {
    week_start: weekStart,
    week_end: weekEndOf(weekStart),
    dish_types: [],
    google_sheet_sources: [],
    schools: [],
    dishes: [],
    weekly_menu: null,
    attendance: null,
    readiness: {
      weekly_menu_approved: false,
      attendance_approved: false,
      weekly_menu_approval_snapshot_id: null,
      attendance_approval_snapshot_id: null,
      ready: false,
      warnings: [],
    },
    default_attendance_preview: [],
  };
}

export function PlanningInputsWorkbenchView({
  authState,
  api,
  pantryApi,
  readinessApi,
  needGenerationApi,
  confirmedNeedApi,
  initialWeekStart,
  mode = "connected",
}: {
  authState: AtlasAuthState;
  api?: PlanningInputsApi;
  pantryApi?: PantryApi;
  readinessApi?: Pick<
    ReturnType<typeof createPlanningInputReadinessApi>,
    "preflight"
  >;
  needGenerationApi?: NeedGenerationApi;
  confirmedNeedApi?: ConfirmedNeedApi;
  initialWeekStart?: string;
  mode?: "connected" | "review";
}) {
  const [correlationId] = useState(() => crypto.randomUUID());
  const [weekStart, setWeekStart] = useState(
    () => initialWeekStart ?? mondayOf(new Date()),
  );
  const [tab, setTab] = useState<TabId>("menu");
  const [dailyConfirmedNeedPreflights, setDailyConfirmedNeedPreflights] =
    useState<Record<string, PlanningInputPreflightData>>({});
  const [selectedConfirmedNeed, setSelectedConfirmedNeed] =
    useState<DailyConfirmedNeedSelection | null>(null);
  const [
    confirmedNeedProjectionResolution,
    setConfirmedNeedProjectionResolution,
  ] = useState<ConfirmedNeedProjectionResolution>("idle");
  const [load, setLoad] = useState<LoadState>("idle");
  const [data, setData] = useState(() => emptyData(weekStart));
  const [notice, setNotice] = useState<string | null>(null);
  const [sourceOutcome, setSourceOutcome] = useState<{
    message: string;
    consequence: string | null;
    currentness: string | null;
  } | null>(null);
  const [refreshRequired, setRefreshRequired] = useState(false);
  const [dirty, setDirty] = useState(false);
  const [pantryDirty, setPantryDirty] = useState(false);
  const [confirmedNeedDirty, setConfirmedNeedDirty] = useState(false);
  const [saving, setSaving] = useState(false);
  const [menuRows, setMenuRows] = useState<MenuLine[]>([]);
  const [attendanceRows, setAttendanceRows] = useState<AttendanceLine[]>([]);
  const [menuPreview, setMenuPreview] =
    useState<PlanningPreview<MenuLine> | null>(null);
  const [attendancePreview, setAttendancePreview] =
    useState<PlanningPreview<AttendanceLine> | null>(null);
  const [menuCorrectionImpact, setMenuCorrectionImpact] =
    useState<PlanningCorrectionImpact | null>(null);
  const [attendanceCorrectionImpact, setAttendanceCorrectionImpact] =
    useState<PlanningCorrectionImpact | null>(null);
  const [menuSourceName, setMenuSourceName] = useState(
    "Chỉnh sửa trực tiếp Atlas",
  );
  const [attendanceSourceName, setAttendanceSourceName] = useState(
    "Mặc định theo Thực đơn tuần",
  );
  const [attendanceSourceType, setAttendanceSourceType] =
    useState("SCHOOL_DEFAULTS");
  const [menuSourceType, setMenuSourceType] =
    useState<MenuSourceType>("MANUAL");
  const [browserChecksum, setBrowserChecksum] = useState<string | null>(null);
  const [importErrors, setImportErrors] = useState<string[]>([]);
  const [importWarnings, setImportWarnings] = useState<string[]>([]);
  const [selectedGoogleSourceId, setSelectedGoogleSourceId] = useState("");
  const [googleFetch, setGoogleFetch] = useState<GoogleFetchState>({
    status: "idle",
  });
  const [attendancePaste, setAttendancePaste] = useState("");
  const [schoolSearch, setSchoolSearch] = useState("");
  const [attendanceSchoolSearch, setAttendanceSchoolSearch] = useState("");
  const [serviceDateFilter, setServiceDateFilter] = useState(weekStart);
  const generation = useRef(0);
  const confirmedNeedGeneration = useRef(0);
  const authSubject =
    authState.status === "authenticated" ? authState.authSubject : null;
  const DatePickerInput = useContext(AtlasDatePickerInputContext);
  const selectedWeekEnd = weekEndOf(weekStart);
  const confirmedNeedServiceDates = useMemo(
    () => dailyServiceDates(weekStart, selectedWeekEnd),
    [selectedWeekEnd, weekStart],
  );
  const confirmedNeedCandidates = useMemo(
    () =>
      confirmedNeedServiceDates.flatMap((serviceDate) => {
        const batchId =
          dailyConfirmedNeedPreflights[serviceDate]?.current_need
            ?.confirmed_need_batch_id;
        return batchId ? [{ serviceDate, batchId }] : [];
      }),
    [confirmedNeedServiceDates, dailyConfirmedNeedPreflights],
  );
  const confirmedNeedResolution = selectedConfirmedNeed
    ? ("available" as const)
    : confirmedNeedProjectionResolution === "ready"
      ? confirmedNeedCandidates.length
        ? ("selection_required" as const)
        : ("missing" as const)
      : confirmedNeedProjectionResolution;

  const resolveCurrentConfirmedNeed = useCallback(async () => {
    if (!readinessApi || !authSubject) {
      setDailyConfirmedNeedPreflights({});
      setSelectedConfirmedNeed(null);
      setConfirmedNeedProjectionResolution("idle");
      return;
    }
    const request = ++confirmedNeedGeneration.current;
    setDailyConfirmedNeedPreflights({});
    setSelectedConfirmedNeed(null);
    setConfirmedNeedProjectionResolution("loading");
    const results = await Promise.all(
      confirmedNeedServiceDates.map((serviceDate) =>
        readinessApi.preflight(
          authSubject,
          correlationId,
          serviceDate,
          serviceDate,
        ),
      ),
    );
    if (request !== confirmedNeedGeneration.current) return;
    const parsed = Object.fromEntries(
      confirmedNeedServiceDates.flatMap((serviceDate, index) => {
        const preflight = planningInputPreflightFromResult(results[index]!);
        return preflight ? [[serviceDate, preflight]] : [];
      }),
    ) as Record<string, PlanningInputPreflightData>;
    if (Object.keys(parsed).length !== confirmedNeedServiceDates.length) {
      const denied = results.some(
        (result) =>
          result.kind === "backend_error" &&
          result.error.error_code === "CAPABILITY_DENIED",
      );
      setDailyConfirmedNeedPreflights(parsed);
      setConfirmedNeedProjectionResolution(denied ? "denied" : "error");
      return;
    }
    const candidates = confirmedNeedServiceDates.flatMap((serviceDate) => {
      const batchId =
        parsed[serviceDate]?.current_need?.confirmed_need_batch_id;
      return batchId ? [{ serviceDate, batchId }] : [];
    });
    setDailyConfirmedNeedPreflights(parsed);
    setSelectedConfirmedNeed(candidates.length === 1 ? candidates[0]! : null);
    setConfirmedNeedProjectionResolution("ready");
  }, [authSubject, confirmedNeedServiceDates, correlationId, readinessApi]);

  const adopt = useCallback((workbench: PlanningInputsWorkbenchData) => {
    setData(workbench);
    setMenuRows(activeMenuRows(workbench.weekly_menu));
    setAttendanceRows(
      attendanceWorkingRows(
        workbench.attendance,
        workbench.default_attendance_preview,
      ),
    );
    setMenuSourceName(
      workbench.weekly_menu?.source_name ?? "Chỉnh sửa trực tiếp Atlas",
    );
    setAttendanceSourceType(
      workbench.attendance?.source_type ?? "SCHOOL_DEFAULTS",
    );
    setAttendanceSourceName(
      workbench.attendance?.source_name ?? "Mặc định theo Thực đơn tuần",
    );
    setMenuPreview(null);
    setAttendancePreview(null);
    setBrowserChecksum(null);
    setImportErrors([]);
    setImportWarnings([]);
    setDirty(false);
  }, []);

  const refresh = useCallback(async () => {
    if (!api || !authSubject) return false;
    const request = ++generation.current;
    setLoad("loading");
    setNotice(null);
    const result = await api.getWorkbench(
      authSubject,
      correlationId,
      weekStart,
    );
    if (request !== generation.current) return false;
    const workbench = planningWorkbenchFromResult(result);
    if (!workbench) {
      setLoad("error");
      setNotice(planningResultMessage(result));
      return false;
    }
    setLoad("ready");
    adopt(workbench);
    setRefreshRequired(false);
    setSourceOutcome(null);
    return true;
  }, [api, authSubject, correlationId, weekStart, adopt]);

  useEffect(() => {
    generation.current += 1;
    if (authSubject) void refresh();
    else {
      setLoad("idle");
      setData(emptyData(weekStart));
    }
  }, [authSubject, refresh, weekStart]);

  useEffect(() => {
    void resolveCurrentConfirmedNeed();
  }, [resolveCurrentConfirmedNeed]);

  useEffect(() => {
    setSelectedGoogleSourceId((current) =>
      data.google_sheet_sources.some(
        (source) => source.weekly_menu_google_source_id === current,
      )
        ? current
        : (data.google_sheet_sources[0]?.weekly_menu_google_source_id ?? ""),
    );
  }, [data.google_sheet_sources]);

  useEffect(() => {
    if (!dirty && !pantryDirty && !confirmedNeedDirty) return;
    const warn = (event: BeforeUnloadEvent) => event.preventDefault();
    window.addEventListener("beforeunload", warn);
    return () => window.removeEventListener("beforeunload", warn);
  }, [dirty, pantryDirty, confirmedNeedDirty]);

  const discardMenuChanges = () => {
    setMenuRows(activeMenuRows(data.weekly_menu));
    setMenuPreview(null);
    setMenuSourceType("MANUAL");
    setMenuSourceName("Chỉnh sửa trực tiếp Atlas");
    setBrowserChecksum(null);
    setImportErrors([]);
    setImportWarnings([]);
    setGoogleFetch({ status: "idle" });
    setDirty(false);
  };

  const discardAttendanceChanges = () => {
    setAttendanceRows(
      attendanceWorkingRows(data.attendance, data.default_attendance_preview),
    );
    setAttendancePreview(null);
    setAttendancePaste("");
    setAttendanceSourceType(data.attendance?.source_type ?? "SCHOOL_DEFAULTS");
    setAttendanceSourceName(
      data.attendance?.source_name ?? "Mặc định theo Thực đơn tuần",
    );
    setBrowserChecksum(null);
    setImportErrors([]);
    setImportWarnings([]);
    setDirty(false);
  };

  const currentSourceDirty =
    tab === "pantry"
      ? pantryDirty
      : tab === "confirmed-needs"
        ? confirmedNeedDirty
        : tab === "menu" || tab === "attendance"
          ? dirty
          : false;

  const discardCurrentSourceChanges = () => {
    if (tab === "menu") discardMenuChanges();
    if (tab === "attendance") discardAttendanceChanges();
    if (tab === "pantry") setPantryDirty(false);
    if (tab === "confirmed-needs") setConfirmedNeedDirty(false);
  };

  const refreshAuthoritativeData = () => {
    if (
      (dirty || pantryDirty || confirmedNeedDirty) &&
      !window.confirm(
        "Có thay đổi chưa lưu. Tải lại sẽ bỏ các thay đổi này. Tiếp tục?",
      )
    )
      return;
    if (dirty || pantryDirty || confirmedNeedDirty)
      discardCurrentSourceChanges();
    void refresh();
    void resolveCurrentConfirmedNeed();
  };

  const changeTab = (next: TabId) => {
    if (next === tab) return;
    if (
      currentSourceDirty &&
      !window.confirm(
        "Có thay đổi chưa lưu. Chuyển khu vực sẽ bỏ các thay đổi này. Tiếp tục?",
      )
    )
      return;
    if (currentSourceDirty) discardCurrentSourceChanges();
    setTab(next);
  };

  const changeWeek = (next: string) => {
    if (
      (dirty || pantryDirty || confirmedNeedDirty) &&
      !window.confirm("Bỏ các thay đổi chưa lưu để chuyển tuần?")
    )
      return false;
    if (dirty || pantryDirty || confirmedNeedDirty)
      discardCurrentSourceChanges();
    setSelectedConfirmedNeed(null);
    setWeekStart(next);
    setServiceDateFilter(next);
    return true;
  };

  const selectConfirmedNeedDate = (selection: DailyConfirmedNeedSelection) => {
    if (
      selectedConfirmedNeed?.serviceDate === selection.serviceDate &&
      selectedConfirmedNeed.batchId === selection.batchId
    )
      return;
    if (
      confirmedNeedDirty &&
      !window.confirm(
        "Có thay đổi chưa lưu. Chuyển ngày sẽ bỏ các thay đổi này. Tiếp tục?",
      )
    )
      return;
    if (confirmedNeedDirty) setConfirmedNeedDirty(false);
    setSelectedConfirmedNeed(selection);
  };

  const activeSchools = useMemo(
    () =>
      data.schools
        .filter((school) => school.school_status === "ACTIVE")
        .sort(
          (left, right) =>
            left.display_order - right.display_order ||
            left.school_code.localeCompare(right.school_code),
        ),
    [data.schools],
  );
  const activeDishes = useMemo(
    () =>
      data.dishes
        .filter((dish) => dish.dish_status === "ACTIVE")
        .sort(
          (left, right) =>
            left.display_order - right.display_order ||
            left.dish_code.localeCompare(right.dish_code),
        ),
    [data.dishes],
  );
  const activeDishTypes = useMemo(
    () =>
      data.dish_types
        .filter((dishType) => dishType.dish_type_status === "ACTIVE")
        .sort(
          (left, right) =>
            left.display_order - right.display_order ||
            left.dish_type_code.localeCompare(right.dish_type_code) ||
            left.dish_type_id.localeCompare(right.dish_type_id),
        ),
    [data.dish_types],
  );
  const unmappedDishes = useMemo(
    () => activeDishes.filter((dish) => !dish.dish_type_id),
    [activeDishes],
  );
  const menuKeys = useMemo(() => {
    const search = schoolSearch.trim().toLocaleLowerCase("vi");
    const schools = activeSchools.filter(
      (school) =>
        !search ||
        school.school_code.toLocaleLowerCase("vi").includes(search) ||
        school.school_name.toLocaleLowerCase("vi").includes(search),
    );
    const keys = new Set(
      schools.map((school) => `${school.school_id}|${serviceDateFilter}`),
    );
    for (const line of menuRows) {
      if (
        line.service_date === serviceDateFilter &&
        (!search ||
          schools.some((school) => school.school_id === line.school_id))
      )
        keys.add(`${line.school_id}|${line.service_date}`);
    }
    return Array.from(keys).sort();
  }, [menuRows, activeSchools, schoolSearch, serviceDateFilter]);
  const serviceDates = useMemo(
    () =>
      Array.from({ length: 7 }, (_, offset) => {
        return addLocalCalendarDays(data.week_start, offset);
      }),
    [data.week_start],
  );
  const attendanceTotals = useMemo(
    () =>
      attendanceRows.reduce(
        (total, line) => ({
          students:
            total.students +
            (Number.isFinite(line.student_portions)
              ? line.student_portions
              : 0),
          teachers:
            total.teachers +
            (Number.isFinite(line.teacher_portions)
              ? line.teacher_portions
              : 0),
        }),
        { students: 0, teachers: 0 },
      ),
    [attendanceRows],
  );
  const filteredAttendanceRows = useMemo(
    () =>
      attendanceRows.filter((line) => {
        const school = data.schools.find(
          (item) => item.school_id === line.school_id,
        );
        return fuzzyTextMatch(
          attendanceSchoolSearch,
          school?.school_code ?? "",
          school?.school_name ?? line.school_id,
        );
      }),
    [attendanceRows, attendanceSchoolSearch, data.schools],
  );
  const needsAttendanceConfirmation = useMemo(
    () =>
      attendanceNeedsConfirmation(
        data.attendance,
        data.default_attendance_preview,
      ),
    [data.attendance, data.default_attendance_preview],
  );

  const runCompletion = async (
    source: "weekly_menu" | "attendance",
    invoke: () => Promise<AtlasRpcResult>,
  ) => {
    setSaving(true);
    setNotice(null);
    setSourceOutcome(null);
    const result = await invoke();
    setSaving(false);
    const message = planningResultMessage(result);
    const currentness =
      result.kind === "success" &&
      typeof result.response.downstream_currentness === "string"
        ? result.response.downstream_currentness
        : null;
    const outcome =
      result.kind === "success" &&
      (currentness === "CURRENT" ||
        currentness === "OUTDATED" ||
        currentness === "NOT_GENERATED")
        ? planningSourceSaveOutcome(source, currentness)
        : null;
    setSourceOutcome({
      message: outcome?.savedMessage ?? message,
      consequence: outcome?.consequenceMessage ?? null,
      currentness,
    });
    if (
      result.kind === "transport_error" ||
      (result.kind === "backend_error" &&
        ["STALE_VERSION", "STALE_SOURCE_SIGNATURE"].includes(
          result.error.error_code,
        ))
    ) {
      setRefreshRequired(true);
      return false;
    }
    const readback = planningReadbackFromResult(result);
    if (readback) {
      adopt(readback);
      setLoad("ready");
      setRefreshRequired(false);
      return true;
    }
    if (result.kind === "success") setRefreshRequired(true);
    return false;
  };

  const previewMenu = async (rows = menuRows) => {
    if (!api || !authSubject) return null;
    setSaving(true);
    const result = await api.previewMenu(
      authSubject,
      correlationId,
      weekStart,
      rows as unknown as JsonValue[],
    );
    const preview = planningPreviewFromResult<MenuLine>(result);
    setMenuPreview(preview);
    const impactResult =
      preview?.can_save && api.getCorrectionImpact
        ? await api.getCorrectionImpact(
            authSubject,
            correlationId,
            "WEEKLY_MENU",
            {
              week_start: weekStart,
              source_type: menuSourceType,
              source_name: menuSourceName,
              source_signature: preview.source_signature,
              expected_source_signature:
                data.weekly_menu?.source_signature ?? null,
              rows: preview.canonical_rows as unknown as JsonValue[],
            },
          )
        : null;
    const impact = impactResult
      ? planningCorrectionImpactFromResult(impactResult)
      : preview?.can_save
        ? safeNoDownstreamImpact("WEEKLY_MENU")
        : null;
    setMenuCorrectionImpact(impact);
    setSaving(false);
    setNotice(
      preview && impact
        ? "Đã cập nhật phần Xem thay đổi cho thực đơn."
        : planningResultMessage(impactResult ?? result),
    );
    return preview;
  };

  const previewAttendance = async (rows = attendanceRows) => {
    if (!api || !authSubject) return null;
    setSaving(true);
    const result = await api.previewAttendance(
      authSubject,
      correlationId,
      weekStart,
      rows as unknown as JsonValue[],
    );
    const preview = planningPreviewFromResult<AttendanceLine>(result);
    setAttendancePreview(preview);
    const impactResult =
      preview?.can_save && api.getCorrectionImpact
        ? await api.getCorrectionImpact(
            authSubject,
            correlationId,
            "ATTENDANCE",
            {
              week_start: weekStart,
              source_type: attendanceSourceType,
              source_name: attendanceSourceName,
              source_signature: preview.source_signature,
              expected_source_signature:
                data.attendance?.source_signature ?? null,
              rows: preview.canonical_rows as unknown as JsonValue[],
            },
          )
        : null;
    const impact = impactResult
      ? planningCorrectionImpactFromResult(impactResult)
      : preview?.can_save
        ? safeNoDownstreamImpact("ATTENDANCE")
        : null;
    setAttendanceCorrectionImpact(impact);
    setSaving(false);
    setNotice(
      preview && impact
        ? "Đã cập nhật phần Xem thay đổi cho sĩ số."
        : planningResultMessage(impactResult ?? result),
    );
    return preview;
  };

  const saveMenu = async () => {
    if (!api || !authSubject || refreshRequired) return;
    const preview = menuPreview;
    if (!preview?.can_save || !menuCorrectionImpact?.save_allowed) return;
    const request = weeklyMenuCompletionRequest(
      authSubject,
      correlationId,
      data.weekly_menu?.version ?? 1,
      {
        week_start: weekStart,
        source_type: menuSourceType,
        source_name: menuSourceName,
        source_signature: preview.source_signature,
        expected_source_signature: data.weekly_menu?.source_signature ?? null,
        rows: preview.canonical_rows as unknown as JsonValue[],
      },
    );
    await runCompletion("weekly_menu", () => api.saveCompletedMenu(request));
  };

  const saveAttendance = async () => {
    if (!api || !authSubject || refreshRequired) return;
    const preview = attendancePreview;
    if (!preview?.can_save || !attendanceCorrectionImpact?.save_allowed) return;
    const request = attendanceCompletionRequest(
      authSubject,
      correlationId,
      data.attendance?.version ?? 1,
      {
        week_start: weekStart,
        source_type: attendanceSourceType,
        source_name: attendanceSourceName,
        source_signature: preview.source_signature,
        expected_source_signature: data.attendance?.source_signature ?? null,
        rows: preview.canonical_rows as unknown as JsonValue[],
      },
    );
    await runCompletion("attendance", () =>
      api.saveCompletedAttendance(request),
    );
  };

  const prepareCorrection = async (
    source: "menu" | "attendance",
    chain: PlanningCorrectionChain,
  ) => {
    if (!api?.prepareCorrection || !authSubject) return;
    setSaving(true);
    const result = await api.prepareCorrection(
      authSubject,
      correlationId,
      chain,
      "Hiệu chỉnh nguồn Kế hoạch sau khi rà soát ảnh hưởng.",
    );
    setNotice(planningResultMessage(result));
    if (
      result.kind === "transport_error" ||
      (result.kind === "backend_error" &&
        ["STALE_VERSION", "RETRYABLE_CONCURRENCY_FAILURE"].includes(
          result.error.error_code,
        ))
    ) {
      setSaving(false);
      setRefreshRequired(true);
      return;
    }
    setSaving(false);
    if (result.kind === "success") {
      if (source === "menu") await previewMenu();
      else await previewAttendance();
    }
  };

  const onMenuFile = async (file?: File) => {
    if (!file) return;
    const review = await parseMenuWorkbook(
      file,
      data.dish_types,
      data.schools,
      data.dishes,
    );
    setMenuRows(review.rows);
    setMenuPreview(null);
    setMenuSourceName(review.fileName);
    setMenuSourceType("WORKBOOK_IMPORT");
    setBrowserChecksum(review.browserChecksum);
    setImportErrors(review.errors);
    setImportWarnings(review.warnings);
    setGoogleFetch({ status: "idle" });
    setDirty(true);
  };

  const onGoogleSync = async () => {
    if (!api || !selectedGoogleSourceId) return;
    setGoogleFetch({ status: "fetching" });
    setNotice(null);
    const result = await api.syncMenuFromGoogle(
      selectedGoogleSourceId,
      weekStart,
      correlationId,
    );
    if (result.kind !== "success") {
      setGoogleFetch({
        status: "error",
        errorCode:
          result.kind === "backend_error"
            ? result.error.error_code
            : result.kind === "auth_error"
              ? result.diagnostic.code
              : result.diagnostic.code,
      });
      setNotice(googleResultMessage(result));
      return;
    }
    const source = recordValue(result.response.source);
    const matrix = result.response.rows;
    if (
      !source ||
      typeof source.source_name !== "string" ||
      typeof source.sheet_name !== "string" ||
      typeof result.response.fetched_at !== "string" ||
      !Array.isArray(matrix) ||
      !matrix.every((row) => Array.isArray(row))
    ) {
      setGoogleFetch({ status: "error", errorCode: "MALFORMED_RESPONSE" });
      setNotice("Bộ đồng bộ Google Sheet trả về dữ liệu không hợp lệ.");
      return;
    }
    const review = await parseMenuMatrix(
      matrix as unknown as SourceMatrix,
      {
        sourceName: source.source_name,
        sheetName: source.sheet_name,
        firstRowNumber: 3,
      },
      data.dish_types,
      data.schools,
      data.dishes,
    );
    setMenuRows(review.rows);
    setMenuPreview(null);
    setMenuSourceName(review.sourceName);
    setMenuSourceType("GOOGLE_SHEET");
    setBrowserChecksum(review.browserChecksum);
    setImportErrors(review.errors);
    setImportWarnings(review.warnings);
    setGoogleFetch({
      status: "success",
      sourceName: source.source_name,
      sheetName: source.sheet_name,
      fetchedAt: result.response.fetched_at,
      sourceRowCount: review.sourceRowCount,
    });
    setDirty(true);
  };

  const updateMenuCell = (
    schoolId: string,
    serviceDate: string,
    slot: string,
    dishId: string,
  ) => {
    setMenuSourceType("MANUAL");
    setMenuSourceName("Chỉnh sửa trực tiếp Atlas");
    setGoogleFetch({ status: "idle" });
    setMenuRows((current) => {
      const others = current.filter(
        (line) =>
          !(
            line.school_id === schoolId &&
            line.service_date === serviceDate &&
            line.menu_slot_code === slot
          ),
      );
      if (!dishId) return others;
      return [
        ...others,
        {
          school_id: schoolId,
          service_date: serviceDate,
          menu_slot_code: slot,
          dish_id: dishId,
          source_row_reference: `atlas:${schoolId}:${serviceDate}:${slot}`,
        },
      ];
    });
    setMenuPreview(null);
    setDirty(true);
  };

  const updateAttendance = (
    line: AttendanceLine,
    field: "student_portions" | "teacher_portions",
    value: string,
  ) => {
    setAttendanceSourceType("MANUAL");
    setAttendanceSourceName("Chỉnh sửa trực tiếp Atlas");
    setBrowserChecksum(null);
    setAttendanceRows((current) =>
      current.map((candidate) =>
        candidate.school_id === line.school_id &&
        candidate.service_date === line.service_date
          ? {
              ...candidate,
              [field]: value.trim() === "" ? Number.NaN : Number(value),
            }
          : candidate,
      ),
    );
    setAttendancePreview(null);
    setDirty(true);
  };

  const authMessage =
    authState.status === "session_expired"
      ? "Phiên làm việc đã hết. Vui lòng đăng nhập lại để tiếp tục."
      : "Đăng nhập để xem và cập nhật nguồn kế hoạch.";

  return (
    <div className="planning-inputs-workbench">
      <WorkbenchHeader
        eyebrow="Lập nhu cầu"
        title="Lập nhu cầu theo tuần"
        context="Thực đơn → Sĩ số → Nhu cầu bổ sung → Tạo nhu cầu → Xác nhận nhu cầu."
        headingLevel={2}
      />
      <Paper component="section" className="planning-context-bar" withBorder>
        {!DatePickerInput ? (
          <label>
            Tuần phục vụ
            <input
              aria-label="Tuần phục vụ"
              value={viDate(weekStart)}
              data-business-value={weekStart}
              onChange={(event) => {
                const value = event.target.value;
                const isoValue = /^\d{4}-\d{2}-\d{2}$/.test(value)
                  ? value
                  : value.split("/").reverse().join("-");
                if (/^\d{4}-\d{2}-\d{2}$/.test(isoValue))
                  changeWeek(localMondayOfIso(isoValue));
              }}
            />
          </label>
        ) : (
          <DatePickerInput
            label="Tuần phục vụ"
            aria-label="Tuần phục vụ"
            value={weekStart}
            valueFormat="DD/MM/YYYY"
            locale="vi"
            firstDayOfWeek={1}
            onChange={(value) => {
              if (typeof value === "string" && value)
                changeWeek(localMondayOfIso(value));
            }}
          />
        )}
        <div>
          <span>Khoảng ngày</span>
          <b>
            {viDate(data.week_start)} – {viDate(data.week_end)}
          </b>
        </div>
        <Button
          type="button"
          variant="outline"
          leftSection={<ArrowClockwise size={17} aria-hidden="true" />}
          onClick={refreshAuthoritativeData}
          disabled={saving}
        >
          Tải lại dữ liệu
        </Button>
      </Paper>

      {!authSubject ? (
        <OperationalState
          variant={
            authState.status === "session_expired"
              ? "read-only"
              : "access-denied"
          }
          title={authMessage}
        />
      ) : (
        <>
          <Box
            className="planning-tabs"
            role="tablist"
            aria-label="Quy trình Lập nhu cầu"
          >
            <Button
              type="button"
              role="tab"
              variant="subtle"
              aria-selected={tab === "menu"}
              className={tab === "menu" ? "active" : ""}
              onClick={() => changeTab("menu")}
            >
              Thực đơn
            </Button>
            <Button
              type="button"
              role="tab"
              variant="subtle"
              aria-selected={tab === "attendance"}
              className={tab === "attendance" ? "active" : ""}
              onClick={() => changeTab("attendance")}
            >
              Sĩ số
            </Button>
            <Button
              type="button"
              role="tab"
              variant="subtle"
              aria-selected={tab === "pantry"}
              className={tab === "pantry" ? "active" : ""}
              onClick={() => changeTab("pantry")}
            >
              Nhu cầu bổ sung
            </Button>
            <Button
              type="button"
              role="tab"
              variant="subtle"
              aria-selected={tab === "need-generation"}
              className={tab === "need-generation" ? "active" : ""}
              onClick={() => changeTab("need-generation")}
            >
              Tạo nhu cầu
            </Button>
            <Button
              type="button"
              role="tab"
              variant="subtle"
              aria-selected={tab === "confirmed-needs"}
              className={tab === "confirmed-needs" ? "active" : ""}
              onClick={() => changeTab("confirmed-needs")}
            >
              Xác nhận nhu cầu
            </Button>
          </Box>

          {(tab === "menu" || tab === "attendance") && sourceOutcome && (
            <p
              className={`operator-notice${
                sourceOutcome.currentness === "OUTDATED" ? " warning" : ""
              }`}
              role={refreshRequired ? "alert" : "status"}
            >
              {sourceOutcome.message}
              {sourceOutcome.consequence && (
                <span> {sourceOutcome.consequence}</span>
              )}
              {refreshRequired && (
                <span> Cần tải lại dữ liệu mới nhất trước khi tiếp tục.</span>
              )}
            </p>
          )}

          {(tab === "menu" || tab === "attendance") && load === "loading" && (
            <OperationalState
              variant="information"
              title="Đang tải nguồn kế hoạch…"
            />
          )}
          {(tab === "menu" || tab === "attendance") && load === "error" && (
            <OperationalState
              variant="system-error"
              title={notice ?? "Không thể tải nguồn kế hoạch."}
              onAuthoritativeRefresh={() => void refresh()}
            />
          )}

          {tab === "menu" && load !== "error" && (
            <Panel
              title="Thực đơn tuần"
              description="Chọn món theo trường và ngày phục vụ, xem rõ các thay đổi rồi lưu cho Kế hoạch."
              status={
                <Chip tone={statusTone(data.weekly_menu?.weekly_menu_status)}>
                  {statusLabel(data.weekly_menu?.weekly_menu_status)}
                </Chip>
              }
            >
              {dirty && (
                <p className="planning-dirty-notice" role="status">
                  Có thay đổi chưa lưu trong nguồn đang làm việc.
                </p>
              )}
              {importErrors.map((error) => (
                <p className="operator-notice danger" key={error}>
                  {error}
                </p>
              ))}
              <Issues
                title="Lỗi chặn"
                issues={
                  menuPreview?.issues.blockers ??
                  data.weekly_menu?.issues.blockers ??
                  []
                }
                tone="danger"
              />
              <Issues
                title="Cảnh báo"
                issues={[
                  ...(menuPreview?.issues.warnings ??
                    data.weekly_menu?.issues.warnings ??
                    []),
                  ...importWarnings.map((warning) => ({
                    code: warning,
                    message: warning,
                    source_row_reference: null,
                  })),
                ]}
                tone="warning"
              />
              <div
                className="planning-workbench-toolbar"
                aria-label="Bộ lọc, nguồn và thao tác thực đơn"
              >
                <div className="planning-toolbar-group planning-filter-group">
                  <span className="planning-toolbar-label">Phạm vi lưới</span>
                  <label>
                    Tìm trường
                    <input
                      type="search"
                      value={schoolSearch}
                      onChange={(event) => setSchoolSearch(event.target.value)}
                      placeholder="Mã hoặc tên trường"
                    />
                  </label>
                  <label>
                    Ngày phục vụ
                    <select
                      value={serviceDateFilter}
                      onChange={(event) =>
                        setServiceDateFilter(event.target.value)
                      }
                    >
                      {serviceDates.map((date) => (
                        <option value={date} key={date}>
                          {viDate(date)}
                        </option>
                      ))}
                    </select>
                  </label>
                </div>
                <div className="planning-toolbar-group planning-source-group">
                  <span className="planning-toolbar-label">Nạp nguồn</span>
                  <label className="file-action">
                    <UploadSimple size={17} aria-hidden="true" />
                    Chọn workbook
                    <input
                      type="file"
                      accept=".xlsx"
                      onChange={(event) =>
                        void onMenuFile(event.target.files?.[0])
                      }
                    />
                  </label>
                  <label>
                    Nguồn Google Sheet
                    <select
                      aria-label="Nguồn Google Sheet"
                      value={selectedGoogleSourceId}
                      onChange={(event) =>
                        setSelectedGoogleSourceId(event.target.value)
                      }
                    >
                      {data.google_sheet_sources.length === 0 && (
                        <option value="">Chưa có nguồn cấu hình</option>
                      )}
                      {data.google_sheet_sources.map((source) => (
                        <option
                          value={source.weekly_menu_google_source_id}
                          key={source.weekly_menu_google_source_id}
                        >
                          {source.source_name}
                        </option>
                      ))}
                    </select>
                  </label>
                  <button
                    type="button"
                    className="secondary"
                    onClick={() => void onGoogleSync()}
                    disabled={
                      googleFetch.status === "fetching" ||
                      !selectedGoogleSourceId
                    }
                  >
                    <CloudArrowDown size={17} aria-hidden="true" />
                    {googleFetch.status === "fetching"
                      ? "Đang đồng bộ…"
                      : "Đồng bộ từ Google Sheet"}
                  </button>
                </div>
                <div className="planning-toolbar-group planning-local-actions">
                  <span className="planning-toolbar-label">Rà soát và lưu</span>
                  <button
                    type="button"
                    className="secondary"
                    onClick={() => void previewMenu()}
                    disabled={saving || !menuRows.length}
                  >
                    <Eye size={17} aria-hidden="true" />
                    Xem thay đổi
                  </button>
                  <button
                    type="button"
                    className="primary"
                    onClick={() => void saveMenu()}
                    disabled={
                      saving ||
                      refreshRequired ||
                      !dirty ||
                      !menuRows.length ||
                      !menuPreview?.can_save ||
                      !menuCorrectionImpact?.save_allowed
                    }
                  >
                    <FloppyDisk size={17} aria-hidden="true" />
                    Lưu
                  </button>
                  <button
                    type="button"
                    className="quiet"
                    onClick={discardMenuChanges}
                    disabled={!dirty}
                  >
                    Hủy thay đổi
                  </button>
                </div>
              </div>
              {data.google_sheet_sources.length === 0 && (
                <p className="operator-notice warning">
                  Chưa cấu hình nguồn Google Sheet.
                  <br />
                  Bạn vẫn có thể nhập tệp .xlsx.
                </p>
              )}
              {unmappedDishes.length > 0 && (
                <p className="operator-notice danger">
                  Có {unmappedDishes.length} món ăn đang hoạt động chưa được gán
                  Loại món; các món này không thể phân vào Thực đơn tuần.
                </p>
              )}
              {activeDishTypes.length === 0 && (
                <p className="operator-notice danger">
                  Không có Loại món đang hoạt động để tạo cột Thực đơn tuần.
                </p>
              )}
              {menuKeys.length === 0 ? (
                <p className="empty">
                  Không có trường hoạt động phù hợp bộ lọc.
                </p>
              ) : (
                <div className="planning-grid-scroll">
                  <CompactTable
                    headers={[
                      "Trường / ngày",
                      ...activeDishTypes.map(
                        (dishType) => dishType.dish_type_name,
                      ),
                    ]}
                  >
                    {menuKeys.map((key) => {
                      const [schoolId, serviceDate] = key.split("|");
                      const school = data.schools.find(
                        (item) => item.school_id === schoolId,
                      );
                      return (
                        <tr key={key}>
                          <th scope="row">
                            {school?.school_name ?? schoolId}
                            <small>{viDate(serviceDate)}</small>
                          </th>
                          {activeDishTypes.map((dishType) => {
                            const line = menuRows.find(
                              (item) =>
                                item.school_id === schoolId &&
                                item.service_date === serviceDate &&
                                item.menu_slot_code === dishType.dish_type_code,
                            );
                            const matchingDishes = activeDishes.filter(
                              (dish) =>
                                dish.dish_type_id === dishType.dish_type_id,
                            );
                            const selectedDish = line
                              ? activeDishes.find(
                                  (dish) => dish.dish_id === line.dish_id,
                                )
                              : undefined;
                            const selectedMismatch =
                              selectedDish &&
                              selectedDish.dish_type_id !==
                                dishType.dish_type_id;
                            return (
                              <td key={dishType.dish_type_code}>
                                <select
                                  aria-label={`${dishType.dish_type_name} · ${school?.school_name ?? schoolId} · ${viDate(serviceDate)}`}
                                  value={line?.dish_id ?? ""}
                                  onChange={(event) =>
                                    updateMenuCell(
                                      schoolId,
                                      serviceDate,
                                      dishType.dish_type_code,
                                      event.target.value,
                                    )
                                  }
                                  disabled={saving || refreshRequired}
                                >
                                  <option value="">—</option>
                                  {selectedMismatch && selectedDish && (
                                    <option
                                      value={selectedDish.dish_id}
                                      disabled
                                    >
                                      ⚠ {selectedDish.dish_name} — không khớp
                                      Loại món
                                    </option>
                                  )}
                                  {matchingDishes.map((dish) => (
                                    <option
                                      value={dish.dish_id}
                                      key={dish.dish_id}
                                    >
                                      {dish.dish_name}
                                    </option>
                                  ))}
                                </select>
                              </td>
                            );
                          })}
                        </tr>
                      );
                    })}
                  </CompactTable>
                </div>
              )}
              <div className="planning-support-region">
                <SourceSummary source={data.weekly_menu} />
                {googleFetch.status === "success" && (
                  <details className="planning-evidence">
                    <summary>Bằng chứng Google Sheet vừa tải</summary>
                    <section
                      className="planning-source-summary planning-source-summary-inline"
                      aria-label="Nguồn Google Sheet vừa tải"
                    >
                      <span>
                        Nguồn: <b>{googleFetch.sourceName}</b>
                      </span>
                      <span>
                        Trang tính: <b>{googleFetch.sheetName}</b>
                      </span>
                      <span>
                        Tải lúc:{" "}
                        <b>
                          {googleFetch.fetchedAt
                            ? new Date(googleFetch.fetchedAt).toLocaleString(
                                "vi-VN",
                              )
                            : "—"}
                        </b>
                      </span>
                      <span>
                        Dòng nguồn: <b>{googleFetch.sourceRowCount ?? 0}</b>
                      </span>
                    </section>
                  </details>
                )}
                {browserChecksum && (
                  <p className="planning-checksum">
                    SHA-256 trình duyệt: <code>{browserChecksum}</code>
                  </p>
                )}
                <ReviewSummary
                  preview={menuPreview}
                  kind="menu"
                  schools={data.schools}
                  dishes={data.dishes}
                  dishTypes={data.dish_types}
                  previousMenuRows={activeMenuRows(data.weekly_menu)}
                  previousAttendanceRows={[]}
                />
                <PlanningCorrectionImpactPanel
                  impact={menuCorrectionImpact}
                  busy={saving}
                  onPrepare={(chain) => void prepareCorrection("menu", chain)}
                />
                <History entries={data.weekly_menu?.approval_history ?? []} />
                <ChangeTimeline
                  entries={data.weekly_menu?.change_history ?? []}
                />
              </div>
            </Panel>
          )}

          {tab === "attendance" && load !== "error" && (
            <Panel
              title="Sĩ số"
              description="Sĩ số làm việc đã có sẵn theo thực đơn. Tìm trường, sửa số suất thực tế, xem thay đổi rồi lưu cho Kế hoạch."
              status={
                <Chip
                  tone={
                    needsAttendanceConfirmation
                      ? "warning"
                      : statusTone(data.attendance?.attendance_status)
                  }
                >
                  {needsAttendanceConfirmation
                    ? "CẦN XEM & LƯU"
                    : statusLabel(data.attendance?.attendance_status)}
                </Chip>
              }
            >
              {needsAttendanceConfirmation && (
                <p className="planning-dirty-notice" role="status">
                  Có sĩ số mặc định mới theo thực đơn chưa được lưu.
                </p>
              )}
              {dirty && (
                <p className="planning-dirty-notice" role="status">
                  Có thay đổi chưa lưu trong nguồn đang làm việc.
                </p>
              )}
              <Issues
                title="Lỗi chặn"
                issues={
                  attendancePreview?.issues.blockers ??
                  data.attendance?.issues.blockers ??
                  []
                }
                tone="danger"
              />
              <Issues
                title="Cảnh báo"
                issues={[
                  ...(attendancePreview?.issues.warnings ??
                    data.attendance?.issues.warnings ??
                    []),
                ]}
                tone="warning"
              />
              <div
                className="planning-workbench-toolbar attendance-toolbar"
                aria-label="Tìm kiếm, rà soát và lưu sĩ số"
              >
                <div className="planning-toolbar-group planning-filter-group">
                  <span className="planning-toolbar-label">Danh sách</span>
                  <label>
                    Tìm trường
                    <input
                      type="search"
                      aria-label="Tìm trường trong sĩ số"
                      value={attendanceSchoolSearch}
                      onChange={(event) =>
                        setAttendanceSchoolSearch(event.target.value)
                      }
                      placeholder="Mã hoặc tên trường"
                    />
                  </label>
                </div>
                <div className="planning-toolbar-group planning-local-actions">
                  <span className="planning-toolbar-label">Rà soát và lưu</span>
                  <button
                    type="button"
                    className="secondary"
                    onClick={() => void previewAttendance()}
                    disabled={saving || !attendanceRows.length}
                  >
                    <Eye size={17} aria-hidden="true" />
                    Xem thay đổi
                  </button>
                  <button
                    type="button"
                    className="primary"
                    onClick={() => void saveAttendance()}
                    disabled={
                      saving ||
                      refreshRequired ||
                      !attendanceRows.length ||
                      !attendancePreview?.can_save ||
                      !attendanceCorrectionImpact?.save_allowed
                    }
                  >
                    <FloppyDisk size={17} aria-hidden="true" />
                    Lưu
                  </button>
                  <button
                    type="button"
                    className="quiet"
                    onClick={discardAttendanceChanges}
                    disabled={!dirty}
                  >
                    Hủy thay đổi
                  </button>
                </div>
              </div>
              <details className="attendance-paste">
                <summary>Dán hàng loạt từ bảng tính</summary>
                <p>Thứ tự cột: trường, ngày, suất học sinh, suất giáo viên.</p>
                <textarea
                  aria-label="Dữ liệu sĩ số dán hàng loạt"
                  value={attendancePaste}
                  onChange={(event) => setAttendancePaste(event.target.value)}
                />
                <button
                  type="button"
                  onClick={() => {
                    const rows = parseAttendancePaste(
                      attendancePaste,
                      data.schools,
                    );
                    setAttendanceRows(rows);
                    setAttendancePreview(null);
                    setAttendanceSourceType("BULK_PASTE");
                    setAttendanceSourceName("Dán hàng loạt Atlas");
                    setBrowserChecksum(null);
                    setDirty(true);
                  }}
                >
                  Chuẩn hóa dữ liệu đã dán
                </button>
              </details>
              {filteredAttendanceRows.length === 0 ? (
                <p className="empty">
                  {attendanceRows.length === 0
                    ? "Chưa có trường/ngày có thực đơn trong tuần này."
                    : "Không tìm thấy trường phù hợp."}
                </p>
              ) : (
                <div className="planning-grid-scroll attendance-grid-scroll">
                  <CompactTable
                    headers={[
                      "Trường",
                      "Ngày phục vụ",
                      "Suất học sinh",
                      "Suất giáo viên",
                      "Tổng",
                    ]}
                  >
                    {filteredAttendanceRows.map((line) => {
                      const school = data.schools.find(
                        (item) => item.school_id === line.school_id,
                      );
                      const editable = !saving && !refreshRequired;
                      return (
                        <tr key={`${line.school_id}:${line.service_date}`}>
                          <th scope="row">
                            {school?.school_name ?? line.school_id}
                          </th>
                          <td>{viDate(line.service_date)}</td>
                          <td>
                            <input
                              aria-label={`Suất học sinh · ${school?.school_name ?? line.school_id} · ${viDate(line.service_date)}`}
                              type="number"
                              min="0"
                              value={
                                Number.isNaN(line.student_portions)
                                  ? ""
                                  : line.student_portions
                              }
                              disabled={!editable}
                              onChange={(event) =>
                                updateAttendance(
                                  line,
                                  "student_portions",
                                  event.target.value,
                                )
                              }
                            />
                          </td>
                          <td>
                            <input
                              aria-label={`Suất giáo viên · ${school?.school_name ?? line.school_id} · ${viDate(line.service_date)}`}
                              type="number"
                              min="0"
                              value={
                                Number.isNaN(line.teacher_portions)
                                  ? ""
                                  : line.teacher_portions
                              }
                              disabled={!editable}
                              onChange={(event) =>
                                updateAttendance(
                                  line,
                                  "teacher_portions",
                                  event.target.value,
                                )
                              }
                            />
                          </td>
                          <td>
                            {Number.isFinite(line.student_portions) &&
                            Number.isFinite(line.teacher_portions)
                              ? line.student_portions + line.teacher_portions
                              : "Cần nhập"}
                          </td>
                        </tr>
                      );
                    })}
                  </CompactTable>
                </div>
              )}
              {attendanceRows.length > 0 && (
                <p className="planning-attendance-totals">
                  Tổng: <b>{attendanceTotals.students}</b> suất học sinh ·{" "}
                  <b>{attendanceTotals.teachers}</b> suất giáo viên ·{" "}
                  <b>{attendanceTotals.students + attendanceTotals.teachers}</b>{" "}
                  suất
                </p>
              )}
              <div className="planning-support-region">
                <SourceSummary source={data.attendance} />
                {browserChecksum && (
                  <p className="planning-checksum">
                    SHA-256 trình duyệt: <code>{browserChecksum}</code>
                  </p>
                )}
                <ReviewSummary
                  preview={attendancePreview}
                  kind="attendance"
                  schools={data.schools}
                  dishes={data.dishes}
                  dishTypes={data.dish_types}
                  previousMenuRows={[]}
                  previousAttendanceRows={activeAttendanceRows(data.attendance)}
                />
                <PlanningCorrectionImpactPanel
                  impact={attendanceCorrectionImpact}
                  busy={saving}
                  onPrepare={(chain) =>
                    void prepareCorrection("attendance", chain)
                  }
                />
                <History entries={data.attendance?.approval_history ?? []} />
                <ChangeTimeline
                  entries={data.attendance?.change_history ?? []}
                />
              </div>
            </Panel>
          )}

          {tab === "pantry" && (
            <PantryWorkbench
              authState={authState}
              api={pantryApi}
              weekStart={weekStart}
              mode={mode}
              onDirtyChange={setPantryDirty}
            />
          )}

          {tab === "confirmed-needs" && (
            <>
              {confirmedNeedProjectionResolution === "ready" && (
                <Panel
                  title="Nhu cầu xác nhận theo ngày"
                  description="Tuần là phần tổng hợp để xem và chọn; mỗi ngày giữ nhu cầu xác nhận riêng."
                >
                  <div className="table-scroll">
                    <table aria-label="Xác nhận nhu cầu theo ngày">
                      <thead>
                        <tr>
                          <th>Ngày phục vụ</th>
                          <th>Trạng thái</th>
                          <th>Thao tác</th>
                        </tr>
                      </thead>
                      <tbody>
                        {confirmedNeedServiceDates.map((serviceDate) => {
                          const preflight =
                            dailyConfirmedNeedPreflights[serviceDate];
                          const batchId =
                            preflight?.current_need?.confirmed_need_batch_id;
                          const selected =
                            selectedConfirmedNeed?.serviceDate ===
                              serviceDate &&
                            selectedConfirmedNeed.batchId === batchId;
                          return (
                            <tr
                              key={serviceDate}
                              aria-current={selected ? "date" : undefined}
                            >
                              <td>{viDate(serviceDate)}</td>
                              <td>
                                {preflight
                                  ? confirmedNeedDateStatus(preflight)
                                  : "Không thể tải trạng thái"}
                              </td>
                              <td>
                                {batchId ? (
                                  <Button
                                    type="button"
                                    variant={selected ? "filled" : "outline"}
                                    onClick={() =>
                                      selectConfirmedNeedDate({
                                        serviceDate,
                                        batchId,
                                      })
                                    }
                                  >
                                    {selected ? "Đang xem" : "Mở ngày này"}
                                  </Button>
                                ) : (
                                  <span>—</span>
                                )}
                              </td>
                            </tr>
                          );
                        })}
                      </tbody>
                    </table>
                  </div>
                  {selectedConfirmedNeed && (
                    <p role="status">
                      Đang xem ngày{" "}
                      <b>{viDate(selectedConfirmedNeed.serviceDate)}</b>.
                    </p>
                  )}
                </Panel>
              )}
              <ConfirmedNeedReviewWorkbench
                key={selectedConfirmedNeed?.batchId ?? "unselected"}
                authState={authState}
                api={confirmedNeedApi}
                initialBatchId={selectedConfirmedNeed?.batchId ?? null}
                currentNeedResolution={confirmedNeedResolution}
                mode={mode}
                onDirtyChange={setConfirmedNeedDirty}
              />
            </>
          )}

          {tab === "need-generation" && (
            <NeedGenerationWorkbench
              authState={authState}
              api={needGenerationApi}
              preflightApi={readinessApi}
              selectedWeekStart={weekStart}
              selectedWeekEnd={selectedWeekEnd}
              mode={mode}
              onConfirmedNeedSelected={(
                nextBatchId,
                serviceDate,
                authoritativePreflight,
              ) => {
                setDailyConfirmedNeedPreflights((current) => ({
                  ...current,
                  [serviceDate]: authoritativePreflight,
                }));
                setSelectedConfirmedNeed({
                  serviceDate,
                  batchId: nextBatchId,
                });
                setConfirmedNeedProjectionResolution("ready");
                setTab("confirmed-needs");
              }}
            />
          )}

          {notice && load !== "error" && (
            <p
              className="operator-notice"
              role={notice.includes("không") ? "alert" : "status"}
            >
              {notice}
            </p>
          )}
          {mode === "review" && (
            <p className="planning-review-footnote">
              Dữ liệu trên trang này chỉ thuộc chế độ xem thử.
            </p>
          )}
        </>
      )}
    </div>
  );
}

export function PlanningInputsWorkbench(
  props: ComponentProps<typeof PlanningInputsWorkbenchView>,
) {
  return (
    <MantineProvider
      theme={atlasTheme}
      forceColorScheme="light"
      env={import.meta.env.MODE === "test" ? "test" : "default"}
    >
      <PlanningInputsWorkbenchView {...props} />
    </MantineProvider>
  );
}
