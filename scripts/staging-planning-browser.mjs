import { spawn } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
const PREVIEW = "https://0d969e3b.thuonghao-ops-erp.pages.dev/";
const PHASE_TABLIST = '[role="tablist"][aria-label="Giai đoạn lập nhu cầu"]';
const CONFIRMED_WORKBENCH = 'section[aria-label="Xác nhận nhu cầu"]';
const SOURCES_WORKBENCH = 'section[aria-label="Nguồn lập nhu cầu"]';
const CONFIRMED_TABLE = 'table[aria-label="Nhu cầu xác nhận"]';
const REHEARSAL_WEEK = "14/09/2026 – 20/09/2026";
const REHEARSAL_SERVICE_DATE = "2026-09-17";
const REHEARSAL_WEEK_DATES = [
  "2026-09-14",
  "2026-09-15",
  "2026-09-16",
  "2026-09-17",
  "2026-09-18",
  "2026-09-19",
  "2026-09-20",
];
const REHEARSAL_NOTE =
  "Owner-approved Staging closeout verification: one minimal quantity edit; no Procurement release.";
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function until(fn, label, timeout = 60000, interval = 300) {
  const end = Date.now() + timeout;
  while (Date.now() < end) {
    const v = await fn();
    if (v) return v;
    await sleep(interval);
  }
  throw new Error(`BROWSER_GATE_${label}`);
}

export async function navigateToConfirmedNeed({
  evaluate,
  timeout = 60000,
  interval = 300,
}) {
  await navigateUntil({
    evaluate,
    scope: PHASE_TABLIST,
    role: "tab",
    label: "Xác nhận nhu cầu",
    destination: CONFIRMED_WORKBENCH,
    timeout,
    interval,
  });
  await until(
    () =>
      evaluate(
        `(()=>{const tab=[...document.querySelectorAll(${JSON.stringify(`${PHASE_TABLIST} [role="tab"]`)})].find(e=>e.textContent.trim()==='Xác nhận nhu cầu');return Boolean(document.querySelector(${JSON.stringify(CONFIRMED_WORKBENCH)})&&tab?.getAttribute('aria-selected')==='true');})()`,
      ),
    "confirmed_need_phase_state",
    timeout,
    interval,
  );
}

async function navigateToPlanningSources({ evaluate }) {
  await navigateUntil({
    evaluate,
    scope: PHASE_TABLIST,
    role: "tab",
    label: "Nguồn lập nhu cầu",
    destination: SOURCES_WORKBENCH,
  });
}
export async function navigateUntil({
  evaluate,
  scope,
  role,
  label,
  destination,
  timeout = 60000,
  interval = 300,
}) {
  const selector = `${scope} ${role === "tab" ? '[role="tab"]' : "button"}`;
  const end = Date.now() + timeout;
  while (Date.now() < end) {
    if (
      await evaluate(
        `Boolean(document.querySelector(${JSON.stringify(destination)}))`,
      )
    )
      return;
    await evaluate(
      `(()=>{const e=[...document.querySelectorAll(${JSON.stringify(selector)})].find(e=>e.textContent.trim()===${JSON.stringify(label)}&&!e.disabled&&e.getAttribute('aria-disabled')!=='true');if(!e)return false;e.click();return true;})()`,
    );
    if (
      await evaluate(
        `Boolean(document.querySelector(${JSON.stringify(destination)}))`,
      )
    )
      return;
    await sleep(interval);
  }
  throw new Error(`BROWSER_GATE_navigation_${role}_${label}`);
}

export async function ensurePlanningServiceDateAvailable({
  evaluate,
  serviceDate,
  weekStart,
  timeout = 60000,
  interval = 300,
}) {
  const serviceDateSelector = 'select[aria-label="Ngày phục vụ"]';
  const weekInputSelector = 'input[aria-label="Tuần phục vụ"]';
  const calendarTriggerSelector =
    'button[data-part="trigger"][aria-label="Mở lịch — Tuần phục vụ"]';
  const calendarSelector =
    '[role="application"][aria-label="Lịch — Tuần phục vụ"]';
  const daySelector =
    '[data-part="table-cell-trigger"][data-view="day"][data-value]';
  const hasServiceDate = () =>
    evaluate(
      `(()=>{const s=document.querySelector(${JSON.stringify(serviceDateSelector)});return Boolean(s&&!s.disabled&&[...s.options].some(o=>o.value===${JSON.stringify(serviceDate)}));})()`,
    );
  if (await hasServiceDate()) return;

  const weekInputReady = await evaluate(
    `(()=>{const e=document.querySelector(${JSON.stringify(weekInputSelector)});return Boolean(e&&!e.disabled);})()`,
  );
  if (!weekInputReady) throw new Error("BROWSER_GATE_rehearsal_week_input");
  const opened = await evaluate(
    `(()=>{const e=document.querySelector(${JSON.stringify(calendarTriggerSelector)});if(!e||e.disabled||e.getAttribute('aria-disabled')==='true')return false;e.click();return true;})()`,
  );
  if (!opened) throw new Error("BROWSER_GATE_rehearsal_week_trigger");

  const firstValues = await until(
    () =>
      evaluate(
        `(()=>{const root=document.querySelector(${JSON.stringify(calendarSelector)});if(!root)return null;const values=[...root.querySelectorAll(${JSON.stringify(daySelector)})].map(e=>e.getAttribute('data-value')).filter(Boolean).sort();return values.length?values:null;})()`,
      ),
    "rehearsal_week_calendar",
    timeout,
    interval,
  );
  const middle = firstValues[Math.floor(firstValues.length / 2)];
  const monthDistance = (left, right) => {
    const [leftYear, leftMonth] = left.split("-").map(Number);
    const [rightYear, rightMonth] = right.split("-").map(Number);
    return (leftYear - rightYear) * 12 + leftMonth - rightMonth;
  };
  const maxNavigation = Math.abs(monthDistance(weekStart, middle)) + 2;

  const end = Date.now() + timeout;
  let navigationCount = 0;
  while (Date.now() < end && navigationCount <= maxNavigation) {
    if (await hasServiceDate()) return;
    const state = await evaluate(
      `(()=>{const root=document.querySelector(${JSON.stringify(calendarSelector)});if(!root)return null;const values=[...root.querySelectorAll(${JSON.stringify(daySelector)})].map(e=>e.getAttribute('data-value')).filter(Boolean).sort();return values.length?{values,target:Boolean(root.querySelector(${JSON.stringify(`${daySelector}[data-value="${weekStart}"]`)}))}:null;})()`,
    );
    if (!state) {
      await sleep(interval);
      continue;
    }
    if (state.target) {
      const selected = await evaluate(
        `(()=>{const root=document.querySelector(${JSON.stringify(calendarSelector)});const target=root?.querySelector(${JSON.stringify(`${daySelector}[data-value="${weekStart}"]`)});if(!target||target.getAttribute('aria-disabled')==='true')return false;target.click();return true;})()`,
      );
      if (!selected) throw new Error("BROWSER_GATE_rehearsal_week_selection");
      const expectedWeekEnd = (() => {
        const date = new Date(`${weekStart}T12:00:00Z`);
        date.setUTCDate(date.getUTCDate() + 6);
        return date.toISOString().slice(0, 10);
      })();
      const viDate = (date) => date.split("-").reverse().join("/");
      const expectedWeek = `${viDate(weekStart)} – ${viDate(expectedWeekEnd)}`;
      const expectedOptions = Array.from({ length: 7 }, (_, index) => {
        const date = new Date(`${weekStart}T12:00:00Z`);
        date.setUTCDate(date.getUTCDate() + index);
        return date.toISOString().slice(0, 10);
      });
      await until(
        () =>
          evaluate(
            `(()=>{const week=document.querySelector(${JSON.stringify(weekInputSelector)});const service=document.querySelector(${JSON.stringify(serviceDateSelector)});return Boolean(week?.value===${JSON.stringify(expectedWeek)}&&service&&!service.disabled&&JSON.stringify([...service.options].map(o=>o.value))===${JSON.stringify(JSON.stringify(expectedOptions))}&&[...service.options].some(o=>o.value===${JSON.stringify(serviceDate)}));})()`,
          ),
        "service_date",
        Math.max(0, end - Date.now()),
        interval,
      );
      return;
    }
    const direction =
      weekStart < state.values[0]
        ? "prev-trigger"
        : weekStart > state.values[state.values.length - 1]
          ? "next-trigger"
          : null;
    if (!direction) throw new Error("BROWSER_GATE_rehearsal_week_navigation");
    if (navigationCount >= maxNavigation)
      throw new Error("BROWSER_GATE_rehearsal_week_navigation_bound");
    const beforeSignature = state.values.join(",");
    const navigated = await evaluate(
      `(()=>{const root=document.querySelector(${JSON.stringify(calendarSelector)});const nav=root?.querySelector(${JSON.stringify(`[data-part="${direction}"]`)});if(!nav||nav.disabled||nav.getAttribute('aria-disabled')==='true')return false;nav.click();return true;})()`,
    );
    if (!navigated) throw new Error("BROWSER_GATE_rehearsal_week_navigation");
    navigationCount += 1;
    await until(
      () =>
        evaluate(
          `(()=>{const root=document.querySelector(${JSON.stringify(calendarSelector)});const values=root?[...root.querySelectorAll(${JSON.stringify(daySelector)})].map(e=>e.getAttribute('data-value')).filter(Boolean).sort():[];return values.length&&values.join(',')!==${JSON.stringify(beforeSignature)};})()`,
        ),
      "rehearsal_week_navigation_settled",
      Math.max(0, end - Date.now()),
      interval,
    );
  }
  throw new Error("BROWSER_GATE_service_date");
}
async function cdp(url) {
  const socket = new WebSocket(url);
  await new Promise((yes, no) => {
    socket.addEventListener("open", yes, { once: true });
    socket.addEventListener("error", no, { once: true });
  });
  let id = 0;
  const pending = new Map();
  socket.addEventListener("message", (e) => {
    const p = JSON.parse(String(e.data));
    if (p.id && pending.has(p.id)) {
      const task = pending.get(p.id);
      pending.delete(p.id);
      clearTimeout(task.timer);
      p.error
        ? task.no(new Error("BROWSER_PROTOCOL_ERROR"))
        : task.yes(p.result);
    }
  });
  return {
    close: () => socket.close(),
    send(method, params = {}) {
      return new Promise((yes, no) => {
        const n = ++id;
        const timer = setTimeout(() => {
          pending.delete(n);
          no(new Error("BROWSER_PROTOCOL_TIMEOUT"));
        }, 20000);
        pending.set(n, { yes, no, timer });
        socket.send(JSON.stringify({ id: n, method, params }));
      });
    },
  };
}
const exact = (v) => {
  const [w, d = ""] = String(v).split(".");
  return BigInt(w) * 1000000n + BigInt((d + "000000").slice(0, 6));
};

export function assertFirstSaveTransition({
  before,
  after,
  adjustedLineId,
  adjustedQuantity,
  note,
}) {
  const fail = () => {
    throw new Error("BROWSER_FIRST_SAVE_CONTRACT_FAILED");
  };
  if (
    before?.lines?.length !== 248 ||
    after?.lines?.length !== 248 ||
    after.batch_version !== before.batch_version + 1 ||
    before.lines.some((line) => line.current_decision_id !== null)
  )
    fail();
  const beforeById = new Map(
    before.lines.map((line) => [line.confirmed_need_line_id, line]),
  );
  if (
    new Set(beforeById.keys()).size !== 248 ||
    new Set(after.lines.map((line) => line.confirmed_need_line_id)).size !==
      248 ||
    after.lines.some((line) => !beforeById.has(line.confirmed_need_line_id))
  )
    fail();

  let businessQuantityAdjustments = 0;
  let proposalAcceptances = 0;
  for (const line of after.lines) {
    const prior = beforeById.get(line.confirmed_need_line_id);
    const decision = line.decision_history?.find(
      (item) => item.decision_id === line.current_decision_id,
    );
    if (
      !prior ||
      !line.current_decision_id ||
      line.current_decision_number !== 1 ||
      !decision ||
      decision.decision_number !== 1 ||
      decision.predecessor_decision_id !== null ||
      exact(line.theoretical_quantity) !== exact(prior.theoretical_quantity) ||
      exact(line.proposed_confirmed_quantity) !==
        exact(prior.proposed_confirmed_quantity) ||
      line.confirmed_quantity_after == null ||
      exact(decision.confirmed_quantity_after) !==
        exact(line.confirmed_quantity_after)
    )
      fail();
    const adjusted =
      exact(line.confirmed_quantity_after) !==
      exact(line.proposed_confirmed_quantity);
    if (adjusted) {
      businessQuantityAdjustments += 1;
      if (
        line.confirmed_need_line_id !== adjustedLineId ||
        exact(line.confirmed_quantity_after) !== exact(adjustedQuantity) ||
        decision.reason_code !== "OPERATIONAL_QUANTITY_ADJUSTMENT" ||
        decision.reason_note !== note
      )
        fail();
    } else {
      proposalAcceptances += 1;
      if (
        line.confirmed_need_line_id === adjustedLineId ||
        decision.reason_code !== "PROPOSAL_ACCEPTED"
      )
        fail();
    }
  }
  if (businessQuantityAdjustments !== 1 || proposalAcceptances !== 247) fail();
  return {
    newDecisions: 248,
    businessQuantityAdjustments,
    proposalAcceptances,
  };
}

export function safeAuthoritativeDiagnostic(workbench) {
  if (!workbench) return { batch_exists: false };
  return {
    batch_exists: true,
    batch_version: workbench.batch_version,
    line_count: workbench.lines?.length ?? null,
    editing_allowed: workbench.editing_allowed,
    blocker_count: workbench.blockers?.length ?? null,
    has_more: workbench.pagination?.has_more ?? null,
  };
}

export function assertPreGenerateGate(state) {
  if (
    state?.week_value !== REHEARSAL_WEEK ||
    state.service_date !== REHEARSAL_SERVICE_DATE ||
    JSON.stringify(state.service_options) !==
      JSON.stringify(REHEARSAL_WEEK_DATES) ||
    !state.service_enabled ||
    !state.generate_present ||
    !state.generate_enabled ||
    state.update_present ||
    state.rendered_rows !== 0
  )
    throw new Error("BROWSER_GATE_pre_generate");
}

export function assertPreSaveGate(state) {
  if (
    state?.rendered_rows !== 248 ||
    state.quantity_adjustment_rows !== 1 ||
    state.adjustment_reason_rows !== 1 ||
    state.nonblank_note_rows !== 1 ||
    state.invalid_controls !== 0 ||
    !state.save_present ||
    !state.save_enabled
  )
    throw new Error("BROWSER_GATE_pre_save");
}

export function preSaveGateStateExpression() {
  return `(()=>{const root=document.querySelector(${JSON.stringify(CONFIRMED_WORKBENCH)});const rows=root?[...root.querySelectorAll(${JSON.stringify(`${CONFIRMED_TABLE} tbody tr`)})]:[];const save=root?[...root.querySelectorAll('button')].find(e=>e.textContent.trim()==='Lưu'):null;const deltaText=r=>(r.children[4]?.textContent??'').trim();const isNonzeroDelta=r=>{const text=deltaText(r);const value=Number(text.replaceAll('.','').replace(',','.'));return Number.isFinite(value)&&value!==0;};return {rendered_rows:rows.length,quantity_delta_rows:rows.filter(r=>deltaText(r)!=='—').length,quantity_adjustment_rows:rows.filter(isNonzeroDelta).length,adjustment_reason_rows:rows.filter(r=>r.querySelector('select[aria-label^="Lý do"]')?.value==='OPERATIONAL_QUANTITY_ADJUSTMENT').length,nonblank_note_rows:rows.filter(r=>(r.querySelector('input[aria-label^="Ghi chú"]')?.value??'').trim()!=='').length,invalid_controls:root?.querySelectorAll('[aria-invalid="true"]').length??0,save_present:Boolean(save),save_enabled:Boolean(save&&!save.disabled&&save.getAttribute('aria-disabled')!=='true')};})()`;
}
export async function verifyPlanningBrowser({ target, readReview, nextCent }) {
  if (target.projectRef !== "rnzxmxiiqgtdevzregff")
    throw new Error("BROWSER_TARGET_REJECTED");
  const profile = mkdtempSync(join(tmpdir(), "atlas-planning-browser-"));
  const chrome = spawn(
    process.env.CHROME_BIN || "google-chrome",
    [
      "--headless=new",
      "--no-sandbox",
      "--disable-dev-shm-usage",
      "--remote-debugging-port=9224",
      "--window-size=1600,1100",
      `--user-data-dir=${profile}`,
      "about:blank",
    ],
    { stdio: "ignore" },
  );
  let connection;
  let evaluate;
  let stage = "launch";
  try {
    const page = await until(
      async () => {
        try {
          return (
            await (await fetch("http://127.0.0.1:9224/json/list")).json()
          ).find((p) => p.type === "page");
        } catch {
          return null;
        }
      },
      stage,
      15000,
    );
    connection = await cdp(page.webSocketDebuggerUrl);
    const send = connection.send;
    evaluate = async (expression) => {
      const x = await send("Runtime.evaluate", {
        expression,
        returnByValue: true,
        awaitPromise: true,
      });
      if (x.exceptionDetails) throw new Error("BROWSER_EVALUATION_FAILED");
      return x.result.value;
    };
    const click = async (label) => {
      await until(
        () =>
          evaluate(
            `Boolean([...document.querySelectorAll('button,[role="tab"]')].find(b=>b.textContent.trim()===${JSON.stringify(label)}&&!b.disabled))`,
          ),
        `button_${label}`,
      );
      await evaluate(
        `[...document.querySelectorAll('button,[role="tab"]')].find(b=>b.textContent.trim()===${JSON.stringify(label)}&&!b.disabled).click()`,
      );
    };
    const input = async (selector, value, kind = "input") => {
      await evaluate(
        `(()=>{const e=document.querySelector(${JSON.stringify(selector)});if(!e||e.disabled||e.readOnly)throw Error('input');e.focus();Object.getOwnPropertyDescriptor(${kind === "select" ? "HTMLSelectElement" : "HTMLInputElement"}.prototype,'value').set.call(e,${JSON.stringify(value)});e.dispatchEvent(new Event(${kind === "select" ? "'change'" : "'input'"},{bubbles:true}));})()`,
      );
    };
    const logNavigation = async (transition) => {
      const state = await evaluate(
        `({transition:${JSON.stringify(transition)},url:location.href,controls:[...document.querySelectorAll('nav[aria-label="Điều hướng Atlas"] button,[role="tablist"][aria-label="Giai đoạn lập nhu cầu"],[role="tablist"][aria-label="Giai đoạn lập nhu cầu"] [role="tab"]')].map(e=>({tag:e.tagName.toLowerCase(),role:e.getAttribute('role')||e.tagName.toLowerCase(),label:e.getAttribute('aria-label')||e.textContent.trim(),disabled:Boolean(e.disabled)||e.getAttribute('aria-disabled')==='true',selected:e.getAttribute('aria-selected')==='true'}))})`,
      );
      console.log(JSON.stringify({ browser_navigation: state }));
    };
    const oneShotButton = async (scope, label, gate) => {
      const clicked = await evaluate(
        `(()=>{const root=document.querySelector(${JSON.stringify(scope)});const button=root?[...root.querySelectorAll('button')].find(e=>e.textContent.trim()===${JSON.stringify(label)}&&!e.disabled&&e.getAttribute('aria-disabled')!=='true'):null;if(!button)return false;button.click();return true;})()`,
      );
      if (!clicked) throw new Error(`BROWSER_GATE_${gate}`);
    };
    await send("Page.enable");
    await send("Runtime.enable");
    stage = "authenticated_preview";
    await send("Page.navigate", { url: PREVIEW });
    await until(
      () => evaluate(`Boolean(document.querySelector('#atlas-signin-email'))`),
      "signin_form",
    );
    await logNavigation("signin_form");
    if ((await evaluate("location.origin")) !== new URL(PREVIEW).origin)
      throw new Error("BROWSER_ORIGIN_MISMATCH");
    await input("#atlas-signin-email", target.testEmail);
    await input("#atlas-signin-password", target.testPassword);
    await click("Đăng nhập");
    await until(
      () =>
        evaluate(
          `Boolean(document.querySelector('nav[aria-label="Điều hướng Atlas"]'))`,
        ),
      "authenticated_shell",
    );
    await logNavigation("authenticated");
    stage = "planning_navigation";
    await navigateUntil({
      evaluate,
      scope: 'nav[aria-label="Điều hướng Atlas"]',
      role: "button",
      label: "Lập nhu cầu",
      destination: '[role="tablist"][aria-label="Giai đoạn lập nhu cầu"]',
    });
    await logNavigation("planning_open");
    stage = "confirmed_need_navigation";
    await navigateToConfirmedNeed({
      evaluate,
    });
    await logNavigation("confirmed_need_open");
    const logServiceDateState = async (transition) => {
      const state = await evaluate(
        `(()=>{const week=document.querySelector('input[aria-label="Tuần phục vụ"]');const service=document.querySelector('select[aria-label="Ngày phục vụ"]');return {transition:${JSON.stringify(transition)},week_value:week?.value??null,week_disabled:Boolean(week?.disabled),service_date:service?.value??null,service_disabled:Boolean(service?.disabled),service_options:service?[...service.options].map(o=>o.value):[]};})()`,
      );
      console.log(JSON.stringify({ browser_service_date: state }));
    };
    stage = "service_date";
    await logServiceDateState("before_rehearsal_week");
    await ensurePlanningServiceDateAvailable({
      evaluate,
      serviceDate: REHEARSAL_SERVICE_DATE,
      weekStart: "2026-09-14",
    });
    await logServiceDateState("rehearsal_week_ready");
    await input(
      `${CONFIRMED_WORKBENCH} select[aria-label="Ngày phục vụ"]`,
      REHEARSAL_SERVICE_DATE,
      "select",
    );
    const preGenerate = await until(
      () =>
        evaluate(
          `(()=>{const root=document.querySelector(${JSON.stringify(CONFIRMED_WORKBENCH)});const week=root?.querySelector('input[aria-label="Tuần phục vụ"]');const service=root?.querySelector('select[aria-label="Ngày phục vụ"]');const buttons=root?[...root.querySelectorAll('button')]:[];const generate=buttons.find(e=>e.textContent.trim()==='Tạo nhu cầu');const update=buttons.find(e=>e.textContent.trim()==='Cập nhật nhu cầu');return root?{week_value:week?.value??null,service_date:service?.value??null,service_options:service?[...service.options].map(o=>o.value):[],service_enabled:Boolean(service&&!service.disabled),generate_present:Boolean(generate),generate_enabled:Boolean(generate&&!generate.disabled&&generate.getAttribute('aria-disabled')!=='true'),update_present:Boolean(update),rendered_rows:root.querySelectorAll(${JSON.stringify(`${CONFIRMED_TABLE} tbody tr`)}).length}:null;})()`,
        ),
      "pre_generate_surface",
    );
    console.log(JSON.stringify({ browser_pre_generate: preGenerate }));
    assertPreGenerateGate(preGenerate);
    stage = "generate_once";
    await oneShotButton(CONFIRMED_WORKBENCH, "Tạo nhu cầu", "generate_once");
    await until(
      () =>
        evaluate(
          `document.querySelectorAll(${JSON.stringify(`${CONFIRMED_TABLE} tbody tr`)}).length===248`,
        ),
      "248_rendered_rows",
    );
    const before = await readReview();
    if (
      before?.lines.length !== 248 ||
      before.pagination.has_more ||
      before.blockers.length ||
      !before.editing_allowed ||
      before.source_kind !== "NEED_GENERATION" ||
      before.service_period?.period_start !== REHEARSAL_SERVICE_DATE ||
      before.service_period?.period_end !== REHEARSAL_SERVICE_DATE ||
      before.lines.some((line) => line.current_decision_id !== null)
    )
      throw new Error("BROWSER_GENERATION_READBACK_FAILED");
    const candidate = await evaluate(
      `(()=>{const rows=[...document.querySelectorAll(${JSON.stringify(`${CONFIRMED_TABLE} tbody tr`)})];const index=rows.findIndex(r=>r.children[1].textContent.trim()==='kg'&&r.querySelector('input[aria-label^="Số lượng xác nhận"]')&&!r.querySelector('input[aria-label^="Số lượng xác nhận"]').disabled&&!r.querySelector('input[aria-label^="Số lượng xác nhận"]').readOnly);if(index<0)return null;const r=rows[index];return {index,ingredient:r.children[0].children[0].textContent,recipient:r.children[0].children[1].textContent};})()`,
    );
    if (!candidate) throw new Error("NO_EDITABLE_KG_REHEARSAL_ROW");
    const line = before.lines.find(
      (l) =>
        l.ingredient.name === candidate.ingredient &&
        candidate.recipient ===
          `${l.school.name} · ${l.delivery_location.name}`,
    );
    if (!line) throw new Error("BROWSER_ROW_IDENTITY_MISMATCH");
    const proposed = nextCent(
      line.confirmed_quantity_after ?? line.proposed_confirmed_quantity,
    );
    const row = `${CONFIRMED_TABLE} tbody tr:nth-child(${candidate.index + 1})`;
    stage = "quantity_edit";
    await input(`${row} input[aria-label^="Số lượng xác nhận"]`, proposed);
    await input(
      `${row} select[aria-label^="Lý do"]`,
      "OPERATIONAL_QUANTITY_ADJUSTMENT",
      "select",
    );
    await until(
      () =>
        evaluate(
          `Boolean(document.querySelector(${JSON.stringify(`${row} input[aria-label^="Ghi chú"]`)}))`,
        ),
      "note_input",
    );
    await input(`${row} input[aria-label^="Ghi chú"]`, REHEARSAL_NOTE);
    const preSave = await evaluate(preSaveGateStateExpression());
    console.log(JSON.stringify({ browser_pre_save: preSave }));
    assertPreSaveGate(preSave);
    stage = "save_once";
    await oneShotButton(CONFIRMED_WORKBENCH, "Lưu", "save_once");
    const after = await until(async () => {
      try {
        const workbench = await readReview();
        return workbench && workbench.batch_version > before.batch_version
          ? workbench
          : null;
      } catch {
        return null;
      }
    }, "saved_readback");
    const firstSave = assertFirstSaveTransition({
      before,
      after,
      adjustedLineId: line.confirmed_need_line_id,
      adjustedQuantity: proposed,
      note: REHEARSAL_NOTE,
    });
    stage = "reopen";
    await until(
      () =>
        evaluate(
          `![...document.querySelectorAll('button')].some(b=>b.textContent.trim()==='Lưu')`,
        ),
      "save_settled",
    );
    await navigateToPlanningSources({ evaluate });
    await navigateToConfirmedNeed({ evaluate });
    await until(
      () =>
        evaluate(
          `document.querySelectorAll('table[aria-label="Nhu cầu xác nhận"] tbody tr').length===248`,
        ),
      "reopened_rows",
    );
    const reopened = await readReview();
    if (JSON.stringify(reopened.lines) !== JSON.stringify(after.lines))
      throw new Error("REOPEN_READBACK_CHANGED");
    assertFirstSaveTransition({
      before,
      after: reopened,
      adjustedLineId: line.confirmed_need_line_id,
      adjustedQuantity: proposed,
      note: REHEARSAL_NOTE,
    });
    if (process.env.RUNNER_TEMP) {
      const screenshot = await send("Page.captureScreenshot", {
        format: "png",
        captureBeyondViewport: false,
      });
      writeFileSync(
        join(process.env.RUNNER_TEMP, "atlas-planning-closeout.png"),
        Buffer.from(screenshot.data, "base64"),
      );
    }
    return {
      status: "browser-generation-save-reopen-pass",
      serviceDate: "2026-09-17",
      renderedRows: 248,
      generatedBatches: 1,
      businessQuantityAdjustments: firstSave.businessQuantityAdjustments,
      newDecisions: firstSave.newDecisions,
      proposalAcceptances: firstSave.proposalAcceptances,
      batchId: after.confirmed_need_batch_id,
      batchVersion: after.batch_version,
      generateClicks: 1,
      saveClicks: 1,
      otherQuantitiesEqualGeneratedProposal: true,
      theoreticalQuantitiesUnchanged: true,
      procurementRelease: false,
    };
  } catch (error) {
    const diagnostic = { browser_stage: stage };
    try {
      diagnostic.ui = await evaluate(
        `(()=>{const week=document.querySelector('input[aria-label="Tuần phục vụ"]');const service=document.querySelector('select[aria-label="Ngày phục vụ"]');const buttons=[...document.querySelectorAll('button')];const generate=buttons.find(e=>e.textContent.trim()==='Tạo nhu cầu');const save=buttons.find(e=>e.textContent.trim()==='Lưu');return {week_value:week?.value??null,service_date:service?.value??null,service_options:service?[...service.options].map(o=>o.value):[],generate_present:Boolean(generate),generate_enabled:Boolean(generate&&!generate.disabled&&generate.getAttribute('aria-disabled')!=='true'),save_present:Boolean(save),save_enabled:Boolean(save&&!save.disabled&&save.getAttribute('aria-disabled')!=='true'),rendered_rows:document.querySelectorAll(${JSON.stringify(`${CONFIRMED_TABLE} tbody tr`)}).length};})()`,
      );
    } catch {
      diagnostic.ui_read_failed = true;
    }
    try {
      const workbench = await readReview();
      diagnostic.authoritative = safeAuthoritativeDiagnostic(workbench);
    } catch {
      diagnostic.authoritative_read_failed = true;
    }
    console.error(JSON.stringify({ browser_diagnostic: diagnostic }));
    throw error;
  } finally {
    connection?.close();
    chrome.kill();
    await sleep(500);
    rmSync(profile, { recursive: true, force: true });
  }
}
