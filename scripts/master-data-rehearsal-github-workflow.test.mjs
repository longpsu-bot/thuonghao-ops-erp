// @vitest-environment node
import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

const workflowPath =
  ".github/workflows/atlas-master-data-rehearsal-validate.yml";

function workflow() {
  return readFileSync(workflowPath, "utf8");
}

describe("GitHub-only OPS v1 master rehearsal validation", () => {
  it("is manual, exact-main, read-only, and uses the protected management token", () => {
    const text = workflow();

    expect(text).toContain("workflow_dispatch:");
    expect(text).not.toMatch(/^\s*(push|pull_request):/m);
    expect(text).toContain("permissions:\n  contents: read");
    expect(text).toContain("environment: atlas-staging");
    expect(text).toContain(
      "ATLAS_STAGING_SUPABASE_ACCESS_TOKEN: ${{ secrets.ATLAS_STAGING_SUPABASE_ACCESS_TOKEN }}",
    );
    expect(text).toContain("git rev-parse origin/main");
    expect(text).toContain("git status --porcelain");
    expect(text).toContain("pnpm ops:v1:master:snapshot --");
    expect(text).toContain("pnpm local:master-data:rehearsal:preview --");
    expect(text).toContain("$RUNNER_TEMP/ops-v1-master.json");
    expect(text).toContain("if: always()");

    for (const forbidden of [
      "--apply",
      "local:master-data:rehearsal:apply",
      "atlas:staging:deploy",
      "supabase db push",
      "ATLAS_STAGING_PROJECT_REF",
      "VITE_SUPABASE_URL",
      "actions/upload-artifact",
    ]) {
      expect(text).not.toContain(forbidden);
    }
  });

  it("never stores the raw OPS snapshot outside runner temp", () => {
    const text = workflow();
    expect(text).not.toMatch(/artifact|cache.*ops-v1-master/i);
    expect(text.match(/ops-v1-master\.json/g)?.length).toBeGreaterThanOrEqual(
      2,
    );
  });
});
