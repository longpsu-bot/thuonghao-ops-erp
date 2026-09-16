import { executeAtlasStagingPostgres } from "./atlas-staging-postgres-transport.mjs";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { redactAtlasStagingDiagnostic } from "./atlas-staging-contract.mjs";
import { validateV1ReferenceImportRequest } from "./atlas-staging-v1-reference-target.mjs";
import { verifyExactMainCheckout } from "./import-atlas-staging-v1-reference-snapshot.mjs";
import {
  checksumOpsV1MasterSnapshot,
  extractOpsV1MasterSnapshot,
} from "./ops-v1-master-snapshot-contract.mjs";

const STAGING = "rnzxmxiiqgtdevzregff";
const SHA256 = /^[0-9a-f]{64}$/;
export function buildStagingMasterLoadSql(
  snapshot,
  { targetProjectRef, apply = false, planChecksum } = {},
) {
  if (targetProjectRef !== STAGING)
    throw new Error("EXACT_STAGING_TARGET_REQUIRED");
  if (
    !snapshot ||
    snapshot.contract_version !== "OPS-V1-MASTER-SNAPSHOT.v1" ||
    snapshot.source_project_ref !== "qnthofvccilhnefdcxnz" ||
    snapshot.snapshot_checksum !== checksumOpsV1MasterSnapshot(snapshot)
  )
    throw new Error("SNAPSHOT_CHECKSUM_OR_CONTRACT_INVALID");
  if (apply && !SHA256.test(String(planChecksum ?? "")))
    throw new Error("REVIEWED_PLAN_CHECKSUM_REQUIRED");
  const packageSql = readFileSync(
    new URL(
      "../supabase/packages/atlas-staging-master-load.sql",
      import.meta.url,
    ),
    "utf8",
  );
  const encoded = Buffer.from(JSON.stringify(snapshot), "utf8").toString(
    "base64",
  );
  const literal = `convert_from(decode('${encoded}','base64'),'UTF8')::jsonb`;
  return `set statement_timeout = '15min';\nset lock_timeout = '30s';\n${packageSql}\nselect pg_temp.run_staging_master_load(${literal}, ${apply ? "true" : "false"}, ${apply ? `'${planChecksum}'` : "null"}) as result;\n`;
}
export function parseStagingMasterResult(output) {
  let parsed;
  try {
    parsed = typeof output === "string" ? JSON.parse(output) : output;
  } catch {
    throw new Error("STAGING_RESPONSE_INVALID");
  }
  const result =
    Array.isArray(parsed) && parsed.length === 1 ? parsed[0]?.result : null;
  if (!result || typeof result !== "object" || Array.isArray(result))
    throw new Error("STAGING_RESPONSE_INVALID");
  return result;
}
function safeSummary(value) {
  const categories = {};
  const blockers = [];
  for (const issue of value.issues ?? []) {
    const group = `${issue.severity ?? "UNKNOWN"}/${issue.code ?? "UNKNOWN"}`;
    categories[group] = (categories[group] ?? 0) + 1;
    if (issue.severity === "BLOCKER")
      blockers.push({
        code: issue.code,
        object_type: issue.object_type ?? issue.entity,
        legacy_id: issue.legacy_id,
        field: issue.field,
      });
  }
  const { issues: ignored, ...rest } = value;
  return { ...rest, issue_categories: categories, blockers };
}
export async function runAtlasStagingMasterLoad({
  commitSha,
  apply = false,
  targetConfirmation,
  environment = process.env,
  cwd = process.cwd(),
  verifyCheckout = verifyExactMainCheckout,
  extractSnapshot = extractOpsV1MasterSnapshot,
  executeTarget,
  fetchImpl = fetch,
} = {}) {
  const authority = validateV1ReferenceImportRequest({
    environment,
    applyRequested: apply,
    applyFlagPresent: apply,
    targetConfirmation,
  });
  await verifyCheckout({ commitSha, cwd });
  const snapshot = await extractSnapshot({
    accessToken: authority.targetAccessToken,
    snapshotId: `ops-v1-staging-master-${environment.GITHUB_RUN_ID ?? Date.now()}-${environment.GITHUB_RUN_ATTEMPT ?? "1"}`,
    extractorVersion: commitSha,
    fetchImpl,
  });
  const target = {
    projectRef: authority.targetProjectRef,
    supabaseUrl: authority.targetSupabaseUrl,
    accessToken: authority.targetAccessToken,
  };
  const targetSql =
    executeTarget ??
    ((t, sql) => executeAtlasStagingPostgres(t, sql, { environment, cwd }));
  const execute = async (requestedApply, planChecksum) =>
    parseStagingMasterResult(
      await targetSql(
        target,
        buildStagingMasterLoadSql(snapshot, {
          targetProjectRef: target.projectRef,
          apply: requestedApply,
          planChecksum,
        }),
        (url, options) => fetchImpl(url, { ...options, redirect: "error" }),
      ),
    );
  const preview = await execute(false);
  const source = {
    snapshot_id: snapshot.snapshot_id,
    snapshot_checksum: snapshot.snapshot_checksum,
    exported_at: snapshot.exported_at,
    source_counts: snapshot.source_counts,
    canonical_counts: Object.fromEntries(
      Object.entries(snapshot.records).map(([name, rows]) => [
        name,
        rows.length,
      ]),
    ),
  };
  if (!apply || preview.success !== true)
    return { ...safeSummary(preview), source };
  if (
    !SHA256.test(String(preview.plan_checksum ?? "")) ||
    preview.snapshot_checksum !== snapshot.snapshot_checksum
  )
    throw new Error("STAGING_PREVIEW_CONTRACT_MISMATCH");
  const applied = await execute(true, preview.plan_checksum);
  if (
    applied.success !== true ||
    applied.reconciled !== true ||
    applied.operational_data_unchanged !== true
  )
    throw new Error(
      `STAGING_APPLY_FAILED:${/^[A-Z_]+$/.test(applied.error_code ?? "") ? applied.error_code : "READBACK"}`,
    );
  const replay = await execute(true, preview.plan_checksum);
  if (
    replay.success !== true ||
    replay.status !== "REPLAYED" ||
    replay.reconciled !== true ||
    replay.operational_data_unchanged !== true ||
    JSON.stringify(applied.target_counts) !==
      JSON.stringify(replay.target_counts)
  )
    throw new Error("STAGING_REPLAY_DID_NOT_RECONCILE");
  return {
    ...safeSummary(applied),
    source,
    status: "STAGING_MASTER_DATA_LOADED",
    replay_status: replay.status,
  };
}
export async function verifyStagingMasterVisibility(
  loadResult,
  { environment = process.env, fetchImpl = fetch } = {},
) {
  const { targetSupabaseUrl } = validateV1ReferenceImportRequest({
    environment,
  });
  const key = environment.VITE_SUPABASE_PUBLISHABLE_KEY;
  if (
    !key ||
    !environment.ATLAS_STAGING_TEST_EMAIL ||
    !environment.ATLAS_STAGING_TEST_PASSWORD
  )
    throw new Error("STAGING_READ_CREDENTIAL_MISSING");
  const login = await fetchImpl(
    `${targetSupabaseUrl}/auth/v1/token?grant_type=password`,
    {
      method: "POST",
      redirect: "error",
      headers: { apikey: key, "Content-Type": "application/json" },
      body: JSON.stringify({
        email: environment.ATLAS_STAGING_TEST_EMAIL,
        password: environment.ATLAS_STAGING_TEST_PASSWORD,
      }),
    },
  );
  const session = await login.json();
  if (!login.ok || !session.access_token || !session.user?.id)
    throw new Error("STAGING_READ_SIGNIN_FAILED");
  const read = async (name, version, payload = {}) => {
    const response = await fetchImpl(
      `${targetSupabaseUrl}/rest/v1/rpc/${name}`,
      {
        method: "POST",
        redirect: "error",
        headers: {
          apikey: key,
          Authorization: `Bearer ${session.access_token}`,
          "Content-Type": "application/json",
          "Content-Profile": "atlas_api",
        },
        body: JSON.stringify({
          request: {
            contract_version: version,
            requested_by_auth_subject: session.user.id,
            correlation_id: crypto.randomUUID(),
            payload,
          },
        }),
      },
    );
    const body = await response.json();
    if (!response.ok || body?.success !== true)
      throw new Error(`STAGING_AUTHENTICATED_READ_FAILED:${name}`);
    return body;
  };
  const schools = await read("get_school_master_data", "RMVP-01.v1");
  const master = await read(
    "get_ingredient_supplier_master_data",
    "RMVP-01.v1",
  );
  const recipes = await read("get_dish_recipe_workbench", "RMVP-02A.v2");
  const count = (rows, field, prefix) =>
    Array.isArray(rows)
      ? rows.filter((row) => String(row[field] ?? "").startsWith(prefix)).length
      : -1;
  const visible = {
    schools: count(schools.schools, "school_code", "v1-school-"),
    ingredients: count(master.ingredients, "ingredient_code", "v1-ingredient-"),
    suppliers: count(master.suppliers, "supplier_code", "v1-supplier-"),
    dishes: count(recipes.workbench?.dishes, "dish_code", "v1-dish-"),
  };
  for (const [entity, n] of Object.entries(visible))
    if (n !== loadResult.source.canonical_counts[entity])
      throw new Error(`VISIBLE_MASTER_COUNT_MISMATCH:${entity}`);
  const activeUnits = (master.units ?? []).filter(
    (unit) => unit.unit_status === "ACTIVE",
  );
  if (
    activeUnits.filter((unit) => unit.unit_code === "kg").length !== 1 ||
    activeUnits.some((unit) => unit.unit_name === "Hủ")
  )
    throw new Error("VISIBLE_CANONICAL_UNIT_MISMATCH");
  const now = new Date();
  const vietnam = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Ho_Chi_Minh",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(now);
  const monday = new Date(`${vietnam}T00:00:00Z`);
  monday.setUTCDate(monday.getUTCDate() - ((monday.getUTCDay() + 6) % 7));
  await read("get_planning_inputs_workbench", "RMVP-03A.v1", {
    week_start: monday.toISOString().slice(0, 10),
  });
  return {
    status: "AUTHENTICATED_MASTER_READS_PASS",
    visible_imported_counts: visible,
    planning_read: "PASS",
  };
}

async function main() {
  const args = process.argv.slice(2).filter((arg) => arg !== "--");
  const flags = new Map();
  for (let i = 0; i < args.length; i += 1) {
    const flag = args[i];
    if (
      flags.has(flag) ||
      !["--commit-sha", "--target-project-ref", "--apply"].includes(flag)
    )
      throw new Error("INVALID_ARGUMENT");
    if (flag === "--apply") flags.set(flag, true);
    else {
      const value = args[++i];
      if (!value || value.startsWith("--")) throw new Error("MISSING_ARGUMENT");
      flags.set(flag, value);
    }
  }
  const result = await runAtlasStagingMasterLoad({
    commitSha: flags.get("--commit-sha"),
    apply: flags.has("--apply"),
    targetConfirmation: flags.get("--target-project-ref"),
  });
  console.log(JSON.stringify(result, null, 2));
  if (result.status === "STAGING_MASTER_DATA_LOADED")
    console.log(
      JSON.stringify(await verifyStagingMasterVisibility(result), null, 2),
    );
  if (result.success !== true) process.exitCode = 2;
}
if (
  process.argv[1] &&
  resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  main().catch((error) => {
    console.error(
      redactAtlasStagingDiagnostic(
        error instanceof Error ? error.message : "STAGING_MASTER_LOAD_FAILED",
        [process.env.ATLAS_STAGING_SUPABASE_ACCESS_TOKEN],
      ),
    );
    process.exitCode = 1;
  });
}
