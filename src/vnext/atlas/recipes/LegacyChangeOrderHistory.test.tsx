import "@testing-library/jest-dom/vitest";
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, expect, it, vi } from "vitest";
import { AtlasVNextProvider } from "../AtlasVNextProvider";
import { LegacyChangeOrderHistory } from "./LegacyChangeOrderHistory";
import type { LegacyRecipeChangeOrder } from "../bridges/recipeAdjustment";

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});
const row: LegacyRecipeChangeOrder = {
  source_table: "system_bom_change_orders",
  legacy_id: "1",
  scope_kind: "SYSTEM_DISH",
  action: "ADJUST_QUANTITY",
  source_active: false,
  effective_from: "2026-01-19",
  source_created_at: null,
  source_school_type_id: "1",
  quantity: "1.000001",
  unit_name: "kg",
  dish_name: "Canh bí",
  school_name: null,
  ingredient_name: "Muối",
  substitute_name: null,
  note: "Ghi chú nguồn",
};

it("discloses bounded read-only history without claiming cancellation or current effect", () => {
  vi.stubGlobal(
    "ResizeObserver",
    class {
      observe() {}
      unobserve() {}
      disconnect() {}
    },
  );
  render(
    <AtlasVNextProvider>
      <LegacyChangeOrderHistory
        rows={Array.from({ length: 27 }, (_, i) => ({
          ...row,
          legacy_id: String(i + 1),
        }))}
        query=""
      />
    </AtlasVNextProvider>,
  );
  expect(screen.queryByRole("table")).not.toBeInTheDocument();
  const details = screen.getByText(/Lịch sử OPS v1/).closest("details")!;
  details.open = true;
  fireEvent(details, new Event("toggle", { bubbles: true }));
  expect(screen.getAllByText("Nguồn inactive; không rõ ngày hủy")).toHaveLength(
    25,
  );
  expect(screen.getAllByText(/1.000001/)).toHaveLength(25);
  expect(
    screen.queryByRole("button", { name: "Hủy lệnh" }),
  ).not.toBeInTheDocument();
  fireEvent.click(screen.getByRole("button", { name: "Xem thêm lịch sử" }));
  expect(screen.getAllByText("Nguồn inactive; không rõ ngày hủy")).toHaveLength(
    27,
  );
});

it("filters source history by the existing accent-insensitive search", () => {
  render(
    <AtlasVNextProvider>
      <LegacyChangeOrderHistory rows={[row]} query="thit" />
    </AtlasVNextProvider>,
  );
  expect(screen.getByText(/Lịch sử OPS v1 · 0\/1/)).toBeInTheDocument();
});
