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
import { AtlasVNextProvider } from "../AtlasVNextProvider";
import { ProcurementOrdersStage } from "./ProcurementOrdersStage";
import { reviewOrder, reviewDate } from "./procurementReviewFixtures";

afterEach(cleanup);
const bulk = () => {
  const disclosure = screen.queryByRole("button", {
    name: "Tiện ích đơn mua",
  });
  if (disclosure?.getAttribute("aria-expanded") === "false")
    fireEvent.click(disclosure);
  return within(screen.getByRole("group", { name: "Tiện ích đơn mua đã tải" }));
};
const selectedExports = () =>
  within(screen.getByRole("region", { name: /^Chi tiết đơn mua/ }));
async function confirmExport(format: "XLSX" | "PDF") {
  const dialog = within(
    await screen.findByRole("dialog", { name: `Đơn mua sẽ xuất ${format}` }),
  );
  expect(
    dialog.getByRole("list", { name: "Danh sách đơn mua" }),
  ).toHaveTextContent("PO-20260910-ANPHU");
  fireEvent.click(dialog.getByRole("button", { name: `Xuất ${format} 1 đơn` }));
}
describe("loaded PO presentation exports", () => {
  const data = () => ({
    success: true as const,
    contract_version: "SCHOOL-CATERING-PROCUREMENT.v1" as const,
    date_start: reviewDate,
    date_end: reviewDate,
    purchase_orders: [reviewOrder("po_released")],
    procurement_current: true,
    warnings: [],
    blockers: [],
  });
  it.each(["all", "details_ing", "details_school", "sum"] as const)(
    "sends %s mode to the actual PDF ZIP callback",
    async (mode) => {
      const orders = data(),
        zip = vi.fn();
      render(
        <AtlasVNextProvider>
          <ProcurementOrdersStage
            data={orders}
            disabled={false}
            search=""
            onAction={vi.fn()}
            onExportZip={zip}
          />
        </AtlasVNextProvider>,
      );
      fireEvent.change(
        bulk().getByRole("combobox", { name: "Nội dung xuất PO" }),
        { target: { value: mode } },
      );
      fireEvent.click(bulk().getByRole("button", { name: "Xuất PDF" }));
      expect(zip).not.toHaveBeenCalled();
      await confirmExport("PDF");
      await waitFor(() =>
        expect(zip).toHaveBeenCalledWith(orders.purchase_orders, mode, "pdf"),
      );
    },
  );
  it("locks both formats during export and offers retry after a generation failure", async () => {
    let reject!: (error: Error) => void;
    const zip = vi.fn(
      () =>
        new Promise<void>((_resolve, fail) => {
          reject = fail;
        }),
    );
    render(
      <AtlasVNextProvider>
        <ProcurementOrdersStage
          data={data()}
          disabled={false}
          search=""
          onAction={vi.fn()}
          onExportZip={zip}
        />
      </AtlasVNextProvider>,
    );
    const xlsx = bulk().getByRole("button", { name: "Xuất XLSX" });
    const pdf = bulk().getByRole("button", { name: "Xuất PDF" });
    fireEvent.click(pdf);
    await confirmExport("PDF");
    expect(xlsx).toBeDisabled();
    expect(pdf).toBeDisabled();
    expect(
      screen.getByRole("combobox", { name: "Nội dung xuất PO" }),
    ).toBeDisabled();
    fireEvent.click(xlsx);
    expect(zip).toHaveBeenCalledTimes(1);
    reject(new Error("document generation failed"));
    await waitFor(() =>
      expect(screen.getByRole("alert")).toHaveTextContent(
        "Chưa xuất được chứng từ",
      ),
    );
    expect(xlsx).toBeEnabled();
    expect(pdf).toBeEnabled();
    zip.mockResolvedValueOnce(undefined);
    fireEvent.click(xlsx);
    await confirmExport("XLSX");
    await waitFor(() =>
      expect(zip).toHaveBeenLastCalledWith(
        data().purchase_orders,
        "all",
        "xlsx",
      ),
    );
  });
  it("passes the selected mode to immutable XLSX/PDF and ZIP callbacks", async () => {
    const orders = data();
    const xlsx = vi.fn(),
      pdf = vi.fn(),
      zip = vi.fn();
    render(
      <AtlasVNextProvider>
        <ProcurementOrdersStage
          data={orders}
          disabled={false}
          search=""
          onAction={vi.fn()}
          onExportXlsx={xlsx}
          onExportPdf={pdf}
          onExportZip={zip}
        />
      </AtlasVNextProvider>,
    );
    fireEvent.change(
      bulk().getByRole("combobox", { name: "Nội dung xuất PO" }),
      { target: { value: "details_ing" } },
    );
    fireEvent.click(bulk().getByRole("button", { name: "Xuất XLSX" }));
    await confirmExport("XLSX");
    expect(zip).toHaveBeenCalledWith(
      orders.purchase_orders,
      "details_ing",
      "xlsx",
    );
    fireEvent.click(
      screen.getByRole("button", { name: /^Xem đơn NCC An Phú/ }),
    );
    await waitFor(() =>
      expect(
        selectedExports().getByRole("button", { name: "Xuất XLSX" }),
      ).toBeEnabled(),
    );
    fireEvent.click(
      selectedExports().getByRole("button", { name: "Xuất XLSX" }),
    );
    expect(xlsx).toHaveBeenCalledWith(orders.purchase_orders[0], "details_ing");
    await waitFor(() =>
      expect(
        selectedExports().getByRole("button", { name: "Xuất PDF" }),
      ).toBeEnabled(),
    );
    fireEvent.click(
      selectedExports().getByRole("button", { name: "Xuất PDF" }),
    );
    expect(pdf).toHaveBeenCalledWith(orders.purchase_orders[0], "details_ing");
  });
  it("requires an explicit date-wide choice to export hidden eligible orders and excludes denied/draft/unready rows", async () => {
    const orders = data();
    const denied = reviewOrder("po_released");
    denied.purchase_order_id = "denied";
    denied.allowed_actions.export = false;
    const unready = reviewOrder("po_released");
    unready.purchase_order_id = "unready";
    unready.export_ready = false;
    const draft = reviewOrder("po_draft");
    draft.purchase_order_id = "draft";
    orders.purchase_orders.push(denied, unready, draft);
    const zip = vi.fn();
    render(
      <AtlasVNextProvider>
        <ProcurementOrdersStage
          data={orders}
          disabled={false}
          search="no match"
          onAction={vi.fn()}
          onExportZip={zip}
        />
      </AtlasVNextProvider>,
    );
    expect(bulk().getByRole("button", { name: "Xuất XLSX" })).toBeDisabled();
    fireEvent.change(
      bulk().getByRole("combobox", { name: "Phạm vi thao tác" }),
      { target: { value: "loaded" } },
    );
    fireEvent.click(bulk().getByRole("button", { name: "Xuất XLSX" }));
    await confirmExport("XLSX");
    expect(zip).toHaveBeenCalledWith(
      [orders.purchase_orders[0]],
      "all",
      "xlsx",
    );
    await waitFor(() =>
      expect(bulk().getByRole("button", { name: "Xuất PDF" })).toBeEnabled(),
    );
    fireEvent.click(bulk().getByRole("button", { name: "Xuất PDF" }));
    await confirmExport("PDF");
    expect(zip).toHaveBeenLastCalledWith(
      [orders.purchase_orders[0]],
      "all",
      "pdf",
    );
  });
  it("blocks confirmation when the reviewed revision loses export permission", async () => {
    const orders = data();
    const zip = vi.fn();
    const stage = () => (
      <AtlasVNextProvider>
        <ProcurementOrdersStage
          data={orders}
          disabled={false}
          search=""
          onAction={vi.fn()}
          onExportZip={zip}
        />
      </AtlasVNextProvider>
    );
    const { rerender } = render(stage());
    fireEvent.click(bulk().getByRole("button", { name: "Xuất PDF" }));
    const dialog = within(await screen.findByRole("dialog"));
    orders.purchase_orders[0]!.allowed_actions.export = false;
    rerender(stage());
    expect(dialog.getByRole("alert")).toHaveTextContent(
      "Thông tin đơn mua đã thay đổi",
    );
    expect(
      dialog.getByRole("button", { name: "Xuất PDF 1 đơn" }),
    ).toBeDisabled();
    expect(zip).not.toHaveBeenCalled();
  });
  it("blocks ZIP while the loaded scope is unavailable", () => {
    const zip = vi.fn();
    render(
      <AtlasVNextProvider>
        <ProcurementOrdersStage
          data={data()}
          disabled
          search=""
          onAction={vi.fn()}
          onExportZip={zip}
        />
      </AtlasVNextProvider>,
    );
    const button = bulk().getByRole("button", { name: "Xuất XLSX" });
    expect(button).toBeDisabled();
    expect(bulk().getByRole("button", { name: "Xuất PDF" })).toBeDisabled();
    fireEvent.click(button);
    expect(zip).not.toHaveBeenCalled();
  });
  it("keeps incomplete historical records readable with safe guidance and no official exports", () => {
    const orders = data();
    const order = orders.purchase_orders[0]!;
    order.document_snapshot_complete = false;
    order.export_ready = false;
    order.allowed_actions.export = false;
    order.blockers = ["PO_DOCUMENT_SNAPSHOT_INCOMPLETE"];
    render(
      <AtlasVNextProvider>
        <ProcurementOrdersStage
          data={orders}
          disabled={false}
          search=""
          onAction={vi.fn()}
          onExportXlsx={vi.fn()}
          onExportPdf={vi.fn()}
          onExportZip={vi.fn()}
        />
      </AtlasVNextProvider>,
    );
    fireEvent.click(
      screen.getByRole("button", { name: /^Xem đơn NCC An Phú/ }),
    );
    expect(
      screen.getByText(
        /Không đủ dữ liệu chứng từ lịch sử để tái xuất chính thức\./,
      ),
    ).toBeInTheDocument();
    expect(screen.getAllByText("Gạo thơm").length).toBeGreaterThan(0);
    expect(
      selectedExports().queryByRole("button", { name: "Xuất XLSX" }),
    ).not.toBeInTheDocument();
    expect(
      selectedExports().queryByRole("button", { name: "Xuất PDF" }),
    ).not.toBeInTheDocument();
    expect(bulk().getByRole("button", { name: "Xuất XLSX" })).toBeDisabled();
    expect(bulk().getByRole("button", { name: "Xuất PDF" })).toBeDisabled();
    expect(
      screen.queryByText("PO_DOCUMENT_SNAPSHOT_INCOMPLETE"),
    ).not.toBeInTheDocument();
  });
});
