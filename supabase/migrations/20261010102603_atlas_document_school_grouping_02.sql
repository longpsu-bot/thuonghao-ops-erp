-- Owner-authorized separation of explicit cooking locations and Dispatch export groups.
-- Additive only: no inferred memberships, seeds, or historical snapshot backfill.
reset role;
grant atlas_owner,atlas_master_data_command_runtime,atlas_read_runtime,atlas_procurement_command_runtime to postgres with set true;
set role atlas_owner;
alter table atlas_admin.cooking_groups
  add column location_kind text,
  add column host_school_id uuid references atlas_admin.schools(school_id),
  add constraint cooking_location_facts_check check (
    (location_kind is null and host_school_id is null)
    or (location_kind is not distinct from 'SCHOOL' and host_school_id is not null)
    or (location_kind is not distinct from 'COMPANY' and host_school_id is null));
alter table atlas_admin.cooking_groups add constraint company_cooking_location_name_check
  check(location_kind is distinct from 'COMPANY' or cooking_group_name='Công ty Thượng Hảo');
grant insert(location_kind,host_school_id),update(location_kind,host_school_id)
  on atlas_admin.cooking_groups to atlas_master_data_command_runtime;
create table atlas_admin.dispatch_groups (
  dispatch_group_id uuid primary key default gen_random_uuid(),
  dispatch_group_name text not null check (
    dispatch_group_name=btrim(dispatch_group_name)
    and char_length(dispatch_group_name) between 1 and 200),
  active boolean not null default true,
  version bigint not null default 1 check(version>0),
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp()
);
create table atlas_admin.dispatch_group_members (
  school_id uuid primary key references atlas_admin.schools(school_id),
  dispatch_group_id uuid not null references atlas_admin.dispatch_groups(dispatch_group_id)
);
create index dispatch_group_members_group_idx
  on atlas_admin.dispatch_group_members(dispatch_group_id,school_id);
alter table atlas_admin.dispatch_groups enable row level security;
alter table atlas_admin.dispatch_groups force row level security;
alter table atlas_admin.dispatch_group_members enable row level security;
alter table atlas_admin.dispatch_group_members force row level security;
revoke all on atlas_admin.dispatch_groups,atlas_admin.dispatch_group_members
  from public,anon,authenticated,service_role;
grant select on atlas_admin.dispatch_groups,atlas_admin.dispatch_group_members
  to atlas_read_runtime,atlas_master_data_command_runtime;
grant insert(dispatch_group_name,active),update(dispatch_group_name,active,version,updated_at)
  on atlas_admin.dispatch_groups to atlas_master_data_command_runtime;
grant insert,update,delete on atlas_admin.dispatch_group_members
  to atlas_master_data_command_runtime;
create policy dispatch_group_read on atlas_admin.dispatch_groups
  for select to atlas_read_runtime using(true);
create policy dispatch_group_command_read on atlas_admin.dispatch_groups
  for select to atlas_master_data_command_runtime using(true);
create policy dispatch_group_command_insert on atlas_admin.dispatch_groups
  for insert to atlas_master_data_command_runtime with check(true);
create policy dispatch_group_command_update on atlas_admin.dispatch_groups
  for update to atlas_master_data_command_runtime using(true) with check(true);
create policy dispatch_membership_read on atlas_admin.dispatch_group_members
  for select to atlas_read_runtime using(true);
create policy dispatch_membership_command_read on atlas_admin.dispatch_group_members
  for select to atlas_master_data_command_runtime using(true);
create policy dispatch_membership_command_insert on atlas_admin.dispatch_group_members
  for insert to atlas_master_data_command_runtime with check(true);
create policy dispatch_membership_command_update on atlas_admin.dispatch_group_members
  for update to atlas_master_data_command_runtime using(true) with check(true);
create policy dispatch_membership_command_delete on atlas_admin.dispatch_group_members
  for delete to atlas_master_data_command_runtime using(true);

-- Row locks serialize assignment with School/group deactivation. School first,
-- then target group; deactivation never takes School locks after group locks.
create function atlas_core.guard_school_dispatch_group_membership() returns trigger
language plpgsql security definer set search_path='' as $$
declare v_status text; v_active boolean;
begin
  select school_status into v_status from atlas_admin.schools
    where school_id=new.school_id for update;
  if v_status is distinct from 'ACTIVE' then
    raise exception using errcode='23514',message='Dispatch membership requires an active School.';
  end if;
  select active into v_active from atlas_admin.dispatch_groups
    where dispatch_group_id=new.dispatch_group_id for update;
  if v_active is distinct from true then
    raise exception using errcode='23514',message='Dispatch membership requires an active existing group.';
  end if;
  return new;
end;
$$;
create function atlas_core.guard_dispatch_group_deactivation() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
  if not new.active and exists(select 1 from atlas_admin.dispatch_group_members
    where dispatch_group_id=new.dispatch_group_id) then
    raise exception using errcode='23514',message='Clear or move Dispatch memberships before deactivation.';
  end if;
  return new;
end;
$$;
create function atlas_core.guard_dispatch_school_deactivation() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if new.school_status<>'ACTIVE' and exists(select 1 from atlas_admin.dispatch_group_members
    where school_id=new.school_id) then
    raise exception using errcode='23514',message='Clear Dispatch membership before School deactivation.';
  end if;
  return new;
end;
$$;
create trigger guard_school_dispatch_group_membership before insert or update
  on atlas_admin.dispatch_group_members for each row
  execute function atlas_core.guard_school_dispatch_group_membership();
create trigger guard_dispatch_group_deactivation before update of active
  on atlas_admin.dispatch_groups for each row
  execute function atlas_core.guard_dispatch_group_deactivation();
create trigger guard_dispatch_school_deactivation before update of school_status
  on atlas_admin.schools for each row
  execute function atlas_core.guard_dispatch_school_deactivation();
revoke execute on function atlas_core.guard_school_dispatch_group_membership(),
  atlas_core.guard_dispatch_group_deactivation(),atlas_core.guard_dispatch_school_deactivation()
  from public,anon,authenticated,service_role;
grant create on schema atlas_core to atlas_master_data_command_runtime;
reset role;
alter function atlas_core.guard_school_dispatch_group_membership() owner to atlas_master_data_command_runtime;
alter function atlas_core.guard_dispatch_school_deactivation() owner to atlas_master_data_command_runtime;
set role atlas_owner;
revoke create on schema atlas_core from atlas_master_data_command_runtime;

create function atlas_api.get_dispatch_groups(request jsonb) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare v_error jsonb; v_context jsonb; v_groups jsonb;
begin
  v_error:=atlas_core.rmvp_01_validate_read_request(request,'get_dispatch_groups');
  if v_error is not null then return v_error; end if;
  if request->'payload'<>'{}'::jsonb then
    return atlas_core.rmvp_01_read_error(request,'get_dispatch_groups','VALIDATION_FAILED','Use an empty payload.');
  end if;
  v_context:=atlas_core.rmvp_01_authorize_global(request,'master_data.read','get_dispatch_groups');
  if v_context ? 'error' then return v_context->'error'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('dispatch_group_id',dispatch_group_id,
    'dispatch_group_name',dispatch_group_name,'active',active,'version',version)
    order by dispatch_group_name,dispatch_group_id),'[]'::jsonb)
    into v_groups from atlas_admin.dispatch_groups;
  return jsonb_build_object('success',true,'contract_version','RMVP-01.v1',
    'correlation_id',request->>'correlation_id','dispatch_groups',v_groups);
exception when others then
  return atlas_core.rmvp_01_read_error(request,'get_dispatch_groups','INTERNAL_READ_FAILURE','Dispatch groups could not be read safely.');
end;
$$;

create function atlas_api.upsert_dispatch_group(request jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare
  v_name constant text:='upsert_dispatch_group'; v_payload jsonb:=request->'payload';
  v_id uuid; v_group atlas_admin.dispatch_groups%rowtype; v_prepare jsonb;
  v_receipt uuid; v_actor uuid; v_before jsonb; v_after jsonb; v_version bigint;
begin
  v_after:=atlas_core.rmvp_01_validate_command_request(request,v_name);
  if v_after is not null then return v_after; end if;
  v_id:=atlas_core.pa_05b_safe_uuid(v_payload->>'dispatch_group_id');
  if not (v_payload ?& array['dispatch_group_id','dispatch_group_name','active'])
    or v_payload - array['dispatch_group_id','dispatch_group_name','active']<>'{}'::jsonb
    or (v_payload->'dispatch_group_id'<>'null'::jsonb and v_id is null)
    or jsonb_typeof(v_payload->'dispatch_group_name')<>'string'
    or v_payload->>'dispatch_group_name'<>btrim(v_payload->>'dispatch_group_name')
    or char_length(v_payload->>'dispatch_group_name') not between 1 and 200
    or jsonb_typeof(v_payload->'active')<>'boolean'
    or request->>'reason_code'<>'DISPATCH_GROUP_SAVED'
    or (v_id is null and (request->>'expected_version')::bigint<>1) then
    return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED','Dispatch group fields are invalid.','ADMIN',v_name);
  end if;
  v_prepare:=atlas_core.rmvp_01_prepare_command(request,v_name,'master_data.schools.write',
    'dispatch_group:'||coalesce(v_id::text,'new'));
  if v_prepare->>'status'='RETURN' then return v_prepare->'response'; end if;
  v_receipt:=(v_prepare->>'receipt_id')::uuid; v_actor:=(v_prepare->>'actor_id')::uuid;
  if v_id is null then
    v_version:=null; v_before:='{}'::jsonb;
    insert into atlas_admin.dispatch_groups(dispatch_group_name,active)
      values(v_payload->>'dispatch_group_name',(v_payload->>'active')::boolean)
      returning dispatch_group_id into v_id;
  else
    select * into v_group from atlas_admin.dispatch_groups where dispatch_group_id=v_id for update;
    if not found then
      return atlas_core.pa_05b_finish_command(v_receipt,atlas_core.pa_05b_command_error(
        request,'NOT_FOUND','Dispatch group was not found.','ADMIN',v_name),false);
    end if;
    if v_group.version<>(request->>'expected_version')::bigint then
      return atlas_core.pa_05b_finish_command(v_receipt,atlas_core.pa_05b_command_error(
        request,'STALE_VERSION','Refresh the Dispatch group before saving.','ADMIN',v_name),false);
    end if;
    if not (v_payload->>'active')::boolean and exists(select 1
      from atlas_admin.dispatch_group_members where dispatch_group_id=v_id) then
      return atlas_core.pa_05b_finish_command(v_receipt,atlas_core.pa_05b_command_error(
        request,'DISPATCH_GROUP_HAS_MEMBERS','Move or clear assigned Schools before deactivation.','ADMIN',v_name),false);
    end if;
    v_version:=v_group.version;
    v_before:=jsonb_build_object('dispatch_group_name',v_group.dispatch_group_name,'active',v_group.active);
    update atlas_admin.dispatch_groups set dispatch_group_name=v_payload->>'dispatch_group_name',
      active=(v_payload->>'active')::boolean,version=version+1,updated_at=transaction_timestamp()
      where dispatch_group_id=v_id;
  end if;
  v_after:=jsonb_build_object('dispatch_group_id',v_id,'dispatch_group_name',v_payload->>'dispatch_group_name',
    'active',(v_payload->>'active')::boolean);
  return atlas_core.rmvp_01_finish_success(request,v_actor,v_receipt,'DispatchGroupSaved',
    'DispatchGroup',v_id,v_version,coalesce(v_version,0)+1,v_before,v_after,'Dispatch group saved.',
    jsonb_build_object('dispatch_group_id',v_id));
exception when serialization_failure or deadlock_detected then
  return atlas_core.pa_05b_command_error(request,'RETRYABLE_CONCURRENCY_FAILURE','Retry the exact Dispatch group request.','ADMIN',v_name,true);
when others then
  return atlas_core.pa_05b_command_error(request,'INTERNAL_COMMAND_FAILURE','Dispatch group could not be saved safely.','ADMIN',v_name);
end;
$$;

create function atlas_api.set_school_dispatch_group(request jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare
  v_name constant text:='set_school_dispatch_group'; v_payload jsonb:=request->'payload';
  v_school_id uuid; v_group_id uuid; v_school atlas_admin.schools%rowtype;
  v_group atlas_admin.dispatch_groups%rowtype; v_prepare jsonb; v_receipt uuid; v_actor uuid;
  v_before jsonb; v_error jsonb;
begin
  v_error:=atlas_core.rmvp_01_validate_command_request(request,v_name);
  if v_error is not null then return v_error; end if;
  v_school_id:=atlas_core.pa_05b_safe_uuid(v_payload->>'school_id');
  v_group_id:=atlas_core.pa_05b_safe_uuid(v_payload->>'dispatch_group_id');
  if v_school_id is null or not(v_payload ? 'dispatch_group_id')
    or v_payload - array['school_id','dispatch_group_id']<>'{}'::jsonb
    or (v_payload->'dispatch_group_id'<>'null'::jsonb and v_group_id is null)
    or request->>'reason_code'<>'SCHOOL_DISPATCH_GROUP_SET' then
    return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED','School cooking assignment is invalid.','ADMIN',v_name);
  end if;
  v_prepare:=atlas_core.rmvp_01_prepare_command(request,v_name,'master_data.schools.write','school:'||v_school_id::text);
  if v_prepare->>'status'='RETURN' then return v_prepare->'response'; end if;
  v_receipt:=(v_prepare->>'receipt_id')::uuid; v_actor:=(v_prepare->>'actor_id')::uuid;
  select * into v_school from atlas_admin.schools where school_id=v_school_id for update;
  if not found then v_error:=atlas_core.pa_05b_command_error(request,'NOT_FOUND','School was not found.','ADMIN',v_name);
  elsif v_school.version<>(request->>'expected_version')::bigint then
    v_error:=atlas_core.pa_05b_command_error(request,'STALE_VERSION','Refresh the School before saving.','ADMIN',v_name);
  elsif v_group_id is not null and v_school.school_status<>'ACTIVE' then
    v_error:=atlas_core.pa_05b_command_error(request,'SCHOOL_INACTIVE','Only active Schools can be assigned.','ADMIN',v_name);
  end if;
  if v_error is not null then return atlas_core.pa_05b_finish_command(v_receipt,v_error,false); end if;
  if v_group_id is not null then
    select * into v_group from atlas_admin.dispatch_groups where dispatch_group_id=v_group_id for update;
    if not found then v_error:=atlas_core.pa_05b_command_error(request,'NOT_FOUND','Dispatch group was not found.','ADMIN',v_name);
    elsif not v_group.active then
      v_error:=atlas_core.pa_05b_command_error(request,'DISPATCH_GROUP_INACTIVE','Choose an active Dispatch group.','ADMIN',v_name);
    end if;
    if v_error is not null then return atlas_core.pa_05b_finish_command(v_receipt,v_error,false); end if;
  end if;
  select jsonb_build_object('dispatch_group_id',dispatch_group_id) into v_before
    from atlas_admin.dispatch_group_members where school_id=v_school_id;
  if v_group_id is null then
    delete from atlas_admin.dispatch_group_members where school_id=v_school_id;
  else
    insert into atlas_admin.dispatch_group_members(school_id,dispatch_group_id)
      values(v_school_id,v_group_id) on conflict(school_id) do update
      set dispatch_group_id=excluded.dispatch_group_id;
  end if;
  update atlas_admin.schools set version=version+1,updated_at=transaction_timestamp() where school_id=v_school_id;
  return atlas_core.rmvp_01_finish_success(request,v_actor,v_receipt,'SchoolDispatchGroupSet',
    'School',v_school_id,v_school.version,v_school.version+1,
    coalesce(v_before,jsonb_build_object('dispatch_group_id',null)),
    jsonb_build_object('dispatch_group_id',v_group_id),'School Dispatch group saved.',
    jsonb_build_object('school_id',v_school_id));
exception when serialization_failure or deadlock_detected then
  return atlas_core.pa_05b_command_error(request,'RETRYABLE_CONCURRENCY_FAILURE','Retry the exact School assignment request.','ADMIN',v_name,true);
when others then
  return atlas_core.pa_05b_command_error(request,'INTERNAL_COMMAND_FAILURE','School cooking assignment could not be saved safely.','ADMIN',v_name);
end;
$$;

revoke execute on function atlas_api.get_dispatch_groups(jsonb),atlas_api.upsert_dispatch_group(jsonb),
  atlas_api.set_school_dispatch_group(jsonb) from public,anon,authenticated,service_role;
grant execute on function atlas_api.get_dispatch_groups(jsonb),atlas_api.upsert_dispatch_group(jsonb),
  atlas_api.set_school_dispatch_group(jsonb) to authenticated;
grant create on schema atlas_api to atlas_read_runtime,atlas_master_data_command_runtime;
reset role;
alter function atlas_api.get_dispatch_groups(jsonb) owner to atlas_read_runtime;
alter function atlas_api.upsert_dispatch_group(jsonb) owner to atlas_master_data_command_runtime;
alter function atlas_api.set_school_dispatch_group(jsonb) owner to atlas_master_data_command_runtime;
set role atlas_owner;
revoke create on schema atlas_api from atlas_read_runtime,atlas_master_data_command_runtime;

grant create on schema atlas_api to atlas_read_runtime,atlas_master_data_command_runtime;
reset role;
set role atlas_read_runtime;
create or replace function atlas_api.get_cooking_groups(request jsonb) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare v_error jsonb; v_context jsonb; v_groups jsonb;
begin
  v_error:=atlas_core.rmvp_01_validate_read_request(request,'get_cooking_groups');
  if v_error is not null then return v_error; end if;
  if request->'payload'<>'{}'::jsonb then
    return atlas_core.rmvp_01_read_error(request,'get_cooking_groups','VALIDATION_FAILED','Use an empty payload.');
  end if;
  v_context:=atlas_core.rmvp_01_authorize_global(request,'master_data.read','get_cooking_groups');
  if v_context ? 'error' then return v_context->'error'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('cooking_group_id',cooking_group_id,
    'cooking_group_name',cooking_group_name,'active',active,'version',version,'location_kind',location_kind,'host_school_id',host_school_id)
    order by cooking_group_name,cooking_group_id),'[]'::jsonb)
    into v_groups from atlas_admin.cooking_groups;
  return jsonb_build_object('success',true,'contract_version','RMVP-01.v1',
    'correlation_id',request->>'correlation_id','cooking_groups',v_groups);
exception when others then
  return atlas_core.rmvp_01_read_error(request,'get_cooking_groups','INTERNAL_READ_FAILURE','Cooking groups could not be read safely.');
end;
$$;

reset role;
set role atlas_master_data_command_runtime;
create or replace function atlas_api.upsert_cooking_group(request jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare
  v_name constant text:='upsert_cooking_group'; v_payload jsonb:=request->'payload';
  v_id uuid; v_group atlas_admin.cooking_groups%rowtype; v_prepare jsonb;
  v_receipt uuid; v_actor uuid; v_before jsonb; v_after jsonb; v_version bigint; v_kind text; v_host uuid; v_typed boolean;
begin
  v_after:=atlas_core.rmvp_01_validate_command_request(request,v_name);
  if v_after is not null then return v_after; end if;
  v_id:=atlas_core.pa_05b_safe_uuid(v_payload->>'cooking_group_id');
  v_typed:=v_payload ? 'location_kind' or v_payload ? 'host_school_id';
  v_kind:=v_payload->>'location_kind'; v_host:=atlas_core.pa_05b_safe_uuid(v_payload->>'host_school_id');
  if not (v_payload ?& array['cooking_group_id','cooking_group_name','active'])
    or v_payload - array['cooking_group_id','cooking_group_name','active','location_kind','host_school_id']<>'{}'::jsonb
    or (v_payload->'cooking_group_id'<>'null'::jsonb and v_id is null)
    or jsonb_typeof(v_payload->'cooking_group_name')<>'string'
    or v_payload->>'cooking_group_name'<>btrim(v_payload->>'cooking_group_name')
    or char_length(v_payload->>'cooking_group_name') not between 1 and 200
    or jsonb_typeof(v_payload->'active')<>'boolean'
    or (v_id is null and not v_typed)
    or (v_typed and (not(v_payload ?& array['location_kind','host_school_id'])
      or jsonb_typeof(v_payload->'location_kind') is distinct from 'string'
      or v_kind not in ('SCHOOL','COMPANY')
      or (v_kind='SCHOOL' and v_host is null)
      or (v_kind='COMPANY' and (v_payload->'host_school_id' is distinct from 'null'::jsonb
        or v_payload->>'cooking_group_name'<>'Công ty Thượng Hảo'))))
    or request->>'reason_code'<>'COOKING_GROUP_SAVED'
    or (v_id is null and (request->>'expected_version')::bigint<>1) then
    return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED','Cooking group fields are invalid.','ADMIN',v_name);
  end if;
  v_prepare:=atlas_core.rmvp_01_prepare_command(request,v_name,'master_data.schools.write',
    'cooking_group:'||coalesce(v_id::text,'new'));
  if v_prepare->>'status'='RETURN' then return v_prepare->'response'; end if;
  v_receipt:=(v_prepare->>'receipt_id')::uuid; v_actor:=(v_prepare->>'actor_id')::uuid;
  if v_typed and v_host is not null and not exists(select 1 from atlas_admin.schools where school_id=v_host) then
    return atlas_core.pa_05b_finish_command(v_receipt,atlas_core.pa_05b_command_error(
      request,'NOT_FOUND','Host School was not found.','ADMIN',v_name),false);
  end if;
  if v_id is null then
    v_version:=null; v_before:='{}'::jsonb;
    insert into atlas_admin.cooking_groups(cooking_group_name,active,location_kind,host_school_id)
      values(v_payload->>'cooking_group_name',(v_payload->>'active')::boolean,v_kind,v_host)
      returning cooking_group_id into v_id;
  else
    select * into v_group from atlas_admin.cooking_groups where cooking_group_id=v_id for update;
    if not found then
      return atlas_core.pa_05b_finish_command(v_receipt,atlas_core.pa_05b_command_error(
        request,'NOT_FOUND','Cooking group was not found.','ADMIN',v_name),false);
    end if;
    if v_group.version<>(request->>'expected_version')::bigint then
      return atlas_core.pa_05b_finish_command(v_receipt,atlas_core.pa_05b_command_error(
        request,'STALE_VERSION','Refresh the cooking group before saving.','ADMIN',v_name),false);
    end if;
    if not (v_payload->>'active')::boolean and exists(select 1
      from atlas_admin.school_cooking_group_memberships where cooking_group_id=v_id) then
      return atlas_core.pa_05b_finish_command(v_receipt,atlas_core.pa_05b_command_error(
        request,'COOKING_GROUP_HAS_MEMBERS','Move or clear assigned Schools before deactivation.','ADMIN',v_name),false);
    end if;
    v_version:=v_group.version;
    v_before:=jsonb_build_object('cooking_group_name',v_group.cooking_group_name,'active',v_group.active,'location_kind',v_group.location_kind,'host_school_id',v_group.host_school_id);
    if not v_typed then v_kind:=v_group.location_kind; v_host:=v_group.host_school_id; end if;
    if v_kind='COMPANY' and v_payload->>'cooking_group_name'<>'Công ty Thượng Hảo' then
      return atlas_core.pa_05b_finish_command(v_receipt,atlas_core.pa_05b_command_error(
        request,'VALIDATION_FAILED','Company Cooking Location requires its canonical name.','ADMIN',v_name),false);
    end if;
    update atlas_admin.cooking_groups set cooking_group_name=v_payload->>'cooking_group_name',
      active=(v_payload->>'active')::boolean,location_kind=v_kind,host_school_id=v_host,version=version+1,updated_at=transaction_timestamp()
      where cooking_group_id=v_id;
  end if;
  v_after:=jsonb_build_object('cooking_group_id',v_id,'cooking_group_name',v_payload->>'cooking_group_name',
    'active',(v_payload->>'active')::boolean,'location_kind',v_kind,'host_school_id',v_host);
  return atlas_core.rmvp_01_finish_success(request,v_actor,v_receipt,'CookingGroupSaved',
    'CookingGroup',v_id,v_version,coalesce(v_version,0)+1,v_before,v_after,'Cooking group saved.',
    jsonb_build_object('cooking_group_id',v_id));
exception when serialization_failure or deadlock_detected then
  return atlas_core.pa_05b_command_error(request,'RETRYABLE_CONCURRENCY_FAILURE','Retry the exact cooking group request.','ADMIN',v_name,true);
when others then
  return atlas_core.pa_05b_command_error(request,'INTERNAL_COMMAND_FAILURE','Cooking group could not be saved safely.','ADMIN',v_name);
end;
$$;

create or replace function atlas_api.set_school_cooking_group(request jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare
  v_name constant text:='set_school_cooking_group'; v_payload jsonb:=request->'payload';
  v_school_id uuid; v_group_id uuid; v_school atlas_admin.schools%rowtype;
  v_group atlas_admin.cooking_groups%rowtype; v_prepare jsonb; v_receipt uuid; v_actor uuid;
  v_before jsonb; v_error jsonb;
begin
  v_error:=atlas_core.rmvp_01_validate_command_request(request,v_name);
  if v_error is not null then return v_error; end if;
  v_school_id:=atlas_core.pa_05b_safe_uuid(v_payload->>'school_id');
  v_group_id:=atlas_core.pa_05b_safe_uuid(v_payload->>'cooking_group_id');
  if v_school_id is null or not(v_payload ? 'cooking_group_id')
    or v_payload - array['school_id','cooking_group_id']<>'{}'::jsonb
    or (v_payload->'cooking_group_id'<>'null'::jsonb and v_group_id is null)
    or request->>'reason_code'<>'SCHOOL_COOKING_GROUP_SET' then
    return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED','School cooking assignment is invalid.','ADMIN',v_name);
  end if;
  v_prepare:=atlas_core.rmvp_01_prepare_command(request,v_name,'master_data.schools.write','school:'||v_school_id::text);
  if v_prepare->>'status'='RETURN' then return v_prepare->'response'; end if;
  v_receipt:=(v_prepare->>'receipt_id')::uuid; v_actor:=(v_prepare->>'actor_id')::uuid;
  select * into v_school from atlas_admin.schools where school_id=v_school_id for update;
  if not found then v_error:=atlas_core.pa_05b_command_error(request,'NOT_FOUND','School was not found.','ADMIN',v_name);
  elsif v_school.version<>(request->>'expected_version')::bigint then
    v_error:=atlas_core.pa_05b_command_error(request,'STALE_VERSION','Refresh the School before saving.','ADMIN',v_name);
  elsif v_group_id is not null and v_school.school_status<>'ACTIVE' then
    v_error:=atlas_core.pa_05b_command_error(request,'SCHOOL_INACTIVE','Only active Schools can be assigned.','ADMIN',v_name);
  end if;
  if v_error is not null then return atlas_core.pa_05b_finish_command(v_receipt,v_error,false); end if;
  if v_group_id is not null then
    select * into v_group from atlas_admin.cooking_groups where cooking_group_id=v_group_id for update;
    if not found then v_error:=atlas_core.pa_05b_command_error(request,'NOT_FOUND','Cooking group was not found.','ADMIN',v_name);
    elsif not v_group.active then
      v_error:=atlas_core.pa_05b_command_error(request,'COOKING_GROUP_INACTIVE','Choose an active cooking group.','ADMIN',v_name);
    elsif v_group.location_kind is null then
      v_error:=atlas_core.pa_05b_command_error(request,'COOKING_LOCATION_RECONCILIATION_REQUIRED',
        'Resolve explicit location kind and host School before assigning.','ADMIN',v_name);
    end if;
    if v_error is not null then return atlas_core.pa_05b_finish_command(v_receipt,v_error,false); end if;
  end if;
  select jsonb_build_object('cooking_group_id',cooking_group_id) into v_before
    from atlas_admin.school_cooking_group_memberships where school_id=v_school_id;
  if v_group_id is null then
    delete from atlas_admin.school_cooking_group_memberships where school_id=v_school_id;
  else
    insert into atlas_admin.school_cooking_group_memberships(school_id,cooking_group_id)
      values(v_school_id,v_group_id) on conflict(school_id) do update
      set cooking_group_id=excluded.cooking_group_id;
  end if;
  update atlas_admin.schools set version=version+1,updated_at=transaction_timestamp() where school_id=v_school_id;
  return atlas_core.rmvp_01_finish_success(request,v_actor,v_receipt,'SchoolCookingGroupSet',
    'School',v_school_id,v_school.version,v_school.version+1,
    coalesce(v_before,jsonb_build_object('cooking_group_id',null)),
    jsonb_build_object('cooking_group_id',v_group_id),'School cooking group saved.',
    jsonb_build_object('school_id',v_school_id));
exception when serialization_failure or deadlock_detected then
  return atlas_core.pa_05b_command_error(request,'RETRYABLE_CONCURRENCY_FAILURE','Retry the exact School assignment request.','ADMIN',v_name,true);
when others then
  return atlas_core.pa_05b_command_error(request,'INTERNAL_COMMAND_FAILURE','School cooking assignment could not be saved safely.','ADMIN',v_name);
end;
$$;

reset role;
set role atlas_owner;
revoke create on schema atlas_api from atlas_read_runtime,atlas_master_data_command_runtime;
set role atlas_owner;
alter table atlas_dispatch.school_dispatch_releases
  add column cooking_location_id_snapshot uuid,
  add column cooking_location_name_snapshot text,
  add column cooking_location_kind_snapshot text,
  add column cooking_location_host_school_id_snapshot uuid,
  add column dispatch_group_id_snapshot uuid,
  add column dispatch_group_name_snapshot text,
  add constraint dispatch_location_snapshot_check check (
    (cooking_location_id_snapshot is null and cooking_location_name_snapshot is null
      and cooking_location_kind_snapshot is null and cooking_location_host_school_id_snapshot is null)
    or (cooking_location_id_snapshot is not null and cooking_location_name_snapshot is not null
      and ((cooking_location_kind_snapshot is null and cooking_location_host_school_id_snapshot is null)
      or (cooking_location_kind_snapshot is not distinct from 'SCHOOL' and cooking_location_host_school_id_snapshot is not null)
      or (cooking_location_kind_snapshot is not distinct from 'COMPANY' and cooking_location_host_school_id_snapshot is null)))),
  add constraint dispatch_group_snapshot_check check (
    (dispatch_group_id_snapshot is null and dispatch_group_name_snapshot is null)
    or (dispatch_group_id_snapshot is not null and dispatch_group_name_snapshot is not null));

-- Only the command runtime can lock authoritative Admin facts. This private
-- helper takes School locks first, then sorted cooking/Dispatch group locks.
-- Assignment guards take the same School lock; rename/deactivation locks groups.
create function atlas_core.lock_school_document_group_facts(p_school_ids uuid[])
returns void language plpgsql volatile security definer set search_path='' as $$
begin
  perform school_id from atlas_admin.schools where school_id=any(p_school_ids) order by school_id for share;
  perform cg.cooking_group_id from atlas_admin.cooking_groups cg
    where exists(select 1 from atlas_admin.school_cooking_group_memberships m
      where m.school_id=any(p_school_ids) and m.cooking_group_id=cg.cooking_group_id)
    order by cg.cooking_group_id for share;
  perform dg.dispatch_group_id from atlas_admin.dispatch_groups dg
    where exists(select 1 from atlas_admin.dispatch_group_members m
      where m.school_id=any(p_school_ids) and m.dispatch_group_id=dg.dispatch_group_id)
    order by dg.dispatch_group_id for share;
end;
$$;
revoke execute on function atlas_core.lock_school_document_group_facts(uuid[]) from public,anon,authenticated,service_role;
grant execute on function atlas_core.lock_school_document_group_facts(uuid[]) to atlas_read_runtime,atlas_procurement_command_runtime;
grant create on schema atlas_core to atlas_master_data_command_runtime;
reset role;
alter function atlas_core.lock_school_document_group_facts(uuid[]) owner to atlas_master_data_command_runtime;
set role atlas_owner;
revoke create on schema atlas_core from atlas_master_data_command_runtime;

grant create on schema atlas_core,atlas_api to atlas_read_runtime;
reset role;
set role atlas_read_runtime;
do $amend$
declare d text; old text; replacement text;
begin
  d:=pg_get_functiondef('atlas_api.get_school_master_data(jsonb)'::regprocedure);
  old:=$o$'cooking_group_name', cg.cooking_group_name,$o$;
  replacement:=old||$n$
        'cooking_location_id',cg.cooking_group_id,'cooking_location_name',cg.cooking_group_name,
        'cooking_location_kind',cg.location_kind,'cooking_location_host_school_id',cg.host_school_id,
        'dispatch_group_id',dg.dispatch_group_id,'dispatch_group_name',dg.dispatch_group_name,$n$;
  if strpos(d,old)=0 then raise exception 'School canonical fields anchor missing'; end if;
  d:=replace(d,old,replacement);
  old:='left join atlas_admin.cooking_groups cg on cg.cooking_group_id=cgm.cooking_group_id';
  replacement:=old||' left join atlas_admin.dispatch_group_members dgm on dgm.school_id=s.school_id left join atlas_admin.dispatch_groups dg on dg.dispatch_group_id=dgm.dispatch_group_id';
  if strpos(d,old)=0 then raise exception 'School Dispatch join anchor missing'; end if;
  execute replace(d,old,replacement);

  d:=pg_get_functiondef('atlas_core.school_catering_po_school_breakdown(uuid)'::regprocedure);
  old:='cg.cooking_group_id,cg.cooking_group_name';
  if strpos(d,old)=0 then raise exception 'PO canonical grouping anchor missing'; end if;
  d:=replace(d,old,old||',cg.location_kind,cg.host_school_id,dg.dispatch_group_id,dg.dispatch_group_name');
  old:='left join atlas_admin.cooking_groups cg on cg.cooking_group_id=cgm.cooking_group_id';
  d:=replace(d,old,old||' left join atlas_admin.dispatch_group_members dgm on dgm.school_id=school.school_id left join atlas_admin.dispatch_groups dg on dg.dispatch_group_id=dgm.dispatch_group_id');
  old:=$o$'cooking_group_name',cooking_group_name,$o$;
  if strpos(d,old)=0 then raise exception 'PO canonical JSON anchor missing'; end if;
  execute replace(d,old,old||$n$
    'cooking_location_id',cooking_group_id,'cooking_location_name',cooking_group_name,
    'cooking_location_kind',location_kind,'cooking_location_host_school_id',host_school_id,
    'dispatch_group_id',dispatch_group_id,'dispatch_group_name',dispatch_group_name,$n$);

  d:=pg_get_functiondef('atlas_core.freeze_school_dispatch_header_output()'::regprocedure);
  old:='begin';
  d:=replace(d,old,old||' perform atlas_core.lock_school_document_group_facts(array[new.school_id]);');
  old:=' return new;';
  if strpos(d,old)=0 then raise exception 'PXK canonical capture anchor missing'; end if;
  execute replace(d,old,$n$
  new.cooking_location_id_snapshot:=new.cooking_group_id_snapshot;
  new.cooking_location_name_snapshot:=new.cooking_group_name_snapshot;
  select cg.location_kind,cg.host_school_id into new.cooking_location_kind_snapshot,new.cooking_location_host_school_id_snapshot
    from atlas_admin.cooking_groups cg where cg.cooking_group_id=new.cooking_group_id_snapshot;
  select dg.dispatch_group_id,dg.dispatch_group_name into new.dispatch_group_id_snapshot,new.dispatch_group_name_snapshot
    from atlas_admin.dispatch_group_members m join atlas_admin.dispatch_groups dg using(dispatch_group_id)
    where m.school_id=new.school_id;
  return new;$n$);

  d:=pg_get_functiondef('atlas_core.school_dispatch_release_json(uuid)'::regprocedure);
  old:=$o$'cooking_group_name',release.cooking_group_name_snapshot,$o$;
  if strpos(d,old)=0 then raise exception 'PXK canonical read anchor missing'; end if;
  execute replace(d,old,old||$n$
    'cooking_location_id',release.cooking_location_id_snapshot,
    'cooking_location_name',release.cooking_location_name_snapshot,
    'cooking_location_kind',release.cooking_location_kind_snapshot,
    'cooking_location_host_school_id',release.cooking_location_host_school_id_snapshot,
    'dispatch_group_id',release.dispatch_group_id_snapshot,'dispatch_group_name',release.dispatch_group_name_snapshot,$n$);
end;
$amend$;
reset role;
set role atlas_owner;
revoke create on schema atlas_core,atlas_api from atlas_read_runtime;
grant create on schema atlas_core to atlas_procurement_command_runtime;
reset role;
set role atlas_procurement_command_runtime;
do $capture_lock$
declare d text; old text;
begin
 d:=pg_get_functiondef('atlas_core.freeze_school_catering_po_line_output()'::regprocedure);
 old:='    new.school_breakdown_snapshot :=';
 if strpos(d,old)=0 then raise exception 'PO capture lock anchor missing'; end if;
 execute replace(d,old,$n$
    perform atlas_core.lock_school_document_group_facts(array(
      select distinct (school->>'school_id')::uuid from jsonb_array_elements(
        atlas_core.school_catering_po_school_breakdown(new.school_catering_allocation_supplier_split_id)) school));
    new.school_breakdown_snapshot :=$n$);
end;
$capture_lock$;
reset role;
set role atlas_owner;
revoke create on schema atlas_core from atlas_procurement_command_runtime;
reset role;
grant atlas_read_runtime,atlas_master_data_command_runtime,atlas_procurement_command_runtime to postgres with set false;
-- Preserve the complete School/location/Dispatch breakdown, including historical null.
set role atlas_owner;
do $po_immutable$
declare d text; old text;
begin
 d:=pg_get_functiondef('atlas_core.guard_po_document_identity_snapshot()'::regprocedure);
 old:='    or new.unit_code_snapshot is distinct from old.unit_code_snapshot then';
 if strpos(d,old)=0 then raise exception 'PO School immutability anchor missing'; end if;
 execute replace(d,old,'    or new.unit_code_snapshot is distinct from old.unit_code_snapshot'
   ||' or new.school_breakdown_snapshot is distinct from old.school_breakdown_snapshot then');
end;
$po_immutable$;
create trigger guard_po_school_breakdown_snapshot before update of school_breakdown_snapshot
  on atlas_procurement.purchase_order_line_revisions for each row
  execute function atlas_core.guard_po_document_identity_snapshot();
reset role;
-- Forward rollback disables new maintenance/exposure and retains current/frozen evidence.
