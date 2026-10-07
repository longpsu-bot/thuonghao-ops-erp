import ExcelJS from "exceljs";
import { describe, expect, it } from "vitest";
import { shoppingFixture } from "./shoppingListTestFixtures";
import {
  packageText,
  readShoppingListPackage,
  setPackageText,
  writeShoppingListPackage,
} from "./shoppingListPackage";

import {
  createConfirmedNeedShoppingListXlsx,
  parseConfirmedNeedShoppingListXlsx,
} from "./confirmedNeedShoppingList";
import { shoppingListRowHeight } from "./shoppingListLayout";
import { shoppingListUnitDisplay } from "./shoppingListContract";

async function fixture() {
  const f = shoppingFixture();
  const book = new ExcelJS.Workbook();
  await book.xlsx.load(await createConfirmedNeedShoppingListXlsx([f]));
  return { ...f, book, sheet: book.worksheets[0]! };
}
const bytes = async (book: ExcelJS.Workbook) =>
  new Uint8Array(await book.xlsx.writeBuffer());
describe("frozen Shopping List V1", () => {
  it.each([
    ["kg", "Kilogram", "kg"],
    ["v1-unit-034ce34d3ff3", "Quả", "Quả"],
    ["v1-unit-469606e98b7e", "Gói", "Gói"],
    ["Cái", "Cái", "Cái"],
    [" kg ", " Kilogram ", "kg"],
    [" V1-UNIT-technical ", " Quả ", "Quả"],
    ["", "Hộp", "Hộp"],
    ["00000000-0000-4000-8000-000000009999", "Cốc", "Cốc"],
    ["atlas-unit-technical", "Trái", "Trái"],
  ])("resolves Unit %s / %s to %s", (code, name, expected) => {
    expect(shoppingListUnitDisplay({ code, name })).toBe(expected);
  });
  it.each([
    "",
    " ",
    "v1-unit-missing",
    "?",
    "00000000-0000-4000-8000-000000009999",
    "unit-123",
    "atlas-unit-123",
  ])("fails closed for technical code and unusable name %s", async (name) => {
    const f = shoppingFixture();
    f.workbench.lines[0]!.controlled_unit.name = name;
    await expect(
      createConfirmedNeedShoppingListXlsx([f]),
    ).rejects.toMatchObject({ code: "INVALID_UNIT_DISPLAY" });
  });
  it.each([
    ["v1-unit-034ce34d3ff3", "Quả"],
    ["v1-unit-469606e98b7e", "Gói"],
  ])("exports and imports human name for %s", async (code, name) => {
    const f = shoppingFixture();
    for (const line of f.workbench.lines)
      Object.assign(line.controlled_unit, { code, name });
    const book = new ExcelJS.Workbook();
    await book.xlsx.load(await createConfirmedNeedShoppingListXlsx([f]));
    expect(book.worksheets[0]!.getCell("C4").value).toBe(name);
    expect(
      (
        await parseConfirmedNeedShoppingListXlsx(
          await bytes(book),
          [f.workbench],
          f.drafts,
        )
      ).changedLineIds,
    ).toEqual([]);
  });
  it("checks ambiguity using the displayed Unit while preserving identity", async () => {
    const f = shoppingFixture();
    const first = f.workbench.lines[0]!,
      second = f.workbench.lines[2]!;
    second.ingredient = { ...first.ingredient };
    first.controlled_unit.code = "kg";
    first.controlled_unit.name = "Kilogram";
    second.controlled_unit.code = "v1-unit-technical";
    second.controlled_unit.name = "kg";
    second.controlled_unit.id = "00000000-0000-4000-8000-000000009999";
    await expect(
      createConfirmedNeedShoppingListXlsx([f]),
    ).rejects.toMatchObject({ code: "AMBIGUOUS_DISPLAY" });
    second.controlled_unit.id = first.controlled_unit.id;
    await expect(
      createConfirmedNeedShoppingListXlsx([f]),
    ).resolves.toBeInstanceOf(ArrayBuffer);
  });
  it.each(["Kilogram", "😀"])(
    "keeps print overflow and unsupported glyph rejection for %s",
    async (code) => {
      const f = shoppingFixture();
      f.workbench.lines[0]!.controlled_unit.code = code;
      await expect(
        createConfirmedNeedShoppingListXlsx([f]),
      ).rejects.toMatchObject({ code: "PRINT_OVERFLOW" });
    },
  );
  it("keeps the real Staging Miếng fallback blocked by frozen print width", async () => {
    const f = shoppingFixture("2026-09-17");
    Object.assign(f.workbench.lines[0]!.controlled_unit, {
      code: "v1-unit-83bea5cf6378",
      name: "Miếng",
    });
    expect(shoppingListUnitDisplay(f.workbench.lines[0]!.controlled_unit)).toBe(
      "Miếng",
    );
    await expect(
      createConfirmedNeedShoppingListXlsx([f]),
    ).rejects.toMatchObject({
      code: "PRINT_OVERFLOW",
    });
  });
  it("exports kg/Kilogram without overflow and round-trips only local quantity proposals", async () => {
    const f = shoppingFixture("2026-09-17");
    for (const line of f.workbench.lines) {
      line.controlled_unit.code = "kg";
      line.controlled_unit.name = "Kilogram";
    }
    const before = structuredClone(f);
    expect(() =>
      shoppingListRowHeight("Trường", "Gạo", "Kilogram", "1", ""),
    ).toThrow(expect.objectContaining({ code: "PRINT_OVERFLOW" }));
    const book = new ExcelJS.Workbook();
    await book.xlsx.load(await createConfirmedNeedShoppingListXlsx([f]));
    const sheet = book.worksheets[0]!;
    expect(sheet.getCell("C4").value).toBe("kg");
    expect(sheet.getCell("N4").value).toBe(
      f.workbench.lines[0]!.controlled_unit.id,
    );
    expect(
      (
        await parseConfirmedNeedShoppingListXlsx(
          await bytes(book),
          [f.workbench],
          f.drafts,
        )
      ).changedLineIds,
    ).toEqual([]);
    sheet.getCell("D4").value = 12.5;
    const result = await parseConfirmedNeedShoppingListXlsx(
      await bytes(book),
      [f.workbench],
      f.drafts,
    );
    const id = f.workbench.lines[0]!.confirmed_need_line_id;
    expect(result.changedLineIds).toEqual([id]);
    expect(result.drafts[id]).toMatchObject({
      exact_quantity: "12,5",
      quantity_entered: true,
    });
    expect(f).toEqual(before);
    sheet.getCell("C4").value = "something else";
    await expect(
      parseConfirmedNeedShoppingListXlsx(
        await bytes(book),
        [f.workbench],
        f.drafts,
      ),
    ).rejects.toMatchObject({ code: "REFERENCE_CHANGED" });
    sheet.getCell("C4").value = "kg";
    sheet.getCell("N4").value = "00000000-0000-4000-8000-000000009999";
    await expect(
      parseConfirmedNeedShoppingListXlsx(
        await bytes(book),
        [f.workbench],
        f.drafts,
      ),
    ).rejects.toMatchObject({ code: "STALE_IDENTITY" });
    expect(f).toEqual(before);
  });
  it("rejects hostile ZIP envelopes before parsing workbook XML", async () => {
    const encode = new TextEncoder();
    const duplicate = writeShoppingListPackage(
      new Map([
        ["a.xml", encode.encode("<a/>")],
        ["b.xml", encode.encode("<b/>")],
      ]),
    );
    for (let i = 0; i < duplicate.length - 5; i++)
      if (
        duplicate[i] === 98 &&
        duplicate[i + 1] === 46 &&
        duplicate[i + 2] === 120 &&
        duplicate[i + 3] === 109 &&
        duplicate[i + 4] === 108
      )
        duplicate[i] = 97;
    await expect(readShoppingListPackage(duplicate)).rejects.toThrow();
    await expect(
      readShoppingListPackage(
        writeShoppingListPackage(
          new Map([["../a.xml", encode.encode("<a/>")]]),
        ),
      ),
    ).rejects.toThrow();
    const encrypted = writeShoppingListPackage(
      new Map([["a.xml", encode.encode("<a/>")]]),
    );
    encrypted[6] = encrypted[6]! | 1;
    await expect(readShoppingListPackage(encrypted)).rejects.toThrow();
    await expect(
      readShoppingListPackage(new Uint8Array(10485761)),
    ).rejects.toThrow();
  });
  it("ignores date-typed working-paper cells", async () => {
    const f = shoppingFixture(),
      files = await readShoppingListPackage(
        await createConfirmedNeedShoppingListXlsx([f]),
      );
    setPackageText(
      files,
      "xl/worksheets/sheet1.xml",
      packageText(files, "xl/worksheets/sheet1.xml").replace(
        /<c\b([^>]*\br="E4"[^>]*)>[\s\S]*?<\/c>/,
        (_, a) =>
          `<c${a.replace(/\s*t="[^"]*"/, "")} t="d"><v>2026-09-07</v></c>`,
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
  it.each([
    "calculatedColumnFormula",
    "totalsRowFormula",
    "formula1",
    "formula2",
  ])("rejects executable formula element %s", async (tag) => {
    const f = shoppingFixture(),
      files = await readShoppingListPackage(
        await createConfirmedNeedShoppingListXlsx([f]),
      ),
      table = tag.includes("Column") || tag.includes("Row"),
      part = table ? "xl/tables/table1.xml" : "xl/worksheets/sheet1.xml";
    const xml = packageText(files, part),
      formula = `<${tag}>1+1</${tag}>`;
    setPackageText(
      files,
      part,
      table
        ? xml.replace(
            /<tableColumn\b([^>]*)\/>/,
            `<tableColumn$1>${formula}</tableColumn>`,
          )
        : xml.replace("</worksheet>", `${formula}</worksheet>`),
    );
    await expect(
      parseConfirmedNeedShoppingListXlsx(
        writeShoppingListPackage(files),
        [f.workbench],
        f.drafts,
      ),
    ).rejects.toThrow();
  });
  it("rejects erased School labels despite blank-repeat presentation", async () => {
    const f = await fixture();
    for (let r = 4; r <= 9; r++) f.sheet.getCell(`A${r}`).value = null;
    await expect(
      parseConfirmedNeedShoppingListXlsx(
        await bytes(f.book),
        [f.workbench],
        f.drafts,
      ),
    ).rejects.toThrow();
  });
  it.each([42, true, { error: "#N/A" } as ExcelJS.CellValue])(
    "ignores scalar working-paper notes %j",
    async (value) => {
      const f = await fixture();
      f.sheet.getCell("E4").value = value;
      expect(
        (
          await parseConfirmedNeedShoppingListXlsx(
            await bytes(f.book),
            [f.workbench],
            f.drafts,
          )
        ).changedLineIds,
      ).toEqual([]);
    },
  );
  it("exports saved facts into the complete frozen Table and print geometry", async () => {
    const { book, sheet, workbench } = await fixture();
    expect(sheet.getRow(3).values).toEqual([
      undefined,
      "TRƯỜNG",
      "THÀNH PHẦN",
      "ĐVT",
      "SỐ LƯỢNG",
      "GHI CHÚ",
      "__workbook_marker",
      "__line_id",
      "__revision_id",
      "__decision_id",
      "__service_date",
      "__school_id",
      "__location_id",
      "__ingredient_id",
      "__unit_id",
      "__exported_quantity",
    ]);
    expect(sheet.getCell("A4").value).toBe("Trường Nguyễn Du");
    expect(sheet.getCell("A5").value).toBeNull();
    expect(sheet.getCell("C4").value).toBe("kg");
    expect(sheet.getCell("E4").value).toBe("NCC An Bình");
    expect(sheet.getCell("L4").value).toBe(
      workbench.lines[0]!.delivery_location.id,
    );
    expect(sheet.getTables()).toHaveLength(1);
    expect(
      packageText(
        await readShoppingListPackage(
          await createConfirmedNeedShoppingListXlsx([shoppingFixture()]),
        ),
        "xl/tables/table1.xml",
      ),
    ).toContain('ref="A3:O9"');
    expect(book.getWorksheet("_ATLAS_META")?.state).toBe("veryHidden");
    expect(sheet.pageSetup).toMatchObject({
      paperSize: 9,
      orientation: "portrait",
      scale: 96,
      printArea: "A1:E9",
      printTitlesRow: "1:3",
    });
    expect([1, 2, 3, 4, 5].map((c) => sheet.getColumn(c).width)).toEqual([
      25, 32, 6, 16, 15,
    ]);
    expect([1, 2, 3].map((r) => sheet.getRow(r).height)).toEqual([32, 5, 48]);
    for (let r = 4; r <= 9; r++)
      expect([28, 44]).toContain(sheet.getRow(r).height);
    expect(
      ["A3", "B4", "D4", "E4"].map((c) => sheet.getCell(c).font.size),
    ).toEqual([17, 18, 16, 14]);
    for (let c = 6; c <= 15; c++) expect(sheet.getColumn(c).hidden).toBe(true);
  });
  it("ignores notes and preserves reasons for quantity-only proposals", async () => {
    const f = await fixture();
    f.sheet.getCell("E4").value = "staff note";
    expect(
      (
        await parseConfirmedNeedShoppingListXlsx(
          await bytes(f.book),
          [f.workbench],
          f.drafts,
        )
      ).changedLineIds,
    ).toEqual([]);
    f.sheet.getCell("D4").value = 12.5;
    const a = await parseConfirmedNeedShoppingListXlsx(
      await bytes(f.book),
      [f.workbench],
      f.drafts,
    );
    f.sheet.getCell("E4").value = "";
    expect(
      await parseConfirmedNeedShoppingListXlsx(
        await bytes(f.book),
        [f.workbench],
        f.drafts,
      ),
    ).toEqual(a);
    expect(a.changedLineIds).toEqual([
      f.workbench.lines[0]!.confirmed_need_line_id,
    ]);
    expect(a.drafts[a.changedLineIds[0]!]).toMatchObject({
      exact_quantity: "12,5",
      quantity_entered: true,
      reason_code: "PROPOSAL_ACCEPTED",
      reason_note: "",
    });
  });
  it.each([
    "F4",
    "G4",
    "H4",
    "I4",
    "J4",
    "K4",
    "L4",
    "M4",
    "N4",
    "O4",
    "A4",
    "B4",
    "C4",
  ])("rejects evidence/reference tampering %s", async (cell) => {
    const f = await fixture();
    const before = structuredClone(f.drafts);
    f.sheet.getCell(cell).value = "tampered";
    await expect(
      parseConfirmedNeedShoppingListXlsx(
        await bytes(f.book),
        [f.workbench],
        f.drafts,
      ),
    ).rejects.toThrow();
    expect(f.drafts).toEqual(before);
  });
  it.each(["1.234", "12.51", "", -1, { formula: "1+1" }])(
    "rejects invalid quantity or formula %j",
    async (value) => {
      const f = await fixture();
      f.sheet.getCell("D4").value = value;
      await expect(
        parseConfirmedNeedShoppingListXlsx(
          await bytes(f.book),
          [f.workbench],
          f.drafts,
        ),
      ).rejects.toThrow();
    },
  );
  it("rejects duplicate, missing and outside-Table rows", async () => {
    for (const mode of ["duplicate", "missing", "outside"]) {
      const f = await fixture();
      if (mode === "duplicate")
        f.sheet.getCell("G5").value = f.sheet.getCell("G4").value;
      if (mode === "missing") f.sheet.getRow(5).values = [];
      if (mode === "outside") f.sheet.getCell("A10").value = "extra";
      await expect(
        parseConfirmedNeedShoppingListXlsx(
          await bytes(f.book),
          [f.workbench],
          f.drafts,
        ),
      ).rejects.toThrow();
    }
  });
  it("supports three daily batches and rejects stale middle authority", async () => {
    const fs = [
      shoppingFixture(),
      shoppingFixture("2026-09-08", 2),
      shoppingFixture("2026-09-09", 3),
    ];
    const output = await createConfirmedNeedShoppingListXlsx(fs);
    const drafts = Object.assign({}, ...fs.map((f) => f.drafts));
    expect(
      (
        await parseConfirmedNeedShoppingListXlsx(
          new Uint8Array(output),
          fs.map((f) => f.workbench),
          drafts,
        )
      ).changedLineIds,
    ).toEqual([]);
    fs[1]!.workbench.batch_version++;
    await expect(
      parseConfirmedNeedShoppingListXlsx(
        new Uint8Array(output),
        fs.map((f) => f.workbench),
        drafts,
      ),
    ).rejects.toThrow();
  });
  it("returns a safe corrupt-file error", async () => {
    const f = shoppingFixture();
    await expect(
      parseConfirmedNeedShoppingListXlsx(
        new Uint8Array([1, 2, 3]),
        [f.workbench],
        f.drafts,
      ),
    ).rejects.toThrow("Không thể đọc Phiếu đi chợ");
  });
  it("maps a complete Table sort by stable identity", async () => {
    const f = await fixture();
    f.sheet.getCell("D4").value = 12.5;
    const rows = Array.from(
      { length: 6 },
      (_, i) => f.sheet.getRow(i + 4).values,
    ).reverse();
    rows.forEach((values, i) => {
      f.sheet.getRow(i + 4).values = values;
    });
    expect(
      (
        await parseConfirmedNeedShoppingListXlsx(
          await bytes(f.book),
          [f.workbench],
          f.drafts,
        )
      ).changedLineIds,
    ).toEqual([f.workbench.lines[0]!.confirmed_need_line_id]);
  });
  it.each(["batch_version", "run", "release", "revision", "decision"])(
    "rejects fresh authority drift %s atomically",
    async (kind) => {
      const f = await fixture(),
        before = structuredClone(f.drafts);
      f.sheet.getCell("D4").value = 12.5;
      if (kind === "batch_version") f.workbench.batch_version++;
      if (kind === "run")
        f.workbench.need_generation_source.run_id =
          "00000000-0000-4000-8000-000000009999";
      if (kind === "release")
        f.workbench.need_generation_source.release_snapshot_id =
          "00000000-0000-4000-8000-000000009999";
      if (kind === "revision")
        f.workbench.lines[1]!.current_revision_id =
          "00000000-0000-4000-8000-000000009999";
      if (kind === "decision") f.workbench.lines[1]!.current_decision_id = null;
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
  it("rejects a row transplanted into a different daily Table", async () => {
    const fs = [
        shoppingFixture(),
        shoppingFixture("2026-09-08", 2),
        shoppingFixture("2026-09-09", 3),
      ],
      book = new ExcelJS.Workbook();
    await book.xlsx.load(await createConfirmedNeedShoppingListXlsx(fs));
    book.worksheets[1]!.getRow(4).values = book.worksheets[0]!.getRow(4).values;
    const drafts = Object.assign({}, ...fs.map((f) => f.drafts)),
      before = structuredClone(drafts);
    await expect(
      parseConfirmedNeedShoppingListXlsx(
        await bytes(book),
        fs.map((f) => f.workbench),
        drafts,
      ),
    ).rejects.toThrow();
    expect(drafts).toEqual(before);
  });
  it("blocks unsuitable Unit display and actual print overflow", async () => {
    const f = shoppingFixture();
    f.workbench.lines[0]!.controlled_unit.name = "v1-unit-migration";
    await expect(
      createConfirmedNeedShoppingListXlsx([f]),
    ).rejects.toMatchObject({ code: "INVALID_UNIT_DISPLAY" });
    f.workbench.lines[0]!.controlled_unit.name = "kg";
    f.workbench.lines[0]!.ingredient.name = "W".repeat(80);
    await expect(
      createConfirmedNeedShoppingListXlsx([f]),
    ).rejects.toMatchObject({ code: "PRINT_OVERFLOW" });
  });
});
