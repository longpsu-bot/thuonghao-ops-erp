import type { ConfirmedNeedLine } from "./confirmedNeedModel";

// Owner-selected A+: A's density, 6 pt moved from Note to Unit.
export const shoppingListContract = {
  contractName: "ATLAS_SHOPPING_LIST",
  contractVersion: "ATLAS_SHOPPING_LIST_V2",
  geometryVariant: "A+",
  visibleHeaders: ["TRƯỜNG", "THÀNH PHẦN", "ĐVT", "SỐ LƯỢNG", "GHI CHÚ"],
  hiddenHeaders: [
    "__workbook_marker",
    "__line_id",
    "__revision_id",
    "__decision_id",
    "__service_date",
    "__school_id",
    "__location_id",
    "__ingredient_id",
    "__unit_id",
    "__exported_quantity",
    "__row_kind",
    "__school_name",
  ],
  metadataKeys: [
    "contract_name",
    "contract_version",
    "workbook_marker",
    "exported_at",
    "service_period_start",
    "service_period_end",
    "geometry_variant",
  ],
  dailyKeys: [
    "service_date",
    "confirmed_need_batch_id",
    "batch_version",
    "need_generation_run_id",
    "release_snapshot_id",
  ],
  metadataSheet: "_ATLAS_META",
  metadataState: "veryHidden",
  headerRow: 3,
  firstDataRow: 4,
  lastColumn: "Q",
  editableColumns: ["D", "E"],
  paper: "A4",
  orientation: "portrait",
  printAreaColumns: "A:E",
  printTitleRows: "1:3",
  font: "Times New Roman",
  bodyHeightClasses: ["NORMAL", "WRAPPED"],
  maxServiceDates: 7,
  partialImport: false,
  importWrites: false,
  legacyAccepted: false,
  protectedSort: false,
  protectionPassword: "ATLAS_SHOPPING_LIST_V2",
  print: {
    titleFontPt: 20,
    headerFontPt: 17,
    bodyFontPt: 18,
    schoolFontPt: 18,
    supplierFontPt: 14,
    quantityFontPt: 16,
    titleRowPt: 32,
    spacerRowPt: 5,
    headerRowPt: 48,
    normalRowPt: 28,
    bodyHardCapPt: 44,
    columnWidths: [14, 31, 10, 16, 23],
    a4WidthPt: 595.28,
    a4HeightPt: 841.89,
    topMarginIn: 0.25,
    bottomMarginIn: 0.25,
    footerAllowancePt: 12,
    wrappedRowPt: 44,
    bandRowPt: 28,
    leftMarginIn: 0.2,
    rightMarginIn: 0.2,
    scalePercent: 96,
  },
  resourceLimits: {
    compressedBytes: 10485760,
    zipEntries: 128,
    totalUncompressedBytes: 52428800,
    xmlPartBytes: 20971520,
    dataLines: 10000,
    dateSheets: 7,
    maximumLargeEntryRatio: 200,
    largeEntryThresholdBytes: 1048576,
  },
} as const;

export class ShoppingListError extends Error {
  constructor(
    public readonly code: string,
    message = "Phiếu đi chợ không còn khớp hoặc sai cấu trúc. Hãy xuất một file mới.",
  ) {
    super(message);
    this.name = "ShoppingListError";
  }
}
export function shoppingAssert(
  condition: unknown,
  code = "WORKBOOK_INVALID",
): asserts condition {
  if (!condition) throw new ShoppingListError(code);
}
export const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
export function shoppingListUnitDisplay(
  unit: Pick<ConfirmedNeedLine["controlled_unit"], "code" | "name">,
): string {
  const label = [unit.code.trim(), unit.name.trim()].find(
    (value) =>
      value &&
      value !== "?" &&
      !/^(?:v1-unit-|atlas[-_:]|unit[-_:])/i.test(value) &&
      !uuidPattern.test(value.toLowerCase()) &&
      !/\p{Control}/u.test(value),
  );
  shoppingAssert(label, "INVALID_UNIT_DISPLAY");
  return label;
}
export function validServiceDate(date: string) {
  return (
    /^\d{4}-\d{2}-\d{2}$/.test(date) &&
    !Number.isNaN(Date.parse(date)) &&
    new Date(date).toISOString().slice(0, 10) === date
  );
}
