import readXlsxFile from "read-excel-file/browser";
import { describe, expect, it, vi } from "vitest";
import type {
  PlanningSchool,
  PlanningDish,
  PlanningDishType,
} from "./planningInputsModel";
import {
  parseMenuMatrix,
  parseMenuWorkbook,
  parseAttendanceWorkbook,
  parseAttendancePaste,
} from "./planningInputsWorkbook";
vi.mock("read-excel-file/browser", () => ({ default: vi.fn() }));
const a: PlanningSchool = {
  school_id: "school-a",
  school_code: "school-a",
  school_name: "Trường A",
  school_status: "ACTIVE",
  display_order: 1,
  school_type_id: null,
  default_student_portions: 0,
  default_teacher_portions: 0,
};
const b: PlanningSchool = {
  ...a,
  school_id: "school-b",
  school_code: "school-b",
  school_name: "Trường B",
  display_order: 2,
};
const type: PlanningDishType = {
  dish_type_id: "soup",
  dish_type_code: "soup",
  dish_type_name: "Món canh",
  source_header_aliases: ["Canh", "Món Canh"],
  dish_type_status: "ACTIVE",
  display_order: 1,
  version: 1,
};
const dish: PlanningDish = {
  dish_id: "dish-1",
  dish_code: "dish-1",
  dish_name: "Canh",
  dish_type_id: "soup",
  dish_type_code: "soup",
  dish_type_name: "Món canh",
  dish_status: "ACTIVE",
  display_order: 1,
  requires_need_generation: true,
};
const source = {
  sourceName: "Google",
  sheetName: "Tuần 21-09-2026",
  firstRowNumber: 3,
};
const paths = [
  "menu-matrix",
  "menu-workbook",
  "attendance-workbook",
  "attendance-paste",
] as const;
async function parseSchool(
  path: (typeof paths)[number],
  value: string,
  schools: PlanningSchool[],
  header = "Tên trường",
) {
  const menu = [
    [header, "Ngày", "soup"],
    [value, "2026-09-21", "dish-1"],
  ];
  if (path === "menu-matrix")
    return (await parseMenuMatrix(menu, source, [type], schools, [dish])).rows;
  if (path === "attendance-paste")
    return parseAttendancePaste(`${value}\t2026-09-21\t0\t0`, schools);
  const data =
    path === "menu-workbook"
      ? menu
      : [
          [header, "Ngày", "Sĩ số học sinh", "Sĩ số giáo viên"],
          [value, "2026-09-21", "0", "0"],
        ];
  vi.mocked(readXlsxFile).mockResolvedValueOnce([{ sheet: "Tuần", data }]);
  const file = new File(["mock"], "input.xlsx");
  return path === "menu-workbook"
    ? (await parseMenuWorkbook(file, [type], schools, [dish])).rows
    : (await parseAttendanceWorkbook(file, schools)).rows;
}
describe.each(paths)("AUD-001 — %s", (path) => {
  it("never chooses among duplicate normalized School names in either reference order", async () => {
    const schools = [
      { ...a, school_name: " Trường trùng " },
      { ...b, school_name: "TRƯỜNG TRÙNG" },
    ];
    const left = await parseSchool(path, "Trường trùng", schools);
    const right = await parseSchool(
      path,
      "Trường trùng",
      [...schools].reverse(),
    );
    expect(left[0].school_id).toMatch(/^unresolved:school:/);
    expect(right[0].school_id).toBe(left[0].school_id);
  });
  it("prefers exactly one code over another School's name independent of order", async () => {
    const schools = [{ ...a, school_name: "school-b" }, b];
    for (const refs of [schools, [...schools].reverse()])
      expect((await parseSchool(path, "school-b", refs))[0].school_id).toBe(
        "school-b",
      );
  });
  it("leaves duplicate codes unresolved even with a unique label fallback", async () => {
    const schools = [
      { ...a, school_code: "duplicate", school_name: "duplicate" },
      { ...b, school_code: "DUPLICATE" },
    ];
    expect(
      (await parseSchool(path, "duplicate", schools))[0].school_id,
    ).toMatch(/^unresolved:school:/);
  });
  it("resolves unique Unicode names and exact codes with existing normalization", async () => {
    expect(
      (await parseSchool(path, " TRƯỜNG A ".normalize("NFD"), [a, b]))[0]
        .school_id,
    ).toBe(a.school_id);
    expect((await parseSchool(path, " SCHOOL-B ", [a, b]))[0].school_id).toBe(
      b.school_id,
    );
  });
  it("never matches a blank source against a blank reference field", async () => {
    expect(
      (await parseSchool(path, "", [{ ...a, school_name: "" }]))[0].school_id,
    ).toMatch(/^unresolved:school:/);
  });
});
describe.each(paths.filter((path) => path !== "attendance-paste"))(
  "explicit School code column — %s",
  (path) => {
    it.each(["school_code", "Mã trường"])(
      "does not interpret a label as a code under %s",
      async (header) => {
        expect(
          (await parseSchool(path, a.school_name, [a, b], header))[0].school_id,
        ).toMatch(/^unresolved:school:/);
        expect(
          (await parseSchool(path, b.school_code, [a, b], header))[0].school_id,
        ).toBe(b.school_id);
      },
    );
  },
);
describe("AUD-002 — preserve column positions until validation", () => {
  it.each([
    ["soup", "soup"],
    ["soup", " SOUP "],
    ["Món canh", "Món canh".normalize("NFD")],
    ["soup", "Canh"],
  ])(
    "blocks exact/normalized/alias duplicate Dish Type headings %j",
    async (first, second) => {
      const result = await parseMenuMatrix(
        [
          ["school_code", "Ngày", first, second],
          ["school-a", "2026-09-21", "dish-1", "dish-2"],
        ],
        source,
        [type],
        [a, b],
        [dish, { ...dish, dish_id: "dish-2", dish_code: "dish-2" }],
      );
      expect(result.errors.length).toBeGreaterThan(0);
      expect(result.rows).toEqual([]);
      expect(result.sourceRowCount).toBe(1);
    },
  );
  it("blocks one source column claimed by two active Dish Types", async () => {
    const other = {
      ...type,
      dish_type_id: "savory",
      dish_type_code: "savory",
      dish_type_name: "Món mặn",
      source_header_aliases: ["soup"],
    };
    const result = await parseMenuMatrix(
      [
        ["school_code", "Ngày", "soup"],
        ["school-a", "2026-09-21", "dish-1"],
      ],
      source,
      [type, other],
      [a, b],
      [dish],
    );
    expect(result.errors.length).toBeGreaterThan(0);
    expect(result.rows).toEqual([]);
  });
  it.each([
    ["school_code", " SCHOOL_CODE "],
    ["Tên trường", "Mã trường"],
    ["Ngày", "service_date"],
  ])(
    "blocks duplicate recognized identity/date columns %j",
    async (first, second) => {
      const school = first !== "Ngày";
      const headers = school
        ? [first, second, "Ngày", "soup"]
        : ["school_code", first, second, "soup"];
      const row = school
        ? ["school-a", "school-b", "2026-09-21", "dish-1"]
        : ["school-a", "2026-09-21", "2026-09-22", "dish-1"];
      const result = await parseMenuMatrix(
        [headers, row],
        source,
        [type],
        [a, b],
        [dish],
      );
      expect(result.errors.length).toBeGreaterThan(0);
      expect(result.rows).toEqual([]);
    },
  );
  it("does not reject blank/repeated presentation headings or repeated aliases on one type", async () => {
    const result = await parseMenuMatrix(
      [
        ["Tên trường", "Ngày", "Món canh", "", "", "Thứ", "Thứ"],
        [a.school_name, "2026-09-21", "dish-1", "", "", "Hai", "Hai"],
      ],
      source,
      [type],
      [a, b],
      [dish],
    );
    expect(result.errors).toEqual([]);
    expect(result.rows).toHaveLength(1);
    expect(result.rows[0].source_row_reference).toContain("row:4:soup");
  });
  it("Attendance workbook also blocks duplicate recognized quantity aliases", async () => {
    vi.mocked(readXlsxFile).mockResolvedValueOnce([
      {
        sheet: "Sĩ số",
        data: [
          [
            "Tên trường",
            "Ngày",
            "Sĩ số học sinh",
            "Số suất học sinh",
            "Sĩ số giáo viên",
          ],
          [a.school_name, "2026-09-21", 0, 1, 0],
        ],
      },
    ]);
    const result = await parseAttendanceWorkbook(
      new File(["mock"], "attendance.xlsx"),
      [a],
    );
    expect(result.errors.length).toBeGreaterThan(0);
    expect(result.rows).toEqual([]);
  });
});
