import "@testing-library/jest-dom/vitest";
import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { AtlasVNextProvider } from "../AtlasVNextProvider";
import { ProcurementOrdersStage } from "./ProcurementOrdersStage";
import { reviewOrder, reviewDate } from "./procurementReviewFixtures";

afterEach(cleanup);
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
      screen.getByRole("combobox", { name: "Nội dung xuất PO" }),
      { target: { value: "details_ing" } },
    );
    fireEvent.click(
      screen.getByRole("button", { name: "Xuất ZIP PO · phạm vi đã tải" }),
    );
    expect(zip).toHaveBeenCalledWith(orders.purchase_orders, "details_ing");
    fireEvent.click(screen.getByRole("button", { name: "Xem đơn NCC An Phú" }));
    await waitFor(() =>
      expect(screen.getByRole("button", { name: "XLSX" })).toBeEnabled(),
    );
    fireEvent.click(screen.getByRole("button", { name: "XLSX" }));
    expect(xlsx).toHaveBeenCalledWith(orders.purchase_orders[0], "details_ing");
    await waitFor(() =>
      expect(screen.getByRole("button", { name: "PDF" })).toBeEnabled(),
    );
    fireEvent.click(screen.getByRole("button", { name: "PDF" }));
    expect(pdf).toHaveBeenCalledWith(orders.purchase_orders[0], "details_ing");
  });
  it("includes loaded eligible orders despite local search and excludes denied/draft/unready rows", () => {
    const orders = data();
    const denied = reviewOrder("po_released");
    denied.purchase_order_id = "denied";
    denied.allowed_actions.export = false;
    const unready = reviewOrder("po_released");
    unready.purchase_order_id = "unready";
    unready.export_ready = false;
    orders.purchase_orders.push(denied, unready, reviewOrder("po_draft"));
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
    fireEvent.click(
      screen.getByRole("button", { name: "Xuất ZIP PO · phạm vi đã tải" }),
    );
    expect(zip).toHaveBeenCalledWith([orders.purchase_orders[0]], "all");
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
    const button = screen.getByRole("button", {
      name: "Xuất ZIP PO · phạm vi đã tải",
    });
    expect(button).toBeDisabled();
    fireEvent.click(button);
    expect(zip).not.toHaveBeenCalled();
  });
});
