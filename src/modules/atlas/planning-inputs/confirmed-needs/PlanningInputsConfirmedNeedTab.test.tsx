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
  options: { noDemandDates?: string[] } = {},
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
    if (options.noDemandDates?.includes(serviceDate)) {
      preflight.readiness_state = "BLOCKED";
      preflight.blocking_issue_count = 1;
      preflight.current_need = null;
      preflight.issues = [
        {
          severity: "BLOCKING",
          issue_code: "NO_NEED_SOURCE_FOR_SERVICE_DATE",
          message: "Không có nhu cầu cần lập cho ngày này.",
          input_type: "NEED_GENERATION",
          school_id: null,
          service_date: serviceDate,
        },
      ];
    }
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

function confirmedNeedApiForDates(
  batchDates: Record<string, string>,
  options: { releaseEligible?: boolean } = {},
) {
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
      if (options.releaseEligible) {
        workbench.allowed_actions.release_confirmed_needs = true;
        workbench.disabled_reason_codes.release_confirmed_needs = null;
        workbench.disabled_reasons.release_confirmed_needs = null;
      }
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
    expect(tabs).toHaveLength(4);
    expect(tabs[3]).toHaveTextContent("Xác nhận nhu cầu");
    fireEvent.click(tabs[3]!);
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
    expect(
      screen.getByRole("button", { name: "Phạm vi trường" }),
    ).toHaveTextContent("Tất cả trường");
    expect(screen.queryByText(/UUID|Mã lô|Tải lô/i)).not.toBeInTheDocument();
  });

  it("resets Monday search state when opening the independent Wednesday batch", async () => {
    const mondayBatch = "c4500000-0000-0000-0000-000000000011";
    const wednesdayBatch = "c4500000-0000-0000-0000-000000000013";
    const readinessApi = readinessWithDailyNeeds({
      "2026-08-03": {
        batchId: mondayBatch,
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
        needGenerationApi={createReviewNeedGenerationApi("ready")}
        readinessApi={readinessApi}
        confirmedNeedApi={confirmedNeedApi}
        initialWeekStart="2026-08-03"
        mode="review"
      />,
    );

    fireEvent.click(screen.getByRole("tab", { name: "Xác nhận nhu cầu" }));
    const projection = await screen.findByRole("table", {
      name: "Tổng quan nhu cầu theo ngày",
    });
    expect(projection).toHaveTextContent("03/08/2026");
    expect(projection).toHaveTextContent("05/08/2026");
    expect(projection).toHaveTextContent("Chờ xác nhận");
    expect(projection).toHaveTextContent("Mở xác nhận");
    expect(
      screen.getByText("Chọn ngày phục vụ ở bảng trên để mở nhu cầu xác nhận."),
    ).toBeVisible();

    const mondayRow = screen.getByRole("row", {
      name: /03\/08\/2026.*Chờ xác nhận.*Mở xác nhận/,
    });
    fireEvent.click(mondayRow.querySelector("button") as HTMLButtonElement);
    const search = await screen.findByPlaceholderText(
      "Tìm theo nguyên liệu, trường, điểm giao…",
    );
    fireEvent.change(search, { target: { value: "Nguyễn Du" } });
    expect(search).toHaveValue("Nguyễn Du");

    const wednesdayRow = screen.getByRole("row", {
      name: /05\/08\/2026.*Chờ xác nhận.*Mở xác nhận/,
    });
    fireEvent.click(wednesdayRow.querySelector("button") as HTMLButtonElement);

    await waitFor(() =>
      expect(
        screen.getByPlaceholderText("Tìm theo nguyên liệu, trường, điểm giao…"),
      ).toHaveValue(""),
    );
    expect(screen.getByText(/Đang xem ngày/)).toHaveTextContent("05/08/2026");
    expect(confirmedNeedApi.getReview).toHaveBeenCalledTimes(2);
    expect(confirmedNeedApi.getReview).toHaveBeenNthCalledWith(
      1,
      expect.any(String),
      expect.any(String),
      mondayBatch,
      expect.any(Object),
      0,
      10_000,
    );
    expect(confirmedNeedApi.getReview).toHaveBeenNthCalledWith(
      2,
      expect.any(String),
      expect.any(String),
      wednesdayBatch,
      expect.any(Object),
      0,
      10_000,
    );
  });

  it("disarms Monday release confirmation when switching to Wednesday", async () => {
    const mondayBatch = "c4500000-0000-0000-0000-000000000021";
    const wednesdayBatch = "c4500000-0000-0000-0000-000000000023";
    const readinessApi = readinessWithDailyNeeds({
      "2026-08-03": { batchId: mondayBatch },
      "2026-08-05": { batchId: wednesdayBatch },
    });
    const confirmedNeedApi = confirmedNeedApiForDates(
      {
        [mondayBatch]: "2026-08-03",
        [wednesdayBatch]: "2026-08-05",
      },
      { releaseEligible: true },
    );
    const release = vi.spyOn(confirmedNeedApi, "releaseSaved");
    render(
      <PlanningInputsWorkbench
        authState={authState}
        needGenerationApi={createReviewNeedGenerationApi("ready")}
        readinessApi={readinessApi}
        confirmedNeedApi={confirmedNeedApi}
        initialWeekStart="2026-08-03"
        mode="review"
      />,
    );

    fireEvent.click(screen.getByRole("tab", { name: "Xác nhận nhu cầu" }));
    const projection = await screen.findByRole("table", {
      name: "Tổng quan nhu cầu theo ngày",
    });
    const mondayRow = within(projection).getByRole("row", {
      name: /03\/08\/2026.*Chờ xác nhận.*Mở xác nhận/,
    });
    fireEvent.click(mondayRow.querySelector("button") as HTMLButtonElement);
    fireEvent.click(
      await screen.findByRole("button", { name: "Chuyển sang lên đơn" }),
    );
    expect(
      screen.getByRole("dialog", { name: "Xác nhận chuyển sang lên đơn" }),
    ).toBeVisible();

    const wednesdayRow = within(projection).getByRole("row", {
      name: /05\/08\/2026.*Chờ xác nhận.*Mở xác nhận/,
    });
    fireEvent.click(wednesdayRow.querySelector("button") as HTMLButtonElement);

    await waitFor(() =>
      expect(screen.getByText(/Đang xem ngày/)).toHaveTextContent("05/08/2026"),
    );
    expect(
      screen.queryByRole("dialog", { name: "Xác nhận chuyển sang lên đơn" }),
    ).not.toBeInTheDocument();
    expect(release).not.toHaveBeenCalled();
  });

  it("disarms a stale Confirmed Need when the global service date changes", async () => {
    const mondayBatch = "c4500000-0000-0000-0000-000000000031";
    const readinessApi = readinessWithDailyNeeds(
      {
        "2026-08-24": { batchId: mondayBatch },
      },
      { noDemandDates: ["2026-08-25"] },
    );
    const confirmedNeedApi = confirmedNeedApiForDates(
      { [mondayBatch]: "2026-08-24" },
      { releaseEligible: true },
    );
    render(
      <PlanningInputsWorkbench
        authState={authState}
        needGenerationApi={createReviewNeedGenerationApi("ready")}
        readinessApi={readinessApi}
        confirmedNeedApi={confirmedNeedApi}
        initialWeekStart="2026-08-24"
        mode="review"
      />,
    );

    fireEvent.click(screen.getByRole("tab", { name: "Xác nhận nhu cầu" }));
    expect(await screen.findByText(/Đang xem ngày/)).toHaveTextContent(
      "24/08/2026",
    );
    expect(
      await screen.findByRole("textbox", {
        name: "Số lượng xác nhận Gạo thơm",
      }),
    ).toBeVisible();
    expect(
      await screen.findByRole("button", { name: "Chuyển sang lên đơn" }),
    ).toBeVisible();

    fireEvent.click(screen.getByRole("tab", { name: "Thực đơn" }));
    const serviceDate = screen.getByLabelText("Ngày phục vụ");
    fireEvent.change(serviceDate, { target: { value: "2026-08-25" } });
    expect(serviceDate).toHaveValue("2026-08-25");
    fireEvent.click(screen.getByRole("tab", { name: "Xác nhận nhu cầu" }));

    const projection = await screen.findByRole("table", {
      name: "Tổng quan nhu cầu theo ngày",
    });
    expect(
      within(projection).getByRole("row", {
        name: /25\/08\/2026.*Không có nhu cầu cần lập/,
      }),
    ).toBeVisible();
    expect(screen.queryByText(/Đang xem ngày/)).not.toBeInTheDocument();
    expect(
      screen.queryByRole("textbox", { name: "Số lượng xác nhận Gạo thơm" }),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: "Chuyển sang lên đơn" }),
    ).not.toBeInTheDocument();
  });

  it("realigns the global service date when opening a Confirmed Need row", async () => {
    const mondayBatch = "c4500000-0000-0000-0000-000000000041";
    const readinessApi = readinessWithDailyNeeds({
      "2026-08-24": { batchId: mondayBatch },
    });
    const confirmedNeedApi = confirmedNeedApiForDates({
      [mondayBatch]: "2026-08-24",
    });
    render(
      <PlanningInputsWorkbench
        authState={authState}
        needGenerationApi={createReviewNeedGenerationApi("ready")}
        readinessApi={readinessApi}
        confirmedNeedApi={confirmedNeedApi}
        initialWeekStart="2026-08-24"
        mode="review"
      />,
    );

    const serviceDate = screen.getByLabelText("Ngày phục vụ");
    fireEvent.change(serviceDate, { target: { value: "2026-08-25" } });
    expect(serviceDate).toHaveValue("2026-08-25");
    fireEvent.click(screen.getByRole("tab", { name: "Xác nhận nhu cầu" }));
    const projection = await screen.findByRole("table", {
      name: "Tổng quan nhu cầu theo ngày",
    });
    fireEvent.click(
      within(projection).getByRole("button", {
        name: "Mở xác nhận 24/08/2026",
      }),
    );

    expect(await screen.findByText(/Đang xem ngày/)).toHaveTextContent(
      "24/08/2026",
    );
    expect(
      await screen.findByRole("textbox", {
        name: "Số lượng xác nhận Gạo thơm",
      }),
    ).toBeVisible();
    fireEvent.click(screen.getByRole("tab", { name: "Thực đơn" }));
    expect(screen.getByLabelText("Ngày phục vụ")).toHaveValue("2026-08-24");
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

  it("keeps embedded Need Generation as navigation rather than command authority", async () => {
    render(
      <PlanningInputsWorkbench
        authState={authState}
        needGenerationApi={createReviewNeedGenerationApi("ready")}
        readinessApi={createReviewPlanningInputReadinessApi("ready")}
        confirmedNeedApi={createReviewConfirmedNeedApi("ready")}
        mode="review"
      />,
    );
    fireEvent.click(screen.getByRole("tab", { name: "Xác nhận nhu cầu" }));
    expect(
      await screen.findByRole("region", {
        name: "Tổng quan nhu cầu theo ngày",
      }),
    ).toBeVisible();
    expect(
      screen.queryByRole("button", { name: /^Tạo nhu cầu$/ }),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByLabelText("Mã lô Confirmed Need"),
    ).not.toBeInTheDocument();
  });
});
