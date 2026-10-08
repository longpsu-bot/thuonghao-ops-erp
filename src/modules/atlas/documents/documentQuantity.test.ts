import ExcelJS from "exceljs";
import { describe, expect, it } from "vitest";
import { setExactQuantity } from "./documentPresentation";
import { createReviewPurchaseOrdersFixture } from "../procurement/reviewSchoolCateringProcurementApi";
import {
  buildPurchaseOrderExportData,
  buildPurchaseOrderPdfDefinition,
  createPurchaseOrderXlsx,
} from "../procurement/purchaseOrderExports";
import { createReviewSchoolDispatchDocument } from "../dispatch/reviewSchoolDispatchReleaseApi";
import {
  buildSchoolDispatchExportData,
  buildSchoolDispatchPdfDefinition,
  createGroupedSchoolDispatchXlsx,
} from "../dispatch/schoolDispatchReleaseExports";

function totalMicros(values: string[]) {
  return values.reduce((sum, value) => {
    const [whole, fraction = ""] = value.split(".");
    return sum + BigInt(whole!) * 1_000_000n + BigInt(fraction.padEnd(6, "0"));
  }, 0n);
}

describe("printed exact quantities", () => {
  it.each([
    ["375.000000", "375", false],
    ["39.700000", "39.7", false],
    ["12.340000", "12.34", false],
    ["0.050000", "0.05", false],
    ["100.000000", "100", false],
    ["0.000000", "0", false],
    ["12.345678", "12.345678", true],
    ["12.345000", "12.345", true],
    ["0.000001", "0.000001", true],
    ["99999999999999.120000", "99999999999999.12", false],
    ["9007199254740993.123456", "9007199254740993.123456", true],
  ])(
    "prints %s as %s without losing significant digits",
    async (source, printed, exception) => {
      const workbook = new ExcelJS.Workbook();
      const cell = workbook.addWorksheet("Quantity").getCell("A1");
      setExactQuantity(cell, source);
      const reopened = new ExcelJS.Workbook();
      await reopened.xlsx.load(await workbook.xlsx.writeBuffer());
      const saved = reopened.worksheets[0]!.getCell("A1");
      expect(saved.value).toBe(printed);
      expect(saved.numFmt).toBe("@");
      expect(saved.alignment.horizontal).toBe("right");
      expect(saved.alignment.wrapText).not.toBe(true);
      if (exception)
        expect(JSON.stringify(saved.note)).toContain("PRECISION_EXCEPTION");
      else expect(saved.note).toBeUndefined();
    },
  );

  it.each(["", "1e6", "NaN", "1.2345678", "-1", "1."])(
    "rejects invalid exact source %s",
    (source) => {
      const cell = new ExcelJS.Workbook()
        .addWorksheet("Quantity")
        .getCell("A1");
      expect(() => setExactQuantity(cell, source)).toThrow();
    },
  );

  it("conserves exact PO totals while all three XLSX/PDF views print the same quantities", async () => {
    const order =
      createReviewPurchaseOrdersFixture("released_po").purchase_orders[0]!;
    order.lines[0]!.ordered_quantity = "12.340000";
    order.lines[0]!.school_breakdown[0]!.ordered_quantity = "12.340000";
    order.lines[1]!.ordered_quantity = "0.050000";
    order.lines[1]!.school_breakdown[0]!.ordered_quantity = "0.050000";
    const source = structuredClone(order);
    expect(buildPurchaseOrderExportData(order)).toMatchObject({
      summaryLines: [{ orderedQuantity: "12.390000" }],
      schoolLines: [
        { orderedQuantity: "12.340000" },
        { orderedQuantity: "0.050000" },
      ],
    });
    for (const [mode, column, expected] of [
      ["sum", 5, ["12.39"]],
      ["details_ing", 6, ["12.34", "0.05"]],
      ["details_school", 6, ["12.34", "0.05"]],
    ] as const) {
      const workbook = new ExcelJS.Workbook();
      await workbook.xlsx.load(await createPurchaseOrderXlsx(order, mode));
      const values: string[] = [];
      workbook.worksheets[0]!.eachRow((row) => {
        const cell = row.getCell(column);
        if (cell.numFmt === "@") values.push(cell.text);
      });
      expect(values).toEqual(expected);
      expect(totalMicros(values)).toBe(12_390_000n);
      const sheet = workbook.worksheets[0]!;
      if (mode === "sum") {
        expect(sheet.getColumn(3).width).toBeGreaterThan(36);
        expect(sheet.getColumn(5).width).toBeLessThan(12.71);
      } else {
        expect(sheet.getColumn(4).width).toBeGreaterThan(34);
        expect(
          sheet.getColumn(6).width! + sheet.getColumn(7).width!,
        ).toBeLessThan(24);
      }
      const tables = (
        buildPurchaseOrderPdfDefinition(order, mode).content as {
          table?: { widths: unknown[] };
        }[]
      ).filter((item) => item.table);
      expect(tables[0]!.table!.widths[4]).toBeLessThan(110);
      const pdf = JSON.stringify(buildPurchaseOrderPdfDefinition(order, mode));
      for (const printed of expected)
        expect(pdf).toContain(`"text":"${printed}"`);
      expect(pdf).not.toContain(".340000");
      expect(pdf).not.toContain(".050000");
    }
    expect(order).toEqual(source);
  });

  it("preserves PXK source totals and exact exceptions in grouped XLSX and PDF", async () => {
    const document = createReviewSchoolDispatchDocument("RELEASED");
    document.lines = [
      "375.000000",
      "39.700000",
      "12.345678",
      "99999999999999.120000",
    ].map((quantity, index) => ({
      ...document.lines[0]!,
      ingredient_id: `item-${index}`,
      quantity,
    }));
    const source = structuredClone(document);
    expect(
      buildSchoolDispatchExportData(document).lines.map(
        (line) => line.quantity,
      ),
    ).toEqual([
      "375.000000",
      "39.700000",
      "12.345678",
      "99999999999999.120000",
    ]);
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(await createGroupedSchoolDispatchXlsx([document]));
    const sheet = workbook.worksheets[0]!;
    const expected = ["375", "39.7", "12.345678", "99999999999999.12"];
    expect(totalMicros(source.lines.map((line) => line.quantity))).toBe(
      100_000_000_000_426_165_678n,
    );
    expect(
      totalMicros(
        expected.map((_, index) => sheet.getCell(`D${11 + index}`).text),
      ),
    ).toBe(100_000_000_000_426_165_678n);
    const pdf = JSON.stringify(buildSchoolDispatchPdfDefinition(document));
    expected.forEach((printed, index) => {
      expect(sheet.getCell(`D${11 + index}`).value).toBe(printed);
      expect(pdf).toContain(`"text":"${printed}"`);
    });
    expect(JSON.stringify(sheet.getCell("D13").note)).toContain(
      "PRECISION_EXCEPTION",
    );
    expect(document).toEqual(source);
  });
});
