import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { test } from "vitest";
import * as browser from "./staging-planning-browser.mjs";

const { reachReadyToReview } = browser;

test("desktop closeout waits for the rail and its module navigation", async () => {
  document.body.innerHTML =
    '<aside aria-label="Điều hướng nhanh Atlas"></aside>';
  const evaluate = async (expression) => globalThis.eval(expression);
  await assert.rejects(
    () =>
      browser.waitForAuthenticatedDesktopShell({
        evaluate,
        timeout: 10,
        interval: 0,
      }),
    /BROWSER_GATE_authenticated_shell/,
  );
  document.querySelector("aside").innerHTML =
    '<nav aria-label="Điều hướng mô-đun Atlas"></nav>';
  await browser.waitForAuthenticatedDesktopShell({
    evaluate,
    timeout: 10,
    interval: 0,
  });
});

test("desktop icon-only module button navigates by accessible label", async () => {
  document.body.innerHTML =
    '<aside aria-label="Điều hướng nhanh Atlas"><nav aria-label="Điều hướng mô-đun Atlas"><button aria-label="Lập nhu cầu"><svg></svg></button></nav></aside>';
  const button = document.querySelector("button");
  let clicks = 0;
  button.addEventListener("click", () => {
    clicks += 1;
    document.body.insertAdjacentHTML(
      "beforeend",
      '<div role="tablist" aria-label="Giai đoạn lập nhu cầu"></div>',
    );
  });
  await browser.navigateUntil({
    evaluate: async (expression) => globalThis.eval(expression),
    scope: 'nav[aria-label="Điều hướng mô-đun Atlas"]',
    role: "button",
    label: "Lập nhu cầu",
    destination: '[role="tablist"][aria-label="Giai đoạn lập nhu cầu"]',
    timeout: 20,
    interval: 0,
  });
  assert.equal(clicks, 1);
});

test("protected desktop runner scopes the shell gate and Planning navigation to the rail", () => {
  const source = readFileSync(
    resolve("scripts/staging-planning-browser.mjs"),
    "utf8",
  );
  assert.match(source, /AUTHENTICATED_SHELL_SELECTOR/);
  assert.match(source, /ATLAS_MODULE_NAV_SELECTOR/);
  assert.match(source, /scope: ATLAS_MODULE_NAV_SELECTOR/);
  assert.match(source, /diagnostic\.shell = await readSafeBrowserStructure/);
  assert.doesNotMatch(source, /scope: 'nav\[aria-label="Điều hướng Atlas"\]'/);
});

test("failure diagnostics report shell structure without form values", async () => {
  document.body.innerHTML =
    '<input id="atlas-signin-email" value="private@example.com"><input id="atlas-signin-password" value="private-password"><div role="alert">private@example.com</div><aside aria-label="Điều hướng nhanh Atlas"><nav aria-label="Điều hướng mô-đun Atlas"><button aria-label="Lập nhu cầu"><svg></svg></button></nav></aside>';
  const diagnostic = await browser.readSafeBrowserStructure({
    evaluate: async (expression) => globalThis.eval(expression),
  });
  assert.equal(diagnostic.signinFormPresent, true);
  assert.equal(diagnostic.alertCount, 1);
  assert.equal(diagnostic.desktopRailPresent, true);
  assert.equal(diagnostic.desktopModuleNavPresent, true);
  assert.equal(diagnostic.drawerNavPresent, false);
  assert.deepEqual(diagnostic.moduleNavigationLabels, ["Lập nhu cầu"]);
  assert.equal(diagnostic.currentUrl, location.origin + location.pathname);
  assert.doesNotMatch(
    JSON.stringify(diagnostic),
    /private@example\.com|private-password/,
  );
});

test("corrected resume reaches review with zero Generate clicks", async () => {
  let clicks = 0;
  const review = {
    confirmed_need_batch_id: "a0311e0a-a4de-48b9-a529-fe7464a3352b",
    batch_version: 2,
    source_kind: "NEED_GENERATION",
    editing_allowed: true,
    blockers: [],
    pagination: { has_more: false },
    service_period: {
      period_start: "2026-09-17",
      period_end: "2026-09-17",
    },
    lines: Array.from({ length: 248 }, (_, index) => ({
      confirmed_need_line_id: `line-${index}`,
      current_decision_id: null,
      decision_history: [],
    })),
  };
  const result = await reachReadyToReview({
    mode: "D046_CORRECTED_RESUME",
    expectedBatchId: review.confirmed_need_batch_id,
    interval: 0,
    timeout: 100,
    evaluate: async (expression) =>
      expression.includes("rendered_rows:root?.querySelectorAll")
        ? { rendered_rows: 248, week_enabled: true, refresh_ready: true }
        : {
            week_value: "14/09/2026 – 20/09/2026",
            week_enabled: true,
            refresh_ready: true,
            loading: false,
            service_date: "2026-09-17",
            service_options: [
              "2026-09-14",
              "2026-09-15",
              "2026-09-16",
              "2026-09-17",
              "2026-09-18",
              "2026-09-19",
              "2026-09-20",
            ],
            service_enabled: true,
            generate_present: false,
            update_present: false,
            rendered_rows: 248,
          },
    readReview: async () => review,
    clickOnce: async () => {
      clicks += 1;
    },
  });
  assert.equal(result.generateClicks, 0);
  assert.equal(result.before, review);
  assert.equal(clicks, 0);
});

test("post-Save resume reaches the persisted review with zero Generate clicks", async () => {
  let clicks = 0;
  const review = {
    confirmed_need_batch_id: "a0311e0a-a4de-48b9-a529-fe7464a3352b",
    batch_version: 3,
    source_kind: "NEED_GENERATION",
    editing_allowed: true,
    blockers: [],
    pagination: { has_more: false },
    service_period: {
      period_start: "2026-09-17",
      period_end: "2026-09-17",
    },
    lines: Array.from({ length: 248 }, (_, index) => ({
      confirmed_need_line_id: `line-${index}`,
      current_decision_id: `decision-${index}`,
      decision_history: [{ decision_id: `decision-${index}` }],
    })),
  };
  const result = await reachReadyToReview({
    mode: "POST_SAVE_CLOSEOUT_RESUME",
    expectedBatchId: review.confirmed_need_batch_id,
    interval: 0,
    timeout: 100,
    evaluate: async (expression) =>
      expression.includes("rendered_rows:root?.querySelectorAll")
        ? { rendered_rows: 248, week_enabled: true, refresh_ready: true }
        : {
            week_value: "14/09/2026 – 20/09/2026",
            week_enabled: true,
            refresh_ready: true,
            loading: false,
            service_date: "2026-09-17",
            service_options: [
              "2026-09-14",
              "2026-09-15",
              "2026-09-16",
              "2026-09-17",
              "2026-09-18",
              "2026-09-19",
              "2026-09-20",
            ],
            service_enabled: true,
            generate_present: false,
            update_present: false,
            rendered_rows: 248,
          },
    readReview: async () => review,
    clickOnce: async () => {
      clicks += 1;
    },
  });
  assert.equal(result.generateClicks, 0);
  assert.equal(result.before, review);
  assert.equal(clicks, 0);
});
