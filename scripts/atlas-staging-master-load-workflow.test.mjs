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
    expect(s).toMatch(
      /diagnostic_boundary:\s+description:[^\n]+\s+required: false\s+type: boolean\s+default: false/,
    );
    expect(fullLoad).toContain('test "$DIAGNOSTIC_BOUNDARY" = "false"');
    expect(
      fullLoad.indexOf('test "$DIAGNOSTIC_BOUNDARY" = "false"'),
    ).toBeLessThan(fullLoad.indexOf("Install frozen dependencies"));
    expect(planningPreview).toContain(
      'if [ "$DIAGNOSTIC_BOUNDARY" = "true" ]; then',
    );
    expect(planningPreview).toContain("args+=(--diagnostic-boundary)");
    expect(planningPreview).toContain(
      'node scripts/run-planning-master-catchup.mjs "${args[@]}"',
    );
    expect(fullLoad).not.toContain("upload-artifact");
    expect(planningPreview).toContain('test "$APPLY_REQUESTED" = "false"');
    expect(planningPreview).toContain('test "$GITHUB_SHA" = "$REQUESTED_SHA"');
    expect(planningPreview).toContain("planning-master-report.tsv");
    expect(planningPreview).toContain(
      "name: ${{ inputs.diagnostic_boundary && 'planning-master-diagnostic-preview' || 'planning-master-preview' }}-${{ inputs.commit_sha }}",
    );
    expect(planningPreview).toContain(
      "${{ inputs.diagnostic_boundary && 'planning-master-diagnostic-report.tsv' || 'planning-master-report.tsv' }}",
    );
    expect(planningPreview).not.toContain("--apply");
    expect(planningPreview).not.toContain("snapshot.json");
    expect(planningPreview).not.toContain("planning-preview/\n");
    expect(s).not.toContain("db reset");
    expect(s).not.toContain("qnthofvccilhnefdcxnz");
  });
});
