import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  within,
} from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import { AtlasVNextProvider } from "./AtlasVNextProvider";
import { AtlasDesignLanguageReference } from "./AtlasDesignLanguageReference";

afterEach(cleanup);
const show = () =>
  render(
    <AtlasVNextProvider>
      <AtlasDesignLanguageReference />
    </AtlasVNextProvider>,
  );

describe("Atlas design language reference", () => {
  it("exposes one workbench heading and the canonical filter order", () => {
    show();
    expect(screen.getAllByRole("heading", { level: 1 })).toHaveLength(1);
    const toolbar = screen.getByRole("group", { name: "Phạm vi mua hàng" });
    const fields = toolbar.querySelectorAll("input, select, button");
    expect(
      Array.from(fields, (field) => field.getAttribute("aria-label")),
    ).toEqual([
      "Ngày phục vụ",
      "Trường",
      "Tìm kiếm",
      "Trạng thái",
      "Làm mới dữ liệu",
    ]);
  });
  it("uses semantic columns, explicit selected text and one primary detail action", () => {
    show();
    const table = screen.getByRole("table");
    expect(
      within(table)
        .getAllByRole("columnheader")
        .map((header) => header.textContent),
    ).toEqual([
      "Nguyên liệu",
      "Trường / điểm giao",
      "Số lượng",
      "Đơn vị",
      "Trạng thái",
      "Thao tác",
    ]);
    const selected = within(table).getByText("Đang chọn").closest("tr");
    expect(selected).toHaveAttribute("aria-selected", "true");
    const detail = screen.getByRole("region", { name: "Phân bổ Gạo thơm" });
    expect(
      within(detail).getByRole("button", { name: "Lưu phân bổ" }),
    ).toBeEnabled();
    expect(within(detail).getByRole("button", { name: "Đóng" })).toBeEnabled();
  });
  it("filters fixtures and exposes an empty state without changing business data", () => {
    show();
    fireEvent.change(screen.getByLabelText("Tìm kiếm"), {
      target: { value: "không có nguyên liệu" },
    });
    expect(screen.getByText("Không có nguyên liệu phù hợp")).toBeVisible();
    expect(
      screen.queryByRole("region", { name: "Phân bổ Gạo thơm" }),
    ).not.toBeInTheDocument();
  });
  it("blocks commitment when the fixture outcome is unknown", () => {
    render(
      <AtlasVNextProvider>
        <AtlasDesignLanguageReference scenario="unknown" />
      </AtlasVNextProvider>,
    );
    expect(screen.getByText("Chưa xác định kết quả lưu")).toBeVisible();
    expect(screen.getByRole("button", { name: "Lưu phân bổ" })).toBeDisabled();
  });
});
