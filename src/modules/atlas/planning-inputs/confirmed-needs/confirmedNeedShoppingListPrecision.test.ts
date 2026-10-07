import ExcelJS from "exceljs";
import { describe, it, expect } from "vitest";
import { shoppingFixture } from "./shoppingListTestFixtures";
import { initialConfirmedNeedDraft } from "./confirmedNeedModel";
import {
  createConfirmedNeedShoppingListXlsx,
  parseConfirmedNeedShoppingListXlsx,
  shortestShoppingListQuantity,
} from "./confirmedNeedShoppingList";
import {
  readShoppingListPackage,
  packageText,
  setPackageText,
  writeShoppingListPackage,
} from "./shoppingListPackage";
function fixture(quantity = "1.234567") {
  const f = shoppingFixture();
  const l = f.workbench.lines[0]!;
  l.theoretical_quantity = quantity;
  l.proposed_confirmed_quantity = quantity;
  l.confirmed_quantity_after = quantity;
  l.effective_policy!.planning_step = "0.000001";
  f.drafts[l.confirmed_need_line_id] = initialConfirmedNeedDraft(l);
  return f;
}
async function workbook(quantity = "1.234567") {
  const f = fixture(quantity),
    book = new ExcelJS.Workbook();
  const output = await createConfirmedNeedShoppingListXlsx([f]);
  await book.xlsx.load(output);
  return { ...f, book, output, sheet: book.worksheets[0]! };
}
const bytes = async (book: ExcelJS.Workbook) =>
  new Uint8Array(await book.xlsx.writeBuffer());
describe("AUD-003 V2 precision", () => {
  it.each(["1.234567", "0.000001", "12.345600", "1.230000", "0.000000", "0"])(
    "retains exact authoritative XML and unchanged draft for %s",
    async (quantity) => {
      const f = fixture(quantity),
        before = structuredClone(f.drafts),
        output = await createConfirmedNeedShoppingListXlsx([f]);
      const xml = packageText(
        await readShoppingListPackage(output),
        "xl/worksheets/sheet1.xml",
      );
      expect(xml).toMatch(/<c[^>]*r="D5"[^>]*t="s"/);
      const native = new ExcelJS.Workbook();
      await native.xlsx.load(output);
      expect(native.worksheets[0]!.getCell("D5").value).toBe(
        shortestShoppingListQuantity(quantity),
      );
      expect(native.worksheets[0]!.getCell("O5").value).toBe(quantity);
      const imported = await parseConfirmedNeedShoppingListXlsx(
        output,
        [structuredClone(f.workbench)],
        f.drafts,
      );
      expect(imported.changedLineIds).toEqual([]);
      expect(imported.drafts).toEqual(before);
    },
  );
  it.each([1.234567, "1.234567", "1,234567"])(
    "recognizes unchanged numeric/dot/comma %s",
    async (value) => {
      const f = await workbook();
      f.sheet.getCell("D5").value = value;
      const result = await parseConfirmedNeedShoppingListXlsx(
        await bytes(f.book),
        [f.workbench],
        f.drafts,
      );
      expect(result.changedLineIds).toEqual([]);
      expect(result.drafts).toEqual(f.drafts);
    },
  );
  it("normalizes exponent numeric XML before binary conversion", async () => {
    const f = await workbook(),
      files = await readShoppingListPackage(f.output);
    setPackageText(
      files,
      "xl/worksheets/sheet1.xml",
      packageText(files, "xl/worksheets/sheet1.xml").replace(
        /<c\b([^>]*\br="D5"[^>]*)>[\s\S]*?<\/c>/,
        (_, attrs) =>
          `<c${attrs.replace(/\s*t="[^"]*"/, "")} t="n"><v>1234567e-6</v></c>`,
      ),
    );
    expect(
      (
        await parseConfirmedNeedShoppingListXlsx(
          writeShoppingListPackage(files),
          [f.workbench],
          f.drafts,
        )
      ).changedLineIds,
    ).toEqual([]);
  });
  it.each([0, 1.25, "1,25"])(
    "permits real two-decimal/zero entry without importing a reason %s",
    async (value) => {
      const f = await workbook();
      f.sheet.getCell("D5").value = value;
      f.sheet.getCell("E5").value = "ignored";
      const result = await parseConfirmedNeedShoppingListXlsx(
        await bytes(f.book),
        [f.workbench],
        f.drafts,
      );
      expect(result.changedLineIds).toHaveLength(1);
      expect(result.drafts[result.changedLineIds[0]!]!.reason_code).toBe(
        "PROPOSAL_ACCEPTED",
      );
      expect(result.drafts[result.changedLineIds[0]!]!.reason_note).toBe("");
    },
  );
  it.each(["1.234568", "1.234", "1.2345678", -1, "", "NaN"])(
    "rejects invalid actual entry %j atomically",
    async (value) => {
      const f = await workbook(),
        before = structuredClone(f.drafts);
      f.sheet.getCell("D5").value = value;
      await expect(
        parseConfirmedNeedShoppingListXlsx(
          await bytes(f.book),
          [f.workbench],
          f.drafts,
        ),
      ).rejects.toThrow();
      expect(f.drafts).toEqual(before);
    },
  );
  it("rejects coordinated baseline tampering instead of treating it as authority", async () => {
    const f = await workbook();
    f.sheet.getCell("D5").value = "9.123456";
    f.sheet.getCell("O5").value = "9.123456";
    await expect(
      parseConfirmedNeedShoppingListXlsx(
        await bytes(f.book),
        [f.workbench],
        f.drafts,
      ),
    ).rejects.toThrow();
  });
  it("ignores note-only changes and blocks existing dirty quantities", async () => {
    const f = await workbook();
    f.sheet.getCell("E5").value = "working paper";
    expect(
      (
        await parseConfirmedNeedShoppingListXlsx(
          await bytes(f.book),
          [f.workbench],
          f.drafts,
        )
      ).changedLineIds,
    ).toEqual([]);
    f.drafts[f.workbench.lines[0]!.confirmed_need_line_id]!.exact_quantity =
      "1,25";
    await expect(
      parseConfirmedNeedShoppingListXlsx(f.output, [f.workbench], f.drafts),
    ).rejects.toThrow();
  });
  it("blocks oversized printed quantity clearly while preserving full numeric(20,6) text in imports", async () => {
    const f = await workbook(),
      large = "99999999999999.123456",
      l = f.workbench.lines[0]!;
    l.confirmed_quantity_after = large;
    l.proposed_confirmed_quantity = large;
    f.drafts[l.confirmed_need_line_id] = initialConfirmedNeedDraft(l);
    f.sheet.getCell("D5").value = large;
    f.sheet.getCell("O5").value = large;
    expect(
      (
        await parseConfirmedNeedShoppingListXlsx(
          await bytes(f.book),
          [f.workbench],
          f.drafts,
        )
      ).changedLineIds,
    ).toEqual([]);
    await expect(
      createConfirmedNeedShoppingListXlsx([f]),
    ).rejects.toMatchObject({ code: "PRINT_OVERFLOW" });
  });
});
