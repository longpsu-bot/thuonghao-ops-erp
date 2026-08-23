import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import type { AtlasRpcResult, JsonValue } from "../../connection/atlasRpc";
import type { AtlasAuthState } from "../../connection/authSession";
import { PlanningInputsWorkbench } from "../PlanningInputsWorkbench";
import { createReviewNeedGenerationApi } from "../need-generation/reviewNeedGenerationApi";
import { createReviewPlanningInputReadinessApi } from "../readiness/reviewPlanningInputReadinessApi";
import type { PlanningInputPreflightData } from "../readiness/planningInputReadinessModel";
import type { ConfirmedNeedApi } from "./confirmedNeedApi";
import {
  createReviewConfirmedNeedApi,
  createReviewConfirmedNeedFixture,
} from "./reviewConfirmedNeedApi";

afterEach(cleanup);

const authState = {
  status: "authenticated",
  authSubject: "review-only-atlas-operator",
  user: { id: "review-only-atlas-operator" },
  session: { user: { id: "review-only-atlas-operator" } },
} as unknown as AtlasAuthState;

const defaultBatchId = "c4500000-0000-0000-0000-000000000001";

function readinessWithDailyNeeds(
  needs: Record<
    string,
    {
      batchId: string;
      status?: string;
      currentness?: PlanningInputPreflightData["downstream_currentness"];
    }
  >,
) {
  const api = createReviewPlanningInputReadinessApi("ready");
  const original = api.preflight.bind(api);
  api.preflight = vi.fn(async (auth, correlationId, start, end, sources) => {
    const result = await original(auth, correlationId, start, end, sources);
    if (result.kind !== "success") return result;
    const serviceDate = start;
    const need = needs[serviceDate];
    const preflight = result.response
      .preflight as unknown as PlanningInputPreflightData;
    if (need) {
      preflight.downstream_currentness = need.currentness ?? "CURRENT";
      preflight.current_need = {
        confirmed_need_batch_id: need.batchId,
        confirmed_need_batch_status: need.status ?? "DRAFT_REVIEW",
        confirmed_need_batch_version: 1,
        need_generation_run_id: `run-${serviceDate}`,
        need_generation_run_version: 1,
        need_generation_run_status: "MATERIALIZED",
      };
    }
    return result;
  });
  return api;
}

function confirmedNeedApiForDates(batchDates: Record<string, string>) {
  const api = createReviewConfirmedNeedApi("ready");
  const getReview = vi.fn<ConfirmedNeedApi["getReview"]>(
    async (_subject, correlationId, requestedBatchId) => {
      const serviceDate = batchDates[requestedBatchId];
      if (!serviceDate)
        return {
          kind: "backend_error",
          error: {
            success: false,
            error_code: "CONFIRMED_NEED_BATCH_NOT_FOUND",
            safe_message: "Không tìm thấy nhu cầu xác nhận.",
          },
        } satisfies AtlasRpcResult;
      const workbench = createReviewConfirmedNeedFixture();
      workbench.confirmed_need_batch_id = requestedBatchId;
      workbench.service_period = {
        period_start: serviceDate,
        period_end: serviceDate,
      };
      workbench.lines = workbench.lines.map((line) => ({
        ...line,
        service_date: serviceDate,
      }));
      return {
        kind: "success",
        response: {
          success: true,
          correlation_id: correlationId,
          workbench: workbench as unknown as JsonValue,
        },
      } satisfies AtlasRpcResult;
    },
  );
  return { ...api, getReview };
}

describe("Planning Inputs Confirmed Need tab", () => {
  it("keeps Xác nhận nhu cầu as the first downstream review tab", async () => {
    render(
      <PlanningInputsWorkbench
        authState={authState}
        readinessApi={createReviewPlanningInputReadinessApi("ready")}
        confirmedNeedApi={createReviewConfirmedNeedApi("ready")}
        mode="review"
      />,
    );
    const tabs = screen.getAllByRole("tab");
    expect(tabs).toHaveLength(5);
    expect(tabs[4]).toHaveTextContent("Xác nhận nhu cầu");
    fireEvent.click(tabs[4]!);
    expect(
      await screen.findByText("Chưa có nhu cầu cho tuần đã chọn."),
    ).toBeVisible();
    expect(
      screen.queryByLabelText("Mã lô Confirmed Need"),
    ).not.toBeInTheDocument();
  });

  it("rediscovers one daily Confirmed Need after a fresh mount through seven date-scoped reads", async () => {
    const readinessApi = readinessWithDailyNeeds({
      "2026-08-04": { batchId: defaultBatchId },
    });
    const confirmedNeedApi = createReviewConfirmedNeedApi("ready");
    const getReview = vi.spyOn(confirmedNeedApi, "getReview");
    render(
      <PlanningInputsWorkbench
        authState={authState}
        readinessApi={readinessApi}
        confirmedNeedApi={confirmedNeedApi}
        initialWeekStart="2026-08-03"
        mode="review"
      />,
    );
    const confirmedNeedTab = screen.getByRole("tab", {
      name: "Xác nhận nhu cầu",
    });
    fireEvent.click(confirmedNeedTab);
    await waitFor(() =>
      expect(confirmedNeedTab).toHaveAttribute("aria-selected", "true"),
    );
    expect(await screen.findByText("Gạo thơm")).toBeVisible();
    expect(screen.getByText(/Đang xem ngày/)).toHaveTextContent("04/08/2026");
    expect(readinessApi.preflight).toHaveBeenCalledTimes(7);
    expect(
      vi
        .mocked(readinessApi.preflight)
        .mock.calls.every(
          ([, , periodStart, periodEnd]) => periodStart === periodEnd,
        ),
    ).toBe(true);
    expect(getReview).toHaveBeenCalledWith(
      expect.any(String),
      expect.any(String),
      defaultBatchId,
      expect.any(Object),
      0,
      10_000,
    );
    expect(screen.getByLabelText("Trường")).toHaveDisplayValue("Tất cả trường");
    expect(screen.queryByText(/UUID|Mã lô|Tải lô/i)).not.toBeInTheDocument();
  });

  it("keeps Monday and Wednesday batches independent and opens only the selected date", async () => {
    const mondayBatch = "c4500000-0000-0000-0000-000000000011";
    const wednesdayBatch = "c4500000-0000-0000-0000-000000000013";
    const readinessApi = readinessWithDailyNeeds({
      "2026-08-03": {
        batchId: mondayBatch,
        currentness: "OUTDATED",
      },
      "2026-08-05": { batchId: wednesdayBatch },
    });
    const confirmedNeedApi = confirmedNeedApiForDates({
      [mondayBatch]: "2026-08-03",
      [wednesdayBatch]: "2026-08-05",
    });
    render(
      <PlanningInputsWorkbench
        authState={authState}
        readinessApi={readinessApi}
        confirmedNeedApi={confirmedNeedApi}
        initialWeekStart="2026-08-03"
        mode="review"
      />,
    );

    fireEvent.click(screen.getByRole("tab", { name: "Xác nhận nhu cầu" }));
    const projection = await screen.findByRole("table", {
      name: "Xác nhận nhu cầu theo ngày",
    });
    expect(projection).toHaveTextContent("03/08/2026");
    expect(projection).toHaveTextContent("Nhu cầu cần cập nhật");
    expect(projection).toHaveTextContent("05/08/2026");
    expect(projection).toHaveTextContent("Cần rà soát");
    expect(
      screen.getByText("Chọn ngày phục vụ ở bảng trên để mở nhu cầu xác nhận."),
    ).toBeVisible();

    const wednesdayRow = screen.getByRole("row", {
      name: /05\/08\/2026 Cần rà soát/,
    });
    fireEvent.click(wednesdayRow.querySelector("button") as HTMLButtonElement);

    expect(await screen.findByText("Gạo thơm")).toBeVisible();
    expect(screen.getByText(/Đang xem ngày/)).toHaveTextContent("05/08/2026");
    expect(confirmedNeedApi.getReview).toHaveBeenCalledTimes(1);
    expect(confirmedNeedApi.getReview).toHaveBeenCalledWith(
      expect.any(String),
      expect.any(String),
      wednesdayBatch,
      expect.any(Object),
      0,
      10_000,
    );
    expect(confirmedNeedApi.getReview).not.toHaveBeenCalledWith(
      expect.any(String),
      expect.any(String),
      mondayBatch,
      expect.anything(),
      expect.anything(),
      expect.anything(),
    );
  });

  it("shows a simple message when preflight denies access", async () => {
    render(
      <PlanningInputsWorkbench
        authState={authState}
        readinessApi={createReviewPlanningInputReadinessApi(
          "permission_denied",
        )}
        confirmedNeedApi={createReviewConfirmedNeedApi("ready")}
        mode="review"
      />,
    );
    const confirmedNeedTab = screen.getByRole("tab", {
      name: "Xác nhận nhu cầu",
    });
    fireEvent.click(confirmedNeedTab);
    await waitFor(() =>
      expect(confirmedNeedTab).toHaveAttribute("aria-selected", "true"),
    );
    expect(
      await screen.findByText("Bạn không có quyền xem dữ liệu này."),
    ).toBeVisible();
  });

  it("opens the batch returned by RMVP-04 materialization", async () => {
    render(
      <PlanningInputsWorkbench
        authState={authState}
        needGenerationApi={createReviewNeedGenerationApi("ready")}
        readinessApi={createReviewPlanningInputReadinessApi("ready")}
        confirmedNeedApi={createReviewConfirmedNeedApi("ready")}
        mode="review"
      />,
    );
    fireEvent.click(screen.getAllByRole("tab")[3]!);
    fireEvent.click(
      await screen.findByRole("button", { name: /Tạo nhu cầu$/ }),
    );
    fireEvent.click(
      await screen.findByRole("button", { name: "Mở Xác nhận nhu cầu" }),
    );
    await waitFor(() =>
      expect(
        screen.getByRole("tab", { name: "Xác nhận nhu cầu" }),
      ).toHaveAttribute("aria-selected", "true"),
    );
    expect(await screen.findByText("Gạo thơm")).toBeVisible();
    expect(
      screen.queryByLabelText("Mã lô Confirmed Need"),
    ).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Xuất Excel" })).toBeDisabled();
    expect(screen.queryByText("Nhập Excel")).not.toBeInTheDocument();
  });
});
