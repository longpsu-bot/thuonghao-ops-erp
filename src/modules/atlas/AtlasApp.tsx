import { useState } from "react";
import {
  atlasGroups,
  atlasPages,
  journeys,
  type AtlasPage,
  type AtlasPageId,
} from "./atlasConfig";

const purchaseOrderPreview = [
  {
    ingredient: "Pumpkin",
    supplier: "An Phu Produce",
    quantity: "75 kg",
    coordination: "Optional note: delivery window acknowledged by phone",
  },
  {
    ingredient: "Jasmine rice",
    supplier: "Thanh Cong Foods",
    quantity: "250 kg",
    coordination: "No supplier confirmation required for this 24-hour cycle",
  },
];

const receivingPreview = [
  {
    ingredient: "Pumpkin",
    ordered: "75 kg",
    received: "75 kg",
    result: "Matched",
  },
  {
    ingredient: "Jasmine rice",
    ordered: "250 kg",
    received: "240 kg",
    result: "Discrepancy: short by 10 kg",
  },
];

function ResponsibilityPage({ page }: { page: AtlasPage }) {
  return (
    <section className="atlas-page">
      <div className="page-kicker">
        MOCK PROTOTYPE · NO BACKEND OR DOCUMENT RELEASE
      </div>
      <h1>{page.label}</h1>
      <p className="page-intro">
        This page describes the responsibility and handoff for the Atlas
        prototype. All values are static fixtures and no operational record is
        created.
      </p>
      <div className="responsibility-grid">
        <article>
          <span>Responsible role</span>
          <strong>{page.role}</strong>
        </article>
        <article>
          <span>Input</span>
          <strong>{page.input}</strong>
        </article>
        <article>
          <span>Primary responsibility</span>
          <strong>{page.responsibility}</strong>
        </article>
        <article>
          <span>Completed output</span>
          <strong>{page.output}</strong>
        </article>
        <article>
          <span>Next handoff</span>
          <strong>{page.handoff}</strong>
        </article>
      </div>
      {page.id === "requirement-planning" && (
        <div className="handoff-board">
          <h2>Destination is planned with the requirement</h2>
          <span>
            Example: 75 kg pumpkin for Nguyen Du School · Route North. The
            outbound destination remains attached before purchasing begins.
          </span>
        </div>
      )}
      {page.id === "purchase-planning" && (
        <div className="handoff-board">
          <h2>Supplier assignment and order preparation</h2>
          {purchaseOrderPreview.map((line) => (
            <article key={line.ingredient}>
              <strong>
                {line.ingredient} · {line.quantity}
              </strong>
              <span>{line.supplier}</span>
              <small>{line.coordination}</small>
            </article>
          ))}
        </div>
      )}
      {page.id === "warehouse-receiving" && (
        <div className="handoff-board">
          <h2>Ordered versus received</h2>
          {receivingPreview.map((line) => (
            <article key={line.ingredient}>
              <strong>{line.ingredient}</strong>
              <span>
                Ordered: {line.ordered} · Received: {line.received}
              </span>
              <small>{line.result}</small>
            </article>
          ))}
        </div>
      )}
      <button className="page-action" disabled>
        {page.primaryAction} · mock data
      </button>
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
      <div className="page-kicker">ATLAS WORKFLOW · MOCK DATA</div>
      <h1>Three-stage operating workflow</h1>
      <p className="page-intro">
        Atlas currently focuses on requirements, purchase planning, and
        warehouse receiving. Driver handoff, school handoff, QA, and accounting
        workflows are not active stages.
      </p>
      <div className="journey-cards">
        {journeys.map((journey) => (
          <article key={journey.id}>
            <span>{journey.id}</span>
            <h2>{journey.name}</h2>
            <p>{journey.context}</p>
            <ol>
              {journey.flow.map((step) => (
                <li key={step}>{step}</li>
              ))}
            </ol>
            <button onClick={() => onNavigate("requirement-planning")}>
              Open requirement planning
            </button>
          </article>
        ))}
      </div>
      <div className="handoff-board">
        <h2>Active workflow stages</h2>
        <button onClick={() => onNavigate("requirement-planning")}>
          1. Requirement Planning
        </button>
        <button onClick={() => onNavigate("purchase-planning")}>
          2. Purchase Planning
        </button>
        <button onClick={() => onNavigate("warehouse-receiving")}>
          3. Warehouse Receiving
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
            <span>Operating period</span>
            <strong>13/07/2026 – 15/07/2026</strong>
          </div>
          <div>
            <span>Current page</span>
            <strong>
              {activePage.label} · {activePage.role}
            </strong>
          </div>
          <mark>Prototype · no backend</mark>
        </header>
        {active === "operations-home" ? (
          <OperationsHome onNavigate={setActive} />
        ) : (
          <ResponsibilityPage page={activePage} />
        )}
      </div>
    </div>
  );
}
