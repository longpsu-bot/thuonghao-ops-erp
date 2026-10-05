import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { useState } from "react";
import { afterEach, beforeEach, expect, it, vi } from "vitest";
import { AtlasDateInput } from "./AtlasDateInput";
import { AtlasVNextProvider, AtlasWorkbenchScope } from "./AtlasVNextProvider";

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

function PersistentDates() {
  const [active, setActive] = useState("Need");
  const [closed, setClosed] = useState(false);
  const [dates, setDates] = useState({
    Need: "2026-09-05",
    Purchase: "2026-10-02",
    Recipe: "2026-11-03",
  });
  return (
    <AtlasVNextProvider>
      <button
        onClick={() => setActive(active === "Need" ? "Purchase" : "Need")}
      >
        Switch owner
      </button>
      <button onClick={() => setClosed(true)}>Close inactive Need</button>
      <button
        onClick={() =>
          setDates((previous) => ({ ...previous, Need: "2026-12-18" }))
        }
      >
        Set hidden Need date
      </button>
      {(["Need", "Purchase", "Recipe"] as const).map((owner) =>
        owner === "Need" && closed ? null : (
          <section
            key={owner}
            data-owner={owner}
            hidden={active !== owner}
            inert={active !== owner}
          >
            <AtlasWorkbenchScope active={active === owner}>
              <AtlasDateInput
                label={owner}
                value={dates[owner]}
                onValueChange={(value) =>
                  setDates((previous) => ({ ...previous, [owner]: value }))
                }
              />
            </AtlasWorkbenchScope>
          </section>
        ),
      )}
    </AtlasVNextProvider>
  );
}

it("dismisses the owned calendar on deactivation while retaining its date", async () => {
  const { container } = render(<PersistentDates />);
  const segment = screen.getAllByRole("spinbutton")[0];
  fireEvent.click(screen.getByRole("button", { name: "Mở lịch — Need" }));
  await screen.findByRole("grid");
  fireEvent.click(screen.getByRole("button", { name: "Switch owner" }));
  await waitFor(() =>
    expect(
      container.querySelector('[data-owner="Need"] [data-part="content"]'),
    ).toBeNull(),
  );
  fireEvent.click(screen.getByRole("button", { name: "Switch owner" }));
  await waitFor(() =>
    expect(screen.queryByRole("grid")).not.toBeInTheDocument(),
  );
  expect(screen.getAllByRole("spinbutton")[0]).toBe(segment);
  expect(
    screen.getAllByRole("spinbutton").map((segment) => segment.textContent),
  ).toEqual(["05", "09", "2026"]);
});

it("preserves independent dates after keyboard selection and a delayed switch", async () => {
  render(<PersistentDates />);
  const trigger = screen.getByRole("button", { name: "Mở lịch — Need" });
  trigger.focus();
  fireEvent.click(trigger);
  const grid = await screen.findByRole("grid");
  await waitFor(() =>
    expect(
      grid.querySelector(
        '[data-value="2026-09-05"][data-part="table-cell-trigger"]',
      ),
    ).toHaveFocus(),
  );
  fireEvent.keyDown(document.activeElement!, { key: "ArrowRight" });
  await waitFor(() =>
    expect(
      grid.querySelector(
        '[data-value="2026-09-06"][data-part="table-cell-trigger"]',
      ),
    ).toHaveFocus(),
  );
  fireEvent.keyDown(document.activeElement!, { key: "Enter" });
  await waitFor(() =>
    expect(screen.getAllByRole("spinbutton")[0]).toHaveTextContent("06"),
  );
  fireEvent.click(screen.getByRole("button", { name: "Switch owner" }));
  await new Promise((resolve) => window.setTimeout(resolve, 3100));
  expect(screen.queryByRole("grid")).not.toBeInTheDocument();
  expect(
    screen.getAllByRole("spinbutton").map((segment) => segment.textContent),
  ).toEqual(["02", "10", "2026"]);
  fireEvent.click(screen.getByRole("button", { name: "Switch owner" }));
  expect(
    screen.getAllByRole("spinbutton").map((segment) => segment.textContent),
  ).toEqual(["06", "09", "2026"]);
}, 10000);

it("blocks hidden editing while accepting an explicit owner date update", async () => {
  render(<PersistentDates />);
  const segment = screen.getAllByRole("spinbutton")[0];
  fireEvent.click(screen.getByRole("button", { name: "Switch owner" }));
  expect(segment).toHaveAttribute("aria-disabled", "true");
  expect(segment.tabIndex).toBe(-1);
  fireEvent.keyDown(segment, { key: "ArrowUp" });
  fireEvent.click(segment);
  expect(segment).toHaveTextContent("05");
  expect(screen.queryByRole("grid")).not.toBeInTheDocument();
  fireEvent.click(screen.getByRole("button", { name: "Set hidden Need date" }));
  await waitFor(() => expect(segment).toHaveTextContent("18"));
  fireEvent.click(screen.getByRole("button", { name: "Switch owner" }));
  expect(screen.getAllByRole("spinbutton")[0]).toBe(segment);
  expect(
    screen.getAllByRole("spinbutton").map((segment) => segment.textContent),
  ).toEqual(["18", "12", "2026"]);
});

it("closing an inactive owner does not corrupt the active calendar or selected date", async () => {
  render(<PersistentDates />);
  fireEvent.click(screen.getByRole("button", { name: "Switch owner" }));
  fireEvent.click(screen.getByRole("button", { name: "Mở lịch — Purchase" }));
  const grid = await screen.findByRole("grid");
  fireEvent.click(screen.getByRole("button", { name: "Close inactive Need" }));
  expect(screen.getByRole("grid")).toBe(grid);
  fireEvent.click(
    grid.querySelector<HTMLElement>(
      '[data-value="2026-10-13"][data-part="table-cell-trigger"]',
    )!,
  );
  await waitFor(() =>
    expect(screen.getAllByRole("spinbutton")[0]).toHaveTextContent("13"),
  );
  await new Promise((resolve) => window.setTimeout(resolve, 3100));
  expect(screen.queryByRole("grid")).not.toBeInTheDocument();
  expect(
    screen.getAllByRole("spinbutton").map((segment) => segment.textContent),
  ).toEqual(["13", "10", "2026"]);
}, 10000);
