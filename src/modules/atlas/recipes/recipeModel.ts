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
  issuance_kind: "ATLAS_NATIVE" | "LEGACY_UNATTRIBUTED";
  issuer: string | null;
  issued_at: string | null;
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
  selected_recipe:
    | (NonNullable<EffectiveCompositionResult["selected_recipe"]> & {
        school_type_id: string;
        school_type_code: "v1-school-type-1" | "v1-school-type-2";
        selection_scope: "SCHOOL_TYPE";
        released_at: string;
      })
    | null;
  basis_portions: number | null;
  base_authoring: RecipeWorkflowSelection;
  effective_readiness: {
    status: "READY" | "BLOCKED";
    blockers: { code: string; message: string; [key: string]: JsonValue }[];
    warnings: { code: string; message: string }[];
  };
  editable_state: "EDITABLE_BASE" | "LOCKED_CHANGE_ORDER";
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
  school_type_code: "v1-school-type-1" | "v1-school-type-2";
  scope_name: string;
  status: "COPIED";
  source_recipe_id: string;
  source_recipe_version_id: string;
  source_selection_scope: "SCHOOL_TYPE";
  target_recipe_id: string;
  target_recipe_version_id: string;
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
  isItem: (value: unknown) => value is T,
): T[] | null {
  if (result.kind !== "success") return null;
  const value = source[key];
  if (!Array.isArray(value)) return null;
  const parsed: T[] = [];
  for (const item of value) {
    if (!isItem(item)) return null;
    parsed.push(item);
  }
  return parsed;
}

function isRecord(value: unknown): value is Record<string, JsonValue> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isNonemptyString(value: unknown): value is string {
  return typeof value === "string" && value.trim().length > 0;
}

function isNullableString(value: unknown): value is string | null {
  return typeof value === "string" || value === null;
}

function isPositiveInteger(value: unknown): value is number {
  return Number.isInteger(value) && Number(value) > 0;
}

function isPositiveNumber(value: unknown): value is number {
  return typeof value === "number" && Number.isFinite(value) && value > 0;
}

function isEffectiveLine(value: JsonValue): boolean {
  if (!isRecord(value)) return false;
  const hasRecipeLine = typeof value.target_recipe_line_id === "string";
  const hasAdjustmentLine = typeof value.adjustment_line_id === "string";
  return (
    typeof value.ingredient_id === "string" &&
    typeof value.ingredient_name === "string" &&
    typeof value.quantity_per_basis === "number" &&
    typeof value.unit_id === "string" &&
    typeof value.unit_name === "string" &&
    typeof value.target_id === "string" &&
    typeof value.source_layer === "string" &&
    ((value.target_kind === "RECIPE_LINE" &&
      hasRecipeLine &&
      value.adjustment_line_id === null &&
      value.target_id === value.target_recipe_line_id) ||
      (value.target_kind === "ADJUSTMENT_LINE" &&
        hasAdjustmentLine &&
        value.target_recipe_line_id === null &&
        value.target_id === value.adjustment_line_id))
  );
}

function isHistoryChangeOrder(value: JsonValue): boolean {
  if (!isRecord(value)) return false;
  const issuanceIsCoherent =
    (value.issuance_kind === "LEGACY_UNATTRIBUTED" &&
      value.issuer === null &&
      value.issued_at === null) ||
    (value.issuance_kind === "ATLAS_NATIVE" &&
      isNonemptyString(value.issuer) &&
      isNonemptyString(value.issued_at));
  return (
    typeof value.adjustment_id === "string" &&
    typeof value.revision_id === "string" &&
    typeof value.revision_number === "number" &&
    (value.revision_status === "ACTIVE" ||
      value.revision_status === "SUPERSEDED" ||
      value.revision_status === "CANCELLED") &&
    (value.business_event_kind === "CREATED" ||
      value.business_event_kind === "CORRECTED" ||
      value.business_event_kind === "CANCELLED") &&
    (value.scope_kind === "SYSTEM_INGREDIENT" ||
      value.scope_kind === "SYSTEM_DISH" ||
      value.scope_kind === "SCHOOL" ||
      value.scope_kind === "SCHOOL_DISH") &&
    (value.action_kind === "ADD" ||
      value.action_kind === "REPLACE" ||
      value.action_kind === "ADJUST_QUANTITY" ||
      value.action_kind === "REMOVE") &&
    typeof value.effective_from === "string" &&
    (typeof value.effective_to === "string" || value.effective_to === null) &&
    typeof value.reason_code === "string" &&
    typeof value.reason === "string" &&
    issuanceIsCoherent
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
    value.change_orders.every(isHistoryChangeOrder) &&
    Array.isArray(value.warnings) &&
    Array.isArray(value.blockers)
  );
}

function isRecipeCompositionLine(
  value: unknown,
): value is RecipeCompositionLine {
  if (!isRecord(value)) return false;
  const validDispositionQuantity =
    (value.line_disposition === "PRESENT" &&
      isPositiveNumber(value.quantity_per_basis)) ||
    (value.line_disposition === "REMOVED" &&
      value.quantity_per_basis === 0 &&
      isNonemptyString(value.predecessor_recipe_line_revision_id));
  return (
    isNonemptyString(value.recipe_line_id) &&
    (value.recipe_line_revision_id === undefined ||
      isNonemptyString(value.recipe_line_revision_id)) &&
    isNullableString(value.predecessor_recipe_line_revision_id) &&
    (value.line_revision_number === undefined ||
      isPositiveInteger(value.line_revision_number)) &&
    isNonemptyString(value.ingredient_id) &&
    validDispositionQuantity &&
    isNonemptyString(value.unit_id) &&
    isNullableString(value.operational_note) &&
    isNullableString(value.line_code) &&
    (value.legacy_line_id === undefined ||
      isNullableString(value.legacy_line_id))
  );
}

function normalizedRecipeWorkflowSelection(
  value: unknown,
  allowExactNoDishOmissions: boolean,
): RecipeWorkflowSelection | null {
  if (isRecipeWorkflowSelection(value)) return value;
  if (
    !allowExactNoDishOmissions ||
    !isRecord(value) ||
    "expected_version" in value ||
    "in_use_recipe_version_id" in value ||
    value.dish_id !== null ||
    value.school_type_id !== null ||
    value.recipe_id !== null ||
    value.recipe_version_id !== null ||
    value.business_status !== "NEEDS_ATTENTION" ||
    value.locked_for_normal_editing !== false ||
    value.lock_reason !== null ||
    value.basis_portions !== 100 ||
    !Array.isArray(value.composition) ||
    value.composition.length !== 0 ||
    !isRecord(value.allowed_actions) ||
    value.allowed_actions.save_recipe !== false ||
    value.allowed_actions.release_recipe !== false ||
    !isRecord(value.disabled_reason_codes) ||
    value.disabled_reason_codes.save_recipe !== "DISH_NOT_FOUND" ||
    value.disabled_reason_codes.release_recipe !== "DISH_NOT_FOUND" ||
    !isRecord(value.disabled_reasons) ||
    !isNonemptyString(value.disabled_reasons.save_recipe) ||
    !isNonemptyString(value.disabled_reasons.release_recipe)
  )
    return null;
  const normalized = {
    ...value,
    expected_version: null,
    in_use_recipe_version_id: null,
  };
  return isRecipeWorkflowSelection(normalized) ? normalized : null;
}

function isRecipeWorkflowSelection(
  value: unknown,
): value is RecipeWorkflowSelection {
  if (!isRecord(value)) return false;
  return (
    (typeof value.dish_id === "string" || value.dish_id === null) &&
    (typeof value.school_type_id === "string" ||
      value.school_type_id === null) &&
    (typeof value.recipe_id === "string" || value.recipe_id === null) &&
    (typeof value.recipe_version_id === "string" ||
      value.recipe_version_id === null) &&
    (isPositiveInteger(value.expected_version) ||
      value.expected_version === null) &&
    (typeof value.in_use_recipe_version_id === "string" ||
      value.in_use_recipe_version_id === null) &&
    (value.business_status === "NOT_SAVED" ||
      value.business_status === "SAVED" ||
      value.business_status === "AVAILABLE" ||
      value.business_status === "LOCKED" ||
      value.business_status === "NEEDS_ATTENTION") &&
    typeof value.locked_for_normal_editing === "boolean" &&
    (typeof value.lock_reason === "string" || value.lock_reason === null) &&
    isPositiveInteger(value.basis_portions) &&
    Array.isArray(value.composition) &&
    value.composition.every(isRecipeCompositionLine) &&
    isRecord(value.allowed_actions) &&
    typeof value.allowed_actions.save_recipe === "boolean" &&
    typeof value.allowed_actions.release_recipe === "boolean" &&
    isRecord(value.disabled_reason_codes) &&
    isNullableString(value.disabled_reason_codes.save_recipe) &&
    isNullableString(value.disabled_reason_codes.release_recipe) &&
    isRecord(value.disabled_reasons) &&
    isNullableString(value.disabled_reasons.save_recipe) &&
    isNullableString(value.disabled_reasons.release_recipe)
  );
}

function isDishTypeReference(value: unknown): value is DishTypeReference {
  if (!isRecord(value)) return false;
  return (
    isNonemptyString(value.dish_type_id) &&
    isNonemptyString(value.dish_type_code) &&
    isNonemptyString(value.dish_type_name) &&
    Array.isArray(value.source_header_aliases) &&
    value.source_header_aliases.every((alias) => typeof alias === "string") &&
    typeof value.display_order === "number" &&
    Number.isFinite(value.display_order) &&
    (value.dish_type_status === "ACTIVE" ||
      value.dish_type_status === "INACTIVE") &&
    isPositiveInteger(value.version) &&
    typeof value.created_at === "string" &&
    typeof value.updated_at === "string"
  );
}

function isDishRecord(value: unknown): value is DishRecord {
  if (!isRecord(value)) return false;
  return (
    isNonemptyString(value.dish_id) &&
    isNonemptyString(value.dish_code) &&
    isNonemptyString(value.dish_name) &&
    isNullableString(value.dish_category) &&
    isNullableString(value.dish_type_id) &&
    isNullableString(value.dish_type_code) &&
    isNullableString(value.dish_type_name) &&
    isNullableString(value.operational_notes) &&
    (value.dish_status === "DRAFT" ||
      value.dish_status === "ACTIVE" ||
      value.dish_status === "INACTIVE") &&
    typeof value.display_order === "number" &&
    Number.isFinite(value.display_order) &&
    typeof value.requires_need_generation === "boolean" &&
    isPositiveInteger(value.version) &&
    typeof value.created_at === "string" &&
    typeof value.updated_at === "string"
  );
}

function isRecipeRecord(value: unknown): value is RecipeRecord {
  if (!isRecord(value)) return false;
  return (
    isNonemptyString(value.recipe_id) &&
    isNonemptyString(value.dish_id) &&
    isNullableString(value.school_type_id) &&
    (value.recipe_status === "ACTIVE" || value.recipe_status === "INACTIVE") &&
    isPositiveInteger(value.version) &&
    typeof value.created_at === "string" &&
    typeof value.updated_at === "string"
  );
}

function isRecipeVersionRecord(value: unknown): value is RecipeVersionRecord {
  if (!isRecord(value)) return false;
  return (
    isNonemptyString(value.recipe_version_id) &&
    isNonemptyString(value.recipe_id) &&
    isPositiveInteger(value.version_number) &&
    isNullableString(value.predecessor_recipe_version_id) &&
    isPositiveInteger(value.basis_portions) &&
    (value.recipe_version_status === "DRAFT" ||
      value.recipe_version_status === "VALIDATED" ||
      value.recipe_version_status === "RELEASED_FOR_PLANNING" ||
      value.recipe_version_status === "LOCKED") &&
    isPositiveInteger(value.version) &&
    isRecord(value.source_evidence) &&
    isNonemptyString(value.created_by_actor_id) &&
    typeof value.created_at === "string" &&
    isNullableString(value.validated_by_actor_id) &&
    isNullableString(value.validated_at) &&
    isNullableString(value.released_by_actor_id) &&
    isNullableString(value.released_at) &&
    isNullableString(value.locked_by_actor_id) &&
    isNullableString(value.locked_at) &&
    Array.isArray(value.composition) &&
    value.composition.every(isRecipeCompositionLine)
  );
}

function isRecipeReference(value: unknown): value is RecipeReference {
  if (!isRecord(value)) return false;
  return (
    isNonemptyString(value.school_type_id) &&
    isNonemptyString(value.school_type_code) &&
    isNonemptyString(value.school_type_name) &&
    (value.school_type_status === "ACTIVE" ||
      value.school_type_status === "INACTIVE")
  );
}

function isRecipeIngredientReference(
  value: unknown,
): value is RecipeIngredientReference {
  if (!isRecord(value)) return false;
  return (
    isNonemptyString(value.ingredient_id) &&
    isNonemptyString(value.ingredient_code) &&
    isNonemptyString(value.ingredient_name) &&
    (value.ingredient_status === "ACTIVE" ||
      value.ingredient_status === "INACTIVE" ||
      value.ingredient_status === "ARCHIVED")
  );
}

function isRecipeUnitReference(value: unknown): value is RecipeUnitReference {
  if (!isRecord(value)) return false;
  return (
    isNonemptyString(value.unit_id) &&
    isNonemptyString(value.unit_code) &&
    isNonemptyString(value.unit_name) &&
    (value.unit_status === "ACTIVE" || value.unit_status === "INACTIVE")
  );
}

function isCopyScopeResult(value: JsonValue): boolean {
  if (!isRecord(value)) return false;
  return (
    typeof value.school_type_id === "string" &&
    (value.school_type_code === "v1-school-type-1" ||
      value.school_type_code === "v1-school-type-2") &&
    typeof value.scope_name === "string" &&
    value.status === "COPIED" &&
    typeof value.source_recipe_id === "string" &&
    typeof value.source_recipe_version_id === "string" &&
    value.source_selection_scope === "SCHOOL_TYPE" &&
    typeof value.target_recipe_id === "string" &&
    typeof value.target_recipe_version_id === "string"
  );
}

function isSelectedRecipe(
  value: JsonValue,
  dishId: string,
): value is NonNullable<DishRecipeOperatorWorkbench["selected_recipe"]> {
  if (!isRecord(value)) return false;
  return (
    value.dish_id === dishId &&
    isNonemptyString(value.school_type_id) &&
    (value.school_type_code === "v1-school-type-1" ||
      value.school_type_code === "v1-school-type-2") &&
    isNonemptyString(value.recipe_id) &&
    isNonemptyString(value.recipe_version_id) &&
    value.selection_scope === "SCHOOL_TYPE" &&
    isPositiveNumber(value.basis_portions) &&
    isNonemptyString(value.released_at)
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
  const dishes = responseArray(result, source, "dishes", isDishRecord);
  const dishTypes = responseArray<DishTypeReference>(
    result,
    source,
    "dish_types",
    isDishTypeReference,
  );
  const recipes = responseArray(result, source, "recipes", isRecipeRecord);
  const recipeVersions = responseArray<RecipeVersionRecord>(
    result,
    source,
    "recipe_versions",
    isRecipeVersionRecord,
  );
  const schoolTypes = responseArray<RecipeReference>(
    result,
    source,
    "school_types",
    isRecipeReference,
  );
  const ingredients = responseArray<RecipeIngredientReference>(
    result,
    source,
    "ingredients",
    isRecipeIngredientReference,
  );
  const units = responseArray(result, source, "units", isRecipeUnitReference);
  const selectedRecipe = normalizedRecipeWorkflowSelection(
    source.selected_recipe,
    dishes?.length === 0,
  );
  if (
    !dishTypes ||
    !dishes ||
    !recipes ||
    !recipeVersions ||
    !schoolTypes ||
    !ingredients ||
    !units ||
    !selectedRecipe
  )
    return null;
  const dishIds = new Set(dishes.map((item) => item.dish_id));
  const dishTypeIds = new Set(dishTypes.map((item) => item.dish_type_id));
  const schoolTypeIds = new Set(schoolTypes.map((item) => item.school_type_id));
  const recipeIds = new Set(recipes.map((item) => item.recipe_id));
  const ingredientIds = new Set(ingredients.map((item) => item.ingredient_id));
  const unitIds = new Set(units.map((item) => item.unit_id));
  const compositionReferencesExist = (lines: RecipeCompositionLine[]) =>
    lines.every(
      (line) =>
        ingredientIds.has(line.ingredient_id) && unitIds.has(line.unit_id),
    );
  const selectedDish =
    selectedRecipe.dish_id === null
      ? null
      : dishes.find((item) => item.dish_id === selectedRecipe.dish_id);
  const selectedRecipeRecord =
    selectedRecipe.recipe_id === null
      ? null
      : recipes.find((item) => item.recipe_id === selectedRecipe.recipe_id);
  const selectedVersion =
    selectedRecipe.recipe_version_id === null
      ? null
      : recipeVersions.find(
          (item) => item.recipe_version_id === selectedRecipe.recipe_version_id,
        );
  if (
    dishes.some(
      (item) =>
        item.dish_type_id !== null && !dishTypeIds.has(item.dish_type_id),
    ) ||
    recipes.some(
      (item) =>
        !dishIds.has(item.dish_id) ||
        (item.school_type_id !== null &&
          !schoolTypeIds.has(item.school_type_id)),
    ) ||
    recipeVersions.some(
      (item) =>
        !recipeIds.has(item.recipe_id) ||
        !compositionReferencesExist(item.composition),
    ) ||
    !compositionReferencesExist(selectedRecipe.composition) ||
    (selectedRecipe.dish_id !== null && !selectedDish) ||
    (selectedRecipe.school_type_id !== null &&
      !schoolTypeIds.has(selectedRecipe.school_type_id)) ||
    (selectedRecipe.recipe_id !== null &&
      (!selectedRecipeRecord ||
        selectedRecipeRecord.dish_id !== selectedRecipe.dish_id ||
        selectedRecipeRecord.school_type_id !==
          selectedRecipe.school_type_id)) ||
    (selectedRecipe.recipe_version_id !== null &&
      (!selectedVersion ||
        selectedVersion.recipe_id !== selectedRecipe.recipe_id))
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
    selected_recipe: selectedRecipe,
  };
}

export function dishRecipeOperatorWorkbenchFromResult(
  result: AtlasRpcResult,
): DishRecipeOperatorWorkbench | null {
  if (
    result.kind !== "success" ||
    result.response.success !== true ||
    !isRecord(result.response.workbench)
  )
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
    !(
      (source.context_kind === "SYSTEM_SCHOOL_TYPE" &&
        source.school_id === null) ||
      (source.context_kind === "SCHOOL" && typeof source.school_id === "string")
    ) ||
    !(
      source.selected_recipe === null ||
      isSelectedRecipe(source.selected_recipe, source.dish.dish_id)
    ) ||
    (typeof source.basis_portions !== "number" &&
      source.basis_portions !== null) ||
    !isRecipeWorkflowSelection(source.base_authoring) ||
    !isRecord(source.effective_readiness) ||
    (source.effective_readiness.status !== "READY" &&
      source.effective_readiness.status !== "BLOCKED") ||
    !Array.isArray(source.effective_readiness.blockers) ||
    !Array.isArray(source.effective_readiness.warnings) ||
    (source.editable_state !== "EDITABLE_BASE" &&
      source.editable_state !== "LOCKED_CHANGE_ORDER") ||
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
  const allowedActions = source.allowed_actions as JsonValue[];
  const baseAuthoring =
    source.base_authoring as unknown as RecipeWorkflowSelection;
  if (
    !allowedActions.every(
      (action) =>
        action === "CREATE_CHANGE_ORDER" || action === "COPY_DISH_RECIPES",
    ) ||
    baseAuthoring.dish_id !== source.dish.dish_id ||
    baseAuthoring.school_type_id !== source.school_type_id ||
    (source.selected_recipe !== null &&
      (source.selected_recipe.school_type_id !== source.school_type_id ||
        source.selected_recipe.school_type_id !==
          baseAuthoring.school_type_id ||
        source.selected_recipe.recipe_id !== baseAuthoring.recipe_id)) ||
    (source.editable_state === "EDITABLE_BASE" &&
      (source.is_operationally_locked ||
        (source.is_editable && !baseAuthoring.allowed_actions.save_recipe) ||
        allowedActions.includes("CREATE_CHANGE_ORDER"))) ||
    (source.editable_state === "LOCKED_CHANGE_ORDER" &&
      (!source.is_operationally_locked ||
        source.is_editable ||
        allowedActions.includes("COPY_DISH_RECIPES")))
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
    source.success !== true ||
    source.contract_version !== "RECIPE-EFFECTIVE.v1" ||
    typeof source.command_id !== "string" ||
    typeof source.correlation_id !== "string" ||
    typeof source.idempotency_status !== "string" ||
    !Array.isArray(source.scope_results) ||
    source.scope_results.length !== 2 ||
    !source.scope_results.every(isCopyScopeResult) ||
    new Set(
      source.scope_results.map((scope) =>
        isRecord(scope) ? scope.school_type_code : null,
      ),
    ).size !== 2
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
      "Món này đã xuất hiện trong thực đơn tuần đã duyệt nên toàn bộ món — gồm cả hai công thức theo loại trường — bị khóa chỉnh sửa thông thường. Muốn thay đổi thành phần, hãy dùng Lệnh điều chỉnh.",
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
