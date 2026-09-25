import { isDeepStrictEqual } from "node:util";
import { fileURLToPath } from "node:url";
import {
  executeAtlasStagingManagementSql,
  validateAtlasStagingPackageProtectedValues,
  redactAtlasStagingDiagnostic,
} from "./atlas-staging-contract.mjs";
import { verifyPackageCheckout } from "./install-atlas-staging-package.mjs";
import { planningCloseoutSnapshotSql } from "./verify-staging-planning-closeout.mjs";

const SUBJECT = "a1010000-0000-4000-8000-000000000101";
export const PLANNING_GENERATION_MAX_MS = 7000;
export const PLANNING_GENERATION_OPERATOR_TARGET_MS = 4000;
export const PLANNING_PERFORMANCE_PROBES = Object.freeze([
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

export function projectAdoptionGroups(contributions) {
  if (!Array.isArray(contributions)) throw new Error("INVALID_ADOPTION_GROUPS");
  const legacyGroups = new Set();
  const correctedGroups = new Set();
  const legacyToCorrected = new Map();
  const correctedToLegacy = new Map();
  const beforeIds = new Set();
  const afterIds = new Set();

  for (const contribution of contributions) {
    const { contributionId, legacyOperationalKey, correctedOperationalKey } =
      contribution ?? {};
    if (
      typeof contributionId !== "string" ||
      typeof legacyOperationalKey !== "string"
    )
      throw new Error("INVALID_ADOPTION_GROUPS");
    beforeIds.add(contributionId);
    legacyGroups.add(legacyOperationalKey);
    if (typeof correctedOperationalKey !== "string") continue;
    afterIds.add(contributionId);
    correctedGroups.add(correctedOperationalKey);
    if (!legacyToCorrected.has(legacyOperationalKey))
      legacyToCorrected.set(legacyOperationalKey, new Set());
    legacyToCorrected.get(legacyOperationalKey).add(correctedOperationalKey);
    if (!correctedToLegacy.has(correctedOperationalKey))
      correctedToLegacy.set(correctedOperationalKey, new Set());
    correctedToLegacy.get(correctedOperationalKey).add(legacyOperationalKey);
  }

  const excessMappings = (mapping) =>
    [...mapping.values()].reduce(
      (total, targets) => total + Math.max(0, targets.size - 1),
      0,
    );
  return {
    legacyGroupCount: legacyGroups.size,
    correctedGroupCount: correctedGroups.size,
    contributionCountBefore: beforeIds.size,
    contributionCountAfter: afterIds.size,
    mergeCount: excessMappings(correctedToLegacy),
    splitCount: excessMappings(legacyToCorrected),
    lostContributionCount: [...beforeIds].filter((id) => !afterIds.has(id))
      .length,
  };
}

export function planningAdoptionMergeProofAccepted(row) {
  return Boolean(
    row?.legacy_group_count === 232 &&
    row.corrected_group_count === 231 &&
    row.contribution_count_before === row.contribution_count_after &&
    Number.isInteger(row.contribution_count_before) &&
    row.contribution_count_before > 0 &&
    row.merge_count === 1 &&
    row.split_count === 0 &&
    row.lost_contribution_count === 0,
  );
}

const ADOPTION_WORKLOAD_DATES = Object.freeze([
  "2026-09-14",
  "2026-09-15",
  "2026-09-16",
  "2026-09-17",
  "2026-09-18",
]);

export function planningAdoptionWorkloadAccepted(rows) {
  if (!Array.isArray(rows) || rows.length !== ADOPTION_WORKLOAD_DATES.length)
    return false;
  const byDate = new Map();
  for (const row of rows) {
    if (
      !ADOPTION_WORKLOAD_DATES.includes(row?.date) ||
      byDate.has(row.date) ||
      !Number.isInteger(row.adoption_occurrence_count) ||
      row.adoption_occurrence_count <= 0 ||
      !Array.isArray(row.adoption_legacy_line_ids) ||
      !row.adoption_legacy_line_ids.every((id) => typeof id === "string") ||
      !Array.isArray(row.adoption_ingredient_ids) ||
      !row.adoption_ingredient_ids.every((id) => typeof id === "string")
    )
      return false;
    byDate.set(row.date, row);
  }
  if (!ADOPTION_WORKLOAD_DATES.every((date) => byDate.has(date))) return false;
  const occurrences = rows.reduce(
    (total, row) => total + row.adoption_occurrence_count,
    0,
  );
  const lines = new Set(rows.flatMap((row) => row.adoption_legacy_line_ids));
  const ingredients = new Set(
    rows.flatMap((row) => row.adoption_ingredient_ids),
  );
  return occurrences === 24 && lines.size === 8 && ingredients.size === 3;
}

export function planningPerformanceProbeAccepted(
  row,
  expectedLineCount,
  requireOneMergeProof = false,
) {
  return Boolean(
    row?.success === true &&
    row.error_code === null &&
    Number.isFinite(row.generation_ms) &&
    row.generation_ms < PLANNING_GENERATION_MAX_MS &&
    row.currentness === "CURRENT" &&
    row.review_success === true &&
    row.review_error_code === null &&
    row.line_count === expectedLineCount &&
    row.has_more === false &&
    row.blocker_count === 0 &&
    row.editing_allowed === true &&
    (!requireOneMergeProof || planningAdoptionMergeProofAccepted(row)),
  );
}

export function summarizePlanningPerformanceTimings(timings) {
  if (
    !Array.isArray(timings) ||
    timings.length === 0 ||
    timings.some((value) => !Number.isFinite(value) || value < 0)
  )
    throw new Error("INVALID_PERFORMANCE_TIMINGS");
  const samples = [...timings].sort((left, right) => left - right);
  const nearestRank = (percentile) =>
    samples[Math.ceil(percentile * samples.length) - 1];
  const p95 = nearestRank(0.95);
  return {
    samples_ms: samples,
    p50_ms: nearestRank(0.5),
    p95_ms: p95,
    operator_target_ms: PLANNING_GENERATION_OPERATOR_TARGET_MS,
    operator_target_met: p95 <= PLANNING_GENERATION_OPERATOR_TARGET_MS,
  };
}

export function rollbackProbeSql(date) {
  if (!PLANNING_PERFORMANCE_PROBES.some((probe) => probe.date === date))
    throw new Error("UNAPPROVED_PROBE_DATE");
  return `begin; set local lock_timeout='2s'; set local statement_timeout='8s';
create temp table planning_performance_probe_result(r jsonb, generation_ms numeric, review jsonb);
grant select, insert, update on planning_performance_probe_result to authenticated;
set local request.jwt.claims='{"sub":"${SUBJECT}","role":"authenticated"}';
set local role authenticated;
with started as materialized(select clock_timestamp() as at,gen_random_uuid() as id),
generated as materialized(select at,atlas_api.execute_need_generation(jsonb_build_object(
 'contract_version','RMVP-04.v3','command_id',id,'correlation_id',gen_random_uuid(),
 'idempotency_key','planning-performance-probe:'||id,'expected_version',1,
 'requested_by_auth_subject','${SUBJECT}','requested_at',now(),
 'reason_code','NEED_GENERATION_EXECUTED','reason_note','Owner-approved rollback-only Staging performance certification.',
 'payload',jsonb_build_object('service_date','${date}','expected_current_need_generation_run_id',null))) r from started)
insert into planning_performance_probe_result(r,generation_ms)
select r,1000*extract(epoch from clock_timestamp()-at) as generation_ms from generated;
-- The STABLE review needs its own statement to see the materialized batch.
update planning_performance_probe_result set review=case when r->>'success'='true' then
 atlas_api.get_confirmed_need_review(jsonb_build_object('contract_version','RMVP-05.v1',
 'requested_by_auth_subject','${SUBJECT}','correlation_id',gen_random_uuid(),
 'payload',jsonb_build_object('confirmed_need_batch_id',r#>'{affected_aggregate_ids,confirmed_need_batch_id}',
 'filters',jsonb_build_object('service_date','${date}'),'line_offset',0,'line_limit',10000))) else null end;
reset role;
with reviewed as materialized(select r,generation_ms,review from planning_performance_probe_result)
-- Project bounded contribution identities twice: imported raw adoption Unit and
-- current corrected Unit. Only aggregate proof counts leave this transaction.
,source_contributions as materialized(
 select contribution.confirmed_need_line_revision_contribution_id contribution_id,
        contribution.service_date,contribution.customer_id,contribution.school_id,
        contribution.delivery_location_id,contribution.ingredient_id,
        contribution.source_unit_id,contribution.controlled_unit_id,
        contribution.theoretical_need_line_id
 from planning_performance_probe_result result
 join atlas_planning.confirmed_need_line_revision_contributions contribution
   on contribution.confirmed_need_batch_id=(result.r#>>'{affected_aggregate_ids,confirmed_need_batch_id}')::uuid
 join atlas_planning.confirmed_need_line_revisions revision
   on revision.confirmed_need_line_revision_id=contribution.confirmed_need_line_revision_id
  and revision.is_current
),projected_contributions as materialized(
 select source.contribution_id,source.theoretical_need_line_id,
        evidence.recipe_unit_adoption_evidence_id,
        line_mapping.legacy_id adoption_legacy_line_id,
        ingredient_mapping.legacy_id adoption_ingredient_id,
        jsonb_build_array(source.service_date,source.customer_id,source.school_id,
          source.delivery_location_id,source.ingredient_id,
          coalesce(evidence.source_unit_id,source.source_unit_id))::text legacy_operational_key,
        jsonb_build_array(source.service_date,source.customer_id,source.school_id,
          source.delivery_location_id,source.ingredient_id,
          source.controlled_unit_id)::text corrected_operational_key
 from source_contributions source
 join atlas_planning.theoretical_need_lines theoretical
   on theoretical.theoretical_need_line_id=source.theoretical_need_line_id
 left join atlas_legacy.recipe_unit_adoption_evidence evidence
   on evidence.evidence_kind='OPS_V1_BOM_UNIT_TO_INGREDIENT_PURCHASE_UNIT_CORRECTION'
  and evidence.source_system='OPS_V1'
  and evidence.target_recipe_version_id=theoretical.recipe_version_id
  and evidence.target_recipe_line_revision_id=theoretical.recipe_line_revision_id
  and evidence.recipe_id=theoretical.recipe_id
  and evidence.recipe_line_id=theoretical.recipe_line_id
  and evidence.ingredient_id=source.ingredient_id
  and evidence.corrected_unit_id=source.source_unit_id
  and exists (
    select 1 from atlas_legacy.import_batches batch
    where batch.import_batch_id=evidence.import_batch_id
      and batch.source_system='OPS_V1' and batch.import_status='COMPLETED'
      and batch.snapshot_id=evidence.snapshot_id
      and batch.snapshot_checksum=evidence.snapshot_checksum
  )
 left join atlas_legacy.master_data_mappings line_mapping
   on line_mapping.source_system='OPS_V1' and line_mapping.object_type='RECIPE_LINE'
  and line_mapping.recipe_line_id=evidence.recipe_line_id
 left join atlas_legacy.master_data_mappings ingredient_mapping
   on ingredient_mapping.source_system='OPS_V1' and ingredient_mapping.object_type='INGREDIENT'
  and ingredient_mapping.ingredient_id=evidence.ingredient_id
),adoption_merge_proof as materialized(
 select
   (select count(distinct legacy_operational_key)::integer from projected_contributions) legacy_group_count,
   (select count(distinct corrected_operational_key)::integer from projected_contributions) corrected_group_count,
   (select count(distinct contribution_id)::integer from source_contributions) contribution_count_before,
   (select count(distinct contribution_id)::integer from projected_contributions) contribution_count_after,
   (select coalesce(sum(grouping.legacy_count-1),0)::integer from (
      select count(distinct legacy_operational_key)::integer legacy_count
      from projected_contributions group by corrected_operational_key
    ) grouping) merge_count,
   (select coalesce(sum(grouping.corrected_count-1),0)::integer from (
      select count(distinct corrected_operational_key)::integer corrected_count
      from projected_contributions group by legacy_operational_key
    ) grouping) split_count,
   (select count(*)::integer from source_contributions source
      where not exists (select 1 from projected_contributions projected
        where projected.contribution_id=source.contribution_id)) lost_contribution_count
),adoption_workload_proof as materialized(
 select count(distinct theoretical_need_line_id)::integer adoption_occurrence_count,
        coalesce(jsonb_agg(distinct adoption_legacy_line_id order by adoption_legacy_line_id)
          filter (where adoption_legacy_line_id is not null),'[]'::jsonb) adoption_legacy_line_ids,
        coalesce(jsonb_agg(distinct adoption_ingredient_id order by adoption_ingredient_id)
          filter (where adoption_ingredient_id is not null),'[]'::jsonb) adoption_ingredient_ids
 from projected_contributions
 where recipe_unit_adoption_evidence_id is not null
)
select jsonb_build_object('date','${date}','success',r->'success','error_code',r->>'error_code',
 'generation_ms',generation_ms,'currentness',r#>>'{authoritative_readback,preflight,downstream_currentness}',
 'review_success',review->'success','review_error_code',review->>'error_code','line_count',jsonb_array_length(review#>'{workbench,lines}'),
 'has_more',review#>'{workbench,pagination,has_more}',
 'blocker_count',jsonb_array_length(review#>'{workbench,blockers}'),
 'editing_allowed',review#>'{workbench,editing_allowed}',
 'legacy_group_count',proof.legacy_group_count,'corrected_group_count',proof.corrected_group_count,
 'contribution_count_before',proof.contribution_count_before,'contribution_count_after',proof.contribution_count_after,
 'merge_count',proof.merge_count,'split_count',proof.split_count,
 'lost_contribution_count',proof.lost_contribution_count,
 'adoption_occurrence_count',workload.adoption_occurrence_count,
 'adoption_legacy_line_ids',workload.adoption_legacy_line_ids,
 'adoption_ingredient_ids',workload.adoption_ingredient_ids) as probe
from reviewed cross join adoption_merge_proof proof cross join adoption_workload_proof workload;
rollback;`;
}

export function assertPlanningPerformanceCheckpoint(before, after) {
  if (!isDeepStrictEqual(before, after))
    throw new Error("PERFORMANCE_CHECKPOINT_CHANGED");
}

function periodContainsDate(item, date) {
  return item.period_start <= date && item.period_end >= date;
}

export function assertPlanningPerformanceBaseline(snapshot) {
  if (
    !Array.isArray(snapshot?.runs) ||
    !Array.isArray(snapshot?.batches) ||
    [...snapshot.runs, ...snapshot.batches].some(
      (item) =>
        typeof item?.period_start !== "string" ||
        typeof item?.period_end !== "string" ||
        item.period_start > item.period_end,
    )
  )
    throw new Error("PERFORMANCE_CHECKPOINT_INVALID");
  const probeDates = new Set(
    PLANNING_PERFORMANCE_PROBES.map(({ date }) => date),
  );
  if (
    [...snapshot.runs, ...snapshot.batches].some((item) =>
      [...probeDates].some((date) => periodContainsDate(item, date)),
    )
  )
    throw new Error("PERFORMANCE_PROBE_DATE_NOT_CLEAN");
}

export async function runPlanningPerformanceProbes({ readSnapshot, runProbe }) {
  const before = await readSnapshot();
  assertPlanningPerformanceBaseline(before);
  const timings = [];
  const workloadByDate = new Map([
    [before.adoption_workload?.date, before.adoption_workload],
  ]);
  for (const {
    date,
    expectedLineCount,
    requireOneMergeProof = false,
  } of PLANNING_PERFORMANCE_PROBES) {
    let row;
    let failure;
    try {
      row = await runProbe(date);
    } catch (error) {
      failure = error;
    }
    const after = await readSnapshot();
    assertPlanningPerformanceCheckpoint(before, after);
    if (failure)
      throw new Error("GENERATION_PERFORMANCE_BLOCKED", { cause: failure });
    console.log(JSON.stringify({ rollback_probe: row }));
    if (
      !planningPerformanceProbeAccepted(
        row,
        expectedLineCount,
        requireOneMergeProof,
      )
    )
      throw new Error("GENERATION_PERFORMANCE_BLOCKED");
    timings.push(row.generation_ms);
    const workload = {
      date: row.date,
      adoption_occurrence_count: row.adoption_occurrence_count,
      adoption_legacy_line_ids: row.adoption_legacy_line_ids,
      adoption_ingredient_ids: row.adoption_ingredient_ids,
    };
    const prior = workloadByDate.get(row.date);
    if (prior && !isDeepStrictEqual(prior, workload))
      throw new Error("ADOPTION_WORKLOAD_DRIFT");
    workloadByDate.set(row.date, workload);
  }
  if (!planningAdoptionWorkloadAccepted([...workloadByDate.values()]))
    throw new Error("ADOPTION_WORKLOAD_DRIFT");
  return {
    status: "GENERATION_PERFORMANCE_PASS",
    probes: PLANNING_PERFORMANCE_PROBES.length,
    checkpointPreserved: true,
    adoptionWorkloadVerified: true,
    timing: summarizePlanningPerformanceTimings(timings),
  };
}

export async function verifyPlanningPerformance({
  commitSha,
  environment = process.env,
} = {}) {
  const target = validateAtlasStagingPackageProtectedValues(environment);
  verifyPackageCheckout({ commitSha });
  const sql = async (query) =>
    JSON.parse(await executeAtlasStagingManagementSql(target, query));
  return runPlanningPerformanceProbes({
    readSnapshot: async () =>
      (await sql(planningCloseoutSnapshotSql()))[0]?.checkpoint,
    runProbe: async (date) => (await sql(rollbackProbeSql(date)))[0]?.probe,
  });
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const at = process.argv.indexOf("--commit-sha");
  verifyPlanningPerformance({ commitSha: process.argv[at + 1] })
    .then((result) => console.log(JSON.stringify(result)))
    .catch((error) => {
      console.error(redactAtlasStagingDiagnostic(error.message));
      process.exitCode = 1;
    });
}
