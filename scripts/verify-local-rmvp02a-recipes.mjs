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
  const created = await invoke(
    client,
    "create_dish",
    v1Request(subject, 1, "RMVP02A_V2_CREATE_DISH", {
      dish_code: `rmvp02a-v2-${suffix}`,
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
  await client.auth.signOut({ scope: "local" });
  console.log(
    "Verified RMVP-02A browser-key sign-in, pre-use eligibility, one-command creation Save, automatic Planning availability, pre-use lineage/immutability, no release action, and authoritative reauthentication readback.",
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
