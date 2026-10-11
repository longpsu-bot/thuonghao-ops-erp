import { describe, expect, it } from "vitest";
import { parseMenuMatrix } from "./planningInputsWorkbook";
import type {
  PlanningSchool,
  PlanningDish,
  PlanningDishType,
} from "./planningInputsModel";
import { compareCanonicalSchools } from "../../../vnext/atlas/canonicalSchoolOrder";
import evidence from "../../../../scripts/fixtures/atlas-planning-school-order-2026-10-11.json";

describe("source-backed Planning master convergence", () => {
  it("reproduces stale School and missing Dish cells, then resolves exact corrected masters", async () => {
    const school = {
      school_id: "stable-school-33",
      school_code: "v1-school-33",
      school_name: "THUẬN AN - PHÂN HIỆU",
      school_status: "ACTIVE",
      display_order: 16,
      school_type_id: null,
      default_student_portions: 615,
      default_teacher_portions: 25,
    } as PlanningSchool;
    const type = {
      dish_type_id: "stable-type-1",
      dish_type_code: "canh",
      dish_type_name: "Canh",
      source_header_aliases: ["Canh"],
      display_order: 1,
      dish_type_status: "ACTIVE",
      version: 1,
    } as PlanningDishType;
    const dish = {
      dish_id: "deterministic-import-dish-2010",
      dish_code: "v1-dish-2010",
      dish_name: "Canh đu đủ nấu tôm khô",
      dish_type_id: type.dish_type_id,
      dish_type_code: "canh",
      dish_type_name: "Canh",
      dish_status: "ACTIVE",
      display_order: 1,
      requires_need_generation: true,
    } as PlanningDish;
    const matrix = [
      ["Tên trường", "Ngày", "Canh"],
      [school.school_name, "12/10/2026", dish.dish_name],
      [school.school_name, "13/10/2026", dish.dish_name],
    ];
    const source = {
      sourceName: "ops.weekly-menu",
      sheetName: "Tuần 12-10-2026",
      firstRowNumber: 3,
    };
    const before = await parseMenuMatrix(
      matrix,
      source,
      [type],
      [{ ...school, school_name: "TRẦN ĐẠI NGHĨA" }],
      [],
    );
    expect(
      before.diagnostics.filter((i) => i.code === "UNKNOWN_SCHOOL"),
    ).toHaveLength(2);
    expect(
      before.diagnostics.filter((i) => i.code === "UNKNOWN_DISH"),
    ).toHaveLength(2);
    const after = await parseMenuMatrix(
      matrix,
      source,
      [type],
      [school],
      [dish],
    );
    expect(after.errors).toEqual([]);
    expect(after.diagnostics).toEqual([]);
    expect(after.rows.map((r) => r.school_id)).toEqual([
      school.school_id,
      school.school_id,
    ]);
    expect(after.rows.map((r) => r.dish_id)).toEqual([
      dish.dish_id,
      dish.dish_id,
    ]);
  });
  it("retains the complete observed V1 sequence, NULL tail and Owner blocks", () => {
    const rows = [...evidence.schools]
      .reverse()
      .map((s) => ({ ...s, school_id: s.legacy_id }))
      .sort(compareCanonicalSchools);
    expect(rows.map((s) => s.legacy_id)).toEqual([
      "24",
      "39",
      "37",
      "40",
      "38",
      "8",
      "22",
      "31",
      "30",
      "29",
      "12",
      "34",
      "32",
      "52",
      "10",
      "33",
      "15",
      "7",
      "47",
      "48",
      "49",
      "50",
      "53",
      "41",
      "43",
      "42",
      "9",
      "13",
      "17",
      "14",
      "5",
      "23",
      "16",
      "25",
      "19",
      "46",
      "27",
      "28",
      "26",
      "18",
      "6",
      "36",
      "4",
      "35",
      "44",
      "45",
      "11",
      "20",
      "21",
    ]);
    expect(rows.slice(-3).map((s) => s.display_order)).toEqual([49, 50, 51]);
    expect(
      rows
        .filter((s) => ["47", "48", "49", "50", "53"].includes(s.legacy_id))
        .map((s) => s.display_order),
    ).toEqual([19, 20, 21, 22, 23]);
  });
});
