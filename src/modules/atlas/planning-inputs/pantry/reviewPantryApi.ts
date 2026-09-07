import type {
  AtlasRpcResult,
  AtlasSafeBackendError,
  AtlasSuccessEnvelope,
  JsonValue,
} from "../../connection/atlasRpc";
import type { AtlasReviewScenario } from "../../review/reviewMode";
import type {
  PantryApi,
  PantryCommandRequest,
  PantryCompletionCommandRequest,
} from "./pantryApi";
import type {
  PantryBatch,
  PantryPreview,
  PantryWorkbenchData,
} from "./pantryModel";

const now = "2026-07-29T04:00:00.000Z";
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
    safe_message: "Yêu cầu xem thử Pantry đã bị từ chối an toàn.",
  } as AtlasSafeBackendError,
});

function fixture(weekStart: string): PantryWorkbenchData {
  const end = new Date(`${weekStart}T00:00:00Z`);
  end.setUTCDate(end.getUTCDate() + 6);
  const batch: PantryBatch = {
    pantry_need_batch_id: "review-pantry-batch",
    week_start: weekStart,
    week_end: end.toISOString().slice(0, 10),
    pantry_need_batch_status: "DRAFT",
    version: 1,
    source_type: "MANUAL_ATLAS",
    source_name: "Nhập thủ công Atlas",
    source_signature: "a".repeat(64),
    no_additions_confirmed: false,
    school_date_modes: [
      {
        school_id: "review-planning-school-1",
        service_date: weekStart,
        direct_need_mode: "ADDITIVE",
      },
    ],
    requesting_actor_id: "review-only-atlas-operator",
    requesting_actor_name: "Điều phối viên xem thử",
    creation_method: "MANUAL_ATLAS",
    latest_approved_by_actor_id: null,
    latest_approved_at: null,
    latest_approval_snapshot_id: null,
    created_at: now,
    updated_at: now,
    active_lines: [
      {
        pantry_need_line_id: "review-pantry-line-1",
        service_date: weekStart,
        school_id: "review-planning-school-1",
        school_code: "TH001",
        school_name: "Trường Tiểu học Nguyễn Du",
        delivery_location_id: "review-planning-location-1",
        delivery_location_code: "KITCHEN-TH001",
        delivery_location_name: "Bếp chính Nguyễn Du",
        ingredient_id: "review-pantry-ingredient",
        ingredient_code: "RICE-001",
        ingredient_name: "Gạo tẻ",
        unit_id: "review-pantry-unit",
        unit_code: "kg",
        unit_name: "Kilôgam",
        pantry_need_purpose_id: "review-pantry-purpose-school",
        purpose_code: "school_requested_supplement",
        purpose_name_vi: "Bổ sung theo yêu cầu của trường",
        purpose_description:
          "An identified School has explicitly requested an additional Ingredient quantity for the stated service date beyond the demand already represented by controlled Planning sources.",
        purpose_note_rule: "REQUIRED",
        requested_quantity: "12.500000",
        note: "Nhà trường đề nghị bổ sung cho hoạt động bán trú.",
        source_request_reference: "REQ-TH001-2026-08",
        source_row_reference: "review:row:1",
        line_status: "ACTIVE",
        updated_at: now,
      },
    ],
    invalid_lines: [],
    issues: { blockers: [], warnings: [] },
    approval_history: [],
    change_history: [
      {
        audit_event_id: "review-pantry-audit",
        event_type: "PantryDraftCreated",
        version_before: null,
        version_after: 1,
        actor_id: "review-only-atlas-operator",
        actor_display_name: "Điều phối viên xem thử",
        reason_code: "REVIEW_FIXTURE",
        reason_note: "Dữ liệu xem thử không được lưu.",
        occurred_at: now,
      },
    ],
  };
  return {
    week_start: weekStart,
    week_end: batch.week_end,
    source_method: {
      source_type: "MANUAL_ATLAS",
      source_name: "Nhập thủ công Atlas",
    },
    purposes: [
      {
        pantry_need_purpose_id: "review-pantry-purpose-school",
        purpose_code: "school_requested_supplement",
        purpose_name_vi: "Bổ sung theo yêu cầu của trường",
        purpose_description:
          "An identified School has explicitly requested an additional Ingredient quantity for the stated service date beyond the demand already represented by controlled Planning sources.",
        note_rule: "REQUIRED",
        purpose_status: "ACTIVE",
        display_order: 10,
        version: 1,
      },
      {
        pantry_need_purpose_id: "review-pantry-purpose-planning",
        purpose_code: "planning_identified_supplement",
        purpose_name_vi: "Bổ sung do bộ phận Kế hoạch xác định",
        purpose_description:
          "Planning or catering operations has identified a specific additional Ingredient quantity required to deliver service for the stated School and service date, and that quantity is not represented by another controlled Planning source.",
        note_rule: "REQUIRED",
        purpose_status: "ACTIVE",
        display_order: 20,
        version: 1,
      },
    ],
    schools: [
      {
        school_id: "review-planning-school-1",
        school_code: "TH001",
        school_name: "Trường Tiểu học Nguyễn Du",
        school_status: "ACTIVE",
        display_order: 1,
        customer_id: "review-planning-customer-1",
        customer_name: "Trường Tiểu học Nguyễn Du",
        default_delivery_location: {
          delivery_location_id: "review-planning-location-1",
          location_code: "KITCHEN-TH001",
          location_name: "Bếp chính Nguyễn Du",
          address_text: "Hà Nội",
          timezone_name: "Asia/Bangkok",
        },
      },
      {
        school_id: "review-planning-school-2",
        school_code: "TH002",
        school_name: "Trường Tiểu học Trần Quốc Toản",
        school_status: "ACTIVE",
        display_order: 2,
        customer_id: "review-planning-customer-2",
        customer_name: "Trường Tiểu học Trần Quốc Toản",
        default_delivery_location: {
          delivery_location_id: "review-planning-location-2",
          location_code: "KITCHEN-TH002",
          location_name: "Bếp chính Trần Quốc Toản",
          address_text: "Hà Nội",
          timezone_name: "Asia/Bangkok",
        },
      },
      {
        school_id: "review-planning-school-3",
        school_code: "TH003",
        school_name: "Trường Mầm non Hoa Hồng",
        school_status: "ACTIVE",
        display_order: 3,
        customer_id: "review-planning-customer-3",
        customer_name: "Trường Mầm non Hoa Hồng",
        default_delivery_location: {
          delivery_location_id: "review-planning-location-3",
          location_code: "KITCHEN-TH003",
          location_name: "Bếp chính Hoa Hồng",
          address_text: "Hà Nội",
          timezone_name: "Asia/Bangkok",
        },
      },
    ],
    ingredients: [
      {
        ingredient_id: "review-pantry-ingredient",
        ingredient_code: "RICE-001",
        ingredient_name: "Gạo tẻ",
        ingredient_status: "ACTIVE",
        purchase_unit: {
          unit_id: "review-pantry-unit",
          unit_code: "kg",
          unit_name: "Kilôgam",
        },
      },
    ],
    catalog_issues: { blockers: [], warnings: [] },
    school_date_modes: clone(batch.school_date_modes),
    batch,
    allowed_actions: {
      can_preview: true,
      can_save: true,
      can_validate: true,
      can_approve: false,
      can_reopen: false,
    },
  };
}

function commandWeek(
  request: PantryCommandRequest | PantryCompletionCommandRequest,
) {
  const value = request.payload.week_start;
  return typeof value === "string" ? value : "2026-08-03";
}

export function createReviewPantryApi(
  scenario: AtlasReviewScenario,
): PantryApi {
  let state = fixture("2026-08-03");

  const fail = () =>
    scenario === "permission_denied"
      ? backendError("CAPABILITY_DENIED")
      : scenario === "stale"
        ? backendError("STALE_VERSION")
        : scenario === "server_error"
          ? ({
              kind: "transport_error",
              diagnostic: {
                code: "NETWORK_FAILURE",
                safeMessage:
                  "Không thể tải dữ liệu Pantry lúc này. Vui lòng thử lại.",
              },
            } satisfies AtlasRpcResult)
          : null;

  const command = async (
    request: PantryCommandRequest | PantryCompletionCommandRequest,
    status: PantryBatch["pantry_need_batch_status"],
    message: string,
    eventTypeOverride?: string,
  ) => {
    const error = fail();
    if (error) return error;
    const weekStart = commandWeek(request);
    if (state.week_start !== weekStart) state = fixture(weekStart);
    if (state.batch) {
      const versionBefore = state.batch.version;
      state.batch.pantry_need_batch_status = status;
      state.batch.version += 1;
      state.batch.updated_at = now;
      const eventType =
        eventTypeOverride ??
        {
          DRAFT: "PantryDraftReplaced",
          VALIDATED: "PantryValidated",
          APPROVED: "PantryApproved",
          REOPENED: "PantryReopened",
        }[status];
      state.batch.change_history.unshift({
        audit_event_id: `review-pantry-audit-${state.batch.version}`,
        event_type: eventType,
        version_before: versionBefore,
        version_after: state.batch.version,
        actor_id: "review-only-atlas-operator",
        actor_display_name: "Điều phối viên xem thử",
        reason_code: request.reason_code,
        reason_note: request.reason_note,
        occurred_at: now,
      });
      if (status === "APPROVED") {
        const snapshotId = `review-pantry-snapshot-${state.batch.version}`;
        state.batch.latest_approval_snapshot_id = snapshotId;
        state.batch.latest_approved_by_actor_id = "review-only-atlas-operator";
        state.batch.latest_approved_at = now;
        state.batch.approval_history.unshift({
          pantry_need_approval_snapshot_id: snapshotId,
          approved_batch_version: state.batch.version,
          approved_by_actor_id: "review-only-atlas-operator",
          approved_by_display_name: "Điều phối viên xem thử",
          approved_at: now,
          source_signature: state.batch.source_signature,
          no_additions_confirmed: state.batch.no_additions_confirmed,
          line_count: state.batch.active_lines.length,
          blocker_summary: [],
          warning_summary: [],
          lines: clone(state.batch.active_lines) as unknown as JsonValue[],
        });
      }
      const requestedModes = request.payload.school_date_modes;
      if (Array.isArray(requestedModes)) {
        state.batch.school_date_modes = clone(
          requestedModes as unknown as PantryBatch["school_date_modes"],
        );
        state.school_date_modes = clone(state.batch.school_date_modes);
      }
      state.allowed_actions = {
        can_preview: true,
        can_save: status === "DRAFT" || status === "REOPENED",
        can_validate: status === "DRAFT" || status === "REOPENED",
        can_approve: status === "VALIDATED",
        can_reopen: status === "APPROVED",
      };
    }
    return success({
      safe_operator_message: message,
      workbench: clone(state) as unknown as JsonValue,
    });
  };

  return {
    async getCorrectionImpact(
      _authSubject,
      _correlationId,
      _sourceKind,
      _sourcePayload,
    ) {
      return success({
        impact: {
          affected_service_dates: [],
          date_impacts: [],
          save_allowed: true,
          save_blocker_code: null,
        },
      });
    },
    async prepareCorrection() {
      return backendError("CORRECTION_ACTION_NOT_REQUIRED");
    },
    async getWorkbench(_authSubject, _correlationId, weekStart) {
      const error = fail();
      if (error) return error;
      if (state.week_start !== weekStart) state = fixture(weekStart);
      return success({ workbench: clone(state) as unknown as JsonValue });
    },
    async preview(
      _authSubject,
      _correlationId,
      weekStart,
      noAdditionsConfirmed,
      rows,
      schoolDateModes,
    ) {
      const error = fail();
      if (error) return error;
      const preview: PantryPreview = {
        week_start: weekStart,
        week_end: state.week_end,
        source_type: "MANUAL_ATLAS",
        source_name: "Nhập thủ công Atlas",
        source_signature: noAdditionsConfirmed
          ? "0".repeat(64)
          : "b".repeat(64),
        no_additions_confirmed: noAdditionsConfirmed,
        canonical_rows: clone(rows),
        school_date_modes: clone(schoolDateModes ?? []),
        issues: { blockers: [], warnings: [] },
        comparison: {
          status: state.batch ? "REPLACEMENT" : "NEW",
          current_batch_id: state.batch?.pantry_need_batch_id ?? null,
          current_version: state.batch?.version ?? null,
          current_status: state.batch?.pantry_need_batch_status ?? null,
          current_source_signature: state.batch?.source_signature ?? null,
          new_lines: state.batch ? [] : clone(rows),
          changed_lines: state.batch
            ? clone(rows).map((row) => ({
                before: null,
                after: row,
              }))
            : [],
          unchanged_lines: [],
          omitted_lines: [],
          changed_school_dates: [],
        },
        can_save: true,
      };
      return success({ preview: preview as unknown as JsonValue });
    },
    async save(request) {
      const editableStatus =
        state.batch?.pantry_need_batch_status === "REOPENED"
          ? "REOPENED"
          : "DRAFT";
      return command(
        request,
        editableStatus,
        "Bản nháp Pantry xem thử đã cập nhật.",
        "PantryDraftReplaced",
      );
    },
    async saveCompleted(request) {
      const result = await command(
        request,
        "APPROVED",
        "Đã lưu. Phiên bản này đang được sử dụng cho Kế hoạch.",
        "PantryCompleted",
      );
      if (result.kind !== "success") return result;
      return success({
        safe_operator_message:
          "Đã lưu. Phiên bản này đang được sử dụng cho Kế hoạch.",
        downstream_currentness: "NOT_GENERATED",
        authoritative_readback: {
          pantry: clone(state) as unknown as JsonValue,
          preflight: { downstream_currentness: "NOT_GENERATED" },
        },
      });
    },
    async validate(request) {
      return command(request, "VALIDATED", "Pantry xem thử đã xác thực.");
    },
    async approve(request) {
      return command(request, "APPROVED", "Pantry xem thử đã phê duyệt.");
    },
    async reopen(request) {
      return command(request, "REOPENED", "Pantry xem thử đã mở lại.");
    },
  };
}
