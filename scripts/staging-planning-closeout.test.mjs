import React, { useState } from "react";
import {
  act,
  cleanup,
  fireEvent,
  render,
  screen,
} from "@testing-library/react";
import { afterEach, beforeEach, test } from "vitest";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import * as closeoutVerifier from "./verify-staging-planning-closeout.mjs";
import * as planningBrowser from "./staging-planning-browser.mjs";
import { AtlasVNextProvider } from "../src/vnext/atlas/AtlasVNextProvider";
import { AtlasWeekRangeInput } from "../src/vnext/atlas/AtlasWeekRangeInput";
import { ConfirmedNeedTable } from "../src/vnext/atlas/planning-confirmed/ConfirmedNeedTable";
import { initialConfirmedNeedDraft } from "../src/vnext/atlas/bridges/confirmedNeed";

const { nextCent } = closeoutVerifier;

test("closeout preparation schedules no rollback generation benchmark", () => {
  const source = readFileSync(
    resolve(process.cwd(), "scripts/verify-staging-planning-closeout.mjs"),
    "utf8",
  );
  assert.doesNotMatch(source, /rollbackProbeSql\(date\)/);
  assert.doesNotMatch(source, /atlas_api\.execute_need_generation/);
});

test("closeout workflow never installs or replays quantity policies", () => {
  const workflow = readFileSync(
    resolve(
      process.cwd(),
      ".github/workflows/atlas-staging-planning-closeout.yml",
    ),
    "utf8",
  );
  assert.doesNotMatch(workflow, /install-staging-count-unit-policies/);
});

test("closeout workflow is read-only before the browser Save", () => {
  const workflow = readFileSync(
    resolve(
      process.cwd(),
      ".github/workflows/atlas-staging-planning-closeout.yml",
    ),
    "utf8",
  );
  assert.doesNotMatch(
    workflow,
    /Validate the approved policy package with rollback/,
  );
  assert.doesNotMatch(
    workflow,
    /Install and idempotently replay approved Staging policies/,
  );
});

beforeEach(() => {
  globalThis.ResizeObserver = class {
    observe() {}
    unobserve() {}
    disconnect() {}
  };
});

afterEach(() => {
  cleanup();
  document.body.innerHTML = "";
});

function shiftIsoDate(value, days) {
  const date = new Date(`${value}T12:00:00Z`);
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}

function WeekHarness({
  initialWeek,
  initialBusy = false,
  busyOnChange = false,
}) {
  const [week, setWeek] = useState(initialWeek);
  const [busy, setBusy] = useState(initialBusy);
  React.useEffect(() => {
    if (!busy) return;
    const timer = setTimeout(() => void act(() => setBusy(false)), 40);
    return () => clearTimeout(timer);
  }, [busy]);
  const days = Array.from({ length: 7 }, (_, index) =>
    shiftIsoDate(week, index),
  );
  return React.createElement(
    AtlasVNextProvider,
    null,
    React.createElement(
      "section",
      { "aria-label": "Xác nhận nhu cầu" },
      React.createElement(AtlasWeekRangeInput, {
        label: "Tuần phục vụ",
        value: week,
        disabled: busy,
        onValueChange: (next) => {
          setWeek(next);
          if (busyOnChange) setBusy(true);
        },
      }),
      React.createElement(
        "select",
        { "aria-label": "Ngày phục vụ", defaultValue: days[0] },
        days.map((day) =>
          React.createElement("option", { key: day, value: day }, day),
        ),
      ),
    ),
  );
}

async function browserEvaluate(expression) {
  let value;
  await act(async () => {
    value = globalThis.eval(expression);
  });
  return value;
}

function renderWeek(initialWeek, options = {}) {
  render(React.createElement(WeekHarness, { initialWeek, ...options }));
  return screen.getByRole("textbox", { name: "Tuần phục vụ" });
}
test("staged verification edit uses an exact next-cent value", () => {
  assert.equal(nextCent("1.234567"), "1.24");
  assert.equal(nextCent("1.230000"), "1.24");
  assert.equal(nextCent("90071992547409.910000"), "90071992547409.92");
  assert.throws(() => nextCent("1e4"));
  assert.throws(() => nextCent("-1"));
});

test("browser enters Confirmed Need even while Sources keeps the shared service-date select mounted", async () => {
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
        <button role="tab" aria-selected="true">Nguồn lập nhu cầu</button>
        <button role="tab" aria-selected="false" id="confirmed">Xác nhận nhu cầu</button>
      </div>
      <section aria-label="Nguồn lập nhu cầu">
        <select aria-label="Ngày phục vụ"></select>
      </section>`,
    );
    document.querySelector("#confirmed").addEventListener("click", () => {
      confirmedClicks += 1;
      if (confirmedClicks % 2 !== 0) return;
      document
        .querySelector("#confirmed")
        .setAttribute("aria-selected", "true");
      document.body.insertAdjacentHTML(
        "beforeend",
        '<section aria-label="Xác nhận nhu cầu"></section>',
      );
    });
  });
  const evaluate = async (expression) => globalThis.eval(expression);

  await planningBrowser.navigateUntil({
    evaluate,
    scope: 'nav[aria-label="Điều hướng Atlas"]',
    role: "button",
    label: "Lập nhu cầu",
    destination: '[role="tablist"][aria-label="Giai đoạn lập nhu cầu"]',
    interval: 0,
    timeout: 100,
  });
  assert.equal(typeof planningBrowser.navigateToConfirmedNeed, "function");
  await planningBrowser.navigateToConfirmedNeed({
    evaluate,
    interval: 0,
    timeout: 100,
  });

  document.querySelector('section[aria-label="Xác nhận nhu cầu"]').remove();
  document.querySelector("#confirmed").setAttribute("aria-selected", "false");
  await planningBrowser.navigateToConfirmedNeed({
    evaluate,
    interval: 0,
    timeout: 100,
  });

  assert.equal(decoyClicks, 0);
  assert.equal(planningClicks, 2);
  assert.equal(confirmedClicks, 4);
  assert.ok(document.querySelector('section[aria-label="Xác nhận nhu cầu"]'));
  assert.equal(
    document.querySelector("#confirmed").getAttribute("role"),
    "tab",
  );
});

test("tab navigation waits for selection when both phase sections remain mounted", async () => {
  document.body.innerHTML = `<div role="tablist" aria-label="Giai đoạn lập nhu cầu">
    <button role="tab" aria-selected="true">Nguồn lập nhu cầu</button>
    <button role="tab" aria-selected="false">Xác nhận nhu cầu</button>
  </div><section aria-label="Nguồn lập nhu cầu"></section>
  <section aria-label="Xác nhận nhu cầu"></section>`;
  const tab = screen.getByRole("tab", { name: "Xác nhận nhu cầu" });
  let clicks = 0;
  tab.addEventListener("click", () => {
    clicks += 1;
    tab.setAttribute("aria-selected", "true");
  });
  await planningBrowser.navigateToConfirmedNeed({
    evaluate: browserEvaluate,
    interval: 5,
    timeout: 1000,
  });
  assert.equal(clicks, 1);
  assert.equal(tab.getAttribute("aria-selected"), "true");
});

test("browser leaves an already-correct real Atlas week untouched", async () => {
  const field = renderWeek("2026-09-14");
  assert.equal(
    await browserEvaluate(
      `(()=>{const s=document.querySelector('select[aria-label="Ngày phục vụ"]');return Boolean(s&&!s.disabled&&[...s.options].some(o=>o.value==='2026-09-17'));})()`,
    ),
    true,
  );
  await planningBrowser.ensurePlanningServiceDateAvailable({
    evaluate: browserEvaluate,
    serviceDate: "2026-09-17",
    weekStart: "2026-09-14",
    interval: 0,
    timeout: 250,
  });
  assert.equal(field.value, "14/09/2026 – 20/09/2026");
  assert.equal(screen.queryByRole("application"), null);
});

test("already-correct week waits for initial authoritative loading to finish", async () => {
  const field = renderWeek("2026-09-14", { initialBusy: true });
  assert.equal(field.disabled, true);
  await planningBrowser.ensurePlanningServiceDateAvailable({
    evaluate: browserEvaluate,
    serviceDate: "2026-09-17",
    weekStart: "2026-09-14",
    interval: 5,
    timeout: 1000,
  });
  assert.equal(field.disabled, false);
  assert.equal(field.value, "14/09/2026 – 20/09/2026");
});

test("calendar navigation waits instead of failing on a temporarily disabled week", async () => {
  const field = renderWeek("2026-09-21", { initialBusy: true });
  await planningBrowser.ensurePlanningServiceDateAvailable({
    evaluate: browserEvaluate,
    serviceDate: "2026-09-17",
    weekStart: "2026-09-14",
    interval: 5,
    timeout: 1000,
  });
  assert.equal(field.disabled, false);
  assert.equal(field.value, "14/09/2026 – 20/09/2026");
});

test("week change waits for its second authoritative loading cycle", async () => {
  const field = renderWeek("2026-09-21", { busyOnChange: true });
  await planningBrowser.ensurePlanningServiceDateAvailable({
    evaluate: browserEvaluate,
    serviceDate: "2026-09-17",
    weekStart: "2026-09-14",
    interval: 5,
    timeout: 1000,
  });
  assert.equal(field.disabled, false);
  assert.equal(field.value, "14/09/2026 – 20/09/2026");
});

test("browser selects the historical week through the real Ark day-cell contract", async () => {
  const field = renderWeek("2026-09-21");
  await planningBrowser.ensurePlanningServiceDateAvailable({
    evaluate: browserEvaluate,
    serviceDate: "2026-09-17",
    weekStart: "2026-09-14",
    interval: 0,
    timeout: 1000,
  });
  assert.equal(field.value, "14/09/2026 – 20/09/2026");
  assert.ok(
    document.querySelector(
      'select[aria-label="Ngày phục vụ"] option[value="2026-09-17"]',
    ),
  );
});

test("real Atlas day-cell anatomy is a role-button div, not an HTML button", async () => {
  renderWeek("2026-09-21");
  await act(async () => {
    screen.getByRole("button", { name: "Mở lịch — Tuần phục vụ" }).click();
  });
  const target = document.querySelector(
    '[data-part="table-cell-trigger"][data-view="day"][data-value="2026-09-14"]',
  );
  assert.ok(target);
  assert.notEqual(target.tagName, "BUTTON");
  assert.equal(target.getAttribute("role"), "button");
});

test("browser reaches the historical week from October through real Ark month navigation", async () => {
  const field = renderWeek("2026-10-05");
  await planningBrowser.ensurePlanningServiceDateAvailable({
    evaluate: browserEvaluate,
    serviceDate: "2026-09-17",
    weekStart: "2026-09-14",
    interval: 0,
    timeout: 1000,
  });
  assert.equal(field.value, "14/09/2026 – 20/09/2026");
  assert.ok(
    document.querySelector(
      'select[aria-label="Ngày phục vụ"] option[value="2026-09-17"]',
    ),
  );
});

function firstSaveFixture() {
  const lines = Array.from({ length: 248 }, (_, index) => ({
    confirmed_need_line_id: `line-${index}`,
    theoretical_quantity: "2.000000",
    proposed_confirmed_quantity: "1.000000",
    current_decision_id: null,
    current_decision_number: null,
    confirmed_quantity_after: null,
    decision_history: [],
  }));
  const afterLines = lines.map((line, index) => {
    const adjusted = index === 0;
    const decision = {
      decision_id: `decision-${index}`,
      decision_number: 1,
      predecessor_decision_id: null,
      confirmed_quantity_after: adjusted ? "1.010000" : "1.000000",
      reason_code: adjusted
        ? "OPERATIONAL_QUANTITY_ADJUSTMENT"
        : "PROPOSAL_ACCEPTED",
      reason_note: adjusted
        ? "Owner-approved Staging closeout verification: one minimal quantity edit; no Procurement release."
        : null,
    };
    return {
      ...line,
      current_decision_id: decision.decision_id,
      current_decision_number: 1,
      confirmed_quantity_after: decision.confirmed_quantity_after,
      decision_history: [decision],
    };
  });
  return {
    before: { batch_version: 1, lines },
    after: { batch_version: 2, lines: afterLines },
    adjustedLineId: "line-0",
    adjustedQuantity: "1.01",
    note: "Owner-approved Staging closeout verification: one minimal quantity edit; no Procurement release.",
  };
}

test("first Save creates 248 first decisions but exactly one business quantity adjustment", () => {
  assert.equal(typeof planningBrowser.assertFirstSaveTransition, "function");
  assert.deepEqual(
    planningBrowser.assertFirstSaveTransition(firstSaveFixture()),
    {
      newDecisions: 248,
      businessQuantityAdjustments: 1,
      proposalAcceptances: 247,
    },
  );
});

test("first Save rejects a second business quantity adjustment", () => {
  const fixture = firstSaveFixture();
  fixture.after.lines[1].confirmed_quantity_after = "1.010000";
  fixture.after.lines[1].decision_history[0].confirmed_quantity_after =
    "1.010000";
  assert.throws(
    () => planningBrowser.assertFirstSaveTransition(fixture),
    /BROWSER_FIRST_SAVE_CONTRACT_FAILED/,
  );
});

test("final retained proof requires one run, one batch, no handoff, and unchanged source fingerprints", () => {
  const state = pristineResumeSnapshot();
  state.batches[0].version = 2;
  state.batches[0].decision_count = 248;
  state.batches[0].current_decision_count = 248;
  state.batches[0].adjustment_count = 1;
  state.batches[0].acceptance_count = 247;
  state.preflight.current_need.confirmed_need_batch_version = 2;
  state.save_receipt_count = 1;
  const review = {
    confirmed_need_batch_id: retainedBatchId,
    source_kind: "NEED_GENERATION",
    batch_version: 2,
    editing_allowed: true,
    blockers: [],
    pagination: { has_more: false },
    lines: Array.from({ length: 248 }, (_, index) => ({
      confirmed_need_line_id: `line-${index}`,
    })),
  };
  const proof = {
    baseline: {
      mode: "PRISTINE_GENERATED_RESUME",
      runId: retainedRunId,
      batchId: retainedBatchId,
    },
    browser: {
      batchId: retainedBatchId,
      batchVersion: 2,
      generateClicks: 0,
      saveClicks: 1,
      newDecisions: 248,
      businessQuantityAdjustments: 1,
      proposalAcceptances: 247,
    },
    state,
    review,
    baselineFingerprints: sourceFingerprints,
    finalFingerprints: sourceFingerprints,
  };
  assert.equal(
    typeof closeoutVerifier.assertFinalPlanningCloseoutProof,
    "function",
  );
  assert.deepEqual(closeoutVerifier.assertFinalPlanningCloseoutProof(proof), {
    mode: "PRISTINE_GENERATED_RESUME",
    retainedRuns: 1,
    retainedBatches: 1,
    retainedLines: 248,
    humanDecisions: 248,
    currentDecisions: 248,
    purchaseHandoffs: 0,
    sourceFingerprintsUnchanged: true,
  });
  for (const rejectedProof of [
    { baseline: { ...proof.baseline, mode: "ZERO_BASELINE" } },
    { browser: { ...proof.browser, generateClicks: 1 } },
    { browser: { ...proof.browser, saveClicks: 2 } },
  ]) {
    assert.throws(
      () =>
        closeoutVerifier.assertFinalPlanningCloseoutProof({
          ...proof,
          ...rejectedProof,
        }),
      /FINAL_PLANNING_CLOSEOUT_PROOF_FAILED/,
    );
  }
  assert.throws(
    () =>
      closeoutVerifier.assertFinalPlanningCloseoutProof({
        ...proof,
        finalFingerprints: {
          ...proof.finalFingerprints,
          pantry: "changed",
        },
      }),
    /FINAL_PLANNING_CLOSEOUT_PROOF_FAILED/,
  );
  const changed = structuredClone(state);
  changed.batches[0].decision_count = 247;
  assert.throws(
    () =>
      closeoutVerifier.assertFinalPlanningCloseoutProof({
        ...proof,
        state: changed,
      }),
    /FINAL_PLANNING_CLOSEOUT_PROOF_FAILED/,
  );
  changed.batches[0].decision_count = 248;
  changed.batches[0].adjustment_count = 2;
  assert.throws(
    () =>
      closeoutVerifier.assertFinalPlanningCloseoutProof({
        ...proof,
        state: changed,
      }),
    /FINAL_PLANNING_CLOSEOUT_PROOF_FAILED/,
  );
  changed.batches[0].adjustment_count = 1;
  changed.batches[0].current_run_version = 2;
  assert.throws(
    () =>
      closeoutVerifier.assertFinalPlanningCloseoutProof({
        ...proof,
        state: changed,
      }),
    /FINAL_PLANNING_CLOSEOUT_PROOF_FAILED/,
  );
});

test("failure diagnostics reduce authoritative review to safe counts and flags", () => {
  assert.equal(typeof planningBrowser.safeAuthoritativeDiagnostic, "function");
  const diagnostic = planningBrowser.safeAuthoritativeDiagnostic({
    batch_version: 2,
    editing_allowed: true,
    blockers: [{ message: "secret school blocker" }],
    pagination: { has_more: false },
    lines: [
      {
        ingredient: { name: "secret ingredient" },
        school: { name: "secret school" },
        confirmed_quantity_after: "123.450000",
      },
    ],
  });
  assert.deepEqual(diagnostic, {
    batch_exists: true,
    batch_version: 2,
    line_count: 1,
    editing_allowed: true,
    blocker_count: 1,
    has_more: false,
  });
  assert.doesNotMatch(
    JSON.stringify(diagnostic),
    /secret|123\.45|ingredient|school/i,
  );
});

test("pre-Generate gate accepts only the exact safe rehearsal surface", () => {
  const safe = {
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
    generate_present: true,
    generate_enabled: true,
    update_present: false,
    rendered_rows: 0,
  };
  assert.equal(typeof planningBrowser.assertPreGenerateGate, "function");
  assert.doesNotThrow(() => planningBrowser.assertPreGenerateGate(safe));
  assert.throws(
    () =>
      planningBrowser.assertPreGenerateGate({
        ...safe,
        update_present: true,
      }),
    /BROWSER_GATE_pre_generate/,
  );
});

test("pre-Save gate permits exactly one valid business adjustment", () => {
  const safe = {
    rendered_rows: 248,
    quantity_adjustment_rows: 1,
    adjustment_reason_rows: 1,
    nonblank_note_rows: 1,
    invalid_controls: 0,
    save_present: true,
    save_enabled: true,
  };
  assert.equal(typeof planningBrowser.assertPreSaveGate, "function");
  assert.doesNotThrow(() => planningBrowser.assertPreSaveGate(safe));
  assert.throws(
    () =>
      planningBrowser.assertPreSaveGate({
        ...safe,
        quantity_adjustment_rows: 2,
      }),
    /BROWSER_GATE_pre_save/,
  );
});

function freshConfirmedNeedLine(index) {
  return {
    confirmed_need_line_id: `line-${index}`,
    current_revision_id: `revision-${index}`,
    current_revision_number: 1,
    service_date: "2026-09-17",
    customer: { id: "customer", name: "Customer" },
    school: { id: `school-${index}`, name: `School ${index}` },
    delivery_location: { id: `location-${index}`, name: `Location ${index}` },
    ingredient: { id: `ingredient-${index}`, name: `Ingredient ${index}` },
    controlled_unit: {
      id: "kg",
      code: "kg",
      name: "Kilogram",
      status: "ACTIVE",
    },
    theoretical_quantity: "2.000000",
    proposed_confirmed_quantity: "1.000000",
    current_decision_id: null,
    current_decision_number: null,
    current_decision_kind: null,
    confirmed_quantity_after: null,
    confirmation_state: "NEW",
    effective_policy: null,
    source_membership_count: 1,
    source_stale: false,
    blockers: [],
    warnings: [],
    validation_issues: { blocking: [], warnings: [] },
    decision_history: [],
  };
}

test("real Confirmed Need rows distinguish one nonzero edit from pending zero deltas", async () => {
  const lines = Array.from({ length: 3 }, (_, index) =>
    freshConfirmedNeedLine(index),
  );
  const drafts = Object.fromEntries(
    lines.map((line, index) => [
      line.confirmed_need_line_id,
      index === 0
        ? {
            ...initialConfirmedNeedDraft(line),
            exact_quantity: "1.01",
            quantity_entered: true,
            reason_code: "OPERATIONAL_QUANTITY_ADJUSTMENT",
            reason_note:
              "Owner-approved Staging closeout verification: one minimal quantity edit; no Procurement release.",
          }
        : initialConfirmedNeedDraft(line),
    ]),
  );
  render(
    React.createElement(
      AtlasVNextProvider,
      null,
      React.createElement(
        "section",
        { "aria-label": "Xác nhận nhu cầu" },
        React.createElement(ConfirmedNeedTable, {
          lines,
          drafts,
          errors: {},
          editable: true,
          onEdit: () => {},
        }),
        React.createElement("button", null, "Lưu"),
      ),
    ),
  );
  assert.equal(typeof planningBrowser.preSaveGateStateExpression, "function");
  const state = await browserEvaluate(
    planningBrowser.preSaveGateStateExpression(),
  );
  assert.equal(state.rendered_rows, 3);
  assert.equal(state.quantity_delta_rows, 3);
  assert.equal(state.quantity_adjustment_rows, 1);
  assert.doesNotThrow(() =>
    planningBrowser.assertPreSaveGate({
      ...state,
      rendered_rows: 248,
      quantity_delta_rows: 248,
    }),
  );
});

const rehearsalDates = [
  "2026-09-14",
  "2026-09-15",
  "2026-09-16",
  "2026-09-17",
  "2026-09-18",
  "2026-09-19",
  "2026-09-20",
];
const rehearsalOptions = rehearsalDates
  .map(
    (date) =>
      `<option value="${date}"${date === "2026-09-17" ? " selected" : ""}>${date}</option>`,
  )
  .join("");

test("pre-Generate waits for service-date read to settle on the exact safe surface", async () => {
  document.body.innerHTML = `<section aria-label="Xác nhận nhu cầu">
    <input aria-label="Tuần phục vụ" value="14/09/2026 – 20/09/2026" disabled readonly>
    <select aria-label="Ngày phục vụ">${rehearsalOptions}</select>
    <button aria-label="Làm mới dữ liệu" aria-busy="true" disabled></button>
    <p role="status">Đang tải nhu cầu…</p>
  </section>`;
  const root = document.querySelector('section[aria-label="Xác nhận nhu cầu"]');
  const timer = setTimeout(() => {
    root.querySelector('input[aria-label="Tuần phục vụ"]').disabled = false;
    const refresh = root.querySelector('button[aria-label="Làm mới dữ liệu"]');
    refresh.disabled = false;
    refresh.setAttribute("aria-busy", "false");
    root.querySelector('[role="status"]').remove();
    root.insertAdjacentHTML("beforeend", "<button>Tạo nhu cầu</button>");
  }, 40);
  try {
    const state = await planningBrowser.waitForPreGenerateSurface({
      evaluate: browserEvaluate,
      interval: 5,
      timeout: 1000,
    });
    assert.equal(state.week_enabled, true);
    assert.equal(state.service_date, "2026-09-17");
    assert.equal(state.generate_enabled, true);
  } finally {
    clearTimeout(timer);
  }
});

test("reason selection waits for the real conditional note input to mount", async () => {
  const line = {
    ...freshConfirmedNeedLine(0),
    current_decision_id: "decision-0",
    current_decision_number: 1,
    confirmed_quantity_after: "1.000000",
    confirmation_state: "CONFIRMED_CURRENT",
  };
  function DelayedReasonTable() {
    const [draft, setDraft] = useState(initialConfirmedNeedDraft(line));
    return React.createElement(
      AtlasVNextProvider,
      null,
      React.createElement(
        "section",
        { "aria-label": "Xác nhận nhu cầu" },
        React.createElement(ConfirmedNeedTable, {
          lines: [line],
          drafts: { [line.confirmed_need_line_id]: draft },
          errors: {},
          editable: true,
          onEdit: (_id, change) =>
            setTimeout(
              () =>
                void act(() =>
                  setDraft((current) => ({ ...current, ...change })),
                ),
              40,
            ),
        }),
      ),
    );
  }
  render(React.createElement(DelayedReasonTable));
  const row =
    'section[aria-label="Xác nhận nhu cầu"] table[aria-label="Nhu cầu xác nhận"] tbody tr:nth-child(1)';
  assert.equal(
    document.querySelector(`${row} input[aria-label^="Ghi chú"]`),
    null,
  );
  fireEvent.change(
    screen.getByRole("combobox", { name: "Lý do Ingredient 0" }),
    {
      target: { value: "OPERATIONAL_QUANTITY_ADJUSTMENT" },
    },
  );
  await planningBrowser.waitForReasonNoteReady({
    evaluate: browserEvaluate,
    row,
    reason: "OPERATIONAL_QUANTITY_ADJUSTMENT",
    interval: 5,
    timeout: 1000,
  });
  assert.ok(document.querySelector(`${row} input[aria-label^="Ghi chú"]`));
});

test("pre-Save waits for quantity, reason, note, and Save eligibility to settle", async () => {
  const rows = Array.from(
    { length: 248 },
    (_, index) => `<tr>
    <td>Ingredient ${index}</td><td>kg</td><td>1</td>
    <td><input aria-label="Số lượng xác nhận ${index}" value="1"></td>
    <td class="delta">${index === 0 ? "—" : "0"}</td>
    <td><select aria-label="Lý do ${index}">
      <option value="PROPOSAL_ACCEPTED">Accepted</option>
      <option value="OPERATIONAL_QUANTITY_ADJUSTMENT">Adjusted</option>
    </select>${index === 0 ? '<input aria-label="Ghi chú 0" value="">' : ""}</td>
  </tr>`,
  ).join("");
  document.body.innerHTML = `<section aria-label="Xác nhận nhu cầu">
    <table aria-label="Nhu cầu xác nhận"><tbody>${rows}</tbody></table>
    <button disabled>Lưu</button>
  </section>`;
  const root = document.querySelector('section[aria-label="Xác nhận nhu cầu"]');
  const first = root.querySelector("tbody tr");
  const timers = [
    setTimeout(() => {
      first.querySelector('input[aria-label^="Số lượng xác nhận"]').value =
        "1.01";
      first.querySelector(".delta").textContent = "+0,01";
    }, 20),
    setTimeout(() => {
      first.querySelector('select[aria-label^="Lý do"]').value =
        "OPERATIONAL_QUANTITY_ADJUSTMENT";
    }, 40),
    setTimeout(() => {
      first.querySelector('input[aria-label^="Ghi chú"]').value =
        "Owner-approved Staging closeout verification: one minimal quantity edit; no Procurement release.";
    }, 60),
    setTimeout(() => {
      root.querySelector("button").disabled = false;
    }, 80),
  ];
  try {
    const state = await planningBrowser.waitForPreSaveSurface({
      evaluate: browserEvaluate,
      interval: 5,
      timeout: 1000,
    });
    assert.equal(state.quantity_adjustment_rows, 1);
    assert.equal(state.adjustment_reason_rows, 1);
    assert.equal(state.nonblank_note_rows, 1);
    assert.equal(state.save_enabled, true);
  } finally {
    timers.forEach(clearTimeout);
  }
});

test("reopen waits for authoritative workbench settlement beyond 248 rendered rows", async () => {
  document.body.innerHTML = `<div role="tablist" aria-label="Giai đoạn lập nhu cầu">
    <button role="tab" aria-selected="true">Xác nhận nhu cầu</button>
  </div><section aria-label="Xác nhận nhu cầu">
    <input aria-label="Tuần phục vụ" value="14/09/2026 – 20/09/2026" disabled readonly>
    <select aria-label="Ngày phục vụ">${rehearsalOptions}</select>
    <button aria-label="Làm mới dữ liệu" aria-busy="true" disabled></button>
    <p role="status">Đang tải nhu cầu…</p>
    <table aria-label="Nhu cầu xác nhận"><tbody>${"<tr><td>line</td></tr>".repeat(248)}</tbody></table>
  </section>`;
  const root = document.querySelector('section[aria-label="Xác nhận nhu cầu"]');
  const timer = setTimeout(() => {
    root.querySelector('input[aria-label="Tuần phục vụ"]').disabled = false;
    const refresh = root.querySelector('button[aria-label="Làm mới dữ liệu"]');
    refresh.disabled = false;
    refresh.setAttribute("aria-busy", "false");
    root.querySelector('[role="status"]').remove();
  }, 40);
  try {
    const state = await planningBrowser.waitForRenderedConfirmedRows({
      evaluate: browserEvaluate,
      interval: 5,
      timeout: 1000,
    });
    assert.equal(state.rendered_rows, 248);
    assert.equal(state.week_enabled, true);
    assert.equal(state.refresh_ready, true);
  } finally {
    clearTimeout(timer);
  }
});

const retainedRunId = "0c83b440-8fb2-4a77-9735-804ef4c89ea0";
const retainedBatchId = "a0311e0a-a4de-48b9-a529-fe7464a3352b";
const syntheticActorId = "a1010000-0000-4000-8000-000000000001";
const sourceFingerprints = {
  weekly_menu: "menu",
  attendance: "attendance",
  pantry: "pantry",
};

const approvedCountPolicyNames = [
  ["v1-unit-034ce34d3ff3", "Quả"],
  ["v1-unit-2d183c73d76a", "Bó"],
  ["v1-unit-469606e98b7e", "Gói"],
  ["v1-unit-46bab433cc1a", "Cốc"],
  ["v1-unit-83bea5cf6378", "Miếng"],
  ["v1-unit-91a0b1c14124", "Cái"],
  ["v1-unit-9837090d3b3f", "Hũ"],
  ["v1-unit-b1e160b3fbfb", "Chai"],
  ["v1-unit-c854d71627b2", "Cây"],
  ["v1-unit-cac06658f903", "Lon"],
  ["v1-unit-cad1515b85c4", "Ổ"],
  ["v1-unit-dafac3b7da11", "Bịch"],
  ["v1-unit-ea9046ea54e4", "Hộp"],
  ["v1-unit-eb0ce03e77fa", "Trái"],
];

function approvedPolicyRows() {
  return [
    ...approvedCountPolicyNames.map(([unit_code, unit_name]) => ({
      unit_code,
      unit_name,
      dimension_code: "COUNT",
      unit_status: "ACTIVE",
      planning_step: 1,
      effective_from: "2026-09-14",
      effective_to: null,
      policy_revision_status: "ACTIVE",
      revision_number: 1,
    })),
    {
      unit_code: "kg",
      unit_name: "Kilogram",
      dimension_code: "MASS",
      unit_status: "ACTIVE",
      planning_step: 0.01,
      effective_from: "2026-01-01",
      effective_to: null,
      policy_revision_status: "ACTIVE",
      revision_number: 1,
    },
  ];
}

function pristineResumeSnapshot() {
  return {
    runs: [
      {
        id: retainedRunId,
        period_start: "2026-09-17",
        period_end: "2026-09-17",
        status: "RELEASED_FOR_CONFIRMATION",
        version: 3,
        generated_line_count: 304,
        blocking_issue_count: 0,
        warning_count: 0,
        actor_id: syntheticActorId,
      },
    ],
    batches: [
      {
        id: retainedBatchId,
        period_start: "2026-09-17",
        period_end: "2026-09-17",
        status: "DRAFT_REVIEW",
        version: 1,
        source_kind: "NEED_GENERATION",
        origin_run_id: retainedRunId,
        current_run_id: retainedRunId,
        origin_run_version: 3,
        current_run_version: 3,
        line_count: 248,
        decision_count: 0,
        current_decision_count: 0,
        adjustment_count: 0,
        acceptance_count: 0,
      },
    ],
    handoffs: 0,
    preflight: {
      readiness_state: "READY",
      downstream_currentness: "CURRENT",
      blocking_issue_count: 0,
      current_need: {
        need_generation_run_id: retainedRunId,
        confirmed_need_batch_id: retainedBatchId,
        need_generation_run_version: 3,
        confirmed_need_batch_version: 1,
      },
      source_date_fingerprints: {
        service_date: "2026-09-17",
        selected: { ...sourceFingerprints },
        current: { ...sourceFingerprints },
      },
    },
    receipts: [
      {
        command_name: "execute_need_generation",
        actor_id: syntheticActorId,
        outcome: "COMPLETED",
        success: true,
        affected_aggregate_ids: {
          need_generation_run_id: retainedRunId,
          confirmed_need_batch_id: retainedBatchId,
        },
        new_versions: {
          need_generation_run_version: 3,
          confirmed_need_batch_version: 1,
        },
      },
    ],
    save_receipt_count: 0,
    policies: approvedPolicyRows(),
  };
}

test("closeout snapshot verifies policies in a read-only transaction", () => {
  const sql = closeoutVerifier.planningCloseoutSnapshotSql();
  assert.match(sql, /^begin read only;/);
  assert.match(sql, /planning_quantity_policy_revisions/);
  assert.match(sql, /atlas_admin\.units/);
  assert.match(sql, /u\.dimension_code='COUNT'/);
  assert.match(sql, /u\.unit_status='ACTIVE'/);
  assert.doesNotMatch(sql, /r\.planning_step=1/);
  assert.doesNotMatch(sql, /r\.effective_from='2026-09-14'/);
  assert.match(sql, /rollback;$/);
  assert.doesNotMatch(sql, /\b(insert|update|delete|create|alter)\b/i);
});

for (const [label, mutate] of [
  ["missing COUNT policy", (rows) => rows.shift()],
  [
    "extra 14/09 step-1 COUNT policy",
    (rows) => rows.push({ ...rows[0], unit_code: "extra" }),
  ],
  [
    "extra active COUNT policy with a different step and effective date",
    (rows) =>
      rows.push({
        ...rows[0],
        unit_code: "unexpected-count-unit",
        planning_step: 2,
        effective_from: "2026-09-15",
      }),
  ],
  [
    "wrong COUNT step",
    (rows) => {
      rows[0].planning_step = 2;
    },
  ],
  [
    "wrong COUNT effective date",
    (rows) => {
      rows[0].effective_from = "2026-09-15";
    },
  ],
  [
    "inactive COUNT policy",
    (rows) => {
      rows[0].policy_revision_status = "RETIRED";
    },
  ],
  [
    "inactive COUNT unit",
    (rows) => {
      rows[0].unit_status = "INACTIVE";
    },
  ],
  [
    "wrong COUNT dimension",
    (rows) => {
      rows[0].dimension_code = "MASS";
    },
  ],
  [
    "ended COUNT policy",
    (rows) => {
      rows[0].effective_to = "2026-09-20";
    },
  ],
  [
    "wrong COUNT revision",
    (rows) => {
      rows[0].revision_number = 2;
    },
  ],
  [
    "wrong COUNT name",
    (rows) => {
      rows[0].unit_name = "Other";
    },
  ],
  [
    "wrong COUNT code",
    (rows) => {
      rows[0].unit_code = "other";
    },
  ],
  [
    "wrong kg step",
    (rows) => {
      rows.at(-1).planning_step = 1;
    },
  ],
  [
    "wrong kg date",
    (rows) => {
      rows.at(-1).effective_from = "2026-09-14";
    },
  ],
  [
    "inactive kg policy",
    (rows) => {
      rows.at(-1).policy_revision_status = "RETIRED";
    },
  ],
]) {
  test(`pristine resume rejects ${label}`, () => {
    const snapshot = pristineResumeSnapshot();
    mutate(snapshot.policies);
    assert.throws(
      () => closeoutVerifier.classifyPlanningCloseoutBaseline(snapshot),
      /PLANNING_CLOSEOUT_BASELINE_REJECTED/,
    );
  });
}

test("zero baseline and exact retained state classify into only two modes", () => {
  const zero = pristineResumeSnapshot();
  zero.runs = [];
  zero.batches = [];
  zero.receipts = [];
  zero.preflight.downstream_currentness = "NOT_GENERATED";
  zero.preflight.current_need = null;
  assert.deepEqual(closeoutVerifier.classifyPlanningCloseoutBaseline(zero), {
    mode: "ZERO_BASELINE",
    runId: null,
    batchId: null,
    fingerprints: sourceFingerprints,
  });
  assert.deepEqual(
    closeoutVerifier.classifyPlanningCloseoutBaseline(pristineResumeSnapshot()),
    {
      mode: "PRISTINE_GENERATED_RESUME",
      runId: retainedRunId,
      batchId: retainedBatchId,
      fingerprints: sourceFingerprints,
    },
  );
});

test("protected closeout rejects zero baseline before invoking the browser journey", async () => {
  const zero = pristineResumeSnapshot();
  zero.runs = [];
  zero.batches = [];
  zero.receipts = [];
  zero.preflight.downstream_currentness = "NOT_GENERATED";
  zero.preflight.current_need = null;
  let browserInvocations = 0;
  await assert.rejects(
    closeoutVerifier.startProtectedPlanningBrowserCloseout(zero, async () => {
      browserInvocations += 1;
      return { generateClicks: 1, saveClicks: 1 };
    }),
    /PLANNING_CLOSEOUT_RESUME_REQUIRED/,
  );
  assert.equal(browserInvocations, 0);
});

test("protected closeout starts the pristine resume browser with zero Generate and one Save", async () => {
  let browserInvocations = 0;
  const result = await closeoutVerifier.startProtectedPlanningBrowserCloseout(
    pristineResumeSnapshot(),
    async (baseline) => {
      browserInvocations += 1;
      assert.equal(baseline.mode, "PRISTINE_GENERATED_RESUME");
      return { generateClicks: 0, saveClicks: 1 };
    },
  );
  assert.equal(browserInvocations, 1);
  assert.deepEqual(result, { generateClicks: 0, saveClicks: 1 });
});

for (const [label, mutate] of [
  [
    "existing human decisions",
    (s) => {
      s.batches[0].decision_count = 1;
    },
  ],
  [
    "existing current decisions",
    (s) => {
      s.batches[0].current_decision_count = 1;
    },
  ],
  [
    "wrong batch version",
    (s) => {
      s.batches[0].version = 2;
    },
  ],
  [
    "wrong run status",
    (s) => {
      s.runs[0].status = "INVALIDATED";
    },
  ],
  [
    "wrong batch status",
    (s) => {
      s.batches[0].status = "APPROVED";
    },
  ],
  [
    "mismatched batch and run",
    (s) => {
      s.batches[0].current_run_id = "another-run";
    },
  ],
  [
    "handoff",
    (s) => {
      s.handoffs = 1;
    },
  ],
  [
    "outdated source",
    (s) => {
      s.preflight.downstream_currentness = "OUTDATED";
    },
  ],
  [
    "source fingerprint mismatch",
    (s) => {
      s.preflight.source_date_fingerprints.current.pantry = "changed";
    },
  ],
  [
    "missing command receipt",
    (s) => {
      s.receipts = [];
    },
  ],
  [
    "receipt with wrong run",
    (s) => {
      s.receipts[0].affected_aggregate_ids.need_generation_run_id =
        "another-run";
    },
  ],
  [
    "receipt with wrong batch",
    (s) => {
      s.receipts[0].affected_aggregate_ids.confirmed_need_batch_id =
        "another-batch";
    },
  ],
  [
    "wrong actor",
    (s) => {
      s.receipts[0].actor_id = "another-actor";
    },
  ],
  [
    "duplicate run",
    (s) => {
      s.runs.push({ ...s.runs[0] });
    },
  ],
  [
    "duplicate batch",
    (s) => {
      s.batches.push({ ...s.batches[0] });
    },
  ],
  [
    "previous Save receipt",
    (s) => {
      s.save_receipt_count = 1;
    },
  ],
  [
    "receipt version mismatch",
    (s) => {
      s.receipts[0].new_versions.confirmed_need_batch_version = 2;
    },
  ],
  [
    "wrong date",
    (s) => {
      s.runs[0].period_start = "2026-09-16";
    },
  ],
  [
    "unexpected generated line count",
    (s) => {
      s.runs[0].generated_line_count = 248;
    },
  ],
  [
    "wrong run version",
    (s) => {
      s.runs[0].version = 2;
    },
  ],
  [
    "wrong source kind",
    (s) => {
      s.batches[0].source_kind = "LEGACY";
    },
  ],
  [
    "wrong stable line count",
    (s) => {
      s.batches[0].line_count = 304;
    },
  ],
  [
    "preflight blocker",
    (s) => {
      s.preflight.blocking_issue_count = 1;
    },
  ],
  [
    "preflight batch mismatch",
    (s) => {
      s.preflight.current_need.confirmed_need_batch_id = "another-batch";
    },
  ],
  [
    "duplicate command receipt",
    (s) => {
      s.receipts.push({ ...s.receipts[0] });
    },
  ],
  [
    "failed command receipt",
    (s) => {
      s.receipts[0].success = false;
    },
  ],
]) {
  test(`pristine resume rejects ${label}`, () => {
    const snapshot = pristineResumeSnapshot();
    mutate(snapshot);
    assert.throws(
      () => closeoutVerifier.classifyPlanningCloseoutBaseline(snapshot),
      /PLANNING_CLOSEOUT_BASELINE_REJECTED/,
    );
  });
}

test("resume reaches shared review without Generate while zero mode clicks once", async () => {
  const review = {
    confirmed_need_batch_id: retainedBatchId,
    batch_version: 1,
    source_kind: "NEED_GENERATION",
    editing_allowed: true,
    blockers: [],
    pagination: { has_more: false },
    service_period: { period_start: "2026-09-17", period_end: "2026-09-17" },
    lines: Array.from({ length: 248 }, (_, index) => ({
      confirmed_need_line_id: `line-${index}`,
      current_decision_id: null,
      decision_history: [],
    })),
  };
  const tableRows = "<tr><td>line</td></tr>".repeat(248);
  const readyMarkup = (resume) => `<section aria-label="Xác nhận nhu cầu">
    <input aria-label="Tuần phục vụ" value="14/09/2026 – 20/09/2026">
    <select aria-label="Ngày phục vụ">${rehearsalOptions}</select>
    <button aria-label="Làm mới dữ liệu" aria-busy="false"></button>
    ${resume ? `<table aria-label="Nhu cầu xác nhận"><tbody>${tableRows}</tbody></table>` : "<button>Tạo nhu cầu</button>"}
  </section>`;
  for (const mode of ["PRISTINE_GENERATED_RESUME", "ZERO_BASELINE"]) {
    document.body.innerHTML = readyMarkup(mode === "PRISTINE_GENERATED_RESUME");
    const clicks = [];
    const clickOnce = async (_scope, label) => {
      clicks.push(label);
      document
        .querySelector('section[aria-label="Xác nhận nhu cầu"]')
        .insertAdjacentHTML(
          "beforeend",
          `<table aria-label="Nhu cầu xác nhận"><tbody>${tableRows}</tbody></table>`,
        );
    };
    const result = await planningBrowser.reachReadyToReview({
      mode,
      expectedBatchId: retainedBatchId,
      evaluate: browserEvaluate,
      readReview: async () => review,
      clickOnce,
    });
    assert.equal(result.before, review);
    assert.equal(result.generateClicks, mode === "ZERO_BASELINE" ? 1 : 0);
    assert.deepEqual(clicks, mode === "ZERO_BASELINE" ? ["Tạo nhu cầu"] : []);
  }
});

test("Save click is one-shot and reopened review must match saved decisions", async () => {
  let clicks = 0;
  await planningBrowser.clickBusinessActionOnce({
    evaluate: async () => {
      clicks += 1;
      return true;
    },
    scope: 'section[aria-label="Xác nhận nhu cầu"]',
    label: "Lưu",
    gate: "save_once",
  });
  assert.equal(clicks, 1);
  clicks = 0;
  await assert.rejects(
    planningBrowser.clickBusinessActionOnce({
      evaluate: async () => {
        clicks += 1;
        return false;
      },
      scope: 'section[aria-label="Xác nhận nhu cầu"]',
      label: "Lưu",
      gate: "save_once",
    }),
    /BROWSER_GATE_save_once/,
  );
  assert.equal(clicks, 1);
  const fixture = firstSaveFixture();
  const after = { ...fixture.after, confirmed_need_batch_id: retainedBatchId };
  assert.doesNotThrow(() =>
    planningBrowser.assertReopenedReview(after, structuredClone(after)),
  );
  const changed = structuredClone(after);
  changed.lines[0].current_decision_id = "unexpected";
  assert.throws(
    () => planningBrowser.assertReopenedReview(after, changed),
    /REOPEN_READBACK_CHANGED/,
  );
});

test("Sources navigation waits for its refresh control to settle", async () => {
  document.body.innerHTML = `<section aria-label="Nguồn lập nhu cầu">
    <button aria-label="Làm mới dữ liệu" aria-busy="true" disabled></button>
  </section>`;
  const button = document.querySelector("button");
  const timer = setTimeout(() => {
    button.disabled = false;
    button.setAttribute("aria-busy", "false");
  }, 40);
  try {
    await planningBrowser.waitForPlanningSourcesReady({
      evaluate: browserEvaluate,
      interval: 5,
      timeout: 1000,
    });
    assert.equal(button.disabled, false);
  } finally {
    clearTimeout(timer);
  }
});
