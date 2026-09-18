import { fileURLToPath } from "node:url";
import { createClient } from "@supabase/supabase-js";
import {
  executeAtlasStagingManagementSql,
  validateAtlasStagingPackageProtectedValues,
  redactAtlasStagingDiagnostic,
} from "./atlas-staging-contract.mjs";
import { verifyPackageCheckout } from "./install-atlas-staging-package.mjs";

const SUBJECT = "a1010000-0000-4000-8000-000000000101";
const DAYS = [
  "2026-09-14",
  "2026-09-15",
  "2026-09-16",
  "2026-09-17",
  "2026-09-18",
];
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
set local request.jwt.claims='{"sub":"${SUBJECT}","role":"authenticated"}';
set local role authenticated;
with started as materialized(select clock_timestamp() as at,gen_random_uuid() as id),
generated as materialized(select at,atlas_api.execute_need_generation(jsonb_build_object(
 'contract_version','RMVP-04.v3','command_id',id,'correlation_id',gen_random_uuid(),
 'idempotency_key','planning-closeout-probe:'||id,'expected_version',1,
 'requested_by_auth_subject','${SUBJECT}','requested_at',now(),
 'reason_code','NEED_GENERATION_EXECUTED','reason_note','Owner-approved rollback-only Staging closeout verification.',
 'payload',jsonb_build_object('service_date','${date}','expected_current_need_generation_run_id',null))) r from started),
measured as materialized(select r,1000*extract(epoch from clock_timestamp()-at) as generation_ms from generated),
reviewed as materialized(select r,generation_ms,case when r->>'success'='true' then
 atlas_api.get_confirmed_need_review(jsonb_build_object('contract_version','RMVP-05.v1',
 'requested_by_auth_subject','${SUBJECT}','correlation_id',gen_random_uuid(),
 'payload',jsonb_build_object('confirmed_need_batch_id',r#>'{affected_aggregate_ids,confirmed_need_batch_id}',
 'filters',jsonb_build_object('service_date','${date}'),'line_offset',0,'line_limit',10000))) else null end as review from measured)
select jsonb_build_object('date','${date}','success',r->'success','error_code',r->>'error_code',
 'generation_ms',generation_ms,'currentness',r#>>'{authoritative_readback,preflight,downstream_currentness}',
 'review_success',review->'success','line_count',jsonb_array_length(review#>'{workbench,lines}'),
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
  const baseline = (
    await sql(
      `begin read only; select count(*)::int as batches from atlas_planning.confirmed_need_batches where period_start between '2026-09-14' and '2026-09-18'; rollback;`,
    )
  )[0];
  if (baseline?.batches !== 0)
    throw new Error("REHEARSAL_ALREADY_PERSISTED_REVIEW_REQUIRED");
  for (const date of ["2026-09-17", "2026-09-17", ...DAYS]) {
    const row = (await sql(rollbackProbeSql(date)))[0]?.probe;
    console.log(JSON.stringify({ rollback_probe: row }));
    if (
      !row?.success ||
      !row.review_success ||
      row.currentness !== "CURRENT" ||
      row.has_more ||
      row.blocker_count !== 0 ||
      !row.editing_allowed ||
      row.generation_ms >= 8000
    )
      throw new Error("HOSTED_PLANNING_ACCEPTANCE_FAILED");
    if (date === "2026-09-17" && row.line_count !== 248)
      throw new Error("REAL_DAY_RECONCILIATION_MISMATCH");
  }
  const after = (
    await sql(
      `begin read only; select count(*)::int as batches from atlas_planning.confirmed_need_batches where period_start between '2026-09-14' and '2026-09-18'; rollback;`,
    )
  )[0];
  if (after?.batches !== 0) throw new Error("ROLLBACK_VERIFICATION_FAILED");
  if (!persist)
    return { status: "rollback-verification-pass", retainedBatches: 0 };
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
    const id = (
      await sql(
        `begin read only; select confirmed_need_batch_id from atlas_planning.confirmed_need_batches where period_start='2026-09-17' and period_end='2026-09-17'; rollback;`,
      )
    )[0]?.confirmed_need_batch_id;
    if (!id) return null;
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
    const { verifyPlanningBrowser } =
      await import("./staging-planning-browser.mjs");
    return await verifyPlanningBrowser({
      target,
      session: data.session,
      readReview,
      nextCent,
    });
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
