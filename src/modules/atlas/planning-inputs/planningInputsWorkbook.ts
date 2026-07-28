import readXlsxFile, { type CellValue } from "read-excel-file/browser";
import type {
  AttendanceLine,
  MenuLine,
  PlanningDish,
  PlanningDishType,
  PlanningSchool,
} from "./planningInputsModel";

export type MatrixCell = CellValue | string | number | boolean | null;
export type SourceMatrix = MatrixCell[][];

const SCHOOL_COLUMNS = ["Tên trường", "Mã trường", "school_code"] as const;
const DATE_COLUMNS = ["Ngày", "service_date"] as const;
const ATTENDANCE_COLUMNS = {
  student: ["Số suất học sinh", "Sĩ số học sinh"],
  teacher: ["Số suất giáo viên", "Sĩ số giáo viên"],
} as const;

const normalized = (value: unknown) =>
  String(value ?? "")
    .normalize("NFC")
    .trim()
    .toLocaleLowerCase("vi");

function headerIndex(row: MatrixCell[]) {
  return new Map(
    row.flatMap((value, index) => {
      const key = normalized(value);
      return key ? [[key, index] as const] : [];
    }),
  );
}

function aliasIndex(headers: Map<string, number>, names: readonly string[]) {
  for (const name of names) {
    const index = headers.get(normalized(name));
    if (index !== undefined) return index;
  }
  return undefined;
}

function cellAt(row: MatrixCell[], index: number | undefined) {
  return index === undefined
    ? ""
    : String(row[index] ?? "")
        .normalize("NFC")
        .trim();
}

function cellAlias(
  row: MatrixCell[],
  headers: Map<string, number>,
  names: readonly string[],
) {
  return cellAt(row, aliasIndex(headers, names));
}

function hasAlias(headers: Map<string, number>, names: readonly string[]) {
  return aliasIndex(headers, names) !== undefined;
}

function headerRowIndex(sheet: SourceMatrix) {
  return sheet.findIndex((row) => {
    const headers = headerIndex(row);
    return hasAlias(headers, SCHOOL_COLUMNS) && hasAlias(headers, DATE_COLUMNS);
  });
}

function sourceSheet<T extends { data?: SourceMatrix }>(sheets: T[]) {
  return (
    sheets.find((candidate) => headerRowIndex(candidate.data ?? []) >= 0) ??
    sheets[0]
  );
}

function reference<T>(
  value: string,
  values: T[],
  code: (item: T) => string,
  label: (item: T) => string,
) {
  const key = normalized(value);
  return values.find(
    (item) => normalized(code(item)) === key || normalized(label(item)) === key,
  );
}

function isoDate(value: MatrixCell | undefined): string {
  if (value instanceof Date) return value.toISOString().slice(0, 10);
  const text = String(value ?? "").trim();
  const iso = /^(\d{4})-(\d{2})-(\d{2})$/.exec(text);
  if (iso) return text;
  const vi = /^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$/.exec(text);
  if (!vi) return text;
  return `${vi[3]}-${vi[2].padStart(2, "0")}-${vi[1].padStart(2, "0")}`;
}

function unresolved(kind: string, value: string) {
  return `unresolved:${kind}:${normalized(value) || "blank"}`;
}

function explicitNumber(value: string) {
  return value.trim() === "" ? Number.NaN : Number(value);
}

export type MenuMatrixSource = {
  sourceName: string;
  sheetName: string;
  firstRowNumber?: number;
};

export type MenuMatrixReview = {
  sourceName: string;
  rows: MenuLine[];
  browserChecksum: string;
  errors: string[];
  warnings: string[];
  sourceRowCount: number;
  headerRowNumber: number | null;
};

export type MenuWorkbookReview = MenuMatrixReview & {
  fileName: string;
};

export type AttendanceWorkbookReview = {
  fileName: string;
  rows: AttendanceLine[];
  browserChecksum: string;
  errors: string[];
};

export async function browserChecksum(
  rows: Record<string, unknown>[],
  fields: string[],
) {
  const normalizedRows = rows
    .map((row) =>
      Object.fromEntries(
        fields.map((field) => [
          field,
          typeof row[field] === "string"
            ? row[field].normalize("NFC").trim()
            : row[field],
        ]),
      ),
    )
    .sort((left, right) =>
      JSON.stringify(left).localeCompare(JSON.stringify(right), "vi"),
    );
  const bytes = new TextEncoder().encode(JSON.stringify(normalizedRows));
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest), (value) =>
    value.toString(16).padStart(2, "0"),
  ).join("");
}

function dishTypeHeaderIndexes(
  headers: Map<string, number>,
  dishTypes: PlanningDishType[],
  errors: string[],
  warnings: string[],
) {
  const claimed = new Map<number, string>();
  return dishTypes
    .filter((dishType) => dishType.dish_type_status === "ACTIVE")
    .flatMap((dishType) => {
      const names = [
        dishType.dish_type_name,
        dishType.dish_type_code,
        ...dishType.source_header_aliases,
      ];
      const indexes = Array.from(
        new Set(
          names.flatMap((name) => {
            const index = headers.get(normalized(name));
            return index === undefined ? [] : [index];
          }),
        ),
      );
      if (indexes.length === 0) {
        warnings.push(
          `Không có cột tùy chọn cho loại món: ${dishType.dish_type_name}.`,
        );
        return [];
      }
      if (indexes.length > 1) {
        errors.push(
          `Có nhiều cột cùng ánh xạ tới loại món: ${dishType.dish_type_name}.`,
        );
        return [];
      }
      const index = indexes[0]!;
      const otherCode = claimed.get(index);
      if (otherCode) {
        errors.push(
          `Một cột nguồn ánh xạ tới nhiều loại món: ${otherCode}, ${dishType.dish_type_code}.`,
        );
        return [];
      }
      claimed.set(index, dishType.dish_type_code);
      return [{ dishType, index }];
    });
}

/**
 * Pure source-adapter parser shared by workbook and Google Sheet matrices.
 * It resolves only supplied database references and never fabricates slot
 * identity from column position.
 */
export async function parseMenuMatrix(
  matrix: SourceMatrix,
  source: MenuMatrixSource,
  dishTypes: PlanningDishType[],
  schools: PlanningSchool[],
  dishes: PlanningDish[],
): Promise<MenuMatrixReview> {
  const sheet = matrix.map((row) =>
    row.map((value) =>
      typeof value === "string" ? value.normalize("NFC") : value,
    ),
  );
  const headerOffset = headerRowIndex(sheet);
  const headers = headerIndex(
    headerOffset < 0 ? [] : (sheet[headerOffset] ?? []),
  );
  const errors: string[] = [];
  const warnings: string[] = [];
  if (headerOffset < 0) {
    errors.push("Không tìm thấy hàng tiêu đề có Tên trường và Ngày.");
  }
  if (!hasAlias(headers, SCHOOL_COLUMNS))
    errors.push("Thiếu cột bắt buộc: Tên trường.");
  if (!hasAlias(headers, DATE_COLUMNS))
    errors.push("Thiếu cột bắt buộc: Ngày.");

  const typeColumns = dishTypeHeaderIndexes(
    headers,
    dishTypes,
    errors,
    warnings,
  );
  const rows: MenuLine[] = [];
  const dataRows = sheet.slice(Math.max(headerOffset + 1, 0));
  for (const [offset, sourceRow] of dataRows.entries()) {
    if (sourceRow.every((value) => normalized(value) === "")) continue;
    const schoolText = cellAlias(sourceRow, headers, SCHOOL_COLUMNS);
    const serviceDate = isoDate(
      sourceRow[aliasIndex(headers, DATE_COLUMNS) ?? -1],
    );
    const school = reference(
      schoolText,
      schools,
      (item) => item.school_code,
      (item) => item.school_name,
    );
    const rowNumber =
      (source.firstRowNumber ?? 1) + Math.max(headerOffset, -1) + offset + 1;
    for (const { dishType, index } of typeColumns) {
      const dishText = cellAt(sourceRow, index);
      if (!dishText) continue;
      const dish = reference(
        dishText,
        dishes,
        (item) => item.dish_code,
        (item) => item.dish_name,
      );
      rows.push({
        school_id: school?.school_id ?? unresolved("school", schoolText),
        service_date: serviceDate,
        menu_slot_code: dishType.dish_type_code,
        dish_id: dish?.dish_id ?? unresolved("dish", dishText),
        source_row_reference:
          `${source.sourceName}:${source.sheetName}:row:${rowNumber}:` +
          dishType.dish_type_code,
      });
    }
  }
  return {
    sourceName: `${source.sourceName} / ${source.sheetName}`.normalize("NFC"),
    rows,
    browserChecksum: await browserChecksum(
      rows as unknown as Record<string, unknown>[],
      ["school_id", "service_date", "menu_slot_code", "dish_id"],
    ),
    errors,
    warnings,
    sourceRowCount: dataRows.filter((row) =>
      row.some((value) => normalized(value) !== ""),
    ).length,
    headerRowNumber:
      headerOffset < 0 ? null : (source.firstRowNumber ?? 1) + headerOffset,
  };
}

export async function parseMenuWorkbook(
  file: File,
  dishTypes: PlanningDishType[],
  schools: PlanningSchool[],
  dishes: PlanningDish[],
): Promise<MenuWorkbookReview> {
  const sheets = await readXlsxFile(file);
  const selectedSheet = sourceSheet(sheets);
  const parsed = await parseMenuMatrix(
    selectedSheet?.data ?? [],
    {
      sourceName: file.name,
      sheetName: selectedSheet?.sheet ?? "sheet-1",
    },
    dishTypes,
    schools,
    dishes,
  );
  return { ...parsed, fileName: parsed.sourceName };
}

export async function parseAttendanceWorkbook(
  file: File,
  schools: PlanningSchool[],
): Promise<AttendanceWorkbookReview> {
  const sheets = await readXlsxFile(file);
  const selectedSheet = sourceSheet(sheets);
  const sheet = selectedSheet?.data ?? [];
  const headerOffset = headerRowIndex(sheet);
  const headers = headerIndex(
    headerOffset < 0 ? [] : (sheet[headerOffset] ?? []),
  );
  const errors: string[] = [];
  if (headerOffset < 0)
    errors.push("Không tìm thấy hàng tiêu đề có Tên trường và Ngày.");
  if (!hasAlias(headers, SCHOOL_COLUMNS))
    errors.push("Thiếu cột bắt buộc: Tên trường.");
  if (!hasAlias(headers, DATE_COLUMNS))
    errors.push("Thiếu cột bắt buộc: Ngày.");
  if (!hasAlias(headers, ATTENDANCE_COLUMNS.student))
    errors.push("Thiếu cột bắt buộc: Số suất học sinh.");
  if (!hasAlias(headers, ATTENDANCE_COLUMNS.teacher))
    errors.push("Thiếu cột bắt buộc: Số suất giáo viên.");
  const rows: AttendanceLine[] = [];
  for (const [offset, source] of sheet
    .slice(Math.max(headerOffset + 1, 0))
    .entries()) {
    if (source.every((value) => normalized(value) === "")) continue;
    const schoolText = cellAlias(source, headers, SCHOOL_COLUMNS);
    const school = reference(
      schoolText,
      schools,
      (item) => item.school_code,
      (item) => item.school_name,
    );
    rows.push({
      school_id: school?.school_id ?? unresolved("school", schoolText),
      service_date: isoDate(source[aliasIndex(headers, DATE_COLUMNS) ?? -1]),
      student_portions: explicitNumber(
        cellAlias(source, headers, ATTENDANCE_COLUMNS.student),
      ),
      teacher_portions: explicitNumber(
        cellAlias(source, headers, ATTENDANCE_COLUMNS.teacher),
      ),
      source_row_reference: `${file.name}:${selectedSheet?.sheet ?? "sheet-1"}:row:${Math.max(headerOffset, -1) + offset + 2}`,
    });
  }
  return {
    fileName: `${file.name} / ${selectedSheet?.sheet ?? "sheet-1"}`.normalize(
      "NFC",
    ),
    rows,
    browserChecksum: await browserChecksum(
      rows as unknown as Record<string, unknown>[],
      ["school_id", "service_date", "student_portions", "teacher_portions"],
    ),
    errors,
  };
}

export function parseAttendancePaste(
  value: string,
  schools: PlanningSchool[],
): AttendanceLine[] {
  return value
    .normalize("NFC")
    .split(/\r?\n/)
    .flatMap((line, index) => {
      if (!line.trim()) return [];
      const [schoolText = "", date = "", student = "", teacher = ""] =
        line.split("\t");
      const school = reference(
        schoolText,
        schools,
        (item) => item.school_code,
        (item) => item.school_name,
      );
      return [
        {
          school_id: school?.school_id ?? unresolved("school", schoolText),
          service_date: isoDate(date),
          student_portions: explicitNumber(student),
          teacher_portions: explicitNumber(teacher),
          source_row_reference: `paste:row:${index + 1}`,
        },
      ];
    });
}
