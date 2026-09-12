import type {
  AtlasRpcResult,
  IngredientMasterData,
  IngredientSupplierMasterDataApi,
  SupplierMasterData,
} from "../bridges/ingredientSupplierMasterData";

export const ingredientSupplierScenarios = [
  "INGREDIENTS_DENSE_360",
  "SUPPLIERS_37",
  "INGREDIENT_ACTIVE",
  "INGREDIENT_INACTIVE",
  "INGREDIENT_ARCHIVED",
  "INGREDIENT_CURRENT_INACTIVE_TYPE",
  "INGREDIENT_CURRENT_INACTIVE_GROUP",
  "INGREDIENT_CURRENT_INACTIVE_UNIT",
  "INGREDIENT_CREATE",
  "INGREDIENT_DIRTY",
  "INGREDIENT_INVALID",
  "INGREDIENT_REVIEW",
  "INGREDIENT_STALE",
  "INGREDIENT_UNKNOWN",
  "PRIORITY_NONE",
  "PRIORITY_ONE",
  "PRIORITY_SIX",
  "PRIORITY_DUPLICATE_SUPPLIER",
  "PRIORITY_DUPLICATE_RANK",
  "PRIORITY_INACTIVE_SUPPLIER",
  "PRIORITY_EMPTY_REPLACEMENT",
  "SUPPLIER_ACTIVE",
  "SUPPLIER_INACTIVE",
  "SUPPLIER_SUSPENDED",
  "SUPPLIER_CREATE",
  "SUPPLIER_DIRTY",
  "SUPPLIER_UNKNOWN",
  "LIFECYCLE_DEACTIVATE",
  "LIFECYCLE_REACTIVATE",
  "LIFECYCLE_ARCHIVE",
  "READ_FAILURE",
  "PERMISSION_DENIED",
  "SUCCESS_THEN_READBACK_FAILURE",
] as const;
export type IngredientSupplierScenario =
  (typeof ingredientSupplierScenarios)[number];

const supplierNames = [
  "NCC Minh Tâm",
  "NCC Hoàng Dung",
  "Thực phẩm An Phú",
  "Nông sản Bình Minh",
  "Rau sạch Củ Chi",
  "Gia vị Phương Nam",
];
export const ingredientSupplierFixtureSuppliers: SupplierMasterData[] =
  Array.from({ length: 37 }, (_, index) => ({
    supplier_id: `supplier-${String(index + 1).padStart(2, "0")}`,
    supplier_code: `NCC-${String(index + 1).padStart(3, "0")}`,
    supplier_name: supplierNames[index] ?? `Nhà cung ứng khu vực ${index + 1}`,
    supplier_status:
      index === 1 ? "INACTIVE" : index === 2 ? "SUSPENDED" : "ACTIVE",
    contact_name: index % 4 === 0 ? `Anh/Chị ${index + 1}` : null,
    contact_phone:
      index % 3 === 0 ? `090000${String(index).padStart(4, "0")}` : null,
    contact_email: index % 5 === 0 ? `ncc${index + 1}@example.test` : null,
    version: 2 + (index % 4),
  }));

const ingredientNames = [
  "Rau muống",
  "Cà rốt Đà Lạt",
  "Thịt heo nạc",
  "Cá basa phi lê",
  "Gạo thơm lài",
  "Nước mắm nhĩ",
  "Bí đỏ hồ lô",
  "Hành lá",
];
export const ingredientSupplierFixtureIngredients: IngredientMasterData[] =
  Array.from({ length: 360 }, (_, index) => {
    const priorityCount =
      index === 8 ? 6 : index % 9 === 0 ? 2 : index % 4 === 0 ? 1 : 0;
    const inactiveCatalog = index === 1;
    return {
      ingredient_id: `ingredient-${String(index + 1).padStart(3, "0")}`,
      ingredient_code: `NL-${String(index + 1).padStart(4, "0")}`,
      ingredient_name:
        ingredientNames[index] ??
        `Nguyên liệu sơ chế ${String(index + 1).padStart(3, "0")}`,
      ingredient_status:
        index === 1 ? "INACTIVE" : index === 2 ? "ARCHIVED" : "ACTIVE",
      ingredient_type_id: inactiveCatalog
        ? "type-inactive"
        : `type-${(index % 3) + 1}`,
      ingredient_type_name: inactiveCatalog
        ? "Phân loại lịch sử"
        : ["Rau củ", "Thịt cá", "Thực phẩm khô"][index % 3]!,
      ingredient_order_group_id: inactiveCatalog
        ? "group-inactive"
        : `group-${(index % 2) + 1}`,
      ingredient_order_group_name: inactiveCatalog
        ? "Nhóm lịch sử"
        : index % 2
          ? "Hàng ngày"
          : "Hàng đặt trước",
      ingredient_type: inactiveCatalog
        ? "Phân loại lịch sử"
        : ["Rau củ", "Thịt cá", "Thực phẩm khô"][index % 3]!,
      shopping_type: inactiveCatalog
        ? "Nhóm lịch sử"
        : index % 2
          ? "Hàng ngày"
          : "Hàng đặt trước",
      purchase_unit_id: inactiveCatalog
        ? "unit-inactive"
        : index % 3 === 0
          ? "unit-kg"
          : "unit-pack",
      purchase_unit_code: inactiveCatalog
        ? "OLD"
        : index % 3 === 0
          ? "KG"
          : "PACK",
      purchase_unit_name: inactiveCatalog
        ? "Đơn vị lịch sử"
        : index % 3 === 0
          ? "Kilôgam"
          : "Gói",
      order_step: index % 3 === 0 ? 0.5 : index % 3 === 1 ? 1 : 2.5,
      version: 2 + (index % 7),
      supplier_priorities: Array.from(
        { length: priorityCount },
        (_, priorityIndex) => {
          const supplier =
            index === 8
              ? ingredientSupplierFixtureSuppliers.filter(
                  (candidate) => candidate.supplier_status === "ACTIVE",
                )[priorityIndex]!
              : ingredientSupplierFixtureSuppliers[priorityIndex]!;
          return {
            supplier_eligibility_id: `eligibility-${index}-${priorityIndex}`,
            supplier_id: supplier.supplier_id,
            supplier_name: supplier.supplier_name,
            priority: priorityIndex + 1,
          };
        },
      ),
    };
  });

const units = [
  {
    unit_id: "unit-kg",
    unit_code: "KG",
    unit_name: "Kilôgam",
    unit_status: "ACTIVE" as const,
  },
  {
    unit_id: "unit-pack",
    unit_code: "PACK",
    unit_name: "Gói",
    unit_status: "ACTIVE" as const,
  },
  {
    unit_id: "unit-inactive",
    unit_code: "OLD",
    unit_name: "Đơn vị lịch sử",
    unit_status: "INACTIVE" as const,
  },
];
const ingredientTypes = [
  {
    ingredient_type_id: "type-1",
    ingredient_type_code: "VEG",
    ingredient_type_name: "Rau củ",
    display_order: 1,
    ingredient_type_status: "ACTIVE" as const,
  },
  {
    ingredient_type_id: "type-2",
    ingredient_type_code: "PROTEIN",
    ingredient_type_name: "Thịt cá",
    display_order: 2,
    ingredient_type_status: "ACTIVE" as const,
  },
  {
    ingredient_type_id: "type-3",
    ingredient_type_code: "DRY",
    ingredient_type_name: "Thực phẩm khô",
    display_order: 3,
    ingredient_type_status: "ACTIVE" as const,
  },
  {
    ingredient_type_id: "type-inactive",
    ingredient_type_code: "OLD",
    ingredient_type_name: "Phân loại lịch sử",
    display_order: 4,
    ingredient_type_status: "INACTIVE" as const,
  },
];
const ingredientOrderGroups = [
  {
    ingredient_order_group_id: "group-1",
    ingredient_order_group_code: "ADVANCE",
    ingredient_order_group_name: "Hàng đặt trước",
    display_order: 1,
    ingredient_order_group_status: "ACTIVE" as const,
  },
  {
    ingredient_order_group_id: "group-2",
    ingredient_order_group_code: "DAILY",
    ingredient_order_group_name: "Hàng ngày",
    display_order: 2,
    ingredient_order_group_status: "ACTIVE" as const,
  },
  {
    ingredient_order_group_id: "group-inactive",
    ingredient_order_group_code: "OLD",
    ingredient_order_group_name: "Nhóm lịch sử",
    display_order: 3,
    ingredient_order_group_status: "INACTIVE" as const,
  },
];

function authority(): AtlasRpcResult {
  return {
    kind: "success",
    response: {
      success: true,
      ingredients: ingredientSupplierFixtureIngredients,
      suppliers: ingredientSupplierFixtureSuppliers,
      units,
      ingredient_types: ingredientTypes,
      ingredient_order_groups: ingredientOrderGroups,
    },
  };
}
const permissionDenied: AtlasRpcResult = {
  kind: "backend_error",
  error: {
    success: false,
    error_code: "CAPABILITY_DENIED",
    safe_message: "Denied",
  },
};
const stale: AtlasRpcResult = {
  kind: "backend_error",
  error: {
    success: false,
    error_code: "STALE_VERSION",
    safe_message: "Stale",
    expected_version: 1,
    actual_version: 2,
  },
};
const unknown: AtlasRpcResult = {
  kind: "transport_error",
  diagnostic: { code: "NETWORK_FAILURE", safeMessage: "offline" },
};
const success: AtlasRpcResult = {
  kind: "success",
  response: { success: true },
};

export function createIngredientSupplierReviewFixture(
  scenario: IngredientSupplierScenario = "INGREDIENTS_DENSE_360",
): IngredientSupplierMasterDataApi {
  let reads = 0;
  const writeResult =
    scenario === "PERMISSION_DENIED"
      ? permissionDenied
      : scenario === "INGREDIENT_STALE"
        ? stale
        : scenario === "INGREDIENT_UNKNOWN" || scenario === "SUPPLIER_UNKNOWN"
          ? unknown
          : success;
  const write = async () => writeResult;
  return {
    async getIngredientsAndSuppliers() {
      reads += 1;
      if (
        scenario === "READ_FAILURE" ||
        (scenario === "SUCCESS_THEN_READBACK_FAILURE" && reads > 1)
      )
        return {
          kind: "backend_error",
          error: {
            success: false,
            error_code: "READ_FAILED",
            safe_message: "Không thể tải dữ liệu.",
          },
        };
      return authority();
    },
    createIngredient: write,
    updateIngredient: write,
    setIngredientLifecycle: write,
    createSupplier: write,
    updateSupplier: write,
    replacePriorities: write,
  };
}
