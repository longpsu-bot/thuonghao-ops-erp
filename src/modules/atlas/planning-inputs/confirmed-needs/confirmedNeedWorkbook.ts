import {
  confirmedNeedReasonCodeFromLabel,
  confirmedNeedReasonLabel,
  confirmedNeedReasonLabels,
  exactDecimalEqual,
  initialConfirmedNeedDraft,
  normalizeConfirmedNeedQuantity,
  subtractExactDecimals,
  type ConfirmedNeedDraftLine,
  type ConfirmedNeedLine,
  type ConfirmedNeedReasonCode,
  type ConfirmedNeedWorkbenchData,
} from "./confirmedNeedModel";

export const CONFIRMED_NEED_WORKBOOK_CONTRACT = "CONFIRMED_NEED_XLSX.v1";
export const CONFIRMED_NEED_OPERATOR_SHEET = "Xác nhận nhu cầu";
export const CONFIRMED_NEED_META_SHEET = "_ATLAS_META";

export const confirmedNeedVisibleColumns = [
  "Ngày",
  "Trường",
  "Điểm giao",
  "Nguyên liệu",
  "ĐVT",
  "SL lý thuyết",
  "SL đề xuất",
  "SL xác nhận",
  "Chênh lệch",
  "Lý do",
  "Ghi chú",
] as const;

export const confirmedNeedHiddenColumns = [
  "__confirmed_need_line_id",
  "__current_revision_id",
  "__current_decision_id",
] as const;

export const confirmedNeedWorkbookColumns = [
  ...confirmedNeedVisibleColumns,
  ...confirmedNeedHiddenColumns,
] as const;

export const confirmedNeedMetaKeys = [
  "workbook_contract_version",
  "confirmed_need_batch_id",
  "batch_version",
  "exported_at",
] as const;

type WorkbookCell =
  | string
  | number
  | boolean
  | Date
  | {
      value: string;
      type: StringConstructor;
      format: string;
      fontWeight?: "bold";
    };
type WorkbookSheetData = WorkbookCell[][];
type WorkbookSheet = {
  sheet: string;
  data: WorkbookSheetData;
  stickyRowsCount?: number;
  columns: { width: number }[];
};
type WorkbookElementAttributes = Record<string, string | number>;
type ReadWorkbookCell = string | number | boolean | DateConstructor | null;
type ReadWorkbookSheet = { sheet: string; data: ReadWorkbookCell[][] };

export const confirmedNeedWorkbookVisibilityFeature = {
  files: {
    transform: {
      "xl/workbook.xml": {
        transformElementAttributes(
          tagName: string,
          attributes: WorkbookElementAttributes,
          index: number | undefined,
          _sheetOptions: unknown,
          _properties: unknown,
        ) {
          if (tagName === "sheet" && index === 1)
            return { ...attributes, state: "hidden" };
          return attributes;
        },
      },
      "xl/worksheets/sheet{id}.xml": {
        transformElementAttributes(
          tagName: string,
          attributes: WorkbookElementAttributes,
          index: number | undefined,
          _sheetOptions: unknown,
          properties: { sheetIndex: number; sheetId: string },
        ) {
          if (
            properties.sheetIndex === 0 &&
            tagName === "col" &&
            index !== undefined &&
            index >= confirmedNeedVisibleColumns.length
          )
            return { ...attributes, hidden: 1 };
          return attributes;
        },
      },
    },
  },
};

export class ConfirmedNeedWorkbookError extends Error {
  constructor(
    public readonly code:
      | "EMPTY_EXPORT"
      | "BATCH_DRIFT"
      | "PAGING_DRIFT"
      | "DUPLICATE_LINE"
      | "INCOMPLETE_BATCH",
    message: string,
  ) {
    super(message);
    this.name = "ConfirmedNeedWorkbookError";
  }
}

function stableLineSort(left: ConfirmedNeedLine, right: ConfirmedNeedLine) {
  return (
    left.service_date.localeCompare(right.service_date) ||
    left.school.name.localeCompare(right.school.name, "vi") ||
    left.delivery_location.name.localeCompare(
      right.delivery_location.name,
      "vi",
    ) ||
    left.ingredient.name.localeCompare(right.ingredient.name, "vi") ||
    left.confirmed_need_line_id.localeCompare(right.confirmed_need_line_id)
  );
}

export function assembleConfirmedNeedPages(
  pages: ConfirmedNeedWorkbenchData[],
): ConfirmedNeedWorkbenchData {
  const first = pages[0];
  if (!first)
    throw new ConfirmedNeedWorkbookError(
      "EMPTY_EXPORT",
      "Không có dữ liệu lô nhu cầu để xuất Excel.",
    );
  const expectedTotal = first.pagination.total_lines;
  let expectedOffset = 0;
  const lines: ConfirmedNeedLine[] = [];
  const ids = new Set<string>();

  for (const page of pages) {
    if (
      page.confirmed_need_batch_id !== first.confirmed_need_batch_id ||
      page.batch_version !== first.batch_version ||
      page.pagination.total_lines !== expectedTotal
    )
      throw new ConfirmedNeedWorkbookError(
        "BATCH_DRIFT",
        "Dữ liệu đã thay đổi trong lúc tải. Hãy làm mới rồi xuất Excel lại.",
      );
    if (page.pagination.offset !== expectedOffset)
      throw new ConfirmedNeedWorkbookError(
        "PAGING_DRIFT",
        "Các trang dữ liệu không liên tục. Hãy làm mới rồi xuất Excel lại.",
      );
    for (const line of page.lines) {
      if (ids.has(line.confirmed_need_line_id))
        throw new ConfirmedNeedWorkbookError(
          "DUPLICATE_LINE",
          "Phát hiện dòng nhu cầu trùng khi xuất Excel. Hãy làm mới dữ liệu.",
        );
      ids.add(line.confirmed_need_line_id);
      lines.push(line);
    }
    expectedOffset += page.lines.length;
  }

  const last = pages.at(-1)!;
  if (
    lines.length !== expectedTotal ||
    expectedOffset !== expectedTotal ||
    last.pagination.has_more
  )
    throw new ConfirmedNeedWorkbookError(
      "INCOMPLETE_BATCH",
      "Chưa tải đủ toàn bộ lô nhu cầu. Hãy làm mới rồi xuất Excel lại.",
    );

  return {
    ...first,
    lines: [...lines].sort(stableLineSort),
    pagination: {
      offset: 0,
      limit: expectedTotal,
      total_lines: expectedTotal,
      has_more: false,
    },
  };
}

function textCell(value: string, bold = false): WorkbookCell {
  return {
    value,
    type: String,
    format: "@",
    fontWeight: bold ? "bold" : undefined,
  };
}

function viDate(value: string) {
  const [year, month, day] = value.slice(0, 10).split("-");
  return year && month && day ? `${day}/${month}/${year}` : value;
}

function draftForLine(
  line: ConfirmedNeedLine,
  drafts: Record<string, ConfirmedNeedDraftLine>,
) {
  return drafts[line.confirmed_need_line_id] ?? initialConfirmedNeedDraft(line);
}

export function buildConfirmedNeedWorkbookSheets(
  workbench: ConfirmedNeedWorkbenchData,
  drafts: Record<string, ConfirmedNeedDraftLine>,
  exportedAt: string,
) {
  const operatorData: WorkbookSheetData = [
    confirmedNeedWorkbookColumns.map((column) => textCell(column, true)),
    ...workbench.lines.map((line) => {
      const draft = draftForLine(line, drafts);
      return [
        viDate(line.service_date),
        line.school.name,
        line.delivery_location.name,
        line.ingredient.name,
        line.controlled_unit.code,
        textCell(line.theoretical_quantity),
        textCell(line.proposed_confirmed_quantity),
        textCell(draft.exact_quantity),
        textCell(
          subtractExactDecimals(
            draft.exact_quantity,
            line.proposed_confirmed_quantity,
          ) ?? "",
        ),
        confirmedNeedReasonLabel(draft.reason_code),
        draft.reason_note,
        line.confirmed_need_line_id,
        line.current_revision_id,
        line.current_decision_id ?? "",
      ];
    }),
  ];
  const metadata = {
    workbook_contract_version: CONFIRMED_NEED_WORKBOOK_CONTRACT,
    confirmed_need_batch_id: workbench.confirmed_need_batch_id,
    batch_version: String(workbench.batch_version),
    exported_at: exportedAt,
  } satisfies Record<(typeof confirmedNeedMetaKeys)[number], string>;
  const metaData: WorkbookSheetData = confirmedNeedMetaKeys.map((key) => [
    textCell(key),
    textCell(metadata[key]),
  ]);
  const sheets: WorkbookSheet[] = [
    {
      sheet: CONFIRMED_NEED_OPERATOR_SHEET,
      data: operatorData,
      stickyRowsCount: 1,
      columns: [
        { width: 13 },
        { width: 28 },
        { width: 22 },
        { width: 28 },
        { width: 10 },
        { width: 16 },
        { width: 16 },
        { width: 16 },
        { width: 16 },
        { width: 30 },
        { width: 34 },
        { width: 18 },
        { width: 18 },
        { width: 18 },
      ],
    },
    {
      sheet: CONFIRMED_NEED_META_SHEET,
      data: metaData,
      columns: [{ width: 34 }, { width: 48 }],
    },
  ];
  return { operatorData, metaData, metadata, sheets };
}

export async function createConfirmedNeedWorkbookBlob(
  workbench: ConfirmedNeedWorkbenchData,
  drafts: Record<string, ConfirmedNeedDraftLine>,
  exportedAt = new Date().toISOString(),
) {
  const { default: writeXlsxFile } = await import("write-excel-file/browser");
  const { sheets } = buildConfirmedNeedWorkbookSheets(
    workbench,
    drafts,
    exportedAt,
  );
  return writeXlsxFile(sheets, {
    features: [confirmedNeedWorkbookVisibilityFeature],
  }).toBlob();
}

export async function downloadConfirmedNeedWorkbook(
  workbench: ConfirmedNeedWorkbenchData,
  drafts: Record<string, ConfirmedNeedDraftLine>,
  fileName: string,
  exportedAt = new Date().toISOString(),
) {
  const { default: writeXlsxFile } = await import("write-excel-file/browser");
  const { sheets } = buildConfirmedNeedWorkbookSheets(
    workbench,
    drafts,
    exportedAt,
  );
  await writeXlsxFile(sheets, {
    features: [confirmedNeedWorkbookVisibilityFeature],
  }).toFile(fileName);
}

export type ConfirmedNeedReadWorkbook = ReadWorkbookSheet[];

export function parseExactWorkbookNumber(source: string) {
  return source;
}

export async function readConfirmedNeedWorkbook(
  input: File | Blob | ArrayBuffer,
) {
  const { default: readXlsxFile } = await import("read-excel-file/browser");
  return readXlsxFile<string>(input, {
    trim: false,
    parseNumber: parseExactWorkbookNumber,
  });
}

export type ConfirmedNeedImportError = {
  rowNumber: number | null;
  field: string;
  message: string;
};

export type ConfirmedNeedImportChangedLine = {
  line: ConfirmedNeedLine;
  rowNumber: number;
  before: ConfirmedNeedDraftLine;
  after: ConfirmedNeedDraftLine;
  differenceFromProposal: string;
  noteRequired: boolean;
};

export type ConfirmedNeedImportReview = {
  totalRows: number;
  changedRows: number;
  unchangedRows: number;
  errorRows: number;
  errors: ConfirmedNeedImportError[];
  changedLines: ConfirmedNeedImportChangedLine[];
  candidate: Record<string, ConfirmedNeedDraftLine> | null;
  canApply: boolean;
};

function cellText(value: ReadWorkbookCell) {
  return typeof value === "string" ? value : null;
}

function addError(
  errors: ConfirmedNeedImportError[],
  rowNumber: number | null,
  field: string,
  message: string,
) {
  errors.push({ rowNumber, field, message });
}

function expectedReferences(line: ConfirmedNeedLine) {
  return [
    viDate(line.service_date),
    line.school.name,
    line.delivery_location.name,
    line.ingredient.name,
    line.controlled_unit.code,
  ];
}

function editableChanged(
  before: ConfirmedNeedDraftLine,
  after: ConfirmedNeedDraftLine,
) {
  return (
    !exactDecimalEqual(before.exact_quantity, after.exact_quantity) ||
    before.reason_code !== after.reason_code ||
    before.reason_note.trim() !== after.reason_note.trim()
  );
}

function noteRequiredFor(
  line: ConfirmedNeedLine,
  code: ConfirmedNeedReasonCode,
  changed: boolean,
) {
  return (
    code === "OPERATIONAL_QUANTITY_ADJUSTMENT" ||
    code === "OTHER" ||
    Boolean(line.current_decision_id && changed)
  );
}

function structuralReview(errors: ConfirmedNeedImportError[]) {
  return {
    totalRows: 0,
    changedRows: 0,
    unchangedRows: 0,
    errorRows: errors.length,
    errors,
    changedLines: [],
    candidate: null,
    canApply: false,
  } satisfies ConfirmedNeedImportReview;
}

export function reviewConfirmedNeedWorkbook(
  workbook: ConfirmedNeedReadWorkbook,
  authority: ConfirmedNeedWorkbenchData,
  drafts: Record<string, ConfirmedNeedDraftLine>,
): ConfirmedNeedImportReview {
  const errors: ConfirmedNeedImportError[] = [];
  const operatorSheets = workbook.filter(
    (sheet) => sheet.sheet === CONFIRMED_NEED_OPERATOR_SHEET,
  );
  const metaSheets = workbook.filter(
    (sheet) => sheet.sheet === CONFIRMED_NEED_META_SHEET,
  );
  if (operatorSheets.length !== 1)
    addError(
      errors,
      null,
      "Trang tính",
      `File phải có đúng một trang “${CONFIRMED_NEED_OPERATOR_SHEET}”.`,
    );
  if (metaSheets.length !== 1)
    addError(
      errors,
      null,
      "Metadata",
      `File phải có đúng một trang “${CONFIRMED_NEED_META_SHEET}”.`,
    );
  if (errors.length) return structuralReview(errors);

  const operator = operatorSheets[0]!;
  const meta = metaSheets[0]!;
  const header = operator.data[0] ?? [];
  if (
    header.length !== confirmedNeedWorkbookColumns.length ||
    confirmedNeedWorkbookColumns.some(
      (column, index) => cellText(header[index] ?? null) !== column,
    )
  )
    addError(
      errors,
      1,
      "Tiêu đề cột",
      "Cấu trúc cột Excel đã thay đổi. Hãy xuất file mới từ Atlas.",
    );

  const metadata = new Map<string, string>();
  for (const [index, row] of meta.data.entries()) {
    const key = cellText(row[0] ?? null);
    const value = cellText(row[1] ?? null);
    if (!key || value === null || row.length !== 2) {
      addError(
        errors,
        index + 1,
        "Metadata",
        "Metadata của file không hợp lệ.",
      );
      continue;
    }
    if (metadata.has(key))
      addError(errors, index + 1, "Metadata", `Metadata “${key}” bị trùng.`);
    metadata.set(key, value);
  }
  if (
    metadata.size !== confirmedNeedMetaKeys.length ||
    confirmedNeedMetaKeys.some((key) => !metadata.has(key)) ||
    [...metadata.keys()].some(
      (key) =>
        !confirmedNeedMetaKeys.includes(
          key as (typeof confirmedNeedMetaKeys)[number],
        ),
    )
  )
    addError(
      errors,
      null,
      "Metadata",
      "Metadata của file không đúng hợp đồng Atlas.",
    );
  if (
    metadata.get("workbook_contract_version") !==
    CONFIRMED_NEED_WORKBOOK_CONTRACT
  )
    addError(
      errors,
      null,
      "Phiên bản file",
      "Phiên bản file Excel không được hỗ trợ. Hãy xuất file mới.",
    );
  if (
    metadata.get("confirmed_need_batch_id") !==
      authority.confirmed_need_batch_id ||
    metadata.get("batch_version") !== String(authority.batch_version)
  )
    addError(
      errors,
      null,
      "Phiên bản lô",
      "File Excel được xuất từ phiên bản dữ liệu cũ. Hãy tải lại và xuất file mới.",
    );
  if (errors.length) return structuralReview(errors);

  const rows = operator.data.slice(1);
  const authorityById = new Map(
    authority.lines.map((line) => [line.confirmed_need_line_id, line]),
  );
  const seen = new Set<string>();
  const candidate: Record<string, ConfirmedNeedDraftLine> = {};
  const changedLines: ConfirmedNeedImportChangedLine[] = [];
  let unchangedRows = 0;

  rows.forEach((row, rowIndex) => {
    const rowNumber = rowIndex + 2;
    if (row.length !== confirmedNeedWorkbookColumns.length) {
      addError(
        errors,
        rowNumber,
        "Cấu trúc dòng",
        "Dòng Excel không có đủ cột bắt buộc.",
      );
      return;
    }
    const lineId = cellText(row[11] ?? null);
    if (!lineId) {
      addError(
        errors,
        rowNumber,
        "Định danh dòng",
        "Dòng bị thiếu định danh Atlas. Không được xóa hoặc chèn dòng.",
      );
      return;
    }
    if (seen.has(lineId)) {
      addError(
        errors,
        rowNumber,
        "Định danh dòng",
        "Dòng nhu cầu bị trùng trong file Excel.",
      );
      return;
    }
    seen.add(lineId);
    const line = authorityById.get(lineId);
    if (!line) {
      addError(
        errors,
        rowNumber,
        "Định danh dòng",
        "File có dòng không thuộc lô nhu cầu hiện tại.",
      );
      return;
    }
    const revisionId = cellText(row[12] ?? null);
    const decisionId = cellText(row[13] ?? null) || null;
    if (revisionId !== line.current_revision_id)
      addError(
        errors,
        rowNumber,
        "Phiên bản dòng",
        "Dòng đã có phiên bản số lượng mới trong Atlas.",
      );
    if (decisionId !== line.current_decision_id)
      addError(
        errors,
        rowNumber,
        "Quyết định hiện hành",
        "Dòng đã có quyết định mới trong Atlas.",
      );

    expectedReferences(line).forEach((expected, index) => {
      if (cellText(row[index] ?? null) !== expected)
        addError(
          errors,
          rowNumber,
          confirmedNeedVisibleColumns[index]!,
          `${confirmedNeedVisibleColumns[index]} đã bị thay đổi. Hãy dùng giá trị do Atlas xuất.`,
        );
    });
    [line.theoretical_quantity, line.proposed_confirmed_quantity].forEach(
      (expected, index) => {
        const value = cellText(row[index + 5] ?? null);
        if (!value || !exactDecimalEqual(value.replace(",", "."), expected))
          addError(
            errors,
            rowNumber,
            confirmedNeedVisibleColumns[index + 5]!,
            `${confirmedNeedVisibleColumns[index + 5]} đã bị thay đổi. Hãy dùng giá trị do Atlas xuất.`,
          );
      },
    );

    const quantitySource = cellText(row[7] ?? null);
    const quantity =
      quantitySource === null
        ? null
        : normalizeConfirmedNeedQuantity(quantitySource);
    if (!quantity) {
      addError(
        errors,
        rowNumber,
        "SL xác nhận",
        "SL xác nhận phải là số không âm, tối đa 14 chữ số nguyên và 6 chữ số thập phân; nhập 0 nếu xác nhận bằng không.",
      );
      return;
    }

    const before = draftForLine(line, drafts);
    const reasonText = cellText(row[9] ?? null)?.trim() ?? "";
    let reasonCode = confirmedNeedReasonCodeFromLabel(reasonText);
    if (!reasonCode && !reasonText && !line.current_decision_id)
      reasonCode = exactDecimalEqual(quantity, line.proposed_confirmed_quantity)
        ? "PROPOSAL_ACCEPTED"
        : "PLANNING_STEP_ADJUSTMENT";
    if (!reasonCode) {
      addError(
        errors,
        rowNumber,
        "Lý do",
        "Lý do không thuộc danh sách tiếng Việt do Atlas cung cấp.",
      );
      return;
    }
    const unchangedProposal = exactDecimalEqual(
      quantity,
      line.proposed_confirmed_quantity,
    );
    if (
      (unchangedProposal && reasonCode !== "PROPOSAL_ACCEPTED") ||
      (!unchangedProposal && reasonCode === "PROPOSAL_ACCEPTED")
    ) {
      addError(
        errors,
        rowNumber,
        "Lý do",
        "Lý do đã chọn mâu thuẫn với SL xác nhận và SL đề xuất.",
      );
      return;
    }
    const noteValue = row[10] ?? null;
    const note = cellText(noteValue);
    if (note === null && noteValue !== null) {
      addError(errors, rowNumber, "Ghi chú", "Ghi chú phải là văn bản.");
      return;
    }
    const after: ConfirmedNeedDraftLine = {
      selected: before.selected,
      exact_quantity: quantity,
      reason_code: reasonCode,
      reason_note: note?.trim() ?? "",
    };
    const changed = editableChanged(before, after);
    const noteRequired = noteRequiredFor(line, reasonCode, changed);
    if (noteRequired && !after.reason_note) {
      addError(
        errors,
        rowNumber,
        "Ghi chú",
        line.current_decision_id && changed
          ? "Thay thế quyết định hiện tại cần ghi chú hiệu chỉnh."
          : "Lý do này cần ghi chú.",
      );
      return;
    }
    if (unchangedProposal && !line.current_decision_id && after.reason_note) {
      addError(
        errors,
        rowNumber,
        "Ghi chú",
        "Lần chấp nhận đề xuất đầu tiên không có ghi chú.",
      );
      return;
    }
    candidate[lineId] = { ...after, selected: changed || before.selected };
    if (changed)
      changedLines.push({
        line,
        rowNumber,
        before,
        after: { ...after, selected: true },
        differenceFromProposal:
          subtractExactDecimals(quantity, line.proposed_confirmed_quantity) ??
          "0",
        noteRequired,
      });
    else unchangedRows += 1;
  });

  for (const line of authority.lines) {
    if (!seen.has(line.confirmed_need_line_id))
      addError(
        errors,
        null,
        "Thiếu dòng",
        `File thiếu dòng ${line.ingredient.name} ngày ${viDate(line.service_date)}. Xóa dòng không có nghĩa là xác nhận số lượng 0.`,
      );
  }

  const errorRowKeys = new Set(
    errors.map((error, index) => error.rowNumber ?? `structure:${index}`),
  );
  const canApply = errors.length === 0 && seen.size === authority.lines.length;
  return {
    totalRows: rows.length,
    changedRows: changedLines.length,
    unchangedRows,
    errorRows: errorRowKeys.size,
    errors,
    changedLines,
    candidate: canApply ? candidate : null,
    canApply,
  };
}

export function applyConfirmedNeedWorkbookReview(
  review: ConfirmedNeedImportReview,
  current: Record<string, ConfirmedNeedDraftLine>,
) {
  if (!review.canApply || !review.candidate) return current;
  const next = { ...current };
  for (const changed of review.changedLines)
    next[changed.line.confirmed_need_line_id] = {
      ...review.candidate[changed.line.confirmed_need_line_id]!,
      selected: true,
    };
  return next;
}

export function confirmedNeedReasonOptions() {
  return Object.entries(confirmedNeedReasonLabels) as [
    ConfirmedNeedReasonCode,
    string,
  ][];
}
