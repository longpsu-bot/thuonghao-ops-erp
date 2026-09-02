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

function configureSavedAdjustmentFixture(
  workbench: ReturnType<typeof createReviewConfirmedNeedFixture>,
) {
  const adjusted = workbench.lines[0]!;
  adjusted.theoretical_quantity = "23.500000";
  adjusted.proposed_confirmed_quantity = "30.000000";
  adjusted.current_decision_id = "saved-adjustment-decision";
  adjusted.current_decision_number = 3;
  adjusted.current_decision_kind = "ADJUSTED_QUANTITY_CONFIRMED";
  adjusted.confirmed_quantity_after = "30.000000";
  adjusted.confirmation_state = "CONFIRMED_CURRENT";
  adjusted.decision_history = [
    {
      decision_id: "saved-adjustment-decision",
      decision_number: 3,
      predecessor_decision_id: "prior-adjustment-decision",
      decision_kind: "ADJUSTED_QUANTITY_CONFIRMED",
      revision_id: adjusted.current_revision_id,
      theoretical_quantity_before: "23.500000",
      proposed_quantity_before: "30.000000",
      confirmed_quantity_after: "30.000000",
      planning_tick_count: "120",
      reason_code: "OPERATIONAL_QUANTITY_ADJUSTMENT",
      reason_note: "Điều chỉnh theo suất ăn thực tế",
      policy_revision_id: adjusted.effective_policy!.revision_id,
      decided_at: "2026-08-24T08:00:00Z",
      batch_version: 7,
    },
  ];

  const accepted = workbench.lines[1]!;
  accepted.current_decision_id = "saved-accepted-decision";
  accepted.current_decision_number = 1;
  accepted.current_decision_kind = "UNCHANGED_PROPOSAL_ACCEPTED";
  accepted.confirmed_quantity_after = accepted.proposed_confirmed_quantity;
  accepted.confirmation_state = "CONFIRMED_CURRENT";

  workbench.batch_status = "REOPENED";
  workbench.authoritative_batch_status = "REOPENED";
  workbench.batch_version = 7;
  workbench.line_counts = {
    ...workbench.line_counts,
    unreviewed: Math.max(0, workbench.lines.length - 2),
    confirmed: Math.min(2, workbench.lines.length),
    adjusted: 1,
    needs_review: Math.max(0, workbench.lines.length - 2),
    new: Math.max(0, workbench.lines.length - 2),
  };
  workbench.allowed_actions.save_confirmed_needs = true;
  workbench.allowed_actions.release_confirmed_needs =
    workbench.lines.length === 2;
  workbench.disabled_reason_codes.release_confirmed_needs =
    workbench.lines.length === 2 ? null : "RELEASE_INCOMPLETE";
  workbench.disabled_reasons.release_confirmed_needs =
    workbench.lines.length === 2
      ? null
      : "Còn dòng cần xử lý trước khi chuyển sang lên đơn.";
  return adjusted;
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
    expect(screen.getByText("Ngày đang xác nhận")).toBeVisible();
    expect(
      screen.queryByRole("heading", { name: "Xác nhận nhu cầu" }),
    ).not.toBeInTheDocument();
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
      within(shell).getByText("Ngày đang xác nhận"),
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
      "Thay đổi chưa lưu",
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

  it("filters only the display by unsaved local change and still saves the full changed payload", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    const save = vi.spyOn(api, "save");
    renderReview(api);
    await screen.findByText("Gạo thơm");

    fireEvent.change(screen.getByLabelText("Số lượng xác nhận Gạo thơm"), {
      target: { value: "10.5" },
    });
    fireEvent.click(
      screen.getByRole("checkbox", {
        name: "Chỉ hiển thị thay đổi chưa lưu",
      }),
    );
    expect(screen.getByText("Gạo thơm")).toBeVisible();
    expect(screen.getByText("Cà rốt")).toBeVisible();
    expect(screen.getByText("Hiển thị 2/2 dòng")).toBeVisible();

    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));
    await waitFor(() => expect(save).toHaveBeenCalledTimes(1));
    expect(save.mock.calls[0]?.[0].payload.lines).toHaveLength(2);
  });

  it("keeps a clean saved adjustment error-free and eligible for Release", async () => {
    renderAuthoritativeFixture(configureSavedAdjustmentFixture);
    await screen.findByText("Gạo thơm");
    const row = screen.getByText("Gạo thơm").closest("tr")!;

    expect(within(row).getByText("23,5")).toBeVisible();
    expect(
      within(row).getByLabelText("Số lượng xác nhận Gạo thơm"),
    ).toHaveValue("30.000000");
    expect(within(row).getByText("Đã lưu")).toBeVisible();
    expect(screen.getByText("1 đã điều chỉnh")).toBeVisible();
    expect(
      screen.queryByText("Số lượng không đổi nên không cần lý do điều chỉnh."),
    ).not.toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "Chuyển sang lên đơn" }),
    ).toBeEnabled();
  });

  it("shows the persisted adjustment reason and note instead of proposal acceptance", async () => {
    renderAuthoritativeFixture(configureSavedAdjustmentFixture);
    await screen.findByText("Gạo thơm");
    const row = screen.getByText("Gạo thơm").closest("tr")!;

    expect(
      within(row).getByRole("combobox", { name: "Lý do điều chỉnh Gạo thơm" }),
    ).toHaveValue("OPERATIONAL_QUANTITY_ADJUSTMENT");
    expect(within(row).getByLabelText("Ghi chú Gạo thơm")).toHaveValue(
      "Điều chỉnh theo suất ăn thực tế",
    );
    expect(
      within(row).queryByText("Chấp nhận đề xuất"),
    ).not.toBeInTheDocument();
  });

  it("marks a 30 to 31 quantity edit dirty and shows a +1 unsaved change", async () => {
    renderAuthoritativeFixture(configureSavedAdjustmentFixture);
    await screen.findByText("Gạo thơm");
    const row = screen.getByText("Gạo thơm").closest("tr")!;

    fireEvent.change(within(row).getByLabelText("Số lượng xác nhận Gạo thơm"), {
      target: { value: "31" },
    });

    expect(within(row).getByText("+1")).toBeVisible();
    expect(screen.getByRole("button", { name: "Lưu" })).toBeEnabled();

    fireEvent.change(within(row).getByLabelText("Số lượng xác nhận Gạo thơm"), {
      target: { value: "29" },
    });
    expect(within(row).getByText("-1")).toBeVisible();
  });

  it("restores the saved baseline, reason, and note after 30 to 31 to 30", async () => {
    renderAuthoritativeFixture(configureSavedAdjustmentFixture);
    await screen.findByText("Gạo thơm");
    const row = screen.getByText("Gạo thơm").closest("tr")!;
    const quantity = within(row).getByLabelText("Số lượng xác nhận Gạo thơm");

    fireEvent.change(quantity, { target: { value: "31" } });
    fireEvent.change(quantity, { target: { value: "30" } });

    expect(within(row).getByText("—")).toBeVisible();
    expect(within(row).getByLabelText("Lý do điều chỉnh Gạo thơm")).toHaveValue(
      "OPERATIONAL_QUANTITY_ADJUSTMENT",
    );
    expect(within(row).getByLabelText("Ghi chú Gạo thơm")).toHaveValue(
      "Điều chỉnh theo suất ăn thực tế",
    );
    expect(
      screen.queryByText("Số lượng không đổi nên không cần lý do điều chỉnh."),
    ).not.toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "Chuyển sang lên đơn" }),
    ).toBeEnabled();
  });

  it("treats a reason-note-only edit as an unsaved filtered and validated Save line", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    const workbench = createReviewConfirmedNeedFixture();
    configureSavedAdjustmentFixture(workbench);
    vi.spyOn(api, "getReview").mockResolvedValue({
      kind: "success",
      response: { success: true, workbench },
    } as never);
    const save = vi.spyOn(api, "save");
    renderReview(api);
    await screen.findByText("Gạo thơm");

    fireEvent.change(screen.getByLabelText("Ghi chú Gạo thơm"), {
      target: { value: "" },
    });
    fireEvent.click(
      screen.getByRole("checkbox", { name: "Chỉ hiển thị thay đổi chưa lưu" }),
    );
    expect(screen.getByText("Gạo thơm")).toBeVisible();
    expect(screen.queryByText("Cà rốt")).not.toBeInTheDocument();
    expect(screen.getByText("Lý do này cần ghi chú.")).toBeVisible();
    expect(screen.getByRole("button", { name: "Lưu" })).toBeDisabled();

    fireEvent.change(screen.getByLabelText("Ghi chú Gạo thơm"), {
      target: { value: "Cập nhật ghi chú vận hành" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));
    await waitFor(() => expect(save).toHaveBeenCalledTimes(1));
    expect(save.mock.calls[0]?.[0].payload.lines).toEqual([
      expect.objectContaining({
        confirmed_need_line_id: workbench.lines[0]!.confirmed_need_line_id,
        reason_code: "OPERATIONAL_QUANTITY_ADJUSTMENT",
        reason_note: "Cập nhật ghi chú vận hành",
      }),
    ]);
  });

  it("filters out clean saved adjustments while including changed and new lines", async () => {
    const api = createReviewConfirmedNeedApi("ready", { lineCount: 3 });
    const workbench = createReviewConfirmedNeedFixture(3);
    configureSavedAdjustmentFixture(workbench);
    vi.spyOn(api, "getReview").mockResolvedValue({
      kind: "success",
      response: { success: true, workbench },
    } as never);
    renderReview(api);
    await screen.findByText("Gạo thơm");

    fireEvent.change(screen.getByLabelText("Số lượng xác nhận Cà rốt"), {
      target: { value: "6" },
    });
    fireEvent.click(
      screen.getByRole("checkbox", { name: "Chỉ hiển thị thay đổi chưa lưu" }),
    );

    expect(screen.queryByText("Gạo thơm")).not.toBeInTheDocument();
    expect(screen.getByText("Cà rốt")).toBeVisible();
    expect(screen.getByText("Gạo thơm 3")).toBeVisible();
    expect(screen.getByText("Hiển thị 2/3 dòng")).toBeVisible();
  });

  it("executes Release directly for a clean saved adjustment", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    const workbench = createReviewConfirmedNeedFixture();
    configureSavedAdjustmentFixture(workbench);
    vi.spyOn(api, "getReview").mockResolvedValue({
      kind: "success",
      response: { success: true, workbench },
    } as never);
    const releaseSaved = vi.spyOn(api, "releaseSaved").mockResolvedValue({
      kind: "backend_error",
      error: {
        success: false,
        error_code: "TEST_RELEASE_STOP",
        safe_message: "Dừng sau khi xác nhận lệnh phát hành.",
      },
    });
    renderReview(api);
    await screen.findByText("Gạo thơm");

    fireEvent.click(
      screen.getByRole("button", { name: "Chuyển sang lên đơn" }),
    );
    fireEvent.click(screen.getByRole("button", { name: "Xác nhận chuyển" }));

    await waitFor(() => expect(releaseSaved).toHaveBeenCalledTimes(1));
    expect(releaseSaved.mock.calls[0]?.[0].expected_version).toBe(7);
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

  it("truthfully confirms that release creates or updates Purchase Handoff before Procurement", async () => {
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
    expect(dialog).toHaveTextContent(
      "tạo hoặc cập nhật Bàn giao mua hàng sang Thu mua",
    );
    expect(dialog).toHaveTextContent("chưa phân bổ nhà cung cấp");
    expect(dialog).toHaveTextContent("chưa tạo Đơn mua");
    expect(dialog).not.toHaveTextContent("chưa tạo Bàn giao mua hàng");
    fireEvent.click(screen.getByRole("button", { name: "Xác nhận chuyển" }));
    await screen.findByText("Đã chuyển sang lên đơn.");
    expect(release).toHaveBeenCalledTimes(1);
    expect(
      screen.getAllByText("Đã chuyển sang lên đơn").length,
    ).toBeGreaterThan(0);
    expect(
      screen.queryByRole("button", { name: "Chuyển sang lên đơn" }),
    ).not.toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: "Lưu" }),
    ).not.toBeInTheDocument();
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

  it("keeps the embedded review subordinate to the active page heading", async () => {
    renderReview();
    await screen.findByText("Gạo thơm");
    const shell = screen.getByRole("region", {
      name: "Bàn xác nhận nhu cầu",
    });
    expect(within(shell).getByText("Ngày đang xác nhận")).toBeVisible();
    expect(within(shell).queryByRole("heading")).not.toBeInTheDocument();
    expect(
      within(shell).getByRole("region", { name: "Bảng xác nhận nhu cầu" }),
    ).toBeVisible();
  });
});
