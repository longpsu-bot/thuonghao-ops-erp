import React from "react";
import { createRoot } from "react-dom/client";
import { AtlasVNextProvider } from "/src/vnext/atlas/AtlasVNextProvider";
import { AtlasVNextShell } from "/src/vnext/atlas/AtlasVNextShell";
import { SchoolFulfilmentWorkbench } from "/src/vnext/atlas/reconciliation/SchoolFulfilmentWorkbench";
import {
  createSchoolFulfilmentReviewFixture,
  type SchoolFulfilmentScenario,
} from "/src/vnext/atlas/reconciliation/schoolFulfilmentReviewFixtures";
const scenario = (new URLSearchParams(location.search).get("scenario") ||
  "ATTENTION_MIXED") as SchoolFulfilmentScenario;
const fixture = createSchoolFulfilmentReviewFixture(scenario);
(window as any).fixtureReads = 0;
const api = {
  async getWorkbench(request: any) {
    (window as any).fixtureReads++;
    return fixture.getWorkbench(request);
  },
};
createRoot(document.getElementById("root")!).render(
  <AtlasVNextProvider>
    <AtlasVNextShell activeModule="reconciliation">
      <SchoolFulfilmentWorkbench
        api={api}
        authSubject="fixture-operator"
        initialDateStart="2026-09-24"
        initialDateEnd="2026-09-26"
      />
    </AtlasVNextShell>
  </AtlasVNextProvider>,
);
