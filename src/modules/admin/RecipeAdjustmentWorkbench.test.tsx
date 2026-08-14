import "@testing-library/jest-dom/vitest";
import { MantineProvider } from "@mantine/core";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
  within,
} from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
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
};

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
});

function renderWorkbench(
  view: "rules" | "effective" = "rules",
  api = createReviewRecipeAdjustmentApi("ready"),
) {
  return {
    api,
    ...render(
      <MantineProvider theme={atlasTheme}>
        <RecipeAdjustmentWorkbench
          authState={createReviewAuthState("ready")}
          api={api}
          view={view}
          mode="review"
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

function selectRecipeTarget(dialog: HTMLElement) {
  const school = within(dialog).queryByLabelText("Trường");
  if (school)
    fireEvent.change(school, {
      target: { value: fixtureIds.school },
    });
  fireEvent.change(within(dialog).getByLabelText("Món"), {
    target: { value: fixtureIds.dish },
  });
  const recipeType = within(dialog).queryByRole("combobox", {
    name: /Loại công thức/,
  });
  if (recipeType)
    fireEvent.change(recipeType, {
      target: { value: fixtureIds.schoolType },
    });
}

function fillRecipeReplacement(dialog: HTMLElement) {
  selectRecipeTarget(dialog);
  selectAction(dialog, "Thay nguyên liệu");
  fireEvent.change(
    within(dialog).getByLabelText("Nguyên liệu trong công thức"),
    {
      target: { value: fixtureIds.porkLine },
    },
  );
  fireEvent.change(within(dialog).getByLabelText("Thay bằng"), {
    target: { value: fixtureIds.potato },
  });
  fireEvent.change(within(dialog).getByLabelText("Lý do"), {
    target: { value: "Thay theo tiêu chuẩn nguyên liệu đã duyệt." },
  });
  const representativeSchool =
    within(dialog).queryByLabelText("Trường dùng để xem");
  if (representativeSchool)
    fireEvent.change(representativeSchool, {
      target: { value: fixtureIds.school },
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
  if (representativeDish)
    fireEvent.change(representativeDish, {
      target: { value: fixtureIds.dish },
    });
}

describe("Recipe Change Order first-user workbench", () => {
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
    selectRecipeTarget(dialog);
    selectAction(dialog, "Thêm nguyên liệu");
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
    fireEvent.change(within(dialog).getByLabelText("Trường dùng để xem"), {
      target: { value: fixtureIds.school },
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

  it("blocks ADD preview safely when the Ingredient has no purchase Unit", async () => {
    renderWorkbench();
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
      target: { value: "Kiểm tra dữ liệu nguyên liệu thiếu đơn vị." },
    });
    fireEvent.change(within(dialog).getByLabelText("Trường dùng để xem"), {
      target: { value: fixtureIds.school },
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
    selectRecipeTarget(dialog);
    selectAction(dialog, "Đổi định lượng");
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
    fireEvent.change(within(dialog).getByLabelText("Trường dùng để xem"), {
      target: { value: fixtureIds.school },
    });
    fireEvent.click(
      within(dialog).getByRole("button", { name: "Xem ảnh hưởng" }),
    );

    await screen.findByRole("dialog", { name: "Thay đổi dự kiến" });
    expect(preview.mock.calls[0][2].proposed_adjustment).toMatchObject({
      action_kind: "ADJUST_QUANTITY",
      target_recipe_line_id: fixtureIds.porkLine,
      quantity_per_basis: 7.5,
      unit_id: null,
    });
  });

  it("shows no Unit decision for REPLACE until quantity override derives the substitute Unit", async () => {
    const { api } = renderWorkbench();
    const preview = vi.spyOn(api, "preview");
    const dialog = await openCreateDialog();
    fillRecipeReplacement(dialog);
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
    ).toEqual(["Chọn loại công thức", "Tiểu học", "Trung học"]);
    expect(dialog.textContent).not.toMatch(
      /Không bắt buộc|Tất cả loại trường|Cả hai loại trường/,
    );
    expect(
      within(dialog).getByRole("button", { name: "Xem ảnh hưởng" }),
    ).toBeDisabled();

    selectRecipeTarget(dialog);
    selectAction(dialog, "Thay nguyên liệu");
    expect(within(dialog).getByLabelText("Trường dùng để xem")).toHaveValue("");
    expect(
      within(within(dialog).getByLabelText("Trường dùng để xem"))
        .getAllByRole("option")
        .map((option) => option.textContent),
    ).toEqual(["Chọn trường", "Trường Tiểu học Minh Khai"]);

    fillRecipeReplacement(dialog);
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
      scope_kind: "SYSTEM_DISH",
      school_type_id: fixtureIds.schoolType,
    });
    expect(
      within(review).getByText("Canh bí đỏ · Tiểu học"),
    ).toBeInTheDocument();
    expect(within(review).getByText("Tất cả trường")).toBeInTheDocument();

    const comparison = within(review).getByRole("table", {
      name: "So sánh công thức trước và sau",
    });
    expect(within(comparison).getAllByText("Bí đỏ · 20 Kilôgam")).toHaveLength(
      2,
    );
    expect(
      within(comparison).queryByText(/25 Kilôgam/),
    ).not.toBeInTheDocument();
    expect(
      within(comparison).queryByText(/10 Kilôgam/),
    ).not.toBeInTheDocument();
  });

  it("filters Recipe lines and representative Schools by Recipe Type and clears stale preview", async () => {
    const { api } = renderWorkbench();
    const preview = vi.spyOn(api, "preview");
    const dialog = await openCreateDialog();
    fillRecipeReplacement(dialog);

    const primaryLines = within(
      within(dialog).getByLabelText("Nguyên liệu trong công thức"),
    )
      .getAllByRole("option")
      .map((option) => option.textContent);
    expect(primaryLines).toContain("Thịt heo · 8 Kilôgam");
    expect(primaryLines).not.toContain("Thịt heo · 10 Kilôgam");
    expect(
      within(within(dialog).getByLabelText("Trường dùng để xem"))
        .getAllByRole("option")
        .map((option) => option.textContent),
    ).toEqual(["Chọn trường", "Trường Tiểu học Minh Khai"]);

    fireEvent.click(
      within(dialog).getByRole("button", { name: "Xem ảnh hưởng" }),
    );
    const review = await screen.findByRole("dialog", {
      name: "Thay đổi dự kiến",
    });
    fireEvent.click(within(review).getByRole("button", { name: "Quay lại" }));
    const edit = await screen.findByRole("dialog", { name: "Tạo điều chỉnh" });

    fireEvent.change(
      within(edit).getByRole("combobox", {
        name: /Loại công thức/,
      }),
      {
        target: { value: fixtureIds.secondarySchoolType },
      },
    );
    expect(
      within(edit).getByLabelText("Nguyên liệu trong công thức"),
    ).toHaveValue("");
    expect(within(edit).getByLabelText("Thay bằng")).toHaveValue("");
    expect(
      within(within(edit).getByLabelText("Nguyên liệu trong công thức"))
        .getAllByRole("option")
        .map((option) => option.textContent),
    ).toEqual([
      "Chọn nguyên liệu trong món",
      "Bí đỏ · 25 Kilôgam",
      "Thịt heo · 10 Kilôgam",
    ]);
    expect(
      within(within(edit).getByLabelText("Trường dùng để xem"))
        .getAllByRole("option")
        .map((option) => option.textContent),
    ).toEqual(["Chọn trường", "Trường Trung học Trần Phú"]);
    expect(within(edit).getByLabelText("Trường dùng để xem")).toHaveValue("");
    expect(
      within(edit).getByRole("button", { name: "Xem ảnh hưởng" }),
    ).toBeDisabled();
    expect(preview).toHaveBeenCalledOnce();
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
    expect(within(derivedType).getByText("Trung học")).toBeInTheDocument();
    expect(within(dialog).getByLabelText("Món")).toHaveValue("");
    fireEvent.change(within(dialog).getByLabelText("Món"), {
      target: { value: fixtureIds.dish },
    });
    selectAction(dialog, "Thay nguyên liệu");
    const recipeLine = within(dialog).getByLabelText(
      "Nguyên liệu trong công thức",
    );
    const options = within(recipeLine)
      .getAllByRole("option")
      .map((option) => option.textContent);
    expect(options).toContain("Thịt heo · 10 Kilôgam");
    expect(options).not.toContain("Thịt heo · 8 Kilôgam");

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
      within(review).getByText("Canh bí đỏ · Trung học"),
    ).toBeInTheDocument();
    expect(
      within(review).getByText("Trường Trung học Trần Phú"),
    ).toBeInTheDocument();
    const comparison = within(review).getByRole("table", {
      name: "So sánh công thức trước và sau",
    });
    expect(within(comparison).getAllByText("Bí đỏ · 25 Kilôgam")).toHaveLength(
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
      ).getByText("Trung học"),
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
      authority: "Tất cả trường",
      expectedScope: "SYSTEM_DISH",
    },
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
        fillRecipeReplacement(dialog);
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
    fillRecipeReplacement(dialog);

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
    expect(within(comparison).getAllByText("Bí đỏ · 20 Kilôgam")).toHaveLength(
      2,
    );
    const changedRow = within(comparison)
      .getAllByRole("row")
      .find((row) => row.textContent?.includes("Thịt heo"));
    expect(changedRow).toBeDefined();
    expect(within(changedRow!).getByLabelText("Có thay đổi")).toHaveTextContent(
      "→",
    );
    const unchangedRow = within(comparison)
      .getAllByRole("row")
      .find((row) => row.textContent?.includes("Bí đỏ"));
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
    fillRecipeReplacement(dialog);
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
    fillRecipeReplacement(dialog);

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
      selectRecipeTarget(dialog);
      selectAction(dialog, action);
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
      fireEvent.change(within(dialog).getByLabelText("Trường dùng để xem"), {
        target: { value: fixtureIds.school },
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
        within(comparison).getAllByText("Bí đỏ · 20 Kilôgam"),
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
            "Canh bí đỏ · Tiểu học · Một món tại các trường",
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
      within(fixedContext).getByText("Canh bí đỏ · Tiểu học"),
    ).toBeInTheDocument();
    expect(within(fixedContext).getByText("Tất cả trường")).toBeInTheDocument();
    expect(within(dialog).getByLabelText("Món")).toBeDisabled();
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
    expect(screen.getByLabelText("Ngày xem")).not.toHaveValue("");
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
});
