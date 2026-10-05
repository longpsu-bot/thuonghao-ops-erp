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
import { AtlasVNextProvider, AtlasWorkbenchScope } from "./AtlasVNextProvider";
import { AtlasDateInput } from "./AtlasDateInput";
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
  it("isolates pending week announcements across switch and inactive close without replacing the field", async () => {
    function Owners() {
      const [active, setActive] = useState(true);
      const [closed, setClosed] = useState(false);
      const [week, setWeek] = useState("2026-09-14");
      const [day, setDay] = useState("2026-10-02");
      return (
        <AtlasVNextProvider>
          <button onClick={() => setActive(!active)}>Switch date owner</button>
          <button onClick={() => setClosed(true)}>Close hidden week</button>
          {!closed && (
            <section hidden={!active} inert={!active}>
              <AtlasWorkbenchScope active={active}>
                <AtlasWeekRangeInput
                  label="Tuần phục vụ"
                  value={week}
                  onValueChange={setWeek}
                />
              </AtlasWorkbenchScope>
            </section>
          )}
          <section hidden={active} inert={active}>
            <AtlasWorkbenchScope active={!active}>
              <AtlasDateInput
                label="Ngày phục vụ"
                value={day}
                onValueChange={setDay}
              />
            </AtlasWorkbenchScope>
          </section>
        </AtlasVNextProvider>
      );
    }
    const { container } = render(<Owners />);
    const field = screen.getByRole("textbox", { name: "Tuần phục vụ" });
    fireEvent.keyDown(field, { key: "ArrowDown" });
    const grid = await screen.findByRole("grid");
    fireEvent.click(
      grid.querySelector<HTMLElement>(
        '[data-value="2026-09-23"][data-part="table-cell-trigger"]',
      )!,
    );
    await waitFor(() => expect(field).toHaveValue("21/09/2026 – 27/09/2026"));
    const pending = document.querySelector("[data-live-announcer]")!;
    expect(pending).not.toBeNull();
    fireEvent.click(screen.getByRole("button", { name: "Switch date owner" }));
    expect(container.querySelector('input[aria-label="Tuần phục vụ"]')).toBe(
      field,
    );
    expect(pending.isConnected).toBe(false);
    expect(
      container.querySelector(
        '[data-scope="date-picker"][data-part="content"]',
      ),
    ).toBeNull();
    const segment = screen.getAllByRole("spinbutton")[0];
    fireEvent.focus(segment);
    fireEvent.keyDown(segment, { key: "ArrowUp" });
    await waitFor(() => expect(segment).toHaveTextContent("03"));
    const activeRegion = document.querySelector("[data-live-announcer]")!;
    expect(activeRegion).not.toBeNull();
    fireEvent.click(screen.getByRole("button", { name: "Close hidden week" }));
    expect(activeRegion.isConnected).toBe(true);
    await new Promise((resolve) => window.setTimeout(resolve, 3100));
    expect(pending.textContent).toBe("");
    expect(activeRegion.textContent).not.toBe("");
    expect(activeRegion.closest("[hidden], [inert]")).toBeNull();
  }, 10000);

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
