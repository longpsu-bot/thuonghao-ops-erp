import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { validateApprovedAtlasStagingTarget } from "./atlas-staging-contract.mjs";

const STAGING = "rnzxmxiiqgtdevzregff";
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
        "--dbname",
        url,
      ],
      {
        cwd,
        env: childEnv,
        input: statement,
        encoding: "utf8",
        shell: false,
        timeout: 20 * 60 * 1000,
        maxBuffer: 32 * 1024 * 1024,
      },
    );
  } catch {
    throw new Error("STAGING_POSTGRES_EXECUTION_FAILED");
  }
  if (result.status !== 0 || result.error)
    throw new Error("STAGING_POSTGRES_EXECUTION_FAILED");
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
