import { randomUUID } from "node:crypto";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
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

function requireLocalCredential(name) {
  const value = String(process.env[name] ?? "").trim();
  if (!value)
    throw new Error(`Set ${name} for the local-only certification run.`);
  return value;
}

function runLocalSql(statement) {
  const temporaryDirectory = mkdtempSync(
    join(tmpdir(), "atlas-staging-certification-"),
  );
  const sqlPath = join(temporaryDirectory, "query.sql");
  try {
    writeFileSync(sqlPath, statement, { encoding: "utf8", flag: "wx" });
    runPinnedSupabase(
      ["db", "query", "--local", "--file", sqlPath, "--agent", "no"],
      {
        stdio: ["ignore", "ignore", "inherit"],
      },
    );
  } finally {
    rmSync(temporaryDirectory, { force: true, recursive: true });
  }
}

function conflictingCalculationContractSql(manifest, conflictKind) {
  const contract = manifest.need_generation_calculation_contract;
  const actorId = manifest.identity_actor_id;
  const rootId =
    conflictKind === "root"
      ? "c1020000-0000-4000-8000-000000000230"
      : contract.need_generation_calculation_contract_id;
  const revisionId =
    conflictKind === "root"
      ? "c1020000-0000-4000-8000-000000000231"
      : contract.need_generation_calculation_contract_revision_id;
  const approvedAtSql =
    conflictKind === "revision"
      ? `'${contract.evidence_timestamp}'::timestamptz + interval '1 second'`
      : `'${contract.evidence_timestamp}'::timestamptz`;
  const expectedDiagnostic =
    conflictKind === "root"
      ? "ATLAS_STAGING_FOUNDATION_NEED_GENERATION_CONTRACT_MISMATCH"
      : "ATLAS_STAGING_FOUNDATION_NEED_GENERATION_CONTRACT_REVISION_MISMATCH";
  return `do $atlas_staging_foundation_conflict_probe$
declare conflict_rejected boolean := false;
begin
begin
insert into atlas_planning.need_generation_calculation_contracts (
  need_generation_calculation_contract_id, contract_code, current_revision_id,
  version, created_at, updated_at
) values (
  '${rootId}'::uuid, '${contract.contract_code}', '${revisionId}'::uuid,
  ${contract.revision_number}, '${contract.evidence_timestamp}'::timestamptz,
  '${contract.evidence_timestamp}'::timestamptz
);
insert into atlas_planning.need_generation_calculation_contract_revisions (
  need_generation_calculation_contract_revision_id,
  need_generation_calculation_contract_id, revision_number, formula_kind,
  quantity_precision, quantity_scale, factor_precision, factor_scale,
  final_coercion_mode, approved_by_actor_id, approved_at
) values (
  '${revisionId}'::uuid, '${rootId}'::uuid, ${contract.revision_number},
  '${contract.formula_kind}', ${contract.quantity_precision},
  ${contract.quantity_scale}, ${contract.factor_precision},
  ${contract.factor_scale}, '${contract.final_coercion_mode}',
  '${actorId}'::uuid, ${approvedAtSql}
);
execute $atlas_staging_foundation_package_sql$
${buildFoundationPackageSql(manifest)}
$atlas_staging_foundation_package_sql$;
exception when others then
  if sqlerrm <> '${expectedDiagnostic}' then raise; end if;
  conflict_rejected := true;
end;
if not conflict_rejected then
  raise exception 'ATLAS_STAGING_FOUNDATION_CONFLICT_WAS_NOT_REJECTED';
end if;
end;
$atlas_staging_foundation_conflict_probe$;`;
}

function cleanBaselineSql() {
  return `do $atlas_staging_clean_baseline$
begin
  if (select count(*) from atlas_core.actors) <> 0
    or (select count(*) from atlas_core.roles) <> 0
    or (select count(*) from atlas_admin.customers) <> 0
    or (select count(*) from atlas_admin.schools) <> 0
    or (select count(*) from atlas_admin.units) <> 0
    or (select count(*) from atlas_planning.pantry_need_purposes) <> 0
    or (select count(*) from atlas_planning.planning_quantity_policies) <> 0
    or (select count(*) from atlas_planning.need_generation_calculation_contracts) <> 0
    or (select count(*) from atlas_planning.need_generation_calculation_contract_revisions) <> 0 then
    raise exception 'ATLAS_STAGING_LOCAL_BASELINE_NOT_CLEAN';
  end if;
end;
$atlas_staging_clean_baseline$;`;
}

function initialFoundationStateSql(foundationManifest) {
  const schoolId = foundationManifest.school.school_id;
  const contract = foundationManifest.need_generation_calculation_contract;
  return `do $atlas_staging_initial_foundation_state$
begin
  if (select count(*) from atlas_admin.schools
      where school_id = '${schoolId}'::uuid
        and default_student_portions = 0
        and default_teacher_portions = 0
        and version = 1) <> 1
    or (select count(*) from atlas_audit.domain_events
        where aggregate_type = 'School' and aggregate_id = '${schoolId}'::uuid) <> 0
    or (select count(*) from atlas_audit.audit_events
        where aggregate_type = 'School' and aggregate_id = '${schoolId}'::uuid) <> 0
    or (select count(*) from atlas_planning.need_generation_calculation_contracts
        where need_generation_calculation_contract_id =
          '${contract.need_generation_calculation_contract_id}'::uuid) <> 1
    or (select count(*) from atlas_planning.need_generation_calculation_contract_revisions
        where need_generation_calculation_contract_revision_id =
          '${contract.need_generation_calculation_contract_revision_id}'::uuid) <> 1 then
    raise exception 'ATLAS_STAGING_INITIAL_FOUNDATION_STATE_MISMATCH';
  end if;
end;
$atlas_staging_initial_foundation_state$;`;
}

function operatorSourceFactsFixtureSql(identityManifest, foundationManifest) {
  const actorId = identityManifest.actor.actor_id;
  const schoolId = foundationManifest.school.school_id;
  return `do $atlas_staging_operator_source_facts_fixture$
begin
  insert into atlas_planning.weekly_menus (
    weekly_menu_id, week_start, week_end, source_type, source_name,
    source_signature, imported_by_actor_id
  ) values (
    'a1030000-0000-4000-8000-000000000001'::uuid,
    '2026-08-24'::date, '2026-08-30'::date, 'LOCAL_CERTIFICATION',
    'Foundation replay preservation fixture', repeat('1', 64),
    '${actorId}'::uuid
  );
  insert into atlas_planning.attendance_batches (
    attendance_batch_id, period_start, period_end, source_type, source_name,
    source_signature, imported_by_actor_id
  ) values (
    'a1030000-0000-4000-8000-000000000002'::uuid,
    '2026-08-24'::date, '2026-08-30'::date, 'LOCAL_CERTIFICATION',
    'Foundation replay preservation fixture', repeat('2', 64),
    '${actorId}'::uuid
  );
  insert into atlas_planning.pantry_need_batches (
    pantry_need_batch_id, week_start, source_signature, requesting_actor_id
  ) values (
    'a1030000-0000-4000-8000-000000000003'::uuid,
    '2026-08-24'::date, repeat('3', 64), '${actorId}'::uuid
  );

  drop table if exists extensions.atlas_staging_foundation_replay_baseline;
  create table extensions.atlas_staging_foundation_replay_baseline (
    fact_kind text primary key,
    fact_row jsonb not null
  );
  insert into extensions.atlas_staging_foundation_replay_baseline
    (fact_kind, fact_row)
  select 'School', to_jsonb(school)
    from atlas_admin.schools school
    where school.school_id = '${schoolId}'::uuid
  union all
  select 'Weekly Menu', to_jsonb(menu)
    from atlas_planning.weekly_menus menu
    where menu.weekly_menu_id = 'a1030000-0000-4000-8000-000000000001'::uuid
  union all
  select 'Attendance', to_jsonb(attendance)
    from atlas_planning.attendance_batches attendance
    where attendance.attendance_batch_id = 'a1030000-0000-4000-8000-000000000002'::uuid
  union all
  select 'Pantry', to_jsonb(pantry)
    from atlas_planning.pantry_need_batches pantry
    where pantry.pantry_need_batch_id = 'a1030000-0000-4000-8000-000000000003'::uuid;

  if (select count(*) from extensions.atlas_staging_foundation_replay_baseline) <> 4 then
    raise exception 'ATLAS_STAGING_OPERATOR_SOURCE_FIXTURE_MISMATCH';
  end if;
end;
$atlas_staging_operator_source_facts_fixture$;`;
}

function foundationReplayPreservationSql(identityManifest, foundationManifest) {
  const actorId = identityManifest.actor.actor_id;
  const roleId = identityManifest.role.role_id;
  const schoolId = foundationManifest.school.school_id;
  const contract = foundationManifest.need_generation_calculation_contract;
  return `do $atlas_staging_foundation_replay_preservation$
begin
  if (select count(*) from atlas_admin.schools
      where school_id = '${schoolId}'::uuid
        and default_student_portions = 100
        and default_teacher_portions = 10
        and version = 2) <> 1
    or (select fact_row from extensions.atlas_staging_foundation_replay_baseline
        where fact_kind = 'School') is distinct from
       (select to_jsonb(school) from atlas_admin.schools school
        where school.school_id = '${schoolId}'::uuid)
    or (select fact_row from extensions.atlas_staging_foundation_replay_baseline
        where fact_kind = 'Weekly Menu') is distinct from
       (select to_jsonb(menu) from atlas_planning.weekly_menus menu
        where menu.weekly_menu_id = 'a1030000-0000-4000-8000-000000000001'::uuid)
    or (select fact_row from extensions.atlas_staging_foundation_replay_baseline
        where fact_kind = 'Attendance') is distinct from
       (select to_jsonb(attendance) from atlas_planning.attendance_batches attendance
        where attendance.attendance_batch_id = 'a1030000-0000-4000-8000-000000000002'::uuid)
    or (select fact_row from extensions.atlas_staging_foundation_replay_baseline
        where fact_kind = 'Pantry') is distinct from
       (select to_jsonb(pantry) from atlas_planning.pantry_need_batches pantry
        where pantry.pantry_need_batch_id = 'a1030000-0000-4000-8000-000000000003'::uuid)
    or (select count(*) from atlas_planning.weekly_menus) <> 1
    or (select count(*) from atlas_planning.attendance_batches) <> 1
    or (select count(*) from atlas_planning.pantry_need_batches) <> 1
    or (select count(*) from atlas_audit.domain_events
        where event_type = 'SchoolPortionDefaultsUpdated'
          and aggregate_type = 'School' and aggregate_id = '${schoolId}'::uuid
          and aggregate_version = 2 and actor_id = '${actorId}'::uuid) <> 1
    or (select count(*) from atlas_audit.audit_events
        where event_type = 'SchoolPortionDefaultsUpdated'
          and aggregate_type = 'School' and aggregate_id = '${schoolId}'::uuid
          and aggregate_version_before = 1 and aggregate_version_after = 2
          and actor_id = '${actorId}'::uuid) <> 1
    or (select count(*) from atlas_planning.need_generation_calculation_contracts
        where need_generation_calculation_contract_id =
          '${contract.need_generation_calculation_contract_id}'::uuid) <> 1
    or (select count(*) from atlas_planning.need_generation_calculation_contract_revisions
        where need_generation_calculation_contract_revision_id =
          '${contract.need_generation_calculation_contract_revision_id}'::uuid) <> 1
    or (select count(*) from atlas_planning.need_generation_calculation_contracts) <> 1
    or (select count(*) from atlas_planning.need_generation_calculation_contract_revisions) <> 1
    or (select count(*) from atlas_planning.planning_input_sets) <> 0
    or (select count(*) from atlas_planning.need_generation_runs) <> 0
    or (select count(*) from atlas_planning.confirmed_need_batches) <> 0
    or (select count(*) from atlas_planning.confirmed_need_line_decisions) <> 0
    or (select count(*) from atlas_planning.confirmed_need_releases) <> 0
    or (select count(*) from atlas_planning.purchase_handoff_batches) <> 0
    or (select count(*) from atlas_procurement.fulfilment_allocations) <> 0
    or (select count(*) from atlas_procurement.purchase_orders) <> 0
    or (select count(*) from atlas_evidence.supplier_receiving_evidence) <> 0
    or (select count(*) from atlas_dispatch.dispatch_plans) <> 0
    or exists (
      select 1
        from atlas_core.role_capabilities role_capability
        join atlas_core.capabilities capability using (capability_id)
        where role_capability.role_id = '${roleId}'::uuid
          and capability.capability_code in (
            'master_data.recipes.import',
            'confirmed_need_approval.approve'
          )
    ) then
    raise exception 'ATLAS_STAGING_FOUNDATION_REPLAY_PRESERVATION_MISMATCH';
  end if;
end;
$atlas_staging_foundation_replay_preservation$;`;
}

function assertAnonymousDenial(error) {
  if (
    String(error?.code ?? "") !== "42501" ||
    !/permission denied/i.test(String(error?.message ?? ""))
  ) {
    throw new Error("The anonymous local package probe was not denied safely.");
  }
}

function clientOptions() {
  return {
    db: { retry: false },
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  };
}

async function applyOperatorSchoolPortionDefaults({
  apiUrl,
  browserKey,
  email,
  password,
  authSubjectId,
  schoolId,
}) {
  const client = createClient(apiUrl, browserKey, clientOptions());
  const { data: signIn, error: signInError } =
    await client.auth.signInWithPassword({ email, password });
  if (signInError || signIn.session?.user.id !== authSubjectId) {
    throw new Error(
      "The managed local package identity could not sign in for the School workflow.",
    );
  }
  let workflowFailure;
  try {
    const { data, error } = await client
      .schema("atlas_api")
      .rpc("update_school_portion_defaults_bulk", {
        request: {
          contract_version: "RMVP-01.v2",
          command_id: randomUUID(),
          correlation_id: randomUUID(),
          idempotency_key: `foundation-replay-school-defaults-${randomUUID()}`,
          requested_by_auth_subject: authSubjectId,
          requested_at: new Date().toISOString(),
          reason_code: "SCHOOL_PORTION_DEFAULTS_BULK_UPDATE",
          reason_note: "Local Foundation replay preservation certification.",
          payload: {
            changes: [
              {
                school_id: schoolId,
                expected_version: 1,
                default_student_portions: 100,
                default_teacher_portions: 10,
              },
            ],
          },
        },
      })
      .retry(false);
    const updatedSchool = data?.updated_schools?.[0];
    if (
      error ||
      data?.success !== true ||
      data?.contract_version !== "RMVP-01.v2" ||
      data?.updated_schools?.length !== 1 ||
      updatedSchool?.school_id !== schoolId ||
      updatedSchool?.version !== 2 ||
      updatedSchool?.default_student_portions !== 100 ||
      updatedSchool?.default_teacher_portions !== 10
    ) {
      throw new Error(
        "The authoritative local School-default workflow did not produce exact 100/10 version-2 evidence.",
      );
    }
  } catch (error) {
    workflowFailure = error;
  } finally {
    const { error: signOutError } = await client.auth.signOut({
      scope: "local",
    });
    if (signOutError)
      throw new Error("The local School-workflow session was not cleared.");
  }
  if (workflowFailure) throw workflowFailure;
}

async function verifyBrowserAuthorization({
  apiUrl,
  browserKey,
  email,
  password,
  authSubjectId,
}) {
  const anonymous = createClient(apiUrl, browserKey, clientOptions());
  const anonymousAttempt = await anonymous
    .schema("atlas_api")
    .rpc("get_school_master_data", { request: {} })
    .retry(false);
  assertAnonymousDenial(anonymousAttempt.error);

  const client = createClient(apiUrl, browserKey, clientOptions());
  const { data: signIn, error: signInError } =
    await client.auth.signInWithPassword({ email, password });
  if (signInError || signIn.session?.user.id !== authSubjectId) {
    throw new Error(
      "The managed local package identity could not sign in safely.",
    );
  }
  let verificationFailure;
  try {
    const { data, error } = await client
      .schema("atlas_api")
      .rpc("get_school_master_data", {
        request: {
          contract_version: "RMVP-01.v1",
          correlation_id: randomUUID(),
          requested_by_auth_subject: authSubjectId,
          payload: {},
        },
      })
      .retry(false);
    if (
      error ||
      data?.success !== true ||
      !Array.isArray(data.schools) ||
      data.schools.length !== 1
    ) {
      throw new Error(
        "The approved local package read did not succeed exactly.",
      );
    }
  } catch (error) {
    verificationFailure = error;
  } finally {
    const { error: signOutError } = await client.auth.signOut({
      scope: "local",
    });
    if (signOutError)
      throw new Error("The local certification session was not cleared.");
  }
  if (verificationFailure) throw verificationFailure;
}

export async function certifyLocalAtlasStagingPackages() {
  const email = requireLocalCredential("ATLAS_STAGING_TEST_EMAIL");
  const password = requireLocalCredential("ATLAS_STAGING_TEST_PASSWORD");
  if (
    !email.toLocaleLowerCase("en").endsWith("@local.test") ||
    password.length < 12
  ) {
    throw new Error(
      "Local package credentials do not satisfy the local-only safety guard.",
    );
  }

  runPinnedSupabase(["db", "reset", "--local", "--no-seed"], {
    stdio: ["ignore", "ignore", "inherit"],
  });
  const { apiUrl, browserKey, serviceRoleKey } = readLocalSupabaseStatus({
    requireAdminKey: true,
  });
  runLocalSql(cleanBaselineSql());

  const cwd = fileURLToPath(new URL("..", import.meta.url));
  const identity = readAtlasStagingPackage("identity", cwd);
  const foundation = readAtlasStagingPackage("foundation", cwd);
  const reconcileIdentity = async () => {
    const result = await reconcileManagedAuthUser({
      manifest: identity,
      email,
      password,
      supabaseUrl: apiUrl,
      secretKey: serviceRoleKey,
    });
    runLocalSql(buildIdentityPackageSql(identity));
    runLocalSql(buildIdentityVerificationSql(identity));
    return result;
  };

  const firstIdentity = await reconcileIdentity();
  const replayIdentity = await reconcileIdentity();
  if (firstIdentity.replay || !replayIdentity.replay) {
    throw new Error("Identity package replay evidence is inconsistent.");
  }
  runLocalSql(conflictingCalculationContractSql(foundation, "root"));
  runLocalSql(conflictingCalculationContractSql(foundation, "revision"));
  runLocalSql(buildFoundationPackageSql(foundation));
  runLocalSql(buildFoundationVerificationSql(foundation));
  runLocalSql(initialFoundationStateSql(foundation));
  await applyOperatorSchoolPortionDefaults({
    apiUrl,
    browserKey,
    email,
    password,
    authSubjectId: identity.auth_user.auth_subject_id,
    schoolId: foundation.school.school_id,
  });
  runLocalSql(operatorSourceFactsFixtureSql(identity, foundation));
  runLocalSql(buildFoundationPackageSql(foundation));
  runLocalSql(buildFoundationVerificationSql(foundation));
  runLocalSql(foundationReplayPreservationSql(identity, foundation));
  runLocalSql(buildFoundationPackageSql(foundation));
  runLocalSql(buildFoundationVerificationSql(foundation));
  runLocalSql(foundationReplayPreservationSql(identity, foundation));
  await verifyBrowserAuthorization({
    apiUrl,
    browserKey,
    email,
    password,
    authSubjectId: identity.auth_user.auth_subject_id,
  });
  return {
    identity: "first-install-and-replay-passed",
    foundation: "first-install-operator-change-and-two-replays-passed",
    schoolPortions: "initial-0-0-then-preserved-100-10-version-2",
    sourceFacts: "weekly-menu-attendance-pantry-preserved",
    calculationContract: "exact-single-root-and-revision-preserved",
    browserAuthorization: "passed",
    downstreamFacts: "absent",
  };
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  certifyLocalAtlasStagingPackages()
    .then(() => {
      console.log(
        "Local Atlas Staging Identity and Foundation first-install, operator School change, two replays, source preservation, authorization, calculation-contract, and downstream-exclusion certification passed.",
      );
    })
    .catch((error) => {
      console.error(
        error instanceof Error
          ? error.message
          : "Local Atlas Staging package certification failed safely.",
      );
      process.exitCode = 1;
    });
}
