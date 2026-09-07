import { spawnSync } from "node:child_process";
import { saveLocalConfirmedAllocations } from "./local-confirmed-supplier-allocation.mjs";
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
      `select count(*)::integer ready_count from atlas_planning.confirmed_need_batches where confirmed_need_batch_id='${batchId}'::uuid and batch_status='RELEASED_FOR_PURCHASE_HANDOFF'`,
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
  await saveLocalConfirmedAllocations(
    client,
    subject,
    saved.authoritative_readback,
    invoke,
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

function quantityMicros(value) {
  assert(
    typeof value === "string" && /^\d+(?:\.\d{1,6})?$/.test(value),
    "Expected an exact public quantity string with at most six decimals.",
  );
  const [whole, fraction = ""] = value.split(".");
  return BigInt(whole) * 1_000_000n + BigInt(fraction.padEnd(6, "0"));
}

function quantityParts(value) {
  const micros = quantityMicros(value);
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
  const sourceRequest = {
    ...readRequest,
    contract_version: "CONFIRMED-SUPPLIER-ALLOCATION.v1",
  };
  const beforeHandoff = await invoke(
    client,
    "get_confirmed_supplier_allocation_workbench",
    sourceRequest,
  );
  const confirmedRows = beforeHandoff.rows.filter(
    (item) => item.family.source_confirmed_need_batch_id === batchId,
  );
  assert(
    confirmedRows.length > 0 &&
      confirmedRows.every(
        (item) =>
          item.state === "BALANCED" &&
          item.family.source_kind === "CONFIRMED_NEED" &&
          item.splits.length > 0,
      ),
    "Handoff prerequisite did not expose persisted Confirmed Need allocations.",
  );

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

  let readback = await invoke(
    client,
    "get_school_catering_procurement_workbench",
    readRequest,
  );
  const afterHandoff = await invoke(
    client,
    "get_confirmed_supplier_allocation_workbench",
    sourceRequest,
  );
  for (const previous of confirmedRows) {
    const current = readback.rows.find(
      (item) => item.family.family_id === previous.family.family_id,
    );
    const source = afterHandoff.rows.find(
      (item) => item.family.family_id === previous.family.family_id,
    );
    const promotion = handoff.allocation_promotions?.find(
      (item) => item.family_id === previous.family.family_id,
    );
    assert(
      current?.state === "BALANCED" &&
        source?.state === "BALANCED" &&
        source.family.source_kind === "PURCHASE_HANDOFF" &&
        current.family.version === previous.family.version + 1 &&
        source.family.version === current.family.version &&
        source.family.source_fingerprint ===
          current.family.source_fingerprint &&
        promotion?.source_kind === "PURCHASE_HANDOFF" &&
        promotion.family_version === current.family.version &&
        promotion.source_fingerprint === current.family.source_fingerprint &&
        uuidPattern.test(promotion.family_revision_id),
      "Handoff did not expose the promoted successor through public readback.",
    );
    assert(
      current.splits.length === previous.splits.length &&
        current.splits.every((split) =>
          previous.splits.some(
            (prior) =>
              prior.supplier_id === split.supplier_id &&
              prior.allocated_quantity === split.allocated_quantity &&
              prior.split_ratio === split.split_ratio &&
              uuidPattern.test(split.supplier_split_id),
          ),
        ) &&
        quantityMicros(current.family_quantity) ===
          quantityMicros(previous.family_quantity) &&
        current.splits.reduce(
          (total, split) => total + quantityMicros(split.allocated_quantity),
          0n,
        ) === quantityMicros(current.family_quantity) &&
        current.recommendation === null &&
        source.recommendation === null &&
        current.allowed_actions.confirm_recommendation === false,
      "Promotion did not preserve the exact persisted supplier allocation.",
    );
  }
  const promoted = readback.rows.find(
    (item) => item.family.family_id === confirmedRows[0].family.family_id,
  );
  const beforeVersion = promoted.family.version;
  const [quantityA, quantityB] = quantityParts(promoted.family_quantity);
  const manual = await invoke(
    client,
    "save_school_catering_supplier_allocation",
    command(
      subject,
      "SCHOOL_CATERING_SUPPLIER_ALLOCATION_SAVED",
      beforeVersion,
      {
        family: {
          service_date: promoted.family.service_date,
          delivery_location_id: promoted.family.delivery_location_id,
          ingredient_id: promoted.family.ingredient_id,
          unit_id: promoted.family.unit_id,
          expected_source_fingerprint: promoted.family.source_fingerprint,
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
    manual.family.family_version === beforeVersion + 1,
    "Manual split did not advance the current family version exactly once.",
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
    finalRow?.state === "BALANCED" &&
      finalRow.family.version === beforeVersion + 1 &&
      finalRow.splits.length === 2,
    "Final manual split readback is not balanced with two suppliers.",
  );
  assert(
    finalRow.splits.some(
      (split) =>
        split.supplier_id === supplierA &&
        split.allocated_quantity === quantityA &&
        split.split_ratio === "0.600000000000",
    ),
    "Final readback does not retain the server-calculated 60% split.",
  );
  assert(
    finalRow.splits.some(
      (split) =>
        split.supplier_id === supplierB &&
        split.allocated_quantity === quantityB &&
        split.split_ratio === "0.400000000000",
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
  for (const [supplierId, quantity] of [
    [supplierA, quantityA],
    [supplierB, quantityB],
  ]) {
    const order = purchaseOrders.purchase_orders.find(
      (item) => item.supplier.supplier_id === supplierId,
    );
    const line = order?.lines.find(
      (item) => item.source.family_id === manual.family.family_id,
    );
    const split = finalRow.splits.find(
      (item) => item.supplier_id === supplierId,
    );
    assert(
      order?.status === "DRAFT" &&
        line?.ordered_quantity === quantity &&
        line.source.family_revision_id === manual.family.family_revision_id &&
        line.source.supplier_split_id === split.supplier_split_id,
      "Supplier PO did not consume the current exact post-Handoff allocation.",
    );
  }
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
    `Verified D-042 correction gates and removed-Handoff-family PO regeneration, ${confirmedRows.length} preserved/promoted allocations, exact manual 60/40 edit at family version ${beforeVersion} -> ${manual.family.family_version}, current-split PO drafts, backend number release, and authoritative readback.`,
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
