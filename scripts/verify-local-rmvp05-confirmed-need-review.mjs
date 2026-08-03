import { fileURLToPath } from "node:url";
import { createClient } from "@supabase/supabase-js";
import {
  readLocalSupabaseStatus,
  runPinnedSupabase,
} from "./local-supabase-status.mjs";

const email = "atlas.pa06b.operator@local.test";
const password = "Atlas-PA06B-local-only!";
const deterministicBatchId = "b6500000-0000-0000-0000-000000000050";
const browserSource = process.env.RMVP05_BROWSER_SOURCE ?? "fixture";

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function installLocalFixture(relativePath) {
  const sqlPath = fileURLToPath(new URL(relativePath, import.meta.url));
  runPinnedSupabase(["db", "query", "--local", "--file", sqlPath], {
    stdio: "inherit",
  });
}

function readRequest(contractVersion, subject, payload) {
  return {
    contract_version: contractVersion,
    requested_by_auth_subject: subject,
    correlation_id: crypto.randomUUID(),
    payload,
  };
}

function confirmationCommand(subject, version, previewHash, lines) {
  const commandId = crypto.randomUUID();
  return {
    contract_version: "RMVP-05.v1",
    command_id: commandId,
    correlation_id: crypto.randomUUID(),
    idempotency_key: `confirmed-need-quantities:${commandId}`,
    expected_version: version,
    requested_by_auth_subject: subject,
    requested_at: new Date(Date.now() - 1000).toISOString(),
    reason_code: "CONFIRMED_NEED_QUANTITIES_CONFIRMED",
    reason_note: null,
    payload: {
      confirmed_need_batch_id: null,
      preview_hash: previewHash,
      lines,
    },
  };
}

async function invoke(client, name, request) {
  const { data, error } = await client
    .schema("atlas_api")
    .rpc(name, { request })
    .retry(false);
  if (error) {
    throw new Error(
      `RMVP-05 ${name} transport failed safely (${error.code ?? "UNKNOWN"}: ${error.message ?? "no message"}).`,
    );
  }
  assert(data, `RMVP-05 ${name} returned no envelope.`);
  return data;
}

async function invokeSuccess(client, name, request) {
  const data = await invoke(client, name, request);
  assert(
    data.success === true,
    `RMVP-05 ${name} was rejected: ${data.error_code ?? "UNKNOWN"}.`,
  );
  return data;
}

function isoDate(date) {
  return date.toISOString().slice(0, 10);
}

function incrementMicro(quantity) {
  const [whole, fraction = ""] = quantity.split(".");
  const scaled =
    BigInt(whole) * 1_000_000n + BigInt(fraction.padEnd(6, "0").slice(0, 6));
  const next = scaled + 1n;
  return `${next / 1_000_000n}.${String(next % 1_000_000n).padStart(6, "0")}`;
}

async function findMaterializedBatch(client, subject) {
  const candidate = new Date();
  candidate.setUTCHours(0, 0, 0, 0);
  candidate.setUTCDate(
    candidate.getUTCDate() + ((8 - candidate.getUTCDay()) % 7) + 7 * 1040,
  );

  for (let offset = 0; offset < 26; offset += 1) {
    const serviceDate = isoDate(candidate);
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
    if (
      materialization?.confirmed_need_batch_id &&
      materialization.confirmed_need_status === "DRAFT_REVIEW"
    ) {
      return materialization.confirmed_need_batch_id;
    }
    candidate.setUTCDate(candidate.getUTCDate() + 7);
  }
  throw new Error("RMVP-05 could not find the RMVP-04/CMD-15 browser batch.");
}

function reviewRequest(subject, batchId) {
  return readRequest("RMVP-05.v1", subject, {
    confirmed_need_batch_id: batchId,
    filters: {},
    line_offset: 0,
    line_limit: 100,
  });
}

function previewRequest(subject, batchId, version, lines) {
  return readRequest("RMVP-05.v1", subject, {
    confirmed_need_batch_id: batchId,
    expected_batch_version: version,
    lines,
  });
}

function draftLine(line, quantity, reasonCode, reasonNote) {
  return {
    confirmed_need_line_id: line.confirmed_need_line_id,
    expected_current_revision_id: line.current_revision_id,
    expected_current_decision_id: line.current_decision_id,
    proposed_confirmed_quantity: quantity,
    reason_code: reasonCode,
    reason_note: reasonNote,
  };
}

async function main() {
  assert(
    browserSource === "fixture" || browserSource === "rmvp04",
    "RMVP-05 browser source must be fixture or rmvp04.",
  );
  const { apiUrl, browserKey } = readLocalSupabaseStatus();
  installLocalFixture("../supabase/local/rmvp_05_browser_fixture.sql");

  const client = createClient(apiUrl, browserKey, {
    db: { schema: "atlas_api" },
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  });
  const { data: signIn, error: signInError } =
    await client.auth.signInWithPassword({ email, password });
  assert(
    !signInError && signIn.session,
    "RMVP-05 local acceptance sign-in failed.",
  );
  const subject = signIn.session.user.id;
  const batchId =
    browserSource === "rmvp04"
      ? await findMaterializedBatch(client, subject)
      : deterministicBatchId;

  const initial = await invokeSuccess(
    client,
    "get_confirmed_need_review",
    reviewRequest(subject, batchId),
  );
  assert(
    initial.workbench.batch_status === "DRAFT_REVIEW" &&
      initial.workbench.batch_version === 1 &&
      initial.workbench.lines.length >= 2 &&
      initial.workbench.allowed_actions.preview_confirmation === true &&
      initial.workbench.lines.every(
        (line) =>
          typeof line.theoretical_quantity === "string" &&
          typeof line.proposed_confirmed_quantity === "string" &&
          line.effective_policy?.planning_step === "0.000001",
      ),
    "RMVP-05 shaped read did not expose exact reviewable proposals and policies.",
  );

  const selected = initial.workbench.lines.slice(0, 2);
  const mixedLines = [
    draftLine(
      selected[0],
      selected[0].proposed_confirmed_quantity,
      "PROPOSAL_ACCEPTED",
      null,
    ),
    draftLine(
      selected[1],
      incrementMicro(selected[1].proposed_confirmed_quantity),
      "PLANNING_STEP_ADJUSTMENT",
      null,
    ),
  ];
  const preview = await invokeSuccess(
    client,
    "preview_confirmed_need_confirmation",
    previewRequest(subject, batchId, 1, mixedLines),
  );
  assert(
    preview.preview.success === true &&
      /^[0-9a-f]{64}$/.test(preview.preview.preview_hash) &&
      preview.preview.write_certainty === "NO_WRITE" &&
      preview.preview.ordered_preview_lines.some(
        (line) => line.decision_kind === "UNCHANGED_PROPOSAL_ACCEPTED",
      ) &&
      preview.preview.ordered_preview_lines.some(
        (line) => line.decision_kind === "ADJUSTED_QUANTITY_CONFIRMED",
      ),
    "RMVP-05 mixed exact preview was not authoritative and write-free.",
  );

  const command = confirmationCommand(
    subject,
    1,
    preview.preview.preview_hash,
    mixedLines,
  );
  command.payload.confirmed_need_batch_id = batchId;
  const confirmed = await invokeSuccess(
    client,
    "confirm_need_quantities",
    command,
  );
  assert(
    confirmed.new_batch_version === 2 &&
      confirmed.unchanged_accepted_line_count === 1 &&
      confirmed.adjusted_line_count === 1 &&
      confirmed.created_successor_revision_ids.length === 1 &&
      confirmed.created_decision_ids.length === 2,
    "RMVP-05 mixed confirmation did not persist the expected decision evidence.",
  );

  const replay = await invokeSuccess(
    client,
    "confirm_need_quantities",
    command,
  );
  assert(
    JSON.stringify(replay) === JSON.stringify(confirmed),
    "RMVP-05 exact retry did not return the immutable original response.",
  );

  const afterMixed = await invokeSuccess(
    client,
    "get_confirmed_need_review",
    reviewRequest(subject, batchId),
  );
  const unchangedReadback = afterMixed.workbench.lines.find(
    (line) =>
      line.confirmed_need_line_id === selected[0].confirmed_need_line_id,
  );
  const adjustedReadback = afterMixed.workbench.lines.find(
    (line) =>
      line.confirmed_need_line_id === selected[1].confirmed_need_line_id,
  );
  assert(
    afterMixed.workbench.batch_version === 2 &&
      afterMixed.workbench.line_counts.total ===
        initial.workbench.line_counts.total &&
      afterMixed.workbench.line_counts.unreviewed ===
        initial.workbench.line_counts.total - 2 &&
      afterMixed.workbench.line_counts.confirmed === 2 &&
      afterMixed.workbench.line_counts.adjusted === 1 &&
      unchangedReadback?.confirmed_quantity_after ===
        mixedLines[0].proposed_confirmed_quantity &&
      unchangedReadback.decision_history.length === 1 &&
      adjustedReadback?.confirmed_quantity_after ===
        mixedLines[1].proposed_confirmed_quantity &&
      adjustedReadback.decision_history.length === 1,
    "RMVP-05 authoritative readback did not preserve the exact mixed decision result.",
  );

  if (browserSource === "rmvp04") {
    const missingNoteLine = draftLine(
      unchangedReadback,
      unchangedReadback.proposed_confirmed_quantity,
      "PROPOSAL_ACCEPTED",
      null,
    );
    const missingNote = await invokeSuccess(
      client,
      "preview_confirmed_need_confirmation",
      previewRequest(subject, batchId, 2, [missingNoteLine]),
    );
    assert(
      missingNote.preview.success === false &&
        missingNote.preview.error_code === "REASON_NOTE_REQUIRED",
      "RMVP-05 replacement preview did not require correction evidence.",
    );

    const replacementLine = {
      ...missingNoteLine,
      reason_note: "GitHub-only corrected confirmation evidence",
    };
    const replacementPreview = await invokeSuccess(
      client,
      "preview_confirmed_need_confirmation",
      previewRequest(subject, batchId, 2, [replacementLine]),
    );
    assert(
      replacementPreview.preview.success === true &&
        replacementPreview.preview.warnings.some(
          (warning) => warning.code === "DECISION_REPLACEMENT",
        ),
      "RMVP-05 governed replacement preview was not accepted with a warning.",
    );

    const replacementCommand = confirmationCommand(
      subject,
      2,
      replacementPreview.preview.preview_hash,
      [replacementLine],
    );
    replacementCommand.payload.confirmed_need_batch_id = batchId;
    const replacement = await invokeSuccess(
      client,
      "confirm_need_quantities",
      replacementCommand,
    );
    assert(
      replacement.new_batch_version === 3 &&
        replacement.created_successor_revision_ids.length === 0 &&
        replacement.created_decision_ids.length === 1,
      "RMVP-05 replacement did not append only decision evidence.",
    );

    const finalRead = await invokeSuccess(
      client,
      "get_confirmed_need_review",
      reviewRequest(subject, batchId),
    );
    const finalTarget = finalRead.workbench.lines.find(
      (line) =>
        line.confirmed_need_line_id ===
        unchangedReadback.confirmed_need_line_id,
    );
    assert(
      finalRead.workbench.batch_version === 3 &&
        finalTarget?.decision_history.length === 2 &&
        finalTarget.decision_history[0].predecessor_decision_id ===
          finalTarget.decision_history[1].decision_id,
      "RMVP-05 final readback did not preserve the two-decision predecessor chain.",
    );
  }

  await client.auth.signOut({ scope: "local" });
  console.log(
    browserSource === "rmvp04"
      ? `Verified full upstream RMVP-05 read/preview/confirm/replay/replacement/readback for batch ${batchId}.`
      : `Verified short RMVP-05 fixture read/preview/confirm/replay/readback for batch ${batchId}.`,
  );
}

try {
  await main();
} catch (error) {
  console.error(
    error instanceof Error
      ? error.message
      : "RMVP-05 local acceptance failed safely.",
  );
  process.exitCode = 1;
}
