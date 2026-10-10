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
import {
  createProcurementReviewFixture,
  reviewOrder,
  reviewSuccess,
} from "./procurement/procurementReviewFixtures";
import { Capacity } from "./AtlasWorkspaceCapacity.stories";
import { createConfirmedNeedReviewFixture } from "./planning-confirmed/confirmedNeedReviewFixtures";
import { createRecipeReviewFixture } from "./recipes/recipeReviewFixtures";
import {
  createSchoolPxkReviewFixture,
  pxkData,
  pxkRow,
  pxkSuccess,
} from "./dispatch/schoolPxkReviewFixtures";
import { success } from "./planning/planningReviewFixtures";
import { ProcurementWorkbench } from "./procurement/ProcurementWorkbench";
function Review() {
  const params = new URLSearchParams(window.location.search);
  const [signedIn, setSignedIn] = useState(
    params.get("session") !== "unauthenticated",
  );
  const apis = useMemo(() => {
    const fixture = createAtlasApplicationFixture();
    const rangeReview = params.get("scenario") === "range";
    const scenario = rangeReview ? "ready" : params.get("scenario");
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
    if (rangeReview) {
      // Explicit dated review snapshots only; no production adapter or hosted writes.
      const datesIn = (start: string, end: string) => {
        const dates: string[] = [];
        for (
          let date = new Date(`${start}T00:00:00Z`);
          date.toISOString().slice(0, 10) <= end;
          date.setUTCDate(date.getUTCDate() + 1)
        ) {
          dates.push(date.toISOString().slice(0, 10));
        }
        return dates;
      };
      fixture.procurement.getPurchaseOrders = async (request) => {
        const payload = request.payload as {
          date_start: string;
          date_end: string;
        };
        return reviewSuccess({
          success: true,
          contract_version: "SCHOOL-CATERING-PROCUREMENT.v1",
          date_start: payload.date_start,
          date_end: payload.date_end,
          procurement_current: true,
          blockers: [],
          warnings: [],
          purchase_orders: datesIn(payload.date_start, payload.date_end).map(
            (date, index) => {
              const order = reviewOrder(
                index % 3 === 2 ? "po_draft" : "po_released",
              );
              return {
                ...order,
                purchase_order_id: `review-order-${date}`,
                service_date: date,
                document_number: order.document_number
                  ? `PO-${date.replaceAll("-", "")}-53`
                  : null,
                lines: order.lines.map((line) => ({
                  ...line,
                  service_date: date,
                })),
              };
            },
          ),
        });
      };
      fixture.schoolDispatch.getWorkbench = async (request) => {
        const payload = request.payload as {
          date_start: string;
          date_end: string;
          school_ids: string[];
        };
        const rows = datesIn(payload.date_start, payload.date_end)
          .map((date, index) => {
            const row = pxkRow(
              index % 3 === 2 ? "READY" : "CURRENT",
              (index % 3) + 1,
            );
            const document = row.current_release
              ? {
                  ...row.current_release,
                  service_date: date,
                  school_dispatch_release_id: `review-release-${date}`,
                  document_number: `PXK-${date.replaceAll("-", "")}-${index + 1}`,
                }
              : null;
            return {
              ...row,
              service_date: date,
              preview: { ...row.preview, service_date: date },
              current_release: document,
              history: document ? [document] : [],
            };
          })
          .filter(
            (row) =>
              !payload.school_ids.length ||
              payload.school_ids.includes(row.school_id),
          );
        return pxkSuccess({
          ...pxkData(rows, payload.date_start),
          date_end: payload.date_end,
        });
      };
    }
    return fixture;
  }, []);
  if (params.has("internal"))
    return (
      <AtlasVNextProvider>
        <ProcurementWorkbench
          authSubject="fixture-operator"
          initialServiceDate={applicationReviewNow.toISOString().slice(0, 10)}
          purchaseReviewApi={apis.purchaseReview}
          procurementApi={apis.procurement}
        />
      </AtlasVNextProvider>
    );
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
            procurementZip: async () => {},
            pxkZip: async () => {},
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
