import "@testing-library/jest-dom/vitest";
import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
} from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { AtlasRefreshButton } from "./AtlasRefreshButton";
import { AtlasVNextProvider } from "./AtlasVNextProvider";
import { atlasSystem } from "./system";

afterEach(() => {
  cleanup();
  vi.useRealTimers();
});

describe("Atlas routine refresh", () => {
  it("names the utility and invokes only enabled activation", () => {
    const onClick = vi.fn();
    const { rerender } = render(
      <AtlasVNextProvider>
        <AtlasRefreshButton loading={false} onClick={onClick} />
      </AtlasVNextProvider>,
    );
    const button = screen.getByRole("button", { name: "Làm mới dữ liệu" });
    expect(button).toHaveAttribute("title", "Làm mới dữ liệu");
    fireEvent.click(button);
    expect(onClick).toHaveBeenCalledOnce();
    rerender(
      <AtlasVNextProvider>
        <AtlasRefreshButton loading={false} disabled onClick={onClick} />
      </AtlasVNextProvider>,
    );
    expect(button).toBeDisabled();
    fireEvent.click(button);
    expect(onClick).toHaveBeenCalledOnce();
  });

  it("keeps the same button and icon through loading, completion and bounded cleanup", () => {
    vi.useFakeTimers();
    const onClick = vi.fn();
    const view = (loading: boolean) => (
      <AtlasVNextProvider>
        <AtlasRefreshButton loading={loading} onClick={onClick} />
      </AtlasVNextProvider>
    );
    const { rerender } = render(view(false));
    const button = screen.getByRole("button");
    const icon = button.querySelector("svg");
    expect(button).toHaveAttribute("data-phase", "idle");
    rerender(view(true));
    expect(button).toHaveAttribute("aria-busy", "true");
    expect(button).toHaveAttribute("data-phase", "loading");
    expect(button).toBeDisabled();
    fireEvent.click(button);
    expect(onClick).not.toHaveBeenCalled();
    rerender(view(false));
    expect(button).toHaveAttribute("data-phase", "complete");
    expect(button).toHaveAttribute("aria-busy", "false");
    act(() => vi.advanceTimersByTime(199));
    expect(button).toHaveAttribute("data-phase", "complete");
    act(() => vi.advanceTimersByTime(1));
    expect(button).toHaveAttribute("data-phase", "idle");
    expect(screen.getByRole("button")).toBe(button);
    expect(button.querySelector("svg")).toBe(icon);
  });

  it("cancels prior completion when another read starts", () => {
    vi.useFakeTimers();
    const view = (loading: boolean) => (
      <AtlasVNextProvider>
        <AtlasRefreshButton loading={loading} onClick={() => {}} />
      </AtlasVNextProvider>
    );
    const { rerender } = render(view(true));
    rerender(view(false));
    rerender(view(true));
    act(() => vi.advanceTimersByTime(300));
    expect(screen.getByRole("button")).toHaveAttribute("data-phase", "loading");
  });

  it("suppresses both sanctioned animations under reduced motion", () => {
    for (const name of ["refreshSpin", "refreshComplete"]) {
      expect(atlasSystem._config.theme?.animationStyles?.[name]).toMatchObject({
        value: { _motionReduce: { animation: "none" } },
      });
    }
  });
});
