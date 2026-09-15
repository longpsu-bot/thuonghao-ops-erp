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
import { AtlasVNextProvider } from "./AtlasVNextProvider";
import { AtlasWeekRangeInput } from "./AtlasWeekRangeInput";

beforeEach(() => {
  vi.stubGlobal(
    "ResizeObserver",
    class {
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

function show(disabled = false) {
  const onValueChange = vi.fn();
  function ControlledWeek() {
    const [value, setValue] = useState("2026-09-14");
    return (
      <AtlasWeekRangeInput
        label="Tuần phục vụ"
        value={value}
        disabled={disabled}
        onValueChange={(next) => {
          onValueChange(next);
          setValue(next);
        }}
      />
    );
  }
  render(
    <AtlasVNextProvider>
      <ControlledWeek />
    </AtlasVNextProvider>,
  );
  return onValueChange;
}

describe("Atlas week-range input", () => {
  it("projects one canonical Monday as its full Vietnamese Monday-Sunday range", () => {
    show();
    expect(screen.getByRole("textbox", { name: "Tuần phục vụ" })).toHaveValue(
      "14/09/2026 – 20/09/2026",
    );
    expect(
      screen.queryByText("14/09/2026 – 20/09/2026"),
    ).not.toBeInTheDocument();
  });

  it("opens by keyboard and normalizes a selected Wednesday before emitting", async () => {
    const onValueChange = show();
    const field = screen.getByRole("textbox", { name: "Tuần phục vụ" });
    fireEvent.keyDown(field, { key: "ArrowDown" });
    const grid = await screen.findByRole("grid");
    expect(
      [...grid.querySelectorAll("th")].map((cell) => cell.textContent),
    ).toEqual(["T2", "T3", "T4", "T5", "T6", "T7", "CN"]);
    const wednesday = grid.querySelector<HTMLElement>(
      '[data-part="table-cell-trigger"][data-value="2026-09-16"]',
    );
    expect(wednesday).not.toBeNull();
    fireEvent.click(wednesday!);
    await waitFor(() =>
      expect(onValueChange).toHaveBeenCalledWith("2026-09-14"),
    );
    expect(field).toHaveValue("14/09/2026 – 20/09/2026");
  });

  it("disables both the range field and calendar trigger without emitting", () => {
    const onValueChange = show(true);
    const field = screen.getByRole("textbox", { name: "Tuần phục vụ" });
    const trigger = screen.getByRole("button", {
      name: "Mở lịch — Tuần phục vụ",
    });
    expect(field).toBeDisabled();
    expect(trigger).toBeDisabled();
    fireEvent.click(field);
    fireEvent.click(trigger);
    expect(screen.queryByRole("grid")).not.toBeInTheDocument();
    expect(onValueChange).not.toHaveBeenCalled();
  });
});
