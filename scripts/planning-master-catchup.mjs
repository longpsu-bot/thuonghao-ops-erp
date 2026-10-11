import { readFileSync } from "node:fs";
import { createHash } from "node:crypto";
import {
  checksumOpsV1MasterSnapshot,
  canonicalMasterJson,
} from "./ops-v1-master-snapshot-contract.mjs";

function previewValidatorDefinition() {
  const migration = readFileSync(
    new URL(
      "../supabase/migrations/20261011162800_atlas_planning_tui_count_unit.sql",
      import.meta.url,
    ),
    "utf8",
  ).replace(/\r\n/g, "\n");
  const definitions = [
    ...migration.matchAll(
      /CREATE OR REPLACE FUNCTION atlas_legacy\.master_import_validate_values\(kind text, legacy text, source_row jsonb, v jsonb\)[\s\S]*?end \$function\$\s*;/gi,
    ),
  ];
  if (definitions.length !== 1)
    throw new Error("CANDIDATE_VALIDATOR_STRUCTURE_CHANGED");
  const definition = definitions[0][0];
  const remainder = migration
    .replace(definition, "")
    .replace(/^\s*--.*$/gm, "")
    .trim();
  if (!/^set role atlas_owner;\s*reset role;$/i.test(remainder))
    throw new Error("CANDIDATE_VALIDATOR_STRUCTURE_CHANGED");
  return definition;
}

export function planningCatchupPreviewValidationPolicy() {
  return {
    mode: "SESSION_LOCAL_CANDIDATE",
    migration_version: "20261011162800",
    definition_checksum: createHash("sha256")
      .update(previewValidatorDefinition())
      .digest("hex"),
  };
}

export function assertPlanningSource(snapshot) {
  if (snapshot?.snapshot_checksum !== checksumOpsV1MasterSnapshot(snapshot))
    throw new Error("SNAPSHOT_CHECKSUM_MISMATCH");
  if (
    snapshot.contract_version !== "OPS-V1-MASTER-SNAPSHOT.v1" ||
    snapshot.source_system !== "OPS_V1" ||
    snapshot.source_project_ref !== "qnthofvccilhnefdcxnz"
  )
    throw new Error("SOURCE_CONTRACT_INVALID");
  const a = snapshot.source_access;
  if (
    !a ||
    a.role_name !== "supabase_read_only_user" ||
    a.has_required_select !== true ||
    a.has_non_select_privilege !== false ||
    a.bypass_rls !== true ||
    a.superuser !== false ||
    a.create_role !== false ||
    a.create_db !== false
  )
    throw new Error("SOURCE_NOT_PROVEN_READ_ONLY");
}

/** Exact typed identity closure. Existing dependencies are references, never overwrite targets. */
export function derivePlanningCatchup(snapshot, mappings) {
  assertPlanningSource(snapshot);
  const typed = new Set();
  for (const m of mappings) {
    const key = `${m.object_type}:${m.legacy_id}`;
    if (typed.has(key)) throw new Error("DUPLICATE_TYPED_MAPPING");
    typed.add(key);
  }
  const source = snapshot.records;
  const records = Object.fromEntries(Object.keys(source).map((k) => [k, []]));
  const add = (entity, key) => {
    if (key == null) throw new Error(`MISSING_DEPENDENCY:${entity}:null`);
    const rows = source[entity].filter((r) => r.legacy_id === key);
    if (rows.length !== 1)
      throw new Error(`MISSING_DEPENDENCY:${entity}:${key}`);
    if (!records[entity].some((r) => r.legacy_id === key))
      records[entity].push(rows[0]);
    return rows[0];
  };
  for (const d of source.dishes.filter(
    (d) => d.dish_status === "ACTIVE" && !typed.has(`DISH:${d.legacy_id}`),
  )) {
    add("dishes", d.legacy_id);
    add("dish_types", d.dish_type_legacy_id);
    const recipes = source.recipes.filter(
      (r) => r.dish_legacy_id === d.legacy_id,
    );
    if (!recipes.length) throw new Error(`MISSING_RECIPE:${d.legacy_id}`);
    for (const r of recipes) {
      add("recipes", r.legacy_id);
      add("school_types", r.school_type_legacy_id);
      const lines = source.recipe_lines.filter(
        (l) => l.recipe_legacy_id === r.legacy_id,
      );
      // Empty composition preserves the typed root; only positive, valid source
      // lines authorize Recipe Versions in the backend catch-up plan.
      for (const l of lines) {
        add("recipe_lines", l.legacy_id);
        const i = add("ingredients", l.ingredient_legacy_id);
        add("units", l.unit_legacy_id);
        add("units", i.purchase_unit_legacy_id);
        add("ingredient_types", i.ingredient_type_legacy_id);
        add("ingredient_order_groups", i.ingredient_order_group_legacy_id);
      }
    }
  }
  for (const e of source.supplier_eligibilities.filter((e) =>
    records.ingredients.some((i) => i.legacy_id === e.ingredient_legacy_id),
  )) {
    add("supplier_eligibilities", e.legacy_id);
    add("suppliers", e.supplier_legacy_id);
  }
  for (const [entity, rows] of Object.entries(records)) {
    rows.sort((a, b) =>
      a.legacy_id < b.legacy_id ? -1 : a.legacy_id > b.legacy_id ? 1 : 0,
    );
    if (
      snapshot.source_diagnostics.some(
        (d) =>
          d.severity === "BLOCKER" &&
          d.entity === entity &&
          (!d.legacy_id || rows.some((r) => r.legacy_id === d.legacy_id)),
      )
    )
      throw new Error(`SOURCE_DEPENDENCY_BLOCKED:${entity}`);
  }
  const nullIds = new Set(
    snapshot.source_diagnostics
      .filter((d) => d.code === "INACTIVE_SCHOOL_DISPLAY_ORDER_DEFAULTED")
      .map((d) => d.legacy_id),
  );
  const lexical = new Intl.Collator("vi");
  const ordered = [...source.schools].sort(
    (a, b) =>
      (nullIds.has(a.legacy_id) ? Infinity : a.display_order) -
        (nullIds.has(b.legacy_id) ? Infinity : b.display_order) ||
      lexical.compare(a.school_name, b.school_name) ||
      a.legacy_id.localeCompare(b.legacy_id),
  );
  let tail = Math.max(
    0,
    ...source.schools
      .filter((s) => !nullIds.has(s.legacy_id))
      .map((s) => s.display_order),
  );
  const schoolOrders = ordered.map((s) => ({
    legacy_id: s.legacy_id,
    display_order: nullIds.has(s.legacy_id) ? ++tail : s.display_order,
  }));
  return { records, schoolOrders };
}

export function buildPlanningCatchupSql(
  snapshot,
  { targetProjectRef, apply = false, planChecksum, actorId } = {},
) {
  if (targetProjectRef !== "rnzxmxiiqgtdevzregff")
    throw new Error("EXACT_STAGING_TARGET_REQUIRED");
  assertPlanningSource(snapshot);
  if (
    apply &&
    (!/^[a-f0-9]{64}$/.test(planChecksum ?? "") ||
      !/^[a-f0-9-]{36}$/.test(actorId ?? ""))
  )
    throw new Error("REVIEWED_PLAN_AND_ACTOR_REQUIRED");
  let sql = readFileSync(
    new URL(
      "../supabase/packages/atlas-planning-master-catchup.sql",
      import.meta.url,
    ),
    "utf8",
  );
  if (!apply) {
    const call = "atlas_legacy.master_import_validate_values(";
    if (sql.split(call).length !== 2)
      throw new Error("CANDIDATE_VALIDATOR_CALL_CHANGED");
    const temporary = "pg_temp.planning_catchup_preview_validate_values";
    const definition = previewValidatorDefinition().replace(
      "atlas_legacy.master_import_validate_values",
      temporary,
    );
    sql = `${definition}\n${sql.replace(call, `${temporary}(`)}`;
  }
  const encoded = Buffer.from(JSON.stringify(snapshot)).toString("base64");
  return `\\warn CATCHUP_CLIENT_SCRIPT_BEGIN
set statement_timeout='15min';
set lock_timeout='30s';
set client_min_messages='notice';
set plan_cache_mode='force_generic_plan';
\\warn CATCHUP_CLIENT_SETTINGS_DONE
${sql}
\\warn CATCHUP_CLIENT_HELPERS_DONE
\\warn CATCHUP_CLIENT_QUERY_BEGIN
select pg_temp.run_planning_master_catchup(convert_from(decode('${encoded}','base64'),'UTF8')::jsonb,${apply},${apply ? `'${planChecksum}'` : "null"},${apply ? `'${actorId}'::uuid` : "null"}) as result;
\\warn CATCHUP_CLIENT_QUERY_DONE
`;
}

export function formatPlanningCatchupReport(plan) {
  const keys = [
    "SOURCE_SYSTEM",
    "OBJECT_TYPE",
    "LEGACY_ID",
    "SOURCE_NAME",
    "CURRENT_ATLAS_ID",
    "CURRENT_ATLAS_VALUE",
    "PROPOSED_ATLAS_ID",
    "ACTION",
    "DEPENDENCY_REASON",
  ];
  return (
    keys.join("\t") +
    "\n" +
    (plan.report ?? [])
      .map((r) =>
        keys
          .map((k) =>
            typeof r[k] === "object"
              ? canonicalMasterJson(r[k])
              : String(r[k] ?? "—").replace(/[\t\r\n]/g, " "),
          )
          .join("\t"),
      )
      .join("\n") +
    "\n"
  );
}
