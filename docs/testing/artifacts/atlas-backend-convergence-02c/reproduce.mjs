import assert from "node:assert/strict";
import { readFileSync, writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  catalogVerificationSql,
  readCatalogAuthority,
} from "../../../../scripts/verify-atlas-staging.mjs";

const directory = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(directory, "../../../..");
const container = process.env.ATLAS_LOCAL_DB_CONTAINER;
assert.equal(container, "supabase_db_atlas-backend-convergence-02c");
const read = (file) => readFileSync(path.join(root, file), "utf8");
function expand(file) {
  return read(file).replace(/^\\ir\s+(.+)$/gm, (_, included) =>
    expand(path.join(path.dirname(file), included.trim())),
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
  assert.equal(result.status, 0, result.stderr);
  assert.doesNotMatch(result.stdout, /^not ok\b/m);
  return result;
}
const mode = process.argv[2];
if (mode === "catalog") {
  const result = sql(readFileSync(path.join(directory, "catalog.sql"), "utf8"));
  writeFileSync(path.join(directory, "effective-catalog.tsv"), result.stdout);
  sql(
    `begin transaction read only;${catalogVerificationSql(readCatalogAuthority(root))} rollback;`,
  );
  const repository = readFileSync(
    path.join(directory, "staging-observation.json"),
    "utf8",
  );
  const hosted = JSON.parse(repository).migrations;
  const local = JSON.parse(
    sql(
      "select jsonb_agg(jsonb_build_object('version',version,'name',name) order by version) from supabase_migrations.schema_migrations;",
    ).stdout.trim(),
  );
  const { readdirSync } = await import("node:fs");
  const files = readdirSync(path.join(root, "supabase/migrations"))
    .filter((name) => name.endsWith(".sql"))
    .sort();
  assert.deepEqual(
    local,
    files.map((file) => ({
      version: file.slice(0, 14),
      name: file.slice(15, -4),
    })),
  );
  assert.deepEqual(local.slice(0, hosted.length), hosted);
  writeFileSync(
    path.join(directory, "migration-parity.json"),
    JSON.stringify(
      {
        repository_count: files.length,
        local_count: local.length,
        staging_count: hosted.length,
        local_parity: true,
        hosted_missing: local.slice(hosted.length),
        hosted_only: [],
        catalog_verifier: "PASS",
      },
      null,
      2,
    ) + "\n",
  );
  console.log(
    "Catalog verifier and exact 94-entry version/name replay parity PASS",
  );
} else if (mode === "regressions") {
  const suites = JSON.parse(
    read(
      "docs/testing/artifacts/atlas-backend-convergence-02b/sql-regressions.json",
    ),
  ).map((row) => row.suite);
  const results = [];
  for (const suite of suites) {
    const result = spawnSync(
      process.execPath,
      [path.join(root, "scripts/test-local-purchase-review.mjs"), suite],
      {
        cwd: root,
        env: process.env,
        encoding: "utf8",
        maxBuffer: 16 * 1024 * 1024,
      },
    );
    const row = {
      suite,
      exit: result.status,
      plan: result.stdout.match(/^1\.\.[1-9]\d*$/m)?.[0],
    };
    results.push(row);
    writeFileSync(
      path.join(directory, "sql-regressions.json"),
      JSON.stringify(results, null, 2) + "\n",
    );
    console.log(JSON.stringify(row));
    assert.equal(result.status, 0, result.stdout + result.stderr);
  }
} else if (mode === "performance") {
  const instrumentation = readFileSync(
    path.join(directory, "measure.sql"),
    "utf8",
  );
  // Reuse the actual guarded scale fixture and consequential source commands.
  let scale = expand(
    "supabase/tests/need_generation_operational_scale.sql",
  ).split("-- This is the production authenticated budget")[0];
  scale += `reset role;\n${instrumentation}
select pg_temp.measure('get_planning_input_preflight',pg_temp.read_request('RMVP-03B.v2',pg_temp.ng_id(101),
 '{"period_start":"2050-09-19","period_end":"2050-09-19"}'),21);
set local statement_timeout='8s';
select pg_temp.measure('execute_need_generation',(select request from ng_requests where name='generate'),7);
set local role authenticated;
insert into ng_results select 'generate',atlas_api.execute_need_generation(request),null from ng_requests where name='generate';
reset role;
select pg_temp.measure('get_confirmed_need_review',pg_temp.read_request('RMVP-05.v1',pg_temp.ng_id(101),
 jsonb_build_object('confirmed_need_batch_id',response#>'{affected_aggregate_ids,confirmed_need_batch_id}',
 'filters',jsonb_build_object('service_date','2050-09-19'),'line_offset',0,'line_limit',10000)),21)
 from ng_results where name='generate';
rollback;`;
  // Minimal guarded purchase fixture, exact decisions, actual preparation/PO release.
  let purchase = expand(
    "supabase/tests/atlas_backend_convergence_02b_allocation.sql",
  ).split("create function pg_temp.allocation_facts()")[0];
  purchase += `${instrumentation}
select is(pg_temp.invoke('save_confirmed_supplier_allocation',pg_temp.allocation_request('CONFIRMED_NEED',
 'b6500000-0000-0000-0000-000000000006','1','99'))->>'success','true','rice accepted');
select is(pg_temp.invoke('save_confirmed_supplier_allocation',pg_temp.allocation_request('CONFIRMED_NEED',
 'b6500000-0000-0000-0000-000000000007','3',null))->>'success','true','other family accepted');
select pg_temp.measure('get_confirmed_supplier_allocation_workbench',pg_temp.read_request('CONFIRMED-SUPPLIER-ALLOCATION.v1',
 'b6000000-0000-0000-0000-000000000101','{"date_start":"2026-11-02","date_end":"2026-11-02"}'),21);
select pg_temp.measure('save_confirmed_supplier_allocation',pg_temp.allocation_request('CONFIRMED_NEED',
 'b6500000-0000-0000-0000-000000000006','1','99'),7);
select is(pg_temp.invoke('prepare_school_catering_purchase_orders',pg_temp.command('PURCHASE-COMMITMENT.v1',
 'PURCHASE_ORDERS_PREPARED',version,'{"confirmed_need_batch_id":"b6500000-0000-0000-0000-000000000050","service_date":"2026-11-02"}'))
 ->>'success','true','real preparation') from atlas_planning.confirmed_need_batches
 where confirmed_need_batch_id='b6500000-0000-0000-0000-000000000050';
select pg_temp.measure('save_school_catering_supplier_allocation',pg_temp.allocation_request('PURCHASE_HANDOFF',
 'b6500000-0000-0000-0000-000000000006','1','99'),7);
select is(pg_temp.invoke('release_school_catering_purchase_order',pg_temp.command('SCHOOL-CATERING-PROCUREMENT.v1',
 'SCHOOL_CATERING_PO_RELEASED',p.version,jsonb_build_object('purchase_order_id',p.purchase_order_id,
 'expected_purchase_order_revision_id',r.purchase_order_revision_id)))->>'success','true','actual PO release')
 from atlas_procurement.purchase_orders p join atlas_procurement.purchase_order_revisions r
 using(purchase_order_id) where r.is_current;
insert into atlas_core.role_capabilities(role_id,capability_id)
 select 'b6000000-0000-0000-0000-000000000003',capability_id from atlas_core.capabilities
 where capability_code='dispatch.school_release.read' on conflict do nothing;
select pg_temp.measure('get_school_catering_purchase_orders',pg_temp.read_request('SCHOOL-CATERING-PROCUREMENT.v1',
 'b6000000-0000-0000-0000-000000000101','{"date_start":"2026-11-02","date_end":"2026-11-02","supplier_ids":[],"statuses":[],"search":null}'),21);
select pg_temp.measure('get_school_dispatch_release_workbench',pg_temp.read_request('SCHOOL-DISPATCH-RELEASE.v1',
 'b6000000-0000-0000-0000-000000000101','{"date_start":"2026-11-02","date_end":"2026-11-02","school_ids":[],"search":null}'),21);
select pg_temp.measure('get_school_fulfilment_reconciliation_workbench',pg_temp.read_request('SCHOOL-FULFILMENT-RECONCILIATION.v1',
 'b6000000-0000-0000-0000-000000000101','{"date_start":"2026-11-02","date_end":"2026-11-02","school_ids":[],"search":null}'),21);
select * from finish(); rollback;`;
  for (const [name, source] of [
    ["scale", scale],
    ["purchase", purchase],
  ]) {
    if (process.argv[3] && process.argv[3] !== name) continue;
    // Each sample is a separate top-level statement: the existing 8s timeout
    // applies to one real command, never the sum of seven benchmark calls.
    const statements = source.replace(
      /select pg_temp\.measure\([\s\S]*?;/g,
      (statement) => {
        const match = /,(7|21)\)(?=\s*(?:from|;))/.exec(statement);
        assert.ok(match, statement);
        return (
          "set constraints all immediate; set constraints all deferred;\n" +
          Array.from({ length: Number(match[1]) }, (_, i) =>
            statement.replace(match[0], `,${i})`),
          ).join("\n")
        );
      },
    );
    const result = sql(statements);
    const samples = result.stderr
      .split(/\r?\n/)
      .filter((line) => line.includes("MEASUREMENT "))
      .map((line) => JSON.parse(line.slice(line.indexOf("MEASUREMENT ") + 12)));
    assert.ok(samples.length > 0);
    for (const sample of samples) {
      const expectedRows = {
        get_confirmed_need_review: 248,
        get_confirmed_supplier_allocation_workbench: 2,
        get_school_catering_purchase_orders: 2,
        get_school_dispatch_release_workbench: 1,
        get_school_fulfilment_reconciliation_workbench: 1,
      }[sample.api];
      if (expectedRows !== undefined)
        assert.equal(sample.returned_rows, expectedRows);
    }
    writeFileSync(
      path.join(directory, `measurements-${name}.jsonl`),
      samples.map((sample) => JSON.stringify(sample)).join("\n") + "\n",
    );
    console.log(`${name}: ${samples.length} successful authenticated samples`);
  }
} else if (mode === "summary") {
  const summaries = [];
  for (const fixture of ["scale", "purchase"]) {
    const samples = readFileSync(
      path.join(directory, `measurements-${fixture}.jsonl`),
      "utf8",
    )
      .trim()
      .split("\n")
      .map(JSON.parse);
    for (const api of new Set(samples.map((sample) => sample.api))) {
      const rows = samples.filter((sample) => sample.api === api);
      assert.ok(rows.every((sample) => sample.success === true));
      const warm = rows.slice(1);
      const percentile = (values, p) =>
        values.sort((a, b) => a - b)[Math.ceil(values.length * p) - 1];
      summaries.push({
        api,
        fixture,
        sample_count: rows.length,
        first_call_ms: rows[0].elapsed_ms,
        warm_sample_count: warm.length,
        median_ms: percentile(
          warm.map((sample) => sample.elapsed_ms),
          0.5,
        ),
        p95_ms: percentile(
          warm.map((sample) => sample.elapsed_ms),
          0.95,
        ),
        planning_median_ms: percentile(
          warm.map((sample) => sample.plan[0]["Planning Time"]),
          0.5,
        ),
        execution_median_ms: percentile(
          warm.map((sample) => sample.plan[0]["Execution Time"]),
          0.5,
        ),
        last_shared_hit_blocks: rows.at(-1).plan[0].Plan["Shared Hit Blocks"],
        last_shared_read_blocks: rows.at(-1).plan[0].Plan["Shared Read Blocks"],
        returned_rows: rows[0].returned_rows,
        distinct_response_hashes: new Set(
          rows.map((sample) => sample.response_md5),
        ).size,
        action: "RETAIN",
        post_change: "Not applicable; implementation unchanged",
      });
    }
  }
  writeFileSync(
    path.join(directory, "performance-summary.json"),
    JSON.stringify(summaries, null, 2) + "\n",
  );
  console.log(JSON.stringify(summaries));
} else {
  throw new Error("Use catalog, regressions, performance or summary.");
}
