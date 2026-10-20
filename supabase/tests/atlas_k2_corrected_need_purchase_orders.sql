-- Authenticated K2 correction-to-PO journey; every fixture write rolls back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=extensions,public,pg_catalog;
set local statement_timeout='8s';
select no_plan();
\ir ../local/purchase_review_confirm_release_fixture.sql

insert into atlas_core.role_capabilities(role_id,capability_id)
select 'b6000000-0000-0000-0000-000000000003',capability_id
from atlas_core.capabilities where capability_code in (
  'planning.need_generation.write','confirmed_need_release.release')
on conflict do nothing;

-- Actual key writes remain forbidden even though row locks require column grants.
create temporary table k2_core_lock_results(table_name text,result boolean);
create function pg_temp.k2_core_write_denied() returns void
language plpgsql set search_path='' as $$
declare target text; key_name text; denied boolean;
begin
  for target,key_name in values
    ('actors','actor_id'),('actor_auth_subjects','actor_auth_subject_id'),
    ('roles','role_id'),('role_capabilities','role_id'),('capabilities','capability_id'),
    ('actor_role_memberships','actor_role_membership_id'),('actor_scopes','actor_scope_id') loop
    denied:=false;
    begin
      execute format('update atlas_core.%I set %I=%I',target,key_name,key_name);
    exception when insufficient_privilege then denied:=true;
    end;
    insert into pg_temp.k2_core_lock_results values(target,denied);
  end loop;
end;
$$;
grant insert on k2_core_lock_results to atlas_procurement_command_runtime;
grant atlas_procurement_command_runtime to postgres with set true;
set local role atlas_procurement_command_runtime;
select atlas_core.school_catering_lock_po_release_actor('b6000000-0000-0000-0000-000000000001');
select pg_temp.k2_core_write_denied();
insert into k2_core_lock_results values('empty_ancestry',atlas_core.school_catering_corrected_allocation_ancestry('{}'::jsonb) is false);
reset role;
grant atlas_procurement_command_runtime to postgres with set false;
select ok(result,'Procurement key-only lock grant cannot update '||table_name)
from k2_core_lock_results order by table_name;
select ok(not exists(select 1 from pg_roles role cross join unnest(array[
  'atlas_core.school_catering_lock_po_release_actor(uuid)',
  'atlas_core.school_catering_corrected_allocation_ancestry(jsonb)']) helper(signature)
  where role.rolname in ('anon','authenticated','service_role')
    and has_function_privilege(role.rolname,helper.signature,'EXECUTE')),
  'private lock and ancestry helpers are inaccessible to public request roles');

create temporary table k2_results(name text primary key,response jsonb not null);
create temporary table k2_requests(name text primary key,request jsonb not null);
grant select,insert on k2_results,k2_requests to authenticated;

create function pg_temp.k2_command(contract text,reason text,version bigint,payload jsonb)
returns jsonb language sql volatile set search_path='' as $$
  select jsonb_build_object('contract_version',contract,'command_id',id,
    'correlation_id',gen_random_uuid(),'idempotency_key','k2:'||id,
    'expected_version',version,
    'requested_by_auth_subject','b6000000-0000-0000-0000-000000000101',
    'requested_at',transaction_timestamp()-interval '1 second',
    'reason_code',reason,'reason_note',null,'payload',payload)
  from (select gen_random_uuid() id) command;
$$;
grant execute on function pg_temp.k2_command(text,text,bigint,jsonb) to authenticated;

create function pg_temp.k3_allocation_read(p_date date) returns jsonb
language sql volatile set search_path='' as $$
  select atlas_api.get_confirmed_supplier_allocation_workbench(jsonb_build_object(
    'contract_version','CONFIRMED-SUPPLIER-ALLOCATION.v1','correlation_id',gen_random_uuid(),
    'requested_by_auth_subject',current_setting('request.jwt.claim.sub',true),
    'payload',jsonb_build_object('date_start',p_date,'date_end',p_date,
      'school_ids','[]'::jsonb,'states','[]'::jsonb,'search',null)));
$$;
grant execute on function pg_temp.k3_allocation_read(date) to authenticated;

create function pg_temp.k3_po_read() returns jsonb
language plpgsql volatile set search_path='' as $$
declare started timestamptz:=clock_timestamp(); answer jsonb;
begin
  answer:=atlas_api.get_school_catering_purchase_orders(jsonb_build_object(
    'contract_version','SCHOOL-CATERING-PROCUREMENT.v1','correlation_id',gen_random_uuid(),
    'requested_by_auth_subject',current_setting('request.jwt.claim.sub',true),
    'payload',jsonb_build_object('date_start','2050-09-19','date_end','2050-09-19',
      'supplier_ids','[]'::jsonb,'statuses','[]'::jsonb,'search',null)));
  if clock_timestamp()-started>=interval '8 seconds' then
    raise exception 'B1 PO read exceeded the public 8s budget' using errcode='57014';
  end if;
  return answer;
end;
$$;
create function pg_temp.k3_pxk_read() returns jsonb
language plpgsql volatile set search_path='' as $$
declare started timestamptz:=clock_timestamp(); answer jsonb;
begin
  answer:=atlas_api.get_school_dispatch_release_workbench(jsonb_build_object(
    'contract_version','SCHOOL-DISPATCH-RELEASE.v1','correlation_id',gen_random_uuid(),
    'requested_by_auth_subject',current_setting('request.jwt.claim.sub',true),
    'payload',jsonb_build_object('date_start','2050-09-19','date_end','2050-09-19',
      'school_ids','[]'::jsonb,'search',null)));
  if clock_timestamp()-started>=interval '8 seconds' then
    raise exception 'B1 PXK read exceeded the public 8s budget' using errcode='57014';
  end if;
  return answer;
end;
$$;
grant execute on function pg_temp.k3_po_read(),pg_temp.k3_pxk_read() to authenticated;

insert into k2_requests
select 'initial_save',pg_temp.k2_command('RMVP-05.v2','CONFIRMED_NEED_SAVED',b.version,
  jsonb_build_object('confirmed_need_batch_id',b.confirmed_need_batch_id,'lines',(
    select jsonb_agg(jsonb_build_object(
      'confirmed_need_line_id',l.confirmed_need_line_id,
      'expected_current_revision_id',r.confirmed_need_line_revision_id,
      'expected_current_decision_id',l.current_confirmed_need_line_decision_id,
      'proposed_confirmed_quantity',r.confirmed_quantity::text,
      'reason_code','PROPOSAL_ACCEPTED','reason_note',null)
      order by l.confirmed_need_line_id)
    from atlas_planning.confirmed_need_lines l
    join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_id)
    where l.confirmed_need_batch_id=b.confirmed_need_batch_id and r.is_current)))
from atlas_planning.confirmed_need_batches b
where b.confirmed_need_batch_id='b6500000-0000-0000-0000-000000000050';
set local role authenticated;
select set_config('request.jwt.claim.sub','b6000000-0000-0000-0000-000000000101',true);
insert into k2_results select 'initial_save',atlas_api.save_confirmed_needs(request)
from k2_requests where name='initial_save';
reset role;
select is((select response->>'success' from k2_results where name='initial_save'),
  'true','initial authenticated human confirmation succeeds');

insert into k2_requests
select 'initial_prepare',pg_temp.k2_command('PURCHASE-COMMITMENT.v1',
  'PURCHASE_ORDERS_PREPARED',version,jsonb_build_object(
    'confirmed_need_batch_id',confirmed_need_batch_id,'service_date','2026-11-02'))
from atlas_planning.confirmed_need_batches
where confirmed_need_batch_id='b6500000-0000-0000-0000-000000000050';
set local role authenticated;
insert into k2_results select 'initial_prepare',
  atlas_api.prepare_school_catering_purchase_orders(request)
from k2_requests where name='initial_prepare';
reset role;
select is((select response->>'success' from k2_results where name='initial_prepare'),
  'true','initial Preparation preserves ordinary release and real Handoff');
set local role authenticated;
insert into k2_results values('ordinary_released_read',pg_temp.k3_allocation_read('2026-11-02'));
reset role;
select is((select jsonb_array_length(response->'rows') from k2_results where name='ordinary_released_read'),
  2,'ordinary released read includes both families');
select ok((select bool_and(row#>>'{family,source_kind}'='PURCHASE_HANDOFF'
    and row->>'state'='BALANCED' and row#>>'{family,source_confirmed_need_batch_id}'=
      'b6500000-0000-0000-0000-000000000050')
  from k2_results cross join lateral jsonb_array_elements(response->'rows') row
  where name='ordinary_released_read'),
  'ordinary released Handoff keeps the existing Confirmed Need lineage contract');

insert into k2_requests
select 'po001',pg_temp.k2_command('SCHOOL-CATERING-PROCUREMENT.v1',
  'SCHOOL_CATERING_PO_RELEASED',po.version,jsonb_build_object(
    'purchase_order_id',po.purchase_order_id,
    'expected_purchase_order_revision_id',r.purchase_order_revision_id))
from atlas_procurement.purchase_orders po
join atlas_procurement.purchase_order_revisions r using(purchase_order_id)
where po.school_catering_service_date='2026-11-02' and r.is_current;
set local role authenticated;
insert into k2_results select 'po001',atlas_api.release_school_catering_purchase_order(request)
from k2_requests where name='po001';
reset role;
select is((select response->>'success' from k2_results where name='po001'),
  'true','PO-001 is issued through the authenticated public release command');

create function pg_temp.k2_issued_snapshot(po_id uuid)
returns jsonb language sql stable set search_path='' as $$
  select jsonb_build_object('document_number',po.document_number,'supplier_id',po.supplier_id,
    'service_date',po.school_catering_service_date,'replaces_purchase_order_id',po.replaces_purchase_order_id,
    'revisions',(select jsonb_agg(to_jsonb(r) order by r.revision_number)
      from atlas_procurement.purchase_order_revisions r where r.purchase_order_id=po_id),
    'lines',(select jsonb_agg(to_jsonb(l) order by l.purchase_order_line_revision_id)
      from atlas_procurement.purchase_order_line_revisions l
      join atlas_procurement.purchase_order_revisions r using(purchase_order_revision_id)
      where r.purchase_order_id=po_id))
  from atlas_procurement.purchase_orders po where po.purchase_order_id=po_id;
$$;
create temporary table k2_issued_history as select 'po001' name,
  (response->>'purchase_order_id')::uuid po_id,
  pg_temp.k2_issued_snapshot((response->>'purchase_order_id')::uuid) facts
from k2_results where name='po001';

create function pg_temp.k2_replacement_request()
returns jsonb language sql volatile set search_path='' as $$
  select pg_temp.k2_command('SCHOOL-CATERING-PROCUREMENT.v1',
    'SCHOOL_CATERING_PO_REPLACEMENT_CREATED',po.version,jsonb_build_object(
      'replaced_purchase_order_id',po.purchase_order_id,
      'expected_purchase_order_revision_id',r.purchase_order_revision_id))
  from atlas_procurement.purchase_orders po
  join atlas_procurement.purchase_order_revisions r using(purchase_order_id)
  where po.school_catering_service_date='2026-11-02' and r.is_current
    and po.purchase_order_status='RELEASED_TO_SUPPLIER';
$$;
create function pg_temp.k2_release_request()
returns jsonb language sql volatile set search_path='' as $$
  select pg_temp.k2_command('SCHOOL-CATERING-PROCUREMENT.v1',
    'SCHOOL_CATERING_PO_RELEASED',po.version,jsonb_build_object(
      'purchase_order_id',po.purchase_order_id,
      'expected_purchase_order_revision_id',r.purchase_order_revision_id))
  from atlas_procurement.purchase_orders po
  join atlas_procurement.purchase_order_revisions r using(purchase_order_id)
  where po.school_catering_service_date='2026-11-02' and r.is_current
    and po.purchase_order_status='DRAFT';
$$;

create temporary table k2_original_source as
select b.confirmed_need_batch_id,b.current_confirmed_need_release_id,
  h.purchase_handoff_batch_id,h.version handoff_version,r.purchase_handoff_revision_id
from atlas_planning.confirmed_need_batches b
join atlas_planning.purchase_handoff_batches h using(confirmed_need_batch_id)
join atlas_planning.purchase_handoff_revisions r using(purchase_handoff_batch_id)
where b.confirmed_need_batch_id='b6500000-0000-0000-0000-000000000050' and r.is_current;

-- A valid receipt lifecycle supplies no missing business lineage or decision.
grant atlas_procurement_command_runtime to postgres with set true;
set local role atlas_procurement_command_runtime;
insert into atlas_core.command_receipts(command_name,scope_key,idempotency_key,
  command_id,correlation_id,actor_id,expected_version,request_hash,outcome)
values('prepare_corrected_need_transfer','unsupported:k2','unsupported:k2',
  'b6900000-0000-0000-0000-000000000021',gen_random_uuid(),
  'b6000000-0000-0000-0000-000000000001',1,repeat('f',64),'IN_PROGRESS');
select atlas_core.pa_05b_finish_command(command_receipt_id,
  '{"success":true,"corrected_source_eligible":true}'::jsonb,true)
from atlas_core.command_receipts where command_id='b6900000-0000-0000-0000-000000000021';
reset role;
grant atlas_procurement_command_runtime to postgres with set false;
insert into k2_requests select 'forged_receipt_draft',pg_temp.k2_replacement_request();
set local role authenticated;
insert into k2_results select 'forged_receipt_draft',
  atlas_api.create_school_catering_purchase_order_replacement(request)
from k2_requests where name='forged_receipt_draft';
reset role;
select is((select response->>'success' from k2_results where name='forged_receipt_draft'),
  'false','a manufactured completed transfer receipt alone cannot enable a replacement Draft');
select is((select count(*) from atlas_procurement.purchase_orders
  where purchase_order_kind='SCHOOL_CATERING'),1::bigint,
  'manufactured receipt creates no PO root or supplier commitment');

insert into k2_requests
select 'correction110',pg_temp.k2_command('RMVP-05.v3','CONFIRMED_NEED_SAVED',b.version,
  jsonb_build_object('confirmed_need_batch_id',b.confirmed_need_batch_id,
    'correction',jsonb_build_object(
      'expected_confirmed_need_release_id',o.current_confirmed_need_release_id,
      'expected_purchase_handoff_batch_id',o.purchase_handoff_batch_id,
      'expected_purchase_handoff_revision_id',o.purchase_handoff_revision_id,
      'expected_purchase_handoff_version',o.handoff_version,
      'expected_source_fingerprint',encode(sha256(convert_to(
        atlas_core.rmvp_07_validated_facts_projection(b.confirmed_need_batch_id)::text,'UTF8')),'hex')),
    'lines',jsonb_build_array(jsonb_build_object(
      'confirmed_need_line_id',l.confirmed_need_line_id,
      'expected_current_revision_id',r.confirmed_need_line_revision_id,
      'expected_current_decision_id',l.current_confirmed_need_line_decision_id,
      'proposed_confirmed_quantity','110.000000',
      'reason_code','OPERATIONAL_QUANTITY_ADJUSTMENT',
      'reason_note','Correct actual Need after supplier release'))))
from atlas_planning.confirmed_need_batches b cross join k2_original_source o
join atlas_planning.confirmed_need_lines l on l.confirmed_need_batch_id=o.confirmed_need_batch_id
join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_id)
where b.confirmed_need_batch_id=o.confirmed_need_batch_id and r.is_current
  and l.ingredient_id='b6500000-0000-0000-0000-000000000006';
set local role authenticated;
insert into k2_results select 'correction110',atlas_api.save_confirmed_needs(request)
from k2_requests where name='correction110';
reset role;
select is((select response->>'success' from k2_results where name='correction110'),
  'true','authentic K1 correction from 100 to 110 succeeds');

insert into k2_requests
select 'allocation110',pg_temp.k2_command('CONFIRMED-SUPPLIER-ALLOCATION.v1',
  'CONFIRMED_SUPPLIER_ALLOCATION_SAVED',f.version,jsonb_build_object(
    'family',jsonb_build_object('service_date',p->'service_date',
      'delivery_location_id',p->'delivery_location_id','ingredient_id',p->'ingredient_id',
      'unit_id',p->'unit_id','expected_source_fingerprint',p->'source_fingerprint',
      'expected_source_batch_id',p->'source_confirmed_need_batch_id',
      'expected_source_batch_version',p->'source_confirmed_need_batch_version'),
    'splits',jsonb_build_array(jsonb_build_object('supplier_id',s.supplier_id,
      'allocated_quantity','110.000000','supplier_note','Accepted corrected quantity'))))
from atlas_core.purchase_review_confirmed_sources('2026-11-02','2026-11-02') p
join atlas_procurement.school_catering_allocation_families f
  on f.ingredient_id=(p->>'ingredient_id')::uuid
  and f.delivery_location_id=(p->>'delivery_location_id')::uuid
  and f.service_date=(p->>'service_date')::date and f.unit_id=(p->>'unit_id')::uuid
join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
join atlas_procurement.school_catering_allocation_supplier_splits s using(family_revision_id)
where r.is_current and f.ingredient_id='b6500000-0000-0000-0000-000000000006';
set local role authenticated;
insert into k2_results select 'allocation110',atlas_api.save_confirmed_supplier_allocation(request)
from k2_requests where name='allocation110';
reset role;
select is((select response->>'success' from k2_results where name='allocation110'),
  'true','affected 110 Supplier Allocation is explicitly accepted');

-- Owner #400 / 6279713889: reproduce the connected mixed-source read path.
-- Roll back its explicit acceptance/Preparation so the original K2 journey and
-- its immutable-history assertions below still exercise the same fixtures.
savepoint k3_read_parity;
set local role authenticated;
insert into k2_results values('allocation_read110',
  atlas_api.get_confirmed_supplier_allocation_workbench(jsonb_build_object(
    'contract_version','CONFIRMED-SUPPLIER-ALLOCATION.v1',
    'correlation_id',gen_random_uuid(),
    'requested_by_auth_subject','b6000000-0000-0000-0000-000000000101',
    'payload',jsonb_build_object('date_start','2026-11-02','date_end','2026-11-02',
      'school_ids','[]'::jsonb,'states','[]'::jsonb,'search',null))));
reset role;

-- Recreate the obsolete read's accepted CN binding for the untouched family.
-- The existing writer remains unchanged; the amended read must now expose its
-- stale authority and must never claim Preparation is ready from raw CN totals.
savepoint k3_wrong_cn;
insert into k2_requests
select 'wrong_cn3',pg_temp.k2_command('CONFIRMED-SUPPLIER-ALLOCATION.v1',
  'CONFIRMED_SUPPLIER_ALLOCATION_SAVED',f.version,jsonb_build_object(
    'family',jsonb_build_object('service_date',p->'service_date',
      'delivery_location_id',p->'delivery_location_id','ingredient_id',p->'ingredient_id',
      'unit_id',p->'unit_id','expected_source_fingerprint',p->'source_fingerprint',
      'expected_source_batch_id',p->'source_confirmed_need_batch_id',
      'expected_source_batch_version',p->'source_confirmed_need_batch_version'),
    'splits',jsonb_build_array(jsonb_build_object('supplier_id',s.supplier_id,
      'allocated_quantity','3.000000','supplier_note',null))))
from atlas_core.purchase_review_confirmed_sources('2026-11-02','2026-11-02') p
join atlas_procurement.school_catering_allocation_families f
  on f.ingredient_id=(p->>'ingredient_id')::uuid and f.service_date='2026-11-02'
join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
join atlas_procurement.school_catering_allocation_supplier_splits s using(family_revision_id)
where r.is_current and f.ingredient_id='b6500000-0000-0000-0000-000000000007';
set local role authenticated;
insert into k2_results select 'wrong_cn3',atlas_api.save_confirmed_supplier_allocation(request)
from k2_requests where name='wrong_cn3';
insert into k2_results values('wrong_cn_read',pg_temp.k3_allocation_read('2026-11-02'));
reset role;
insert into k2_requests
select 'wrong_cn_prepare',pg_temp.k2_command('PURCHASE-COMMITMENT.v1','PURCHASE_ORDERS_PREPARED',
  (response#>>'{preparation,expected_version}')::bigint,
  jsonb_build_object('service_date',response#>'{preparation,service_date}',
    'confirmed_need_batch_id',response#>'{preparation,confirmed_need_batch_id}'))
from k2_results where name='wrong_cn_read';
set local role authenticated;
insert into k2_results select 'wrong_cn_prepare',atlas_api.prepare_school_catering_purchase_orders(request)
from k2_requests where name='wrong_cn_prepare';
reset role;
select jsonb_object_agg(name,response)::text evidence from k2_results
where name in ('wrong_cn3','wrong_cn_read','wrong_cn_prepare')
\gset k3_wrong_
rollback to savepoint k3_wrong_cn;
insert into k2_results select key,value from jsonb_each(:'k3_wrong_evidence'::jsonb);

-- Reproduce the actual UI's dispatch using only the authenticated read's source
-- kind, fingerprint and version; no test-side replacement of source authority.
insert into k2_requests
select 'read_accept3',pg_temp.k2_command(
  case when row#>>'{family,source_kind}'='CONFIRMED_NEED'
    then 'CONFIRMED-SUPPLIER-ALLOCATION.v1' else 'SCHOOL-CATERING-PROCUREMENT.v1' end,
  case when row#>>'{family,source_kind}'='CONFIRMED_NEED'
    then 'CONFIRMED_SUPPLIER_ALLOCATION_SAVED' else 'SCHOOL_CATERING_SUPPLIER_ALLOCATION_SAVED' end,
  (row#>>'{family,version}')::bigint,jsonb_build_object('family',
    jsonb_build_object('service_date',row->'service_date','delivery_location_id',row->'delivery_location_id',
      'ingredient_id',row->'ingredient_id','unit_id',row->'unit_id',
      'expected_source_fingerprint',row#>'{family,source_fingerprint}') ||
    case when row#>>'{family,source_kind}'='CONFIRMED_NEED' then jsonb_build_object(
      'expected_source_batch_id',row#>'{family,source_confirmed_need_batch_id}',
      'expected_source_batch_version',row#>'{family,source_confirmed_need_batch_version}') else '{}'::jsonb end,
    'splits',(select jsonb_agg(jsonb_build_object('supplier_id',s->'supplier_id',
      'allocated_quantity',s->'allocated_quantity','supplier_note',s->'supplier_note'))
      from jsonb_array_elements(row->'splits') s)))
from k2_results cross join lateral jsonb_array_elements(response->'rows') row
where name='allocation_read110' and row->>'ingredient_id'='b6500000-0000-0000-0000-000000000007';
set local role authenticated;
insert into k2_results select 'read_accept3',case
  when request->>'contract_version'='CONFIRMED-SUPPLIER-ALLOCATION.v1'
    then atlas_api.save_confirmed_supplier_allocation(request)
  else atlas_api.save_school_catering_supplier_allocation(request) end
from k2_requests where name='read_accept3';
reset role;
insert into k2_requests
select 'read_prepare110',pg_temp.k2_command('PURCHASE-COMMITMENT.v1','PURCHASE_ORDERS_PREPARED',
  (response#>>'{preparation,expected_version}')::bigint,
  jsonb_build_object('service_date',response#>'{preparation,service_date}',
    'confirmed_need_batch_id',response#>'{preparation,confirmed_need_batch_id}'))
from k2_results where name='allocation_read110';
set local role authenticated;
insert into k2_results select 'read_prepare110',atlas_api.prepare_school_catering_purchase_orders(request)
from k2_requests where name='read_prepare110';
reset role;
select jsonb_object_agg(name,response)::text evidence from k2_results
where name in ('allocation_read110','wrong_cn3','wrong_cn_read','wrong_cn_prepare','read_accept3','read_prepare110')
\gset k3_parity_
rollback to savepoint k3_read_parity;
-- Keep observations only, after rollback, so TAP numbering/results survive.
insert into k2_results select key,value from jsonb_each(:'k3_parity_evidence'::jsonb);
select is((select jsonb_array_length(response->'rows') from k2_results where name='allocation_read110'),
  2,'corrected read returns both real families');
select is(row#>>'{family,source_kind}','PURCHASE_HANDOFF',
  'untouched 3 kg read retains original Handoff authority')
from k2_results cross join lateral jsonb_array_elements(response->'rows') row
where name='allocation_read110' and row->>'ingredient_id'='b6500000-0000-0000-0000-000000000007';
select is(row#>>'{family,source_fingerprint}',
  atlas_core.school_catering_family_projection('2026-11-02',
    'b6500000-0000-0000-0000-000000000002','b6500000-0000-0000-0000-000000000007',
    'b6500000-0000-0000-0000-000000000005')->>'source_fingerprint',
  'untouched read fingerprint equals Preparation canonical source')
from k2_results cross join lateral jsonb_array_elements(response->'rows') row
where name='allocation_read110' and row->>'ingredient_id'='b6500000-0000-0000-0000-000000000007';
select is(row->>'state','BALANCED','untouched original Handoff needs no CN reacceptance')
from k2_results cross join lateral jsonb_array_elements(response->'rows') row
where name='allocation_read110' and row->>'ingredient_id'='b6500000-0000-0000-0000-000000000007';
select ok(row#>>'{family,source_confirmed_need_batch_id}' is null
    and row#>>'{family,source_confirmed_need_batch_version}' is null
    and not exists(select 1 from jsonb_array_elements(row->'contributions') c
      where c->>'purchase_handoff_line_revision_id' is null
        or c->>'confirmed_need_line_revision_id' is not null),
  'Handoff row has exact Handoff contributors and no CN command bindings')
from k2_results cross join lateral jsonb_array_elements(response->'rows') row
where name='allocation_read110' and row->>'ingredient_id'='b6500000-0000-0000-0000-000000000007';
select is(row#>>'{family,source_kind}','CONFIRMED_NEED',
  'changed 110 kg family retains authentic corrected CN authority')
from k2_results cross join lateral jsonb_array_elements(response->'rows') row
where name='allocation_read110' and row->>'ingredient_id'='b6500000-0000-0000-0000-000000000006';
select is((select response->>'success' from k2_results where name='wrong_cn3'),
  'true','original obsolete CN acceptance is reproduced without a writer change');
select is(row->>'state','STALE_REBALANCE_AVAILABLE',
  'same 3 kg total with CN contributors cannot masquerade as canonical Handoff BALANCED')
from k2_results cross join lateral jsonb_array_elements(response->'rows') row
where name='wrong_cn_read' and row->>'ingredient_id'='b6500000-0000-0000-0000-000000000007';
select is((select response#>>'{preparation,ready}' from k2_results where name='wrong_cn_read'),
  'false','raw CN readiness cannot override canonical date SOURCE_CHANGED');
select is((select response->>'error_code' from k2_results where name='wrong_cn_prepare'),
  'PREPARATION_BLOCKED','writer still rejects genuine noncanonical accepted source');
select ok((select response#>'{blockers,0,blockers}' @> '[{"reason":"SOURCE_CHANGED"}]'
  from k2_results where name='wrong_cn_prepare'),'SOURCE_CHANGED guard is preserved');
select is((select response->>'success' from k2_results where name='read_accept3'),
  'true','explicit unchanged 3 kg acceptance from exact read bindings succeeds');
select diag(response::text) from k2_results where name='read_prepare110';
select is((select response->>'success' from k2_results where name='read_prepare110'),
  'true','exact authenticated read acceptance can Prepare mixed CN/Handoff without SOURCE_CHANGED');

insert into k2_requests
select 'prepare110',pg_temp.k2_command('PURCHASE-COMMITMENT.v1',
  'PURCHASE_ORDERS_PREPARED',version,jsonb_build_object(
    'confirmed_need_batch_id',confirmed_need_batch_id,'service_date','2026-11-02'))
from atlas_planning.confirmed_need_batches
where confirmed_need_batch_id='b6500000-0000-0000-0000-000000000050';
set local role authenticated;
insert into k2_results select 'prepare110',atlas_api.prepare_school_catering_purchase_orders(request)
from k2_requests where name='prepare110';
reset role;
select is((select response->>'success' from k2_results where name='prepare110'),
  'true','K2 Preparation accepts authentic correction without another Planning release');

insert into k2_requests select 'draft002',pg_temp.k2_replacement_request();
set local role authenticated;
insert into k2_results select 'draft002',atlas_api.create_school_catering_purchase_order_replacement(request)
from k2_requests where name='draft002';
reset role;
select is((select response->>'success' from k2_results where name='draft002'),
  'true','complete replacement Draft for PO-002 is generated through the public command');
select is((select po.purchase_order_status from atlas_procurement.purchase_orders po
  join k2_issued_history history on po.purchase_order_id=history.po_id where history.name='po001'),
  'RELEASED_TO_SUPPLIER','Preparation and replacement Draft leave PO-001 active');

insert into k2_requests select 'po002',pg_temp.k2_release_request();

create temporary table k2_proof_cases(name text,payload jsonb,expected boolean);
insert into k2_proof_cases
select 'valid accepted corrected source',to_jsonb(family)||jsonb_build_object(
  'source_batch_id',revision.source_confirmed_need_batch_id,
  'source_version',revision.source_confirmed_need_batch_version,
  'contributions',(select jsonb_agg(to_jsonb(c))
    from atlas_procurement.school_catering_allocation_family_contributions c
    where c.family_revision_id=revision.family_revision_id)),true
from atlas_procurement.school_catering_allocation_families family
join atlas_procurement.school_catering_allocation_family_revisions revision using(family_id)
where family.service_date='2026-11-02' and family.ingredient_id='b6500000-0000-0000-0000-000000000006'
  and revision.is_current;
insert into k2_proof_cases
select 'unknown appended contribution',jsonb_set(payload,'{contributions}',payload->'contributions'||
  jsonb_build_array(jsonb_build_object('confirmed_need_line_revision_id',gen_random_uuid(),
    'confirmed_need_line_decision_id',gen_random_uuid(),'contribution_quantity','1.000000'))),false
from k2_proof_cases where expected;
insert into k2_proof_cases
select 'mismatched revision and decision',jsonb_set(payload,'{contributions,0,confirmed_need_line_revision_id}',
  to_jsonb('b6560000-0000-0000-0000-000000000011'::text)),false from k2_proof_cases where expected;
insert into k2_proof_cases
select 'wrong contribution quantity',jsonb_set(payload,'{contributions,0,contribution_quantity}',
  to_jsonb('999.000000'::text)),false from k2_proof_cases where expected;
insert into k2_proof_cases
select 'wrong controlled Unit',jsonb_set(payload,'{unit_id}',to_jsonb(gen_random_uuid())),false
from k2_proof_cases where expected;
create temporary table k2_proof_results(name text,result boolean,expected boolean);
grant select on k2_proof_cases to atlas_procurement_command_runtime;
grant insert on k2_proof_results to atlas_procurement_command_runtime;
grant atlas_procurement_command_runtime to postgres with set true;
set local role atlas_procurement_command_runtime;
insert into k2_proof_results select name,
  atlas_core.school_catering_corrected_allocation_ancestry(payload),expected from k2_proof_cases;
reset role;
grant atlas_procurement_command_runtime to postgres with set false;
select is(result,expected,'immutable proof: '||name) from k2_proof_results order by name;

create function pg_temp.k2_unsupported_history_probe()
returns jsonb language plpgsql volatile set search_path='' as $$
declare prior record; member record; revision_id uuid;
begin
  begin
    select r.* into strict prior from atlas_procurement.purchase_order_revisions r
    join atlas_procurement.purchase_orders po using(purchase_order_id)
    where po.purchase_order_status='DRAFT' and po.school_catering_service_date='2026-11-02'
      and r.is_current;
    select split.supplier_split_id,split.allocated_quantity,f.*,line.purchase_order_line_id,
      line.purchase_order_line_revision_id into strict member
    from atlas_procurement.school_catering_allocation_families f
    join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
    join atlas_procurement.school_catering_allocation_supplier_splits split using(family_revision_id)
    join atlas_procurement.purchase_order_line_revisions line
      on line.purchase_order_revision_id=prior.purchase_order_revision_id and line.ingredient_id=f.ingredient_id
    where f.ingredient_id='b6500000-0000-0000-0000-000000000006'
      and r.source_kind='CONFIRMED_NEED' and not r.is_current;
    insert into atlas_procurement.purchase_order_revisions(purchase_order_id,revision_number,revision_kind,
      revision_status,is_current,predecessor_revision_id,service_date,delivery_location_id,
      supplier_name_snapshot,delivery_location_snapshot,command_id)
    values(prior.purchase_order_id,prior.revision_number+1,'SUPERSEDING','DRAFT',false,
      prior.purchase_order_revision_id,prior.service_date,null,prior.supplier_name_snapshot,
      prior.delivery_location_snapshot,prior.command_id)
    returning purchase_order_revision_id into revision_id;
    insert into atlas_procurement.purchase_order_line_revisions(purchase_order_revision_id,purchase_order_line_id,
      school_catering_allocation_supplier_split_id,ingredient_id,ordered_quantity,unit_id,
      delivery_location_id,service_date,predecessor_revision_id)
    values(revision_id,member.purchase_order_line_id,member.supplier_split_id,member.ingredient_id,
      member.allocated_quantity,member.unit_id,member.delivery_location_id,member.service_date,
      member.purchase_order_line_revision_id);
    set constraints all immediate;
    raise exception using errcode='K2H01',message='Unsupported history was accepted';
  exception when others then return jsonb_build_object('sqlstate',sqlstate,'message',sqlerrm); end;
end;
$$;
create temporary table k2_history_probe as select pg_temp.k2_unsupported_history_probe() result;
select is(result->>'sqlstate','23514','noncurrent Draft history cannot launder an initial pre-issuance CN allocation')
from k2_history_probe;
select is(result->>'message','Official PO requires Purchase Handoff allocation authority.',
  'historical rejection comes from the official source guard') from k2_history_probe;

create function pg_temp.k2_commitment_state()
returns jsonb language sql stable set search_path='' as $$
  select jsonb_build_object(
    'roots',(select jsonb_agg(to_jsonb(po) order by purchase_order_id)
      from atlas_procurement.purchase_orders po),
    'revisions',(select jsonb_agg(to_jsonb(r) order by purchase_order_revision_id)
      from atlas_procurement.purchase_order_revisions r),
    'lines',(select jsonb_agg(to_jsonb(l) order by purchase_order_line_revision_id)
      from atlas_procurement.purchase_order_line_revisions l));
$$;
create function pg_temp.k2_forced_failure() returns trigger
language plpgsql set search_path='' as $$
begin raise exception using errcode='23514',message='K2 deliberate release rollback'; end $$;
create function pg_temp.k2_release_probe(fault text)
returns jsonb language plpgsql volatile set search_path='' as $$
declare response jsonb; source_response jsonb; allocation_read jsonb; command jsonb; before_state jsonb; answer jsonb;
begin
  begin
    if fault='no_planning_roles' then
      delete from atlas_core.role_capabilities binding using atlas_core.capabilities capability
      where binding.capability_id=capability.capability_id
        and binding.role_id='b6000000-0000-0000-0000-000000000003'
        and capability.capability_code in('planning.need_generation.write',
          'confirmed_need_release.release','confirmed_need_quantities.confirm');
    elsif fault='no_procurement_write' then
      delete from atlas_core.role_capabilities binding using atlas_core.capabilities capability
      where binding.capability_id=capability.capability_id
        and binding.role_id='b6000000-0000-0000-0000-000000000003'
        and capability.capability_code='procurement.school_catering.write';
    elsif fault='inactive_actor' then
      update atlas_core.actors set actor_status='INACTIVE',deactivated_at=transaction_timestamp()
      where actor_id='b6000000-0000-0000-0000-000000000001';
    elsif fault='wrong_scope' then
      delete from atlas_core.actor_scopes
      where actor_id='b6000000-0000-0000-0000-000000000001';
    elsif fault='inactive_supplier' then
      update atlas_admin.suppliers set supplier_status='INACTIVE'
      where supplier_id=(select supplier_id from atlas_procurement.purchase_orders
        where purchase_order_id=(select (request#>>'{payload,purchase_order_id}')::uuid
          from k2_requests where name='po002'));
    elsif fault='upstream_reopened' then
      select pg_temp.k2_command('RMVP-03A.v1','WEEKLY_MENU_REOPENED',version,
        jsonb_build_object('week_start','2026-11-02'))||jsonb_build_object(
          'reason_note','Disposable upstream correction') into command
      from atlas_planning.weekly_menus where week_start='2026-11-02';
      set local role authenticated;
      source_response:=atlas_api.reopen_weekly_menu(command);
      reset role;
    elsif fault='new_need_decision' then
      select pg_temp.k2_command('RMVP-05.v3','CONFIRMED_NEED_SAVED',b.version,
        jsonb_build_object('confirmed_need_batch_id',b.confirmed_need_batch_id,
          'correction',(request#>'{payload,correction}')||jsonb_build_object(
            'expected_source_fingerprint',encode(sha256(convert_to(
              atlas_core.rmvp_07_validated_facts_projection(b.confirmed_need_batch_id)::text,'UTF8')),'hex')),
          'lines',jsonb_build_array((request#>'{payload,lines,0}')||jsonb_build_object(
            'expected_current_revision_id',r.confirmed_need_line_revision_id,
            'expected_current_decision_id',l.current_confirmed_need_line_decision_id,
            'proposed_confirmed_quantity','111.000000')))) into command
      from k2_requests cross join atlas_planning.confirmed_need_batches b
      join atlas_planning.confirmed_need_lines l using(confirmed_need_batch_id)
      join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_id)
      where name='correction110' and b.confirmed_need_batch_id='b6500000-0000-0000-0000-000000000050'
        and l.ingredient_id='b6500000-0000-0000-0000-000000000006' and r.is_current;
      set local role authenticated;
      source_response:=atlas_api.save_confirmed_needs(command);
      reset role;
    elsif fault='rollback' then
      create trigger k2_deliberate_failure
      after insert on atlas_procurement.purchase_order_line_revisions
      for each row execute function pg_temp.k2_forced_failure();
    end if;
    before_state:=pg_temp.k2_commitment_state();
    select request into command from k2_requests where name='po002';
    command:=command||jsonb_build_object('command_id',gen_random_uuid(),
      'idempotency_key','k2-probe:'||gen_random_uuid());
    set local role authenticated;
    allocation_read:=pg_temp.k3_allocation_read('2026-11-02');
    response:=atlas_api.release_school_catering_purchase_order(command);
    reset role;
    answer:=jsonb_build_object('response',response,'source_response',source_response,'allocation_read',allocation_read,
      'commitment_unchanged',pg_temp.k2_commitment_state()=before_state);
    raise exception using errcode='K2T01';
  exception when sqlstate 'K2T01' then return answer; end;
end;
$$;
create temporary table k2_release_probes(fault text,result jsonb);
-- Each independent fault retains the existing 8s budget, rather than sharing
-- one statement budget across eight complete release transactions.
select format('insert into k2_release_probes select %L,pg_temp.k2_release_probe(%L);',fault,fault)
from (values
  ('no_planning_roles'),('no_procurement_write'),('inactive_actor'),('wrong_scope'),
  ('inactive_supplier'),('upstream_reopened'),('new_need_decision'),('rollback')) cases(fault)
\gexec
select is(result#>>'{response,success}','true',
  'Procurement releaser needs no current Planning capabilities after authentic K1 Save')
from k2_release_probes where fault='no_planning_roles';
select is(result#>>'{response,success}','false','release rejects '||fault)
from k2_release_probes where fault<>'no_planning_roles' order by fault;
select is(result->>'commitment_unchanged','true','rejected '||fault||' leaves every PO fact unchanged')
from k2_release_probes where fault<>'no_planning_roles' order by fault;
select is(result#>>'{source_response,success}','true',fault||' is performed by its real public command')
from k2_release_probes where fault in('upstream_reopened','new_need_decision') order by fault;
select is(result#>>'{allocation_read,preparation,ready}','false',
  'amended Procurement read blocks Preparation after '||fault)
from k2_release_probes where fault in('inactive_supplier','upstream_reopened','new_need_decision');
select is(result#>>'{allocation_read,preparation,allowed}','false',
  'Procurement read denies Preparation without write capability')
from k2_release_probes where fault='no_procurement_write';
select ok(not exists(select 1 from jsonb_array_elements(result#>'{allocation_read,rows}') row
    where row#>>'{allowed_actions,save_allocation}'='true'),
  'read-only Procurement Actor cannot Save any allocation')
from k2_release_probes where fault='no_procurement_write';
select is(result#>>'{allocation_read,success}','false','inactive Actor cannot read Procurement')
from k2_release_probes where fault='inactive_actor';
select ok(result#>'{allocation_read,rows}'='[]'::jsonb
    and result#>>'{allocation_read,preparation,allowed}'='false',
  'out-of-scope Actor cannot see rows or Prepare')
from k2_release_probes where fault='wrong_scope';

savepoint k3_missing_read_capability;
delete from atlas_core.role_capabilities binding using atlas_core.capabilities capability
where binding.capability_id=capability.capability_id
  and binding.role_id='b6000000-0000-0000-0000-000000000003'
  and capability.capability_code='procurement.school_catering.read';
set local role authenticated;
select pg_temp.k3_allocation_read('2026-11-02')::text response
\gset k3_missing_read_
reset role;
rollback to savepoint k3_missing_read_capability;
select is(:'k3_missing_read_response'::jsonb->>'error_code','CAPABILITY_DENIED',
  'missing Procurement read capability rejects the authenticated read');

set local role authenticated;
insert into k2_results select 'po002',atlas_api.release_school_catering_purchase_order(request)
from k2_requests where name='po002';
reset role;
select is((select response->>'success' from k2_results where name='po002'),
  'true','explicit authenticated Release issues PO-002');
select is((select line.ordered_quantity::text from atlas_procurement.purchase_order_line_revisions line
  join atlas_procurement.purchase_order_revisions revision using(purchase_order_revision_id)
  join k2_results result on revision.purchase_order_id=(result.response->>'purchase_order_id')::uuid
  where result.name='po002' and revision.is_current
    and line.ingredient_id='b6500000-0000-0000-0000-000000000006'),
  '110.000000','PO-002 contains the complete 110, not a difference-only 10');
select is((select po.purchase_order_status from atlas_procurement.purchase_orders po
  join k2_issued_history history on po.purchase_order_id=history.po_id where history.name='po001'),
  'SUPERSEDED','PO-002 release supersedes PO-001 atomically');
select is(pg_temp.k2_issued_snapshot(po_id),facts,
  'PO-001 number, original 100, revisions, School snapshots and export facts stay identical')
from k2_issued_history where name='po001';
insert into k2_issued_history select 'po002',(response->>'purchase_order_id')::uuid,
  pg_temp.k2_issued_snapshot((response->>'purchase_order_id')::uuid)
from k2_results where name='po002';

insert into k2_requests
select 'correction90',pg_temp.k2_command('RMVP-05.v3','CONFIRMED_NEED_SAVED',b.version,
  jsonb_build_object('confirmed_need_batch_id',b.confirmed_need_batch_id,
    'correction',jsonb_build_object(
      'expected_confirmed_need_release_id',o.current_confirmed_need_release_id,
      'expected_purchase_handoff_batch_id',o.purchase_handoff_batch_id,
      'expected_purchase_handoff_revision_id',o.purchase_handoff_revision_id,
      'expected_purchase_handoff_version',o.handoff_version,
      'expected_source_fingerprint',encode(sha256(convert_to(
        atlas_core.rmvp_07_validated_facts_projection(b.confirmed_need_batch_id)::text,'UTF8')),'hex')),
    'lines',jsonb_build_array(jsonb_build_object(
      'confirmed_need_line_id',l.confirmed_need_line_id,
      'expected_current_revision_id',r.confirmed_need_line_revision_id,
      'expected_current_decision_id',l.current_confirmed_need_line_decision_id,
      'proposed_confirmed_quantity','90.000000',
      'reason_code','OPERATIONAL_QUANTITY_ADJUSTMENT','reason_note','Second actual Need correction'))))
from atlas_planning.confirmed_need_batches b cross join k2_original_source o
join atlas_planning.confirmed_need_lines l on l.confirmed_need_batch_id=o.confirmed_need_batch_id
join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_id)
where b.confirmed_need_batch_id=o.confirmed_need_batch_id and r.is_current
  and l.ingredient_id='b6500000-0000-0000-0000-000000000006';
set local role authenticated;
insert into k2_results select 'correction90',atlas_api.save_confirmed_needs(request)
from k2_requests where name='correction90';
reset role;
select is((select response->>'success' from k2_results where name='correction90'),
  'true','second authentic K1 correction from 110 to 90 succeeds after PO-002');

set local role authenticated;
insert into k2_results values('allocation_read90',pg_temp.k3_allocation_read('2026-11-02'));
reset role;
select is((select jsonb_array_length(response->'rows') from k2_results where name='allocation_read90'),
  2,'repeated-correction read still includes both real families');
select ok(row#>>'{family,source_kind}'='CONFIRMED_NEED'
    and row->>'family_quantity'='90.000000'
    and row#>>'{family,source_fingerprint}' is not null
    and row#>>'{allowed_actions,save_allocation}'='true'
    and row->>'state'='STALE_REBALANCE_AVAILABLE',
  'later 90 kg correction exposes authentic editable CN proposal while old accepted 110 is stale')
from k2_results cross join lateral jsonb_array_elements(response->'rows') row
where name='allocation_read90' and row->>'ingredient_id'='b6500000-0000-0000-0000-000000000006';
select is((select response#>>'{preparation,ready}' from k2_results where name='allocation_read90'),
  'false','90 kg correction requires explicit acceptance before Preparation');
select ok(row#>>'{family,source_kind}'='PURCHASE_HANDOFF' and row->>'state'='BALANCED',
  'second correction still preserves untouched 3 kg Handoff authority')
from k2_results cross join lateral jsonb_array_elements(response->'rows') row
where name='allocation_read90' and row->>'ingredient_id'='b6500000-0000-0000-0000-000000000007';

insert into k2_requests
select 'allocation90',pg_temp.k2_command('CONFIRMED-SUPPLIER-ALLOCATION.v1',
  'CONFIRMED_SUPPLIER_ALLOCATION_SAVED',f.version,jsonb_build_object(
    'family',jsonb_build_object('service_date',p->'service_date',
      'delivery_location_id',p->'delivery_location_id','ingredient_id',p->'ingredient_id',
      'unit_id',p->'unit_id','expected_source_fingerprint',p->'source_fingerprint',
      'expected_source_batch_id',p->'source_confirmed_need_batch_id',
      'expected_source_batch_version',p->'source_confirmed_need_batch_version'),
    'splits',jsonb_build_array(jsonb_build_object('supplier_id',s.supplier_id,
      'allocated_quantity','90.000000','supplier_note','Accepted second corrected quantity'))))
from atlas_core.purchase_review_confirmed_sources('2026-11-02','2026-11-02') p
join atlas_procurement.school_catering_allocation_families f
  on f.ingredient_id=(p->>'ingredient_id')::uuid
  and f.delivery_location_id=(p->>'delivery_location_id')::uuid
  and f.service_date=(p->>'service_date')::date and f.unit_id=(p->>'unit_id')::uuid
join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
join atlas_procurement.school_catering_allocation_supplier_splits s using(family_revision_id)
where r.is_current and f.ingredient_id='b6500000-0000-0000-0000-000000000006';
set local role authenticated;
insert into k2_results select 'allocation90',atlas_api.save_confirmed_supplier_allocation(request)
from k2_requests where name='allocation90';
reset role;
select is((select response->>'success' from k2_results where name='allocation90'),
  'true','affected 90 Supplier Allocation is explicitly reaccepted');
insert into k2_requests
select 'prepare90',pg_temp.k2_command('PURCHASE-COMMITMENT.v1',
  'PURCHASE_ORDERS_PREPARED',version,jsonb_build_object(
    'confirmed_need_batch_id',confirmed_need_batch_id,'service_date','2026-11-02'))
from atlas_planning.confirmed_need_batches
where confirmed_need_batch_id='b6500000-0000-0000-0000-000000000050';
set local role authenticated;
insert into k2_results select 'prepare90',atlas_api.prepare_school_catering_purchase_orders(request)
from k2_requests where name='prepare90';
reset role;
select is((select response->>'success' from k2_results where name='prepare90'),
  'true','second Preparation preserves the original release and Handoff');
insert into k2_requests select 'draft003',pg_temp.k2_replacement_request();
set local role authenticated;
insert into k2_results select 'draft003',atlas_api.create_school_catering_purchase_order_replacement(request)
from k2_requests where name='draft003';
reset role;
select is((select response->>'success' from k2_results where name='draft003'),
  'true','second complete replacement Draft succeeds');
insert into k2_requests select 'po003',pg_temp.k2_release_request();
set local role authenticated;
insert into k2_results select 'po003',atlas_api.release_school_catering_purchase_order(request)
from k2_requests where name='po003';
insert into k2_results select 'replay003',atlas_api.release_school_catering_purchase_order(request)
from k2_requests where name='po003';
reset role;
select is((select response->>'success' from k2_results where name='po003'),
  'true','explicit authenticated Release issues PO-003');
select is((select line.ordered_quantity::text from atlas_procurement.purchase_order_line_revisions line
  join atlas_procurement.purchase_order_revisions revision using(purchase_order_revision_id)
  join k2_results result on revision.purchase_order_id=(result.response->>'purchase_order_id')::uuid
  where result.name='po003' and revision.is_current
    and line.ingredient_id='b6500000-0000-0000-0000-000000000006'),
  '90.000000','PO-003 contains complete 90');
select is((select count(distinct response->>'document_number') from k2_results
  where name in ('po001','po002','po003')),3::bigint,'three releases have three independent official numbers');
select is((select response from k2_results where name='replay003'),
  (select response from k2_results where name='po003'),'duplicate Release returns exactly the original PO-003 response');
select is(pg_temp.k2_issued_snapshot(po_id),facts,
  name||' immutable history remains identical after PO-003') from k2_issued_history order by name;

-- Real R20/B5/H3 generation, two Schools sharing one location, two Suppliers.
-- A first PXK must remain discoverable when every family is corrected CN.
savepoint k3_cn_only_scope;
insert into atlas_core.role_capabilities(role_id,capability_id)
select 'b6000000-0000-0000-0000-000000000003',capability_id
from atlas_core.capabilities where capability_code='dispatch.school_release.read' on conflict do nothing;
insert into k2_requests
select 'cn_only_save',pg_temp.k2_command('RMVP-05.v3','CONFIRMED_NEED_SAVED',b.version,
  jsonb_build_object('confirmed_need_batch_id',b.confirmed_need_batch_id,
    'correction',jsonb_build_object('expected_confirmed_need_release_id',o.current_confirmed_need_release_id,
      'expected_purchase_handoff_batch_id',o.purchase_handoff_batch_id,
      'expected_purchase_handoff_revision_id',o.purchase_handoff_revision_id,
      'expected_purchase_handoff_version',o.handoff_version,
      'expected_source_fingerprint',encode(sha256(convert_to(
        atlas_core.rmvp_07_validated_facts_projection(b.confirmed_need_batch_id)::text,'UTF8')),'hex')),
    'lines',(select jsonb_agg(jsonb_build_object('confirmed_need_line_id',l.confirmed_need_line_id,
      'expected_current_revision_id',r.confirmed_need_line_revision_id,
      'expected_current_decision_id',l.current_confirmed_need_line_decision_id,
      'proposed_confirmed_quantity',(r.confirmed_quantity+1)::text,
      'reason_code','OPERATIONAL_QUANTITY_ADJUSTMENT','reason_note','K3 first all-CN PXK scope')
      order by l.confirmed_need_line_id)
      from atlas_planning.confirmed_need_lines l join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_id)
      where l.confirmed_need_batch_id=b.confirmed_need_batch_id and r.is_current)))
from atlas_planning.confirmed_need_batches b join k2_original_source o using(confirmed_need_batch_id);
set local role authenticated;
insert into k2_results select name,atlas_api.save_confirmed_needs(request)
from k2_requests where name='cn_only_save';
reset role;
insert into k2_requests
select 'cn_only_allocation:'||f.family_id,pg_temp.k2_command('CONFIRMED-SUPPLIER-ALLOCATION.v1',
  'CONFIRMED_SUPPLIER_ALLOCATION_SAVED',f.version,jsonb_build_object(
    'family',jsonb_build_object('service_date',f.service_date,'delivery_location_id',f.delivery_location_id,
      'ingredient_id',f.ingredient_id,'unit_id',f.unit_id,
      'expected_source_fingerprint',p->'source_fingerprint',
      'expected_source_batch_id',p->'source_confirmed_need_batch_id',
      'expected_source_batch_version',p->'source_confirmed_need_batch_version'),
    'splits',jsonb_build_array(jsonb_build_object('supplier_id','c7100000-0000-4000-8000-000000000001',
      'allocated_quantity',p->>'family_quantity','supplier_note',null))))
from atlas_procurement.school_catering_allocation_families f
cross join lateral(select atlas_core.purchase_review_confirmed_projection(
  f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id) p) projection
where f.service_date='2026-11-02';
set local role authenticated;
insert into k2_results select name,atlas_api.save_confirmed_supplier_allocation(request)
from k2_requests where name like 'cn_only_allocation:%';
reset role;
insert into k2_requests select 'cn_only_prepare',pg_temp.k2_command('PURCHASE-COMMITMENT.v1',
  'PURCHASE_ORDERS_PREPARED',version,jsonb_build_object('confirmed_need_batch_id',confirmed_need_batch_id,
    'service_date','2026-11-02')) from atlas_planning.confirmed_need_batches
where confirmed_need_batch_id='b6500000-0000-0000-0000-000000000050';
set local role authenticated;
insert into k2_results select name,atlas_api.prepare_school_catering_purchase_orders(request)
from k2_requests where name='cn_only_prepare';
reset role;
insert into k2_requests select 'cn_only_draft',pg_temp.k2_replacement_request();
set local role authenticated;
insert into k2_results select name,atlas_api.create_school_catering_purchase_order_replacement(request)
from k2_requests where name='cn_only_draft';
reset role;
insert into k2_requests select 'cn_only_release',pg_temp.k2_release_request();
set local role authenticated;
insert into k2_results select name,atlas_api.release_school_catering_purchase_order(request)
from k2_requests where name='cn_only_release';
set local statement_timeout='8s';
insert into k2_results select 'cn_only_pxk',atlas_api.get_school_dispatch_release_workbench(jsonb_build_object(
  'contract_version','SCHOOL-DISPATCH-RELEASE.v1','correlation_id',gen_random_uuid(),
  'requested_by_auth_subject',current_setting('request.jwt.claim.sub',true),
  'payload',jsonb_build_object('date_start','2026-11-02','date_end','2026-11-02',
    'school_ids','[]'::jsonb,'search',null)));
reset role;
select (select bool_and(response->>'success'='true') from k2_results where name like 'cn_only_%') commands_ok,
  (select count(*)>0 and bool_and(r.source_kind='CONFIRMED_NEED')
    from atlas_procurement.school_catering_allocation_families f
    join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
    where f.service_date='2026-11-02' and r.is_current) all_cn,
  (select count(*)=0 from atlas_dispatch.school_dispatch_releases where service_date='2026-11-02') no_history,
  (select jsonb_array_length(response->'rows')=1 and response#>>'{rows,0,state}'='READY'
    from k2_results where name='cn_only_pxk') visible_ready,
  (select bool_and((line->>'quantity')::numeric=r.confirmed_quantity)
    from k2_results cross join lateral jsonb_array_elements(response->'rows') row
    cross join lateral jsonb_array_elements(row#>'{preview,lines}') line
    join atlas_planning.confirmed_need_line_revisions r
      on r.school_id=(row->>'school_id')::uuid and r.ingredient_id=(line->>'ingredient_id')::uuid
      and r.unit_id=(line->>'unit_id')::uuid and r.service_date='2026-11-02' and r.is_current
    where name='cn_only_pxk') exact_quantities
\gset k3_cn_
rollback to savepoint k3_cn_only_scope;
select is(:'k3_cn_commands_ok'::boolean,true,'all-CN scope uses authentic correction, allocation, Preparation and PO release');
select is(:'k3_cn_all_cn'::boolean,true,'all-CN scope has no retained PH family to conceal discovery failure');
select is(:'k3_cn_no_history'::boolean,true,'all-CN scope has never issued a PXK');
select is(:'k3_cn_visible_ready'::boolean,true,'authenticated read discovers the first all-CN PXK scope');
select is(:'k3_cn_exact_quantities'::boolean,true,'first all-CN preview retains exact current School quantities');

\ir ../local/atlas_b1_two_school_need_fixture.sql
insert into atlas_admin.suppliers(supplier_id,supplier_code,supplier_name,document_code)
values(pg_temp.ng_id(61),'k2-b1-second-supplier','K2 B1 second Supplier','K2-B1-2');
insert into atlas_admin.supplier_eligibilities(supplier_id,ingredient_id,effective_from,priority)
select pg_temp.ng_id(61),pg_temp.ng_id(2001),'2050-01-01',2;
create temporary table k2_b1_batch as
select b.confirmed_need_batch_id from atlas_planning.confirmed_need_batches b
join atlas_planning.need_generation_runs run on run.need_generation_run_id=b.current_need_generation_run_id
where run.generated_by_actor_id=pg_temp.ng_id(1) and run.period_start='2050-09-19';
insert into k2_requests
select 'b1_save',pg_temp.ng_request('RMVP-05.v2','CONFIRMED_NEED_SAVED',jsonb_build_object(
  'confirmed_need_batch_id',b.confirmed_need_batch_id,'lines',(
    select jsonb_agg(jsonb_build_object('confirmed_need_line_id',l.confirmed_need_line_id,
      'expected_current_revision_id',r.confirmed_need_line_revision_id,
      'expected_current_decision_id',l.current_confirmed_need_line_decision_id,
      'proposed_confirmed_quantity',r.confirmed_quantity::text,
      'reason_code','PROPOSAL_ACCEPTED','reason_note',null) order by l.confirmed_need_line_id)
    from atlas_planning.confirmed_need_lines l
    join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_id)
    where l.confirmed_need_batch_id=b.confirmed_need_batch_id and r.is_current)))
  ||jsonb_build_object('expected_version',b.version,'reason_note',null)
from atlas_planning.confirmed_need_batches b join k2_b1_batch using(confirmed_need_batch_id);
set local role authenticated;
insert into k2_results select 'b1_save',atlas_api.save_confirmed_needs(request)
from k2_requests where name='b1_save';
reset role;
select is((select response->>'success' from k2_results where name='b1_save'),'true',
  'B1 real human confirmation keeps R20+B5+H3 and the other School20');

-- Public regeneration carries unchanged authority before issuance. Later K1
-- must accept both that carried predecessor and the other School's carried line.
create temporary table k2_b1_before_carry as
select l.confirmed_need_line_id,l.current_confirmed_need_line_decision_id,r.confirmed_need_line_revision_id
from atlas_planning.confirmed_need_lines l
join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_id)
join k2_b1_batch target on target.confirmed_need_batch_id=l.confirmed_need_batch_id
where r.is_current and l.ingredient_id=pg_temp.ng_id(2001);
with rows as (
  select (request#>'{payload,rows}')||jsonb_build_array(jsonb_build_object(
    'service_date','2050-09-19','school_id',pg_temp.ng_id(5001),'ingredient_id',pg_temp.ng_id(2002),
    'pantry_need_purpose_id',pg_temp.ng_id(40),'requested_quantity',1,'note',null,
    'source_request_reference','K2:carry-other-family','source_row_reference','K2:carry-other-family')) value,
    request->'payload' payload from ng_requests where name='pantry'
)
insert into k2_requests
select 'b1_carry_pantry',pg_temp.ng_request('PANTRY-02.v3','PANTRY_SAVED',payload||jsonb_build_object(
  'rows',value,'source_signature',atlas_core.pantry_02_signature('2050-09-19',false,
    atlas_core.pantry_02_canonical_rows('2050-09-19',value)),
  'expected_source_signature',batch.source_signature))||jsonb_build_object('expected_version',batch.version)
from rows cross join atlas_planning.pantry_need_batches batch where batch.week_start='2050-09-19';
set local role authenticated;
insert into k2_results select name,atlas_api.save_pantry(request)
from k2_requests where name='b1_carry_pantry';
reset role;
select is((select response->>'success' from k2_results where name='b1_carry_pantry'),'true',
  'unrelated B1 Pantry correction uses the public source writer before issuance');
insert into k2_requests
select 'b1_carry_generate',pg_temp.ng_request('RMVP-04.v3','UPSTREAM_SOURCE_CHANGED',jsonb_build_object(
  'service_date','2050-09-19','expected_current_need_generation_run_id',b.current_need_generation_run_id))
  ||jsonb_build_object('expected_version',b.current_need_generation_run_version)
from atlas_planning.confirmed_need_batches b join k2_b1_batch using(confirmed_need_batch_id);
set local role authenticated;
insert into k2_results select name,atlas_api.execute_need_generation(request)
from k2_requests where name='b1_carry_generate';
reset role;
select is((select response->>'success' from k2_results where name='b1_carry_generate'),'true',
  'public regeneration establishes approved carried authority');
select ok((select count(*)=2 and bool_and(
    r.confirmed_need_line_revision_id<>prior.confirmed_need_line_revision_id
    and l.current_confirmed_need_line_decision_id=prior.current_confirmed_need_line_decision_id
    and atlas_core.planning_contract_02b_decision_authorizes_revision(
      l.current_confirmed_need_line_decision_id,l.confirmed_need_line_id,r.confirmed_need_line_revision_id))
  from k2_b1_before_carry prior join atlas_planning.confirmed_need_lines l using(confirmed_need_line_id)
  join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_id) where r.is_current),
  'both target Schools retain exact carried human authority through successor revisions');
insert into k2_requests
select 'b1_carry_save',pg_temp.ng_request('RMVP-05.v2','CONFIRMED_NEED_SAVED',jsonb_build_object(
  'confirmed_need_batch_id',b.confirmed_need_batch_id,'lines',(
    select jsonb_agg(jsonb_build_object('confirmed_need_line_id',l.confirmed_need_line_id,
      'expected_current_revision_id',r.confirmed_need_line_revision_id,'expected_current_decision_id',null,
      'proposed_confirmed_quantity',r.confirmed_quantity::text,'reason_code','PROPOSAL_ACCEPTED','reason_note',null))
    from atlas_planning.confirmed_need_lines l join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_id)
    where l.confirmed_need_batch_id=b.confirmed_need_batch_id and r.is_current
      and l.current_confirmed_need_line_decision_id is null)))
  ||jsonb_build_object('expected_version',b.version,'reason_note',null)
from atlas_planning.confirmed_need_batches b join k2_b1_batch using(confirmed_need_batch_id);
set local role authenticated;
insert into k2_results select name,atlas_api.save_confirmed_needs(request)
from k2_requests where name='b1_carry_save';
reset role;
select is((select response->>'success' from k2_results where name='b1_carry_save'),'true',
  'selective human Save confirms only invalidated lines and leaves carried authority intact');

create function pg_temp.k2_b1_allocation(a numeric,b numeric)
returns jsonb language sql volatile set search_path='' as $$
  select pg_temp.ng_request('CONFIRMED-SUPPLIER-ALLOCATION.v1',
    'CONFIRMED_SUPPLIER_ALLOCATION_SAVED',jsonb_build_object(
      'family',jsonb_build_object('service_date',p->'service_date',
        'delivery_location_id',p->'delivery_location_id','ingredient_id',p->'ingredient_id',
        'unit_id',p->'unit_id','expected_source_fingerprint',p->'source_fingerprint',
        'expected_source_batch_id',p->'source_confirmed_need_batch_id',
        'expected_source_batch_version',p->'source_confirmed_need_batch_version'),
      'splits',jsonb_build_array(jsonb_build_object('supplier_id',pg_temp.ng_id(60),
        'allocated_quantity',a::text,'supplier_note','Whole shared-School allocation'))
        ||case when b>0 then jsonb_build_array(jsonb_build_object('supplier_id',pg_temp.ng_id(61),
          'allocated_quantity',b::text,'supplier_note','Second Supplier accepted note')) else '[]'::jsonb end))
    ||jsonb_build_object('expected_version',coalesce(f.version,0),'reason_note',null)
  from atlas_core.purchase_review_confirmed_sources('2050-09-19','2050-09-19') p
  left join atlas_procurement.school_catering_allocation_families f
    on f.service_date=(p->>'service_date')::date
    and f.delivery_location_id=(p->>'delivery_location_id')::uuid
    and f.ingredient_id=(p->>'ingredient_id')::uuid and f.unit_id=(p->>'unit_id')::uuid
  where p->>'ingredient_id'=pg_temp.ng_id(2001)::text;
$$;
insert into k2_requests values('b1_allocation48',pg_temp.k2_b1_allocation(30,18));
set local role authenticated;
insert into k2_results select 'b1_allocation48',atlas_api.save_confirmed_supplier_allocation(request)
from k2_requests where name='b1_allocation48';
reset role;
select is((select response->>'success' from k2_results where name='b1_allocation48'),'true',
  'B1 explicit initial two-Supplier split totals the whole shared family48');
insert into k2_requests
select 'b1_prepare48',pg_temp.ng_request('PURCHASE-COMMITMENT.v1','PURCHASE_ORDERS_PREPARED',
  jsonb_build_object('confirmed_need_batch_id',b.confirmed_need_batch_id,'service_date','2050-09-19'))
  ||jsonb_build_object('expected_version',b.version,'reason_note',null)
from atlas_planning.confirmed_need_batches b join k2_b1_batch using(confirmed_need_batch_id);
set local role authenticated;
insert into k2_results select 'b1_prepare48',atlas_api.prepare_school_catering_purchase_orders(request)
from k2_requests where name='b1_prepare48';
reset role;
select is((select response->>'success' from k2_results where name='b1_prepare48'),'true',
  'B1 initial two-Supplier Preparation succeeds');
insert into k2_requests
select 'b1_po001:'||po.supplier_id,pg_temp.ng_request('SCHOOL-CATERING-PROCUREMENT.v1',
  'SCHOOL_CATERING_PO_RELEASED',jsonb_build_object('purchase_order_id',po.purchase_order_id,
    'expected_purchase_order_revision_id',r.purchase_order_revision_id))
  ||jsonb_build_object('expected_version',po.version,'reason_note',null)
from atlas_procurement.purchase_orders po
join atlas_procurement.purchase_order_revisions r using(purchase_order_id)
where po.school_catering_service_date='2050-09-19' and r.is_current;
set local role authenticated;
insert into k2_results select name,atlas_api.release_school_catering_purchase_order(request)
from k2_requests where name like 'b1_po001:%';
reset role;
select is((select count(*) from k2_results where name like 'b1_po001:%'
  and response->>'success'='true'),2::bigint,'both initial shared-School Supplier POs are actually released');
insert into k2_issued_history select name,(response->>'purchase_order_id')::uuid,
  pg_temp.k2_issued_snapshot((response->>'purchase_order_id')::uuid)
from k2_results where name like 'b1_po001:%';
create temporary table k2_b1_unchanged as
select l.confirmed_need_line_id,to_jsonb(r) revision,to_jsonb(d) decision
from atlas_planning.confirmed_need_lines l
join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_id)
join atlas_planning.confirmed_need_line_decisions d
  on d.confirmed_need_line_decision_id=l.current_confirmed_need_line_decision_id
join k2_b1_batch target on target.confirmed_need_batch_id=l.confirmed_need_batch_id
where r.is_current and not(l.school_id=pg_temp.ng_id(5001) and l.ingredient_id=pg_temp.ng_id(2001));
insert into k2_requests
select 'b1_correct30',pg_temp.ng_request('RMVP-05.v3','CONFIRMED_NEED_SAVED',jsonb_build_object(
  'confirmed_need_batch_id',b.confirmed_need_batch_id,'correction',jsonb_build_object(
    'expected_confirmed_need_release_id',b.current_confirmed_need_release_id,
    'expected_purchase_handoff_batch_id',h.purchase_handoff_batch_id,
    'expected_purchase_handoff_revision_id',hr.purchase_handoff_revision_id,
    'expected_purchase_handoff_version',h.version,
    'expected_source_fingerprint',encode(sha256(convert_to(
      atlas_core.rmvp_07_validated_facts_projection(b.confirmed_need_batch_id)::text,'UTF8')),'hex')),
  'lines',jsonb_build_array(jsonb_build_object('confirmed_need_line_id',l.confirmed_need_line_id,
    'expected_current_revision_id',r.confirmed_need_line_revision_id,
    'expected_current_decision_id',l.current_confirmed_need_line_decision_id,
    'proposed_confirmed_quantity','30.000000','reason_code','OPERATIONAL_QUANTITY_ADJUSTMENT',
    'reason_note','B1 actual quantity correction preserves R20/B5/H3'))))
  ||jsonb_build_object('expected_version',b.version,'reason_note',null)
from atlas_planning.confirmed_need_batches b join k2_b1_batch using(confirmed_need_batch_id)
join atlas_planning.confirmed_need_lines l using(confirmed_need_batch_id)
join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_id)
join atlas_planning.purchase_handoff_batches h on h.confirmed_need_batch_id=b.confirmed_need_batch_id
join atlas_planning.purchase_handoff_revisions hr using(purchase_handoff_batch_id)
where l.school_id=pg_temp.ng_id(5001) and l.ingredient_id=pg_temp.ng_id(2001)
  and r.is_current and hr.is_current;
set local role authenticated;
insert into k2_results select 'b1_correct30',atlas_api.save_confirmed_needs(request)
from k2_requests where name='b1_correct30';
reset role;
select is((select response->>'success' from k2_results where name='b1_correct30'),'true',
  'B1 public K1 correction changes School A28 to30 while School B20 retains its identity');

-- Removing a previously issued Supplier never auto-cancels its commitment.
savepoint b1_removed_supplier;
insert into k2_requests values('b1_removed_allocation',pg_temp.k2_b1_allocation(50,0));
set local role authenticated;
insert into k2_results select name,atlas_api.save_confirmed_supplier_allocation(request)
from k2_requests where name='b1_removed_allocation';
reset role;
select response->>'success' success from k2_results where name='b1_removed_allocation'
\gset k3_removed_allocation_
set local role authenticated;
insert into k2_results values('b1_removed_read',pg_temp.k3_allocation_read('2050-09-19'));
reset role;
select response#>>'{preparation,ready}' ready from k2_results where name='b1_removed_read'
\gset k3_removed_
select atlas_core.school_catering_po_commitment_state(po.purchase_order_id,r.purchase_order_revision_id) state
from atlas_procurement.purchase_orders po
join atlas_procurement.purchase_order_revisions r using(purchase_order_id)
where po.school_catering_service_date='2050-09-19' and po.supplier_id=pg_temp.ng_id(61) and r.is_current
\gset k3_removed_commitment_
insert into k2_requests
select 'b1_removed_replacement',pg_temp.ng_request('SCHOOL-CATERING-PROCUREMENT.v1',
  'SCHOOL_CATERING_PO_REPLACEMENT_CREATED',jsonb_build_object('replaced_purchase_order_id',po.purchase_order_id,
    'expected_purchase_order_revision_id',r.purchase_order_revision_id))
  ||jsonb_build_object('expected_version',po.version,'reason_note',null)
from atlas_procurement.purchase_orders po
join atlas_procurement.purchase_order_revisions r using(purchase_order_id)
where po.school_catering_service_date='2050-09-19' and po.supplier_id=pg_temp.ng_id(61) and r.is_current;
set local role authenticated;
insert into k2_results select name,atlas_api.create_school_catering_purchase_order_replacement(request)
from k2_requests where name='b1_removed_replacement';
reset role;
select response->>'error_code' code from k2_results where name='b1_removed_replacement'
\gset k3_removed_replacement_
rollback to savepoint b1_removed_supplier;
select is(:'k3_removed_allocation_success'::text,'true',
  'removed-Supplier scenario uses an authentic explicit allocation Save');
select is(:'k3_removed_commitment_state'::text,'CANCELLATION_REQUIRED',
  'removed Supplier keeps a cancellation obligation');
select is(:'k3_removed_replacement_code'::text,'CANCELLATION_REQUIRED',
  'public replacement refuses a zero-Supplier document');
select is(:'k3_removed_ready'::text,'false',
  'removed issued Supplier blocks Preparation read until explicit cancellation');

insert into k2_requests values('b1_allocation50',pg_temp.k2_b1_allocation(32,18));
set local role authenticated;
insert into k2_results select name,atlas_api.save_confirmed_supplier_allocation(request)
from k2_requests where name='b1_allocation50';
reset role;
select is((select response->>'success' from k2_results where name='b1_allocation50'),'true',
  'B1 corrected shared-School family50 requires explicit two-Supplier acceptance');
set local role authenticated;
insert into k2_results values('b1_mixed_read',pg_temp.k3_allocation_read('2050-09-19'));
reset role;
select is((select jsonb_agg(jsonb_build_array(row->>'service_date',row->>'delivery_location_id',
    row->>'ingredient_id',row->>'unit_id') order by row->>'ingredient_id')
  from k2_results cross join lateral jsonb_array_elements(response->'rows') row
  where name='b1_mixed_read'),jsonb_build_array(
    jsonb_build_array('2050-09-19',pg_temp.ng_id(11),pg_temp.ng_id(2001),pg_temp.ng_id(13)),
    jsonb_build_array('2050-09-19',pg_temp.ng_id(11),pg_temp.ng_id(2002),pg_temp.ng_id(13)),
    jsonb_build_array('2050-09-19',pg_temp.ng_id(11),pg_temp.ng_id(2003),pg_temp.ng_id(13)),
    jsonb_build_array('2050-09-19',pg_temp.ng_id(11),pg_temp.ng_id(2004),pg_temp.ng_id(13)),
    jsonb_build_array('2050-09-19',pg_temp.ng_id(11),pg_temp.ng_id(2016),pg_temp.ng_id(13))),
  'shared-School corrected read includes exactly the five authored family keys');
select ok(row#>>'{family,source_kind}'='CONFIRMED_NEED'
    and row->>'state'='BALANCED' and jsonb_array_length(row->'schools')=2
    and jsonb_array_length(row->'contributions')=2 and jsonb_array_length(row->'splits')=2,
  'authenticated B1 read retains both Schools, both Suppliers and exact corrected contributors')
from k2_results cross join lateral jsonb_array_elements(response->'rows') row
where name='b1_mixed_read' and row->>'ingredient_id'=pg_temp.ng_id(2001)::text;
select ok(row#>>'{family,source_kind}'='PURCHASE_HANDOFF' and row->>'state'='BALANCED',
  'B1 unchanged other Ingredient keeps original Handoff source in the mixed read')
from k2_results cross join lateral jsonb_array_elements(response->'rows') row
where name='b1_mixed_read' and row->>'ingredient_id'=pg_temp.ng_id(2002)::text;
select is((select response#>>'{preparation,ready}' from k2_results where name='b1_mixed_read'),
  'true','B1 mixed two-Supplier whole-date read agrees with actual Preparation');
insert into k2_requests
select 'b1_prepare50',pg_temp.ng_request('PURCHASE-COMMITMENT.v1','PURCHASE_ORDERS_PREPARED',
  jsonb_build_object('confirmed_need_batch_id',b.confirmed_need_batch_id,'service_date','2050-09-19'))
  ||jsonb_build_object('expected_version',b.version,'reason_note',null)
from atlas_planning.confirmed_need_batches b join k2_b1_batch using(confirmed_need_batch_id);
set local role authenticated;
insert into k2_results select 'b1_prepare50',atlas_api.prepare_school_catering_purchase_orders(request)
from k2_requests where name='b1_prepare50';
reset role;
select is((select response->>'success' from k2_results where name='b1_prepare50'),'true',
  'B1 corrected Preparation validates every family across both Schools');
insert into k2_requests
select 'b1_draft002:'||po.supplier_id,pg_temp.ng_request('SCHOOL-CATERING-PROCUREMENT.v1',
  'SCHOOL_CATERING_PO_REPLACEMENT_CREATED',jsonb_build_object('replaced_purchase_order_id',po.purchase_order_id,
    'expected_purchase_order_revision_id',r.purchase_order_revision_id))
  ||jsonb_build_object('expected_version',po.version,'reason_note',null)
from atlas_procurement.purchase_orders po
join atlas_procurement.purchase_order_revisions r using(purchase_order_id)
where po.school_catering_service_date='2050-09-19' and po.purchase_order_status='RELEASED_TO_SUPPLIER' and r.is_current;
set local role authenticated;
insert into k2_results select name,atlas_api.create_school_catering_purchase_order_replacement(request)
from k2_requests where name='b1_draft002:'||pg_temp.ng_id(60);
set local statement_timeout='8s';
insert into k2_results values('b1_first_draft_po_read',pg_temp.k3_po_read());
insert into k2_results values('b1_first_draft_pxk_read',pg_temp.k3_pxk_read());
insert into k2_results select name,atlas_api.create_school_catering_purchase_order_replacement(request)
from k2_requests where name='b1_draft002:'||pg_temp.ng_id(61);
set local statement_timeout='8s';
insert into k2_results values('b1_both_drafts_po_read',pg_temp.k3_po_read());
insert into k2_results values('b1_both_drafts_pxk_read',pg_temp.k3_pxk_read());
reset role;
select is((select response->>'success' from k2_results where name=stage),'true',
  stage||' completes through authenticated public read within the unchanged 8s budget')
from unnest(array['b1_first_draft_po_read','b1_first_draft_pxk_read',
  'b1_both_drafts_po_read','b1_both_drafts_pxk_read']) stage;
select is((select count(*) from k2_results
    cross join lateral jsonb_array_elements(response->'purchase_orders') po
    where name='b1_both_drafts_po_read' and po->>'commitment_state'='DRAFT_CURRENT'),
  2::bigint,'both complete Supplier Drafts are current without releasing either to evade a read');
select ok((select bool_and(row->>'state'='BLOCKED'
    and row#>>'{allowed_actions,release}'='false') from k2_results
    cross join lateral jsonb_array_elements(response->'rows') row
    where name='b1_both_drafts_pxk_read'),
  'PXK stays blocked until both Supplier commitments are explicitly current');
select ok((select bool_and((po->>'release_eligible')::boolean
    and (po#>>'{allowed_actions,release}')::boolean) from k2_results
    cross join lateral jsonb_array_elements(response->'purchase_orders') po
    where name='b1_both_drafts_po_read' and po->>'status'='DRAFT'),
  'complete corrected-date frontier exposes both Drafts as releasable');
select is((select count(*) from k2_results where name like 'b1_draft002:%'
  and response->>'success'='true'),2::bigint,'both Suppliers receive complete replacement Drafts');
select ok(atlas_core.school_catering_po_draft_is_stale(
    (select (response->>'purchase_order_id')::uuid from k2_results
      where name='b1_draft002:'||pg_temp.ng_id(60)),
    (select (response->>'purchase_order_revision_id')::uuid from k2_results where name='draft003')),
  'a foreign-date revision with mixed CN/Handoff families cannot satisfy the B1 Draft');
insert into k2_requests
select 'b1_po002:'||po.supplier_id,pg_temp.ng_request('SCHOOL-CATERING-PROCUREMENT.v1',
  'SCHOOL_CATERING_PO_RELEASED',jsonb_build_object('purchase_order_id',po.purchase_order_id,
    'expected_purchase_order_revision_id',r.purchase_order_revision_id))
  ||jsonb_build_object('expected_version',po.version,'reason_note',null)
from atlas_procurement.purchase_orders po
join atlas_procurement.purchase_order_revisions r using(purchase_order_id)
where po.school_catering_service_date='2050-09-19' and po.purchase_order_status='DRAFT' and r.is_current;

-- A later allocation in another family cannot leave an omitted Supplier.
savepoint b1_omitted_supplier;
insert into atlas_admin.suppliers(supplier_id,supplier_code,supplier_name,document_code)
values(pg_temp.ng_id(62),'k2-b1-third-supplier','K2 B1 third Supplier','K2-B1-3');
insert into atlas_admin.supplier_eligibilities(supplier_id,ingredient_id,effective_from,priority)
values(pg_temp.ng_id(62),pg_temp.ng_id(2002),'2050-01-01',2);
insert into k2_requests
select 'b1_reassign_other_family',pg_temp.ng_request('SCHOOL-CATERING-PROCUREMENT.v1',
  'SCHOOL_CATERING_SUPPLIER_ALLOCATION_SAVED',jsonb_build_object(
    'family',jsonb_build_object('service_date',f.service_date,'delivery_location_id',f.delivery_location_id,
      'ingredient_id',f.ingredient_id,'unit_id',f.unit_id,'expected_source_fingerprint',p->>'source_fingerprint'),
    'splits',jsonb_build_array(jsonb_build_object('supplier_id',pg_temp.ng_id(62),
      'allocated_quantity',r.family_quantity::text,'supplier_note','New Supplier needs complete coverage'))))
  ||jsonb_build_object('expected_version',f.version,'reason_note',null)
from atlas_procurement.school_catering_allocation_families f
join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
cross join lateral(select atlas_core.school_catering_family_projection(
  f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id) p) source
where f.service_date='2050-09-19' and f.ingredient_id=pg_temp.ng_id(2002) and r.is_current;
set local role authenticated;
insert into k2_results select name,atlas_api.save_school_catering_supplier_allocation(request)
from k2_requests where name='b1_reassign_other_family';
reset role;
select response->>'success' success from k2_results where name='b1_reassign_other_family'
\gset k3_omitted_allocation_
select atlas_core.school_catering_po_draft_is_stale(
  (request#>>'{payload,purchase_order_id}')::uuid,(request#>>'{payload,expected_purchase_order_revision_id}')::uuid)::text stale
from k2_requests where name='b1_po002:'||pg_temp.ng_id(61)
\gset k3_omitted_draft_
set local role authenticated;
insert into k2_results select 'b1_omitted_supplier_release',atlas_api.release_school_catering_purchase_order(request)
from k2_requests where name='b1_po002:'||pg_temp.ng_id(61);
insert into k2_results values('b1_omitted_supplier_read',pg_temp.k3_po_read());
insert into k2_results values('b1_omitted_filtered_read',atlas_api.get_school_catering_purchase_orders(jsonb_build_object(
  'contract_version','SCHOOL-CATERING-PROCUREMENT.v1','correlation_id',gen_random_uuid(),
  'requested_by_auth_subject',current_setting('request.jwt.claim.sub',true),
  'payload',jsonb_build_object('date_start','2050-09-19','date_end','2050-09-19',
    'supplier_ids',jsonb_build_array(pg_temp.ng_id(61)),'statuses',jsonb_build_array('DRAFT'),'search',null))));
reset role;
select response->>'error_code' code from k2_results where name='b1_omitted_supplier_release'
\gset k3_omitted_release_
select bool_and(po->>'release_eligible'='false'
    and po#>>'{allowed_actions,release}'='false'
    and jsonb_array_length(po->'disabled_reasons')>0)::text denied,
    (select jsonb_array_length(response->'blockers')>0 from k2_results
      where name='b1_omitted_supplier_read')::text explained
from k2_results cross join lateral jsonb_array_elements(response->'purchase_orders') po
where name='b1_omitted_supplier_read' and po->>'status'='DRAFT'
\gset k3_omitted_read_
select (jsonb_array_length(response->'purchase_orders')=1
    and response#>>'{purchase_orders,0,commitment_state}'='DRAFT_CURRENT'
    and response#>>'{purchase_orders,0,allowed_actions,release}'='false'
    and response#>>'{purchase_orders,0,release_eligible}'='false')::text denied,
    -- V2 already reports this generic whole-date currentness code; preserve it.
    (response->'blockers'=jsonb_build_array('PROCUREMENT_NOT_CURRENT',
      '19/09/2050: Cần chuẩn bị đầy đủ đơn mua theo phân bổ hiện tại trước khi phát hành. Kiểm tra các đơn Cần cập nhật hoặc trở lại Phân bổ NCC.'))::text generic
from k2_results where name='b1_omitted_filtered_read'
\gset k3_omitted_filtered_
rollback to savepoint b1_omitted_supplier;
select is(:'k3_omitted_allocation_success'::text,'true',
  'omitted-Supplier scenario uses an explicit Save in a different family');
select is(:'k3_omitted_draft_stale'::text,'false',
  'target Supplier Draft itself remains current despite the other-family change');
select is(:'k3_omitted_release_code'::text,'PREPARATION_BLOCKED',
  'final Release rejects the missing Supplier/date document despite current target totals');
select is(:'k3_omitted_read_denied'::text,'true',
  'public PO read denies every Draft on a blocked corrected date, including the current target');
select is(:'k3_omitted_read_explained'::text,'true',
  'public PO read explains the whole-date prerequisite before an operator submits release');
select is(:'k3_omitted_filtered_denied'::text,'true',
  'Supplier/status filter cannot hide the complete-date prerequisite from the current target');
select is(:'k3_omitted_filtered_generic'::text,'true',
  'filtered read reveals only the generic release prerequisite, not hidden Supplier/frontier details');

-- Inherited immutable guard rejects contribution UPDATE before touching data;
-- its existing 42703 diagnostic is outside this task's historical-guard scope.
select throws_ok($attempt$
  update atlas_procurement.school_catering_allocation_family_contributions contribution
  set confirmed_need_line_revision_id=(select r.confirmed_need_line_revision_id
    from atlas_planning.confirmed_need_line_revisions r
    join atlas_planning.confirmed_need_lines line using(confirmed_need_line_id)
    where line.school_id=pg_temp.ng_id(5002) and line.ingredient_id=pg_temp.ng_id(2001) and r.is_current)
  where contribution.family_revision_id=(select r.family_revision_id
    from atlas_procurement.school_catering_allocation_family_revisions r
    join atlas_procurement.school_catering_allocation_families f using(family_id)
    where f.service_date='2050-09-19' and f.ingredient_id=pg_temp.ng_id(2001) and r.is_current)
    and contribution.confirmed_need_line_revision_id<>(select r.confirmed_need_line_revision_id
      from atlas_planning.confirmed_need_line_revisions r
      join atlas_planning.confirmed_need_lines line using(confirmed_need_line_id)
      where line.school_id=pg_temp.ng_id(5002) and line.ingredient_id=pg_temp.ng_id(2001) and r.is_current)
$attempt$,'42703',null,'equal total50 cannot hide changed immutable School membership');

savepoint b1_wrong_shared_scope;
delete from atlas_core.actor_scopes where actor_id=pg_temp.ng_id(1);
insert into atlas_core.actor_scopes(actor_id,scope_kind,school_id)
values(pg_temp.ng_id(1),'SCHOOL',pg_temp.ng_id(5001));
set local role authenticated;
insert into k2_results select 'b1_wrong_shared_scope',atlas_api.release_school_catering_purchase_order(request)
from k2_requests where name='b1_po002:'||pg_temp.ng_id(60);
insert into k2_results values('b1_scoped_po_read',pg_temp.k3_po_read());
insert into k2_results values('b1_scoped_pxk_read',pg_temp.k3_pxk_read());
reset role;
select (select response->>'error_code' from k2_results where name='b1_wrong_shared_scope') code,
  (select coalesce(bool_and(school->>'school_id'=pg_temp.ng_id(5001)::text),true)
    from k2_results cross join lateral jsonb_array_elements(response->'purchase_orders') po
    cross join lateral jsonb_array_elements(po->'lines') line
    cross join lateral jsonb_array_elements(line->'school_breakdown') school
    where name='b1_scoped_po_read') only_authorized_school,
  (select jsonb_agg(row->>'school_id') from k2_results
    cross join lateral jsonb_array_elements(response->'rows') row
    where name='b1_scoped_pxk_read') visible_schools
\gset k3_shared_scope_
rollback to savepoint b1_wrong_shared_scope;
select is(:'k3_shared_scope_code'::text,'SCOPE_DENIED',
  'one School at a shared location cannot issue the whole shared-School PO');
select is(:'k3_shared_scope_only_authorized_school'::boolean,true,
  'one-School authorization exposes no other School through any positive Supplier overlap');
select is(:'k3_shared_scope_visible_schools'::jsonb,jsonb_build_array(pg_temp.ng_id(5001)::text),
  'one-School PXK authorization excludes the other School at the same location');
set local role authenticated;
insert into k2_results select name,atlas_api.release_school_catering_purchase_order(request)
from k2_requests where name='b1_po002:'||pg_temp.ng_id(60);
set local statement_timeout='8s';
insert into k2_results values('b1_a_released_po_read',pg_temp.k3_po_read());
insert into k2_results values('b1_a_released_pxk_read',pg_temp.k3_pxk_read());
reset role;
select is((select response->>'success' from k2_results where name=stage),'true',
  stage||' completes after A release while B remains Draft within the public 8s budget')
from unnest(array['b1_a_released_po_read','b1_a_released_pxk_read']) stage;
select ok((select count(*) filter(where po#>>'{supplier,supplier_id}'=pg_temp.ng_id(60)::text
      and po->>'commitment_state'='CURRENT')=1
    and count(*) filter(where po#>>'{supplier,supplier_id}'=pg_temp.ng_id(61)::text
      and po->>'commitment_state'='DRAFT_CURRENT')=1
    from k2_results cross join lateral jsonb_array_elements(response->'purchase_orders') po
    where name='b1_a_released_po_read'),
  'A is current and B remains a current Draft after only the explicit A release');
select ok((select count(*)=2 and bool_and(row->>'state'='BLOCKED'
    and row#>>'{allowed_actions,release}'='false') from k2_results
    cross join lateral jsonb_array_elements(response->'rows') row
    where name='b1_a_released_pxk_read'),
  'both Schools remain blocked until the second Supplier explicitly releases');
set local role authenticated;
insert into k2_results select name,atlas_api.release_school_catering_purchase_order(request)
from k2_requests where name='b1_po002:'||pg_temp.ng_id(61);
set local statement_timeout='8s';
insert into k2_results values('b1_released_po_read',pg_temp.k3_po_read());
insert into k2_results values('b1_released_pxk_read',pg_temp.k3_pxk_read());
reset role;
select is((select response->>'success' from k2_results where name=stage),'true',
  stage||' completes through authenticated public read within the unchanged 8s budget')
from unnest(array['b1_released_po_read','b1_released_pxk_read']) stage;
select is((select count(*) from k2_results
    cross join lateral jsonb_array_elements(response->'purchase_orders') po
    where name='b1_released_po_read' and po->>'commitment_state'='CURRENT'),
  2::bigint,'only both explicitly released successor POs are current');
select is((select count(*) from k2_results
    cross join lateral jsonb_array_elements(response->'purchase_orders') po
    where name='b1_released_po_read' and po->>'commitment_state'='SUPERSEDED'),
  2::bigint,'both immutable predecessor documents remain historical in the public read');
select is((select count(*) from k2_results where name like 'b1_po002:%'
  and response->>'success'='true'),2::bigint,'both complete shared-School replacement POs are explicitly released');
select ok((select count(*)=2 and bool_and(row#>>'{preview,ready}'='true'
    and row->>'state' in ('READY','REPLACEMENT_REQUIRED'))
  from k2_results cross join lateral jsonb_array_elements(response->'rows') row
  where name='b1_released_pxk_read'),
  'both explicitly released Suppliers permit truthful current mixed-source PXK previews');
select is((select jsonb_agg(jsonb_build_array(row->>'school_id',line->>'quantity')
    order by row->>'school_id')
  from k2_results cross join lateral jsonb_array_elements(response->'rows') row
  cross join lateral jsonb_array_elements(row#>'{preview,lines}') line
  where name='b1_released_pxk_read' and line->>'ingredient_id'=pg_temp.ng_id(2001)::text),
  jsonb_build_array(jsonb_build_array(pg_temp.ng_id(5001)::text,'30.000000'),
    jsonb_build_array(pg_temp.ng_id(5002)::text,'20.000000')),
  'PXK retains exact corrected School A30 and unchanged School B20 within the CN family');
select ok((select bool_and(line->>'quantity'=(select sum((source->>'covered_quantity')::numeric)::numeric(20,6)::text
      from jsonb_array_elements(line->'sources') source))
  from k2_results cross join lateral jsonb_array_elements(response->'rows') row
  cross join lateral jsonb_array_elements(row#>'{preview,lines}') line
  where name='b1_released_pxk_read'),
  'every preview quantity is fully covered by exact contribution/split/released-PO identities');
select is((select sum(l.ordered_quantity) from atlas_procurement.purchase_orders po
  join atlas_procurement.purchase_order_revisions r using(purchase_order_id)
  join atlas_procurement.purchase_order_line_revisions l using(purchase_order_revision_id)
  where po.school_catering_service_date='2050-09-19' and po.purchase_order_status='RELEASED_TO_SUPPLIER'
    and r.is_current and l.ingredient_id=pg_temp.ng_id(2001)),50::numeric,
  'complete current supplier/date coverage totals corrected School A30 plus unchanged School B20');
select ok(not exists(select 1 from k2_b1_unchanged old
  join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_id)
  join atlas_planning.confirmed_need_line_decisions d
    on d.confirmed_need_line_decision_id=(old.decision->>'confirmed_need_line_decision_id')::uuid
  where r.is_current and (to_jsonb(r)<>old.revision or to_jsonb(d)<>old.decision)),
  'unaffected B1 School/Ingredient revisions and decisions remain byte-identical');
select ok((select count(*)=3 and sum(c.controlled_contribution_quantity)=28
  and sum(c.controlled_contribution_quantity) filter(where t.contribution_family='RECIPE_DERIVED')=20
  and sum(c.controlled_contribution_quantity) filter(where t.pantry_need_line_id is not null)=8
  from atlas_planning.confirmed_need_line_revision_contributions c
  join atlas_planning.theoretical_need_lines t using(theoretical_need_line_id)
  join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_revision_id)
  where t.school_id=pg_temp.ng_id(5001) and t.ingredient_id=pg_temp.ng_id(2001) and r.is_current),
  'issued correction retains exact R20/B5/H3 theoretical evidence beneath human30');
select is(pg_temp.k2_issued_snapshot(po_id),facts,
  name||' original issued content remains identical') from k2_issued_history where name like 'b1_po001:%';

-- Stale CN membership belonging only to A must not erase B's own current Need.
create function pg_temp.k3_school_only_correction(quantity text) returns jsonb
language sql volatile set search_path='' as $$
  select pg_temp.ng_request('RMVP-05.v3','CONFIRMED_NEED_SAVED',jsonb_build_object(
    'confirmed_need_batch_id',b.confirmed_need_batch_id,
    'correction',(original.request#>'{payload,correction}')||jsonb_build_object(
      'expected_source_fingerprint',encode(sha256(convert_to(
        atlas_core.rmvp_07_validated_facts_projection(b.confirmed_need_batch_id)::text,'UTF8')),'hex')),
    'lines',jsonb_build_array(jsonb_build_object('confirmed_need_line_id',l.confirmed_need_line_id,
      'expected_current_revision_id',r.confirmed_need_line_revision_id,
      'expected_current_decision_id',l.current_confirmed_need_line_decision_id,
      'proposed_confirmed_quantity',quantity,'reason_code','OPERATIONAL_QUANTITY_ADJUSTMENT',
      'reason_note','K3 School-only stale source regression'))))
    ||jsonb_build_object('expected_version',b.version,'reason_note',null)
  from k2_requests original cross join atlas_planning.confirmed_need_batches b
  join k2_b1_batch using(confirmed_need_batch_id)
  join atlas_planning.confirmed_need_lines l using(confirmed_need_batch_id)
  join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_id)
  where original.name='b1_correct30' and l.school_id=pg_temp.ng_id(5001)
    and l.ingredient_id=pg_temp.ng_id(2016) and r.is_current;
$$;
savepoint k3_school_only_stale;
insert into k2_requests values('school_only9',pg_temp.k3_school_only_correction('9.000000'));
set local role authenticated;
insert into k2_results select name,atlas_api.save_confirmed_needs(request)
from k2_requests where name='school_only9';
reset role;
insert into k2_requests
select 'school_only_allocation',pg_temp.ng_request('CONFIRMED-SUPPLIER-ALLOCATION.v1',
  'CONFIRMED_SUPPLIER_ALLOCATION_SAVED',jsonb_build_object('family',jsonb_build_object(
    'service_date',f.service_date,'delivery_location_id',f.delivery_location_id,
    'ingredient_id',f.ingredient_id,'unit_id',f.unit_id,'expected_source_fingerprint',p->'source_fingerprint',
    'expected_source_batch_id',p->'source_confirmed_need_batch_id',
    'expected_source_batch_version',p->'source_confirmed_need_batch_version'),
    'splits',jsonb_build_array(jsonb_build_object('supplier_id',pg_temp.ng_id(60),
      'allocated_quantity',p->>'family_quantity','supplier_note',null))))
    ||jsonb_build_object('expected_version',f.version,'reason_note',null)
from atlas_procurement.school_catering_allocation_families f
cross join lateral(select atlas_core.purchase_review_confirmed_projection(
  f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id) p) projection
where f.service_date='2050-09-19' and f.ingredient_id=pg_temp.ng_id(2016);
set local role authenticated;
insert into k2_results select name,atlas_api.save_confirmed_supplier_allocation(request)
from k2_requests where name='school_only_allocation';
reset role;
insert into k2_requests values('school_only10',pg_temp.k3_school_only_correction('10.000000'));
set local role authenticated;
insert into k2_results select name,atlas_api.save_confirmed_needs(request)
from k2_requests where name='school_only10';
set local statement_timeout='8s';
insert into k2_results values('school_only_pxk',pg_temp.k3_pxk_read());
reset role;
select (select bool_and(response->>'success'='true') from k2_results where name like 'school_only%') success,
  (select row#>'{preview,blockers}' ? 'NO_CURRENT_NEED' from k2_results
    cross join lateral jsonb_array_elements(response->'rows') row where name='school_only_pxk'
      and row->>'school_id'=pg_temp.ng_id(5001)::text) a_missing,
  (select row#>'{preview,blockers}' ? 'NO_CURRENT_NEED' from k2_results
    cross join lateral jsonb_array_elements(response->'rows') row where name='school_only_pxk'
      and row->>'school_id'=pg_temp.ng_id(5002)::text) b_missing
\gset k3_school_only_
rollback to savepoint k3_school_only_stale;
select is(:'k3_school_only_success'::boolean,true,'School-only stale CN case uses two authentic corrections and explicit allocation');
select is(:'k3_school_only_a_missing'::boolean,true,'affected School cannot issue a partial preview omitting its stale CN family');
select is(:'k3_school_only_b_missing'::boolean,false,'other School retains its own current Need despite unrelated stale CN membership');
select * from finish();
rollback;
