import { type ReactNode, useState } from "react";
import { PlannerWorkspacePage } from "../planner/PlannerWorkspacePage";
import {
  atlasGroups,
  atlasPages,
  type AtlasPage,
  type AtlasPageId,
} from "./atlasConfig";
import {
  workflowJourneyById,
  workflowJourneys,
  type JourneyId,
} from "./workflowFixtures";

const journeyGroups = new Set(["Lập kế hoạch", "Mua hàng", "Thực hiện"]);

function ResponsibilityDetails({ page }: { page: AtlasPage }) {
  return (
    <>
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
    </>
  );
}

function JourneyWorkflowPanel({
  activePage,
  selectedJourneyId,
  progress,
  onSelectJourney,
  onAdvance,
  onNavigate,
}: {
  activePage: AtlasPageId;
  selectedJourneyId: JourneyId;
  progress: Record<JourneyId, number>;
  onSelectJourney: (id: JourneyId) => void;
  onAdvance: () => void;
  onNavigate: (id: AtlasPageId) => void;
}) {
  const journey = workflowJourneyById[selectedJourneyId];
  const currentIndex = progress[selectedJourneyId];
  const currentStage = journey.stages[currentIndex];
  const isCurrentPage = currentStage.pageId === activePage;
  const isComplete = currentIndex === journey.stages.length - 1;

  return (
    <section className="workflow-panel" aria-label="Tiến độ hành trình mẫu">
      <div className="workflow-panel-head">
        <div>
          <span>DỮ LIỆU MẪU · TIẾN ĐỘ CỤC BỘ</span>
          <h2>Hành trình đang chọn: {journey.id}</h2>
          <p>
            {journey.name} · {journey.context}
          </p>
        </div>
        <div className="journey-picker" aria-label="Chọn hành trình mẫu">
          {workflowJourneys.map((option) => (
            <button
              className={option.id === selectedJourneyId ? "active" : ""}
              key={option.id}
              onClick={() => onSelectJourney(option.id)}
            >
              {option.id}
            </button>
          ))}
        </div>
      </div>
      <p className="workflow-source">Nguồn mẫu: {journey.sourceSummary}</p>
      <ol className="workflow-stages">
        {journey.stages.map((stage, index) => (
          <li
            className={
              index < currentIndex
                ? "complete"
                : index === currentIndex
                  ? "current"
                  : "pending"
            }
            key={`${journey.id}-${stage.pageId}`}
          >
            <span>{index + 1}</span>
            <strong>{stage.label}</strong>
            <small>
              {index < currentIndex
                ? "Đã mô phỏng"
                : index === currentIndex
                  ? "Đang rà soát"
                  : "Chờ mô phỏng"}
            </small>
          </li>
        ))}
      </ol>
      <div className="workflow-snapshot">
        <div>
          <span>Giai đoạn hiện tại</span>
          <strong>{currentStage.label}</strong>
        </div>
        <div>
          <span>Vai trò</span>
          <strong>{currentStage.role}</strong>
        </div>
        <div>
          <span>Đầu vào mẫu</span>
          <strong>{currentStage.inputSnapshot}</strong>
        </div>
        <div>
          <span>Đầu ra mẫu</span>
          <strong>{currentStage.outputSnapshot}</strong>
        </div>
        <div>
          <span>Bàn giao tiếp theo</span>
          <strong>{currentStage.nextHandoff}</strong>
        </div>
      </div>
      {currentStage.blocker ? (
        <p className="workflow-blocker">Cần lưu ý: {currentStage.blocker}</p>
      ) : null}
      <div className="workflow-actions">
        {isCurrentPage ? (
          <button disabled={isComplete} onClick={onAdvance}>
            {isComplete
              ? "Đã đến QA mẫu"
              : "Mô phỏng hoàn tất và chuyển bàn giao"}
          </button>
        ) : (
          <button onClick={() => onNavigate(currentStage.pageId)}>
            Đến giai đoạn hiện tại
          </button>
        )}
        <small>
          Chỉ thay đổi trạng thái trong bộ nhớ; tải lại trang sẽ đặt lại.
        </small>
      </div>
    </section>
  );
}

function ResponsibilityPage({
  page,
  workflow,
}: {
  page: AtlasPage;
  workflow: ReactNode;
}) {
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
      <ResponsibilityDetails page={page} />
      {workflow}
      <button className="page-action" disabled>
        {page.primaryAction} · thao tác dự kiến (prototype)
      </button>
    </section>
  );
}

function OperationsHome({
  onNavigate,
  onSelectJourney,
}: {
  onNavigate: (id: AtlasPageId) => void;
  onSelectJourney: (id: JourneyId) => void;
}) {
  return (
    <section className="atlas-page home-page">
      <div className="page-kicker">TRANG ĐIỀU HÀNH · DỮ LIỆU MẪU</div>
      <h1>Trang điều hành</h1>
      <p className="page-intro">
        Kỳ vận hành 13/07/2026 – 15/07/2026 · chọn hành trình để rà soát bàn
        giao mẫu từ nguồn đến QA.
      </p>
      <div className="journey-cards">
        {workflowJourneys.map((journey) => (
          <article key={journey.id}>
            <span>{journey.id}</span>
            <h2>{journey.name}</h2>
            <p>{journey.context}</p>
            <p className="journey-source">{journey.sourceSummary}</p>
            <ol>
              {journey.stages.map((stage) => (
                <li key={stage.pageId}>{stage.label}</li>
              ))}
            </ol>
            <button
              onClick={() => {
                onSelectJourney(journey.id);
                onNavigate(journey.stages[0].pageId);
              }}
            >
              Mở hành trình mẫu
            </button>
          </article>
        ))}
      </div>
      <div className="handoff-board">
        <h2>Ranh giới vận hành cần rà soát</h2>
        <span>
          Rà soát nhu cầu nguyên liệu tách biệt với Phân bổ nhà cung cấp.
        </span>
        <span>Tiếp nhận và chuẩn bị kho tách biệt với giao nhận ra ngoài.</span>
      </div>
    </section>
  );
}

export function AtlasApp() {
  const [active, setActive] = useState<AtlasPageId>("operations-home");
  const [selectedJourneyId, setSelectedJourneyId] =
    useState<JourneyId>("CAT-0713-ND");
  const [progress, setProgress] = useState<Record<JourneyId, number>>({
    "CAT-0713-ND": 0,
    "WS-2026-0714": 0,
  });
  const activePage = atlasPages.find((page) => page.id === active)!;
  const showWorkflow = journeyGroups.has(activePage.group);

  const advanceJourney = () => {
    const journey = workflowJourneyById[selectedJourneyId];
    const currentIndex = progress[selectedJourneyId];
    const nextStage = journey.stages[currentIndex + 1];
    if (!nextStage) return;

    setProgress((current) => ({
      ...current,
      [selectedJourneyId]: currentIndex + 1,
    }));
    setActive(nextStage.pageId);
  };

  const workflow = showWorkflow ? (
    <JourneyWorkflowPanel
      activePage={active}
      onAdvance={advanceJourney}
      onNavigate={setActive}
      onSelectJourney={setSelectedJourneyId}
      progress={progress}
      selectedJourneyId={selectedJourneyId}
    />
  ) : null;

  return (
    <div className="atlas-shell">
      <aside className="atlas-sidebar">
        <div className="atlas-brand">
          <span>OPS ERP</span>
          <strong>Atlas</strong>
          <small>Prototype luồng vận hành</small>
        </div>
        <nav aria-label="Điều hướng Atlas">
          {atlasGroups.map((group) => (
            <div className="nav-group" key={group}>
              <span>{group}</span>
              {atlasPages
                .filter((page) => page.group === group)
                .map((page) => (
                  <button
                    className={active === page.id ? "active" : ""}
                    key={page.id}
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
          <OperationsHome
            onNavigate={setActive}
            onSelectJourney={setSelectedJourneyId}
          />
        ) : active === "requirement-review" ? (
          <div className="requirement-recovery">
            <div className="recovery-context">
              <span>Lập kế hoạch · Rà soát nhu cầu nguyên liệu</span>
              <strong>
                {selectedJourneyId} · Bàn giao: Phân bổ nhà cung cấp
              </strong>
            </div>
            <div className="workflow-wrapper">{workflow}</div>
            <PlannerWorkspacePage />
          </div>
        ) : (
          <ResponsibilityPage page={activePage} workflow={workflow} />
        )}
      </div>
    </div>
  );
}
