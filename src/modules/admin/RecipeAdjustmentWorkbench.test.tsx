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
import { RecipeAdjustmentWorkbench } from "./RecipeAdjustmentWorkbench";

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

function fillSystemIngredientReplacement(dialog: HTMLElement) {
  fireEvent.change(within(dialog).getByLabelText("Nguyên liệu cần thay đổi"), {
    target: { value: "17000000-0000-4000-8000-000000000001" },
  });
  fireEvent.change(within(dialog).getByLabelText("Nguyên liệu mới"), {
    target: { value: "17000000-0000-4000-8000-000000000003" },
  });
  fireEvent.change(within(dialog).getByLabelText("Lý do"), {
    target: { value: "Thay theo tiêu chuẩn nguyên liệu đã duyệt." },
  });
}

describe("Recipe Change Order first-user workbench", () => {
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
    expect(screen.getByText("Không có dữ liệu từ OPS v1")).toBeInTheDocument();

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

  it("opens a create modal and shows only scopes and fields valid for the chosen intent", async () => {
    renderWorkbench();
    const dialog = await openCreateDialog();

    expect(
      within(dialog).getByText("Bạn muốn thay đổi gì?"),
    ).toBeInTheDocument();
    expect(within(dialog).getByText("Áp dụng ở đâu?")).toBeInTheDocument();
    expect(within(dialog).getByLabelText("Thay nguyên liệu")).toBeChecked();
    expect(
      within(dialog).getByLabelText("Mọi món có nguyên liệu này"),
    ).toBeChecked();

    fireEvent.click(within(dialog).getByLabelText("Thêm nguyên liệu"));
    expect(
      within(dialog).queryByLabelText("Mọi món có nguyên liệu này"),
    ).not.toBeInTheDocument();
    expect(
      within(dialog).getByLabelText("Nguyên liệu thêm"),
    ).toBeInTheDocument();
    expect(within(dialog).getByLabelText("Định lượng mới")).toBeInTheDocument();
    expect(within(dialog).getByLabelText("Đơn vị")).toBeInTheDocument();
    expect(
      within(dialog).queryByLabelText("Nguyên liệu mới"),
    ).not.toBeInTheDocument();
  });

  it("requires authoritative preview before save and invalidates it after a material edit", async () => {
    const { api } = renderWorkbench();
    const preview = vi.spyOn(api, "preview");
    const create = vi.spyOn(api, "create");
    const dialog = await openCreateDialog();
    fillSystemIngredientReplacement(dialog);

    const save = within(dialog).getByRole("button", { name: "Lưu điều chỉnh" });
    expect(save).toBeDisabled();
    fireEvent.click(
      within(dialog).getByRole("button", { name: "Xem ảnh hưởng" }),
    );
    expect(
      await within(dialog).findByText("Trước điều chỉnh → Sau điều chỉnh"),
    ).toBeInTheDocument();
    expect(preview).toHaveBeenCalledOnce();
    expect(save).toBeEnabled();

    fireEvent.change(within(dialog).getByLabelText("Lý do"), {
      target: { value: "Lý do đã được cập nhật sau khi xem ảnh hưởng." },
    });
    expect(save).toBeDisabled();
    fireEvent.click(
      within(dialog).getByRole("button", { name: "Xem ảnh hưởng" }),
    );
    await waitFor(() => expect(preview).toHaveBeenCalledTimes(2));
    expect(save).toBeEnabled();
    fireEvent.click(save);
    await waitFor(() => expect(create).toHaveBeenCalledOnce());
  });

  it("explains representative preview context for broad scopes without claiming a global enumeration", async () => {
    renderWorkbench();
    const dialog = await openCreateDialog();
    expect(
      within(dialog).getByText("Bối cảnh dùng để xem ảnh hưởng"),
    ).toBeInTheDocument();
    expect(
      within(dialog).getByLabelText("Trường đại diện"),
    ).toBeInTheDocument();
    expect(within(dialog).getByLabelText("Món đại diện")).toBeInTheDocument();
    expect(within(dialog).getByText(/bối cảnh đại diện/i)).toBeInTheDocument();
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
    expect(within(dialog).getByLabelText("Thay nguyên liệu")).toBeDisabled();
    expect(
      within(dialog).getByLabelText("Nguyên liệu cần thay đổi"),
    ).toBeDisabled();
    fireEvent.change(within(dialog).getByLabelText("Lý do"), {
      target: { value: "Điều chỉnh theo biên bản vận hành mới." },
    });
    fireEvent.click(
      within(dialog).getByRole("button", { name: "Xem ảnh hưởng" }),
    );
    await within(dialog).findByText("Trước điều chỉnh → Sau điều chỉnh");
    fireEvent.click(
      within(dialog).getByRole("button", { name: "Lưu điều chỉnh" }),
    );
    await waitFor(() => expect(supersede).toHaveBeenCalledOnce());
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
