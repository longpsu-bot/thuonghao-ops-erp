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

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
});

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
        workbench.lines = workbench.lines.map((line, index) => ({
          ...line,
          current_decision_id: `release-ready-decision-${index + 1}`,
          current_decision_number: 1,
          current_decision_kind: "PROPOSAL_ACCEPTED",
          confirmed_quantity_after: line.proposed_confirmed_quantity,
          confirmation_state: "CONFIRMED_CURRENT",
        }));
        workbench.line_counts = {
          ...workbench.line_counts,
          unreviewed: 0,
          confirmed: workbench.lines.length,
          needs_review: 0,
          new: 0,
        };
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
  it("uses only the shared working date, including days without a batch", async () => {
    render(
      <PlanningInputsWorkbench
        authState={authState}
        needGenerationApi={createReviewNeedGenerationApi("ready")}
        readinessApi={readinessWithDailyNeeds(
          {},
          { noDemandDates: ["2026-09-03"] },
        )}
        confirmedNeedApi={createReviewConfirmedNeedApi("ready")}
        initialWeekStart="2026-08-31"
        mode="review"
      />,
    );
    expect(screen.getByLabelText("Tuần phục vụ")).toHaveValue(
      "31/08/2026 – 06/09/2026",
    );
    fireEvent.click(screen.getByRole("tab", { name: "Xác nhận nhu cầu" }));
    const sharedDate = screen.getByRole("combobox", { name: "Ngày phục vụ" });
    expect(sharedDate).toHaveAccessibleDescription(
      "Ngày làm việc hiện tại trong tuần phục vụ",
    );
    fireEvent.change(sharedDate, { target: { value: "2026-09-03" } });
    expect(sharedDate).toHaveValue("2026-09-03");
    expect(
      within(sharedDate).getByRole("option", { selected: true }),
    ).toHaveTextContent("Thứ Năm · 03/09/2026");
    expect(await screen.findByText("Không có nhu cầu cần lập")).toBeVisible();
    expect(
      screen.getAllByRole("combobox", { name: "Ngày phục vụ" }),
    ).toHaveLength(1);
    expect(
      screen.queryByRole("navigation", { name: "Chọn ngày xác nhận nhu cầu" }),
    ).not.toBeInTheDocument();
    expect(screen.queryByText("Chọn ngày xác nhận")).not.toBeInTheDocument();
    expect(
      screen.queryByLabelText("Bảng xác nhận nhu cầu"),
    ).not.toBeInTheDocument();
    fireEvent.change(sharedDate, { target: { value: "2026-09-04" } });
    expect(
      await screen.findByRole("button", { name: "Tạo nhu cầu" }),
    ).toBeEnabled();
    expect(
      screen.queryByText("Không có nhu cầu cần lập"),
    ).not.toBeInTheDocument();
    expect(screen.queryByText("Ngày đang xem")).not.toBeInTheDocument();
  });

  it("keeps the working date and draft unchanged when a dirty date change is cancelled", async () => {
    const confirm = vi.spyOn(window, "confirm").mockReturnValue(false);
    render(
      <PlanningInputsWorkbench
        authState={authState}
        needGenerationApi={createReviewNeedGenerationApi("ready")}
        readinessApi={readinessWithDailyNeeds(
          { "2026-08-31": { batchId: defaultBatchId } },
          { noDemandDates: ["2026-09-03"] },
        )}
        confirmedNeedApi={confirmedNeedApiForDates({
          [defaultBatchId]: "2026-08-31",
        })}
        initialWeekStart="2026-08-31"
        mode="review"
      />,
    );
    fireEvent.click(screen.getByRole("tab", { name: "Xác nhận nhu cầu" }));
    const quantity = await screen.findByLabelText("Số lượng xác nhận Gạo thơm");
    fireEvent.change(quantity, { target: { value: "10.25" } });
    const changeDate = () =>
      fireEvent.change(screen.getByLabelText("Ngày phục vụ"), {
        target: { value: "2026-09-03" },
      });
    changeDate();
    expect(confirm).toHaveBeenCalledOnce();
    expect(quantity).toHaveValue("10.25");
    expect(screen.getByLabelText("Ngày phục vụ")).toHaveValue("2026-08-31");
    confirm.mockReturnValue(true);
    changeDate();
    expect(screen.getByLabelText("Ngày phục vụ")).toHaveValue("2026-09-03");
    expect(await screen.findByText("Không có nhu cầu cần lập")).toBeVisible();
    expect(
      screen.queryByLabelText("Số lượng xác nhận Gạo thơm"),
    ).not.toBeInTheDocument();
  });
  it("discards only with confirmation when two dates reference the same historical batch", async () => {
    vi.spyOn(window, "confirm").mockReturnValue(true);
    const api = confirmedNeedApiForDates({ [defaultBatchId]: "2026-08-03" });
    render(
      <PlanningInputsWorkbench
        authState={authState}
        readinessApi={readinessWithDailyNeeds({
          "2026-08-03": { batchId: defaultBatchId },
          "2026-08-04": { batchId: defaultBatchId },
        })}
        confirmedNeedApi={api}
        initialWeekStart="2026-08-03"
        mode="review"
      />,
    );
    fireEvent.click(screen.getByRole("tab", { name: "Xác nhận nhu cầu" }));
    fireEvent.change(
      await screen.findByLabelText("Số lượng xác nhận Gạo thơm"),
      { target: { value: "12.25" } },
    );
    fireEvent.change(screen.getByLabelText("Ngày phục vụ"), {
      target: { value: "2026-08-04" },
    });
    await waitFor(() => expect(api.getReview).toHaveBeenCalledTimes(2));
    fireEvent.change(screen.getByLabelText("Ngày phục vụ"), {
      target: { value: "2026-08-03" },
    });
    expect(
      await screen.findByLabelText("Số lượng xác nhận Gạo thơm"),
    ).toHaveValue("10,25");
  });

  it("threads the successful Purchase Handoff callback through the Planning workbench", async () => {
    const serviceDate = "2026-08-03";
    const readinessApi = readinessWithDailyNeeds({
      [serviceDate]: { batchId: defaultBatchId },
    });
    const confirmedNeedApi = confirmedNeedApiForDates(
      { [defaultBatchId]: serviceDate },
      { releaseEligible: true },
    );
    const released = createReviewConfirmedNeedFixture();
    released.confirmed_need_batch_id = defaultBatchId;
    released.batch_status = "RELEASED_FOR_PURCHASE_HANDOFF";
    released.authoritative_batch_status = "RELEASED_FOR_PURCHASE_HANDOFF";
    released.batch_version = 4;
    released.lines = released.lines.map((line, index) => ({
      ...line,
      service_date: serviceDate,
      current_decision_id: `release-ready-decision-${index + 1}`,
      current_decision_number: 1,
      current_decision_kind: "PROPOSAL_ACCEPTED",
      confirmed_quantity_after: line.proposed_confirmed_quantity,
      confirmation_state: "CONFIRMED_CURRENT",
    }));
    released.line_counts = {
      ...released.line_counts,
      unreviewed: 0,
      confirmed: released.lines.length,
      needs_review: 0,
      new: 0,
    };
    vi.spyOn(confirmedNeedApi, "releaseSaved").mockResolvedValue({
      kind: "success",
      response: {
        success: true,
        authoritative_readback: released as unknown as JsonValue,
      },
    });
    vi.spyOn(confirmedNeedApi, "releasePurchaseHandoff").mockResolvedValue({
      kind: "success",
      response: { success: true },
    });
    const onPurchaseHandoffReleased = vi.fn();
    render(
      <PlanningInputsWorkbench
        authState={authState}
        needGenerationApi={createReviewNeedGenerationApi("ready")}
        readinessApi={readinessApi}
        confirmedNeedApi={confirmedNeedApi}
        initialWeekStart={serviceDate}
        mode="review"
        onPurchaseHandoffReleased={onPurchaseHandoffReleased}
      />,
    );

    fireEvent.click(screen.getByRole("tab", { name: "Xác nhận nhu cầu" }));
    fireEvent.click(
      await screen.findByRole("button", { name: "Chuyển sang lên đơn" }),
    );
    fireEvent.click(screen.getByRole("button", { name: "Xác nhận chuyển" }));

    await waitFor(() =>
      expect(onPurchaseHandoffReleased).toHaveBeenCalledOnce(),
    );
  });

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
    expect(tabs[3]).toHaveAccessibleName("Xác nhận nhu cầu");
    expect(tabs[3]).toHaveTextContent("Xác nhận nhu cầu");
    fireEvent.click(tabs[3]!);
    expect(
      await screen.findByText("Chưa có nhu cầu xác nhận cho ngày này."),
    ).toBeVisible();
    expect(
      screen.queryByLabelText("Mã lô Confirmed Need"),
    ).not.toBeInTheDocument();
  });

  it("opens only the selected date from seven date-scoped reads without auto-switching to another candidate", async () => {
    const readinessApi = readinessWithDailyNeeds({
      "2026-08-04": { batchId: defaultBatchId },
    });
    const confirmedNeedApi = confirmedNeedApiForDates({
      [defaultBatchId]: "2026-08-04",
    });
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
    expect(screen.getByLabelText("Ngày phục vụ")).toHaveValue("2026-08-03");
    fireEvent.change(screen.getByLabelText("Ngày phục vụ"), {
      target: { value: "2026-08-04" },
    });
    expect(await screen.findByText("Gạo thơm")).toBeVisible();
    expect(screen.getByLabelText("Ngày phục vụ")).toHaveValue("2026-08-04");
    expect(
      new Set(
        vi.mocked(readinessApi.preflight).mock.calls.map((call) => call[2]),
      ).size,
    ).toBe(7);
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
    const confirmedNeedApi = confirmedNeedApiForDates(
      {
        [mondayBatch]: "2026-08-03",
        [wednesdayBatch]: "2026-08-05",
      },
      { releaseEligible: true },
    );
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

    fireEvent.change(screen.getByLabelText("Ngày phục vụ"), {
      target: { value: "2026-08-03" },
    });
    const search = await screen.findByPlaceholderText(
      "Tìm theo nguyên liệu, trường, điểm giao…",
    );
    fireEvent.change(search, { target: { value: "Nguyễn Du" } });
    expect(search).toHaveValue("Nguyễn Du");
    expect(
      screen.queryByRole("button", { name: "Mở xác nhận" }),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: "Mở xác nhận" }),
    ).not.toBeInTheDocument();

    fireEvent.change(screen.getByLabelText("Ngày phục vụ"), {
      target: { value: "2026-08-05" },
    });

    await waitFor(() =>
      expect(
        screen.getByPlaceholderText("Tìm theo nguyên liệu, trường, điểm giao…"),
      ).toHaveValue(""),
    );
    expect(screen.getByLabelText("Ngày phục vụ")).toHaveValue("2026-08-05");
    expect(
      screen.queryByRole("button", { name: "Mở xác nhận" }),
    ).not.toBeInTheDocument();
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

    fireEvent.change(screen.getByLabelText("Ngày phục vụ"), {
      target: { value: "2026-08-03" },
    });
    fireEvent.click(
      await screen.findByRole("button", { name: "Chuyển sang lên đơn" }),
    );
    expect(
      screen.getByRole("dialog", { name: "Xác nhận chuyển sang lên đơn" }),
    ).toBeVisible();

    fireEvent.change(screen.getByLabelText("Ngày phục vụ"), {
      target: { value: "2026-08-05" },
    });

    await waitFor(() =>
      expect(screen.getByLabelText("Ngày phục vụ")).toHaveValue("2026-08-05"),
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
    expect(await screen.findByLabelText("Ngày phục vụ")).toHaveValue(
      "2026-08-24",
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

    expect(await screen.findByText("Không có nhu cầu cần lập")).toBeVisible();
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

    fireEvent.change(screen.getByLabelText("Ngày phục vụ"), {
      target: { value: "2026-08-24" },
    });

    expect(await screen.findByLabelText("Ngày phục vụ")).toHaveValue(
      "2026-08-24",
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

  it("generates the selected day, opens the returned Draft Review batch, and preserves Save then release", async () => {
    const needGenerationApi = createReviewNeedGenerationApi("ready");
    const execute = vi.spyOn(needGenerationApi, "execute");
    const confirmedNeedApi = confirmedNeedApiForDates({
      [defaultBatchId]: "2026-08-31",
    });
    const getReview = vi.spyOn(confirmedNeedApi, "getReview");
    const save = vi.spyOn(confirmedNeedApi, "save");
    render(
      <PlanningInputsWorkbench
        authState={authState}
        needGenerationApi={needGenerationApi}
        readinessApi={createReviewPlanningInputReadinessApi("ready")}
        confirmedNeedApi={confirmedNeedApi}
        initialWeekStart="2026-08-31"
        mode="review"
      />,
    );
    fireEvent.click(screen.getByRole("tab", { name: "Xác nhận nhu cầu" }));
    expect(execute).not.toHaveBeenCalled();

    fireEvent.click(await screen.findByRole("button", { name: "Tạo nhu cầu" }));

    await waitFor(() => expect(execute).toHaveBeenCalledTimes(1));
    expect(execute.mock.calls[0]?.[0]).toMatchObject({
      contract_version: "RMVP-04.v3",
      payload: { service_date: "2026-08-31" },
    });
    expect(await screen.findByLabelText("Ngày phục vụ")).toHaveValue(
      "2026-08-31",
    );
    expect(await screen.findByText("Gạo thơm")).toBeVisible();
    expect(getReview).toHaveBeenCalledWith(
      expect.any(String),
      expect.any(String),
      defaultBatchId,
      expect.any(Object),
      0,
      10_000,
    );

    const saveButton = screen.getByRole("button", { name: "Lưu" });
    expect(saveButton).toBeEnabled();
    fireEvent.click(saveButton);
    expect(await screen.findByText("Đã lưu thay đổi.")).toBeVisible();
    expect(save).toHaveBeenCalledTimes(1);
    expect(
      screen.getByRole("button", { name: "Chuyển sang lên đơn" }),
    ).toBeEnabled();
    expect(
      screen.queryByLabelText("Mã lô Confirmed Need"),
    ).not.toBeInTheDocument();
  });
});
