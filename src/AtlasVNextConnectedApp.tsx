import { useMemo } from "react";
import { createMasterDataApi } from "./modules/atlas/master-data/masterDataApi";
import { createRecipeApi } from "./modules/atlas/recipes/recipeApi";
import { createRecipeAdjustmentApi } from "./modules/atlas/recipe-adjustments/recipeAdjustmentApi";
import { createPlanningInputsApi } from "./modules/atlas/planning-inputs/planningInputsApi";
import { createPantryApi } from "./modules/atlas/planning-inputs/pantry/pantryApi";
import { createPlanningInputReadinessApi } from "./modules/atlas/planning-inputs/readiness/planningInputReadinessApi";
import { createNeedGenerationApi } from "./modules/atlas/planning-inputs/need-generation/needGenerationApi";
import { createConfirmedNeedApi } from "./modules/atlas/planning-inputs/confirmed-needs/confirmedNeedApi";
import { createPurchaseReviewApi } from "./modules/atlas/procurement/purchaseReviewApi";
import { createSchoolCateringProcurementApi } from "./modules/atlas/procurement/schoolCateringProcurementApi";
import { createSchoolDispatchReleaseApi } from "./modules/atlas/dispatch/schoolDispatchReleaseApi";
import { createSchoolFulfilmentReconciliationApi } from "./modules/atlas/dispatch/schoolFulfilmentReconciliationApi";
import {
  getAtlasSupabaseClient,
  type AtlasSupabaseClientResult,
} from "./modules/atlas/connection/supabaseClient";
import { useAtlasAuthSession } from "./modules/atlas/connection/authSession";
import { createAtlasRpcTransport } from "./modules/atlas/connection/atlasRpc";
import {
  downloadPurchaseOrderXlsx,
  downloadPurchaseOrderPdf,
} from "./modules/atlas/procurement/purchaseOrderExports";
import {
  downloadSchoolDispatchXlsx,
  downloadSchoolDispatchPdf,
  downloadGroupedSchoolDispatchXlsx,
} from "./modules/atlas/dispatch/schoolDispatchReleaseExports";
import { AtlasVNextProvider } from "./vnext/atlas/AtlasVNextProvider";
import { AtlasSessionGate } from "./vnext/atlas/AtlasSessionGate";
import { AtlasVNextApp } from "./vnext/atlas/AtlasVNextApp";
import type { AtlasVNextApis } from "./vnext/atlas/AtlasVNextApis";
import {
  downloadConfirmedNeedShoppingList,
  importConfirmedNeedShoppingList,
} from "./modules/atlas/planning-inputs/confirmed-needs/confirmedNeedShoppingList";
const exporters = {
  procurementXlsx: downloadPurchaseOrderXlsx,
  procurementPdf: downloadPurchaseOrderPdf,
  pxkXlsx: downloadSchoolDispatchXlsx,
  pxkPdf: downloadSchoolDispatchPdf,
  pxkGroupedXlsx: downloadGroupedSchoolDispatchXlsx,
  shoppingListXlsx: downloadConfirmedNeedShoppingList,
  shoppingListImport: importConfirmedNeedShoppingList,
};
export function AtlasVNextConnectedApp({
  connection: suppliedConnection,
}: {
  connection?: AtlasSupabaseClientResult;
} = {}) {
  const connection = useMemo(
    () => suppliedConnection ?? getAtlasSupabaseClient(),
    [suppliedConnection],
  );
  const auth = useAtlasAuthSession(connection);
  const transport = useMemo(
    () =>
      connection.status === "configured"
        ? createAtlasRpcTransport(connection.client)
        : undefined,
    [connection],
  );
  const apis = useMemo<AtlasVNextApis | undefined>(
    () =>
      transport
        ? {
            masterData: createMasterDataApi(transport),
            recipe: createRecipeApi(transport),
            recipeAdjustment: createRecipeAdjustmentApi(transport),
            planning: createPlanningInputsApi(transport),
            pantry: createPantryApi(transport),
            planningReadiness: createPlanningInputReadinessApi(transport),
            needGeneration: createNeedGenerationApi(transport),
            confirmedNeed: createConfirmedNeedApi(transport),
            purchaseReview: createPurchaseReviewApi(transport),
            procurement: createSchoolCateringProcurementApi(transport),
            schoolDispatch: createSchoolDispatchReleaseApi(transport),
            reconciliation: createSchoolFulfilmentReconciliationApi(transport),
          }
        : undefined,
    [transport],
  );
  return (
    <AtlasVNextProvider>
      <AtlasSessionGate
        session={{
          status: auth.state.status,
          safeMessage:
            auth.state.status === "session_expired"
              ? auth.state.safeMessage
              : undefined,
        }}
        safeAuthError={auth.safeAuthError}
        onSignIn={auth.signIn}
      >
        {auth.state.status === "authenticated" && apis && (
          <AtlasVNextApp
            authSubject={auth.state.authSubject}
            apis={apis}
            userLabel={auth.state.user.email ?? "Người vận hành"}
            environmentLabel={
              connection.status === "configured"
                ? connection.environmentLabel
                : undefined
            }
            onSignOut={() => {
              void auth.signOut();
            }}
            safeAuthError={auth.safeAuthError}
            exporters={exporters}
          />
        )}
      </AtlasSessionGate>
    </AtlasVNextProvider>
  );
}
