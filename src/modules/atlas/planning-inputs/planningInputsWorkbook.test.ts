import readXlsxFile from "read-excel-file/browser";
import { describe, expect, it, vi } from "vitest";
import type { PlanningSchool } from "./planningInputsModel";
import {
  browserChecksum,
  parseAttendancePaste,
  parseAttendanceWorkbook,
  parseMenuWorkbook,
} from "./planningInputsWorkbook";

vi.mock("read-excel-file/browser", () => ({ default: vi.fn() }));

const schools: PlanningSchool[] = [
  {
    school_id: "school-1",
    school_code: "TH001",
    school_name: "Trường Nguyễn Du",
    school_status: "ACTIVE",
    display_order: 1,
    school_type_id: null,
    default_student_portions: 100,
    default_teacher_portions: 10,
  },
];

describe("Planning workbook canonicalization", () => {
  it("preserves explicit zero attendance and unresolved schools for backend blockers", () => {
    const rows = parseAttendancePaste(
      [
        "TH001\t03/08/2026\t0\t0",
        "Trường không tồn tại\t2026-08-04\t12\t2",
      ].join("\n"),
      schools,
    );
    expect(rows[0]).toMatchObject({
      school_id: "school-1",
      service_date: "2026-08-03",
      student_portions: 0,
      teacher_portions: 0,
    });
    expect(rows[1].school_id).toMatch(/^unresolved:school:/);
  });

  it("produces an order-independent browser SHA-256 review checksum", async () => {
    const fields = ["school_id", "service_date", "student_portions"];
    const left = [
      {
        school_id: "school-2",
        service_date: "2026-08-04",
        student_portions: 20,
      },
      {
        school_id: "school-1",
        service_date: "2026-08-03",
        student_portions: 10,
      },
    ];
    await expect(browserChecksum(left, fields)).resolves.toBe(
      await browserChecksum([...left].reverse(), fields),
    );
  });

  it("finds row-three Menu headers and maps Vietnamese labels to stable slot codes", async () => {
    vi.mocked(readXlsxFile).mockResolvedValueOnce([
      {
        sheet: "Hướng dẫn",
        data: [["Không phải dữ liệu thực đơn"]],
      },
      {
        sheet: "Tuần 03-08-2026",
        data: [
          ["Thực đơn tuần"],
          [],
          [
            "Ngày",
            "Thứ",
            "Tên trường",
            "Món Canh",
            "Món Mặn",
            "Món Xào",
            "Tráng miệng",
            "Buổi xế",
          ],
          ["03/08/2026", "Thứ hai", "TH001", "Canh bí", "", "", "", ""],
        ],
      },
    ]);
    const review = await parseMenuWorkbook(
      new File(["fixture"], "menu.xlsx"),
      schools,
      [
        {
          dish_id: "dish-1",
          dish_code: "CANH-BI",
          dish_name: "Canh bí",
          dish_status: "ACTIVE",
          display_order: 1,
          requires_need_generation: true,
        },
      ],
    );
    expect(review.errors).toEqual([]);
    expect(review.fileName).toBe("menu.xlsx / Tuần 03-08-2026");
    expect(review.rows).toEqual([
      expect.objectContaining({
        school_id: "school-1",
        service_date: "2026-08-03",
        menu_slot_code: "soup",
        dish_id: "dish-1",
        source_row_reference: "menu.xlsx:Tuần 03-08-2026:row:4:Món canh",
      }),
    ]);
  });

  it("accepts documented Attendance header aliases without inferring blanks as zero", async () => {
    vi.mocked(readXlsxFile).mockResolvedValueOnce([
      {
        sheet: "Sĩ số",
        data: [
          ["Tên trường", "Ngày", "Sĩ số học sinh", "Sĩ số giáo viên"],
          ["TH001", "2026-08-03", "", "0"],
        ],
      },
    ]);
    const review = await parseAttendanceWorkbook(
      new File(["fixture"], "attendance.xlsx"),
      schools,
    );
    expect(review.errors).toEqual([]);
    expect(Number.isNaN(review.rows[0].student_portions)).toBe(true);
    expect(review.rows[0].teacher_portions).toBe(0);
  });
});
