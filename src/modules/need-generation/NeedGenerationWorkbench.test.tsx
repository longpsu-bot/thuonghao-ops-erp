import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import "@testing-library/jest-dom/vitest";
import { afterEach, describe, expect, it } from "vitest";
import { NeedGenerationWorkbench } from "./NeedGenerationWorkbench";

afterEach(cleanup);

describe("Need Generation workbench", () => {
  it("shows the decision summary and releases only after validation", () => {
    render(<NeedGenerationWorkbench />);
    expect(screen.getByLabelText("Tóm tắt tạo nhu cầu")).toBeInTheDocument();
    expect(screen.getByText("Đầu vào sẵn sàng")).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "Chuyển sang xác nhận" }),
    ).toBeDisabled();

    fireEvent.click(screen.getByRole("button", { name: "Kiểm tra kết quả" }));
    const release = screen.getByRole("button", {
      name: "Chuyển sang xác nhận",
    });
    expect(release).toBeEnabled();
    fireEvent.click(release);
    expect(screen.getByText(/chưa phải nhu cầu mua hàng/)).toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "Xem giải thích" }));
    expect(screen.getByText("prototype-exact-portion-v1")).toBeInTheDocument();
    expect(
      screen.getByText(/Procurement không được tiêu thụ trực tiếp/),
    ).toBeInTheDocument();
  });
});
