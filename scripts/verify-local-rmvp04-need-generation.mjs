import { fileURLToPath } from "node:url";
import { createClient } from "@supabase/supabase-js";
import {
  readLocalSupabaseStatus,
  runPinnedSupabase,
} from "./local-supabase-status.mjs";
import { installLocalFoundationNeedGenerationContract } from "./install-local-foundation-need-generation-contract.mjs";

const email = "atlas.pa06b.operator@local.test";
const password = "Atlas-PA06B-local-only!";
const rmvp05PantryIngredientId = "b6400000-0000-0000-0000-000000000050";

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
  reasonNote = "Bounded GitHub-only RMVP-04 browser-key acceptance.",
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

function readinessCommand(
  subject,
  expectedRootStatus,
  expectedEvaluationId,
  expectedEvaluationVersion,
  reasonCode,
  payload,
) {
  const commandId = crypto.randomUUID();
  return {
    contract_version: "RMVP-03B.v1",
    command_id: commandId,
    correlation_id: crypto.randomUUID(),
    idempotency_key: `${reasonCode.toLowerCase()}:${commandId}`,
    requested_by_auth_subject: subject,
    requested_at: new Date(Date.now() - 1000).toISOString(),
    expected_root_status: expectedRootStatus,
    expected_current_evaluation_id: expectedEvaluationId,
    expected_current_evaluation_version: expectedEvaluationVersion,
    reason_code: reasonCode,
    reason_note: null,
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
      `RMVP-04 ${name} transport failed safely (${error.code ?? "UNKNOWN"}: ${error.message ?? "no message"}).`,
    );
  }
  if (!data || data.success !== true) {
    throw new Error(
      `RMVP-04 ${name} was rejected: ${data?.error_code ?? "UNKNOWN"}.`,
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
    throw new Error("RMVP-04 local acceptance sign-in failed.");
  }
  return data.session.user.id;
}

function isoDate(date) {
  return date.toISOString().slice(0, 10);
}

function activeMenuRows(menu) {
  return menu.lines.filter((line) => line.line_status === "ACTIVE");
}

async function planningWorkbench(client, subject, weekStart) {
  const result = await invoke(
    client,
    "get_planning_inputs_workbench",
    readRequest("RMVP-03A.v1", subject, { week_start: weekStart }),
  );
  return result.workbench;
}

async function findApprovedPlanningWeek(client, subject) {
  const candidate = new Date();
  candidate.setUTCHours(0, 0, 0, 0);
  candidate.setUTCDate(
    candidate.getUTCDate() + ((8 - candidate.getUTCDay()) % 7) + 7 * 1040,
  );
  for (let offset = 0; offset < 26; offset += 1) {
    const weekStart = isoDate(candidate);
    const workbench = await planningWorkbench(client, subject, weekStart);
    if (
      workbench.weekly_menu?.weekly_menu_status === "APPROVED" &&
      workbench.attendance?.attendance_status === "APPROVED"
    ) {
      return { weekStart, workbench };
    }
    candidate.setUTCDate(candidate.getUTCDate() + 7);
  }
  throw new Error("RMVP-04 could not find the approved RMVP-03A local week.");
}

async function releasedRecipeDish(client, subject) {
  const result = await invoke(
    client,
    "get_dish_recipe_workbench",
    readRequest("RMVP-02A.v1", subject, {}),
  );
  const candidate = result.workbench.recipe_versions
    .map((version) => {
      const recipe = result.workbench.recipes.find(
        (item) => item.recipe_id === version.recipe_id,
      );
      const dish = result.workbench.dishes.find(
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
    candidate,
    "RMVP-04 requires an active released Recipe with an active Dish and usable composition.",
  );
  return candidate;
}

async function alignMenuToReleasedRecipe(
  client,
  subject,
  weekStart,
  workbench,
  dish,
) {
  const reopened = await invoke(
    client,
    "reopen_weekly_menu",
    commandRequest(
      "RMVP-03A.v1",
      subject,
      workbench.weekly_menu.version,
      "RMVP04_BROWSER_MENU_REOPEN",
      { week_start: weekStart },
    ),
  );
  const reopenedMenu = reopened.authoritative_readback.weekly_menu;
  const preview = await invoke(
    client,
    "preview_weekly_menu_import",
    readRequest("RMVP-03A.v1", subject, {
      week_start: weekStart,
      rows: activeMenuRows(reopenedMenu).map((line) => ({
        ...line,
        dish_id: dish.dish_id,
        source_row_reference: "rmvp04-browser-menu:1",
      })),
    }),
  );
  const saved = await invoke(
    client,
    "save_weekly_menu_draft",
    commandRequest(
      "RMVP-03A.v1",
      subject,
      reopenedMenu.version,
      "RMVP04_BROWSER_MENU_SAVE",
      {
        week_start: weekStart,
        source_type: "MANUAL_CORRECTION",
        source_name: "RMVP-04 released Recipe alignment",
        source_signature: preview.preview.source_signature,
        expected_source_signature: reopenedMenu.source_signature,
        rows: preview.preview.canonical_rows,
      },
    ),
  );
  const savedMenu = saved.authoritative_readback.weekly_menu;
  await invoke(
    client,
    "validate_weekly_menu",
    commandRequest(
      "RMVP-03A.v1",
      subject,
      savedMenu.version,
      "RMVP04_BROWSER_MENU_VALIDATE",
      { week_start: weekStart },
    ),
  );
  await invoke(
    client,
    "approve_weekly_menu",
    commandRequest(
      "RMVP-03A.v1",
      subject,
      savedMenu.version,
      "RMVP04_BROWSER_MENU_APPROVE",
      { week_start: weekStart },
    ),
  );
  const current = await planningWorkbench(client, subject, weekStart);
  assert(
    current.weekly_menu.weekly_menu_status === "APPROVED" &&
      activeMenuRows(current.weekly_menu).every(
        (line) => line.dish_id === dish.dish_id,
      ),
    "RMVP-04 did not obtain an approved Menu bound to the released Recipe.",
  );
  return current;
}

async function approvePositivePantry(
  client,
  subject,
  weekStart,
  schoolId,
  ingredientId,
) {
  const initial = await invoke(
    client,
    "get_pantry_source_workbench",
    readRequest("PANTRY-02.v1", subject, { week_start: weekStart }),
  );
  const school = initial.workbench.schools.find(
    (item) => item.school_id === schoolId,
  );
  const ingredient = initial.workbench.ingredients.find(
    (item) => item.ingredient_id === ingredientId,
  );
  const purpose = initial.workbench.purposes.find(
    (item) => item.purpose_code === "school_requested_supplement",
  );
  assert(
    school?.default_delivery_location?.delivery_location_id &&
      ingredient?.purchase_unit?.unit_id &&
      purpose,
    "RMVP-04 Pantry setup lacks exact School, Ingredient, Unit, Location, or Purpose evidence.",
  );
  const rows = [
    {
      service_date: weekStart,
      school_id: school.school_id,
      ingredient_id: ingredient.ingredient_id,
      pantry_need_purpose_id: purpose.pantry_need_purpose_id,
      requested_quantity: "1.250000",
      note: "Bổ sung tổng hợp cho kiểm thử RMVP-04.",
      source_request_reference: "RMVP-04-BROWSER",
      source_row_reference: "browser:1",
    },
  ];
  const preview = await invoke(
    client,
    "preview_pantry_source",
    readRequest("PANTRY-02.v1", subject, {
      week_start: weekStart,
      no_additions_confirmed: false,
      rows,
    }),
  );
  const saved = await invoke(
    client,
    "save_pantry_draft",
    commandRequest("PANTRY-02.v1", subject, 1, "RMVP04_BROWSER_PANTRY_SAVE", {
      week_start: weekStart,
      no_additions_confirmed: false,
      source_signature: preview.preview.source_signature,
      expected_source_signature: null,
      rows,
    }),
  );
  const batch = saved.workbench.batch;
  const validated = await invoke(
    client,
    "validate_pantry",
    commandRequest(
      "PANTRY-02.v1",
      subject,
      batch.version,
      "RMVP04_BROWSER_PANTRY_VALIDATE",
      {
        week_start: weekStart,
        expected_source_signature: batch.source_signature,
      },
    ),
  );
  const approved = await invoke(
    client,
    "approve_pantry",
    commandRequest(
      "PANTRY-02.v1",
      subject,
      validated.workbench.batch.version,
      "RMVP04_BROWSER_PANTRY_APPROVE",
      {
        week_start: weekStart,
        expected_source_signature: batch.source_signature,
      },
    ),
  );
  assert(
    approved.workbench.batch.pantry_need_batch_status === "APPROVED" &&
      approved.workbench.batch.approval_history[0].line_count === 1,
    "RMVP-04 did not obtain one positive approved Pantry line.",
  );
  return approved.workbench.batch;
}

async function main() {
  installLocalFoundationNeedGenerationContract();
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
  const approvedPlanning = await findApprovedPlanningWeek(client, subject);
  const recipe = await releasedRecipeDish(client, subject);
  const planning = await alignMenuToReleasedRecipe(
    client,
    subject,
    approvedPlanning.weekStart,
    approvedPlanning.workbench,
    recipe.dish,
  );
  const menuLine = activeMenuRows(planning.weekly_menu)[0];
  assert(menuLine, "RMVP-04 approved Menu contains no active line.");
  const recipeLine = recipe.version.composition.find(
    (line) =>
      line.line_disposition === "PRESENT" && line.quantity_per_basis > 0,
  );
  assert(recipeLine, "RMVP-04 released Recipe contains no positive line.");
  assert(
    recipeLine.ingredient_id !== rmvp05PantryIngredientId,
    "RMVP-04 recipe and RMVP-05 browser pantry fixtures must use distinct Ingredients.",
  );
  const pantry = await approvePositivePantry(
    client,
    subject,
    approvedPlanning.weekStart,
    menuLine.school_id,
    rmvp05PantryIngredientId,
  );
  const periodStart = menuLine.service_date;
  const periodEnd = menuLine.service_date;

  const readinessRead = await invoke(
    client,
    "get_planning_input_readiness_workbench",
    readRequest("RMVP-03B.v1", subject, {
      period_start: periodStart,
      period_end: periodEnd,
    }),
  );
  assert(
    readinessRead.workbench.decision === "NOT_EVALUATED",
    "RMVP-04 expected a fresh exact-period readiness root.",
  );
  const evaluation = await invoke(
    client,
    "evaluate_planning_input_readiness",
    readinessCommand(
      subject,
      "ABSENT",
      null,
      null,
      "READINESS_EVALUATION_REQUESTED",
      {
        period_start: periodStart,
        period_end: periodEnd,
        source_candidates: {
          weekly_menu: {
            weekly_menu_id: planning.weekly_menu.weekly_menu_id,
            weekly_menu_version: planning.weekly_menu.version,
            weekly_menu_approval_snapshot_id:
              planning.weekly_menu.latest_approval_snapshot_id,
          },
          attendance: {
            attendance_batch_id: planning.attendance.attendance_batch_id,
            attendance_version: planning.attendance.version,
            attendance_approval_snapshot_id:
              planning.attendance.latest_approval_snapshot_id,
          },
          pantry: {
            pantry_need_batch_id: pantry.pantry_need_batch_id,
            pantry_need_batch_version: pantry.version,
            pantry_need_approval_snapshot_id:
              pantry.latest_approval_snapshot_id,
          },
        },
      },
    ),
  );
  assert(
    evaluation.authoritative_readback.decision === "READY",
    "RMVP-04 source evaluation was not READY.",
  );
  const planningInputSetId =
    evaluation.affected_aggregate_ids.planning_input_set_id;
  const planningInputEvaluationId =
    evaluation.affected_aggregate_ids.planning_input_evaluation_id;
  const evaluationVersion = evaluation.new_versions.current_evaluation_version;
  const requested = await invoke(
    client,
    "request_planning_input_need_generation",
    readinessCommand(
      subject,
      "READY",
      planningInputEvaluationId,
      evaluationVersion,
      "NEED_GENERATION_HANDOFF_REQUESTED",
      {
        planning_input_set_id: planningInputSetId,
        period_start: periodStart,
        period_end: periodEnd,
      },
    ),
  );
  assert(
    requested.authoritative_readback.decision === "NEED_GENERATION_REQUESTED",
    "RMVP-04 readiness handoff was not requested.",
  );

  const created = await invoke(
    client,
    "create_need_generation_run",
    commandRequest(
      "RMVP-04.v1",
      subject,
      evaluationVersion,
      "NEED_GENERATION_CREATED",
      {
        planning_input_set_id: planningInputSetId,
        planning_input_evaluation_id: planningInputEvaluationId,
        period_start: periodStart,
        period_end: periodEnd,
      },
      null,
    ),
  );
  const runId = created.affected_aggregate_ids.need_generation_run_id;
  assert(
    created.authoritative_readback.selected_run.status === "GENERATED" &&
      created.authoritative_readback.selected_run.generated_line_count >= 2,
    "RMVP-04 generation did not create mixed atomic evidence.",
  );
  const validated = await invoke(
    client,
    "validate_need_generation_run",
    commandRequest(
      "RMVP-04.v1",
      subject,
      created.new_versions.need_generation_run_version,
      "NEED_GENERATION_VALIDATED",
      { need_generation_run_id: runId },
      null,
    ),
  );
  const released = await invoke(
    client,
    "release_need_generation_run",
    commandRequest(
      "RMVP-04.v1",
      subject,
      validated.new_versions.need_generation_run_version,
      "NEED_GENERATION_RELEASED",
      { need_generation_run_id: runId },
      null,
    ),
  );
  const materialized = await invoke(
    client,
    "create_confirmed_needs_from_generation",
    commandRequest("PA-06E-H0C.v1", subject, 1, "RMVP04_BROWSER_MATERIALIZE", {
      need_generation_run_id: runId,
      need_generation_run_version:
        released.new_versions.need_generation_run_version,
      confirmed_need_batch_id: null,
    }),
  );
  const finalRead = await invoke(
    client,
    "get_need_generation_workbench",
    readRequest("RMVP-04.v1", subject, {
      period_start: periodStart,
      period_end: periodEnd,
      need_generation_run_id: runId,
      filters: {},
      group_offset: 0,
      group_limit: 100,
    }),
  );
  const totals = finalRead.workbench.grouped_requirements.reduce(
    (result, group) => ({
      recipe: result.recipe + Number(group.recipe_derived_quantity),
      pantry: result.pantry + Number(group.pantry_direct_quantity),
    }),
    { recipe: 0, pantry: 0 },
  );
  assert(
    finalRead.workbench.selected_run.status === "RELEASED_FOR_CONFIRMATION" &&
      totals.recipe > 0 &&
      totals.pantry > 0 &&
      finalRead.workbench.materialization.confirmed_need_batch_id ===
        materialized.affected_aggregate_ids.confirmed_need_batch_id &&
      finalRead.workbench.materialization.confirmed_need_status ===
        "DRAFT_REVIEW",
    "RMVP-04 authoritative readback did not retain released mixed demand and CMD-15 state.",
  );
  await client.auth.signOut({ scope: "local" });
  console.log(
    `Verified RMVP-04 browser-key readiness/request/generate/validate/release/CMD-15/readback for ${periodStart}.`,
  );
}

try {
  await main();
} catch (error) {
  console.error(
    error instanceof Error
      ? error.message
      : "RMVP-04 local acceptance failed safely.",
  );
  process.exitCode = 1;
}
