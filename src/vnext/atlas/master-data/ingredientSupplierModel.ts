import { foldVietnameseSearch } from "../foldVietnameseSearch";
import type {
  IngredientMasterData,
  SupplierMasterData,
} from "../bridges/ingredientSupplierMasterData";

export type IngredientStatusFilter =
  "ALL" | IngredientMasterData["ingredient_status"];
export type PriorityDraft = { supplierId: string; priority: number };

const ORDER_STEP = /^\d+(?:[.,]\d+)?$/;

export function parseOrderStepDraft(value: string) {
  const trimmed = value.trim();
  if (!ORDER_STEP.test(trimmed)) return null;
  const parsed = Number(trimmed.replace(",", "."));
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
}

export function formatVietnameseDecimal(value: number) {
  return new Intl.NumberFormat("vi-VN", { maximumFractionDigits: 12 }).format(
    value,
  );
}

function includesFolded(value: string | null | undefined, query: string) {
  return foldVietnameseSearch(value ?? "").includes(query);
}

export function filterIngredients(
  ingredients: IngredientMasterData[],
  query: string,
  status: IngredientStatusFilter,
  catalogues: {
    suppliers: SupplierMasterData[];
    units: { unit_id: string; unit_name: string }[];
    ingredientTypes: {
      ingredient_type_id: string;
      ingredient_type_name: string;
    }[];
    ingredientOrderGroups: {
      ingredient_order_group_id: string;
      ingredient_order_group_name: string;
    }[];
  },
) {
  const folded = foldVietnameseSearch(query.trim());
  const supplierNames = new Map(
    catalogues.suppliers.map((supplier) => [
      supplier.supplier_id,
      supplier.supplier_name,
    ]),
  );
  const unitNames = new Map(
    catalogues.units.map((unit) => [unit.unit_id, unit.unit_name]),
  );
  const typeNames = new Map(
    catalogues.ingredientTypes.map((type) => [
      type.ingredient_type_id,
      type.ingredient_type_name,
    ]),
  );
  const groupNames = new Map(
    catalogues.ingredientOrderGroups.map((group) => [
      group.ingredient_order_group_id,
      group.ingredient_order_group_name,
    ]),
  );
  return ingredients.filter((item) => {
    if (status !== "ALL" && item.ingredient_status !== status) return false;
    if (!folded) return true;
    return [
      item.ingredient_name,
      item.ingredient_code,
      item.ingredient_type_name ?? typeNames.get(item.ingredient_type_id ?? ""),
      item.ingredient_order_group_name ??
        groupNames.get(item.ingredient_order_group_id ?? ""),
      item.purchase_unit_name ?? unitNames.get(item.purchase_unit_id ?? ""),
      ...item.supplier_priorities.map(
        (priority) =>
          priority.supplier_name ?? supplierNames.get(priority.supplier_id),
      ),
    ].some((value) => includesFolded(value, folded));
  });
}

export function filterSuppliers(
  suppliers: SupplierMasterData[],
  query: string,
) {
  const folded = foldVietnameseSearch(query.trim());
  if (!folded) return suppliers;
  return suppliers.filter((supplier) =>
    [
      supplier.supplier_name,
      supplier.supplier_code,
      supplier.contact_name,
      supplier.contact_phone,
      supplier.contact_email,
    ].some((value) => includesFolded(value, folded)),
  );
}

export function catalogueOptionsForIngredient<
  T extends { id: string; name: string; status: "ACTIVE" | "INACTIVE" },
>(items: T[], currentId: string | null) {
  return items
    .filter((item) => item.status === "ACTIVE" || item.id === currentId)
    .map((item) => ({
      ...item,
      currentInactive: item.status === "INACTIVE" && item.id === currentId,
    }));
}

export function validatePriorities(
  priorities: PriorityDraft[],
  ingredient: IngredientMasterData,
  suppliers: SupplierMasterData[],
) {
  const errors: string[] = [];
  if (ingredient.ingredient_status !== "ACTIVE")
    errors.push("Chỉ nguyên liệu đang dùng mới có thể cập nhật ưu tiên.");
  if (priorities.length > 6)
    errors.push("Chỉ được chọn tối đa 6 nhà cung ứng.");
  const supplierIds = priorities.map((item) => item.supplierId);
  if (new Set(supplierIds).size !== supplierIds.length)
    errors.push("Mỗi nhà cung ứng chỉ được chọn một lần.");
  const ranks = priorities.map((item) => item.priority);
  if (new Set(ranks).size !== ranks.length)
    errors.push("Mỗi mức ưu tiên chỉ được dùng một lần.");
  if (ranks.some((rank) => !Number.isInteger(rank) || rank < 1 || rank > 6))
    errors.push("Mức ưu tiên phải là số nguyên từ 1 đến 6.");
  const statusById = new Map(
    suppliers.map((supplier) => [
      supplier.supplier_id,
      supplier.supplier_status,
    ]),
  );
  if (
    supplierIds.some(
      (supplierId) => !supplierId || statusById.get(supplierId) !== "ACTIVE",
    )
  )
    errors.push(
      "Hãy gỡ hoặc thay nhà cung ứng không còn hợp tác trước khi lưu.",
    );
  return errors;
}
