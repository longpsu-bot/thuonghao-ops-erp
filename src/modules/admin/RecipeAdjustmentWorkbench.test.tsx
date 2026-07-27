import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { createReviewRecipeAdjustmentApi } from "../atlas/recipe-adjustments/reviewRecipeAdjustmentApi";
import { createReviewAuthState } from "../atlas/review/reviewMode";
import { RecipeAdjustmentWorkbench } from "./RecipeAdjustmentWorkbench";

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
});

describe("Recipe adjustment and effective BOM workbench", () => {
  it("loads every closed scope/action and immutable lifecycle evidence", async () => {
    render(
      <RecipeAdjustmentWorkbench
        authState={createReviewAuthState("ready")}
        api={createReviewRecipeAdjustmentApi("ready")}
        view="rules"
        mode="review"
      />,
    );
    expect(
      (await screen.findAllByText("Toàn hệ thống · Nguyên liệu")).length,
    ).toBeGreaterThan(0);
    for (const action of [
      "Thêm",
      "Thay thế",
      "Điều chỉnh định lượng",
      "Loại bỏ",
    ])
      expect(screen.getAllByText(action).length).toBeGreaterThan(0);
    expect(screen.getAllByText("Đã hủy").length).toBeGreaterThan(0);
    expect(
      screen.getAllByText(/phiên bản và quan hệ kế nhiệm/i).length,
    ).toBeGreaterThan(0);
    expect(
      screen.queryByRole("button", { name: /^Xóa$/i }),
    ).not.toBeInTheDocument();
  });

  it("previews before save and requires explicit confirmation", async () => {
    vi.spyOn(window, "confirm").mockReturnValue(true);
    render(
      <RecipeAdjustmentWorkbench
        authState={createReviewAuthState("ready")}
        api={createReviewRecipeAdjustmentApi("ready")}
        view="rules"
        mode="review"
      />,
    );
    await screen.findAllByText("Toàn hệ thống · Nguyên liệu");
    fireEvent.change(screen.getByLabelText("Nguyên liệu thêm"), {
      target: { value: "17000000-0000-4000-8000-000000000003" },
    });
    fireEvent.change(screen.getByLabelText("Định lượng theo định mức"), {
      target: { value: "5" },
    });
    fireEvent.change(screen.getByLabelText("Đơn vị"), {
      target: { value: "18000000-0000-4000-8000-000000000001" },
    });
    fireEvent.change(screen.getByLabelText("Lý do bắt buộc"), {
      target: { value: "Bổ sung theo tiêu chuẩn đã duyệt." },
    });
    fireEvent.click(
      screen.getByRole("button", { name: "Xem trước có thẩm quyền" }),
    );
    expect(await screen.findByText(/1 dòng bị ảnh hưởng/)).toBeInTheDocument();
    const save = screen.getByRole("button", { name: "Lưu quy tắc" });
    expect(save).toBeEnabled();
    fireEvent.click(save);
    await waitFor(() => expect(window.confirm).toHaveBeenCalledOnce());
    expect(
      await screen.findByText(/Đã cập nhật dữ liệu xem thử/),
    ).toBeInTheDocument();
  });

  it("supersedes and cancels through explicit reviewed lifecycle commands", async () => {
    vi.spyOn(window, "confirm").mockReturnValue(true);
    vi.spyOn(window, "prompt").mockReturnValue(
      "Dừng áp dụng theo biên bản đã duyệt.",
    );
    const api = createReviewRecipeAdjustmentApi("ready");
    const supersede = vi.spyOn(api, "supersede");
    const cancel = vi.spyOn(api, "cancel");
    render(
      <RecipeAdjustmentWorkbench
        authState={createReviewAuthState("ready")}
        api={api}
        view="rules"
        mode="review"
      />,
    );
    await screen.findAllByText("Toàn hệ thống · Nguyên liệu");

    fireEvent.click(
      screen.getAllByRole("button", { name: "Tạo bản kế nhiệm" })[0],
    );
    fireEvent.change(screen.getByLabelText("Lý do bắt buộc"), {
      target: { value: "Cập nhật theo tiêu chuẩn đã duyệt." },
    });
    fireEvent.click(
      screen.getByRole("button", { name: "Xem trước có thẩm quyền" }),
    );
    await screen.findByText(/1 dòng bị ảnh hưởng/);
    fireEvent.click(screen.getByRole("button", { name: "Lưu bản kế nhiệm" }));
    await waitFor(() => expect(supersede).toHaveBeenCalledOnce());

    fireEvent.click(screen.getAllByRole("button", { name: "Hủy" })[0]);
    await waitFor(() => expect(cancel).toHaveBeenCalledOnce());
    expect(window.prompt).toHaveBeenCalledOnce();
  });

  it("renders precedence, removed-line audit, duplicate and cycle blockers", async () => {
    render(
      <RecipeAdjustmentWorkbench
        authState={createReviewAuthState("ready")}
        api={createReviewRecipeAdjustmentApi("ready")}
        view="effective"
        mode="review"
      />,
    );
    await screen.findByText("BOM hiệu lực");
    fireEvent.click(
      screen.getByRole("button", { name: "Phân giải BOM hiệu lực" }),
    );
    expect(await screen.findByText("Trường · Món")).toBeInTheDocument();
    expect(screen.getByText("4 bước điều chỉnh")).toBeInTheDocument();

    const scenario = screen.getByLabelText("Tình huống kiểm tra");
    fireEvent.change(scenario, { target: { value: "removed" } });
    fireEvent.click(
      screen.getByRole("button", { name: "Phân giải BOM hiệu lực" }),
    );
    expect(await screen.findByText(/Đã loại bỏ/)).toBeInTheDocument();

    fireEvent.change(scenario, { target: { value: "duplicate" } });
    fireEvent.click(
      screen.getByRole("button", { name: "Phân giải BOM hiệu lực" }),
    );
    expect(
      await screen.findByText(/DUPLICATE_EFFECTIVE_INGREDIENT/),
    ).toBeInTheDocument();

    fireEvent.change(scenario, { target: { value: "cycle" } });
    fireEvent.click(
      screen.getByRole("button", { name: "Phân giải BOM hiệu lực" }),
    );
    expect(await screen.findByText(/REPLACEMENT_CYCLE/)).toBeInTheDocument();
  });

  it("shows permission, retry, and session-loss outcomes safely", async () => {
    for (const [scenario, expected] of [
      ["permission_denied", "Bạn không có quyền quản trị quy tắc điều chỉnh."],
      ["server_error", "Yêu cầu xem thử đã bị từ chối an toàn."],
      ["session_lost", "Yêu cầu xem thử đã bị từ chối an toàn."],
    ] as const) {
      const view = render(
        <RecipeAdjustmentWorkbench
          authState={createReviewAuthState("ready")}
          api={createReviewRecipeAdjustmentApi(scenario)}
          view="rules"
          mode="review"
        />,
      );
      expect(await screen.findByText(expected)).toBeInTheDocument();
      view.unmount();
    }
  });

  it("shows a deterministic loading state", async () => {
    render(
      <RecipeAdjustmentWorkbench
        authState={createReviewAuthState("ready")}
        api={createReviewRecipeAdjustmentApi("loading")}
        view="rules"
        mode="review"
      />,
    );
    expect(
      await screen.findByText("Đang tải quy tắc điều chỉnh…"),
    ).toBeInTheDocument();
  });

  it("shows a stale-write outcome after an authenticated preview attempt", async () => {
    render(
      <RecipeAdjustmentWorkbench
        authState={createReviewAuthState("ready")}
        api={createReviewRecipeAdjustmentApi("stale")}
        view="rules"
        mode="review"
      />,
    );
    await screen.findAllByText("Toàn hệ thống · Nguyên liệu");
    fireEvent.change(screen.getByLabelText("Nguyên liệu thêm"), {
      target: { value: "17000000-0000-4000-8000-000000000003" },
    });
    fireEvent.change(screen.getByLabelText("Định lượng theo định mức"), {
      target: { value: "5" },
    });
    fireEvent.change(screen.getByLabelText("Đơn vị"), {
      target: { value: "18000000-0000-4000-8000-000000000001" },
    });
    fireEvent.change(screen.getByLabelText("Lý do bắt buộc"), {
      target: { value: "Bổ sung theo tiêu chuẩn đã duyệt." },
    });
    fireEvent.click(
      screen.getByRole("button", { name: "Xem trước có thẩm quyền" }),
    );
    expect(
      await screen.findByText(
        "Quy tắc đã thay đổi. Hãy tải lại trước khi lưu.",
      ),
    ).toBeInTheDocument();
  });
});
