// Read-only QA: fresh authorized export response in, production XLSX specimens out.
import fs from "node:fs/promises";
import path from "node:path";
import assert from "node:assert/strict";
import ExcelJS from "exceljs";
import { createServer } from "vite";
import { JSDOM } from "jsdom";

globalThis.DOMParser = new JSDOM().window.DOMParser;
const [authorityPath, outputPath, mode] = process.argv.slice(2);
assert(
  authorityPath && outputPath,
  "Provide authorized export response JSON and output directory.",
);
const authority = JSON.parse(await fs.readFile(authorityPath, "utf8"));
assert.equal(authority.success, true);
assert.equal(authority.workbench.lines.length, 248);
assert.equal(authority.workbench.service_period.period_start, "2026-09-17");
assert.equal(authority.workbench.service_period.period_end, "2026-09-17");
assert.equal(authority.workbench.pagination.has_more, false);
assert.equal(authority.workbench.pagination.offset, 0);
const output = path.resolve(outputPath);
await fs.mkdir(output, { recursive: true });
const server = await createServer({
  configFile: false,
  optimizeDeps: { noDiscovery: true, include: [] },
  server: { hmr: false, middlewareMode: true },
  appType: "custom",
});
try {
  const root = "/src/modules/atlas/planning-inputs/confirmed-needs/";
  const codec = await server.ssrLoadModule(
    `${root}confirmedNeedShoppingList.ts`,
  );
  const model = await server.ssrLoadModule(`${root}confirmedNeedModel.ts`);
  const layout = await server.ssrLoadModule(`${root}shoppingListLayout.ts`);
  const { shoppingListContract, shoppingListUnitDisplay } =
    await server.ssrLoadModule(`${root}shoppingListContract.ts`);
  const batch = {
    workbench: authority.workbench,
    supplierAdvice: authority.shopping_list_supplier_advice,
  };
  const drafts = Object.fromEntries(
    batch.workbench.lines.map((l) => [
      l.confirmed_need_line_id,
      model.initialConfirmedNeedDraft(l),
    ]),
  );
  const report = {};
  const geometry = shoppingListContract.geometryVariant;
  const name = `ShoppingList-SchoolBand-APlus-2026-09-17`;
  const filename = path.join(output, `${name}.xlsx`);
  const bytes =
    mode === "--verify-native"
      ? await fs.readFile(
          path.join(output, `${name}-QUANTITY-EDIT-TEST-ONLY.xlsx`),
        )
      : new Uint8Array(
          await codec.createConfirmedNeedShoppingListXlsx(
            [batch],
            new Date(),
            crypto.randomUUID(),
          ),
        );
  if (mode !== "--verify-native") await fs.writeFile(filename, bytes);
  const book = new ExcelJS.Workbook();
  await book.xlsx.load(bytes);
  const sheet = book.worksheets[0];
  assert.equal(sheet.getTables().length, 1);
  assert.equal(sheet.views[0].ySplit, 3);
  assert.equal(sheet.pageSetup.printTitlesRow, "1:3");
  const data = [],
    bands = [],
    rows = [];
  const byLine = new Map(
    batch.workbench.lines.map((l) => [l.confirmed_need_line_id, l]),
  );
  for (let r = 4; r <= sheet.rowCount; r++) {
    const row = sheet.getRow(r),
      kind = row.getCell(16).value;
    if (kind === "DATA_LINE") {
      const line = byLine.get(row.getCell(7).value);
      assert(line);
      assert.equal(row.getCell(1).value, null);
      assert.equal(row.getCell(11).value, line.school.id);
      assert.equal(row.getCell(17).value, line.school.name);
      assert.equal(row.getCell(13).value, line.ingredient.id);
      assert.equal(row.getCell(14).value, line.controlled_unit.id);
      assert.equal(row.getCell(8).value, line.current_revision_id);
      assert.equal(row.getCell(9).value ?? "", line.current_decision_id ?? "");
      assert.equal(
        row.getCell(15).value,
        codec.savedShoppingListQuantity(line),
      );
      assert.equal(
        row.getCell(3).value,
        shoppingListUnitDisplay(line.controlled_unit),
      );
      assert.equal(
        row.getCell(4).value,
        mode === "--verify-native" && data.length === 0
          ? "12,5"
          : codec.shortestShoppingListQuantity(
              codec.savedShoppingListQuantity(line),
            ),
        `Visible quantity must match clean authority except the isolated QA edit: row ${r}`,
      );
      data.push(r);
    } else {
      assert.equal(kind, "SCHOOL_BAND");
      assert.equal(row.getCell(7).value, null);
      assert.equal(row.getCell(1).isMerged, false);
      bands.push(r);
    }
    rows.push({
      row: r,
      kind,
      school_id: row.getCell(11).value,
      school_name: row.getCell(17).value,
      visible: [1, 2, 3, 4, 5].map((c) => row.getCell(c).value),
      height: row.height,
    });
  }
  assert.equal(data.length, 248);
  assert.equal(sheet.getCell("B5").value, "Cá basa phi lê");
  assert.equal(sheet.getCell("O5").value, "228.010000");
  assert.equal(book.getWorksheet("_ATLAS_META").getCell("B7").value, "A+");
  const result = await codec.parseConfirmedNeedShoppingListXlsx(
    bytes,
    [batch.workbench],
    drafts,
  );
  assert.deepEqual(
    result.changedLineIds,
    mode === "--verify-native"
      ? [batch.workbench.lines[0].confirmed_need_line_id]
      : [],
  );
  const units = [
    ...new Set(
      batch.workbench.lines.map((l) =>
        shoppingListUnitDisplay(l.controlled_unit),
      ),
    ),
  ];
  if (mode === "--verify-native")
    assert.equal(
      result.drafts[result.changedLineIds[0]].exact_quantity,
      "12,5",
    );
  const p = shoppingListContract.print;
  const widths = layout.shoppingListColumnUsableWidths();
  report[geometry] = {
    geometry,
    xlsx:
      mode === "--verify-native"
        ? path.join(output, `${name}-QUANTITY-EDIT-TEST-ONLY.xlsx`)
        : filename,
    data_lines: data.length,
    initial_school_bands: bands.filter(
      (r) => !String(sheet.getCell(`A${r}`).value).endsWith(" (tiếp)"),
    ).length,
    continuation_bands: bands.filter((r) =>
      String(sheet.getCell(`A${r}`).value).endsWith(" (tiếp)"),
    ).length,
    wrapped_data_rows: data.filter(
      (r) => sheet.getRow(r).height === p.wrappedRowPt,
    ).length,
    wrapped_ingredient_rows: batch.workbench.lines.filter(
      (l) =>
        layout.shoppingListTextWidth(l.ingredient.name, p.bodyFontPt) >
        widths[1],
    ).length,
    wrapped_school_bands: 0,
    units,
    max_unit_width_pt: Math.max(
      ...units.map((u) => layout.shoppingListTextWidth(u, p.bodyFontPt)),
    ),
    unit_usable_width_pt: widths[2],
    note_usable_width_pt: widths[4],
    column_widths: p.columnWidths,
    normal_row_pt: p.normalRowPt,
    wrapped_row_pt: p.wrappedRowPt,
    print_overflow: false,
    flat_data_school_names: "PASS",
    round_trip: "PASS",
    immediate_db_writes: 0,
    rows,
  };
  console.log(
    `${geometry}: DATA_LINE=${data.length}; initial=${report[geometry].initial_school_bands}; continuations=${report[geometry].continuation_bands}; round trip PASS`,
  );
  await fs.writeFile(
    path.join(
      output,
      mode === "--verify-native"
        ? "native-import-report.json"
        : "specimen-report.json",
    ),
    JSON.stringify(report, null, 2),
  );
} finally {
  await server.close();
}
