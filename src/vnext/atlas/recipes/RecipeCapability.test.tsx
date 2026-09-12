import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
  within,
} from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import { AtlasVNextProvider } from "../AtlasVNextProvider";
import { RecipeCapability } from "./RecipeCapability";
import { createRecipeReviewFixture } from "./recipeReviewFixtures";
import {
  createChangeOrderFixture,
  type ChangeOrderScenario,
} from "./changeOrderReviewFixtures";
afterEach(cleanup);
async function setup(
  scenario: ChangeOrderScenario = "ACTIVE",
  initialJob: "recipes" | "changes" = "changes",
) {
  const f = createChangeOrderFixture(scenario),
    base = createRecipeReviewFixture("DISH_ACTIVE_EDITABLE");
  render(
    <AtlasVNextProvider>
      <RecipeCapability
        authSubject="operator"
        recipeApi={base.api}
        adjustmentApi={f.api}
        initialDate="2026-09-12"
        initialJob={initialJob}
      />
    </AtlasVNextProvider>,
  );
  await waitFor(() =>
    expect(
      screen.getByRole("button", {
        name: initialJob === "changes" ? "Tạo lệnh điều chỉnh" : "Tạo món mới",
      }),
    ).toBeEnabled(),
  );
  return f;
}
function choose(label: string, value: string) {
  fireEvent.change(screen.getByLabelText(label), { target: { value } });
}
async function editor(action = "REPLACE") {
  fireEvent.click(screen.getByRole("button", { name: "Tạo lệnh điều chỉnh" }));
  choose("Món", "dish-0");
  choose("Loại công thức", "scope-0");
  choose("Hành động", action);
  if (action !== "ADD") {
    await waitFor(() =>
      expect(screen.getByLabelText("Thành phần hiện tại")).not.toBeDisabled(),
    );
    choose("Thành phần hiện tại", "RECIPE_LINE:base-line");
  }
  if (action === "REPLACE") choose("Nguyên liệu thay thế", "ingredient-3");
  if (action === "ADD") {
    choose("Nguyên liệu thêm", "ingredient-3");
    choose("Định lượng mới", "1,5");
  }
  if (action === "ADJUST_QUANTITY") choose("Định lượng mới", "1,5");
  choose("Lý do điều chỉnh", "Điều chỉnh theo thực đơn");
}
describe("Unified Recipe capability and Change Order operator job", () => {
  it("has one capability heading and peer jobs above the full-width base catalogue", async () => {
    const f = await setup("ACTIVE", "recipes");
    expect(screen.getAllByRole("heading", { level: 1 })).toHaveLength(1);
    expect(screen.getByRole("heading", { level: 1 })).toHaveTextContent(
      "Công thức",
    );
    const tabs = screen.getByRole("tablist");
    expect(within(tabs).getAllByRole("tab")).toHaveLength(2);
    expect(screen.getByRole("tab", { name: "Công thức" })).toHaveAttribute(
      "aria-selected",
      "true",
    );
    fireEvent.click(screen.getByRole("tab", { name: "Lệnh điều chỉnh" }));
    await screen.findByRole("table", { name: "Lệnh điều chỉnh" });
    expect(
      tabs.compareDocumentPosition(
        screen.getByRole("table", { name: "Lệnh điều chỉnh" }),
      ) & Node.DOCUMENT_POSITION_FOLLOWING,
    ).toBeTruthy();
    expect(
      f.calls.every((c) => !["create", "supersede", "cancel"].includes(c.name)),
    ).toBe(true);
  });
  it("protects dirty base switching and preserves the exact cancelled draft", async () => {
    await setup("ACTIVE", "recipes");
    fireEvent.click(
      screen.getByRole("button", { name: "Xem công thức Canh bí đỏ thịt bằm" }),
    );
    const input = await screen.findByLabelText("Định lượng Bí đỏ");
    choose("Định lượng Bí đỏ", "2,25");
    fireEvent.click(screen.getByRole("tab", { name: "Lệnh điều chỉnh" }));
    const dialog = await screen.findByRole("dialog");
    fireEvent.click(
      within(dialog).getByRole("button", { name: "Tiếp tục chỉnh sửa" }),
    );
    await waitFor(() =>
      expect(screen.queryByRole("dialog")).not.toBeInTheDocument(),
    );
    expect(input).toHaveValue("2,25");
    fireEvent.click(screen.getByRole("tab", { name: "Lệnh điều chỉnh" }));
    fireEvent.click(
      within(await screen.findByRole("dialog")).getByRole("button", {
        name: "Bỏ thay đổi",
      }),
    );
    await screen.findByRole("table", { name: "Lệnh điều chỉnh" });
  });
  it("protects Change Order job switch, close and row selection while local search retains drafts", async () => {
    const f = await setup();
    await editor();
    const reads = f.calls.filter((c) => c.name === "read").length;
    choose("Tìm lệnh", "ca rot");
    expect(screen.getByLabelText("Lý do điều chỉnh")).toHaveValue(
      "Điều chỉnh theo thực đơn",
    );
    expect(f.calls.filter((c) => c.name === "read")).toHaveLength(reads);
    fireEvent.click(screen.getByRole("tab", { name: "Công thức" }));
    fireEvent.click(
      within(await screen.findByRole("dialog")).getByRole("button", {
        name: "Tiếp tục chỉnh sửa",
      }),
    );
    await waitFor(() =>
      expect(screen.queryByRole("dialog")).not.toBeInTheDocument(),
    );
    expect(screen.getByLabelText("Lý do điều chỉnh")).toHaveValue(
      "Điều chỉnh theo thực đơn",
    );
    fireEvent.click(screen.getByRole("button", { name: "Đóng lệnh" }));
    fireEvent.click(
      within(await screen.findByRole("dialog")).getByRole("button", {
        name: "Bỏ thay đổi",
      }),
    );
    await waitFor(() =>
      expect(
        screen.queryByLabelText("Lý do điều chỉnh"),
      ).not.toBeInTheDocument(),
    );
  });
  it.each(["REPLACE", "ADJUST_QUANTITY", "ADD", "REMOVE"])(
    "shows required %s business fields and authoritative before/after Review",
    async (action) => {
      const f = await setup();
      await editor(action);
      expect(screen.queryByLabelText("Nguyên liệu thay thế") !== null).toBe(
        action === "REPLACE",
      );
      expect(screen.queryByLabelText("Định lượng mới") !== null).toBe(
        ["ADD", "ADJUST_QUANTITY"].includes(action),
      );
      expect(screen.queryByLabelText("Trường")).not.toBeInTheDocument();
      expect(document.querySelector('input[type="date"]')).toBeNull();
      expect(
        screen.queryByLabelText("Trường kiểm tra"),
      ).not.toBeInTheDocument();
      fireEvent.click(screen.getByRole("button", { name: "Xem tác động" }));
      const review = await screen.findByRole("dialog", {
        name: "Xem tác động",
      });
      expect(
        within(review).getByRole("table", { name: "Trước điều chỉnh" }),
      ).toBeInTheDocument();
      expect(
        within(review).getByRole("table", { name: "Sau điều chỉnh" }),
      ).toBeInTheDocument();
      expect(
        within(review).getByText(/1 thành phần chịu tác động/),
      ).toBeInTheDocument();
      expect(f.calls.some((c) => c.name === "create")).toBe(false);
      fireEvent.click(
        within(review).getByRole("button", { name: "Lưu lệnh điều chỉnh" }),
      );
      await waitFor(() =>
        expect(f.calls.filter((c) => c.name === "create")).toHaveLength(1),
      );
    },
  );
  it("uses two human decisions and shows only scope-supported actions", async () => {
    await setup();
    fireEvent.click(
      screen.getByRole("button", { name: "Tạo lệnh điều chỉnh" }),
    );
    choose("Điều chỉnh", "ingredient");
    expect(
      within(screen.getByLabelText("Hành động"))
        .getAllByRole("option")
        .map((o) => o.textContent),
    ).toEqual(["Chọn hành động", "Thay nguyên liệu"]);
    expect(
      screen.getByRole("group", { name: "Ngữ cảnh kiểm tra tác động" }),
    ).toBeInTheDocument();
    choose("Áp dụng cho", "one");
    expect(
      within(screen.getByLabelText("Hành động"))
        .getAllByRole("option")
        .map((o) => o.textContent),
    ).toEqual(["Chọn hành động", "Thay nguyên liệu", "Bỏ nguyên liệu"]);
    expect(screen.getByLabelText("Trường")).toBeInTheDocument();
    expect(screen.queryByLabelText("Loại công thức")).not.toBeInTheDocument();
    expect(document.body.textContent).not.toMatch(
      /SYSTEM_DISH|SCHOOL_DISH|SYSTEM_INGREDIENT|ADJUST_QUANTITY|Supersede|revision_id|adjustment_id/,
    );
  });
  it("blocked Preview offers blockers and editable return without Save", async () => {
    await setup("PREVIEW_BLOCKED");
    await editor();
    fireEvent.click(screen.getByRole("button", { name: "Xem tác động" }));
    const dialog = await screen.findByRole("dialog");
    expect(
      within(dialog).getByText("Nguyên liệu bị trùng trong công thức."),
    ).toBeInTheDocument();
    expect(
      within(dialog).queryByRole("button", { name: "Lưu lệnh điều chỉnh" }),
    ).not.toBeInTheDocument();
    fireEvent.click(
      within(dialog).getByRole("button", { name: "Tiếp tục chỉnh sửa" }),
    );
    await waitFor(() =>
      expect(screen.queryByRole("dialog")).not.toBeInTheDocument(),
    );
    expect(screen.getByLabelText("Lý do điều chỉnh")).toHaveValue(
      "Điều chỉnh theo thực đơn",
    );
  });
  it("renders immutable legacy history without inventing attribution and cancel uses a focused dialog", async () => {
    await setup("LEGACY_UNATTRIBUTED_HISTORY");
    fireEvent.click(
      screen.getByRole("button", {
        name: "Xem lệnh Thay nguyên liệu Canh bí đỏ thịt bằm",
      }),
    );
    expect(
      screen.getByText("Dữ liệu cũ · không lưu người phát hành"),
    ).toBeInTheDocument();
    expect(screen.queryByText("Nguyễn Lan")).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Hủy lệnh" }));
    const dialog = await screen.findByRole("dialog", { name: "Hủy lệnh" });
    expect(within(dialog).getAllByRole("spinbutton")).toHaveLength(3);
    expect(within(dialog).getByLabelText("Lý do hủy")).toBeInTheDocument();
    expect(
      within(dialog).getByRole("button", { name: "Xác nhận hủy" }),
    ).toBeDisabled();
  });
  it("keeps the empty ledger quiet with the create entry point", async () => {
    await setup("EMPTY");
    expect(screen.getByText("Chưa có lệnh điều chỉnh.")).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "Tạo lệnh điều chỉnh" }),
    ).toBeEnabled();
  });
});

it("keeps a definite cancellation denial visible inside the active dialog", async () => {
  await setup("PERMISSION_DENIED");
  fireEvent.click(
    screen.getByRole("button", {
      name: "Xem lệnh Thay nguyên liệu Canh bí đỏ thịt bằm",
    }),
  );
  fireEvent.click(screen.getByRole("button", { name: "Hủy lệnh" }));
  const dialog = await screen.findByRole("dialog", { name: "Hủy lệnh" });
  choose("Lý do hủy", "Không còn áp dụng");
  fireEvent.click(within(dialog).getByRole("button", { name: "Xác nhận hủy" }));
  expect(
    await within(dialog).findByText(
      "Bạn không có quyền thực hiện điều chỉnh công thức.",
    ),
  ).toBeInTheDocument();
});

it("labels selected target, replacement, type and Unit as human facts", async () => {
  await setup();
  fireEvent.click(
    screen.getByRole("button", {
      name: "Xem lệnh Thay nguyên liệu Canh bí đỏ thịt bằm",
    }),
  );
  const detail = screen.getByLabelText("Chi tiết lệnh");
  for (const label of [
    "Món",
    "Loại công thức",
    "Thành phần hiện tại",
    "Nguyên liệu thay thế",
    "Đơn vị",
  ])
    expect(
      within(detail).getByText(label, { exact: true }),
    ).toBeInTheDocument();
});

it("retains a prior ADD's authoritative Unit when its Ingredient purchase Unit has since changed", async () => {
  const f = createChangeOrderFixture(),
    base = createRecipeReviewFixture("DISH_ACTIVE_EDITABLE");
  const row = f.data.operator_rows[0];
  row.target_recipe_line_id = null;
  row.adjustment_line_id = "prior-added";
  f.data.operator_rows.push({
    ...structuredClone(row),
    adjustment_id: "source-add",
    action_kind: "ADD",
    target_ingredient_id: "ingredient-2",
    content_revision: { ...row.content_revision, unit_id: "old-unit" },
  });
  render(
    <AtlasVNextProvider>
      <RecipeCapability
        authSubject="operator"
        recipeApi={base.api}
        adjustmentApi={f.api}
        initialDate="2026-09-12"
        initialJob="changes"
      />
    </AtlasVNextProvider>,
  );
  fireEvent.click(
    await screen.findByRole("button", {
      name: "Xem lệnh Thay nguyên liệu Canh bí đỏ thịt bằm",
    }),
  );
  expect(
    within(screen.getByLabelText("Chi tiết lệnh")).getByText("Đơn vị cũ"),
  ).toBeInTheDocument();
});
