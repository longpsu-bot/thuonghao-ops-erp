import type { SchoolCateringPurchaseOrder } from "./schoolCateringProcurementModel";
import type { TDocumentDefinitions } from "pdfmake/interfaces";
import type { Cell, Row, Worksheet } from "exceljs";

const QUANTITY_SCALE = 1_000_000n;

type PurchaseOrderExportLine = {
  ingredientName: string;
  orderedQuantity: string;
  unitCode: string;
};

type PurchaseOrderSchoolExportLine = PurchaseOrderExportLine & {
  locationName: string;
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
  const schoolLines = order.lines.map((line) => {
    const key = `${line.ingredient.ingredient_id}\u0000${line.unit.unit_id}`;
    const current = summaries.get(key);
    const quantity = scaledQuantity(line.ordered_quantity);
    summaries.set(key, {
      ingredientName: line.ingredient.ingredient_name,
      unitCode: line.unit.unit_code,
      quantity: (current?.quantity ?? 0n) + quantity,
    });
    return {
      locationName: line.delivery_location.location_name,
      ingredientName: line.ingredient.ingredient_name,
      orderedQuantity: exactQuantity(quantity),
      unitCode: line.unit.unit_code,
    };
  });

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
      { text: "THƯỢNG HẢO", style: "company" },
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
              line.locationName,
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
      cell.font = { ...cell.font, name: "Times New Roman", size: 11 };
      cell.alignment = { vertical: "middle", ...cell.alignment };
    });
  });
}

function addGroupBand(worksheet: Worksheet, text: string) {
  const row = worksheet.addRow([text]);
  worksheet.mergeCells(row.number, 1, row.number, 4);
  row.font = { name: "Times New Roman", bold: true };
  row.fill = {
    type: "pattern",
    pattern: "solid",
    fgColor: { argb: "FFE7E7E7" },
  };
  borderRow(row);
}

function groupBy<T>(items: T[], keyFor: (item: T) => string) {
  const groups = new Map<string, T[]>();
  for (const item of items) {
    const key = keyFor(item);
    groups.set(key, [...(groups.get(key) ?? []), item]);
  }
  return groups;
}

export async function createPurchaseOrderXlsx(
  order: SchoolCateringPurchaseOrder,
) {
  const data = buildPurchaseOrderExportData(order);
  const ExcelJS = (await import("exceljs")).default;
  const workbook = new ExcelJS.Workbook();
  workbook.creator = "Atlas · Thượng Hảo";
  workbook.created = new Date();

  const summary = workbook.addWorksheet("Tổng");
  prepareWorksheet(summary);
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
  prepareWorksheet(bySchool);
  const schools = groupBy(data.schoolLines, (line) => line.locationName);
  for (const [locationName, lines] of schools) {
    if (bySchool.rowCount) bySchool.addRow([]);
    addGroupBand(bySchool, `TRƯỜNG / ĐIỂM GIAO: ${locationName}`);
    styleWorksheetHeader(
      bySchool.addRow(["STT", "Tên hàng", "Đơn vị", "Số lượng"]),
    );
    lines.forEach((line, index) => {
      const row = bySchool.addRow([
        index + 1,
        line.ingredientName,
        line.unitCode,
        null,
      ]);
      setQuantity(row.getCell(4), line.orderedQuantity);
      borderRow(row);
    });
  }
  bySchool.getColumn(1).width = 8;
  bySchool.getColumn(2).width = 38;
  bySchool.getColumn(3).width = 13;
  bySchool.getColumn(4).width = 18;
  applyDocumentFont(bySchool);

  const byIngredient = workbook.addWorksheet("Theo hàng");
  prepareWorksheet(byIngredient);
  const ingredients = groupBy(
    data.schoolLines,
    (line) => `${line.ingredientName}\u0000${line.unitCode}`,
  );
  for (const [key, lines] of ingredients) {
    if (byIngredient.rowCount) byIngredient.addRow([]);
    const [ingredientName, unitCode] = key.split("\u0000");
    addGroupBand(byIngredient, `TÊN HÀNG: ${ingredientName}`);
    styleWorksheetHeader(
      byIngredient.addRow(["STT", "Trường / điểm giao", "Đơn vị", "Số lượng"]),
    );
    lines.forEach((line, index) => {
      const row = byIngredient.addRow([
        index + 1,
        line.locationName,
        unitCode,
        null,
      ]);
      setQuantity(row.getCell(4), line.orderedQuantity);
      borderRow(row);
    });
  }
  byIngredient.getColumn(1).width = 8;
  byIngredient.getColumn(2).width = 38;
  byIngredient.getColumn(3).width = 13;
  byIngredient.getColumn(4).width = 18;
  applyDocumentFont(byIngredient);

  const buffer = await workbook.xlsx.writeBuffer();
  return buffer;
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

function downloadBytes(
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
