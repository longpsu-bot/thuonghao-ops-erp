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

describe("Planning Inputs generation tab", () => {
  it("integrates automatic preflight into the fourth internal tab", async () => {
    render(
      <PlanningInputsWorkbench
        authState={authState}
        needGenerationApi={createReviewNeedGenerationApi("ready")}
        readinessApi={createReviewPlanningInputReadinessApi("ready")}
        mode="review"
      />,
    );
    const tabs = screen.getAllByRole("tab");
    expect(tabs).toHaveLength(5);
    expect(tabs[3]).toHaveTextContent("Tạo nhu cầu");
    fireEvent.click(tabs[3]!);
    expect(
      await screen.findByText(
        "Thực đơn, Sĩ số và Nhu cầu bổ sung đã sẵn sàng.",
      ),
    ).toBeVisible();
    expect(screen.getByRole("button", { name: "Tạo nhu cầu" })).toBeVisible();
  });
});
