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
      screen.getByRole("button", { name: "Đánh dấu sẵn sàng" }),
    ).toBeDisabled();
  });
});
