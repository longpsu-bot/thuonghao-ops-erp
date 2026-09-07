import type { Cell, Row, Worksheet } from "exceljs";
import type { TDocumentDefinitions } from "pdfmake/interfaces";
import type { SchoolDispatchDocument } from "./schoolDispatchReleaseModel";

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
    deliveryLocationName: document.delivery_location_name,
    deliveryAddress: document.delivery_address,
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
      { text: "THƯỢNG HẢO", style: "company" },
      { text: "PHIẾU XUẤT KHO", style: "heading" },
      { text: `Số phiếu: ${data.documentNumber}` },
      { text: `Ngày phục vụ: ${data.serviceDate}` },
      { text: `Trường: ${data.schoolName}` },
      { text: `Điểm giao: ${data.deliveryLocationName}` },
      { text: `Địa chỉ: ${data.deliveryAddress}` },
      ...(data.note ? [{ text: `Ghi chú: ${data.note}` }] : []),
      {
        table: {
          headerRows: 1,
          widths: [32, "*", 90, 55],
          body: [
            ["STT", "Nguyên liệu", "Số lượng", "Đơn vị"],
            ...data.lines.map((line, index) => [
              index + 1,
              line.ingredientName,
              line.quantity,
              line.unitCode,
            ]),
          ],
        },
        margin: [0, 12, 0, 0],
      },
    ],
    defaultStyle: { font: "Roboto", fontSize: 10 },
    styles: {
      company: { bold: true, fontSize: 9, margin: [0, 0, 0, 4] },
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
  if (typeof cell.value === "number") cell.numFmt = "0.######";
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

export async function createSchoolDispatchXlsx(
  document: SchoolDispatchDocument,
) {
  const data = buildSchoolDispatchExportData(document);
  const ExcelJS = (await import("exceljs")).default;
  const workbook = new ExcelJS.Workbook();
  workbook.creator = "Atlas · Thượng Hảo";
  const sheet = workbook.addWorksheet("Phiếu xuất kho");
  prepareWorksheet(sheet);
  sheet.mergeCells("A1:D1");
  sheet.getCell("A1").value = "THƯỢNG HẢO";
  sheet.mergeCells("A2:D2");
  sheet.getCell("A2").value = "PHIẾU XUẤT KHO";
  sheet.getCell("A2").font = { name: "Times New Roman", bold: true, size: 18 };
  sheet.getCell("A2").alignment = { horizontal: "center" };
  sheet.addRow([]);
  sheet.addRow(["Số phiếu", data.documentNumber]);
  sheet.addRow(["Ngày phục vụ", data.serviceDate]);
  sheet.addRow(["Trường", data.schoolName]);
  sheet.addRow(["Điểm giao", data.deliveryLocationName]);
  sheet.addRow(["Địa chỉ", data.deliveryAddress]);
  if (data.note) sheet.addRow(["Ghi chú", data.note]);
  const header = sheet.addRow(["STT", "Nguyên liệu", "Đơn vị", "Số lượng"]);
  header.font = { name: "Times New Roman", bold: true };
  borderRow(header);
  data.lines.forEach((line, index) => {
    const row = sheet.addRow([
      index + 1,
      line.ingredientName,
      line.unitCode,
      null,
    ]);
    exactExcelQuantity(row.getCell(4), line.quantity);
    borderRow(row);
  });
  sheet.getColumn(1).width = 8;
  sheet.getColumn(2).width = 40;
  sheet.getColumn(3).width = 14;
  sheet.getColumn(4).width = 18;
  sheet.eachRow((row) =>
    row.eachCell((cell) => {
      cell.font = { ...cell.font, name: "Times New Roman", size: 11 };
      cell.alignment = { vertical: "middle", ...cell.alignment };
    }),
  );
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

export async function downloadSchoolDispatchPdf(
  document: SchoolDispatchDocument,
) {
  downloadBytes(
    await createSchoolDispatchPdf(document),
    "application/pdf",
    `${safeStem(document)}.pdf`,
  );
}
