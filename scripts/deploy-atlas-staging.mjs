import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import {
  defaultCommandRunner,
  redactAtlasStagingDiagnostic,
  requireExactCommitSha,
  validateAtlasStagingProtectedValues,
  verifyExactHeadCertification,
} from "./atlas-staging-contract.mjs";
import { verifyAtlasStaging } from "./verify-atlas-staging.mjs";

function cliPath() {
  return process.platform === "win32"
    ? "node_modules/.bin/supabase.CMD"
    : "node_modules/.bin/supabase";
}

function commandSuccess(
  runCommand,
  command,
  args,
  options,
  protectedValues = [],
) {
  const result = runCommand(command, args, options);
  if (result.status !== 0) {
    throw new Error(
      redactAtlasStagingDiagnostic(
        `${result.stdout}\n${result.stderr}`,
        protectedValues,
      ).trim() || "Atlas staging deployment command failed safely.",
    );
  }
  return result.stdout;
}

export function inspectPinnedSupabaseCli({
  cwd = process.cwd(),
  environment = process.env,
  runCommand = defaultCommandRunner,
} = {}) {
  const packageJson = JSON.parse(readFileSync(`${cwd}/package.json`, "utf8"));
  const expectedVersion = packageJson.devDependencies?.supabase;
  const options = {
    cwd,
    env: { ...environment, SUPABASE_TELEMETRY_DISABLED: "1" },
  };
  const version = commandSuccess(
    runCommand,
    cliPath(),
    ["--version"],
    options,
  ).trim();
  if (!expectedVersion || version !== expectedVersion) {
    throw new Error(
      "The repository-pinned Supabase CLI version does not match package authority.",
    );
  }
  const requiredHelp = [
    {
      args: ["link", "--help"],
      flags: ["--project-ref", "--password"],
    },
    { args: ["db", "push", "--help"], flags: ["--db-url", "--dry-run"] },
    { args: ["migration", "list", "--help"], flags: ["--db-url"] },
    { args: ["db", "query", "--help"], flags: ["--db-url"] },
  ];
  for (const item of requiredHelp) {
    const output = commandSuccess(runCommand, cliPath(), item.args, options);
    if (item.flags.some((flag) => !output.includes(flag))) {
      throw new Error(
        "The pinned Supabase CLI does not expose a required inspected flag.",
      );
    }
  }
  return version;
}

export function planAtlasStagingDeployment(environment = process.env) {
  const target = validateAtlasStagingProtectedValues(environment);
  return {
    target,
    command: [
      "supabase",
      "link <protected-staging-ref>",
      "then db push --linked --yes",
    ],
    repositoryMigrationsOnly: true,
    installsDataPackages: false,
    deploysEdgeFunctions: false,
  };
}

export async function deployAtlasStaging({
  commitSha: commitShaValue,
  environment = process.env,
  cwd = process.cwd(),
  runCommand = defaultCommandRunner,
  fetchImpl = fetch,
  dryRun = false,
  preflightOnly = false,
  verifyHosted = verifyAtlasStaging,
} = {}) {
  const commitSha = requireExactCommitSha(commitShaValue);
  const plan = planAtlasStagingDeployment(environment);
  if (dryRun) return { status: "dry-run", plan };

  inspectPinnedSupabaseCli({ cwd, environment, runCommand });
  await verifyExactHeadCertification({
    commitSha,
    environment,
    cwd,
    runCommand,
    fetchImpl,
  });
  if (preflightOnly) return { status: "preflight", plan };

  const protectedValues = [
    plan.target.accessToken,
    plan.target.databasePassword,
    plan.target.testPassword,
    plan.target.publishableKey,
  ];
  const commandEnvironment = {
    ...environment,
    SUPABASE_ACCESS_TOKEN: plan.target.accessToken,
    SUPABASE_TELEMETRY_DISABLED: "1",
  };
  commandSuccess(
    runCommand,
    cliPath(),
    [
      "link",
      "--project-ref",
      plan.target.projectRef,
      "--password",
      plan.target.databasePassword,
    ],
    {
      cwd,
      env: commandEnvironment,
    },
    protectedValues,
  );
  commandSuccess(
    runCommand,
    cliPath(),
    [
      "db",
      "push",
      "--linked",
      "--password",
      plan.target.databasePassword,
      "--yes",
    ],
    { cwd, env: commandEnvironment },
    protectedValues,
  );
  await verifyHosted({
    environment,
    cwd,
    runCommand,
    fetchImpl,
    platformOnly: true,
  });
  return { status: "deployed", plan };
}

function argument(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : undefined;
}

async function main() {
  const result = await deployAtlasStaging({
    commitSha: argument("--commit-sha"),
    dryRun: process.argv.includes("--dry-run"),
    preflightOnly: process.argv.includes("--preflight"),
  });
  const messages = {
    "dry-run":
      "Atlas staging deployment dry-run passed without network or process execution.",
    preflight:
      "Atlas staging deployment preflight and exact-head certification passed.",
    deployed:
      "Atlas staging migrations and platform-only read verification passed.",
  };
  console.log(messages[result.status]);
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  main().catch((error) => {
    console.error(
      redactAtlasStagingDiagnostic(
        error instanceof Error
          ? error.message
          : "Atlas staging deployment failed safely.",
      ),
    );
    process.exitCode = 1;
  });
}
