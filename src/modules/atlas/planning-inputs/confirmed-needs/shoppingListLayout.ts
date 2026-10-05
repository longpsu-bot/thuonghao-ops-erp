import metrics from "./shoppingListFontMetrics.json";
import {
  ShoppingListError,
  shoppingListContract as contract,
} from "./shoppingListContract";

// Times New Roman glyph advances from the native font used in F13. Accent
// combining marks have zero advance; unsupported glyphs fail export safely.
function width(text: string, size: number, bold = false) {
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
      if (width(word, size, bold) > points) return Infinity;
      const candidate = line ? `${line} ${word}` : word;
      if (width(candidate, size, bold) > points) {
        count++;
        line = word;
      } else line = candidate;
    }
  }
  return count;
}
export function shoppingListRowHeight(
  school: string,
  ingredient: string,
  unit: string,
  quantity: string,
  supplier: string,
  continuation = false,
  schoolShown = true,
) {
  const p = contract.print;
  const size = Array.from(
    `${school}${ingredient}${unit}${quantity}${supplier}`,
  ).filter((c) => c !== "\n" && c !== "\r").length;
  // This is an artifact warning/block, never a database or name-length rule.
  if (
    size > 84 ||
    width(unit, p.bodyFontPt) > 35.5 ||
    width(quantity, p.quantityFontPt) > 95.5
  )
    throw new ShoppingListError(
      "PRINT_OVERFLOW",
      "Nội dung vượt khuôn in đã kiểm chứng. Hãy rà soát Phiếu đi chợ trước khi xuất.",
    );
  const lines = Math.max(
    lineCount(
      continuation ? `${school} (tiếp)` : schoolShown ? school : "",
      149.5,
      p.schoolFontPt,
      true,
    ),
    lineCount(ingredient, 192.5, p.bodyFontPt),
    lineCount(supplier, 89.5, p.supplierFontPt),
  );
  if (lines > 2)
    throw new ShoppingListError(
      "PRINT_OVERFLOW",
      "Nội dung không vừa khuôn in Phiếu đi chợ. Hãy rà soát tên hiển thị trước khi xuất.",
    );
  return continuation || lines > 1 ? p.wrappedRowPt : p.normalRowPt;
}
export function shoppingListPages(
  rows: { schoolId: string; height: number }[],
) {
  const p = contract.print;
  const capacity =
    (p.a4HeightPt -
      72 * (p.topMarginIn + p.bottomMarginIn) -
      p.footerAllowancePt -
      p.titleRowPt -
      p.spacerRowPt -
      p.headerRowPt) /
    p.pageHeightScaleUpperBound;
  let remaining = capacity,
    index = 0;
  const breaks: number[] = [],
    continuations = new Set<number>();
  while (index < rows.length) {
    let end = index;
    while (end < rows.length && rows[end]!.schoolId === rows[index]!.schoolId)
      end++;
    const total = rows.slice(index, end).reduce((sum, r) => sum + r.height, 0);
    let fit = 0,
      space = remaining;
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
      breaks.push(index + 3);
      remaining = capacity;
    }
    for (let i = index; i < end; i++) {
      let height = rows[i]!.height;
      if (height > remaining) {
        breaks.push(i + 3);
        remaining = capacity;
        if (i > index) {
          continuations.add(i);
          height = p.wrappedRowPt;
          rows[i]!.height = height;
        }
      }
      remaining -= height;
    }
    index = end;
  }
  return { breaks, continuations };
}
