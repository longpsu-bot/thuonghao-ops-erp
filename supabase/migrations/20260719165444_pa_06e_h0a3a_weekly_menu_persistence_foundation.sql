-- PA-06E-H0A3a: private Weekly Menu persistence and approval snapshots.
--
-- This additive migration creates persistence structure only. It adds no API,
-- command, capability, seed, legacy write, downstream calculation, or hosted action.

set role atlas_owner;

create table atlas_planning.weekly_menus (
  weekly_menu_id uuid not null default gen_random_uuid(),
  week_start date not null,
  week_end date not null,
  source_type text not null,
  source_name text not null,
  source_signature text not null,
  weekly_menu_status text not null default 'DRAFT',
  row_count integer not null default 0,
  imported_by_actor_id uuid not null,
  imported_at timestamptz not null default transaction_timestamp(),
  latest_approved_by_actor_id uuid,
  latest_approved_at timestamptz,
  latest_approval_snapshot_id uuid,
  version bigint not null default 1,
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp(),
  constraint weekly_menus_pkey primary key (weekly_menu_id),
  constraint weekly_menus_week_start_key unique (week_start),
  constraint weekly_menus_id_version_key unique (weekly_menu_id, version),
  constraint weekly_menus_imported_by_actor_fkey foreign key (imported_by_actor_id)
    references atlas_core.actors (actor_id) on delete restrict,
  constraint weekly_menus_latest_approved_by_actor_fkey foreign key (
    latest_approved_by_actor_id
  ) references atlas_core.actors (actor_id) on delete restrict,
  constraint weekly_menus_service_week_check check (
    week_end = week_start + 6
  ),
  constraint weekly_menus_source_type_check check (btrim(source_type) <> ''),
  constraint weekly_menus_source_name_check check (btrim(source_name) <> ''),
  constraint weekly_menus_source_signature_check check (btrim(source_signature) <> ''),
  constraint weekly_menus_status_check check (
    weekly_menu_status in (
      'DRAFT',
      'VALIDATED',
      'APPROVED',
      'NEED_GENERATION_REQUESTED',
      'REOPENED'
    )
  ),
  constraint weekly_menus_row_count_check check (row_count >= 0),
  constraint weekly_menus_approval_evidence_check check (
    (
      latest_approved_by_actor_id is null
      and latest_approved_at is null
      and latest_approval_snapshot_id is null
    )
    or (
      latest_approved_by_actor_id is not null
      and latest_approved_at is not null
      and latest_approval_snapshot_id is not null
    )
  ),
  constraint weekly_menus_approved_status_evidence_check check (
    weekly_menu_status not in ('APPROVED', 'NEED_GENERATION_REQUESTED')
    or latest_approval_snapshot_id is not null
  ),
  constraint weekly_menus_version_check check (version > 0),
  constraint weekly_menus_timestamps_check check (
    updated_at >= created_at
  )
);

create index weekly_menus_imported_by_actor_idx
  on atlas_planning.weekly_menus (imported_by_actor_id);
create index weekly_menus_latest_approved_by_actor_idx
  on atlas_planning.weekly_menus (latest_approved_by_actor_id)
  where latest_approved_by_actor_id is not null;

create table atlas_planning.weekly_menu_lines (
  weekly_menu_line_id uuid not null default gen_random_uuid(),
  weekly_menu_id uuid not null,
  school_id uuid not null,
  service_date date not null,
  menu_slot_code text not null,
  dish_id uuid not null,
  line_status text not null default 'ACTIVE',
  source_row_reference text,
  created_by_actor_id uuid not null,
  created_at timestamptz not null default transaction_timestamp(),
  updated_by_actor_id uuid not null,
  updated_at timestamptz not null default transaction_timestamp(),
  constraint weekly_menu_lines_pkey primary key (weekly_menu_line_id),
  constraint weekly_menu_lines_id_menu_key unique (
    weekly_menu_line_id,
    weekly_menu_id
  ),
  constraint weekly_menu_lines_menu_fkey foreign key (weekly_menu_id)
    references atlas_planning.weekly_menus (weekly_menu_id) on delete restrict,
  constraint weekly_menu_lines_school_fkey foreign key (school_id)
    references atlas_admin.schools (school_id) on delete restrict,
  constraint weekly_menu_lines_dish_fkey foreign key (dish_id)
    references atlas_admin.dishes (dish_id) on delete restrict,
  constraint weekly_menu_lines_created_by_actor_fkey foreign key (created_by_actor_id)
    references atlas_core.actors (actor_id) on delete restrict,
  constraint weekly_menu_lines_updated_by_actor_fkey foreign key (updated_by_actor_id)
    references atlas_core.actors (actor_id) on delete restrict,
  constraint weekly_menu_lines_assignment_key unique (
    weekly_menu_id,
    school_id,
    service_date,
    menu_slot_code
  ),
  constraint weekly_menu_lines_menu_slot_code_check check (
    menu_slot_code = lower(menu_slot_code)
    and btrim(menu_slot_code) <> ''
  ),
  constraint weekly_menu_lines_status_check check (
    line_status in ('ACTIVE', 'INVALID')
  ),
  constraint weekly_menu_lines_source_row_reference_check check (
    source_row_reference is null
    or btrim(source_row_reference) <> ''
  ),
  constraint weekly_menu_lines_timestamps_check check (
    updated_at >= created_at
  )
);

create index weekly_menu_lines_school_idx
  on atlas_planning.weekly_menu_lines (school_id);
create index weekly_menu_lines_dish_idx
  on atlas_planning.weekly_menu_lines (dish_id);
create index weekly_menu_lines_created_by_actor_idx
  on atlas_planning.weekly_menu_lines (created_by_actor_id);
create index weekly_menu_lines_updated_by_actor_idx
  on atlas_planning.weekly_menu_lines (updated_by_actor_id);

create table atlas_planning.weekly_menu_approval_snapshots (
  weekly_menu_approval_snapshot_id uuid not null default gen_random_uuid(),
  weekly_menu_id uuid not null,
  weekly_menu_version bigint not null,
  approved_by_actor_id uuid not null,
  approved_at timestamptz not null,
  constraint weekly_menu_approval_snapshots_pkey primary key (
    weekly_menu_approval_snapshot_id
  ),
  constraint weekly_menu_approval_snapshots_id_menu_key unique (
    weekly_menu_approval_snapshot_id,
    weekly_menu_id
  ),
  constraint weekly_menu_approval_snapshots_id_ownership_key unique (
    weekly_menu_approval_snapshot_id,
    weekly_menu_id,
    weekly_menu_version
  ),
  constraint weekly_menu_approval_snapshots_menu_fkey foreign key (weekly_menu_id)
    references atlas_planning.weekly_menus (weekly_menu_id) on delete restrict,
  constraint weekly_menu_approval_snapshots_approved_by_actor_fkey foreign key (
    approved_by_actor_id
  ) references atlas_core.actors (actor_id) on delete restrict,
  constraint weekly_menu_approval_snapshots_menu_version_key unique (
    weekly_menu_id,
    weekly_menu_version
  ),
  constraint weekly_menu_approval_snapshots_version_check check (
    weekly_menu_version > 0
  )
);

create index weekly_menu_approval_snapshots_approved_by_actor_idx
  on atlas_planning.weekly_menu_approval_snapshots (approved_by_actor_id);

alter table atlas_planning.weekly_menus
  add constraint weekly_menus_latest_approval_snapshot_fkey foreign key (
    latest_approval_snapshot_id,
    weekly_menu_id
  ) references atlas_planning.weekly_menu_approval_snapshots (
    weekly_menu_approval_snapshot_id,
    weekly_menu_id
  ) on delete restrict;

create index weekly_menus_latest_approval_snapshot_idx
  on atlas_planning.weekly_menus (
    latest_approval_snapshot_id,
    weekly_menu_id
  )
  where latest_approval_snapshot_id is not null;

create table atlas_planning.weekly_menu_approval_snapshot_lines (
  weekly_menu_approval_snapshot_line_id uuid not null default gen_random_uuid(),
  weekly_menu_approval_snapshot_id uuid not null,
  weekly_menu_id uuid not null,
  weekly_menu_version bigint not null,
  weekly_menu_line_id uuid not null,
  school_id uuid not null,
  service_date date not null,
  menu_slot_code text not null,
  dish_id uuid not null,
  source_row_reference text,
  constraint weekly_menu_approval_snapshot_lines_pkey primary key (
    weekly_menu_approval_snapshot_line_id
  ),
  constraint weekly_menu_approval_snapshot_lines_snapshot_fkey foreign key (
    weekly_menu_approval_snapshot_id,
    weekly_menu_id,
    weekly_menu_version
  ) references atlas_planning.weekly_menu_approval_snapshots (
    weekly_menu_approval_snapshot_id,
    weekly_menu_id,
    weekly_menu_version
  ) on delete restrict,
  constraint weekly_menu_approval_snapshot_lines_menu_line_fkey foreign key (
    weekly_menu_line_id,
    weekly_menu_id
  ) references atlas_planning.weekly_menu_lines (
    weekly_menu_line_id,
    weekly_menu_id
  ) on delete restrict,
  constraint weekly_menu_approval_snapshot_lines_school_fkey foreign key (school_id)
    references atlas_admin.schools (school_id) on delete restrict,
  constraint weekly_menu_approval_snapshot_lines_dish_fkey foreign key (dish_id)
    references atlas_admin.dishes (dish_id) on delete restrict,
  constraint weekly_menu_approval_snapshot_lines_line_key unique (
    weekly_menu_approval_snapshot_id,
    weekly_menu_line_id
  ),
  constraint weekly_menu_approval_snapshot_lines_assignment_key unique (
    weekly_menu_approval_snapshot_id,
    school_id,
    service_date,
    menu_slot_code
  ),
  constraint weekly_menu_approval_snapshot_lines_version_check check (
    weekly_menu_version > 0
  ),
  constraint weekly_menu_approval_snapshot_lines_menu_slot_code_check check (
    menu_slot_code = lower(menu_slot_code)
    and btrim(menu_slot_code) <> ''
  ),
  constraint weekly_menu_approval_snapshot_lines_source_row_reference_check check (
    source_row_reference is null
    or btrim(source_row_reference) <> ''
  )
);

create index weekly_menu_approval_snapshot_lines_snapshot_ownership_idx
  on atlas_planning.weekly_menu_approval_snapshot_lines (
    weekly_menu_approval_snapshot_id,
    weekly_menu_id,
    weekly_menu_version
  );
create index weekly_menu_approval_snapshot_lines_menu_line_idx
  on atlas_planning.weekly_menu_approval_snapshot_lines (
    weekly_menu_line_id,
    weekly_menu_id
  );
create index weekly_menu_approval_snapshot_lines_school_idx
  on atlas_planning.weekly_menu_approval_snapshot_lines (school_id);
create index weekly_menu_approval_snapshot_lines_dish_idx
  on atlas_planning.weekly_menu_approval_snapshot_lines (dish_id);

create function atlas_planning.pa_06e_h0a3a_weekly_menu_lifecycle_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  prior_snapshot_version bigint;
begin
  if tg_op = 'INSERT' then
    if new.weekly_menu_status <> 'DRAFT' then
      raise exception using
        errcode = '23514',
        message = 'new weekly menus must enter as DRAFT';
    end if;

    return new;
  end if;

  if tg_op = 'DELETE' then
    if old.weekly_menu_status <> 'DRAFT'
      or old.latest_approval_snapshot_id is not null
    then
      raise exception using
        errcode = '23514',
        message = 'validated or historically approved weekly menus cannot be deleted';
    end if;

    return old;
  end if;

  if new.weekly_menu_id is distinct from old.weekly_menu_id
    or new.week_start is distinct from old.week_start
    or new.week_end is distinct from old.week_end
    or new.created_at is distinct from old.created_at
  then
    raise exception using
      errcode = '23514',
      message = 'weekly menu identity and service-week scope are immutable';
  end if;

  if new.version < old.version
    or new.version > old.version + 1
  then
    raise exception using
      errcode = '23514',
      message = 'weekly menu version must advance monotonically by at most one';
  end if;

  if old.latest_approval_snapshot_id is not null
    and new.weekly_menu_status <> 'APPROVED'
    and (
      new.latest_approval_snapshot_id is distinct from old.latest_approval_snapshot_id
      or new.latest_approved_by_actor_id is distinct from old.latest_approved_by_actor_id
      or new.latest_approved_at is distinct from old.latest_approved_at
    )
  then
    raise exception using
      errcode = '23514',
      message = 'established weekly menu approval evidence is immutable across later transitions';
  end if;

  if new.weekly_menu_status = old.weekly_menu_status then
    if old.weekly_menu_status not in ('DRAFT', 'REOPENED')
      and new is distinct from old
    then
      raise exception using
        errcode = '23514',
        message = 'validated and approved weekly menus change only through lifecycle transitions';
    end if;

    return new;
  end if;

  if not (
    (old.weekly_menu_status = 'DRAFT' and new.weekly_menu_status = 'VALIDATED')
    or (old.weekly_menu_status = 'VALIDATED' and new.weekly_menu_status = 'APPROVED')
    or (
      old.weekly_menu_status = 'APPROVED'
      and new.weekly_menu_status = 'NEED_GENERATION_REQUESTED'
    )
    or (
      old.weekly_menu_status in ('APPROVED', 'NEED_GENERATION_REQUESTED')
      and new.weekly_menu_status = 'REOPENED'
    )
    or (old.weekly_menu_status = 'REOPENED' and new.weekly_menu_status = 'DRAFT')
  ) then
    raise exception using
      errcode = '23514',
      message = 'weekly menu lifecycle transition is invalid';
  end if;

  if new.weekly_menu_status = 'REOPENED' then
    if new.version <> old.version + 1 then
      raise exception using
        errcode = '23514',
        message = 'reopening a weekly menu must create the next working version';
    end if;
  elsif new.version <> old.version then
    raise exception using
      errcode = '23514',
      message = 'weekly menu lifecycle transitions preserve the current version except on reopen';
  end if;

  if new.weekly_menu_status = 'APPROVED'
    and old.latest_approval_snapshot_id is not null
  then
    select snapshot.weekly_menu_version
      into prior_snapshot_version
    from atlas_planning.weekly_menu_approval_snapshots snapshot
    where snapshot.weekly_menu_approval_snapshot_id = old.latest_approval_snapshot_id;

    if new.latest_approval_snapshot_id is not distinct from old.latest_approval_snapshot_id
      or new.version <= prior_snapshot_version
    then
      raise exception using
        errcode = '23514',
        message = 'later weekly menu approval requires a new snapshot for a later version';
    end if;
  end if;

  return new;
end
$$;

create function atlas_planning.pa_06e_h0a3a_weekly_menu_line_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  target_menu atlas_planning.weekly_menus%rowtype;
begin
  if tg_op = 'UPDATE' and (
    new.weekly_menu_line_id is distinct from old.weekly_menu_line_id
    or new.weekly_menu_id is distinct from old.weekly_menu_id
    or new.created_by_actor_id is distinct from old.created_by_actor_id
    or new.created_at is distinct from old.created_at
  ) then
    raise exception using
      errcode = '23514',
      message = 'stable weekly menu line identity and ownership are immutable';
  end if;

  select menu.*
    into target_menu
  from atlas_planning.weekly_menus menu
  where menu.weekly_menu_id = case
    when tg_op = 'DELETE' then old.weekly_menu_id
    else new.weekly_menu_id
  end;

  if not found then
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;

  if target_menu.weekly_menu_status not in ('DRAFT', 'REOPENED') then
    raise exception using
      errcode = '23514',
      message = 'weekly menu lines are mutable only while the menu is DRAFT or REOPENED';
  end if;

  if tg_op <> 'DELETE'
    and (
      new.service_date < target_menu.week_start
      or new.service_date > target_menu.week_end
    )
  then
    raise exception using
      errcode = '23514',
      message = 'weekly menu line service date must be inside the menu service week';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end
$$;

create function atlas_planning.pa_06e_h0a3a_weekly_menu_snapshot_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  target_menu atlas_planning.weekly_menus%rowtype;
  target_snapshot atlas_planning.weekly_menu_approval_snapshots%rowtype;
  target_line atlas_planning.weekly_menu_lines%rowtype;
begin
  if tg_op in ('UPDATE', 'DELETE') then
    raise exception using
      errcode = '23514',
      message = 'weekly menu approval snapshots and snapshot lines are immutable';
  end if;

  if tg_table_name = 'weekly_menu_approval_snapshots' then
    select menu.*
      into target_menu
    from atlas_planning.weekly_menus menu
    where menu.weekly_menu_id = new.weekly_menu_id;

    if found and (
      target_menu.weekly_menu_status <> 'VALIDATED'
      or new.weekly_menu_version <> target_menu.version
    ) then
      raise exception using
        errcode = '23514',
        message = 'an approval snapshot requires the exact current validated weekly menu version';
    end if;

    return new;
  end if;

  select snapshot.*
    into target_snapshot
  from atlas_planning.weekly_menu_approval_snapshots snapshot
  where snapshot.weekly_menu_approval_snapshot_id = new.weekly_menu_approval_snapshot_id;

  select line.*
    into target_line
  from atlas_planning.weekly_menu_lines line
  where line.weekly_menu_line_id = new.weekly_menu_line_id;

  if found and (
    target_line.line_status <> 'ACTIVE'
    or new.weekly_menu_id is distinct from target_line.weekly_menu_id
    or new.school_id is distinct from target_line.school_id
    or new.service_date is distinct from target_line.service_date
    or new.menu_slot_code is distinct from target_line.menu_slot_code
    or new.dish_id is distinct from target_line.dish_id
    or new.source_row_reference is distinct from target_line.source_row_reference
  ) then
    raise exception using
      errcode = '23514',
      message = 'approval snapshot lines must exactly copy active weekly menu lines';
  end if;

  select menu.*
    into target_menu
  from atlas_planning.weekly_menus menu
  where menu.weekly_menu_id = new.weekly_menu_id;

  if found and (
    target_menu.weekly_menu_status <> 'VALIDATED'
    or new.weekly_menu_version <> target_menu.version
    or new.weekly_menu_version is distinct from target_snapshot.weekly_menu_version
  ) then
    raise exception using
      errcode = '23514',
      message = 'approval snapshot lines require the exact current validated weekly menu version';
  end if;

  return new;
end
$$;

create function atlas_planning.pa_06e_h0a3a_weekly_menu_snapshot_integrity_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  target_menu atlas_planning.weekly_menus%rowtype;
  target_snapshot atlas_planning.weekly_menu_approval_snapshots%rowtype;
  target_snapshot_id uuid;
begin
  if tg_table_name = 'weekly_menus' then
    if new.weekly_menu_status not in ('APPROVED', 'NEED_GENERATION_REQUESTED') then
      return null;
    end if;

    target_menu := new;
    target_snapshot_id := new.latest_approval_snapshot_id;
  elsif tg_table_name = 'weekly_menu_approval_snapshots' then
    select menu.*
      into target_menu
    from atlas_planning.weekly_menus menu
    where menu.weekly_menu_id = new.weekly_menu_id;
    target_snapshot_id := new.weekly_menu_approval_snapshot_id;
  else
    select menu.*
      into target_menu
    from atlas_planning.weekly_menus menu
    where menu.weekly_menu_id = new.weekly_menu_id;
    target_snapshot_id := new.weekly_menu_approval_snapshot_id;
  end if;

  if target_menu.weekly_menu_status not in ('APPROVED', 'NEED_GENERATION_REQUESTED')
    or target_menu.latest_approval_snapshot_id is distinct from target_snapshot_id
  then
    raise exception using
      errcode = '23514',
      message = 'an approval snapshot must be bound to the approved weekly menu at commit';
  end if;

  select snapshot.*
    into target_snapshot
  from atlas_planning.weekly_menu_approval_snapshots snapshot
  where snapshot.weekly_menu_approval_snapshot_id = target_snapshot_id;

  if not found
    or target_snapshot.weekly_menu_id is distinct from target_menu.weekly_menu_id
    or target_snapshot.weekly_menu_version is distinct from target_menu.version
    or target_snapshot.approved_by_actor_id is distinct from target_menu.latest_approved_by_actor_id
    or target_snapshot.approved_at is distinct from target_menu.latest_approved_at
  then
    raise exception using
      errcode = '23514',
      message = 'approved weekly menu evidence must match the exact current approval snapshot';
  end if;

  if exists (
    select 1
    from atlas_planning.weekly_menu_lines line
    where line.weekly_menu_id = target_menu.weekly_menu_id
      and line.line_status = 'ACTIVE'
      and not exists (
        select 1
        from atlas_planning.weekly_menu_approval_snapshot_lines snapshot_line
        where snapshot_line.weekly_menu_approval_snapshot_id = target_snapshot_id
          and snapshot_line.weekly_menu_line_id = line.weekly_menu_line_id
          and snapshot_line.weekly_menu_id = line.weekly_menu_id
          and snapshot_line.weekly_menu_version = target_snapshot.weekly_menu_version
          and snapshot_line.school_id = line.school_id
          and snapshot_line.service_date = line.service_date
          and snapshot_line.menu_slot_code = line.menu_slot_code
          and snapshot_line.dish_id = line.dish_id
          and snapshot_line.source_row_reference is not distinct from line.source_row_reference
      )
  ) then
    raise exception using
      errcode = '23514',
      message = 'approval snapshot must contain every active weekly menu line exactly once';
  end if;

  if exists (
    select 1
    from atlas_planning.weekly_menu_approval_snapshot_lines snapshot_line
    left join atlas_planning.weekly_menu_lines line
      on line.weekly_menu_line_id = snapshot_line.weekly_menu_line_id
     and line.weekly_menu_id = snapshot_line.weekly_menu_id
    where snapshot_line.weekly_menu_approval_snapshot_id = target_snapshot_id
      and (
        line.weekly_menu_line_id is null
        or line.line_status <> 'ACTIVE'
        or snapshot_line.school_id is distinct from line.school_id
        or snapshot_line.service_date is distinct from line.service_date
        or snapshot_line.menu_slot_code is distinct from line.menu_slot_code
        or snapshot_line.dish_id is distinct from line.dish_id
        or snapshot_line.source_row_reference is distinct from line.source_row_reference
      )
  ) then
    raise exception using
      errcode = '23514',
      message = 'approval snapshot may contain only exact active weekly menu lines';
  end if;

  return null;
end
$$;

create trigger weekly_menus_lifecycle_guard
before insert or update or delete on atlas_planning.weekly_menus
for each row execute function atlas_planning.pa_06e_h0a3a_weekly_menu_lifecycle_guard();

create trigger weekly_menu_lines_mutability_guard
before insert or update or delete on atlas_planning.weekly_menu_lines
for each row execute function atlas_planning.pa_06e_h0a3a_weekly_menu_line_guard();

create trigger weekly_menu_approval_snapshots_immutable_guard
before insert or update or delete on atlas_planning.weekly_menu_approval_snapshots
for each row execute function atlas_planning.pa_06e_h0a3a_weekly_menu_snapshot_guard();

create trigger weekly_menu_approval_snapshot_lines_immutable_guard
before insert or update or delete on atlas_planning.weekly_menu_approval_snapshot_lines
for each row execute function atlas_planning.pa_06e_h0a3a_weekly_menu_snapshot_guard();

create constraint trigger weekly_menus_snapshot_integrity_guard
after insert or update on atlas_planning.weekly_menus
deferrable initially deferred
for each row execute function atlas_planning.pa_06e_h0a3a_weekly_menu_snapshot_integrity_guard();

create constraint trigger weekly_menu_approval_snapshots_integrity_guard
after insert on atlas_planning.weekly_menu_approval_snapshots
deferrable initially deferred
for each row execute function atlas_planning.pa_06e_h0a3a_weekly_menu_snapshot_integrity_guard();

create constraint trigger weekly_menu_approval_snapshot_lines_integrity_guard
after insert on atlas_planning.weekly_menu_approval_snapshot_lines
deferrable initially deferred
for each row execute function atlas_planning.pa_06e_h0a3a_weekly_menu_snapshot_integrity_guard();

comment on table atlas_planning.weekly_menus is
  'Stable private Planning root for one exact seven-day service period and its latest approval evidence.';
comment on table atlas_planning.weekly_menu_lines is
  'Stable school/date/menu-slot Dish assignments mutable only for DRAFT or REOPENED Weekly Menus.';
comment on table atlas_planning.weekly_menu_approval_snapshots is
  'Immutable exact approval header for one positive Weekly Menu version.';
comment on table atlas_planning.weekly_menu_approval_snapshot_lines is
  'Immutable typed copy of every and only ACTIVE line accepted in one Weekly Menu approval.';
comment on column atlas_planning.weekly_menu_lines.menu_slot_code is
  'Normalized lowercase source-provided slot evidence; H0A3a seeds and hard-codes no slot catalogue.';
comment on column atlas_planning.weekly_menus.latest_approval_snapshot_id is
  'Latest historical approval snapshot; APPROVED and NEED_GENERATION_REQUESTED require its exact current version.';

alter table atlas_planning.weekly_menus enable row level security;
alter table atlas_planning.weekly_menus force row level security;
alter table atlas_planning.weekly_menu_lines enable row level security;
alter table atlas_planning.weekly_menu_lines force row level security;
alter table atlas_planning.weekly_menu_approval_snapshots enable row level security;
alter table atlas_planning.weekly_menu_approval_snapshots force row level security;
alter table atlas_planning.weekly_menu_approval_snapshot_lines enable row level security;
alter table atlas_planning.weekly_menu_approval_snapshot_lines force row level security;

revoke all on table atlas_planning.weekly_menus
  from public, anon, authenticated, service_role;
revoke all on table atlas_planning.weekly_menu_lines
  from public, anon, authenticated, service_role;
revoke all on table atlas_planning.weekly_menu_approval_snapshots
  from public, anon, authenticated, service_role;
revoke all on table atlas_planning.weekly_menu_approval_snapshot_lines
  from public, anon, authenticated, service_role;

revoke execute on function atlas_planning.pa_06e_h0a3a_weekly_menu_lifecycle_guard()
  from public, anon, authenticated, service_role;
revoke execute on function atlas_planning.pa_06e_h0a3a_weekly_menu_line_guard()
  from public, anon, authenticated, service_role;
revoke execute on function atlas_planning.pa_06e_h0a3a_weekly_menu_snapshot_guard()
  from public, anon, authenticated, service_role;
revoke execute on function atlas_planning.pa_06e_h0a3a_weekly_menu_snapshot_integrity_guard()
  from public, anon, authenticated, service_role;

reset role;
