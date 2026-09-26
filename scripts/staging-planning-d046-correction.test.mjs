import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
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
const correctionWorkflowPath = resolve(
  process.cwd(),
  ".github/workflows/atlas-staging-planning-d046-correction.yml",
);
const retainedLegacyRecipeLine =
  "recipe:dish:1483:school-type:1:ingredient:1045";
const retainedLegacyIngredient = "1045";
const adoptionEvidence = Object.freeze({
  evidence_kind: "OPS_V1_BOM_UNIT_TO_INGREDIENT_PURCHASE_UNIT_CORRECTION",
  source_system: "OPS_V1",
  recipe_id: "recipe-1483",
  recipe_line_id: "recipe-line-1483",
  ingredient_id: "ingredient-1045",
  predecessor_recipe_version_id: "recipe-version-predecessor",
  predecessor_recipe_line_revision_id: "recipe-line-revision-predecessor",
  source_unit_id: "unit-qua",
  target_recipe_version_id: "recipe-version-target",
  target_recipe_line_revision_id: "recipe-line-revision-target",
  corrected_unit_id: "unit-trai",
  quantity_per_basis: "0.025000",
});

function predecessorAdoptionOccurrence() {
  return {
    legacy_recipe_line_id: retainedLegacyRecipeLine,
    legacy_ingredient_id: retainedLegacyIngredient,
    theoretical: {
      recipe_id: adoptionEvidence.recipe_id,
      recipe_line_id: adoptionEvidence.recipe_line_id,
      ingredient_id: adoptionEvidence.ingredient_id,
      recipe_version_id: adoptionEvidence.predecessor_recipe_version_id,
      recipe_line_revision_id:
        adoptionEvidence.predecessor_recipe_line_revision_id,
      unit_id: adoptionEvidence.source_unit_id,
    },
    evidence: { ...adoptionEvidence },
    target: {
      recipe_id: adoptionEvidence.recipe_id,
      recipe_line_id: adoptionEvidence.recipe_line_id,
      ingredient_id: adoptionEvidence.ingredient_id,
      recipe_version_id: adoptionEvidence.target_recipe_version_id,
      recipe_line_revision_id: adoptionEvidence.target_recipe_line_revision_id,
      predecessor_recipe_version_id:
        adoptionEvidence.predecessor_recipe_version_id,
      predecessor_recipe_line_revision_id:
        adoptionEvidence.predecessor_recipe_line_revision_id,
      unit_id: adoptionEvidence.corrected_unit_id,
      quantity_per_basis: adoptionEvidence.quantity_per_basis,
      line_disposition: "PRESENT",
      recipe_version_status: "RELEASED_FOR_PLANNING",
    },
  };
}

function retainedAdoptionWorkload() {
  return {
    date: "2026-09-17",
    adoption_occurrence_count: 1,
    adoption_legacy_line_ids: [retainedLegacyRecipeLine],
    adoption_ingredient_ids: [retainedLegacyIngredient],
    adoption_occurrences: [predecessorAdoptionOccurrence()],
  };
}

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

function receipt(runId, batchVersion, runVersion = 3, id = "initial") {
  return {
    command_id: id,
    expected_version: batchVersion === 1 ? 1 : 3,
    idempotency_key:
      batchVersion === 1
        ? `generation:${id}`
        : `planning-d046-correction:${id}`,
    idempotency_status: "COMPLETED",
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

function benignReceipt() {
  return {
    ...receipt(RETAINED_RUN, 1, 3, "benign-attempt"),
    expected_version: 3,
    idempotency_key: "planning-d046-correction:benign-attempt",
    idempotency_status: "NO_CHANGE",
  };
}

test("recovery accepts one benign NO_CHANGE before the original receipt", () => {
  const snapshot = preCorrectionSnapshot();
  snapshot.receipts.unshift(benignReceipt());
  assert.equal(
    classifyD046CorrectionBaseline(snapshot).mode,
    "D046_CORRECTION_ELIGIBLE",
  );
});

for (const [field, value] of Object.entries({
  actor_id: "other",
  expected_version: 1,
  idempotency_key: "ordinary",
  outcome: "FAILED",
  success: false,
  idempotency_status: "COMPLETED",
  affected_aggregate_ids: {},
  new_versions: {},
})) {
  test(`recovery rejects an extra receipt with invalid ${field}`, () => {
    const snapshot = preCorrectionSnapshot();
    snapshot.receipts.push({ ...benignReceipt(), [field]: value });
    assert.throws(
      () => classifyD046CorrectionBaseline(snapshot),
      /BASELINE_REJECTED/,
    );
  });
}

test("recovery rejects two benign attempts and a missing original", () => {
  const snapshot = preCorrectionSnapshot();
  snapshot.receipts.push(benignReceipt(), {
    ...benignReceipt(),
    command_id: "second",
  });
  assert.throws(
    () => classifyD046CorrectionBaseline(snapshot),
    /BASELINE_REJECTED/,
  );
  snapshot.receipts = [benignReceipt()];
  assert.throws(
    () => classifyD046CorrectionBaseline(snapshot),
    /BASELINE_REJECTED/,
  );
});

test("unknown outcome recovery invokes once with existing benign audit history", async () => {
  const before = preCorrectionSnapshot();
  const after = correctedSnapshot();
  before.receipts.unshift(benignReceipt());
  after.receipts.unshift(benignReceipt());
  let reads = 0;
  let invokes = 0;
  const result = await executeD046Correction({
    commandId,
    readSnapshot: async () => [before, after][reads++],
    invoke: async () => {
      invokes++;
      throw new Error("transport lost after commit");
    },
  });
  assert.equal(result.mode, "D046_CORRECTED_RESUME");
  assert.equal(invokes, 1);
  assert.equal(reads, 2);
});

test("readback cannot attribute another correction to this benign command", async () => {
  const after = correctedSnapshot();
  after.receipts.push({
    ...benignReceipt(),
    command_id: "d0460000-0000-4000-8000-000000000019",
  });
  let reads = 0;
  await assert.rejects(
    executeD046Correction({
      commandId: "d0460000-0000-4000-8000-000000000019",
      readSnapshot: async () => [preCorrectionSnapshot(), after][reads++],
      invoke: async () => {
        throw new Error("unknown");
      },
    }),
    /OUTCOME_REJECTED/,
  );
});

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
      downstream_currentness: "CURRENT",
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
    },
    adoption_workload: retainedAdoptionWorkload(),
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

test("pre-correction classifier accepts the preserved current D-046 checkpoint", () => {
  assert.deepEqual(classifyD046CorrectionBaseline(preCorrectionSnapshot()), {
    mode: "D046_CORRECTION_ELIGIBLE",
    predecessorRunId: RETAINED_RUN,
    batchId: RETAINED_BATCH,
    expectedVersion: 3,
    currentLineCount: 248,
    fingerprints,
  });
});

test("pre-correction eligibility requires CURRENT without a fabricated Recipe outdated reason", () => {
  const snapshot = preCorrectionSnapshot();
  snapshot.preflight.downstream_currentness = "OUTDATED";
  snapshot.preflight.outdated_reasons = ["RECIPE_SUCCESSOR_CHANGED"];
  assert.throws(
    () => classifyD046CorrectionBaseline(snapshot),
    /D046_CORRECTION_BASELINE_REJECTED/,
  );
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

for (const source of ["weekly_menu", "attendance", "pantry"]) {
  test(`pre-correction classifier rejects ${source} fingerprint drift`, () => {
    const snapshot = preCorrectionSnapshot();
    snapshot.preflight.source_date_fingerprints.current[source] = "changed";
    assert.throws(
      () => classifyD046CorrectionBaseline(snapshot),
      /D046_CORRECTION_BASELINE_REJECTED/,
    );
  });
}

for (const [label, mutate] of [
  ["decision", (s) => (s.batches[0].decision_count = 1)],
  ["Save receipt", (s) => (s.save_receipt_count = 1)],
  ["Handoff", (s) => (s.handoffs = 1)],
  [
    "second correction receipt",
    (s) => s.receipts.push(receipt(RETAINED_RUN, 1)),
  ],
  ["wrong current run", (s) => (s.batches[0].current_run_id = "wrong")],
  ["non-248 current count", (s) => (s.batches[0].line_count = 247)],
  [
    "missing predecessor adoption evidence",
    (s) => {
      s.adoption_workload.adoption_occurrence_count = 0;
      s.adoption_workload.adoption_legacy_line_ids = [];
      s.adoption_workload.adoption_ingredient_ids = [];
      s.adoption_workload.adoption_occurrences = [];
    },
  ],
  [
    "mixed predecessor and target lineage",
    (s) => {
      s.adoption_workload.adoption_occurrences[0].theoretical.recipe_line_revision_id =
        adoptionEvidence.target_recipe_line_revision_id;
    },
  ],
  [
    "non-authoritative target successor",
    (s) => {
      s.adoption_workload.adoption_occurrences[0].target.recipe_version_status =
        "LOCKED";
    },
  ],
  [
    "missing target successor",
    (s) => {
      s.adoption_workload.adoption_occurrences[0].target = null;
    },
  ],
  [
    "unrelated Recipe successor",
    (s) => {
      s.adoption_workload.adoption_occurrences[0].evidence.evidence_kind =
        "ORDINARY_RECIPE_SUCCESSOR";
    },
  ],
  [
    "wrong retained Recipe line",
    (s) => {
      s.adoption_workload.adoption_legacy_line_ids = ["unexpected-line"];
      s.adoption_workload.adoption_occurrences[0].legacy_recipe_line_id =
        "unexpected-line";
    },
  ],
  [
    "wrong retained Ingredient",
    (s) => {
      s.adoption_workload.adoption_ingredient_ids = ["9999"];
      s.adoption_workload.adoption_occurrences[0].legacy_ingredient_id = "9999";
    },
  ],
  [
    "unexpected additional adoption correction",
    (s) => {
      s.adoption_workload.adoption_occurrence_count = 2;
      s.adoption_workload.adoption_occurrences.push(
        structuredClone(s.adoption_workload.adoption_occurrences[0]),
      );
    },
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

test("already-corrected state is not pre-correction eligible", () => {
  assert.throws(
    () => classifyD046CorrectionBaseline(correctedSnapshot()),
    /D046_CORRECTION_BASELINE_REJECTED/,
  );
});

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

test("D046 correction workflow is manual, protected, and read-only by default", () => {
  const workflow = readFileSync(correctionWorkflowPath, "utf8");
  const triggerBlock = workflow.match(/^on:\n([\s\S]*?)\npermissions:/m)?.[1];
  const jobHeader = workflow.slice(0, workflow.indexOf("    steps:"));
  const guard = workflow.indexOf("Verify exact current main commit");
  const install = workflow.indexOf("Install frozen dependencies");
  assert.match(workflow, /^name: Atlas Staging Planning D046 Correction$/m);
  assert.match(workflow, /on:\s*\n\s*workflow_dispatch:/);
  assert.deepEqual(
    [...(triggerBlock?.matchAll(/^  ([a-z_]+):/gm) ?? [])].map(
      (match) => match[1],
    ),
    ["workflow_dispatch"],
  );
  assert.match(
    workflow,
    /commit_sha:\s*\n\s+description: Exact full commit SHA at the current origin\/main tip\s*\n\s+required: true\s*\n\s+type: string/,
  );
  assert.match(
    workflow,
    /persist_correction:\s*\n\s+description: Execute the one-shot 17\/09 correction\s*\n\s+required: true\s*\n\s+type: boolean\s*\n\s+default: false/,
  );
  assert.match(
    workflow,
    /permissions:\s*\n\s+contents: read\s*\n\s+actions: read\s*\n\s+checks: read/,
  );
  assert.doesNotMatch(workflow, /permissions:[\s\S]*\bwrite\b/);
  assert.match(workflow, /environment: atlas-staging/);
  assert.match(workflow, /ref: \$\{\{ inputs\.commit_sha \}\}/);
  assert.match(workflow, /fetch-depth: 0/);
  assert.match(
    workflow,
    /git fetch --no-tags origin main:refs\/remotes\/origin\/main/,
  );
  assert.ok(guard >= 0);
  assert.ok(install > guard);
  assert.match(workflow, /\^\[0-9a-f\]\{40\}\$/);
  assert.match(workflow, /git rev-parse HEAD/);
  assert.match(
    workflow,
    /MAIN_SHA="\$\(git rev-parse refs\/remotes\/origin\/main\)"/,
  );
  assert.match(
    workflow,
    /if \[\[ "\$REQUESTED_COMMIT_SHA" != "\$MAIN_SHA" \]\]; then/,
  );
  assert.match(workflow, /commit_sha must equal the current origin\/main SHA/);
  assert.doesNotMatch(workflow, /git merge-base --is-ancestor/);
  assert.doesNotMatch(jobHeader, /secrets\./);
  assert.match(workflow, /version: 11\.7\.0/);
  assert.match(workflow, /node-version: 24/);
  assert.match(workflow, /pnpm install --frozen-lockfile/);
});

test("D046 correction workflow separates eligibility from explicit mutation", () => {
  const workflow = readFileSync(correctionWorkflowPath, "utf8");
  const preflight = workflow.indexOf("Run non-mutating protected preflight");
  const eligibility = workflow.indexOf("Verify D046 correction eligibility");
  const mutation = workflow.indexOf("Execute one-shot D046 correction");
  assert.ok(preflight >= 0);
  assert.ok(eligibility > preflight);
  assert.ok(mutation > eligibility);
  assert.match(
    workflow,
    /if: \$\{\{ inputs\.persist_correction == false \}\}[\s\S]*?node scripts\/correct-staging-planning-d046\.mjs\s+--commit-sha "\$\{\{ inputs\.commit_sha \}\}"/,
  );
  assert.match(
    workflow,
    /if: \$\{\{ inputs\.persist_correction == true \}\}[\s\S]*?node scripts\/correct-staging-planning-d046\.mjs\s+--commit-sha "\$\{\{ inputs\.commit_sha \}\}"\s+--persist-correction/,
  );
  assert.equal(workflow.match(/--persist-correction/g)?.length, 1);
  assert.match(
    workflow,
    /atlas:staging:deploy --[\s\S]*?--certification github[\s\S]*?--preflight/,
  );
  assert.doesNotMatch(
    workflow,
    /planning-(closeout|performance)|persist-rehearsal/i,
  );
});
