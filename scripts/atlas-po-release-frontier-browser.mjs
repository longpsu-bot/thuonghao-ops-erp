// A distinct future week on the already reset disposable runner. Reuse only its
// synthetic master facts; all operational prerequisites use authenticated commands.
import assert from "node:assert/strict";
import { writeFileSync } from "node:fs";
import path from "node:path";

export async function certifyPoReleaseFrontier({
  connection,
  evaluate,
  until,
  operator,
  subject,
  sql,
  source,
  url,
  evidence,
}) {
  assert(
    process.env.GITHUB_ACTIONS === "true" ||
      process.env.ATLAS_DISPOSABLE_BROWSER_CERTIFICATION === "true",
  );
  assert.equal(subject, "a7400000-0000-4000-8000-000000000101");
  const date = "2050-10-03";
  assert.equal(
    sql(
      `select count(*) from atlas_planning.confirmed_need_batches where period_start='${date}'`,
    ),
    "0",
  );
  // Only reuse the two request/identity helpers, never historical acceptance writes.
  const start = source.indexOf("-- Disposable local/CI only.");
  const helpers = source.slice(
    source.indexOf("create function pg_temp.ng_id", start),
    source.indexOf("insert into atlas_core.actors", start),
  );
  assert(
    helpers.includes("create function pg_temp.ng_request") &&
      !helpers.includes("insert into"),
  );
  const setup =
    sql(`begin; set local search_path=extensions,public,pg_catalog; select no_plan();
${helpers}
create temporary table frontier_commands(name text,response jsonb);
grant select,insert on frontier_commands to authenticated;
select set_config('request.jwt.claim.sub',pg_temp.ng_id(101)::text,true);
select set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.ng_id(101),'role','authenticated')::text,true);
create temporary table frontier_requests(name text,request jsonb);
grant select on frontier_requests to authenticated;
with rows as (
 select pg_temp.ng_id(5000+i) school_id,date '${date}' service_date,'soup' menu_slot_code,
 pg_temp.ng_id(1001) dish_id,'frontier-menu-'||i source_row_reference from generate_series(1,2)i
), canonical as(select atlas_core.rmvp_03a_canonical_menu_rows(jsonb_agg(to_jsonb(rows))) rows from rows)
insert into frontier_requests select 'menu',pg_temp.ng_request('RMVP-03A.v2','WEEKLY_MENU_SAVED',jsonb_build_object(
 'week_start','${date}','source_type','GOOGLE_SHEET','source_name','Disposable release frontier',
 'source_signature',atlas_core.rmvp_03a_menu_signature(rows),'expected_source_signature',null,'rows',rows)) from canonical;
with rows as (
 select pg_temp.ng_id(5000+i) school_id,date '${date}' service_date,95 student_portions,5 teacher_portions,
 'frontier-attendance-'||i source_row_reference from generate_series(1,2)i
), canonical as(select atlas_core.rmvp_03a_canonical_attendance_rows(jsonb_agg(to_jsonb(rows))) rows from rows)
insert into frontier_requests select 'attendance',pg_temp.ng_request('RMVP-03A.v2','ATTENDANCE_SAVED',jsonb_build_object(
 'week_start','${date}','source_type','BULK_PASTE','source_name','Disposable release frontier',
 'source_signature',atlas_core.rmvp_03a_attendance_signature(rows),'expected_source_signature',null,'rows',rows)) from canonical;
insert into frontier_requests values('pantry',pg_temp.ng_request('PANTRY-02.v3','PANTRY_SAVED',jsonb_build_object(
 'week_start','${date}','no_additions_confirmed',true,'rows','[]'::jsonb,
 'source_signature',atlas_core.pantry_02_signature('${date}',true,'[]'::jsonb),
 'expected_source_signature',null,'school_date_modes','[]'::jsonb)));
set local role authenticated;
insert into frontier_commands select name,atlas_api.save_weekly_menu(request) from frontier_requests where name='menu';
insert into frontier_commands select name,atlas_api.save_attendance(request) from frontier_requests where name='attendance';
insert into frontier_commands select name,atlas_api.save_pantry(request) from frontier_requests where name='pantry';
insert into frontier_commands values('generation',atlas_api.execute_need_generation(pg_temp.ng_request('RMVP-04.v3','NEED_GENERATION_EXECUTED',
 jsonb_build_object('service_date','${date}','expected_current_need_generation_run_id',null))));
reset role;
insert into frontier_requests
select 'save',pg_temp.ng_request('RMVP-05.v2','CONFIRMED_NEED_SAVED',jsonb_build_object(
 'confirmed_need_batch_id',b.confirmed_need_batch_id,'lines',(
 select jsonb_agg(jsonb_build_object('confirmed_need_line_id',l.confirmed_need_line_id,
 'expected_current_revision_id',r.confirmed_need_line_revision_id,'expected_current_decision_id',null,
 'proposed_confirmed_quantity',r.confirmed_quantity::text,'reason_code','PROPOSAL_ACCEPTED','reason_note',null))
 from atlas_planning.confirmed_need_lines l join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_id)
 where l.confirmed_need_batch_id=b.confirmed_need_batch_id and r.is_current)))
 ||jsonb_build_object('expected_version',b.version,'reason_note',null)
from atlas_planning.confirmed_need_batches b where b.period_start='${date}' and b.period_end=b.period_start;
set local role authenticated;
insert into frontier_commands select name,atlas_api.save_confirmed_needs(request) from frontier_requests where name='save';
reset role;
insert into frontier_requests
select 'allocation',pg_temp.ng_request('CONFIRMED-SUPPLIER-ALLOCATION.v1','CONFIRMED_SUPPLIER_ALLOCATION_SAVED',jsonb_build_object(
 'family',jsonb_build_object('service_date',p->'service_date','delivery_location_id',p->'delivery_location_id',
 'ingredient_id',p->'ingredient_id','unit_id',p->'unit_id','expected_source_fingerprint',p->'source_fingerprint',
 'expected_source_batch_id',p->'source_confirmed_need_batch_id','expected_source_batch_version',p->'source_confirmed_need_batch_version'),
 'splits',jsonb_build_array(jsonb_build_object('supplier_id',pg_temp.ng_id(60),'allocated_quantity','22','supplier_note',null),
 jsonb_build_object('supplier_id',pg_temp.ng_id(61),'allocated_quantity','18','supplier_note',null))))
 ||jsonb_build_object('expected_version',0,'reason_note',null)
from atlas_core.purchase_review_confirmed_sources('${date}','${date}') p
where p->>'ingredient_id'=pg_temp.ng_id(2001)::text and (p->>'family_quantity')::numeric=40;
set local role authenticated;
insert into frontier_commands select name,atlas_api.save_confirmed_supplier_allocation(request) from frontier_requests where name='allocation';
reset role;
insert into frontier_requests
select 'prepare',pg_temp.ng_request('PURCHASE-COMMITMENT.v1','PURCHASE_ORDERS_PREPARED',jsonb_build_object(
 'confirmed_need_batch_id',b.confirmed_need_batch_id,'service_date','${date}'))
 ||jsonb_build_object('expected_version',b.version,'reason_note',null)
from atlas_planning.confirmed_need_batches b where b.period_start='${date}' and b.period_end=b.period_start;
set local role authenticated;
insert into frontier_commands select name,atlas_api.prepare_school_catering_purchase_orders(request) from frontier_requests where name='prepare';
reset role;
select is(count(*),7::bigint,'all seven distinct frontier prerequisites executed') from frontier_commands;
select is(response->>'success','true','frontier prerequisite '||name) from frontier_commands;
set constraints all immediate; commit;`);
  assert(!/^not ok\b/m.test(setup), setup);
  const rpc = async (name, contract, payload, command) => {
    const id = crypto.randomUUID();
    const request = {
      contract_version: contract,
      requested_by_auth_subject: subject,
      correlation_id: id,
      payload,
    };
    if (command)
      Object.assign(request, {
        command_id: id,
        idempotency_key: `frontier:${id}`,
        requested_at: new Date().toISOString(),
        reason_note: null,
        ...command,
      });
    const result = await operator.schema("atlas_api").rpc(name, { request });
    assert(
      !result.error && result.data?.success,
      `${name}: ${JSON.stringify(result.error ?? result.data)}`,
    );
    return result.data;
  };
  const read = (extra = {}) =>
    rpc(
      "get_school_catering_purchase_orders",
      "SCHOOL-CATERING-PROCUREMENT.v1",
      {
        date_start: date,
        date_end: date,
        supplier_ids: [],
        statuses: [],
        search: null,
        ...extra,
      },
    );
  const initial = (await read()).purchase_orders;
  const unaffected = (
    await read({ date_start: "2050-09-19", date_end: "2050-09-19" })
  ).purchase_orders;
  assert.equal(initial.length, 2);
  assert(initial.every((o) => o.release_eligible && o.allowed_actions.release));
  // One authentic quantity correction in the other, single-Supplier family.
  const correction = JSON.parse(
    sql(`select jsonb_build_object('expected_version',b.version,'payload',jsonb_build_object(
 'confirmed_need_batch_id',b.confirmed_need_batch_id,'correction',jsonb_build_object(
 'expected_confirmed_need_release_id',b.current_confirmed_need_release_id,
 'expected_purchase_handoff_batch_id',h.purchase_handoff_batch_id,
 'expected_purchase_handoff_revision_id',hr.purchase_handoff_revision_id,'expected_purchase_handoff_version',h.version,
 'expected_source_fingerprint',encode(sha256(convert_to(atlas_core.rmvp_07_validated_facts_projection(b.confirmed_need_batch_id)::text,'UTF8')),'hex')),
 'lines',jsonb_build_array(jsonb_build_object('confirmed_need_line_id',l.confirmed_need_line_id,
 'expected_current_revision_id',r.confirmed_need_line_revision_id,'expected_current_decision_id',l.current_confirmed_need_line_decision_id,
 'proposed_confirmed_quantity',(r.confirmed_quantity+1)::text,'reason_code','OPERATIONAL_QUANTITY_ADJUSTMENT',
 'reason_note','Disposable one-unit quantity correction'))))
from atlas_planning.confirmed_need_batches b join atlas_planning.confirmed_need_lines l using(confirmed_need_batch_id)
join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_id)
join atlas_planning.purchase_handoff_batches h on h.confirmed_need_batch_id=b.confirmed_need_batch_id
join atlas_planning.purchase_handoff_revisions hr using(purchase_handoff_batch_id)
where b.period_start='${date}' and l.school_id='a7400000-0000-4000-8000-000000005001'
and l.ingredient_id='a7400000-0000-4000-8000-000000002002' and r.is_current and hr.is_current`),
  );
  await rpc("save_confirmed_needs", "RMVP-05.v3", correction.payload, {
    expected_version: correction.expected_version,
    reason_code: "CONFIRMED_NEED_SAVED",
  });
  const allocations = await rpc(
    "get_confirmed_supplier_allocation_workbench",
    "CONFIRMED-SUPPLIER-ALLOCATION.v1",
    {
      date_start: date,
      date_end: date,
      school_ids: [],
      states: [],
      search: null,
    },
  );
  const row = allocations.rows.find((r) => r.ingredient_id.endsWith("002002"));
  assert(row && row.state !== "BALANCED");
  await rpc(
    "save_confirmed_supplier_allocation",
    "CONFIRMED-SUPPLIER-ALLOCATION.v1",
    {
      family: {
        service_date: date,
        delivery_location_id: row.delivery_location_id,
        ingredient_id: row.ingredient_id,
        unit_id: row.unit_id,
        expected_source_fingerprint: row.family.source_fingerprint,
        expected_source_batch_id: row.family.source_confirmed_need_batch_id,
        expected_source_batch_version:
          row.family.source_confirmed_need_batch_version,
      },
      splits: [
        {
          supplier_id: "a7400000-0000-4000-8000-000000000060",
          allocated_quantity: row.family_quantity,
          supplier_note: "Explicit corrected quantity acceptance",
        },
      ],
    },
    {
      expected_version: row.family.version,
      reason_code: "CONFIRMED_SUPPLIER_ALLOCATION_SAVED",
    },
  );
  const blocked = await read();
  assert.equal(
    blocked.purchase_orders.filter((o) => o.commitment_state === "DRAFT_STALE")
      .length,
    1,
  );
  const current = blocked.purchase_orders.find(
    (o) => o.commitment_state === "DRAFT_CURRENT",
  );
  assert(current);
  assert(
    blocked.purchase_orders.every(
      (o) => !o.release_eligible && !o.allowed_actions.release,
    ),
  );
  const filtered = await read({
    supplier_ids: [current.supplier.supplier_id],
    search: current.supplier.supplier_name,
  });
  assert.equal(filtered.purchase_orders.length, 1);
  assert.equal(filtered.purchase_orders[0].allowed_actions.release, false);
  assert(
    filtered.blockers.some(
      (m) => m.includes("03/10/2050") && m.includes("Cần cập nhật"),
    ),
  );
  assert(!JSON.stringify(filtered.blockers).includes("OTHER_INVALID_STATE"));
  const multi = (await read({ date_start: "2050-09-19" })).purchase_orders;
  assert.deepEqual(
    multi.filter((o) => o.service_date === "2050-09-19"),
    unaffected,
  );
  assert(
    multi
      .filter((o) => o.service_date === date)
      .every((o) => !o.release_eligible),
  );
  const receiptCount = () =>
    Number(
      sql(
        `select count(*) from atlas_core.command_receipts where command_name='release_school_catering_purchase_order' and outcome='COMPLETED'`,
      ),
    );
  const beforeReceipts = receiptCount();
  const testUrl = `${url}?date=${date}`;
  await connection.send("Page.navigate", { url: testUrl });
  await until(
    () =>
      evaluate(
        `[...document.querySelectorAll('button')].some(b=>b.textContent.trim()==='Phát hành tất cả PO (0)'&&b.disabled)&&document.body.innerText.includes('Cần chuẩn bị đầy đủ đơn mua')`,
      ),
    "FRONTIER_BLOCKED_UI",
  );
  await evaluate(
    `(()=>{const input=document.querySelector('input[placeholder="Nhà cung ứng, số đơn, nguyên liệu, trường"]');Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set.call(input,${JSON.stringify(current.supplier.supplier_name)});input.dispatchEvent(new Event('input',{bubbles:true}));})()`,
  );
  await until(
    () =>
      evaluate(
        `document.body.innerText.includes('1 đơn mua đang hiển thị')&&[...document.querySelectorAll('button')].some(b=>b.textContent.trim()==='Phát hành cho NCC'&&b.disabled)`,
      ),
    "FRONTIER_FILTERED_DISABLED_UI",
  );
  const shot = await connection.send("Page.captureScreenshot", {
    format: "png",
  });
  writeFileSync(
    path.join(evidence, "release-frontier-blocked.png"),
    Buffer.from(shot.data, "base64"),
  );
  assert.equal(receiptCount(), beforeReceipts);
  await connection.send("Page.navigate", { url: testUrl });
  await until(
    () =>
      evaluate(
        `(()=>{const b=[...document.querySelectorAll('button[aria-label^="Xem đơn "]')].find(b=>b.getAttribute('aria-label').endsWith('Cần cập nhật'));if(!b||b.disabled)return false;b.click();return true;})()`,
      ),
    "FRONTIER_STALE_DRAFT_READY",
  );
  await until(
    () =>
      evaluate(
        `[...document.querySelectorAll('button')].some(b=>b.textContent.trim()==='Tạo lại đơn cần cập nhật'&&!b.disabled)`,
      ),
    "FRONTIER_REGENERATION_READY",
  );
  assert(
    await evaluate(
      `(()=>{const b=[...document.querySelectorAll('button')].find(b=>b.textContent.trim()==='Tạo lại đơn cần cập nhật');if(!b||b.disabled)return false;b.click();return true;})()`,
    ),
  );
  await until(
    () =>
      evaluate(
        `[...document.querySelectorAll('button')].some(b=>b.textContent.trim()==='Phát hành tất cả PO (2)'&&!b.disabled)`,
      ),
    "FRONTIER_REPAIRED_UI",
  );
  const regenerated = (await read()).purchase_orders;
  assert.equal(regenerated.length, 2);
  assert.deepEqual(
    new Set(regenerated.map((o) => o.purchase_order_id)),
    new Set(initial.map((o) => o.purchase_order_id)),
  );
  assert(
    regenerated.every(
      (o) =>
        o.commitment_state === "DRAFT_CURRENT" && o.allowed_actions.release,
    ),
  );
  const exact = (value) =>
    String(value)
      .replace(/(\.\d*?)0+$/, "$1")
      .replace(/\.$/, "");
  const quantities = (orders) =>
    orders
      .flatMap((o) =>
        o.lines.map((l) => [
          o.supplier.supplier_id,
          l.ingredient.ingredient_id,
          l.unit.unit_id,
          exact(l.ordered_quantity),
          l.service_date,
          l.delivery_location.delivery_location_id,
        ]),
      )
      .sort((a, b) => JSON.stringify(a).localeCompare(JSON.stringify(b)));
  const beforeRelease = quantities(regenerated);
  const accepted = await rpc(
    "get_confirmed_supplier_allocation_workbench",
    "CONFIRMED-SUPPLIER-ALLOCATION.v1",
    {
      date_start: date,
      date_end: date,
      school_ids: [],
      states: [],
      search: null,
    },
  );
  assert(
    accepted.rows.length > 0 &&
      accepted.rows.every((row) => row.state === "BALANCED"),
  );
  const expected = accepted.rows
    .flatMap((row) =>
      row.splits.map((split) => [
        split.supplier_id,
        row.ingredient_id,
        row.unit_id,
        exact(split.allocated_quantity),
        row.service_date,
        row.delivery_location_id,
      ]),
    )
    .sort((a, b) => JSON.stringify(a).localeCompare(JSON.stringify(b)));
  assert.deepEqual(
    beforeRelease,
    expected,
    "Regenerated Draft quantities/Units/scope must equal explicitly saved allocation facts.",
  );
  assert.equal(receiptCount(), beforeReceipts);
  assert(
    await evaluate(
      `(()=>{const b=[...document.querySelectorAll('button')].find(b=>b.textContent.trim()==='Phát hành tất cả PO (2)');if(!b||b.disabled)return false;b.click();return true;})()`,
    ),
  );
  await until(
    () => evaluate("document.body.innerText.includes('Đã phát hành 2/2 PO.')"),
    "FRONTIER_RELEASED_UI",
  );
  assert.equal(receiptCount(), beforeReceipts + 2);
  const priorOrigin = await evaluate("performance.timeOrigin");
  const releasedBeforeReload = (await read()).purchase_orders;
  assert.equal(releasedBeforeReload.length, 2);
  assert(releasedBeforeReload.every((o) => o.document_number));
  await connection.send("Page.reload", {});
  await until(
    () =>
      evaluate(
        `performance.timeOrigin!==${JSON.stringify(priorOrigin)}&&document.readyState==='complete'&&Boolean(document.querySelector('button[aria-label="Làm mới dữ liệu"]:not(:disabled)'))&&${JSON.stringify(releasedBeforeReload.map((o) => o.document_number))}.every(number=>document.body.innerText.includes(number))&&[...document.querySelectorAll('button')].some(b=>b.textContent.trim()==='Phát hành tất cả PO (0)'&&b.disabled)`,
      ),
    "FRONTIER_RELEASE_REOPENED",
  );
  const released = (await read()).purchase_orders;
  assert.equal(released.length, 2);
  assert.deepEqual(
    new Set(released.map((o) => o.purchase_order_id)),
    new Set(initial.map((o) => o.purchase_order_id)),
  );
  assert(
    released.every(
      (o) => o.status === "RELEASED_TO_SUPPLIER" && o.document_number,
    ),
  );
  assert.deepEqual(quantities(released), beforeRelease);
  for (const order of released) {
    const label = `Xem đơn ${order.supplier.supplier_name} · 03/10/2050 · ${order.document_number}`;
    assert(
      await evaluate(
        `(()=>{const b=[...document.querySelectorAll('button[aria-label]')].find(b=>b.getAttribute('aria-label')===${JSON.stringify(label)});if(!b||b.disabled)return false;b.click();return true;})()`,
      ),
    );
    const compare = (a, b) =>
      JSON.stringify(a).localeCompare(JSON.stringify(b));
    const values = order.lines
      .map((line) => {
        const quantity = exact(line.ordered_quantity);
        assert(
          /^\d{1,3}(?:\.\d+)?$/.test(quantity),
          "Review fixture quantity formatting beyond the known sub-1000 range.",
        );
        return [
          line.ingredient.ingredient_name,
          `${quantity.replace(".", ",")} kg`,
          `Điểm giao: ${line.delivery_location.location_name}`,
        ];
      })
      .sort(compare);
    const rendered = await until(async () => {
      const actual = await evaluate(
        `(()=>{const root=document.querySelector('[aria-label="Dòng đơn mua"]');if(!root)return null;return [...root.children].map(section=>[...section.firstElementChild.firstElementChild.children].slice(0,3).map(cell=>cell.textContent.trim().replace(/\\s+/g,' ')));})()`,
      );
      return actual &&
        JSON.stringify(actual.sort(compare)) === JSON.stringify(values)
        ? actual
        : null;
    }, "FRONTIER_REOPENED_QUANTITIES");
    assert.deepEqual(
      rendered,
      values,
      "Each reopened row must pair its exact Ingredient, quantity/Unit and delivery location.",
    );
  }
  const releasedShot = await connection.send("Page.captureScreenshot", {
    format: "png",
  });
  writeFileSync(
    path.join(evidence, "release-frontier-released.png"),
    Buffer.from(releasedShot.data, "base64"),
  );
  assert.deepEqual(
    (await read({ date_start: "2050-09-19", date_end: "2050-09-19" }))
      .purchase_orders,
    unaffected,
  );
  return {
    date,
    mixedDrafts: 2,
    currentTargetBlocked: true,
    filteredTargetBlocked: true,
    explicitRegeneration: true,
    released: 2,
    completedReleaseReceipts: 2,
    reopened: true,
  };
}
