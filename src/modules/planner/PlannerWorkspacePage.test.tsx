import { cleanup, render, screen, fireEvent } from "@testing-library/react";
import "@testing-library/jest-dom/vitest";
import { afterEach, describe, expect, it } from "vitest";
import { PlannerWorkspacePage } from "./PlannerWorkspacePage";

afterEach(cleanup);

describe("PlannerWorkspacePage", () => {
  it("filters fixtures and opens an inspectable trace", () => {
    render(<PlannerWorkspacePage />);
    expect(screen.getByText("Gạo Jasmine")).toBeInTheDocument();
    fireEvent.click(screen.getByText("Gạo Jasmine"));
    expect(
      screen.getByRole("complementary", { name: "Chi tiết yêu cầu" }),
    ).toHaveTextContent("DỮ LIỆU MẪU");
    expect(
      screen.getByText("Bỏ qua phân rã công thức theo BR-002"),
    ).toBeInTheDocument();
  });
  it("keeps blocking lines from being marked ready", () => {
    render(<PlannerWorkspacePage />);
    fireEvent.click(screen.getByText("Nước màu dừa"));
    expect(
      screen.getByRole("button", { name: "Tạo nháp sẵn sàng" }),
    ).toBeDisabled();
  });
  it("keeps fixture readiness separate from a local readiness draft", () => {
    render(<PlannerWorkspacePage />);
    fireEvent.click(screen.getByText("Định mức theo mẻ (suy luận mock)"));
    fireEvent.click(screen.getByRole("button", { name: "Tạo nháp sẵn sàng" }));
    expect(screen.getByText("Nháp: sẵn sàng")).toBeInTheDocument();
    expect(screen.getByText("Sẵn sàng mua hàng (fixture)")).toBeInTheDocument();
  });
});
