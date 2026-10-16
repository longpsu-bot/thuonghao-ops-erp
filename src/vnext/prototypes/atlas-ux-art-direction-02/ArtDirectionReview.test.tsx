import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  within,
} from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import { ArtDirectionReview } from "./ArtDirectionReview";

afterEach(() => {
  cleanup();
  history.replaceState(null, "", "/");
});
describe("isolated art-direction prototypes", () => {
  it.each(["ledger", "journal", "rail"])(
    "%s exposes thirteen tabs and the selected complete synthetic order",
    (view) => {
      history.replaceState(null, "", `?view=${view}`);
      const { container } = render(<ArtDirectionReview />);
      expect(container.querySelector(`.variant-${view}`)).not.toBeNull();
      expect(
        container.querySelector(
          view === "ledger"
            ? ".supplier-ledger"
            : view === "journal"
              ? ".order-journal"
              : ".supplier-rail",
        ),
      ).not.toBeNull();
      expect(screen.getAllByRole("tab")).toHaveLength(13);
      const detail = screen.getByRole("region", {
        name: "Chi tiết Thực phẩm An Phú",
      });
      expect(
        within(detail).getByRole("heading", { name: "Thực phẩm An Phú" }),
      ).toBeVisible();
      expect(
        within(detail).getAllByText("Trường Tiểu học Nguyễn Du"),
      ).toHaveLength(2);
      expect(within(detail).getByText("42,5")).toBeVisible();
      expect(
        screen.getByText("Dữ liệu giả lập · Không kết nối hệ thống"),
      ).toBeVisible();
      fireEvent.change(screen.getByRole("textbox", { name: "Tìm đơn mua" }), {
        target: { value: "Đà Lạt" },
      });
      expect(
        screen.getByRole("region", { name: "Chi tiết Rau sạch Đà Lạt" }),
      ).toBeVisible();
    },
  );
  it("does not turn a business confirmation into a fake issued status", () => {
    render(<ArtDirectionReview />);
    fireEvent.click(screen.getByRole("button", { name: "Phát hành cho NCC" }));
    fireEvent.click(screen.getByRole("button", { name: "Kết thúc xem thử" }));
    const detail = screen.getByRole("region", {
      name: "Chi tiết Thực phẩm An Phú",
    });
    expect(within(detail).getByText("Bản nháp")).toBeVisible();
    expect(within(detail).getByText("Bản nháp · Chưa cấp số")).toBeVisible();
    expect(screen.getByRole("status")).toHaveTextContent(
      "không phát hành hoặc gửi dữ liệu",
    );
  });
  it("keeps genuinely unavailable draft School evidence explicit and release blocked", () => {
    render(<ArtDirectionReview />);
    fireEvent.change(screen.getByRole("textbox", { name: "Tìm đơn mua" }), {
      target: { value: "Biển Xanh" },
    });
    const detail = screen.getByRole("region", {
      name: "Chi tiết Hải sản Biển Xanh",
    });
    expect(
      within(detail).getByText(/Không suy ra trường từ địa điểm/),
    ).toBeVisible();
    expect(
      within(detail).queryByText("Trường Tiểu học Lê Lợi"),
    ).not.toBeInTheDocument();
    expect(
      within(detail).getByRole("button", { name: "Phát hành cho NCC" }),
    ).toBeDisabled();
  });
  it("distinguishes filtered absence from a day without orders", () => {
    render(<ArtDirectionReview />);
    fireEvent.change(screen.getByRole("textbox", { name: "Tìm đơn mua" }), {
      target: { value: "không khớp" },
    });
    expect(
      screen.getByRole("heading", { name: "Không có đơn khớp bộ lọc" }),
    ).toBeVisible();
    fireEvent.change(
      screen.getByRole("combobox", { name: "Trạng thái bản mẫu" }),
      { target: { value: "empty" } },
    );
    fireEvent.click(screen.getByRole("button", { name: "Xóa bộ lọc" }));
    expect(
      screen.getByRole("heading", { name: "Chưa có đơn mua trong ngày này" }),
    ).toBeVisible();
  });
  it("dirty Cancel retains the tab; discard closes only that owner", () => {
    render(<ArtDirectionReview />);
    fireEvent.click(
      screen.getByRole("button", { name: "Đóng Hàng đặt riêng" }),
    );
    fireEvent.click(screen.getByRole("button", { name: "Hủy" }));
    expect(screen.getAllByRole("tab")).toHaveLength(13);
    fireEvent.click(
      screen.getByRole("button", { name: "Đóng Hàng đặt riêng" }),
    );
    fireEvent.click(screen.getByRole("button", { name: "Bỏ thay đổi" }));
    expect(screen.getAllByRole("tab")).toHaveLength(12);
    expect(screen.getByRole("tab", { name: "Đơn mua" })).toHaveAttribute(
      "aria-selected",
      "true",
    );
  });
  it("busy and blocked states prevent issue without hiding the selected document", () => {
    render(<ArtDirectionReview />);
    fireEvent.change(
      screen.getByRole("combobox", { name: "Trạng thái bản mẫu" }),
      { target: { value: "busy" } },
    );
    expect(screen.getByRole("button", { name: "Đang xử lý…" })).toBeDisabled();
    expect(screen.getByRole("tab", { name: "Đơn mua" })).toBeDisabled();
    fireEvent.change(
      screen.getByRole("combobox", { name: "Trạng thái bản mẫu" }),
      { target: { value: "blocked" } },
    );
    expect(
      screen.getByRole("button", { name: "Phát hành cho NCC" }),
    ).toBeDisabled();
    expect(
      screen.getByRole("region", { name: "Chi tiết Thực phẩm An Phú" }),
    ).toBeVisible();
  });
});
