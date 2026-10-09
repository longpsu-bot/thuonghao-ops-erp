import ExcelJS from "exceljs";
import { describe, expect, it } from "vitest";
import { createReviewPurchaseOrdersFixture } from "../procurement/reviewSchoolCateringProcurementApi";
import {
  buildPurchaseOrderPdfDefinition,
  createPurchaseOrderXlsx,
} from "../procurement/purchaseOrderExports";
import { createReviewSchoolDispatchDocument } from "../dispatch/reviewSchoolDispatchReleaseApi";
import {
  buildSchoolDispatchPdfDefinition,
  createGroupedSchoolDispatchXlsx,
  createSchoolDispatchXlsx,
} from "../dispatch/schoolDispatchReleaseExports";

function visibleText(sheet: ExcelJS.Worksheet) {
  const values: string[] = [];
  sheet.eachRow((row) =>
    row.eachCell((cell) => {
      if (
        !sheet.getColumn(cell.col).hidden &&
        cell.value !== null &&
        (!cell.isMerged || cell.address === cell.master.address)
      )
        values.push(cell.text);
    }),
  );
  return values.join("\n");
}

function metadata(book: ExcelJS.Workbook) {
  const sheet = book.getWorksheet("_ATLAS_META")!;
  expect(sheet).toBeDefined();
  expect(sheet.state).toBe("veryHidden");
  expect(sheet.getCell("B1").text).toBe("ATLAS_OPERATIONAL_DOCUMENT_V1");
  const records: {
    kind: string;
    documentId: string;
    sheet: string;
    row: number;
    data: Record<string, unknown>;
  }[] = [];
  sheet.eachRow((row, index) => {
    if (index > 2)
      records.push({
        kind: row.getCell(1).text,
        documentId: row.getCell(2).text,
        sheet: row.getCell(3).text,
        row: Number(row.getCell(4).value),
        data: JSON.parse(row.getCell(5).text),
      });
  });
  return records;
}

describe("hidden operational document parsing metadata", () => {
  it("reserves the very-hidden metadata name independently of a single School label", async () => {
    const document = createReviewSchoolDispatchDocument("RELEASED");
    document.school_name = "_ATLAS_META";
    const book = new ExcelJS.Workbook();
    await book.xlsx.load(await createSchoolDispatchXlsx(document));
    expect(book.worksheets[0]!.state).toBe("visible");
    expect(book.worksheets[0]!.name).toBe("_ATLAS_META 2");
    expect(metadata(book).filter((r) => r.kind === "DOCUMENT")).toHaveLength(1);
  });
  it.each(["all", "sum", "details_ing", "details_school"] as const)(
    "keeps PO identities and source links hidden in %s, including continuation rows",
    async (mode) => {
      const order =
        createReviewPurchaseOrdersFixture("released_po").purchase_orders[0]!;
      order.lines = [order.lines[0]!];
      order.replaces_purchase_order_id = "internal-predecessor-po";
      order.lines[0]!.supplier_note = "Note ".repeat(400);
      const book = new ExcelJS.Workbook();
      await book.xlsx.load(await createPurchaseOrderXlsx(order, mode));
      const records = metadata(book);
      expect(records.find((r) => r.kind === "DOCUMENT")?.data).toMatchObject({
        document_type: "PO",
        purchase_order_id: order.purchase_order_id,
        supplier_id: order.supplier.supplier_id,
        replaces_purchase_order_id: "internal-predecessor-po",
      });
      for (const sheet of book.worksheets.filter(
        (s) => s.state === "visible",
      )) {
        expect(sheet.pageSetup.printArea).toMatch(/^A1:F/);
        for (let col = 7; col <= 14; col++)
          expect(sheet.getColumn(col).hidden).toBe(true);
        expect(visibleText(sheet)).not.toContain("internal-predecessor-po");
        expect(visibleText(sheet)).not.toContain(
          order.lines[0]!.ingredient.ingredient_id,
        );
        let items = 0;
        let continuations = 0;
        sheet.eachRow((row) => {
          const kind = row.getCell(14).text;
          if (kind !== "ITEM" && kind !== "CONTINUATION") return;
          if (kind === "ITEM") items++;
          else continuations++;
          expect(row.getCell(7).text).toBe(order.purchase_order_id);
          expect(row.getCell(8).text).toBe(
            order.lines[0]!.ingredient.ingredient_id,
          );
          expect(row.getCell(9).text).toBe(order.lines[0]!.unit.unit_id);
          expect(row.getCell(13).text).toMatch(/^\d+\.\d{6}$/);
          expect(
            records.some(
              (r) =>
                r.kind === "ROW_SOURCE" &&
                r.sheet === sheet.name &&
                r.row === row.number &&
                r.data.purchase_order_line_revision_id ===
                  order.lines[0]!.purchase_order_line_revision_id,
            ),
          ).toBe(true);
          if (kind === "CONTINUATION") expect(row.getCell(5).text).toBe("");
        });
        expect(items).toBeGreaterThan(0);
        expect(continuations).toBeGreaterThan(0);
      }
      expect(
        JSON.stringify(buildPurchaseOrderPdfDefinition(order, mode)),
      ).not.toContain("internal-predecessor-po");
    },
  );

  it("retains every source of an aggregated PO row", async () => {
    const order =
      createReviewPurchaseOrdersFixture("released_po").purchase_orders[0]!;
    order.lines = [order.lines[0]!];
    const second = structuredClone(order.lines[0]!);
    second.purchase_order_line_revision_id = "another-line-revision";
    second.purchase_order_line_id = "another-line";
    order.lines.push(second);
    const book = new ExcelJS.Workbook();
    await book.xlsx.load(await createPurchaseOrderXlsx(order, "sum"));
    const sources = metadata(book).filter(
      (r) => r.kind === "ROW_SOURCE" && r.row === 11,
    );
    expect(
      sources.map((r) => r.data.purchase_order_line_revision_id).sort(),
    ).toEqual(
      [
        order.lines[0]!.purchase_order_line_revision_id,
        "another-line-revision",
      ].sort(),
    );
    expect(book.worksheets[0]!.getCell("M11").text).toBe("120.000000");
  });

  it("keeps PXK batch documents and exact source coverage associated with their rows", async () => {
    const first = createReviewSchoolDispatchDocument("RELEASED");
    first.predecessor_release_id = "internal-predecessor-pxk";
    first.lines[0]!.school_dispatch_release_line_id = "dispatch-line";
    first.lines[0]!.quantity = "0.000001";
    const second = structuredClone(first);
    second.school_dispatch_release_id = "release-second";
    second.school_name = "_ATLAS_META";
    delete second.lines[0]!.school_dispatch_release_line_id;
    const book = new ExcelJS.Workbook();
    await book.xlsx.load(
      await createGroupedSchoolDispatchXlsx([second, first]),
    );
    const records = metadata(book);
    expect(records.filter((r) => r.kind === "DOCUMENT")).toHaveLength(2);
    for (const sheet of book.worksheets.filter((s) => s.state === "visible")) {
      expect(sheet.pageSetup.printArea).toMatch(/^A1:H/);
      expect(visibleText(sheet)).not.toContain("internal-predecessor-pxk");
      for (let col = 9; col <= 16; col++)
        expect(sheet.getColumn(col).hidden).toBe(true);
      expect(sheet.getCell("J11").text).toBe(first.lines[0]!.ingredient_id);
      expect(sheet.getCell("O11").text).toBe("0.000001");
      const sources = records.filter(
        (r) =>
          r.kind === "ROW_SOURCE" && r.sheet === sheet.name && r.row === 11,
      );
      expect(sources).toHaveLength(first.lines[0]!.sources.length || 1);
      if (first.lines[0]!.sources.length)
        expect(sources[0]!.data).toMatchObject(first.lines[0]!.sources[0]!);
      expect(sources[0]!.data.school_dispatch_release_line_id).toBe(
        sheet.getCell("I11").text === first.school_dispatch_release_id
          ? "dispatch-line"
          : null,
      );
    }
    expect(
      JSON.stringify(buildSchoolDispatchPdfDefinition(first)),
    ).not.toContain("internal-predecessor-pxk");
  });
});
