// @vitest-environment node
import { describe, expect, it } from "vitest";
import * as configuration from "./atlas-document-school-configuration.mjs";

const source = () =>
  configuration.ownerSchoolIdentityExpectations.map(
    ([legacy_school_id, source_name]) => ({ legacy_school_id, source_name }),
  );
const schoolId = (id) => `aa000000-0000-4000-8000-${id.padStart(12, "0")}`;
const schools = () =>
  source().map((s, i) => ({
    school_id: schoolId(s.legacy_school_id),
    school_code: `v1-school-${s.legacy_school_id}`,
    school_name: s.source_name,
    display_order: i,
  }));
const mappings = () =>
  source().map((s) => ({
    source_system: "OPS_V1",
    object_type: "SCHOOL",
    legacy_id: s.legacy_school_id,
    school_id: schoolId(s.legacy_school_id),
  }));
const report = (overrides = {}) => {
  expect(configuration.buildSchoolMasterReconciliationReport).toBeTypeOf(
    "function",
  );
  return configuration.buildSchoolMasterReconciliationReport({
    source: source(),
    schools: schools(),
    mappings: mappings(),
    ...overrides,
  });
};

describe("School master reconciliation evidence", () => {
  it("reports all 15 Owner identities deterministically from typed mappings", () => {
    const value = report();
    expect(value.map((r) => r.legacy_school_id)).toEqual([
      "10",
      "52",
      "47",
      "48",
      "49",
      "50",
      "53",
      "40",
      "38",
      "19",
      "46",
      "27",
      "28",
      "17",
      "14",
    ]);
    expect(value.every((r) => r.status === "MATCH")).toBe(true);
    expect(
      report({
        source: source().reverse(),
        schools: schools().reverse(),
        mappings: mappings().reverse(),
      }),
    ).toEqual(value);
  });
  it("separates a stale name from a genuinely missing typed identity", () => {
    const rows = schools().filter((s) => s.school_code !== "v1-school-52");
    rows.find((s) => s.school_code === "v1-school-10").school_name =
      "BÌNH QUỚI";
    const value = report({
      schools: rows,
      mappings: mappings().filter((m) => m.legacy_id !== "52"),
    });
    expect(value.find((r) => r.legacy_school_id === "10")).toMatchObject({
      status: "NAME_MISMATCH",
      current_atlas_school_id: schoolId("10"),
      current_atlas_code: "v1-school-10",
      current_atlas_name: "BÌNH QUỚI",
    });
    expect(value.find((r) => r.legacy_school_id === "52")).toMatchObject({
      status: "MISSING",
      current_atlas_school_id: null,
    });
  });
  it("does not adopt an orphaned same-name or same-code School", () => {
    const sameName = report({
      mappings: mappings().filter((m) => m.legacy_id !== "52"),
      schools: schools().map((s) =>
        s.school_code === "v1-school-52"
          ? { ...s, school_code: "unmanaged-same-name" }
          : s,
      ),
    });
    expect(sameName.find((r) => r.legacy_school_id === "52").status).toBe(
      "MISSING",
    );
    const sameCode = report({
      mappings: mappings().filter((m) => m.legacy_id !== "52"),
    });
    expect(sameCode.find((r) => r.legacy_school_id === "52").status).toBe(
      "WRONG_MAPPING",
    );
  });
  it("detects duplicate mappings and shared UUIDs, including unrelated source IDs", () => {
    const duplicate = report({ mappings: [...mappings(), mappings()[0]] });
    expect(duplicate.find((r) => r.legacy_school_id === "52").status).toBe(
      "DUPLICATE_MAPPING",
    );
    const shared = report({
      mappings: [
        ...mappings(),
        {
          source_system: "OPS_V1",
          object_type: "SCHOOL",
          legacy_id: "999",
          school_id: schoolId("10"),
        },
      ],
    });
    expect(shared.find((r) => r.legacy_school_id === "10").status).toBe(
      "DUPLICATE_MAPPING",
    );
  });
  it("rejects missing, duplicate or changed source identity instead of guessing", () => {
    expect(() => report({ source: source().slice(1) })).toThrow(
      /SCHOOL_MASTER_RECONCILIATION_REQUIRED/,
    );
    expect(() => report({ source: [...source(), source()[0]] })).toThrow(
      /SCHOOL_MASTER_RECONCILIATION_REQUIRED/,
    );
    expect(() =>
      report({
        source: source().map((s) =>
          s.legacy_school_id === "10" ? { ...s, source_name: "BÌNH QUỚI" } : s,
        ),
      }),
    ).toThrow(/SCHOOL_MASTER_RECONCILIATION_REQUIRED/);
  });
  it("flags dangling and wrongly coded typed mappings", () => {
    const dangling = report({
      schools: schools().filter((s) => s.school_code !== "v1-school-10"),
    });
    expect(dangling.find((r) => r.legacy_school_id === "10").status).toBe(
      "WRONG_MAPPING",
    );
    const wrong = report({
      schools: schools().map((s) =>
        s.school_code === "v1-school-10"
          ? { ...s, school_code: "v1-school-999" }
          : s,
      ),
    });
    expect(wrong.find((r) => r.legacy_school_id === "10").status).toBe(
      "WRONG_MAPPING",
    );
  });
});
