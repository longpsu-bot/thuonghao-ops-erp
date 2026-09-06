import "@testing-library/jest-dom/vitest";
import { MantineProvider } from "@mantine/core";
import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
  within,
} from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { createRecipeAdjustmentApi } from "../atlas/recipe-adjustments/recipeAdjustmentApi";
import type {
  AtlasRpcRequest,
  AtlasRpcResult,
  JsonValue,
} from "../atlas/connection/atlasRpc";
import type { AtlasAuthState } from "../atlas/connection/authSession";
import { createReviewRecipeAdjustmentApi } from "../atlas/recipe-adjustments/reviewRecipeAdjustmentApi";
import { createReviewAuthState } from "../atlas/review/reviewMode";
import { atlasTheme } from "../../theme";
import {
  RecipeAdjustmentWorkbench,
  vietnamLocalDate,
} from "./RecipeAdjustmentWorkbench";

const fixtureIds = {
  school: "11000000-0000-4000-8000-000000000001",
  secondarySchool: "11000000-0000-4000-8000-000000000002",
  sameTypeSchool: "11000000-0000-4000-8000-000000000003",
  schoolType: "12000000-0000-4000-8000-000000000001",
  secondarySchoolType: "12000000-0000-4000-8000-000000000002",
  dish: "13000000-0000-4000-8000-000000000001",
  pumpkinLine: "16000000-0000-4000-8000-000000000001",
  porkLine: "16000000-0000-4000-8000-000000000002",
  secondaryPumpkinLine: "16000000-0000-4000-8000-000000000003",
  secondaryPorkLine: "16000000-0000-4000-8000-000000000004",
  pumpkin: "17000000-0000-4000-8000-000000000001",
  pork: "17000000-0000-4000-8000-000000000002",
  potato: "17000000-0000-4000-8000-000000000004",
  missingUnitIngredient: "17000000-0000-4000-8000-000000000005",
  kilogram: "18000000-0000-4000-8000-000000000001",
  systemAddLine: "1a000000-0000-4000-8000-000000000002",
  schoolAddLine: "1a000000-0000-4000-8000-000000000012",
};

beforeEach(() => {
  // JSDOM has no layout observer; keep the real Mantine Select/filter behavior.
  vi.stubGlobal(
    "ResizeObserver",
    class {
      observe() {}
      unobserve() {}
      disconnect() {}
    },
  );
  Object.defineProperty(Element.prototype, "scrollIntoView", {
    configurable: true,
    value: vi.fn(),
  });
});

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
  vi.useRealTimers();
});

function renderWorkbench(
  view: "rules" | "effective" = "rules",
  api = createReviewRecipeAdjustmentApi("ready"),
  mode: "review" | "connected" = "review",
) {
  return {
    api,
    ...render(
      <MantineProvider theme={atlasTheme}>
        <RecipeAdjustmentWorkbench
          authState={createReviewAuthState("ready")}
          api={api}
          view={view}
          mode={mode}
        />
      </MantineProvider>,
    ),
  };
}

async function openCreateDialog() {
  fireEvent.click(
    await screen.findByRole("button", { name: "Tạo điều chỉnh" }),
  );
  return screen.findByRole("dialog", { name: "Tạo điều chỉnh" });
}

function selectAction(dialog: HTMLElement, name: string) {
  fireEvent.click(within(dialog).getByLabelText(name));
}

function selectDish(picker: HTMLElement) {
  fireEvent.click(picker);
  fireEvent.change(picker, { target: { value: "bí đỏ" } });
  fireEvent.click(screen.getByRole("option", { name: "Canh bí đỏ" }));
}

function selectRecipeTarget(dialog: HTMLElement) {
  const school = within(dialog).queryByLabelText("Trường");
  if (school)
    fireEvent.change(school, {
      target: { value: fixtureIds.school },
    });
  selectDish(within(dialog).getByLabelText("Món"));
  const recipeType = within(dialog).queryByRole("combobox", {
    name: /Loại công thức/,
  });
  if (recipeType)
    fireEvent.change(recipeType, {
      target: { value: fixtureIds.schoolType },
    });
}

async function fillRecipeReplacement(dialog: HTMLElement) {
  fireEvent.click(within(dialog).getByLabelText("Một trường"));
  fireEvent.change(within(dialog).getByLabelText("Trường"), {
    target: { value: fixtureIds.school },
  });
  selectDish(within(dialog).getByLabelText("Món"));
  selectAction(dialog, "Thay nguyên liệu");
  const target = within(dialog).getByLabelText("Nguyên liệu trong công thức");
  await waitFor(() =>
    expect(
      within(target)
        .getAllByRole("option")
        .some((option) => option.getAttribute("value") === fixtureIds.porkLine),
    ).toBe(true),
  );
  fireEvent.change(target, {
    target: { value: fixtureIds.porkLine },
  });
  fireEvent.change(within(dialog).getByLabelText("Thay bằng"), {
    target: { value: fixtureIds.potato },
  });
  fireEvent.change(within(dialog).getByLabelText("Lý do"), {
    target: { value: "Thay theo tiêu chuẩn nguyên liệu đã duyệt." },
  });
}

function fillIngredientReplacement(dialog: HTMLElement) {
  const school = within(dialog).queryByLabelText("Trường");
  if (school)
    fireEvent.change(school, {
      target: { value: fixtureIds.school },
    });
  selectAction(dialog, "Thay nguyên liệu");
  fireEvent.change(within(dialog).getByLabelText("Nguyên liệu hiện tại"), {
    target: { value: fixtureIds.pork },
  });
  fireEvent.change(within(dialog).getByLabelText("Thay bằng"), {
    target: { value: fixtureIds.potato },
  });
  fireEvent.change(within(dialog).getByLabelText("Lý do"), {
    target: { value: "Thay theo tiêu chuẩn nguyên liệu đã duyệt." },
  });
  const representativeSchool =
    within(dialog).queryByLabelText("Trường đại diện");
  if (representativeSchool)
    fireEvent.change(representativeSchool, {
      target: { value: fixtureIds.school },
    });
  const representativeDish =
    within(dialog).queryByLabelText("Món đại diện") ??
    within(dialog).queryByLabelText("Món dùng để xem");
  if (representativeDish) selectDish(representativeDish);
}

async function selectSchoolDishTarget(
  dialog: HTMLElement,
  targetId: string,
  schoolId = fixtureIds.school,
) {
  fireEvent.click(within(dialog).getByLabelText("Một trường"));
  fireEvent.change(within(dialog).getByLabelText("Trường"), {
    target: { value: schoolId },
  });
  selectDish(within(dialog).getByLabelText("Món"));
  selectAction(dialog, "Thay nguyên liệu");
  const target = within(dialog).getByLabelText("Nguyên liệu trong công thức");
  await waitFor(() =>
    expect(
      within(target)
        .getAllByRole("option")
        .some((option) => option.getAttribute("value") === targetId),
    ).toBe(true),
  );
  fireEvent.change(target, { target: { value: targetId } });
}

async function selectSystemDishTarget(
  dialog: HTMLElement,
  targetId: string,
  schoolTypeId = fixtureIds.schoolType,
) {
  selectDish(within(dialog).getByLabelText("Món"));
  fireEvent.change(
    within(dialog).getByRole("combobox", { name: /Loại công thức/ }),
    { target: { value: schoolTypeId } },
  );
  selectAction(dialog, "Thay nguyên liệu");
  const target = within(dialog).getByLabelText("Nguyên liệu trong công thức");
  await waitFor(() =>
    expect(
      within(target)
        .getAllByRole("option")
        .some((option) => option.getAttribute("value") === targetId),
    ).toBe(true),
  );
  fireEvent.change(target, { target: { value: targetId } });
}

async function selectSchoolRecipeContext(dialog: HTMLElement, action: string) {
  fireEvent.click(within(dialog).getByLabelText("Một trường"));
  selectRecipeTarget(dialog);
  selectAction(dialog, action);
  if (action !== "Thêm nguyên liệu") {
    await waitFor(() =>
      expect(
        within(dialog).getByLabelText(
          action === "Bỏ nguyên liệu"
            ? "Nguyên liệu cần bỏ"
            : "Nguyên liệu trong công thức",
        ),
      ).toBeEnabled(),
    );
  }
}

describe("Recipe Change Order first-user workbench", () => {
  it("previews and creates a base SYSTEM_DISH target with Dish and School Type only", async () => {
    const { api } = renderWorkbench();
    const getTargets = vi.spyOn(api, "getEffectiveTargetContext");
    const preview = vi.spyOn(api, "preview");
    const create = vi.spyOn(api, "create");
    const dialog = await openCreateDialog();

    await selectSystemDishTarget(dialog, fixtureIds.pumpkinLine);
    fireEvent.change(within(dialog).getByLabelText("Thay bằng"), {
      target: { value: fixtureIds.potato },
    });
    fireEvent.change(within(dialog).getByLabelText("Lý do"), {
      target: { value: "Thay dòng gốc trong đúng loại công thức." },
    });

    await waitFor(() =>
      expect(getTargets).toHaveBeenCalledWith(
        expect.any(String),
        expect.any(String),
        expect.any(String),
        fixtureIds.dish,
        { kind: "system", schoolTypeId: fixtureIds.schoolType },
      ),
    );
    const target = within(dialog).getByLabelText("Nguyên liệu trong công thức");
    expect(
      within(target).getByRole("option", { name: /Cà rốt · 22/ }),
    ).toHaveValue(fixtureIds.pumpkinLine);
    expect(
      within(target).getByRole("option", {
        name: /Gia vị thiếu đơn vị · 1,25/,
      }),
    ).toHaveValue(fixtureIds.systemAddLine);
    expect(
      within(dialog).queryByLabelText("Trường dùng để xem"),
    ).not.toBeInTheDocument();
    expect(
      within(dialog).queryByText(/chưa hỗ trợ xem và lưu điều chỉnh/i),
    ).not.toBeInTheDocument();
    expect(
      within(dialog).queryByText("Xem ảnh hưởng tại"),
    ).not.toBeInTheDocument();
    const previewButton = within(dialog).getByRole("button", {
      name: "Xem ảnh hưởng",
    });
    await waitFor(() => expect(previewButton).toBeEnabled());
    fireEvent.click(previewButton);
    const review = await screen.findByRole("dialog", {
      name: "Thay đổi dự kiến",
    });
    expect(
      within(review).queryByText("Xem ảnh hưởng tại"),
    ).not.toBeInTheDocument();
    expect(preview.mock.calls[0][2]).toMatchObject({
      dish_id: fixtureIds.dish,
      school_type_id: fixtureIds.schoolType,
      proposed_adjustment: {
        target_recipe_line_id: fixtureIds.pumpkinLine,
        adjustment_line_id: null,
      },
    });
    expect(preview.mock.calls[0][2]).not.toHaveProperty("school_id");
    fireEvent.click(
      within(review).getByRole("button", { name: "Lưu điều chỉnh" }),
    );
    await waitFor(() => expect(create).toHaveBeenCalledOnce());
    expect(create.mock.calls[0][0].payload).toMatchObject({
      preview_dish_id: fixtureIds.dish,
      preview_school_type_id: fixtureIds.schoolType,
      target_recipe_line_id: fixtureIds.pumpkinLine,
      adjustment_line_id: null,
    });
    expect(create.mock.calls[0][0].payload).not.toHaveProperty(
      "preview_school_id",
    );
  });

  it("round-trips a prior SYSTEM_DISH ADD target through exact system Preview and Create", async () => {
    const { api } = renderWorkbench();
    const getTargets = vi.spyOn(api, "getEffectiveTargetContext");
    const preview = vi.spyOn(api, "preview");
    const create = vi.spyOn(api, "create");
    const dialog = await openCreateDialog();

    await selectSystemDishTarget(dialog, fixtureIds.systemAddLine);
    fireEvent.change(within(dialog).getByLabelText("Thay bằng"), {
      target: { value: fixtureIds.potato },
    });
    fireEvent.change(within(dialog).getByLabelText("Lý do"), {
      target: { value: "Thay dòng đã thêm trong đúng loại công thức." },
    });

    expect(getTargets).toHaveBeenCalledWith(
      expect.any(String),
      expect.any(String),
      expect.any(String),
      fixtureIds.dish,
      { kind: "system", schoolTypeId: fixtureIds.schoolType },
    );
    const previewButton = within(dialog).getByRole("button", {
      name: "Xem ảnh hưởng",
    });
    await waitFor(() => expect(previewButton).toBeEnabled());
    fireEvent.click(previewButton);
    const review = await screen.findByRole("dialog", {
      name: "Thay đổi dự kiến",
    });
    expect(preview.mock.calls[0][2]).toMatchObject({
      dish_id: fixtureIds.dish,
      school_type_id: fixtureIds.schoolType,
      proposed_adjustment: {
        target_recipe_line_id: null,
        adjustment_line_id: fixtureIds.systemAddLine,
      },
    });
    expect(preview.mock.calls[0][2]).not.toHaveProperty("school_id");
    fireEvent.click(
      within(review).getByRole("button", { name: "Lưu điều chỉnh" }),
    );
    await waitFor(() => expect(create).toHaveBeenCalledOnce());
    expect(create.mock.calls[0][0].payload).toMatchObject({
      preview_dish_id: fixtureIds.dish,
      preview_school_type_id: fixtureIds.schoolType,
      target_recipe_line_id: null,
      adjustment_line_id: fixtureIds.systemAddLine,
    });
    expect(create.mock.calls[0][0].payload).not.toHaveProperty(
      "preview_school_id",
    );
  });

  it("preserves a prior SCHOOL_DISH ADD target through correction Preview and Supersede", async () => {
    const { api } = renderWorkbench();
    const supersede = vi.spyOn(api, "supersede");
    const table = await screen.findByRole("table");
    const row = within(table)
      .getAllByRole("row")
      .find(
        (candidate) =>
          candidate.textContent?.includes(
            "Canh bí đỏ · Trường Tiểu học Minh Khai",
          ) && candidate.textContent?.includes("Thay nguyên liệu"),
      );
    expect(row).toBeDefined();
    fireEvent.click(within(row!).getByRole("button", { name: "Xem" }));
    const drawer = await screen.findByRole("dialog", {
      name: "Chi tiết điều chỉnh",
    });
    fireEvent.click(
      within(drawer).getByRole("button", { name: "Điều chỉnh lại" }),
    );
    const dialog = await screen.findByRole("dialog", {
      name: "Điều chỉnh lại",
    });
    await waitFor(() =>
      expect(
        within(dialog).getByLabelText("Nguyên liệu trong công thức"),
      ).toHaveValue(fixtureIds.schoolAddLine),
    );
    fireEvent.change(within(dialog).getByLabelText("Lý do"), {
      target: { value: "Sửa dòng do trường đã thêm trước đó." },
    });
    const previewButton = within(dialog).getByRole("button", {
      name: "Xem ảnh hưởng",
    });
    await waitFor(() => expect(previewButton).toBeEnabled());
    fireEvent.click(previewButton);
    const review = await screen.findByRole("dialog", {
      name: "Thay đổi dự kiến",
    });
    fireEvent.click(
      within(review).getByRole("button", { name: "Lưu điều chỉnh" }),
    );
    await waitFor(() => expect(supersede).toHaveBeenCalledOnce());
    expect(supersede.mock.calls[0][0].payload).toMatchObject({
      preview_school_id: fixtureIds.school,
      preview_dish_id: fixtureIds.dish,
      target_recipe_line_id: null,
      adjustment_line_id: fixtureIds.schoolAddLine,
    });
    expect(supersede.mock.calls[0][0].payload).not.toHaveProperty(
      "preview_school_type_id",
    );
  });

  it("supersedes SYSTEM_DISH with the exact Dish and School Type context", async () => {
    const { api } = renderWorkbench();
    const preview = vi.spyOn(api, "preview");
    const supersede = vi.spyOn(api, "supersede");
    const table = await screen.findByRole("table");
    const row = within(table)
      .getAllByRole("row")
      .find(
        (candidate) =>
          candidate.textContent?.includes(
            "Canh bí đỏ · TIỂU HỌC · Một món tại các trường",
          ) && candidate.textContent?.includes("Thay nguyên liệu"),
      );
    expect(row).toBeDefined();
    fireEvent.click(within(row!).getByRole("button", { name: "Xem" }));
    const drawer = await screen.findByRole("dialog", {
      name: "Chi tiết điều chỉnh",
    });
    fireEvent.click(
      within(drawer).getByRole("button", { name: "Điều chỉnh lại" }),
    );
    const dialog = await screen.findByRole("dialog", {
      name: "Điều chỉnh lại",
    });
    await waitFor(() =>
      expect(
        within(dialog).getByLabelText("Nguyên liệu trong công thức"),
      ).not.toHaveValue(""),
    );
    fireEvent.change(within(dialog).getByLabelText("Lý do"), {
      target: { value: "Sửa điều chỉnh hệ thống đã ban hành." },
    });
    const previewButton = within(dialog).getByRole("button", {
      name: "Xem ảnh hưởng",
    });
    await waitFor(() => expect(previewButton).toBeEnabled());
    fireEvent.click(previewButton);
    const review = await screen.findByRole("dialog", {
      name: "Thay đổi dự kiến",
    });
    expect(preview.mock.calls[0][2]).toMatchObject({
      dish_id: fixtureIds.dish,
      school_type_id: fixtureIds.schoolType,
      replaces_adjustment_id: expect.any(String),
    });
    expect(preview.mock.calls[0][2]).not.toHaveProperty("school_id");
    fireEvent.click(
      within(review).getByRole("button", { name: "Lưu điều chỉnh" }),
    );
    await waitFor(() => expect(supersede).toHaveBeenCalledOnce());
    expect(supersede.mock.calls[0][0].payload).toMatchObject({
      preview_dish_id: fixtureIds.dish,
      preview_school_type_id: fixtureIds.schoolType,
      predecessor_revision_id: expect.any(String),
    });
    expect(supersede.mock.calls[0][0].payload).not.toHaveProperty(
      "preview_school_id",
    );
  });

  it("invalidates a reviewed SYSTEM_DISH preview when School Type changes", async () => {
    const { api } = renderWorkbench();
    const preview = vi.spyOn(api, "preview");
    const create = vi.spyOn(api, "create");
    const dialog = await openCreateDialog();
    await selectSystemDishTarget(dialog, fixtureIds.pumpkinLine);
    fireEvent.change(within(dialog).getByLabelText("Thay bằng"), {
      target: { value: fixtureIds.potato },
    });
    fireEvent.change(within(dialog).getByLabelText("Lý do"), {
      target: { value: "Xem trước trước khi đổi loại công thức." },
    });
    fireEvent.click(
      within(dialog).getByRole("button", { name: "Xem ảnh hưởng" }),
    );
    const review = await screen.findByRole("dialog", {
      name: "Thay đổi dự kiến",
    });
    fireEvent.click(within(review).getByRole("button", { name: "Quay lại" }));
    const edit = await screen.findByRole("dialog", { name: "Tạo điều chỉnh" });
    fireEvent.change(
      within(edit).getByRole("combobox", { name: /Loại công thức/ }),
      { target: { value: fixtureIds.secondarySchoolType } },
    );

    expect(preview).toHaveBeenCalledOnce();
    expect(create).not.toHaveBeenCalled();
    expect(
      within(edit).queryByRole("button", { name: "Lưu điều chỉnh" }),
    ).not.toBeInTheDocument();
    expect(
      within(edit).getByRole("button", { name: "Xem ảnh hưởng" }),
    ).toBeDisabled();
  });

  it.each([
    ["a School identity", "school"],
    ["the wrong School Type", "school_type"],
  ] as const)(
    "rejects SYSTEM_DISH Preview with %s",
    async (_label, mismatch) => {
      const fixture = createReviewRecipeAdjustmentApi("ready");
      const api = {
        ...fixture,
        async preview(...args: Parameters<typeof fixture.preview>) {
          const result = await fixture.preview(...args);
          if (result.kind !== "success") return result;
          const preview = result.response.preview as Record<string, JsonValue>;
          const before = preview.before as Record<string, JsonValue>;
          const after = preview.after as Record<string, JsonValue>;
          return {
            ...result,
            response: {
              ...result.response,
              preview: {
                ...preview,
                ...(mismatch === "school"
                  ? { school_id: fixtureIds.school }
                  : { school_type_id: fixtureIds.secondarySchoolType }),
                before: {
                  ...before,
                  ...(mismatch === "school"
                    ? { school_id: fixtureIds.school }
                    : { school_type_id: fixtureIds.secondarySchoolType }),
                },
                after: {
                  ...after,
                  ...(mismatch === "school"
                    ? { school_id: fixtureIds.school }
                    : { school_type_id: fixtureIds.secondarySchoolType }),
                },
              },
            },
          };
        },
      };
      renderWorkbench("rules", api);
      const dialog = await openCreateDialog();
      await selectSystemDishTarget(dialog, fixtureIds.pumpkinLine);
      fireEvent.change(within(dialog).getByLabelText("Thay bằng"), {
        target: { value: fixtureIds.potato },
      });
      fireEvent.change(within(dialog).getByLabelText("Lý do"), {
        target: { value: "Từ chối kết quả sai bối cảnh hệ thống." },
      });
      fireEvent.click(
        within(dialog).getByRole("button", { name: "Xem ảnh hưởng" }),
      );
      await waitFor(() =>
        expect(
          screen.queryByRole("dialog", { name: "Thay đổi dự kiến" }),
        ).not.toBeInTheDocument(),
      );
      expect(
        screen.getByText(/không khớp bối cảnh đã gửi/i),
      ).toBeInTheDocument();
    },
  );

  it("ignores a late Preview after the reviewed intent changes", async () => {
    const fixture = createReviewRecipeAdjustmentApi("ready");
    let releasePreview: (() => Promise<void>) | undefined;
    const api = {
      ...fixture,
      preview: vi.fn(
        (...args: Parameters<typeof fixture.preview>) =>
          new Promise<Awaited<ReturnType<typeof fixture.preview>>>(
            (resolve) => {
              releasePreview = async () =>
                resolve(await fixture.preview(...args));
            },
          ),
      ),
    };
    renderWorkbench("rules", api);
    const dialog = await openCreateDialog();
    await selectSchoolDishTarget(dialog, fixtureIds.porkLine);
    fireEvent.change(within(dialog).getByLabelText("Thay bằng"), {
      target: { value: fixtureIds.potato },
    });
    const reason = within(dialog).getByLabelText("Lý do");
    fireEvent.change(reason, { target: { value: "Lý do trước khi gửi." } });
    fireEvent.click(
      within(dialog).getByRole("button", { name: "Xem ảnh hưởng" }),
    );
    fireEvent.change(reason, { target: { value: "Lý do đã thay đổi." } });
    await act(async () => releasePreview?.());

    await waitFor(() =>
      expect(
        screen.queryByRole("dialog", { name: "Thay đổi dự kiến" }),
      ).not.toBeInTheDocument(),
    );
    expect(
      within(dialog).queryByRole("button", { name: "Lưu điều chỉnh" }),
    ).not.toBeInTheDocument();
  });

  it("rejects a context-mismatched Preview and a malformed effective-target read", async () => {
    const fixture = createReviewRecipeAdjustmentApi("ready");
    const mismatchApi = {
      ...fixture,
      async preview(...args: Parameters<typeof fixture.preview>) {
        const result = await fixture.preview(...args);
        if (result.kind !== "success") return result;
        const preview = result.response.preview as Record<string, JsonValue>;
        const wrongSchoolId = fixtureIds.sameTypeSchool;
        return {
          ...result,
          response: {
            ...result.response,
            preview: {
              ...preview,
              school_id: wrongSchoolId,
              before: {
                ...(preview.before as Record<string, JsonValue>),
                school_id: wrongSchoolId,
              },
              after: {
                ...(preview.after as Record<string, JsonValue>),
                school_id: wrongSchoolId,
              },
            },
          },
        };
      },
    };
    renderWorkbench("rules", mismatchApi);
    const dialog = await openCreateDialog();
    await selectSchoolDishTarget(dialog, fixtureIds.porkLine);
    fireEvent.change(within(dialog).getByLabelText("Thay bằng"), {
      target: { value: fixtureIds.potato },
    });
    fireEvent.change(within(dialog).getByLabelText("Lý do"), {
      target: { value: "Không chấp nhận Preview sai trường." },
    });
    fireEvent.click(
      within(dialog).getByRole("button", { name: "Xem ảnh hưởng" }),
    );
    await waitFor(() =>
      expect(
        screen.queryByRole("dialog", { name: "Thay đổi dự kiến" }),
      ).not.toBeInTheDocument(),
    );

    cleanup();
    const malformedApi = {
      ...fixture,
      async getEffectiveTargetContext(
        ...args: Parameters<typeof fixture.getEffectiveTargetContext>
      ) {
        const result = await fixture.getEffectiveTargetContext(...args);
        if (result.kind !== "success") return result;
        const targetContext = result.response.target_context as Record<
          string,
          JsonValue
        >;
        const lines = targetContext.effective_lines as Array<
          Record<string, JsonValue>
        >;
        return {
          ...result,
          response: {
            ...result.response,
            target_context: {
              ...targetContext,
              effective_lines: [
                {
                  ...lines[0],
                  adjustment_line_id: fixtureIds.systemAddLine,
                },
              ],
            },
          },
        };
      },
    };
    renderWorkbench("rules", malformedApi);
    const malformedDialog = await openCreateDialog();
    fireEvent.click(within(malformedDialog).getByLabelText("Một trường"));
    fireEvent.change(within(malformedDialog).getByLabelText("Trường"), {
      target: { value: fixtureIds.school },
    });
    selectDish(within(malformedDialog).getByLabelText("Món"));
    selectAction(malformedDialog, "Thay nguyên liệu");
    await waitFor(() =>
      expect(
        within(malformedDialog).getByText(/không thể tải mục tiêu hiệu lực/i),
      ).toBeInTheDocument(),
    );
    expect(
      within(malformedDialog).getByRole("button", { name: "Xem ảnh hưởng" }),
    ).toBeDisabled();
  });

  it("keeps a denied Preview out of review and exposes only the safe operator message", async () => {
    const fixture = createReviewRecipeAdjustmentApi("ready");
    const api = {
      ...fixture,
      preview: vi.fn(async () => ({
        kind: "backend_error" as const,
        error: {
          success: false as const,
          error_code: "CAPABILITY_DENIED",
          safe_message: "Bạn không có quyền xem ảnh hưởng điều chỉnh này.",
        },
      })),
    };
    renderWorkbench("rules", api as typeof fixture);
    const dialog = await openCreateDialog();
    await selectSchoolDishTarget(dialog, fixtureIds.porkLine);
    fireEvent.change(within(dialog).getByLabelText("Thay bằng"), {
      target: { value: fixtureIds.potato },
    });
    fireEvent.change(within(dialog).getByLabelText("Lý do"), {
      target: { value: "Thử thao tác không được cấp quyền." },
    });
    const previewButton = within(dialog).getByRole("button", {
      name: "Xem ảnh hưởng",
    });
    await waitFor(() => expect(previewButton).toBeEnabled());
    fireEvent.click(previewButton);
    expect(
      await screen.findByText(
        "Bạn không có quyền thực hiện điều chỉnh công thức.",
      ),
    ).toBeInTheDocument();
    expect(
      screen.queryByRole("dialog", { name: "Thay đổi dự kiến" }),
    ).not.toBeInTheDocument();
  });

  it("fails closed when an authoring reference used by the form is malformed", async () => {
    const fixture = createReviewRecipeAdjustmentApi("ready");
    const api = {
      ...fixture,
      async getOperatorWorkbench(
        ...args: Parameters<typeof fixture.getOperatorWorkbench>
      ) {
        const result = await fixture.getOperatorWorkbench(...args);
        if (result.kind !== "success") return result;
        const workbench = result.response.workbench as Record<
          string,
          JsonValue
        >;
        const ingredients = workbench.ingredients as Array<
          Record<string, JsonValue>
        >;
        ingredients[0].purchase_unit_id = 42;
        return result;
      },
    };

    renderWorkbench("rules", api);

    expect(
      await screen.findByText(
        "Dữ liệu tham chiếu điều chỉnh không hợp lệ. Hãy tải lại.",
      ),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "Tạo điều chỉnh" }),
    ).toBeDisabled();
  });

  it("uses backend applicability, half-open periods, and unattributed issuance in the ledger", async () => {
    const api = createReviewRecipeAdjustmentApi("ready");
    const original = api.getOperatorWorkbench;
    vi.spyOn(api, "getOperatorWorkbench").mockImplementation(
      async (...args) => {
        const result = await original(...args);
        if (result.kind !== "success") return result;
        const workbench = result.response.workbench as Record<
          string,
          JsonValue
        >;
        const rows = workbench.operator_rows as Array<
          Record<string, JsonValue>
        >;
        const legacy = rows[0];
        const display = legacy.display_revision as Record<string, JsonValue>;
        legacy.temporal_state = "ACTIVE";
        legacy.is_effective_now = false;
        legacy.display_revision = { ...display, effective_to: "2026-07-10" };
        return result;
      },
    );
    renderWorkbench("rules", api);
    const table = await screen.findByRole("table");
    const legacyRow = within(table)
      .getAllByRole("row")
      .find((row) => row.textContent?.includes("Không có dữ liệu từ OPS v1"));
    expect(legacyRow).toBeDefined();
    expect(legacyRow).toHaveTextContent("Không có trong BOM hiệu lực");
    expect(legacyRow).toHaveTextContent("đến trước 10/07/2026");
    expect(legacyRow).not.toHaveTextContent("27/07/2026");
  });

  it.each(["success", "transport_error"] as const)(
    "keeps a %s mutation locked until exact adjustment and revision evidence is read back",
    async (outcome) => {
      const fixture = createReviewRecipeAdjustmentApi("ready");
      const originalRead = fixture.getOperatorWorkbench;
      let submitted: AtlasRpcRequest | null = null;
      let revealExactEvidence = false;
      const api = {
        ...fixture,
        create: vi.fn(async (request: AtlasRpcRequest) => {
          submitted = request;
          return outcome === "success"
            ? ({
                kind: "success" as const,
                response: {
                  success: true as const,
                  safe_operator_message: "Đã ghi nhận.",
                },
              } as const)
            : ({
                kind: "transport_error" as const,
                diagnostic: {
                  code: "NETWORK_ERROR" as const,
                  safeMessage: "Chưa xác định kết quả.",
                },
              } as const);
        }),
        async getOperatorWorkbench(
          ...args: Parameters<typeof fixture.getOperatorWorkbench>
        ) {
          const result = await originalRead(...args);
          if (!revealExactEvidence || !submitted || result.kind !== "success")
            return result;
          const workbench = result.response.workbench as Record<
            string,
            JsonValue
          >;
          const rows = workbench.operator_rows as Array<
            Record<string, JsonValue>
          >;
          const payload = submitted.payload as Record<string, JsonValue>;
          const template = structuredClone(rows[0]);
          const revision = structuredClone(
            template.display_revision as Record<string, JsonValue>,
          );
          revision.revision_id = String(payload.revision_id);
          revision.predecessor_revision_id = null;
          template.adjustment_id = String(payload.adjustment_id);
          template.current_revision_id = String(payload.revision_id);
          template.current_revision_number = 1;
          template.display_revision = revision;
          template.content_revision = structuredClone(revision);
          const { revision_status: _status, ...historyRevision } = revision;
          const {
            issued_at: _at,
            issuance_kind: _kind,
            issued_by_actor_name: _actor,
            ...commandRevision
          } = historyRevision;
          template.command_revision = commandRevision;
          template.history = [
            { ...historyRevision, business_event_kind: "CREATED" },
          ];
          rows.push(template);
          return result;
        },
      };
      renderWorkbench("rules", api as typeof fixture);
      const dialog = await openCreateDialog();
      await selectSchoolDishTarget(dialog, fixtureIds.porkLine);
      fireEvent.change(within(dialog).getByLabelText("Thay bằng"), {
        target: { value: fixtureIds.potato },
      });
      fireEvent.change(within(dialog).getByLabelText("Lý do"), {
        target: { value: "Kiểm tra đối soát đúng định danh." },
      });
      const previewButton = within(dialog).getByRole("button", {
        name: "Xem ảnh hưởng",
      });
      await waitFor(() => expect(previewButton).toBeEnabled());
      fireEvent.click(previewButton);
      const review = await screen.findByRole("dialog", {
        name: "Thay đổi dự kiến",
      });
      fireEvent.click(
        within(review).getByRole("button", { name: "Lưu điều chỉnh" }),
      );

      const lock = await within(review).findByRole("alert");
      expect(lock).toHaveTextContent(/Không gửi lại thao tác/i);
      expect(within(review).getByText("Đang xác minh")).toBeInTheDocument();
      expect(within(review).queryByText("Có thể lưu")).not.toBeInTheDocument();
      fireEvent.click(
        within(lock).getByRole("button", { name: "Tải lại dữ liệu" }),
      );
      await waitFor(() =>
        expect(within(review).getByRole("alert")).toBeInTheDocument(),
      );

      revealExactEvidence = true;
      fireEvent.click(
        within(lock).getByRole("button", {
          name: "Tải lại dữ liệu",
        }),
      );
      await waitFor(() =>
        expect(screen.queryByRole("alert")).not.toBeInTheDocument(),
      );
      await waitFor(() =>
        expect(
          screen.queryByRole("dialog", { name: "Thay đổi dự kiến" }),
        ).not.toBeInTheDocument(),
      );
    },
  );

  it("keeps unknown cancellation recovery visible inside the active dialog", async () => {
    const fixture = createReviewRecipeAdjustmentApi("ready");
    const getWorkbench = vi.spyOn(fixture, "getOperatorWorkbench");
    const api = {
      ...fixture,
      cancel: vi.fn(async () => ({
        kind: "transport_error" as const,
        diagnostic: {
          code: "NETWORK_FAILURE" as const,
          safeMessage: "Chưa xác định kết quả.",
        },
      })),
    };
    renderWorkbench("rules", api as typeof fixture);
    fireEvent.click((await screen.findAllByRole("button", { name: "Xem" }))[1]);
    const drawer = await screen.findByRole("dialog", {
      name: "Chi tiết điều chỉnh",
    });
    fireEvent.click(
      within(drawer).getByRole("button", { name: "Hủy điều chỉnh" }),
    );
    const dialog = await screen.findByRole("dialog", {
      name: "Hủy điều chỉnh",
    });
    fireEvent.change(within(dialog).getByLabelText("Lý do"), {
      target: { value: "Dừng áp dụng nhưng chưa rõ kết quả ghi nhận." },
    });
    fireEvent.click(
      within(dialog).getByRole("button", { name: "Xác nhận hủy" }),
    );

    const lock = await within(dialog).findByRole("alert");
    expect(lock).toHaveTextContent(/Không gửi lại thao tác/i);
    expect(
      within(dialog).getByRole("button", { name: "Xác nhận hủy" }),
    ).toBeDisabled();
    const readsBeforeRecovery = getWorkbench.mock.calls.length;
    fireEvent.click(
      within(lock).getByRole("button", { name: "Tải lại dữ liệu" }),
    );
    await waitFor(() =>
      expect(getWorkbench.mock.calls.length).toBeGreaterThan(
        readsBeforeRecovery,
      ),
    );
    expect(within(dialog).getByRole("alert")).toBeInTheDocument();
  });

  it.each(["create", "cancel"] as const)(
    "keeps a delayed %s bound to its original account across session expiry",
    async (command) => {
      const fixture = createReviewRecipeAdjustmentApi("ready");
      const originalCommand = fixture[command];
      let settle: (() => void) | undefined;
      const mutation = vi.fn(
        async (request: Parameters<typeof originalCommand>[0]) => {
          const result = await originalCommand(request);
          return new Promise<AtlasRpcResult>((resolve) => {
            settle = () => resolve(result);
          });
        },
      );
      const reads = vi.fn(fixture.getOperatorWorkbench);
      const api = {
        ...fixture,
        [command]: mutation,
        getOperatorWorkbench: reads,
      };
      const authenticated = (subject: string): AtlasAuthState => {
        const state = createReviewAuthState("ready");
        if (state.status !== "authenticated")
          throw new Error("Expected authenticated fixture");
        return { ...state, authSubject: subject };
      };
      const element = (authState: AtlasAuthState) => (
        <MantineProvider theme={atlasTheme}>
          <RecipeAdjustmentWorkbench
            authState={authState}
            api={api}
            view="rules"
            mode="review"
          />
        </MantineProvider>
      );
      const view = render(element(authenticated("operator-a")));
      if (command === "create") {
        const dialog = await openCreateDialog();
        await fillRecipeReplacement(dialog);
        fireEvent.click(
          within(dialog).getByRole("button", { name: "Xem ảnh hưởng" }),
        );
        const review = await screen.findByRole("dialog", {
          name: "Thay đổi dự kiến",
        });
        fireEvent.click(
          within(review).getByRole("button", { name: "Lưu điều chỉnh" }),
        );
      } else {
        fireEvent.click(
          (await screen.findAllByRole("button", { name: "Xem" }))[1],
        );
        const detail = await screen.findByRole("dialog", {
          name: "Chi tiết điều chỉnh",
        });
        fireEvent.click(
          within(detail).getByRole("button", { name: "Hủy điều chỉnh" }),
        );
        const dialog = await screen.findByRole("dialog", {
          name: "Hủy điều chỉnh",
        });
        fireEvent.change(within(dialog).getByLabelText("Lý do"), {
          target: { value: "Hủy theo yêu cầu đã duyệt." },
        });
        fireEvent.click(
          within(dialog).getByRole("button", { name: "Xác nhận hủy" }),
        );
      }
      await waitFor(() => expect(settle).toBeDefined());
      view.rerender(element(createReviewAuthState("session_lost")));
      expect(screen.getByText(/Phiên làm việc đã mất/)).toBeVisible();
      view.rerender(element(authenticated("operator-b")));
      await waitFor(() =>
        expect(
          reads.mock.calls.some(([subject]) => subject === "operator-b"),
        ).toBe(true),
      );
      // B can read the exact committed fixture, but cannot reconcile A's request.
      await waitFor(() =>
        expect(
          screen.getByRole("button", { name: "Tạo điều chỉnh" }),
        ).toBeDisabled(),
      );
      expect(
        await screen.findByText(/thuộc phiên đăng nhập trước/),
      ).toBeVisible();
      expect(
        screen.getByRole("button", { name: "Tải lại dữ liệu" }),
      ).toBeDisabled();
      const countBeforeLateResult = reads.mock.calls.length;
      await act(async () => settle!());
      expect(reads).toHaveBeenCalledTimes(countBeforeLateResult);
      expect(
        screen.getByRole("button", { name: "Tạo điều chỉnh" }),
      ).toBeDisabled();
      view.rerender(element(authenticated("operator-a")));
      await waitFor(() =>
        expect(
          screen.getByRole("button", { name: "Tạo điều chỉnh" }),
        ).toBeEnabled(),
      );
      expect(screen.queryByRole("alert")).not.toBeInTheDocument();
      expect(mutation).toHaveBeenCalledTimes(1);
      expect(mutation.mock.calls[0][0].requested_by_auth_subject).toBe(
        "operator-a",
      );
    },
  );

  it("releases busy state when current-day readback confirms a command before its response arrives", async () => {
    vi.useFakeTimers({ toFake: ["Date"] });
    vi.setSystemTime(new Date("2026-09-06T16:59:00.000Z"));
    const fixture = createReviewRecipeAdjustmentApi("ready");
    let settle: (() => void) | undefined;
    const api = {
      ...fixture,
      create: vi.fn(async (request: Parameters<typeof fixture.create>[0]) => {
        const result = await fixture.create(request);
        return new Promise<AtlasRpcResult>((resolve) => {
          settle = () => resolve(result);
        });
      }),
    };
    renderWorkbench("rules", api);
    const dialog = await openCreateDialog();
    await fillRecipeReplacement(dialog);
    fireEvent.click(
      within(dialog).getByRole("button", { name: "Xem ảnh hưởng" }),
    );
    const review = await screen.findByRole("dialog", {
      name: "Thay đổi dự kiến",
    });
    fireEvent.click(
      within(review).getByRole("button", { name: "Lưu điều chỉnh" }),
    );
    await waitFor(() => expect(settle).toBeDefined());
    vi.setSystemTime(new Date("2026-09-06T17:01:00.000Z"));
    fireEvent.focus(window);
    await waitFor(() =>
      expect(
        screen.getByRole("button", { name: "Tạo điều chỉnh" }),
      ).toBeEnabled(),
    );
    await act(async () => settle!());
    expect(screen.queryByRole("alert")).not.toBeInTheDocument();
    expect(api.create).toHaveBeenCalledOnce();
  });

  it("invalidates adjustment authoring while a new account read is pending or denied", async () => {
    const fixture = createReviewRecipeAdjustmentApi("ready");
    const operatorA = createReviewAuthState("ready");
    if (operatorA.status !== "authenticated")
      throw new Error("Expected authenticated fixture");
    let deny: ((result: AtlasRpcResult) => void) | undefined;
    const create = vi.fn(fixture.create);
    const api = {
      ...fixture,
      create,
      getOperatorWorkbench: vi.fn(
        (...args: Parameters<typeof fixture.getOperatorWorkbench>) =>
          args[0] === "operator-b"
            ? new Promise<AtlasRpcResult>((resolve) => {
                deny = resolve;
              })
            : fixture.getOperatorWorkbench(...args),
      ),
    };
    const element = (authState: AtlasAuthState) => (
      <MantineProvider theme={atlasTheme}>
        <RecipeAdjustmentWorkbench
          authState={authState}
          api={api}
          view="rules"
          mode="review"
        />
      </MantineProvider>
    );
    const view = render(element(operatorA));
    const dialog = await openCreateDialog();
    await fillRecipeReplacement(dialog);
    fireEvent.click(
      within(dialog).getByRole("button", { name: "Xem ảnh hưởng" }),
    );
    await screen.findByRole("dialog", { name: "Thay đổi dự kiến" });
    view.rerender(element({ ...operatorA, authSubject: "operator-b" }));
    // A closing Mantine portal can still exist during its exit transition.
    const staleSave = screen.queryByRole("button", { name: "Lưu điều chỉnh" });
    if (staleSave) fireEvent.click(staleSave);
    expect(create).not.toHaveBeenCalled();
    await waitFor(() =>
      expect(
        screen.queryByRole("dialog", { name: "Thay đổi dự kiến" }),
      ).not.toBeInTheDocument(),
    );
    expect(
      screen.getByRole("button", { name: "Tạo điều chỉnh" }),
    ).toBeDisabled();
    await act(async () =>
      deny!({
        kind: "backend_error",
        error: {
          success: false,
          error_code: "FORBIDDEN",
          safe_message: "Không được đọc điều chỉnh.",
        },
      }),
    );
    expect(await screen.findByText(/Không được đọc điều chỉnh/)).toBeVisible();
    expect(
      screen.getByRole("button", { name: "Tạo điều chỉnh" }),
    ).toBeDisabled();
    expect(
      screen.queryByRole("button", { name: "Xem" }),
    ).not.toBeInTheDocument();
    expect(create).not.toHaveBeenCalled();
  });

  it.each(["mismatched echo", "day changed"] as const)(
    "rejects stale current-ledger authority when the %s",
    async (scenario) => {
      vi.useFakeTimers({ toFake: ["Date"] });
      vi.setSystemTime(new Date("2026-09-06T16:59:00.000Z"));
      const fixture = createReviewRecipeAdjustmentApi("ready");
      let settle: (() => void) | undefined;
      const api = {
        ...fixture,
        getOperatorWorkbench: vi.fn(
          async (...args: Parameters<typeof fixture.getOperatorWorkbench>) => {
            const result = await fixture.getOperatorWorkbench(...args);
            if (result.kind !== "success") throw new Error("Expected fixture");
            const workbench = result.response.workbench as Record<
              string,
              JsonValue
            >;
            if (scenario === "mismatched echo")
              workbench.reference_date = "2026-09-05";
            return new Promise<AtlasRpcResult>((resolve) => {
              settle = () => resolve(result);
            });
          },
        ),
      };
      renderWorkbench("rules", api);
      await waitFor(() => expect(settle).toBeDefined());
      if (scenario === "day changed")
        vi.setSystemTime(new Date("2026-09-06T17:01:00.000Z"));
      await act(async () => settle!());
      expect(
        await screen.findByText(/Dữ liệu tham chiếu điều chỉnh không hợp lệ/),
      ).toBeVisible();
      expect(
        screen.getByRole("button", { name: "Tạo điều chỉnh" }),
      ).toBeDisabled();
      expect(
        screen.queryByRole("button", { name: "Xem" }),
      ).not.toBeInTheDocument();
      expect(api.getOperatorWorkbench).toHaveBeenCalledWith(
        expect.any(String),
        expect.any(String),
        "2026-09-06",
      );
    },
  );

  it("derives the current Vietnam ledger date without a routine date input and preserves business dates", async () => {
    vi.useFakeTimers({ toFake: ["Date"] });
    vi.setSystemTime(new Date("2026-09-06T18:15:00.000Z"));
    const api = createReviewRecipeAdjustmentApi("ready");
    const read = vi.spyOn(api, "getOperatorWorkbench");
    renderWorkbench("rules", api);
    await screen.findByRole("table");
    expect(read).toHaveBeenCalledWith(
      expect.any(String),
      expect.any(String),
      "2026-09-07",
    );
    expect(screen.queryByLabelText("Ngày tham chiếu")).not.toBeInTheDocument();
    expect(
      screen.queryByText(/Trạng thái được tính tại ngày tham chiếu/),
    ).not.toBeInTheDocument();
    expect(screen.queryByLabelText("Xem tại ngày")).not.toBeInTheDocument();
    const dialog = await openCreateDialog();
    await fillRecipeReplacement(dialog);
    expect(within(dialog).getByLabelText("Hiệu lực từ")).toBeVisible();
    expect(within(dialog).getByLabelText("Hiệu lực đến")).toBeVisible();
    expect(screen.getByText("Ngày ban hành")).toBeInTheDocument();
  });

  it.each([
    {
      label: "Món",
      object: "Công thức của một món",
      authority: "Tất cả trường",
    },
    { label: "Món", object: "Công thức của một món", authority: "Một trường" },
    {
      label: "Món đại diện",
      object: "Một nguyên liệu",
      authority: "Tất cả trường",
    },
    {
      label: "Món dùng để xem",
      object: "Một nguyên liệu",
      authority: "Một trường",
    },
  ])(
    "filters $label by Dish name for $object / $authority",
    async ({ label, object, authority }) => {
      const api = createReviewRecipeAdjustmentApi("ready");
      const getWorkbench = api.getOperatorWorkbench;
      vi.spyOn(api, "getOperatorWorkbench").mockImplementation(
        async (...args) => {
          const result = await getWorkbench(...args);
          if (result.kind !== "success")
            throw new Error("Expected fixture workbench");
          const workbench = result.response.workbench as Record<
            string,
            JsonValue
          >;
          workbench.dishes = [
            ...(workbench.dishes as JsonValue[]),
            ...Array.from({ length: 300 }, (_, index) => ({
              dish_id: `23000000-0000-4000-8000-${String(index).padStart(12, "0")}`,
              dish_name: `Món thử ${index}`,
              dish_code: `dish-23000000-0000-4000-8000-${String(index).padStart(12, "0")}`,
            })),
          ];
          return result;
        },
      );
      renderWorkbench("rules", api);
      const dialog = await openCreateDialog();
      if (object !== "Công thức của một món")
        fireEvent.click(within(dialog).getByLabelText(object));
      if (authority !== "Tất cả trường")
        fireEvent.click(within(dialog).getByLabelText(authority));
      if (object === "Một nguyên liệu")
        selectAction(dialog, "Thay nguyên liệu");
      const picker = within(dialog).getByRole("combobox", {
        name: label,
      });
      fireEvent.click(picker);
      fireEvent.change(picker, { target: { value: "bí đỏ" } });
      const options = within(screen.getByRole("listbox")).getAllByRole(
        "option",
      );
      expect(options).toHaveLength(1);
      expect(options[0]).toHaveTextContent("Canh bí đỏ");
      expect(options[0]).not.toHaveTextContent(/dish-|13000000/);
      fireEvent.click(options[0]);
      expect(picker).toHaveValue("Canh bí đỏ");
    },
  );

  it.each([true, false])(
    "connected quantity Save requires a current preview with can_save=%s",
    async (canSave) => {
      vi.useFakeTimers({ toFake: ["Date"] });
      vi.setSystemTime(new Date("2026-09-04T07:00:01.000Z"));
      const fixture = createReviewRecipeAdjustmentApi("ready");
      const writes: AtlasRpcRequest[] = [];
      // Replace only the external RPC transport; use the connected API and UI.
      const api = createRecipeAdjustmentApi({
        async invoke(name, request) {
          if (name === "atlas_api.get_recipe_adjustment_operator_workbench")
            return fixture.getOperatorWorkbench(
              String(request.requested_by_auth_subject),
              String(request.correlation_id),
              "2026-09-04",
            );
          if (name === "atlas_api.get_recipe_effective_target_context")
            return fixture.getEffectiveTargetContext(
              String(request.requested_by_auth_subject),
              String(request.correlation_id),
              String((request.payload as Record<string, JsonValue>).as_of_date),
              String((request.payload as Record<string, JsonValue>).dish_id),
              {
                kind: "school",
                schoolId: String(
                  (request.payload as Record<string, JsonValue>).school_id,
                ),
              },
            );
          if (name === "atlas_api.preview_recipe_composition_adjustment") {
            const result = await fixture.preview(
              String(request.requested_by_auth_subject),
              String(request.correlation_id),
              request.payload as Record<string, JsonValue>,
            );
            if (result.kind !== "success")
              throw new Error("Fixture preview failed");
            return {
              ...result,
              response: {
                ...result.response,
                preview: {
                  ...(result.response.preview as Record<string, JsonValue>),
                  can_save: canSave,
                },
              },
            };
          }
          if (name === "atlas_api.create_recipe_composition_adjustment") {
            writes.push(request);
            return { kind: "success", response: { success: true } };
          }
          throw new Error(`Unexpected RPC: ${name}`);
        },
      });
      renderWorkbench("rules", api, "connected");
      const dialog = await openCreateDialog();
      await selectSchoolRecipeContext(dialog, "Đổi định lượng");
      fireEvent.change(
        within(dialog).getByLabelText("Nguyên liệu trong công thức"),
        {
          target: { value: fixtureIds.porkLine },
        },
      );
      fireEvent.change(within(dialog).getByLabelText("Định lượng mới"), {
        target: { value: "7.5" },
      });
      fireEvent.change(within(dialog).getByLabelText("Lý do"), {
        target: { value: "Kiểm tra lưu điều chỉnh." },
      });
      expect(
        within(dialog).queryByRole("button", { name: "Lưu điều chỉnh" }),
      ).not.toBeInTheDocument();
      fireEvent.click(
        within(dialog).getByRole("button", { name: "Xem ảnh hưởng" }),
      );
      const review = await screen.findByRole("dialog", {
        name: "Thay đổi dự kiến",
      });
      expect(writes).toHaveLength(0);
      const save = within(review).getByRole("button", {
        name: "Lưu điều chỉnh",
      });
      if (!canSave) {
        expect(save).toBeDisabled();
        fireEvent.click(save);
        expect(writes).toHaveLength(0);
        return;
      }
      expect(save).toBeEnabled();
      fireEvent.click(save);
      await waitFor(() => expect(writes).toHaveLength(1));
      expect(writes[0]).toMatchObject({
        requested_at: "2026-09-04T07:00:01.000Z",
        expected_version: 1,
        payload: {
          dish_id: fixtureIds.dish,
          preview_dish_id: fixtureIds.dish,
          scope_kind: "SCHOOL_DISH",
          action_kind: "ADJUST_QUANTITY",
          quantity_per_basis: 7.5,
        },
      });
      expect(
        await screen.findByText(/chưa đọc lại được đúng phiên bản/i),
      ).toBeInTheDocument();
    },
  );

  it("uses the Vietnam-local calendar date shortly after local midnight", () => {
    const shortlyAfterMidnightInVietnam = new Date("2026-08-13T17:05:00.000Z");

    expect(shortlyAfterMidnightInVietnam.toISOString().slice(0, 10)).toBe(
      "2026-08-13",
    );
    expect(vietnamLocalDate(shortlyAfterMidnightInVietnam)).toBe("2026-08-14");
  });

  it("renders a table-first human-language list with search and backend-shaped status", async () => {
    renderWorkbench();

    expect(await screen.findByText("ĐIỀU CHỈNH CÔNG THỨC")).toBeInTheDocument();
    const table = screen.getByRole("table");
    for (const header of [
      "Trạng thái",
      "Món / phạm vi ảnh hưởng",
      "Loại thay đổi",
      "Nội dung thay đổi",
      "Hiệu lực",
      "Ngày ban hành",
      "Người ban hành",
      "Xem",
    ])
      expect(
        within(table).getByRole("columnheader", { name: header }),
      ).toBeInTheDocument();

    for (const label of [
      "Thay nguyên liệu",
      "Đổi định lượng",
      "Thêm nguyên liệu",
      "Bỏ nguyên liệu",
      "Mọi món có nguyên liệu này",
      "Một món tại các trường",
      "Mọi món của một trường",
      "Một món của một trường",
    ])
      expect(screen.getAllByText(new RegExp(label)).length).toBeGreaterThan(0);

    expect(screen.getByText(/Đang hiệu lực · thay đổi từ/)).toBeInTheDocument();
    const legacyRow = within(table)
      .getAllByRole("row")
      .find(
        (row) =>
          within(row).queryAllByText("Không có dữ liệu từ OPS v1").length === 2,
      );
    expect(legacyRow).toBeDefined();

    const cancelledRows = within(table)
      .getAllByRole("row")
      .filter((row) => row.textContent?.includes("Đã hủy"));
    expect(
      cancelledRows.some((row) => row.textContent?.includes("Bí đỏ → Cà rốt")),
    ).toBe(true);
    expect(
      cancelledRows.some((row) => row.textContent?.includes("12,5 Kilôgam")),
    ).toBe(true);

    const beforeSearch = within(table).getAllByRole("row").length;
    fireEvent.change(
      screen.getByPlaceholderText("Tìm món, trường hoặc nguyên liệu..."),
      {
        target: { value: "Minh Khai" },
      },
    );
    expect(within(table).getAllByRole("row").length).toBeLessThan(beforeSearch);

    const normalText = document.body.textContent ?? "";
    expect(normalText).not.toMatch(
      /Revision|predecessor|successor|ACTIVE|SUPERSEDED|CANCELLED|Tạo bản kế nhiệm|Phiên bản kế nhiệm/i,
    );
    expect(normalText).not.toMatch(
      /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i,
    );
  });

  it("orders the accessible decision tree by object, authority, target, action, then payload", async () => {
    renderWorkbench();
    const dialog = await openCreateDialog();

    const objectHeading = within(dialog).getByRole("heading", {
      level: 3,
      name: "Đối tượng điều chỉnh",
    });
    const authorityHeading = within(dialog).getByRole("heading", {
      level: 3,
      name: "Phạm vi áp dụng",
    });
    const actionHeading = within(dialog).getByRole("heading", {
      level: 3,
      name: "Loại thay đổi",
    });
    const targetHeading = within(dialog).getByRole("heading", {
      level: 3,
      name: "Mục tiêu điều chỉnh",
    });
    expect(
      objectHeading.compareDocumentPosition(authorityHeading) &
        Node.DOCUMENT_POSITION_FOLLOWING,
    ).toBeTruthy();
    expect(
      authorityHeading.compareDocumentPosition(targetHeading) &
        Node.DOCUMENT_POSITION_FOLLOWING,
    ).toBeTruthy();
    expect(
      targetHeading.compareDocumentPosition(actionHeading) &
        Node.DOCUMENT_POSITION_FOLLOWING,
    ).toBeTruthy();
    expect(
      within(dialog).getByRole("radiogroup", {
        name: "Bạn muốn điều chỉnh gì?",
      }),
    ).toBeInTheDocument();
    expect(
      within(dialog).getByLabelText("Công thức của một món"),
    ).toBeChecked();
    expect(within(dialog).getByLabelText("Tất cả trường")).toBeChecked();
    expect(
      within(dialog).queryByRole("heading", {
        level: 3,
        name: "Nội dung điều chỉnh",
      }),
    ).not.toBeInTheDocument();

    selectAction(dialog, "Thêm nguyên liệu");
    expect(
      within(dialog).getByLabelText("Nguyên liệu thêm"),
    ).toBeInTheDocument();
    expect(within(dialog).getByLabelText("Định lượng")).toBeInTheDocument();
    expect(within(dialog).getByLabelText("Đơn vị")).toHaveAttribute("readonly");
    expect(
      within(dialog).queryByRole("combobox", { name: "Đơn vị" }),
    ).not.toBeInTheDocument();
    expect(
      within(dialog).queryByLabelText("Thay bằng"),
    ).not.toBeInTheDocument();
  });

  it("derives the ADD Unit from the selected Ingredient and carries it in the proposal", async () => {
    const { api } = renderWorkbench();
    const preview = vi.spyOn(api, "preview");
    const dialog = await openCreateDialog();
    await selectSchoolRecipeContext(dialog, "Thêm nguyên liệu");
    fireEvent.change(within(dialog).getByLabelText("Nguyên liệu thêm"), {
      target: { value: fixtureIds.potato },
    });

    const unit = within(dialog).getByLabelText("Đơn vị");
    expect(unit).toHaveAttribute("readonly");
    expect(unit).toHaveValue("Kilôgam");
    expect(
      within(dialog).queryByRole("combobox", { name: "Đơn vị" }),
    ).not.toBeInTheDocument();

    fireEvent.change(within(dialog).getByLabelText("Định lượng"), {
      target: { value: "0.5" },
    });
    fireEvent.change(within(dialog).getByLabelText("Lý do"), {
      target: { value: "Bổ sung nguyên liệu theo thực đơn." },
    });
    fireEvent.click(
      within(dialog).getByRole("button", { name: "Xem ảnh hưởng" }),
    );

    await screen.findByRole("dialog", { name: "Thay đổi dự kiến" });
    expect(preview.mock.calls[0][2].proposed_adjustment).toMatchObject({
      action_kind: "ADD",
      target_ingredient_id: fixtureIds.potato,
      quantity_per_basis: 0.5,
      unit_id: fixtureIds.kilogram,
    });
  });

  it("keeps a generated SYSTEM_DISH ADD line stable through system Preview and Create", async () => {
    const { api } = renderWorkbench();
    const preview = vi.spyOn(api, "preview");
    const create = vi.spyOn(api, "create");
    const dialog = await openCreateDialog();
    selectRecipeTarget(dialog);
    selectAction(dialog, "Thêm nguyên liệu");
    fireEvent.change(within(dialog).getByLabelText("Nguyên liệu thêm"), {
      target: { value: fixtureIds.potato },
    });
    fireEvent.change(within(dialog).getByLabelText("Định lượng"), {
      target: { value: "0.5" },
    });
    fireEvent.change(within(dialog).getByLabelText("Lý do"), {
      target: { value: "Thêm nguyên liệu cho đúng loại công thức." },
    });
    const previewButton = within(dialog).getByRole("button", {
      name: "Xem ảnh hưởng",
    });
    await waitFor(() => expect(previewButton).toBeEnabled());
    fireEvent.click(previewButton);
    const review = await screen.findByRole("dialog", {
      name: "Thay đổi dự kiến",
    });
    const proposed = preview.mock.calls[0][2].proposed_adjustment as Record<
      string,
      JsonValue
    >;
    expect(preview.mock.calls[0][2]).toMatchObject({
      dish_id: fixtureIds.dish,
      school_type_id: fixtureIds.schoolType,
    });
    expect(preview.mock.calls[0][2]).not.toHaveProperty("school_id");
    expect(proposed).toMatchObject({
      action_kind: "ADD",
      target_ingredient_id: fixtureIds.potato,
      quantity_per_basis: 0.5,
      unit_id: fixtureIds.kilogram,
      adjustment_line_id: expect.any(String),
    });
    fireEvent.click(
      within(review).getByRole("button", { name: "Lưu điều chỉnh" }),
    );
    await waitFor(() => expect(create).toHaveBeenCalledOnce());
    expect(create.mock.calls[0][0].payload).toMatchObject({
      adjustment_line_id: proposed.adjustment_line_id,
      preview_dish_id: fixtureIds.dish,
      preview_school_type_id: fixtureIds.schoolType,
    });
    expect(create.mock.calls[0][0].payload).not.toHaveProperty(
      "preview_school_id",
    );
  });

  it("blocks SYSTEM_DISH ADD before Preview when the Ingredient has no purchase Unit", async () => {
    const { api } = renderWorkbench();
    const preview = vi.spyOn(api, "preview");
    const dialog = await openCreateDialog();
    selectRecipeTarget(dialog);
    selectAction(dialog, "Thêm nguyên liệu");
    fireEvent.change(within(dialog).getByLabelText("Nguyên liệu thêm"), {
      target: { value: fixtureIds.missingUnitIngredient },
    });
    fireEvent.change(within(dialog).getByLabelText("Định lượng"), {
      target: { value: "1" },
    });
    fireEvent.change(within(dialog).getByLabelText("Lý do"), {
      target: { value: "Không lưu khi thiếu đơn vị mua." },
    });

    expect(within(dialog).getByText(/chưa có đơn vị mua/i)).toBeInTheDocument();
    expect(
      within(dialog).getByRole("button", { name: "Xem ảnh hưởng" }),
    ).toBeDisabled();
    expect(preview).not.toHaveBeenCalled();
  });

  it("blocks ADD preview safely when the Ingredient has no purchase Unit", async () => {
    renderWorkbench();
    const dialog = await openCreateDialog();
    await selectSchoolRecipeContext(dialog, "Thêm nguyên liệu");
    fireEvent.change(within(dialog).getByLabelText("Nguyên liệu thêm"), {
      target: { value: fixtureIds.missingUnitIngredient },
    });
    fireEvent.change(within(dialog).getByLabelText("Định lượng"), {
      target: { value: "1" },
    });
    fireEvent.change(within(dialog).getByLabelText("Lý do"), {
      target: { value: "Kiểm tra dữ liệu nguyên liệu thiếu đơn vị." },
    });

    expect(
      within(dialog).getByText(
        "Nguyên liệu đã chọn chưa có đơn vị mua. Hãy cập nhật danh mục nguyên liệu trước khi xem ảnh hưởng.",
      ),
    ).toBeInTheDocument();
    expect(
      within(dialog).getByRole("button", { name: "Xem ảnh hưởng" }),
    ).toBeDisabled();
  });

  it("preserves the target Recipe-line Unit for quantity adjustment and sends null unit_id", async () => {
    const { api } = renderWorkbench();
    const preview = vi.spyOn(api, "preview");
    const dialog = await openCreateDialog();
    await selectSchoolRecipeContext(dialog, "Đổi định lượng");
    fireEvent.change(
      within(dialog).getByLabelText("Nguyên liệu trong công thức"),
      { target: { value: fixtureIds.porkLine } },
    );

    const unit = within(dialog).getByLabelText("Đơn vị");
    expect(unit).toHaveAttribute("readonly");
    expect(unit).toHaveValue("Kilôgam");
    expect(unit).not.toHaveValue("Gam");
    fireEvent.change(within(dialog).getByLabelText("Định lượng mới"), {
      target: { value: "7.5" },
    });
    fireEvent.change(within(dialog).getByLabelText("Lý do"), {
      target: { value: "Điều chỉnh theo định lượng công thức." },
    });
    fireEvent.click(
      within(dialog).getByRole("button", { name: "Xem ảnh hưởng" }),
    );

    await screen.findByRole("dialog", { name: "Thay đổi dự kiến" });
    expect(preview.mock.calls[0][2].proposed_adjustment).toMatchObject({
      action_kind: "ADJUST_QUANTITY",
      target_recipe_line_id: fixtureIds.porkLine,
      adjustment_line_id: null,
      quantity_per_basis: 7.5,
      unit_id: null,
    });
  });

  it("shows no Unit decision for REPLACE until quantity override derives the substitute Unit", async () => {
    const { api } = renderWorkbench();
    const preview = vi.spyOn(api, "preview");
    const dialog = await openCreateDialog();
    await fillRecipeReplacement(dialog);
    expect(within(dialog).queryByLabelText("Đơn vị")).not.toBeInTheDocument();

    fireEvent.click(within(dialog).getByLabelText("Đổi cả định lượng"));
    const unit = within(dialog).getByLabelText("Đơn vị");
    expect(unit).toHaveAttribute("readonly");
    expect(unit).toHaveValue("Kilôgam");
    expect(
      within(dialog).queryByRole("combobox", { name: "Đơn vị" }),
    ).not.toBeInTheDocument();
    fireEvent.change(within(dialog).getByLabelText("Định lượng mới"), {
      target: { value: "10" },
    });
    fireEvent.click(
      within(dialog).getByRole("button", { name: "Xem ảnh hưởng" }),
    );

    await screen.findByRole("dialog", { name: "Thay đổi dự kiến" });
    expect(preview.mock.calls[0][2].proposed_adjustment).toMatchObject({
      action_kind: "REPLACE",
      substitute_ingredient_id: fixtureIds.potato,
      quantity_per_basis: 10,
      unit_id: fixtureIds.kilogram,
    });
  });

  it.each([1280, 650])(
    "keeps the 1000px modal bounded without horizontal overflow at %ipx",
    async (viewportWidth) => {
      Object.defineProperty(window, "innerWidth", {
        configurable: true,
        value: viewportWidth,
      });
      renderWorkbench();
      const dialog = await openCreateDialog();
      const root = dialog.closest<HTMLElement>("[data-centered]");
      const body = dialog.querySelector<HTMLElement>(".mantine-Modal-body");

      expect(root?.style.getPropertyValue("--modal-size")).toBe(
        "calc(62.5rem * var(--mantine-scale))",
      );
      expect(root?.style.getPropertyValue("--modal-x-offset")).toBe(
        "calc(1.25rem * var(--mantine-scale))",
      );
      expect(dialog).toHaveStyle({ maxHeight: "86dvh", overflowX: "hidden" });
      expect(body).toHaveStyle({
        maxHeight: "calc(86dvh - 64px)",
        overflowX: "hidden",
      });
      expect(document.documentElement.scrollWidth).toBeLessThanOrEqual(
        viewportWidth,
      );
    },
  );

  it("requires and carries one explicit Recipe Type for Recipe + all schools", async () => {
    const { api } = renderWorkbench();
    const preview = vi.spyOn(api, "preview");
    const dialog = await openCreateDialog();

    expect(within(dialog).getByLabelText("Món")).toHaveValue("");
    const recipeType = within(dialog).getByRole("combobox", {
      name: /Loại công thức/,
    });
    expect(recipeType).toBeRequired();
    expect(recipeType).toHaveValue("");
    expect(
      within(recipeType)
        .getAllByRole("option")
        .map((option) => option.textContent),
    ).toEqual(["Chọn loại công thức", "TIỂU HỌC", "TRUNG HỌC"]);
    expect(dialog.textContent).not.toMatch(
      /Không bắt buộc|Tất cả loại trường|Cả hai loại trường/,
    );
    expect(
      within(dialog).getByRole("button", { name: "Xem ảnh hưởng" }),
    ).toBeDisabled();

    selectRecipeTarget(dialog);
    selectAction(dialog, "Thay nguyên liệu");
    await waitFor(() =>
      expect(
        within(dialog).getByRole("option", { name: /Cà rốt · 22/ }),
      ).toBeInTheDocument(),
    );
    expect(within(dialog).queryByLabelText("Trường dùng để xem")).toBeNull();
    expect(
      within(dialog).queryByText(/chưa hỗ trợ xem và lưu điều chỉnh/i),
    ).not.toBeInTheDocument();
    expect(
      within(dialog).getByRole("button", { name: "Xem ảnh hưởng" }),
    ).toBeDisabled();
    expect(preview).not.toHaveBeenCalled();
  });

  it("reloads exact system targets when Recipe Type changes without a School proxy", async () => {
    const { api } = renderWorkbench();
    const preview = vi.spyOn(api, "preview");
    const dialog = await openCreateDialog();
    selectRecipeTarget(dialog);
    selectAction(dialog, "Thay nguyên liệu");

    fireEvent.change(
      within(dialog).getByRole("combobox", {
        name: /Loại công thức/,
      }),
      {
        target: { value: fixtureIds.secondarySchoolType },
      },
    );
    await waitFor(() =>
      expect(
        within(within(dialog).getByLabelText("Nguyên liệu trong công thức"))
          .getAllByRole("option")
          .map((option) => option.textContent),
      ).toEqual([
        "Chọn nguyên liệu trong món",
        "Cà rốt · 22 Kilôgam",
        "Thịt heo · 10 Kilôgam",
        "Gia vị thiếu đơn vị · 1,25 Kilôgam",
      ]),
    );
    expect(within(dialog).queryByLabelText("Trường dùng để xem")).toBeNull();
    expect(
      within(dialog).getByRole("button", { name: "Xem ảnh hưởng" }),
    ).toBeDisabled();
    expect(preview).not.toHaveBeenCalled();
  });

  it("derives Recipe Type from one School and prevents cross-type Recipe-line targets", async () => {
    const { api } = renderWorkbench();
    const preview = vi.spyOn(api, "preview");
    const dialog = await openCreateDialog();
    fireEvent.click(within(dialog).getByLabelText("Một trường"));

    expect(
      within(dialog).queryByRole("combobox", { name: "Loại công thức" }),
    ).not.toBeInTheDocument();
    const derivedType = within(dialog).getByLabelText(
      "Loại công thức xác định từ trường",
    );
    expect(within(dialog).getByLabelText("Trường")).toHaveValue("");
    expect(within(dialog).getByLabelText("Món")).toHaveValue("");
    expect(
      within(derivedType).getByText("Chọn trường để xác định"),
    ).toBeInTheDocument();

    fireEvent.change(within(dialog).getByLabelText("Trường"), {
      target: { value: fixtureIds.secondarySchool },
    });
    expect(within(derivedType).getByText("TRUNG HỌC")).toBeInTheDocument();
    expect(within(dialog).getByLabelText("Món")).toHaveValue("");
    selectDish(within(dialog).getByLabelText("Món"));
    selectAction(dialog, "Thay nguyên liệu");
    const recipeLine = within(dialog).getByLabelText(
      "Nguyên liệu trong công thức",
    );
    await waitFor(() => {
      const options = within(recipeLine)
        .getAllByRole("option")
        .map((option) => option.textContent);
      expect(options).toContain("Thịt heo · 10 Kilôgam");
      expect(options).not.toContain("Thịt heo · 8 Kilôgam");
    });

    fireEvent.change(recipeLine, {
      target: { value: fixtureIds.secondaryPorkLine },
    });
    fireEvent.change(within(dialog).getByLabelText("Thay bằng"), {
      target: { value: fixtureIds.potato },
    });
    fireEvent.change(within(dialog).getByLabelText("Lý do"), {
      target: { value: "Điều chỉnh công thức Trung học." },
    });
    fireEvent.click(
      within(dialog).getByRole("button", { name: "Xem ảnh hưởng" }),
    );
    const review = await screen.findByRole("dialog", {
      name: "Thay đổi dự kiến",
    });
    const proposal = preview.mock.calls[0][2].proposed_adjustment as Record<
      string,
      unknown
    >;
    expect(proposal).toMatchObject({
      scope_kind: "SCHOOL_DISH",
      school_id: fixtureIds.secondarySchool,
      school_type_id: null,
      target_recipe_line_id: fixtureIds.secondaryPorkLine,
    });
    expect(
      within(review).getByText("Canh bí đỏ · TRUNG HỌC"),
    ).toBeInTheDocument();
    expect(
      within(review).getByText("Trường Trung học Trần Phú"),
    ).toBeInTheDocument();
    const comparison = within(review).getByRole("table", {
      name: "So sánh công thức trước và sau",
    });
    expect(within(comparison).getAllByText("Cà rốt · 22 Kilôgam")).toHaveLength(
      2,
    );
    expect(
      within(comparison).queryByText(/20 Kilôgam/),
    ).not.toBeInTheDocument();
  });

  it("starts one-School Ingredient targets and representative Dish unset", async () => {
    renderWorkbench();
    const dialog = await openCreateDialog();
    fireEvent.click(within(dialog).getByLabelText("Một nguyên liệu"));
    fireEvent.click(within(dialog).getByLabelText("Một trường"));
    selectAction(dialog, "Thay nguyên liệu");

    expect(within(dialog).getByLabelText("Trường")).toHaveValue("");
    expect(within(dialog).getByLabelText("Nguyên liệu hiện tại")).toHaveValue(
      "",
    );
    expect(within(dialog).getByLabelText("Món dùng để xem")).toHaveValue("");
    expect(
      within(dialog).getByRole("button", { name: "Xem ảnh hưởng" }),
    ).toBeDisabled();
  });

  it("clears dependent Recipe target state when School changes", async () => {
    renderWorkbench();
    const dialog = await openCreateDialog();
    fireEvent.click(within(dialog).getByLabelText("Một trường"));
    selectRecipeTarget(dialog);
    selectAction(dialog, "Thay nguyên liệu");
    fireEvent.change(
      within(dialog).getByLabelText("Nguyên liệu trong công thức"),
      { target: { value: fixtureIds.porkLine } },
    );
    fireEvent.change(within(dialog).getByLabelText("Thay bằng"), {
      target: { value: fixtureIds.potato },
    });

    fireEvent.change(within(dialog).getByLabelText("Trường"), {
      target: { value: fixtureIds.secondarySchool },
    });

    expect(within(dialog).getByLabelText("Món")).toHaveValue("");
    expect(
      within(dialog).getByLabelText("Nguyên liệu trong công thức"),
    ).toHaveValue("");
    expect(within(dialog).getByLabelText("Thay bằng")).toHaveValue("");
    expect(
      within(
        within(dialog).getByLabelText("Loại công thức xác định từ trường"),
      ).getByText("TRUNG HỌC"),
    ).toBeInTheDocument();
    expect(
      within(dialog).getByRole("button", { name: "Xem ảnh hưởng" }),
    ).toBeDisabled();
  });

  it("filters actions by the unchanged RMVP-02B authority matrix", async () => {
    renderWorkbench();
    const dialog = await openCreateDialog();
    const actionGroup = () =>
      within(dialog).getByRole("radiogroup", {
        name: "Bạn muốn thay đổi như thế nào?",
      });
    const actionNames = () =>
      within(actionGroup())
        .getAllByRole("radio")
        .map((radio) => radio.getAttribute("aria-label"));

    expect(actionNames()).toEqual([
      "Thêm nguyên liệu",
      "Thay nguyên liệu",
      "Đổi định lượng",
      "Bỏ nguyên liệu",
    ]);

    fireEvent.click(within(dialog).getByLabelText("Một trường"));
    expect(actionNames()).toEqual([
      "Thêm nguyên liệu",
      "Thay nguyên liệu",
      "Đổi định lượng",
      "Bỏ nguyên liệu",
    ]);

    fireEvent.click(within(dialog).getByLabelText("Một nguyên liệu"));
    expect(actionNames()).toEqual(["Thay nguyên liệu"]);

    fireEvent.click(within(dialog).getByLabelText("Một trường"));
    expect(actionNames()).toEqual(["Thay nguyên liệu", "Bỏ nguyên liệu"]);
    expect(
      within(dialog).queryByLabelText("Thêm nguyên liệu"),
    ).not.toBeInTheDocument();
    expect(
      within(dialog).queryByLabelText("Đổi định lượng"),
    ).not.toBeInTheDocument();
  });

  it.each([
    {
      businessObject: "Công thức của một món",
      authority: "Một trường",
      expectedScope: "SCHOOL_DISH",
    },
    {
      businessObject: "Một nguyên liệu",
      authority: "Tất cả trường",
      expectedScope: "SYSTEM_INGREDIENT",
    },
    {
      businessObject: "Một nguyên liệu",
      authority: "Một trường",
      expectedScope: "SCHOOL",
    },
  ])(
    "maps $businessObject + $authority to $expectedScope without exposing it",
    async ({ businessObject, authority, expectedScope }) => {
      const { api } = renderWorkbench();
      const preview = vi.spyOn(api, "preview");
      const dialog = await openCreateDialog();

      if (businessObject !== "Công thức của một món")
        fireEvent.click(within(dialog).getByLabelText(businessObject));
      if (authority !== "Tất cả trường")
        fireEvent.click(within(dialog).getByLabelText(authority));
      if (businessObject === "Công thức của một món")
        await fillRecipeReplacement(dialog);
      else fillIngredientReplacement(dialog);

      expect(dialog.textContent).not.toContain(expectedScope);
      fireEvent.click(
        within(dialog).getByRole("button", { name: "Xem ảnh hưởng" }),
      );
      await screen.findByRole("dialog", { name: "Thay đổi dự kiến" });
      const request = preview.mock.calls[0][2];
      expect(
        (request.proposed_adjustment as Record<string, unknown>).scope_kind,
      ).toBe(expectedScope);
    },
  );

  it("reviews the exact changed line, preserves quantity, and invalidates preview after editing", async () => {
    const { api } = renderWorkbench();
    const preview = vi.spyOn(api, "preview");
    const create = vi.spyOn(api, "create");
    const dialog = await openCreateDialog();
    await fillRecipeReplacement(dialog);

    expect(
      within(dialog).queryByRole("button", { name: "Lưu điều chỉnh" }),
    ).not.toBeInTheDocument();
    fireEvent.click(
      within(dialog).getByRole("button", { name: "Xem ảnh hưởng" }),
    );
    const review = await screen.findByRole("dialog", {
      name: "Thay đổi dự kiến",
    });
    expect(preview).toHaveBeenCalledOnce();
    const comparison = within(review).getByRole("table", {
      name: "So sánh công thức trước và sau",
    });
    expect(
      within(comparison).getByText("Thịt heo · 8 Kilôgam"),
    ).toBeInTheDocument();
    expect(
      within(comparison).getByText("Khoai tây · 8 Kilôgam"),
    ).toBeInTheDocument();
    expect(
      within(comparison).getAllByText("Khoai tây · 24 Kilôgam"),
    ).toHaveLength(2);
    const changedRow = within(comparison)
      .getAllByRole("row")
      .find((row) => row.textContent?.includes("Thịt heo"));
    expect(changedRow).toBeDefined();
    expect(within(changedRow!).getByLabelText("Có thay đổi")).toHaveTextContent(
      "→",
    );
    const unchangedRow = within(comparison)
      .getAllByRole("row")
      .find((row) => row.textContent?.includes("Khoai tây · 24"));
    expect(unchangedRow).toBeDefined();
    expect(
      within(unchangedRow!).queryByLabelText("Có thay đổi"),
    ).not.toBeInTheDocument();
    expect(
      within(review).queryByRole("button", {
        name: "Xem toàn bộ công thức",
      }),
    ).not.toBeInTheDocument();
    expect(
      within(review).getByRole("button", { name: "Lưu điều chỉnh" }),
    ).toBeEnabled();
    expect(review.textContent).not.toMatch(
      /SYSTEM_|REPLACE|revision|predecessor|successor|[0-9a-f]{8}-[0-9a-f-]{27,}/i,
    );

    fireEvent.click(within(review).getByRole("button", { name: "Quay lại" }));

    const edit = await screen.findByRole("dialog", { name: "Tạo điều chỉnh" });
    expect(
      within(edit).getByLabelText("Nguyên liệu trong công thức"),
    ).toHaveValue(fixtureIds.porkLine);
    expect(within(edit).getByLabelText("Thay bằng")).toHaveValue(
      fixtureIds.potato,
    );
    expect(within(edit).getByLabelText("Lý do")).toHaveValue(
      "Thay theo tiêu chuẩn nguyên liệu đã duyệt.",
    );

    fireEvent.change(within(edit).getByLabelText("Lý do"), {
      target: { value: "Lý do đã được cập nhật sau khi xem ảnh hưởng." },
    });
    expect(
      within(edit).queryByRole("button", { name: "Lưu điều chỉnh" }),
    ).not.toBeInTheDocument();
    fireEvent.click(
      within(edit).getByRole("button", { name: "Xem ảnh hưởng" }),
    );
    await waitFor(() => expect(preview).toHaveBeenCalledTimes(2));
    const refreshedReview = await screen.findByRole("dialog", {
      name: "Thay đổi dự kiến",
    });
    fireEvent.click(
      within(refreshedReview).getByRole("button", {
        name: "Lưu điều chỉnh",
      }),
    );
    await waitFor(() => expect(create).toHaveBeenCalledOnce());
  });

  it("clears stale payload and preview when Business Object or Authority changes", async () => {
    const { api } = renderWorkbench();
    const preview = vi.spyOn(api, "preview");
    const dialog = await openCreateDialog();
    await fillRecipeReplacement(dialog);
    fireEvent.click(
      within(dialog).getByRole("button", { name: "Xem ảnh hưởng" }),
    );
    const review = await screen.findByRole("dialog", {
      name: "Thay đổi dự kiến",
    });
    fireEvent.click(within(review).getByRole("button", { name: "Quay lại" }));
    const edit = await screen.findByRole("dialog", { name: "Tạo điều chỉnh" });

    fireEvent.click(within(edit).getByLabelText("Một nguyên liệu"));
    expect(within(edit).queryByLabelText("Thay bằng")).not.toBeInTheDocument();
    expect(
      within(edit).queryByRole("heading", {
        level: 3,
        name: "Nội dung điều chỉnh",
      }),
    ).not.toBeInTheDocument();
    expect(
      within(edit).queryByRole("button", { name: "Lưu điều chỉnh" }),
    ).not.toBeInTheDocument();

    fireEvent.click(within(edit).getByLabelText("Một trường"));
    selectAction(edit, "Thay nguyên liệu");
    expect(within(edit).getByLabelText("Nguyên liệu hiện tại")).toHaveValue("");
    expect(within(edit).getByLabelText("Thay bằng")).toHaveValue("");
    expect(preview).toHaveBeenCalledOnce();
  });

  it("does not carry Recipe targets across an Authority change", async () => {
    renderWorkbench();
    const dialog = await openCreateDialog();
    await fillRecipeReplacement(dialog);

    fireEvent.click(within(dialog).getByLabelText("Một trường"));

    expect(within(dialog).getByLabelText("Trường")).toHaveValue("");
    expect(within(dialog).getByLabelText("Món")).toHaveValue("");
    expect(
      within(dialog).getByLabelText("Nguyên liệu trong công thức"),
    ).toHaveValue("");
    expect(within(dialog).getByLabelText("Thay bằng")).toHaveValue("");
    expect(
      within(
        within(dialog).getByLabelText("Loại công thức xác định từ trường"),
      ).getByText("Chọn trường để xác định"),
    ).toBeInTheDocument();
    expect(
      within(dialog).getByRole("button", { name: "Xem ảnh hưởng" }),
    ).toBeDisabled();
  });

  it.each([
    {
      action: "Thêm nguyên liệu",
      targetLabel: "Nguyên liệu thêm",
      targetValue: fixtureIds.potato,
      quantity: "0.5",
      before: "—",
      after: "Khoai tây · 0,5 Kilôgam",
    },
    {
      action: "Bỏ nguyên liệu",
      targetLabel: "Nguyên liệu cần bỏ",
      targetValue: fixtureIds.porkLine,
      before: "Thịt heo · 8 Kilôgam",
      after: "Đã bỏ",
    },
    {
      action: "Đổi định lượng",
      targetLabel: "Nguyên liệu trong công thức",
      targetValue: fixtureIds.porkLine,
      quantity: "7.5",
      before: "Thịt heo · 8 Kilôgam",
      after: "Thịt heo · 7,5 Kilôgam",
    },
  ])(
    "aligns the full Recipe for $action",
    async ({ action, targetLabel, targetValue, quantity, before, after }) => {
      renderWorkbench();
      const dialog = await openCreateDialog();
      await selectSchoolRecipeContext(dialog, action);
      fireEvent.change(within(dialog).getByLabelText(targetLabel), {
        target: { value: targetValue },
      });
      if (quantity)
        fireEvent.change(
          within(dialog).getByLabelText(
            action === "Thêm nguyên liệu" ? "Định lượng" : "Định lượng mới",
          ),
          { target: { value: quantity } },
        );
      fireEvent.change(within(dialog).getByLabelText("Lý do"), {
        target: { value: `Kiểm tra ${action.toLocaleLowerCase("vi")}.` },
      });
      fireEvent.click(
        within(dialog).getByRole("button", { name: "Xem ảnh hưởng" }),
      );
      const review = await screen.findByRole("dialog", {
        name: "Thay đổi dự kiến",
      });
      const comparison = within(review).getByRole("table", {
        name: "So sánh công thức trước và sau",
      });
      const alignedRow = within(comparison)
        .getAllByRole("row")
        .find((row) => row.textContent?.includes(after));
      expect(alignedRow).toBeDefined();
      expect(within(alignedRow!).getByText(before)).toBeInTheDocument();
      expect(within(alignedRow!).getByText(after)).toBeInTheDocument();
      expect(
        within(alignedRow!).getByLabelText("Có thay đổi"),
      ).toHaveTextContent("→");
      expect(
        within(comparison).getAllByText("Khoai tây · 24 Kilôgam"),
      ).toHaveLength(2);
    },
  );

  it("explains representative preview context for broad scopes without claiming a global enumeration", async () => {
    renderWorkbench();
    const dialog = await openCreateDialog();
    fireEvent.click(within(dialog).getByLabelText("Một nguyên liệu"));
    selectAction(dialog, "Thay nguyên liệu");
    expect(within(dialog).getByText("Xem ảnh hưởng tại")).toBeInTheDocument();
    expect(
      within(dialog).getByLabelText("Trường đại diện"),
    ).toBeInTheDocument();
    expect(within(dialog).getByLabelText("Món đại diện")).toBeInTheDocument();
    expect(within(dialog).getByLabelText("Nguyên liệu hiện tại")).toHaveValue(
      "",
    );
    expect(within(dialog).getByLabelText("Trường đại diện")).toHaveValue("");
    expect(within(dialog).getByLabelText("Món đại diện")).toHaveValue("");
    expect(
      within(dialog).getByRole("button", { name: "Xem ảnh hưởng" }),
    ).toBeDisabled();
    expect(
      within(dialog).getByText(
        /Đây là bối cảnh dùng để xem trước; phạm vi áp dụng vẫn theo lựa chọn ở trên\./,
      ),
    ).toBeInTheDocument();
    expect(
      within(dialog).queryByText(/tất cả món bị ảnh hưởng/i),
    ).not.toBeInTheDocument();
  });

  it("shows business history in a drawer and corrects through the existing supersede command", async () => {
    const { api } = renderWorkbench();
    const supersede = vi.spyOn(api, "supersede");
    const firstView = (
      await screen.findAllByRole("button", { name: "Xem" })
    )[0];
    fireEvent.click(firstView);
    const drawer = await screen.findByRole("dialog", {
      name: "Chi tiết điều chỉnh",
    });
    expect(within(drawer).getByText("Lịch sử điều chỉnh")).toBeInTheDocument();
    expect(within(drawer).getByText("Tạo điều chỉnh")).toBeInTheDocument();
    expect(
      within(drawer).getAllByText("Không có dữ liệu từ OPS v1").length,
    ).toBeGreaterThan(0);

    fireEvent.click(
      within(drawer).getByRole("button", { name: "Điều chỉnh lại" }),
    );
    const dialog = await screen.findByRole("dialog", {
      name: "Điều chỉnh lại",
    });
    const fixedContext = within(dialog).getByLabelText(
      "Bối cảnh điều chỉnh cố định",
    );
    expect(
      within(fixedContext).getByText("Một nguyên liệu"),
    ).toBeInTheDocument();
    expect(within(fixedContext).getByText("Tất cả trường")).toBeInTheDocument();
    expect(
      within(fixedContext).getByText("Thay nguyên liệu"),
    ).toBeInTheDocument();
    expect(within(dialog).queryByRole("radiogroup")).not.toBeInTheDocument();
    expect(
      within(dialog).getByLabelText("Nguyên liệu hiện tại"),
    ).toBeDisabled();
    expect(
      within(dialog).queryByRole("combobox", { name: "Đơn vị" }),
    ).not.toBeInTheDocument();
    fireEvent.change(within(dialog).getByLabelText("Lý do"), {
      target: { value: "Điều chỉnh theo biên bản vận hành mới." },
    });
    fireEvent.click(
      within(dialog).getByRole("button", { name: "Xem ảnh hưởng" }),
    );
    const review = await screen.findByRole("dialog", {
      name: "Thay đổi dự kiến",
    });
    fireEvent.click(
      within(review).getByRole("button", { name: "Lưu điều chỉnh" }),
    );
    await waitFor(() => expect(supersede).toHaveBeenCalledOnce());
  });

  it("keeps Dish and Recipe Type fixed when correcting a system Recipe adjustment", async () => {
    renderWorkbench();
    const table = await screen.findByRole("table");
    const systemRecipeRow = within(table)
      .getAllByRole("row")
      .find(
        (row) =>
          row.textContent?.includes(
            "Canh bí đỏ · TIỂU HỌC · Một món tại các trường",
          ) && row.textContent?.includes("Thay nguyên liệu"),
      );
    expect(systemRecipeRow).toBeDefined();
    fireEvent.click(
      within(systemRecipeRow!).getByRole("button", { name: "Xem" }),
    );
    const drawer = await screen.findByRole("dialog", {
      name: "Chi tiết điều chỉnh",
    });
    fireEvent.click(
      within(drawer).getByRole("button", { name: "Điều chỉnh lại" }),
    );

    const dialog = await screen.findByRole("dialog", {
      name: "Điều chỉnh lại",
    });
    const fixedContext = within(dialog).getByLabelText(
      "Bối cảnh điều chỉnh cố định",
    );
    expect(
      within(fixedContext).getByText("Canh bí đỏ · TIỂU HỌC"),
    ).toBeInTheDocument();
    expect(within(fixedContext).getByText("Tất cả trường")).toBeInTheDocument();
    expect(within(dialog).getByLabelText("Món")).toBeDisabled();
    expect(within(dialog).getByLabelText("Món")).toHaveValue("Canh bí đỏ");
    expect(
      within(dialog).getByRole("combobox", { name: /Loại công thức/ }),
    ).toBeDisabled();
    expect(
      within(dialog).getByLabelText("Nguyên liệu trong công thức"),
    ).toBeDisabled();
    expect(within(dialog).queryByRole("radiogroup")).not.toBeInTheDocument();
  });

  it("cancels through an application modal without prompt or confirm", async () => {
    const prompt = vi.spyOn(window, "prompt");
    const confirm = vi.spyOn(window, "confirm");
    const { api } = renderWorkbench();
    const cancel = vi.spyOn(api, "cancel");
    fireEvent.click((await screen.findAllByRole("button", { name: "Xem" }))[1]);
    const drawer = await screen.findByRole("dialog", {
      name: "Chi tiết điều chỉnh",
    });
    fireEvent.click(
      within(drawer).getByRole("button", { name: "Hủy điều chỉnh" }),
    );
    const dialog = await screen.findByRole("dialog", {
      name: "Hủy điều chỉnh",
    });
    expect(
      within(dialog).getByText("Lịch sử điều chỉnh được giữ nguyên."),
    ).toBeInTheDocument();
    fireEvent.change(within(dialog).getByLabelText("Lý do"), {
      target: { value: "Dừng áp dụng theo quyết định đã duyệt." },
    });
    fireEvent.click(
      within(dialog).getByRole("button", { name: "Xác nhận hủy" }),
    );
    await waitFor(() => expect(cancel).toHaveBeenCalledOnce());
    expect(prompt).not.toHaveBeenCalled();
    expect(confirm).not.toHaveBeenCalled();
  });

  it("keeps Công thức hiệu lực as a secondary explicit-context read surface", async () => {
    renderWorkbench("effective");
    expect(await screen.findByText("Công thức hiệu lực")).toBeInTheDocument();
    expect(screen.getByLabelText("Xem tại ngày")).not.toHaveValue("");
    expect(screen.getByLabelText("Trường")).toBeInTheDocument();
    expect(screen.getByLabelText("Món")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Xem công thức" }));
    expect(
      await screen.findByText(/Công thức theo loại trường/),
    ).toBeInTheDocument();
    expect(screen.getByText("Chi tiết kỹ thuật")).toBeInTheDocument();
    expect(document.body.textContent).not.toMatch(
      /recipe_version_id|applied_revision_ids|fingerprint/i,
    );
  });

  it("isolates historical inspection dates from the current adjustment ledger", async () => {
    vi.useFakeTimers({ toFake: ["Date"] });
    vi.setSystemTime(new Date("2026-09-06T18:15:00.000Z"));
    const api = createReviewRecipeAdjustmentApi("ready");
    const reads = vi.spyOn(api, "getOperatorWorkbench");
    const resolve = vi.spyOn(api, "resolve");
    const view = renderWorkbench("effective", api);
    const inspect = await screen.findByRole("button", {
      name: "Xem công thức",
    });
    await waitFor(() => expect(inspect).toBeEnabled());
    fireEvent.change(screen.getByLabelText("Xem tại ngày"), {
      target: { value: "2026-07-01" },
    });
    fireEvent.click(inspect);
    await waitFor(() =>
      expect(resolve).toHaveBeenCalledWith(
        expect.any(String),
        expect.any(String),
        expect.objectContaining({ as_of_date: "2026-07-01" }),
      ),
    );
    expect(
      screen.queryByRole("button", { name: "Tạo điều chỉnh" }),
    ).not.toBeInTheDocument();
    view.rerender(
      <MantineProvider theme={atlasTheme}>
        <RecipeAdjustmentWorkbench
          authState={createReviewAuthState("ready")}
          api={api}
          view="rules"
          mode="review"
        />
      </MantineProvider>,
    );
    expect(screen.queryByLabelText("Xem tại ngày")).not.toBeInTheDocument();
    expect(screen.queryByLabelText("Ngày tham chiếu")).not.toBeInTheDocument();
    expect(reads.mock.calls.every((args) => args[2] === "2026-09-07")).toBe(
      true,
    );
    expect(
      await screen.findByRole("button", { name: "Tạo điều chỉnh" }),
    ).toBeEnabled();
  });

  it("refreshes the current ledger with the Vietnam date after the business day changes", async () => {
    vi.useFakeTimers({ toFake: ["Date"] });
    vi.setSystemTime(new Date("2026-09-06T16:59:00.000Z"));
    const api = createReviewRecipeAdjustmentApi("ready");
    const reads = vi.spyOn(api, "getOperatorWorkbench");
    renderWorkbench("rules", api);
    await waitFor(() =>
      expect(reads).toHaveBeenLastCalledWith(
        expect.any(String),
        expect.any(String),
        "2026-09-06",
      ),
    );
    vi.setSystemTime(new Date("2026-09-06T17:01:00.000Z"));
    fireEvent.focus(window);
    await waitFor(() =>
      expect(reads).toHaveBeenLastCalledWith(
        expect.any(String),
        expect.any(String),
        "2026-09-07",
      ),
    );
    expect(screen.queryByLabelText("Ngày tham chiếu")).not.toBeInTheDocument();
  });

  it("ignores a late effective composition after the selected date changes", async () => {
    const fixture = createReviewRecipeAdjustmentApi("ready");
    let releaseResolve: (() => Promise<void>) | undefined;
    const api = {
      ...fixture,
      resolve: vi.fn(
        (...args: Parameters<typeof fixture.resolve>) =>
          new Promise<Awaited<ReturnType<typeof fixture.resolve>>>(
            (resolve) => {
              releaseResolve = async () =>
                resolve(await fixture.resolve(...args));
            },
          ),
      ),
    };
    renderWorkbench("effective", api);
    const viewButton = await screen.findByRole("button", {
      name: "Xem công thức",
    });
    await waitFor(() => expect(viewButton).toBeEnabled());
    fireEvent.click(viewButton);
    await waitFor(() => expect(api.resolve).toHaveBeenCalledOnce());
    fireEvent.change(screen.getByLabelText("Xem tại ngày"), {
      target: { value: "2026-09-07" },
    });
    await act(async () => releaseResolve?.());

    expect(
      screen.queryByText(/Công thức theo loại trường/),
    ).not.toBeInTheDocument();
    expect(
      screen.getByText(
        "Chọn ngày, trường và món để xem công thức đang áp dụng.",
      ),
    ).toBeInTheDocument();
  });

  it("rejects an effective composition that does not match its requested context", async () => {
    const fixture = createReviewRecipeAdjustmentApi("ready");
    const api = {
      ...fixture,
      async resolve(...args: Parameters<typeof fixture.resolve>) {
        const result = await fixture.resolve(...args);
        if (result.kind !== "success") return result;
        const resolution = result.response.resolution as Record<
          string,
          JsonValue
        >;
        resolution.dish_id = "dish-from-another-request";
        return result;
      },
    };
    renderWorkbench("effective", api);
    const viewButton = await screen.findByRole("button", {
      name: "Xem công thức",
    });
    await waitFor(() => expect(viewButton).toBeEnabled());
    fireEvent.click(viewButton);

    expect(
      await screen.findByText(
        "Kết quả công thức không khớp bối cảnh đã chọn. Vui lòng xem lại.",
      ),
    ).toBeInTheDocument();
    expect(
      screen.queryByText(/Công thức theo loại trường/),
    ).not.toBeInTheDocument();
  });
});
