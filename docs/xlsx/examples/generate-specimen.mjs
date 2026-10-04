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
const print = layout.print;
const outputPath = path.resolve(
  process.argv[2] ?? path.join(here, "atlas-shopping-list-v1-example.xlsx"),
);
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
function bodyRowClass(row, startsSchool) {
  const cases = fixture.print_cases;
  if (
    cases.two_line_ingredient_ids.includes(row.ingredient_id) ||
    (startsSchool && cases.two_line_school_ids.includes(row.school_id))
  )
    return "twoLineRowPt";
  return startsSchool ? "schoolRowPt" : "normalRowPt";
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
    size: print.bodyFontPt,
    color: "#000000",
  };
  sheet.getRange(`A1:Q${end}`).format.verticalAlignment = "center";
  const title = `${weekdays[new Date(`${date}T00:00:00Z`).getUTCDay()]} (${date.split("-").reverse().join("/")})`;
  sheet.mergeCells("A1:E1");
  sheet.getRange("A1").values = [[title]];
  sheet.getRange("A1:E1").format.font = {
    name: "Times New Roman",
    size: print.titleFontPt,
    bold: true,
    color: "#000000",
  };
  sheet.getRange("A1:E1").format.horizontalAlignment = "center";
  sheet.getRange("A1:E1").format.rowHeight = print.titleRowPt;
  sheet.getRange("A2:E2").format.rowHeight = print.spacerRowPt;
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
  const widths = print.columnWidths;
  for (let col = 0; col < widths.length; col++) {
    const letter = String.fromCharCode(65 + col);
    sheet.getRange(`${letter}1:${letter}${end}`).format.columnWidth =
      widths[col];
  }
  sheet.getRange(`A4:A${end}`).format.wrapText = true;
  sheet.getRange(`B4:B${end}`).format.wrapText = true;
  sheet.getRange(`E4:E${end}`).format.wrapText = true;
  sheet.getRange(`C4:D${end}`).format.wrapText = false;
  sheet.getRange(`A4:E${end}`).format.rowHeight = print.normalRowPt;
  sheet.getRange(`A4:E${end}`).format.fill = "#FFFFFF";
  sheet.getRange(`E4:E${end}`).format.font = {
    name: "Times New Roman",
    size: print.supplierFontPt,
    color: "#000000",
  };
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
    const startsSchool = Boolean(data[index][0]);
    sheet.getRange(`A${rowNumber}:E${rowNumber}`).format.rowHeight =
      print[bodyRowClass(row, startsSchool)];
    if (!row.exact_quantity.includes("."))
      sheet.getRange(`D${rowNumber}`).setNumberFormat("0");
    const group = `${row.school_id}:${row.delivery_location_id}`;
    if (school !== group) {
      sheet.getRange(`A${rowNumber}:E${rowNumber}`).format.borders = {
        top: { style: "medium", color: "#000000" },
      };
      sheet.getRange(`A${rowNumber}`).format.font = {
        name: "Times New Roman",
        size: print.schoolFontPt,
        bold: true,
        color: "#000000",
      };
    }
    school = group;
  });
  sheet.getRange(`A${end}:E${end}`).format.borders = {
    bottom: { style: "medium", color: "#000000" },
  };
  rows.forEach((row, index) => {
    const rowNumber = index + 4;
    const first =
      index === 0 ||
      row.school_id !== rows[index - 1].school_id ||
      row.delivery_location_id !== rows[index - 1].delivery_location_id;
    const top = { style: first ? "medium" : "thin", color: "#000000" };
    const bottom = {
      style: index === rows.length - 1 ? "medium" : "thin",
      color: "#000000",
    };
    sheet.getRange(`A${rowNumber}`).format.borders = {
      top,
      bottom,
      left: { style: "medium", color: "#000000" },
      right: { style: "thin", color: "#000000" },
    };
    sheet.getRange(`E${rowNumber}`).format.borders = {
      top,
      bottom,
      left: { style: "thin", color: "#000000" },
      right: { style: "medium", color: "#000000" },
    };
  });
  sheet.getRange("A3:E3").format = {
    fill: "#FFFFFF",
    font: {
      name: "Times New Roman",
      size: print.headerFontPt,
      bold: true,
      color: "#000000",
    },
    horizontalAlignment: "center",
    verticalAlignment: "center",
    rowHeight: print.headerRowPt,
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
await fs.mkdir(path.dirname(outputPath), { recursive: true });
await (await SpreadsheetFile.exportXlsx(workbook)).save(outputPath);
console.log(
  `Base specimen: ${outputPath}; run finalize-specimen.py before review.`,
);
