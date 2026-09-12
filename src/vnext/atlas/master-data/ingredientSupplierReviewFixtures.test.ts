import { describe, expect, it } from "vitest";
import {
  ingredientSupplierFixtureIngredients,
  ingredientSupplierFixtureSuppliers,
  ingredientSupplierScenarios,
} from "./ingredientSupplierReviewFixtures";

describe("Ingredient/Supplier review fixtures", () => {
  it("provides the complete approved review scenario registry", () => {
    expect(ingredientSupplierScenarios).toEqual([
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
    ]);
  });

  it("renders realistic catalogue scale without duplicate technical identities", () => {
    expect(ingredientSupplierFixtureIngredients).toHaveLength(360);
    expect(ingredientSupplierFixtureSuppliers).toHaveLength(37);
    expect(
      new Set(
        ingredientSupplierFixtureIngredients.map((item) => item.ingredient_id),
      ).size,
    ).toBe(360);
    expect(
      new Set(
        ingredientSupplierFixtureSuppliers.map((item) => item.supplier_id),
      ).size,
    ).toBe(37);
    const sixPriorityIngredient = ingredientSupplierFixtureIngredients.find(
      (item) => item.ingredient_name === "Nguyên liệu sơ chế 009",
    );
    expect(sixPriorityIngredient?.supplier_priorities).toHaveLength(6);
    expect(
      sixPriorityIngredient?.supplier_priorities.every((priority) =>
        ingredientSupplierFixtureSuppliers.some(
          (supplier) =>
            supplier.supplier_id === priority.supplier_id &&
            supplier.supplier_status === "ACTIVE",
        ),
      ),
    ).toBe(true);
  });
});
