import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { validateApprovedAtlasStagingTarget } from "./atlas-staging-contract.mjs";

const STAGING = "rnzxmxiiqgtdevzregff";
const CLIENT_PHASES = new Set([
  "CATCHUP_CLIENT_SCRIPT_BEGIN",
  "CATCHUP_CLIENT_SETTINGS_DONE",
  "CATCHUP_CLIENT_HELPERS_DONE",
  "CATCHUP_CLIENT_QUERY_BEGIN",
  "CATCHUP_CLIENT_QUERY_DONE",
]);
const SERVER_PHASES = new Map([
  ["PZ001", "CATCHUP_SERVER_ENTRY"],
  ["PZ002", "CATCHUP_SERVER_SOURCE_CHECKED"],
  ["PZ003", "CATCHUP_SERVER_RECIPE_PLAN_DONE"],
  ["PZ004", "CATCHUP_SERVER_PROTECTED_DONE"],
  ["PZ005", "CATCHUP_SERVER_MAPPING_HASH_DONE"],
  ["PZ006", "CATCHUP_SERVER_PLAN_HASH_DONE"],
  ["PZ007", "CATCHUP_SERVER_SCOPE_DONE"],
  ["PZ008", "CATCHUP_SERVER_DEPENDENCIES_DONE"],
  ["PZ009", "CATCHUP_SERVER_EMPTY_ROOTS_DONE"],
  ["PZ010", "CATCHUP_SERVER_RECIPE_INPUT_READY"],
]);
function emitSafePostgresPhases(stderr, onPhase) {
  if (typeof stderr !== "string") return;
  const emitted = new Set();
  for (const line of stderr.split(/\r?\n/)) {
    const notice = line.match(
      /^(?:psql:<stdin>:\d+:[ \t]*)?NOTICE:[ \t]+(PZ00[1-9]|PZ010)[ \t]*$/,
    );
    const phase = CLIENT_PHASES.has(line)
      ? line
      : SERVER_PHASES.get(notice?.[1]);
    // No prefixes, message text or unknown codes escape. Repetition is bounded
    // to the fixed marker count while retaining first-observed wire order.
    if (phase && !emitted.has(phase)) {
      emitted.add(phase);
      onPhase(phase);
    }
  }
}
function safePostgresFailureCode(stderr) {
  const diagnostic = typeof stderr === "string" ? stderr : "";
  // psql's SQLSTATE verbosity omits server messages. Accept only a bounded
  // uppercase state at the start of a server diagnostic, never arbitrary text.
  const state = diagnostic.match(
    /^(?:psql:<stdin>:\d+:[ \t]*)?(?:ERROR|FATAL):[ \t]+([0-9A-Z]{5})(?=[: \t\r]|$)/m,
  )?.[1];
  if (state) return `STAGING_POSTGRES_SQLSTATE_${state}`;
  // libpq connection failures may have no SQLSTATE. Return fixed categories
  // only; addresses, server prose, SQL and credentials never leave this helper.
  const connectionLines = diagnostic
    .split(/\r?\n/)
    .filter((line) =>
      /^(?:psql: error: |FATAL:[ \t]+|server closed the connection unexpectedly)/.test(
        line,
      ),
    );
  if (connectionLines.some((line) => line.includes("too many clients already")))
    return "STAGING_POSTGRES_TOO_MANY_CLIENTS";
  if (connectionLines.some((line) => line.includes("timeout expired")))
    return "STAGING_POSTGRES_CONNECTION_TIMED_OUT";
  if (
    connectionLines.some((line) =>
      line.includes("server closed the connection unexpectedly"),
    )
  )
    return "STAGING_POSTGRES_CONNECTION_CLOSED";
  return "STAGING_POSTGRES_EXECUTION_FAILED";
}
export function validatedStagingPoolerUrl(value, projectRef) {
  if (projectRef !== STAGING) throw new Error("EXACT_STAGING_TARGET_REQUIRED");
  let url;
  try {
    url = new URL(String(value).trim());
  } catch {
    throw new Error("STAGING_POOLER_URL_INVALID");
  }
  if (
    !["postgres:", "postgresql:"].includes(url.protocol) ||
    decodeURIComponent(url.username) !== `postgres.${STAGING}` ||
    !/^[a-z0-9-]+\.pooler\.supabase\.com$/.test(url.hostname) ||
    url.port !== "5432" ||
    url.pathname !== "/postgres" ||
    url.search ||
    url.hash
  )
    throw new Error("STAGING_SESSION_POOLER_REQUIRED");
  url.password = "";
  return url.toString();
}
export async function executeAtlasStagingPostgres(
  target,
  statement,
  {
    environment = process.env,
    cwd = process.cwd(),
    run = spawnSync,
    timeoutMs = 20 * 60 * 1000,
    onPhase = () => {},
    readLinkedFile = (path) => readFileSync(path, "utf8"),
  } = {},
) {
  validateApprovedAtlasStagingTarget(target?.projectRef, target?.supabaseUrl);
  const password = environment.ATLAS_STAGING_DB_PASSWORD;
  const certificate = environment.ATLAS_STAGING_CA_BUNDLE;
  if (!password || !certificate)
    throw new Error("STAGING_POSTGRES_CREDENTIAL_REQUIRED");
  let linkedRef, linkedUrl;
  try {
    linkedRef = String(
      readLinkedFile(join(cwd, "supabase", ".temp", "project-ref")),
    ).trim();
    linkedUrl = String(
      readLinkedFile(join(cwd, "supabase", ".temp", "pooler-url")),
    ).trim();
  } catch {
    throw new Error("STAGING_POSTGRES_LINK_MISSING");
  }
  if (linkedRef !== STAGING) throw new Error("STAGING_POSTGRES_LINK_MISMATCH");
  const url = validatedStagingPoolerUrl(linkedUrl, target.projectRef);
  if (typeof statement !== "string" || !statement.trim())
    throw new Error("STAGING_POSTGRES_SQL_REQUIRED");
  // PostgreSQL wire protocol avoids the Management API request-body limit.
  // SQL and password never enter process arguments, logs, or a source artifact.
  const childEnv = {
    PATH: environment.PATH ?? process.env.PATH,
    HOME: environment.HOME ?? process.env.HOME,
    SystemRoot: environment.SystemRoot ?? process.env.SystemRoot,
    PGPASSWORD: password,
    PGSSLMODE: "verify-full",
    PGSSLROOTCERT: certificate,
    PGCONNECT_TIMEOUT: "20",
    PGAPPNAME: "atlas-staging-master-load",
    PGCLIENTENCODING: "UTF8",
  };
  if (
    !Number.isInteger(timeoutMs) ||
    timeoutMs < 20000 ||
    timeoutMs > 20 * 60 * 1000
  )
    throw new Error("STAGING_POSTGRES_TIMEOUT_INVALID");
  let result;
  try {
    result = run(
      "psql",
      [
        "--no-psqlrc",
        "--quiet",
        "--tuples-only",
        "--no-align",
        "--no-password",
        "--set",
        "ON_ERROR_STOP=1",
        "--set",
        "VERBOSITY=sqlstate",
        "--dbname",
        url,
      ],
      {
        cwd,
        env: childEnv,
        input: statement,
        encoding: "utf8",
        shell: false,
        timeout: timeoutMs,
        maxBuffer: 32 * 1024 * 1024,
      },
    );
  } catch {
    throw new Error("STAGING_POSTGRES_EXECUTION_FAILED");
  }
  emitSafePostgresPhases(result.stderr, onPhase);
  if (result.error?.code === "ETIMEDOUT")
    throw new Error("STAGING_POSTGRES_EXECUTION_TIMED_OUT");
  if (result.status !== 0 || result.error)
    throw new Error(safePostgresFailureCode(result.stderr));
  let value;
  try {
    value = JSON.parse(String(result.stdout ?? "").trim());
  } catch {
    throw new Error("STAGING_POSTGRES_RESPONSE_INVALID");
  }
  if (!value || typeof value !== "object" || Array.isArray(value))
    throw new Error("STAGING_POSTGRES_RESPONSE_INVALID");
  return JSON.stringify([{ result: value }]);
}
