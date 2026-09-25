import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { test } from "vitest";
import {
  PLANNING_PERFORMANCE_PROBES,
  projectAdoptionGroups,
  planningAdoptionMergeProofAccepted,
  planningAdoptionWorkloadAccepted,
  planningPerformanceProbeAccepted,
  rollbackProbeSql,
  assertPlanningPerformanceCheckpoint,
  runPlanningPerformanceProbes,
} from "./verify-staging-planning-performance.mjs";

function adoptionMergeFixture() {
  return [
    ...Array.from({ length: 230 }, (_, index) => ({
      contributionId: `stable-${index}`,
      legacyOperationalKey: `stable-${index}`,
      correctedOperationalKey: `stable-${index}`,
    })),
    {
      contributionId: "binh-quoi-thom-qua",
      legacyOperationalKey: "binh-quoi-thom-qua",
      correctedOperationalKey: "binh-quoi-thom-trai",
    },
    {
      contributionId: "binh-quoi-thom-trai",
      legacyOperationalKey: "binh-quoi-thom-trai",
      correctedOperationalKey: "binh-quoi-thom-trai",
    },
  ];
}

test("14/09 correction is exactly one operational merge with no contribution loss", () => {
  assert.deepEqual(projectAdoptionGroups(adoptionMergeFixture()), {
    legacyGroupCount: 232,
    correctedGroupCount: 231,
    contributionCountBefore: 232,
    contributionCountAfter: 232,
    mergeCount: 1,
    splitCount: 0,
    lostContributionCount: 0,
  });
});

test("14/09 proof rejects loss, a second merge, a split, and constant-only evidence", () => {
  const asProofRow = (projection) => ({
    legacy_group_count: projection.legacyGroupCount,
    corrected_group_count: projection.correctedGroupCount,
    contribution_count_before: projection.contributionCountBefore,
    contribution_count_after: projection.contributionCountAfter,
    merge_count: projection.mergeCount,
    split_count: projection.splitCount,
    lost_contribution_count: projection.lostContributionCount,
  });
  const accepted = {
    legacy_group_count: 232,
    corrected_group_count: 231,
    contribution_count_before: 232,
    contribution_count_after: 232,
    merge_count: 1,
    split_count: 0,
    lost_contribution_count: 0,
  };
  assert.equal(planningAdoptionMergeProofAccepted(accepted), true);
  const missing = adoptionMergeFixture();
  missing.at(-1).correctedOperationalKey = null;
  const secondMerge = adoptionMergeFixture();
  secondMerge[0].correctedOperationalKey =
    secondMerge[1].correctedOperationalKey;
  const split = adoptionMergeFixture();
  split[0].legacyOperationalKey = split[1].legacyOperationalKey;
  for (const invalid of [
    asProofRow(projectAdoptionGroups(missing)),
    asProofRow(projectAdoptionGroups(secondMerge)),
    asProofRow(projectAdoptionGroups(split)),
    { line_count: 231 },
  ]) {
    assert.equal(planningAdoptionMergeProofAccepted(invalid), false);
  }
});

const valid = {
  success: true,
  error_code: null,
  generation_ms: 6999.999,
  currentness: "CURRENT",
  review_success: true,
  review_error_code: null,
  line_count: 231,
  has_more: false,
  blocker_count: 0,
  editing_allowed: true,
  legacy_group_count: 232,
  corrected_group_count: 231,
  contribution_count_before: 304,
  contribution_count_after: 304,
  merge_count: 1,
  split_count: 0,
  lost_contribution_count: 0,
};

const adoptionWorkloadByDate = Object.freeze({
  "2026-09-14": {
    adoption_occurrence_count: 6,
    adoption_legacy_line_ids: ["line-1", "line-2", "line-3"],
    adoption_ingredient_ids: ["ingredient-1", "ingredient-2"],
  },
  "2026-09-15": {
    adoption_occurrence_count: 5,
    adoption_legacy_line_ids: ["line-1", "line-4", "line-5"],
    adoption_ingredient_ids: ["ingredient-1", "ingredient-3"],
  },
  "2026-09-16": {
    adoption_occurrence_count: 4,
    adoption_legacy_line_ids: ["line-2", "line-6"],
    adoption_ingredient_ids: ["ingredient-2"],
  },
  "2026-09-17": {
    adoption_occurrence_count: 5,
    adoption_legacy_line_ids: ["line-3", "line-7"],
    adoption_ingredient_ids: ["ingredient-1", "ingredient-3"],
  },
  "2026-09-18": {
    adoption_occurrence_count: 4,
    adoption_legacy_line_ids: ["line-5", "line-8"],
    adoption_ingredient_ids: ["ingredient-2", "ingredient-3"],
  },
});

const probeForDate = (date, changes = {}) => ({
  ...valid,
  date,
  ...adoptionWorkloadByDate[date],
  ...changes,
});

test("selected 14-18 September workload is exactly 24 mapped occurrences", () => {
  const rows = Object.entries(adoptionWorkloadByDate).map(([date, proof]) => ({
    date,
    ...proof,
  }));
  assert.equal(planningAdoptionWorkloadAccepted(rows), true);
  for (const mutate of [
    (copy) => {
      copy[0].adoption_occurrence_count -= 1;
    },
    (copy) => {
      copy[4].adoption_legacy_line_ids =
        copy[4].adoption_legacy_line_ids.filter((id) => id !== "line-8");
    },
    (copy) => {
      copy[0].adoption_ingredient_ids.push("ingredient-4");
    },
    (copy) => {
      copy.pop();
    },
    (copy) => {
      copy[1].date = copy[0].date;
    },
  ]) {
    const changed = structuredClone(rows);
    mutate(changed);
    assert.equal(planningAdoptionWorkloadAccepted(changed), false);
  }
});

test("performance probe sequence starts with two rollback-only 14/09 calls", () => {
  assert.deepEqual(PLANNING_PERFORMANCE_PROBES, [
    {
      date: "2026-09-14",
      expectedLineCount: 231,
      requireOneMergeProof: true,
    },
    {
      date: "2026-09-14",
      expectedLineCount: 231,
      requireOneMergeProof: true,
    },
    { date: "2026-09-15", expectedLineCount: 225 },
    { date: "2026-09-16", expectedLineCount: 213 },
    { date: "2026-09-18", expectedLineCount: 210 },
  ]);
  assert.ok(
    !PLANNING_PERFORMANCE_PROBES.some(({ date }) => date === "2026-09-17"),
  );
});

test("performance acceptance enforces success, review, exact rows, and strict margin", () => {
  assert.equal(planningPerformanceProbeAccepted(valid, 231, true), true);
  for (const changes of [
    { generation_ms: 7000 },
    { generation_ms: 7000.001 },
    { success: false, error_code: "RETRYABLE_CONCURRENCY_FAILURE" },
    { error_code: "RETRYABLE_CONCURRENCY_FAILURE" },
    { review_success: false },
    { review_error_code: "REVIEW_FAILED" },
    { currentness: "OUTDATED" },
    { has_more: true },
    { blocker_count: 1 },
    { editing_allowed: false },
    { line_count: 230 },
    { merge_count: 2 },
  ]) {
    assert.equal(
      planningPerformanceProbeAccepted({ ...valid, ...changes }, 231, true),
      false,
    );
  }
});

test("approved rollback SQL retains formal timeouts and never commits", () => {
  const sql = rollbackProbeSql("2026-09-14");
  assert.match(sql, /lock_timeout='2s'/);
  assert.match(sql, /statement_timeout='8s'/);
  assert.match(sql, /atlas_api\.execute_need_generation/);
  assert.match(sql, /atlas_api\.get_confirmed_need_review/);
  assert.ok(
    sql.indexOf("from generated;") <
      sql.indexOf("atlas_api.get_confirmed_need_review"),
  );
  assert.match(sql, /'review_error_code',review->>'error_code'/);
  assert.match(sql, /atlas_legacy\.recipe_unit_adoption_evidence/);
  assert.match(sql, /legacy_group_count/);
  assert.match(sql, /corrected_group_count/);
  assert.match(sql, /contribution_count_before/);
  assert.match(sql, /contribution_count_after/);
  assert.match(sql, /merge_count/);
  assert.match(sql, /split_count/);
  assert.match(sql, /lost_contribution_count/);
  assert.match(sql, /adoption_occurrence_count/);
  assert.match(sql, /adoption_legacy_line_ids/);
  assert.match(sql, /adoption_ingredient_ids/);
  assert.match(sql, /rollback;$/);
  assert.doesNotMatch(sql, /commit;/i);
  assert.throws(() => rollbackProbeSql("2026-09-17"), /UNAPPROVED_PROBE_DATE/);
});

function pristineCheckpoint() {
  const runId = "0c83b440-8fb2-4a77-9735-804ef4c89ea0";
  const batchId = "a0311e0a-a4de-48b9-a529-fe7464a3352b";
  const actorId = "a1010000-0000-4000-8000-000000000001";
  const fingerprints = { attendance: "a", pantry: "p", weekly_menu: "w" };
  const countPolicies = [
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
  ];
  return {
    runs: [
      {
        id: runId,
        period_start: "2026-09-17",
        period_end: "2026-09-17",
        status: "RELEASED_FOR_CONFIRMATION",
        version: 3,
        generated_line_count: 304,
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
        version: 1,
        source_kind: "NEED_GENERATION",
        origin_run_id: runId,
        current_run_id: runId,
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
    policies: [
      ...countPolicies.map(([unit_code, unit_name]) => ({
        unit_code,
        unit_name,
        dimension_code: "COUNT",
        unit_status: "ACTIVE",
        planning_step: 1,
        effective_from: "2026-09-14",
        effective_to: null,
        policy_revision_status: "ACTIVE",
        revision_number: 1,
      })),
      {
        unit_code: "kg",
        unit_name: "Kilogram",
        dimension_code: "MASS",
        unit_status: "ACTIVE",
        planning_step: 0.01,
        effective_from: "2026-01-01",
        effective_to: null,
        policy_revision_status: "ACTIVE",
        revision_number: 1,
      },
    ],
    preflight: {
      readiness_state: "READY",
      downstream_currentness: "CURRENT",
      blocking_issue_count: 0,
      current_need: {
        need_generation_run_id: runId,
        confirmed_need_batch_id: batchId,
        need_generation_run_version: 3,
        confirmed_need_batch_version: 1,
      },
      source_date_fingerprints: {
        service_date: "2026-09-17",
        selected: fingerprints,
        current: { ...fingerprints },
      },
    },
    receipts: [
      {
        command_name: "execute_need_generation",
        actor_id: actorId,
        outcome: "COMPLETED",
        success: true,
        affected_aggregate_ids: {
          need_generation_run_id: runId,
          confirmed_need_batch_id: batchId,
        },
        new_versions: {
          need_generation_run_version: 3,
          confirmed_need_batch_version: 1,
        },
      },
    ],
    save_receipt_count: 0,
    adoption_workload: {
      date: "2026-09-17",
      ...adoptionWorkloadByDate["2026-09-17"],
    },
  };
}

test("failed first probe stops without retry after checkpoint readback", async () => {
  const baseline = pristineCheckpoint();
  const calls = [];
  let reads = 0;
  await assert.rejects(
    runPlanningPerformanceProbes({
      readSnapshot: async () => {
        reads += 1;
        return structuredClone(baseline);
      },
      runProbe: async (date) => {
        calls.push(date);
        return probeForDate(date, {
          success: false,
          error_code: "RETRYABLE_CONCURRENCY_FAILURE",
        });
      },
    }),
    /GENERATION_PERFORMANCE_BLOCKED/,
  );
  assert.deepEqual(calls, ["2026-09-14"]);
  assert.equal(reads, 2);
});

test("performance classification does not inherit browser policy acceptance", async () => {
  const baseline = pristineCheckpoint();
  baseline.policies = [];
  let calls = 0;
  await assert.rejects(
    runPlanningPerformanceProbes({
      readSnapshot: async () => structuredClone(baseline),
      runProbe: async (date) => {
        calls += 1;
        return probeForDate(date, {
          success: false,
          error_code: "RETRYABLE_CONCURRENCY_FAILURE",
        });
      },
    }),
    /GENERATION_PERFORMANCE_BLOCKED/,
  );
  assert.equal(calls, 1);
});

test("performance certification preserves a saved browser checkpoint across every probe", async () => {
  const saved = pristineCheckpoint();
  saved.batches[0].version = 2;
  saved.batches[0].decision_count = 248;
  saved.batches[0].current_decision_count = 248;
  saved.batches[0].adjustment_count = 1;
  saved.batches[0].acceptance_count = 247;
  saved.save_receipt_count = 1;
  saved.preflight.current_need.confirmed_need_batch_version = 2;
  let reads = 0;
  const calls = [];
  const result = await runPlanningPerformanceProbes({
    readSnapshot: async () => {
      reads += 1;
      return structuredClone(saved);
    },
    runProbe: async (date) => {
      calls.push(date);
      return probeForDate(date, {
        line_count:
          PLANNING_PERFORMANCE_PROBES[calls.length - 1].expectedLineCount,
      });
    },
  });
  assert.deepEqual(result, {
    status: "GENERATION_PERFORMANCE_PASS",
    probes: 5,
    checkpointPreserved: true,
    adoptionWorkloadVerified: true,
  });
  assert.equal(reads, 6);
  assert.deepEqual(
    calls,
    PLANNING_PERFORMANCE_PROBES.map(({ date }) => date),
  );
});

for (const [label, contaminate] of [
  [
    "retained Need run overlapping a probe date",
    (checkpoint) =>
      checkpoint.runs.push({
        id: "retained-probe-run",
        period_start: "2026-09-14",
        period_end: "2026-09-16",
      }),
  ],
  [
    "retained Confirmed Need batch on a probe date",
    (checkpoint) =>
      checkpoint.batches.push({
        id: "retained-probe-batch",
        period_start: "2026-09-18",
        period_end: "2026-09-18",
      }),
  ],
]) {
  test(`performance certification rejects ${label} before probing`, async () => {
    const checkpoint = pristineCheckpoint();
    contaminate(checkpoint);
    let probes = 0;
    await assert.rejects(
      runPlanningPerformanceProbes({
        readSnapshot: async () => checkpoint,
        runProbe: async () => {
          probes += 1;
        },
      }),
      /PERFORMANCE_PROBE_DATE_NOT_CLEAN/,
    );
    assert.equal(probes, 0);
  });
}

test("every successful probe proves unchanged checkpoint", async () => {
  const baseline = pristineCheckpoint();
  let reads = 0;
  const calls = [];
  const result = await runPlanningPerformanceProbes({
    readSnapshot: async () => {
      reads += 1;
      return structuredClone(baseline);
    },
    runProbe: async (date) => {
      calls.push(date);
      return probeForDate(date, {
        line_count:
          PLANNING_PERFORMANCE_PROBES[calls.length - 1].expectedLineCount,
      });
    },
  });
  assert.equal(result.status, "GENERATION_PERFORMANCE_PASS");
  assert.equal(reads, 6);
  assert.deepEqual(
    calls,
    PLANNING_PERFORMANCE_PROBES.map(({ date }) => date),
  );
});

test("retained probe effects block certification before the next date", async () => {
  const baseline = pristineCheckpoint();
  let reads = 0;
  let calls = 0;
  await assert.rejects(
    runPlanningPerformanceProbes({
      readSnapshot: async () => {
        reads += 1;
        const snapshot = structuredClone(baseline);
        if (reads > 1) snapshot.runs.push({ id: "retained-probe" });
        return snapshot;
      },
      runProbe: async () => {
        calls += 1;
        return probeForDate("2026-09-14");
      },
    }),
    /PERFORMANCE_CHECKPOINT_CHANGED/,
  );
  assert.equal(calls, 1);
  assert.equal(reads, 2);
});

test("timeout failure is reported as blocked without an automatic retry", async () => {
  const baseline = pristineCheckpoint();
  let reads = 0;
  let calls = 0;
  await assert.rejects(
    runPlanningPerformanceProbes({
      readSnapshot: async () => {
        reads += 1;
        return structuredClone(baseline);
      },
      runProbe: async () => {
        calls += 1;
        throw new Error("statement timeout");
      },
    }),
    /GENERATION_PERFORMANCE_BLOCKED/,
  );
  assert.equal(calls, 1);
  assert.equal(reads, 2);
});

test("performance checkpoint comparison rejects every retained effect", () => {
  const before = {
    runs: [{ id: "run", version: 3, status: "RELEASED_FOR_CONFIRMATION" }],
    batches: [
      {
        id: "batch",
        version: 1,
        status: "DRAFT_REVIEW",
        line_count: 248,
        decision_count: 0,
        current_decision_count: 0,
      },
    ],
    handoffs: 0,
    preflight: { source_date_fingerprints: { selected: { menu: "source" } } },
  };
  assert.doesNotThrow(() =>
    assertPlanningPerformanceCheckpoint(before, structuredClone(before)),
  );
  for (const changed of [
    (s) => {
      s.runs[0].id = "new-run";
    },
    (s) => {
      s.batches[0].version = 2;
    },
    (s) => {
      s.batches[0].decision_count = 1;
    },
    (s) => {
      s.batches[0].current_decision_count = 1;
    },
    (s) => {
      s.handoffs = 1;
    },
    (s) => {
      s.preflight.source_date_fingerprints.selected.menu = "changed";
    },
    (s) => {
      s.runs.push({ id: "retained-probe" });
    },
  ]) {
    const after = structuredClone(before);
    changed(after);
    assert.throws(
      () => assertPlanningPerformanceCheckpoint(before, after),
      /PERFORMANCE_CHECKPOINT_CHANGED/,
    );
  }
});

test("workflow responsibilities are independent", () => {
  const closeout = readFileSync(
    resolve(
      process.cwd(),
      ".github/workflows/atlas-staging-planning-closeout.yml",
    ),
    "utf8",
  );
  const performance = readFileSync(
    resolve(
      process.cwd(),
      ".github/workflows/atlas-staging-planning-performance.yml",
    ),
    "utf8",
  );
  assert.match(closeout, /verify-staging-planning-closeout/);
  assert.match(closeout, /if \[ "\$PERSIST_REHEARSAL" != "true" \]; then/);
  assert.doesNotMatch(
    closeout,
    /install-staging-count-unit-policies|verify-staging-planning-performance|rollback generation probe/i,
  );
  assert.match(performance, /verify-staging-planning-performance/);
  assert.doesNotMatch(
    performance,
    /google-chrome|staging-planning-browser|save_confirmed_needs|install-staging-count-unit-policies/,
  );
});
