// Actual connected correction/governance UI on the reset disposable runner only.
import assert from "node:assert/strict";
import { controlledInputExpression } from "./staging-planning-browser.mjs";

export async function certifyConnectedCorrections({
  connection,
  evaluate,
  until,
  operator,
  subject,
  sql,
  url,
  authoring,
}) {
  const date = authoring.week;
  assert.equal(date, "2050-09-26");
  const rpc = async (name, contract, payload = {}) => {
    assert(
      [
        "get_planning_inputs_workbench",
        "get_pantry_source_workbench",
        "get_dish_recipe_operator_workbench",
        "get_recipe_adjustment_workbench",
        "get_recipe_adjustment_operator_workbench",
        "resolve_system_effective_recipe_composition",
      ].includes(name),
    );
    const result = await operator.schema("atlas_api").rpc(name, {
      request: {
        contract_version: contract,
        requested_by_auth_subject: subject,
        correlation_id: crypto.randomUUID(),
        payload,
      },
    });
    assert(
      !result.error && result.data?.success,
      `Correction public read failed: ${name}/${result.error?.code ?? result.data?.error_code}`,
    );
    return result.data.workbench ?? result.data;
  };
  const count = (name) =>
    Number(
      sql(
        `select count(*) from atlas_core.command_receipts where command_name='${name}' and outcome='COMPLETED'`,
      ),
    );
  const planning = () =>
    rpc("get_planning_inputs_workbench", "RMVP-03A.v1", { week_start: date });
  const pantry = () =>
    rpc("get_pantry_source_workbench", "PANTRY-02.v1", { week_start: date });
  const adjustments = () =>
    rpc("get_recipe_adjustment_workbench", "RMVP-02B.v1");
  const effective = async (asOf) =>
    (
      await rpc(
        "resolve_system_effective_recipe_composition",
        "RECIPE-EFFECTIVE.v1",
        {
          as_of_date: asOf,
          dish_id: authoring.dish,
          school_type_id: authoring.schoolType,
        },
      )
    ).resolution;
  const recipe = () =>
    rpc("get_dish_recipe_operator_workbench", "RECIPE-EFFECTIVE.v1", {
      as_of_date: date,
      dish_id: authoring.dish,
      school_type_id: authoring.schoolType,
    });
  const open = async (stage) => {
    const origin = await evaluate("performance.timeOrigin");
    await connection.send("Page.navigate", { url: `${url}?stage=${stage}` });
    await until(
      () =>
        evaluate(
          `performance.timeOrigin!==${origin}&&document.readyState==='complete'`,
        ),
      "CORRECTION_NEW_DOCUMENT",
    );
  };
  const action = async (label, scope = "body", aria = false) => {
    const expression = `(()=>[...document.querySelector(${JSON.stringify(scope)})?.querySelectorAll('button')??[]].find(b=>${aria ? "b.getAttribute('aria-label')" : "b.textContent.trim()"}===${JSON.stringify(label)}&&!b.disabled))()`;
    try {
      await until(
        () => evaluate(`Boolean(${expression})`),
        `CORRECTION_READY_${label}`,
      );
    } catch (error) {
      const state = await evaluate(
        "({alerts:[...document.querySelectorAll('[role=alert]')].map(e=>e.innerText),dialogs:[...document.querySelectorAll('[role=dialog]')].map(e=>e.innerText.slice(0,1800)),text:document.body.innerText.slice(-2500)})",
      );
      throw new Error(`${error.message}: ${JSON.stringify(state)}`, {
        cause: error,
      });
    }
    assert(
      await evaluate(
        `(()=>{const b=${expression};if(!b)return false;b.click();return true;})()`,
      ),
    );
  };
  const input = async (selector, value, kind = "input") => {
    await until(
      () =>
        evaluate(
          `Boolean(document.querySelector(${JSON.stringify(selector)})&&!document.querySelector(${JSON.stringify(selector)}).disabled)`,
        ),
      "CORRECTION_INPUT_READY",
    );
    return evaluate(
      kind === "textarea"
        ? `(()=>{const e=document.querySelector(${JSON.stringify(selector)});Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype,'value').set.call(e,${JSON.stringify(value)});e.dispatchEvent(new Event('input',{bubbles:true}));})()`
        : controlledInputExpression(selector, value, kind),
    );
  };
  const field = async (scope, label, value) => {
    const tag = await until(
      () =>
        evaluate(
          `(()=>{const root=document.querySelector(${JSON.stringify(scope)});const label=[...root?.querySelectorAll('label')??[]].find(l=>l.textContent.trim()===${JSON.stringify(label)});const e=label?.control??label?.parentElement.querySelector('input,textarea,select');if(!e||e.disabled)return null;e.setAttribute('data-correction-field','active');return e.tagName.toLowerCase();})()`,
        ),
      `CORRECTION_FIELD_${label}`,
    );
    await input(
      '[data-correction-field="active"]',
      value,
      tag === "select" ? "select" : tag === "textarea" ? "textarea" : "input",
    );
    await evaluate(
      "document.querySelector('[data-correction-field=active]').removeAttribute('data-correction-field')",
    );
  };
  const readAfter = async (name, before, read, predicate) => {
    const result = await until(async () => {
      const value = await read();
      return count(name) === before + 1 && predicate(value) ? value : null;
    }, `CORRECTION_SAVED_${name}`);
    assert.equal(count(name), before + 1);
    return result;
  };

  const sourceBefore = await planning();
  const pantryBefore = await pantry();
  const attendance = sourceBefore.attendance;
  const line = attendance.lines.find(
    (l) =>
      l.school_id === authoring.school &&
      l.service_date === date &&
      l.line_status === "ACTIVE",
  );
  assert.equal(line?.student_portions, 12);
  assert.equal(line.teacher_portions, 0);
  assert(line.attendance_line_id);
  const pair = (row) => `${row.school_id}|${row.service_date}`;
  const previousRows = attendance.lines.filter(
    (row) => row.line_status === "ACTIVE",
  );
  const previousByPair = new Map(previousRows.map((row) => [pair(row), row]));
  assert.equal(previousRows.length, 1);
  const activeSchools = sourceBefore.schools.filter(
    (row) => row.school_status === "ACTIVE",
  );
  assert.equal(activeSchools.length, 3);
  const weekDates = Array.from({ length: 7 }, (_, offset) =>
    new Date(Date.parse(`${date}T00:00:00Z`) + offset * 86400000)
      .toISOString()
      .slice(0, 10),
  );
  const defaultPairs = new Map(
    sourceBefore.default_attendance_preview.map((row) => [pair(row), row]),
  );
  assert.equal(sourceBefore.default_attendance_preview.length, 21);
  assert.equal(defaultPairs.size, 21);
  for (const school of activeSchools)
    for (const day of weekDates)
      assert.deepEqual(defaultPairs.get(`${school.school_id}|${day}`), {
        school_id: school.school_id,
        service_date: day,
        student_portions: school.default_student_portions,
        teacher_portions: school.default_teacher_portions,
        source_row_reference: `default:${school.school_code}:${day}`,
      });
  // Approved whole-week Review overlays saved facts on public default facts.
  const expectedByPair = new Map(
    sourceBefore.default_attendance_preview.map((row) => [pair(row), row]),
  );
  for (const row of previousRows) expectedByPair.set(pair(row), row);
  expectedByPair.set(pair(line), { ...line, student_portions: 13 });
  const expectedRows = [...expectedByPair.values()];
  assert.equal(expectedRows.length, 21);
  const businessFacts = (rows) =>
    rows
      .map((row) => ({
        school: row.school_id,
        date: row.service_date,
        students: row.student_portions,
        teachers: row.teacher_portions,
        source: row.source_row_reference,
      }))
      .sort((a, b) => JSON.stringify(a).localeCompare(JSON.stringify(b)));
  const expectedReview = expectedRows
    .filter((row) => {
      const old = previousByPair.get(pair(row));
      return (
        !old ||
        old.student_portions !== row.student_portions ||
        old.teacher_portions !== row.teacher_portions
      );
    })
    .sort(
      (a, b) =>
        a.service_date.localeCompare(b.service_date) ||
        a.school_id.localeCompare(b.school_id),
    )
    .map((row) => {
      const old = previousByPair.get(pair(row));
      const name = sourceBefore.schools.find(
        (s) => s.school_id === row.school_id,
      )?.school_name;
      assert(name);
      return [
        `${name} ${row.service_date.split("-").reverse().join("/")} · Đổi`,
        `HS ${old?.student_portions ?? "—"} · GV ${old?.teacher_portions ?? "—"}`,
        `HS ${row.student_portions} · GV ${row.teacher_portions}`,
      ];
    });
  assert.equal(expectedReview.length, 21);
  const school = sourceBefore.schools.find(
    (s) => s.school_id === authoring.school,
  );
  assert(school?.school_name);
  await open("attendance");
  const student = `input[aria-label=${JSON.stringify(`Học sinh ${school.school_name}`)}]`;
  await input(student, "13");
  await action("Xem thay đổi");
  await until(
    () =>
      evaluate(
        "Boolean(document.querySelector('aside[aria-label=\"Xem thay đổi\"] table'))",
      ),
    "CORRECTION_WHOLE_WEEK_REVIEW",
  );
  assert.deepEqual(
    await evaluate(
      "[...document.querySelector('aside[aria-label=\"Xem thay đổi\"] table').querySelectorAll('tbody tr')].map(row=>[...row.cells].map(cell=>cell.innerText.replace(/\\s+/g,' ').trim()))",
    ),
    expectedReview,
    "Every default and edited pair must be explicitly reviewed before whole-week Save.",
  );
  const attendanceReceipts = count("save_attendance");
  await action("Lưu", 'aside[aria-label="Xem thay đổi"]');
  const savedSources = await readAfter(
    "save_attendance",
    attendanceReceipts,
    planning,
    (data) => data.attendance?.version === attendance.version + 1,
  );
  assert.equal(
    savedSources.attendance.attendance_batch_id,
    attendance.attendance_batch_id,
  );
  assert.notEqual(
    savedSources.attendance.latest_approval_snapshot_id,
    attendance.latest_approval_snapshot_id,
  );
  assert.deepEqual(
    savedSources.attendance.approval_history.filter(
      (row) =>
        row.approval_snapshot_id !==
        savedSources.attendance.latest_approval_snapshot_id,
    ),
    attendance.approval_history,
  );
  assert.equal(
    savedSources.attendance.approval_history.length,
    attendance.approval_history.length + 1,
  );
  assert.equal(savedSources.attendance.row_count, 21);
  const savedApproval = savedSources.attendance.approval_history.find(
    (row) =>
      row.approval_snapshot_id ===
      savedSources.attendance.latest_approval_snapshot_id,
  );
  assert.equal(savedApproval?.line_count, 21);
  assert.equal(savedApproval.version, savedSources.attendance.version);
  assert.deepEqual(
    businessFacts(savedSources.attendance.lines),
    businessFacts(expectedRows),
  );
  assert.equal(
    new Set(savedSources.attendance.lines.map(pair)).size,
    expectedRows.length,
  );
  assert.equal(
    new Set(savedSources.attendance.lines.map((row) => row.attendance_line_id))
      .size,
    expectedRows.length,
  );
  assert(
    savedSources.attendance.lines.every(
      (row) =>
        row.line_status === "ACTIVE" &&
        /^[0-9a-f-]{36}$/.test(row.attendance_line_id) &&
        row.updated_at === savedSources.attendance.updated_at &&
        Number.isFinite(Date.parse(row.updated_at)) &&
        row.updated_by_actor_id ===
          savedSources.attendance.latest_approved_by_actor_id,
    ),
  );
  for (const old of previousRows)
    assert.equal(
      savedSources.attendance.lines.find((row) => pair(row) === pair(old))
        ?.attendance_line_id,
      old.attendance_line_id,
    );
  const previousIds = new Set(
    previousRows.map((row) => row.attendance_line_id),
  );
  assert.equal(
    savedSources.attendance.lines.filter(
      (row) => !previousIds.has(row.attendance_line_id),
    ).length,
    20,
  );
  assert.equal(savedSources.readiness.attendance_approved, true);
  assert.equal(savedSources.readiness.weekly_menu_approved, false);
  assert.equal(savedSources.readiness.ready, false);
  assert.deepEqual((await pantry()).batch, pantryBefore.batch);
  assert.deepEqual(savedSources.weekly_menu, sourceBefore.weekly_menu);
  await open("attendance");
  await until(
    () =>
      evaluate(
        `document.querySelector(${JSON.stringify(student)})?.value==='13'`,
      ),
    "CORRECTION_ATTENDANCE_REOPEN",
  );
  assert.deepEqual((await planning()).attendance, savedSources.attendance);

  const base = (await recipe()).base_authoring;
  const before = await effective(date);
  assert.equal(before.status, "READY");
  const originalLine = before.lines.find(
    (l) =>
      l.final_ingredient_id === authoring.ingredient &&
      l.final_disposition === "PRESENT",
  );
  assert.equal(originalLine?.final_quantity_per_basis, 2.5);
  assert.equal(originalLine.final_unit_id, authoring.unit);
  const originalAdjustments = await adjustments();
  await open("adjustments");
  await action("Tạo lệnh điều chỉnh");
  const createForm = 'form[aria-label="Tạo lệnh điều chỉnh"]';
  // Keep the normal current-date ledger; enter the future effective date
  // through its real segmented keyboard control instead of a test-date prop.
  for (const [part, value] of [
    ["year", "2050"],
    ["month", "09"],
    ["day", "26"],
  ]) {
    const selector = `${createForm} [role="spinbutton"][data-type="${part}"]`;
    await until(
      () =>
        evaluate(
          `Boolean(document.querySelector(${JSON.stringify(selector)}))`,
        ),
      "CORRECTION_EFFECTIVE_DATE_SEGMENT",
    );
    await evaluate(
      `document.querySelector(${JSON.stringify(selector)}).focus()`,
    );
    for (const digit of value) {
      await connection.send("Input.dispatchKeyEvent", {
        type: "keyDown",
        key: digit,
        code: `Digit${digit}`,
        text: digit,
        windowsVirtualKeyCode: digit.charCodeAt(0),
      });
      await connection.send("Input.dispatchKeyEvent", {
        type: "keyUp",
        key: digit,
        code: `Digit${digit}`,
        windowsVirtualKeyCode: digit.charCodeAt(0),
      });
    }
    await until(
      () =>
        evaluate(
          `document.querySelector(${JSON.stringify(selector)})?.getAttribute('aria-valuenow')===${JSON.stringify(String(Number(value)))}`,
        ),
      `CORRECTION_EFFECTIVE_${part}`,
    );
  }
  await field(createForm, "Món", authoring.dish);
  await field(createForm, "Loại công thức", authoring.schoolType);
  await field(createForm, "Hành động", "ADJUST_QUANTITY");
  await field(
    createForm,
    "Thành phần hiện tại",
    `RECIPE_LINE:${originalLine.base_recipe_line_id}`,
  );
  await field(createForm, "Định lượng mới", "3,5");
  await field(createForm, "Lý do điều chỉnh", "Disposable governance create");
  await action("Xem tác động", createForm);
  const createReceipts = count("create_recipe_composition_adjustment");
  await action("Lưu lệnh điều chỉnh", '[role="dialog"]');
  const createdData = await readAfter(
    "create_recipe_composition_adjustment",
    createReceipts,
    adjustments,
    (data) =>
      data.adjustments.length === originalAdjustments.adjustments.length + 1,
  );
  const root = createdData.adjustments.find(
    (row) =>
      !originalAdjustments.adjustments.some(
        (old) => old.adjustment_id === row.adjustment_id,
      ),
  );
  assert.equal(root.scope_kind, "SYSTEM_DISH");
  assert.equal(root.action_kind, "ADJUST_QUANTITY");
  assert.equal(root.school_id, null);
  assert.equal(root.dish_id, authoring.dish);
  assert.equal(root.school_type_id, authoring.schoolType);
  assert.equal(root.target_recipe_line_id, originalLine.base_recipe_line_id);
  assert.equal(root.revisions.length, 1);
  assert.equal(root.current_revision_number, 1);
  assert.equal(root.version, 1);
  assert.equal(root.revisions[0].quantity_per_basis, 3.5);
  assert.equal(root.revisions[0].effective_from, date);
  assert.equal(root.revisions[0].reason_note, "Disposable governance create");
  assert.equal(
    root.revisions[0].unit_id,
    null,
    "Quantity adjustment preserves the typed target Unit through resolution.",
  );
  const rootKey = (row) => [
    row.adjustment_id,
    row.scope_kind,
    row.action_kind,
    row.school_id,
    row.dish_id,
    row.school_type_id,
    row.target_recipe_line_id,
    row.adjustment_line_id,
  ];
  // The compatibility read derives historical lifecycle labels from the root
  // pointer; every other revision field is immutable accepted evidence.
  const frozenRevision = ({ lifecycle_status: _derived, ...value }) => value;
  const checkEffective = async (asOf, quantity, revision) => {
    const result = await effective(asOf);
    assert.equal(result.status, "READY");
    assert.equal(result.school_type_id, authoring.schoolType);
    assert.equal(result.dish_id, authoring.dish);
    const lines = result.lines.filter((l) => l.final_disposition === "PRESENT");
    assert.equal(lines.length, 1);
    const value = lines[0];
    assert.equal(value.final_ingredient_id, authoring.ingredient);
    assert.equal(value.final_unit_id, authoring.unit);
    assert.equal(value.final_quantity_per_basis, quantity);
    assert.equal(value.base_recipe_line_id, originalLine.base_recipe_line_id);
    assert.deepEqual(
      value.applied_adjustment_ids,
      revision ? [root.adjustment_id] : [],
    );
    assert.deepEqual(value.applied_revision_ids, revision ? [revision] : []);
  };
  await checkEffective(date, 3.5, root.current_revision_id);
  const chooseRoot = async () => {
    await field('div[aria-label="Lệnh điều chỉnh"]', "Tình trạng", "all");
    await field(
      'div[aria-label="Lệnh điều chỉnh"]',
      "Tìm lệnh",
      "Disposable browser dish",
    );
    await action(
      "Xem lệnh Đổi định lượng Disposable browser dish",
      "body",
      true,
    );
    await until(
      () =>
        evaluate(
          "Boolean(document.querySelector('[aria-label=\"Chi tiết lệnh\"]'))",
        ),
      "CORRECTION_ADJUSTMENT_DETAIL",
    );
  };
  await open("adjustments");
  await until(
    () =>
      evaluate(
        "[...document.querySelectorAll('tr')].some(row=>row.querySelector('button[aria-label=\"Xem lệnh Đổi định lượng Disposable browser dish\"]')&&row.innerText.includes('Sắp hiệu lực'))",
      ),
    "CORRECTION_NORMAL_SCHEDULED_LEDGER",
  );
  await chooseRoot();
  assert(
    await evaluate(
      "document.querySelector('[aria-label=\"Chi tiết lệnh\"]').innerText.includes('3,5')",
    ),
  );
  await action("Sửa lệnh");
  const correctForm = 'form[aria-label="Sửa lệnh"]';
  await field(correctForm, "Định lượng mới", "3,75");
  await field(
    correctForm,
    "Lý do điều chỉnh",
    "Disposable governance correction",
  );
  await action("Xem tác động", correctForm);
  const correctionReceipts = count("supersede_recipe_composition_adjustment");
  await action("Lưu sửa lệnh", '[role="dialog"]');
  const corrected = (
    await readAfter(
      "supersede_recipe_composition_adjustment",
      correctionReceipts,
      adjustments,
      (data) =>
        data.adjustments.some(
          (row) =>
            row.adjustment_id === root.adjustment_id &&
            row.version === root.version + 1,
        ),
    )
  ).adjustments.find((row) => row.adjustment_id === root.adjustment_id);
  assert.deepEqual(rootKey(corrected), rootKey(root));
  assert.equal(
    corrected.current_revision_number,
    root.current_revision_number + 1,
  );
  assert.equal(corrected.revisions.length, 2);
  assert.deepEqual(
    frozenRevision(
      corrected.revisions.find(
        (r) => r.revision_id === root.current_revision_id,
      ),
    ),
    frozenRevision(root.revisions[0]),
  );
  assert.equal(
    corrected.revisions.find((r) => r.revision_id === root.current_revision_id)
      .lifecycle_status,
    "SUPERSEDED",
  );
  const successor = corrected.revisions.find(
    (r) => r.revision_id === corrected.current_revision_id,
  );
  assert.equal(successor.predecessor_revision_id, root.current_revision_id);
  assert.equal(successor.quantity_per_basis, 3.75);
  assert.equal(successor.reason_note, "Disposable governance correction");
  await checkEffective(date, 3.75, corrected.current_revision_id);
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: "Asia/Ho_Chi_Minh",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(new Date());
  const datePart = (kind) => parts.find((part) => part.type === kind).value;
  const referenceDate = `${datePart("year")}-${datePart("month")}-${datePart("day")}`;
  const ledger = await rpc(
    "get_recipe_adjustment_operator_workbench",
    "RMVP-02B.v2",
    { as_of_date: referenceDate },
  );
  assert.equal(ledger.reference_date, referenceDate);
  const scheduled = ledger.operator_rows.find(
    (row) => row.adjustment_id === root.adjustment_id,
  );
  assert.equal(scheduled.temporal_state, "SCHEDULED");
  assert.equal(scheduled.is_effective_now, false);
  assert.equal(scheduled.version, corrected.version);
  assert.equal(scheduled.current_revision_id, corrected.current_revision_id);
  // Before first effect the backend deliberately displays the first scheduled
  // content; correction editing uses the separate latest command revision.
  assert.equal(
    scheduled.content_revision.revision_id,
    root.current_revision_id,
  );
  assert.equal(scheduled.content_revision.quantity_per_basis, 3.5);
  assert.equal(
    scheduled.command_revision.revision_id,
    corrected.current_revision_id,
  );
  assert.equal(scheduled.command_revision.quantity_per_basis, 3.75);
  assert.equal(scheduled.command_revision.reason_note, successor.reason_note);
  assert.deepEqual(
    scheduled.history.map((revision) => ({
      id: revision.revision_id,
      event: revision.business_event_kind,
      quantity: revision.quantity_per_basis,
      reason: revision.reason_note,
    })),
    [
      {
        id: successor.revision_id,
        event: "CORRECTED",
        quantity: 3.75,
        reason: successor.reason_note,
      },
      {
        id: root.current_revision_id,
        event: "CREATED",
        quantity: 3.5,
        reason: root.revisions[0].reason_note,
      },
    ],
  );
  await open("adjustments");
  await chooseRoot();
  assert(
    await evaluate(
      "document.querySelector('[aria-label=\"Chi tiết lệnh\"]').innerText.includes('Định lượng: 3,5 kg')&&document.querySelector('[aria-label=\"Chi tiết lệnh\"]').innerText.includes('Disposable governance correction')",
    ),
  );
  await action("Sửa lệnh", '[aria-label="Chi tiết lệnh"]');
  await until(
    () =>
      evaluate(
        `Boolean(document.querySelector(${JSON.stringify(correctForm)}))`,
      ),
    "CORRECTION_REOPEN_EDITOR",
  );
  assert.deepEqual(
    await evaluate(
      `(()=>{const form=document.querySelector(${JSON.stringify(correctForm)});return ['Định lượng mới','Lý do điều chỉnh'].map(text=>{const label=[...form.querySelectorAll('label')].find(label=>label.textContent.trim()===text);return (label?.control??label?.parentElement.querySelector('input,textarea')).value;});})()`,
    ),
    ["3.75", successor.reason_note],
    "Reopened correction must use the latest exact command payload.",
  );
  await action("Đóng lệnh", '[aria-label="Chi tiết lệnh"]', true);
  await until(
    () => evaluate(`!document.querySelector(${JSON.stringify(correctForm)})`),
    "CORRECTION_UNCHANGED_EDITOR_CLOSED",
  );
  assert.equal(
    count("supersede_recipe_composition_adjustment"),
    correctionReceipts + 1,
  );
  await chooseRoot();
  await action("Hủy lệnh", '[aria-label="Chi tiết lệnh"]');
  await action("Mở lịch — Hủy từ ngày", '[role="dialog"]', true);
  const cancelDay = '[data-part="table-cell-trigger"][data-value="2050-09-27"]';
  await until(
    () =>
      evaluate(`Boolean(document.querySelector(${JSON.stringify(cancelDay)}))`),
    "CORRECTION_CANCEL_DATE",
  );
  await evaluate(
    `document.querySelector(${JSON.stringify(cancelDay)}).click()`,
  );
  await field(
    '[role="dialog"]',
    "Lý do hủy",
    "Disposable governance cancellation",
  );
  const cancelReceipts = count("cancel_recipe_composition_adjustment");
  await action("Xác nhận hủy", '[role="dialog"]');
  const cancelled = (
    await readAfter(
      "cancel_recipe_composition_adjustment",
      cancelReceipts,
      adjustments,
      (data) =>
        data.adjustments.some(
          (row) =>
            row.adjustment_id === root.adjustment_id &&
            row.version === corrected.version + 1,
        ),
    )
  ).adjustments.find((row) => row.adjustment_id === root.adjustment_id);
  assert.deepEqual(rootKey(cancelled), rootKey(root));
  assert.equal(
    cancelled.current_revision_number,
    corrected.current_revision_number + 1,
  );
  assert.equal(cancelled.revisions.length, 3);
  for (const revision of corrected.revisions) {
    const retained = cancelled.revisions.find(
      (r) => r.revision_id === revision.revision_id,
    );
    assert.equal(retained.lifecycle_status, "SUPERSEDED");
    assert.deepEqual(frozenRevision(retained), frozenRevision(revision));
  }
  const cancellation = cancelled.revisions.find(
    (r) => r.revision_id === cancelled.current_revision_id,
  );
  assert.equal(
    cancellation.predecessor_revision_id,
    corrected.current_revision_id,
  );
  assert.equal(cancellation.lifecycle_status, "CANCELLED");
  assert.equal(cancellation.effective_from, "2050-09-27");
  assert.equal(cancellation.reason_note, "Disposable governance cancellation");
  await checkEffective("2050-09-25", 2.5, null);
  await checkEffective(date, 3.75, corrected.current_revision_id);
  await checkEffective("2050-09-27", 2.5, null);
  assert.deepEqual(
    (await recipe()).base_authoring,
    base,
    "Governance preserves the complete base Recipe.",
  );
  await open("adjustments");
  await chooseRoot();
  assert(
    await evaluate(
      "document.querySelector('[aria-label=\"Chi tiết lệnh\"]').innerText.includes('Disposable governance cancellation')",
    ),
  );
  assert.deepEqual(
    (await adjustments()).adjustments.find(
      (row) => row.adjustment_id === root.adjustment_id,
    ),
    cancelled,
  );
  const finalCatalog = await adjustments();
  assert.deepEqual(
    finalCatalog.adjustments.filter(
      (row) => row.adjustment_id !== root.adjustment_id,
    ),
    originalAdjustments.adjustments,
  );
  return {
    status: "PASS",
    attendanceCorrections: 1,
    adjustmentCreates: 1,
    adjustmentCorrections: 1,
    adjustmentCancellations: 1,
    adjustment: root.adjustment_id,
    historicalBaseRetained: true,
    datedEffectiveQuantities: [2.5, 3.75, 2.5],
  };
}
