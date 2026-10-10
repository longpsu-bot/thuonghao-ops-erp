-- Owner-authorized Document System Class C amendment: one current cooking fact.
-- No dating/history model; released documents retain their own immutable snapshots.
reset role;
grant atlas_owner,atlas_master_data_command_runtime,atlas_read_runtime to postgres with set true;
set role atlas_owner;

create table atlas_admin.cooking_groups (
  cooking_group_id uuid primary key default gen_random_uuid(),
  cooking_group_name text not null check (
    cooking_group_name=btrim(cooking_group_name)
    and char_length(cooking_group_name) between 1 and 200),
  active boolean not null default true,
  version bigint not null default 1 check(version>0),
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp()
);
create table atlas_admin.school_cooking_group_memberships (
  school_id uuid primary key references atlas_admin.schools(school_id),
  cooking_group_id uuid not null references atlas_admin.cooking_groups(cooking_group_id)
);
create index school_cooking_group_memberships_group_idx
  on atlas_admin.school_cooking_group_memberships(cooking_group_id,school_id);
alter table atlas_admin.cooking_groups enable row level security;
alter table atlas_admin.cooking_groups force row level security;
alter table atlas_admin.school_cooking_group_memberships enable row level security;
alter table atlas_admin.school_cooking_group_memberships force row level security;
revoke all on atlas_admin.cooking_groups,atlas_admin.school_cooking_group_memberships
  from public,anon,authenticated,service_role;
grant select on atlas_admin.cooking_groups,atlas_admin.school_cooking_group_memberships
  to atlas_read_runtime,atlas_master_data_command_runtime;
grant insert(cooking_group_name,active),update(cooking_group_name,active,version,updated_at)
  on atlas_admin.cooking_groups to atlas_master_data_command_runtime;
grant insert,update,delete on atlas_admin.school_cooking_group_memberships
  to atlas_master_data_command_runtime;
create policy cooking_group_read on atlas_admin.cooking_groups
  for select to atlas_read_runtime using(true);
create policy cooking_group_command_read on atlas_admin.cooking_groups
  for select to atlas_master_data_command_runtime using(true);
create policy cooking_group_command_insert on atlas_admin.cooking_groups
  for insert to atlas_master_data_command_runtime with check(true);
create policy cooking_group_command_update on atlas_admin.cooking_groups
  for update to atlas_master_data_command_runtime using(true) with check(true);
create policy cooking_membership_read on atlas_admin.school_cooking_group_memberships
  for select to atlas_read_runtime using(true);
create policy cooking_membership_command_read on atlas_admin.school_cooking_group_memberships
  for select to atlas_master_data_command_runtime using(true);
create policy cooking_membership_command_insert on atlas_admin.school_cooking_group_memberships
  for insert to atlas_master_data_command_runtime with check(true);
create policy cooking_membership_command_update on atlas_admin.school_cooking_group_memberships
  for update to atlas_master_data_command_runtime using(true) with check(true);
create policy cooking_membership_command_delete on atlas_admin.school_cooking_group_memberships
  for delete to atlas_master_data_command_runtime using(true);

-- Row locks serialize assignment with School/group deactivation. School first,
-- then target group; deactivation never takes School locks after group locks.
create function atlas_core.guard_school_cooking_group_membership() returns trigger
language plpgsql security definer set search_path='' as $$
declare v_status text; v_active boolean;
begin
  select school_status into v_status from atlas_admin.schools
    where school_id=new.school_id for update;
  if v_status is distinct from 'ACTIVE' then
    raise exception using errcode='23514',message='Cooking membership requires an active School.';
  end if;
  select active into v_active from atlas_admin.cooking_groups
    where cooking_group_id=new.cooking_group_id for update;
  if v_active is distinct from true then
    raise exception using errcode='23514',message='Cooking membership requires an active existing group.';
  end if;
  return new;
end;
$$;
create function atlas_core.guard_cooking_group_deactivation() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
  if not new.active and exists(select 1 from atlas_admin.school_cooking_group_memberships
    where cooking_group_id=new.cooking_group_id) then
    raise exception using errcode='23514',message='Clear or move cooking memberships before deactivation.';
  end if;
  return new;
end;
$$;
create function atlas_core.guard_cooking_school_deactivation() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if new.school_status<>'ACTIVE' and exists(select 1 from atlas_admin.school_cooking_group_memberships
    where school_id=new.school_id) then
    raise exception using errcode='23514',message='Clear cooking membership before School deactivation.';
  end if;
  return new;
end;
$$;
create trigger guard_school_cooking_group_membership before insert or update
  on atlas_admin.school_cooking_group_memberships for each row
  execute function atlas_core.guard_school_cooking_group_membership();
create trigger guard_cooking_group_deactivation before update of active
  on atlas_admin.cooking_groups for each row
  execute function atlas_core.guard_cooking_group_deactivation();
create trigger guard_cooking_school_deactivation before update of school_status
  on atlas_admin.schools for each row
  execute function atlas_core.guard_cooking_school_deactivation();
revoke execute on function atlas_core.guard_school_cooking_group_membership(),
  atlas_core.guard_cooking_group_deactivation(),atlas_core.guard_cooking_school_deactivation()
  from public,anon,authenticated,service_role;
grant create on schema atlas_core to atlas_master_data_command_runtime;
reset role;
alter function atlas_core.guard_school_cooking_group_membership() owner to atlas_master_data_command_runtime;
alter function atlas_core.guard_cooking_school_deactivation() owner to atlas_master_data_command_runtime;
set role atlas_owner;
revoke create on schema atlas_core from atlas_master_data_command_runtime;

create function atlas_api.get_cooking_groups(request jsonb) returns jsonb
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
    'cooking_group_name',cooking_group_name,'active',active,'version',version)
    order by cooking_group_name,cooking_group_id),'[]'::jsonb)
    into v_groups from atlas_admin.cooking_groups;
  return jsonb_build_object('success',true,'contract_version','RMVP-01.v1',
    'correlation_id',request->>'correlation_id','cooking_groups',v_groups);
exception when others then
  return atlas_core.rmvp_01_read_error(request,'get_cooking_groups','INTERNAL_READ_FAILURE','Cooking groups could not be read safely.');
end;
$$;

create function atlas_api.upsert_cooking_group(request jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare
  v_name constant text:='upsert_cooking_group'; v_payload jsonb:=request->'payload';
  v_id uuid; v_group atlas_admin.cooking_groups%rowtype; v_prepare jsonb;
  v_receipt uuid; v_actor uuid; v_before jsonb; v_after jsonb; v_version bigint;
begin
  v_after:=atlas_core.rmvp_01_validate_command_request(request,v_name);
  if v_after is not null then return v_after; end if;
  v_id:=atlas_core.pa_05b_safe_uuid(v_payload->>'cooking_group_id');
  if not (v_payload ?& array['cooking_group_id','cooking_group_name','active'])
    or v_payload - array['cooking_group_id','cooking_group_name','active']<>'{}'::jsonb
    or (v_payload->'cooking_group_id'<>'null'::jsonb and v_id is null)
    or jsonb_typeof(v_payload->'cooking_group_name')<>'string'
    or v_payload->>'cooking_group_name'<>btrim(v_payload->>'cooking_group_name')
    or char_length(v_payload->>'cooking_group_name') not between 1 and 200
    or jsonb_typeof(v_payload->'active')<>'boolean'
    or request->>'reason_code'<>'COOKING_GROUP_SAVED'
    or (v_id is null and (request->>'expected_version')::bigint<>1) then
    return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED','Cooking group fields are invalid.','ADMIN',v_name);
  end if;
  v_prepare:=atlas_core.rmvp_01_prepare_command(request,v_name,'master_data.schools.write',
    'cooking_group:'||coalesce(v_id::text,'new'));
  if v_prepare->>'status'='RETURN' then return v_prepare->'response'; end if;
  v_receipt:=(v_prepare->>'receipt_id')::uuid; v_actor:=(v_prepare->>'actor_id')::uuid;
  if v_id is null then
    v_version:=null; v_before:='{}'::jsonb;
    insert into atlas_admin.cooking_groups(cooking_group_name,active)
      values(v_payload->>'cooking_group_name',(v_payload->>'active')::boolean)
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
    v_before:=jsonb_build_object('cooking_group_name',v_group.cooking_group_name,'active',v_group.active);
    update atlas_admin.cooking_groups set cooking_group_name=v_payload->>'cooking_group_name',
      active=(v_payload->>'active')::boolean,version=version+1,updated_at=transaction_timestamp()
      where cooking_group_id=v_id;
  end if;
  v_after:=jsonb_build_object('cooking_group_id',v_id,'cooking_group_name',v_payload->>'cooking_group_name',
    'active',(v_payload->>'active')::boolean);
  return atlas_core.rmvp_01_finish_success(request,v_actor,v_receipt,'CookingGroupSaved',
    'CookingGroup',v_id,v_version,coalesce(v_version,0)+1,v_before,v_after,'Cooking group saved.',
    jsonb_build_object('cooking_group_id',v_id));
exception when serialization_failure or deadlock_detected then
  return atlas_core.pa_05b_command_error(request,'RETRYABLE_CONCURRENCY_FAILURE','Retry the exact cooking group request.','ADMIN',v_name,true);
when others then
  return atlas_core.pa_05b_command_error(request,'INTERNAL_COMMAND_FAILURE','Cooking group could not be saved safely.','ADMIN',v_name);
end;
$$;

create function atlas_api.set_school_cooking_group(request jsonb) returns jsonb
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

revoke execute on function atlas_api.get_cooking_groups(jsonb),atlas_api.upsert_cooking_group(jsonb),
  atlas_api.set_school_cooking_group(jsonb) from public,anon,authenticated,service_role;
grant execute on function atlas_api.get_cooking_groups(jsonb),atlas_api.upsert_cooking_group(jsonb),
  atlas_api.set_school_cooking_group(jsonb) to authenticated;
grant create on schema atlas_api to atlas_read_runtime,atlas_master_data_command_runtime;
reset role;
alter function atlas_api.get_cooking_groups(jsonb) owner to atlas_read_runtime;
alter function atlas_api.upsert_cooking_group(jsonb) owner to atlas_master_data_command_runtime;
alter function atlas_api.set_school_cooking_group(jsonb) owner to atlas_master_data_command_runtime;
set role atlas_owner;
revoke create on schema atlas_api from atlas_read_runtime,atlas_master_data_command_runtime;

alter table atlas_dispatch.school_dispatch_releases
  add column cooking_group_id_snapshot uuid,
  add column cooking_group_name_snapshot text,
  add constraint school_dispatch_cooking_group_snapshot_check check (
    (cooking_group_id_snapshot is null and cooking_group_name_snapshot is null)
    or (cooking_group_id_snapshot is not null and cooking_group_name_snapshot is not null
      and cooking_group_name_snapshot=btrim(cooking_group_name_snapshot)
      and char_length(cooking_group_name_snapshot) between 1 and 200));

-- Preserve existing authority, validation, labels, precision and execution owners.
-- Fail migration if an upstream definition no longer matches the reviewed anchor.
grant create on schema atlas_api,atlas_core to atlas_read_runtime;
reset role;
set role atlas_read_runtime;
do $amend$
declare v_definition text; v_old text; v_new text;
begin
  v_definition:=pg_get_functiondef('atlas_api.get_school_master_data(jsonb)'::regprocedure);
  v_old:=$old$'school_status', s.school_status,$old$;
  v_new:=$new$'school_status', s.school_status,
        'cooking_group_id', cg.cooking_group_id,
        'cooking_group_name', cg.cooking_group_name,$new$;
  if strpos(v_definition,v_old)=0 then raise exception 'School read cooking anchor missing'; end if;
  v_definition:=replace(v_definition,v_old,v_new);
  v_old:='from atlas_admin.schools s';
  v_new:='from atlas_admin.schools s left join atlas_admin.school_cooking_group_memberships cgm on cgm.school_id=s.school_id left join atlas_admin.cooking_groups cg on cg.cooking_group_id=cgm.cooking_group_id';
  if strpos(v_definition,v_old)=0 then raise exception 'School read FROM anchor missing'; end if;
  execute replace(v_definition,v_old,v_new);

  v_definition:=pg_get_functiondef('atlas_core.school_catering_po_school_breakdown(uuid)'::regprocedure);
  v_old:='coverage.delivery_location_id,location.location_name';
  v_new:='coverage.delivery_location_id,location.location_name,cg.cooking_group_id,cg.cooking_group_name';
  if strpos(v_definition,v_old)=0 then raise exception 'PO grouping cooking anchor missing'; end if;
  v_definition:=replace(v_definition,v_old,v_new);
  v_old:='join atlas_admin.schools school on school.school_id=coverage.school_id';
  v_new:=v_old||' left join atlas_admin.school_cooking_group_memberships cgm on cgm.school_id=school.school_id left join atlas_admin.cooking_groups cg on cg.cooking_group_id=cgm.cooking_group_id';
  if strpos(v_definition,v_old)=0 then raise exception 'PO School join anchor missing'; end if;
  v_definition:=replace(v_definition,v_old,v_new);
  v_old:=$old$'school_display_order',display_order,$old$;
  v_new:=$new$'school_display_order',display_order,
    'cooking_group_id',cooking_group_id,'cooking_group_name',cooking_group_name,$new$;
  if strpos(v_definition,v_old)=0 then raise exception 'PO JSON cooking anchor missing'; end if;
  execute replace(v_definition,v_old,v_new);

  v_definition:=pg_get_functiondef('atlas_core.freeze_school_dispatch_header_output()'::regprocedure);
  v_old:='  return new;';
  v_new:='  select cg.cooking_group_id,cg.cooking_group_name into new.cooking_group_id_snapshot,new.cooking_group_name_snapshot from atlas_admin.school_cooking_group_memberships cgm join atlas_admin.cooking_groups cg using(cooking_group_id) where cgm.school_id=new.school_id; return new;';
  if strpos(v_definition,v_old)=0 then raise exception 'PXK header cooking anchor missing'; end if;
  execute replace(v_definition,v_old,v_new);

  v_definition:=pg_get_functiondef('atlas_core.school_dispatch_release_json(uuid)'::regprocedure);
  v_old:=$old$'school_name',release.school_name_snapshot,$old$;
  v_new:=$new$'school_name',release.school_name_snapshot,
    'cooking_group_id',release.cooking_group_id_snapshot,
    'cooking_group_name',release.cooking_group_name_snapshot,$new$;
  if strpos(v_definition,v_old)=0 then raise exception 'PXK read cooking anchor missing'; end if;
  execute replace(v_definition,v_old,v_new);
end;
$amend$;
reset role;
set role atlas_owner;
revoke create on schema atlas_api,atlas_core from atlas_read_runtime;
reset role;
grant atlas_read_runtime,atlas_master_data_command_runtime to postgres with set false;
-- No adoption/backfill: existing released cooking snapshots remain null/absent.
-- Forward rollback disables commands/exports while retaining membership and frozen data.
