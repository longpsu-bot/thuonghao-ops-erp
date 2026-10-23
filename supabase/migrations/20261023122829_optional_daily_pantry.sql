-- Owner 23 October: untouched additions are optional for daily Need.
-- No old evaluation, Pantry source or operational document is rewritten.
begin;
create temporary table optional_pantry_authoring_lease on commit drop as
select r.rolname,a.set_option from pg_roles r join pg_auth_members a on a.roleid=r.oid
where a.member=(select oid from pg_roles where rolname=current_user)
 and a.grantor=(select oid from pg_roles where rolname=current_user)
 and r.rolname in ('atlas_owner','atlas_read_runtime','atlas_planning_command_runtime','atlas_need_generation_runtime');
do $lease$ begin
 if (select count(*) from optional_pantry_authoring_lease)<>4 then raise exception 'Expected four existing authoring memberships'; end if;
end $lease$;
grant atlas_owner,atlas_read_runtime,atlas_planning_command_runtime,atlas_need_generation_runtime to postgres with set true;
create temporary table optional_pantry_schema_lease on commit drop as
select n.nspname,r.rolname,has_schema_privilege(r.rolname,n.oid,'CREATE') had_create
from pg_namespace n cross join pg_roles r
where n.nspname in ('atlas_api','atlas_core')
 and r.rolname in ('atlas_read_runtime','atlas_planning_command_runtime','atlas_need_generation_runtime');
grant select on optional_pantry_schema_lease to atlas_owner;
set role atlas_owner;
grant create on schema atlas_api,atlas_core to atlas_read_runtime,atlas_planning_command_runtime,atlas_need_generation_runtime;

alter table atlas_planning.planning_input_evaluations
 add column pantry_absent boolean not null default false,
 add constraint planning_input_evaluations_pantry_absent_check check (
  not pantry_absent or (evaluation_result='READY' and blocking_issue_count=0
   and pantry_need_batch_id is null and pantry_need_batch_version is null
   and pantry_need_approval_snapshot_id is null
   and weekly_menu_id is not null and weekly_menu_version is not null
   and weekly_menu_approval_snapshot_id is not null
   and attendance_batch_id is not null and attendance_version is not null
   and attendance_approval_snapshot_id is not null));
comment on column atlas_planning.planning_input_evaluations.pantry_absent is
 'Backend-verified daily absence at evaluation time; historical null bindings default false.';
reset role;
set role atlas_read_runtime;
create function atlas_core.optional_pantry_absent(period_start date,period_end date)
returns boolean language sql stable security invoker set search_path='' as $function$
 select period_start is not null and period_start=period_end and not exists (
  select 1 from atlas_planning.pantry_need_batches batch
  where batch.week_start<=period_end and batch.week_end>=period_start);
$function$;
revoke all on function atlas_core.optional_pantry_absent(date,date) from public,anon,authenticated,service_role;
grant execute on function atlas_core.optional_pantry_absent(date,date)
 to atlas_owner,atlas_planning_command_runtime,atlas_need_generation_runtime;
reset role;

set role atlas_owner;
do $patch$
declare target record; patch jsonb; definition text; v_anchor text; occurrences integer;
begin
 for target in select signature,jsonb_agg(jsonb_build_object('old',old_text,'new',new_text) order by ordinal) changes from (values
  ('atlas_core.rmvp_03b_calculate_issues(date,date,jsonb,jsonb,jsonb)',$old$    where pantry_evidence ->> 'selection_state' = 'MISSING'$old$,$new$    where pantry_evidence ->> 'selection_state' = 'MISSING'
      and not atlas_core.optional_pantry_absent(period_start,period_end)$new$,0),
  ('atlas_planning.pa_06e_h0a4b_planning_input_integrity_guard()',$old$      if v_evaluation.pantry_need_batch_id is null
        and not exists ($old$,$new$      if v_evaluation.pantry_need_batch_id is null
        and not atlas_core.optional_pantry_absent(v_root.period_start,v_root.period_end)
        and not exists ($new$,1),
  ('atlas_planning.pa_06e_h0a4b_planning_input_evaluation_guard()',$old$  if v_root.current_evaluation_id = new.planning_input_evaluation_id then$old$,$new$  if new.pantry_absent and not atlas_core.optional_pantry_absent(v_root.period_start,v_root.period_end) then
    raise exception using errcode='23514',message='Optional Pantry requires a daily period without any existing source batch';
  end if;
  if v_root.current_evaluation_id = new.planning_input_evaluation_id then$new$,2),
  ('atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()',$old$      (v_initial_check or (tg_table_name = 'need_generation_input_snapshots' and tg_op = 'INSERT'))
      and ($old$,$new$      (v_initial_check or (tg_table_name = 'need_generation_input_snapshots' and tg_op = 'INSERT'))
      and not v_evaluation.pantry_absent
      and ($new$,3),
  ('atlas_core.rmvp_03b_bindings_current(uuid,date,date)',$old$    join atlas_planning.pantry_need_batches pantry$old$,$new$    left join atlas_planning.pantry_need_batches pantry$new$,4),
  ('atlas_core.rmvp_03b_bindings_current(uuid,date,date)',$old$      and evaluation.pantry_need_batch_id is not null
$old$,$new$$new$,5),
  ('atlas_core.rmvp_03b_bindings_current(uuid,date,date)',$old$      and pantry.version = evaluation.pantry_need_batch_version$old$,$new$      and ((evaluation.pantry_absent and atlas_core.optional_pantry_absent(period_start,period_end))
        or (pantry.version = evaluation.pantry_need_batch_version$new$,6),
  ('atlas_core.rmvp_03b_bindings_current(uuid,date,date)',$old$      and pantry.week_start <= period_start and pantry.week_end >= period_end$old$,$new$      and pantry.week_start <= period_start and pantry.week_end >= period_end))$new$,7),
  ('atlas_core.rmvp_03b_stale_source_types(uuid,date,date)',$old$    where pantry_need_batch_id is null or not exists ($old$,$new$    where not (pantry_absent and atlas_core.optional_pantry_absent(period_start,period_end))
      and (pantry_need_batch_id is null or not exists ($new$,8),
  ('atlas_core.rmvp_03b_stale_source_types(uuid,date,date)',$old$        and batch.week_start <= period_start and batch.week_end >= period_end
    )$old$,$new$        and batch.week_start <= period_start and batch.week_end >= period_end
    ))$new$,9),
  ('atlas_core.rmvp_03b_all_history_items(uuid)',$old$case when evaluation.pantry_need_batch_id is null then 'PRE_PANTRY_NULL_BINDING' else 'BOUND' end$old$,$new$case when evaluation.pantry_absent then 'OPTIONAL_ABSENT' when evaluation.pantry_need_batch_id is null then 'PRE_PANTRY_NULL_BINDING' else 'BOUND' end$new$,10),
  ('atlas_core.rmvp_03b_all_history_items(uuid)',$old$'can_authorize_need_generation_request', evaluation.pantry_need_batch_id is not null$old$,$new$'can_authorize_need_generation_request', evaluation.pantry_absent or evaluation.pantry_need_batch_id is not null$new$,11),
  ('atlas_core.rmvp_03b_source_evidence(text,date,date,jsonb)',$old$    'pantry_evidence_kind', case
      when source_kind = 'PANTRY' and v_state = 'MISSING' then 'MISSING'$old$,$new$    'optional_absent', source_kind='PANTRY' and v_state='MISSING'
      and atlas_core.optional_pantry_absent(p_period_start,p_period_end),
    'pantry_evidence_kind', case
      when source_kind = 'PANTRY' and v_state = 'MISSING' then 'MISSING'$new$,12)) as changes(signature,old_text,new_text,ordinal) group by signature order by min(ordinal) loop
  definition:=pg_get_functiondef(target.signature::regprocedure);
  for patch in select value from jsonb_array_elements(target.changes) loop
   v_anchor:=patch->>'old';
   occurrences:=(length(definition)-length(replace(definition,v_anchor,'')))/length(v_anchor);
   if occurrences<>1 then raise exception 'Optional Pantry anchor changed: % (% occurrences)',target.signature,occurrences; end if;
   definition:=replace(definition,v_anchor,patch->>'new');
  end loop;
  execute definition;
 end loop;
end $patch$;
reset role;

set role atlas_read_runtime;
do $patch$
declare target record; patch jsonb; definition text; v_anchor text; occurrences integer;
begin
 for target in select signature,jsonb_agg(jsonb_build_object('old',old_text,'new',new_text) order by ordinal) changes from (values
  ('atlas_core.direct_need_evaluation_ready(uuid,date,date)',$old$    and e.pantry_need_batch_id is not null
    and exists(select 1 from atlas_planning.weekly_menus menu$old$,$new$    and exists(select 1 from atlas_planning.weekly_menus menu$new$,0),
  ('atlas_core.direct_need_evaluation_ready(uuid,date,date)',$old$        and attendance.period_end>=target_period_end)
    and exists(select 1 from atlas_planning.pantry_need_batches pantry$old$,$new$        and attendance.period_end>=target_period_end)
    and ((e.pantry_absent and atlas_core.optional_pantry_absent(target_period_start,target_period_end))
      or exists(select 1 from atlas_planning.pantry_need_batches pantry$new$,1),
  ('atlas_core.direct_need_evaluation_ready(uuid,date,date)',$old$            pantry_snapshot.pantry_need_approval_snapshot_id));$old$,$new$            pantry_snapshot.pantry_need_approval_snapshot_id)));$new$,2),
  ('atlas_core.issue_223_period_preflight_payload(date,date,jsonb)',$old$      and v_pantry ->> 'selection_state' = 'SELECTED'
      then 'READY' else 'BLOCKED' end,$old$,$new$      and (v_pantry ->> 'selection_state' = 'SELECTED'
        or coalesce((v_pantry->>'optional_absent')::boolean,false))
      then 'READY' else 'BLOCKED' end,$new$,4),
  ('atlas_core.direct_need_legacy_preflight_payload(date,date,jsonb)',$old$        and v_sources -> 'pantry' ->> 'selection_state' = 'SELECTED'$old$,$new$        and (v_sources -> 'pantry' ->> 'selection_state' = 'SELECTED'
          or (coalesce((v_sources#>>'{pantry,optional_absent}')::boolean,false)
            and exists(select 1 from atlas_planning.need_generation_runs run
              join atlas_planning.planning_input_evaluations evaluation
                on evaluation.planning_input_evaluation_id=run.planning_input_evaluation_id
              where run.need_generation_run_id=atlas_core.pa_05b_safe_uuid(v_current->>'need_generation_run_id')
                and evaluation.pantry_absent)))$new$,5),
  ('atlas_core.direct_need_legacy_preflight_payload(date,date,jsonb)',$old$        and v_current ->> 'pantry_need_batch_id' =$old$,$new$        and (v_current ->> 'pantry_need_batch_id') is not distinct from$new$,6)) as changes(signature,old_text,new_text,ordinal) group by signature order by min(ordinal) loop
  definition:=pg_get_functiondef(target.signature::regprocedure);
  for patch in select value from jsonb_array_elements(target.changes) loop
   v_anchor:=patch->>'old';
   occurrences:=(length(definition)-length(replace(definition,v_anchor,'')))/length(v_anchor);
   if occurrences<>1 then raise exception 'Optional Pantry anchor changed: % (% occurrences)',target.signature,occurrences; end if;
   definition:=replace(definition,v_anchor,patch->>'new');
  end loop;
  execute definition;
 end loop;
end $patch$;
reset role;

set role atlas_planning_command_runtime;
do $patch$
declare target record; patch jsonb; definition text; v_anchor text; occurrences integer;
begin
 for target in select signature,jsonb_agg(jsonb_build_object('old',old_text,'new',new_text) order by ordinal) changes from (values
  ('atlas_api.save_pantry_draft(jsonb)',$old$  no_additions := (request -> 'payload' ->> 'no_additions_confirmed')::boolean;$old$,$new$  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'ATLAS-PANTRY-WEEK:' || (date_trunc('week',week_start::timestamp)::date)::text,0));
  no_additions := (request -> 'payload' ->> 'no_additions_confirmed')::boolean;$new$,0),
  ('atlas_core.issue_222_enforce_source_save(jsonb,text,text,text,text)',$old$  v_dates := atlas_core.issue_222_affected_dates($old$,$new$  if source_kind='PANTRY' then
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'ATLAS-PANTRY-WEEK:' || (date_trunc('week',v_week_start::timestamp)::date)::text,0));
  end if;
  v_dates := atlas_core.issue_222_affected_dates($new$,1),
  ('atlas_core.issue_222_affected_dates(text,jsonb)',$old$  end if;
  return v_dates;
end;$old$,$new$  end if;
  -- The first weekly source changes every current absence binding in that week.
  if v_kind='PANTRY' and not exists(select 1 from atlas_planning.pantry_need_batches batch
    where batch.week_start=v_week_start) then
    select coalesce(array_agg(distinct service_date order by service_date),'{}'::date[]) into v_dates
    from (
      select unnest(v_dates) service_date
      union
      select run.period_start from atlas_planning.need_generation_runs run
      join atlas_planning.planning_input_evaluations evaluation using(planning_input_evaluation_id)
      where evaluation.pantry_absent and run.run_status<>'INVALIDATED'
        and run.period_start between v_week_start and v_week_start+6
    ) affected;
  end if;
  return v_dates;
end;$new$,2),
  ('atlas_api.save_pantry_draft(jsonb)',$old$    insert into atlas_planning.pantry_need_batches ($old$,$new$    if exists(select 1 from atlas_planning.need_generation_runs run
      join atlas_planning.planning_input_evaluations evaluation using(planning_input_evaluation_id)
      where evaluation.pantry_absent and run.run_status<>'INVALIDATED'
        and run.period_start between week_start and week_start+6) then
      error_response:=atlas_core.issue_222_enforce_source_save(
        jsonb_set(request,'{payload}',(request->'payload')||jsonb_build_object('school_date_modes','[]'::jsonb)),
        'PANTRY',command_name,'PANTRY-02.v1','planning.pantry.write');
      if error_response is not null then
        return atlas_core.pa_05b_finish_command(receipt_id,error_response,false);
      end if;
    end if;
    insert into atlas_planning.pantry_need_batches ($new$,3),
  ('atlas_api.evaluate_planning_input_readiness(jsonb)',$old$  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');$old$,$new$  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'ATLAS-PANTRY-WEEK:' || (date_trunc('week',v_start::timestamp)::date)::text,0));
$new$,4),
  ('atlas_api.request_planning_input_need_generation(jsonb)',$old$  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');$old$,$new$  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'ATLAS-PANTRY-WEEK:' || (date_trunc('week',v_start::timestamp)::date)::text,0));
$new$,5),
  ('atlas_api.evaluate_planning_input_readiness(jsonb)',$old$    blocking_issue_count, warning_count, evaluated_by_actor_id
  ) values ($old$,$new$    blocking_issue_count, warning_count, evaluated_by_actor_id, pantry_absent
  ) values ($new$,6),
  ('atlas_api.evaluate_planning_input_readiness(jsonb)',$old$    v_blockers, v_warnings, v_actor_id
  );$old$,$new$    v_blockers, v_warnings, v_actor_id,
    v_result='READY' and v_pantry_input is null
      and atlas_core.optional_pantry_absent(v_start,v_end)
  );$new$,7),
  ('atlas_api.request_planning_input_need_generation(jsonb)',$old$  if v_evaluation.pantry_need_batch_id is null then$old$,$new$  if v_evaluation.pantry_need_batch_id is null and not v_evaluation.pantry_absent then$new$,8)) as changes(signature,old_text,new_text,ordinal) group by signature order by min(ordinal) loop
  definition:=pg_get_functiondef(target.signature::regprocedure);
  for patch in select value from jsonb_array_elements(target.changes) loop
   v_anchor:=patch->>'old';
   occurrences:=(length(definition)-length(replace(definition,v_anchor,'')))/length(v_anchor);
   if occurrences<>1 then raise exception 'Optional Pantry anchor changed: % (% occurrences)',target.signature,occurrences; end if;
   definition:=replace(definition,v_anchor,patch->>'new');
  end loop;
  execute definition;
 end loop;
end $patch$;
reset role;

set role atlas_need_generation_runtime;
do $patch$
declare target record; patch jsonb; definition text; v_anchor text; occurrences integer;
begin
 for target in select signature,jsonb_agg(jsonb_build_object('old',old_text,'new',new_text) order by ordinal) changes from (values
  ('atlas_api.create_need_generation_run(jsonb)',$old$  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');$old$,$new$  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'ATLAS-PANTRY-WEEK:' || (date_trunc('week',v_start::timestamp)::date)::text,0));
$new$,0),
  ('atlas_core.issue_223_execute_need_generation_v2(jsonb)',$old$  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');$old$,$new$  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'ATLAS-PANTRY-WEEK:' || (date_trunc('week',v_start::timestamp)::date)::text,0));
$new$,1),
  ('atlas_core.issue_223_execute_need_generation_v2(jsonb)',$old$          'pantry', pg_catalog.jsonb_build_object(
            'pantry_need_batch_id', v_preflight -> 'source_evidence' ->
              'pantry' -> 'selected' -> 'pantry_need_batch_id',
            'pantry_need_batch_version', v_preflight -> 'source_evidence' ->
              'pantry' -> 'selected' -> 'pantry_need_batch_version',
            'pantry_need_approval_snapshot_id',
              v_preflight -> 'source_evidence' -> 'pantry' ->
                'selected' -> 'pantry_need_approval_snapshot_id'
          )$old$,$new$          'pantry', case when v_preflight#>'{source_evidence,pantry,selected}' is null
            or v_preflight#>'{source_evidence,pantry,selected}'='null'::jsonb then null
            else pg_catalog.jsonb_build_object(
              'pantry_need_batch_id',v_preflight#>'{source_evidence,pantry,selected,pantry_need_batch_id}',
              'pantry_need_batch_version',v_preflight#>'{source_evidence,pantry,selected,pantry_need_batch_version}',
              'pantry_need_approval_snapshot_id',v_preflight#>'{source_evidence,pantry,selected,pantry_need_approval_snapshot_id}') end$new$,2)) as changes(signature,old_text,new_text,ordinal) group by signature order by min(ordinal) loop
  definition:=pg_get_functiondef(target.signature::regprocedure);
  for patch in select value from jsonb_array_elements(target.changes) loop
   v_anchor:=patch->>'old';
   occurrences:=(length(definition)-length(replace(definition,v_anchor,'')))/length(v_anchor);
   if occurrences<>1 then raise exception 'Optional Pantry anchor changed: % (% occurrences)',target.signature,occurrences; end if;
   definition:=replace(definition,v_anchor,patch->>'new');
  end loop;
  execute definition;
 end loop;
end $patch$;
reset role;

set role atlas_owner;
do $restore$ declare lease record; begin
 for lease in select * from pg_temp.optional_pantry_schema_lease where not had_create loop
  execute format('revoke create on schema %I from %I',lease.nspname,lease.rolname);
 end loop;
end $restore$;
reset role;
do $restore$ declare lease record; begin
 for lease in select * from pg_temp.optional_pantry_authoring_lease where not set_option loop
  execute format('grant %I to postgres with set false',lease.rolname);
 end loop;
end $restore$;
notify pgrst,'reload schema';
commit;
