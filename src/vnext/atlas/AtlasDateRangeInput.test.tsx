import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { useState } from "react";
import { userEvent } from "storybook/test";
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
  it("shows the complete interval on one range control without separate date fields", () => {
    show();
    const trigger = screen.getByRole("button", {
      name: "Mở lịch — Khoảng ngày",
    });
    expect(trigger).toHaveTextContent("29/09/2026 — 29/09/2026");
    expect((trigger as HTMLButtonElement).labels).toHaveLength(1);
    expect(screen.queryByRole("spinbutton")).not.toBeInTheDocument();
    expect(
      screen.queryByRole("group", { name: "Từ ngày" }),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByRole("group", { name: "Đến ngày" }),
    ).not.toBeInTheDocument();
  });
  it("associates the single invalid range control with one externally rendered workbar error", () => {
    render(
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
    const trigger = screen.getByRole("button", {
      name: "Mở lịch — Khoảng ngày",
    });
    expect(trigger).toHaveAttribute("aria-invalid", "true");
    expect(trigger).toHaveAccessibleDescription(
      "29/09/2026 — 06/10/2026 Chọn tối đa 7 ngày.",
    );
    expect(screen.queryByRole("spinbutton")).not.toBeInTheDocument();
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
    const trigger = screen.getByRole("button", {
      name: "Mở lịch — Khoảng ngày",
    });
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
    expect(trigger).toBeDisabled();
    fireEvent.click(trigger);
    expect(changed).not.toHaveBeenCalled();
    rerender(content(true));
    expect(trigger).toHaveTextContent("29/09/2026 — 05/10/2026");
    expect(screen.queryByRole("grid")).not.toBeInTheDocument();
  });
  it("opens a Monday-first range calendar from the combined interval", async () => {
    show();
    expect(
      screen.getByRole("button", { name: "Mở lịch — Khoảng ngày" }),
    ).toHaveAccessibleDescription("29/09/2026 — 29/09/2026");
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
  it("selects both ends with the keyboard and restores focus to the combined range", async () => {
    const changed = show();
    const trigger = screen.getByRole("button", {
      name: "Mở lịch — Khoảng ngày",
    });
    await userEvent.click(trigger);
    await screen.findByRole("grid");
    await waitFor(() =>
      expect(document.activeElement).toHaveAttribute(
        "data-value",
        "2026-09-29",
      ),
    );
    await userEvent.keyboard("{Enter}");
    expect(changed).not.toHaveBeenCalled();
    await waitFor(() =>
      expect(document.activeElement).toHaveAttribute(
        "data-value",
        "2026-09-30",
      ),
    );
    await userEvent.keyboard("{ArrowRight}");
    await waitFor(() =>
      expect(document.activeElement).toHaveAttribute(
        "data-value",
        "2026-10-01",
      ),
    );
    await userEvent.keyboard("{Enter}");
    await waitFor(() =>
      expect(changed).toHaveBeenLastCalledWith({
        start: "2026-09-29",
        end: "2026-10-01",
      }),
    );
    await waitFor(() => expect(trigger).toHaveFocus());
    expect(trigger).toHaveTextContent("29/09/2026 — 01/10/2026");
  });
  it("discards an unfinished range on Escape without changing the displayed scope", async () => {
    const changed = show();
    const trigger = screen.getByRole("button", {
      name: "Mở lịch — Khoảng ngày",
    });
    await userEvent.click(trigger);
    const grid = await screen.findByRole("grid");
    await userEvent.click(
      grid.querySelector<HTMLElement>(
        '[data-part="table-cell-trigger"][data-value="2026-09-26"]',
      )!,
    );
    expect(changed).not.toHaveBeenCalled();
    await userEvent.keyboard("{Escape}");
    await waitFor(() =>
      expect(screen.queryByRole("grid")).not.toBeInTheDocument(),
    );
    expect(trigger).toHaveTextContent("29/09/2026 — 29/09/2026");
    await waitFor(() => expect(trigger).toHaveFocus());
  });
  it("reports the eighth day selected across months on the single range control", async () => {
    const changed = show();
    fireEvent.click(
      screen.getByRole("button", { name: "Mở lịch — Khoảng ngày" }),
    );
    const grid = await screen.findByRole("grid");
    fireEvent.click(
      grid.querySelector<HTMLElement>(
        '[data-part="table-cell-trigger"][data-value="2026-09-29"]',
      )!,
    );
    expect(changed).not.toHaveBeenCalled();
    fireEvent.click(screen.getByRole("button", { name: "Tháng sau" }));
    await waitFor(() =>
      expect(
        screen
          .getByRole("grid")
          .querySelector(
            '[data-part="table-cell-trigger"][data-value="2026-10-06"]',
          ),
      ).not.toBeNull(),
    );
    fireEvent.click(
      screen
        .getByRole("grid")
        .querySelector<HTMLElement>(
          '[data-part="table-cell-trigger"][data-value="2026-10-06"]',
        )!,
    );
    await waitFor(() =>
      expect(changed).toHaveBeenLastCalledWith({
        start: "2026-09-29",
        end: "2026-10-06",
      }),
    );
    expect(await screen.findByText("Chọn tối đa 7 ngày.")).toHaveAttribute(
      "role",
      "alert",
    );
    expect(
      screen.getByRole("button", { name: "Mở lịch — Khoảng ngày" }),
    ).toHaveAttribute("aria-invalid", "true");
  });
  it.each(["2026-09-26", "2026-09-30"])(
    "commits a same-day or cross-week calendar selection through %s only after the second date",
    async (end) => {
      const changed = show();
      const trigger = screen.getByRole("button", {
        name: "Mở lịch — Khoảng ngày",
      });
      await userEvent.click(trigger);
      const grid = await screen.findByRole("grid");
      const popup = grid.closest<HTMLElement>('[data-part="content"]')!;
      await waitFor(() =>
        expect(document.activeElement).toHaveAttribute(
          "data-value",
          "2026-09-29",
        ),
      );
      await userEvent.click(
        grid.querySelector<HTMLElement>(
          '[data-part="table-cell-trigger"][data-value="2026-09-26"]',
        )!,
      );
      expect(changed).not.toHaveBeenCalled();
      // Pointer selection keeps focus on the selected starting date.
      await waitFor(() =>
        expect(document.activeElement).toHaveAttribute(
          "data-value",
          "2026-09-26",
        ),
      );
      await userEvent.click(
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
      expect(trigger).toHaveAttribute("aria-expanded", "false");
      // jsdom cannot finish a CSS exit animation. Wait until Presence has
      // removed the popup or installed its exit listener before simulating it.
      await waitFor(() => {
        if (popup.isConnected)
          expect(popup).toHaveAttribute("data-state", "closed");
        expect(
          !popup.isConnected || popup.style.animationFillMode === "forwards",
        ).toBe(true);
      });
      if (popup.isConnected)
        fireEvent(popup, new Event("animationcancel", { bubbles: true }));
      await waitFor(() =>
        expect(screen.queryByRole("grid")).not.toBeInTheDocument(),
      );
      expect(trigger).toHaveTextContent(
        end === "2026-09-26"
          ? "26/09/2026 — 26/09/2026"
          : "26/09/2026 — 30/09/2026",
      );
      await waitFor(() => expect(trigger).toHaveFocus());
      await userEvent.click(trigger);
      const selectedGrid = await screen.findByRole("grid");
      expect(
        [
          ...selectedGrid.querySelectorAll(
            '[data-part="table-cell-trigger"][data-in-range]',
          ),
        ].map((cell) => cell.getAttribute("data-value")),
      ).toEqual(
        end === "2026-09-26"
          ? ["2026-09-26"]
          : [
              "2026-09-26",
              "2026-09-27",
              "2026-09-28",
              "2026-09-29",
              "2026-09-30",
            ],
      );
    },
  );
});
