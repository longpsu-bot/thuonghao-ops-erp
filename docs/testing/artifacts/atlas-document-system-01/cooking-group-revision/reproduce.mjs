import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync, writeFileSync, readdirSync } from "node:fs";
import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  catalogVerificationSql,
  readCatalogAuthority,
} from "../../../../../scripts/verify-atlas-staging.mjs";
import { redactAtlasStagingDiagnostic } from "../../../../../scripts/atlas-staging-contract.mjs";

const directory = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(directory, "../../../../..");
const container = "supabase_db_atlas-document-system-360-cooking";
const mode = process.argv[2];
assert.ok(["1", "2", "compare"].includes(mode));
assert.ok(
  !process.argv[3] || ["--evidence-only", "--resume"].includes(process.argv[3]),
);
const read = (file) => readFileSync(path.join(root, file), "utf8");
const digest = (value) => createHash("sha256").update(value).digest("hex");
const suites = [
  ...new Set([
    "need_generation_operational_scale.sql",
    ...JSON.parse(
      read(
        "docs/testing/artifacts/atlas-backend-convergence-02b/sql-regressions.json",
      ),
    ).map((row) => row.suite),
    "master_data_rehearsal_import.sql",
    "master_data_rehearsal_recipe_import.sql",
    "rmvp_01_atlas_master_data.sql",
    "rmvp_02b_recipe_adjustments_effective_bom.sql",
    "atlas_shopping_list_export_read.sql",
    "atlas_school_cooking_groups.sql",
    "school_catering_purchase_orders.sql",
    "school_dispatch_release.sql",
    "procurement_supplier_line_note.sql",
  ]),
];
function verifySuites(rows) {
  assert.deepEqual(
    rows.map((row) => row.suite),
    suites,
  );
  assert.ok(
    rows.every(
      (row) =>
        row.exit === 0 &&
        /^1\.\.[1-9]\d*$/.test(row.plan) &&
        /^[a-f0-9]{64}$/.test(row.assertions_sha256),
    ),
  );
}
function normalizeSnapshots(business) {
  for (const value of Object.values(business)) {
    for (const key of ["po_snapshots", "pxk_snapshots"]) {
      value[key]?.sort((a, b) =>
        JSON.stringify(a).localeCompare(JSON.stringify(b), "en"),
      );
    }
  }
  return business;
}
function save(file, value) {
  writeFileSync(
    path.join(directory, file),
    JSON.stringify(value, null, 2) + "\n",
  );
}
function sql(source) {
  const result = spawnSync(
    "docker",
    [
      "exec",
      "-i",
      container,
      "psql",
      "-X",
      "-qAt",
      "-v",
      "ON_ERROR_STOP=1",
      "-U",
      "postgres",
      "-d",
      "postgres",
    ],
    { input: source, encoding: "utf8", maxBuffer: 32 * 1024 * 1024 },
  );
  assert.equal(result.status, 0, redactAtlasStagingDiagnostic(result.stderr));
  assert.doesNotMatch(result.stdout, /^not ok\b/m);
  return result.stdout.replaceAll("\r\n", "\n");
}
function expand(file) {
  const absolute = path.resolve(root, file);
  assert.ok(absolute.startsWith(path.join(root, "supabase") + path.sep));
  return read(file).replace(/^\\ir\s+(.+)$/gm, (_, included) =>
    expand(path.join(path.dirname(file), included.trim())),
  );
}

if (mode === "compare") {
  save("comparison.json", {
    status: "NOT_RUN",
    reason: "Comparison preflight incomplete",
  });
  assert.equal(process.env.ATLAS_LOCAL_DB_CONTAINER, container);
  const first = JSON.parse(readFileSync(path.join(directory, "cycle-1.json")));
  const second = JSON.parse(readFileSync(path.join(directory, "cycle-2.json")));
  for (const cycle of [first, second]) {
    assert.equal(cycle.catalog_verifier, "PASS");
    assert.equal(cycle.bootstrap.reset_exit, 0);
    assert.equal(cycle.bootstrap.seeds_enabled, false);
    assert.equal(cycle.bootstrap.project, "atlas-document-system-360-cooking");
    assert.equal(cycle.migrations.length, 95);
    verifySuites(cycle.suites);
    assert.equal(Object.keys(cycle.business).length, 4);
    normalizeSnapshots(cycle.business);
  }
  const differences = [
    ...new Set([...Object.keys(first), ...Object.keys(second)]),
  ].filter((key) => JSON.stringify(first[key]) !== JSON.stringify(second[key]));
  save("comparison.json", {
    status: differences.length ? "FAIL" : "PASS",
    differences,
    compared: Object.keys(first),
  });
  assert.deepEqual(differences, []);
  console.log(
    "Both clean cycles: exact migration/catalog and semantic contract evidence PASS",
  );
} else {
  const previous = process.argv[3]
    ? JSON.parse(readFileSync(path.join(directory, `cycle-${mode}.json`)))
    : {};
  save(`cycle-${mode}.json`, {});
  assert.equal(process.env.ATLAS_LOCAL_DB_CONTAINER, container);
  const evidence = process.argv[3]
    ? { suites: previous.suites.filter((row) => row.exit === 0) }
    : {};
  if (process.argv[3] === "--evidence-only") {
    verifySuites(evidence.suites);
  } else if (process.argv[3] === "--resume") {
    assert.deepEqual(
      evidence.suites.map((row) => row.suite),
      suites.slice(0, evidence.suites.length),
    );
  }
  save(`cycle-${mode}.json`, evidence);
  evidence.migrations = JSON.parse(
    sql(
      "select jsonb_agg(jsonb_build_object('version',version,'name',name) order by version) from supabase_migrations.schema_migrations;",
    ),
  );
  const repository = readdirSync(path.join(root, "supabase/migrations"))
    .filter((file) => file.endsWith(".sql"))
    .sort()
    .map((file) => ({ version: file.slice(0, 14), name: file.slice(15, -4) }));
  assert.deepEqual(evidence.migrations, repository);
  const bootstrap = JSON.parse(
    readFileSync(path.join(directory, `reset-${mode}.json`)),
  );
  evidence.bootstrap = {
    project: bootstrap.project,
    reset_exit: bootstrap.reset_exit,
    seeds_enabled: bootstrap.seeds_enabled,
    command: bootstrap.command,
  };
  const catalog = sql(
    read("docs/testing/artifacts/atlas-backend-convergence-02c/catalog.sql"),
  );
  writeFileSync(
    path.join(
      process.env.TEMP,
      "atlas-document-system-360-cooking",
      `effective-catalog-${mode}.tsv`,
    ),
    catalog,
  );
  evidence.catalog_sha256 = digest(catalog);
  const additional = JSON.parse(
    sql(readFileSync(path.join(directory, "catalog-extra.sql"), "utf8")),
  );
  writeFileSync(
    path.join(
      process.env.TEMP,
      "atlas-document-system-360-cooking",
      `catalog-extra-${mode}.json`,
    ),
    JSON.stringify(additional, null, 2),
  );
  evidence.additional_catalog = Object.fromEntries(
    Object.entries(additional).map(([key, rows]) => [
      key,
      { count: rows?.length ?? 0, sha256: digest(JSON.stringify(rows)) },
    ]),
  );
  sql(
    `begin transaction read only;${catalogVerificationSql(readCatalogAuthority(root))} rollback;`,
  );
  evidence.catalog_verifier = "PASS";
  save(`cycle-${mode}.json`, evidence);
  console.log(
    `Cycle ${mode}: migration names/versions and current95 effective catalog PASS`,
  );

  // Run scale alone first; keep its unchanged production timeout and assertions.
  evidence.suites ??= [];
  const pendingSuites =
    process.argv[3] === "--evidence-only"
      ? []
      : suites.slice(evidence.suites.length);
  for (const suite of pendingSuites) {
    // These import suites rely on the CLI pgTAP session preamble. Supply the
    // same extension/search-path prerequisite inside their rolled-back tests.
    const importSuite = suite.startsWith("master_data_rehearsal_");
    const result = importSuite
      ? {
          status: 0,
          stdout: sql(
            expand(`supabase/tests/${suite}`).replace(
              /^begin;/m,
              "begin; create extension if not exists pgtap with schema extensions; set search_path=extensions,public,pg_catalog;",
            ),
          ),
          stderr: "",
        }
      : spawnSync(
          process.execPath,
          [path.join(root, "scripts/test-local-purchase-review.mjs"), suite],
          {
            cwd: root,
            env: process.env,
            encoding: "utf8",
            maxBuffer: 16 * 1024 * 1024,
          },
        );
    const output = result.stdout ?? "";
    const assertions = output
      .split(/\r?\n/)
      .filter((line) => /^(?:ok|not ok) \d+\b/.test(line));
    const plan = /^1\.\.(\d+)$/m.exec(output);
    const row = {
      suite,
      exit: result.status,
      plan: plan?.[0] ?? null,
      assertions_sha256: digest(assertions.join("\n")),
    };
    evidence.suites.push(row);
    save(`cycle-${mode}.json`, evidence);
    writeFileSync(
      path.join(
        process.env.TEMP,
        "atlas-document-system-360-cooking",
        `cycle-${mode}-${suite}.log`,
      ),
      redactAtlasStagingDiagnostic(output + result.stderr),
    );
    console.log(JSON.stringify({ suite, exit: row.exit, plan: row.plan }));
    assert.equal(
      result.status,
      0,
      redactAtlasStagingDiagnostic(output + result.stderr),
    );
    assert.ok(plan);
    assert.equal(assertions.length, Number(plan[1]));
    assert.doesNotMatch(output, /^not ok\b/m);
  }
  // Reuse complete fixtures unchanged; append stable business-key projections
  // before their final rollback, rather than comparing volatile generated IDs.
  evidence.business = {};
  for (const [suite, table] of [
    ["purchase_review_confirm_release.sql", "review_results"],
    ["school_dispatch_release.sql", "pxk_results"],
    ["master_data_rehearsal_recipe_import.sql", "evidence"],
    ["atlas_school_cooking_groups.sql", "cg_results"],
  ]) {
    const projection = readFileSync(
      path.join(directory, "semantic-evidence.sql"),
      "utf8",
    )
      .replaceAll("RESULT_TABLE", table)
      .replaceAll("RESULT_NAME", table === "evidence" ? "label" : "name")
      .replaceAll(
        "RESULT_RESPONSE",
        table === "evidence" ? "result" : "response",
      );
    let source = expand(`supabase/tests/${suite}`);
    if (table === "evidence")
      source = source.replace(
        /^begin;/m,
        "begin; create extension if not exists pgtap with schema extensions; set search_path=extensions,public,pg_catalog;",
      );
    assert.match(source, /rollback;\s*$/);
    const output = sql(
      source.replace(/rollback;\s*$/, `${projection}\nrollback;`),
    );
    const line = output
      .split("\n")
      .find((item) => item.startsWith("02D_SEMANTICS="));
    assert.ok(line, suite);
    evidence.business[suite] = JSON.parse(line.slice("02D_SEMANTICS=".length));
    normalizeSnapshots(evidence.business);
    save(`cycle-${mode}.json`, evidence);
  }
  console.log(
    `Cycle ${mode}: ${evidence.suites.length} existing suites and business evidence PASS`,
  );
}
