import type { AtlasRpcResult, JsonValue } from "../connection/atlasRpc";
import type { MasterDataCommandRequest } from "./masterDataApi";

export type SchoolMasterData = {
  school_id: string;
  school_code: string;
  school_name: string;
  school_status: "ACTIVE" | "INACTIVE";
  version: number;
  display_order: number;
  default_student_portions: number;
  default_teacher_portions: number;
  school_type_id: string | null;
  school_type_name: string | null;
  customer_id: string;
  customer_code: string;
  customer_name: string;
  delivery_location_id: string;
  delivery_location_name: string;
  delivery_address: string;
  delivery_instructions: string | null;
  contract_context: string | null;
};

export type SupplierPriority = {
  supplier_eligibility_id: string;
  supplier_id: string;
  supplier_name: string;
  priority: number;
};

export type IngredientMasterData = {
  ingredient_id: string;
  ingredient_code: string;
  ingredient_name: string;
  ingredient_status: "ACTIVE" | "INACTIVE" | "ARCHIVED";
  ingredient_type: string | null;
  shopping_type: string | null;
  purchase_unit_id: string | null;
  purchase_unit_code: string | null;
  purchase_unit_name: string | null;
  order_step: number | null;
  version: number;
  supplier_priorities: SupplierPriority[];
};

export type SupplierMasterData = {
  supplier_id: string;
  supplier_code: string;
  supplier_name: string;
  supplier_status: "ACTIVE" | "INACTIVE" | "SUSPENDED";
  contact_name: string | null;
  contact_phone: string | null;
  contact_email: string | null;
  version: number;
};

export type UnitMasterData = {
  unit_id: string;
  unit_code: string;
  unit_name: string;
  unit_status: "ACTIVE" | "INACTIVE";
};

export function responseArray<T>(
  result: AtlasRpcResult,
  key: string,
): T[] | null {
  if (result.kind !== "success") return null;
  const value = result.response[key];
  return Array.isArray(value) ? (value as T[]) : null;
}

export function resultMessage(result: AtlasRpcResult) {
  if (result.kind === "backend_error") {
    if (result.error.error_code === "CAPABILITY_DENIED")
      return "Bạn không có quyền thực hiện thao tác này.";
    if (result.error.error_code === "SCOPE_DENIED")
      return "Phạm vi được cấp không cho phép thao tác này.";
    if (result.error.error_code === "STALE_VERSION")
      return "Dữ liệu đã thay đổi. Hãy tải lại trước khi lưu.";
    if (result.error.error_code === "VALIDATION_FAILED")
      return "Dữ liệu chưa hợp lệ. Kiểm tra các trường và thử lại.";
    return "Không thể hoàn tất thao tác lúc này. Vui lòng thử lại.";
  }
  if (result.kind === "success") return "Đã cập nhật và tải lại dữ liệu.";
  if (result.kind === "auth_error")
    return "Phiên làm việc không còn hợp lệ. Vui lòng đăng nhập lại.";
  if (result.kind === "transport_error")
    return "Không thể kết nối để hoàn tất thao tác. Vui lòng thử lại.";
  return "Không thể hoàn tất thao tác lúc này. Vui lòng thử lại.";
}

export function commandRequest(
  authSubject: string,
  correlationId: string,
  expectedVersion: number,
  reasonCode: string,
  payload: Record<string, JsonValue>,
): MasterDataCommandRequest {
  const commandId = crypto.randomUUID();
  return {
    contract_version: "RMVP-01.v1",
    command_id: commandId,
    correlation_id: correlationId,
    idempotency_key: `${reasonCode.toLowerCase()}:${commandId}`,
    expected_version: expectedVersion,
    requested_by_auth_subject: authSubject,
    requested_at: new Date().toISOString(),
    reason_code: reasonCode,
    reason_note: "Cập nhật từ khu vực Dữ liệu gốc Atlas.",
    payload,
  };
}
