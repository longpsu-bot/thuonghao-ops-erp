-- PA-06E-H0A3b: private Attendance persistence and approval snapshots.
--
-- This additive migration creates persistence structure only. It adds no API,
-- command, capability, seed, legacy write, downstream calculation, or hosted action.

set role atlas_owner;

create table atlas_planning.attendance_batches (
  attendance_batch_id uuid not null default gen_random_uuid(),
  period_start date not null,
  period_end date not null,
  source_type text not null,
  source_name text not null,
  source_signature text not null,
  attendance_status text not null default 'DRAFT',
  row_count integer not null default 0,
  imported_by_actor_id uuid not null,
  imported_at timestamptz not null default transaction_timestamp(),
  latest_approved_by_actor_id uuid,
  latest_approved_at timestamptz,
  latest_approval_snapshot_id uuid,
  version bigint not null default 1,
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp(),
  constraint attendance_batches_pkey primary key (attendance_batch_id),
  constraint attendance_batches_period_key unique (period_start, period_end),
  constraint attendance_batches_id_version_key unique (attendance_batch_id, version),
  constraint attendance_batches_imported_by_actor_fkey foreign key (imported_by_actor_id)
    references atlas_core.actors (actor_id) on delete restrict,
  constraint attendance_batches_latest_approved_by_actor_fkey foreign key (
    latest_approved_by_actor_id
  ) references atlas_core.actors (actor_id) on delete restrict,
  constraint attendance_batches_period_check check (period_end >= period_start),
  constraint attendance_batches_source_type_check check (btrim(source_type) <> ''),
  constraint attendance_batches_source_name_check check (btrim(source_name) <> ''),
  constraint attendance_batches_source_signature_check check (
    btrim(source_signature) <> ''
  ),
  constraint attendance_batches_status_check check (
    attendance_status in (
      'DRAFT',
      'VALIDATED',
      'APPROVED',
      'USED_FOR_NEED_GENERATION',
      'REOPENED'
    )
  ),
  constraint attendance_batches_row_count_check check (row_count >= 0),
  constraint attendance_batches_approval_evidence_check check (
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
  constraint attendance_batches_approved_status_evidence_check check (
    attendance_status not in ('APPROVED', 'USED_FOR_NEED_GENERATION')
    or latest_approval_snapshot_id is not null
  ),
  constraint attendance_batches_version_check check (version > 0),
  constraint attendance_batches_timestamps_check check (updated_at >= created_at)
);

create index attendance_batches_imported_by_actor_idx
  on atlas_planning.attendance_batches (imported_by_actor_id);
create index attendance_batches_latest_approved_by_actor_idx
  on atlas_planning.attendance_batches (latest_approved_by_actor_id)
  where latest_approved_by_actor_id is not null;

create table atlas_planning.attendance_lines (
  attendance_line_id uuid not null default gen_random_uuid(),
  attendance_batch_id uuid not null,
  school_id uuid not null,
  service_date date not null,
  student_portions integer not null,
  teacher_portions integer not null,
  line_status text not null default 'ACTIVE',
  source_row_reference text,
  created_by_actor_id uuid not null,
  created_at timestamptz not null default transaction_timestamp(),
  updated_by_actor_id uuid not null,
  updated_at timestamptz not null default transaction_timestamp(),
  constraint attendance_lines_pkey primary key (attendance_line_id),
  constraint attendance_lines_id_batch_key unique (
    attendance_line_id,
    attendance_batch_id
  ),
  constraint attendance_lines_batch_fkey foreign key (attendance_batch_id)
    references atlas_planning.attendance_batches (attendance_batch_id) on delete restrict,
  constraint attendance_lines_school_fkey foreign key (school_id)
    references atlas_admin.schools (school_id) on delete restrict,
  constraint attendance_lines_created_by_actor_fkey foreign key (created_by_actor_id)
    references atlas_core.actors (actor_id) on delete restrict,
  constraint attendance_lines_updated_by_actor_fkey foreign key (updated_by_actor_id)
    references atlas_core.actors (actor_id) on delete restrict,
  constraint attendance_lines_assignment_key unique (
    attendance_batch_id,
    school_id,
    service_date
  ),
  constraint attendance_lines_student_portions_check check (student_portions >= 0),
  constraint attendance_lines_teacher_portions_check check (teacher_portions >= 0),
  constraint attendance_lines_status_check check (
    line_status in ('ACTIVE', 'INVALID')
  ),
  constraint attendance_lines_source_row_reference_check check (
    source_row_reference is null
    or btrim(source_row_reference) <> ''
  ),
  constraint attendance_lines_timestamps_check check (updated_at >= created_at)
);

create index attendance_lines_school_idx
  on atlas_planning.attendance_lines (school_id);
create index attendance_lines_created_by_actor_idx
  on atlas_planning.attendance_lines (created_by_actor_id);
create index attendance_lines_updated_by_actor_idx
  on atlas_planning.attendance_lines (updated_by_actor_id);

create table atlas_planning.attendance_approval_snapshots (
  attendance_approval_snapshot_id uuid not null default gen_random_uuid(),
  attendance_batch_id uuid not null,
  attendance_version bigint not null,
  approved_by_actor_id uuid not null,
  approved_at timestamptz not null,
  constraint attendance_approval_snapshots_pkey primary key (
    attendance_approval_snapshot_id
  ),
  constraint attendance_approval_snapshots_id_batch_key unique (
    attendance_approval_snapshot_id,
    attendance_batch_id
  ),
  constraint attendance_approval_snapshots_id_ownership_key unique (
    attendance_approval_snapshot_id,
    attendance_batch_id,
    attendance_version
  ),
  constraint attendance_approval_snapshots_batch_fkey foreign key (attendance_batch_id)
    references atlas_planning.attendance_batches (attendance_batch_id) on delete restrict,
  constraint attendance_approval_snapshots_approved_by_actor_fkey foreign key (
    approved_by_actor_id
  ) references atlas_core.actors (actor_id) on delete restrict,
  constraint attendance_approval_snapshots_batch_version_key unique (
    attendance_batch_id,
    attendance_version
  ),
  constraint attendance_approval_snapshots_version_check check (attendance_version > 0)
);

create index attendance_approval_snapshots_approved_by_actor_idx
  on atlas_planning.attendance_approval_snapshots (approved_by_actor_id);

alter table atlas_planning.attendance_batches
  add constraint attendance_batches_latest_approval_snapshot_fkey foreign key (
    latest_approval_snapshot_id,
    attendance_batch_id
  ) references atlas_planning.attendance_approval_snapshots (
    attendance_approval_snapshot_id,
    attendance_batch_id
  ) on delete restrict;

create index attendance_batches_latest_approval_snapshot_idx
  on atlas_planning.attendance_batches (
    latest_approval_snapshot_id,
    attendance_batch_id
  )
  where latest_approval_snapshot_id is not null;

create table atlas_planning.attendance_approval_snapshot_lines (
  attendance_approval_snapshot_line_id uuid not null default gen_random_uuid(),
  attendance_approval_snapshot_id uuid not null,
  attendance_batch_id uuid not null,
  attendance_version bigint not null,
  attendance_line_id uuid not null,
  school_id uuid not null,
  service_date date not null,
  student_portions integer not null,
  teacher_portions integer not null,
  source_row_reference text,
  constraint attendance_approval_snapshot_lines_pkey primary key (
    attendance_approval_snapshot_line_id
  ),
  constraint attendance_approval_snapshot_lines_snapshot_fkey foreign key (
    attendance_approval_snapshot_id,
    attendance_batch_id,
    attendance_version
  ) references atlas_planning.attendance_approval_snapshots (
    attendance_approval_snapshot_id,
    attendance_batch_id,
    attendance_version
  ) on delete restrict,
  constraint attendance_approval_snapshot_lines_attendance_line_fkey foreign key (
    attendance_line_id,
    attendance_batch_id
  ) references atlas_planning.attendance_lines (
    attendance_line_id,
    attendance_batch_id
  ) on delete restrict,
  constraint attendance_approval_snapshot_lines_school_fkey foreign key (school_id)
    references atlas_admin.schools (school_id) on delete restrict,
  constraint attendance_approval_snapshot_lines_line_key unique (
    attendance_approval_snapshot_id,
    attendance_line_id
  ),
  constraint attendance_approval_snapshot_lines_assignment_key unique (
    attendance_approval_snapshot_id,
    school_id,
    service_date
  ),
  constraint attendance_approval_snapshot_lines_version_check check (
    attendance_version > 0
  ),
  constraint attendance_approval_snapshot_lines_student_portions_check check (
    student_portions >= 0
  ),
  constraint attendance_approval_snapshot_lines_teacher_portions_check check (
    teacher_portions >= 0
  ),
  constraint attendance_approval_snapshot_lines_source_row_reference_check check (
    source_row_reference is null
    or btrim(source_row_reference) <> ''
  )
);

create index attendance_approval_snapshot_lines_snapshot_ownership_idx
  on atlas_planning.attendance_approval_snapshot_lines (
    attendance_approval_snapshot_id,
    attendance_batch_id,
    attendance_version
  );
create index attendance_approval_snapshot_lines_attendance_line_idx
  on atlas_planning.attendance_approval_snapshot_lines (
    attendance_line_id,
    attendance_batch_id
  );
create index attendance_approval_snapshot_lines_school_idx
  on atlas_planning.attendance_approval_snapshot_lines (school_id);

create function atlas_planning.pa_06e_h0a3b_attendance_lifecycle_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  prior_snapshot_version bigint;
begin
  if tg_op = 'INSERT' then
    if new.attendance_status <> 'DRAFT' then
      raise exception using
        errcode = '23514',
        message = 'new attendance batches must enter as DRAFT';
    end if;

    return new;
  end if;

  if tg_op = 'DELETE' then
    if old.attendance_status <> 'DRAFT'
      or old.latest_approval_snapshot_id is not null
    then
      raise exception using
        errcode = '23514',
        message = 'validated or historically approved attendance batches cannot be deleted';
    end if;

    return old;
  end if;

  if new.attendance_batch_id is distinct from old.attendance_batch_id
    or new.period_start is distinct from old.period_start
    or new.period_end is distinct from old.period_end
    or new.created_at is distinct from old.created_at
  then
    raise exception using
      errcode = '23514',
      message = 'attendance batch identity and service-period scope are immutable';
  end if;

  if (
    new.source_type is distinct from old.source_type
    or new.source_name is distinct from old.source_name
    or new.source_signature is distinct from old.source_signature
    or new.row_count is distinct from old.row_count
    or new.imported_by_actor_id is distinct from old.imported_by_actor_id
    or new.imported_at is distinct from old.imported_at
    or new.updated_at is distinct from old.updated_at
  ) and not (
    new.attendance_status = old.attendance_status
    and old.attendance_status in ('DRAFT', 'REOPENED')
  )
  then
    raise exception using
      errcode = '23514',
      message = 'attendance import and source evidence may change only during same-state DRAFT or REOPENED refreshes';
  end if;

  if new.version < old.version
    or new.version > old.version + 1
  then
    raise exception using
      errcode = '23514',
      message = 'attendance version must advance monotonically by at most one';
  end if;

  if old.latest_approval_snapshot_id is not null
    and new.attendance_status <> 'APPROVED'
    and (
      new.latest_approval_snapshot_id is distinct from old.latest_approval_snapshot_id
      or new.latest_approved_by_actor_id is distinct from old.latest_approved_by_actor_id
      or new.latest_approved_at is distinct from old.latest_approved_at
    )
  then
    raise exception using
      errcode = '23514',
      message = 'established attendance approval evidence is immutable across later transitions';
  end if;

  if new.attendance_status is distinct from old.attendance_status
    and new.attendance_status <> 'APPROVED'
    and (
      new.latest_approval_snapshot_id is distinct from old.latest_approval_snapshot_id
      or new.latest_approved_by_actor_id is distinct from old.latest_approved_by_actor_id
      or new.latest_approved_at is distinct from old.latest_approved_at
    )
  then
    raise exception using
      errcode = '23514',
      message = 'attendance approval evidence changes only during approval';
  end if;

  if new.attendance_status = old.attendance_status then
    if old.attendance_status in ('DRAFT', 'REOPENED') then
      if new.version is distinct from old.version
        or new.latest_approval_snapshot_id is distinct from old.latest_approval_snapshot_id
        or new.latest_approved_by_actor_id is distinct from old.latest_approved_by_actor_id
        or new.latest_approved_at is distinct from old.latest_approved_at
      then
        raise exception using
          errcode = '23514',
          message = 'working attendance refreshes preserve version and approval history';
      end if;
    elsif new is distinct from old then
      raise exception using
        errcode = '23514',
        message = 'validated and approved attendance batches change only through lifecycle transitions';
    end if;

    return new;
  end if;

  if not (
    (old.attendance_status = 'DRAFT' and new.attendance_status = 'VALIDATED')
    or (old.attendance_status = 'VALIDATED' and new.attendance_status = 'APPROVED')
    or (
      old.attendance_status = 'APPROVED'
      and new.attendance_status = 'USED_FOR_NEED_GENERATION'
    )
    or (
      old.attendance_status in ('APPROVED', 'USED_FOR_NEED_GENERATION')
      and new.attendance_status = 'REOPENED'
    )
    or (old.attendance_status = 'REOPENED' and new.attendance_status = 'DRAFT')
  ) then
    raise exception using
      errcode = '23514',
      message = 'attendance lifecycle transition is invalid';
  end if;

  if new.attendance_status = 'REOPENED' then
    if new.version <> old.version + 1 then
      raise exception using
        errcode = '23514',
        message = 'reopening attendance must create the next working version';
    end if;
  elsif new.version <> old.version then
    raise exception using
      errcode = '23514',
      message = 'attendance lifecycle transitions preserve the current version except on reopen';
  end if;

  if new.attendance_status = 'APPROVED'
    and old.latest_approval_snapshot_id is not null
  then
    select snapshot.attendance_version
      into prior_snapshot_version
    from atlas_planning.attendance_approval_snapshots snapshot
    where snapshot.attendance_approval_snapshot_id = old.latest_approval_snapshot_id;

    if new.latest_approval_snapshot_id is not distinct from old.latest_approval_snapshot_id
      or new.version <= prior_snapshot_version
    then
      raise exception using
        errcode = '23514',
        message = 'later attendance approval requires a new snapshot for a later version';
    end if;
  end if;

  return new;
end
$$;

create function atlas_planning.pa_06e_h0a3b_attendance_line_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  target_batch atlas_planning.attendance_batches%rowtype;
begin
  if tg_op = 'UPDATE' and (
    new.attendance_line_id is distinct from old.attendance_line_id
    or new.attendance_batch_id is distinct from old.attendance_batch_id
    or new.created_by_actor_id is distinct from old.created_by_actor_id
    or new.created_at is distinct from old.created_at
  ) then
    raise exception using
      errcode = '23514',
      message = 'stable attendance line identity and ownership are immutable';
  end if;

  select batch.*
    into target_batch
  from atlas_planning.attendance_batches batch
  where batch.attendance_batch_id = case
    when tg_op = 'DELETE' then old.attendance_batch_id
    else new.attendance_batch_id
  end;

  if not found then
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;

  if target_batch.attendance_status not in ('DRAFT', 'REOPENED') then
    raise exception using
      errcode = '23514',
      message = 'attendance lines are mutable only while the batch is DRAFT or REOPENED';
  end if;

  if tg_op <> 'DELETE'
    and (
      new.service_date < target_batch.period_start
      or new.service_date > target_batch.period_end
    )
  then
    raise exception using
      errcode = '23514',
      message = 'attendance line service date must be inside the batch service period';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end
$$;

create function atlas_planning.pa_06e_h0a3b_attendance_snapshot_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  target_batch atlas_planning.attendance_batches%rowtype;
  target_snapshot atlas_planning.attendance_approval_snapshots%rowtype;
  target_line atlas_planning.attendance_lines%rowtype;
begin
  if tg_op in ('UPDATE', 'DELETE') then
    raise exception using
      errcode = '23514',
      message = 'attendance approval snapshots and snapshot lines are immutable';
  end if;

  if tg_table_name = 'attendance_approval_snapshots' then
    select batch.*
      into target_batch
    from atlas_planning.attendance_batches batch
    where batch.attendance_batch_id = new.attendance_batch_id;

    if found and (
      target_batch.attendance_status <> 'VALIDATED'
      or new.attendance_version <> target_batch.version
    ) then
      raise exception using
        errcode = '23514',
        message = 'an approval snapshot requires the exact current validated attendance version';
    end if;

    return new;
  end if;

  select snapshot.*
    into target_snapshot
  from atlas_planning.attendance_approval_snapshots snapshot
  where snapshot.attendance_approval_snapshot_id = new.attendance_approval_snapshot_id;

  select line.*
    into target_line
  from atlas_planning.attendance_lines line
  where line.attendance_line_id = new.attendance_line_id;

  if found and (
    target_line.line_status <> 'ACTIVE'
    or new.attendance_batch_id is distinct from target_line.attendance_batch_id
    or new.school_id is distinct from target_line.school_id
    or new.service_date is distinct from target_line.service_date
    or new.student_portions is distinct from target_line.student_portions
    or new.teacher_portions is distinct from target_line.teacher_portions
    or new.source_row_reference is distinct from target_line.source_row_reference
  ) then
    raise exception using
      errcode = '23514',
      message = 'approval snapshot lines must exactly copy active attendance lines';
  end if;

  select batch.*
    into target_batch
  from atlas_planning.attendance_batches batch
  where batch.attendance_batch_id = new.attendance_batch_id;

  if found and (
    target_batch.attendance_status <> 'VALIDATED'
    or new.attendance_version <> target_batch.version
    or new.attendance_version is distinct from target_snapshot.attendance_version
  ) then
    raise exception using
      errcode = '23514',
      message = 'approval snapshot lines require the exact current validated attendance version';
  end if;

  return new;
end
$$;

create function atlas_planning.pa_06e_h0a3b_attendance_snapshot_integrity_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  target_batch atlas_planning.attendance_batches%rowtype;
  target_snapshot atlas_planning.attendance_approval_snapshots%rowtype;
  target_snapshot_id uuid;
begin
  if tg_table_name = 'attendance_batches' then
    if new.attendance_status not in ('APPROVED', 'USED_FOR_NEED_GENERATION') then
      return null;
    end if;

    target_batch := new;
    target_snapshot_id := new.latest_approval_snapshot_id;
  elsif tg_table_name = 'attendance_approval_snapshots' then
    select batch.*
      into target_batch
    from atlas_planning.attendance_batches batch
    where batch.attendance_batch_id = new.attendance_batch_id;
    target_snapshot_id := new.attendance_approval_snapshot_id;
  else
    select batch.*
      into target_batch
    from atlas_planning.attendance_batches batch
    where batch.attendance_batch_id = new.attendance_batch_id;
    target_snapshot_id := new.attendance_approval_snapshot_id;
  end if;

  if target_batch.attendance_status not in ('APPROVED', 'USED_FOR_NEED_GENERATION')
    or target_batch.latest_approval_snapshot_id is distinct from target_snapshot_id
  then
    raise exception using
      errcode = '23514',
      message = 'an approval snapshot must be bound to the approved attendance batch at commit';
  end if;

  select snapshot.*
    into target_snapshot
  from atlas_planning.attendance_approval_snapshots snapshot
  where snapshot.attendance_approval_snapshot_id = target_snapshot_id;

  if not found
    or target_snapshot.attendance_batch_id is distinct from target_batch.attendance_batch_id
    or target_snapshot.attendance_version is distinct from target_batch.version
    or target_snapshot.approved_by_actor_id is distinct from target_batch.latest_approved_by_actor_id
    or target_snapshot.approved_at is distinct from target_batch.latest_approved_at
  then
    raise exception using
      errcode = '23514',
      message = 'approved attendance evidence must match the exact current approval snapshot';
  end if;

  if exists (
    select 1
    from atlas_planning.attendance_lines line
    where line.attendance_batch_id = target_batch.attendance_batch_id
      and line.line_status = 'ACTIVE'
      and not exists (
        select 1
        from atlas_planning.attendance_approval_snapshot_lines snapshot_line
        where snapshot_line.attendance_approval_snapshot_id = target_snapshot_id
          and snapshot_line.attendance_line_id = line.attendance_line_id
          and snapshot_line.attendance_batch_id = line.attendance_batch_id
          and snapshot_line.attendance_version = target_snapshot.attendance_version
          and snapshot_line.school_id = line.school_id
          and snapshot_line.service_date = line.service_date
          and snapshot_line.student_portions = line.student_portions
          and snapshot_line.teacher_portions = line.teacher_portions
          and snapshot_line.source_row_reference is not distinct from line.source_row_reference
      )
  ) then
    raise exception using
      errcode = '23514',
      message = 'approval snapshot must contain every active attendance line exactly once';
  end if;

  if exists (
    select 1
    from atlas_planning.attendance_approval_snapshot_lines snapshot_line
    left join atlas_planning.attendance_lines line
      on line.attendance_line_id = snapshot_line.attendance_line_id
     and line.attendance_batch_id = snapshot_line.attendance_batch_id
    where snapshot_line.attendance_approval_snapshot_id = target_snapshot_id
      and (
        line.attendance_line_id is null
        or line.line_status <> 'ACTIVE'
        or snapshot_line.school_id is distinct from line.school_id
        or snapshot_line.service_date is distinct from line.service_date
        or snapshot_line.student_portions is distinct from line.student_portions
        or snapshot_line.teacher_portions is distinct from line.teacher_portions
        or snapshot_line.source_row_reference is distinct from line.source_row_reference
      )
  ) then
    raise exception using
      errcode = '23514',
      message = 'approval snapshot may contain only exact active attendance lines';
  end if;

  return null;
end
$$;

create trigger attendance_batches_lifecycle_guard
before insert or update or delete on atlas_planning.attendance_batches
for each row execute function atlas_planning.pa_06e_h0a3b_attendance_lifecycle_guard();

create trigger attendance_lines_mutability_guard
before insert or update or delete on atlas_planning.attendance_lines
for each row execute function atlas_planning.pa_06e_h0a3b_attendance_line_guard();

create trigger attendance_approval_snapshots_immutable_guard
before insert or update or delete on atlas_planning.attendance_approval_snapshots
for each row execute function atlas_planning.pa_06e_h0a3b_attendance_snapshot_guard();

create trigger attendance_approval_snapshot_lines_immutable_guard
before insert or update or delete on atlas_planning.attendance_approval_snapshot_lines
for each row execute function atlas_planning.pa_06e_h0a3b_attendance_snapshot_guard();

create constraint trigger attendance_batches_snapshot_integrity_guard
after insert or update on atlas_planning.attendance_batches
deferrable initially deferred
for each row execute function atlas_planning.pa_06e_h0a3b_attendance_snapshot_integrity_guard();

create constraint trigger attendance_approval_snapshots_integrity_guard
after insert on atlas_planning.attendance_approval_snapshots
deferrable initially deferred
for each row execute function atlas_planning.pa_06e_h0a3b_attendance_snapshot_integrity_guard();

create constraint trigger attendance_approval_snapshot_lines_integrity_guard
after insert on atlas_planning.attendance_approval_snapshot_lines
deferrable initially deferred
for each row execute function atlas_planning.pa_06e_h0a3b_attendance_snapshot_integrity_guard();

comment on table atlas_planning.attendance_batches is
  'Stable private Planning root for one inclusive service period and its latest approval evidence.';
comment on table atlas_planning.attendance_lines is
  'Stable school/date exact attendance portions mutable only for DRAFT or REOPENED batches.';
comment on table atlas_planning.attendance_approval_snapshots is
  'Immutable exact approval header for one positive Attendance version.';
comment on table atlas_planning.attendance_approval_snapshot_lines is
  'Immutable typed copy of every and only ACTIVE line accepted in one Attendance approval.';
comment on column atlas_planning.attendance_batches.latest_approval_snapshot_id is
  'Latest historical approval snapshot; APPROVED and USED_FOR_NEED_GENERATION require its exact current version.';

alter table atlas_planning.attendance_batches enable row level security;
alter table atlas_planning.attendance_batches force row level security;
alter table atlas_planning.attendance_lines enable row level security;
alter table atlas_planning.attendance_lines force row level security;
alter table atlas_planning.attendance_approval_snapshots enable row level security;
alter table atlas_planning.attendance_approval_snapshots force row level security;
alter table atlas_planning.attendance_approval_snapshot_lines enable row level security;
alter table atlas_planning.attendance_approval_snapshot_lines force row level security;

revoke all on table atlas_planning.attendance_batches
  from public, anon, authenticated, service_role;
revoke all on table atlas_planning.attendance_lines
  from public, anon, authenticated, service_role;
revoke all on table atlas_planning.attendance_approval_snapshots
  from public, anon, authenticated, service_role;
revoke all on table atlas_planning.attendance_approval_snapshot_lines
  from public, anon, authenticated, service_role;

revoke execute on function atlas_planning.pa_06e_h0a3b_attendance_lifecycle_guard()
  from public, anon, authenticated, service_role;
revoke execute on function atlas_planning.pa_06e_h0a3b_attendance_line_guard()
  from public, anon, authenticated, service_role;
revoke execute on function atlas_planning.pa_06e_h0a3b_attendance_snapshot_guard()
  from public, anon, authenticated, service_role;
revoke execute on function atlas_planning.pa_06e_h0a3b_attendance_snapshot_integrity_guard()
  from public, anon, authenticated, service_role;

reset role;
