-- PANTRY-RDY-02 Planning Input Readiness persistence amendment.
-- Adds exact Pantry approval-snapshot lineage to new readiness evaluations
-- and request decisions without backfilling or rewriting historical evidence.

set role atlas_owner;

alter table atlas_planning.planning_input_evaluations
  add column pantry_need_batch_id uuid,
  add column pantry_need_batch_version bigint,
  add column pantry_need_approval_snapshot_id uuid,
  add constraint planning_input_evaluations_pantry_family_check check (
    (
      pantry_need_batch_id is null
      and pantry_need_batch_version is null
      and pantry_need_approval_snapshot_id is null
    )
    or (
      pantry_need_batch_id is not null
      and pantry_need_batch_version is not null
      and pantry_need_batch_version > 0
      and pantry_need_approval_snapshot_id is not null
    )
  );

alter table atlas_planning.pantry_need_approval_snapshots
  add constraint pantry_need_approval_snapshots_readiness_ownership_key unique (
    pantry_need_approval_snapshot_id,
    pantry_need_batch_id,
    approved_batch_version
  );

alter table atlas_planning.planning_input_evaluations
  add constraint planning_input_evaluations_pantry_snapshot_fkey foreign key (
    pantry_need_approval_snapshot_id,
    pantry_need_batch_id,
    pantry_need_batch_version
  ) references atlas_planning.pantry_need_approval_snapshots (
    pantry_need_approval_snapshot_id,
    pantry_need_batch_id,
    approved_batch_version
  ) on delete restrict;

create index planning_input_evaluations_pantry_snapshot_idx
  on atlas_planning.planning_input_evaluations (
    pantry_need_approval_snapshot_id,
    pantry_need_batch_id,
    pantry_need_batch_version
  )
  where pantry_need_approval_snapshot_id is not null;

alter table atlas_planning.planning_input_evaluation_issues
  drop constraint planning_input_evaluation_issues_code_check,
  drop constraint planning_input_evaluation_issues_severity_code_check,
  drop constraint planning_input_evaluation_issues_input_type_check,
  add constraint planning_input_evaluation_issues_code_check check (
    issue_code in (
      'MISSING_WEEKLY_MENU_APPROVAL_SNAPSHOT',
      'MISSING_ATTENDANCE_APPROVAL_SNAPSHOT',
      'MISSING_PANTRY_APPROVAL_SNAPSHOT',
      'SOURCE_SNAPSHOT_OWNERSHIP_MISMATCH',
      'WEEKLY_MENU_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD',
      'ATTENDANCE_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD',
      'PANTRY_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD',
      'STALE_OR_MISMATCHED_SNAPSHOT_BINDING',
      'REQUEST_WITHOUT_CURRENT_READY_EVALUATION',
      'MENU_SCHOOL_DATE_WITHOUT_ATTENDANCE',
      'ATTENDANCE_SCHOOL_DATE_WITHOUT_MENU',
      'ZERO_ATTENDANCE_FOR_PLANNED_MENU'
    )
  ),
  add constraint planning_input_evaluation_issues_severity_code_check check (
    (
      severity = 'BLOCKING'
      and issue_code in (
        'MISSING_WEEKLY_MENU_APPROVAL_SNAPSHOT',
        'MISSING_ATTENDANCE_APPROVAL_SNAPSHOT',
        'MISSING_PANTRY_APPROVAL_SNAPSHOT',
        'SOURCE_SNAPSHOT_OWNERSHIP_MISMATCH',
        'WEEKLY_MENU_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD',
        'ATTENDANCE_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD',
        'PANTRY_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD',
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
  add constraint planning_input_evaluation_issues_input_type_check check (
    input_type is null
    or input_type in ('WEEKLY_MENU', 'ATTENDANCE', 'PANTRY')
  );

create or replace function atlas_planning.pa_06e_h0a4b_planning_input_set_guard()
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
      join atlas_planning.pantry_need_batches as pantry
        on pantry.pantry_need_batch_id = evaluation.pantry_need_batch_id
      where evaluation.planning_input_evaluation_id = old.current_evaluation_id
        and evaluation.planning_input_set_id = old.planning_input_set_id
        and evaluation.evaluation_result = 'READY'
        and evaluation.blocking_issue_count = 0
        and evaluation.weekly_menu_id is not null
        and evaluation.attendance_batch_id is not null
        and evaluation.pantry_need_batch_id is not null
        and weekly_menu.version = evaluation.weekly_menu_version
        and weekly_menu.latest_approval_snapshot_id =
          evaluation.weekly_menu_approval_snapshot_id
        and weekly_menu.weekly_menu_status in (
          'APPROVED',
          'NEED_GENERATION_REQUESTED'
        )
        and weekly_menu.week_start <= old.period_start
        and weekly_menu.week_end >= old.period_end
        and attendance.version = evaluation.attendance_version
        and attendance.latest_approval_snapshot_id =
          evaluation.attendance_approval_snapshot_id
        and attendance.attendance_status in (
          'APPROVED',
          'USED_FOR_NEED_GENERATION'
        )
        and attendance.period_start <= old.period_start
        and attendance.period_end >= old.period_end
        and pantry.pantry_need_batch_status = 'APPROVED'
        and pantry.version = evaluation.pantry_need_batch_version
        and pantry.latest_approval_snapshot_id =
          evaluation.pantry_need_approval_snapshot_id
        and pantry.week_start <= old.period_start
        and pantry.week_end >= old.period_end
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

create or replace function atlas_planning.pa_06e_h0a4b_planning_input_integrity_guard()
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
  v_pantry_current boolean := false;
  v_weekly_covers boolean := false;
  v_attendance_covers boolean := false;
  v_pantry_covers boolean := false;
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

  select
    count(*),
    min(evaluation.evaluation_version),
    max(evaluation.evaluation_version)
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
  where issue.planning_input_evaluation_id =
    v_evaluation.planning_input_evaluation_id;

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
        and weekly_menu.latest_approval_snapshot_id =
          v_evaluation.weekly_menu_approval_snapshot_id
        and weekly_menu.weekly_menu_status in (
          'APPROVED',
          'NEED_GENERATION_REQUESTED'
        )
    into v_weekly_covers, v_weekly_current
    from atlas_planning.weekly_menus as weekly_menu
    where weekly_menu.weekly_menu_id = v_evaluation.weekly_menu_id;
  end if;

  if v_evaluation.attendance_batch_id is not null then
    select
      attendance.period_start <= v_root.period_start
        and attendance.period_end >= v_root.period_end,
      attendance.version = v_evaluation.attendance_version
        and attendance.latest_approval_snapshot_id =
          v_evaluation.attendance_approval_snapshot_id
        and attendance.attendance_status in (
          'APPROVED',
          'USED_FOR_NEED_GENERATION'
        )
    into v_attendance_covers, v_attendance_current
    from atlas_planning.attendance_batches as attendance
    where attendance.attendance_batch_id = v_evaluation.attendance_batch_id;
  end if;

  if v_evaluation.pantry_need_batch_id is not null then
    select
      pantry.week_start <= v_root.period_start
        and pantry.week_end >= v_root.period_end,
      pantry.pantry_need_batch_status = 'APPROVED'
        and pantry.version = v_evaluation.pantry_need_batch_version
        and pantry.latest_approval_snapshot_id =
          v_evaluation.pantry_need_approval_snapshot_id
    into v_pantry_covers, v_pantry_current
    from atlas_planning.pantry_need_batches as pantry
    where pantry.pantry_need_batch_id = v_evaluation.pantry_need_batch_id;
  end if;

  if v_root.readiness_status <> 'INVALIDATED' then
    if v_evaluation.evaluation_result = 'READY'
      and (
        v_evaluation.weekly_menu_id is null
        or v_evaluation.attendance_batch_id is null
        or v_evaluation.pantry_need_batch_id is null
        or not v_weekly_covers
        or not v_attendance_covers
        or not v_pantry_covers
        or not v_weekly_current
        or not v_attendance_current
        or not v_pantry_current
      )
    then
      raise exception using
        errcode = '23514',
        message = 'READY requires all three exact current source snapshots covering the evaluated period';
    end if;

    if v_evaluation.evaluation_result = 'NOT_READY' then
      if v_evaluation.weekly_menu_id is null
        and not exists (
          select 1
          from atlas_planning.planning_input_evaluation_issues as issue
          where issue.planning_input_evaluation_id =
              v_evaluation.planning_input_evaluation_id
            and issue.severity = 'BLOCKING'
            and issue.issue_code =
              'MISSING_WEEKLY_MENU_APPROVAL_SNAPSHOT'
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
          where issue.planning_input_evaluation_id =
              v_evaluation.planning_input_evaluation_id
            and issue.severity = 'BLOCKING'
            and issue.issue_code =
              'MISSING_ATTENDANCE_APPROVAL_SNAPSHOT'
        )
      then
        raise exception using
          errcode = '23514',
          message = 'a missing Attendance binding requires its exact blocker';
      end if;

      if v_evaluation.pantry_need_batch_id is null
        and not exists (
          select 1
          from atlas_planning.planning_input_evaluation_issues as issue
          where issue.planning_input_evaluation_id =
              v_evaluation.planning_input_evaluation_id
            and issue.severity = 'BLOCKING'
            and issue.issue_code = 'MISSING_PANTRY_APPROVAL_SNAPSHOT'
        )
      then
        raise exception using
          errcode = '23514',
          message = 'a missing Pantry binding requires its exact blocker';
      end if;

      if v_evaluation.weekly_menu_id is not null
        and not v_weekly_covers
        and not exists (
          select 1
          from atlas_planning.planning_input_evaluation_issues as issue
          where issue.planning_input_evaluation_id =
              v_evaluation.planning_input_evaluation_id
            and issue.severity = 'BLOCKING'
            and issue.issue_code =
              'WEEKLY_MENU_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD'
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
          where issue.planning_input_evaluation_id =
              v_evaluation.planning_input_evaluation_id
            and issue.severity = 'BLOCKING'
            and issue.issue_code =
              'ATTENDANCE_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD'
        )
      then
        raise exception using
          errcode = '23514',
          message = 'insufficient Attendance coverage requires its exact blocker';
      end if;

      if v_evaluation.pantry_need_batch_id is not null
        and not v_pantry_covers
        and not exists (
          select 1
          from atlas_planning.planning_input_evaluation_issues as issue
          where issue.planning_input_evaluation_id =
              v_evaluation.planning_input_evaluation_id
            and issue.severity = 'BLOCKING'
            and issue.issue_code =
              'PANTRY_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD'
        )
      then
        raise exception using
          errcode = '23514',
          message = 'insufficient Pantry coverage requires its exact blocker';
      end if;

      if (
        (v_evaluation.weekly_menu_id is not null and not v_weekly_current)
        or (
          v_evaluation.attendance_batch_id is not null
          and not v_attendance_current
        )
        or (v_evaluation.pantry_need_batch_id is not null and not v_pantry_current)
      ) and not exists (
        select 1
        from atlas_planning.planning_input_evaluation_issues as issue
        where issue.planning_input_evaluation_id =
            v_evaluation.planning_input_evaluation_id
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
    where line.weekly_menu_approval_snapshot_id =
        v_evaluation.weekly_menu_approval_snapshot_id
      and v_evaluation.weekly_menu_id is not null
      and v_evaluation.attendance_batch_id is not null
      and line.service_date between v_root.period_start and v_root.period_end
  ), attendance_days as (
    select
      line.school_id,
      line.service_date,
      line.student_portions + line.teacher_portions as total_portions
    from atlas_planning.attendance_approval_snapshot_lines as line
    where line.attendance_approval_snapshot_id =
        v_evaluation.attendance_approval_snapshot_id
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
        where line.weekly_menu_approval_snapshot_id =
            v_evaluation.weekly_menu_approval_snapshot_id
          and v_evaluation.weekly_menu_id is not null
          and v_evaluation.attendance_batch_id is not null
          and line.service_date between v_root.period_start and v_root.period_end
      ), attendance_days as (
        select
          line.school_id,
          line.service_date,
          line.student_portions + line.teacher_portions as total_portions
        from atlas_planning.attendance_approval_snapshot_lines as line
        where line.attendance_approval_snapshot_id =
            v_evaluation.attendance_approval_snapshot_id
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
        where issue.planning_input_evaluation_id =
            v_evaluation.planning_input_evaluation_id
          and issue.severity = 'WARNING'
      )
      select 1
      from (
        (
          select * from expected_warnings
          except
          select * from actual_warnings
        )
        union all
        (
          select * from actual_warnings
          except
          select * from expected_warnings
        )
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

reset role;
