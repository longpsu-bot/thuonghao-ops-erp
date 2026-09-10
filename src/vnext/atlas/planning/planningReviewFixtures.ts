import type {
  AtlasRpcResult,
  AtlasSuccessEnvelope,
  PlanningInputsWorkbenchData,
  PantryWorkbenchData,
  PlanningPreview,
  MenuLine,
  AttendanceLine,
  PantryPreview,
  PlanningCorrectionImpact,
} from "../bridges/planning";

export const reviewWeek = "2026-09-07";
export const success = (value: object): AtlasRpcResult => ({
  kind: "success",
  response: { success: true, ...value } as AtlasSuccessEnvelope,
});
export const unknown: AtlasRpcResult = {
  kind: "transport_error",
  diagnostic: { code: "NETWORK_FAILURE", safeMessage: "Kết nối bị gián đoạn." },
};
export const stale: AtlasRpcResult = {
  kind: "backend_error",
  error: {
    success: false,
    error_code: "STALE_VERSION",
    retryable: false,
    safe_message: "Dữ liệu đã thay đổi.",
  },
};
export function planningSnapshot(): PlanningInputsWorkbenchData {
  const schools: PlanningInputsWorkbenchData["schools"] = Array.from(
    { length: 33 },
    (_, i) => ({
      school_id: `school-${i}`,
      school_code: `TH${String(i + 1).padStart(3, "0")}`,
      school_name:
        i === 0
          ? "Trường Nguyễn Du"
          : i === 1
            ? "Trường Lê Lợi"
            : `Trường học ${i + 1}`,
      school_status: "ACTIVE",
      display_order: i,
      school_type_id: null,
      default_student_portions: 100,
      default_teacher_portions: 10,
    }),
  );
  const menu: MenuLine[] = schools.map((s) => ({
    school_id: s.school_id,
    service_date: reviewWeek,
    menu_slot_code: "soup",
    dish_id: "dish-1",
    source_row_reference: null,
  }));
  const attendance: AttendanceLine[] = schools.map((s) => ({
    school_id: s.school_id,
    service_date: reviewWeek,
    student_portions: 100,
    teacher_portions: 10,
    source_row_reference: null,
  }));
  return {
    week_start: reviewWeek,
    week_end: "2026-09-13",
    schools,
    dish_types: [
      {
        dish_type_id: "type-1",
        dish_type_code: "soup",
        dish_type_name: "Món canh",
        source_header_aliases: ["Canh"],
        display_order: 1,
        dish_type_status: "ACTIVE",
        version: 1,
      },
    ],
    dishes: ["Canh bí thịt bằm", "Canh rau ngót"].map((name, i) => ({
      dish_id: `dish-${i + 1}`,
      dish_code: `CANH${i + 1}`,
      dish_name: name,
      dish_type_id: "type-1",
      dish_type_code: "soup",
      dish_type_name: "Món canh",
      dish_status: "ACTIVE",
      display_order: i,
      requires_need_generation: true,
    })),
    google_sheet_sources: [
      {
        weekly_menu_google_source_id: "google-1",
        source_code: "MENU",
        source_name: "Thực đơn chính thức",
        source_status: "ACTIVE",
        display_order: 1,
      },
    ],
    weekly_menu: {
      weekly_menu_id: "menu-1",
      week_start: reviewWeek,
      week_end: "2026-09-13",
      source_type: "GOOGLE_SHEET",
      source_name: "Thực đơn chính thức",
      source_signature: "menu-authority",
      weekly_menu_status: "APPROVED",
      row_count: menu.length,
      version: 4,
      latest_approved_at: null,
      latest_approval_snapshot_id: null,
      lines: menu,
      issues: { blockers: [], warnings: [] },
      change_history: [],
      approval_history: [],
    },
    attendance: {
      attendance_batch_id: "attendance-1",
      period_start: reviewWeek,
      period_end: "2026-09-13",
      source_type: "MANUAL_ATLAS",
      source_name: "Nhập thủ công Atlas",
      source_signature: "attendance-authority",
      attendance_status: "APPROVED",
      row_count: attendance.length,
      version: 3,
      latest_approved_at: null,
      latest_approval_snapshot_id: null,
      lines: attendance,
      issues: { blockers: [], warnings: [] },
      change_history: [],
      approval_history: [],
    },
    default_attendance_preview: attendance,
    readiness: {
      weekly_menu_approved: true,
      attendance_approved: true,
      weekly_menu_approval_snapshot_id: null,
      attendance_approval_snapshot_id: null,
      ready: true,
      warnings: [],
    },
  };
}
export function pantrySnapshot(): PantryWorkbenchData {
  return {
    week_start: reviewWeek,
    week_end: "2026-09-13",
    source_method: {
      source_type: "MANUAL_ATLAS",
      source_name: "Nhập thủ công Atlas",
    },
    schools: planningSnapshot().schools.map((s) => ({
      ...s,
      customer_id: "customer",
      customer_name: s.school_name,
      default_delivery_location: {
        delivery_location_id: `location-${s.school_id}`,
        location_code: "BEP",
        location_name: `Bếp ${s.school_name}`,
        address_text: "",
        timezone_name: "Asia/Ho_Chi_Minh",
      },
    })),
    ingredients: [
      {
        ingredient_id: "ingredient-1",
        ingredient_code: "GAO",
        ingredient_name: "Gạo thơm",
        ingredient_status: "ACTIVE",
        purchase_unit: { unit_id: "unit-1", unit_code: "KG", unit_name: "kg" },
      },
    ],
    purposes: [
      {
        pantry_need_purpose_id: "purpose-1",
        purpose_code: "EXTRA",
        purpose_name_vi: "Bổ sung theo yêu cầu",
        purpose_description: "",
        note_rule: "REQUIRED",
        purpose_status: "ACTIVE",
        display_order: 1,
        version: 1,
      },
    ],
    catalog_issues: { blockers: [], warnings: [] },
    batch: null,
    allowed_actions: {
      can_preview: true,
      can_save: true,
      can_validate: false,
      can_approve: false,
      can_reopen: false,
    },
  };
}
export const safeImpact: PlanningCorrectionImpact = {
  source_kind: "WEEKLY_MENU",
  material_change: true,
  affected_service_dates: [reviewWeek],
  date_impacts: [],
  save_allowed: true,
  save_blocker_code: null,
};
export function menuPreview(): PlanningPreview<MenuLine> {
  return {
    week_start: reviewWeek,
    week_end: "2026-09-13",
    canonical_rows: [
      {
        school_id: "school-0",
        service_date: reviewWeek,
        menu_slot_code: "soup",
        dish_id: "dish-2",
        source_row_reference: "official:4",
      },
    ],
    source_signature: "menu-preview",
    source_row_count: 1,
    row_count: 1,
    comparison: {
      changed_school_days: [
        { school_id: "school-0", service_date: reviewWeek },
      ],
    },
    issues: { blockers: [], warnings: [] },
    can_save: true,
  };
}
export function attendancePreview(): PlanningPreview<AttendanceLine> {
  return {
    ...menuPreview(),
    canonical_rows: [
      {
        school_id: "school-0",
        service_date: reviewWeek,
        student_portions: 0,
        teacher_portions: 12,
        source_row_reference: null,
      },
    ],
    source_signature: "attendance-preview",
  };
}
export function pantryPreview(): PantryPreview {
  return {
    week_start: reviewWeek,
    week_end: "2026-09-13",
    source_type: "MANUAL_ATLAS",
    source_name: "Nhập thủ công Atlas",
    source_signature: "pantry-preview",
    no_additions_confirmed: true,
    canonical_rows: [],
    school_date_modes: [],
    issues: { blockers: [], warnings: [] },
    comparison: {
      status: "NEW",
      current_batch_id: null,
      current_version: null,
      current_status: null,
      current_source_signature: null,
      new_lines: [],
      changed_lines: [],
      unchanged_lines: [],
      omitted_lines: [],
      changed_school_dates: [],
    },
    can_save: true,
  };
}

// Explicit response snapshots; these adapters never simulate backend algorithms.
export function createPlanningReviewFixture() {
  const planning = planningSnapshot(),
    pantry = pantrySnapshot();
  return {
    planning,
    pantry,
    api: {
      getWorkbench: async () => success({ workbench: planning }),
      syncMenuFromGoogle: async () =>
        success({
          source: { source_name: "Thực đơn chính thức", sheet_name: "Tuần 37" },
          fetched_at: "2026-09-07T01:00:00Z",
          rows: [
            ["Tên trường", "Ngày", "Món canh"],
            ["TH001", reviewWeek, "CANH2"],
          ],
        }),
      previewMenu: async () => success({ preview: menuPreview() }),
      previewAttendance: async () => success({ preview: attendancePreview() }),
      getCorrectionImpact: async () => success({ impact: safeImpact }),
      prepareCorrection: async () => success({}),
      saveCompletedMenu: async () =>
        success({ authoritative_readback: { planning_inputs: planning } }),
      saveCompletedAttendance: async () =>
        success({ authoritative_readback: { planning_inputs: planning } }),
    },
    pantryApi: {
      getWorkbench: async () => success({ workbench: pantry }),
      preview: async () => success({ preview: pantryPreview() }),
      getCorrectionImpact: async () =>
        success({ impact: { ...safeImpact, source_kind: "PANTRY" } }),
      prepareCorrection: async () => success({}),
      saveCompleted: async () =>
        success({ authoritative_readback: { pantry } }),
    },
  };
}
