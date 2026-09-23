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
export const PLANNING_PERFORMANCE_PROBES = Object.freeze([
  { date: "2026-09-14", expectedLineCount: 232 },
  { date: "2026-09-14", expectedLineCount: 232 },
  { date: "2026-09-15", expectedLineCount: 225 },
  { date: "2026-09-16", expectedLineCount: 213 },
  { date: "2026-09-18", expectedLineCount: 210 },
]);

export function planningPerformanceProbeAccepted(row, expectedLineCount) {
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
    row.editing_allowed === true,
  );
}

export function rollbackProbeSql(date) {
  if (!PLANNING_PERFORMANCE_PROBES.some((probe) => probe.date === date))
    throw new Error("UNAPPROVED_PROBE_DATE");
  return `begin; set local lock_timeout='2s'; set local statement_timeout='8s';
create temp table planning_performance_probe_result(r jsonb, generation_ms numeric);
grant select, insert on planning_performance_probe_result to authenticated;
set local request.jwt.claims='{"sub":"${SUBJECT}","role":"authenticated"}';
set local role authenticated;
with started as materialized(select clock_timestamp() as at,gen_random_uuid() as id),
generated as materialized(select at,atlas_api.execute_need_generation(jsonb_build_object(
 'contract_version','RMVP-04.v3','command_id',id,'correlation_id',gen_random_uuid(),
 'idempotency_key','planning-performance-probe:'||id,'expected_version',1,
 'requested_by_auth_subject','${SUBJECT}','requested_at',now(),
 'reason_code','NEED_GENERATION_EXECUTED','reason_note','Owner-approved rollback-only Staging performance certification.',
 'payload',jsonb_build_object('service_date','${date}','expected_current_need_generation_run_id',null))) r from started)
insert into planning_performance_probe_result
select r,1000*extract(epoch from clock_timestamp()-at) as generation_ms from generated;
-- The STABLE review needs its own statement to see the materialized batch.
with reviewed as materialized(select r,generation_ms,case when r->>'success'='true' then
 atlas_api.get_confirmed_need_review(jsonb_build_object('contract_version','RMVP-05.v1',
 'requested_by_auth_subject','${SUBJECT}','correlation_id',gen_random_uuid(),
 'payload',jsonb_build_object('confirmed_need_batch_id',r#>'{affected_aggregate_ids,confirmed_need_batch_id}',
 'filters',jsonb_build_object('service_date','${date}'),'line_offset',0,'line_limit',10000))) else null end as review from planning_performance_probe_result)
select jsonb_build_object('date','${date}','success',r->'success','error_code',r->>'error_code',
 'generation_ms',generation_ms,'currentness',r#>>'{authoritative_readback,preflight,downstream_currentness}',
 'review_success',review->'success','review_error_code',review->>'error_code','line_count',jsonb_array_length(review#>'{workbench,lines}'),
 'has_more',review#>'{workbench,pagination,has_more}',
 'blocker_count',jsonb_array_length(review#>'{workbench,blockers}'),
 'editing_allowed',review#>'{workbench,editing_allowed}') as probe from reviewed;
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
  for (const { date, expectedLineCount } of PLANNING_PERFORMANCE_PROBES) {
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
    if (!planningPerformanceProbeAccepted(row, expectedLineCount))
      throw new Error("GENERATION_PERFORMANCE_BLOCKED");
  }
  return {
    status: "GENERATION_PERFORMANCE_PASS",
    probes: PLANNING_PERFORMANCE_PROBES.length,
    checkpointPreserved: true,
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
