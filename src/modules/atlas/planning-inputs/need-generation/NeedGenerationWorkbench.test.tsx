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
) {
  render(
    <NeedGenerationWorkbench
      authState={authState}
      api={api}
      preflightApi={preflightApi}
      selectedWeekStart="2026-08-03"
      selectedWeekEnd="2026-08-09"
      onConfirmedNeedMaterialized={onConfirmedNeedMaterialized}
    />,
  );
  return { api, preflightApi, onConfirmedNeedMaterialized };
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

    expect(
      await screen.findByText(
        "Thực đơn, Sĩ số và Nhu cầu bổ sung đã sẵn sàng.",
      ),
    ).toBeVisible();
    const support = screen.getByText("Chi tiết hỗ trợ").closest("details");
    expect(support).not.toHaveAttribute("open");
    expect(screen.getAllByText("SẴN SÀNG")).toHaveLength(8);
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
    expect(
      screen.getByRole("table", { name: "Tổng quan nhu cầu theo ngày" }),
    ).toBeVisible();
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
      await screen.findByText("Nhu cầu hiện tại đã được tạo."),
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
      await screen.findByText("Cần lưu Thực đơn trước khi tạo nhu cầu."),
    ).toBeVisible();
    expect(screen.getAllByText("CẦN XỬ LÝ")).toHaveLength(8);
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

  it("targets Tuesday independently without caller-authored date ranges", async () => {
    const api = createReviewNeedGenerationApi("ready");
    const execute = vi.spyOn(api, "execute");
    renderWorkbench(api, createReviewPlanningInputReadinessApi("ready"));

    fireEvent.click(
      await screen.findByRole("button", {
        name: "Tạo nhu cầu 04/08/2026",
      }),
    );
    fireEvent.click(await screen.findByRole("button", { name: "Tạo nhu cầu" }));

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
      screen.getByRole("button", { name: "Tạo nhu cầu 03/08/2026" }),
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
      await screen.findByText("Cần kiểm tra Sĩ số trước khi tạo nhu cầu."),
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
        "Dữ liệu nguồn đã thay đổi. Hãy tải lại trước khi tiếp tục.",
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
    renderWorkbench(api, await makePreflightCurrentness("OUTDATED"));

    expect(
      await screen.findByText(
        "Dữ liệu nguồn đã thay đổi. Cần cập nhật nhu cầu.",
      ),
    ).toBeVisible();
    fireEvent.click(screen.getByRole("button", { name: "Cập nhật nhu cầu" }));
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
      screen.queryByText(/Phiếu nhu cầu xác nhận|trong một giao dịch/),
    ).not.toBeInTheDocument();
    expect(screen.getByText("Nhu cầu hiện tại đã được tạo.")).toBeVisible();
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
        "Đã nhận kết quả nhưng chưa tải được dữ liệu mới nhất. Hãy tải lại dữ liệu.",
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
    expect(
      screen.getByRole("button", { name: "Tải lại dữ liệu" }),
    ).toBeEnabled();
  });

  it("shows CURRENT without a misleading generation action", async () => {
    const onOpen = vi.fn();
    renderWorkbench(
      createReviewNeedGenerationApi("ready"),
      await makePreflightCurrentness("CURRENT"),
      onOpen,
    );

    expect(
      await screen.findByText("Nhu cầu hiện tại đã được tạo."),
    ).toBeVisible();
    expect(
      screen.queryByRole("button", { name: "Tạo nhu cầu" }),
    ).not.toBeInTheDocument();
    fireEvent.click(
      screen.getByRole("button", { name: "Mở Xác nhận nhu cầu" }),
    );
    expect(onOpen).toHaveBeenCalledWith("current-batch");
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
    expect(
      screen.getByRole("button", { name: "Tải lại dữ liệu" }),
    ).toBeEnabled();
  });
});
