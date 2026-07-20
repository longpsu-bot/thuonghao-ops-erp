begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;

select plan(126);

-- Bounded structure and canonical fields.
select is(
  (
    select array_agg(c.relname order by c.relname)::text[]
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'atlas_planning'
      and c.relkind = 'r'
      and c.relname like 'attendance%'
  ),
  array[
    'attendance_approval_snapshot_lines',
    'attendance_approval_snapshots',
    'attendance_batches',
    'attendance_lines'
  ]::text[],
  'H0A3b creates exactly the four approved private Attendance relations'
);

select is(
  (
    select array_agg(a.attname order by a.attnum)::text[]
    from pg_attribute a
    where a.attrelid = 'atlas_planning.attendance_batches'::regclass
      and a.attnum > 0
      and not a.attisdropped
  ),
  array[
    'attendance_batch_id',
    'period_start',
    'period_end',
    'source_type',
    'source_name',
    'source_signature',
    'attendance_status',
    'row_count',
    'imported_by_actor_id',
    'imported_at',
    'latest_approved_by_actor_id',
    'latest_approved_at',
    'latest_approval_snapshot_id',
    'version',
    'created_at',
    'updated_at'
  ]::text[],
  'attendance_batches has only the bounded source, lifecycle, approval, and version fields'
);

select is(
  (
    select array_agg(a.attname order by a.attnum)::text[]
    from pg_attribute a
    where a.attrelid = 'atlas_planning.attendance_lines'::regclass
      and a.attnum > 0
      and not a.attisdropped
  ),
  array[
    'attendance_line_id',
    'attendance_batch_id',
    'school_id',
    'service_date',
    'student_portions',
    'teacher_portions',
    'line_status',
    'source_row_reference',
    'created_by_actor_id',
    'created_at',
    'updated_by_actor_id',
    'updated_at'
  ]::text[],
  'attendance_lines has only stable school/date exact portions and actor/time fields'
);

select is(
  (
    select array_agg(a.attname order by a.attnum)::text[]
    from pg_attribute a
    where a.attrelid = 'atlas_planning.attendance_approval_snapshots'::regclass
      and a.attnum > 0
      and not a.attisdropped
  ),
  array[
    'attendance_approval_snapshot_id',
    'attendance_batch_id',
    'attendance_version',
    'approved_by_actor_id',
    'approved_at'
  ]::text[],
  'Attendance approval headers contain only exact batch/version and approval evidence'
);

select is(
  (
    select array_agg(a.attname order by a.attnum)::text[]
    from pg_attribute a
    where a.attrelid = 'atlas_planning.attendance_approval_snapshot_lines'::regclass
      and a.attnum > 0
      and not a.attisdropped
  ),
  array[
    'attendance_approval_snapshot_line_id',
    'attendance_approval_snapshot_id',
    'attendance_batch_id',
    'attendance_version',
    'attendance_line_id',
    'school_id',
    'service_date',
    'student_portions',
    'teacher_portions',
    'source_row_reference'
  ]::text[],
  'Attendance approval snapshot lines contain only the exact accepted line copy'
);

select is(
  (
    select count(*)::integer
    from pg_attrdef ad
    join pg_attribute a
      on a.attrelid = ad.adrelid
     and a.attnum = ad.adnum
    where ad.adrelid in (
      'atlas_planning.attendance_batches'::regclass,
      'atlas_planning.attendance_lines'::regclass,
      'atlas_planning.attendance_approval_snapshots'::regclass,
      'atlas_planning.attendance_approval_snapshot_lines'::regclass
    )
      and a.attname in (
        'attendance_batch_id',
        'attendance_line_id',
        'attendance_approval_snapshot_id',
        'attendance_approval_snapshot_line_id'
      )
      and pg_get_expr(ad.adbin, ad.adrelid) = 'gen_random_uuid()'
  ),
  4,
  'all four H0A3b identities are database-generated UUIDs'
);

select is(
  (
    select array_agg(format_type(a.atttypid, a.atttypmod) order by a.attname)::text[]
    from pg_attribute a
    where a.attrelid in (
      'atlas_planning.attendance_lines'::regclass,
      'atlas_planning.attendance_approval_snapshot_lines'::regclass
    )
      and a.attname in ('student_portions', 'teacher_portions')
      and a.attnum > 0
      and not a.attisdropped
  ),
  array['integer', 'integer', 'integer', 'integer']::text[],
  'working and approved student/teacher portions are exact integers'
);

select ok(
  to_regclass('atlas_planning.attendance_issues') is null
  and to_regclass('atlas_planning.attendance_events') is null
  and to_regclass('atlas_planning.attendance_defaults') is null,
  'H0A3b creates no issue, event, reason, default, or policy relation'
);

select ok(
  to_regclass('public.attendance_batches') is null
  and to_regclass('ops_v2.attendance_batches') is null,
  'H0A3b creates no public or OPS v2 Attendance relation'
);

-- Synthetic local-only owners and reference data.
insert into atlas_core.actors (actor_id, actor_type, display_name) values
  ('ab000000-0000-0000-0000-000000000001', 'HUMAN', 'H0A3b importer'),
  ('ab000000-0000-0000-0000-000000000002', 'HUMAN', 'H0A3b approver'),
  ('ab000000-0000-0000-0000-000000000003', 'HUMAN', 'H0A3b alternate');

insert into atlas_admin.customers (
  customer_id, customer_code, customer_name, customer_type
) values (
  'ab000000-0000-0000-0000-000000000100',
  'pa06e-h0a3b-customer',
  'PA-06E-H0A3b synthetic customer',
  'SCHOOL_CATERING'
);

insert into atlas_admin.delivery_locations (
  delivery_location_id, customer_id, location_code, location_name,
  address_text, timezone_name
) values (
  'ab000000-0000-0000-0000-000000000101',
  'ab000000-0000-0000-0000-000000000100',
  'pa06e-h0a3b-location',
  'PA-06E-H0A3b synthetic location',
  'Synthetic local-only address',
  'Asia/Ho_Chi_Minh'
);

insert into atlas_admin.school_types (
  school_type_id, school_type_code, school_type_name
) values (
  'ab000000-0000-0000-0000-000000000110',
  'pa06e-h0a3b-primary',
  'PA-06E-H0A3b Primary'
);

insert into atlas_admin.schools (
  school_id, customer_id, school_code, school_name, school_type_id,
  default_delivery_location_id, display_order
) values
  (
    'ab000000-0000-0000-0000-000000000120',
    'ab000000-0000-0000-0000-000000000100',
    'pa06e-h0a3b-school-a',
    'PA-06E-H0A3b School A',
    'ab000000-0000-0000-0000-000000000110',
    'ab000000-0000-0000-0000-000000000101',
    10
  ),
  (
    'ab000000-0000-0000-0000-000000000121',
    'ab000000-0000-0000-0000-000000000100',
    'pa06e-h0a3b-school-b',
    'PA-06E-H0A3b School B',
    'ab000000-0000-0000-0000-000000000110',
    'ab000000-0000-0000-0000-000000000101',
    20
  );

update atlas_admin.schools
set school_status = 'INACTIVE'
where school_id = 'ab000000-0000-0000-0000-000000000121';

-- Root creation, constraints, inclusive arbitrary period, and DRAFT refresh.
select lives_ok(
  $$
    insert into atlas_planning.attendance_batches (
      attendance_batch_id, period_start, period_end, source_type, source_name,
      source_signature, row_count, imported_by_actor_id, imported_at,
      created_at, updated_at
    ) values (
      'ab000000-0000-0000-0000-000000000200',
      date '2026-07-20', date '2026-07-24',
      'CSV', 'attendance-one.csv', 'sha256:attendance-one', 3,
      'ab000000-0000-0000-0000-000000000001',
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
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200'
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
      'ab000000-0000-0000-0000-000000000201',
      date '2026-08-01', date '2026-08-01', 'CSV', 'invalid.csv', 'invalid',
      'ab000000-0000-0000-0000-000000000001', 'VALIDATED'
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
      'ab000000-0000-0000-0000-000000000202',
      date '2026-08-02', date '2026-08-02', 'CSV', 'invalid.csv', 'invalid',
      'ab000000-0000-0000-0000-000000000001', 'APPROVED',
      'ab000000-0000-0000-0000-000000000002', transaction_timestamp(),
      'ab000000-0000-0000-0000-000000009999'
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
      'ab000000-0000-0000-0000-000000000203',
      date '2026-08-03', date '2026-08-03', 'CSV', 'invalid.csv', 'invalid',
      'ab000000-0000-0000-0000-000000000001', 'USED_FOR_NEED_GENERATION',
      'ab000000-0000-0000-0000-000000000002', transaction_timestamp(),
      'ab000000-0000-0000-0000-000000009999'
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
      'ab000000-0000-0000-0000-000000000204',
      date '2026-08-04', date '2026-08-04', 'CSV', 'invalid.csv', 'invalid',
      'ab000000-0000-0000-0000-000000000001', 'REOPENED'
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
      'ab000000-0000-0000-0000-000000000001'
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
      'ab000000-0000-0000-0000-000000000001'
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
      'ab000000-0000-0000-0000-000000000001'
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
      'ab000000-0000-0000-0000-000000000001'
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
      'ab000000-0000-0000-0000-000000000001'
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
      -1, 'ab000000-0000-0000-0000-000000000001'
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
      'zero-version', 0, 'ab000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514', null,
  'Attendance version must be positive'
);

select lives_ok(
  $$
    update atlas_planning.attendance_batches
    set source_type = 'XLSX',
        source_name = 'attendance-one-corrected.xlsx',
        source_signature = 'sha256:attendance-one-corrected',
        row_count = 4,
        imported_by_actor_id = 'ab000000-0000-0000-0000-000000000003',
        imported_at = timestamptz '2026-07-20 08:10:00+07',
        updated_at = updated_at + interval '1 second'
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200'
  $$,
  'same-state DRAFT refresh replaces only the complete source/import evidence'
);

select ok(
  exists (
    select 1
    from atlas_planning.attendance_batches
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200'
      and period_start = date '2026-07-20'
      and period_end = date '2026-07-24'
      and source_type = 'XLSX'
      and source_name = 'attendance-one-corrected.xlsx'
      and source_signature = 'sha256:attendance-one-corrected'
      and row_count = 4
      and imported_by_actor_id = 'ab000000-0000-0000-0000-000000000003'
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
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200'
  $$,
  '23514',
  'working attendance refreshes preserve version and approval history',
  'same-state DRAFT refresh cannot change version'
);

-- Stable exact lines in DRAFT, including zero portions.
select lives_ok(
  $$
    insert into atlas_planning.attendance_lines (
      attendance_line_id, attendance_batch_id, school_id, service_date,
      student_portions, teacher_portions, line_status, source_row_reference,
      created_by_actor_id, updated_by_actor_id
    ) values
      (
        'ab000000-0000-0000-0000-000000000210',
        'ab000000-0000-0000-0000-000000000200',
        'ab000000-0000-0000-0000-000000000120', date '2026-07-20',
        0, 0, 'ACTIVE', 'Sheet1!A2',
        'ab000000-0000-0000-0000-000000000001',
        'ab000000-0000-0000-0000-000000000001'
      ),
      (
        'ab000000-0000-0000-0000-000000000211',
        'ab000000-0000-0000-0000-000000000200',
        'ab000000-0000-0000-0000-000000000121', date '2026-07-21',
        100, 5, 'ACTIVE', 'Sheet1!B2',
        'ab000000-0000-0000-0000-000000000001',
        'ab000000-0000-0000-0000-000000000001'
      ),
      (
        'ab000000-0000-0000-0000-000000000212',
        'ab000000-0000-0000-0000-000000000200',
        'ab000000-0000-0000-0000-000000000120', date '2026-07-22',
        50, 2, 'INVALID', 'Sheet1!C2',
        'ab000000-0000-0000-0000-000000000001',
        'ab000000-0000-0000-0000-000000000001'
      )
  $$,
  'DRAFT accepts exact lines, zero portions, and an INACTIVE School without inventing active-school policy'
);

select is(
  (
    select row(student_portions, teacher_portions)::text
    from atlas_planning.attendance_lines
    where attendance_line_id = 'ab000000-0000-0000-0000-000000000210'
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
      'ab000000-0000-0000-0000-000000000200',
      'ab000000-0000-0000-0000-000000000121', date '2026-07-23', -1, 0,
      'ab000000-0000-0000-0000-000000000001',
      'ab000000-0000-0000-0000-000000000001'
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
      'ab000000-0000-0000-0000-000000000200',
      'ab000000-0000-0000-0000-000000000121', date '2026-07-23', 0, -1,
      'ab000000-0000-0000-0000-000000000001',
      'ab000000-0000-0000-0000-000000000001'
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
      'ab000000-0000-0000-0000-000000000200',
      'ab000000-0000-0000-0000-000000000121', date '2026-07-19', 1, 0,
      'ab000000-0000-0000-0000-000000000001',
      'ab000000-0000-0000-0000-000000000001'
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
      'ab000000-0000-0000-0000-000000000200',
      'ab000000-0000-0000-0000-000000000121', date '2026-07-25', 1, 0,
      'ab000000-0000-0000-0000-000000000001',
      'ab000000-0000-0000-0000-000000000001'
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
      'ab000000-0000-0000-0000-000000000200',
      'ab000000-0000-0000-0000-000000000121', date '2026-07-23', 1, 0, '  ',
      'ab000000-0000-0000-0000-000000000001',
      'ab000000-0000-0000-0000-000000000001'
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
      'ab000000-0000-0000-0000-000000000200',
      'ab000000-0000-0000-0000-000000000120', date '2026-07-20', 1, 0,
      'ab000000-0000-0000-0000-000000000001',
      'ab000000-0000-0000-0000-000000000001'
    )
  $$,
  '23505', null,
  'one stable attendance line exists per batch/school/date'
);

select lives_ok(
  $$
    insert into atlas_planning.attendance_lines (
      attendance_line_id, attendance_batch_id, school_id, service_date,
      student_portions, teacher_portions, source_row_reference,
      created_by_actor_id, updated_by_actor_id
    ) values (
      'ab000000-0000-0000-0000-000000000213',
      'ab000000-0000-0000-0000-000000000200',
      'ab000000-0000-0000-0000-000000000121', date '2026-07-23',
      1, 1, 'Sheet1!D2',
      'ab000000-0000-0000-0000-000000000001',
      'ab000000-0000-0000-0000-000000000001'
    );
    update atlas_planning.attendance_lines
    set school_id = 'ab000000-0000-0000-0000-000000000120',
        service_date = date '2026-07-24',
        student_portions = 2,
        teacher_portions = 0,
        line_status = 'INVALID',
        source_row_reference = 'Sheet1!D2-corrected',
        updated_by_actor_id = 'ab000000-0000-0000-0000-000000000003',
        updated_at = updated_at + interval '1 second'
    where attendance_line_id = 'ab000000-0000-0000-0000-000000000213';
    delete from atlas_planning.attendance_lines
    where attendance_line_id = 'ab000000-0000-0000-0000-000000000213'
  $$,
  'DRAFT permits line insert, full content update, and delete'
);

select throws_ok(
  $$
    update atlas_planning.attendance_lines
    set attendance_line_id = 'ab000000-0000-0000-0000-000000009991'
    where attendance_line_id = 'ab000000-0000-0000-0000-000000000210'
  $$,
  '23514',
  'stable attendance line identity and ownership are immutable',
  'stable attendance line UUID is immutable'
);

select throws_ok(
  $$
    update atlas_planning.attendance_lines
    set attendance_batch_id = 'ab000000-0000-0000-0000-000000009992'
    where attendance_line_id = 'ab000000-0000-0000-0000-000000000210'
  $$,
  '23514',
  'stable attendance line identity and ownership are immutable',
  'stable attendance line batch ownership is immutable'
);

select throws_ok(
  $$
    update atlas_planning.attendance_lines
    set created_by_actor_id = 'ab000000-0000-0000-0000-000000000003'
    where attendance_line_id = 'ab000000-0000-0000-0000-000000000210'
  $$,
  '23514',
  'stable attendance line identity and ownership are immutable',
  'stable attendance line creator is immutable'
);

select throws_ok(
  $$
    update atlas_planning.attendance_lines
    set created_at = created_at + interval '1 second'
    where attendance_line_id = 'ab000000-0000-0000-0000-000000000210'
  $$,
  '23514',
  'stable attendance line identity and ownership are immutable',
  'stable attendance line creation time is immutable'
);

select throws_ok(
  $$
    delete from atlas_admin.schools
    where school_id = 'ab000000-0000-0000-0000-000000000120'
  $$,
  '23503', null,
  'Attendance School references use ON DELETE RESTRICT without active-status enforcement'
);

-- Lifecycle validation and frozen-line behavior.
select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'APPROVED'
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200'
  $$,
  '23514', null,
  'DRAFT cannot skip directly to APPROVED'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'REOPENED', version = version + 1
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200'
  $$,
  '23514',
  'attendance lifecycle transition is invalid',
  'DRAFT cannot skip directly to REOPENED'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'VALIDATED', source_signature = 'smuggled-draft-validation'
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200'
  $$,
  '23514', null,
  'DRAFT to VALIDATED preserves source evidence'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'VALIDATED', version = version + 1
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200'
  $$,
  '23514', null,
  'DRAFT to VALIDATED preserves the current version'
);

select lives_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'VALIDATED'
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200'
  $$,
  'DRAFT advances to VALIDATED at the same version'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'DRAFT'
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200'
  $$,
  '23514',
  'attendance lifecycle transition is invalid',
  'VALIDATED cannot reverse directly to DRAFT'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'USED_FOR_NEED_GENERATION'
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200'
  $$,
  '23514', null,
  'VALIDATED cannot skip directly to USED_FOR_NEED_GENERATION'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set source_name = 'frozen-validated.csv'
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200'
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
      'ab000000-0000-0000-0000-000000000200',
      'ab000000-0000-0000-0000-000000000121', date '2026-07-23', 1, 0,
      'ab000000-0000-0000-0000-000000000001',
      'ab000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514', null,
  'VALIDATED blocks attendance-line insert'
);

select throws_ok(
  $$
    update atlas_planning.attendance_lines
    set student_portions = 101
    where attendance_line_id = 'ab000000-0000-0000-0000-000000000211'
  $$,
  '23514', null,
  'VALIDATED blocks attendance-line update'
);

select throws_ok(
  $$
    delete from atlas_planning.attendance_lines
    where attendance_line_id = 'ab000000-0000-0000-0000-000000000212'
  $$,
  '23514', null,
  'VALIDATED blocks attendance-line delete'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'APPROVED'
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200'
  $$,
  '23514', null,
  'VALIDATED cannot approve without exact approval evidence and snapshot reference'
);

-- Snapshot header and exact line-copy guards.
insert into atlas_planning.attendance_batches (
  attendance_batch_id, period_start, period_end, source_type, source_name,
  source_signature, imported_by_actor_id
) values (
  'ab000000-0000-0000-0000-000000000300',
  date '2026-07-27', date '2026-07-29', 'CSV', 'attendance-two.csv',
  'sha256:attendance-two', 'ab000000-0000-0000-0000-000000000001'
);

insert into atlas_planning.attendance_lines (
  attendance_line_id, attendance_batch_id, school_id, service_date,
  student_portions, teacher_portions, source_row_reference,
  created_by_actor_id, updated_by_actor_id
) values (
  'ab000000-0000-0000-0000-000000000310',
  'ab000000-0000-0000-0000-000000000300',
  'ab000000-0000-0000-0000-000000000120', date '2026-07-27',
  80, 4, 'Sheet2!A2',
  'ab000000-0000-0000-0000-000000000001',
  'ab000000-0000-0000-0000-000000000001'
);

select throws_ok(
  $$
    insert into atlas_planning.attendance_approval_snapshots (
      attendance_approval_snapshot_id, attendance_batch_id, attendance_version,
      approved_by_actor_id, approved_at
    ) values (
      'ab000000-0000-0000-0000-000000000320',
      'ab000000-0000-0000-0000-000000000300', 1,
      'ab000000-0000-0000-0000-000000000002', transaction_timestamp()
    )
  $$,
  '23514', null,
  'a DRAFT Attendance batch cannot receive an approval snapshot'
);

select throws_ok(
  $$
    insert into atlas_planning.attendance_approval_snapshots (
      attendance_approval_snapshot_id, attendance_batch_id, attendance_version,
      approved_by_actor_id, approved_at
    ) values (
      'ab000000-0000-0000-0000-000000000219',
      'ab000000-0000-0000-0000-000000000200', 2,
      'ab000000-0000-0000-0000-000000000002', transaction_timestamp()
    )
  $$,
  '23514', null,
  'approval snapshot header rejects a noncurrent Attendance version'
);

insert into atlas_planning.attendance_approval_snapshots (
  attendance_approval_snapshot_id, attendance_batch_id, attendance_version,
  approved_by_actor_id, approved_at
) values (
  'ab000000-0000-0000-0000-000000000220',
  'ab000000-0000-0000-0000-000000000200', 1,
  'ab000000-0000-0000-0000-000000000002',
  timestamptz '2026-07-20 09:00:00+07'
);

select throws_ok(
  $$
    insert into atlas_planning.attendance_approval_snapshots (
      attendance_batch_id, attendance_version, approved_by_actor_id, approved_at
    ) values (
      'ab000000-0000-0000-0000-000000000200', 1,
      'ab000000-0000-0000-0000-000000000002', transaction_timestamp()
    )
  $$,
  '23505', null,
  'only one approval snapshot exists per Attendance batch/version'
);

select throws_ok(
  $$
    insert into atlas_planning.attendance_approval_snapshot_lines (
      attendance_approval_snapshot_id, attendance_batch_id, attendance_version,
      attendance_line_id, school_id, service_date, student_portions,
      teacher_portions, source_row_reference
    ) values (
      'ab000000-0000-0000-0000-000000000220',
      'ab000000-0000-0000-0000-000000000200', 2,
      'ab000000-0000-0000-0000-000000000210',
      'ab000000-0000-0000-0000-000000000120', date '2026-07-20',
      0, 0, 'Sheet1!A2'
    )
  $$,
  '23514', null,
  'snapshot line rejects the wrong Attendance version'
);

select throws_ok(
  $$
    insert into atlas_planning.attendance_approval_snapshot_lines (
      attendance_approval_snapshot_id, attendance_batch_id, attendance_version,
      attendance_line_id, school_id, service_date, student_portions,
      teacher_portions, source_row_reference
    ) values (
      'ab000000-0000-0000-0000-000000000220',
      'ab000000-0000-0000-0000-000000000200', 1,
      'ab000000-0000-0000-0000-000000000310',
      'ab000000-0000-0000-0000-000000000120', date '2026-07-27',
      80, 4, 'Sheet2!A2'
    )
  $$,
  '23514', null,
  'snapshot line rejects cross-batch stable-line ownership'
);

select throws_ok(
  $$
    insert into atlas_planning.attendance_approval_snapshot_lines (
      attendance_approval_snapshot_id, attendance_batch_id, attendance_version,
      attendance_line_id, school_id, service_date, student_portions,
      teacher_portions, source_row_reference
    ) values (
      'ab000000-0000-0000-0000-000000000220',
      'ab000000-0000-0000-0000-000000000200', 1,
      'ab000000-0000-0000-0000-000000000212',
      'ab000000-0000-0000-0000-000000000120', date '2026-07-22',
      50, 2, 'Sheet1!C2'
    )
  $$,
  '23514', null,
  'snapshot rejects INVALID or otherwise extra attendance lines'
);

select throws_ok(
  $$
    insert into atlas_planning.attendance_approval_snapshot_lines (
      attendance_approval_snapshot_id, attendance_batch_id, attendance_version,
      attendance_line_id, school_id, service_date, student_portions,
      teacher_portions, source_row_reference
    ) values (
      'ab000000-0000-0000-0000-000000000220',
      'ab000000-0000-0000-0000-000000000200', 1,
      'ab000000-0000-0000-0000-000000000210',
      'ab000000-0000-0000-0000-000000000121', date '2026-07-20',
      0, 0, 'Sheet1!A2'
    )
  $$,
  '23514', null,
  'snapshot rejects an altered School'
);

select throws_ok(
  $$
    insert into atlas_planning.attendance_approval_snapshot_lines (
      attendance_approval_snapshot_id, attendance_batch_id, attendance_version,
      attendance_line_id, school_id, service_date, student_portions,
      teacher_portions, source_row_reference
    ) values (
      'ab000000-0000-0000-0000-000000000220',
      'ab000000-0000-0000-0000-000000000200', 1,
      'ab000000-0000-0000-0000-000000000210',
      'ab000000-0000-0000-0000-000000000120', date '2026-07-21',
      0, 0, 'Sheet1!A2'
    )
  $$,
  '23514', null,
  'snapshot rejects an altered service date'
);

select throws_ok(
  $$
    insert into atlas_planning.attendance_approval_snapshot_lines (
      attendance_approval_snapshot_id, attendance_batch_id, attendance_version,
      attendance_line_id, school_id, service_date, student_portions,
      teacher_portions, source_row_reference
    ) values (
      'ab000000-0000-0000-0000-000000000220',
      'ab000000-0000-0000-0000-000000000200', 1,
      'ab000000-0000-0000-0000-000000000210',
      'ab000000-0000-0000-0000-000000000120', date '2026-07-20',
      1, 0, 'Sheet1!A2'
    )
  $$,
  '23514', null,
  'snapshot rejects altered student portions'
);

select throws_ok(
  $$
    insert into atlas_planning.attendance_approval_snapshot_lines (
      attendance_approval_snapshot_id, attendance_batch_id, attendance_version,
      attendance_line_id, school_id, service_date, student_portions,
      teacher_portions, source_row_reference
    ) values (
      'ab000000-0000-0000-0000-000000000220',
      'ab000000-0000-0000-0000-000000000200', 1,
      'ab000000-0000-0000-0000-000000000210',
      'ab000000-0000-0000-0000-000000000120', date '2026-07-20',
      0, 1, 'Sheet1!A2'
    )
  $$,
  '23514', null,
  'snapshot rejects altered teacher portions'
);

select throws_ok(
  $$
    insert into atlas_planning.attendance_approval_snapshot_lines (
      attendance_approval_snapshot_id, attendance_batch_id, attendance_version,
      attendance_line_id, school_id, service_date, student_portions,
      teacher_portions, source_row_reference
    ) values (
      'ab000000-0000-0000-0000-000000000220',
      'ab000000-0000-0000-0000-000000000200', 1,
      'ab000000-0000-0000-0000-000000000210',
      'ab000000-0000-0000-0000-000000000120', date '2026-07-20',
      0, 0, 'Sheet1!A2-altered'
    )
  $$,
  '23514', null,
  'snapshot rejects an altered source-row reference'
);

insert into atlas_planning.attendance_approval_snapshot_lines (
  attendance_approval_snapshot_line_id, attendance_approval_snapshot_id,
  attendance_batch_id, attendance_version, attendance_line_id, school_id,
  service_date, student_portions, teacher_portions, source_row_reference
) values (
  'ab000000-0000-0000-0000-000000000221',
  'ab000000-0000-0000-0000-000000000220',
  'ab000000-0000-0000-0000-000000000200', 1,
  'ab000000-0000-0000-0000-000000000210',
  'ab000000-0000-0000-0000-000000000120', date '2026-07-20',
  0, 0, 'Sheet1!A2'
);

select throws_ok(
  $$
    insert into atlas_planning.attendance_approval_snapshot_lines (
      attendance_approval_snapshot_id, attendance_batch_id, attendance_version,
      attendance_line_id, school_id, service_date, student_portions,
      teacher_portions, source_row_reference
    ) values (
      'ab000000-0000-0000-0000-000000000220',
      'ab000000-0000-0000-0000-000000000200', 1,
      'ab000000-0000-0000-0000-000000000210',
      'ab000000-0000-0000-0000-000000000120', date '2026-07-20',
      0, 0, 'Sheet1!A2'
    )
  $$,
  '23505', null,
  'snapshot rejects a duplicate stable Attendance line'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'APPROVED',
        latest_approved_by_actor_id = 'ab000000-0000-0000-0000-000000000002',
        latest_approved_at = timestamptz '2026-07-20 09:00:00+07',
        latest_approval_snapshot_id = 'ab000000-0000-0000-0000-000000000220'
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200';
    set constraints all immediate
  $$,
  '23514', null,
  'approval fails when any ACTIVE attendance line is missing from the snapshot'
);

insert into atlas_planning.attendance_approval_snapshot_lines (
  attendance_approval_snapshot_line_id, attendance_approval_snapshot_id,
  attendance_batch_id, attendance_version, attendance_line_id, school_id,
  service_date, student_portions, teacher_portions, source_row_reference
) values (
  'ab000000-0000-0000-0000-000000000222',
  'ab000000-0000-0000-0000-000000000220',
  'ab000000-0000-0000-0000-000000000200', 1,
  'ab000000-0000-0000-0000-000000000211',
  'ab000000-0000-0000-0000-000000000121', date '2026-07-21',
  100, 5, 'Sheet1!B2'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'APPROVED',
        source_signature = 'smuggled-validation-approval',
        latest_approved_by_actor_id = 'ab000000-0000-0000-0000-000000000002',
        latest_approved_at = timestamptz '2026-07-20 09:00:00+07',
        latest_approval_snapshot_id = 'ab000000-0000-0000-0000-000000000220'
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200'
  $$,
  '23514', null,
  'VALIDATED to APPROVED preserves source evidence'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'APPROVED', version = version + 1,
        latest_approved_by_actor_id = 'ab000000-0000-0000-0000-000000000002',
        latest_approved_at = timestamptz '2026-07-20 09:00:00+07',
        latest_approval_snapshot_id = 'ab000000-0000-0000-0000-000000000220'
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200'
  $$,
  '23514', null,
  'VALIDATED to APPROVED preserves version'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'APPROVED',
        latest_approved_by_actor_id = 'ab000000-0000-0000-0000-000000000003',
        latest_approved_at = timestamptz '2026-07-20 09:00:00+07',
        latest_approval_snapshot_id = 'ab000000-0000-0000-0000-000000000220'
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200';
    set constraints all immediate
  $$,
  '23514', null,
  'approved root actor must match the exact snapshot actor'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'APPROVED',
        latest_approved_by_actor_id = 'ab000000-0000-0000-0000-000000000002',
        latest_approved_at = timestamptz '2026-07-20 09:01:00+07',
        latest_approval_snapshot_id = 'ab000000-0000-0000-0000-000000000220'
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200';
    set constraints all immediate
  $$,
  '23514', null,
  'approved root timestamp must match the exact snapshot timestamp'
);

select lives_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'APPROVED',
        latest_approved_by_actor_id = 'ab000000-0000-0000-0000-000000000002',
        latest_approved_at = timestamptz '2026-07-20 09:00:00+07',
        latest_approval_snapshot_id = 'ab000000-0000-0000-0000-000000000220'
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200';
    set constraints all immediate;
    set constraints all deferred
  $$,
  'VALIDATED advances to APPROVED with every and only exact ACTIVE line'
);

select is(
  (
    select count(*)::integer
    from atlas_planning.attendance_approval_snapshot_lines
    where attendance_approval_snapshot_id = 'ab000000-0000-0000-0000-000000000220'
  ),
  2,
  'first approval contains every ACTIVE line and excludes the INVALID line'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set source_name = 'frozen-approved.csv'
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200'
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
      'ab000000-0000-0000-0000-000000000200',
      'ab000000-0000-0000-0000-000000000121', date '2026-07-23', 1, 0,
      'ab000000-0000-0000-0000-000000000001',
      'ab000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514', null,
  'APPROVED blocks attendance-line insert'
);

select throws_ok(
  $$
    update atlas_planning.attendance_lines
    set teacher_portions = 6
    where attendance_line_id = 'ab000000-0000-0000-0000-000000000211'
  $$,
  '23514', null,
  'APPROVED blocks attendance-line update'
);

select throws_ok(
  $$
    delete from atlas_planning.attendance_lines
    where attendance_line_id = 'ab000000-0000-0000-0000-000000000212'
  $$,
  '23514', null,
  'APPROVED blocks attendance-line delete'
);

select throws_ok(
  $$
    update atlas_planning.attendance_approval_snapshots
    set approved_at = approved_at + interval '1 second'
    where attendance_approval_snapshot_id = 'ab000000-0000-0000-0000-000000000220'
  $$,
  '23514', null,
  'approval snapshot headers are immutable'
);

select throws_ok(
  $$
    delete from atlas_planning.attendance_approval_snapshots
    where attendance_approval_snapshot_id = 'ab000000-0000-0000-0000-000000000220'
  $$,
  '23514', null,
  'approval snapshot headers cannot be deleted'
);

select throws_ok(
  $$
    update atlas_planning.attendance_approval_snapshot_lines
    set student_portions = 1
    where attendance_approval_snapshot_line_id = 'ab000000-0000-0000-0000-000000000221'
  $$,
  '23514', null,
  'approval snapshot lines are immutable'
);

select throws_ok(
  $$
    delete from atlas_planning.attendance_approval_snapshot_lines
    where attendance_approval_snapshot_line_id = 'ab000000-0000-0000-0000-000000000221'
  $$,
  '23514', null,
  'approval snapshot lines cannot be deleted'
);

-- Used evidence, reopen version semantics, working correction, and later approval.
select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'USED_FOR_NEED_GENERATION', row_count = row_count + 1
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200'
  $$,
  '23514', null,
  'APPROVED to USED_FOR_NEED_GENERATION preserves source evidence'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'USED_FOR_NEED_GENERATION', version = version + 1
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200'
  $$,
  '23514', null,
  'APPROVED to USED_FOR_NEED_GENERATION preserves version'
);

select lives_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'USED_FOR_NEED_GENERATION'
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200';
    set constraints all immediate;
    set constraints all deferred
  $$,
  'APPROVED advances to USED_FOR_NEED_GENERATION with the same approval evidence'
);

select is(
  (
    select row(
      version, latest_approved_by_actor_id, latest_approved_at,
      latest_approval_snapshot_id
    )::text
    from atlas_planning.attendance_batches
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200'
  ),
  '(1,ab000000-0000-0000-0000-000000000002,"2026-07-20 02:00:00+00",ab000000-0000-0000-0000-000000000220)',
  'USED_FOR_NEED_GENERATION preserves exact approval actor/time/snapshot evidence'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set source_signature = 'frozen-used'
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200'
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
      'ab000000-0000-0000-0000-000000000200',
      'ab000000-0000-0000-0000-000000000121', date '2026-07-23', 1, 0,
      'ab000000-0000-0000-0000-000000000001',
      'ab000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514', null,
  'USED_FOR_NEED_GENERATION blocks attendance-line insert'
);

select throws_ok(
  $$
    update atlas_planning.attendance_lines
    set student_portions = 101
    where attendance_line_id = 'ab000000-0000-0000-0000-000000000211'
  $$,
  '23514', null,
  'USED_FOR_NEED_GENERATION blocks attendance-line update'
);

select throws_ok(
  $$
    delete from atlas_planning.attendance_lines
    where attendance_line_id = 'ab000000-0000-0000-0000-000000000212'
  $$,
  '23514', null,
  'USED_FOR_NEED_GENERATION blocks attendance-line delete'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'APPROVED'
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200'
  $$,
  '23514', null,
  'USED_FOR_NEED_GENERATION cannot reverse directly to APPROVED'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'REOPENED'
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200'
  $$,
  '23514', null,
  'reopen cannot reuse the approved version'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'REOPENED', version = version + 2
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200'
  $$,
  '23514', null,
  'reopen cannot skip more than one version'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'REOPENED', version = version + 1,
        source_name = 'smuggled-used-reopen.csv'
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200'
  $$,
  '23514', null,
  'USED_FOR_NEED_GENERATION to REOPENED preserves source evidence'
);

select lives_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'REOPENED', version = version + 1
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200'
  $$,
  'USED_FOR_NEED_GENERATION reopens at exactly version plus one'
);

select is(
  (
    select row(
      attendance_status, version, latest_approved_by_actor_id,
      latest_approved_at, latest_approval_snapshot_id
    )::text
    from atlas_planning.attendance_batches
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200'
  ),
  '(REOPENED,2,ab000000-0000-0000-0000-000000000002,"2026-07-20 02:00:00+00",ab000000-0000-0000-0000-000000000220)',
  'reopen advances exactly one version and preserves complete approval history'
);

select lives_ok(
  $$
    update atlas_planning.attendance_batches
    set source_type = 'MANUAL_CORRECTION',
        source_name = 'attendance-one-reopened.csv',
        source_signature = 'sha256:attendance-one-reopened',
        row_count = 3,
        imported_by_actor_id = 'ab000000-0000-0000-0000-000000000001',
        imported_at = timestamptz '2026-07-20 10:00:00+07',
        updated_at = updated_at + interval '1 second'
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200'
  $$,
  'same-state REOPENED refresh replaces only working source/import evidence'
);

select ok(
  exists (
    select 1
    from atlas_planning.attendance_batches
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200'
      and source_type = 'MANUAL_CORRECTION'
      and source_name = 'attendance-one-reopened.csv'
      and source_signature = 'sha256:attendance-one-reopened'
      and row_count = 3
      and imported_by_actor_id = 'ab000000-0000-0000-0000-000000000001'
      and imported_at = timestamptz '2026-07-20 10:00:00+07'
      and version = 2
      and latest_approval_snapshot_id = 'ab000000-0000-0000-0000-000000000220'
  ),
  'REOPENED refresh preserves root, period, version, and prior approval history'
);

select lives_ok(
  $$
    insert into atlas_planning.attendance_lines (
      attendance_line_id, attendance_batch_id, school_id, service_date,
      student_portions, teacher_portions, source_row_reference,
      created_by_actor_id, updated_by_actor_id
    ) values (
      'ab000000-0000-0000-0000-000000000213',
      'ab000000-0000-0000-0000-000000000200',
      'ab000000-0000-0000-0000-000000000121', date '2026-07-23',
      2, 0, 'Sheet1!D2-reopened',
      'ab000000-0000-0000-0000-000000000001',
      'ab000000-0000-0000-0000-000000000001'
    )
  $$,
  'REOPENED permits attendance-line insert'
);

select lives_ok(
  $$
    update atlas_planning.attendance_lines
    set student_portions = 3,
        teacher_portions = 1,
        updated_by_actor_id = 'ab000000-0000-0000-0000-000000000003',
        updated_at = updated_at + interval '1 second'
    where attendance_line_id = 'ab000000-0000-0000-0000-000000000213'
  $$,
  'REOPENED permits attendance-line update'
);

select lives_ok(
  $$
    delete from atlas_planning.attendance_lines
    where attendance_line_id = 'ab000000-0000-0000-0000-000000000213'
  $$,
  'REOPENED permits attendance-line delete'
);

select lives_ok(
  $$
    update atlas_planning.attendance_lines
    set student_portions = 1,
        source_row_reference = 'Sheet1!A2-corrected',
        updated_by_actor_id = 'ab000000-0000-0000-0000-000000000003',
        updated_at = updated_at + interval '1 second'
    where attendance_line_id = 'ab000000-0000-0000-0000-000000000210'
  $$,
  'REOPENED corrects stable line content without changing stable identity'
);

select is(
  (
    select row(student_portions, source_row_reference)::text
    from atlas_planning.attendance_approval_snapshot_lines
    where attendance_approval_snapshot_line_id = 'ab000000-0000-0000-0000-000000000221'
  ),
  '(0,Sheet1!A2)',
  'reopened correction does not rewrite the prior immutable snapshot line'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'DRAFT', source_type = 'smuggled-reopen-draft'
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200'
  $$,
  '23514', null,
  'REOPENED to DRAFT preserves source evidence'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'DRAFT', version = version + 1
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200'
  $$,
  '23514', null,
  'REOPENED to DRAFT preserves version'
);

select lives_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'DRAFT'
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200'
  $$,
  'REOPENED advances to DRAFT at the same later version'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'VALIDATED', version = version - 1
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200'
  $$,
  '23514', null,
  'Attendance version cannot decrease on later validation'
);

update atlas_planning.attendance_batches
set attendance_status = 'VALIDATED'
where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200';

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'APPROVED',
        latest_approved_by_actor_id = 'ab000000-0000-0000-0000-000000000002',
        latest_approved_at = timestamptz '2026-07-20 09:00:00+07',
        latest_approval_snapshot_id = 'ab000000-0000-0000-0000-000000000220'
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200'
  $$,
  '23514',
  'later attendance approval requires a new snapshot for a later version',
  'later approval cannot reuse the prior-version snapshot'
);

select lives_ok(
  $test$
    do $body$
    begin
      insert into atlas_planning.attendance_approval_snapshots (
        attendance_approval_snapshot_id, attendance_batch_id, attendance_version,
        approved_by_actor_id, approved_at
      ) values (
        'ab000000-0000-0000-0000-000000000230',
        'ab000000-0000-0000-0000-000000000200', 2,
        'ab000000-0000-0000-0000-000000000003',
        timestamptz '2026-07-20 11:00:00+07'
      );

      insert into atlas_planning.attendance_approval_snapshot_lines (
        attendance_approval_snapshot_line_id, attendance_approval_snapshot_id,
        attendance_batch_id, attendance_version, attendance_line_id, school_id,
        service_date, student_portions, teacher_portions, source_row_reference
      ) values
        (
          'ab000000-0000-0000-0000-000000000231',
          'ab000000-0000-0000-0000-000000000230',
          'ab000000-0000-0000-0000-000000000200', 2,
          'ab000000-0000-0000-0000-000000000210',
          'ab000000-0000-0000-0000-000000000120', date '2026-07-20',
          1, 0, 'Sheet1!A2-corrected'
        ),
        (
          'ab000000-0000-0000-0000-000000000232',
          'ab000000-0000-0000-0000-000000000230',
          'ab000000-0000-0000-0000-000000000200', 2,
          'ab000000-0000-0000-0000-000000000211',
          'ab000000-0000-0000-0000-000000000121', date '2026-07-21',
          100, 5, 'Sheet1!B2'
        );

      update atlas_planning.attendance_batches
      set attendance_status = 'APPROVED',
          latest_approved_by_actor_id = 'ab000000-0000-0000-0000-000000000003',
          latest_approved_at = timestamptz '2026-07-20 11:00:00+07',
          latest_approval_snapshot_id = 'ab000000-0000-0000-0000-000000000230'
      where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200';

      set constraints all immediate;
      set constraints all deferred;
    end
    $body$
  $test$,
  'later Attendance version receives a new complete exact approval snapshot'
);

select is(
  (
    select count(*)::integer
    from atlas_planning.attendance_approval_snapshots
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200'
  ),
  2,
  'reopen/later approval preserves both immutable historical snapshots'
);

select is(
  (
    select row(
      attendance_status, version, latest_approved_by_actor_id,
      latest_approval_snapshot_id
    )::text
    from atlas_planning.attendance_batches
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200'
  ),
  '(APPROVED,2,ab000000-0000-0000-0000-000000000003,ab000000-0000-0000-0000-000000000230)',
  'stable Attendance root points to the exact latest approval without deleting history'
);

-- Direct APPROVED to REOPENED branch and its source-preservation rule.
update atlas_planning.attendance_batches
set attendance_status = 'VALIDATED'
where attendance_batch_id = 'ab000000-0000-0000-0000-000000000300';

insert into atlas_planning.attendance_approval_snapshots (
  attendance_approval_snapshot_id, attendance_batch_id, attendance_version,
  approved_by_actor_id, approved_at
) values (
  'ab000000-0000-0000-0000-000000000320',
  'ab000000-0000-0000-0000-000000000300', 1,
  'ab000000-0000-0000-0000-000000000002',
  timestamptz '2026-07-20 12:00:00+07'
);

insert into atlas_planning.attendance_approval_snapshot_lines (
  attendance_approval_snapshot_line_id, attendance_approval_snapshot_id,
  attendance_batch_id, attendance_version, attendance_line_id, school_id,
  service_date, student_portions, teacher_portions, source_row_reference
) values (
  'ab000000-0000-0000-0000-000000000321',
  'ab000000-0000-0000-0000-000000000320',
  'ab000000-0000-0000-0000-000000000300', 1,
  'ab000000-0000-0000-0000-000000000310',
  'ab000000-0000-0000-0000-000000000120', date '2026-07-27',
  80, 4, 'Sheet2!A2'
);

update atlas_planning.attendance_batches
set attendance_status = 'APPROVED',
    latest_approved_by_actor_id = 'ab000000-0000-0000-0000-000000000002',
    latest_approved_at = timestamptz '2026-07-20 12:00:00+07',
    latest_approval_snapshot_id = 'ab000000-0000-0000-0000-000000000320'
where attendance_batch_id = 'ab000000-0000-0000-0000-000000000300';
set constraints all immediate;
set constraints all deferred;

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'REOPENED', version = version + 1,
        source_signature = 'smuggled-approved-reopen'
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000300'
  $$,
  '23514', null,
  'APPROVED to REOPENED preserves source evidence'
);

select lives_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'REOPENED', version = version + 1
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000300'
  $$,
  'APPROVED may reopen directly at exactly version plus one'
);

-- Stable root deletion and exact declarative ownership constraints.
select throws_ok(
  $$
    delete from atlas_planning.attendance_batches
    where attendance_batch_id = 'ab000000-0000-0000-0000-000000000200'
  $$,
  '23514', null,
  'historically approved Attendance roots cannot be deleted'
);

select ok(
  exists (
    select 1 from pg_constraint
    where conrelid = 'atlas_planning.attendance_approval_snapshots'::regclass
      and conname = 'attendance_approval_snapshots_batch_version_key'
      and contype = 'u'
  ),
  'one immutable approval snapshot is allowed per Attendance version'
);

select ok(
  exists (
    select 1 from pg_constraint
    where conrelid = 'atlas_planning.attendance_approval_snapshot_lines'::regclass
      and conname = 'attendance_approval_snapshot_lines_line_key'
      and contype = 'u'
  ),
  'one snapshot line is allowed per stable Attendance line'
);

select ok(
  exists (
    select 1 from pg_constraint
    where conrelid = 'atlas_planning.attendance_approval_snapshot_lines'::regclass
      and conname = 'attendance_approval_snapshot_lines_assignment_key'
      and contype = 'u'
  ),
  'approval snapshots prohibit duplicate school/date assignments'
);

select ok(
  (
    select count(*) = 12 and bool_and(con.confdeltype = 'r')
    from pg_constraint con
    where con.conname in (
      'attendance_batches_imported_by_actor_fkey',
      'attendance_batches_latest_approved_by_actor_fkey',
      'attendance_batches_latest_approval_snapshot_fkey',
      'attendance_lines_batch_fkey',
      'attendance_lines_school_fkey',
      'attendance_lines_created_by_actor_fkey',
      'attendance_lines_updated_by_actor_fkey',
      'attendance_approval_snapshots_batch_fkey',
      'attendance_approval_snapshots_approved_by_actor_fkey',
      'attendance_approval_snapshot_lines_snapshot_fkey',
      'attendance_approval_snapshot_lines_attendance_line_fkey',
      'attendance_approval_snapshot_lines_school_fkey'
    )
  ),
  'every H0A3b operational foreign key uses ON DELETE RESTRICT'
);

select ok(
  not exists (
    select 1
    from pg_constraint con
    where con.conrelid in (
      'atlas_planning.attendance_batches'::regclass,
      'atlas_planning.attendance_lines'::regclass,
      'atlas_planning.attendance_approval_snapshots'::regclass,
      'atlas_planning.attendance_approval_snapshot_lines'::regclass
    )
      and con.contype = 'f'
      and not exists (
        select 1
        from pg_index idx
        where idx.indrelid = con.conrelid
          and idx.indisvalid
          and (
            select array_agg(key_column.attnum::smallint order by key_column.ordinality)
            from unnest(idx.indkey::smallint[]) with ordinality
              as key_column(attnum, ordinality)
            where key_column.ordinality <= cardinality(con.conkey)
          ) = con.conkey
      )
  ),
  'every H0A3b foreign key has a matching leading-column index'
);

-- Private ownership, RLS, ACL, and unchanged API/authorization surfaces.
select ok(
  not exists (
    select 1
    from pg_class c
    where c.oid in (
      'atlas_planning.attendance_batches'::regclass,
      'atlas_planning.attendance_lines'::regclass,
      'atlas_planning.attendance_approval_snapshots'::regclass,
      'atlas_planning.attendance_approval_snapshot_lines'::regclass
    )
      and (not c.relrowsecurity or not c.relforcerowsecurity)
  ),
  'all four H0A3b relations have RLS enabled and forced'
);

select is(
  (
    select count(*)::integer
    from pg_policy policy
    where policy.polrelid in (
      'atlas_planning.attendance_batches'::regclass,
      'atlas_planning.attendance_lines'::regclass,
      'atlas_planning.attendance_approval_snapshots'::regclass,
      'atlas_planning.attendance_approval_snapshot_lines'::regclass
    )
  ),
  0,
  'H0A3b adds zero RLS policies'
);

select is(
  (
    select count(*)::integer
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'atlas_planning'
      and c.relkind = 'S'
      and c.relname like 'attendance%'
  ),
  0,
  'database-generated UUID identities add no H0A3b sequences or sequence grants'
);

select is(
  (
    select array_agg(owner.rolname order by c.relname)::text[]
    from pg_class c
    join pg_roles owner on owner.oid = c.relowner
    where c.oid in (
      'atlas_planning.attendance_batches'::regclass,
      'atlas_planning.attendance_lines'::regclass,
      'atlas_planning.attendance_approval_snapshots'::regclass,
      'atlas_planning.attendance_approval_snapshot_lines'::regclass
    )
  ),
  array['atlas_owner', 'atlas_owner', 'atlas_owner', 'atlas_owner']::text[],
  'all four H0A3b relations are owned by atlas_owner'
);

select is(
  (
    select count(*)::integer
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    join pg_roles owner on owner.oid = p.proowner
    where n.nspname = 'atlas_planning'
      and p.proname like 'pa_06e_h0a3b_%'
      and owner.rolname = 'atlas_owner'
  ),
  4,
  'the four minimum private H0A3b guard functions are owned by atlas_owner'
);

select ok(
  not exists (
    select 1
    from pg_class c
    cross join lateral aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) acl
    left join pg_roles grantee on grantee.oid = acl.grantee
    where c.oid in (
      'atlas_planning.attendance_batches'::regclass,
      'atlas_planning.attendance_lines'::regclass,
      'atlas_planning.attendance_approval_snapshots'::regclass,
      'atlas_planning.attendance_approval_snapshot_lines'::regclass
    )
      and (acl.grantee = 0 or grantee.rolname in ('anon', 'authenticated', 'service_role'))
  ),
  'PUBLIC and API roles have no H0A3b table privileges of any kind'
);

select ok(
  not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
    left join pg_roles grantee on grantee.oid = acl.grantee
    where n.nspname = 'atlas_planning'
      and p.proname like 'pa_06e_h0a3b_%'
      and (acl.grantee = 0 or grantee.rolname in ('anon', 'authenticated', 'service_role'))
      and acl.privilege_type = 'EXECUTE'
  ),
  'PUBLIC and API roles cannot execute private H0A3b guard functions'
);

select ok(
  not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_planning'
      and p.proname like 'pa_06e_h0a3b_%'
      and not coalesce(p.proconfig, array[]::text[]) @> array['search_path=""']
  ),
  'every private H0A3b guard function has a hardened empty search path'
);

select is(
  (
    select array_agg(
      format('%s(%s)', p.proname, pg_get_function_identity_arguments(p.oid))
      order by p.proname
    )::text[]
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
  ),
  array[
    'allocate_supplier_direct_fulfilment(request jsonb)',
    'apply_supplier_evidence_to_allocation(request jsonb)',
    'close_successful_trip(request jsonb)',
    'confirm_dispatch_load(request jsonb)',
    'confirm_successful_delivery(request jsonb)',
    'create_dispatch_plan(request jsonb)',
    'create_or_assign_dispatch_trip(request jsonb)',
    'get_command_audit_timeline(request jsonb)',
    'get_dispatch_evidence_readiness(request jsonb)',
    'get_operator_blockers(request jsonb)',
    'get_supplier_direct_trace(request jsonb)',
    'record_dispatch_departure(request jsonb)',
    'record_supplier_receiving_evidence(request jsonb)',
    'record_wholesale_source(request jsonb)',
    'release_dispatch_requirement(request jsonb)',
    'release_purchase_handoff(request jsonb)',
    'release_supplier_purchase_order(request jsonb)',
    'release_wholesale_order(request jsonb)'
  ]::text[],
  'the exact 18-function atlas_api registry remains unchanged'
);

select is((select count(*)::integer from atlas_core.roles), 0, 'H0A3b seeds no roles');
select is((select count(*)::integer from atlas_core.capabilities), 0, 'H0A3b seeds no capabilities');

select * from finish();

rollback;
