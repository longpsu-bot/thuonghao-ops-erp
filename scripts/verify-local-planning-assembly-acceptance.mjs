import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createClient } from "@supabase/supabase-js";
import {
  buildFoundationPackageSql,
  buildFoundationVerificationSql,
  buildIdentityPackageSql,
  buildIdentityVerificationSql,
  readAtlasStagingPackage,
  reconcileManagedAuthUser,
} from "./install-atlas-staging-package.mjs";
import {
  readLocalSupabaseStatus,
  runPinnedSupabase,
} from "./local-supabase-status.mjs";

const email = "atlas.planning.assembly@local.test";
const password = "Atlas-Planning-Assembly-local-only!";
const weekStart = "2026-11-09";

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function runSql(sql) {
  const directory = mkdtempSync(join(tmpdir(), "atlas-planning-assembly-"));
  const path = join(directory, "assertion.sql");
  try {
    writeFileSync(path, sql, { encoding: "utf8", flag: "wx" });
    runPinnedSupabase(
      ["db", "query", "--local", "--file", path, "--agent", "no"],
      {
        stdio: ["ignore", "ignore", "inherit"],
      },
    );
  } finally {
    rmSync(directory, { force: true, recursive: true });
  }
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
  { requestedAt = new Date(Date.now() - 1_000), reasonNote = null } = {},
) {
  const commandId = crypto.randomUUID();
  return {
    contract_version: contractVersion,
    command_id: commandId,
    correlation_id: crypto.randomUUID(),
    idempotency_key: `${reasonCode.toLowerCase()}:${commandId}`,
    expected_version: expectedVersion,
    requested_by_auth_subject: subject,
    requested_at: requestedAt.toISOString(),
    reason_code: reasonCode,
    reason_note: reasonNote,
    payload,
  };
}

async function invoke(client, name, request, { rejected = false } = {}) {
  const { data, error } = await client
    .schema("atlas_api")
    .rpc(name, { request })
    .retry(false);
  if (error) {
    throw new Error(
      `Planning assembly ${name} transport failed (${error.code ?? "UNKNOWN"}: ${error.message ?? "no message"}).`,
    );
  }
  if (rejected) {
    assert(
      data?.success === false,
      `${name} unexpectedly accepted an invalid command.`,
    );
  } else {
    assert(
      data?.success === true,
      `${name} was rejected: ${data?.error_code ?? "UNKNOWN"} (${data?.safe_message ?? "no safe message"}).`,
    );
  }
  return data;
}

function activeRows(root, property) {
  return (root?.[property] ?? []).filter(
    (line) => !line.line_status || line.line_status === "ACTIVE",
  );
}

function confirmedCommand(subject, workbench, kind, lines = undefined) {
  return commandRequest(
    kind === "save" ? "RMVP-05.v2" : "RMVP-07.v2",
    subject,
    workbench.batch_version,
    kind === "save" ? "CONFIRMED_NEED_SAVED" : "CONFIRMED_NEED_RELEASED",
    {
      confirmed_need_batch_id: workbench.confirmed_need_batch_id,
      ...(kind === "save" ? { lines } : {}),
    },
  );
}

function packageStateSql(foundation, stage) {
  const schoolId = foundation.school.school_id;
  const contract = foundation.need_generation_calculation_contract;
  const purposes = foundation.pantry_purposes
    .map((purpose) => `'${purpose.pantry_need_purpose_id}'::uuid`)
    .join(", ");
  const expectedStudent = stage === "initial" ? 0 : 100;
  const expectedTeacher = stage === "initial" ? 0 : 10;
  const expectedVersion = stage === "initial" ? 1 : 2;
  return `do $planning_assembly_package_state$
begin
  if (select count(*) from atlas_admin.schools where school_id = '${schoolId}'::uuid
      and default_student_portions = ${expectedStudent}
      and default_teacher_portions = ${expectedTeacher}
      and version = ${expectedVersion}) <> 1
    or (select count(*) from atlas_planning.pantry_need_purposes
        where pantry_need_purpose_id in (${purposes})
          and note_rule = 'OPTIONAL' and purpose_status = 'ACTIVE') <> 2
    or (select count(*) from atlas_planning.need_generation_calculation_contracts
        where need_generation_calculation_contract_id =
          '${contract.need_generation_calculation_contract_id}'::uuid) <> 1
    or (select count(*) from atlas_planning.need_generation_calculation_contract_revisions
        where need_generation_calculation_contract_revision_id =
          '${contract.need_generation_calculation_contract_revision_id}'::uuid) <> 1
    or (select count(*) from atlas_planning.weekly_menus) <> 0
    or (select count(*) from atlas_planning.attendance_batches) <> 0
    or (select count(*) from atlas_planning.pantry_need_batches) <> 0
    or (select count(*) from atlas_planning.need_generation_runs) <> 0
    or (select count(*) from atlas_planning.confirmed_need_batches) <> 0 then
    raise exception 'PLANNING_ASSEMBLY_PACKAGE_STATE_MISMATCH';
  end if;
end;
$planning_assembly_package_state$;`;
}

function schoolEvidenceSql(foundation, actorId) {
  return `do $planning_assembly_school_evidence$
begin
  if (select count(*) from atlas_audit.domain_events
      where aggregate_type = 'School'
        and aggregate_id = '${foundation.school.school_id}'::uuid
        and event_type = 'SchoolPortionDefaultsUpdated'
        and aggregate_version = 2 and actor_id = '${actorId}'::uuid) <> 1
    or (select count(*) from atlas_audit.audit_events
      where aggregate_type = 'School'
        and aggregate_id = '${foundation.school.school_id}'::uuid
        and event_type = 'SchoolPortionDefaultsUpdated'
        and aggregate_version_before = 1 and aggregate_version_after = 2
        and actor_id = '${actorId}'::uuid) <> 1 then
    raise exception 'PLANNING_ASSEMBLY_SCHOOL_EVIDENCE_MISMATCH';
  end if;
end;
$planning_assembly_school_evidence$;`;
}

function theoreticalQuantitySql(runId) {
  return `do $planning_assembly_theoretical_quantity$
begin
  if (select sum(theoretical_quantity)
      from atlas_planning.theoretical_need_lines
      where need_generation_run_id = '${runId}'::uuid
        and contribution_family = 'RECIPE_DERIVED'
        and line_disposition = 'ACTIVE') <> 12.100000::numeric then
    raise exception 'PLANNING_ASSEMBLY_THEORETICAL_QUANTITY_MISMATCH';
  end if;
end;
$planning_assembly_theoretical_quantity$;`;
}

function captureBusinessStateSql() {
  return `do $planning_assembly_capture$
begin
drop table if exists extensions.planning_assembly_replay_baseline;
create table extensions.planning_assembly_replay_baseline (state jsonb not null);
insert into extensions.planning_assembly_replay_baseline (state)
select jsonb_build_object(
  'schools',(select jsonb_agg(to_jsonb(row) order by school_id) from atlas_admin.schools row),
  'ingredients',(select jsonb_agg(to_jsonb(row) order by ingredient_id) from atlas_admin.ingredients row),
  'suppliers',(select jsonb_agg(to_jsonb(row) order by supplier_id) from atlas_admin.suppliers row),
  'priorities',(select jsonb_agg(to_jsonb(row) order by supplier_eligibility_id) from atlas_admin.supplier_eligibilities row),
  'dishes',(select jsonb_agg(to_jsonb(row) order by dish_id) from atlas_admin.dishes row),
  'recipes',(select jsonb_agg(to_jsonb(row) order by recipe_id) from atlas_admin.recipes row),
  'recipe_versions',(select jsonb_agg(to_jsonb(row) order by recipe_version_id) from atlas_admin.recipe_versions row),
  'menus',(select jsonb_agg(to_jsonb(row) order by weekly_menu_id) from atlas_planning.weekly_menus row),
  'attendance',(select jsonb_agg(to_jsonb(row) order by attendance_batch_id) from atlas_planning.attendance_batches row),
  'pantry',(select jsonb_agg(to_jsonb(row) order by pantry_need_batch_id) from atlas_planning.pantry_need_batches row),
  'generation',(select jsonb_agg(to_jsonb(row) order by need_generation_run_id) from atlas_planning.need_generation_runs row),
  'confirmed',(select jsonb_agg(to_jsonb(row) order by confirmed_need_batch_id) from atlas_planning.confirmed_need_batches row),
  'domain_events',(select jsonb_agg(to_jsonb(row) order by domain_event_id) from atlas_audit.domain_events row),
  'audit_events',(select jsonb_agg(to_jsonb(row) order by audit_event_id) from atlas_audit.audit_events row)
);
end;
$planning_assembly_capture$;`;
}

function verifyBusinessStateSql() {
  return `do $planning_assembly_final_state$
declare current_state jsonb;
begin
  select jsonb_build_object(
    'schools',(select jsonb_agg(to_jsonb(row) order by school_id) from atlas_admin.schools row),
    'ingredients',(select jsonb_agg(to_jsonb(row) order by ingredient_id) from atlas_admin.ingredients row),
    'suppliers',(select jsonb_agg(to_jsonb(row) order by supplier_id) from atlas_admin.suppliers row),
    'priorities',(select jsonb_agg(to_jsonb(row) order by supplier_eligibility_id) from atlas_admin.supplier_eligibilities row),
    'dishes',(select jsonb_agg(to_jsonb(row) order by dish_id) from atlas_admin.dishes row),
    'recipes',(select jsonb_agg(to_jsonb(row) order by recipe_id) from atlas_admin.recipes row),
    'recipe_versions',(select jsonb_agg(to_jsonb(row) order by recipe_version_id) from atlas_admin.recipe_versions row),
    'menus',(select jsonb_agg(to_jsonb(row) order by weekly_menu_id) from atlas_planning.weekly_menus row),
    'attendance',(select jsonb_agg(to_jsonb(row) order by attendance_batch_id) from atlas_planning.attendance_batches row),
    'pantry',(select jsonb_agg(to_jsonb(row) order by pantry_need_batch_id) from atlas_planning.pantry_need_batches row),
    'generation',(select jsonb_agg(to_jsonb(row) order by need_generation_run_id) from atlas_planning.need_generation_runs row),
    'confirmed',(select jsonb_agg(to_jsonb(row) order by confirmed_need_batch_id) from atlas_planning.confirmed_need_batches row),
    'domain_events',(select jsonb_agg(to_jsonb(row) order by domain_event_id) from atlas_audit.domain_events row),
    'audit_events',(select jsonb_agg(to_jsonb(row) order by audit_event_id) from atlas_audit.audit_events row)
  ) into current_state;
  if current_state is distinct from
      (select state from extensions.planning_assembly_replay_baseline)
    or (select count(*) from atlas_planning.purchase_handoff_batches) <> 0
    or (select count(*) from atlas_procurement.fulfilment_allocations) <> 0
    or (select count(*) from atlas_procurement.purchase_orders) <> 0
    or (select count(*) from atlas_evidence.supplier_receiving_evidence) <> 0
    or (select count(*) from atlas_dispatch.dispatch_plans) <> 0 then
    raise exception 'PLANNING_ASSEMBLY_FINAL_REPLAY_OR_DOWNSTREAM_MISMATCH';
  end if;
end;
$planning_assembly_final_state$;`;
}

async function main() {
  const resumeAfterConfirmed = process.argv.includes(
    "--resume-after-confirmed",
  );
  const resumeAfterGeneration =
    process.argv.includes("--resume-after-generation") || resumeAfterConfirmed;
  const resumeAfterPantry =
    process.argv.includes("--resume-after-pantry") || resumeAfterGeneration;
  const resumeAfterAttendance =
    process.argv.includes("--resume-after-attendance") || resumeAfterPantry;
  const resumeAfterMenu =
    process.argv.includes("--resume-after-menu") || resumeAfterAttendance;
  if (!process.argv.includes("--reuse-local")) {
    runPinnedSupabase(["db", "reset", "--local", "--no-seed"], {
      stdio: ["ignore", "ignore", "inherit"],
    });
  }
  const { apiUrl, browserKey, serviceRoleKey } = readLocalSupabaseStatus({
    requireAdminKey: true,
  });
  const identity = readAtlasStagingPackage("identity");
  const foundation = readAtlasStagingPackage("foundation");
  assert(
    foundation.package.version === "1.1.0",
    "Foundation 1.1.0 is required.",
  );

  await reconcileManagedAuthUser({
    manifest: identity,
    email,
    password,
    supabaseUrl: apiUrl,
    secretKey: serviceRoleKey,
  });
  runSql(buildIdentityPackageSql(identity));
  runSql(buildIdentityVerificationSql(identity));
  runSql(buildFoundationPackageSql(foundation));
  runSql(buildFoundationVerificationSql(foundation));
  if (!resumeAfterMenu) runSql(packageStateSql(foundation, "initial"));

  const client = createClient(apiUrl, browserKey, {
    db: { schema: "atlas_api" },
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  });
  const signIn = await client.auth.signInWithPassword({ email, password });
  assert(
    !signIn.error && signIn.data.session,
    "Assembly operator sign-in failed.",
  );
  const subject = signIn.data.session.user.id;

  let ingredientId;
  let dishId;
  let dishType;
  let planning;

  if (!resumeAfterMenu) {
    const schoolCommand = commandRequest(
      "RMVP-01.v2",
      subject,
      1,
      "SCHOOL_PORTION_DEFAULTS_BULK_UPDATE",
      {
        changes: [
          {
            school_id: foundation.school.school_id,
            expected_version: 1,
            default_student_portions: 100,
            default_teacher_portions: 10,
          },
        ],
      },
      { reasonNote: "Assembled Planning acceptance School preparation." },
    );
    delete schoolCommand.expected_version;
    const schoolUpdate = await invoke(
      client,
      "update_school_portion_defaults_bulk",
      schoolCommand,
    );
    assert(
      schoolUpdate.updated_schools?.[0]?.version === 2 &&
        schoolUpdate.updated_schools[0].default_student_portions === 100 &&
        schoolUpdate.updated_schools[0].default_teacher_portions === 10,
      "School 0/0 to 100/10 did not produce version 2.",
    );
    runSql(schoolEvidenceSql(foundation, identity.actor.actor_id));
    runSql(buildFoundationPackageSql(foundation));
    runSql(buildFoundationVerificationSql(foundation));
    runSql(packageStateSql(foundation, "replay"));
    runSql(schoolEvidenceSql(foundation, identity.actor.actor_id));

    let master = await invoke(
      client,
      "get_ingredient_supplier_master_data",
      readRequest("RMVP-01.v1", subject, {}),
    );
    const ingredientType = master.ingredient_types.find(
      (item) => item.ingredient_type_code === "khac",
    );
    const orderGroup = master.ingredient_order_groups.find(
      (item) => item.ingredient_order_group_code === "daily_other",
    );
    assert(
      ingredientType && orderGroup,
      "Accepted Ingredient catalogs are absent.",
    );
    const supplierCreated = await invoke(
      client,
      "create_supplier",
      commandRequest("RMVP-01.v1", subject, 1, "ASSEMBLY_SUPPLIER_CREATE", {
        supplier_code: "assembly-supplier",
        supplier_name: "Planning Assembly Supplier",
        contact_name: "Synthetic Operator",
        contact_phone: "0900000000",
        contact_email: "assembly@example.invalid",
      }),
    );
    const ingredientCreated = await invoke(
      client,
      "create_ingredient",
      commandRequest("RMVP-01.v1", subject, 1, "ASSEMBLY_INGREDIENT_CREATE", {
        ingredient_code: "assembly-ingredient",
        ingredient_name: "Planning Assembly Ingredient",
        purchase_unit_id: foundation.unit.unit_id,
        ingredient_type_id: ingredientType.ingredient_type_id,
        ingredient_order_group_id: orderGroup.ingredient_order_group_id,
        order_step: 0.01,
      }),
    );
    const supplierId = supplierCreated.affected_aggregate_ids.supplier_id;
    ingredientId = ingredientCreated.affected_aggregate_ids.ingredient_id;
    await invoke(
      client,
      "replace_ingredient_supplier_priorities",
      commandRequest("RMVP-01.v1", subject, 1, "ASSEMBLY_PRIORITY_REPLACE", {
        ingredient_id: ingredientId,
        priorities: [{ supplier_id: supplierId, priority: 1 }],
      }),
    );
    master = await invoke(
      client,
      "get_ingredient_supplier_master_data",
      readRequest("RMVP-01.v1", subject, {}),
    );
    assert(
      master.ingredients.some((item) => item.ingredient_id === ingredientId) &&
        master.suppliers.some((item) => item.supplier_id === supplierId),
      "Public Admin commands did not read back the synthetic chain.",
    );

    let recipeWorkbench = (
      await invoke(
        client,
        "get_dish_recipe_workbench",
        readRequest("RMVP-02A.v2", subject, {}),
      )
    ).workbench;
    dishType = recipeWorkbench.dish_types.find(
      (item) => item.dish_type_code === "savory",
    );
    assert(dishType, "Accepted savory Dish Type is absent.");
    const dishCreated = await invoke(
      client,
      "create_dish",
      commandRequest("RMVP-02A.v1", subject, 1, "ASSEMBLY_DISH_CREATE", {
        dish_code: "assembly-dish",
        dish_name: "Planning Assembly Dish",
        dish_category: "Acceptance",
        dish_type_id: dishType.dish_type_id,
        operational_notes: "Synthetic assembled Planning acceptance",
        display_order: 9900,
        requires_need_generation: true,
      }),
    );
    dishId = dishCreated.affected_aggregate_ids.dish_id;
    recipeWorkbench = (
      await invoke(
        client,
        "get_dish_recipe_workbench",
        readRequest("RMVP-02A.v2", subject, {
          dish_id: dishId,
          school_type_id: null,
        }),
      )
    ).workbench;
    const recipeSaved = await invoke(
      client,
      "save_recipe",
      commandRequest(
        "RMVP-02A.v2",
        subject,
        recipeWorkbench.selected_recipe.expected_version,
        "RECIPE_SAVED",
        {
          dish_id: dishId,
          school_type_id: null,
          recipe_version_id: null,
          basis_portions: 100,
          lines: [
            {
              recipe_line_id: crypto.randomUUID(),
              ingredient_id: ingredientId,
              quantity_per_basis: 10,
              unit_id: foundation.unit.unit_id,
              operational_note: "Assembly theoretical quantity line",
            },
          ],
        },
      ),
    );
    recipeWorkbench = recipeSaved.authoritative_readback;
    assert(
      recipeWorkbench.selected_recipe.business_status === "AVAILABLE" &&
        recipeWorkbench.recipe_versions.some(
          (item) => item.recipe_version_status === "RELEASED_FOR_PLANNING",
        ) &&
        recipeWorkbench.dishes.find((item) => item.dish_id === dishId)
          ?.dish_status === "ACTIVE",
      "Initial Recipe Save did not activate the Dish and release a usable Recipe.",
    );

    const planningRead = async () =>
      (
        await invoke(
          client,
          "get_planning_inputs_workbench",
          readRequest("RMVP-03A.v1", subject, { week_start: weekStart }),
        )
      ).workbench;
    planning = await planningRead();
    const menuRows = [
      {
        school_id: foundation.school.school_id,
        service_date: weekStart,
        menu_slot_code: dishType.dish_type_code,
        dish_id: dishId,
        source_row_reference: "assembly-menu:1",
      },
    ];
    const menuPreview = await invoke(
      client,
      "preview_weekly_menu_import",
      readRequest("RMVP-03A.v1", subject, {
        week_start: weekStart,
        rows: menuRows,
      }),
    );
    const menu = await invoke(
      client,
      "save_weekly_menu",
      commandRequest("RMVP-03A.v2", subject, 1, "WEEKLY_MENU_SAVED", {
        week_start: weekStart,
        source_type: "MANUAL_ATLAS",
        source_name: "Planning assembly acceptance",
        source_signature: menuPreview.preview.source_signature,
        expected_source_signature: null,
        rows: menuPreview.preview.canonical_rows,
      }),
    );
    assert(
      menu.authoritative_readback.planning_inputs.weekly_menu
        .weekly_menu_status === "APPROVED",
      "Weekly Menu v2 did not complete as APPROVED.",
    );
  } else {
    const resumedMaster = await invoke(
      client,
      "get_ingredient_supplier_master_data",
      readRequest("RMVP-01.v1", subject, {}),
    );
    ingredientId = resumedMaster.ingredients.find(
      (item) => item.ingredient_code === "assembly-ingredient",
    )?.ingredient_id;
    const resumedRecipe = (
      await invoke(
        client,
        "get_dish_recipe_workbench",
        readRequest("RMVP-02A.v2", subject, {}),
      )
    ).workbench;
    const resumedDish = resumedRecipe.dishes.find(
      (item) => item.dish_code === "assembly-dish",
    );
    dishId = resumedDish?.dish_id;
    dishType = resumedRecipe.dish_types.find(
      (item) => item.dish_type_id === resumedDish?.dish_type_id,
    );
    planning = (
      await invoke(
        client,
        "get_planning_inputs_workbench",
        readRequest("RMVP-03A.v1", subject, { week_start: weekStart }),
      )
    ).workbench;
    assert(
      ingredientId &&
        dishId &&
        dishType &&
        planning.weekly_menu?.weekly_menu_status === "APPROVED",
      "The same-stack resume point after Weekly Menu is incomplete.",
    );
  }

  const attendanceRows = [
    {
      school_id: foundation.school.school_id,
      service_date: weekStart,
      student_portions: 111,
      teacher_portions: 10,
      source_row_reference: "assembly-attendance:1",
    },
  ];
  const attendancePreview = await invoke(
    client,
    "preview_attendance_import",
    readRequest("RMVP-03A.v1", subject, {
      week_start: weekStart,
      rows: attendanceRows,
    }),
  );
  assert(
    attendancePreview.preview.can_save === true &&
      attendancePreview.preview.issues.blockers.length === 0 &&
      JSON.stringify(
        attendancePreview.preview.issues.warnings.map((item) => item.code),
      ) === JSON.stringify(["PORTIONS_DIFFER_FROM_DEFAULT"]),
    "Attendance 111/10 preview did not retain only the defaults warning.",
  );
  const attendance = resumeAfterAttendance
    ? {
        new_versions: { aggregate_version: planning.attendance.version },
        authoritative_readback: { planning_inputs: planning },
      }
    : await invoke(
        client,
        "save_attendance",
        commandRequest(
          "RMVP-03A.v2",
          subject,
          1,
          "ATTENDANCE_SAVED",
          {
            week_start: weekStart,
            source_type: "MANUAL_ATLAS",
            source_name: "Planning assembly acceptance",
            source_signature: attendancePreview.preview.source_signature,
            expected_source_signature: null,
            rows: attendancePreview.preview.canonical_rows,
          },
          { requestedAt: new Date(Date.now() + 30_000) },
        ),
      );
  assert(
    attendance.authoritative_readback.planning_inputs.attendance
      .attendance_status === "APPROVED" &&
      activeRows(
        attendance.authoritative_readback.planning_inputs.attendance,
        "lines",
      )[0]?.student_portions === 111,
    "Attendance +30s completion did not preserve authoritative 111/10.",
  );
  const tooFuture = commandRequest(
    "RMVP-03A.v2",
    subject,
    attendance.new_versions.aggregate_version,
    "ATTENDANCE_SAVED",
    {
      week_start: weekStart,
      source_type: "MANUAL_ATLAS",
      source_name: "Rejected future clock probe",
      source_signature: attendancePreview.preview.source_signature,
      expected_source_signature: attendancePreview.preview.source_signature,
      rows: attendancePreview.preview.canonical_rows,
    },
    { requestedAt: new Date(Date.now() + 120_000) },
  );
  const futureRejection = await invoke(client, "save_attendance", tooFuture, {
    rejected: true,
  });
  assert(
    futureRejection.error_code === "VALIDATION_FAILED" &&
      JSON.stringify(futureRejection).includes("requested_at"),
    "Beyond-tolerance requested_at was not rejected safely.",
  );

  const pantryWorkbench = (
    await invoke(
      client,
      "get_pantry_source_workbench",
      readRequest("PANTRY-02.v1", subject, { week_start: weekStart }),
    )
  ).workbench;
  const pantryPurpose = pantryWorkbench.purposes.find(
    (item) => item.purpose_code === "school_requested_supplement",
  );
  const pantryRows = [
    {
      service_date: weekStart,
      school_id: foundation.school.school_id,
      ingredient_id: ingredientId,
      pantry_need_purpose_id: pantryPurpose.pantry_need_purpose_id,
      requested_quantity: "1.250000",
      note: null,
      source_request_reference: "ASSEMBLY",
      source_row_reference: "assembly-pantry:1",
    },
  ];
  const pantryPreview = await invoke(
    client,
    "preview_pantry_source",
    readRequest("PANTRY-02.v1", subject, {
      week_start: weekStart,
      no_additions_confirmed: false,
      rows: pantryRows,
    }),
  );
  const pantryCodes = [
    ...pantryPreview.preview.issues.blockers,
    ...pantryPreview.preview.issues.warnings,
  ].map((item) => item.code);
  assert(
    (pantryPreview.preview.can_save === true ||
      (resumeAfterPantry &&
        pantryPreview.preview.comparison.status === "NO_CHANGE")) &&
      !pantryCodes.includes("MISSING_REQUIRED_NOTE") &&
      !pantryCodes.includes("WHITESPACE_ONLY_NOTE") &&
      pantryPreview.preview.canonical_rows[0]?.note === null,
    `OPTIONAL Pantry null Note was not canonical and valid (${pantryCodes.join(",") || "no issue code"}).`,
  );
  const meaningfulPreview = await invoke(
    client,
    "preview_pantry_source",
    readRequest("PANTRY-02.v1", subject, {
      week_start: weekStart,
      no_additions_confirmed: false,
      rows: [{ ...pantryRows[0], note: "Bổ sung có chủ đích." }],
    }),
  );
  assert(
    meaningfulPreview.preview.can_save ||
      (resumeAfterPantry &&
        meaningfulPreview.preview.issues.blockers.length === 0 &&
        meaningfulPreview.preview.canonical_rows[0]?.note ===
          "Bổ sung có chủ đích."),
    "Meaningful OPTIONAL Pantry Note was rejected.",
  );
  const pantry = resumeAfterPantry
    ? { authoritative_readback: { pantry: pantryWorkbench } }
    : await invoke(
        client,
        "save_pantry",
        commandRequest("PANTRY-02.v2", subject, 1, "PANTRY_SAVED", {
          week_start: weekStart,
          no_additions_confirmed: false,
          source_signature: pantryPreview.preview.source_signature,
          expected_source_signature: null,
          rows: pantryRows,
        }),
      );
  assert(
    pantry.authoritative_readback.pantry.batch.pantry_need_batch_status ===
      "APPROVED",
    "Positive Pantry completion was not APPROVED.",
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
      (
        preflight.preflight.blocking_issues ??
        preflight.preflight.blockers ??
        []
      ).length === 0,
    "Assembled Planning input preflight was not READY with zero blockers.",
  );
  const currentGeneration = resumeAfterGeneration
    ? await invoke(
        client,
        "get_need_generation_workbench",
        readRequest("RMVP-04.v1", subject, {
          period_start: weekStart,
          period_end: weekStart,
          need_generation_run_id: null,
          filters: {},
          group_offset: 0,
          group_limit: 100,
        }),
      )
    : null;
  const generated = resumeAfterGeneration
    ? null
    : await invoke(
        client,
        "execute_need_generation",
        commandRequest("RMVP-04.v3", subject, 1, "NEED_GENERATION_EXECUTED", {
          service_date: weekStart,
          expected_current_need_generation_run_id: null,
        }),
      );
  const runId = resumeAfterGeneration
    ? currentGeneration.workbench.selected_run.need_generation_run_id
    : generated.affected_aggregate_ids.need_generation_run_id;
  const confirmedNeedId = resumeAfterGeneration
    ? currentGeneration.workbench.materialization.confirmed_need_batch_id
    : generated.affected_aggregate_ids.confirmed_need_batch_id;
  assert(
    (resumeAfterGeneration || generated.downstream_currentness === "CURRENT") &&
      runId &&
      confirmedNeedId,
    "Atomic Need Generation did not materialize a current Confirmed Need.",
  );
  const generationRead =
    currentGeneration ??
    (await invoke(
      client,
      "get_need_generation_workbench",
      readRequest("RMVP-04.v1", subject, {
        period_start: weekStart,
        period_end: weekStart,
        need_generation_run_id: runId,
        filters: {},
        group_offset: 0,
        group_limit: 100,
      }),
    ));
  assert(
    generationRead.workbench.grouped_requirements.some(
      (group) => String(group.recipe_derived_quantity) === "12.1",
    ),
    `PostgreSQL did not produce exact 121 x 10 / 100 = 12.100000 theoretical quantity (${JSON.stringify(generationRead.workbench.grouped_requirements)}).`,
  );
  runSql(theoreticalQuantitySql(runId));

  const confirmedRead = await invoke(
    client,
    "get_confirmed_need_review",
    readRequest("RMVP-05.v1", subject, {
      confirmed_need_batch_id: confirmedNeedId,
      filters: {},
      line_offset: 0,
      line_limit: 10_000,
    }),
  );
  if (resumeAfterConfirmed) {
    assert(
      confirmedRead.workbench.batch_status ===
        "RELEASED_FOR_PURCHASE_HANDOFF" &&
        confirmedRead.workbench.editing_allowed === false &&
        confirmedRead.workbench.lifecycle_history[0]?.evidence_kind ===
          "RELEASE",
      "The same-stack Confirmed Need resume point is not released with history.",
    );
  } else {
    const confirmedLines = confirmedRead.workbench.lines
      .filter((line) => line.current_decision_id === null)
      .map((line) => ({
        confirmed_need_line_id: line.confirmed_need_line_id,
        expected_current_revision_id: line.current_revision_id,
        expected_current_decision_id: null,
        proposed_confirmed_quantity: line.proposed_confirmed_quantity,
        reason_code: "PROPOSAL_ACCEPTED",
        reason_note: null,
      }));
    const saved = await invoke(
      client,
      "save_confirmed_needs",
      confirmedCommand(
        subject,
        confirmedRead.workbench,
        "save",
        confirmedLines,
      ),
    );
    assert(
      saved.authoritative_readback.batch_status === "DRAFT_REVIEW" &&
        saved.authoritative_readback.editing_allowed === true &&
        saved.authoritative_readback.line_counts.unreviewed === 0,
      "Confirmed Need Save did not remain editable and fully reviewed.",
    );
    const released = await invoke(
      client,
      "release_confirmed_needs",
      confirmedCommand(subject, saved.authoritative_readback, "release"),
    );
    assert(
      released.authoritative_readback.batch_status ===
        "RELEASED_FOR_PURCHASE_HANDOFF" &&
        released.authoritative_readback.lifecycle_history[0]?.evidence_kind ===
          "RELEASE" &&
        released.authoritative_readback.lifecycle_history.some(
          (item) => item.evidence_kind === "VALIDATION",
        ),
      "Confirmed Need Release did not preserve immutable lifecycle evidence.",
    );
  }

  runSql(captureBusinessStateSql());
  runSql(buildFoundationPackageSql(foundation));
  runSql(buildFoundationVerificationSql(foundation));
  runSql(verifyBusinessStateSql());
  await client.auth.signOut({ scope: "local" });
  console.log(
    "Planning assembly acceptance passed: packages, 0/0→100/10 replay, public Admin/Recipe/source v2 workflows, +30s Attendance, OPTIONAL Pantry null Note, READY, atomic Need Generation, exact 12.100000 quantity, Confirmed Need Save/Release, downstream zero, and final replay preservation.",
  );
}

try {
  await main();
} catch (error) {
  console.error(
    error instanceof Error
      ? (error.stack ?? error.message)
      : "Planning assembly acceptance failed safely.",
  );
  process.exitCode = 1;
}
