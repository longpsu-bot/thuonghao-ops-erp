import { expect, it } from "vitest";
import { purchaseOrderLineUnitLabel } from "./schoolCateringProcurementModel";
import { createReviewPurchaseOrdersFixture } from "./reviewSchoolCateringProcurementApi";

it("keeps the captured human Unit label after release and master rename", () => {
  const line =
    createReviewPurchaseOrdersFixture("released_po").purchase_orders[0]!
      .lines[0]!;
  Object.assign(line, {
    unit_code_snapshot: "v1-unit-count",
    unit_name_snapshot: "Gói",
  });
  Object.assign(line.unit, {
    unit_code: "unit-new",
    unit_name: "Changed master name",
  });
  expect(purchaseOrderLineUnitLabel("RELEASED_TO_SUPPLIER", line)).toBe("Gói");
  expect(purchaseOrderLineUnitLabel("SUPERSEDED", line)).toBe("Gói");
});

it("retains legacy evidence when no frozen human Unit label exists", () => {
  const line =
    createReviewPurchaseOrdersFixture("released_po").purchase_orders[0]!
      .lines[0]!;
  line.unit_code_snapshot = "v1-unit-count";
  line.unit.unit_name = "Mutable current name";
  expect(purchaseOrderLineUnitLabel("RELEASED_TO_SUPPLIER", line)).toBe(
    "v1-unit-count",
  );
});

it("retains a normal frozen Unit code when a name snapshot also exists", () => {
  const line =
    createReviewPurchaseOrdersFixture("released_po").purchase_orders[0]!
      .lines[0]!;
  Object.assign(line, {
    unit_code_snapshot: "kg",
    unit_name_snapshot: "Kilogram",
  });
  expect(purchaseOrderLineUnitLabel("RELEASED_TO_SUPPLIER", line)).toBe("kg");
});
