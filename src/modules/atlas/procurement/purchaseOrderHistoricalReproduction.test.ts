import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import ExcelJS from "exceljs";
import { expect, it } from "vitest";
import { createReviewPurchaseOrdersFixture } from "./reviewSchoolCateringProcurementApi";
import {
  buildPurchaseOrderPdfDefinition,
  createPurchaseOrderXlsx,
} from "./purchaseOrderExports";

it("retains baseline historical worksheet models and PDF definitions in every mode", async () => {
  const order =
    createReviewPurchaseOrdersFixture("released_po").purchase_orders[0]!;
  order.current_revision.released_at = "2026-09-02T00:00:00.000Z";
  const results: Record<string, { xlsx: string; pdf: string }> = {};
  const hash = (value: unknown) =>
    createHash("sha256").update(JSON.stringify(value)).digest("hex");
  for (const mode of ["all", "details_ing", "details_school", "sum"] as const) {
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(await createPurchaseOrderXlsx(order, mode));
    results[mode] = {
      xlsx: hash(workbook.model),
      pdf: hash(buildPurchaseOrderPdfDefinition(order, mode)),
    };
  }
  const baseline = JSON.parse(
    readFileSync(
      "docs/testing/artifacts/atlas-b2-po-ingredient-code-optional/historical-baseline.json",
      "utf8",
    ),
  );
  expect(results).toEqual(baseline);
});
