import { fileURLToPath } from "node:url";
import { createClient } from "@supabase/supabase-js";
import {
  readLocalSupabaseStatus,
  runPinnedSupabase,
} from "./local-supabase-status.mjs";

const email = "atlas.pa06b.operator@local.test";
const password = "Atlas-PA06B-local-only!";
const pantryIngredientId = "b6400000-0000-0000-0000-000000000050";

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

function commandRequest(
  contractVersion,
  subject,
  expectedVersion,
  reasonCode,
  payload,
  reasonNote = null,
) {
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
    reason_note: reasonNote,
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
      `PLANNING-CONTRACT-01 ${name} transport failed safely (${error.code ?? "UNKNOWN"}: ${error.message ?? "no message"}).`,
    );
  }
  if (!data || data.success !== true) {
    const diagnostic = [
      data?.safe_message,
      ...(data?.blocking_references ?? []).map((item) => item.code),
    ]
      .filter(Boolean)
      .join("; ");
    throw new Error(
      `PLANNING-CONTRACT-01 ${name} was rejected: ${data?.error_code ?? "UNKNOWN"}${diagnostic ? ` (${diagnostic})` : ""}.`,
    );
  }
  return data;
}

async function signIn(client) {
  const { data, error } = await client.auth.signInWithPassword({
    email,
    password,
  });
  if (error || !data.session) {
    throw new Error(
      "PLANNING-CONTRACT-01 local sign-in failed. Run pnpm local:auth:provision first.",
    );
  }
  return data.session.user.id;
}

function isoDate(date) {
  return date.toISOString().slice(0, 10);
}

async function planningWorkbench(client, subject, weekStart) {
  return (
    await invoke(
      client,
      "get_planning_inputs_workbench",
      readRequest("RMVP-03A.v1", subject, { week_start: weekStart }),
    )
  ).workbench;
}

async function pantryWorkbench(client, subject, weekStart) {
  return (
    await invoke(
      client,
      "get_pantry_source_workbench",
      readRequest("PANTRY-02.v1", subject, { week_start: weekStart }),
    )
  ).workbench;
}

async function findEmptyWeek(client, subject) {
  const candidate = new Date();
  candidate.setUTCHours(0, 0, 0, 0);
  candidate.setUTCDate(
    candidate.getUTCDate() + ((8 - candidate.getUTCDay()) % 7) + 7 * 2080,
  );
  for (let offset = 0; offset < 26; offset += 1) {
    const weekStart = isoDate(candidate);
    const planning = await planningWorkbench(client, subject, weekStart);
    const pantry = await pantryWorkbench(client, subject, weekStart);
    if (!planning.weekly_menu && !planning.attendance && !pantry.batch) {
      return { weekStart, planning, pantry };
    }
    candidate.setUTCDate(candidate.getUTCDate() + 7);
  }
  throw new Error(
    "PLANNING-CONTRACT-01 could not find an unused local acceptance week.",
  );
}

async function releasedRecipeDish(client, subject) {
  const workbench = (
    await invoke(
      client,
      "get_dish_recipe_workbench",
      readRequest("RMVP-02A.v1", subject, {}),
    )
  ).workbench;
  const candidate = workbench.recipe_versions
    .map((version) => {
      const recipe = workbench.recipes.find(
        (item) => item.recipe_id === version.recipe_id,
      );
      const dish = workbench.dishes.find(
        (item) => item.dish_id === recipe?.dish_id,
      );
      return { version, recipe, dish };
    })
    .find(
      ({ version, recipe, dish }) =>
        version.recipe_version_status === "RELEASED_FOR_PLANNING" &&
        version.composition.some(
          (line) =>
            line.line_disposition === "PRESENT" && line.quantity_per_basis > 0,
        ) &&
        recipe?.recipe_status === "ACTIVE" &&
        dish?.dish_status === "ACTIVE",
    );
  assert(
    candidate?.dish?.dish_type_code,
    "PLANNING-CONTRACT-01 requires an active released Recipe with an active Dish and usable composition.",
  );
  return { version: candidate.version, dish: candidate.dish };
}

async function previewMenu(client, subject, weekStart, rows) {
  return (
    await invoke(
      client,
      "preview_weekly_menu_import",
      readRequest("RMVP-03A.v1", subject, { week_start: weekStart, rows }),
    )
  ).preview;
}

async function previewAttendance(client, subject, weekStart, rows) {
  return (
    await invoke(
      client,
      "preview_attendance_import",
      readRequest("RMVP-03A.v1", subject, { week_start: weekStart, rows }),
    )
  ).preview;
}

async function previewPantry(client, subject, weekStart, rows) {
  return (
    await invoke(
      client,
      "preview_pantry_source",
      readRequest("PANTRY-02.v1", subject, {
        week_start: weekStart,
        no_additions_confirmed: false,
        rows,
      }),
    )
  ).preview;
}

async function main() {
  installLocalFixture("../supabase/local/pantry_02_purpose_fixture.sql");
  installLocalFixture("../supabase/local/rmvp_04_browser_fixture.sql");
  const { apiUrl, browserKey } = readLocalSupabaseStatus();
  const client = createClient(apiUrl, browserKey, {
    db: { schema: "atlas_api" },
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  });
  const subject = await signIn(client);
  const { weekStart, planning, pantry } = await findEmptyWeek(client, subject);
  const { dish } = await releasedRecipeDish(client, subject);
  const school = planning.schools[0];
  const ingredient = pantry.ingredients.find(
    (item) => item.ingredient_id === pantryIngredientId,
  );
  const purpose = pantry.purposes.find(
    (item) => item.purpose_code === "school_requested_supplement",
  );
  assert(
    school && ingredient && purpose,
    "PLANNING-CONTRACT-01 lacks the School, Pantry Ingredient, or Purpose fixture.",
  );

  const menuRows = [
    {
      school_id: school.school_id,
      service_date: weekStart,
      menu_slot_code: dish.dish_type_code,
      dish_id: dish.dish_id,
      source_row_reference: "planning-contract-01-menu:1",
    },
  ];
  const menuPreview = await previewMenu(client, subject, weekStart, menuRows);
  const menu = await invoke(
    client,
    "save_weekly_menu",
    commandRequest("RMVP-03A.v2", subject, 1, "WEEKLY_MENU_SAVED", {
      week_start: weekStart,
      source_type: "MANUAL_ATLAS",
      source_name: "PLANNING-CONTRACT-01 browser acceptance",
      source_signature: menuPreview.source_signature,
      expected_source_signature: null,
      rows: menuPreview.canonical_rows,
    }),
  );

  const attendanceRows = [
    {
      school_id: school.school_id,
      service_date: weekStart,
      student_portions: 10,
      teacher_portions: 0,
      source_row_reference: "planning-contract-01-attendance:1",
    },
  ];
  const attendancePreview = await previewAttendance(
    client,
    subject,
    weekStart,
    attendanceRows,
  );
  const attendance = await invoke(
    client,
    "save_attendance",
    commandRequest("RMVP-03A.v2", subject, 1, "ATTENDANCE_SAVED", {
      week_start: weekStart,
      source_type: "MANUAL_ATLAS",
      source_name: "PLANNING-CONTRACT-01 browser acceptance",
      source_signature: attendancePreview.source_signature,
      expected_source_signature: null,
      rows: attendancePreview.canonical_rows,
    }),
  );

  const pantryRows = [
    {
      service_date: weekStart,
      school_id: school.school_id,
      ingredient_id: ingredient.ingredient_id,
      pantry_need_purpose_id: purpose.pantry_need_purpose_id,
      requested_quantity: "1.250000",
      note: "Bổ sung cho kiểm thử PLANNING-CONTRACT-01.",
      source_request_reference: "PLANNING-CONTRACT-01",
      source_row_reference: "planning-contract-01-pantry:1",
    },
  ];
  const pantryPreview = await previewPantry(
    client,
    subject,
    weekStart,
    pantryRows,
  );
  const pantrySave = await invoke(
    client,
    "save_pantry",
    commandRequest("PANTRY-02.v2", subject, 1, "PANTRY_SAVED", {
      week_start: weekStart,
      no_additions_confirmed: false,
      source_signature: pantryPreview.source_signature,
      expected_source_signature: null,
      rows: pantryRows,
    }),
  );
  assert(
    menu.contract_version === "RMVP-03A.v2" &&
      attendance.contract_version === "RMVP-03A.v2" &&
      pantrySave.contract_version === "PANTRY-02.v2",
    "PLANNING-CONTRACT-01 source Saves did not use the additive contracts.",
  );

  const preflight = await invoke(
    client,
    "get_planning_input_preflight",
    readRequest("RMVP-03B.v2", subject, {
      period_start: weekStart,
      period_end: weekStart,
    }),
  );
  assert(
    preflight.preflight.readiness_state === "READY" &&
      preflight.preflight.downstream_currentness === "NOT_GENERATED",
    "PLANNING-CONTRACT-01 automatic preflight was not READY/NOT_GENERATED.",
  );

  const initial = await invoke(
    client,
    "execute_need_generation",
    commandRequest("RMVP-04.v2", subject, 1, "NEED_GENERATION_EXECUTED", {
      period_start: weekStart,
      period_end: weekStart,
      expected_current_need_generation_run_id: null,
    }),
  );
  const initialRunId = initial.affected_aggregate_ids.need_generation_run_id;
  const confirmedNeedId =
    initial.affected_aggregate_ids.confirmed_need_batch_id;
  assert(
    initial.downstream_currentness === "CURRENT" && confirmedNeedId,
    "PLANNING-CONTRACT-01 initial generation did not materialize a current Confirmed Need.",
  );

  const correctedRows = [
    {
      ...pantryRows[0],
      requested_quantity: "2.500000",
      note: "Bổ sung đã điều chỉnh cho PLANNING-CONTRACT-01.",
      source_row_reference: "planning-contract-01-pantry:2",
    },
  ];
  const correctedPreview = await previewPantry(
    client,
    subject,
    weekStart,
    correctedRows,
  );
  const correctedSource = await invoke(
    client,
    "save_pantry",
    commandRequest(
      "PANTRY-02.v2",
      subject,
      pantrySave.new_versions.aggregate_version,
      "PANTRY_SAVED",
      {
        week_start: weekStart,
        no_additions_confirmed: false,
        source_signature: correctedPreview.source_signature,
        expected_source_signature: pantryPreview.source_signature,
        rows: correctedRows,
      },
      "Điều chỉnh nguồn Pantry sau khi nhu cầu đã được tạo.",
    ),
  );
  assert(
    correctedSource.downstream_currentness === "OUTDATED",
    "PLANNING-CONTRACT-01 source correction did not report OUTDATED.",
  );

  const outdated = await invoke(
    client,
    "get_planning_input_preflight",
    readRequest("RMVP-03B.v2", subject, {
      period_start: weekStart,
      period_end: weekStart,
    }),
  );
  assert(
    outdated.preflight.readiness_state === "READY" &&
      outdated.preflight.downstream_currentness === "OUTDATED",
    "PLANNING-CONTRACT-01 correction preflight was not READY/OUTDATED.",
  );

  const successor = await invoke(
    client,
    "execute_need_generation",
    commandRequest(
      "RMVP-04.v2",
      subject,
      initial.new_versions.need_generation_run_version,
      "UPSTREAM_SOURCE_CHANGED",
      {
        period_start: weekStart,
        period_end: weekStart,
        expected_current_need_generation_run_id: initialRunId,
      },
      "Cập nhật nhu cầu sau điều chỉnh Pantry.",
    ),
  );
  assert(
    successor.downstream_currentness === "CURRENT" &&
      successor.affected_aggregate_ids.need_generation_run_id !==
        initialRunId &&
      successor.affected_aggregate_ids.confirmed_need_batch_id ===
        confirmedNeedId &&
      successor.new_versions.confirmed_need_batch_version === 2,
    "PLANNING-CONTRACT-01 did not create the direct successor Confirmed Need correction.",
  );

  await client.auth.signOut({ scope: "local" });
  console.log(
    `Verified PLANNING-CONTRACT-01 browser-key source Saves, automatic preflight, Tạo nhu cầu, OUTDATED correction, and Cập nhật nhu cầu for ${weekStart}.`,
  );
}

try {
  await main();
} catch (error) {
  console.error(
    error instanceof Error
      ? error.message
      : "PLANNING-CONTRACT-01 local acceptance failed safely.",
  );
  process.exitCode = 1;
}
