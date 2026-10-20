import "@testing-library/jest-dom/vitest";
import { cleanup, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { AtlasVNextProvider } from "../AtlasVNextProvider";
import { ProcurementOrdersStage } from "./ProcurementOrdersStage";
import { createProcurementReviewFixture } from "./procurementReviewFixtures";

afterEach(cleanup);
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
