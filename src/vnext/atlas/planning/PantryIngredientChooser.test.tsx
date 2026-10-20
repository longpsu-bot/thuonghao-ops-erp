import "@testing-library/jest-dom/vitest";
import { cleanup, render, screen, within } from "@testing-library/react";
import { userEvent } from "storybook/test";
import { afterEach, beforeEach, expect, it, vi } from "vitest";
import { useState } from "react";
import { AtlasVNextProvider } from "../AtlasVNextProvider";
import type { PantryIngredient } from "../bridges/planning";
import { PantryIngredientChooser } from "./PantryIngredientChooser";

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
const ingredients: PantryIngredient[] = Array.from({ length: 403 }, (_, i) => ({
  ingredient_id: `ingredient-${i}`,
  ingredient_code: i >= 400 ? `RM-${i}` : `NL-${i}`,
  ingredient_name: i >= 400 ? "Rau muống" : `Nguyên liệu ${i}`,
  ingredient_status: i === 402 ? "INACTIVE" : "ACTIVE",
  purchase_unit: { unit_id: "kg", unit_code: "kg", unit_name: "Kilôgam" },
}));

it("keeps multi-character search independent of selection and selects exact eligible UUIDs from 403 Ingredients", async () => {
  const change = vi.fn();
  function Example() {
    const [value, setValue] = useState("");
    return (
      <AtlasVNextProvider>
        <PantryIngredientChooser
          label="Nguyên liệu dòng 1"
          ingredients={ingredients}
          value={value}
          onChange={(id) => {
            change(id);
            setValue(id);
          }}
        />
        <button>Tiếp theo</button>
      </AtlasVNextProvider>
    );
  }
  render(<Example />);
  const input = screen.getByRole("combobox", { name: "Nguyên liệu dòng 1" });
  await userEvent.click(input);
  expect(screen.getAllByRole("option")).toHaveLength(40);
  expect(screen.getByRole("status")).toHaveTextContent("40 / 403");
  await userEvent.type(input, "RAU MUONG");
  expect(input).toHaveValue("RAU MUONG");
  const list = screen.getByRole("listbox", { name: "Nguyên liệu dòng 1" });
  expect(within(list).getAllByRole("option")).toHaveLength(3);
  expect(within(list).getByRole("option", { name: /RM-402/ })).toHaveAttribute(
    "aria-disabled",
    "true",
  );
  expect(change).not.toHaveBeenCalled();
  await userEvent.keyboard("{ArrowDown}{ArrowDown}{Enter}");
  expect(change).toHaveBeenCalledExactlyOnceWith("ingredient-401");
  expect(input).toHaveValue("Rau muống");
  await userEvent.click(input);
  await userEvent.type(input, "NO MATCH");
  expect(screen.getByRole("status")).toHaveTextContent(
    "Không tìm thấy nguyên liệu",
  );
  await userEvent.keyboard("{Escape}{Tab}");
  expect(input).toHaveValue("Rau muống");
  expect(screen.getByRole("button", { name: "Tiếp theo" })).toHaveFocus();
  expect(change).toHaveBeenCalledTimes(1);
});

it("searches permitted internal references and supports pointer selection without committing typing", async () => {
  const change = vi.fn();
  render(
    <AtlasVNextProvider>
      <PantryIngredientChooser
        label="Nguyên liệu"
        ingredients={ingredients}
        value=""
        onChange={change}
      />
    </AtlasVNextProvider>,
  );
  await userEvent.type(screen.getByRole("combobox"), "RM-400");
  expect(change).not.toHaveBeenCalled();
  await userEvent.click(screen.getByRole("option", { name: /RM-400/ }));
  expect(change).toHaveBeenCalledExactlyOnceWith("ingredient-400");
});

it("retains the query and highlighted UUID through catalog reordering and blocks newly inactive results", async () => {
  const change = vi.fn();
  const rows = ingredients.slice(400);
  const example = (catalog: PantryIngredient[]) => (
    <AtlasVNextProvider>
      <PantryIngredientChooser
        label="Nguyên liệu"
        ingredients={catalog}
        value=""
        onChange={change}
      />
    </AtlasVNextProvider>
  );
  const view = render(example(rows));
  await userEvent.type(screen.getByRole("combobox"), "rau muong");
  await userEvent.keyboard("{ArrowDown}{ArrowDown}");
  view.rerender(example([rows[1]!, rows[0]!, rows[2]!]));
  expect(screen.getByRole("combobox")).toHaveValue("rau muong");
  await userEvent.keyboard("{Enter}");
  expect(change).toHaveBeenCalledExactlyOnceWith("ingredient-401");
  await userEvent.click(screen.getByRole("combobox"));
  await userEvent.type(screen.getByRole("combobox"), "RM-400");
  await userEvent.keyboard("{ArrowDown}");
  view.rerender(
    example(rows.filter((row) => row.ingredient_id !== "ingredient-400")),
  );
  await userEvent.keyboard("{Enter}");
  expect(change).toHaveBeenCalledTimes(1);
  view.rerender(
    example(rows.map((row) => ({ ...row, ingredient_status: "INACTIVE" }))),
  );
  await userEvent.keyboard("{Enter}");
  expect(change).toHaveBeenCalledTimes(1);
});
