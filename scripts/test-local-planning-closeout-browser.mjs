import assert from "node:assert/strict";
import { build, preview } from "vite";
import { execFileSync, spawn } from "node:child_process";
import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { basename, dirname, join, resolve } from "node:path";
import { randomUUID } from "node:crypto";
import { fileURLToPath } from "node:url";
import { localSql } from "./planning-closeout-local-fixture.mjs";
import { createClient } from "@supabase/supabase-js";
import ExcelJS from "exceljs";
import { editShoppingListQuantity } from "./shopping-list-browser-edit.mjs";
import { readLocalSupabaseStatus } from "./local-supabase-status.mjs";
import { certifyFirstNeedGeneration } from "./atlas-connected-need-generation.mjs";
import {
  cdp,
  prepareConfirmedNeedEdit,
  clickBusinessActionOnce,
  assertFirstSaveTransition,
  assertReopenedReview,
  preSaveGateStateExpression,
  controlledInputExpression,
  minimalPlanningAdjustment,
} from "./staging-planning-browser.mjs";

const subject = "a7400000-0000-4000-8000-000000000101";
const date = "2050-09-19";
const url =
  "http://127.0.0.1:3018/supabase/local/planning_closeout_browser.html";
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
async function until(fn, label) {
  const end = Date.now() + 45000;
  do {
    const result = await fn();
    if (result) return result;
    await sleep(100);
  } while (Date.now() < end);
  throw new Error(`LOCAL_BROWSER_${label}`);
}
export async function certifyLocalCloseoutBrowser() {
  assert(
    process.env.GITHUB_ACTIONS === "true" ||
      process.env.ATLAS_DISPOSABLE_BROWSER_CERTIFICATION === "true",
    "Explicit disposable certification required.",
  );
  assert(
    /^project_id = "thuonghao-ops-erp"$/m.test(
      readFileSync("supabase/config.toml", "utf8"),
    ),
  );
  const state = localSql(
    "select jsonb_build_object('run',r.need_generation_run_id,'batch',b.confirmed_need_batch_id,'version',b.version,'decisions',(select count(*) from atlas_planning.confirmed_need_line_decisions)) from atlas_planning.need_generation_runs r join atlas_planning.confirmed_need_batches b on b.current_need_generation_run_id=r.need_generation_run_id where r.period_start='2050-09-19'",
  )[0];
  assert.ok(
    [1, 2].includes(state.version),
    "browser harness requires a disposable unsaved fixture",
  );
  assert.equal(state.decisions, 0);
  const local = readLocalSupabaseStatus({ requireAdminKey: true });
  assert.equal(local.apiUrl, "http://127.0.0.1:54321");
  const email = "atlas.planning.operator@local.test",
    password = "Atlas-disposable-planning-only!";
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
    "Disposable Planning Auth provisioning failed.",
  );
  const operator = createClient(local.apiUrl, local.browserKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  assert(
    !(await operator.auth.signInWithPassword({ email, password })).error,
    "Public Planning Auth sign-in failed.",
  );
  async function rpc(name, request) {
    assert.ok(
      [
        "execute_need_generation",
        "get_confirmed_need_review",
        "get_planning_input_preflight",
        "save_confirmed_needs",
      ].includes(name),
    );
    const result = await operator.schema("atlas_api").rpc(name, { request });
    assert(
      !result.error && result.data,
      `Public Planning RPC transport failed: ${result.error?.code ?? name}`,
    );
    return result.data;
  }
  const command = randomUUID();
  if (state.version === 1)
    assert.equal(
      (
        await rpc("execute_need_generation", {
          contract_version: "RMVP-04.v3",
          command_id: command,
          correlation_id: randomUUID(),
          idempotency_key: `local-browser-correction:${command}`,
          expected_version: 3,
          requested_by_auth_subject: subject,
          requested_at: new Date().toISOString(),
          reason_code: "NEED_GENERATION_EXECUTED",
          reason_note: "Disposable local browser fixture",
          payload: {
            service_date: date,
            expected_current_need_generation_run_id: state.run,
          },
        })
      ).success,
      true,
    );
  const readRequest = {
    contract_version: "RMVP-05.v1",
    requested_by_auth_subject: subject,
    correlation_id: randomUUID(),
    payload: {
      confirmed_need_batch_id: state.batch,
      filters: { service_date: date },
      line_offset: 0,
      line_limit: 10000,
    },
  };
  const readReview = async () => {
    const result = await rpc("get_confirmed_need_review", readRequest);
    assert(
      result.success && result.workbench,
      "Authenticated complete Planning read failed.",
    );
    return result.workbench;
  };
  const before = await readReview();
  const anonymous = createClient(local.apiUrl, local.browserKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const deniedRead = await anonymous
    .schema("atlas_api")
    .rpc("get_confirmed_need_review", { request: readRequest });
  assert(
    deniedRead.error?.code === "42501" || deniedRead.data?.success === false,
    "Anonymous callers must not obtain the authenticated Planning review.",
  );
  assert.equal(before.lines.length, 248);
  assert.equal(before.batch_version, 2);
  assert(/^[0-9a-f-]{36}$/.test(state.batch));
  const revisionFacts = () =>
    localSql(`begin read only;
    select jsonb_object_agg(r.confirmed_need_line_id, jsonb_build_object(
      'id',r.confirmed_need_line_revision_id,'number',r.revision_number,
      'predecessor',r.predecessor_revision_id,
      'sources',(select jsonb_agg(
        (to_jsonb(c) - array['confirmed_need_line_revision_contribution_id','confirmed_need_line_revision_id','created_at'])
        || jsonb_build_object('source_theoretical_quantity',c.source_theoretical_quantity::text,
          'controlled_contribution_quantity',c.controlled_contribution_quantity::text)
        order by c.theoretical_need_line_id)
        from atlas_planning.confirmed_need_line_revision_contributions c
        where c.confirmed_need_line_revision_id=r.confirmed_need_line_revision_id)))
    from atlas_planning.confirmed_need_line_revisions r
    where r.confirmed_need_batch_id='${state.batch}'::uuid and r.is_current;
    commit;`)[0];
  const originalRevisionFacts = revisionFacts();
  const assertRevisionTransition = (
    priorReview,
    nextReview,
    priorFacts,
    adjustedId,
  ) => {
    const nextFacts = revisionFacts();
    assert.equal(Object.keys(nextFacts).length, 248);
    for (const line of nextReview.lines) {
      const prior = priorReview.lines.find(
        (value) => value.confirmed_need_line_id === line.confirmed_need_line_id,
      );
      const id = line.confirmed_need_line_id;
      const facts = nextFacts[id];
      assert(
        prior &&
          facts &&
          Array.isArray(facts.sources) &&
          facts.sources.length > 0,
      );
      assert.equal(facts.id, line.current_revision_id);
      assert.equal(facts.number, line.current_revision_number);
      assert.deepEqual(
        facts.sources,
        originalRevisionFacts[id].sources,
        "Every exact source membership, scope, Unit and contribution quantity survives Save.",
      );
      if (id === adjustedId) {
        assert.notEqual(facts.id, priorFacts[id].id);
        assert.equal(facts.predecessor, priorFacts[id].id);
        assert.equal(facts.number, priorFacts[id].number + 1);
      } else {
        assert.deepEqual(
          facts,
          priorFacts[id],
          "Untouched lines retain their exact revision and sources.",
        );
      }
      const decision = line.decision_history.find(
        (value) => value.decision_id === line.current_decision_id,
      );
      assert.equal(decision?.revision_id, facts.id);
    }
    return nextFacts;
  };
  let saves = 0;
  Object.assign(process.env, {
    VITE_ATLAS_ENVIRONMENT: "local",
    VITE_SUPABASE_URL: local.apiUrl,
    VITE_SUPABASE_PUBLISHABLE_KEY: local.browserKey,
  });
  const evidenceDir = resolve(".git/atlas-planning-browser");
  mkdirSync(evidenceDir, { recursive: true });
  for (const name of readdirSync(evidenceDir).filter((name) =>
    /\.(?:xlsx|png)$|^report\.json$/i.test(name),
  ))
    rmSync(join(evidenceDir, name));
  const buildOptions = {
    outDir: ".git/closeout-browser-dist",
    emptyOutDir: true,
    rolldownOptions: {
      input: resolve("supabase/local/planning_closeout_browser.html"),
    },
  };
  await build({ build: buildOptions });
  const server = await preview({
    build: buildOptions,
    preview: { host: "127.0.0.1", port: 3018, strictPort: true },
  });
  const profile = mkdtempSync(join(tmpdir(), "atlas-local-closeout-"));
  let chrome, connection, evaluate;
  try {
    chrome = spawn(
      process.env.CHROME_BIN ||
        (process.platform === "win32"
          ? "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe"
          : "google-chrome"),
      [
        "--headless=new",
        "--no-sandbox",
        "--disable-dev-shm-usage",
        "--remote-debugging-port=9225",
        "--window-size=1600,1100",
        `--user-data-dir=${profile}`,
        "about:blank",
      ],
      { stdio: "ignore" },
    );
    const page = await until(async () => {
      try {
        return (
          await (await fetch("http://127.0.0.1:9225/json/list")).json()
        ).find((p) => p.type === "page");
      } catch {
        return null;
      }
    }, "launch");
    connection = await cdp(page.webSocketDebuggerUrl);
    console.log("Local browser: protocol connected");
    evaluate = async (expression) => {
      const x = await connection.send("Runtime.evaluate", {
        expression,
        awaitPromise: true,
        returnByValue: true,
      });
      if (x.exceptionDetails)
        throw new Error(JSON.stringify(x.exceptionDetails));
      return x.result.value;
    };
    const click = (label) =>
      evaluate(
        `(()=>{const b=[...document.querySelectorAll('button')].find(b=>b.textContent.trim()===${JSON.stringify(label)});if(!b||b.disabled)return false;b.click();return true;})()`,
      );
    const body = () => evaluate("document.body?.innerText ?? ''");
    const workbookReady = () =>
      evaluate(
        "[...document.querySelectorAll('button')].some(b=>b.textContent.trim()==='Nhập Phiếu đi chợ'&&!b.disabled)",
      );
    const receiptState = () =>
      localSql(
        "select jsonb_build_object('handoffs',(select count(*) from atlas_planning.purchase_handoff_batches),'save_receipts',(select count(*) from atlas_core.command_receipts where command_name='save_confirmed_needs'),'decisions',(select count(*) from atlas_planning.confirmed_need_line_decisions))",
      )[0];
    const importFile = async (filename) => {
      const previousReads = await evaluate(
        "performance.getEntriesByType('resource').filter(e=>e.name.includes('/rpc/')).length",
      );
      const document = await connection.send("DOM.getDocument", {});
      const input = await connection.send("DOM.querySelector", {
        nodeId: document.root.nodeId,
        selector: 'input[type="file"][aria-label="Nhập Phiếu đi chợ .xlsx"]',
      });
      assert(input.nodeId, "Actual workbook input must be present.");
      await connection.send("DOM.setFileInputFiles", {
        nodeId: input.nodeId,
        files: [resolve(filename)],
      });
      await until(
        () =>
          evaluate(
            `Boolean(document.querySelector('button[aria-label="Mở lịch — Khoảng ngày"]:not(:disabled)'))&&performance.getEntriesByType('resource').filter(e=>e.name.includes('/rpc/')).length>${previousReads}`,
          ),
        "workbook_import_finished",
      );
    };
    await connection.send("Browser.setDownloadBehavior", {
      behavior: "allow",
      downloadPath: evidenceDir,
    });
    const open = async () => {
      console.log("Local browser: navigate");
      const previousDocument = await evaluate("performance.timeOrigin");
      await connection.send("Page.navigate", { url });
      await until(
        () =>
          evaluate(
            `performance.timeOrigin!==${JSON.stringify(previousDocument)}&&document.readyState==='complete'`,
          ),
        "new_document",
      );
      await until(
        async () =>
          (await body()).includes("Đăng nhập") ||
          (await evaluate(preSaveGateStateExpression())).rendered_rows === 248,
        "signin_or_retained_session",
      );
      if ((await body()).includes("Đăng nhập")) {
        await evaluate(
          `(()=>{const inputs=[...document.querySelectorAll('input')];const setter=Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set;for(const [i,value] of [[0,${JSON.stringify(email)}],[1,${JSON.stringify(password)}]]){setter.call(inputs[i],value);inputs[i].dispatchEvent(new Event('input',{bubbles:true}));}})()`,
        );
        assert(await click("Đăng nhập"));
      }
      console.log("Local browser: wait for rows");
      await until(async () => {
        const s = await evaluate(preSaveGateStateExpression());
        return (
          s.rendered_rows === 248 &&
          (await evaluate(
            "Boolean(document.querySelector('input[aria-label^=\"Số lượng xác nhận\"]:not(:disabled)'))",
          ))
        );
      }, "248_rows");
    };
    await open();
    assert(
      !(await workbookReady()),
      "Unsaved initial confirmations must keep workbook actions disabled.",
    );
    assert.deepEqual(receiptState(), {
      handoffs: 0,
      save_receipts: 0,
      decisions: 0,
    });
    const initialEdit = await prepareConfirmedNeedEdit({ evaluate, before });
    await clickBusinessActionOnce({
      evaluate,
      scope: 'section[aria-label="Xác nhận nhu cầu"]',
      label: "Lưu",
      gate: "initial_save_once",
    });
    saves++;
    await until(
      () => receiptState().save_receipts === 1,
      "initial_save_receipt",
    );
    await until(
      () =>
        evaluate(
          "Boolean(document.querySelector('button[aria-label=\"Mở lịch — Khoảng ngày\"]:not(:disabled)'))",
        ),
      "initial_save_readback_finished",
    );
    const confirmed = await readReview();
    const decisions = assertFirstSaveTransition({
      before,
      after: confirmed,
      adjustedLineId: initialEdit.line.confirmed_need_line_id,
      adjustedQuantity: initialEdit.proposed,
      note: initialEdit.note,
    });
    const confirmedRevisionFacts = assertRevisionTransition(
      before,
      confirmed,
      originalRevisionFacts,
      initialEdit.line.confirmed_need_line_id,
    );
    assert.deepEqual(
      receiptState(),
      { handoffs: 0, save_receipts: 1, decisions: 248 },
      "Preserve the original one-Save/248-decision contract before the worksheet journey.",
    );
    await open();
    assertReopenedReview(confirmed, await readReview());
    assert.equal(
      (await evaluate(preSaveGateStateExpression())).save_present,
      false,
    );
    await until(workbookReady, "shopping_list_ready");
    const originalFacts = receiptState();
    assert.deepEqual(originalFacts, {
      handoffs: 0,
      save_receipts: 1,
      decisions: 248,
    });
    assert(await click("Xuất Phiếu đi chợ"));
    const downloaded = await until(
      () => readdirSync(evidenceDir).find((name) => name.endsWith(".xlsx")),
      "shopping_list_download",
    );
    const originalWorkbook = join(evidenceDir, downloaded);
    await until(workbookReady, "export_finished");
    await importFile(originalWorkbook);
    assert(
      await evaluate(
        '!document.querySelector(\'section[aria-label="Xác nhận nhu cầu"] [role="alert"]\')',
      ),
      "Fresh unchanged import must complete without an error alert.",
    );
    assert.equal(
      (await evaluate(preSaveGateStateExpression())).save_present,
      false,
      "Unchanged import must stay clean.",
    );
    assert.deepEqual(
      await readReview(),
      confirmed,
      "Unchanged import must preserve every source and quantity.",
    );
    assert.deepEqual(
      receiptState(),
      originalFacts,
      "Import alone must never write decisions/receipts.",
    );
    const target = confirmed.lines.find(
      (line) =>
        line.current_decision_kind === "UNCHANGED_PROPOSAL_ACCEPTED" &&
        line.effective_policy?.status === "ACTIVE",
    );
    assert(target);
    const candidate = { lineId: target.confirmed_need_line_id };
    const proposed = minimalPlanningAdjustment(target);
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(readFileSync(originalWorkbook));
    let changedCells = 0;
    let worksheetPath, cell;
    for (const sheet of workbook.worksheets.filter(
      (sheet) => sheet.state === "visible",
    ))
      sheet.eachRow((row) => {
        if (row.getCell(7).text === candidate.lineId) {
          worksheetPath = `xl/worksheets/sheet${sheet.id}.xml`;
          cell = `D${row.number}`;
          changedCells++;
        }
      });
    assert.equal(
      changedCells,
      1,
      "Only the selected exact line's editable quantity cell changes.",
    );
    const modifiedWorkbook = join(evidenceDir, "quantity-proposal.xlsx");
    writeFileSync(
      modifiedWorkbook,
      await editShoppingListQuantity(
        readFileSync(originalWorkbook),
        worksheetPath,
        cell,
        proposed,
      ),
    );
    await importFile(modifiedWorkbook);
    assert(
      await evaluate(
        `document.querySelector('tr[data-confirmed-need-line-id="${candidate.lineId}"] input[aria-label^="Số lượng xác nhận"]')?.value===${JSON.stringify(proposed)}`,
      ),
      "The actual workbook import must propose the selected quantity.",
    );
    const proposedState = await evaluate(preSaveGateStateExpression());
    const importedQuantities = await evaluate(
      `(()=>[...document.querySelectorAll('section[aria-label="Xác nhận nhu cầu"] tr[data-confirmed-need-line-id]')].map(row=>({id:row.getAttribute('data-confirmed-need-line-id'),quantity:row.querySelector('input[aria-label^="Số lượng xác nhận"]')?.value})))()`,
    );
    assert.equal(importedQuantities.length, 248);
    const normalized = (value) =>
      String(value)
        .replace(",", ".")
        .replace(/(\.\d*?)0+$/, "$1")
        .replace(/\.$/, "");
    const confirmedQuantities = new Map(
      confirmed.lines.map((line) => [
        line.confirmed_need_line_id,
        normalized(line.confirmed_quantity_after),
      ]),
    );
    assert.deepEqual(
      importedQuantities
        .filter(
          (row) => normalized(row.quantity) !== confirmedQuantities.get(row.id),
        )
        .map((row) => row.id),
      [candidate.lineId],
      "The import changes only its selected target relative to the saved baseline; the first saved adjustment remains intact.",
    );
    assert.equal(
      proposedState.quantity_delta_rows,
      2,
      "Both confirmed and proposed adjustments remain visible against the original proposal.",
    );
    assert.equal(
      proposedState.save_enabled,
      false,
      "A file quantity change still needs an explicit operator reason.",
    );
    assert.deepEqual(
      receiptState(),
      originalFacts,
      "Modified import remains a local proposal.",
    );
    console.log("Local browser: explicit adjustment reason/note");
    const importedRow = `section[aria-label="Xác nhận nhu cầu"] tr[data-confirmed-need-line-id="${candidate.lineId}"]`;
    await evaluate(
      controlledInputExpression(
        `${importedRow} select[aria-label^="Lý do"]`,
        "OPERATIONAL_QUANTITY_ADJUSTMENT",
        "select",
      ),
    );
    await until(
      () =>
        evaluate(
          `Boolean(document.querySelector(${JSON.stringify(`${importedRow} input[aria-label^="Ghi chú"]:not(:disabled)`)}))`,
        ),
      "imported_note_ready",
    );
    const importedNote = "Disposable connected worksheet adjustment";
    await evaluate(
      controlledInputExpression(
        `${importedRow} input[aria-label^="Ghi chú"]`,
        importedNote,
      ),
    );
    await until(
      async () => (await evaluate(preSaveGateStateExpression())).save_enabled,
      "imported_adjustment_ready",
    );
    console.log("Local browser: save");
    await clickBusinessActionOnce({
      evaluate,
      scope: 'section[aria-label="Xác nhận nhu cầu"]',
      label: "Lưu",
      gate: "worksheet_successor_save_once",
    });
    saves++;
    await until(() => receiptState().save_receipts === 2, "save_receipt");
    await until(
      () =>
        evaluate(
          "[...document.querySelectorAll('button')].some(b=>b.getAttribute('aria-label')==='Làm mới dữ liệu'&&!b.disabled)",
        ),
      "save_readback_finished",
    );
    const saved = await readReview();
    assertRevisionTransition(
      confirmed,
      saved,
      confirmedRevisionFacts,
      candidate.lineId,
    );
    const sourceScope = (review) =>
      review.lines
        .map((line) => ({
          id: line.confirmed_need_line_id,
          date: line.service_date,
          customer: line.customer,
          school: line.school,
          location: line.delivery_location,
          ingredient: line.ingredient,
          unit: line.controlled_unit,
          policy: line.effective_policy,
          source_count: line.source_membership_count,
        }))
        .sort((a, b) => a.id.localeCompare(b.id));
    assert.deepEqual(
      sourceScope(saved),
      sourceScope(before),
      "Saving a quantity decision must retain stable line identity, source count, Unit and School scope; revision lineage is checked separately.",
    );
    assert.equal(saved.batch_version, confirmed.batch_version + 1);
    const confirmedById = new Map(
      confirmed.lines.map((line) => [line.confirmed_need_line_id, line]),
    );
    for (const line of saved.lines) {
      const prior = confirmedById.get(line.confirmed_need_line_id);
      assert(prior);
      assert.equal(line.theoretical_quantity, prior.theoretical_quantity);
      assert.equal(
        line.proposed_confirmed_quantity,
        prior.proposed_confirmed_quantity,
      );
      if (line.confirmed_need_line_id === candidate.lineId) {
        assert.notEqual(line.current_decision_id, prior.current_decision_id);
        assert.equal(
          line.current_decision_number,
          prior.current_decision_number + 1,
        );
        const decision = line.decision_history.find(
          (value) => value.decision_id === line.current_decision_id,
        );
        assert(decision);
        assert.equal(
          decision.predecessor_decision_id,
          prior.current_decision_id,
        );
        assert.equal(decision.decision_kind, "ADJUSTED_QUANTITY_CONFIRMED");
        assert.equal(decision.reason_code, "OPERATIONAL_QUANTITY_ADJUSTMENT");
        assert.equal(decision.reason_note, importedNote);
        assert.equal(
          decision.policy_revision_id,
          prior.effective_policy.revision_id,
        );
        assert.equal(decision.batch_version, saved.batch_version);
        assert.equal(
          line.confirmed_quantity_after
            .replace(/(\.\d*?)0+$/, "$1")
            .replace(/\.$/, ""),
          proposed.replace(",", "."),
        );
        assert.deepEqual(
          line.decision_history.filter(
            (value) => value.decision_id !== decision.decision_id,
          ),
          prior.decision_history,
          "The original explicit decision must remain immutable history.",
        );
      } else {
        assert.equal(
          line.confirmed_quantity_after,
          prior.confirmed_quantity_after,
        );
        assert.equal(line.current_decision_id, prior.current_decision_id);
        assert.deepEqual(line.decision_history, prior.decision_history);
      }
    }
    await connection.send("Page.navigate", { url: "about:blank" });
    await until(
      () => evaluate("location.href==='about:blank'"),
      "closed_document",
    );
    await open();
    assertReopenedReview(saved, await readReview());
    const reopenedRows = await evaluate(
      `(()=>{const root=document.querySelector('section[aria-label="Xác nhận nhu cầu"] table[aria-label="Nhu cầu xác nhận"]');return [...root.querySelectorAll('tbody tr')].map(row=>({id:row.getAttribute('data-confirmed-need-line-id'),quantity:row.querySelector('input[aria-label^="Số lượng xác nhận"]')?.value}));})()`,
    );
    const exactDisplay = (value) => {
      assert(
        /^\d+(?:[,.]\d{1,6})?$/.test(value),
        "Every rendered quantity must be an exact decimal.",
      );
      return value
        .replace(",", ".")
        .replace(/(\.\d*?)0+$/, "$1")
        .replace(/\.$/, "");
    };
    assert.deepEqual(
      reopenedRows
        .map((row) => ({ id: row.id, quantity: exactDisplay(row.quantity) }))
        .sort((a, b) => a.id.localeCompare(b.id)),
      saved.lines
        .map((line) => ({
          id: line.confirmed_need_line_id,
          quantity: exactDisplay(line.confirmed_quantity_after),
        }))
        .sort((a, b) => a.id.localeCompare(b.id)),
      "All248 visible reloaded quantities must match the persisted public read, including the imported adjustment.",
    );
    assert.equal(
      (await evaluate(preSaveGateStateExpression())).save_present,
      false,
    );
    assert.equal(saves, 2);
    await until(workbookReady, "reopened_shopping_list_ready");
    await importFile(originalWorkbook);
    assert(
      (await body()).includes("Tải lại") &&
        ((await body()).includes("Phiếu đi chợ mới") ||
          (await body()).includes("xuất file mới")),
      "The now-stale workbook must show specific recovery guidance.",
    );
    assert.equal(
      (await evaluate(preSaveGateStateExpression())).save_present,
      false,
    );
    assertReopenedReview(saved, await readReview());
    const evidence = receiptState();
    assert.deepEqual(evidence, {
      handoffs: 0,
      save_receipts: 2,
      decisions: 249,
    });
    const screenshot = await connection.send("Page.captureScreenshot", {
      format: "png",
    });
    writeFileSync(
      join(evidenceDir, "reopened.png"),
      Buffer.from(screenshot.data, "base64"),
    );
    const generation = await certifyFirstNeedGeneration({
      evaluate,
      until,
      rpc,
      sql: localSql,
      subject,
      open,
      readOriginal: readReview,
      original: saved,
      originalReceiptState: evidence,
      receiptState,
    });
    const generatedScreenshot = await connection.send(
      "Page.captureScreenshot",
      { format: "png" },
    );
    writeFileSync(
      join(evidenceDir, "generated-reopened.png"),
      Buffer.from(generatedScreenshot.data, "base64"),
    );
    const report = {
      status: "LOCAL_BROWSER_SAVE_REOPEN_PASS",
      ...decisions,
      ...evidence,
      saveClicks: saves,
      preSave: initialEdit.preSave,
      worksheetSuccessorDecisions: 1,
      firstNeedGeneration: generation,
      source: execFileSync("git", ["rev-parse", "HEAD"], {
        encoding: "utf8",
      }).trim(),
      journey:
        "Public Auth → initial248-line Save/reopen → fresh XLSX download → unchanged import → one file quantity proposal → explicit reason/note → one successor Save → public readback → reopen → stale-file rejection → native fresh-day first generation →248 rows/304 memberships → explicit unconfirmed Discard → new-document reselect/reopen",
      transport:
        "actual public Auth/PostgREST; real connected React/Chakra workbench and shopping service; disposable runner only",
    };
    writeFileSync(
      join(evidenceDir, "report.json"),
      JSON.stringify(report, null, 2),
    );
    console.log(JSON.stringify(report));
    return report;
  } catch (error) {
    if (connection) {
      try {
        const screenshot = await connection.send("Page.captureScreenshot", {
          format: "png",
        });
        writeFileSync(
          join(evidenceDir, "failure.png"),
          Buffer.from(screenshot.data, "base64"),
        );
      } catch {
        /* Preserve the original failed assertion. */
      }
    }
    if (evaluate)
      console.error(
        await evaluate(
          "({url:location.origin+location.pathname,text:document.body.innerText.slice(0,3500),buttons:[...document.querySelectorAll('button')].map(b=>({label:b.textContent.trim()||b.getAttribute('aria-label'),disabled:b.disabled}))})",
        ).catch(() => ({ readFailed: true })),
      );
    throw error;
  } finally {
    connection?.close();
    if (chrome) {
      chrome.kill();
      await new Promise((resolve) => chrome.once("exit", resolve));
    }
    await new Promise((resolve) => server.httpServer.close(resolve));
    assert(
      dirname(resolve(profile)) === resolve(tmpdir()) &&
        basename(profile).startsWith("atlas-local-closeout-"),
    );
    rmSync(profile, {
      recursive: true,
      force: true,
      maxRetries: 5,
      retryDelay: 200,
    });
  }
}
if (process.argv[1] === fileURLToPath(import.meta.url))
  await certifyLocalCloseoutBrowser();
