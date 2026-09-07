import type {
  AtlasRpcResult,
  AtlasSuccessEnvelope,
  JsonValue,
} from "../connection/atlasRpc";
import type {
  ReleaseSchoolDispatchDocumentRequest,
  SchoolDispatchReleaseApi,
} from "./schoolDispatchReleaseApi";
import type {
  SchoolDispatchDocument,
  SchoolDispatchWorkbenchData,
  SchoolDispatchWorkbenchRow,
} from "./schoolDispatchReleaseModel";

export type SchoolDispatchReviewScenario =
  | "ready"
  | "current"
  | "replacement_required"
  | "cancellation_required"
  | "empty"
  | "permission_denied";

const schoolId = "26000000-0000-4000-8000-000000000001";
const locationId = "26000000-0000-4000-8000-000000000002";
const releaseId = "26000000-0000-4000-8000-000000000003";
const fingerprint = "a".repeat(64);
const changedFingerprint = "b".repeat(64);

function success(value: Record<string, unknown>): AtlasRpcResult {
  return {
    kind: "success",
    response: { success: true, ...value } as AtlasSuccessEnvelope,
  };
}

export function createReviewSchoolDispatchDocument(
  status: "RELEASED" | "SUPERSEDED" = "RELEASED",
): SchoolDispatchDocument {
  return {
    school_dispatch_release_id: releaseId,
    service_date: "2026-09-24",
    school_id: schoolId,
    delivery_location_id: locationId,
    status,
    document_number: "PXK-20260924-2600000000004000",
    source_fingerprint: fingerprint,
    predecessor_release_id: null,
    school_name: "Trường Tiểu học Nguyễn Du",
    delivery_location_name: "Bếp chính Nguyễn Du",
    delivery_address: "Số 1 Nguyễn Du",
    note: null,
    version: 1,
    released_by_actor_id: "26000000-0000-4000-8000-000000000004",
    released_at: "2026-09-23T08:00:00.000Z",
    export_ready: true,
    lines: [
      {
        school_dispatch_release_line_id: "26000000-0000-4000-8000-000000000005",
        ingredient_id: "26000000-0000-4000-8000-000000000006",
        ingredient_name: "Gạo thơm",
        unit_id: "26000000-0000-4000-8000-000000000007",
        unit_code: "kg",
        quantity: "100.000000",
        sources: [
          {
            confirmed_need_line_revision_id:
              "26000000-0000-4000-8000-000000000011",
            confirmed_need_line_decision_id:
              "26000000-0000-4000-8000-000000000012",
            allocation_family_revision_id:
              "26000000-0000-4000-8000-000000000013",
            allocation_family_contribution_id:
              "26000000-0000-4000-8000-000000000014",
            allocation_supplier_split_id:
              "26000000-0000-4000-8000-000000000015",
            purchase_order_id: "26000000-0000-4000-8000-000000000016",
            purchase_order_revision_id: "26000000-0000-4000-8000-000000000017",
            purchase_order_line_revision_id:
              "26000000-0000-4000-8000-000000000018",
            covered_quantity: "100.000000",
          },
        ],
      },
    ],
  };
}

function baseRow(): SchoolDispatchWorkbenchRow {
  return {
    service_date: "2026-09-24",
    school_id: schoolId,
    delivery_location_id: locationId,
    state: "READY",
    expected_version: 0,
    preview: {
      service_date: "2026-09-24",
      school_id: schoolId,
      delivery_location_id: locationId,
      school_name: "Trường Tiểu học Nguyễn Du",
      delivery_location_name: "Bếp chính Nguyễn Du",
      delivery_address: "Số 1 Nguyễn Du",
      source_fingerprint: fingerprint,
      ready: true,
      lines: createReviewSchoolDispatchDocument().lines,
      blockers: [],
      warnings: [],
    },
    current_release: null,
    history: [],
    allowed_actions: { release: true, replace: false, export: false },
    blockers: [],
    warnings: [],
  };
}

export function createReviewSchoolDispatchWorkbench(
  scenario: SchoolDispatchReviewScenario = "ready",
): SchoolDispatchWorkbenchData {
  const row = baseRow();
  if (scenario === "current") {
    row.state = "CURRENT";
    row.expected_version = 1;
    row.current_release = createReviewSchoolDispatchDocument();
    row.history = [row.current_release];
    row.allowed_actions = { release: false, replace: false, export: true };
  } else if (scenario === "replacement_required") {
    row.state = "REPLACEMENT_REQUIRED";
    row.expected_version = 1;
    row.preview.source_fingerprint = changedFingerprint;
    row.current_release = createReviewSchoolDispatchDocument();
    row.history = [row.current_release];
    row.allowed_actions = { release: false, replace: true, export: true };
  } else if (scenario === "cancellation_required") {
    row.state = "BLOCKED";
    row.preview.ready = false;
    row.preview.blockers = ["CANCELLATION_REQUIRED"];
    row.blockers = ["CANCELLATION_REQUIRED"];
    row.allowed_actions = { release: false, replace: false, export: false };
  }
  return {
    success: true,
    contract_version: "SCHOOL-DISPATCH-RELEASE.v1",
    date_start: "2026-09-24",
    date_end: "2026-09-24",
    rows: scenario === "empty" ? [] : [row],
    warnings: [],
    blockers: [],
  };
}

export function createReviewSchoolDispatchReleaseApi(
  scenario: SchoolDispatchReviewScenario = "ready",
): SchoolDispatchReleaseApi {
  let data = createReviewSchoolDispatchWorkbench(scenario);
  return {
    async getWorkbench() {
      if (scenario === "permission_denied") {
        return {
          kind: "backend_error",
          error: {
            success: false,
            error_code: "CAPABILITY_DENIED",
            safe_message: "Bạn không có quyền xem Phiếu xuất kho.",
          },
        };
      }
      return success(data as unknown as Record<string, JsonValue>);
    },
    async releaseDocument(request: ReleaseSchoolDispatchDocumentRequest) {
      const previous = data.rows[0]?.current_release;
      const released = createReviewSchoolDispatchDocument();
      released.source_fingerprint = request.payload.expected_source_fingerprint;
      released.predecessor_release_id = request.payload.predecessor_release_id;
      released.note = request.reason_note;
      const priorHistory = previous
        ? [{ ...previous, status: "SUPERSEDED" as const }]
        : [];
      data = createReviewSchoolDispatchWorkbench("current");
      data.rows[0] = {
        ...data.rows[0]!,
        preview: {
          ...data.rows[0]!.preview,
          source_fingerprint: request.payload.expected_source_fingerprint,
        },
        current_release: released,
        history: [released, ...priorHistory],
      };
      return success({
        command_id: request.command_id,
        correlation_id: request.correlation_id,
        idempotency_status: "COMPLETED",
        school_dispatch_release_id: released.school_dispatch_release_id,
        document_number: released.document_number,
        authoritative_readback: released,
        safe_operator_message: "Đã phát hành Phiếu xuất kho cho trường.",
        warnings: [],
        blockers: [],
      });
    },
  };
}
