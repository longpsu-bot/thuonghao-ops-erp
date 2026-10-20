// Disposable certification entry: real Auth, PostgREST, APIs and operator UI.
// No SQL transport, review API, mocked result or browser privileged credential.
import React, { useMemo } from "react";
import { createRoot } from "react-dom/client";
import { AtlasVNextProvider } from "../../src/vnext/atlas/AtlasVNextProvider";
import { AtlasSessionGate } from "../../src/vnext/atlas/AtlasSessionGate";
import { ProcurementWorkbench } from "../../src/vnext/atlas/procurement/ProcurementWorkbench";
import { SchoolPxkWorkbench } from "../../src/vnext/atlas/dispatch/SchoolPxkWorkbench";
import { SchoolFulfilmentWorkbench } from "../../src/vnext/atlas/reconciliation/SchoolFulfilmentWorkbench";
import { getAtlasSupabaseClient } from "../../src/modules/atlas/connection/supabaseClient";
import { readAtlasBrowserEnvironment } from "../../src/modules/atlas/connection/environment";
import { useAtlasAuthSession } from "../../src/modules/atlas/connection/authSession";
import { createAtlasRpcTransport } from "../../src/modules/atlas/connection/atlasRpc";
import { createPurchaseReviewApi } from "../../src/modules/atlas/procurement/purchaseReviewApi";
import { createSchoolCateringProcurementApi } from "../../src/modules/atlas/procurement/schoolCateringProcurementApi";
import { createSchoolDispatchReleaseApi } from "../../src/modules/atlas/dispatch/schoolDispatchReleaseApi";
import { createSchoolFulfilmentReconciliationApi } from "../../src/modules/atlas/dispatch/schoolFulfilmentReconciliationApi";
import {
  downloadSchoolDispatchXlsx,
  downloadSchoolDispatchPdf,
} from "../../src/modules/atlas/dispatch/schoolDispatchReleaseExports";
import {
  downloadPurchaseOrderXlsx,
  downloadPurchaseOrderPdf,
  downloadPurchaseOrderZip,
} from "../../src/modules/atlas/procurement/purchaseOrderExports";

if (
  location.hostname !== "127.0.0.1" ||
  import.meta.env.VITE_ATLAS_ENVIRONMENT !== "local"
)
  throw new Error("DISPOSABLE_ONLY");
const connection = getAtlasSupabaseClient();
const environment = readAtlasBrowserEnvironment();
if (
  connection.status !== "configured" ||
  environment.status !== "configured" ||
  environment.config.supabaseUrl !== "http://127.0.0.1:54321"
)
  throw new Error("DISPOSABLE_API_ONLY");
function ConnectedProcurement() {
  const auth = useAtlasAuthSession(connection);
  const apis = useMemo(() => {
    if (connection.status !== "configured")
      throw new Error("DISPOSABLE_CONNECTION_REQUIRED");
    const transport = createAtlasRpcTransport(connection.client);
    return {
      purchaseReviewApi: createPurchaseReviewApi(transport),
      procurementApi: createSchoolCateringProcurementApi(transport),
      dispatchApi: createSchoolDispatchReleaseApi(transport),
      reconciliationApi: createSchoolFulfilmentReconciliationApi(transport),
    };
  }, []);
  return (
    <AtlasVNextProvider>
      <AtlasSessionGate
        session={{ status: auth.state.status }}
        safeAuthError={auth.safeAuthError}
        onSignIn={auth.signIn}
      >
        {auth.state.status === "authenticated" &&
          (new URLSearchParams(location.search).get("stage") === "pxk" ? (
            <SchoolPxkWorkbench
              api={apis.dispatchApi}
              authSubject={auth.state.authSubject}
              initialServiceDate="2050-09-19"
              onExportXlsx={downloadSchoolDispatchXlsx}
              onExportPdf={downloadSchoolDispatchPdf}
            />
          ) : new URLSearchParams(location.search).get("stage") ===
            "reconciliation" ? (
            <SchoolFulfilmentWorkbench
              api={apis.reconciliationApi}
              authSubject={auth.state.authSubject}
              initialDateStart="2050-09-19"
              initialDateEnd="2050-09-19"
            />
          ) : (
            <ProcurementWorkbench
              {...apis}
              authSubject={auth.state.authSubject}
              initialServiceDate="2050-09-19"
              ownerStage={
                new URLSearchParams(location.search).get("stage") ===
                "allocation"
                  ? "allocation"
                  : "orders"
              }
              onExportXlsx={downloadPurchaseOrderXlsx}
              onExportPdf={downloadPurchaseOrderPdf}
              onExportZip={downloadPurchaseOrderZip}
            />
          ))}
      </AtlasSessionGate>
    </AtlasVNextProvider>
  );
}
createRoot(document.getElementById("root")!).render(<ConnectedProcurement />);
