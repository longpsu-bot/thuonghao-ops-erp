import {
  emptyRecipeWorkbench,
  type AtlasRpcResult,
  type DishRecipeApi,
  type DishRecipeOperatorWorkbench,
  type JsonValue,
  type RecipeCompositionLine,
  type RecipeVersionRecord,
  type RecipeWorkbenchData,
  type RecipeWorkbookReview,
} from "../bridges/dishRecipe";

export const recipeScenarios = [
  "EMPTY_CATALOG",
  "DISH_ACTIVE_EDITABLE",
  "DISH_ACTIVE_LOCKED",
  "DISH_INACTIVE",
  "DISH_DRAFT_LEGACY",
  "DISH_CREATE",
  "DISH_EDIT",
  "DISH_NAME_CONFLICT",
  "DISH_LIFECYCLE",
  "RECIPE_EMPTY_SCOPE",
  "RECIPE_READY_BASE",
  "RECIPE_DIRTY",
  "RECIPE_INVALID_BASIS",
  "RECIPE_INVALID_QUANTITY",
  "RECIPE_DUPLICATE_INGREDIENT",
  "RECIPE_EFFECTIVE_DIFFERS_FROM_BASE",
  "RECIPE_EFFECTIVE_BLOCKED",
  "RECIPE_OPERATIONALLY_LOCKED",
  "SAVE_SUCCESS",
  "SAVE_STALE",
  "SAVE_UNKNOWN",
  "SAVE_SUCCESS_READBACK_FAILURE",
  "COPY_ELIGIBLE",
  "COPY_INELIGIBLE",
  "COPY_SUCCESS",
  "COPY_UNKNOWN",
  "IMPORT_VALID",
  "IMPORT_WITH_ERRORS",
  "IMPORT_SUCCESS",
  "IMPORT_UNKNOWN",
  "PERMISSION_DENIED",
  "READ_FAILURE",
  "AUTH_CHANGE_DELAYED_RESPONSE",
] as const;
export type RecipeScenario = (typeof recipeScenarios)[number];
export const recipeFixtureDate = "2026-09-12";
export const fixtureSuccess = (value: object = {}): AtlasRpcResult => ({
  kind: "success",
  response: { success: true, ...structuredClone(value) } as {
    success: true;
    [key: string]: JsonValue;
  },
});
export const fixtureError = (code: string): AtlasRpcResult => ({
  kind: "backend_error",
  error: {
    success: false,
    error_code: code,
    safe_message: "Yêu cầu chưa được thực hiện.",
    write_certainty: "NO_WRITE",
  },
});
const now = "2026-09-12T02:00:00Z";
export function recipeFixtureData(): RecipeWorkbenchData {
  const data = emptyRecipeWorkbench();
  data.dish_types = ["Món canh", "Món mặn", "Loại món cũ"].map((name, i) => ({
    dish_type_id: `type-${i}`,
    dish_type_code: `hidden-type-${i}`,
    dish_type_name: name,
    source_header_aliases: [],
    display_order: i,
    dish_type_status: i === 2 ? "INACTIVE" : "ACTIVE",
    version: 1,
    created_at: now,
    updated_at: now,
  }));
  data.school_types = ["Khối nhỏ", "Khối lớn"].map((name, i) => ({
    school_type_id: `scope-${i}`,
    school_type_code: `v1-school-type-${i + 1}`,
    school_type_name: name,
    school_type_status: "ACTIVE",
  }));
  data.ingredients = [
    "Bí đỏ",
    "Thịt heo",
    "Hành lá",
    "Cà rốt",
    "Nguyên liệu cũ",
  ].map((name, i) => ({
    ingredient_id: `ingredient-${i}`,
    ingredient_code: `hidden-ingredient-${i}`,
    ingredient_name: name,
    ingredient_status: i === 4 ? "INACTIVE" : "ACTIVE",
  }));
  data.units = [
    {
      unit_id: "kg",
      unit_code: "hidden-kg",
      unit_name: "Kilôgam",
      unit_status: "ACTIVE",
    },
    {
      unit_id: "old-unit",
      unit_code: "hidden-old",
      unit_name: "Đơn vị cũ",
      unit_status: "INACTIVE",
    },
  ];
  data.dishes = [
    "Canh bí đỏ thịt bằm",
    "Thịt heo kho",
    "Canh rau củ",
    "Đậu sốt cà chua",
    "Cá kho gừng",
    "Canh cải xanh",
    "Trứng hấp",
    "Gà xào nấm",
    "Canh khoai mỡ",
    "Thịt rim",
    "Rau củ luộc",
    "Cơm trắng",
  ].map((name, i) => ({
    dish_id: `dish-${i}`,
    dish_code: `hidden-dish-${i}`,
    dish_name: name,
    dish_category: i % 2 ? "Món chính" : "Canh",
    dish_type_id: `type-${i % 2}`,
    dish_type_code: `hidden-type-${i % 2}`,
    dish_type_name: i % 2 ? "Món mặn" : "Món canh",
    operational_notes: null,
    dish_status: i === 3 ? "INACTIVE" : i === 4 ? "DRAFT" : "ACTIVE",
    display_order: i,
    requires_need_generation: true,
    version: 7,
    created_at: now,
    updated_at: now,
  }));
  for (const dish of data.dishes)
    for (const scope of data.school_types) {
      const id = `${dish.dish_id}-${scope.school_type_id}`;
      data.recipes.push({
        recipe_id: id,
        dish_id: dish.dish_id,
        school_type_id: scope.school_type_id,
        recipe_status: "ACTIVE",
        version: 1,
        created_at: now,
        updated_at: now,
      });
      data.recipe_versions.push(
        versionFor(id, [
          {
            recipe_line_id: `${id}-line`,
            predecessor_recipe_line_revision_id: null,
            ingredient_id: "ingredient-0",
            quantity_per_basis: 22.5,
            unit_id: "kg",
            line_disposition: "PRESENT",
            operational_note: "Cắt miếng vừa",
            line_code: null,
          },
        ]),
      );
    }
  return data;
}
function versionFor(
  recipeId: string,
  lines: RecipeCompositionLine[],
): RecipeVersionRecord {
  return {
    recipe_id: recipeId,
    recipe_version_id: `${recipeId}-version`,
    version_number: 1,
    predecessor_recipe_version_id: null,
    basis_portions: 80,
    recipe_version_status: "RELEASED_FOR_PLANNING",
    version: 3,
    source_evidence: {},
    created_by_actor_id: "fixture-actor",
    created_at: now,
    validated_by_actor_id: "fixture-actor",
    validated_at: now,
    released_by_actor_id: "fixture-actor",
    released_at: now,
    locked_by_actor_id: null,
    locked_at: null,
    composition: lines,
  };
}
export function createRecipeReviewFixture(
  scenario: RecipeScenario = "DISH_ACTIVE_EDITABLE",
) {
  const data = recipeFixtureData();
  const locked = ["DISH_ACTIVE_LOCKED", "RECIPE_OPERATIONALLY_LOCKED"].includes(
    scenario,
  );
  let wrote = false;
  let sequence = 0;
  if (scenario === "EMPTY_CATALOG") {
    data.dishes = [];
    data.recipes = [];
    data.recipe_versions = [];
  }
  if (scenario === "RECIPE_EMPTY_SCOPE")
    data.recipe_versions = data.recipe_versions.filter(
      (v) => !v.recipe_id.startsWith("dish-0-"),
    );
  if (scenario === "DISH_INACTIVE") data.dishes[0].dish_status = "INACTIVE";
  if (scenario === "DISH_DRAFT_LEGACY") data.dishes[0].dish_status = "DRAFT";
  if (scenario === "RECIPE_DUPLICATE_INGREDIENT")
    data.recipe_versions[0].composition.push({
      ...data.recipe_versions[0].composition[0],
      recipe_line_id: "duplicate-fixture-line",
    });
  const selection = (dishId: string, scopeId: string) => {
    const root = data.recipes.find(
      (r) => r.dish_id === dishId && r.school_type_id === scopeId,
    );
    const version = data.recipe_versions
      .filter((v) => v.recipe_id === root?.recipe_id)
      .at(-1);
    const dish = data.dishes.find((d) => d.dish_id === dishId)!;
    return {
      ...emptyRecipeWorkbench().selected_recipe,
      dish_id: dishId,
      school_type_id: scopeId,
      recipe_id: root?.recipe_id ?? null,
      recipe_version_id: version?.recipe_version_id ?? null,
      expected_version: version?.version ?? dish.version,
      basis_portions: version?.basis_portions ?? 100,
      composition: version?.composition ?? [],
      business_status: locked
        ? ("LOCKED" as const)
        : !version
          ? ("NOT_SAVED" as const)
          : version.recipe_version_status === "DRAFT"
            ? ("SAVED" as const)
            : ("AVAILABLE" as const),
      locked_for_normal_editing: locked,
      allowed_actions: {
        save_recipe: !locked && dish.dish_status === "ACTIVE",
        release_recipe: false,
      },
    };
  };
  const readFailure = () =>
    scenario === "READ_FAILURE" ||
    (wrote && scenario === "SAVE_SUCCESS_READBACK_FAILURE");
  const api: DishRecipeApi = {
    async getWorkbench(_subject, _correlation, selected) {
      if (scenario === "AUTH_CHANGE_DELAYED_RESPONSE")
        await new Promise((resolve) => setTimeout(resolve, 200));
      if (scenario === "PERMISSION_DENIED")
        return fixtureError("CAPABILITY_DENIED");
      if (readFailure()) return fixtureError("INTERNAL_READ_FAILURE");
      return fixtureSuccess({
        workbench: {
          ...data,
          selected_recipe: selected
            ? selection(selected.dishId, selected.schoolTypeId!)
            : emptyRecipeWorkbench().selected_recipe,
        },
      });
    },
    async getEffectiveWorkbench(_subject, _correlation, date, dishId, context) {
      if (readFailure() || context.kind !== "system")
        return fixtureError("INTERNAL_READ_FAILURE");
      const base = selection(dishId, context.schoolTypeId);
      const dish = data.dishes.find((d) => d.dish_id === dishId)!;
      const ready = base.business_status === "AVAILABLE" || locked;
      const workbench: DishRecipeOperatorWorkbench = {
        dish,
        context_kind: "SYSTEM_SCHOOL_TYPE",
        as_of_date: date,
        school_id: null,
        school_type_id: context.schoolTypeId,
        selected_recipe: ready
          ? {
              dish_id: dishId,
              school_type_id: context.schoolTypeId,
              school_type_code:
                context.schoolTypeId === "scope-0"
                  ? "v1-school-type-1"
                  : "v1-school-type-2",
              recipe_id: base.recipe_id!,
              recipe_version_id: base.recipe_version_id!,
              basis_portions: base.basis_portions,
              selection_scope: "SCHOOL_TYPE",
              released_at: now,
            }
          : null,
        basis_portions: ready ? base.basis_portions : null,
        base_authoring: base,
        effective_readiness: {
          status:
            ready && scenario !== "RECIPE_EFFECTIVE_BLOCKED"
              ? "READY"
              : "BLOCKED",
          blockers: [
            {
              code: "FIXTURE_BLOCKER",
              message: "Chưa có công thức hiệu lực cho ngày này.",
            },
          ],
          warnings: [],
        },
        editable_state: locked ? "LOCKED_CHANGE_ORDER" : "EDITABLE_BASE",
        is_editable: base.allowed_actions.save_recipe,
        is_operationally_locked: locked,
        current_effective_bom: base.composition.map((l) => ({
          target_id: l.recipe_line_id,
          target_kind: "RECIPE_LINE",
          target_recipe_line_id: l.recipe_line_id,
          adjustment_line_id: null,
          ingredient_id:
            scenario === "RECIPE_EFFECTIVE_DIFFERS_FROM_BASE"
              ? "ingredient-3"
              : l.ingredient_id,
          ingredient_name:
            scenario === "RECIPE_EFFECTIVE_DIFFERS_FROM_BASE"
              ? "Cà rốt"
              : "Bí đỏ",
          quantity_per_basis:
            scenario === "RECIPE_EFFECTIVE_DIFFERS_FROM_BASE"
              ? 19
              : l.quantity_per_basis,
          unit_id: l.unit_id,
          unit_name: "Kilôgam",
          source_layer: "BASE_RECIPE",
        })),
        school_exception_count: 0,
        allowed_actions:
          locked || scenario === "COPY_INELIGIBLE" ? [] : ["COPY_DISH_RECIPES"],
        blockers: [],
        warnings: [],
        history_periods: [],
      };
      return fixtureSuccess({ workbench });
    },
    async saveRecipe(request) {
      if (scenario === "SAVE_STALE") return fixtureError("STALE_VERSION");
      if (scenario === "SAVE_UNKNOWN")
        return {
          kind: "transport_error",
          diagnostic: { code: "NETWORK_FAILURE", safeMessage: "Unknown" },
        };
      const root = data.recipes.find(
        (r) =>
          r.dish_id === request.payload.dish_id &&
          r.school_type_id === request.payload.school_type_id,
      )!;
      const version = versionFor(
        root.recipe_id,
        (request.payload.lines as unknown as RecipeCompositionLine[]).map(
          (l) => ({
            ...l,
            predecessor_recipe_line_revision_id: null,
            line_disposition: "PRESENT",
            line_code: null,
          }),
        ),
      );
      version.recipe_version_id += `-saved-${++sequence}`;
      version.basis_portions = Number(request.payload.basis_portions);
      version.version = request.expected_version + 1;
      data.recipe_versions.push(version);
      wrote = true;
      return fixtureSuccess({ command_id: request.command_id });
    },
    async createDish(request) {
      if (scenario === "DISH_NAME_CONFLICT") return fixtureError("CONFLICT");
      const id = `new-dish-${++sequence}`;
      const template = recipeFixtureData().dishes[0];
      data.dishes.push({
        ...template,
        dish_id: id,
        dish_code: `generated-${id}`,
        dish_name: String(request.payload.dish_name),
        dish_type_id: String(request.payload.dish_type_id),
        dish_category: String(request.payload.dish_category ?? ""),
        operational_notes: String(request.payload.operational_notes ?? ""),
        version: 1,
      });
      for (const scope of data.school_types)
        data.recipes.push({
          recipe_id: `${id}-${scope.school_type_id}`,
          dish_id: id,
          school_type_id: scope.school_type_id,
          recipe_status: "ACTIVE",
          version: 1,
          created_at: now,
          updated_at: now,
        });
      return fixtureSuccess({ affected_aggregate_ids: { dish_id: id } });
    },
    async updateDish(request) {
      const dish = data.dishes.find(
        (d) => d.dish_id === request.payload.dish_id,
      )!;
      Object.assign(dish, request.payload, { version: dish.version + 1 });
      return fixtureSuccess({
        affected_aggregate_ids: { dish_id: dish.dish_id },
      });
    },
    async setDishLifecycle(request) {
      const dish = data.dishes.find(
        (d) => d.dish_id === request.payload.dish_id,
      )!;
      dish.dish_status = request.payload.dish_status as typeof dish.dish_status;
      dish.version++;
      return fixtureSuccess({
        affected_aggregate_ids: { dish_id: dish.dish_id },
      });
    },
    async copyDishRecipes(request) {
      if (scenario === "COPY_UNKNOWN")
        return {
          kind: "transport_error",
          diagnostic: { code: "NETWORK_FAILURE", safeMessage: "Unknown" },
        };
      const results = data.school_types.map((scope) => {
        const source = selection(
          request.payload.source_dish_id,
          scope.school_type_id,
        );
        const target = selection(
          request.payload.target_dish_id,
          scope.school_type_id,
        );
        const version = versionFor(
          target.recipe_id!,
          structuredClone(source.composition).map((l) => ({
            ...l,
            recipe_line_id: `${target.recipe_id}-${l.ingredient_id}`,
          })),
        );
        version.recipe_version_id += `-copied-${++sequence}`;
        version.recipe_version_status = "DRAFT";
        version.source_evidence = {
          source_kind: "RECIPE_EFFECTIVE_COPY",
          outer_command_id: request.command_id,
          source_dish_id: request.payload.source_dish_id,
          copy_as_of_date: request.payload.as_of_date,
        };
        data.recipe_versions.push(version);
        return {
          school_type_id: scope.school_type_id,
          school_type_code: scope.school_type_code,
          scope_name: scope.school_type_name,
          status: "COPIED",
          source_recipe_id: source.recipe_id,
          source_recipe_version_id: source.recipe_version_id,
          source_selection_scope: "SCHOOL_TYPE",
          target_recipe_id: target.recipe_id,
          target_recipe_version_id: version.recipe_version_id,
        };
      });
      return fixtureSuccess({
        contract_version: "RECIPE-EFFECTIVE.v1",
        command_id: request.command_id,
        correlation_id: request.correlation_id,
        idempotency_status: "APPLIED",
        scope_results: results,
      });
    },
    async applyImport(request) {
      if (scenario === "IMPORT_UNKNOWN")
        return {
          kind: "transport_error",
          diagnostic: { code: "NETWORK_FAILURE", safeMessage: "Unknown" },
        };
      const rows = (
        JSON.parse(String(request.payload.canonical_json)) as {
          rows: RecipeWorkbookReview["rows"];
        }
      ).rows;
      for (const legacyId of new Set(rows.map((row) => row.recipe_legacy_id))) {
        const group = rows.filter((row) => row.recipe_legacy_id === legacyId),
          first = group[0];
        let dish = data.dishes.find((d) => d.dish_name === first.dish_name);
        if (!dish) {
          dish = {
            ...recipeFixtureData().dishes[0],
            dish_id: `import-dish-${++sequence}`,
            dish_code: first.dish_code,
            dish_name: first.dish_name,
            dish_status: "DRAFT",
          };
          data.dishes.push(dish);
        }
        let root = data.recipes.find(
          (r) =>
            r.dish_id === dish.dish_id &&
            r.school_type_id === first.school_type_id,
        );
        if (!root) {
          root = {
            recipe_id: `import-recipe-${++sequence}`,
            dish_id: dish.dish_id,
            school_type_id: first.school_type_id,
            recipe_status: "ACTIVE",
            version: 1,
            created_at: now,
            updated_at: now,
          };
          data.recipes.push(root);
        }
        const version = versionFor(
          root.recipe_id,
          group.map((row) => ({
            recipe_line_id: `import-line-${row.legacy_line_id}`,
            predecessor_recipe_line_revision_id: null,
            ingredient_id: row.ingredient_id,
            quantity_per_basis: row.quantity_per_basis,
            unit_id: row.unit_id,
            line_disposition: "PRESENT",
            operational_note: row.operational_note,
            line_code: null,
          })),
        );
        version.recipe_version_id += `-import-${++sequence}`;
        version.recipe_version_status = "DRAFT";
        version.basis_portions = first.basis_portions;
        version.source_evidence = {
          source_kind: "WORKBOOK_IMPORT",
          workbook_checksum: String(request.payload.workbook_checksum),
          recipe_legacy_id: legacyId,
        };
        data.recipe_versions.push(version);
      }
      return fixtureSuccess();
    },
  };
  return { api, data };
}
