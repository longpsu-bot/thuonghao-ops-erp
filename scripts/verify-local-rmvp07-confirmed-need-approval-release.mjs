import { fileURLToPath } from "node:url";
import { createClient } from "@supabase/supabase-js";
import {
  readLocalSupabaseStatus,
  runPinnedSupabase,
} from "./local-supabase-status.mjs";

const email = "atlas.pa06b.operator@local.test";
const password = "Atlas-PA06B-local-only!";
const deterministicBatchId = "b6500000-0000-0000-0000-000000000050";
const browserSource = process.env.RMVP07_BROWSER_SOURCE ?? "fixture";
const schemaCacheAttempts = 6;
const schemaCacheDelayMs = 1_500;

function assert(condition, message) {
  if (!condition) throw new Error(message);
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
    { stdio: "inherit" },
  );
}

function readRequest(subject, batchId) {
  return {
    contract_version: "RMVP-05.v1",
    requested_by_auth_subject: subject,
    correlation_id: crypto.randomUUID(),
    payload: {
      confirmed_need_batch_id: batchId,
      filters: {},
      line_offset: 0,
      line_limit: 10_000,
    },
  };
}

function command(subject, workbench, kind, lines) {
  const commandId = crypto.randomUUID();
  return {
    contract_version: kind === "save" ? "RMVP-05.v2" : "RMVP-07.v2",
    command_id: commandId,
    correlation_id: crypto.randomUUID(),
    idempotency_key: `confirmed-need-${kind}:${commandId}`,
    expected_version: workbench.batch_version,
    requested_by_auth_subject: subject,
    requested_at: new Date(Date.now() - 1_000).toISOString(),
    reason_code:
      kind === "save" ? "CONFIRMED_NEED_SAVED" : "CONFIRMED_NEED_RELEASED",
    reason_note: null,
    payload: {
      confirmed_need_batch_id: workbench.confirmed_need_batch_id,
      ...(kind === "save" ? { lines } : {}),
    },
  };
}

async function invoke(client, name, request) {
  for (let attempt = 1; attempt <= schemaCacheAttempts; attempt += 1) {
    const { data, error } = await client
      .schema("atlas_api")
      .rpc(name, { request })
      .retry(false);
    if (!error) {
      assert(data, `D-037 ${name} returned no envelope.`);
      return data;
    }
    if (error.code !== "PGRST002" || attempt === schemaCacheAttempts) {
      throw new Error(
        `D-037 ${name} transport failed safely (${error.code ?? "UNKNOWN"}: ${error.message ?? "no message"}).`,
      );
    }
    await new Promise((resolve) => setTimeout(resolve, schemaCacheDelayMs));
  }
}

async function invokeSuccess(client, name, request) {
  const response = await invoke(client, name, request);
  assert(
    response.success === true,
    `D-037 ${name} was rejected: ${response.error_code ?? "UNKNOWN"} (${response.safe_message ?? "no safe message"}).`,
  );
  return response;
}

async function findMaterializedBatch(client, subject) {
  const candidate = new Date();
  candidate.setUTCHours(0, 0, 0, 0);
  candidate.setUTCDate(
    candidate.getUTCDate() + ((8 - candidate.getUTCDay()) % 7) + 7 * 1040,
  );
  for (let offset = 0; offset < 26; offset += 1) {
    const serviceDate = candidate.toISOString().slice(0, 10);
    const response = await invokeSuccess(
      client,
      "get_need_generation_workbench",
      {
        contract_version: "RMVP-04.v1",
        requested_by_auth_subject: subject,
        correlation_id: crypto.randomUUID(),
        payload: {
          period_start: serviceDate,
          period_end: serviceDate,
          need_generation_run_id: null,
          filters: {},
          group_offset: 0,
          group_limit: 100,
        },
      },
    );
    if (response.workbench.materialization?.confirmed_need_batch_id) {
      return response.workbench.materialization.confirmed_need_batch_id;
    }
    candidate.setUTCDate(candidate.getUTCDate() + 7);
  }
  throw new Error("D-037 could not find the RMVP-04 materialized batch.");
}

function downstreamState() {
  const sql = [
    "select jsonb_build_object(",
    "'purchase_handoff_batches',(select count(*) from atlas_planning.purchase_handoff_batches),",
    "'purchase_handoff_revisions',(select count(*) from atlas_planning.purchase_handoff_revisions),",
    "'purchase_handoff_lines',(select count(*) from atlas_planning.purchase_handoff_lines),",
    "'purchase_handoff_line_revisions',(select count(*) from atlas_planning.purchase_handoff_line_revisions),",
    "'purchase_demand_references',(select count(*) from atlas_planning.purchase_demand_references),",
    "'procurement',(select count(*) from atlas_procurement.fulfilment_allocations),",
    "'warehouse',(select count(*) from atlas_evidence.supplier_receiving_evidence),",
    "'dispatch',(select count(*) from atlas_dispatch.dispatch_plans)",
    ") as downstream_state;",
  ].join(" ");
  const output = runPinnedSupabase(
    ["db", "query", "--local", "--agent", "no", "--output", "json", sql],
    { encoding: "utf8", stdio: ["ignore", "pipe", "inherit"] },
  );
  const rows = JSON.parse(output);
  const state = Array.isArray(rows) ? rows[0]?.downstream_state : null;
  assert(
    state && typeof state === "object",
    "D-037 returned no downstream state.",
  );
  return JSON.stringify(state);
}

async function main() {
  assert(
    browserSource === "fixture" || browserSource === "rmvp04",
    "D-037 browser source must be fixture or rmvp04.",
  );
  const { apiUrl, browserKey } = readLocalSupabaseStatus();
  if (browserSource === "fixture")
    install("../supabase/local/rmvp_05_browser_fixture.sql");
  install("../supabase/local/rmvp_06_browser_fixture.sql");

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
  assert(!error && signIn.session, "D-037 local acceptance sign-in failed.");
  const subject = signIn.session.user.id;
  const batchId =
    browserSource === "fixture"
      ? deterministicBatchId
      : await findMaterializedBatch(client, subject);

  const initialRead = await invokeSuccess(
    client,
    "get_confirmed_need_review",
    readRequest(subject, batchId),
  );
  const initial = initialRead.workbench;
  const lines = initial.lines
    .filter((line) => line.current_decision_id === null)
    .map((line) => ({
      confirmed_need_line_id: line.confirmed_need_line_id,
      expected_current_revision_id: line.current_revision_id,
      expected_current_decision_id: null,
      proposed_confirmed_quantity: line.proposed_confirmed_quantity,
      reason_code: "PROPOSAL_ACCEPTED",
      reason_note: null,
    }));
  assert(lines.length > 0, "D-037 fixture must begin with unsaved decisions.");

  const saveCommand = command(subject, initial, "save", lines);
  const saved = await invokeSuccess(
    client,
    "save_confirmed_needs",
    saveCommand,
  );
  assert(
    saved.contract_version === "RMVP-05.v2" &&
      saved.command_name === "save_confirmed_needs" &&
      saved.idempotency_status === "COMPLETED" &&
      saved.authoritative_readback.batch_status === "DRAFT_REVIEW" &&
      saved.authoritative_readback.editing_allowed === true &&
      saved.authoritative_readback.line_counts.unreviewed === 0,
    "D-037 Save did not persist a complete editable readback.",
  );
  const saveReplay = await invokeSuccess(
    client,
    "save_confirmed_needs",
    saveCommand,
  );
  assert(
    JSON.stringify(saveReplay) === JSON.stringify(saved),
    "D-037 Save replay did not return the original response.",
  );

  const downstreamBefore = downstreamState();
  const releaseCommand = command(
    subject,
    saved.authoritative_readback,
    "release",
  );
  const released = await invokeSuccess(
    client,
    "release_confirmed_needs",
    releaseCommand,
  );
  assert(
    released.contract_version === "RMVP-07.v2" &&
      released.command_name === "release_confirmed_needs" &&
      released.idempotency_status === "COMPLETED" &&
      released.resulting_batch_status === "RELEASED_FOR_PURCHASE_HANDOFF" &&
      released.authoritative_readback.batch_status ===
        "RELEASED_FOR_PURCHASE_HANDOFF" &&
      released.authoritative_readback.lifecycle_history[0]?.evidence_kind ===
        "RELEASE" &&
      released.authoritative_readback.lifecycle_history[1]?.evidence_kind ===
        "APPROVAL" &&
      released.authoritative_readback.lifecycle_history.some(
        (item) => item.evidence_kind === "VALIDATION",
      ),
    "D-037 Release did not return complete atomic lifecycle evidence.",
  );
  const releaseReplay = await invokeSuccess(
    client,
    "release_confirmed_needs",
    releaseCommand,
  );
  assert(
    JSON.stringify(releaseReplay) === JSON.stringify(released),
    "D-037 Release replay did not return the original response.",
  );
  assert(
    downstreamState() === downstreamBefore,
    "D-037 created a Purchase Handoff or downstream fact.",
  );

  const finalRead = await invokeSuccess(
    client,
    "get_confirmed_need_review",
    readRequest(subject, batchId),
  );
  assert(
    finalRead.workbench.batch_status === "RELEASED_FOR_PURCHASE_HANDOFF" &&
      finalRead.workbench.editing_allowed === false,
    "D-037 final readback is not released and read-only.",
  );
  await client.auth.signOut({ scope: "local" });
  console.log(
    `Verified ${browserSource === "fixture" ? "short" : "full upstream"} D-037 Save/replay/Release/replay/readback with zero downstream delta for batch ${batchId}.`,
  );
}

try {
  await main();
} catch (error) {
  console.error(
    error instanceof Error
      ? error.message
      : "D-037 local acceptance failed safely.",
  );
  process.exitCode = 1;
}
