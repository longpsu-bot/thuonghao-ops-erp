import type {
  AtlasRpcResult,
  AtlasSuccessEnvelope,
  PlanningInputsWorkbenchData,
  PantryWorkbenchData,
  PlanningPreview,
  MenuLine,
  AttendanceLine,
  PantryPreview,
  PantryApi,
  PantrySchoolDateMode,
  JsonValue,
  PlanningCorrectionImpact,
  PlanningInputsApi,
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
        dish_type_id: "type-main",
        dish_type_code: "main",
        dish_type_name: "Món mặn",
        source_header_aliases: ["Món mặn"],
        display_order: 1,
        dish_type_status: "ACTIVE",
        version: 1,
      },
      {
        dish_type_id: "type-soup",
        dish_type_code: "soup",
        dish_type_name: "Món canh",
        source_header_aliases: ["Món canh"],
        display_order: 2,
        dish_type_status: "ACTIVE",
        version: 1,
      },
      {
        dish_type_id: "type-stir",
        dish_type_code: "stir_fry",
        dish_type_name: "Món xào",
        source_header_aliases: ["Món xào"],
        display_order: 3,
        dish_type_status: "ACTIVE",
        version: 1,
      },
      {
        dish_type_id: "type-veg",
        dish_type_code: "vegetable",
        dish_type_name: "Rau",
        source_header_aliases: ["Rau"],
        display_order: 4,
        dish_type_status: "ACTIVE",
        version: 1,
      },
      {
        dish_type_id: "type-dessert",
        dish_type_code: "dessert",
        dish_type_name: "Tráng miệng",
        source_header_aliases: ["Tráng miệng"],
        display_order: 5,
        dish_type_status: "ACTIVE",
        version: 1,
      },
      {
        dish_type_id: "type-old",
        dish_type_code: "old",
        dish_type_name: "Loại cũ",
        source_header_aliases: [],
        display_order: 99,
        dish_type_status: "INACTIVE",
        version: 1,
      },
    ],
    dishes: [
      {
        dish_id: "dish-1",
        dish_code: "CANH1",
        dish_name: "Canh bí thịt bằm",
        dish_type_id: "type-soup",
        dish_type_code: "soup",
        dish_type_name: "Món canh",
      },
      {
        dish_id: "dish-2",
        dish_code: "CANH2",
        dish_name: "Canh rau ngót",
        dish_type_id: "type-soup",
        dish_type_code: "soup",
        dish_type_name: "Món canh",
      },
      {
        dish_id: "dish-main",
        dish_code: "MAN1",
        dish_name: "Thịt kho",
        dish_type_id: "type-main",
        dish_type_code: "main",
        dish_type_name: "Món mặn",
      },
      {
        dish_id: "dish-stir",
        dish_code: "XAO1",
        dish_name: "Rau củ xào",
        dish_type_id: "type-stir",
        dish_type_code: "stir_fry",
        dish_type_name: "Món xào",
      },
      {
        dish_id: "dish-veg",
        dish_code: "RAU1",
        dish_name: "Rau luộc",
        dish_type_id: "type-veg",
        dish_type_code: "vegetable",
        dish_type_name: "Rau",
      },
      {
        dish_id: "dish-dessert",
        dish_code: "TM1",
        dish_name: "Chuối",
        dish_type_id: "type-dessert",
        dish_type_code: "dessert",
        dish_type_name: "Tráng miệng",
      },
    ].map((dish, i) => ({
      ...dish,
      dish_status: "ACTIVE" as const,
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
        purpose_code: "planning_identified_supplement",
        purpose_name_vi: "Bổ sung",
        purpose_description: "",
        note_rule: "OPTIONAL",
        purpose_status: "ACTIVE",
        display_order: 1,
        version: 1,
      },
      {
        pantry_need_purpose_id: "purpose-2",
        purpose_code: "school_requested_supplement",
        purpose_name_vi: "Đặt theo yêu cầu nhà trường",
        purpose_description: "",
        note_rule: "OPTIONAL",
        purpose_status: "ACTIVE",
        display_order: 2,
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
      saveCompletedMenu: async (
        request: Parameters<PlanningInputsApi["saveCompletedMenu"]>[0],
      ) => {
        const readback = structuredClone(planning);
        readback.weekly_menu = {
          ...readback.weekly_menu!,
          source_type: request.payload.source_type,
          source_name: request.payload.source_name,
          source_signature: request.payload.source_signature,
          lines: request.payload.rows as unknown as MenuLine[],
          row_count: request.payload.rows.length,
          version: request.expected_version + 1,
        };
        return success({
          authoritative_readback: { planning_inputs: readback },
        });
      },
      saveCompletedAttendance: async () =>
        success({ authoritative_readback: { planning_inputs: planning } }),
    },
    pantryApi: {
      getWorkbench: async () => success({ workbench: pantry }),
      preview: async (
        _subject: string,
        _correlation: string,
        week: string,
        noAdditions: boolean,
        rows: JsonValue[],
        modes: PantrySchoolDateMode[] = [],
      ) => {
        // Synthetic review response echoes the submitted proposal; it does not
        // certify a signature or simulate backend validation.
        const submitted = structuredClone(rows).map((value) => {
          const row = value as Record<string, JsonValue>;
          const school = pantry.schools.find(
            (item) => item.school_id === row.school_id,
          );
          const ingredient = pantry.ingredients.find(
            (item) => item.ingredient_id === row.ingredient_id,
          );
          return {
            ...row,
            school_id: row.school_id,
            service_date: row.service_date,
            ingredient_id: row.ingredient_id,
            pantry_need_purpose_id: row.pantry_need_purpose_id,
            school_name: school?.school_name ?? "",
            ingredient_name: ingredient?.ingredient_name ?? "",
            delivery_location_name:
              school?.default_delivery_location.location_name ?? "",
            unit_name: ingredient?.purchase_unit.unit_name ?? "",
          };
        });
        const preview = pantryPreview();
        return success({
          preview: {
            ...preview,
            week_start: week,
            no_additions_confirmed: noAdditions,
            canonical_rows: submitted,
            school_date_modes: structuredClone(modes),
            comparison: {
              ...preview.comparison,
              new_lines: submitted,
              omitted_lines: (pantry.batch?.active_lines ?? []).filter(
                (line) =>
                  !submitted.some(
                    (row) =>
                      row.service_date === line.service_date &&
                      row.school_id === line.school_id &&
                      row.ingredient_id === line.ingredient_id &&
                      row.pantry_need_purpose_id ===
                        line.pantry_need_purpose_id,
                  ),
              ),
              changed_school_dates: submitted.map((row) => ({
                school_id: row.school_id,
                service_date: row.service_date,
              })),
            },
          },
        });
      },
      getCorrectionImpact: async () =>
        success({ impact: { ...safeImpact, source_kind: "PANTRY" } }),
      prepareCorrection: async () => success({}),
      saveCompleted: async (
        request: Parameters<PantryApi["saveCompleted"]>[0],
      ) => {
        const at = `${request.payload.week_start}T00:00:00Z`;
        const previous = pantry.batch;
        pantry.batch = {
          pantry_need_batch_id:
            previous?.pantry_need_batch_id ?? "review-only-pantry-batch",
          week_start: request.payload.week_start,
          week_end: pantry.week_end,
          pantry_need_batch_status: "APPROVED",
          version: request.expected_version + 1,
          source_type: "MANUAL_ATLAS",
          source_name: "Nhập thủ công Atlas",
          source_signature: request.payload.source_signature,
          no_additions_confirmed: request.payload.no_additions_confirmed,
          school_date_modes: structuredClone(request.payload.school_date_modes),
          requesting_actor_id: "review-only-operator",
          requesting_actor_name: "Dữ liệu xem thử, không ghi hệ thống",
          creation_method: "MANUAL_ATLAS",
          latest_approved_by_actor_id: null,
          latest_approved_at: null,
          latest_approval_snapshot_id: null,
          created_at: previous?.created_at ?? at,
          updated_at: at,
          active_lines: request.payload.rows.map((value, index) => {
            const row = value as Record<string, JsonValue>;
            const text = (key: string) =>
              typeof row[key] === "string" ? (row[key] as string) : "";
            const school = pantry.schools.find(
              (item) => item.school_id === text("school_id"),
            );
            const ingredient = pantry.ingredients.find(
              (item) => item.ingredient_id === text("ingredient_id"),
            );
            return {
              pantry_need_line_id: `review-only-pantry-line-${index}`,
              service_date: text("service_date"),
              school_id: text("school_id"),
              school_code: school?.school_code ?? "",
              school_name: school?.school_name ?? "",
              ingredient_id: text("ingredient_id"),
              ingredient_code: ingredient?.ingredient_code ?? "",
              ingredient_name: ingredient?.ingredient_name ?? "",
              delivery_location_id:
                school?.default_delivery_location.delivery_location_id ?? "",
              delivery_location_name:
                school?.default_delivery_location.location_name ?? "",
              unit_id: ingredient?.purchase_unit.unit_id ?? "",
              unit_code: ingredient?.purchase_unit.unit_code ?? "",
              unit_name: ingredient?.purchase_unit.unit_name ?? "",
              pantry_need_purpose_id: text("pantry_need_purpose_id"),
              purpose_code:
                pantry.purposes.find(
                  (p) =>
                    p.pantry_need_purpose_id === text("pantry_need_purpose_id"),
                )?.purpose_code ?? "legacy_unknown",
              purpose_name_vi:
                pantry.purposes.find(
                  (p) =>
                    p.pantry_need_purpose_id === text("pantry_need_purpose_id"),
                )?.purpose_name_vi ?? "Phân loại đã lưu",
              requested_quantity: text("requested_quantity"),
              note: text("note"),
              source_request_reference: text("source_request_reference"),
              source_row_reference: text("source_row_reference"),
              line_status: "ACTIVE",
              updated_at: at,
            };
          }),
          invalid_lines: [],
          issues: { blockers: [], warnings: [] },
          approval_history: previous?.approval_history ?? [],
          change_history: previous?.change_history ?? [],
        };
        return success({
          authoritative_readback: { pantry: structuredClone(pantry) },
        });
      },
    },
  };
}
