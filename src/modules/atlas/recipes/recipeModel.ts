import type { AtlasRpcResult, JsonValue } from "../connection/atlasRpc";

export type DishStatus = "DRAFT" | "ACTIVE" | "INACTIVE";
export type RecipeStatus = "ACTIVE" | "INACTIVE";
export type RecipeVersionStatus =
  "DRAFT" | "VALIDATED" | "RELEASED_FOR_PLANNING" | "LOCKED";

export type DishRecord = {
  dish_id: string;
  dish_code: string;
  dish_name: string;
  dish_category: string | null;
  operational_notes: string | null;
  dish_status: DishStatus;
  display_order: number;
  requires_need_generation: boolean;
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

export type RecipeWorkbenchData = {
  dishes: DishRecord[];
  recipes: RecipeRecord[];
  recipe_versions: RecipeVersionRecord[];
  school_types: RecipeReference[];
  ingredients: RecipeIngredientReference[];
  units: RecipeUnitReference[];
};

export const emptyRecipeWorkbench = (): RecipeWorkbenchData => ({
  dishes: [],
  recipes: [],
  recipe_versions: [],
  school_types: [],
  ingredients: [],
  units: [],
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
  if (
    !dishes ||
    !recipes ||
    !recipeVersions ||
    !schoolTypes ||
    !ingredients ||
    !units
  )
    return null;
  return {
    dishes,
    recipes,
    recipe_versions: recipeVersions,
    school_types: schoolTypes,
    ingredients,
    units,
  };
}

export function recipeResultMessage(result: AtlasRpcResult): string {
  if (result.kind === "success")
    return (
      result.response.safe_operator_message?.toString() ??
      "Đã lưu và tải lại dữ liệu có thẩm quyền."
    );
  if (result.kind === "auth_error")
    return "Phiên làm việc không còn hợp lệ. Vui lòng đăng nhập lại.";
  if (result.kind === "transport_error")
    return "Không thể kết nối với Atlas. Không có thay đổi nào được giả định.";
  if (result.kind === "client_error")
    return "Thao tác chưa có trong danh mục API đã được duyệt.";
  const messages: Record<string, string> = {
    CAPABILITY_DENIED: "Bạn không có quyền thực hiện thao tác này.",
    SCOPE_DENIED: "Phạm vi được cấp không cho phép thao tác này.",
    STALE_VERSION: "Dữ liệu đã thay đổi. Hãy tải lại trước khi lưu.",
    VALIDATION_FAILED: "Dữ liệu chưa hợp lệ. Kiểm tra chi tiết và thử lại.",
    INVARIANT_VIOLATION: "Thao tác vi phạm quy tắc vòng đời công thức.",
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
  const ingredient = ingredients.find(
    (item) => item.ingredient_id === ingredientId,
  );
  return ingredient
    ? `${ingredient.ingredient_name} (${ingredient.ingredient_code})`
    : ingredientId;
}

export function unitLabel(unitId: string, units: RecipeUnitReference[]) {
  const unit = units.find((item) => item.unit_id === unitId);
  return unit ? `${unit.unit_name} (${unit.unit_code})` : unitId;
}
