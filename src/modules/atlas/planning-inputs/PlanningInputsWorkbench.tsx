import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { AtlasAuthState } from "../connection/authSession";
import type { AtlasRpcResult, JsonValue } from "../connection/atlasRpc";
import { Chip, CompactTable, Panel } from "../WorkbenchComponents";
import {
  planningCommandRequest,
  type PlanningCommandRequest,
  type PlanningInputsApi,
} from "./planningInputsApi";
import {
  activeAttendanceRows,
  activeMenuRows,
  mondayOf,
  planningPreviewFromResult,
  planningReadbackFromResult,
  planningResultMessage,
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
  parseAttendanceWorkbook,
  parseMenuMatrix,
  parseMenuWorkbook,
  type SourceMatrix,
} from "./planningInputsWorkbook";
import { PantryWorkbench } from "./pantry/PantryWorkbench";
import type { PantryApi } from "./pantry/pantryApi";
import { PlanningInputReadinessWorkbench } from "./readiness/PlanningInputReadinessWorkbench";
import type { PlanningInputReadinessApi } from "./readiness/planningInputReadinessApi";
import { NeedGenerationWorkbench } from "./need-generation/NeedGenerationWorkbench";
import type { NeedGenerationApi } from "./need-generation/needGenerationApi";
import { ConfirmedNeedReviewWorkbench } from "./confirmed-needs/ConfirmedNeedReviewWorkbench";
import type { ConfirmedNeedApi } from "./confirmed-needs/confirmedNeedApi";

type TabId =
  | "menu"
  | "attendance"
  | "pantry"
  | "readiness"
  | "need-generation"
  | "confirmed-needs";
type LoadState = "idle" | "loading" | "ready" | "error";
type MenuSourceType = "MANUAL" | "WORKBOOK_IMPORT" | "GOOGLE_SHEET";
type GoogleFetchState = {
  status: "idle" | "fetching" | "success" | "error";
  sourceName?: string;
  sheetName?: string;
  fetchedAt?: string;
  sourceRowCount?: number;
  errorCode?: string;
};

function statusTone(status?: string) {
  if (status === "APPROVED") return "ok" as const;
  if (status === "VALIDATED") return "neutral" as const;
  return "warning" as const;
}

function statusLabel(status?: string) {
  const labels: Record<string, string> = {
    DRAFT: "BẢN NHÁP",
    VALIDATED: "ĐÃ XÁC THỰC",
    APPROVED: "ĐÃ PHÊ DUYỆT",
    REOPENED: "ĐÃ MỞ LẠI",
    NEED_GENERATION_REQUESTED: "ĐÃ CHUYỂN TIẾP",
    USED_FOR_NEED_GENERATION: "ĐÃ ĐƯỢC SỬ DỤNG",
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
    <section className="planning-source-summary" aria-label="Bằng chứng nguồn">
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
  );
}

function PreviewSummary<T>({
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
    <details className="planning-preview-summary" open>
      <summary>
        Xem trước có thẩm quyền ·{" "}
        {preview.source_row_count ?? preview.row_count} dòng nguồn ·{" "}
        {preview.row_count} dòng chuẩn hóa
      </summary>
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

function emptyData(weekStart: string): PlanningInputsWorkbenchData {
  const end = new Date(`${weekStart}T00:00:00Z`);
  end.setUTCDate(end.getUTCDate() + 6);
  return {
    week_start: weekStart,
    week_end: end.toISOString().slice(0, 10),
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

export function PlanningInputsWorkbench({
  authState,
  api,
  pantryApi,
  readinessApi,
  needGenerationApi,
  confirmedNeedApi,
  mode = "connected",
}: {
  authState: AtlasAuthState;
  api?: PlanningInputsApi;
  pantryApi?: PantryApi;
  readinessApi?: PlanningInputReadinessApi;
  needGenerationApi?: NeedGenerationApi;
  confirmedNeedApi?: ConfirmedNeedApi;
  mode?: "connected" | "review";
}) {
  const [correlationId] = useState(() => crypto.randomUUID());
  const [weekStart, setWeekStart] = useState(() => mondayOf(new Date()));
  const [tab, setTab] = useState<TabId>("menu");
  const [confirmedNeedBatchId, setConfirmedNeedBatchId] = useState<
    string | null
  >(null);
  const [load, setLoad] = useState<LoadState>("idle");
  const [data, setData] = useState(() => emptyData(weekStart));
  const [notice, setNotice] = useState<string | null>(null);
  const [dirty, setDirty] = useState(false);
  const [saving, setSaving] = useState(false);
  const [menuRows, setMenuRows] = useState<MenuLine[]>([]);
  const [attendanceRows, setAttendanceRows] = useState<AttendanceLine[]>([]);
  const [menuPreview, setMenuPreview] =
    useState<PlanningPreview<MenuLine> | null>(null);
  const [attendancePreview, setAttendancePreview] =
    useState<PlanningPreview<AttendanceLine> | null>(null);
  const [sourceName, setSourceName] = useState("Chỉnh sửa trực tiếp Atlas");
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
  const [reopenNote, setReopenNote] = useState("");
  const [schoolSearch, setSchoolSearch] = useState("");
  const [serviceDateFilter, setServiceDateFilter] = useState(weekStart);
  const generation = useRef(0);
  const authSubject =
    authState.status === "authenticated" ? authState.authSubject : null;

  const adopt = useCallback((workbench: PlanningInputsWorkbenchData) => {
    setData(workbench);
    setMenuRows(activeMenuRows(workbench.weekly_menu));
    setAttendanceRows(activeAttendanceRows(workbench.attendance));
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
    setSelectedGoogleSourceId((current) =>
      data.google_sheet_sources.some(
        (source) => source.weekly_menu_google_source_id === current,
      )
        ? current
        : (data.google_sheet_sources[0]?.weekly_menu_google_source_id ?? ""),
    );
  }, [data.google_sheet_sources]);

  useEffect(() => {
    if (!dirty) return;
    const warn = (event: BeforeUnloadEvent) => event.preventDefault();
    window.addEventListener("beforeunload", warn);
    return () => window.removeEventListener("beforeunload", warn);
  }, [dirty]);

  const changeWeek = (next: string) => {
    if (dirty && !window.confirm("Bỏ các thay đổi chưa lưu để chuyển tuần?"))
      return;
    setWeekStart(next);
    setServiceDateFilter(next);
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
        const date = new Date(`${data.week_start}T00:00:00Z`);
        date.setUTCDate(date.getUTCDate() + offset);
        return date.toISOString().slice(0, 10);
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

  const runCommand = async (
    invoke: (
      request: PlanningCommandRequest,
    ) => ReturnType<PlanningInputsApi["saveMenu"]>,
    request: PlanningCommandRequest,
  ) => {
    setSaving(true);
    setNotice(null);
    const result = await invoke(request);
    setSaving(false);
    setNotice(planningResultMessage(result));
    const readback = planningReadbackFromResult(result);
    if (readback) {
      adopt(readback);
      setLoad("ready");
      return true;
    }
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
    setSaving(false);
    const preview = planningPreviewFromResult<MenuLine>(result);
    setMenuPreview(preview);
    setNotice(planningResultMessage(result));
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
    setSaving(false);
    const preview = planningPreviewFromResult<AttendanceLine>(result);
    setAttendancePreview(preview);
    setNotice(planningResultMessage(result));
    return preview;
  };

  const saveMenu = async () => {
    if (!api || !authSubject) return;
    const preview = menuPreview ?? (await previewMenu());
    if (!preview?.can_save) return;
    await runCommand(
      api.saveMenu,
      planningCommandRequest(
        authSubject,
        correlationId,
        data.weekly_menu?.version ?? 1,
        "WEEKLY_MENU_DRAFT_SAVE",
        {
          week_start: weekStart,
          source_type: menuSourceType,
          source_name: sourceName,
          source_signature: preview.source_signature,
          expected_source_signature: data.weekly_menu?.source_signature ?? null,
          rows: preview.canonical_rows as unknown as JsonValue[],
        },
      ),
    );
  };

  const saveAttendance = async () => {
    if (!api || !authSubject) return;
    const preview = attendancePreview ?? (await previewAttendance());
    if (!preview?.can_save) return;
    await runCommand(
      api.saveAttendance,
      planningCommandRequest(
        authSubject,
        correlationId,
        data.attendance?.version ?? 1,
        "ATTENDANCE_DRAFT_SAVE",
        {
          week_start: weekStart,
          source_type: browserChecksum ? "WORKBOOK_IMPORT" : "MANUAL",
          source_name: sourceName,
          source_signature: preview.source_signature,
          expected_source_signature: data.attendance?.source_signature ?? null,
          rows: preview.canonical_rows as unknown as JsonValue[],
        },
      ),
    );
  };

  const menuAction = async (
    action: "validateMenu" | "approveMenu" | "reopenMenu",
  ) => {
    if (!api || !authSubject || !data.weekly_menu) return;
    await runCommand(
      api[action],
      planningCommandRequest(
        authSubject,
        correlationId,
        data.weekly_menu.version,
        `WEEKLY_MENU_${action.toUpperCase()}`,
        { week_start: weekStart },
        action === "reopenMenu" ? reopenNote : null,
      ),
    );
  };

  const attendanceAction = async (
    action: "validateAttendance" | "approveAttendance" | "reopenAttendance",
  ) => {
    if (!api || !authSubject || !data.attendance) return;
    await runCommand(
      api[action],
      planningCommandRequest(
        authSubject,
        correlationId,
        data.attendance.version,
        `ATTENDANCE_${action.toUpperCase()}`,
        { week_start: weekStart },
        action === "reopenAttendance" ? reopenNote : null,
      ),
    );
  };

  const createDefaults = async () => {
    if (!api || !authSubject) return;
    const preview = await previewAttendance(data.default_attendance_preview);
    if (!preview?.can_save) return;
    await runCommand(
      api.createAttendanceDefaults,
      planningCommandRequest(
        authSubject,
        correlationId,
        data.attendance?.version ?? 1,
        "ATTENDANCE_CREATE_DEFAULTS",
        {
          week_start: weekStart,
          source_signature: preview.source_signature,
          expected_source_signature: data.attendance?.source_signature ?? null,
        },
      ),
    );
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
    setSourceName(review.fileName);
    setMenuSourceType("WORKBOOK_IMPORT");
    setBrowserChecksum(review.browserChecksum);
    setImportErrors(review.errors);
    setImportWarnings(review.warnings);
    setGoogleFetch({ status: "idle" });
    setDirty(true);
    await previewMenu(review.rows);
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
    setSourceName(review.sourceName);
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
    await previewMenu(review.rows);
  };

  const onAttendanceFile = async (file?: File) => {
    if (!file) return;
    const review = await parseAttendanceWorkbook(file, data.schools);
    setAttendanceRows(review.rows);
    setSourceName(review.fileName);
    setBrowserChecksum(review.browserChecksum);
    setImportErrors(review.errors);
    setImportWarnings([]);
    setDirty(true);
    await previewAttendance(review.rows);
  };

  const updateMenuCell = (
    schoolId: string,
    serviceDate: string,
    slot: string,
    dishId: string,
  ) => {
    setMenuSourceType("MANUAL");
    setSourceName("Chỉnh sửa trực tiếp Atlas");
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
      <section className="planning-context-bar">
        <label>
          Tuần phục vụ
          <input
            type="date"
            value={weekStart}
            onChange={(event) => changeWeek(event.target.value)}
          />
        </label>
        <div>
          <span>Khoảng ngày</span>
          <b>
            {viDate(data.week_start)} – {viDate(data.week_end)}
          </b>
        </div>
        <button type="button" onClick={() => void refresh()} disabled={saving}>
          Tải lại có thẩm quyền
        </button>
      </section>

      {!authSubject ? (
        <p className="operator-notice warning">{authMessage}</p>
      ) : (
        <>
          <section
            className={`planning-readiness ${data.readiness.ready ? "ready" : ""}`}
            aria-label="Tình trạng sẵn sàng nguồn kế hoạch"
          >
            <div>
              <strong>
                {data.readiness.ready
                  ? "Hai nguồn tham chiếu đã được phê duyệt"
                  : "Hai nguồn tham chiếu chưa cùng được phê duyệt"}
              </strong>
              <small>
                Tham chiếu hai nguồn, không phải quyết định sẵn sàng có thẩm
                quyền. Xem tab Sẵn sàng đầu vào để quyết định theo ba nguồn.
              </small>
            </div>
            <Chip tone={data.readiness.weekly_menu_approved ? "ok" : "warning"}>
              Thực đơn{" "}
              {data.readiness.weekly_menu_approved ? "đã duyệt" : "chưa duyệt"}
            </Chip>
            <Chip tone={data.readiness.attendance_approved ? "ok" : "warning"}>
              Sĩ số{" "}
              {data.readiness.attendance_approved ? "đã duyệt" : "chưa duyệt"}
            </Chip>
          </section>

          <div className="planning-tabs" role="tablist">
            <button
              type="button"
              role="tab"
              aria-selected={tab === "menu"}
              className={tab === "menu" ? "active" : ""}
              onClick={() => setTab("menu")}
            >
              Thực đơn tuần
            </button>
            <button
              type="button"
              role="tab"
              aria-selected={tab === "attendance"}
              className={tab === "attendance" ? "active" : ""}
              onClick={() => setTab("attendance")}
            >
              Sĩ số
            </button>
            <button
              type="button"
              role="tab"
              aria-selected={tab === "pantry"}
              className={tab === "pantry" ? "active" : ""}
              onClick={() => setTab("pantry")}
            >
              Pantry
            </button>
            <button
              type="button"
              role="tab"
              aria-selected={tab === "readiness"}
              className={tab === "readiness" ? "active" : ""}
              onClick={() => setTab("readiness")}
            >
              Sẵn sàng đầu vào
            </button>
            <button
              type="button"
              role="tab"
              aria-selected={tab === "need-generation"}
              className={tab === "need-generation" ? "active" : ""}
              onClick={() => setTab("need-generation")}
            >
              Tạo nhu cầu
            </button>
            <button
              type="button"
              role="tab"
              aria-selected={tab === "confirmed-needs"}
              className={tab === "confirmed-needs" ? "active" : ""}
              onClick={() => setTab("confirmed-needs")}
            >
              Xác nhận nhu cầu
            </button>
          </div>

          {(tab === "menu" || tab === "attendance") && load === "loading" && (
            <p role="status" className="empty">
              Đang tải nguồn kế hoạch…
            </p>
          )}
          {(tab === "menu" || tab === "attendance") && load === "error" && (
            <div role="alert" className="command-outcome danger">
              <p>{notice}</p>
              <button type="button" onClick={() => void refresh()}>
                Thử tải lại
              </button>
            </div>
          )}

          {tab === "menu" && load !== "error" && (
            <Panel
              title="Thực đơn tuần"
              description="Nhập workbook hoặc chỉnh lưới trường/ngày; Atlas xem trước toàn bộ trước khi thay thế bản nháp."
              status={
                <Chip tone={statusTone(data.weekly_menu?.weekly_menu_status)}>
                  {statusLabel(data.weekly_menu?.weekly_menu_status)}
                </Chip>
              }
            >
              <div className="planning-toolbar">
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
                <label className="file-action">
                  Chọn workbook thực đơn
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
                  onClick={() => void onGoogleSync()}
                  disabled={
                    googleFetch.status === "fetching" || !selectedGoogleSourceId
                  }
                >
                  {googleFetch.status === "fetching"
                    ? "Đang đồng bộ…"
                    : "Đồng bộ từ Google Sheet"}
                </button>
                <button
                  type="button"
                  onClick={() => void previewMenu()}
                  disabled={saving || !menuRows.length}
                >
                  Xem trước
                </button>
                <button
                  type="button"
                  onClick={() => void saveMenu()}
                  disabled={saving || !menuRows.length}
                >
                  Lưu bản nháp
                </button>
                <button
                  type="button"
                  onClick={() => {
                    setMenuRows(activeMenuRows(data.weekly_menu));
                    setDirty(false);
                    setMenuPreview(null);
                    setMenuSourceType("MANUAL");
                    setSourceName("Chỉnh sửa trực tiếp Atlas");
                    setGoogleFetch({ status: "idle" });
                  }}
                  disabled={!dirty}
                >
                  Hủy thay đổi
                </button>
              </div>
              {data.google_sheet_sources.length === 0 && (
                <p className="operator-notice warning">
                  Chưa cấu hình nguồn Google Sheet.
                  <br />
                  Bạn vẫn có thể nhập tệp .xlsx.
                </p>
              )}
              <SourceSummary source={data.weekly_menu} />
              {googleFetch.status === "success" && (
                <section
                  className="planning-source-summary"
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
              )}
              {browserChecksum && (
                <p className="planning-checksum">
                  SHA-256 trình duyệt: <code>{browserChecksum}</code>
                </p>
              )}
              {importErrors.map((error) => (
                <p className="operator-notice danger" key={error}>
                  {error}
                </p>
              ))}
              {importWarnings.map((warning) => (
                <p className="operator-notice warning" key={warning}>
                  {warning}
                </p>
              ))}
              <PreviewSummary
                preview={menuPreview}
                kind="menu"
                schools={data.schools}
              />
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
                          <th>
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
                                  disabled={
                                    !["DRAFT", "REOPENED"].includes(
                                      data.weekly_menu?.weekly_menu_status ??
                                        "DRAFT",
                                    )
                                  }
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
                issues={
                  menuPreview?.issues.warnings ??
                  data.weekly_menu?.issues.warnings ??
                  []
                }
                tone="warning"
              />
              <div className="planning-lifecycle-actions">
                <button
                  type="button"
                  disabled={
                    saving || data.weekly_menu?.weekly_menu_status !== "DRAFT"
                  }
                  onClick={() => void menuAction("validateMenu")}
                >
                  Xác thực
                </button>
                <button
                  type="button"
                  disabled={
                    saving ||
                    data.weekly_menu?.weekly_menu_status !== "VALIDATED"
                  }
                  onClick={() => void menuAction("approveMenu")}
                >
                  Phê duyệt
                </button>
                {["APPROVED", "NEED_GENERATION_REQUESTED"].includes(
                  data.weekly_menu?.weekly_menu_status ?? "",
                ) && (
                  <>
                    <input
                      aria-label="Lý do mở lại thực đơn"
                      value={reopenNote}
                      onChange={(event) => setReopenNote(event.target.value)}
                      placeholder="Lý do bắt buộc"
                    />
                    <button
                      type="button"
                      disabled={saving || !reopenNote.trim()}
                      onClick={() => void menuAction("reopenMenu")}
                    >
                      Mở lại
                    </button>
                  </>
                )}
              </div>
              <History entries={data.weekly_menu?.approval_history ?? []} />
              <ChangeTimeline
                entries={data.weekly_menu?.change_history ?? []}
              />
            </Panel>
          )}

          {tab === "attendance" && load !== "error" && (
            <Panel
              title="Sĩ số"
              description="Tạo từ mặc định theo đúng trường/ngày có thực đơn, nhập workbook hoặc dán hàng loạt; số 0 luôn là giá trị tường minh."
              status={
                <Chip tone={statusTone(data.attendance?.attendance_status)}>
                  {statusLabel(data.attendance?.attendance_status)}
                </Chip>
              }
            >
              <div className="planning-toolbar">
                <button
                  type="button"
                  onClick={() => void createDefaults()}
                  disabled={saving}
                >
                  Tạo từ sĩ số mặc định
                </button>
                <label className="file-action">
                  Chọn workbook sĩ số
                  <input
                    type="file"
                    accept=".xlsx"
                    onChange={(event) =>
                      void onAttendanceFile(event.target.files?.[0])
                    }
                  />
                </label>
                <button
                  type="button"
                  onClick={() => void previewAttendance()}
                  disabled={saving || !attendanceRows.length}
                >
                  Xem trước
                </button>
                <button
                  type="button"
                  onClick={() => void saveAttendance()}
                  disabled={saving || !attendanceRows.length}
                >
                  Lưu bản nháp
                </button>
              </div>
              <SourceSummary source={data.attendance} />
              {browserChecksum && (
                <p className="planning-checksum">
                  SHA-256 trình duyệt: <code>{browserChecksum}</code>
                </p>
              )}
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
                    setSourceName("Dán hàng loạt Atlas");
                    setDirty(true);
                    void previewAttendance(rows);
                  }}
                >
                  Chuẩn hóa dữ liệu đã dán
                </button>
              </details>
              {attendanceRows.length === 0 ? (
                <p className="empty">Chưa có dòng sĩ số cho tuần này.</p>
              ) : (
                <div className="planning-grid-scroll">
                  <CompactTable
                    headers={[
                      "Trường",
                      "Ngày phục vụ",
                      "Suất học sinh",
                      "Suất giáo viên",
                      "Tổng",
                    ]}
                  >
                    {attendanceRows.map((line) => {
                      const school = data.schools.find(
                        (item) => item.school_id === line.school_id,
                      );
                      const editable = ["DRAFT", "REOPENED"].includes(
                        data.attendance?.attendance_status ?? "DRAFT",
                      );
                      return (
                        <tr key={`${line.school_id}:${line.service_date}`}>
                          <th>{school?.school_name ?? line.school_id}</th>
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
              <PreviewSummary
                preview={attendancePreview}
                kind="attendance"
                schools={data.schools}
              />
              {attendanceRows.length > 0 && (
                <p className="planning-attendance-totals">
                  Tổng: <b>{attendanceTotals.students}</b> suất học sinh ·{" "}
                  <b>{attendanceTotals.teachers}</b> suất giáo viên ·{" "}
                  <b>{attendanceTotals.students + attendanceTotals.teachers}</b>{" "}
                  suất
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
                  ...data.readiness.warnings,
                ]}
                tone="warning"
              />
              <div className="planning-lifecycle-actions">
                <button
                  type="button"
                  disabled={
                    saving || data.attendance?.attendance_status !== "DRAFT"
                  }
                  onClick={() => void attendanceAction("validateAttendance")}
                >
                  Xác thực
                </button>
                <button
                  type="button"
                  disabled={
                    saving || data.attendance?.attendance_status !== "VALIDATED"
                  }
                  onClick={() => void attendanceAction("approveAttendance")}
                >
                  Phê duyệt
                </button>
                {["APPROVED", "USED_FOR_NEED_GENERATION"].includes(
                  data.attendance?.attendance_status ?? "",
                ) && (
                  <>
                    <input
                      aria-label="Lý do mở lại sĩ số"
                      value={reopenNote}
                      onChange={(event) => setReopenNote(event.target.value)}
                      placeholder="Lý do bắt buộc"
                    />
                    <button
                      type="button"
                      disabled={saving || !reopenNote.trim()}
                      onClick={() => void attendanceAction("reopenAttendance")}
                    >
                      Mở lại
                    </button>
                  </>
                )}
              </div>
              <History entries={data.attendance?.approval_history ?? []} />
              <ChangeTimeline entries={data.attendance?.change_history ?? []} />
            </Panel>
          )}

          {tab === "pantry" && (
            <PantryWorkbench
              authState={authState}
              api={pantryApi}
              weekStart={weekStart}
              mode={mode}
            />
          )}

          {tab === "readiness" && (
            <PlanningInputReadinessWorkbench
              authState={authState}
              api={readinessApi}
              selectedWeekStart={weekStart}
              selectedWeekEnd={data.week_end}
              mode={mode}
            />
          )}

          {tab === "confirmed-needs" && (
            <ConfirmedNeedReviewWorkbench
              authState={authState}
              api={confirmedNeedApi}
              initialBatchId={confirmedNeedBatchId}
              mode={mode}
            />
          )}

          {tab === "need-generation" && (
            <NeedGenerationWorkbench
              authState={authState}
              api={needGenerationApi}
              selectedWeekStart={weekStart}
              selectedWeekEnd={data.week_end}
              mode={mode}
              onConfirmedNeedMaterialized={(nextBatchId: string) => {
                setConfirmedNeedBatchId(nextBatchId);
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
              Dữ liệu và lệnh trên trang này chỉ thuộc chế độ xem thử.
            </p>
          )}
        </>
      )}
    </div>
  );
}
