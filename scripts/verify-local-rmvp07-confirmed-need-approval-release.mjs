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

function command(subject, workbench, kind) {
  const commandId = crypto.randomUUID();
  const definitions = {
    validation: {
      contract_version: "RMVP-06.v1",
      idempotency_key: `confirmed-need-validation:${commandId}`,
      reason_code: "BATCH_VALIDATION_REQUESTED",
    },
    approval: {
      contract_version: "RMVP-07.v1",
      idempotency_key: `confirmed-need-approval:${commandId}`,
      reason_code: "CONFIRMED_NEED_APPROVAL_REQUESTED",
    },
    release: {
      contract_version: "RMVP-07.v1",
      idempotency_key: `confirmed-need-release:${commandId}`,
      reason_code: "CONFIRMED_NEED_RELEASE_REQUESTED",
    },
  };
  return {
    ...definitions[kind],
    command_id: commandId,
    correlation_id: crypto.randomUUID(),
    expected_version: workbench.batch_version,
    requested_by_auth_subject: subject,
    requested_at: new Date(Date.now() - 1_000).toISOString(),
    reason_note: null,
    payload: { confirmed_need_batch_id: workbench.confirmed_need_batch_id },
  };
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

async function invoke(client, name, request) {
  for (let attempt = 1; attempt <= schemaCacheAttempts; attempt += 1) {
    const { data, error } = await client
      .schema("atlas_api")
      .rpc(name, { request })
      .retry(false);
    if (!error) {
      assert(data, `RMVP-07 ${name} returned no envelope.`);
      return data;
    }
    if (error.code !== "PGRST002" || attempt === schemaCacheAttempts) {
      throw new Error(
        `RMVP-07 ${name} transport failed safely (${error.code ?? "UNKNOWN"}: ${error.message ?? "no message"}).`,
      );
    }
    await new Promise((resolve) => setTimeout(resolve, schemaCacheDelayMs));
  }
}

async function invokeSuccess(client, name, request) {
  const response = await invoke(client, name, request);
  assert(
    response.success === true,
    `RMVP-07 ${name} was rejected: ${response.error_code ?? "UNKNOWN"} (${response.safe_message ?? "no safe message"}).`,
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
    if (response.workbench.materialization?.confirmed_need_batch_id) {
      return response.workbench.materialization.confirmed_need_batch_id;
    }
    candidate.setUTCDate(candidate.getUTCDate() + 7);
  }
  throw new Error("RMVP-07 could not find the RMVP-04 materialized batch.");
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
  assert(preview.preview.success, "RMVP-07 prerequisite preview was blocked.");
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

async function ensureValidated(client, subject, workbench) {
  if (workbench.batch_status === "VALIDATED") return workbench;
  const validated = await invokeSuccess(
    client,
    "validate_confirmed_needs",
    command(subject, workbench, "validation"),
  );
  assert(
    validated.validation_status === "VALIDATED",
    "RMVP-07 prerequisite RMVP-06 validation did not succeed.",
  );
  const authoritative = await invokeSuccess(
    client,
    "get_confirmed_need_review",
    reviewRequest(subject, workbench.confirmed_need_batch_id),
  );
  return authoritative.workbench;
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
  let lastError;
  for (let attempt = 1; attempt <= 3; attempt += 1) {
    try {
      const output = runPinnedSupabase(
        ["db", "query", "--local", "--output-format", "json", sql],
        {
          encoding: "utf8",
          stdio: ["ignore", "pipe", "inherit"],
        },
      );
      const state = JSON.parse(output).rows?.[0]?.downstream_state;
      assert(
        state && typeof state === "object" && !Array.isArray(state),
        "RMVP-07 downstream-state query returned no object.",
      );
      return JSON.stringify(state);
    } catch (error) {
      lastError = error;
    }
  }
  throw lastError;
}

async function main() {
  assert(
    browserSource === "fixture" || browserSource === "rmvp04",
    "RMVP-07 browser source must be fixture or rmvp04.",
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
  assert(!error && signIn.session, "RMVP-07 local acceptance sign-in failed.");
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
  const confirmed = await ensureAllLinesConfirmed(
    client,
    subject,
    initial.workbench,
  );
  const validated = await ensureValidated(client, subject, confirmed);
  assert(
    validated.batch_status === "VALIDATED" &&
      validated.allowed_actions.approve_confirmed_needs === true &&
      validated.disabled_reason_codes.approve_confirmed_needs === null &&
      validated.allowed_actions.release_confirmed_needs_for_purchase_handoff ===
        false,
    "RMVP-07 validated readback did not authorize approval exactly.",
  );
  const downstreamBefore = downstreamState();

  const approvalCommand = command(subject, validated, "approval");
  const approval = await invokeSuccess(
    client,
    "approve_confirmed_needs",
    approvalCommand,
  );
  assert(
    approval.contract_version === "RMVP-07.v1" &&
      approval.command_name === "approve_confirmed_needs" &&
      approval.idempotency_status === "COMPLETED" &&
      approval.resulting_batch_status === "APPROVED" &&
      /^[0-9a-f]{64}$/.test(approval.validated_fact_fingerprint) &&
      approval.authoritative_readback.batch_status === "APPROVED" &&
      approval.authoritative_readback.allowed_actions
        .release_confirmed_needs_for_purchase_handoff === true,
    "RMVP-07 approval did not return exact authoritative evidence.",
  );
  const approvalReplay = await invokeSuccess(
    client,
    "approve_confirmed_needs",
    approvalCommand,
  );
  assert(
    JSON.stringify(approvalReplay) === JSON.stringify(approval),
    "RMVP-07 approval replay did not return the original response.",
  );

  const releaseCommand = command(
    subject,
    approval.authoritative_readback,
    "release",
  );
  const release = await invokeSuccess(
    client,
    "release_confirmed_needs_for_purchase_handoff",
    releaseCommand,
  );
  assert(
    release.contract_version === "RMVP-07.v1" &&
      release.command_name === "release_confirmed_needs_for_purchase_handoff" &&
      release.idempotency_status === "COMPLETED" &&
      release.resulting_batch_status === "RELEASED_FOR_PURCHASE_HANDOFF" &&
      release.authoritative_readback.batch_status ===
        "RELEASED_FOR_PURCHASE_HANDOFF",
    "RMVP-07 release did not return exact authoritative evidence.",
  );
  const releaseReplay = await invokeSuccess(
    client,
    "release_confirmed_needs_for_purchase_handoff",
    releaseCommand,
  );
  assert(
    JSON.stringify(releaseReplay) === JSON.stringify(release),
    "RMVP-07 release replay did not return the original response.",
  );

  const downstreamAfter = downstreamState();
  assert(
    downstreamAfter === downstreamBefore,
    "RMVP-07 created a Purchase Handoff or downstream fact.",
  );
  const finalRead = await invokeSuccess(
    client,
    "get_confirmed_need_review",
    reviewRequest(subject, batchId),
  );
  const final = finalRead.workbench;
  assert(
    final.allowed_actions.approve_confirmed_needs === false &&
      final.allowed_actions.release_confirmed_needs_for_purchase_handoff ===
        false &&
      final.disabled_reason_codes.approve_confirmed_needs ===
        "APPROVAL_ALREADY_COMPLETED" &&
      final.disabled_reason_codes
        .release_confirmed_needs_for_purchase_handoff ===
        "RELEASE_ALREADY_COMPLETED" &&
      final.approval.current_snapshot_id ===
        approval.confirmed_need_approval_snapshot_id &&
      final.release.current_release_id === release.confirmed_need_release_id &&
      final.facts_changed_since_validation === false &&
      final.facts_changed_since_approval === false &&
      final.lifecycle_history[0]?.evidence_kind === "RELEASE" &&
      final.lifecycle_history[1]?.evidence_kind === "APPROVAL" &&
      final.lifecycle_history.some(
        (item) => item.evidence_kind === "VALIDATION",
      ),
    "RMVP-07 final UI readback is incomplete or incorrectly ordered.",
  );
  await client.auth.signOut({ scope: "local" });
  console.log(
    `Verified ${browserSource === "fixture" ? "short" : "full upstream"} RMVP-07 approval/replay/release/replay/readback with zero downstream delta for batch ${batchId}.`,
  );
}

try {
  await main();
} catch (error) {
  console.error(
    error instanceof Error
      ? error.message
      : "RMVP-07 local acceptance failed safely.",
  );
  process.exitCode = 1;
}
