import { test } from "vitest";
import assert from "node:assert/strict";
import {
  nextCent,
  rollbackProbeSql,
} from "./verify-staging-planning-closeout.mjs";
import * as planningBrowser from "./staging-planning-browser.mjs";
const { navigateUntil } = planningBrowser;
test("staged verification edit uses an exact next-cent value", () => {
  assert.equal(nextCent("1.234567"), "1.24");
  assert.equal(nextCent("1.230000"), "1.24");
  assert.equal(nextCent("90071992547409.910000"), "90071992547409.92");
  assert.throws(() => nextCent("1e4"));
  assert.throws(() => nextCent("-1"));
});
test("rollback probes keep the operator timeout and restrict approved dates", () => {
  const sql = rollbackProbeSql("2026-09-17");
  assert.match(sql, /statement_timeout='8s'/);
  assert.match(sql, /rollback;$/);
  assert.doesNotMatch(sql, /commit;/);
  assert.throws(() => rollbackProbeSql("2026-09-21"));
});

test("rollback review starts a new statement after materializing generation", () => {
  const sql = rollbackProbeSql("2026-09-17");
  // A STABLE review in the generation statement cannot see its new batch.
  // Preserve atomic rollback, but mirror the browser's separate read request.
  const generationEnd = sql.indexOf("from generated;");
  const reviewCall = sql.indexOf("atlas_api.get_confirmed_need_review");
  assert.ok(generationEnd >= 0 && generationEnd < reviewCall);
  assert.match(sql, /create temp table planning_closeout_probe_result/);
  assert.match(sql, /insert into planning_closeout_probe_result/);
  assert.match(sql, /'review_error_code',review->>'error_code'/);
  assert.match(sql, /rollback;$/);
  assert.doesNotMatch(sql, /commit;/);
});

test("browser navigation waits for scoped Chakra destinations after guarded clicks", async () => {
  document.body.innerHTML = `
    <button id="decoy">Lập nhu cầu</button>
    <nav aria-label="Điều hướng Atlas">
      <button id="planning">Lập nhu cầu</button>
    </nav>
  `;
  let decoyClicks = 0;
  let planningClicks = 0;
  let confirmedClicks = 0;
  document.querySelector("#decoy").addEventListener("click", () => {
    decoyClicks += 1;
  });
  document.querySelector("#planning").addEventListener("click", () => {
    planningClicks += 1;
    if (planningClicks !== 2) return;
    document.body.insertAdjacentHTML(
      "beforeend",
      `<div role="tablist" aria-label="Giai đoạn lập nhu cầu">
        <button role="tab">Nguồn lập nhu cầu</button>
        <button role="tab" id="confirmed">Xác nhận nhu cầu</button>
      </div>`,
    );
    document.querySelector("#confirmed").addEventListener("click", () => {
      confirmedClicks += 1;
      if (confirmedClicks !== 2) return;
      document.body.insertAdjacentHTML(
        "beforeend",
        '<select aria-label="Ngày phục vụ"></select>',
      );
    });
  });
  const evaluate = async (expression) => globalThis.eval(expression);

  await navigateUntil({
    evaluate,
    scope: 'nav[aria-label="Điều hướng Atlas"]',
    role: "button",
    label: "Lập nhu cầu",
    destination: '[role="tablist"][aria-label="Giai đoạn lập nhu cầu"]',
    interval: 0,
    timeout: 100,
  });
  await navigateUntil({
    evaluate,
    scope: '[role="tablist"][aria-label="Giai đoạn lập nhu cầu"]',
    role: "tab",
    label: "Xác nhận nhu cầu",
    destination: 'select[aria-label="Ngày phục vụ"]',
    interval: 0,
    timeout: 100,
  });

  assert.equal(decoyClicks, 0);
  assert.equal(planningClicks, 2);
  assert.equal(confirmedClicks, 2);
  assert.equal(
    document.querySelector("#confirmed").getAttribute("role"),
    "tab",
  );
});


test("browser moves to the fixed rehearsal week before selecting a historical service date", async () => {
  document.body.innerHTML = `
    <input aria-label="Tuần phục vụ" value="05/10/2026 – 11/10/2026" readonly />
    <select aria-label="Ngày phục vụ">
      <option value="2026-10-05">05/10/2026</option>
      <option value="2026-10-06">06/10/2026</option>
    </select>
  `;
  let previousMonthClicks = 0;
  let weekClicks = 0;
  const weekInput = document.querySelector('input[aria-label="Tuần phục vụ"]');
  const renderOctober = () => {
    document.body.insertAdjacentHTML(
      "beforeend",
      `<div role="application" aria-label="Lịch — Tuần phục vụ">
        <button aria-label="Tháng trước">Tháng trước</button>
        <button aria-label="Tháng sau">Tháng sau</button>
        <button data-view="day" data-value="2026-10-05">5</button>
      </div>`,
    );
    document
      .querySelector('button[aria-label="Tháng trước"]')
      .addEventListener("click", () => {
        previousMonthClicks += 1;
        document
          .querySelector('[role="application"][aria-label="Lịch — Tuần phục vụ"]')
          .remove();
        document.body.insertAdjacentHTML(
          "beforeend",
          `<div role="application" aria-label="Lịch — Tuần phục vụ">
            <button aria-label="Tháng trước">Tháng trước</button>
            <button aria-label="Tháng sau">Tháng sau</button>
            <button data-view="day" data-value="2026-09-14">14</button>
          </div>`,
        );
        document
          .querySelector('button[data-value="2026-09-14"]')
          .addEventListener("click", () => {
            weekClicks += 1;
            weekInput.value = "14/09/2026 – 20/09/2026";
            const select = document.querySelector(
              'select[aria-label="Ngày phục vụ"]',
            );
            select.innerHTML = Array.from({ length: 7 }, (_, i) => {
              const day = String(14 + i).padStart(2, "0");
              return `<option value="2026-09-${day}">${day}/09/2026</option>`;
            }).join("");
          });
      });
  };
  weekInput.addEventListener("click", renderOctober);
  const evaluate = async (expression) => globalThis.eval(expression);

  assert.equal(
    typeof planningBrowser.ensurePlanningServiceDateAvailable,
    "function",
  );
  await planningBrowser.ensurePlanningServiceDateAvailable({
    evaluate,
    serviceDate: "2026-09-17",
    weekStart: "2026-09-14",
    interval: 0,
    timeout: 100,
  });

  assert.equal(previousMonthClicks, 1);
  assert.equal(weekClicks, 1);
  assert.equal(
    document.querySelector('select[aria-label="Ngày phục vụ"]').querySelector(
      'option[value="2026-09-17"]',
    )?.value,
    "2026-09-17",
  );
});
