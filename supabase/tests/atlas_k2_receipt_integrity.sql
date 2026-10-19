-- Receipt integrity: authenticated commands, private runtime probes and intact guards.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=extensions,public,pg_catalog;
set local statement_timeout='8s';
select no_plan();
\ir ../local/purchase_review_confirm_release_fixture.sql
insert into atlas_core.role_capabilities(role_id,capability_id)
select 'b6000000-0000-0000-0000-000000000003',capability_id
from atlas_core.capabilities where capability_code in (
  'planning.need_generation.write','confirmed_need_release.release',
  'dispatch.school_release.read','dispatch.school_release.release')
on conflict do nothing;

create temporary table ri_results(name text primary key,response jsonb not null);
create temporary table ri_requests(name text primary key,request jsonb not null);
grant select,insert on ri_results,ri_requests to authenticated;

create function pg_temp.ri_command(contract text,reason text,version bigint,payload jsonb)
returns jsonb language sql volatile set search_path='' as $$
  select jsonb_build_object('contract_version',contract,'command_id',id,
    'correlation_id',gen_random_uuid(),'idempotency_key','c-k1:'||id,
    'expected_version',version,
    'requested_by_auth_subject','b6000000-0000-0000-0000-000000000101',
    'requested_at',transaction_timestamp()-interval '1 second',
    'reason_code',reason,'reason_note',null,'payload',payload)
  from (select gen_random_uuid() id) command;
$$;
grant execute on function pg_temp.ri_command(text,text,bigint,jsonb) to authenticated;

-- Initial human confirmation and transfer use the installed public commands.
insert into ri_requests
select 'initial_save',pg_temp.ri_command('RMVP-05.v2','CONFIRMED_NEED_SAVED',b.version,
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
insert into ri_results select 'initial_save',atlas_api.save_confirmed_needs(request)
from ri_requests where name='initial_save';
reset role;
select is((select response->>'success' from ri_results where name='initial_save'),
  'true','Receipt compatibility: public editable Save succeeds');

insert into ri_requests
select 'initial_prepare',pg_temp.ri_command('PURCHASE-COMMITMENT.v1',
  'PURCHASE_ORDERS_PREPARED',version,jsonb_build_object(
    'confirmed_need_batch_id',confirmed_need_batch_id,'service_date','2026-11-02'))
from atlas_planning.confirmed_need_batches
where confirmed_need_batch_id='b6500000-0000-0000-0000-000000000050';
set local role authenticated;
insert into ri_results select 'initial_prepare',
  atlas_api.prepare_school_catering_purchase_orders(request)
from ri_requests where name='initial_prepare';
reset role;
select is((select response->>'success' from ri_results where name='initial_prepare'),
  'true','Receipt compatibility: public Preparation releases Need and real Handoff');

-- Real issued documents precede the correction; K1 must retain every byte.
update atlas_admin.schools set dispatch_document_issuer_name='Receipt disposable issuer',
  dispatch_document_issuer_address='Receipt disposable address'
where school_id='b6500000-0000-0000-0000-000000000004';
insert into ri_requests
select 'initial_po',pg_temp.ri_command('SCHOOL-CATERING-PROCUREMENT.v1',
  'SCHOOL_CATERING_PO_RELEASED',po.version,jsonb_build_object(
    'purchase_order_id',po.purchase_order_id,
    'expected_purchase_order_revision_id',revision.purchase_order_revision_id))
from atlas_procurement.purchase_orders po
join atlas_procurement.purchase_order_revisions revision using(purchase_order_id)
where po.school_catering_service_date='2026-11-02' and revision.is_current;
set local role authenticated;
insert into ri_results select 'initial_po',atlas_api.release_school_catering_purchase_order(request)
from ri_requests where name='initial_po';
reset role;
select is((select response->>'success' from ri_results where name='initial_po'),
  'true','Receipt compatibility: real public Supplier PO release');
insert into ri_requests
select 'initial_pxk',pg_temp.ri_command('SCHOOL-DISPATCH-RELEASE.v1',
  'SCHOOL_DISPATCH_DOCUMENT_RELEASED',0,jsonb_build_object('service_date','2026-11-02',
    'school_id','b6500000-0000-0000-0000-000000000004',
    'delivery_location_id','b6500000-0000-0000-0000-000000000002',
    'expected_source_fingerprint',preview->>'source_fingerprint',
    'predecessor_release_id',null))
from (select atlas_core.school_dispatch_release_preview('2026-11-02',
  'b6500000-0000-0000-0000-000000000004',
  'b6500000-0000-0000-0000-000000000002') preview) source;
set local role authenticated;
insert into ri_results select 'initial_pxk',atlas_api.release_school_dispatch_document(request)
from ri_requests where name='initial_pxk';
reset role;
select is((select response->>'success' from ri_results where name='initial_pxk'),
  'true','Receipt compatibility: real public School PXK release');

create function pg_temp.ri_snapshot(include_working boolean default false)
returns jsonb language plpgsql set search_path='' as $$
declare target text; facts jsonb; answer jsonb:='{}';
begin
  for target in select unnest(array[
    'atlas_planning.need_generation_release_snapshots',
    'atlas_planning.need_generation_release_snapshot_lines',
    'atlas_planning.confirmed_need_approval_snapshots',
    'atlas_planning.confirmed_need_snapshot_lines','atlas_planning.confirmed_need_releases',
    'atlas_planning.purchase_handoff_batches','atlas_planning.purchase_handoff_revisions',
    'atlas_planning.purchase_handoff_lines','atlas_planning.purchase_handoff_line_revisions',
    'atlas_planning.purchase_demand_references',
    'atlas_procurement.school_catering_allocation_families',
    'atlas_procurement.school_catering_allocation_family_revisions',
    'atlas_procurement.school_catering_allocation_family_contributions',
    'atlas_procurement.school_catering_allocation_supplier_splits',
    'atlas_procurement.purchase_orders','atlas_procurement.purchase_order_revisions',
    'atlas_procurement.purchase_order_lines','atlas_procurement.purchase_order_line_revisions',
    'atlas_dispatch.school_dispatch_releases','atlas_dispatch.school_dispatch_release_lines',
    'atlas_dispatch.school_dispatch_release_line_sources']||case when include_working then array[
    'atlas_planning.confirmed_need_batches','atlas_planning.confirmed_need_lines',
    'atlas_planning.confirmed_need_line_revisions','atlas_planning.confirmed_need_line_decisions',
    'atlas_planning.confirmed_need_line_revision_contributions',
    'atlas_core.command_receipts','atlas_audit.domain_events','atlas_audit.audit_events']
    else array[]::text[] end)
  loop
    execute format('select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text),''[]''::jsonb) from %s t',target)
      into facts;
    answer:=answer||jsonb_build_object(target,facts);
  end loop;
  return answer;
end $$;

-- Test-only role assumptions, rolled back with the entire fixture.
grant atlas_confirmed_need_review_runtime, atlas_procurement_command_runtime,
  atlas_dispatch_command_runtime to postgres with set true;
create function pg_temp.ri_probe(runtime_name text, statement text)
returns jsonb language plpgsql set search_path='' as $$
declare role_identity text; changed integer;
begin
  execute format('set local role %I',runtime_name);
  role_identity:=current_user;
  execute statement;
  get diagnostics changed=row_count;
  reset role;
  return jsonb_build_object('role',role_identity,'sqlstate','00000','rows',changed);
exception when others then
  return jsonb_build_object('role',role_identity,'sqlstate',sqlstate,'message',sqlerrm);
end $$;
create temporary table ri_before as select pg_temp.ri_snapshot(true) facts;
create temporary table ri_probes(name text, runtime_name text, result jsonb);

insert into ri_probes
select 'response',runtime_name,pg_temp.ri_probe(runtime_name,format(
 'update atlas_core.command_receipts set response_payload=response_payload||''{"forged_transfer_witness":true}''::jsonb where command_id=%L::uuid',
 (select request->>'command_id' from ri_requests where name='initial_prepare')))
from unnest(array['atlas_confirmed_need_review_runtime','atlas_procurement_command_runtime',
 'atlas_dispatch_command_runtime']) runtime_name;
select is(result->>'role',runtime_name,'probe actually assumes '||runtime_name) from ri_probes;
select is(result->>'sqlstate','23514','original failure: completed result mutation rejected for '||runtime_name)
from ri_probes;
set local role authenticated;
insert into ri_results select 'replay_prepare',atlas_api.prepare_school_catering_purchase_orders(request)
from ri_requests where name='initial_prepare';
reset role;
select is((select response from ri_results where name='replay_prepare'),
 (select response from ri_results where name='initial_prepare'),
 'original failure: authenticated exact Preparation replay retains immutable result');
insert into ri_probes
select 'identity',runtime_name,pg_temp.ri_probe(runtime_name,format(
 'update atlas_core.command_receipts set command_name=''prepare_corrected_need_transfer'',request_hash=repeat(''f'',64),response_payload=''{"forged":true}''::jsonb where command_id=%L::uuid',
 (select request->>'command_id' from ri_requests where name='initial_prepare')))
from unnest(array['atlas_confirmed_need_review_runtime','atlas_procurement_command_runtime',
 'atlas_dispatch_command_runtime']) runtime_name;
select is(result->>'sqlstate','23514','original failure: completed identity/hash/result change rejected for '||runtime_name)
from ri_probes where name='identity';
select is(pg_temp.ri_snapshot(true),(select facts from ri_before),
 'rejected private mutations and public replay preserve every business/receipt snapshot');

-- Original public Planning, PO and Dispatch commands replay without new writes.
set local role authenticated;
insert into ri_results select 'replay_save',atlas_api.save_confirmed_needs(request)
from ri_requests where name='initial_save';
insert into ri_results select 'replay_po',atlas_api.release_school_catering_purchase_order(request)
from ri_requests where name='initial_po';
insert into ri_results select 'replay_pxk',atlas_api.release_school_dispatch_document(request)
from ri_requests where name='initial_pxk';
reset role;
select is(replay.response,original.response,'exact public replay: '||original.name)
from ri_results original join ri_results replay on replay.name=replace(original.name,'initial_','replay_')
where original.name in ('initial_save','initial_po','initial_pxk');
select is(pg_temp.ri_snapshot(true),(select facts from ri_before),'lost response/replay adds no receipt or business write');

create temporary table ri_open_request as select jsonb_build_object(
 'command_id',gen_random_uuid(),'correlation_id',gen_random_uuid(),
 'idempotency_key','receipt-test','expected_version',1) request;
create temporary table ri_open as
with inserted as (insert into atlas_core.command_receipts(command_name,scope_key,idempotency_key,
 command_id,correlation_id,actor_id,expected_version,request_hash,outcome)
select 'receipt_integrity_fixture','b6000000-0000-0000-0000-000000000001:receipt-test','receipt-test',
 (request->>'command_id')::uuid,(request->>'correlation_id')::uuid,
 'b6000000-0000-0000-0000-000000000001',1,atlas_core.pa_05b_request_hash(request),'IN_PROGRESS'
from ri_open_request returning *)
select * from inserted;
insert into atlas_core.actors(actor_id,actor_type,display_name)
values('b6000000-0000-0000-0000-000000000099','HUMAN','Receipt integrity alternate Actor');
select is(pg_temp.ri_probe('atlas_procurement_command_runtime',format(
 'update atlas_core.command_receipts set %I=%s where command_receipt_id=%L::uuid',field,expression,
 (select command_receipt_id from ri_open)))->>'sqlstate','23514',
 'IN_PROGRESS identity remains immutable: '||field)
from (values ('command_receipt_id','gen_random_uuid()'),('command_name',quote_literal('forged')),
 ('scope_key',quote_literal('forged')),('idempotency_key',quote_literal('forged')),
 ('command_id','gen_random_uuid()'),('correlation_id','gen_random_uuid()'),
 ('actor_id',quote_literal('b6000000-0000-0000-0000-000000000099')||'::uuid'),
 ('expected_version','42'),('request_hash','repeat(''f'',64)'),
 ('started_at','started_at+interval ''1 second''')) mutations(field,expression);
select is(pg_temp.ri_probe('atlas_procurement_command_runtime',format(
 'update atlas_core.command_receipts set response_payload=''{}''::jsonb where command_receipt_id=%L::uuid',
 (select command_receipt_id from ri_open)))->>'sqlstate','23514','IN_PROGRESS cannot accumulate unsupported completion evidence');

-- UNKNOWN/in-flight receipt retains normal begin-helper concurrency response.
select is(atlas_core.pa_05b_begin_command(request,
 'b6000000-0000-0000-0000-000000000001','receipt_integrity_fixture','TEST','receipt-test')
 #>>'{response,error_code}','RETRYABLE_CONCURRENCY_FAILURE',
 'in-flight exact replay reports concurrency failure and does not complete the receipt') from ri_open_request;

select atlas_core.pa_05b_finish_command(command_receipt_id,
 '{"success":false,"error_code":"TEST_REJECTION"}'::jsonb,false) from ri_open;
select is(outcome,'FAILED_NON_RETRYABLE','valid deterministic error completes once')
from atlas_core.command_receipts where command_receipt_id=(select command_receipt_id from ri_open);
select is(pg_temp.ri_probe('atlas_procurement_command_runtime',format(
 'update atlas_core.command_receipts set %s where command_receipt_id=%L::uuid',mutation,
 (select command_receipt_id from ri_open)))->>'sqlstate','23514','terminal evidence immutable: '||mutation)
from (values ('outcome=''IN_PROGRESS'',completed_at=null'),('outcome=''COMPLETED'''),
 ('completed_at=completed_at+interval ''1 second'''),('response_payload=''{}''::jsonb'),
 ('error_code=''CHANGED''')) mutations(mutation);
select is(pg_temp.ri_probe('atlas_procurement_command_runtime',format(
 'delete from atlas_core.command_receipts where command_receipt_id=%L::uuid',
 (select command_receipt_id from ri_open)))->>'sqlstate','42501','runtime has no receipt DELETE privilege');
select throws_ok(format('delete from atlas_core.command_receipts where command_receipt_id=%L::uuid',
 (select command_receipt_id from ri_open)),'23514','Command receipt history cannot be deleted.',
 'database-owned guard also rejects privileged terminal deletion');

savepoint unsupported_evidence;
select is(pg_temp.ri_probe('atlas_procurement_command_runtime',
 $statement$insert into atlas_core.command_receipts(command_name,scope_key,idempotency_key,
 command_id,correlation_id,actor_id,request_hash,outcome,response_payload,completed_at)
 values('prepare_corrected_need_transfer','unsupported','unsupported',
 'b6900000-0000-0000-0000-000000000001',gen_random_uuid(),
 'b6000000-0000-0000-0000-000000000001',repeat('f',64),'COMPLETED','{"forged":true}',transaction_timestamp())$statement$
 )->>'sqlstate','23514','runtime cannot INSERT an already terminal transfer-shaped receipt');
select is(pg_temp.ri_probe('atlas_procurement_command_runtime',
 $statement$insert into atlas_core.command_receipts(command_name,scope_key,idempotency_key,
 command_id,correlation_id,actor_id,request_hash,outcome)
 values('prepare_corrected_need_transfer','unsupported','unsupported',
 'b6900000-0000-0000-0000-000000000001',gen_random_uuid(),
 'b6000000-0000-0000-0000-000000000001',repeat('f',64),'IN_PROGRESS')$statement$
 )->>'sqlstate','00000','authority limit: existing runtime can create unsupported transfer-shaped intent');
select is(pg_temp.ri_probe('atlas_procurement_command_runtime',
 $statement$select atlas_core.pa_05b_finish_command(command_receipt_id,'{"success":true,"forged":true}'::jsonb,true)
 from atlas_core.command_receipts where command_id='b6900000-0000-0000-0000-000000000001'$statement$
 )->>'sqlstate','00000','authority limit: runtime can complete its unsupported intent without Preparation');
select ok(exists(select 1 from atlas_core.command_receipts where
 command_id='b6900000-0000-0000-0000-000000000001' and outcome='COMPLETED')
 and not exists(select 1 from atlas_procurement.school_catering_allocation_family_revisions
 where command_id='b6900000-0000-0000-0000-000000000001'),
 'DECISION REQUIRED: immutable COMPLETED receipt is not accepted allocation/Preparation provenance');
rollback to savepoint unsupported_evidence;
select ok(not exists(select 1 from atlas_core.command_receipts
 where command_id='b6900000-0000-0000-0000-000000000001'),
 'transaction rollback removes even terminal receipt without DELETE or trigger bypass');
select ok((select relrowsecurity and relforcerowsecurity from pg_class
 where oid='atlas_core.command_receipts'::regclass),'forced receipt RLS retained');
select ok(not has_table_privilege('authenticated','atlas_core.command_receipts','INSERT')
 and not has_table_privilege('authenticated','atlas_core.command_receipts','UPDATE'),
 'public browser roles receive no direct receipt writes');
select function_owner_is('atlas_core','command_receipt_integrity_guard',array[]::text[],'atlas_owner');
select ok((select not prosecdef and proconfig @> array['search_path=""'] from pg_proc
 where oid='atlas_core.command_receipt_integrity_guard()'::regprocedure),
 'guard uses invoker privileges and an empty search path');
select ok(not exists(select 1 from unnest(array['anon','authenticated','service_role']) role_name
 where has_function_privilege(role_name,'atlas_core.command_receipt_integrity_guard()','EXECUTE')),
 'guard adds no browser/service execute grant');
select is((select count(*)::integer from regexp_matches(pg_get_functiondef(
 'atlas_core.issue_223_execute_need_generation_v2(jsonb)'::regprocedure),
 'set constraints all immediate','g')),2,'both bridge and final materialization constraint flushes remain');
set constraints all immediate;
select * from finish();
rollback;
