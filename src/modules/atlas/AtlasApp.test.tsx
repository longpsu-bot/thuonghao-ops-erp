import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import "@testing-library/jest-dom/vitest";
import { afterEach, describe, expect, it } from "vitest";
import { AtlasApp } from "./AtlasApp";

afterEach(cleanup);

describe("AtlasApp", () => {
  it("shows exactly the three approved active daily workflow stages", () => {
    render(<AtlasApp />);
    const stages = screen.getByLabelText("Ba giai đoạn vận hành hằng ngày");
    expect(stages).toHaveTextContent("Lập nhu cầu");
    expect(stages).toHaveTextContent("Lập kế hoạch mua hàng");
    expect(stages).toHaveTextContent("Nhập kho");
    expect(stages.querySelectorAll("button")).toHaveLength(3);
    expect(screen.queryByText("Dispatch Planning")).not.toBeInTheDocument();
    expect(screen.queryByText("QA")).not.toBeInTheDocument();
  });

  it("keeps recipe pages in supporting data, outside the daily workflow", () => {
    render(<AtlasApp />);
    expect(
      screen.getByRole("button", { name: "Món ăn & Công thức" }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "Kiểm soát thay đổi công thức" }),
    ).toBeInTheDocument();
    const stages = screen.getByLabelText("Ba giai đoạn vận hành hằng ngày");
    expect(stages).not.toHaveTextContent("Món ăn & Công thức");
    expect(stages).not.toHaveTextContent("Kiểm soát thay đổi công thức");
  });

  it("shows split supplier assignment and keeps supplier coordination optional", () => {
    render(<AtlasApp />);
    fireEvent.click(
      screen.getByRole("button", { name: "Lập kế hoạch mua hàng" }),
    );
    expect(screen.getAllByText("Gạo Jasmine")).toHaveLength(2);
    expect(screen.getByText("150 kg")).toBeInTheDocument();
    expect(screen.getByText("100 kg")).toBeInTheDocument();
    expect(
      screen.getByText(/ghi chú phối hợp là tùy chọn/i),
    ).toBeInTheDocument();
  });

  it("shows the supplier-linked receiving shortage and downstream impact", () => {
    render(<AtlasApp />);
    fireEvent.click(screen.getByRole("button", { name: "Nhập kho" }));
    expect(screen.getAllByText("Thiếu 10 kg")).toHaveLength(2);
    expect(screen.getByText("Thành Công Foods")).toBeInTheDocument();
    expect(screen.getAllByText(/Bếp Minh An còn thiếu 10 kg/i)).toHaveLength(2);
  });
});
