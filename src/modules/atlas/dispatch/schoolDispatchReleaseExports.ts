import type { Workbook } from "exceljs";
import type { TDocumentDefinitions } from "pdfmake/interfaces";
import type { SchoolDispatchDocument } from "./schoolDispatchReleaseModel";
import companyLogoDataUrl from "../../../assets/thuong-hao-logo.jpg?inline";

import {
  applyDocumentFont,
  borderRow,
  documentStatusLabel,
  documentPdfFooter,
  documentFilePart,
  finishDocumentSheet,
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
  return {
    pageSize: "A4",
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
          { text: "", width: 54 },
        ],
      },
      { text: "PHIẾU XUẤT KHO", style: "heading" },
      {
        text: documentStatusLabel(document.status),
        bold: true,
        margin: [0, 0, 0, 8],
      },
      ...(document.predecessor_release_id
        ? [{ text: `Thay thế phiếu: ${document.predecessor_release_id}` }]
        : []),
      { text: `Số phiếu: ${data.documentNumber}` },
      { text: `Ngày phục vụ: ${data.serviceDate}` },
      { text: `Trường: ${data.schoolName}` },
      { text: `Điểm giao: ${data.deliveryLocationName}` },
      { text: `Địa chỉ: ${data.deliveryAddress}` },
      ...(data.note ? [{ text: `Ghi chú: ${data.note}` }] : []),
      {
        table: {
          headerRows: 2,
          widths: [20, "*", 30, 120, 30, 30, 65],
          dontBreakRows: true,
          body: [
            [
              { text: "Stt", rowSpan: 2 },
              { text: "Tên thực phẩm", rowSpan: 2 },
              { text: "Đvt", rowSpan: 2 },
              { text: "Số lượng", rowSpan: 2 },
              { text: "Tình trạng cảm quan", colSpan: 2 },
              {},
              { text: "Biện pháp xử lý", rowSpan: 2 },
            ],
            ["", "", "", "", "Đạt", "K Đạt", ""],
            ...data.lines.map((line, index) => [
              index + 1,
              line.ingredientName,
              line.unitCode,
              { text: line.quantity, alignment: "right" as const },
              "",
              "",
              "",
            ]),
          ],
        },
        margin: [0, 12, 0, 0],
      },
      {
        columns: [
          { text: "Người nhận hàng\n(Ký, ghi họ tên)", alignment: "center" },
          { text: "Người giao hàng\n(Ký, ghi họ tên)", alignment: "center" },
          { text: "Người lập phiếu\n(Ký, ghi họ tên)", alignment: "center" },
        ],
        bold: true,
        margin: [0, 28, 0, 50],
        unbreakable: true,
      },
    ],
    defaultStyle: { font: "Roboto", fontSize: 10 },
    styles: {
      company: { bold: true, fontSize: 9, margin: [0, 0, 0, 4] },
      address: { fontSize: 8, margin: [0, 0, 0, 6] },
      heading: { bold: true, fontSize: 17, margin: [0, 0, 0, 10] },
    },
  };
}

function addSchoolDispatchSheet(
  workbook: Workbook,
  document: SchoolDispatchDocument,
  sheetName: string,
  logoId: number,
) {
  const data = buildSchoolDispatchExportData(document);
  const sheet = workbook.addWorksheet(sheetName);
  prepareDocumentSheet(sheet);
  sheet.mergeCells("A3:G3");
  sheet.getCell("A3").value = documentStatusLabel(document.status);
  sheet.getCell("A3").font = { name: "Times New Roman", size: 11, bold: true };
  sheet.getRow(3).height = 24;
  sheet.addImage(logoId, {
    tl: { col: 0, row: 0 },
    ext: { width: 58, height: 58 },
  });
  sheet.mergeCells("A1:G1");
  sheet.getCell("A1").value = data.issuerName;
  sheet.getCell("A1").alignment = { horizontal: "center" };
  sheet.mergeCells("A2:G2");
  sheet.getCell("A2").value = `ĐC: ${data.issuerAddress}`;
  sheet.getCell("A2").alignment = { horizontal: "center" };
  sheet.mergeCells("A4:G4");
  sheet.getCell("A4").value = "PHIẾU XUẤT KHO";
  sheet.getCell("A4").font = { name: "Times New Roman", bold: true, size: 20 };
  sheet.getCell("A4").alignment = { horizontal: "center" };

  sheet.mergeCells("A5:G5");
  sheet.getCell("A5").value = `Số phiếu: ${data.documentNumber}`;
  sheet.getRow(5).height = 22;
  sheet.mergeCells("A6:G6");
  sheet.getCell("A6").value = `Trường: ${data.schoolName}`;
  sheet.mergeCells("A7:G7");
  sheet.getCell("A7").value = `Địa chỉ: ${data.deliveryAddress}`;
  sheet.mergeCells("A8:G8");
  sheet.getCell("A8").value =
    `Ngày: ${data.serviceDate} · Điểm giao: ${data.deliveryLocationName}${data.note ? `\nGhi chú: ${data.note}` : ""}${document.predecessor_release_id ? `\nThay thế phiếu: ${document.predecessor_release_id}` : ""}`;
  for (const r of [1, 2, 6, 7, 8])
    sheet.getRow(r).height = wrappedRowHeight(
      String(sheet.getCell(r, 1).value ?? ""),
      112,
      12,
      r === 1 ? 28 : 24,
    );
  sheet.getRow(4).height = 30;
  sheet.mergeCells("A9:A10");
  sheet.mergeCells("B9:B10");
  sheet.mergeCells("C9:C10");
  sheet.mergeCells("D9:D10");
  sheet.mergeCells("E9:F9");
  sheet.mergeCells("G9:G10");
  sheet.getCell("A9").value = "Stt";
  sheet.getCell("B9").value = "Tên thực phẩm";
  sheet.getCell("C9").value = "Đvt";
  sheet.getCell("D9").value = "Số lượng";
  sheet.getCell("E9").value = "Tình trạng cảm quan";
  sheet.getCell("E10").value = "Đạt";
  sheet.getCell("F10").value = "K Đạt";
  sheet.getCell("G9").value = "Biện pháp xử lý";
  for (const rowNumber of [9, 10]) {
    const header = sheet.getRow(rowNumber);
    header.height = 30;
    header.font = { name: "Times New Roman", bold: true, size: 12 };
    header.alignment = {
      horizontal: "center",
      vertical: "middle",
      wrapText: true,
    };
    borderRow(header);
  }
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
    ];
    row.height = wrappedRowHeight(line.ingredientName, 38, 14);
    row.font = { name: "Times New Roman", size: 14 };
    row.alignment = { vertical: "middle", wrapText: true };
    setExactQuantity(row.getCell(4), line.quantity);
    borderRow(row);
  });
  [6, 38, 8, 24, 8, 8, 20].forEach(
    (width, index) => (sheet.getColumn(index + 1).width = width),
  );
  const signatureRow = 11 + data.lines.length + 2;
  sheet.mergeCells(signatureRow, 1, signatureRow, 2);
  sheet.mergeCells(signatureRow, 3, signatureRow, 5);
  sheet.mergeCells(signatureRow, 6, signatureRow, 7);
  sheet.getCell(signatureRow, 1).value = "Người nhận hàng\n(Ký, ghi họ tên)";
  sheet.getCell(signatureRow, 3).value = "Người giao hàng\n(Ký, ghi họ tên)";
  sheet.getCell(signatureRow, 6).value = "Người lập phiếu\n(Ký, ghi họ tên)";
  for (const column of [1, 3, 6]) {
    sheet.getCell(signatureRow, column).font = {
      name: "Times New Roman",
      size: 14,
      bold: true,
    };
    sheet.getCell(signatureRow, column).alignment = {
      horizontal: "center",
      vertical: "top",
      wrapText: true,
    };
  }
  // One physical row keeps all three signature areas together during printing.
  sheet.getRow(signatureRow).height = 102;
  applyDocumentFont(sheet);
  finishDocumentSheet(
    sheet,
    "G",
    10,
    `${data.documentNumber} · ${documentStatusLabel(document.status)}`,
  );
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
  addSchoolDispatchSheet(
    workbook,
    document,
    safeWorksheetName(document.school_name),
    logoId,
  );
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
  const names = new Set<string>();
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
    addSchoolDispatchSheet(workbook, document, name, logoId);
  }
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
