import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { checksumOpsV1MasterSnapshot } from "./ops-v1-master-snapshot-contract.mjs";
import { exportOpsV1MasterSnapshotFile } from "./extract-ops-v1-master-snapshot.mjs";
import {
  validateDisposableRehearsalTarget,
  parseRehearsalQueryResult,
} from "./run-local-master-data-rehearsal.mjs";
import { runPinnedSupabase } from "./local-supabase-status.mjs";

const SOURCE = "qnthofvccilhnefdcxnz";
const SCOPES = {
  ingredient_change_orders: "SYSTEM_INGREDIENT",
  system_bom_change_orders: "SYSTEM_DISH",
  school_wide_overrides: "SCHOOL",
  school_recipe_overrides: "SCHOOL_DISH",
};
const ACTIONS = {
  add: "ADD",
  replace: "REPLACE",
  adjust_qty: "ADJUST_QUANTITY",
  remove: "REMOVE",
};
const nullableText = (value) => value == null || typeof value === "string";

export function buildRecipeHistorySourceSql() {
  const tables = Object.keys(SCOPES);
  const privileges = tables
    .map(
      (table) =>
        `pg_catalog.has_table_privilege(role.oid, 'public.${table}', 'SELECT')`,
    )
    .join(" and ");
  const writes = tables
    .flatMap((table) =>
      ["INSERT", "UPDATE", "DELETE", "TRUNCATE"].map(
        (privilege) =>
          `pg_catalog.has_table_privilege(role.oid, 'public.${table}', '${privilege}')`,
      ),
    )
    .join(" or ");
  const records = tables.map((table) => {
    const ingredient = table === "ingredient_change_orders";
    const dish = [
      "system_bom_change_orders",
      "school_recipe_overrides",
    ].includes(table);
    const school = [
      "school_wide_overrides",
      "school_recipe_overrides",
    ].includes(table);
    return `'${table}', (select coalesce(jsonb_agg(nested.record order by (nested.record->>'id')::bigint), '[]'::jsonb) from (
      select to_jsonb(s) || jsonb_build_object(
        'id',s.id::text,
        '${ingredient ? "old_ingredient_id" : "ingredient_id"}',s.${ingredient ? "old_ingredient_id" : "ingredient_id"}::text,
        '${ingredient ? "new_ingredient_id" : "substitute_ingredient_id"}',s.${ingredient ? "new_ingredient_id" : "substitute_ingredient_id"}::text,
        'action',${ingredient ? "'replace'" : "s.action"},
        'usable_quantity_override',${ingredient ? "null::text" : "s.usable_quantity_override::text"},
        'dish_id',${dish ? "s.dish_id::text" : "null::text"},
        'school_id',${school ? "s.school_id::text" : "null::text"},
        'school_type_id',${ingredient ? "null::text" : "s.school_type_id::text"},
        'dish_name',${dish ? "d.name" : "null::text"},
        'school_name',${school ? "sc.name" : "null::text"},
        'ingredient_name',i.name,'substitute_name',replacement.name,
        'purchase_unit',${table === "school_recipe_overrides" ? "coalesce(s.purchase_unit_override,i.purchase_unit,replacement.purchase_unit)" : "coalesce(i.purchase_unit,replacement.purchase_unit)"}
      ) as record
      from public.${table} s
      left join public.ingredients i on i.id=s.${ingredient ? "old_ingredient_id" : "ingredient_id"}
      left join public.ingredients replacement on replacement.id=s.${ingredient ? "new_ingredient_id" : "substitute_ingredient_id"}
      ${dish ? "left join public.dishes d on d.id=s.dish_id" : ""}
      ${school ? "left join public.schools sc on sc.id=s.school_id" : ""}
    ) nested)`;
  });
  return `select jsonb_build_object('source_project_ref','${SOURCE}', 'exported_at',statement_timestamp(),
    'source_access',(select jsonb_build_object('role_name',role.rolname,'transactionReadOnly',current_setting('transaction_read_only'),'superuser',role.rolsuper,'bypassRls',role.rolbypassrls,'createRole',role.rolcreaterole,'createDb',role.rolcreatedb,'hasRequiredSelect',(${privileges}),'hasNonSelectTablePrivilege',(${writes})) from pg_roles role where role.rolname=current_user),
    'source_counts',jsonb_build_object(${tables.map((table) => `'${table}',(select count(*) from public.${table})`).join(",")}),
    'records',jsonb_build_object(${records.join(",")})) as snapshot`;
}

export function normalizeRecipeHistorySnapshot(
  raw,
  { snapshotId, extractorVersion },
) {
  if (raw?.source_project_ref !== SOURCE)
    throw new Error("UNAPPROVED_SOURCE_PROJECT");
  const access = raw.source_access;
  const restrictedRole =
    access?.createRole === false &&
    access?.createDb === false &&
    access?.hasNonSelectTablePrivilege === false;
  if (
    !access ||
    access.superuser !== false ||
    access.bypassRls !== true ||
    access.hasRequiredSelect !== true ||
    (!restrictedRole && access.transactionReadOnly !== "on")
  )
    throw new Error("SOURCE_NOT_READ_ONLY");
  if (
    !snapshotId?.trim() ||
    !extractorVersion?.trim() ||
    !Number.isFinite(Date.parse(raw.exported_at))
  )
    throw new Error("SNAPSHOT_METADATA_INVALID");
  if (
    Object.keys(raw.records ?? {})
      .sort()
      .join() !== Object.keys(SCOPES).sort().join() ||
    Object.keys(raw.source_counts ?? {})
      .sort()
      .join() !== Object.keys(SCOPES).sort().join()
  )
    throw new Error("SOURCE_COMPLETENESS_INVALID");
  const records = [];
  for (const [table, scope] of Object.entries(SCOPES)) {
    const rows = raw.records[table];
    if (!Array.isArray(rows) || raw.source_counts[table] !== rows.length)
      throw new Error("SOURCE_COMPLETENESS_INVALID");
    const seen = new Set();
    for (const row of rows) {
      if (
        !row ||
        typeof row.id !== "string" ||
        !/^[1-9]\d*$/.test(row.id) ||
        typeof row.is_active !== "boolean" ||
        !Object.hasOwn(ACTIONS, row.action) ||
        ![
          row.effective_date,
          row.created_at,
          row.school_type_id,
          row.dish_name,
          row.school_name,
          row.ingredient_name,
          row.substitute_name,
          row.purchase_unit,
          row.note,
        ].every(nullableText) ||
        (row.usable_quantity_override != null &&
          (typeof row.usable_quantity_override !== "string" ||
            !/^-?\d+(\.\d+)?$/.test(row.usable_quantity_override)))
      )
        throw new Error("SOURCE_RECORD_INVALID");
      if (seen.has(row.id)) throw new Error("DUPLICATE_SOURCE_IDENTITY");
      seen.add(row.id);
      records.push({
        source_table: table,
        legacy_id: row.id,
        scope_kind: scope,
        action: ACTIONS[row.action],
        source_active: row.is_active,
        effective_from: row.effective_date ?? null,
        source_created_at: row.created_at ?? null,
        source_school_type_id: row.school_type_id ?? null,
        dish_name: row.dish_name ?? null,
        school_name: row.school_name ?? null,
        ingredient_name: row.ingredient_name ?? null,
        substitute_name: row.substitute_name ?? null,
        quantity: row.usable_quantity_override ?? null,
        unit_name: row.purchase_unit ?? null,
        note: row.note ?? null,
        source_record: row,
      });
    }
  }
  records.sort(
    (a, b) =>
      a.source_table.localeCompare(b.source_table) ||
      (BigInt(a.legacy_id) < BigInt(b.legacy_id)
        ? -1
        : BigInt(a.legacy_id) > BigInt(b.legacy_id)
          ? 1
          : 0),
  );
  const snapshot = {
    contract_version: "OPS-V1-RECIPE-HISTORY.v1",
    source_system: "OPS_V1_RECIPE_HISTORY",
    source_project_ref: SOURCE,
    snapshot_id: snapshotId,
    extractor_version: extractorVersion,
    exported_at: new Date(raw.exported_at).toISOString(),
    source_access: access,
    source_counts: raw.source_counts,
    source_diagnostics: [],
    records,
  };
  return {
    ...snapshot,
    snapshot_checksum: checksumOpsV1MasterSnapshot(snapshot),
  };
}

export async function extractRecipeHistorySnapshot({
  projectRef = SOURCE,
  accessToken,
  fetchImpl = fetch,
  ...identity
}) {
  if (projectRef !== SOURCE) throw new Error("UNAPPROVED_SOURCE_PROJECT");
  if (!accessToken?.trim()) throw new Error("SOURCE_CREDENTIAL_MISSING");
  let response;
  try {
    response = await fetchImpl(
      `https://api.supabase.com/v1/projects/${SOURCE}/database/query/read-only`,
      {
        method: "POST",
        redirect: "error",
        signal: AbortSignal.timeout(60000),
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ query: buildRecipeHistorySourceSql() }),
      },
    );
  } catch {
    throw new Error("SOURCE_FETCH_FAILED");
  }
  if (response.status !== 201) throw new Error("SOURCE_FETCH_FAILED");
  let body;
  try {
    body = await response.json();
  } catch {
    throw new Error("SOURCE_RESPONSE_INVALID");
  }
  if (!Array.isArray(body) || body.length !== 1)
    throw new Error("SOURCE_RESPONSE_INVALID");
  let raw = body[0]?.snapshot;
  if (typeof raw === "string") {
    try {
      raw = JSON.parse(raw);
    } catch {
      throw new Error("SOURCE_RESPONSE_INVALID");
    }
  }
  return normalizeRecipeHistorySnapshot(raw, identity);
}

export function runLocalRecipeHistory({
  file,
  apply = false,
  actorId,
  planChecksum,
  checkTarget = validateDisposableRehearsalTarget,
  executeSql,
} = {}) {
  if (!file) throw new Error("EXPLICIT_SNAPSHOT_FILE_REQUIRED");
  if (
    apply &&
    (!/^[a-f0-9-]{36}$/i.test(actorId ?? "") ||
      !/^[a-f0-9]{64}$/.test(planChecksum ?? ""))
  )
    throw new Error("ACTOR_AND_REVIEWED_PLAN_REQUIRED");
  const snapshot = JSON.parse(readFileSync(resolve(file), "utf8"));
  if (
    snapshot?.contract_version !== "OPS-V1-RECIPE-HISTORY.v1" ||
    snapshot.snapshot_checksum !== checksumOpsV1MasterSnapshot(snapshot)
  )
    throw new Error("SNAPSHOT_CHECKSUM_MISMATCH");
  const target = checkTarget();
  const encoded = Buffer.from(JSON.stringify(snapshot)).toString("base64");
  const sql = `select atlas_legacy.import_recipe_change_order_history(convert_from(decode('${encoded}','base64'),'UTF8')::jsonb,${apply ? `'${actorId}'::uuid` : "null"},${apply ? `'${planChecksum}'` : "null"}) as result;`;
  if (executeSql) return executeSql(sql, target);
  const temporary = mkdtempSync(join(tmpdir(), "atlas-recipe-history-"));
  try {
    const path = join(temporary, "query.sql");
    writeFileSync(path, sql, { encoding: "utf8", mode: 0o600 });
    return parseRehearsalQueryResult(
      runPinnedSupabase(
        ["db", "query", "--local", "--output-format", "json", "--file", path],
        {
          env: { ...process.env, SUPABASE_WORKDIR: target.workdir },
          encoding: "utf8",
          stdio: ["ignore", "pipe", "pipe"],
          maxBuffer: 32 * 1024 * 1024,
        },
      ),
    );
  } finally {
    rmSync(temporary, { recursive: true, force: true });
  }
}

async function main() {
  const args = process.argv.slice(2).filter((a) => a !== "--");
  const flags = new Set(["--export", "--apply"]),
    values = new Map();
  for (let i = 0; i < args.length; i++) {
    const key = args[i];
    if (
      ![
        "--export",
        "--apply",
        "--output",
        "--snapshot-id",
        "--file",
        "--actor-id",
        "--plan-checksum",
      ].includes(key) ||
      values.has(key)
    )
      throw new Error("INVALID_ARGUMENTS");
    if (flags.has(key)) values.set(key, true);
    else {
      if (!args[i + 1] || args[i + 1].startsWith("--"))
        throw new Error("INVALID_ARGUMENTS");
      values.set(key, args[++i]);
    }
  }
  const exporting = values.has("--export");
  if (
    exporting &&
    (values.has("--file") ||
      values.has("--apply") ||
      values.has("--actor-id") ||
      values.has("--plan-checksum"))
  )
    throw new Error("INVALID_ARGUMENTS");
  if (!exporting && (values.has("--output") || values.has("--snapshot-id")))
    throw new Error("INVALID_ARGUMENTS");
  const result = exporting
    ? await exportOpsV1MasterSnapshotFile({
        output: values.get("--output"),
        snapshotId: values.get("--snapshot-id"),
        extractorVersion: execFileSync("git", ["rev-parse", "HEAD"], {
          encoding: "utf8",
        }).trim(),
        accessToken: process.env.ATLAS_STAGING_SUPABASE_ACCESS_TOKEN,
        extract: extractRecipeHistorySnapshot,
      })
    : runLocalRecipeHistory({
        file: values.get("--file"),
        apply: values.has("--apply"),
        actorId: values.get("--actor-id"),
        planChecksum: values.get("--plan-checksum"),
      });
  console.log(JSON.stringify(result, null, 2));
}
if (
  process.argv[1] &&
  resolve(process.argv[1]) === fileURLToPath(import.meta.url)
)
  main().catch((error) => {
    console.error(
      /^[A-Z_]+$/.test(error.message) ? error.message : "RECIPE_HISTORY_FAILED",
    );
    process.exitCode = 1;
  });
