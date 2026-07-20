begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;

select plan(45);

insert into atlas_core.actors (actor_id, actor_type, display_name) values
  ('b4000000-0000-0000-0000-000000000001', 'HUMAN', 'H0A4b evaluator'),
  ('b4000000-0000-0000-0000-000000000002', 'HUMAN', 'H0A4b approver');

insert into atlas_admin.customers (
  customer_id, customer_code, customer_name, customer_type
) values (
  'b4000000-0000-0000-0000-000000000100',
  'pa06e-h0a4b-integrity-customer', 'H0A4b integrity customer', 'SCHOOL_CATERING'
);

insert into atlas_admin.delivery_locations (
  delivery_location_id, customer_id, location_code, location_name,
  address_text, timezone_name
) values (
  'b4000000-0000-0000-0000-000000000101',
  'b4000000-0000-0000-0000-000000000100',
  'pa06e-h0a4b-integrity-location', 'H0A4b integrity location',
  'Local-only test address', 'Asia/Ho_Chi_Minh'
);

insert into atlas_admin.school_types (
  school_type_id, school_type_code, school_type_name
) values (
  'b4000000-0000-0000-0000-000000000110',
  'pa06e-h0a4b-integrity-type', 'H0A4b integrity type'
);

insert into atlas_admin.schools (
  school_id, customer_id, school_code, school_name, school_type_id,
  default_delivery_location_id, display_order
) values
  (
    'b4000000-0000-0000-0000-000000000120',
    'b4000000-0000-0000-0000-000000000100',
    'pa06e-h0a4b-integrity-school-a', 'H0A4b School A',
    'b4000000-0000-0000-0000-000000000110',
    'b4000000-0000-0000-0000-000000000101', 10
  ),
  (
    'b4000000-0000-0000-0000-000000000121',
    'b4000000-0000-0000-0000-000000000100',
    'pa06e-h0a4b-integrity-school-b', 'H0A4b School B',
    'b4000000-0000-0000-0000-000000000110',
    'b4000000-0000-0000-0000-000000000101', 20
  ),
  (
    'b4000000-0000-0000-0000-000000000122',
    'b4000000-0000-0000-0000-000000000100',
    'pa06e-h0a4b-integrity-school-c', 'H0A4b School C',
    'b4000000-0000-0000-0000-000000000110',
    'b4000000-0000-0000-0000-000000000101', 30
  );

insert into atlas_admin.dishes (
  dish_id, dish_code, dish_name, dish_status, display_order
) values (
  'b4000000-0000-0000-0000-000000000130',
  'pa06e-h0a4b-integrity-dish', 'H0A4b integrity dish', 'ACTIVE', 10
);

insert into atlas_planning.weekly_menus (
  weekly_menu_id, week_start, week_end, source_type, source_name,
  source_signature, row_count, imported_by_actor_id
) values (
  'b4000000-0000-0000-0000-000000000200',
  date '2026-09-07', date '2026-09-13', 'FIXTURE', 'H0A4b weekly menu',
  'sha256:h0a4b-weekly-menu', 3,
  'b4000000-0000-0000-0000-000000000001'
);

insert into atlas_planning.weekly_menu_lines (
  weekly_menu_line_id, weekly_menu_id, school_id, service_date,
  menu_slot_code, dish_id, created_by_actor_id, updated_by_actor_id
) values
  (
    'b4000000-0000-0000-0000-000000000210',
    'b4000000-0000-0000-0000-000000000200',
    'b4000000-0000-0000-0000-000000000120', date '2026-09-07',
    'savory', 'b4000000-0000-0000-0000-000000000130',
    'b4000000-0000-0000-0000-000000000001',
    'b4000000-0000-0000-0000-000000000001'
  ),
  (
    'b4000000-0000-0000-0000-000000000211',
    'b4000000-0000-0000-0000-000000000200',
    'b4000000-0000-0000-0000-000000000121', date '2026-09-08',
    'savory', 'b4000000-0000-0000-0000-000000000130',
    'b4000000-0000-0000-0000-000000000001',
    'b4000000-0000-0000-0000-000000000001'
  ),
  (
    'b4000000-0000-0000-0000-000000000212',
    'b4000000-0000-0000-0000-000000000200',
    'b4000000-0000-0000-0000-000000000120', date '2026-09-10',
    'savory', 'b4000000-0000-0000-0000-000000000130',
    'b4000000-0000-0000-0000-000000000001',
    'b4000000-0000-0000-0000-000000000001'
  );

update atlas_planning.weekly_menus
set weekly_menu_status = 'VALIDATED'
where weekly_menu_id = 'b4000000-0000-0000-0000-000000000200';

insert into atlas_planning.weekly_menu_approval_snapshots (
  weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version,
  approved_by_actor_id, approved_at
) values (
  'b4000000-0000-0000-0000-000000000220',
  'b4000000-0000-0000-0000-000000000200', 1,
  'b4000000-0000-0000-0000-000000000002',
  timestamptz '2026-09-06 09:00:00+07'
);

insert into atlas_planning.weekly_menu_approval_snapshot_lines (
  weekly_menu_approval_snapshot_line_id, weekly_menu_approval_snapshot_id,
  weekly_menu_id, weekly_menu_version, weekly_menu_line_id, school_id,
  service_date, menu_slot_code, dish_id
) values
  (
    'b4000000-0000-0000-0000-000000000221',
    'b4000000-0000-0000-0000-000000000220',
    'b4000000-0000-0000-0000-000000000200', 1,
    'b4000000-0000-0000-0000-000000000210',
    'b4000000-0000-0000-0000-000000000120', date '2026-09-07',
    'savory', 'b4000000-0000-0000-0000-000000000130'
  ),
  (
    'b4000000-0000-0000-0000-000000000222',
    'b4000000-0000-0000-0000-000000000220',
    'b4000000-0000-0000-0000-000000000200', 1,
    'b4000000-0000-0000-0000-000000000211',
    'b4000000-0000-0000-0000-000000000121', date '2026-09-08',
    'savory', 'b4000000-0000-0000-0000-000000000130'
  ),
  (
    'b4000000-0000-0000-0000-000000000223',
    'b4000000-0000-0000-0000-000000000220',
    'b4000000-0000-0000-0000-000000000200', 1,
    'b4000000-0000-0000-0000-000000000212',
    'b4000000-0000-0000-0000-000000000120', date '2026-09-10',
    'savory', 'b4000000-0000-0000-0000-000000000130'
  );

update atlas_planning.weekly_menus
set weekly_menu_status = 'APPROVED',
    latest_approved_by_actor_id = 'b4000000-0000-0000-0000-000000000002',
    latest_approved_at = timestamptz '2026-09-06 09:00:00+07',
    latest_approval_snapshot_id = 'b4000000-0000-0000-0000-000000000220'
where weekly_menu_id = 'b4000000-0000-0000-0000-000000000200';

insert into atlas_planning.attendance_batches (
  attendance_batch_id, period_start, period_end, source_type, source_name,
  source_signature, row_count, imported_by_actor_id
) values (
  'b4000000-0000-0000-0000-000000000300',
  date '2026-09-07', date '2026-09-13', 'FIXTURE', 'H0A4b attendance',
  'sha256:h0a4b-attendance', 3,
  'b4000000-0000-0000-0000-000000000001'
);

insert into atlas_planning.attendance_lines (
  attendance_line_id, attendance_batch_id, school_id, service_date,
  student_portions, teacher_portions, created_by_actor_id, updated_by_actor_id
) values
  (
    'b4000000-0000-0000-0000-000000000310',
    'b4000000-0000-0000-0000-000000000300',
    'b4000000-0000-0000-0000-000000000120', date '2026-09-07', 0, 0,
    'b4000000-0000-0000-0000-000000000001',
    'b4000000-0000-0000-0000-000000000001'
  ),
  (
    'b4000000-0000-0000-0000-000000000311',
    'b4000000-0000-0000-0000-000000000300',
    'b4000000-0000-0000-0000-000000000122', date '2026-09-09', 10, 1,
    'b4000000-0000-0000-0000-000000000001',
    'b4000000-0000-0000-0000-000000000001'
  ),
  (
    'b4000000-0000-0000-0000-000000000312',
    'b4000000-0000-0000-0000-000000000300',
    'b4000000-0000-0000-0000-000000000120', date '2026-09-10', 15, 2,
    'b4000000-0000-0000-0000-000000000001',
    'b4000000-0000-0000-0000-000000000001'
  );

update atlas_planning.attendance_batches
set attendance_status = 'VALIDATED'
where attendance_batch_id = 'b4000000-0000-0000-0000-000000000300';

insert into atlas_planning.attendance_approval_snapshots (
  attendance_approval_snapshot_id, attendance_batch_id, attendance_version,
  approved_by_actor_id, approved_at
) values (
  'b4000000-0000-0000-0000-000000000320',
  'b4000000-0000-0000-0000-000000000300', 1,
  'b4000000-0000-0000-0000-000000000002',
  timestamptz '2026-09-06 09:05:00+07'
);

insert into atlas_planning.attendance_approval_snapshot_lines (
  attendance_approval_snapshot_line_id, attendance_approval_snapshot_id,
  attendance_batch_id, attendance_version, attendance_line_id, school_id,
  service_date, student_portions, teacher_portions
) values
  (
    'b4000000-0000-0000-0000-000000000321',
    'b4000000-0000-0000-0000-000000000320',
    'b4000000-0000-0000-0000-000000000300', 1,
    'b4000000-0000-0000-0000-000000000310',
    'b4000000-0000-0000-0000-000000000120', date '2026-09-07', 0, 0
  ),
  (
    'b4000000-0000-0000-0000-000000000322',
    'b4000000-0000-0000-0000-000000000320',
    'b4000000-0000-0000-0000-000000000300', 1,
    'b4000000-0000-0000-0000-000000000311',
    'b4000000-0000-0000-0000-000000000122', date '2026-09-09', 10, 1
  ),
  (
    'b4000000-0000-0000-0000-000000000323',
    'b4000000-0000-0000-0000-000000000320',
    'b4000000-0000-0000-0000-000000000300', 1,
    'b4000000-0000-0000-0000-000000000312',
    'b4000000-0000-0000-0000-000000000120', date '2026-09-10', 15, 2
  );

update atlas_planning.attendance_batches
set attendance_status = 'APPROVED',
    latest_approved_by_actor_id = 'b4000000-0000-0000-0000-000000000002',
    latest_approved_at = timestamptz '2026-09-06 09:05:00+07',
    latest_approval_snapshot_id = 'b4000000-0000-0000-0000-000000000320'
where attendance_batch_id = 'b4000000-0000-0000-0000-000000000300';

-- Empty alternate snapshots let this suite isolate ownership and period rules
-- without creating warning observations owned by Suite 3.
insert into atlas_planning.weekly_menus (
  weekly_menu_id, week_start, week_end, source_type, source_name,
  source_signature, row_count, imported_by_actor_id
) values (
  'b4000000-0000-0000-0000-000000000250',
  date '2026-09-14', date '2026-09-20', 'FIXTURE', 'H0A4b alternate menu',
  'sha256:h0a4b-alternate-menu', 0,
  'b4000000-0000-0000-0000-000000000001'
);

update atlas_planning.weekly_menus
set weekly_menu_status = 'VALIDATED'
where weekly_menu_id = 'b4000000-0000-0000-0000-000000000250';

insert into atlas_planning.weekly_menu_approval_snapshots (
  weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version,
  approved_by_actor_id, approved_at
) values (
  'b4000000-0000-0000-0000-000000000270',
  'b4000000-0000-0000-0000-000000000250', 1,
  'b4000000-0000-0000-0000-000000000002',
  timestamptz '2026-09-06 10:00:00+07'
);

update atlas_planning.weekly_menus
set weekly_menu_status = 'APPROVED',
    latest_approved_by_actor_id = 'b4000000-0000-0000-0000-000000000002',
    latest_approved_at = timestamptz '2026-09-06 10:00:00+07',
    latest_approval_snapshot_id = 'b4000000-0000-0000-0000-000000000270'
where weekly_menu_id = 'b4000000-0000-0000-0000-000000000250';

insert into atlas_planning.attendance_batches (
  attendance_batch_id, period_start, period_end, source_type, source_name,
  source_signature, row_count, imported_by_actor_id
) values (
  'b4000000-0000-0000-0000-000000000350',
  date '2026-09-14', date '2026-09-20', 'FIXTURE',
  'H0A4b alternate attendance', 'sha256:h0a4b-alternate-attendance', 0,
  'b4000000-0000-0000-0000-000000000001'
);

update atlas_planning.attendance_batches
set attendance_status = 'VALIDATED'
where attendance_batch_id = 'b4000000-0000-0000-0000-000000000350';

insert into atlas_planning.attendance_approval_snapshots (
  attendance_approval_snapshot_id, attendance_batch_id, attendance_version,
  approved_by_actor_id, approved_at
) values (
  'b4000000-0000-0000-0000-000000000370',
  'b4000000-0000-0000-0000-000000000350', 1,
  'b4000000-0000-0000-0000-000000000002',
  timestamptz '2026-09-06 10:05:00+07'
);

update atlas_planning.attendance_batches
set attendance_status = 'APPROVED',
    latest_approved_by_actor_id = 'b4000000-0000-0000-0000-000000000002',
    latest_approved_at = timestamptz '2026-09-06 10:05:00+07',
    latest_approval_snapshot_id = 'b4000000-0000-0000-0000-000000000370'
where attendance_batch_id = 'b4000000-0000-0000-0000-000000000350';

set constraints all immediate;
set constraints all deferred;

create function pg_temp.h0a4b_make_evaluation(
  p_set_id uuid,
  p_evaluation_id uuid,
  p_period_start date,
  p_period_end date,
  p_result text,
  p_weekly_bound boolean,
  p_attendance_bound boolean,
  p_blocking_count integer,
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
    case when p_weekly_bound then 'b4000000-0000-0000-0000-000000000200'::uuid end,
    case when p_weekly_bound then 1 end,
    case when p_weekly_bound then 'b4000000-0000-0000-0000-000000000220'::uuid end,
    case when p_attendance_bound then 'b4000000-0000-0000-0000-000000000300'::uuid end,
    case when p_attendance_bound then 1 end,
    case when p_attendance_bound then 'b4000000-0000-0000-0000-000000000320'::uuid end,
    p_blocking_count, p_warning_count,
    'b4000000-0000-0000-0000-000000000001'
  );

  insert into atlas_planning.planning_input_evaluation_issues (
    planning_input_readiness_issue_id, planning_input_evaluation_id,
    planning_input_set_id, evaluation_version, severity, issue_code,
    message, input_type, school_id, service_date
  )
  select
    issue.issue_id, p_evaluation_id, p_set_id, 1, issue.severity,
    issue.issue_code, issue.message, issue.input_type, issue.school_id,
    issue.service_date
  from jsonb_to_recordset(p_issues) as issue(
    issue_id uuid, severity text, issue_code text, message text,
    input_type text, school_id uuid, service_date date
  );
end;
$$;

create function pg_temp.h0a4b_make_clean_evaluation(
  p_set_id uuid,
  p_evaluation_id uuid,
  p_period_start date,
  p_period_end date,
  p_result text
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
    'b4000000-0000-0000-0000-000000000250', 1,
    'b4000000-0000-0000-0000-000000000270',
    'b4000000-0000-0000-0000-000000000350', 1,
    'b4000000-0000-0000-0000-000000000370',
    0, 0, 'b4000000-0000-0000-0000-000000000001'
  );
end;
$$;

select lives_ok(
  $$
    select pg_temp.h0a4b_make_evaluation(
      'b4000000-0000-0000-0000-000000000400',
      'b4000000-0000-0000-0000-000000000401',
      date '2026-09-10', date '2026-09-10', 'READY', true, true, 0, 0, '[]'
    );
    set constraints all immediate;
    set constraints all deferred
  $$,
  'READY commits with both exact current source snapshots and zero blockers'
);

select is(
  (
    select row(readiness_status, current_evaluation_id)::text
    from atlas_planning.planning_input_sets
    where planning_input_set_id = 'b4000000-0000-0000-0000-000000000400'
  ),
  '(READY,b4000000-0000-0000-0000-000000000401)',
  'the root points to its exact READY evaluation'
);

select is(
  (
    select row(
      weekly_menu_id, weekly_menu_version, weekly_menu_approval_snapshot_id,
      attendance_batch_id, attendance_version, attendance_approval_snapshot_id
    )::text
    from atlas_planning.planning_input_evaluations
    where planning_input_evaluation_id = 'b4000000-0000-0000-0000-000000000401'
  ),
  '(b4000000-0000-0000-0000-000000000200,1,b4000000-0000-0000-0000-000000000220,b4000000-0000-0000-0000-000000000300,1,b4000000-0000-0000-0000-000000000320)',
  'the evaluation preserves both exact root/version/snapshot triples'
);

select throws_ok(
  $$
    insert into atlas_planning.planning_input_sets (
      planning_input_set_id, period_start, period_end, readiness_status,
      current_evaluation_id
    ) values (
      'b4000000-0000-0000-0000-000000000408', date '2026-09-12',
      date '2026-09-11', 'NOT_READY',
      'b4000000-0000-0000-0000-000000000409'
    )
  $$,
  '23514', null,
  'Planning Input Set periods reject a reversed inclusive range'
);

select throws_ok(
  $$
    insert into atlas_planning.planning_input_sets (
      planning_input_set_id, period_start, period_end, readiness_status,
      current_evaluation_id
    ) values (
      'b4000000-0000-0000-0000-000000000406', date '2026-09-10',
      date '2026-09-10', 'READY',
      'b4000000-0000-0000-0000-000000000407'
    )
  $$,
  '23505', null,
  'one exact evaluated period has only one stable Planning Input Set root'
);

select throws_ok(
  $$
    insert into atlas_planning.planning_input_sets values (
      'b4000000-0000-0000-0000-000000000410', date '2026-09-10',
      date '2026-09-11', 'NOT_READY',
      'b4000000-0000-0000-0000-000000000411', transaction_timestamp(),
      transaction_timestamp()
    );
    insert into atlas_planning.planning_input_evaluations (
      planning_input_evaluation_id, planning_input_set_id, evaluation_version,
      evaluation_result, weekly_menu_id, blocking_issue_count, warning_count,
      evaluated_by_actor_id
    ) values (
      'b4000000-0000-0000-0000-000000000411',
      'b4000000-0000-0000-0000-000000000410', 1, 'NOT_READY',
      'b4000000-0000-0000-0000-000000000200', 1, 0,
      'b4000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514', null,
  'Weekly Menu source columns are all-null or all-populated'
);

select throws_ok(
  $$
    insert into atlas_planning.planning_input_sets values (
      'b4000000-0000-0000-0000-000000000412', date '2026-09-10',
      date '2026-09-11', 'NOT_READY',
      'b4000000-0000-0000-0000-000000000413', transaction_timestamp(),
      transaction_timestamp()
    );
    insert into atlas_planning.planning_input_evaluations (
      planning_input_evaluation_id, planning_input_set_id, evaluation_version,
      evaluation_result, attendance_batch_id, attendance_version,
      blocking_issue_count, warning_count, evaluated_by_actor_id
    ) values (
      'b4000000-0000-0000-0000-000000000413',
      'b4000000-0000-0000-0000-000000000412', 1, 'NOT_READY',
      'b4000000-0000-0000-0000-000000000300', 1, 1, 0,
      'b4000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514', null,
  'Attendance source columns are all-null or all-populated'
);

select throws_ok(
  $$
    insert into atlas_planning.planning_input_sets (
      planning_input_set_id, period_start, period_end, readiness_status,
      current_evaluation_id
    ) values (
      'b4000000-0000-0000-0000-000000000414', date '2026-09-10',
      date '2026-09-11', 'NOT_READY',
      'b4000000-0000-0000-0000-000000000415'
    );
    insert into atlas_planning.planning_input_evaluations (
      planning_input_evaluation_id, planning_input_set_id, evaluation_version,
      evaluation_result, weekly_menu_id, weekly_menu_version,
      weekly_menu_approval_snapshot_id, blocking_issue_count, warning_count,
      evaluated_by_actor_id
    ) values (
      'b4000000-0000-0000-0000-000000000415',
      'b4000000-0000-0000-0000-000000000414', 1, 'NOT_READY',
      'b4000000-0000-0000-0000-000000000200', 1,
      'b4000000-0000-0000-0000-000000009999', 1, 0,
      'b4000000-0000-0000-0000-000000000001'
    )
  $$,
  '23503', null,
  'a Weekly Menu snapshot binding must resolve as one exact owned triple'
);

select throws_ok(
  $$
    insert into atlas_planning.planning_input_sets (
      planning_input_set_id, period_start, period_end, readiness_status,
      current_evaluation_id
    ) values (
      'b4000000-0000-0000-0000-000000000416', date '2026-09-10',
      date '2026-09-11', 'NOT_READY',
      'b4000000-0000-0000-0000-000000000417'
    );
    insert into atlas_planning.planning_input_evaluations (
      planning_input_evaluation_id, planning_input_set_id, evaluation_version,
      evaluation_result, attendance_batch_id, attendance_version,
      attendance_approval_snapshot_id, blocking_issue_count, warning_count,
      evaluated_by_actor_id
    ) values (
      'b4000000-0000-0000-0000-000000000417',
      'b4000000-0000-0000-0000-000000000416', 1, 'NOT_READY',
      'b4000000-0000-0000-0000-000000000300', 1,
      'b4000000-0000-0000-0000-000000009999', 1, 0,
      'b4000000-0000-0000-0000-000000000001'
    )
  $$,
  '23503', null,
  'an Attendance snapshot binding must resolve as one exact owned triple'
);

select throws_ok(
  $$
    insert into atlas_planning.planning_input_sets (
      planning_input_set_id, period_start, period_end, readiness_status,
      current_evaluation_id
    ) values (
      'b4000000-0000-0000-0000-000000000418', date '2026-09-11',
      date '2026-09-11', 'NOT_READY',
      'b4000000-0000-0000-0000-000000000419'
    );
    insert into atlas_planning.planning_input_evaluations (
      planning_input_evaluation_id, planning_input_set_id, evaluation_version,
      evaluation_result, blocking_issue_count, warning_count,
      evaluated_by_actor_id
    ) values (
      'b4000000-0000-0000-0000-000000000419',
      'b4000000-0000-0000-0000-000000000418', 2, 'NOT_READY', 1, 0,
      'b4000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514', null,
  'the first evaluation is exactly root-local version 1'
);

select throws_ok(
  $$
    insert into atlas_planning.planning_input_sets (
      planning_input_set_id, period_start, period_end, readiness_status,
      current_evaluation_id
    ) values (
      'b4000000-0000-0000-0000-000000000420', date '2026-09-12',
      date '2026-09-12', 'NOT_READY',
      'b4000000-0000-0000-0000-000000000421'
    );
    insert into atlas_planning.planning_input_evaluations (
      planning_input_evaluation_id, planning_input_set_id, evaluation_version,
      evaluation_result, weekly_menu_id, weekly_menu_version,
      weekly_menu_approval_snapshot_id, attendance_batch_id,
      attendance_version, attendance_approval_snapshot_id,
      blocking_issue_count, warning_count, evaluated_by_actor_id
    ) values (
      'b4000000-0000-0000-0000-000000000421',
      'b4000000-0000-0000-0000-000000000420', 1, 'READY',
      'b4000000-0000-0000-0000-000000000250', 1,
      'b4000000-0000-0000-0000-000000000270',
      'b4000000-0000-0000-0000-000000000350', 1,
      'b4000000-0000-0000-0000-000000000370', 0, 0,
      'b4000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514', null,
  'the first evaluation result must equal the new root status'
);

select throws_ok(
  $$
    insert into atlas_planning.planning_input_sets (
      planning_input_set_id, period_start, period_end, readiness_status,
      current_evaluation_id
    ) values (
      'b4000000-0000-0000-0000-000000000422', date '2026-09-11',
      date '2026-09-12', 'NOT_READY',
      'b4000000-0000-0000-0000-000000000423'
    );
    insert into atlas_planning.planning_input_evaluations (
      planning_input_evaluation_id, planning_input_set_id, evaluation_version,
      evaluation_result, weekly_menu_id, weekly_menu_version,
      weekly_menu_approval_snapshot_id, blocking_issue_count, warning_count,
      evaluated_by_actor_id
    ) values (
      'b4000000-0000-0000-0000-000000000423',
      'b4000000-0000-0000-0000-000000000422', 1, 'NOT_READY',
      'b4000000-0000-0000-0000-000000000250', 2,
      'b4000000-0000-0000-0000-000000000270', 1, 0,
      'b4000000-0000-0000-0000-000000000001'
    )
  $$,
  '23503', null,
  'Weekly Menu binding rejects a snapshot from the wrong root version'
);

select throws_ok(
  $$
    insert into atlas_planning.planning_input_sets (
      planning_input_set_id, period_start, period_end, readiness_status,
      current_evaluation_id
    ) values (
      'b4000000-0000-0000-0000-000000000424', date '2026-09-11',
      date '2026-09-13', 'NOT_READY',
      'b4000000-0000-0000-0000-000000000425'
    );
    insert into atlas_planning.planning_input_evaluations (
      planning_input_evaluation_id, planning_input_set_id, evaluation_version,
      evaluation_result, attendance_batch_id, attendance_version,
      attendance_approval_snapshot_id, blocking_issue_count, warning_count,
      evaluated_by_actor_id
    ) values (
      'b4000000-0000-0000-0000-000000000425',
      'b4000000-0000-0000-0000-000000000424', 1, 'NOT_READY',
      'b4000000-0000-0000-0000-000000000350', 2,
      'b4000000-0000-0000-0000-000000000370', 1, 0,
      'b4000000-0000-0000-0000-000000000001'
    )
  $$,
  '23503', null,
  'Attendance binding rejects a snapshot from the wrong root version'
);

select throws_ok(
  $$
    insert into atlas_planning.planning_input_sets (
      planning_input_set_id, period_start, period_end, readiness_status,
      current_evaluation_id
    ) values (
      'b4000000-0000-0000-0000-000000000426', date '2026-09-12',
      date '2026-09-13', 'READY',
      'b4000000-0000-0000-0000-000000000401'
    );
    set constraints all immediate
  $$,
  '23503', null,
  'current evaluation pointers cannot cross Planning Input Set roots'
);

select throws_ok(
  $$
    select pg_temp.h0a4b_make_evaluation(
      'b4000000-0000-0000-0000-000000000428',
      'b4000000-0000-0000-0000-000000000429',
      date '2026-09-11', date '2026-09-11', 'READY', false, true, 0, 0, '[]'
    );
    set constraints all immediate
  $$,
  '23514', null,
  'READY rejects a missing Weekly Menu approval snapshot'
);

select throws_ok(
  $$
    select pg_temp.h0a4b_make_evaluation(
      'b4000000-0000-0000-0000-000000000430',
      'b4000000-0000-0000-0000-000000000431',
      date '2026-09-11', date '2026-09-11', 'READY', true, false, 0, 0, '[]'
    );
    set constraints all immediate
  $$,
  '23514', null,
  'READY rejects a missing Attendance approval snapshot'
);

select throws_ok(
  $$
    select pg_temp.h0a4b_make_evaluation(
      'b4000000-0000-0000-0000-000000000432',
      'b4000000-0000-0000-0000-000000000433',
      date '2026-09-13', date '2026-09-14', 'READY', true, true, 0, 0, '[]'
    );
    set constraints all immediate
  $$,
  '23514', null,
  'READY requires both upstream periods to contain the evaluated period'
);

select throws_ok(
  $test$
    select pg_temp.h0a4b_make_evaluation(
      'b4000000-0000-0000-0000-000000000434',
      'b4000000-0000-0000-0000-000000000435',
      date '2026-09-11', date '2026-09-11', 'READY', true, true, 1, 0,
      '[{"issue_id":"b4000000-0000-0000-0000-000000000436","severity":"BLOCKING","issue_code":"REQUEST_WITHOUT_CURRENT_READY_EVALUATION","message":"blocking"}]'
    );
    set constraints all immediate
  $test$,
  '23514', null,
  'READY rejects any blocking issue row'
);

select lives_ok(
  $test$
    select pg_temp.h0a4b_make_evaluation(
      'b4000000-0000-0000-0000-000000000440',
      'b4000000-0000-0000-0000-000000000441',
      date '2026-09-11', date '2026-09-11', 'NOT_READY', false, false, 2, 0,
      '[
        {"issue_id":"b4000000-0000-0000-0000-000000000442","severity":"BLOCKING","issue_code":"MISSING_WEEKLY_MENU_APPROVAL_SNAPSHOT","message":"menu missing","input_type":"WEEKLY_MENU"},
        {"issue_id":"b4000000-0000-0000-0000-000000000443","severity":"BLOCKING","issue_code":"MISSING_ATTENDANCE_APPROVAL_SNAPSHOT","message":"attendance missing","input_type":"ATTENDANCE"}
      ]'
    );
    set constraints all immediate;
    set constraints all deferred
  $test$,
  'NOT_READY persists when both missing bindings have their exact blockers'
);

select is(
  (
    select row(evaluation_result, blocking_issue_count, warning_count)::text
    from atlas_planning.planning_input_evaluations
    where planning_input_evaluation_id = 'b4000000-0000-0000-0000-000000000441'
  ),
  '(NOT_READY,2,0)',
  'the accepted NOT_READY evaluation count evidence matches its issue set'
);

select throws_ok(
  $test$
    select pg_temp.h0a4b_make_evaluation(
      'b4000000-0000-0000-0000-000000000444',
      'b4000000-0000-0000-0000-000000000445',
      date '2026-09-11', date '2026-09-12', 'NOT_READY', false, true, 1, 0,
      '[{"issue_id":"b4000000-0000-0000-0000-000000000446","severity":"BLOCKING","issue_code":"SOURCE_SNAPSHOT_OWNERSHIP_MISMATCH","message":"wrong blocker"}]'
    );
    set constraints all immediate
  $test$,
  '23514', null,
  'missing Weekly Menu evidence requires the matching missing-snapshot blocker'
);

select throws_ok(
  $test$
    select pg_temp.h0a4b_make_evaluation(
      'b4000000-0000-0000-0000-000000000447',
      'b4000000-0000-0000-0000-000000000448',
      date '2026-09-11', date '2026-09-13', 'NOT_READY', true, false, 1, 0,
      '[{"issue_id":"b4000000-0000-0000-0000-000000000449","severity":"BLOCKING","issue_code":"SOURCE_SNAPSHOT_OWNERSHIP_MISMATCH","message":"wrong blocker"}]'
    );
    set constraints all immediate
  $test$,
  '23514', null,
  'missing Attendance evidence requires the matching missing-snapshot blocker'
);

select throws_ok(
  $$
    select pg_temp.h0a4b_make_evaluation(
      'b4000000-0000-0000-0000-000000000450',
      'b4000000-0000-0000-0000-000000000451',
      date '2026-09-12', date '2026-09-13', 'NOT_READY', false, false, 0, 0, '[]'
    );
    set constraints all immediate
  $$,
  '23514', null,
  'NOT_READY requires at least one blocker'
);

select throws_ok(
  $test$
    select pg_temp.h0a4b_make_evaluation(
      'b4000000-0000-0000-0000-000000000452',
      'b4000000-0000-0000-0000-000000000453',
      date '2026-09-10', date '2026-09-11', 'NOT_READY', false, false, 3, 0,
      '[
        {"issue_id":"b4000000-0000-0000-0000-000000000454","severity":"BLOCKING","issue_code":"MISSING_WEEKLY_MENU_APPROVAL_SNAPSHOT","message":"menu missing"},
        {"issue_id":"b4000000-0000-0000-0000-000000000455","severity":"BLOCKING","issue_code":"MISSING_ATTENDANCE_APPROVAL_SNAPSHOT","message":"attendance missing"}
      ]'
    );
    set constraints all immediate
  $test$,
  '23514', null,
  'stored counts must exactly equal the immutable issue rows'
);

select lives_ok(
  $$
    select pg_temp.h0a4b_make_clean_evaluation(
      'b4000000-0000-0000-0000-000000000480',
      'b4000000-0000-0000-0000-000000000481',
      date '2026-09-14', date '2026-09-20', 'READY'
    );
    set constraints all immediate;
    set constraints all deferred
  $$,
  'READY accepts equality containment by both exact current source periods'
);

select lives_ok(
  $$
    select pg_temp.h0a4b_make_clean_evaluation(
      'b4000000-0000-0000-0000-000000000482',
      'b4000000-0000-0000-0000-000000000483',
      date '2026-09-16', date '2026-09-17', 'READY'
    );
    set constraints all immediate;
    set constraints all deferred
  $$,
  'READY accepts a proper subset wholly contained by both source periods'
);

select throws_ok(
  $$
    select pg_temp.h0a4b_make_clean_evaluation(
      'b4000000-0000-0000-0000-000000000484',
      'b4000000-0000-0000-0000-000000000485',
      date '2026-09-19', date '2026-09-21', 'READY'
    );
    set constraints all immediate;
  $$,
  '23514', null,
  'partial source-period overlap is rejected'
);

select throws_ok(
  $$
    select pg_temp.h0a4b_make_clean_evaluation(
      'b4000000-0000-0000-0000-000000000486',
      'b4000000-0000-0000-0000-000000000487',
      date '2026-09-21', date '2026-09-22', 'READY'
    );
    set constraints all immediate;
  $$,
  '23514', null,
  'a disjoint evaluated period is rejected'
);

select throws_ok(
  $$
    select pg_temp.h0a4b_make_clean_evaluation(
      'b4000000-0000-0000-0000-000000000488',
      'b4000000-0000-0000-0000-000000000489',
      date '2026-09-13', date '2026-09-14', 'READY'
    );
    set constraints all immediate;
  $$,
  '23514', null,
  'an evaluated range with an uncovered day is rejected'
);

select throws_ok(
  $$
    insert into atlas_planning.planning_input_evaluation_issues (
      planning_input_evaluation_id, planning_input_set_id, evaluation_version,
      severity, issue_code, message
    ) values (
      'b4000000-0000-0000-0000-000000000441',
      'b4000000-0000-0000-0000-000000000440', 1, 'BLOCKING',
      'ZERO_ATTENDANCE_FOR_PLANNED_MENU', 'wrong severity'
    )
  $$,
  '23514', null,
  'warning codes cannot be classified as BLOCKING'
);

select throws_ok(
  $$
    insert into atlas_planning.planning_input_evaluation_issues (
      planning_input_evaluation_id, planning_input_set_id, evaluation_version,
      severity, issue_code, message
    ) values (
      'b4000000-0000-0000-0000-000000000441',
      'b4000000-0000-0000-0000-000000000440', 1, 'WARNING',
      'MISSING_WEEKLY_MENU_APPROVAL_SNAPSHOT', 'wrong severity'
    )
  $$,
  '23514', null,
  'blocking codes cannot be classified as WARNING'
);

select throws_ok(
  $$
    insert into atlas_planning.planning_input_evaluation_issues (
      planning_input_evaluation_id, planning_input_set_id, evaluation_version,
      severity, issue_code, message
    ) values (
      'b4000000-0000-0000-0000-000000000441',
      'b4000000-0000-0000-0000-000000000440', 1, 'BLOCKING',
      'UNAPPROVED_WEEKLY_MENU', 'unapproved code'
    )
  $$,
  '23514', null,
  'unapproved issue codes are rejected'
);

select throws_ok(
  $$
    insert into atlas_planning.planning_input_evaluation_issues (
      planning_input_evaluation_id, planning_input_set_id, evaluation_version,
      severity, issue_code, message
    ) values (
      'b4000000-0000-0000-0000-000000000441',
      'b4000000-0000-0000-0000-000000000440', 1, 'BLOCKING',
      'REQUEST_WITHOUT_CURRENT_READY_EVALUATION', '   '
    )
  $$,
  '23514', null,
  'issue messages must contain nonblank evidence'
);

select throws_ok(
  $$
    insert into atlas_planning.planning_input_evaluation_issues (
      planning_input_evaluation_id, planning_input_set_id, evaluation_version,
      severity, issue_code, message, input_type
    ) values (
      'b4000000-0000-0000-0000-000000000441',
      'b4000000-0000-0000-0000-000000000440', 1, 'BLOCKING',
      'REQUEST_WITHOUT_CURRENT_READY_EVALUATION', 'bad type', 'RECIPE'
    )
  $$,
  '23514', null,
  'issue input type is optional but limited to the two approved source families'
);

select throws_ok(
  $$
    insert into atlas_planning.planning_input_evaluation_issues (
      planning_input_readiness_issue_id, planning_input_evaluation_id,
      planning_input_set_id, evaluation_version, severity, issue_code, message,
      input_type
    ) values (
      'b4000000-0000-0000-0000-000000000468',
      'b4000000-0000-0000-0000-000000000441',
      'b4000000-0000-0000-0000-000000000440', 1, 'BLOCKING',
      'MISSING_WEEKLY_MENU_APPROVAL_SNAPSHOT', 'duplicate null context',
      'WEEKLY_MENU'
    )
  $$,
  '23505', null,
  'contextual uniqueness treats duplicate null context as the same issue'
);

select throws_ok(
  $$
    insert into atlas_planning.planning_input_evaluation_issues (
      planning_input_evaluation_id, planning_input_set_id, evaluation_version,
      severity, issue_code, message, school_id
    ) values (
      'b4000000-0000-0000-0000-000000000441',
      'b4000000-0000-0000-0000-000000000440', 1, 'BLOCKING',
      'REQUEST_WITHOUT_CURRENT_READY_EVALUATION', 'bad school',
      'b4000000-0000-0000-0000-000000009999'
    )
  $$,
  '23503', null,
  'optional school context remains a typed school foreign key'
);

select throws_ok(
  $$
    insert into atlas_planning.planning_input_evaluation_issues (
      planning_input_evaluation_id, planning_input_set_id, evaluation_version,
      severity, issue_code, message
    ) values (
      'b4000000-0000-0000-0000-000000000401',
      'b4000000-0000-0000-0000-000000000440', 1, 'BLOCKING',
      'REQUEST_WITHOUT_CURRENT_READY_EVALUATION', 'mixed ownership'
    )
  $$,
  '23514', null,
  'issue evaluation, root, and version ownership cannot be mixed'
);

select throws_ok(
  $$
    insert into atlas_planning.planning_input_evaluation_issues (
      planning_input_evaluation_id, planning_input_set_id, evaluation_version,
      severity, issue_code, message
    ) values (
      'b4000000-0000-0000-0000-000000000441',
      'b4000000-0000-0000-0000-000000000440', 0, 'BLOCKING',
      'REQUEST_WITHOUT_CURRENT_READY_EVALUATION', 'bad version'
    )
  $$,
  '23514', null,
  'issue evaluation versions must be positive and owned'
);

select throws_ok(
  $$
    update atlas_planning.planning_input_evaluations
    set evaluated_at = evaluated_at + interval '1 second'
    where planning_input_evaluation_id = 'b4000000-0000-0000-0000-000000000401'
  $$,
  '23514', 'planning input evaluations are immutable and nondeletable',
  'evaluation rows are immutable'
);

select throws_ok(
  $$
    delete from atlas_planning.planning_input_evaluations
    where planning_input_evaluation_id = 'b4000000-0000-0000-0000-000000000401'
  $$,
  '23514', 'planning input evaluations are immutable and nondeletable',
  'evaluation rows cannot be deleted'
);

select throws_ok(
  $$
    update atlas_planning.planning_input_evaluation_issues
    set message = 'changed'
    where planning_input_readiness_issue_id = 'b4000000-0000-0000-0000-000000000442'
  $$,
  '23514', 'planning input evaluation issues are immutable and nondeletable',
  'issue rows are immutable'
);

select throws_ok(
  $$
    delete from atlas_planning.planning_input_evaluation_issues
    where planning_input_readiness_issue_id = 'b4000000-0000-0000-0000-000000000442'
  $$,
  '23514', 'planning input evaluation issues are immutable and nondeletable',
  'issue rows cannot be deleted'
);

update atlas_planning.weekly_menus
set weekly_menu_status = 'NEED_GENERATION_REQUESTED'
where weekly_menu_id = 'b4000000-0000-0000-0000-000000000200';
update atlas_planning.attendance_batches
set attendance_status = 'USED_FOR_NEED_GENERATION'
where attendance_batch_id = 'b4000000-0000-0000-0000-000000000300';
set constraints all immediate;
set constraints all deferred;

select lives_ok(
  $$
    select pg_temp.h0a4b_make_evaluation(
      'b4000000-0000-0000-0000-000000000470',
      'b4000000-0000-0000-0000-000000000471',
      date '2026-09-12', date '2026-09-12', 'READY', true, true, 0, 0, '[]'
    );
    set constraints all immediate;
    set constraints all deferred
  $$,
  'the exact handed-off upstream states remain READY-eligible'
);

update atlas_planning.weekly_menus
set weekly_menu_status = 'REOPENED', version = version + 1
where weekly_menu_id = 'b4000000-0000-0000-0000-000000000200';
set constraints all immediate;
set constraints all deferred;

select throws_ok(
  $test$
    select pg_temp.h0a4b_make_evaluation(
      'b4000000-0000-0000-0000-000000000472',
      'b4000000-0000-0000-0000-000000000473',
      date '2026-09-13', date '2026-09-13', 'NOT_READY', true, true, 1, 0,
      '[{"issue_id":"b4000000-0000-0000-0000-000000000474","severity":"BLOCKING","issue_code":"SOURCE_SNAPSHOT_OWNERSHIP_MISMATCH","message":"wrong stale blocker"}]'
    );
    set constraints all immediate
  $test$,
  '23514', null,
  'a stale exact snapshot binding requires the approved stale-binding blocker'
);

select lives_ok(
  $test$
    select pg_temp.h0a4b_make_evaluation(
      'b4000000-0000-0000-0000-000000000475',
      'b4000000-0000-0000-0000-000000000476',
      date '2026-09-13', date '2026-09-13', 'NOT_READY', true, true, 1, 0,
      '[{"issue_id":"b4000000-0000-0000-0000-000000000477","severity":"BLOCKING","issue_code":"STALE_OR_MISMATCHED_SNAPSHOT_BINDING","message":"weekly menu changed"}]'
    );
    set constraints all immediate;
    set constraints all deferred
  $test$,
  'a stale exact source binding commits only with its matching blocker'
);

select * from finish();
rollback;
