import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

export const before = JSON.parse(
  readFileSync(new URL("before.json", import.meta.url), "utf8"),
).js_export_po_xlsx_grouped;

export function removeDetailSpacer(source) {
  if (source !== before) throw new Error("OPS_V1_PO_SPACING_SOURCE_MISMATCH");
  let result = source;
  for (const [from, to] of [
    [
      "const buildBreakdownByEntitySheet =",
      "const buildBreakdownByIngredientSheet =",
    ],
    ["const buildBreakdownByIngredientSheet =", "// BUILD EXPORT BUCKETS"],
  ]) {
    const start = result.indexOf(from);
    const end = result.indexOf(to, start + from.length);
    const block = result.slice(start, end);
    if (
      start < 0 ||
      end < 0 ||
      (block.match(/ws\.getRow\(9\)/g) || []).length !== 2 ||
      (block.match(/let r = 10;/g) || []).length !== 1 ||
      (block.match(/"1:9"/g) || []).length !== 1
    )
      throw new Error("OPS_V1_PO_SPACING_SOURCE_MISMATCH");
    const replacement = block
      .replaceAll("ws.getRow(9)", "ws.getRow(8)")
      .replaceAll(/\b([A-G])9\b/g, (_, column) => `${column}8`)
      .replace("let r = 10;", "let r = 9;")
      .replace('"1:9"', '"1:8"');
    result = result.slice(0, start) + replacement + result.slice(end);
  }
  return result;
}

export const after = removeDetailSpacer(before);

export function rollback(current) {
  if (current !== after) throw new Error("OPS_V1_PO_SPACING_SOURCE_MISMATCH");
  return before;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  writeFileSync(new URL("after.txt", import.meta.url), after);
  console.log(
    "Prepared one Retool exporter replacement; detail headers move from row 9 to 8.",
  );
}
