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
  onContinueAllocation: (serviceDate: string) => void = vi.fn(),
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
        onContinueAllocation={onContinueAllocation}
      />
    </PlanningRailActionProvider>
  );
}

function renderReview(
  api = createReviewConfirmedNeedApi("ready"),
  onContinueAllocation: (serviceDate: string) => void = vi.fn(),
) {
  render(reviewTree(api, [], onContinueAllocation));
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
  onContinueAllocation: (serviceDate: string) => void = vi.fn(),
) {
  renderReview(api, onContinueAllocation);
  await screen.findByText("Gạo thơm");
  fireEvent.click(screen.getByRole("button", { name: "Lưu" }));
  await screen.findByText("Đã lưu thay đổi.");
  return api;
}

describe("Confirmed Need two-action workbench", () => {
  it("continues to allocation for the same working date without release or Handoff commands", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    const navigate = vi.fn();
    const release = vi.spyOn(api, "releaseSaved");
    const handoff = vi.spyOn(api, "releasePurchaseHandoff");
    render(
      <PlanningRailActionProvider>
        <PlanningRailActionHost />
        <ConfirmedNeedReviewWorkbench
          authState={authState}
          api={api}
          initialBatchId={batchId}
          workingServiceDate="2026-08-03"
          onContinueAllocation={navigate}
        />
      </PlanningRailActionProvider>,
    );
    await screen.findByText("Gạo thơm");
    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));
    await screen.findByText("Đã lưu thay đổi.");
    fireEvent.click(
      screen.getByRole("button", { name: "Tiếp tục phân bổ NCC" }),
    );
    expect(navigate).toHaveBeenCalledWith("2026-08-03");
    expect(release).not.toHaveBeenCalled();
    expect(handoff).not.toHaveBeenCalled();
  });
  it.each(["10", "10.5", "10.25", "10,25", "99999999999999.25"])(
    "accepts %s and sends an exact decimal string",
    async (value) => {
      const api = renderAuthoritativeFixture((workbench) => {
        workbench.lines[0]!.proposed_confirmed_quantity = "12.000000";
      });
      const save = vi.spyOn(api, "save");
      const input = await screen.findByLabelText("Số lượng xác nhận Gạo thơm");
      fireEvent.change(input, { target: { value } });
      expect(input).not.toHaveAttribute("aria-invalid", "true");
      const button = screen.getByRole("button", { name: "Lưu" });
      expect(button).toBeEnabled();
      fireEvent.click(button);
      await waitFor(() => expect(save).toHaveBeenCalledOnce());
      expect(
        save.mock.calls[0]?.[0].payload.lines[0]?.proposed_confirmed_quantity,
      ).toBe(value.replace(",", "."));
    },
  );

  it.each(["10.256", "1.234567", "10,256", "10.250", "10.250000"])(
    "rejects %s without rounding or truncating and disables Save",
    async (value) => {
      const api = renderReview();
      const save = vi.spyOn(api, "save");
      const input = await screen.findByLabelText("Số lượng xác nhận Gạo thơm");
      fireEvent.change(input, { target: { value } });
      expect(input).toHaveValue(value);
      expect(input).toHaveAttribute("aria-invalid", "true");
      expect(input).toHaveAccessibleDescription(
        "Số lượng phải là số không âm, tối đa 2 chữ số thập phân.",
      );
      expect(screen.getByRole("button", { name: "Lưu" })).toBeDisabled();
      expect(save).not.toHaveBeenCalled();
    },
  );

  it.each([
    ["10.000000", "10"],
    ["10.500000", "10,5"],
    ["10.250000", "10,25"],
  ])(
    "displays backend %s as %s without changing saved authority",
    async (exact, display) => {
      const api = renderAuthoritativeFixture((workbench) => {
        configureSavedAdjustmentFixture(workbench);
        const line = workbench.lines[0]!;
        line.confirmed_quantity_after = exact;
        line.proposed_confirmed_quantity = exact;
      });
      const save = vi.spyOn(api, "save");
      expect(
        await screen.findByLabelText("Số lượng xác nhận Gạo thơm"),
      ).toHaveValue(display);
      expect(
        screen.queryByRole("button", { name: "Lưu" }),
      ).not.toBeInTheDocument();
      expect(
        screen.getByRole("button", { name: "Tiếp tục phân bổ NCC" }),
      ).toBeDisabled();
      expect(save).not.toHaveBeenCalled();
    },
  );

  it("preserves exceptional historical precision read-only and saves only other changed lines", async () => {
    const api = renderAuthoritativeFixture((workbench) => {
      configureSavedAdjustmentFixture(workbench);
      workbench.lines[0]!.confirmed_quantity_after = "10.256700";
      workbench.lines[0]!.proposed_confirmed_quantity = "10.256700";
    });
    const save = vi.spyOn(api, "save");
    const exact = await screen.findByLabelText("Số lượng xác nhận Gạo thơm");
    expect(exact).toHaveAttribute("readonly");
    expect(exact).toHaveValue("10,2567");
    expect(exact).toHaveAccessibleDescription(/Vượt độ chính xác chỉnh sửa v1/);
    fireEvent.change(screen.getByLabelText("Số lượng xác nhận Cà rốt"), {
      target: { value: "5.25" },
    });
    fireEvent.change(screen.getByLabelText("Ghi chú Cà rốt"), {
      target: { value: "Điều chỉnh thực tế" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));
    await waitFor(() => expect(save).toHaveBeenCalledOnce());
    expect(save.mock.calls[0]?.[0].payload.lines).toHaveLength(1);
    expect(
      save.mock.calls[0]?.[0].payload.lines[0]?.proposed_confirmed_quantity,
    ).toBe("5.25");
  });

  it("has no duplicate date filter even when a historical batch spans days", async () => {
    renderReview();
    await screen.findByText("Gạo thơm");
    const toolbar = screen.getByRole("region", {
      name: "Bộ lọc xác nhận nhu cầu",
    });
    expect(within(toolbar).queryByLabelText("Ngày")).not.toBeInTheDocument();
    expect(within(toolbar).getByRole("searchbox")).toBeVisible();
    expect(within(toolbar).getByLabelText("Tình trạng")).toBeVisible();
    expect(
      within(toolbar).getByLabelText("Chỉ hiển thị thay đổi chưa lưu"),
    ).toBeVisible();
  });
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
    ).toHaveValue("30");
    expect(within(row).getByText("Đã lưu")).toBeVisible();
    expect(screen.getByText("1 đã điều chỉnh")).toBeVisible();
    expect(
      screen.queryByText("Số lượng không đổi nên không cần lý do điều chỉnh."),
    ).not.toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "Tiếp tục phân bổ NCC" }),
    ).toBeDisabled();
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
      screen.getByRole("button", { name: "Tiếp tục phân bổ NCC" }),
    ).toBeDisabled();
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

  it("requires a working date before leaving a historical multi-date batch", async () => {
    const api = renderAuthoritativeFixture(configureSavedAdjustmentFixture);
    const release = vi.spyOn(api, "releaseSaved");
    await screen.findByText("Gạo thơm");
    const next = screen.getByRole("button", { name: "Tiếp tục phân bổ NCC" });
    expect(next).toBeDisabled();
    expect(next).toHaveAttribute(
      "title",
      "Chọn ngày phục vụ trước khi phân bổ NCC.",
    );
    expect(release).not.toHaveBeenCalled();
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

  it("composes external school scope with search and confirmation filters", async () => {
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
    expect(within(toolbar).queryByLabelText("Ngày")).not.toBeInTheDocument();
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
      within(rail).queryByRole("button", { name: "Tiếp tục phân bổ NCC" }),
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

  it("does not require release permission for navigation to allocation", async () => {
    const api = createReviewConfirmedNeedApi("ready");
    const fixture = createReviewConfirmedNeedFixture();
    configureSavedAdjustmentFixture(fixture);
    fixture.allowed_actions.release_confirmed_needs = false;
    vi.spyOn(api, "getReview").mockResolvedValue({
      kind: "success",
      response: { success: true, workbench: fixture },
    } as never);
    const navigate = vi.fn();
    render(
      <PlanningRailActionProvider>
        <PlanningRailActionHost />
        <ConfirmedNeedReviewWorkbench
          authState={authState}
          api={api}
          initialBatchId={batchId}
          workingServiceDate="2026-08-03"
          onContinueAllocation={navigate}
        />
      </PlanningRailActionProvider>,
    );
    const button = await screen.findByRole("button", {
      name: "Tiếp tục phân bổ NCC",
    });
    expect(button).toBeEnabled();
    fireEvent.click(button);
    expect(navigate).toHaveBeenCalledWith("2026-08-03");
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

  it("keeps saved Need editable and exposes no release confirmation dialog", async () => {
    const api = await saveAll();
    const release = vi.spyOn(api, "releaseSaved");
    const handoff = vi.spyOn(api, "releasePurchaseHandoff");
    expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
    expect(screen.getByLabelText("Số lượng xác nhận Cà rốt")).toBeEnabled();
    expect(release).not.toHaveBeenCalled();
    expect(handoff).not.toHaveBeenCalled();
  });

  it("allows returning to allocation after a historical release without retrying Handoff", async () => {
    const fixture = createReviewConfirmedNeedFixture();
    configureSavedAdjustmentFixture(fixture);
    fixture.authoritative_batch_status = "RELEASED_FOR_PURCHASE_HANDOFF";
    const api = createReviewConfirmedNeedApi("ready");
    vi.spyOn(api, "getReview").mockResolvedValue({
      kind: "success",
      response: { success: true, workbench: fixture },
    } as never);
    const handoff = vi.spyOn(api, "releasePurchaseHandoff");
    const navigate = vi.fn();
    render(
      <PlanningRailActionProvider>
        <PlanningRailActionHost />
        <ConfirmedNeedReviewWorkbench
          authState={authState}
          api={api}
          initialBatchId={batchId}
          workingServiceDate="2026-08-03"
          onContinueAllocation={navigate}
        />
      </PlanningRailActionProvider>,
    );
    fireEvent.click(
      await screen.findByRole("button", { name: "Tiếp tục phân bổ NCC" }),
    );
    expect(navigate).toHaveBeenCalledWith("2026-08-03");
    expect(handoff).not.toHaveBeenCalled();
    expect(screen.getByLabelText("Số lượng xác nhận Gạo thơm")).toBeDisabled();
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
