import "@testing-library/jest-dom/vitest";
import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
  within,
} from "@testing-library/react";
import { userEvent } from "storybook/test";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { AtlasVNextProvider } from "../AtlasVNextProvider";
import { ConfirmedNeedWorkbench } from "./ConfirmedNeedWorkbench";
import type { ConfirmedNeedWorkbenchProps } from "./useConfirmedNeedWorkbench";
import {
  createConfirmedNeedReviewFixture,
  reviewDate,
  type ConfirmedReviewScenario,
} from "./confirmedNeedReviewFixtures";
beforeEach(() =>
  vi.stubGlobal(
    "ResizeObserver",
    class {
      observe() {}
      unobserve() {}
      disconnect() {}
    },
  ),
);
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});
function show(
  scenario: ConfirmedReviewScenario = "normal",
  workbookProps: Pick<
    ConfirmedNeedWorkbenchProps,
    "onExportShoppingList" | "onImportShoppingList"
  > = {},
  prepare?: (
    fixture: ReturnType<typeof createConfirmedNeedReviewFixture>,
  ) => void,
) {
  const f = createConfirmedNeedReviewFixture(scenario);
  prepare?.(f);
  const navigate = vi.fn();
  const detail = vi.spyOn(f.needGenerationApi, "getWorkbench");
  const save = vi.spyOn(f.confirmedNeedApi, "save");
  render(
    <AtlasVNextProvider>
      <ConfirmedNeedWorkbench
        {...f}
        authSubject="operator"
        initialServiceDate={reviewDate}
        onContinueAllocation={navigate}
        {...workbookProps}
      />
    </AtlasVNextProvider>,
  );
  return { f, navigate, detail, save };
}
async function quantity() {
  return screen.findByRole("textbox", { name: "Số lượng xác nhận Gạo thơm" });
}
async function editValid() {
  fireEvent.change(await quantity(), { target: { value: "12,5" } });
  fireEvent.change(screen.getByRole("combobox", { name: "Lý do Gạo thơm" }), {
    target: { value: "OTHER" },
  });
  fireEvent.change(screen.getByRole("textbox", { name: "Ghi chú Gạo thơm" }), {
    target: { value: "Bếp yêu cầu" },
  });
}
describe("Confirmed Need Chakra operator surface", () => {
  it("composes Confirmed Need as a Station with a named local table viewport", async () => {
    show();
    await quantity();

    const context = screen.getByRole("region", {
      name: "Ngữ cảnh xác nhận nhu cầu",
    });
    expect(context.parentElement).toHaveStyle({
      gridTemplateRows: "auto minmax(0, 1fr)",
    });
    expect(context).toHaveTextContent("Lập nhu cầu");
    expect(context).toHaveTextContent("Xác nhận nhu cầu");
    expect(context).toHaveTextContent("07/09/2026 · Tất cả trường");

    const viewport = screen.getByRole("region", {
      name: "Bảng xác nhận nhu cầu",
    });
    expect(viewport).toHaveAttribute("tabindex", "0");
    expect(
      within(viewport).getByRole("table", { name: "Nhu cầu xác nhận" }),
    ).toHaveStyle({
      minWidth: "var(--atlas-layout-confirmed-need-table-min, 1040px)",
      width: "100%",
      tableLayout: "fixed",
    });
    expect(within(viewport).getAllByRole("columnheader")).toHaveLength(5);
    expect(
      within(viewport).getByRole("columnheader", {
        name: "Nguyên liệu / nơi nhận",
      }),
    ).toHaveStyle({
      position: "sticky",
      left: "var(--atlas-layout-zero, 0)",
      background: "var(--atlas-colors-bg-toolbar)",
      zIndex: "var(--atlas-layout-sticky-identity-header-z, 5)",
    });
    expect(
      within(viewport).getByText("Gạo thơm").closest('[data-field="identity"]'),
    ).toHaveStyle({
      position: "sticky",
      left: "var(--atlas-layout-zero, 0)",
      background: "var(--atlas-colors-bg-workbench)",
      zIndex: "var(--atlas-layout-sticky-identity-z, 2)",
    });
    expect(
      within(
        within(viewport)
          .getByText("Gạo thơm")
          .closest('[data-field="identity"]')!,
      ).queryByText("Đã lưu"),
    ).not.toBeInTheDocument();
  });

  it("keeps search and refresh immediate while compact filters disclose a truthful scope summary", async () => {
    show();
    await quantity();

    expect(screen.getByRole("textbox", { name: "Tìm kiếm" })).toBeEnabled();
    expect(
      screen.getByRole("button", { name: "Làm mới dữ liệu" }),
    ).toBeEnabled();
    const disclosure = screen.getByRole("button", { name: "Bộ lọc" });
    expect(disclosure).toHaveAttribute("aria-expanded", "false");
    expect(disclosure).toHaveAttribute(
      "aria-controls",
      "confirmed-need-filters",
    );
    expect(
      screen.getByText(
        "Tuần 07/09/2026 · Ngày 07/09/2026 · Tất cả trường · Tình trạng: Tất cả",
      ),
    ).toBeInTheDocument();

    fireEvent.click(disclosure);
    expect(disclosure).toHaveAttribute("aria-expanded", "true");
    fireEvent.change(screen.getByRole("combobox", { name: "Tình trạng" }), {
      target: { value: "needs_review" },
    });
    fireEvent.click(disclosure);
    expect(screen.getByText(/Tình trạng: Cần rà soát/)).toBeInTheDocument();
  });

  it.each([390, 768])(
    "tabs from the expanded compact filter trigger into revealed controls at %ipx",
    async (width) => {
      Object.defineProperty(window, "innerWidth", {
        configurable: true,
        value: width,
      });
      show();
      await quantity();

      const disclosure = screen.getByRole("button", { name: "Bộ lọc" });
      screen.getByRole("textbox", { name: "Tìm kiếm" }).focus();
      await userEvent.tab();
      expect(disclosure).toHaveFocus();
      await userEvent.keyboard("{Enter}");
      expect(disclosure).toHaveAttribute("aria-expanded", "true");

      const filters = document.getElementById("confirmed-need-filters");
      expect(filters).toContainElement(document.activeElement as HTMLElement);
      while (filters?.contains(document.activeElement)) await userEvent.tab();
      expect(
        screen.getByRole("button", { name: "Làm mới dữ liệu" }),
      ).toHaveFocus();
    },
  );

  it.each([
    [390, "busy"],
    [768, "busy"],
    [390, "locked"],
    [768, "locked"],
  ] as const)(
    "keeps the %ipx onward path reversible when Confirmed Need is %s",
    async (width, state) => {
      Object.defineProperty(window, "innerWidth", {
        configurable: true,
        value: width,
      });
      if (state === "busy") {
        show("normal", {}, (fixture) => {
          const initialRead = fixture.confirmedNeedApi.getReview;
          let reads = 0;
          fixture.confirmedNeedApi.getReview = (...args) => {
            reads += 1;
            return reads === 1
              ? initialRead(...args)
              : new Promise(() => undefined);
          };
        });
        await quantity();
        fireEvent.click(
          screen.getByRole("button", { name: "Làm mới dữ liệu" }),
        );
      } else {
        show("stale");
        await editValid();
        fireEvent.click(screen.getByRole("button", { name: "Lưu" }));
        await screen.findByRole("button", {
          name: "Tải lại dữ liệu hiện tại",
        });
      }
      await waitFor(() =>
        expect(
          screen.getByRole("button", { name: "Làm mới dữ liệu" }),
        ).toBeDisabled(),
      );

      const disclosure = screen.getByRole("button", { name: "Bộ lọc" });
      fireEvent.click(disclosure);
      const status = screen.getByRole("combobox", { name: "Tình trạng" });
      status.focus();
      await userEvent.tab();
      expect(status).not.toHaveFocus();
      expect(
        document.getElementById("confirmed-need-filters"),
      ).not.toContainElement(document.activeElement as HTMLElement);
      await userEvent.tab({ shift: true });
      expect(disclosure).toHaveFocus();
    },
  );

  it.each([390, 768])(
    "exits loading compact filters when Refresh is disabled at %ipx and reverses to the trigger",
    async (width) => {
      Object.defineProperty(window, "innerWidth", {
        configurable: true,
        value: width,
      });
      show("loading");

      const disclosure = screen.getByRole("button", { name: "Bộ lọc" });
      fireEvent.click(disclosure);
      const status = screen.getByRole("combobox", { name: "Tình trạng" });
      status.focus();
      expect(
        screen.getByRole("button", { name: "Làm mới dữ liệu" }),
      ).toBeDisabled();
      await userEvent.tab();

      expect(status).not.toHaveFocus();
      expect(
        document.getElementById("confirmed-need-filters"),
      ).not.toContainElement(document.activeElement as HTMLElement);
      const onward = document.activeElement as HTMLElement;
      expect(
        disclosure.compareDocumentPosition(onward) &
          Node.DOCUMENT_POSITION_FOLLOWING,
      ).toBeTruthy();
      await userEvent.tab({ shift: true });
      expect(disclosure).toHaveFocus();
    },
  );

  it("reports an unknown Station scope when the authoritative read fails", async () => {
    show("read_failure");

    const context = await screen.findByRole("region", {
      name: "Ngữ cảnh xác nhận nhu cầu",
    });
    await screen.findByRole("alert");
    expect(context).toHaveTextContent("Không xác định");
    expect(context).not.toHaveTextContent("0 trường");
  });

  it("keeps utilities secondary and exposes the persistent decision footer", async () => {
    show("normal", {
      onExportShoppingList: vi.fn().mockResolvedValue(undefined),
      onImportShoppingList: vi.fn().mockResolvedValue({
        drafts: {},
        changedLineIds: [],
      }),
    });
    await quantity();

    const utilities = screen.getByRole("group", {
      name: "Tiện ích nhu cầu xác nhận",
    });
    expect(
      within(utilities).getByRole("button", { name: "Xuất Phiếu đi chợ" }),
    ).toHaveAttribute("data-atlas-action-priority", "tertiary");
    expect(
      within(utilities).getByRole("button", {
        name: "Xem cách hình thành nhu cầu",
      }),
    ).toHaveAttribute("data-atlas-action-priority", "tertiary");

    const footer = screen.getByRole("group", {
      name: "Thao tác xác nhận nhu cầu",
    });
    expect(footer).toHaveAttribute("data-atlas-persistent-actions", "true");
    expect(
      within(footer).getByRole("button", { name: "Tiếp tục phân bổ NCC" }),
    ).toHaveAttribute("data-atlas-action-priority", "primary");
  });

  it("styles a valid adjustment as a decision and only invalid input as danger", async () => {
    show();
    const input = await quantity();

    expect(input.closest('[data-field="confirmation"]')).toHaveAttribute(
      "data-adjustment-state",
      "unchanged",
    );

    await editValid();
    expect(
      screen.getByRole("region", { name: "Bảng xác nhận nhu cầu" }),
    ).toHaveStyle({
      "--atlas-confirmed-need-table-mobile-max-height": "28dvh",
    });
    expect(input.closest('[data-field="confirmation"]')).toHaveAttribute(
      "data-adjustment-state",
      "valid",
    );
    expect(input.closest('[data-field="confirmation"]')).toHaveStyle({
      background: "var(--atlas-colors-bg-selected)",
    });
    expect(screen.getByRole("button", { name: "Lưu" })).toHaveAttribute(
      "data-atlas-action-priority",
      "primary",
    );
    expect(
      screen.getByRole("button", { name: "Tiếp tục phân bổ NCC" }),
    ).toHaveAttribute("data-atlas-action-priority", "secondary");

    fireEvent.change(input, { target: { value: "10,123" } });
    expect(input.closest('[data-field="confirmation"]')).toHaveAttribute(
      "data-adjustment-state",
      "invalid",
    );
    expect(input.closest('[data-field="confirmation"]')).toHaveStyle({
      background: "var(--atlas-colors-bg-danger)",
    });
  });

  it("provides certified review evidence without rendering historical identities as current rows", () => {
    const fixture = createConfirmedNeedReviewFixture(
      "certified_shape" as ConfirmedReviewScenario,
    ) as ReturnType<typeof createConfirmedNeedReviewFixture> & {
      reviewEvidence: {
        currentDecisionCount: number;
        proposalAcceptanceCount: number;
        adjustedLineId: string;
        retainedHistoricalIdentities: Array<{
          confirmedNeedLineId: string;
          decisionId: string;
          exactQuantity: string;
        }>;
      };
    };

    expect(fixture.batch.lines).toHaveLength(248);
    expect(fixture.reviewEvidence.currentDecisionCount).toBe(248);
    expect(
      fixture.batch.lines.filter((line) => line.current_decision_id !== null),
    ).toHaveLength(248);
    expect(fixture.reviewEvidence.proposalAcceptanceCount).toBe(247);
    expect(
      fixture.batch.lines.filter(
        (line) => line.current_decision_kind === "PROPOSAL_ACCEPTED",
      ),
    ).toHaveLength(247);
    expect(
      fixture.batch.lines.filter(
        (line) => line.current_decision_kind === "OPERATIONAL_ADJUSTMENT",
      ),
    ).toHaveLength(1);
    expect(fixture.reviewEvidence.adjustedLineId).toBe(
      fixture.batch.lines[247]!.confirmed_need_line_id,
    );
    expect(fixture.reviewEvidence.retainedHistoricalIdentities).toHaveLength(
      249,
    );
    expect(
      fixture.batch.lines.some(
        (line) =>
          line.confirmed_need_line_id ===
          fixture.reviewEvidence.retainedHistoricalIdentities[248]!
            .confirmedNeedLineId,
      ),
    ).toBe(false);
    expect(
      fixture.reviewEvidence.retainedHistoricalIdentities[248]!.exactQuantity,
    ).toBe("10.123456");
    expect(
      fixture.batch.lines.some((line) => line.controlled_unit.code === "Quả"),
    ).toBe(true);
    expect(fixture.batch.lines[0]!.ingredient.name.length).toBeGreaterThan(60);
    expect(
      fixture.reviewEvidence.retainedHistoricalIdentities.some(
        ({ confirmedNeedLineId, decisionId }) =>
          /^[0-9a-f]{8}-[0-9a-f-]{27}$/i.test(confirmedNeedLineId) ||
          /^[0-9a-f]{8}-[0-9a-f-]{27}$/i.test(decisionId),
      ),
    ).toBe(false);
  });

  it("exposes authoritative stable line identity across controlled rerenders", async () => {
    show();
    const input = await quantity();
    expect(input.closest("tr")).toHaveAttribute(
      "data-confirmed-need-line-id",
      "line-0",
    );
    fireEvent.change(input, { target: { value: "12,5" } });
    expect((await quantity()).closest("tr")).toHaveAttribute(
      "data-confirmed-need-line-id",
      "line-0",
    );
    expect(await quantity()).toBeEnabled();
  });
  it("imports Phiếu đi chợ changes into local drafts and leaves Save as the sole write", async () => {
    const onExportShoppingList = vi.fn().mockResolvedValue(undefined);
    const onImportShoppingList = vi
      .fn()
      .mockImplementation(
        async (
          _file,
          _workbench,
          drafts: Parameters<
            NonNullable<ConfirmedNeedWorkbenchProps["onImportShoppingList"]>
          >[2],
        ) => ({
          drafts: {
            ...drafts,
            "line-0": {
              ...drafts["line-0"]!,
              exact_quantity: "12,5",
              quantity_entered: true,
              reason_code: "OPERATIONAL_QUANTITY_ADJUSTMENT" as const,
              reason_note: "Điều chỉnh từ Phiếu đi chợ",
            },
          },
          changedLineIds: ["line-0"],
        }),
      );
    const h = show("normal", {
      onExportShoppingList,
      onImportShoppingList,
    });
    await quantity();

    fireEvent.click(screen.getByRole("button", { name: "Xuất Phiếu đi chợ" }));
    await waitFor(() => expect(onExportShoppingList).toHaveBeenCalledTimes(1));
    fireEvent.change(screen.getByLabelText("Nhập Phiếu đi chợ .xlsx"), {
      target: {
        files: [
          new File([new Uint8Array([1, 2, 3])], "shopping-list.xlsx", {
            type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
          }),
        ],
      },
    });

    expect(
      await screen.findByText("Đã nhập 1 thay đổi vào bản nháp."),
    ).toBeVisible();
    expect(await quantity()).toHaveValue("12,5");
    expect(h.save).not.toHaveBeenCalled();
    expect(screen.getByRole("button", { name: "Lưu" })).toBeEnabled();
  });
  it("displays an exact cent delta beyond binary floating-point precision", async () => {
    const h = show();
    await quantity();
    h.f.batch.lines[0]!.confirmed_quantity_after = "99999999999999.980000";
    h.f.batch.lines[0]!.proposed_confirmed_quantity = "99999999999999.980000";
    h.f.batch.lines[0]!.effective_policy!.planning_step = "0.010000";
    fireEvent.click(screen.getByRole("button", { name: "Làm mới dữ liệu" }));
    await waitFor(() =>
      expect(
        screen.getByRole("textbox", { name: "Số lượng xác nhận Gạo thơm" }),
      ).toHaveValue("99999999999999,98"),
    );
    fireEvent.change(await quantity(), {
      target: { value: "99999999999999,99" },
    });
    expect(screen.getByRole("cell", { name: "+0,01 kg" })).toBeVisible();
  });
  it("pages Need detail through bounded backend reads and applies school/ingredient filters explicitly", async () => {
    const h = show();
    await quantity();
    h.f.need.pagination.has_more = true;
    h.f.need.pagination.total_groups = 26;
    fireEvent.click(
      screen.getByRole("button", { name: "Xem cách hình thành nhu cầu" }),
    );
    await screen.findByRole("table", { name: "Cách hình thành nhu cầu" });
    fireEvent.click(screen.getByRole("button", { name: "Trang sau" }));
    await waitFor(() => expect(h.detail).toHaveBeenCalledTimes(2));
    expect(h.detail.mock.calls[1]!.slice(6, 8)).toEqual([25, 25]);
    await screen.findByRole("table", { name: "Cách hình thành nhu cầu" });
    fireEvent.change(
      screen.getByRole("combobox", { name: "Trường chi tiết" }),
      { target: { value: "school-0" } },
    );
    fireEvent.change(
      screen.getByRole("combobox", { name: "Nguyên liệu chi tiết" }),
      { target: { value: "ingredient-0" } },
    );
    expect(h.detail).toHaveBeenCalledTimes(2);
    fireEvent.click(screen.getByRole("button", { name: "Áp dụng chi tiết" }));
    await waitFor(() => expect(h.detail).toHaveBeenCalledTimes(3));
    expect(h.detail.mock.calls[2]![5]).toMatchObject({
      service_date: reviewDate,
      school_id: "school-0",
      ingredient_id: "ingredient-0",
    });
    expect(h.detail.mock.calls[2]![6]).toBe(0);
  });
  it.each([
    ["no_demand", "Không có nhu cầu cần lập cho ngày này."],
    ["blocked", "Cần lưu sĩ số trước khi tạo nhu cầu."],
  ] as const)(
    "shows compact %s state without an empty table",
    async (scenario, message) => {
      show(scenario);
      expect(await screen.findByText(message)).toBeVisible();
      expect(screen.queryByRole("table")).not.toBeInTheDocument();
    },
  );
  it.each([
    ["not_generated", "Tạo nhu cầu"],
    ["outdated", "Cập nhật nhu cầu"],
  ] as const)(
    "opens generated Confirmed Need directly from %s",
    async (scenario, label) => {
      show(scenario);
      fireEvent.click(await screen.findByRole("button", { name: label }));
      expect(
        await screen.findByRole("table", { name: "Nhu cầu xác nhận" }),
      ).toBeVisible();
      expect(screen.queryByText("Mở xác nhận")).not.toBeInTheDocument();
    },
  );
  it("has one h1, quiet summary, semantic table and no technical identifiers", async () => {
    show();
    await quantity();
    expect(screen.getAllByRole("heading", { level: 1 })).toHaveLength(1);
    expect(screen.getByRole("heading", { level: 1 })).toHaveTextContent(
      "Xác nhận nhu cầu",
    );
    expect(screen.getAllByRole("columnheader")).toHaveLength(5);
    expect(document.body.textContent).not.toMatch(
      /batch-current|line-0|revision-0|decision-0|DRAFT_REVIEW/,
    );
    expect(screen.getByText(/6 dòng/)).toBeVisible();
  });
  it("keeps the primary table on proposal and human confirmation while moving raw and step evidence to progressive detail", async () => {
    show("needs_review", {}, (fixture) => {
      Object.assign(fixture.batch.lines[0]!, {
        theoretical_quantity: "0.025500",
        proposed_confirmed_quantity: "0.100000",
        proposal_rounding_step: "0.100000",
      });
      fixture.batch.lines[0]!.effective_policy!.planning_step = "0.010000";
    });
    const input = await quantity();
    const row = input.closest("tr")!;
    expect(
      screen.queryByRole("columnheader", { name: "Nhu cầu tính" }),
    ).not.toBeInTheDocument();
    expect(
      screen.getByRole("columnheader", { name: "Đề xuất vận hành" }),
    ).toBeVisible();
    expect(
      screen.getByRole("columnheader", { name: "Số lượng xác nhận" }),
    ).toBeVisible();
    expect(row.querySelector('[data-field="raw-requirement"]')).toBeNull();
    expect(
      row.querySelector('[data-field="operational-proposal"]'),
    ).toHaveTextContent("0,1");
    expect(row).not.toHaveTextContent("Làm tròn:");
    expect(row).not.toHaveTextContent("Bước xác nhận:");
    expect(input).toHaveValue("0,1");
    fireEvent.click(
      screen.getByRole("button", { name: "Xem cách hình thành nhu cầu" }),
    );
    const evidence = await screen.findByRole("table", {
      name: "Cách hình thành nhu cầu",
    });
    expect(
      screen.getByRole("heading", {
        level: 2,
        name: "Cách hình thành nhu cầu",
      }),
    ).toBeVisible();
    expect(
      screen.getByRole("region", {
        name: "Bằng chứng hình thành nhu cầu",
      }),
    ).toHaveAttribute("tabindex", "0");
    const evidenceRow = within(evidence).getByText("Gạo thơm").closest("tr")!;
    expect(evidenceRow).toHaveTextContent("0,0255 kg");
    expect(evidenceRow).toHaveTextContent("0,1 kg");
    expect(evidenceRow).toHaveTextContent("0,01 kg");
  });
  it("fails closed when Need detail cannot distinguish two customers with the exposed detail identity", async () => {
    show("normal", {}, (fixture) => {
      const group = fixture.need.grouped_requirements[0]!;
      fixture.need.grouped_requirements.push({
        ...group,
        customer_id: "customer-other",
      });
      fixture.need.pagination.total_groups = 2;
    });
    await quantity();
    fireEvent.click(
      screen.getByRole("button", { name: "Xem cách hình thành nhu cầu" }),
    );
    const evidence = await screen.findByRole("table", {
      name: "Cách hình thành nhu cầu",
    });
    for (const ingredient of within(evidence).getAllByRole("button", {
      name: "Xem chi tiết Gạo thơm",
    }))
      expect(ingredient).toBeDisabled();
    expect(
      within(evidence).getAllByText(
        "Không đối chiếu được đầy đủ bằng chứng của dòng nhu cầu hiện tại.",
      ),
    ).toHaveLength(2);
  });
  it("does not classify a fresh six-place proposal as historical", async () => {
    show("needs_review", {}, (fixture) => {
      fixture.batch.lines[0]!.proposed_confirmed_quantity = "10.123456";
      fixture.batch.lines[0]!.effective_policy!.planning_step = "0.000001";
    });
    expect(await quantity()).toHaveValue("10,123456");
    expect(await quantity()).not.toHaveAttribute("readonly");
    expect(await quantity()).toBeEnabled();
  });
  it("keeps a fresh exact proposal acceptance quiet while preserving its required first Save", async () => {
    show("needs_review");
    const input = await quantity();
    const row = input.closest("tr")!;
    expect(row).toHaveTextContent("Theo đề xuất");
    expect(
      within(row).queryByRole("combobox", { name: "Lý do Gạo thơm" }),
    ).not.toBeInTheDocument();
    expect(
      within(row).queryByRole("textbox", { name: "Ghi chú Gạo thơm" }),
    ).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Lưu" })).toBeEnabled();
  });
  it("links invalid quantity to its error and disables Save/Continue", async () => {
    show();
    const input = await quantity();
    fireEvent.change(input, { target: { value: "10,123" } });
    expect(input).toHaveAttribute("aria-invalid", "true");
    expect(
      document.getElementById(input.getAttribute("aria-describedby")!),
    ).toHaveTextContent("Số lượng xác nhận phải theo bước 0,25 kg.");
    expect(screen.getByRole("button", { name: "Lưu" })).toBeDisabled();
    expect(
      screen.getByRole("button", { name: "Tiếp tục phân bổ NCC" }),
    ).toBeDisabled();
  });
  it("renders historical six-place authority read-only without rounding", async () => {
    show("historical");
    expect(await quantity()).toHaveValue("10,123456");
    expect(await quantity()).toHaveAttribute("readonly");
  });
  it("saves valid changes and adopts the returned value", async () => {
    const h = show();
    await editValid();
    fireEvent.click(screen.getByRole("button", { name: "Lưu" }));
    expect(await screen.findByText("Đã lưu thay đổi.")).toBeVisible();
    expect(await quantity()).toHaveValue("12,5");
    expect(screen.getByText(/1 đã điều chỉnh/)).toBeVisible();
    const row = (await quantity()).closest("tr")!;
    expect(
      within(row).getByRole("combobox", { name: "Lý do Gạo thơm" }),
    ).toHaveValue("OTHER");
    expect(
      within(row).getByRole("textbox", { name: "Ghi chú Gạo thơm" }),
    ).toHaveValue("Bếp yêu cầu");
    expect(row.querySelector('[data-field="delta"]')).toHaveTextContent(
      "+2,25 kg",
    );
    expect(h.f.batch.lines[0]!.confirmed_quantity_after).toBe("10.250000");
    expect(h.save).toHaveBeenCalledTimes(1);
    expect(await h.save.mock.results[0]!.value).toMatchObject({
      kind: "success",
      response: {
        authoritative_readback: {
          line_counts: { adjusted: 1 },
          lines: expect.arrayContaining([
            expect.objectContaining({
              confirmed_quantity_after: "12.500000",
              current_decision_kind: "OPERATIONAL_ADJUSTMENT",
              decision_history: expect.arrayContaining([
                expect.objectContaining({
                  decision_kind: "OPERATIONAL_ADJUSTMENT",
                  confirmed_quantity_after: "12.500000",
                  reason_code: "OTHER",
                  reason_note: "Bếp yêu cầu",
                }),
              ]),
            }),
          ]),
        },
      },
    });
  });
  it("protects refresh through one dialog, preserving draft on cancel", async () => {
    show();
    fireEvent.change(await quantity(), { target: { value: "12,5" } });
    fireEvent.click(screen.getByRole("button", { name: "Làm mới dữ liệu" }));
    expect(await screen.findByRole("dialog")).toHaveTextContent(
      "Có thay đổi chưa lưu. Bỏ thay đổi và tiếp tục?",
    );
    fireEvent.click(screen.getByRole("button", { name: "Tiếp tục chỉnh sửa" }));
    expect(await quantity()).toHaveValue("12,5");
    fireEvent.click(screen.getByRole("button", { name: "Làm mới dữ liệu" }));
    fireEvent.click(await screen.findByRole("button", { name: "Bỏ thay đổi" }));
    await waitFor(() =>
      expect(screen.queryByRole("dialog")).not.toBeInTheDocument(),
    );
    expect(await quantity()).toHaveValue("10,25");
  });
  it("uses the same dirty dialog for committed School Apply", async () => {
    show();
    fireEvent.change(await quantity(), { target: { value: "12,5" } });
    fireEvent.click(screen.getByRole("button", { name: "Bộ lọc" }));
    fireEvent.click(screen.getByRole("button", { name: "Tất cả trường" }));
    fireEvent.click(
      await screen.findByRole("checkbox", { name: "Trường Nguyễn Du" }),
    );
    fireEvent.click(screen.getByRole("button", { name: "Áp dụng" }));
    expect(
      await screen.findByRole("dialog", {
        name: "Có thay đổi chưa lưu. Bỏ thay đổi và tiếp tục?",
      }),
    ).toBeVisible();
    fireEvent.click(screen.getByRole("button", { name: "Tiếp tục chỉnh sửa" }));
    expect(await quantity()).toHaveValue("12,5");
  });
  it("shows hidden changes while search stays local", async () => {
    show();
    fireEvent.change(await quantity(), { target: { value: "12,5" } });
    fireEvent.change(screen.getByRole("textbox", { name: "Tìm kiếm" }), {
      target: { value: "thit" },
    });
    expect(
      screen.getByText("Có 1 thay đổi chưa lưu ngoài bộ lọc hiện tại."),
    ).toBeVisible();
    expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
  });
  it.each(["stale", "unknown", "recovery_failed"] as const)(
    "exposes accessible %s recovery and locks writes",
    async (scenario) => {
      show(scenario);
      await editValid();
      fireEvent.click(screen.getByRole("button", { name: "Lưu" }));
      const recovery = await screen.findByRole("button", {
        name:
          scenario === "stale"
            ? "Tải lại dữ liệu hiện tại"
            : "Tải lại để xác nhận",
      });
      expect(
        screen.getByRole("button", { name: "Tiếp tục phân bổ NCC" }),
      ).toBeDisabled();
      fireEvent.click(recovery);
      if (scenario === "recovery_failed") {
        expect(
          await screen.findByText(
            "Không thể thực hiện yêu cầu. Hãy tải lại dữ liệu.",
          ),
        ).toBeVisible();
        expect(
          screen.getByRole("button", { name: "Tải lại để xác nhận" }),
        ).toBeVisible();
      } else
        await waitFor(() =>
          expect(
            screen.getByRole("button", { name: "Tiếp tục phân bổ NCC" }),
          ).toBeEnabled(),
        );
    },
  );
  it("released authority is read-only but navigates directly without a dialog", async () => {
    const h = show("released");
    expect(await quantity()).toBeDisabled();
    expect(
      screen.queryByRole("button", { name: "Lưu" }),
    ).not.toBeInTheDocument();
    fireEvent.click(
      screen.getByRole("button", { name: "Tiếp tục phân bổ NCC" }),
    );
    expect(h.navigate).toHaveBeenCalledWith(reviewDate);
    expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
  });
  it("loads grouped Need only on disclosure with exact date and backend page bounds", async () => {
    const h = show();
    await quantity();
    expect(h.detail).not.toHaveBeenCalled();
    fireEvent.click(
      screen.getByRole("button", { name: "Xem cách hình thành nhu cầu" }),
    );
    expect(
      await screen.findByRole("table", { name: "Cách hình thành nhu cầu" }),
    ).toBeVisible();
    expect(h.detail).toHaveBeenCalledWith(
      "operator",
      expect.any(String),
      reviewDate,
      reviewDate,
      "run-current",
      {
        service_date: reviewDate,
        school_id: null,
        ingredient_id: null,
        contribution_family: null,
      },
      0,
      25,
      null,
    );
    fireEvent.change(screen.getByRole("combobox", { name: "Nguồn đóng góp" }), {
      target: { value: "PANTRY_DIRECT" },
    });
    expect(h.detail).toHaveBeenCalledTimes(1);
    fireEvent.click(screen.getByRole("button", { name: "Áp dụng chi tiết" }));
    await waitFor(() => expect(h.detail).toHaveBeenCalledTimes(2));
    expect(h.detail.mock.calls[1]![5].contribution_family).toBe(
      "PANTRY_DIRECT",
    );
    fireEvent.click(
      within(
        screen.getByRole("table", { name: "Cách hình thành nhu cầu" }),
      ).getByRole("button", { name: "Xem chi tiết Gạo thơm" }),
    );
    expect(await screen.findByText(/Cơm trắng/)).toBeVisible();
    expect(screen.getByText(/Bổ sung suất ăn/)).toBeVisible();
    expect(document.body.textContent).not.toContain("atomic-private");
  });
});

it("keeps the initiating action loading and disabled while a long generation is pending", async () => {
  let finish!: () => void;
  let calls = 0;
  show("not_generated", {}, (f) => {
    const execute = f.needGenerationApi.execute.bind(f.needGenerationApi);
    f.needGenerationApi.execute = async (request) => {
      calls++;
      await new Promise<void>((resolve) => {
        finish = resolve;
      });
      return execute(request);
    };
  });
  const button = await screen.findByRole("button", { name: "Tạo nhu cầu" });
  vi.useFakeTimers();
  try {
    fireEvent.click(button);
    expect(button).toBeDisabled();
    fireEvent.click(button);
    expect(calls).toBe(1);
    expect(screen.queryByText(/Đang xử lý…/)).not.toBeInTheDocument();
    act(() => vi.advanceTimersByTime(2000));
    expect(screen.getByText(/Đang xử lý…/)).toBeVisible();
    expect(screen.getByText("Đã xử lý 2 giây")).toBeVisible();
    await act(async () => {
      finish();
    });
    expect(screen.getByText("✓ Hoàn tất")).toBeVisible();
    expect(screen.getByText(/6 dòng nhu cầu đã sẵn sàng/)).toBeVisible();
    expect(calls).toBe(1);
  } finally {
    vi.useRealTimers();
  }
});

it("retains Update Need continuity counts in the authoritative completion feedback", async () => {
  show("outdated");
  fireEvent.click(
    await screen.findByRole("button", { name: "Cập nhật nhu cầu" }),
  );
  await screen.findByText("✓ Hoàn tất");
  expect(screen.getByText(/5 xác nhận được giữ nguyên/)).toBeVisible();
});
