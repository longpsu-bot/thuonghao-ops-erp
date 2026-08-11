import { createClient } from "@supabase/supabase-js";
import { readLocalSupabaseStatus } from "./local-supabase-status.mjs";

const email = "atlas.pa06b.operator@local.test";
const password = "Atlas-PA06B-local-only!";

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function requireVersion(workbench, recipeVersionId, message) {
  const version = workbench.recipe_versions.find(
    (item) => item.recipe_version_id === recipeVersionId,
  );
  assert(version, message);
  return version;
}

function assertCompositionEqual(actual, expected, message) {
  assert(JSON.stringify(actual) === JSON.stringify(expected), message);
}

function v1CommandRequest(subject, expectedVersion, reasonCode, payload) {
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

function workflowRequest(subject, expectedVersion, operation, payload) {
  const commandId = crypto.randomUUID();
  const reasonCode =
    operation === "save" ? "RECIPE_SAVED" : "RECIPE_PUT_INTO_USE";
  return {
    contract_version: "RMVP-02A.v2",
    command_id: commandId,
    correlation_id: crypto.randomUUID(),
    idempotency_key: `rmvp02a-v2:${operation}:${commandId}`,
    expected_version: expectedVersion,
    requested_by_auth_subject: subject,
    requested_at: new Date(Date.now() - 1000).toISOString(),
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
  assert(ingredient, "RMVP-02A requires one active Ingredient reference.");
  assert(unit, "RMVP-02A requires one active Unit reference.");
  assert(dishType, "RMVP-02A requires one active Dish Type reference.");

  const suffix = crypto.randomUUID().slice(0, 8);
  const created = await invoke(
    client,
    "create_dish",
    v1CommandRequest(subject, 1, "RMVP02A_V2_CREATE_DISH", {
      dish_code: `rmvp02a-v2-${suffix}`,
      dish_name: `RMVP-02A v2 ${suffix}`,
      dish_category: "Acceptance",
      dish_type_id: dishType.dish_type_id,
      operational_notes: "Local-only two-action acceptance evidence",
      display_order: 9900,
      requires_need_generation: true,
    }),
  );
  const dishId = created.affected_aggregate_ids.dish_id;
  await invoke(
    client,
    "set_dish_lifecycle",
    v1CommandRequest(subject, 1, "RMVP02A_V2_ACTIVATE_DISH", {
      dish_id: dishId,
      dish_status: "ACTIVE",
    }),
  );

  let selected = await readWorkbench(client, subject, {
    dish_id: dishId,
    school_type_id: null,
  });
  assert(
    selected.selected_recipe.business_status === "NOT_SAVED" &&
      selected.selected_recipe.allowed_actions.save_recipe === true &&
      selected.selected_recipe.allowed_actions.release_recipe === false,
    "RMVP-02A v2 did not authorize only Save for the new Dish scope.",
  );

  const stableLineId = crypto.randomUUID();
  const saveNew = await invoke(
    client,
    "save_recipe",
    workflowRequest(
      subject,
      selected.selected_recipe.expected_version,
      "save",
      {
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
      },
    ),
  );
  selected = saveNew.authoritative_readback;
  const firstVersionId = selected.selected_recipe.recipe_version_id;
  assert(
    firstVersionId &&
      selected.selected_recipe.business_status === "SAVED" &&
      selected.selected_recipe.basis_portions === 80 &&
      selected.selected_recipe.allowed_actions.release_recipe === true,
    "Save did not return the editable authoritative Recipe without release.",
  );

  const saveDraft = await invoke(
    client,
    "save_recipe",
    workflowRequest(
      subject,
      selected.selected_recipe.expected_version,
      "save",
      {
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
            operational_note: "Updated saved line",
          },
        ],
      },
    ),
  );
  selected = saveDraft.authoritative_readback;
  assert(
    selected.selected_recipe.recipe_version_id === firstVersionId &&
      selected.selected_recipe.basis_portions === 90,
    "Save did not reuse and replace the current editable draft.",
  );

  const firstRelease = await invoke(
    client,
    "release_recipe",
    workflowRequest(
      subject,
      selected.selected_recipe.expected_version,
      "release",
      { recipe_version_id: firstVersionId },
    ),
  );
  selected = firstRelease.authoritative_readback;
  const released = requireVersion(
    selected,
    firstVersionId,
    "The first put-into-use result omitted its Recipe evidence.",
  );
  assert(
    released.recipe_version_status === "RELEASED_FOR_PLANNING" &&
      released.validated_at &&
      released.released_at &&
      released.composition[0].recipe_line_revision_id,
    "Put into use did not validate, materialize, and release atomically.",
  );
  const initialComposition = structuredClone(released.composition);
  const initialRevisionId = released.composition[0].recipe_line_revision_id;

  const saveSuccessor = await invoke(
    client,
    "save_recipe",
    workflowRequest(
      subject,
      selected.selected_recipe.expected_version,
      "save",
      {
        dish_id: dishId,
        school_type_id: null,
        recipe_version_id: firstVersionId,
        basis_portions: 90,
        lines: [
          {
            recipe_line_id: stableLineId,
            ingredient_id: ingredient.ingredient_id,
            quantity_per_basis: 16,
            unit_id: unit.unit_id,
            operational_note: "Successor stable-line correction",
          },
        ],
      },
    ),
  );
  selected = saveSuccessor.authoritative_readback;
  const successorVersionId = selected.selected_recipe.recipe_version_id;
  const priorDuringEdit = requireVersion(
    selected,
    firstVersionId,
    "The prior released Recipe disappeared while editing its successor.",
  );
  const successorDraft = requireVersion(
    selected,
    successorVersionId,
    "Save after release did not return the internal successor draft.",
  );
  assert(
    successorVersionId !== firstVersionId,
    "Save reused a locked release.",
  );
  assertCompositionEqual(
    priorDuringEdit.composition,
    initialComposition,
    "Save after release changed prior immutable composition.",
  );
  assert(
    successorDraft.predecessor_recipe_version_id === firstVersionId &&
      successorDraft.composition[0].recipe_line_id === stableLineId &&
      successorDraft.composition[0].predecessor_recipe_line_revision_id ===
        initialRevisionId,
    "Save after release did not preserve exact version and stable-line lineage.",
  );

  const successorRelease = await invoke(
    client,
    "release_recipe",
    workflowRequest(
      subject,
      selected.selected_recipe.expected_version,
      "release",
      { recipe_version_id: successorVersionId },
    ),
  );
  selected = successorRelease.authoritative_readback;
  const lockedPrior = requireVersion(
    selected,
    firstVersionId,
    "The prior Recipe disappeared after successor release.",
  );
  const releasedSuccessor = requireVersion(
    selected,
    successorVersionId,
    "The released successor was absent from authoritative readback.",
  );
  assert(
    lockedPrior.recipe_version_status === "LOCKED" &&
      releasedSuccessor.recipe_version_status === "RELEASED_FOR_PLANNING",
    "Successor put-into-use did not lock the prior release and become current.",
  );
  assertCompositionEqual(
    lockedPrior.composition,
    initialComposition,
    "Successor put-into-use changed the prior released composition.",
  );

  const signOut = await client.auth.signOut({ scope: "local" });
  if (signOut.error) throw new Error("RMVP-02A local sign-out failed.");
  const signedOutSession = await client.auth.getSession();
  assert(
    !signedOutSession.error && !signedOutSession.data.session,
    "RMVP-02A local sign-out did not clear the browser client session.",
  );
  const signedInAgainSubject = await signIn(client);
  assert(
    signedInAgainSubject === subject,
    "RMVP-02A sign-in restored a different subject.",
  );
  const persisted = await readWorkbench(client, subject, {
    dish_id: dishId,
    school_type_id: null,
  });
  assert(
    requireVersion(
      persisted,
      firstVersionId,
      "Prior version was not persisted.",
    ).recipe_version_status === "LOCKED" &&
      requireVersion(
        persisted,
        successorVersionId,
        "Successor version was not persisted.",
      ).recipe_version_status === "RELEASED_FOR_PLANNING",
    "The two-action Recipe lifecycle did not persist across reauthentication.",
  );
  await client.auth.signOut({ scope: "local" });
  console.log(
    "Verified RMVP-02A browser-key sign-in, backend eligibility, Save-new, Save-existing, atomic put-into-use, internal successor creation, stable-line lineage, prior immutability, successor release, and authoritative reauthentication readback.",
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
