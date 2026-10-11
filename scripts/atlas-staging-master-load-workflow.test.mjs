// @vitest-environment node
import { describe, it, expect } from "vitest";
import { readFileSync } from "node:fs";
describe("protected hosted master load workflow", () => {
  it("requires manual exact-main target/apply decisions before protected execution", () => {
    const s = readFileSync(
      new URL(
        "../.github/workflows/atlas-staging-master-data-load.yml",
        import.meta.url,
      ),
      "utf8",
    );
    expect(s).toContain("workflow_dispatch:");
    expect(s).toContain("default: false");
    expect(s).toContain("environment: atlas-staging");
    expect(s).toContain("refs/heads/main");
    expect(s.indexOf("Verify exact current main")).toBeLessThan(
      s.indexOf("Install frozen dependencies"),
    );
    expect(s).toContain("--target-project-ref");
    expect(s).toContain("ATLAS_STAGING_SUPABASE_ACCESS_TOKEN");
    const [fullLoad, planningPreview] = s.split("  planning-preview:");
    expect(fullLoad).not.toContain("upload-artifact");
    expect(planningPreview).toContain('test "$APPLY_REQUESTED" = "false"');
    expect(planningPreview).toContain('test "$GITHUB_SHA" = "$REQUESTED_SHA"');
    expect(planningPreview).toContain("planning-master-report.tsv");
    expect(planningPreview).not.toContain("--apply");
    expect(planningPreview).not.toContain("snapshot.json");
    expect(planningPreview).not.toContain("planning-preview/\n");
    expect(s).not.toContain("db reset");
    expect(s).not.toContain("qnthofvccilhnefdcxnz");
  });
});
