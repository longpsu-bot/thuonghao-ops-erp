import { test } from "vitest";
import assert from "node:assert/strict";
import * as preview from "./staging-planning-preview.mjs";

test("preview provenance requires exact immutable deployment, PR286 head and required main ancestry", () => {
  const facts = {
    url: "https://abc12345.thuonghao-ops-erp.pages.dev/",
    sha: "a".repeat(40),
    requiredSha: "b".repeat(40),
    prHead: "a".repeat(40),
    comparison: { status: "ahead", merge_base_commit: { sha: "b".repeat(40) } },
    manifest: {
      schema: "atlas-planning-preview.v1",
      commit: "a".repeat(40),
      dirty: false,
      entrypoint: "AtlasVNextConnectedApp",
      supabaseOrigin: "https://rnzxmxiiqgtdevzregff.supabase.co",
    },
  };
  assert.equal(preview.assertPlanningPreview(facts).commit, facts.sha);
  for (const patch of [
    { url: "https://main.thuonghao-ops-erp.pages.dev/" },
    { sha: "c".repeat(40) },
    { prHead: "c".repeat(40) },
    { comparison: { status: "diverged" } },
    { manifest: { ...facts.manifest, dirty: true } },
    { manifest: { ...facts.manifest, entrypoint: "AtlasApp" } },
    { manifest: { ...facts.manifest, commit: "c".repeat(40) } },
    {
      manifest: {
        ...facts.manifest,
        supabaseOrigin: "https://other.supabase.co",
      },
    },
  ])
    assert.throws(
      () => preview.assertPlanningPreview({ ...facts, ...patch }),
      /PREVIEW_PROVENANCE/,
    );
});
