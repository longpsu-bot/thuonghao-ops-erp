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
    expect(screen.getByText("OPS-2026-0714-MA-GAO-001")).toBeInTheDocument();
    expect(screen.getByText("Chủ xử lý")).toBeInTheDocument();
    expect(screen.getByText("Tuổi ngoại lệ")).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "Kiểm soát thay đổi công thức" }),
    ).toBeInTheDocument();
    expect(screen.getByText("Dữ liệu & quản trị")).toBeInTheDocument();
  });
  it("shows actual-need confirmation with the merged recipient and destination", () => {
    render(<AtlasApp />);
    fireEvent.click(screen.getByRole("button", { name: "Lập nhu cầu" }));
    expect(screen.getByText(/Nhu cầu tính toán/)).toBeInTheDocument();
    expect(screen.getByText("Nguồn")).toBeInTheDocument();
    expect(screen.getByText("Lý do / ghi chú")).toBeInTheDocument();
    expect(
      screen.getByText("Hàng đặt riêng · 2 cần xác nhận"),
    ).toBeInTheDocument();
    expect(screen.getByText("Người nhập thực tế")).toBeInTheDocument();
    expect(screen.getByText("Người xác nhận")).toBeInTheDocument();
    expect(screen.getByText("Bàn giao Thu mua")).toBeInTheDocument();
    expect(
      screen
        .getAllByRole("columnheader")
        .slice(-2)
        .map((header) => header.textContent),
    ).toEqual(["Người nhập thực tế", "Người xác nhận"]);
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
    expect(screen.getAllByText("OPS-2026-0714-MA-GAO-001").length).toBe(2);
    expect(screen.getByText("Ghi chú giao hàng")).toBeInTheDocument();
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
    expect(screen.getByText("PO-0714-008")).toBeInTheDocument();
    expect(screen.getByText("PXK-0714-MA")).toBeInTheDocument();
    expect(screen.getByText("Delta")).toBeInTheDocument();
    expect(screen.getAllByText("Lần phát hành 1").length).toBe(2);
  });
  it("shows supplier-linked receiving, downstream impact, and supporting recipe governance", () => {
    render(<AtlasApp />);
    fireEvent.click(
      screen.getByRole("button", { name: "Nhập kho & xử lý chênh lệch" }),
    );
    expect(screen.getByText("Thành Công Foods")).toBeInTheDocument();
    expect(screen.getByText("Dự kiến")).toBeInTheDocument();
    expect(screen.getByText(/Thiếu cho bếp Minh An/)).toBeInTheDocument();
    expect(screen.getByText("Trạng thái bằng chứng")).toBeInTheDocument();
    expect(screen.getByText("Chủ xử lý")).toBeInTheDocument();
    expect(screen.getByText("240 kg")).toBeInTheDocument();
    expect(
      screen
        .getAllByRole("columnheader")
        .slice(-4)
        .map((header) => header.textContent),
    ).toEqual([
      "Ảnh hưởng phía sau",
      "Bước tiếp",
      "Trạng thái bằng chứng",
      "Chủ xử lý",
    ]);
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
  it("keeps the trace drawer static and prototype-only", () => {
    render(<AtlasApp />);
    fireEvent.click(screen.getByRole("button", { name: "Mở chuỗi truy xuất" }));
    expect(
      screen.getByRole("complementary", { name: "Chuỗi truy xuất" }),
    ).toBeInTheDocument();
    expect(screen.getAllByText("Nguồn").length).toBeGreaterThan(0);
    expect(
      screen.getByText(/không tạo sự kiện, chứng từ hay/),
    ).toBeInTheDocument();
  });
});
