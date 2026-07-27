import type {
  AtlasRpcResult,
  AtlasSafeBackendError,
  AtlasSuccessEnvelope,
  JsonValue,
} from "../connection/atlasRpc";
import type { AtlasReviewScenario } from "../review/reviewMode";
import type { RecipeApi, RecipeCommandRequest } from "./recipeApi";
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
  version: "30000000-0000-4000-8000-000000000001",
  ingredient: "40000000-0000-4000-8000-000000000001",
  ingredient2: "40000000-0000-4000-8000-000000000002",
  unit: "50000000-0000-4000-8000-000000000001",
  schoolType: "60000000-0000-4000-8000-000000000001",
  dishTypeSoup: "80000000-0000-4000-8000-000000000001",
  dishTypeSavory: "80000000-0000-4000-8000-000000000002",
};

function fixtures(): RecipeWorkbenchData {
  return {
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
        dish_status: "DRAFT",
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
        school_type_id: null,
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
        recipe_version_status: "DRAFT",
        version: 1,
        source_evidence: { source_kind: "MANUAL" },
        created_by_actor_id: actor,
        created_at: now,
        validated_by_actor_id: null,
        validated_at: null,
        released_by_actor_id: null,
        released_at: null,
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
    ],
    school_types: [
      {
        school_type_id: ids.schoolType,
        school_type_code: "tieu-hoc",
        school_type_name: "Tiểu học",
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
    ],
    units: [
      {
        unit_id: ids.unit,
        unit_code: "kg",
        unit_name: "Kilôgam",
        unit_status: "ACTIVE",
      },
    ],
  };
}

const clone = <T>(value: T): T => structuredClone(value);
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
const payloadString = (request: RecipeCommandRequest, key: string) =>
  String(request.payload[key] ?? "");
const payloadNumber = (request: RecipeCommandRequest, key: string) =>
  Number(request.payload[key] ?? 0);

export function createReviewRecipeApi(
  scenario: AtlasReviewScenario = "ready",
): RecipeApi {
  let data = scenario === "empty" ? emptyRecipeWorkbench() : fixtures();
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

  const mutate = (callback: (request: RecipeCommandRequest) => boolean) => {
    return (request: RecipeCommandRequest) => {
      const blocked = blockedWrite();
      if (blocked) return Promise.resolve(blocked);
      return Promise.resolve(
        callback(request) ? saved() : backendError("VALIDATION_FAILED"),
      );
    };
  };

  return {
    getWorkbench() {
      if (scenario === "loading")
        return new Promise<AtlasRpcResult>(() => undefined);
      const blocked = blockedRead();
      return Promise.resolve(blocked ?? success(clone(data)));
    },
    createDish: mutate((request) => {
      const code = payloadString(request, "dish_code");
      const name = payloadString(request, "dish_name");
      const dishType = data.dish_types.find(
        (item) =>
          item.dish_type_id === payloadString(request, "dish_type_id") &&
          item.dish_type_status === "ACTIVE",
      );
      if (!code || !name || !dishType) return false;
      data.dishes.push({
        dish_id: crypto.randomUUID(),
        dish_code: code,
        dish_name: name,
        dish_category: payloadString(request, "dish_category") || null,
        dish_type_id: dishType.dish_type_id,
        dish_type_code: dishType.dish_type_code,
        dish_type_name: dishType.dish_type_name,
        operational_notes: payloadString(request, "operational_notes") || null,
        dish_status:
          request.payload.dish_status === "ACTIVE" ? "ACTIVE" : "DRAFT",
        display_order: payloadNumber(request, "display_order"),
        requires_need_generation:
          request.payload.requires_need_generation !== false,
        version: 1,
        created_at: now,
        updated_at: now,
      });
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
  request: RecipeCommandRequest,
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
