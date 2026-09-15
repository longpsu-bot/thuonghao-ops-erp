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

  it("uses the guarded disposable workdir and accepts a valid rejected preview", () => {
    const text = workflow();

    expect(text).toContain('workdir="$RUNNER_TEMP/atlas-master-rehearsal-01"');
    expect(text).toContain('cp -R supabase "$workdir/supabase"');
    expect(text).toContain('project_id = "atlas-master-rehearsal-01"');
    expect(text).toContain('echo "SUPABASE_WORKDIR=$workdir" >> "$GITHUB_ENV"');
    expect(text).toContain('supabase start --workdir "$SUPABASE_WORKDIR"');
    expect(text).toContain(
      'supabase db reset --local --no-seed --workdir "$SUPABASE_WORKDIR"',
    );
    expect(text).toContain(
      'supabase stop --workdir "$SUPABASE_WORKDIR" --no-backup',
    );
    expect(text).toContain('if [ "$code" -eq 0 ] || [ "$code" -eq 2 ]; then');
    expect(text).toContain('exit "$code"');
    expect(text).toContain('rm -rf "$SUPABASE_WORKDIR"');
  });
});
