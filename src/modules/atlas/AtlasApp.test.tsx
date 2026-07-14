import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import "@testing-library/jest-dom/vitest";
import { afterEach, describe, expect, it } from "vitest";
import { AtlasApp } from "./AtlasApp";

afterEach(cleanup);
describe("Atlas operations workbench", () => {
  it("shows the corrected daily workbench navigation and upstream control board", () => {
    render(<AtlasApp />);
    [
      "Bảng điều hành",
      "Nguồn kế hoạch",
      "Tổng hợp & xác nhận nhu cầu",
      "Lập kế hoạch mua hàng",
      "Phát hành chứng từ",
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
      screen.getByRole("button", { name: "Dishes & Recipes" }),
    ).toBeInTheDocument();
    expect(screen.getByText("Dữ liệu & quản trị")).toBeInTheDocument();
  });
  it("shows source planning tabs and source status", () => {
    render(<AtlasApp />);
    fireEvent.click(screen.getByRole("button", { name: "Nguồn kế hoạch" }));
    [
      "Thực đơn tuần",
      "Sĩ số / suất ăn",
      "Hàng đặt riêng",
      "Pantry / nhu cầu nội bộ",
      "Tóm tắt nguồn",
    ].forEach((name) =>
      expect(screen.getByRole("tab", { name })).toBeInTheDocument(),
    );
    expect(screen.getAllByText(/Google Sheet tuần/).length).toBeGreaterThan(0);
    fireEvent.click(screen.getByRole("button", { name: "Xem chi tiết" }));
    expect(screen.getByText("Canh bí đỏ")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("tab", { name: "Hàng đặt riêng" }));
    expect(screen.getByText("Bổ sung suất đặt riêng")).toBeInTheDocument();
    fireEvent.click(
      screen.getByRole("tab", { name: "Pantry / nhu cầu nội bộ" }),
    );
    expect(
      screen.getByText(/không phải hạch toán tồn kho/),
    ).toBeInTheDocument();
  });

  it("keeps Attendance actions decision-first and details expandable", () => {
    render(<AtlasApp initialPage="planning-sources" />);
    fireEvent.click(screen.getByRole("tab", { name: "Sĩ số / suất ăn" }));
    expect(screen.getByLabelText("Tóm tắt số suất")).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "Duyệt số suất" }),
    ).toBeDisabled();
    fireEvent.click(screen.getByRole("button", { name: "Kiểm tra số suất" }));
    fireEvent.click(screen.getByRole("button", { name: "Duyệt số suất" }));
    fireEvent.click(
      screen.getByRole("button", { name: "Bàn giao tạo nhu cầu" }),
    );
    expect(
      screen.getByText("Đã bàn giao số suất cho bước tạo nhu cầu."),
    ).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Xem chi tiết" }));
    expect(screen.getByText("Suất học sinh")).toBeInTheDocument();
  });

  it("keeps Weekly Menu actions decision-first and detail expandable", () => {
    render(<AtlasApp initialPage="planning-sources" />);
    expect(screen.getByLabelText("Tóm tắt thực đơn tuần")).toBeInTheDocument();
    expect(screen.getByText("Lỗi chặn")).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "Duyệt thực đơn" }),
    ).toBeDisabled();
    fireEvent.click(screen.getByRole("button", { name: "Kiểm tra thực đơn" }));
    fireEvent.click(screen.getByRole("button", { name: "Duyệt thực đơn" }));
    fireEvent.click(
      screen.getByRole("button", { name: "Yêu cầu tạo nhu cầu" }),
    );
    expect(
      screen.getByText("Đã yêu cầu tạo nhu cầu từ phiên bản đã duyệt."),
    ).toBeInTheDocument();
  });
  it("shows actual-need confirmation with the merged recipient and destination", () => {
    render(<AtlasApp />);
    fireEvent.click(
      screen.getByRole("button", { name: "Tổng hợp & xác nhận nhu cầu" }),
    );
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
    expect(
      screen.getAllByText("Bếp trung tâm · Tuyến Bắc").length,
    ).toBeGreaterThan(0);
    expect(
      screen.getByRole("button", { name: "Xác nhận nhu cầu" }),
    ).toBeInTheDocument();
    expect(screen.getByText("Vì sao có nhu cầu này?")).toBeInTheDocument();
    expect(
      screen.getByText("Hàng đặt riêng · OPS-2026-0714-MA-GAO-001"),
    ).toBeInTheDocument();
    expect(
      screen.getByText("Pantry / nhu cầu nội bộ · OPS-2026-0714-PN-DAU-001"),
    ).toBeInTheDocument();
    expect(screen.getByText(/Nhu cầu cuối: 250 kg/)).toBeInTheDocument();
    expect(screen.getByText(/Nhu cầu cuối: 20 lít/)).toBeInTheDocument();
  });
  it("exposes the command-gated Procurement workbench", () => {
    render(<AtlasApp />);
    fireEvent.click(
      screen.getByRole("button", { name: "Lập kế hoạch mua hàng" }),
    );
    expect(
      screen.getByLabelText("Procurement decision summary"),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "Validate allocation" }),
    ).toBeDisabled();
    expect(
      screen.getByRole("button", { name: "Release PO to supplier" }),
    ).toBeDisabled();
  });
  it("shows release tabs and reconciliation", () => {
    render(<AtlasApp />);
    fireEvent.click(screen.getByRole("button", { name: "Phát hành chứng từ" }));
    expect(
      screen.getByRole("tab", { name: "Đơn đặt NCC / PO" }),
    ).toBeInTheDocument();
    expect(screen.getByText("Chế độ xuất")).toBeInTheDocument();
    expect(screen.getByText("Theo dòng đang lọc")).toBeInTheDocument();
    expect(screen.getByText("PO-0714-008")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("tab", { name: "Phiếu nhận hàng" }));
    expect(
      screen.getByText(/không phải kết quả nhận thực tế/),
    ).toBeInTheDocument();
    fireEvent.click(screen.getByRole("tab", { name: "Đối chiếu chứng từ" }));
    expect(screen.getByText("SL dự kiến nhận")).toBeInTheDocument();
    expect(screen.getByText("Lệch số lượng")).toBeInTheDocument();
  });
  it("shows supplier-linked receiving, downstream impact, and the consolidated recipe workbench", () => {
    render(<AtlasApp />);
    fireEvent.click(
      screen.getByRole("button", { name: "Nhập kho & xử lý chênh lệch" }),
    );
    expect(
      screen.getByText("Warehouse receiving decision"),
    ).toBeInTheDocument();
    expect(screen.getByText("Supplier-confirmed PO:")).toBeInTheDocument();
    expect(screen.getByText("Expected")).toBeInTheDocument();
    expect(screen.getByText("Source trace")).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "Start receiving session" }),
    ).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Dishes & Recipes" }));
    expect(
      screen.getByLabelText("Dishes and recipes administration summary"),
    ).toBeInTheDocument();
    expect(screen.getByText("BOM lines")).toBeInTheDocument();
    fireEvent.click(
      screen.getByRole("button", { name: "Ranh giới prototype" }),
    );
    expect(
      screen.getByText(/không thay đổi dữ liệu thực tế/),
    ).toBeInTheDocument();
  });
  it("exposes the command-gated Ingredients & Suppliers Admin workbench", () => {
    render(<AtlasApp initialPage="ingredients-units" />);
    expect(
      screen.getByLabelText("Ingredients and suppliers administration summary"),
    ).toBeInTheDocument();
    expect(
      screen.getByText(/Which suppliers are active and eligible/),
    ).toBeInTheDocument();
    expect(
      screen.queryByRole("columnheader", { name: "Ingredient" }),
    ).not.toBeInTheDocument();
    fireEvent.click(
      screen.getByRole("button", { name: "Review master-data details" }),
    );
    expect(
      screen.getByRole("columnheader", { name: "Ingredient" }),
    ).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: /cung/ }));
    expect(
      screen.getByLabelText("Ingredients and suppliers administration summary"),
    ).toBeInTheDocument();
  });
  it("keeps the trace drawer static and prototype-only", () => {
    render(<AtlasApp />);
    fireEvent.click(screen.getByRole("button", { name: "Mở chuỗi truy xuất" }));
    expect(
      screen.getByRole("complementary", { name: "Chuỗi truy xuất" }),
    ).toBeInTheDocument();
    expect(screen.getAllByText("Nguồn kế hoạch").length).toBeGreaterThan(0);
    [
      "Công thức / định lượng",
      "Nhu cầu tính toán",
      "Nhu cầu thực tế xác nhận",
      "Phân bổ NCC",
      "PO",
      "Phiếu xuất kho",
      "Phiếu nhận hàng",
      "Nhập kho",
      "Ngoại lệ",
    ].forEach((stage) =>
      expect(screen.getAllByText(stage).length).toBeGreaterThan(0),
    );
    expect(
      screen.getByText(/không tạo sự kiện, chứng từ hay/),
    ).toBeInTheDocument();
  });
});
