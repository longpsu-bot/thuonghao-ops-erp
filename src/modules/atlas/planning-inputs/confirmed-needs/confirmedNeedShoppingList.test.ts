import ExcelJS from "exceljs";
import { describe, expect, it } from "vitest";
import { initialConfirmedNeedDraft } from "./confirmedNeedModel";
import { reviewBatch } from "../../../../vnext/atlas/planning-confirmed/confirmedNeedReviewFixtures";
import {
  createConfirmedNeedShoppingListXlsx,
  parseConfirmedNeedShoppingListXlsx,
} from "./confirmedNeedShoppingList";

function fixture() {
  const workbench = reviewBatch();
  const drafts = Object.fromEntries(
    workbench.lines.map((line) => [
      line.confirmed_need_line_id,
      initialConfirmedNeedDraft(line),
    ]),
  );
  return { workbench, drafts };
}

describe("Confirmed Need Shopping List workbook", () => {
  it("matches the approved continuous School-grouped working layout", async () => {
    const { workbench, drafts } = fixture();
    const bytes = await createConfirmedNeedShoppingListXlsx(
      workbench,
      drafts,
      new Date("2026-09-07T03:04:05.000Z"),
    );
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(bytes);

    expect(workbook.worksheets.map((sheet) => sheet.name)).toEqual([
      "2026-09-07",
    ]);
    const sheet = workbook.worksheets[0]!;
    expect(sheet.getRow(3).values).toMatchObject({
      1: "TRƯỜNG",
      2: "THÀNH PHẦN",
      3: "ĐVT",
      4: "SL",
      5: "GHI CHÚ",
    });
    expect(sheet.getColumn(1).width).toBeCloseTo(17.57, 1);
    expect(sheet.getColumn(2).width).toBe(42);
    expect(sheet.getColumn(4).width).toBe(11);
    expect(sheet.getRow(1).height).toBe(36);
    expect(sheet.getRow(3).height).toBe(36);
    expect(sheet.getCell("A3").font).toMatchObject({
      name: "Times New Roman",
      size: 18,
      bold: true,
    });
    expect(sheet.getCell("A3").fill).toMatchObject({
      type: "pattern",
      pattern: "solid",
    });
    expect(sheet.getCell("A1").value).toBe("Thứ Hai (07/09/2026)");
    expect(sheet.getCell("A4").value).toBe("Trường Nguyễn Du");
    expect(sheet.getRow(4).height).toBe(42);
    expect(sheet.getCell("A4").font.bold).toBe(true);
    expect(sheet.getCell("A5").value).toBeNull();
    expect(sheet.getCell("A4").border.top?.style).toBe("thick");
    expect(sheet.getCell("A5").border.top?.style).not.toBe("thick");
    expect(sheet.model.merges).toEqual(["A1:E1"]);
    expect(sheet.getColumn(6).hidden).toBe(true);
    expect(sheet.getColumn(6).width).toBe(1);
    expect(sheet.getCell("D4").protection.locked).toBe(false);
    expect(sheet.getCell("E4").protection.locked).toBe(false);
    expect(sheet.views[0]?.showGridLines).toBe(false);
  });

  it("round-trips edited quantity and note into local drafts without a save API", async () => {
    const { workbench, drafts } = fixture();
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(
      await createConfirmedNeedShoppingListXlsx(workbench, drafts),
    );
    const sheet = workbook.worksheets[0]!;
    sheet.getCell("D4").value = 12.5;
    sheet.getCell("E4").value = "Điều chỉnh theo số suất thực tế";

    const imported = await parseConfirmedNeedShoppingListXlsx(
      new Uint8Array(await workbook.xlsx.writeBuffer()),
      workbench,
      drafts,
    );

    expect(imported.changedLineIds).toEqual(["line-0"]);
    expect(imported.drafts["line-0"]).toMatchObject({
      exact_quantity: "12,5",
      quantity_entered: true,
      reason_code: "OPERATIONAL_QUANTITY_ADJUSTMENT",
      reason_note: "Điều chỉnh theo số suất thực tế",
    });
    expect(imported.drafts["line-1"]).toEqual(drafts["line-1"]);
  });

  it("rejects the whole import when immutable identity is stale or duplicated", async () => {
    const { workbench, drafts } = fixture();
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(
      await createConfirmedNeedShoppingListXlsx(workbench, drafts),
    );
    const sheet = workbook.worksheets[0]!;
    sheet.getCell("F4").value = "batch-stale";
    await expect(
      parseConfirmedNeedShoppingListXlsx(
        new Uint8Array(await workbook.xlsx.writeBuffer()),
        workbench,
        drafts,
      ),
    ).rejects.toThrow(/không còn khớp/i);

    sheet.getCell("F4").value = workbench.confirmed_need_batch_id;
    sheet.getCell("J5").value = sheet.getCell("J4").value;
    await expect(
      parseConfirmedNeedShoppingListXlsx(
        new Uint8Array(await workbook.xlsx.writeBuffer()),
        workbench,
        drafts,
      ),
    ).rejects.toThrow(/trùng dòng/i);
  });

  it("requires a note whenever an imported quantity changes", async () => {
    const { workbench, drafts } = fixture();
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(
      await createConfirmedNeedShoppingListXlsx(workbench, drafts),
    );
    workbook.worksheets[0]!.getCell("D4").value = 12.5;

    await expect(
      parseConfirmedNeedShoppingListXlsx(
        new Uint8Array(await workbook.xlsx.writeBuffer()),
        workbench,
        drafts,
      ),
    ).rejects.toThrow(/ghi chú/i);
  });
});
