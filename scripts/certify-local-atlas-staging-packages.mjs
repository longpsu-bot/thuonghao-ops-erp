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

function cleanBaselineSql() {
  return `do $atlas_staging_clean_baseline$
begin
  if (select count(*) from atlas_core.actors) <> 0
    or (select count(*) from atlas_core.roles) <> 0
    or (select count(*) from atlas_admin.customers) <> 0
    or (select count(*) from atlas_admin.schools) <> 0
    or (select count(*) from atlas_admin.units) <> 0
    or (select count(*) from atlas_planning.pantry_need_purposes) <> 0
    or (select count(*) from atlas_planning.planning_quantity_policies) <> 0 then
    raise exception 'ATLAS_STAGING_LOCAL_BASELINE_NOT_CLEAN';
  end if;
end;
$atlas_staging_clean_baseline$;`;
}

function operatorFactsRemainEmptySql(identityManifest) {
  const actorId = identityManifest.actor.actor_id;
  const roleId = identityManifest.role.role_id;
  return `do $atlas_staging_operator_facts_empty$
declare relation_name text;
declare row_count bigint;
begin
  foreach relation_name in array array[
    'atlas_admin.ingredients',
    'atlas_admin.suppliers',
    'atlas_admin.supplier_eligibilities',
    'atlas_admin.dishes',
    'atlas_admin.recipes',
    'atlas_admin.recipe_versions',
    'atlas_admin.recipe_lines',
    'atlas_admin.recipe_composition_adjustments',
    'atlas_planning.weekly_menus',
    'atlas_planning.attendance_batches',
    'atlas_planning.pantry_need_batches',
    'atlas_planning.planning_input_sets',
    'atlas_planning.planning_input_evaluations',
    'atlas_planning.need_generation_runs',
    'atlas_planning.confirmed_need_batches',
    'atlas_planning.purchase_handoff_batches',
    'atlas_planning.wholesale_orders',
    'atlas_procurement.purchase_orders',
    'atlas_dispatch.dispatch_plans'
  ] loop
    execute format('select count(*) from %s', relation_name) into row_count;
    if row_count <> 0 then
      raise exception 'ATLAS_STAGING_OPERATOR_FACT_PRESENT:%', relation_name;
    end if;
  end loop;
  if exists (
    select 1
      from atlas_core.role_capabilities role_capability
      join atlas_core.capabilities capability using (capability_id)
      where role_capability.role_id = '${roleId}'::uuid
        and capability.capability_code in (
          'master_data.recipes.import',
          'confirmed_need_approval.approve'
        )
  ) or (select count(*) from atlas_core.actors where actor_id = '${actorId}'::uuid) <> 1 then
    raise exception 'ATLAS_STAGING_NEGATIVE_CAPABILITY_POSTURE_MISMATCH';
  end if;
end;
$atlas_staging_operator_facts_empty$;`;
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
  runLocalSql(buildFoundationPackageSql(foundation));
  runLocalSql(buildFoundationVerificationSql(foundation));
  runLocalSql(buildFoundationPackageSql(foundation));
  runLocalSql(buildFoundationVerificationSql(foundation));
  runLocalSql(operatorFactsRemainEmptySql(identity));
  await verifyBrowserAuthorization({
    apiUrl,
    browserKey,
    email,
    password,
    authSubjectId: identity.auth_user.auth_subject_id,
  });
  return {
    identity: "first-install-and-replay-passed",
    foundation: "first-install-and-replay-passed",
    browserAuthorization: "passed",
    operatorFacts: "absent",
  };
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  certifyLocalAtlasStagingPackages()
    .then(() => {
      console.log(
        "Local Atlas Staging Identity and Foundation first-install, replay, authorization, and exclusion certification passed.",
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
