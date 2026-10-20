import "@testing-library/jest-dom/vitest";
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { AtlasVNextProvider } from "../AtlasVNextProvider";
import { ProcurementOrdersStage } from "./ProcurementOrdersStage";
import { createProcurementReviewFixture } from "./procurementReviewFixtures";
import { reviewFamily } from "./procurementReviewFixtures";
import { ProcurementAllocationTable } from "./ProcurementAllocationTable";
import { ProcurementSupplierDetail } from "./ProcurementSupplierDetail";

afterEach(cleanup);
describe("Allocation Unit display", () => {
  it("uses the current human Unit in the list, saved splits and editor", () => {
    const row = {
      ...reviewFamily("manual_split"),
      unit_code: "v1-unit-count",
      unit_name: "Gói",
    };
    render(
      <AtlasVNextProvider>
        <ProcurementAllocationTable
          rows={[row]}
          selectedKey={null}
          disabled={false}
          onSelect={vi.fn()}
        />
        <ProcurementSupplierDetail
          row={row}
          disabled={false}
          onSave={vi.fn()}
          onClose={vi.fn()}
        />
      </AtlasVNextProvider>,
    );
    const table = screen.getByRole("table", { name: "Phân bổ nhà cung ứng" });
    const detail = screen.getByRole("region", { name: "Phân bổ Gạo thơm" });
    expect(table).toHaveTextContent("100 Gói");
    expect(detail).toHaveTextContent("100 / 100 Gói");
    expect(table).not.toHaveTextContent("v1-unit-");
    expect(detail).not.toHaveTextContent("v1-unit-");
    expect(
      screen.getByRole("textbox", { name: "Phân bổ NCC An Phú" }),
    ).toHaveValue("60");
    expect(
      screen.getByRole("textbox", { name: "Phân bổ NCC Bình Minh" }),
    ).toHaveValue("40");
    const quantity = screen.getByRole("textbox", {
      name: "Phân bổ NCC An Phú",
    });
    fireEvent.change(quantity, { target: { value: "59" } });
    expect(detail).toHaveTextContent("99 / 100 Gói");
    expect(detail).toHaveTextContent("Thiếu 1 Gói");
    expect(screen.getByRole("button", { name: "Lưu phân bổ" })).toBeDisabled();
    fireEvent.change(quantity, { target: { value: "61" } });
    expect(detail).toHaveTextContent("101 / 100 Gói");
    expect(detail).toHaveTextContent("Vượt 1 Gói");
    expect(screen.getByRole("button", { name: "Lưu phân bổ" })).toBeDisabled();
  });
});
describe("PO Unit display", () => {
  it("uses the backend Unit name for imported draft identifiers", () => {
    const f = createProcurementReviewFixture("po_draft");
    Object.assign(f.orders.purchase_orders[0]!.lines[0]!.unit, {
      unit_code: "v1-unit-469606e98b7e",
      unit_name: "Gói",
    });
    render(
      <AtlasVNextProvider>
        <ProcurementOrdersStage
          data={f.orders}
          disabled={false}
          search=""
          onAction={vi.fn()}
        />
      </AtlasVNextProvider>,
    );
    expect(
      screen.getByRole("region", { name: /Chi tiết đơn mua/ }),
    ).toHaveTextContent("60,000001 Gói");
    expect(
      screen.getByRole("region", { name: /Chi tiết đơn mua/ }),
    ).not.toHaveTextContent("v1-unit-");
  });
  it("retains the frozen official label even when a mutable Unit name is present", () => {
    const f = createProcurementReviewFixture("po_released");
    Object.assign(f.orders.purchase_orders[0]!.lines[0]!.unit, {
      unit_code: "Changed master code",
      unit_name: "Changed master name",
    });
    render(
      <AtlasVNextProvider>
        <ProcurementOrdersStage
          data={f.orders}
          disabled={false}
          search=""
          onAction={vi.fn()}
        />
      </AtlasVNextProvider>,
    );
    expect(
      screen.getByRole("region", { name: /Chi tiết đơn mua/ }),
    ).toHaveTextContent("60,000001 kg");
    expect(
      screen.getByRole("region", { name: /Chi tiết đơn mua/ }),
    ).not.toHaveTextContent("Changed master name");
  });
});
