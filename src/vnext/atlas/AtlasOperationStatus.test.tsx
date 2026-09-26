import "@testing-library/jest-dom/vitest";
import { act, cleanup, render, screen } from "@testing-library/react";
import { afterEach, expect, it, vi } from "vitest";
import { AtlasVNextProvider } from "./AtlasVNextProvider";
import {
  AtlasOperationStatus,
  type AtlasOperation,
} from "./AtlasOperationStatus";

afterEach(() => {
  cleanup();
  vi.useRealTimers();
});
const show = (operation: AtlasOperation) => (
  <AtlasVNextProvider>
    <AtlasOperationStatus operation={operation} />
  </AtlasVNextProvider>
);
it("delays feedback until 2s, reports elapsed time and adds calm copy at 15s without ticking the live region", () => {
  vi.useFakeTimers();
  const startedAt = Date.now();
  const { unmount } = render(
    show({ status: "RUNNING", action: "Đang tạo nhu cầu…", startedAt }),
  );
  act(() => vi.advanceTimersByTime(1999));
  expect(screen.queryByRole("status")).not.toBeInTheDocument();
  act(() => vi.advanceTimersByTime(1));
  const status = screen.getByRole("status");
  expect(status).toHaveAttribute("aria-live", "polite");
  expect(status).toHaveTextContent("Đang tạo nhu cầu…");
  expect(screen.getByText("Đã xử lý 2 giây")).toBeVisible();
  expect(status).not.toHaveTextContent("2 giây");
  act(() => vi.advanceTimersByTime(12000));
  expect(screen.queryByText(/Vui lòng không gửi lại/)).not.toBeInTheDocument();
  act(() => vi.advanceTimersByTime(1000));
  expect(status).toHaveTextContent("Vui lòng không gửi lại yêu cầu.");
  expect(screen.getByText("Đã xử lý 15 giây")).toBeVisible();
  unmount();
  expect(vi.getTimerCount()).toBe(0);
});
it.each([
  ["SUCCEEDED", "Hoàn tất"],
  ["FAILED", "Không thể hoàn tất"],
  ["UNKNOWN_OUTCOME", "Chưa xác định kết quả"],
] as const)("transitions to %s and stops the timer", (state, heading) => {
  vi.useFakeTimers();
  const { rerender } = render(
    show({
      status: "RUNNING",
      action: "Đang cập nhật nhu cầu…",
      startedAt: Date.now(),
    }),
  );
  act(() => vi.advanceTimersByTime(3000));
  rerender(
    show({ status: state, message: "Kết quả được xác nhận từ máy chủ." }),
  );
  expect(screen.getByRole("status")).toHaveTextContent(heading);
  expect(screen.getByRole("status")).toHaveTextContent(
    "Kết quả được xác nhận từ máy chủ.",
  );
  expect(vi.getTimerCount()).toBe(0);
  expect(screen.queryByText(/Đã xử lý/)).not.toBeInTheDocument();
});
