import ExcelJS from "exceljs";
import { describe, expect, it } from "vitest";
import { createReviewPurchaseOrdersFixture } from "./reviewSchoolCateringProcurementApi";
import {
  buildPurchaseOrderPdfDefinition,
  createPurchaseOrderXlsx,
  createPurchaseOrderPdf,
} from "./purchaseOrderExports";

const fixture = () =>
  createReviewPurchaseOrdersFixture("released_po").purchase_orders[0]!;
async function load(bytes: ExcelJS.Buffer) {
  const workbook = new ExcelJS.Workbook();
  await workbook.xlsx.load(bytes);
  return workbook;
}
describe("Owner V1 PO presentation revision", () => {
  it("keeps ingredient bands in the summary item sequence even when School order encounters another item first", async () => {
    const order = fixture();
    order.lines[0]!.ingredient = {
      ingredient_id: "z-last",
      ingredient_name: "Ức gà",
    };
    order.lines[1]!.ingredient = {
      ingredient_id: "a-first",
      ingredient_name: "Đầu cánh gà",
    };
    order.lines[0]!.ingredient_name_snapshot = "Ức gà";
    order.lines[1]!.ingredient_name_snapshot = "Đầu cánh gà";
    const workbook = await load(await createPurchaseOrderXlsx(order));
    const item = workbook
      .getWorksheet("02-09-2026 - Tổng")!
      .getCell("C11").text;
    expect(item).toBe("Đầu cánh gà");
    expect(
      workbook.getWorksheet("02-09-2026 - Theo hàng")!.getCell("A10").text,
    ).toContain(item);
    expect(
      workbook.getWorksheet("02-09-2026 - Theo trường")!.getCell("C11").text,
    ).toBe("Ức gà");
  });
  it("keeps plain summary headers after PDF rendering and allows the complete large quantity to print", async () => {
    const order = fixture();
    order.lines[0]!.ordered_quantity = "99999999999999.123456";
    order.lines[0]!.school_breakdown[0]!.ordered_quantity =
      order.lines[0]!.ordered_quantity;
    await createPurchaseOrderPdf(order, "sum");
    const workbook = await load(await createPurchaseOrderXlsx(order, "sum"));
    const sheet = workbook.worksheets[0]!;
    expect(sheet.getCell("A10").value).toBe("STT");
    expect(sheet.getCell("F10").value).toBe("Ghi chú");
    expect(sheet.pageSetup.orientation).toBe("landscape");
    expect(buildPurchaseOrderPdfDefinition(order, "sum").pageOrientation).toBe(
      "landscape",
    );
    expect(sheet.getColumn(5).width).toBeGreaterThanOrEqual(
      "99999999999999.123456".length * 1.34 + 2,
    );
  });
  it("keeps V1 all-mode order while hiding item codes from the printed summary", async () => {
    const workbook = await load(await createPurchaseOrderXlsx(fixture()));
    expect(workbook.getWorksheet("_ATLAS_META")?.state).toBe("veryHidden");
    expect(
      workbook.worksheets
        .filter((sheet) => sheet.state === "visible")
        .map((sheet) => sheet.name),
    ).toEqual([
      "02-09-2026 - Theo hàng",
      "02-09-2026 - Theo trường",
      "02-09-2026 - Tổng",
    ]);
    const summary = workbook.worksheets[2]!;
    expect(summary.getColumn(2).hidden).toBe(true);
    expect(
      (summary.getRow(10).values as unknown[])
        .slice(1, 7)
        .filter((_, index) => !summary.getColumn(index + 1).hidden),
    ).toEqual(["STT", "Tên hàng", "Đơn vị", "Số lượng", "Ghi chú"]);
    expect(summary.getCell("C1").text).toContain("THƯỢNG HẢO");
    expect(summary.getCell("C2").text).toContain("96/3");
    expect(summary.getCell("A4").text).toBe("PHIẾU ĐẶT HÀNG");
    expect(summary.getCell("A7").text).toBe("Ngày dùng:");
    expect(summary.getCell("A8").text).toContain("Mã NCC:");
    expect(summary.getCell("A8").text).toBe("Mã NCC: 53");
    expect(summary.getCell("A9").text).toBe("");
    expect(summary.getCell("B11").text).toBe("1082");
    expect(summary.getCell("E11").value).toBe("100");
    expect(summary.getCell("E11").numFmt).toBe("@");
    expect(summary.pageSetup.printTitlesRow).toBe("1:10");
    expect(JSON.stringify(summary.getSheetValues())).not.toContain("Ngày giao");
  });
  it.each([
    ["all", ["Theo hàng", "Theo trường", "Tổng"]],
    ["details_ing", ["Theo hàng"]],
    ["details_school", ["Theo trường"]],
    ["sum", ["Tổng"]],
  ] as const)("supports the V1 %s selection mode", async (mode, suffixes) => {
    const workbook = await load(await createPurchaseOrderXlsx(fixture(), mode));
    expect(workbook.getWorksheet("_ATLAS_META")?.state).toBe("veryHidden");
    expect(
      workbook.worksheets
        .filter((sheet) => sheet.state === "visible")
        .map((sheet) => sheet.name),
    ).toEqual(suffixes.map((name) => `02-09-2026 - ${name}`));
  });
  it("uses compact group bands and numbered rows in both directions, with all School identities kept distinct", async () => {
    const order = fixture();
    order.lines[1]!.school_breakdown[0]!.school_name =
      order.lines[0]!.school_breakdown[0]!.school_name;
    const workbook = await load(await createPurchaseOrderXlsx(order));
    for (const suffix of ["Theo hàng", "Theo trường"]) {
      const sheet = workbook.getWorksheet(`02-09-2026 - ${suffix}`)!;
      expect(sheet.columns.filter((column) => !column.hidden)).toHaveLength(5);
      expect(sheet.columns.filter((column) => column.hidden)).toHaveLength(9);
      expect(sheet.model.merges).toContain("A10:F10");
      expect(sheet.getCell("A11").value).toBe(1);
      expect(sheet.getCell("B11").text).toBe("1082");
      expect(sheet.getCell("E11").value).toBe("60");
      expect(sheet.pageSetup.orientation).toBe("portrait");
    }
    expect(
      workbook.getWorksheet("02-09-2026 - Theo trường")!.getCell("A13").text,
    ).toContain(order.lines[0]!.school_breakdown[0]!.school_name);
  });
  it("uses Ngày dùng and supplier code in PDF while keeping item code hidden", () => {
    const definition = buildPurchaseOrderPdfDefinition(fixture());
    const text = JSON.stringify(definition);
    expect(text).toContain("Ngày dùng");
    expect(text).not.toContain("Ngày giao");
    expect(text).toContain("Mã NCC: 53");
    expect(text).not.toContain("1082");
    expect(text).not.toContain("chưa lưu mã");
    expect(text).not.toContain("Mã hàng");
    const tables = (
      definition.content as { table?: { body: unknown[][] } }[]
    ).filter((item) => item.table);
    expect(
      tables.some(
        (item) =>
          JSON.stringify(
            item.table!.body[0]!.map((cell) =>
              typeof cell === "string" ? cell : (cell as { text: string }).text,
            ),
          ) ===
          JSON.stringify([
            "STT",
            "Tên hàng",
            "Đơn vị",
            "Số lượng",
            "Ghi chú",
          ]),
      ),
    ).toBe(true);
  });
});
