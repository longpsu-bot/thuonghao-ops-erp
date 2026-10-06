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
import { success } from "./planning/planningReviewFixtures";
import {
  createLegibilitySystem,
  LegibilityPrototypeSwitcher,
  type LegibilityVariant,
} from "./AtlasLegibilityVariants.prototype";
function Review() {
  const params = new URLSearchParams(window.location.search);
  const requestedVariant = params.get("legibility");
  const variant = ["A", "B", "C"].includes(requestedVariant ?? "")
    ? (requestedVariant as LegibilityVariant)
    : null;
  const system = useMemo(
    () => (variant ? createLegibilitySystem(variant) : undefined),
    [variant],
  );
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
    if (scenario === "missingRecipeUnit") {
      const recipe = createRecipeReviewFixture("DISH_ACTIVE_EDITABLE");
      recipe.data.ingredients[3].purchase_unit_id = null;
      recipe.data.ingredients[3].purchase_unit_name = null;
      fixture.recipe = recipe.api;
    }
    if (scenario === "invalidMenuCell") {
      fixture.planning.syncMenuFromGoogle = async () =>
        success({
          source: { source_name: "Thực đơn chính thức", sheet_name: "Tuần 37" },
          fetched_at: "2026-09-07T01:00:00Z",
          rows: [
            ["Tên trường", "Ngày", "Món canh"],
            ["TH001", "2026-09-07", "CANH2"],
            ["TH002", "2026-09-07", "Món chưa có trong danh mục"],
          ],
        });
    }
    if (scenario === "pendingValidMenu") {
      // Review-only pending Preview snapshot; normal valid sync still saves immediately.
      fixture.planning.previewMenu = async () => new Promise(() => {});
    }
    return fixture;
  }, []);
  return (
    <AtlasVNextProvider system={system}>
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
      {variant && <LegibilityPrototypeSwitcher variant={variant} />}
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
