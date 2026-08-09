import type {
  AtlasRpcResult,
  AtlasSafeBackendError,
  AtlasSuccessEnvelope,
  JsonValue,
} from "../connection/atlasRpc";
import type { AtlasReviewScenario } from "../review/reviewMode";
import type {
  AttendanceCompletionPayload,
  PlanningCompletionCommandRequest,
  PlanningCommandRequest,
  PlanningInputsApi,
  WeeklyMenuCompletionPayload,
} from "./planningInputsApi";
import type {
  AttendanceLine,
  AttendanceRecord,
  MenuLine,
  PlanningDishType,
  PlanningInputsWorkbenchData,
  PlanningIssue,
  WeeklyMenuRecord,
} from "./planningInputsModel";

const now = "2026-07-27T04:00:00.000Z";

const clone = <T>(value: T): T => structuredClone(value);
const success = (data: Record<string, JsonValue>): AtlasRpcResult => ({
  kind: "success",
  response: { success: true, ...data } as AtlasSuccessEnvelope,
});
const backendError = (errorCode: string): AtlasRpcResult => ({
  kind: "backend_error",
  error: {
    success: false,
    error_code: errorCode,
    safe_message: "Yêu cầu xem thử đã bị từ chối an toàn.",
  } as AtlasSafeBackendError,
});

const issue = (code: string, message: string): PlanningIssue => ({
  code,
  message,
  source_row_reference: "review:row:2",
});

function reviewRows(weekStart: string) {
  const menu: MenuLine[] = [
    {
      weekly_menu_line_id: "review-menu-line-1",
      school_id: "review-planning-school-1",
      service_date: weekStart,
      menu_slot_code: "soup",
      dish_id: "review-planning-dish-1",
      line_status: "ACTIVE",
      source_row_reference: "review-menu.xlsx:row:2:Món canh",
    },
    {
      weekly_menu_line_id: "review-menu-line-2",
      school_id: "review-planning-school-1",
      service_date: weekStart,
      menu_slot_code: "savory",
      dish_id: "review-planning-dish-2",
      line_status: "ACTIVE",
      source_row_reference: "review-menu.xlsx:row:2:Món mặn",
    },
    {
      weekly_menu_line_id: "review-menu-line-3",
      school_id: "review-planning-school-2",
      service_date: weekStart,
      menu_slot_code: "soup",
      dish_id: "review-planning-dish-3",
      line_status: "ACTIVE",
      source_row_reference: "review-menu.xlsx:row:3:Món canh",
    },
  ];
  const attendance: AttendanceLine[] = [
    {
      attendance_line_id: "review-attendance-line-1",
      school_id: "review-planning-school-1",
      service_date: weekStart,
      student_portions: 420,
      teacher_portions: 28,
      line_status: "ACTIVE",
      source_row_reference: "default:TH001",
    },
    {
      attendance_line_id: "review-attendance-line-2",
      school_id: "review-planning-school-2",
      service_date: weekStart,
      student_portions: 360,
      teacher_portions: 24,
      line_status: "ACTIVE",
      source_row_reference: "default:TH002",
    },
  ];
  return { menu, attendance };
}

function statusFor(scenario: AtlasReviewScenario, kind: "menu" | "attendance") {
  const prefix = kind === "menu" ? "menu_" : "attendance_";
  if (scenario === `${prefix}validated`) return "VALIDATED";
  if (scenario === `${prefix}approved`) return "APPROVED";
  if (scenario === `${prefix}reopened`) return "REOPENED";
  return "DRAFT";
}

function fixtures(
  scenario: AtlasReviewScenario,
  weekStart: string,
): PlanningInputsWorkbenchData {
  const weekEnd = new Date(`${weekStart}T00:00:00Z`);
  weekEnd.setUTCDate(weekEnd.getUTCDate() + 6);
  const end = weekEnd.toISOString().slice(0, 10);
  const rows = reviewRows(weekStart);
  const menuStatus = statusFor(
    scenario,
    "menu",
  ) as WeeklyMenuRecord["weekly_menu_status"];
  const attendanceStatus = statusFor(
    scenario,
    "attendance",
  ) as AttendanceRecord["attendance_status"];
  const menuBlockers: PlanningIssue[] =
    scenario === "menu_invalid_dates"
      ? [issue("SERVICE_DATE_OUTSIDE_WEEK", "Ngày phục vụ nằm ngoài tuần.")]
      : scenario === "menu_duplicate"
        ? [
            issue(
              "DUPLICATE_MENU_ASSIGNMENT",
              "Trùng trường, ngày và ô thực đơn.",
            ),
          ]
        : scenario === "menu_inactive_refs"
          ? [issue("INACTIVE_DISH", "Món ăn đã ngừng hoạt động.")]
          : scenario === "menu_type_mismatch" ||
              scenario === "google_preview_blockers"
            ? [
                issue(
                  "DISH_TYPE_MISMATCH",
                  "Món ăn không khớp Loại món của cột thực đơn.",
                ),
              ]
            : [];
  const menuRows = scenario === "menu_zero_valid" ? [] : clone(rows.menu);
  if (scenario === "menu_type_mismatch" && menuRows[0])
    menuRows[0].dish_id = "review-planning-dish-2";
  const attendanceRows =
    scenario === "attendance_zero"
      ? rows.attendance.map((line) => ({
          ...line,
          student_portions: 0,
          teacher_portions: 0,
        }))
      : scenario === "attendance_negative"
        ? rows.attendance.map((line, index) => ({
            ...line,
            student_portions: index === 0 ? -1 : line.student_portions,
          }))
        : clone(rows.attendance);
  const menuWarnings =
    scenario === "menu_recipe_warning"
      ? [
          issue(
            "RECIPE_NOT_READY",
            "Món ăn chưa có công thức phát hành phù hợp.",
          ),
        ]
      : scenario === "menu_diff_approved"
        ? [
            issue(
              "DIFFERS_FROM_APPROVED_MENU",
              "Phân công khác lần phê duyệt gần nhất.",
            ),
          ]
        : [];
  const attendanceWarnings =
    scenario === "attendance_diff_defaults"
      ? [issue("PORTIONS_DIFFER_FROM_DEFAULT", "Sĩ số khác mặc định hiện tại.")]
      : scenario === "attendance_diff_approved"
        ? [
            issue(
              "PORTIONS_DIFFER_FROM_APPROVED",
              "Sĩ số khác lần phê duyệt gần nhất.",
            ),
          ]
        : scenario === "attendance_missing_menu"
          ? [
              issue(
                "ATTENDANCE_WITHOUT_MENU_ASSIGNMENT",
                "Có sĩ số nhưng chưa có phân công thực đơn.",
              ),
            ]
          : [];
  const attendanceBlockers =
    scenario === "attendance_negative"
      ? [issue("INVALID_STUDENT_PORTIONS", "Số suất học sinh không được âm.")]
      : [];
  const menuApproved = menuStatus === "APPROVED";
  const attendanceApproved = attendanceStatus === "APPROVED";
  const dishTypes: PlanningDishType[] = [
    {
      dish_type_id: "review-dish-type-soup",
      dish_type_code: "soup",
      dish_type_name:
        scenario === "dish_types_renamed" ? "Canh trong ngày" : "Món canh",
      source_header_aliases: ["Canh"],
      display_order: 1,
      dish_type_status: "ACTIVE",
      version: 1,
    },
    {
      dish_type_id: "review-dish-type-savory",
      dish_type_code: "savory",
      dish_type_name: "Món mặn",
      source_header_aliases: ["Mặn"],
      display_order: scenario === "dish_types_reordered" ? 0 : 2,
      dish_type_status: "ACTIVE",
      version: 1,
    },
    {
      dish_type_id: "review-dish-type-stir-fry",
      dish_type_code: "stir_fry",
      dish_type_name: "Món xào",
      source_header_aliases: ["Xào"],
      display_order: 3,
      dish_type_status: "ACTIVE",
      version: 1,
    },
    {
      dish_type_id: "review-dish-type-dessert",
      dish_type_code: "dessert",
      dish_type_name: "Tráng miệng",
      source_header_aliases: [],
      display_order: 4,
      dish_type_status: "ACTIVE",
      version: 1,
    },
    {
      dish_type_id: "review-dish-type-snack",
      dish_type_code: "afternoon_snack",
      dish_type_name: "Buổi xế",
      source_header_aliases: ["Bữa xế"],
      display_order: 5,
      dish_type_status: "ACTIVE",
      version: 1,
    },
    {
      dish_type_id: "review-dish-type-beverage",
      dish_type_code: "beverage",
      dish_type_name: "Nước",
      source_header_aliases: ["Đồ uống"],
      display_order: 6,
      dish_type_status: "ACTIVE",
      version: 1,
    },
  ];
  if (scenario === "dish_types_added") {
    dishTypes.push({
      dish_type_id: "review-dish-type-salad",
      dish_type_code: "salad",
      dish_type_name: "Món trộn",
      source_header_aliases: ["Salad"],
      display_order: 7,
      dish_type_status: "ACTIVE",
      version: 1,
    });
  }
  const activeDishTypes =
    scenario === "dish_types_inactive"
      ? dishTypes.filter((dishType) => dishType.dish_type_code !== "dessert")
      : dishTypes;
  return {
    week_start: weekStart,
    week_end: end,
    dish_types: activeDishTypes,
    google_sheet_sources:
      scenario === "google_source_missing"
        ? []
        : [
            {
              weekly_menu_google_source_id: "review-google-source",
              source_code: "review-menu",
              source_name: "Nguồn thực đơn xem thử",
              source_status: "ACTIVE",
              display_order: 1,
            },
          ],
    schools: [
      {
        school_id: "review-planning-school-1",
        school_code: "TH001",
        school_name: "Trường Tiểu học Nguyễn Du",
        school_status: "ACTIVE",
        display_order: 1,
        school_type_id: "review-primary",
        default_student_portions: 420,
        default_teacher_portions: 28,
      },
      {
        school_id: "review-planning-school-2",
        school_code: "TH002",
        school_name: "Trường Tiểu học Trần Quốc Toản",
        school_status: "ACTIVE",
        display_order: 2,
        school_type_id: "review-primary",
        default_student_portions: 360,
        default_teacher_portions: 24,
      },
      {
        school_id: "review-planning-school-3",
        school_code: "TH003",
        school_name: "Trường Mầm non Hoa Hồng",
        school_status: "INACTIVE",
        display_order: 3,
        school_type_id: "review-preschool",
        default_student_portions: 180,
        default_teacher_portions: 18,
      },
    ],
    dishes: Array.from({ length: 7 }, (_, index) => {
      const dishType = dishTypes[[0, 1, 0, 2, 3, 5, 4][index] ?? 0];
      return {
        dish_id: `review-planning-dish-${index + 1}`,
        dish_code: `MON${String(index + 1).padStart(3, "0")}`,
        dish_name: [
          "Canh bí đỏ thịt bằm",
          "Thịt lợn kho trứng",
          "Canh rau ngót",
          "Rau cải xào tỏi",
          "Dưa hấu",
          "Sữa chua",
          "Chuối tiêu",
        ][index]!,
        dish_category: null,
        dish_type_id: dishType?.dish_type_id ?? null,
        dish_type_code: dishType?.dish_type_code ?? null,
        dish_type_name: dishType?.dish_type_name ?? null,
        dish_status: index === 6 ? ("INACTIVE" as const) : ("ACTIVE" as const),
        display_order: index + 1,
        requires_need_generation: index < 4,
      };
    }),
    weekly_menu:
      scenario === "empty" || scenario === "menu_empty"
        ? null
        : {
            weekly_menu_id: "review-weekly-menu",
            week_start: weekStart,
            week_end: end,
            source_type: "WORKBOOK_IMPORT",
            source_name: "OPS Menu Weekly",
            source_signature: "review-menu-checksum",
            weekly_menu_status: menuStatus,
            row_count: menuRows.length,
            version: scenario === "menu_reopened" ? 2 : 1,
            latest_approved_at: menuStatus === "DRAFT" ? null : now,
            latest_approval_snapshot_id:
              menuStatus === "DRAFT" ? null : "review-menu-snapshot",
            lines: menuRows,
            issues: { blockers: menuBlockers, warnings: menuWarnings },
            change_history: [
              {
                audit_event_id: "review-menu-audit",
                event_type: "WeeklyMenuDraftCreated",
                version_before: 1,
                version_after: 1,
                actor_id: "review-actor",
                actor_display_name: "Nguyễn Minh Anh",
                reason_code: "MENU_IMPORT",
                reason_note: "Nhập thực đơn tuần.",
                occurred_at: now,
              },
            ],
            approval_history:
              menuStatus === "DRAFT"
                ? []
                : [
                    {
                      approval_snapshot_id: "review-menu-snapshot",
                      version: 1,
                      approved_by_actor_id: "review-actor",
                      approved_by_display_name: "Nguyễn Minh Anh",
                      approved_at: now,
                      line_count: rows.menu.length,
                    },
                  ],
          },
    attendance:
      scenario === "empty"
        ? null
        : {
            attendance_batch_id: "review-attendance",
            period_start: weekStart,
            period_end: end,
            source_type:
              scenario === "attendance_imported"
                ? "WORKBOOK_IMPORT"
                : "SCHOOL_DEFAULTS",
            source_name:
              scenario === "attendance_imported"
                ? "Sĩ số tuần 03-08-2026.xlsx"
                : "Sĩ số mặc định theo thực đơn",
            source_signature: "review-attendance-checksum",
            attendance_status: attendanceStatus,
            row_count: attendanceRows.length,
            version: scenario === "attendance_reopened" ? 2 : 1,
            latest_approved_at: attendanceStatus === "DRAFT" ? null : now,
            latest_approval_snapshot_id:
              attendanceStatus === "DRAFT"
                ? null
                : "review-attendance-snapshot",
            lines: attendanceRows,
            issues: {
              blockers: attendanceBlockers,
              warnings: attendanceWarnings,
            },
            change_history: [
              {
                audit_event_id: "review-attendance-audit",
                event_type: "AttendanceDraftCreated",
                version_before: 1,
                version_after: 1,
                actor_id: "review-actor",
                actor_display_name: "Nguyễn Minh Anh",
                reason_code: "ATTENDANCE_IMPORT",
                reason_note: "Nhập số suất ăn tuần.",
                occurred_at: now,
              },
            ],
            approval_history:
              attendanceStatus === "DRAFT"
                ? []
                : [
                    {
                      approval_snapshot_id: "review-attendance-snapshot",
                      version: 1,
                      approved_by_actor_id: "review-actor",
                      approved_by_display_name: "Nguyễn Minh Anh",
                      approved_at: now,
                      line_count: rows.attendance.length,
                    },
                  ],
          },
    readiness: {
      weekly_menu_approved: menuApproved,
      attendance_approved: attendanceApproved,
      weekly_menu_approval_snapshot_id: menuApproved
        ? "review-menu-snapshot"
        : null,
      attendance_approval_snapshot_id: attendanceApproved
        ? "review-attendance-snapshot"
        : null,
      ready: menuApproved && attendanceApproved,
      warnings: attendanceWarnings,
    },
    default_attendance_preview: clone(rows.attendance),
  };
}

function scenarioError(scenario: AtlasReviewScenario, write = false) {
  if (
    scenario === "permission_denied" ||
    scenario === "menu_permission_denied" ||
    scenario === "attendance_permission_denied"
  )
    return backendError("CAPABILITY_DENIED");
  if (
    write &&
    (scenario === "stale" ||
      scenario === "menu_stale" ||
      scenario === "attendance_stale")
  )
    return backendError("STALE_VERSION");
  if (
    write &&
    (scenario === "menu_retryable" || scenario === "attendance_retryable")
  )
    return backendError("RETRYABLE_CONCURRENCY_FAILURE");
  if (scenario === "server_error") return backendError("INTERNAL_READ_FAILURE");
  return null;
}

export function createReviewPlanningInputsApi(
  scenario: AtlasReviewScenario = "ready",
): PlanningInputsApi {
  let current = fixtures(scenario, "2026-08-03");
  const response = () =>
    success({
      authoritative_readback: clone(current) as unknown as JsonValue,
      idempotency_status:
        scenario === "menu_replay_success" ||
        scenario === "attendance_replay_success"
          ? "NO_CHANGE"
          : "COMPLETED",
      safe_operator_message:
        "Đã cập nhật dữ liệu xem thử; thay đổi mất khi tải lại trang.",
    });
  const mutate = (
    request: PlanningCommandRequest,
    callback: () => void,
  ): Promise<AtlasRpcResult> => {
    const blocked = scenarioError(scenario, true);
    if (blocked) return Promise.resolve(blocked);
    if (!request.payload.week_start)
      return Promise.resolve(backendError("VALIDATION_FAILED"));
    callback();
    return Promise.resolve(response());
  };
  const mutateCompletion = (
    request:
      | PlanningCompletionCommandRequest<WeeklyMenuCompletionPayload>
      | PlanningCompletionCommandRequest<AttendanceCompletionPayload>,
    callback: () => void,
  ): Promise<AtlasRpcResult> => {
    const blocked = scenarioError(scenario, true);
    if (blocked) return Promise.resolve(blocked);
    if (!request.payload.week_start)
      return Promise.resolve(backendError("VALIDATION_FAILED"));
    callback();
    return Promise.resolve(
      success({
        authoritative_readback: {
          planning_inputs: clone(current) as unknown as JsonValue,
          preflight: {
            downstream_currentness: "NOT_GENERATED",
          },
        },
        downstream_currentness: "NOT_GENERATED",
        idempotency_status: "COMPLETED",
        safe_operator_message:
          "Đã lưu. Phiên bản này đang được sử dụng cho Kế hoạch.",
      }),
    );
  };

  return {
    getWorkbench(_authSubject, _correlationId, weekStart) {
      if (scenario === "loading")
        return new Promise<AtlasRpcResult>(() => undefined);
      const blocked = scenarioError(scenario);
      if (blocked) return Promise.resolve(blocked);
      current = fixtures(scenario, weekStart);
      return Promise.resolve(
        success({ workbench: clone(current) as unknown as JsonValue }),
      );
    },
    previewMenu(_auth, _correlation, weekStart, rows) {
      const blocked = scenarioError(scenario);
      if (blocked) return Promise.resolve(blocked);
      const blockers = current.weekly_menu?.issues.blockers ?? [];
      return Promise.resolve(
        success({
          preview: {
            week_start: weekStart,
            week_end: current.week_end,
            canonical_rows: clone(rows),
            source_signature: `review-menu-${rows.length}`,
            source_row_count: rows.length,
            row_count: rows.length,
            normalized_assignment_count: rows.length,
            comparison: {
              new_assignments: 0,
              changed_assignments: scenario === "menu_diff_approved" ? 1 : 0,
              unchanged_assignments: rows.length,
              omitted_prior_assignments: 0,
              changed_school_days:
                scenario === "menu_diff_approved"
                  ? [
                      {
                        school_id: "review-planning-school-1",
                        service_date: weekStart,
                      },
                    ]
                  : [],
            },
            issues: {
              blockers,
              warnings: current.weekly_menu?.issues.warnings ?? [],
            },
            can_save: blockers.length === 0,
          },
        }),
      );
    },
    previewAttendance(_auth, _correlation, weekStart, rows) {
      const blocked = scenarioError(scenario);
      if (blocked) return Promise.resolve(blocked);
      const issues = current.attendance?.issues ?? {
        blockers: [],
        warnings: [],
      };
      return Promise.resolve(
        success({
          preview: {
            week_start: weekStart,
            week_end: current.week_end,
            canonical_rows: clone(rows),
            source_signature: `review-attendance-${rows.length}`,
            source_row_count: rows.length,
            row_count: rows.length,
            normalized_row_count: rows.length,
            comparison: {
              new_rows: 0,
              changed_rows: scenario === "attendance_diff_approved" ? 1 : 0,
              unchanged_rows: rows.length,
              omitted_prior_rows: 0,
              changed_school_days:
                scenario === "attendance_diff_approved"
                  ? [
                      {
                        school_id: "review-planning-school-1",
                        service_date: weekStart,
                      },
                    ]
                  : [],
            },
            issues,
            can_save: issues.blockers.length === 0,
          },
        }),
      );
    },
    syncMenuFromGoogle(sourceId, weekStart, correlationId) {
      if (scenario === "google_source_missing")
        return Promise.resolve(backendError("GOOGLE_SOURCE_UNAVAILABLE"));
      if (scenario === "google_source_unavailable")
        return Promise.resolve(backendError("GOOGLE_SOURCE_UNAVAILABLE"));
      if (scenario === "google_empty_sheet")
        return Promise.resolve(backendError("EMPTY_SHEET"));
      if (scenario === "google_sheet_missing")
        return Promise.resolve(backendError("WEEKLY_SHEET_MISSING"));
      if (scenario === "google_connector_unavailable")
        return Promise.resolve(backendError("CONNECTOR_UNAVAILABLE"));
      if (scenario === "google_permission_denied")
        return Promise.resolve(backendError("CAPABILITY_DENIED"));
      if (scenario === "google_retryable")
        return Promise.resolve(backendError("GOOGLE_UPSTREAM_RETRYABLE"));
      if (sourceId !== "review-google-source")
        return Promise.resolve(backendError("GOOGLE_SOURCE_UNAVAILABLE"));
      const soupType = current.dish_types.find(
        (dishType) => dishType.dish_type_code === "soup",
      );
      return Promise.resolve(
        success({
          source: {
            source_id: sourceId,
            source_code: "review-menu",
            source_name: "Nguồn thực đơn xem thử",
            sheet_name: `Tuần ${weekStart.split("-").reverse().join("-")}`,
            range: "'review-week'!A3:Z500",
          },
          fetched_at: now,
          rows: [
            ["Tên trường", "Ngày", soupType?.dish_type_name ?? "Món canh"],
            [
              "TH001",
              weekStart,
              scenario === "google_preview_blockers"
                ? "Món không tồn tại"
                : "MON001",
            ],
          ],
          warnings: [],
          correlation_id: correlationId,
        }),
      );
    },
    saveCompletedMenu(request) {
      return mutateCompletion(request, () => {
        if (!current.weekly_menu) return;
        current.weekly_menu.weekly_menu_status = "APPROVED";
        current.weekly_menu.lines = clone(
          request.payload.rows as unknown as MenuLine[],
        );
        current.weekly_menu.source_signature = request.payload.source_signature;
        current.readiness.weekly_menu_approved = true;
        current.readiness.ready = current.readiness.attendance_approved;
      });
    },
    saveMenu(request) {
      return mutate(request, () => {
        if (!current.weekly_menu) return;
        current.weekly_menu.weekly_menu_status = "DRAFT";
        current.weekly_menu.lines = clone(
          request.payload.rows as unknown as MenuLine[],
        );
        current.weekly_menu.source_signature = String(
          request.payload.source_signature,
        );
      });
    },
    validateMenu(request) {
      return mutate(request, () => {
        if (current.weekly_menu)
          current.weekly_menu.weekly_menu_status = "VALIDATED";
      });
    },
    approveMenu(request) {
      return mutate(request, () => {
        if (!current.weekly_menu) return;
        current.weekly_menu.weekly_menu_status = "APPROVED";
        current.readiness.weekly_menu_approved = true;
        current.readiness.ready = current.readiness.attendance_approved;
      });
    },
    reopenMenu(request) {
      return mutate(request, () => {
        if (!current.weekly_menu) return;
        current.weekly_menu.weekly_menu_status = "REOPENED";
        current.weekly_menu.version += 1;
        current.readiness.weekly_menu_approved = false;
        current.readiness.ready = false;
      });
    },
    createAttendanceDefaults(request) {
      return mutate(request, () => {
        if (current.attendance) {
          current.attendance.attendance_status = "DRAFT";
          current.attendance.lines = clone(current.default_attendance_preview);
        }
      });
    },
    saveCompletedAttendance(request) {
      return mutateCompletion(request, () => {
        if (!current.attendance) return;
        current.attendance.attendance_status = "APPROVED";
        current.attendance.lines = clone(
          request.payload.rows as unknown as AttendanceLine[],
        );
        current.attendance.source_signature = request.payload.source_signature;
        current.readiness.attendance_approved = true;
        current.readiness.ready = current.readiness.weekly_menu_approved;
      });
    },
    saveAttendance(request) {
      return mutate(request, () => {
        if (!current.attendance) return;
        current.attendance.attendance_status = "DRAFT";
        current.attendance.lines = clone(
          request.payload.rows as unknown as AttendanceLine[],
        );
        current.attendance.source_signature = String(
          request.payload.source_signature,
        );
      });
    },
    validateAttendance(request) {
      return mutate(request, () => {
        if (current.attendance)
          current.attendance.attendance_status = "VALIDATED";
      });
    },
    approveAttendance(request) {
      return mutate(request, () => {
        if (!current.attendance) return;
        current.attendance.attendance_status = "APPROVED";
        current.readiness.attendance_approved = true;
        current.readiness.ready = current.readiness.weekly_menu_approved;
      });
    },
    reopenAttendance(request) {
      return mutate(request, () => {
        if (!current.attendance) return;
        current.attendance.attendance_status = "REOPENED";
        current.attendance.version += 1;
        current.readiness.attendance_approved = false;
        current.readiness.ready = false;
      });
    },
  };
}
