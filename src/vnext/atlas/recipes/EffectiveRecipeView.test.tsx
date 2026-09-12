import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  within,
} from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import { AtlasVNextProvider } from "../AtlasVNextProvider";
import {
  dishRecipeOperatorWorkbenchFromResult,
  type DishRecipeOperatorWorkbench,
} from "../bridges/dishRecipe";
import { EffectiveRecipeView } from "./EffectiveRecipeView";
import { createRecipeReviewFixture } from "./recipeReviewFixtures";

afterEach(cleanup);
async function facts() {
  const f = createRecipeReviewFixture();
  return dishRecipeOperatorWorkbenchFromResult(
    await f.api.getEffectiveWorkbench(
      "operator",
      "review",
      "2026-09-12",
      "dish-0",
      { kind: "system", schoolTypeId: "scope-0" },
    ),
  )!;
}
function show(effective: DishRecipeOperatorWorkbench | null) {
  return render(
    <AtlasVNextProvider>
      <EffectiveRecipeView effective={effective} />
    </AtlasVNextProvider>,
  );
}
describe("authoritative effective presentation", () => {
  it("keeps equal composition in a closed disclosure with accessible read-only facts", async () => {
    show(await facts());
    expect(screen.getByText("Đang trùng với công thức gốc")).toBeVisible();
    const summary = screen.getByText("Xem thành phần hiệu lực");
    expect(summary.closest("details")).not.toHaveAttribute("open");
    fireEvent.click(summary);
    expect(
      screen.getByRole("table", { name: "Công thức hiệu lực" }),
    ).toBeVisible();
    expect(screen.queryByRole("textbox")).not.toBeInTheDocument();
  });
  it.each(["ingredient", "quantity", "unit", "basis"] as const)(
    "shows %s differences directly without inferring adjustment rules",
    async (kind) => {
      const e = await facts();
      if (kind === "ingredient") {
        e.current_effective_bom[0].ingredient_id = "another";
        e.current_effective_bom[0].ingredient_name = "Cà rốt";
      }
      if (kind === "quantity")
        e.current_effective_bom[0].quantity_per_basis = 19;
      if (kind === "unit") {
        e.current_effective_bom[0].unit_id = "another";
        e.current_effective_bom[0].unit_name = "Gam";
      }
      if (kind === "basis") e.basis_portions = 100;
      show(e);
      expect(
        screen.getByText("Công thức hiệu lực có thay đổi so với công thức gốc"),
      ).toBeVisible();
      const table = screen.getByRole("table", { name: "Công thức hiệu lực" });
      expect(table).toBeVisible();
      if (kind === "ingredient")
        expect(within(table).getByText("Cà rốt")).toBeVisible();
      if (kind === "quantity")
        expect(within(table).getByText("19")).toBeVisible();
      if (kind === "unit") expect(within(table).getByText("Gam")).toBeVisible();
      if (kind === "basis") expect(screen.getByText(/100 suất/)).toBeVisible();
    },
  );
  it("ignores removed base lines and technical lineage while preserving material counts", async () => {
    const e = await facts();
    e.base_authoring.composition.push({
      ...e.base_authoring.composition[0],
      recipe_line_id: "removed",
      line_disposition: "REMOVED",
    });
    e.current_effective_bom[0].target_id = "different-lineage";
    e.current_effective_bom[0].source_layer = "SYSTEM_DISH";
    const view = show(e);
    expect(screen.getByText("Đang trùng với công thức gốc")).toBeVisible();
    e.current_effective_bom.push({
      ...e.current_effective_bom[0],
      target_id: "extra",
    });
    view.rerender(
      <AtlasVNextProvider>
        <EffectiveRecipeView effective={e} />
      </AtlasVNextProvider>,
    );
    expect(
      screen.getByText("Công thức hiệu lực có thay đổi so với công thức gốc"),
    ).toBeVisible();
  });
  it("shows locked equal composition directly and never adds a Change Order control", async () => {
    const e = await facts();
    e.editable_state = "LOCKED_CHANGE_ORDER";
    show(e);
    expect(
      screen.getByRole("table", { name: "Công thức hiệu lực" }),
    ).toBeVisible();
    expect(
      screen.queryByText("Xem thành phần hiệu lực"),
    ).not.toBeInTheDocument();
    expect(screen.queryByRole("button")).not.toBeInTheDocument();
  });
  it("does not claim equality when effective readiness is blocked", async () => {
    const e = await facts();
    e.effective_readiness.status = "BLOCKED";
    show(e);
    expect(
      screen.getByText("Chưa sẵn sàng cho ngày áp dụng này."),
    ).toBeVisible();
    expect(
      screen.queryByText("Đang trùng với công thức gốc"),
    ).not.toBeInTheDocument();
    expect(screen.queryByRole("table")).not.toBeInTheDocument();
  });
});
