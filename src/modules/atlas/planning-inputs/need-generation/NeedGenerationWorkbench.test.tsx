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
import { createReviewPlanningInputReadinessApi } from "../readiness/reviewPlanningInputReadinessApi";
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
  session: { user: { id: "review-only-atlas-operator" } },
} as unknown as AtlasAuthState;

function renderWorkbench(
  api = createReviewNeedGenerationApi("ready"),
  preflightApi = createReviewPlanningInputReadinessApi("ready"),
  onConfirmedNeedMaterialized = vi.fn(),
  embeddedInConfirmedNeed = false,
  onConfirmedNeedSelected = vi.fn(),
) {
  render(
    <NeedGenerationWorkbench
      authState={authState}
      api={api}
      preflightApi={preflightApi}
      selectedWeekStart="2026-08-03"
      selectedWeekEnd="2026-08-09"
      onConfirmedNeedMaterialized={onConfirmedNeedMaterialized}
      onConfirmedNeedSelected={onConfirmedNeedSelected}
      embeddedInConfirmedNeed={embeddedInConfirmedNeed}
    />,
  );
  return {
    api,
    preflightApi,
    onConfirmedNeedMaterialized,
    onConfirmedNeedSelected,
  };
}

async function makePreflightCurrentness(
  currentness: "CURRENT" | "OUTDATED" | "NOT_GENERATED",
  confirmedNeedStatus = "DRAFT_REVIEW",
) {
  const api = createReviewPlanningInputReadinessApi("ready");
  const original = api.preflight;
  vi.spyOn(api, "preflight").mockImplementation(async (...args) => {
    const result = await original(...args);
    if (result.kind === "success" && result.response.preflight) {
      const preflight = result.response.preflight as Record<string, unknown>;
      preflight.downstream_currentness = currentness;
      preflight.current_need =
        currentness === "NOT_GENERATED"
          ? null
          : {
              need_generation_run_id: "current-run",
              need_generation_run_version: 3,
              confirmed_need_batch_id: "current-batch",
              confirmed_need_batch_version: 1,
              confirmed_need_batch_status: confirmedNeedStatus,
            };
    }
    return result;
  });
  return api;
}

describe("UI-QUALITY-02AB-UX automatic preflight and atomic Need Generation", () => {
  it("renders embedded Confirmed Need navigation as an attached seven-day selector", async () => {
    const api = createReviewNeedGenerationApi("ready");
    const execute = vi.spyOn(api, "execute");
    renderWorkbench(
      api,
      createReviewPlanningInputReadinessApi("ready"),
      vi.fn(),
      true,
    );

    const navigator = await screen.findByRole("region", {
      name: "Tổng quan nhu cầu theo ngày",
    });
    const selector = within(navigator).getByRole("navigation", {
      name: "Chọn ngày xác nhận nhu cầu",
    });
    const selectedDay = within(selector).getByRole("button", {
      name: "Rà soát 03/08/2026",
    });
    expect(selectedDay).toHaveAttribute("aria-current", "date");
    expect(selectedDay).toHaveAttribute(
      "aria-controls",
      "planning-confirmed-review",
    );
    fireEvent.click(selectedDay);
    expect(execute).not.toHaveBeenCalled();
    expect(
      await within(navigator).findByRole("button", { name: "Tạo nhu cầu" }),
    ).toBeEnabled();
    expect(within(selector).getAllByRole("button")).toHaveLength(7);
    expect(
      within(navigator).queryByRole("table", {
        name: "Tổng quan nhu cầu theo ngày",
      }),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByRole("heading", { name: "Tình trạng nhu cầu" }),
    ).not.toBeInTheDocument();
    expect(screen.queryByText(/Tuần đang xem:/)).not.toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: "Làm mới" }),
    ).not.toBeInTheDocument();
    expect(screen.queryByText("Chi tiết hỗ trợ")).not.toBeInTheDocument();
  });

  it("executes exactly one selected-day RMVP-04.v3 command and selects its returned batch", async () => {
    const api = createReviewNeedGenerationApi("ready");
    const execute = vi.spyOn(api, "execute");
    const create = vi.spyOn(api, "create");
    const validate = vi.spyOn(api, "validate");
    const release = vi.spyOn(api, "release");
    const materialize = vi.spyOn(api, "materialize");
    const onConfirmedNeedSelected = vi.fn();
    render(
      <NeedGenerationWorkbench
        authState={authState}
        api={api}
        preflightApi={createReviewPlanningInputReadinessApi("ready")}
        selectedWeekStart="2026-08-31"
        selectedWeekEnd="2026-09-06"
        embeddedInConfirmedNeed
        onConfirmedNeedSelected={onConfirmedNeedSelected}
      />,
    );

    const navigator = await screen.findByRole("region", {
      name: "Tổng quan nhu cầu theo ngày",
    });
    fireEvent.click(
      within(navigator).getByRole("button", {
        name: "Rà soát 31/08/2026",
      }),
    );
    expect(execute).not.toHaveBeenCalled();

    fireEvent.click(
      await within(navigator).findByRole("button", { name: "Tạo nhu cầu" }),
    );

    await waitFor(() => expect(execute).toHaveBeenCalledTimes(1));
    expect(execute.mock.calls[0]?.[0]).toMatchObject({
      contract_version: "RMVP-04.v3",
      payload: {
        service_date: "2026-08-31",
        expected_current_need_generation_run_id: null,
      },
    });
    expect(create).not.toHaveBeenCalled();
    expect(validate).not.toHaveBeenCalled();
    expect(release).not.toHaveBeenCalled();
    expect(materialize).not.toHaveBeenCalled();
    await waitFor(() =>
      expect(onConfirmedNeedSelected).toHaveBeenCalledWith(
        "c4500000-0000-0000-0000-000000000001",
        "2026-08-31",
        expect.objectContaining({
          downstream_currentness: "CURRENT",
          current_need: expect.objectContaining({
            confirmed_need_batch_id: "c4500000-0000-0000-0000-000000000001",
            confirmed_need_batch_status: "DRAFT_REVIEW",
          }),
        }),
      ),
    );
  });

  it("uses the authoritative returned service date when selecting the generated batch", async () => {
    const api = createReviewNeedGenerationApi("ready");
    const originalExecute = api.execute.bind(api);
    vi.spyOn(api, "execute").mockImplementation(async (request) => {
      const result = await originalExecute(request);
      if (result.kind === "success") {
        const readback = result.response.authoritative_readback as unknown as {
          preflight: Record<string, unknown>;
        };
        readback.preflight.period_start = "2026-09-01";
        readback.preflight.period_end = "2026-09-01";
      }
      return result;
    });
    const onConfirmedNeedSelected = vi.fn();
    render(
      <NeedGenerationWorkbench
        authState={authState}
        api={api}
        preflightApi={createReviewPlanningInputReadinessApi("ready")}
        selectedWeekStart="2026-08-31"
        selectedWeekEnd="2026-09-06"
        embeddedInConfirmedNeed
        onConfirmedNeedSelected={onConfirmedNeedSelected}
      />,
    );

    fireEvent.click(await screen.findByRole("button", { name: "Tạo nhu cầu" }));

    await waitFor(() =>
      expect(onConfirmedNeedSelected).toHaveBeenCalledWith(
        "c4500000-0000-0000-0000-000000000001",
        "2026-09-01",
        expect.objectContaining({ period_start: "2026-09-01" }),
      ),
    );
  });

  it("opens the exact CURRENT Confirmed Need without executing generation", async () => {
    const api = createReviewNeedGenerationApi("ready");
    const execute = vi.spyOn(api, "execute");
    const onConfirmedNeedSelected = vi.fn();
    renderWorkbench(
      api,
      await makePreflightCurrentness("CURRENT"),
      vi.fn(),
      true,
      onConfirmedNeedSelected,
    );

    const openConfirmedNeed = await screen.findByRole("button", {
      name: "Mở xác nhận",
    });
    expect(openConfirmedNeed).toBeEnabled();
    expect(openConfirmedNeed).toHaveClass("secondary-forward");
    fireEvent.click(openConfirmedNeed);

    expect(execute).not.toHaveBeenCalled();
    expect(onConfirmedNeedSelected).toHaveBeenCalledWith(
      "current-batch",
      "2026-08-03",
      expect.objectContaining({ downstream_currentness: "CURRENT" }),
    );
  });

  it("shows a quiet open state only for the same Confirmed Need batch and date", async () => {
    const api = createReviewNeedGenerationApi("ready");
    const preflightApi = await makePreflightCurrentness("CURRENT");
    const props = {
      authState,
      api,
      preflightApi,
      selectedWeekStart: "2026-08-03",
      selectedWeekEnd: "2026-08-09",
      embeddedInConfirmedNeed: true,
    };
    const { rerender } = render(
      <NeedGenerationWorkbench
        {...props}
        openConfirmedNeed={{
          batchId: "current-batch",
          serviceDate: "2026-08-03",
        }}
      />,
    );
    const action = await screen.findByRole("region", {
      name: "Việc cần làm cho ngày đã chọn",
    });
    expect(within(action).getByRole("status")).toHaveTextContent("Đang mở");
    expect(within(action).queryByRole("button")).not.toBeInTheDocument();

    for (const openConfirmedNeed of [
      { batchId: "another-batch", serviceDate: "2026-08-03" },
      { batchId: "current-batch", serviceDate: "2026-08-04" },
      null,
    ]) {
      rerender(
        <NeedGenerationWorkbench
          {...props}
          openConfirmedNeed={openConfirmedNeed}
        />,
      );
      expect(
        within(action).getByRole("button", { name: "Mở xác nhận" }),
      ).toHaveClass("secondary-forward");
      expect(within(action).queryByText("Đang mở")).not.toBeInTheDocument();
    }
  });

  it("keeps embedded BLOCKED state backend-driven with no execute action", async () => {
    const api = createReviewNeedGenerationApi("ready");
    const execute = vi.spyOn(api, "execute");
    renderWorkbench(
      api,
      createReviewPlanningInputReadinessApi("empty"),
      vi.fn(),
      true,
    );

    const selectedDayAction = await screen.findByRole("region", {
      name: "Việc cần làm cho ngày đã chọn",
    });
    expect(
      within(selectedDayAction).getByText(
        "Cần lưu Thực đơn trước khi tạo nhu cầu.",
      ),
    ).toBeVisible();
    expect(
      screen.queryByRole("button", { name: "Tạo nhu cầu" }),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: "Cập nhật nhu cầu" }),
    ).not.toBeInTheDocument();
    expect(execute).not.toHaveBeenCalled();
  });

  it("renders seven backend daily states and executes exactly one Monday v3 write", async () => {
    const api = createReviewNeedGenerationApi("ready");
    const preflightApi = createReviewPlanningInputReadinessApi("ready");
    const preflight = vi.spyOn(preflightApi, "preflight");
    const execute = vi.spyOn(api, "execute");
    const create = vi.spyOn(api, "create");
    const validate = vi.spyOn(api, "validate");
    const release = vi.spyOn(api, "release");
    const materialize = vi.spyOn(api, "materialize");
    renderWorkbench(api, preflightApi);

    expect(await screen.findByText("Dữ liệu đã sẵn sàng.")).toBeVisible();
    const support = screen.getByText("Chi tiết hỗ trợ").closest("details");
    expect(support).not.toHaveAttribute("open");
    expect(screen.getAllByText("SẴN SÀNG")).toHaveLength(1);
    expect(screen.queryByText("READY")).not.toBeInTheDocument();
    expect(preflight).toHaveBeenCalledTimes(7);
    expect(preflight.mock.calls.map((call) => call.slice(2))).toEqual([
      ["2026-08-03", "2026-08-03"],
      ["2026-08-04", "2026-08-04"],
      ["2026-08-05", "2026-08-05"],
      ["2026-08-06", "2026-08-06"],
      ["2026-08-07", "2026-08-07"],
      ["2026-08-08", "2026-08-08"],
      ["2026-08-09", "2026-08-09"],
    ]);
    const table = screen.getByRole("table", {
      name: "Tổng quan nhu cầu theo ngày",
    });
    expect(table).toBeVisible();
    expect(
      within(table)
        .getAllByRole("columnheader")
        .map((header) => header.textContent),
    ).toEqual(["Ngày phục vụ", "Trạng thái", "Việc cần làm"]);
    expect(within(table).queryByText("Đầu vào")).not.toBeInTheDocument();
    expect(
      within(table).queryByText("Xác nhận nhu cầu"),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByText("Mỗi ngày là một nhu cầu độc lập."),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByLabelText("Từ ngày tạo nhu cầu"),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByLabelText("Đến ngày tạo nhu cầu"),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: /Đánh giá mức sẵn sàng/ }),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: /Yêu cầu tạo nhu cầu/ }),
    ).not.toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "Tạo nhu cầu" }));
    await waitFor(() => expect(execute).toHaveBeenCalledTimes(1));
    expect(execute.mock.calls[0]?.[0]).toMatchObject({
      contract_version: "RMVP-04.v3",
      payload: { service_date: "2026-08-03" },
    });
    expect(create).not.toHaveBeenCalled();
    expect(validate).not.toHaveBeenCalled();
    expect(release).not.toHaveBeenCalled();
    expect(materialize).not.toHaveBeenCalled();
    expect(
      await screen.findByText("Nhu cầu đã cập nhật từ dữ liệu hiện tại."),
    ).toBeVisible();
    expect(screen.getByText("Đã tạo nhu cầu.")).toBeVisible();
    expect(
      screen.queryByText(/Phiếu nhu cầu xác nhận|trong một giao dịch/),
    ).not.toBeInTheDocument();
  });

  it("shows blocked sources in plain Vietnamese and prevents execution", async () => {
    const api = createReviewNeedGenerationApi("ready");
    const execute = vi.spyOn(api, "execute");
    renderWorkbench(api, createReviewPlanningInputReadinessApi("empty"));

    expect(
      (
        await screen.findAllByText("Cần lưu Thực đơn trước khi tạo nhu cầu.")
      )[0],
    ).toBeVisible();
    expect(screen.getAllByText("CẦN XỬ LÝ")).toHaveLength(1);
    expect(screen.getAllByText("CHƯA CÓ")).toHaveLength(3);
    expect(screen.getAllByText("CHƯA CÓ")[0]).not.toBeVisible();
    for (const rawToken of [
      "READY",
      "BLOCKED",
      "MISSING",
      "AMBIGUOUS",
      "STALE",
    ])
      expect(screen.queryByText(rawToken)).not.toBeInTheDocument();
    expect(
      screen.queryByText("Không có bằng chứng đã phê duyệt giao với kỳ."),
    ).not.toBeInTheDocument();
    expect(screen.getByText("Lỗi chặn (3)")).toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: "Tạo nhu cầu" }),
    ).not.toBeInTheDocument();
    expect(execute).not.toHaveBeenCalled();
  });

  it("presents no daily Need source neutrally while Pantry-only remains actionable", async () => {
    const api = createReviewNeedGenerationApi("ready");
    const execute = vi.spyOn(api, "execute");
    const preflightApi = createReviewPlanningInputReadinessApi("ready");
    const original = preflightApi.preflight;
    vi.spyOn(preflightApi, "preflight").mockImplementation(async (...args) => {
      const result = await original(...args);
      if (result.kind !== "success" || !result.response.preflight)
        return result;
      const preflight = result.response.preflight as Record<string, unknown>;
      const sources = preflight.source_evidence as Record<
        string,
        Record<string, unknown>
      >;
      if (args[2] === "2026-08-03") {
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
            service_date: "2026-08-03",
          },
        ];
        (sources.weekly_menu!.selected as Record<string, unknown>).line_count =
          0;
        (sources.pantry!.selected as Record<string, unknown>).line_count = 0;
      }
      if (args[2] === "2026-08-04") {
        (sources.weekly_menu!.selected as Record<string, unknown>).line_count =
          0;
        (sources.pantry!.selected as Record<string, unknown>).line_count = 1;
      }
      return result;
    });
    renderWorkbench(api, preflightApi);

    const table = await screen.findByRole("table", {
      name: "Tổng quan nhu cầu theo ngày",
    });
    const noDemandRow = within(table).getByText("03/08/2026").closest("tr")!;
    expect(
      within(noDemandRow).getByText("Không có nhu cầu cần lập"),
    ).toBeVisible();
    expect(
      within(noDemandRow).getByRole("button", { name: "Xem 03/08/2026" }),
    ).toBeVisible();
    expect(
      screen.getAllByText("Không có nhu cầu cần lập").length,
    ).toBeGreaterThan(1);
    expect(
      screen.queryByText("NO_NEED_SOURCE_FOR_SERVICE_DATE"),
    ).not.toBeInTheDocument();
    expect(screen.queryByText("EMPTY_ACTIVE_RELEASE")).not.toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: "Tạo nhu cầu" }),
    ).not.toBeInTheDocument();
    expect(execute).not.toHaveBeenCalled();

    fireEvent.click(
      within(table).getByRole("button", { name: "Rà soát 04/08/2026" }),
    );
    expect(
      await screen.findByRole("button", { name: "Tạo nhu cầu" }),
    ).toBeEnabled();
    expect(execute).not.toHaveBeenCalled();
  });

  it("shows the backend legacy-overlap blocker on its daily row and disables generation", async () => {
    const api = createReviewNeedGenerationApi("ready");
    const execute = vi.spyOn(api, "execute");
    const preflightApi = createReviewPlanningInputReadinessApi("ready");
    const original = preflightApi.preflight;
    vi.spyOn(preflightApi, "preflight").mockImplementation(async (...args) => {
      const result = await original(...args);
      if (
        args[2] === "2026-08-03" &&
        result.kind === "success" &&
        result.response.preflight
      ) {
        const preflight = result.response.preflight as Record<string, unknown>;
        preflight.readiness_state = "BLOCKED";
        preflight.downstream_currentness = "LEGACY_OVERLAP";
        preflight.blocking_issue_count = 1;
        preflight.current_need = null;
        preflight.legacy_overlap = {
          service_date: "2026-08-03",
          blocker_code: "ACTIVE_LEGACY_NEED_RANGE_OVERLAP",
          safe_message:
            "An active historical multi-day Need commitment contains this service date.",
          active_chains: [
            {
              need_generation_run_id: "legacy-run",
              need_generation_run_status: "RELEASED_FOR_CONFIRMATION",
              need_generation_run_version: 3,
              period_start: "2026-08-03",
              period_end: "2026-08-09",
              confirmed_need_batch_id: "legacy-batch",
              confirmed_need_batch_status: "DRAFT_REVIEW",
              confirmed_need_batch_version: 1,
            },
          ],
        };
        preflight.issues = [
          {
            severity: "BLOCKING",
            issue_code: "ACTIVE_LEGACY_NEED_RANGE_OVERLAP",
            message:
              "An active historical multi-day Need commitment contains this service date.",
            input_type: "NEED_GENERATION",
            school_id: null,
            service_date: "2026-08-03",
          },
        ];
      }
      return result;
    });
    renderWorkbench(api, preflightApi);

    const table = await screen.findByRole("table", {
      name: "Tổng quan nhu cầu theo ngày",
    });
    const dailyRow = within(table).getByText("03/08/2026").closest("tr");
    expect(dailyRow).not.toBeNull();
    expect(
      within(dailyRow!).getByText("Thuộc nhu cầu đã lập trước đây"),
    ).toBeVisible();
    expect(
      within(dailyRow!).getByRole("button", {
        name: "Xem 03/08/2026",
      }),
    ).toBeVisible();
    expect(
      screen.getByText(
        "Ngày này đã thuộc một nhu cầu nhiều ngày đang có hiệu lực nên không thể tạo nhu cầu mới.",
      ),
    ).toBeVisible();
    expect(
      screen.getByText(
        "Ngày này đã nằm trong một nhu cầu nhiều ngày đang có hiệu lực. Giữ nguyên nhu cầu cũ và chờ quy trình điều chỉnh.",
      ),
    ).toBeVisible();
    expect(
      screen.queryByRole("button", { name: "Tạo nhu cầu" }),
    ).not.toBeInTheDocument();
    expect(execute).not.toHaveBeenCalled();
  });

  it("targets Tuesday independently without caller-authored date ranges", async () => {
    const api = createReviewNeedGenerationApi("ready");
    const execute = vi.spyOn(api, "execute");
    renderWorkbench(api, createReviewPlanningInputReadinessApi("ready"));

    fireEvent.click(
      await screen.findByRole("button", {
        name: "Rà soát 04/08/2026",
      }),
    );
    expect(execute).not.toHaveBeenCalled();
    const createNeed = await screen.findByRole("button", {
      name: "Tạo nhu cầu",
    });
    expect(createNeed).toBeEnabled();
    fireEvent.click(createNeed);

    await waitFor(() => expect(execute).toHaveBeenCalledTimes(1));
    expect(execute.mock.calls[0]?.[0].payload).toEqual({
      service_date: "2026-08-04",
      expected_current_need_generation_run_id: null,
    });
    expect(execute.mock.calls[0]?.[0].payload).not.toHaveProperty(
      "period_start",
    );
    expect(execute.mock.calls[0]?.[0].payload).not.toHaveProperty("period_end");
    expect(
      screen.getByRole("button", { name: "Rà soát 03/08/2026" }),
    ).toBeVisible();
  });

  it("maps known preflight issues and keeps raw backend sentences hidden", async () => {
    const preflightApi = createReviewPlanningInputReadinessApi("ready");
    const original = preflightApi.preflight;
    vi.spyOn(preflightApi, "preflight").mockImplementation(async (...args) => {
      const result = await original(...args);
      if (result.kind === "success" && result.response.preflight) {
        const preflight = result.response.preflight as Record<string, unknown>;
        preflight.readiness_state = "BLOCKED";
        preflight.blocking_issue_count = 1;
        preflight.issues = [
          {
            severity: "WARNING",
            issue_code: "ZERO_ATTENDANCE_FOR_PLANNED_MENU",
            message: "Zero attendance for planned menu.",
            input_type: null,
            school_id: null,
            service_date: null,
          },
          {
            severity: "BLOCKING",
            issue_code: "MISSING_WEEKLY_MENU_APPROVAL_SNAPSHOT",
            message: "No approved Weekly Menu snapshot intersects the period.",
            input_type: null,
            school_id: null,
            service_date: null,
          },
        ];
      }
      return result;
    });
    renderWorkbench(createReviewNeedGenerationApi("ready"), preflightApi);

    const blockerRegion = await screen.findByRole("region", {
      name: "Lỗi chặn",
    });
    const warningRegion = screen.getByRole("region", { name: "Cảnh báo" });
    const blocker = within(blockerRegion).getByText(
      "Chưa có thực đơn tuần đã lưu phù hợp với kỳ này.",
    );
    const warning = within(warningRegion).getByText(
      "Thực đơn đã có nhưng tổng số suất ăn của trường và ngày này bằng 0.",
    );
    expect(
      screen.queryByText(
        "No approved Weekly Menu snapshot intersects the period.",
      ),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByText("Zero attendance for planned menu."),
    ).not.toBeInTheDocument();
    expect(
      blocker.compareDocumentPosition(warning) &
        Node.DOCUMENT_POSITION_FOLLOWING,
    ).toBeTruthy();
  });

  it("maps ambiguous and stale source evidence without exposing backend messages", async () => {
    const preflightApi = createReviewPlanningInputReadinessApi("ready");
    const original = preflightApi.preflight;
    vi.spyOn(preflightApi, "preflight").mockImplementation(async (...args) => {
      const result = await original(...args);
      if (result.kind === "success" && result.response.preflight) {
        const preflight = result.response.preflight as Record<string, unknown>;
        const sources = preflight.source_evidence as Record<
          string,
          Record<string, unknown>
        >;
        preflight.readiness_state = "BLOCKED";
        sources.attendance!.selection_state = "AMBIGUOUS";
        sources.attendance!.safe_message =
          "Multiple approved candidates found.";
        sources.pantry!.selection_state = "STALE";
        sources.pantry!.safe_message = "Selected snapshot is stale.";
      }
      return result;
    });
    renderWorkbench(createReviewNeedGenerationApi("ready"), preflightApi);

    expect(
      (
        await screen.findAllByText("Cần kiểm tra Sĩ số trước khi tạo nhu cầu.")
      )[0],
    ).toBeVisible();
    fireEvent.click(screen.getByText("Chi tiết hỗ trợ"));
    expect(screen.getByText("CẦN TẢI LẠI")).toBeVisible();
    expect(screen.getAllByText("CẦN XỬ LÝ").length).toBeGreaterThan(0);
    expect(
      screen.getByText(
        "Có nhiều bản dữ liệu phù hợp. Cần xử lý nguồn trước khi tiếp tục.",
      ),
    ).toBeInTheDocument();
    expect(
      screen.getByText(
        "Dữ liệu nguồn đã thay đổi. Hãy làm mới trước khi tiếp tục.",
      ),
    ).toBeInTheDocument();
    expect(
      screen.queryByText("Multiple approved candidates found."),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByText("Selected snapshot is stale."),
    ).not.toBeInTheDocument();
  });

  it("uses Cập nhật nhu cầu for backend OUTDATED state", async () => {
    const api = createReviewNeedGenerationApi("ready");
    const originalExecute = api.execute;
    const execute = vi.spyOn(api, "execute");
    execute.mockImplementation(async (...args) => {
      const result = await originalExecute(...args);
      if (result.kind === "success")
        result.response.safe_operator_message =
          "Đã cập nhật nhu cầu và hiệu chỉnh Phiếu nhu cầu xác nhận trong một giao dịch.";
      return result;
    });
    renderWorkbench(
      api,
      await makePreflightCurrentness("OUTDATED"),
      vi.fn(),
      true,
    );

    expect(
      await screen.findByText(
        "Dữ liệu nguồn đã thay đổi sau lần tính gần nhất.",
      ),
    ).toBeVisible();
    fireEvent.click(screen.getByRole("button", { name: "Rà soát 04/08/2026" }));
    expect(execute).not.toHaveBeenCalled();
    const updateNeed = await screen.findByRole("button", {
      name: "Cập nhật nhu cầu",
    });
    expect(updateNeed).toBeEnabled();
    fireEvent.click(updateNeed);
    await waitFor(() => expect(execute).toHaveBeenCalledTimes(1));
    expect(execute.mock.calls[0]?.[0].payload).toMatchObject({
      expected_current_need_generation_run_id: "current-run",
    });
    expect(
      await screen.findByText(
        "Nhu cầu đã được cập nhật. 4 dòng cần rà soát; 63 xác nhận trước đó được giữ nguyên.",
      ),
    ).toBeVisible();
    expect(
      screen.queryByText(
        /Đã cập nhật nhu cầu và hiệu chỉnh Phiếu nhu cầu xác nhận/,
      ),
    ).not.toBeInTheDocument();
    expect(
      screen.getByText("Nhu cầu đã cập nhật từ dữ liệu hiện tại."),
    ).toBeVisible();
  });

  it("requires reconciliation instead of claiming success when authoritative readback is incomplete", async () => {
    const api = createReviewNeedGenerationApi("ready");
    const execute = vi.spyOn(api, "execute").mockResolvedValue({
      kind: "success",
      response: {
        success: true,
        safe_operator_message:
          "Đã tạo nhu cầu và Phiếu nhu cầu xác nhận trong một giao dịch.",
      },
    });
    renderWorkbench(api, createReviewPlanningInputReadinessApi("ready"));

    fireEvent.click(await screen.findByRole("button", { name: "Tạo nhu cầu" }));

    expect(
      await screen.findByText(
        "Đã nhận kết quả nhưng chưa đọc lại được dữ liệu mới nhất. Hãy làm mới.",
      ),
    ).toBeVisible();
    expect(execute).toHaveBeenCalledTimes(1);
    expect(screen.queryByText("Đã tạo nhu cầu.")).not.toBeInTheDocument();
    expect(
      screen.queryByText(/Phiếu nhu cầu xác nhận|trong một giao dịch/),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: "Tạo nhu cầu" }),
    ).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Làm mới" })).toBeEnabled();
  });

  it("shows CURRENT without a misleading generation action", async () => {
    const onOpen = vi.fn();
    renderWorkbench(
      createReviewNeedGenerationApi("ready"),
      await makePreflightCurrentness("CURRENT"),
      onOpen,
    );

    expect(
      await screen.findByText("Nhu cầu đã cập nhật từ dữ liệu hiện tại."),
    ).toBeVisible();
    expect(
      screen.queryByRole("button", { name: "Tạo nhu cầu" }),
    ).not.toBeInTheDocument();
    const table = screen.getByRole("table", {
      name: "Tổng quan nhu cầu theo ngày",
    });
    const currentRow = within(table).getByText("04/08/2026").closest("tr")!;
    expect(within(currentRow).getByText("Chờ xác nhận")).toBeVisible();
    fireEvent.click(
      within(currentRow).getByRole("button", {
        name: "Mở xác nhận 04/08/2026",
      }),
    );
    expect(onOpen).toHaveBeenCalledWith("current-batch");
  });

  it("keeps one operational group while preserving Recipe and Pantry contribution detail", async () => {
    renderWorkbench();
    fireEvent.click(await screen.findByRole("button", { name: "Tạo nhu cầu" }));
    await screen.findByText("Nhu cầu đã cập nhật từ dữ liệu hiện tại.");

    const calculationDetail = screen
      .getByText("Chi tiết tính nhu cầu")
      .closest("details")!;
    expect(calculationDetail).not.toHaveAttribute("open");
    expect(screen.queryByText("DRAFT_REVIEW")).not.toBeInTheDocument();
    expect(
      screen.queryByText("RELEASED_FOR_CONFIRMATION"),
    ).not.toBeInTheDocument();

    fireEvent.click(
      within(calculationDetail).getByText("Chi tiết tính nhu cầu"),
    );
    const rows = within(calculationDetail).getAllByRole("row");
    expect(rows).toHaveLength(2);
    const requirement = rows[1]!;
    expect(requirement).toHaveTextContent("Gạo");
    expect(requirement).toHaveTextContent("21");
    expect(requirement).toHaveTextContent("2,5");
    expect(requirement).toHaveTextContent("23,5");

    fireEvent.click(within(requirement).getByRole("button", { name: "Xem" }));
    const contributionDetail = await screen.findByText(
      "Chi tiết hình thành số lượng",
    );
    const details = contributionDetail.closest("details")!;
    expect(within(details).getByText(/Công thức/)).toBeVisible();
    expect(within(details).getByText(/21 kg/)).toBeVisible();
    expect(within(details).getByText(/Nhu cầu bổ sung/)).toBeVisible();
    expect(within(details).getByText(/2,5 kg/)).toBeVisible();
  });

  it("explains released downstream correction before offering an invalid update", async () => {
    const api = createReviewNeedGenerationApi("ready");
    const execute = vi.spyOn(api, "execute");
    renderWorkbench(
      api,
      await makePreflightCurrentness(
        "OUTDATED",
        "RELEASED_FOR_PURCHASE_HANDOFF",
      ),
    );

    expect(
      await screen.findByText(
        "Nhu cầu này đã được chuyển sang lên đơn nên chưa thể cập nhật trực tiếp tại đây.",
      ),
    ).toBeVisible();
    expect(
      screen.queryByRole("button", { name: "Cập nhật nhu cầu" }),
    ).not.toBeInTheDocument();
    expect(
      screen.getByText(/Nhu cầu đã chuyển sang lên đơn được giữ nguyên/),
    ).toBeVisible();
    expect(execute).not.toHaveBeenCalled();
  });

  it("does not retry an unknown write and requires authoritative refresh", async () => {
    const api = createReviewNeedGenerationApi("ready");
    const execute = vi.spyOn(api, "execute").mockResolvedValue({
      kind: "transport_error",
      diagnostic: { code: "NETWORK_FAILURE", safeMessage: "Mất kết nối" },
    });
    renderWorkbench(api, createReviewPlanningInputReadinessApi("ready"));

    fireEvent.click(await screen.findByRole("button", { name: "Tạo nhu cầu" }));
    await screen.findByText(/Không thể ghi tiếp cho đến khi/);
    expect(execute).toHaveBeenCalledTimes(1);
    expect(
      screen.queryByRole("button", { name: "Tạo nhu cầu" }),
    ).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Làm mới" })).toBeEnabled();
  });
});
