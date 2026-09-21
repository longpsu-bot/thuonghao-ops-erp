import React, { useState } from "react";
import { act, cleanup, render, screen } from "@testing-library/react";
import { afterEach, beforeEach, test } from "vitest";
import assert from "node:assert/strict";
import * as closeoutVerifier from "./verify-staging-planning-closeout.mjs";
import * as planningBrowser from "./staging-planning-browser.mjs";
import { AtlasVNextProvider } from "../src/vnext/atlas/AtlasVNextProvider";
import { AtlasWeekRangeInput } from "../src/vnext/atlas/AtlasWeekRangeInput";
import { ConfirmedNeedTable } from "../src/vnext/atlas/planning-confirmed/ConfirmedNeedTable";
import { initialConfirmedNeedDraft } from "../src/vnext/atlas/bridges/confirmedNeed";

const { nextCent, rollbackProbeSql } = closeoutVerifier;

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

function WeekHarness({ initialWeek }) {
  const [week, setWeek] = useState(initialWeek);
  const days = Array.from({ length: 7 }, (_, index) =>
    shiftIsoDate(week, index),
  );
  return React.createElement(
    AtlasVNextProvider,
    null,
    React.createElement(AtlasWeekRangeInput, {
      label: "Tuần phục vụ",
      value: week,
      onValueChange: setWeek,
    }),
    React.createElement(
      "select",
      { "aria-label": "Ngày phục vụ", defaultValue: days[0] },
      days.map((day) =>
        React.createElement("option", { key: day, value: day }, day),
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

function renderWeek(initialWeek) {
  render(React.createElement(WeekHarness, { initialWeek }));
  return screen.getByRole("textbox", { name: "Tuần phục vụ" });
}
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

test("protected generation acceptance is strict below 7000 ms", () => {
  const valid = {
    success: true,
    review_success: true,
    currentness: "CURRENT",
    has_more: false,
    blocker_count: 0,
    editing_allowed: true,
    line_count: 248,
  };
  assert.equal(
    typeof closeoutVerifier.planningCloseoutProbeAccepted,
    "function",
  );
  assert.equal(
    closeoutVerifier.planningCloseoutProbeAccepted({
      ...valid,
      generation_ms: 6999.999,
    }),
    true,
  );
  assert.equal(
    closeoutVerifier.planningCloseoutProbeAccepted({
      ...valid,
      generation_ms: 7000,
    }),
    false,
  );
  assert.equal(
    closeoutVerifier.planningCloseoutProbeAccepted({
      ...valid,
      generation_ms: 7000.001,
    }),
    false,
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
  const review = {
    confirmed_need_batch_id: "batch-1",
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
    browser: { batchId: "batch-1", batchVersion: 2 },
    state: { runs: 1, batches: 1, handoffs: 0 },
    review,
    baselineFingerprints: {
      weekly_menu: "menu-fingerprint",
      attendance: "attendance-fingerprint",
      pantry: "pantry-fingerprint",
    },
    finalFingerprints: {
      weekly_menu: "menu-fingerprint",
      attendance: "attendance-fingerprint",
      pantry: "pantry-fingerprint",
    },
  };
  assert.equal(
    typeof closeoutVerifier.assertFinalPlanningCloseoutProof,
    "function",
  );
  assert.deepEqual(closeoutVerifier.assertFinalPlanningCloseoutProof(proof), {
    retainedRuns: 1,
    retainedBatches: 1,
    retainedLines: 248,
    purchaseHandoffs: 0,
    sourceFingerprintsUnchanged: true,
  });
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
