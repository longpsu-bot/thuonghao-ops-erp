import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  act,
  fireEvent,
  render,
  screen,
  waitFor,
  within,
} from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import type { AtlasWorkbenchStatus } from "../AtlasModuleExit";
import { AtlasVNextProvider, AtlasWorkbenchScope } from "../AtlasVNextProvider";
import { RecipeCapability } from "./RecipeCapability";
import { createRecipeReviewFixture } from "./recipeReviewFixtures";
import { fixtureSuccess } from "./recipeReviewFixtures";
import { adjustmentPreviewFromResult } from "../bridges/recipeAdjustment";
import {
  createChangeOrderFixture,
  type ChangeOrderScenario,
} from "./changeOrderReviewFixtures";
afterEach(cleanup);
async function setup(
  scenario: ChangeOrderScenario = "ACTIVE",
  initialJob: "recipes" | "changes" = "changes",
  onWorkspaceStatus?: (status: AtlasWorkbenchStatus) => void,
  configure?: (fixture: ReturnType<typeof createChangeOrderFixture>) => void,
) {
  const f = createChangeOrderFixture(scenario),
    base = createRecipeReviewFixture("DISH_ACTIVE_EDITABLE");
  configure?.(f);
  render(
    <AtlasVNextProvider>
      <RecipeCapability
        authSubject="operator"
        recipeApi={base.api}
        adjustmentApi={f.api}
        initialDate="2026-09-12"
        initialJob={initialJob}
        onWorkspaceStatus={onWorkspaceStatus}
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
  await waitFor(() =>
    expect(screen.getByRole("button", { name: "Xem tác động" })).toBeEnabled(),
  );
}
async function retainedWorkspace(initialJob: "recipes" | "changes") {
  const f = createChangeOrderFixture(),
    base = createRecipeReviewFixture("DISH_ACTIVE_EDITABLE"),
    status = vi.fn();
  const view = (active: boolean) => (
    <AtlasVNextProvider>
      <button>Other workbench</button>
      <AtlasWorkbenchScope active={active}>
        <div hidden={!active} inert={!active}>
          <RecipeCapability
            authSubject="operator"
            recipeApi={base.api}
            adjustmentApi={f.api}
            initialDate="2026-09-12"
            initialJob={initialJob}
            onWorkspaceStatus={status}
          />
        </div>
      </AtlasWorkbenchScope>
    </AtlasVNextProvider>
  );
  const ui = render(view(true));
  await waitFor(() =>
    expect(
      screen.getByRole("button", {
        name: initialJob === "changes" ? "Tạo lệnh điều chỉnh" : "Tạo món mới",
      }),
    ).toBeEnabled(),
  );
  return {
    ...f,
    status,
    setActive: (active: boolean) => ui.rerender(view(active)),
  };
}

describe("Unified Recipe capability and Change Order operator job", () => {
  it("translates a known inactive substitute blocker without exposing backend English", async () => {
    await setup("PREVIEW_BLOCKED", "changes", undefined, (fixture) => {
      const original = fixture.api.preview;
      fixture.api.preview = async (...args) => {
        const preview = adjustmentPreviewFromResult(await original(...args))!;
        return fixtureSuccess({
          preview: {
            ...preview,
            blockers: [
              {
                code: "SUBSTITUTE_INGREDIENT_INACTIVE",
                message: "The substitute Ingredient must be active.",
              },
            ],
          },
        });
      };
    });
    await editor();
    fireEvent.click(screen.getByRole("button", { name: "Xem tác động" }));
    const dialog = await screen.findByRole("dialog");
    expect(
      within(dialog).getByText("Nguyên liệu thay thế đang ngừng sử dụng."),
    ).toBeVisible();
    expect(
      screen.queryByText("The substitute Ingredient must be active."),
    ).not.toBeInTheDocument();
    expect(
      within(dialog).queryByRole("button", { name: "Lưu lệnh điều chỉnh" }),
    ).not.toBeInTheDocument();
  });
  it("retains a delayed Change Order Preview without opening a hidden modal, then shows it on activation", async () => {
    const f = await retainedWorkspace("changes");
    await editor();
    const original = f.api.preview;
    let finish!: () => void;
    f.api.preview = async (...args) => {
      const response = await original(...args);
      return new Promise((resolve) => {
        finish = () => resolve(response);
      });
    };
    fireEvent.click(screen.getByRole("button", { name: "Xem tác động" }));
    await waitFor(() => expect(finish).toBeTypeOf("function"));
    f.setActive(false);
    const other = screen.getByRole("button", { name: "Other workbench" });
    other.focus();
    await act(async () => {
      finish();
    });
    expect(
      document.querySelector('[role="dialog"][data-state="open"]'),
    ).toBeNull();
    expect(other).toHaveFocus();
    expect(f.status).toHaveBeenLastCalledWith(
      expect.objectContaining({ unsaved: true, blocked: true }),
    );
    f.setActive(true);
    const dialog = await screen.findByRole("dialog", { name: "Xem tác động" });
    expect(
      within(dialog).getByRole("button", { name: "Lưu lệnh điều chỉnh" }),
    ).toBeEnabled();
    expect(screen.getByLabelText("Lý do điều chỉnh")).toHaveValue(
      "Điều chỉnh theo thực đơn",
    );
    expect(f.calls.filter((call) => call.name === "preview")).toHaveLength(1);
  });
  it("defers utility modal activation when accepted discard completes in an inactive workbench", async () => {
    const f = await retainedWorkspace("recipes");
    fireEvent.click(screen.getByRole("button", { name: "Tạo món mới" }));
    choose("Tên món", "Bỏ thay đổi này");
    fireEvent.click(screen.getByRole("button", { name: "Nhập workbook" }));
    const discard = await screen.findByRole("dialog");
    fireEvent.click(
      within(discard).getByRole("button", { name: "Bỏ thay đổi" }),
    );
    await waitFor(() =>
      expect(discard).toHaveAttribute("data-state", "closed"),
    );
    f.setActive(false);
    fireEvent(discard, new Event("animationcancel", { bubbles: true }));
    await waitFor(() =>
      expect(screen.queryByLabelText("Tên món")).not.toBeInTheDocument(),
    );
    expect(
      document.querySelector('[role="dialog"][data-state="open"]'),
    ).toBeNull();
    f.setActive(true);
    expect(
      await screen.findByRole("dialog", { name: "Nhập workbook" }),
    ).toBeInTheDocument();
  });
  it("reports actual utility reason edits and their revert before modal dismissal", async () => {
    const status = vi.fn();
    await setup("ACTIVE", "recipes", status);
    fireEvent.click(screen.getByRole("button", { name: "Nhập workbook" }));
    const dialog = await screen.findByRole("dialog", { name: "Nhập workbook" });
    expect(status).toHaveBeenLastCalledWith(
      expect.objectContaining({ unsaved: false, blocked: true }),
    );
    const reason = within(dialog).getByLabelText("Lý do nhập workbook");
    fireEvent.change(reason, { target: { value: "Nhập thành phần" } });
    expect(status).toHaveBeenLastCalledWith(
      expect.objectContaining({ unsaved: true, blocked: true }),
    );
    fireEvent.change(reason, { target: { value: "" } });
    expect(status).toHaveBeenLastCalledWith(
      expect.objectContaining({ unsaved: false, blocked: true }),
    );
  });
  it("reports untouched create and each metadata field edit/revert through the capability", async () => {
    const status = vi.fn();
    await setup("ACTIVE", "recipes", status);
    expect(status).toHaveBeenLastCalledWith(
      expect.objectContaining({ unsaved: false, blocked: false }),
    );
    fireEvent.click(screen.getByRole("button", { name: "Tạo món mới" }));
    expect(status).toHaveBeenLastCalledWith(
      expect.objectContaining({ unsaved: false }),
    );
    for (const label of [
      "Tên món",
      "Loại món của món",
      "Phân loại / nhóm món",
      "Ghi chú vận hành (không bắt buộc)",
    ]) {
      const field = screen.getByLabelText(label);
      const baseline = (field as HTMLInputElement).value;
      const value =
        label === "Loại món của món"
          ? (within(field).getAllByRole("option")[1] as HTMLOptionElement).value
          : "Thay đổi";
      choose(label, value);
      expect(status).toHaveBeenLastCalledWith(
        expect.objectContaining({ unsaved: true }),
      );
      choose(label, baseline);
      expect(status).toHaveBeenLastCalledWith(
        expect.objectContaining({ unsaved: false }),
      );
    }
  });
  it("reports edit metadata baseline, revert, canceled close and authoritative Save", async () => {
    const status = vi.fn();
    await setup("ACTIVE", "recipes", status);
    fireEvent.click(
      screen.getByRole("button", { name: "Sửa công thức Canh bí đỏ thịt bằm" }),
    );
    await screen.findByLabelText("Định lượng Bí đỏ");
    fireEvent.click(screen.getByRole("button", { name: "Sửa thông tin món" }));
    expect(status).toHaveBeenLastCalledWith(
      expect.objectContaining({ unsaved: false }),
    );
    const name = (screen.getByLabelText("Tên món") as HTMLInputElement).value;
    choose("Tên món", "Tên tạm");
    expect(status).toHaveBeenLastCalledWith(
      expect.objectContaining({ unsaved: true }),
    );
    choose("Tên món", name);
    expect(status).toHaveBeenLastCalledWith(
      expect.objectContaining({ unsaved: false }),
    );
    choose("Tên món", "Canh đổi tên");
    expect(status).toHaveBeenLastCalledWith(
      expect.objectContaining({ unsaved: true }),
    );
    fireEvent.click(screen.getByRole("button", { name: "Đóng công thức" }));
    const discard = await screen.findByRole("dialog");
    fireEvent.click(
      within(discard).getByRole("button", {
        name: "Tiếp tục chỉnh sửa",
      }),
    );
    await waitFor(() => {
      expect(discard).toHaveAttribute("data-state", "closed");
      // jsdom does not run the CSS exit animation; deliver its native completion.
      fireEvent(discard, new Event("animationcancel", { bubbles: true }));
      expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
    });
    expect(screen.getByLabelText("Tên món")).toHaveValue("Canh đổi tên");
    expect(status).toHaveBeenLastCalledWith(
      expect.objectContaining({ unsaved: true, blocked: false }),
    );
    fireEvent.click(screen.getByRole("button", { name: "Lưu thông tin món" }));
    await screen.findByText("Đã lưu thông tin món.");
    expect(status).toHaveBeenLastCalledWith(
      expect.objectContaining({ unsaved: false, blocked: false }),
    );
  });
  it("clears metadata status only after approved discard completes", async () => {
    const status = vi.fn();
    await setup("ACTIVE", "recipes", status);
    fireEvent.click(screen.getByRole("button", { name: "Tạo món mới" }));
    choose("Tên món", "Bỏ tên này");
    fireEvent.click(screen.getByRole("button", { name: "Đóng công thức" }));
    const discard = await screen.findByRole("dialog");
    fireEvent.click(
      within(discard).getByRole("button", {
        name: "Bỏ thay đổi",
      }),
    );
    expect(screen.getByLabelText("Tên món")).toHaveValue("Bỏ tên này");
    expect(status).toHaveBeenLastCalledWith(
      expect.objectContaining({ unsaved: true }),
    );
    await waitFor(() =>
      expect(discard).toHaveAttribute("data-state", "closed"),
    );
    // jsdom does not run CSS exit animations; production completes this in the browser.
    fireEvent(discard, new Event("animationcancel", { bubbles: true }));
    await waitFor(() =>
      expect(screen.queryByLabelText("Tên món")).not.toBeInTheDocument(),
    );
    expect(status).toHaveBeenLastCalledWith(
      expect.objectContaining({ unsaved: false, blocked: false }),
    );
  });
  it("reports BOM work, frozen Review and successful authoritative Save", async () => {
    const status = vi.fn();
    await setup("ACTIVE", "recipes", status);
    fireEvent.click(
      screen.getByRole("button", { name: "Sửa công thức Canh bí đỏ thịt bằm" }),
    );
    const field = await screen.findByLabelText("Định lượng Bí đỏ");
    const baseline = (field as HTMLInputElement).value;
    choose("Định lượng Bí đỏ", "2,25");
    expect(status).toHaveBeenLastCalledWith(
      expect.objectContaining({ unsaved: true, blocked: false }),
    );
    choose("Định lượng Bí đỏ", baseline);
    expect(status).toHaveBeenLastCalledWith(
      expect.objectContaining({ unsaved: false }),
    );
    choose("Định lượng Bí đỏ", "2,25");
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    expect(status).toHaveBeenLastCalledWith(
      expect.objectContaining({ unsaved: true, blocked: true }),
    );
    fireEvent.click(screen.getByRole("button", { name: "Lưu công thức" }));
    await screen.findByText("Đã lưu công thức · Sẵn sàng cho Lập nhu cầu");
    await waitFor(() =>
      expect(status).toHaveBeenLastCalledWith(
        expect.objectContaining({ unsaved: false, blocked: false }),
      ),
    );
  });
  it("reports Change Order baseline, edited/reverted reason and cancellation fields", async () => {
    const status = vi.fn();
    await setup("ACTIVE", "changes", status);
    fireEvent.click(
      screen.getByRole("button", { name: "Tạo lệnh điều chỉnh" }),
    );
    expect(status).toHaveBeenLastCalledWith(
      expect.objectContaining({ unsaved: false, blocked: false }),
    );
    choose("Lý do điều chỉnh", "Thay đổi");
    expect(status).toHaveBeenLastCalledWith(
      expect.objectContaining({ unsaved: true }),
    );
    choose("Lý do điều chỉnh", "");
    expect(status).toHaveBeenLastCalledWith(
      expect.objectContaining({ unsaved: false }),
    );
    fireEvent.click(screen.getByRole("button", { name: "Đóng lệnh" }));
    fireEvent.click(
      screen.getByRole("button", {
        name: "Xem lệnh Thay nguyên liệu Canh bí đỏ thịt bằm",
      }),
    );
    fireEvent.click(screen.getByRole("button", { name: "Hủy lệnh" }));
    await screen.findByRole("dialog", { name: "Hủy lệnh" });
    expect(status).toHaveBeenLastCalledWith(
      expect.objectContaining({ unsaved: false, blocked: true }),
    );
    choose("Lý do hủy", "Không còn áp dụng");
    expect(status).toHaveBeenLastCalledWith(
      expect.objectContaining({ unsaved: true, blocked: true }),
    );
    choose("Lý do hủy", "");
    expect(status).toHaveBeenLastCalledWith(
      expect.objectContaining({ unsaved: false, blocked: true }),
    );
    fireEvent.click(screen.getByRole("button", { name: "Tiếp tục xem lệnh" }));
    await waitFor(() =>
      expect(screen.queryByRole("dialog")).not.toBeInTheDocument(),
    );
    expect(status).toHaveBeenLastCalledWith(
      expect.objectContaining({ unsaved: false, blocked: false }),
    );
  });
  it.each(["ACTIVE", "UNKNOWN_CREATE"] as const)(
    "reports Change Order %s Review and readback resolution",
    async (scenario) => {
      const status = vi.fn();
      const f = await setup(scenario, "changes", status);
      await editor();
      expect(status).toHaveBeenLastCalledWith(
        expect.objectContaining({ unsaved: true, blocked: false }),
      );
      fireEvent.click(screen.getByRole("button", { name: "Xem tác động" }));
      const dialog = await screen.findByRole("dialog", {
        name: "Xem tác động",
      });
      expect(status).toHaveBeenLastCalledWith(
        expect.objectContaining({ unsaved: true, blocked: true }),
      );
      fireEvent.click(
        within(dialog).getByRole("button", { name: "Lưu lệnh điều chỉnh" }),
      );
      if (scenario === "UNKNOWN_CREATE") {
        const recover = await screen.findByRole("button", {
          name: "Tải lại để xác nhận",
        });
        await waitFor(() =>
          expect(status).toHaveBeenLastCalledWith(
            expect.objectContaining({
              unsaved: true,
              blocked: true,
              attention:
                "Atlas chưa thể xác nhận thao tác đã hoàn tất hay chưa.",
            }),
          ),
        );
        await waitFor(() =>
          expect(screen.queryByRole("dialog")).not.toBeInTheDocument(),
        );
        fireEvent.click(recover);
      }
      await waitFor(() =>
        expect(status).toHaveBeenLastCalledWith(
          expect.objectContaining({ unsaved: false, blocked: false }),
        ),
      );
      expect(f.calls.filter((c) => c.name === "create")).toHaveLength(1);
    },
  );
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
      screen.getByRole("button", { name: "Sửa công thức Canh bí đỏ thịt bằm" }),
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
  it.each(["ADD", "REPLACE", "ADJUST_QUANTITY"])(
    "attaches the authoritative Unit to %s quantity without changing payload semantics",
    async (action) => {
      const f = await setup("ACTIVE", "changes", undefined, ({ data }) => {
        data.ingredients[3].purchase_unit_id = "litre";
        data.ingredients[3].purchase_unit_name = "Lít";
        data.units.push({
          unit_id: "litre",
          unit_code: "litre",
          unit_name: "Lít",
          unit_status: "ACTIVE",
        });
      });
      await editor(action);
      if (action === "REPLACE") {
        choose("Định lượng", "change");
        choose("Định lượng mới", "1,5");
      }
      const input = screen.getByLabelText("Định lượng mới");
      expect(input.parentElement).toHaveAccessibleName("Định lượng và đơn vị");
      expect(input).toHaveAccessibleDescription(
        action === "ADJUST_QUANTITY" ? "Kilôgam" : "Lít",
      );
      const unit = document.getElementById(
        input.getAttribute("aria-describedby")!,
      )!;
      expect(input.parentElement).toContainElement(unit);
      expect(
        screen.queryByRole("combobox", { name: "Đơn vị" }),
      ).not.toBeInTheDocument();
      choose("Định lượng mới", "0");
      await waitFor(() =>
        expect(input).toHaveAccessibleErrorMessage(
          /Nhập số thập phân lớn hơn 0/,
        ),
      );
      choose("Định lượng mới", "1,5");
      fireEvent.click(screen.getByRole("button", { name: "Xem tác động" }));
      await screen.findByRole("dialog", { name: "Xem tác động" });
      const request = f.calls.find((call) => call.name === "preview")!
        .payload as { proposed_adjustment: unknown };
      expect(request.proposed_adjustment).toEqual(
        expect.objectContaining({
          quantity_per_basis: 1.5,
          unit_id: action === "ADJUST_QUANTITY" ? null : "litre",
        }),
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
    await waitFor(() => expect(dialog).toHaveAttribute("data-state", "closed"));
    // jsdom does not run the CSS exit animation; deliver its native completion.
    fireEvent(dialog, new Event("animationcancel", { bubbles: true }));
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
