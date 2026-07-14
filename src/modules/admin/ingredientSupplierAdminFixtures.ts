import type { IngredientSupplierAdminState } from "./ingredientSupplierAdminDomain";

export const ingredientSupplierAdminFixture: IngredientSupplierAdminState = {
  ingredients: [
    {
      ingredientId: "ingredient-rice",
      ingredientName: "Rice",
      status: "ACTIVE",
      ingredientGroup: "Dry goods",
      operationalNotes:
        "Stable kilogram profile for Planning and Warehouse reference.",
      unitProfile: {
        purchaseUnit: "kg",
        planningUnit: "kg",
        inventoryUnit: "kg",
        usableUnit: "kg",
      },
      statusChanges: [],
      masterDataChanges: [
        {
          ingredientMasterDataChangeId: "ingredient-rice-change-1",
          ingredientId: "ingredient-rice",
          changeType: "IngredientCreated",
          actorId: "admin-lan",
          at: "2026-07-14T01:00:00.000Z",
          reason: "Prototype master-data review",
        },
      ],
    },
    {
      ingredientId: "ingredient-spring-onion",
      ingredientName: "Spring onion",
      status: "ACTIVE",
      ingredientGroup: "Fresh produce",
      operationalNotes:
        "Purchased by bundle and interpreted operationally in kilograms.",
      unitProfile: {
        purchaseUnit: "bundle",
        planningUnit: "kg",
        inventoryUnit: "kg",
        usableUnit: "kg",
      },
      statusChanges: [],
      masterDataChanges: [
        {
          ingredientMasterDataChangeId: "ingredient-spring-onion-change-1",
          ingredientId: "ingredient-spring-onion",
          changeType: "IngredientUnitProfileChanged",
          actorId: "admin-lan",
          at: "2026-07-14T02:00:00.000Z",
          reason: "Recorded approved bundle reference",
        },
      ],
    },
    {
      ingredientId: "ingredient-old-oil",
      ingredientName: "Legacy cooking oil",
      status: "INACTIVE",
      ingredientGroup: "Pantry",
      operationalNotes:
        "Retained only so historical references remain interpretable.",
      unitProfile: {
        purchaseUnit: "bottle",
        planningUnit: "liter",
        inventoryUnit: "bottle",
        usableUnit: "liter",
      },
      statusChanges: [
        {
          ingredientStatusChangeId: "ingredient-old-oil-status-1",
          ingredientId: "ingredient-old-oil",
          beforeStatus: "ACTIVE",
          afterStatus: "INACTIVE",
          actorId: "admin-lan",
          at: "2026-07-12T01:00:00.000Z",
          reason: "Superseded ingredient identity",
        },
      ],
      masterDataChanges: [
        {
          ingredientMasterDataChangeId: "ingredient-old-oil-change-1",
          ingredientId: "ingredient-old-oil",
          changeType: "IngredientDeactivated",
          actorId: "admin-lan",
          at: "2026-07-12T01:00:00.000Z",
          reason: "Superseded ingredient identity",
          before: "ACTIVE",
          after: "INACTIVE",
        },
      ],
    },
  ],
  suppliers: [
    {
      supplierId: "supplier-an-phu",
      supplierName: "An Phu Foods",
      status: "ACTIVE",
      contactReference: "Purchasing desk · 0900 100 200",
      operationalNotes: "Eligible for reviewed dry goods and fresh produce.",
      statusChanges: [],
      masterDataChanges: [
        {
          supplierMasterDataChangeId: "supplier-an-phu-change-1",
          supplierId: "supplier-an-phu",
          changeType: "SupplierCreated",
          actorId: "admin-lan",
          at: "2026-07-14T01:10:00.000Z",
          reason: "Prototype master-data review",
        },
      ],
    },
    {
      supplierId: "supplier-minh-tam",
      supplierName: "Minh Tam Produce",
      status: "ACTIVE",
      contactReference: "Fresh produce desk",
      operationalNotes:
        "Eligible for spring onion; not a Procurement assignment.",
      statusChanges: [],
      masterDataChanges: [
        {
          supplierMasterDataChangeId: "supplier-minh-tam-change-1",
          supplierId: "supplier-minh-tam",
          changeType: "SupplierCreated",
          actorId: "admin-lan",
          at: "2026-07-14T01:20:00.000Z",
          reason: "Prototype master-data review",
        },
      ],
    },
    {
      supplierId: "supplier-legacy",
      supplierName: "Legacy Pantry Supplier",
      status: "INACTIVE",
      operationalNotes: "Unavailable for new Procurement assignment.",
      statusChanges: [
        {
          supplierStatusChangeId: "supplier-legacy-status-1",
          supplierId: "supplier-legacy",
          beforeStatus: "ACTIVE",
          afterStatus: "INACTIVE",
          actorId: "admin-lan",
          at: "2026-07-11T01:00:00.000Z",
          reason: "Supplier relationship ended",
        },
      ],
      masterDataChanges: [
        {
          supplierMasterDataChangeId: "supplier-legacy-change-1",
          supplierId: "supplier-legacy",
          changeType: "SupplierDeactivated",
          actorId: "admin-lan",
          at: "2026-07-11T01:00:00.000Z",
          reason: "Supplier relationship ended",
          before: "ACTIVE",
          after: "INACTIVE",
        },
      ],
    },
  ],
  unitConversionRules: [
    {
      unitConversionRuleId: "spring-onion-bundle-kg",
      ingredientId: "ingredient-spring-onion",
      fromUnit: "bundle",
      toUnit: "kg",
      factor: 0.1,
      status: "ACTIVE",
      actorId: "admin-lan",
      at: "2026-07-14T02:00:00.000Z",
      reason: "Approved prototype conversion reference",
    },
    {
      unitConversionRuleId: "old-oil-bottle-liter",
      ingredientId: "ingredient-old-oil",
      fromUnit: "bottle",
      toUnit: "liter",
      factor: 1,
      status: "INACTIVE",
      actorId: "admin-lan",
      at: "2026-07-12T01:00:00.000Z",
      reason: "Deactivated with legacy ingredient",
    },
  ],
  eligibilities: [
    {
      ingredientSupplierEligibilityId: "rice-an-phu-eligibility",
      ingredientId: "ingredient-rice",
      supplierId: "supplier-an-phu",
      status: "ELIGIBLE",
    },
    {
      ingredientSupplierEligibilityId: "spring-onion-an-phu-eligibility",
      ingredientId: "ingredient-spring-onion",
      supplierId: "supplier-an-phu",
      status: "ELIGIBLE",
    },
    {
      ingredientSupplierEligibilityId: "spring-onion-minh-tam-eligibility",
      ingredientId: "ingredient-spring-onion",
      supplierId: "supplier-minh-tam",
      status: "ELIGIBLE",
    },
    {
      ingredientSupplierEligibilityId: "old-oil-legacy-eligibility",
      ingredientId: "ingredient-old-oil",
      supplierId: "supplier-legacy",
      status: "INELIGIBLE",
    },
  ],
  defaultSupplierPolicies: [
    {
      defaultSupplierPolicyId: "rice-default-an-phu",
      ingredientId: "ingredient-rice",
      supplierId: "supplier-an-phu",
      preference: "DEFAULT",
      status: "ACTIVE",
      effect: "ADMIN_REFERENCE_ONLY",
    },
    {
      defaultSupplierPolicyId: "spring-onion-preferred-minh-tam",
      ingredientId: "ingredient-spring-onion",
      supplierId: "supplier-minh-tam",
      preference: "PREFERRED",
      status: "ACTIVE",
      effect: "ADMIN_REFERENCE_ONLY",
    },
  ],
  ingredientSupplierChanges: [
    {
      ingredientSupplierChangeId: "ingredient-supplier-change-1",
      ingredientId: "ingredient-spring-onion",
      supplierId: "supplier-minh-tam",
      changeType: "DefaultSupplierPolicyChanged",
      actorId: "admin-lan",
      at: "2026-07-14T03:00:00.000Z",
      reason: "Recorded Admin preference for operator review",
      after: "PREFERRED:supplier-minh-tam",
    },
  ],
};
