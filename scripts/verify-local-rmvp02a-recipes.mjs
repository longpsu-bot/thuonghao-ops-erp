import { createClient } from "@supabase/supabase-js";
import { readLocalSupabaseStatus } from "./local-supabase-status.mjs";

const email = "atlas.pa06b.operator@local.test";
const password = "Atlas-PA06B-local-only!";

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function commandRequest(subject, expectedVersion, reasonCode, payload) {
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

async function invoke(client, name, request) {
  const { data, error } = await client
    .schema("atlas_api")
    .rpc(name, { request })
    .retry(false);
  if (error) {
    throw new Error(
      `RMVP-02A ${name} transport failed safely (${error.code ?? "UNKNOWN"}).`,
    );
  }
  if (!data || data.success !== true) {
    throw new Error(
      `RMVP-02A ${name} was rejected: ${data?.error_code ?? "UNKNOWN"}.`,
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
    throw new Error("RMVP-02A local acceptance sign-in failed.");
  }
  return data.session.user.id;
}

async function readWorkbench(client, subject) {
  const result = await invoke(client, "get_dish_recipe_workbench", {
    contract_version: "RMVP-02A.v1",
    requested_by_auth_subject: subject,
    correlation_id: crypto.randomUUID(),
    payload: {},
  });
  assert(result.workbench, "RMVP-02A workbench envelope was absent.");
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
  assert(ingredient, "RMVP-02A requires one active Ingredient reference.");
  assert(unit, "RMVP-02A requires one active Unit reference.");

  const suffix = crypto.randomUUID().slice(0, 8);
  const created = await invoke(
    client,
    "create_dish",
    commandRequest(subject, 1, "RMVP02A_ACCEPT_CREATE_DISH", {
      dish_code: `rmvp02a-accept-${suffix}`,
      dish_name: `RMVP-02A Acceptance ${suffix}`,
      dish_category: "Acceptance",
      operational_notes: "Local-only acceptance evidence",
      display_order: 9900,
      requires_need_generation: true,
    }),
  );
  const dishId = created.affected_aggregate_ids.dish_id;
  await invoke(
    client,
    "set_dish_lifecycle",
    commandRequest(subject, 1, "RMVP02A_ACCEPT_ACTIVATE_DISH", {
      dish_id: dishId,
      dish_status: "ACTIVE",
    }),
  );
  const draft = await invoke(
    client,
    "create_recipe_draft",
    commandRequest(subject, 2, "RMVP02A_ACCEPT_CREATE_DRAFT", {
      dish_id: dishId,
      school_type_id: null,
      basis_portions: 100,
    }),
  );
  const recipeVersionId = draft.affected_aggregate_ids.recipe_version_id;
  await invoke(
    client,
    "replace_recipe_draft_composition",
    commandRequest(subject, 1, "RMVP02A_ACCEPT_SAVE_BOM", {
      recipe_version_id: recipeVersionId,
      basis_portions: 100,
      lines: [
        {
          ingredient_id: ingredient.ingredient_id,
          quantity_per_basis: 12.5,
          unit_id: unit.unit_id,
          line_disposition: "PRESENT",
          operational_note: "Acceptance line",
          line_code: "acceptance-line",
        },
      ],
    }),
  );
  await invoke(
    client,
    "validate_recipe_version",
    commandRequest(subject, 2, "RMVP02A_ACCEPT_VALIDATE", {
      recipe_version_id: recipeVersionId,
    }),
  );
  await invoke(
    client,
    "release_recipe_version_for_planning",
    commandRequest(subject, 3, "RMVP02A_ACCEPT_RELEASE", {
      recipe_version_id: recipeVersionId,
    }),
  );

  const afterRelease = await readWorkbench(client, subject);
  const released = afterRelease.recipe_versions.find(
    (item) => item.recipe_version_id === recipeVersionId,
  );
  assert(
    released?.recipe_version_status === "RELEASED_FOR_PLANNING" &&
      released.composition.length === 1,
    "RMVP-02A release did not read back one authoritative planning composition.",
  );

  const signOut = await client.auth.signOut({ scope: "local" });
  if (signOut.error) throw new Error("RMVP-02A local sign-out failed.");
  const signedInAgainSubject = await signIn(client);
  assert(
    signedInAgainSubject === subject,
    "RMVP-02A sign-in restored a different subject.",
  );
  const afterSignIn = await readWorkbench(client, subject);
  assert(
    afterSignIn.recipe_versions.some(
      (item) =>
        item.recipe_version_id === recipeVersionId &&
        item.recipe_version_status === "RELEASED_FOR_PLANNING",
    ),
    "RMVP-02A planning release did not persist across sign-out and sign-in.",
  );
  await client.auth.signOut({ scope: "local" });
  console.log(
    "Verified RMVP-02A sign-in, Dish activation, draft BOM, validation, planning release, authoritative refresh, and persisted readback.",
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
