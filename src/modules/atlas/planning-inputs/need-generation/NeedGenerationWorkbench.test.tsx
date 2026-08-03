import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
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

function renderReview(api = createReviewNeedGenerationApi("ready")) {
  return render(
    <NeedGenerationWorkbench
      authState={authState}
      api={api}
      selectedWeekStart="2026-08-03"
      selectedWeekEnd="2026-08-09"
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
    renderReview(api);

    fireEvent.click(await screen.findByRole("button", { name: "Tạo nhu cầu" }));
    expect(await screen.findByText("Bếp Trường Atlas A")).toBeVisible();
    expect(screen.getByText("Kho phụ Trường Atlas A")).toBeVisible();
    expect(screen.getAllByText("12,5")).toHaveLength(2);
    expect(screen.getAllByText("2")).toHaveLength(2);
    expect(create).toHaveBeenCalledOnce();

    fireEvent.click(screen.getByRole("button", { name: "Kiểm tra nhu cầu" }));
    await waitFor(() => expect(validate).toHaveBeenCalledOnce());
    fireEvent.click(screen.getByRole("button", { name: "Phát hành nhu cầu" }));
    await waitFor(() => expect(release).toHaveBeenCalledOnce());
    fireEvent.click(
      screen.getByRole("button", { name: "Tạo nhu cầu xác nhận" }),
    );
    await waitFor(() => expect(materialize).toHaveBeenCalledOnce());
    expect(await screen.findByText(/DRAFT_REVIEW/)).toBeVisible();
  });

  it("selects an exact period, filters, paginates and drills into atomic detail", async () => {
    const api = createReviewNeedGenerationApi("ready");
    const getWorkbench = vi.spyOn(api, "getWorkbench");
    renderReview(api);
    await screen.findByText("ĐÃ YÊU CẦU TẠO NHU CẦU");
    fireEvent.change(screen.getByLabelText("Từ ngày tạo nhu cầu"), {
      target: { value: "2026-08-04" },
    });
    fireEvent.change(screen.getByLabelText("Đến ngày tạo nhu cầu"), {
      target: { value: "2026-08-08" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Xem kỳ" }));
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
    fireEvent.click(await screen.findByRole("button", { name: "Tạo nhu cầu" }));
    fireEvent.change(screen.getByLabelText("Nguồn"), {
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
      await screen.findByText("Chi tiết đóng góp nguyên tử"),
    ).toBeVisible();
    expect(screen.getByRole("button", { name: "Trang trước" })).toBeDisabled();
    expect(screen.getByRole("button", { name: "Trang sau" })).toBeDisabled();
  });

  it("renders blockers before warnings and exposes backend disabled reasons", async () => {
    const api = createReviewNeedGenerationApi("ready");
    const original = api.getWorkbench.bind(api);
    api.getWorkbench = vi.fn(async (...args: Parameters<typeof original>) => {
      const result = await original(
        args[0],
        args[1],
        args[2],
        args[3],
        args[4],
        args[5],
        args[6],
        args[7],
        args[8],
      );
      if (result.kind === "success") {
        const value = result.response.workbench as Record<string, unknown>;
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
      }
      return result;
    });
    renderReview(api);
    const blocker = await screen.findByText("Lỗi chặn từ backend");
    const warning = screen.getByText("Cảnh báo từ backend");
    expect(
      blocker.compareDocumentPosition(warning) &
        Node.DOCUMENT_POSITION_FOLLOWING,
    ).toBeTruthy();
    expect(
      screen.getByRole("button", { name: "Kiểm tra nhu cầu" }),
    ).toHaveAttribute("title", "Tạo nhu cầu trước.");
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
