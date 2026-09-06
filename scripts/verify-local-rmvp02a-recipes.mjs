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

async function verifyCanonicalCopy(client, subject, sourceDishId, references) {
  const {
    secondarySchoolType,
    canonicalSchoolTypes,
    ingredient,
    unit,
    dishType,
  } = references;
  const secondary = await readWorkbench(client, subject, {
    dish_id: sourceDishId,
    school_type_id: secondarySchoolType.school_type_id,
  });
  await invoke(
    client,
    "save_recipe",
    saveRequest(subject, secondary.selected_recipe.expected_version, {
      dish_id: sourceDishId,
      school_type_id: secondarySchoolType.school_type_id,
      recipe_version_id: null,
      basis_portions: 100,
      lines: [
        {
          recipe_line_id: crypto.randomUUID(),
          ingredient_id: ingredient.ingredient_id,
          quantity_per_basis: 20,
          unit_id: unit.unit_id,
          operational_note: "Canonical copy source scope",
        },
      ],
    }),
  );
  const asOfDate = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Ho_Chi_Minh",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
  const readRequest = (dishId, schoolTypeId) => ({
    contract_version: "RECIPE-EFFECTIVE.v1",
    requested_by_auth_subject: subject,
    correlation_id: crypto.randomUUID(),
    payload: {
      as_of_date: asOfDate,
      dish_id: dishId,
      school_type_id: schoolTypeId,
    },
  });
  const before = await readWorkbench(client, subject);
  const sourceRootIds = new Set(
    before.recipes
      .filter((root) => root.dish_id === sourceDishId)
      .map((root) => root.recipe_id),
  );
  const sourceEvidence = (data) =>
    JSON.stringify(
      data.recipe_versions.filter((version) =>
        sourceRootIds.has(version.recipe_id),
      ),
    );
  const sourceBefore = sourceEvidence(before);
  const target = await invoke(
    client,
    "create_dish",
    v1Request(subject, 1, "MODEL_CONVERGENCE_COPY_TARGET", {
      dish_code: `convergence-copy-${crypto.randomUUID().slice(0, 8)}`,
      dish_name: "Local canonical two-scope copy target",
      dish_category: "Acceptance",
      dish_type_id: dishType.dish_type_id,
      operational_notes: "Disposable browser-key convergence evidence",
      display_order: 9901,
      requires_need_generation: true,
    }),
  );
  const targetDishId = target.affected_aggregate_ids.dish_id;
  const targetRead = await readWorkbench(client, subject);
  const targetDish = targetRead.dishes.find(
    (dish) => dish.dish_id === targetDishId,
  );
  const targetRoots = targetRead.recipes.filter(
    (root) => root.dish_id === targetDishId,
  );
  assert(
    targetDish?.dish_status === "ACTIVE" &&
      targetRoots.length === 2 &&
      !targetRead.recipe_versions.some((version) =>
        targetRoots.some((root) => root.recipe_id === version.recipe_id),
      ),
    "Canonical browser-key copy target was not ACTIVE with two version-free roots.",
  );
  const sourceContexts = new Map();
  for (const schoolType of canonicalSchoolTypes) {
    const typeId = schoolType.school_type_id;
    const source = await invoke(
      client,
      "get_dish_recipe_operator_workbench",
      readRequest(sourceDishId, typeId),
    );
    const resolution = await invoke(
      client,
      "resolve_system_effective_recipe_composition",
      readRequest(sourceDishId, typeId),
    );
    const targets = await invoke(
      client,
      "get_recipe_effective_target_context",
      readRequest(sourceDishId, typeId),
    );
    assert(
      source.workbench?.effective_readiness.status === "READY" &&
        source.workbench.school_id === null &&
        source.workbench.school_type_id === typeId &&
        resolution.resolution?.status === "READY" &&
        targets.target_context?.school_id === null &&
        targets.target_context.school_type_id === typeId &&
        targets.target_context.effective_lines.length > 0,
      "Canonical browser-key system reads did not return the exact ready typed context.",
    );
    sourceContexts.set(typeId, source.workbench);
    const rootOnly = await invoke(
      client,
      "get_dish_recipe_operator_workbench",
      readRequest(targetDishId, typeId),
    );
    assert(
      rootOnly.workbench?.effective_readiness.status === "BLOCKED" &&
        rootOnly.workbench.base_authoring.recipe_version_id === null &&
        rootOnly.workbench.base_authoring.allowed_actions.save_recipe === true,
      "Root-only canonical read did not separate blocked effectiveness from permitted authoring.",
    );
  }
  const request = {
    ...v1Request(subject, targetDish.version, "COPY_DISH_RECIPES", {
      source_dish_id: sourceDishId,
      target_dish_id: targetDishId,
      as_of_date: asOfDate,
    }),
    contract_version: "RECIPE-EFFECTIVE.v1",
    reason_note:
      "Verify both persisted DRAFT snapshots through a local browser key.",
  };
  const copied = await invoke(client, "copy_dish_recipes", request);
  assert(
    copied.scope_results?.length === 2 &&
      new Set(copied.scope_results.map((scope) => scope.school_type_id))
        .size === 2 &&
      canonicalSchoolTypes.every((type) =>
        copied.scope_results.some(
          (scope) =>
            scope.school_type_id === type.school_type_id &&
            scope.school_type_code === type.school_type_code &&
            scope.status === "COPIED",
        ),
      ),
    "Canonical browser-key copy did not return both distinct canonical scopes.",
  );
  const after = await readWorkbench(client, subject);
  const normalized = (lines) =>
    JSON.stringify(
      lines
        .map((line) => ({
          ingredient_id: line.ingredient_id,
          quantity_per_basis: line.quantity_per_basis,
          unit_id: line.unit_id,
        }))
        .sort((left, right) =>
          JSON.stringify(left).localeCompare(JSON.stringify(right)),
        ),
    );
  for (const scope of copied.scope_results) {
    const version = after.recipe_versions.find(
      (row) => row.recipe_version_id === scope.target_recipe_version_id,
    );
    const source = sourceContexts.get(scope.school_type_id);
    const readback = await invoke(
      client,
      "get_dish_recipe_operator_workbench",
      readRequest(targetDishId, scope.school_type_id),
    );
    assert(
      version?.recipe_version_status === "DRAFT" &&
        version.recipe_id === scope.target_recipe_id &&
        version.source_evidence?.outer_command_id === request.command_id &&
        version.source_evidence.source_dish_id === sourceDishId &&
        version.source_evidence.copy_as_of_date === asOfDate &&
        version.basis_portions === source.basis_portions &&
        normalized(version.composition) ===
          normalized(source.current_effective_bom) &&
        readback.workbench?.base_authoring.recipe_version_id ===
          version.recipe_version_id &&
        readback.workbench.effective_readiness.status === "BLOCKED",
      "Canonical copy scope was not the exact persisted, editable DRAFT system snapshot.",
    );
  }
  assert(
    sourceEvidence(after) === sourceBefore,
    "Canonical copy changed immutable source Recipe evidence.",
  );
  const replay = await invoke(client, "copy_dish_recipes", request);
  const replayRead = await readWorkbench(client, subject);
  assert(
    JSON.stringify(replay.scope_results) ===
      JSON.stringify(copied.scope_results) &&
      replayRead.recipe_versions.length === after.recipe_versions.length,
    "Canonical browser-key exact replay duplicated or replaced copy versions.",
  );
  console.log(
    "Verified MODEL-CONVERGENCE canonical authenticated system reads, root-only authoring, two-scope persisted DRAFT copy, exact source snapshots/command provenance, source immutability and exact replay.",
  );
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
  const canonicalSchoolTypes = ["v1-school-type-1", "v1-school-type-2"].map(
    (schoolTypeCode) =>
      initial.school_types.find(
        (item) =>
          item.school_type_code === schoolTypeCode &&
          item.school_type_status === "ACTIVE",
      ),
  );
  const [primarySchoolType, secondarySchoolType] = canonicalSchoolTypes;
  assert(
    ingredient && unit && dishType && primarySchoolType && secondarySchoolType,
    "Active Recipe references and both canonical School Types are required.",
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
  const createdDish = created.authoritative_readback.dishes.find(
    (item) => item.dish_id === dishId,
  );
  assert(
    createdDish?.dish_status === "ACTIVE" &&
      createdDish.version === 1 &&
      created.affected_aggregate_ids.recipe_ids?.length === 2,
    "Dish creation did not return an ACTIVE version-1 Dish with both canonical typed Recipe roots.",
  );

  let workbench = await readWorkbench(client, subject, {
    dish_id: dishId,
    school_type_id: primarySchoolType.school_type_id,
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
      school_type_id: primarySchoolType.school_type_id,
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
      firstSave.new_versions?.dish_version === 1 &&
      firstSave.emitted_event_ids?.length === 1 &&
      firstSave.audit_event_ids?.length === 1 &&
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
      school_type_id: primarySchoolType.school_type_id,
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
    school_type_id: primarySchoolType.school_type_id,
  });
  assert(
    persisted.selected_recipe.recipe_version_id === secondVersionId &&
      persisted.selected_recipe.business_status === "AVAILABLE" &&
      persisted.selected_recipe.locked_for_normal_editing === false,
    "Creation Save did not persist authoritative readback across sign-in.",
  );

  await verifyCanonicalCopy(client, subject, dishId, {
    secondarySchoolType,
    canonicalSchoolTypes,
    ingredient,
    unit,
    dishType,
  });

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
    school_type_id: primarySchoolType.school_type_id,
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
      school_type_id: primarySchoolType.school_type_id,
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
      target_school_type_id: primarySchoolType.school_type_id,
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
        school_type_id: primarySchoolType.school_type_id,
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
    school_type_id: primarySchoolType.school_type_id,
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
    school_type_id: primarySchoolType.school_type_id,
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
      school_type_id: primarySchoolType.school_type_id,
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
    school_type_id: primarySchoolType.school_type_id,
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
    "Verified RMVP-02A browser-key ACTIVE version-1 typed-pair creation, Recipe-only Save evidence without Dish lifecycle mutation, typed pre-use availability, approved-menu derived Dish lock, Save/copy/import denial with zero base composition mutation, successful Recipe lifecycle administration with event/audit evidence, and the unchanged post-lifecycle composition lock.",
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
