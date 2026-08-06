import { readdirSync, readFileSync } from "node:fs";
import { randomUUID } from "node:crypto";
import { fileURLToPath } from "node:url";
import { createClient } from "@supabase/supabase-js";
import {
  ATLAS_CATALOG_FINGERPRINT,
  ATLAS_RUNTIME_ROLES,
  defaultCommandRunner,
  redactAtlasStagingDiagnostic,
  validateAtlasStagingProtectedValues,
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

function repositoryMigrationVersions(cwd) {
  return readdirSync(`${cwd}/supabase/migrations`)
    .filter((name) => /^\d{14}_.+\.sql$/.test(name))
    .map((name) => name.slice(0, 14))
    .sort();
}

function assertMigrationHistory(output, expectedVersions) {
  const applied = new Set();
  for (const line of output.split(/\r?\n/)) {
    const match = /^\s*(\d{14})\s*\|\s*(\d{14})/.exec(line);
    if (match && match[1] === match[2]) applied.add(match[1]);
  }
  if (
    applied.size !== expectedVersions.length ||
    expectedVersions.some((version) => !applied.has(version))
  ) {
    throw new Error(
      "Hosted migration history does not match repository authority.",
    );
  }
}

function catalogVerificationSql() {
  const roles = ATLAS_RUNTIME_ROLES.map((role) => `'${role}'`).join(", ");
  const expected = ATLAS_CATALOG_FINGERPRINT;
  return `do $$
declare
  private_grants bigint;
begin
  if (select count(*) from pg_namespace where nspname like 'atlas\\_%' escape '\\') <> ${expected.schemas} then
    raise exception 'ATLAS_CATALOG_SCHEMA_MISMATCH';
  end if;
  if (select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname like 'atlas\\_%' escape '\\' and c.relkind = 'r') <> ${expected.tables} then
    raise exception 'ATLAS_CATALOG_TABLE_MISMATCH';
  end if;
  if (select count(*) from pg_policy p join pg_class c on c.oid = p.polrelid join pg_namespace n on n.oid = c.relnamespace where n.nspname like 'atlas\\_%' escape '\\') <> ${expected.policies} then
    raise exception 'ATLAS_CATALOG_POLICY_MISMATCH';
  end if;
  if (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'atlas_api') <> ${expected.apiFunctions} then
    raise exception 'ATLAS_API_FINGERPRINT_MISMATCH';
  end if;
  if (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'atlas_api' and has_function_privilege('authenticated', p.oid, 'EXECUTE')) <> ${expected.authenticatedExecutions} then
    raise exception 'ATLAS_AUTHENTICATED_EXECUTE_MISMATCH';
  end if;
  if (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'atlas_api' and has_function_privilege('anon', p.oid, 'EXECUTE')) <> ${expected.anonymousExecutions} then
    raise exception 'ATLAS_ANON_EXECUTE_MISMATCH';
  end if;
  if not has_schema_privilege('authenticated', 'atlas_api', 'USAGE') or has_schema_privilege('anon', 'atlas_api', 'USAGE') then
    raise exception 'ATLAS_API_SCHEMA_GRANT_MISMATCH';
  end if;
  if (select count(*) from pg_roles where rolname in (${roles})) <> ${ATLAS_RUNTIME_ROLES.length} then
    raise exception 'ATLAS_RUNTIME_ROLE_MISMATCH';
  end if;
  select count(*) into private_grants
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname in ('atlas_core','atlas_admin','atlas_planning','atlas_procurement','atlas_evidence','atlas_dispatch','atlas_audit','atlas_reporting','atlas_legacy')
    and c.relkind in ('r','p','v','m','S')
    and (has_table_privilege('anon', c.oid, 'SELECT,INSERT,UPDATE,DELETE') or has_table_privilege('authenticated', c.oid, 'SELECT,INSERT,UPDATE,DELETE'));
  if private_grants <> 0 then raise exception 'ATLAS_PRIVATE_RELATION_EXPOSURE'; end if;
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

export function planAtlasStagingVerification(environment = process.env) {
  const target = validateAtlasStagingProtectedValues(environment);
  return {
    target,
    commands: [
      ["supabase", "link", "--project-ref", "<protected-staging-ref>"],
      ["supabase", "migration", "list", "--linked"],
      ["supabase", "db", "query", "<catalog-read>", "--linked"],
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
    ["migration", "list", "--linked", "--password", target.databasePassword],
    options,
    protectedValues,
  );
  assertMigrationHistory(migrations, repositoryMigrationVersions(cwd));
  runSafe(
    runCommand,
    cliPath(),
    ["db", "query", catalogVerificationSql(), "--linked"],
    options,
    protectedValues,
  );

  const health = await fetchImpl(`${target.supabaseUrl}/auth/v1/health`, {
    headers: { apikey: target.publishableKey },
  });
  if (!health.ok)
    throw new Error("The Atlas staging project API is not reachable.");
  if (platformOnly) return { status: "verified", phase: "platform" };

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
  if (!anonymousAttempt.error) {
    throw new Error("Unauthenticated Atlas API execution was not denied.");
  }

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
