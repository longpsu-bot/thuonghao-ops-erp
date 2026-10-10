import ExcelJS from "exceljs";
import { describe, expect, it } from "vitest";
import {
  actualVisibleWidthPoints,
  measuredSchoolLineCount,
  measuredSchoolRowHeight,
} from "./schoolRowMeasurement";

function schoolSheet() {
  const sheet = new ExcelJS.Workbook().addWorksheet("School bands");
  [7, 12, 42, 10, 18, 36].forEach((width, index) => {
    sheet.getColumn(index + 1).width = width;
  });
  sheet.getColumn(2).hidden = true;
  return sheet;
}

describe("measured School row height", () => {
  it("sums native Excel visible column widths and ignores hidden metadata", () => {
    const sheet = schoolSheet();
    // Native Excel COM: these visible widths span 678pt; B contributes zero.
    expect(actualVisibleWidthPoints(sheet, 1, 6)).toBe(678);
    sheet.getColumn(2).width = 255;
    expect(actualVisibleWidthPoints(sheet, 1, 6)).toBe(678);
    sheet.getColumn(3).width = 8.43;
    expect(actualVisibleWidthPoints(sheet, 3, 3)).toBe(50.25);
  });

  it.each([
    [1, 28],
    [5, 44],
    [9, 60],
    [13, 76],
    [17, 92],
    [21, 108],
  ])(
    "allocates uncapped line height for %i bold wide glyphs",
    (count, height) => {
      const sheet = schoolSheet();
      // D is 60pt, less the 3.75pt Excel edge padding. Bold W is measured 14pt.
      expect(measuredSchoolRowHeight("W".repeat(count), sheet, 4, 4)).toBe(
        height,
      );
    },
  );

  it("uses Theo hàng's School cell width independently of the full band", () => {
    const sheet = schoolSheet();
    const text = "WWWW WWWW WWWW WWWW WWWW";
    expect(measuredSchoolRowHeight(text, sheet, 1, 6, false)).toBe(28);
    expect(measuredSchoolRowHeight(text, sheet, 4, 4, false)).toBe(92);
    sheet.getColumn(4).width = 18;
    expect(measuredSchoolRowHeight(text, sheet, 4, 4, false)).toBe(92);
    sheet.getColumn(4).width = 25;
    expect(measuredSchoolRowHeight(text, sheet, 4, 4, false)).toBe(60);
  });

  it("wraps at words instead of dividing the whole string width", () => {
    // Each WW is 28pt: two words require 59.5pt including the space.
    expect(measuredSchoolLineCount("WW WW WW", 56)).toBe(3);
  });

  it("preserves explicit CRLF, LF, CR and blank lines", () => {
    expect(measuredSchoolLineCount("A\r\nB\n\nC\rD\n", 500)).toBe(6);
    expect(measuredSchoolLineCount("", 500)).toBe(1);
  });

  it("breaks long tokens without a line cap or an empty boundary line", () => {
    expect(measuredSchoolLineCount("W".repeat(10), 28)).toBe(5);
    expect(measuredSchoolLineCount("W".repeat(11), 28)).toBe(6);
    expect(measuredSchoolLineCount("WWW", 1)).toBe(3);
  });

  it("uses measured glyph advances, style and Vietnamese canonical equivalents", () => {
    expect(measuredSchoolLineCount("IIIII", 28)).toBe(1);
    expect(measuredSchoolLineCount("WWWWW", 28)).toBe(3);
    expect(measuredSchoolLineCount("IIIIII", 28, false)).toBe(1);
    expect(measuredSchoolLineCount("IIIIII", 28, true)).toBe(2);
    expect(measuredSchoolLineCount("VĨNH TÂN", 50)).toBe(2);
    expect(measuredSchoolLineCount("VĨNH TÂN".normalize("NFD"), 50)).toBe(2);
    expect(
      measuredSchoolLineCount(
        "CHUYÊN HÙNG VƯƠNG (Chiều Mặn 2) (Nấu tại: Công ty Thượng Hảo)",
        700,
      ),
    ).toBe(1);
  });

  it("rejects invalid widths and ranges instead of guessing available width", () => {
    expect(() => measuredSchoolLineCount("A", 0)).toThrow(RangeError);
    expect(() => measuredSchoolLineCount("A", Number.NaN)).toThrow(RangeError);
    expect(() => actualVisibleWidthPoints(schoolSheet(), 3, 1)).toThrow(
      RangeError,
    );
    const sheet = schoolSheet();
    sheet.getColumn(4).hidden = true;
    expect(() => measuredSchoolRowHeight("A", sheet, 4, 4)).toThrow(RangeError);
  });
});
