import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import ExcelJS from "exceljs";
import { expect, it } from "vitest";
import { createReviewPurchaseOrdersFixture } from "./reviewSchoolCateringProcurementApi";
import {
  buildPurchaseOrderPdfDefinition,
  createPurchaseOrderXlsx,
} from "./purchaseOrderExports";

it("retains baseline historical models except the explicitly verified header layout fixes in every mode", async () => {
  const order =
    createReviewPurchaseOrdersFixture("released_po").purchase_orders[0]!;
  order.current_revision.released_at = "2026-09-02T00:00:00.000Z";
  const results: Record<string, { xlsx: string; pdf: string }> = {};
  const hash = (value: unknown) =>
    createHash("sha256").update(JSON.stringify(value)).digest("hex");
  for (const mode of ["all", "details_ing", "details_school", "sum"] as const) {
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(await createPurchaseOrderXlsx(order, mode));
    // Verify the authorized layout fixes, then retain the original full-model golden.
    for (const sheet of workbook.worksheets.filter(
      (sheet) => sheet.state === "visible",
    )) {
      if (sheet.name.endsWith(" - Tổng")) {
        expect(sheet.getRow(7).height).toBe(32);
        sheet.getRow(7).height = 24;
        for (const row of [1, 2]) {
          for (let column = 3; column <= 6; column++) {
            const cell = sheet.getCell(row, column);
            expect(cell.alignment.horizontal).toBe("center");
            const { horizontal: _horizontal, ...alignment } = cell.alignment;
            cell.style = { ...cell.style, alignment };
          }
        }
      } else {
        expect(sheet.getRow(5).height).toBe(32);
        sheet.getRow(5).height = 22;
      }
    }
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
