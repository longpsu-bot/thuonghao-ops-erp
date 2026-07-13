import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import "@testing-library/jest-dom/vitest";
import { afterEach, describe, expect, it } from "vitest";
import { AtlasApp } from "./AtlasApp";

afterEach(cleanup);
describe("Atlas operations workbench", () => {
  it("shows the five daily workbench pages and exception-first control board", () => {
    render(<AtlasApp />);
    [
      "Bảng điều hành",
      "Lập nhu cầu",
      "Lập kế hoạch mua hàng",
      "Phát hành đơn / phiếu",
      "Nhập kho & xử lý chênh lệch",
    ].forEach((name) =>
      expect(screen.getByRole("button", { name })).toBeInTheDocument(),
    );
    expect(screen.getByText("Hàng đợi cần chú ý")).toBeInTheDocument();
    expect(screen.getByText("NCC giao thiếu")).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "Kiểm soát thay đổi công thức" }),
    ).toBeInTheDocument();
    expect(screen.getByText("Dữ liệu & quản trị")).toBeInTheDocument();
  });
  it("shows actual-need confirmation with the merged recipient and destination", () => {
    render(<AtlasApp />);
    fireEvent.click(screen.getByRole("button", { name: "Lập nhu cầu" }));
    expect(screen.getByText(/Nhu cầu tính toán/)).toBeInTheDocument();
    expect(screen.getAllByText("Trường Nguyễn Du").length).toBeGreaterThan(0);
    expect(screen.getByText("Bếp trung tâm · Tuyến Bắc")).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "Xác nhận nhu cầu" }),
    ).toBeInTheDocument();
  });
  it("represents supplier split allocation", () => {
    render(<AtlasApp />);
    fireEvent.click(
      screen.getByRole("button", { name: "Lập kế hoạch mua hàng" }),
    );
    expect(screen.getByText("Thành Công Foods")).toBeInTheDocument();
    expect(screen.getByText("Nam Việt Supply")).toBeInTheDocument();
    expect(screen.getByText("Chia NCC")).toBeInTheDocument();
    expect(screen.getByText("Phân công một phần")).toBeInTheDocument();
    expect(screen.getByText("Chưa phân công")).toBeInTheDocument();
  });
  it("shows release panels and PO-versus-dispatch reconciliation", () => {
    render(<AtlasApp />);
    fireEvent.click(
      screen.getByRole("button", { name: "Phát hành đơn / phiếu" }),
    );
    expect(
      screen.getByText("Đơn đặt nhà cung cấp / PO Release"),
    ).toBeInTheDocument();
    expect(
      screen.getByText("Phiếu xuất kho / Dispatch Order Release"),
    ).toBeInTheDocument();
    expect(
      screen.getByText("Đối chiếu PO và Phiếu xuất kho"),
    ).toBeInTheDocument();
  });
  it("shows supplier-linked receiving, downstream impact, and supporting recipe governance", () => {
    render(<AtlasApp />);
    fireEvent.click(
      screen.getByRole("button", { name: "Nhập kho & xử lý chênh lệch" }),
    );
    expect(screen.getByText("Thành Công Foods")).toBeInTheDocument();
    expect(screen.getByText(/Thiếu cho bếp Minh An/)).toBeInTheDocument();
    fireEvent.click(
      screen.getByRole("button", { name: "Kiểm soát thay đổi công thức" }),
    );
    expect(
      screen.getByText(/không phải một bước vận hành hằng ngày/),
    ).toBeInTheDocument();
    fireEvent.click(
      screen.getByRole("button", { name: "Ranh giới prototype" }),
    );
    expect(
      screen.getByText(/không thay đổi dữ liệu thực tế/),
    ).toBeInTheDocument();
  });
});
