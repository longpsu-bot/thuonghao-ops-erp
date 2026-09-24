import assert from "node:assert/strict";
import { test } from "vitest";
import {
  RETAINED_BATCH,
  RETAINED_RUN,
  classifyD046CorrectionBaseline,
  buildD046CorrectionRequest,
  executeD046Correction,
} from "./correct-staging-planning-d046.mjs";

const successorRunId = "d0460000-0000-4000-8000-000000000017";
const commandId = "d0460000-0000-4000-8000-000000000018";
const actorId = "a1010000-0000-4000-8000-000000000001";
const fingerprints = {
  attendance: "attendance",
  pantry: "pantry",
  weekly_menu: "menu",
};

function postDeployManifest() {
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
    correction_evidence_count: 76,
    direct_successor_version_count: 74,
    successor_present_count: 322,
    exact_sibling_copy_count: 246,
    locked_predecessor_version_count: 74,
  };
}

function receipt(runId, batchVersion, runVersion = 3, id = "initial") {
  return {
    command_id: id,
    command_name: "execute_need_generation",
    actor_id: actorId,
    outcome: "COMPLETED",
    success: true,
    affected_aggregate_ids: {
      need_generation_run_id: runId,
      confirmed_need_batch_id: RETAINED_BATCH,
    },
    new_versions: {
      need_generation_run_version: runVersion,
      confirmed_need_batch_version: batchVersion,
    },
  };
}

export function preCorrectionSnapshot() {
  return {
    runs: [
      {
        id: RETAINED_RUN,
        period_start: "2026-09-17",
        period_end: "2026-09-17",
        status: "RELEASED_FOR_CONFIRMATION",
        version: 3,
        generated_line_count: 304,
        release_snapshot_line_count: 304,
        blocking_issue_count: 0,
        warning_count: 0,
        actor_id: actorId,
        predecessor_run_id: null,
      },
    ],
    batches: [
      {
        id: RETAINED_BATCH,
        period_start: "2026-09-17",
        period_end: "2026-09-17",
        status: "DRAFT_REVIEW",
        version: 1,
        source_kind: "NEED_GENERATION",
        origin_run_id: RETAINED_RUN,
        current_run_id: RETAINED_RUN,
        origin_run_version: 3,
        current_run_version: 3,
        line_count: 248,
        decision_count: 0,
        current_decision_count: 0,
        adjustment_count: 0,
        acceptance_count: 0,
      },
    ],
    handoffs: 0,
    save_receipt_count: 0,
    receipts: [receipt(RETAINED_RUN, 1)],
    preflight: {
      readiness_state: "READY",
      downstream_currentness: "OUTDATED",
      blocking_issue_count: 0,
      current_need: {
        need_generation_run_id: RETAINED_RUN,
        confirmed_need_batch_id: RETAINED_BATCH,
        need_generation_run_version: 3,
        confirmed_need_batch_version: 1,
      },
      source_date_fingerprints: {
        service_date: "2026-09-17",
        selected: { ...fingerprints },
        current: { ...fingerprints },
      },
      outdated_reasons: ["RECIPE_SUCCESSOR_CHANGED"],
    },
    adoption_manifest: postDeployManifest(),
  };
}

export function correctedSnapshot() {
  const snapshot = preCorrectionSnapshot();
  snapshot.runs = [
    {
      ...snapshot.runs[0],
      status: "INVALIDATED",
      version: 4,
    },
    {
      ...snapshot.runs[0],
      id: successorRunId,
      status: "RELEASED_FOR_CONFIRMATION",
      version: 3,
      predecessor_run_id: RETAINED_RUN,
    },
  ];
  snapshot.batches[0] = {
    ...snapshot.batches[0],
    version: 2,
    current_run_id: successorRunId,
    current_run_version: 3,
  };
  snapshot.receipts.push(receipt(successorRunId, 2, 3, commandId));
  snapshot.preflight.downstream_currentness = "CURRENT";
  snapshot.preflight.current_need = {
    need_generation_run_id: successorRunId,
    confirmed_need_batch_id: RETAINED_BATCH,
    need_generation_run_version: 3,
    confirmed_need_batch_version: 2,
  };
  snapshot.preflight.outdated_reasons = [];
  snapshot.d046 = {
    predecessor_release_contribution_count: 304,
    successor_release_contribution_count: 304,
    current_snapshot_pair_count: 248,
    exact_proposal_count: 248,
    invalid_proposal_count: 0,
    retained_pre_d046_null_pair_count: 248,
    allowed_unit_transition_count: 1,
    invalid_unit_transition_count: 0,
    current_raw_membership_count: 304,
  };
  return snapshot;
}

test("pre-correction classifier accepts only the preserved outdated D-046 checkpoint", () => {
  assert.deepEqual(classifyD046CorrectionBaseline(preCorrectionSnapshot()), {
    mode: "D046_CORRECTION_ELIGIBLE",
    predecessorRunId: RETAINED_RUN,
    batchId: RETAINED_BATCH,
    expectedVersion: 3,
    currentLineCount: 248,
    fingerprints,
  });
});

test("D-046 request keeps one stable logical idempotency key", () => {
  const first = buildD046CorrectionRequest(preCorrectionSnapshot(), commandId);
  const second = buildD046CorrectionRequest(preCorrectionSnapshot(), commandId);
  assert.equal(first.command_id, commandId);
  assert.equal(first.idempotency_key, `planning-d046-correction:${commandId}`);
  assert.equal(second.idempotency_key, first.idempotency_key);
  assert.equal(first.expected_version, 3);
  assert.deepEqual(first.payload, {
    service_date: "2026-09-17",
    expected_current_need_generation_run_id: RETAINED_RUN,
  });
});

test("one-shot correction invokes once and reads authoritative state twice", async () => {
  let invokes = 0;
  let reads = 0;
  const snapshots = [preCorrectionSnapshot(), correctedSnapshot()];
  const result = await executeD046Correction({
    commandId,
    invoke: async () => {
      invokes += 1;
      return {
        success: true,
        affected_aggregate_ids: {
          need_generation_run_id: successorRunId,
          confirmed_need_batch_id: RETAINED_BATCH,
        },
      };
    },
    readSnapshot: async () => snapshots[reads++],
  });
  assert.equal(invokes, 1);
  assert.equal(reads, 2);
  assert.equal(result.mode, "D046_CORRECTED_RESUME");
  assert.equal(result.currentRunId, successorRunId);
});

test("unknown RPC response is resolved only by one authoritative readback", async () => {
  let invokes = 0;
  let reads = 0;
  const snapshots = [preCorrectionSnapshot(), correctedSnapshot()];
  const result = await executeD046Correction({
    commandId,
    invoke: async () => {
      invokes += 1;
      throw new Error("connection closed after send");
    },
    readSnapshot: async () => snapshots[reads++],
  });
  assert.equal(invokes, 1);
  assert.equal(reads, 2);
  assert.equal(result.mode, "D046_CORRECTED_RESUME");
});

for (const [label, mutate] of [
  ["decision", (s) => (s.batches[0].decision_count = 1)],
  ["Save receipt", (s) => (s.save_receipt_count = 1)],
  ["Handoff", (s) => (s.handoffs = 1)],
  [
    "second correction receipt",
    (s) => s.receipts.push(receipt(RETAINED_RUN, 1)),
  ],
  [
    "source fingerprint drift",
    (s) => (s.preflight.source_date_fingerprints.current.pantry = "changed"),
  ],
  ["wrong current run", (s) => (s.batches[0].current_run_id = "wrong")],
  ["non-248 current count", (s) => (s.batches[0].line_count = 247)],
  [
    "non-Recipe outdated reason",
    (s) => s.preflight.outdated_reasons.push("MENU_CHANGED"),
  ],
  [
    "manifest drift",
    (s) => (s.adoption_manifest.correction_evidence_count = 75),
  ],
]) {
  test(`pre-correction classifier rejects ${label}`, () => {
    const snapshot = preCorrectionSnapshot();
    mutate(snapshot);
    assert.throws(
      () => classifyD046CorrectionBaseline(snapshot),
      /D046_CORRECTION_BASELINE_REJECTED/,
    );
  });
}

test("rejected baseline performs no RPC", async () => {
  const snapshot = preCorrectionSnapshot();
  snapshot.batches[0].decision_count = 1;
  let invokes = 0;
  let reads = 0;
  await assert.rejects(
    executeD046Correction({
      commandId,
      invoke: async () => {
        invokes += 1;
      },
      readSnapshot: async () => {
        reads += 1;
        return snapshot;
      },
    }),
    /D046_CORRECTION_BASELINE_REJECTED/,
  );
  assert.equal(invokes, 0);
  assert.equal(reads, 1);
});
