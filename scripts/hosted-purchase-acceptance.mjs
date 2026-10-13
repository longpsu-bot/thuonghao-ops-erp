import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { isDeepStrictEqual } from "node:util";
import { createClient } from "@supabase/supabase-js";
import {
  executeAtlasStagingManagementSql,
  validateAtlasStagingPackageProtectedValues,
} from "./atlas-staging-contract.mjs";

const DATE = "2026-10-12";
const BATCH = "69661e86-abb3-4bf4-88a5-4717fe18c472";
const SUBJECT = "a1010000-0000-4000-8000-000000000101";

export function assertPreflight(state, read) {
  assert.deepEqual(state.batch, { state: "DRAFT_REVIEW", version: 2 });
  for (const key of ["allocations", "handoffs", "po_roots", "po_lines"])
    assert.equal(state[key], 0, key);
  assert.equal(read.success, true);
  assert.equal(read.rows.length, 236);
  assert.ok(
    read.rows.every(
      (row) =>
        row.complete &&
        /^0*\d+[.]\d+$/.test(row.family_quantity) &&
        /[1-9]/.test(row.family_quantity) &&
        row.recommendation?.supplier_id,
    ),
  );
  assert.equal(
    new Set(read.rows.map((row) => row.recommendation.supplier_id)).size,
    17,
  );
  assert.deepEqual(read.preparation, {
    ready: true,
    allowed: true,
    blockers: [],
    service_date: DATE,
    expected_version: 2,
    confirmed_need_batch_id: BATCH,
  });
}

export async function executeAcceptance({
  request,
  evidence,
  save,
  rpc,
  snapshot,
  validate,
  replayOnly = false,
}) {
  evidence.request = request;
  evidence.status = "COMMAND_INTENT_RECORDED";
  save();
  try {
    if (replayOnly)
      assert.equal(
        evidence.first?.response?.success,
        true,
        "NO_CONFIRMED_ORIGINAL_SUCCESS",
      );
    else evidence.first = await rpc(request);
  } catch {
    evidence.status = "UNKNOWN_OUTCOME";
    save();
    try {
      evidence.recovery = await snapshot();
    } finally {
      save();
    }
    throw new Error("UNKNOWN_OUTCOME_NO_NEW_COMMAND");
  }
  save();
  const after = await snapshot();
  if (replayOnly)
    assert.equal(
      after.fact_digest,
      evidence.after.fact_digest,
      "ORIGINAL_FACTS_CHANGED",
    );
  evidence.after = after;
  save();
  if (evidence.first.response.success !== true) {
    evidence.status = "PUBLIC_COMMAND_FAILED";
    save();
  }
  assert.equal(evidence.first.response.success, true, "PUBLIC_COMMAND_FAILED");
  // Replay is safe only after a confirmed successful result and authoritative readback.
  validate(evidence.after);
  evidence.status = "REPLAY_INTENT_RECORDED";
  save();
  try {
    evidence.replay = await rpc(request);
  } catch {
    evidence.status = "UNKNOWN_REPLAY_OUTCOME";
    save();
    try {
      evidence.recovery = await snapshot();
    } finally {
      save();
    }
    throw new Error("UNKNOWN_REPLAY_OUTCOME_NO_NEW_COMMAND");
  }
  save();
  evidence.final = await snapshot();
  save();
  assert.ok(
    isDeepStrictEqual(evidence.first.response, evidence.replay.response),
    "REPLAY_RESPONSE_DELTA",
  );
  assert.ok(
    isDeepStrictEqual(evidence.after, evidence.final),
    "REPLAY_FACT_DELTA",
  );
  assert.ok(evidence.first.elapsed_ms < 20000, "PUBLIC_ELAPSED_OVER_20S");
  evidence.status = "HOSTED_ACCEPTANCE_PASS";
  save();
}

export function snapshotSql(commandId) {
  assert.match(commandId, /^[0-9a-f-]{36}$/);
  return `begin read only;
with f as (select * from atlas_procurement.school_catering_allocation_families where service_date='${DATE}'),
r as (select v.* from atlas_procurement.school_catering_allocation_family_revisions v join f using(family_id)),
s as (select v.* from atlas_procurement.school_catering_allocation_supplier_splits v join r using(family_revision_id)),
c as (select v.* from atlas_procurement.school_catering_allocation_family_contributions v join r using(family_revision_id)),
p as (select * from atlas_procurement.purchase_orders where school_catering_service_date='${DATE}'),
pr as (select v.* from atlas_procurement.purchase_order_revisions v join p using(purchase_order_id)),
pl as (select v.* from atlas_procurement.purchase_order_lines v join p using(purchase_order_id)),
lr as (select v.* from atlas_procurement.purchase_order_line_revisions v join pr using(purchase_order_revision_id)),
h as (select * from atlas_planning.purchase_handoff_batches where confirmed_need_batch_id='${BATCH}'),
hr as (select v.* from atlas_planning.purchase_handoff_revisions v join h using(purchase_handoff_batch_id)),
hl as (select v.* from atlas_planning.purchase_handoff_lines v join h using(purchase_handoff_batch_id)),
hlr as (select v.* from atlas_planning.purchase_handoff_line_revisions v join hl using(purchase_handoff_line_id)),
facts as (
select 'families' k, to_jsonb(f) v from f union all select 'revisions',to_jsonb(r) from r
union all select 'splits',to_jsonb(s) from s union all select 'contributions',to_jsonb(c) from c
union all select 'orders',to_jsonb(p) from p union all select 'po_revisions',to_jsonb(pr) from pr
union all select 'po_lines',to_jsonb(pl) from pl union all select 'po_line_revisions',to_jsonb(lr) from lr
union all select 'handoffs',to_jsonb(h) from h union all select 'handoff_revisions',to_jsonb(hr) from hr
union all select 'handoff_lines',to_jsonb(hl) from hl union all select 'handoff_line_revisions',to_jsonb(hlr) from hlr
union all select 'batch',to_jsonb(b) from atlas_planning.confirmed_need_batches b where confirmed_need_batch_id='${BATCH}'
union all select 'receipts',to_jsonb(v) from atlas_core.command_receipts v
union all select 'domain_events',to_jsonb(v) from atlas_audit.domain_events v
union all select 'audit_events',to_jsonb(v) from atlas_audit.audit_events v)
select jsonb_build_object(
'batch',(select jsonb_build_object('state',batch_status,'version',version) from atlas_planning.confirmed_need_batches where confirmed_need_batch_id='${BATCH}'),
'allocations',(select count(*) from f),'allocation_revisions',(select count(*) from r),
'priority_defaults',(select count(*) from r where source_kind='CONFIRMED_NEED' and source_confirmed_need_batch_id='${BATCH}' and decision_origin='PRIORITY_RECOMMENDATION'),
'manual_defaults',(select count(*) from r where decision_origin='MANUAL'),
'promoted_families',(select count(*) from r where is_current and source_kind='PURCHASE_HANDOFF' and decision_origin='PRIORITY_RECOMMENDATION'),
'handoffs',(select count(*) from h),'released_handoffs',(select count(*) from h where handoff_status='RELEASED_TO_PROCUREMENT'),
'po_roots',(select count(*) from p),'draft_pos',(select count(*) from p where purchase_order_status='DRAFT'),
'po_lines',(select count(*) from lr),'po_suppliers',(select count(distinct supplier_id) from p),
'receipt',(select to_jsonb(v) from atlas_core.command_receipts v where command_id='${commandId}'),
'fact_digest',(select md5(coalesce(jsonb_agg(jsonb_build_object('table',k,'row',v) order by k,v::text)::text,'')) from facts),
'fact_count',(select count(*) from facts),
'current_allocations',(select coalesce(jsonb_agg(jsonb_build_object('ingredient_id',f.ingredient_id,'unit_id',f.unit_id,'delivery_location_id',f.delivery_location_id,'quantity',r.family_quantity::text,'supplier_id',s.supplier_id) order by f.ingredient_id,f.unit_id,f.delivery_location_id),'[]') from f join r using(family_id) join s using(family_revision_id) where r.is_current),
'invalid_lineage',(select count(*) from r current_revision left join r predecessor on predecessor.family_revision_id=current_revision.predecessor_revision_id
 where current_revision.is_current and (predecessor.source_kind is distinct from 'CONFIRMED_NEED' or predecessor.source_confirmed_need_batch_id is distinct from '${BATCH}'::uuid or predecessor.source_confirmed_need_batch_version is distinct from 2 or predecessor.command_id is distinct from '${commandId}'::uuid or current_revision.command_id is distinct from (select (response_payload->'handoff'->>'command_id')::uuid from atlas_core.command_receipts where command_id='${commandId}') or predecessor.family_quantity is distinct from current_revision.family_quantity or current_revision.source_purchase_handoff_revision_id is null or current_revision.source_confirmed_need_batch_id is not null)),
'invalid_quantities',(select count(*) from r where is_current and (family_quantity is distinct from (select sum(allocated_quantity) from s where s.family_revision_id=r.family_revision_id) or family_quantity is distinct from (select sum(contribution_quantity) from c where c.family_revision_id=r.family_revision_id) or (select count(*) from s where s.family_revision_id=r.family_revision_id)<>1)),
'invalid_po_lines',(select count(*) from lr left join s on s.supplier_split_id=lr.school_catering_allocation_supplier_split_id left join r using(family_revision_id) left join f using(family_id) join pr using(purchase_order_revision_id) join p using(purchase_order_id) where s.supplier_split_id is null or r.is_current is distinct from true or lr.ordered_quantity is distinct from s.allocated_quantity or p.supplier_id is distinct from s.supplier_id or lr.ingredient_id is distinct from f.ingredient_id or lr.unit_id is distinct from f.unit_id or lr.delivery_location_id is distinct from f.delivery_location_id or lr.service_date is distinct from f.service_date)
) as evidence;
rollback;`;
}

function validateResult(state) {
  for (const [key, value] of Object.entries({
    allocations: 236,
    allocation_revisions: 472,
    priority_defaults: 236,
    manual_defaults: 0,
    promoted_families: 236,
    handoffs: 1,
    released_handoffs: 1,
    po_roots: 17,
    draft_pos: 17,
    po_lines: 236,
    po_suppliers: 17,
    invalid_lineage: 0,
    invalid_quantities: 0,
    invalid_po_lines: 0,
  }))
    assert.equal(state[key], value, key);
  assert.equal(state.batch.state, "RELEASED_FOR_PURCHASE_HANDOFF");
  assert.equal(state.receipt?.outcome, "COMPLETED");
  assert.equal(state.receipt?.response_payload?.success, true);
}

async function main() {
  const replayOnly = Boolean(process.env.ATLAS_ACCEPTANCE_REPLAY_RUN_ID);
  const evidence = replayOnly
    ? JSON.parse(
        readFileSync(
          "artifacts/hosted-purchase-original/evidence.json",
          "utf8",
        ),
      )
    : { main_sha: process.env.ATLAS_ACCEPTANCE_MAIN_SHA };
  assert.equal(evidence.main_sha, process.env.ATLAS_ACCEPTANCE_MAIN_SHA);
  mkdirSync("artifacts/hosted-purchase-acceptance", { recursive: true });
  const save = () =>
    writeFileSync(
      "artifacts/hosted-purchase-acceptance/evidence.json",
      JSON.stringify(evidence, null, 2),
    );
  let intentLogged = false;
  const saveWithIntent = () => {
    save();
    if (evidence.status === "COMMAND_INTENT_RECORDED" && !intentLogged) {
      console.log(JSON.stringify({ command_intent: evidence.request }));
      intentLogged = true;
    }
  };
  try {
    const target = validateAtlasStagingPackageProtectedValues(process.env);
    assert.equal(target.projectRef, "rnzxmxiiqgtdevzregff");
    const client = createClient(target.supabaseUrl, target.publishableKey, {
      db: { retry: false },
      auth: {
        autoRefreshToken: false,
        persistSession: false,
        detectSessionInUrl: false,
      },
    });
    const { data, error } = await client.auth.signInWithPassword({
      email: target.testEmail,
      password: target.testPassword,
    });
    assert.ok(
      !error && data.session?.user.id === SUBJECT,
      "STAGING_AUTH_SUBJECT_MISMATCH",
    );
    const sql = async (query) => {
      const result = JSON.parse(
        await executeAtlasStagingManagementSql(target, query),
      );
      assert.ok(
        Array.isArray(result) && result.length === 1,
        "MANAGEMENT_EVIDENCE_SHAPE",
      );
      return result[0].evidence;
    };
    const metadata = await sql(
      `begin read only; select jsonb_build_object('migration_count',(select count(*) from supabase_migrations.schema_migrations),'tip',(select max(version) from supabase_migrations.schema_migrations),'proconfig',(select to_jsonb(proconfig) from pg_proc where oid='atlas_api.prepare_school_catering_purchase_orders(jsonb)'::regprocedure)) as evidence; rollback;`,
    );
    evidence.metadata = metadata;
    save();
    assert.equal(metadata.migration_count, 105);
    assert.equal(metadata.tip, "20261013082420");
    assert.deepEqual(
      [...metadata.proconfig].sort(),
      ['search_path=""', "statement_timeout=20s"].sort(),
    );
    const { data: publicRead, error: readError } = await client
      .schema("atlas_api")
      .rpc("get_confirmed_supplier_allocation_workbench", {
        request: {
          contract_version: "CONFIRMED-SUPPLIER-ALLOCATION.v1",
          correlation_id: randomUUID(),
          requested_by_auth_subject: SUBJECT,
          payload: { date_start: DATE, date_end: DATE },
        },
      })
      .retry(false);
    assert.ok(!readError, "PUBLIC_PREFLIGHT_READ_FAILED");
    const read = replayOnly ? evidence.preflight_read : publicRead;
    const commandId = replayOnly ? evidence.request.command_id : randomUUID();
    if (!replayOnly) {
      evidence.preflight_read = read;
      evidence.before = await sql(snapshotSql(commandId));
      save();
      assertPreflight(evidence.before, read);
    }
    const request = replayOnly
      ? evidence.request
      : {
          contract_version: "PURCHASE-COMMITMENT.v1",
          command_id: commandId,
          correlation_id: randomUUID(),
          idempotency_key: `purchase-preparation:${commandId}`,
          expected_version: 2,
          requested_by_auth_subject: SUBJECT,
          requested_at: new Date().toISOString(),
          reason_code: "PURCHASE_ORDERS_PREPARED",
          reason_note: null,
          payload: { service_date: DATE, confirmed_need_batch_id: BATCH },
        };
    assert.equal(request.contract_version, "PURCHASE-COMMITMENT.v1");
    assert.equal(request.requested_by_auth_subject, SUBJECT);
    assert.equal(request.expected_version, 2);
    assert.equal(request.reason_code, "PURCHASE_ORDERS_PREPARED");
    assert.equal(request.idempotency_key, `purchase-preparation:${commandId}`);
    assert.deepEqual(request.payload, {
      service_date: DATE,
      confirmed_need_batch_id: BATCH,
    });
    if (replayOnly) {
      assert.equal(evidence.first.http_status, 200);
      assert.equal(evidence.first.response.success, true);
      const current = await sql(snapshotSql(commandId));
      assert.equal(current.receipt.command_id, commandId);
      assert.deepEqual(
        current.receipt.response_payload,
        evidence.first.response,
        "RECEIPT_ORIGINAL_RESPONSE_MISMATCH",
      );
      evidence.original_run_id = process.env.ATLAS_ACCEPTANCE_REPLAY_RUN_ID;
    }
    const rpc = async (request) => {
      const started = performance.now();
      const response = await fetch(
        `${target.supabaseUrl}/rest/v1/rpc/prepare_school_catering_purchase_orders`,
        {
          method: "POST",
          headers: {
            apikey: target.publishableKey,
            Authorization: `Bearer ${data.session.access_token}`,
            "Content-Type": "application/json",
            "Content-Profile": "atlas_api",
            Accept: "application/json",
          },
          body: JSON.stringify({ request }),
          signal: AbortSignal.timeout(45000),
        },
      );
      const text = await response.text();
      const elapsed_ms = performance.now() - started;
      let body;
      try {
        body = JSON.parse(text);
      } catch {
        throw new Error("UNKNOWN_RESPONSE");
      }
      // PostgREST SQL errors prove rollback; other HTTP failures need authoritative recovery.
      if (
        !response.ok &&
        !/^(57014|P\d{4}|[234]\w{4}|55P03)$/.test(body.code ?? "")
      )
        throw new Error("UNKNOWN_HTTP_OUTCOME");
      return { elapsed_ms, http_status: response.status, response: body };
    };
    await executeAcceptance({
      request,
      evidence,
      replayOnly,
      save: saveWithIntent,
      rpc,
      snapshot: () => sql(snapshotSql(commandId)),
      validate: (state) => {
        validateResult(state);
        const byFamily = (row) =>
          [row.ingredient_id, row.unit_id, row.delivery_location_id].join(":");
        const expected = read.rows.map((row) => ({
          ingredient_id: row.ingredient_id,
          unit_id: row.unit_id,
          delivery_location_id: row.delivery_location_id,
          quantity: row.family_quantity,
          supplier_id: row.recommendation.supplier_id,
        }));
        const sort = (rows) =>
          rows.toSorted((a, b) => byFamily(a).localeCompare(byFamily(b)));
        assert.deepEqual(
          sort(state.current_allocations),
          sort(expected),
          "EXACT_PREFLIGHT_QUANTITY_SUPPLIER_DELTA",
        );
      },
    });
    console.log(
      JSON.stringify({
        status: evidence.status,
        command_id: commandId,
        elapsed_ms: evidence.first.elapsed_ms,
        replay_elapsed_ms: evidence.replay.elapsed_ms,
        fact_digest: evidence.final.fact_digest,
      }),
    );
  } catch {
    if (
      evidence.first?.response?.success &&
      evidence.status === "COMMAND_INTENT_RECORDED"
    )
      evidence.status = "READBACK_VALIDATION_FAILED";
    evidence.status = evidence.status ?? "PREFLIGHT_FAILED";
    save();
    console.error(
      `Hosted acceptance stopped safely: ${evidence.status}. Inspect protected evidence; do not issue another command.`,
    );
    process.exitCode = 1;
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) await main();
