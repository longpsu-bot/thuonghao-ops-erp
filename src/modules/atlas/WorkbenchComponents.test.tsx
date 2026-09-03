import "@testing-library/jest-dom/vitest";
import { MantineProvider } from "@mantine/core";
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { atlasTheme } from "../../theme";
import {
  OperationalState,
  RefreshButton,
  WorkbenchHeader,
} from "./WorkbenchComponents";

Object.defineProperty(window, "matchMedia", {
  writable: true,
  value: vi.fn().mockImplementation((query: string) => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: vi.fn(),
    removeListener: vi.fn(),
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
    dispatchEvent: vi.fn(),
  })),
});

afterEach(cleanup);

function renderWithTheme(children: React.ReactNode) {
  return render(
    <MantineProvider theme={atlasTheme}>{children}</MantineProvider>,
  );
}

describe("Mantine-backed Atlas presentation", () => {
  it("labels icon-only routine refresh and prevents activation while disabled", () => {
    const refresh = vi.fn();
    const { rerender } = render(<RefreshButton onClick={refresh} />);
    const button = screen.getByRole("button", { name: "Làm mới dữ liệu" });
    expect(button).toHaveAttribute("title", "Làm mới dữ liệu");
    expect(button).toHaveAttribute("type", "button");
    expect(button).toHaveTextContent(/^$/);
    expect(button.querySelector("svg")).toHaveAttribute("aria-hidden", "true");
    fireEvent.click(button);
    expect(refresh).toHaveBeenCalledOnce();
    rerender(<RefreshButton onClick={refresh} disabled />);
    expect(button).toBeDisabled();
    fireEvent.click(button);
    expect(refresh).toHaveBeenCalledOnce();
  });

  it("renders the shared Atlas theme with page and nested headings", () => {
    renderWithTheme(
      <>
        <WorkbenchHeader
          eyebrow="Lập nhu cầu"
          title="Nguồn kế hoạch"
          context="Bối cảnh vận hành hiện tại"
        />
        <WorkbenchHeader
          title="Điều hành nguồn kế hoạch theo tuần"
          headingLevel={2}
        />
      </>,
    );

    expect(document.documentElement.dataset.mantineColorScheme).toBe("light");
    expect(
      screen.getByRole("heading", { level: 1, name: "Nguồn kế hoạch" }),
    ).toBeVisible();
    expect(
      screen.getByRole("heading", {
        level: 2,
        name: "Điều hành nguồn kế hoạch theo tuần",
      }),
    ).toBeVisible();
  });

  it("announces access denial and retains long Vietnamese guidance", () => {
    const guidance =
      "Bạn chưa có quyền xem dữ liệu của tuần phục vụ này. Hãy liên hệ người quản trị để kiểm tra phạm vi trường học được phân công trước khi tiếp tục.";

    renderWithTheme(
      <OperationalState variant="access-denied" title="Không có quyền truy cập">
        {guidance}
      </OperationalState>,
    );

    const alert = screen.getByRole("alert");
    expect(alert).toHaveAttribute("aria-live", "assertive");
    expect(alert).toHaveTextContent(guidance);
  });

  it("presents read-only information without warning semantics", () => {
    renderWithTheme(
      <OperationalState
        variant="read-only"
        title="Bản xem thử không thay đổi dữ liệu vận hành"
      />,
    );

    const status = screen.getByRole("status");
    expect(status).toHaveClass("read-only");
    expect(status).toHaveAttribute("aria-live", "polite");
    expect(status).toHaveTextContent("Chỉ xem");
    expect(status).not.toHaveTextContent("Cần chú ý");
  });

  it("requires authoritative refresh after an unknown outcome without retry", () => {
    const refresh = vi.fn();
    renderWithTheme(
      <OperationalState
        variant="unknown-outcome"
        title="Chưa xác định kết quả phê duyệt"
        onAuthoritativeRefresh={refresh}
      />,
    );

    const status = screen.getByRole("status");
    expect(status).toHaveAttribute("aria-live", "polite");
    expect(status).toHaveTextContent("thành công hay thất bại");
    expect(status).toHaveTextContent("Không tự động gửi lại thao tác");
    expect(
      screen.queryByRole("button", { name: /thử lại|gửi lại/i }),
    ).not.toBeInTheDocument();

    const recovery = screen.getByRole("button", { name: "Tải lại dữ liệu" });
    expect(recovery).toHaveTextContent("Tải lại dữ liệu");
    fireEvent.click(recovery);
    expect(refresh).toHaveBeenCalledOnce();
  });
});
