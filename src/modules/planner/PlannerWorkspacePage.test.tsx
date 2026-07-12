import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import "@testing-library/jest-dom/vitest";
import { afterEach, describe, expect, it } from "vitest";
import { PlannerWorkspacePage } from "./PlannerWorkspacePage";

afterEach(cleanup);

describe("PlannerWorkspacePage", () => {
  it("shows Vietnamese dates and grouped date headers", () => {
    render(<PlannerWorkspacePage />);
    expect(screen.getByLabelText("Từ ngày")).toHaveValue("13/07/2026");
    expect(screen.getByLabelText("Đến ngày")).toHaveValue("15/07/2026");
    expect(screen.getByText("13/07/2026 — T2")).toBeInTheDocument();
    expect(screen.getByText("14/07/2026 — T3")).toBeInTheDocument();
  });

  it("changes requirement grouping with the selected view mode", () => {
    render(<PlannerWorkspacePage />);
    fireEvent.click(
      screen.getByRole("button", { name: "Theo trường / khách" }),
    );
    expect(
      screen.getAllByText("Trường Tiểu học Nguyễn Du").length,
    ).toBeGreaterThan(1);
    expect(screen.queryByText("13/07/2026 — T2")).not.toBeInTheDocument();
  });

  it("uses Vietnamese status labels rather than raw status enums", () => {
    render(<PlannerWorkspacePage />);
    expect(screen.getAllByText("Cần kiểm tra").length).toBeGreaterThan(0);
    expect(screen.getAllByText("Bị chặn").length).toBeGreaterThan(0);
    expect(screen.queryByText("WARNING")).not.toBeInTheDocument();
    expect(screen.queryByText("BLOCKED")).not.toBeInTheDocument();
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

  it("filters to planner-attention rows only", () => {
    render(<PlannerWorkspacePage />);
    fireEvent.click(screen.getByLabelText("Chỉ xem dòng cần xử lý"));
    expect(screen.queryByText("Bí đỏ")).not.toBeInTheDocument();
    expect(screen.getByText("Cá basa phi lê")).toBeInTheDocument();
  });
});
