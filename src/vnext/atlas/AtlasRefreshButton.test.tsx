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
  it("keeps 8px controls, 6px workbenches and the circular compact Refresh exception", () => {
    const theme = atlasSystem._config.theme;
    expect(theme?.tokens?.radii?.control).toEqual({ value: "8px" });
    expect(theme?.tokens?.radii?.workbench).toEqual({ value: "6px" });
    expect(theme?.tokens?.sizes?.control).toEqual({ value: "40px" });
    expect(theme?.tokens?.sizes?.compact).toEqual({ value: "36px" });
    render(
      <AtlasVNextProvider>
        <AtlasRefreshButton loading={false} onClick={() => {}} />
      </AtlasVNextProvider>,
    );
    const button = screen.getByRole("button");
    const rules = [...document.styleSheets].flatMap((sheet) => [
      ...sheet.cssRules,
    ]);
    expect(
      rules.some(
        (rule) =>
          rule instanceof CSSStyleRule &&
          [...button.classList].some(
            (name) => rule.selectorText === `.${name}`,
          ) &&
          rule.style.borderRadius === "var(--atlas-radii-full)" &&
          rule.style.width === "var(--atlas-sizes-compact)" &&
          rule.style.height === "var(--atlas-sizes-compact)",
      ),
    ).toBe(true);
  });

  it("adds only local detail-entry motion and preserves Refresh timing", () => {
    const theme = atlasSystem._config.theme;
    expect(theme?.keyframes?.atlasDetailEnter).toEqual({
      from: { opacity: 0, transform: "translateY(6px)" },
      to: { opacity: 1, transform: "translateY(0)" },
    });
    expect(theme?.animationStyles?.detailEnter).toEqual({
      value: {
        animation: "atlasDetailEnter 160ms ease-out",
        _motionReduce: { animation: "none" },
      },
    });
    expect(theme?.animationStyles?.refreshSpin?.value?.animation).toBe(
      "atlasRefreshSpin 800ms linear infinite",
    );
    expect(theme?.animationStyles?.refreshComplete?.value?.animation).toBe(
      "atlasRefreshComplete 200ms ease-out",
    );
  });
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
