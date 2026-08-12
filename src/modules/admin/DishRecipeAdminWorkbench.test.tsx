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
import type { AtlasRpcResult } from "../atlas/connection/atlasRpc";
import type { RecipeApi } from "../atlas/recipes/recipeApi";
import { createReviewRecipeApi } from "../atlas/recipes/reviewRecipeApi";
import { createReviewRecipeAdjustmentApi } from "../atlas/recipe-adjustments/reviewRecipeAdjustmentApi";
import { createReviewAuthState } from "../atlas/review/reviewMode";
import { DishRecipeAdminWorkbench } from "./DishRecipeAdminWorkbench";

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
});

function renderWorkbench(api: RecipeApi = createReviewRecipeApi("ready")) {
  return render(
    <DishRecipeAdminWorkbench
      authState={createReviewAuthState("ready")}
      api={api}
      adjustmentApi={createReviewRecipeAdjustmentApi("ready")}
      mode="review"
    />,
  );
}

function overrideSelection(
  change: (selected: {
    locked_for_normal_editing: boolean;
    lock_reason: string | null;
    business_status: string;
    allowed_actions: Record<string, boolean>;
    disabled_reason_codes: Record<string, string | null>;
    disabled_reasons: Record<string, string | null>;
  }) => void,
) {
  const base = createReviewRecipeApi("ready");
  const getWorkbench = base.getWorkbench;
  return {
    ...base,
    async getWorkbench(...args: Parameters<RecipeApi["getWorkbench"]>) {
      const result = await getWorkbench(...args);
      if (result.kind !== "success") return result;
      const workbench = (result.response.workbench ?? result.response) as {
        selected_recipe: Parameters<typeof change>[0];
      };
      change(workbench.selected_recipe);
      return result;
    },
  } satisfies RecipeApi;
}

async function openCreation() {
  fireEvent.click(
    await screen.findByRole("tab", { name: "Tạo món & công thức" }),
  );
  await screen.findByRole("heading", { name: "Tạo món & công thức" });
}

describe("Recipe creation-and-lock workbench", () => {
  it("opens on a read-only current-effective catalog with useful Recipe information", async () => {
    renderWorkbench();

    expect(
      await screen.findByRole("tab", { name: "Danh sách", selected: true }),
    ).toBeInTheDocument();
    expect(screen.getAllByText("Canh bí đỏ thịt bằm")).not.toHaveLength(0);
    expect(screen.getByText(/Bí đỏ.*Thịt heo xay/)).toBeInTheDocument();
    expect(
      screen.getByText(/Danh sách này chỉ để tra cứu/),
    ).toBeInTheDocument();
    expect(screen.getAllByRole("button", { name: "Xem" })).not.toHaveLength(0);
    for (const forbidden of [
      "Sửa",
      "Xác thực",
      "Đưa vào sử dụng",
      "Tạo phiên bản kế nhiệm",
    ]) {
      expect(screen.queryByRole("button", { name: forbidden })).toBeNull();
    }
  });

  it("filters the catalog by Dish code and current Ingredient name", async () => {
    renderWorkbench();
    const search = await screen.findByPlaceholderText(
      "Tìm theo tên món, mã món hoặc nguyên liệu…",
    );
    fireEvent.change(search, { target: { value: "thịt heo" } });
    const catalog = screen.getByRole("table");
    expect(
      within(catalog).getByText("Canh bí đỏ thịt bằm"),
    ).toBeInTheDocument();
    expect(within(catalog).queryByText("Cơm trắng")).toBeNull();

    fireEvent.change(search, { target: { value: "com-trang" } });
    expect(within(catalog).getByText("Cơm trắng")).toBeInTheDocument();
    expect(within(catalog).queryByText("Canh bí đỏ thịt bằm")).toBeNull();
  });

  it("keeps creation as a distinct job with Dish context, scope and basis", async () => {
    renderWorkbench();
    await openCreation();

    expect(
      await screen.findByRole("heading", { name: "Canh bí đỏ thịt bằm" }),
    ).toBeInTheDocument();
    expect(screen.getByText(/Loại món: Món canh/)).toBeInTheDocument();
    expect(screen.getByLabelText("Áp dụng cho")).toHaveValue("");
    expect(screen.getByLabelText("Số suất áp dụng cho định lượng")).toHaveValue(
      100,
    );
    expect(screen.getAllByText("Sẵn sàng cho Lập nhu cầu")).not.toHaveLength(0);
    expect(
      screen.queryByRole("button", { name: "Đưa vào sử dụng" }),
    ).toBeNull();
  });

  it("searches loaded active Ingredients without a huge select", async () => {
    renderWorkbench();
    await openCreation();
    const search = screen.getByPlaceholderText("Tìm nguyên liệu để thêm…");
    fireEvent.change(search, { target: { value: "hành" } });
    fireEvent.click(screen.getByRole("option", { name: /Hành lá/ }));

    expect(screen.getByText("Hành lá")).toBeInTheDocument();
    expect(screen.queryByText("Hành lá (hanh-la)")).toBeNull();
    expect(screen.getAllByText("Có thay đổi chưa lưu")).not.toHaveLength(0);
  });

  it("uses Copy only as a helper that fills the current creation form", async () => {
    renderWorkbench();
    await openCreation();
    fireEvent.click(screen.getByRole("button", { name: "Sao chép công thức" }));

    expect(
      screen.getByRole("dialog", { name: "Sao chép công thức" }),
    ).toBeInTheDocument();
    fireEvent.change(screen.getByLabelText("Chọn công thức nguồn"), {
      target: { value: "30000000-0000-4000-8000-000000000001" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Dùng công thức này" }));

    expect(screen.queryByRole("dialog")).toBeNull();
    expect(
      screen.getByRole("heading", { name: "Tạo món & công thức" }),
    ).toBeInTheDocument();
    expect(screen.getByText(/Đã sao chép nội dung/)).toBeInTheDocument();
    expect(screen.getAllByText("Có thay đổi chưa lưu")).not.toHaveLength(0);
  });

  it("keeps a newly created Dish active so its initial Recipe can be copied and saved", async () => {
    const api = createReviewRecipeApi("ready");
    const createDish = vi.spyOn(api, "createDish");
    const saveRecipe = vi.spyOn(api, "saveRecipe");
    renderWorkbench(api);
    await openCreation();

    fireEvent.click(screen.getByRole("button", { name: "Tạo món mới" }));
    fireEvent.change(screen.getByLabelText("Mã món"), {
      target: { value: "mon-moi-03a" },
    });
    fireEvent.change(screen.getByLabelText("Tên món"), {
      target: { value: "Món mới 03A" },
    });
    fireEvent.change(screen.getByLabelText("Loại món"), {
      target: { value: "80000000-0000-4000-8000-000000000001" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Lưu món ăn" }));

    await waitFor(() => expect(createDish).toHaveBeenCalledTimes(1));
    expect(
      screen.getByRole("tab", { name: "Tạo món & công thức", selected: true }),
    ).toBeInTheDocument();
    expect(
      await screen.findByRole("heading", { name: "Món mới 03A" }),
    ).toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "Sao chép công thức" }));
    fireEvent.change(screen.getByLabelText("Chọn công thức nguồn"), {
      target: { value: "30000000-0000-4000-8000-000000000001" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Dùng công thức này" }));
    expect(screen.getAllByText("Có thay đổi chưa lưu")).not.toHaveLength(0);

    fireEvent.click(screen.getByRole("button", { name: "Tạo" }));
    await waitFor(() => expect(saveRecipe).toHaveBeenCalledTimes(1));
    expect(
      screen.getByRole("tab", { name: "Tạo món & công thức", selected: true }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("heading", { name: "Món mới 03A" }),
    ).toBeInTheDocument();
  });

  it("Save makes an eligible pre-use Recipe available through one backend command", async () => {
    const base = createReviewRecipeApi("ready");
    const saveRecipe = vi.spyOn(base, "saveRecipe");
    const releaseRecipe = vi.spyOn(base, "releaseRecipe");
    renderWorkbench(base);
    await openCreation();
    fireEvent.change(screen.getByLabelText(/Định lượng Bí đỏ/), {
      target: { value: "24" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));

    await waitFor(() =>
      expect(screen.getAllByText("Sẵn sàng cho Lập nhu cầu")).not.toHaveLength(
        0,
      ),
    );
    expect(saveRecipe).toHaveBeenCalledTimes(1);
    expect(releaseRecipe).not.toHaveBeenCalled();
    expect(
      screen.queryByRole("button", { name: "Đưa vào sử dụng" }),
    ).toBeNull();
  });

  it("renders an operationally used identity read-only and directs it to Change Order", async () => {
    const api = overrideSelection((selected) => {
      selected.locked_for_normal_editing = true;
      selected.lock_reason =
        "Món này đã có trong thực đơn đã duyệt. Muốn thay đổi công thức, hãy dùng Điều chỉnh.";
      selected.business_status = "LOCKED";
      selected.allowed_actions.save_recipe = false;
      selected.disabled_reason_codes.save_recipe = "SAVE_OPERATIONALLY_LOCKED";
      selected.disabled_reasons.save_recipe = selected.lock_reason;
    });
    const saveRecipe = vi.spyOn(api, "saveRecipe");
    renderWorkbench(api);
    await openCreation();

    expect(screen.getByRole("alert")).toHaveTextContent(
      "Món này đã có trong thực đơn đã duyệt. Muốn thay đổi công thức, hãy dùng Điều chỉnh.",
    );
    expect(screen.getByLabelText(/Định lượng Bí đỏ/)).toBeDisabled();
    expect(
      screen.getByPlaceholderText("Tìm nguyên liệu để thêm…"),
    ).toBeDisabled();
    expect(screen.getByRole("button", { name: "Lưu" })).toBeDisabled();
    fireEvent.click(screen.getByRole("button", { name: "Đi đến Điều chỉnh" }));
    expect(
      await screen.findByRole("tab", { name: "Điều chỉnh", selected: true }),
    ).toBeInTheDocument();
    expect(saveRecipe).not.toHaveBeenCalled();
  });

  it("does not silently discard unsaved work when changing Dish or navigation", async () => {
    const confirm = vi.spyOn(window, "confirm").mockReturnValue(false);
    renderWorkbench();
    await openCreation();
    fireEvent.change(screen.getByLabelText(/Định lượng Bí đỏ/), {
      target: { value: "24" },
    });

    fireEvent.click(screen.getByRole("option", { name: /Cơm trắng/ }));
    expect(
      screen.getByRole("heading", { name: "Canh bí đỏ thịt bằm" }),
    ).toBeInTheDocument();

    fireEvent.click(screen.getByRole("tab", { name: "Danh sách" }));
    expect(
      screen.getByRole("tab", { name: "Tạo món & công thức", selected: true }),
    ).toBeInTheDocument();
    expect(confirm).toHaveBeenCalledTimes(2);
  });

  it("requires authoritative refresh after an unknown Save outcome and never retries", async () => {
    const base = createReviewRecipeApi("ready");
    const saveRecipe = vi.fn(async (): Promise<AtlasRpcResult> => ({
      kind: "transport_error",
      diagnostic: {
        code: "NETWORK_FAILURE",
        safeMessage: "The local Supabase service could not be reached.",
      },
    }));
    renderWorkbench({ ...base, saveRecipe });
    await openCreation();
    fireEvent.change(screen.getByLabelText(/Định lượng Bí đỏ/), {
      target: { value: "24" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));

    expect(
      await screen.findByText(/Chưa xác định thao tác vừa rồi đã hoàn tất/),
    ).toBeVisible();
    expect(screen.getByRole("button", { name: "Lưu" })).toBeDisabled();
    expect(saveRecipe).toHaveBeenCalledTimes(1);
    fireEvent.click(screen.getByRole("button", { name: "Tải lại" }));
    await waitFor(() =>
      expect(
        screen.queryByText(/Chưa xác định thao tác vừa rồi đã hoàn tất/),
      ).not.toBeInTheDocument(),
    );
    expect(saveRecipe).toHaveBeenCalledTimes(1);
  });

  it("keeps technical version evidence behind support history disclosure", async () => {
    renderWorkbench();
    await openCreation();
    const history = screen.getByText("Lịch sử công thức");
    expect(history.closest("details")).not.toHaveAttribute("open");
    expect(screen.getByText(/Số lưu trữ:/)).not.toBeVisible();
    fireEvent.click(history);
    fireEvent.click(screen.getByText("Chi tiết hỗ trợ"));
    expect(screen.getByText(/Số lưu trữ:/)).toBeVisible();
  });
});
