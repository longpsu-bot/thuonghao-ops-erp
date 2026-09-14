import type { Cell, Row, Workbook, Worksheet } from "exceljs";
import type { TDocumentDefinitions } from "pdfmake/interfaces";
import type { SchoolDispatchDocument } from "./schoolDispatchReleaseModel";
import companyLogoDataUrl from "../../../assets/thuong-hao-logo.jpg?inline";

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
    info: { title: `Phiếu xuất kho ${data.documentNumber}` },
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
      { text: `Số phiếu: ${data.documentNumber}` },
      { text: `Ngày phục vụ: ${data.serviceDate}` },
      { text: `Trường: ${data.schoolName}` },
      { text: `Điểm giao: ${data.deliveryLocationName}` },
      { text: `Địa chỉ: ${data.deliveryAddress}` },
      ...(data.note ? [{ text: `Ghi chú: ${data.note}` }] : []),
      {
        table: {
          headerRows: 2,
          widths: [25, "*", 35, 55, 38, 38, 70],
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
              line.quantity,
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
        margin: [0, 28, 0, 0],
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

function borderRow(row: Row) {
  row.eachCell((cell) => {
    cell.border = {
      top: { style: "thin", color: { argb: "FF7F7F7F" } },
      left: { style: "thin", color: { argb: "FF7F7F7F" } },
      bottom: { style: "thin", color: { argb: "FF7F7F7F" } },
      right: { style: "thin", color: { argb: "FF7F7F7F" } },
    };
  });
}

function exactExcelQuantity(cell: Cell, value: string) {
  const governed = scaledQuantity(value);
  const numeric = Number(value);
  const scaled = numeric * Number(QUANTITY_SCALE);
  cell.value =
    Number.isFinite(numeric) &&
    Number.isSafeInteger(scaled) &&
    BigInt(scaled) === governed
      ? numeric
      : value;
  if (typeof cell.value === "number") cell.numFmt = "General";
  cell.alignment = { horizontal: "right" };
}

function prepareWorksheet(worksheet: Worksheet) {
  worksheet.views = [{ showGridLines: false }];
  worksheet.pageSetup = {
    paperSize: 9,
    orientation: "portrait",
    fitToPage: true,
    fitToWidth: 1,
    fitToHeight: 0,
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
  prepareWorksheet(sheet);
  sheet.addImage(logoId, {
    tl: { col: 0, row: 0 },
    ext: { width: 58, height: 58 },
  });
  sheet.mergeCells("A1:G1");
  sheet.getCell("A1").value = data.issuerName;
  sheet.mergeCells("A2:G2");
  sheet.getCell("A2").value = `ĐC: ${data.issuerAddress}`;
  sheet.mergeCells("A4:G4");
  sheet.getCell("A4").value = "PHIẾU XUẤT KHO";
  sheet.getCell("A4").font = { name: "Times New Roman", bold: true, size: 20 };
  sheet.getCell("A4").alignment = { horizontal: "center" };
  sheet.getCell("F5").value = "Ngày:";
  sheet.getCell("G5").value = data.serviceDate;
  sheet.mergeCells("A5:D5");
  sheet.getCell("A5").value = `Số phiếu: ${data.documentNumber}`;
  sheet.mergeCells("A6:G6");
  sheet.getCell("A6").value = `Trường: ${data.schoolName}`;
  sheet.mergeCells("A7:G7");
  sheet.getCell("A7").value = `Địa chỉ: ${data.deliveryAddress}`;
  if (data.note) {
    sheet.mergeCells("A8:G8");
    sheet.getCell("A8").value = `Ghi chú: ${data.note}`;
  }
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
    header.font = { name: "Times New Roman", bold: true, size: 16 };
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
    row.height = 30;
    exactExcelQuantity(row.getCell(4), line.quantity);
    borderRow(row);
  });
  [13, 37.43, 8, 9.57, 11, 11, 14].forEach(
    (width, index) => (sheet.getColumn(index + 1).width = width),
  );
  const signatureRow = Math.max(29, 11 + data.lines.length + 6);
  sheet.mergeCells(signatureRow, 1, signatureRow, 2);
  sheet.mergeCells(signatureRow, 3, signatureRow, 5);
  sheet.mergeCells(signatureRow, 6, signatureRow, 7);
  sheet.getCell(signatureRow, 1).value = "Người nhận hàng";
  sheet.getCell(signatureRow, 3).value = "Người giao hàng";
  sheet.getCell(signatureRow, 6).value = "Người lập phiếu";
  sheet.mergeCells(signatureRow + 1, 1, signatureRow + 1, 2);
  sheet.mergeCells(signatureRow + 1, 3, signatureRow + 1, 5);
  sheet.mergeCells(signatureRow + 1, 6, signatureRow + 1, 7);
  for (const column of [1, 3, 6]) {
    sheet.getCell(signatureRow, column).font = {
      name: "Times New Roman",
      size: 16,
      bold: true,
    };
    sheet.getCell(signatureRow, column).alignment = { horizontal: "center" };
    sheet.getCell(signatureRow + 1, column).value = "(Ký, ghi họ tên)";
    sheet.getCell(signatureRow + 1, column).alignment = {
      horizontal: "center",
    };
  }
  sheet.eachRow((row) =>
    row.eachCell((cell) => {
      cell.font = { name: "Times New Roman", size: 16, ...cell.font };
      cell.alignment = { vertical: "middle", ...cell.alignment };
    }),
  );
}

function safeSheetName(value: string) {
  return (
    value
      .replace(/[\\/*?:[\]]/g, " ")
      .trim()
      .slice(0, 31) || "PXK"
  );
}

export async function createSchoolDispatchXlsx(
  document: SchoolDispatchDocument,
) {
  const ExcelJS = (await import("exceljs")).default;
  const workbook = new ExcelJS.Workbook();
  workbook.creator = "Atlas · Thượng Hảo";
  const logoId = workbook.addImage({
    base64: companyLogoDataUrl,
    extension: "jpeg",
  });
  addSchoolDispatchSheet(
    workbook,
    document,
    safeSheetName(document.school_name),
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
  workbook.creator = "Atlas · Thượng Hảo";
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
    const stem = safeSheetName(
      `${document.service_date.slice(5)} ${document.school_name}`,
    );
    let name = stem;
    let suffix = 2;
    while (names.has(name)) {
      const tail = ` ${suffix}`;
      name = `${stem.slice(0, 31 - tail.length)}${tail}`;
      suffix += 1;
    }
    names.add(name);
    addSchoolDispatchSheet(workbook, document, name, logoId);
  }
  return workbook.xlsx.writeBuffer();
}

export async function createSchoolDispatchPdf(
  document: SchoolDispatchDocument,
) {
  const definition = buildSchoolDispatchPdfDefinition(document);
  const [pdfMake, pdfFonts] = await Promise.all([
    import("pdfmake/build/pdfmake"),
    import("pdfmake/build/vfs_fonts"),
  ]);
  const fontModule = pdfFonts as unknown as {
    default?: Record<string, string>;
    vfs?: Record<string, string>;
  };
  const virtualFonts = fontModule.default ?? fontModule.vfs;
  if (!virtualFonts) throw new Error("PDF font assets are unavailable.");
  return new Promise<Uint8Array>((resolve, reject) => {
    try {
      pdfMake
        .createPdf(definition, undefined, undefined, virtualFonts)
        .getBuffer((buffer) => resolve(new Uint8Array(buffer)));
    } catch (error) {
      reject(error);
    }
  });
}

function safeStem(document: SchoolDispatchDocument) {
  const school = document.school_name
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/đ/gi, "d")
    .replace(/[^a-zA-Z0-9]+/g, "-")
    .replace(/^-|-$/g, "");
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
