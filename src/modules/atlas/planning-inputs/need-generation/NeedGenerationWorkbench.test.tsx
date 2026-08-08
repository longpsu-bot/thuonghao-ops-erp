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
import type { AtlasAuthState } from "../../connection/authSession";
import type { AtlasRpcResult } from "../../connection/atlasRpc";
import { NeedGenerationWorkbench } from "./NeedGenerationWorkbench";
import { createReviewNeedGenerationApi } from "./reviewNeedGenerationApi";

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
});

const authState = {
  status: "authenticated",
  authSubject: "review-only-atlas-operator",
  user: { id: "review-only-atlas-operator" },
  session: {
    access_token: "review",
    refresh_token: "review",
    expires_in: 3600,
    token_type: "bearer",
    user: { id: "review-only-atlas-operator" },
  },
} as unknown as AtlasAuthState;

function renderReview(
  api = createReviewNeedGenerationApi("ready"),
  onConfirmedNeedMaterialized?: (batchId: string) => void,
) {
  return render(
    <NeedGenerationWorkbench
      authState={authState}
      api={api}
      selectedWeekStart="2026-08-03"
      selectedWeekEnd="2026-08-09"
      onConfirmedNeedMaterialized={onConfirmedNeedMaterialized}
    />,
  );
}

describe("RMVP-04 connected workbench", () => {
  it("runs create, validate, release and existing CMD-15 with separated Recipe/Pantry groups", async () => {
    const api = createReviewNeedGenerationApi("ready");
    const create = vi.spyOn(api, "create");
    const validate = vi.spyOn(api, "validate");
    const release = vi.spyOn(api, "release");
    const materialize = vi.spyOn(api, "materialize");
    const onMaterialized = vi.fn();
    renderReview(api, onMaterialized);

    const createAction = await screen.findByRole("button", {
      name: "Tạo nhu cầu",
    });
    expect(createAction).toHaveClass("primary-forward");
    expect(
      screen.queryByRole("button", { name: "Kiểm tra nhu cầu" }),
    ).not.toBeInTheDocument();
    expect(screen.queryByText(/chưa đặt mua hàng/)).not.toBeInTheDocument();
    fireEvent.click(createAction);
    expect(
      await screen.findByRole("heading", {
        name: "Nhu cầu nguyên liệu đã tạo",
      }),
    ).toBeVisible();
    expect(await screen.findByText("Bếp Trường Atlas A")).toBeVisible();
    expect(screen.getByText("Kho phụ Trường Atlas A")).toBeVisible();
    const table = screen.getByRole("table");
    expect(within(table).getAllByText("12,5")).toHaveLength(2);
    expect(within(table).getAllByText("2")).toHaveLength(2);
    expect(create).toHaveBeenCalledOnce();

    const validateAction = screen.getByRole("button", {
      name: "Kiểm tra nhu cầu",
    });
    expect(validateAction).toHaveClass("primary-forward");
    expect(
      screen.queryByRole("button", { name: "Phát hành nhu cầu" }),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: "Tạo nhu cầu xác nhận" }),
    ).not.toBeInTheDocument();
    fireEvent.click(validateAction);
    await waitFor(() => expect(validate).toHaveBeenCalledOnce());
    const releaseAction = screen.getByRole("button", {
      name: "Phát hành nhu cầu",
    });
    expect(releaseAction).toHaveClass("primary-forward");
    expect(
      screen.queryByRole("button", { name: "Kiểm tra nhu cầu" }),
    ).not.toBeInTheDocument();
    fireEvent.click(releaseAction);
    await waitFor(() => expect(release).toHaveBeenCalledOnce());
    const materializeAction = screen.getByRole("button", {
      name: "Tạo nhu cầu xác nhận",
    });
    expect(materializeAction).toHaveClass("primary-forward");
    expect(
      screen.getByText(/chưa đặt mua hàng và chưa chọn nhà cung cấp/),
    ).toBeVisible();
    fireEvent.click(materializeAction);
    await waitFor(() => expect(materialize).toHaveBeenCalledOnce());
    const boundary = await screen.findByText("Kết quả của thao tác");
    const boundarySection = boundary.closest("section");
    if (!boundarySection) throw new Error("Missing materialization boundary.");
    fireEvent.click(within(boundarySection).getByText("Chi tiết kỹ thuật"));
    expect(within(boundarySection).getByText(/DRAFT_REVIEW/)).toBeVisible();
    expect(onMaterialized).toHaveBeenCalledWith(
      "c4500000-0000-0000-0000-000000000001",
    );
  });

  it("shows a handoff-not-requested state without implying that a run exists", async () => {
    const api = createReviewNeedGenerationApi("ready");
    const original = api.getWorkbench.bind(api);
    api.getWorkbench = vi.fn(async (...args: Parameters<typeof original>) => {
      const result = await original(...args);
      if (result.kind === "success") {
        const value = result.response.workbench as Record<string, unknown>;
        const root = value.planning_input_set as Record<string, unknown>;
        root.readiness_status = "READY";
        value.allowed_actions = {
          create: false,
          validate: false,
          release: false,
          materialize: false,
          invalidate: false,
        };
        value.disabled_reasons = {
          create: "Chưa ghi nhận yêu cầu tạo nhu cầu.",
          validate: "Tạo nhu cầu trước.",
          release: "Kiểm tra nhu cầu trước.",
          materialize: "Phát hành nhu cầu trước.",
          invalidate: "Chưa có lần tạo nhu cầu.",
        };
      }
      return result;
    });
    renderReview(api);

    expect(
      await screen.findByRole("heading", { name: "Chưa thể tạo nhu cầu" }),
    ).toBeVisible();
    expect(
      screen.queryByRole("button", { name: "Tạo nhu cầu" }),
    ).not.toBeInTheDocument();
    expect(
      screen.getByRole("heading", { name: "Chưa thể tạo nhu cầu" }),
    ).toBeVisible();
    expect(
      screen.getByText("Chưa ghi nhận yêu cầu tạo nhu cầu."),
    ).toBeVisible();
    expect(screen.queryByText("Kiểm tra nhu cầu")).not.toBeInTheDocument();
    expect(
      screen.queryByRole("heading", { name: "Nhu cầu nguyên liệu đã tạo" }),
    ).not.toBeInTheDocument();
  });

  it("selects an exact period, filters, paginates and drills into atomic detail", async () => {
    const api = createReviewNeedGenerationApi("ready");
    const getWorkbench = vi.spyOn(api, "getWorkbench");
    renderReview(api);
    await screen.findByText("ĐÃ YÊU CẦU TẠO NHU CẦU");
    fireEvent.click(screen.getByText("Đổi phạm vi xem"));
    fireEvent.change(screen.getByLabelText("Từ ngày tạo nhu cầu"), {
      target: { value: "2026-08-04" },
    });
    fireEvent.change(screen.getByLabelText("Đến ngày tạo nhu cầu"), {
      target: { value: "2026-08-08" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Xem phạm vi này" }));
    await waitFor(() =>
      expect(getWorkbench).toHaveBeenCalledWith(
        expect.anything(),
        expect.anything(),
        "2026-08-04",
        "2026-08-08",
        null,
        expect.anything(),
        0,
        100,
        null,
      ),
    );
    const createAction = screen.getByRole("button", { name: "Tạo nhu cầu" });
    await waitFor(() => expect(createAction).toBeEnabled());
    fireEvent.click(createAction);
    fireEvent.change(await screen.findByLabelText("Nguồn"), {
      target: { value: "PANTRY_DIRECT" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Lọc" }));
    await waitFor(() =>
      expect(getWorkbench).toHaveBeenLastCalledWith(
        expect.anything(),
        expect.anything(),
        expect.anything(),
        expect.anything(),
        null,
        expect.objectContaining({ contribution_family: "PANTRY_DIRECT" }),
        0,
        100,
        null,
      ),
    );
    fireEvent.click(screen.getAllByRole("button", { name: "Xem 1" })[0]!);
    expect(
      await screen.findByText("Chi tiết hình thành số lượng"),
    ).toBeVisible();
    expect(screen.getByRole("button", { name: "Trang trước" })).toBeDisabled();
    expect(screen.getByRole("button", { name: "Trang sau" })).toBeDisabled();
  });

  it("renders blockers before warnings and exposes backend disabled reasons", async () => {
    const api = createReviewNeedGenerationApi("ready");
    const originalCreate = api.create.bind(api);
    api.create = vi.fn(async (...args: Parameters<typeof originalCreate>) => {
      const result = await originalCreate(...args);
      if (result.kind === "success") {
        const value = result.response.authoritative_readback as Record<
          string,
          unknown
        >;
        value.blocking_issues = [
          {
            need_generation_issue_id: "blocker",
            issue_code: "MISSING_ELIGIBLE_RECIPE",
            message: "Lỗi chặn từ backend",
          },
        ];
        value.warnings = [
          {
            need_generation_issue_id: "warning",
            issue_code: "ZERO_ACTIVE_THEORETICAL_QUANTITY",
            message: "Cảnh báo từ backend",
          },
        ];
        const run = value.selected_run as Record<string, unknown>;
        run.blocking_issue_count = 1;
        run.warning_count = 1;
        value.allowed_actions = {
          create: false,
          validate: false,
          release: false,
          materialize: false,
          invalidate: true,
        };
        value.disabled_reasons = {
          create: "Đã có lần tạo nhu cầu đang hoạt động.",
          validate: "Cần xử lý lỗi chặn trước khi kiểm tra.",
          release: "Kiểm tra nhu cầu trước.",
          materialize: "Phát hành nhu cầu trước.",
          invalidate: null,
        };
      }
      return result;
    });
    renderReview(api);
    fireEvent.click(await screen.findByRole("button", { name: "Tạo nhu cầu" }));
    const blocker = await screen.findByText("Lỗi chặn từ backend");
    const warning = screen.getByText("Cảnh báo từ backend");
    expect(
      blocker.compareDocumentPosition(warning) &
        Node.DOCUMENT_POSITION_FOLLOWING,
    ).toBeTruthy();
    expect(
      screen.queryByRole("button", { name: "Kiểm tra nhu cầu" }),
    ).not.toBeInTheDocument();
    expect(
      screen.getByText("Cần xử lý lỗi chặn trước khi kiểm tra."),
    ).toBeVisible();
    expect(
      screen.getByRole("heading", { name: "Nhu cầu nguyên liệu đã tạo" }),
    ).toBeVisible();
    expect(screen.getByText("Thao tác khác")).toBeVisible();
  });

  it("never retries automatically and reuses the exact immutable request on demand", async () => {
    const base = createReviewNeedGenerationApi("ready");
    const original = base.create.bind(base);
    const create = vi
      .fn()
      .mockResolvedValueOnce({
        kind: "transport_error",
        diagnostic: { code: "NETWORK_FAILURE", safeMessage: "safe" },
      } satisfies AtlasRpcResult)
      .mockImplementation(original);
    const api = { ...base, create };
    renderReview(api);
    fireEvent.click(await screen.findByRole("button", { name: "Tạo nhu cầu" }));
    const retry = await screen.findByRole("button", {
      name: "Thử lại đúng yêu cầu",
    });
    expect(create).toHaveBeenCalledOnce();
    const exactRequest = create.mock.calls[0]?.[0];
    fireEvent.click(retry);
    await screen.findByText("Bếp Trường Atlas A");
    expect(create).toHaveBeenCalledTimes(2);
    expect(create.mock.calls[1]?.[0]).toBe(exactRequest);
  });

  it("clears stale eligibility and refreshes authoritative state", async () => {
    const base = createReviewNeedGenerationApi("ready");
    const getWorkbench = vi.spyOn(base, "getWorkbench");
    base.create = vi.fn().mockResolvedValue({
      kind: "backend_error",
      error: {
        success: false,
        error_code: "STALE_SOURCE_BINDING",
        safe_message: "stale",
      },
    } satisfies AtlasRpcResult);
    renderReview(base);
    fireEvent.click(await screen.findByRole("button", { name: "Tạo nhu cầu" }));
    await waitFor(() =>
      expect(getWorkbench.mock.calls.length).toBeGreaterThan(1),
    );
    expect(screen.queryByText("Bếp Trường Atlas A")).not.toBeInTheDocument();
  });
});
