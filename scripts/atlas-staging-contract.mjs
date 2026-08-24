import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";

export const ATLAS_STAGING_GITHUB_ENVIRONMENT = "atlas-staging";
export const APPROVED_ATLAS_STAGING_PROJECT_REF = "rnzxmxiiqgtdevzregff";
export const LIVE_OPS_PROJECT_DENYLIST = Object.freeze([
  "qnthofvccilhnefdcxnz",
]);
export const ATLAS_STAGING_VARIABLE_NAMES = Object.freeze([
  "ATLAS_STAGING_PROJECT_REF",
  "VITE_ATLAS_ENVIRONMENT",
  "VITE_SUPABASE_URL",
  "VITE_SUPABASE_PUBLISHABLE_KEY",
  "ATLAS_STAGING_TEST_EMAIL",
]);
export const ATLAS_STAGING_SECRET_NAMES = Object.freeze([
  "ATLAS_STAGING_SUPABASE_ACCESS_TOKEN",
  "ATLAS_STAGING_DB_PASSWORD",
  "ATLAS_STAGING_TEST_PASSWORD",
]);
export const ATLAS_STAGING_IDENTITY_SECRET_NAMES = Object.freeze([
  "ATLAS_STAGING_SUPABASE_SECRET_KEY",
]);

const FULL_SHA = /^[0-9a-f]{40}$/;
const PROJECT_REF = /^[a-z0-9]{20}$/;
export const ATLAS_STAGING_CERTIFICATION_MODES = Object.freeze([
  "github",
  "local",
]);
const LOCAL_CERTIFICATION_ENVIRONMENT_NAMES = new Set([
  "PATH",
  "HOME",
  "USERPROFILE",
  "SYSTEMROOT",
  "WINDIR",
  "COMSPEC",
  "PATHEXT",
  "TEMP",
  "TMP",
  "TMPDIR",
  "APPDATA",
  "LOCALAPPDATA",
  "LANG",
  "TERM",
  "PNPM_HOME",
  "DOCKER_HOST",
  "DOCKER_CONTEXT",
  "DOCKER_TLS_VERIFY",
  "DOCKER_CERT_PATH",
]);

export function redactAtlasStagingDiagnostic(value, protectedValues = []) {
  let safe = String(value ?? "");
  for (const secret of protectedValues.filter(Boolean)) {
    safe = safe.split(String(secret)).join("[REDACTED]");
  }
  return safe
    .replace(/postgres(?:ql)?:\/\/[^\s'\"]+/gi, "[REDACTED_DATABASE_URL]")
    .replace(/sb_(?:secret|publishable)_[A-Za-z0-9._-]+/g, "[REDACTED_KEY]")
    .replace(/eyJ[A-Za-z0-9._-]+/g, "[REDACTED_JWT]")
    .replace(/(Bearer\s+)[A-Za-z0-9._-]+/gi, "$1[REDACTED]")
    .replace(/\b(password|passwd)\s*([=:]\s*)[^\s'\"]+/gi, "$1$2[REDACTED]");
}

export function requireExactCommitSha(value) {
  const sha = String(value ?? "")
    .trim()
    .toLowerCase();
  if (!FULL_SHA.test(sha)) {
    throw new Error("A valid full commit SHA is required.");
  }
  return sha;
}

export function requireAtlasStagingCertificationMode(value) {
  const mode = String(value ?? "")
    .trim()
    .toLowerCase();
  if (!ATLAS_STAGING_CERTIFICATION_MODES.includes(mode)) {
    throw new Error(
      "Atlas staging certification must be explicitly selected as github or local.",
    );
  }
  return mode;
}

export function localCertificationEnvironment(environment) {
  const safeEnvironment = Object.fromEntries(
    Object.entries(environment).filter(([name]) => {
      const normalizedName = name.toUpperCase();
      return (
        LOCAL_CERTIFICATION_ENVIRONMENT_NAMES.has(normalizedName) ||
        normalizedName.startsWith("LC_")
      );
    }),
  );
  return { ...safeEnvironment, SUPABASE_TELEMETRY_DISABLED: "1" };
}

export function projectRefFromStagingUrl(value) {
  let url;
  try {
    url = new URL(String(value ?? ""));
  } catch {
    return null;
  }
  if (url.protocol !== "https:" || url.username || url.password) return null;
  const match = /^([a-z0-9]{20})\.supabase\.co$/i.exec(url.hostname);
  return match?.[1].toLowerCase() ?? null;
}

export function validateAtlasStagingTarget(projectRefValue, urlValue) {
  const projectRef = String(projectRefValue ?? "")
    .trim()
    .toLowerCase();
  const urlProjectRef = projectRefFromStagingUrl(urlValue);
  if (!PROJECT_REF.test(projectRef) || !urlProjectRef) {
    throw new Error("Atlas staging target identity is invalid.");
  }
  if (
    LIVE_OPS_PROJECT_DENYLIST.includes(projectRef) ||
    LIVE_OPS_PROJECT_DENYLIST.includes(urlProjectRef)
  ) {
    throw new Error("The protected target is forbidden for Atlas staging.");
  }
  if (projectRef !== urlProjectRef) {
    throw new Error(
      "The protected project reference and staging URL do not match.",
    );
  }
  return {
    projectRef,
    supabaseUrl: `https://${projectRef}.supabase.co`,
  };
}

export function validateApprovedAtlasStagingTarget(projectRefValue, urlValue) {
  const target = validateAtlasStagingTarget(projectRefValue, urlValue);
  if (target.projectRef !== APPROVED_ATLAS_STAGING_PROJECT_REF) {
    throw new Error(
      "The protected target is not the approved Atlas Staging project.",
    );
  }
  return target;
}

function browserKeyIsSafe(value) {
  if (!value || /\s/.test(value) || value.startsWith("sb_secret_"))
    return false;
  if (value.startsWith("sb_publishable_") && value.length > 20) return true;
  const parts = value.split(".");
  if (parts.length !== 3) return false;
  try {
    const payload = JSON.parse(
      Buffer.from(parts[1], "base64url").toString("utf8"),
    );
    return payload?.role === "anon";
  } catch {
    return false;
  }
}

function serverSecretKeyIsSafe(value) {
  if (!value || /\s/.test(value)) return false;
  if (value.startsWith("sb_secret_") && value.length > 20) return true;
  const parts = value.split(".");
  if (parts.length !== 3) return false;
  try {
    const payload = JSON.parse(
      Buffer.from(parts[1], "base64url").toString("utf8"),
    );
    return payload?.role === "service_role";
  } catch {
    return false;
  }
}

export function validateAtlasStagingProtectedValues(
  environment,
  { requireDatabasePassword = true } = {},
) {
  const requiredSecretNames = requireDatabasePassword
    ? ATLAS_STAGING_SECRET_NAMES
    : ATLAS_STAGING_SECRET_NAMES.filter(
        (name) => name !== "ATLAS_STAGING_DB_PASSWORD",
      );
  const missing = [
    ...ATLAS_STAGING_VARIABLE_NAMES,
    ...requiredSecretNames,
  ].filter((name) => !String(environment[name] ?? "").trim());
  if (missing.length) {
    throw new Error(
      `Required protected values are missing: ${missing.join(", ")}.`,
    );
  }
  if (environment.VITE_ATLAS_ENVIRONMENT !== "staging") {
    throw new Error("Protected deployment requires explicit staging mode.");
  }
  if (!browserKeyIsSafe(environment.VITE_SUPABASE_PUBLISHABLE_KEY)) {
    throw new Error(
      "The protected browser key is not publishable or anonymous.",
    );
  }
  const target = validateAtlasStagingTarget(
    environment.ATLAS_STAGING_PROJECT_REF,
    environment.VITE_SUPABASE_URL,
  );
  const protectedValues = {
    ...target,
    publishableKey: environment.VITE_SUPABASE_PUBLISHABLE_KEY,
    testEmail: environment.ATLAS_STAGING_TEST_EMAIL,
    accessToken: environment.ATLAS_STAGING_SUPABASE_ACCESS_TOKEN,
    testPassword: environment.ATLAS_STAGING_TEST_PASSWORD,
  };
  if (requireDatabasePassword) {
    protectedValues.databasePassword = environment.ATLAS_STAGING_DB_PASSWORD;
  }
  return protectedValues;
}

export function validateAtlasStagingPackageProtectedValues(
  environment,
  { identity = false } = {},
) {
  const target = validateAtlasStagingProtectedValues(environment, {
    requireDatabasePassword: false,
  });
  validateApprovedAtlasStagingTarget(
    environment.ATLAS_STAGING_PROJECT_REF,
    environment.VITE_SUPABASE_URL,
  );
  if (!identity) return target;

  const secretKey = String(
    environment.ATLAS_STAGING_SUPABASE_SECRET_KEY ?? "",
  ).trim();
  if (!serverSecretKeyIsSafe(secretKey)) {
    throw new Error(
      "The protected server-only Atlas Staging secret key is missing or unsafe.",
    );
  }
  return { ...target, secretKey };
}

export async function executeAtlasStagingManagementSql(
  target,
  statement,
  fetchImpl = fetch,
) {
  validateApprovedAtlasStagingTarget(target?.projectRef, target?.supabaseUrl);
  const accessToken = String(target?.accessToken ?? "").trim();
  const query = String(statement ?? "");
  if (!accessToken || !query.trim()) {
    throw new Error(
      "The protected Atlas Staging database query failed safely.",
    );
  }

  let response;
  try {
    response = await fetchImpl(
      `https://api.supabase.com/v1/projects/${target.projectRef}/database/query`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
          Accept: "application/json",
        },
        body: JSON.stringify({ query }),
      },
    );
  } catch {
    throw new Error(
      "The protected Atlas Staging database query failed safely.",
    );
  }
  if (response.status !== 201) {
    throw new Error(
      "The protected Atlas Staging database query failed safely.",
    );
  }
  try {
    return await response.text();
  } catch {
    throw new Error(
      "The protected Atlas Staging database query failed safely.",
    );
  }
}

async function readPostgrestConfiguration(target, fetchImpl) {
  const response = await fetchImpl(
    `https://api.supabase.com/v1/projects/${target.projectRef}/postgrest`,
    {
      headers: {
        Authorization: `Bearer ${target.accessToken}`,
        Accept: "application/json",
      },
    },
  );
  if (!response.ok) {
    throw new Error("The protected Data API configuration is unavailable.");
  }
  const configuration = await response.json();
  if (typeof configuration?.db_schema !== "string") {
    throw new Error("The protected Data API configuration is malformed.");
  }
  return configuration;
}

export async function verifyAtlasApiExposure(target, fetchImpl = fetch) {
  const configuration = await readPostgrestConfiguration(target, fetchImpl);
  const schemas = configuration.db_schema
    .split(",")
    .map((schema) => schema.trim())
    .filter(Boolean);
  if (!schemas.includes("atlas_api")) {
    throw new Error("The atlas_api schema is not exposed by the Data API.");
  }
  return schemas;
}

export async function ensureAtlasApiExposure(target, fetchImpl = fetch) {
  const configuration = await readPostgrestConfiguration(target, fetchImpl);
  const schemas = configuration.db_schema
    .split(",")
    .map((schema) => schema.trim())
    .filter(Boolean);
  if (schemas.includes("atlas_api")) return schemas;

  const updatedSchemas = [...schemas, "atlas_api"];
  const response = await fetchImpl(
    `https://api.supabase.com/v1/projects/${target.projectRef}/postgrest`,
    {
      method: "PATCH",
      headers: {
        Authorization: `Bearer ${target.accessToken}`,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify({ db_schema: updatedSchemas.join(",") }),
    },
  );
  if (!response.ok) {
    throw new Error("The protected atlas_api exposure update failed safely.");
  }
  await verifyAtlasApiExposure(target, fetchImpl);
  return updatedSchemas;
}

export function defaultCommandRunner(command, args, options = {}) {
  const result = spawnSync(command, args, {
    cwd: options.cwd,
    env: options.env ?? process.env,
    encoding: "utf8",
    shell: options.shell ?? process.platform === "win32",
    timeout: options.timeout,
  });
  return {
    status: result.status ?? 1,
    stdout: result.stdout ?? "",
    stderr: result.stderr ?? "",
  };
}

export function nativeSupabaseCliInvocation(command, args) {
  return {
    command,
    args: [...args],
    shell: false,
  };
}

export function repositorySupabaseCliInvocation(
  args,
  {
    cwd = process.cwd(),
    platform = process.platform,
    architecture = process.arch,
  } = {},
) {
  const cliArgs = [...args];
  if (platform !== "win32") {
    return {
      command: "pnpm",
      args: ["exec", "supabase", ...cliArgs],
      shell: false,
    };
  }

  const platformPackage = {
    arm64: "@supabase/cli-windows-arm64",
    x64: "@supabase/cli-windows-x64",
  }[architecture];
  if (!platformPackage) {
    throw new Error(
      "The repository-pinned Supabase CLI does not support this Windows architecture.",
    );
  }

  const repositoryRequire = createRequire(join(cwd, "package.json"));
  const packageAuthority = JSON.parse(
    readFileSync(join(cwd, "package.json"), "utf8"),
  );
  const expectedVersion = packageAuthority.devDependencies?.supabase;
  const supabasePackagePath = repositoryRequire.resolve(
    "supabase/package.json",
  );
  const supabasePackage = JSON.parse(readFileSync(supabasePackagePath, "utf8"));
  const platformPackagePath = createRequire(supabasePackagePath).resolve(
    `${platformPackage}/package.json`,
  );
  const platformPackageAuthority = JSON.parse(
    readFileSync(platformPackagePath, "utf8"),
  );
  if (
    !expectedVersion ||
    supabasePackage.version !== expectedVersion ||
    supabasePackage.optionalDependencies?.[platformPackage] !==
      expectedVersion ||
    platformPackageAuthority.version !== expectedVersion
  ) {
    throw new Error(
      "The repository-pinned Supabase CLI package authority is inconsistent.",
    );
  }

  return nativeSupabaseCliInvocation(
    join(dirname(platformPackagePath), "bin", "supabase.exe"),
    cliArgs,
  );
}

function requireCommandSuccess(result, message) {
  if (result.status !== 0) throw new Error(message);
  return result.stdout.trim();
}

async function successfulWorkflowRun({
  repository,
  workflow,
  commitSha,
  token,
  requiredJob,
  fetchImpl,
}) {
  const headers = {
    Accept: "application/vnd.github+json",
    Authorization: `Bearer ${token}`,
    "X-GitHub-Api-Version": "2022-11-28",
  };
  const runsResponse = await fetchImpl(
    `https://api.github.com/repos/${repository}/actions/workflows/${workflow}/runs?head_sha=${commitSha}&status=success&per_page=100`,
    { headers },
  );
  if (!runsResponse.ok)
    throw new Error("Exact-head workflow evidence is unavailable.");
  const runs = (await runsResponse.json()).workflow_runs ?? [];
  for (const run of runs) {
    if (run.head_sha !== commitSha || run.conclusion !== "success") continue;
    const jobsResponse = await fetchImpl(
      `https://api.github.com/repos/${repository}/actions/runs/${run.id}/jobs?filter=latest&per_page=100`,
      { headers },
    );
    if (!jobsResponse.ok)
      throw new Error("Exact-head job evidence is unavailable.");
    const jobs = (await jobsResponse.json()).jobs ?? [];
    if (
      jobs.some(
        (job) => job.name === requiredJob && job.conclusion === "success",
      )
    ) {
      return;
    }
  }
  throw new Error(
    `Required exact-head certification is missing: ${requiredJob}.`,
  );
}

function verifyExactHeadState({ commitSha, cwd, runCommand }) {
  requireCommandSuccess(
    runCommand("git", ["cat-file", "-e", `${commitSha}^{commit}`], {
      cwd,
      shell: false,
    }),
    "The requested commit does not exist in this checkout.",
  );
  const head = requireCommandSuccess(
    runCommand("git", ["rev-parse", "HEAD"], { cwd, shell: false }),
    "The checked-out commit cannot be verified.",
  );
  if (head !== commitSha)
    throw new Error("Checkout is not at the requested exact commit.");
  requireCommandSuccess(
    runCommand(
      "git",
      ["merge-base", "--is-ancestor", commitSha, "origin/main"],
      {
        cwd,
        shell: false,
      },
    ),
    "The requested commit is not contained in main.",
  );
  const status = requireCommandSuccess(
    runCommand("git", ["status", "--porcelain"], { cwd, shell: false }),
    "Worktree cleanliness cannot be verified.",
  );
  if (status) throw new Error("The deployment worktree is not clean.");
}

function refreshOriginMain({ cwd, runCommand }) {
  requireCommandSuccess(
    runCommand(
      "git",
      ["fetch", "--no-tags", "origin", "main:refs/remotes/origin/main"],
      { cwd, shell: false },
    ),
    "The current origin/main cannot be fetched for local certification.",
  );
}

export async function verifyExactHeadCertification({
  commitSha: commitShaValue,
  certificationMode: certificationModeValue,
  environment = process.env,
  cwd = process.cwd(),
  runCommand = defaultCommandRunner,
  fetchImpl = fetch,
  runFrontendCertification,
  runSupabaseCertification,
}) {
  const commitSha = requireExactCommitSha(commitShaValue);
  const certificationMode = requireAtlasStagingCertificationMode(
    certificationModeValue,
  );
  if (certificationMode === "local") {
    refreshOriginMain({ cwd, runCommand });
  }
  verifyExactHeadState({ commitSha, cwd, runCommand });

  if (certificationMode === "github") {
    const repository = String(environment.GITHUB_REPOSITORY ?? "");
    const token = String(environment.GITHUB_TOKEN ?? "");
    if (!repository || !token) {
      throw new Error(
        "GitHub exact-head verification requires the built-in workflow context.",
      );
    }
    await successfulWorkflowRun({
      repository,
      workflow: "frontend-ci.yml",
      commitSha,
      token,
      requiredJob: "Format, typecheck, test, build",
      fetchImpl,
    });
    await successfulWorkflowRun({
      repository,
      workflow: "supabase-integration.yml",
      commitSha,
      token,
      requiredJob: "Supabase Full Integration",
      fetchImpl,
    });
  } else {
    if (
      typeof runFrontendCertification !== "function" ||
      typeof runSupabaseCertification !== "function"
    ) {
      throw new Error("Local exact-head certification is unavailable.");
    }
    const certificationEnvironment = localCertificationEnvironment(environment);
    await runFrontendCertification({
      cwd,
      environment: certificationEnvironment,
      runCommand,
    });
    await runSupabaseCertification({
      cwd,
      environment: certificationEnvironment,
      runCommand,
    });
    refreshOriginMain({ cwd, runCommand });
  }

  verifyExactHeadState({ commitSha, cwd, runCommand });
  return commitSha;
}
