import { fileURLToPath } from "node:url";
import { createClient } from "@supabase/supabase-js";
import {
  executeAtlasStagingManagementSql,
  validateAtlasStagingPackageProtectedValues,
  redactAtlasStagingDiagnostic,
} from "./atlas-staging-contract.mjs";
import { verifyPackageCheckout } from "./install-atlas-staging-package.mjs";

const SUBJECT = "a1010000-0000-4000-8000-000000000101";
const SYNTHETIC_ACTOR = "a1010000-0000-4000-8000-000000000001";
const RETAINED_RUN = "0c83b440-8fb2-4a77-9735-804ef4c89ea0";
const RETAINED_BATCH = "a0311e0a-a4de-48b9-a529-fe7464a3352b";
const DAYS = [
  "2026-09-14",
  "2026-09-15",
  "2026-09-16",
  "2026-09-17",
  "2026-09-18",
];
export const PLANNING_CLOSEOUT_GENERATION_MAX_MS = 7000;
export function planningCloseoutProbeDates(mode) {
  if (mode === "ZERO_BASELINE") return ["2026-09-17", "2026-09-17", ...DAYS];
  if (mode === "PRISTINE_GENERATED_RESUME")
    return DAYS.filter((date) => date !== "2026-09-17");
  throw new Error("PLANNING_CLOSEOUT_BASELINE_REJECTED");
}
export function planningCloseoutProbeAccepted(row) {
  return Boolean(
    row?.success &&
    row.review_success &&
    row.currentness === "CURRENT" &&
    !row.has_more &&
    row.blocker_count === 0 &&
    row.editing_allowed &&
    Number.isFinite(row.generation_ms) &&
    row.generation_ms < PLANNING_CLOSEOUT_GENERATION_MAX_MS,
  );
}
function canonicalJson(value) {
  if (Array.isArray(value)) return value.map(canonicalJson);
  if (value && typeof value === "object")
    return Object.fromEntries(
      Object.keys(value)
        .sort()
        .map((key) => [key, canonicalJson(value[key])]),
    );
  return value;
}
const sameJson = (left, right) =>
  JSON.stringify(canonicalJson(left)) === JSON.stringify(canonicalJson(right));
const exactDate = (item) =>
  item?.period_start === "2026-09-17" && item?.period_end === "2026-09-17";
function preflightAccepted(preflight, currentness, runId, batchId) {
  const source = preflight?.source_date_fingerprints;
  const keys = ["attendance", "pantry", "weekly_menu"];
  return (
    preflight?.readiness_state === "READY" &&
    preflight.downstream_currentness === currentness &&
    preflight.blocking_issue_count === 0 &&
    source?.service_date === "2026-09-17" &&
    sameJson(Object.keys(source.selected ?? {}).sort(), keys) &&
    keys.every(
      (key) =>
        typeof source.selected[key] === "string" &&
        source.selected[key].length > 0,
    ) &&
    sameJson(source.selected, source.current) &&
    (runId
      ? preflight.current_need?.need_generation_run_id === runId &&
        preflight.current_need?.confirmed_need_batch_id === batchId &&
        preflight.current_need?.need_generation_run_version === 3 &&
        preflight.current_need?.confirmed_need_batch_version >= 1
      : preflight.current_need == null)
  );
}
function generationReceiptAccepted(receipts, run, batch) {
  const receipt = receipts?.[0];
  return (
    receipts?.length === 1 &&
    receipt.command_name === "execute_need_generation" &&
    receipt.actor_id === SYNTHETIC_ACTOR &&
    receipt.outcome === "COMPLETED" &&
    receipt.success === true &&
    receipt.affected_aggregate_ids?.need_generation_run_id === run.id &&
    receipt.affected_aggregate_ids?.confirmed_need_batch_id === batch.id &&
    receipt.new_versions?.need_generation_run_version === 3 &&
    receipt.new_versions?.confirmed_need_batch_version === 1
  );
}

export function classifyPlanningCloseoutBaseline(snapshot) {
  const fail = () => {
    throw new Error("PLANNING_CLOSEOUT_BASELINE_REJECTED");
  };
  if (
    !Array.isArray(snapshot?.runs) ||
    !Array.isArray(snapshot?.batches) ||
    !Array.isArray(snapshot?.receipts) ||
    snapshot.handoffs !== 0 ||
    snapshot.save_receipt_count !== 0
  )
    fail();
  if (snapshot.runs.length === 0 && snapshot.batches.length === 0) {
    if (
      snapshot.receipts.length !== 0 ||
      !preflightAccepted(snapshot.preflight, "NOT_GENERATED", null, null)
    )
      fail();
    return {
      mode: "ZERO_BASELINE",
      runId: null,
      batchId: null,
      fingerprints: snapshot.preflight.source_date_fingerprints.selected,
    };
  }
  if (
    snapshot.runs.length !== 1 ||
    snapshot.batches.length !== 1 ||
    snapshot.receipts.length !== 1
  )
    fail();
  const run = snapshot.runs[0];
  const batch = snapshot.batches[0];
  if (
    !exactDate(run) ||
    !exactDate(batch) ||
    run.id !== RETAINED_RUN ||
    batch.id !== RETAINED_BATCH ||
    run.status !== "RELEASED_FOR_CONFIRMATION" ||
    run.version !== 3 ||
    run.generated_line_count !== 304 ||
    run.blocking_issue_count !== 0 ||
    run.warning_count !== 0 ||
    run.actor_id !== SYNTHETIC_ACTOR ||
    batch.status !== "DRAFT_REVIEW" ||
    batch.version !== 1 ||
    batch.source_kind !== "NEED_GENERATION" ||
    batch.origin_run_id !== run.id ||
    batch.current_run_id !== run.id ||
    batch.origin_run_version !== 3 ||
    batch.current_run_version !== 3 ||
    batch.line_count !== 248 ||
    batch.decision_count !== 0 ||
    batch.current_decision_count !== 0 ||
    batch.adjustment_count !== 0 ||
    batch.acceptance_count !== 0 ||
    !preflightAccepted(snapshot.preflight, "CURRENT", run.id, batch.id) ||
    snapshot.preflight.current_need.confirmed_need_batch_version !== 1 ||
    !generationReceiptAccepted(snapshot.receipts, run, batch)
  )
    fail();
  return {
    mode: "PRISTINE_GENERATED_RESUME",
    runId: run.id,
    batchId: batch.id,
    fingerprints: snapshot.preflight.source_date_fingerprints.selected,
  };
}

export function planningCloseoutSnapshotSql() {
  return `begin read only;
with scoped_runs as (
  select * from atlas_planning.need_generation_runs
  where period_start <= '2026-09-20' and period_end >= '2026-09-14'
), scoped_batches as (
  select * from atlas_planning.confirmed_need_batches
  where period_start <= '2026-09-20' and period_end >= '2026-09-14'
), preflight as (
  select atlas_core.planning_contract_01_preflight_payload(
    '2026-09-17'::date, '2026-09-17'::date, null) as payload
)
select jsonb_build_object(
  'runs', (select coalesce(jsonb_agg(jsonb_build_object(
    'id', r.need_generation_run_id, 'period_start', r.period_start,
    'period_end', r.period_end, 'status', r.run_status, 'version', r.version,
    'generated_line_count', r.generated_line_count,
    'blocking_issue_count', r.blocking_issue_count, 'warning_count', r.warning_count,
    'actor_id', r.generated_by_actor_id)), '[]'::jsonb) from scoped_runs r),
  'batches', (select coalesce(jsonb_agg(jsonb_build_object(
    'id', b.confirmed_need_batch_id, 'period_start', b.period_start,
    'period_end', b.period_end, 'status', b.batch_status, 'version', b.version,
    'source_kind', b.source_kind, 'origin_run_id', b.origin_need_generation_run_id,
    'current_run_id', b.current_need_generation_run_id,
    'origin_run_version', b.origin_need_generation_run_version,
    'current_run_version', b.current_need_generation_run_version,
    'line_count', (select count(*) from atlas_planning.confirmed_need_lines l
      where l.confirmed_need_batch_id=b.confirmed_need_batch_id),
    'decision_count', (select count(*) from atlas_planning.confirmed_need_line_decisions d
      where d.confirmed_need_batch_id=b.confirmed_need_batch_id),
    'current_decision_count', (select count(*) from atlas_planning.confirmed_need_lines l
      where l.confirmed_need_batch_id=b.confirmed_need_batch_id
        and l.current_confirmed_need_line_decision_id is not null),
    'adjustment_count', (select count(*) from atlas_planning.confirmed_need_line_decisions d
      where d.confirmed_need_batch_id=b.confirmed_need_batch_id
        and d.confirmed_quantity_after<>d.proposed_quantity_before
        and d.reason_code='OPERATIONAL_QUANTITY_ADJUSTMENT'),
    'acceptance_count', (select count(*) from atlas_planning.confirmed_need_line_decisions d
      where d.confirmed_need_batch_id=b.confirmed_need_batch_id
        and d.confirmed_quantity_after=d.proposed_quantity_before
        and d.reason_code='PROPOSAL_ACCEPTED')
  )), '[]'::jsonb) from scoped_batches b),
  'handoffs', (select count(*) from atlas_planning.purchase_handoff_batches h
    where h.period_start <= '2026-09-20' and h.period_end >= '2026-09-14'),
  'preflight', (select jsonb_build_object(
    'readiness_state', p.payload->'readiness_state',
    'downstream_currentness', p.payload->'downstream_currentness',
    'blocking_issue_count', p.payload->'blocking_issue_count',
    'current_need', p.payload->'current_need',
    'source_date_fingerprints', p.payload->'source_date_fingerprints'
  ) from preflight p),
  'receipts', (select coalesce(jsonb_agg(jsonb_build_object(
    'command_name', c.command_name, 'actor_id', c.actor_id,
    'outcome', c.outcome, 'success', c.response_payload->'success',
    'affected_aggregate_ids', c.response_payload->'affected_aggregate_ids',
    'new_versions', c.response_payload->'new_versions')), '[]'::jsonb)
    from atlas_core.command_receipts c where c.command_name='execute_need_generation'
      and (exists(select 1 from scoped_runs r where
        c.response_payload#>>'{affected_aggregate_ids,need_generation_run_id}'=r.need_generation_run_id::text)
      or exists(select 1 from scoped_batches b where
        c.response_payload#>>'{affected_aggregate_ids,confirmed_need_batch_id}'=b.confirmed_need_batch_id::text))),
  'save_receipt_count', (select count(*) from atlas_core.command_receipts c
    where c.command_name='save_confirmed_needs' and exists(
      select 1 from scoped_batches b where
        c.scope_key like '%:ConfirmedNeedBatch:' || b.confirmed_need_batch_id::text))
) as checkpoint;
rollback;`;
}
export function assertFinalPlanningCloseoutProof({
  baseline,
  browser,
  state,
  review,
  baselineFingerprints,
  finalFingerprints,
}) {
  const fingerprintsMatch =
    baselineFingerprints != null &&
    finalFingerprints != null &&
    sameJson(baselineFingerprints, finalFingerprints) &&
    sameJson(
      finalFingerprints,
      state?.preflight?.source_date_fingerprints?.current,
    );
  const run = state?.runs?.[0];
  const batch = state?.batches?.[0];
  if (
    !["ZERO_BASELINE", "PRISTINE_GENERATED_RESUME"].includes(baseline?.mode) ||
    state?.runs?.length !== 1 ||
    state?.batches?.length !== 1 ||
    state?.handoffs !== 0 ||
    !exactDate(run) ||
    !exactDate(batch) ||
    run.status !== "RELEASED_FOR_CONFIRMATION" ||
    run.version !== 3 ||
    run.generated_line_count !== 304 ||
    run.actor_id !== SYNTHETIC_ACTOR ||
    run.blocking_issue_count !== 0 ||
    run.warning_count !== 0 ||
    batch.status !== "DRAFT_REVIEW" ||
    batch.version !== 2 ||
    batch.source_kind !== "NEED_GENERATION" ||
    batch.origin_run_id !== run.id ||
    batch.current_run_id !== run.id ||
    batch.origin_run_version !== run.version ||
    batch.current_run_version !== run.version ||
    batch.line_count !== 248 ||
    batch.decision_count !== 248 ||
    batch.current_decision_count !== 248 ||
    batch.adjustment_count !== 1 ||
    batch.acceptance_count !== 247 ||
    !generationReceiptAccepted(state.receipts, run, batch) ||
    state.save_receipt_count !== 1 ||
    (baseline.runId && baseline.runId !== run.id) ||
    (baseline.batchId && baseline.batchId !== batch.id) ||
    !preflightAccepted(state.preflight, "CURRENT", run.id, batch.id) ||
    state.preflight.current_need.confirmed_need_batch_version !== 2 ||
    !browser?.batchId ||
    browser.batchId !== batch.id ||
    browser.generateClicks !== (baseline.mode === "ZERO_BASELINE" ? 1 : 0) ||
    browser.saveClicks !== 1 ||
    browser.newDecisions !== 248 ||
    browser.businessQuantityAdjustments !== 1 ||
    browser.proposalAcceptances !== 247 ||
    review?.confirmed_need_batch_id !== browser.batchId ||
    review?.batch_version !== browser.batchVersion ||
    review?.source_kind !== "NEED_GENERATION" ||
    review?.lines?.length !== 248 ||
    review?.pagination?.has_more ||
    review?.blockers?.length !== 0 ||
    !review?.editing_allowed ||
    !fingerprintsMatch
  )
    throw new Error("FINAL_PLANNING_CLOSEOUT_PROOF_FAILED");
  return {
    mode: baseline.mode,
    retainedRuns: state.runs.length,
    retainedBatches: state.batches.length,
    retainedLines: review.lines.length,
    humanDecisions: batch.decision_count,
    currentDecisions: batch.current_decision_count,
    purchaseHandoffs: state.handoffs,
    sourceFingerprintsUnchanged: true,
  };
}
export function nextCent(value) {
  if (!/^\d+(?:\.\d{1,6})?$/.test(value))
    throw new Error("INVALID_EXACT_QUANTITY");
  const [whole, decimal = ""] = value.split(".");
  const ticks =
    BigInt(whole) * 100n + BigInt((decimal + "00").slice(0, 2)) + 1n;
  return `${ticks / 100n}.${String(ticks % 100n).padStart(2, "0")}`;
}
export function rollbackProbeSql(date) {
  if (!DAYS.includes(date)) throw new Error("UNAPPROVED_PROBE_DATE");
  return `begin; set local lock_timeout='2s'; set local statement_timeout='8s';
create temp table planning_closeout_probe_result(r jsonb, generation_ms numeric);
grant select, insert on planning_closeout_probe_result to authenticated;
set local request.jwt.claims='{"sub":"${SUBJECT}","role":"authenticated"}';
set local role authenticated;
with started as materialized(select clock_timestamp() as at,gen_random_uuid() as id),
generated as materialized(select at,atlas_api.execute_need_generation(jsonb_build_object(
 'contract_version','RMVP-04.v3','command_id',id,'correlation_id',gen_random_uuid(),
 'idempotency_key','planning-closeout-probe:'||id,'expected_version',1,
 'requested_by_auth_subject','${SUBJECT}','requested_at',now(),
 'reason_code','NEED_GENERATION_EXECUTED','reason_note','Owner-approved rollback-only Staging closeout verification.',
 'payload',jsonb_build_object('service_date','${date}','expected_current_need_generation_run_id',null))) r from started)
insert into planning_closeout_probe_result
select r,1000*extract(epoch from clock_timestamp()-at) as generation_ms from generated;
-- The STABLE read needs its own statement to see the newly materialized batch.
with reviewed as materialized(select r,generation_ms,case when r->>'success'='true' then
 atlas_api.get_confirmed_need_review(jsonb_build_object('contract_version','RMVP-05.v1',
 'requested_by_auth_subject','${SUBJECT}','correlation_id',gen_random_uuid(),
 'payload',jsonb_build_object('confirmed_need_batch_id',r#>'{affected_aggregate_ids,confirmed_need_batch_id}',
 'filters',jsonb_build_object('service_date','${date}'),'line_offset',0,'line_limit',10000))) else null end as review from planning_closeout_probe_result)
select jsonb_build_object('date','${date}','success',r->'success','error_code',r->>'error_code',
 'generation_ms',generation_ms,'currentness',r#>>'{authoritative_readback,preflight,downstream_currentness}',
 'review_success',review->'success','review_error_code',review->>'error_code','line_count',jsonb_array_length(review#>'{workbench,lines}'),
 'has_more',review#>'{workbench,pagination,has_more}',
 'blocker_count',jsonb_array_length(review#>'{workbench,blockers}'),
 'editing_allowed',review#>'{workbench,editing_allowed}') as probe from reviewed;
rollback;`;
}
export async function verifyPlanningCloseout({
  commitSha,
  persist = false,
  environment = process.env,
} = {}) {
  const target = validateAtlasStagingPackageProtectedValues(environment);
  verifyPackageCheckout({ commitSha });
  const sql = async (query) =>
    JSON.parse(await executeAtlasStagingManagementSql(target, query));
  const readSnapshot = async () =>
    (await sql(planningCloseoutSnapshotSql()))[0]?.checkpoint;
  const baseline = classifyPlanningCloseoutBaseline(await readSnapshot());
  const baselineFingerprints = baseline.fingerprints;
  const probeDates = planningCloseoutProbeDates(baseline.mode);
  for (const date of probeDates) {
    const row = (await sql(rollbackProbeSql(date)))[0]?.probe;
    console.log(JSON.stringify({ rollback_probe: row }));
    if (!planningCloseoutProbeAccepted(row))
      throw new Error("HOSTED_PLANNING_ACCEPTANCE_FAILED");
    if (date === "2026-09-17" && row.line_count !== 248)
      throw new Error("REAL_DAY_RECONCILIATION_MISMATCH");
  }
  const afterProbes = classifyPlanningCloseoutBaseline(await readSnapshot());
  if (
    afterProbes.mode !== baseline.mode ||
    afterProbes.runId !== baseline.runId ||
    afterProbes.batchId !== baseline.batchId ||
    !sameJson(afterProbes.fingerprints, baselineFingerprints)
  )
    throw new Error("ROLLBACK_VERIFICATION_FAILED");
  if (!persist)
    return {
      status: "rollback-verification-pass",
      mode: baseline.mode,
      retainedBatches: baseline.mode === "PRISTINE_GENERATED_RESUME" ? 1 : 0,
    };
  const client = createClient(target.supabaseUrl, target.publishableKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    db: { retry: false },
  });
  const { data, error } = await client.auth.signInWithPassword({
    email: target.testEmail,
    password: target.testPassword,
  });
  if (error || data.user?.id !== SUBJECT || !data.session)
    throw new Error("STAGING_OPERATOR_AUTH_FAILED");
  const readReview = async () => {
    const rows = await sql(
      `begin read only; select confirmed_need_batch_id from atlas_planning.confirmed_need_batches where period_start='2026-09-17' and period_end='2026-09-17'; rollback;`,
    );
    if (
      rows.length !== 1 ||
      (baseline.batchId && rows[0].confirmed_need_batch_id !== baseline.batchId)
    )
      throw new Error("AUTHORITATIVE_BATCH_ID_REJECTED");
    const id = rows[0].confirmed_need_batch_id;
    const result = await client
      .schema("atlas_api")
      .rpc("get_confirmed_need_review", {
        request: {
          contract_version: "RMVP-05.v1",
          requested_by_auth_subject: SUBJECT,
          correlation_id: crypto.randomUUID(),
          payload: {
            confirmed_need_batch_id: id,
            filters: { service_date: "2026-09-17" },
            line_offset: 0,
            line_limit: 10000,
          },
        },
      });
    if (result.error || !result.data?.success)
      throw new Error("AUTHORITATIVE_REVIEW_FAILED");
    return result.data.workbench;
  };
  try {
    const beforeBrowser = classifyPlanningCloseoutBaseline(
      await readSnapshot(),
    );
    if (
      beforeBrowser.mode !== baseline.mode ||
      beforeBrowser.runId !== baseline.runId ||
      beforeBrowser.batchId !== baseline.batchId ||
      !sameJson(beforeBrowser.fingerprints, baselineFingerprints)
    )
      throw new Error("PLANNING_CLOSEOUT_CHECKPOINT_CHANGED");
    const { verifyPlanningBrowser } =
      await import("./staging-planning-browser.mjs");
    const browser = await verifyPlanningBrowser({
      target,
      baseline,
      session: data.session,
      readReview,
      nextCent,
    });
    const state = await readSnapshot();
    const review = await readReview();
    const finalProof = assertFinalPlanningCloseoutProof({
      baseline,
      browser,
      state,
      review,
      baselineFingerprints,
      finalFingerprints: state?.preflight?.source_date_fingerprints?.selected,
    });
    console.log(JSON.stringify({ final_planning_closeout_proof: finalProof }));
    return { ...browser, finalProof };
  } finally {
    client.auth.stopAutoRefresh();
  }
}
if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const at = process.argv.indexOf("--commit-sha");
  verifyPlanningCloseout({
    commitSha: process.argv[at + 1],
    persist: process.argv.includes("--persist-rehearsal"),
  })
    .then((result) => console.log(JSON.stringify(result)))
    .catch((error) => {
      console.error(redactAtlasStagingDiagnostic(error.message));
      process.exitCode = 1;
    });
}
