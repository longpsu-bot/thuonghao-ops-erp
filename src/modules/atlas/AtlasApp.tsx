import { useMemo, useState } from "react";
import { IngredientSupplierAdminWorkbench } from "../admin/IngredientSupplierAdminWorkbench";
import { DishRecipeAdminWorkbench } from "../admin/DishRecipeAdminWorkbench";
import { SchoolAdminWorkbench } from "../admin/SchoolAdminWorkbench";
import { atlasGroups, atlasPages, type AtlasPageId } from "./atlasConfig";
import {
  ControlBoardPage,
  DocumentReleasePage,
  DispatchDeliveryPage,
  PlanningSourcesPage,
  PurchasePlanningPage,
  RequirementPlanningPage,
  SupportingPage,
  WarehouseReceivingPage,
  WarehouseStockReleasePage,
} from "./AtlasPages";
import { PageShell, TracePanel } from "./WorkbenchComponents";
import { MvpMorningChaosPage } from "./MvpMorningChaosPage";
import { AtlasConnectionPanelView } from "./connection/AtlasConnectionPanel";
import { createAtlasRpcTransport } from "./connection/atlasRpc";
import { useAtlasAuthSession } from "./connection/authSession";
import {
  getAtlasSupabaseClient,
  type AtlasSupabaseClientResult,
} from "./connection/supabaseClient";
import { SupplierEvidenceReadinessWorkbench } from "./evidence/SupplierEvidenceReadinessWorkbench";
import { createSupplierEvidenceApi } from "./evidence/supplierEvidenceApi";

export function AtlasApp({
  initialPage = "control-board",
  connection = getAtlasSupabaseClient(),
}: {
  initialPage?: AtlasPageId;
  connection?: AtlasSupabaseClientResult;
}) {
  const [active, setActive] = useState<AtlasPageId>(initialPage);
  const [traceOpen, setTraceOpen] = useState(false);
  const auth = useAtlasAuthSession(connection);
  const evidenceApi = useMemo(
    () =>
      connection.status === "configured"
        ? createSupplierEvidenceApi(createAtlasRpcTransport(connection.client))
        : undefined,
    [connection],
  );
  const page = atlasPages.find((candidate) => candidate.id === active)!;
  let content = <SupportingPage page={page} />;
  if (active === "control-board") content = <ControlBoardPage />;
  if (active === "planning-sources") content = <PlanningSourcesPage />;
  if (active === "requirement-planning") content = <RequirementPlanningPage />;
  if (active === "purchase-planning") content = <PurchasePlanningPage />;
  if (active === "document-release") content = <DocumentReleasePage />;
  if (active === "supplier-evidence-readiness")
    content = (
      <SupplierEvidenceReadinessWorkbench
        authState={auth.state}
        api={evidenceApi}
      />
    );
  if (active === "warehouse-receiving") content = <WarehouseReceivingPage />;
  if (active === "warehouse-stock-release")
    content = <WarehouseStockReleasePage />;
  if (active === "dispatch-delivery") content = <DispatchDeliveryPage />;
  if (active === "mvp-operations-simulation") content = <MvpMorningChaosPage />;
  if (active === "customers-schools") content = <SchoolAdminWorkbench />;
  if (active === "ingredients-units" || active === "suppliers-eligibility")
    content = <IngredientSupplierAdminWorkbench />;
  if (active === "recipe-governance") content = <DishRecipeAdminWorkbench />;

  return (
    <div className="atlas-shell">
      <aside className="atlas-sidebar">
        <div className="atlas-brand">
          <span>OPS ERP</span>
          <strong>Atlas</strong>
          <small>Operations workbench</small>
        </div>
        <nav aria-label="Điều hướng Atlas">
          {atlasGroups.map((group) => (
            <div className="nav-group" key={group}>
              <span>{group}</span>
              {atlasPages
                .filter((candidate) => candidate.group === group)
                .map((candidate) => (
                  <button
                    key={candidate.id}
                    className={candidate.id === active ? "active" : ""}
                    onClick={() => setActive(candidate.id)}
                  >
                    {candidate.label}
                  </button>
                ))}
            </div>
          ))}
        </nav>
      </aside>
      <div className="atlas-content">
        <header className="atlas-topbar">
          <div>
            <span>Ngày phục vụ</span>
            <strong>14/07/2026 · Ca sáng</strong>
          </div>
          <div>
            <span>Không gian hiện tại</span>
            <strong>{page.label}</strong>
          </div>
          <button className="trace-toggle" onClick={() => setTraceOpen(true)}>
            Mở chuỗi truy xuất
          </button>
          <mark>Prototype · dữ liệu cục bộ</mark>
        </header>
        <AtlasConnectionPanelView auth={auth} />
        <PageShell page={page}>{content}</PageShell>
      </div>
      {traceOpen && <TracePanel onClose={() => setTraceOpen(false)} />}
    </div>
  );
}
