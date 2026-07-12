import { useState } from "react";
import { PlannerWorkspacePage } from "../planner/PlannerWorkspacePage";
import {
  atlasPages,
  atlasGroups,
  journeys,
  type AtlasPage,
  type AtlasPageId,
} from "./atlasConfig";

const journeyGroups = new Set(["Lập kế hoạch", "Mua hàng", "Thực hiện"]);

function ResponsibilityPage({ page }: { page: AtlasPage }) {
  return (
    <section className="atlas-page">
      <div className="page-kicker">
        CHỨC NĂNG DỰ KIẾN · PROTOTYPE · KHÔNG GHI DỮ LIỆU
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
      <button className="page-action" disabled>
        {page.primaryAction} · thao tác dự kiến (prototype)
      </button>
      {journeyGroups.has(page.group) ? (
        <div className="journey-strip" aria-label="Ngữ cảnh hành trình mẫu">
          {journeys.map((journey) => (
            <div key={journey.id}>
              <strong>
                {journey.id} · {journey.name}
              </strong>
              <span>{journey.context}</span>
            </div>
          ))}
        </div>
      ) : null}
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
      <div className="page-kicker">TRANG ĐIỀU HÀNH · DỮ LIỆU MẪU</div>
      <h1>Trang điều hành</h1>
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
              Mở trang bắt đầu hành trình
            </button>
          </article>
        ))}
      </div>
      <div className="handoff-board">
        <h2>Điểm bàn giao cần kiểm tra</h2>
        <button onClick={() => onNavigate("requirement-review")}>
          Rà soát nhu cầu nguyên liệu · Lập kế hoạch → Mua hàng
        </button>
        <button onClick={() => onNavigate("supplier-allocation")}>
          Phân bổ nhà cung cấp · Mua hàng
        </button>
        <button onClick={() => onNavigate("operational-qa")}>
          Kiểm soát vận hành · phân tuyến ngoại lệ
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
          <small>Prototype luồng vận hành</small>
        </div>
        <nav aria-label="Atlas navigation">
          {atlasGroups.map((group) => (
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
            <span>Kỳ vận hành</span>
            <strong>13/07/2026 – 15/07/2026</strong>
          </div>
          <div>
            <span>Trang hiện tại</span>
            <strong>
              {activePage.label} · {activePage.role}
            </strong>
          </div>
          <mark>Prototype · không có backend</mark>
        </header>
        {active === "operations-home" ? (
          <OperationsHome onNavigate={setActive} />
        ) : active === "requirement-review" ? (
          <div className="requirement-recovery">
            <div className="recovery-context">
              <span>Lập kế hoạch · Rà soát nhu cầu nguyên liệu</span>
              <strong>
                CAT-0713-ND + WS-2026-0714 · Bàn giao: Phân bổ nhà cung cấp
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
