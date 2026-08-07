import { readdirSync, readFileSync } from "node:fs";
import { randomUUID } from "node:crypto";
import { fileURLToPath } from "node:url";
import { createClient } from "@supabase/supabase-js";
import {
  defaultCommandRunner,
  redactAtlasStagingDiagnostic,
  validateAtlasStagingProtectedValues,
  verifyAtlasApiExposure,
} from "./atlas-staging-contract.mjs";

function cliPath() {
  return process.platform === "win32"
    ? "node_modules/.bin/supabase.CMD"
    : "node_modules/.bin/supabase";
}

function runSafe(runCommand, command, args, options, protectedValues) {
  const result = runCommand(command, args, options);
  if (result.status !== 0) {
    const diagnostic = redactAtlasStagingDiagnostic(
      `${result.stdout}\n${result.stderr}`,
      protectedValues,
    );
    throw new Error(
      diagnostic.trim()
        ? `Atlas staging verification command failed safely: ${diagnostic.trim()}`
        : "Atlas staging verification command failed safely.",
    );
  }
  return result.stdout;
}

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
    throw new Error("Hosted migration evidence is not valid CLI JSON output.");
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

export function catalogVerificationSql(authority) {
  const schemas = sqlArray(authority.schemas);
  const roles = sqlArray(authority.databaseRoles);
  const signatures = sqlArray(authority.apiSignatures);
  const owners = sqlArray(authority.apiOwners);
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
  if actual is distinct from ${roles} or (select count(*) from atlas_core.roles) <> 0 then
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

function extractCustomerId(output) {
  const match = /ATLAS_CUSTOMER_ID=([0-9a-f-]{36})/i.exec(output);
  if (!match)
    throw new Error(
      "No approved staging customer is available for the read check.",
    );
  return match[1];
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
  const target = validateAtlasStagingProtectedValues(environment);
  return {
    target,
    commands: [
      ["supabase", "link", "--project-ref", "<protected-staging-ref>"],
      ["supabase", "db", "query", "<migration-json-read>", "--linked"],
      ["supabase", "db", "query", "<identity-catalog-read>", "--linked"],
      ["Data API", "anonymous atlas_api authorization probe"],
    ],
    networkWrites: false,
  };
}

export async function verifyAtlasStaging({
  environment = process.env,
  cwd = process.cwd(),
  runCommand = defaultCommandRunner,
  fetchImpl = fetch,
  createClientFactory = createClient,
  dryRun = false,
  platformOnly = false,
} = {}) {
  const plan = planAtlasStagingVerification(environment);
  if (dryRun) return plan;

  const { target } = plan;
  const protectedValues = [
    target.accessToken,
    target.databasePassword,
    target.testPassword,
    target.publishableKey,
  ];
  const commandEnvironment = {
    ...environment,
    SUPABASE_ACCESS_TOKEN: target.accessToken,
    SUPABASE_TELEMETRY_DISABLED: "1",
  };
  const options = { cwd, env: commandEnvironment };

  runSafe(
    runCommand,
    cliPath(),
    [
      "link",
      "--project-ref",
      target.projectRef,
      "--password",
      target.databasePassword,
    ],
    options,
    protectedValues,
  );

  const migrations = runSafe(
    runCommand,
    cliPath(),
    [
      "db",
      "query",
      migrationHistorySql(),
      "--linked",
      "--output",
      "json",
      "--agent",
      "no",
    ],
    options,
    protectedValues,
  );
  assertExactMigrationHistory(
    repositoryMigrationVersions(cwd),
    parseMigrationHistoryEvidence(migrations),
  );
  runSafe(
    runCommand,
    cliPath(),
    [
      "db",
      "query",
      catalogVerificationSql(readCatalogAuthority(cwd)),
      "--linked",
    ],
    options,
    protectedValues,
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
    runSafe(
      runCommand,
      cliPath(),
      ["db", "query", actorVerificationSql(authSubject), "--linked"],
      options,
      protectedValues,
    );
    const customerOutput = runSafe(
      runCommand,
      cliPath(),
      [
        "db",
        "query",
        "select 'ATLAS_CUSTOMER_ID=' || customer_id::text from atlas_admin.customers where customer_status = 'ACTIVE' order by customer_id limit 1;",
        "--linked",
      ],
      options,
      protectedValues,
    );
    const customerId = extractCustomerId(customerOutput);
    const serviceDate = new Date().toISOString().slice(0, 10);
    const { data: readResult, error: readError } = await client
      .schema("atlas_api")
      .rpc("get_operator_blockers", {
        request: {
          contract_version: "PA-05C.v1",
          correlation_id: randomUUID(),
          requested_by_auth_subject: authSubject,
          payload: { service_date: serviceDate, customer_id: customerId },
        },
      })
      .retry(false);
    if (readError || !readResult || typeof readResult !== "object") {
      throw new Error("The approved authenticated Atlas read failed safely.");
    }
  } catch (error) {
    verificationFailure = error;
  } finally {
    const { error: signOutError } = await client.auth.signOut({
      scope: "local",
    });
    const { data: afterSignOut, error: sessionError } =
      await client.auth.getSession();
    if (signOutError || sessionError || afterSignOut.session) {
      throw new Error("The staging session was not cleared safely.");
    }
  }
  if (verificationFailure) throw verificationFailure;
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
