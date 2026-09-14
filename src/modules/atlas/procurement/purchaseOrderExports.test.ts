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
    order.supplier.supplier_name = "Tên NCC hiện tại đã đổi";
    order.current_revision.supplier_name_snapshot = "NCC An Phú lúc phát hành";
    const data = buildPurchaseOrderExportData(order);

    expect(data).toEqual({
      documentNumber: "PO-20260902-2500000000004000",
      supplierName: "NCC An Phú lúc phát hành",
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
          schoolName: "Trường Nguyễn Du",
          schoolDisplayOrder: 1,
          ingredientName: "Gạo thơm",
          orderedQuantity: "60.000000",
          unitCode: "kg",
        },
        {
          schoolName: "Trường Trần Quốc Toản",
          schoolDisplayOrder: 2,
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
    order.lines[0]!.school_breakdown[0]!.ordered_quantity =
      "9007199254740992.123455";
    order.lines[1]!.school_breakdown[0]!.ordered_quantity = "1.000001";

    expect(
      buildPurchaseOrderExportData(order).summaryLines[0]!.orderedQuantity,
    ).toBe("9007199254740993.123456");
  });

  it("includes official identity and released snapshot lines in the PDF definition", () => {
    const order =
      createReviewPurchaseOrdersFixture("released_po").purchase_orders[0]!;
    order.supplier.supplier_name = "Tên NCC hiện tại đã đổi";
    order.current_revision.supplier_name_snapshot = "NCC An Phú lúc phát hành";
    const definition = buildPurchaseOrderPdfDefinition(order);
    const serialized = JSON.stringify(definition);

    expect(serialized).toContain("PHIẾU ĐẶT HÀNG");
    expect(serialized).toContain("PO-20260902-2500000000004000");
    expect(serialized).toContain("NCC An Phú lúc phát hành");
    expect(serialized).not.toContain("Tên NCC hiện tại đã đổi");
    expect(serialized).toContain("02/09/2026");
    expect(serialized).toContain("Gạo thơm");
    expect(serialized).toContain("Trường Nguyễn Du");
    expect(serialized).toContain("60.000000");
  });

  it("creates the default three-sheet PO workbook with exact numeric quantities", async () => {
    const order =
      createReviewPurchaseOrdersFixture("released_po").purchase_orders[0]!;
    order.supplier.supplier_name = "Tên NCC hiện tại đã đổi";
    order.current_revision.supplier_name_snapshot = "NCC An Phú lúc phát hành";
    const bytes = await createPurchaseOrderXlsx(order);
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(bytes);

    expect(workbook.worksheets.map((sheet) => sheet.name)).toEqual([
      "Tổng",
      "Theo trường",
      "Theo hàng",
    ]);
    const summaryText = JSON.stringify(
      workbook.getWorksheet("Tổng")!.getSheetValues(),
    );
    const schoolText = JSON.stringify(
      workbook.getWorksheet("Theo trường")!.getSheetValues(),
    );
    const ingredientText = JSON.stringify(
      workbook.getWorksheet("Theo hàng")!.getSheetValues(),
    );
    expect(summaryText).toContain("PHIẾU ĐẶT HÀNG");
    expect(summaryText).toContain("PO-20260902-2500000000004000");
    expect(summaryText).toContain("NCC An Phú lúc phát hành");
    expect(summaryText).not.toContain("Tên NCC hiện tại đã đổi");
    expect(summaryText).toContain("02/09/2026");
    expect(summaryText).not.toContain("Mã hàng");
    expect(summaryText).not.toContain("Mã NCC");
    expect(schoolText).toContain("Trường Nguyễn Du");
    expect(ingredientText).toContain("Trường Trần Quốc Toản");
    expect(workbook.getWorksheet("Tổng")!.getCell("D8").value).toBe(100);
    expect(workbook.getWorksheet("Theo trường")!.getCell("A10").value).toBe(
      "Trường Nguyễn Du",
    );
    expect(workbook.getWorksheet("Theo trường")!.model.merges).toContain(
      "A10:B10",
    );
    expect(workbook.getWorksheet("Theo trường")!.model.merges).toContain(
      "F10:G10",
    );
    expect(workbook.getWorksheet("Theo trường")!.getCell("A11").value).toBe(
      "Trường Trần Quốc Toản",
    );
    expect(workbook.getWorksheet("Theo trường")!.getCell("F10").value).toBe(60);
    expect(
      workbook.getWorksheet("Theo trường")!.getCell("F10").numFmt ?? "General",
    ).toBe("General");
    expect(workbook.model.media).toHaveLength(1);
    expect(
      workbook.getWorksheet("Theo trường")!.getCell("A9").fill,
    ).toMatchObject({
      type: "pattern",
      pattern: "solid",
    });
    expect(workbook.getWorksheet("Theo hàng")!.getCell("A10").value).toBe(
      "Gạo thơm",
    );
    expect(workbook.getWorksheet("Theo hàng")!.model.merges).toContain(
      "A10:B10",
    );
    expect(workbook.getWorksheet("Theo hàng")!.getCell("A11").value).toBeNull();
    expect(workbook.getWorksheet("Theo hàng")!.getRow(10).height).toBe(30);
    expect(workbook.getWorksheet("Tổng")!.views[0]?.showGridLines).toBe(false);
    expect(workbook.getWorksheet("Tổng")!.pageSetup.orientation).toBe(
      "portrait",
    );
  });

  it("retains unsafe exact XLSX quantities as text instead of losing precision", async () => {
    const order =
      createReviewPurchaseOrdersFixture("released_po").purchase_orders[0]!;
    order.lines[0]!.ordered_quantity = "9007199254740992.123455";
    order.lines[1]!.ordered_quantity = "1.000001";
    order.lines[0]!.school_breakdown[0]!.ordered_quantity =
      "9007199254740992.123455";
    order.lines[1]!.school_breakdown[0]!.ordered_quantity = "1.000001";

    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(await createPurchaseOrderXlsx(order));

    expect(workbook.getWorksheet("Tổng")!.getCell("D8").value).toBe(
      "9007199254740993.123456",
    );
    expect(workbook.getWorksheet("Theo trường")!.getCell("F10").value).toBe(
      "9007199254740992.123455",
    );
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

  it("rejects a released export when its immutable supplier snapshot is missing", async () => {
    const order =
      createReviewPurchaseOrdersFixture("released_po").purchase_orders[0]!;
    order.current_revision.supplier_name_snapshot = null;

    expect(() => buildPurchaseOrderExportData(order)).toThrow(
      /supplier snapshot/i,
    );
    await expect(createPurchaseOrderXlsx(order)).rejects.toThrow(
      /supplier snapshot/i,
    );
  });
});
