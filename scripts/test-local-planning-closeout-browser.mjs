import assert from "node:assert/strict";
import { build, preview } from "vite";
import { spawn } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { randomUUID } from "node:crypto";
import { fileURLToPath } from "node:url";
import { localSql } from "./planning-closeout-local-fixture.mjs";
import {
  cdp,
  prepareConfirmedNeedEdit,
  clickBusinessActionOnce,
  assertFirstSaveTransition,
  assertReopenedReview,
  preSaveGateStateExpression,
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
  const state = localSql(
    "select jsonb_build_object('run',r.need_generation_run_id,'batch',b.confirmed_need_batch_id,'version',b.version,'decisions',(select count(*) from atlas_planning.confirmed_need_line_decisions)) from atlas_planning.need_generation_runs r join atlas_planning.confirmed_need_batches b on b.current_need_generation_run_id=r.need_generation_run_id where r.period_start='2050-09-19'",
  )[0];
  assert.ok(
    [1, 2].includes(state.version),
    "browser harness requires a disposable unsaved fixture",
  );
  assert.equal(state.decisions, 0);
  function rpc(name, request) {
    assert.ok(
      [
        "execute_need_generation",
        "get_confirmed_need_review",
        "get_planning_input_preflight",
        "save_confirmed_needs",
      ].includes(name),
    );
    const literal = JSON.stringify(request).replaceAll("'", "''");
    return localSql(
      `begin;set local statement_timeout='8s';set local request.jwt.claims='{"sub":"${subject}","role":"authenticated"}';set local role authenticated;select atlas_api.${name}('${literal}'::jsonb);set constraints all immediate;commit;`,
    )[0];
  }
  const command = randomUUID();
  if (state.version === 1)
    assert.equal(
      rpc("execute_need_generation", {
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
      }).success,
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
  const readReview = () =>
    rpc("get_confirmed_need_review", readRequest).workbench;
  const before = readReview();
  assert.equal(before.lines.length, 248);
  assert.equal(before.batch_version, 2);
  let saves = 0;
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
    plugins: [
      {
        name: "local-closeout-rpc",
        configurePreviewServer(s) {
          s.middlewares.use("/__closeout-rpc", async (req, res) => {
            try {
              assert.equal(req.method, "POST");
              assert.equal(req.headers.origin, "http://127.0.0.1:3018");
              let text = "";
              for await (const chunk of req) {
                text += chunk;
                if (text.length > 200000) throw new Error("REQUEST_TOO_LARGE");
              }
              const { method, request } = JSON.parse(text);
              console.log(`Local browser RPC: ${method}`);
              let result;
              if (method === "review")
                result = rpc("get_confirmed_need_review", readRequest);
              else if (method === "preflight")
                result = rpc("get_planning_input_preflight", {
                  contract_version: "RMVP-03B.v2",
                  requested_by_auth_subject: subject,
                  correlation_id: randomUUID(),
                  payload: { period_start: date, period_end: date },
                });
              else {
                assert.equal(method, "save");
                assert.equal(saves, 0);
                assert.equal(request.requested_by_auth_subject, subject);
                assert.equal(
                  request.payload.confirmed_need_batch_id,
                  state.batch,
                );
                assert.equal(request.expected_version, 2);
                saves++;
                result = rpc("save_confirmed_needs", request);
              }
              res.setHeader("Content-Type", "application/json");
              res.end(JSON.stringify(result));
            } catch (e) {
              res.statusCode = 500;
              res.end(JSON.stringify({ error: e.message }));
            }
          });
        },
      },
    ],
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
    const open = async () => {
      console.log("Local browser: navigate");
      await connection.send("Page.navigate", { url });
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
    console.log("Local browser: edit");
    const edit = await prepareConfirmedNeedEdit({ evaluate, before });
    console.log("Local browser: save");
    await clickBusinessActionOnce({
      evaluate,
      scope: 'section[aria-label="Xác nhận nhu cầu"]',
      label: "Lưu",
      gate: "save_once",
    });
    await until(() => saves === 1, "save");
    const saved = readReview();
    const decisions = assertFirstSaveTransition({
      before,
      after: saved,
      adjustedLineId: edit.line.confirmed_need_line_id,
      adjustedQuantity: edit.proposed,
      note: edit.note,
    });
    await connection.send("Page.navigate", { url: "about:blank" });
    await open();
    assertReopenedReview(saved, readReview());
    assert.equal(
      (await evaluate(preSaveGateStateExpression())).save_present,
      false,
    );
    assert.equal(saves, 1);
    const evidence = localSql(
      "select jsonb_build_object('handoffs',(select count(*) from atlas_planning.purchase_handoff_batches),'save_receipts',(select count(*) from atlas_core.command_receipts where command_name='save_confirmed_needs'),'decisions',(select count(*) from atlas_planning.confirmed_need_line_decisions))",
    )[0];
    assert.deepEqual(evidence, {
      handoffs: 0,
      save_receipts: 1,
      decisions: 248,
    });
    const screenshot = await connection.send("Page.captureScreenshot", {
      format: "png",
    });
    writeFileSync(
      ".git/closeout-browser.png",
      Buffer.from(screenshot.data, "base64"),
    );
    const report = {
      status: "LOCAL_BROWSER_SAVE_REOPEN_PASS",
      ...decisions,
      ...evidence,
      saveClicks: saves,
      preSave: edit.preSave,
      transport:
        "loopback-only PostgreSQL authenticated role; real current React/Chakra workbench; no hosted sign-in or PR286 deployment",
    };
    console.log(JSON.stringify(report));
    return report;
  } catch (error) {
    if (evaluate)
      console.error(
        await evaluate(
          "({url:location.href,text:document.body.innerText,html:document.body.innerHTML.slice(0,4000)})",
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
