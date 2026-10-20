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
import {
  supplierQuantityFootprint,
  schoolQuantityFootprint,
} from "./atlas-procurement-browser-coverage.mjs";

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
  return readFileSync(absolute, "utf8").replace(/^\\ir\s+(.+)$/gm, (_, name) =>
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
  /\.(?:zip|png)$|^report\.json$/i.test(name),
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
  assert.deepEqual(
    supplierQuantityFootprint(before),
    supplierQuantityFootprint(initialOrders),
    "Draft regeneration must preserve each PO's supplier/family/scope and exact quantity.",
  );
  assert.deepEqual(
    schoolQuantityFootprint(before, expectedSchools),
    schoolQuantityFootprint(initialOrders, initialSchools),
    "Draft regeneration must preserve aggregate School/date/location/ingredient/Unit/family quantities across all suppliers.",
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
  const shot = await connection.send("Page.captureScreenshot", {
    format: "png",
  });
  writeFileSync(
    path.join(evidence, "released.png"),
    Buffer.from(shot.data, "base64"),
  );
  const report = {
    status: "PASS",
    source: execFileSync("git", ["rev-parse", "HEAD"], {
      encoding: "utf8",
    }).trim(),
    environment: "disposable GitHub runner",
    journey:
      "Auth → Allocation human Unit → note Save/readback/reload → Draft regeneration → search → publish all → public readback → reload → XLSX/PDF",
    poCount: after.length,
    receiptCount: 2,
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
