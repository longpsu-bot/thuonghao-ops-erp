import { useState } from "react";
import { IngredientSupplierAdminWorkbench } from "../admin/IngredientSupplierAdminWorkbench";
import { SchoolAdminWorkbench } from "../admin/SchoolAdminWorkbench";
import { atlasGroups, atlasPages, type AtlasPageId } from "./atlasConfig";
import {
  ControlBoardPage,
  DocumentReleasePage,
  PlanningSourcesPage,
  PurchasePlanningPage,
  RequirementPlanningPage,
  SupportingPage,
  WarehouseReceivingPage,
  WarehouseStockReleasePage,
} from "./AtlasPages";
import { PageShell, TracePanel } from "./WorkbenchComponents";

export function AtlasApp({
  initialPage = "control-board",
}: {
  initialPage?: AtlasPageId;
}) {
  const [active, setActive] = useState<AtlasPageId>(initialPage);
  const [traceOpen, setTraceOpen] = useState(false);
  const page = atlasPages.find((candidate) => candidate.id === active)!;
  let content = <SupportingPage page={page} />;
  if (active === "control-board") content = <ControlBoardPage />;
  if (active === "planning-sources") content = <PlanningSourcesPage />;
  if (active === "requirement-planning") content = <RequirementPlanningPage />;
  if (active === "purchase-planning") content = <PurchasePlanningPage />;
  if (active === "document-release") content = <DocumentReleasePage />;
  if (active === "warehouse-receiving") content = <WarehouseReceivingPage />;
  if (active === "warehouse-stock-release")
    content = <WarehouseStockReleasePage />;
  if (active === "customers-schools") content = <SchoolAdminWorkbench />;
  if (active === "ingredients-units" || active === "suppliers-eligibility")
    content = <IngredientSupplierAdminWorkbench />;

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
        <PageShell page={page}>{content}</PageShell>
      </div>
      {traceOpen && <TracePanel onClose={() => setTraceOpen(false)} />}
    </div>
  );
}
