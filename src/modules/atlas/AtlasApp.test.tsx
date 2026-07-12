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
    expect(screen.getByRole("button", { name: "Món ăn & Công thức" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Kiểm soát thay đổi công thức" })).toBeInTheDocument();
    const stages = screen.getByLabelText("Ba giai đoạn vận hành hằng ngày");
    expect(stages).not.toHaveTextContent("Món ăn & Công thức");
    expect(stages).not.toHaveTextContent("Kiểm soát thay đổi công thức");
  });

  it("shows the receiving shortage and keeps supplier coordination optional", () => {
    render(<AtlasApp />);
    fireEvent.click(screen.getByRole("button", { name: "Lập kế hoạch mua hàng" }));
    expect(screen.getByText(/không yêu cầu xác nhận NCC/i)).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Nhập kho" }));
    expect(screen.getAllByText("Thiếu 10 kg")).toHaveLength(2);
    expect(screen.getByText(/đặt 250 kg · nhận 240 kg · thiếu 10 kg/i)).toBeInTheDocument();
  });
});
