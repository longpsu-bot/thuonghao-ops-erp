import ExcelJS from "exceljs";
import {
  confirmedNeedInputDisplay,
  exactDecimalEqual,
  normalizeConfirmedNeedEntry,
  normalizeConfirmedNeedQuantity,
  type ConfirmedNeedDraftLine,
  type ConfirmedNeedLine,
  type ConfirmedNeedWorkbenchData,
} from "./confirmedNeedModel";

const visibleHeaders = ["TRƯỜNG", "THÀNH PHẦN", "ĐVT", "SL", "GHI CHÚ"];
const technicalHeaders = [
  "ATLAS_BATCH_ID",
  "ATLAS_BATCH_VERSION",
  "ATLAS_RUN_ID",
  "ATLAS_RELEASE_SNAPSHOT_ID",
  "ATLAS_LINE_ID",
  "ATLAS_REVISION_ID",
  "ATLAS_REVISION_NUMBER",
  "ATLAS_DECISION_ID",
  "ATLAS_DECISION_NUMBER",
  "ATLAS_SERVICE_DATE",
  "ATLAS_SCHOOL_ID",
  "ATLAS_LOCATION_ID",
  "ATLAS_INGREDIENT_ID",
  "ATLAS_UNIT_ID",
  "ATLAS_EXPORTED_QUANTITY",
  "ATLAS_REASON_CODE",
  "ATLAS_WORKBOOK_MARKER",
] as const;
const marker = "ATLAS_CONFIRMED_NEED_SHOPPING_LIST_V1";
const firstDataRow = 4;
const quantityColumn = 4;
const noteColumn = 5;

function cellText(value: ExcelJS.CellValue | undefined | null) {
  if (value === null || value === undefined) return "";
  if (typeof value === "object") {
    if ("text" in value) return String(value.text);
    if ("result" in value && value.result !== undefined)
      return String(value.result);
  }
  return String(value).trim();
}

function xlsxQuantity(value: string): number | string {
  const numeric = Number(value);
  return Number.isSafeInteger(numeric * 1_000_000) ? numeric : value;
}

function orderedLines(workbench: ConfirmedNeedWorkbenchData) {
  const schoolOrder = new Map<string, number>();
  for (const line of workbench.lines) {
    if (!schoolOrder.has(line.school.id))
      schoolOrder.set(line.school.id, schoolOrder.size);
  }
  return workbench.lines
    .map((line, sourceIndex) => ({ line, sourceIndex }))
    .sort(
      (left, right) =>
        left.line.service_date.localeCompare(right.line.service_date) ||
        schoolOrder.get(left.line.school.id)! -
          schoolOrder.get(right.line.school.id)! ||
        left.sourceIndex - right.sourceIndex,
    )
    .map(({ line }) => line);
}

function staffDateTitle(date: string) {
  const [year, month, day] = date.split("-").map(Number);
  const weekdays = [
    "Chủ Nhật",
    "Thứ Hai",
    "Thứ Ba",
    "Thứ Tư",
    "Thứ Năm",
    "Thứ Sáu",
    "Thứ Bảy",
  ];
  const weekday =
    weekdays[new Date(Date.UTC(year!, month! - 1, day)).getUTCDay()];
  return `${weekday} (${date.split("-").reverse().join("/")})`;
}

function addSheet(
  workbook: ExcelJS.Workbook,
  date: string,
  workbench: ConfirmedNeedWorkbenchData,
  lines: ConfirmedNeedLine[],
  drafts: Record<string, ConfirmedNeedDraftLine>,
) {
  const sheet = workbook.addWorksheet(date, {
    views: [{ showGridLines: false, state: "frozen", ySplit: 3 }],
    pageSetup: {
      paperSize: 9,
      orientation: "landscape",
      fitToPage: true,
      fitToWidth: 1,
      fitToHeight: 0,
      margins: {
        left: 0.25,
        right: 0.25,
        top: 0.5,
        bottom: 0.5,
        header: 0.2,
        footer: 0.2,
      },
    },
  });
  sheet.columns = [
    { width: 17.57 },
    { width: 42 },
    { width: 8 },
    { width: 11 },
    { width: 12 },
    ...technicalHeaders.map(() => ({ width: 1, hidden: true })),
  ];
  sheet.mergeCells("A1:E1");
  const title = sheet.getCell("A1");
  title.value = staffDateTitle(date);
  title.font = { name: "Times New Roman", size: 20, bold: true };
  title.alignment = { horizontal: "center", vertical: "middle" };
  sheet.getRow(1).height = 36;
  sheet.getRow(2).height = 8.1;

  const header = sheet.getRow(3);
  header.values = [...visibleHeaders, ...technicalHeaders];
  header.height = 36;
  header.font = {
    name: "Times New Roman",
    size: 18,
    bold: true,
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

  let previousSchoolId: string | null = null;
  lines.forEach((line, index) => {
    const draft = drafts[line.confirmed_need_line_id];
    if (!draft)
      throw new Error(
        `Thiếu bản nháp cho dòng ${line.confirmed_need_line_id}.`,
      );
    const row = sheet.getRow(firstDataRow + index);
    const startsSchool = previousSchoolId !== line.school.id;
    row.values = [
      startsSchool ? line.school.name : null,
      line.ingredient.name,
      line.controlled_unit.code,
      xlsxQuantity(draft.exact_quantity),
      draft.reason_note,
      workbench.confirmed_need_batch_id,
      workbench.batch_version,
      workbench.need_generation_source.run_id,
      workbench.need_generation_source.release_snapshot_id,
      line.confirmed_need_line_id,
      line.current_revision_id,
      line.current_revision_number,
      line.current_decision_id ?? "",
      line.current_decision_number ?? "",
      line.service_date,
      line.school.id,
      line.delivery_location.id,
      line.ingredient.id,
      line.controlled_unit.id,
      draft.exact_quantity,
      draft.reason_code,
      marker,
    ];
    row.height = startsSchool ? 42 : 30;
    row.font = { name: "Times New Roman", size: 18 };
    row.alignment = { vertical: "middle", wrapText: true };
    if (startsSchool)
      row.getCell(1).font = {
        name: "Times New Roman",
        size: 18,
        bold: true,
      };
    for (let column = 1; column <= visibleHeaders.length; column += 1) {
      row.getCell(column).border = {
        top: {
          style: startsSchool ? "thick" : "thin",
          color: { argb: "FF000000" },
        },
        left: { style: "thin", color: { argb: "FF000000" } },
        right: { style: "thin", color: { argb: "FF000000" } },
        bottom: { style: "thin", color: { argb: "FF000000" } },
      };
    }
    row.getCell(quantityColumn).numFmt = "0.##";
    row.getCell(quantityColumn).protection = { locked: false };
    row.getCell(noteColumn).protection = { locked: false };
    previousSchoolId = line.school.id;
  });
  sheet.autoFilter = { from: "A3", to: "E3" };
  return sheet.protect(marker, {
    selectLockedCells: true,
    selectUnlockedCells: true,
    autoFilter: true,
  });
}

export async function createConfirmedNeedShoppingListXlsx(
  workbench: ConfirmedNeedWorkbenchData,
  drafts: Record<string, ConfirmedNeedDraftLine>,
  exportedAt = new Date(),
) {
  const workbook = new ExcelJS.Workbook();
  workbook.creator = "OPS ERP - Project Atlas";
  workbook.created = exportedAt;
  const groups = new Map<string, ConfirmedNeedLine[]>();
  for (const line of orderedLines(workbench)) {
    const lines = groups.get(line.service_date) ?? [];
    lines.push(line);
    groups.set(line.service_date, lines);
  }
  await Promise.all(
    [...groups].map(([date, lines]) =>
      addSheet(workbook, date, workbench, lines, drafts),
    ),
  );
  return workbook.xlsx.writeBuffer();
}

export type ConfirmedNeedShoppingListImport = {
  drafts: Record<string, ConfirmedNeedDraftLine>;
  changedLineIds: string[];
};

export async function parseConfirmedNeedShoppingListXlsx(
  bytes: ArrayBuffer | Uint8Array,
  workbench: ConfirmedNeedWorkbenchData,
  currentDrafts: Record<string, ConfirmedNeedDraftLine>,
): Promise<ConfirmedNeedShoppingListImport> {
  const workbook = new ExcelJS.Workbook();
  await workbook.xlsx.load(
    bytes as unknown as Parameters<typeof workbook.xlsx.load>[0],
  );
  const linesById = new Map(
    workbench.lines.map((line) => [line.confirmed_need_line_id, line]),
  );
  const nextDrafts = structuredClone(currentDrafts);
  const seen = new Set<string>();
  const changedLineIds: string[] = [];

  for (const sheet of workbook.worksheets) {
    for (
      let rowNumber = firstDataRow;
      rowNumber <= sheet.rowCount;
      rowNumber += 1
    ) {
      const row = sheet.getRow(rowNumber);
      if (!row.hasValues) continue;
      const values = Array.from(
        { length: technicalHeaders.length },
        (_, index) =>
          cellText(row.getCell(visibleHeaders.length + index + 1).value),
      );
      const [
        batchId,
        batchVersion,
        runId,
        releaseSnapshotId,
        lineId,
        revisionId,
        revisionNumber,
        decisionId,
        decisionNumber,
        serviceDate,
        schoolId,
        locationId,
        ingredientId,
        unitId,
        exportedQuantity,
        exportedReasonCode,
        workbookMarker,
      ] = values;
      if (seen.has(lineId!))
        throw new Error(`Workbook có trùng dòng Atlas ${lineId}.`);
      const line = linesById.get(lineId!);
      if (
        workbookMarker !== marker ||
        batchId !== workbench.confirmed_need_batch_id ||
        batchVersion !== String(workbench.batch_version) ||
        runId !== workbench.need_generation_source.run_id ||
        releaseSnapshotId !==
          workbench.need_generation_source.release_snapshot_id ||
        !line ||
        revisionId !== line.current_revision_id ||
        revisionNumber !== String(line.current_revision_number) ||
        decisionId !== (line.current_decision_id ?? "") ||
        decisionNumber !== String(line.current_decision_number ?? "") ||
        serviceDate !== line.service_date ||
        schoolId !== line.school.id ||
        locationId !== line.delivery_location.id ||
        ingredientId !== line.ingredient.id ||
        unitId !== line.controlled_unit.id
      )
        throw new Error(
          `Workbook không còn khớp dữ liệu Atlas hiện tại (dòng ${rowNumber}).`,
        );
      seen.add(lineId!);

      const rawQuantity = cellText(row.getCell(quantityColumn).value);
      const normalizedQuantity = normalizeConfirmedNeedEntry(rawQuantity);
      if (!normalizedQuantity)
        throw new Error(
          `Số lượng tại dòng ${rowNumber} phải là số không âm, tối đa 2 chữ số thập phân.`,
        );
      const note = cellText(row.getCell(noteColumn).value);
      const quantityChanged = !exactDecimalEqual(
        normalizeConfirmedNeedQuantity(exportedQuantity!) ?? exportedQuantity!,
        normalizedQuantity,
      );
      if (quantityChanged && !note)
        throw new Error(`Dòng ${rowNumber} cần ghi chú khi thay đổi số lượng.`);

      const existing = currentDrafts[lineId!];
      if (!existing)
        throw new Error(`Không tìm thấy bản nháp Atlas cho dòng ${lineId}.`);
      const reasonCode = quantityChanged
        ? "OPERATIONAL_QUANTITY_ADJUSTMENT"
        : (exportedReasonCode as ConfirmedNeedDraftLine["reason_code"]);
      if (
        ![
          "PROPOSAL_ACCEPTED",
          "PLANNING_STEP_ADJUSTMENT",
          "OPERATIONAL_QUANTITY_ADJUSTMENT",
          "OTHER",
        ].includes(reasonCode)
      )
        throw new Error(
          `Mã lý do trong workbook không hợp lệ tại dòng ${rowNumber}.`,
        );
      nextDrafts[lineId!] = {
        ...existing,
        exact_quantity: quantityChanged
          ? confirmedNeedInputDisplay(normalizedQuantity)
          : existing.exact_quantity,
        quantity_entered: quantityChanged ? true : existing.quantity_entered,
        reason_code: reasonCode,
        reason_note: note,
      };
      if (
        !exactDecimalEqual(existing.exact_quantity, normalizedQuantity) ||
        existing.reason_code !== reasonCode ||
        existing.reason_note.trim() !== note
      )
        changedLineIds.push(lineId!);
    }
  }
  if (seen.size !== workbench.lines.length)
    throw new Error("Workbook thiếu dòng Atlas nên không thể nhập một phần.");
  return { drafts: nextDrafts, changedLineIds };
}

export async function downloadConfirmedNeedShoppingList(
  workbench: ConfirmedNeedWorkbenchData,
  drafts: Record<string, ConfirmedNeedDraftLine>,
) {
  const bytes = await createConfirmedNeedShoppingListXlsx(workbench, drafts);
  const blob = new Blob([bytes as BlobPart], {
    type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = `Shopping-List-${workbench.service_period.period_start}-${workbench.service_period.period_end}.xlsx`;
  anchor.click();
  URL.revokeObjectURL(url);
}

export async function importConfirmedNeedShoppingList(
  file: File,
  workbench: ConfirmedNeedWorkbenchData,
  drafts: Record<string, ConfirmedNeedDraftLine>,
) {
  return parseConfirmedNeedShoppingListXlsx(
    await file.arrayBuffer(),
    workbench,
    drafts,
  );
}
