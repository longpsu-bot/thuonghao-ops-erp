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
    commandRequest(subject, 1, "RMVP02A_ACCEPT_CREATE_DISH", {
      dish_code: `rmvp02a-accept-${suffix}`,
      dish_name: `RMVP-02A Acceptance ${suffix}`,
      dish_category: "Acceptance",
      dish_type_id: dishType.dish_type_id,
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
  const released = requireVersion(
    afterRelease,
    recipeVersionId,
    "RMVP-02A initial planning release was absent from authoritative readback.",
  );
  assert(
    released.recipe_version_status === "RELEASED_FOR_PLANNING" &&
      released.composition.length === 1,
    "RMVP-02A release did not read back one authoritative planning composition.",
  );
  const initialComposition = structuredClone(released.composition);
  const initialLine = released.composition[0];
  assert(
    initialLine.recipe_line_id && initialLine.recipe_line_revision_id,
    "RMVP-02A initial validation did not materialize stable line and revision identities.",
  );

  const successorResult = await invoke(
    client,
    "create_recipe_successor_version",
    commandRequest(
      subject,
      released.version,
      "RMVP02A_ACCEPT_CREATE_SUCCESSOR",
      { recipe_version_id: recipeVersionId },
    ),
  );
  const successorVersionId =
    successorResult.affected_aggregate_ids.recipe_version_id;
  const afterSuccessor = await readWorkbench(client, subject);
  const successorDraft = requireVersion(
    afterSuccessor,
    successorVersionId,
    "RMVP-02A successor draft was absent from authoritative readback.",
  );
  assert(
    successorDraft.recipe_version_status === "DRAFT" &&
      successorDraft.predecessor_recipe_version_id === recipeVersionId,
    "RMVP-02A successor draft did not retain the exact version predecessor.",
  );
  assert(
    successorDraft.composition.length === 1 &&
      successorDraft.composition[0].recipe_line_id ===
        initialLine.recipe_line_id &&
      successorDraft.composition[0].predecessor_recipe_line_revision_id ===
        initialLine.recipe_line_revision_id,
    "RMVP-02A successor draft did not retain stable RecipeLine and revision predecessor identity.",
  );

  const correctedQuantity = 11.25;
  await invoke(
    client,
    "replace_recipe_draft_composition",
    commandRequest(
      subject,
      successorDraft.version,
      "RMVP02A_ACCEPT_CORRECT_STABLE_LINE",
      {
        recipe_version_id: successorVersionId,
        basis_portions: successorDraft.basis_portions,
        lines: successorDraft.composition.map((line) => ({
          recipe_line_id: line.recipe_line_id,
          predecessor_recipe_line_revision_id:
            line.predecessor_recipe_line_revision_id,
          ingredient_id: line.ingredient_id,
          quantity_per_basis: correctedQuantity,
          unit_id: line.unit_id,
          line_disposition: "PRESENT",
          operational_note: "Acceptance stable-line correction",
          line_code: line.line_code,
        })),
      },
    ),
  );
  const afterCorrection = await readWorkbench(client, subject);
  const correctedDraft = requireVersion(
    afterCorrection,
    successorVersionId,
    "RMVP-02A corrected successor draft was absent from authoritative readback.",
  );
  assert(
    correctedDraft.recipe_version_status === "DRAFT" &&
      correctedDraft.composition.length === 1 &&
      correctedDraft.composition[0].quantity_per_basis === correctedQuantity &&
      correctedDraft.composition[0].recipe_line_id ===
        initialLine.recipe_line_id &&
      correctedDraft.composition[0].predecessor_recipe_line_revision_id ===
        initialLine.recipe_line_revision_id,
    "RMVP-02A stable-line correction did not preserve exact draft lineage.",
  );

  await invoke(
    client,
    "validate_recipe_version",
    commandRequest(
      subject,
      correctedDraft.version,
      "RMVP02A_ACCEPT_VALIDATE_SUCCESSOR",
      { recipe_version_id: successorVersionId },
    ),
  );
  const afterSuccessorValidation = await readWorkbench(client, subject);
  const validatedSuccessor = requireVersion(
    afterSuccessorValidation,
    successorVersionId,
    "RMVP-02A validated successor was absent from authoritative readback.",
  );
  const validatedSuccessorLine = validatedSuccessor.composition[0];
  assert(
    validatedSuccessor.recipe_version_status === "VALIDATED" &&
      validatedSuccessorLine.recipe_line_id === initialLine.recipe_line_id &&
      validatedSuccessorLine.predecessor_recipe_line_revision_id ===
        initialLine.recipe_line_revision_id &&
      validatedSuccessorLine.recipe_line_revision_id,
    "RMVP-02A successor validation did not materialize the corrected stable-line revision.",
  );

  await invoke(
    client,
    "release_recipe_version_for_planning",
    commandRequest(
      subject,
      validatedSuccessor.version,
      "RMVP02A_ACCEPT_RELEASE_SUCCESSOR",
      { recipe_version_id: successorVersionId },
    ),
  );
  const afterSuccessorRelease = await readWorkbench(client, subject);
  const lockedPrior = requireVersion(
    afterSuccessorRelease,
    recipeVersionId,
    "RMVP-02A prior release was absent after successor release.",
  );
  const releasedSuccessor = requireVersion(
    afterSuccessorRelease,
    successorVersionId,
    "RMVP-02A released successor was absent from authoritative readback.",
  );
  assert(
    lockedPrior.recipe_version_status === "LOCKED",
    "RMVP-02A successor release did not lock the prior planning release.",
  );
  assertCompositionEqual(
    lockedPrior.composition,
    initialComposition,
    "RMVP-02A successor release changed the prior released composition.",
  );
  assert(
    releasedSuccessor.recipe_version_status === "RELEASED_FOR_PLANNING" &&
      releasedSuccessor.predecessor_recipe_version_id === recipeVersionId &&
      releasedSuccessor.composition[0].recipe_line_id ===
        initialLine.recipe_line_id &&
      releasedSuccessor.composition[0].predecessor_recipe_line_revision_id ===
        initialLine.recipe_line_revision_id &&
      releasedSuccessor.composition[0].quantity_per_basis === correctedQuantity,
    "RMVP-02A successor release did not preserve authoritative version and stable-line lineage.",
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
  const afterSignIn = await readWorkbench(client, subject);
  const persistedPrior = requireVersion(
    afterSignIn,
    recipeVersionId,
    "RMVP-02A prior version was absent after sign-out and sign-in.",
  );
  const persistedSuccessor = requireVersion(
    afterSignIn,
    successorVersionId,
    "RMVP-02A successor version was absent after sign-out and sign-in.",
  );
  assert(
    persistedPrior.recipe_version_status === "LOCKED" &&
      persistedSuccessor.recipe_version_status === "RELEASED_FOR_PLANNING" &&
      persistedSuccessor.predecessor_recipe_version_id === recipeVersionId,
    "RMVP-02A authoritative version lifecycle did not persist across sign-out and sign-in.",
  );
  assertCompositionEqual(
    persistedPrior.composition,
    initialComposition,
    "RMVP-02A prior composition changed across sign-out and sign-in.",
  );
  assert(
    persistedSuccessor.composition.length === 1 &&
      persistedSuccessor.composition[0].recipe_line_id ===
        initialLine.recipe_line_id &&
      persistedSuccessor.composition[0].predecessor_recipe_line_revision_id ===
        initialLine.recipe_line_revision_id &&
      persistedSuccessor.composition[0].quantity_per_basis ===
        correctedQuantity,
    "RMVP-02A successor composition lineage did not read back authoritatively after sign-in.",
  );
  await client.auth.signOut({ scope: "local" });
  console.log(
    "Verified RMVP-02A browser-key sign-in, initial release, successor stable-line correction, validation, release, prior locking and immutability, exact version/revision lineage, reauthentication, and authoritative two-version readback.",
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
