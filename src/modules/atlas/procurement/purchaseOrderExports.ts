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
  createDocumentZip,
  finishDocumentSheet,
  formatExactDocumentQuantity,
  initializeDocumentWorkbook,
  prepareDocumentSheet as prepareWorksheet,
  renderDocumentPdf,
  setExactQuantity as setQuantity,
  wrappedRowHeight,
} from "../documents/documentPresentation";

const QUANTITY_SCALE = 1_000_000n;
function officialCode(value: string | null | undefined) {
  return (
    typeof value === "string" &&
    value.trim().length > 0 &&
    value === value.trim() &&
    Array.from(value).length <= 200 &&
    !/[\u0000-\u001f\u007f]/.test(value) &&
    !/^v1-(ingredient|supplier)-/i.test(value) &&
    !/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i.test(value)
  );
}

type PurchaseOrderExportLine = {
  ingredientDocumentCode: string;
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
  cookingGroupId: string | null;
  cookingGroupName: string | null;
};

export type PurchaseOrderExportData = {
  documentNumber: string;
  supplierName: string;
  supplierDocumentCode: string;
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
  const incompleteMessage =
    "Không đủ dữ liệu chứng từ lịch sử để tái xuất chính thức.";
  if (
    ["RELEASED_TO_SUPPLIER", "SUPERSEDED"].includes(order.status) &&
    (order.document_snapshot_complete !== true ||
      !officialCode(order.current_revision.supplier_document_code_snapshot) ||
      !order.current_revision.supplier_name_snapshot?.trim() ||
      !order.lines.length ||
      order.lines.some(
        (line) =>
          !officialCode(line.ingredient_document_code_snapshot) ||
          !line.ingredient_name_snapshot?.trim() ||
          !line.unit_code_snapshot?.trim(),
      ))
  ) {
    throw new Error(incompleteMessage);
  }
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
      ingredientDocumentCode: string;
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
      ingredientDocumentCode: line.ingredient_document_code_snapshot!,
      ingredientName: line.ingredient_name_snapshot!,
      unitCode: line.unit_code_snapshot!,
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
        cookingGroupId: school.cooking_group_id ?? null,
        cookingGroupName: school.cooking_group_name ?? null,
        ingredientDocumentCode: line.ingredient_document_code_snapshot!,
        ingredientName: line.ingredient_name_snapshot!,
        orderedQuantity: exactQuantity(schoolQuantity),
        unitCode: line.unit_code_snapshot!,
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
    supplierDocumentCode:
      order.current_revision.supplier_document_code_snapshot!,
    serviceDate: dateLabel(order.service_date),
    releasedRevision: order.current_revision.revision_number,
    summaryLines: Array.from(summaries.values(), (line) => ({
      ingredientName: line.ingredientName,
      ingredientDocumentCode: line.ingredientDocumentCode,
      orderedQuantity: exactQuantity(line.quantity),
      unitCode: line.unitCode,
      supplierNote: line.supplierNote,
    })),
    schoolLines,
  };
}

export type PurchaseOrderWorkbookMode =
  "all" | "details_ing" | "details_school" | "sum";
const summaryHeaders = [
  "STT",
  "Mã hàng",
  "Tên hàng",
  "Đơn vị",
  "Số lượng",
  "Ghi chú",
];

function groupBy<T>(items: T[], keyFor: (item: T) => string) {
  const groups = new Map<string, T[]>();
  for (const item of items) {
    const key = keyFor(item);
    const group = groups.get(key) ?? [];
    group.push(item);
    groups.set(key, group);
  }
  return [...groups.values()];
}
function schoolLabel(line: PurchaseOrderSchoolExportLine) {
  return [
    `TRƯỜNG: ${line.schoolName}`,
    ...(line.cookingGroupId && line.cookingGroupName
      ? [`NẤU TẠI: ${line.cookingGroupName}`]
      : []),
    ...(line.schoolName === line.locationName ? [] : [line.locationName]),
  ].join("\n");
}
function detailGroups(
  data: PurchaseOrderExportData,
  direction: "details_ing" | "details_school",
) {
  const lines =
    direction === "details_ing"
      ? [...data.schoolLines].sort(
          (a, b) =>
            a.ingredientId.localeCompare(b.ingredientId) ||
            a.unitId.localeCompare(b.unitId),
        )
      : data.schoolLines;
  return groupBy(lines, (line) =>
    direction === "details_school"
      ? `${line.schoolId}\u0000${line.locationId}`
      : `${line.ingredientId}\u0000${line.unitId}\u0000${line.supplierNote ?? ""}`,
  );
}
function groupLabel(
  lines: PurchaseOrderSchoolExportLine[],
  direction: "details_ing" | "details_school",
) {
  const first = lines[0]!;
  return direction === "details_school"
    ? schoolLabel(first)
    : `${first.ingredientName} (${first.unitCode})`;
}
const noteColumnWidth = 32;
const noteFontSize = 12;
// Native TNR12 wide capitals reach 11.33pt. Use a full em rather than the
// average-glyph estimate: continuous supplier instructions must fit their row.
function noteRowHeight(note: string | null) {
  const capacity = Math.max(
    1,
    Math.floor((noteColumnWidth * 5.25 - 6) / noteFontSize),
  );
  const lines = (note ?? "").split(/\r?\n/).reduce((total, line) => {
    let rows = 1;
    let used = 0;
    // Excel moves a whole word to the next line when it does not fit. A plain
    // character-count ceiling misses that unused space, even with wide glyphs.
    for (const token of line.match(/\s+|\S+/g) ?? []) {
      if (used && used + token.length > capacity) {
        rows++;
        used = 0;
      }
      rows += Math.floor((token.length - 1) / capacity);
      used += ((token.length - 1) % capacity) + 1;
    }
    return total + rows;
  }, 0);
  return Math.max(30, lines * (noteFontSize + 3) + 8);
}
// Excel cannot split a physical row; the same conservative note metric bounds
// each fragment and sizes its row, retaining every character across pages.
function noteChunks(note: string | null) {
  if (!note) return [note];
  const chunks: string[] = [];
  let chunk = "";
  for (const character of note) {
    if (chunk && noteRowHeight(chunk + character) > 180) {
      chunks.push(chunk);
      chunk = "";
    }
    chunk += character;
  }
  chunks.push(chunk);
  return chunks;
}
function lineChunks(line: PurchaseOrderExportLine) {
  const notes = noteChunks(line.supplierNote);
  const codes = line.ingredientDocumentCode.match(/[\s\S]{1,32}/gu)!;
  return Array.from(
    { length: Math.max(notes.length, codes.length) },
    (_, index) => ({
      note: notes[index] ?? null,
      code: codes[index] ?? "",
    }),
  );
}
function codeRowHeight(code: string) {
  // Full-em capacity for the narrow code cell, including wide native TNR glyphs.
  return Math.max(30, Math.ceil(code.length / 4) * 15 + 8);
}
function codeHeaderHeight(
  text: string,
  width: number,
  font: number,
  minimum: number,
) {
  const capacity = Math.max(1, Math.floor((width * 5.25 - 6) / font));
  return Math.max(minimum, Math.ceil(text.length / capacity) * (font + 3) + 8);
}
function selectedViews(mode: PurchaseOrderWorkbookMode) {
  if (!["all", "details_ing", "details_school", "sum"].includes(mode))
    throw new Error("Unknown PO document selection.");
  return (["details_ing", "details_school", "sum"] as const).filter(
    (view) => mode === "all" || view === mode,
  );
}
const viewTitle = {
  details_ing: "CHI TIẾT GIAO HÀNG (THEO HÀNG)",
  details_school: "CHI TIẾT GIAO HÀNG",
  sum: "PHIẾU ĐẶT HÀNG",
};
const viewName = {
  details_ing: "Theo hàng",
  details_school: "Theo trường",
  sum: "Tổng",
};

export function buildPurchaseOrderPdfDefinition(
  order: SchoolCateringPurchaseOrder,
  mode: PurchaseOrderWorkbookMode = "all",
): TDocumentDefinitions {
  const data = buildPurchaseOrderExportData(order);
  const quantityWidth = Math.max(
    60,
    ...[...data.summaryLines, ...data.schoolLines].map(
      (line) =>
        formatExactDocumentQuantity(line.orderedQuantity).text.length * 8 + 6,
    ),
  );
  const content: TDocumentDefinitions["content"] = [];
  for (const [viewIndex, view] of selectedViews(mode).entries()) {
    content.push(
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
        ],
        ...(viewIndex
          ? {
              pageBreak: "before" as const,
              pageOrientation:
                view === "sum" && quantityWidth > 90
                  ? ("landscape" as const)
                  : ("portrait" as const),
            }
          : {}),
      },
      { text: viewTitle[view], style: "heading" },
      { text: `Nhà cung cấp: ${data.supplierName}`, fontSize: 14 },
      { text: `Ngày dùng: ${data.serviceDate}`, bold: true },
      {
        text: `Số đơn: ${data.documentNumber} · v${data.releasedRevision} · ${documentStatusLabel(data.status)}${data.replacementLabel}`,
        fontSize: 11,
        margin: [0, 4, 0, 4],
      },
      { text: `Mã NCC: ${data.supplierDocumentCode}`, fontSize: 11 },
    );
    if (view === "sum") {
      content.push(
        { text: "", margin: [0, 0, 0, 8] },
        {
          table: {
            headerRows: 1,
            widths: [25, 45, "*", 36, quantityWidth, 110],
            dontBreakRows: true,
            body: [
              summaryHeaders.map((text) => ({ text, style: "tableHeader" })),
              ...data.summaryLines.flatMap((line, index) =>
                lineChunks(line).map(({ note, code }, continuation) => [
                  continuation ? "..." : index + 1,
                  { text: code, fontSize: 12 },
                  line.ingredientName,
                  line.unitCode,
                  {
                    text: continuation
                      ? ""
                      : formatExactDocumentQuantity(line.orderedQuantity).text,
                    noWrap: true,
                    alignment: "right" as const,
                  },
                  note ?? "",
                ]),
              ),
            ],
          },
        },
      );
    } else {
      for (const lines of detailGroups(data, view)) {
        const label = groupLabel(lines, view);
        const body: import("pdfmake/interfaces").TableCell[][] = [
          [
            { text: label, colSpan: 6, bold: true, fillColor: "#e8e8e8" },
            {},
            {},
            {},
            {},
            {},
          ],
          [
            "STT",
            "Mã hàng",
            view === "details_school" ? "Tên hàng" : "Trường học",
            "Đơn vị",
            "Số lượng",
            "Ghi chú",
          ].map((text) => ({ text, style: "tableHeader" })),
        ];
        lines.forEach((line, index) => {
          const detail =
            view === "details_school" ? line.ingredientName : schoolLabel(line);
          lineChunks(line).forEach(({ note, code }, continuation) =>
            body.push([
              continuation ? "..." : index + 1,
              { text: code, fontSize: 12 },
              detail,
              line.unitCode,
              {
                text: continuation
                  ? ""
                  : formatExactDocumentQuantity(line.orderedQuantity).text,
                alignment: "right",
                noWrap: true,
              },
              note ?? "",
            ]),
          );
        });
        content.push({
          table: {
            headerRows: 2,
            dontBreakRows: true,
            keepWithHeaderRows: 1,
            widths: [25, 45, "*", 36, quantityWidth, 110],
            body,
          },
          margin: [0, 8, 0, 0],
        });
      }
    }
  }
  return {
    pageSize: "A4",
    pageOrientation:
      mode === "sum" && quantityWidth > 90 ? "landscape" : "portrait",
    pageMargins: [28, 32, 28, 42],
    content,
    footer: documentPdfFooter(
      `${data.documentNumber} · ${documentStatusLabel(data.status)}`,
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
    defaultStyle: { font: "Roboto", fontSize: 14 },
    styles: {
      tableHeader: { bold: true, fontSize: 16 },
      company: { bold: true, fontSize: 14 },
      address: { italics: true, fontSize: 12, margin: [0, 2, 0, 6] },
      heading: {
        bold: true,
        fontSize: 20,
        alignment: "center",
        margin: [0, 8, 0, 12],
      },
    },
  };
}

function styleWorksheetHeader(row: Row) {
  row.font = { name: "Times New Roman", bold: true, size: 16 };
  row.fill = {
    type: "pattern",
    pattern: "solid",
    fgColor: { argb: "FFD9D9D9" },
  };
  row.alignment = { vertical: "middle", horizontal: "center", wrapText: true };
  borderRow(row);
}
function addDetailSheet(
  workbook: import("exceljs").Workbook,
  data: PurchaseOrderExportData,
  direction: "details_ing" | "details_school",
  logoId: number,
) {
  const sheet = workbook.addWorksheet(
    `${data.serviceDate.replaceAll("/", "-")} - ${viewName[direction]}`,
  );
  prepareWorksheet(sheet);
  sheet.addImage(logoId, {
    tl: { col: 0, row: 0 },
    ext: { width: 58, height: 58 },
  });
  sheet.mergeCells("B1:F1");
  sheet.getCell("B1").value = companyName;
  sheet.getCell("B1").font = { name: "Times New Roman", size: 14, bold: true };
  sheet.getCell("B1").alignment = { horizontal: "center" };
  sheet.mergeCells("B2:F2");
  sheet.getCell("B2").value = companyAddress;
  sheet.getCell("B2").font = {
    name: "Times New Roman",
    size: 12,
    italic: true,
  };
  sheet.getCell("B2").alignment = { horizontal: "center" };
  sheet.mergeCells("A4:F4");
  sheet.getCell("A4").value = viewTitle[direction];
  sheet.getCell("A4").font = { name: "Times New Roman", size: 20, bold: true };
  sheet.getCell("A4").alignment = { horizontal: "center" };
  sheet.getCell("D5").value = "Ngày dùng:";
  sheet.mergeCells("E5:F5");
  sheet.getCell("E5").value = data.serviceDate;
  sheet.mergeCells("A6:F6");
  sheet.getCell("A6").value = `Nhà cung cấp: ${data.supplierName}`;
  sheet.mergeCells("A8:F8");
  sheet.getCell("A8").value =
    `${data.documentNumber} · v${data.releasedRevision} · ${documentStatusLabel(data.status)}${data.replacementLabel} · Mã NCC: ${data.supplierDocumentCode}`;
  sheet.getCell("A8").font = { name: "Times New Roman", size: 9 };
  const quantityWidth = Math.max(
    12,
    ...data.schoolLines.map(
      (line) =>
        formatExactDocumentQuantity(line.orderedQuantity).text.length * 1.34 +
        2,
    ),
  );
  // 139 columns fit landscape A4/Letter without shrinking the body font.
  const noteWidth = noteColumnWidth;
  const descriptionWidth =
    quantityWidth > 18
      ? Math.max(34, 139 - 29 - noteWidth - quantityWidth)
      : 34 + Math.max(0, 12 - quantityWidth);
  const formWidth = 29 + noteWidth + descriptionWidth + quantityWidth;
  sheet.pageSetup.orientation = quantityWidth > 18 ? "landscape" : "portrait";
  // Fixed scale preserves manual breaks; Excel fit-to-page ignores them.
  sheet.pageSetup.fitToPage = quantityWidth <= 18;
  [7, 12, descriptionWidth, 10, quantityWidth, noteWidth].forEach(
    (width, i) => (sheet.getColumn(i + 1).width = width),
  );
  for (const [row, height] of [
    [1, 22],
    [2, 24],
    [3, 8],
    [4, 30],
    [5, 22],
    [6, wrappedRowHeight(sheet.getCell("A6").text, formWidth, 14, 22)],
    [7, 12],
    [8, wrappedRowHeight(sheet.getCell("A8").text, formWidth, 9, 20)],
  ])
    sheet.getRow(row!).height =
      row === 8
        ? codeHeaderHeight(sheet.getCell("A8").text, formWidth, 9, height!)
        : height;
  sheet.getRow(9).values = [
    "STT",
    "Mã hàng",
    direction === "details_school" ? "Tên hàng" : "Trường học",
    "Đơn vị",
    "Số lượng",
    "Ghi chú",
  ];
  sheet.getRow(9).height = 46;
  styleWorksheetHeader(sheet.getRow(9));
  let rowNumber = 10;
  const headerHeight = Array.from(
    { length: 9 },
    (_, i) => sheet.getRow(i + 1).height ?? 20,
  ).reduce((a, b) => a + b, 0);
  // ponytail: conservative A4/TNR height budget; native Excel QA owns the ceiling, measured font pagination if other fonts are introduced.
  const landscape = sheet.pageSetup.orientation === "landscape";
  const scale = Math.min(
    1,
    ((landscape ? 841.89 : 595.28) - 0.6 * 72) / (formWidth * 5.25),
  );
  const pageHeight = ((landscape ? 595.28 : 841.89) - 0.9 * 72) / scale - 12;
  let pageUsed = headerHeight;
  let activeLabel = "";
  const band = (label: string) => {
    sheet.mergeCells(rowNumber, 1, rowNumber, 6);
    const row = sheet.getRow(rowNumber++);
    row.getCell(1).value = label;
    row.font = { name: "Times New Roman", size: 14, bold: true };
    row.fill = {
      type: "pattern",
      pattern: "solid",
      fgColor: { argb: "FFE8E8E8" },
    };
    row.height = wrappedRowHeight(label, formWidth, 14, 24);
    row.alignment = { vertical: "middle", wrapText: true };
    borderRow(row);
    pageUsed += row.height;
  };
  const room = (height: number, continuing: boolean) => {
    if (pageUsed + height <= pageHeight) return;
    sheet.getRow(rowNumber - 1).addPageBreak();
    pageUsed = headerHeight;
    if (continuing) band(`${activeLabel} (tiếp)`);
  };
  for (const lines of detailGroups(data, direction)) {
    activeLabel = groupLabel(lines, direction);
    room(
      wrappedRowHeight(activeLabel, formWidth, 14, 24) +
        wrappedRowHeight(
          direction === "details_school"
            ? lines[0]!.ingredientName
            : schoolLabel(lines[0]!),
          descriptionWidth,
          14,
          30,
        ),
      false,
    );
    band(activeLabel);
    lines.forEach((line, index) => {
      const detail =
        direction === "details_school"
          ? line.ingredientName
          : schoolLabel(line);
      lineChunks(line).forEach(({ note, code }, continuation) => {
        const height = Math.max(
          wrappedRowHeight(detail, descriptionWidth, 14, 30),
          noteRowHeight(note),
          codeRowHeight(code),
        );
        room(height, true);
        const row = sheet.getRow(rowNumber++);
        row.values = [
          continuation ? "..." : index + 1,
          code,
          detail,
          line.unitCode,
          null,
          note,
        ];
        row.font = { name: "Times New Roman", size: 14 };
        row.getCell(6).font = { name: "Times New Roman", size: noteFontSize };
        row.getCell(2).font = { name: "Times New Roman", size: 12 };
        row.alignment = { vertical: "middle", wrapText: true };
        row.height = height;
        if (!continuation) setQuantity(row.getCell(5), line.orderedQuantity);
        borderRow(row);
        pageUsed += height;
      });
    });
    sheet.getRow(rowNumber++).height = 20;
    pageUsed += 20;
  }
  applyDocumentFont(sheet);
  finishDocumentSheet(
    sheet,
    "F",
    9,
    `${data.documentNumber} · ${documentStatusLabel(data.status)}`,
  );
}
function addSummarySheet(
  workbook: import("exceljs").Workbook,
  data: PurchaseOrderExportData,
  logoId: number,
) {
  const sheet = workbook.addWorksheet(
    `${data.serviceDate.replaceAll("/", "-")} - Tổng`,
  );
  prepareWorksheet(sheet);
  sheet.addImage(logoId, {
    tl: { col: 0, row: 0 },
    ext: { width: 75, height: 65 },
  });
  sheet.mergeCells("C1:F1");
  sheet.getCell("C1").value = companyName;
  sheet.getCell("C1").font = { name: "Times New Roman", bold: true, size: 14 };
  sheet.mergeCells("C2:F2");
  sheet.getCell("C2").value = companyAddress;
  sheet.getCell("C2").font = {
    name: "Times New Roman",
    size: 12,
    italic: true,
  };
  sheet.mergeCells("A4:F4");
  sheet.getCell("A4").value = "PHIẾU ĐẶT HÀNG";
  sheet.getCell("A4").font = { name: "Times New Roman", bold: true, size: 20 };
  sheet.getCell("A4").alignment = { horizontal: "center" };
  sheet.mergeCells("A5:F5");
  sheet.getCell("A5").value =
    `${data.documentNumber} · v${data.releasedRevision} · ${documentStatusLabel(data.status)}${data.replacementLabel}`;
  sheet.getCell("A5").font = { name: "Times New Roman", size: 9 };
  sheet.mergeCells("A6:F6");
  sheet.getCell("A6").value = `Nhà cung cấp: ${data.supplierName}`;
  sheet.getCell("A7").value = "Ngày dùng:";
  sheet.mergeCells("B7:F7");
  sheet.getCell("B7").value = data.serviceDate;
  sheet.mergeCells("A8:F8");
  sheet.getCell("A8").value = `Mã NCC: ${data.supplierDocumentCode}`;
  sheet.mergeCells("A9:F9");
  sheet.getCell("A9").value = "";
  sheet.getCell("A9").font = { name: "Times New Roman", size: 10 };
  const quantityWidth = Math.max(
    10,
    ...data.summaryLines.map(
      (line) =>
        formatExactDocumentQuantity(line.orderedQuantity).text.length * 1.34 +
        2,
    ),
  );
  const noteWidth = noteColumnWidth;
  sheet.pageSetup.orientation = quantityWidth > 18 ? "landscape" : "portrait";
  sheet.pageSetup.fitToPage = quantityWidth <= 18;
  const descriptionWidth =
    quantityWidth > 18
      ? Math.max(36, 139 - 7 - 12 - 9.71 - quantityWidth - noteWidth)
      : 36 + Math.max(0, 12.71 - quantityWidth);
  [7, 12, descriptionWidth, 9.71, quantityWidth, noteWidth].forEach(
    (width, i) => (sheet.getColumn(i + 1).width = width),
  );
  for (const [r, w, size, minimum] of [
    [1, descriptionWidth + 9.71 + quantityWidth + noteWidth, 14, 22],
    [2, descriptionWidth + 9.71 + quantityWidth + noteWidth, 12, 20],
    [4, 105, 20, 30],
    [5, 105, 9, 22],
    [6, 105, 14, 26],
    [8, 105, 12, 22],
    [9, 105, 10, 20],
  ])
    sheet.getRow(r!).height =
      r === 8
        ? codeHeaderHeight(sheet.getCell("A8").text, w!, size!, minimum!)
        : wrappedRowHeight(
            sheet.getCell(r!, r! <= 2 ? 3 : 1).text,
            w!,
            size,
            minimum,
          );
  sheet.getRow(3).height = 8;
  sheet.getRow(7).height = 24;
  sheet.getRow(10).values = summaryHeaders;
  sheet.getRow(10).height = 46;
  styleWorksheetHeader(sheet.getRow(10));
  let rowNumber = 11;
  data.summaryLines.forEach((line, index) =>
    lineChunks(line).forEach(({ note, code }, continuation) => {
      const row = sheet.getRow(rowNumber++);
      row.values = [
        continuation ? "..." : index + 1,
        code,
        line.ingredientName,
        line.unitCode,
        null,
        note,
      ];
      row.font = { name: "Times New Roman", size: 14 };
      row.alignment = { vertical: "middle", wrapText: true };
      row.getCell(6).font = { name: "Times New Roman", size: noteFontSize };
      row.getCell(2).font = { name: "Times New Roman", size: 12 };
      row.height = Math.max(
        wrappedRowHeight(line.ingredientName, descriptionWidth, 14),
        noteRowHeight(note),
        codeRowHeight(code),
      );
      if (!continuation) setQuantity(row.getCell(5), line.orderedQuantity);
      borderRow(row);
    }),
  );
  applyDocumentFont(sheet);
  finishDocumentSheet(
    sheet,
    "F",
    10,
    `${data.documentNumber} · ${documentStatusLabel(data.status)}`,
  );
}
export async function createPurchaseOrderXlsx(
  order: SchoolCateringPurchaseOrder,
  mode: PurchaseOrderWorkbookMode = "all",
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
  for (const view of selectedViews(mode)) {
    if (view === "sum") addSummarySheet(workbook, data, logoId);
    else addDetailSheet(workbook, data, view, logoId);
  }
  return workbook.xlsx.writeBuffer();
}

export async function createPurchaseOrderPdf(
  order: SchoolCateringPurchaseOrder,
  mode: PurchaseOrderWorkbookMode = "all",
) {
  const definition = buildPurchaseOrderPdfDefinition(order, mode);
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
  mode: PurchaseOrderWorkbookMode = "all",
) {
  const bytes = await createPurchaseOrderXlsx(order, mode);
  downloadBytes(
    bytes,
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    `${purchaseOrderFileStem(order)}-${mode}.xlsx`,
  );
}

export async function downloadPurchaseOrderPdf(
  order: SchoolCateringPurchaseOrder,
  mode: PurchaseOrderWorkbookMode = "all",
) {
  const bytes = await createPurchaseOrderPdf(order, mode);
  downloadBytes(
    bytes,
    "application/pdf",
    `${purchaseOrderFileStem(order)}-${mode}.pdf`,
  );
}

export async function createPurchaseOrderZip(
  orders: SchoolCateringPurchaseOrder[],
  mode: PurchaseOrderWorkbookMode = "all",
) {
  const ids = new Set<string>();
  const files = [];
  const ordered = [...orders].sort(
    (a, b) =>
      a.service_date.localeCompare(b.service_date) ||
      a.supplier.supplier_id.localeCompare(b.supplier.supplier_id) ||
      a.purchase_order_id.localeCompare(b.purchase_order_id),
  );
  for (const [index, order] of ordered.entries()) {
    buildPurchaseOrderExportData(order);
    if (ids.has(order.purchase_order_id))
      throw new Error("Duplicate PO identity.");
    ids.add(order.purchase_order_id);
    files.push({
      name: `${purchaseOrderFileStem(order)}-${index + 1}-${mode}.xlsx`,
      bytes: await createPurchaseOrderXlsx(order, mode),
    });
  }
  return createDocumentZip(files);
}

export async function downloadPurchaseOrderZip(
  orders: SchoolCateringPurchaseOrder[],
  mode: PurchaseOrderWorkbookMode = "all",
) {
  downloadBytes(
    await createPurchaseOrderZip(orders, mode),
    "application/zip",
    `PO-supplier-date-${mode}.zip`,
  );
}
