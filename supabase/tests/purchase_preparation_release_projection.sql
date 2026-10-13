begin;
create extension if not exists pgtap with schema extensions;
set search_path=extensions,public,pg_catalog;
select no_plan();
\ir ../local/purchase_review_confirm_release_fixture.sql

create temporary table projection_requests(name text primary key,request jsonb);
create temporary table projection_results(name text primary key,response jsonb);
grant select,insert on projection_requests,projection_results to authenticated;
insert into projection_requests
select 'save',jsonb_build_object('contract_version','RMVP-05.v2',
  'command_id',gen_random_uuid(),'correlation_id',gen_random_uuid(),
  'idempotency_key',gen_random_uuid()::text,'expected_version',b.version,
  'requested_by_auth_subject','b6000000-0000-0000-0000-000000000101',
  'requested_at',transaction_timestamp()-interval '1 second',
  'reason_code','CONFIRMED_NEED_SAVED','reason_note',null,
  'payload',jsonb_build_object('confirmed_need_batch_id',b.confirmed_need_batch_id,
    'lines',(select jsonb_agg(jsonb_build_object(
      'confirmed_need_line_id',r.confirmed_need_line_id,
      'expected_current_revision_id',r.confirmed_need_line_revision_id,
      'expected_current_decision_id',null,
      'proposed_confirmed_quantity',r.confirmed_quantity::text,
      'reason_code','PROPOSAL_ACCEPTED','reason_note',null))
      from atlas_planning.confirmed_need_line_revisions r
      where r.confirmed_need_batch_id=b.confirmed_need_batch_id and r.is_current)))
from atlas_planning.confirmed_need_batches b
where b.confirmed_need_batch_id='b6500000-0000-0000-0000-000000000050';
set local role authenticated;
select set_config('request.jwt.claim.sub','b6000000-0000-0000-0000-000000000101',true);
insert into projection_results select name,atlas_api.save_confirmed_needs(request) from projection_requests;
reset role;
set constraints all immediate;
set constraints all deferred;
select is((select response->>'success' from projection_results where name='save'),'true','real Save establishes complete source authority');

-- Compare every output field/fingerprint against the previous wide-sort query.
do $source_equivalence$
declare definition text; body text; prior_sources jsonb; current_sources jsonb;
begin
  definition:=pg_get_functiondef('atlas_core.purchase_review_confirmed_sources(date,date)'::regprocedure);
  definition:=replace(definition,
    'atlas_core.rmvp_06_canonical_evaluation(b.confirmed_need_batch_id)->>''outcome'' outcome',
    'atlas_core.rmvp_06_canonical_evaluation(b.confirmed_need_batch_id) evaluation');
  definition:=replace(definition,'b.outcome','b.evaluation');
  definition:=replace(definition,'outcome=''VALIDATED''','evaluation->>''outcome''=''VALIDATED''');
  definition:=replace(definition,'unit_id,outcome','unit_id,evaluation->>''outcome''');
  body:=regexp_replace(split_part(split_part(definition,'AS $function$',2),'$function$',1),'[;[:space:]]+$','');
  body:=replace(replace(body,'p_start','date ''2026-11-02'''),'p_end','date ''2026-11-02''');
  execute 'select jsonb_agg(value order by value::text) from ('||body||') s(value)' into prior_sources;
  select jsonb_agg(value order by value::text) into current_sources
  from atlas_core.purchase_review_confirmed_sources('2026-11-02','2026-11-02') s(value);
  perform set_config('atlas.test_source_equivalence',(prior_sources=current_sources)::text,true);
end;
$source_equivalence$;
select is(current_setting('atlas.test_source_equivalence'),'true','narrow grouping preserves exact source output and fingerprints');

insert into projection_requests
select 'prepare',request||jsonb_build_object('contract_version','PURCHASE-COMMITMENT.v1',
  'command_id',gen_random_uuid(),'idempotency_key',gen_random_uuid()::text,
  'expected_version',b.version,'reason_code','PURCHASE_ORDERS_PREPARED',
  'payload',jsonb_build_object('confirmed_need_batch_id',b.confirmed_need_batch_id,'service_date',b.period_start))
from projection_requests cross join atlas_planning.confirmed_need_batches b
where name='save' and b.confirmed_need_batch_id='b6500000-0000-0000-0000-000000000050';
set local track_functions='all';
set local statement_timeout='20s';
set local role authenticated;
insert into projection_results select name,atlas_api.prepare_school_catering_purchase_orders(request)
from projection_requests where name='prepare';
reset role;
set constraints all immediate;
select is((select response->>'success' from projection_results where name='prepare'),'true','authenticated preparation succeeds with all integrity guards');
select is((select calls from pg_stat_xact_user_functions
  where funcid='atlas_core.purchase_review_confirmed_sources(date,date)'::regprocedure),
  7::bigint,'preparation reconstructs current sources seven times instead of eleven');
select diag((select jsonb_agg(jsonb_build_object('function',funcname,'calls',calls)
  order by funcname)::text from pg_stat_xact_user_functions where calls>0
  and funcname in ('purchase_review_confirmed_sources','rmvp_06_canonical_evaluation',
    'rmvp_07_validated_facts_projection','purchase_review_lock_allocations',
    'purchase_review_allocation_ready')));
select function_privs_are('atlas_core','purchase_review_allocation_ready',array['uuid','jsonb'],
  'authenticated',array[]::text[]);
select function_privs_are('atlas_core','purchase_review_preparation_allocation_ready',array['uuid','jsonb'],
  'authenticated',array[]::text[]);
select ok((select bool_and(pg_get_userbyid(p.proowner)='atlas_procurement_command_runtime'
  and p.proconfig=array['search_path=""']::text[]
  and not has_function_privilege('anon',p.oid,'EXECUTE')
  and not has_function_privilege('service_role',p.oid,'EXECUTE'))
  from pg_proc p where p.oid in (
    'atlas_core.purchase_review_allocation_ready(uuid,jsonb)'::regprocedure,
    'atlas_core.purchase_review_preparation_allocation_ready(uuid,jsonb)'::regprocedure)),
  'resolved predicates retain exact private ownership, path and execution boundary');
select * from finish();
rollback;
