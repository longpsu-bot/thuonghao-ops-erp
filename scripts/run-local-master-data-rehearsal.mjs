import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { parseLocalSupabaseStatus } from "./local-supabase-status.mjs";
import { checksumOpsV1MasterSnapshot } from "./ops-v1-master-snapshot-contract.mjs";
import {
  formatMasterDataRehearsalReport,
  isReconciledMasterPreview,
} from "./master-data-rehearsal-report.mjs";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const CHECKSUM = /^[0-9a-f]{64}$/;
const PROJECT = "atlas-master-rehearsal-01";
function invokeLocalCli(args, environment = process.env) {
  if (!environment.npm_execpath) throw new Error("USE_PINNED_PNPM_SCRIPT");
  try {
    return execFileSync(
      process.execPath,
      [environment.npm_execpath, "exec", "supabase", ...args],
      {
        env: environment,
        cwd: process.cwd(),
        encoding: "utf8",
        stdio: ["ignore", "pipe", "pipe"],
        maxBuffer: 64 * 1024 * 1024,
      },
    );
  } catch {
    throw new Error("LOCAL_SUPABASE_COMMAND_FAILED");
  }
}
export function validateDisposableRehearsalTarget({
  environment = process.env,
  readConfig = (path) => readFileSync(path, "utf8"),
  readStatus = () =>
    JSON.parse(invokeLocalCli(["status", "-o", "json"], environment)),
} = {}) {
  if (
    typeof environment.SUPABASE_WORKDIR !== "string" ||
    !environment.SUPABASE_WORKDIR.trim()
  )
    throw new Error("EXPLICIT_DISPOSABLE_WORKDIR_REQUIRED");
  const workdir = resolve(environment.SUPABASE_WORKDIR);
  let config;
  try {
    config = readConfig(join(workdir, "supabase", "config.toml"));
  } catch {
    throw new Error("DISPOSABLE_CONFIG_UNAVAILABLE");
  }
  const projectId = config.match(/^\s*project_id\s*=\s*"([^"\r\n]+)"/m)?.[1];
  if (projectId !== PROJECT) throw new Error("UNAPPROVED_DISPOSABLE_PROJECT");
  const raw = readStatus();
  parseLocalSupabaseStatus(raw);
  let database;
  try {
    database = new URL(raw.DB_URL);
  } catch {
    throw new Error("LOOPBACK_DATABASE_REQUIRED");
  }
  if (
    !["postgres:", "postgresql:"].includes(database.protocol) ||
    !["127.0.0.1", "localhost"].includes(database.hostname)
  )
    throw new Error("LOOPBACK_DATABASE_REQUIRED");
  return { workdir, projectId };
}
export function parseRehearsalQueryResult(output) {
  let rows;
  try {
    rows = JSON.parse(output);
  } catch {
    throw new Error("LOCAL_IMPORT_RESPONSE_INVALID");
  }
  if (!Array.isArray(rows) || rows.length !== 1)
    throw new Error("LOCAL_IMPORT_RESPONSE_INVALID");
  const result = rows[0]?.result;
  if (!result || typeof result !== "object" || Array.isArray(result))
    throw new Error("LOCAL_IMPORT_RESPONSE_INVALID");
  return result;
}
function queryLocalSql(sql, target, environment) {
  // The only SQL file is generated internally. Source text enters SQL solely as base64.
  const temporary = mkdtempSync(join(tmpdir(), "atlas-master-import-"));
  try {
    const path = join(temporary, "query.sql");
    writeFileSync(path, sql, { encoding: "utf8", mode: 0o600 });
    const output = invokeLocalCli(
      ["db", "query", "--local", "--output-format", "json", "--file", path],
      { ...environment, SUPABASE_WORKDIR: target.workdir },
    );
    return parseRehearsalQueryResult(output);
  } finally {
    rmSync(temporary, { recursive: true, force: true });
  }
}
export function runLocalMasterDataRehearsal({
  file,
  apply = false,
  actorId,
  planChecksum,
  environment = process.env,
  checkTarget = () => validateDisposableRehearsalTarget({ environment }),
  executeSql,
} = {}) {
  if (typeof file !== "string" || !file.trim())
    throw new Error("EXPLICIT_SNAPSHOT_FILE_REQUIRED");
  if (apply && (typeof actorId !== "string" || !UUID.test(actorId)))
    throw new Error("VALID_IMPORT_ACTOR_REQUIRED");
  if (
    apply &&
    (typeof planChecksum !== "string" || !CHECKSUM.test(planChecksum))
  )
    throw new Error("REVIEWED_PLAN_CHECKSUM_REQUIRED");
  let snapshot;
  try {
    snapshot = JSON.parse(readFileSync(resolve(file), "utf8"));
  } catch {
    throw new Error("SNAPSHOT_FILE_INVALID");
  }
  if (
    !snapshot ||
    typeof snapshot !== "object" ||
    Array.isArray(snapshot) ||
    snapshot.contract_version !== "OPS-V1-MASTER-SNAPSHOT.v1"
  )
    throw new Error("SNAPSHOT_CONTRACT_INVALID");
  if (snapshot.snapshot_checksum !== checksumOpsV1MasterSnapshot(snapshot))
    throw new Error("SNAPSHOT_CHECKSUM_MISMATCH");
  const target = checkTarget();
  const query =
    executeSql ?? ((sql) => queryLocalSql(sql, target, environment));
  const literal = `convert_from(decode('${Buffer.from(JSON.stringify(snapshot), "utf8").toString("base64")}','base64'),'UTF8')::jsonb`;
  const previewSql = `select atlas_legacy.preview_master_data_snapshot(${literal}) as result;\n`;
  const preview = query(previewSql, target);
  const mode = apply ? "apply" : "preview";
  const response = {
    mode,
    snapshot: {
      snapshot_id: snapshot.snapshot_id,
      snapshot_checksum: snapshot.snapshot_checksum,
      source_counts: snapshot.source_counts,
    },
    preview,
  };
  if (!apply || preview?.success !== true)
    return {
      ...response,
      report: formatMasterDataRehearsalReport({ mode, snapshot, preview }),
    };
  if (preview.plan_checksum !== planChecksum)
    throw new Error("REVIEWED_PLAN_CHANGED");
  const result = query(
    `select atlas_legacy.apply_master_data_snapshot(${literal},'${planChecksum}','${actorId.toLowerCase()}'::uuid) as result;\n`,
    target,
  );
  if (result?.success !== true)
    return {
      ...response,
      result,
      report: formatMasterDataRehearsalReport({
        mode,
        snapshot,
        preview,
        result,
      }),
    };
  const afterPreview = query(previewSql, target);
  if (!isReconciledMasterPreview(afterPreview))
    throw new Error("AUTHORITATIVE_READBACK_DID_NOT_RECONCILE");
  return {
    ...response,
    result,
    afterPreview,
    report: formatMasterDataRehearsalReport({
      mode,
      snapshot,
      preview,
      result,
      afterPreview,
    }),
  };
}
function main() {
  const args = process.argv.slice(2).filter((arg) => arg !== "--");
  const flags = new Map();
  for (let i = 0; i < args.length; i += 1) {
    const flag = args[i];
    if (
      flags.has(flag) ||
      ![
        "--file",
        "--apply",
        "--actor-id",
        "--plan-checksum",
        "--json",
      ].includes(flag)
    )
      throw new Error("INVALID_CLI_ARGUMENT");
    if (["--apply", "--json"].includes(flag)) flags.set(flag, true);
    else {
      const value = args[++i];
      if (!value || value.startsWith("--"))
        throw new Error("MISSING_CLI_ARGUMENT");
      flags.set(flag, value);
    }
  }
  const response = runLocalMasterDataRehearsal({
    file: flags.get("--file"),
    apply: flags.has("--apply"),
    actorId: flags.get("--actor-id"),
    planChecksum: flags.get("--plan-checksum"),
  });
  console.log(
    flags.has("--json") ? JSON.stringify(response, null, 2) : response.report,
  );
  if (
    response.preview.success !== true ||
    (response.mode === "apply" && response.result?.success !== true)
  )
    process.exitCode = 2;
}
if (
  process.argv[1] &&
  resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  try {
    main();
  } catch (error) {
    console.error(
      error instanceof Error && /^[A-Z_]+$/.test(error.message)
        ? error.message
        : "LOCAL_REHEARSAL_FAILED",
    );
    process.exitCode = 1;
  }
}
