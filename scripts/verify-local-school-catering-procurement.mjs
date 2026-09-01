import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { createClient } from "@supabase/supabase-js";
import {
  readLocalSupabaseStatus,
  runPinnedSupabase,
} from "./local-supabase-status.mjs";

const email = "atlas.pa06b.operator@local.test";
const password = "Atlas-PA06B-local-only!";
const batchId = "b6500000-0000-0000-0000-000000000050";
const supplierA = "c7100000-0000-4000-8000-000000000001";
const supplierB = "c7100000-0000-4000-8000-000000000002";
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function runNodeScript(relativePath, label, environment = {}) {
  const result = spawnSync(
    process.execPath,
    [fileURLToPath(new URL(relativePath, import.meta.url))],
    {
      cwd: process.cwd(),
      env: { ...process.env, ...environment },
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
      shell: false,
    },
  );
  if (result.status !== 0) {
    const diagnostic = `${result.stdout ?? ""}\n${result.stderr ?? ""}`
      .split(/\r?\n/)
      .filter(Boolean)
      .slice(-40)
      .join("\n");
    throw new Error(
      `${label} failed safely.\n${diagnostic || result.error?.message || "No diagnostic output."}`,
    );
  }
  const summary = String(result.stdout ?? "")
    .split(/\r?\n/)
    .filter(Boolean)
    .at(-1);
  if (summary) console.log(summary);
}

function sqlUuid(value, label) {
  assert(uuidPattern.test(String(value)), `${label} is not a safe UUID.`);
  return `'${value}'::uuid`;
}

function installProcurementFixture(ingredientIds) {
  assert(
    ingredientIds.length > 0,
    "No released school-catering ingredients were found.",
  );
  for (const ingredientId of ingredientIds) sqlUuid(ingredientId, "Ingredient");
  install("../supabase/local/school_catering_procurement_verifier_fixture.sql");
}

function releasedIngredientIds() {
  const sql = `select ingredient_id from atlas_planning.confirmed_need_line_revisions
    where confirmed_need_batch_id='${batchId}'::uuid and is_current order by ingredient_id`;
  const output = runPinnedSupabase(
    ["db", "query", "--local", "--agent", "no", "--output", "json", sql],
    { encoding: "utf8", stdio: ["ignore", "pipe", "inherit"] },
  );
  const rows = JSON.parse(output);
  return [...new Set(rows.map((row) => row.ingredient_id))];
}

function install(relativePath) {
  runPinnedSupabase(
    [
      "db",
      "query",
      "--local",
      "--file",
      fileURLToPath(new URL(relativePath, import.meta.url)),
    ],
    { stdio: "ignore" },
  );
}

function verifyPlanningCorrectionBoundaries() {
  for (const testFile of [
    "supabase/tests/school_catering_planning_correction.sql",
    "supabase/tests/school_catering_purchase_orders.sql",
  ]) {
    runPinnedSupabase(["test", "db", testFile, "--local"], {
      stdio: "inherit",
    });
  }
}

async function invoke(client, name, request) {
  const { data, error } = await client
    .schema("atlas_api")
    .rpc(name, { request });
  if (error) {
    throw new Error(
      `${name} transport failed safely (${error.code ?? "UNKNOWN"}).`,
    );
  }
  assert(
    data?.success === true,
    `${name} was rejected (${data?.error_code ?? "UNKNOWN"}).`,
  );
  return data;
}

function command(
  subject,
  reasonCode,
  expectedVersion,
  payload,
  contractVersion,
) {
  const commandId = crypto.randomUUID();
  return {
    contract_version: contractVersion,
    command_id: commandId,
    correlation_id: crypto.randomUUID(),
    idempotency_key: `school-catering:${commandId}`,
    expected_version: expectedVersion,
    requested_by_auth_subject: subject,
    requested_at: new Date(Date.now() - 1000).toISOString(),
    reason_code: reasonCode,
    reason_note: null,
    payload,
  };
}

async function releaseConfirmedNeed(client, subject) {
  const stateOutput = runPinnedSupabase(
    [
      "db",
      "query",
      "--local",
      "--agent",
      "no",
      "--output",
      "json",
      `select count(*)::integer ready_count from atlas_planning.confirmed_need_batches
       where confirmed_need_batch_id='${batchId}'::uuid
         and batch_status='RELEASED_FOR_PURCHASE_HANDOFF'`,
    ],
    { encoding: "utf8", stdio: ["ignore", "pipe", "inherit"] },
  );
  const alreadyReleased =
    Number(JSON.parse(stateOutput)[0]?.ready_count ?? 0) === 1;
  if (alreadyReleased) {
    const existing = await invoke(client, "get_confirmed_need_review", {
      contract_version: "RMVP-05.v1",
      requested_by_auth_subject: subject,
      correlation_id: crypto.randomUUID(),
      payload: {
        confirmed_need_batch_id: batchId,
        filters: {},
        line_offset: 0,
        line_limit: 10000,
      },
    });
    return existing.workbench;
  }
  install("../supabase/local/rmvp_05_browser_fixture.sql");
  install("../supabase/local/rmvp_06_browser_fixture.sql");
  const reviewRequest = {
    contract_version: "RMVP-05.v1",
    requested_by_auth_subject: subject,
    correlation_id: crypto.randomUUID(),
    payload: {
      confirmed_need_batch_id: batchId,
      filters: {},
      line_offset: 0,
      line_limit: 10000,
    },
  };
  const initial = await invoke(
    client,
    "get_confirmed_need_review",
    reviewRequest,
  );
  const lines = initial.workbench.lines
    .filter((line) => line.current_decision_id === null)
    .map((line) => ({
      confirmed_need_line_id: line.confirmed_need_line_id,
      expected_current_revision_id: line.current_revision_id,
      expected_current_decision_id: null,
      proposed_confirmed_quantity: line.proposed_confirmed_quantity,
      reason_code: "PROPOSAL_ACCEPTED",
      reason_note: null,
    }));
  const saved = await invoke(
    client,
    "save_confirmed_needs",
    command(
      subject,
      "CONFIRMED_NEED_SAVED",
      initial.workbench.batch_version,
      { confirmed_need_batch_id: batchId, lines },
      "RMVP-05.v2",
    ),
  );
  const released = await invoke(
    client,
    "release_confirmed_needs",
    command(
      subject,
      "CONFIRMED_NEED_RELEASED",
      saved.authoritative_readback.batch_version,
      { confirmed_need_batch_id: batchId },
      "RMVP-07.v2",
    ),
  );
  assert(
    released.authoritative_readback.batch_status ===
      "RELEASED_FOR_PURCHASE_HANDOFF",
    "Confirmed Need prerequisite did not reach released status.",
  );
  return released.authoritative_readback;
}

function quantityParts(value) {
  const [whole, fraction = ""] = String(value).split(".");
  const micros =
    BigInt(whole) * 1_000_000n + BigInt(fraction.padEnd(6, "0").slice(0, 6));
  const first = (micros * 60n) / 100n;
  const second = micros - first;
  const format = (amount) =>
    `${amount / 1_000_000n}.${String(amount % 1_000_000n).padStart(6, "0")}`;
  return [format(first), format(second)];
}

async function main() {
  const { apiUrl, browserKey } = readLocalSupabaseStatus();
  verifyPlanningCorrectionBoundaries();
  runNodeScript(
    "./provision-local-atlas-identity.mjs",
    "local identity provisioning",
  );
  const client = createClient(apiUrl, browserKey, {
    db: { schema: "atlas_api" },
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  });
  const { data: signIn, error } = await client.auth.signInWithPassword({
    email,
    password,
  });
  assert(!error && signIn.session, "School-catering verifier sign-in failed.");
  const subject = signIn.session.user.id;
  const workbench = await releaseConfirmedNeed(client, subject);
  installProcurementFixture(releasedIngredientIds());

  const handoff = await invoke(
    client,
    "release_school_catering_purchase_handoff",
    command(
      subject,
      "SCHOOL_CATERING_PURCHASE_HANDOFF_RELEASED",
      workbench.batch_version,
      { confirmed_need_batch_id: batchId },
      "SCHOOL-CATERING-HANDOFF.v1",
    ),
  );
  assert(
    handoff.affected_aggregate_ids.purchase_demand_reference_ids.length > 0,
    "Handoff release returned no NEED_GENERATION demand references.",
  );

  const readRequest = {
    contract_version: "SCHOOL-CATERING-PROCUREMENT.v1",
    requested_by_auth_subject: subject,
    correlation_id: crypto.randomUUID(),
    payload: {
      date_start: workbench.service_period.period_start,
      date_end: workbench.service_period.period_end,
      school_ids: [],
      states: [],
      search: null,
    },
  };
  let readback = await invoke(
    client,
    "get_school_catering_procurement_workbench",
    readRequest,
  );
  const row = readback.rows[0];
  assert(
    row?.state === "UNALLOCATED" && row.recommendation?.split_ratio === 1,
    "Workbench did not return the uncommitted 100% priority recommendation.",
  );

  const candidates = readback.rows.map((item) => {
    const candidate = {
      ...item.family,
      expected_family_version: item.family.version,
      expected_source_fingerprint: item.family.source_fingerprint,
    };
    delete candidate.family_id;
    delete candidate.version;
    delete candidate.source_fingerprint;
    return candidate;
  });
  const confirmed = await invoke(
    client,
    "confirm_school_catering_supplier_recommendations",
    command(
      subject,
      "SCHOOL_CATERING_SUPPLIER_RECOMMENDATIONS_CONFIRMED",
      1,
      { candidates },
      "SCHOOL-CATERING-PROCUREMENT.v1",
    ),
  );
  assert(
    confirmed.confirmed.length === candidates.length &&
      confirmed.skipped.length === 0,
    "The explicit 100% supplier recommendations were not all confirmed.",
  );

  readback = await invoke(
    client,
    "get_school_catering_procurement_workbench",
    readRequest,
  );
  const recommended = readback.rows.find(
    (item) => item.family.family_id === confirmed.confirmed[0].family_id,
  );
  assert(
    recommended?.state === "BALANCED" && recommended.family.version === 1,
    "Recommendation readback is not balanced at family version 1.",
  );
  const [quantityA, quantityB] = quantityParts(recommended.family_quantity);
  const manual = await invoke(
    client,
    "save_school_catering_supplier_allocation",
    command(
      subject,
      "SCHOOL_CATERING_SUPPLIER_ALLOCATION_SAVED",
      1,
      {
        family: {
          service_date: recommended.family.service_date,
          delivery_location_id: recommended.family.delivery_location_id,
          ingredient_id: recommended.family.ingredient_id,
          unit_id: recommended.family.unit_id,
          expected_source_fingerprint: recommended.family.source_fingerprint,
        },
        splits: [
          { supplier_id: supplierA, allocated_quantity: quantityA },
          { supplier_id: supplierB, allocated_quantity: quantityB },
        ],
      },
      "SCHOOL-CATERING-PROCUREMENT.v1",
    ),
  );
  assert(
    manual.family.family_version === 2,
    "Manual split did not create family version 2.",
  );

  readback = await invoke(
    client,
    "get_school_catering_procurement_workbench",
    readRequest,
  );
  const finalRow = readback.rows.find(
    (item) => item.family.family_id === manual.family.family_id,
  );
  assert(
    finalRow?.state === "BALANCED" && finalRow.splits.length === 2,
    "Final manual split readback is not balanced with two suppliers.",
  );
  assert(
    finalRow.splits.some(
      (split) =>
        split.supplier_id === supplierA && Number(split.split_ratio) === 0.6,
    ),
    "Final readback does not retain the server-calculated 60% split.",
  );
  assert(
    finalRow.splits.some(
      (split) =>
        split.supplier_id === supplierB && Number(split.split_ratio) === 0.4,
    ),
    "Final readback does not retain the server-calculated 40% split.",
  );

  assert(
    readback.rows.every((item) => item.state === "BALANCED"),
    "Not every family is balanced before PO draft materialization.",
  );
  const poDate = finalRow.service_date;
  const drafts = await invoke(
    client,
    "create_school_catering_purchase_order_drafts",
    command(
      subject,
      "SCHOOL_CATERING_PO_DRAFTS_CREATED",
      1,
      { date_start: poDate, date_end: poDate },
      "SCHOOL-CATERING-PROCUREMENT.v1",
    ),
  );
  assert(
    drafts.created_purchase_order_ids.length >= 2 &&
      drafts.ready_dates.includes(poDate) &&
      drafts.skipped_dates.length === 0,
    "Supplier/date PO drafts were not materialized from every balanced family.",
  );

  const poReadRequest = {
    contract_version: "SCHOOL-CATERING-PROCUREMENT.v1",
    requested_by_auth_subject: subject,
    correlation_id: crypto.randomUUID(),
    payload: {
      date_start: poDate,
      date_end: poDate,
      supplier_ids: [],
      statuses: [],
      search: null,
    },
  };
  let purchaseOrders = await invoke(
    client,
    "get_school_catering_purchase_orders",
    poReadRequest,
  );
  const draft = purchaseOrders.purchase_orders.find(
    (purchaseOrder) =>
      purchaseOrder.supplier.supplier_id === supplierA &&
      purchaseOrder.release_eligible,
  );
  assert(
    draft?.status === "DRAFT" && draft.document_number === null,
    "Authoritative PO readback did not expose a releasable unnumbered DRAFT.",
  );
  const releasedPo = await invoke(
    client,
    "release_school_catering_purchase_order",
    command(
      subject,
      "SCHOOL_CATERING_PO_RELEASED",
      draft.version,
      {
        purchase_order_id: draft.purchase_order_id,
        expected_purchase_order_revision_id:
          draft.current_revision.purchase_order_revision_id,
      },
      "SCHOOL-CATERING-PROCUREMENT.v1",
    ),
  );
  assert(
    /^PO-\d{8}-[0-9A-F]{16}$/.test(releasedPo.document_number),
    "PO release did not return the deterministic backend-generated number.",
  );
  purchaseOrders = await invoke(
    client,
    "get_school_catering_purchase_orders",
    poReadRequest,
  );
  const releasedReadback = purchaseOrders.purchase_orders.find(
    (purchaseOrder) =>
      purchaseOrder.purchase_order_id === draft.purchase_order_id,
  );
  assert(
    releasedReadback?.status === "RELEASED_TO_SUPPLIER" &&
      releasedReadback.export_ready === true &&
      releasedReadback.document_number === releasedPo.document_number,
    "Authoritative PO readback did not retain the released number/export state.",
  );
  await client.auth.signOut({ scope: "local" });
  console.log(
    "Verified D-042 correction gates and removed-Handoff-family PO regeneration through public allocation/draft commands, plus authenticated Handoff, balanced allocation, PO draft, backend number release, and authoritative readback.",
  );
}

try {
  await main();
} catch (error) {
  console.error(
    error instanceof Error
      ? error.message
      : "School-catering Procurement verification failed safely.",
  );
  process.exitCode = 1;
}
