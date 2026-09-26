import { isDeepStrictEqual } from "node:util";
import {
  planningCloseoutSnapshotSql,
  classifyPlanningCheckpoint,
  classifyPlanningGenerationReceipts,
} from "./verify-staging-planning-closeout.mjs";

export const PROTECTED_STATEMENT_TIMEOUT_MS = 60000;
export const NORMAL_AUTHENTICATED_STATEMENT_TIMEOUT_MS = 8000;

function timingSummary(samples, prefix, timeout) {
  if (
    !Array.isArray(samples) ||
    samples.length < 3 ||
    samples.some((x) => typeof x !== "number" || !Number.isFinite(x) || x < 0)
  )
    throw new Error("CORRECTION_SAMPLES_REJECTED");
  const sorted = [...samples].sort((a, b) => a - b);
  if (sorted.at(-1) >= timeout)
    throw new Error("CORRECTION_STATEMENT_TIMEOUT_REJECTED");
  return {
    [`${prefix}_samples_ms`]: samples,
    [`${prefix}_min_ms`]: sorted[0],
    [`${prefix}_p50_ms`]: sorted[Math.ceil(sorted.length * 0.5) - 1],
    [`${prefix}_max_ms`]: sorted.at(-1),
  };
}

export function summarizeCorrectionPerformance(
  rpc,
  flush,
  timeout,
  normalTimeout,
) {
  if (
    timeout !== PROTECTED_STATEMENT_TIMEOUT_MS ||
    normalTimeout !== NORMAL_AUTHENTICATED_STATEMENT_TIMEOUT_MS
  )
    throw new Error("CORRECTION_TIMEOUT_POLICY_REJECTED");
  if (rpc?.length !== flush?.length)
    throw new Error("CORRECTION_SAMPLES_REJECTED");
  return {
    execution_policy: "PROTECTED_MAINTENANCE",
    protected_statement_timeout_ms: timeout,
    effective_protected_statement_timeout_ms: timeout,
    normal_authenticated_statement_timeout_ms: normalTimeout,
    ...timingSummary(rpc, "rpc", timeout),
    ...timingSummary(flush, "constraint_flush", timeout),
  };
}

// Privileged transport sets policy only. The public command still resolves
// the existing synthetic authenticated Actor, capabilities and forced RLS.
function correctionTransactionSql(request, protectedMaintenance = true) {
  const literal = JSON.stringify(request).replaceAll("'", "''");
  const policy = protectedMaintenance ? "60s" : "8s";
  return `begin;
set local lock_timeout='2s';
set local row_security=on;
create temp table correction_timeout_policy on commit drop as
select split_part(setting,'=',2) setting
from pg_catalog.pg_db_role_setting config
cross join lateral unnest(config.setconfig) setting
where setting like 'statement_timeout=%'
 and config.setrole in (0,(select oid from pg_catalog.pg_roles where rolname='authenticated'))
 and config.setdatabase in (0,(select oid from pg_catalog.pg_database where datname=current_database()))
order by (config.setrole<>0) desc,(config.setdatabase<>0) desc limit 1;
do $policy$ begin
 if not exists(select 1 from correction_timeout_policy) then raise exception 'CORRECTION_TIMEOUT_POLICY_MISSING'; end if;
 if exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace,
   lateral unnest(p.proconfig) c where n.nspname in ('atlas_api','atlas_core','atlas_planning') and c like 'statement_timeout=%') then
   raise exception 'CORRECTION_FUNCTION_TIMEOUT_POLICY_REJECTED'; end if;
 perform set_config('statement_timeout',(select setting from correction_timeout_policy),true);
 if (select setting::numeric from pg_settings where name='statement_timeout')<>8000 then raise exception 'CORRECTION_NORMAL_TIMEOUT_POLICY_REJECTED'; end if;
end $policy$;
alter table correction_timeout_policy add column normal_timeout_ms numeric;
update correction_timeout_policy set normal_timeout_ms=(select setting::numeric from pg_settings where name='statement_timeout');
grant select on correction_timeout_policy to authenticated;
create temp table correction_probe(response jsonb,rpc_ms numeric,constraint_flush_ms numeric,timeout_ms numeric,invocation_role text,invocation_subject text) on commit drop;
grant select,insert,update on correction_probe to authenticated;
set local statement_timeout='${policy}';
set local request.jwt.claims='{"sub":"a1010000-0000-4000-8000-000000000101","role":"authenticated"}';
set local role authenticated;
with start as materialized(select clock_timestamp() at,
 (select setting::numeric from pg_settings where name='statement_timeout') timeout_ms,
 current_user::text invocation_role,auth.uid()::text invocation_subject),
result as materialized(select at,timeout_ms,invocation_role,invocation_subject,
 atlas_api.execute_need_generation('${literal}'::jsonb) response from start)
insert into correction_probe(response,rpc_ms,timeout_ms,invocation_role,invocation_subject)
select response,1000*extract(epoch from clock_timestamp()-at),timeout_ms,invocation_role,invocation_subject from result;
-- Nested commands may change SET LOCAL for subsequent statements. Restore
-- the approved policy before the separate deferred-constraint statement.
set local statement_timeout='${policy}';
do $flush$ declare started timestamptz:=clock_timestamp(); begin
 set constraints all immediate;
 update correction_probe set constraint_flush_ms=1000*extract(epoch from clock_timestamp()-started);
end $flush$;
reset role;
set local statement_timeout='${policy}';`;
}

function rollbackSql(request, protectedMaintenance) {
  return `${correctionTransactionSql(request, protectedMaintenance)}
create temp table correction_checkpoint on commit drop as ${planningCloseoutSnapshotSql()
    .trim()
    .replace(/^begin read only;\s*/, "")
    .replace(/;\s*rollback;$/, "")};
select jsonb_build_object('response',response,'rpc_ms',rpc_ms,'constraint_flush_ms',constraint_flush_ms,
 'effective_statement_timeout_ms',timeout_ms,'normal_authenticated_statement_timeout_ms',normal_timeout_ms,
 'invocation_role',invocation_role,'invocation_subject',invocation_subject,
 'checkpoint',checkpoint) probe from correction_probe cross join correction_checkpoint cross join correction_timeout_policy;
rollback;`;
}
export function correctionRollbackSql(request) {
  return rollbackSql(request, true);
}
// Local normal-generation regression retains the normal 8s policy. Hosted
// Planning Performance continues to use its existing independent runner.
export function normalGenerationRollbackSql(request) {
  return rollbackSql(request, false);
}

export function correctionPersistenceSql(request) {
  return `${correctionTransactionSql(request)}
do $outcome$ begin
 if not exists(select 1 from correction_probe where response->>'success'='true'
   and coalesce(response->>'retryable','false')='false'
   and nullif(response->>'error_code','') is null
   and response->>'idempotency_status'='COMPLETED') then
   raise exception 'D046_CORRECTION_COMMAND_REJECTED';
 end if;
end $outcome$;
select response from correction_probe;
commit;`;
}

export async function certifyCorrectionRollback({
  readSnapshot,
  runProbe,
  makeRequest,
}) {
  const before = await readSnapshot();
  const samples = [],
    flush = [],
    endToEnd = [];
  let timeout, normalTimeout;
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
      probe.invocation_role !== "authenticated" ||
      probe.invocation_subject !== request.requested_by_auth_subject
    )
      throw new Error("CORRECTION_AUTHENTICATED_IDENTITY_REJECTED");
    timeout = probe.effective_statement_timeout_ms;
    normalTimeout = probe.normal_authenticated_statement_timeout_ms;
    if (timeout !== 60000 || normalTimeout !== 8000)
      throw new Error("CORRECTION_TIMEOUT_POLICY_REJECTED");
    samples.push(probe.rpc_ms);
    flush.push(probe.constraint_flush_ms);
  }
  return {
    status: "D046_CORRECTION_ROLLBACK_PASS",
    ...summarizeCorrectionPerformance(samples, flush, timeout, normalTimeout),
    probes: samples.length,
    checkpointPreserved: true,
    businessProof: true,
    correctionBusinessProof: true,
    timeoutPolicyVerified: true,
    end_to_end_samples_ms: endToEnd,
    end_to_end_scope:
      "Management transport, public RPC, deferred flush, in-transaction proof, rollback and independent checkpoint read. RPC and flush are separate SQL statements; their sum is not a statement-timeout gate.",
  };
}
