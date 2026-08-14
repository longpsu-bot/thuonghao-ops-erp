import type { AtlasRpcResult, JsonValue } from "../connection/atlasRpc";

export type RecipeAdjustmentScope =
  "SYSTEM_INGREDIENT" | "SYSTEM_DISH" | "SCHOOL" | "SCHOOL_DISH";
export type RecipeAdjustmentAction =
  "ADD" | "REPLACE" | "ADJUST_QUANTITY" | "REMOVE";
export type RecipeAdjustmentLifecycle = "ACTIVE" | "SUPERSEDED" | "CANCELLED";

export type AdjustmentReference = {
  school_id?: string;
  school_code?: string;
  school_name?: string;
  school_type_id?: string | null;
  school_type_code?: string;
  school_type_name?: string;
  school_type_status?: string;
  school_status?: string;
  dish_id?: string;
  dish_code?: string;
  dish_name?: string;
  dish_status?: string;
  requires_need_generation?: boolean;
  ingredient_id?: string;
  ingredient_code?: string;
  ingredient_name?: string;
  ingredient_status?: string;
  unit_id?: string;
  unit_code?: string;
  unit_name?: string;
  unit_status?: string;
  recipe_line_id?: string;
  recipe_id?: string;
  line_code?: string | null;
  quantity_per_basis?: number;
};

export type RecipeAdjustmentRevision = {
  revision_id: string;
  revision_number: number;
  predecessor_revision_id: string | null;
  lifecycle_status: RecipeAdjustmentLifecycle;
  effective_from: string;
  effective_to: string | null;
  substitute_ingredient_id: string | null;
  quantity_per_basis: number | null;
  unit_id: string | null;
  reason_code: string;
  reason_note: string;
  source_evidence: Record<string, JsonValue>;
  created_by_actor_id: string;
  created_by_actor_name: string;
  created_at: string;
};

export type RecipeAdjustmentRecord = {
  adjustment_id: string;
  scope_kind: RecipeAdjustmentScope;
  action_kind: RecipeAdjustmentAction;
  school_id: string | null;
  dish_id: string | null;
  school_type_id: string | null;
  target_ingredient_id: string | null;
  target_recipe_line_id: string | null;
  adjustment_line_id: string | null;
  current_revision_id: string;
  current_revision_number: number;
  lifecycle_status: RecipeAdjustmentLifecycle;
  version: number;
  legacy_source: string | null;
  legacy_record_id: string | null;
  created_by_actor_id: string;
  created_by_actor_name: string;
  created_at: string;
  updated_by_actor_id: string;
  updated_by_actor_name: string;
  updated_at: string;
  revisions: RecipeAdjustmentRevision[];
};

export type RecipeAdjustmentTemporalState =
  | "ACTIVE"
  | "SCHEDULED"
  | "ACTIVE_CHANGE_SCHEDULED"
  | "ACTIVE_CANCELLATION_SCHEDULED"
  | "ACTIVE_RESUMED"
  | "EXPIRED"
  | "CANCELLED";

export type RecipeAdjustmentOperatorRevision = {
  revision_id: string;
  revision_status?: "ACTIVE" | "SUPERSEDED" | "CANCELLED";
  business_event_kind?: "CREATED" | "CORRECTED" | "CANCELLED";
  effective_from: string;
  effective_to: string | null;
  substitute_ingredient_id: string | null;
  quantity_per_basis: number | null;
  unit_id: string | null;
  reason_note: string;
  issued_at?: string | null;
  issuance_kind?: "ATLAS_NATIVE" | "LEGACY_UNATTRIBUTED";
  issued_by_actor_name?: string | null;
};

export type RecipeAdjustmentOperatorRecord = {
  adjustment_id: string;
  version: number;
  current_revision_id: string;
  current_revision_number: number;
  can_correct: boolean;
  can_cancel: boolean;
  scope_kind: RecipeAdjustmentScope;
  action_kind: RecipeAdjustmentAction;
  school_id: string | null;
  dish_id: string | null;
  school_type_id: string | null;
  target_ingredient_id: string | null;
  target_recipe_line_id: string | null;
  adjustment_line_id: string | null;
  temporal_state: RecipeAdjustmentTemporalState;
  temporal_state_date: string | null;
  display_revision: RecipeAdjustmentOperatorRevision;
  content_revision: RecipeAdjustmentOperatorRevision;
  command_revision: RecipeAdjustmentOperatorRevision;
  history: RecipeAdjustmentOperatorRevision[];
};

export type RecipeAdjustmentWorkbenchData = {
  reference_date: string;
  scope_catalog: {
    scope_kind: RecipeAdjustmentScope;
    actions: RecipeAdjustmentAction[];
  }[];
  precedence: string[];
  schools: AdjustmentReference[];
  dishes: AdjustmentReference[];
  school_types: AdjustmentReference[];
  ingredients: AdjustmentReference[];
  units: AdjustmentReference[];
  recipe_lines: AdjustmentReference[];
  operator_rows: RecipeAdjustmentOperatorRecord[];
  adjustments?: RecipeAdjustmentRecord[];
};

export type EffectiveCompositionLine = {
  selected_dish_id: string;
  selected_recipe_id: string;
  selected_recipe_version_id: string;
  basis_portions: number;
  base_recipe_line_id: string | null;
  base_recipe_line_revision_id: string | null;
  adjustment_line_id: string | null;
  line_code: string | null;
  base_ingredient_id: string | null;
  base_quantity_per_basis: number | null;
  base_unit_id: string | null;
  base_disposition: "PRESENT" | "REMOVED" | null;
  final_ingredient_id: string;
  final_quantity_per_basis: number;
  final_unit_id: string;
  final_disposition: "PRESENT" | "REMOVED";
  source_layer: string;
  applied_adjustment_ids: string[];
  applied_revision_ids: string[];
  lineage: {
    adjustment_id: string;
    revision_id: string;
    revision_number: number;
    scope_kind: RecipeAdjustmentScope;
    action_kind: RecipeAdjustmentAction;
    before: Record<string, JsonValue> | null;
    after: Record<string, JsonValue>;
    reason_code: string;
    reason_note: string;
    effective_from: string;
    effective_to: string | null;
    is_preview: boolean;
  }[];
};

export type EffectiveCompositionResult = {
  status: "READY" | "BLOCKED";
  as_of_date: string;
  school_id: string;
  dish_id: string;
  historical: boolean;
  selected_recipe: {
    dish_id: string;
    recipe_id: string;
    recipe_version_id: string;
    selection_scope: "SCHOOL_TYPE" | "GENERAL";
    basis_portions: number;
  } | null;
  lines: EffectiveCompositionLine[];
  warnings: { code: string; message: string }[];
  blockers: { code: string; message: string; [key: string]: JsonValue }[];
};

export type RecipeAdjustmentPreview = {
  as_of_date: string;
  school_id: string;
  dish_id: string;
  proposed_adjustment: Record<string, JsonValue>;
  before: EffectiveCompositionResult;
  after: EffectiveCompositionResult;
  affected_line_count: number;
  can_save: boolean;
  warnings: { code: string; message: string }[];
  blockers: { code: string; message: string; [key: string]: JsonValue }[];
};

export const emptyRecipeAdjustmentWorkbench =
  (): RecipeAdjustmentWorkbenchData => ({
    reference_date: "",
    scope_catalog: [],
    precedence: [],
    schools: [],
    dishes: [],
    school_types: [],
    ingredients: [],
    units: [],
    recipe_lines: [],
    operator_rows: [],
  });

function isRecord(
  value: JsonValue | undefined,
): value is Record<string, JsonValue> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export function adjustmentWorkbenchFromResult(
  result: AtlasRpcResult,
): RecipeAdjustmentWorkbenchData | null {
  if (result.kind !== "success") return null;
  const source = result.response.workbench;
  if (!isRecord(source)) return null;
  const keys = [
    "scope_catalog",
    "precedence",
    "schools",
    "dishes",
    "school_types",
    "ingredients",
    "units",
    "recipe_lines",
    "operator_rows",
  ] as const;
  if (keys.some((key) => !Array.isArray(source[key]))) return null;
  if (typeof source.reference_date !== "string") return null;
  return source as unknown as RecipeAdjustmentWorkbenchData;
}

export function effectiveCompositionFromResult(
  result: AtlasRpcResult,
): EffectiveCompositionResult | null {
  if (result.kind !== "success" || !isRecord(result.response.resolution))
    return null;
  return result.response.resolution as unknown as EffectiveCompositionResult;
}

export function adjustmentPreviewFromResult(
  result: AtlasRpcResult,
): RecipeAdjustmentPreview | null {
  if (result.kind !== "success" || !isRecord(result.response.preview))
    return null;
  return result.response.preview as unknown as RecipeAdjustmentPreview;
}

export function adjustmentResultMessage(result: AtlasRpcResult): string {
  if (result.kind === "success") return "Đã cập nhật dữ liệu điều chỉnh.";
  if (result.kind === "auth_error")
    return "Phiên làm việc không còn hợp lệ. Vui lòng đăng nhập lại.";
  if (result.kind === "transport_error")
    return "Không thể xác định kết quả do mất kết nối. Hãy tải lại dữ liệu trước khi tiếp tục.";
  if (result.kind === "client_error")
    return "Thao tác này chưa sẵn sàng trong Atlas.";
  const operatorMessages: Record<string, string> = {
    CAPABILITY_DENIED: "Bạn không có quyền thực hiện điều chỉnh công thức.",
    SCOPE_DENIED: "Phạm vi được cấp không cho phép thao tác này.",
    STALE_VERSION: "Điều chỉnh đã thay đổi. Hãy tải lại trước khi lưu.",
    VALIDATION_FAILED: "Thông tin điều chỉnh chưa hợp lệ. Hãy kiểm tra lại.",
    INVARIANT_VIOLATION:
      "Công thức hiệu lực bị chặn do chuỗi thay thế, nguyên liệu trùng hoặc mục tiêu không còn phù hợp.",
    CONFLICT: "Điều chỉnh trùng hoặc chồng lấn với lịch sử hiện có.",
  };
  return (
    operatorMessages[result.error.error_code] ??
    result.error.safe_message ??
    "Atlas đã từ chối thao tác một cách an toàn."
  );
}
