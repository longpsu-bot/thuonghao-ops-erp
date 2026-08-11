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
  business_status: "NOT_SAVED" | "SAVED" | "IN_USE" | "NEEDS_ATTENTION";
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
