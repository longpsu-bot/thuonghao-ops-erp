import { createHash } from "node:crypto";
import { createClient } from "@supabase/supabase-js";
import { readLocalSupabaseStatus } from "./local-supabase-status.mjs";

const email = "atlas.pa06b.operator@local.test";
const password = "Atlas-PA06B-local-only!";

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function v1Request(subject, expectedVersion, reasonCode, payload) {
  const commandId = crypto.randomUUID();
  return {
    contract_version: "RMVP-02A.v1",
    command_id: commandId,
    correlation_id: crypto.randomUUID(),
    idempotency_key: `${reasonCode.toLowerCase()}:${commandId}`,
    expected_version: expectedVersion,
    requested_by_auth_subject: subject,
    requested_at: new Date(Date.now() - 1000).toISOString(),
    reason_code: reasonCode,
    reason_note: "Bounded local RMVP-02A acceptance.",
    payload,
  };
}

function saveRequest(subject, expectedVersion, payload) {
  const commandId = crypto.randomUUID();
  return {
    contract_version: "RMVP-02A.v2",
    command_id: commandId,
    correlation_id: crypto.randomUUID(),
    idempotency_key: `rmvp02a-v2:save:${commandId}`,
    expected_version: expectedVersion,
    requested_by_auth_subject: subject,
    requested_at: new Date(Date.now() - 1000).toISOString(),
    reason_code: "RECIPE_SAVED",
    reason_note: null,
    payload,
  };
}

function planningReadRequest(subject, payload) {
  return {
    contract_version: "RMVP-03A.v1",
    requested_by_auth_subject: subject,
    correlation_id: crypto.randomUUID(),
    payload,
  };
}

function planningCommandRequest(subject, expectedVersion, reasonCode, payload) {
  const commandId = crypto.randomUUID();
  return {
    contract_version: "RMVP-03A.v1",
    command_id: commandId,
    correlation_id: crypto.randomUUID(),
    idempotency_key: `${reasonCode.toLowerCase()}:${commandId}`,
    expected_version: expectedVersion,
    requested_by_auth_subject: subject,
    requested_at: new Date(Date.now() - 1000).toISOString(),
    reason_code: reasonCode,
    reason_note: "Bounded local approved-menu lock evidence.",
    payload,
  };
}

async function invoke(client, name, request) {
  const { data, error } = await client
    .schema("atlas_api")
    .rpc(name, { request })
    .retry(false);
  if (error)
    throw new Error(
      `RMVP-02A ${name} transport failed safely (${error.code ?? "UNKNOWN"}).`,
    );
  if (!data || data.success !== true)
    throw new Error(
      `RMVP-02A ${name} was rejected: ${data?.error_code ?? "UNKNOWN"}.`,
    );
  return data;
}

async function invokeDenied(client, name, request) {
  const { data, error } = await client
    .schema("atlas_api")
    .rpc(name, { request })
    .retry(false);
  if (error)
    throw new Error(
      `RMVP-02A ${name} denial had a transport failure (${error.code ?? "UNKNOWN"}).`,
    );
  assert(
    data?.success === false &&
      data.error_code === "INVARIANT_VIOLATION" &&
      data.safe_message ===
        "Món này đã có trong thực đơn đã duyệt. Muốn thay đổi công thức, hãy dùng Điều chỉnh.",
    `RMVP-02A ${name} did not return the canonical approved-menu denial.`,
  );
  return data;
}

async function signIn(client) {
  const { data, error } = await client.auth.signInWithPassword({
    email,
    password,
  });
  if (error || !data.session)
    throw new Error("RMVP-02A local acceptance sign-in failed.");
  return data.session.user.id;
}

async function readWorkbench(client, subject, selection = {}) {
  const result = await invoke(client, "get_dish_recipe_workbench", {
    contract_version: "RMVP-02A.v2",
    requested_by_auth_subject: subject,
    correlation_id: crypto.randomUUID(),
    payload: selection,
  });
  assert(result.workbench, "RMVP-02A v2 workbench envelope was absent.");
  return result.workbench;
}

async function readPlanningWorkbench(client, subject, weekStart) {
  const result = await invoke(
    client,
    "get_planning_inputs_workbench",
    planningReadRequest(subject, { week_start: weekStart }),
  );
  return result.workbench;
}

function recipeCompositionEvidence(workbench, dishId) {
  const recipeIds = new Set(
    workbench.recipes
      .filter((recipe) => recipe.dish_id === dishId)
      .map((recipe) => recipe.recipe_id),
  );
  const selected = workbench.selected_recipe;
  return JSON.stringify({
    recipeScopes: workbench.recipes
      .filter((recipe) => recipeIds.has(recipe.recipe_id))
      .map((recipe) => ({
        recipe_id: recipe.recipe_id,
        dish_id: recipe.dish_id,
        school_type_id: recipe.school_type_id,
      })),
    versions: workbench.recipe_versions.filter((version) =>
      recipeIds.has(version.recipe_id),
    ),
    selected: {
      dish_id: selected.dish_id,
      school_type_id: selected.school_type_id,
      recipe_id: selected.recipe_id,
      recipe_version_id: selected.recipe_version_id,
      in_use_recipe_version_id: selected.in_use_recipe_version_id,
      basis_portions: selected.basis_portions,
      composition: selected.composition,
    },
  });
}

function isoDate(date) {
  return date.toISOString().slice(0, 10);
}

async function findEmptyFutureMonday(client, subject) {
  const candidate = new Date();
  candidate.setUTCHours(0, 0, 0, 0);
  const daysUntilMonday = (8 - candidate.getUTCDay()) % 7;
  candidate.setUTCDate(candidate.getUTCDate() + daysUntilMonday + 7 * 1200);
  for (let offset = 0; offset < 26; offset += 1) {
    const weekStart = isoDate(candidate);
    const workbench = await readPlanningWorkbench(client, subject, weekStart);
    if (!workbench.weekly_menu) return { weekStart, workbench };
    candidate.setUTCDate(candidate.getUTCDate() + 7);
  }
  throw new Error("RMVP-02A could not find an unused future Menu week.");
}

async function main() {
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
  const initial = await readWorkbench(client, subject);
  const ingredient = initial.ingredients.find(
    (item) => item.ingredient_status === "ACTIVE",
  );
  const unit = initial.units.find((item) => item.unit_status === "ACTIVE");
  const dishType = initial.dish_types.find(
    (item) => item.dish_type_status === "ACTIVE",
  );
  assert(
    ingredient && unit && dishType,
    "Active Recipe references are required.",
  );

  const suffix = crypto.randomUUID().slice(0, 8);
  const dishCode = `rmvp02a-v2-${suffix}`;
  const created = await invoke(
    client,
    "create_dish",
    v1Request(subject, 1, "RMVP02A_V2_CREATE_DISH", {
      dish_code: dishCode,
      dish_name: `RMVP-02A v2 ${suffix}`,
      dish_category: "Acceptance",
      dish_type_id: dishType.dish_type_id,
      operational_notes: "Local-only creation-and-lock acceptance evidence",
      display_order: 9900,
      requires_need_generation: true,
    }),
  );
  const dishId = created.affected_aggregate_ids.dish_id;
  await invoke(
    client,
    "set_dish_lifecycle",
    v1Request(subject, 1, "RMVP02A_V2_ACTIVATE_DISH", {
      dish_id: dishId,
      dish_status: "ACTIVE",
    }),
  );

  let workbench = await readWorkbench(client, subject, {
    dish_id: dishId,
    school_type_id: null,
  });
  let selected = workbench.selected_recipe;
  assert(
    selected.business_status === "NOT_SAVED" &&
      selected.locked_for_normal_editing === false &&
      selected.allowed_actions.save_recipe === true,
    "A new Dish was not editable before operational use.",
  );

  const stableLineId = crypto.randomUUID();
  const firstSave = await invoke(
    client,
    "save_recipe",
    saveRequest(subject, selected.expected_version, {
      dish_id: dishId,
      school_type_id: null,
      recipe_version_id: null,
      basis_portions: 80,
      lines: [
        {
          recipe_line_id: stableLineId,
          ingredient_id: ingredient.ingredient_id,
          quantity_per_basis: 12.5,
          unit_id: unit.unit_id,
          operational_note: "Initial saved line",
        },
      ],
    }),
  );
  workbench = firstSave.authoritative_readback;
  selected = workbench.selected_recipe;
  const firstVersionId = selected.recipe_version_id;
  const firstVersion = workbench.recipe_versions.find(
    (item) => item.recipe_version_id === firstVersionId,
  );
  assert(
    firstVersionId &&
      selected.business_status === "AVAILABLE" &&
      selected.locked_for_normal_editing === false &&
      selected.basis_portions === 80 &&
      firstVersion?.recipe_version_status === "RELEASED_FOR_PLANNING" &&
      firstVersion.composition[0]?.recipe_line_revision_id,
    "One creation Save did not materialize and make the Recipe available.",
  );

  const secondSave = await invoke(
    client,
    "save_recipe",
    saveRequest(subject, selected.expected_version, {
      dish_id: dishId,
      school_type_id: null,
      recipe_version_id: firstVersionId,
      basis_portions: 90,
      lines: [
        {
          recipe_line_id: stableLineId,
          ingredient_id: ingredient.ingredient_id,
          quantity_per_basis: 14,
          unit_id: unit.unit_id,
          operational_note: "Pre-use correction",
        },
      ],
    }),
  );
  workbench = secondSave.authoritative_readback;
  selected = workbench.selected_recipe;
  const secondVersionId = selected.recipe_version_id;
  const prior = workbench.recipe_versions.find(
    (item) => item.recipe_version_id === firstVersionId,
  );
  const current = workbench.recipe_versions.find(
    (item) => item.recipe_version_id === secondVersionId,
  );
  assert(
    secondVersionId !== firstVersionId &&
      selected.business_status === "AVAILABLE" &&
      selected.locked_for_normal_editing === false &&
      selected.basis_portions === 90 &&
      prior?.recipe_version_status === "LOCKED" &&
      current?.recipe_version_status === "RELEASED_FOR_PLANNING" &&
      current.predecessor_recipe_version_id === firstVersionId &&
      current.composition[0]?.recipe_line_id === stableLineId,
    "Pre-use Save did not preserve lineage while advancing available composition.",
  );

  await client.auth.signOut({ scope: "local" });
  assert(
    !(await client.auth.getSession()).data.session,
    "RMVP-02A sign-out did not clear the browser session.",
  );
  assert(
    (await signIn(client)) === subject,
    "Reauthentication changed subject.",
  );
  const persisted = await readWorkbench(client, subject, {
    dish_id: dishId,
    school_type_id: null,
  });
  assert(
    persisted.selected_recipe.recipe_version_id === secondVersionId &&
      persisted.selected_recipe.business_status === "AVAILABLE" &&
      persisted.selected_recipe.locked_for_normal_editing === false,
    "Creation Save did not persist authoritative readback across sign-in.",
  );

  const { weekStart, workbench: planning } = await findEmptyFutureMonday(
    client,
    subject,
  );
  const school = planning.schools.find(
    (item) => item.school_status === "ACTIVE",
  );
  assert(school, "Approved-menu lock evidence requires one active School.");
  const menuPreview = await invoke(
    client,
    "preview_weekly_menu_import",
    planningReadRequest(subject, {
      week_start: weekStart,
      rows: [
        {
          school_id: school.school_id,
          service_date: weekStart,
          menu_slot_code: dishType.dish_type_code,
          dish_id: dishId,
          source_row_reference: "rmvp02a-lock:2",
        },
      ],
    }),
  );
  assert(
    menuPreview.preview.can_save &&
      menuPreview.preview.canonical_rows.length === 1,
    "Approved-menu lock preview was not saveable.",
  );
  await invoke(
    client,
    "save_weekly_menu_draft",
    planningCommandRequest(subject, 1, "RMVP02A_LOCK_MENU_SAVE", {
      week_start: weekStart,
      source_type: "BULK_PASTE",
      source_name: "RMVP-02A lock journey",
      source_signature: menuPreview.preview.source_signature,
      expected_source_signature: null,
      rows: menuPreview.preview.canonical_rows,
    }),
  );
  await invoke(
    client,
    "validate_weekly_menu",
    planningCommandRequest(subject, 1, "RMVP02A_LOCK_MENU_VALIDATE", {
      week_start: weekStart,
    }),
  );
  const approval = await invoke(
    client,
    "approve_weekly_menu",
    planningCommandRequest(subject, 1, "RMVP02A_LOCK_MENU_APPROVE", {
      week_start: weekStart,
    }),
  );
  assert(
    approval.authoritative_readback.weekly_menu.latest_approval_snapshot_id,
    "Weekly Menu approval did not create lock evidence.",
  );

  const locked = await readWorkbench(client, subject, {
    dish_id: dishId,
    school_type_id: null,
  });
  const lockedSelection = locked.selected_recipe;
  const lockedDish = locked.dishes.find((item) => item.dish_id === dishId);
  const lockedRoot = locked.recipes.find(
    (item) => item.recipe_id === lockedSelection.recipe_id,
  );
  assert(
    lockedSelection.business_status === "LOCKED" &&
      lockedSelection.locked_for_normal_editing === true &&
      lockedSelection.allowed_actions.save_recipe === false &&
      lockedDish &&
      lockedRoot,
    "Approved Menu evidence did not lock the Dish-wide Recipe readback.",
  );
  const lockedEvidence = JSON.stringify({
    versions: locked.recipe_versions,
    selected: lockedSelection,
    dish: lockedDish,
    root: lockedRoot,
  });
  const lockedCompositionEvidence = recipeCompositionEvidence(locked, dishId);

  await invokeDenied(
    client,
    "save_recipe",
    saveRequest(subject, lockedSelection.expected_version, {
      dish_id: dishId,
      school_type_id: null,
      recipe_version_id: secondVersionId,
      basis_portions: 100,
      lines: [
        {
          recipe_line_id: stableLineId,
          ingredient_id: ingredient.ingredient_id,
          quantity_per_basis: 99,
          unit_id: unit.unit_id,
          operational_note: "must not save after approved Menu use",
        },
      ],
    }),
  );
  await invokeDenied(
    client,
    "copy_recipe_version",
    v1Request(subject, lockedDish.version, "RMVP02A_LOCK_COPY", {
      source_recipe_version_id: secondVersionId,
      target_dish_id: dishId,
      target_school_type_id: null,
    }),
  );
  const canonicalJson = JSON.stringify({
    rows: [
      {
        legacy_line_id: `ops-v1:line:${dishCode}:ingredient`,
        dish_legacy_id: `ops-v1:dish:${dishCode}`,
        recipe_legacy_id: `ops-v1:recipe:${dishCode}:general`,
        dish_code: dishCode,
        dish_name: "must not change through import",
        dish_category: "Acceptance",
        requires_need_generation: true,
        school_type_id: null,
        basis_portions: 100,
        ingredient_id: ingredient.ingredient_id,
        quantity_per_basis: 99,
        unit_id: unit.unit_id,
        operational_note: "must not import after approved Menu use",
      },
    ],
  });
  await invokeDenied(
    client,
    "apply_recipe_import",
    v1Request(subject, lockedDish.version, "RMVP02A_LOCK_IMPORT", {
      canonical_json: canonicalJson,
      workbook_checksum: createHash("sha256")
        .update(canonicalJson, "utf8")
        .digest("hex"),
    }),
  );

  const afterDenials = await readWorkbench(client, subject, {
    dish_id: dishId,
    school_type_id: null,
  });
  assert(
    JSON.stringify({
      versions: afterDenials.recipe_versions,
      selected: afterDenials.selected_recipe,
      dish: afterDenials.dishes.find((item) => item.dish_id === dishId),
      root: afterDenials.recipes.find(
        (item) => item.recipe_id === lockedSelection.recipe_id,
      ),
    }) === lockedEvidence,
    "A denied post-lock command changed base Recipe evidence.",
  );

  const lifecycle = await invoke(
    client,
    "set_recipe_lifecycle",
    v1Request(subject, lockedRoot.version, "RMVP02A_LOCK_LIFECYCLE", {
      recipe_id: lockedRoot.recipe_id,
      recipe_status: "INACTIVE",
    }),
  );
  const lifecycleReadbackRoot = lifecycle.authoritative_readback.recipes.find(
    (recipe) => recipe.recipe_id === lockedRoot.recipe_id,
  );
  assert(
    lifecycle.success === true &&
      lifecycle.idempotency_status === "COMPLETED" &&
      lifecycle.new_versions?.aggregate_version === lockedRoot.version + 1 &&
      lifecycle.emitted_event_ids?.length === 1 &&
      lifecycle.emitted_event_ids[0] &&
      lifecycle.audit_event_ids?.length === 1 &&
      lifecycle.audit_event_ids[0] &&
      lifecycleReadbackRoot?.recipe_status === "INACTIVE" &&
      lifecycleReadbackRoot.version === lockedRoot.version + 1,
    "Post-lock Recipe lifecycle administration lacked authoritative success, version, event, audit, or readback evidence.",
  );

  const afterLifecycle = await readWorkbench(client, subject, {
    dish_id: dishId,
    school_type_id: null,
  });
  const afterLifecycleSelection = afterLifecycle.selected_recipe;
  const afterLifecycleRoot = afterLifecycle.recipes.find(
    (recipe) => recipe.recipe_id === lockedRoot.recipe_id,
  );
  assert(
    afterLifecycleRoot?.recipe_status === "INACTIVE" &&
      afterLifecycleRoot.version === lockedRoot.version + 1 &&
      afterLifecycleSelection.locked_for_normal_editing === true &&
      afterLifecycleSelection.allowed_actions.save_recipe === false &&
      recipeCompositionEvidence(afterLifecycle, dishId) ===
        lockedCompositionEvidence,
    "Recipe lifecycle administration changed composition or reopened normal editing.",
  );

  await invokeDenied(
    client,
    "save_recipe",
    saveRequest(subject, afterLifecycleSelection.expected_version, {
      dish_id: dishId,
      school_type_id: null,
      recipe_version_id: secondVersionId,
      basis_portions: 100,
      lines: [
        {
          recipe_line_id: stableLineId,
          ingredient_id: ingredient.ingredient_id,
          quantity_per_basis: 99,
          unit_id: unit.unit_id,
          operational_note: "must remain locked after lifecycle administration",
        },
      ],
    }),
  );
  const finalLocked = await readWorkbench(client, subject, {
    dish_id: dishId,
    school_type_id: null,
  });
  assert(
    finalLocked.selected_recipe.locked_for_normal_editing === true &&
      finalLocked.selected_recipe.allowed_actions.save_recipe === false &&
      recipeCompositionEvidence(finalLocked, dishId) ===
        lockedCompositionEvidence,
    "Recipe lifecycle administration silently reopened or changed locked composition.",
  );
  await client.auth.signOut({ scope: "local" });
  console.log(
    "Verified RMVP-02A browser-key pre-use creation/Save and availability, approved-menu Dish lock, Save/copy/import denial with zero base composition mutation, successful Recipe lifecycle administration with event/audit evidence, and the unchanged post-lifecycle composition lock.",
  );
}

try {
  await main();
} catch (error) {
  console.error(
    error instanceof Error
      ? error.message
      : "RMVP-02A local acceptance failed safely.",
  );
  process.exitCode = 1;
}
