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
import { createRecipeApi, type RecipeApi } from "./recipes/recipeApi";
import { createReviewRecipeApi } from "./recipes/reviewRecipeApi";
import { createReviewMasterDataApi } from "./review/reviewMasterDataApi";
import {
  ATLAS_REVIEW_NOTICE,
  createReviewAuthState,
  isAtlasReviewMode,
  type AtlasReviewScenario,
} from "./review/reviewMode";

export type MasterDataPageId =
  "customers-schools" | "ingredients-units" | "recipes";

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

        {["Kế hoạch nhu cầu", "Thu mua", "Kho"].map((label) => (
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
  mode,
}: {
  page: MasterDataPageId;
  authState: AtlasAuthState;
  api?: MasterDataApi;
  recipeApi?: RecipeApi;
  mode: "connected" | "review";
}) {
  const schoolPage = page === "customers-schools";
  const recipePage = page === "recipes";
  return (
    <main className="atlas-page master-data-page">
      <header className="master-data-page-heading">
        <span className="page-kicker">
          {recipePage ? "Quản trị công thức" : "Dữ liệu gốc"}
        </span>
        <h1>
          {recipePage
            ? "Công thức"
            : schoolPage
              ? "Trường học"
              : "Nguyên liệu và Nhà cung ứng"}
        </h1>
        <p>
          {recipePage
            ? "Quản lý món ăn, phạm vi công thức chung/theo loại trường, phiên bản BOM bất biến, sao chép và nhập workbook có đối soát."
            : schoolPage
              ? "Quản lý thông tin vận hành và sĩ số mặc định của trường."
              : "Quản lý thông tin mua hàng, trạng thái nguyên liệu và thứ tự ưu tiên nhà cung ứng."}
        </p>
      </header>

      {recipePage ? (
        <DishRecipeAdminWorkbench
          authState={authState}
          api={recipeApi}
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
  mode,
  session,
  reviewScenario,
  onReviewScenarioChange,
}: {
  initialPage: MasterDataPageId;
  authState: AtlasAuthState;
  api?: MasterDataApi;
  recipeApi?: RecipeApi;
  mode: "connected" | "review";
  session?: AtlasAuthSessionController;
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
          session && <AtlasConnectionPanelView auth={session} />
        )}
        <MasterDataPage
          key={`${mode}:${reviewScenario ?? "connected"}`}
          page={active}
          authState={authState}
          api={api}
          recipeApi={recipeApi}
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
  const authState = useMemo(() => createReviewAuthState(scenario), [scenario]);

  return (
    <AtlasShell
      initialPage={initialPage}
      authState={authState}
      api={api}
      recipeApi={recipeApi}
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

  return (
    <AtlasShell
      initialPage={initialPage}
      authState={auth.state}
      api={api}
      recipeApi={recipeApi}
      mode="connected"
      session={auth}
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
