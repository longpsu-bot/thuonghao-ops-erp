import type { Workbook } from "exceljs";
import type { Column, Content, TDocumentDefinitions } from "pdfmake/interfaces";
import type { SchoolDispatchDocument } from "./schoolDispatchReleaseModel";
import companyLogoDataUrl from "../../../assets/thuong-hao-logo.jpg?inline";
import {
  appendDocumentParsingMetadata,
  prepareDocumentParsingColumns,
  writeDocumentParsingRow,
  type DocumentParsingRecord,
} from "../documents/documentParsingMetadata";

import {
  applyDocumentFont,
  borderRow,
  documentStatusLabel,
  documentPdfFooter,
  documentFilePart,
  createDocumentZip,
  finishDocumentSheet,
  formatExactDocumentQuantity,
  initializeDocumentWorkbook,
  prepareDocumentSheet,
  renderDocumentPdf,
  safeWorksheetName,
  setExactQuantity,
  wrappedRowHeight,
} from "../documents/documentPresentation";

const QUANTITY_SCALE = 1_000_000n;

function scaledQuantity(value: string) {
  const match = value.match(/^(\d+)(?:\.(\d{0,6}))?$/);
  if (!match)
    throw new Error("Released PXK contains an invalid exact quantity.");
  return (
    BigInt(match[1]!) * QUANTITY_SCALE + BigInt((match[2] ?? "").padEnd(6, "0"))
  );
}

function dateLabel(value: string) {
  const [year, month, day] = value.split("-");
  return year && month && day ? `${day}/${month}/${year}` : value;
}

export function buildSchoolDispatchExportData(
  document: SchoolDispatchDocument,
) {
  if (
    !document.export_ready ||
    !["RELEASED", "SUPERSEDED"].includes(document.status) ||
    !document.document_number
  ) {
    throw new Error("Only an immutable released PXK snapshot can be exported.");
  }
  for (const line of document.lines) scaledQuantity(line.quantity);
  return {
    documentNumber: document.document_number,
    serviceDate: dateLabel(document.service_date),
    schoolName: document.school_name,
    schoolDisplayOrder: document.school_display_order,
    cookingGroupId: document.cooking_group_id ?? null,
    cookingGroupName: document.cooking_group_name ?? null,
    deliveryLocationName: document.delivery_location_name,
    deliveryAddress: document.delivery_address,
    issuerName: document.document_issuer_name,
    issuerAddress: document.document_issuer_address,
    note: document.note,
    status: document.status,
    lines: document.lines.map((line) => ({
      ingredientName: line.ingredient_name,
      quantity: line.quantity,
      unitCode: line.unit_code,
    })),
  };
}

export function buildSchoolDispatchPdfDefinition(
  document: SchoolDispatchDocument,
): TDocumentDefinitions {
  const data = buildSchoolDispatchExportData(document);
  const quantityWidth = Math.max(
    60,
    ...data.lines.map(
      (line) =>
        formatExactDocumentQuantity(line.quantity).text.length * 8.5 + 6,
    ),
  );
  const cookingHeader: Content[] =
    data.cookingGroupId && data.cookingGroupName
      ? [{ text: `NẤU TẠI: ${data.cookingGroupName}` }]
      : [];
  return {
    pageSize: "A4",
    pageOrientation: quantityWidth > 90 ? "landscape" : "portrait",
    pageMargins: [28, 32, 28, 42],
    footer: documentPdfFooter(
      `${data.documentNumber} · ${documentStatusLabel(document.status)}`,
    ),
    info: {
      title: `Phiếu xuất kho ${data.documentNumber}`,
      creationDate: new Date(document.released_at),
      modDate: new Date(document.released_at),
    },
    content: [
      {
        columns: [
          { image: companyLogoDataUrl, width: 54 },
          {
            stack: [
              { text: data.issuerName, style: "company" },
              { text: `ĐC: ${data.issuerAddress}`, style: "address" },
            ],
            alignment: "center",
          },
        ],
      },
      { text: "PHIẾU XUẤT KHO", style: "heading" },
      {
        columns: [
          { text: `Số phiếu: ${data.documentNumber}`, width: "*" },
          { text: `Ngày: ${data.serviceDate}`, width: 136, alignment: "right" },
        ],
      },
      { text: `TRƯỜNG: ${data.schoolName}` },
      ...cookingHeader,
      { text: `Địa chỉ: ${data.deliveryAddress}` },
      {
        text: [
          { text: documentStatusLabel(document.status), bold: true },
          ` · Điểm giao: ${data.deliveryLocationName}`,
          ...(data.note ? [`\nGhi chú: ${data.note}`] : []),
          ...(document.predecessor_release_id ? ["\nPhiếu thay thế"] : []),
        ],
        fontSize: 11,
        margin: [0, 3, 0, 0],
      },
      {
        table: {
          headerRows: 2,
          widths: [22, "*", 35, quantityWidth, 28, 40, 68, 80],
          heights: 30,
          dontBreakRows: true,
          body: [
            [
              { text: "Stt", bold: true, rowSpan: 2 },
              { text: "Tên thực phẩm", bold: true, rowSpan: 2 },
              { text: "Đvt", bold: true, rowSpan: 2 },
              { text: "Số lượng", bold: true, rowSpan: 2 },
              { text: "Tình trạng cảm quan", bold: true, colSpan: 2 },
              {},
              { text: "Biện pháp xử lý", bold: true, rowSpan: 2 },
              { text: "Ghi chú", bold: true, rowSpan: 2 },
            ],
            [
              "",
              "",
              "",
              "",
              { text: "Đạt", bold: true, noWrap: true },
              { text: "Không đạt", bold: true, noWrap: true },
              "",
              "",
            ],
            ...data.lines.map((line, index) => [
              index + 1,
              line.ingredientName,
              line.unitCode,
              {
                text: formatExactDocumentQuantity(line.quantity).text,
                fontSize: 15,
                noWrap: true,
                alignment: "right" as const,
              },
              "",
              "",
              "",
              "",
            ]),
          ],
        },
        margin: [0, 8, 0, 0],
      },
      {
        columns: [
          "Người nhận hàng",
          "Người giao hàng",
          "Người lập phiếu",
        ].map<Column>((role) => ({
          stack: [
            { text: role, bold: true },
            {
              text: "(Ký, ghi họ tên)",
              italics: true,
              margin: [0, 4, 0, 0],
            },
            { text: " ", margin: [0, 0, 0, 72] },
          ],
          alignment: "center" as const,
        })),
        margin: [0, 52, 0, 0],
        unbreakable: true,
      },
    ],
    defaultStyle: { font: "Roboto", fontSize: 15 },
    styles: {
      company: { bold: true, fontSize: 14, margin: [0, 0, 0, 4] },
      address: { fontSize: 12, margin: [0, 0, 0, 6] },
      heading: {
        bold: true,
        fontSize: 18,
        alignment: "center",
        margin: [0, 10, 0, 10],
      },
    },
  };
}

function addSchoolDispatchSheet(
  workbook: Workbook,
  document: SchoolDispatchDocument,
  sheetName: string,
  logoId: number,
  records: DocumentParsingRecord[],
) {
  const data = buildSchoolDispatchExportData(document);
  const sheet = workbook.addWorksheet(sheetName);
  records.push({
    kind: "DOCUMENT",
    documentId: document.school_dispatch_release_id,
    sheetName,
    rowNumber: null,
    data: {
      document_type: "PXK",
      school_dispatch_release_id: document.school_dispatch_release_id,
      document_number: document.document_number,
      service_date: document.service_date,
      school_id: document.school_id,
      delivery_location_id: document.delivery_location_id,
      cooking_group_id: document.cooking_group_id ?? null,
      version: document.version,
      status: document.status,
      predecessor_release_id: document.predecessor_release_id,
      source_fingerprint: document.source_fingerprint,
      released_at: document.released_at,
    },
  });
  prepareDocumentSheet(sheet);
  const quantityWidth = Math.max(
    10,
    ...data.lines.map(
      (line) =>
        formatExactDocumentQuantity(line.quantity).text.length * 1.53 + 2,
    ),
  );
  const columnWidths = [
    7,
    quantityWidth > 18
      ? Math.max(30, 139 - 7 - 8 - quantityWidth - 8 - 8 - 20 - 24)
      : 30 + Math.max(0, 12.28515625 - quantityWidth),
    8,
    quantityWidth,
    7,
    11,
    19,
    23,
  ];
  sheet.pageSetup.orientation = quantityWidth > 18 ? "landscape" : "portrait";
  // Fixed scale keeps the signature block together at manual page breaks.
  sheet.pageSetup.fitToPage = quantityWidth <= 18;
  columnWidths.forEach(
    (width, index) => (sheet.getColumn(index + 1).width = width),
  );
  const formWidth = columnWidths.reduce((sum, width) => sum + width, 0);
  sheet.mergeCells("A1:A3");
  sheet.getRow(3).height = 10;
  sheet.addImage(logoId, {
    tl: { col: 0, row: 0 },
    ext: { width: 58, height: 58 },
  });
  sheet.mergeCells("B1:H1");
  sheet.getCell("B1").value = data.issuerName;
  sheet.getCell("B1").font = { name: "Times New Roman", size: 14, bold: true };
  sheet.getCell("B1").alignment = { horizontal: "center" };
  sheet.mergeCells("B2:H2");
  sheet.getCell("B2").value = `ĐC: ${data.issuerAddress}`;
  sheet.getCell("B2").alignment = { horizontal: "center" };
  sheet.getRow(1).height = wrappedRowHeight(
    data.issuerName,
    formWidth - 7,
    14,
    28,
  );
  sheet.getRow(2).height = wrappedRowHeight(
    `ĐC: ${data.issuerAddress}`,
    formWidth - 7,
    12,
    24,
  );
  sheet.mergeCells("A4:H4");
  sheet.getCell("A4").value = "PHIẾU XUẤT KHO";
  sheet.getCell("A4").font = { name: "Times New Roman", bold: true, size: 20 };
  sheet.getCell("A4").alignment = { horizontal: "center" };

  sheet.mergeCells("A5:E5");
  sheet.getCell("A5").value = `Số phiếu: ${data.documentNumber}`;
  sheet.getCell("F5").value = "Ngày:";
  sheet.mergeCells("G5:H5");
  sheet.getCell("G5").value = data.serviceDate;
  sheet.getCell("G5").alignment = { horizontal: "center" };
  sheet.getRow(5).height = 22;
  sheet.mergeCells("A6:H6");
  sheet.getCell("A6").value =
    `TRƯỜNG: ${data.schoolName}${data.cookingGroupId && data.cookingGroupName ? `\nNẤU TẠI: ${data.cookingGroupName}` : ""}`;
  sheet.mergeCells("A7:H7");
  sheet.getCell("A7").value = `Địa chỉ: ${data.deliveryAddress}`;
  sheet.mergeCells("A8:H8");
  sheet.getCell("A8").value = {
    richText: [
      {
        text: documentStatusLabel(document.status),
        font: { name: "Times New Roman", size: 11, bold: true },
      },
      {
        text: ` · Điểm giao: ${data.deliveryLocationName}${data.note ? `\nGhi chú: ${data.note}` : ""}${document.predecessor_release_id ? "\nPhiếu thay thế" : ""}`,
        font: { name: "Times New Roman", size: 11 },
      },
    ],
  };
  sheet.getCell("A8").font = { name: "Times New Roman", size: 11 };
  sheet.getRow(8).height = wrappedRowHeight(
    sheet.getCell("A8").text,
    formWidth,
    11,
    20,
  );
  for (const r of [6, 7]) {
    sheet.getCell(r, 1).font = { name: "Times New Roman", size: 14 };
    sheet.getRow(r).height = wrappedRowHeight(
      String(sheet.getCell(r, 1).value ?? ""),
      formWidth,
      14,
      24,
    );
  }
  sheet.getRow(4).height = 30;
  sheet.mergeCells("A9:A10");
  sheet.mergeCells("B9:B10");
  sheet.mergeCells("C9:C10");
  sheet.mergeCells("D9:D10");
  sheet.mergeCells("E9:F9");
  sheet.mergeCells("G9:G10");
  sheet.mergeCells("H9:H10");
  sheet.getCell("A9").value = "Stt";
  sheet.getCell("B9").value = "Tên thực phẩm";
  sheet.getCell("C9").value = "Đvt";
  sheet.getCell("D9").value = "Số lượng";
  sheet.getCell("E9").value = "Tình trạng cảm quan";
  sheet.getCell("E10").value = "Đạt";
  sheet.getCell("F10").value = "Không đạt";
  sheet.getCell("G9").value = "Biện pháp xử lý";
  sheet.getCell("H9").value = "Ghi chú";
  for (const rowNumber of [9, 10]) {
    const header = sheet.getRow(rowNumber);
    header.height = rowNumber === 9 ? 40 : 28;
    header.font = { name: "Times New Roman", bold: true, size: 16 };
    header.alignment = {
      horizontal: "center",
      vertical: "middle",
      wrapText: true,
    };
    borderRow(header);
  }
  for (const cell of [sheet.getCell("E10"), sheet.getCell("F10")])
    cell.alignment = {
      horizontal: "center",
      vertical: "middle",
      wrapText: false,
    };
  data.lines.forEach((line, index) => {
    const row = sheet.getRow(11 + index);
    row.values = [
      index + 1,
      line.ingredientName,
      line.unitCode,
      null,
      "",
      "",
      "",
      "",
    ];
    row.height = wrappedRowHeight(line.ingredientName, columnWidths[1]!, 16);
    row.font = { name: "Times New Roman", size: 16 };
    row.alignment = { vertical: "middle", wrapText: true };
    setExactQuantity(row.getCell(4), line.quantity);
    row.getCell(4).font = { name: "Times New Roman", size: 16 };
    borderRow(row);
    const sourceLine = document.lines[index]!;
    const lineId = sourceLine.school_dispatch_release_line_id ?? null;
    const sources = sourceLine.sources.length
      ? sourceLine.sources.map((source) => ({
          school_dispatch_release_line_id: lineId,
          ...source,
        }))
      : [{ school_dispatch_release_line_id: lineId }];
    writeDocumentParsingRow(
      sheet,
      row,
      8,
      [
        document.school_dispatch_release_id,
        sourceLine.ingredient_id,
        sourceLine.unit_id,
        document.school_id,
        document.delivery_location_id,
        document.cooking_group_id ?? null,
        sourceLine.quantity,
        "ITEM",
      ],
      sources,
      records,
    );
  });
  const signatureRow = 11 + data.lines.length + 5;
  for (const row of [signatureRow, signatureRow + 1, signatureRow + 6]) {
    sheet.mergeCells(row, 1, row, 2);
    sheet.mergeCells(row, 3, row, 5);
    sheet.mergeCells(row, 6, row, 8);
  }
  for (const [index, column] of [1, 3, 6].entries()) {
    sheet.getCell(signatureRow, column).value = [
      "Người nhận hàng",
      "Người giao hàng",
      "Người lập phiếu",
    ][index]!;
    sheet.getCell(signatureRow, column).font = {
      name: "Times New Roman",
      size: 16,
      bold: true,
    };
    sheet.getCell(signatureRow, column).alignment = {
      horizontal: "center",
      vertical: "top",
      wrapText: true,
    };
    sheet.getCell(signatureRow + 1, column).value = "(Ký, ghi họ tên)";
    sheet.getCell(signatureRow + 1, column).font = {
      name: "Times New Roman",
      size: 16,
      italic: true,
    };
    sheet.getCell(signatureRow + 1, column).alignment = {
      horizontal: "center",
      vertical: "top",
    };
  }
  sheet.getRow(signatureRow).height = 24;
  sheet.getRow(signatureRow + 1).height = 24;
  sheet.getRow(signatureRow + 6).height = 24;
  // ponytail: conservative native A4/TNR budget; keep the separated roles,
  // instructions and handwriting rows together. Native print QA verifies it.
  const rowHeight = (number: number) => sheet.getRow(number).height ?? 20;
  const landscape = sheet.pageSetup.orientation === "landscape";
  const signatureBlockStart = signatureRow - 5;
  if (landscape)
    for (let number = signatureBlockStart; number < signatureRow; number++)
      sheet.getRow(number).height = 10;
  const scale = Math.min(
    1,
    ((landscape ? 841.89 : 595.28) - 0.6 * 72) / (formWidth * 5.25),
  );
  const pageHeight = ((landscape ? 595.28 : 841.89) - 0.9 * 72) / scale - 20;
  const headerHeight = Array.from({ length: 10 }, (_, i) =>
    rowHeight(i + 1),
  ).reduce((a, b) => a + b, 0);
  let remaining = pageHeight;
  for (let number = 1; number < signatureBlockStart; number++) {
    const height = rowHeight(number);
    if (height > remaining) remaining = pageHeight - headerHeight;
    remaining -= height;
  }
  const signatureHeight = Array.from({ length: 12 }, (_, i) =>
    rowHeight(signatureBlockStart + i),
  ).reduce((a, b) => a + b, 0);
  if (remaining < signatureHeight + 20)
    sheet.getRow(signatureBlockStart - 1).addPageBreak();
  applyDocumentFont(sheet);
  finishDocumentSheet(
    sheet,
    "H",
    10,
    `${data.documentNumber} · ${documentStatusLabel(document.status)}`,
  );
  prepareDocumentParsingColumns(sheet, 8, 10);
}

export async function createSchoolDispatchXlsx(
  document: SchoolDispatchDocument,
) {
  const ExcelJS = (await import("exceljs")).default;
  const workbook = new ExcelJS.Workbook();
  initializeDocumentWorkbook(workbook, "Phiếu xuất kho", document.released_at);
  const logoId = workbook.addImage({
    base64: companyLogoDataUrl,
    extension: "jpeg",
  });
  const records: DocumentParsingRecord[] = [];
  addSchoolDispatchSheet(
    workbook,
    document,
    safeWorksheetName(document.school_name, new Set(["_atlas_meta"])),
    logoId,
    records,
  );
  appendDocumentParsingMetadata(workbook, records);
  return workbook.xlsx.writeBuffer();
}

export async function createGroupedSchoolDispatchXlsx(
  documents: SchoolDispatchDocument[],
) {
  if (!documents.length)
    throw new Error("At least one released PXK snapshot is required.");
  const ExcelJS = (await import("exceljs")).default;
  const workbook = new ExcelJS.Workbook();
  initializeDocumentWorkbook(
    workbook,
    "Phiếu xuất kho theo ngày",
    [...documents].map((d) => d.released_at).sort()[0],
  );
  const logoId = workbook.addImage({
    base64: companyLogoDataUrl,
    extension: "jpeg",
  });
  const names = new Set<string>(["_atlas_meta"]);
  const records: DocumentParsingRecord[] = [];
  const ordered = [...documents].sort(
    (left, right) =>
      left.service_date.localeCompare(right.service_date) ||
      left.school_display_order - right.school_display_order ||
      left.school_name.localeCompare(right.school_name, "vi") ||
      left.document_number.localeCompare(right.document_number),
  );
  for (const document of ordered) {
    const name = safeWorksheetName(
      `${document.service_date.slice(5)} ${document.school_name}`,
      names,
    );
    addSchoolDispatchSheet(workbook, document, name, logoId, records);
  }
  appendDocumentParsingMetadata(workbook, records);
  return workbook.xlsx.writeBuffer();
}

export async function createSchoolDispatchPdf(
  document: SchoolDispatchDocument,
) {
  const definition = buildSchoolDispatchPdfDefinition(document);
  return renderDocumentPdf(definition);
}

function safeStem(document: SchoolDispatchDocument) {
  const school = documentFilePart(document.school_name);
  return `${school}-${document.service_date}-${document.document_number}`;
}

function downloadBytes(
  bytes: ArrayBuffer | Uint8Array,
  mimeType: string,
  fileName: string,
) {
  const blob = new Blob([bytes as BlobPart], { type: mimeType });
  const url = URL.createObjectURL(blob);
  const anchor = window.document.createElement("a");
  anchor.href = url;
  anchor.download = fileName;
  anchor.click();
  URL.revokeObjectURL(url);
}

export async function downloadSchoolDispatchXlsx(
  document: SchoolDispatchDocument,
) {
  downloadBytes(
    await createSchoolDispatchXlsx(document),
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    `${safeStem(document)}.xlsx`,
  );
}

export async function downloadGroupedSchoolDispatchXlsx(
  documents: SchoolDispatchDocument[],
) {
  const orderedDates = [
    ...new Set(documents.map((item) => item.service_date)),
  ].sort();
  downloadBytes(
    await createGroupedSchoolDispatchXlsx(documents),
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    `PXK-GROUPED-${orderedDates[0]}-${orderedDates.at(-1)}.xlsx`,
  );
}

export async function downloadSchoolDispatchPdf(
  document: SchoolDispatchDocument,
) {
  downloadBytes(
    await createSchoolDispatchPdf(document),
    "application/pdf",
    `${safeStem(document)}.pdf`,
  );
}

export type SchoolDispatchZipMode = "date" | "entity";

export async function createSchoolDispatchZip(
  documents: SchoolDispatchDocument[],
  mode: SchoolDispatchZipMode = "date",
) {
  if (!["date", "entity"].includes(mode))
    throw new Error("Invalid Dispatch ZIP mode.");
  const groups = new Map<string, SchoolDispatchDocument[]>();
  const ids = new Set<string>();
  const ordered = [...documents].sort(
    (a, b) =>
      a.service_date.localeCompare(b.service_date) ||
      a.school_display_order - b.school_display_order ||
      a.school_id.localeCompare(b.school_id) ||
      a.delivery_location_id.localeCompare(b.delivery_location_id) ||
      a.school_dispatch_release_id.localeCompare(b.school_dispatch_release_id),
  );
  for (const document of ordered) {
    buildSchoolDispatchExportData(document);
    if (ids.has(document.school_dispatch_release_id))
      throw new Error("Duplicate PXK identity.");
    ids.add(document.school_dispatch_release_id);
    const key =
      mode === "date"
        ? document.service_date
        : document.cooking_group_id && document.cooking_group_name
          ? JSON.stringify(["COOKING_GROUP", document.cooking_group_id])
          : JSON.stringify([
              "SCHOOL",
              document.school_id,
              document.delivery_location_id,
            ]);
    const group = groups.get(key) ?? [];
    group.push(document);
    groups.set(key, group);
  }
  const files = [];
  for (const [index, group] of [...groups.values()].entries()) {
    const first = group[0]!;
    const stem =
      mode === "date"
        ? `Dispatch-${first.service_date}`
        : `Dispatch-${first.cooking_group_id && first.cooking_group_name ? documentFilePart(first.cooking_group_name) : `${documentFilePart(first.school_name)}-${documentFilePart(first.delivery_location_name)}`}-${index + 1}-${first.service_date}-${group.at(-1)!.service_date}`;
    files.push({
      name: `${stem}.xlsx`,
      bytes: await createGroupedSchoolDispatchXlsx(group),
    });
  }
  return createDocumentZip(files);
}

export async function downloadSchoolDispatchZip(
  documents: SchoolDispatchDocument[],
  mode: SchoolDispatchZipMode = "date",
) {
  downloadBytes(
    await createSchoolDispatchZip(documents, mode),
    "application/zip",
    `Dispatch-${mode}.zip`,
  );
}
