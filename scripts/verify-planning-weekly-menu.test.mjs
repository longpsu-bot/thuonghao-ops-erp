// @vitest-environment node
import { describe, expect, it } from "vitest";
import { assertPlanningWeeklyMenuAccepted } from "./verify-planning-weekly-menu.mjs";

const zeroReferences = {
  UNKNOWN_SCHOOL: 0,
  UNKNOWN_DISH: 0,
  AMBIGUOUS_DISH: 0,
};

describe("Planning Weekly Menu acceptance gate", () => {
  it("accepts only a passing read with zero unresolved references", () => {
    expect(() =>
      assertPlanningWeeklyMenuAccepted({
        status: "GOOGLE_WEEKLY_MENU_SHADOW_READ_PASS",
        reference_issue_counts: zeroReferences,
      }),
    ).not.toThrow();
  });

  it("rejects a blocked shadow read even when reference counts are zero", () => {
    expect(() =>
      assertPlanningWeeklyMenuAccepted({
        status: "GOOGLE_WEEKLY_MENU_SHADOW_READ_BLOCKED",
        reference_issue_counts: zeroReferences,
      }),
    ).toThrow("WEEKLY_MENU_READ_ONLY_BLOCKED");
  });

  it.each(Object.keys(zeroReferences))(
    "rejects a passing shadow read with %s references",
    (code) => {
      expect(() =>
        assertPlanningWeeklyMenuAccepted({
          status: "GOOGLE_WEEKLY_MENU_SHADOW_READ_PASS",
          reference_issue_counts: { ...zeroReferences, [code]: 1 },
        }),
      ).toThrow("WEEKLY_MENU_REFERENCE_IDENTITIES_UNRESOLVED");
    },
  );
});
