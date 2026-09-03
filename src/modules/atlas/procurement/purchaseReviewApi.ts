import type { AtlasRpcRequest, AtlasRpcResult } from "../connection/atlasRpc";
import {
  saveSupplierAllocationRequest,
  type ProcurementWorkbenchScope,
  type SchoolCateringProcurementRpcInvoker,
} from "./schoolCateringProcurementApi";
import type {
  AllocationFamilyReference,
  AllocationFamilyRow,
  AllocationProposalSplit,
  EligibleSupplier,
  ProcurementWorkbenchData,
  SupplierSplitInput,
} from "./schoolCateringProcurementModel";

export type PurchasePreparation = {
  service_date: string;
  confirmed_need_batch_id: string;
  expected_version: number;
  ready: boolean;
  allowed: boolean;
  blockers: string[];
};
export type ConfirmedAllocationWorkbench = Omit<
  ProcurementWorkbenchData,
  "contract_version"
> & {
  contract_version: "CONFIRMED-SUPPLIER-ALLOCATION.v1";
  preparation: PurchasePreparation | null;
};
export type GeneratedPurchaseReviewRow = Pick<
  AllocationFamilyRow,
  | "service_date"
  | "school_id"
  | "school_name"
  | "delivery_location_id"
  | "location_name"
  | "ingredient_id"
  | "ingredient_name"
  | "unit_id"
  | "unit_code"
  | "family_quantity"
> & {
  family_quantity: string;
  eligible_suppliers: EligibleSupplier[];
  recommendation: AllocationProposalSplit | null;
  warnings: string[];
};
export type GeneratedPurchaseReview = {
  success: true;
  contract_version: "PURCHASE-REVIEW.v1";
  service_date: string;
  document_label: "DỰ KIẾN — CHƯA XÁC NHẬN";
  rows: GeneratedPurchaseReviewRow[];
  warnings: string[];
  blockers: string[];
};
export type ConfirmedAllocationReference = AllocationFamilyReference & {
  expected_source_batch_id: string;
  expected_source_batch_version: number;
};

export function generatedPurchaseReviewRequest(
  authSubject: string,
  correlationId: string,
  serviceDate: string,
): AtlasRpcRequest {
  return {
    contract_version: "PURCHASE-REVIEW.v1",
    requested_by_auth_subject: authSubject,
    correlation_id: correlationId,
    payload: { service_date: serviceDate },
  };
}
export function confirmedAllocationReadRequest(
  authSubject: string,
  correlationId: string,
  scope: ProcurementWorkbenchScope,
): AtlasRpcRequest {
  return {
    contract_version: "CONFIRMED-SUPPLIER-ALLOCATION.v1",
    requested_by_auth_subject: authSubject,
    correlation_id: correlationId,
    payload: scope,
  };
}
export function confirmedAllocationRequest(
  authSubject: string,
  correlationId: string,
  expectedVersion: number,
  family: ConfirmedAllocationReference,
  splits: SupplierSplitInput[],
) {
  return {
    ...saveSupplierAllocationRequest(
      authSubject,
      correlationId,
      expectedVersion,
      family,
      splits,
    ),
    contract_version: "CONFIRMED-SUPPLIER-ALLOCATION.v1" as const,
    reason_code: "CONFIRMED_SUPPLIER_ALLOCATION_SAVED" as const,
    payload: { family, splits },
  };
}
export function preparePurchaseOrdersRequest(
  authSubject: string,
  correlationId: string,
  source: Pick<
    PurchasePreparation,
    "service_date" | "confirmed_need_batch_id" | "expected_version"
  >,
) {
  const commandId = crypto.randomUUID();
  return {
    contract_version: "PURCHASE-COMMITMENT.v1" as const,
    command_id: commandId,
    correlation_id: correlationId,
    idempotency_key: `purchase-preparation:${commandId}`,
    expected_version: source.expected_version,
    requested_by_auth_subject: authSubject,
    requested_at: new Date().toISOString(),
    reason_code: "PURCHASE_ORDERS_PREPARED",
    reason_note: null,
    payload: {
      service_date: source.service_date,
      confirmed_need_batch_id: source.confirmed_need_batch_id,
    },
  };
}
export function generatedPurchaseReviewFromResult(
  result: AtlasRpcResult,
): GeneratedPurchaseReview | null {
  if (
    result.kind !== "success" ||
    result.response.contract_version !== "PURCHASE-REVIEW.v1" ||
    !Array.isArray(result.response.rows)
  )
    return null;
  const value = result.response as unknown as GeneratedPurchaseReview;
  return value.document_label === "DỰ KIẾN — CHƯA XÁC NHẬN" &&
    value.rows.every((row) => typeof row.family_quantity === "string")
    ? value
    : null;
}
export function confirmedAllocationFromResult(
  result: AtlasRpcResult,
): ConfirmedAllocationWorkbench | null {
  if (
    result.kind !== "success" ||
    result.response.contract_version !== "CONFIRMED-SUPPLIER-ALLOCATION.v1" ||
    !Array.isArray(result.response.rows)
  )
    return null;
  return result.response as unknown as ConfirmedAllocationWorkbench;
}
export function createPurchaseReviewApi(
  invoker: SchoolCateringProcurementRpcInvoker,
) {
  return {
    getGeneratedReview: (request: AtlasRpcRequest) =>
      invoker.invoke("atlas_api.get_generated_purchase_review", request),
    getConfirmedAllocations: (request: AtlasRpcRequest) =>
      invoker.invoke(
        "atlas_api.get_confirmed_supplier_allocation_workbench",
        request,
      ),
    saveConfirmedAllocation: (
      request: ReturnType<typeof confirmedAllocationRequest>,
    ) =>
      invoker.invoke("atlas_api.save_confirmed_supplier_allocation", request),
    preparePurchaseOrders: (
      request: ReturnType<typeof preparePurchaseOrdersRequest>,
    ) =>
      invoker.invoke(
        "atlas_api.prepare_school_catering_purchase_orders",
        request,
      ),
  };
}
export type PurchaseReviewApi = ReturnType<typeof createPurchaseReviewApi>;
