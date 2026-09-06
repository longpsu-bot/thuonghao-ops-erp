import {
  createPurchaseReviewApi,
  type PurchaseReviewApi,
} from "./procurement/purchaseReviewApi";
import { useEffect, useMemo, useRef, useState } from "react";
import {
  AppShell,
  Box,
  Burger,
  Divider,
  Group,
  MantineProvider,
  NativeSelect,
  NavLink,
  Stack,
  Text,
} from "@mantine/core";
import { useDisclosure } from "@mantine/hooks";
import {
  ClipboardText,
  Database,
  House,
  ShoppingCart,
  Warehouse,
} from "@phosphor-icons/react";
import { atlasTheme } from "../../theme";
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
import { PlanningInputsWorkbenchView as PlanningInputsWorkbench } from "./planning-inputs/PlanningInputsWorkbench";
import { createReviewPurchaseJourney } from "./procurement/reviewPurchaseReviewApi";
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
import { createPlanningInputReadinessApi } from "./planning-inputs/readiness/planningInputReadinessApi";
import {
  createNeedGenerationApi,
  type NeedGenerationApi,
} from "./planning-inputs/need-generation/needGenerationApi";
import { createReviewNeedGenerationApi } from "./planning-inputs/need-generation/reviewNeedGenerationApi";
import {
  createConfirmedNeedApi,
  type ConfirmedNeedApi,
} from "./planning-inputs/confirmed-needs/confirmedNeedApi";
import { SchoolCateringProcurementWorkbench } from "./procurement/SchoolCateringProcurementWorkbench";
import {
  createSchoolCateringProcurementApi,
  type SchoolCateringProcurementApi,
} from "./procurement/schoolCateringProcurementApi";
import {
  createReviewSchoolCateringProcurementApi,
  type SchoolCateringProcurementReviewScenario,
} from "./procurement/reviewSchoolCateringProcurementApi";
import { OperationalState, WorkbenchHeader } from "./WorkbenchComponents";
import { createReviewMasterDataApi } from "./review/reviewMasterDataApi";
import {
  ATLAS_REVIEW_NOTICE,
  createReviewAuthState,
  isAtlasReviewMode,
  type AtlasReviewScenario,
} from "./review/reviewMode";

export type MasterDataPageId =
  | "customers-schools"
  | "ingredients-units"
  | "recipes"
  | "planning-inputs"
  | "procurement";

type AtlasAppProps = {
  initialPage?: MasterDataPageId;
  initialReviewScenario?: AtlasReviewScenario;
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
  { value: "procurement_default", label: "Mua hàng · phân bổ đề xuất" },
  { value: "procurement_manual_split", label: "Mua hàng · chia nhiều NCC" },
  { value: "procurement_rebalance", label: "Mua hàng · cân bằng lại" },
  {
    value: "procurement_needs_reallocation",
    label: "Mua hàng · NCC không còn phù hợp",
  },
  { value: "procurement_po_draft", label: "Mua hàng · đơn nháp" },
  { value: "procurement_stale_po", label: "Mua hàng · đơn cần cập nhật" },
  { value: "procurement_released_po", label: "Mua hàng · đã phát hành" },
  {
    value: "procurement_permission_denied",
    label: "Mua hàng · thiếu quyền",
  },
  {
    value: "procurement_retryable_failure",
    label: "Mua hàng · lỗi kết nối",
  },
  { value: "procurement_empty", label: "Mua hàng · không có dữ liệu" },
];

function procurementReviewScenario(
  scenario: AtlasReviewScenario,
): SchoolCateringProcurementReviewScenario {
  const procurementScenarios: Partial<
    Record<AtlasReviewScenario, SchoolCateringProcurementReviewScenario>
  > = {
    ready: "default",
    empty: "empty",
    permission_denied: "permission_denied",
    procurement_default: "default",
    procurement_manual_split: "manual_split",
    procurement_rebalance: "rebalance",
    procurement_needs_reallocation: "needs_reallocation",
    procurement_po_draft: "po_draft",
    procurement_stale_po: "stale_po",
    procurement_released_po: "released_po",
    procurement_permission_denied: "permission_denied",
    procurement_retryable_failure: "retryable_failure",
    procurement_empty: "empty",
  };
  return procurementScenarios[scenario] ?? "default";
}

function currentProcurementScope(today = new Date()) {
  const date = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, "0")}-${String(today.getDate()).padStart(2, "0")}`;
  return { dateStart: date, dateEnd: date };
}

function AtlasNavigation({
  active,
  onNavigate,
  onNavigateComplete,
}: {
  active: MasterDataPageId;
  onNavigate: (page: MasterDataPageId) => void;
  onNavigateComplete?: () => void;
}) {
  const navigate = (page: MasterDataPageId) => {
    onNavigate(page);
    onNavigateComplete?.();
  };

  return (
    <Stack className="atlas-sidebar" component="aside" gap={0}>
      <Stack className="atlas-brand" gap={2}>
        <Text component="span">OPS ERP</Text>
        <Text component="strong">Atlas</Text>
        <Text component="small">Điều hành suất ăn học đường</Text>
      </Stack>
      <Stack component="nav" aria-label="Điều hướng Atlas" gap={4}>
        <NavLink
          renderRoot={(props) => <button {...props} type="button" disabled />}
          label="Tổng quan"
          leftSection={<House aria-hidden="true" size={19} weight="regular" />}
          description="Chưa triển khai"
          disabled
        />

        <Stack className="nav-group" gap={3}>
          <Group className="nav-group-label" gap={8}>
            <Database aria-hidden="true" size={16} weight="regular" />
            <Text component="span">Dữ liệu gốc</Text>
          </Group>
          <NavLink
            component="button"
            type="button"
            label="Trường học"
            active={active === "customers-schools"}
            onClick={() => navigate("customers-schools")}
          />
          <NavLink
            component="button"
            type="button"
            label="Nguyên liệu và Nhà cung ứng"
            active={active === "ingredients-units"}
            onClick={() => navigate("ingredients-units")}
          />
          <NavLink
            component="button"
            type="button"
            label="Công thức"
            active={active === "recipes"}
            onClick={() => navigate("recipes")}
          />
        </Stack>

        <Divider className="atlas-nav-divider" />
        <Stack className="nav-group" gap={3}>
          <NavLink
            component="button"
            type="button"
            label="Lập nhu cầu"
            leftSection={
              <ClipboardText aria-hidden="true" size={19} weight="regular" />
            }
            active={active === "planning-inputs"}
            onClick={() => navigate("planning-inputs")}
          />
        </Stack>

        <NavLink
          component="button"
          type="button"
          label="Kế hoạch mua hàng"
          leftSection={
            <ShoppingCart aria-hidden="true" size={19} weight="regular" />
          }
          active={active === "procurement"}
          onClick={() => navigate("procurement")}
        />
        <NavLink
          renderRoot={(props) => <button {...props} type="button" disabled />}
          label="Kho"
          description="Chưa triển khai"
          leftSection={
            <Warehouse aria-hidden="true" size={19} weight="regular" />
          }
          disabled
        />
      </Stack>
    </Stack>
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
  procurementApi,
  purchaseReviewApi,
  onContinueAllocation,
  procurementDate,
  mode,
}: {
  page: MasterDataPageId;
  authState: AtlasAuthState;
  api?: MasterDataApi;
  recipeApi?: RecipeApi;
  recipeAdjustmentApi?: RecipeAdjustmentApi;
  planningApi?: PlanningInputsApi;
  pantryApi?: PantryApi;
  readinessApi?: ReturnType<typeof createPlanningInputReadinessApi>;
  needGenerationApi?: NeedGenerationApi;
  confirmedNeedApi?: ConfirmedNeedApi;
  procurementApi?: SchoolCateringProcurementApi;
  purchaseReviewApi?: PurchaseReviewApi;
  onContinueAllocation?: (serviceDate: string) => void;
  procurementDate?: string;
  mode: "connected" | "review";
}) {
  const schoolPage = page === "customers-schools";
  const recipePage = page === "recipes";
  const planningPage = page === "planning-inputs";
  const procurementPage = page === "procurement";
  const procurementScope = currentProcurementScope();
  const serviceDate = procurementDate ?? procurementScope.dateStart;
  return (
    <main className="atlas-page master-data-page">
      {!planningPage && !procurementPage && (
        <WorkbenchHeader
          eyebrow={recipePage ? "Món ăn và công thức" : "Dữ liệu gốc"}
          title={
            recipePage
              ? "Công thức món ăn"
              : schoolPage
                ? "Trường học"
                : "Nguyên liệu và Nhà cung ứng"
          }
          context={
            recipePage
              ? "Tra cứu công thức hiện hành, tạo món và công thức mới, hoặc chuyển sang Lệnh điều chỉnh khi món đã được sử dụng."
              : schoolPage
                ? "Quản lý thông tin vận hành và sĩ số mặc định của trường."
                : "Quản lý thông tin mua hàng, trạng thái nguyên liệu và thứ tự ưu tiên nhà cung ứng."
          }
        />
      )}

      {planningPage ? (
        <PlanningInputsWorkbench
          authState={authState}
          api={planningApi}
          pantryApi={pantryApi}
          readinessApi={readinessApi}
          needGenerationApi={needGenerationApi}
          confirmedNeedApi={confirmedNeedApi}
          purchaseReviewApi={purchaseReviewApi}
          onContinueAllocation={onContinueAllocation}
          initialServiceDate={procurementDate}
          mode={mode}
        />
      ) : procurementPage ? (
        <SchoolCateringProcurementWorkbench
          authState={authState}
          api={procurementApi}
          purchaseReviewApi={purchaseReviewApi}
          initialDateStart={serviceDate}
          initialDateEnd={serviceDate}
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
  procurementApi,
  purchaseReviewApi,
  mode,
  session,
  connection,
  reviewScenario,
  onReviewScenarioChange,
  initialServiceDate,
}: {
  initialPage: MasterDataPageId;
  authState: AtlasAuthState;
  api?: MasterDataApi;
  recipeApi?: RecipeApi;
  recipeAdjustmentApi?: RecipeAdjustmentApi;
  planningApi?: PlanningInputsApi;
  pantryApi?: PantryApi;
  readinessApi?: ReturnType<typeof createPlanningInputReadinessApi>;
  needGenerationApi?: NeedGenerationApi;
  confirmedNeedApi?: ConfirmedNeedApi;
  procurementApi?: SchoolCateringProcurementApi;
  purchaseReviewApi?: PurchaseReviewApi;
  mode: "connected" | "review";
  session?: AtlasAuthSessionController;
  connection?: AtlasSupabaseClientResult;
  reviewScenario?: AtlasReviewScenario;
  onReviewScenarioChange?: (scenario: AtlasReviewScenario) => void;
  initialServiceDate?: string;
}) {
  const [active, setActive] = useState<MasterDataPageId>(initialPage);
  const [procurementDate, setProcurementDate] = useState(initialServiceDate);
  const [mobileNavigationOpened, mobileNavigation] = useDisclosure(false);
  const mobileNavigationButtonRef = useRef<HTMLButtonElement>(null);
  const contentRef = useRef<HTMLElement>(null);
  const allocationNavigationPending = useRef(false);

  useEffect(() => {
    if (active !== "procurement" || !allocationNavigationPending.current)
      return;
    allocationNavigationPending.current = false;
    contentRef.current
      ?.querySelector<HTMLHeadingElement>(".procurement-heading h1")
      ?.focus();
  }, [active]);

  const completeNavigation = () => {
    if (!mobileNavigationOpened) return;

    mobileNavigation.close();
    mobileNavigationButtonRef.current?.focus();
  };

  return (
    <AppShell
      className="atlas-shell"
      header={{ height: { base: 56, md: 0 } }}
      navbar={{
        width: 252,
        breakpoint: "md",
        collapsed: { mobile: !mobileNavigationOpened },
      }}
      padding={0}
      withBorder={false}
    >
      <AppShell.Header className="atlas-mobile-header" hiddenFrom="md">
        <Group h="100%" px="md" justify="space-between">
          <Box className="atlas-mobile-brand">
            <Text component="span">OPS ERP</Text>
            <Text component="strong">Atlas</Text>
          </Box>
          <Burger
            ref={mobileNavigationButtonRef}
            opened={mobileNavigationOpened}
            onClick={mobileNavigation.toggle}
            aria-label={
              mobileNavigationOpened
                ? "Đóng điều hướng Atlas"
                : "Mở điều hướng Atlas"
            }
          />
        </Group>
      </AppShell.Header>
      <AppShell.Navbar className="atlas-navbar">
        <AtlasNavigation
          active={active}
          onNavigate={setActive}
          onNavigateComplete={completeNavigation}
        />
      </AppShell.Navbar>
      <AppShell.Main className="atlas-content" ref={contentRef}>
        {mode === "review" ? (
          <Box component="header" className="atlas-review-bar">
            <OperationalState
              variant="read-only"
              title={ATLAS_REVIEW_NOTICE}
              compact
            />
            <NativeSelect
              className="atlas-review-scenario"
              label="Tình huống xem thử"
              value={reviewScenario}
              data={REVIEW_SCENARIOS}
              onChange={(event) =>
                onReviewScenarioChange?.(
                  event.currentTarget.value as AtlasReviewScenario,
                )
              }
            />
          </Box>
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
          procurementApi={procurementApi}
          purchaseReviewApi={purchaseReviewApi}
          procurementDate={procurementDate}
          onContinueAllocation={(date) => {
            allocationNavigationPending.current = true;
            setProcurementDate(date);
            setActive("procurement");
          }}
          mode={mode}
        />
      </AppShell.Main>
    </AppShell>
  );
}

function ReviewAtlasApp({
  initialPage,
  initialReviewScenario,
}: {
  initialPage: MasterDataPageId;
  initialReviewScenario: AtlasReviewScenario;
}) {
  const [scenario, setScenario] = useState<AtlasReviewScenario>(
    initialReviewScenario,
  );
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
  const needGenerationApi = useMemo(
    () => createReviewNeedGenerationApi(scenario),
    [scenario],
  );
  const [reviewDate] = useState(() => {
    const monday = new Date();
    monday.setDate(monday.getDate() - ((monday.getDay() + 6) % 7));
    return currentProcurementScope(monday).dateStart;
  });
  const journey = useMemo(
    () => createReviewPurchaseJourney(scenario, reviewDate),
    [scenario, reviewDate],
  );
  const legacyProcurementApi = useMemo(
    () =>
      createReviewSchoolCateringProcurementApi(
        procurementReviewScenario(scenario),
      ),
    [scenario],
  );
  const legacyProcurementScenario = scenario.startsWith("procurement_");
  const authState = useMemo(() => createReviewAuthState(scenario), [scenario]);

  return (
    <AtlasShell
      initialPage={initialPage}
      initialServiceDate={reviewDate}
      authState={authState}
      api={api}
      recipeApi={recipeApi}
      recipeAdjustmentApi={recipeAdjustmentApi}
      planningApi={planningApi}
      pantryApi={pantryApi}
      readinessApi={journey.readinessApi}
      needGenerationApi={needGenerationApi}
      confirmedNeedApi={journey.confirmedNeedApi}
      procurementApi={
        legacyProcurementScenario
          ? legacyProcurementApi
          : journey.procurementApi
      }
      purchaseReviewApi={
        legacyProcurementScenario ? undefined : journey.purchaseReviewApi
      }
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
  const procurementApi = useMemo(
    () =>
      transport ? createSchoolCateringProcurementApi(transport) : undefined,
    [transport],
  );

  const purchaseReviewApi = useMemo(
    () => (transport ? createPurchaseReviewApi(transport) : undefined),
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
      procurementApi={procurementApi}
      purchaseReviewApi={purchaseReviewApi}
      mode="connected"
      session={auth}
      connection={connection}
    />
  );
}

export function AtlasAppView({
  initialPage = "customers-schools",
  initialReviewScenario = "ready",
  reviewMode = isAtlasReviewMode(),
  connection,
  connectionFactory = getAtlasSupabaseClient,
}: AtlasAppProps) {
  if (reviewMode)
    return (
      <ReviewAtlasApp
        initialPage={initialPage}
        initialReviewScenario={initialReviewScenario}
      />
    );

  return (
    <ConnectedAtlasApp
      initialPage={initialPage}
      connection={connection ?? connectionFactory()}
    />
  );
}

export function AtlasApp(props: AtlasAppProps) {
  return (
    <MantineProvider
      theme={atlasTheme}
      forceColorScheme="light"
      env={import.meta.env.MODE === "test" ? "test" : "default"}
    >
      <AtlasAppView {...props} />
    </MantineProvider>
  );
}
