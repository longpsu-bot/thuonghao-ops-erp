import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
  within,
} from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { AtlasVNextProvider } from "./AtlasVNextProvider";
import { AtlasSchoolScope } from "./AtlasSchoolScope";
import { SchoolDefaultsWorkbench } from "./schools/SchoolDefaultsWorkbench";
import { createSchoolDefaultsReviewFixture } from "./schools/schoolDefaultsReviewFixtures";
import { IngredientSupplierWorkbench } from "./master-data/IngredientSupplierWorkbench";
import { createIngredientSupplierReviewFixture } from "./master-data/ingredientSupplierReviewFixtures";
import { PlanningSourcesWorkbench } from "./planning/PlanningSourcesWorkbench";
import { createPlanningStoryFixture } from "./planning/planningStoryFixtures";
import { RecipeCapability } from "./recipes/RecipeCapability";
import {
  createRecipeReviewFixture,
  fixtureSuccess,
} from "./recipes/recipeReviewFixtures";
import {
  createChangeOrderFixture,
  fixtureTargets,
} from "./recipes/changeOrderReviewFixtures";

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
const button = (name: string) => screen.getByRole("button", { name });
const change = (input: HTMLElement, value: string) =>
  fireEvent.change(input, { target: { value } });
// jsdom does not resolve background custom properties. Inspect the emitted
// resting rule; real browser evidence additionally verifies computed colors.
const primary = () =>
  screen
    .getAllByRole("button", { hidden: true })
    .filter(
      (b) =>
        !b.hasAttribute("disabled") &&
        [...document.styleSheets].some((sheet) =>
          [...sheet.cssRules].some(
            (rule) =>
              rule instanceof CSSStyleRule &&
              [...b.classList].some(
                (name) => rule.selectorText === `.${name}`,
              ) &&
              rule.style.background ===
                "var(--atlas-colors-action-primary-default)",
          ),
        ),
    );

async function schools() {
  const api = createSchoolDefaultsReviewFixture();
  const read = vi.spyOn(api, "getSchools");
  render(
    <AtlasVNextProvider>
      <SchoolDefaultsWorkbench api={api} authSubject="operator" />
    </AtlasVNextProvider>,
  );
  const input = await screen.findByRole("textbox", {
    name: "Học sinh mặc định — Trường Mầm non Ánh Dương",
  });
  change(input, "123");
  return { input, read };
}
async function planning(job: "menu" | "attendance" | "pantry") {
  const f = createPlanningStoryFixture(
    job === "pantry" ? "pantry_review" : job,
  );
  const read = vi.spyOn(f.api, "getWorkbench");
  const pantryRead = vi.spyOn(f.pantryApi, "getWorkbench");
  render(
    <AtlasVNextProvider>
      <PlanningSourcesWorkbench
        {...f}
        authSubject="operator"
        initialWeek="2026-09-07"
        initialJob={job}
      />
    </AtlasVNextProvider>,
  );
  await screen.findByRole("table");
  if (job === "menu") {
    fireEvent.click(button("Đồng bộ Google Sheet"));
    await screen.findByText("Đang chỉnh sửa · chưa lưu");
  } else
    change(
      await screen.findByRole("textbox", {
        name:
          job === "attendance"
            ? "Học sinh Trường Nguyễn Du"
            : "Số lượng dòng 1",
      }),
      "125",
    );
  fireEvent.click(button("Xem thay đổi"));
  const review = await screen.findByRole("complementary", {
    name: "Xem thay đổi",
  });
  return { review, read, pantryRead };
}

function choose(label: string, value: string) {
  change(screen.getByLabelText(label), value);
}
async function renderChangeOrders(
  fixture = createChangeOrderFixture("ACTIVE"),
) {
  render(
    <AtlasVNextProvider>
      <RecipeCapability
        authSubject="operator"
        recipeApi={createRecipeReviewFixture("DISH_ACTIVE_EDITABLE").api}
        adjustmentApi={fixture.api}
        initialDate="2026-09-12"
        initialJob="changes"
      />
    </AtlasVNextProvider>,
  );
  await waitFor(() => expect(button("Tạo lệnh điều chỉnh")).toBeEnabled());
  return fixture;
}
async function startDishAdd(ingredientId = "ingredient-2") {
  fireEvent.click(button("Tạo lệnh điều chỉnh"));
  choose("Món", "dish-0");
  choose("Loại công thức", "scope-0");
  choose("Hành động", "ADD");
  choose("Nguyên liệu thêm", ingredientId);
  choose("Định lượng mới", "13");
  choose("Lý do điều chỉnh", "Điều chỉnh theo thực đơn");
}

describe("06D-C duplicate ADD operator safety", () => {
  it("blocks one duplicate until an explicit exact-line quantity transition", async () => {
    const f = await renderChangeOrders();
    await startDishAdd();

    expect(
      await screen.findByText(/Hành lá đã có trong công thức/i),
    ).toBeVisible();
    expect(screen.getByText(/0,2 Kilôgam/i)).toBeVisible();
    expect(button("Xem tác động")).toBeDisabled();
    expect(f.calls.filter((call) => call.name === "preview")).toHaveLength(0);
    expect(f.calls.filter((call) => call.name === "create")).toHaveLength(0);

    fireEvent.click(button("Chuyển sang Điều chỉnh định lượng"));

    expect(screen.getByLabelText("Hành động")).toHaveValue("ADJUST_QUANTITY");
    expect(screen.getByLabelText("Thành phần hiện tại")).toHaveValue(
      "ADJUSTMENT_LINE:prior-add-line",
    );
    expect(screen.getByLabelText("Định lượng mới")).toHaveValue("13");
    expect(f.calls.filter((call) => call.name === "preview")).toHaveLength(0);
    expect(f.calls.filter((call) => call.name === "create")).toHaveLength(0);
  });

  it("blocks ambiguous duplicates and requires manual action and target selection", async () => {
    const f = createChangeOrderFixture("ACTIVE");
    f.api.getEffectiveTargetContext = async (
      _subject,
      _correlation,
      date,
      dish,
      context,
    ) => {
      const targets = fixtureTargets(
        date,
        dish,
        context.kind === "school" ? context.schoolId : null,
        context.kind === "system" ? context.schoolTypeId : "scope-0",
      );
      targets.effective_lines.push({
        ...targets.effective_lines[1]!,
        target_id: "second-add-line",
        adjustment_line_id: "second-add-line",
      });
      return fixtureSuccess({ target_context: targets });
    };
    await renderChangeOrders(f);
    await startDishAdd();

    expect(
      await screen.findByText(
        /Nguyên liệu đã xuất hiện ở nhiều dòng hiệu lực/i,
      ),
    ).toBeVisible();
    expect(button("Xem tác động")).toBeDisabled();
    expect(
      screen.queryByRole("button", {
        name: "Chuyển sang Điều chỉnh định lượng",
      }),
    ).not.toBeInTheDocument();

    choose("Hành động", "ADJUST_QUANTITY");
    expect(screen.getByLabelText("Thành phần hiện tại")).toHaveValue("");
    choose("Thành phần hiện tại", "ADJUSTMENT_LINE:second-add-line");
    expect(screen.getByLabelText("Thành phần hiện tại")).toHaveValue(
      "ADJUSTMENT_LINE:second-add-line",
    );
  });

  it("keeps an existing ADD correction on its immutable action identity", async () => {
    const f = createChangeOrderFixture("ACTIVE");
    const row = f.data.operator_rows[0]!;
    row.action_kind = "ADD";
    row.target_ingredient_id = "ingredient-2";
    row.target_recipe_line_id = null;
    row.adjustment_line_id = "prior-add-line";
    for (const revision of [
      row.command_revision,
      row.content_revision,
      row.display_revision,
      ...row.history,
    ]) {
      revision.substitute_ingredient_id = null;
      revision.quantity_per_basis = 0.2;
      revision.unit_id = "kg";
    }
    await renderChangeOrders(f);
    fireEvent.click(
      screen.getByRole("button", { name: /Xem lệnh Thêm nguyên liệu/ }),
    );
    fireEvent.click(button("Sửa lệnh"));

    await waitFor(() => expect(button("Xem tác động")).toBeEnabled());
    expect(screen.getByLabelText("Hành động")).toHaveValue("ADD");
    expect(
      screen.queryByRole("button", {
        name: "Chuyển sang Điều chỉnh định lượng",
      }),
    ).not.toBeInTheDocument();
    fireEvent.click(button("Xem tác động"));
    await waitFor(() =>
      expect(f.calls.filter((call) => call.name === "preview")).toHaveLength(1),
    );
    expect(
      (
        f.calls.find((call) => call.name === "preview")?.payload as {
          proposed_adjustment: { action_kind: string };
        }
      ).proposed_adjustment.action_kind,
    ).toBe("ADD");
  });
});

describe("06D-C locked Recipe peer navigation", () => {
  it("opens the existing Change Order job without a backend mutation", async () => {
    const recipe = createRecipeReviewFixture("DISH_ACTIVE_LOCKED");
    recipe.data.recipe_versions[0]!.recipe_version_status = "LOCKED";
    const adjustment = createChangeOrderFixture("ACTIVE");
    const recipeWrite = vi.spyOn(recipe.api, "saveRecipe");
    render(
      <AtlasVNextProvider>
        <RecipeCapability
          authSubject="operator"
          recipeApi={recipe.api}
          adjustmentApi={adjustment.api}
          initialDate="2026-09-12"
          initialJob="recipes"
        />
      </AtlasVNextProvider>,
    );
    fireEvent.click(
      await screen.findByRole("button", {
        name: "Xem công thức Canh bí đỏ thịt bằm",
      }),
    );
    fireEvent.click(
      await screen.findByRole("button", { name: "Tạo lệnh điều chỉnh" }),
    );

    expect(
      screen.getByRole("tab", { name: "Lệnh điều chỉnh" }),
    ).toHaveAttribute("aria-selected", "true");
    expect(
      await screen.findByRole("table", { name: "Lệnh điều chỉnh" }),
    ).toBeInTheDocument();
    expect(recipeWrite).not.toHaveBeenCalled();
    expect(
      adjustment.calls.filter((call) =>
        ["create", "supersede", "cancel"].includes(call.name),
      ),
    ).toHaveLength(0);
  });
});

describe("06B frozen Review safety and focus", () => {
  it("preserves a School draft on normal refresh and saves directly without Review", async () => {
    const { input, read } = await schools();
    expect(button("Làm mới dữ liệu")).toBeEnabled();
    fireEvent.click(button("Làm mới dữ liệu"));
    await waitFor(() => expect(read).toHaveBeenCalledTimes(2));
    await waitFor(() => expect(button("Làm mới dữ liệu")).toBeEnabled());
    expect(input).toHaveValue("123");
    expect(
      screen.queryByRole("complementary", {
        name: "Thay đổi sĩ số mặc định",
      }),
    ).not.toBeInTheDocument();
    expect(button("Làm mới dữ liệu")).toBeEnabled();
    expect(button("Lưu thay đổi")).toBeEnabled();
  });
  it.each(["menu", "attendance", "pantry"] as const)(
    "blocks routine refresh during %s Preview and restores it on back",
    async (job) => {
      const { read, pantryRead } = await planning(job);
      const reads = read.mock.calls.length,
        pantryReads = pantryRead.mock.calls.length;
      expect(button("Làm mới dữ liệu")).toBeDisabled();
      fireEvent.click(button("Làm mới dữ liệu"));
      expect(read).toHaveBeenCalledTimes(reads);
      expect(pantryRead).toHaveBeenCalledTimes(pantryReads);
      expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
      fireEvent.click(button("Quay lại"));
      expect(button("Làm mới dữ liệu")).toBeEnabled();
      expect(screen.getByText("Đang chỉnh sửa · chưa lưu")).toBeVisible();
    },
  );
  it("moves focus into Planning Review and returns it on back", async () => {
    const { review } = await planning("attendance");
    await waitFor(() => expect(review).toHaveFocus());
    fireEvent.click(button("Quay lại"));
    await waitFor(() => expect(button("Xem thay đổi")).toHaveFocus());
  });
});

describe("06B peer navigation and action hierarchy", () => {
  async function master() {
    const api = createIngredientSupplierReviewFixture();
    const read = api.getIngredientsAndSuppliers;
    api.getIngredientsAndSuppliers = async (...args) => {
      const result = await read(...args);
      if (result.kind === "success") {
        for (const key of ["ingredients", "suppliers"])
          if (Array.isArray(result.response[key]))
            result.response[key] = result.response[key].slice(0, 3);
      }
      return result;
    };
    render(
      <AtlasVNextProvider>
        <IngredientSupplierWorkbench authSubject="operator" api={api} />
      </AtlasVNextProvider>,
    );
    await screen.findByText("Rau muống", { exact: true });
  }
  it("links semantic peer tabs to their panel", async () => {
    await master();
    const tab = screen.getByRole("tab", { name: "Nguyên liệu" });
    expect(tab).toHaveAttribute("aria-selected", "true");
    expect(
      document.getElementById(tab.getAttribute("aria-controls")!),
    ).toHaveAttribute("role", "tabpanel");
    expect(primary().map((b) => b.textContent)).toEqual(["Tạo nguyên liệu"]);
  });
  it("keeps a dirty peer switch guarded through Cancel and Discard", async () => {
    await master();
    fireEvent.click(screen.getByRole("button", { name: /Xem.*Rau muống/ }));
    const input = screen.getByRole("textbox", {
      name: "Tên nguyên liệu",
    });
    change(input, "Rau muống mới");
    fireEvent.click(screen.getByRole("tab", { name: "Nhà cung ứng" }));
    const dialog = await screen.findByRole("dialog");
    fireEvent.click(
      within(dialog).getByRole("button", { name: "Tiếp tục chỉnh sửa" }),
    );
    await waitFor(() => expect(dialog).toHaveAttribute("data-state", "closed"));
    expect(screen.getByRole("tab", { name: "Nguyên liệu" })).toHaveAttribute(
      "aria-selected",
      "true",
    );
    expect(input).toHaveValue("Rau muống mới");
    fireEvent.click(screen.getByRole("tab", { name: "Nhà cung ứng" }));
    const discardDialog = await screen.findByRole("dialog");
    fireEvent.click(
      within(discardDialog).getByRole("button", { name: "Bỏ thay đổi" }),
    );
    await waitFor(() =>
      expect(discardDialog).toHaveAttribute("data-state", "closed"),
    );
    fireEvent.animationEnd(discardDialog);
    await waitFor(() =>
      expect(screen.getByRole("tab", { name: "Nhà cung ứng" })).toHaveAttribute(
        "aria-selected",
        "true",
      ),
    );
    expect(
      screen.queryByRole("textbox", { name: "Tên nguyên liệu" }),
    ).not.toBeInTheDocument();
  });
  it("makes the exact Ingredient save the sole dominant command during Review", async () => {
    await master();
    fireEvent.click(screen.getByRole("button", { name: /Xem.*Rau muống/ }));
    change(
      screen.getByRole("textbox", { name: "Tên nguyên liệu" }),
      "Rau muống mới",
    );
    fireEvent.click(button("Xem thay đổi"));
    await screen.findByRole("complementary", {
      name: "Xem thay đổi nguyên liệu",
    });
    expect(primary().map((b) => b.textContent)).toEqual(["Lưu nguyên liệu"]);
  });
  it.each(["recipes", "changes"] as const)(
    "demotes Create while the %s editor owns the current decision",
    async (job) => {
      render(
        <AtlasVNextProvider>
          <RecipeCapability
            authSubject="operator"
            recipeApi={createRecipeReviewFixture("DISH_ACTIVE_EDITABLE").api}
            adjustmentApi={createChangeOrderFixture("ACTIVE").api}
            initialDate="2026-09-12"
            initialJob={job}
          />
        </AtlasVNextProvider>,
      );
      const create = await screen.findByRole("button", {
        name: job === "recipes" ? "Tạo món mới" : "Tạo lệnh điều chỉnh",
      });
      await waitFor(() => expect(create).toBeEnabled());
      expect(primary()).toContain(create);
      fireEvent.click(
        job === "recipes"
          ? screen.getByRole("button", {
              name: "Sửa công thức Canh bí đỏ thịt bằm",
            })
          : create,
      );
      if (job === "recipes") {
        await screen.findByLabelText("Định lượng Bí đỏ");
        await waitFor(() =>
          expect(
            screen.getByRole("button", { name: "Tạo món mới", hidden: true }),
          ).toBeEnabled(),
        );
      }
      expect(primary()).not.toContain(
        screen.getByRole("button", {
          name: job === "recipes" ? "Tạo món mới" : "Tạo lệnh điều chỉnh",
          hidden: true,
        }),
      );
    },
  );
  it("does not present School filter application as a business command", async () => {
    render(
      <AtlasVNextProvider>
        <AtlasSchoolScope
          schools={[{ school_id: "s", school_name: "Trường A" }]}
          value={[]}
          onApply={() => {}}
        />
      </AtlasVNextProvider>,
    );
    fireEvent.click(button("Tất cả trường"));
    await screen.findByRole("button", { name: "Áp dụng" });
    expect(primary()).toHaveLength(0);
  });
});
