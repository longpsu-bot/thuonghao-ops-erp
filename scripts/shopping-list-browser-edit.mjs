// Test-file editing only: a general ExcelJS rewrite drops manual row breaks.
// Preserve every package part and alter just the selected editable quantity cell.
import assert from "node:assert/strict";
import JSZip from "jszip";

export async function editShoppingListQuantity(
  bytes,
  worksheetPath,
  cell,
  quantity,
) {
  assert(/^xl\/worksheets\/sheet[1-9]\d*\.xml$/.test(worksheetPath));
  assert(/^D[1-9]\d*$/.test(cell));
  assert(/^(0|[1-9]\d{0,13})(?:[.,]\d{1,2})?$/.test(quantity));
  const zip = await JSZip.loadAsync(bytes);
  const part = zip.file(worksheetPath);
  assert(part, "Exact visible worksheet part required.");
  const xml = await part.async("string");
  const pattern = new RegExp(
    `<c\\b([^>]*\\br="${cell}"[^>]*)>[\\s\\S]*?<\\/c>`,
    "g",
  );
  assert.equal(
    [...xml.matchAll(pattern)].length,
    1,
    "Exactly one existing quantity cell required.",
  );
  zip.file(
    worksheetPath,
    xml.replace(
      pattern,
      (_, attributes) =>
        `<c${attributes.replace(/\s+t="[^"]*"/, "")}><v>${quantity.replace(",", ".")}</v></c>`,
    ),
  );
  return zip.generateAsync({ type: "uint8array", compression: "DEFLATE" });
}
