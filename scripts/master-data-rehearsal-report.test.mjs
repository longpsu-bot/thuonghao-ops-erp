// @vitest-environment node
import { describe, it, expect } from "vitest";
import { formatMasterDataRehearsalReport } from "./master-data-rehearsal-report.mjs";

describe("master-only rehearsal report", () => {
  it("distinguishes a successful preview from an applied rehearsal", () => {
    const report = formatMasterDataRehearsalReport({
      mode: "preview",
      snapshot: {
        snapshot_id: "synthetic-a",
        snapshot_checksum: "a".repeat(64),
        source_counts: { dishes: 2, ingredients: 3 },
        unit_alias_evidence: [{ source_label: "Hủ", canonical_label: "Hũ" }],
      },
      preview: {
        success: true,
        plan_checksum: "b".repeat(64),
        actions: [
          { object_type: "DISH", legacy_id: "1", action: "CREATE" },
          { object_type: "INGREDIENT", legacy_id: "2", action: "NO_CHANGE" },
        ],
        issues: [],
      },
    });
    expect(report).toContain("Mode: PREVIEW — no business writes");
    expect(report).toContain("Gate: NOT_APPLIED");
    expect(report).not.toContain("CUTOVER_READY");
    expect(report).toContain("Hủ → Hũ");
    for (const section of [
      "Snapshot",
      "Source counts",
      "Actions",
      "Blockers",
      "Target drift",
      "Missing roots",
      "Relationship removals",
      "Source-only fields",
      "Units",
      "Recipe/BOM",
    ])
      expect(report).toContain(section);
  });
  it("sorts issues deterministically and does not print raw source-only contact values", () => {
    const input = {
      mode: "preview",
      snapshot: { snapshot_id: "x", source_counts: {} },
      preview: {
        success: false,
        actions: [],
        issues: [
          {
            code: "SOURCE_ONLY_UNMAPPED",
            severity: "INFO",
            entity: "suppliers",
            legacy_id: "3",
            field: "contact_details",
            detail: "private-phone-value",
          },
          {
            code: "TARGET_DRIFT",
            severity: "BLOCKER",
            object_type: "UNIT",
            legacy_id: "kg",
          },
          {
            code: "RECIPE_EMPTY",
            severity: "BLOCKER",
            object_type: "RECIPE",
            legacy_id: "dish:1:school-type:1",
          },
        ],
      },
    };
    expect(formatMasterDataRehearsalReport(input)).toBe(
      formatMasterDataRehearsalReport({
        ...input,
        preview: {
          ...input.preview,
          issues: [...input.preview.issues].reverse(),
        },
      }),
    );
    expect(formatMasterDataRehearsalReport(input)).toContain("Gate: REJECTED");
    expect(formatMasterDataRehearsalReport(input)).not.toContain(
      "private-phone-value",
    );
  });
  it("reports accepted only after successful apply and authoritative readback", () => {
    const input = {
      mode: "apply",
      snapshot: { snapshot_id: "x", source_counts: {} },
      preview: { success: true, actions: [], issues: [] },
      result: {
        success: true,
        status: "COMPLETED",
        operator_actor_id: "fixture-actor",
      },
      afterPreview: { success: true, actions: [{ action: "NO_CHANGE" }] },
    };
    expect(formatMasterDataRehearsalReport(input)).toContain(
      "Gate: REHEARSAL_ACCEPTED",
    );
    expect(
      formatMasterDataRehearsalReport({
        ...input,
        afterPreview: { success: false },
      }),
    ).toContain("Gate: REJECTED");
    expect(
      formatMasterDataRehearsalReport({ ...input, afterPreview: undefined }),
    ).toContain("Gate: REJECTED");
  });
});
