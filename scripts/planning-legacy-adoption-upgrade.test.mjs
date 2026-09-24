import { describe, expect, it, vi } from "vitest";
import {
  PLANNING_LEGACY_ADOPTION_UPGRADE_COMMANDS,
  RESTORE_CURRENT_SCHEMA_COMMAND,
  testLocalPlanningLegacyAdoptionUpgrade,
} from "./test-local-planning-legacy-adoption-upgrade.mjs";

describe("planning legacy adoption upgrade harness", () => {
  it("runs the pre-migration fixture through the real migration and restores current schema", () => {
    const runSupabase = vi.fn(() => ({
      status: 0,
      stdout: "",
      stderr: "",
    }));

    expect(testLocalPlanningLegacyAdoptionUpgrade({ runSupabase })).toEqual({
      status: "passed",
    });
    expect(runSupabase.mock.calls.map(([args]) => args)).toEqual([
      ...PLANNING_LEGACY_ADOPTION_UPGRADE_COMMANDS,
      RESTORE_CURRENT_SCHEMA_COMMAND,
    ]);
  });

  it("restores current schema after a failed migration and preserves the primary failure", () => {
    const runSupabase = vi.fn((args) => {
      if (args[0] === "migration") {
        return { status: 1, stdout: "", stderr: "migration rejected" };
      }
      return { status: 0, stdout: "", stderr: "" };
    });

    expect(() =>
      testLocalPlanningLegacyAdoptionUpgrade({ runSupabase }),
    ).toThrow(/migration rejected/);
    expect(runSupabase.mock.calls.at(-1)[0]).toEqual(
      RESTORE_CURRENT_SCHEMA_COMMAND,
    );
  });
});
