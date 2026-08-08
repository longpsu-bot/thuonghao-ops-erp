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
import type { AtlasRpcResult, JsonValue } from "../../connection/atlasRpc";
import { PlanningInputReadinessWorkbench } from "./PlanningInputReadinessWorkbench";
import type { PlanningInputReadinessApi } from "./planningInputReadinessApi";
import {
  planningInputReadinessWorkbenchFromResult,
  type PlanningInputReadinessWorkbenchData,
  type ReadinessHistoryItem,
  type ReadinessIssue,
} from "./planningInputReadinessModel";
import { createReviewPlanningInputReadinessApi } from "./reviewPlanningInputReadinessApi";

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

function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((complete) => {
    resolve = complete;
  });
  return { promise, resolve };
}

function success(
  workbench: PlanningInputReadinessWorkbenchData,
): AtlasRpcResult {
  return {
    kind: "success",
    response: {
      success: true,
      contract_version: "RMVP-03B.v1",
      workbench: workbench as unknown as JsonValue,
    },
  };
}

async function reviewWorkbench(
  scenario: Parameters<typeof createReviewPlanningInputReadinessApi>[0],
  start = "2026-08-03",
  end = "2026-08-09",
) {
  const result = await createReviewPlanningInputReadinessApi(
    scenario,
  ).getWorkbench("review-only-atlas-operator", "correlation", start, end);
  const workbench = planningInputReadinessWorkbenchFromResult(result);
  if (!workbench) throw new Error("Review fixture did not return a workbench.");
  return workbench;
}

describe("RMVP-03B connected workbench", () => {
  it("shows the exact inclusive period, three evidence cards, and source-free handoff", async () => {
    const api = createReviewPlanningInputReadinessApi("ready");
    const evaluate = vi.spyOn(api, "evaluate");
    const request = vi.spyOn(api, "requestNeedGeneration");
    render(
      <PlanningInputReadinessWorkbench
        authState={authState}
        api={api}
        selectedWeekStart="2026-08-03"
        selectedWeekEnd="2026-08-09"
      />,
    );

    expect(
      screen.getByRole("heading", {
        name: "Có thể yêu cầu tạo nhu cầu cho giai đoạn này không?",
      }),
    ).toBeVisible();
    expect(
      await screen.findByText(/Kỳ có thẩm quyền \(bao gồm cả hai ngày\)/),
    ).toHaveTextContent("03/08/2026 – 09/08/2026");
    expect(
      screen.getByRole("heading", { name: "Thực đơn tuần" }),
    ).toBeVisible();
    expect(screen.getByRole("heading", { name: "Sĩ số" })).toBeVisible();
    expect(screen.getByRole("heading", { name: "Pantry" })).toBeVisible();
    expect(screen.getByText("12 dòng Pantry đã phê duyệt.")).toBeVisible();
    expect(screen.getAllByRole("article")).toHaveLength(3);
    expect(
      screen.queryByRole("combobox", { name: /Chọn bằng chứng/ }),
    ).not.toBeInTheDocument();

    const evaluateAction = screen.getByRole("button", {
      name: "Đánh giá mức sẵn sàng",
    });
    expect(evaluateAction).toHaveClass("primary-forward");
    fireEvent.click(evaluateAction);
    await screen.findByText("SẴN SÀNG");
    expect(evaluate).toHaveBeenCalledOnce();

    const requestAction = screen.getByRole("button", {
      name: "Yêu cầu tạo nhu cầu",
    });
    expect(requestAction).toHaveClass("primary-forward");
    fireEvent.click(requestAction);
    await screen.findByText("ĐÃ YÊU CẦU TẠO NHU CẦU");
    expect(request).toHaveBeenCalledOnce();
    const payload = request.mock.calls[0]?.[0].payload;
    expect(payload).toEqual({
      planning_input_set_id: "b6100000-0000-0000-0000-000000000001",
      period_start: "2026-08-03",
      period_end: "2026-08-09",
    });
    expect(payload).not.toHaveProperty("source_candidates");

    fireEvent.click(screen.getByText("Điều chỉnh hoặc vô hiệu hóa kết quả"));
    const note = screen.getByRole("textbox", { name: "Ghi chú vô hiệu" });
    expect(note).toBeRequired();
    expect(
      screen.getByRole("button", {
        name: "Vô hiệu hóa kết quả sẵn sàng",
      }),
    ).toBeDisabled();
    fireEvent.change(note, { target: { value: "Điều chỉnh theo rà soát." } });
    expect(
      screen.getByRole("button", {
        name: "Vô hiệu hóa kết quả sẵn sàng",
      }),
    ).toBeEnabled();
  });

  it("re-reads an ambiguous selection and warns before discarding it", async () => {
    const api = createReviewPlanningInputReadinessApi("menu_duplicate");
    const getWorkbench = vi.spyOn(api, "getWorkbench");
    const confirmDiscard = vi.fn().mockReturnValue(false);
    render(
      <PlanningInputReadinessWorkbench
        authState={authState}
        api={api}
        selectedWeekStart="2026-08-03"
        selectedWeekEnd="2026-08-09"
        confirmDiscard={confirmDiscard}
      />,
    );

    const selector = await screen.findByRole("combobox", {
      name: "Chọn bằng chứng Thực đơn tuần",
    });
    expect(
      screen.getByRole("button", { name: "Đánh giá mức sẵn sàng" }),
    ).toBeDisabled();
    const option = Array.from(selector.querySelectorAll("option"))[1];
    if (!option) throw new Error("Missing ambiguous candidate option.");
    fireEvent.change(selector, { target: { value: option.value } });
    await waitFor(() => expect(getWorkbench).toHaveBeenCalledTimes(2));
    await waitFor(() =>
      expect(
        screen.getByRole("button", { name: "Đánh giá mức sẵn sàng" }),
      ).toBeEnabled(),
    );

    fireEvent.change(screen.getByLabelText("Từ ngày"), {
      target: { value: "2026-08-10" },
    });
    fireEvent.change(screen.getByLabelText("Đến ngày"), {
      target: { value: "2026-08-16" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Đọc đúng kỳ" }));
    expect(confirmDiscard).toHaveBeenCalledOnce();
    expect(screen.getByLabelText("Từ ngày")).toHaveValue("2026-08-10");
    expect(screen.getByText(/Kỳ có thẩm quyền/)).toHaveTextContent(
      "03/08/2026",
    );
  });

  it("disables stale evidence and distinguishes explicit-zero and missing Pantry", async () => {
    const stale = render(
      <PlanningInputReadinessWorkbench
        authState={authState}
        api={createReviewPlanningInputReadinessApi("stale")}
        selectedWeekStart="2026-08-03"
        selectedWeekEnd="2026-08-09"
      />,
    );
    await screen.findByText("ĐÃ CŨ");
    expect(
      screen.getByRole("button", { name: "Đánh giá mức sẵn sàng" }),
    ).toBeDisabled();
    stale.unmount();

    const zero = render(
      <PlanningInputReadinessWorkbench
        authState={authState}
        api={createReviewPlanningInputReadinessApi("attendance_zero")}
        selectedWeekStart="2026-08-03"
        selectedWeekEnd="2026-08-09"
      />,
    );
    expect(
      await screen.findByText("Không có bổ sung Pantry — đã xác nhận rõ ràng."),
    ).toBeVisible();
    zero.unmount();

    render(
      <PlanningInputReadinessWorkbench
        authState={authState}
        api={createReviewPlanningInputReadinessApi("empty")}
        selectedWeekStart="2026-08-03"
        selectedWeekEnd="2026-08-09"
      />,
    );
    expect(
      await screen.findByText("Chưa có bằng chứng Pantry đã phê duyệt."),
    ).toBeVisible();
  });

  it("renders authoritative blockers before warnings", async () => {
    const value = await reviewWorkbench("ready");
    const blocker: ReadinessIssue = {
      planning_input_readiness_issue_id: "blocker-1",
      severity: "BLOCKING",
      issue_code: "BLOCKER",
      safe_message: "Lỗi chặn từ backend",
      input_type: null,
      school_id: null,
      service_date: null,
    };
    const warning: ReadinessIssue = {
      ...blocker,
      planning_input_readiness_issue_id: "warning-1",
      severity: "WARNING",
      issue_code: "WARNING",
      safe_message: "Cảnh báo từ backend",
    };
    value.current_evaluation = {
      planning_input_evaluation_id: "evaluation-1",
      evaluation_version: 1,
      evaluation_result: "NOT_READY",
      blocking_issue_count: 1,
      warning_count: 1,
      evaluated_by_actor_id: "actor-1",
      evaluated_by_display_name: "Operator",
      evaluated_at: "2026-08-01T00:00:00Z",
      source_bindings: { weekly_menu: null, attendance: null, pantry: null },
      issues: { blockers: [blocker], warnings: [warning] },
    };
    const api = {
      ...createReviewPlanningInputReadinessApi("ready"),
      getWorkbench: vi.fn().mockResolvedValue(success(value)),
    };
    render(
      <PlanningInputReadinessWorkbench
        authState={authState}
        api={api}
        selectedWeekStart="2026-08-03"
        selectedWeekEnd="2026-08-09"
      />,
    );
    const blockerText = await screen.findByText("Lỗi chặn từ backend");
    const warningText = screen.getByText("Cảnh báo từ backend");
    expect(
      blockerText.compareDocumentPosition(warningText) &
        Node.DOCUMENT_POSITION_FOLLOWING,
    ).toBeTruthy();
  });

  it("preserves one exact retry request and never retries automatically", async () => {
    const base = createReviewPlanningInputReadinessApi("ready");
    const originalEvaluate = base.evaluate.bind(base);
    const evaluate = vi
      .fn()
      .mockResolvedValueOnce({
        kind: "backend_error",
        error: {
          success: false,
          error_code: "RETRYABLE_CONCURRENCY_FAILURE",
          safe_message: "safe",
          retryable: true,
        },
      } satisfies AtlasRpcResult)
      .mockImplementation(originalEvaluate);
    const api = { ...base, evaluate };
    render(
      <PlanningInputReadinessWorkbench
        authState={authState}
        api={api}
        selectedWeekStart="2026-08-03"
        selectedWeekEnd="2026-08-09"
      />,
    );
    fireEvent.click(
      await screen.findByRole("button", { name: "Đánh giá mức sẵn sàng" }),
    );
    const retry = await screen.findByRole("button", {
      name: "Gửi lại đúng yêu cầu",
    });
    expect(evaluate).toHaveBeenCalledOnce();
    const originalRequest = evaluate.mock.calls[0]?.[0];
    fireEvent.click(retry);
    await screen.findByText("SẴN SÀNG");
    expect(evaluate).toHaveBeenCalledTimes(2);
    expect(evaluate.mock.calls[1]?.[0]).toBe(originalRequest);
  });

  it("treats transport uncertainty as unknown and offers only authoritative refresh", async () => {
    const base = createReviewPlanningInputReadinessApi("ready");
    const evaluate = vi.fn().mockResolvedValue({
      kind: "transport_error",
      diagnostic: { code: "NETWORK_FAILURE", safeMessage: "safe" },
    } satisfies AtlasRpcResult);
    render(
      <PlanningInputReadinessWorkbench
        authState={authState}
        api={{ ...base, evaluate }}
        selectedWeekStart="2026-08-03"
        selectedWeekEnd="2026-08-09"
      />,
    );
    fireEvent.click(
      await screen.findByRole("button", { name: "Đánh giá mức sẵn sàng" }),
    );
    expect(await screen.findByText("Chưa xác định kết quả lệnh")).toBeVisible();
    expect(evaluate).toHaveBeenCalledOnce();
    expect(
      screen.queryByRole("button", { name: "Gửi lại đúng yêu cầu" }),
    ).not.toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "Kiểm tra trạng thái có thẩm quyền" }),
    ).toBeEnabled();
  });

  it("appends history without duplicates and labels historical null-Pantry evidence", async () => {
    const value = await reviewWorkbench("ready");
    const first: ReadinessHistoryItem = {
      history_kind: "NEED_GENERATION_REQUEST",
      history_item_id: "history-1",
      occurred_at: "2026-08-02T00:00:00Z",
    };
    const historical: ReadinessHistoryItem = {
      history_kind: "EVALUATION",
      history_item_id: "history-2",
      occurred_at: "2026-08-01T00:00:00Z",
      evaluation: {
        planning_input_evaluation_id: "historical-evaluation",
        evaluation_version: 1,
        evaluation_result: "READY",
        blocking_issue_count: 0,
        warning_count: 0,
        evaluated_by_actor_id: "actor-1",
        evaluated_by_display_name: "Operator",
        evaluated_at: "2026-08-01T00:00:00Z",
        source_bindings: { weekly_menu: null, attendance: null, pantry: null },
        issues: [],
        historical_pantry_state: "PRE_PANTRY_NULL_BINDING",
        can_authorize_need_generation_request: false,
      },
    };
    const firstPage = {
      ...value,
      history_items: [first],
      history_has_more: true,
      history_next_cursor: "opaque==",
    };
    const secondPage = {
      ...value,
      history_items: [first, historical],
      history_has_more: false,
      history_next_cursor: null,
    };
    const getWorkbench = vi.fn(
      async (
        _subject: string,
        _correlation: string,
        _start: string,
        _end: string,
        _selection?: Record<string, JsonValue>,
        _limit?: number,
        cursor?: string | null,
      ) => success(cursor ? secondPage : firstPage),
    );
    const api = {
      ...createReviewPlanningInputReadinessApi("ready"),
      getWorkbench,
    } satisfies PlanningInputReadinessApi;
    render(
      <PlanningInputReadinessWorkbench
        authState={authState}
        api={api}
        selectedWeekStart="2026-08-03"
        selectedWeekEnd="2026-08-09"
        historyLimit={1}
      />,
    );
    fireEvent.click(await screen.findByText("Lịch sử đánh giá"));
    fireEvent.click(screen.getByRole("button", { name: "Tải thêm lịch sử" }));
    expect(
      await screen.findByText(
        /Đánh giá lịch sử trước khi Pantry được ràng buộc/,
      ),
    ).toBeVisible();
    expect(
      within(
        screen.getByRole("region", { name: "Lịch sử sẵn sàng" }),
      ).getAllByText("Yêu cầu tạo nhu cầu"),
    ).toHaveLength(1);
    expect(getWorkbench.mock.calls[1]?.[6]).toBe("opaque==");
  });

  it("ignores a late read response from a discarded period", async () => {
    const oldValue = await reviewWorkbench("ready", "2026-08-03", "2026-08-09");
    oldValue.decision = "INVALIDATED";
    const newValue = await reviewWorkbench("ready", "2026-08-10", "2026-08-16");
    newValue.decision = "READY";
    const oldPending = deferred<AtlasRpcResult>();
    const newPending = deferred<AtlasRpcResult>();
    const api = {
      ...createReviewPlanningInputReadinessApi("ready"),
      getWorkbench: vi
        .fn()
        .mockImplementationOnce(() => oldPending.promise)
        .mockImplementationOnce(() => newPending.promise),
    };
    render(
      <PlanningInputReadinessWorkbench
        authState={authState}
        api={api}
        selectedWeekStart="2026-08-03"
        selectedWeekEnd="2026-08-09"
      />,
    );
    fireEvent.change(screen.getByLabelText("Từ ngày"), {
      target: { value: "2026-08-10" },
    });
    fireEvent.change(screen.getByLabelText("Đến ngày"), {
      target: { value: "2026-08-16" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Đọc đúng kỳ" }));
    newPending.resolve(success(newValue));
    await screen.findByText("SẴN SÀNG");
    oldPending.resolve(success(oldValue));
    await waitFor(() => expect(screen.getByText("SẴN SÀNG")).toBeVisible());
    expect(screen.queryByText("ĐÃ VÔ HIỆU")).not.toBeInTheDocument();
  });
});
