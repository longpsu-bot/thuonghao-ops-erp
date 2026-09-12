import {
  emptyRecipeAdjustmentWorkbench,
  type RecipeAdjustmentApi,
  type RecipeAdjustmentWorkbenchData,
  type RecipeAdjustmentOperatorRecord,
  type RecipeAdjustmentCommandRequest,
  type EffectiveCompositionResult,
  type EffectiveTargetContext,
  type JsonValue,
} from "../bridges/recipeAdjustment";
import {
  fixtureSuccess,
  fixtureError,
  recipeFixtureData,
} from "./recipeReviewFixtures";
export const changeOrderScenarios = [
  "EMPTY",
  "SYSTEM_DISH_CREATE",
  "SYSTEM_DISH_PREVIEW",
  "SYSTEM_DISH_SCHOOL_INSPECTION",
  "SYSTEM_DISH_ADD",
  "SYSTEM_DISH_TARGET_PRIOR_ADD",
  "SCHOOL_DISH_CREATE",
  "SCHOOL_CREATE",
  "SYSTEM_INGREDIENT_CREATE",
  "ACTION_REPLACE",
  "ACTION_ADJUST_QUANTITY",
  "ACTION_ADD",
  "ACTION_REMOVE",
  "ACTIVE",
  "SCHEDULED",
  "ACTIVE_CHANGE_SCHEDULED",
  "ACTIVE_CANCELLATION_SCHEDULED",
  "ACTIVE_RESUMED",
  "EXPIRED",
  "CANCELLED",
  "CORRECTABLE",
  "CANCELLABLE",
  "LEGACY_UNATTRIBUTED_HISTORY",
  "SUPERSEDE_PREVIEW",
  "CANCEL_DIALOG",
  "PREVIEW_BLOCKED",
  "PREVIEW_WARNING",
  "STALE",
  "UNKNOWN_CREATE",
  "UNKNOWN_SUPERSEDE",
  "UNKNOWN_CANCEL",
  "FAILED_UNKNOWN_RECOVERY",
  "SUCCESS_READBACK",
  "PERMISSION_DENIED",
  "READ_FAILURE",
  "AUTH_CHANGE_DELAYED_RESPONSE",
  "MOBILE",
] as const;
export type ChangeOrderScenario = (typeof changeOrderScenarios)[number];
export const changeDate = "2026-09-12";
export function changeOrderFixtureData(): RecipeAdjustmentWorkbenchData {
  const base = recipeFixtureData(),
    data = emptyRecipeAdjustmentWorkbench();
  data.reference_date = changeDate;
  data.scope_catalog = [
    { scope_kind: "SYSTEM_INGREDIENT", actions: ["REPLACE"] },
    {
      scope_kind: "SYSTEM_DISH",
      actions: ["ADD", "REPLACE", "ADJUST_QUANTITY", "REMOVE"],
    },
    { scope_kind: "SCHOOL", actions: ["REPLACE", "REMOVE"] },
    {
      scope_kind: "SCHOOL_DISH",
      actions: ["ADD", "REPLACE", "ADJUST_QUANTITY", "REMOVE"],
    },
  ];
  data.precedence = [
    "RELEASED_RECIPE_VERSION",
    "SYSTEM_INGREDIENT",
    "SYSTEM_DISH",
    "SCHOOL",
    "SCHOOL_DISH",
  ];
  data.school_types = base.school_types;
  data.dishes = base.dishes;
  data.ingredients = base.ingredients.map((i) => ({
    ...i,
    purchase_unit_id: "kg",
    purchase_unit_name: "Kilôgam",
  }));
  data.units = base.units;
  data.schools = [
    "Mầm non Hoa Mai",
    "Mầm non Hướng Dương",
    "Tiểu học Bình Minh",
  ].map((name, i) => ({
    school_id: `school-${i}`,
    school_name: name,
    school_type_id: i === 2 ? "scope-1" : "scope-0",
    school_status: "ACTIVE",
  }));
  data.recipe_lines = [
    {
      recipe_line_id: "base-line",
      recipe_id: "recipe-0",
      dish_id: "dish-0",
      school_type_id: "scope-0",
      line_code: null,
      ingredient_id: "ingredient-0",
      ingredient_name: "Bí đỏ",
      quantity_per_basis: 2,
      unit_id: "kg",
      unit_name: "Kilôgam",
    },
  ];
  const revision = {
    revision_id: "revision-existing",
    effective_from: "2026-09-01",
    effective_to: null,
    substitute_ingredient_id: "ingredient-3",
    quantity_per_basis: null,
    unit_id: null,
    reason_note: "Thay bí đỏ bằng cà rốt theo thực đơn",
    issued_at: "2026-09-01T02:00:00Z",
    issuance_kind: "ATLAS_NATIVE" as const,
    issued_by_actor_name: "Nguyễn Lan",
    revision_status: "ACTIVE" as const,
  };
  data.operator_rows = [
    {
      adjustment_id: "order-existing",
      version: 3,
      current_revision_id: revision.revision_id,
      current_revision_number: 3,
      can_correct: true,
      can_cancel: true,
      scope_kind: "SYSTEM_DISH",
      action_kind: "REPLACE",
      school_id: null,
      dish_id: "dish-0",
      school_type_id: "scope-0",
      target_ingredient_id: null,
      target_recipe_line_id: "base-line",
      adjustment_line_id: null,
      temporal_state: "ACTIVE",
      temporal_state_date: null,
      is_effective_now: true,
      display_revision: revision,
      content_revision: revision,
      command_revision: revision,
      history: [{ ...revision, business_event_kind: "CREATED" }],
    },
  ];
  return data;
}
export function fixtureTargets(
  date = changeDate,
  dish = "dish-0",
  school: string | null = null,
  type = "scope-0",
): EffectiveTargetContext {
  return {
    as_of_date: date,
    dish_id: dish,
    school_id: school,
    school_type_id: type,
    selected_recipe: {
      dish_id: dish,
      recipe_id: "recipe-0",
      recipe_version_id: "version-0",
      selection_scope: "SCHOOL_TYPE",
      basis_portions: 100,
    },
    basis_portions: 100,
    warnings: [],
    blockers: [],
    effective_lines: [
      {
        ingredient_id: "ingredient-0",
        ingredient_name: "Bí đỏ",
        quantity_per_basis: 2,
        unit_id: "kg",
        unit_name: "Kilôgam",
        target_kind: "RECIPE_LINE",
        target_recipe_line_id: "base-line",
        adjustment_line_id: null,
        target_id: "base-line",
        source_layer: "BASE",
      },
      {
        ingredient_id: "ingredient-2",
        ingredient_name: "Hành lá",
        quantity_per_basis: 0.2,
        unit_id: "kg",
        unit_name: "Kilôgam",
        target_kind: "ADJUSTMENT_LINE",
        target_recipe_line_id: null,
        adjustment_line_id: "prior-add-line",
        target_id: "prior-add-line",
        source_layer: "SYSTEM_DISH",
      },
    ],
  };
}
export function fixtureComposition(
  date = changeDate,
  dish = "dish-0",
  school: string | null = null,
  type = "scope-0",
): EffectiveCompositionResult {
  const t = fixtureTargets(date, dish, school, type);
  return {
    status: "READY",
    as_of_date: date,
    dish_id: dish,
    school_id: school,
    school_type_id: type,
    historical: false,
    selected_recipe: t.selected_recipe,
    warnings: [],
    blockers: [],
    lines: t.effective_lines.map((l) => ({
      selected_dish_id: dish,
      selected_recipe_id: "recipe-0",
      selected_recipe_version_id: "version-0",
      basis_portions: 100,
      base_recipe_line_id: l.target_recipe_line_id,
      base_recipe_line_revision_id: l.target_recipe_line_id
        ? "base-revision"
        : null,
      adjustment_line_id: l.adjustment_line_id,
      line_code: null,
      base_ingredient_id: l.ingredient_id,
      base_quantity_per_basis: l.quantity_per_basis,
      base_unit_id: l.unit_id,
      base_disposition: "PRESENT",
      final_ingredient_id: l.ingredient_id,
      final_quantity_per_basis: l.quantity_per_basis,
      final_unit_id: l.unit_id,
      final_disposition: "PRESENT",
      source_layer: l.source_layer,
      applied_adjustment_ids: [],
      applied_revision_ids: [],
      lineage: [],
    })),
  };
}
// Deterministic local review responses only; this fixture never invokes a hosted adapter.
export function createChangeOrderFixture(
  scenario: ChangeOrderScenario = "ACTIVE",
) {
  const data = changeOrderFixtureData();
  if (scenario === "EMPTY") data.operator_rows = [];
  const row = data.operator_rows[0];
  if (
    row &&
    [
      "SCHEDULED",
      "ACTIVE_CHANGE_SCHEDULED",
      "ACTIVE_CANCELLATION_SCHEDULED",
      "ACTIVE_RESUMED",
      "EXPIRED",
      "CANCELLED",
    ].includes(scenario)
  ) {
    row.temporal_state =
      scenario as RecipeAdjustmentOperatorRecord["temporal_state"];
    row.temporal_state_date = "2026-09-20";
    row.is_effective_now = scenario.startsWith("ACTIVE");
    row.can_correct = row.can_cancel = !["EXPIRED", "CANCELLED"].includes(
      scenario,
    );
    if (scenario === "SCHEDULED") {
      row.display_revision.effective_from = "2026-09-20";
    } else if (scenario === "EXPIRED") {
      row.display_revision.effective_to = "2026-09-10";
    } else if (scenario !== "ACTIVE_RESUMED") {
      const cancellation =
        scenario === "CANCELLED" ||
        scenario === "ACTIVE_CANCELLATION_SCHEDULED";
      const revision = {
        ...row.display_revision,
        revision_id: "scheduled-revision",
        effective_from: scenario === "CANCELLED" ? "2026-09-10" : "2026-09-20",
        issued_at: "2026-09-10T02:00:00Z",
        reason_note: cancellation
          ? "Ngừng áp dụng theo thực đơn mới"
          : "Cập nhật định lượng theo thực đơn mới",
        revision_status: cancellation
          ? ("CANCELLED" as const)
          : ("ACTIVE" as const),
      };
      row.current_revision_id = revision.revision_id;
      row.command_revision = revision;
      row.display_revision = revision;
      row.history = [
        ...row.history,
        {
          ...revision,
          business_event_kind: cancellation ? "CANCELLED" : "CORRECTED",
        },
      ];
    }
  }
  if (scenario === "LEGACY_UNATTRIBUTED_HISTORY") {
    for (const r of [
      row.display_revision,
      row.content_revision,
      ...row.history,
    ]) {
      r.issuance_kind = "LEGACY_UNATTRIBUTED";
      r.issued_at = null;
      r.issued_by_actor_name = null;
    }
  }
  const calls: { name: string; payload?: unknown }[] = [];
  let hasWritten = false;
  async function mutate(name: string, request: RecipeAdjustmentCommandRequest) {
    calls.push({ name, payload: structuredClone(request) });
    if (scenario === "STALE") return fixtureError("STALE_VERSION");
    if (scenario === "PERMISSION_DENIED")
      return fixtureError("CAPABILITY_DENIED");
    const p = request.payload,
      previous = data.operator_rows.find(
        (r) => r.adjustment_id === p.adjustment_id,
      );
    const content = {
      revision_id: String(p.revision_id),
      effective_from: String(p.effective_from),
      effective_to: (p.effective_to ?? null) as string | null,
      substitute_ingredient_id: (p.substitute_ingredient_id ?? null) as
        string | null,
      quantity_per_basis: (p.quantity_per_basis ?? null) as number | null,
      unit_id: (p.unit_id ?? null) as string | null,
      reason_note: request.reason_note,
      issued_at: "2026-09-12T02:00:00Z",
      issuance_kind: "ATLAS_NATIVE" as const,
      issued_by_actor_name: "Nguyễn Lan",
      revision_status:
        name === "cancel" ? ("CANCELLED" as const) : ("ACTIVE" as const),
    };
    const next: RecipeAdjustmentOperatorRecord = {
      ...(previous ?? changeOrderFixtureData().operator_rows[0]),
      adjustment_id: String(p.adjustment_id),
      current_revision_id: content.revision_id,
      current_revision_number: (previous?.current_revision_number ?? 0) + 1,
      version: (previous?.version ?? 0) + 1,
      scope_kind: (p.scope_kind ??
        previous?.scope_kind) as RecipeAdjustmentOperatorRecord["scope_kind"],
      action_kind: (p.action_kind ??
        previous?.action_kind) as RecipeAdjustmentOperatorRecord["action_kind"],
      school_id: (p.school_id ?? previous?.school_id ?? null) as string | null,
      school_type_id: (p.school_type_id ?? previous?.school_type_id ?? null) as
        string | null,
      dish_id: (p.dish_id ?? previous?.dish_id ?? null) as string | null,
      target_ingredient_id: (p.target_ingredient_id ??
        previous?.target_ingredient_id ??
        null) as string | null,
      target_recipe_line_id: (p.target_recipe_line_id ??
        previous?.target_recipe_line_id ??
        null) as string | null,
      adjustment_line_id: (p.adjustment_line_id ??
        previous?.adjustment_line_id ??
        null) as string | null,
      temporal_state: name === "cancel" ? "CANCELLED" : "ACTIVE",
      can_cancel: name !== "cancel",
      can_correct: name !== "cancel",
      is_effective_now: name !== "cancel",
      command_revision: content,
      display_revision: content,
      content_revision:
        name === "cancel" && previous ? previous.content_revision : content,
      history: [
        ...(previous?.history ?? []),
        {
          ...content,
          business_event_kind:
            name === "cancel"
              ? "CANCELLED"
              : previous
                ? "CORRECTED"
                : "CREATED",
        },
      ],
    };
    hasWritten = true;
    if (scenario !== "FAILED_UNKNOWN_RECOVERY")
      data.operator_rows = [
        ...data.operator_rows.filter(
          (r) => r.adjustment_id !== next.adjustment_id,
        ),
        next,
      ];
    if (
      scenario.startsWith("UNKNOWN") ||
      scenario === "FAILED_UNKNOWN_RECOVERY"
    )
      return {
        kind: "transport_error" as const,
        diagnostic: {
          code: "NETWORK_FAILURE" as const,
          safeMessage: "Fixture connection lost",
        },
      };
    return fixtureSuccess();
  }
  const api: RecipeAdjustmentApi = {
    getWorkbench: async () => {
      throw new Error("Use the operator read");
    },
    getOperatorWorkbench: async (_a, _c, date) => {
      calls.push({ name: "read", payload: date });
      if (
        scenario === "READ_FAILURE" ||
        (hasWritten && scenario === "FAILED_UNKNOWN_RECOVERY")
      )
        return fixtureError("INTERNAL_READ_FAILURE");
      if (scenario === "AUTH_CHANGE_DELAYED_RESPONSE")
        await new Promise((r) => setTimeout(r, 100));
      return fixtureSuccess({ workbench: { ...data, reference_date: date } });
    },
    getEffectiveTargetContext: async (_a, _c, date, dish, context) => {
      calls.push({ name: "targets", payload: context });
      return fixtureSuccess({
        target_context: fixtureTargets(
          date,
          dish,
          context.kind === "school" ? context.schoolId : null,
          context.kind === "system"
            ? context.schoolTypeId
            : (data.schools.find((s) => s.school_id === context.schoolId)
                ?.school_type_id ?? "scope-0"),
        ),
      });
    },
    preview: async (_a, _c, p) => {
      calls.push({ name: "preview", payload: structuredClone(p) });
      const proposal = p.proposed_adjustment as Record<string, JsonValue>;
      const before = fixtureComposition(
          String(p.as_of_date),
          String(p.dish_id),
          p.school_id ? String(p.school_id) : null,
          p.school_type_id
            ? String(p.school_type_id)
            : (data.schools.find((s) => s.school_id === p.school_id)
                ?.school_type_id ?? "scope-0"),
        ),
        after = structuredClone(before);
      const target =
        after.lines.find(
          (l) =>
            (l.base_recipe_line_id &&
              l.base_recipe_line_id === proposal.target_recipe_line_id) ||
            (l.adjustment_line_id &&
              l.adjustment_line_id === proposal.adjustment_line_id),
        ) ?? after.lines[0];
      if (proposal.action_kind === "REPLACE")
        target.final_ingredient_id = String(proposal.substitute_ingredient_id);
      if (proposal.action_kind === "REMOVE")
        target.final_disposition = "REMOVED";
      if (
        proposal.action_kind !== "ADD" &&
        (proposal.action_kind === "ADJUST_QUANTITY" ||
          proposal.quantity_per_basis)
      )
        target.final_quantity_per_basis = Number(proposal.quantity_per_basis);
      if (proposal.action_kind === "ADD")
        after.lines.push({
          ...after.lines[0],
          base_recipe_line_id: null,
          base_recipe_line_revision_id: null,
          adjustment_line_id: String(proposal.adjustment_line_id),
          final_ingredient_id: String(proposal.target_ingredient_id),
          final_quantity_per_basis: Number(proposal.quantity_per_basis),
        });
      return fixtureSuccess({
        preview: {
          as_of_date: p.as_of_date,
          school_id: p.school_id ?? null,
          school_type_id: p.school_type_id ?? null,
          dish_id: p.dish_id,
          proposed_adjustment: proposal,
          before,
          after,
          affected_line_count: 1,
          can_save: scenario !== "PREVIEW_BLOCKED",
          blockers:
            scenario === "PREVIEW_BLOCKED"
              ? [
                  {
                    code: "DUPLICATE",
                    message: "Nguyên liệu bị trùng trong công thức.",
                  },
                ]
              : [],
          warnings:
            scenario === "PREVIEW_WARNING"
              ? [
                  {
                    code: "WARNING",
                    message: "Có lệnh khác áp dụng sau giai đoạn này.",
                  },
                ]
              : [],
        },
      });
    },
    resolve: async (_a, _c, p) => {
      calls.push({ name: "resolve", payload: p });
      return fixtureSuccess({
        resolution: fixtureComposition(
          String(p.as_of_date),
          String(p.dish_id),
          String(p.school_id),
          data.schools.find((s) => s.school_id === p.school_id)
            ?.school_type_id ?? "scope-0",
        ),
      });
    },
    resolveSystem: async (_a, _c, date, dish, type) => {
      calls.push({ name: "resolveSystem" });
      return fixtureSuccess({
        resolution: fixtureComposition(date, dish, null, type),
      });
    },
    create: (r) => mutate("create", r),
    supersede: (r) => mutate("supersede", r),
    cancel: (r) => mutate("cancel", r),
  };
  return { api, data, calls };
}
