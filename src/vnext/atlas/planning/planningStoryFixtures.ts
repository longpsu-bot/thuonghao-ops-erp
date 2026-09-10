import type {
  PantryBatch,
  PantryDraftRow,
  PantryPreview,
  PlanningCorrectionImpact,
} from "../bridges/planning";
import {
  createPlanningReviewFixture,
  menuPreview,
  pantryPreview,
  reviewWeek,
  safeImpact,
  stale,
  success,
  unknown,
} from "./planningReviewFixtures";
export type PlanningReviewScenario =
  | "menu"
  | "menu_dirty"
  | "menu_review"
  | "menu_blocked"
  | "menu_stale"
  | "menu_unknown"
  | "attendance"
  | "attendance_dirty"
  | "attendance_invalid"
  | "attendance_paste"
  | "attendance_review"
  | "attendance_correction"
  | "attendance_unknown"
  | "pantry"
  | "pantry_zero"
  | "pantry_additive"
  | "pantry_complete"
  | "pantry_blocked"
  | "pantry_review"
  | "pantry_correction"
  | "pantry_unknown"
  | "dirty_dialog";
const directRows: PantryDraftRow[] = [
  {
    school_id: "school-0",
    service_date: reviewWeek,
    ingredient_id: "ingredient-1",
    pantry_need_purpose_id: "purpose-1",
    requested_quantity: "25.75",
    note: "Bữa phụ theo yêu cầu của trường",
    source_request_reference: "Yêu cầu bếp ngày 07/09",
    source_row_reference: "fixture:1",
  },
  {
    school_id: "school-1",
    service_date: reviewWeek,
    ingredient_id: "ingredient-1",
    pantry_need_purpose_id: "purpose-1",
    requested_quantity: "18.5",
    note: "Điều chỉnh số suất ăn",
    source_request_reference: "Phiếu bổ sung",
    source_row_reference: "fixture:2",
  },
];
const correction: PlanningCorrectionImpact = {
  ...safeImpact,
  save_allowed: false,
  save_blocker_code: "PLANNING_RELEASE_CORRECTION_REQUIRED",
  date_impacts: [
    {
      service_date: reviewWeek,
      need_state: "CURRENT",
      confirmed_need_state: "RELEASED_FOR_PURCHASE_HANDOFF",
      planning_release_occurred: true,
      purchase_handoff_exists: false,
      later_downstream_commitment_exists: false,
      legacy_overlap_exists: false,
      correction_policy: "PLANNING_RELEASE_CORRECTION_REQUIRED",
      safe_to_save: false,
      next_required_action: "PREPARE_CORRECTION",
      operator_message:
        "Cam kết kế hoạch đã phát hành. Cần mở lại trước khi lưu nguồn.",
      chains: [
        {
          need_generation_run_id: "fixture-chain",
          need_generation_run_version: 2,
          run_status: "COMPLETED",
          period_start: reviewWeek,
          period_end: reviewWeek,
          is_legacy_range: false,
          confirmed_need_batch_id: "fixture-confirmed",
          confirmed_need_batch_version: 3,
          confirmed_need_status: "RELEASED_FOR_PURCHASE_HANDOFF",
          planning_release_occurred: true,
          active_purchase_handoff_exists: false,
          later_downstream_commitment_exists: false,
        },
      ],
    },
  ],
};
export function createPlanningStoryFixture(scenario: PlanningReviewScenario) {
  const fixture = createPlanningReviewFixture();
  const proposedMenu = fixture.planning.weekly_menu!.lines.map((r, i) => ({
    ...r,
    dish_id: i < 3 ? "dish-2" : "dish-1",
  }));
  fixture.api.syncMenuFromGoogle = async () =>
    success({
      source: { source_name: "Thực đơn chính thức", sheet_name: "Tuần 37" },
      fetched_at: "2026-09-07T01:00:00Z",
      rows: [
        ["Tên trường", "Ngày", "Món canh"],
        ...fixture.planning.schools.map((s, i) => [
          s.school_code,
          reviewWeek,
          i < 3 ? "CANH2" : "CANH1",
        ]),
      ],
    });
  fixture.api.previewMenu = async () =>
    success({ preview: { ...menuPreview(), canonical_rows: proposedMenu } });
  if (scenario.startsWith("pantry") && scenario !== "pantry") {
    const mode = scenario === "pantry_complete" ? "COMPLETE" : "ADDITIVE";
    const batch: PantryBatch = {
      pantry_need_batch_id: "fixture-pantry",
      week_start: reviewWeek,
      week_end: "2026-09-13",
      pantry_need_batch_status: "APPROVED",
      version: 2,
      source_type: "MANUAL_ATLAS",
      source_name: "Nhập thủ công Atlas",
      source_signature: "pantry-authority",
      no_additions_confirmed: scenario === "pantry_zero",
      school_date_modes: directRows.map((r) => ({
        school_id: r.school_id,
        service_date: r.service_date,
        direct_need_mode: mode,
      })),
      requesting_actor_id: "fixture-actor",
      requesting_actor_name: "Nhân viên kế hoạch",
      creation_method: "MANUAL_ATLAS",
      latest_approved_by_actor_id: null,
      latest_approved_at: null,
      latest_approval_snapshot_id: null,
      created_at: "",
      updated_at: "",
      active_lines:
        scenario === "pantry_zero"
          ? []
          : directRows.map((r, i) => ({
              ...r,
              pantry_need_line_id: `fixture-line-${i}`,
              school_code: `TH00${i + 1}`,
              school_name: fixture.planning.schools[i].school_name,
              delivery_location_id: `fixture-location-${i}`,
              delivery_location_name:
                fixture.pantry.schools[i].default_delivery_location
                  .location_name,
              ingredient_code: "GAO",
              ingredient_name: "Gạo thơm",
              unit_id: "unit-1",
              unit_code: "KG",
              unit_name: "kg",
              purpose_code: "EXTRA",
              purpose_name_vi: "Bổ sung theo yêu cầu",
              line_status: "ACTIVE",
              updated_at: "",
            })),
      invalid_lines: [],
      issues: { blockers: [], warnings: [] },
      approval_history: [],
      change_history: [],
    };
    fixture.pantry.batch = batch;
    const preview: PantryPreview = {
      ...pantryPreview(),
      no_additions_confirmed: false,
      canonical_rows: directRows,
      school_date_modes: batch.school_date_modes,
      comparison: {
        ...pantryPreview().comparison,
        status: "REPLACEMENT",
        changed_lines: [
          {
            before: directRows[0],
            after: { ...directRows[0], requested_quantity: "30" },
          },
        ],
      },
    };
    fixture.pantryApi.preview = async () => success({ preview });
  }
  if (scenario === "pantry_blocked")
    fixture.pantry.catalog_issues.blockers = [
      {
        code: "CATALOG_UNAVAILABLE",
        message:
          "Danh mục nguyên liệu chưa sẵn sàng. Liên hệ quản trị dữ liệu.",
        field: null,
        source_row_reference: null,
      },
    ];
  if (scenario.endsWith("correction") || scenario === "menu_blocked") {
    const impact =
      scenario === "menu_blocked"
        ? {
            ...safeImpact,
            save_allowed: false,
            save_blocker_code: "BLOCKED_BY_DOWNSTREAM_COMMITMENT",
            date_impacts: [
              {
                ...correction.date_impacts[0],
                correction_policy: "BLOCKED_BY_DOWNSTREAM_COMMITMENT",
                operator_message:
                  "Đã có cam kết mua hàng. Cần xử lý nghiệp vụ liên quan trước khi lưu nguồn.",
                chains: [],
              },
            ],
          }
        : correction;
    fixture.api.getCorrectionImpact = async () => success({ impact });
    fixture.pantryApi.getCorrectionImpact = async () => success({ impact });
  }
  if (scenario.endsWith("unknown") || scenario.endsWith("stale")) {
    const response = scenario.endsWith("stale") ? stale : unknown;
    fixture.api.saveCompletedMenu = async () => response;
    fixture.api.saveCompletedAttendance = async () => response;
    fixture.pantryApi.saveCompleted = async () => response;
  }
  return fixture;
}
