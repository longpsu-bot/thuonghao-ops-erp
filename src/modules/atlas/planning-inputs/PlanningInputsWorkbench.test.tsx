import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import type { AtlasAuthState } from "../connection/authSession";
import { PlanningInputsWorkbench } from "./PlanningInputsWorkbench";
import { createReviewPlanningInputsApi } from "./reviewPlanningInputsApi";
import { createReviewPantryApi } from "./pantry/reviewPantryApi";

afterEach(cleanup);

const authState = {
  status: "authenticated",
  authSubject: "review-only-atlas-operator",
  user: { id: "review-only-atlas-operator" },
  session: {
    access_token: "review",
    refresh_token: "review",
    expires_in: 3600,
    token_type: "bearer",
    user: { id: "review-only-atlas-operator" },
  },
} as unknown as AtlasAuthState;

function renderWorkbench(scenario = "ready" as const) {
  return render(
    <PlanningInputsWorkbench
      authState={authState}
      api={createReviewPlanningInputsApi(scenario)}
      pantryApi={createReviewPantryApi(scenario)}
      mode="review"
    />,
  );
}

describe("UI-QUALITY-02A Planning source presentation", () => {
  it("keeps all six workflow destinations and selects each source workbench", async () => {
    renderWorkbench();

    const destinations = [
      "Thực đơn tuần",
      "Sĩ số",
      "Pantry",
      "Sẵn sàng đầu vào",
      "Tạo nhu cầu",
      "Xác nhận nhu cầu",
    ];
    expect(
      screen
        .getAllByRole("tab")
        .map((tab) => tab.textContent?.replace(/\s+/g, " ").trim()),
    ).toEqual(destinations);

    expect(
      (await screen.findAllByText("Canh bí đỏ thịt bằm")).length,
    ).toBeGreaterThan(0);
    expect(screen.getByLabelText("Thao tác vòng đời thực đơn")).toBeVisible();

    fireEvent.click(screen.getByRole("tab", { name: "Sĩ số" }));
    expect(
      await screen.findByLabelText("Nguồn và thao tác sĩ số"),
    ).toBeVisible();
    expect(screen.getByLabelText("Thao tác vòng đời sĩ số")).toBeVisible();

    fireEvent.click(screen.getByRole("tab", { name: "Pantry" }));
    expect(await screen.findByLabelText("Nhập và lưu Pantry")).toBeVisible();
    expect(screen.getByLabelText("Thao tác vòng đời Pantry")).toBeVisible();
  });

  it("keeps dirty state explicit and every business action text-labelled", async () => {
    renderWorkbench();

    fireEvent.change((await screen.findAllByLabelText(/Món canh ·/))[0], {
      target: { value: "review-planning-dish-3" },
    });

    expect(
      screen.getByText("Có thay đổi chưa lưu trong nguồn đang làm việc."),
    ).toBeVisible();
    for (const name of ["Xem trước", "Lưu bản nháp", "Hủy thay đổi"]) {
      expect(screen.getByRole("button", { name })).toHaveAccessibleName(name);
    }

    fireEvent.click(screen.getByRole("button", { name: "Xem trước" }));
    await waitFor(() =>
      expect(
        screen.getByRole("button", { name: "Lưu bản nháp" }),
      ).toBeEnabled(),
    );
  });
});
