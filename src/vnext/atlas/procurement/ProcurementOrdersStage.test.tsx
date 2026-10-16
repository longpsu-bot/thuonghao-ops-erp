import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  within,
} from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { AtlasVNextProvider } from "../AtlasVNextProvider";
import { ProcurementOrdersStage } from "./ProcurementOrdersStage";
import { createProcurementReviewFixture } from "./procurementReviewFixtures";
afterEach(cleanup);
function show(
  scenario: Parameters<typeof createProcurementReviewFixture>[0] = "po_draft",
  disabled = false,
) {
  const fixture = createProcurementReviewFixture(scenario);
  const onAction = vi.fn();
  const onExportXlsx = vi.fn();
  const onExportPdf = vi.fn();
  render(
    <AtlasVNextProvider>
      <ProcurementOrdersStage
        data={fixture.orders}
        disabled={disabled}
        search=""
        onAction={onAction}
        onExportXlsx={onExportXlsx}
        onExportPdf={onExportPdf}
      />
    </AtlasVNextProvider>,
  );
  const trigger = screen.getByRole("button", { name: /^Xem đơn NCC An Phú/ });
  fireEvent.click(trigger);
  return {
    fixture,
    onAction,
    onExportXlsx,
    onExportPdf,
    trigger,
    detail: screen.getByRole("region", { name: "Chi tiết đơn mua NCC An Phú" }),
  };
}
describe("Supplier purchase orders", () => {
  it("starts with a supplier rail and visible first document without a second click", () => {
    const fixture = createProcurementReviewFixture("po_draft");
    render(
      <AtlasVNextProvider>
        <ProcurementOrdersStage
          data={fixture.orders}
          disabled={false}
          search=""
          onAction={vi.fn()}
        />
      </AtlasVNextProvider>,
    );
    const rail = screen.getByRole("navigation", {
      name: "Đơn mua theo nhà cung cấp",
    });
    expect(
      within(rail).getByRole("button", { name: /^Xem đơn NCC An Phú/ }),
    ).toHaveAttribute("aria-pressed", "true");
    expect(rail).toHaveTextContent("10/09/2026");
    const detail = screen.getByRole("region", {
      name: "Chi tiết đơn mua NCC An Phú",
    });
    expect(
      within(detail).getByRole("button", { name: "Phát hành cho NCC" }),
    ).toBeEnabled();
    expect(detail).toHaveTextContent(/Chưa có chi tiết trường nhận/);
    expect(detail).not.toHaveTextContent("0 trường");
  });
  it("does not retain hidden document actions after filtering and does not reopen after Close", () => {
    const fixture = createProcurementReviewFixture("po_draft"),
      action = vi.fn();
    const showStage = (search: string) => (
      <AtlasVNextProvider>
        <ProcurementOrdersStage
          data={fixture.orders}
          disabled={false}
          search={search}
          onAction={action}
        />
      </AtlasVNextProvider>
    );
    const { rerender } = render(showStage(""));
    fireEvent.click(
      screen.getByRole("button", { name: /^Xem đơn NCC An Phú/ }),
    );
    rerender(showStage("Không khớp"));
    expect(
      screen.queryByRole("button", { name: "Phát hành cho NCC" }),
    ).not.toBeInTheDocument();
    expect(screen.getByText(/Không có đơn mua khớp/)).toBeVisible();
    rerender(showStage(""));
    fireEvent.click(
      screen.getByRole("button", { name: /^Xem đơn NCC An Phú/ }),
    );
    const trigger = screen.getByRole("button", { name: /^Xem đơn NCC An Phú/ });
    fireEvent.click(screen.getByRole("button", { name: "Đóng" }));
    expect(trigger).toHaveFocus();
    rerender(showStage(""));
    expect(
      screen.queryByRole("region", { name: "Chi tiết đơn mua NCC An Phú" }),
    ).not.toBeInTheDocument();
    expect(action).not.toHaveBeenCalled();
  });
  it("distinguishes same-supplier document UUIDs and uses their fresh readback object", () => {
    const fixture = createProcurementReviewFixture("po_draft");
    const second = structuredClone(fixture.orders.purchase_orders[0]);
    second.purchase_order_id = "other-date-order";
    second.service_date = "2026-09-11";
    fixture.orders.purchase_orders.push(second);
    const action = vi.fn();
    const showStage = () => (
      <AtlasVNextProvider>
        <ProcurementOrdersStage
          data={fixture.orders}
          disabled={false}
          search=""
          onAction={action}
        />
      </AtlasVNextProvider>
    );
    const { rerender } = render(showStage());
    fireEvent.click(
      screen.getByRole("button", {
        name: "Xem đơn NCC An Phú · 11/09/2026 · Bản nháp",
      }),
    );
    let detail = screen.getByRole("region", {
      name: "Chi tiết đơn mua NCC An Phú",
    });
    expect(detail).toHaveTextContent("11/09/2026");
    const fresh = structuredClone(second);
    fresh.lines[0].ordered_quantity = "70.000002";
    fresh.version += 1;
    fixture.orders.purchase_orders[1] = fresh;
    rerender(showStage());
    detail = screen.getByRole("region", {
      name: "Chi tiết đơn mua NCC An Phú",
    });
    expect(detail).toHaveTextContent("70,000002");
    fireEvent.click(
      within(detail).getByRole("button", { name: "Phát hành cho NCC" }),
    );
    expect(action).toHaveBeenCalledWith(fresh);
  });
  it("shows only captured released School quantities without confusing delivery locations with Schools", () => {
    const { detail } = show("po_released");
    expect(detail).toHaveTextContent("Trường Nguyễn Du");
    expect(detail).toHaveTextContent("Bếp chính Nguyễn Du");
    expect(detail).toHaveTextContent("60,000001 kg");
  });
  it("shows each immutable supplier instruction in the PO line detail", () => {
    const fixture = createProcurementReviewFixture("po_draft");
    fixture.orders.purchase_orders[0]!.lines[0]!.supplier_note =
      "Rau non, không lấy bó già";
    render(
      <AtlasVNextProvider>
        <ProcurementOrdersStage
          data={fixture.orders}
          disabled={false}
          search=""
          onAction={vi.fn()}
        />
      </AtlasVNextProvider>,
    );
    fireEvent.click(
      screen.getByRole("button", { name: /^Xem đơn NCC An Phú/ }),
    );
    const detail = within(
      screen.getByRole("region", { name: "Chi tiết đơn mua NCC An Phú" }),
    );
    expect(
      detail.getByRole("heading", { name: "Nguyên liệu và nơi nhận" }),
    ).toBeInTheDocument();
    expect(detail.getByText("Ghi chú:")).toBeVisible();
    expect(detail.getByText("Ghi chú:").parentElement).toHaveTextContent(
      "Rau non, không lấy bó già",
    );
  });
  it("leaves a blank line note quiet in the narrow detail", () => {
    const { detail } = show("po_draft");
    expect(within(detail).queryByText("Ghi chú:")).not.toBeInTheDocument();
  });
  it("uses the shaped historical line note on a released PO", () => {
    const fixture = createProcurementReviewFixture("po_released");
    fixture.orders.purchase_orders[0]!.lines[0]!.supplier_note =
      "Loại 500g/gói";
    render(
      <AtlasVNextProvider>
        <ProcurementOrdersStage
          data={fixture.orders}
          disabled={false}
          search=""
          onAction={vi.fn()}
        />
      </AtlasVNextProvider>,
    );
    fireEvent.click(
      screen.getByRole("button", { name: /^Xem đơn NCC An Phú/ }),
    );
    const detail = within(
      screen.getByRole("region", { name: "Chi tiết đơn mua NCC An Phú" }),
    );
    expect(detail.getByText("Ghi chú:").parentElement).toHaveTextContent(
      "Loại 500g/gói",
    );
  });
  it.each([
    [
      "po_stale",
      "PO_DRAFT_STALE",
      /Bản nháp cần tạo lại/,
      /Đơn nháp cần cập nhật/,
    ],
    [
      "replacement_required",
      "PO_REPLACEMENT_REQUIRED",
      /Đơn đã phát hành được giữ nguyên/,
      /không còn khớp phân bổ|Đơn đã được phát hành/,
    ],
    [
      "cancellation_required",
      "CANCELLATION_REQUIRED",
      /Cần xử lý hủy cam kết/,
      /never-match/,
    ],
  ] as const)(
    "renders %s guidance once and retains unrelated warnings",
    (scenario, code, dedicated, duplicate) => {
      const fixture = createProcurementReviewFixture(scenario);
      const order = fixture.orders.purchase_orders[0]!;
      order.blockers = [code];
      order.disabled_reasons = [
        code,
        ...(scenario === "replacement_required" ? ["PO_ALREADY_RELEASED"] : []),
      ];
      order.warnings = [code, "SUPPLIER_INACTIVE", "SUPPLIER_INACTIVE"];
      render(
        <AtlasVNextProvider>
          <ProcurementOrdersStage
            data={fixture.orders}
            disabled={false}
            search=""
            onAction={vi.fn()}
          />
        </AtlasVNextProvider>,
      );
      fireEvent.click(
        screen.getByRole("button", { name: /^Xem đơn NCC An Phú/ }),
      );
      const detail = within(
        screen.getByRole("region", { name: "Chi tiết đơn mua NCC An Phú" }),
      );
      expect(screen.getAllByText(dedicated)).toHaveLength(1);
      expect(screen.queryAllByText(duplicate)).toHaveLength(0);
      expect(
        detail.getAllByText(/Nhà cung cấp hiện không hoạt động/),
      ).toHaveLength(1);
    },
  );
  it("does not suppress a state reason without matching dedicated guidance", () => {
    const fixture = createProcurementReviewFixture("po_draft");
    fixture.orders.purchase_orders[0]!.disabled_reasons = [
      "PO_ALREADY_RELEASED",
      "PO_REPLACEMENT_REQUIRED",
    ];
    render(
      <AtlasVNextProvider>
        <ProcurementOrdersStage
          data={fixture.orders}
          disabled={false}
          search=""
          onAction={vi.fn()}
        />
      </AtlasVNextProvider>,
    );
    fireEvent.click(
      screen.getByRole("button", { name: /^Xem đơn NCC An Phú/ }),
    );
    expect(screen.getByText(/Đơn đã được phát hành/)).toBeVisible();
    expect(screen.getByText(/không còn khớp phân bổ/)).toBeVisible();
  });
  it("keeps scope-wide PO blockers visible without a selected order", () => {
    const fixture = createProcurementReviewFixture("empty");
    fixture.orders.blockers = ["CANCELLATION_REQUIRED"];
    render(
      <AtlasVNextProvider>
        <ProcurementOrdersStage
          data={fixture.orders}
          disabled={false}
          search=""
          onAction={vi.fn()}
        />
      </AtlasVNextProvider>,
    );
    expect(screen.getByText(/Cần xử lý hủy cam kết/)).toBeVisible();
  });
  it.each([
    ["po_draft", "Phát hành cho NCC"],
    ["po_stale", "Tạo lại đơn cần cập nhật"],
    ["replacement_required", "Tạo đơn thay thế"],
  ] as const)("has one consequential action for %s", (scenario, label) => {
    const { onAction, detail, fixture } = show(scenario);
    const primary = within(detail).getByRole("button", { name: label });
    expect(primary).toBeEnabled();
    fireEvent.click(primary);
    expect(onAction).toHaveBeenCalledWith(fixture.orders.purchase_orders[0]);
    expect(
      within(detail).queryAllByRole("button", {
        name: /^(Phát hành cho NCC|Tạo lại đơn cần cập nhật|Tạo đơn thay thế)$/,
      }),
    ).toHaveLength(1);
  });
  it("shows exact line quantities, focuses detail and returns focus to originating row", () => {
    const { trigger, detail } = show();
    expect(
      within(detail).getByRole("heading", { name: "NCC An Phú" }),
    ).toHaveFocus();
    expect(detail).toHaveTextContent("60,000001");
    expect(detail).not.toHaveTextContent(/private-|phiên bản/i);
    fireEvent.click(within(detail).getByRole("button", { name: "Đóng" }));
    expect(trigger).toHaveFocus();
  });
  it("shows cancellation blocker without an invented cancel action", () => {
    const { detail } = show("cancellation_required");
    expect(detail).toHaveTextContent("Cần xử lý hủy cam kết");
    expect(
      within(detail).queryByRole("button", { name: /hủy|thay thế|phát hành/i }),
    ).not.toBeInTheDocument();
  });
  it.each(["po_released", "superseded"] as const)(
    "exports only authoritative immutable %s snapshots",
    (scenario) => {
      const { detail, onExportXlsx, fixture } = show(scenario);
      expect(
        within(detail).queryByRole("button", { name: "Phát hành cho NCC" }),
      ).not.toBeInTheDocument();
      fireEvent.click(
        within(detail).getByRole("button", { name: "Xuất Excel" }),
      );
      expect(onExportXlsx).toHaveBeenCalledWith(
        fixture.orders.purchase_orders[0],
        "all",
      );
      expect(
        within(detail).getByRole("button", { name: "Xuất PDF" }),
      ).toBeVisible();
    },
  );
  it("does not expose exports for drafts", () => {
    const { detail } = show();
    expect(
      within(detail).queryByRole("button", { name: "Xuất Excel" }),
    ).not.toBeInTheDocument();
  });
  it.each(["po_draft", "po_stale", "replacement_required"] as const)(
    "locks %s consequential action after stale/unknown",
    (scenario) => {
      const { detail } = show(scenario, true);
      expect(
        within(detail).getByRole("button", {
          name: /^(Phát hành cho NCC|Tạo lại đơn cần cập nhật|Tạo đơn thay thế)$/,
        }),
      ).toBeDisabled();
    },
  );
});
