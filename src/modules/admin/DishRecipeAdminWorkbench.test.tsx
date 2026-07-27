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
import { createReviewRecipeAdjustmentApi } from "../atlas/recipe-adjustments/reviewRecipeAdjustmentApi";
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
      adjustmentApi={createReviewRecipeAdjustmentApi("ready")}
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
      "Quy tắc điều chỉnh",
      "BOM hiệu lực",
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

  it("previews every source composition line before copy", async () => {
    renderWorkbench();
    await screen.findAllByText("Canh bí đỏ thịt bằm");
    fireEvent.click(screen.getByRole("tab", { name: "Sao chép" }));
    const sourceSelect = screen.getByLabelText(
      "Phiên bản nguồn",
    ) as HTMLSelectElement;
    fireEvent.change(sourceSelect, {
      target: { value: sourceSelect.options[1].value },
    });
    expect(
      screen.getByRole("heading", {
        name: "Thành phần công thức nguồn",
      }),
    ).toBeInTheDocument();
    expect(screen.getByText("Bí đỏ (bi-do)")).toBeInTheDocument();
    expect(screen.getByText("Thịt heo xay (thit-heo-xay)")).toBeInTheDocument();
    expect(screen.getAllByText("Kilôgam (kg)")).toHaveLength(2);
    expect(screen.getAllByText("Có hiệu lực")).toHaveLength(2);
  });
});
