import { describe, expect, it } from "vitest";
import type {
  IngredientMasterData,
  IngredientOrderGroupMasterData,
  IngredientTypeMasterData,
  SupplierMasterData,
  UnitMasterData,
} from "../bridges/ingredientSupplierMasterData";
import {
  catalogueOptionsForIngredient,
  filterIngredients,
  filterSuppliers,
  formatVietnameseDecimal,
  parseOrderStepDraft,
  validatePriorities,
} from "./ingredientSupplierModel";

const activeSupplier: SupplierMasterData = {
  supplier_id: "supplier-active",
  supplier_code: "NCC-MINH-TAM",
  supplier_name: "NCC Minh Tâm",
  supplier_status: "ACTIVE",
  contact_name: "Tâm",
  contact_phone: "0901",
  contact_email: "tam@example.test",
  version: 2,
};
const inactiveSupplier: SupplierMasterData = {
  ...activeSupplier,
  supplier_id: "supplier-inactive",
  supplier_code: "NCC-CU",
  supplier_name: "Nhà cung ứng Cũ",
  supplier_status: "INACTIVE",
};
const ingredient: IngredientMasterData = {
  ingredient_id: "ingredient-1",
  ingredient_code: "NL-RAU-MUONG",
  ingredient_name: "Rau muống",
  ingredient_status: "ACTIVE",
  ingredient_type_id: "type-1",
  ingredient_type_name: "Rau lá",
  ingredient_order_group_id: "group-1",
  ingredient_order_group_name: "Hàng ngày",
  ingredient_type: "Rau lá",
  shopping_type: "Hàng ngày",
  purchase_unit_id: "unit-1",
  purchase_unit_code: "KG",
  purchase_unit_name: "Kilôgam",
  order_step: 0.5,
  version: 4,
  supplier_priorities: [
    {
      supplier_eligibility_id: "eligibility-1",
      supplier_id: activeSupplier.supplier_id,
      supplier_name: activeSupplier.supplier_name,
      priority: 1,
    },
  ],
};

describe("Ingredient/Supplier vNext model", () => {
  it.each([
    ["0,1", 0.1],
    ["0.1", 0.1],
    ["1", 1],
    ["2,5", 2.5],
    ["2.5", 2.5],
  ])("accepts operator order step %s", (draft, expected) => {
    expect(parseOrderStepDraft(draft)).toBe(expected);
  });

  it.each(["", "0", "-1", "1,2.3", "1.2,3", "abc", "1e3"])(
    "rejects invalid order step %s",
    (draft) => expect(parseOrderStepDraft(draft)).toBeNull(),
  );

  it("formats business decimals with Vietnamese punctuation", () => {
    expect(formatVietnameseDecimal(25.75)).toBe("25,75");
  });

  it("filters Ingredients locally with accent folding across hidden code and human related names", () => {
    const catalogues = {
      suppliers: [activeSupplier],
      units: [
        {
          unit_id: "unit-1",
          unit_code: "KG",
          unit_name: "Kilôgam",
          unit_status: "ACTIVE",
        },
      ] satisfies UnitMasterData[],
      ingredientTypes: [
        {
          ingredient_type_id: "type-1",
          ingredient_type_code: "RAU",
          ingredient_type_name: "Rau lá",
          display_order: 1,
          ingredient_type_status: "ACTIVE",
        },
      ] satisfies IngredientTypeMasterData[],
      ingredientOrderGroups: [
        {
          ingredient_order_group_id: "group-1",
          ingredient_order_group_code: "DAILY",
          ingredient_order_group_name: "Hàng ngày",
          display_order: 1,
          ingredient_order_group_status: "ACTIVE",
        },
      ] satisfies IngredientOrderGroupMasterData[],
    };
    for (const query of [
      "RAU MUONG",
      "nl-rau",
      "rau la",
      "hang ngay",
      "kilogam",
      "minh tam",
    ]) {
      expect(filterIngredients([ingredient], query, "ALL", catalogues)).toEqual(
        [ingredient],
      );
    }
    expect(
      filterIngredients([ingredient], "rau", "INACTIVE", catalogues),
    ).toEqual([]);
  });

  it("filters Suppliers locally with accent folding across hidden code and contacts", () => {
    for (const query of [
      "minh tam",
      "ncc-minh",
      "tam",
      "0901",
      "example.test",
    ]) {
      expect(filterSuppliers([activeSupplier], query)).toEqual([
        activeSupplier,
      ]);
    }
  });

  it("offers active catalogue values plus only the Ingredient's current inactive value", () => {
    const options = catalogueOptionsForIngredient(
      [
        { id: "active", name: "Đang dùng", status: "ACTIVE" },
        { id: "current", name: "Giá trị hiện tại", status: "INACTIVE" },
        { id: "other", name: "Không được chọn", status: "INACTIVE" },
      ],
      "current",
    );
    expect(options).toEqual([
      {
        id: "active",
        name: "Đang dùng",
        status: "ACTIVE",
        currentInactive: false,
      },
      {
        id: "current",
        name: "Giá trị hiện tại",
        status: "INACTIVE",
        currentInactive: true,
      },
    ]);
    expect(catalogueOptionsForIngredient(options, null)).toHaveLength(1);
  });

  it("accepts an explicit empty priority replacement for an active Ingredient", () => {
    expect(validatePriorities([], ingredient, [activeSupplier])).toEqual([]);
  });

  it("rejects duplicate Suppliers, duplicate/out-of-range ranks, inactive Suppliers, and non-active Ingredients", () => {
    expect(
      validatePriorities(
        [
          { supplierId: activeSupplier.supplier_id, priority: 1 },
          { supplierId: activeSupplier.supplier_id, priority: 1 },
          { supplierId: inactiveSupplier.supplier_id, priority: 7 },
        ],
        { ...ingredient, ingredient_status: "INACTIVE" },
        [activeSupplier, inactiveSupplier],
      ),
    ).toEqual([
      "Chỉ nguyên liệu đang dùng mới có thể cập nhật ưu tiên.",
      "Mỗi nhà cung ứng chỉ được chọn một lần.",
      "Mỗi mức ưu tiên chỉ được dùng một lần.",
      "Mức ưu tiên phải là số nguyên từ 1 đến 6.",
      "Hãy gỡ hoặc thay nhà cung ứng không còn hợp tác trước khi lưu.",
    ]);
  });

  it("rejects more than six priority rows", () => {
    expect(
      validatePriorities(
        Array.from({ length: 7 }, (_, index) => ({
          supplierId: `supplier-${index}`,
          priority: index + 1,
        })),
        ingredient,
        Array.from({ length: 7 }, (_, index) => ({
          ...activeSupplier,
          supplier_id: `supplier-${index}`,
        })),
      ),
    ).toContain("Chỉ được chọn tối đa 6 nhà cung ứng.");
  });
});
