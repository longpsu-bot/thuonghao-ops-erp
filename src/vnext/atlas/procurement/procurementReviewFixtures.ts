import type {
  AllocationFamilyRow,
  AtlasRpcResult,
  AtlasSuccessEnvelope,
  ConfirmedAllocationWorkbench,
  ProcurementSchoolOption,
  PurchaseOrdersData,
  PurchaseReviewApi,
  SchoolCateringProcurementApi,
  SchoolCateringPurchaseOrder,
} from "../bridges/procurement";

export type ProcurementReviewScenario =
  | "normal"
  | "manual_split"
  | "rebalance"
  | "needs_reallocation"
  | "blocked"
  | "empty"
  | "read_failure"
  | "retryable_failure"
  | "unknown"
  | "ready"
  | "po_draft"
  | "po_stale"
  | "po_released"
  | "replacement_required"
  | "cancellation_required"
  | "superseded";
export const reviewDate = "2026-09-10";
export const reviewSchools: ProcurementSchoolOption[] = Array.from(
  { length: 33 },
  (_, index) => ({
    school_id: `school-${index}`,
    school_name:
      index === 0
        ? "Trường Tiểu học Nguyễn Du"
        : index === 1
          ? "Trường Tiểu học Lê Lợi"
          : `Trường học ${String(index + 1).padStart(2, "0")}`,
  }),
);
export function reviewSuccess(value: object = {}): AtlasRpcResult {
  return {
    kind: "success",
    response: { success: true, ...value } as AtlasSuccessEnvelope,
  };
}
export function reviewFailure(
  code = "STALE_VERSION",
  retryable = false,
): AtlasRpcResult {
  return {
    kind: "backend_error",
    error: {
      success: false,
      error_code: code,
      retryable,
      safe_message: retryable
        ? "Hệ thống đang bận. Có thể thử lại thao tác."
        : "Dữ liệu đã thay đổi; hãy tải lại trước khi tiếp tục.",
    },
  };
}
export const reviewUnknown: AtlasRpcResult = {
  kind: "transport_error",
  diagnostic: {
    code: "NETWORK_FAILURE",
    safeMessage: "Kết nối bị gián đoạn. Chưa xác nhận thao tác đã hoàn tất.",
  },
};

export function reviewFamily(
  scenario: ProcurementReviewScenario = "normal",
): AllocationFamilyRow {
  const saved = [
    "manual_split",
    "rebalance",
    "needs_reallocation",
    "ready",
  ].includes(scenario);
  return {
    family: {
      source_kind: "CONFIRMED_NEED",
      source_confirmed_need_batch_id: "private-batch",
      source_confirmed_need_batch_version: 3,
      service_date: reviewDate,
      delivery_location_id: "location-0",
      ingredient_id: "ingredient-0",
      unit_id: "unit-kg",
      family_id: saved ? "private-family" : null,
      version: saved ? 2 : 0,
      source_fingerprint: "private-fingerprint",
    },
    service_date: reviewDate,
    delivery_location_id: "location-0",
    location_name: "Bếp chính Nguyễn Du",
    school_id: "school-0",
    school_name: reviewSchools[0]!.school_name,
    schools: [reviewSchools[0]!],
    ingredient_id: "ingredient-0",
    ingredient_name: "Gạo thơm",
    unit_id: "unit-kg",
    unit_code: "kg",
    family_quantity:
      scenario === "blocked"
        ? null
        : scenario === "rebalance"
          ? "120.000000"
          : "100.000000",
    complete: scenario !== "blocked",
    contributions: [],
    contribution_count: 2,
    splits: saved
      ? [
          {
            supplier_split_id: "private-split-a",
            supplier_id: "supplier-a",
            supplier_name: "NCC An Phú",
            allocated_quantity: "60.000000",
            split_ratio: "0.600000000000",
          },
          {
            supplier_split_id: "private-split-b",
            supplier_id: "supplier-b",
            supplier_name: "NCC Bình Minh",
            allocated_quantity: "40.000000",
            split_ratio: "0.400000000000",
          },
        ]
      : [],
    eligible_suppliers: [
      { supplier_id: "supplier-a", supplier_name: "NCC An Phú", priority: 1 },
      ...(scenario === "needs_reallocation"
        ? []
        : [
            {
              supplier_id: "supplier-b",
              supplier_name: "NCC Bình Minh",
              priority: 2,
            },
          ]),
      {
        supplier_id: "supplier-c",
        supplier_name: "NCC Thành Công",
        priority: 3,
      },
    ],
    state:
      scenario === "rebalance"
        ? "STALE_REBALANCE_AVAILABLE"
        : scenario === "needs_reallocation"
          ? "NEEDS_REALLOCATION"
          : scenario === "blocked"
            ? "BLOCKED"
            : saved
              ? "BALANCED"
              : "UNALLOCATED",
    recommendation:
      saved || scenario === "blocked"
        ? null
        : {
            supplier_id: "supplier-a",
            allocated_quantity: "100.000000",
            split_ratio: "1.000000000000",
          },
    rebalance_proposal:
      scenario === "rebalance"
        ? [
            {
              supplier_id: "supplier-a",
              allocated_quantity: "72.000000",
              split_ratio: "0.6",
            },
            {
              supplier_id: "supplier-b",
              allocated_quantity: "48.000000",
              split_ratio: "0.4",
            },
          ]
        : null,
    allowed_actions: {
      save_allocation: scenario !== "blocked",
      confirm_recommendation: false,
    },
    disabled_reasons: [],
    blockers:
      scenario === "blocked"
        ? ["Hoàn tất xác nhận nhu cầu trước khi phân bổ NCC."]
        : [],
    warnings: [],
  };
}
export function reviewOrder(
  scenario: ProcurementReviewScenario = "po_draft",
): SchoolCateringPurchaseOrder {
  const released = [
    "po_released",
    "replacement_required",
    "cancellation_required",
    "superseded",
  ].includes(scenario);
  return {
    purchase_order_id: "private-order",
    supplier: {
      supplier_id: "supplier-a",
      supplier_name: "NCC An Phú",
      supplier_status: "ACTIVE",
    },
    service_date: reviewDate,
    status:
      scenario === "superseded"
        ? "SUPERSEDED"
        : released
          ? "RELEASED_TO_SUPPLIER"
          : "DRAFT",
    version: 4,
    document_number: released ? "PO-20260910-ANPHU" : null,
    replaces_purchase_order_id: null,
    replaced_by_purchase_order_id:
      scenario === "superseded" ? "private-successor" : null,
    commitment_state:
      scenario === "po_stale"
        ? "DRAFT_STALE"
        : scenario === "replacement_required"
          ? "REPLACEMENT_REQUIRED"
          : scenario === "cancellation_required"
            ? "CANCELLATION_REQUIRED"
            : scenario === "superseded"
              ? "SUPERSEDED"
              : released
                ? "CURRENT"
                : "DRAFT_CURRENT",
    current_revision: {
      purchase_order_revision_id: "private-order-revision",
      revision_number: 2,
      revision_kind: "BASE",
      revision_status: released ? "RELEASED" : "DRAFT",
      predecessor_revision_id: null,
      supplier_name_snapshot: released ? "NCC An Phú" : null,
      delivery_location_snapshot: null,
      released_by_actor_id: null,
      released_at: null,
      reason_note: null,
    },
    lines: [
      {
        purchase_order_line_revision_id: "private-line-revision",
        purchase_order_line_id: "private-line",
        ingredient: {
          ingredient_id: "ingredient-0",
          ingredient_name: "Gạo thơm",
        },
        ordered_quantity: "60.000001",
        unit: { unit_id: "unit-kg", unit_code: "kg" },
        delivery_location: {
          delivery_location_id: "location-0",
          location_name: "Bếp chính Nguyễn Du",
        },
        service_date: reviewDate,
        source: {
          family_id: "private-family",
          family_revision_id: "private-family-revision",
          supplier_split_id: "private-split",
        },
      },
    ],
    stale: scenario === "po_stale",
    release_eligible: !released && scenario !== "po_stale",
    export_ready: released,
    blockers:
      scenario === "cancellation_required" ? ["CANCELLATION_REQUIRED"] : [],
    warnings: [],
    allowed_actions: {
      release: !released && scenario !== "po_stale",
      export: released,
      create_replacement: scenario === "replacement_required",
    },
    disabled_reasons: [],
  };
}

/** Explicit review snapshots only. No hosted adapter and no backend derivation. */
export function createProcurementReviewFixture(
  scenario: ProcurementReviewScenario = "normal",
) {
  const fixture = {
    allocation: {
      success: true,
      contract_version: "CONFIRMED-SUPPLIER-ALLOCATION.v1",
      date_start: reviewDate,
      date_end: reviewDate,
      rows: scenario === "empty" ? [] : [reviewFamily(scenario)],
      warnings: [],
      blockers: [],
      preparation: {
        service_date: reviewDate,
        confirmed_need_batch_id: "private-batch",
        expected_version: 3,
        ready: scenario === "ready",
        allowed: scenario === "ready",
        blockers: scenario === "ready" ? [] : ["ALLOCATION_IMBALANCED"],
      },
    } as ConfirmedAllocationWorkbench,
    orders: {
      success: true,
      contract_version: "SCHOOL-CATERING-PROCUREMENT.v1",
      date_start: reviewDate,
      date_end: reviewDate,
      purchase_orders: scenario === "empty" ? [] : [reviewOrder(scenario)],
      procurement_current: true,
      blockers: [],
      warnings: [],
    } as PurchaseOrdersData,
    commandResult:
      scenario === "unknown"
        ? reviewUnknown
        : scenario === "retryable_failure"
          ? reviewFailure("RETRYABLE_CONCURRENCY_FAILURE", true)
          : reviewSuccess({ safe_operator_message: "Đã lưu theo yêu cầu." }),
  };
  const command = async () => fixture.commandResult;
  const purchaseReviewApi: PurchaseReviewApi = {
    getGeneratedReview: async () => reviewFailure("NOT_AVAILABLE"),
    getConfirmedAllocations: async () =>
      scenario === "read_failure"
        ? reviewFailure("ACCESS_DENIED")
        : reviewSuccess(fixture.allocation),
    saveConfirmedAllocation: command,
    preparePurchaseOrders: command,
  };
  const procurementApi: SchoolCateringProcurementApi = {
    getWorkbench: async () => reviewFailure("NOT_AVAILABLE"),
    saveAllocation: command,
    confirmRecommendations: async () => reviewFailure("NOT_AVAILABLE"),
    getPurchaseOrders: async () =>
      scenario === "read_failure"
        ? reviewFailure("ACCESS_DENIED")
        : reviewSuccess(fixture.orders),
    createPurchaseOrderDrafts: command,
    createPurchaseOrderReplacement: command,
    releasePurchaseOrder: command,
  };
  return Object.assign(fixture, { purchaseReviewApi, procurementApi });
}
