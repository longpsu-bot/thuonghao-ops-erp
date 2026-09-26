import type { SchoolFulfilmentScope } from "./bridges/schoolFulfilment";
import type { AtlasVNextApis } from "./AtlasVNextApis";
import { createSchoolDefaultsReviewFixture } from "./schools/schoolDefaultsReviewFixtures";
import { createIngredientSupplierReviewFixture } from "./master-data/ingredientSupplierReviewFixtures";
import { createRecipeReviewFixture } from "./recipes/recipeReviewFixtures";
import { createChangeOrderFixture } from "./recipes/changeOrderReviewFixtures";
import { createPlanningReviewFixture } from "./planning/planningReviewFixtures";
import { createConfirmedNeedReviewFixture } from "./planning-confirmed/confirmedNeedReviewFixtures";
import {
  createProcurementReviewFixture,
  type ProcurementReviewScenario,
} from "./procurement/procurementReviewFixtures";
import { createSchoolPxkReviewFixture } from "./dispatch/schoolPxkReviewFixtures";
import {
  fulfilmentRow,
  fulfilmentData,
  fulfilmentSuccess,
} from "./reconciliation/schoolFulfilmentReviewFixtures";

export const applicationReviewDate = "2026-09-07";
export const applicationReviewNow = new Date("2026-09-07T03:00:00Z");
export function createAtlasApplicationFixture(
  procurementScenario: ProcurementReviewScenario = "manual_split",
): AtlasVNextApis {
  const planning = createPlanningReviewFixture();
  const confirmed = createConfirmedNeedReviewFixture();
  const procurement = createProcurementReviewFixture(procurementScenario);
  const preflightRead = confirmed.preflightApi.preflight;
  confirmed.preflightApi.preflight = async (...args) =>
    snapshotDate(await preflightRead(...args), applicationReviewDate, args[2]);
  const confirmedRead = confirmed.confirmedNeedApi.getReview;
  confirmed.confirmedNeedApi.getReview = async (...args) =>
    snapshotDate(
      await confirmedRead(...args),
      applicationReviewDate,
      args[3].service_date ?? applicationReviewDate,
    );
  return {
    masterData: {
      ...createIngredientSupplierReviewFixture(),
      ...createSchoolDefaultsReviewFixture(),
    },
    recipe: createRecipeReviewFixture("DISH_ACTIVE_EDITABLE").api,
    recipeAdjustment: createChangeOrderFixture("ACTIVE").api,
    planning: planning.api,
    pantry: planning.pantryApi,
    planningReadiness: confirmed.preflightApi,
    needGeneration: confirmed.needGenerationApi,
    confirmedNeed: confirmed.confirmedNeedApi,
    purchaseReview: procurement.purchaseReviewApi,
    procurement: procurement.procurementApi,
    schoolDispatch: createSchoolPxkReviewFixture("READY"),
    reconciliation: {
      async getWorkbench(request) {
        const scope = request.payload as SchoolFulfilmentScope;
        return fulfilmentSuccess(
          fulfilmentData(
            [fulfilmentRow({ service_date: scope.date_start })],
            scope.date_start,
            scope.date_end,
          ),
        );
      },
    },
  };
}

// Date-stamped copies of explicit certified snapshots, with no business calculation.
function snapshotDate<T>(snapshot: T, from: string, to: string): T {
  return JSON.parse(JSON.stringify(snapshot).replaceAll(from, to)) as T;
}
