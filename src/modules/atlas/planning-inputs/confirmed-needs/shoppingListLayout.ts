import metrics from "./shoppingListFontMetrics.json";
import {
  ShoppingListError,
  shoppingListContract,
} from "./shoppingListContract";

// Times New Roman glyph advances from the native font used in F13. Accent
// combining marks have zero advance; unsupported glyphs fail export safely.
export function shoppingListTextWidth(
  text: string,
  size: number,
  bold = false,
) {
  const map: Record<string, number> = bold ? metrics.bold : metrics.normal;
  let result = 0;
  for (const glyph of text.normalize("NFD")) {
    if (/\p{Mark}/u.test(glyph)) continue;
    const advance = map[glyph];
    if (advance === undefined)
      throw new ShoppingListError(
        "PRINT_OVERFLOW",
        "Nội dung chưa được kiểm chứng để in. Hãy rà soát tên hiển thị trước khi xuất Phiếu đi chợ.",
      );
    result += advance * size;
  }
  return result;
}
function lineCount(text: string, points: number, size: number, bold = false) {
  let count = 0;
  for (const paragraph of text.split(/\r?\n/)) {
    let line = "";
    count++;
    for (const word of paragraph.split(" ")) {
      if (shoppingListTextWidth(word, size, bold) > points) return Infinity;
      const candidate = line ? `${line} ${word}` : word;
      if (shoppingListTextWidth(candidate, size, bold) > points) {
        count++;
        line = word;
      } else line = candidate;
    }
  }
  return count;
}
export function shoppingListRowHeight(
  ingredient: string,
  unit: string,
  quantity: string,
  supplier: string,
) {
  const p = shoppingListContract.print;
  const usable = shoppingListColumnUsableWidths();
  // Native Carlito 11 Normal style gives 6 pt per column unit. Padding is
  // reserved conservatively; native widths and physical PDFs verify this.
  if (
    shoppingListTextWidth(unit, p.bodyFontPt) > usable[2]! ||
    shoppingListTextWidth(quantity, p.quantityFontPt) > usable[3]!
  )
    throw new ShoppingListError(
      "PRINT_OVERFLOW",
      "Nội dung vượt khuôn in đã kiểm chứng. Hãy rà soát Phiếu đi chợ trước khi xuất.",
    );
  const lines = Math.max(
    lineCount(ingredient, usable[1]!, p.bodyFontPt),
    lineCount(supplier, usable[4]!, p.supplierFontPt),
  );
  if (lines > 2)
    throw new ShoppingListError(
      "PRINT_OVERFLOW",
      "Nội dung không vừa khuôn in Phiếu đi chợ. Hãy rà soát tên hiển thị trước khi xuất.",
    );
  return lines > 1 ? p.wrappedRowPt : p.normalRowPt;
}
export function shoppingListColumnUsableWidths() {
  return shoppingListContract.print.columnWidths.map((w) => w * 6 - 5.5);
}
export type ShoppingListBodyRow = {
  kind: "SCHOOL_BAND" | "DATA_LINE";
  index: number;
  height: number;
  continuation: boolean;
};
export function shoppingListPages(
  rows: { schoolId: string; height: number }[],
) {
  const p = shoppingListContract.print;
  const capacity =
    (p.a4HeightPt -
      72 * (p.topMarginIn + p.bottomMarginIn) -
      p.footerAllowancePt) /
      (p.scalePercent / 100) -
    p.titleRowPt -
    p.spacerRowPt -
    p.headerRowPt;
  let remaining = capacity,
    index = 0;
  const breaks: number[] = [],
    body: ShoppingListBodyRow[] = [];
  const band = (index: number, continuation: boolean) => {
    body.push({
      kind: "SCHOOL_BAND",
      index,
      height: p.bandRowPt,
      continuation,
    });
    remaining -= p.bandRowPt;
  };
  const page = () => {
    breaks.push(body.length + 3);
    remaining = capacity;
  };
  while (index < rows.length) {
    let end = index;
    while (end < rows.length && rows[end]!.schoolId === rows[index]!.schoolId)
      end++;
    const total =
      p.bandRowPt +
      rows.slice(index, end).reduce((sum, r) => sum + r.height, 0);
    let fit = 0,
      space = remaining - p.bandRowPt;
    for (let i = index; i < end; i++) {
      if (rows[i]!.height > space) break;
      space -= rows[i]!.height;
      fit++;
    }
    if (
      index &&
      ((end - index <= 8 && total > remaining) ||
        (total > remaining && remaining < capacity && fit < 3))
    ) {
      page();
    }
    band(index, false);
    for (let i = index; i < end; i++) {
      const height = rows[i]!.height;
      if (height > remaining) {
        page();
        band(i, true);
      }
      body.push({ kind: "DATA_LINE", index: i, height, continuation: false });
      remaining -= height;
    }
    index = end;
  }
  return { breaks, body };
}
