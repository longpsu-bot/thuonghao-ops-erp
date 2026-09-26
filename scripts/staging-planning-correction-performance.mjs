import { isDeepStrictEqual } from "node:util";
import {
  planningCloseoutSnapshotSql,
  classifyPlanningCheckpoint,
  classifyPlanningGenerationReceipts,
} from "./verify-staging-planning-closeout.mjs";

export const MAX_TIMEOUT_UTILIZATION = 0.75;
export const CORRECTION_OPERATOR_TARGET_MS = 4000;

export function summarizeCorrectionPerformance(samples, timeout) {
  if (typeof timeout !== "number" || !Number.isFinite(timeout) || timeout <= 0)
    throw new Error("CORRECTION_TIMEOUT_POLICY_REJECTED");
  if (
    !Array.isArray(samples) ||
    samples.length < 3 ||
    samples.some((x) => typeof x !== "number" || !Number.isFinite(x) || x <= 0)
  )
    throw new Error("CORRECTION_SAMPLES_REJECTED");
  const sorted = [...samples].sort((a, b) => a - b);
  const max = sorted.at(-1);
  if (max > timeout * MAX_TIMEOUT_UTILIZATION)
    throw new Error("CORRECTION_TIMEOUT_HEADROOM_REJECTED");
  return {
    effective_statement_timeout_ms: timeout,
    max_timeout_utilization: MAX_TIMEOUT_UTILIZATION,
    derived_ceiling_ms: timeout * MAX_TIMEOUT_UTILIZATION,
    samples_server_ms: samples,
    min_server_ms: sorted[0],
    p50_server_ms: sorted[Math.ceil(sorted.length * 0.5) - 1],
    max_server_ms: max,
    timeout_utilization_max: max / timeout,
    timeout_headroom_ms: timeout - max,
    timeout_headroom_percent: ((timeout - max) / timeout) * 100,
    operator_target_ms: CORRECTION_OPERATOR_TARGET_MS,
    operator_target_met: max <= CORRECTION_OPERATOR_TARGET_MS,
  };
}

export function correctionRollbackSql(request) {
  const literal = JSON.stringify(request).replaceAll("'", "''");
  return `begin;
set local lock_timeout='2s';
-- SET ROLE alone does not apply ALTER ROLE settings. Resolve PostgreSQL's
-- database+role > role > database precedence, then apply that exact policy.
create temp table correction_timeout_policy as
select split_part(setting,'=',2) setting
from pg_catalog.pg_db_role_setting config
cross join lateral unnest(config.setconfig) setting
where setting like 'statement_timeout=%'
 and config.setrole in (0,(select oid from pg_catalog.pg_roles where rolname='authenticated'))
 and config.setdatabase in (0,(select oid from pg_catalog.pg_database where datname=current_database()))
order by (config.setrole<>0) desc,(config.setdatabase<>0) desc limit 1;
do $policy$ begin
 if not exists(select 1 from correction_timeout_policy) then raise exception 'CORRECTION_TIMEOUT_POLICY_MISSING'; end if;
 -- A function-local timeout would make the role-derived policy ambiguous.
 if exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace,
   lateral unnest(p.proconfig) c where n.nspname in ('atlas_api','atlas_core','atlas_planning') and c like 'statement_timeout=%') then
   raise exception 'CORRECTION_FUNCTION_TIMEOUT_POLICY_REJECTED'; end if;
 perform set_config('statement_timeout',(select setting from correction_timeout_policy),true);
 if (select setting::numeric from pg_settings where name='statement_timeout')<=0 then raise exception 'CORRECTION_TIMEOUT_DISABLED'; end if;
end $policy$;
alter table correction_timeout_policy add column timeout_ms numeric;
update correction_timeout_policy set timeout_ms=(select setting::numeric from pg_settings where name='statement_timeout');
grant select on correction_timeout_policy to authenticated;
create temp table correction_probe(response jsonb,started timestamptz,server_ms numeric,timeout_ms numeric);
grant select,insert,update on correction_probe to authenticated;
set local request.jwt.claims='{"sub":"a1010000-0000-4000-8000-000000000101","role":"authenticated"}';
set local role authenticated;
with start as materialized(select clock_timestamp() at,timeout_ms from correction_timeout_policy),
result as materialized(select at,timeout_ms,atlas_api.execute_need_generation('${literal}'::jsonb) response from start)
insert into correction_probe(response,started,timeout_ms)
select response,at,timeout_ms from result;
-- Existing component SET LOCAL calls do not change the running statement's
-- timer, but can change later statements. Preserve the policy captured BEFORE
-- the public RPC and restore it for the explicit deferred-constraint flush.
select set_config('statement_timeout',(select setting from correction_timeout_policy),true);
set constraints all immediate;
update correction_probe set server_ms=1000*extract(epoch from clock_timestamp()-started);
reset role;
create temp table correction_checkpoint as ${planningCloseoutSnapshotSql()
    .trim()
    .replace(/^begin read only;\s*/, "")
    .replace(/;\s*rollback;$/, "")};
select jsonb_build_object('response',response,'server_ms',server_ms,'effective_statement_timeout_ms',timeout_ms,
 'checkpoint',checkpoint) probe from correction_probe cross join correction_checkpoint;
rollback;`;
}

export async function certifyCorrectionRollback({
  readSnapshot,
  runProbe,
  makeRequest,
}) {
  const before = await readSnapshot();
  const samples = [];
  const endToEnd = [];
  let timeout;
  for (let iteration = 0; iteration < 3; iteration++) {
    const request = makeRequest(before);
    const start = performance.now();
    let probe;
    try {
      probe = await runProbe(request);
    } finally {
      if (!isDeepStrictEqual(before, await readSnapshot()))
        throw new Error("CORRECTION_CHECKPOINT_CHANGED");
    }
    endToEnd.push(performance.now() - start);
    if (
      probe?.response?.success !== true ||
      probe.response.retryable === true ||
      probe.response.error_code
    )
      throw new Error("CORRECTION_ROLLBACK_COMMAND_REJECTED");
    const corrected = classifyPlanningCheckpoint(probe.checkpoint);
    const receipt = classifyPlanningGenerationReceipts(
      probe.checkpoint.receipts,
      corrected.currentRunId,
    )?.correction;
    if (
      corrected.mode !== "D046_CORRECTED_RESUME" ||
      receipt?.command_id !== request.command_id ||
      !isDeepStrictEqual(
        probe.response.affected_aggregate_ids,
        receipt.affected_aggregate_ids,
      ) ||
      !isDeepStrictEqual(probe.response.new_versions, receipt.new_versions) ||
      probe.response.idempotency_status !== "COMPLETED" ||
      !isDeepStrictEqual(
        corrected.fingerprints,
        before.preflight.source_date_fingerprints.selected,
      )
    )
      throw new Error("CORRECTION_ROLLBACK_BUSINESS_PROOF_REJECTED");
    if (
      timeout !== undefined &&
      timeout !== probe.effective_statement_timeout_ms
    )
      throw new Error("CORRECTION_TIMEOUT_POLICY_CHANGED");
    timeout = probe.effective_statement_timeout_ms;
    samples.push(probe.server_ms);
  }
  return {
    status: "D046_CORRECTION_ROLLBACK_PASS",
    ...summarizeCorrectionPerformance(samples, timeout),
    probes: samples.length,
    checkpointPreserved: true,
    businessProof: true,
    correctionBusinessProof: true,
    timeoutPolicyVerified: true,
    end_to_end_ms: endToEnd,
    end_to_end_scope:
      "Management transport, public RPC SQL, in-transaction proof, rollback and independent checkpoint read; server samples exclude transport and proof reads.",
  };
}
