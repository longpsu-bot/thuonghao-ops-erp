import "@testing-library/jest-dom/vitest";
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import type { AtlasAuthState } from "../../connection/authSession";
import { PlanningInputsWorkbench } from "../PlanningInputsWorkbench";
import { createReviewPlanningInputReadinessApi } from "../readiness/reviewPlanningInputReadinessApi";
import { createReviewNeedGenerationApi } from "./reviewNeedGenerationApi";

afterEach(cleanup);

const authState = {
  status: "authenticated",
  authSubject: "review-only-atlas-operator",
  user: { id: "review-only-atlas-operator" },
  session: { user: { id: "review-only-atlas-operator" } },
} as unknown as AtlasAuthState;

describe("Planning Inputs contextual generation", () => {
  it("integrates automatic preflight into the compact daily navigator without a peer tab", async () => {
    render(
      <PlanningInputsWorkbench
        authState={authState}
        needGenerationApi={createReviewNeedGenerationApi("ready")}
        readinessApi={createReviewPlanningInputReadinessApi("ready")}
        mode="review"
      />,
    );
    const tabs = screen.getAllByRole("tab");
    expect(tabs).toHaveLength(4);
    expect(tabs[3]).toHaveAccessibleName("Xác nhận nhu cầu");
    expect(tabs[3]).toHaveTextContent("Xác nhận");
    expect(
      screen.queryByRole("tab", { name: "Tạo nhu cầu" }),
    ).not.toBeInTheDocument();
    fireEvent.click(tabs[3]!);
    expect(
      await screen.findByRole("navigation", {
        name: "Chọn ngày xác nhận nhu cầu",
      }),
    ).toBeVisible();
    expect(
      screen.queryByRole("button", { name: /^Tạo nhu cầu$/ }),
    ).not.toBeInTheDocument();
  });
});
