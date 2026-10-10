import type { Row, Workbook, Worksheet } from "exceljs";

export type DocumentParsingRecord = {
  kind: "DOCUMENT" | "ROW_SOURCE";
  documentId: string;
  sheetName: string;
  rowNumber: number | null;
  data: Record<string, unknown>;
};

const headers = [
  "__document_id",
  "__ingredient_id",
  "__unit_id",
  "__school_id",
  "__location_id",
  "__cooking_group_id",
  "__exported_quantity",
  "__row_kind",
];

export function prepareDocumentParsingColumns(
  sheet: Worksheet,
  visibleColumns: number,
  headerRow: number,
) {
  headers.forEach((header, index) => {
    const column = visibleColumns + index + 1;
    sheet.getColumn(column).hidden = true;
    sheet.getColumn(column).width = 1;
    sheet.getColumn(column).numFmt = "@";
    sheet.getCell(headerRow, column).value = header;
  });
}

export function writeDocumentParsingRow(
  sheet: Worksheet,
  row: Row,
  visibleColumns: number,
  values: [
    string,
    string,
    string,
    string | null,
    string | null,
    string | null,
    string,
    "ITEM" | "CONTINUATION",
  ],
  sources: Record<string, unknown>[],
  records: DocumentParsingRecord[],
) {
  values.forEach((value, index) => {
    const cell = row.getCell(visibleColumns + index + 1);
    cell.value = value;
    cell.numFmt = "@";
  });
  for (const source of sources)
    records.push({
      kind: "ROW_SOURCE",
      documentId: values[0],
      sheetName: sheet.name,
      rowNumber: row.number,
      data: source,
    });
}

export function appendDocumentParsingMetadata(
  workbook: Workbook,
  records: DocumentParsingRecord[],
) {
  const sheet = workbook.addWorksheet("_ATLAS_META", { state: "veryHidden" });
  sheet.addRow(["contract_version", "ATLAS_OPERATIONAL_DOCUMENT_V1"]);
  sheet.addRow([
    "record_kind",
    "document_id",
    "sheet_name",
    "row_number",
    "payload_json",
  ]);
  for (const record of records)
    sheet.addRow([
      record.kind,
      record.documentId,
      record.sheetName,
      record.rowNumber,
      JSON.stringify(record.data),
    ]);
  for (const column of [1, 2, 3, 5]) sheet.getColumn(column).numFmt = "@";
}
