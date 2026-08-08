import "@testing-library/jest-dom/vitest";
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import type { AtlasAuthState } from "../../connection/authSession";
import { PlanningInputsWorkbench } from "../PlanningInputsWorkbench";
import { createReviewNeedGenerationApi } from "./reviewNeedGenerationApi";

afterEach(cleanup);

const authState = {
  status: "authenticated",
  authSubject: "review-only-atlas-operator",
  user: { id: "review-only-atlas-operator" },
  session: { user: { id: "review-only-atlas-operator" } },
} as unknown as AtlasAuthState;

describe("Planning Inputs fifth tab", () => {
  it("integrates Tạo nhu cầu as the fifth internal tab without new navigation", async () => {
    render(
      <PlanningInputsWorkbench
        authState={authState}
        needGenerationApi={createReviewNeedGenerationApi("ready")}
        mode="review"
      />,
    );
    const tabs = screen.getAllByRole("tab");
    expect(tabs).toHaveLength(6);
    expect(tabs[4]).toHaveTextContent("Tạo nhu cầu");
    fireEvent.click(tabs[4]!);
    expect(
      await screen.findByRole("heading", { name: "Sẵn sàng tạo nhu cầu" }),
    ).toBeVisible();
    expect(screen.getByRole("button", { name: "Tạo nhu cầu" })).toBeVisible();
  });
});
