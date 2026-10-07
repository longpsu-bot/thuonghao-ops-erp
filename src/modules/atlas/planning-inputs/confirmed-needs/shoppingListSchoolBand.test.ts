import ExcelJS from "exceljs";
import { expect, it } from "vitest";
import { shoppingFixture } from "./shoppingListTestFixtures";
import { initialConfirmedNeedDraft } from "./confirmedNeedModel";
import { shoppingListContract } from "./shoppingListContract";
import {
  shoppingListColumnUsableWidths,
  shoppingListTextWidth,
} from "./shoppingListLayout";
import {
  readShoppingListEnvelope,
  validateShoppingListEnvelope,
} from "./shoppingListImport";
import {
  createConfirmedNeedShoppingListXlsx,
  parseConfirmedNeedShoppingListXlsx,
} from "./confirmedNeedShoppingList";

it("exports the Owner-selected A+ density and Unit/Note allocation by default", async () => {
  const f = shoppingFixture();
  const book = new ExcelJS.Workbook();
  await book.xlsx.load(await createConfirmedNeedShoppingListXlsx([f]));
  const sheet = book.worksheets[0]!;
  expect(book.getWorksheet("_ATLAS_META")!.getCell("B7").value).toBe("A+");
  expect([1, 2, 3, 4, 5].map((c) => sheet.getColumn(c).width)).toEqual([
    14, 31, 10, 16, 23,
  ]);
  expect(sheet.getRow(4).height).toBe(28);
  expect(sheet.getRow(5).height).toBe(28);
  expect(shoppingListColumnUsableWidths()[2]).toBe(54.5);
  expect(shoppingListColumnUsableWidths()[4]).toBe(132.5);
});

it("exports locked School bands and complete flat DATA_LINE records in V2", async () => {
  const f = shoppingFixture();
  const bytes = await createConfirmedNeedShoppingListXlsx([f]);
  const book = new ExcelJS.Workbook();
  await book.xlsx.load(bytes);
  const sheet = book.worksheets[0]!;
  expect(sheet.views[0]).toMatchObject({ state: "frozen", ySplit: 3 });
  expect(sheet.pageSetup.printTitlesRow).toBe("1:3");
  expect(book.getWorksheet("_ATLAS_META")!.getCell("B2").value).toBe(
    "ATLAS_SHOPPING_LIST_V2",
  );
  expect(sheet.getCell("P4").value).toBe("SCHOOL_BAND");
  expect(sheet.getCell("G4").value).toBeNull();
  expect(sheet.getCell("A4").value).toBe(f.workbench.lines[0]!.school.name);
  expect(sheet.getCell("P5").value).toBe("DATA_LINE");
  expect(sheet.getCell("A5").value).toBeNull();
  expect(sheet.getCell("K5").value).toBe(f.workbench.lines[0]!.school.id);
  expect(sheet.getCell("Q5").value).toBe(f.workbench.lines[0]!.school.name);
  expect(sheet.getCell("D4").protection?.locked).not.toBe(false);
  expect(sheet.getCell("D5").protection.locked).toBe(false);
  expect(sheet.getColumn(17).hidden).toBe(true);
  expect(sheet.getCell("A4").fill).toMatchObject({
    type: "pattern",
    fgColor: { argb: "FFD9D9D9" },
  });
  expect(sheet.getCell("A4").font.bold).toBe(true);
  expect(sheet.getCell("B4").border.left?.style).toBeUndefined();
  expect(sheet.getCell("B4").border.top?.style).toBe("medium");
  expect(sheet.getCell("A4").isMerged).toBe(false);
  expect(
    (await parseConfirmedNeedShoppingListXlsx(bytes, [f.workbench], f.drafts))
      .changedLineIds,
  ).toEqual([]);
});

it.each([
  "moved",
  "missing-band",
  "duplicate-band",
  "missing-line",
  "fake-line",
  "blank-kind",
])("fails closed for %s", async (mode) => {
  const f = shoppingFixture();
  const envelope = await readShoppingListEnvelope(
    await createConfirmedNeedShoppingListXlsx([f]),
  );
  const rows = envelope.sheets.get("2026-09-07")!;
  if (mode === "moved") [rows[1], rows[5]] = [rows[5]!, rows[1]!];
  if (mode === "missing-band") rows.splice(0, 1);
  if (mode === "duplicate-band") rows.splice(1, 0, structuredClone(rows[0]!));
  if (mode === "missing-line") rows.splice(1, 1);
  if (mode === "fake-line") rows.splice(1, 0, structuredClone(rows[1]!));
  if (mode === "blank-kind") rows[1]![15]!.text = "";
  const before = structuredClone(f.drafts);
  expect(() =>
    validateShoppingListEnvelope(envelope, [f.workbench], f.drafts),
  ).toThrow();
  expect(f.drafts).toEqual(before);
});

it("uses A4-bounded A+ geometry, real Units and separate continuation bands", async () => {
  const f = shoppingFixture();
  const template = f.workbench.lines[0]!;
  const names = ["kg", "Miếng", "Quả", "Gói", "Cốc", "Cái", "Hộp", "Trái"];
  f.workbench.lines = Array.from({ length: 55 }, (_, i) => ({
    ...structuredClone(template),
    confirmed_need_line_id: `00000000-0000-4000-8000-${String(9000 + i).padStart(12, "0")}`,
    controlled_unit: {
      ...template.controlled_unit,
      code: names[i % 8] === "kg" ? "kg" : "v1-unit-technical",
      name: names[i % 8]!,
    },
  }));
  f.workbench.pagination.total_lines = 55;
  f.workbench.line_counts.total = 55;
  f.drafts = Object.fromEntries(
    f.workbench.lines.map((l) => [
      l.confirmed_need_line_id,
      initialConfirmedNeedDraft(l),
    ]),
  );
  f.supplierAdvice = Object.fromEntries(
    f.workbench.lines.map((l) => [l.confirmed_need_line_id, ""]),
  );
  const bytes = await createConfirmedNeedShoppingListXlsx(
    [f],
    new Date(),
    crypto.randomUUID(),
  );
  const envelope = await readShoppingListEnvelope(bytes);
  const rows = envelope.sheets.get("2026-09-07")!;
  const bands = rows.filter((r) => r[15]!.text === "SCHOOL_BAND");
  expect(bands.filter((r) => !r[0]!.text.endsWith(" (tiếp)"))).toHaveLength(1);
  expect(bands.length).toBeGreaterThan(1);
  expect(rows.filter((r) => r[15]!.text === "DATA_LINE")).toHaveLength(55);
  for (const after of envelope.breaks.get("2026-09-07")!) {
    expect(rows[after - 3]![15]!.text).toBe("SCHOOL_BAND");
    expect(rows[after - 3]![0]!.text).toBe(`${template.school.name} (tiếp)`);
  }
  for (const r of rows.filter((r) => r[15]!.text === "DATA_LINE")) {
    expect(r[10]!.text).toBe(template.school.id);
    expect(r[16]!.text).toBe(template.school.name);
  }
  const p = shoppingListContract.print;
  expect(
    (p.columnWidths.reduce((n, w) => n + w * 6, 0) * p.scalePercent) / 100,
  ).toBeLessThanOrEqual(p.a4WidthPt - 72 * (p.leftMarginIn + p.rightMarginIn));
  expect(shoppingListTextWidth("Miếng", p.bodyFontPt)).toBeLessThan(
    shoppingListColumnUsableWidths()[2]!,
  );
  expect(
    validateShoppingListEnvelope(envelope, [f.workbench], f.drafts)
      .changedLineIds,
  ).toEqual([]);
  // A continuation label away from its generated page position is not accepted.
  rows[0]![0]!.text += " (tiếp)";
  expect(() =>
    validateShoppingListEnvelope(envelope, [f.workbench], f.drafts),
  ).toThrow();
});

it.each(["A", "B", "C"])(
  "rejects superseded specimen geometry %s",
  async (geometry) => {
    const book = new ExcelJS.Workbook();
    await book.xlsx.load(
      await createConfirmedNeedShoppingListXlsx([shoppingFixture()]),
    );
    book.getWorksheet("_ATLAS_META")!.getCell("B7").value = geometry;
    await expect(
      readShoppingListEnvelope(new Uint8Array(await book.xlsx.writeBuffer())),
    ).rejects.toMatchObject({ code: "UNSUPPORTED_GEOMETRY" });
  },
);

it("rejects old V1 contract and renamed canonical School snapshots", async () => {
  const f = shoppingFixture();
  const book = new ExcelJS.Workbook();
  await book.xlsx.load(await createConfirmedNeedShoppingListXlsx([f]));
  book.getWorksheet("_ATLAS_META")!.getCell("B2").value =
    "ATLAS_SHOPPING_LIST_V1";
  await expect(
    readShoppingListEnvelope(new Uint8Array(await book.xlsx.writeBuffer())),
  ).rejects.toMatchObject({ code: "UNSUPPORTED_CONTRACT" });
  book.getWorksheet("_ATLAS_META")!.getCell("B2").value =
    "ATLAS_SHOPPING_LIST_V2";
  for (const l of f.workbench.lines)
    if (l.school.id === f.workbench.lines[0]!.school.id)
      l.school.name = "Tên mới";
  await expect(
    parseConfirmedNeedShoppingListXlsx(
      new Uint8Array(await book.xlsx.writeBuffer()),
      [f.workbench],
      f.drafts,
    ),
  ).rejects.toMatchObject({ code: "REFERENCE_CHANGED" });
});

it("accepts native Excel height quantization but rejects a resized structural row", async () => {
  const f = shoppingFixture();
  const envelope = await readShoppingListEnvelope(
    await createConfirmedNeedShoppingListXlsx([f]),
  );
  const heights = envelope.heights.get("2026-09-07")!;
  heights[0]! += 0.1;
  heights[1]! -= 0.05;
  expect(
    validateShoppingListEnvelope(envelope, [f.workbench], f.drafts)
      .changedLineIds,
  ).toEqual([]);
  heights[0]! += 1;
  expect(() =>
    validateShoppingListEnvelope(envelope, [f.workbench], f.drafts),
  ).toThrow();
});

it("measures only emitted School bands, without reserving an unused continuation suffix", async () => {
  const f = shoppingFixture();
  const school = {
    ...f.workbench.lines[0]!.school,
    name: "TRƯỜNG MẦM NON TƯ THỤC QUỐC TẾ THƯỢNG HẢO ABC",
  };
  for (const line of f.workbench.lines) line.school = { ...school };
  await expect(
    createConfirmedNeedShoppingListXlsx([f]),
  ).resolves.toBeInstanceOf(ArrayBuffer);
});

it("classifies a band retargeted to another existing School as STALE_IDENTITY", async () => {
  const f = shoppingFixture();
  const book = new ExcelJS.Workbook();
  await book.xlsx.load(await createConfirmedNeedShoppingListXlsx([f]));
  book.worksheets[0]!.getCell("K4").value = f.workbench.lines[1]!.school.id;
  await expect(
    parseConfirmedNeedShoppingListXlsx(
      new Uint8Array(await book.xlsx.writeBuffer()),
      [f.workbench],
      f.drafts,
    ),
  ).rejects.toMatchObject({ code: "STALE_IDENTITY" });
});

it.each([
  ["K5", "tampered", "STALE_IDENTITY"],
  ["Q5", "tampered", "REFERENCE_CHANGED"],
  ["A4", "tampered", "REFERENCE_CHANGED"],
  ["K4", "tampered", "STALE_IDENTITY"],
  ["P4", "DATA_LINE", "LINE_SET_MISMATCH"],
  ["P5", "SCHOOL_BAND", "LINE_SET_MISMATCH"],
])("rejects School/row-kind tampering at %s", async (address, value, code) => {
  const f = shoppingFixture();
  const book = new ExcelJS.Workbook();
  await book.xlsx.load(await createConfirmedNeedShoppingListXlsx([f]));
  book.worksheets[0]!.getCell(address).value = value;
  await expect(
    parseConfirmedNeedShoppingListXlsx(
      new Uint8Array(await book.xlsx.writeBuffer()),
      [f.workbench],
      f.drafts,
    ),
  ).rejects.toMatchObject({ code });
});
