-- Owner 16 October 2026: purpose-free Pantry v4. Legacy authored-purpose APIs remain.
begin;
create temporary table pantry_v4_authoring_lease on commit drop as
select r.rolname, a.set_option from pg_roles r join pg_auth_members a on a.roleid=r.oid
where a.member=(select oid from pg_roles where rolname=current_user)
  and a.grantor=(select oid from pg_roles where rolname=current_user)
  and r.rolname in ('atlas_owner','atlas_read_runtime','atlas_planning_command_runtime');
do $lease$ begin
 if (select count(*) from pantry_v4_authoring_lease)<>3 then raise exception 'Expected three pre-existing authoring memberships'; end if;
end $lease$;
grant atlas_owner, atlas_read_runtime, atlas_planning_command_runtime to postgres with set true;
create temporary table pantry_v4_schema_lease on commit drop as
select n.nspname,r.rolname,has_schema_privilege(r.rolname,n.oid,'CREATE') had_create
from pg_namespace n cross join pg_roles r
where (n.nspname='atlas_api' and r.rolname in ('atlas_read_runtime','atlas_planning_command_runtime'))
 or (n.nspname='atlas_core' and r.rolname='atlas_planning_command_runtime');
grant select on pantry_v4_schema_lease to atlas_owner;
set role atlas_owner;
grant create on schema atlas_api to atlas_read_runtime,atlas_planning_command_runtime;
grant create on schema atlas_core to atlas_planning_command_runtime;
create function atlas_core.pantry_v4_rows(rows jsonb)
returns jsonb language plpgsql immutable security invoker set search_path='' as $function$
declare row_value jsonb; result jsonb := '[]'::jsonb;
begin
 if jsonb_typeof(rows) is distinct from 'array' then return null; end if;
 for row_value in select value from jsonb_array_elements(rows) loop
  if jsonb_typeof(row_value) is distinct from 'object'
   or row_value-array['service_date','school_id','ingredient_id','requested_quantity',
       'note','source_request_reference','source_row_reference']<>'{}'::jsonb
   or (row_value ? 'note' and jsonb_typeof(row_value->'note') not in ('string','null'))
  then return null; end if;
  result:=result||jsonb_build_array(row_value||jsonb_build_object(
   'pantry_need_purpose_id','3c3de399-b88f-575a-a3ce-eff9e16deb55',
   'note',atlas_core.pantry_02_normalize_text(regexp_replace(row_value->>'note','^[[:space:]]+|[[:space:]]+$','','g'))));
 end loop;
 return result;
end $function$;
create function atlas_core.pantry_v4_source_payload(source_kind text,payload jsonb)
returns jsonb language plpgsql immutable security invoker set search_path='' as $function$
declare normalized_rows jsonb;
begin
 if not coalesce(payload ? 'source_contract_version',false) then return payload; end if;
 if source_kind is distinct from 'PANTRY'
   or payload->>'source_contract_version' is distinct from 'PANTRY-02.v4'
   or payload-array['source_contract_version','week_start','no_additions_confirmed',
      'source_signature','expected_source_signature','rows','school_date_modes']<>'{}'::jsonb
 then return null; end if;
 normalized_rows:=atlas_core.pantry_v4_rows(payload->'rows');
 if normalized_rows is null then return null; end if;
 return jsonb_set(payload-'source_contract_version','{rows}',normalized_rows);
end $function$;
revoke all on function atlas_core.pantry_v4_rows(jsonb),atlas_core.pantry_v4_source_payload(text,jsonb)
from public,anon,authenticated,service_role;
grant execute on function atlas_core.pantry_v4_rows(jsonb),atlas_core.pantry_v4_source_payload(text,jsonb)
to atlas_read_runtime,atlas_planning_command_runtime;
reset role;
-- The only new reference fact. No historical line/snapshot is rewritten.
insert into atlas_planning.pantry_need_purposes
(pantry_need_purpose_id,purpose_code,purpose_name_vi,purpose_description,note_rule,purpose_status,display_order)
values('3c3de399-b88f-575a-a3ce-eff9e16deb55','direct_entry_unspecified',
'Nhập trực tiếp — không chỉ định mục đích',
'Phân loại kỹ thuật do hệ thống gán cho dữ liệu nhập trực tiếp, không phải mục đích do người vận hành lựa chọn.',
'OPTIONAL','ACTIVE',2147483647);


reset role;
set role atlas_read_runtime;
do $patch$
declare definition text := pg_get_functiondef('atlas_api.preview_pantry_source(jsonb)'::regprocedure);
begin
 if position($old0$begin
  if request->>'contract_version'='PANTRY-02.v1' then$old0$ in definition)=0 then raise exception 'Pantry v4 source anchor atlas_api.preview_pantry_source(jsonb) #0 changed'; end if;
 definition:=replace(definition,$old0$begin
  if request->>'contract_version'='PANTRY-02.v1' then$old0$,$new0$begin
  if request->>'contract_version'='PANTRY-02.v4' then
    v_modes:=atlas_core.pantry_v4_rows(request#>'{payload,rows}');
    if v_modes is null then return atlas_core.pantry_02_read_error(request,'preview_pantry_source',
      'VALIDATION_FAILED','Purpose-free Pantry rows contain invalid fields.'); end if;
    v_legacy_request:=jsonb_set(jsonb_set(request,'{contract_version}','"PANTRY-02.v3"'),'{payload,rows}',v_modes);
    v_result:=atlas_api.preview_pantry_source(v_legacy_request);
    return jsonb_set(v_result,'{contract_version}','"PANTRY-02.v4"');
  end if;
  if request->>'contract_version'='PANTRY-02.v1' then$new0$);
 execute definition;
end $patch$;


reset role;
set role atlas_planning_command_runtime;
do $patch$
declare definition text := pg_get_functiondef('atlas_core.issue_222_affected_dates(text,jsonb)'::regprocedure);
begin
 if position($old0$begin
  if v_week_start$old0$ in definition)=0 then raise exception 'Pantry v4 source anchor atlas_core.issue_222_affected_dates(text,jsonb) #0 changed'; end if;
 definition:=replace(definition,$old0$begin
  if v_week_start$old0$,$new0$begin
  source_payload:=atlas_core.pantry_v4_source_payload(v_kind,source_payload);
  if source_payload is null then return v_dates; end if;
  if v_week_start$new0$);
 execute definition;
end $patch$;


reset role;
set role atlas_planning_command_runtime;
do $patch$
declare definition text := pg_get_functiondef('atlas_core.issue_222_source_impact_payload(text,jsonb)'::regprocedure);
begin
 if position($old0$  v_dates date[] := atlas_core.issue_222_affected_dates(
    source_kind, source_payload
  );$old0$ in definition)=0 then raise exception 'Pantry v4 source anchor atlas_core.issue_222_source_impact_payload(text,jsonb) #0 changed'; end if;
 definition:=replace(definition,$old0$  v_dates date[] := atlas_core.issue_222_affected_dates(
    source_kind, source_payload
  );$old0$,$new0$  v_dates date[];$new0$);
 if position($old1$begin
  foreach v_date$old1$ in definition)=0 then raise exception 'Pantry v4 source anchor atlas_core.issue_222_source_impact_payload(text,jsonb) #1 changed'; end if;
 definition:=replace(definition,$old1$begin
  foreach v_date$old1$,$new1$begin
  source_payload:=atlas_core.pantry_v4_source_payload(upper(source_kind),source_payload);
  if source_payload is null then return jsonb_build_object('source_kind',upper(source_kind),
    'material_change',false,'affected_service_dates','[]'::jsonb,'date_impacts','[]'::jsonb,
    'save_allowed',false,'save_blocker_code','VALIDATION_FAILED'); end if;
  v_dates:=atlas_core.issue_222_affected_dates(source_kind,source_payload);
  foreach v_date$new1$);
 execute definition;
end $patch$;


reset role;
set role atlas_planning_command_runtime;
do $patch$
declare definition text := pg_get_functiondef('atlas_core.issue_222_enforce_source_save(jsonb,text,text,text,text)'::regprocedure);
begin
 if position($old0$  v_payload jsonb := request -> 'payload';$old0$ in definition)=0 then raise exception 'Pantry v4 source anchor atlas_core.issue_222_enforce_source_save(jsonb,text,text,text,text) #0 changed'; end if;
 definition:=replace(definition,$old0$  v_payload jsonb := request -> 'payload';$old0$,$new0$  v_payload jsonb := request -> 'payload';
  v_source_payload jsonb := request -> 'payload';$new0$);
 if position($old1$begin
  -- Preserve$old1$ in definition)=0 then raise exception 'Pantry v4 source anchor atlas_core.issue_222_enforce_source_save(jsonb,text,text,text,text) #1 changed'; end if;
 definition:=replace(definition,$old1$begin
  -- Preserve$old1$,$new1$begin
  if source_kind='PANTRY' and request->>'contract_version'='PANTRY-02.v4' then
    v_source_payload:=v_source_payload||jsonb_build_object('source_contract_version','PANTRY-02.v4');
    v_payload:=atlas_core.pantry_v4_source_payload(source_kind,v_source_payload);
    if v_payload is null then return atlas_core.planning_contract_01_command_error(
      request,command_name,contract_version,'VALIDATION_FAILED','Purpose-free Pantry rows contain invalid fields.'); end if;
  end if;
  -- Preserve$new1$);
 if position($old2$v_dates := atlas_core.issue_222_affected_dates(
    source_kind, request -> 'payload'$old2$ in definition)=0 then raise exception 'Pantry v4 source anchor atlas_core.issue_222_enforce_source_save(jsonb,text,text,text,text) #2 changed'; end if;
 definition:=replace(definition,$old2$v_dates := atlas_core.issue_222_affected_dates(
    source_kind, request -> 'payload'$old2$,$new2$v_dates := atlas_core.issue_222_affected_dates(
    source_kind, v_source_payload$new2$);
 if position($old3$v_impact := atlas_core.issue_222_source_impact_payload(
    source_kind, request -> 'payload'$old3$ in definition)=0 then raise exception 'Pantry v4 source anchor atlas_core.issue_222_enforce_source_save(jsonb,text,text,text,text) #3 changed'; end if;
 definition:=replace(definition,$old3$v_impact := atlas_core.issue_222_source_impact_payload(
    source_kind, request -> 'payload'$old3$,$new3$v_impact := atlas_core.issue_222_source_impact_payload(
    source_kind, v_source_payload$new3$);
 execute definition;
end $patch$;


reset role;
set role atlas_planning_command_runtime;
do $patch$
declare definition text := pg_get_functiondef('atlas_core.issue_222_save_pantry_impl(jsonb)'::regprocedure);
begin
 if position($old0$  v_contract constant text := 'PANTRY-02.v3';$old0$ in definition)=0 then raise exception 'Pantry v4 source anchor atlas_core.issue_222_save_pantry_impl(jsonb) #0 changed'; end if;
 definition:=replace(definition,$old0$  v_contract constant text := 'PANTRY-02.v3';$old0$,$new0$  v_contract constant text := case when request->>'contract_version'='PANTRY-02.v4' then 'PANTRY-02.v4' else 'PANTRY-02.v3' end;$new0$);
 if position($old1$    v_week_start, request -> 'payload' -> 'rows'$old1$ in definition)=0 then raise exception 'Pantry v4 source anchor atlas_core.issue_222_save_pantry_impl(jsonb) #1 changed'; end if;
 definition:=replace(definition,$old1$    v_week_start, request -> 'payload' -> 'rows'$old1$,$new1$    v_week_start, case when v_contract='PANTRY-02.v4' then atlas_core.pantry_v4_rows(request#>'{payload,rows}') else request#>'{payload,rows}' end$new1$);
 if position($old2$        (request -> 'payload') - 'school_date_modes'$old2$ in definition)=0 then raise exception 'Pantry v4 source anchor atlas_core.issue_222_save_pantry_impl(jsonb) #2 changed'; end if;
 definition:=replace(definition,$old2$        (request -> 'payload') - 'school_date_modes'$old2$,$new2$        case when v_contract='PANTRY-02.v4' then jsonb_set((request->'payload')-'school_date_modes','{rows}',atlas_core.pantry_v4_rows(request#>'{payload,rows}')) else (request->'payload')-'school_date_modes' end$new2$);
 execute definition;
end $patch$;


reset role;
set role atlas_planning_command_runtime;
do $patch$
declare definition text := pg_get_functiondef('atlas_api.save_pantry(jsonb)'::regprocedure);
begin
 if position($old0$  v_error jsonb;$old0$ in definition)=0 then raise exception 'Pantry v4 source anchor atlas_api.save_pantry(jsonb) #0 changed'; end if;
 definition:=replace(definition,$old0$  v_error jsonb;$old0$,$new0$  v_error jsonb;
  v_actor jsonb;
  v_existing boolean;
  v_prepare jsonb;$new0$);
 if position($old1$begin
  -- Existing v2$old1$ in definition)=0 then raise exception 'Pantry v4 source anchor atlas_api.save_pantry(jsonb) #1 changed'; end if;
 definition:=replace(definition,$old1$begin
  -- Existing v2$old1$,$new1$begin
  if request->>'contract_version'='PANTRY-02.v4' then
    -- Existing identities replay before mutable impact checks, but only AFTER
    -- the unchanged envelope/HUMAN/capability/GLOBAL authorization boundary.
    v_error:=atlas_core.issue_222_source_save_auth_error(request,'save_pantry',
      'PANTRY-02.v4','planning.pantry.write');
    if v_error is not null then return v_error; end if;
    v_actor:=atlas_core.pa_05b_resolve_actor(request,'PLANNING','save_pantry');
    select exists(select 1 from atlas_core.command_receipts receipt
      where receipt.command_id=atlas_core.pa_05b_safe_uuid(request->>'command_id')
        or (receipt.scope_key=(v_actor->>'actor_id')||':pantry:'||
              atlas_core.pa_05d_safe_date(request#>>'{payload,week_start}')::text
          and receipt.command_name='save_pantry'
          and receipt.idempotency_key=request->>'idempotency_key')) into v_existing;
    if v_existing then
      begin
        v_prepare:=atlas_core.planning_contract_01_prepare_top_command(request,'save_pantry',
          'PANTRY-02.v4','planning.pantry.write',
          'pantry:'||atlas_core.pa_05d_safe_date(request#>>'{payload,week_start}')::text);
        if v_prepare->>'status'='RETURN' then
          return (v_prepare->'response')||jsonb_build_object('contract_version','PANTRY-02.v4');
        end if;
        -- Never leave a receipt created by an unexpected lookup race.
        raise sqlstate 'PV401' using message='Existing Pantry receipt did not resolve';
      exception when sqlstate 'PV401' then
        return atlas_core.planning_contract_01_command_error(request,'save_pantry',
          'PANTRY-02.v4','RETRYABLE_CONCURRENCY_FAILURE','Retry the identical Pantry command.',
          '[]'::jsonb,'[]'::jsonb,null)||jsonb_build_object('retryable',true,'write_certainty','NO_COMMITTED_CHANGE');
      end;
    end if;
    v_error:=atlas_core.issue_222_enforce_source_save(request,'PANTRY','save_pantry',
      'PANTRY-02.v4','planning.pantry.write');
    if v_error is not null then return v_error; end if;
    return atlas_core.issue_222_save_pantry_impl(request);
  end if;
  -- Existing v2$new1$);
 execute definition;
end $patch$;


reset role;
set role atlas_planning_command_runtime;
do $patch$
declare definition text := pg_get_functiondef('atlas_api.request_planning_input_need_generation(jsonb)'::regprocedure);
begin
 if position($old0$if not atlas_core.rmvp_03b_bindings_current(
    v_evaluation.planning_input_evaluation_id, v_start, v_end$old0$ in definition)=0 then raise exception 'Pantry v4 source anchor atlas_api.request_planning_input_need_generation(jsonb) #0 changed'; end if;
 definition:=replace(definition,$old0$if not atlas_core.rmvp_03b_bindings_current(
    v_evaluation.planning_input_evaluation_id, v_start, v_end$old0$,$new0$if not atlas_core.direct_need_evaluation_ready(
    v_evaluation.planning_input_evaluation_id, v_start, v_end$new0$);
 execute definition;
end $patch$;


reset role;
set role atlas_owner;
do $restore_schema$ declare r record; begin
 for r in select * from pg_temp.pantry_v4_schema_lease where not had_create loop
  execute format('revoke create on schema %I from %I',r.nspname,r.rolname);
 end loop;
end $restore_schema$;
reset role;
do $restore_roles$ declare r record; begin
 for r in select * from pg_temp.pantry_v4_authoring_lease where not set_option loop
  execute format('grant %I to postgres with set false',r.rolname);
 end loop;
end $restore_roles$;
commit;
