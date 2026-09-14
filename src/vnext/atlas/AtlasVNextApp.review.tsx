// Explicit opt-in local fixture entry. Not imported by the production entrypoint.
import { createRoot } from "react-dom/client";
import { useMemo, useState } from "react";
import { AtlasVNextApp } from "./AtlasVNextApp";
import { AtlasVNextProvider } from "./AtlasVNextProvider";
import { AtlasSessionGate } from "./AtlasSessionGate";
import {
  createAtlasApplicationFixture,
  applicationReviewNow,
} from "./atlasApplicationReviewFixtures";
import { createProcurementReviewFixture } from "./procurement/procurementReviewFixtures";
function Review() {
  const params = new URLSearchParams(window.location.search);
  const [signedIn, setSignedIn] = useState(
    params.get("session") !== "unauthenticated",
  );
  const apis = useMemo(() => {
    const fixture = createAtlasApplicationFixture();
    if (params.get("scenario") === "unknown") {
      const procurement = createProcurementReviewFixture("unknown");
      fixture.purchaseReview = procurement.purchaseReviewApi;
      fixture.procurement = procurement.procurementApi;
    }
    return fixture;
  }, []);
  return (
    <AtlasVNextProvider>
      <AtlasSessionGate
        session={{ status: signedIn ? "authenticated" : "unauthenticated" }}
        onSignIn={async () => {
          setSignedIn(true);
          return true;
        }}
      >
        <AtlasVNextApp
          apis={apis}
          authSubject="fixture-operator"
          userLabel="vanhanh@example.test"
          environmentLabel="Local"
          now={applicationReviewNow}
          onSignOut={() => setSignedIn(false)}
          exporters={{
            procurementXlsx: () => {},
            procurementPdf: () => {},
            pxkXlsx: () => {},
            pxkPdf: () => {},
            pxkGroupedXlsx: () => {},
            shoppingListXlsx: async () => {},
            shoppingListImport: async (_file, _workbench, drafts) => ({
              drafts,
              changedLineIds: [],
            }),
          }}
        />
      </AtlasSessionGate>
    </AtlasVNextProvider>
  );
}
createRoot(document.getElementById("root")!).render(<Review />);
