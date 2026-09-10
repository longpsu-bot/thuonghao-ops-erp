import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  within,
} from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { act } from "react";
import { AtlasVNextProvider } from "./AtlasVNextProvider";
import { AtlasDesignLanguageReference } from "./AtlasDesignLanguageReference";

afterEach(() => {
  cleanup();
  vi.useRealTimers();
});
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
    expect(screen.getByRole("heading", { level: 1 })).toHaveTextContent(
      "Phân bổ nhà cung ứng",
    );
    expect(screen.getByText("Kế hoạch mua hàng")).toBeVisible();
    const toolbar = screen.getByRole("group", { name: "Phạm vi mua hàng" });
    expect(
      within(toolbar)
        .getAllByRole("spinbutton")
        .map((el) => el.getAttribute("data-type")),
    ).toEqual(["day", "month", "year"]);
    const fields = toolbar.querySelectorAll(
      'input:not([type="hidden"]), select, button',
    );
    expect(
      Array.from(fields, (field) => field.getAttribute("aria-label")),
    ).toEqual(["Trường", "Tìm kiếm", "Trạng thái", "Làm mới dữ liệu"]);
  });
  it("uses semantic columns, dense accessible selection and explicit row actions", () => {
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
    const selected = within(table).getByText("Gạo thơm").closest("tr");
    expect(selected).toHaveAttribute("aria-selected", "true");
    expect(within(table).queryByText("Đang chọn")).not.toBeInTheDocument();
    expect(
      selected?.querySelector("[data-selection-indicator]"),
    ).toHaveAttribute("aria-hidden", "true");
    expect(
      within(table).getByRole("button", { name: "Xem phân bổ Gạo thơm" }),
    ).toHaveTextContent("Xem phân bổ");
    const allocate = within(table).getByRole("button", {
      name: "Phân bổ NCC Thịt heo nạc",
    });
    expect(allocate).toHaveTextContent("Phân bổ NCC");
    for (const quantity of ["120", "48,5", "25,75"])
      expect(within(table).getByText(quantity)).toBeVisible();
    expect(table.textContent).not.toMatch(/,\d{6}/);
    const detail = screen.getByRole("region", { name: "Phân bổ Gạo thơm" });
    expect(
      within(detail).getByRole("button", { name: "Lưu phân bổ" }),
    ).toBeEnabled();
    expect(within(detail).getByRole("button", { name: "Đóng" })).toBeEnabled();
    fireEvent.click(allocate);
    expect(
      within(table).getByText("Thịt heo nạc").closest("tr"),
    ).toHaveAttribute("aria-selected", "true");
    expect(selected).toHaveAttribute("aria-selected", "false");
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
    vi.useFakeTimers();
    render(
      <AtlasVNextProvider>
        <AtlasDesignLanguageReference scenario="unknown" />
      </AtlasVNextProvider>,
    );
    expect(screen.getByText("Chưa xác định kết quả lưu")).toBeVisible();
    expect(screen.getByRole("button", { name: "Lưu phân bổ" })).toBeDisabled();
    const recover = screen.getByRole("button", { name: "Tải lại để xác nhận" });
    expect(recover).toBeVisible();
    const refresh = screen.getByRole("button", { name: "Làm mới dữ liệu" });
    expect(refresh).not.toBe(recover);
    fireEvent.click(refresh);
    act(() => vi.advanceTimersByTime(1200));
    expect(screen.getByRole("button", { name: "Lưu phân bổ" })).toBeDisabled();
    fireEvent.click(recover);
    expect(screen.getByRole("button", { name: "Lưu phân bổ" })).toBeDisabled();
    act(() => vi.advanceTimersByTime(1200));
    expect(
      screen.queryByText("Chưa xác định kết quả lưu"),
    ).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Lưu phân bổ" })).toBeEnabled();
    expect(
      screen.getByText(
        "Đã tải lại trạng thái minh họa để xác nhận. Không có dữ liệu nghiệp vụ được lưu.",
      ),
    ).toBeVisible();
  });
});
