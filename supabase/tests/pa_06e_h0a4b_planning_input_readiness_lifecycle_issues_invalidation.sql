begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;

select plan(48);

insert into atlas_core.actors (actor_id, actor_type, display_name) values
  ('c4000000-0000-0000-0000-000000000001', 'HUMAN', 'H0A4b lifecycle evaluator'),
  ('c4000000-0000-0000-0000-000000000002', 'HUMAN', 'H0A4b lifecycle approver');

insert into atlas_admin.customers (
  customer_id, customer_code, customer_name, customer_type
) values (
  'c4000000-0000-0000-0000-000000000100',
  'pa06e-h0a4b-lifecycle-customer', 'H0A4b lifecycle customer',
  'SCHOOL_CATERING'
);

insert into atlas_admin.delivery_locations (
  delivery_location_id, customer_id, location_code, location_name,
  address_text, timezone_name
) values (
  'c4000000-0000-0000-0000-000000000101',
  'c4000000-0000-0000-0000-000000000100',
  'pa06e-h0a4b-lifecycle-location', 'H0A4b lifecycle location',
  'Local-only lifecycle address', 'Asia/Ho_Chi_Minh'
);

insert into atlas_admin.school_types (
  school_type_id, school_type_code, school_type_name
) values (
  'c4000000-0000-0000-0000-000000000110',
  'pa06e-h0a4b-lifecycle-type', 'H0A4b lifecycle type'
);

insert into atlas_admin.schools (
  school_id, customer_id, school_code, school_name, school_type_id,
  default_delivery_location_id, display_order
) values (
  'c4000000-0000-0000-0000-000000000120',
  'c4000000-0000-0000-0000-000000000100',
  'pa06e-h0a4b-lifecycle-school', 'H0A4b lifecycle school',
  'c4000000-0000-0000-0000-000000000110',
  'c4000000-0000-0000-0000-000000000101', 10
);

insert into atlas_admin.dishes (
  dish_id, dish_code, dish_name, dish_status, display_order
) values (
  'c4000000-0000-0000-0000-000000000130',
  'pa06e-h0a4b-lifecycle-dish', 'H0A4b lifecycle dish', 'ACTIVE', 10
);

insert into atlas_planning.weekly_menus (
  weekly_menu_id, week_start, week_end, source_type, source_name,
  source_signature, row_count, imported_by_actor_id
) values (
  'c4000000-0000-0000-0000-000000000200',
  date '2026-10-05', date '2026-10-11', 'FIXTURE', 'H0A4b lifecycle menu',
  'sha256:h0a4b-lifecycle-menu', 3,
  'c4000000-0000-0000-0000-000000000001'
);

insert into atlas_planning.weekly_menu_lines (
  weekly_menu_line_id, weekly_menu_id, school_id, service_date,
  menu_slot_code, dish_id, created_by_actor_id, updated_by_actor_id
) values
  (
    'c4000000-0000-0000-0000-000000000210',
    'c4000000-0000-0000-0000-000000000200',
    'c4000000-0000-0000-0000-000000000120', date '2026-10-05',
    'savory', 'c4000000-0000-0000-0000-000000000130',
    'c4000000-0000-0000-0000-000000000001',
    'c4000000-0000-0000-0000-000000000001'
  ),
  (
    'c4000000-0000-0000-0000-000000000211',
    'c4000000-0000-0000-0000-000000000200',
    'c4000000-0000-0000-0000-000000000120', date '2026-10-06',
    'savory', 'c4000000-0000-0000-0000-000000000130',
    'c4000000-0000-0000-0000-000000000001',
    'c4000000-0000-0000-0000-000000000001'
  ),
  (
    'c4000000-0000-0000-0000-000000000212',
    'c4000000-0000-0000-0000-000000000200',
    'c4000000-0000-0000-0000-000000000120', date '2026-10-08',
    'savory', 'c4000000-0000-0000-0000-000000000130',
    'c4000000-0000-0000-0000-000000000001',
    'c4000000-0000-0000-0000-000000000001'
  );

update atlas_planning.weekly_menus
set weekly_menu_status = 'VALIDATED'
where weekly_menu_id = 'c4000000-0000-0000-0000-000000000200';

insert into atlas_planning.weekly_menu_approval_snapshots (
  weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version,
  approved_by_actor_id, approved_at
) values (
  'c4000000-0000-0000-0000-000000000220',
  'c4000000-0000-0000-0000-000000000200', 1,
  'c4000000-0000-0000-0000-000000000002',
  timestamptz '2026-10-04 09:00:00+07'
);

insert into atlas_planning.weekly_menu_approval_snapshot_lines (
  weekly_menu_approval_snapshot_line_id, weekly_menu_approval_snapshot_id,
  weekly_menu_id, weekly_menu_version, weekly_menu_line_id, school_id,
  service_date, menu_slot_code, dish_id
) values
  (
    'c4000000-0000-0000-0000-000000000221',
    'c4000000-0000-0000-0000-000000000220',
    'c4000000-0000-0000-0000-000000000200', 1,
    'c4000000-0000-0000-0000-000000000210',
    'c4000000-0000-0000-0000-000000000120', date '2026-10-05',
    'savory', 'c4000000-0000-0000-0000-000000000130'
  ),
  (
    'c4000000-0000-0000-0000-000000000222',
    'c4000000-0000-0000-0000-000000000220',
    'c4000000-0000-0000-0000-000000000200', 1,
    'c4000000-0000-0000-0000-000000000211',
    'c4000000-0000-0000-0000-000000000120', date '2026-10-06',
    'savory', 'c4000000-0000-0000-0000-000000000130'
  ),
  (
    'c4000000-0000-0000-0000-000000000223',
    'c4000000-0000-0000-0000-000000000220',
    'c4000000-0000-0000-0000-000000000200', 1,
    'c4000000-0000-0000-0000-000000000212',
    'c4000000-0000-0000-0000-000000000120', date '2026-10-08',
    'savory', 'c4000000-0000-0000-0000-000000000130'
  );

update atlas_planning.weekly_menus
set weekly_menu_status = 'APPROVED',
    latest_approved_by_actor_id = 'c4000000-0000-0000-0000-000000000002',
    latest_approved_at = timestamptz '2026-10-04 09:00:00+07',
    latest_approval_snapshot_id = 'c4000000-0000-0000-0000-000000000220'
where weekly_menu_id = 'c4000000-0000-0000-0000-000000000200';

insert into atlas_planning.attendance_batches (
  attendance_batch_id, period_start, period_end, source_type, source_name,
  source_signature, row_count, imported_by_actor_id
) values (
  'c4000000-0000-0000-0000-000000000300',
  date '2026-10-05', date '2026-10-11', 'FIXTURE', 'H0A4b lifecycle attendance',
  'sha256:h0a4b-lifecycle-attendance', 3,
  'c4000000-0000-0000-0000-000000000001'
);

insert into atlas_planning.attendance_lines (
  attendance_line_id, attendance_batch_id, school_id, service_date,
  student_portions, teacher_portions, created_by_actor_id, updated_by_actor_id
) values
  (
    'c4000000-0000-0000-0000-000000000310',
    'c4000000-0000-0000-0000-000000000300',
    'c4000000-0000-0000-0000-000000000120', date '2026-10-05', 20, 2,
    'c4000000-0000-0000-0000-000000000001',
    'c4000000-0000-0000-0000-000000000001'
  ),
  (
    'c4000000-0000-0000-0000-000000000311',
    'c4000000-0000-0000-0000-000000000300',
    'c4000000-0000-0000-0000-000000000120', date '2026-10-07', 10, 1,
    'c4000000-0000-0000-0000-000000000001',
    'c4000000-0000-0000-0000-000000000001'
  ),
  (
    'c4000000-0000-0000-0000-000000000312',
    'c4000000-0000-0000-0000-000000000300',
    'c4000000-0000-0000-0000-000000000120', date '2026-10-08', 0, 0,
    'c4000000-0000-0000-0000-000000000001',
    'c4000000-0000-0000-0000-000000000001'
  );

update atlas_planning.attendance_batches
set attendance_status = 'VALIDATED'
where attendance_batch_id = 'c4000000-0000-0000-0000-000000000300';

insert into atlas_planning.attendance_approval_snapshots (
  attendance_approval_snapshot_id, attendance_batch_id, attendance_version,
  approved_by_actor_id, approved_at
) values (
  'c4000000-0000-0000-0000-000000000320',
  'c4000000-0000-0000-0000-000000000300', 1,
  'c4000000-0000-0000-0000-000000000002',
  timestamptz '2026-10-04 09:05:00+07'
);

insert into atlas_planning.attendance_approval_snapshot_lines (
  attendance_approval_snapshot_line_id, attendance_approval_snapshot_id,
  attendance_batch_id, attendance_version, attendance_line_id, school_id,
  service_date, student_portions, teacher_portions
) values
  (
    'c4000000-0000-0000-0000-000000000321',
    'c4000000-0000-0000-0000-000000000320',
    'c4000000-0000-0000-0000-000000000300', 1,
    'c4000000-0000-0000-0000-000000000310',
    'c4000000-0000-0000-0000-000000000120', date '2026-10-05', 20, 2
  ),
  (
    'c4000000-0000-0000-0000-000000000322',
    'c4000000-0000-0000-0000-000000000320',
    'c4000000-0000-0000-0000-000000000300', 1,
    'c4000000-0000-0000-0000-000000000311',
    'c4000000-0000-0000-0000-000000000120', date '2026-10-07', 10, 1
  ),
  (
    'c4000000-0000-0000-0000-000000000323',
    'c4000000-0000-0000-0000-000000000320',
    'c4000000-0000-0000-0000-000000000300', 1,
    'c4000000-0000-0000-0000-000000000312',
    'c4000000-0000-0000-0000-000000000120', date '2026-10-08', 0, 0
  );

update atlas_planning.attendance_batches
set attendance_status = 'APPROVED',
    latest_approved_by_actor_id = 'c4000000-0000-0000-0000-000000000002',
    latest_approved_at = timestamptz '2026-10-04 09:05:00+07',
    latest_approval_snapshot_id = 'c4000000-0000-0000-0000-000000000320'
where attendance_batch_id = 'c4000000-0000-0000-0000-000000000300';

set constraints all immediate;
set constraints all deferred;

create function pg_temp.h0a4b_create_first(
  p_set_id uuid,
  p_evaluation_id uuid,
  p_period_start date,
  p_period_end date,
  p_result text,
  p_weekly_bound boolean,
  p_attendance_bound boolean,
  p_blocking_count integer,
  p_issues jsonb
) returns void
language plpgsql
as $$
begin
  insert into atlas_planning.planning_input_sets (
    planning_input_set_id, period_start, period_end, readiness_status,
    current_evaluation_id
  ) values (
    p_set_id, p_period_start, p_period_end, p_result, p_evaluation_id
  );

  insert into atlas_planning.planning_input_evaluations (
    planning_input_evaluation_id, planning_input_set_id, evaluation_version,
    evaluation_result, weekly_menu_id, weekly_menu_version,
    weekly_menu_approval_snapshot_id, attendance_batch_id,
    attendance_version, attendance_approval_snapshot_id,
    blocking_issue_count, warning_count, evaluated_by_actor_id
  ) values (
    p_evaluation_id, p_set_id, 1, p_result,
    case when p_weekly_bound then 'c4000000-0000-0000-0000-000000000200'::uuid end,
    case when p_weekly_bound then 1 end,
    case when p_weekly_bound then 'c4000000-0000-0000-0000-000000000220'::uuid end,
    case when p_attendance_bound then 'c4000000-0000-0000-0000-000000000300'::uuid end,
    case when p_attendance_bound then 1 end,
    case when p_attendance_bound then 'c4000000-0000-0000-0000-000000000320'::uuid end,
    p_blocking_count, 0, 'c4000000-0000-0000-0000-000000000001'
  );

  insert into atlas_planning.planning_input_evaluation_issues (
    planning_input_readiness_issue_id, planning_input_evaluation_id,
    planning_input_set_id, evaluation_version, severity, issue_code, message,
    input_type
  )
  select issue.issue_id, p_evaluation_id, p_set_id, 1, issue.severity,
    issue.issue_code, issue.message, issue.input_type
  from jsonb_to_recordset(p_issues) as issue(
    issue_id uuid, severity text, issue_code text, message text, input_type text
  );
end;
$$;

create function pg_temp.h0a4b_add_successor(
  p_set_id uuid,
  p_evaluation_id uuid,
  p_version bigint,
  p_result text,
  p_weekly_bound boolean,
  p_attendance_bound boolean,
  p_blocking_count integer,
  p_issues jsonb
) returns void
language plpgsql
as $$
begin
  insert into atlas_planning.planning_input_evaluations (
    planning_input_evaluation_id, planning_input_set_id, evaluation_version,
    evaluation_result, weekly_menu_id, weekly_menu_version,
    weekly_menu_approval_snapshot_id, attendance_batch_id,
    attendance_version, attendance_approval_snapshot_id,
    blocking_issue_count, warning_count, evaluated_by_actor_id
  ) values (
    p_evaluation_id, p_set_id, p_version, p_result,
    case when p_weekly_bound then 'c4000000-0000-0000-0000-000000000200'::uuid end,
    case when p_weekly_bound then 1 end,
    case when p_weekly_bound then 'c4000000-0000-0000-0000-000000000220'::uuid end,
    case when p_attendance_bound then 'c4000000-0000-0000-0000-000000000300'::uuid end,
    case when p_attendance_bound then 1 end,
    case when p_attendance_bound then 'c4000000-0000-0000-0000-000000000320'::uuid end,
    p_blocking_count, 0, 'c4000000-0000-0000-0000-000000000001'
  );

  insert into atlas_planning.planning_input_evaluation_issues (
    planning_input_readiness_issue_id, planning_input_evaluation_id,
    planning_input_set_id, evaluation_version, severity, issue_code, message,
    input_type
  )
  select issue.issue_id, p_evaluation_id, p_set_id, p_version, issue.severity,
    issue.issue_code, issue.message, issue.input_type
  from jsonb_to_recordset(p_issues) as issue(
    issue_id uuid, severity text, issue_code text, message text, input_type text
  );

  update atlas_planning.planning_input_sets
  set readiness_status = p_result,
      current_evaluation_id = p_evaluation_id,
      updated_at = updated_at + interval '1 second'
  where planning_input_set_id = p_set_id;
end;
$$;

create function pg_temp.h0a4b_create_warning_ready(
  p_set_id uuid,
  p_evaluation_id uuid,
  p_warning_count integer,
  p_issues jsonb
) returns void
language plpgsql
as $$
begin
  insert into atlas_planning.planning_input_sets (
    planning_input_set_id, period_start, period_end, readiness_status,
    current_evaluation_id
  ) values (
    p_set_id, date '2026-10-06', date '2026-10-08', 'READY', p_evaluation_id
  );

  insert into atlas_planning.planning_input_evaluations (
    planning_input_evaluation_id, planning_input_set_id, evaluation_version,
    evaluation_result, weekly_menu_id, weekly_menu_version,
    weekly_menu_approval_snapshot_id, attendance_batch_id,
    attendance_version, attendance_approval_snapshot_id,
    blocking_issue_count, warning_count, evaluated_by_actor_id
  ) values (
    p_evaluation_id, p_set_id, 1, 'READY',
    'c4000000-0000-0000-0000-000000000200', 1,
    'c4000000-0000-0000-0000-000000000220',
    'c4000000-0000-0000-0000-000000000300', 1,
    'c4000000-0000-0000-0000-000000000320',
    0, p_warning_count, 'c4000000-0000-0000-0000-000000000001'
  );

  insert into atlas_planning.planning_input_evaluation_issues (
    planning_input_readiness_issue_id, planning_input_evaluation_id,
    planning_input_set_id, evaluation_version, severity, issue_code, message,
    school_id, service_date
  )
  select issue.issue_id, p_evaluation_id, p_set_id, 1, issue.severity,
    issue.issue_code, issue.message, issue.school_id, issue.service_date
  from jsonb_to_recordset(p_issues) as issue(
    issue_id uuid, severity text, issue_code text, message text,
    school_id uuid, service_date date
  );
end;
$$;

select lives_ok(
  $test$
    select pg_temp.h0a4b_create_first(
      'c4000000-0000-0000-0000-000000000400',
      'c4000000-0000-0000-0000-000000000401',
      date '2026-10-05', date '2026-10-05', 'NOT_READY', false, false, 2,
      '[
        {"issue_id":"c4000000-0000-0000-0000-000000000410","severity":"BLOCKING","issue_code":"MISSING_WEEKLY_MENU_APPROVAL_SNAPSHOT","message":"menu missing","input_type":"WEEKLY_MENU"},
        {"issue_id":"c4000000-0000-0000-0000-000000000411","severity":"BLOCKING","issue_code":"MISSING_ATTENDANCE_APPROVAL_SNAPSHOT","message":"attendance missing","input_type":"ATTENDANCE"}
      ]'
    );
    set constraints all immediate;
    set constraints all deferred
  $test$,
  'the first evaluation may establish NOT_READY version 1'
);

select throws_ok(
  $test$
    select pg_temp.h0a4b_create_warning_ready(
      'c4000000-0000-0000-0000-000000000450',
      'c4000000-0000-0000-0000-000000000451', 2,
      '[
        {"issue_id":"c4000000-0000-0000-0000-000000000452","severity":"WARNING","issue_code":"MENU_SCHOOL_DATE_WITHOUT_ATTENDANCE","message":"menu only","school_id":"c4000000-0000-0000-0000-000000000120","service_date":"2026-10-06"},
        {"issue_id":"c4000000-0000-0000-0000-000000000453","severity":"WARNING","issue_code":"ATTENDANCE_SCHOOL_DATE_WITHOUT_MENU","message":"attendance only","school_id":"c4000000-0000-0000-0000-000000000120","service_date":"2026-10-07"}
      ]'
    );
    set constraints all immediate
  $test$,
  '23514', null,
  'omitting one applicable warning observation is rejected'
);

select is(
  (
    select row(evaluation_version, evaluation_result, blocking_issue_count)::text
    from atlas_planning.planning_input_evaluations
    where planning_input_evaluation_id = 'c4000000-0000-0000-0000-000000000401'
  ),
  '(1,NOT_READY,2)',
  'the first evaluation persists version, result, and exact issue count'
);

select lives_ok(
  $$
    select pg_temp.h0a4b_add_successor(
      'c4000000-0000-0000-0000-000000000400',
      'c4000000-0000-0000-0000-000000000402', 2,
      'READY', true, true, 0, '[]'
    );
    set constraints all immediate;
    set constraints all deferred
  $$,
  'NOT_READY may be re-evaluated to READY at the exact next version'
);

select is(
  (
    select row(readiness_status, current_evaluation_id)::text
    from atlas_planning.planning_input_sets
    where planning_input_set_id = 'c4000000-0000-0000-0000-000000000400'
  ),
  '(READY,c4000000-0000-0000-0000-000000000402)',
  'the root advances to the exact READY successor'
);

select is(
  (
    select array_agg(evaluation_version order by evaluation_version)::bigint[]
    from atlas_planning.planning_input_evaluations
    where planning_input_set_id = 'c4000000-0000-0000-0000-000000000400'
  ),
  array[1, 2]::bigint[],
  'evaluation history begins as a contiguous root-local sequence'
);

select is(
  (
    select count(*)::integer
    from atlas_planning.planning_input_evaluation_issues
    where planning_input_evaluation_id = 'c4000000-0000-0000-0000-000000000401'
  ),
  2,
  'successor evaluation preserves the prior issue evidence'
);

select lives_ok(
  $$
    update atlas_planning.planning_input_sets
    set readiness_status = 'NEED_GENERATION_REQUESTED',
        updated_at = updated_at + interval '1 second'
    where planning_input_set_id = 'c4000000-0000-0000-0000-000000000400';
    set constraints all immediate;
    set constraints all deferred
  $$,
  'READY may request need generation from the same current evaluation'
);

select is(
  (
    select row(readiness_status, current_evaluation_id)::text
    from atlas_planning.planning_input_sets
    where planning_input_set_id = 'c4000000-0000-0000-0000-000000000400'
  ),
  '(NEED_GENERATION_REQUESTED,c4000000-0000-0000-0000-000000000402)',
  'request preserves the exact current READY evaluation'
);

select throws_ok(
  $$
    insert into atlas_planning.planning_input_evaluations (
      planning_input_evaluation_id, planning_input_set_id, evaluation_version,
      evaluation_result, blocking_issue_count, warning_count,
      evaluated_by_actor_id
    ) values (
      'c4000000-0000-0000-0000-000000000499',
      'c4000000-0000-0000-0000-000000000400', 3, 'NOT_READY', 1, 0,
      'c4000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514', 'the current readiness status does not permit re-evaluation',
  'requested input sets cannot be re-evaluated directly'
);

select throws_ok(
  $$
    update atlas_planning.planning_input_sets
    set updated_at = updated_at + interval '1 second'
    where planning_input_set_id = 'c4000000-0000-0000-0000-000000000400'
  $$,
  '23514', 'invalid planning input readiness lifecycle transition',
  'requested same-state updates are not hidden lifecycle transitions'
);

select lives_ok(
  $$
    update atlas_planning.planning_input_sets
    set readiness_status = 'INVALIDATED',
        updated_at = updated_at + interval '1 second'
    where planning_input_set_id = 'c4000000-0000-0000-0000-000000000400';
    set constraints all immediate;
    set constraints all deferred
  $$,
  'NEED_GENERATION_REQUESTED may be explicitly invalidated'
);

select is(
  (
    select row(readiness_status, current_evaluation_id)::text
    from atlas_planning.planning_input_sets
    where planning_input_set_id = 'c4000000-0000-0000-0000-000000000400'
  ),
  '(INVALIDATED,c4000000-0000-0000-0000-000000000402)',
  'invalidation preserves the exact evaluation evidence'
);

select lives_ok(
  $$
    select pg_temp.h0a4b_add_successor(
      'c4000000-0000-0000-0000-000000000400',
      'c4000000-0000-0000-0000-000000000403', 3,
      'READY', true, true, 0, '[]'
    );
    set constraints all immediate;
    set constraints all deferred
  $$,
  'INVALIDATED may receive the exact next READY evaluation'
);

select is(
  (
    select row(readiness_status, evaluation_version)::text
    from atlas_planning.planning_input_sets input_set
    join atlas_planning.planning_input_evaluations evaluation
      on evaluation.planning_input_evaluation_id = input_set.current_evaluation_id
    where input_set.planning_input_set_id = 'c4000000-0000-0000-0000-000000000400'
  ),
  '(READY,3)',
  'the invalidated root advances to READY version 3'
);

select is(
  (
    select array_agg(evaluation_version order by evaluation_version)::bigint[]
    from atlas_planning.planning_input_evaluations
    where planning_input_set_id = 'c4000000-0000-0000-0000-000000000400'
  ),
  array[1, 2, 3]::bigint[],
  're-evaluation retains contiguous versions 1 through 3'
);

select lives_ok(
  $$
    update atlas_planning.planning_input_sets
    set readiness_status = 'INVALIDATED',
        updated_at = updated_at + interval '1 second'
    where planning_input_set_id = 'c4000000-0000-0000-0000-000000000400';
    set constraints all immediate;
    set constraints all deferred
  $$,
  'READY may be explicitly invalidated without replacing its evidence'
);

select lives_ok(
  $test$
    select pg_temp.h0a4b_add_successor(
      'c4000000-0000-0000-0000-000000000400',
      'c4000000-0000-0000-0000-000000000404', 4,
      'NOT_READY', true, false, 1,
      '[{"issue_id":"c4000000-0000-0000-0000-000000000412","severity":"BLOCKING","issue_code":"MISSING_ATTENDANCE_APPROVAL_SNAPSHOT","message":"attendance missing","input_type":"ATTENDANCE"}]'
    );
    set constraints all immediate;
    set constraints all deferred
  $test$,
  'INVALIDATED may receive the exact next NOT_READY evaluation'
);

select is(
  (
    select row(readiness_status, evaluation_result, evaluation_version)::text
    from atlas_planning.planning_input_sets input_set
    join atlas_planning.planning_input_evaluations evaluation
      on evaluation.planning_input_evaluation_id = input_set.current_evaluation_id
    where input_set.planning_input_set_id = 'c4000000-0000-0000-0000-000000000400'
  ),
  '(NOT_READY,NOT_READY,4)',
  'root status matches its NOT_READY version 4 evaluation'
);

select is(
  (
    select issue_code
    from atlas_planning.planning_input_evaluation_issues
    where planning_input_evaluation_id = 'c4000000-0000-0000-0000-000000000404'
  ),
  'MISSING_ATTENDANCE_APPROVAL_SNAPSHOT',
  'the new NOT_READY evaluation owns its exact immutable blocker'
);

select throws_ok(
  $$
    update atlas_planning.planning_input_sets
    set readiness_status = 'NEED_GENERATION_REQUESTED'
    where planning_input_set_id = 'c4000000-0000-0000-0000-000000000400'
  $$,
  '23514', 'invalid planning input readiness lifecycle transition',
  'NOT_READY cannot request need generation'
);

select throws_ok(
  $$
    update atlas_planning.planning_input_sets
    set readiness_status = 'INVALIDATED'
    where planning_input_set_id = 'c4000000-0000-0000-0000-000000000400'
  $$,
  '23514', 'invalid planning input readiness lifecycle transition',
  'NOT_READY cannot be invalidated'
);

select lives_ok(
  $$
    select pg_temp.h0a4b_add_successor(
      'c4000000-0000-0000-0000-000000000400',
      'c4000000-0000-0000-0000-000000000405', 5,
      'READY', true, true, 0, '[]'
    );
    set constraints all immediate;
    set constraints all deferred
  $$,
  'NOT_READY may advance only through a new exact READY evaluation'
);

select throws_ok(
  $$
    insert into atlas_planning.planning_input_evaluation_issues (
      planning_input_readiness_issue_id, planning_input_evaluation_id,
      planning_input_set_id, evaluation_version, severity, issue_code, message,
      school_id, service_date
    ) values (
      'c4000000-0000-0000-0000-000000000459',
      'c4000000-0000-0000-0000-000000000455',
      'c4000000-0000-0000-0000-000000000454', 1, 'WARNING',
      'MENU_SCHOOL_DATE_WITHOUT_ATTENDANCE', 'invented warning',
      'c4000000-0000-0000-0000-000000000120', date '2026-10-08'
    );
    set constraints all immediate
  $$,
  '23514', null,
  'an invented warning without a source observation is rejected'
);

select is(
  (
    select count(*)::integer
    from atlas_planning.planning_input_evaluations
    where planning_input_set_id = 'c4000000-0000-0000-0000-000000000400'
  ),
  5,
  'all five immutable evaluations remain in root-local history'
);

select throws_ok(
  $$
    insert into atlas_planning.planning_input_evaluations (
      planning_input_evaluation_id, planning_input_set_id, evaluation_version,
      evaluation_result, blocking_issue_count, warning_count,
      evaluated_by_actor_id
    ) values (
      'c4000000-0000-0000-0000-000000000406',
      'c4000000-0000-0000-0000-000000000400', 6, 'NOT_READY', 1, 0,
      'c4000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514', 'the current readiness status does not permit re-evaluation',
  'READY cannot be re-evaluated directly'
);

select throws_ok(
  $$
    update atlas_planning.planning_input_sets
    set readiness_status = 'NOT_READY'
    where planning_input_set_id = 'c4000000-0000-0000-0000-000000000400'
  $$,
  '23514', 'invalid planning input readiness lifecycle transition',
  'READY cannot reuse one evaluation as NOT_READY'
);

select throws_ok(
  $$
    update atlas_planning.planning_input_sets
    set updated_at = updated_at + interval '1 second'
    where planning_input_set_id = 'c4000000-0000-0000-0000-000000000400'
  $$,
  '23514', 'invalid planning input readiness lifecycle transition',
  'READY same-state updates cannot bypass the lifecycle'
);

select throws_ok(
  $$
    update atlas_planning.planning_input_sets
    set planning_input_set_id = 'c4000000-0000-0000-0000-000000009999'
    where planning_input_set_id = 'c4000000-0000-0000-0000-000000000400'
  $$,
  '23514', null,
  'planning input set identity is immutable'
);

select throws_ok(
  $$
    update atlas_planning.planning_input_sets
    set period_end = date '2026-10-06'
    where planning_input_set_id = 'c4000000-0000-0000-0000-000000000400'
  $$,
  '23514', null,
  'planning input set period is immutable'
);

select throws_ok(
  $$
    update atlas_planning.planning_input_sets
    set created_at = created_at - interval '1 second'
    where planning_input_set_id = 'c4000000-0000-0000-0000-000000000400'
  $$,
  '23514', null,
  'planning input set creation time is immutable'
);

select throws_ok(
  $$
    delete from atlas_planning.planning_input_sets
    where planning_input_set_id = 'c4000000-0000-0000-0000-000000000400'
  $$,
  '23514', 'planning input sets cannot be deleted',
  'stable Planning Input Set roots cannot be deleted'
);

select lives_ok(
  $$
    select pg_temp.h0a4b_create_first(
      'c4000000-0000-0000-0000-000000000420',
      'c4000000-0000-0000-0000-000000000421',
      date '2026-10-09', date '2026-10-09', 'READY', true, true, 0, '[]'
    );
    set constraints all immediate;
    set constraints all deferred
  $$,
  'a first evaluation may also establish READY version 1'
);

select lives_ok(
  $test$
    select pg_temp.h0a4b_create_warning_ready(
      'c4000000-0000-0000-0000-000000000454',
      'c4000000-0000-0000-0000-000000000455', 3,
      '[
        {"issue_id":"c4000000-0000-0000-0000-000000000456","severity":"WARNING","issue_code":"MENU_SCHOOL_DATE_WITHOUT_ATTENDANCE","message":"menu only","school_id":"c4000000-0000-0000-0000-000000000120","service_date":"2026-10-06"},
        {"issue_id":"c4000000-0000-0000-0000-000000000457","severity":"WARNING","issue_code":"ATTENDANCE_SCHOOL_DATE_WITHOUT_MENU","message":"attendance only","school_id":"c4000000-0000-0000-0000-000000000120","service_date":"2026-10-07"},
        {"issue_id":"c4000000-0000-0000-0000-000000000458","severity":"WARNING","issue_code":"ZERO_ATTENDANCE_FOR_PLANNED_MENU","message":"zero attendance","school_id":"c4000000-0000-0000-0000-000000000120","service_date":"2026-10-08"}
      ]'
    );
    set constraints all immediate;
    set constraints all deferred
  $test$,
  'READY permits warnings when every and only source observation is persisted'
);

update atlas_planning.weekly_menus
set weekly_menu_status = 'REOPENED', version = version + 1
where weekly_menu_id = 'c4000000-0000-0000-0000-000000000200';
set constraints all immediate;
set constraints all deferred;

select is(
  (
    select readiness_status
    from atlas_planning.planning_input_sets
    where planning_input_set_id = 'c4000000-0000-0000-0000-000000000420'
  ),
  'READY',
  'upstream source change does not automatically invalidate readiness history'
);

select throws_ok(
  $$
    update atlas_planning.planning_input_sets
    set readiness_status = 'NEED_GENERATION_REQUESTED'
    where planning_input_set_id = 'c4000000-0000-0000-0000-000000000420'
  $$,
  '23514', null,
  'request revalidates and rejects a stale current source binding'
);

select lives_ok(
  $$
    update atlas_planning.planning_input_sets
    set readiness_status = 'INVALIDATED',
        updated_at = updated_at + interval '1 second'
    where planning_input_set_id = 'c4000000-0000-0000-0000-000000000420';
    set constraints all immediate;
    set constraints all deferred
  $$,
  'a stale READY evaluation remains explicitly invalidatable'
);

select is(
  (
    select row(readiness_status, current_evaluation_id)::text
    from atlas_planning.planning_input_sets
    where planning_input_set_id = 'c4000000-0000-0000-0000-000000000420'
  ),
  '(INVALIDATED,c4000000-0000-0000-0000-000000000421)',
  'explicit invalidation preserves the stale evaluation as decision evidence'
);

select throws_ok(
  $$
    update atlas_planning.planning_input_sets
    set readiness_status = 'NEED_GENERATION_REQUESTED'
    where planning_input_set_id = 'c4000000-0000-0000-0000-000000000420'
  $$,
  '23514', 'invalid planning input readiness lifecycle transition',
  'INVALIDATED cannot request need generation'
);

select lives_ok(
  $test$
    select pg_temp.h0a4b_add_successor(
      'c4000000-0000-0000-0000-000000000420',
      'c4000000-0000-0000-0000-000000000422', 2,
      'NOT_READY', true, true, 1,
      '[{"issue_id":"c4000000-0000-0000-0000-000000000423","severity":"BLOCKING","issue_code":"STALE_OR_MISMATCHED_SNAPSHOT_BINDING","message":"weekly menu reopened"}]'
    );
    set constraints all immediate;
    set constraints all deferred
  $test$,
  'INVALIDATED can be re-evaluated to NOT_READY with exact stale evidence'
);

select is(
  (
    select row(readiness_status, evaluation_result, evaluation_version)::text
    from atlas_planning.planning_input_sets input_set
    join atlas_planning.planning_input_evaluations evaluation
      on evaluation.planning_input_evaluation_id = input_set.current_evaluation_id
    where input_set.planning_input_set_id = 'c4000000-0000-0000-0000-000000000420'
  ),
  '(NOT_READY,NOT_READY,2)',
  'stale re-evaluation becomes the exact current NOT_READY version 2'
);

select is(
  (
    select array_agg(issue_code order by issue_code)::text[]
    from atlas_planning.planning_input_evaluation_issues
    where planning_input_evaluation_id = 'c4000000-0000-0000-0000-000000000455'
  ),
  array[
    'ATTENDANCE_SCHOOL_DATE_WITHOUT_MENU',
    'MENU_SCHOOL_DATE_WITHOUT_ATTENDANCE',
    'ZERO_ATTENDANCE_FOR_PLANNED_MENU'
  ]::text[],
  'READY warning evidence is the exact every-and-only observation set'
);

select throws_ok(
  $$
    insert into atlas_planning.planning_input_sets (
      planning_input_set_id, period_start, period_end, readiness_status,
      current_evaluation_id
    ) values (
      'c4000000-0000-0000-0000-000000000432', date '2026-10-08',
      date '2026-10-08', 'NEED_GENERATION_REQUESTED',
      'c4000000-0000-0000-0000-000000000433'
    )
  $$,
  '23514', null,
  'a new root cannot enter NEED_GENERATION_REQUESTED'
);

select throws_ok(
  $$
    insert into atlas_planning.planning_input_sets (
      planning_input_set_id, period_start, period_end, readiness_status,
      current_evaluation_id
    ) values (
      'c4000000-0000-0000-0000-000000000434', date '2026-10-08',
      date '2026-10-08', 'INVALIDATED',
      'c4000000-0000-0000-0000-000000000435'
    )
  $$,
  '23514', null,
  'a new root cannot enter INVALIDATED'
);

select is(
  (
    select warning_count
    from atlas_planning.planning_input_evaluations
    where planning_input_evaluation_id = 'c4000000-0000-0000-0000-000000000455'
  ),
  3,
  'warning_count exactly matches the immutable warning issue rows'
);

select throws_ok(
  $$
    insert into atlas_planning.planning_input_sets (
      planning_input_set_id, period_start, period_end, readiness_status,
      current_evaluation_id
    ) values (
      'c4000000-0000-0000-0000-000000000438', date '2026-10-08',
      date '2026-10-08', 'NOT_READY',
      'c4000000-0000-0000-0000-000000000439'
    );
    insert into atlas_planning.planning_input_evaluations (
      planning_input_evaluation_id, planning_input_set_id, evaluation_version,
      evaluation_result, weekly_menu_id, weekly_menu_version,
      weekly_menu_approval_snapshot_id, attendance_batch_id,
      attendance_version, attendance_approval_snapshot_id,
      blocking_issue_count, warning_count, evaluated_by_actor_id
    ) values (
      'c4000000-0000-0000-0000-000000000439',
      'c4000000-0000-0000-0000-000000000438', 1, 'READY',
      'c4000000-0000-0000-0000-000000000200', 1,
      'c4000000-0000-0000-0000-000000000220',
      'c4000000-0000-0000-0000-000000000300', 1,
      'c4000000-0000-0000-0000-000000000320', 0, 0,
      'c4000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514', null,
  'the first evaluation result must match the new root status'
);

select pg_temp.h0a4b_create_first(
  'c4000000-0000-0000-0000-000000000440',
  'c4000000-0000-0000-0000-000000000441',
  date '2026-10-07', date '2026-10-07', 'NOT_READY', false, false, 2,
  '[
    {"issue_id":"c4000000-0000-0000-0000-000000000442","severity":"BLOCKING","issue_code":"MISSING_WEEKLY_MENU_APPROVAL_SNAPSHOT","message":"menu missing"},
    {"issue_id":"c4000000-0000-0000-0000-000000000443","severity":"BLOCKING","issue_code":"MISSING_ATTENDANCE_APPROVAL_SNAPSHOT","message":"attendance missing"}
  ]'
);
set constraints all immediate;
set constraints all deferred;

select throws_ok(
  $$
    insert into atlas_planning.planning_input_evaluations (
      planning_input_evaluation_id, planning_input_set_id, evaluation_version,
      evaluation_result, blocking_issue_count, warning_count,
      evaluated_by_actor_id
    ) values (
      'c4000000-0000-0000-0000-000000000444',
      'c4000000-0000-0000-0000-000000000440', 3, 'NOT_READY', 2, 0,
      'c4000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514', 'successor evaluations must use the exact next root-local version',
  'successor evaluation versions cannot skip a root-local number'
);

select throws_ok(
  $test$
    insert into atlas_planning.planning_input_evaluations (
      planning_input_evaluation_id, planning_input_set_id, evaluation_version,
      evaluation_result, blocking_issue_count, warning_count,
      evaluated_by_actor_id
    ) values (
      'c4000000-0000-0000-0000-000000000445',
      'c4000000-0000-0000-0000-000000000440', 2, 'NOT_READY', 2, 0,
      'c4000000-0000-0000-0000-000000000001'
    );
    insert into atlas_planning.planning_input_evaluation_issues (
      planning_input_readiness_issue_id, planning_input_evaluation_id,
      planning_input_set_id, evaluation_version, severity, issue_code, message
    ) values
      (
        'c4000000-0000-0000-0000-000000000446',
        'c4000000-0000-0000-0000-000000000445',
        'c4000000-0000-0000-0000-000000000440', 2, 'BLOCKING',
        'MISSING_WEEKLY_MENU_APPROVAL_SNAPSHOT', 'menu missing'
      ),
      (
        'c4000000-0000-0000-0000-000000000447',
        'c4000000-0000-0000-0000-000000000445',
        'c4000000-0000-0000-0000-000000000440', 2, 'BLOCKING',
        'MISSING_ATTENDANCE_APPROVAL_SNAPSHOT', 'attendance missing'
      );
    set constraints all immediate
  $test$,
  '23514', null,
  'a successor evaluation cannot commit without becoming the exact current pointer'
);

select * from finish();
rollback;
