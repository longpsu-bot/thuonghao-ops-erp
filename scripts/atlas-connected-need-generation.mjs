// Additive first-generation UI proof on the existing disposable source fixture.
import assert from "node:assert/strict";
import { clickBusinessActionOnce } from "./staging-planning-browser.mjs";

export async function certifyFirstNeedGeneration({
  evaluate,
  until,
  rpc,
  sql,
  subject,
  open,
  readOriginal,
  original,
  originalReceiptState,
  receiptState,
}) {
  const date = "2050-09-20";
  const preflight = async () =>
    (
      await rpc("get_planning_input_preflight", {
        contract_version: "RMVP-03B.v2",
        requested_by_auth_subject: subject,
        correlation_id: crypto.randomUUID(),
        payload: { period_start: date, period_end: date },
      })
    ).preflight;
  const before = await preflight();
  assert.equal(before.readiness_state, "READY");
  assert.equal(before.downstream_currentness, "NOT_GENERATED");
  assert.equal(before.current_need, null);
  assert(before.source_date_fingerprints);
  assert.equal(before.source_date_fingerprints.service_date, date);
  assert.deepEqual(
    Object.keys(before.source_date_fingerprints.selected).sort(),
    ["attendance", "pantry", "weekly_menu"],
  );
  assert(
    Object.values(before.source_date_fingerprints.selected).every(
      (value) => typeof value === "string" && value.length > 0,
    ),
  );
  const generationReceipts = () =>
    sql(
      "select jsonb_build_object('rows',coalesce(jsonb_agg(to_jsonb(r) order by r.command_id),'[]')) from atlas_core.command_receipts r where command_name='execute_need_generation'",
    )[0].rows;
  const oldGenerationReceipts = generationReceipts();
  const receipts = () =>
    sql(
      "select jsonb_build_object('count',count(*)) from atlas_core.command_receipts where command_name='execute_need_generation' and outcome='COMPLETED'",
    )[0].count;
  const previousReceipts = receipts();
  const chooseDate = async (day, discard = false) => {
    await until(
      () =>
        evaluate(
          "(()=>{const b=document.querySelector('button[aria-label=\"Mở lịch — Khoảng ngày\"]');return b&&!b.disabled;})()",
        ),
      "GENERATION_RANGE_READY",
    );
    await evaluate(
      "document.querySelector('button[aria-label=\"Mở lịch — Khoảng ngày\"]').click()",
    );
    const selector = `[data-part="table-cell-trigger"][data-value="${day}"]`;
    for (let edge = 0; edge < 2; edge++) {
      await until(
        () =>
          evaluate(
            `Boolean(document.querySelector(${JSON.stringify(selector)}))`,
          ),
        "GENERATION_DAY_READY",
      );
      await evaluate(
        `document.querySelector(${JSON.stringify(selector)}).click()`,
      );
    }
    if (discard) {
      await until(
        () =>
          evaluate(
            "[...document.querySelectorAll('[role=dialog][data-state=open]')].some(d=>d.textContent.includes('Có thay đổi chưa lưu.'))",
          ),
        "GENERATION_UNCONFIRMED_EXIT",
      );
      await clickBusinessActionOnce({
        evaluate,
        scope: '[role="dialog"][data-state="open"]',
        label: "Bỏ thay đổi",
        gate: "generation_discard_unsaved_defaults_once",
      });
    }
  };
  await chooseDate(date);
  await until(
    () =>
      evaluate(
        "[...document.querySelectorAll('button')].some(b=>b.textContent.trim()==='Tạo nhu cầu'&&!b.disabled)&&!document.querySelector('table[aria-label=\"Nhu cầu xác nhận\"]')",
      ),
    "GENERATION_FIRST_ACTION",
  );
  await clickBusinessActionOnce({
    evaluate,
    scope: 'section[aria-label="Xác nhận nhu cầu"]',
    label: "Tạo nhu cầu",
    gate: "first_need_generation_once",
  });
  const current = await until(async () => {
    const value = await preflight();
    return receipts() === previousReceipts + 1 &&
      value.downstream_currentness === "CURRENT"
      ? value
      : null;
  }, "GENERATION_PUBLIC_CURRENT");
  assert.equal(receipts(), previousReceipts + 1);
  const newGenerationReceipts = generationReceipts();
  const originalCommandIds = new Set(
    oldGenerationReceipts.map((row) => row.command_id),
  );
  assert.deepEqual(
    newGenerationReceipts.filter((row) =>
      originalCommandIds.has(row.command_id),
    ),
    oldGenerationReceipts,
  );
  assert.equal(
    newGenerationReceipts.filter(
      (row) => !originalCommandIds.has(row.command_id),
    ).length,
    1,
  );
  assert.equal(current.readiness_state, "READY");
  assert.equal(
    current.current_need.need_generation_run_status,
    "RELEASED_FOR_CONFIRMATION",
  );
  assert.equal(current.current_need.confirmed_need_batch_version, 1);
  assert.deepEqual(
    current.source_date_fingerprints.selected,
    before.source_date_fingerprints.selected,
  );
  assert.deepEqual(
    current.source_date_fingerprints.selected,
    current.source_date_fingerprints.current,
  );
  assert.deepEqual(current.source_evidence, before.source_evidence);
  const read = async () =>
    (
      await rpc("get_confirmed_need_review", {
        contract_version: "RMVP-05.v1",
        requested_by_auth_subject: subject,
        correlation_id: crypto.randomUUID(),
        payload: {
          confirmed_need_batch_id: current.current_need.confirmed_need_batch_id,
          filters: { service_date: date },
          line_offset: 0,
          line_limit: 10000,
        },
      })
    ).workbench;
  const generated = await read();
  assert.equal(generated.lines.length, 248);
  assert.equal(generated.batch_version, 1);
  assert.equal(generated.pagination.has_more, false);
  assert.equal(
    new Set(generated.lines.map((line) => line.confirmed_need_line_id)).size,
    248,
  );
  assert(
    generated.lines.every(
      (line) =>
        line.service_date === date &&
        !line.current_decision_id &&
        line.decision_history.length === 0 &&
        !line.source_stale &&
        line.controlled_unit.id &&
        line.school.id,
    ),
  );
  assert.equal(
    generated.lines.reduce(
      (sum, line) => sum + line.source_membership_count,
      0,
    ),
    304,
  );
  const decimal = (value) => {
    assert(/^\d+(?:[,.]\d{1,6})?$/.test(String(value)));
    return String(value)
      .replace(",", ".")
      .replace(/(\.\d*?)0+$/, "$1")
      .replace(/\.$/, "");
  };
  const rendered = async () => {
    await until(
      () =>
        evaluate(
          `document.querySelectorAll('table[aria-label="Nhu cầu xác nhận"] tbody tr').length===248&&Boolean(document.querySelector('tr[data-confirmed-need-line-id="${generated.lines[0].confirmed_need_line_id}"] input[aria-label^="Số lượng xác nhận"]:not(:disabled)'))`,
        ),
      "GENERATION_EDITABLE_ROWS",
    );
    assert.deepEqual(
      (
        await evaluate(
          "[...document.querySelectorAll('table[aria-label=\"Nhu cầu xác nhận\"] tbody tr')].map(row=>({id:row.getAttribute('data-confirmed-need-line-id'),quantity:row.querySelector('input[aria-label^=\"Số lượng xác nhận\"]')?.value}))",
        )
      )
        .map((row) => ({ id: row.id, quantity: decimal(row.quantity) }))
        .sort((a, b) => a.id.localeCompare(b.id)),
      generated.lines
        .map((line) => ({
          id: line.confirmed_need_line_id,
          quantity: decimal(line.proposed_confirmed_quantity),
        }))
        .sort((a, b) => a.id.localeCompare(b.id)),
    );
  };
  await rendered();
  // Explicitly discard only unconfirmed editor defaults, then reopen a document.
  await chooseDate("2050-09-19", true);
  await until(
    () =>
      evaluate(
        `Boolean(document.querySelector('tr[data-confirmed-need-line-id="${original.lines[0].confirmed_need_line_id}"] input[aria-label^="Số lượng xác nhận"]:not(:disabled)'))&&!document.querySelector('[role="dialog"][data-state="open"]')`,
      ),
    "GENERATION_RETURNED_ORIGINAL_SCOPE",
  );
  assert.deepEqual(await readOriginal(), original);
  await open();
  assert.deepEqual(await readOriginal(), original);
  await chooseDate(date);
  await rendered();
  assert.deepEqual(await read(), generated);
  assert.deepEqual(receiptState(), originalReceiptState);
  assert.equal(receipts(), previousReceipts + 1);
  return {
    date,
    generateClicks: 1,
    completedReceipts: 1,
    lines: 248,
    sourceMemberships: 304,
    reopened: true,
  };
}
