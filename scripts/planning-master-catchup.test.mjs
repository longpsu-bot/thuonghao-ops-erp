// @vitest-environment node
import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import { checksumOpsV1MasterSnapshot } from "./ops-v1-master-snapshot-contract.mjs";
import {
  derivePlanningCatchup,
  buildPlanningCatchupSql,
  planningCatchupPreviewValidationPolicy,
  formatPlanningCatchupReport,
} from "./planning-master-catchup.mjs";

function fixture() {
  const records = Object.fromEntries(
    [
      "customers",
      "delivery_locations",
      "dish_types",
      "dishes",
      "ingredient_order_groups",
      "ingredient_types",
      "ingredients",
      "recipe_lines",
      "recipes",
      "school_types",
      "schools",
      "supplier_eligibilities",
      "suppliers",
      "units",
    ].map((k) => [k, []]),
  );
  records.schools = [
    { legacy_id: "33", school_name: "THUẬN AN - PHÂN HIỆU", display_order: 16 },
    { legacy_id: "11", school_name: "ĐẤT CUỐC", display_order: 0 },
  ];
  records.dishes = [
    {
      legacy_id: "9",
      dish_name: "Món mới",
      dish_status: "ACTIVE",
      dish_type_legacy_id: "1",
    },
    {
      legacy_id: "8",
      dish_name: "Món cũ",
      dish_status: "ACTIVE",
      dish_type_legacy_id: "1",
    },
  ];
  records.recipes = [
    {
      legacy_id: "dish:9:school-type:1",
      dish_legacy_id: "9",
      school_type_legacy_id: "1",
    },
  ];
  records.recipe_lines = [
    {
      legacy_id: "recipe:dish:9:school-type:1:ingredient:5",
      recipe_legacy_id: "dish:9:school-type:1",
      ingredient_legacy_id: "5",
      unit_legacy_id: "kg",
    },
  ];
  records.ingredients = [
    {
      legacy_id: "5",
      ingredient_name: "Mới",
      ingredient_type_legacy_id: "1",
      ingredient_order_group_legacy_id: "1",
      purchase_unit_legacy_id: "kg",
    },
  ];
  records.units = [{ legacy_id: "kg" }];
  records.dish_types = [{ legacy_id: "1" }];
  records.school_types = [{ legacy_id: "1" }];
  records.ingredient_types = [{ legacy_id: "1" }];
  records.ingredient_order_groups = [{ legacy_id: "1" }];
  records.suppliers = [{ legacy_id: "2" }];
  records.supplier_eligibilities = [
    {
      legacy_id: "ingredient:5:supplier:2",
      ingredient_legacy_id: "5",
      supplier_legacy_id: "2",
    },
  ];
  const s = {
    contract_version: "OPS-V1-MASTER-SNAPSHOT.v1",
    source_system: "OPS_V1",
    source_project_ref: "qnthofvccilhnefdcxnz",
    snapshot_id: "fixture",
    records,
    source_diagnostics: [
      {
        severity: "INFO",
        code: "INACTIVE_SCHOOL_DISPLAY_ORDER_DEFAULTED",
        entity: "schools",
        legacy_id: "11",
      },
    ],
    source_access: {
      role_name: "supabase_read_only_user",
      has_required_select: true,
      has_non_select_privilege: false,
      bypass_rls: true,
      superuser: false,
      create_role: false,
      create_db: false,
    },
  };
  return { ...s, snapshot_checksum: checksumOpsV1MasterSnapshot(s) };
}
const mappings = [
  {
    object_type: "DISH",
    legacy_id: "8",
    target_id: "00000000-0000-4000-8000-000000000008",
  },
];
describe("bounded Planning master closure", () => {
  it("limits an explicit Dish scope without trimming the signed source", () => {
    const s = fixture();
    s.records.dishes.push({ ...s.records.dishes[0], legacy_id: "10" });
    s.snapshot_checksum = checksumOpsV1MasterSnapshot(s);
    const original = structuredClone(s);
    expect(
      derivePlanningCatchup(s, mappings, ["9"]).records.dishes.map(
        (d) => d.legacy_id,
      ),
    ).toEqual(["9"]);
    expect(s).toEqual(original);
    for (const ids of [[], ["9", "9"], ["missing"], [9]]) {
      expect(() =>
        buildPlanningCatchupSql(s, {
          targetProjectRef: "rnzxmxiiqgtdevzregff",
          dishLegacyIds: ids,
        }),
      ).toThrow("CATCHUP_DISH_SCOPE_INVALID");
    }
    expect(
      buildPlanningCatchupSql(s, {
        targetProjectRef: "rnzxmxiiqgtdevzregff",
        dishLegacyIds: ["9"],
      }),
    ).toContain("'[\"9\"]'::jsonb");
  });
  it("derives only missing active dishes and exact dependencies", () => {
    const p = derivePlanningCatchup(fixture(), mappings);
    expect(p.records.dishes.map((x) => x.legacy_id)).toEqual(["9"]);
    expect(p.records.recipes).toHaveLength(1);
    expect(p.records.ingredients).toHaveLength(1);
    expect(p.records.suppliers).toHaveLength(1);
    expect(p.records.supplier_eligibilities).toHaveLength(1);
    expect(p.records.customers).toEqual([]);
  });
  it("imports supplier decisions only for new Ingredients", () => {
    const s = fixture();
    s.records.ingredients.push({ ...s.records.ingredients[0], legacy_id: "6" });
    s.records.recipe_lines.push({
      ...s.records.recipe_lines[0],
      legacy_id: "recipe:dish:9:school-type:1:ingredient:6",
      ingredient_legacy_id: "6",
    });
    s.records.suppliers.push({ legacy_id: "3" });
    s.records.supplier_eligibilities.push({
      legacy_id: "ingredient:6:supplier:3",
      ingredient_legacy_id: "6",
      supplier_legacy_id: "3",
    });
    s.snapshot_checksum = checksumOpsV1MasterSnapshot(s);
    const existing = [
      ...mappings,
      { object_type: "INGREDIENT", legacy_id: "5" },
    ];
    const p = derivePlanningCatchup(s, existing);
    expect(p.records.ingredients.map((i) => i.legacy_id)).toEqual(["5", "6"]);
    expect(p.records.supplier_eligibilities.map((e) => e.legacy_id)).toEqual([
      "ingredient:6:supplier:3",
    ]);
    expect(p.records.suppliers.map((r) => r.legacy_id)).toEqual(["3"]);
    const allExisting = derivePlanningCatchup(s, [
      ...existing,
      { object_type: "INGREDIENT", legacy_id: "6" },
    ]);
    expect(allExisting.records.supplier_eligibilities).toEqual([]);
    expect(allExisting.records.suppliers).toEqual([]);
  });
  it("preserves empty 2034 and 2041 roots without copying 2036 or synthesizing Ingredient 1204", () => {
    const s = fixture();
    s.records.dishes = [
      {
        legacy_id: "2034",
        dish_name: "Cá basa phi lê sốt me + thịt heo kho tiêu",
      },
      {
        legacy_id: "2036",
        dish_name: "Cá basa phi lê sốt me + thịt heo kho tiêu (THĐ)",
      },
      { legacy_id: "2041", dish_name: "Bánh bông lan kem Thiên Ân 40g" },
    ].map((d) => ({ ...d, dish_type_legacy_id: "1", dish_status: "ACTIVE" }));
    const identities = [
      ["2034", "1", "3456"],
      ["2034", "2", "3457"],
      ["2036", "1", "3460"],
      ["2041", "1", "3468"],
      ["2041", "2", "3469"],
    ];
    s.records.school_types.push({ legacy_id: "2" });
    s.records.recipes = identities.map(([dish, school, source]) => ({
      legacy_id: `dish:${dish}:school-type:${school}`,
      source_record_id: source,
      dish_legacy_id: dish,
      school_type_legacy_id: school,
      recipe_status: "ACTIVE",
      basis_portions: 100,
    }));
    s.records.recipe_lines = [
      {
        ...s.records.recipe_lines[0],
        legacy_id: "recipe:dish:2036:school-type:1:ingredient:5",
        recipe_legacy_id: "dish:2036:school-type:1",
        quantity_per_basis: "100",
      },
    ];
    s.records.ingredients.push({
      ...s.records.ingredients[0],
      legacy_id: "1204",
      ingredient_name: "Bánh bông lan kem Thiên Ân 40g",
    });
    s.source_diagnostics.push(
      ...s.records.recipes
        .filter((r) => r.dish_legacy_id !== "2036")
        .map((r) => ({
          severity: "INFO",
          code: "SOURCE_RECIPE_EMPTY",
          entity: "recipes",
          legacy_id: r.legacy_id,
          field: "composition",
          detail: r.source_record_id,
        })),
    );
    s.snapshot_checksum = checksumOpsV1MasterSnapshot(s);
    const plan = derivePlanningCatchup(s, []);
    expect(plan.records.recipes).toEqual(s.records.recipes);
    expect(plan.records.recipe_lines).toEqual(s.records.recipe_lines);
    expect(plan.records.ingredients.map((r) => r.legacy_id)).toEqual(["5"]);
    expect(
      plan.records.recipes
        .filter((r) => r.dish_legacy_id !== "2036")
        .map((r) => r.source_record_id),
    ).toEqual(["3456", "3457", "3468", "3469"]);
    expect(derivePlanningCatchup(s, [])).toEqual(plan);
    expect(
      derivePlanningCatchup(
        s,
        s.records.dishes.map((d) => ({
          object_type: "DISH",
          legacy_id: d.legacy_id,
        })),
      ).records.recipes,
    ).toEqual([]);
  });
  it.each(["MISSING_DISH", "UNSUPPORTED_SCHOOL_RECIPE"])(
    "keeps invalid empty Recipe references blocked: %s",
    (code) => {
      const s = fixture();
      s.records.recipe_lines = [];
      s.source_diagnostics.push({
        severity: "BLOCKER",
        code,
        entity: "recipes",
        legacy_id: "dish:9:school-type:1",
      });
      s.snapshot_checksum = checksumOpsV1MasterSnapshot(s);
      expect(() => derivePlanningCatchup(s, mappings)).toThrow(
        "SOURCE_DEPENDENCY_BLOCKED:recipes",
      );
    },
  );
  it("does not confuse a missing Recipe with an empty typed root", () => {
    const s = fixture();
    s.records.recipes = [];
    s.snapshot_checksum = checksumOpsV1MasterSnapshot(s);
    expect(() => derivePlanningCatchup(s, mappings)).toThrow(
      "MISSING_RECIPE:9",
    );
  });
  it("keeps invalid nonpositive source lines blocked rather than treating them as empty composition", () => {
    const s = fixture();
    s.records.recipe_lines[0].quantity_per_basis = "0";
    s.source_diagnostics.push({
      severity: "BLOCKER",
      code: "INVALID_QUANTITY",
      entity: "recipe_lines",
      legacy_id: s.records.recipe_lines[0].legacy_id,
    });
    s.snapshot_checksum = checksumOpsV1MasterSnapshot(s);
    expect(() => derivePlanningCatchup(s, mappings)).toThrow(
      "SOURCE_DEPENDENCY_BLOCKED:recipe_lines",
    );
  });
  it("still blocks an empty Recipe with a missing School Type", () => {
    const s = fixture();
    s.records.recipe_lines = [];
    s.records.school_types = [];
    s.snapshot_checksum = checksumOpsV1MasterSnapshot(s);
    expect(() => derivePlanningCatchup(s, mappings)).toThrow(
      "MISSING_DEPENDENCY:school_types:1",
    );
  });
  it("retains all empty Recipe source IDs in the original nine report columns", () => {
    const roots = [
      ["dish:2034:school-type:1", "3456"],
      ["dish:2034:school-type:2", "3457"],
      ["dish:2041:school-type:1", "3468"],
      ["dish:2041:school-type:2", "3469"],
    ];
    const report = formatPlanningCatchupReport({
      report: roots.map(([key, id]) => ({
        SOURCE_SYSTEM: "OPS_V1",
        OBJECT_TYPE: "RECIPE",
        LEGACY_ID: key,
        SOURCE_RECIPE_ID: id,
        SOURCE_NAME: key,
        ACTION: "CREATE",
        DEPENDENCY_REASON: `SOURCE_RECIPE_EMPTY: source_recipe_id=${id}; root only; RECIPE_NOT_READY; no released composition`,
      })),
    });
    const [header, ...rows] = report
      .trim()
      .split("\n")
      .map((line) => line.split("\t"));
    expect(header).toEqual([
      "SOURCE_SYSTEM",
      "OBJECT_TYPE",
      "LEGACY_ID",
      "SOURCE_NAME",
      "CURRENT_ATLAS_ID",
      "CURRENT_ATLAS_VALUE",
      "PROPOSED_ATLAS_ID",
      "ACTION",
      "DEPENDENCY_REASON",
    ]);
    expect(rows).toHaveLength(4);
    for (const [index, row] of rows.entries()) {
      expect(row).toHaveLength(9);
      expect(row[2]).toBe(roots[index][0]);
      expect(row[8]).toContain(`source_recipe_id=${roots[index][1]}`);
      expect(row[8]).toContain("SOURCE_RECIPE_EMPTY");
      expect(row[8]).toContain("RECIPE_NOT_READY");
    }
  });
  it("maps NULL-source School orders to deterministic tail", () => {
    expect(derivePlanningCatchup(fixture(), mappings).schoolOrders).toEqual([
      { legacy_id: "33", display_order: 16 },
      { legacy_id: "11", display_order: 17 },
    ]);
  });
  it("blocks missing ingredients before planning recipes", () => {
    const s = fixture();
    s.records.ingredients = [];
    s.snapshot_checksum = checksumOpsV1MasterSnapshot(s);
    expect(() => derivePlanningCatchup(s, mappings)).toThrow(
      "MISSING_DEPENDENCY:ingredients:5",
    );
  });
  it("requires a read-only, checksum-bound immutable source", () => {
    const s = fixture();
    s.records.dishes[0].dish_name = "drift";
    expect(() => derivePlanningCatchup(s, mappings)).toThrow(
      "SNAPSHOT_CHECKSUM",
    );
    const t = fixture();
    t.source_access.has_non_select_privilege = true;
    t.snapshot_checksum = checksumOpsV1MasterSnapshot(t);
    expect(() => derivePlanningCatchup(t, mappings)).toThrow(
      "SOURCE_NOT_PROVEN_READ_ONLY",
    );
  });
  it("rejects ambiguous typed source mappings", () => {
    expect(() =>
      derivePlanningCatchup(fixture(), [...mappings, ...mappings]),
    ).toThrow("DUPLICATE_TYPED_MAPPING");
  });
  it("only builds SQL for exact Staging and requires reviewed apply checksums", () => {
    const s = fixture();
    expect(() =>
      buildPlanningCatchupSql(s, { targetProjectRef: "qnthofvccilhnefdcxnz" }),
    ).toThrow("EXACT_STAGING_TARGET");
    expect(() =>
      buildPlanningCatchupSql(s, {
        targetProjectRef: "rnzxmxiiqgtdevzregff",
        apply: true,
      }),
    ).toThrow("REVIEWED_PLAN");
  });
  it("enables connection checks only for the optional diagnostic preview", () => {
    const snapshot = fixture();
    const options = { targetProjectRef: "rnzxmxiiqgtdevzregff" };
    const normal = buildPlanningCatchupSql(snapshot, options);
    expect(normal).not.toContain("client_connection_check_interval");
    expect(
      buildPlanningCatchupSql(snapshot, {
        ...options,
        diagnosticBoundary: false,
      }),
    ).toBe(normal);
    const diagnostic = buildPlanningCatchupSql(snapshot, {
      ...options,
      diagnosticBoundary: true,
    });
    const setting = "set client_connection_check_interval='2s';\n";
    expect(diagnostic.split(setting)).toHaveLength(2);
    expect(diagnostic.replace(setting, "")).toBe(normal);
    expect(diagnostic.indexOf(setting)).toBeLessThan(
      diagnostic.indexOf("CATCHUP_CLIENT_SETTINGS_DONE"),
    );
    expect(diagnostic.indexOf(setting)).toBeLessThan(
      diagnostic.indexOf(
        "create or replace function pg_temp.planning_catchup_scope",
      ),
    );
  });
  it("rejects diagnostic apply before validating or encoding source data", () => {
    expect(() =>
      buildPlanningCatchupSql(null, {
        targetProjectRef: "rnzxmxiiqgtdevzregff",
        apply: true,
        diagnosticBoundary: true,
        planChecksum: "a".repeat(64),
        actorId: "ee120000-0000-4000-8000-000000000001",
      }),
    ).toThrow("DIAGNOSTIC_BOUNDARY_PREVIEW_ONLY");
  });
  it("models only the exact candidate validator in temporary preview scope", () => {
    const migration = readFileSync(
      new URL(
        "../supabase/migrations/20261011162800_atlas_planning_tui_count_unit.sql",
        import.meta.url,
      ),
      "utf8",
    );
    const definition = migration
      .replace(/\r\n/g, "\n")
      .match(
        /CREATE OR REPLACE FUNCTION atlas_legacy\.master_import_validate_values[\s\S]*?end \$function\$\s*;/i,
      )[0];
    const sql = buildPlanningCatchupSql(fixture(), {
      targetProjectRef: "rnzxmxiiqgtdevzregff",
    });
    expect(sql).toContain(
      definition.replace(
        "atlas_legacy.master_import_validate_values",
        "pg_temp.planning_catchup_preview_validate_values",
      ),
    );
    expect(sql).not.toMatch(
      /create or replace function atlas_legacy\.master_import_validate_values/i,
    );
    expect(sql).not.toMatch(/set role atlas_owner|reset role/i);
    expect(sql).not.toContain("atlas_legacy.master_import_validate_values(");
    expect(sql).toContain("pg_temp.planning_catchup_preview_validate_values(");
    expect(planningCatchupPreviewValidationPolicy()).toMatchObject({
      mode: "SESSION_LOCAL_CANDIDATE",
      migration_version: "20261011162800",
      definition_checksum: expect.stringMatching(/^[a-f0-9]{64}$/),
    });
  });
  it("uses deployed authoritative validation for apply without a candidate overlay", () => {
    const sql = buildPlanningCatchupSql(fixture(), {
      targetProjectRef: "rnzxmxiiqgtdevzregff",
      apply: true,
      planChecksum: "a".repeat(64),
      actorId: "ee120000-0000-4000-8000-000000000001",
    });
    expect(sql).toContain("atlas_legacy.master_import_validate_values(");
    expect(sql).not.toContain("planning_catchup_preview_validate_values");
  });
  it("emits fixed psql boundaries around settings, helpers and the final query", () => {
    const sql = buildPlanningCatchupSql(fixture(), {
      targetProjectRef: "rnzxmxiiqgtdevzregff",
    });
    expect(sql.match(/^\\warn .*$/gm)).toEqual([
      "\\warn CATCHUP_CLIENT_SCRIPT_BEGIN",
      "\\warn CATCHUP_CLIENT_SETTINGS_DONE",
      "\\warn CATCHUP_CLIENT_HELPERS_DONE",
      "\\warn CATCHUP_CLIENT_QUERY_BEGIN",
      "\\warn CATCHUP_CLIENT_QUERY_DONE",
    ]);
    expect(sql.indexOf("CATCHUP_CLIENT_SCRIPT_BEGIN")).toBeLessThan(
      sql.indexOf("set statement_timeout='15min'"),
    );
    expect(sql.indexOf("set lock_timeout='30s'")).toBeLessThan(
      sql.indexOf("CATCHUP_CLIENT_SETTINGS_DONE"),
    );
    expect(sql.indexOf("CATCHUP_CLIENT_SETTINGS_DONE")).toBeLessThan(
      sql.indexOf("create or replace function pg_temp.planning_catchup_scope"),
    );
    expect(sql.indexOf("CATCHUP_CLIENT_HELPERS_DONE")).toBeGreaterThan(
      sql.indexOf(
        "create or replace function pg_temp.run_planning_master_catchup",
      ),
    );
    expect(sql.indexOf("CATCHUP_CLIENT_QUERY_BEGIN")).toBeLessThan(
      sql.indexOf("select pg_temp.run_planning_master_catchup(convert_from"),
    );
    expect(sql.trim()).toMatch(/\\warn CATCHUP_CLIENT_QUERY_DONE$/);
  });
  it.each([false, true])(
    "pins generic plans only in the catchup session for apply=%s",
    (apply) => {
      const sql = buildPlanningCatchupSql(fixture(), {
        targetProjectRef: "rnzxmxiiqgtdevzregff",
        apply,
        planChecksum: "a".repeat(64),
        actorId: "ee120000-0000-4000-8000-000000000001",
      });
      expect(
        sql.match(/set plan_cache_mode='force_generic_plan';/g),
      ).toHaveLength(1);
      expect(
        sql.indexOf("set plan_cache_mode='force_generic_plan';"),
      ).toBeLessThan(sql.indexOf("CATCHUP_CLIENT_SETTINGS_DONE"));
      expect(sql.indexOf("CATCHUP_CLIENT_SETTINGS_DONE")).toBeLessThan(
        sql.indexOf(
          "create or replace function pg_temp.planning_catchup_scope",
        ),
      );
      expect(sql).not.toMatch(
        /alter\s+(?:role|database|function)[\s\S]*plan_cache_mode/i,
      );
    },
  );
  it("projects only internal working metadata after retaining the complete signed input", () => {
    const snapshot = fixture();
    snapshot.source_fingerprints = { fixture: "original fingerprints" };
    snapshot.unit_alias_evidence = [{ original: "aliases remain evidence" }];
    snapshot.snapshot_checksum = checksumOpsV1MasterSnapshot(snapshot);
    const sql = buildPlanningCatchupSql(snapshot, {
      targetProjectRef: "rnzxmxiiqgtdevzregff",
    });
    const encoded = sql.match(/convert_from\(decode\('([^']+)','base64'\)/)[1];
    expect(JSON.parse(Buffer.from(encoded, "base64").toString("utf8"))).toEqual(
      snapshot,
    );
    const scope = sql.match(
      /create or replace function pg_temp\.planning_catchup_scope[\s\S]*?end \$\$;/,
    )[0];
    expect(scope).toContain(
      "return jsonb_build_object('records',scoped,'snapshot_id',snapshot->'snapshot_id','snapshot_checksum',snapshot->'snapshot_checksum','exported_at',snapshot->'exported_at','catchup_dish_ids',dish_ids);",
    );
    expect(scope).not.toContain("return snapshot||");
    expect(
      sql.indexOf(
        "atlas_legacy.master_snapshot_hash(snapshot-'snapshot_checksum')",
      ),
    ).toBeLessThan(
      sql.indexOf(
        "scoped:=pg_temp.planning_catchup_scope(snapshot,coalesce(prior.reconciliation",
      ),
    );
    expect(sql).toContain(
      "jsonb_array_elements(snapshot->'source_diagnostics')",
    );
    expect(sql).toContain(
      "jsonb_array_elements(snapshot#>'{records,schools}')",
    );
    expect(sql).toContain("snapshot->'source_counts'");
  });
  it("uses only literal SQLSTATE notices after critical planner and hash boundaries", () => {
    const sql = readFileSync(
      new URL(
        "../supabase/packages/atlas-planning-master-catchup.sql",
        import.meta.url,
      ),
      "utf8",
    );
    expect(
      [
        ...sql.matchAll(
          /raise notice using errcode='(PZ\d{3})',message='([^']+)'/g,
        ),
      ]
        .map((m) => [m[1], m[2]])
        .sort(),
    ).toEqual([
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
    for (const [marker, predecessor] of [
      ["SOURCE_CHECKED", "DUPLICATE_SOURCE_IDENTITY"],
      [
        "RECIPE_PLAN_DONE",
        "extension:=atlas_legacy.master_import_recipe_plan(composed);",
      ],
      [
        "PROTECTED_DONE",
        "protected_value:=pg_temp.planning_catchup_protected(actions);",
      ],
      ["MAPPING_HASH_DONE", "mapping_fp:=atlas_legacy.master_snapshot_hash("],
      ["PLAN_HASH_DONE", "plan_fp:=atlas_legacy.master_snapshot_hash(plan);"],
      [
        "SCOPE_DONE",
        "scoped:=pg_temp.planning_catchup_scope(snapshot,coalesce(prior.reconciliation->'catchup_dish_ids',requested_scope));",
      ],
      [
        "DEPENDENCIES_DONE",
        "'dependency_reason','Missing Dish dependency closure'",
      ],
      [
        "EMPTY_ROOTS_DONE",
        "empty_roots:=pg_temp.planning_catchup_empty_roots(scoped);",
      ],
      ["RECIPE_INPUT_READY", "select jsonb_set(scoped,'{records,recipes}'"],
    ])
      expect(sql.indexOf(`CATCHUP_SERVER_${marker}`)).toBeGreaterThan(
        sql.indexOf(predecessor),
      );
    expect(sql.indexOf("CATCHUP_SERVER_SCOPE_DONE")).toBeLessThan(
      sql.indexOf("CATCHUP_SERVER_DEPENDENCIES_DONE"),
    );
    expect(sql.indexOf("CATCHUP_SERVER_DEPENDENCIES_DONE")).toBeLessThan(
      sql.indexOf("empty_roots:=pg_temp.planning_catchup_empty_roots(scoped);"),
    );
    expect(sql.indexOf("CATCHUP_SERVER_EMPTY_ROOTS_DONE")).toBeLessThan(
      sql.indexOf("CATCHUP_SERVER_RECIPE_INPUT_READY"),
    );
    expect(sql.indexOf("CATCHUP_SERVER_RECIPE_INPUT_READY")).toBeLessThan(
      sql.indexOf(
        "extension:=atlas_legacy.master_import_recipe_plan(composed);",
      ),
    );
  });
});
