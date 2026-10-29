import { createHash, randomUUID } from "node:crypto";
import { readFileSync, readdirSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { executeAtlasStagingPostgres } from "./atlas-staging-postgres-transport.mjs";
import { validateV1ReferenceImportRequest } from "./atlas-staging-v1-reference-target.mjs";
import { verifyExactMainCheckout } from "./import-atlas-staging-v1-reference-snapshot.mjs";
import { parseStagingMasterResult } from "./import-atlas-staging-master-data.mjs";
import {
  canonicalMasterJson,
  canonicalizeUnitSourceLabel,
} from "./ops-v1-master-snapshot-contract.mjs";
import { redactAtlasStagingDiagnostic } from "./atlas-staging-contract.mjs";
import { migrationVersionsFromFilenames } from "./verify-atlas-staging.mjs";

const STAGING = "rnzxmxiiqgtdevzregff";
const SOURCE = "qnthofvccilhnefdcxnz";
const CONTRACT = "OPS-V1-INGREDIENT-NAME-FORWARD-CORRECTION.v1";
const CORRECTION_ID = "ops-v1-ingredient-name-forward-correction-20261027-v1";
const SHA256 = /^[0-9a-f]{64}$/;
export const INGREDIENT_NAME_CORRECTIONS = Object.freeze([
  ["931", "Chả giò", "Chả giò xốp Cholimex 2kg"],
  ["962", "Hẹ tươi", "Hẹ lá"],
  ["1040", "Thịt heo xay", "Thịt vai heo xay"],
  ["1041", "Thịt nạc vai", "Nạc vai heo"],
  ["1047", "Tôm thẻ", "Tôm thẻ size 60 - 70 con/kg"],
  ["1053", "Ức gà fillet (không da)", "Ức phi lê gà"],
  ["1067", "Sườn non heo chặt sẵn", "Sườn non heo chặt nhỏ"],
  ["1154", "Nạc lưng heo", "Nạc lưng heo (Miếng)"],
]);

function hash(value) {
  return createHash("sha256").update(value, "utf8").digest("hex");
}

function fail(detail) {
  throw new Error(
    `INGREDIENT_NAME_FORWARD_CORRECTION_REQUIRED_REVIEW:${detail}`,
  );
}

function text(value) {
  return typeof value === "string" ? value.normalize("NFC").trim() : null;
}

function positive(value) {
  const token = text(String(value ?? ""));
  if (!token || !/^\d{1,14}(?:\.\d{1,6})?$/.test(token) || !/[1-9]/.test(token))
    fail("INVALID_SOURCE_ORDER_STEP");
  return token
    .replace(/^0+(?=\d)/, "")
    .replace(/(\.\d*?)0+$/, "$1")
    .replace(/\.$/, "");
}

function sourceRecord(row) {
  const legacyId = text(String(row.id ?? row.legacy_id ?? ""));
  const ingredientName = text(row.name ?? row.ingredient_name);
  if (!legacyId || !/^[1-9]\d*$/.test(legacyId) || !ingredientName)
    fail("INVALID_SOURCE_ROW");
  if (row.ingredient_code) return { ...row, legacy_id: legacyId };
  return {
    legacy_id: legacyId,
    ingredient_code: `v1-ingredient-${legacyId}`,
    ingredient_name: ingredientName,
    ingredient_type_legacy_id:
      row.ingredient_type_id == null ? null : String(row.ingredient_type_id),
    ingredient_order_group_legacy_id:
      row.shopping_type_id == null ? null : String(row.shopping_type_id),
    purchase_unit_legacy_id: canonicalizeUnitSourceLabel(row.purchase_unit),
    order_step: positive(row.order_step),
    ingredient_status: row.archived_at
      ? "ARCHIVED"
      : row.is_active === true
        ? "ACTIVE"
        : "INACTIVE",
  };
}

export function ingredientNameCorrectionMigrationVersions(cwd = process.cwd()) {
  return migrationVersionsFromFilenames(
    readdirSync(resolve(cwd, "supabase/migrations")),
  );
}

export function buildIngredientNameCorrectionPayload(
  snapshot,
  { migrationVersions = ingredientNameCorrectionMigrationVersions() } = {},
) {
  if (
    snapshot?.source_project_ref !== SOURCE ||
    !SHA256.test(String(snapshot.snapshot_checksum ?? "")) ||
    !Array.isArray(snapshot.records?.ingredients)
  )
    fail("SOURCE_SNAPSHOT_INVALID");
  const rows = snapshot.records.ingredients.map(sourceRecord);
  const records = INGREDIENT_NAME_CORRECTIONS.map(
    ([legacyId, expectedBeforeName, expectedAfterName]) => {
      const matches = rows.filter((row) => row.legacy_id === legacyId);
      if (
        matches.length !== 1 ||
        matches[0].ingredient_name !== expectedAfterName ||
        matches[0].ingredient_code !== `v1-ingredient-${legacyId}`
      )
        fail("SOURCE_SCOPE_DRIFT");
      const source = matches[0];
      return {
        legacy_id: legacyId,
        expected_before_name: expectedBeforeName,
        expected_after_name: expectedAfterName,
        source_fingerprint: hash(canonicalMasterJson(source)),
        source_record: source,
      };
    },
  );
  if (rows.length !== records.length) fail("SOURCE_SCOPE_DRIFT");
  if (
    migrationVersions.length !== 135 ||
    migrationVersions.at(-1) !== "20261023122829"
  )
    fail("REPOSITORY_MIGRATION_SCOPE_DRIFT");
  return {
    contract_version: CONTRACT,
    source_project_ref: SOURCE,
    correction_id: CORRECTION_ID,
    source_snapshot_checksum: snapshot.snapshot_checksum,
    expected_migration_versions: migrationVersions,
    migration_versions_checksum: hash(canonicalMasterJson(migrationVersions)),
    records,
  };
}

export function buildIngredientNameCorrectionSql(
  payload,
  { targetProjectRef, apply = false, planChecksum } = {},
) {
  if (targetProjectRef !== STAGING) fail("EXACT_STAGING_TARGET_REQUIRED");
  if (apply && !SHA256.test(String(planChecksum ?? "")))
    fail("REVIEWED_PLAN_CHECKSUM_REQUIRED");
  const packageSql = readFileSync(
    new URL(
      "../supabase/packages/atlas-staging-ingredient-name-forward-correction.sql",
      import.meta.url,
    ),
    "utf8",
  );
  const encoded = Buffer.from(JSON.stringify(payload), "utf8").toString(
    "base64",
  );
  const literal = `convert_from(decode('${encoded}','base64'),'UTF8')::jsonb`;
  return `set statement_timeout='2min';\nset lock_timeout='15s';\n${packageSql}\nselect pg_temp.run_ingredient_name_forward_correction(${literal}, ${apply ? "true" : "false"}, ${apply ? `'${planChecksum}'` : "null"}, '${payload.correction_id}') as result;\n`;
}

function findSnapshot(value) {
  if (Array.isArray(value)) {
    for (const child of value) {
      const found = findSnapshot(child);
      if (found) return found;
    }
    return null;
  }
  if (!value || typeof value !== "object") return null;
  if (value.snapshot) {
    if (typeof value.snapshot === "object") return value.snapshot;
    try {
      return JSON.parse(value.snapshot);
    } catch {
      return null;
    }
  }
  for (const child of Object.values(value)) {
    const found = findSnapshot(child);
    if (found) return found;
  }
  return null;
}

export function buildIngredientNameSourceSql() {
  const ids = INGREDIENT_NAME_CORRECTIONS.map(([id]) => id).join(",");
  return `select jsonb_build_object(
  'source_project_ref','${SOURCE}',
  'source_access',(select jsonb_build_object(
    'role_name',r.rolname,'superuser',r.rolsuper,'create_role',r.rolcreaterole,
    'create_db',r.rolcreatedb,
    'has_select',pg_catalog.has_table_privilege(r.oid,'public.ingredients','SELECT'),
    'has_non_select',pg_catalog.has_table_privilege(r.oid,'public.ingredients','INSERT')
      or pg_catalog.has_table_privilege(r.oid,'public.ingredients','UPDATE')
      or pg_catalog.has_table_privilege(r.oid,'public.ingredients','DELETE')
      or pg_catalog.has_table_privilege(r.oid,'public.ingredients','TRUNCATE'))
    from pg_catalog.pg_roles r where r.rolname=current_user),
  'ingredients',(select coalesce(jsonb_agg(to_jsonb(i) order by i.id),'[]') from (
    select id::text,name,purchase_unit,ingredient_type_id::text,shopping_type_id::text,
      order_step::text,is_active,archived_at
    from public.ingredients where id in (${ids})
  ) i)
) as snapshot;`;
}

export async function extractReviewedIngredientSnapshot({
  projectRef = SOURCE,
  accessToken,
  fetchImpl = fetch,
} = {}) {
  if (projectRef !== SOURCE || !text(accessToken))
    fail("SOURCE_REQUEST_INVALID");
  let response;
  try {
    response = await fetchImpl(
      `https://api.supabase.com/v1/projects/${SOURCE}/database/query/read-only`,
      {
        method: "POST",
        redirect: "error",
        signal: AbortSignal.timeout(45_000),
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
          Accept: "application/json",
        },
        body: JSON.stringify({ query: buildIngredientNameSourceSql() }),
      },
    );
  } catch {
    fail("SOURCE_READ_FAILED");
  }
  if (response.status !== 201) fail(`SOURCE_READ_HTTP_${response.status}`);
  let output;
  try {
    output = await response.json();
  } catch {
    fail("SOURCE_RESPONSE_INVALID");
  }
  const raw = findSnapshot(output);
  const access = raw?.source_access;
  if (
    raw?.source_project_ref !== SOURCE ||
    access?.role_name !== "supabase_read_only_user" ||
    access.superuser !== false ||
    access.create_role !== false ||
    access.create_db !== false ||
    access.has_select !== true ||
    access.has_non_select !== false ||
    !Array.isArray(raw.ingredients)
  )
    fail("SOURCE_READ_ONLY_PROOF_INVALID");
  const ingredients = raw.ingredients.map(sourceRecord);
  const checksum = hash(canonicalMasterJson(ingredients));
  return {
    contract_version: CONTRACT,
    source_project_ref: SOURCE,
    snapshot_id: `${CORRECTION_ID}-${checksum.slice(0, 12)}`,
    records: { ingredients },
    source_counts: { ingredients: ingredients.length },
    source_diagnostics: [],
    snapshot_checksum: checksum,
  };
}

function validatePlan(result, payload, statuses) {
  if (
    result?.success !== true ||
    !statuses.includes(result.status) ||
    result.correction_id !== CORRECTION_ID ||
    result.source_snapshot_checksum !== payload.source_snapshot_checksum ||
    result.migration_versions_checksum !==
      payload.migration_versions_checksum ||
    !SHA256.test(String(result.plan_checksum ?? "")) ||
    result.update_count !== 8 ||
    result.no_change_count !== 0 ||
    !Array.isArray(result.report) ||
    result.report.length !== 8
  )
    fail("TARGET_PLAN_DRIFT");
  for (const expected of payload.records) {
    const row = result.report.find(
      (item) => item.legacy_id === expected.legacy_id,
    );
    if (
      !row ||
      row.current_name !== expected.expected_before_name ||
      row.proposed_name !== expected.expected_after_name ||
      row.action !== "UPDATE"
    )
      fail("TARGET_REPORT_DRIFT");
  }
  return result;
}

async function authenticatedIngredientReadback(
  payload,
  authority,
  environment,
  fetchImpl,
) {
  const key = environment.VITE_SUPABASE_PUBLISHABLE_KEY;
  const email = environment.ATLAS_STAGING_TEST_EMAIL;
  const password = environment.ATLAS_STAGING_TEST_PASSWORD;
  if (!key || !email || !password)
    fail("AUTHENTICATED_READ_CREDENTIAL_REQUIRED");
  const request = async (url, options) => {
    let response;
    try {
      response = await fetchImpl(url, {
        ...options,
        redirect: "error",
        signal: AbortSignal.timeout(45_000),
      });
      return { ok: response.ok, body: await response.json() };
    } catch {
      fail("AUTHENTICATED_READ_FAILED");
    }
  };
  const login = await request(
    `${authority.targetSupabaseUrl}/auth/v1/token?grant_type=password`,
    {
      method: "POST",
      headers: { apikey: key, "Content-Type": "application/json" },
      body: JSON.stringify({ email, password }),
    },
  );
  if (!login.ok || !login.body?.access_token || !login.body?.user?.id)
    fail("AUTHENTICATED_SIGNIN_FAILED");
  const read = await request(
    `${authority.targetSupabaseUrl}/rest/v1/rpc/get_ingredient_supplier_master_data`,
    {
      method: "POST",
      headers: {
        apikey: key,
        Authorization: `Bearer ${login.body.access_token}`,
        "Content-Type": "application/json",
        "Content-Profile": "atlas_api",
      },
      body: JSON.stringify({
        request: {
          contract_version: "RMVP-01.v1",
          requested_by_auth_subject: login.body.user.id,
          correlation_id: randomUUID(),
          payload: {},
        },
      }),
    },
  );
  if (
    !read.ok ||
    read.body?.success !== true ||
    !Array.isArray(read.body.ingredients)
  )
    fail("AUTHENTICATED_READBACK_FAILED");
  for (const expected of payload.records) {
    const row = read.body.ingredients.find(
      (item) => item.ingredient_code === `v1-ingredient-${expected.legacy_id}`,
    );
    if (row?.ingredient_name !== expected.expected_after_name)
      fail("AUTHENTICATED_NAME_READBACK_DRIFT");
  }
  return { status: "AUTHENTICATED_INGREDIENT_NAME_READBACK_PASS", count: 8 };
}

export async function runIngredientNameCorrection({
  commitSha,
  apply = false,
  planChecksum,
  targetConfirmation,
  environment = process.env,
  cwd = process.cwd(),
  verifyCheckout = verifyExactMainCheckout,
  extractSnapshot = extractReviewedIngredientSnapshot,
  executeTarget,
  verifyReadback,
  fetchImpl = fetch,
} = {}) {
  if (apply && !SHA256.test(String(planChecksum ?? "")))
    fail("REVIEWED_PLAN_CHECKSUM_REQUIRED");
  if (!apply && planChecksum != null) fail("PLAN_CHECKSUM_APPLY_ONLY");
  const authority = validateV1ReferenceImportRequest({
    environment,
    applyRequested: apply,
    applyFlagPresent: apply,
    targetConfirmation,
  });
  await verifyCheckout({ commitSha, cwd });
  const snapshot = await extractSnapshot({
    projectRef: SOURCE,
    accessToken: authority.targetAccessToken,
    fetchImpl,
  });
  const payload = buildIngredientNameCorrectionPayload(snapshot, {
    migrationVersions: ingredientNameCorrectionMigrationVersions(cwd),
  });
  const target = {
    projectRef: authority.targetProjectRef,
    supabaseUrl: authority.targetSupabaseUrl,
    accessToken: authority.targetAccessToken,
  };
  const execute =
    executeTarget ??
    ((requestedTarget, sql) =>
      executeAtlasStagingPostgres(requestedTarget, sql, {
        environment,
        cwd,
      }));
  const call = async (requestedApply, checksum) =>
    parseStagingMasterResult(
      await execute(
        target,
        buildIngredientNameCorrectionSql(payload, {
          targetProjectRef: target.projectRef,
          apply: requestedApply,
          planChecksum: checksum,
        }),
      ),
    );
  const preview = validatePlan(await call(false), payload, ["PREVIEW"]);
  if (!apply) return preview;
  if (preview.plan_checksum !== planChecksum)
    fail("REVIEWED_PLAN_CHECKSUM_DRIFT");
  await verifyCheckout({ commitSha, cwd });
  const applied = validatePlan(await call(true, planChecksum), payload, [
    "APPLIED",
    "REPLAYED",
  ]);
  if (
    applied.reconciled !== true ||
    applied.operational_data_unchanged !== true ||
    applied.unrelated_master_facts_unchanged !== true ||
    applied.updated_count !== 8
  )
    fail("APPLY_READBACK_DRIFT");
  const replay = validatePlan(await call(true, planChecksum), payload, [
    "REPLAYED",
  ]);
  if (replay.reconciled !== true) fail("REPLAY_DRIFT");
  const readback = await (
    verifyReadback ??
    (executeTarget
      ? async () => ({ status: "INJECTED_TARGET_READBACK" })
      : authenticatedIngredientReadback)
  )(payload, authority, environment, fetchImpl);
  return {
    ...applied,
    replay_status: replay.status,
    authenticated_readback: readback,
  };
}

async function main() {
  const args = process.argv.slice(2).filter((arg) => arg !== "--");
  const flags = new Map();
  for (let index = 0; index < args.length; index += 1) {
    const flag = args[index];
    if (
      flags.has(flag) ||
      ![
        "--commit-sha",
        "--target-project-ref",
        "--plan-checksum",
        "--apply",
      ].includes(flag)
    )
      fail("INVALID_ARGUMENT");
    if (flag === "--apply") flags.set(flag, true);
    else flags.set(flag, args[++index]);
  }
  const result = await runIngredientNameCorrection({
    commitSha: flags.get("--commit-sha"),
    apply: flags.has("--apply"),
    planChecksum: flags.get("--plan-checksum"),
    targetConfirmation: flags.get("--target-project-ref"),
  });
  console.log(JSON.stringify(result, null, 2));
}

if (
  process.argv[1] &&
  resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  main().catch((error) => {
    console.error(
      redactAtlasStagingDiagnostic(
        error instanceof Error
          ? error.message
          : "Ingredient-name correction failed safely.",
      ),
    );
    process.exitCode = 1;
  });
}
