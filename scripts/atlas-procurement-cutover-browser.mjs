import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import {
  readFileSync,
  writeFileSync,
  mkdirSync,
  mkdtempSync,
  rmSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import {
  DATE,
  OUTPUT,
  rowsDigest,
  snapshot,
  assertAcceptedState,
  assertSnapshotsEqual,
  saveEvidence,
} from "./atlas-procurement-cutover.mjs";
import {
  validateAtlasStagingPackageProtectedValues,
  redactAtlasStagingDiagnostic,
} from "./atlas-staging-contract.mjs";
import {
  ensurePlanningServiceDateAvailable,
  controlledInputExpression,
} from "./staging-planning-browser.mjs";

const READS = new Set([
  "get_school_master_data",
  "get_ingredient_supplier_master_data",
  "get_cooking_groups",
  "get_dispatch_groups",
  "get_confirmed_supplier_allocation_workbench",
  "get_school_catering_procurement_workbench",
  "get_school_catering_purchase_orders",
  "get_confirmed_need_review",
  "get_confirmed_need_shopping_list_export",
  "get_planning_input_preflight",
  "get_planning_inputs_workbench",
  "get_pantry_source_workbench",
]);
export function readRpcAllowed(name) {
  return READS.has(name);
}
export function observeRpcRequest(request, origin) {
  return (
    request.method === "POST" &&
    request.url.startsWith(origin + "/rest/v1/rpc/")
  );
}
export function assertOperatorOrders(read) {
  assert.equal(read.success, true, "PO_BUSINESS_SUCCESS");
  const orders = read.purchase_orders;
  assert.equal(orders.length, 17, "17_DRAFT_POS");
  assert.ok(
    orders.every((o) => o.status === "DRAFT" && o.service_date === DATE),
    "DRAFT_DATE_STATUS",
  );
  assert.equal(
    new Set(orders.map((o) => o.supplier.supplier_id + ":" + o.service_date))
      .size,
    17,
    "ONE_SUPPLIER_DATE_ONE_PO",
  );
  assert.equal(
    orders.reduce((n, o) => n + o.lines.length, 0),
    236,
    "236_PO_LINES",
  );
  assert.equal(
    new Set(
      orders.flatMap((o) =>
        o.lines.map((l) => l.purchase_order_line_revision_id),
      ),
    ).size,
    236,
    "DISTINCT_PO_LINES",
  );
}
const pause = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
async function until(fn, label, timeout = 30000) {
  const end = Date.now() + timeout;
  while (Date.now() < end) {
    const v = await fn();
    if (v) return v;
    await pause(250);
  }
  throw new Error("BROWSER_GATE_" + label);
}
async function connect(url, onEvent, onEventError) {
  const socket = new WebSocket(url);
  await new Promise((resolve, reject) => {
    socket.addEventListener("open", resolve, { once: true });
    socket.addEventListener("error", reject, { once: true });
  });
  let id = 0;
  const pending = new Map();
  socket.addEventListener("message", (event) => {
    const message = JSON.parse(String(event.data));
    if (message.id && pending.has(message.id)) {
      const task = pending.get(message.id);
      pending.delete(message.id);
      clearTimeout(task.timer);
      message.error
        ? task.reject(
            new Error(
              "BROWSER_PROTOCOL_ERROR_" +
                task.method +
                ":" +
                message.error.code +
                ":" +
                message.error.message,
            ),
          )
        : task.resolve(message.result);
    } else if (message.method)
      void Promise.resolve(onEvent(message)).catch(onEventError);
  });
  return {
    close: () => socket.close(),
    send(method, params = {}) {
      return new Promise((resolve, reject) => {
        const n = ++id,
          timer = setTimeout(() => {
            pending.delete(n);
            reject(new Error("BROWSER_PROTOCOL_TIMEOUT_" + method));
          }, 20000);
        pending.set(n, { resolve, reject, timer, method });
        socket.send(JSON.stringify({ id: n, method, params }));
      });
    },
  };
}
const allocationPanel = 'section[aria-label="Kế hoạch mua hàng"]';
const ordersPanel = allocationPanel;
const confirmedPanel = 'section[aria-label="Xác nhận nhu cầu"]';
const quantity = (value) => {
  const [whole, fraction = ""] = value.split(".");
  return (
    BigInt(whole).toString() +
    (fraction.replace(/0+$/, "") ? "," + fraction.replace(/0+$/, "") : "")
  );
};
const compact = (value) => value.replace(/\s+/g, " ").trim();

async function main() {
  mkdirSync(OUTPUT, { recursive: true });
  const evidence = JSON.parse(readFileSync(OUTPUT + "/evidence.json", "utf8"));
  assert.equal(evidence.phase_a.status, "PASS", "PHASE_A_MUST_PASS");
  const target = validateAtlasStagingPackageProtectedValues(process.env);
  const frontend = process.env.ATLAS_PLANNING_PREVIEW_URL;
  assert.equal(
    frontend,
    "https://06e87532.thuonghao-ops-erp.pages.dev/",
    "CONNECTED_FRONTEND_TARGET",
  );
  const manifest = await (await fetch(frontend + "_atlas-build.json")).json();
  assert.equal(manifest.commit, process.env.ATLAS_PLANNING_PREVIEW_SHA);
  assert.equal(manifest.dirty, false);
  assert.equal(manifest.entrypoint, "AtlasVNextConnectedApp");
  assert.equal(manifest.supabaseOrigin, target.supabaseUrl);
  evidence.phase_b = {
    status: "RUNNING",
    frontend,
    manifest,
    requests: [],
    frontend_errors: [],
    blocked_commands: [],
    representative_pos: [],
    follow_up_debt: [],
  };
  const b = evidence.phase_b;
  const profile = mkdtempSync(join(tmpdir(), "atlas-procurement-rehearsal-"));
  const chrome = spawn(
    process.env.CHROME_BIN || "google-chrome",
    [
      "--headless=new",
      "--no-sandbox",
      "--disable-dev-shm-usage",
      "--remote-debugging-port=9225",
      "--window-size=1600,1100",
      "--user-data-dir=" + profile,
      "about:blank",
    ],
    { stdio: "ignore" },
  );
  let connection,
    evaluate,
    stage = "launch";
  const requests = new Map(),
    reads = [];
  try {
    evidence.before_phase_b = await snapshot(target);
    assertAcceptedState(evidence.before_phase_b);
    assertSnapshotsEqual(evidence.after_phase_a, evidence.before_phase_b);
    saveEvidence(evidence);
    const page = await until(
      async () => {
        try {
          return (
            await (await fetch("http://127.0.0.1:9225/json/list")).json()
          ).find((p) => p.type === "page");
        } catch {
          return null;
        }
      },
      "chrome",
      15000,
    );
    connection = await connect(
      page.webSocketDebuggerUrl,
      async (event) => {
        const p = event.params;
        if (event.method === "Fetch.requestPaused") {
          const name = new URL(p.request.url).pathname.split("/").pop();
          if (!readRpcAllowed(name)) {
            b.blocked_commands.push(name);
            await connection.send("Fetch.failRequest", {
              requestId: p.requestId,
              errorReason: "BlockedByClient",
            });
          } else
            await connection.send("Fetch.continueRequest", {
              requestId: p.requestId,
            });
        }
        if (
          event.method === "Network.requestWillBeSent" &&
          observeRpcRequest(p.request, target.supabaseUrl)
        ) {
          const name = new URL(p.request.url).pathname.split("/").pop();
          let payload;
          try {
            payload = JSON.parse(p.request.postData).request.payload;
          } catch {}
          requests.set(p.requestId, { name, payload, started: p.timestamp });
        }
        if (
          event.method === "Network.responseReceived" &&
          requests.has(p.requestId)
        )
          requests.get(p.requestId).http_status = p.response.status;
        if (
          event.method === "Network.loadingFinished" &&
          requests.has(p.requestId)
        ) {
          const r = requests.get(p.requestId);
          r.elapsed_ms = (p.timestamp - r.started) * 1000;
          const raw = await connection.send("Network.getResponseBody", {
            requestId: p.requestId,
          });
          let response;
          try {
            response = JSON.parse(
              raw.base64Encoded
                ? Buffer.from(raw.body, "base64").toString()
                : raw.body,
            );
          } catch {}
          b.requests.push({
            name: r.name,
            payload: r.payload,
            http_status: r.http_status,
            elapsed_ms: r.elapsed_ms,
            success: response?.success,
            error_code: response?.error_code ?? response?.code,
          });
          reads.push({ ...r, response });
          saveEvidence(evidence);
        }
        if (event.method === "Runtime.exceptionThrown")
          b.frontend_errors.push({
            type: "exception",
            text: p.exceptionDetails.text,
            description: p.exceptionDetails.exception?.description,
          });
        if (event.method === "Runtime.consoleAPICalled" && p.type === "error")
          b.frontend_errors.push({
            type: "console",
            text: p.args.map((a) => a.value ?? a.description).join(" "),
          });
      },
      (error) => {
        b.recorder_errors ??= [];
        b.recorder_errors.push(
          redactAtlasStagingDiagnostic(error.message, Object.values(target)),
        );
        saveEvidence(evidence);
      },
    );
    const send = connection.send;
    evaluate = async (expression) => {
      const r = await send("Runtime.evaluate", {
        expression,
        returnByValue: true,
        awaitPromise: true,
      });
      if (r.exceptionDetails)
        throw new Error("BROWSER_EVALUATION_" + r.exceptionDetails.text);
      return r.result.value;
    };
    await send("Page.enable");
    await send("Network.enable");
    await send("Runtime.enable");
    await send("Fetch.enable", {
      patterns: [
        {
          urlPattern: target.supabaseUrl + "/rest/v1/rpc/*",
          requestStage: "Request",
        },
      ],
    });
    const click = async (label, scope = "document") => {
      await until(
        () =>
          evaluate(
            `(()=>{const root=${scope === "document" ? "document" : "document.querySelector(" + JSON.stringify(scope) + ")"};const e=[...(root?.querySelectorAll('button,[role="tab"]')||[])].find(e=>(e.getAttribute('aria-label')===${JSON.stringify(label)}||e.textContent.trim()===${JSON.stringify(label)})&&e.getClientRects().length&&!e.disabled);if(!e)return false;e.click();return true;})()`,
          ),
        "button_" + label,
      );
    };
    const screenshot = async (name) => {
      const r = await send("Page.captureScreenshot", { format: "png" });
      writeFileSync(
        OUTPUT + "/" + name + ".png",
        Buffer.from(r.data, "base64"),
      );
    };
    const visibleState = () =>
      evaluate(
        `({url:location.origin+location.pathname,panels:[...document.querySelectorAll('[role="tabpanel"]:not([hidden])')].map(e=>({label:e.getAttribute('aria-label'),text:e.innerText})),buttons:[...document.querySelectorAll('button')].filter(e=>e.getClientRects().length).map(e=>({label:e.getAttribute('aria-label')||e.textContent.trim(),disabled:e.disabled})),alerts:[...document.querySelectorAll('[role="alert"]')].filter(e=>e.getClientRects().length).map(e=>e.innerText)})`,
      );
    const setRange = async (panel, label) => {
      await click("Mở lịch — " + label, panel);
      const calendar =
        '[role="application"][aria-label="Lịch — ' + label + '"]';
      for (let i = 0; i < 3; i++) {
        const found = await evaluate(
          `(()=>{const c=document.querySelector(${JSON.stringify(calendar)});return Boolean(c?.querySelector('[data-part="table-cell-trigger"][data-value="${DATE}"]'));})()`,
        );
        if (found) break;
        const values = await evaluate(
          `[...document.querySelectorAll(${JSON.stringify(calendar + " [data-part=table-cell-trigger][data-value]")})].map(e=>e.getAttribute('data-value')).sort()`,
        );
        assert.ok(values.length, "DATE_CALENDAR");
        const direction = DATE < values[0] ? "prev-trigger" : "next-trigger";
        await evaluate(
          `document.querySelector(${JSON.stringify(calendar + ' [data-part="' + direction + '"]')}).click()`,
        );
      }
      for (let i = 0; i < 1; i++) {
        await until(
          () =>
            evaluate(
              `(()=>{const e=document.querySelector(${JSON.stringify(calendar + ' [data-part="table-cell-trigger"][data-value="' + DATE + '"]')});if(!e||e.getAttribute('aria-disabled')==='true')return false;e.click();return true;})()`,
            ),
          "calendar_day",
        );
      }
      await until(
        () =>
          evaluate(
            `document.querySelector(${JSON.stringify(panel)})?.innerText.includes('12/10/2026')&&!document.querySelector(${JSON.stringify(calendar)})`,
          ),
        "selected_range",
      );
    };
    const latestRead = (name) =>
      reads
        .toReversed()
        .find(
          (r) =>
            r.name === name &&
            r.payload?.date_start === DATE &&
            r.payload?.date_end === DATE,
        );
    const tableRows = (panel) =>
      evaluate(
        `[...document.querySelectorAll(${JSON.stringify(panel + " table tbody tr")})].map(tr=>[...tr.querySelectorAll('td')].map(td=>td.innerText.trim()))`,
      );
    const allocationReady = async () => {
      await until(async () => {
        const r = latestRead("get_confirmed_supplier_allocation_workbench");
        const ui = await tableRows(allocationPanel);
        return r && ui.length === 236 && r;
      }, "allocation_236");
      const r = latestRead("get_confirmed_supplier_allocation_workbench");
      assert.equal(r.http_status, 200);
      assert.equal(r.response.success, true);
      assert.equal(
        rowsDigest(r.response.rows),
        evidence.phase_a.rows_md5,
        "UI_RESPONSE_EXACT_ACCEPTED_ROWS",
      );
      const ui = await tableRows(allocationPanel);
      const expected = r.response.rows.map((row) => ({
        ingredient: row.ingredient_name,
        location: row.location_name,
        schools: row.schools.map((s) => s.school_name),
        need: quantity(row.family_quantity),
        unit: row.unit_code,
        suppliers: row.splits.map((s) => s.supplier_name).join(", "),
      }));
      for (const cells of ui) {
        const index = expected.findIndex(
          (e) =>
            e.ingredient === cells[0] &&
            e.suppliers === cells[3] &&
            compact(cells[2]) === compact(e.need + " " + e.unit) &&
            cells[1].includes(e.location) &&
            e.schools.every((s) => cells[1].includes(s)),
        );
        assert.ok(
          index >= 0,
          "UI_SCHOOL_LOCATION_INGREDIENT_QUANTITY_SUPPLIER",
        );
        expected.splice(index, 1);
        assert.equal(cells[4], "Đủ", "UI_BALANCED_STATE");
      }
      assert.equal(expected.length, 0, "UI_NO_MISSING_FAMILY");
      assert.equal(
        await evaluate(
          `document.querySelector(${JSON.stringify(allocationPanel)})?.querySelectorAll('[role="alert"]').length`,
        ),
        0,
        "ALLOCATION_ALERT",
      );
      b.allocation = {
        http_status: r.http_status,
        elapsed_ms: r.elapsed_ms,
        row_count: ui.length,
        exact_ui_values: true,
        school_location_first: false,
        deployed_columns: [
          "Nguyên liệu",
          "Trường / điểm giao",
          "Nhu cầu",
          "Nhà cung ứng",
        ],
        state_labels: "Đủ / Xem phân bổ",
        authority: "PURCHASE_HANDOFF",
      };
      saveEvidence(evidence);
    };
    stage = "sign_in";
    await send("Page.navigate", { url: frontend });
    await until(
      () => evaluate("Boolean(document.querySelector('#atlas-signin-email'))"),
      "signin",
    );
    assert.equal(await evaluate("location.origin"), new URL(frontend).origin);
    for (const [selector, value] of [
      ["#atlas-signin-email", target.testEmail],
      ["#atlas-signin-password", target.testPassword],
    ]) {
      await evaluate(
        `(()=>{const e=document.querySelector(${JSON.stringify(selector)});Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set.call(e,${JSON.stringify(value)});e.dispatchEvent(new Event('input',{bubbles:true}));})()`,
      );
    }
    await click("Đăng nhập");
    await until(
      () =>
        evaluate(
          "Boolean(!document.querySelector('#atlas-signin-email') && document.querySelector('aside'))",
        ),
      "authenticated_shell",
    );
    stage = "allocation";
    await click("Kế hoạch mua hàng");
    await until(
      () =>
        evaluate(
          `Boolean(document.querySelector(${JSON.stringify(allocationPanel)}))`,
        ),
      "allocation_panel",
    );
    await setRange(allocationPanel, "Ngày phục vụ");
    await allocationReady();
    await screenshot("01-supplier-allocation");
    stage = "refresh";
    const prior = reads.length;
    await click("Làm mới dữ liệu", allocationPanel);
    await until(
      () =>
        reads.length > prior &&
        latestRead("get_confirmed_supplier_allocation_workbench"),
      "fresh_request",
    );
    await allocationReady();
    b.refresh = "PASS";
    stage = "leave_return";
    await click("Trường học");
    await click("Kế hoạch mua hàng");
    await allocationReady();
    b.leave_return = "PASS";
    await screenshot("02-allocation-return");
    stage = "open_purchase_orders";
    await click("Đơn mua", allocationPanel);
    await until(async () => {
      const r = latestRead("get_school_catering_purchase_orders");
      return r && (await tableRows(ordersPanel)).length === 17;
    }, "orders_17");
    const poRead = latestRead("get_school_catering_purchase_orders");
    assert.equal(poRead.http_status, 200);
    assertOperatorOrders(poRead.response);
    const orders = poRead.response.purchase_orders;
    const allocationRows = evidence.phase_a.response.rows;
    for (const order of orders) {
      assert.equal(order.export_ready, false, "DRAFT_EXPORT_NOT_READY");
      assert.equal(
        order.allowed_actions.export,
        false,
        "DRAFT_EXPORT_NOT_ALLOWED",
      );
      for (const line of order.lines) {
        const row = allocationRows.find(
          (row) => row.family.family_id === line.source.family_id,
        );
        assert.ok(row, "PO_FAMILY_LINEAGE");
        const split = row.splits.find(
          (split) => split.supplier_split_id === line.source.supplier_split_id,
        );
        assert.ok(split, "PO_SPLIT_LINEAGE");
        assert.equal(
          order.supplier.supplier_id,
          split.supplier_id,
          "PO_EXACT_SUPPLIER",
        );
        assert.equal(
          line.ordered_quantity,
          split.allocated_quantity,
          "PO_EXACT_QUANTITY",
        );
        assert.equal(
          line.ingredient.ingredient_id,
          row.ingredient_id,
          "PO_EXACT_INGREDIENT",
        );
        assert.equal(line.unit.unit_id, row.unit_id, "PO_EXACT_UNIT");
        assert.equal(
          line.delivery_location.delivery_location_id,
          row.delivery_location_id,
          "PO_EXACT_LOCATION",
        );
        assert.equal(
          line.supplier_note ?? null,
          split.supplier_note ?? null,
          "PO_EXACT_SUPPLIER_NOTE",
        );
      }
    }
    b.purchase_orders = orders;
    const uiOrders = await tableRows(ordersPanel);
    assert.equal(
      uiOrders.reduce((n, cells) => n + Number(cells[3]), 0),
      236,
      "UI_236_PO_LINES",
    );
    for (const order of orders) {
      const cells = uiOrders.find((c) => c[0] === order.supplier.supplier_name);
      assert.ok(cells, "UI_SUPPLIER");
      assert.equal(cells[1], "12/10/2026");
      assert.equal(Number(cells[3]), order.lines.length);
      assert.ok(cells[4].includes("Bản nháp"), "UI_DRAFT");
    }
    await screenshot("03-draft-purchase-orders");
    const ranked = orders.toSorted((a, b) => a.lines.length - b.lines.length);
    for (const order of [ranked.at(-1), ranked[0]]) {
      stage = "representative_po_" + order.lines.length;
      await click("Xem đơn " + order.supplier.supplier_name, ordersPanel);
      const detail =
        '[role="region"][aria-label="Chi tiết đơn mua ' +
        order.supplier.supplier_name +
        '"]';
      const text = await until(
        () =>
          evaluate(
            `document.querySelector(${JSON.stringify(detail)})?.innerText`,
          ),
        "po_detail",
      );
      assert.ok(
        text.includes(order.supplier.supplier_name) &&
          text.includes("12/10/2026"),
        "PO_IDENTITY_DATE",
      );
      for (const line of order.lines) {
        assert.ok(
          text.includes(line.ingredient.ingredient_name) &&
            text.includes(line.delivery_location.location_name),
          "PO_LINE_INGREDIENT_DESTINATION",
        );
        assert.ok(
          text.includes(quantity(line.ordered_quantity)) &&
            text.includes(line.unit.unit_code),
          "PO_LINE_QUANTITY_UNIT",
        );
        if (line.supplier_note)
          assert.ok(text.includes(line.supplier_note), "PO_SUPPLIER_NOTE");
      }
      const controls = await evaluate(
        `[...document.querySelector(${JSON.stringify(detail)}).querySelectorAll('button')].map(e=>({label:e.textContent.trim(),disabled:e.disabled}))`,
      );
      assert.ok(
        !controls.some((c) => /Xuất Excel|Xuất PDF/.test(c.label)),
        "DRAFT_OFFICIAL_EXPORT_MUST_BE_UNAVAILABLE",
      );
      b.representative_pos.push({
        supplier_id: order.supplier.supplier_id,
        supplier_name: order.supplier.supplier_name,
        po_id: order.purchase_order_id,
        line_count: order.lines.length,
        identity_date_quantity_location_notes: "PASS",
        official_export: "NOT_ENABLED_DRAFT",
      });
      await screenshot("04-po-" + order.lines.length + "-lines");
      await click("Đóng", detail);
    }
    const zip = await evaluate(
      `[...document.querySelector(${JSON.stringify(ordersPanel)}).querySelectorAll('button')].filter(e=>e.textContent.includes('Xuất ZIP PO')).map(e=>({label:e.textContent.trim(),disabled:e.disabled}))`,
    );
    assert.ok(
      zip.every((control) => control.disabled),
      "DRAFT_ZIP_EXPORT_MUST_BE_DISABLED",
    );
    b.po_export = {
      status: "NOT_ENABLED_FOR_DRAFT_STATE",
      zip_control: zip[0] ?? "NOT_IMPLEMENTED_IN_PINNED_FRONTEND",
      individual_export_controls: "ABSENT",
      download_count: 0,
    };
    stage = "browser_reload";
    await send("Page.reload");
    await until(
      () =>
        evaluate(
          "Boolean(!document.querySelector('#atlas-signin-email') && document.querySelector('aside'))",
        ),
      "session_after_reload",
    );
    await click("Kế hoạch mua hàng");
    await setRange(allocationPanel, "Ngày phục vụ");
    await allocationReady();
    b.browser_reload = "PASS";
    stage = "shopping_list";
    await click("Lập nhu cầu");
    await click("Xác nhận nhu cầu");
    await until(
      () =>
        evaluate(
          `Boolean(document.querySelector(${JSON.stringify(confirmedPanel)}))`,
        ),
      "confirmed_panel",
    );
    await ensurePlanningServiceDateAvailable({
      evaluate,
      serviceDate: DATE,
      weekStart: DATE,
    });
    await evaluate(
      controlledInputExpression(
        confirmedPanel + ' select[aria-label="Ngày phục vụ"]',
        DATE,
        "select",
      ),
    );
    await until(
      () =>
        evaluate(
          `document.querySelector(${JSON.stringify(confirmedPanel)})?.innerText.includes('Nhu cầu đã chuyển sang mua hàng')`,
        ),
      "confirmed_released_read",
    );
    const shopping = await evaluate(
      `[...document.querySelector(${JSON.stringify(confirmedPanel)}).querySelectorAll('button')].filter(e=>e.textContent.trim()==='Xuất Phiếu đi chợ').map(e=>({label:e.textContent.trim(),disabled:e.disabled}))`,
    );
    assert.equal(shopping.length, 1);
    assert.equal(
      shopping[0].disabled,
      true,
      "RELEASED_SHOPPING_LIST_MUST_BE_READ_ONLY",
    );
    b.shopping_list = {
      status: "NOT_ENABLED_FOR_RELEASED_CONFIRMED_NEED",
      control: shopping[0],
      download_count: 0,
    };
    await screenshot("05-released-shopping-list");
    assert.equal(b.blocked_commands.length, 0, "NO_BUSINESS_COMMAND_ATTEMPT");
    assert.equal(b.frontend_errors.length, 0, "NO_FRONTEND_FATAL_ERROR");
    assert.ok(
      b.requests.every((r) => r.http_status === 200 && r.success === true),
      "NO_BACKEND_HTTP_BUSINESS_FAILURE",
    );
    evidence.after_phase_b = await snapshot(target);
    assertSnapshotsEqual(evidence.before_phase_b, evidence.after_phase_b);
    b.fact_delta = 0;
    b.receipt_event_audit_delta = 0;
    b.follow_up_debt.push({
      classification: "D",
      issue:
        "Pinned frontend predates the accepted School-first tables; Ingredient is still the first column. No UI rewrite was performed.",
    });
    b.status = "FUNCTIONAL_READS_PASS_ACCEPTED_UI_VERSION_GAP";
    evidence.task_status = "BLOCKED_UI_VERSION";
    evidence.phase = "REHEARSAL_COMPLETE";
    evidence.atlas_procurement_cutover_rehearsal = "NOT_PASSED";
    saveEvidence(evidence);
    console.log(
      JSON.stringify({
        phase_b: "PASS",
        allocation_rows: 236,
        draft_pos: 17,
        po_lines: 236,
        refresh: b.refresh,
        leave_return: b.leave_return,
        browser_reload: b.browser_reload,
        po_export: b.po_export.status,
        shopping_list: b.shopping_list.status,
        fact_delta: 0,
      }),
    );
  } catch (error) {
    b.status = "STOPPED";
    b.failed_stage = stage;
    b.failure = {
      message: redactAtlasStagingDiagnostic(
        error.message,
        Object.values(target),
      ),
      stack: redactAtlasStagingDiagnostic(error.stack, Object.values(target)),
    };
    if (connection) {
      try {
        const r = await connection.send("Page.captureScreenshot", {
          format: "png",
        });
        writeFileSync(OUTPUT + "/failure.png", Buffer.from(r.data, "base64"));
      } catch {}
      try {
        b.failure_ui_state = await evaluate(
          `({visible_text:document.body.innerText,buttons:[...document.querySelectorAll('button')].filter(e=>e.getClientRects().length).map(e=>({label:e.getAttribute('aria-label')||e.textContent.trim(),disabled:e.disabled}))})`,
        );
      } catch {}
    }
    try {
      evidence.after_phase_b = await snapshot(target);
    } catch {
      b.snapshot_recovery = "FAILED";
    }
    evidence.task_status = "STOPPED";
    saveEvidence(evidence);
    console.error(JSON.stringify({ stage, failure: b.failure.message }));
    process.exitCode = 1;
  } finally {
    connection?.close();
    chrome.kill("SIGTERM");
    await pause(500);
    rmSync(profile, { recursive: true, force: true });
  }
}
if (process.argv[1] === fileURLToPath(import.meta.url)) await main();
