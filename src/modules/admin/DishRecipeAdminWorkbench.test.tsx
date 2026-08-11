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

function denyAction(action: "save_recipe" | "release_recipe") {
  const base = createReviewRecipeApi("ready");
  const getWorkbench = base.getWorkbench;
  return {
    ...base,
    async getWorkbench(...args: Parameters<RecipeApi["getWorkbench"]>) {
      const result = await getWorkbench(...args);
      if (result.kind !== "success") return result;
      const workbench = (result.response.workbench ??
        result.response) as unknown as {
        selected_recipe: {
          allowed_actions: Record<string, boolean>;
          disabled_reason_codes: Record<string, string | null>;
          disabled_reasons: Record<string, string | null>;
        };
      };
      workbench.selected_recipe.allowed_actions[action] = false;
      workbench.selected_recipe.disabled_reason_codes[action] =
        "CAPABILITY_REQUIRED";
      workbench.selected_recipe.disabled_reasons[action] =
        action === "save_recipe"
          ? "Bạn chưa có quyền lưu công thức."
          : "Bạn chưa có quyền đưa công thức vào sử dụng.";
      return result;
    },
  } satisfies RecipeApi;
}

describe("Recipe first-user workbench", () => {
  it("makes the selected Dish, scope, basis, saved state and two human actions obvious", async () => {
    renderWorkbench();

    expect(
      await screen.findByRole("heading", { name: "Canh bí đỏ thịt bằm" }),
    ).toBeInTheDocument();
    expect(screen.getByText(/Loại món: Món canh/)).toBeInTheDocument();
    expect(screen.getByLabelText("Áp dụng cho")).toHaveValue("");
    expect(
      screen.getByRole("option", { name: "Tiểu học" }),
    ).toBeInTheDocument();
    expect(screen.getByLabelText("Số suất áp dụng cho định lượng")).toHaveValue(
      100,
    );
    expect(screen.getAllByText("Đã lưu")).not.toHaveLength(0);
    expect(screen.getByRole("button", { name: "Lưu" })).toBeDisabled();
    expect(
      screen.getByRole("button", { name: "Đưa vào sử dụng" }),
    ).toBeEnabled();
  });

  it("filters the Dish finder by human-readable name and code", async () => {
    renderWorkbench();
    const search = await screen.findByPlaceholderText(
      "Tìm theo tên hoặc mã món…",
    );
    fireEvent.change(search, { target: { value: "com-trang" } });

    const finder = screen.getByLabelText("Tìm món ăn");
    expect(
      within(finder).getByRole("option", { name: /Cơm trắng/ }),
    ).toBeInTheDocument();
    expect(
      within(finder).queryByRole("option", { name: /Canh bí đỏ/ }),
    ).not.toBeInTheDocument();
  });

  it("searches loaded Ingredients and adds the selected result", async () => {
    renderWorkbench();
    const search = await screen.findByPlaceholderText(
      "Tìm nguyên liệu để thêm…",
    );
    fireEvent.change(search, { target: { value: "hành" } });
    fireEvent.click(screen.getByRole("option", { name: /Hành lá/ }));

    expect(screen.getByText("Hành lá (hanh-la)")).toBeInTheDocument();
    expect(screen.getAllByText("Có thay đổi chưa lưu")).not.toHaveLength(0);
  });

  it("uses Lưu as the normal action and Save never puts the Recipe into use", async () => {
    renderWorkbench();
    const quantity = await screen.findByLabelText(/Định lượng Bí đỏ/);
    fireEvent.change(quantity, { target: { value: "24" } });
    const save = screen.getByRole("button", { name: "Lưu" });
    expect(save).toBeEnabled();
    expect(save).toHaveClass("primary");
    fireEvent.click(save);

    await waitFor(() =>
      expect(screen.getAllByText("Đã lưu")).not.toHaveLength(0),
    );
    expect(screen.queryByText("Đang sử dụng")).not.toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "Đưa vào sử dụng" }),
    ).toBeEnabled();
  });

  it("puts the current saved Recipe into use through one commitment action", async () => {
    vi.spyOn(window, "confirm").mockReturnValue(true);
    renderWorkbench();
    fireEvent.click(
      await screen.findByRole("button", { name: "Đưa vào sử dụng" }),
    );

    await waitFor(() =>
      expect(screen.getAllByText("Đang sử dụng")).not.toHaveLength(0),
    );
    expect(window.confirm).toHaveBeenCalledTimes(1);
  });

  it("does not expose validation, successor, or Recipe Version controls in normal editing", async () => {
    renderWorkbench();
    await screen.findByRole("heading", { name: "Công thức" });

    expect(screen.queryByRole("button", { name: "Xác thực" })).toBeNull();
    expect(
      screen.queryByRole("button", { name: "Tạo phiên bản kế nhiệm" }),
    ).toBeNull();
    expect(screen.queryByRole("tab", { name: /Phiên bản/ })).toBeNull();
    expect(screen.queryByText(/Xác thực:/)).toBeNull();
    expect(screen.queryByText(/Phát hành:/)).toBeNull();
  });

  it("never promotes backend-denied Save eligibility", async () => {
    renderWorkbench(denyAction("save_recipe"));
    const quantity = await screen.findByLabelText(/Định lượng Bí đỏ/);
    fireEvent.change(quantity, { target: { value: "24" } });

    expect(screen.getByRole("button", { name: "Lưu" })).toBeDisabled();
    expect(screen.getByText("Bạn chưa có quyền lưu công thức.")).toBeVisible();
  });

  it("never promotes backend-denied put-into-use eligibility", async () => {
    renderWorkbench(denyAction("release_recipe"));

    expect(
      await screen.findByRole("button", { name: "Đưa vào sử dụng" }),
    ).toBeDisabled();
    expect(
      screen.getByText("Bạn chưa có quyền đưa công thức vào sử dụng."),
    ).toBeVisible();
  });

  it("uses local invalid state only to make backend eligibility stricter", async () => {
    renderWorkbench();
    const quantity = await screen.findByLabelText(/Định lượng Bí đỏ/);
    fireEvent.change(quantity, { target: { value: "0" } });

    expect(screen.getByRole("button", { name: "Lưu" })).toBeDisabled();
    expect(
      screen.getByRole("button", { name: "Đưa vào sử dụng" }),
    ).toBeDisabled();
    expect(
      screen.getByText(/Kiểm tra lại định lượng, đơn vị và nguyên liệu trùng/),
    ).toBeVisible();
  });

  it("requires authoritative refresh after an unknown write outcome and never auto-retries", async () => {
    const base = createReviewRecipeApi("ready");
    const saveRecipe = vi.fn(async (): Promise<AtlasRpcResult> => ({
      kind: "transport_error",
      diagnostic: {
        code: "NETWORK_FAILURE",
        safeMessage: "The local Supabase service could not be reached.",
      },
    }));
    renderWorkbench({ ...base, saveRecipe });
    fireEvent.change(await screen.findByLabelText(/Định lượng Bí đỏ/), {
      target: { value: "24" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));

    expect(
      await screen.findByText(/Chưa xác định thao tác vừa rồi đã hoàn tất/),
    ).toBeVisible();
    expect(screen.getByRole("button", { name: "Lưu" })).toBeDisabled();
    expect(
      screen.getByRole("button", { name: "Đưa vào sử dụng" }),
    ).toBeDisabled();
    expect(saveRecipe).toHaveBeenCalledTimes(1);

    fireEvent.click(screen.getByRole("button", { name: "Tải lại" }));
    await waitFor(() =>
      expect(
        screen.queryByText(/Chưa xác định thao tác vừa rồi đã hoàn tất/),
      ).not.toBeInTheDocument(),
    );
    expect(saveRecipe).toHaveBeenCalledTimes(1);
  });

  it("keeps technical version evidence behind Recipe history disclosure", async () => {
    renderWorkbench();
    const history = await screen.findByText("Lịch sử công thức");
    expect(history.closest("details")).not.toHaveAttribute("open");
    expect(screen.getByText(/Số lưu trữ:/)).not.toBeVisible();
    fireEvent.click(history);
    fireEvent.click(screen.getByText("Chi tiết hỗ trợ"));
    expect(screen.getByText(/Số lưu trữ:/)).toBeVisible();
  });
});
