import { describe, expect, it } from "vitest";
import type { SchoolMasterData } from "../bridges/schoolMasterData";
import {
  applySchoolDraftEdit,
  countHiddenDraftSchools,
  countInvalidDraftSchools,
  createSchoolDefaultsReview,
  filterAndOrderSchools,
  parsePortionDraft,
  reconcileSchoolDrafts,
  type SchoolDefaultsDrafts,
} from "./schoolDefaultsModel";

const schools: SchoolMasterData[] = [
  {
    school_id: "school-2",
    school_code: "TH002",
    school_name: "Trường Trung học Beta",
    school_status: "ACTIVE",
    version: 7,
    display_order: 2,
    default_student_portions: 840,
    default_teacher_portions: 45,
    school_type_id: "secondary",
    school_type_name: "Trung học",
    customer_id: "customer-2",
    customer_code: "KH02",
    customer_name: "Cụm trường Beta",
    delivery_location_id: "location-2",
    delivery_location_name: "Kho thực phẩm",
    delivery_address: "02 Đường Bế Văn Đàn",
    delivery_instructions: null,
    contract_context: null,
  },
  {
    school_id: "school-1",
    school_code: "TH001",
    school_name: "Trường Tiểu học Ánh Dương",
    school_status: "INACTIVE",
    version: 3,
    display_order: 1,
    default_student_portions: 420,
    default_teacher_portions: 32,
    school_type_id: "primary",
    school_type_name: "Tiểu học",
    customer_id: "customer-1",
    customer_code: "KH01",
    customer_name: "Cụm trường Ánh Dương",
    delivery_location_id: "location-1",
    delivery_location_name: "Cổng giao chính",
    delivery_address: "01 Đường Nguyễn Trãi",
    delivery_instructions: "Trước 05:30",
    contract_context: "Hợp đồng 2026–2027",
  },
];

describe("School default portion model", () => {
  it.each([
    ["0", 0],
    ["2147483647", 2_147_483_647],
    ["", null],
    ["-1", null],
    ["1.5", null],
    ["1e3", null],
    ["unsafe", null],
    ["2147483648", null],
    ["9007199254740992", null],
  ])("parses %j without coercing invalid input to zero", (value, expected) => {
    expect(parsePortionDraft(value)).toBe(expected);
  });

  it("orders by display order and searches all approved Vietnamese context locally", () => {
    expect(
      filterAndOrderSchools(schools, "", "ALL").map((s) => s.school_id),
    ).toEqual(["school-1", "school-2"]);
    expect(filterAndOrderSchools(schools, "anh duong", "ALL")).toEqual([
      schools[1],
    ]);
    expect(filterAndOrderSchools(schools, "be van dan", "ALL")).toEqual([
      schools[0],
    ]);
    expect(filterAndOrderSchools(schools, "", "Tiểu học")).toEqual([
      schools[1],
    ]);
  });

  it("retains valid and invalid drafts, removes matches, and drops orphan Schools after refresh", () => {
    const drafts: SchoolDefaultsDrafts = {
      "school-1": { student: "421", teacher: "" },
      "school-2": { student: "840", teacher: "45" },
      orphan: { student: "1", teacher: "2" },
    };
    expect(reconcileSchoolDrafts(drafts, schools)).toEqual({
      "school-1": { student: "421", teacher: "" },
    });
  });

  it("removes a School from the dirty set when both values return to authority", () => {
    const changed = applySchoolDraftEdit({}, schools[0], "student", "841");
    expect(changed).toEqual({
      "school-2": { student: "841", teacher: "45" },
    });
    expect(applySchoolDraftEdit(changed, schools[0], "student", "840")).toEqual(
      {},
    );
  });

  it("counts invalid and filtered-out dirty Schools without deleting drafts", () => {
    const drafts: SchoolDefaultsDrafts = {
      "school-1": { student: "", teacher: "32" },
      "school-2": { student: "841", teacher: "45" },
    };
    expect(countInvalidDraftSchools(drafts)).toBe(1);
    expect(countHiddenDraftSchools(drafts, [schools[0]])).toBe(1);
  });

  it("freezes exact versions and old/new values for every dirty School", () => {
    const drafts: SchoolDefaultsDrafts = {
      "school-2": { student: "841", teacher: "45" },
      "school-1": { student: "420", teacher: "33" },
    };
    expect(createSchoolDefaultsReview(schools, drafts)).toEqual([
      {
        school_id: "school-1",
        school_code: "TH001",
        school_name: "Trường Tiểu học Ánh Dương",
        expected_version: 3,
        current_student_portions: 420,
        new_student_portions: 420,
        current_teacher_portions: 32,
        new_teacher_portions: 33,
      },
      {
        school_id: "school-2",
        school_code: "TH002",
        school_name: "Trường Trung học Beta",
        expected_version: 7,
        current_student_portions: 840,
        new_student_portions: 841,
        current_teacher_portions: 45,
        new_teacher_portions: 45,
      },
    ]);
    expect(
      createSchoolDefaultsReview(schools, {
        "school-1": { student: "", teacher: "32" },
      }),
    ).toBeNull();
  });
});
