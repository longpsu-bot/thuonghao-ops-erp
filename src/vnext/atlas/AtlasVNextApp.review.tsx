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
  reviewFamily,
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
import {
  createPlanningReviewFixture,
  planningSnapshot,
  success,
} from "./planning/planningReviewFixtures";
import planningSchoolEvidence from "../../../scripts/fixtures/atlas-planning-school-order-2026-10-11.json";
import { ProcurementWorkbench } from "./procurement/ProcurementWorkbench";
import { PantryCategoryDesignReview } from "./planning/PantryCategoryDesignReview";
import { schoolDefaultsFixtureSchools } from "./schools/schoolDefaultsReviewFixtures";
function Review() {
  const params = new URLSearchParams(window.location.search);
  const [signedIn, setSignedIn] = useState(
    params.get("session") !== "unauthenticated",
  );
  const apis = useMemo(() => {
    const fixture = createAtlasApplicationFixture();
    if (["ux400", "ux401"].includes(params.get("scenario") ?? "")) {
      // Local presentation fixture: 49 retained reference names plus one explicit
      // synthetic School. No hosted read/write or connected lineage is claimed.
      const planning = createPlanningReviewFixture();
      const names = [
        ...planningSchoolEvidence.schools.map((s) => s.school_name),
        "Trường thử nghiệm số 50",
      ];
      planning.planning.schools = names.map((school_name, index) => ({
        ...planning.planning.schools[0],
        school_id: `school-${index}`,
        school_name,
        school_code: `TEST-${index + 1}`,
        display_order: index + 1,
      }));
      fixture.planning = planning.api;
      if (params.get("scenario") === "ux401") {
        planning.pantry.schools = planning.planning.schools.map((school) => ({
          ...planning.pantry.schools[0]!,
          ...school,
          customer_name: school.school_name,
          default_delivery_location: {
            ...planning.pantry.schools[0]!.default_delivery_location!,
            delivery_location_id: `location-${school.school_id}`,
            location_name: `Bếp ${school.school_name}`,
          },
        }));
        planning.pantry.ingredients = Array.from(
          { length: 403 },
          (_, index) => ({
            ...planning.pantry.ingredients[0]!,
            ingredient_id:
              index === 0 ? "ingredient-1" : `ingredient-${index + 1}`,
            ingredient_code: index === 0 ? "GAO" : `MH-${index + 1}`,
            ingredient_name:
              index === 0
                ? "Gạo thơm"
                : index >= 400
                  ? "Rau muống"
                  : `Nguyên liệu minh họa ${index}`,
            ingredient_status: index === 402 ? "INACTIVE" : "ACTIVE",
          }),
        );
        fixture.pantry = planning.pantryApi;
        const schools = planning.planning.schools.map((school, index) => ({
          ...schoolDefaultsFixtureSchools[0]!,
          ...school,
          version: 3,
          cooking_group_id:
            index < 8
              ? "ux-cooking-school"
              : index < 20
                ? "ux-cooking-company"
                : null,
          cooking_group_name:
            index < 8
              ? `Bếp ${names[0]}`
              : index < 20
                ? "Bếp Công ty Thượng Hảo"
                : null,
          dispatch_group_id: index < 12 ? "ux-dispatch" : null,
          dispatch_group_name: index < 12 ? "Cụm giao sáng" : null,
        }));
        fixture.masterData.getSchools = async () =>
          reviewSuccess({ success: true, schools: structuredClone(schools) });
        fixture.masterData.getCookingGroups = async () =>
          reviewSuccess({
            success: true,
            cooking_groups: [
              {
                cooking_group_id: "ux-cooking-school",
                cooking_group_name: `Bếp ${names[0]}`,
                location_kind: "SCHOOL",
                host_school_id: "school-0",
                active: true,
                version: 2,
              },
              {
                cooking_group_id: "ux-cooking-company",
                cooking_group_name: "Bếp Công ty Thượng Hảo",
                location_kind: "COMPANY",
                host_school_id: null,
                active: true,
                version: 1,
              },
            ],
          });
        fixture.masterData.getDispatchGroups = async () =>
          reviewSuccess({
            success: true,
            dispatch_groups: [
              {
                dispatch_group_id: "ux-dispatch",
                dispatch_group_name: "Cụm giao sáng",
                active: true,
                version: 4,
              },
            ],
          });
        const reviewReadOnly = async () => ({
          kind: "backend_error" as const,
          error: {
            success: false as const,
            error_code: "CAPABILITY_DENIED",
            safe_message:
              "Minh họa giao diện · Không lưu thay đổi nhóm trong ví dụ này.",
          },
        });
        fixture.masterData.upsertCookingGroup = reviewReadOnly;
        fixture.masterData.setSchoolCookingGroup = reviewReadOnly;
        fixture.masterData.upsertDispatchGroup = reviewReadOnly;
        fixture.masterData.setSchoolDispatchGroup = reviewReadOnly;
        // Review-only reads expose group management. Existing command tests own
        // persistence evidence; this fixture does not simulate backend writes.
      }
    }
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
    if (scenario === "planningMaster") {
      // LOCAL_FIXTURE: observed names/ranks, stable local identities and synthetic
      // attendance. This is parser/UI evidence, not a hosted master-data readback.
      const planning = planningSnapshot();
      const week = "2026-10-12";
      const weekEnd = "2026-10-18";
      planning.week_start = week;
      planning.week_end = weekEnd;
      planning.schools = planningSchoolEvidence.schools.map((school) => ({
        ...planning.schools[0],
        school_id: `stable-school-${school.legacy_id}`,
        school_code: `v1-school-${school.legacy_id}`,
        school_name: school.school_name,
        display_order: school.display_order,
      }));
      planning.dish_types = [
        {
          dish_type_id: "stable-type-1",
          dish_type_code: "canh",
          dish_type_name: "Canh",
          source_header_aliases: ["Canh"],
          display_order: 1,
          dish_type_status: "ACTIVE",
          version: 1,
        },
      ];
      planning.dishes = [
        {
          dish_id: "deterministic-import-dish-2010",
          dish_code: "v1-dish-2010",
          dish_name: "Canh đu đủ nấu tôm khô",
          dish_type_id: "stable-type-1",
          dish_type_code: "canh",
          dish_type_name: "Canh",
          dish_status: "ACTIVE",
          display_order: 1,
          requires_need_generation: true,
        },
      ];
      const menu = planning.schools.map((school) => ({
        school_id: school.school_id,
        service_date: week,
        menu_slot_code: "canh",
        dish_id: planning.dishes[0].dish_id,
        source_row_reference: null,
      }));
      const attendance = planning.schools.map((school) => ({
        school_id: school.school_id,
        service_date: week,
        student_portions: school.default_student_portions,
        teacher_portions: school.default_teacher_portions,
        source_row_reference: null,
      }));
      planning.weekly_menu = {
        ...planning.weekly_menu!,
        week_start: week,
        week_end: weekEnd,
        lines: menu,
        row_count: menu.length,
      };
      planning.attendance = {
        ...planning.attendance!,
        period_start: week,
        period_end: weekEnd,
        lines: attendance,
        row_count: attendance.length,
      };
      planning.default_attendance_preview = attendance;
      fixture.planning.getWorkbench = async () =>
        success({ workbench: planning });
      fixture.planning.syncMenuFromGoogle = async () =>
        success({
          source: {
            source_name: "Thực đơn chính thức",
            sheet_name: "Tuần 12-10-2026",
          },
          fetched_at: "2026-10-12T01:00:00Z",
          rows: [
            ["Tên trường", "Ngày", "Canh"],
            ...planning.schools.map((school) => [
              school.school_name,
              "12/10/2026",
              planning.dishes[0].dish_name,
            ]),
          ],
        });
      // The real strict parser runs first. Hold Preview so its resolved candidate
      // remains inspectable without entering the normal automatic save path.
      fixture.planning.previewMenu = async () => new Promise(() => {});
    }
    if (rangeReview) {
      // Explicit dated review snapshots only; no production adapter or hosted writes.
      const dailyNeed = new Map<
        string,
        ReturnType<typeof createConfirmedNeedReviewFixture>
      >();
      const needFor = (date: string) => {
        if (!dailyNeed.has(date))
          dailyNeed.set(date, createConfirmedNeedReviewFixture());
        return dailyNeed.get(date)!;
      };
      const datedNeed = <T,>(value: T, date: string): T =>
        JSON.parse(
          JSON.stringify(value)
            .replaceAll("2026-09-07", date)
            .replaceAll('"batch-current"', `"batch-current-${date}"`)
            .replaceAll('"run-current"', `"run-current-${date}"`)
            .replace(
              /"((?:line|revision|decision)-(?:\d+|saved))"/g,
              `"$1-${date}"`,
            ),
        ) as T;
      fixture.planningReadiness.preflight = async (...args) =>
        datedNeed(
          await needFor(args[2]).preflightApi.preflight(...args),
          args[2],
        );
      fixture.confirmedNeed.getReview = async (...args) => {
        const date = args[3].service_date ?? "2026-09-07";
        return datedNeed(
          await needFor(date).confirmedNeedApi.getReview(...args),
          date,
        );
      };
      fixture.confirmedNeed.save = async (request) => {
        const date = request.payload.confirmed_need_batch_id.slice(-10);
        return datedNeed(
          await needFor(date).confirmedNeedApi.save(request),
          date,
        );
      };
      fixture.needGeneration.getWorkbench = async (...args) =>
        datedNeed(
          await needFor(args[2]).needGenerationApi.getWorkbench(...args),
          args[2],
        );
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
      fixture.purchaseReview.getConfirmedAllocations = async (request) => {
        const payload = request.payload as {
          date_start: string;
          date_end: string;
          school_ids: string[];
        };
        const rows = datesIn(payload.date_start, payload.date_end)
          .map((date) => {
            const row = reviewFamily("manual_split");
            return {
              ...row,
              service_date: date,
              family: {
                ...row.family,
                service_date: date,
                family_id: `review-family-${date}`,
                source_fingerprint: `review-family-fingerprint-${date}`,
                source_confirmed_need_batch_id: `batch-current-${date}`,
                source_confirmed_need_batch_version: 4,
              },
            };
          })
          .filter(
            (row) =>
              !payload.school_ids.length ||
              payload.school_ids.includes(row.school_id ?? ""),
          );
        return reviewSuccess({
          ...createProcurementReviewFixture("ready").allocation,
          date_start: payload.date_start,
          date_end: payload.date_end,
          rows,
          preparation:
            payload.date_start === payload.date_end
              ? {
                  service_date: payload.date_start,
                  confirmed_need_batch_id: `batch-current-${payload.date_start}`,
                  expected_version: 4,
                  ready: true,
                  allowed: true,
                  blockers: [],
                }
              : null,
        });
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
          environmentLabel={
            ["planningMaster", "ux401"].includes(params.get("scenario") ?? "")
              ? "LOCAL_FIXTURE"
              : "Local"
          }
          now={
            params.get("scenario") === "planningMaster"
              ? new Date("2026-10-12T03:00:00Z")
              : applicationReviewNow
          }
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
            shoppingListImport: async (_file, workbench, drafts, context) => {
              if (params.get("scenario") !== "range")
                return { drafts, changedLineIds: [] };
              // Review-only import proposal: one visibly changed row per selected day.
              // The supplied file is intentionally not parsed by this explicit fixture.
              const proposed = { ...(context?.drafts ?? drafts) };
              const changedLineIds: string[] = [];
              for (const batch of context?.workbenches ?? [workbench]) {
                const id = batch.lines[0]?.confirmed_need_line_id;
                if (!id || !proposed[id]) continue;
                proposed[id] = {
                  ...proposed[id],
                  exact_quantity: "12.5",
                  quantity_entered: true,
                  reason_code: "OTHER",
                  reason_note: "Đề xuất nhập thử theo ngày",
                };
                changedLineIds.push(id);
              }
              return { drafts: proposed, changedLineIds };
            },
          }}
        />
      </AtlasSessionGate>
    </AtlasVNextProvider>
  );
}
createRoot(document.getElementById("root")!).render(
  new URLSearchParams(window.location.search).has("capacity") ? (
    <Capacity />
  ) : new URLSearchParams(window.location.search).get("scenario") ===
    "pantry-categories" ? (
    <AtlasVNextProvider>
      <PantryCategoryDesignReview />
    </AtlasVNextProvider>
  ) : (
    <Review />
  ),
);
