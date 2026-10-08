import ExcelJS from "exceljs";
import { describe, expect, it, vi } from "vitest";
import readXlsxFile from "read-excel-file/browser";
import { parseAttendanceWorkbook } from "../planning-inputs/planningInputsWorkbook";
import { createAttendanceImportTemplate } from "./attendanceImportTemplate";
import type { PlanningSchool } from "../planning-inputs/planningInputsModel";
vi.mock("read-excel-file/browser", () => ({ default: vi.fn() }));
const schools: PlanningSchool[] = [
  {
    school_id: "school-a",
    school_code: "TH001",
    school_name: "Trường An Bình",
    school_status: "ACTIVE",
    display_order: 1,
    school_type_id: null,
    default_student_portions: 100,
    default_teacher_portions: 10,
  },
];

describe("Attendance import document", () => {
  it("leaves every input blank and passes existing code/date/zero semantics to the unchanged parser", async () => {
    const book = new ExcelJS.Workbook();
    await book.xlsx.load(
      await createAttendanceImportTemplate("2026-09-07", schools),
    );
    const sheet = book.getWorksheet("Nhập sĩ số")!;
    expect(sheet.getRow(6).values).toEqual([
      undefined,
      "Mã trường",
      "Ngày",
      "Số suất học sinh",
      "Số suất giáo viên",
    ]);
    expect(sheet.getCell("C7").value).toBeNull();
    expect(sheet.getCell("D7").value).toBeNull();
    sheet.getRow(7).values = ["TH001", "2026-09-07", 0, 10];
    sheet.getRow(8).values = ["TH001", "2026-09-08", null, 0];
    const data = [];
    for (let r = 1; r <= sheet.rowCount; r++)
      data.push([1, 2, 3, 4].map((c) => sheet.getCell(r, c).value));
    vi.mocked(readXlsxFile).mockResolvedValue([
      { sheet: "Nhập sĩ số", data },
    ] as never);
    const result = await parseAttendanceWorkbook(
      new File(["fixture"], "attendance.xlsx"),
      schools,
    );
    expect(result.errors).toEqual([]);
    expect(result.rows).toMatchObject([
      {
        school_id: "school-a",
        service_date: "2026-09-07",
        student_portions: 0,
        teacher_portions: 10,
      },
      {
        school_id: "school-a",
        service_date: "2026-09-08",
        student_portions: NaN,
        teacher_portions: 0,
      },
    ]);
    expect(JSON.stringify(book.model)).toContain("MẪU NHẬP — CHƯA LƯU");
    expect(sheet.pageSetup.printTitlesRow).toBe("1:6");
  });
});
