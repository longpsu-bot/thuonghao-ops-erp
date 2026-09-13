import type { SchoolMasterDataApi } from "./bridges/schoolMasterData";
import type { IngredientSupplierMasterDataApi } from "./bridges/ingredientSupplierMasterData";
import type { DishRecipeApi } from "./bridges/dishRecipe";
import type { RecipeAdjustmentApi } from "./bridges/recipeAdjustment";
import type { PlanningInputsApi, PantryApi } from "./bridges/planning";
import type {
  PreflightApi,
  NeedGenerationApi,
  ConfirmedNeedApi,
} from "./bridges/confirmedNeed";
import type {
  PurchaseReviewApi,
  SchoolCateringProcurementApi,
} from "./bridges/procurement";
import type { SchoolDispatchReleaseApi } from "./bridges/schoolDispatch";
import type { SchoolFulfilmentReconciliationApi } from "./bridges/schoolFulfilment";

export type AtlasVNextApis = {
  masterData: SchoolMasterDataApi & IngredientSupplierMasterDataApi;
  recipe: DishRecipeApi;
  recipeAdjustment: RecipeAdjustmentApi;
  planning: Pick<
    PlanningInputsApi,
    | "getWorkbench"
    | "previewMenu"
    | "previewAttendance"
    | "syncMenuFromGoogle"
    | "saveCompletedMenu"
    | "saveCompletedAttendance"
    | "getCorrectionImpact"
    | "prepareCorrection"
  >;
  pantry: Pick<
    PantryApi,
    | "getWorkbench"
    | "preview"
    | "saveCompleted"
    | "getCorrectionImpact"
    | "prepareCorrection"
  >;
  planningReadiness: PreflightApi;
  needGeneration: NeedGenerationApi;
  confirmedNeed: ConfirmedNeedApi;
  purchaseReview: PurchaseReviewApi;
  procurement: SchoolCateringProcurementApi;
  schoolDispatch: SchoolDispatchReleaseApi;
  reconciliation: SchoolFulfilmentReconciliationApi;
};
