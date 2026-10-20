// One bounded connected journey on an explicitly disposable certification stack.
import assert from "node:assert/strict";
import { execFileSync, spawn, spawnSync } from "node:child_process";
import {
  readFileSync,
  mkdirSync,
  mkdtempSync,
  writeFileSync,
  rmSync,
  readdirSync,
} from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { build, preview } from "vite";
import { createClient } from "@supabase/supabase-js";
import JSZip from "jszip";
import ExcelJS from "exceljs";
import { readLocalSupabaseStatus } from "./local-supabase-status.mjs";
import { cdp } from "./staging-planning-browser.mjs";

assert(
  process.env.GITHUB_ACTIONS === "true" ||
    process.env.ATLAS_DISPOSABLE_BROWSER_CERTIFICATION === "true",
  "Connected write rehearsal requires explicit disposable certification.",
);
const root = path.resolve(import.meta.dirname, "..");
assert(
  /^project_id = "thuonghao-ops-erp"$/m.test(
    readFileSync(path.join(root, "supabase/config.toml"), "utf8"),
  ),
);
const container = "supabase_db_thuonghao-ops-erp";
function sql(statement) {
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
    { input: statement, encoding: "utf8", maxBuffer: 32 * 1024 * 1024 },
  );
  assert.equal(
    result.status,
    0,
    [
      result.stderr,
      result.stdout
        .split(/\r?\n/)
        .filter((line) => /^(?:not ok|#)/.test(line))
        .slice(-30)
        .join("\n"),
    ].join("\n"),
  );
  return result.stdout.trim();
}
assert.equal(
  sql("select count(*) from atlas_admin.schools"),
  "0",
  "Reset the disposable runner database before provisioning.",
);
function expand(file) {
  const absolute = path.resolve(file);
  assert(absolute.startsWith(path.join(root, "supabase") + path.sep));
  return readFileSync(absolute, "utf8")
    .replaceAll("\r\n", "\n")
    .replace(/^\\ir\s+(.+)$/gm, (_, name) =>
      expand(path.resolve(path.dirname(absolute), name.trim())),
    );
}
const source = expand(
  path.join(root, "supabase/tests/atlas_k2_corrected_need_purchase_orders.sql"),
);
const startMarker =
  "-- Disposable local/CI only. All source and generation constraints stay enabled.";
assert.equal(
  source.split(startMarker).length,
  2,
  "Review changed source-fixture boundary.",
);
const start = source.indexOf(startMarker);
const release = source
  .slice(start)
  .search(/insert into k2_requests\s+select 'b1_po001:'/);
assert(release > 0, "Review changed first-release boundary.");
const initialUnitCode = "'effective-generation-kg'";
const technicalUnitCode = "v1-unit-disposable-kg";
const humanUnitName = "kg";
let operationalFixture = source.slice(start, start + release);
assert.equal(
  operationalFixture.split(initialUnitCode).length,
  2,
  "Review the single synthetic Unit master prerequisite.",
);
// Initial synthetic master metadata only, before the unchanged public source commands.
operationalFixture = operationalFixture.replace(
  initialUnitCode,
  `'${technicalUnitCode}'`,
);
assert.equal(operationalFixture.split("'Need scale kilogram'").length, 2);
operationalFixture = operationalFixture.replace(
  "'Need scale kilogram'",
  `'${humanUnitName}'`,
);
const schoolMasterColumns = "default_delivery_location_id,display_order)";
const schoolMasterValues = "pg_temp.ng_id(11),i\nfrom generate_series(1,2) i;";
assert.equal(operationalFixture.split(schoolMasterColumns).length, 2);
assert.equal(operationalFixture.split(schoolMasterValues).length, 2);
// Required initial document-header master facts, before any operational command.
operationalFixture = operationalFixture
  .replace(
    schoolMasterColumns,
    "default_delivery_location_id,display_order,dispatch_document_issuer_name,dispatch_document_issuer_address)",
  )
  .replace(
    schoolMasterValues,
    "pg_temp.ng_id(11),i,'Disposable issuer','Disposable issuer address'\nfrom generate_series(1,2) i;",
  );
const fixture = `begin; create extension if not exists pgtap with schema extensions; set local search_path=extensions,public,pg_catalog; select no_plan();
-- B1 explicitly reuses the canonical calculation contract from this prerequisite.
${expand(path.join(root, "supabase/local/purchase_review_confirm_release_fixture.sql"))}
create table public.k2_results(name text primary key,response jsonb not null);
create table public.k2_requests(name text primary key,request jsonb not null);
grant select,insert on public.k2_results,public.k2_requests to authenticated;
${operationalFixture.replaceAll("create temporary table ", "create table public.")}
set constraints all immediate; commit;`;
const fixtureResult = sql(fixture);
assert(
  !/^not ok\b/m.test(fixtureResult),
  "Source/confirmation/allocation/Prepare prerequisites failed.",
);
assert.equal(
  sql(
    "select count(*) from atlas_procurement.purchase_orders where school_catering_service_date='2050-09-19' and purchase_order_status='DRAFT'",
  ),
  "2",
);
const local = readLocalSupabaseStatus({ requireAdminKey: true });
assert.equal(local.apiUrl, "http://127.0.0.1:54321");
const subject = "a7400000-0000-4000-8000-000000000101";
const email = "atlas.stabilization.operator@local.test",
  password = "Atlas-disposable-browser-only!";
const admin = createClient(local.apiUrl, local.serviceRoleKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});
const user = await admin.auth.admin.createUser({
  id: subject,
  email,
  password,
  email_confirm: true,
});
assert(
  !user.error && user.data.user?.id === subject,
  "Disposable Auth provisioning failed.",
);
const operator = createClient(local.apiUrl, local.browserKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});
assert(
  !(await operator.auth.signInWithPassword({ email, password })).error,
  "Public Auth sign-in failed.",
);
const read = async () => {
  const result = await operator
    .schema("atlas_api")
    .rpc("get_school_catering_purchase_orders", {
      request: {
        contract_version: "SCHOOL-CATERING-PROCUREMENT.v1",
        requested_by_auth_subject: subject,
        correlation_id: crypto.randomUUID(),
        payload: {
          date_start: "2050-09-19",
          date_end: "2050-09-19",
          supplier_ids: [],
          statuses: [],
          search: null,
        },
      },
    });
  assert(
    !result.error && result.data?.success,
    "Authenticated PO read failed.",
  );
  return result.data.purchase_orders;
};
const initialOrders = await read();
let before = initialOrders;
assert.equal(before.length, 2);
assert(
  before.every(
    (o) =>
      o.status === "DRAFT" && o.release_eligible && o.allowed_actions.release,
  ),
);
// Draft reads have no frozen School snapshot yet. Capture the canonical
// read-only projection before the UI releases; compare its persisted snapshot.
const readSchoolCoverage = () =>
  JSON.parse(
    sql(`
select jsonb_object_agg(line.purchase_order_line_id,
  atlas_core.school_catering_po_school_breakdown(line.school_catering_allocation_supplier_split_id))
from atlas_procurement.purchase_order_line_revisions line
join atlas_procurement.purchase_order_revisions revision using(purchase_order_revision_id)
join atlas_procurement.purchase_orders po using(purchase_order_id)
where revision.is_current and po.school_catering_service_date='2050-09-19'
`),
  );
let expectedSchools = readSchoolCoverage();
const initialSchools = expectedSchools;
const readAllocations = async () => {
  const result = await operator
    .schema("atlas_api")
    .rpc("get_confirmed_supplier_allocation_workbench", {
      request: {
        contract_version: "CONFIRMED-SUPPLIER-ALLOCATION.v1",
        requested_by_auth_subject: subject,
        correlation_id: crypto.randomUUID(),
        payload: { date_start: "2050-09-19", date_end: "2050-09-19" },
      },
    });
  assert(
    !result.error && result.data?.success,
    "Authenticated Allocation read failed.",
  );
  return result.data.rows;
};
const readSchoolDocuments = async (name, contract) => {
  const result = await operator.schema("atlas_api").rpc(name, {
    request: {
      contract_version: contract,
      requested_by_auth_subject: subject,
      correlation_id: crypto.randomUUID(),
      payload: {
        date_start: "2050-09-19",
        date_end: "2050-09-19",
        school_ids: [],
        search: null,
      },
    },
  });
  assert(
    !result.error && result.data?.success,
    `Authenticated School document read failed: ${result.error?.code ?? name}`,
  );
  return result.data.rows;
};
const readDispatch = () =>
  readSchoolDocuments(
    "get_school_dispatch_release_workbench",
    "SCHOOL-DISPATCH-RELEASE.v1",
  );
const readReconciliation = () =>
  readSchoolDocuments(
    "get_school_fulfilment_reconciliation_workbench",
    "SCHOOL-FULFILMENT-RECONCILIATION.v1",
  );
const exact = (value) => {
  assert(
    /^\d+(?:\.\d{1,6})?$/.test(value),
    "Expected exact nonnegative six-decimal quantity.",
  );
  const [whole, fraction = ""] = value.split(".");
  return BigInt(whole) * 1_000_000n + BigInt(fraction.padEnd(6, "0"));
};
const schoolSourceKeys = (sources) =>
  sources
    .map((source) => {
      const identity = [
        source.confirmed_need_line_revision_id,
        source.confirmed_need_line_decision_id,
        source.allocation_family_revision_id,
        source.allocation_family_contribution_id,
        source.allocation_supplier_split_id,
        source.purchase_order_id,
        source.purchase_order_revision_id,
        source.purchase_order_line_revision_id,
      ];
      assert(
        identity.every(
          (value) =>
            typeof value === "string" &&
            /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(value),
        ),
        "Every typed source identity must be present.",
      );
      return JSON.stringify([
        ...identity,
        exact(source.covered_quantity).toString(),
      ]);
    })
    .sort();
const coverage = (orders, schoolsByLine) =>
  orders
    .map((order) => ({
      id: order.purchase_order_id,
      supplier: order.supplier.supplier_id,
      date: order.service_date,
      lines: order.lines
        .map((line) => ({
          id: line.purchase_order_line_id,
          ingredient: line.ingredient.ingredient_id,
          unit: line.unit.unit_id,
          location: line.delivery_location.delivery_location_id,
          source: line.source,
          quantity: line.ordered_quantity,
          schools: (
            schoolsByLine?.[line.purchase_order_line_id] ??
            line.school_breakdown
          )
            .map((school) => ({
              id: school.school_id,
              location: school.delivery_location_id,
              quantity: school.ordered_quantity,
            }))
            .sort((a, b) => a.id.localeCompare(b.id)),
        }))
        .sort((a, b) => a.id.localeCompare(b.id)),
    }))
    .sort((a, b) => a.id.localeCompare(b.id));
assert(before.every((order) => order.lines.length > 0));
assert.equal(
  new Set(
    Object.values(expectedSchools).flatMap((schools) =>
      schools.map((school) => school.school_id),
    ),
  ).size,
  2,
);
Object.assign(process.env, {
  VITE_ATLAS_ENVIRONMENT: "local",
  VITE_SUPABASE_URL: local.apiUrl,
  VITE_SUPABASE_PUBLISHABLE_KEY: local.browserKey,
});
const evidence = path.join(root, ".git/atlas-procurement-browser");
const quantityLabel = (value) =>
  value.replace(/(\.\d*?)0+$/, "$1").replace(/\.$/, "");
mkdirSync(evidence, { recursive: true });
for (const name of readdirSync(evidence).filter((name) =>
  /\.(?:zip|png|xlsx|pdf)$|^report\.json$/i.test(name),
)) {
  rmSync(path.join(evidence, name));
}
const outDir = path.join(evidence, "dist");
await build({
  build: {
    outDir,
    emptyOutDir: true,
    rolldownOptions: {
      input: path.join(root, "supabase/local/atlas_procurement_browser.html"),
    },
  },
});
const server = await preview({
  build: { outDir },
  preview: { host: "127.0.0.1", port: 3019, strictPort: true },
});
const profile = mkdtempSync(path.join(tmpdir(), "atlas-procurement-ci-"));
let chrome, connection;
const until = async (fn, label) => {
  const end = Date.now() + 30000;
  while (Date.now() < end) {
    const result = await fn();
    if (result) return result;
    await new Promise((r) => setTimeout(r, 100));
  }
  throw new Error(`CONNECTED_PROCUREMENT_${label}`);
};
try {
  chrome = spawn(
    process.env.CHROME_BIN ||
      (process.platform === "win32"
        ? "C:/Program Files/Google/Chrome/Application/chrome.exe"
        : "google-chrome"),
    [
      "--headless=new",
      "--no-sandbox",
      "--disable-dev-shm-usage",
      "--remote-debugging-port=9226",
      `--user-data-dir=${profile}`,
      "about:blank",
    ],
    { stdio: "ignore" },
  );
  const page = await until(async () => {
    try {
      return (
        await (await fetch("http://127.0.0.1:9226/json/list")).json()
      ).find((p) => p.type === "page");
    } catch {
      return null;
    }
  }, "BROWSER_START");
  connection = await cdp(page.webSocketDebuggerUrl);
  const evaluate = async (expression) => {
    const response = await connection.send("Runtime.evaluate", {
      expression,
      returnByValue: true,
      awaitPromise: true,
    });
    assert(!response.exceptionDetails, "Browser journey evaluation failed.");
    return response.result?.value;
  };
  const text = () => evaluate("document.body?.innerText ?? ''");
  const click = (label) =>
    evaluate(
      `(()=>{const b=[...document.querySelectorAll('button')].find(b=>b.textContent.trim()===${JSON.stringify(label)});if(!b||b.disabled)return false;b.click();return true;})()`,
    );
  const reload = async () => {
    const previousDocument = await evaluate("performance.timeOrigin");
    await connection.send("Page.reload", {});
    await until(
      () =>
        evaluate(
          `performance.timeOrigin!==${JSON.stringify(previousDocument)}&&document.readyState==='complete'`,
        ),
      "NEW_RELOADED_DOCUMENT",
    );
  };
  await connection.send("Browser.setDownloadBehavior", {
    behavior: "allow",
    downloadPath: evidence,
  });
  const url =
    "http://127.0.0.1:3019/supabase/local/atlas_procurement_browser.html";
  await connection.send("Page.navigate", { url: `${url}?stage=allocation` });
  await until(async () => (await text()).includes("Đăng nhập"), "LOGIN");
  assert(
    !(await text()).includes("Phát hành tất cả"),
    "Unauthenticated UI must expose no release action.",
  );
  await evaluate(
    `(()=>{const inputs=[...document.querySelectorAll('input')];const setter=Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set;for(const [i,value] of [[0,${JSON.stringify(email)}],[1,${JSON.stringify(password)}]]){setter.call(inputs[i],value);inputs[i].dispatchEvent(new Event('input',{bubbles:true}));}})()`,
  );
  assert(await click("Đăng nhập"));
  await until(
    async () => (await text()).includes(humanUnitName),
    "ALLOCATION_UNIT_NAME",
  );
  assert(!(await text()).includes(technicalUnitCode));
  const allocationBefore = await readAllocations();
  assert(allocationBefore.length > 0);
  assert(
    allocationBefore.every(
      (row) =>
        row.unit_name === humanUnitName && row.unit_code === technicalUnitCode,
    ),
  );
  const editedFamily = allocationBefore.find(
    (row) =>
      row.state === "BALANCED" &&
      row.splits.length > 0 &&
      row.allowed_actions.save_allocation,
  );
  assert(
    editedFamily,
    "Prepared fixture must expose a saved editable Allocation.",
  );
  assert.equal(
    allocationBefore.filter(
      (row) => row.ingredient_id === editedFamily.ingredient_id,
    ).length,
    1,
    "Select one unambiguous synthetic ingredient family.",
  );
  const editLabel = await evaluate(
    `(()=>{const row=[...document.querySelectorAll('tr')].find(row=>row.querySelector('[data-allocation-ingredient]')?.textContent.trim()===${JSON.stringify(editedFamily.ingredient_name)});const b=row?.querySelector('button[aria-label^="Xem phân bổ "]');return !b?.disabled&&b?.getAttribute('aria-label');})()`,
  );
  assert(editLabel, "Prepared Allocation must remain editable.");
  const editAllocation = () =>
    evaluate(
      `(()=>{const b=[...document.querySelectorAll('button[aria-label]')].find(b=>b.getAttribute('aria-label')===${JSON.stringify(editLabel)});if(!b||b.disabled)return false;b.click();return true;})()`,
    );
  assert(await editAllocation());
  const noteLabel = await until(
    () =>
      evaluate(
        `document.querySelector('textarea[aria-label^="Ghi chú cho "]')?.getAttribute('aria-label')`,
      ),
    "ALLOCATION_EDITOR",
  );
  const supplierNote = "Disposable Unit label browser check";
  await evaluate(
    `(()=>{const input=[...document.querySelectorAll('textarea')].find(input=>input.getAttribute('aria-label')===${JSON.stringify(noteLabel)});const setter=Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype,'value').set;setter.call(input,${JSON.stringify(supplierNote)});input.dispatchEvent(new Event('input',{bubbles:true}));})()`,
  );
  await until(() => click("Lưu phân bổ"), "ALLOCATION_SAVE_READY");
  // One actual public command; uncertainty stops this journey, never a blind retry.
  await until(
    async () =>
      (await readAllocations()).some((row) =>
        row.splits.some((split) => split.supplier_note === supplierNote),
      ),
    "ALLOCATION_SAVED_READBACK",
  );
  const allocationQuantities = (rows) =>
    rows
      .map((row) => ({
        date: row.service_date,
        location: row.delivery_location_id,
        ingredient: row.ingredient_id,
        unit: row.unit_id,
        quantity: row.family_quantity,
        family: {
          id: row.family.family_id,
          source_kind: row.family.source_kind,
          batch: row.family.source_confirmed_need_batch_id,
          batch_version: row.family.source_confirmed_need_batch_version,
          fingerprint: row.family.source_fingerprint,
        },
        contributions: row.contributions,
        schools: row.schools,
        splits: row.splits
          .map((split) => ({
            supplier: split.supplier_id,
            quantity: split.allocated_quantity,
          }))
          .sort((a, b) => a.supplier.localeCompare(b.supplier)),
      }))
      .sort((a, b) => JSON.stringify(a).localeCompare(JSON.stringify(b)));
  assert.deepEqual(
    allocationQuantities(await readAllocations()),
    allocationQuantities(allocationBefore),
    "A supplier-note edit must preserve all allocated quantities and scope.",
  );
  await until(
    () =>
      evaluate(
        `[...document.querySelectorAll('button')].some(b=>b.textContent.trim()==='Đóng'&&!b.disabled)`,
      ),
    "ALLOCATION_COMMAND_READBACK",
  );
  await reload();
  await until(editAllocation, "ALLOCATION_REOPEN");
  await until(
    () =>
      evaluate(
        `[...document.querySelectorAll('textarea')].some(input=>input.getAttribute('aria-label')===${JSON.stringify(noteLabel)}&&input.value===${JSON.stringify(supplierNote)})`,
      ),
    "ALLOCATION_PERSISTED_NOTE",
  );
  assert(
    (await text()).includes(humanUnitName) &&
      !(await text()).includes(technicalUnitCode),
  );
  assert(await click("Đóng"));
  await connection.send("Page.navigate", { url });
  await until(
    () =>
      evaluate(
        `(()=>{const b=[...document.querySelectorAll('button[aria-label^="Xem đơn "]')].find(b=>b.getAttribute('aria-label').endsWith('Cần cập nhật'));if(!b||b.disabled)return false;b.click();return true;})()`,
      ),
    "STALE_DRAFT",
  );
  await until(
    () => click("Tạo lại đơn cần cập nhật"),
    "REGENERATE_DRAFT_READY",
  );
  await until(
    async () => (await text()).includes("Phát hành tất cả PO (2)"),
    "CURRENT_DRAFTS",
  );
  before = await read();
  expectedSchools = readSchoolCoverage();
  assert(
    before.every(
      (order) =>
        order.status === "DRAFT" &&
        order.commitment_state === "DRAFT_CURRENT" &&
        order.release_eligible,
    ),
  );
  const quantityFootprint = (orders, schoolsByLine) =>
    orders
      .map((order) => ({
        id: order.purchase_order_id,
        supplier: order.supplier.supplier_id,
        date: order.service_date,
        lines: order.lines
          .map((line) => ({
            ingredient: line.ingredient.ingredient_id,
            unit: line.unit.unit_id,
            location: line.delivery_location.delivery_location_id,
            quantity: line.ordered_quantity,
            family: line.source.family_id,
            schools: schoolsByLine[line.purchase_order_line_id]
              .map((school) => ({
                id: school.school_id,
                location: school.delivery_location_id,
                quantity: school.ordered_quantity,
              }))
              .sort((a, b) => a.id.localeCompare(b.id)),
          }))
          .sort((a, b) => JSON.stringify(a).localeCompare(JSON.stringify(b))),
      }))
      .sort((a, b) => a.id.localeCompare(b.id));
  assert.deepEqual(
    quantityFootprint(before, expectedSchools),
    quantityFootprint(initialOrders, initialSchools),
    "Supported Draft regeneration must retain PO/source family/School scope and exact quantities.",
  );
  assert(
    before.some((order) =>
      order.lines.some((line) => line.supplier_note === supplierNote),
    ),
    "Regeneration must carry the saved supplier note into the Draft.",
  );
  const searchName = before.find((o) =>
    o.supplier.supplier_name.includes("second"),
  )?.supplier.supplier_name;
  assert(searchName);
  await evaluate(
    `(()=>{const input=document.querySelector('input[placeholder="Nhà cung ứng, số đơn, nguyên liệu, trường"]');const setter=Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set;setter.call(input,${JSON.stringify(searchName)});input.dispatchEvent(new Event('input',{bubbles:true}));})()`,
  );
  await until(
    async () => (await text()).includes("1 đơn mua theo nhà cung cấp"),
    "FILTER",
  );
  assert(
    (await text()).includes("Phát hành tất cả PO (2)"),
    "Search must not narrow the displayed release scope.",
  );
  assert(await click("Phát hành tất cả PO (2)"));
  await until(
    async () => (await text()).includes("Đã phát hành 2/2 PO."),
    "BULK_RELEASE",
  );
  const after = await read();
  assert(
    after.every(
      (o) =>
        o.status === "RELEASED_TO_SUPPLIER" &&
        o.document_number &&
        o.document_snapshot_complete,
    ),
  );
  assert.deepEqual(
    coverage(after),
    coverage(before, expectedSchools),
    "PO identity, source, exact quantities and per-School coverage must survive release.",
  );
  assert(
    after.every((order) =>
      order.lines.every(
        (line) =>
          line.unit_code_snapshot === technicalUnitCode &&
          line.unit_name_snapshot === humanUnitName,
      ),
    ),
    "Future official documents must freeze both the technical Unit code and its human name.",
  );
  assert(
    after.some((order) =>
      order.lines.some((line) => line.supplier_note === supplierNote),
    ),
  );
  const numbers = after.map((o) => o.document_number).sort();
  const receipts = sql(
    "select count(*) from atlas_core.command_receipts where command_name='release_school_catering_purchase_order' and outcome='COMPLETED'",
  );
  assert.equal(receipts, "2", "One receipt per PO, with no duplicate command.");
  await reload();
  await until(async () => {
    const body = await text();
    return (
      body.includes("Phát hành tất cả PO (0)") &&
      numbers.every((n) => body.includes(n))
    );
  }, "PERSISTED_RELOAD");
  assert.deepEqual(
    (await read()).map((o) => o.document_number).sort(),
    numbers,
  );
  assert(await click("Xuất XLSX"));
  await until(
    async () => readdirSync(evidence).some((n) => /\.zip$/i.test(n)),
    "XLSX_EXPORT",
  );
  await until(() => click("Xuất PDF"), "PDF_EXPORT_READY");
  await until(
    async () =>
      readdirSync(evidence).filter((n) => /\.zip$/i.test(n)).length === 2,
    "PDF_EXPORT",
  );
  const exported = new Set();
  for (const name of readdirSync(evidence).filter((name) =>
    /\.zip$/i.test(name),
  )) {
    const zip = await JSZip.loadAsync(readFileSync(path.join(evidence, name)), {
      checkCRC32: true,
    });
    const entries = Object.values(zip.files).filter((file) => !file.dir);
    assert.equal(
      entries.length,
      2,
      "Every eligible loaded PO must be exported.",
    );
    const format = entries.every((file) => file.name.endsWith(".xlsx"))
      ? "xlsx"
      : entries.every((file) => file.name.endsWith(".pdf"))
        ? "pdf"
        : null;
    assert(
      format && !exported.has(format),
      "Expected one fresh XLSX archive and one PDF archive.",
    );
    exported.add(format);
    const seen = new Set();
    for (const entry of entries) {
      const order = after.find((order) =>
        entry.name.includes(order.document_number),
      );
      assert(
        order && !seen.has(order.purchase_order_id),
        "Archive document identity must match the authoritative release.",
      );
      seen.add(order.purchase_order_id);
      const bytes = await entry.async("nodebuffer");
      if (format === "xlsx") {
        const workbook = new ExcelJS.Workbook();
        await workbook.xlsx.load(bytes);
        const metadata = workbook.getWorksheet("_ATLAS_META");
        assert(metadata && metadata.state === "veryHidden");
        assert.equal(
          metadata.getCell("B1").value,
          "ATLAS_OPERATIONAL_DOCUMENT_V1",
        );
        const records = [];
        metadata.eachRow((row, index) => {
          if (index > 2)
            records.push({
              kind: row.getCell(1).text,
              id: row.getCell(2).text,
              sheet: row.getCell(3).text,
              row: Number(row.getCell(4).value),
              data: JSON.parse(row.getCell(5).text),
            });
        });
        const document = records.find((record) => record.kind === "DOCUMENT");
        assert.equal(document?.data.document_number, order.document_number);
        assert.equal(
          document?.data.purchase_order_revision_id,
          order.current_revision.purchase_order_revision_id,
        );
        assert.equal(document?.data.service_date, order.service_date);
        assert(
          records.every((record) => record.id === order.purchase_order_id),
        );
        for (const source of records.filter(
          (record) => record.kind === "ROW_SOURCE",
        )) {
          const sheet = workbook.getWorksheet(source.sheet);
          assert(sheet && sheet.state === "visible");
          const row = sheet.getRow(source.row);
          if (row.getCell(14).text === "CONTINUATION") continue;
          const quantity =
            source.data.school_quantity ?? source.data.ordered_quantity;
          assert.equal(
            row.getCell(5).text,
            quantityLabel(quantity),
            "Visible XLSX quantity must match its exact released source.",
          );
          assert.equal(row.getCell(4).text, humanUnitName);
        }
        for (const line of order.lines) {
          const source = records.find(
            (record) =>
              record.kind === "ROW_SOURCE" &&
              record.data.purchase_order_line_id ===
                line.purchase_order_line_id &&
              record.data.ordered_quantity === line.ordered_quantity,
          );
          assert(
            source,
            "Export metadata must retain every released source and exact quantity.",
          );
          assert.equal(
            source.data.purchase_order_line_revision_id,
            line.purchase_order_line_revision_id,
          );
          assert.equal(source.data.unit_code_snapshot, technicalUnitCode);
          assert.equal(source.data.unit_name_snapshot, humanUnitName);
        }
        assert.equal(
          workbook.worksheets.filter((sheet) => sheet.state === "visible")
            .length,
          3,
        );
      } else {
        assert.equal(bytes.subarray(0, 5).toString(), "%PDF-");
        const pdfPath = path.join(profile, `${order.purchase_order_id}.pdf`);
        writeFileSync(pdfPath, bytes);
        const contents = execFileSync("pdftotext", ["-layout", pdfPath, "-"], {
          encoding: "utf8",
        });
        const flatContents = ` ${contents.replace(/\s+/g, " ")} `;
        assert(contents.includes(order.document_number));
        assert(
          contents.includes(order.service_date.split("-").reverse().join("/")),
        );
        assert(
          contents.includes(order.current_revision.supplier_name_snapshot),
        );
        for (const line of order.lines) {
          assert(contents.includes(line.ingredient_name_snapshot));
          assert(contents.includes(humanUnitName));
          assert(!contents.includes(technicalUnitCode));
          const quantity = quantityLabel(line.ordered_quantity);
          assert(
            flatContents.includes(` ${quantity} `),
            "PDF must contain the released quantity.",
          );
          for (const school of line.school_breakdown)
            assert(contents.includes(school.school_name));
        }
      }
    }
  }
  assert.deepEqual([...exported].sort(), ["pdf", "xlsx"]);
  // Continue through the actual existing School PXK owner with the same public Auth.
  const readySchools = await readDispatch();
  assert.equal(readySchools.length, 2);
  assert(
    readySchools.every(
      (row) =>
        row.state === "READY" &&
        row.allowed_actions.release &&
        row.preview.ready &&
        !row.current_release,
    ),
  );
  const poSchoolQuantities = new Map();
  for (const order of after)
    for (const line of order.lines)
      for (const school of line.school_breakdown) {
        const key = JSON.stringify([
          order.service_date,
          school.school_id,
          school.delivery_location_id,
          line.ingredient.ingredient_id,
          line.unit.unit_id,
        ]);
        poSchoolQuantities.set(
          key,
          (poSchoolQuantities.get(key) ?? 0n) + exact(school.ordered_quantity),
        );
      }
  const pxkScope = (row, lines) =>
    lines
      .map((line) => ({
        key: JSON.stringify([
          row.service_date,
          row.school_id,
          row.delivery_location_id,
          line.ingredient_id,
          line.unit_id,
        ]),
        quantity: exact(line.quantity).toString(),
      }))
      .sort((a, b) => a.key.localeCompare(b.key));
  assert.deepEqual(
    readySchools
      .flatMap((row) => pxkScope(row, row.preview.lines))
      .sort((a, b) => a.key.localeCompare(b.key)),
    [...poSchoolQuantities]
      .map(([key, quantity]) => ({ key, quantity: quantity.toString() }))
      .sort((a, b) => a.key.localeCompare(b.key)),
    "School previews must exactly match released PO School/ingredient/Unit coverage.",
  );
  await connection.send("Page.navigate", { url: `${url}?stage=pxk` });
  await until(
    async () => (await text()).includes("Phiếu xuất kho"),
    "PXK_OWNER",
  );
  const dispatches = [];
  for (const ready of readySchools) {
    await until(
      () =>
        evaluate(
          `(()=>{const b=[...document.querySelectorAll('button[aria-describedby]')].find(b=>b.getAttribute('aria-describedby').includes(${JSON.stringify(ready.school_id)})&&b.textContent.trim()==='Phát hành');if(!b||b.disabled)return false;b.click();return true;})()`,
        ),
      "PXK_OPEN_READY_SCHOOL",
    );
    const note = `Disposable PXK ${ready.school_id}`;
    await until(
      () =>
        evaluate(
          `Boolean(document.querySelector('textarea[aria-label="Ghi chú trên phiếu"]:not(:disabled)'))`,
        ),
      "PXK_NOTE_READY",
    );
    await evaluate(
      `(()=>{const input=document.querySelector('textarea[aria-label="Ghi chú trên phiếu"]');Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype,'value').set.call(input,${JSON.stringify(note)});input.dispatchEvent(new Event('input',{bubbles:true}));})()`,
    );
    await until(() => click("Phát hành phiếu xuất kho"), "PXK_RELEASE_READY");
    const released = await until(async () => {
      const row = (await readDispatch()).find(
        (row) =>
          row.school_id === ready.school_id &&
          row.delivery_location_id === ready.delivery_location_id,
      );
      return row?.state === "CURRENT" &&
        row.current_release?.status === "RELEASED"
        ? row
        : null;
    }, "PXK_PERSISTED_RELEASE");
    const document = released.current_release;
    assert.equal(document.service_date, ready.service_date);
    assert.equal(document.school_id, ready.school_id);
    assert.equal(document.delivery_location_id, ready.delivery_location_id);
    assert.equal(document.source_fingerprint, ready.preview.source_fingerprint);
    assert.equal(document.predecessor_release_id, null);
    assert.equal(document.note, note);
    assert.equal(document.document_issuer_name, "Disposable issuer");
    assert.equal(document.document_issuer_address, "Disposable issuer address");
    assert(document.export_ready && document.document_number);
    assert.deepEqual(
      pxkScope(document, document.lines),
      pxkScope(ready, ready.preview.lines),
    );
    for (const line of document.lines) {
      const preview = ready.preview.lines.find(
        (value) =>
          value.ingredient_id === line.ingredient_id &&
          value.unit_id === line.unit_id,
      );
      const frozenSources = schoolSourceKeys(line.sources),
        previewSources = schoolSourceKeys(preview.sources);
      assert.equal(
        new Set(frozenSources).size,
        frozenSources.length,
        "Frozen typed sources must contain no duplicate membership.",
      );
      assert.equal(new Set(previewSources).size, previewSources.length);
      assert.deepEqual(
        frozenSources,
        previewSources,
        "Release must freeze every exact typed identity/quantity regardless of generated source-row ordering.",
      );
      assert.equal(
        line.sources.reduce(
          (total, source) => total + exact(source.covered_quantity),
          0n,
        ),
        exact(line.quantity),
      );
    }
    dispatches.push(document);
    await until(
      async () => (await text()).includes(document.document_number),
      "PXK_UI_READBACK",
    );
    const exportSchool = (label) =>
      evaluate(
        `(()=>{const group=[...document.querySelectorAll('[role="group"][aria-label]')].find(group=>group.getAttribute('aria-label')===${JSON.stringify(`Xuất phiếu ${document.document_number}`)});const b=[...(group?.querySelectorAll('button')??[])].find(b=>b.textContent.trim()===${JSON.stringify(label)});if(!b||b.disabled)return false;b.click();return true;})()`,
      );
    await until(() => exportSchool("Xuất XLSX"), "PXK_XLSX_READY");
    const schoolXlsx = await until(
      () =>
        readdirSync(evidence).find(
          (name) =>
            name.endsWith(".xlsx") && name.includes(document.document_number),
        ),
      "PXK_XLSX_DOWNLOAD",
    );
    await until(() => exportSchool("Xuất PDF"), "PXK_PDF_READY");
    const schoolPdf = await until(
      () =>
        readdirSync(evidence).find(
          (name) =>
            name.endsWith(".pdf") && name.includes(document.document_number),
        ),
      "PXK_PDF_DOWNLOAD",
    );
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(readFileSync(path.join(evidence, schoolXlsx)));
    const metadata = workbook.getWorksheet("_ATLAS_META");
    assert(metadata && metadata.state === "veryHidden");
    assert.equal(metadata.getCell("B1").text, "ATLAS_OPERATIONAL_DOCUMENT_V1");
    const records = [];
    metadata.eachRow((row, index) => {
      if (index > 2)
        records.push({
          kind: row.getCell(1).text,
          id: row.getCell(2).text,
          sheet: row.getCell(3).text,
          row: Number(row.getCell(4).value),
          data: JSON.parse(row.getCell(5).text),
        });
    });
    assert(
      records.every(
        (record) => record.id === document.school_dispatch_release_id,
      ),
    );
    const documentRecord = records.find((record) => record.kind === "DOCUMENT");
    assert.equal(
      records.filter((record) => record.kind === "DOCUMENT").length,
      1,
    );
    assert.equal(documentRecord.data.document_number, document.document_number);
    assert.equal(
      documentRecord.data.source_fingerprint,
      document.source_fingerprint,
    );
    assert.equal(documentRecord.data.school_id, document.school_id);
    assert.equal(documentRecord.data.service_date, document.service_date);
    assert.equal(
      documentRecord.data.delivery_location_id,
      document.delivery_location_id,
    );
    assert.equal(documentRecord.data.note, note);
    const sheet = workbook.getWorksheet(documentRecord.sheet);
    assert(sheet && sheet.state === "visible");
    assert.equal(sheet.getCell("B1").text, document.document_issuer_name);
    assert(sheet.getCell("B2").text.includes(document.document_issuer_address));
    assert(sheet.getCell("A6").text.includes(document.school_name));
    assert.equal(
      sheet.getCell("G5").text,
      document.service_date.split("-").reverse().join("/"),
    );
    const sourceTuple = (data) =>
      JSON.stringify([
        data.school_dispatch_release_line_id,
        data.school_id,
        data.source_quantity,
        data.dispatch_group_id ?? null,
        data.note,
        schoolSourceKeys([data])[0],
      ]);
    const expectedSources = document.lines
      .flatMap((line) =>
        line.sources.map((source) =>
          sourceTuple({
            school_dispatch_release_line_id:
              line.school_dispatch_release_line_id,
            school_id: document.school_id,
            source_quantity: line.quantity,
            dispatch_group_id: document.dispatch_group_id ?? null,
            note,
            ...source,
          }),
        ),
      )
      .sort();
    const actualSources = records
      .filter((record) => record.kind === "ROW_SOURCE")
      .map((record) => sourceTuple(record.data))
      .sort();
    assert.deepEqual(
      actualSources,
      expectedSources,
      "PXK metadata must contain the complete frozen source multiset with no extra or duplicate records.",
    );
    assert.equal(records.length, expectedSources.length + 1);
    for (const line of document.lines)
      for (const source of line.sources) {
        const record = records.find(
          (record) =>
            record.kind === "ROW_SOURCE" &&
            record.data.school_dispatch_release_line_id ===
              line.school_dispatch_release_line_id &&
            record.data.allocation_family_contribution_id ===
              source.allocation_family_contribution_id &&
            record.data.allocation_supplier_split_id ===
              source.allocation_supplier_split_id &&
            record.data.purchase_order_line_revision_id ===
              source.purchase_order_line_revision_id,
        );
        assert(record, "PXK export must retain every exact typed source.");
        assert.equal(record.data.source_quantity, line.quantity);
        assert.equal(record.data.covered_quantity, source.covered_quantity);
        assert.equal(
          record.data.confirmed_need_line_revision_id,
          source.confirmed_need_line_revision_id,
        );
        assert.equal(
          record.data.confirmed_need_line_decision_id,
          source.confirmed_need_line_decision_id,
        );
        assert.equal(
          sheet.getRow(record.row).getCell(4).text,
          quantityLabel(line.quantity),
        );
        assert.equal(sheet.getRow(record.row).getCell(3).text, line.unit_code);
        assert.equal(
          sheet.getRow(record.row).getCell(2).text,
          line.ingredient_name,
        );
        assert.equal(
          sheet.getRow(record.row).getCell(9).text,
          document.school_dispatch_release_id,
        );
        assert.equal(
          sheet.getRow(record.row).getCell(10).text,
          line.ingredient_id,
        );
        assert.equal(sheet.getRow(record.row).getCell(11).text, line.unit_id);
        assert.equal(
          sheet.getRow(record.row).getCell(12).text,
          document.school_id,
        );
        assert.equal(
          sheet.getRow(record.row).getCell(13).text,
          document.delivery_location_id,
        );
      }
    const pdf = execFileSync(
      "pdftotext",
      ["-layout", path.join(evidence, schoolPdf), "-"],
      { encoding: "utf8" },
    );
    const rawPdf = execFileSync(
      "pdftotext",
      ["-raw", path.join(evidence, schoolPdf), "-"],
      { encoding: "utf8" },
    );
    const compact = rawPdf.replace(/\s+/g, "");
    for (const value of [
      document.document_number,
      document.school_name,
      document.document_issuer_name,
      document.document_issuer_address,
      document.service_date.split("-").reverse().join("/"),
      note,
    ])
      assert(
        compact.includes(value.replace(/\s+/g, "")),
        "PXK PDF must contain its frozen header/note.",
      );
    for (const line of document.lines) {
      assert(compact.includes(line.ingredient_name.replace(/\s+/g, "")));
      assert(compact.includes(line.unit_code));
      assert(
        pdf.replace(/\s+/g, " ").includes(` ${quantityLabel(line.quantity)} `),
      );
    }
    assert(
      await evaluate(
        `(()=>{const b=document.querySelector('button[aria-label="Đóng chi tiết"]');if(!b||b.disabled)return false;b.click();return true;})()`,
      ),
    );
  }
  assert.equal(
    sql(
      "select count(*) from atlas_core.command_receipts where command_name='release_school_dispatch_document' and outcome='COMPLETED'",
    ),
    "2",
    "One completed receipt per School release.",
  );
  await reload();
  await until(async () => {
    const body = await text();
    return dispatches.every((document) =>
      body.includes(document.document_number),
    );
  }, "PXK_PERSISTED_RELOAD");
  const persistedDispatches = await readDispatch();
  assert(persistedDispatches.every((row) => row.state === "CURRENT"));
  for (const document of dispatches) {
    assert.deepEqual(
      persistedDispatches.find(
        (row) =>
          row.school_id === document.school_id &&
          row.delivery_location_id === document.delivery_location_id,
      )?.current_release,
      document,
      "Reopening must preserve the complete frozen School document.",
    );
    await until(
      () =>
        evaluate(
          `(()=>{const b=[...document.querySelectorAll('button[aria-describedby]')].find(b=>b.getAttribute('aria-describedby').includes(${JSON.stringify(document.school_id)})&&b.textContent.trim()==='Xem phiếu');if(!b||b.disabled)return false;b.click();return true;})()`,
        ),
      "PXK_REOPEN_DOCUMENT",
    );
    const visible = await until(
      () =>
        evaluate(
          `(()=>{const table=[...document.querySelectorAll('table[aria-label]')].find(table=>table.getAttribute('aria-label')===${JSON.stringify(`Nội dung ${document.document_number}`)});return table&&[...table.querySelectorAll('tbody tr')].map(row=>({ingredient:row.cells[0].textContent.trim(),quantity:row.cells[1].textContent.trim(),unit:row.cells[2].textContent.trim()}));})()`,
        ),
      "PXK_REOPENED_CONTENTS",
    );
    assert.deepEqual(
      visible
        .map((line) => ({
          ...line,
          quantity: exact(line.quantity.replace(",", ".")).toString(),
        }))
        .sort((a, b) => a.ingredient.localeCompare(b.ingredient)),
      document.lines
        .map((line) => ({
          ingredient: line.ingredient_name,
          quantity: exact(line.quantity).toString(),
          unit: line.unit_code,
        }))
        .sort((a, b) => a.ingredient.localeCompare(b.ingredient)),
      "Every reloaded visible School quantity and Unit must match its immutable snapshot.",
    );
    assert(
      await evaluate(
        `(()=>{const b=document.querySelector('button[aria-label="Đóng chi tiết"]');if(!b||b.disabled)return false;b.click();return true;})()`,
      ),
    );
  }
  const comparison = await readReconciliation();
  assert.equal(comparison.length, 2);
  assert(
    comparison.every(
      (row) =>
        row.comparison_status === "OK" &&
        row.pxk_state === "CURRENT" &&
        row.blockers.length === 0 &&
        row.quantity_totals_by_unit.every(
          (total) => exact(total.delta_quantity) === 0n,
        ),
    ),
    "Released PO/PXK coverage must reconcile without hidden operational blockers.",
  );
  assert.deepEqual(
    new Set(comparison.map((row) => row.school_dispatch_release_id)),
    new Set(dispatches.map((document) => document.school_dispatch_release_id)),
  );
  const comparisonKey = (row, ingredient, unit) =>
    JSON.stringify([
      row.service_date,
      row.school_id,
      row.delivery_location_id,
      ingredient,
      unit,
    ]);
  const expectedDetails = dispatches
    .flatMap((document) =>
      document.lines.map((line) => ({
        key: comparisonKey(document, line.ingredient_id, line.unit_id),
        unit: line.unit_code,
        po: exact(line.quantity).toString(),
        pxk: exact(line.quantity).toString(),
        delta: "0",
      })),
    )
    .sort((a, b) => a.key.localeCompare(b.key));
  const actualDetails = comparison
    .flatMap((row) =>
      row.details.map((detail) => ({
        key: comparisonKey(row, detail.ingredient_id, detail.unit_id),
        unit: detail.unit_code,
        po: exact(detail.po_quantity).toString(),
        pxk: exact(detail.pxk_quantity).toString(),
        delta: exact(detail.delta_quantity).toString(),
      })),
    )
    .sort((a, b) => a.key.localeCompare(b.key));
  assert.deepEqual(
    actualDetails,
    expectedDetails,
    "Every reconciled School/date/location/ingredient/Unit quantity must equal its exact frozen document.",
  );
  const expectedUnitTotals = new Map();
  for (const document of dispatches) {
    const totals = new Map();
    for (const line of document.lines) {
      const previous = totals.get(line.unit_id);
      totals.set(line.unit_id, {
        unit_id: line.unit_id,
        unit_code: line.unit_code,
        quantity: (previous?.quantity ?? 0n) + exact(line.quantity),
      });
    }
    assert(totals.size > 0);
    expectedUnitTotals.set(document.school_dispatch_release_id, [
      ...totals.values(),
    ]);
  }
  for (const row of comparison) {
    const document = dispatches.find(
      (document) =>
        document.school_dispatch_release_id === row.school_dispatch_release_id,
    );
    assert.equal(row.school_name, document.school_name);
    assert.equal(row.delivery_location_name, document.delivery_location_name);
    assert(row.details.length > 0 && row.quantity_totals_by_unit.length > 0);
    assert.deepEqual(
      row.quantity_totals_by_unit
        .map((total) => ({
          unit: total.unit_id,
          code: total.unit_code,
          po: exact(total.po_quantity).toString(),
          pxk: exact(total.pxk_quantity).toString(),
          delta: exact(total.delta_quantity).toString(),
        }))
        .sort((a, b) => a.unit.localeCompare(b.unit)),
      expectedUnitTotals
        .get(document.school_dispatch_release_id)
        .map((total) => ({
          unit: total.unit_id,
          code: total.unit_code,
          po: total.quantity.toString(),
          pxk: total.quantity.toString(),
          delta: "0",
        }))
        .sort((a, b) => a.unit.localeCompare(b.unit)),
      "Reconciliation Unit totals must be complete, exact and nonempty.",
    );
  }
  await connection.send("Page.navigate", {
    url: `${url}?stage=reconciliation`,
  });
  await until(
    async () => (await text()).replace(/\s+/g, " ").includes("Khớp 2"),
    "RECONCILIATION_MATCHES",
  );
  await evaluate(
    `(()=>{const select=document.querySelector('select[aria-label="Tình trạng"]');Object.getOwnPropertyDescriptor(HTMLSelectElement.prototype,'value').set.call(select,'all');select.dispatchEvent(new Event('change',{bubbles:true}));})()`,
  );
  await until(
    () =>
      evaluate(
        `document.querySelector('table[aria-label="Đối chiếu theo trường"]')?.querySelectorAll('tbody tr').length===2`,
      ),
    "RECONCILIATION_VISIBLE_SCHOOLS",
  );
  const comparisonText = await text();
  assert(
    dispatches.every(
      (document) =>
        comparisonText.includes(document.document_number) &&
        comparisonText.includes(document.school_name),
    ),
  );
  assert(numbers.every((number) => comparisonText.includes(number)));
  const visibleComparison = await evaluate(
    `(()=>{const table=document.querySelector('table[aria-label="Đối chiếu theo trường"]');return [...table.querySelectorAll('tbody tr')].map(row=>({date:row.cells[0].textContent.trim(),school:row.cells[1].children[0].textContent.trim(),location:row.cells[1].children[1].textContent.trim(),status:row.cells[2].textContent.trim(),totals:[...row.cells[4].children].map(total=>total.textContent.trim().replace(/\\s+/g,' ')).sort()}));})()`,
  );
  const displayedQuantity = (quantity) => {
    const fraction = String(quantity % 1_000_000n)
      .padStart(6, "0")
      .replace(/0+$/, "");
    return `${quantity / 1_000_000n}${fraction ? `,${fraction}` : ""}`;
  };
  assert.deepEqual(
    visibleComparison.sort((a, b) => a.school.localeCompare(b.school)),
    dispatches
      .map((document) => ({
        date: document.service_date.split("-").reverse().join("/"),
        school: document.school_name,
        location: document.delivery_location_name,
        status: "Khớp",
        totals: expectedUnitTotals
          .get(document.school_dispatch_release_id)
          .map(
            (total) =>
              `${total.unit_code} · PO ${displayedQuantity(total.quantity)} · PXK ${displayedQuantity(total.quantity)} · Δ 0`,
          )
          .sort(),
      }))
      .sort((a, b) => a.school.localeCompare(b.school)),
    "Visible reconciliation status and all exact Unit totals must match the frozen School documents.",
  );
  assert.deepEqual(
    (await read()).map((order) => ({
      id: order.purchase_order_id,
      number: order.document_number,
      version: order.version,
      revision: order.current_revision,
      lines: order.lines,
    })),
    after.map((order) => ({
      id: order.purchase_order_id,
      number: order.document_number,
      version: order.version,
      revision: order.current_revision,
      lines: order.lines,
    })),
    "School release must never mutate the original official PO documents.",
  );
  const shot = await connection.send("Page.captureScreenshot", {
    format: "png",
  });
  writeFileSync(
    path.join(evidence, "reconciled.png"),
    Buffer.from(shot.data, "base64"),
  );
  const report = {
    status: "PASS",
    source: execFileSync("git", ["rev-parse", "HEAD"], {
      encoding: "utf8",
    }).trim(),
    environment: "disposable GitHub runner",
    journey:
      "Auth → Allocation human Unit → note Save/readback/reload → Draft regeneration → search → publish all → public readback → reload → PO XLSX/PDF → two School PXK releases → PXK XLSX/PDF → reopen → matching public/UI reconciliation",
    poCount: after.length,
    receiptCount: 2,
    pxkCount: dispatches.length,
    pxkReceiptCount: 2,
    pxkDocumentNumbers: dispatches.map((document) => document.document_number),
    reconciliation: comparison.map((row) => ({
      school: row.school_id,
      status: row.comparison_status,
    })),
    documentNumbers: numbers,
    quantities: after.map((o) => o.lines.map((l) => l.ordered_quantity)),
  };
  writeFileSync(
    path.join(evidence, "report.json"),
    JSON.stringify(report, null, 2),
  );
  console.log(JSON.stringify(report));
} catch (error) {
  if (connection) {
    try {
      const shot = await connection.send("Page.captureScreenshot", {
        format: "png",
      });
      writeFileSync(
        path.join(evidence, "failure.png"),
        Buffer.from(shot.data, "base64"),
      );
    } catch {
      /* Preserve the original assertion when Chrome is unavailable. */
    }
  }
  throw error;
} finally {
  connection?.close();
  if (chrome && chrome.exitCode === null && chrome.signalCode === null) {
    const exited = new Promise((resolve) => chrome.once("exit", resolve));
    chrome.kill();
    await exited;
  }
  await new Promise((resolve) => server.httpServer.close(resolve));
  assert(
    path.dirname(path.resolve(profile)) === path.resolve(tmpdir()) &&
      path.basename(profile).startsWith("atlas-procurement-ci-"),
  );
  rmSync(profile, { recursive: true, force: true });
}
