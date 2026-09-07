import type {
  AtlasRpcResult,
  AtlasSuccessEnvelope,
  JsonValue,
} from "../connection/atlasRpc";
import type {
  ConfirmSupplierRecommendationsRequest,
  CreatePurchaseOrderDraftsRequest,
  CreatePurchaseOrderReplacementRequest,
  ReleasePurchaseOrderRequest,
  SaveSupplierAllocationRequest,
  SchoolCateringProcurementApi,
} from "./schoolCateringProcurementApi";
import type {
  AllocationFamilyRow,
  ProcurementWorkbenchData,
  PurchaseOrderDraftSkippedDate,
  PurchaseOrdersData,
  SchoolCateringPurchaseOrder,
} from "./schoolCateringProcurementModel";

export type SchoolCateringProcurementReviewScenario =
  | "default"
  | "manual_split"
  | "unallocated"
  | "rebalance"
  | "needs_reallocation"
  | "po_draft"
  | "stale_po"
  | "released_po"
  | "replacement_required"
  | "cancellation_required"
  | "permission_denied"
  | "retryable_failure"
  | "stale_version"
  | "replay_success"
  | "empty";

const familyId = "25000000-0000-4000-8000-000000000001";
const familyRevisionId = "25000000-0000-4000-8000-000000000002";
const locationId = "25000000-0000-4000-8000-000000000011";
const ingredientId = "25000000-0000-4000-8000-000000000021";
const unitId = "25000000-0000-4000-8000-000000000031";
const supplierAId = "25000000-0000-4000-8000-000000000041";
const supplierBId = "25000000-0000-4000-8000-000000000042";
const purchaseOrderId = "25000000-0000-4000-8000-000000000051";
const purchaseOrderRevisionId = "25000000-0000-4000-8000-000000000052";

function success(response: Record<string, unknown>): AtlasRpcResult {
  return {
    kind: "success",
    response: { success: true, ...response } as AtlasSuccessEnvelope,
  };
}

function backendError(errorCode: string, safeMessage: string): AtlasRpcResult {
  return {
    kind: "backend_error",
    error: {
      success: false,
      error_code: errorCode,
      safe_message: safeMessage,
      retryable: errorCode === "RETRYABLE_CONCURRENCY_FAILURE",
    },
  };
}

function retryableFailure(): AtlasRpcResult {
  return {
    kind: "transport_error",
    diagnostic: {
      code: "NETWORK_FAILURE",
      safeMessage:
        "Không thể kết nối Atlas. Không có lệnh nào được tự gửi lại.",
    },
  };
}

function baseFamilyRow(): AllocationFamilyRow {
  return {
    family: {
      service_date: "2026-09-02",
      delivery_location_id: locationId,
      ingredient_id: ingredientId,
      unit_id: unitId,
      family_id: null,
      version: 0,
      source_fingerprint: "review-source-100",
    },
    service_date: "2026-09-02",
    delivery_location_id: locationId,
    location_name: "Bếp chính Nguyễn Du",
    school_id: "25000000-0000-4000-8000-000000000061",
    school_name: "Trường Tiểu học Nguyễn Du",
    ingredient_id: ingredientId,
    ingredient_name: "Gạo thơm",
    unit_id: unitId,
    unit_code: "kg",
    family_quantity: "100.000000",
    contributions: [
      {
        purchase_handoff_line_revision_id:
          "25000000-0000-4000-8000-000000000071",
        contribution_quantity: "60.000000",
      },
      {
        purchase_handoff_line_revision_id:
          "25000000-0000-4000-8000-000000000072",
        contribution_quantity: "40.000000",
      },
    ],
    contribution_count: 2,
    splits: [],
    eligible_suppliers: [
      { supplier_id: supplierAId, supplier_name: "NCC An Phú", priority: 1 },
      { supplier_id: supplierBId, supplier_name: "NCC Bình Minh", priority: 2 },
    ],
    state: "UNALLOCATED",
    recommendation: {
      supplier_id: supplierAId,
      allocated_quantity: "100.000000",
      split_ratio: "1.000000000000",
    },
    rebalance_proposal: null,
    allowed_actions: {
      save_allocation: true,
      confirm_recommendation: true,
    },
    disabled_reasons: [],
    blockers: [],
    warnings: [],
  };
}

export function createReviewProcurementWorkbenchFixture(
  scenario: SchoolCateringProcurementReviewScenario = "default",
): ProcurementWorkbenchData {
  const row = baseFamilyRow();
  if (scenario === "manual_split") {
    row.family = { ...row.family, family_id: familyId, version: 1 };
    row.state = "BALANCED";
    row.recommendation = null;
    row.allowed_actions.confirm_recommendation = false;
    row.disabled_reasons = ["ALLOCATION_ALREADY_EXISTS"];
    row.splits = [
      {
        supplier_split_id: "25000000-0000-4000-8000-000000000081",
        supplier_id: supplierAId,
        supplier_name: "NCC An Phú",
        allocated_quantity: "60.000000",
        split_ratio: "0.600000000000",
      },
      {
        supplier_split_id: "25000000-0000-4000-8000-000000000082",
        supplier_id: supplierBId,
        supplier_name: "NCC Bình Minh",
        allocated_quantity: "40.000000",
        split_ratio: "0.400000000000",
      },
    ];
  } else if (scenario === "rebalance") {
    Object.assign(
      row,
      createReviewProcurementWorkbenchFixture("manual_split").rows[0],
    );
    row.family = {
      ...row.family,
      source_fingerprint: "review-source-120",
    };
    row.family_quantity = "120.000000";
    row.state = "STALE_REBALANCE_AVAILABLE";
    row.rebalance_proposal = [
      {
        supplier_id: supplierAId,
        allocated_quantity: "72.000000",
        split_ratio: "0.600000000000",
      },
      {
        supplier_id: supplierBId,
        allocated_quantity: "48.000000",
        split_ratio: "0.400000000000",
      },
    ];
  } else if (scenario === "needs_reallocation") {
    Object.assign(
      row,
      createReviewProcurementWorkbenchFixture("manual_split").rows[0],
    );
    row.family = {
      ...row.family,
      source_fingerprint: "review-source-ineligible",
    };
    row.state = "NEEDS_REALLOCATION";
    row.eligible_suppliers = row.eligible_suppliers.slice(0, 1);
    row.rebalance_proposal = null;
    row.blockers = ["SUPPLIER_INELIGIBLE"];
    row.disabled_reasons = ["SUPPLIER_INELIGIBLE"];
  }
  return {
    success: true,
    contract_version: "SCHOOL-CATERING-PROCUREMENT.v1",
    date_start: "2026-09-01",
    date_end: "2026-09-07",
    rows: scenario === "empty" ? [] : [row],
    warnings: [],
    blockers: [],
  };
}

function basePurchaseOrder(): SchoolCateringPurchaseOrder {
  return {
    purchase_order_id: purchaseOrderId,
    supplier: {
      supplier_id: supplierAId,
      supplier_name: "NCC An Phú",
      supplier_status: "ACTIVE",
    },
    service_date: "2026-09-02",
    status: "DRAFT",
    version: 1,
    document_number: null,
    replaces_purchase_order_id: null,
    replaced_by_purchase_order_id: null,
    commitment_state: "DRAFT_CURRENT",
    current_revision: {
      purchase_order_revision_id: purchaseOrderRevisionId,
      revision_number: 1,
      revision_kind: "BASE",
      revision_status: "DRAFT",
      predecessor_revision_id: null,
      supplier_name_snapshot: "NCC An Phú",
      delivery_location_snapshot: null,
      released_by_actor_id: null,
      released_at: null,
      reason_note: null,
    },
    lines: [
      {
        purchase_order_line_revision_id: "25000000-0000-4000-8000-000000000091",
        purchase_order_line_id: "25000000-0000-4000-8000-000000000092",
        ingredient: {
          ingredient_id: ingredientId,
          ingredient_name: "Gạo thơm",
        },
        ordered_quantity: "60.000000",
        unit: { unit_id: unitId, unit_code: "kg" },
        delivery_location: {
          delivery_location_id: locationId,
          location_name: "Bếp chính Nguyễn Du",
        },
        service_date: "2026-09-02",
        source: {
          family_id: familyId,
          family_revision_id: familyRevisionId,
          supplier_split_id: "25000000-0000-4000-8000-000000000081",
        },
      },
      {
        purchase_order_line_revision_id: "25000000-0000-4000-8000-000000000093",
        purchase_order_line_id: "25000000-0000-4000-8000-000000000094",
        ingredient: {
          ingredient_id: ingredientId,
          ingredient_name: "Gạo thơm",
        },
        ordered_quantity: "40.000000",
        unit: { unit_id: unitId, unit_code: "kg" },
        delivery_location: {
          delivery_location_id: "25000000-0000-4000-8000-000000000012",
          location_name: "Bếp chính Trần Quốc Toản",
        },
        service_date: "2026-09-02",
        source: {
          family_id: familyId,
          family_revision_id: familyRevisionId,
          supplier_split_id: "25000000-0000-4000-8000-000000000081",
        },
      },
    ],
    stale: false,
    release_eligible: true,
    export_ready: false,
    blockers: [],
    warnings: [],
    allowed_actions: {
      release: true,
      export: false,
      create_replacement: false,
    },
    disabled_reasons: [],
  };
}

export function createReviewPurchaseOrdersFixture(
  scenario: SchoolCateringProcurementReviewScenario = "po_draft",
): PurchaseOrdersData {
  const order = basePurchaseOrder();
  if (scenario === "stale_po") {
    order.stale = true;
    order.commitment_state = "DRAFT_STALE";
    order.release_eligible = false;
    order.blockers = ["PO_DRAFT_STALE"];
    order.allowed_actions.release = false;
    order.disabled_reasons = ["PO_DRAFT_STALE"];
  } else if (scenario === "released_po") {
    order.status = "RELEASED_TO_SUPPLIER";
    order.version = 2;
    order.document_number = "PO-20260902-2500000000004000";
    order.current_revision = {
      ...order.current_revision,
      revision_number: 2,
      revision_kind: "RELEASE",
      revision_status: "RELEASED_TO_SUPPLIER",
      predecessor_revision_id: purchaseOrderRevisionId,
      purchase_order_revision_id: "25000000-0000-4000-8000-000000000053",
      released_by_actor_id: "25000000-0000-4000-8000-000000000101",
      released_at: "2026-09-01T08:00:00.000Z",
    };
    order.release_eligible = false;
    order.export_ready = true;
    order.commitment_state = "CURRENT";
    order.allowed_actions = {
      release: false,
      export: true,
      create_replacement: false,
    };
    order.disabled_reasons = ["PO_ALREADY_RELEASED"];
  } else if (
    scenario === "replacement_required" ||
    scenario === "cancellation_required"
  ) {
    Object.assign(
      order,
      createReviewPurchaseOrdersFixture("released_po").purchase_orders[0],
    );
    order.stale = true;
    order.commitment_state =
      scenario === "replacement_required"
        ? "REPLACEMENT_REQUIRED"
        : "CANCELLATION_REQUIRED";
    order.blockers = [
      scenario === "replacement_required"
        ? "PO_REPLACEMENT_REQUIRED"
        : "CANCELLATION_REQUIRED",
    ];
    order.disabled_reasons = [...order.blockers];
    order.allowed_actions.create_replacement =
      scenario === "replacement_required";
  }
  return {
    success: true,
    contract_version: "SCHOOL-CATERING-PROCUREMENT.v1",
    date_start: "2026-09-01",
    date_end: "2026-09-07",
    purchase_orders: scenario === "empty" ? [] : [order],
    procurement_current: scenario !== "cancellation_required",
    warnings: [],
    blockers: [],
  };
}

export function createReviewSchoolCateringProcurementApi(
  scenario: SchoolCateringProcurementReviewScenario = "default",
): SchoolCateringProcurementApi {
  let workbench = createReviewProcurementWorkbenchFixture(scenario);
  let purchaseOrders = createReviewPurchaseOrdersFixture(
    scenario === "stale_po" ||
      scenario === "released_po" ||
      scenario === "replacement_required" ||
      scenario === "cancellation_required"
      ? scenario
      : "po_draft",
  );

  const preflight = (): AtlasRpcResult | null => {
    if (scenario === "permission_denied")
      return backendError(
        "CAPABILITY_DENIED",
        "Bạn không có quyền truy cập Kế hoạch mua hàng.",
      );
    if (scenario === "retryable_failure") return retryableFailure();
    return null;
  };

  return {
    async getWorkbench() {
      const failure = preflight();
      return (
        failure ?? success(workbench as unknown as Record<string, JsonValue>)
      );
    },
    async saveAllocation(request: SaveSupplierAllocationRequest) {
      const failure = preflight();
      if (failure) return failure;
      if (scenario === "stale_version")
        return backendError(
          "STALE_VERSION",
          "Phân bổ đã thay đổi. Hãy tải lại dữ liệu hiện tại.",
        );
      if (scenario === "replay_success")
        return success({
          command_id: request.command_id,
          idempotency_status: "REPLAY",
          safe_operator_message: "Phân bổ này đã được lưu trước đó.",
          warnings: [],
          blockers: [],
        });
      const row = workbench.rows[0];
      if (row) {
        row.family = {
          ...row.family,
          family_id: row.family.family_id ?? familyId,
          version: row.family.version + 1,
        };
        row.splits = request.payload.splits.map((split, index) => ({
          supplier_split_id: `25000000-0000-4000-8000-${String(index + 81).padStart(12, "0")}`,
          supplier_id: split.supplier_id,
          supplier_name:
            row.eligible_suppliers.find(
              (supplier) => supplier.supplier_id === split.supplier_id,
            )?.supplier_name ?? "Nhà cung ứng",
          allocated_quantity: split.allocated_quantity,
          split_ratio:
            split.allocated_quantity === "72.000000"
              ? "0.600000000000"
              : split.allocated_quantity === "48.000000"
                ? "0.400000000000"
                : "0.500000000000",
        }));
        row.state = "BALANCED";
        row.recommendation = null;
        row.rebalance_proposal = null;
        row.blockers = [];
        row.disabled_reasons = ["ALLOCATION_ALREADY_EXISTS"];
      }
      return success({
        command_id: request.command_id,
        correlation_id: request.correlation_id,
        idempotency_status: "COMPLETED",
        family: {
          family_id: familyId,
          family_version: row?.family.version ?? 1,
          family_quantity: row?.family_quantity ?? "0",
        },
        safe_operator_message: "Đã lưu phân bổ nhà cung ứng.",
        warnings: [],
        blockers: [],
      });
    },
    async confirmRecommendations(
      request: ConfirmSupplierRecommendationsRequest,
    ) {
      const failure = preflight();
      if (failure) return failure;
      const row = workbench.rows[0];
      if (row?.recommendation) {
        row.splits = [
          {
            supplier_split_id: "25000000-0000-4000-8000-000000000081",
            supplier_id: row.recommendation.supplier_id,
            supplier_name:
              row.eligible_suppliers[0]?.supplier_name ?? "Nhà cung ứng",
            allocated_quantity: row.recommendation.allocated_quantity,
            split_ratio: row.recommendation.split_ratio,
          },
        ];
        row.family = { ...row.family, family_id: familyId, version: 1 };
        row.state = "BALANCED";
        row.recommendation = null;
        row.allowed_actions.confirm_recommendation = false;
      }
      return success({
        command_id: request.command_id,
        correlation_id: request.correlation_id,
        idempotency_status: "COMPLETED",
        confirmed: [{ family_id: familyId, family_version: 1 }],
        skipped: [],
        safe_operator_message: "Đã xác nhận phân bổ đề xuất.",
        warnings: [],
        blockers: [],
      });
    },
    async getPurchaseOrders() {
      const failure = preflight();
      return (
        failure ??
        success(purchaseOrders as unknown as Record<string, JsonValue>)
      );
    },
    async createPurchaseOrderDrafts(request: CreatePurchaseOrderDraftsRequest) {
      const failure = preflight();
      if (failure) return failure;
      purchaseOrders = createReviewPurchaseOrdersFixture("po_draft");
      const skippedDates: PurchaseOrderDraftSkippedDate[] =
        request.payload.date_end === request.payload.date_start
          ? []
          : [
              {
                service_date: request.payload.date_end,
                family_count: 0,
                ready: false,
                blockers: [
                  {
                    service_date: request.payload.date_end,
                    reason: "NO_CURRENT_FAMILIES",
                  },
                ],
              },
            ];
      return success({
        command_id: request.command_id,
        correlation_id: request.correlation_id,
        idempotency_status: "COMPLETED",
        created_purchase_order_ids: [purchaseOrderId],
        regenerated_purchase_order_ids: [],
        ready_dates: [request.payload.date_start],
        skipped_dates: skippedDates,
        authoritative_readback: {
          purchase_order_ids: [purchaseOrderId],
          ready_dates: [request.payload.date_start],
          skipped_dates: skippedDates,
        },
        safe_operator_message: "Đã tạo đơn mua cho ngày sẵn sàng.",
        warnings: [],
        blockers: skippedDates,
      });
    },
    async createPurchaseOrderReplacement(
      request: CreatePurchaseOrderReplacementRequest,
    ) {
      const failure = preflight();
      if (failure) return failure;
      const replacement = basePurchaseOrder();
      replacement.purchase_order_id = "25000000-0000-4000-8000-000000000054";
      replacement.replaces_purchase_order_id =
        request.payload.replaced_purchase_order_id;
      replacement.current_revision.purchase_order_revision_id =
        "25000000-0000-4000-8000-000000000055";
      const released = createReviewPurchaseOrdersFixture("replacement_required")
        .purchase_orders[0]!;
      released.replaced_by_purchase_order_id = replacement.purchase_order_id;
      released.allowed_actions.create_replacement = false;
      purchaseOrders = {
        ...createReviewPurchaseOrdersFixture("replacement_required"),
        purchase_orders: [released, replacement],
      };
      return success({
        command_id: request.command_id,
        correlation_id: request.correlation_id,
        idempotency_status: "COMPLETED",
        purchase_order_id: replacement.purchase_order_id,
        replaces_purchase_order_id: request.payload.replaced_purchase_order_id,
        safe_operator_message: "Đã tạo đơn mua thay thế đầy đủ để kiểm tra.",
        warnings: [],
        blockers: [],
      });
    },
    async releasePurchaseOrder(request: ReleasePurchaseOrderRequest) {
      const failure = preflight();
      if (failure) return failure;
      purchaseOrders = createReviewPurchaseOrdersFixture("released_po");
      const order = purchaseOrders.purchase_orders[0]!;
      return success({
        command_id: request.command_id,
        correlation_id: request.correlation_id,
        idempotency_status: "COMPLETED",
        purchase_order_id: order.purchase_order_id,
        document_number: order.document_number,
        authoritative_readback: {
          purchase_order_id: order.purchase_order_id,
          status: order.status,
          document_number: order.document_number,
          version: order.version,
        },
        safe_operator_message: "Đã phát hành đơn mua cho nhà cung cấp.",
        warnings: [],
        blockers: [],
      });
    },
  };
}
