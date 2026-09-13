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
import { createRecipeReviewFixture } from "./recipes/recipeReviewFixtures";
import { createChangeOrderFixture } from "./recipes/changeOrderReviewFixtures";

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

describe("06B frozen Review safety and focus", () => {
  it("preserves a School draft on normal refresh but cannot refresh its frozen Review", async () => {
    const { input, read } = await schools();
    expect(button("Làm mới dữ liệu")).toBeEnabled();
    fireEvent.click(button("Làm mới dữ liệu"));
    await waitFor(() => expect(read).toHaveBeenCalledTimes(2));
    await waitFor(() => expect(button("Làm mới dữ liệu")).toBeEnabled());
    expect(input).toHaveValue("123");
    fireEvent.click(button("Xem thay đổi"));
    expect(button("Làm mới dữ liệu")).toBeDisabled();
    fireEvent.click(button("Làm mới dữ liệu"));
    expect(read).toHaveBeenCalledTimes(2);
    expect(
      screen.getByRole("complementary", { name: "Thay đổi sĩ số mặc định" }),
    ).toHaveFocus();
    fireEvent.click(button("Đóng"));
    expect(button("Làm mới dữ liệu")).toBeEnabled();
    expect(input).toHaveValue("123");
  });
  it("returns focus to the remounted School Review action on close", async () => {
    await schools();
    fireEvent.click(button("Xem thay đổi"));
    fireEvent.click(button("Đóng"));
    await waitFor(() => expect(button("Xem thay đổi")).toHaveFocus());
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
              name: "Xem công thức Canh bí đỏ thịt bằm",
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
