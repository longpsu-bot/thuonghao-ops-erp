// Existing D-044 and School PXK commands through the real disposable operator UI.
import assert from "node:assert/strict";
import {
  supplierQuantityFootprint,
  schoolQuantityFootprint,
} from "./atlas-procurement-browser-coverage.mjs";

export async function certifyConnectedReplacements({
  connection,
  evaluate,
  until,
  read,
  readAllocations,
  readSchoolCoverage,
  readDispatch,
  readReconciliation,
  allocationQuantities,
  coverage,
  schoolSourceKeys,
  pxkScope,
  sql,
  url,
}) {
  const count = (name) =>
    Number(
      sql(
        `select count(*) from atlas_core.command_receipts where command_name='${name}' and outcome='COMPLETED'`,
      ),
    );
  const originalOrders = await read();
  const originalSchoolRows = await readDispatch();
  const assertExportable = (orders) => {
    assert(orders.length > 0);
    for (const order of orders) {
      assert.equal(order.document_snapshot_complete, true);
      assert.equal(order.export_ready, true);
      assert.equal(order.allowed_actions.export, true);
    }
  };
  const schoolScopes = (rows) =>
    rows
      .map((row) =>
        [row.service_date, row.school_id, row.delivery_location_id].join("|"),
      )
      .sort();
  const allocationNotes = (rows) =>
    new Map(
      rows.flatMap((row) =>
        row.splits.map((split) => [
          `${row.family.family_id}|${split.supplier_id}`,
          split.supplier_note ?? null,
        ]),
      ),
    );
  assertExportable(originalOrders);
  assert.equal(originalOrders.length, 2);
  assert(
    originalOrders.every(
      (o) =>
        o.status === "RELEASED_TO_SUPPLIER" && o.commitment_state === "CURRENT",
    ),
  );
  assert.equal(originalSchoolRows.length, 2);
  assert(
    originalSchoolRows.every(
      (row) => row.state === "CURRENT" && row.current_release,
    ),
  );
  const allocations = await readAllocations();
  const family = allocations.find(
    (row) =>
      row.state === "BALANCED" &&
      row.allowed_actions.save_allocation &&
      row.splits.filter((s) => Number(s.allocated_quantity) > 0).length === 2,
  );
  assert(
    family?.family.family_id,
    "One exact saved dual-supplier family required.",
  );
  assert(
    originalOrders.every((o) =>
      o.lines.some((l) => l.source.family_id === family.family.family_id),
    ),
  );
  const originalSchools = readSchoolCoverage();
  const frozenOrder = (o) => ({
    id: o.purchase_order_id,
    number: o.document_number,
    supplier: o.supplier,
    date: o.service_date,
    revision: o.current_revision,
    lines: o.lines,
  });
  const frozenSchool = ({ status: _status, ...document }) => document;
  const open = async (stage) => {
    const origin = await evaluate("performance.timeOrigin");
    await connection.send("Page.navigate", {
      url: stage ? `${url}?stage=${stage}` : url,
    });
    await until(
      () =>
        evaluate(
          `performance.timeOrigin!==${origin}&&document.readyState==='complete'`,
        ),
      "REPLACEMENT_NEW_DOCUMENT",
    );
  };
  const clickOnce = async (label, selector = "button", attribute = false) => {
    const expression = `(()=>[...document.querySelectorAll(${JSON.stringify(selector)})].find(b=>${attribute ? "b.getAttribute('aria-label')" : "b.textContent.trim()"}===${JSON.stringify(label)}&&!b.disabled))()`;
    await until(
      () => evaluate(`Boolean(${expression})`),
      `REPLACEMENT_READY_${label}`,
    );
    assert(
      await evaluate(
        `(()=>{const b=${expression};if(!b)return false;b.click();return true;})()`,
      ),
    );
  };
  const allocationReceipts = count("save_school_catering_supplier_allocation");
  const createReceipts = count(
    "create_school_catering_purchase_order_replacement",
  );
  const releaseReceipts = count("release_school_catering_purchase_order");
  const pxkReceipts = count("release_school_dispatch_document");
  await open("allocation");
  const label = await until(
    () =>
      evaluate(
        `(()=>{const r=[...document.querySelectorAll('tr')].find(r=>r.querySelector('[data-allocation-ingredient]')?.textContent.trim()===${JSON.stringify(family.ingredient_name)});const b=r?.querySelector('button[aria-label^="Xem phân bổ "]');return !b?.disabled&&b?.getAttribute('aria-label');})()`,
      ),
    "REPLACEMENT_FAMILY_READY",
  );
  await clickOnce(label, "button[aria-label]", true);
  const noteLabel = await until(
    () =>
      evaluate(
        "document.querySelector('textarea[aria-label^=\"Ghi chú cho \"]:not(:disabled)')?.getAttribute('aria-label')",
      ),
    "REPLACEMENT_NOTE_READY",
  );
  const note = "Disposable explicit replacement note";
  const editedSplits = family.splits.filter(
    (split) => noteLabel === `Ghi chú cho ${split.supplier_name}`,
  );
  assert.equal(
    editedSplits.length,
    1,
    "Exactly one saved supplier identified by the editor label.",
  );
  const editedKey = `${family.family.family_id}|${editedSplits[0].supplier_id}`;
  const expectedNotes = allocationNotes(allocations);
  assert.notEqual(expectedNotes.get(editedKey), note);
  expectedNotes.set(editedKey, note);
  await evaluate(
    `(()=>{const e=[...document.querySelectorAll('textarea')].find(e=>e.getAttribute('aria-label')===${JSON.stringify(noteLabel)});Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype,'value').set.call(e,${JSON.stringify(note)});e.dispatchEvent(new Event('input',{bubbles:true}));})()`,
  );
  await clickOnce("Lưu phân bổ");
  const savedAllocations = await until(async () => {
    const rows = await readAllocations();
    return rows.some(
      (r) =>
        r.family.family_id === family.family.family_id &&
        r.family.version === family.family.version + 1 &&
        r.splits.some((s) => s.supplier_note === note),
    )
      ? rows
      : null;
  }, "REPLACEMENT_ALLOCATION_PERSISTED");
  assert.equal(
    count("save_school_catering_supplier_allocation"),
    allocationReceipts + 1,
  );
  assert.deepEqual(
    allocationQuantities(savedAllocations),
    allocationQuantities(allocations),
    "Note-only successor preserves all source/supplier/School quantities.",
  );
  assert.deepEqual(
    allocationNotes(savedAllocations),
    expectedNotes,
    "Only the intended supplier/family note changes.",
  );
  const assertCurrentNotes = (orders) => {
    let editedLines = 0;
    for (const order of orders)
      for (const line of order.lines) {
        const key = `${line.source.family_id}|${order.supplier.supplier_id}`;
        assert(expectedNotes.has(key));
        assert.equal(line.supplier_note ?? null, expectedNotes.get(key));
        if (key === editedKey) editedLines++;
      }
    assert.equal(
      editedLines,
      1,
      "Replacement freezes the exact edited supplier note once.",
    );
  };
  const stale = await read();
  assert.equal(stale.length, 2);
  assertExportable(stale);
  assert(
    stale.every(
      (o) =>
        o.commitment_state === "REPLACEMENT_REQUIRED" &&
        o.allowed_actions.create_replacement,
    ),
  );
  const blockedSchools = await readDispatch();
  assert.deepEqual(
    schoolScopes(blockedSchools),
    schoolScopes(originalSchoolRows),
  );
  assert(
    blockedSchools.every(
      (row) =>
        row.state === "BLOCKED" &&
        !row.allowed_actions.replace &&
        !row.allowed_actions.release,
    ),
    "No PXK command before complete current PO coverage.",
  );
  await open();
  for (const old of originalOrders) {
    await clickOnce(
      `Xem đơn ${old.supplier.supplier_name} · 19/09/2050 · ${old.document_number}`,
      "button[aria-label]",
      true,
    );
    await clickOnce("Tạo đơn thay thế");
    await until(
      async () =>
        (await read()).some(
          (o) =>
            o.replaces_purchase_order_id === old.purchase_order_id &&
            o.status === "DRAFT",
        ),
      "REPLACEMENT_DRAFT_PERSISTED",
    );
  }
  assert.equal(
    count("create_school_catering_purchase_order_replacement"),
    createReceipts + 2,
  );
  const reviewed = await read();
  const drafts = reviewed.filter((o) => o.status === "DRAFT");
  assert.equal(drafts.length, 2);
  assertCurrentNotes(drafts);
  assertExportable(reviewed.filter((o) => o.status === "RELEASED_TO_SUPPLIER"));
  for (const old of originalOrders) {
    const retained = reviewed.find(
      (o) => o.purchase_order_id === old.purchase_order_id,
    );
    assert.equal(retained.status, "RELEASED_TO_SUPPLIER");
    assert.deepEqual(
      frozenOrder(retained),
      frozenOrder(old),
      "Original released content remains frozen while replacement Drafts are reviewed.",
    );
  }
  assert(
    drafts.every(
      (o) =>
        !o.document_number &&
        o.commitment_state === "DRAFT_CURRENT" &&
        o.release_eligible,
    ),
  );
  const freshSchools = readSchoolCoverage();
  const supplierTotals = (orders) =>
    supplierQuantityFootprint(orders)
      .map(({ id: _id, ...value }) => value)
      .sort((a, b) => a.supplier.localeCompare(b.supplier));
  assert.deepEqual(supplierTotals(drafts), supplierTotals(originalOrders));
  assert.deepEqual(
    schoolQuantityFootprint(drafts, freshSchools),
    schoolQuantityFootprint(originalOrders, originalSchools),
  );
  await clickOnce("Phát hành tất cả PO (2)");
  await until(
    () => evaluate("document.body.innerText.includes('Đã phát hành 2/2 PO.')"),
    "REPLACEMENT_PO_RELEASE_READBACK",
  );
  const released = await read();
  const successors = released.filter((o) =>
    drafts.some((d) => d.purchase_order_id === o.purchase_order_id),
  );
  assert.equal(successors.length, 2);
  assertCurrentNotes(successors);
  assertExportable(released);
  assert(
    successors.every(
      (o) =>
        o.status === "RELEASED_TO_SUPPLIER" &&
        o.commitment_state === "CURRENT" &&
        o.document_number,
    ),
  );
  assert.equal(
    new Set([...originalOrders, ...successors].map((o) => o.document_number))
      .size,
    4,
  );
  assert.deepEqual(
    coverage(successors),
    coverage(drafts, freshSchools),
    "Each replacement freezes its exact reviewed current source/School coverage.",
  );
  for (const old of originalOrders) {
    const historical = released.find(
      (o) => o.purchase_order_id === old.purchase_order_id,
    );
    const successor = successors.find(
      (o) => o.replaces_purchase_order_id === old.purchase_order_id,
    );
    assert(successor);
    assert.equal(historical.status, "SUPERSEDED");
    assert.equal(historical.version, old.version + 1);
    assert.equal(
      historical.replaced_by_purchase_order_id,
      successor.purchase_order_id,
    );
    assert.deepEqual(frozenOrder(historical), frozenOrder(old));
  }
  assert.equal(
    count("release_school_catering_purchase_order"),
    releaseReceipts + 2,
  );
  const schoolTargets = await readDispatch();
  assert.equal(schoolTargets.length, 2);
  assert(
    schoolTargets.every(
      (row) =>
        row.state === "REPLACEMENT_REQUIRED" &&
        row.allowed_actions.replace &&
        row.preview.ready,
    ),
  );
  for (const row of schoolTargets) {
    const old = originalSchoolRows.find(
      (value) =>
        value.school_id === row.school_id &&
        value.delivery_location_id === row.delivery_location_id,
    ).current_release;
    assert.equal(
      row.current_release.school_dispatch_release_id,
      old.school_dispatch_release_id,
    );
    assert.notEqual(row.preview.source_fingerprint, old.source_fingerprint);
    assert.deepEqual(frozenSchool(row.current_release), frozenSchool(old));
    assert.deepEqual(
      pxkScope(row, row.preview.lines),
      pxkScope(old, old.lines),
    );
  }
  await open("pxk");
  const successorSchools = [];
  for (const target of schoolTargets) {
    const choose = `(()=>[...document.querySelectorAll('button[aria-describedby]')].find(b=>b.getAttribute('aria-describedby').includes(${JSON.stringify(target.school_id)})&&b.textContent.trim()==='Tạo phiếu thay thế'&&!b.disabled))()`;
    await until(
      () => evaluate(`Boolean(${choose})`),
      "REPLACEMENT_PXK_ROW_READY",
    );
    await evaluate(`(${choose}).click()`);
    await clickOnce("Phát hành phiếu thay thế");
    const current = await until(async () => {
      const row = (await readDispatch()).find(
        (r) =>
          r.school_id === target.school_id &&
          r.delivery_location_id === target.delivery_location_id,
      );
      return row?.state === "CURRENT" &&
        row.current_release?.predecessor_release_id ===
          target.current_release.school_dispatch_release_id
        ? row
        : null;
    }, "REPLACEMENT_PXK_PERSISTED");
    const document = current.current_release;
    assert.equal(document.export_ready, true);
    assert.equal(current.allowed_actions.export, true);
    assert.notEqual(
      document.school_dispatch_release_id,
      target.current_release.school_dispatch_release_id,
    );
    assert.notEqual(
      document.document_number,
      target.current_release.document_number,
    );
    assert.equal(
      document.source_fingerprint,
      target.preview.source_fingerprint,
    );
    assert.deepEqual(
      pxkScope(document, document.lines),
      pxkScope(target, target.preview.lines),
    );
    for (const line of document.lines) {
      const preview = target.preview.lines.find(
        (l) =>
          l.ingredient_id === line.ingredient_id && l.unit_id === line.unit_id,
      );
      assert.deepEqual(
        schoolSourceKeys(line.sources),
        schoolSourceKeys(preview.sources),
      );
    }
    const historical = current.history.find(
      (old) =>
        old.school_dispatch_release_id ===
        target.current_release.school_dispatch_release_id,
    );
    assert.equal(historical?.status, "SUPERSEDED");
    assert.deepEqual(
      frozenSchool(historical),
      frozenSchool(target.current_release),
    );
    successorSchools.push(document);
    await clickOnce("Đóng chi tiết", "button[aria-label]", true);
  }
  assert.equal(count("release_school_dispatch_document"), pxkReceipts + 2);
  await open("pxk");
  await until(
    () =>
      evaluate(
        `document.body.innerText.includes(${JSON.stringify(successorSchools[0].document_number)})`,
      ),
    "REPLACEMENT_PXK_REOPEN",
  );
  const reopened = await readDispatch();
  for (const document of successorSchools)
    assert.deepEqual(
      reopened.find(
        (r) =>
          r.school_id === document.school_id &&
          r.delivery_location_id === document.delivery_location_id,
      )?.current_release,
      document,
    );
  const comparison = await readReconciliation();
  assert.equal(comparison.length, 2);
  assert(
    comparison.every(
      (r) =>
        r.comparison_status === "OK" &&
        r.pxk_state === "CURRENT" &&
        r.blockers.length === 0 &&
        r.quantity_totals_by_unit.length > 0 &&
        r.quantity_totals_by_unit.every((q) =>
          /^0(?:\.0+)?$/.test(q.delta_quantity),
        ),
    ),
  );
  for (const row of comparison) {
    const document = successorSchools.find(
      (d) =>
        d.school_id === row.school_id &&
        d.delivery_location_id === row.delivery_location_id,
    );
    assert(document);
    assert.equal(
      row.school_dispatch_release_id,
      document.school_dispatch_release_id,
    );
    const expected = pxkScope(document, document.lines);
    assert.deepEqual(
      pxkScope(
        row,
        row.details.map((line) => ({ ...line, quantity: line.po_quantity })),
      ),
      expected,
    );
    assert.deepEqual(
      pxkScope(
        row,
        row.details.map((line) => ({ ...line, quantity: line.pxk_quantity })),
      ),
      expected,
    );
    const covered = successors.filter((order) =>
      order.lines.some((line) =>
        line.school_breakdown.some(
          (s) =>
            s.school_id === row.school_id &&
            s.delivery_location_id === row.delivery_location_id &&
            !/^0(?:\.0+)?$/.test(s.ordered_quantity),
        ),
      ),
    );
    assert.deepEqual(
      new Set(row.purchase_order_ids),
      new Set(covered.map((o) => o.purchase_order_id)),
    );
  }
  await open("reconciliation");
  await until(
    () =>
      evaluate(
        "document.body.innerText.replace(/\\s+/g,' ').includes('Khớp 2')",
      ),
    "REPLACEMENT_MATCHING_RECONCILIATION_UI",
  );
  await evaluate(
    "(()=>{const s=document.querySelector('select[aria-label=\"Tình trạng\"]');Object.getOwnPropertyDescriptor(HTMLSelectElement.prototype,'value').set.call(s,'all');s.dispatchEvent(new Event('change',{bubbles:true}));})()",
  );
  await until(
    () =>
      evaluate(
        "document.querySelector('table[aria-label=\"Đối chiếu theo trường\"]')?.querySelectorAll('tbody tr').length===2",
      ),
    "REPLACEMENT_VISIBLE_MATCHES",
  );
  assert(
    await evaluate(
      `(()=>{const text=document.querySelector('table[aria-label="Đối chiếu theo trường"]').innerText;return ${JSON.stringify(successorSchools.map((d) => d.document_number))}.every(number=>text.includes(number));})()`,
    ),
  );
  return {
    status: "PASS",
    allocationSuccessors: 1,
    replacementDrafts: 2,
    replacementPoReleases: 2,
    replacementPxkReleases: 2,
    poNumbers: successors.map((o) => o.document_number),
    pxkNumbers: successorSchools.map((d) => d.document_number),
    exactHistoricalSnapshotsRetained: true,
  };
}
