// @vitest-environment node
import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import {
  buildPreparationProbe,
  classifyPreparationProbe,
} from "./diagnose-confirmed-need-preparation.mjs";

describe("bounded C388 Preparation evidence", () => {
  it("rejects local CLI execution before changing any migration or starting a database", () => {
    const migration =
      "supabase/migrations/20261015065552_operator_confirmed_need_correction.sql";
    const before = readFileSync(migration);
    const result = spawnSync(
      process.execPath,
      ["scripts/diagnose-confirmed-need-preparation.mjs", "baseline"],
      {
        env: { ...process.env, GITHUB_ACTIONS: "false" },
        encoding: "utf8",
      },
    );
    expect(result.status).not.toBe(0);
    expect(result.stderr).toContain(
      "restricted to a first-attempt manual repository Actions run",
    );
    expect(readFileSync(migration).equals(before)).toBe(true);
  });
  it("retains the original 250-family prefix and stops at the first corrected Preparation", () => {
    const { sql, fixtureSha256 } = buildPreparationProbe("baseline");
    expect(fixtureSha256).toMatch(/^[a-f0-9]{64}$/);
    expect(sql).toContain("generate_series(1,50)");
    expect(sql).toContain("generate_series(1,5)");
    expect(sql).toContain("set local statement_timeout='20s'");
    expect(sql).toContain("set local lock_timeout='1s'");
    expect(sql).toContain("set constraints all immediate;");
    expect(sql).toContain("select pg_temp.c_scale_history('preparation',1);");
    expect(sql).not.toContain("generate_series(1,8)");
    expect(sql).not.toContain("select pg_temp.c_scale_history('replacement'");
    expect(sql.trimEnd()).toMatch(/rollback;$/);
    expect(sql).not.toContain("track_functions");
  });

  it("adds session instrumentation only after the original correction/allocation prefix", () => {
    const { sql } = buildPreparationProbe("profile");
    expect(sql.indexOf("set local track_functions")).toBeGreaterThan(
      sql.indexOf("select pg_temp.c_scale_history('allocation-save',1);"),
    );
    expect(sql).toContain("set local pg_stat_statements.track='all'");
    expect(sql).toContain("set local auto_explain.log_nested_statements=on");
    expect(sql).not.toMatch(
      /alter\s+(system|role)|pg_stat_statements_reset|pg_stat_reset/i,
    );
    expect(() => buildPreparationProbe("full-integration")).toThrow();
  });

  it("never attributes prefix failure or treats canceled work as a completed target", () => {
    const prefix =
      "C_SCALE_START preparation prepare_school_catering_purchase_orders depth 0";
    const target =
      "C_SCALE_START history-1-preparation prepare_school_catering_purchase_orders depth 1";
    const timeout = "canceling statement due to statement timeout";
    expect(classifyPreparationProbe(3, prefix + timeout, true)).toBe(
      "INVALID_PREFIX",
    );
    expect(classifyPreparationProbe(3, target + timeout, true)).toBe(
      "TARGET_TIMEOUT",
    );
    expect(classifyPreparationProbe(0, target, true)).toBe("INCOMPLETE_TARGET");
    expect(
      classifyPreparationProbe(
        0,
        target + "\nC_SCALE_END history-1-preparation ms 10 success true",
        true,
      ),
    ).toBe("TARGET_COMPLETED");
    expect(
      classifyPreparationProbe(
        0,
        target + "\nC_SCALE_END history-1-preparation ms 10 success true",
        false,
      ),
    ).toBe("FAIL_RESIDUE_OR_INTEGRITY");
  });

  it("preserves full-integration defaults while allowing explicit bounded dispatch", () => {
    const workflow = readFileSync(
      ".github/workflows/supabase-integration.yml",
      "utf8",
    );
    expect(workflow).toContain("default: full-integration");
    expect(workflow).toContain("inputs.scope == 'full-integration'");
    expect(workflow).toContain("name: C388 bounded Preparation diagnostic");
    expect(workflow).toContain(
      "node scripts/diagnose-confirmed-need-preparation.mjs",
    );
    expect(workflow).not.toContain("secrets.");
  });
});
