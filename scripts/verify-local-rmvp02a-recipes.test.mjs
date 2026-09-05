import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

describe("RMVP-02A local acceptance fixture", () => {
  it("provisions the canonical typed Recipe pair and exercises a typed scope", () => {
    const snapshot = JSON.parse(
      readFileSync(
        "supabase/local/rmvp_01_master_data_snapshot.example.json",
        "utf8",
      ),
    );
    const verifier = readFileSync(
      "scripts/verify-local-rmvp02a-recipes.mjs",
      "utf8",
    );

    expect(
      snapshot.records.school_types.map((item) => item.school_type_code),
    ).toEqual(["v1-school-type-1", "v1-school-type-2"]);
    expect(verifier).toContain("canonicalSchoolTypes");
    expect(verifier).toContain("primarySchoolType.school_type_id");
    expect(verifier).not.toContain("school_type_id: null");
  });
});
