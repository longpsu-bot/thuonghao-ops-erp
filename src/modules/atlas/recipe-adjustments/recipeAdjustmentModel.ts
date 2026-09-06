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
  purchase_unit_id?: string | null;
  purchase_unit_name?: string | null;
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
  revision_status: "ACTIVE" | "SUPERSEDED" | "CANCELLED";
  business_event_kind: "CREATED" | "CORRECTED" | "CANCELLED";
  effective_from: string;
  effective_to: string | null;
  substitute_ingredient_id: string | null;
  quantity_per_basis: number | null;
  unit_id: string | null;
  reason_note: string;
  issued_at: string | null;
  issuance_kind: "ATLAS_NATIVE" | "LEGACY_UNATTRIBUTED";
  issued_by_actor_name: string | null;
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
  is_effective_now: boolean;
  display_revision: RecipeAdjustmentOperatorRevision;
  content_revision: RecipeAdjustmentOperatorRevision;
  command_revision: RecipeAdjustmentOperatorRevision;
  history: RecipeAdjustmentOperatorRevision[];
};

export type EffectiveTargetLine = {
  ingredient_id: string;
  ingredient_name: string;
  quantity_per_basis: number;
  unit_id: string;
  unit_name: string;
  target_kind: "RECIPE_LINE" | "ADJUSTMENT_LINE";
  target_recipe_line_id: string | null;
  adjustment_line_id: string | null;
  target_id: string;
  source_layer: string;
  lineage?: Record<string, JsonValue>[];
};

export type EffectiveTargetContext = {
  as_of_date: string;
  dish_id: string;
  school_id: string | null;
  school_type_id: string | null;
  selected_recipe: EffectiveCompositionResult["selected_recipe"];
  basis_portions: number | null;
  effective_lines: EffectiveTargetLine[];
  warnings: { code: string; message: string }[];
  blockers: { code: string; message: string; [key: string]: JsonValue }[];
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
  school_id: string | null;
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

function isNullableString(value: JsonValue | undefined) {
  return typeof value === "string" || value === null;
}

function isNonEmptyString(value: JsonValue | undefined) {
  return typeof value === "string" && value.trim().length > 0;
}

function isNullableNonEmptyString(value: JsonValue | undefined) {
  return value === null || isNonEmptyString(value);
}

function isPositiveInteger(value: JsonValue | undefined) {
  return typeof value === "number" && Number.isInteger(value) && value > 0;
}

function isPositiveNumber(value: JsonValue | undefined) {
  return typeof value === "number" && Number.isFinite(value) && value > 0;
}

function isAdjustmentScope(
  value: JsonValue | undefined,
): value is RecipeAdjustmentScope {
  return (
    value === "SYSTEM_INGREDIENT" ||
    value === "SYSTEM_DISH" ||
    value === "SCHOOL" ||
    value === "SCHOOL_DISH"
  );
}

function isAdjustmentAction(
  value: JsonValue | undefined,
): value is RecipeAdjustmentAction {
  return (
    value === "ADD" ||
    value === "REPLACE" ||
    value === "ADJUST_QUANTITY" ||
    value === "REMOVE"
  );
}

const contractActionsByScope: Record<
  RecipeAdjustmentScope,
  RecipeAdjustmentAction[]
> = {
  SYSTEM_INGREDIENT: ["REPLACE"],
  SYSTEM_DISH: ["ADD", "REPLACE", "ADJUST_QUANTITY", "REMOVE"],
  SCHOOL: ["REPLACE", "REMOVE"],
  SCHOOL_DISH: ["ADD", "REPLACE", "ADJUST_QUANTITY", "REMOVE"],
};

function isScopeCatalog(value: JsonValue | undefined) {
  if (!Array.isArray(value) || value.length !== 4) return false;
  const scopes = new Set<RecipeAdjustmentScope>();
  for (const row of value) {
    if (!isRecord(row) || !isAdjustmentScope(row.scope_kind)) return false;
    const actions = row.actions;
    if (!Array.isArray(actions) || !actions.every(isAdjustmentAction))
      return false;
    const expectedActions = contractActionsByScope[row.scope_kind];
    if (
      actions.length !== expectedActions.length ||
      new Set(actions).size !== expectedActions.length ||
      !expectedActions.every((action) => actions.includes(action)) ||
      scopes.has(row.scope_kind)
    )
      return false;
    scopes.add(row.scope_kind);
  }
  return scopes.size === 4;
}

function isPrecedence(value: JsonValue | undefined) {
  const expected = [
    "RELEASED_RECIPE_VERSION",
    "SYSTEM_INGREDIENT",
    "SYSTEM_DISH",
    "SCHOOL",
    "SCHOOL_DISH",
  ];
  return (
    Array.isArray(value) &&
    value.length === expected.length &&
    value.every((item, index) => item === expected[index])
  );
}

function isSchoolReference(value: JsonValue) {
  return (
    isRecord(value) &&
    isNonEmptyString(value.school_id) &&
    isNonEmptyString(value.school_name) &&
    isNonEmptyString(value.school_type_id)
  );
}

function isDishReference(value: JsonValue) {
  return (
    isRecord(value) &&
    isNonEmptyString(value.dish_id) &&
    isNonEmptyString(value.dish_name)
  );
}

function isSchoolTypeReference(value: JsonValue) {
  return (
    isRecord(value) &&
    isNonEmptyString(value.school_type_id) &&
    isNonEmptyString(value.school_type_name)
  );
}

function isIngredientReference(value: JsonValue) {
  if (
    !isRecord(value) ||
    !isNonEmptyString(value.ingredient_id) ||
    !isNonEmptyString(value.ingredient_name) ||
    !isNullableNonEmptyString(value.purchase_unit_id) ||
    !isNullableNonEmptyString(value.purchase_unit_name)
  )
    return false;
  return (
    (value.purchase_unit_id === null && value.purchase_unit_name === null) ||
    (isNonEmptyString(value.purchase_unit_id) &&
      isNonEmptyString(value.purchase_unit_name))
  );
}

function isUnitReference(value: JsonValue) {
  return (
    isRecord(value) &&
    isNonEmptyString(value.unit_id) &&
    isNonEmptyString(value.unit_name)
  );
}

function isRecipeLineReference(value: JsonValue) {
  return (
    isRecord(value) &&
    isNonEmptyString(value.recipe_line_id) &&
    isNonEmptyString(value.recipe_id) &&
    isNonEmptyString(value.dish_id) &&
    isNullableNonEmptyString(value.school_type_id) &&
    isNullableNonEmptyString(value.line_code) &&
    isNonEmptyString(value.ingredient_id) &&
    isNonEmptyString(value.ingredient_name) &&
    isPositiveNumber(value.quantity_per_basis) &&
    isNonEmptyString(value.unit_id) &&
    isNonEmptyString(value.unit_name)
  );
}

function isMessage(value: JsonValue): boolean {
  return (
    isRecord(value) &&
    typeof value.code === "string" &&
    typeof value.message === "string"
  );
}

function isSelectedRecipe(value: JsonValue | undefined): boolean {
  if (value === null) return true;
  return (
    isRecord(value) &&
    typeof value.dish_id === "string" &&
    typeof value.recipe_id === "string" &&
    typeof value.recipe_version_id === "string" &&
    (value.selection_scope === "SCHOOL_TYPE" ||
      value.selection_scope === "GENERAL") &&
    typeof value.basis_portions === "number"
  );
}

function isEffectiveTargetLine(value: JsonValue): boolean {
  if (!isRecord(value)) return false;
  const isRecipeLine = value.target_kind === "RECIPE_LINE";
  const stableIdentityMatches = isRecipeLine
    ? typeof value.target_recipe_line_id === "string" &&
      value.adjustment_line_id === null &&
      value.target_id === value.target_recipe_line_id
    : value.target_kind === "ADJUSTMENT_LINE" &&
      value.target_recipe_line_id === null &&
      typeof value.adjustment_line_id === "string" &&
      value.target_id === value.adjustment_line_id;
  return (
    typeof value.ingredient_id === "string" &&
    typeof value.ingredient_name === "string" &&
    typeof value.quantity_per_basis === "number" &&
    typeof value.unit_id === "string" &&
    typeof value.unit_name === "string" &&
    typeof value.target_id === "string" &&
    typeof value.source_layer === "string" &&
    stableIdentityMatches
  );
}

function isEffectiveCompositionLine(value: JsonValue): boolean {
  return (
    isRecord(value) &&
    typeof value.selected_dish_id === "string" &&
    typeof value.selected_recipe_id === "string" &&
    typeof value.selected_recipe_version_id === "string" &&
    typeof value.basis_portions === "number" &&
    isNullableString(value.base_recipe_line_id) &&
    isNullableString(value.base_recipe_line_revision_id) &&
    isNullableString(value.adjustment_line_id) &&
    isNullableString(value.line_code) &&
    isNullableString(value.base_ingredient_id) &&
    (typeof value.base_quantity_per_basis === "number" ||
      value.base_quantity_per_basis === null) &&
    isNullableString(value.base_unit_id) &&
    (value.base_disposition === "PRESENT" ||
      value.base_disposition === "REMOVED" ||
      value.base_disposition === null) &&
    typeof value.final_ingredient_id === "string" &&
    typeof value.final_quantity_per_basis === "number" &&
    typeof value.final_unit_id === "string" &&
    (value.final_disposition === "PRESENT" ||
      value.final_disposition === "REMOVED") &&
    typeof value.source_layer === "string" &&
    Array.isArray(value.applied_adjustment_ids) &&
    value.applied_adjustment_ids.every((item) => typeof item === "string") &&
    Array.isArray(value.applied_revision_ids) &&
    value.applied_revision_ids.every((item) => typeof item === "string") &&
    Array.isArray(value.lineage)
  );
}

function isEffectiveComposition(value: JsonValue | undefined): boolean {
  return (
    isRecord(value) &&
    (value.status === "READY" || value.status === "BLOCKED") &&
    typeof value.as_of_date === "string" &&
    isNullableString(value.school_id) &&
    typeof value.dish_id === "string" &&
    typeof value.historical === "boolean" &&
    isSelectedRecipe(value.selected_recipe) &&
    Array.isArray(value.lines) &&
    value.lines.every(isEffectiveCompositionLine) &&
    Array.isArray(value.warnings) &&
    value.warnings.every(isMessage) &&
    Array.isArray(value.blockers) &&
    value.blockers.every(isMessage)
  );
}

function isOperatorRevision(value: JsonValue | undefined): boolean {
  return (
    isRecord(value) &&
    isNonEmptyString(value.revision_id) &&
    (value.revision_status === "ACTIVE" ||
      value.revision_status === "SUPERSEDED" ||
      value.revision_status === "CANCELLED") &&
    (value.business_event_kind === "CREATED" ||
      value.business_event_kind === "CORRECTED" ||
      value.business_event_kind === "CANCELLED") &&
    typeof value.effective_from === "string" &&
    isNullableString(value.effective_to) &&
    isNullableNonEmptyString(value.substitute_ingredient_id) &&
    (typeof value.quantity_per_basis === "number" ||
      value.quantity_per_basis === null) &&
    isNullableNonEmptyString(value.unit_id) &&
    typeof value.reason_note === "string" &&
    isNullableString(value.issued_at) &&
    (value.issuance_kind === "ATLAS_NATIVE" ||
      value.issuance_kind === "LEGACY_UNATTRIBUTED") &&
    isNullableString(value.issued_by_actor_name)
  );
}

function isOperatorRecord(value: JsonValue): boolean {
  if (!isRecord(value)) return false;
  const temporalStates: RecipeAdjustmentTemporalState[] = [
    "ACTIVE",
    "SCHEDULED",
    "ACTIVE_CHANGE_SCHEDULED",
    "ACTIVE_CANCELLATION_SCHEDULED",
    "ACTIVE_RESUMED",
    "EXPIRED",
    "CANCELLED",
  ];
  return (
    isNonEmptyString(value.adjustment_id) &&
    isPositiveInteger(value.version) &&
    isNonEmptyString(value.current_revision_id) &&
    isPositiveInteger(value.current_revision_number) &&
    typeof value.can_correct === "boolean" &&
    typeof value.can_cancel === "boolean" &&
    (value.scope_kind === "SYSTEM_INGREDIENT" ||
      value.scope_kind === "SYSTEM_DISH" ||
      value.scope_kind === "SCHOOL" ||
      value.scope_kind === "SCHOOL_DISH") &&
    (value.action_kind === "ADD" ||
      value.action_kind === "REPLACE" ||
      value.action_kind === "ADJUST_QUANTITY" ||
      value.action_kind === "REMOVE") &&
    isNullableNonEmptyString(value.school_id) &&
    isNullableNonEmptyString(value.dish_id) &&
    isNullableNonEmptyString(value.school_type_id) &&
    isNullableNonEmptyString(value.target_ingredient_id) &&
    isNullableNonEmptyString(value.target_recipe_line_id) &&
    isNullableNonEmptyString(value.adjustment_line_id) &&
    temporalStates.includes(
      value.temporal_state as RecipeAdjustmentTemporalState,
    ) &&
    isNullableString(value.temporal_state_date) &&
    typeof value.is_effective_now === "boolean" &&
    isOperatorRevision(value.display_revision) &&
    isOperatorRevision(value.content_revision) &&
    isOperatorRevision(value.command_revision) &&
    Array.isArray(value.history) &&
    value.history.every(isOperatorRevision)
  );
}

export function adjustmentWorkbenchFromResult(
  result: AtlasRpcResult,
): RecipeAdjustmentWorkbenchData | null {
  if (result.kind !== "success") return null;
  const source = result.response.workbench;
  if (!isRecord(source)) return null;
  if (
    typeof source.reference_date !== "string" ||
    !isScopeCatalog(source.scope_catalog) ||
    !isPrecedence(source.precedence) ||
    !Array.isArray(source.schools) ||
    !source.schools.every(isSchoolReference) ||
    !Array.isArray(source.dishes) ||
    !source.dishes.every(isDishReference) ||
    !Array.isArray(source.school_types) ||
    !source.school_types.every(isSchoolTypeReference) ||
    !Array.isArray(source.ingredients) ||
    !source.ingredients.every(isIngredientReference) ||
    !Array.isArray(source.units) ||
    !source.units.every(isUnitReference) ||
    !Array.isArray(source.recipe_lines) ||
    !source.recipe_lines.every(isRecipeLineReference) ||
    !Array.isArray(source.operator_rows) ||
    !source.operator_rows.every(isOperatorRecord)
  )
    return null;
  return source as unknown as RecipeAdjustmentWorkbenchData;
}

export function effectiveCompositionFromResult(
  result: AtlasRpcResult,
): EffectiveCompositionResult | null {
  if (result.kind !== "success" || !isRecord(result.response.resolution))
    return null;
  const source = result.response.resolution;
  if (!isEffectiveComposition(source)) return null;
  return source as unknown as EffectiveCompositionResult;
}

export function effectiveTargetContextFromResult(
  result: AtlasRpcResult,
): EffectiveTargetContext | null {
  if (result.kind !== "success" || !isRecord(result.response.target_context))
    return null;
  const source = result.response.target_context;
  if (
    typeof source.as_of_date !== "string" ||
    typeof source.dish_id !== "string" ||
    !isNullableString(source.school_id) ||
    typeof source.school_type_id !== "string" ||
    !isSelectedRecipe(source.selected_recipe) ||
    (isRecord(source.selected_recipe) &&
      source.selected_recipe.selection_scope !== "SCHOOL_TYPE") ||
    !Array.isArray(source.effective_lines) ||
    !source.effective_lines.every(isEffectiveTargetLine) ||
    (source.effective_lines.length > 0 && source.selected_recipe === null) ||
    !Array.isArray(source.warnings) ||
    !source.warnings.every(isMessage) ||
    !Array.isArray(source.blockers) ||
    !source.blockers.every(isMessage) ||
    (typeof source.basis_portions !== "number" &&
      source.basis_portions !== null)
  )
    return null;
  return source as unknown as EffectiveTargetContext;
}

export function adjustmentPreviewFromResult(
  result: AtlasRpcResult,
): RecipeAdjustmentPreview | null {
  if (result.kind !== "success" || !isRecord(result.response.preview))
    return null;
  const source = result.response.preview;
  const before = source.before;
  const after = source.after;
  if (!isEffectiveComposition(before) || !isEffectiveComposition(after))
    return null;
  const beforeComposition = before as unknown as EffectiveCompositionResult;
  const afterComposition = after as unknown as EffectiveCompositionResult;
  if (
    typeof source.as_of_date !== "string" ||
    typeof source.school_id !== "string" ||
    typeof source.dish_id !== "string" ||
    !isRecord(source.proposed_adjustment) ||
    beforeComposition.as_of_date !== source.as_of_date ||
    afterComposition.as_of_date !== source.as_of_date ||
    beforeComposition.school_id !== source.school_id ||
    afterComposition.school_id !== source.school_id ||
    beforeComposition.dish_id !== source.dish_id ||
    afterComposition.dish_id !== source.dish_id ||
    typeof source.affected_line_count !== "number" ||
    !Number.isInteger(source.affected_line_count) ||
    source.affected_line_count < 0 ||
    typeof source.can_save !== "boolean" ||
    !Array.isArray(source.warnings) ||
    !source.warnings.every(isMessage) ||
    !Array.isArray(source.blockers) ||
    !source.blockers.every(isMessage)
  )
    return null;
  return source as unknown as RecipeAdjustmentPreview;
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
