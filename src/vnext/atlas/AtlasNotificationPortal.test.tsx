import "@testing-library/jest-dom/vitest";
import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
} from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { AtlasNotificationPortal } from "./AtlasNotificationPortal";
import { AtlasVNextProvider } from "./AtlasVNextProvider";

afterEach(() => {
  cleanup();
  vi.useRealTimers();
});

describe("Atlas notification portal", () => {
  it("owns a polite, dismissible portal notice and pauses dismissal on hover", () => {
    vi.useFakeTimers();
    const dismiss = vi.fn();
    render(
      <AtlasVNextProvider>
        <AtlasNotificationPortal
          message={{
            id: 1,
            title: "Đã đồng bộ thực đơn",
            description: "2 món đã được thay đổi.",
          }}
          onDismiss={dismiss}
        />
      </AtlasVNextProvider>,
    );
    const notice = screen.getByRole("status", {
      name: /Đã đồng bộ thực đơn/,
    });
    expect(notice).toHaveAttribute("aria-live", "polite");
    expect(notice.parentElement).toHaveAttribute("data-atlas-portal-root");
    act(() => vi.advanceTimersByTime(3000));
    fireEvent.pointerEnter(notice);
    act(() => vi.advanceTimersByTime(10000));
    expect(dismiss).not.toHaveBeenCalled();
    fireEvent.pointerLeave(notice);
    act(() => vi.advanceTimersByTime(4000));
    expect(dismiss).toHaveBeenCalledOnce();
  });

  it("uses the latest callback without restarting the same notification", () => {
    vi.useFakeTimers();
    const first = vi.fn();
    const second = vi.fn();
    const message = {
      id: 2,
      title: "Đã đồng bộ thực đơn",
      description: "1 món đã được bỏ.",
    };
    const { rerender } = render(
      <AtlasVNextProvider>
        <AtlasNotificationPortal message={message} onDismiss={first} />
      </AtlasVNextProvider>,
    );
    act(() => vi.advanceTimersByTime(3000));
    rerender(
      <AtlasVNextProvider>
        <AtlasNotificationPortal message={message} onDismiss={second} />
      </AtlasVNextProvider>,
    );
    act(() => vi.advanceTimersByTime(4000));
    expect(first).not.toHaveBeenCalled();
    expect(second).toHaveBeenCalledOnce();
  });
});
