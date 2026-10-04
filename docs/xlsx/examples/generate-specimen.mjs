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
const supplierById = new Map(
  fixture.suppliers.map((supplier) => [supplier.supplier_id, supplier]),
);
function preferredSupplier(row) {
  const candidates = fixture.supplier_eligibilities
    .filter(
      (entry) =>
        entry.ingredient_id === row.ingredient_id &&
        entry.eligibility_status === "ACTIVE" &&
        entry.effective_from <= row.service_date &&
        (!entry.effective_to || row.service_date < entry.effective_to) &&
        supplierById.get(entry.supplier_id)?.supplier_status === "ACTIVE",
    )
    .sort((left, right) => left.priority - right.priority);
  if (
    !candidates.length ||
    !Number.isInteger(candidates[0].priority) ||
    (candidates[1] && candidates[1].priority === candidates[0].priority)
  )
    return "";
  return supplierById.get(candidates[0].supplier_id).supplier_name;
}
function rowHeight(row, schoolName, supplierName) {
  const lines = Math.max(
    Math.ceil(schoolName.length / 12),
    Math.ceil(row.ingredient_name.length / 31),
    Math.ceil(supplierName.length / 18),
    1,
  );
  return Math.min(
    96,
    Math.max(
      schoolName ? 32 : 29,
      lines * 18 + 6,
      supplierName ? Math.ceil(supplierName.length / 18) * 18 + 16 : 0,
      schoolName.length > 30 ? 96 : 0,
    ),
  );
}
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
  const end = rows.length + 3;
  sheet.getRange(`A1:Q${end}`).format.font = {
    name: "Times New Roman",
    size: 15,
    color: "#000000",
  };
  sheet.getRange(`A1:Q${end}`).format.verticalAlignment = "center";
  const title = `${weekdays[new Date(`${date}T00:00:00Z`).getUTCDay()]} (${date.split("-").reverse().join("/")})`;
  sheet.mergeCells("A1:E1");
  sheet.getRange("A1").values = [[title]];
  sheet.getRange("A1:E1").format.font = {
    name: "Times New Roman",
    size: 20,
    bold: true,
    color: "#000000",
  };
  sheet.getRange("A1:E1").format.horizontalAlignment = "center";
  sheet.getRange("A1:E1").format.rowHeight = 36;
  sheet.getRange("A2:E2").format.rowHeight = 9;
  sheet.getRange("A3:Q3").values = [
    [...layout.visibleHeaders, ...layout.hiddenHeaders],
  ];
  let precedingSchool;
  const data = rows.map((row) => {
    const group = `${row.school_id}:${row.delivery_location_id}`;
    const first = group !== precedingSchool;
    precedingSchool = group;
    const school = first
      ? row.school_name +
        (locations.get(row.school_id).size > 1
          ? `\nĐiểm giao: ${row.delivery_location_name}`
          : "")
      : "";
    const supplier = preferredSupplier(row);
    return [
      school,
      row.ingredient_name,
      row.unit_code,
      row.exact_quantity.replace(/(\.\d*?)0+$/, "$1").replace(/\.$/, ""),
      supplier,
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
      supplier,
    ];
  });
  const visibleKeys = rows.map((row) =>
    JSON.stringify([
      row.school_name +
        (locations.get(row.school_id).size > 1
          ? `\nĐiểm giao: ${row.delivery_location_name}`
          : ""),
      row.ingredient_name,
      row.unit_code,
    ]),
  );
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
  const widths = [17.5, 35, 7.5, 13, 20];
  for (let col = 0; col < widths.length; col++) {
    const letter = String.fromCharCode(65 + col);
    sheet.getRange(`${letter}1:${letter}${end}`).format.columnWidth =
      widths[col];
  }
  sheet.getRange(`A3:E${end}`).format.wrapText = true;
  sheet.getRange(`A4:E${end}`).format.rowHeight = 29;
  sheet.getRange(`A4:E${end}`).format.fill = "#FFFFFF";
  sheet.getRange(`D4:D${end}`).setNumberFormat("0.######");
  sheet.getRange(`D4:D${end}`).format.horizontalAlignment = "right";
  sheet.getRange(`C4:C${end}`).format.horizontalAlignment = "center";
  sheet.getRange(`E4:E${end}`).format.horizontalAlignment = "left";
  sheet.getRange(`A4:E${end}`).format.borders = {
    top: { style: "thin", color: "#000000" },
    bottom: { style: "thin", color: "#000000" },
    left: { style: "thin", color: "#000000" },
    right: { style: "thin", color: "#000000" },
    insideHorizontal: { style: "thin", color: "#000000" },
    insideVertical: { style: "thin", color: "#000000" },
  };
  let school;
  rows.forEach((row, index) => {
    const rowNumber = index + 4;
    sheet.getRange(`A${rowNumber}:E${rowNumber}`).format.rowHeight = rowHeight(
      row,
      data[index][0],
      data[index][4],
    );
    if (!row.exact_quantity.includes("."))
      sheet.getRange(`D${rowNumber}`).setNumberFormat("0");
    const group = `${row.school_id}:${row.delivery_location_id}`;
    if (school !== group) {
      sheet.getRange(`A${rowNumber}:E${rowNumber}`).format.borders = {
        top: { style: "medium", color: "#000000" },
      };
      sheet.getRange(`A${rowNumber}`).format.font = {
        name: "Times New Roman",
        size: 15,
        bold: true,
        color: "#000000",
      };
    }
    school = group;
  });
  sheet.getRange("A3:E3").format = {
    fill: "#FFFFFF",
    font: { name: "Times New Roman", size: 15, bold: true, color: "#000000" },
    horizontalAlignment: "center",
    verticalAlignment: "center",
    rowHeight: 39,
    wrapText: true,
    borders: {
      top: { style: "medium", color: "#000000" },
      bottom: { style: "medium", color: "#000000" },
      left: { style: "medium", color: "#000000" },
      right: { style: "medium", color: "#000000" },
      insideVertical: { style: "thin", color: "#000000" },
    },
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
