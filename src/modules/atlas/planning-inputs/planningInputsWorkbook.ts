import readXlsxFile, { type CellValue } from "read-excel-file/browser";
import type {
  AttendanceLine,
  MenuLine,
  PlanningDish,
  PlanningSchool,
} from "./planningInputsModel";

type WorkbookCell = CellValue | null;

const MENU_COLUMNS = [
  ["Món canh", "soup"],
  ["Món mặn", "savory"],
  ["Món xào", "stir_fry"],
  ["Tráng miệng", "dessert"],
  ["Buổi xế", "afternoon_snack"],
] as const;

const ATTENDANCE_COLUMNS = {
  student: ["Số suất học sinh", "Sĩ số học sinh"],
  teacher: ["Số suất giáo viên", "Sĩ số giáo viên"],
} as const;

const normalized = (value: unknown) =>
  String(value ?? "")
    .normalize("NFC")
    .trim()
    .toLocaleLowerCase("vi");

function headerIndex(row: WorkbookCell[]) {
  return new Map(row.map((value, index) => [normalized(value), index]));
}

function cell(row: WorkbookCell[], headers: Map<string, number>, name: string) {
  const index = headers.get(normalized(name));
  return index === undefined ? "" : String(row[index] ?? "").trim();
}

function cellAlias(
  row: WorkbookCell[],
  headers: Map<string, number>,
  names: readonly string[],
) {
  for (const name of names) {
    if (headers.has(normalized(name))) return cell(row, headers, name);
  }
  return "";
}

function hasAlias(headers: Map<string, number>, names: readonly string[]) {
  return names.some((name) => headers.has(normalized(name)));
}

function headerRowIndex(sheet: WorkbookCell[][]) {
  return sheet.findIndex((row) => {
    const headers = headerIndex(row);
    return (
      headers.has(normalized("Tên trường")) && headers.has(normalized("Ngày"))
    );
  });
}

function sourceSheet<T extends { data?: WorkbookCell[][] }>(sheets: T[]) {
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

function isoDate(value: WorkbookCell | undefined): string {
  if (value instanceof Date) return value.toISOString().slice(0, 10);
  const text = String(value ?? "").trim();
  const iso = /^(\d{4})-(\d{2})-(\d{2})$/.exec(text);
  if (iso) return text;
  const vi = /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/.exec(text);
  if (!vi) return text;
  return `${vi[3]}-${vi[2].padStart(2, "0")}-${vi[1].padStart(2, "0")}`;
}

function unresolved(kind: string, value: string) {
  return `unresolved:${kind}:${normalized(value) || "blank"}`;
}

function explicitNumber(value: string) {
  return value.trim() === "" ? Number.NaN : Number(value);
}

export type MenuWorkbookReview = {
  fileName: string;
  rows: MenuLine[];
  browserChecksum: string;
  errors: string[];
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

export async function parseMenuWorkbook(
  file: File,
  schools: PlanningSchool[],
  dishes: PlanningDish[],
): Promise<MenuWorkbookReview> {
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
  for (const required of [
    "Tên trường",
    "Ngày",
    ...MENU_COLUMNS.map(([h]) => h),
  ]) {
    if (!headers.has(normalized(required)))
      errors.push(`Thiếu cột bắt buộc: ${required}.`);
  }
  const rows: MenuLine[] = [];
  for (const [offset, source] of sheet
    .slice(Math.max(headerOffset + 1, 0))
    .entries()) {
    if (source.every((value) => normalized(value) === "")) continue;
    const schoolText = cell(source, headers, "Tên trường");
    const dateIndex = headers.get(normalized("Ngày"));
    const serviceDate = isoDate(
      dateIndex === undefined ? undefined : source[dateIndex],
    );
    const school = reference(
      schoolText,
      schools,
      (item) => item.school_code,
      (item) => item.school_name,
    );
    for (const [header, slot] of MENU_COLUMNS) {
      const dishText = cell(source, headers, header);
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
        menu_slot_code: slot,
        dish_id: dish?.dish_id ?? unresolved("dish", dishText),
        source_row_reference: `${file.name}:${selectedSheet?.sheet ?? "sheet-1"}:row:${Math.max(headerOffset, -1) + offset + 2}:${header}`,
      });
    }
  }
  return {
    fileName: `${file.name} / ${selectedSheet?.sheet ?? "sheet-1"}`.normalize(
      "NFC",
    ),
    rows,
    browserChecksum: await browserChecksum(
      rows as unknown as Record<string, unknown>[],
      ["school_id", "service_date", "menu_slot_code", "dish_id"],
    ),
    errors,
  };
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
  for (const required of ["Tên trường", "Ngày"]) {
    if (!headers.has(normalized(required)))
      errors.push(`Thiếu cột bắt buộc: ${required}.`);
  }
  if (!hasAlias(headers, ATTENDANCE_COLUMNS.student))
    errors.push("Thiếu cột bắt buộc: Số suất học sinh.");
  if (!hasAlias(headers, ATTENDANCE_COLUMNS.teacher))
    errors.push("Thiếu cột bắt buộc: Số suất giáo viên.");
  const rows: AttendanceLine[] = [];
  for (const [offset, source] of sheet
    .slice(Math.max(headerOffset + 1, 0))
    .entries()) {
    if (source.every((value) => normalized(value) === "")) continue;
    const schoolText = cell(source, headers, "Tên trường");
    const school = reference(
      schoolText,
      schools,
      (item) => item.school_code,
      (item) => item.school_name,
    );
    const dateIndex = headers.get(normalized("Ngày"));
    rows.push({
      school_id: school?.school_id ?? unresolved("school", schoolText),
      service_date: isoDate(
        dateIndex === undefined ? undefined : source[dateIndex],
      ),
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
