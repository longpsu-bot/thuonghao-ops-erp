import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { afterEach, beforeEach, expect, it, vi } from "vitest";
import { AtlasVNextProvider } from "../AtlasVNextProvider";
import { createAtlasApplicationFixture } from "../atlasApplicationReviewFixtures";
import { PlanningCapability } from "./PlanningCapability";
import {
  createPlanningReviewFixture,
  reviewWeek,
} from "./planningReviewFixtures";
import { createConfirmedNeedReviewFixture } from "../planning-confirmed/confirmedNeedReviewFixtures";

beforeEach(() =>
  vi.stubGlobal(
    "ResizeObserver",
    class {
      observe() {}
      unobserve() {}
      disconnect() {}
    },
  ),
);
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

it("retains its local date across external seed changes and forwards both owners' reports", async () => {
  const sources = createPlanningReviewFixture();
  const confirmed = createConfirmedNeedReviewFixture();
  const apis = {
    ...createAtlasApplicationFixture(),
    planning: sources.api,
    pantry: sources.pantryApi,
    planningReadiness: confirmed.preflightApi,
    needGeneration: confirmed.needGenerationApi,
    confirmedNeed: confirmed.confirmedNeedApi,
  };
  const report = vi.fn();
  const notify = vi.fn();
  const navigate = vi.fn();
  const view = (seed: string) => (
    <AtlasVNextProvider>
      <PlanningCapability
        authSubject="operator"
        apis={apis}
        serviceDate={seed}
        onServiceDateChange={notify}
        onContinueAllocation={navigate}
        onWorkspaceStatus={report}
      />
    </AtlasVNextProvider>
  );
  const { rerender } = render(view(reviewWeek));
  await screen.findByRole("table", { name: "Thực đơn theo trường" });
  await waitFor(() =>
    expect(report).toHaveBeenLastCalledWith(
      expect.objectContaining({ unsaved: false, blocked: false }),
    ),
  );
  rerender(view("2026-09-14"));
  fireEvent.click(screen.getByRole("tab", { name: "Xác nhận nhu cầu" }));
  const quantity = await screen.findByRole("textbox", {
    name: "Số lượng xác nhận Gạo thơm",
  });
  fireEvent.click(screen.getByRole("button", { name: "Bộ lọc" }));
  expect(screen.getByRole("spinbutton", { name: "Day" })).toHaveAttribute(
    "aria-valuenow",
    "7",
  );
  expect(screen.getByRole("spinbutton", { name: "Month" })).toHaveAttribute(
    "aria-valuenow",
    "9",
  );
  expect(screen.getByRole("spinbutton", { name: "Year" })).toHaveAttribute(
    "aria-valuenow",
    "2026",
  );
  expect(notify).toHaveBeenLastCalledWith(reviewWeek);
  fireEvent.change(quantity, { target: { value: "12,5" } });
  expect(report).toHaveBeenLastCalledWith(
    expect.objectContaining({ unsaved: true }),
  );
});
