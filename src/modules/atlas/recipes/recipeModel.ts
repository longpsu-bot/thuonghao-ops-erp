import type { AtlasRpcResult, JsonValue } from "../connection/atlasRpc";
import type {
  EffectiveCompositionResult,
  EffectiveTargetLine,
  RecipeAdjustmentAction,
  RecipeAdjustmentScope,
} from "../recipe-adjustments/recipeAdjustmentModel";

export type DishStatus = "DRAFT" | "ACTIVE" | "INACTIVE";
export type RecipeStatus = "ACTIVE" | "INACTIVE";
export type RecipeVersionStatus =
  "DRAFT" | "VALIDATED" | "RELEASED_FOR_PLANNING" | "LOCKED";

export type DishRecord = {
  dish_id: string;
  dish_code: string;
  dish_name: string;
  dish_category: string | null;
  dish_type_id: string | null;
  dish_type_code: string | null;
  dish_type_name: string | null;
  operational_notes: string | null;
  dish_status: DishStatus;
  display_order: number;
  requires_need_generation: boolean;
  version: number;
  created_at: string;
  updated_at: string;
};

export type DishTypeReference = {
  dish_type_id: string;
  dish_type_code: string;
  dish_type_name: string;
  source_header_aliases: string[];
  display_order: number;
  dish_type_status: "ACTIVE" | "INACTIVE";
  version: number;
  created_at: string;
  updated_at: string;
};

export type RecipeRecord = {
  recipe_id: string;
  dish_id: string;
  school_type_id: string | null;
  recipe_status: RecipeStatus;
  version: number;
  created_at: string;
  updated_at: string;
};

export type RecipeCompositionLine = {
  recipe_line_id: string;
  recipe_line_revision_id?: string;
  predecessor_recipe_line_revision_id: string | null;
  line_revision_number?: number;
  ingredient_id: string;
  quantity_per_basis: number;
  unit_id: string;
  line_disposition: "PRESENT" | "REMOVED";
  operational_note: string | null;
  line_code: string | null;
  legacy_line_id?: string | null;
};

export type RecipeVersionRecord = {
  recipe_version_id: string;
  recipe_id: string;
  version_number: number;
  predecessor_recipe_version_id: string | null;
  basis_portions: number;
  recipe_version_status: RecipeVersionStatus;
  version: number;
  source_evidence: Record<string, JsonValue>;
  created_by_actor_id: string;
  created_at: string;
  validated_by_actor_id: string | null;
  validated_at: string | null;
  released_by_actor_id: string | null;
  released_at: string | null;
  locked_by_actor_id: string | null;
  locked_at: string | null;
  composition: RecipeCompositionLine[];
};

export type RecipeReference = {
  school_type_id: string;
  school_type_code: string;
  school_type_name: string;
  school_type_status: "ACTIVE" | "INACTIVE";
};

export type RecipeIngredientReference = {
  ingredient_id: string;
  ingredient_code: string;
  ingredient_name: string;
  ingredient_status: "ACTIVE" | "INACTIVE" | "ARCHIVED";
};

export type RecipeUnitReference = {
  unit_id: string;
  unit_code: string;
  unit_name: string;
  unit_status: "ACTIVE" | "INACTIVE";
};

export type RecipeWorkflowSelection = {
  dish_id: string | null;
  school_type_id: string | null;
  recipe_id: string | null;
  recipe_version_id: string | null;
  expected_version: number | null;
  in_use_recipe_version_id: string | null;
  business_status:
    "NOT_SAVED" | "SAVED" | "AVAILABLE" | "LOCKED" | "NEEDS_ATTENTION";
  locked_for_normal_editing: boolean;
  lock_reason: string | null;
  basis_portions: number;
  composition: RecipeCompositionLine[];
  allowed_actions: {
    save_recipe: boolean;
    release_recipe: boolean;
  };
  disabled_reason_codes: {
    save_recipe: string | null;
    release_recipe: string | null;
  };
  disabled_reasons: {
    save_recipe: string | null;
    release_recipe: string | null;
  };
};

export type RecipeWorkbenchData = {
  dish_types: DishTypeReference[];
  dishes: DishRecord[];
  recipes: RecipeRecord[];
  recipe_versions: RecipeVersionRecord[];
  school_types: RecipeReference[];
  ingredients: RecipeIngredientReference[];
  units: RecipeUnitReference[];
  selected_recipe: RecipeWorkflowSelection;
};

export type EffectiveHistoryChangeOrder = {
  adjustment_id: string;
  revision_id: string;
  revision_number: number;
  revision_status: "ACTIVE" | "SUPERSEDED" | "CANCELLED";
  business_event_kind: "CREATED" | "CORRECTED" | "CANCELLED";
  scope_kind: RecipeAdjustmentScope;
  action_kind: RecipeAdjustmentAction;
  effective_from: string;
  effective_to: string | null;
  reason_code: string;
  reason: string;
  issuer: string;
  issued_at: string;
};

export type EffectiveHistoryPeriod = {
  period_from: string;
  period_to: string | null;
  resolution_status: "READY" | "BLOCKED";
  effective_bom: EffectiveTargetLine[];
  change_orders: EffectiveHistoryChangeOrder[];
  warnings: { code: string; message: string }[];
  blockers: { code: string; message: string; [key: string]: JsonValue }[];
};

export type DishRecipeOperatorWorkbench = {
  dish: {
    dish_id: string;
    dish_name: string;
    dish_type_name: string | null;
    dish_status: DishStatus;
  };
  context_kind: "SYSTEM_SCHOOL_TYPE" | "SCHOOL";
  as_of_date: string;
  school_id: string | null;
  school_type_id: string;
  selected_recipe: EffectiveCompositionResult["selected_recipe"];
  basis_portions: number | null;
  editable_state: "LOCKED_RELEASED";
  is_editable: boolean;
  is_operationally_locked: boolean;
  current_effective_bom: EffectiveTargetLine[];
  school_exception_count: number;
  allowed_actions: ("CREATE_CHANGE_ORDER" | "COPY_DISH_RECIPES")[];
  blockers: { code: string; message: string; [key: string]: JsonValue }[];
  warnings: { code: string; message: string }[];
  history_periods: EffectiveHistoryPeriod[];
};

export type DishRecipeCopyScopeResult = {
  school_type_id: string;
  scope_name: string;
  status: "COPIED" | "SOURCE_NOT_AVAILABLE";
  source_recipe_id?: string;
  source_recipe_version_id?: string;
  source_selection_scope?: "SCHOOL_TYPE" | "GENERAL";
  target_recipe_id?: string;
  target_recipe_version_id?: string;
};

export type DishRecipeCopyResult = {
  success: true;
  contract_version: "RECIPE-EFFECTIVE.v1";
  command_id: string;
  correlation_id: string;
  idempotency_status: string;
  scope_results: DishRecipeCopyScopeResult[];
};

export const emptyRecipeWorkbench = (): RecipeWorkbenchData => ({
  dish_types: [],
  dishes: [],
  recipes: [],
  recipe_versions: [],
  school_types: [],
  ingredients: [],
  units: [],
  selected_recipe: {
    dish_id: null,
    school_type_id: null,
    recipe_id: null,
    recipe_version_id: null,
    expected_version: null,
    in_use_recipe_version_id: null,
    business_status: "NOT_SAVED",
    locked_for_normal_editing: false,
    lock_reason: null,
    basis_portions: 100,
    composition: [],
    allowed_actions: { save_recipe: false, release_recipe: false },
    disabled_reason_codes: {
      save_recipe: "SELECTION_REQUIRED",
      release_recipe: "SELECTION_REQUIRED",
    },
    disabled_reasons: {
      save_recipe: "Hãy chọn món ăn.",
      release_recipe: "Hãy chọn món ăn.",
    },
  },
});

function responseArray<T>(
  result: AtlasRpcResult,
  source: Record<string, JsonValue>,
  key: string,
): T[] | null {
  if (result.kind !== "success") return null;
  const value = source[key];
  return Array.isArray(value) ? (value as T[]) : null;
}

function isRecord(
  value: JsonValue | undefined,
): value is Record<string, JsonValue> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isEffectiveLine(value: JsonValue): boolean {
  if (!isRecord(value)) return false;
  return (
    typeof value.ingredient_id === "string" &&
    typeof value.ingredient_name === "string" &&
    typeof value.quantity_per_basis === "number" &&
    typeof value.unit_id === "string" &&
    typeof value.unit_name === "string" &&
    (value.target_kind === "RECIPE_LINE" ||
      value.target_kind === "ADJUSTMENT_LINE") &&
    typeof value.target_id === "string" &&
    typeof value.source_layer === "string"
  );
}

function isHistoryPeriod(value: JsonValue): boolean {
  if (!isRecord(value)) return false;
  return (
    typeof value.period_from === "string" &&
    (typeof value.period_to === "string" || value.period_to === null) &&
    (value.resolution_status === "READY" ||
      value.resolution_status === "BLOCKED") &&
    Array.isArray(value.effective_bom) &&
    value.effective_bom.every(isEffectiveLine) &&
    Array.isArray(value.change_orders) &&
    Array.isArray(value.warnings) &&
    Array.isArray(value.blockers)
  );
}

function isCopyScopeResult(value: JsonValue): boolean {
  if (!isRecord(value)) return false;
  return (
    typeof value.school_type_id === "string" &&
    typeof value.scope_name === "string" &&
    (value.status === "COPIED" || value.status === "SOURCE_NOT_AVAILABLE")
  );
}

export function recipeWorkbenchFromResult(
  result: AtlasRpcResult,
): RecipeWorkbenchData | null {
  if (result.kind !== "success") return null;
  const nested = result.response.workbench;
  const source =
    typeof nested === "object" && nested !== null && !Array.isArray(nested)
      ? nested
      : result.response;
  const dishes = responseArray<DishRecord>(result, source, "dishes");
  const dishTypes = responseArray<DishTypeReference>(
    result,
    source,
    "dish_types",
  );
  const recipes = responseArray<RecipeRecord>(result, source, "recipes");
  const recipeVersions = responseArray<RecipeVersionRecord>(
    result,
    source,
    "recipe_versions",
  );
  const schoolTypes = responseArray<RecipeReference>(
    result,
    source,
    "school_types",
  );
  const ingredients = responseArray<RecipeIngredientReference>(
    result,
    source,
    "ingredients",
  );
  const units = responseArray<RecipeUnitReference>(result, source, "units");
  const selectedRecipe = source.selected_recipe;
  if (
    !dishTypes ||
    !dishes ||
    !recipes ||
    !recipeVersions ||
    !schoolTypes ||
    !ingredients ||
    !units ||
    typeof selectedRecipe !== "object" ||
    selectedRecipe === null ||
    Array.isArray(selectedRecipe)
  )
    return null;
  return {
    dish_types: dishTypes,
    dishes,
    recipes,
    recipe_versions: recipeVersions,
    school_types: schoolTypes,
    ingredients,
    units,
    selected_recipe: selectedRecipe as unknown as RecipeWorkflowSelection,
  };
}

export function dishRecipeOperatorWorkbenchFromResult(
  result: AtlasRpcResult,
): DishRecipeOperatorWorkbench | null {
  if (result.kind !== "success" || !isRecord(result.response.workbench))
    return null;
  const source = result.response.workbench;
  if (
    !isRecord(source.dish) ||
    typeof source.dish.dish_id !== "string" ||
    typeof source.dish.dish_name !== "string" ||
    (source.context_kind !== "SYSTEM_SCHOOL_TYPE" &&
      source.context_kind !== "SCHOOL") ||
    typeof source.as_of_date !== "string" ||
    typeof source.school_type_id !== "string" ||
    (typeof source.basis_portions !== "number" &&
      source.basis_portions !== null) ||
    source.editable_state !== "LOCKED_RELEASED" ||
    typeof source.is_editable !== "boolean" ||
    typeof source.is_operationally_locked !== "boolean" ||
    typeof source.school_exception_count !== "number" ||
    !Array.isArray(source.current_effective_bom) ||
    !source.current_effective_bom.every(isEffectiveLine) ||
    !Array.isArray(source.allowed_actions) ||
    !Array.isArray(source.blockers) ||
    !Array.isArray(source.warnings) ||
    !Array.isArray(source.history_periods) ||
    !source.history_periods.every(isHistoryPeriod)
  )
    return null;
  return source as unknown as DishRecipeOperatorWorkbench;
}

export function dishRecipeCopyFromResult(
  result: AtlasRpcResult,
): DishRecipeCopyResult | null {
  if (result.kind !== "success") return null;
  const source = result.response;
  if (
    source.contract_version !== "RECIPE-EFFECTIVE.v1" ||
    typeof source.command_id !== "string" ||
    typeof source.correlation_id !== "string" ||
    typeof source.idempotency_status !== "string" ||
    !Array.isArray(source.scope_results) ||
    !source.scope_results.every(isCopyScopeResult)
  )
    return null;
  return source as DishRecipeCopyResult;
}

export function recipeResultMessage(result: AtlasRpcResult): string {
  if (result.kind === "success")
    return (
      result.response.safe_operator_message?.toString() ??
      "Đã cập nhật và tải lại công thức."
    );
  if (result.kind === "auth_error")
    return "Phiên làm việc không còn hợp lệ. Vui lòng đăng nhập lại.";
  if (result.kind === "transport_error")
    return "Mất kết nối khi đang cập nhật. Hãy tải lại để kiểm tra kết quả trước khi tiếp tục.";
  if (result.kind === "client_error")
    return "Thao tác này chưa sẵn sàng. Hãy tải lại hoặc liên hệ bộ phận hỗ trợ.";
  const messages: Record<string, string> = {
    CAPABILITY_DENIED: "Bạn không có quyền thực hiện thao tác này.",
    SCOPE_DENIED: "Phạm vi được cấp không cho phép thao tác này.",
    STALE_VERSION: "Dữ liệu đã thay đổi. Hãy tải lại trước khi lưu.",
    VALIDATION_FAILED: "Dữ liệu chưa hợp lệ. Kiểm tra chi tiết và thử lại.",
    INVARIANT_VIOLATION: "Công thức hiện tại chưa cho phép thao tác này.",
    RECIPE_OPERATIONALLY_LOCKED:
      "Món này đã có trong thực đơn đã duyệt. Muốn thay đổi công thức, hãy dùng Điều chỉnh.",
    CONFLICT: "Dữ liệu mục tiêu đang xung đột với một bản ghi hiện có.",
  };
  return (
    messages[result.error.error_code] ??
    result.error.safe_message ??
    "Atlas đã từ chối thao tác một cách an toàn."
  );
}

export function schoolScopeLabel(
  recipe: RecipeRecord,
  schoolTypes: RecipeReference[],
) {
  if (!recipe.school_type_id) return "Công thức chung";
  return (
    schoolTypes.find(
      (schoolType) => schoolType.school_type_id === recipe.school_type_id,
    )?.school_type_name ?? "Loại trường không xác định"
  );
}

export function ingredientLabel(
  ingredientId: string,
  ingredients: RecipeIngredientReference[],
) {
  return (
    ingredients.find((item) => item.ingredient_id === ingredientId)
      ?.ingredient_name ?? "Nguyên liệu không xác định"
  );
}

export function unitLabel(unitId: string, units: RecipeUnitReference[]) {
  return (
    units.find((item) => item.unit_id === unitId)?.unit_name ??
    "Đơn vị không xác định"
  );
}
