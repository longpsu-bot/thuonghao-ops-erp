import { fileURLToPath } from "node:url";
import {
  defaultCommandRunner,
  redactAtlasStagingDiagnostic,
  repositorySupabaseCliInvocation,
  throwPreferredFailure,
} from "./atlas-staging-contract.mjs";

const PRE_D047_MIGRATION = "20260923041223";

export const PLANNING_LEGACY_ADOPTION_UPGRADE_COMMANDS = Object.freeze([
  Object.freeze([
    "db",
    "reset",
    "--local",
    "--no-seed",
    "--version",
    PRE_D047_MIGRATION,
  ]),
  Object.freeze([
    "db",
    "query",
    "--local",
    "--file",
    "supabase/local/planning_legacy_adoption_upgrade_fixture.sql",
  ]),
  Object.freeze(["migration", "up", "--local"]),
  Object.freeze([
    "test",
    "db",
    "supabase/tests/planning_legacy_adoption_upgrade.sql",
    "--local",
  ]),
  Object.freeze([
    "db",
    "reset",
    "--local",
    "--no-seed",
    "--version",
    PRE_D047_MIGRATION,
  ]),
  Object.freeze([
    "db",
    "query",
    "--local",
    "--file",
    "supabase/local/planning_legacy_adoption_upgrade_fixture.sql",
  ]),
  Object.freeze([
    "db",
    "query",
    "--local",
    "--file",
    "supabase/local/planning_legacy_adoption_upgrade_duplicate_action.sql",
  ]),
  Object.freeze(["migration", "up", "--local"]),
  Object.freeze([
    "test",
    "db",
    "supabase/tests/planning_legacy_adoption_upgrade_duplicate_action.sql",
    "--local",
  ]),
  Object.freeze([
    "db",
    "reset",
    "--local",
    "--no-seed",
    "--version",
    PRE_D047_MIGRATION,
  ]),
  Object.freeze([
    "db",
    "query",
    "--local",
    "--file",
    "supabase/local/planning_legacy_adoption_upgrade_fixture.sql",
  ]),
  Object.freeze([
    "db",
    "query",
    "--local",
    "--file",
    "supabase/local/planning_legacy_adoption_upgrade_missing_corrected_unit_mapping.sql",
  ]),
  Object.freeze(["migration", "up", "--local"]),
  Object.freeze([
    "test",
    "db",
    "supabase/tests/planning_legacy_adoption_upgrade_missing_corrected_unit_mapping.sql",
    "--local",
  ]),
]);

export const RESTORE_CURRENT_SCHEMA_COMMAND = Object.freeze([
  "db",
  "reset",
  "--local",
  "--no-seed",
]);

function defaultSupabaseRunner(args, { cwd, environment }) {
  const invocation = repositorySupabaseCliInvocation(args, { cwd });
  return defaultCommandRunner(invocation.command, invocation.args, {
    cwd,
    env: environment,
    shell: invocation.shell,
  });
}

function requireSuccess(result, label) {
  if (result.status === 0) return;
  const detail = redactAtlasStagingDiagnostic(
    `${result.stdout ?? ""}\n${result.stderr ?? ""}`,
  ).trim();
  throw new Error(
    detail
      ? `Planning legacy adoption upgrade failed at ${label}.\n${detail}`
      : `Planning legacy adoption upgrade failed at ${label}.`,
  );
}

export function testLocalPlanningLegacyAdoptionUpgrade({
  cwd = process.cwd(),
  environment = process.env,
  runSupabase = defaultSupabaseRunner,
} = {}) {
  const options = {
    cwd,
    environment: { ...environment, SUPABASE_TELEMETRY_DISABLED: "1" },
  };
  let primaryFailure;
  try {
    for (const args of PLANNING_LEGACY_ADOPTION_UPGRADE_COMMANDS) {
      const label = `supabase ${args.join(" ")}`;
      console.log(`Planning legacy adoption upgrade: ${label}`);
      requireSuccess(runSupabase(args, options), label);
    }
  } catch (error) {
    primaryFailure = error;
  }

  let cleanupFailure;
  try {
    console.log("Planning legacy adoption upgrade: restore current schema");
    requireSuccess(
      runSupabase(RESTORE_CURRENT_SCHEMA_COMMAND, options),
      "current schema restoration",
    );
  } catch (error) {
    cleanupFailure = error;
  }

  throwPreferredFailure(primaryFailure, cleanupFailure);
  return { status: "passed" };
}

function main() {
  testLocalPlanningLegacyAdoptionUpgrade();
  console.log("Planning legacy adoption upgrade test passed.");
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  try {
    main();
  } catch (error) {
    console.error(
      redactAtlasStagingDiagnostic(
        error instanceof Error
          ? error.message
          : "Planning legacy adoption upgrade test failed safely.",
      ),
    );
    process.exitCode = 1;
  }
}
