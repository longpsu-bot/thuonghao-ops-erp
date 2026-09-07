import type {
  AtlasRpcName,
  AtlasRpcRequest,
  AtlasRpcResult,
} from "../connection/atlasRpc";
import type {
  AllocationFamilyReference,
  AllocationFamilyState,
  ProcurementWorkbenchData,
  PurchaseOrdersData,
  PurchaseOrderStatus,
  RecommendationCandidate,
  SupplierSplitInput,
} from "./schoolCateringProcurementModel";

export const SCHOOL_CATERING_PROCUREMENT_RPC_FUNCTIONS = {
  getWorkbench: "atlas_api.get_school_catering_procurement_workbench",
  saveAllocation: "atlas_api.save_school_catering_supplier_allocation",
  confirmRecommendations:
    "atlas_api.confirm_school_catering_supplier_recommendations",
  getPurchaseOrders: "atlas_api.get_school_catering_purchase_orders",
  createPurchaseOrderDrafts:
    "atlas_api.create_school_catering_purchase_order_drafts",
  createPurchaseOrderReplacement:
    "atlas_api.create_school_catering_purchase_order_replacement",
  releasePurchaseOrder: "atlas_api.release_school_catering_purchase_order",
} as const satisfies Record<string, AtlasRpcName>;

export type ProcurementWorkbenchScope = {
  date_start: string;
  date_end: string;
  school_ids: string[];
  states: AllocationFamilyState[];
  search: string | null;
};

export type PurchaseOrderScope = {
  date_start: string;
  date_end: string;
  supplier_ids: string[];
  statuses: PurchaseOrderStatus[];
  search: string | null;
};

type ProcurementCommandBase = AtlasRpcRequest & {
  contract_version: "SCHOOL-CATERING-PROCUREMENT.v1";
  command_id: string;
  correlation_id: string;
  idempotency_key: string;
  expected_version: number;
  requested_by_auth_subject: string;
  requested_at: string;
  reason_note: null;
};

export type SaveSupplierAllocationRequest = ProcurementCommandBase & {
  reason_code: "SCHOOL_CATERING_SUPPLIER_ALLOCATION_SAVED";
  payload: {
    family: AllocationFamilyReference;
    splits: SupplierSplitInput[];
  };
};

export type ConfirmSupplierRecommendationsRequest = ProcurementCommandBase & {
  reason_code: "SCHOOL_CATERING_SUPPLIER_RECOMMENDATIONS_CONFIRMED";
  payload: { candidates: RecommendationCandidate[] };
};

export type CreatePurchaseOrderDraftsRequest = ProcurementCommandBase & {
  reason_code: "SCHOOL_CATERING_PO_DRAFTS_CREATED";
  payload: { date_start: string; date_end: string };
};

export type ReleasePurchaseOrderRequest = ProcurementCommandBase & {
  reason_code: "SCHOOL_CATERING_PO_RELEASED";
  payload: {
    purchase_order_id: string;
    expected_purchase_order_revision_id: string;
  };
};

export type CreatePurchaseOrderReplacementRequest = ProcurementCommandBase & {
  reason_code: "SCHOOL_CATERING_PO_REPLACEMENT_CREATED";
  payload: {
    replaced_purchase_order_id: string;
    expected_purchase_order_revision_id: string;
  };
};

export type SchoolCateringProcurementRpcInvoker = {
  invoke(
    functionName: AtlasRpcName,
    request: AtlasRpcRequest,
  ): Promise<AtlasRpcResult>;
};

export function procurementWorkbenchReadRequest(
  authSubject: string,
  correlationId: string,
  scope: ProcurementWorkbenchScope,
): AtlasRpcRequest {
  return {
    contract_version: "SCHOOL-CATERING-PROCUREMENT.v1",
    requested_by_auth_subject: authSubject,
    correlation_id: correlationId,
    payload: scope,
  };
}

export function purchaseOrdersReadRequest(
  authSubject: string,
  correlationId: string,
  scope: PurchaseOrderScope,
): AtlasRpcRequest {
  return {
    contract_version: "SCHOOL-CATERING-PROCUREMENT.v1",
    requested_by_auth_subject: authSubject,
    correlation_id: correlationId,
    payload: scope,
  };
}

function commandBase(
  authSubject: string,
  correlationId: string,
  expectedVersion: number,
  idempotencyPrefix: string,
) {
  const commandId = crypto.randomUUID();
  return {
    contract_version: "SCHOOL-CATERING-PROCUREMENT.v1" as const,
    command_id: commandId,
    correlation_id: correlationId,
    idempotency_key: `${idempotencyPrefix}:${commandId}`,
    expected_version: expectedVersion,
    requested_by_auth_subject: authSubject,
    requested_at: new Date().toISOString(),
    reason_note: null,
  };
}

export function saveSupplierAllocationRequest(
  authSubject: string,
  correlationId: string,
  expectedVersion: number,
  family: AllocationFamilyReference,
  splits: SupplierSplitInput[],
): SaveSupplierAllocationRequest {
  return {
    ...commandBase(
      authSubject,
      correlationId,
      expectedVersion,
      "school-catering-allocation",
    ),
    reason_code: "SCHOOL_CATERING_SUPPLIER_ALLOCATION_SAVED",
    payload: { family, splits },
  };
}

export function confirmSupplierRecommendationsRequest(
  authSubject: string,
  correlationId: string,
  candidates: RecommendationCandidate[],
): ConfirmSupplierRecommendationsRequest {
  return {
    ...commandBase(
      authSubject,
      correlationId,
      1,
      "school-catering-recommendations",
    ),
    reason_code: "SCHOOL_CATERING_SUPPLIER_RECOMMENDATIONS_CONFIRMED",
    payload: { candidates },
  };
}

export function createPurchaseOrderDraftsRequest(
  authSubject: string,
  correlationId: string,
  dateStart: string,
  dateEnd: string,
): CreatePurchaseOrderDraftsRequest {
  return {
    ...commandBase(authSubject, correlationId, 1, "school-catering-po-drafts"),
    reason_code: "SCHOOL_CATERING_PO_DRAFTS_CREATED",
    payload: { date_start: dateStart, date_end: dateEnd },
  };
}

export function releasePurchaseOrderRequest(
  authSubject: string,
  correlationId: string,
  expectedVersion: number,
  purchaseOrderId: string,
  expectedPurchaseOrderRevisionId: string,
): ReleasePurchaseOrderRequest {
  return {
    ...commandBase(
      authSubject,
      correlationId,
      expectedVersion,
      "school-catering-po",
    ),
    reason_code: "SCHOOL_CATERING_PO_RELEASED",
    payload: {
      purchase_order_id: purchaseOrderId,
      expected_purchase_order_revision_id: expectedPurchaseOrderRevisionId,
    },
  };
}

export function createPurchaseOrderReplacementRequest(
  authSubject: string,
  correlationId: string,
  expectedVersion: number,
  replacedPurchaseOrderId: string,
  expectedPurchaseOrderRevisionId: string,
): CreatePurchaseOrderReplacementRequest {
  return {
    ...commandBase(
      authSubject,
      correlationId,
      expectedVersion,
      "school-catering-po-replacement",
    ),
    reason_code: "SCHOOL_CATERING_PO_REPLACEMENT_CREATED",
    payload: {
      replaced_purchase_order_id: replacedPurchaseOrderId,
      expected_purchase_order_revision_id: expectedPurchaseOrderRevisionId,
    },
  };
}

function record(value: unknown): Record<string, unknown> | null {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : null;
}

export function procurementWorkbenchFromResult(
  result: AtlasRpcResult,
): ProcurementWorkbenchData | null {
  return result.kind === "success"
    ? (record(result.response) as ProcurementWorkbenchData | null)
    : null;
}

export function purchaseOrdersFromResult(
  result: AtlasRpcResult,
): PurchaseOrdersData | null {
  return result.kind === "success"
    ? (record(result.response) as PurchaseOrdersData | null)
    : null;
}

export function createSchoolCateringProcurementApi(
  invoker: SchoolCateringProcurementRpcInvoker,
) {
  return {
    getWorkbench(request: AtlasRpcRequest) {
      return invoker.invoke(
        SCHOOL_CATERING_PROCUREMENT_RPC_FUNCTIONS.getWorkbench,
        request,
      );
    },
    saveAllocation(request: SaveSupplierAllocationRequest) {
      return invoker.invoke(
        SCHOOL_CATERING_PROCUREMENT_RPC_FUNCTIONS.saveAllocation,
        request,
      );
    },
    confirmRecommendations(request: ConfirmSupplierRecommendationsRequest) {
      return invoker.invoke(
        SCHOOL_CATERING_PROCUREMENT_RPC_FUNCTIONS.confirmRecommendations,
        request,
      );
    },
    getPurchaseOrders(request: AtlasRpcRequest) {
      return invoker.invoke(
        SCHOOL_CATERING_PROCUREMENT_RPC_FUNCTIONS.getPurchaseOrders,
        request,
      );
    },
    createPurchaseOrderDrafts(request: CreatePurchaseOrderDraftsRequest) {
      return invoker.invoke(
        SCHOOL_CATERING_PROCUREMENT_RPC_FUNCTIONS.createPurchaseOrderDrafts,
        request,
      );
    },
    createPurchaseOrderReplacement(
      request: CreatePurchaseOrderReplacementRequest,
    ) {
      return invoker.invoke(
        SCHOOL_CATERING_PROCUREMENT_RPC_FUNCTIONS.createPurchaseOrderReplacement,
        request,
      );
    },
    releasePurchaseOrder(request: ReleasePurchaseOrderRequest) {
      return invoker.invoke(
        SCHOOL_CATERING_PROCUREMENT_RPC_FUNCTIONS.releasePurchaseOrder,
        request,
      );
    },
  };
}

export type SchoolCateringProcurementApi = ReturnType<
  typeof createSchoolCateringProcurementApi
>;
