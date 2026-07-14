import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import "@testing-library/jest-dom/vitest";
import { afterEach, describe, expect, it } from "vitest";
import { ConfirmedNeedWorkbench } from "./ConfirmedNeedWorkbench";

afterEach(cleanup);

describe("Confirmed Need workbench", () => {
  it("keeps approval and Purchase Handoff release in command order", () => {
    render(<ConfirmedNeedWorkbench />);
    expect(
      screen.getByLabelText("Tóm tắt xác nhận nhu cầu"),
    ).toBeInTheDocument();
    const approve = screen.getByRole("button", { name: "Duyệt nhu cầu" });
    const release = screen.getByRole("button", {
      name: "Chuyển Purchase Handoff",
    });
    expect(approve).toBeDisabled();
    expect(release).toBeDisabled();

    fireEvent.click(screen.getByRole("button", { name: "Kiểm tra nhu cầu" }));
    expect(approve).toBeEnabled();
    fireEvent.click(approve);
    expect(release).toBeEnabled();
    fireEvent.click(release);
    expect(screen.getByText(/không tạo đơn mua hàng/)).toBeInTheDocument();
  });

  it("shows line trace and adjustment history only on demand", () => {
    render(<ConfirmedNeedWorkbench />);
    fireEvent.click(screen.getByRole("button", { name: "Xem chi tiết" }));
    expect(screen.getByText("need-run-2026-29-v1-line-1")).toBeInTheDocument();
    fireEvent.click(
      screen.getByRole("button", { name: "Điều chỉnh dòng mẫu" }),
    );
    expect(screen.getByText(/72 → 70 kg/)).toBeInTheDocument();
    expect(screen.getByText("1")).toBeInTheDocument();
  });
});
