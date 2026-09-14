import type { SchoolCateringPurchaseOrder } from "./schoolCateringProcurementModel";
import type { TDocumentDefinitions } from "pdfmake/interfaces";
import type { Cell, Row, Worksheet } from "exceljs";
import companyLogoDataUrl from "../../../assets/thuong-hao-logo.png?inline";

const QUANTITY_SCALE = 1_000_000n;

type PurchaseOrderExportLine = {
  ingredientName: string;
  orderedQuantity: string;
  unitCode: string;
};

type PurchaseOrderSchoolExportLine = PurchaseOrderExportLine & {
  schoolName: string;
  schoolDisplayOrder: number;
};

export type PurchaseOrderExportData = {
  documentNumber: string;
  supplierName: string;
  serviceDate: string;
  releasedRevision: number;
  summaryLines: PurchaseOrderExportLine[];
  schoolLines: PurchaseOrderSchoolExportLine[];
};

function scaledQuantity(value: string) {
  const match = value.match(/^(\d+)(?:\.(\d{0,6}))?$/);
  if (!match)
    throw new Error("Released PO contains an invalid exact quantity.");
  return (
    BigInt(match[1]!) * QUANTITY_SCALE + BigInt((match[2] ?? "").padEnd(6, "0"))
  );
}

function exactQuantity(value: bigint) {
  const integer = value / QUANTITY_SCALE;
  const fraction = String(value % QUANTITY_SCALE).padStart(6, "0");
  return `${integer}.${fraction}`;
}

function dateLabel(value: string) {
  const [year, month, day] = value.split("-");
  return year && month && day ? `${day}/${month}/${year}` : value;
}

export function buildPurchaseOrderExportData(
  order: SchoolCateringPurchaseOrder,
): PurchaseOrderExportData {
  if (
    order.status !== "RELEASED_TO_SUPPLIER" ||
    !order.document_number ||
    !order.export_ready ||
    !order.allowed_actions.export
  ) {
    throw new Error(
      "Only an authoritative released PO snapshot can be exported.",
    );
  }
  const supplierSnapshot =
    order.current_revision.supplier_name_snapshot?.trim();
  if (!supplierSnapshot)
    throw new Error("Released PO supplier snapshot is missing.");

  const summaries = new Map<
    string,
    { ingredientName: string; unitCode: string; quantity: bigint }
  >();
  const schoolLines: PurchaseOrderSchoolExportLine[] = [];
  for (const line of order.lines) {
    const key = `${line.ingredient.ingredient_id}\u0000${line.unit.unit_id}`;
    const current = summaries.get(key);
    const quantity = scaledQuantity(line.ordered_quantity);
    summaries.set(key, {
      ingredientName: line.ingredient.ingredient_name,
      unitCode: line.unit.unit_code,
      quantity: (current?.quantity ?? 0n) + quantity,
    });
    let breakdownTotal = 0n;
    for (const school of line.school_breakdown) {
      const schoolQuantity = scaledQuantity(school.ordered_quantity);
      breakdownTotal += schoolQuantity;
      schoolLines.push({
        schoolName: school.school_name,
        schoolDisplayOrder: school.school_display_order,
        ingredientName: line.ingredient.ingredient_name,
        orderedQuantity: exactQuantity(schoolQuantity),
        unitCode: line.unit.unit_code,
      });
    }
    if (!line.school_breakdown.length || breakdownTotal !== quantity)
      throw new Error("Released PO School breakdown is incomplete.");
  }
  schoolLines.sort(
    (left, right) =>
      left.schoolDisplayOrder - right.schoolDisplayOrder ||
      left.schoolName.localeCompare(right.schoolName, "vi") ||
      left.ingredientName.localeCompare(right.ingredientName, "vi"),
  );

  return {
    documentNumber: order.document_number,
    supplierName: supplierSnapshot,
    serviceDate: dateLabel(order.service_date),
    releasedRevision: order.current_revision.revision_number,
    summaryLines: Array.from(summaries.values(), (line) => ({
      ingredientName: line.ingredientName,
      orderedQuantity: exactQuantity(line.quantity),
      unitCode: line.unitCode,
    })),
    schoolLines,
  };
}

export function buildPurchaseOrderPdfDefinition(
  order: SchoolCateringPurchaseOrder,
): TDocumentDefinitions {
  const data = buildPurchaseOrderExportData(order);
  return {
    info: { title: `Phiếu đặt hàng ${data.documentNumber}` },
    content: [
      {
        columns: [
          { image: companyLogoDataUrl, width: 54 },
          {
            stack: [
              { text: companyName, style: "company" },
              { text: companyAddress, style: "address" },
            ],
            alignment: "center",
          },
          { text: "", width: 54 },
        ],
      },
      { text: "PHIẾU ĐẶT HÀNG", style: "heading" },
      { text: `Số đơn: ${data.documentNumber}` },
      { text: `Nhà cung ứng: ${data.supplierName}` },
      { text: `Ngày giao: ${data.serviceDate}` },
      { text: `Phiên bản phát hành: ${data.releasedRevision}` },
      { text: "Tổng hợp đơn mua", style: "section" },
      {
        table: {
          headerRows: 1,
          widths: ["*", 90, 55],
          body: [
            ["Nguyên liệu", "Số lượng", "Đơn vị"],
            ...data.summaryLines.map((line) => [
              line.ingredientName,
              line.orderedQuantity,
              line.unitCode,
            ]),
          ],
        },
      },
      { text: "Theo trường / điểm giao", style: "section" },
      {
        table: {
          headerRows: 1,
          widths: ["*", "*", 75, 45],
          body: [
            ["Trường / điểm giao", "Nguyên liệu", "Số lượng", "Đơn vị"],
            ...data.schoolLines.map((line) => [
              line.schoolName,
              line.ingredientName,
              line.orderedQuantity,
              line.unitCode,
            ]),
          ],
        },
      },
    ],
    defaultStyle: { font: "Roboto", fontSize: 9 },
    styles: {
      company: { bold: true, fontSize: 9, margin: [0, 0, 0, 4] },
      address: { italics: true, fontSize: 8, margin: [0, 0, 0, 6] },
      heading: { bold: true, fontSize: 16, margin: [0, 0, 0, 10] },
      section: { bold: true, fontSize: 11, margin: [0, 12, 0, 6] },
    },
  };
}

function styleWorksheetHeader(row: Row) {
  row.font = { name: "Times New Roman", bold: true };
  row.fill = {
    type: "pattern",
    pattern: "solid",
    fgColor: { argb: "FFD9D9D9" },
  };
  row.alignment = { vertical: "middle", horizontal: "center" };
  borderRow(row);
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

function exactExcelQuantity(value: string): string | number {
  const governed = scaledQuantity(value);
  const numeric = Number(value);
  if (!Number.isFinite(numeric)) return value;
  const scaledNumeric = numeric * Number(QUANTITY_SCALE);
  if (
    !Number.isSafeInteger(scaledNumeric) ||
    BigInt(scaledNumeric) !== governed
  )
    return value;
  return numeric;
}

function setQuantity(cell: Cell, value: string) {
  cell.value = exactExcelQuantity(value);
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
    margins: {
      left: 0.35,
      right: 0.35,
      top: 0.45,
      bottom: 0.45,
      header: 0.2,
      footer: 0.2,
    },
  };
  worksheet.properties.defaultRowHeight = 18;
}

function applyDocumentFont(worksheet: Worksheet) {
  worksheet.eachRow((row) => {
    row.eachCell((cell) => {
      cell.font = {
        name: "Times New Roman",
        size: cell.font?.size ?? 11,
        ...cell.font,
      };
      cell.alignment = { vertical: "middle", ...cell.alignment };
    });
  });
}

function groupBy<T>(items: T[], keyFor: (item: T) => string) {
  const groups = new Map<string, T[]>();
  for (const item of items) {
    const key = keyFor(item);
    groups.set(key, [...(groups.get(key) ?? []), item]);
  }
  return groups;
}

const companyName = "CÔNG TY TNHH MTV TM - DV THƯỢNG HẢO";
const companyAddress =
  "ĐC: 96/3 KP. Thạnh Lợi, Phường Thuận An, Tp Hồ Chí Minh, Việt Nam";

function prepareDetailSheet(
  sheet: Worksheet,
  title: string,
  data: PurchaseOrderExportData,
  firstHeader: string,
  fourthHeader: string,
  logoId: number,
) {
  prepareWorksheet(sheet);
  sheet.addImage(logoId, {
    tl: { col: 0, row: 0 },
    ext: { width: 58, height: 58 },
  });
  sheet.pageSetup.orientation = "landscape";
  sheet.mergeCells("A1:G1");
  sheet.getCell("A1").value = companyName;
  sheet.getCell("A1").alignment = { horizontal: "center" };
  sheet.mergeCells("A2:G2");
  sheet.getCell("A2").value = companyAddress;
  sheet.getCell("A2").alignment = { horizontal: "center" };
  sheet.mergeCells("A4:G4");
  sheet.getCell("A4").value = title;
  sheet.getCell("A4").font = { name: "Times New Roman", bold: true, size: 18 };
  sheet.getCell("A4").alignment = { horizontal: "center" };
  sheet.mergeCells("A6:D6");
  sheet.getCell("A6").value = `Nhà cung cấp: ${data.supplierName}`;
  sheet.getCell("A6").font = { name: "Times New Roman", size: 16 };
  sheet.getCell("A7").value = "Ngày dùng:";
  sheet.getCell("B7").value = data.serviceDate;
  const header = sheet.getRow(9);
  header.values = [
    firstHeader,
    null,
    "STT",
    fourthHeader,
    "Đơn vị",
    "Số lượng",
  ];
  sheet.mergeCells("A9:B9");
  sheet.mergeCells("F9:G9");
  header.height = 36;
  header.font = {
    name: "Times New Roman",
    bold: true,
    size: 16,
    color: { argb: "FF000000" },
  };
  header.fill = {
    type: "pattern",
    pattern: "solid",
    fgColor: { argb: "FFB7B7B7" },
  };
  header.alignment = {
    horizontal: "center",
    vertical: "middle",
    wrapText: true,
  };
  borderRow(header);
  [15, 13, 8, 34, 11, 11, 14].forEach(
    (width, index) => (sheet.getColumn(index + 1).width = width),
  );
}

function addDetailRow(
  sheet: Worksheet,
  rowNumber: number,
  groupLabel: string | null,
  index: number,
  detailLabel: string,
  unitCode: string,
  quantity: string,
) {
  sheet.mergeCells(rowNumber, 1, rowNumber, 2);
  sheet.mergeCells(rowNumber, 6, rowNumber, 7);
  const row = sheet.getRow(rowNumber);
  row.getCell(1).value = groupLabel;
  row.getCell(3).value = index;
  row.getCell(4).value = detailLabel;
  row.getCell(5).value = unitCode;
  row.height = 30;
  row.font = { name: "Times New Roman", size: 16 };
  row.alignment = { vertical: "middle", wrapText: true };
  if (groupLabel)
    row.getCell(1).font = {
      name: "Times New Roman",
      size: 16,
      bold: true,
    };
  if (rowNumber % 2 === 1)
    row.fill = {
      type: "pattern",
      pattern: "solid",
      fgColor: { argb: "FFF2F2F2" },
    };
  setQuantity(row.getCell(6), quantity);
  borderRow(row);
  if (groupLabel)
    row.eachCell((cell) => {
      cell.border = {
        ...cell.border,
        top: { style: "medium", color: { argb: "FF000000" } },
      };
    });
}

export async function createPurchaseOrderXlsx(
  order: SchoolCateringPurchaseOrder,
) {
  const data = buildPurchaseOrderExportData(order);
  const ExcelJS = (await import("exceljs")).default;
  const workbook = new ExcelJS.Workbook();
  workbook.creator = "Atlas · Thượng Hảo";
  workbook.created = new Date();
  const logoId = workbook.addImage({
    base64: companyLogoDataUrl,
    extension: "png",
  });

  const summary = workbook.addWorksheet("Tổng");
  prepareWorksheet(summary);
  summary.addImage(logoId, {
    tl: { col: 0, row: 0 },
    ext: { width: 58, height: 58 },
  });
  summary.mergeCells("A1:D1");
  summary.getCell("A1").value = "THƯỢNG HẢO";
  summary.mergeCells("A2:D2");
  summary.getCell("A2").value = "PHIẾU ĐẶT HÀNG";
  summary.getCell("A2").font = {
    name: "Times New Roman",
    bold: true,
    size: 18,
  };
  summary.getCell("A2").alignment = { horizontal: "center" };
  summary.addRow([]);
  summary.addRow(["Số đơn", data.documentNumber]);
  summary.addRow(["Ngày giao", data.serviceDate]);
  summary.addRow(["Nhà cung ứng", data.supplierName]);
  const summaryHeader = summary.addRow([
    "STT",
    "Tên hàng",
    "Đơn vị",
    "Số lượng",
  ]);
  styleWorksheetHeader(summaryHeader);
  data.summaryLines.forEach((line, index) => {
    const row = summary.addRow([
      index + 1,
      line.ingredientName,
      line.unitCode,
      null,
    ]);
    setQuantity(row.getCell(4), line.orderedQuantity);
    borderRow(row);
  });
  summary.getColumn(1).width = 8;
  summary.getColumn(2).width = 38;
  summary.getColumn(3).width = 13;
  summary.getColumn(4).width = 18;
  applyDocumentFont(summary);

  const bySchool = workbook.addWorksheet("Theo trường");
  prepareDetailSheet(
    bySchool,
    "CHI TIẾT GIAO HÀNG",
    data,
    "Trường học",
    "Tên hàng",
    logoId,
  );
  const schools = groupBy(
    data.schoolLines,
    (line) =>
      `${String(line.schoolDisplayOrder).padStart(10, "0")}\u0000${line.schoolName}`,
  );
  let schoolRow = 10;
  for (const [, lines] of schools) {
    lines.forEach((line, index) => {
      addDetailRow(
        bySchool,
        schoolRow,
        index === 0 ? line.schoolName : null,
        index + 1,
        line.ingredientName,
        line.unitCode,
        line.orderedQuantity,
      );
      schoolRow += 1;
    });
  }
  applyDocumentFont(bySchool);

  const byIngredient = workbook.addWorksheet("Theo hàng");
  prepareDetailSheet(
    byIngredient,
    "CHI TIẾT GIAO HÀNG (THEO HÀNG)",
    data,
    "Tên hàng",
    "Trường học",
    logoId,
  );
  const ingredients = groupBy(
    data.schoolLines,
    (line) => `${line.ingredientName}\u0000${line.unitCode}`,
  );
  let ingredientRow = 10;
  for (const [key, lines] of ingredients) {
    const [ingredientName, unitCode] = key.split("\u0000");
    lines.forEach((line, index) => {
      addDetailRow(
        byIngredient,
        ingredientRow,
        index === 0 ? ingredientName! : null,
        index + 1,
        line.schoolName,
        unitCode!,
        line.orderedQuantity,
      );
      ingredientRow += 1;
    });
  }
  applyDocumentFont(byIngredient);

  return workbook.xlsx.writeBuffer();
}

export async function createPurchaseOrderPdf(
  order: SchoolCateringPurchaseOrder,
) {
  const definition = buildPurchaseOrderPdfDefinition(order);
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

export function downloadBytes(
  bytes: ArrayBuffer | Uint8Array,
  mimeType: string,
  fileName: string,
) {
  const blob = new Blob([bytes as BlobPart], { type: mimeType });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = fileName;
  anchor.click();
  URL.revokeObjectURL(url);
}

function purchaseOrderFileStem(order: SchoolCateringPurchaseOrder) {
  const supplier = order.current_revision.supplier_name_snapshot?.trim();
  if (!supplier) throw new Error("Released PO supplier snapshot is missing.");
  const safeSupplier = supplier
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/đ/gi, "d")
    .replace(/[^a-zA-Z0-9]+/g, "-")
    .replace(/^-|-$/g, "");
  return `${safeSupplier}-${order.service_date}-${order.document_number}`;
}

export async function downloadPurchaseOrderXlsx(
  order: SchoolCateringPurchaseOrder,
) {
  const bytes = await createPurchaseOrderXlsx(order);
  downloadBytes(
    bytes,
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    `${purchaseOrderFileStem(order)}.xlsx`,
  );
}

export async function downloadPurchaseOrderPdf(
  order: SchoolCateringPurchaseOrder,
) {
  const bytes = await createPurchaseOrderPdf(order);
  downloadBytes(
    bytes,
    "application/pdf",
    `${purchaseOrderFileStem(order)}.pdf`,
  );
}
