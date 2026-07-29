import { fileURLToPath } from "node:url";
import { createClient } from "@supabase/supabase-js";
import {
  readLocalSupabaseStatus,
  runPinnedSupabase,
} from "./local-supabase-status.mjs";

const email = "atlas.pa06b.operator@local.test";
const password = "Atlas-PA06B-local-only!";
const contractVersion = "PANTRY-02.v1";

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function readRequest(subject, payload) {
  return {
    contract_version: contractVersion,
    requested_by_auth_subject: subject,
    correlation_id: crypto.randomUUID(),
    payload,
  };
}

function commandRequest(subject, expectedVersion, reasonCode, payload) {
  const commandId = crypto.randomUUID();
  return {
    contract_version: contractVersion,
    command_id: commandId,
    correlation_id: crypto.randomUUID(),
    idempotency_key: `${reasonCode.toLowerCase()}:${commandId}`,
    expected_version: expectedVersion,
    requested_by_auth_subject: subject,
    requested_at: new Date(Date.now() - 1000).toISOString(),
    reason_code: reasonCode,
    reason_note: "Bounded local PANTRY-02 acceptance evidence.",
    payload,
  };
}

async function invoke(client, name, request) {
  const { data, error } = await client
    .schema("atlas_api")
    .rpc(name, { request })
    .retry(false);
  if (error) {
    throw new Error(
      `PANTRY-02 ${name} transport failed safely (${error.code ?? "UNKNOWN"}: ${error.message ?? "no message"}).`,
    );
  }
  if (!data || data.success !== true) {
    throw new Error(
      `PANTRY-02 ${name} was rejected: ${data?.error_code ?? "UNKNOWN"}.`,
    );
  }
  return data;
}

function installLocalFile(relativePath) {
  const sqlPath = fileURLToPath(new URL(relativePath, import.meta.url));
  runPinnedSupabase(["db", "query", "--local", "--file", sqlPath], {
    stdio: "inherit",
  });
}

async function signIn(client) {
  const { data, error } = await client.auth.signInWithPassword({
    email,
    password,
  });
  if (error || !data.session) {
    throw new Error(
      "PANTRY-02 local sign-in failed. Run pnpm local:auth:provision first.",
    );
  }
  return data.session.user.id;
}

function isoDate(date) {
  return date.toISOString().slice(0, 10);
}

async function readWorkbench(client, subject, weekStart) {
  const result = await invoke(
    client,
    "get_pantry_source_workbench",
    readRequest(subject, { week_start: weekStart }),
  );
  assert(result.workbench, "PANTRY-02 workbench envelope was absent.");
  return result.workbench;
}

async function findEmptyFutureMonday(client, subject) {
  const candidate = new Date();
  candidate.setUTCHours(0, 0, 0, 0);
  candidate.setUTCDate(
    candidate.getUTCDate() + ((8 - candidate.getUTCDay()) % 7) + 7 * 1560,
  );

  for (let offset = 0; offset < 26; offset += 1) {
    const weekStart = isoDate(candidate);
    const workbench = await readWorkbench(client, subject, weekStart);
    if (!workbench.batch) return { weekStart, workbench };
    candidate.setUTCDate(candidate.getUTCDate() + 7);
  }
  throw new Error("PANTRY-02 could not find an unused explicit future week.");
}

async function preview(client, subject, weekStart, noAdditions, rows) {
  const result = await invoke(
    client,
    "preview_pantry_source",
    readRequest(subject, {
      week_start: weekStart,
      no_additions_confirmed: noAdditions,
      rows,
    }),
  );
  assert(
    result.preview?.can_save === true,
    "PANTRY-02 local proposal was not saveable.",
  );
  return result.preview;
}

async function main() {
  const { apiUrl, browserKey } = readLocalSupabaseStatus();
  installLocalFile("../supabase/local/pantry_02_purpose_fixture.sql");

  const client = createClient(apiUrl, browserKey, {
    db: { schema: "atlas_api" },
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  });
  const subject = await signIn(client);
  const { weekStart, workbench } = await findEmptyFutureMonday(client, subject);
  const school = workbench.schools[0];
  const ingredient = workbench.ingredients[0];
  const purpose = workbench.purposes.find(
    (item) => item.purpose_code === "school_requested_supplement",
  );
  assert(
    school && ingredient && purpose,
    "PANTRY-02 needs imported local School, Ingredient, Unit, Location, and Purpose fixtures.",
  );
  assert(
    school.default_delivery_location?.delivery_location_id &&
      ingredient.purchase_unit?.unit_id,
    "PANTRY-02 workbench did not return backend-derived Location and Unit.",
  );

  const initialRows = [
    {
      service_date: weekStart,
      school_id: school.school_id,
      ingredient_id: ingredient.ingredient_id,
      pantry_need_purpose_id: purpose.pantry_need_purpose_id,
      requested_quantity: "1.234567",
      note: "Nhà trường đề nghị bổ sung cho tuần kiểm thử cục bộ.",
      source_request_reference: "PANTRY-02-LOCAL-1",
      source_row_reference: "local:1",
    },
  ];
  const initialPreview = await preview(
    client,
    subject,
    weekStart,
    false,
    initialRows,
  );
  assert(
    initialPreview.canonical_rows[0].delivery_location_id ===
      school.default_delivery_location.delivery_location_id &&
      initialPreview.canonical_rows[0].unit_id ===
        ingredient.purchase_unit.unit_id &&
      String(initialPreview.canonical_rows[0].requested_quantity) ===
        "1.234567",
    "PANTRY-02 preview did not derive exact references and preserve quantity.",
  );

  const initialSave = await invoke(
    client,
    "save_pantry_draft",
    commandRequest(subject, 1, "PANTRY02_LOCAL_CREATE", {
      week_start: weekStart,
      no_additions_confirmed: false,
      source_signature: initialPreview.source_signature,
      expected_source_signature: null,
      rows: initialRows,
    }),
  );
  const stableLineId =
    initialSave.workbench?.batch?.active_lines?.[0]?.pantry_need_line_id;
  assert(stableLineId, "PANTRY-02 initial stable line identity was absent.");

  const correctedRows = [
    {
      ...initialRows[0],
      requested_quantity: "2.500000",
      note: "Nhà trường xác nhận lượng bổ sung đã điều chỉnh.",
      source_row_reference: "local:corrected",
    },
  ];
  const correctedPreview = await preview(
    client,
    subject,
    weekStart,
    false,
    correctedRows,
  );
  const replacement = await invoke(
    client,
    "save_pantry_draft",
    commandRequest(subject, 1, "PANTRY02_LOCAL_REPLACE", {
      week_start: weekStart,
      no_additions_confirmed: false,
      source_signature: correctedPreview.source_signature,
      expected_source_signature: initialPreview.source_signature,
      rows: correctedRows,
    }),
  );
  assert(
    replacement.workbench.batch.version === 2 &&
      replacement.workbench.batch.active_lines[0].pantry_need_line_id ===
        stableLineId,
    "PANTRY-02 complete replacement did not preserve stable line identity.",
  );

  const validated = await invoke(
    client,
    "validate_pantry",
    commandRequest(subject, 2, "PANTRY02_LOCAL_VALIDATE", {
      week_start: weekStart,
      expected_source_signature: correctedPreview.source_signature,
    }),
  );
  assert(
    validated.workbench.batch.pantry_need_batch_status === "VALIDATED" &&
      validated.workbench.batch.version === 3,
    "PANTRY-02 positive working source did not validate as version 3.",
  );

  const approved = await invoke(
    client,
    "approve_pantry",
    commandRequest(subject, 3, "PANTRY02_LOCAL_APPROVE", {
      week_start: weekStart,
      expected_source_signature: correctedPreview.source_signature,
    }),
  );
  const positiveSnapshot = approved.workbench.batch.latest_approval_snapshot_id;
  assert(
    approved.workbench.batch.pantry_need_batch_status === "APPROVED" &&
      approved.workbench.batch.version === 4 &&
      approved.workbench.batch.approval_history[0].line_count === 1,
    "PANTRY-02 positive approval snapshot was not exact.",
  );

  const reopened = await invoke(
    client,
    "reopen_pantry",
    commandRequest(subject, 4, "PANTRY02_LOCAL_REOPEN", {
      week_start: weekStart,
      expected_source_signature: correctedPreview.source_signature,
    }),
  );
  assert(
    reopened.workbench.batch.pantry_need_batch_status === "REOPENED" &&
      reopened.workbench.batch.version === 5 &&
      reopened.workbench.batch.latest_approval_snapshot_id === positiveSnapshot,
    "PANTRY-02 reopen did not preserve the prior approval snapshot.",
  );

  const zeroPreview = await preview(client, subject, weekStart, true, []);
  const zeroReopened = await invoke(
    client,
    "save_pantry_draft",
    commandRequest(subject, 5, "PANTRY02_LOCAL_ZERO", {
      week_start: weekStart,
      no_additions_confirmed: true,
      source_signature: zeroPreview.source_signature,
      expected_source_signature: correctedPreview.source_signature,
      rows: [],
    }),
  );
  assert(
    zeroReopened.workbench.batch.pantry_need_batch_status === "REOPENED" &&
      zeroReopened.workbench.batch.version === 6 &&
      zeroReopened.workbench.batch.no_additions_confirmed === true &&
      zeroReopened.workbench.batch.active_lines.length === 0 &&
      zeroReopened.workbench.batch.invalid_lines.some(
        (line) => line.pantry_need_line_id === stableLineId,
      ),
    "PANTRY-02 explicit zero successor did not remain REOPENED or invalidate the stable line.",
  );

  await invoke(
    client,
    "validate_pantry",
    commandRequest(subject, 6, "PANTRY02_LOCAL_ZERO_VALIDATE", {
      week_start: weekStart,
      expected_source_signature: zeroPreview.source_signature,
    }),
  );
  const finalApproval = await invoke(
    client,
    "approve_pantry",
    commandRequest(subject, 7, "PANTRY02_LOCAL_ZERO_APPROVE", {
      week_start: weekStart,
      expected_source_signature: zeroPreview.source_signature,
    }),
  );
  const finalBatch = finalApproval.workbench.batch;
  assert(
    finalBatch.pantry_need_batch_status === "APPROVED" &&
      finalBatch.version === 8 &&
      finalBatch.approval_history.length === 2 &&
      finalBatch.approval_history.some(
        (snapshot) =>
          snapshot.pantry_need_approval_snapshot_id === positiveSnapshot &&
          snapshot.line_count === 1,
      ) &&
      finalBatch.approval_history.some(
        (snapshot) =>
          snapshot.no_additions_confirmed === true &&
          snapshot.line_count === 0 &&
          snapshot.lines.length === 0,
      ) &&
      finalBatch.change_history.length === 8,
    "PANTRY-02 zero-line reapproval or immutable history was incomplete.",
  );

  installLocalFile("../supabase/local/pantry_02_acceptance_assertion.sql");
  await client.auth.signOut({ scope: "local" });
  console.log(
    `Verified PANTRY-02 browser-key read/preview/stable replacement/validate/positive approval/reopen/REOPENED correction/zero successor approval, exact snapshots, events/audits, and no downstream mutation for ${weekStart}.`,
  );
}

try {
  await main();
} catch (error) {
  console.error(
    error instanceof Error
      ? error.message
      : "PANTRY-02 local acceptance failed safely.",
  );
  process.exitCode = 1;
}
