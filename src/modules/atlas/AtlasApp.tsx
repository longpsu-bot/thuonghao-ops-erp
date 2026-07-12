import { useState } from "react";
import { PlannerWorkspacePage } from "../planner/PlannerWorkspacePage";
import {
  atlasPages,
  journeys,
  type AtlasPage,
  type AtlasPageId,
} from "./atlasConfig";

const groups = [
  "Overview",
  "Planning",
  "Procurement",
  "Fulfilment",
  "Master Data",
  "Administration",
];

function ResponsibilityPage({ page }: { page: AtlasPage }) {
  return (
    <section className="atlas-page">
      <div className="page-kicker">
        PROTOTYPE PLACEHOLDER · KHÔNG GHI DỮ LIỆU
      </div>
      <h1>{page.label}</h1>
      <p className="page-intro">
        Trang này mô tả trách nhiệm và bàn giao trong Atlas; chưa gọi backend và
        chưa tạo chứng từ vận hành.
      </p>
      <div className="responsibility-grid">
        <article>
          <span>Vai trò chịu trách nhiệm</span>
          <strong>{page.role}</strong>
        </article>
        <article>
          <span>Đầu vào</span>
          <strong>{page.input}</strong>
        </article>
        <article>
          <span>Trách nhiệm chính</span>
          <strong>{page.responsibility}</strong>
        </article>
        <article>
          <span>Đầu ra hoàn tất</span>
          <strong>{page.output}</strong>
        </article>
        <article>
          <span>Bàn giao tiếp theo</span>
          <strong>{page.handoff}</strong>
        </article>
      </div>
      <button className="page-action">
        {page.primaryAction} · dữ liệu mẫu
      </button>
      <div className="journey-strip">
        {journeys.map((journey) => (
          <div key={journey.id}>
            <strong>{journey.name}</strong>
            <span>{journey.context}</span>
          </div>
        ))}
      </div>
    </section>
  );
}

function OperationsHome({
  onNavigate,
}: {
  onNavigate: (id: AtlasPageId) => void;
}) {
  return (
    <section className="atlas-page home-page">
      <div className="page-kicker">OPERATIONS HOME · DỮ LIỆU MẪU</div>
      <h1>Điều phối vận hành theo kỳ</h1>
      <p className="page-intro">
        Kỳ vận hành 13/07/2026 – 15/07/2026 · 2 hành trình mẫu đang chờ rà soát.
      </p>
      <div className="journey-cards">
        {journeys.map((journey, index) => (
          <article key={journey.id}>
            <span>{journey.id}</span>
            <h2>{journey.name}</h2>
            <p>{journey.context}</p>
            <ol>
              {journey.flow.map((step) => (
                <li key={step}>{step}</li>
              ))}
            </ol>
            <button
              onClick={() =>
                onNavigate(index === 0 ? "menu-planning" : "additional-demand")
              }
            >
              Mở điểm vào hành trình
            </button>
          </article>
        ))}
      </div>
      <div className="handoff-board">
        <h2>Điểm bàn giao cần kiểm tra</h2>
        <button onClick={() => onNavigate("requirement-review")}>
          Requirement Review · Planning → Procurement
        </button>
        <button onClick={() => onNavigate("supplier-allocation")}>
          Supplier Allocation · Purchasing
        </button>
        <button onClick={() => onNavigate("operational-qa")}>
          Operational QA · phân tuyến ngoại lệ
        </button>
      </div>
    </section>
  );
}

export function AtlasApp() {
  const [active, setActive] = useState<AtlasPageId>("operations-home");
  const activePage = atlasPages.find((page) => page.id === active)!;
  return (
    <div className="atlas-shell">
      <aside className="atlas-sidebar">
        <div className="atlas-brand">
          <span>OPS ERP</span>
          <strong>Atlas</strong>
          <small>Workflow prototype</small>
        </div>
        <nav aria-label="Atlas navigation">
          {groups.map((group) => (
            <div className="nav-group" key={group}>
              <span>{group}</span>
              {atlasPages
                .filter((page) => page.group === group)
                .map((page) => (
                  <button
                    key={page.id}
                    className={active === page.id ? "active" : ""}
                    onClick={() => setActive(page.id)}
                  >
                    {page.label}
                  </button>
                ))}
            </div>
          ))}
        </nav>
      </aside>
      <div className="atlas-content">
        <header className="atlas-topbar">
          <div>
            <span>Operating period</span>
            <strong>13/07/2026 – 15/07/2026</strong>
          </div>
          <div>
            <span>Trang hiện tại</span>
            <strong>
              {activePage.label} · {activePage.role}
            </strong>
          </div>
          <mark>Prototype · không backend</mark>
        </header>
        {active === "operations-home" ? (
          <OperationsHome onNavigate={setActive} />
        ) : active === "requirement-review" ? (
          <div className="requirement-recovery">
            <div className="recovery-context">
              <span>Planning · Requirement Review</span>
              <strong>
                CAT-0713-ND + WS-2026-0714 · Bàn giao: Supplier Allocation
              </strong>
            </div>
            <PlannerWorkspacePage />
          </div>
        ) : (
          <ResponsibilityPage page={activePage} />
        )}
      </div>
    </div>
  );
}
