import { describe, expect, it } from "vitest";
import {
  CreateIngredient,
  CreateSupplier,
  DefaultSupplierPolicyReference,
  IngredientOperationalReference,
  IngredientSupplierAdminWorkbench,
  IngredientSupplierEligibilityReference,
  SetDefaultSupplierPolicy,
  SetIngredientStatus,
  SetIngredientSupplierEligibility,
  SetIngredientUnitProfile,
  SetSupplierStatus,
  SupplierProcurementAssignmentReference,
  ingredientIssues,
} from "./ingredientSupplierAdminDomain";
import { ingredientSupplierAdminFixture } from "./ingredientSupplierAdminFixtures";

const audit = {
  actorId: "admin-lan",
  at: "2026-07-14T05:00:00.000Z",
  reason: "Focused test",
};
const activeIngredient = ingredientSupplierAdminFixture.ingredients[0];
const activeSupplier = ingredientSupplierAdminFixture.suppliers[0];

describe("Ingredients & Suppliers Admin foundation", () => {
  it("blocks missing ingredient names and duplicate active ingredient identities", () => {
    const missing = CreateIngredient(ingredientSupplierAdminFixture, {
      ...activeIngredient,
      ingredientId: "ingredient-missing-name",
      ingredientName: " ",
      ...audit,
    });
    expect(missing.accepted).toBe(false);
    expect(missing.blockers.map((issue) => issue.issueCode)).toContain(
      "INGREDIENT_NAME_MISSING",
    );
    const duplicate = CreateIngredient(ingredientSupplierAdminFixture, {
      ...activeIngredient,
      ingredientId: "ingredient-duplicate",
      ingredientName: `  ${activeIngredient.ingredientName}  `,
      ...audit,
    });
    expect(duplicate.accepted).toBe(false);
    expect(duplicate.blockers.map((issue) => issue.issueCode)).toContain(
      "DUPLICATE_ACTIVE_INGREDIENT",
    );
  });

  it("blocks operational validity without a purchase unit or required conversion", () => {
    const withoutPurchaseUnit = {
      ...activeIngredient,
      unitProfile: { ...activeIngredient.unitProfile, purchaseUnit: "" },
    };
    expect(
      ingredientIssues(ingredientSupplierAdminFixture, withoutPurchaseUnit).map(
        (issue) => issue.issueCode,
      ),
    ).toContain("PURCHASE_UNIT_MISSING");
    const withoutConversion = {
      ...activeIngredient,
      ingredientId: "ingredient-no-conversion",
      unitProfile: {
        purchaseUnit: "case",
        planningUnit: "kg",
        inventoryUnit: "item",
      },
    };
    expect(
      ingredientIssues(ingredientSupplierAdminFixture, withoutConversion).map(
        (issue) => issue.issueCode,
      ),
    ).toContain("UNIT_CONVERSION_MISSING");
  });

  it("blocks inactive ingredients for each new downstream reference unless override evidence exists", () => {
    const inactive = ingredientSupplierAdminFixture.ingredients[2];
    for (const use of [
      "RECIPE_BOM",
      "PLANNING",
      "PROCUREMENT",
      "WAREHOUSE",
    ] as const) {
      expect(IngredientOperationalReference(inactive, use).accepted).toBe(
        false,
      );
      expect(
        IngredientOperationalReference(inactive, use, "approved exception-61")
          .accepted,
      ).toBe(true);
    }
  });

  it("blocks missing supplier names, duplicate active identities, and inactive assignment", () => {
    const missing = CreateSupplier(ingredientSupplierAdminFixture, {
      ...activeSupplier,
      supplierId: "supplier-missing-name",
      supplierName: " ",
      ...audit,
    });
    expect(missing.accepted).toBe(false);
    expect(missing.blockers.map((issue) => issue.issueCode)).toContain(
      "SUPPLIER_NAME_MISSING",
    );
    const duplicate = CreateSupplier(ingredientSupplierAdminFixture, {
      ...activeSupplier,
      supplierId: "supplier-duplicate",
      supplierName: ` ${activeSupplier.supplierName} `,
      ...audit,
    });
    expect(duplicate.blockers.map((issue) => issue.issueCode)).toContain(
      "DUPLICATE_ACTIVE_SUPPLIER",
    );
    const inactive = ingredientSupplierAdminFixture.suppliers[2];
    expect(SupplierProcurementAssignmentReference(inactive).accepted).toBe(
      false,
    );
    expect(
      SupplierProcurementAssignmentReference(inactive, "approved exception-61")
        .accepted,
    ).toBe(true);
  });

  it("requires ingredient-supplier eligibility before Procurement may treat the pair as eligible", () => {
    expect(
      IngredientSupplierEligibilityReference(
        ingredientSupplierAdminFixture,
        "ingredient-rice",
        "supplier-minh-tam",
      ).accepted,
    ).toBe(false);
    const changed = SetIngredientSupplierEligibility(
      ingredientSupplierAdminFixture,
      {
        ingredientId: "ingredient-rice",
        supplierId: "supplier-minh-tam",
        status: "ELIGIBLE",
        ...audit,
      },
    );
    expect(
      IngredientSupplierEligibilityReference(
        changed.state,
        "ingredient-rice",
        "supplier-minh-tam",
      ).accepted,
    ).toBe(true);
    expect(changed.state.ingredientSupplierChanges.at(-1)?.changeType).toBe(
      "IngredientSupplierEligibilityChanged",
    );
  });

  it("keeps default supplier policy as Admin reference data without commitment effects", () => {
    const policy = ingredientSupplierAdminFixture.defaultSupplierPolicies[0];
    expect(DefaultSupplierPolicyReference(policy)).toMatchObject({
      effect: "ADMIN_REFERENCE_ONLY",
      createsPurchaseOrder: false,
      createsSupplierCommitment: false,
    });
    const changed = SetDefaultSupplierPolicy(ingredientSupplierAdminFixture, {
      defaultSupplierPolicyId: "rice-default-an-phu",
      ingredientId: "ingredient-rice",
      supplierId: "supplier-an-phu",
      preference: "PREFERRED",
      status: "ACTIVE",
      ...audit,
    });
    expect(changed.accepted).toBe(true);
    expect(changed.state.ingredientSupplierChanges.at(-1)?.changeType).toBe(
      "DefaultSupplierPolicyChanged",
    );
    expect(
      DefaultSupplierPolicyReference(changed.state.defaultSupplierPolicies[0])
        .createsSupplierCommitment,
    ).toBe(false);
  });

  it("records status and unit-profile changes explicitly and auditably", () => {
    const units = SetIngredientUnitProfile(ingredientSupplierAdminFixture, {
      ingredientId: "ingredient-rice",
      unitProfile: {
        purchaseUnit: "kg",
        planningUnit: "kg",
        inventoryUnit: "kg",
        usableUnit: "kg",
      },
      ...audit,
    });
    expect(
      units.state.ingredients[0].masterDataChanges.at(-1)?.changeType,
    ).toBe("IngredientUnitProfileChanged");
    const ingredientStatus = SetIngredientStatus(units.state, {
      ingredientId: "ingredient-rice",
      status: "INACTIVE",
      ...audit,
    });
    expect(ingredientStatus.state.ingredients[0].statusChanges).toHaveLength(1);
    const supplierStatus = SetSupplierStatus(ingredientStatus.state, {
      supplierId: "supplier-an-phu",
      status: "INACTIVE",
      ...audit,
    });
    expect(supplierStatus.state.suppliers[0].statusChanges).toHaveLength(1);
    expect(
      IngredientSupplierAdminWorkbench(supplierStatus.state).changeHistory.map(
        (change) => change.changeType,
      ),
    ).toEqual(
      expect.arrayContaining([
        "IngredientUnitProfileChanged",
        "IngredientDeactivated",
        "SupplierDeactivated",
      ]),
    );
  });

  it("does not mutate fixtures or add downstream operational and integration behavior", () => {
    const before = JSON.stringify(ingredientSupplierAdminFixture);
    const changed = SetIngredientSupplierEligibility(
      ingredientSupplierAdminFixture,
      {
        ingredientId: "ingredient-rice",
        supplierId: "supplier-minh-tam",
        status: "ELIGIBLE",
        ...audit,
      },
    );
    expect(JSON.stringify(ingredientSupplierAdminFixture)).toBe(before);
    expect(changed.state).not.toBe(ingredientSupplierAdminFixture);
    for (const forbidden of [
      "planning",
      "procurementCommitments",
      "purchaseOrders",
      "warehouse",
      "dispatch",
      "qa",
      "finance",
      "supabase",
      "retool",
      "backend",
      "credentials",
      "productionData",
    ])
      expect(forbidden in changed.state).toBe(false);
  });
});
