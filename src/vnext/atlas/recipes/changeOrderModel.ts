import type {
  EffectiveTargetContext,
  EffectiveTargetLine,
  JsonValue,
  RecipeAdjustmentAction,
  RecipeAdjustmentOperatorRecord,
  RecipeAdjustmentScope,
  RecipeAdjustmentTemporalState,
  RecipeAdjustmentWorkbenchData,
} from "../bridges/recipeAdjustment";
import { canonicalScopes, parseQuantity } from "./recipeDraftModel";
import { foldVietnameseSearch } from "../foldVietnameseSearch";

export type ChangeDraft = {
  object: "recipe" | "ingredient";
  audience: "all" | "one";
  action: RecipeAdjustmentAction | "";
  dishId: string;
  schoolId: string;
  schoolTypeId: string;
  ingredientId: string;
  targetKey: string;
  substituteId: string;
  quantity: string;
  replaceQuantity: boolean;
  effectiveFrom: string;
  effectiveTo: string;
  reason: string;
  previewSchoolId: string;
  previewDishId: string;
  adjustmentId: string;
  revisionId: string;
  addLineId: string;
};
export const actionLabels: Record<RecipeAdjustmentAction, string> = {
  ADD: "Thêm nguyên liệu",
  REPLACE: "Thay nguyên liệu",
  ADJUST_QUANTITY: "Đổi định lượng",
  REMOVE: "Bỏ nguyên liệu",
};
export const scopeLabels: Record<RecipeAdjustmentScope, string> = {
  SYSTEM_DISH: "Một món · tất cả trường",
  SCHOOL_DISH: "Một món · một trường",
  SYSTEM_INGREDIENT: "Một nguyên liệu · tất cả trường",
  SCHOOL: "Một nguyên liệu · một trường",
};
export const temporalLabels: Record<RecipeAdjustmentTemporalState, string> = {
  ACTIVE: "Đang hiệu lực",
  SCHEDULED: "Sắp hiệu lực",
  ACTIVE_CHANGE_SCHEDULED: "Đang hiệu lực · có thay đổi sắp tới",
  ACTIVE_CANCELLATION_SCHEDULED: "Đang hiệu lực · đã lên lịch hủy",
  ACTIVE_RESUMED: "Đang hiệu lực · áp dụng lại nội dung trước",
  EXPIRED: "Đã kết thúc",
  CANCELLED: "Đã hủy",
};
export function vietnamLocalDate(value = new Date()) {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: "Asia/Ho_Chi_Minh",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(value);
  const part = (type: Intl.DateTimeFormatPartTypes) =>
    parts.find((p) => p.type === type)?.value;
  return `${part("year")}-${part("month")}-${part("day")}`;
}
export function scopeFromDecisions(
  object: ChangeDraft["object"],
  audience: ChangeDraft["audience"],
): RecipeAdjustmentScope {
  return object === "recipe"
    ? audience === "all"
      ? "SYSTEM_DISH"
      : "SCHOOL_DISH"
    : audience === "all"
      ? "SYSTEM_INGREDIENT"
      : "SCHOOL";
}
const matrix: Record<RecipeAdjustmentScope, RecipeAdjustmentAction[]> = {
  SYSTEM_DISH: ["ADD", "REPLACE", "ADJUST_QUANTITY", "REMOVE"],
  SCHOOL_DISH: ["ADD", "REPLACE", "ADJUST_QUANTITY", "REMOVE"],
  SCHOOL: ["REPLACE", "REMOVE"],
  SYSTEM_INGREDIENT: ["REPLACE"],
};
export function actionsFor(
  scope: RecipeAdjustmentScope,
  data: RecipeAdjustmentWorkbenchData,
) {
  return matrix[scope].filter((a) =>
    data.scope_catalog.find((s) => s.scope_kind === scope)?.actions.includes(a),
  );
}
export function newChangeDraft(date = vietnamLocalDate()): ChangeDraft {
  return {
    object: "recipe",
    audience: "all",
    action: "",
    dishId: "",
    schoolId: "",
    schoolTypeId: "",
    ingredientId: "",
    targetKey: "",
    substituteId: "",
    quantity: "",
    replaceQuantity: false,
    effectiveFrom: date,
    effectiveTo: "",
    reason: "",
    previewSchoolId: "",
    previewDishId: "",
    adjustmentId: crypto.randomUUID(),
    revisionId: crypto.randomUUID(),
    addLineId: crypto.randomUUID(),
  };
}
export const targetKey = (line: EffectiveTargetLine) =>
  `${line.target_kind}:${line.target_id}`;
export function correctionDraft(
  row: RecipeAdjustmentOperatorRecord,
): ChangeDraft {
  const r = row.command_revision;
  return {
    ...newChangeDraft(r.effective_from),
    object: row.scope_kind.endsWith("DISH") ? "recipe" : "ingredient",
    audience: row.school_id ? "one" : "all",
    action: row.action_kind,
    adjustmentId: row.adjustment_id,
    addLineId: row.adjustment_line_id ?? crypto.randomUUID(),
    dishId: row.dish_id ?? "",
    schoolId: row.school_id ?? "",
    schoolTypeId: row.school_type_id ?? "",
    ingredientId: row.target_ingredient_id ?? "",
    targetKey: row.target_recipe_line_id
      ? `RECIPE_LINE:${row.target_recipe_line_id}`
      : row.adjustment_line_id
        ? `ADJUSTMENT_LINE:${row.adjustment_line_id}`
        : "",
    substituteId: r.substitute_ingredient_id ?? "",
    quantity: r.quantity_per_basis?.toString() ?? "",
    replaceQuantity:
      row.action_kind === "REPLACE" && r.quantity_per_basis !== null,
    effectiveTo: r.effective_to ?? "",
    reason: r.reason_note,
  };
}
export function impactContext(
  d: ChangeDraft,
  data: RecipeAdjustmentWorkbenchData,
) {
  const scope = scopeFromDecisions(d.object, d.audience);
  const schoolId = d.audience === "one" ? d.schoolId : d.previewSchoolId;
  return {
    system: scope === "SYSTEM_DISH",
    dishId: d.object === "recipe" ? d.dishId : d.previewDishId,
    schoolId,
    schoolTypeId:
      scope === "SYSTEM_DISH"
        ? d.schoolTypeId
        : (data.schools.find((s) => s.school_id === schoolId)?.school_type_id ??
          ""),
  };
}
export function purchaseIngredient(
  d: ChangeDraft,
  data: RecipeAdjustmentWorkbenchData,
) {
  return data.ingredients.find(
    (i) =>
      i.ingredient_id ===
      (d.action === "ADD" ? d.ingredientId : d.substituteId),
  );
}
export const needsQuantity = (d: ChangeDraft) =>
  d.action === "ADD" ||
  d.action === "ADJUST_QUANTITY" ||
  (d.action === "REPLACE" && d.replaceQuantity);
export function proposalFor(
  d: ChangeDraft,
  data: RecipeAdjustmentWorkbenchData,
  targets: EffectiveTargetContext | null,
  editing?: RecipeAdjustmentOperatorRecord | null,
): Record<string, JsonValue> {
  const line = targets?.effective_lines.find(
    (l) => targetKey(l) === d.targetKey,
  );
  const ingredientTarget = d.object === "ingredient" || d.action === "ADD";
  return {
    adjustment_id: d.adjustmentId,
    revision_id: d.revisionId,
    revision_number: editing ? editing.current_revision_number + 1 : 1,
    scope_kind: scopeFromDecisions(d.object, d.audience),
    action_kind: d.action,
    school_id: d.audience === "one" ? d.schoolId : null,
    dish_id: d.object === "recipe" ? d.dishId : null,
    school_type_id:
      d.object === "recipe" && d.audience === "all" ? d.schoolTypeId : null,
    target_ingredient_id: ingredientTarget ? d.ingredientId : null,
    target_recipe_line_id: ingredientTarget
      ? null
      : (line?.target_recipe_line_id ?? editing?.target_recipe_line_id ?? null),
    adjustment_line_id:
      d.action === "ADD"
        ? d.addLineId
        : ingredientTarget
          ? null
          : (line?.adjustment_line_id ?? editing?.adjustment_line_id ?? null),
    substitute_ingredient_id: d.action === "REPLACE" ? d.substituteId : null,
    quantity_per_basis: needsQuantity(d) ? parseQuantity(d.quantity) : null,
    unit_id:
      d.action === "ADD" || (d.action === "REPLACE" && d.replaceQuantity)
        ? (purchaseIngredient(d, data)?.purchase_unit_id ?? null)
        : null,
    effective_from: d.effectiveFrom,
    effective_to: d.effectiveTo || null,
    reason_code: editing ? "RULE_CORRECTION" : "OPERATOR_RULE",
    reason_note: d.reason.trim(),
    source_evidence: { source_kind: "ATLAS_OPERATOR" },
  };
}
export function previewRequest(
  d: ChangeDraft,
  data: RecipeAdjustmentWorkbenchData,
  proposal: Record<string, JsonValue>,
  editing?: RecipeAdjustmentOperatorRecord | null,
): Record<string, JsonValue> {
  const c = impactContext(d, data);
  return {
    as_of_date: d.effectiveFrom,
    dish_id: c.dishId,
    ...(c.system
      ? { school_type_id: c.schoolTypeId }
      : { school_id: c.schoolId }),
    ...(editing ? { replaces_adjustment_id: editing.adjustment_id } : {}),
    proposed_adjustment: proposal,
  };
}
export function commandPayload(
  d: ChangeDraft,
  data: RecipeAdjustmentWorkbenchData,
  proposal: Record<string, JsonValue>,
  editing?: RecipeAdjustmentOperatorRecord | null,
): Record<string, JsonValue> {
  const c = impactContext(d, data);
  return {
    ...proposal,
    as_of_date: d.effectiveFrom,
    preview_dish_id: c.dishId,
    ...(c.system
      ? { preview_school_type_id: c.schoolTypeId }
      : { preview_school_id: c.schoolId }),
    predecessor_revision_id: editing?.current_revision_id ?? null,
  };
}
export function validDate(value: string) {
  return (
    /^\d{4}-\d{2}-\d{2}$/.test(value) &&
    Number.isFinite(Date.parse(value)) &&
    new Date(value).toISOString().slice(0, 10) === value
  );
}
export function validChangeDraft(
  d: ChangeDraft,
  data: RecipeAdjustmentWorkbenchData,
  targets: EffectiveTargetContext | null,
  editing?: RecipeAdjustmentOperatorRecord | null,
) {
  const c = impactContext(d, data),
    scope = scopeFromDecisions(d.object, d.audience);
  const activeIngredient = (id: string) =>
    data.ingredients.some(
      (i) => i.ingredient_id === id && i.ingredient_status === "ACTIVE",
    );
  const line = targets?.effective_lines.find(
    (l) => targetKey(l) === d.targetKey,
  );
  const fixedTarget = Boolean(
    editing?.can_correct &&
    targets &&
    editing.adjustment_id === d.adjustmentId &&
    editing.scope_kind === scope &&
    editing.action_kind === d.action &&
    (editing.target_recipe_line_id
      ? d.targetKey === `RECIPE_LINE:${editing.target_recipe_line_id}`
      : editing.adjustment_line_id &&
        d.targetKey === `ADJUSTMENT_LINE:${editing.adjustment_line_id}`),
  );
  return Boolean(
    d.action &&
    actionsFor(scope, data).includes(d.action) &&
    d.reason.trim() &&
    validDate(d.effectiveFrom) &&
    (!d.effectiveTo ||
      (validDate(d.effectiveTo) && d.effectiveTo > d.effectiveFrom)) &&
    data.dishes.some(
      (r) => r.dish_id === c.dishId && r.dish_status === "ACTIVE",
    ) &&
    (c.system
      ? changeSchoolTypes(data).some((s) => s.school_type_id === c.schoolTypeId)
      : data.schools.some(
          (s) =>
            s.school_id === c.schoolId &&
            s.school_status === "ACTIVE" &&
            s.school_type_id,
        )) &&
    (d.object === "ingredient" || d.action === "ADD"
      ? activeIngredient(d.ingredientId)
      : fixedTarget ||
        (line &&
          !targets?.blockers.length &&
          Boolean(line.target_recipe_line_id) !==
            Boolean(line.adjustment_line_id))) &&
    (d.action !== "REPLACE" || activeIngredient(d.substituteId)) &&
    (!needsQuantity(d) || parseQuantity(d.quantity) !== null) &&
    (!(d.action === "ADD" || (d.action === "REPLACE" && d.replaceQuantity)) ||
      data.units.some(
        (u) =>
          u.unit_id === purchaseIngredient(d, data)?.purchase_unit_id &&
          u.unit_status === "ACTIVE",
      )),
  );
}
export function rowFacts(
  row: RecipeAdjustmentOperatorRecord,
  data: RecipeAdjustmentWorkbenchData,
) {
  const names = [
    data.dishes.find((d) => d.dish_id === row.dish_id)?.dish_name,
    data.schools.find((s) => s.school_id === row.school_id)?.school_name,
    data.school_types.find(
      (s) =>
        s.school_type_id ===
        (row.school_type_id ??
          data.schools.find((s) => s.school_id === row.school_id)
            ?.school_type_id),
    )?.school_type_name,
  ];
  const targetId = targetIngredientId(row, data);
  names.push(
    data.ingredients.find((i) => i.ingredient_id === targetId)?.ingredient_name,
    data.ingredients.find(
      (i) => i.ingredient_id === row.content_revision.substitute_ingredient_id,
    )?.ingredient_name,
  );
  return names.filter((n): n is string => Boolean(n));
}
export function ledgerRows(
  data: RecipeAdjustmentWorkbenchData,
  query: string,
  temporal: string,
  scope: string,
) {
  const priority = (r: RecipeAdjustmentOperatorRecord) =>
    r.temporal_state === "ACTIVE_CHANGE_SCHEDULED" ||
    r.temporal_state === "ACTIVE_CANCELLATION_SCHEDULED"
      ? 0
      : r.is_effective_now
        ? 1
        : r.temporal_state === "SCHEDULED"
          ? 2
          : 3;
  return data.operator_rows
    .filter(
      (r) =>
        (!scope || r.scope_kind === scope) &&
        (temporal === "all" ||
          (temporal === "current"
            ? r.is_effective_now || r.temporal_state === "SCHEDULED"
            : temporal === "active"
              ? r.is_effective_now
              : r.temporal_state === temporal)) &&
        foldVietnameseSearch(
          [
            ...rowFacts(r, data),
            ...r.history.map(
              (h) =>
                `${h.reason_note} ${h.issuance_kind === "ATLAS_NATIVE" ? (h.issued_by_actor_name ?? "") : ""}`,
            ),
          ].join(" "),
        ).includes(foldVietnameseSearch(query)),
    )
    .sort((a, b) => priority(a) - priority(b));
}
export const formatDate = (value: string) =>
  value.split("-").reverse().join("/");
export const periodLabel = (from: string, to: string | null) =>
  `${formatDate(from)} · ${to ? `đến trước ${formatDate(to)}` : "không thời hạn"}`;

export function changeSchoolTypes(data: RecipeAdjustmentWorkbenchData) {
  return canonicalScopes(
    data.school_types.flatMap((s) =>
      s.school_type_id &&
      s.school_type_code &&
      s.school_type_status === "ACTIVE"
        ? [
            {
              school_type_id: s.school_type_id,
              school_type_code: s.school_type_code,
              school_type_name: s.school_type_name ?? "",
              school_type_status: "ACTIVE" as const,
            },
          ]
        : [],
    ),
  );
}

export function targetIngredientId(
  row: RecipeAdjustmentOperatorRecord,
  data: RecipeAdjustmentWorkbenchData,
) {
  return (
    row.target_ingredient_id ??
    data.recipe_lines.find(
      (l) => l.recipe_line_id === row.target_recipe_line_id,
    )?.ingredient_id ??
    data.operator_rows.find(
      (r) =>
        r.action_kind === "ADD" &&
        r.adjustment_line_id === row.adjustment_line_id,
    )?.target_ingredient_id
  );
}
