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
  const trigger = screen.getByRole("button", { name: "Xem đơn NCC An Phú" });
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
        screen.getByRole("button", { name: "Xem đơn NCC An Phú" }),
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
    fireEvent.click(screen.getByRole("button", { name: "Xem đơn NCC An Phú" }));
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
      fireEvent.click(within(detail).getByRole("button", { name: "XLSX" }));
      expect(onExportXlsx).toHaveBeenCalledWith(
        fixture.orders.purchase_orders[0],
      );
      expect(within(detail).getByRole("button", { name: "PDF" })).toBeVisible();
    },
  );
  it("does not expose exports for drafts", () => {
    const { detail } = show();
    expect(
      within(detail).queryByRole("button", { name: "XLSX" }),
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
