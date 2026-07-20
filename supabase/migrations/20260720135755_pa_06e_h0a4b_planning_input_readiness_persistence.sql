-- PA-06E-H0A4b Planning Input Readiness persistence.
-- Private persistence and invariant enforcement only: no API, command, role,
-- capability, seed, upstream trigger, or hosted-system change is introduced.

set role atlas_owner;

create table atlas_planning.planning_input_sets (
  planning_input_set_id uuid not null default gen_random_uuid(),
  period_start date not null,
  period_end date not null,
  readiness_status text not null,
  current_evaluation_id uuid not null,
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp(),
  constraint planning_input_sets_pkey primary key (planning_input_set_id),
  constraint planning_input_sets_period_key unique (period_start, period_end),
  constraint planning_input_sets_period_check check (period_end >= period_start),
  constraint planning_input_sets_status_check check (
    readiness_status in (
      'NOT_READY',
      'READY',
      'NEED_GENERATION_REQUESTED',
      'INVALIDATED'
    )
  ),
  constraint planning_input_sets_timestamps_check check (
    updated_at >= created_at
  )
);

create table atlas_planning.planning_input_evaluations (
  planning_input_evaluation_id uuid not null default gen_random_uuid(),
  planning_input_set_id uuid not null,
  evaluation_version bigint not null,
  evaluation_result text not null,
  weekly_menu_id uuid,
  weekly_menu_version bigint,
  weekly_menu_approval_snapshot_id uuid,
  attendance_batch_id uuid,
  attendance_version bigint,
  attendance_approval_snapshot_id uuid,
  blocking_issue_count integer not null,
  warning_count integer not null,
  evaluated_by_actor_id uuid not null,
  evaluated_at timestamptz not null default transaction_timestamp(),
  constraint planning_input_evaluations_pkey primary key (
    planning_input_evaluation_id
  ),
  constraint planning_input_evaluations_id_set_key unique (
    planning_input_evaluation_id,
    planning_input_set_id
  ),
  constraint planning_input_evaluations_ownership_key unique (
    planning_input_evaluation_id,
    planning_input_set_id,
    evaluation_version
  ),
  constraint planning_input_evaluations_set_version_key unique (
    planning_input_set_id,
    evaluation_version
  ),
  constraint planning_input_evaluations_set_fkey foreign key (
    planning_input_set_id
  ) references atlas_planning.planning_input_sets (
    planning_input_set_id
  ) on delete restrict,
  constraint planning_input_evaluations_weekly_menu_snapshot_fkey foreign key (
    weekly_menu_approval_snapshot_id,
    weekly_menu_id,
    weekly_menu_version
  ) references atlas_planning.weekly_menu_approval_snapshots (
    weekly_menu_approval_snapshot_id,
    weekly_menu_id,
    weekly_menu_version
  ) on delete restrict,
  constraint planning_input_evaluations_attendance_snapshot_fkey foreign key (
    attendance_approval_snapshot_id,
    attendance_batch_id,
    attendance_version
  ) references atlas_planning.attendance_approval_snapshots (
    attendance_approval_snapshot_id,
    attendance_batch_id,
    attendance_version
  ) on delete restrict,
  constraint planning_input_evaluations_actor_fkey foreign key (
    evaluated_by_actor_id
  ) references atlas_core.actors (actor_id) on delete restrict,
  constraint planning_input_evaluations_version_check check (
    evaluation_version > 0
  ),
  constraint planning_input_evaluations_result_check check (
    evaluation_result in ('NOT_READY', 'READY')
  ),
  constraint planning_input_evaluations_weekly_menu_family_check check (
    (
      weekly_menu_id is null
      and weekly_menu_version is null
      and weekly_menu_approval_snapshot_id is null
    )
    or (
      weekly_menu_id is not null
      and weekly_menu_version is not null
      and weekly_menu_approval_snapshot_id is not null
    )
  ),
  constraint planning_input_evaluations_attendance_family_check check (
    (
      attendance_batch_id is null
      and attendance_version is null
      and attendance_approval_snapshot_id is null
    )
    or (
      attendance_batch_id is not null
      and attendance_version is not null
      and attendance_approval_snapshot_id is not null
    )
  ),
  constraint planning_input_evaluations_blocking_issue_count_check check (
    blocking_issue_count >= 0
  ),
  constraint planning_input_evaluations_warning_count_check check (
    warning_count >= 0
  )
);

alter table atlas_planning.planning_input_sets
  add constraint planning_input_sets_current_evaluation_fkey foreign key (
    current_evaluation_id,
    planning_input_set_id
  ) references atlas_planning.planning_input_evaluations (
    planning_input_evaluation_id,
    planning_input_set_id
  ) on delete restrict deferrable initially deferred;

create index planning_input_sets_current_evaluation_idx
  on atlas_planning.planning_input_sets (
    current_evaluation_id,
    planning_input_set_id
  );
create index planning_input_evaluations_weekly_menu_snapshot_idx
  on atlas_planning.planning_input_evaluations (
    weekly_menu_approval_snapshot_id,
    weekly_menu_id,
    weekly_menu_version
  )
  where weekly_menu_approval_snapshot_id is not null;
create index planning_input_evaluations_attendance_snapshot_idx
  on atlas_planning.planning_input_evaluations (
    attendance_approval_snapshot_id,
    attendance_batch_id,
    attendance_version
  )
  where attendance_approval_snapshot_id is not null;
create index planning_input_evaluations_actor_idx
  on atlas_planning.planning_input_evaluations (evaluated_by_actor_id);

create table atlas_planning.planning_input_evaluation_issues (
  planning_input_readiness_issue_id uuid not null default gen_random_uuid(),
  planning_input_evaluation_id uuid not null,
  planning_input_set_id uuid not null,
  evaluation_version bigint not null,
  severity text not null,
  issue_code text not null,
  message text not null,
  input_type text,
  school_id uuid,
  service_date date,
  constraint planning_input_evaluation_issues_pkey primary key (
    planning_input_readiness_issue_id
  ),
  constraint planning_input_evaluation_issues_evaluation_fkey foreign key (
    planning_input_evaluation_id,
    planning_input_set_id,
    evaluation_version
  ) references atlas_planning.planning_input_evaluations (
    planning_input_evaluation_id,
    planning_input_set_id,
    evaluation_version
  ) on delete restrict,
  constraint planning_input_evaluation_issues_school_fkey foreign key (
    school_id
  ) references atlas_admin.schools (school_id) on delete restrict,
  constraint planning_input_evaluation_issues_context_key unique nulls not distinct (
    planning_input_evaluation_id,
    issue_code,
    input_type,
    school_id,
    service_date
  ),
  constraint planning_input_evaluation_issues_version_check check (
    evaluation_version > 0
  ),
  constraint planning_input_evaluation_issues_severity_check check (
    severity in ('BLOCKING', 'WARNING')
  ),
  constraint planning_input_evaluation_issues_code_check check (
    issue_code in (
      'MISSING_WEEKLY_MENU_APPROVAL_SNAPSHOT',
      'MISSING_ATTENDANCE_APPROVAL_SNAPSHOT',
      'SOURCE_SNAPSHOT_OWNERSHIP_MISMATCH',
      'WEEKLY_MENU_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD',
      'ATTENDANCE_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD',
      'STALE_OR_MISMATCHED_SNAPSHOT_BINDING',
      'REQUEST_WITHOUT_CURRENT_READY_EVALUATION',
      'MENU_SCHOOL_DATE_WITHOUT_ATTENDANCE',
      'ATTENDANCE_SCHOOL_DATE_WITHOUT_MENU',
      'ZERO_ATTENDANCE_FOR_PLANNED_MENU'
    )
  ),
  constraint planning_input_evaluation_issues_severity_code_check check (
    (
      severity = 'BLOCKING'
      and issue_code in (
        'MISSING_WEEKLY_MENU_APPROVAL_SNAPSHOT',
        'MISSING_ATTENDANCE_APPROVAL_SNAPSHOT',
        'SOURCE_SNAPSHOT_OWNERSHIP_MISMATCH',
        'WEEKLY_MENU_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD',
        'ATTENDANCE_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD',
        'STALE_OR_MISMATCHED_SNAPSHOT_BINDING',
        'REQUEST_WITHOUT_CURRENT_READY_EVALUATION'
      )
    )
    or (
      severity = 'WARNING'
      and issue_code in (
        'MENU_SCHOOL_DATE_WITHOUT_ATTENDANCE',
        'ATTENDANCE_SCHOOL_DATE_WITHOUT_MENU',
        'ZERO_ATTENDANCE_FOR_PLANNED_MENU'
      )
    )
  ),
  constraint planning_input_evaluation_issues_message_check check (
    btrim(message) <> ''
  ),
  constraint planning_input_evaluation_issues_input_type_check check (
    input_type is null or input_type in ('WEEKLY_MENU', 'ATTENDANCE')
  )
);

create index planning_input_evaluation_issues_evaluation_idx
  on atlas_planning.planning_input_evaluation_issues (
    planning_input_evaluation_id,
    planning_input_set_id,
    evaluation_version
  );
create index planning_input_evaluation_issues_school_idx
  on atlas_planning.planning_input_evaluation_issues (school_id)
  where school_id is not null;

create function atlas_planning.pa_06e_h0a4b_planning_input_set_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_current atlas_planning.planning_input_evaluations%rowtype;
  v_next atlas_planning.planning_input_evaluations%rowtype;
  v_request_ready boolean;
begin
  if tg_op = 'DELETE' then
    raise exception using
      errcode = '23514',
      message = 'planning input sets cannot be deleted';
  end if;

  if tg_op = 'INSERT' then
    if new.readiness_status not in ('NOT_READY', 'READY') then
      raise exception using
        errcode = '23514',
        message = 'the first readiness status must be NOT_READY or READY';
    end if;
    return new;
  end if;

  if new.planning_input_set_id is distinct from old.planning_input_set_id
    or new.period_start is distinct from old.period_start
    or new.period_end is distinct from old.period_end
    or new.created_at is distinct from old.created_at
  then
    raise exception using
      errcode = '23514',
      message = 'planning input set identity, period, and creation time are immutable';
  end if;

  select evaluation.*
  into v_current
  from atlas_planning.planning_input_evaluations as evaluation
  where evaluation.planning_input_evaluation_id = old.current_evaluation_id
    and evaluation.planning_input_set_id = old.planning_input_set_id;

  if new.current_evaluation_id is distinct from old.current_evaluation_id then
    if old.readiness_status not in ('NOT_READY', 'INVALIDATED')
      or new.readiness_status not in ('NOT_READY', 'READY')
    then
      raise exception using
        errcode = '23514',
        message = 'only NOT_READY or INVALIDATED input sets may receive a successor evaluation';
    end if;

    select evaluation.*
    into v_next
    from atlas_planning.planning_input_evaluations as evaluation
    where evaluation.planning_input_evaluation_id = new.current_evaluation_id
      and evaluation.planning_input_set_id = new.planning_input_set_id;

    if v_next.planning_input_evaluation_id is null
      or v_current.planning_input_evaluation_id is null
      or v_next.evaluation_version <> v_current.evaluation_version + 1
      or v_next.evaluation_result <> new.readiness_status
    then
      raise exception using
        errcode = '23514',
        message = 'the new current evaluation must be the exact next root-local version and match root status';
    end if;

    return new;
  end if;

  if old.readiness_status = 'READY'
    and new.readiness_status = 'NEED_GENERATION_REQUESTED'
  then
    select exists (
      select 1
      from atlas_planning.planning_input_evaluations as evaluation
      join atlas_planning.weekly_menus as weekly_menu
        on weekly_menu.weekly_menu_id = evaluation.weekly_menu_id
      join atlas_planning.attendance_batches as attendance
        on attendance.attendance_batch_id = evaluation.attendance_batch_id
      where evaluation.planning_input_evaluation_id = old.current_evaluation_id
        and evaluation.planning_input_set_id = old.planning_input_set_id
        and evaluation.evaluation_result = 'READY'
        and evaluation.blocking_issue_count = 0
        and evaluation.weekly_menu_id is not null
        and evaluation.attendance_batch_id is not null
        and weekly_menu.version = evaluation.weekly_menu_version
        and weekly_menu.latest_approval_snapshot_id = evaluation.weekly_menu_approval_snapshot_id
        and weekly_menu.weekly_menu_status in ('APPROVED', 'NEED_GENERATION_REQUESTED')
        and weekly_menu.week_start <= old.period_start
        and weekly_menu.week_end >= old.period_end
        and attendance.version = evaluation.attendance_version
        and attendance.latest_approval_snapshot_id = evaluation.attendance_approval_snapshot_id
        and attendance.attendance_status in ('APPROVED', 'USED_FOR_NEED_GENERATION')
        and attendance.period_start <= old.period_start
        and attendance.period_end >= old.period_end
    ) into v_request_ready;

    if not v_request_ready then
      raise exception using
        errcode = '23514',
        message = 'need generation requires the current READY evaluation and exact current source snapshots';
    end if;
    return new;
  end if;

  if (old.readiness_status = 'READY' and new.readiness_status = 'INVALIDATED')
    or (
      old.readiness_status = 'NEED_GENERATION_REQUESTED'
      and new.readiness_status = 'INVALIDATED'
    )
  then
    return new;
  end if;

  raise exception using
    errcode = '23514',
    message = 'invalid planning input readiness lifecycle transition';
end;
$$;

create function atlas_planning.pa_06e_h0a4b_planning_input_evaluation_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_root atlas_planning.planning_input_sets%rowtype;
  v_current_version bigint;
  v_evaluation_count bigint;
begin
  if tg_op in ('UPDATE', 'DELETE') then
    raise exception using
      errcode = '23514',
      message = 'planning input evaluations are immutable and nondeletable';
  end if;

  select input_set.*
  into v_root
  from atlas_planning.planning_input_sets as input_set
  where input_set.planning_input_set_id = new.planning_input_set_id
  for update;

  if v_root.planning_input_set_id is null then
    raise exception using
      errcode = '23503',
      message = 'planning input evaluation requires its root';
  end if;

  if v_root.current_evaluation_id = new.planning_input_evaluation_id then
    select count(*)
    into v_evaluation_count
    from atlas_planning.planning_input_evaluations as evaluation
    where evaluation.planning_input_set_id = new.planning_input_set_id;

    if v_evaluation_count <> 0
      or new.evaluation_version <> 1
      or v_root.readiness_status <> new.evaluation_result
      or v_root.readiness_status not in ('NOT_READY', 'READY')
    then
      raise exception using
        errcode = '23514',
        message = 'the first evaluation must be version 1 and match the new root';
    end if;
    return new;
  end if;

  if v_root.readiness_status not in ('NOT_READY', 'INVALIDATED') then
    raise exception using
      errcode = '23514',
      message = 'the current readiness status does not permit re-evaluation';
  end if;

  select evaluation.evaluation_version
  into v_current_version
  from atlas_planning.planning_input_evaluations as evaluation
  where evaluation.planning_input_evaluation_id = v_root.current_evaluation_id
    and evaluation.planning_input_set_id = v_root.planning_input_set_id;

  if v_current_version is null
    or new.evaluation_version <> v_current_version + 1
  then
    raise exception using
      errcode = '23514',
      message = 'successor evaluations must use the exact next root-local version';
  end if;

  return new;
end;
$$;

create function atlas_planning.pa_06e_h0a4b_planning_input_issue_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_root atlas_planning.planning_input_sets%rowtype;
  v_issue_evaluation_version bigint;
  v_current_evaluation_version bigint;
begin
  if tg_op in ('UPDATE', 'DELETE') then
    raise exception using
      errcode = '23514',
      message = 'planning input evaluation issues are immutable and nondeletable';
  end if;

  select evaluation.evaluation_version
  into v_issue_evaluation_version
  from atlas_planning.planning_input_evaluations as evaluation
  where evaluation.planning_input_evaluation_id = new.planning_input_evaluation_id
    and evaluation.planning_input_set_id = new.planning_input_set_id
    and evaluation.evaluation_version = new.evaluation_version;

  select input_set.*
  into v_root
  from atlas_planning.planning_input_sets as input_set
  where input_set.planning_input_set_id = new.planning_input_set_id;

  select evaluation.evaluation_version
  into v_current_evaluation_version
  from atlas_planning.planning_input_evaluations as evaluation
  where evaluation.planning_input_evaluation_id = v_root.current_evaluation_id
    and evaluation.planning_input_set_id = v_root.planning_input_set_id;

  if v_issue_evaluation_version is null
    or v_root.planning_input_set_id is null
    or not (
      v_root.current_evaluation_id = new.planning_input_evaluation_id
      or (
        v_root.readiness_status in ('NOT_READY', 'INVALIDATED')
        and v_issue_evaluation_version = v_current_evaluation_version + 1
      )
    )
  then
    raise exception using
      errcode = '23514',
      message = 'issues may be inserted only for the current or pending successor evaluation';
  end if;

  return new;
end;
$$;

create function atlas_planning.pa_06e_h0a4b_planning_input_integrity_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_set_id uuid;
  v_root atlas_planning.planning_input_sets%rowtype;
  v_evaluation atlas_planning.planning_input_evaluations%rowtype;
  v_evaluation_count bigint;
  v_min_version bigint;
  v_max_version bigint;
  v_blocking_count bigint;
  v_warning_count bigint;
  v_expected_warning_count bigint;
  v_weekly_current boolean := false;
  v_attendance_current boolean := false;
  v_weekly_covers boolean := false;
  v_attendance_covers boolean := false;
begin
  if tg_table_name = 'planning_input_sets' then
    v_set_id := new.planning_input_set_id;
  else
    v_set_id := new.planning_input_set_id;
  end if;

  select input_set.*
  into v_root
  from atlas_planning.planning_input_sets as input_set
  where input_set.planning_input_set_id = v_set_id;

  select evaluation.*
  into v_evaluation
  from atlas_planning.planning_input_evaluations as evaluation
  where evaluation.planning_input_evaluation_id = v_root.current_evaluation_id
    and evaluation.planning_input_set_id = v_root.planning_input_set_id;

  if v_root.planning_input_set_id is null
    or v_evaluation.planning_input_evaluation_id is null
  then
    raise exception using
      errcode = '23514',
      message = 'planning input set must commit with one exact current evaluation';
  end if;

  select count(*), min(evaluation.evaluation_version), max(evaluation.evaluation_version)
  into v_evaluation_count, v_min_version, v_max_version
  from atlas_planning.planning_input_evaluations as evaluation
  where evaluation.planning_input_set_id = v_set_id;

  if v_min_version <> 1
    or v_max_version <> v_evaluation_count
    or v_evaluation.evaluation_version <> v_max_version
  then
    raise exception using
      errcode = '23514',
      message = 'evaluation history must be contiguous and the root must point to its latest version';
  end if;

  if (
    v_root.readiness_status = 'NOT_READY'
    and v_evaluation.evaluation_result <> 'NOT_READY'
  ) or (
    v_root.readiness_status in ('READY', 'NEED_GENERATION_REQUESTED')
    and v_evaluation.evaluation_result <> 'READY'
  ) then
    raise exception using
      errcode = '23514',
      message = 'root readiness status does not match its current evaluation';
  end if;

  select
    count(*) filter (where issue.severity = 'BLOCKING'),
    count(*) filter (where issue.severity = 'WARNING')
  into v_blocking_count, v_warning_count
  from atlas_planning.planning_input_evaluation_issues as issue
  where issue.planning_input_evaluation_id = v_evaluation.planning_input_evaluation_id;

  if v_blocking_count <> v_evaluation.blocking_issue_count
    or v_warning_count <> v_evaluation.warning_count
  then
    raise exception using
      errcode = '23514',
      message = 'evaluation issue counts must exactly match immutable issue rows';
  end if;

  if v_evaluation.evaluation_result = 'READY' and v_blocking_count <> 0 then
    raise exception using
      errcode = '23514',
      message = 'READY evaluations cannot contain blocking issues';
  end if;

  if v_evaluation.evaluation_result = 'NOT_READY' and v_blocking_count < 1 then
    raise exception using
      errcode = '23514',
      message = 'NOT_READY evaluations require at least one blocking issue';
  end if;

  if v_evaluation.weekly_menu_id is not null then
    select
      weekly_menu.week_start <= v_root.period_start
        and weekly_menu.week_end >= v_root.period_end,
      weekly_menu.version = v_evaluation.weekly_menu_version
        and weekly_menu.latest_approval_snapshot_id = v_evaluation.weekly_menu_approval_snapshot_id
        and weekly_menu.weekly_menu_status in ('APPROVED', 'NEED_GENERATION_REQUESTED')
    into v_weekly_covers, v_weekly_current
    from atlas_planning.weekly_menus as weekly_menu
    where weekly_menu.weekly_menu_id = v_evaluation.weekly_menu_id;
  end if;

  if v_evaluation.attendance_batch_id is not null then
    select
      attendance.period_start <= v_root.period_start
        and attendance.period_end >= v_root.period_end,
      attendance.version = v_evaluation.attendance_version
        and attendance.latest_approval_snapshot_id = v_evaluation.attendance_approval_snapshot_id
        and attendance.attendance_status in ('APPROVED', 'USED_FOR_NEED_GENERATION')
    into v_attendance_covers, v_attendance_current
    from atlas_planning.attendance_batches as attendance
    where attendance.attendance_batch_id = v_evaluation.attendance_batch_id;
  end if;

  if v_root.readiness_status <> 'INVALIDATED' then
    if v_evaluation.evaluation_result = 'READY'
      and (
        v_evaluation.weekly_menu_id is null
        or v_evaluation.attendance_batch_id is null
        or not v_weekly_covers
        or not v_attendance_covers
        or not v_weekly_current
        or not v_attendance_current
      )
    then
      raise exception using
        errcode = '23514',
        message = 'READY requires both exact current source snapshots covering the evaluated period';
    end if;

    if v_evaluation.evaluation_result = 'NOT_READY' then
      if v_evaluation.weekly_menu_id is null
        and not exists (
          select 1
          from atlas_planning.planning_input_evaluation_issues as issue
          where issue.planning_input_evaluation_id = v_evaluation.planning_input_evaluation_id
            and issue.severity = 'BLOCKING'
            and issue.issue_code = 'MISSING_WEEKLY_MENU_APPROVAL_SNAPSHOT'
        )
      then
        raise exception using
          errcode = '23514',
          message = 'a missing Weekly Menu binding requires its exact blocker';
      end if;

      if v_evaluation.attendance_batch_id is null
        and not exists (
          select 1
          from atlas_planning.planning_input_evaluation_issues as issue
          where issue.planning_input_evaluation_id = v_evaluation.planning_input_evaluation_id
            and issue.severity = 'BLOCKING'
            and issue.issue_code = 'MISSING_ATTENDANCE_APPROVAL_SNAPSHOT'
        )
      then
        raise exception using
          errcode = '23514',
          message = 'a missing Attendance binding requires its exact blocker';
      end if;

      if v_evaluation.weekly_menu_id is not null
        and not v_weekly_covers
        and not exists (
          select 1
          from atlas_planning.planning_input_evaluation_issues as issue
          where issue.planning_input_evaluation_id = v_evaluation.planning_input_evaluation_id
            and issue.severity = 'BLOCKING'
            and issue.issue_code = 'WEEKLY_MENU_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD'
        )
      then
        raise exception using
          errcode = '23514',
          message = 'insufficient Weekly Menu coverage requires its exact blocker';
      end if;

      if v_evaluation.attendance_batch_id is not null
        and not v_attendance_covers
        and not exists (
          select 1
          from atlas_planning.planning_input_evaluation_issues as issue
          where issue.planning_input_evaluation_id = v_evaluation.planning_input_evaluation_id
            and issue.severity = 'BLOCKING'
            and issue.issue_code = 'ATTENDANCE_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD'
        )
      then
        raise exception using
          errcode = '23514',
          message = 'insufficient Attendance coverage requires its exact blocker';
      end if;

      if (
        (v_evaluation.weekly_menu_id is not null and not v_weekly_current)
        or (v_evaluation.attendance_batch_id is not null and not v_attendance_current)
      ) and not exists (
        select 1
        from atlas_planning.planning_input_evaluation_issues as issue
        where issue.planning_input_evaluation_id = v_evaluation.planning_input_evaluation_id
          and issue.severity = 'BLOCKING'
          and issue.issue_code = 'STALE_OR_MISMATCHED_SNAPSHOT_BINDING'
      )
      then
        raise exception using
          errcode = '23514',
          message = 'stale source bindings require the exact stale-binding blocker';
      end if;
    end if;
  end if;

  with menu_days as (
    select distinct line.school_id, line.service_date
    from atlas_planning.weekly_menu_approval_snapshot_lines as line
    where line.weekly_menu_approval_snapshot_id = v_evaluation.weekly_menu_approval_snapshot_id
      and v_evaluation.weekly_menu_id is not null
      and v_evaluation.attendance_batch_id is not null
      and line.service_date between v_root.period_start and v_root.period_end
  ), attendance_days as (
    select line.school_id, line.service_date,
      line.student_portions + line.teacher_portions as total_portions
    from atlas_planning.attendance_approval_snapshot_lines as line
    where line.attendance_approval_snapshot_id = v_evaluation.attendance_approval_snapshot_id
      and v_evaluation.weekly_menu_id is not null
      and v_evaluation.attendance_batch_id is not null
      and line.service_date between v_root.period_start and v_root.period_end
  ), expected_warnings as (
    select
      'MENU_SCHOOL_DATE_WITHOUT_ATTENDANCE'::text as issue_code,
      menu.school_id,
      menu.service_date
    from menu_days as menu
    where not exists (
      select 1
      from attendance_days as attendance
      where attendance.school_id = menu.school_id
        and attendance.service_date = menu.service_date
    )
    union all
    select
      'ATTENDANCE_SCHOOL_DATE_WITHOUT_MENU'::text,
      attendance.school_id,
      attendance.service_date
    from attendance_days as attendance
    where not exists (
      select 1
      from menu_days as menu
      where menu.school_id = attendance.school_id
        and menu.service_date = attendance.service_date
    )
    union all
    select
      'ZERO_ATTENDANCE_FOR_PLANNED_MENU'::text,
      attendance.school_id,
      attendance.service_date
    from attendance_days as attendance
    where attendance.total_portions = 0
      and exists (
        select 1
        from menu_days as menu
        where menu.school_id = attendance.school_id
          and menu.service_date = attendance.service_date
      )
  )
  select count(*)
  into v_expected_warning_count
  from expected_warnings;

  if v_warning_count <> v_expected_warning_count
    or exists (
      with menu_days as (
        select distinct line.school_id, line.service_date
        from atlas_planning.weekly_menu_approval_snapshot_lines as line
        where line.weekly_menu_approval_snapshot_id = v_evaluation.weekly_menu_approval_snapshot_id
          and v_evaluation.weekly_menu_id is not null
          and v_evaluation.attendance_batch_id is not null
          and line.service_date between v_root.period_start and v_root.period_end
      ), attendance_days as (
        select line.school_id, line.service_date,
          line.student_portions + line.teacher_portions as total_portions
        from atlas_planning.attendance_approval_snapshot_lines as line
        where line.attendance_approval_snapshot_id = v_evaluation.attendance_approval_snapshot_id
          and v_evaluation.weekly_menu_id is not null
          and v_evaluation.attendance_batch_id is not null
          and line.service_date between v_root.period_start and v_root.period_end
      ), expected_warnings as (
        select
          'MENU_SCHOOL_DATE_WITHOUT_ATTENDANCE'::text as issue_code,
          menu.school_id,
          menu.service_date
        from menu_days as menu
        where not exists (
          select 1
          from attendance_days as attendance
          where attendance.school_id = menu.school_id
            and attendance.service_date = menu.service_date
        )
        union all
        select
          'ATTENDANCE_SCHOOL_DATE_WITHOUT_MENU'::text,
          attendance.school_id,
          attendance.service_date
        from attendance_days as attendance
        where not exists (
          select 1
          from menu_days as menu
          where menu.school_id = attendance.school_id
            and menu.service_date = attendance.service_date
        )
        union all
        select
          'ZERO_ATTENDANCE_FOR_PLANNED_MENU'::text,
          attendance.school_id,
          attendance.service_date
        from attendance_days as attendance
        where attendance.total_portions = 0
          and exists (
            select 1
            from menu_days as menu
            where menu.school_id = attendance.school_id
              and menu.service_date = attendance.service_date
          )
      ), actual_warnings as (
        select issue.issue_code, issue.school_id, issue.service_date
        from atlas_planning.planning_input_evaluation_issues as issue
        where issue.planning_input_evaluation_id = v_evaluation.planning_input_evaluation_id
          and issue.severity = 'WARNING'
      )
      select 1
      from (
        (select * from expected_warnings except select * from actual_warnings)
        union all
        (select * from actual_warnings except select * from expected_warnings)
      ) as warning_difference
    )
  then
    raise exception using
      errcode = '23514',
      message = 'warning rows must exactly match source snapshot observations in the evaluated period';
  end if;

  return new;
end;
$$;

create trigger planning_input_sets_guard
before insert or update or delete on atlas_planning.planning_input_sets
for each row execute function atlas_planning.pa_06e_h0a4b_planning_input_set_guard();

create trigger planning_input_evaluations_guard
before insert or update or delete on atlas_planning.planning_input_evaluations
for each row execute function atlas_planning.pa_06e_h0a4b_planning_input_evaluation_guard();

create trigger planning_input_evaluation_issues_guard
before insert or update or delete on atlas_planning.planning_input_evaluation_issues
for each row execute function atlas_planning.pa_06e_h0a4b_planning_input_issue_guard();

create constraint trigger planning_input_sets_integrity
after insert or update on atlas_planning.planning_input_sets
deferrable initially deferred
for each row execute function atlas_planning.pa_06e_h0a4b_planning_input_integrity_guard();

create constraint trigger planning_input_evaluations_integrity
after insert on atlas_planning.planning_input_evaluations
deferrable initially deferred
for each row execute function atlas_planning.pa_06e_h0a4b_planning_input_integrity_guard();

create constraint trigger planning_input_evaluation_issues_integrity
after insert on atlas_planning.planning_input_evaluation_issues
deferrable initially deferred
for each row execute function atlas_planning.pa_06e_h0a4b_planning_input_integrity_guard();

alter table atlas_planning.planning_input_sets enable row level security;
alter table atlas_planning.planning_input_sets force row level security;
alter table atlas_planning.planning_input_evaluations enable row level security;
alter table atlas_planning.planning_input_evaluations force row level security;
alter table atlas_planning.planning_input_evaluation_issues enable row level security;
alter table atlas_planning.planning_input_evaluation_issues force row level security;

revoke all on table atlas_planning.planning_input_sets
  from public, anon, authenticated, service_role;
revoke all on table atlas_planning.planning_input_evaluations
  from public, anon, authenticated, service_role;
revoke all on table atlas_planning.planning_input_evaluation_issues
  from public, anon, authenticated, service_role;

revoke all on function atlas_planning.pa_06e_h0a4b_planning_input_set_guard()
  from public, anon, authenticated, service_role;
revoke all on function atlas_planning.pa_06e_h0a4b_planning_input_evaluation_guard()
  from public, anon, authenticated, service_role;
revoke all on function atlas_planning.pa_06e_h0a4b_planning_input_issue_guard()
  from public, anon, authenticated, service_role;
revoke all on function atlas_planning.pa_06e_h0a4b_planning_input_integrity_guard()
  from public, anon, authenticated, service_role;

reset role;
