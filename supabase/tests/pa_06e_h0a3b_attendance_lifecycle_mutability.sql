begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;

select plan(78);

-- This suite owns only period semantics, lifecycle, source refresh, and working-line mutability.
insert into atlas_core.actors (actor_id, actor_type, display_name) values
  ('ac000000-0000-0000-0000-000000000001', 'HUMAN', 'H0A3b lifecycle importer'),
  ('ac000000-0000-0000-0000-000000000002', 'HUMAN', 'H0A3b lifecycle approver'),
  ('ac000000-0000-0000-0000-000000000003', 'HUMAN', 'H0A3b lifecycle alternate');

insert into atlas_admin.customers (
  customer_id, customer_code, customer_name, customer_type
) values (
  'ac000000-0000-0000-0000-000000000100',
  'pa06e-h0a3b-lifecycle-customer',
  'PA-06E-H0A3b lifecycle customer',
  'SCHOOL_CATERING'
);

insert into atlas_admin.delivery_locations (
  delivery_location_id, customer_id, location_code, location_name,
  address_text, timezone_name
) values (
  'ac000000-0000-0000-0000-000000000101',
  'ac000000-0000-0000-0000-000000000100',
  'pa06e-h0a3b-lifecycle-location',
  'PA-06E-H0A3b lifecycle location',
  'Synthetic lifecycle address',
  'Asia/Ho_Chi_Minh'
);

insert into atlas_admin.school_types (
  school_type_id, school_type_code, school_type_name
) values (
  'ac000000-0000-0000-0000-000000000110',
  'pa06e-h0a3b-lifecycle-primary',
  'PA-06E-H0A3b lifecycle Primary'
);

insert into atlas_admin.schools (
  school_id, customer_id, school_code, school_name, school_type_id,
  default_delivery_location_id, display_order
) values
  (
    'ac000000-0000-0000-0000-000000000120',
    'ac000000-0000-0000-0000-000000000100',
    'pa06e-h0a3b-lifecycle-school-a',
    'PA-06E-H0A3b lifecycle School A',
    'ac000000-0000-0000-0000-000000000110',
    'ac000000-0000-0000-0000-000000000101',
    10
  ),
  (
    'ac000000-0000-0000-0000-000000000121',
    'ac000000-0000-0000-0000-000000000100',
    'pa06e-h0a3b-lifecycle-school-b',
    'PA-06E-H0A3b lifecycle School B',
    'ac000000-0000-0000-0000-000000000110',
    'ac000000-0000-0000-0000-000000000101',
    20
  );

update atlas_admin.schools
set school_status = 'INACTIVE'
where school_id = 'ac000000-0000-0000-0000-000000000121';

select lives_ok(
  $$
    insert into atlas_planning.attendance_batches (
      attendance_batch_id, period_start, period_end, source_type, source_name,
      source_signature, row_count, imported_by_actor_id, imported_at,
      created_at, updated_at
    ) values (
      'ac000000-0000-0000-0000-000000000200',
      date '2026-07-20', date '2026-07-24',
      'CSV', 'lifecycle-one.csv', 'sha256:lifecycle-one', 3,
      'ac000000-0000-0000-0000-000000000001',
      timestamptz '2026-07-20 08:00:00+07',
      timestamptz '2026-07-20 08:00:00+07',
      timestamptz '2026-07-20 08:00:00+07'
    )
  $$,
  'an inclusive five-day Attendance period is accepted without a week-shape restriction'
);

select is(
  (
    select row(attendance_status, row_count, version)::text
    from atlas_planning.attendance_batches
    where attendance_batch_id = 'ac000000-0000-0000-0000-000000000200'
  ),
  '(DRAFT,3,1)',
  'new Attendance lifecycle and positive version defaults are exact'
);

select throws_ok(
  $$
    insert into atlas_planning.attendance_batches (
      attendance_batch_id, period_start, period_end, source_type, source_name,
      source_signature, imported_by_actor_id, attendance_status
    ) values (
      'ac000000-0000-0000-0000-000000000201',
      date '2026-08-01', date '2026-08-01', 'CSV', 'invalid.csv', 'invalid',
      'ac000000-0000-0000-0000-000000000001', 'VALIDATED'
    )
  $$,
  '23514',
  'new attendance batches must enter as DRAFT',
  'new Attendance cannot enter directly as VALIDATED'
);

select throws_ok(
  $$
    insert into atlas_planning.attendance_batches (
      attendance_batch_id, period_start, period_end, source_type, source_name,
      source_signature, imported_by_actor_id, attendance_status,
      latest_approved_by_actor_id, latest_approved_at, latest_approval_snapshot_id
    ) values (
      'ac000000-0000-0000-0000-000000000202',
      date '2026-08-02', date '2026-08-02', 'CSV', 'invalid.csv', 'invalid',
      'ac000000-0000-0000-0000-000000000001', 'APPROVED',
      'ac000000-0000-0000-0000-000000000002', transaction_timestamp(),
      'ac000000-0000-0000-0000-000000009999'
    )
  $$,
  '23514',
  'new attendance batches must enter as DRAFT',
  'new Attendance cannot enter directly as APPROVED'
);

select throws_ok(
  $$
    insert into atlas_planning.attendance_batches (
      attendance_batch_id, period_start, period_end, source_type, source_name,
      source_signature, imported_by_actor_id, attendance_status,
      latest_approved_by_actor_id, latest_approved_at, latest_approval_snapshot_id
    ) values (
      'ac000000-0000-0000-0000-000000000203',
      date '2026-08-03', date '2026-08-03', 'CSV', 'invalid.csv', 'invalid',
      'ac000000-0000-0000-0000-000000000001', 'USED_FOR_NEED_GENERATION',
      'ac000000-0000-0000-0000-000000000002', transaction_timestamp(),
      'ac000000-0000-0000-0000-000000009999'
    )
  $$,
  '23514',
  'new attendance batches must enter as DRAFT',
  'new Attendance cannot enter directly as USED_FOR_NEED_GENERATION'
);

select throws_ok(
  $$
    insert into atlas_planning.attendance_batches (
      attendance_batch_id, period_start, period_end, source_type, source_name,
      source_signature, imported_by_actor_id, attendance_status
    ) values (
      'ac000000-0000-0000-0000-000000000204',
      date '2026-08-04', date '2026-08-04', 'CSV', 'invalid.csv', 'invalid',
      'ac000000-0000-0000-0000-000000000001', 'REOPENED'
    )
  $$,
  '23514',
  'new attendance batches must enter as DRAFT',
  'new Attendance cannot enter directly as REOPENED'
);

select throws_ok(
  $$
    insert into atlas_planning.attendance_batches (
      period_start, period_end, source_type, source_name, source_signature,
      imported_by_actor_id
    ) values (
      date '2026-09-02', date '2026-09-01', 'CSV', 'reverse.csv', 'reverse',
      'ac000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514', null,
  'Attendance period end cannot precede period start'
);

select throws_ok(
  $$
    insert into atlas_planning.attendance_batches (
      period_start, period_end, source_type, source_name, source_signature,
      imported_by_actor_id
    ) values (
      date '2026-07-20', date '2026-07-24', 'CSV', 'duplicate.csv', 'duplicate',
      'ac000000-0000-0000-0000-000000000001'
    )
  $$,
  '23505', null,
  'only one stable Attendance batch exists for an exact period tuple'
);

select throws_ok(
  $$
    insert into atlas_planning.attendance_batches (
      period_start, period_end, source_type, source_name, source_signature,
      imported_by_actor_id
    ) values (
      date '2026-09-03', date '2026-09-03', '  ', 'blank.csv', 'blank',
      'ac000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514', null,
  'source type must be nonblank'
);

select throws_ok(
  $$
    insert into atlas_planning.attendance_batches (
      period_start, period_end, source_type, source_name, source_signature,
      imported_by_actor_id
    ) values (
      date '2026-09-04', date '2026-09-04', 'CSV', '  ', 'blank',
      'ac000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514', null,
  'source name must be nonblank'
);

select throws_ok(
  $$
    insert into atlas_planning.attendance_batches (
      period_start, period_end, source_type, source_name, source_signature,
      imported_by_actor_id
    ) values (
      date '2026-09-05', date '2026-09-05', 'CSV', 'blank.csv', '  ',
      'ac000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514', null,
  'source signature must be nonblank'
);

select throws_ok(
  $$
    insert into atlas_planning.attendance_batches (
      period_start, period_end, source_type, source_name, source_signature,
      row_count, imported_by_actor_id
    ) values (
      date '2026-09-06', date '2026-09-06', 'CSV', 'negative.csv', 'negative',
      -1, 'ac000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514', null,
  'Attendance row count cannot be negative'
);

select throws_ok(
  $$
    insert into atlas_planning.attendance_batches (
      period_start, period_end, source_type, source_name, source_signature,
      version, imported_by_actor_id
    ) values (
      date '2026-09-07', date '2026-09-07', 'CSV', 'zero-version.csv',
      'zero-version', 0, 'ac000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514', null,
  'Attendance version must be positive'
);

select lives_ok(
  $$
    update atlas_planning.attendance_batches
    set source_type = 'XLSX',
        source_name = 'lifecycle-one-corrected.xlsx',
        source_signature = 'sha256:lifecycle-one-corrected',
        row_count = 4,
        imported_by_actor_id = 'ac000000-0000-0000-0000-000000000003',
        imported_at = timestamptz '2026-07-20 08:10:00+07',
        updated_at = updated_at + interval '1 second'
    where attendance_batch_id = 'ac000000-0000-0000-0000-000000000200'
  $$,
  'same-state DRAFT refresh replaces only working source/import evidence'
);

select ok(
  exists (
    select 1
    from atlas_planning.attendance_batches
    where attendance_batch_id = 'ac000000-0000-0000-0000-000000000200'
      and period_start = date '2026-07-20'
      and period_end = date '2026-07-24'
      and source_type = 'XLSX'
      and source_name = 'lifecycle-one-corrected.xlsx'
      and source_signature = 'sha256:lifecycle-one-corrected'
      and row_count = 4
      and imported_by_actor_id = 'ac000000-0000-0000-0000-000000000003'
      and imported_at = timestamptz '2026-07-20 08:10:00+07'
      and version = 1
      and latest_approval_snapshot_id is null
  ),
  'DRAFT refresh preserves root, inclusive period, version, and empty approval history'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set version = version + 1
    where attendance_batch_id = 'ac000000-0000-0000-0000-000000000200'
  $$,
  '23514',
  'working attendance refreshes preserve version and approval history',
  'same-state DRAFT refresh cannot change version'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set period_end = period_end + 1
    where attendance_batch_id = 'ac000000-0000-0000-0000-000000000200'
  $$,
  '23514',
  'attendance batch identity and service-period scope are immutable',
  'the stable Attendance period is immutable'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_batch_id = 'ac000000-0000-0000-0000-000000009990'
    where attendance_batch_id = 'ac000000-0000-0000-0000-000000000200'
  $$,
  '23514',
  'attendance batch identity and service-period scope are immutable',
  'the stable Attendance root identity is immutable'
);

select lives_ok(
  $$
    insert into atlas_planning.attendance_lines (
      attendance_line_id, attendance_batch_id, school_id, service_date,
      student_portions, teacher_portions, line_status, source_row_reference,
      created_by_actor_id, updated_by_actor_id
    ) values
      (
        'ac000000-0000-0000-0000-000000000210',
        'ac000000-0000-0000-0000-000000000200',
        'ac000000-0000-0000-0000-000000000120', date '2026-07-20',
        0, 0, 'ACTIVE', 'Sheet1!A2',
        'ac000000-0000-0000-0000-000000000001',
        'ac000000-0000-0000-0000-000000000001'
      ),
      (
        'ac000000-0000-0000-0000-000000000211',
        'ac000000-0000-0000-0000-000000000200',
        'ac000000-0000-0000-0000-000000000121', date '2026-07-21',
        100, 5, 'ACTIVE', 'Sheet1!B2',
        'ac000000-0000-0000-0000-000000000001',
        'ac000000-0000-0000-0000-000000000001'
      ),
      (
        'ac000000-0000-0000-0000-000000000212',
        'ac000000-0000-0000-0000-000000000200',
        'ac000000-0000-0000-0000-000000000120', date '2026-07-22',
        50, 2, 'INVALID', 'Sheet1!C2',
        'ac000000-0000-0000-0000-000000000001',
        'ac000000-0000-0000-0000-000000000001'
      )
  $$,
  'DRAFT accepts exact lines, zero portions, and an INACTIVE School without inventing active-School policy'
);

select is(
  (
    select row(student_portions, teacher_portions)::text
    from atlas_planning.attendance_lines
    where attendance_line_id = 'ac000000-0000-0000-0000-000000000210'
  ),
  '(0,0)',
  'zero student and teacher portions persist exactly'
);

select throws_ok(
  $$
    insert into atlas_planning.attendance_lines (
      attendance_batch_id, school_id, service_date, student_portions,
      teacher_portions, created_by_actor_id, updated_by_actor_id
    ) values (
      'ac000000-0000-0000-0000-000000000200',
      'ac000000-0000-0000-0000-000000000121', date '2026-07-23', -1, 0,
      'ac000000-0000-0000-0000-000000000001',
      'ac000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514', null,
  'student portions cannot be negative'
);

select throws_ok(
  $$
    insert into atlas_planning.attendance_lines (
      attendance_batch_id, school_id, service_date, student_portions,
      teacher_portions, created_by_actor_id, updated_by_actor_id
    ) values (
      'ac000000-0000-0000-0000-000000000200',
      'ac000000-0000-0000-0000-000000000121', date '2026-07-23', 0, -1,
      'ac000000-0000-0000-0000-000000000001',
      'ac000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514', null,
  'teacher portions cannot be negative'
);

select throws_ok(
  $$
    insert into atlas_planning.attendance_lines (
      attendance_batch_id, school_id, service_date, student_portions,
      teacher_portions, created_by_actor_id, updated_by_actor_id
    ) values (
      'ac000000-0000-0000-0000-000000000200',
      'ac000000-0000-0000-0000-000000000121', date '2026-07-19', 1, 0,
      'ac000000-0000-0000-0000-000000000001',
      'ac000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514',
  'attendance line service date must be inside the batch service period',
  'attendance line date cannot precede the inclusive period'
);

select throws_ok(
  $$
    insert into atlas_planning.attendance_lines (
      attendance_batch_id, school_id, service_date, student_portions,
      teacher_portions, created_by_actor_id, updated_by_actor_id
    ) values (
      'ac000000-0000-0000-0000-000000000200',
      'ac000000-0000-0000-0000-000000000121', date '2026-07-25', 1, 0,
      'ac000000-0000-0000-0000-000000000001',
      'ac000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514',
  'attendance line service date must be inside the batch service period',
  'attendance line date cannot follow the inclusive period'
);

select throws_ok(
  $$
    insert into atlas_planning.attendance_lines (
      attendance_batch_id, school_id, service_date, student_portions,
      teacher_portions, source_row_reference, created_by_actor_id, updated_by_actor_id
    ) values (
      'ac000000-0000-0000-0000-000000000200',
      'ac000000-0000-0000-0000-000000000121', date '2026-07-23', 1, 0, '  ',
      'ac000000-0000-0000-0000-000000000001',
      'ac000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514', null,
  'optional source row reference is null or nonblank'
);

select throws_ok(
  $$
    insert into atlas_planning.attendance_lines (
      attendance_batch_id, school_id, service_date, student_portions,
      teacher_portions, created_by_actor_id, updated_by_actor_id
    ) values (
      'ac000000-0000-0000-0000-000000000200',
      'ac000000-0000-0000-0000-000000000120', date '2026-07-20', 1, 0,
      'ac000000-0000-0000-0000-000000000001',
      'ac000000-0000-0000-0000-000000000001'
    )
  $$,
  '23505', null,
  'one stable attendance line exists per batch/School/date'
);

select lives_ok(
  $$
    insert into atlas_planning.attendance_lines (
      attendance_line_id, attendance_batch_id, school_id, service_date,
      student_portions, teacher_portions, source_row_reference,
      created_by_actor_id, updated_by_actor_id
    ) values (
      'ac000000-0000-0000-0000-000000000213',
      'ac000000-0000-0000-0000-000000000200',
      'ac000000-0000-0000-0000-000000000121', date '2026-07-23',
      1, 1, 'Sheet1!D2',
      'ac000000-0000-0000-0000-000000000001',
      'ac000000-0000-0000-0000-000000000001'
    );
    update atlas_planning.attendance_lines
    set school_id = 'ac000000-0000-0000-0000-000000000120',
        service_date = date '2026-07-24',
        student_portions = 2,
        teacher_portions = 0,
        line_status = 'INVALID',
        source_row_reference = 'Sheet1!D2-corrected',
        updated_by_actor_id = 'ac000000-0000-0000-0000-000000000003',
        updated_at = updated_at + interval '1 second'
    where attendance_line_id = 'ac000000-0000-0000-0000-000000000213';
    delete from atlas_planning.attendance_lines
    where attendance_line_id = 'ac000000-0000-0000-0000-000000000213'
  $$,
  'DRAFT permits line insert, full content update, and delete'
);

select throws_ok(
  $$
    update atlas_planning.attendance_lines
    set attendance_line_id = 'ac000000-0000-0000-0000-000000009991'
    where attendance_line_id = 'ac000000-0000-0000-0000-000000000210'
  $$,
  '23514',
  'stable attendance line identity and ownership are immutable',
  'stable attendance line UUID is immutable'
);

select throws_ok(
  $$
    update atlas_planning.attendance_lines
    set attendance_batch_id = 'ac000000-0000-0000-0000-000000009992'
    where attendance_line_id = 'ac000000-0000-0000-0000-000000000210'
  $$,
  '23514',
  'stable attendance line identity and ownership are immutable',
  'stable attendance line batch ownership is immutable'
);

select throws_ok(
  $$
    update atlas_planning.attendance_lines
    set created_by_actor_id = 'ac000000-0000-0000-0000-000000000003'
    where attendance_line_id = 'ac000000-0000-0000-0000-000000000210'
  $$,
  '23514',
  'stable attendance line identity and ownership are immutable',
  'stable attendance line creator is immutable'
);

select throws_ok(
  $$
    update atlas_planning.attendance_lines
    set created_at = created_at + interval '1 second'
    where attendance_line_id = 'ac000000-0000-0000-0000-000000000210'
  $$,
  '23514',
  'stable attendance line identity and ownership are immutable',
  'stable attendance line creation time is immutable'
);

select throws_ok(
  $$
    delete from atlas_admin.schools
    where school_id = 'ac000000-0000-0000-0000-000000000120'
  $$,
  '23503', null,
  'Attendance School references use ON DELETE RESTRICT without active-status enforcement'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'APPROVED'
    where attendance_batch_id = 'ac000000-0000-0000-0000-000000000200'
  $$,
  '23514', null,
  'DRAFT cannot skip directly to APPROVED'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'REOPENED', version = version + 1
    where attendance_batch_id = 'ac000000-0000-0000-0000-000000000200'
  $$,
  '23514',
  'attendance lifecycle transition is invalid',
  'DRAFT cannot skip directly to REOPENED'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'VALIDATED', source_signature = 'smuggled-draft-validation'
    where attendance_batch_id = 'ac000000-0000-0000-0000-000000000200'
  $$,
  '23514', null,
  'DRAFT to VALIDATED preserves source evidence'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'VALIDATED', version = version + 1
    where attendance_batch_id = 'ac000000-0000-0000-0000-000000000200'
  $$,
  '23514', null,
  'DRAFT to VALIDATED preserves the current version'
);

select lives_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'VALIDATED'
    where attendance_batch_id = 'ac000000-0000-0000-0000-000000000200'
  $$,
  'DRAFT advances to VALIDATED at the same version'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'DRAFT'
    where attendance_batch_id = 'ac000000-0000-0000-0000-000000000200'
  $$,
  '23514',
  'attendance lifecycle transition is invalid',
  'VALIDATED cannot reverse directly to DRAFT'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'USED_FOR_NEED_GENERATION'
    where attendance_batch_id = 'ac000000-0000-0000-0000-000000000200'
  $$,
  '23514', null,
  'VALIDATED cannot skip directly to USED_FOR_NEED_GENERATION'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set source_name = 'frozen-validated.csv'
    where attendance_batch_id = 'ac000000-0000-0000-0000-000000000200'
  $$,
  '23514', null,
  'same-state VALIDATED cannot mutate source evidence'
);

select throws_ok(
  $$
    insert into atlas_planning.attendance_lines (
      attendance_batch_id, school_id, service_date, student_portions,
      teacher_portions, created_by_actor_id, updated_by_actor_id
    ) values (
      'ac000000-0000-0000-0000-000000000200',
      'ac000000-0000-0000-0000-000000000121', date '2026-07-23', 1, 0,
      'ac000000-0000-0000-0000-000000000001',
      'ac000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514', null,
  'VALIDATED blocks attendance-line insert'
);

select throws_ok(
  $$
    update atlas_planning.attendance_lines
    set student_portions = 101
    where attendance_line_id = 'ac000000-0000-0000-0000-000000000211'
  $$,
  '23514', null,
  'VALIDATED blocks attendance-line update'
);

select throws_ok(
  $$
    delete from atlas_planning.attendance_lines
    where attendance_line_id = 'ac000000-0000-0000-0000-000000000212'
  $$,
  '23514', null,
  'VALIDATED blocks attendance-line delete'
);

-- Exact snapshot rows are fixture setup only; snapshot behavior belongs to the integrity suite.
insert into atlas_planning.attendance_approval_snapshots (
  attendance_approval_snapshot_id, attendance_batch_id, attendance_version,
  approved_by_actor_id, approved_at
) values (
  'ac000000-0000-0000-0000-000000000220',
  'ac000000-0000-0000-0000-000000000200', 1,
  'ac000000-0000-0000-0000-000000000002',
  timestamptz '2026-07-20 09:00:00+07'
);

insert into atlas_planning.attendance_approval_snapshot_lines (
  attendance_approval_snapshot_line_id, attendance_approval_snapshot_id,
  attendance_batch_id, attendance_version, attendance_line_id, school_id,
  service_date, student_portions, teacher_portions, source_row_reference
) values
  (
    'ac000000-0000-0000-0000-000000000221',
    'ac000000-0000-0000-0000-000000000220',
    'ac000000-0000-0000-0000-000000000200', 1,
    'ac000000-0000-0000-0000-000000000210',
    'ac000000-0000-0000-0000-000000000120', date '2026-07-20',
    0, 0, 'Sheet1!A2'
  ),
  (
    'ac000000-0000-0000-0000-000000000222',
    'ac000000-0000-0000-0000-000000000220',
    'ac000000-0000-0000-0000-000000000200', 1,
    'ac000000-0000-0000-0000-000000000211',
    'ac000000-0000-0000-0000-000000000121', date '2026-07-21',
    100, 5, 'Sheet1!B2'
  );

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'APPROVED',
        source_signature = 'smuggled-validation-approval',
        latest_approved_by_actor_id = 'ac000000-0000-0000-0000-000000000002',
        latest_approved_at = timestamptz '2026-07-20 09:00:00+07',
        latest_approval_snapshot_id = 'ac000000-0000-0000-0000-000000000220'
    where attendance_batch_id = 'ac000000-0000-0000-0000-000000000200'
  $$,
  '23514', null,
  'VALIDATED to APPROVED preserves source evidence'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'APPROVED', version = version + 1,
        latest_approved_by_actor_id = 'ac000000-0000-0000-0000-000000000002',
        latest_approved_at = timestamptz '2026-07-20 09:00:00+07',
        latest_approval_snapshot_id = 'ac000000-0000-0000-0000-000000000220'
    where attendance_batch_id = 'ac000000-0000-0000-0000-000000000200'
  $$,
  '23514', null,
  'VALIDATED to APPROVED preserves version'
);

update atlas_planning.attendance_batches
set attendance_status = 'APPROVED',
    latest_approved_by_actor_id = 'ac000000-0000-0000-0000-000000000002',
    latest_approved_at = timestamptz '2026-07-20 09:00:00+07',
    latest_approval_snapshot_id = 'ac000000-0000-0000-0000-000000000220'
where attendance_batch_id = 'ac000000-0000-0000-0000-000000000200';
set constraints all immediate;
set constraints all deferred;

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set source_name = 'frozen-approved.csv'
    where attendance_batch_id = 'ac000000-0000-0000-0000-000000000200'
  $$,
  '23514', null,
  'same-state APPROVED cannot mutate source evidence'
);

select throws_ok(
  $$
    insert into atlas_planning.attendance_lines (
      attendance_batch_id, school_id, service_date, student_portions,
      teacher_portions, created_by_actor_id, updated_by_actor_id
    ) values (
      'ac000000-0000-0000-0000-000000000200',
      'ac000000-0000-0000-0000-000000000121', date '2026-07-23', 1, 0,
      'ac000000-0000-0000-0000-000000000001',
      'ac000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514', null,
  'APPROVED blocks attendance-line insert'
);

select throws_ok(
  $$
    update atlas_planning.attendance_lines
    set teacher_portions = 6
    where attendance_line_id = 'ac000000-0000-0000-0000-000000000211'
  $$,
  '23514', null,
  'APPROVED blocks attendance-line update'
);

select throws_ok(
  $$
    delete from atlas_planning.attendance_lines
    where attendance_line_id = 'ac000000-0000-0000-0000-000000000212'
  $$,
  '23514', null,
  'APPROVED blocks attendance-line delete'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'USED_FOR_NEED_GENERATION', row_count = row_count + 1
    where attendance_batch_id = 'ac000000-0000-0000-0000-000000000200'
  $$,
  '23514', null,
  'APPROVED to USED_FOR_NEED_GENERATION preserves source evidence'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'USED_FOR_NEED_GENERATION', version = version + 1
    where attendance_batch_id = 'ac000000-0000-0000-0000-000000000200'
  $$,
  '23514', null,
  'APPROVED to USED_FOR_NEED_GENERATION preserves version'
);

select lives_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'USED_FOR_NEED_GENERATION'
    where attendance_batch_id = 'ac000000-0000-0000-0000-000000000200';
    set constraints all immediate;
    set constraints all deferred
  $$,
  'APPROVED advances to USED_FOR_NEED_GENERATION at the same version'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set source_signature = 'frozen-used'
    where attendance_batch_id = 'ac000000-0000-0000-0000-000000000200'
  $$,
  '23514', null,
  'same-state USED_FOR_NEED_GENERATION cannot mutate source evidence'
);

select throws_ok(
  $$
    insert into atlas_planning.attendance_lines (
      attendance_batch_id, school_id, service_date, student_portions,
      teacher_portions, created_by_actor_id, updated_by_actor_id
    ) values (
      'ac000000-0000-0000-0000-000000000200',
      'ac000000-0000-0000-0000-000000000121', date '2026-07-23', 1, 0,
      'ac000000-0000-0000-0000-000000000001',
      'ac000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514', null,
  'USED_FOR_NEED_GENERATION blocks attendance-line insert'
);

select throws_ok(
  $$
    update atlas_planning.attendance_lines
    set student_portions = 101
    where attendance_line_id = 'ac000000-0000-0000-0000-000000000211'
  $$,
  '23514', null,
  'USED_FOR_NEED_GENERATION blocks attendance-line update'
);

select throws_ok(
  $$
    delete from atlas_planning.attendance_lines
    where attendance_line_id = 'ac000000-0000-0000-0000-000000000212'
  $$,
  '23514', null,
  'USED_FOR_NEED_GENERATION blocks attendance-line delete'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'APPROVED'
    where attendance_batch_id = 'ac000000-0000-0000-0000-000000000200'
  $$,
  '23514', null,
  'USED_FOR_NEED_GENERATION cannot reverse directly to APPROVED'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'REOPENED'
    where attendance_batch_id = 'ac000000-0000-0000-0000-000000000200'
  $$,
  '23514', null,
  'reopen cannot reuse the approved version'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'REOPENED', version = version + 2
    where attendance_batch_id = 'ac000000-0000-0000-0000-000000000200'
  $$,
  '23514', null,
  'reopen cannot skip more than one version'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'REOPENED', version = version + 1,
        source_name = 'smuggled-used-reopen.csv'
    where attendance_batch_id = 'ac000000-0000-0000-0000-000000000200'
  $$,
  '23514', null,
  'USED_FOR_NEED_GENERATION to REOPENED preserves source evidence'
);

select lives_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'REOPENED', version = version + 1
    where attendance_batch_id = 'ac000000-0000-0000-0000-000000000200'
  $$,
  'USED_FOR_NEED_GENERATION reopens at exactly version plus one'
);

select is(
  (
    select row(attendance_status, version)::text
    from atlas_planning.attendance_batches
    where attendance_batch_id = 'ac000000-0000-0000-0000-000000000200'
  ),
  '(REOPENED,2)',
  'reopen advances the stable working root to exactly the next version'
);

select lives_ok(
  $$
    update atlas_planning.attendance_batches
    set source_type = 'MANUAL_CORRECTION',
        source_name = 'lifecycle-one-reopened.csv',
        source_signature = 'sha256:lifecycle-one-reopened',
        row_count = 3,
        imported_by_actor_id = 'ac000000-0000-0000-0000-000000000001',
        imported_at = timestamptz '2026-07-20 10:00:00+07',
        updated_at = updated_at + interval '1 second'
    where attendance_batch_id = 'ac000000-0000-0000-0000-000000000200'
  $$,
  'same-state REOPENED refresh replaces only working source/import evidence'
);

select ok(
  exists (
    select 1
    from atlas_planning.attendance_batches
    where attendance_batch_id = 'ac000000-0000-0000-0000-000000000200'
      and source_type = 'MANUAL_CORRECTION'
      and source_name = 'lifecycle-one-reopened.csv'
      and source_signature = 'sha256:lifecycle-one-reopened'
      and row_count = 3
      and imported_by_actor_id = 'ac000000-0000-0000-0000-000000000001'
      and imported_at = timestamptz '2026-07-20 10:00:00+07'
      and version = 2
  ),
  'REOPENED refresh preserves root, period, and current version'
);

select lives_ok(
  $$
    insert into atlas_planning.attendance_lines (
      attendance_line_id, attendance_batch_id, school_id, service_date,
      student_portions, teacher_portions, source_row_reference,
      created_by_actor_id, updated_by_actor_id
    ) values (
      'ac000000-0000-0000-0000-000000000213',
      'ac000000-0000-0000-0000-000000000200',
      'ac000000-0000-0000-0000-000000000121', date '2026-07-23',
      2, 0, 'Sheet1!D2-reopened',
      'ac000000-0000-0000-0000-000000000001',
      'ac000000-0000-0000-0000-000000000001'
    )
  $$,
  'REOPENED permits attendance-line insert'
);

select lives_ok(
  $$
    update atlas_planning.attendance_lines
    set student_portions = 3,
        teacher_portions = 1,
        updated_by_actor_id = 'ac000000-0000-0000-0000-000000000003',
        updated_at = updated_at + interval '1 second'
    where attendance_line_id = 'ac000000-0000-0000-0000-000000000213'
  $$,
  'REOPENED permits attendance-line update'
);

select lives_ok(
  $$
    delete from atlas_planning.attendance_lines
    where attendance_line_id = 'ac000000-0000-0000-0000-000000000213'
  $$,
  'REOPENED permits attendance-line delete'
);

select lives_ok(
  $$
    update atlas_planning.attendance_lines
    set student_portions = 1,
        source_row_reference = 'Sheet1!A2-corrected',
        updated_by_actor_id = 'ac000000-0000-0000-0000-000000000003',
        updated_at = updated_at + interval '1 second'
    where attendance_line_id = 'ac000000-0000-0000-0000-000000000210'
  $$,
  'REOPENED corrects working line content without changing stable identity'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'DRAFT', source_type = 'smuggled-reopen-draft'
    where attendance_batch_id = 'ac000000-0000-0000-0000-000000000200'
  $$,
  '23514', null,
  'REOPENED to DRAFT preserves source evidence'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'DRAFT', version = version + 1
    where attendance_batch_id = 'ac000000-0000-0000-0000-000000000200'
  $$,
  '23514', null,
  'REOPENED to DRAFT preserves version'
);

select lives_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'DRAFT'
    where attendance_batch_id = 'ac000000-0000-0000-0000-000000000200'
  $$,
  'REOPENED advances to DRAFT at the same later version'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'VALIDATED', version = version - 1
    where attendance_batch_id = 'ac000000-0000-0000-0000-000000000200'
  $$,
  '23514', null,
  'Attendance version cannot decrease on later validation'
);

select lives_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'VALIDATED'
    where attendance_batch_id = 'ac000000-0000-0000-0000-000000000200'
  $$,
  'the reopened working version follows DRAFT to VALIDATED normally'
);

-- A second fixture owns the direct APPROVED to REOPENED branch.
insert into atlas_planning.attendance_batches (
  attendance_batch_id, period_start, period_end, source_type, source_name,
  source_signature, imported_by_actor_id
) values (
  'ac000000-0000-0000-0000-000000000300',
  date '2026-07-27', date '2026-07-29', 'CSV', 'lifecycle-two.csv',
  'sha256:lifecycle-two', 'ac000000-0000-0000-0000-000000000001'
);

insert into atlas_planning.attendance_lines (
  attendance_line_id, attendance_batch_id, school_id, service_date,
  student_portions, teacher_portions, source_row_reference,
  created_by_actor_id, updated_by_actor_id
) values (
  'ac000000-0000-0000-0000-000000000310',
  'ac000000-0000-0000-0000-000000000300',
  'ac000000-0000-0000-0000-000000000120', date '2026-07-27',
  80, 4, 'Sheet2!A2',
  'ac000000-0000-0000-0000-000000000001',
  'ac000000-0000-0000-0000-000000000001'
);

update atlas_planning.attendance_batches
set attendance_status = 'VALIDATED'
where attendance_batch_id = 'ac000000-0000-0000-0000-000000000300';

insert into atlas_planning.attendance_approval_snapshots (
  attendance_approval_snapshot_id, attendance_batch_id, attendance_version,
  approved_by_actor_id, approved_at
) values (
  'ac000000-0000-0000-0000-000000000320',
  'ac000000-0000-0000-0000-000000000300', 1,
  'ac000000-0000-0000-0000-000000000002',
  timestamptz '2026-07-20 12:00:00+07'
);

insert into atlas_planning.attendance_approval_snapshot_lines (
  attendance_approval_snapshot_line_id, attendance_approval_snapshot_id,
  attendance_batch_id, attendance_version, attendance_line_id, school_id,
  service_date, student_portions, teacher_portions, source_row_reference
) values (
  'ac000000-0000-0000-0000-000000000321',
  'ac000000-0000-0000-0000-000000000320',
  'ac000000-0000-0000-0000-000000000300', 1,
  'ac000000-0000-0000-0000-000000000310',
  'ac000000-0000-0000-0000-000000000120', date '2026-07-27',
  80, 4, 'Sheet2!A2'
);

update atlas_planning.attendance_batches
set attendance_status = 'APPROVED',
    latest_approved_by_actor_id = 'ac000000-0000-0000-0000-000000000002',
    latest_approved_at = timestamptz '2026-07-20 12:00:00+07',
    latest_approval_snapshot_id = 'ac000000-0000-0000-0000-000000000320'
where attendance_batch_id = 'ac000000-0000-0000-0000-000000000300';
set constraints all immediate;
set constraints all deferred;

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'REOPENED', version = version + 1,
        source_signature = 'smuggled-approved-reopen'
    where attendance_batch_id = 'ac000000-0000-0000-0000-000000000300'
  $$,
  '23514', null,
  'APPROVED to REOPENED preserves source evidence'
);

select lives_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'REOPENED', version = version + 1
    where attendance_batch_id = 'ac000000-0000-0000-0000-000000000300'
  $$,
  'APPROVED may reopen directly at exactly version plus one'
);

select is(
  (
    select row(attendance_status, version)::text
    from atlas_planning.attendance_batches
    where attendance_batch_id = 'ac000000-0000-0000-0000-000000000300'
  ),
  '(REOPENED,2)',
  'direct APPROVED reopen retains the stable root at the next version'
);

select throws_ok(
  $$
    delete from atlas_planning.attendance_batches
    where attendance_batch_id = 'ac000000-0000-0000-0000-000000000300'
  $$,
  '23514', null,
  'historically approved Attendance roots cannot be deleted'
);

insert into atlas_planning.attendance_batches (
  attendance_batch_id, period_start, period_end, source_type, source_name,
  source_signature, imported_by_actor_id
) values (
  'ac000000-0000-0000-0000-000000000400',
  date '2026-08-10', date '2026-08-10', 'CSV', 'disposable.csv',
  'sha256:disposable', 'ac000000-0000-0000-0000-000000000001'
);

select lives_ok(
  $$
    delete from atlas_planning.attendance_batches
    where attendance_batch_id = 'ac000000-0000-0000-0000-000000000400'
  $$,
  'an untouched DRAFT Attendance root may be deleted'
);

select * from finish();

rollback;
