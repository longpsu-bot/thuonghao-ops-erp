// Local QA only. Uses the production codec; never imported by the application.
import fs from "node:fs/promises";
import path from "node:path";
import assert from "node:assert/strict";
import { createServer } from "vite";
import { JSDOM } from "jsdom";
import ExcelJS from "exceljs";
import { execFileSync } from "node:child_process";

globalThis.DOMParser = new JSDOM().window.DOMParser;
const output = path.resolve(
  process.argv.slice(2).find((arg) => !arg.startsWith("--")) ??
    "docs/xlsx/qa/connected-v1",
);
await fs.mkdir(output, { recursive: true });
const server = await createServer({
  configFile: false,
  optimizeDeps: { noDiscovery: true, include: [] },
  server: { hmr: false, middlewareMode: true },
  appType: "custom",
});
try {
  const codec = await server.ssrLoadModule(
    "/src/modules/atlas/planning-inputs/confirmed-needs/confirmedNeedShoppingList.ts",
  );
  const { shoppingFixture } = await server.ssrLoadModule(
    "/src/modules/atlas/planning-inputs/confirmed-needs/shoppingListTestFixtures.ts",
  );
  const model = await server.ssrLoadModule(
    "/src/modules/atlas/planning-inputs/confirmed-needs/confirmedNeedModel.ts",
  );
  if (process.argv.includes("--local")) {
    const calls = [];
    const invoker = {
      async invoke(name, request) {
        assert.match(name, /^atlas_api\.get_/);
        calls.push(name);
        const sql = `begin;
\\ir /tmp/atlas-shopping/local/purchase_review_confirm_release_fixture.sql
update atlas_admin.units set unit_name='kg' where unit_id='b6500000-0000-0000-0000-000000000005';
update atlas_admin.schools set school_name='Trường mẫu' where school_id='b6500000-0000-0000-0000-000000000004';
set local role authenticated;
select set_config('request.jwt.claim.sub','b6000000-0000-0000-0000-000000000101',true);
select ${name}('${JSON.stringify(request).replaceAll("'", "''")}'::jsonb);
rollback;`;
        const result = execFileSync(
          "docker",
          [
            "exec",
            "-i",
            "supabase_db_thuonghao-ops-erp",
            "psql",
            "-U",
            "supabase_admin",
            "-d",
            "postgres",
            "-q",
            "-t",
            "-A",
            "-v",
            "ON_ERROR_STOP=1",
          ],
          { input: sql, encoding: "utf8" },
        );
        const response = JSON.parse(
          result.split("\n").find((line) => line.startsWith("{")),
        );
        assert.equal(response.success, true);
        return { kind: "success", response };
      },
    };
    const { createConfirmedNeedApi } = await server.ssrLoadModule(
      "/src/modules/atlas/planning-inputs/confirmed-needs/confirmedNeedApi.ts",
    );
    const { createPlanningInputReadinessApi } = await server.ssrLoadModule(
      "/src/modules/atlas/planning-inputs/readiness/planningInputReadinessApi.ts",
    );
    const serviceModule = await server.ssrLoadModule(
      "/src/modules/atlas/planning-inputs/confirmed-needs/shoppingListService.ts",
    );
    const subject = "b6000000-0000-0000-0000-000000000101",
      api = createConfirmedNeedApi(invoker),
      preflight = createPlanningInputReadinessApi(invoker);
    const workbench = await serviceModule.loadCompleteConfirmedNeedReview(
      api,
      subject,
      "b6500000-0000-0000-0000-000000000050",
      "2026-11-02",
      true,
    );
    const draft = Object.fromEntries(
      workbench.lines.map((l) => [
        l.confirmed_need_line_id,
        model.initialConfirmedNeedDraft(l),
      ]),
    );
    const local = await codec.createConfirmedNeedShoppingListXlsx([
      { workbench, supplierAdvice: workbench.supplierAdvice },
    ]);
    await fs.writeFile(
      path.join(output, "local-production.xlsx"),
      new Uint8Array(local),
    );
    const book = new ExcelJS.Workbook();
    await book.xlsx.load(local);
    book.worksheets[0].getCell("D4").value = 3.5;
    book.worksheets[0].getCell("E4").value = "ignored staff note";
    const edited = new Uint8Array(await book.xlsx.writeBuffer());
    const imported = await serviceModule
      .createConnectedShoppingListService(api, preflight, subject)
      .import({ arrayBuffer: async () => edited.buffer }, workbench, draft);
    assert.deepEqual(imported.changedLineIds, [
      workbench.lines[0].confirmed_need_line_id,
    ]);
    assert.equal(
      imported.drafts[imported.changedLineIds[0]].reason_code,
      draft[imported.changedLineIds[0]].reason_code,
    );
    await fs.writeFile(
      path.join(output, "local-round-trip.json"),
      JSON.stringify(
        {
          status: "PASS",
          fresh_authorized_reads: calls,
          changedLineIds: imported.changedLineIds,
          import_commands: 0,
          fixture:
            "rolled-back RMVP-05 local fixture with operator display names",
          hosted_writes: 0,
        },
        null,
        2,
      ),
    );
    console.log(
      "Real local authorized read/export/edit/fresh-import: PASS; import commands=0",
    );
  }
  const fixture = JSON.parse(
    await fs.readFile(
      "docs/xlsx/examples/atlas-shopping-list-v1.fixture.json",
      "utf8",
    ),
  );
  const batches = fixture.daily_batches.map((daily, i) => {
    const f = shoppingFixture(daily.service_date, i + 1);
    const template = f.workbench.lines[0];
    f.workbench.confirmed_need_batch_id = daily.confirmed_need_batch_id;
    f.workbench.batch_version = daily.batch_version;
    f.workbench.need_generation_source.run_id = daily.need_generation_run_id;
    f.workbench.need_generation_source.release_snapshot_id =
      daily.release_snapshot_id;
    f.workbench.lines = fixture.rows
      .filter((r) => r.service_date === daily.service_date)
      .map((r) => ({
        ...structuredClone(template),
        confirmed_need_line_id: r.confirmed_need_line_id,
        current_revision_id: r.current_revision_id,
        current_decision_id: r.current_decision_id,
        school: { ...template.school, id: r.school_id, name: r.school_name },
        delivery_location: {
          ...template.delivery_location,
          id: r.delivery_location_id,
        },
        ingredient: {
          ...template.ingredient,
          id: r.ingredient_id,
          name: r.ingredient_name,
        },
        controlled_unit: {
          ...template.controlled_unit,
          id: r.unit_id,
          name: r.unit_display,
        },
        proposed_confirmed_quantity: r.exact_quantity,
        confirmed_quantity_after: r.exact_quantity,
        effective_policy: {
          ...template.effective_policy,
          effective_from: "2020-01-01",
          planning_step: r.planning_step,
        },
        decision_history: [],
      }));
    f.workbench.line_counts.total = f.workbench.lines.length;
    f.workbench.pagination = {
      offset: 0,
      limit: f.workbench.lines.length,
      total_lines: f.workbench.lines.length,
      has_more: false,
    };
    f.supplierAdvice = Object.fromEntries(
      f.workbench.lines.map((line) => {
        const candidates = fixture.supplier_eligibilities
          .filter(
            (e) =>
              e.ingredient_id === line.ingredient.id &&
              e.eligibility_status === "ACTIVE" &&
              e.effective_from <= daily.service_date &&
              (!e.effective_to || e.effective_to > daily.service_date) &&
              fixture.suppliers.some(
                (s) =>
                  s.supplier_id === e.supplier_id &&
                  s.supplier_status === "ACTIVE",
              ),
          )
          .sort((a, b) => a.priority - b.priority);
        const name =
          candidates.length &&
          candidates[0].priority !== candidates[1]?.priority
            ? fixture.suppliers.find(
                (s) => s.supplier_id === candidates[0].supplier_id,
              ).supplier_name
            : "";
        return [line.confirmed_need_line_id, name];
      }),
    );
    return f;
  });
  const drafts = Object.fromEntries(
    batches.flatMap((b) =>
      b.workbench.lines.map((l) => [
        l.confirmed_need_line_id,
        model.initialConfirmedNeedDraft(l),
      ]),
    ),
  );
  const layout = await server.ssrLoadModule(
    "/src/modules/atlas/planning-inputs/confirmed-needs/shoppingListLayout.ts",
  );
  for (const b of batches)
    for (const l of b.workbench.lines)
      try {
        layout.shoppingListRowHeight(
          l.school.name,
          l.ingredient.name,
          l.controlled_unit.name,
          codec.shortestShoppingListQuantity(l.confirmed_quantity_after),
          b.supplierAdvice[l.confirmed_need_line_id],
        );
      } catch (e) {
        console.error(
          l.school.name,
          l.ingredient.name,
          b.supplierAdvice[l.confirmed_need_line_id],
        );
        throw e;
      }
  const generated = path.join(output, "production.xlsx");
  await fs.writeFile(
    generated,
    new Uint8Array(
      await codec.createConfirmedNeedShoppingListXlsx(
        batches,
        new Date(fixture.metadata.exported_at),
        fixture.metadata.workbook_marker,
      ),
    ),
  );
  assert.deepEqual(
    (
      await codec.parseConfirmedNeedShoppingListXlsx(
        await fs.readFile(generated),
        batches.map((b) => b.workbench),
        drafts,
      )
    ).changedLineIds,
    [],
  );
  const native = path.join(output, "native-edited.xlsx");
  if (process.argv.includes("--verify-native")) {
    const imported = await codec.parseConfirmedNeedShoppingListXlsx(
      await fs.readFile(native),
      batches.map((b) => b.workbench),
      drafts,
    );
    assert.deepEqual(imported.changedLineIds, [
      batches[0].workbench.lines[0].confirmed_need_line_id,
    ]);
    assert.equal(
      imported.drafts[imported.changedLineIds[0]].reason_code,
      drafts[imported.changedLineIds[0]].reason_code,
    );
    console.log(
      "Native Excel SaveAs/reopen/full-Table sort: stable identity and quantity-only import PASS",
    );
  }
  console.log(
    `Production XLSX: ${generated}; dates=${batches.length}; rows=${Object.keys(drafts).length}`,
  );
} finally {
  await server.close();
}
