-- DIRECT-INGREDIENT-NEED-CONVERGENCE-01
-- Explicit School/date composition authority on the existing Pantry source.
-- Historical snapshots without this evidence remain ADDITIVE by definition.

reset role;
grant atlas_owner, atlas_read_runtime, atlas_planning_command_runtime,
  atlas_need_generation_runtime to postgres with set true;
set role atlas_owner;
grant usage, create on schema atlas_core, atlas_api
to atlas_need_generation_runtime;
grant usage, create on schema atlas_core to atlas_read_runtime;

create table atlas_planning.pantry_need_school_date_modes (
  pantry_need_batch_id uuid not null,
  school_id uuid not null,
  service_date date not null,
  direct_need_mode text not null,
  updated_by_actor_id uuid not null,
  updated_at timestamptz not null default transaction_timestamp(),
  constraint pantry_need_school_date_modes_pkey primary key (
    pantry_need_batch_id, school_id, service_date
  ),
  constraint pantry_need_school_date_modes_batch_fkey foreign key (
    pantry_need_batch_id
  ) references atlas_planning.pantry_need_batches (
    pantry_need_batch_id
  ) on delete restrict,
  constraint pantry_need_school_date_modes_school_fkey foreign key (
    school_id
  ) references atlas_admin.schools (school_id) on delete restrict,
  constraint pantry_need_school_date_modes_actor_fkey foreign key (
    updated_by_actor_id
  ) references atlas_core.actors (actor_id) on delete restrict,
  constraint pantry_need_school_date_modes_mode_check check (
    direct_need_mode in ('ADDITIVE', 'COMPLETE')
  )
);

create index pantry_need_school_date_modes_school_date_idx
  on atlas_planning.pantry_need_school_date_modes (school_id, service_date);
create index pantry_need_school_date_modes_actor_idx
  on atlas_planning.pantry_need_school_date_modes (updated_by_actor_id);

create table atlas_planning.pantry_need_approval_snapshot_school_date_modes (
  pantry_need_approval_snapshot_id uuid not null,
  pantry_need_batch_id uuid not null,
  school_id uuid not null,
  service_date date not null,
  direct_need_mode text not null,
  constraint pantry_need_approval_snapshot_school_date_modes_pkey primary key (
    pantry_need_approval_snapshot_id, school_id, service_date
  ),
  constraint pantry_need_snapshot_school_date_modes_snapshot_fkey foreign key (
    pantry_need_approval_snapshot_id, pantry_need_batch_id
  ) references atlas_planning.pantry_need_approval_snapshots (
    pantry_need_approval_snapshot_id, pantry_need_batch_id
  ) on delete restrict,
  constraint pantry_need_snapshot_school_date_modes_school_fkey foreign key (
    school_id
  ) references atlas_admin.schools (school_id) on delete restrict,
  constraint pantry_need_snapshot_school_date_modes_mode_check check (
    direct_need_mode in ('ADDITIVE', 'COMPLETE')
  )
);

create index pantry_need_snapshot_school_date_modes_batch_idx
  on atlas_planning.pantry_need_approval_snapshot_school_date_modes (
    pantry_need_batch_id, service_date, school_id
  );

alter table atlas_planning.pantry_need_school_date_modes
  enable row level security;
alter table atlas_planning.pantry_need_school_date_modes
  force row level security;
alter table atlas_planning.pantry_need_approval_snapshot_school_date_modes
  enable row level security;
alter table atlas_planning.pantry_need_approval_snapshot_school_date_modes
  force row level security;

create policy direct_need_mode_owner_all
  on atlas_planning.pantry_need_school_date_modes
  for all to atlas_owner using (true) with check (true);
create policy direct_need_mode_runtime_select
  on atlas_planning.pantry_need_school_date_modes
  for select to atlas_read_runtime, atlas_planning_command_runtime,
    atlas_need_generation_runtime using (true);
create policy direct_need_snapshot_mode_owner_all
  on atlas_planning.pantry_need_approval_snapshot_school_date_modes
  for all to atlas_owner using (true) with check (true);
create policy direct_need_snapshot_mode_runtime_select
  on atlas_planning.pantry_need_approval_snapshot_school_date_modes
  for select to atlas_read_runtime, atlas_planning_command_runtime,
    atlas_need_generation_runtime using (true);

revoke all on table
  atlas_planning.pantry_need_school_date_modes,
  atlas_planning.pantry_need_approval_snapshot_school_date_modes
from public, anon, authenticated, service_role;
grant select on table
  atlas_planning.pantry_need_school_date_modes,
  atlas_planning.pantry_need_approval_snapshot_school_date_modes
to atlas_read_runtime, atlas_planning_command_runtime,
  atlas_need_generation_runtime;

create function atlas_core.direct_need_canonical_modes(
  target_week_start date,
  canonical_rows jsonb,
  supplied_modes jsonb
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  if target_week_start is null
    or extract(isodow from target_week_start) <> 1
    or jsonb_typeof(canonical_rows) <> 'array'
    or jsonb_typeof(supplied_modes) <> 'array'
    or exists (
      select 1 from jsonb_array_elements(supplied_modes) item
      where jsonb_typeof(item) <> 'object'
        or item - array['school_id','service_date','direct_need_mode'] <> '{}'::jsonb
        or not (item ?& array['school_id','service_date','direct_need_mode'])
        or atlas_core.pa_05b_safe_uuid(item ->> 'school_id') is null
        or atlas_core.pa_05d_safe_date(item ->> 'service_date') is null
        or atlas_core.pa_05d_safe_date(item ->> 'service_date')
          not between target_week_start and target_week_start + 6
        or item ->> 'direct_need_mode' not in ('ADDITIVE','COMPLETE')
    )
  then
    return null;
  end if;

  with represented as (
    select distinct
      atlas_core.pa_05b_safe_uuid(row_value ->> 'school_id') school_id,
      atlas_core.pa_05d_safe_date(row_value ->> 'service_date') service_date
    from jsonb_array_elements(canonical_rows) row_value
    where atlas_core.pantry_02_safe_quantity(
      row_value ->> 'requested_quantity'
    ) > 0
  ), proposed as (
    select
      atlas_core.pa_05b_safe_uuid(item ->> 'school_id') school_id,
      atlas_core.pa_05d_safe_date(item ->> 'service_date') service_date,
      item ->> 'direct_need_mode' direct_need_mode
    from jsonb_array_elements(supplied_modes) item
  ), invalid as (
    select 1 from proposed
    group by school_id, service_date having count(*) <> 1
    union all
    select 1 from (
      (select school_id, service_date from represented
       except select school_id, service_date from proposed)
      union all
      (select school_id, service_date from proposed
       except select school_id, service_date from represented)
    ) difference
  )
  select case when exists(select 1 from invalid) then null
    else coalesce(jsonb_agg(jsonb_build_object(
      'school_id', proposed.school_id,
      'service_date', proposed.service_date,
      'direct_need_mode', proposed.direct_need_mode
    ) order by proposed.service_date, proposed.school_id), '[]'::jsonb)
    end
  into v_result
  from proposed;

  return v_result;
end;
$$;

create function atlas_core.direct_need_modes_match(
  target_batch_id uuid,
  canonical_modes jsonb
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  with supplied as (
    select (item->>'school_id')::uuid school_id,
      (item->>'service_date')::date service_date,
      item->>'direct_need_mode' direct_need_mode
    from jsonb_array_elements(canonical_modes) item
  ), stored as (
    select school_id, service_date, direct_need_mode
    from atlas_planning.pantry_need_school_date_modes
    where pantry_need_batch_id = target_batch_id
  )
  select not exists (
    (select * from supplied except select * from stored)
    union all
    (select * from stored except select * from supplied)
  );
$$;

create function atlas_core.direct_need_replace_modes(
  target_week_start date,
  canonical_rows jsonb,
  supplied_modes jsonb,
  actor_id uuid
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_batch_id uuid;
  v_modes jsonb := atlas_core.direct_need_canonical_modes(
    target_week_start, canonical_rows, supplied_modes
  );
begin
  if v_modes is null or actor_id is null then
    raise exception using errcode='22023',
      message='Direct Need School/date modes are invalid.';
  end if;
  select pantry_need_batch_id into v_batch_id
  from atlas_planning.pantry_need_batches
  where week_start=target_week_start for update;
  if v_batch_id is null then
    raise exception using errcode='23503',
      message='Direct Need modes require their Pantry batch.';
  end if;

  delete from atlas_planning.pantry_need_school_date_modes
  where pantry_need_batch_id=v_batch_id;
  insert into atlas_planning.pantry_need_school_date_modes(
    pantry_need_batch_id,school_id,service_date,direct_need_mode,
    updated_by_actor_id,updated_at
  )
  select v_batch_id,(item->>'school_id')::uuid,(item->>'service_date')::date,
    item->>'direct_need_mode',actor_id,transaction_timestamp()
  from jsonb_array_elements(v_modes) item;
  return v_modes;
end;
$$;

create function atlas_core.direct_need_effective_mode(
  snapshot_id uuid,
  target_school_id uuid,
  target_service_date date
)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select mode.direct_need_mode
    from atlas_planning.pantry_need_approval_snapshot_school_date_modes mode
    where mode.pantry_need_approval_snapshot_id=snapshot_id
      and mode.school_id=target_school_id
      and mode.service_date=target_service_date
  ),'ADDITIVE');
$$;

create function atlas_core.direct_need_snapshot_complete_only(
  snapshot_id uuid,
  target_service_date date
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select snapshot_id is not null
    and exists (
      select 1
      from atlas_planning.pantry_need_approval_snapshot_lines line
      where line.pantry_need_approval_snapshot_id=snapshot_id
        and line.service_date=target_service_date
        and line.requested_quantity>0
    )
    and not exists (
      select 1
      from atlas_planning.pantry_need_approval_snapshot_lines line
      where line.pantry_need_approval_snapshot_id=snapshot_id
        and line.service_date=target_service_date
        and line.requested_quantity>0
        and atlas_core.direct_need_effective_mode(
          snapshot_id,line.school_id,line.service_date
        )<>'COMPLETE'
    );
$$;

create function atlas_core.direct_need_snapshot_fingerprint(
  snapshot_id uuid,
  target_service_date date
)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select md5(coalesce(jsonb_agg(jsonb_build_object(
    'pantry_need_line_id',line.pantry_need_line_id,
    'school_id',line.school_id,'service_date',line.service_date,
    'delivery_location_id',line.delivery_location_id,
    'ingredient_id',line.ingredient_id,'unit_id',line.unit_id,
    'purpose_id',line.pantry_need_purpose_id,
    'quantity',line.requested_quantity,'note',line.note,
    'direct_need_mode',atlas_core.direct_need_effective_mode(
      snapshot_id,line.school_id,line.service_date
    )
  ) order by line.school_id,line.delivery_location_id,line.ingredient_id,
    line.unit_id,line.pantry_need_line_id),'[]'::jsonb)::text)
  from atlas_planning.pantry_need_approval_snapshot_lines line
  where line.pantry_need_approval_snapshot_id=snapshot_id
    and line.service_date=target_service_date;
$$;

create function atlas_core.direct_need_current_complete_source(
  target_service_date date
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'pantry_need_batch_id',batch.pantry_need_batch_id,
    'pantry_need_batch_version',batch.version,
    'pantry_need_approval_snapshot_id',batch.latest_approval_snapshot_id,
    'source_fingerprint',atlas_core.direct_need_snapshot_fingerprint(
      batch.latest_approval_snapshot_id,target_service_date
    )
  )
  from atlas_planning.pantry_need_batches batch
  where batch.pantry_need_batch_status='APPROVED'
    and target_service_date between batch.week_start and batch.week_end
    and atlas_core.direct_need_snapshot_complete_only(
      batch.latest_approval_snapshot_id,target_service_date
    );
$$;

create function atlas_core.direct_need_evaluation_ready(
  target_evaluation_id uuid,
  target_period_start date,
  target_period_end date
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  e atlas_planning.planning_input_evaluations%rowtype;
  v_catering boolean;
  v_direct boolean;
begin
  select * into e from atlas_planning.planning_input_evaluations
  where planning_input_evaluation_id=target_evaluation_id;
  if e.planning_input_evaluation_id is null
    or e.evaluation_result<>'READY' or e.blocking_issue_count<>0
    or target_period_start is null or target_period_end is null
  then return false; end if;

  v_catering := e.weekly_menu_id is not null
    and e.weekly_menu_version is not null
    and e.weekly_menu_approval_snapshot_id is not null
    and e.attendance_batch_id is not null
    and e.attendance_version is not null
    and e.attendance_approval_snapshot_id is not null
    and e.pantry_need_batch_id is not null
    and exists(select 1 from atlas_planning.weekly_menus menu
      where menu.weekly_menu_id=e.weekly_menu_id
        and menu.version=e.weekly_menu_version
        and menu.latest_approval_snapshot_id=e.weekly_menu_approval_snapshot_id
        and menu.weekly_menu_status in ('APPROVED','NEED_GENERATION_REQUESTED')
        and menu.week_start<=target_period_start and menu.week_end>=target_period_end)
    and exists(select 1 from atlas_planning.attendance_batches attendance
      where attendance.attendance_batch_id=e.attendance_batch_id
        and attendance.version=e.attendance_version
        and attendance.latest_approval_snapshot_id=e.attendance_approval_snapshot_id
        and attendance.attendance_status in ('APPROVED','USED_FOR_NEED_GENERATION')
        and attendance.period_start<=target_period_start
        and attendance.period_end>=target_period_end)
    and exists(select 1 from atlas_planning.pantry_need_batches pantry
      join atlas_planning.pantry_need_approval_snapshots pantry_snapshot
        on pantry_snapshot.pantry_need_approval_snapshot_id=
          e.pantry_need_approval_snapshot_id
       and pantry_snapshot.pantry_need_batch_id=pantry.pantry_need_batch_id
       and pantry_snapshot.approved_batch_version=pantry.version
      where pantry.pantry_need_batch_id=e.pantry_need_batch_id
        and pantry.version=e.pantry_need_batch_version
        and pantry.latest_approval_snapshot_id=e.pantry_need_approval_snapshot_id
        and pantry.pantry_need_batch_status='APPROVED'
        and pantry.week_start<=target_period_start and pantry.week_end>=target_period_end
        and pantry_snapshot.line_count=(select count(*)
          from atlas_planning.pantry_need_approval_snapshot_lines pantry_member
          where pantry_member.pantry_need_approval_snapshot_id=
            pantry_snapshot.pantry_need_approval_snapshot_id));

  v_direct := target_period_start=target_period_end
    and e.weekly_menu_id is null
    and e.weekly_menu_version is null
    and e.weekly_menu_approval_snapshot_id is null
    and e.attendance_batch_id is null
    and e.attendance_version is null
    and e.attendance_approval_snapshot_id is null
    and e.pantry_need_batch_id is not null
    and exists(select 1 from atlas_planning.pantry_need_batches pantry
      join atlas_planning.pantry_need_approval_snapshots pantry_snapshot
        on pantry_snapshot.pantry_need_approval_snapshot_id=
          e.pantry_need_approval_snapshot_id
       and pantry_snapshot.pantry_need_batch_id=pantry.pantry_need_batch_id
       and pantry_snapshot.approved_batch_version=pantry.version
      where pantry.pantry_need_batch_id=e.pantry_need_batch_id
        and pantry.version=e.pantry_need_batch_version
        and pantry.latest_approval_snapshot_id=e.pantry_need_approval_snapshot_id
        and pantry.pantry_need_batch_status='APPROVED'
        and pantry.week_start<=target_period_start and pantry.week_end>=target_period_end
        and pantry_snapshot.line_count=(select count(*)
          from atlas_planning.pantry_need_approval_snapshot_lines pantry_member
          where pantry_member.pantry_need_approval_snapshot_id=
            pantry_snapshot.pantry_need_approval_snapshot_id)
        and atlas_core.direct_need_snapshot_complete_only(
          pantry.latest_approval_snapshot_id,target_period_start));
  return v_catering or v_direct;
end;
$$;

reset role;
alter function atlas_core.direct_need_modes_match(uuid,jsonb)
  owner to atlas_read_runtime;
alter function atlas_core.direct_need_effective_mode(uuid,uuid,date)
  owner to atlas_read_runtime;
alter function atlas_core.direct_need_snapshot_complete_only(uuid,date)
  owner to atlas_read_runtime;
alter function atlas_core.direct_need_snapshot_fingerprint(uuid,date)
  owner to atlas_read_runtime;
alter function atlas_core.direct_need_current_complete_source(date)
  owner to atlas_read_runtime;
alter function atlas_core.direct_need_evaluation_ready(uuid,date,date)
  owner to atlas_read_runtime;

set role atlas_read_runtime;
revoke all on function
  atlas_core.direct_need_modes_match(uuid,jsonb),
  atlas_core.direct_need_effective_mode(uuid,uuid,date),
  atlas_core.direct_need_snapshot_complete_only(uuid,date),
  atlas_core.direct_need_snapshot_fingerprint(uuid,date),
  atlas_core.direct_need_current_complete_source(date),
  atlas_core.direct_need_evaluation_ready(uuid,date,date)
from public, anon, authenticated, service_role, atlas_command_runtime;
grant execute on function
  atlas_core.direct_need_modes_match(uuid,jsonb),
  atlas_core.direct_need_effective_mode(uuid,uuid,date),
  atlas_core.direct_need_snapshot_complete_only(uuid,date),
  atlas_core.direct_need_snapshot_fingerprint(uuid,date),
  atlas_core.direct_need_current_complete_source(date),
  atlas_core.direct_need_evaluation_ready(uuid,date,date)
to atlas_planning_command_runtime, atlas_need_generation_runtime;

set role atlas_owner;

revoke all on function
  atlas_core.direct_need_canonical_modes(date,jsonb,jsonb),
  atlas_core.direct_need_replace_modes(date,jsonb,jsonb,uuid)
from public, anon, authenticated, service_role;
grant execute on function
  atlas_core.direct_need_canonical_modes(date,jsonb,jsonb)
to atlas_read_runtime, atlas_planning_command_runtime,
  atlas_need_generation_runtime;
grant execute on function
  atlas_core.direct_need_replace_modes(date,jsonb,jsonb,uuid)
to atlas_planning_command_runtime;

create function atlas_planning.direct_need_copy_snapshot_modes()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into atlas_planning.pantry_need_approval_snapshot_school_date_modes(
    pantry_need_approval_snapshot_id,pantry_need_batch_id,school_id,
    service_date,direct_need_mode
  )
  select new.pantry_need_approval_snapshot_id,new.pantry_need_batch_id,
    mode.school_id,mode.service_date,mode.direct_need_mode
  from atlas_planning.pantry_need_school_date_modes mode
  where mode.pantry_need_batch_id=new.pantry_need_batch_id;
  return new;
end;
$$;

create function atlas_planning.direct_need_snapshot_mode_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op in ('UPDATE','DELETE') then
    raise exception using errcode='23514',
      message='Approved Direct Need mode evidence is immutable.';
  end if;
  if new.service_date not between (
      select week_start from atlas_planning.pantry_need_batches
      where pantry_need_batch_id=new.pantry_need_batch_id
    ) and (
      select week_end from atlas_planning.pantry_need_batches
      where pantry_need_batch_id=new.pantry_need_batch_id
    )
  then
    raise exception using errcode='23514',
      message='Direct Need mode must belong to its Pantry week.';
  end if;
  return new;
end;
$$;

create trigger pantry_need_snapshot_copy_school_date_modes
after insert on atlas_planning.pantry_need_approval_snapshots
for each row execute function atlas_planning.direct_need_copy_snapshot_modes();
create trigger pantry_need_snapshot_school_date_modes_guard
before insert or update or delete
on atlas_planning.pantry_need_approval_snapshot_school_date_modes
for each row execute function atlas_planning.direct_need_snapshot_mode_guard();

revoke all on function
  atlas_planning.direct_need_copy_snapshot_modes(),
  atlas_planning.direct_need_snapshot_mode_guard()
from public, anon, authenticated, service_role;

-- New generation snapshots may omit Menu and Attendance only as one complete
-- pair. The direct-complete predicate is rechecked by command and integrity
-- guards against the exact Pantry snapshot.
alter table atlas_planning.need_generation_input_snapshots
  alter column weekly_menu_id drop not null,
  alter column weekly_menu_version drop not null,
  alter column weekly_menu_approval_snapshot_id drop not null,
  alter column attendance_batch_id drop not null,
  alter column attendance_version drop not null,
  alter column attendance_approval_snapshot_id drop not null,
  drop constraint need_generation_input_snapshots_menu_version_check,
  drop constraint need_generation_input_snapshots_attendance_version_check,
  add constraint need_generation_input_snapshots_source_composition_check check (
    (
      weekly_menu_id is not null and weekly_menu_version is not null
      and weekly_menu_version>0
      and weekly_menu_approval_snapshot_id is not null
      and attendance_batch_id is not null and attendance_version is not null
      and attendance_version>0
      and attendance_approval_snapshot_id is not null
    ) or (
      weekly_menu_id is null and weekly_menu_version is null
      and weekly_menu_approval_snapshot_id is null
      and attendance_batch_id is null and attendance_version is null
      and attendance_approval_snapshot_id is null
      and pantry_need_batch_id is not null
      and pantry_need_batch_version is not null
      and pantry_need_approval_snapshot_id is not null
    )
  );

-- The readiness lifecycle keeps every existing catering invariant and uses one
-- closed helper for the additional direct-complete alternative.
do $patch_set_guard$
declare
  definition text := pg_get_functiondef(
    'atlas_planning.pa_06e_h0a4b_planning_input_set_guard()'::regprocedure
  );
  anchor integer;
  start_at integer;
  end_at integer;
  ending text := E'    ) into v_request_ready;';
  replacement text := E'    select atlas_core.direct_need_evaluation_ready(\n      old.current_evaluation_id, old.period_start, old.period_end\n    ) into v_request_ready;';
begin
  anchor := position(E'  if old.readiness_status = \'READY\'\n    and new.readiness_status = \'NEED_GENERATION_REQUESTED\'' in definition);
  if anchor=0 then raise exception 'Direct Need expected readiness transition was not found'; end if;
  start_at := anchor-1 + position('    select exists (' in substring(definition from anchor));
  end_at := start_at-1 + position(ending in substring(definition from start_at)) + length(ending)-1;
  if start_at<anchor or end_at<start_at then raise exception 'Direct Need readiness select boundary changed'; end if;
  definition := substring(definition from 1 for start_at-1)
    ||replacement||substring(definition from end_at+1);
  execute definition;
end;
$patch_set_guard$;

do $patch_readiness_integrity$
declare
  definition text := pg_get_functiondef(
    'atlas_planning.pa_06e_h0a4b_planning_input_integrity_guard()'::regprocedure
  );
  anchor integer;
  start_at integer;
  end_at integer;
  ending text := E'\n\n    if v_evaluation.evaluation_result = \'NOT_READY\'';
  replacement text := E'    if v_evaluation.evaluation_result = \'READY\'\n      and not atlas_core.direct_need_evaluation_ready(\n        v_evaluation.planning_input_evaluation_id,\n        v_root.period_start, v_root.period_end\n      )\n    then\n      raise exception using\n        errcode = \'23514\',\n        message = \'READY requires either all three exact sources or one exact direct-complete Pantry source\';\n    end if;';
begin
  anchor := position(E'  if v_root.readiness_status <> \'INVALIDATED\' then' in definition);
  if anchor=0 then raise exception 'Direct Need expected readiness integrity branch was not found'; end if;
  start_at := anchor-1 + position(E'    if v_evaluation.evaluation_result = \'READY\'' in substring(definition from anchor));
  end_at := start_at-1 + position(ending in substring(definition from start_at))-1;
  if start_at<anchor or end_at<start_at then raise exception 'Direct Need readiness integrity boundary changed'; end if;
  definition := substring(definition from 1 for start_at-1)
    ||replacement||substring(definition from end_at+1);
  execute definition;
end;
$patch_readiness_integrity$;

-- Workbench payload remains one Pantry surface and adds the closed scope facts.
grant create on schema atlas_core, atlas_api to atlas_read_runtime;
set role atlas_read_runtime;
alter function atlas_core.pantry_02_workbench_payload(date,uuid)
  rename to direct_need_legacy_pantry_workbench_payload;

create function atlas_core.pantry_02_workbench_payload(
  target_week_start date,
  target_actor_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_payload jsonb := atlas_core.direct_need_legacy_pantry_workbench_payload(
    target_week_start,target_actor_id
  );
  v_batch_id uuid := atlas_core.pa_05b_safe_uuid(
    v_payload#>>'{batch,pantry_need_batch_id}'
  );
  v_modes jsonb;
begin
  select coalesce(jsonb_agg(jsonb_build_object(
    'school_id',mode.school_id,'service_date',mode.service_date,
    'direct_need_mode',mode.direct_need_mode
  ) order by mode.service_date,mode.school_id),'[]'::jsonb)
  into v_modes
  from atlas_planning.pantry_need_school_date_modes mode
  where mode.pantry_need_batch_id=v_batch_id;
  v_payload := jsonb_set(v_payload,'{school_date_modes}',v_modes,true);
  if v_batch_id is not null then
    v_payload := jsonb_set(v_payload,'{batch,school_date_modes}',v_modes,true);
  end if;
  return v_payload;
end;
$$;

revoke all on function
  atlas_core.pantry_02_workbench_payload(date,uuid),
  atlas_core.direct_need_legacy_pantry_workbench_payload(date,uuid)
from public, anon, authenticated, service_role;
grant execute on function
  atlas_core.pantry_02_workbench_payload(date,uuid),
  atlas_core.direct_need_legacy_pantry_workbench_payload(date,uuid)
to atlas_read_runtime,atlas_planning_command_runtime;

-- Public Pantry reads remain least-privilege and version the mode-aware preview.
set role atlas_read_runtime;
alter function atlas_api.get_pantry_source_workbench(jsonb) set schema atlas_core;
alter function atlas_core.get_pantry_source_workbench(jsonb)
  rename to direct_need_legacy_get_pantry_source_workbench;
alter function atlas_api.preview_pantry_source(jsonb) set schema atlas_core;
alter function atlas_core.preview_pantry_source(jsonb)
  rename to direct_need_legacy_preview_pantry_source;

create function atlas_api.get_pantry_source_workbench(request jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  v_result:=atlas_core.direct_need_legacy_get_pantry_source_workbench(request);
  if v_result->>'success'='true' then
    v_result:=jsonb_set(v_result,'{workbench}',
      atlas_core.pantry_02_workbench_payload(
        atlas_core.pa_05d_safe_date(request#>>'{payload,week_start}'),
        atlas_core.pa_05b_safe_uuid((
          atlas_core.pantry_02_authorize_global(
            request,'planning.inputs.read','get_pantry_source_workbench'
          )->>'actor_id'
        ))
      ),true);
    v_result:=jsonb_set(v_result,'{workbench,school_date_modes}',
      coalesce(v_result#>'{workbench,school_date_modes}','[]'::jsonb),true);
  end if;
  return v_result;
end;
$$;

create function atlas_api.preview_pantry_source(request jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_legacy_request jsonb;
  v_result jsonb;
  v_modes jsonb;
  v_batch_id uuid;
begin
  if request->>'contract_version'='PANTRY-02.v1' then
    return atlas_core.direct_need_legacy_preview_pantry_source(request);
  end if;
  if request->>'contract_version'<>'PANTRY-02.v3'
    or jsonb_typeof(request#>'{payload,school_date_modes}')<>'array'
    or (request->'payload')-array['week_start','no_additions_confirmed','rows',
      'claimed_source_signature','school_date_modes']<>'{}'::jsonb
  then
    return atlas_core.pantry_02_read_error(request,'preview_pantry_source',
      'VALIDATION_FAILED','Direct Need preview requires School/date modes.');
  end if;
  v_legacy_request:=jsonb_set(
    jsonb_set(request,'{contract_version}','"PANTRY-02.v1"'::jsonb,true),
    '{payload}',(request->'payload')-'school_date_modes',true
  );
  v_result:=atlas_core.direct_need_legacy_preview_pantry_source(v_legacy_request);
  if v_result->>'success'<>'true' then return v_result; end if;
  v_modes:=atlas_core.direct_need_canonical_modes(
    atlas_core.pa_05d_safe_date(request#>>'{payload,week_start}'),
    v_result#>'{preview,canonical_rows}',request#>'{payload,school_date_modes}'
  );
  if v_modes is null then
    return atlas_core.pantry_02_read_error(request,'preview_pantry_source',
      'VALIDATION_FAILED',
      'Provide exactly one ADDITIVE or COMPLETE mode for every School/date with direct lines.');
  end if;
  select pantry_need_batch_id into v_batch_id
  from atlas_planning.pantry_need_batches
  where week_start=atlas_core.pa_05d_safe_date(request#>>'{payload,week_start}');
  v_result:=jsonb_set(v_result,'{contract_version}','"PANTRY-02.v3"'::jsonb,true);
  v_result:=jsonb_set(v_result,'{preview,school_date_modes}',v_modes,true);
  if v_batch_id is not null
    and not atlas_core.direct_need_modes_match(v_batch_id,v_modes)
  then
    v_result:=jsonb_set(v_result,'{preview,comparison,status}',
      '"REPLACEMENT"'::jsonb,true);
  end if;
  return v_result;
end;
$$;

revoke all on function
  atlas_core.direct_need_legacy_get_pantry_source_workbench(jsonb),
  atlas_core.direct_need_legacy_preview_pantry_source(jsonb),
  atlas_api.get_pantry_source_workbench(jsonb),
  atlas_api.preview_pantry_source(jsonb)
from public,anon,authenticated,service_role;
grant execute on function
  atlas_core.direct_need_legacy_get_pantry_source_workbench(jsonb),
  atlas_core.direct_need_legacy_preview_pantry_source(jsonb)
to atlas_read_runtime;
grant execute on function
  atlas_api.get_pantry_source_workbench(jsonb),
  atlas_api.preview_pantry_source(jsonb)
to authenticated;

reset role;
set role atlas_owner;
grant usage, create on schema atlas_core, atlas_api
to atlas_planning_command_runtime;
reset role;
set role atlas_planning_command_runtime;

-- Extend the existing atomic completion body. Its one top-level receipt hashes
-- the v3 mode payload; compatibility child commands receive only their v1 rows.
do $patch_pantry_save$
declare
  definition text := pg_get_functiondef(
    'atlas_core.issue_222_save_pantry_impl(jsonb)'::regprocedure
  );
  old_text text;
  new_text text;
begin
  old_text := E'  v_contract constant text := \'PANTRY-02.v2\';';
  if position(old_text in definition)=0 then raise exception 'Direct Need Pantry contract anchor changed'; end if;
  definition:=replace(definition,old_text,E'  v_contract constant text := \'PANTRY-02.v3\';');

  old_text := E'       \'expected_source_signature\', \'rows\'\n     ] <> \'{}\'::jsonb';
  if position(old_text in definition)=0 then raise exception 'Direct Need Pantry allowed payload anchor changed'; end if;
  definition:=replace(definition,old_text,E'       \'expected_source_signature\', \'rows\', \'school_date_modes\'\n     ] <> \'{}\'::jsonb');
  old_text := E'       \'expected_source_signature\', \'rows\'\n     ])';
  if position(old_text in definition)=0 then raise exception 'Direct Need Pantry required payload anchor changed'; end if;
  definition:=replace(definition,old_text,E'       \'expected_source_signature\', \'rows\', \'school_date_modes\'\n     ])');
  definition:=replace(definition,E'  v_rows jsonb;',E'  v_rows jsonb;\n  v_modes jsonb;');

  old_text := E'  v_rows := atlas_core.pantry_02_canonical_rows(\n    v_week_start, request -> \'payload\' -> \'rows\'\n  );';
  if position(old_text in definition)=0 then raise exception 'Direct Need Pantry canonical rows anchor changed'; end if;
  new_text := old_text||E'\n  v_modes := atlas_core.direct_need_canonical_modes(\n    v_week_start, v_rows, request -> \'payload\' -> \'school_date_modes\'\n  );\n  if v_modes is null then\n    return atlas_core.planning_contract_01_command_error(\n      request, v_name, v_contract, \'VALIDATION_FAILED\',\n      \'Provide exactly one ADDITIVE or COMPLETE mode for every School/date with direct lines.\'\n    );\n  end if;';
  definition:=replace(definition,old_text,new_text);

  old_text := E'         and v_batch.no_additions_confirmed = v_no_additions then';
  if position(old_text in definition)=0 then raise exception 'Direct Need Pantry no-change anchor changed'; end if;
  definition:=replace(definition,old_text,
    E'         and v_batch.no_additions_confirmed = v_no_additions\n         and atlas_core.direct_need_modes_match(\n           v_batch.pantry_need_batch_id, v_modes\n         ) then');

  old_text := E'        request -> \'payload\'\n      );';
  if position(old_text in definition)=0 then raise exception 'Direct Need Pantry legacy payload anchor changed'; end if;
  definition:=replace(definition,old_text,
    E'        (request -> \'payload\') - \'school_date_modes\'\n      );');

  old_text := E'    v_legacy := atlas_core.planning_contract_01_legacy_request(\n      request, \'PANTRY-02.v1\', v_version,\n      \'SOURCE_COMPLETION_APPROVED\'';
  if position(old_text in definition)=0 then raise exception 'Direct Need Pantry approval anchor changed'; end if;
  new_text := E'    perform atlas_core.direct_need_replace_modes(\n      v_week_start, v_rows, v_modes, v_actor_id\n    );\n\n'||old_text;
  definition:=replace(definition,old_text,new_text);
  execute definition;
end;
$patch_pantry_save$;

create or replace function atlas_api.save_pantry(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_error jsonb;
  v_request jsonb := request;
  v_result jsonb;
  v_rows jsonb;
  v_modes jsonb;
  v_compatibility_v2 boolean := request->>'contract_version'='PANTRY-02.v2';
begin
  -- Existing v2 callers remain valid and retain the historical additive meaning.
  -- The v3 Application contract is the only path that can assert COMPLETE.
  if v_compatibility_v2 then
    v_rows:=atlas_core.pantry_02_canonical_rows(
      atlas_core.pa_05d_safe_date(request#>>'{payload,week_start}'),
      request#>'{payload,rows}'
    );
    select coalesce(jsonb_agg(jsonb_build_object(
      'school_id',scope.school_id,
      'service_date',scope.service_date,
      'direct_need_mode','ADDITIVE'
    ) order by scope.service_date,scope.school_id),'[]'::jsonb)
    into v_modes
    from (
      select distinct
        atlas_core.pa_05b_safe_uuid(item->>'school_id') school_id,
        atlas_core.pa_05d_safe_date(item->>'service_date') service_date
      from jsonb_array_elements(coalesce(v_rows,'[]'::jsonb)) item
    ) scope;
    v_request:=jsonb_set(
      jsonb_set(request,'{contract_version}','"PANTRY-02.v3"'::jsonb,true),
      '{payload,school_date_modes}',v_modes,true
    );
  end if;
  v_error := atlas_core.issue_222_enforce_source_save(
    v_request, 'PANTRY', 'save_pantry', 'PANTRY-02.v3',
    'planning.pantry.write'
  );
  if v_error is not null then v_result:=v_error;
  else v_result:=atlas_core.issue_222_save_pantry_impl(v_request);
  end if;
  if v_compatibility_v2 then
    v_result:=jsonb_set(v_result,'{contract_version}','"PANTRY-02.v2"'::jsonb,true);
  end if;
  return v_result;
end;
$$;

revoke all on function atlas_api.save_pantry(jsonb)
from public,anon,authenticated,service_role;
grant execute on function atlas_api.save_pantry(jsonb) to authenticated;
comment on function atlas_api.save_pantry(jsonb) is
  'PANTRY-02.v3 atomic Direct Ingredient Need Save with exact School/date ADDITIVE or COMPLETE authority.';

-- Build a genuine READY evaluation for a direct-complete daily source. This is
-- supporting evidence generated inside the existing Need command, not a fake
-- Menu or Attendance source.
create function atlas_core.direct_need_prepare_evaluation(
  request jsonb,
  actor_id uuid,
  target_start date,
  target_end date,
  preflight jsonb
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_set atlas_planning.planning_input_sets%rowtype;
  v_current atlas_planning.planning_input_evaluations%rowtype;
  v_set_id uuid;
  v_evaluation_id uuid:=gen_random_uuid();
  v_version bigint;
  v_pantry_id uuid:=atlas_core.pa_05b_safe_uuid(preflight#>>'{source_evidence,pantry,selected,pantry_need_batch_id}');
  v_pantry_version bigint:=atlas_core.pa_05b_safe_bigint(preflight#>>'{source_evidence,pantry,selected,pantry_need_batch_version}');
  v_snapshot_id uuid:=atlas_core.pa_05b_safe_uuid(preflight#>>'{source_evidence,pantry,selected,pantry_need_approval_snapshot_id}');
begin
  if target_start is null or target_start<>target_end or actor_id is null
    or not atlas_core.direct_need_snapshot_complete_only(v_snapshot_id,target_start)
    or not exists(select 1 from atlas_planning.pantry_need_batches pantry
      where pantry.pantry_need_batch_id=v_pantry_id and pantry.version=v_pantry_version
        and pantry.latest_approval_snapshot_id=v_snapshot_id
        and pantry.pantry_need_batch_status='APPROVED'
        and target_start between pantry.week_start and pantry.week_end)
  then
    return atlas_core.planning_contract_01_command_error(
      request,'execute_need_generation','RMVP-04.v2',
      'PLANNING_INPUTS_NOT_READY',
      'The direct-complete Pantry source is not current.'
    );
  end if;

  select * into v_set from atlas_planning.planning_input_sets
  where period_start=target_start and period_end=target_end for update;
  if v_set.planning_input_set_id is null then
    v_set_id:=gen_random_uuid();v_version:=1;
    insert into atlas_planning.planning_input_sets(
      planning_input_set_id,period_start,period_end,readiness_status,
      current_evaluation_id,created_at,updated_at
    ) values(v_set_id,target_start,target_end,'READY',v_evaluation_id,
      transaction_timestamp(),transaction_timestamp());
  else
    v_set_id:=v_set.planning_input_set_id;
    select * into v_current from atlas_planning.planning_input_evaluations
    where planning_input_evaluation_id=v_set.current_evaluation_id;
    if v_set.readiness_status not in ('NOT_READY','INVALIDATED') then
      return atlas_core.planning_contract_01_command_error(
        request,'execute_need_generation','RMVP-04.v2','STALE_VERSION',
        'Planning readiness changed before direct-complete evaluation.'
      );
    end if;
    v_version:=v_current.evaluation_version+1;
  end if;

  insert into atlas_planning.planning_input_evaluations(
    planning_input_evaluation_id,planning_input_set_id,evaluation_version,
    evaluation_result,weekly_menu_id,weekly_menu_version,
    weekly_menu_approval_snapshot_id,attendance_batch_id,attendance_version,
    attendance_approval_snapshot_id,blocking_issue_count,warning_count,
    evaluated_by_actor_id,evaluated_at,pantry_need_batch_id,
    pantry_need_batch_version,pantry_need_approval_snapshot_id
  ) values(v_evaluation_id,v_set_id,v_version,'READY',null,null,null,
    null,null,null,0,0,actor_id,transaction_timestamp(),v_pantry_id,
    v_pantry_version,v_snapshot_id);

  if v_set.planning_input_set_id is not null then
    update atlas_planning.planning_input_sets
    set readiness_status='READY',current_evaluation_id=v_evaluation_id,
      updated_at=transaction_timestamp()
    where planning_input_set_id=v_set_id;
  end if;

  return jsonb_build_object(
    'success',true,
    'affected_aggregate_ids',jsonb_build_object(
      'planning_input_set_id',v_set_id,
      'planning_input_evaluation_id',v_evaluation_id
    ),
    'new_versions',jsonb_build_object(
      'current_evaluation_version',v_version
    ),
    'authoritative_readback',jsonb_build_object('decision','READY')
  );
end;
$$;

revoke all on function
  atlas_core.direct_need_prepare_evaluation(jsonb,uuid,date,date,jsonb)
from public,anon,authenticated,service_role;
grant execute on function
  atlas_core.direct_need_prepare_evaluation(jsonb,uuid,date,date,jsonb)
to atlas_need_generation_runtime;

reset role;
set role atlas_read_runtime;

-- Compose mode authority into automatic daily preflight and exact currentness.
alter function atlas_core.planning_contract_01_preflight_payload(date,date,jsonb)
  rename to direct_need_legacy_preflight_payload;

create function atlas_core.planning_contract_01_preflight_payload(
  period_start date,
  period_end date,
  supplied_candidates jsonb default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_payload jsonb:=atlas_core.direct_need_legacy_preflight_payload(
    period_start,period_end,supplied_candidates
  );
  v_direct jsonb;
  v_selected_snapshot uuid;
  v_current_snapshot uuid;
  v_current_run uuid;
  v_selected_fingerprint text;
  v_current_fingerprint text;
begin
  if period_start is distinct from period_end
    or v_payload->>'downstream_currentness'='LEGACY_OVERLAP'
  then return v_payload; end if;

  v_direct:=atlas_core.direct_need_current_complete_source(period_start);
  if v_direct is not null then
    v_payload:=jsonb_set(v_payload,'{direct_need_scopes}',(
      select coalesce(jsonb_agg(jsonb_build_object(
        'school_id',mode.school_id,'service_date',mode.service_date,
        'direct_need_mode',mode.direct_need_mode
      ) order by mode.school_id),'[]'::jsonb)
      from atlas_planning.pantry_need_approval_snapshot_school_date_modes mode
      where mode.pantry_need_approval_snapshot_id=(v_direct->>'pantry_need_approval_snapshot_id')::uuid
        and mode.service_date=period_start
    ),true);
    v_payload:=jsonb_set(v_payload,'{direct_need_source_mode}',
      case when v_payload#>>'{source_evidence,weekly_menu,selection_state}'='SELECTED'
        and v_payload#>>'{source_evidence,attendance,selection_state}'='SELECTED'
        then '"COMPOSED"'::jsonb else '"COMPLETE_ONLY"'::jsonb end,true);
    v_payload:=jsonb_set(v_payload,'{source_evidence,pantry,selection_state}','"SELECTED"'::jsonb,true);
    v_payload:=jsonb_set(v_payload,'{source_evidence,pantry,selected}',v_direct,true);
    if v_payload->>'direct_need_source_mode'='COMPLETE_ONLY' then
      v_payload:=jsonb_set(v_payload,'{source_evidence,weekly_menu}',
        jsonb_build_object('selection_state','NOT_REQUIRED','selected',null),true);
      v_payload:=jsonb_set(v_payload,'{source_evidence,attendance}',
        jsonb_build_object('selection_state','NOT_REQUIRED','selected',null),true);
      v_payload:=jsonb_set(v_payload,'{readiness_state}','"READY"'::jsonb,true);
      v_payload:=jsonb_set(v_payload,'{issues}','[]'::jsonb,true);
      v_payload:=jsonb_set(v_payload,'{blocking_issue_count}','0'::jsonb,true);
    end if;
  end if;

  v_selected_snapshot:=atlas_core.pa_05b_safe_uuid(
    v_payload#>>'{source_evidence,pantry,selected,pantry_need_approval_snapshot_id}'
  );
  v_selected_fingerprint:=atlas_core.direct_need_snapshot_fingerprint(
    v_selected_snapshot,period_start
  );
  v_current_run:=atlas_core.pa_05b_safe_uuid(
    v_payload#>>'{current_need,need_generation_run_id}'
  );
  select input.pantry_need_approval_snapshot_id into v_current_snapshot
  from atlas_planning.need_generation_runs run
  join atlas_planning.need_generation_input_snapshots input
    on input.need_generation_input_snapshot_id=run.input_snapshot_id
  where run.need_generation_run_id=v_current_run;
  v_current_fingerprint:=atlas_core.direct_need_snapshot_fingerprint(
    v_current_snapshot,period_start
  );
  v_payload:=jsonb_set(v_payload,'{direct_need_fingerprints}',
    jsonb_build_object('selected',v_selected_fingerprint,
      'current',v_current_fingerprint),true);

  if v_current_run is not null and v_selected_snapshot is not null then
    if v_selected_fingerprint is distinct from v_current_fingerprint then
      v_payload:=jsonb_set(v_payload,'{downstream_currentness}','"OUTDATED"'::jsonb,true);
    elsif exists(select 1 from atlas_planning.need_generation_input_snapshots input
      where input.need_generation_run_id=v_current_run
        and input.weekly_menu_id is null and input.attendance_batch_id is null)
    then
      v_payload:=jsonb_set(v_payload,'{downstream_currentness}','"CURRENT"'::jsonb,true);
    end if;
  end if;
  return v_payload;
end;
$$;

revoke all on function
  atlas_core.direct_need_legacy_preflight_payload(date,date,jsonb),
  atlas_core.planning_contract_01_preflight_payload(date,date,jsonb)
from public,anon,authenticated,service_role;
grant execute on function
  atlas_core.direct_need_legacy_preflight_payload(date,date,jsonb),
  atlas_core.planning_contract_01_preflight_payload(date,date,jsonb)
to atlas_read_runtime,atlas_planning_command_runtime,
  atlas_need_generation_runtime;

reset role;
set role atlas_owner;

-- Preserve the full established integrity function; only replace its source-
-- readiness clause with the shared full-source-or-direct-complete predicate.
do $patch_generation_integrity$
declare
  definition text:=pg_get_functiondef(
    'atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()'::regprocedure
  );
  start_at integer;
  end_at integer;
  start_marker text:=E'  if v_initial_check or v_progress_check then';
  end_marker text:=E'\n\n  if v_initial_check and not exists (';
  replacement text:=E'  if v_initial_check or v_progress_check then\n    if v_root.readiness_status <> \'NEED_GENERATION_REQUESTED\'\n      or v_root.current_evaluation_id <> v_run.planning_input_evaluation_id\n      or not atlas_core.direct_need_evaluation_ready(\n        v_evaluation.planning_input_evaluation_id,\n        v_run.period_start,v_run.period_end\n      )\n    then\n      raise exception using\n        errcode = \'23514\',\n        message = \'generation entry requires current catering or direct-complete source evidence\';\n    end if;\n  end if;';
begin
  start_at:=position(start_marker in definition);
  end_at:=start_at-1+position(end_marker in substring(definition from start_at))-1;
  if start_at=0 or end_at<start_at then raise exception 'Direct Need generation integrity boundary changed'; end if;
  definition:=substring(definition from 1 for start_at-1)
    ||replacement||substring(definition from end_at+1);
  execute definition;
end;
$patch_generation_integrity$;

reset role;
set role atlas_need_generation_runtime;

-- Amend the established generator in place: direct-only readiness is valid,
-- and COMPLETE suppresses Recipe contributions for that exact School/date.
do $patch_generator$
declare
  definition text:=pg_get_functiondef(
    'atlas_api.create_need_generation_run(jsonb)'::regprocedure
  );
  start_at integer;
  end_at integer;
  anchor integer;
  start_marker text:=E'  if not exists (\n    select 1 from atlas_planning.weekly_menus as menu';
  end_marker text:=E'\n\n  select contract.* into v_contract';
  replacement text:=E'  if not atlas_core.direct_need_evaluation_ready(\n    v_evaluation_id,v_start,v_end\n  ) then\n    v_error := atlas_core.rmvp_04_error(\n      request, v_name, \'STALE_SOURCE_BINDING\',\n      \'One or more approved source bindings changed after readiness evaluation.\'\n    );\n    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);\n  end if;';
  menu_anchor text:=E'      and menu_line.service_date between v_start and v_end';
begin
  start_at:=position(start_marker in definition);
  end_at:=start_at-1+position(end_marker in substring(definition from start_at))-1;
  if start_at=0 or end_at<start_at then raise exception 'Direct Need generator source boundary changed'; end if;
  definition:=substring(definition from 1 for start_at-1)
    ||replacement||substring(definition from end_at+1);
  anchor:=position(menu_anchor in definition);
  if anchor=0 then raise exception 'Direct Need generator Menu filter anchor changed'; end if;
  definition:=replace(definition,menu_anchor,menu_anchor||E'\n      and atlas_core.direct_need_effective_mode(\n        v_evaluation.pantry_need_approval_snapshot_id,\n        menu_line.school_id,menu_line.service_date\n      ) <> \'COMPLETE\'');
  execute definition;
end;
$patch_generator$;

-- The existing atomic command keeps its one receipt and child boundaries. Only
-- the readiness-evaluation step branches for an exact direct-complete source.
do $patch_atomic_execute$
declare
  definition text:=pg_get_functiondef(
    'atlas_core.issue_223_execute_need_generation_v2(jsonb)'::regprocedure
  );
  old_text text:=E'    v_result := atlas_api.evaluate_planning_input_readiness(v_request_v1);';
  new_text text:=E'    if v_preflight ->> \'direct_need_source_mode\' = \'COMPLETE_ONLY\' then\n      v_result := atlas_core.direct_need_prepare_evaluation(\n        request,v_actor_id,v_start,v_end,v_preflight\n      );\n    else\n      v_result := atlas_api.evaluate_planning_input_readiness(v_request_v1);\n    end if;';
begin
  if position(old_text in definition)=0 then raise exception 'Direct Need atomic evaluation anchor changed'; end if;
  definition:=replace(definition,old_text,new_text);
  execute definition;
end;
$patch_atomic_execute$;

revoke all on function atlas_api.create_need_generation_run(jsonb)
from public,anon,authenticated,service_role;
grant execute on function atlas_api.create_need_generation_run(jsonb)
to authenticated;

reset role;
set role atlas_owner;
revoke create on schema atlas_core,atlas_api
from atlas_read_runtime,atlas_planning_command_runtime,
  atlas_need_generation_runtime;
reset role;
grant atlas_read_runtime,atlas_planning_command_runtime,
  atlas_need_generation_runtime to postgres with set false;
