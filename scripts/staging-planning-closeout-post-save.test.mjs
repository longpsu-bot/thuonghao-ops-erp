import { test } from "vitest";
import assert from "node:assert/strict";
import * as verifier from "./verify-staging-planning-closeout.mjs";
import * as browser from "./staging-planning-browser.mjs";

const retainedRunId = "0c83b440-8fb2-4a77-9735-804ef4c89ea0";
const currentRunId = "4e5f595f-232a-4c40-b3f8-f4bad96b443f";
const batchId = "a0311e0a-a4de-48b9-a529-fe7464a3352b";
const actorId = "a1010000-0000-4000-8000-000000000001";
const subjectId = "a1010000-0000-4000-8000-000000000101";
const fingerprints = Object.freeze({
  pantry: "d751713988987e9331980363e24189ce",
  attendance: "f0868d16c763ac48fc0d38bf22c47b95",
  weekly_menu: "7a165883b92ada506dfdc7a021e44710",
});

const policies = [
  ["v1-unit-034ce34d3ff3", "Quả"],
  ["v1-unit-2d183c73d76a", "Bó"],
  ["v1-unit-469606e98b7e", "Gói"],
  ["v1-unit-46bab433cc1a", "Cốc"],
  ["v1-unit-83bea5cf6378", "Miếng"],
  ["v1-unit-91a0b1c14124", "Cái"],
  ["v1-unit-9837090d3b3f", "Hũ"],
  ["v1-unit-b1e160b3fbfb", "Chai"],
  ["v1-unit-c854d71627b2", "Cây"],
  ["v1-unit-cac06658f903", "Lon"],
  ["v1-unit-cad1515b85c4", "Ổ"],
  ["v1-unit-dafac3b7da11", "Bịch"],
  ["v1-unit-ea9046ea54e4", "Hộp"],
  ["v1-unit-eb0ce03e77fa", "Trái"],
].map(([unit_code, unit_name]) => ({
  unit_code,
  unit_name,
  dimension_code: "COUNT",
  unit_status: "ACTIVE",
  planning_step: 1,
  effective_from: "2026-09-14",
  effective_to: null,
  policy_revision_status: "ACTIVE",
  revision_number: 1,
}));
policies.push({
  unit_code: "kg",
  unit_name: "Kilogram",
  dimension_code: "MASS",
  unit_status: "ACTIVE",
  planning_step: 0.01,
  effective_from: "2026-01-01",
  effective_to: null,
  policy_revision_status: "ACTIVE",
  revision_number: 1,
});

function generationReceipt({ correction = false } = {}) {
  return {
    command_id: correction ? "correction" : "original",
    command_name: "execute_need_generation",
    actor_id: actorId,
    expected_version: correction ? 3 : 1,
    idempotency_key: correction
      ? "planning-d046-correction:correction"
      : "generation:original",
    idempotency_status: "COMPLETED",
    outcome: "COMPLETED",
    success: true,
    affected_aggregate_ids: {
      need_generation_run_id: correction ? currentRunId : retainedRunId,
      confirmed_need_batch_id: batchId,
    },
    new_versions: {
      need_generation_run_version: 3,
      confirmed_need_batch_version: correction ? 2 : 1,
    },
  };
}

function adoptionManifest() {
  return {
    phase: "post-deploy",
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
    exact_reconciliation_action_count: 76,
    correction_evidence_count: 76,
    direct_successor_version_count: 74,
    successor_present_count: 322,
    exact_sibling_copy_count: 246,
    locked_predecessor_version_count: 74,
    successor_version_mismatch_count: 0,
    sibling_mismatch_count: 0,
  };
}

function postSaveSnapshot() {
  return {
    runs: [
      {
        id: retainedRunId,
        period_start: "2026-09-17",
        period_end: "2026-09-17",
        status: "INVALIDATED",
        version: 4,
        predecessor_run_id: null,
        generated_line_count: 304,
        release_snapshot_line_count: 304,
        blocking_issue_count: 0,
        warning_count: 0,
        actor_id: actorId,
      },
      {
        id: currentRunId,
        period_start: "2026-09-17",
        period_end: "2026-09-17",
        status: "RELEASED_FOR_CONFIRMATION",
        version: 3,
        predecessor_run_id: retainedRunId,
        generated_line_count: 304,
        release_snapshot_line_count: 304,
        blocking_issue_count: 0,
        warning_count: 0,
        actor_id: actorId,
      },
    ],
    batches: [
      {
        id: batchId,
        period_start: "2026-09-17",
        period_end: "2026-09-17",
        status: "DRAFT_REVIEW",
        version: 3,
        source_kind: "NEED_GENERATION",
        origin_run_id: retainedRunId,
        current_run_id: currentRunId,
        origin_run_version: 3,
        current_run_version: 3,
        line_count: 248,
        stable_line_count: 249,
        decision_count: 248,
        current_decision_count: 248,
        adjustment_count: 1,
        acceptance_count: 247,
        invalid_decision_partition_count: 0,
      },
    ],
    handoffs: 0,
    policies: structuredClone(policies),
    preflight: {
      readiness_state: "READY",
      downstream_currentness: "CURRENT",
      blocking_issue_count: 0,
      current_need: {
        need_generation_run_id: currentRunId,
        confirmed_need_batch_id: batchId,
        need_generation_run_version: 3,
        confirmed_need_batch_version: 3,
      },
      source_date_fingerprints: {
        service_date: "2026-09-17",
        selected: { ...fingerprints },
        current: { ...fingerprints },
      },
    },
    receipts: [generationReceipt(), generationReceipt({ correction: true })],
    save_receipts: [
      {
        command_name: "save_confirmed_needs",
        actor_id: actorId,
        scope_key: `${actorId}:ConfirmedNeedBatch:${batchId}`,
        outcome: "COMPLETED",
        request_contract_version: "RMVP-05.v2",
        requested_by_auth_subject: subjectId,
        request_reason_code: "CONFIRMED_NEED_SAVED",
        request_batch_id: batchId,
        expected_version: 2,
        success: true,
        idempotency_status: "COMPLETED",
        confirmed_need_batch_id: batchId,
        prior_batch_version: 2,
        resulting_batch_version: 3,
        adjusted_line_count: 1,
        unchanged_accepted_line_count: 247,
      },
    ],
    save_receipt_count: 1,
    decision_fingerprint: "f".repeat(64),
    d046: {
      predecessor_release_contribution_count: 304,
      successor_release_contribution_count: 304,
      current_snapshot_pair_count: 248,
      exact_proposal_count: 247,
      invalid_proposal_count: 1,
      decision_proposal_count: 248,
      exact_decision_proposal_count: 248,
      invalid_decision_proposal_count: 0,
      retained_pre_d046_null_pair_count: 248,
      allowed_unit_transition_count: 1,
      invalid_unit_transition_count: 0,
      current_raw_membership_count: 304,
    },
    adoption_manifest: adoptionManifest(),
  };
}

function postSaveReview() {
  return {
    confirmed_need_batch_id: batchId,
    batch_version: 3,
    source_kind: "NEED_GENERATION",
    editing_allowed: true,
    blockers: [],
    pagination: { has_more: false },
    lines: Array.from({ length: 248 }, (_, index) => ({
      confirmed_need_line_id: `line-${String(index).padStart(3, "0")}`,
      current_decision_id: `decision-${String(index).padStart(3, "0")}`,
      current_decision_number: 1,
      current_decision_kind:
        index === 0
          ? "ADJUSTED_QUANTITY_CONFIRMED"
          : "UNCHANGED_PROPOSAL_ACCEPTED",
      proposed_confirmed_quantity: "1.000000",
      confirmed_quantity_after: index === 0 ? "1.010000" : "1.000000",
      effective_policy: { planning_step: "0.010000" },
      decision_history: [
        {
          decision_id: `decision-${String(index).padStart(3, "0")}`,
          decision_number: 1,
          predecessor_decision_id: null,
          decision_kind:
            index === 0
              ? "ADJUSTED_QUANTITY_CONFIRMED"
              : "UNCHANGED_PROPOSAL_ACCEPTED",
          revision_id: `revision-${String(index).padStart(3, "0")}`,
          theoretical_quantity_before: "0.910000",
          proposed_quantity_before: "1.000000",
          confirmed_quantity_after: index === 0 ? "1.010000" : "1.000000",
          planning_tick_count: index === 0 ? "101" : "100",
          reason_code:
            index === 0
              ? "OPERATIONAL_QUANTITY_ADJUSTMENT"
              : "PROPOSAL_ACCEPTED",
          reason_note: index === 0 ? "Owner-approved closeout check" : null,
          policy_revision_id: "policy-revision",
          batch_version: 3,
        },
      ],
    })),
  };
}

test("post-Save classifier proves all original proposals while keeping the adjusted current quantity separate", () => {
  assert.deepEqual(
    verifier.classifyPostSavePlanningCloseout(postSaveSnapshot()),
    {
      mode: "POST_SAVE_CLOSEOUT_RESUME",
      predecessorRunId: retainedRunId,
      currentRunId,
      batchId,
      currentLineCount: 248,
      decisionFingerprint: "f".repeat(64),
      fingerprints,
    },
  );
});

for (const [label, mutate] of [
  ["247 decisions", (s) => (s.batches[0].decision_count = 247)],
  ["249 decisions", (s) => (s.batches[0].decision_count = 249)],
  ["247 current decisions", (s) => (s.batches[0].current_decision_count = 247)],
  ["two adjustments", (s) => (s.batches[0].adjustment_count = 2)],
  ["246 acceptances", (s) => (s.batches[0].acceptance_count = 246)],
  [
    "wrong decision semantics",
    (s) => (s.batches[0].invalid_decision_partition_count = 1),
  ],
  [
    "invalid original proposal",
    (s) => (s.d046.invalid_decision_proposal_count = 1),
  ],
  [
    "only 247 exact original proposals",
    (s) => (s.d046.exact_decision_proposal_count = 247),
  ],
  ["handoff present", (s) => (s.handoffs = 1)],
  [
    "changed fingerprint",
    (s) => (s.preflight.source_date_fingerprints.current.pantry = "changed"),
  ],
  ["wrong batch version", (s) => (s.batches[0].version = 2)],
  ["wrong run lineage", (s) => (s.runs[1].predecessor_run_id = "wrong")],
  ["missing decision fingerprint", (s) => (s.decision_fingerprint = null)],
]) {
  test(`post-Save classifier rejects ${label}`, () => {
    const snapshot = postSaveSnapshot();
    mutate(snapshot);
    assert.throws(
      () => verifier.classifyPostSavePlanningCloseout(snapshot),
      /POST_SAVE_CLOSEOUT_REJECTED/,
    );
  });
}

for (const [label, mutate] of [
  ["command name", (r) => (r.command_name = "execute_need_generation")],
  ["actor", (r) => (r.actor_id = "wrong")],
  ["auth subject", (r) => (r.requested_by_auth_subject = "wrong")],
  [
    "PLANNING-injected scope",
    (r) => (r.scope_key = `${actorId}:PLANNING:ConfirmedNeedBatch:${batchId}`),
  ],
  ["scope", (r) => (r.scope_key = `${actorId}:ConfirmedNeedBatch:wrong`)],
  ["outcome", (r) => (r.outcome = "FAILED_NON_RETRYABLE")],
  ["response contract", (r) => (r.request_contract_version = "RMVP-05.v1")],
  ["audit reason", (r) => (r.request_reason_code = "OTHER")],
  ["audit batch id", (r) => (r.request_batch_id = "wrong")],
  ["expected version", (r) => (r.expected_version = 3)],
  ["success", (r) => (r.success = false)],
  ["idempotency", (r) => (r.idempotency_status = "IN_PROGRESS")],
  ["response batch id", (r) => (r.confirmed_need_batch_id = "wrong")],
  ["prior version", (r) => (r.prior_batch_version = 1)],
  ["resulting version", (r) => (r.resulting_batch_version = 4)],
  ["adjusted count", (r) => (r.adjusted_line_count = 2)],
  ["unchanged count", (r) => (r.unchanged_accepted_line_count = 246)],
]) {
  test(`post-Save classifier rejects receipt with wrong ${label}`, () => {
    const snapshot = postSaveSnapshot();
    mutate(snapshot.save_receipts[0]);
    assert.throws(
      () => verifier.classifyPostSavePlanningCloseout(snapshot),
      /POST_SAVE_CLOSEOUT_REJECTED/,
    );
  });
}

for (const [label, mutate] of [
  [
    "zero receipts",
    (snapshot) => {
      snapshot.save_receipts = [];
      snapshot.save_receipt_count = 0;
    },
  ],
  [
    "two receipts",
    (snapshot) => {
      snapshot.save_receipts.push({ ...snapshot.save_receipts[0] });
      snapshot.save_receipt_count = 2;
    },
  ],
]) {
  test(`post-Save classifier rejects ${label}`, () => {
    const snapshot = postSaveSnapshot();
    mutate(snapshot);
    assert.throws(
      () => verifier.classifyPostSavePlanningCloseout(snapshot),
      /POST_SAVE_CLOSEOUT_REJECTED/,
    );
  });
}

test("initial post-Save rejection reports compact dimension diagnostics", () => {
  const snapshot = postSaveSnapshot();
  snapshot.batches[0].decision_count = 247;
  let diagnostic;
  try {
    verifier.classifyPostSavePlanningCloseout(snapshot);
    assert.fail("expected post-Save classification to reject");
  } catch (error) {
    diagnostic = JSON.parse(error.message);
  }
  assert.equal(diagnostic.status, "POST_SAVE_CLOSEOUT_REJECTED");
  assert.deepEqual(diagnostic.checks.decision_count, {
    expected: 248,
    actual: 247,
    pass: false,
  });
  assert.doesNotMatch(JSON.stringify(diagnostic), /line-\d|decision-\d/);
});

test("initial post-Save receipt rejection exposes only its semantic dimension", () => {
  const snapshot = postSaveSnapshot();
  snapshot.save_receipts[0].scope_key = `${actorId}:PLANNING:ConfirmedNeedBatch:${batchId}`;
  let diagnostic;
  try {
    verifier.classifyPostSavePlanningCloseout(snapshot);
    assert.fail("expected post-Save classification to reject");
  } catch (error) {
    diagnostic = JSON.parse(error.message);
  }
  assert.deepEqual(diagnostic.checks.save_receipt_semantics, {
    expected: true,
    actual: false,
    pass: false,
  });
  assert.equal(JSON.stringify(diagnostic).includes(actorId), false);
  assert.equal(JSON.stringify(diagnostic).includes(batchId), false);
});

test("post-Save decision partition rejects wrong reason, blank note, equality adjustment and unequal acceptance", () => {
  for (const mutate of [
    (r) => (r.lines[0].decision_history[0].reason_code = "OTHER"),
    (r) => (r.lines[0].decision_history[0].reason_note = "  "),
    (r) => {
      r.lines[0].confirmed_quantity_after = "1.000000";
      r.lines[0].decision_history[0].confirmed_quantity_after = "1.000000";
    },
    (r) => {
      r.lines[1].confirmed_quantity_after = "1.010000";
      r.lines[1].decision_history[0].confirmed_quantity_after = "1.010000";
    },
  ]) {
    const review = postSaveReview();
    mutate(review);
    assert.throws(
      () => browser.assertPostSaveResumeReview(review),
      /BROWSER_POST_SAVE_READBACK_REJECTED/,
    );
  }
});

test("post-Save workflow cannot fall through to edit, Save, Generate, or Handoff", async () => {
  const calls = { readOnly: 0, mutation: 0 };
  const result = await verifier.startProtectedPlanningBrowserCloseout({
    snapshot: postSaveSnapshot(),
    closeoutMode: "post_save_resume",
    persistRehearsal: false,
    readOnlyJourney: async (baseline) => {
      calls.readOnly += 1;
      assert.equal(baseline.mode, "POST_SAVE_CLOSEOUT_RESUME");
      return { saveClicks: 0, generateClicks: 0, handoffClicks: 0 };
    },
    mutationJourney: async () => {
      calls.mutation += 1;
      return { saveClicks: 1 };
    },
  });
  assert.deepEqual(calls, { readOnly: 1, mutation: 0 });
  assert.deepEqual(result, {
    saveClicks: 0,
    generateClicks: 0,
    handoffClicks: 0,
  });
});

test("post-Save dispatcher rejects the mutation opt-in even when the snapshot is v3", async () => {
  await assert.rejects(
    verifier.startProtectedPlanningBrowserCloseout({
      snapshot: postSaveSnapshot(),
      closeoutMode: "post_save_resume",
      persistRehearsal: true,
      readOnlyJourney: async () => ({}),
      mutationJourney: async () => ({}),
    }),
    /POST_SAVE_RESUME_MUST_BE_READ_ONLY/,
  );
});

test("pre-Save mutation path requires explicit mode and persist_rehearsal=true", async () => {
  const v2 = postSaveSnapshot();
  v2.batches[0].version = 2;
  v2.batches[0].decision_count = 0;
  v2.batches[0].current_decision_count = 0;
  v2.batches[0].adjustment_count = 0;
  v2.batches[0].acceptance_count = 0;
  v2.batches[0].invalid_decision_partition_count = 0;
  v2.preflight.current_need.confirmed_need_batch_version = 2;
  v2.save_receipts = [];
  v2.decision_fingerprint = null;
  v2.d046.exact_proposal_count = 248;
  v2.d046.invalid_proposal_count = 0;

  await assert.rejects(
    verifier.startProtectedPlanningBrowserCloseout({
      snapshot: v2,
      closeoutMode: "post_save_resume",
      persistRehearsal: false,
      readOnlyJourney: async () => ({}),
      mutationJourney: async () => ({}),
    }),
    /POST_SAVE_CLOSEOUT_REJECTED/,
  );
  await assert.rejects(
    verifier.startProtectedPlanningBrowserCloseout({
      snapshot: v2,
      closeoutMode: "pre_save_rehearsal",
      persistRehearsal: false,
      readOnlyJourney: async () => ({}),
      mutationJourney: async () => ({}),
    }),
    /PERSIST_REHEARSAL_REQUIRED/,
  );
});

test("already-saved v3 cannot enter the explicit pre-Save mutation journey", async () => {
  let mutationCalls = 0;
  await assert.rejects(
    verifier.startProtectedPlanningBrowserCloseout({
      snapshot: postSaveSnapshot(),
      closeoutMode: "pre_save_rehearsal",
      persistRehearsal: true,
      readOnlyJourney: async () => ({}),
      mutationJourney: async () => {
        mutationCalls += 1;
        return {};
      },
    }),
  );
  assert.equal(mutationCalls, 0);
});

test("certification-only provenance accepts the explicit allowlist and rejects runtime changes", () => {
  assert.doesNotThrow(() =>
    verifier.assertCertificationOnlyDelta([
      "scripts/verify-staging-planning-closeout.mjs",
      "scripts/staging-planning-browser.mjs",
      "scripts/staging-planning-closeout-post-save.test.mjs",
      "scripts/test-local-planning-final-closeout.mjs",
      ".github/workflows/atlas-staging-planning-closeout.yml",
      "docs/implementation-tasks/TASK-PLANNING-CLOSEOUT-POST-SAVE-VERIFIER.md",
    ]),
  );
  for (const file of [
    "src/vnext/atlas/planning-confirmed/ConfirmedNeedWorkbench.tsx",
    "src/vnext/atlas/bridges/confirmedNeed.ts",
    "supabase/migrations/20260927000000_bad.sql",
    "scripts/staging-planning-preview.mjs",
    "docs/decisions/decision-register.md",
    "docs/business-rules/business-rule-register.md",
    "docs/api/api-contracts.md",
    "docs/implementation-tasks/UNRELATED.md",
  ]) {
    assert.throws(
      () => verifier.assertCertificationOnlyDelta([file]),
      /PLANNING_PREVIEW_CERTIFICATION_DELTA_REJECTED/,
    );
  }
});

test("preview compatibility binds the certified base to the exact verifier commit", () => {
  const verifierCommitSha = "a".repeat(40);
  assert.deepEqual(
    verifier.assertCertificationOnlyComparison({
      verifierCommitSha,
      comparison: {
        status: "ahead",
        merge_base_commit: {
          sha: "1ee97fdb2a51d992c0ee57a9763243ad2da7c279",
        },
        commits: [{ sha: verifierCommitSha }],
        files: [
          { filename: "scripts/verify-staging-planning-closeout.mjs" },
          { filename: "scripts/staging-planning-closeout-post-save.test.mjs" },
        ],
      },
    }),
    {
      verifierCommitSha,
      certifiedPreviewBaseSha: "1ee97fdb2a51d992c0ee57a9763243ad2da7c279",
      previewSha: "4eddd97a7524606ca6ce5e48e2700f6d23a31a03",
    },
  );
  for (const comparison of [
    {
      status: "ahead",
      merge_base_commit: { sha: "b".repeat(40) },
      commits: [{ sha: verifierCommitSha }],
      files: [{ filename: "scripts/verify-staging-planning-closeout.mjs" }],
    },
    {
      status: "ahead",
      merge_base_commit: {
        sha: "1ee97fdb2a51d992c0ee57a9763243ad2da7c279",
      },
      commits: [{ sha: "c".repeat(40) }],
      files: [{ filename: "scripts/verify-staging-planning-closeout.mjs" }],
    },
    {
      status: "ahead",
      merge_base_commit: {
        sha: "1ee97fdb2a51d992c0ee57a9763243ad2da7c279",
      },
      commits: [{ sha: verifierCommitSha }],
      files: [{ filename: "src/vnext/atlas/bridges/confirmedNeed.ts" }],
    },
  ]) {
    assert.throws(
      () =>
        verifier.assertCertificationOnlyComparison({
          verifierCommitSha,
          comparison,
        }),
      /PLANNING_PREVIEW_CERTIFICATION_DELTA_REJECTED/,
    );
  }
});

test("preview compatibility keeps PR 286 Draft/Open at the exact head and main base ref", () => {
  assert.doesNotThrow(() =>
    verifier.assertCertifiedPreviewPullRequest({
      number: 286,
      state: "open",
      draft: true,
      head: { sha: "4eddd97a7524606ca6ce5e48e2700f6d23a31a03" },
      base: { ref: "main", sha: "a".repeat(40) },
    }),
  );
  for (const patch of [
    { number: 287 },
    { state: "closed" },
    { draft: false },
    { head: { sha: "a".repeat(40) } },
    { base: { ref: "release", sha: "a".repeat(40) } },
  ]) {
    assert.throws(
      () =>
        verifier.assertCertifiedPreviewPullRequest({
          number: 286,
          state: "open",
          draft: true,
          head: { sha: "4eddd97a7524606ca6ce5e48e2700f6d23a31a03" },
          base: { ref: "main", sha: "a".repeat(40) },
          ...patch,
        }),
      /PLANNING_PREVIEW_PROVENANCE_REJECTED/,
    );
  }
});

test("snapshot query measures decision proposals and semantic Save receipts without dumping decision rows", () => {
  const sql = verifier.planningCloseoutSnapshotSql();
  assert.match(sql, /decision_proposal_count/);
  assert.match(sql, /exact_decision_proposal_count/);
  assert.match(sql, /invalid_decision_proposal_count/);
  assert.match(sql, /decision\.proposed_quantity_before/);
  assert.match(sql, /decision\.confirmed_need_line_revision_id/);
  assert.match(sql, /ingredient\.order_step/);
  assert.match(sql, /ingredient\.purchase_unit_id/);
  assert.match(sql, /ingredient\.version/);
  assert.match(sql, /save_receipts/);
  assert.doesNotMatch(sql, /'decisions',\s*\(select\s+coalesce\(jsonb_agg/i);
});

test("current decision snapshot projection exposes confirmed_need_line_id exactly once", () => {
  const sql = verifier.planningCloseoutSnapshotSql();
  const projection = sql.match(
    /current_decisions as materialized \(\s*select ([\s\S]*?)\s+from scoped_batches/,
  )?.[1];
  assert.ok(projection, "expected current_decisions CTE projection");
  assert.match(projection, /^decision\.\*/);
  assert.doesNotMatch(
    projection,
    /line\.confirmed_need_line_id\s*,\s*decision\.\*/,
  );
});

test("final post-Save proof accepts read-only browser evidence and emits the closeout summary", () => {
  const state = postSaveSnapshot();
  const review = postSaveReview();
  state.decision_fingerprint = browser.persistedDecisionFingerprint(review);
  const baseline = verifier.classifyPostSavePlanningCloseout(state);
  assert.deepEqual(
    verifier.assertFinalPlanningCloseoutProof({
      baseline,
      browser: {
        mode: "POST_SAVE_CLOSEOUT_RESUME",
        batchId,
        batchVersion: 3,
        renderedRows: 248,
        generateClicks: 0,
        saveClicks: 0,
        handoffClicks: 0,
        decisionFingerprint: state.decision_fingerprint,
        authoritativeReopen: true,
      },
      state,
      review,
      baselineFingerprints: fingerprints,
      finalFingerprints: fingerprints,
    }),
    {
      status: "FINAL_PLANNING_CLOSEOUT_PASS",
      mode: "POST_SAVE_CLOSEOUT_RESUME",
      needGenerationRuns: 2,
      confirmedNeedBatchVersion: 3,
      currentLines: 248,
      stableLineIdentities: 249,
      decisions: 248,
      currentDecisions: 248,
      proposalAcceptances: 247,
      operationalAdjustments: 1,
      exactDecisionProposals: 248,
      invalidDecisionProposals: 0,
      saveReceipts: 1,
      purchaseHandoffs: 0,
      sourceFingerprintsUnchanged: true,
      authoritativeReopen: true,
    },
  );
});

test("final proof failure reports only compact dimension diagnostics", () => {
  const state = postSaveSnapshot();
  const review = postSaveReview();
  state.decision_fingerprint = browser.persistedDecisionFingerprint(review);
  const baseline = verifier.classifyPostSavePlanningCloseout(state);
  state.batches[0].acceptance_count = 246;
  let message = "";
  try {
    verifier.assertFinalPlanningCloseoutProof({
      baseline,
      browser: {
        mode: "POST_SAVE_CLOSEOUT_RESUME",
        batchId,
        batchVersion: 3,
        renderedRows: 248,
        generateClicks: 0,
        saveClicks: 0,
        handoffClicks: 0,
        decisionFingerprint: state.decision_fingerprint,
        authoritativeReopen: true,
      },
      state,
      review,
      baselineFingerprints: fingerprints,
      finalFingerprints: fingerprints,
    });
  } catch (error) {
    message = error.message;
  }
  const diagnostic = JSON.parse(message);
  assert.equal(diagnostic.status, "FINAL_PLANNING_CLOSEOUT_PROOF_FAILED");
  assert.deepEqual(diagnostic.checks.acceptance_count, {
    expected: 247,
    actual: 246,
    pass: false,
  });
  assert.equal(JSON.stringify(diagnostic).includes("line-000"), false);
  assert.equal(JSON.stringify(diagnostic).includes("decision-000"), false);
});
