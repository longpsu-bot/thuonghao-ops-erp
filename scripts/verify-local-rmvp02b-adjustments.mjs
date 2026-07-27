import { fileURLToPath } from "node:url";
import { createClient } from "@supabase/supabase-js";
import {
  readLocalSupabaseStatus,
  runPinnedSupabase,
} from "./local-supabase-status.mjs";

const email = "atlas.pa06b.operator@local.test";
const password = "Atlas-PA06B-local-only!";
const schoolId = "b6200000-0000-0000-0000-000000000120";
const baseIngredientId = "b6200000-0000-0000-0000-000000000210";
const substituteIngredientId = "b6200000-0000-0000-0000-000000000211";
const ingredientIds = {
  baseB: "b6200000-0000-0000-0000-000000000212",
  substituteB: "b6200000-0000-0000-0000-000000000213",
  baseC: "b6200000-0000-0000-0000-000000000214",
  substituteC: "b6200000-0000-0000-0000-000000000215",
  baseD: "b6200000-0000-0000-0000-000000000216",
  baseE: "b6200000-0000-0000-0000-000000000217",
  baseF: "b6200000-0000-0000-0000-000000000218",
  substituteF: "b6200000-0000-0000-0000-000000000219",
  systemAdd: "b6200000-0000-0000-0000-000000000220",
  schoolDishAdd: "b6200000-0000-0000-0000-000000000221",
};
const unitId = "b6200000-0000-0000-0000-000000000200";

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function isoDate(offsetDays = 0) {
  const date = new Date();
  date.setUTCDate(date.getUTCDate() + offsetDays);
  return date.toISOString().slice(0, 10);
}

function commandRequest(subject, expectedVersion, reasonCode, payload) {
  const commandId = crypto.randomUUID();
  return {
    contract_version: "RMVP-02B.v1",
    command_id: commandId,
    correlation_id: crypto.randomUUID(),
    idempotency_key: `${reasonCode.toLowerCase()}:${commandId}`,
    expected_version: expectedVersion,
    requested_by_auth_subject: subject,
    requested_at: new Date(Date.now() - 1000).toISOString(),
    reason_code: reasonCode,
    reason_note: "Bounded browser-key RMVP-02B local acceptance.",
    payload,
  };
}

function recipeCommandRequest(subject, expectedVersion, reasonCode, payload) {
  const request = commandRequest(subject, expectedVersion, reasonCode, payload);
  return { ...request, contract_version: "RMVP-02A.v1" };
}

function readRequest(subject, contractVersion, payload) {
  return {
    contract_version: contractVersion,
    correlation_id: crypto.randomUUID(),
    requested_by_auth_subject: subject,
    payload,
  };
}

async function rpc(client, name, request) {
  const { data, error } = await client
    .schema("atlas_api")
    .rpc(name, { request })
    .retry(false);
  if (error) {
    throw new Error(
      `RMVP-02B ${name} transport failed safely (${error.code ?? "UNKNOWN"}).`,
    );
  }
  return data;
}

async function invoke(client, name, request) {
  const data = await rpc(client, name, request);
  if (!data || data.success !== true) {
    throw new Error(
      `RMVP-02B ${name} was rejected: ${data?.error_code ?? "UNKNOWN"}.`,
    );
  }
  return data;
}

async function expectError(client, name, request, code) {
  const data = await rpc(client, name, request);
  assert(
    data?.success === false && data.error_code === code,
    `RMVP-02B ${name} did not fail closed with ${code}.`,
  );
}

function installFixture() {
  const fixturePath = fileURLToPath(
    new URL(
      "../supabase/local/rmvp_02b_acceptance_fixture.sql",
      import.meta.url,
    ),
  );
  runPinnedSupabase(["db", "query", "--local", "--file", fixturePath], {
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
      "RMVP-02B local acceptance sign-in failed. Run pnpm local:auth:provision first.",
    );
  }
  return data.session.user.id;
}

function recipeVersion(workbench, recipeVersionId) {
  const version = workbench.recipe_versions.find(
    (item) => item.recipe_version_id === recipeVersionId,
  );
  assert(version, "The released acceptance RecipeVersion was not returned.");
  return version;
}

function resolvedLine(response, recipeLineId) {
  const line = response.resolution?.lines?.find(
    (item) => item.base_recipe_line_id === recipeLineId,
  );
  assert(line, "The stable acceptance RecipeLine was not resolved.");
  return line;
}

async function previewAndCreateRule(
  client,
  subject,
  tag,
  schoolId,
  dishId,
  asOfDate,
  proposedAdjustment,
) {
  const preview = await invoke(
    client,
    "preview_recipe_composition_adjustment",
    readRequest(subject, "RMVP-02B.v1", {
      as_of_date: asOfDate,
      school_id: schoolId,
      dish_id: dishId,
      proposed_adjustment: {
        ...proposedAdjustment,
        reason_code: `RMVP02B_MATRIX_${tag}`,
        reason_note: `Authenticated ${tag} matrix preview.`,
        source_evidence: {
          source: "browser-key-acceptance-matrix",
          matrix_case: tag,
        },
      },
    }),
  );
  assert(
    preview.preview?.can_save === true &&
      preview.preview.before.status === "READY" &&
      preview.preview.after.status === "READY",
    `The authenticated ${tag} preview was not saveable.`,
  );
  const created = await invoke(
    client,
    "create_recipe_composition_adjustment",
    commandRequest(subject, 1, `RMVP02B_MATRIX_${tag}`, {
      ...proposedAdjustment,
      as_of_date: asOfDate,
      preview_school_id: schoolId,
      preview_dish_id: dishId,
      source_evidence: {
        source: "browser-key-acceptance-matrix",
        matrix_case: tag,
      },
    }),
  );
  assert(
    created.affected_aggregate_ids.recipe_composition_adjustment_id ===
      proposedAdjustment.adjustment_id,
    `The authenticated ${tag} rule was not persisted.`,
  );
}

async function main() {
  installFixture();
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
  const suffix = crypto.randomUUID().slice(0, 8);

  const createdDish = await invoke(
    client,
    "create_dish",
    recipeCommandRequest(subject, 1, "RMVP02B_ACCEPT_CREATE_DISH", {
      dish_code: `rmvp02b-accept-${suffix}`,
      dish_name: `RMVP-02B Acceptance ${suffix}`,
      dish_category: "Acceptance",
      operational_notes: "Local browser-key acceptance fixture",
      display_order: 7000 + Number.parseInt(suffix.slice(0, 3), 16),
      requires_need_generation: true,
    }),
  );
  const dishId = createdDish.affected_aggregate_ids.dish_id;
  await invoke(
    client,
    "set_dish_lifecycle",
    recipeCommandRequest(subject, 1, "RMVP02B_ACCEPT_ACTIVATE_DISH", {
      dish_id: dishId,
      dish_status: "ACTIVE",
    }),
  );
  const draft = await invoke(
    client,
    "create_recipe_draft",
    recipeCommandRequest(subject, 2, "RMVP02B_ACCEPT_CREATE_RECIPE", {
      dish_id: dishId,
      school_type_id: null,
      basis_portions: 100,
    }),
  );
  const recipeVersionId = draft.affected_aggregate_ids.recipe_version_id;
  await invoke(
    client,
    "replace_recipe_draft_composition",
    recipeCommandRequest(subject, 1, "RMVP02B_ACCEPT_BASE_BOM", {
      recipe_version_id: recipeVersionId,
      basis_portions: 100,
      lines: [
        {
          ingredient_id: baseIngredientId,
          quantity_per_basis: 5,
          unit_id: unitId,
          line_disposition: "PRESENT",
          operational_note: "RMVP-02B browser-key base line",
          line_code: "acceptance-base-a",
        },
        {
          ingredient_id: ingredientIds.baseB,
          quantity_per_basis: 6,
          unit_id: unitId,
          line_disposition: "PRESENT",
          operational_note: "RMVP-02B browser-key base line B",
          line_code: "acceptance-base-b",
        },
        {
          ingredient_id: ingredientIds.baseC,
          quantity_per_basis: 7,
          unit_id: unitId,
          line_disposition: "PRESENT",
          operational_note: "RMVP-02B browser-key base line C",
          line_code: "acceptance-base-c",
        },
        {
          ingredient_id: ingredientIds.baseD,
          quantity_per_basis: 8,
          unit_id: unitId,
          line_disposition: "PRESENT",
          operational_note: "RMVP-02B browser-key base line D",
          line_code: "acceptance-base-d",
        },
        {
          ingredient_id: ingredientIds.baseE,
          quantity_per_basis: 9,
          unit_id: unitId,
          line_disposition: "PRESENT",
          operational_note: "RMVP-02B browser-key base line E",
          line_code: "acceptance-base-e",
        },
        {
          ingredient_id: ingredientIds.baseF,
          quantity_per_basis: 10,
          unit_id: unitId,
          line_disposition: "PRESENT",
          operational_note: "RMVP-02B browser-key base line F",
          line_code: "acceptance-base-f",
        },
      ],
    }),
  );
  await invoke(
    client,
    "validate_recipe_version",
    recipeCommandRequest(subject, 2, "RMVP02B_ACCEPT_VALIDATE_RECIPE", {
      recipe_version_id: recipeVersionId,
    }),
  );
  await invoke(
    client,
    "release_recipe_version_for_planning",
    recipeCommandRequest(subject, 3, "RMVP02B_ACCEPT_RELEASE_RECIPE", {
      recipe_version_id: recipeVersionId,
    }),
  );

  const recipeRead = await invoke(
    client,
    "get_dish_recipe_workbench",
    readRequest(subject, "RMVP-02A.v1", {}),
  );
  const released = recipeVersion(recipeRead.workbench, recipeVersionId);
  assert(
    released.recipe_version_status === "RELEASED_FOR_PLANNING" &&
      released.composition.length === 6,
    "The acceptance RecipeVersion was not released with six atomic matrix lines.",
  );
  const lineIds = Object.fromEntries(
    released.composition.map((line) => [line.line_code, line.recipe_line_id]),
  );
  const recipeLineId = lineIds["acceptance-base-a"];
  assert(recipeLineId, "The primary acceptance RecipeLine was not returned.");

  const adjustmentRead = await invoke(
    client,
    "get_recipe_adjustment_workbench",
    readRequest(subject, "RMVP-02B.v1", {}),
  );
  assert(
    adjustmentRead.workbench.schools.some(
      (school) => school.school_id === schoolId,
    ),
    "The acceptance School was not available to the adjustment workbench.",
  );

  const adjustmentId = crypto.randomUUID();
  const firstRevisionId = crypto.randomUUID();
  const today = isoDate();
  const tomorrow = isoDate(1);
  const cancellationDate = isoDate(2);
  const proposal = {
    adjustment_id: adjustmentId,
    revision_id: firstRevisionId,
    scope_kind: "SYSTEM_DISH",
    action_kind: "ADJUST_QUANTITY",
    dish_id: dishId,
    target_recipe_line_id: recipeLineId,
    quantity_per_basis: 7,
    effective_from: today,
    reason_code: "RMVP02B_ACCEPT_CREATE",
    reason_note: "Authenticated local what-if preview.",
    source_evidence: { source: "browser-key-acceptance" },
  };
  const preview = await invoke(
    client,
    "preview_recipe_composition_adjustment",
    readRequest(subject, "RMVP-02B.v1", {
      as_of_date: today,
      school_id: schoolId,
      dish_id: dishId,
      proposed_adjustment: proposal,
    }),
  );
  assert(
    preview.preview?.can_save === true &&
      preview.preview.affected_line_count === 1 &&
      preview.preview.before.status === "READY" &&
      preview.preview.after.status === "READY",
    "Authoritative what-if preview did not return one safe before/after change.",
  );

  const createRequest = commandRequest(subject, 1, "RMVP02B_ACCEPT_CREATE", {
    ...proposal,
    reason_code: undefined,
    reason_note: undefined,
    as_of_date: today,
    preview_school_id: schoolId,
    preview_dish_id: dishId,
  });
  delete createRequest.payload.reason_code;
  delete createRequest.payload.reason_note;
  const created = await invoke(
    client,
    "create_recipe_composition_adjustment",
    createRequest,
  );
  const replayed = await invoke(
    client,
    "create_recipe_composition_adjustment",
    createRequest,
  );
  assert(
    created.affected_aggregate_ids.recipe_composition_adjustment_id ===
      replayed.affected_aggregate_ids.recipe_composition_adjustment_id &&
      replayed.idempotency_status === "COMPLETED",
    "An exact create replay did not return the original durable receipt.",
  );

  const firstResolution = await invoke(
    client,
    "resolve_effective_recipe_composition",
    readRequest(subject, "RMVP-02B.v1", {
      as_of_date: today,
      school_id: schoolId,
      dish_id: dishId,
    }),
  );
  assert(
    Number(
      resolvedLine(firstResolution, recipeLineId).final_quantity_per_basis,
    ) === 7,
    "The created adjustment was not authoritative on its effective date.",
  );

  const schoolAdjustmentId = crypto.randomUUID();
  const schoolRevisionId = crypto.randomUUID();
  const schoolProposal = {
    adjustment_id: schoolAdjustmentId,
    revision_id: schoolRevisionId,
    scope_kind: "SCHOOL",
    action_kind: "REPLACE",
    school_id: schoolId,
    target_ingredient_id: baseIngredientId,
    substitute_ingredient_id: substituteIngredientId,
    effective_from: today,
    reason_code: "RMVP02B_ACCEPT_SCHOOL",
    reason_note: "Authenticated School replacement preview.",
    source_evidence: { source: "browser-key-school-acceptance" },
  };
  const schoolPreview = await invoke(
    client,
    "preview_recipe_composition_adjustment",
    readRequest(subject, "RMVP-02B.v1", {
      as_of_date: today,
      school_id: schoolId,
      dish_id: dishId,
      proposed_adjustment: schoolProposal,
    }),
  );
  assert(
    schoolPreview.preview?.can_save === true,
    "The School replacement preview was not saveable.",
  );
  await invoke(
    client,
    "create_recipe_composition_adjustment",
    commandRequest(subject, 1, "RMVP02B_ACCEPT_SCHOOL", {
      adjustment_id: schoolAdjustmentId,
      revision_id: schoolRevisionId,
      scope_kind: "SCHOOL",
      action_kind: "REPLACE",
      school_id: schoolId,
      target_ingredient_id: baseIngredientId,
      substitute_ingredient_id: substituteIngredientId,
      effective_from: today,
      as_of_date: today,
      preview_school_id: schoolId,
      preview_dish_id: dishId,
      source_evidence: { source: "browser-key-school-acceptance" },
    }),
  );

  const schoolDishAdjustmentId = crypto.randomUUID();
  const schoolDishRevisionId = crypto.randomUUID();
  const schoolDishProposal = {
    adjustment_id: schoolDishAdjustmentId,
    revision_id: schoolDishRevisionId,
    scope_kind: "SCHOOL_DISH",
    action_kind: "ADJUST_QUANTITY",
    school_id: schoolId,
    dish_id: dishId,
    target_recipe_line_id: recipeLineId,
    quantity_per_basis: 11,
    effective_from: today,
    reason_code: "RMVP02B_ACCEPT_SCHOOL_DISH",
    reason_note: "Authenticated School-and-Dish quantity preview.",
    source_evidence: { source: "browser-key-school-dish-acceptance" },
  };
  const schoolDishPreview = await invoke(
    client,
    "preview_recipe_composition_adjustment",
    readRequest(subject, "RMVP-02B.v1", {
      as_of_date: today,
      school_id: schoolId,
      dish_id: dishId,
      proposed_adjustment: schoolDishProposal,
    }),
  );
  assert(
    schoolDishPreview.preview?.can_save === true,
    "The School-and-Dish preview was not saveable.",
  );
  await invoke(
    client,
    "create_recipe_composition_adjustment",
    commandRequest(subject, 1, "RMVP02B_ACCEPT_SCHOOL_DISH", {
      adjustment_id: schoolDishAdjustmentId,
      revision_id: schoolDishRevisionId,
      scope_kind: "SCHOOL_DISH",
      action_kind: "ADJUST_QUANTITY",
      school_id: schoolId,
      dish_id: dishId,
      target_recipe_line_id: recipeLineId,
      quantity_per_basis: 11,
      effective_from: today,
      as_of_date: today,
      preview_school_id: schoolId,
      preview_dish_id: dishId,
      source_evidence: { source: "browser-key-school-dish-acceptance" },
    }),
  );
  const layeredResolution = await invoke(
    client,
    "resolve_effective_recipe_composition",
    readRequest(subject, "RMVP-02B.v1", {
      as_of_date: today,
      school_id: schoolId,
      dish_id: dishId,
    }),
  );
  const layeredLine = resolvedLine(layeredResolution, recipeLineId);
  assert(
    layeredLine.final_ingredient_id === substituteIngredientId &&
      Number(layeredLine.final_quantity_per_basis) === 11 &&
      layeredLine.source_layer === "SCHOOL_DISH" &&
      JSON.stringify(layeredLine.lineage.map((step) => step.scope_kind)) ===
        JSON.stringify(["SYSTEM_DISH", "SCHOOL", "SCHOOL_DISH"]),
    "The exact SYSTEM_DISH → SCHOOL → SCHOOL_DISH precedence and source audit were not retained.",
  );

  const matrixRules = [
    {
      tag: "SYSTEM_INGREDIENT_REPLACE",
      proposal: {
        adjustment_id: crypto.randomUUID(),
        revision_id: crypto.randomUUID(),
        scope_kind: "SYSTEM_INGREDIENT",
        action_kind: "REPLACE",
        target_ingredient_id: ingredientIds.baseB,
        substitute_ingredient_id: ingredientIds.substituteB,
        effective_from: today,
      },
    },
    {
      tag: "SYSTEM_DISH_ADD",
      proposal: {
        adjustment_id: crypto.randomUUID(),
        revision_id: crypto.randomUUID(),
        adjustment_line_id: crypto.randomUUID(),
        scope_kind: "SYSTEM_DISH",
        action_kind: "ADD",
        dish_id: dishId,
        target_ingredient_id: ingredientIds.systemAdd,
        quantity_per_basis: 12,
        unit_id: unitId,
        effective_from: today,
      },
    },
    {
      tag: "SYSTEM_DISH_REPLACE",
      proposal: {
        adjustment_id: crypto.randomUUID(),
        revision_id: crypto.randomUUID(),
        scope_kind: "SYSTEM_DISH",
        action_kind: "REPLACE",
        dish_id: dishId,
        target_recipe_line_id: lineIds["acceptance-base-c"],
        substitute_ingredient_id: ingredientIds.substituteC,
        effective_from: today,
      },
    },
    {
      tag: "SYSTEM_DISH_REMOVE",
      proposal: {
        adjustment_id: crypto.randomUUID(),
        revision_id: crypto.randomUUID(),
        scope_kind: "SYSTEM_DISH",
        action_kind: "REMOVE",
        dish_id: dishId,
        target_recipe_line_id: lineIds["acceptance-base-d"],
        effective_from: today,
      },
    },
    {
      tag: "SCHOOL_REMOVE",
      proposal: {
        adjustment_id: crypto.randomUUID(),
        revision_id: crypto.randomUUID(),
        scope_kind: "SCHOOL",
        action_kind: "REMOVE",
        school_id: schoolId,
        target_ingredient_id: ingredientIds.baseE,
        effective_from: today,
      },
    },
    {
      tag: "SCHOOL_DISH_ADD",
      proposal: {
        adjustment_id: crypto.randomUUID(),
        revision_id: crypto.randomUUID(),
        adjustment_line_id: crypto.randomUUID(),
        scope_kind: "SCHOOL_DISH",
        action_kind: "ADD",
        school_id: schoolId,
        dish_id: dishId,
        target_ingredient_id: ingredientIds.schoolDishAdd,
        quantity_per_basis: 13,
        unit_id: unitId,
        effective_from: today,
      },
    },
    {
      tag: "SCHOOL_DISH_REPLACE",
      proposal: {
        adjustment_id: crypto.randomUUID(),
        revision_id: crypto.randomUUID(),
        scope_kind: "SCHOOL_DISH",
        action_kind: "REPLACE",
        school_id: schoolId,
        dish_id: dishId,
        target_recipe_line_id: lineIds["acceptance-base-f"],
        substitute_ingredient_id: ingredientIds.substituteF,
        effective_from: today,
      },
    },
    {
      tag: "SCHOOL_DISH_REMOVE",
      proposal: {
        adjustment_id: crypto.randomUUID(),
        revision_id: crypto.randomUUID(),
        scope_kind: "SCHOOL_DISH",
        action_kind: "REMOVE",
        school_id: schoolId,
        dish_id: dishId,
        target_recipe_line_id: lineIds["acceptance-base-b"],
        effective_from: today,
      },
    },
  ];
  for (const matrixRule of matrixRules) {
    await previewAndCreateRule(
      client,
      subject,
      matrixRule.tag,
      schoolId,
      dishId,
      today,
      matrixRule.proposal,
    );
  }

  const secondRevisionId = crypto.randomUUID();
  await invoke(
    client,
    "supersede_recipe_composition_adjustment",
    commandRequest(subject, 1, "RMVP02B_ACCEPT_SUPERSEDE", {
      adjustment_id: adjustmentId,
      revision_id: secondRevisionId,
      predecessor_revision_id: firstRevisionId,
      quantity_per_basis: 9,
      effective_from: tomorrow,
      as_of_date: tomorrow,
      preview_school_id: schoolId,
      preview_dish_id: dishId,
      source_evidence: { source: "browser-key-correction" },
    }),
  );
  const successorResolution = await invoke(
    client,
    "resolve_effective_recipe_composition",
    readRequest(subject, "RMVP-02B.v1", {
      as_of_date: tomorrow,
      school_id: schoolId,
      dish_id: dishId,
    }),
  );
  const successorLine = resolvedLine(successorResolution, recipeLineId);
  const systemSuccessorStep = successorLine.lineage.find(
    (step) =>
      step.scope_kind === "SYSTEM_DISH" &&
      step.revision_id === secondRevisionId,
  );
  assert(
    Number(successorLine.final_quantity_per_basis) === 11 &&
      Number(systemSuccessorStep?.after?.quantity_per_basis) === 9 &&
      successorLine.source_layer === "SCHOOL_DISH",
    "The direct successor was not applied before the higher-priority School-and-Dish rule.",
  );

  const cancellationRevisionId = crypto.randomUUID();
  await invoke(
    client,
    "cancel_recipe_composition_adjustment",
    commandRequest(subject, 1, "RMVP02B_ACCEPT_CANCEL", {
      adjustment_id: schoolDishAdjustmentId,
      revision_id: cancellationRevisionId,
      predecessor_revision_id: schoolDishRevisionId,
      effective_from: cancellationDate,
    }),
  );
  const historicalResolution = await invoke(
    client,
    "resolve_effective_recipe_composition",
    readRequest(subject, "RMVP-02B.v1", {
      as_of_date: tomorrow,
      school_id: schoolId,
      dish_id: dishId,
    }),
  );
  const postCancelResolution = await invoke(
    client,
    "resolve_effective_recipe_composition",
    readRequest(subject, "RMVP-02B.v1", {
      as_of_date: cancellationDate,
      school_id: schoolId,
      dish_id: dishId,
    }),
  );
  assert(
    Number(
      resolvedLine(historicalResolution, recipeLineId).final_quantity_per_basis,
    ) === 11 &&
      Number(
        resolvedLine(postCancelResolution, recipeLineId)
          .final_quantity_per_basis,
      ) === 9 &&
      resolvedLine(postCancelResolution, recipeLineId).source_layer ===
        "SCHOOL",
    "Dated cancellation did not preserve historical higher-priority effect and reveal the lower layers afterward.",
  );

  await expectError(
    client,
    "cancel_recipe_composition_adjustment",
    commandRequest(subject, 1, "RMVP02B_ACCEPT_STALE", {
      adjustment_id: schoolDishAdjustmentId,
      revision_id: crypto.randomUUID(),
      predecessor_revision_id: schoolDishRevisionId,
      effective_from: isoDate(3),
    }),
    "STALE_VERSION",
  );

  const finalRead = await invoke(
    client,
    "get_recipe_adjustment_workbench",
    readRequest(subject, "RMVP-02B.v1", {}),
  );
  const systemRule = finalRead.workbench.adjustments.find(
    (item) => item.adjustment_id === adjustmentId,
  );
  const schoolRule = finalRead.workbench.adjustments.find(
    (item) => item.adjustment_id === schoolAdjustmentId,
  );
  const schoolDishRule = finalRead.workbench.adjustments.find(
    (item) => item.adjustment_id === schoolDishAdjustmentId,
  );
  assert(
    systemRule?.lifecycle_status === "ACTIVE" &&
      systemRule.revisions.length === 2 &&
      systemRule.revisions[0].lifecycle_status === "SUPERSEDED" &&
      systemRule.revisions[1].lifecycle_status === "ACTIVE" &&
      schoolRule?.lifecycle_status === "ACTIVE" &&
      schoolRule.revisions.length === 1 &&
      schoolDishRule?.lifecycle_status === "CANCELLED" &&
      schoolDishRule.revisions.length === 2 &&
      schoolDishRule.revisions[0].lifecycle_status === "SUPERSEDED" &&
      schoolDishRule.revisions[1].lifecycle_status === "CANCELLED",
    "The authoritative workbench did not retain the complete correction lineage.",
  );

  await client.auth.signOut();
  const signedInAgainSubject = await signIn(client);
  assert(
    signedInAgainSubject === subject,
    "Reauthentication did not restore the exact local Actor subject.",
  );
  const reauthenticatedRead = await invoke(
    client,
    "get_recipe_adjustment_workbench",
    readRequest(signedInAgainSubject, "RMVP-02B.v1", {}),
  );
  assert(
    reauthenticatedRead.workbench.adjustments.some(
      (item) =>
        item.adjustment_id === schoolDishAdjustmentId &&
        item.lifecycle_status === "CANCELLED",
    ),
    "Authoritative adjustment state did not survive sign-out and sign-in.",
  );

  console.log(
    "RMVP-02B authenticated local acceptance passed: all 11 scope/action previews and saves, exact precedence, replay, supersede, dated cancel, stale rejection, immutable lineage, and reauthentication.",
  );
}

try {
  await main();
} catch (error) {
  console.error(
    error instanceof Error
      ? error.message
      : "RMVP-02B local acceptance failed safely.",
  );
  process.exitCode = 1;
}
