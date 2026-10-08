import type { SchoolCateringPurchaseOrder } from "./schoolCateringProcurementModel";
import type { TDocumentDefinitions } from "pdfmake/interfaces";
import type { Row, Worksheet } from "exceljs";
import companyLogoDataUrl from "../../../assets/thuong-hao-logo.jpg?inline";

import {
  applyDocumentFont,
  borderRow,
  companyName,
  companyAddress,
  documentStatusLabel,
  documentPdfFooter,
  documentFilePart,
  finishDocumentSheet,
  initializeDocumentWorkbook,
  prepareDocumentSheet as prepareWorksheet,
  renderDocumentPdf,
  setExactQuantity as setQuantity,
  wrappedRowHeight,
} from "../documents/documentPresentation";

const QUANTITY_SCALE = 1_000_000n;

type PurchaseOrderExportLine = {
  ingredientName: string;
  orderedQuantity: string;
  unitCode: string;
  supplierNote: string | null;
};

type PurchaseOrderSchoolExportLine = PurchaseOrderExportLine & {
  schoolId: string;
  locationId: string;
  locationName: string;
  ingredientId: string;
  unitId: string;
  schoolName: string;
  schoolDisplayOrder: number;
};

export type PurchaseOrderExportData = {
  documentNumber: string;
  supplierName: string;
  serviceDate: string;
  releasedRevision: number;
  status: string;
  replacementLabel: string;
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
    !["RELEASED_TO_SUPPLIER", "SUPERSEDED"].includes(order.status) ||
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
    {
      ingredientName: string;
      unitCode: string;
      supplierNote: string | null;
      quantity: bigint;
    }
  >();
  const schoolLines: PurchaseOrderSchoolExportLine[] = [];
  for (const line of [...order.lines].sort(
    (a, b) =>
      a.ingredient.ingredient_id.localeCompare(b.ingredient.ingredient_id) ||
      a.unit.unit_id.localeCompare(b.unit.unit_id) ||
      a.purchase_order_line_revision_id.localeCompare(
        b.purchase_order_line_revision_id,
      ) ||
      (a.supplier_note ?? "").localeCompare(b.supplier_note ?? ""),
  )) {
    const key = `${line.ingredient.ingredient_id}\u0000${line.unit.unit_id}\u0000${line.supplier_note ?? ""}`;
    const current = summaries.get(key);
    const quantity = scaledQuantity(line.ordered_quantity);
    summaries.set(key, {
      ingredientName: line.ingredient.ingredient_name,
      unitCode: line.unit.unit_code,
      supplierNote: line.supplier_note,
      quantity: (current?.quantity ?? 0n) + quantity,
    });
    let breakdownTotal = 0n;
    for (const school of line.school_breakdown) {
      const schoolQuantity = scaledQuantity(school.ordered_quantity);
      breakdownTotal += schoolQuantity;
      schoolLines.push({
        schoolId: school.school_id,
        locationId: school.delivery_location_id,
        locationName: school.delivery_location_name,
        ingredientId: line.ingredient.ingredient_id,
        unitId: line.unit.unit_id,
        schoolName: school.school_name,
        schoolDisplayOrder: school.school_display_order,
        ingredientName: line.ingredient.ingredient_name,
        orderedQuantity: exactQuantity(schoolQuantity),
        unitCode: line.unit.unit_code,
        supplierNote: line.supplier_note,
      });
    }
    if (!line.school_breakdown.length || breakdownTotal !== quantity)
      throw new Error("Released PO School breakdown is incomplete.");
  }
  schoolLines.sort(
    (left, right) =>
      left.schoolDisplayOrder - right.schoolDisplayOrder ||
      left.schoolName.localeCompare(right.schoolName, "vi") ||
      left.schoolId.localeCompare(right.schoolId) ||
      left.locationId.localeCompare(right.locationId) ||
      left.ingredientName.localeCompare(right.ingredientName, "vi") ||
      left.ingredientId.localeCompare(right.ingredientId) ||
      left.unitId.localeCompare(right.unitId) ||
      (left.supplierNote ?? "").localeCompare(right.supplierNote ?? ""),
  );

  return {
    status: order.status,
    replacementLabel: `${order.replaces_purchase_order_id ? ` · Thay thế PO: ${order.replaces_purchase_order_id}` : ""}${order.replaced_by_purchase_order_id ? ` · Được thay thế bởi PO: ${order.replaced_by_purchase_order_id}` : ""}`,
    documentNumber: order.document_number,
    supplierName: supplierSnapshot,
    serviceDate: dateLabel(order.service_date),
    releasedRevision: order.current_revision.revision_number,
    summaryLines: Array.from(summaries.values(), (line) => ({
      ingredientName: line.ingredientName,
      orderedQuantity: exactQuantity(line.quantity),
      unitCode: line.unitCode,
      supplierNote: line.supplierNote,
    })),
    schoolLines,
  };
}

export function buildPurchaseOrderPdfDefinition(
  order: SchoolCateringPurchaseOrder,
): TDocumentDefinitions {
  const data = buildPurchaseOrderExportData(order);
  return {
    pageSize: "A4",
    pageMargins: [28, 32, 28, 42],
    footer: documentPdfFooter(
      `${data.documentNumber} · ${documentStatusLabel(order.status)}`,
    ),
    info: {
      title: `Phiếu đặt hàng ${data.documentNumber}`,
      creationDate: new Date(
        order.current_revision.released_at ?? "2000-01-01T00:00:00Z",
      ),
      modDate: new Date(
        order.current_revision.released_at ?? "2000-01-01T00:00:00Z",
      ),
    },
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
      {
        text: documentStatusLabel(order.status),
        bold: true,
        margin: [0, 0, 0, 8],
      },
      ...(order.replaces_purchase_order_id
        ? [{ text: `Thay thế PO: ${order.replaces_purchase_order_id}` }]
        : []),
      ...(order.replaced_by_purchase_order_id
        ? [
            {
              text: `Được thay thế bởi PO: ${order.replaced_by_purchase_order_id}`,
            },
          ]
        : []),
      { text: `Số đơn: ${data.documentNumber}` },
      { text: `Nhà cung ứng: ${data.supplierName}` },
      { text: `Ngày giao: ${data.serviceDate}` },
      { text: `Phiên bản phát hành: ${data.releasedRevision}` },
      { text: "Tổng hợp đơn mua", style: "section" },
      {
        table: {
          headerRows: 1,
          widths: ["*", 120, 36, 120],
          dontBreakRows: true,
          body: [
            ["Nguyên liệu", "Số lượng", "Đơn vị", "Ghi chú"],
            ...data.summaryLines.flatMap((line) =>
              noteChunks(line.supplierNote).map((note, continuation) => [
                line.ingredientName,
                {
                  text: continuation ? "" : line.orderedQuantity,
                  alignment: "right" as const,
                },
                line.unitCode,
                note ?? "",
              ]),
            ),
          ],
        },
      },
      { text: "Theo trường / điểm giao", style: "section" },
      {
        table: {
          headerRows: 1,
          widths: ["*", "*", 120, 32, 95],
          dontBreakRows: true,
          body: [
            [
              "Trường / điểm giao",
              "Nguyên liệu",
              "Số lượng",
              "Đơn vị",
              "Ghi chú",
            ],
            ...data.schoolLines.flatMap((line) =>
              noteChunks(line.supplierNote).map((note, continuation) => [
                `${line.schoolName} · ${line.locationName}`,
                line.ingredientName,
                {
                  text: continuation ? "" : line.orderedQuantity,
                  alignment: "right" as const,
                },
                line.unitCode,
                note ?? "",
              ]),
            ),
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

function groupBy<T>(items: T[], keyFor: (item: T) => string) {
  const groups = new Map<string, T[]>();
  for (const item of items) {
    const key = keyFor(item);
    const group = groups.get(key) ?? [];
    group.push(item);
    groups.set(key, group);
  }
  return groups;
}

// Excel cannot split a physical row across pages. Keep every note character in
// bounded continuation rows; quantities appear only on the first row.
function noteChunks(note: string | null) {
  if (!note) return [note];
  const chunks: string[] = [];
  let chunk = "";
  for (const character of note) {
    if (chunk && wrappedRowHeight(chunk + character, 32, 12) > 180) {
      chunks.push(chunk);
      chunk = "";
    }
    chunk += character;
  }
  chunks.push(chunk);
  return chunks;
}

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
  sheet.mergeCells("A3:H3");
  sheet.getCell("A3").value = documentStatusLabel(data.status);
  sheet.getCell("A3").font = { name: "Times New Roman", size: 12, bold: true };
  sheet.mergeCells("A5:H5");
  sheet.getCell("A5").value =
    `Số đơn: ${data.documentNumber} · Phiên bản: ${data.releasedRevision}${data.replacementLabel}`;
  sheet.getRow(5).height = wrappedRowHeight(
    String(sheet.getCell("A5").value),
    140,
  );
  sheet.mergeCells("A1:H1");
  sheet.getCell("A1").value = companyName;
  sheet.getCell("A1").alignment = { horizontal: "center" };
  sheet.mergeCells("A2:H2");
  sheet.getCell("A2").value = companyAddress;
  sheet.getCell("A2").alignment = { horizontal: "center" };
  sheet.mergeCells("A4:H4");
  sheet.getCell("A4").value = title;
  sheet.getCell("A4").font = { name: "Times New Roman", bold: true, size: 18 };
  sheet.getCell("A4").alignment = { horizontal: "center" };
  sheet.getRow(1).height = 28;
  sheet.getRow(2).height = 26;
  sheet.getRow(4).height = 34;
  sheet.getRow(7).height = 24;
  sheet.mergeCells("A6:H6");
  sheet.getRow(6).height = wrappedRowHeight(
    `Nhà cung cấp: ${data.supplierName}`,
    140,
    14,
  );
  sheet.getCell("A6").value = `Nhà cung cấp: ${data.supplierName}`;
  sheet.getCell("A6").font = { name: "Times New Roman", size: 14 };
  sheet.getCell("A7").value = "Ngày dùng:";
  sheet.mergeCells("B7:H7");
  sheet.getCell("B7").value = data.serviceDate;
  const header = sheet.getRow(9);
  header.values = [
    firstHeader,
    null,
    "STT",
    fourthHeader,
    "Đơn vị",
    "Số lượng",
    null,
    "Ghi chú",
  ];
  sheet.mergeCells("A9:B9");
  sheet.mergeCells("F9:G9");
  header.height = 36;
  header.font = {
    name: "Times New Roman",
    bold: true,
    size: 12,
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
  [15, 13, 6, 36, 8, 12, 12, 32].forEach(
    (width, index) => (sheet.getColumn(index + 1).width = width),
  );
}

function addDetailRow(
  sheet: Worksheet,
  rowNumber: number,
  groupLabel: string | null,
  index: number | string,
  detailLabel: string,
  unitCode: string,
  quantity: string | null,
  supplierNote: string | null,
  groupStart: boolean,
) {
  sheet.mergeCells(rowNumber, 1, rowNumber, 2);
  sheet.mergeCells(rowNumber, 6, rowNumber, 7);
  const row = sheet.getRow(rowNumber);
  row.getCell(1).value = groupLabel;
  row.getCell(3).value = index;
  row.getCell(4).value = detailLabel;
  row.getCell(5).value = unitCode;
  row.getCell(8).value = supplierNote;
  row.height = Math.max(
    wrappedRowHeight(groupLabel, 28, 14),
    wrappedRowHeight(detailLabel, 36, 14),
    wrappedRowHeight(supplierNote, 32, 12),
  );
  row.font = { name: "Times New Roman", size: 14 };
  row.alignment = { vertical: "middle", wrapText: true };
  if (groupStart)
    row.getCell(1).font = {
      name: "Times New Roman",
      size: 14,
      bold: true,
    };
  if (rowNumber % 2 === 1)
    row.fill = {
      type: "pattern",
      pattern: "solid",
      fgColor: { argb: "FFF2F2F2" },
    };
  row.getCell(8).font = { name: "Times New Roman", size: 12 };
  if (quantity !== null) setQuantity(row.getCell(6), quantity);
  borderRow(row);
  if (groupStart)
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
  initializeDocumentWorkbook(
    workbook,
    `Phiếu đặt hàng ${data.documentNumber}`,
    order.current_revision.released_at ?? undefined,
  );
  const logoId = workbook.addImage({
    base64: companyLogoDataUrl,
    extension: "jpeg",
  });

  const summary = workbook.addWorksheet("Tổng");
  prepareWorksheet(summary);
  summary.addImage(logoId, {
    tl: { col: 0, row: 0 },
    ext: { width: 58, height: 58 },
  });
  summary.mergeCells("A1:E1");
  summary.getCell("A1").value = companyName;
  summary.getCell("A1").alignment = { horizontal: "center" };
  summary.getRow(1).height = 28;
  summary.getRow(2).height = 34;
  summary.mergeCells("A2:E2");
  summary.getCell("A2").value = "PHIẾU ĐẶT HÀNG";
  summary.getCell("A2").font = {
    name: "Times New Roman",
    bold: true,
    size: 18,
  };
  summary.getCell("A2").alignment = { horizontal: "center" };
  summary.mergeCells("A3:E3");
  summary.getCell("A3").value = documentStatusLabel(order.status);
  summary.getCell("A3").font = {
    name: "Times New Roman",
    size: 11,
    bold: true,
  };
  summary.getRow(3).height = 26;
  summary.addRow([
    "Số đơn",
    `${data.documentNumber} · v${data.releasedRevision}${data.replacementLabel}`,
  ]);
  summary.mergeCells("B4:E4");
  summary.getRow(4).height = wrappedRowHeight(
    String(summary.getCell("B4").value),
    90,
  );
  summary.addRow(["Ngày giao", data.serviceDate]);
  summary.mergeCells("B5:E5");
  summary.addRow(["Nhà cung ứng", data.supplierName]);
  summary.mergeCells("B6:E6");
  summary.getRow(6).height = wrappedRowHeight(data.supplierName, 90);
  const summaryHeader = summary.addRow([
    "STT",
    "Tên hàng",
    "Đơn vị",
    "Số lượng",
    "Ghi chú",
  ]);
  styleWorksheetHeader(summaryHeader);
  data.summaryLines.forEach((line, index) => {
    noteChunks(line.supplierNote).forEach((note, continuation) => {
      const row = summary.addRow([
        continuation ? "↳" : index + 1,
        line.ingredientName,
        line.unitCode,
        null,
        note,
      ]);
      if (!continuation) setQuantity(row.getCell(4), line.orderedQuantity);
      row.getCell(5).alignment = { wrapText: true, vertical: "middle" };
      row.height = Math.max(
        wrappedRowHeight(line.ingredientName, 38),
        wrappedRowHeight(note, 32),
      );
      row.getCell(2).alignment = { wrapText: true, vertical: "middle" };
      borderRow(row);
    });
  });
  summary.getColumn(1).width = 14;
  summary.getColumn(2).width = 38;
  summary.getColumn(3).width = 9;
  summary.getColumn(4).width = 24;
  summary.getColumn(5).width = 32;
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
    (line) => `${line.schoolId}\u0000${line.locationId}`,
  );
  let schoolRow = 10;
  for (const [, lines] of schools) {
    lines.forEach((line, index) => {
      noteChunks(line.supplierNote).forEach((note, continuation) => {
        addDetailRow(
          bySchool,
          schoolRow,
          `${line.schoolName} · ${line.locationName}`,
          continuation ? "↳" : index + 1,
          line.ingredientName,
          line.unitCode,
          continuation ? null : line.orderedQuantity,
          note,
          index === 0 && continuation === 0,
        );
        schoolRow += 1;
      });
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
    (line) =>
      `${line.ingredientId}\u0000${line.unitId}\u0000${line.supplierNote ?? ""}`,
  );
  let ingredientRow = 10;
  for (const [, lines] of ingredients) {
    const { ingredientName, unitCode } = lines[0]!;
    lines.forEach((line, index) => {
      noteChunks(line.supplierNote).forEach((note, continuation) => {
        addDetailRow(
          byIngredient,
          ingredientRow,
          ingredientName,
          continuation ? "↳" : index + 1,
          `${line.schoolName} · ${line.locationName}`,
          unitCode!,
          continuation ? null : line.orderedQuantity,
          note,
          index === 0 && continuation === 0,
        );
        ingredientRow += 1;
      });
    });
  }
  applyDocumentFont(byIngredient);

  for (const [sheet, end, header] of [
    [summary, "E", 7],
    [bySchool, "H", 9],
    [byIngredient, "H", 9],
  ] as const) {
    finishDocumentSheet(
      sheet,
      end,
      header,
      `${data.documentNumber} · ${documentStatusLabel(order.status)}`,
    );
  }
  return workbook.xlsx.writeBuffer();
}

export async function createPurchaseOrderPdf(
  order: SchoolCateringPurchaseOrder,
) {
  const definition = buildPurchaseOrderPdfDefinition(order);
  return renderDocumentPdf(definition);
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
  const safeSupplier = documentFilePart(supplier);
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
