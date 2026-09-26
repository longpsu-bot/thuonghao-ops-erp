-- Run through the disposable final-closeout harness after the real upgrade.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=pg_catalog,public,extensions;
select no_plan();
create temp table closeout_baseline as select r.need_generation_run_id run_id,b.confirmed_need_batch_id batch_id,
 r.planning_input_set_id,r.planning_input_evaluation_id,
 atlas_core.planning_contract_01_preflight_payload(r.period_start,r.period_end,null)#>'{source_date_fingerprints}' fingerprints
from atlas_planning.need_generation_runs r join atlas_planning.confirmed_need_batches b
on b.current_need_generation_run_id=r.need_generation_run_id where r.period_start='2050-09-19';
create temp table closeout_request as select jsonb_build_object(
 'contract_version','RMVP-04.v3','command_id',id,'correlation_id',gen_random_uuid(),
 'idempotency_key','closeout-exact-retry:'||id,'expected_version',3,
 'requested_by_auth_subject','a7400000-0000-4000-8000-000000000101',
 'requested_at',now(),'reason_code','NEED_GENERATION_EXECUTED','reason_note','Disposable correction proof',
 'payload',jsonb_build_object('service_date','2050-09-19','expected_current_need_generation_run_id',run_id)) request
from closeout_baseline cross join (select gen_random_uuid() id) ids;
create temp table closeout_result(name text,response jsonb);
grant select on closeout_request,closeout_baseline to authenticated;
grant all on closeout_result to authenticated;
set local request.jwt.claims='{"sub":"a7400000-0000-4000-8000-000000000101","role":"authenticated"}';
create temp table closeout_original_function as select pg_get_functiondef('atlas_api.invalidate_need_generation_run(jsonb)'::regprocedure) definition;
-- Deterministic fault at a real nested public component, properties retained.
do $fault$ declare d text; begin
 select pg_get_functiondef('atlas_api.invalidate_need_generation_run(jsonb)'::regprocedure) into d;
 d:=regexp_replace(d,'AS \$function\$[\s\S]*\$function\$',
 'AS $function$ begin return jsonb_build_object(''success'',false,''retryable'',true,''error_code'',''RETRYABLE_CONCURRENCY_FAILURE''); end; $function$');
 execute d;
end $fault$;
set local role authenticated;
insert into closeout_result select 'retryable',atlas_api.execute_need_generation(request) from closeout_request;
reset role;
select is((select response->>'retryable' from closeout_result),'true','nested correction transient remains retryable');
select is((select response->>'error_code' from closeout_result),'RETRYABLE_CONCURRENCY_FAILURE','nested transient is not hidden');
select is((select count(*) from atlas_core.command_receipts where command_id=(select (request->>'command_id')::uuid from closeout_request)),0::bigint,'retryable correction leaves no FAILED_NON_RETRYABLE or IN_PROGRESS receipt');
select is((select count(*) from atlas_planning.need_generation_runs),1::bigint,'nested failure leaves no successor');
select is((select version from atlas_planning.need_generation_runs where need_generation_run_id=(select run_id from closeout_baseline)),3::bigint,'nested failure preserves predecessor');

-- The outer exception classes must also roll back their receipt-owning block.
do $faults$ declare code text; definition text; response jsonb; begin
 foreach code in array array['40001','40P01','55P03','57014'] loop
  definition:=regexp_replace((select d.definition from closeout_original_function d),
   'AS \$function\$[\s\S]*\$function\$',
   format('AS $function$ begin raise exception using errcode=%L,message=''Disposable transient fault''; end; $function$',code));
  execute definition;
  set local role authenticated;
  select atlas_api.execute_need_generation(request) into response from closeout_request;
  reset role;
  if response->>'retryable' is distinct from 'true' or response->>'error_code' is distinct from 'RETRYABLE_CONCURRENCY_FAILURE'
    or exists(select 1 from atlas_core.command_receipts where command_id=(select (request->>'command_id')::uuid from closeout_request))
  then raise exception 'TRANSIENT_ROLLBACK_FAILED: %',code; end if;
 end loop;
end $faults$;
select pass('serialization, deadlock, lock timeout and statement timeout leave no receipt');

do $deterministic$ declare definition text; response jsonb; request jsonb; id uuid:=gen_random_uuid(); begin
 definition:=regexp_replace((select d.definition from closeout_original_function d),
  'AS \$function\$[\s\S]*\$function\$',
  'AS $function$ begin return jsonb_build_object(''success'',false,''retryable'',false,''error_code'',''INVALID_REQUEST''); end; $function$');
 execute definition;
 select r.request || jsonb_build_object('command_id',id,'idempotency_key','closeout-deterministic:'||id) into request from closeout_request r;
 set local role authenticated;
 response:=atlas_api.execute_need_generation(request);
 reset role;
 if not exists(select 1 from atlas_core.command_receipts where command_id=id and outcome='FAILED_NON_RETRYABLE'
   and response_payload->>'retryable'='false' and response_payload->>'error_code'='INVALID_REQUEST')
 then raise exception 'DETERMINISTIC_FAILURE_RECEIPT_MISSING'; end if;
end $deterministic$;
select pass('deterministic nested failure remains a legitimate immutable failed receipt');
do $$ begin execute (select definition from closeout_original_function); end $$;
-- The same frozen request can now execute once; a duplicate replays it.
set local statement_timeout='8s';
set local role authenticated;
insert into closeout_result select 'corrected',atlas_api.execute_need_generation(request) from closeout_request;
insert into closeout_result select 'replay',atlas_api.execute_need_generation(request) from closeout_request;
reset role;
select is((select response->>'success' from closeout_result where name='corrected'),'true','real correction succeeds under runtime timeout');
select is((select response from closeout_result where name='replay'),(select response from closeout_result where name='corrected'),'same frozen request replays exact response');
select is((select count(*) from atlas_planning.need_generation_runs),2::bigint,'retry and replay create exactly one successor');
select is((select count(*) from atlas_core.command_receipts where command_id=(select (request->>'command_id')::uuid from closeout_request)),1::bigint,'successful retry owns exactly one receipt');
select is((select count(*) from atlas_core.command_receipts where outcome='IN_PROGRESS'),0::bigint,'no dangling IN_PROGRESS receipt');
select is((select count(*) from atlas_planning.confirmed_need_line_revisions where is_current),248::bigint,'correction retains 248 current lines');
select is((select count(*) from atlas_planning.confirmed_need_line_revisions where not is_current and proposal_rounding_step is null and proposal_rounding_ingredient_version is null),248::bigint,'248 historical null proposal pairs remain');
select is((select count(*) from atlas_planning.confirmed_need_line_decisions),0::bigint,'correction fabricates no human decisions');
select is((select count(*) from atlas_planning.purchase_handoff_batches),0::bigint,'correction creates no Handoff');
select is((select atlas_core.planning_contract_01_preflight_payload('2050-09-19','2050-09-19',null)#>'{source_date_fingerprints}'),(select fingerprints from closeout_baseline),'correction preserves exact source fingerprints');
select * from finish();
rollback;
