import { useMemo, useState } from "react";
import { DishRecipeAdminWorkbench } from "../admin/DishRecipeAdminWorkbench";
import { IngredientSupplierAdminWorkbench } from "../admin/IngredientSupplierAdminWorkbench";
import { SchoolAdminWorkbench } from "../admin/SchoolAdminWorkbench";
import { AtlasConnectionPanelView } from "./connection/AtlasConnectionPanel";
import { createAtlasRpcTransport } from "./connection/atlasRpc";
import {
  useAtlasAuthSession,
  type AtlasAuthSessionController,
  type AtlasAuthState,
} from "./connection/authSession";
import {
  getAtlasSupabaseClient,
  type AtlasSupabaseClientResult,
} from "./connection/supabaseClient";
import {
  createMasterDataApi,
  type MasterDataApi,
} from "./master-data/masterDataApi";
import {
  createRecipeAdjustmentApi,
  type RecipeAdjustmentApi,
} from "./recipe-adjustments/recipeAdjustmentApi";
import { createReviewRecipeAdjustmentApi } from "./recipe-adjustments/reviewRecipeAdjustmentApi";
import { createRecipeApi, type RecipeApi } from "./recipes/recipeApi";
import { createReviewRecipeApi } from "./recipes/reviewRecipeApi";
import { PlanningInputsWorkbench } from "./planning-inputs/PlanningInputsWorkbench";
import {
  createPlanningInputsApi,
  type PlanningInputsApi,
} from "./planning-inputs/planningInputsApi";
import { createReviewPlanningInputsApi } from "./planning-inputs/reviewPlanningInputsApi";
import {
  createPantryApi,
  type PantryApi,
} from "./planning-inputs/pantry/pantryApi";
import { createReviewPantryApi } from "./planning-inputs/pantry/reviewPantryApi";
import {
  createPlanningInputReadinessApi,
  type PlanningInputReadinessApi,
} from "./planning-inputs/readiness/planningInputReadinessApi";
import { createReviewPlanningInputReadinessApi } from "./planning-inputs/readiness/reviewPlanningInputReadinessApi";
import {
  createNeedGenerationApi,
  type NeedGenerationApi,
} from "./planning-inputs/need-generation/needGenerationApi";
import { createReviewNeedGenerationApi } from "./planning-inputs/need-generation/reviewNeedGenerationApi";
import {
  createConfirmedNeedApi,
  type ConfirmedNeedApi,
} from "./planning-inputs/confirmed-needs/confirmedNeedApi";
import { createReviewConfirmedNeedApi } from "./planning-inputs/confirmed-needs/reviewConfirmedNeedApi";
import { createReviewMasterDataApi } from "./review/reviewMasterDataApi";
import {
  ATLAS_REVIEW_NOTICE,
  createReviewAuthState,
  isAtlasReviewMode,
  type AtlasReviewScenario,
} from "./review/reviewMode";

export type MasterDataPageId =
  "customers-schools" | "ingredients-units" | "recipes" | "planning-inputs";

type AtlasAppProps = {
  initialPage?: MasterDataPageId;
  reviewMode?: boolean;
  connection?: AtlasSupabaseClientResult;
  connectionFactory?: () => AtlasSupabaseClientResult;
};

const REVIEW_SCENARIOS: {
  value: AtlasReviewScenario;
  label: string;
}[] = [
  { value: "ready", label: "Dữ liệu mẫu" },
  { value: "loading", label: "Đang tải" },
  { value: "empty", label: "Không có dữ liệu" },
  { value: "permission_denied", label: "Không có quyền" },
  { value: "session_lost", label: "Phiên đã hết" },
  { value: "server_error", label: "Lỗi máy chủ" },
  { value: "stale", label: "Xung đột phiên bản" },
  { value: "menu_draft", label: "Thực đơn · bản nháp" },
  { value: "menu_empty", label: "Thực đơn · tuần trống" },
  { value: "menu_validated", label: "Thực đơn · đã xác thực" },
  { value: "menu_approved", label: "Thực đơn · đã phê duyệt" },
  { value: "menu_reopened", label: "Thực đơn · đã mở lại" },
  { value: "menu_recipe_warning", label: "Thực đơn · công thức chưa sẵn sàng" },
  { value: "menu_diff_approved", label: "Thực đơn · khác lần duyệt" },
  { value: "menu_replay_success", label: "Thực đơn · lặp lại an toàn" },
  { value: "menu_invalid_dates", label: "Thực đơn · sai ngày" },
  { value: "menu_duplicate", label: "Thực đơn · trùng dòng" },
  { value: "menu_inactive_refs", label: "Thực đơn · tham chiếu ngừng" },
  { value: "menu_zero_valid", label: "Thực đơn · không có dòng hợp lệ" },
  { value: "menu_permission_denied", label: "Thực đơn · thiếu quyền" },
  { value: "menu_retryable", label: "Thực đơn · thử lại được" },
  { value: "menu_stale", label: "Thực đơn · dữ liệu cũ" },
  { value: "menu_session_lost", label: "Thực đơn · mất phiên" },
  { value: "dish_types_renamed", label: "Loại món · đổi tên" },
  { value: "dish_types_reordered", label: "Loại món · đổi thứ tự" },
  { value: "dish_types_added", label: "Loại món · thêm cột" },
  { value: "dish_types_inactive", label: "Loại món · ngừng hoạt động" },
  { value: "menu_type_match", label: "Thực đơn · đúng Loại món" },
  { value: "menu_type_mismatch", label: "Thực đơn · sai Loại món" },
  { value: "google_source_configured", label: "Google Sheet · đã cấu hình" },
  { value: "google_source_missing", label: "Google Sheet · chưa cấu hình" },
  {
    value: "google_source_unavailable",
    label: "Google Sheet · nguồn ngừng hoạt động",
  },
  { value: "google_fetch_success", label: "Google Sheet · tải thành công" },
  { value: "google_empty_sheet", label: "Google Sheet · trang tuần trống" },
  { value: "google_sheet_missing", label: "Google Sheet · thiếu trang tuần" },
  {
    value: "google_connector_unavailable",
    label: "Google Sheet · bộ đồng bộ lỗi",
  },
  { value: "google_permission_denied", label: "Google Sheet · thiếu quyền" },
  { value: "google_retryable", label: "Google Sheet · có thể thử lại" },
  { value: "google_session_lost", label: "Google Sheet · mất phiên" },
  {
    value: "google_preview_blockers",
    label: "Google Sheet · xem trước có lỗi",
  },
  { value: "google_save_success", label: "Google Sheet · lưu thành công" },
  { value: "attendance_draft", label: "Sĩ số · bản nháp" },
  { value: "attendance_imported", label: "Sĩ số · giá trị đã nhập" },
  { value: "attendance_validated", label: "Sĩ số · đã xác thực" },
  { value: "attendance_approved", label: "Sĩ số · đã phê duyệt" },
  { value: "attendance_reopened", label: "Sĩ số · đã mở lại" },
  { value: "attendance_zero", label: "Sĩ số · số 0 tường minh" },
  { value: "attendance_diff_defaults", label: "Sĩ số · khác mặc định" },
  { value: "attendance_diff_approved", label: "Sĩ số · khác lần duyệt" },
  { value: "attendance_missing_menu", label: "Sĩ số · thiếu thực đơn" },
  { value: "attendance_negative", label: "Sĩ số · giá trị âm bị chặn" },
  { value: "attendance_replay_success", label: "Sĩ số · lặp lại an toàn" },
  { value: "attendance_permission_denied", label: "Sĩ số · thiếu quyền" },
  { value: "attendance_retryable", label: "Sĩ số · thử lại được" },
  { value: "attendance_stale", label: "Sĩ số · dữ liệu cũ" },
  { value: "attendance_session_lost", label: "Sĩ số · mất phiên" },
];

function AtlasNavigation({
  active,
  onNavigate,
}: {
  active: MasterDataPageId;
  onNavigate: (page: MasterDataPageId) => void;
}) {
  return (
    <aside className="atlas-sidebar">
      <div className="atlas-brand">
        <span>OPS ERP</span>
        <strong>Atlas</strong>
        <small>Điều hành suất ăn học đường</small>
      </div>
      <nav aria-label="Điều hướng Atlas">
        <button type="button" className="nav-future" disabled>
          <span>Tổng quan</span>
          <small>Chưa triển khai</small>
        </button>

        <div className="nav-group">
          <span>Dữ liệu gốc</span>
          <button
            type="button"
            className={active === "customers-schools" ? "active" : ""}
            onClick={() => onNavigate("customers-schools")}
          >
            Trường học
          </button>
          <button
            type="button"
            className={active === "ingredients-units" ? "active" : ""}
            onClick={() => onNavigate("ingredients-units")}
          >
            Nguyên liệu và Nhà cung ứng
          </button>
          <button
            type="button"
            className={active === "recipes" ? "active" : ""}
            onClick={() => onNavigate("recipes")}
          >
            Công thức
          </button>
        </div>

        <div className="nav-group">
          <span>Lập nhu cầu</span>
          <button
            type="button"
            className={active === "planning-inputs" ? "active" : ""}
            onClick={() => onNavigate("planning-inputs")}
          >
            Nguồn kế hoạch
          </button>
        </div>

        {["Kế hoạch mua hàng", "Kho"].map((label) => (
          <button type="button" className="nav-future" disabled key={label}>
            <span>{label}</span>
            <small>Chưa triển khai</small>
          </button>
        ))}
      </nav>
    </aside>
  );
}

function MasterDataPage({
  page,
  authState,
  api,
  recipeApi,
  recipeAdjustmentApi,
  planningApi,
  pantryApi,
  readinessApi,
  needGenerationApi,
  confirmedNeedApi,
  mode,
}: {
  page: MasterDataPageId;
  authState: AtlasAuthState;
  api?: MasterDataApi;
  recipeApi?: RecipeApi;
  recipeAdjustmentApi?: RecipeAdjustmentApi;
  planningApi?: PlanningInputsApi;
  pantryApi?: PantryApi;
  readinessApi?: PlanningInputReadinessApi;
  needGenerationApi?: NeedGenerationApi;
  confirmedNeedApi?: ConfirmedNeedApi;
  mode: "connected" | "review";
}) {
  const schoolPage = page === "customers-schools";
  const recipePage = page === "recipes";
  const planningPage = page === "planning-inputs";
  return (
    <main className="atlas-page master-data-page">
      <header className="master-data-page-heading">
        <span className="page-kicker">
          {planningPage
            ? "Lập nhu cầu"
            : recipePage
              ? "Quản trị công thức"
              : "Dữ liệu gốc"}
        </span>
        <h1>
          {planningPage
            ? "Nguồn kế hoạch"
            : recipePage
              ? "Công thức"
              : schoolPage
                ? "Trường học"
                : "Nguyên liệu và Nhà cung ứng"}
        </h1>
        <p>
          {planningPage
            ? "Quản lý thực đơn tuần và sĩ số theo đúng tuần phục vụ, với xem trước, xác thực, phê duyệt và lịch sử bất biến."
            : recipePage
              ? "Quản lý món ăn, phạm vi công thức chung/theo loại trường, phiên bản BOM bất biến, sao chép và nhập workbook có đối soát."
              : schoolPage
                ? "Quản lý thông tin vận hành và sĩ số mặc định của trường."
                : "Quản lý thông tin mua hàng, trạng thái nguyên liệu và thứ tự ưu tiên nhà cung ứng."}
        </p>
      </header>

      {planningPage ? (
        <PlanningInputsWorkbench
          authState={authState}
          api={planningApi}
          pantryApi={pantryApi}
          readinessApi={readinessApi}
          needGenerationApi={needGenerationApi}
          confirmedNeedApi={confirmedNeedApi}
          mode={mode}
        />
      ) : recipePage ? (
        <DishRecipeAdminWorkbench
          authState={authState}
          api={recipeApi}
          adjustmentApi={recipeAdjustmentApi}
          mode={mode}
        />
      ) : schoolPage ? (
        <SchoolAdminWorkbench authState={authState} api={api} mode={mode} />
      ) : (
        <IngredientSupplierAdminWorkbench
          authState={authState}
          api={api}
          mode={mode}
        />
      )}
    </main>
  );
}

function AtlasShell({
  initialPage,
  authState,
  api,
  recipeApi,
  recipeAdjustmentApi,
  planningApi,
  pantryApi,
  readinessApi,
  needGenerationApi,
  confirmedNeedApi,
  mode,
  session,
  connection,
  reviewScenario,
  onReviewScenarioChange,
}: {
  initialPage: MasterDataPageId;
  authState: AtlasAuthState;
  api?: MasterDataApi;
  recipeApi?: RecipeApi;
  recipeAdjustmentApi?: RecipeAdjustmentApi;
  planningApi?: PlanningInputsApi;
  pantryApi?: PantryApi;
  readinessApi?: PlanningInputReadinessApi;
  needGenerationApi?: NeedGenerationApi;
  confirmedNeedApi?: ConfirmedNeedApi;
  mode: "connected" | "review";
  session?: AtlasAuthSessionController;
  connection?: AtlasSupabaseClientResult;
  reviewScenario?: AtlasReviewScenario;
  onReviewScenarioChange?: (scenario: AtlasReviewScenario) => void;
}) {
  const [active, setActive] = useState<MasterDataPageId>(initialPage);

  return (
    <div className="atlas-shell">
      <AtlasNavigation active={active} onNavigate={setActive} />
      <div className="atlas-content">
        {mode === "review" ? (
          <header className="atlas-review-bar">
            <strong role="status">{ATLAS_REVIEW_NOTICE}</strong>
            <label>
              Tình huống xem thử
              <select
                value={reviewScenario}
                onChange={(event) =>
                  onReviewScenarioChange?.(
                    event.target.value as AtlasReviewScenario,
                  )
                }
              >
                {REVIEW_SCENARIOS.map((scenario) => (
                  <option key={scenario.value} value={scenario.value}>
                    {scenario.label}
                  </option>
                ))}
              </select>
            </label>
          </header>
        ) : (
          session &&
          connection && (
            <AtlasConnectionPanelView
              auth={session}
              environmentLabel={
                connection.status === "configured"
                  ? connection.environmentLabel
                  : "Atlas · lỗi cấu hình · non-production"
              }
            />
          )
        )}
        <MasterDataPage
          key={`${mode}:${reviewScenario ?? "connected"}`}
          page={active}
          authState={authState}
          api={api}
          recipeApi={recipeApi}
          recipeAdjustmentApi={recipeAdjustmentApi}
          planningApi={planningApi}
          pantryApi={pantryApi}
          readinessApi={readinessApi}
          needGenerationApi={needGenerationApi}
          confirmedNeedApi={confirmedNeedApi}
          mode={mode}
        />
      </div>
    </div>
  );
}

function ReviewAtlasApp({ initialPage }: { initialPage: MasterDataPageId }) {
  const [scenario, setScenario] = useState<AtlasReviewScenario>("ready");
  const api = useMemo(() => createReviewMasterDataApi(scenario), [scenario]);
  const recipeApi = useMemo(() => createReviewRecipeApi(scenario), [scenario]);
  const recipeAdjustmentApi = useMemo(
    () => createReviewRecipeAdjustmentApi(scenario),
    [scenario],
  );
  const planningApi = useMemo(
    () => createReviewPlanningInputsApi(scenario),
    [scenario],
  );
  const pantryApi = useMemo(() => createReviewPantryApi(scenario), [scenario]);
  const readinessApi = useMemo(
    () => createReviewPlanningInputReadinessApi(scenario),
    [scenario],
  );
  const needGenerationApi = useMemo(
    () => createReviewNeedGenerationApi(scenario),
    [scenario],
  );
  const confirmedNeedApi = useMemo(
    () => createReviewConfirmedNeedApi(scenario),
    [scenario],
  );
  const authState = useMemo(() => createReviewAuthState(scenario), [scenario]);

  return (
    <AtlasShell
      initialPage={initialPage}
      authState={authState}
      api={api}
      recipeApi={recipeApi}
      recipeAdjustmentApi={recipeAdjustmentApi}
      planningApi={planningApi}
      pantryApi={pantryApi}
      readinessApi={readinessApi}
      needGenerationApi={needGenerationApi}
      confirmedNeedApi={confirmedNeedApi}
      mode="review"
      reviewScenario={scenario}
      onReviewScenarioChange={setScenario}
    />
  );
}

function ConnectedAtlasApp({
  initialPage,
  connection,
}: {
  initialPage: MasterDataPageId;
  connection: AtlasSupabaseClientResult;
}) {
  const auth = useAtlasAuthSession(connection);
  const transport = useMemo(
    () =>
      connection.status === "configured"
        ? createAtlasRpcTransport(connection.client)
        : undefined,
    [connection],
  );
  const api = useMemo(
    () => (transport ? createMasterDataApi(transport) : undefined),
    [transport],
  );
  const recipeApi = useMemo(
    () => (transport ? createRecipeApi(transport) : undefined),
    [transport],
  );
  const recipeAdjustmentApi = useMemo(
    () => (transport ? createRecipeAdjustmentApi(transport) : undefined),
    [transport],
  );
  const planningApi = useMemo(
    () => (transport ? createPlanningInputsApi(transport) : undefined),
    [transport],
  );
  const pantryApi = useMemo(
    () => (transport ? createPantryApi(transport) : undefined),
    [transport],
  );
  const readinessApi = useMemo(
    () => (transport ? createPlanningInputReadinessApi(transport) : undefined),
    [transport],
  );
  const needGenerationApi = useMemo(
    () => (transport ? createNeedGenerationApi(transport) : undefined),
    [transport],
  );
  const confirmedNeedApi = useMemo(
    () => (transport ? createConfirmedNeedApi(transport) : undefined),
    [transport],
  );

  return (
    <AtlasShell
      initialPage={initialPage}
      authState={auth.state}
      api={api}
      recipeApi={recipeApi}
      recipeAdjustmentApi={recipeAdjustmentApi}
      planningApi={planningApi}
      pantryApi={pantryApi}
      readinessApi={readinessApi}
      needGenerationApi={needGenerationApi}
      confirmedNeedApi={confirmedNeedApi}
      mode="connected"
      session={auth}
      connection={connection}
    />
  );
}

export function AtlasApp({
  initialPage = "customers-schools",
  reviewMode = isAtlasReviewMode(),
  connection,
  connectionFactory = getAtlasSupabaseClient,
}: AtlasAppProps) {
  if (reviewMode) return <ReviewAtlasApp initialPage={initialPage} />;

  return (
    <ConnectedAtlasApp
      initialPage={initialPage}
      connection={connection ?? connectionFactory()}
    />
  );
}
