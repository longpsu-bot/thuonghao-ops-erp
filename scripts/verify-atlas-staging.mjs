import { readdirSync, readFileSync } from "node:fs";
import { randomUUID } from "node:crypto";
import { fileURLToPath } from "node:url";
import { createClient } from "@supabase/supabase-js";
import {
  executeAtlasStagingManagementSql,
  redactAtlasStagingDiagnostic,
  throwPreferredFailure,
  validateAtlasStagingProtectedValues,
  verifyAtlasApiExposure,
} from "./atlas-staging-contract.mjs";
import {
  buildFoundationVerificationSql,
  buildIdentityVerificationSql,
  readAtlasStagingPackage,
} from "./install-atlas-staging-package.mjs";

export function migrationVersionsFromFilenames(names) {
  const sqlFiles = names.filter((name) => name.endsWith(".sql"));
  const malformed = sqlFiles.filter((name) => !/^\d{14}_.+\.sql$/.test(name));
  if (malformed.length) {
    throw new Error("Repository migration filenames are malformed.");
  }
  const versions = sqlFiles.map((name) => name.slice(0, 14)).sort();
  if (new Set(versions).size !== versions.length) {
    throw new Error("Repository migration versions are duplicated.");
  }
  return versions;
}

function repositoryMigrationVersions(cwd) {
  return migrationVersionsFromFilenames(
    readdirSync(`${cwd}/supabase/migrations`),
  );
}

const MIGRATION_EVIDENCE_MARKER = "ATLAS_MIGRATION_HISTORY=";

function collectStrings(value, result = []) {
  if (typeof value === "string") result.push(value);
  else if (Array.isArray(value)) {
    for (const item of value) collectStrings(item, result);
  } else if (value && typeof value === "object") {
    for (const item of Object.values(value)) collectStrings(item, result);
  }
  return result;
}

export function parseMigrationHistoryEvidence(output) {
  let envelope;
  try {
    envelope = JSON.parse(String(output));
  } catch {
    throw new Error(
      "Hosted migration evidence is not a valid Management API JSON response.",
    );
  }
  const marked = collectStrings(envelope).find((value) =>
    value.includes(MIGRATION_EVIDENCE_MARKER),
  );
  if (!marked) throw new Error("Hosted migration evidence marker is missing.");
  const payloadText = marked.slice(
    marked.indexOf(MIGRATION_EVIDENCE_MARKER) +
      MIGRATION_EVIDENCE_MARKER.length,
  );
  let payload;
  try {
    payload = JSON.parse(payloadText);
  } catch {
    throw new Error("Hosted migration evidence payload is malformed.");
  }
  return payload;
}

export function assertExactMigrationHistory(expectedVersions, evidence) {
  const remote = evidence?.versions;
  if (!Array.isArray(remote) || evidence?.row_count !== remote.length) {
    throw new Error("Hosted migration evidence is incomplete or malformed.");
  }
  if (remote.some((version) => !/^\d{14}$/.test(version))) {
    throw new Error("Hosted migration evidence contains malformed versions.");
  }
  if (new Set(remote).size !== remote.length) {
    throw new Error("Hosted migration evidence contains duplicate versions.");
  }
  const ordered = [...remote].sort();
  if (JSON.stringify(ordered) !== JSON.stringify(expectedVersions)) {
    throw new Error(
      "Hosted migration history does not match repository authority.",
    );
  }
}

function expectedArrayBeforeLabel(source, label) {
  const labelIndex = source.indexOf(label);
  if (labelIndex < 0)
    throw new Error(`Catalog authority label is missing: ${label}`);
  const arrayStart = source.lastIndexOf("array[", labelIndex);
  const arrayEnd = source.indexOf("]::text[]", arrayStart);
  if (arrayStart < 0 || arrayEnd < 0 || arrayEnd > labelIndex) {
    throw new Error(`Catalog authority array is malformed: ${label}`);
  }
  return [
    ...source.slice(arrayStart, arrayEnd).matchAll(/'((?:''|[^'])*)'/g),
  ].map((match) => match[1].replaceAll("''", "'"));
}

export function readCatalogAuthority(cwd = process.cwd()) {
  const source = readFileSync(
    `${cwd}/supabase/tests/atlas_current_platform_security_catalog.sql`,
    "utf8",
  );
  const cat22 = source.slice(
    source.lastIndexOf("jsonb_build_object(", source.indexOf("CAT-22")),
    source.indexOf("CAT-22"),
  );
  const policyCount = Number(/'policy_count',\s*(\d+)/.exec(cat22)?.[1]);
  const policyDigest = /'policy_catalog_md5',\s*'([0-9a-f]{32})'/.exec(
    cat22,
  )?.[1];
  if (!Number.isInteger(policyCount) || !policyDigest) {
    throw new Error("CAT-22 policy authority is malformed.");
  }
  return {
    schemas: expectedArrayBeforeLabel(source, "CAT-01"),
    databaseRoles: expectedArrayBeforeLabel(source, "CAT-04"),
    apiSignatures: expectedArrayBeforeLabel(source, "CAT-15"),
    apiOwners: expectedArrayBeforeLabel(source, "CAT-17"),
    policyCount,
    policyDigest,
  };
}

function sqlArray(values) {
  return `array[${values.map((value) => `'${value.replaceAll("'", "''")}'`).join(", ")}]::text[]`;
}

export function catalogVerificationSql(
  authority,
  { managedApplicationRole, allowMissingManagedApplicationRole = false } = {},
) {
  const schemas = sqlArray(authority.schemas);
  const roles = sqlArray(authority.databaseRoles);
  const signatures = sqlArray(authority.apiSignatures);
  const owners = sqlArray(authority.apiOwners);
  const managedRoleId = String(managedApplicationRole?.role_id ?? "");
  const managedRoleCode = String(managedApplicationRole?.role_code ?? "");
  if (
    managedApplicationRole &&
    (!/^[0-9a-f-]{36}$/i.test(managedRoleId) || !managedRoleCode)
  ) {
    throw new Error("The managed Atlas Staging application role is invalid.");
  }
  const exactManagedRole = managedApplicationRole
    ? `exists (select 1 from atlas_core.roles where role_id = '${managedRoleId}'::uuid and role_code = '${managedRoleCode.replaceAll("'", "''")}' and role_status = 'ACTIVE')`
    : undefined;
  const applicationRoleMismatch = exactManagedRole
    ? allowMissingManagedApplicationRole
      ? `(select count(*) from atlas_core.roles) > 1 or ((select count(*) from atlas_core.roles) = 1 and not ${exactManagedRole})`
      : `(select count(*) from atlas_core.roles) <> 1 or not ${exactManagedRole}`
    : `(select count(*) from atlas_core.roles) <> 0`;
  return `do $$
declare
  actual text[];
  private_grants bigint;
  normal_policy_count bigint;
  isolated_policy_count bigint;
  policy_digest text;
begin
  select array_agg(nspname order by nspname)::text[] into actual from pg_namespace where nspname like 'atlas\\_%' escape '\\';
  if actual is distinct from ${schemas} then
    raise exception 'ATLAS_CATALOG_SCHEMA_MISMATCH';
  end if;
  select array_agg(format('%s|login=%s|inherit=%s|super=%s|createrole=%s|createdb=%s|repl=%s|bypassrls=%s', rolname, rolcanlogin, rolinherit, rolsuper, rolcreaterole, rolcreatedb, rolreplication, rolbypassrls) order by rolname)::text[] into actual from pg_roles where rolname like 'atlas\\_%' escape '\\';
  if actual is distinct from ${roles} or ${applicationRoleMismatch} then
    raise exception 'ATLAS_DATABASE_ROLE_POSTURE_MISMATCH';
  end if;
  if exists (select 1 from pg_roles r cross join pg_namespace n where r.rolname like 'atlas\\_%' escape '\\' and r.rolname <> 'atlas_owner' and n.nspname like 'atlas\\_%' escape '\\' and has_schema_privilege(r.rolname, n.nspname, 'CREATE')) then
    raise exception 'ATLAS_RUNTIME_SCHEMA_CREATE_GRANT_MISMATCH';
  end if;
  select array_agg(format('%s(%s)', p.proname, pg_get_function_identity_arguments(p.oid)) order by p.proname, pg_get_function_identity_arguments(p.oid))::text[] into actual from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'atlas_api';
  if actual is distinct from ${signatures} then
    raise exception 'ATLAS_API_SIGNATURE_MISMATCH';
  end if;
  select array_agg(format('%s(%s)=%s', p.proname, pg_get_function_identity_arguments(p.oid), r.rolname) order by p.proname, pg_get_function_identity_arguments(p.oid))::text[] into actual from pg_proc p join pg_namespace n on n.oid = p.pronamespace join pg_roles r on r.oid = p.proowner where n.nspname = 'atlas_api';
  if actual is distinct from ${owners} then
    raise exception 'ATLAS_API_OWNER_MISMATCH';
  end if;
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'atlas_api' and (not p.prosecdef or p.proconfig is distinct from array['search_path=""']::text[])) then
    raise exception 'ATLAS_API_SECURITY_MODE_MISMATCH';
  end if;
  select array_agg(format('%s(%s)', p.proname, pg_get_function_identity_arguments(p.oid)) order by p.proname, pg_get_function_identity_arguments(p.oid))::text[] into actual from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'atlas_api' and has_function_privilege('authenticated', p.oid, 'EXECUTE');
  if actual is distinct from ${signatures} or exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'atlas_api' and (has_function_privilege('anon', p.oid, 'EXECUTE') or has_function_privilege('service_role', p.oid, 'EXECUTE'))) then
    raise exception 'ATLAS_API_EXECUTE_GRANT_MISMATCH';
  end if;
  if not has_schema_privilege('authenticated', 'atlas_api', 'USAGE') or has_schema_privilege('anon', 'atlas_api', 'USAGE') or has_schema_privilege('service_role', 'atlas_api', 'USAGE') then
    raise exception 'ATLAS_API_SCHEMA_GRANT_MISMATCH';
  end if;
  select count(*) into private_grants from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname in ('atlas_core','atlas_admin','atlas_planning','atlas_procurement','atlas_evidence','atlas_dispatch','atlas_audit','atlas_reporting','atlas_legacy') and c.relkind in ('r','p','v','m','S') and (has_table_privilege('anon', c.oid, 'SELECT,INSERT,UPDATE,DELETE') or has_table_privilege('authenticated', c.oid, 'SELECT,INSERT,UPDATE,DELETE') or has_table_privilege('service_role', c.oid, 'SELECT,INSERT,UPDATE,DELETE'));
  if private_grants <> 0 then raise exception 'ATLAS_PRIVATE_RELATION_EXPOSURE'; end if;
  with normal_policy_catalog as (
    select format('%s|%s|%s|%s|%s|%s|%s|%s', n.nspname, c.relname, p.polname, p.polpermissive, p.polcmd, array(select coalesce((select rolname from pg_roles where oid = role_oid), 'PUBLIC') from unnest(p.polroles) role_oid order by 1)::text, coalesce(pg_get_expr(p.polqual, p.polrelid), '<null>'), coalesce(pg_get_expr(p.polwithcheck, p.polrelid), '<null>')) as row_text
    from pg_policy p
    join pg_class c on c.oid = p.polrelid
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname like 'atlas\\_%' escape '\\'
      and not (n.nspname = 'atlas_admin' and c.relname = 'units' and p.polname = 'rmvp_05_unit_lock')
  )
  select count(*), md5(string_agg(row_text, E'\\n' order by row_text))
  into normal_policy_count, policy_digest
  from normal_policy_catalog;
  if normal_policy_count <> ${authority.policyCount} then
    raise exception 'ATLAS_POLICY_COUNT_MISMATCH';
  end if;
  if policy_digest is distinct from '${authority.policyDigest}' then raise exception 'ATLAS_POLICY_DIGEST_MISMATCH'; end if;
  select count(*) into isolated_policy_count
  from pg_policy p
  join pg_class c on c.oid = p.polrelid
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'atlas_admin'
    and c.relname = 'units'
    and p.polname = 'rmvp_05_unit_lock';
  if isolated_policy_count <> 1 then raise exception 'ATLAS_ISOLATED_POLICY_MISMATCH'; end if;
end $$;`;
}

function actorVerificationSql(authSubject) {
  if (!/^[0-9a-f-]{36}$/i.test(authSubject)) {
    throw new Error("The staging Auth subject is invalid.");
  }
  return `do $$ begin
    if (select count(*) from atlas_core.actor_auth_subjects s join atlas_core.actors a on a.actor_id = s.actor_id where s.auth_provider = 'SUPABASE_AUTH' and s.auth_subject_id = '${authSubject}'::uuid and s.subject_status = 'ACTIVE' and a.actor_status = 'ACTIVE') <> 1 then
      raise exception 'ATLAS_ACTIVE_ACTOR_MAPPING_MISMATCH';
    end if;
  end $$;`;
}

export function assertAnonymousAuthorizationDenial(error) {
  const code = String(error?.code ?? "");
  const message = String(error?.message ?? "");
  if (code !== "42501" || !/permission denied/i.test(message)) {
    throw new Error(
      "The anonymous Atlas API probe did not return the expected authorization denial.",
    );
  }
}

function migrationHistorySql() {
  return `select '${MIGRATION_EVIDENCE_MARKER}' || json_build_object(
    'versions', coalesce(json_agg(version order by version), '[]'::json),
    'row_count', count(*)
  )::text
  from supabase_migrations.schema_migrations;`;
}

export function planAtlasStagingVerification(environment = process.env) {
  const target = validateAtlasStagingProtectedValues(environment, {
    requireDatabasePassword: false,
  });
  return {
    target,
    commands: [
      ["Management API", "POST", "<approved-staging-database-query>"],
      ["Management API", "migration and catalog verification SQL"],
      ["Data API", "anonymous atlas_api authorization probe"],
    ],
    networkWrites: false,
  };
}

export async function verifyAtlasStaging({
  environment = process.env,
  cwd = process.cwd(),
  fetchImpl = fetch,
  createClientFactory = createClient,
  dryRun = false,
  platformOnly = false,
} = {}) {
  const plan = planAtlasStagingVerification(environment);
  if (dryRun) return plan;

  const { target } = plan;
  const migrations = await executeAtlasStagingManagementSql(
    target,
    migrationHistorySql(),
    fetchImpl,
  );
  assertExactMigrationHistory(
    repositoryMigrationVersions(cwd),
    parseMigrationHistoryEvidence(migrations),
  );
  const identityManifest = readAtlasStagingPackage("identity", cwd);
  const foundationManifest = platformOnly
    ? undefined
    : readAtlasStagingPackage("foundation", cwd);
  await executeAtlasStagingManagementSql(
    target,
    catalogVerificationSql(readCatalogAuthority(cwd), {
      managedApplicationRole: identityManifest.role,
      allowMissingManagedApplicationRole: platformOnly,
    }),
    fetchImpl,
  );

  const health = await fetchImpl(`${target.supabaseUrl}/auth/v1/health`, {
    headers: { apikey: target.publishableKey },
  });
  if (!health.ok)
    throw new Error("The Atlas staging project API is not reachable.");
  await verifyAtlasApiExposure(target, fetchImpl);

  const anonymousClient = createClientFactory(
    target.supabaseUrl,
    target.publishableKey,
    {
      db: { retry: false },
      auth: {
        autoRefreshToken: false,
        persistSession: false,
        detectSessionInUrl: false,
      },
    },
  );
  const anonymousAttempt = await anonymousClient
    .schema("atlas_api")
    .rpc("get_operator_blockers", { request: {} })
    .retry(false);
  assertAnonymousAuthorizationDenial(anonymousAttempt.error);
  if (platformOnly) return { status: "verified", phase: "platform" };

  await executeAtlasStagingManagementSql(
    target,
    `${buildIdentityVerificationSql(identityManifest)}\n${buildFoundationVerificationSql(foundationManifest)}`,
    fetchImpl,
  );

  const client = createClientFactory(
    target.supabaseUrl,
    target.publishableKey,
    {
      db: { retry: false },
      auth: {
        autoRefreshToken: false,
        persistSession: false,
        detectSessionInUrl: false,
      },
    },
  );
  const { data: signIn, error: signInError } =
    await client.auth.signInWithPassword({
      email: target.testEmail,
      password: target.testPassword,
    });
  if (signInError || !signIn.session?.user.id) {
    throw new Error("Protected Atlas staging sign-in failed safely.");
  }

  let verificationFailure;
  try {
    const authSubject = signIn.session.user.id;
    await executeAtlasStagingManagementSql(
      target,
      actorVerificationSql(authSubject),
      fetchImpl,
    );
    const { data: readResult, error: readError } = await client
      .schema("atlas_api")
      .rpc("get_school_master_data", {
        request: {
          contract_version: "RMVP-01.v1",
          correlation_id: randomUUID(),
          requested_by_auth_subject: authSubject,
          payload: {},
        },
      })
      .retry(false);
    // This authorization probe requires the managed School, not an exclusive catalog.
    if (
      readError ||
      readResult?.success !== true ||
      !Array.isArray(readResult.schools) ||
      !readResult.schools.some(
        (school) => school?.school_id === foundationManifest.school.school_id,
      )
    ) {
      verificationFailure = new Error(
        "The approved authenticated Atlas read failed safely.",
      );
    }
  } catch (error) {
    verificationFailure = error;
  }
  let cleanupFailure;
  try {
    const { error: signOutError } = await client.auth.signOut({
      scope: "local",
    });
    const { data: afterSignOut, error: sessionError } =
      await client.auth.getSession();
    if (signOutError || sessionError || afterSignOut.session)
      cleanupFailure = new Error("The staging session was not cleared safely.");
  } catch (error) {
    cleanupFailure = error;
  }
  throwPreferredFailure(verificationFailure, cleanupFailure);
  return { status: "verified", phase: "acceptance" };
}

async function main() {
  const dryRun = process.argv.includes("--dry-run");
  const platformOnly = process.argv.includes("--platform-only");
  const result = await verifyAtlasStaging({ dryRun, platformOnly });
  console.log(
    dryRun
      ? "Atlas staging verifier dry-run passed without network or process execution."
      : `Atlas staging read-only ${result.phase} verification passed.`,
  );
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  main().catch((error) => {
    console.error(
      redactAtlasStagingDiagnostic(
        error instanceof Error
          ? error.message
          : "Atlas staging verification failed safely.",
      ),
    );
    process.exitCode = 1;
  });
}
