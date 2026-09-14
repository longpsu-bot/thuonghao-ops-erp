import "@testing-library/jest-dom/vitest";
import { cleanup, render, screen } from "@testing-library/react";
import { afterEach, expect, it, vi } from "vitest";
import { AtlasVNextConnectedApp } from "./AtlasVNextConnectedApp";
import type { AtlasVNextAppProps } from "./vnext/atlas/AtlasVNextApp";
import type { AtlasSupabaseClientResult } from "./modules/atlas/connection/supabaseClient";
import * as masterDataFactory from "./modules/atlas/master-data/masterDataApi";
import * as recipeFactory from "./modules/atlas/recipes/recipeApi";
import * as recipeAdjustmentFactory from "./modules/atlas/recipe-adjustments/recipeAdjustmentApi";
import * as planningFactory from "./modules/atlas/planning-inputs/planningInputsApi";
import * as pantryFactory from "./modules/atlas/planning-inputs/pantry/pantryApi";
import * as planningReadinessFactory from "./modules/atlas/planning-inputs/readiness/planningInputReadinessApi";
import * as needGenerationFactory from "./modules/atlas/planning-inputs/need-generation/needGenerationApi";
import * as confirmedNeedFactory from "./modules/atlas/planning-inputs/confirmed-needs/confirmedNeedApi";
import * as purchaseReviewFactory from "./modules/atlas/procurement/purchaseReviewApi";
import * as procurementFactory from "./modules/atlas/procurement/schoolCateringProcurementApi";
import * as schoolDispatchFactory from "./modules/atlas/dispatch/schoolDispatchReleaseApi";
import * as reconciliationFactory from "./modules/atlas/dispatch/schoolFulfilmentReconciliationApi";
const observed = vi.hoisted(() => ({
  props: null as AtlasVNextAppProps | null,
}));
vi.mock("./vnext/atlas/AtlasVNextApp", () => ({
  AtlasVNextApp: (props: AtlasVNextAppProps) => {
    observed.props = props;
    return <h1>Connected application</h1>;
  },
}));
vi.mock("./modules/atlas/connection/authSession", () => ({
  useAtlasAuthSession: () => ({
    state: {
      status: "authenticated",
      authSubject: "subject-a",
      user: { email: "operator@example.test" },
    },
    signIn: vi.fn(),
    signOut: vi.fn(),
    safeAuthError: null,
  }),
}));
afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
  observed.props = null;
});
it("builds each reviewed API factory once, reuses its bundle, and supplies exporters", () => {
  const masterData = vi.spyOn(masterDataFactory, "createMasterDataApi");
  const recipe = vi.spyOn(recipeFactory, "createRecipeApi");
  const recipeAdjustment = vi.spyOn(
    recipeAdjustmentFactory,
    "createRecipeAdjustmentApi",
  );
  const planning = vi.spyOn(planningFactory, "createPlanningInputsApi");
  const pantry = vi.spyOn(pantryFactory, "createPantryApi");
  const planningReadiness = vi.spyOn(
    planningReadinessFactory,
    "createPlanningInputReadinessApi",
  );
  const needGeneration = vi.spyOn(
    needGenerationFactory,
    "createNeedGenerationApi",
  );
  const confirmedNeed = vi.spyOn(
    confirmedNeedFactory,
    "createConfirmedNeedApi",
  );
  const purchaseReview = vi.spyOn(
    purchaseReviewFactory,
    "createPurchaseReviewApi",
  );
  const procurement = vi.spyOn(
    procurementFactory,
    "createSchoolCateringProcurementApi",
  );
  const schoolDispatch = vi.spyOn(
    schoolDispatchFactory,
    "createSchoolDispatchReleaseApi",
  );
  const reconciliation = vi.spyOn(
    reconciliationFactory,
    "createSchoolFulfilmentReconciliationApi",
  );
  const rpc = vi.fn();
  const connection = {
    status: "configured",
    client: { rpc },
    environmentLabel: "Local · non-production",
  } as unknown as AtlasSupabaseClientResult;
  const { rerender } = render(
    <AtlasVNextConnectedApp connection={connection} />,
  );
  expect(
    screen.getByRole("heading", { name: "Connected application" }),
  ).toBeInTheDocument();
  const apis = observed.props!.apis;
  rerender(<AtlasVNextConnectedApp connection={connection} />);
  expect(observed.props!.apis).toBe(apis);
  expect(masterData).toHaveBeenCalledOnce();
  expect(apis.masterData).toBe(masterData.mock.results[0]!.value);
  expect(recipe).toHaveBeenCalledOnce();
  expect(apis.recipe).toBe(recipe.mock.results[0]!.value);
  expect(recipeAdjustment).toHaveBeenCalledOnce();
  expect(apis.recipeAdjustment).toBe(recipeAdjustment.mock.results[0]!.value);
  expect(planning).toHaveBeenCalledOnce();
  expect(apis.planning).toBe(planning.mock.results[0]!.value);
  expect(pantry).toHaveBeenCalledOnce();
  expect(apis.pantry).toBe(pantry.mock.results[0]!.value);
  expect(planningReadiness).toHaveBeenCalledOnce();
  expect(apis.planningReadiness).toBe(planningReadiness.mock.results[0]!.value);
  expect(needGeneration).toHaveBeenCalledOnce();
  expect(apis.needGeneration).toBe(needGeneration.mock.results[0]!.value);
  expect(confirmedNeed).toHaveBeenCalledOnce();
  expect(apis.confirmedNeed).toBe(confirmedNeed.mock.results[0]!.value);
  expect(purchaseReview).toHaveBeenCalledOnce();
  expect(apis.purchaseReview).toBe(purchaseReview.mock.results[0]!.value);
  expect(procurement).toHaveBeenCalledOnce();
  expect(apis.procurement).toBe(procurement.mock.results[0]!.value);
  expect(schoolDispatch).toHaveBeenCalledOnce();
  expect(apis.schoolDispatch).toBe(schoolDispatch.mock.results[0]!.value);
  expect(reconciliation).toHaveBeenCalledOnce();
  expect(apis.reconciliation).toBe(reconciliation.mock.results[0]!.value);
  expect(Object.keys(observed.props!.exporters!).sort()).toEqual([
    "procurementPdf",
    "procurementXlsx",
    "pxkGroupedXlsx",
    "pxkPdf",
    "pxkXlsx",
    "shoppingListImport",
    "shoppingListXlsx",
  ]);
  expect(
    Object.values(observed.props!.exporters!).every(
      (v) => typeof v === "function",
    ),
  ).toBe(true);
  expect(rpc).not.toHaveBeenCalled();
  expect(observed.props!.userLabel).toBe("operator@example.test");
});
