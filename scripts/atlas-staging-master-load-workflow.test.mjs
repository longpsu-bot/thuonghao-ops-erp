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
    expect(planningPreview).toContain('case "$APPLY_REQUESTED" in');
    expect(planningPreview).toContain('test "$GITHUB_REF" = "refs/heads/main"');
    expect(planningPreview).toContain(
      'test "$CONFIRMED_TARGET" = "$EXPECTED_PROJECT"',
    );
    expect(planningPreview).toContain('test "$GITHUB_SHA" = "$REQUESTED_SHA"');
    expect(planningPreview).toContain("planning-master-report.tsv");
    expect(planningPreview).toContain(
      "name: ${{ inputs.apply && 'planning-master-apply' || inputs.diagnostic_boundary && 'planning-master-diagnostic-preview' || 'planning-master-preview' }}-${{ inputs.commit_sha }}",
    );
    expect(planningPreview).toContain(
      "${{ inputs.diagnostic_boundary && 'planning-master-diagnostic-report.tsv' || 'planning-master-report.tsv' }}",
    );
    expect(planningPreview).toContain(
      'REVIEWED_DISH_LEGACY_IDS: "2065,2077,2078,2079,2080,2082,2083,2084,2085,2086,2087,2088,2089,2090,2091,2093,2094,2095,2097"',
    );
    expect(planningPreview).toContain('--snapshot-output "$snapshot"');
    expect(planningPreview).toContain("trap 'rm -f \"$snapshot\"' EXIT");
    expect(planningPreview).toContain(
      "deterministicV1Uuid('atlas-staging-master-import-actor')",
    );
    expect(planningPreview).toContain('--snapshot-file "$snapshot"');
    expect(planningPreview).toContain('--plan-checksum "$plan_checksum"');
    expect(planningPreview).toContain('--actor-id "$actor_id"');
    expect(planningPreview).toContain(
      '--apply --target-project-ref "$CONFIRMED_TARGET"',
    );
    expect(planningPreview).toContain("planning-master-apply.json");
    expect(planningPreview).not.toContain("snapshot.json");
    expect(planningPreview).not.toMatch(
      /path: \|[\s\S]*planning-source\.json[\s\S]*if-no-files-found:/,
    );
    expect(planningPreview).not.toContain("planning-preview/\n");
    expect(s).not.toContain("db reset");
    expect(s).not.toContain("qnthofvccilhnefdcxnz");
  });
});
