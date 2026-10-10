import type { Worksheet } from "exceljs";
import metrics from "./timesNewRoman14Metrics.json";

const pointsPerPixel = 72 / metrics.provenance.columnDpi;
const maximumDigitWidth = metrics.provenance.maximumDigitWidthPixels;
const cellEdgePaddingPoints = 5 * pointsPerPixel;

// Normal-style digit width was verified against native Excel COM. Cell font
// size is independent: the text below always uses measured TNR 14pt advances.
function excelWidthPoints(width: number) {
  if (!Number.isFinite(width) || width < 0)
    throw new RangeError(
      "School row measurement requires valid column widths.",
    );
  return (
    Math.floor(
      ((256 * width + Math.floor(128 / maximumDigitWidth)) / 256) *
        maximumDigitWidth,
    ) * pointsPerPixel
  );
}

export function actualVisibleWidthPoints(
  sheet: Worksheet,
  firstColumn: number,
  lastColumn: number,
): number {
  if (
    !Number.isInteger(firstColumn) ||
    !Number.isInteger(lastColumn) ||
    firstColumn < 1 ||
    lastColumn < firstColumn ||
    lastColumn > 16384
  )
    throw new RangeError(
      "School row measurement requires a valid column range.",
    );
  let widthPoints = 0;
  for (let index = firstColumn; index <= lastColumn; index++) {
    const column = sheet.getColumn(index);
    if (column.hidden) continue;
    const width = column.width ?? sheet.properties.defaultColWidth;
    if (width === undefined)
      throw new RangeError(
        "School row measurement requires explicit column widths.",
      );
    widthPoints += excelWidthPoints(width);
  }
  return widthPoints;
}

export function measuredSchoolLineCount(
  text: string,
  widthPoints: number,
  bold = true,
): number {
  if (!Number.isFinite(widthPoints) || widthPoints <= 0)
    throw new RangeError(
      "School row measurement requires positive usable width.",
    );
  const advances: Record<string, number> = bold
    ? metrics.bold
    : metrics.regular;
  // Outside the measured Latin/Vietnamese repertoire, reserve the widest
  // measured advance. Text is retained; native font substitution needs QA.
  const fallbackAdvance = Math.max(...Object.values(advances));
  const advance = (character: string) =>
    advances[character.codePointAt(0)!] ?? fallbackAdvance;
  const textWidth = (value: string) =>
    Array.from(value).reduce((sum, character) => sum + advance(character), 0);

  return text
    .normalize("NFC")
    .replace(/\r\n|\r/g, "\n")
    .split("\n")
    .reduce((total, paragraph) => {
      let lines = 1;
      let lineWidth = 0;
      let pendingSpaceWidth = 0;
      for (const token of paragraph.match(/[ \t]+|[^ \t]+/g) ?? []) {
        if (/^[ \t]+$/.test(token)) {
          // Tabs have no single glyph advance; use four measured spaces.
          pendingSpaceWidth += textWidth(token.replaceAll("\t", "    "));
          continue;
        }
        const tokenWidth = textWidth(token);
        if (lineWidth + pendingSpaceWidth + tokenWidth <= widthPoints) {
          lineWidth += pendingSpaceWidth + tokenWidth;
        } else {
          if (lineWidth > 0) {
            lines++;
            lineWidth = 0;
          }
          // A long token must consume as many physical lines as needed. A
          // single oversized glyph still makes progress without an empty line.
          for (const character of token) {
            const glyphWidth = advance(character);
            if (lineWidth > 0 && lineWidth + glyphWidth > widthPoints) {
              lines++;
              lineWidth = 0;
            }
            lineWidth += glyphWidth;
          }
        }
        pendingSpaceWidth = 0;
      }
      return total + lines;
    }, 0);
}

export function measuredSchoolRowHeight(
  text: string,
  sheet: Worksheet,
  firstColumn: number,
  lastColumn: number,
  bold = true,
): number {
  const usableWidthPoints =
    actualVisibleWidthPoints(sheet, firstColumn, lastColumn) -
    cellEdgePaddingPoints;
  const lines = measuredSchoolLineCount(text, usableWidthPoints, bold);
  return 28 + 16 * (lines - 1);
}
