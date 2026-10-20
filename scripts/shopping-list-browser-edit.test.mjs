// @vitest-environment node
import assert from "node:assert/strict";
import { test } from "vitest";
import JSZip from "jszip";
import { editShoppingListQuantity } from "./shopping-list-browser-edit.mjs";

test("a browser quantity edit preserves manual print breaks and every unrelated package byte", async () => {
  const zip = new JSZip();
  const original =
    '<worksheet><sheetData><row r="5"><c r="D5" s="6" t="s"><v>12</v></c><c r="G5"><v>source</v></c></row></sheetData><rowBreaks count="2" manualBreakCount="2"><brk id="29" min="0" max="16383" man="1"/><brk id="55" min="0" max="16383" man="1"/></rowBreaks></worksheet>';
  zip.file("xl/worksheets/sheet1.xml", original);
  zip.file("xl/tables/table1.xml", '<table ref="A3:Q275"/>');
  zip.file("xl/worksheets/sheet2.xml", "immutable metadata");
  const bytes = await zip.generateAsync({ type: "uint8array" });
  const edited = await JSZip.loadAsync(
    await editShoppingListQuantity(
      bytes,
      "xl/worksheets/sheet1.xml",
      "D5",
      "2,6",
    ),
  );
  assert.equal(
    await edited.file("xl/worksheets/sheet1.xml").async("string"),
    original.replace(
      '<c r="D5" s="6" t="s"><v>12</v></c>',
      '<c r="D5" s="6"><v>2.6</v></c>',
    ),
  );
  for (const name of Object.keys(zip.files).filter(
    (name) => !zip.files[name].dir && name !== "xl/worksheets/sheet1.xml",
  )) {
    assert.deepEqual(
      await edited.file(name).async("uint8array"),
      await zip.file(name).async("uint8array"),
    );
  }
  await assert.rejects(() =>
    editShoppingListQuantity(bytes, "xl/worksheets/sheet1.xml", "G5", "2.6"),
  );
  await assert.rejects(() =>
    editShoppingListQuantity(bytes, "xl/worksheets/sheet1.xml", "D6", "2.6"),
  );
  await assert.rejects(() =>
    editShoppingListQuantity(bytes, "xl/worksheets/sheet1.xml", "D5", "=1+1"),
  );
});
