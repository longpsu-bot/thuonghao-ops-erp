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
import {
  PlanningRailActionHost,
  PlanningRailActionProvider,
} from "../PlanningRailActionPortal";
import { ConfirmedNeedReviewWorkbench } from "./ConfirmedNeedReviewWorkbench";
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
const batchId = "c4500000-0000-0000-0000-000000000001";

function reviewTree(
  api: ReturnType<typeof createReviewConfirmedNeedApi>,
  schoolScopeIds: string[] = [],
  onPurchaseHandoffReleased?: () => void,
) {
  return (
    <PlanningRailActionProvider>
      <PlanningRailActionHost />
      <ConfirmedNeedReviewWorkbench
        authState={authState}
        api={api}
        initialBatchId={batchId}
        mode="review"
        schoolScopeIds={schoolScopeIds}
        onPurchaseHandoffReleased={onPurchaseHandoffReleased}
      />
    </PlanningRailActionProvider>
  );
}

function renderReview(
  api = createReviewConfirmedNeedApi("ready"),
  onPurchaseHandoffReleased?: () => void,
) {
  render(reviewTree(api, [], onPurchaseHandoffReleased));
  return api;
}

function renderScopedReview(
  api: ReturnType<typeof createReviewConfirmedNeedApi>,
  schoolScopeIds: string[],
) {
  return render(reviewTree(api, schoolScopeIds));
}

function renderAuthoritativeFixture(
  mutate: (
    workbench: ReturnType<typeof createReviewConfirmedNeedFixture>,
  ) => void,
) {
  const api = createReviewConfirmedNeedApi("ready");
  const workbench = createReviewConfirmedNeedFixture();
  mutate(workbench);
  vi.spyOn(api, "getReview").mockResolvedValue({
    kind: "success",
    response: { success: true, workbench },
  } as never);
  renderReview(api);
  return api;
}

async function saveAll(
  api = createReviewConfirmedNeedApi("ready"),
  onPurchaseHandoffReleased?: () => void,
) {
  renderReview(api, onPurchaseHandoffReleased);
  await screen.findByText("Gạo thơm");
  fireEvent.click(screen.getByRole("button", { name: "Lưu" }));
  await screen.findByText("Đã lưu thay đổi.");
  return api;
}

describe("Confirmed Need two-action workbench", () => {
  it("uses all three canonical Planning review schools", () => {
    const fixture = createReviewConfirmedNeedFixture(3);

    expect(fixture.lines.map((line) => line.school)).toEqual([
      {
        id: "review-planning-school-1",
        name: "Trường Tiểu học Nguyễn Du",
      },
      {
        id: "review-planning-school-2",
        name: "Trường Tiểu học Trần Quốc Toản",
      },
      {
        id: "review-planning-school-3",
        name: "Trường Mầm non Hoa Hồng",
      },
    ]);
  });

  it("shows the current work context in first-time operator language", async () => {
    renderReview();
    await screen.findByText("Gạo thơm");
    expect(
      screen.getByRole("heading", { name: "Xác nhận nhu cầu" }),
    ).toBeVisible();
    expect(screen.getByText("Tuần 03/08/2026–09/08/2026")).toBeVisible();
    expect(screen.getAllByText("Tất cả trường").length).toBeGreaterThan(0);
    expect(screen.getByText("2 dòng")).toBeVisible();
    expect(screen.getAllByText("Chưa lưu").length).toBeGreaterThan(0);
  });

  it("keeps a successful single-date read table-first", async () => {
    renderAuthoritativeFixture((workbench) => {
      workbench.lines = workbench.lines.map((line) => ({
        ...line,
        service_date: "2026-08-03",
      }));
    });
    await screen.findByText("Gạo thơm");

    expect(
      screen.queryByText("Đã cập nhật dữ liệu xác nhận nhu cầu."),
    ).not.toBeInTheDocument();
    const toolbar = screen.getByRole("region", {
      name: "Bộ lọc xác nhận nhu cầu",
    });
    expect(within(toolbar).queryByLabelText("Ngày")).not.toBeInTheDocument();
  });

  it("maps governed lifecycle blockers to concise operator language", async () => {
    renderAuthoritativeFixture((workbench) => {
      workbench.blockers = [
        {
          code: "CONFIRMED_NEED_BATCH_NOT_REVIEWABLE",
          message: "The batch is not in a reviewable lifecycle state.",
        },
      ];
    });
    await screen.findByText("Gạo thơm");

    expect(
      screen.getByText("Nhu cầu này chưa ở trạng thái có thể rà soát."),
    ).toBeVisible();
    expect(
      screen.queryByText("The batch is not in a reviewable lifecycle state."),
    ).not.toBeInTheDocument();
  });

  it("orders the selected-date workbench as summary, conditional notices, filters, table, then collapsed support", async () => {
    renderAuthoritativeFixture((workbench) => {
      workbench.warnings = [
        { code: "REVIEW_WARNING", message: "Kiểm tra dòng cảnh báo." },
      ];
      workbench.lifecycle_history = [
        {
          evidence_kind: "VALIDATION",
          evidence_id: "evidence-1",
          outcome: "VALIDATED",
          source_version: 1,
          resulting_version: 1,
          occurred_at: "2026-08-03T08:00:00Z",
          actor: { id: "operator-1", name: "Điều phối viên" },
          reason_code: "REVIEW_COMPLETED",
          warning_count: 1,
        },
      ];
    });
    await screen.findByText("Gạo thơm");

    const shell = screen.getByRole("region", {
      name: "Bàn xác nhận nhu cầu",
    });
    const ordered = [
      within(shell).getByRole("heading", { name: "Xác nhận nhu cầu" }),
      within(shell).getByRole("region", { name: "Tóm tắt xác nhận nhu cầu" }),
      within(shell).getByRole("region", { name: "Cảnh báo" }),
      within(shell).getByRole("region", { name: "Bộ lọc xác nhận nhu cầu" }),
      within(shell).getByRole("region", { name: "Bảng xác nhận nhu cầu" }),
      within(shell).getByText("Lịch sử xử lý"),
    ];
    ordered.slice(1).forEach((element, index) => {
      expect(
        ordered[index]!.compareDocumentPosition(element) &
          Node.DOCUMENT_POSITION_FOLLOWING,
      ).toBeTruthy();
    });
    expect(within(shell).getByText("2 dòng")).toBeVisible();
    expect(within(shell).getByText(/cần rà soát/)).toBeVisible();
    expect(within(shell).getByText(/đã xác nhận/)).toBeVisible();
    expect(within(shell).getByText(/đã điều chỉnh/)).toBeVisible();
    expect(
      within(shell).queryByText(/tổng số lượng|tổng nhu cầu/i),
    ).not.toBeInTheDocument();
    expect(
      within(shell).getByText("Lịch sử xử lý").closest("details"),
    ).not.toHaveAttribute("open");
  });

  it("keeps the governed line table flat and compact", async () => {
    renderReview();
    await screen.findByText("Gạo thơm");
    const tableRegion = screen.getByRole("region", {
      name: "Bảng xác nhận nhu cầu",
    });
    const table = within(tableRegion).getByRole("table");
    expect(within(table).getAllByRole("row")).toHaveLength(3);
    expect(
      within(table).queryByText(/nhóm nguyên liệu/i),
    ).not.toBeInTheDocument();
    [
      "Nguyên liệu / nơi nhận",
      "Đơn vị",
      "Nhu cầu tính",
      "Số lượng xác nhận",
      "Chênh lệch",
      "Lý do / ghi chú",
    ].forEach((header) =>
      expect(
        within(table).getByRole("columnheader", { name: header }),
      ).toBeVisible(),
    );
    const riceRow = within(table).getByText("Gạo thơm").closest("tr")!;
    expect(
      within(riceRow).getByText("Trường Tiểu học Nguyễn Du"),
    ).toBeVisible();
    expect(within(riceRow).getByText("Bếp phụ")).toBeVisible();
    expect(within(riceRow).getByText("kg")).toBeVisible();
    expect(within(riceRow).getByText("10,25")).toBeVisible();
    expect(
      within(riceRow).getByLabelText("Số lượng xác nhận Gạo thơm"),
    ).toBeVisible();
  });

  it("filters only the display by current draft difference and still saves the full changed payload", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    const save = vi.spyOn(api, "save");
    renderReview(api);
    await screen.findByText("Gạo thơm");

    fireEvent.change(screen.getByLabelText("Số lượng xác nhận Gạo thơm"), {
      target: { value: "10.5" },
    });
    fireEvent.click(
      screen.getByRole("checkbox", {
        name: "Chỉ hiển thị dòng có chênh lệch",
      }),
    );
    expect(screen.getByText("Gạo thơm")).toBeVisible();
    expect(screen.queryByText("Cà rốt")).not.toBeInTheDocument();
    expect(screen.getByText("Hiển thị 1/2 dòng")).toBeVisible();

    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));
    await waitFor(() => expect(save).toHaveBeenCalledTimes(1));
    expect(save.mock.calls[0]?.[0].payload.lines).toHaveLength(2);
  });

  it.each([
    ["ingredient", "cà rốt", "Cà rốt"],
    ["school", "nguyễn du", "Trường Tiểu học Nguyễn Du"],
    ["delivery location", "bếp phụ", "Bếp phụ"],
  ])("searches loaded %s fields", async (_kind, query, expected) => {
    renderReview();
    await screen.findByText("Gạo thơm");
    fireEvent.change(
      screen.getByPlaceholderText("Tìm theo nguyên liệu, trường, điểm giao…"),
      { target: { value: query } },
    );
    expect(
      screen
        .getAllByText(expected)
        .some((element) => element.tagName !== "OPTION"),
    ).toBe(true);
    expect(screen.getByText("Hiển thị 1/2 dòng")).toBeVisible();
  });

  it("composes external school scope with search, date, and confirmation filters", async () => {
    const api = createReviewConfirmedNeedApi("ready", { lineCount: 3 });
    renderScopedReview(api, ["review-planning-school-3"]);
    await screen.findByText("Gạo thơm 3");
    expect(screen.queryByText("Cà rốt")).not.toBeInTheDocument();

    const toolbar = screen.getByRole("region", {
      name: "Bộ lọc xác nhận nhu cầu",
    });
    fireEvent.change(
      within(toolbar).getByPlaceholderText(
        "Tìm theo nguyên liệu, trường, điểm giao…",
      ),
      { target: { value: "gạo thơm 3" } },
    );
    fireEvent.change(within(toolbar).getByLabelText("Ngày"), {
      target: { value: "2026-08-05" },
    });
    fireEvent.change(within(toolbar).getByLabelText("Tình trạng"), {
      target: { value: "needs_review" },
    });
    expect(screen.getByText("Hiển thị 1/3 dòng")).toBeVisible();
  });

  it("keeps hidden dirty edits and includes them in Save", async () => {
    const api = createReviewConfirmedNeedApi("ready", { lineCount: 3 });
    const workbench = createReviewConfirmedNeedFixture(3);
    workbench.lines.forEach((line, index) => {
      line.current_decision_id = `review-current-decision-${index + 1}`;
      line.current_decision_number = 1;
      line.current_decision_kind = "PROPOSAL_ACCEPTED";
      line.confirmed_quantity_after = line.proposed_confirmed_quantity;
      line.confirmation_state = "CONFIRMED_CURRENT";
    });
    workbench.line_counts = {
      ...workbench.line_counts,
      unreviewed: 0,
      confirmed: 3,
      needs_review: 0,
      new: 0,
    };
    vi.spyOn(api, "getReview").mockResolvedValue({
      kind: "success",
      response: { success: true, workbench },
    } as never);
    const save = vi.spyOn(api, "save");
    const view = renderScopedReview(api, []);
    await screen.findByText("Gạo thơm");

    fireEvent.change(screen.getByLabelText("Số lượng xác nhận Gạo thơm"), {
      target: { value: "10.5" },
    });
    fireEvent.change(screen.getByLabelText("Ghi chú Gạo thơm"), {
      target: { value: "Điều chỉnh trường 1" },
    });
    fireEvent.change(screen.getByLabelText("Số lượng xác nhận Cà rốt"), {
      target: { value: "5.5" },
    });
    fireEvent.change(screen.getByLabelText("Ghi chú Cà rốt"), {
      target: { value: "Điều chỉnh trường 2" },
    });

    view.rerender(reviewTree(api, ["review-planning-school-2"]));
    expect(screen.queryByText("Gạo thơm")).not.toBeInTheDocument();
    expect(
      screen.getByText(
        "Có 1 thay đổi chưa lưu ngoài phạm vi trường đang hiển thị. Lưu vẫn áp dụng cho toàn bộ thay đổi hiện tại.",
      ),
    ).toBeVisible();
    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));

    await waitFor(() => expect(save).toHaveBeenCalledTimes(1));
    expect(save.mock.calls[0]?.[0].payload.lines).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          confirmed_need_line_id: "c4520000-0000-0000-0000-000000000001",
          proposed_confirmed_quantity: "10.5",
        }),
        expect.objectContaining({
          confirmed_need_line_id: "c4520000-0000-0000-0000-000000000002",
          proposed_confirmed_quantity: "5.5",
        }),
      ]),
    );
  });

  it("shows only the current primary action in the Planning rail", async () => {
    renderReview();
    await screen.findByText("Gạo thơm");
    const rail = screen.getByLabelText("Hành động bước hiện tại");
    expect(within(rail).getByRole("button", { name: "Lưu" })).toBeVisible();
    expect(
      within(rail).queryByRole("button", { name: "Chuyển sang lên đơn" }),
    ).not.toBeInTheDocument();
    expect(screen.queryByRole("contentinfo")).not.toBeInTheDocument();
    expect(
      screen.queryByRole("button", {
        name: /Hoàn tất xác nhận|Phê duyệt|Phát hành/,
      }),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByText(/250|API|capability|batch ID|phiên bản/i),
    ).not.toBeInTheDocument();
  });

  it("saves through one v2 command and does not release", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    const save = vi.spyOn(api, "save");
    const release = vi.spyOn(api, "releaseSaved");
    await saveAll(api);
    expect(save).toHaveBeenCalledTimes(1);
    expect(save.mock.calls[0]?.[0].payload.lines).toHaveLength(2);
    expect(release).not.toHaveBeenCalled();
    expect(screen.getAllByText("Đã lưu").length).toBeGreaterThan(0);
  });

  it("presents backend continuity states and omits untouched carried lines from Save", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    const workbench = createReviewConfirmedNeedFixture();
    const carried = workbench.lines[0]!;
    carried.current_decision_id = "c4520000-0000-0000-0000-000000000091";
    carried.current_decision_number = 1;
    carried.current_decision_kind = "ADJUSTED_QUANTITY_CONFIRMED";
    carried.confirmed_quantity_after = "10.000000";
    carried.confirmation_state = "CARRIED_FORWARD";
    workbench.lines[1]!.confirmation_state = "CHANGED";
    workbench.line_counts = {
      total: 2,
      unreviewed: 1,
      confirmed: 1,
      adjusted: 1,
      carried_forward: 1,
      needs_review: 1,
      changed: 1,
      new: 0,
      removed: 0,
    };
    vi.spyOn(api, "getReview").mockResolvedValue({
      kind: "success",
      response: { success: true, workbench },
    } as never);
    const save = vi.spyOn(api, "save");
    renderReview(api);

    await screen.findByText("Gạo thơm");
    expect(screen.getByText("1 cần rà soát")).toBeVisible();
    expect(screen.getByText("1 đã xác nhận")).toBeVisible();
    expect(
      screen
        .getAllByText("Giữ nguyên")
        .some((element) => element.tagName !== "OPTION"),
    ).toBe(true);
    expect(screen.getAllByText("Cần rà soát").length).toBeGreaterThan(1);
    fireEvent.change(screen.getByLabelText("Tình trạng"), {
      target: { value: "carried_forward" },
    });
    expect(screen.getByText("Hiển thị 1/2 dòng")).toBeVisible();
    fireEvent.change(screen.getByLabelText("Tình trạng"), {
      target: { value: "" },
    });

    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));
    await waitFor(() => expect(save).toHaveBeenCalledTimes(1));
    expect(save.mock.calls[0]?.[0].payload.lines).toEqual([
      expect.objectContaining({
        confirmed_need_line_id: "c4520000-0000-0000-0000-000000000002",
      }),
    ]);
  });

  it("does not promote Save when authoritative readback denies it", async () => {
    const api = renderAuthoritativeFixture((workbench) => {
      workbench.allowed_actions.save_confirmed_needs = false;
      workbench.disabled_reason_codes.save_confirmed_needs =
        "SAVE_CAPABILITY_REQUIRED";
      workbench.disabled_reasons.save_confirmed_needs =
        "Bạn chưa có quyền lưu thay đổi này.";
    });
    await screen.findByText("Gạo thơm");
    const save = screen.getByRole("button", { name: "Lưu" });
    const saveRequest = vi.spyOn(api, "save");
    expect(save).toBeDisabled();
    expect(save).not.toHaveClass("primary");
    expect(save).toHaveAttribute(
      "title",
      "Bạn chưa có quyền lưu thay đổi này.",
    );
    expect(
      within(screen.getByLabelText("Hành động bước hiện tại")).queryByRole(
        "status",
      ),
    ).not.toBeInTheDocument();
    fireEvent.click(save);
    expect(saveRequest).not.toHaveBeenCalled();
  });

  it("does not promote Release when authoritative readback denies it", async () => {
    renderAuthoritativeFixture((workbench) => {
      workbench.lines = workbench.lines.map((line, index) => ({
        ...line,
        current_decision_id: `c4520000-0000-0000-0000-00000000000${index + 1}`,
        current_decision_number: 1,
        confirmed_quantity_after: line.proposed_confirmed_quantity,
      }));
      workbench.line_counts = {
        total: workbench.lines.length,
        unreviewed: 0,
        confirmed: workbench.lines.length,
        adjusted: 0,
        carried_forward: 0,
        needs_review: 0,
        changed: 0,
        new: 0,
        removed: 0,
      };
      workbench.allowed_actions.release_confirmed_needs = false;
      workbench.disabled_reason_codes.release_confirmed_needs =
        "RELEASE_CAPABILITY_REQUIRED";
      workbench.disabled_reasons.release_confirmed_needs =
        "Bạn chưa có quyền thực hiện bước này.";
    });
    await screen.findByText("Gạo thơm");
    const release = screen.getByRole("button", {
      name: "Chuyển sang lên đơn",
    });
    expect(release).toBeDisabled();
    expect(release).not.toHaveClass("primary");
    expect(release).toHaveAttribute(
      "title",
      "Bạn chưa có quyền thực hiện bước này.",
    );
  });

  it("uses backend eligibility as a ceiling and local validity as a stricter gate", async () => {
    renderReview();
    await screen.findByText("Gạo thơm");
    const save = screen.getByRole("button", { name: "Lưu" });
    expect(save).toBeEnabled();
    expect(save).toHaveClass("primary");
    fireEvent.change(screen.getByLabelText("Số lượng xác nhận Gạo thơm"), {
      target: { value: "không hợp lệ" },
    });
    expect(save).toBeDisabled();
    expect(save).not.toHaveClass("primary");
  });

  it("releases only after a current complete save and concise confirmation", async () => {
    const api = await saveAll();
    const release = vi.spyOn(api, "releaseSaved");
    const releaseButton = screen.getByRole("button", {
      name: "Chuyển sang lên đơn",
    });
    expect(releaseButton).toBeEnabled();
    expect(releaseButton).toHaveClass("primary");
    fireEvent.click(releaseButton);
    const dialog = screen.getByRole("dialog", {
      name: "Xác nhận chuyển sang lên đơn",
    });
    expect(dialog).toHaveTextContent("chưa phân bổ nhà cung cấp");
    expect(dialog).toHaveTextContent("chưa tạo Bàn giao mua hàng");
    expect(dialog).toHaveTextContent("chưa tạo Đơn mua hàng");
    fireEvent.click(screen.getByRole("button", { name: "Xác nhận chuyển" }));
    await screen.findByText("Đã chuyển sang lên đơn.");
    expect(release).toHaveBeenCalledTimes(1);
    expect(
      screen.getAllByText("Đã chuyển sang lên đơn").length,
    ).toBeGreaterThan(0);
    expect(screen.getByLabelText("Số lượng xác nhận Cà rốt")).toBeDisabled();
  });

  it("does not attempt the Purchase Handoff when Confirmed Need release fails", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    const releasePurchaseHandoff = vi.fn().mockResolvedValue({
      kind: "success",
      response: { success: true },
    });
    Object.assign(api, { releasePurchaseHandoff });
    await saveAll(api);
    const releaseSaved = vi.spyOn(api, "releaseSaved").mockResolvedValue({
      kind: "backend_error",
      error: {
        success: false,
        error_code: "CONFIRMED_NEED_RELEASE_BLOCKED",
        safe_message: "Nhu cầu chưa thể phát hành.",
      },
    });

    fireEvent.click(
      screen.getByRole("button", { name: "Chuyển sang lên đơn" }),
    );
    fireEvent.click(screen.getByRole("button", { name: "Xác nhận chuyển" }));

    expect(
      await screen.findByText("Nhu cầu chưa thể phát hành."),
    ).toBeVisible();
    expect(releaseSaved).toHaveBeenCalledTimes(1);
    expect(releasePurchaseHandoff).not.toHaveBeenCalled();
  });

  it("keeps the durable intermediate state and retries only the same Handoff intent", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    const onPurchaseHandoffReleased = vi.fn();
    const handoffFailure = {
      kind: "backend_error" as const,
      error: {
        success: false as const,
        error_code: "RETRYABLE_CONCURRENCY_FAILURE",
        safe_message: "Bàn giao mua hàng chưa được tạo.",
        retryable: true,
      },
    };
    const releasePurchaseHandoff = vi
      .fn()
      .mockResolvedValueOnce(handoffFailure)
      .mockResolvedValue({
        kind: "success",
        response: {
          success: true,
          safe_operator_message: "Đã tạo Bàn giao mua hàng.",
        },
      });
    Object.assign(api, { releasePurchaseHandoff });
    await saveAll(api, onPurchaseHandoffReleased);
    const releaseSaved = vi.spyOn(api, "releaseSaved");

    fireEvent.click(
      screen.getByRole("button", { name: "Chuyển sang lên đơn" }),
    );
    fireEvent.click(screen.getByRole("button", { name: "Xác nhận chuyển" }));

    expect(
      await screen.findByText(/Nhu cầu đã được phát hành.*Bàn giao mua hàng/),
    ).toBeVisible();
    expect(
      screen.getByRole("button", { name: "Thử lại bàn giao" }),
    ).toBeEnabled();
    expect(releaseSaved).toHaveBeenCalledTimes(1);
    expect(releasePurchaseHandoff).toHaveBeenCalledTimes(1);
    const firstIntent = releasePurchaseHandoff.mock.calls[0]?.[0];

    fireEvent.click(screen.getByRole("button", { name: "Thử lại bàn giao" }));

    await waitFor(() =>
      expect(releasePurchaseHandoff).toHaveBeenCalledTimes(2),
    );
    expect(releasePurchaseHandoff.mock.calls[1]?.[0]).toBe(firstIntent);
    expect(releaseSaved).toHaveBeenCalledTimes(1);
    await waitFor(() =>
      expect(onPurchaseHandoffReleased).toHaveBeenCalledOnce(),
    );
  });

  it("refreshes authoritative Planning state and navigates after both commands succeed", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    const onPurchaseHandoffReleased = vi.fn();
    const releasePurchaseHandoff = vi.fn().mockResolvedValue({
      kind: "success",
      response: {
        success: true,
        safe_operator_message: "Đã tạo Bàn giao mua hàng.",
      },
    });
    Object.assign(api, { releasePurchaseHandoff });
    await saveAll(api, onPurchaseHandoffReleased);
    const getReview = vi.spyOn(api, "getReview");
    const releaseSaved = vi.spyOn(api, "releaseSaved");

    fireEvent.click(
      screen.getByRole("button", { name: "Chuyển sang lên đơn" }),
    );
    fireEvent.click(screen.getByRole("button", { name: "Xác nhận chuyển" }));

    await waitFor(() =>
      expect(onPurchaseHandoffReleased).toHaveBeenCalledOnce(),
    );
    expect(releaseSaved).toHaveBeenCalledTimes(1);
    expect(releasePurchaseHandoff).toHaveBeenCalledTimes(1);
    expect(getReview).toHaveBeenCalledTimes(1);
    expect(await screen.findByText("Đã chuyển sang lên đơn.")).toBeVisible();
  });

  it("requires authoritative refresh after an unknown Save outcome without automatic retry", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    const save = vi.spyOn(api, "save").mockResolvedValue({
      kind: "transport_error",
      diagnostic: { code: "NETWORK_FAILURE", safeMessage: "Mất kết nối." },
    });
    renderReview(api);
    await screen.findByText("Gạo thơm");
    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));
    expect(await screen.findByText(/Atlas sẽ không tự gửi lại/)).toBeVisible();
    expect(save).toHaveBeenCalledTimes(1);
    await waitFor(() =>
      expect(screen.getByRole("button", { name: "Lưu" })).toBeDisabled(),
    );
    expect(screen.getByRole("button", { name: "Làm mới" })).toBeEnabled();
  });

  it("does not show unsupported export UI", async () => {
    renderReview();
    await screen.findByText("Gạo thơm");
    expect(
      screen.queryByRole("button", { name: "Xuất Excel" }),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: "Xuất PDF" }),
    ).not.toBeInTheDocument();
    expect(screen.queryByText(/Chức năng xuất file/)).not.toBeInTheDocument();
    expect(screen.queryByText("Nhập Excel")).not.toBeInTheDocument();
  });

  it("uses the approved compact Planning dimensions and mobile breakpoint", async () => {
    renderReview();
    await screen.findByText("Gạo thơm");
    const { readFileSync } = await vi.importActual<{
      readFileSync(path: string | URL, encoding: "utf8"): string;
    }>("node:fs");
    const styles = readFileSync("src/styles.css", "utf8");
    expect(styles).toContain("--planning-rail-height: 54px");
    expect(styles).toContain("--planning-control-height: 32px");
    expect(styles).toContain("--planning-row-height: 40px");
    expect(styles).toContain("--planning-header-row-height: 36px");
    expect(styles).toContain("--planning-cell-inline: 12px");
    expect(styles).toContain("@media (max-width: 56.25em)");
    expect(styles).toContain("min-height: 44px");
  });
});
