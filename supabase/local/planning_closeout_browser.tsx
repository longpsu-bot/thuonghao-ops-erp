// Disposable loopback certification with real Auth/PostgREST and operator UI.
import React, { useMemo } from "react";
import { createRoot } from "react-dom/client";
import { AtlasVNextProvider } from "../../src/vnext/atlas/AtlasVNextProvider";
import { ConfirmedNeedWorkbench } from "../../src/vnext/atlas/planning-confirmed/ConfirmedNeedWorkbench";
import { AtlasSessionGate } from "../../src/vnext/atlas/AtlasSessionGate";
import { getAtlasSupabaseClient } from "../../src/modules/atlas/connection/supabaseClient";
import { readAtlasBrowserEnvironment } from "../../src/modules/atlas/connection/environment";
import { useAtlasAuthSession } from "../../src/modules/atlas/connection/authSession";
import { createAtlasRpcTransport } from "../../src/modules/atlas/connection/atlasRpc";
import { createPlanningInputReadinessApi } from "../../src/modules/atlas/planning-inputs/readiness/planningInputReadinessApi";
import { createNeedGenerationApi } from "../../src/modules/atlas/planning-inputs/need-generation/needGenerationApi";
import { createConfirmedNeedApi } from "../../src/modules/atlas/planning-inputs/confirmed-needs/confirmedNeedApi";
import { createConnectedShoppingListService } from "../../src/modules/atlas/planning-inputs/confirmed-needs/shoppingListService";

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
function ConnectedPlanning() {
  const auth = useAtlasAuthSession(connection);
  const apis = useMemo(() => {
    if (connection.status !== "configured")
      throw new Error("DISPOSABLE_CONNECTION_REQUIRED");
    const transport = createAtlasRpcTransport(connection.client);
    return {
      preflight: createPlanningInputReadinessApi(transport),
      need: createNeedGenerationApi(transport),
      confirmed: createConfirmedNeedApi(transport),
    };
  }, []);
  const shopping = useMemo(
    () =>
      auth.state.status === "authenticated"
        ? createConnectedShoppingListService(
            apis.confirmed,
            apis.preflight,
            auth.state.authSubject,
          )
        : undefined,
    [apis, auth.state],
  );
  return (
    <AtlasVNextProvider>
      <AtlasSessionGate
        session={{ status: auth.state.status }}
        safeAuthError={auth.safeAuthError}
        onSignIn={auth.signIn}
      >
        {auth.state.status === "authenticated" && shopping && (
          <ConfirmedNeedWorkbench
            authSubject={auth.state.authSubject}
            initialServiceDate="2050-09-19"
            preflightApi={apis.preflight}
            needGenerationApi={apis.need}
            confirmedNeedApi={apis.confirmed}
            onExportShoppingList={shopping.export}
            onImportShoppingList={shopping.import}
          />
        )}
      </AtlasSessionGate>
    </AtlasVNextProvider>
  );
}
createRoot(document.getElementById("root")!).render(<ConnectedPlanning />);
