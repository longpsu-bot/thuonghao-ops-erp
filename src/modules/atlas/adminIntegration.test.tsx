import "@testing-library/jest-dom/vitest";
import { cleanup, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import {
  DishRecipeAdminWorkbench as createDishRecipeReadModel,
  ReleaseRecipeVersionForPlanning,
  ValidateRecipeVersion,
  type DishRecipeAdminState,
} from "../admin/dishRecipeAdminDomain";
import { dishRecipeAdminFixture } from "../admin/dishRecipeAdminFixtures";
import {
  DefaultSupplierPolicyReference,
  IngredientSupplierAdminWorkbench as createIngredientSupplierReadModel,
  SetDefaultSupplierPolicy,
  UpdateIngredientProfile,
} from "../admin/ingredientSupplierAdminDomain";
import { ingredientSupplierAdminFixture } from "../admin/ingredientSupplierAdminFixtures";
import { SchoolAdminWorkbench as createSchoolReadModel } from "../admin/schoolAdminDomain";
import { schoolAdminFixture } from "../admin/schoolAdminFixtures";
import { AtlasApp, type MasterDataPageId } from "./AtlasApp";
import { atlasPages } from "./atlasConfig";

afterEach(cleanup);

const audit = {
  actorId: "admin-reviewer",
  at: "2026-07-14T08:00:00.000Z",
  reason: "PD-04 integration conformance review",
};

function objectKeys(value: unknown): string[] {
  if (!value || typeof value !== "object") return [];
  if (Array.isArray(value)) return value.flatMap(objectKeys);
  return Object.entries(value).flatMap(([key, nested]) => [
    key,
    ...objectKeys(nested),
  ]);
}

function renderAtlasSurface(page: MasterDataPageId, heading: string) {
  const rendered = render(<AtlasApp initialPage={page} reviewMode />);
  expect(
    screen.getAllByRole("heading", { name: heading }).length,
  ).toBeGreaterThan(0);
  rendered.unmount();
}

describe("PD-04 Admin integration conformance", () => {
  it("exposes one Master Data area with Schools and Ingredients & Suppliers", () => {
    renderAtlasSurface("customers-schools", "Trường học");
    renderAtlasSurface("ingredients-units", "Nguyên liệu và Nhà cung ứng");
    renderAtlasSurface("recipes", "Công thức món ăn");
  });

  it("keeps Dishes & Recipes as one consolidated Atlas workbench", () => {
    const recipePages = atlasPages.filter((page) =>
      /recipe|công thức/i.test(`${page.id} ${page.label}`),
    );
    expect(recipePages).toHaveLength(1);
    expect(recipePages[0]).toMatchObject({
      id: "recipe-governance",
      label: "Dishes & Recipes",
    });

    render(<AtlasApp reviewMode initialPage="recipes" />);
    for (const tab of ["Công thức", "Lệnh điều chỉnh"])
      expect(screen.getByRole("tab", { name: tab })).toBeInTheDocument();
    expect(screen.queryByText(/Retool layer/i)).not.toBeInTheDocument();
  });

  it("keeps ingredient edits and supplier policy outside Procurement commitment", () => {
    const original = structuredClone(ingredientSupplierAdminFixture);
    const profile = UpdateIngredientProfile(original, {
      ingredientId: "ingredient-rice",
      ingredientName: "Rice",
      ingredientGroup: "Reviewed dry goods",
      operationalNotes: "Future Admin reference only",
      ...audit,
    });
    expect(profile.accepted).toBe(true);

    const policy = SetDefaultSupplierPolicy(profile.state, {
      defaultSupplierPolicyId: "rice-default-an-phu-review",
      ingredientId: "ingredient-rice",
      supplierId: "supplier-an-phu",
      preference: "DEFAULT",
      status: "ACTIVE",
      ...audit,
    });
    expect(policy.accepted).toBe(true);
    const reference = DefaultSupplierPolicyReference(
      policy.state.defaultSupplierPolicies.find(
        (item) => item.ingredientId === "ingredient-rice",
      )!,
    );
    expect(reference).toMatchObject({
      effect: "ADMIN_REFERENCE_ONLY",
      createsPurchaseOrder: false,
      createsSupplierCommitment: false,
    });

    const forbiddenProcurementFields = [
      "supplierAssignmentId",
      "purchaseAllocationId",
      "purchaseOrderId",
      "supplierConfirmationId",
      "supplierCommitmentId",
    ];
    expect(objectKeys(policy.state)).not.toEqual(
      expect.arrayContaining(forbiddenProcurementFields),
    );
    expect(ingredientSupplierAdminFixture).toEqual(original);
  });

  it("releases a versioned future reference without mutating prior operational facts", () => {
    const state: DishRecipeAdminState = {
      ...structuredClone(dishRecipeAdminFixture),
      downstreamRecipeUsage: [
        ...structuredClone(dishRecipeAdminFixture.downstreamRecipeUsage),
        {
          usageId: "confirmed-need-pumpkin-v1",
          recipeVersionId: "recipe-pumpkin-v1",
          domain: "CONFIRMED_NEED",
          referenceId: "confirmed-need-2026-07-13",
          recordedAt: "2026-07-13T06:00:00.000Z",
        },
        {
          usageId: "purchase-handoff-pumpkin-v1",
          recipeVersionId: "recipe-pumpkin-v1",
          domain: "PURCHASE_HANDOFF",
          referenceId: "purchase-handoff-2026-07-13",
          recordedAt: "2026-07-13T07:00:00.000Z",
        },
      ],
    };
    const priorFacts = structuredClone(state.downstreamRecipeUsage);
    const validated = ValidateRecipeVersion(state, {
      recipeVersionId: "recipe-pumpkin-v2",
      ...audit,
    });
    expect(validated.accepted).toBe(true);
    const released = ReleaseRecipeVersionForPlanning(validated.state, {
      recipeVersionId: "recipe-pumpkin-v2",
      ...audit,
    });

    expect(released.accepted).toBe(true);
    expect(released.releasedReference).toMatchObject({
      recipeVersionId: "recipe-pumpkin-v2",
      effect: "FUTURE_PLANNING_REFERENCE_ONLY",
    });
    expect(released.state.downstreamRecipeUsage).toEqual(priorFacts);
    expect(state.downstreamRecipeUsage).toEqual(priorFacts);
    expect(new Set(priorFacts.map((fact) => fact.domain))).toEqual(
      new Set([
        "PLANNING",
        "NEED_GENERATION",
        "CONFIRMED_NEED",
        "PURCHASE_HANDOFF",
      ]),
    );
  });

  it("exposes explicit operational boundaries and no prohibited technology state", () => {
    const school = createSchoolReadModel(schoolAdminFixture);
    const ingredient = createIngredientSupplierReadModel(
      ingredientSupplierAdminFixture,
    );
    const recipe = createDishRecipeReadModel(
      dishRecipeAdminFixture,
      "dish-pumpkin-soup",
      "recipe-pumpkin-v2",
    );
    const boundaryCopy = [
      school.boundaryNote,
      ingredient.boundaryNote,
      recipe.boundaryNote,
    ].join(" ");
    for (const boundary of [
      "Planning recalculation",
      "Procurement assignment",
      "supplier confirmation",
      "supplier commitments",
      "Warehouse movement",
      "QA approval",
      "Production execution",
      "Finance/Accounting",
    ])
      expect(boundaryCopy).toContain(boundary);

    const forbiddenStateFields = [
      "supabaseClient",
      "retoolQuery",
      "backendCommand",
      "credential",
      "productionData",
      "planningRecalculation",
      "purchaseOrderId",
      "supplierConfirmationId",
      "stockMovementId",
      "qaApprovalId",
      "productionExecutionId",
      "invoiceId",
      "accountingEntryId",
    ];
    const keys = objectKeys({
      school: schoolAdminFixture,
      ingredient: ingredientSupplierAdminFixture,
      recipe: dishRecipeAdminFixture,
    });
    expect(keys).not.toEqual(expect.arrayContaining(forbiddenStateFields));
  });
});
