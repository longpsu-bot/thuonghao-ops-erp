import "@testing-library/jest-dom/vitest";
import { LocaleProvider } from "@chakra-ui/react";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { useState } from "react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { AtlasDateInput } from "./AtlasDateInput";
import { AtlasVNextProvider } from "./AtlasVNextProvider";
import { atlasSystem } from "./system";

// jsdom has no layout observer; browser review verifies actual popup positioning.
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

describe("Atlas date convention", () => {
  const show = (
    onValueChange = vi.fn(),
    disabled = false,
    initial = "2026-09-05",
  ) => {
    function ControlledDate() {
      const [value, setValue] = useState(initial);
      return (
        <AtlasDateInput
          label="Ngày phục vụ"
          value={value}
          disabled={disabled}
          onValueChange={(next) => {
            onValueChange(next);
            setValue(next);
          }}
        />
      );
    }
    return render(
      <AtlasVNextProvider>
        <ControlledDate />
      </AtlasVNextProvider>,
    );
  };
  const trigger = () =>
    screen.getByRole("button", { name: "Mở lịch — Ngày phục vụ" });
  const day = (grid: HTMLElement, value: string) => {
    const cell = grid.querySelector<HTMLElement>(
      `[data-part="table-cell-trigger"][data-value="${value}"]`,
    );
    expect(cell).not.toBeNull();
    return cell!;
  };

  it("bounds calendar tables independently of legacy Storybook table geometry", () => {
    expect(
      atlasSystem._config.theme?.slotRecipes?.datePicker?.base?.table,
    ).toMatchObject({
      minW: "var(--atlas-layout-zero, 0)",
      w: "full",
      tableLayout: "fixed",
    });
  });

  it("opens a Vietnamese Monday-first popup with selection inside the single Atlas host", async () => {
    const { container } = show();
    fireEvent.click(trigger());
    const grid = await screen.findByRole("grid");
    expect(grid).toBeVisible();
    // Chakra hides the visual weekday row from AT; each day has a full date label.
    expect(
      [...grid.querySelectorAll("th")].map((header) => header.textContent),
    ).toEqual(["T2", "T3", "T4", "T5", "T6", "T7", "CN"]);
    expect(
      screen.getByRole("button", { name: "Chọn tháng" }),
    ).toHaveTextContent("tháng 9 năm 2026");
    expect(day(grid, "2026-09-05")).toHaveAttribute("data-selected");
    const host = grid.closest("[data-atlas-portal-root]");
    expect(host?.parentElement).toHaveClass("atlas-vnext");
    expect(container.querySelectorAll(".atlas-vnext")).toHaveLength(1);
    expect(container.querySelectorAll("[data-atlas-portal-root]")).toHaveLength(
      1,
    );
    expect(document.querySelector('input[type="date"]')).toBeNull();
  });

  it("selects an ISO date, updates controlled segments and returns focus on close", async () => {
    const onValueChange = vi.fn();
    show(onValueChange);
    trigger().focus();
    fireEvent.click(trigger());
    const grid = await screen.findByRole("grid");
    await waitFor(() => expect(day(grid, "2026-09-05")).toHaveFocus());
    fireEvent.click(day(grid, "2026-09-13"));
    await waitFor(() =>
      expect(onValueChange).toHaveBeenCalledWith("2026-09-13"),
    );
    expect(
      screen.getAllByRole("spinbutton").map((segment) => segment.textContent),
    ).toEqual(["13", "09", "2026"]);
    await waitFor(() =>
      expect(screen.queryByRole("grid")).not.toBeInTheDocument(),
    );
    await waitFor(() => expect(trigger()).toHaveFocus());
  });

  it("opens from the segmented field without changing its date", async () => {
    const onValueChange = vi.fn();
    show(onValueChange);
    fireEvent.click(screen.getAllByRole("spinbutton")[0]);
    expect(await screen.findByRole("grid")).toBeVisible();
    expect(onValueChange).not.toHaveBeenCalled();
  });

  it("supports keyboard day navigation and Escape focus return without a value change", async () => {
    const onValueChange = vi.fn();
    show(onValueChange);
    trigger().focus();
    fireEvent.click(trigger());
    const grid = await screen.findByRole("grid");
    await waitFor(() => expect(day(grid, "2026-09-05")).toHaveFocus());
    fireEvent.keyDown(document.activeElement!, { key: "ArrowRight" });
    await waitFor(() => expect(day(grid, "2026-09-06")).toHaveFocus());
    fireEvent.keyDown(document.activeElement!, { key: "Escape" });
    await waitFor(() =>
      expect(screen.queryByRole("grid")).not.toBeInTheDocument(),
    );
    await waitFor(() => expect(trigger()).toHaveFocus());
    expect(onValueChange).not.toHaveBeenCalled();
  });

  it("disables both segmented editing and calendar activation", async () => {
    const onValueChange = vi.fn();
    show(onValueChange, true);
    expect(trigger()).toBeDisabled();
    for (const segment of screen.getAllByRole("spinbutton")) {
      expect(segment).toHaveAttribute("aria-disabled", "true");
      fireEvent.keyDown(segment, { key: "ArrowUp" });
      fireEvent.click(segment);
    }
    fireEvent.click(trigger());
    expect(screen.queryByRole("grid")).not.toBeInTheDocument();
    expect(onValueChange).not.toHaveBeenCalled();
  });

  it("marks today separately from selection and uses the Atlas selection hierarchy", async () => {
    const now = new Date();
    const today = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(now.getDate()).padStart(2, "0")}`;
    const otherDay = now.getDate() === 1 ? "02" : "01";
    show(vi.fn(), false, `${today.slice(0, 8)}${otherDay}`);
    fireEvent.click(trigger());
    const grid = await screen.findByRole("grid");
    expect(day(grid, today)).toHaveAttribute("data-today");
    expect(day(grid, today)).not.toHaveAttribute("data-selected");
    expect(
      atlasSystem._config.theme?.slotRecipes?.datePicker?.base
        ?.tableCellTrigger,
    ).toMatchObject({
      _today: { color: "fg.primary", textDecoration: "underline" },
      "&[data-selected]": { bg: "action.primary.default", color: "fg.inverse" },
    });
  });
  it("renders leading-zero day/month/year segments despite the surrounding locale", () => {
    const { container } = render(
      <AtlasVNextProvider>
        <LocaleProvider locale="en-US">
          <AtlasDateInput
            label="Ngày phục vụ"
            value="2026-09-05"
            onValueChange={() => {}}
          />
        </LocaleProvider>
      </AtlasVNextProvider>,
    );
    expect(container.querySelector('input[type="date"]')).toBeNull();
    const segments = screen.getAllByRole("spinbutton");
    expect(
      segments.map((segment) => segment.getAttribute("data-type")),
    ).toEqual(["day", "month", "year"]);
    expect(segments.map((segment) => segment.textContent)).toEqual([
      "05",
      "09",
      "2026",
    ]);
    expect(
      container.querySelector('[data-part="segment-group"]')?.textContent,
    ).toBe("05/09/2026");
  });
  it("emits canonical business dates when a day segment is edited", async () => {
    const onValueChange = vi.fn();
    render(
      <AtlasVNextProvider>
        <AtlasDateInput
          label="Ngày phục vụ"
          value="2026-09-05"
          onValueChange={onValueChange}
        />
      </AtlasVNextProvider>,
    );
    fireEvent.focus(screen.getAllByRole("spinbutton")[0]);
    fireEvent.keyDown(screen.getAllByRole("spinbutton")[0], { key: "ArrowUp" });
    await waitFor(() =>
      expect(onValueChange).toHaveBeenCalledWith("2026-09-06"),
    );
  });
});
