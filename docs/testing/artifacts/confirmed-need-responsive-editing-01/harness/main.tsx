import { createRoot } from "react-dom/client";
import { AtlasVNextProvider } from "../../../../../src/vnext/atlas/AtlasVNextProvider";
import { AtlasVNextShell } from "../../../../../src/vnext/atlas/AtlasVNextShell";
import { ConfirmedNeedWorkbench } from "../../../../../src/vnext/atlas/planning-confirmed/ConfirmedNeedWorkbench";
import {
  createConfirmedNeedReviewFixture,
  reviewDate,
  type ConfirmedReviewScenario,
} from "../../../../../src/vnext/atlas/planning-confirmed/confirmedNeedReviewFixtures";

const scenario =
  new URLSearchParams(location.search).get("scenario") ?? "normal";
const fixture = createConfirmedNeedReviewFixture(
  scenario as ConfirmedReviewScenario,
);
createRoot(document.getElementById("root")!).render(
  <AtlasVNextProvider>
    <AtlasVNextShell activeModule="planning">
      <ConfirmedNeedWorkbench
        {...fixture}
        authSubject="fixture-operator"
        initialServiceDate={reviewDate}
        onContinueAllocation={() => {}}
      />
    </AtlasVNextShell>
  </AtlasVNextProvider>,
);
