import { spawn } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
const PREVIEW =
  "https://feat-atlas-ui-vnext-06c-prod.thuonghao-ops-erp.pages.dev/";
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function until(fn, label, timeout = 60000) {
  const end = Date.now() + timeout;
  while (Date.now() < end) {
    const v = await fn();
    if (v) return v;
    await sleep(300);
  }
  throw new Error(`BROWSER_GATE_${label}`);
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
    const evaluate = async (expression) => {
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
        `({transition:${JSON.stringify(transition)},url:location.href,controls:[...document.querySelectorAll('nav[aria-label="Điều hướng Atlas"] button,[role="tablist"][aria-label="Giai đoạn lập nhu cầu"],[role="tablist"][aria-label="Giai đoạn lập nhu cầu"] [role="tab"]')].map(e=>({tag:e.tagName.toLowerCase(),role:e.getAttribute('role')||e.tagName.toLowerCase(),label:e.getAttribute('aria-label')||e.textContent.trim(),disabled:Boolean(e.disabled)||e.getAttribute('aria-disabled')==='true'}))})`,
      );
      console.log(JSON.stringify({ browser_navigation: state }));
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
    await navigateUntil({
      evaluate,
      scope: '[role="tablist"][aria-label="Giai đoạn lập nhu cầu"]',
      role: "tab",
      label: "Xác nhận nhu cầu",
      destination: 'select[aria-label="Ngày phục vụ"]',
    });
    await logNavigation("confirmed_need_open");
    stage = "service_date";
    await until(
      () =>
        evaluate(
          `Boolean(document.querySelector('select[aria-label="Ngày phục vụ"] option[value="2026-09-17"]')) && !document.querySelector('select[aria-label="Ngày phục vụ"]').disabled`,
        ),
      stage,
    );
    await input('select[aria-label="Ngày phục vụ"]', "2026-09-17", "select");
    stage = "generate_once";
    await click("Tạo nhu cầu");
    await until(
      () =>
        evaluate(
          `document.querySelectorAll('table[aria-label="Nhu cầu xác nhận"] tbody tr').length===248`,
        ),
      "248_rendered_rows",
    );
    const before = await readReview();
    if (
      before?.lines.length !== 248 ||
      before.pagination.has_more ||
      before.blockers.length ||
      !before.editing_allowed
    )
      throw new Error("BROWSER_GENERATION_READBACK_FAILED");
    const candidate = await evaluate(
      `(()=>{const rows=[...document.querySelectorAll('table[aria-label="Nhu cầu xác nhận"] tbody tr')];const index=rows.findIndex(r=>r.children[1].textContent.trim()==='kg'&&r.querySelector('input')&&!r.querySelector('input').disabled&&!r.querySelector('input').readOnly);if(index<0)return null;const r=rows[index];return {index,ingredient:r.children[0].children[0].textContent,recipient:r.children[0].children[1].textContent};})()`,
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
    const row = `table[aria-label="Nhu cầu xác nhận"] tbody tr:nth-child(${candidate.index + 1})`;
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
    await input(
      `${row} input[aria-label^="Ghi chú"]`,
      "Owner-approved Staging closeout verification: one minimal quantity edit; no Procurement release.",
    );
    stage = "save_once";
    await click("Lưu");
    const after = await until(async () => {
      const w = await readReview();
      return w && w.batch_version > before.batch_version ? w : null;
    }, "saved_readback");
    const changed = after.lines.filter((l) => {
      const prior = before.lines.find(
        (x) => x.confirmed_need_line_id === l.confirmed_need_line_id,
      );
      return (
        prior?.current_decision_id !== l.current_decision_id ||
        prior?.confirmed_quantity_after !== l.confirmed_quantity_after
      );
    });
    const saved = after.lines.find(
      (l) => l.confirmed_need_line_id === line.confirmed_need_line_id,
    );
    if (
      !saved ||
      saved.confirmed_quantity_after == null ||
      exact(saved.confirmed_quantity_after) !== exact(proposed)
    )
      throw new Error("SAVED_QUANTITY_MISMATCH");
    if (
      changed.length !== 1 ||
      changed[0].confirmed_need_line_id !== line.confirmed_need_line_id
    )
      throw new Error("UNTOUCHED_DECISIONS_CHANGED");
    if (
      after.lines.some(
        (l) =>
          l.theoretical_quantity !==
          before.lines.find(
            (x) => x.confirmed_need_line_id === l.confirmed_need_line_id,
          )?.theoretical_quantity,
      )
    )
      throw new Error("THEORETICAL_QUANTITY_CHANGED");
    stage = "reopen";
    await until(
      () =>
        evaluate(
          `![...document.querySelectorAll('button')].some(b=>b.textContent.trim()==='Lưu')`,
        ),
      "save_settled",
    );
    await navigateUntil({
      evaluate,
      scope: '[role="tablist"][aria-label="Giai đoạn lập nhu cầu"]',
      role: "tab",
      label: "Nguồn lập nhu cầu",
      destination: '[role="tablist"][aria-label="Nguồn lập nhu cầu"]',
    });
    await navigateUntil({
      evaluate,
      scope: '[role="tablist"][aria-label="Giai đoạn lập nhu cầu"]',
      role: "tab",
      label: "Xác nhận nhu cầu",
      destination: 'select[aria-label="Ngày phục vụ"]',
    });
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
      changedLines: 1,
      batchId: after.confirmed_need_batch_id,
      batchVersion: after.batch_version,
      generateClicks: 1,
      saveClicks: 1,
      otherDecisionsUnchanged: true,
      theoreticalQuantitiesUnchanged: true,
      procurementRelease: false,
    };
  } catch (error) {
    console.error(JSON.stringify({ browser_stage: stage }));
    throw error;
  } finally {
    connection?.close();
    chrome.kill();
    await sleep(500);
    rmSync(profile, { recursive: true, force: true });
  }
}
