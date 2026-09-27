import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
  within,
} from "@testing-library/react";
import { afterEach, beforeEach, expect, it, vi } from "vitest";
import { AtlasTableViewport } from "./AtlasTableViewport";
import { AtlasVNextProvider } from "./AtlasVNextProvider";

let notifyResize: (() => void) | undefined;

beforeEach(() => {
  notifyResize = undefined;
  vi.stubGlobal(
    "ResizeObserver",
    class {
      constructor(callback: () => void) {
        notifyResize = callback;
      }
      observe() {}
      unobserve() {}
      disconnect() {}
    },
  );
});

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

it("renders native children inside a named keyboard-reachable local overflow region", () => {
  render(
    <AtlasVNextProvider>
      <AtlasTableViewport label="Danh sách kiểm tra">
        <table>
          <tbody>
            <tr>
              <td>Nội dung</td>
            </tr>
          </tbody>
        </table>
      </AtlasTableViewport>
    </AtlasVNextProvider>,
  );

  const region = screen.getByRole("region", { name: "Danh sách kiểm tra" });
  expect(region).toHaveAttribute("tabindex", "0");
  expect(region).toHaveStyle({ overflow: "auto" });
  region.focus();
  expect(region).toHaveFocus();
  expect(within(region).getByRole("table")).toContainElement(
    within(region).getByText("Nội dung"),
  );
});

it("keeps the named focusable overflow region under shared component ownership", () => {
  render(
    <AtlasVNextProvider>
      <AtlasTableViewport
        label="Danh sách được bảo vệ"
        role="group"
        aria-label="Tên không được dùng"
        tabIndex={-1}
        overflow="visible"
      >
        <div>Nội dung được bảo vệ</div>
      </AtlasTableViewport>
    </AtlasVNextProvider>,
  );

  const region = screen.getByRole("region", {
    name: "Danh sách được bảo vệ",
  });
  expect(region).toHaveAttribute("tabindex", "0");
  expect(region).toHaveStyle({ overflow: "auto" });
  expect(
    screen.queryByRole("group", { name: "Tên không được dùng" }),
  ).not.toBeInTheDocument();
});

it("shows semantic, motion-free continuation cues only while content remains", async () => {
  render(
    <AtlasVNextProvider>
      <AtlasTableViewport label="Danh sách rộng">
        <table>
          <tbody>
            <tr>
              <td>Nội dung rộng</td>
            </tr>
          </tbody>
        </table>
      </AtlasTableViewport>
    </AtlasVNextProvider>,
  );

  const region = screen.getByRole("region", { name: "Danh sách rộng" });
  Object.defineProperties(region, {
    clientWidth: { configurable: true, value: 320 },
    scrollWidth: { configurable: true, value: 900 },
    scrollLeft: { configurable: true, writable: true, value: 0 },
  });
  notifyResize?.();

  const endCue = await screen.findByTestId("table-continuation-end");
  expect(endCue).toHaveAttribute("aria-hidden", "true");
  expect(endCue).toHaveAttribute("data-atlas-continuation", "end");
  expect(endCue).toHaveStyle({
    pointerEvents: "none",
    transition: "var(--atlas-layout-motion, none)",
  });
  expect(
    screen.queryByTestId("table-continuation-start"),
  ).not.toBeInTheDocument();

  Object.defineProperty(region, "scrollLeft", {
    configurable: true,
    writable: true,
    value: 580,
  });
  fireEvent.scroll(region);

  await waitFor(() =>
    expect(
      screen.queryByTestId("table-continuation-end"),
    ).not.toBeInTheDocument(),
  );
  expect(screen.getByTestId("table-continuation-start")).toHaveAttribute(
    "data-atlas-continuation",
    "start",
  );
});
