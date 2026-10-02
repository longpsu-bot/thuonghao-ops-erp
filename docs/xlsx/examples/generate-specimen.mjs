// Design-only specimen. Never imported by src/, and never calls a business API.
import fs from "node:fs/promises";
import path from "node:path";
import { createRequire } from "node:module";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const dependencyRoot = process.env.ATLAS_ARTIFACT_NODE_MODULES;
if (!dependencyRoot)
  throw new Error(
    "Set ATLAS_ARTIFACT_NODE_MODULES to the bundled workspace node_modules path.",
  );
const require = createRequire(import.meta.url);
const modulePath = require.resolve("@oai/artifact-tool", {
  paths: [path.dirname(dependencyRoot)],
});
const { Workbook, SpreadsheetFile } = await import(
  pathToFileURL(modulePath).href
);
const fixture = JSON.parse(
  await fs.readFile(
    path.join(here, "atlas-shopping-list-v1.fixture.json"),
    "utf8",
  ),
);
const schema = JSON.parse(
  await fs.readFile(
    path.join(here, "../atlas-shopping-list-xlsx-v1.schema.json"),
    "utf8",
  ),
);
const layout = schema["x-atlas-layout"];
const outputPath = path.resolve(
  process.argv[2] ?? path.join(here, "atlas-shopping-list-v1-example.xlsx"),
);
const previewDir = process.argv[3];
const workbook = Workbook.create();
const dates = [...new Set(fixture.rows.map((row) => row.service_date))].sort();
const weekdays = [
  "Chủ Nhật",
  "Thứ Hai",
  "Thứ Ba",
  "Thứ Tư",
  "Thứ Năm",
  "Thứ Sáu",
  "Thứ Bảy",
];
for (const date of dates) {
  const rows = fixture.rows.filter((row) => row.service_date === date);
  const locations = new Map();
  for (const row of rows) {
    const values = locations.get(row.school_id) ?? new Set();
    values.add(row.delivery_location_id);
    locations.set(row.school_id, values);
  }
  const sheet = workbook.worksheets.add(date);
  sheet.showGridLines = false;
  sheet.freezePanes.freezeRows(3);
  sheet.tabColor = "#35564C";
  const end = rows.length + 3;
  sheet.getRange(`A1:Q${end}`).format.font = {
    name: "Arial",
    size: 11,
    color: "#2A3330",
  };
  sheet.getRange(`A1:Q${end}`).format.verticalAlignment = "center";
  const title = `PHIẾU ĐI CHỢ · ${weekdays[new Date(`${date}T00:00:00Z`).getUTCDay()]} (${date.split("-").reverse().join("/")})`;
  sheet.mergeCells("A1:E1");
  sheet.getRange("A1").values = [[title]];
  sheet.getRange("A1:E1").format.font = {
    name: "Arial",
    size: 17,
    bold: true,
    color: "#35564C",
  };
  sheet.getRange("A1:E1").format.rowHeight = 34;
  sheet.mergeCells("A2:E2");
  sheet.getRange("A2").values = [
    [
      "Mẫu minh họa · GHI CHÚ: NCC dự kiến, chỉ giữ trong file/phiên. Lưu trên Atlas không lưu GHI CHÚ.\nSửa lượng → nhập bản nháp → ghi lý do trên Atlas → Lưu. Nhập lượng lớn hoặc dùng dấu phẩy: thêm dấu ' trước số.\nGiữ phiên Atlas đã xuất file; nếu tải lại/đóng Atlas, phải xuất file mới để nhập thay đổi số lượng.",
    ],
  ];
  sheet.getRange("A2:E2").format.rowHeight = 46;
  sheet.getRange("A2:E2").format.wrapText = true;
  sheet.getRange("A2:E2").format.font = {
    name: "Arial",
    size: 9,
    color: "#5C6964",
  };
  sheet.getRange("A3:Q3").values = [
    [...layout.visibleHeaders, ...layout.hiddenHeaders],
  ];
  const data = rows.map((row) => [
    row.school_name +
      (locations.get(row.school_id).size > 1
        ? `\nĐiểm giao: ${row.delivery_location_name}`
        : ""),
    row.ingredient_name,
    row.unit_code,
    row.exact_quantity.replace(/(\.\d*?)0+$/, "$1").replace(/\.$/, ""),
    row.shopping_note,
    fixture.metadata.workbook_marker,
    row.confirmed_need_line_id,
    row.current_revision_id,
    row.current_decision_id ?? "",
    row.service_date,
    row.school_id,
    row.delivery_location_id,
    row.ingredient_id,
    row.unit_id,
    row.exact_quantity,
    row.reason_code,
    row.shopping_note,
  ]);
  const visibleKeys = data.map((row) => JSON.stringify(row.slice(0, 3)));
  if (new Set(visibleKeys).size !== data.length)
    throw new Error(
      `Ambiguous canonical visible tuple on ${date}; never collapse rows.`,
    );
  sheet.getRange(`A4:Q${end}`).values = data;
  const table = sheet.tables.add(
    `A3:Q${end}`,
    true,
    `AtlasNeed_${date.replaceAll("-", "")}`,
  );
  table.style = "TableStyleLight1";
  table.showTotals = false;
  table.showFilterButton = true;
  const widths = [38, 53, 8, 16, 33];
  for (let col = 0; col < widths.length; col++) {
    const letter = String.fromCharCode(65 + col);
    sheet.getRange(`${letter}1:${letter}${end}`).format.columnWidth =
      widths[col];
  }
  sheet.getRange(`A3:E${end}`).format.wrapText = true;
  sheet.getRange(`A4:E${end}`).format.rowHeight = 34;
  sheet.getRange(`A4:C${end}`).format.fill = "#FFFFFF";
  sheet.getRange(`D4:D${end}`).setNumberFormat("0.######");
  sheet.getRange(`D4:D${end}`).format.horizontalAlignment = "right";
  sheet.getRange(`C4:C${end}`).format.horizontalAlignment = "center";
  sheet.getRange(`D4:E${end}`).format.fill = "#F8F1DF";
  sheet.getRange(`A4:E${end}`).format.borders = {
    insideHorizontal: { style: "thin", color: "#DCE4E0" },
  };
  let school;
  rows.forEach((row, index) => {
    if (!row.exact_quantity.includes("."))
      sheet.getRange(`D${index + 4}`).setNumberFormat("0");
    if (school !== row.school_id) {
      sheet.getRange(`A${index + 4}:E${index + 4}`).format.borders = {
        top: { style: "medium", color: "#567A71" },
      };
      sheet.getRange(`A${index + 4}`).format.font = {
        name: "Arial",
        size: 11,
        bold: true,
        color: "#2A3330",
      };
    }
    school = row.school_id;
  });
  sheet.getRange("A3:E3").format = {
    fill: "#35564C",
    font: { name: "Arial", size: 11, bold: true, color: "#FFFFFF" },
    horizontalAlignment: "center",
    verticalAlignment: "center",
    rowHeight: 30,
    wrapText: true,
    borders: { insideVertical: { style: "thin", color: "#FFFFFF" } },
  };
}
const meta = workbook.worksheets.add(layout.metadataSheet);
meta.getRange("A1:B10").values = Object.entries(fixture.metadata).map(
  ([key, value]) => [key, String(value)],
);
meta.getRange("A1:B10").format.font = { name: "Arial", size: 11 };
meta.getRange("A1:A10").format.columnWidth = 30;
meta.getRange("B1:B10").format.columnWidth = 42;
workbook.recalculate();
console.log(
  (
    await workbook.inspect({
      kind: "table",
      range: `${dates[0]}!A3:E7`,
      include: "values,formulas",
      tableMaxRows: 5,
      tableMaxCols: 5,
      maxChars: 1800,
    })
  ).ndjson,
);
if (previewDir) {
  await fs.mkdir(previewDir, { recursive: true });
  for (const date of dates) {
    const preview = await workbook.render({
      sheetName: date,
      range: "A1:E17",
      scale: 1.3,
      format: "png",
    });
    await fs.writeFile(
      path.join(previewDir, `${date}.png`),
      new Uint8Array(await preview.arrayBuffer()),
    );
  }
}
await fs.mkdir(path.dirname(outputPath), { recursive: true });
await (await SpreadsheetFile.exportXlsx(workbook)).save(outputPath);
console.log(
  `Base specimen: ${outputPath}; run finalize-specimen.py before review.`,
);
