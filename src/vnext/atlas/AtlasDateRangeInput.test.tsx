import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { useState } from "react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { AtlasDateRangeInput } from "./AtlasDateRangeInput";
import { AtlasVNextProvider, AtlasWorkbenchScope } from "./AtlasVNextProvider";
import { operatorDateRangeError } from "./atlasOperatorDateRange";

beforeEach(() =>
  vi.stubGlobal(
    "ResizeObserver",
    class {
      observe() {}
      unobserve() {}
      disconnect() {}
    },
  ),
);
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});
function show() {
  const changed = vi.fn();
  function Controlled() {
    const [value, setValue] = useState({
      start: "2026-09-29",
      end: "2026-09-29",
    });
    return (
      <AtlasDateRangeInput
        label="Khoảng ngày"
        value={value}
        error={operatorDateRangeError(value)}
        onValueChange={(next) => {
          changed(next);
          setValue(next);
        }}
      />
    );
  }
  render(
    <AtlasVNextProvider>
      <Controlled />
    </AtlasVNextProvider>,
  );
  return changed;
}
describe("shared PO/PXK calendar range", () => {
  it("associates invalid segments with one externally rendered workbar error", () => {
    const { container } = render(
      <AtlasVNextProvider>
        <AtlasDateRangeInput
          label="Khoảng ngày"
          value={{ start: "2026-09-29", end: "2026-10-06" }}
          error="Chọn tối đa 7 ngày."
          errorMessageId="range-error"
          onValueChange={vi.fn()}
        />
        <p id="range-error" role="alert">
          Chọn tối đa 7 ngày.
        </p>
      </AtlasVNextProvider>,
    );
    expect(screen.getAllByRole("alert")).toHaveLength(1);
    for (const segment of screen.getAllByRole("spinbutton"))
      expect(segment).toHaveAttribute("aria-invalid", "true");
    expect(
      container.querySelectorAll(
        '[data-scope="date-input"][data-part="segment-group"]',
      ),
    ).toHaveLength(2);
    for (const label of ["Từ ngày", "Đến ngày"]) {
      const group = screen.getByRole("group", { name: label });
      expect(group).toHaveAttribute("aria-describedby", "range-error");
      expect(
        document.getElementById(group.getAttribute("aria-describedby")!),
      ).toHaveTextContent("Chọn tối đa 7 ngày.");
    }
  });
  it("dismisses an inactive owner's calendar and preserves its independent range", async () => {
    const changed = vi.fn();
    const content = (active: boolean) => (
      <AtlasVNextProvider>
        <AtlasWorkbenchScope active={active}>
          <AtlasDateRangeInput
            label="Khoảng ngày"
            value={{ start: "2026-09-29", end: "2026-10-05" }}
            onValueChange={changed}
          />
        </AtlasWorkbenchScope>
      </AtlasVNextProvider>
    );
    const { container, rerender } = render(content(true));
    const segments = screen.getAllByRole("spinbutton");
    fireEvent.click(
      screen.getByRole("button", { name: "Mở lịch — Khoảng ngày" }),
    );
    await screen.findByRole("grid");
    rerender(content(false));
    await waitFor(() =>
      expect(
        container.querySelector('[data-scope="date-picker"][data-part="root"]'),
      ).toHaveAttribute("data-state", "closed"),
    );
    await waitFor(() =>
      expect(screen.queryByRole("grid")).not.toBeInTheDocument(),
    );
    expect(segments[0]).toHaveAttribute("aria-disabled", "true");
    fireEvent.keyDown(segments[0]!, { key: "ArrowUp" });
    expect(changed).not.toHaveBeenCalled();
    rerender(content(true));
    expect(screen.getAllByRole("spinbutton").map((s) => s.textContent)).toEqual(
      ["29", "09", "2026", "05", "10", "2026"],
    );
    expect(screen.queryByRole("grid")).not.toBeInTheDocument();
  });
  it("presents two Vietnamese dates in one control and opens a Monday-first calendar", async () => {
    show();
    expect(screen.getAllByRole("spinbutton").map((s) => s.textContent)).toEqual(
      ["29", "09", "2026", "29", "09", "2026"],
    );
    fireEvent.click(
      screen.getByRole("button", { name: "Mở lịch — Khoảng ngày" }),
    );
    const grid = await screen.findByRole("grid");
    expect([...grid.querySelectorAll("th")].map((h) => h.textContent)).toEqual([
      "T2",
      "T3",
      "T4",
      "T5",
      "T6",
      "T7",
      "CN",
    ]);
    expect(grid.closest("[data-atlas-portal-root]")).not.toBeNull();
  });
  it("changes the end date with the keyboard and reports an eight-day range", async () => {
    const changed = show();
    const endDay = screen.getAllByRole("spinbutton")[3]!;
    fireEvent.focus(endDay);
    fireEvent.keyDown(endDay, { key: "ArrowUp" });
    await waitFor(() =>
      expect(changed).toHaveBeenLastCalledWith({
        start: "2026-09-29",
        end: "2026-09-30",
      }),
    );
    fireEvent.focus(screen.getAllByRole("spinbutton")[4]!);
    fireEvent.keyDown(screen.getAllByRole("spinbutton")[4]!, {
      key: "ArrowUp",
    });
    expect(await screen.findByText("Chọn tối đa 7 ngày.")).toHaveAttribute(
      "role",
      "alert",
    );
  });
  it.each(["2026-09-26", "2026-09-30"])(
    "commits a same-day or cross-week calendar selection through %s only after the second date",
    async (end) => {
      const changed = show();
      const trigger = screen.getByRole("button", {
        name: "Mở lịch — Khoảng ngày",
      });
      fireEvent.click(trigger);
      const grid = await screen.findByRole("grid");
      fireEvent.click(
        grid.querySelector<HTMLElement>(
          '[data-part="table-cell-trigger"][data-value="2026-09-26"]',
        )!,
      );
      expect(changed).not.toHaveBeenCalled();
      fireEvent.click(
        grid.querySelector<HTMLElement>(
          `[data-part="table-cell-trigger"][data-value="${end}"]`,
        )!,
      );
      await waitFor(() =>
        expect(changed).toHaveBeenLastCalledWith({
          start: "2026-09-26",
          end,
        }),
      );
      await waitFor(() =>
        expect(screen.queryByRole("grid")).not.toBeInTheDocument(),
      );
    },
  );
});
