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
import { Capacity } from "./AtlasWorkspaceCapacity.stories";
import { createConfirmedNeedReviewFixture } from "./planning-confirmed/confirmedNeedReviewFixtures";
import { createRecipeReviewFixture } from "./recipes/recipeReviewFixtures";
import { createSchoolPxkReviewFixture } from "./dispatch/schoolPxkReviewFixtures";
function Review() {
  const params = new URLSearchParams(window.location.search);
  const [signedIn, setSignedIn] = useState(
    params.get("session") !== "unauthenticated",
  );
  const apis = useMemo(() => {
    const fixture = createAtlasApplicationFixture();
    const scenario = params.get("scenario");
    if (
      ["blocked", "error", "empty", "loading", "stale", "ready"].includes(
        scenario ?? "",
      )
    ) {
      const need = createConfirmedNeedReviewFixture(
        scenario === "error"
          ? "read_failure"
          : scenario === "empty"
            ? "no_demand"
            : scenario === "loading"
              ? "loading"
              : scenario === "ready"
                ? "normal"
                : scenario === "stale"
                  ? "stale"
                  : "blocked",
      );
      fixture.planningReadiness = need.preflightApi;
      fixture.needGeneration = need.needGenerationApi;
      fixture.confirmedNeed = need.confirmedNeedApi;
      const procurement = createProcurementReviewFixture(
        scenario === "error"
          ? "read_failure"
          : scenario === "empty"
            ? "empty"
            : scenario === "ready"
              ? "ready"
              : scenario === "stale"
                ? "po_stale"
                : "blocked",
      );
      fixture.purchaseReview = procurement.purchaseReviewApi;
      fixture.procurement = procurement.procurementApi;
      fixture.recipe = createRecipeReviewFixture(
        scenario === "error"
          ? "READ_FAILURE"
          : scenario === "empty"
            ? "EMPTY_CATALOG"
            : scenario === "ready"
              ? "DISH_ACTIVE_EDITABLE"
              : "DISH_ACTIVE_LOCKED",
      ).api;
      fixture.schoolDispatch = createSchoolPxkReviewFixture(
        scenario === "error"
          ? "READ_FAILURE"
          : scenario === "empty"
            ? "EMPTY"
            : scenario === "ready"
              ? "READY"
              : scenario === "stale"
                ? "STALE"
                : "BLOCKED",
      );
      if (scenario === "loading") {
        fixture.purchaseReview.getConfirmedAllocations = async () =>
          new Promise(() => {});
        fixture.recipe.getWorkbench = async () => new Promise(() => {});
        fixture.schoolDispatch.getWorkbench = async () => new Promise(() => {});
      }
    }
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
createRoot(document.getElementById("root")!).render(
  new URLSearchParams(window.location.search).has("capacity") ? (
    <Capacity />
  ) : (
    <Review />
  ),
);
