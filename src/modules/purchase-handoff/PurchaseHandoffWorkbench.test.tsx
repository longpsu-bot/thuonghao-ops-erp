import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import "@testing-library/jest-dom/vitest";
import { afterEach, describe, expect, it } from "vitest";
import { PurchaseHandoffWorkbench } from "./PurchaseHandoffWorkbench";

afterEach(cleanup);

describe("Purchase Handoff workbench", () => {
  it("releases to Procurement only after validation", () => {
    render(<PurchaseHandoffWorkbench />);
    expect(
      screen.getByLabelText("Tóm tắt bàn giao nhu cầu mua"),
    ).toBeInTheDocument();
    const release = screen.getByRole("button", {
      name: "Chuyển Procurement",
    });
    expect(release).toBeDisabled();
    fireEvent.click(screen.getByRole("button", { name: "Kiểm tra bàn giao" }));
    expect(release).toBeEnabled();
    fireEvent.click(release);
    expect(
      screen.getByText(/chưa phân công nhà cung cấp hay tạo PO/),
    ).toBeInTheDocument();
  });

  it("keeps Procurement-facing trace details expandable", () => {
    render(<PurchaseHandoffWorkbench />);
    fireEvent.click(screen.getByRole("button", { name: "Xem chi tiết" }));
    expect(
      screen.getByText("confirmed-need-2026-29-v1-line-1"),
    ).toBeInTheDocument();
    expect(
      screen.getByText(/Không chọn nhà cung cấp, không chia nguồn cung/),
    ).toBeInTheDocument();
  });
});
