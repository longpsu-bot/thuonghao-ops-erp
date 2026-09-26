-- LOCAL disposable fixture only. All instrumentation and command effects roll
-- back together; no constraint/trigger is disabled and no timeout is raised.
begin;
set local track_functions='all';
do $profile$
declare d text; marker text; labels text[][] := array[
  array['    if v_terminal.need_generation_run_id is not null','preflight and D047 predicate'],
  array['    select input_set.* into v_set','predecessor invalidation'],
  array['    v_result := atlas_api.create_need_generation_run(v_request_v1);','Planning Input handling'],
  array['    v_result := atlas_api.validate_need_generation_run(v_request_v1);','successor creation and theoretical generation'],
  array['    v_result := atlas_api.release_need_generation_run(v_request_v1);','successor validation'],
  array['    v_result := atlas_core.planning_contract_01_materialize_confirmed_needs(','successor release'],
  array['    -- Flush the private materializer','Confirmed Need rematerialization'],
  array['    select run.* into v_run','deferred guards'],
  array['  return atlas_core.planning_contract_01_finish_receipt(
    v_receipt_id, v_response, true','final authoritative readback']
]; pair text[];
begin
  select pg_get_functiondef('atlas_core.issue_223_execute_need_generation_v2(jsonb)'::regprocedure) into d;
  d:=replace(d,'  v_name constant text', '  profile_at timestamptz := clock_timestamp();
  v_name constant text');
  foreach pair slice 1 in array labels loop
    if position(pair[1] in d)=0 then raise exception 'PROFILE_MARKER_MISSING: %',pair[2]; end if;
    marker:=format(E'    raise notice ''PROFILE %s: %% ms'', 1000*extract(epoch from clock_timestamp()-profile_at); profile_at := clock_timestamp();\n',pair[2]);
    d:=replace(d,pair[1],marker||pair[1]);
  end loop;
  execute d;
end $profile$;
create temp table closeout_profile_result(response jsonb, server_ms numeric);
grant all on closeout_profile_result to authenticated;
create temp table closeout_profile_before as select * from pg_stat_xact_user_functions;
create temp table closeout_profile_run as select need_generation_run_id from atlas_planning.need_generation_runs where period_start='2050-09-19';
grant select on closeout_profile_run to authenticated;
set local request.jwt.claims='{"sub":"a7400000-0000-4000-8000-000000000101","role":"authenticated"}';
set local statement_timeout='8s';
set local role authenticated;
with started as materialized(select clock_timestamp() at,gen_random_uuid() id),
result as materialized(select at,atlas_api.execute_need_generation(jsonb_build_object(
 'contract_version','RMVP-04.v3','command_id',id,'correlation_id',gen_random_uuid(),
 'idempotency_key','closeout-profile:'||id,'expected_version',3,
 'requested_by_auth_subject','a7400000-0000-4000-8000-000000000101',
 'requested_at',now(),'reason_code','NEED_GENERATION_EXECUTED','reason_note','Disposable correction profiling',
 'payload',jsonb_build_object('service_date','2050-09-19','expected_current_need_generation_run_id',
 (select need_generation_run_id from closeout_profile_run)))) response from started)
insert into closeout_profile_result select response,1000*extract(epoch from clock_timestamp()-at) from result;
reset role;
select jsonb_build_object('success',response->'success','error_code',response->'error_code','server_ms',server_ms) from closeout_profile_result;
select a.schemaname,a.funcname,a.calls-coalesce(b.calls,0) calls,
 round((a.self_time-coalesce(b.self_time,0))::numeric,3) self_ms,
 round((a.total_time-coalesce(b.total_time,0))::numeric,3) inclusive_ms
from pg_stat_xact_user_functions a left join closeout_profile_before b using(funcid)
where a.schemaname like 'atlas%' and a.calls>coalesce(b.calls,0)
order by self_ms desc limit 35;
rollback;
