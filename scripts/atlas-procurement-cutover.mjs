import assert from "node:assert/strict";
import { createHash, randomUUID } from "node:crypto";
import { mkdirSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { createClient } from "@supabase/supabase-js";
import { snapshotSql } from "./hosted-purchase-acceptance.mjs";
import {
  executeAtlasStagingManagementSql,
  validateAtlasStagingPackageProtectedValues,
  redactAtlasStagingDiagnostic,
} from "./atlas-staging-contract.mjs";

export const DATE = "2026-10-12";
export const BATCH = "69661e86-abb3-4bf4-88a5-4717fe18c472";
export const SUBJECT = "a1010000-0000-4000-8000-000000000101";
const MAIN = "a9230321161ce62da3572b3d5ae9f3d78f71ac42";
const COMMAND = "c51a2f96-54ab-400d-94fb-910544949f37";
const ACCEPTED_FACTS = "d55edbee74200aa3e02e8fc94ca8787d";
const ACCEPTED_ROWS = "48e433c45fac665d873103542408a484";
export const OUTPUT = "artifacts/atlas-procurement-cutover";

// PostgreSQL jsonb prints keys by UTF-8 byte length, then byte order.
// Public precision-sensitive quantities are already exact JSON strings.
export function postgresJsonbText(value) {
  if (Array.isArray(value))
    return "[" + value.map(postgresJsonbText).join(", ") + "]";
  if (value && typeof value === "object")
    return (
      "{" +
      Object.keys(value)
        .sort(
          (a, b) =>
            Buffer.byteLength(a) - Buffer.byteLength(b) ||
            Buffer.compare(Buffer.from(a), Buffer.from(b)),
        )
        .map((k) => JSON.stringify(k) + ": " + postgresJsonbText(value[k]))
        .join(", ") +
      "}"
    );
  return JSON.stringify(value);
}
export function rowsDigest(rows) {
  return createHash("md5")
    .update(
      postgresJsonbText(
        rows.toSorted((a, b) =>
          a.family.family_id.localeCompare(b.family.family_id),
        ),
      ),
    )
    .digest("hex");
}
export function assertReadAcceptance(result, expected) {
  assert.equal(result.http_status, 200, "HTTP_NOT_200");
  assert.ok(result.elapsed_ms < 8000, "ELAPSED_NOT_UNDER_8_SECONDS");
  const read = result.response;
  assert.equal(read.success, true, "BUSINESS_READ_FAILED");
  assert.equal(read.rows.length, 236, "ROW_COUNT");
  assert.equal(
    new Set(read.rows.map((r) => r.family.family_id)).size,
    236,
    "DUPLICATE_FAMILY",
  );
  assert.equal(
    new Set(
      read.rows.map((r) =>
        [
          r.service_date,
          r.delivery_location_id,
          r.ingredient_id,
          r.unit_id,
        ].join(":"),
      ),
    ).size,
    236,
    "DUPLICATE_OPERATIONAL_IDENTITY",
  );
  assert.deepEqual(
    read.rows.map((r) => r.family.family_id).sort(),
    expected.families.toSorted(),
    "EXACT_FAMILY_SET",
  );
  assert.ok(
    read.rows.every(
      (r) =>
        r.complete &&
        r.state === "BALANCED" &&
        r.family.source_kind === "PURCHASE_HANDOFF" &&
        r.family.source_confirmed_need_batch_id === BATCH &&
        r.source_purchase_handoff_revision_id,
    ),
    "CURRENT_HANDOFF_AUTHORITY",
  );
  assert.deepEqual(
    read.preparation,
    {
      service_date: DATE,
      confirmed_need_batch_id: BATCH,
      expected_version: 5,
      ready: true,
      allowed: true,
      blockers: [],
    },
    "PREPARATION_STATE_VERSION",
  );
  assert.equal(
    rowsDigest(read.rows),
    expected.rows_md5,
    "EXACT_ACCEPTED_IDENTITY_QUANTITY_SUPPLIER_NOTE_LINEAGE",
  );
}
export function assertSnapshotsEqual(before, after) {
  assert.deepEqual(
    after,
    before,
    "READ_CREATED_OR_CHANGED_FACTS_RECEIPTS_EVENTS_AUDIT",
  );
}
export async function management(target, query) {
  assert.ok(
    query.startsWith("begin read only;") &&
      query.trimEnd().endsWith("rollback;"),
    "READ_ONLY_SQL_REQUIRED",
  );
  const result = JSON.parse(
    await executeAtlasStagingManagementSql(target, query),
  );
  assert.equal(result.length, 1, "EVIDENCE_SHAPE");
  return result[0].evidence;
}
export async function snapshot(target) {
  const state = await management(
    target,
    snapshotSql(COMMAND).replace(
      ") as evidence;",
      ") - 'receipt' - 'current_allocations' as evidence;",
    ),
  );
  const ledger = await management(
    target,
    `begin read only;
    select jsonb_build_object(
    'receipts',(select jsonb_build_object('count',count(*),'digest',md5(jsonb_agg(to_jsonb(r) order by command_receipt_id)::text)) from atlas_core.command_receipts r),
    'events',(select jsonb_build_object('count',count(*),'digest',md5(jsonb_agg(to_jsonb(r) order by domain_event_id)::text)) from atlas_audit.domain_events r),
    'audit',(select jsonb_build_object('count',count(*),'digest',md5(jsonb_agg(to_jsonb(r) order by audit_event_id)::text)) from atlas_audit.audit_events r),
    'suppliers',(select jsonb_build_object('count',count(*),'digest',md5(jsonb_agg(to_jsonb(r) order by supplier_id)::text)) from atlas_admin.suppliers r)
    ) as evidence; rollback;`,
  );
  return { state, ledger };
}
export function assertAcceptedState(before) {
  assert.equal(
    before.state.fact_digest,
    ACCEPTED_FACTS,
    "ACCEPTED_FACTS_DRIFT",
  );
  assert.deepEqual(before.state.batch, {
    state: "RELEASED_FOR_PURCHASE_HANDOFF",
    version: 5,
  });
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
    assert.equal(before.state[key], value, key);
}
export function saveEvidence(evidence) {
  mkdirSync(OUTPUT, { recursive: true });
  writeFileSync(OUTPUT + "/evidence.json", JSON.stringify(evidence, null, 2));
}
async function main() {
  const evidence = {
    main_sha: MAIN,
    phase: "PREFLIGHT",
    phase_a: { status: "NOT_RUN" },
    phase_b: { status: "NOT_RUN" },
    business_commands_sent: 0,
  };
  let target;
  try {
    assert.equal(process.env.ATLAS_ACCEPTANCE_MAIN_SHA, MAIN, "MAIN_SHA");
    target = validateAtlasStagingPackageProtectedValues(process.env);
    evidence.metadata = await management(
      target,
      `begin read only;
      select jsonb_build_object(
        'migration_count',(select count(*) from supabase_migrations.schema_migrations),
        'tip',(select max(version) from supabase_migrations.schema_migrations),
        'authenticated_config',(select to_jsonb(rolconfig) from pg_roles where rolname='authenticated'),
        'families',(select jsonb_agg(family_id order by family_id) from atlas_procurement.school_catering_allocation_families where service_date='${DATE}'),
        'jsonb_encoder_probe',jsonb_build_object('long_key','á','z',1,'aa',jsonb_build_array(true,null),'a','x')::text
      ) as evidence; rollback;`,
    );
    assert.equal(evidence.metadata.migration_count, 106);
    assert.equal(evidence.metadata.tip, "20261013102219");
    assert.ok(
      evidence.metadata.authenticated_config.includes("statement_timeout=8s"),
    );
    assert.equal(
      evidence.metadata.jsonb_encoder_probe,
      postgresJsonbText({ long_key: "á", z: 1, aa: [true, null], a: "x" }),
    );
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
    evidence.authenticated_subject = data.session.user.id;
    evidence.before = await snapshot(target);
    assertAcceptedState(evidence.before);
    evidence.phase = "PHASE_A_HTTP";
    const request = {
      contract_version: "CONFIRMED-SUPPLIER-ALLOCATION.v1",
      requested_by_auth_subject: SUBJECT,
      correlation_id: randomUUID(),
      payload: { date_start: DATE, date_end: DATE },
    };
    saveEvidence(evidence);
    const started = performance.now();
    const http = await fetch(
      target.supabaseUrl +
        "/rest/v1/rpc/get_confirmed_supplier_allocation_workbench",
      {
        method: "POST",
        headers: {
          apikey: target.publishableKey,
          Authorization: "Bearer " + data.session.access_token,
          "Content-Type": "application/json",
          "Content-Profile": "atlas_api",
          Accept: "application/json",
        },
        body: JSON.stringify({ request }),
      },
    );
    const raw = await http.text();
    evidence.phase_a = {
      http_status: http.status,
      elapsed_ms: performance.now() - started,
      response: JSON.parse(raw),
      status: "VALIDATING",
    };
    saveEvidence(evidence);
    evidence.after_phase_a = await snapshot(target);
    saveEvidence(evidence);
    assertSnapshotsEqual(evidence.before, evidence.after_phase_a);
    assertReadAcceptance(evidence.phase_a, {
      families: evidence.metadata.families,
      rows_md5: ACCEPTED_ROWS,
    });
    evidence.phase_a.status = "PASS";
    evidence.phase_a.rows_md5 = rowsDigest(evidence.phase_a.response.rows);
    evidence.phase_a.row_count = evidence.phase_a.response.rows.length;
    evidence.phase_a.fact_delta = 0;
    evidence.phase_a.receipt_event_audit_delta = 0;
    evidence.phase = "PHASE_A_COMPLETE";
    saveEvidence(evidence);
    console.log(
      JSON.stringify({
        phase_a: "PASS",
        http_status: http.status,
        elapsed_ms: evidence.phase_a.elapsed_ms,
        row_count: 236,
        rows_md5: evidence.phase_a.rows_md5,
        fact_delta: 0,
        receipt_event_audit_delta: 0,
      }),
    );
  } catch (error) {
    evidence.task_status = "STOPPED";
    evidence.failure = {
      message: redactAtlasStagingDiagnostic(
        error?.message ?? String(error),
        target ? Object.values(target) : [],
      ),
      stack: redactAtlasStagingDiagnostic(
        error?.stack ?? "",
        target ? Object.values(target) : [],
      ),
    };
    if (target && evidence.before && !evidence.after_phase_a) {
      try {
        evidence.after_phase_a = await snapshot(target);
      } catch {
        evidence.snapshot_recovery = "FAILED";
      }
    }
    evidence.phase_a.status =
      evidence.phase_a.status === "NOT_RUN" ? "NOT_RUN" : "FAIL";
    saveEvidence(evidence);
    console.error(
      JSON.stringify({
        phase: evidence.phase,
        http_status: evidence.phase_a.http_status,
        elapsed_ms: evidence.phase_a.elapsed_ms,
        failure: evidence.failure.message,
      }),
    );
    process.exitCode = 1;
  }
}
if (process.argv[1] === fileURLToPath(import.meta.url)) await main();
