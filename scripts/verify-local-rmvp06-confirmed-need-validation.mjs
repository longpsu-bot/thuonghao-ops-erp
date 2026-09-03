import { fileURLToPath } from "node:url";
import { saveLocalConfirmedAllocations } from "./local-confirmed-supplier-allocation.mjs";
import { createClient } from "@supabase/supabase-js";
import {
  readLocalSupabaseStatus,
  runPinnedSupabase,
} from "./local-supabase-status.mjs";

const email = "atlas.pa06b.operator@local.test";
const password = "Atlas-PA06B-local-only!";
const deterministicBatchId = "b6500000-0000-0000-0000-000000000050";
const browserSource = process.env.RMVP06_BROWSER_SOURCE ?? "fixture";
const schemaCacheAttempts = 6;
const schemaCacheDelayMs = 1_500;

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function install(relativePath) {
  const path = fileURLToPath(new URL(relativePath, import.meta.url));
  runPinnedSupabase(["db", "query", "--local", "--file", path], {
    stdio: "inherit",
  });
}

function readRequest(version, subject, payload) {
  return {
    contract_version: version,
    requested_by_auth_subject: subject,
    correlation_id: crypto.randomUUID(),
    payload,
  };
}

function reviewRequest(subject, batchId) {
  return readRequest("RMVP-05.v1", subject, {
    confirmed_need_batch_id: batchId,
    filters: {},
    line_offset: 0,
    line_limit: 100,
  });
}

function previewRequest(subject, workbench, lines) {
  return readRequest("RMVP-05.v1", subject, {
    confirmed_need_batch_id: workbench.confirmed_need_batch_id,
    expected_batch_version: workbench.batch_version,
    lines,
  });
}

function confirmationCommand(subject, workbench, previewHash, lines) {
  const commandId = crypto.randomUUID();
  return {
    contract_version: "RMVP-05.v1",
    command_id: commandId,
    correlation_id: crypto.randomUUID(),
    idempotency_key: `confirmed-need-quantities:${commandId}`,
    expected_version: workbench.batch_version,
    requested_by_auth_subject: subject,
    requested_at: new Date(Date.now() - 1_000).toISOString(),
    reason_code: "CONFIRMED_NEED_QUANTITIES_CONFIRMED",
    reason_note: null,
    payload: {
      confirmed_need_batch_id: workbench.confirmed_need_batch_id,
      preview_hash: previewHash,
      lines,
    },
  };
}

function validationCommand(subject, workbench) {
  const commandId = crypto.randomUUID();
  return {
    contract_version: "RMVP-06.v1",
    command_id: commandId,
    correlation_id: crypto.randomUUID(),
    idempotency_key: `confirmed-need-validation:${commandId}`,
    expected_version: workbench.batch_version,
    requested_by_auth_subject: subject,
    requested_at: new Date(Date.now() - 1_000).toISOString(),
    reason_code: "BATCH_VALIDATION_REQUESTED",
    reason_note: null,
    payload: { confirmed_need_batch_id: workbench.confirmed_need_batch_id },
  };
}

async function invoke(client, name, request) {
  for (let attempt = 1; attempt <= schemaCacheAttempts; attempt += 1) {
    const { data, error } = await client
      .schema("atlas_api")
      .rpc(name, { request })
      .retry(false);
    if (!error) {
      assert(data, `RMVP-06 ${name} returned no envelope.`);
      return data;
    }
    if (error.code !== "PGRST002" || attempt === schemaCacheAttempts) {
      throw new Error(
        `RMVP-06 ${name} transport failed safely (${error.code ?? "UNKNOWN"}: ${error.message ?? "no message"}).`,
      );
    }
    await new Promise((resolve) => setTimeout(resolve, schemaCacheDelayMs));
  }
}

async function invokeSuccess(client, name, request) {
  const response = await invoke(client, name, request);
  assert(
    response.success === true,
    `RMVP-06 ${name} was rejected: ${response.error_code ?? "UNKNOWN"} (${response.safe_message ?? "no safe message"}).`,
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
      readRequest("RMVP-04.v1", subject, {
        period_start: serviceDate,
        period_end: serviceDate,
        need_generation_run_id: null,
        filters: {},
        group_offset: 0,
        group_limit: 100,
      }),
    );
    const materialization = response.workbench.materialization;
    if (materialization?.confirmed_need_batch_id) {
      return materialization.confirmed_need_batch_id;
    }
    candidate.setUTCDate(candidate.getUTCDate() + 7);
  }
  throw new Error("RMVP-06 could not find the RMVP-04 materialized batch.");
}

async function ensureAllLinesConfirmed(client, subject, workbench) {
  const missing = workbench.lines.filter(
    (line) => line.current_decision_id === null,
  );
  if (!missing.length) return workbench;
  const lines = missing.map((line) => ({
    confirmed_need_line_id: line.confirmed_need_line_id,
    expected_current_revision_id: line.current_revision_id,
    expected_current_decision_id: null,
    proposed_confirmed_quantity: line.proposed_confirmed_quantity,
    reason_code: "PROPOSAL_ACCEPTED",
    reason_note: null,
  }));
  const preview = await invokeSuccess(
    client,
    "preview_confirmed_need_confirmation",
    previewRequest(subject, workbench, lines),
  );
  assert(preview.preview.success, "RMVP-06 prerequisite preview was blocked.");
  const confirmed = await invokeSuccess(
    client,
    "confirm_need_quantities",
    confirmationCommand(
      subject,
      workbench,
      preview.preview.preview_hash,
      lines,
    ),
  );
  return confirmed.authoritative_readback;
}

async function main() {
  assert(
    browserSource === "fixture" || browserSource === "rmvp04",
    "RMVP-06 browser source must be fixture or rmvp04.",
  );
  const { apiUrl, browserKey } = readLocalSupabaseStatus();
  if (browserSource === "fixture") {
    install("../supabase/local/rmvp_05_browser_fixture.sql");
  }
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
  assert(!error && signIn.session, "RMVP-06 local acceptance sign-in failed.");
  const subject = signIn.session.user.id;
  const batchId =
    browserSource === "fixture"
      ? deterministicBatchId
      : await findMaterializedBatch(client, subject);

  const initial = await invokeSuccess(
    client,
    "get_confirmed_need_review",
    reviewRequest(subject, batchId),
  );
  const confirmedWorkbench = await ensureAllLinesConfirmed(
    client,
    subject,
    initial.workbench,
  );
  // The full upstream v1 release verifier needs allocations saved while Need
  // is still editable; validation deliberately closes that editing boundary.
  if (process.env.RMVP07_CONTRACT === "v1") {
    await saveLocalConfirmedAllocations(
      client,
      subject,
      confirmedWorkbench,
      invokeSuccess,
    );
  }
  const command = validationCommand(subject, confirmedWorkbench);
  const validated = await invokeSuccess(
    client,
    "validate_confirmed_needs",
    command,
  );
  assert(
    validated.validation_status === "VALIDATED" &&
      validated.line_count === confirmedWorkbench.line_counts.total &&
      validated.blocking_issue_count === 0 &&
      /^[0-9a-f]{64}$/.test(validated.validation_fingerprint) &&
      validated.authoritative_readback.batch_status === "VALIDATED" &&
      validated.authoritative_readback.editing_allowed === false &&
      validated.authoritative_readback.validation_allowed === false &&
      validated.authoritative_readback.validation.latest_attempt_id ===
        validated.validation_attempt_id,
    "RMVP-06 did not persist and shape exact successful validation evidence.",
  );
  const replay = await invokeSuccess(
    client,
    "validate_confirmed_needs",
    command,
  );
  assert(
    JSON.stringify(replay) === JSON.stringify(validated),
    "RMVP-06 exact retry did not return the immutable original response.",
  );
  const readback = await invokeSuccess(
    client,
    "get_confirmed_need_review",
    reviewRequest(subject, batchId),
  );
  assert(
    readback.workbench.validation.latest_attempt_id ===
      validated.validation_attempt_id &&
      readback.workbench.validation.latest_outcome === "VALIDATED" &&
      readback.workbench.validation.blocking_count === 0,
    "RMVP-06 readback did not preserve the exact latest validation attempt.",
  );
  await client.auth.signOut({ scope: "local" });
  console.log(
    `Verified ${browserSource === "fixture" ? "short" : "full upstream"} RMVP-06 validation/replay/readback for batch ${batchId}.`,
  );
}

try {
  await main();
} catch (error) {
  console.error(
    error instanceof Error
      ? error.message
      : "RMVP-06 local acceptance failed safely.",
  );
  process.exitCode = 1;
}
