import type {
  AtlasRpcResult,
  AtlasSafeBackendError,
  AtlasSuccessEnvelope,
  JsonValue,
} from "../connection/atlasRpc";
import type { AtlasReviewScenario } from "../review/reviewMode";
import type { EffectiveTargetLine } from "../recipe-adjustments/recipeAdjustmentModel";
import type {
  DishRecipeCopyCommandRequest,
  RecipeApi,
  RecipeCommandRequest,
  RecipeWorkflowCommandRequest,
} from "./recipeApi";
import type {
  DishRecord,
  RecipeCompositionLine,
  RecipeRecord,
  RecipeVersionRecord,
  RecipeWorkbenchData,
} from "./recipeModel";
import { emptyRecipeWorkbench } from "./recipeModel";

const now = "2026-07-27T02:00:00.000Z";
const actor = "00000000-0000-4000-8000-000000000001";
const ids = {
  dish: "10000000-0000-4000-8000-000000000001",
  dish2: "10000000-0000-4000-8000-000000000002",
  recipe: "20000000-0000-4000-8000-000000000001",
  recipeSecondary: "20000000-0000-4000-8000-000000000002",
  dish2Recipe: "20000000-0000-4000-8000-000000000003",
  dish2RecipeSecondary: "20000000-0000-4000-8000-000000000004",
  version: "30000000-0000-4000-8000-000000000001",
  versionSecondary: "30000000-0000-4000-8000-000000000002",
  ingredient: "40000000-0000-4000-8000-000000000001",
  ingredient2: "40000000-0000-4000-8000-000000000002",
  ingredient3: "40000000-0000-4000-8000-000000000003",
  effectiveIngredient: "40000000-0000-4000-8000-000000000099",
  unit: "50000000-0000-4000-8000-000000000001",
  schoolType: "60000000-0000-4000-8000-000000000001",
  schoolTypeSecondary: "60000000-0000-4000-8000-000000000002",
  dishTypeSoup: "80000000-0000-4000-8000-000000000001",
  dishTypeSavory: "80000000-0000-4000-8000-000000000002",
};

function fixtures(): RecipeWorkbenchData {
  const data: RecipeWorkbenchData = {
    dish_types: [
      {
        dish_type_id: ids.dishTypeSoup,
        dish_type_code: "soup",
        dish_type_name: "Món canh",
        source_header_aliases: ["Canh"],
        display_order: 1,
        dish_type_status: "ACTIVE",
        version: 1,
        created_at: now,
        updated_at: now,
      },
      {
        dish_type_id: ids.dishTypeSavory,
        dish_type_code: "savory",
        dish_type_name: "Món mặn",
        source_header_aliases: ["Mặn"],
        display_order: 2,
        dish_type_status: "ACTIVE",
        version: 1,
        created_at: now,
        updated_at: now,
      },
    ],
    dishes: [
      {
        dish_id: ids.dish,
        dish_code: "canh-bi-do-thit-bam",
        dish_name: "Canh bí đỏ thịt bằm",
        dish_category: "Canh",
        dish_type_id: ids.dishTypeSoup,
        dish_type_code: "soup",
        dish_type_name: "Món canh",
        operational_notes: "Món mẫu để xem xét vòng đời công thức.",
        dish_status: "ACTIVE",
        display_order: 10,
        requires_need_generation: true,
        version: 1,
        created_at: now,
        updated_at: now,
      },
      {
        dish_id: ids.dish2,
        dish_code: "com-trang",
        dish_name: "Cơm trắng",
        dish_category: "Món chính",
        dish_type_id: ids.dishTypeSavory,
        dish_type_code: "savory",
        dish_type_name: "Món mặn",
        operational_notes: null,
        dish_status: "ACTIVE",
        display_order: 20,
        requires_need_generation: true,
        version: 1,
        created_at: now,
        updated_at: now,
      },
    ],
    recipes: [
      {
        recipe_id: ids.recipe,
        dish_id: ids.dish,
        school_type_id: ids.schoolType,
        recipe_status: "ACTIVE",
        version: 1,
        created_at: now,
        updated_at: now,
      },
      {
        recipe_id: ids.recipeSecondary,
        dish_id: ids.dish,
        school_type_id: ids.schoolTypeSecondary,
        recipe_status: "ACTIVE",
        version: 1,
        created_at: now,
        updated_at: now,
      },
      {
        recipe_id: ids.dish2Recipe,
        dish_id: ids.dish2,
        school_type_id: ids.schoolType,
        recipe_status: "ACTIVE",
        version: 1,
        created_at: now,
        updated_at: now,
      },
      {
        recipe_id: ids.dish2RecipeSecondary,
        dish_id: ids.dish2,
        school_type_id: ids.schoolTypeSecondary,
        recipe_status: "ACTIVE",
        version: 1,
        created_at: now,
        updated_at: now,
      },
    ],
    recipe_versions: [
      {
        recipe_version_id: ids.version,
        recipe_id: ids.recipe,
        version_number: 1,
        predecessor_recipe_version_id: null,
        basis_portions: 100,
        recipe_version_status: "RELEASED_FOR_PLANNING",
        version: 1,
        source_evidence: { source_kind: "MANUAL" },
        created_by_actor_id: actor,
        created_at: now,
        validated_by_actor_id: actor,
        validated_at: now,
        released_by_actor_id: actor,
        released_at: now,
        locked_by_actor_id: null,
        locked_at: null,
        composition: [
          {
            recipe_line_id: "70000000-0000-4000-8000-000000000001",
            predecessor_recipe_line_revision_id: null,
            ingredient_id: ids.ingredient,
            quantity_per_basis: 22.5,
            unit_id: ids.unit,
            line_disposition: "PRESENT",
            operational_note: "Cắt miếng vừa.",
            line_code: "bi-do",
          },
          {
            recipe_line_id: "70000000-0000-4000-8000-000000000002",
            predecessor_recipe_line_revision_id: null,
            ingredient_id: ids.ingredient2,
            quantity_per_basis: 8,
            unit_id: ids.unit,
            line_disposition: "PRESENT",
            operational_note: null,
            line_code: "thit-bam",
          },
        ],
      },
      {
        recipe_version_id: ids.versionSecondary,
        recipe_id: ids.recipeSecondary,
        version_number: 1,
        predecessor_recipe_version_id: null,
        basis_portions: 100,
        recipe_version_status: "RELEASED_FOR_PLANNING",
        version: 1,
        source_evidence: { source_kind: "MANUAL" },
        created_by_actor_id: actor,
        created_at: now,
        validated_by_actor_id: actor,
        validated_at: now,
        released_by_actor_id: actor,
        released_at: now,
        locked_by_actor_id: null,
        locked_at: null,
        composition: [
          {
            recipe_line_id: "70000000-0000-4000-8000-000000000003",
            predecessor_recipe_line_revision_id: null,
            ingredient_id: ids.ingredient,
            quantity_per_basis: 27,
            unit_id: ids.unit,
            line_disposition: "PRESENT",
            operational_note: "Khẩu phần Trung học.",
            line_code: "bi-do-trung-hoc",
          },
          {
            recipe_line_id: "70000000-0000-4000-8000-000000000004",
            predecessor_recipe_line_revision_id: null,
            ingredient_id: ids.ingredient2,
            quantity_per_basis: 10,
            unit_id: ids.unit,
            line_disposition: "PRESENT",
            operational_note: null,
            line_code: "thit-bam-trung-hoc",
          },
        ],
      },
    ],
    school_types: [
      {
        school_type_id: ids.schoolType,
        school_type_code: "v1-school-type-1",
        school_type_name: "TIỂU HỌC",
        school_type_status: "ACTIVE",
      },
      {
        school_type_id: ids.schoolTypeSecondary,
        school_type_code: "v1-school-type-2",
        school_type_name: "TRUNG HỌC",
        school_type_status: "ACTIVE",
      },
    ],
    ingredients: [
      {
        ingredient_id: ids.ingredient,
        ingredient_code: "bi-do",
        ingredient_name: "Bí đỏ",
        ingredient_status: "ACTIVE",
      },
      {
        ingredient_id: ids.ingredient2,
        ingredient_code: "thit-heo-xay",
        ingredient_name: "Thịt heo xay",
        ingredient_status: "ACTIVE",
      },
      {
        ingredient_id: ids.ingredient3,
        ingredient_code: "hanh-la",
        ingredient_name: "Hành lá",
        ingredient_status: "ACTIVE",
      },
      {
        ingredient_id: ids.effectiveIngredient,
        ingredient_code: "hanh-la-hieu-luc",
        ingredient_name: "Hành lá hiệu lực",
        ingredient_status: "ACTIVE",
      },
    ],
    units: [
      {
        unit_id: ids.unit,
        unit_code: "kg",
        unit_name: "Kilôgam",
        unit_status: "ACTIVE",
      },
    ],
    selected_recipe: {
      dish_id: ids.dish,
      school_type_id: ids.schoolType,
      recipe_id: ids.recipe,
      recipe_version_id: ids.version,
      expected_version: 1,
      in_use_recipe_version_id: null,
      business_status: "AVAILABLE",
      locked_for_normal_editing: false,
      lock_reason: null,
      basis_portions: 100,
      composition: [],
      allowed_actions: { save_recipe: true, release_recipe: false },
      disabled_reason_codes: {
        save_recipe: null,
        release_recipe: "RELEASE_ALREADY_IN_USE",
      },
      disabled_reasons: {
        save_recipe: null,
        release_recipe: "Công thức đã sẵn sàng sử dụng.",
      },
    },
  };
  data.selected_recipe.composition = clone(data.recipe_versions[0].composition);
  return data;
}

const clone = <T>(value: T): T => structuredClone(value);
const shapedEffectiveLines: Record<
  "basePrimary" | "systemPrimary" | "schoolPrimary" | "systemSecondary",
  EffectiveTargetLine[]
> = {
  basePrimary: [
    {
      ingredient_id: ids.ingredient,
      ingredient_name: "Bí đỏ",
      quantity_per_basis: 25,
      unit_id: ids.unit,
      unit_name: "Kilôgam",
      target_kind: "RECIPE_LINE",
      target_recipe_line_id: "70000000-0000-4000-8000-000000000001",
      adjustment_line_id: null,
      target_id: "70000000-0000-4000-8000-000000000001",
      source_layer: "RELEASED_RECIPE_VERSION",
      lineage: [],
    },
    {
      ingredient_id: ids.ingredient2,
      ingredient_name: "Thịt heo xay",
      quantity_per_basis: 8,
      unit_id: ids.unit,
      unit_name: "Kilôgam",
      target_kind: "RECIPE_LINE",
      target_recipe_line_id: "70000000-0000-4000-8000-000000000002",
      adjustment_line_id: null,
      target_id: "70000000-0000-4000-8000-000000000002",
      source_layer: "RELEASED_RECIPE_VERSION",
      lineage: [],
    },
  ],
  systemPrimary: [
    {
      ingredient_id: ids.effectiveIngredient,
      ingredient_name: "Hành lá hiệu lực",
      quantity_per_basis: 12,
      unit_id: ids.unit,
      unit_name: "Kilôgam",
      target_kind: "RECIPE_LINE" as const,
      target_recipe_line_id: "70000000-0000-4000-8000-000000000001",
      adjustment_line_id: null,
      target_id: "70000000-0000-4000-8000-000000000001",
      source_layer: "SYSTEM_INGREDIENT",
      lineage: [
        {
          adjustment_id: "90000000-0000-4000-8000-000000000090",
          revision_id: "91000000-0000-4000-8000-000000000090",
          scope_kind: "SYSTEM_INGREDIENT",
          action_kind: "REPLACE",
        },
      ],
    },
    {
      ingredient_id: ids.ingredient2,
      ingredient_name: "Thịt heo xay",
      quantity_per_basis: 8,
      unit_id: ids.unit,
      unit_name: "Kilôgam",
      target_kind: "RECIPE_LINE" as const,
      target_recipe_line_id: "70000000-0000-4000-8000-000000000002",
      adjustment_line_id: null,
      target_id: "70000000-0000-4000-8000-000000000002",
      source_layer: "RELEASED_RECIPE_VERSION",
      lineage: [],
    },
  ],
  schoolPrimary: [
    {
      ingredient_id: ids.effectiveIngredient,
      ingredient_name: "Hành lá hiệu lực",
      quantity_per_basis: 14,
      unit_id: ids.unit,
      unit_name: "Kilôgam",
      target_kind: "RECIPE_LINE" as const,
      target_recipe_line_id: "70000000-0000-4000-8000-000000000001",
      adjustment_line_id: null,
      target_id: "70000000-0000-4000-8000-000000000001",
      source_layer: "SCHOOL_DISH",
      lineage: [
        {
          adjustment_id: "90000000-0000-4000-8000-000000000001",
          revision_id: "91000000-0000-4000-8000-000000000001",
          scope_kind: "SCHOOL_DISH",
          action_kind: "ADJUST_QUANTITY",
        },
      ],
    },
    {
      ingredient_id: ids.ingredient2,
      ingredient_name: "Thịt heo xay",
      quantity_per_basis: 8,
      unit_id: ids.unit,
      unit_name: "Kilôgam",
      target_kind: "RECIPE_LINE" as const,
      target_recipe_line_id: "70000000-0000-4000-8000-000000000002",
      adjustment_line_id: null,
      target_id: "70000000-0000-4000-8000-000000000002",
      source_layer: "RELEASED_RECIPE_VERSION",
      lineage: [],
    },
  ],
  systemSecondary: [
    {
      ingredient_id: ids.ingredient,
      ingredient_name: "Bí đỏ",
      quantity_per_basis: 27,
      unit_id: ids.unit,
      unit_name: "Kilôgam",
      target_kind: "RECIPE_LINE" as const,
      target_recipe_line_id: "70000000-0000-4000-8000-000000000003",
      adjustment_line_id: null,
      target_id: "70000000-0000-4000-8000-000000000003",
      source_layer: "RELEASED_RECIPE_VERSION",
      lineage: [],
    },
  ],
};
const success = (data: Record<string, JsonValue>): AtlasRpcResult => ({
  kind: "success",
  response: { success: true, ...data } as AtlasSuccessEnvelope,
});
const backendError = (errorCode: string): AtlasRpcResult => ({
  kind: "backend_error",
  error: {
    success: false,
    error_code: errorCode,
    safe_message: "Yêu cầu xem thử đã bị từ chối an toàn.",
  } as AtlasSafeBackendError,
});
type ReviewRecipeRequest = RecipeCommandRequest | RecipeWorkflowCommandRequest;
const payloadString = (request: ReviewRecipeRequest, key: string) =>
  String(request.payload[key] ?? "");
const payloadNumber = (request: ReviewRecipeRequest, key: string) =>
  Number(request.payload[key] ?? 0);

function selectRecipe(
  data: RecipeWorkbenchData,
  dishId: string | null = data.selected_recipe.dish_id ??
    data.dishes[0]?.dish_id ??
    null,
  schoolTypeId: string | null = data.selected_recipe.school_type_id,
) {
  const dish = data.dishes.find((item) => item.dish_id === dishId);
  const recipe = data.recipes.find(
    (item) => item.dish_id === dishId && item.school_type_id === schoolTypeId,
  );
  const versions = data.recipe_versions
    .filter((item) => item.recipe_id === recipe?.recipe_id)
    .sort((left, right) => right.version_number - left.version_number);
  const version =
    versions.find((item) => item.recipe_version_status === "DRAFT") ??
    versions[0];
  const releaseReady =
    version?.recipe_version_status === "DRAFT" &&
    version.composition.some((line) => line.line_disposition === "PRESENT");
  const alreadyAvailable =
    version?.recipe_version_status === "RELEASED_FOR_PLANNING";
  const lockedForNormalEditing = false;
  data.selected_recipe = {
    dish_id: dish?.dish_id ?? null,
    school_type_id: schoolTypeId,
    recipe_id: recipe?.recipe_id ?? null,
    recipe_version_id: version?.recipe_version_id ?? null,
    expected_version: version?.version ?? dish?.version ?? null,
    in_use_recipe_version_id:
      versions.find(
        (item) => item.recipe_version_status === "RELEASED_FOR_PLANNING",
      )?.recipe_version_id ?? null,
    business_status: !version
      ? "NOT_SAVED"
      : version.recipe_version_status === "RELEASED_FOR_PLANNING"
        ? "AVAILABLE"
        : "SAVED",
    locked_for_normal_editing: lockedForNormalEditing,
    lock_reason: null,
    basis_portions: version?.basis_portions ?? 100,
    composition: clone(version?.composition ?? []),
    allowed_actions: {
      save_recipe: dish?.dish_status !== "INACTIVE",
      release_recipe: Boolean(releaseReady),
    },
    disabled_reason_codes: {
      save_recipe:
        dish?.dish_status === "INACTIVE" ? "SAVE_DISH_INACTIVE" : null,
      release_recipe: releaseReady
        ? null
        : alreadyAvailable
          ? "RELEASE_ALREADY_IN_USE"
          : "RELEASE_SAVE_REQUIRED",
    },
    disabled_reasons: {
      save_recipe:
        dish?.dish_status === "INACTIVE"
          ? "Món ăn đã ngừng dùng nên không thể lưu công thức mới."
          : null,
      release_recipe: releaseReady
        ? null
        : alreadyAvailable
          ? "Công thức đã sẵn sàng cho Lập nhu cầu."
          : "Hãy lưu công thức trước khi xác nhận cho Lập nhu cầu.",
    },
  };
}

export function createReviewRecipeApi(
  scenario: AtlasReviewScenario = "ready",
): RecipeApi {
  let data = scenario === "empty" ? emptyRecipeWorkbench() : fixtures();
  const copyResults = new Map<string, AtlasSuccessEnvelope>();
  const blockedRead = () => {
    if (scenario === "permission_denied")
      return backendError("CAPABILITY_DENIED");
    if (scenario === "session_lost")
      return backendError("AUTHENTICATION_REQUIRED");
    if (scenario === "server_error")
      return backendError("INTERNAL_READ_FAILURE");
    return null;
  };
  const blockedWrite = () =>
    scenario === "stale" ? backendError("STALE_VERSION") : blockedRead();
  const saved = () =>
    success({
      safe_operator_message:
        "Đã cập nhật dữ liệu xem thử. Thay đổi sẽ mất khi tải lại trang.",
      ...clone(data),
    });

  const mutate = (callback: (request: ReviewRecipeRequest) => boolean) => {
    return (request: ReviewRecipeRequest) => {
      const blocked = blockedWrite();
      if (blocked) return Promise.resolve(blocked);
      return Promise.resolve(
        callback(request) ? saved() : backendError("VALIDATION_FAILED"),
      );
    };
  };

  return {
    getWorkbench(_authSubject, _correlationId, selection) {
      if (scenario === "loading")
        return new Promise<AtlasRpcResult>(() => undefined);
      const blocked = blockedRead();
      if (!blocked)
        selectRecipe(
          data,
          selection?.dishId ?? data.selected_recipe.dish_id,
          selection
            ? selection.schoolTypeId
            : data.selected_recipe.school_type_id,
        );
      return Promise.resolve(blocked ?? success(clone(data)));
    },
    getEffectiveWorkbench(
      _authSubject,
      _correlationId,
      asOfDate,
      dishId,
      context,
    ) {
      if (scenario === "loading")
        return new Promise<AtlasRpcResult>(() => undefined);
      const blocked = blockedRead();
      const dish = data.dishes.find((item) => item.dish_id === dishId);
      const locked = false;
      const schoolTypeId =
        context.kind === "system" ? context.schoolTypeId : ids.schoolType;
      const recipe = data.recipes.find(
        (item) =>
          item.dish_id === dishId && item.school_type_id === schoolTypeId,
      );
      const version = data.recipe_versions.find(
        (item) =>
          item.recipe_id === recipe?.recipe_id &&
          item.recipe_version_status === "RELEASED_FOR_PLANNING",
      );
      const schoolSpecific = context.kind === "school";
      const ready = Boolean(version);
      const lines = !ready
        ? []
        : schoolTypeId === ids.schoolTypeSecondary
          ? clone(shapedEffectiveLines.systemSecondary)
          : clone(
              schoolSpecific
                ? shapedEffectiveLines.schoolPrimary
                : shapedEffectiveLines.systemPrimary,
            );
      selectRecipe(data, dishId, schoolTypeId);
      const baseAuthoring = clone(data.selected_recipe);
      const blockers = ready
        ? []
        : [
            {
              code: "RECIPE_SELECTION_BLOCKED",
              message: "Chưa có công thức đã phát hành cho loại trường này.",
            },
          ];
      return Promise.resolve(
        blocked ??
          success({
            workbench: {
              dish: {
                dish_id: dishId,
                dish_name: dish?.dish_name ?? "Món ăn xem thử",
                dish_type_name: dish?.dish_type_name ?? null,
                dish_status: dish?.dish_status ?? "ACTIVE",
              },
              context_kind:
                context.kind === "system" ? "SYSTEM_SCHOOL_TYPE" : "SCHOOL",
              as_of_date: asOfDate,
              school_id: context.kind === "school" ? context.schoolId : null,
              school_type_id: schoolTypeId,
              selected_recipe: version
                ? {
                    dish_id: dishId,
                    recipe_id: version.recipe_id,
                    recipe_version_id: version.recipe_version_id,
                    selection_scope: "SCHOOL_TYPE",
                    basis_portions: version.basis_portions,
                  }
                : null,
              basis_portions: version?.basis_portions ?? null,
              base_authoring: locked
                ? {
                    ...baseAuthoring,
                    business_status: "LOCKED",
                    locked_for_normal_editing: true,
                    lock_reason: "Món này đã có trong thực đơn đã duyệt.",
                    allowed_actions: {
                      save_recipe: false,
                      release_recipe: false,
                    },
                    disabled_reason_codes: {
                      save_recipe: "SAVE_OPERATIONALLY_LOCKED",
                      release_recipe: "RELEASE_ALREADY_IN_USE",
                    },
                    disabled_reasons: {
                      save_recipe:
                        "Muốn thay đổi công thức, hãy dùng Điều chỉnh.",
                      release_recipe: "Công thức đã sẵn sàng cho Lập nhu cầu.",
                    },
                  }
                : baseAuthoring,
              effective_readiness: {
                status: ready ? "READY" : "BLOCKED",
                blockers,
                warnings: [],
              },
              editable_state: locked ? "LOCKED_CHANGE_ORDER" : "EDITABLE_BASE",
              is_editable: !locked,
              is_operationally_locked: locked,
              current_effective_bom: lines,
              school_exception_count: schoolSpecific && ready ? 1 : 0,
              allowed_actions:
                locked && ready
                  ? ["CREATE_CHANGE_ORDER"]
                  : !locked
                    ? ["COPY_DISH_RECIPES"]
                    : [],
              blockers,
              warnings: [],
              history_periods: ready
                ? [
                    {
                      period_from: "2026-06-01",
                      period_to: "2026-07-01",
                      resolution_status: "READY",
                      effective_bom:
                        schoolTypeId === ids.schoolType && !schoolSpecific
                          ? clone(shapedEffectiveLines.basePrimary)
                          : lines,
                      change_orders: [],
                      warnings: [],
                      blockers: [],
                    },
                    {
                      period_from: "2026-07-01",
                      period_to: null,
                      resolution_status: "READY",
                      effective_bom: lines,
                      change_orders:
                        schoolTypeId === ids.schoolType && !schoolSpecific
                          ? [
                              {
                                adjustment_id:
                                  "90000000-0000-4000-8000-000000000090",
                                revision_id:
                                  "91000000-0000-4000-8000-000000000090",
                                revision_number: 1,
                                revision_status: "ACTIVE",
                                business_event_kind: "CREATED",
                                scope_kind: "SYSTEM_INGREDIENT",
                                action_kind: "REPLACE",
                                effective_from: "2026-07-01",
                                effective_to: null,
                                reason_code: "LEGACY_IMPORT",
                                reason:
                                  "Điều chỉnh nguồn cũ không có người ban hành gốc.",
                                issuer: null,
                                issued_at: null,
                              },
                            ]
                          : [],
                      warnings: [],
                      blockers: [],
                    },
                  ]
                : [],
            },
          }),
      );
    },
    createDish: mutate((request) => {
      const code =
        payloadString(request, "dish_code") || `dish-${crypto.randomUUID()}`;
      const name = payloadString(request, "dish_name");
      const dishType = data.dish_types.find(
        (item) =>
          item.dish_type_id === payloadString(request, "dish_type_id") &&
          item.dish_type_status === "ACTIVE",
      );
      if (!code || !name || !dishType) return false;
      const dishId = crypto.randomUUID();
      data.dishes.push({
        dish_id: dishId,
        dish_code: code,
        dish_name: name,
        dish_category: payloadString(request, "dish_category") || null,
        dish_type_id: dishType.dish_type_id,
        dish_type_code: dishType.dish_type_code,
        dish_type_name: dishType.dish_type_name,
        operational_notes: payloadString(request, "operational_notes") || null,
        dish_status: "ACTIVE",
        display_order: payloadNumber(request, "display_order"),
        requires_need_generation:
          request.payload.requires_need_generation !== false,
        version: 1,
        created_at: now,
        updated_at: now,
      });
      for (const schoolType of data.school_types.filter((item) =>
        ["v1-school-type-1", "v1-school-type-2"].includes(
          item.school_type_code,
        ),
      )) {
        data.recipes.push({
          recipe_id: crypto.randomUUID(),
          dish_id: dishId,
          school_type_id: schoolType.school_type_id,
          recipe_status: "ACTIVE",
          version: 1,
          created_at: now,
          updated_at: now,
        });
      }
      return true;
    }),
    updateDish: mutate((request) => {
      const dish = data.dishes.find(
        (item) => item.dish_id === payloadString(request, "dish_id"),
      );
      if (!dish) return false;
      const dishType = data.dish_types.find(
        (item) =>
          item.dish_type_id === payloadString(request, "dish_type_id") &&
          item.dish_type_status === "ACTIVE",
      );
      if (!dishType) return false;
      dish.dish_name = payloadString(request, "dish_name");
      dish.dish_category = payloadString(request, "dish_category") || null;
      dish.dish_type_id = dishType.dish_type_id;
      dish.dish_type_code = dishType.dish_type_code;
      dish.dish_type_name = dishType.dish_type_name;
      dish.operational_notes =
        payloadString(request, "operational_notes") || null;
      dish.display_order = payloadNumber(request, "display_order");
      dish.requires_need_generation =
        request.payload.requires_need_generation !== false;
      dish.version += 1;
      return true;
    }),
    setDishLifecycle: mutate((request) => {
      const dish = data.dishes.find(
        (item) => item.dish_id === payloadString(request, "dish_id"),
      );
      const status = payloadString(request, "dish_status");
      if (!dish || !["ACTIVE", "INACTIVE"].includes(status)) return false;
      dish.dish_status = status as DishRecord["dish_status"];
      dish.version += 1;
      return true;
    }),
    setRecipeLifecycle: mutate((request) => {
      const recipe = data.recipes.find(
        (item) => item.recipe_id === payloadString(request, "recipe_id"),
      );
      const status = payloadString(request, "recipe_status");
      if (!recipe || !["ACTIVE", "INACTIVE"].includes(status)) return false;
      recipe.recipe_status = status as RecipeRecord["recipe_status"];
      recipe.version += 1;
      return true;
    }),
    createDraft: mutate((request) => {
      const dishId = payloadString(request, "dish_id");
      if (!data.dishes.some((dish) => dish.dish_id === dishId)) return false;
      let recipe = data.recipes.find(
        (item) =>
          item.dish_id === dishId &&
          item.school_type_id ===
            (payloadString(request, "school_type_id") || null) &&
          item.recipe_status === "ACTIVE",
      );
      if (!recipe) {
        recipe = {
          recipe_id: crypto.randomUUID(),
          dish_id: dishId,
          school_type_id: payloadString(request, "school_type_id") || null,
          recipe_status: "ACTIVE",
          version: 1,
          created_at: now,
          updated_at: now,
        };
        data.recipes.push(recipe);
      }
      data.recipe_versions.push(
        newVersion(recipe.recipe_id, payloadNumber(request, "basis_portions")),
      );
      return true;
    }),
    createSuccessor: mutate((request) => {
      const source = data.recipe_versions.find(
        (item) =>
          item.recipe_version_id ===
          payloadString(request, "predecessor_recipe_version_id"),
      );
      if (!source) return false;
      const next = newVersion(source.recipe_id, source.basis_portions, source);
      data.recipe_versions.push(next);
      return true;
    }),
    replaceComposition: mutate((request) => {
      const version = data.recipe_versions.find(
        (item) =>
          item.recipe_version_id ===
          payloadString(request, "recipe_version_id"),
      );
      if (!version || version.recipe_version_status !== "DRAFT") return false;
      version.basis_portions = payloadNumber(request, "basis_portions");
      version.composition = clone(
        (request.payload.lines ?? []) as unknown as RecipeCompositionLine[],
      );
      version.version += 1;
      return true;
    }),
    validateVersion: mutate((request) =>
      transition(request, data.recipe_versions, "DRAFT", "VALIDATED"),
    ),
    releaseVersion: mutate((request) =>
      transition(
        request,
        data.recipe_versions,
        "VALIDATED",
        "RELEASED_FOR_PLANNING",
      ),
    ),
    saveRecipe: mutate((request) => {
      const dishId = payloadString(request, "dish_id");
      const schoolTypeId = payloadString(request, "school_type_id") || null;
      const dish = data.dishes.find((item) => item.dish_id === dishId);
      if (!dish || dish.dish_status === "INACTIVE") return false;

      let recipe = data.recipes.find(
        (item) =>
          item.dish_id === dishId && item.school_type_id === schoolTypeId,
      );
      if (!recipe) {
        recipe = {
          recipe_id: crypto.randomUUID(),
          dish_id: dishId,
          school_type_id: schoolTypeId,
          recipe_status: "ACTIVE",
          version: 1,
          created_at: now,
          updated_at: now,
        };
        data.recipes.push(recipe);
      }
      const versions = data.recipe_versions
        .filter((item) => item.recipe_id === recipe.recipe_id)
        .sort((left, right) => right.version_number - left.version_number);
      let target = versions.find(
        (item) => item.recipe_version_status === "DRAFT",
      );
      if (!target) {
        target = newVersion(
          recipe.recipe_id,
          payloadNumber(request, "basis_portions"),
          versions[0],
        );
        target.version_number = (versions[0]?.version_number ?? 0) + 1;
        data.recipe_versions.push(target);
      }
      target.basis_portions = payloadNumber(request, "basis_portions");
      target.composition = clone(
        (request.payload.lines ?? []) as unknown as RecipeCompositionLine[],
      ).map((line) => ({ ...line, line_disposition: "PRESENT" }));
      for (const prior of versions) {
        if (prior.recipe_version_status === "RELEASED_FOR_PLANNING") {
          prior.recipe_version_status = "LOCKED";
          prior.locked_by_actor_id = actor;
          prior.locked_at = now;
        }
      }
      target.recipe_version_status = "RELEASED_FOR_PLANNING";
      target.validated_by_actor_id = actor;
      target.validated_at = now;
      target.released_by_actor_id = actor;
      target.released_at = now;
      target.version += 3;
      selectRecipe(data, dishId, schoolTypeId);
      return true;
    }),
    releaseRecipe: mutate((request) => {
      const version = data.recipe_versions.find(
        (item) =>
          item.recipe_version_id ===
          payloadString(request, "recipe_version_id"),
      );
      if (!version || version.recipe_version_status !== "DRAFT") return false;
      transition(
        request as RecipeCommandRequest,
        data.recipe_versions,
        "DRAFT",
        "VALIDATED",
      );
      transition(
        request as RecipeCommandRequest,
        data.recipe_versions,
        "VALIDATED",
        "RELEASED_FOR_PLANNING",
      );
      const recipe = data.recipes.find(
        (item) => item.recipe_id === version.recipe_id,
      );
      selectRecipe(data, recipe?.dish_id, recipe?.school_type_id ?? null);
      return true;
    }),
    copyVersion: mutate((request) => {
      const source = data.recipe_versions.find(
        (item) =>
          item.recipe_version_id ===
          payloadString(request, "source_recipe_version_id"),
      );
      const targetRecipeId = payloadString(request, "target_recipe_id");
      if (!source || !data.recipes.some((r) => r.recipe_id === targetRecipeId))
        return false;
      data.recipe_versions.push(
        newVersion(targetRecipeId, source.basis_portions, source),
      );
      return true;
    }),
    copyDishRecipes(request: DishRecipeCopyCommandRequest) {
      const blocked = blockedWrite();
      if (blocked) return Promise.resolve(blocked);
      const prior = copyResults.get(request.command_id);
      if (prior) return Promise.resolve({ kind: "success", response: prior });
      const sourceDish = data.dishes.find(
        (item) => item.dish_id === request.payload.source_dish_id,
      );
      const targetDish = data.dishes.find(
        (item) => item.dish_id === request.payload.target_dish_id,
      );
      if (
        request.reason_code !== "COPY_DISH_RECIPES" ||
        !request.reason_note.trim() ||
        !sourceDish ||
        !targetDish ||
        sourceDish.dish_id === targetDish.dish_id ||
        request.expected_version !== targetDish.version
      )
        return Promise.resolve(backendError("VALIDATION_FAILED"));

      const scopeResults = data.school_types.map((schoolType) => {
        const sourceRecipe = data.recipes.find(
          (recipe) =>
            recipe.dish_id === sourceDish.dish_id &&
            recipe.school_type_id === schoolType.school_type_id &&
            recipe.recipe_status === "ACTIVE",
        );
        const sourceVersion = data.recipe_versions.find(
          (version) =>
            version.recipe_id === sourceRecipe?.recipe_id &&
            version.recipe_version_status === "RELEASED_FOR_PLANNING",
        );
        const targetRecipe = data.recipes.find(
          (recipe) =>
            recipe.dish_id === targetDish.dish_id &&
            recipe.school_type_id === schoolType.school_type_id &&
            recipe.recipe_status === "ACTIVE",
        );
        if (!sourceRecipe || !sourceVersion || !targetRecipe) return null;
        const targetVersion = newVersion(
          targetRecipe.recipe_id,
          sourceVersion.basis_portions,
          sourceVersion,
        );
        const effectiveLines =
          schoolType.school_type_id === ids.schoolType
            ? shapedEffectiveLines.systemPrimary
            : shapedEffectiveLines.systemSecondary;
        targetVersion.composition = effectiveLines.map((line) => ({
          recipe_line_id: crypto.randomUUID(),
          predecessor_recipe_line_revision_id: null,
          ingredient_id: line.ingredient_id,
          quantity_per_basis: line.quantity_per_basis,
          unit_id: line.unit_id,
          line_disposition: "PRESENT",
          operational_note: null,
          line_code: null,
        }));
        targetVersion.version_number =
          Math.max(
            0,
            ...data.recipe_versions
              .filter((item) => item.recipe_id === targetRecipe.recipe_id)
              .map((item) => item.version_number),
          ) + 1;
        targetVersion.source_evidence = {
          source_kind: "RECIPE_EFFECTIVE_COPY",
          outer_command_id: request.command_id,
          source_dish_id: sourceDish.dish_id,
          copy_as_of_date: request.payload.as_of_date,
        };
        data.recipe_versions.push(targetVersion);
        return {
          school_type_id: schoolType.school_type_id,
          school_type_code: schoolType.school_type_code,
          scope_name: schoolType.school_type_name,
          status: "COPIED",
          source_recipe_id: sourceRecipe.recipe_id,
          source_recipe_version_id: sourceVersion.recipe_version_id,
          source_selection_scope: "SCHOOL_TYPE",
          target_recipe_id: targetRecipe.recipe_id,
          target_recipe_version_id: targetVersion.recipe_version_id,
        };
      });
      if (scopeResults.length !== 2 || scopeResults.some((item) => !item))
        return Promise.resolve(backendError("VALIDATION_FAILED"));
      const response = success({
        contract_version: "RECIPE-EFFECTIVE.v1",
        command_id: request.command_id,
        correlation_id: request.correlation_id,
        idempotency_status: "COMPLETED",
        scope_results: scopeResults,
        safe_operator_message:
          "Đã mô phỏng sao chép hai công thức thành bản NHÁP.",
      });
      if (response.kind === "success")
        copyResults.set(request.command_id, response.response);
      return Promise.resolve(response);
    },
    applyImport: mutate(() => true),
  };
}

function newVersion(
  recipeId: string,
  basisPortions: number,
  source?: RecipeVersionRecord,
): RecipeVersionRecord {
  return {
    recipe_version_id: crypto.randomUUID(),
    recipe_id: recipeId,
    version_number: 1,
    predecessor_recipe_version_id: source?.recipe_version_id ?? null,
    basis_portions: basisPortions || 100,
    recipe_version_status: "DRAFT",
    version: 1,
    source_evidence: { source_kind: source ? "SUCCESSOR" : "MANUAL" },
    created_by_actor_id: actor,
    created_at: now,
    validated_by_actor_id: null,
    validated_at: null,
    released_by_actor_id: null,
    released_at: null,
    locked_by_actor_id: null,
    locked_at: null,
    composition: clone(source?.composition ?? []),
  };
}

function transition(
  request: ReviewRecipeRequest,
  versions: RecipeVersionRecord[],
  from: RecipeVersionRecord["recipe_version_status"],
  to: RecipeVersionRecord["recipe_version_status"],
) {
  const version = versions.find(
    (item) =>
      item.recipe_version_id === payloadString(request, "recipe_version_id"),
  );
  if (!version || version.recipe_version_status !== from) return false;
  version.recipe_version_status = to;
  version.version += 1;
  if (to === "VALIDATED") {
    version.validated_by_actor_id = actor;
    version.validated_at = now;
  }
  if (to === "RELEASED_FOR_PLANNING") {
    versions
      .filter(
        (item) =>
          item.recipe_version_id !== version.recipe_version_id &&
          item.recipe_id === version.recipe_id &&
          item.recipe_version_status === "RELEASED_FOR_PLANNING",
      )
      .forEach((item) => {
        item.recipe_version_status = "LOCKED";
        item.locked_by_actor_id = actor;
        item.locked_at = now;
      });
    version.released_by_actor_id = actor;
    version.released_at = now;
  }
  return true;
}
