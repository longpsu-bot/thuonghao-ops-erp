import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import type { AtlasAuthState } from "../connection/authSession";
import { PlanningInputsWorkbench } from "./PlanningInputsWorkbench";
import { createReviewPlanningInputsApi } from "./reviewPlanningInputsApi";
import { createReviewPantryApi } from "./pantry/reviewPantryApi";
import { createReviewPlanningInputReadinessApi } from "./readiness/reviewPlanningInputReadinessApi";

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
});

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

function renderWorkbench(
  scenario: Parameters<typeof createReviewPlanningInputsApi>[0] = "ready",
) {
  return render(
    <PlanningInputsWorkbench
      authState={authState}
      api={createReviewPlanningInputsApi(scenario)}
      pantryApi={createReviewPantryApi(scenario)}
      readinessApi={createReviewPlanningInputReadinessApi(scenario)}
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

  it("protects a dirty Weekly Menu edit and makes save the next action", async () => {
    const confirm = vi.spyOn(window, "confirm").mockReturnValue(false);
    renderWorkbench();

    const menuCell = (await screen.findAllByLabelText(/Món canh ·/))[0];
    fireEvent.change(menuCell, {
      target: { value: "review-planning-dish-3" },
    });

    expect(
      screen.getByText("Có thay đổi chưa lưu trong nguồn đang làm việc."),
    ).toBeVisible();
    for (const name of ["Xem trước", "Lưu bản nháp", "Hủy thay đổi"]) {
      expect(screen.getByRole("button", { name })).toHaveAccessibleName(name);
    }
    expect(screen.getByRole("button", { name: "Lưu bản nháp" })).toBeEnabled();
    expect(screen.getByRole("button", { name: "Xác thực" })).toBeDisabled();

    fireEvent.click(screen.getByRole("tab", { name: "Sĩ số" }));
    expect(confirm).toHaveBeenCalledWith(
      "Có thay đổi chưa lưu. Chuyển khu vực sẽ bỏ các thay đổi này. Tiếp tục?",
    );
    expect(screen.getByRole("tab", { name: "Thực đơn tuần" })).toHaveAttribute(
      "aria-selected",
      "true",
    );
    expect(menuCell).toHaveValue("review-planning-dish-3");

    fireEvent.click(screen.getByRole("button", { name: "Lưu bản nháp" }));
    await waitFor(() =>
      expect(screen.getByRole("button", { name: "Xác thực" })).toBeEnabled(),
    );
    expect(screen.getByRole("button", { name: "Lưu bản nháp" })).toBeDisabled();
    expect(
      screen.queryByText("Có thay đổi chưa lưu trong nguồn đang làm việc."),
    ).not.toBeInTheDocument();
  });

  it("keeps Validate available for a clean saved Weekly Menu draft", async () => {
    const confirm = vi.spyOn(window, "confirm");
    renderWorkbench();

    await screen.findAllByLabelText(/Món canh ·/);
    expect(screen.getByRole("button", { name: "Lưu bản nháp" })).toBeDisabled();
    expect(screen.getByRole("button", { name: "Xác thực" })).toBeEnabled();

    fireEvent.click(screen.getByRole("tab", { name: "Sĩ số" }));
    expect(
      await screen.findByLabelText("Nguồn và thao tác sĩ số"),
    ).toBeVisible();
    expect(confirm).not.toHaveBeenCalled();
  });

  it("cancels Attendance edits back to the authoritative loaded values", async () => {
    renderWorkbench();
    fireEvent.click(screen.getByRole("tab", { name: "Sĩ số" }));

    const quantity = (await screen.findAllByLabelText(/Suất học sinh ·/))[0];
    const originalValue = quantity.getAttribute("value");
    fireEvent.change(quantity, { target: { value: "421" } });

    expect(quantity).toHaveValue(421);
    expect(screen.getByRole("button", { name: "Lưu bản nháp" })).toBeEnabled();
    expect(screen.getByRole("button", { name: "Xác thực" })).toBeDisabled();

    fireEvent.click(screen.getByRole("button", { name: "Hủy thay đổi" }));

    expect(quantity).toHaveAttribute("value", originalValue);
    expect(screen.getByRole("button", { name: "Lưu bản nháp" })).toBeDisabled();
    expect(screen.getByRole("button", { name: "Xác thực" })).toBeEnabled();
    expect(
      screen.queryByText("Có thay đổi chưa lưu trong nguồn đang làm việc."),
    ).not.toBeInTheDocument();
  });

  it("keeps a dirty Pantry edit mounted when tab discard is rejected", async () => {
    const confirm = vi.spyOn(window, "confirm").mockReturnValue(false);
    renderWorkbench();
    fireEvent.click(screen.getByRole("tab", { name: "Pantry" }));

    const quantity = await screen.findByLabelText("Số lượng dòng 1");
    fireEvent.change(quantity, { target: { value: "3.25" } });

    await waitFor(() => {
      const event = new Event("beforeunload", { cancelable: true });
      window.dispatchEvent(event);
      expect(event.defaultPrevented).toBe(true);
    });
    fireEvent.click(screen.getByRole("tab", { name: "Sĩ số" }));

    expect(confirm).toHaveBeenCalledWith(
      "Có thay đổi chưa lưu. Chuyển khu vực sẽ bỏ các thay đổi này. Tiếp tục?",
    );
    expect(screen.getByRole("tab", { name: "Pantry" })).toHaveAttribute(
      "aria-selected",
      "true",
    );
    expect(screen.getByLabelText("Số lượng dòng 1")).toHaveValue(3.25);
  });

  it("keeps the selected week and Pantry edit when week discard is rejected", async () => {
    const confirm = vi.spyOn(window, "confirm").mockReturnValue(false);
    renderWorkbench();
    fireEvent.click(screen.getByRole("tab", { name: "Pantry" }));

    const quantity = await screen.findByLabelText("Số lượng dòng 1");
    fireEvent.change(quantity, { target: { value: "4.5" } });
    const week = screen.getByLabelText("Tuần phục vụ");
    const originalWeek = week.getAttribute("value");
    fireEvent.change(week, { target: { value: "2026-08-10" } });

    expect(confirm).toHaveBeenCalledWith(
      "Bỏ các thay đổi chưa lưu để chuyển tuần?",
    );
    expect(week).toHaveAttribute("value", originalWeek);
    expect(screen.getByLabelText("Số lượng dòng 1")).toHaveValue(4.5);
  });

  it("protects explicit Pantry no-additions as unsaved local work", async () => {
    const confirm = vi
      .spyOn(window, "confirm")
      .mockReturnValueOnce(true)
      .mockReturnValueOnce(false);
    renderWorkbench();
    fireEvent.click(screen.getByRole("tab", { name: "Pantry" }));

    await screen.findByLabelText("Số lượng dòng 1");
    fireEvent.click(
      screen.getByRole("checkbox", {
        name: "Xác nhận tuần này không có bổ sung",
      }),
    );
    expect(screen.getByText(/Đã chọn xác nhận không có bổ sung/)).toBeVisible();

    fireEvent.click(screen.getByRole("tab", { name: "Sĩ số" }));

    expect(screen.getByRole("tab", { name: "Pantry" })).toHaveAttribute(
      "aria-selected",
      "true",
    );
    expect(
      screen.getByRole("checkbox", {
        name: "Xác nhận tuần này không có bổ sung",
      }),
    ).toBeChecked();
    expect(confirm).toHaveBeenLastCalledWith(
      "Có thay đổi chưa lưu. Chuyển khu vực sẽ bỏ các thay đổi này. Tiếp tục?",
    );
  });

  it("keeps an unevaluated Readiness candidate selection when tab discard is rejected", async () => {
    const confirm = vi.spyOn(window, "confirm").mockReturnValue(false);
    renderWorkbench("menu_duplicate");
    fireEvent.click(screen.getByRole("tab", { name: "Sẵn sàng đầu vào" }));

    const selector = await screen.findByRole("combobox", {
      name: "Chọn bằng chứng Thực đơn tuần",
    });
    const option = Array.from(selector.querySelectorAll("option"))[1];
    if (!option) throw new Error("Missing ambiguous readiness candidate.");
    fireEvent.change(selector, { target: { value: option.value } });
    await waitFor(() =>
      expect(
        screen.getByRole("button", { name: "Đánh giá mức sẵn sàng" }),
      ).toBeEnabled(),
    );

    const event = new Event("beforeunload", { cancelable: true });
    window.dispatchEvent(event);
    expect(event.defaultPrevented).toBe(true);

    fireEvent.click(screen.getByRole("tab", { name: "Tạo nhu cầu" }));
    expect(confirm).toHaveBeenCalledWith(
      "Có thay đổi chưa lưu. Chuyển khu vực sẽ bỏ các thay đổi này. Tiếp tục?",
    );
    expect(
      screen.getByRole("tab", { name: "Sẵn sàng đầu vào" }),
    ).toHaveAttribute("aria-selected", "true");
    expect(
      screen.getByRole("button", { name: "Đánh giá mức sẵn sàng" }),
    ).toBeEnabled();
  });
});
