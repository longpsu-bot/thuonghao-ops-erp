import { expect, it } from "vitest";
import {
  readRpcAllowed,
  assertOperatorOrders,
  observeRpcRequest,
} from "./atlas-procurement-cutover-browser.mjs";
it("ignores CORS preflights when recording application RPC responses", () => {
  const origin = "https://rnzxmxiiqgtdevzregff.supabase.co";
  const url =
    origin + "/rest/v1/rpc/get_confirmed_supplier_allocation_workbench";
  expect(observeRpcRequest({ method: "OPTIONS", url }, origin)).toBe(false);
  expect(observeRpcRequest({ method: "POST", url }, origin)).toBe(true);
});
it("permits only the declared read surfaces", () => {
  expect(readRpcAllowed("get_confirmed_supplier_allocation_workbench")).toBe(
    true,
  );
  expect(readRpcAllowed("get_school_catering_purchase_orders")).toBe(true);
  for (const name of [
    "prepare_school_catering_purchase_orders",
    "save_confirmed_supplier_allocation",
    "release_school_catering_purchase_order",
    "get_unknown",
  ])
    expect(readRpcAllowed(name)).toBe(false);
});
const orders = () => ({
  success: true,
  purchase_orders: Array.from({ length: 17 }, (_, i) => ({
    purchase_order_id: "po-" + i,
    supplier: { supplier_id: "supplier-" + i },
    service_date: "2026-10-12",
    status: "DRAFT",
    lines: Array.from({ length: i === 0 ? 12 : 14 }, (_, j) => ({
      purchase_order_line_revision_id: i + "-" + j,
    })),
  })),
});
it("rejects duplicate Supplier/date roots", () => {
  const r = orders();
  r.purchase_orders[1].supplier.supplier_id = "supplier-0";
  expect(() => assertOperatorOrders(r)).toThrow();
});
it("rejects a released PO", () => {
  const r = orders();
  r.purchase_orders[0].status = "RELEASED_TO_SUPPLIER";
  expect(() => assertOperatorOrders(r)).toThrow();
});
it("accepts exactly 17 Draft POs and 236 lines", () => {
  expect(() => assertOperatorOrders(orders())).not.toThrow();
});
it("rejects a missing line", () => {
  const r = orders();
  r.purchase_orders[0].lines.pop();
  expect(() => assertOperatorOrders(r)).toThrow();
});
