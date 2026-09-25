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

let resize: (() => void) | undefined;

beforeEach(() => {
  resize = undefined;
  vi.stubGlobal(
    "ResizeObserver",
    class {
      constructor(callback: () => void) {
        resize = callback;
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

it("creates a named keyboard-reachable local scroll region", () => {
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
  expect(within(region).getByText("Nội dung")).toBeVisible();
});

it("shows a non-interactive continuation fade only while more columns remain", async () => {
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
  resize?.();

  const endFade = await screen.findByTestId("table-continuation-end");
  expect(endFade).toHaveAttribute("aria-hidden", "true");
  expect(endFade).toHaveStyle({ pointerEvents: "none" });
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
    "aria-hidden",
    "true",
  );
});
