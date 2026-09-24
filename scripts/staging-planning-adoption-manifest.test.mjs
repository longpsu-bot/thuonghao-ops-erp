import assert from "node:assert/strict";
import { test } from "vitest";
import {
  planningAdoptionManifestSql,
  classifyPlanningAdoptionManifest,
} from "./verify-staging-planning-adoption-manifest.mjs";

const expected = {
  eligibleLineCount: 76,
  affectedReleasedVersionCount: 74,
  projectedSuccessorPresentCount: 322,
  correctedLineCount: 76,
  copiedSiblingCount: 246,
  legacyIngredientIds: ["956", "1012", "1045", "1057"],
  excludedNativeMismatchCount: 1,
  excludedNativeSourceKind: "UIQ03A_SAVE",
};

function manifestFixture(phase) {
  return {
    phase,
    eligible_line_count: 76,
    affected_released_version_count: 74,
    projected_successor_present_count: 322,
    corrected_line_count: 76,
    copied_sibling_count: 246,
    legacy_ingredient_ids: ["956", "1012", "1045", "1057"],
    excluded_native_mismatch_count: 1,
    excluded_native_source_kind: "UIQ03A_SAVE",
    incomplete_candidate_count: 0,
    duplicate_candidate_count: 0,
    remapped_source_count: 0,
    ...(phase === "post-deploy"
      ? {
          correction_evidence_count: 76,
          direct_successor_version_count: 74,
          successor_present_count: 322,
          exact_sibling_copy_count: 246,
          locked_predecessor_version_count: 74,
        }
      : {}),
  };
}

test("pre-deploy manifest accepts only the exact 76-line authority", () => {
  assert.deepEqual(
    classifyPlanningAdoptionManifest(
      manifestFixture("pre-deploy"),
      "pre-deploy",
    ),
    expected,
  );
  for (const [field, value] of [
    ["eligible_line_count", 75],
    ["affected_released_version_count", 75],
    ["projected_successor_present_count", 321],
    ["corrected_line_count", 77],
    ["copied_sibling_count", 245],
    ["legacy_ingredient_ids", ["956", "1012", "1045"]],
    ["legacy_ingredient_ids", ["956", "1012", "1045", "1057", "9999"]],
    ["excluded_native_mismatch_count", 0],
    ["excluded_native_mismatch_count", 2],
    ["excluded_native_source_kind", "OPS_V1"],
    ["incomplete_candidate_count", 1],
    ["duplicate_candidate_count", 1],
    ["remapped_source_count", 1],
  ]) {
    assert.throws(
      () =>
        classifyPlanningAdoptionManifest(
          { ...manifestFixture("pre-deploy"), [field]: value },
          "pre-deploy",
        ),
      /PLANNING_ADOPTION_MANIFEST_REJECTED/,
    );
  }
});

test("post-deploy manifest requires exact immutable successor evidence", () => {
  assert.deepEqual(
    classifyPlanningAdoptionManifest(
      manifestFixture("post-deploy"),
      "post-deploy",
    ),
    expected,
  );
  for (const [field, value] of [
    ["correction_evidence_count", 75],
    ["correction_evidence_count", 77],
    ["direct_successor_version_count", 73],
    ["successor_present_count", 321],
    ["exact_sibling_copy_count", 245],
    ["locked_predecessor_version_count", 73],
    ["duplicate_candidate_count", 1],
    ["remapped_source_count", 1],
  ]) {
    assert.throws(
      () =>
        classifyPlanningAdoptionManifest(
          { ...manifestFixture("post-deploy"), [field]: value },
          "post-deploy",
        ),
      /PLANNING_ADOPTION_MANIFEST_REJECTED/,
    );
  }
});

test("manifest SQL is phase-bounded, read-only, and payload-free", () => {
  const pre = planningAdoptionManifestSql("pre-deploy");
  const post = planningAdoptionManifestSql("post-deploy");
  for (const sql of [pre, post]) {
    assert.match(sql, /^begin read only;/);
    assert.match(sql, /rollback;$/);
    assert.doesNotMatch(sql, /\b(insert|update|delete|merge|commit)\b/i);
    assert.doesNotMatch(
      sql,
      /atlas_api\.|jsonb_agg\(\s*(to_jsonb|row_to_json|\w+\.\*)/i,
    );
  }
  assert.doesNotMatch(pre, /recipe_unit_adoption_evidence/);
  assert.match(pre, /master_data_mappings/);
  assert.match(pre, /import_batches/);
  assert.match(post, /recipe_unit_adoption_evidence/);
  assert.throws(
    () => planningAdoptionManifestSql("deploy"),
    /PLANNING_ADOPTION_MANIFEST_PHASE_REJECTED/,
  );
});
