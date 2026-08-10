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
              confirmed_need_batch_status: "DRAFT_REVIEW",
            };
    }
    return result;
  });
  return api;
}

describe("UI-QUALITY-02AB-UX automatic preflight and atomic Need Generation", () => {
  it("loads preflight automatically and executes exactly one v2 write", async () => {
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
      await screen.findByText("Đầu vào đã sẵn sàng tạo nhu cầu"),
    ).toBeInTheDocument();
    expect(screen.getByText("SẴN SÀNG")).toBeInTheDocument();
    expect(screen.queryByText("READY")).not.toBeInTheDocument();
    expect(preflight).toHaveBeenCalledTimes(1);
    expect(
      screen.queryByRole("button", { name: /Đánh giá mức sẵn sàng/ }),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: /Yêu cầu tạo nhu cầu/ }),
    ).not.toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "Tạo nhu cầu" }));
    await waitFor(() => expect(execute).toHaveBeenCalledTimes(1));
    expect(execute.mock.calls[0]?.[0].contract_version).toBe("RMVP-04.v2");
    expect(create).not.toHaveBeenCalled();
    expect(validate).not.toHaveBeenCalled();
    expect(release).not.toHaveBeenCalled();
    expect(materialize).not.toHaveBeenCalled();
    expect(
      await screen.findByText("Nhu cầu đang hiện hành"),
    ).toBeInTheDocument();
  });

  it("shows blocked sources in plain Vietnamese and prevents execution", async () => {
    const api = createReviewNeedGenerationApi("ready");
    const execute = vi.spyOn(api, "execute");
    renderWorkbench(api, createReviewPlanningInputReadinessApi("empty"));

    expect(await screen.findByText("Đầu vào đang bị chặn")).toBeInTheDocument();
    expect(screen.getByText("CẦN XỬ LÝ")).toBeInTheDocument();
    expect(screen.getAllByText("CHƯA CÓ")).toHaveLength(3);
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

    const blocker = await screen.findByText(
      "Chưa có thực đơn tuần đã lưu phù hợp với kỳ này.",
    );
    const warning = screen.getByText(
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

    expect(await screen.findByText("CẦN TẢI LẠI")).toBeInTheDocument();
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
    const execute = vi.spyOn(api, "execute");
    renderWorkbench(api, await makePreflightCurrentness("OUTDATED"));

    expect(await screen.findByText("Nhu cầu cần cập nhật")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Cập nhật nhu cầu" }));
    await waitFor(() => expect(execute).toHaveBeenCalledTimes(1));
    expect(execute.mock.calls[0]?.[0].payload).toMatchObject({
      expected_current_need_generation_run_id: "current-run",
    });
  });

  it("shows CURRENT without a misleading generation action", async () => {
    const onOpen = vi.fn();
    renderWorkbench(
      createReviewNeedGenerationApi("ready"),
      await makePreflightCurrentness("CURRENT"),
      onOpen,
    );

    expect(
      await screen.findByText("Nhu cầu đang hiện hành"),
    ).toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: "Tạo nhu cầu" }),
    ).not.toBeInTheDocument();
    fireEvent.click(
      screen.getByRole("button", { name: "Mở Xác nhận nhu cầu" }),
    );
    expect(onOpen).toHaveBeenCalledWith("current-batch");
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
      screen.getByRole("button", { name: "Tải lại có thẩm quyền" }),
    ).toBeEnabled();
  });
});
