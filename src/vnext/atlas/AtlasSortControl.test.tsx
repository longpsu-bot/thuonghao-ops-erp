import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  within,
} from "@testing-library/react";
import { afterEach, expect, it, vi } from "vitest";
import { AtlasVNextProvider } from "./AtlasVNextProvider";
import { AtlasSortControl } from "./AtlasSortControl";
afterEach(cleanup);
it("exposes every axis and direction in one labelled control and restores canonical order", () => {
  const change = vi.fn();
  render(
    <AtlasVNextProvider>
      <AtlasSortControl
        label="Sắp xếp phân bổ"
        axes={
          [
            ["school", "Trường"],
            ["need", "Nhu cầu"],
          ] as const
        }
        value={{ key: null, direction: "default" }}
        onChange={change}
      />
    </AtlasVNextProvider>,
  );
  const select = screen.getByRole("combobox", { name: "Sắp xếp phân bổ" });
  expect(within(select).getAllByRole("option")).toHaveLength(5);
  for (const key of ["school", "need"])
    for (const direction of ["ascending", "descending"]) {
      fireEvent.change(select, { target: { value: `${key}:${direction}` } });
      expect(change).toHaveBeenLastCalledWith({ key, direction });
    }
  fireEvent.change(select, { target: { value: "default" } });
  expect(change).toHaveBeenLastCalledWith({ key: null, direction: "default" });
});
