import { describe, expect, it } from "vitest";
import ExcelJS from "exceljs";
import { createReviewPurchaseOrdersFixture } from "./reviewSchoolCateringProcurementApi";
import {
  buildPurchaseOrderExportData,
  buildPurchaseOrderPdfDefinition,
  createPurchaseOrderPdf,
  createPurchaseOrderXlsx,
} from "./purchaseOrderExports";

describe("released purchase-order exports", () => {
  it("builds summary and school detail solely from the released PO snapshot", () => {
    const order =
      createReviewPurchaseOrdersFixture("released_po").purchase_orders[0]!;
    const data = buildPurchaseOrderExportData(order);

    expect(data).toEqual({
      documentNumber: "PO-20260902-2500000000004000",
      supplierName: "NCC An Phú",
      serviceDate: "02/09/2026",
      releasedRevision: 2,
      summaryLines: [
        {
          ingredientName: "Gạo thơm",
          orderedQuantity: "100.000000",
          unitCode: "kg",
        },
      ],
      schoolLines: [
        {
          locationName: "Bếp chính Nguyễn Du",
          ingredientName: "Gạo thơm",
          orderedQuantity: "60.000000",
          unitCode: "kg",
        },
        {
          locationName: "Bếp chính Trần Quốc Toản",
          ingredientName: "Gạo thơm",
          orderedQuantity: "40.000000",
          unitCode: "kg",
        },
      ],
    });
  });

  it("preserves exact six-decimal quantities beyond JavaScript safe integers", () => {
    const order =
      createReviewPurchaseOrdersFixture("released_po").purchase_orders[0]!;
    order.lines[0]!.ordered_quantity = "9007199254740992.123455";
    order.lines[1]!.ordered_quantity = "1.000001";

    expect(
      buildPurchaseOrderExportData(order).summaryLines[0]!.orderedQuantity,
    ).toBe("9007199254740993.123456");
  });

  it("includes official identity and released snapshot lines in the PDF definition", () => {
    const order =
      createReviewPurchaseOrdersFixture("released_po").purchase_orders[0]!;
    const definition = buildPurchaseOrderPdfDefinition(order);
    const serialized = JSON.stringify(definition);

    expect(serialized).toContain("PO-20260902-2500000000004000");
    expect(serialized).toContain("NCC An Phú");
    expect(serialized).toContain("02/09/2026");
    expect(serialized).toContain("Gạo thơm");
    expect(serialized).toContain("Bếp chính Nguyễn Du");
    expect(serialized).toContain("60.000000");
  });

  it("creates the default XLSX with summary and school-detail sheets", async () => {
    const order =
      createReviewPurchaseOrdersFixture("released_po").purchase_orders[0]!;
    const bytes = await createPurchaseOrderXlsx(order);
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(bytes);

    expect(workbook.worksheets.map((sheet) => sheet.name)).toEqual([
      "Đơn mua",
      "Theo trường",
    ]);
    const summaryText = JSON.stringify(
      workbook.getWorksheet("Đơn mua")!.getSheetValues(),
    );
    const schoolText = JSON.stringify(
      workbook.getWorksheet("Theo trường")!.getSheetValues(),
    );
    expect(summaryText).toContain("PO-20260902-2500000000004000");
    expect(summaryText).toContain("NCC An Phú");
    expect(summaryText).toContain("100.000000");
    expect(schoolText).toContain("Bếp chính Nguyễn Du");
    expect(schoolText).toContain("60.000000");
  });

  it("creates an actual PDF document from the same released snapshot", async () => {
    const order =
      createReviewPurchaseOrdersFixture("released_po").purchase_orders[0]!;
    const bytes = await createPurchaseOrderPdf(order);
    expect(new TextDecoder().decode(bytes.slice(0, 5))).toBe("%PDF-");
    expect(bytes.byteLength).toBeGreaterThan(1_000);
  });

  it("rejects output generation for a DRAFT snapshot", async () => {
    const order =
      createReviewPurchaseOrdersFixture("po_draft").purchase_orders[0]!;
    expect(() => buildPurchaseOrderExportData(order)).toThrow(
      /released PO snapshot/,
    );
    await expect(createPurchaseOrderXlsx(order)).rejects.toThrow(
      /released PO snapshot/,
    );
    await expect(createPurchaseOrderPdf(order)).rejects.toThrow(
      /released PO snapshot/,
    );
  });
});
