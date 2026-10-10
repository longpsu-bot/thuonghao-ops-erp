import ExcelJS from "exceljs";
import { describe, expect, it } from "vitest";
import { createReviewPurchaseOrdersFixture } from "../procurement/reviewSchoolCateringProcurementApi";
import {
  buildPurchaseOrderPdfDefinition,
  buildPurchaseOrderExportData,
  createPurchaseOrderXlsx,
} from "../procurement/purchaseOrderExports";
import { createReviewSchoolDispatchDocument } from "../dispatch/reviewSchoolDispatchReleaseApi";
import {
  createGroupedSchoolDispatchXlsx,
  createSchoolDispatchXlsx,
  buildSchoolDispatchPdfDefinition,
} from "../dispatch/schoolDispatchReleaseExports";
import { safeWorksheetName, documentFilePart } from "./documentPresentation";

async function book(bytes: ExcelJS.Buffer) {
  const workbook = new ExcelJS.Workbook();
  await workbook.xlsx.load(bytes);
  return workbook;
}

describe("Atlas document presentation boundaries", () => {
  it("renders the same captured PO order and safe filename fragments for fixed facts", () => {
    const order =
      createReviewPurchaseOrdersFixture("released_po").purchase_orders[0]!;
    const first = buildPurchaseOrderExportData(order);
    order.lines.reverse();
    expect(buildPurchaseOrderExportData(order)).toEqual(first);
    expect(documentFilePart("Trường / Nguyễn Đình Chiểu:*?")).toBe(
      "Truong-Nguyen-dinh-Chieu",
    );
    expect(documentFilePart("/*?:")).toBe("Atlas");
    expect(documentFilePart("A".repeat(200))).toHaveLength(100);
  });

  it.each(["not-ready", "export-denied", "incomplete-breakdown"])(
    "retains released PO guards for %s",
    async (condition) => {
      const order =
        createReviewPurchaseOrdersFixture("released_po").purchase_orders[0]!;
      if (condition === "not-ready") order.export_ready = false;
      if (condition === "export-denied") order.allowed_actions.export = false;
      if (condition === "incomplete-breakdown")
        order.lines[0]!.school_breakdown = [];
      expect(() => buildPurchaseOrderPdfDefinition(order)).toThrow();
      await expect(createPurchaseOrderXlsx(order)).rejects.toThrow();
    },
  );
  it("keeps Excel worksheet edge apostrophes valid after truncation", () => {
    const workbook = new ExcelJS.Workbook();
    expect(() =>
      workbook.addWorksheet(safeWorksheetName("A".repeat(30) + "'School")),
    ).not.toThrow();
  });

  it("retains every character of a page-tall note in bounded continuation rows without duplicating quantities", async () => {
    const order =
      createReviewPurchaseOrdersFixture("released_po").purchase_orders[0]!;
    order.lines[0]!.supplier_note = "BEGIN" + "A\n".repeat(240) + "END";
    const workbook = await book(await createPurchaseOrderXlsx(order));
    for (const name of [
      "02-09-2026 - Tổng",
      "02-09-2026 - Theo trường",
      "02-09-2026 - Theo hàng",
    ] as const) {
      const sheet = workbook.getWorksheet(name)!;
      const chunks: string[] = [],
        quantities: string[] = [];
      sheet.eachRow((row, n) => {
        if (n < 11) return;
        const noteCell = row.getCell(6);
        const note = noteCell.value;
        if (!noteCell.isMerged && typeof note === "string") {
          chunks.push(note);
          expect(row.height).toBeLessThanOrEqual(180);
        }
        const quantity = row.getCell(5).value;
        if (
          typeof quantity === "string" &&
          /^\d+(?:\.\d{1,6})?$/.test(quantity)
        )
          quantities.push(quantity);
      });
      expect(chunks.join("")).toBe(order.lines[0]!.supplier_note);
      expect(quantities).toEqual(["60", "40"]);
    }
    for (const mode of ["sum", "details_school", "details_ing"] as const) {
      const pdf = buildPurchaseOrderPdfDefinition(order, mode);
      const tables = (
        pdf.content as { table?: { body: unknown[][] } }[]
      ).filter((item) => item.table);
      const notes: string[] = [],
        quantities: string[] = [];
      for (const item of tables) {
        for (const row of item.table!.body.slice(mode === "sum" ? 1 : 2)) {
          const note = row.at(-1);
          if (typeof note === "string") notes.push(note);
          const quantity = (row[3] as { text?: string }).text;
          if (quantity) quantities.push(quantity);
        }
      }
      expect(notes.join("")).toBe(order.lines[0]!.supplier_note);
      expect(quantities).toEqual(["60", "40"]);
    }
  });
  it("keeps all released quantities as exact text and labels every PO sheet", async () => {
    const order =
      createReviewPurchaseOrdersFixture("released_po").purchase_orders[0]!;
    order.status = "SUPERSEDED";
    order.lines[0]!.ordered_quantity = "1.234567";
    order.lines[0]!.school_breakdown[0]!.ordered_quantity = "1.234567";
    const workbook = await book(await createPurchaseOrderXlsx(order));
    for (const sheet of workbook.worksheets.filter(
      (s) => s.state === "visible",
    )) {
      expect(JSON.stringify(sheet.getSheetValues())).toContain(
        order.document_number,
      );
      expect(sheet.pageSetup.printTitlesRow).toMatch(/^1:/);
      expect(sheet.headerFooter.oddFooter).toContain("ĐÃ ĐƯỢC THAY THẾ");
      expect(sheet.headerFooter.oddFooter).toContain("&P / &N");
      expect(sheet.pageSetup.printArea).toMatch(/^A1:/);
    }
    expect(
      workbook.getWorksheet("02-09-2026 - Theo trường")!.getCell("E11").value,
    ).toBe("1.234567");
    expect(
      workbook.getWorksheet("02-09-2026 - Theo trường")!.getCell("E11").numFmt,
    ).toBe("@");
    const pdf = buildPurchaseOrderPdfDefinition(order);
    expect(JSON.stringify(pdf.content)).not.toContain("ĐÃ ĐƯỢC THAY THẾ");
    expect(pdf.footer).toBeTypeOf("function");
  });

  it("never combines equally named Schools/locations or Ingredients with distinct IDs", async () => {
    const order =
      createReviewPurchaseOrdersFixture("released_po").purchase_orders[0]!;
    const [a, b] = order.lines;
    b!.school_breakdown[0]!.school_name = a!.school_breakdown[0]!.school_name;
    b!.school_breakdown[0]!.school_display_order =
      a!.school_breakdown[0]!.school_display_order;
    b!.ingredient.ingredient_id = "different-ingredient-id";
    const workbook = await book(await createPurchaseOrderXlsx(order));
    expect(
      workbook.getWorksheet("02-09-2026 - Theo trường")!.getCell("A10").value,
    ).toContain(a!.school_breakdown[0]!.school_name);
    for (const name of ["02-09-2026 - Theo trường", "02-09-2026 - Theo hàng"]) {
      const sheet = workbook.getWorksheet(name)!;
      expect(sheet.model.merges).toContain("A10:F10");
      expect(sheet.model.merges).toContain("A13:F13");
      expect(sheet.getCell("E11").value).toBe("60");
      expect(sheet.getCell("E14").value).toBe("40");
    }
    expect(
      workbook.getWorksheet("02-09-2026 - Theo hàng")!.getCell("A10").value,
    ).toBe("Gạo thơm (kg)");
    expect(
      workbook.getWorksheet("02-09-2026 - Theo hàng")!.getCell("A13").value,
    ).toBe("Gạo thơm (kg)");
  });

  it("preserves PXK destination, status, exact quantity and repeatable headers", async () => {
    const document = createReviewSchoolDispatchDocument("SUPERSEDED");
    document.lines[0]!.quantity = "99999999999999.123456";
    const workbook = await book(await createSchoolDispatchXlsx(document));
    const sheet = workbook.worksheets[0]!;
    expect(sheet.getCell("D11").value).toBe("99999999999999.123456");
    expect(JSON.stringify(sheet.getSheetValues())).toContain(
      document.delivery_location_name,
    );
    expect(JSON.stringify(sheet.getSheetValues())).toContain(
      "ĐÃ ĐƯỢC THAY THẾ",
    );
    expect(sheet.pageSetup.printTitlesRow).toBe("1:10");
    expect(sheet.headerFooter.oddFooter).toContain(document.document_number);
    const pdf = buildSchoolDispatchPdfDefinition(document);
    expect(pdf.footer).toBeTypeOf("function");
    expect(JSON.stringify(pdf)).toContain("ĐÃ ĐƯỢC THAY THẾ");
  });

  it("allocates unique case-insensitive Excel names without merging released documents", async () => {
    const a = createReviewSchoolDispatchDocument("RELEASED");
    a.school_name = "SCHOOL";
    const b = structuredClone(a);
    b.school_name = "school";
    b.document_number = "PXK-B";
    b.school_dispatch_release_id = "second-release";
    const workbook = await book(await createGroupedSchoolDispatchXlsx([b, a]));
    expect(
      new Set(
        workbook.worksheets
          .filter((s) => s.state === "visible")
          .map((s) => s.name.toLowerCase()),
      ).size,
    ).toBe(2);
  });

  it("wraps long snapshot labels and bounds multipage geometry without cutting rows", async () => {
    const document = createReviewSchoolDispatchDocument("RELEASED");
    document.delivery_address =
      "Địa chỉ giao hàng rất dài, khu vực trường học. ".repeat(4);
    document.lines = Array.from({ length: 60 }, (_, i) => ({
      ...document.lines[0]!,
      ingredient_id: `ingredient-${i}`,
      ingredient_name: "Nguyên liệu có tên dài cần xuống dòng rõ ràng",
      quantity: "1.234567",
    }));
    const workbook = await book(await createSchoolDispatchXlsx(document));
    const sheet = workbook.worksheets[0]!;
    expect(sheet.getCell("B11").alignment.wrapText).toBe(true);
    expect(sheet.getRow(11).height).toBeGreaterThan(30);
    expect(sheet.getRow(7).height).toBeGreaterThan(30);
    const signature = sheet.getRow(sheet.rowCount - 6);
    expect(signature.getCell(1).value).toContain("Người nhận hàng");
    expect(signature.getCell(3).value).toContain("Người giao hàng");
    expect(signature.getCell(6).value).toContain("Người lập phiếu");
    expect(signature.height).toBe(24);
    for (const column of [1, 3, 6])
      expect(sheet.getCell(signature.number + 1, column).value).toBe(
        "(Ký, ghi họ tên)",
      );
    expect(sheet.getRow(signature.number + 1).height).toBe(24);
    for (let row = signature.number + 2; row <= sheet.rowCount; row++)
      for (let column = 1; column <= 7; column++)
        expect(sheet.getCell(row, column).value).toBeNull();
  });
});
