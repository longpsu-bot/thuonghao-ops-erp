import type { SchoolFulfilmentScope } from "./bridges/schoolFulfilment";
import type { AtlasVNextApis } from "./AtlasVNextApis";
import { createSchoolDefaultsReviewFixture } from "./schools/schoolDefaultsReviewFixtures";
import { createIngredientSupplierReviewFixture } from "./master-data/ingredientSupplierReviewFixtures";
import { createRecipeReviewFixture } from "./recipes/recipeReviewFixtures";
import { createChangeOrderFixture } from "./recipes/changeOrderReviewFixtures";
import { createPlanningReviewFixture } from "./planning/planningReviewFixtures";
import { createConfirmedNeedReviewFixture } from "./planning-confirmed/confirmedNeedReviewFixtures";
import { createProcurementReviewFixture } from "./procurement/procurementReviewFixtures";
import { createSchoolPxkReviewFixture } from "./dispatch/schoolPxkReviewFixtures";
import {
  fulfilmentRow,
  fulfilmentData,
  fulfilmentSuccess,
} from "./reconciliation/schoolFulfilmentReviewFixtures";

export const applicationReviewDate = "2026-09-07";
export const applicationReviewNow = new Date("2026-09-07T03:00:00Z");
export function createAtlasApplicationFixture(): AtlasVNextApis {
  const planning = createPlanningReviewFixture();
  const confirmed = createConfirmedNeedReviewFixture();
  const procurement = createProcurementReviewFixture("manual_split");
  const dailyNeed = new Map([[applicationReviewDate, confirmed]]);
  const needFor = (date: string) => {
    if (!dailyNeed.has(date))
      dailyNeed.set(date, createConfirmedNeedReviewFixture("normal", date));
    return dailyNeed.get(date)!;
  };
  const batchDate = (id: string) =>
    /\d{4}-\d{2}-\d{2}$/.exec(id)?.[0] ?? applicationReviewDate;
  const confirmedNeed = {
    ...confirmed.confirmedNeedApi,
    getReview: ((...args) =>
      needFor(
        args[3].service_date ?? applicationReviewDate,
      ).confirmedNeedApi.getReview(
        ...args,
      )) as typeof confirmed.confirmedNeedApi.getReview,
    save: ((request) =>
      needFor(
        batchDate(request.payload.confirmed_need_batch_id),
      ).confirmedNeedApi.save(
        request,
      )) as typeof confirmed.confirmedNeedApi.save,
    previewCorrection: ((request) =>
      needFor(
        batchDate(request.payload.confirmed_need_batch_id),
      ).confirmedNeedApi.previewCorrection(
        request,
      )) as typeof confirmed.confirmedNeedApi.previewCorrection,
    correct: ((request) =>
      needFor(
        batchDate(request.payload.confirmed_need_batch_id),
      ).confirmedNeedApi.correct(
        request,
      )) as typeof confirmed.confirmedNeedApi.correct,
  };
  return {
    masterData: {
      ...createIngredientSupplierReviewFixture(),
      ...createSchoolDefaultsReviewFixture(),
    },
    recipe: createRecipeReviewFixture("DISH_ACTIVE_EDITABLE").api,
    recipeAdjustment: createChangeOrderFixture("ACTIVE").api,
    planning: planning.api,
    pantry: planning.pantryApi,
    planningReadiness: {
      preflight: (...args) => needFor(args[2]).preflightApi.preflight(...args),
    },
    needGeneration: confirmed.needGenerationApi,
    confirmedNeed,
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
