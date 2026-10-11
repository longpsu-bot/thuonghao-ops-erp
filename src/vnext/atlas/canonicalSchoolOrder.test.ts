import { describe, expect, it } from "vitest";
import { compareCanonicalSchools } from "./canonicalSchoolOrder";

describe("canonical School presentation", () => {
  it("uses configured order, Vietnamese name, then stable identity regardless of School code or input order", () => {
    const schools = [
      {
        school_id: "b",
        school_name: "Bình Quới",
        school_code: "001",
        display_order: 2,
      },
      {
        school_id: "a2",
        school_name: "An Bình",
        school_code: "000",
        display_order: 2,
      },
      {
        school_id: "first",
        school_name: "Vĩnh Tân",
        school_code: "999",
        display_order: 1,
      },
      {
        school_id: "a1",
        school_name: "An Bình",
        school_code: "999",
        display_order: 2,
      },
    ];
    expect(
      [...schools].sort(compareCanonicalSchools).map((s) => s.school_id),
    ).toEqual(["first", "a1", "a2", "b"]);
    expect(
      [...schools]
        .reverse()
        .sort(compareCanonicalSchools)
        .map((s) => s.school_id),
    ).toEqual(["first", "a1", "a2", "b"]);
    expect(schools[0].school_id).toBe("b");
  });
  it("keeps absent and null source orders in a deterministic Vietnamese tail", () => {
    const schools = [
      { school_id: "tan-dinh", school_name: "Tân Định", display_order: null },
      { school_id: "tan-binh", school_name: "Tân Bình" },
      { school_id: "dat-cuoc", school_name: "Đất Cuốc", display_order: null },
      {
        school_id: "last-configured",
        school_name: "Vĩnh Tân",
        display_order: 900,
      },
    ];
    expect(
      schools.sort(compareCanonicalSchools).map((s) => s.school_id),
    ).toEqual(["last-configured", "dat-cuoc", "tan-binh", "tan-dinh"]);
  });
});
