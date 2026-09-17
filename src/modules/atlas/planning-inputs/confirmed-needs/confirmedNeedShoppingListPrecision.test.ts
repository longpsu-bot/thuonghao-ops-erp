import ExcelJS from "exceljs";
import { describe, expect, it } from "vitest";
import { initialConfirmedNeedDraft } from "./confirmedNeedModel";
import { reviewBatch } from "../../../../vnext/atlas/planning-confirmed/confirmedNeedReviewFixtures";
import {
  createConfirmedNeedShoppingListXlsx,
  parseConfirmedNeedShoppingListXlsx,
} from "./confirmedNeedShoppingList";
function fixture(quantity = "1.234567") {
  const workbench = reviewBatch();
  const line = workbench.lines[0]!;
  line.theoretical_quantity = quantity;
  line.proposed_confirmed_quantity = quantity;
  line.confirmed_quantity_after = quantity;
  if (!line.effective_policy) throw new Error("Missing fixture policy");
  line.effective_policy.planning_step = "0.000001";
  const drafts = Object.fromEntries(
    workbench.lines.map((line) => [
      line.confirmed_need_line_id,
      initialConfirmedNeedDraft(line),
    ]),
  );
  return { workbench, drafts };
}
async function workbook(quantity = "1.234567") {
  const f = fixture(quantity);
  const book = new ExcelJS.Workbook();
  await book.xlsx.load(
    await createConfirmedNeedShoppingListXlsx(f.workbench, f.drafts),
  );
  return { ...f, book, sheet: book.worksheets[0]! };
}
describe("AUD-003 — exact Shopping List round trip", () => {
  it.each([
    "1.234567",
    "0.000001",
    "12.345600",
    "1.230000",
    "0.000000",
    "99999999999999.123456",
  ])(
    "preserves untouched authoritative quantity %s in exact export bytes",
    async (quantity) => {
      const { workbench, drafts } = fixture(quantity);
      const before = structuredClone(drafts);
      const bytes = await createConfirmedNeedShoppingListXlsx(
        workbench,
        drafts,
      );
      const result = await parseConfirmedNeedShoppingListXlsx(
        new Uint8Array(bytes),
        workbench,
        drafts,
      );
      expect(result.changedLineIds).toEqual([]);
      expect(result.drafts).toEqual(drafts);
      expect(drafts).toEqual(before);
      expect(result.drafts["line-0"].exact_quantity).toBe(quantity);
      expect(result.drafts["line-0"].quantity_entered).toBeUndefined();
    },
  );
  it("shows all retained fractional digits without changing the frozen layout or identities", async () => {
    const { sheet } = await workbook();
    expect(sheet.getCell("D4").value).toBe(1.234567);
    expect(sheet.getCell("D4").numFmt).toBe("0.######");
    expect(sheet.getColumn(4).width).toBe(11);
    expect(sheet.getColumn(6).hidden).toBe(true);
    expect(sheet.getCell("T4").value).toBe("1.234567");
  });
  it.each([1.234567, "1.234567", "1,234567"])(
    "recognizes exact numeric/text/comma equality %s without marking entry",
    async (value) => {
      const { book, sheet, workbench, drafts } = await workbook();
      sheet.getCell("D4").value = value;
      const result = await parseConfirmedNeedShoppingListXlsx(
        new Uint8Array(await book.xlsx.writeBuffer()),
        workbench,
        drafts,
      );
      expect(result.changedLineIds).toEqual([]);
      expect(result.drafts["line-0"]).toEqual(drafts["line-0"]);
    },
  );
  it("allows a note-only edit without treating unchanged authoritative precision as new entry", async () => {
    const { book, sheet, workbench, drafts } = await workbook();
    sheet.getCell("E4").value = "Ghi chú giao hàng";
    const result = await parseConfirmedNeedShoppingListXlsx(
      new Uint8Array(await book.xlsx.writeBuffer()),
      workbench,
      drafts,
    );
    expect(result.changedLineIds).toEqual(["line-0"]);
    expect(result.drafts["line-0"]).toEqual({
      ...drafts["line-0"],
      reason_note: "Ghi chú giao hàng",
    });
  });
  it.each([0, 1.25, "1,25"])(
    "allows a genuine two-decimal/zero edit with a note: %s",
    async (value) => {
      const { book, sheet, workbench, drafts } = await workbook();
      sheet.getCell("D4").value = value;
      sheet.getCell("E4").value = "Điều chỉnh";
      const result = await parseConfirmedNeedShoppingListXlsx(
        new Uint8Array(await book.xlsx.writeBuffer()),
        workbench,
        drafts,
      );
      expect(result.changedLineIds).toEqual(["line-0"]);
      expect(result.drafts["line-0"]).toMatchObject({
        exact_quantity: value === 0 ? "0" : "1,25",
        quantity_entered: true,
        reason_code: "OPERATIONAL_QUANTITY_ADJUSTMENT",
        reason_note: "Điều chỉnh",
      });
    },
  );
  it.each(["1.234568", "1.234", "1.2345678", -1, "", "NaN"])(
    "continues rejecting invalid or over-precision edits: %s",
    async (value) => {
      const { book, sheet, workbench, drafts } = await workbook();
      const before = structuredClone(drafts);
      sheet.getCell("D4").value = value;
      sheet.getCell("E4").value = "Có lý do";
      await expect(
        parseConfirmedNeedShoppingListXlsx(
          new Uint8Array(await book.xlsx.writeBuffer()),
          workbench,
          drafts,
        ),
      ).rejects.toThrow(/Số lượng/);
      expect(drafts).toEqual(before);
    },
  );
  it("still requires a note for genuine edits from a six-decimal baseline", async () => {
    const { book, sheet, workbench, drafts } = await workbook();
    sheet.getCell("D4").value = 1.25;
    await expect(
      parseConfirmedNeedShoppingListXlsx(
        new Uint8Array(await book.xlsx.writeBuffer()),
        workbench,
        drafts,
      ),
    ).rejects.toThrow(/ghi chú/);
  });
  it("checks immutable identity before the precision exception", async () => {
    const { book, sheet, workbench, drafts } = await workbook();
    sheet.getCell("F4").value = "stale";
    sheet.getCell("D4").value = "bad quantity";
    await expect(
      parseConfirmedNeedShoppingListXlsx(
        new Uint8Array(await book.xlsx.writeBuffer()),
        workbench,
        drafts,
      ),
    ).rejects.toThrow(/không còn khớp/);
  });
  it("rejects invalid exported quantity metadata instead of using it as a baseline", async () => {
    const { book, sheet, workbench, drafts } = await workbook();
    sheet.getCell("T4").value = "not-a-quantity";
    sheet.getCell("D4").value = 1.25;
    sheet.getCell("E4").value = "Điều chỉnh";
    await expect(
      parseConfirmedNeedShoppingListXlsx(
        new Uint8Array(await book.xlsx.writeBuffer()),
        workbench,
        drafts,
      ),
    ).rejects.toThrow(/không còn khớp|siêu dữ liệu/);
  });
  it("cannot introduce a six-decimal edit by changing visible quantity plus hidden baseline", async () => {
    const { book, sheet, workbench, drafts } = await workbook();
    sheet.getCell("D4").value = "9.123456";
    sheet.getCell("T4").value = "9.123456";
    const result = await parseConfirmedNeedShoppingListXlsx(
      new Uint8Array(await book.xlsx.writeBuffer()),
      workbench,
      drafts,
    );
    expect(result.drafts["line-0"]).toEqual(drafts["line-0"]);
    expect(result.changedLineIds).toEqual([]);
  });
  it("preserves a current local draft after an untouched older export without phantom quantity changes", async () => {
    const { workbench, drafts } = fixture();
    const bytes = await createConfirmedNeedShoppingListXlsx(workbench, drafts);
    drafts["line-0"].exact_quantity = "1,25";
    drafts["line-0"].quantity_entered = true;
    const result = await parseConfirmedNeedShoppingListXlsx(
      new Uint8Array(bytes),
      workbench,
      drafts,
    );
    expect(result.drafts["line-0"]).toEqual(drafts["line-0"]);
    expect(result.changedLineIds).toEqual([]);
  });
  it("rejects missing lines atomically even when the retained quantities are valid", async () => {
    const { book, sheet, workbench, drafts } = await workbook();
    const before = structuredClone(drafts);
    sheet.spliceRows(4, 1);
    await expect(
      parseConfirmedNeedShoppingListXlsx(
        new Uint8Array(await book.xlsx.writeBuffer()),
        workbench,
        drafts,
      ),
    ).rejects.toThrow(/thiếu dòng/);
    expect(drafts).toEqual(before);
  });
});
