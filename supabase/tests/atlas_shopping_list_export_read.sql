begin;
create extension if not exists pgtap with schema extensions;
set search_path=extensions,public,pg_catalog;
select no_plan();
\ir ../local/purchase_review_confirm_release_fixture.sql
create function pg_temp.shopping_read() returns jsonb language plpgsql as $$
declare result jsonb;
begin
  execute 'select atlas_api.get_confirmed_need_shopping_list_export($1)' into result using jsonb_build_object(
    'contract_version','RMVP-05.v1','correlation_id',gen_random_uuid(),
    'requested_by_auth_subject','b6000000-0000-0000-0000-000000000101',
    'payload',jsonb_build_object('confirmed_need_batch_id','b6500000-0000-0000-0000-000000000050','filters','{}'::jsonb,'line_offset',0,'line_limit',10000));
  return result;
exception when undefined_function then return '{"success":false}'::jsonb;
end; $$;
create temp table shopping_results(response jsonb);
create temporary table shopping_before as select
 (select count(*) from atlas_planning.confirmed_need_line_decisions) decisions,
 (select count(*) from atlas_procurement.school_catering_allocation_family_revisions) allocations,
 (select count(*) from atlas_procurement.purchase_orders) orders,
 (select count(*) from atlas_core.command_receipts) receipts,
 (select count(*) from atlas_audit.domain_events) events;
grant all on shopping_results to authenticated;
grant execute on function pg_temp.shopping_read() to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','b6000000-0000-0000-0000-000000000101',true);
insert into shopping_results select pg_temp.shopping_read();
reset role;
select is((select response->>'success' from shopping_results),'true','authorized export read is available');
select has_function('atlas_api','get_confirmed_need_shopping_list_export',array['jsonb']);
select function_owner_is('atlas_api','get_confirmed_need_shopping_list_export',array['jsonb'],'atlas_confirmed_need_review_runtime');
select function_privs_are('atlas_api','get_confirmed_need_shopping_list_export',array['jsonb'],'anon',array[]::text[]);
select function_privs_are('atlas_api','get_confirmed_need_shopping_list_export',array['jsonb'],'authenticated',array['EXECUTE']);
select ok((select provolatile='s' and prosecdef and proconfig @> array['search_path=""'] from pg_proc where oid='atlas_api.get_confirmed_need_shopping_list_export(jsonb)'::regprocedure),'stable security definer has fixed empty search path');
select is((select to_jsonb(b) from shopping_before b),jsonb_build_object(
 'decisions',(select count(*) from atlas_planning.confirmed_need_line_decisions),
 'allocations',(select count(*) from atlas_procurement.school_catering_allocation_family_revisions),
 'orders',(select count(*) from atlas_procurement.purchase_orders),
 'receipts',(select count(*) from atlas_core.command_receipts),
 'events',(select count(*) from atlas_audit.domain_events)),'export read writes no business facts, receipts or events');
create function pg_temp.shopping_case(variant text) returns jsonb language plpgsql as $$
declare answer jsonb;
begin
 if variant='one' then
  update atlas_admin.supplier_eligibilities set eligibility_status='INACTIVE' where supplier_id='c7100000-0000-4000-8000-000000000002';
 elsif variant='none' then
  update atlas_admin.supplier_eligibilities set eligibility_status='INACTIVE';
 elsif variant='tie' then
  drop index atlas_admin.supplier_eligibilities_active_priority_key;
  update atlas_admin.supplier_eligibilities set priority=1;
 elsif variant='inactive_supplier' then
  update atlas_admin.suppliers set supplier_status='INACTIVE' where supplier_id='c7100000-0000-4000-8000-000000000001';
 elsif variant='inactive_eligibility' then
  update atlas_admin.supplier_eligibilities set eligibility_status='INACTIVE' where supplier_id='c7100000-0000-4000-8000-000000000001';
 elsif variant='future' then
  update atlas_admin.supplier_eligibilities set effective_from='2027-01-01' where supplier_id='c7100000-0000-4000-8000-000000000001';
 elsif variant='expired' then
  update atlas_admin.supplier_eligibilities set effective_to='2026-01-01' where supplier_id='c7100000-0000-4000-8000-000000000001';
 elsif variant='capability' then
  delete from atlas_core.role_capabilities where capability_id in (select capability_id from atlas_core.capabilities where capability_code='confirmed_need_review.read');
 elsif variant='scope' then
  update atlas_core.actor_scopes set scope_status='REVOKED';
 end if;
 perform set_config('request.jwt.claim.sub',case when variant='identity' then 'b6000000-0000-0000-0000-000000000102' else 'b6000000-0000-0000-0000-000000000101' end,true);
 set local role authenticated;
 answer:=pg_temp.shopping_read();
 reset role;
 raise exception using errcode='SLQ01';
exception when sqlstate 'SLQ01' then return answer;
end; $$;
create temp table shopping_cases as select variant,pg_temp.shopping_case(variant) response from unnest(array['one','multiple','none','tie','inactive_supplier','inactive_eligibility','future','expired','identity','capability','scope']) variant;
select ok((select bool_and(value='PR-A Verify Supplier A') from shopping_cases,lateral jsonb_each_text(response->'shopping_list_supplier_advice') where variant='one'),'one valid Supplier returns its name');
select ok((select bool_and(value='PR-A Verify Supplier A') from shopping_cases,lateral jsonb_each_text(response->'shopping_list_supplier_advice') where variant='multiple'),'multiple Suppliers return only unique lowest priority');
select ok((select bool_and(value='') from shopping_cases,lateral jsonb_each_text(response->'shopping_list_supplier_advice') where variant in ('none','tie')),'no eligible Supplier or lowest-priority tie returns blank');
select ok((select bool_and(value='PR-A Verify Supplier B') from shopping_cases,lateral jsonb_each_text(response->'shopping_list_supplier_advice') where variant='inactive_supplier'),'inactive Supplier excluded');
select ok((select bool_and(value='PR-A Verify Supplier B') from shopping_cases,lateral jsonb_each_text(response->'shopping_list_supplier_advice') where variant='inactive_eligibility'),'inactive eligibility excluded');
select ok((select bool_and(value='PR-A Verify Supplier B') from shopping_cases,lateral jsonb_each_text(response->'shopping_list_supplier_advice') where variant='future'),'future eligibility excluded');
select ok((select bool_and(value='PR-A Verify Supplier B') from shopping_cases,lateral jsonb_each_text(response->'shopping_list_supplier_advice') where variant='expired'),'expired eligibility excluded');
select is((select response->>'success' from shopping_cases where variant='identity'),'false','JWT/request identity mismatch rejected');
select is((select response->>'success' from shopping_cases where variant='capability'),'false','read capability required');
select is((select response->>'success' from shopping_cases where variant='scope'),'false','active GLOBAL scope required');
select * from finish();
rollback;
