import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { createReviewAuthState } from "../atlas/review/reviewMode";
import { createReviewRecipeApi } from "../atlas/recipes/reviewRecipeApi";
import { DishRecipeAdminWorkbench } from "./DishRecipeAdminWorkbench";

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
});

function renderWorkbench() {
  return render(
    <DishRecipeAdminWorkbench
      authState={createReviewAuthState("ready")}
      api={createReviewRecipeApi("ready")}
      mode="review"
    />,
  );
}

describe("connected Dish and Recipe workbench", () => {
  it("loads the authoritative catalog and exposes all bounded operator journeys", async () => {
    renderWorkbench();
    expect(
      screen.getByLabelText("Tóm tắt quản trị món ăn và công thức"),
    ).toBeInTheDocument();
    expect(
      (await screen.findAllByText("Canh bí đỏ thịt bằm")).length,
    ).toBeGreaterThan(0);
    for (const tab of [
      "Món ăn",
      "Phiên bản & BOM",
      "Sao chép",
      "Nhập workbook",
    ])
      expect(screen.getByRole("tab", { name: tab })).toBeEnabled();
    expect(screen.queryByText(/Retool layer/i)).not.toBeInTheDocument();
  });

  it("validates and releases only through explicit reviewed commands", async () => {
    vi.spyOn(window, "confirm").mockReturnValue(true);
    renderWorkbench();
    await screen.findAllByText("Canh bí đỏ thịt bằm");
    fireEvent.click(screen.getByRole("tab", { name: "Phiên bản & BOM" }));
    expect(await screen.findByText("Phiên bản v1")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Xác thực" }));
    await waitFor(() =>
      expect(
        screen.getByRole("button", {
          name: "Phát hành cho Lập nhu cầu",
        }),
      ).toBeEnabled(),
    );
    fireEvent.click(
      screen.getByRole("button", { name: "Phát hành cho Lập nhu cầu" }),
    );
    await waitFor(() =>
      expect(
        screen.getAllByText("Đã phát hành cho Lập nhu cầu").length,
      ).toBeGreaterThan(0),
    );
    expect(window.confirm).toHaveBeenCalledTimes(2);
  });

  it("shows the immutable-successor and future-planning boundary", async () => {
    renderWorkbench();
    await screen.findAllByText("Canh bí đỏ thịt bằm");
    fireEvent.click(screen.getByRole("tab", { name: "Phiên bản & BOM" }));
    expect(
      await screen.findByText(
        /Mọi điều chỉnh phải đi qua một phiên bản kế nhiệm/,
      ),
    ).toBeInTheDocument();
    expect(
      screen.getByText(/chỉ ảnh hưởng tham chiếu Lập nhu cầu trong tương lai/),
    ).toBeInTheDocument();
  });
});
