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
const APPROVED_COUNT_POLICIES = new Map([
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
]);

export function planningCloseoutPoliciesAccepted(rows) {
  if (!Array.isArray(rows) || rows.length !== 15) return false;
  const seen = new Set();
  for (const row of rows) {
    if (seen.has(row.unit_code)) return false;
    seen.add(row.unit_code);
    if (row.unit_code === "kg") {
      if (
        row.unit_name !== "Kilogram" ||
        row.dimension_code !== "MASS" ||
        row.unit_status !== "ACTIVE" ||
        row.planning_step !== 0.01 ||
        row.effective_from !== "2026-01-01" ||
        row.effective_to !== null ||
        row.policy_revision_status !== "ACTIVE" ||
        row.revision_number !== 1
      )
        return false;
    } else if (
      row.unit_name !== APPROVED_COUNT_POLICIES.get(row.unit_code) ||
      row.dimension_code !== "COUNT" ||
      row.unit_status !== "ACTIVE" ||
      row.planning_step !== 1 ||
      row.effective_from !== "2026-09-14" ||
      row.effective_to !== null ||
      row.policy_revision_status !== "ACTIVE" ||
      row.revision_number !== 1
    )
      return false;
  }
  return (
    seen.size === 15 &&
    [...APPROVED_COUNT_POLICIES.keys()].every((code) => seen.has(code)) &&
    seen.has("kg")
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

export function classifyPlanningCheckpoint(snapshot) {
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

export function classifyPlanningCloseoutBaseline(snapshot) {
  if (!planningCloseoutPoliciesAccepted(snapshot?.policies))
    throw new Error("PLANNING_CLOSEOUT_BASELINE_REJECTED");
  return classifyPlanningCheckpoint(snapshot);
}

function requireProtectedPlanningCloseoutBaseline(snapshot) {
  const baseline = classifyPlanningCloseoutBaseline(snapshot);
  if (baseline.mode !== "PRISTINE_GENERATED_RESUME")
    throw new Error("PLANNING_CLOSEOUT_RESUME_REQUIRED");
  return baseline;
}

export async function startProtectedPlanningBrowserCloseout(
  snapshot,
  browserJourney,
) {
  return browserJourney(requireProtectedPlanningCloseoutBaseline(snapshot));
}

export function planningCloseoutSnapshotSql() {
  const approvedUnitCodes = [...APPROVED_COUNT_POLICIES.keys(), "kg"]
    .map((code) => `'${code}'`)
    .join(",");
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
  'policies', (select coalesce(jsonb_agg(jsonb_build_object(
    'unit_code', u.unit_code, 'unit_name', u.unit_name,
    'dimension_code', u.dimension_code, 'unit_status', u.unit_status,
    'planning_step', r.planning_step, 'effective_from', r.effective_from,
    'effective_to', r.effective_to, 'policy_revision_status', r.policy_revision_status,
    'revision_number', r.revision_number) order by u.unit_code, r.revision_number), '[]'::jsonb)
    from atlas_admin.units u
    left join atlas_planning.planning_quantity_policies p on p.unit_id=u.unit_id
    left join atlas_planning.planning_quantity_policy_revisions r on r.planning_quantity_policy_id=p.planning_quantity_policy_id
      and r.policy_revision_status='ACTIVE'
    where u.unit_code in (${approvedUnitCodes})
      or (u.dimension_code='COUNT' and (u.unit_status='ACTIVE' or r.policy_revision_status='ACTIVE'))),
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
    baseline?.mode !== "PRISTINE_GENERATED_RESUME" ||
    !planningCloseoutPoliciesAccepted(state?.policies) ||
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
    baseline.runId !== run.id ||
    baseline.batchId !== batch.id ||
    !preflightAccepted(state.preflight, "CURRENT", run.id, batch.id) ||
    state.preflight.current_need.confirmed_need_batch_version !== 2 ||
    !browser?.batchId ||
    browser.batchId !== batch.id ||
    browser.generateClicks !== 0 ||
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
  const baseline = requireProtectedPlanningCloseoutBaseline(
    await readSnapshot(),
  );
  const baselineFingerprints = baseline.fingerprints;
  if (!persist)
    return {
      status: "read-only-checkpoint-pass",
      mode: baseline.mode,
      retainedBatches: 1,
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
    const browser = await startProtectedPlanningBrowserCloseout(
      await readSnapshot(),
      async (beforeBrowser) => {
        if (
          beforeBrowser.runId !== baseline.runId ||
          beforeBrowser.batchId !== baseline.batchId ||
          !sameJson(beforeBrowser.fingerprints, baselineFingerprints)
        )
          throw new Error("PLANNING_CLOSEOUT_CHECKPOINT_CHANGED");
        const { verifyPlanningBrowser } =
          await import("./staging-planning-browser.mjs");
        return verifyPlanningBrowser({
          target,
          baseline: beforeBrowser,
          session: data.session,
          readReview,
          nextCent,
        });
      },
    );
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
