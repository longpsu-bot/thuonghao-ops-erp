import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
  within,
} from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { AtlasVNextProvider } from "../AtlasVNextProvider";
import { DishRecipeWorkbench } from "./DishRecipeWorkbench";
import {
  createRecipeReviewFixture,
  type RecipeScenario,
} from "./recipeReviewFixtures";
afterEach(cleanup);
async function setup(scenario: RecipeScenario = "DISH_ACTIVE_EDITABLE") {
  const fixture = createRecipeReviewFixture(scenario);
  render(
    <AtlasVNextProvider>
      <DishRecipeWorkbench
        authSubject="operator"
        api={fixture.api}
        initialDate="2026-09-12"
      />
    </AtlasVNextProvider>,
  );
  await waitFor(() =>
    expect(screen.getByRole("button", { name: "Tạo món mới" })).toBeEnabled(),
  );
  return fixture;
}
async function select() {
  fireEvent.click(
    await screen.findByRole("button", {
      name: "Xem công thức Canh bí đỏ thịt bằm",
    }),
  );
  await screen.findByRole("heading", { name: "Công thức gốc" });
}
describe("Công thức operator workbench", () => {
  it("preserves the original review comparison after successful Save loses readback", async () => {
    await setup("SAVE_SUCCESS_READBACK_FAILURE");
    await select();
    fireEvent.change(screen.getByLabelText("Số suất áp dụng cho định lượng"), {
      target: { value: "120" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    fireEvent.click(screen.getByRole("button", { name: "Lưu công thức" }));
    await screen.findByRole("button", { name: "Tải lại để xác nhận" });
    expect(screen.getByText("Số suất: 80 → 120")).toBeInTheDocument();
  });
  it("renders one h1, derived labels, local filters and hidden technical identities", async () => {
    const f = await setup();
    const read = vi.spyOn(f.api, "getWorkbench");
    expect(screen.getAllByRole("heading", { level: 1 })).toHaveLength(1);
    expect(screen.getByRole("heading", { level: 1 })).toHaveTextContent(
      "Công thức",
    );
    expect(screen.queryByRole("tab")).not.toBeInTheDocument();
    expect(screen.queryByText(/hidden-/)).not.toBeInTheDocument();
    fireEvent.change(screen.getByLabelText("Tìm món"), {
      target: { value: "thit heo kho" },
    });
    expect(
      screen.getAllByRole("button", { name: /^Xem công thức / }),
    ).toHaveLength(1);
    fireEvent.change(screen.getByLabelText("Trạng thái"), {
      target: { value: "INACTIVE" },
    });
    expect(
      screen.queryByRole("button", { name: /^Xem công thức / }),
    ).not.toBeInTheDocument();
    expect(read).not.toHaveBeenCalled();
  });
  it("selects a row accessibly, opens base/effective and preserves focus on close", async () => {
    await setup();
    await select();
    const button = screen.getByRole("button", {
      name: "Xem công thức Canh bí đỏ thịt bằm",
    });
    expect(button.closest("tr")).toHaveAttribute("aria-selected", "true");
    expect(
      button.closest("tr")?.querySelector("[data-selection-indicator]"),
    ).toBeTruthy();
    expect(
      screen.getByRole("heading", { name: "Công thức hiệu lực" }),
    ).toBeInTheDocument();
    expect(screen.getByLabelText("Loại công thức")).toHaveTextContent(
      "Khối nhỏ",
    );
    fireEvent.click(screen.getByRole("button", { name: "Đóng công thức" }));
    await waitFor(() => expect(button).toHaveFocus());
  });
  it("shows searchable active Ingredient add, validates quantity/basis and protects removal as a local draft", async () => {
    const f = await setup();
    await select();
    const write = vi.spyOn(f.api, "saveRecipe");
    fireEvent.change(screen.getByLabelText("Tìm nguyên liệu để thêm"), {
      target: { value: "hanh la" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Thêm Hành lá" }));
    fireEvent.change(screen.getByLabelText("Định lượng Hành lá"), {
      target: { value: "0" },
    });
    expect(screen.getByLabelText("Định lượng Hành lá")).toHaveAttribute(
      "aria-invalid",
      "true",
    );
    expect(screen.getByRole("button", { name: "Xem thay đổi" })).toBeDisabled();
    fireEvent.change(screen.getByLabelText("Định lượng Hành lá"), {
      target: { value: "0,5" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Bỏ Bí đỏ" }));
    expect(write).not.toHaveBeenCalled();
    expect(screen.getByText("Đang chỉnh sửa · chưa lưu")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Xem thay đổi" }));
    expect(
      screen.getByRole("heading", { name: "Xem thay đổi" }),
    ).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Lưu công thức" })).toBeEnabled();
  });
  it("requires dirty confirmation and cancel preserves the exact quantity draft", async () => {
    await setup();
    await select();
    fireEvent.change(screen.getByLabelText("Định lượng Bí đỏ"), {
      target: { value: "2,25" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Sửa thông tin món" }));
    const dialog = await screen.findByRole("dialog");
    expect(dialog).toHaveTextContent("Có thay đổi chưa lưu");
    fireEvent.click(
      within(dialog).getByRole("button", { name: "Tiếp tục chỉnh sửa" }),
    );
    await waitFor(() =>
      expect(screen.queryByRole("dialog")).not.toBeInTheDocument(),
    );
    expect(screen.getByLabelText("Định lượng Bí đỏ")).toHaveValue("2,25");
  });
  it("locked base is read-only with future correction guidance and no lifecycle Recipe controls", async () => {
    await setup("DISH_ACTIVE_LOCKED");
    await select();
    expect(
      screen.getByText(/Thay đổi thành phần tiếp theo/),
    ).toBeInTheDocument();
    expect(screen.queryByLabelText("Định lượng Bí đỏ")).not.toBeInTheDocument();
    expect(
      screen.queryByRole("button", {
        name: /Lưu công thức|Tạo bản nháp|Xác thực|Duyệt|Đưa vào sử dụng|kế nhiệm|Lệnh điều chỉnh/,
      }),
    ).not.toBeInTheDocument();
  });
  it("displays authoritative effective differences", async () => {
    await setup("RECIPE_EFFECTIVE_DIFFERS_FROM_BASE");
    await select();
    expect(
      within(
        screen.getByRole("table", { name: "Công thức hiệu lực" }),
      ).getByText("Cà rốt"),
    ).toBeInTheDocument();
    expect(
      within(
        screen.getByRole("table", { name: "Công thức hiệu lực" }),
      ).getByText("19"),
    ).toBeInTheDocument();
    expect(screen.getByLabelText("Định lượng Bí đỏ")).toHaveValue("22,5");
  });
  it("empty catalogue permits business-only Create with no technical fields", async () => {
    await setup("EMPTY_CATALOG");
    fireEvent.click(screen.getByRole("button", { name: "Tạo món mới" }));
    expect(screen.getByRole("button", { name: "Tạo món" })).toBeDisabled();
    expect(
      screen.queryByLabelText(/Mã món|display_order|requires_need_generation/),
    ).not.toBeInTheDocument();
    fireEvent.change(screen.getByLabelText("Tên món"), {
      target: { value: "Món mới" },
    });
    fireEvent.change(screen.getByLabelText("Loại món của món"), {
      target: { value: "type-0" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Tạo món" }));
    await screen.findByRole("heading", { name: "Công thức gốc" });
    expect(
      screen.queryByRole("button", { name: /Tạo công thức cho/ }),
    ).not.toBeInTheDocument();
  });
  it("keeps copy and import secondary dialogs, never top-level jobs", async () => {
    await setup();
    await select();
    fireEvent.click(screen.getByRole("button", { name: "Sao chép công thức" }));
    expect(await screen.findByRole("dialog")).toHaveTextContent(
      "Lý do sao chép",
    );
    expect(
      screen.getByRole("button", { name: "Xác nhận sao chép" }),
    ).toBeDisabled();
  });
});
