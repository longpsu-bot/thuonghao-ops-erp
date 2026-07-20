begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;

select plan(40);

-- This suite owns only exact approval snapshots, immutable history, and later-version preservation.
insert into atlas_core.actors (actor_id, actor_type, display_name) values
  ('ad000000-0000-0000-0000-000000000001', 'HUMAN', 'H0A3b snapshot importer'),
  ('ad000000-0000-0000-0000-000000000002', 'HUMAN', 'H0A3b snapshot approver'),
  ('ad000000-0000-0000-0000-000000000003', 'HUMAN', 'H0A3b snapshot alternate');

insert into atlas_admin.customers (
  customer_id, customer_code, customer_name, customer_type
) values (
  'ad000000-0000-0000-0000-000000000100',
  'pa06e-h0a3b-snapshot-customer',
  'PA-06E-H0A3b snapshot customer',
  'SCHOOL_CATERING'
);

insert into atlas_admin.delivery_locations (
  delivery_location_id, customer_id, location_code, location_name,
  address_text, timezone_name
) values (
  'ad000000-0000-0000-0000-000000000101',
  'ad000000-0000-0000-0000-000000000100',
  'pa06e-h0a3b-snapshot-location',
  'PA-06E-H0A3b snapshot location',
  'Synthetic snapshot address',
  'Asia/Ho_Chi_Minh'
);

insert into atlas_admin.school_types (
  school_type_id, school_type_code, school_type_name
) values (
  'ad000000-0000-0000-0000-000000000110',
  'pa06e-h0a3b-snapshot-primary',
  'PA-06E-H0A3b snapshot Primary'
);

insert into atlas_admin.schools (
  school_id, customer_id, school_code, school_name, school_type_id,
  default_delivery_location_id, display_order
) values
  (
    'ad000000-0000-0000-0000-000000000120',
    'ad000000-0000-0000-0000-000000000100',
    'pa06e-h0a3b-snapshot-school-a',
    'PA-06E-H0A3b snapshot School A',
    'ad000000-0000-0000-0000-000000000110',
    'ad000000-0000-0000-0000-000000000101',
    10
  ),
  (
    'ad000000-0000-0000-0000-000000000121',
    'ad000000-0000-0000-0000-000000000100',
    'pa06e-h0a3b-snapshot-school-b',
    'PA-06E-H0A3b snapshot School B',
    'ad000000-0000-0000-0000-000000000110',
    'ad000000-0000-0000-0000-000000000101',
    20
  );

insert into atlas_planning.attendance_batches (
  attendance_batch_id, period_start, period_end, source_type, source_name,
  source_signature, imported_by_actor_id
) values
  (
    'ad000000-0000-0000-0000-000000000200',
    date '2026-07-20', date '2026-07-24', 'CSV', 'snapshot-one.csv',
    'sha256:snapshot-one', 'ad000000-0000-0000-0000-000000000001'
  ),
  (
    'ad000000-0000-0000-0000-000000000300',
    date '2026-07-27', date '2026-07-29', 'CSV', 'snapshot-two.csv',
    'sha256:snapshot-two', 'ad000000-0000-0000-0000-000000000001'
  ),
  (
    'ad000000-0000-0000-0000-000000000400',
    date '2026-08-03', date '2026-08-03', 'CSV', 'snapshot-draft.csv',
    'sha256:snapshot-draft', 'ad000000-0000-0000-0000-000000000001'
  );

insert into atlas_planning.attendance_lines (
  attendance_line_id, attendance_batch_id, school_id, service_date,
  student_portions, teacher_portions, line_status, source_row_reference,
  created_by_actor_id, updated_by_actor_id
) values
  (
    'ad000000-0000-0000-0000-000000000210',
    'ad000000-0000-0000-0000-000000000200',
    'ad000000-0000-0000-0000-000000000120', date '2026-07-20',
    0, 0, 'ACTIVE', 'Sheet1!A2',
    'ad000000-0000-0000-0000-000000000001',
    'ad000000-0000-0000-0000-000000000001'
  ),
  (
    'ad000000-0000-0000-0000-000000000211',
    'ad000000-0000-0000-0000-000000000200',
    'ad000000-0000-0000-0000-000000000121', date '2026-07-21',
    100, 5, 'ACTIVE', 'Sheet1!B2',
    'ad000000-0000-0000-0000-000000000001',
    'ad000000-0000-0000-0000-000000000001'
  ),
  (
    'ad000000-0000-0000-0000-000000000212',
    'ad000000-0000-0000-0000-000000000200',
    'ad000000-0000-0000-0000-000000000120', date '2026-07-22',
    50, 2, 'INVALID', 'Sheet1!C2',
    'ad000000-0000-0000-0000-000000000001',
    'ad000000-0000-0000-0000-000000000001'
  ),
  (
    'ad000000-0000-0000-0000-000000000310',
    'ad000000-0000-0000-0000-000000000300',
    'ad000000-0000-0000-0000-000000000120', date '2026-07-27',
    80, 4, 'ACTIVE', 'Sheet2!A2',
    'ad000000-0000-0000-0000-000000000001',
    'ad000000-0000-0000-0000-000000000001'
  );

update atlas_planning.attendance_batches
set attendance_status = 'VALIDATED'
where attendance_batch_id in (
  'ad000000-0000-0000-0000-000000000200',
  'ad000000-0000-0000-0000-000000000300'
);

select throws_ok(
  $$
    insert into atlas_planning.attendance_approval_snapshots (
      attendance_approval_snapshot_id, attendance_batch_id, attendance_version,
      approved_by_actor_id, approved_at
    ) values (
      'ad000000-0000-0000-0000-000000000420',
      'ad000000-0000-0000-0000-000000000400', 1,
      'ad000000-0000-0000-0000-000000000002', transaction_timestamp()
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
      'ad000000-0000-0000-0000-000000000219',
      'ad000000-0000-0000-0000-000000000200', 2,
      'ad000000-0000-0000-0000-000000000002', transaction_timestamp()
    )
  $$,
  '23514', null,
  'approval snapshot header rejects a noncurrent Attendance version'
);

insert into atlas_planning.attendance_approval_snapshots (
  attendance_approval_snapshot_id, attendance_batch_id, attendance_version,
  approved_by_actor_id, approved_at
) values (
  'ad000000-0000-0000-0000-000000000220',
  'ad000000-0000-0000-0000-000000000200', 1,
  'ad000000-0000-0000-0000-000000000002',
  timestamptz '2026-07-20 09:00:00+07'
);

select throws_ok(
  $$
    insert into atlas_planning.attendance_approval_snapshots (
      attendance_batch_id, attendance_version, approved_by_actor_id, approved_at
    ) values (
      'ad000000-0000-0000-0000-000000000200', 1,
      'ad000000-0000-0000-0000-000000000002', transaction_timestamp()
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
      'ad000000-0000-0000-0000-000000000220',
      'ad000000-0000-0000-0000-000000000200', 2,
      'ad000000-0000-0000-0000-000000000210',
      'ad000000-0000-0000-0000-000000000120', date '2026-07-20',
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
      'ad000000-0000-0000-0000-000000000220',
      'ad000000-0000-0000-0000-000000000200', 1,
      'ad000000-0000-0000-0000-000000000310',
      'ad000000-0000-0000-0000-000000000120', date '2026-07-27',
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
      'ad000000-0000-0000-0000-000000000220',
      'ad000000-0000-0000-0000-000000000200', 1,
      'ad000000-0000-0000-0000-000000000212',
      'ad000000-0000-0000-0000-000000000120', date '2026-07-22',
      50, 2, 'Sheet1!C2'
    )
  $$,
  '23514', null,
  'snapshot rejects an INVALID Attendance line'
);

select throws_ok(
  $$
    insert into atlas_planning.attendance_approval_snapshot_lines (
      attendance_approval_snapshot_id, attendance_batch_id, attendance_version,
      attendance_line_id, school_id, service_date, student_portions,
      teacher_portions, source_row_reference
    ) values (
      'ad000000-0000-0000-0000-000000000220',
      'ad000000-0000-0000-0000-000000000200', 1,
      'ad000000-0000-0000-0000-000000009999',
      'ad000000-0000-0000-0000-000000000121', date '2026-07-24',
      1, 0, 'extra'
    )
  $$,
  '23503', null,
  'snapshot rejects an extra nonexistent stable Attendance line'
);

select throws_ok(
  $$
    insert into atlas_planning.attendance_approval_snapshot_lines (
      attendance_approval_snapshot_id, attendance_batch_id, attendance_version,
      attendance_line_id, school_id, service_date, student_portions,
      teacher_portions, source_row_reference
    ) values (
      'ad000000-0000-0000-0000-000000000220',
      'ad000000-0000-0000-0000-000000000200', 1,
      'ad000000-0000-0000-0000-000000000210',
      'ad000000-0000-0000-0000-000000000121', date '2026-07-20',
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
      'ad000000-0000-0000-0000-000000000220',
      'ad000000-0000-0000-0000-000000000200', 1,
      'ad000000-0000-0000-0000-000000000210',
      'ad000000-0000-0000-0000-000000000120', date '2026-07-21',
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
      'ad000000-0000-0000-0000-000000000220',
      'ad000000-0000-0000-0000-000000000200', 1,
      'ad000000-0000-0000-0000-000000000210',
      'ad000000-0000-0000-0000-000000000120', date '2026-07-20',
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
      'ad000000-0000-0000-0000-000000000220',
      'ad000000-0000-0000-0000-000000000200', 1,
      'ad000000-0000-0000-0000-000000000210',
      'ad000000-0000-0000-0000-000000000120', date '2026-07-20',
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
      'ad000000-0000-0000-0000-000000000220',
      'ad000000-0000-0000-0000-000000000200', 1,
      'ad000000-0000-0000-0000-000000000210',
      'ad000000-0000-0000-0000-000000000120', date '2026-07-20',
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
  'ad000000-0000-0000-0000-000000000221',
  'ad000000-0000-0000-0000-000000000220',
  'ad000000-0000-0000-0000-000000000200', 1,
  'ad000000-0000-0000-0000-000000000210',
  'ad000000-0000-0000-0000-000000000120', date '2026-07-20',
  0, 0, 'Sheet1!A2'
);

select throws_ok(
  $$
    insert into atlas_planning.attendance_approval_snapshot_lines (
      attendance_approval_snapshot_id, attendance_batch_id, attendance_version,
      attendance_line_id, school_id, service_date, student_portions,
      teacher_portions, source_row_reference
    ) values (
      'ad000000-0000-0000-0000-000000000220',
      'ad000000-0000-0000-0000-000000000200', 1,
      'ad000000-0000-0000-0000-000000000210',
      'ad000000-0000-0000-0000-000000000120', date '2026-07-20',
      0, 0, 'Sheet1!A2'
    )
  $$,
  '23505', null,
  'snapshot rejects a duplicate stable Attendance line'
);

select throws_ok(
  $$
    insert into atlas_planning.attendance_approval_snapshot_lines (
      attendance_approval_snapshot_id, attendance_batch_id, attendance_version,
      attendance_line_id, school_id, service_date, student_portions,
      teacher_portions, source_row_reference
    ) values (
      'ad000000-0000-0000-0000-000000000220',
      'ad000000-0000-0000-0000-000000000200', 1,
      'ad000000-0000-0000-0000-000000009998',
      'ad000000-0000-0000-0000-000000000120', date '2026-07-20',
      0, 0, 'duplicate-assignment'
    )
  $$,
  '23505', null,
  'snapshot rejects a duplicate School/date assignment independently of stable-line identity'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'APPROVED',
        latest_approved_by_actor_id = 'ad000000-0000-0000-0000-000000000002',
        latest_approved_at = timestamptz '2026-07-20 09:00:00+07',
        latest_approval_snapshot_id = 'ad000000-0000-0000-0000-000000000220'
    where attendance_batch_id = 'ad000000-0000-0000-0000-000000000200';
    set constraints all immediate
  $$,
  '23514', null,
  'approval fails when any ACTIVE Attendance line is missing from the snapshot'
);

insert into atlas_planning.attendance_approval_snapshot_lines (
  attendance_approval_snapshot_line_id, attendance_approval_snapshot_id,
  attendance_batch_id, attendance_version, attendance_line_id, school_id,
  service_date, student_portions, teacher_portions, source_row_reference
) values (
  'ad000000-0000-0000-0000-000000000222',
  'ad000000-0000-0000-0000-000000000220',
  'ad000000-0000-0000-0000-000000000200', 1,
  'ad000000-0000-0000-0000-000000000211',
  'ad000000-0000-0000-0000-000000000121', date '2026-07-21',
  100, 5, 'Sheet1!B2'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'APPROVED',
        latest_approved_by_actor_id = 'ad000000-0000-0000-0000-000000000002',
        latest_approved_at = timestamptz '2026-07-20 09:00:00+07'
    where attendance_batch_id = 'ad000000-0000-0000-0000-000000000200'
  $$,
  '23514', null,
  'an approved root cannot omit its exact snapshot reference'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'APPROVED',
        latest_approved_by_actor_id = 'ad000000-0000-0000-0000-000000000003',
        latest_approved_at = timestamptz '2026-07-20 09:00:00+07',
        latest_approval_snapshot_id = 'ad000000-0000-0000-0000-000000000220'
    where attendance_batch_id = 'ad000000-0000-0000-0000-000000000200';
    set constraints all immediate
  $$,
  '23514', null,
  'approved root actor must match the exact snapshot actor'
);

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'APPROVED',
        latest_approved_by_actor_id = 'ad000000-0000-0000-0000-000000000002',
        latest_approved_at = timestamptz '2026-07-20 09:01:00+07',
        latest_approval_snapshot_id = 'ad000000-0000-0000-0000-000000000220'
    where attendance_batch_id = 'ad000000-0000-0000-0000-000000000200';
    set constraints all immediate
  $$,
  '23514', null,
  'approved root timestamp must match the exact snapshot timestamp'
);

select lives_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'APPROVED',
        latest_approved_by_actor_id = 'ad000000-0000-0000-0000-000000000002',
        latest_approved_at = timestamptz '2026-07-20 09:00:00+07',
        latest_approval_snapshot_id = 'ad000000-0000-0000-0000-000000000220'
    where attendance_batch_id = 'ad000000-0000-0000-0000-000000000200';
    set constraints all immediate;
    set constraints all deferred
  $$,
  'VALIDATED advances to APPROVED with every and only exact ACTIVE line'
);

select is(
  (
    select count(*)::integer
    from atlas_planning.attendance_approval_snapshot_lines
    where attendance_approval_snapshot_id = 'ad000000-0000-0000-0000-000000000220'
  ),
  2,
  'first approval contains every ACTIVE line and excludes the INVALID line'
);

select throws_ok(
  $$
    update atlas_planning.attendance_approval_snapshots
    set approved_at = approved_at + interval '1 second'
    where attendance_approval_snapshot_id = 'ad000000-0000-0000-0000-000000000220'
  $$,
  '23514', null,
  'approval snapshot headers are immutable'
);

select throws_ok(
  $$
    delete from atlas_planning.attendance_approval_snapshots
    where attendance_approval_snapshot_id = 'ad000000-0000-0000-0000-000000000220'
  $$,
  '23514', null,
  'approval snapshot headers cannot be deleted'
);

select throws_ok(
  $$
    update atlas_planning.attendance_approval_snapshot_lines
    set student_portions = 1
    where attendance_approval_snapshot_line_id = 'ad000000-0000-0000-0000-000000000221'
  $$,
  '23514', null,
  'approval snapshot lines are immutable'
);

select throws_ok(
  $$
    delete from atlas_planning.attendance_approval_snapshot_lines
    where attendance_approval_snapshot_line_id = 'ad000000-0000-0000-0000-000000000221'
  $$,
  '23514', null,
  'approval snapshot lines cannot be deleted'
);

select lives_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'USED_FOR_NEED_GENERATION'
    where attendance_batch_id = 'ad000000-0000-0000-0000-000000000200';
    set constraints all immediate;
    set constraints all deferred
  $$,
  'used handoff retains the exact approved snapshot binding'
);

select is(
  (
    select row(
      version, latest_approved_by_actor_id, latest_approved_at,
      latest_approval_snapshot_id
    )::text
    from atlas_planning.attendance_batches
    where attendance_batch_id = 'ad000000-0000-0000-0000-000000000200'
  ),
  '(1,ad000000-0000-0000-0000-000000000002,"2026-07-20 02:00:00+00",ad000000-0000-0000-0000-000000000220)',
  'USED_FOR_NEED_GENERATION preserves exact approval actor/time/snapshot evidence'
);

select lives_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'REOPENED', version = version + 1
    where attendance_batch_id = 'ad000000-0000-0000-0000-000000000200';
    update atlas_planning.attendance_lines
    set student_portions = 1,
        source_row_reference = 'Sheet1!A2-corrected',
        updated_by_actor_id = 'ad000000-0000-0000-0000-000000000003',
        updated_at = updated_at + interval '1 second'
    where attendance_line_id = 'ad000000-0000-0000-0000-000000000210'
  $$,
  'reopen permits a later working correction while retaining approval history'
);

select is(
  (
    select row(student_portions, source_row_reference)::text
    from atlas_planning.attendance_approval_snapshot_lines
    where attendance_approval_snapshot_line_id = 'ad000000-0000-0000-0000-000000000221'
  ),
  '(0,Sheet1!A2)',
  'reopened correction does not rewrite the prior immutable snapshot line'
);

select is(
  (
    select row(
      latest_approved_by_actor_id, latest_approved_at, latest_approval_snapshot_id
    )::text
    from atlas_planning.attendance_batches
    where attendance_batch_id = 'ad000000-0000-0000-0000-000000000200'
  ),
  '(ad000000-0000-0000-0000-000000000002,"2026-07-20 02:00:00+00",ad000000-0000-0000-0000-000000000220)',
  'reopen preserves the prior approval actor, time, and snapshot reference'
);

update atlas_planning.attendance_batches
set attendance_status = 'DRAFT'
where attendance_batch_id = 'ad000000-0000-0000-0000-000000000200';

update atlas_planning.attendance_batches
set attendance_status = 'VALIDATED'
where attendance_batch_id = 'ad000000-0000-0000-0000-000000000200';

select throws_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'APPROVED',
        latest_approved_by_actor_id = 'ad000000-0000-0000-0000-000000000002',
        latest_approved_at = timestamptz '2026-07-20 09:00:00+07',
        latest_approval_snapshot_id = 'ad000000-0000-0000-0000-000000000220'
    where attendance_batch_id = 'ad000000-0000-0000-0000-000000000200'
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
        'ad000000-0000-0000-0000-000000000230',
        'ad000000-0000-0000-0000-000000000200', 2,
        'ad000000-0000-0000-0000-000000000003',
        timestamptz '2026-07-20 11:00:00+07'
      );

      insert into atlas_planning.attendance_approval_snapshot_lines (
        attendance_approval_snapshot_line_id, attendance_approval_snapshot_id,
        attendance_batch_id, attendance_version, attendance_line_id, school_id,
        service_date, student_portions, teacher_portions, source_row_reference
      ) values
        (
          'ad000000-0000-0000-0000-000000000231',
          'ad000000-0000-0000-0000-000000000230',
          'ad000000-0000-0000-0000-000000000200', 2,
          'ad000000-0000-0000-0000-000000000210',
          'ad000000-0000-0000-0000-000000000120', date '2026-07-20',
          1, 0, 'Sheet1!A2-corrected'
        ),
        (
          'ad000000-0000-0000-0000-000000000232',
          'ad000000-0000-0000-0000-000000000230',
          'ad000000-0000-0000-0000-000000000200', 2,
          'ad000000-0000-0000-0000-000000000211',
          'ad000000-0000-0000-0000-000000000121', date '2026-07-21',
          100, 5, 'Sheet1!B2'
        );

      update atlas_planning.attendance_batches
      set attendance_status = 'APPROVED',
          latest_approved_by_actor_id = 'ad000000-0000-0000-0000-000000000003',
          latest_approved_at = timestamptz '2026-07-20 11:00:00+07',
          latest_approval_snapshot_id = 'ad000000-0000-0000-0000-000000000230'
      where attendance_batch_id = 'ad000000-0000-0000-0000-000000000200';

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
    where attendance_batch_id = 'ad000000-0000-0000-0000-000000000200'
  ),
  2,
  'reopen and later approval preserve both immutable historical snapshots'
);

select is(
  (
    select row(
      attendance_status, version, latest_approved_by_actor_id,
      latest_approval_snapshot_id
    )::text
    from atlas_planning.attendance_batches
    where attendance_batch_id = 'ad000000-0000-0000-0000-000000000200'
  ),
  '(APPROVED,2,ad000000-0000-0000-0000-000000000003,ad000000-0000-0000-0000-000000000230)',
  'stable Attendance root points to the exact latest approval without deleting history'
);

select is(
  (
    select array_agg(
      row(attendance_version, approved_by_actor_id, approved_at)::text
      order by attendance_version
    )::text[]
    from atlas_planning.attendance_approval_snapshots
    where attendance_batch_id = 'ad000000-0000-0000-0000-000000000200'
  ),
  array[
    '(1,ad000000-0000-0000-0000-000000000002,"2026-07-20 02:00:00+00")',
    '(2,ad000000-0000-0000-0000-000000000003,"2026-07-20 04:00:00+00")'
  ]::text[],
  'both approval headers retain their exact version, actor, and time history'
);

select is(
  (
    select row(student_portions, teacher_portions, source_row_reference)::text
    from atlas_planning.attendance_approval_snapshot_lines
    where attendance_approval_snapshot_line_id = 'ad000000-0000-0000-0000-000000000221'
  ),
  '(0,0,Sheet1!A2)',
  'later approval leaves the first-version snapshot content unchanged'
);

select is(
  (
    select row(student_portions, teacher_portions, source_row_reference)::text
    from atlas_planning.attendance_approval_snapshot_lines
    where attendance_approval_snapshot_line_id = 'ad000000-0000-0000-0000-000000000231'
  ),
  '(1,0,Sheet1!A2-corrected)',
  'later approval copies the corrected working content exactly'
);

select throws_ok(
  $$
    update atlas_planning.attendance_approval_snapshots
    set approved_by_actor_id = 'ad000000-0000-0000-0000-000000000003'
    where attendance_approval_snapshot_id = 'ad000000-0000-0000-0000-000000000220'
  $$,
  '23514', null,
  'prior approval headers remain immutable after later approval'
);

select throws_ok(
  $$
    delete from atlas_planning.attendance_approval_snapshot_lines
    where attendance_approval_snapshot_line_id = 'ad000000-0000-0000-0000-000000000221'
  $$,
  '23514', null,
  'prior approval lines remain immutable after later approval'
);

select lives_ok(
  $$
    update atlas_planning.attendance_batches
    set attendance_status = 'USED_FOR_NEED_GENERATION'
    where attendance_batch_id = 'ad000000-0000-0000-0000-000000000200';
    set constraints all immediate;
    set constraints all deferred
  $$,
  'later approved version can be used without rewriting either snapshot'
);

select is(
  (
    select count(*)::integer
    from atlas_planning.attendance_approval_snapshot_lines line
    join atlas_planning.attendance_approval_snapshots snapshot
      on snapshot.attendance_approval_snapshot_id = line.attendance_approval_snapshot_id
    where snapshot.attendance_batch_id = 'ad000000-0000-0000-0000-000000000200'
  ),
  4,
  'both approval versions retain their complete two-line history after handoff'
);

select * from finish();

rollback;
