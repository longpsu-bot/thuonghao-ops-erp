begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;

select plan(100);

select is(
  (
    select array_agg(c.relname order by c.relname)::text[]
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'atlas_planning'
      and c.relkind = 'r'
      and c.relname like 'weekly_menu%'
  ),
  array[
    'weekly_menu_approval_snapshot_lines',
    'weekly_menu_approval_snapshots',
    'weekly_menu_google_sources',
    'weekly_menu_lines',
    'weekly_menus'
  ]::text[],
  'the current Weekly Menu boundary includes the four persistence relations and one RMVP-03A source configuration'
);

select is(
  (
    select array_agg(a.attname order by a.attnum)::text[]
    from pg_attribute a
    where a.attrelid = 'atlas_planning.weekly_menus'::regclass
      and a.attnum > 0
      and not a.attisdropped
  ),
  array[
    'weekly_menu_id',
    'week_start',
    'week_end',
    'source_type',
    'source_name',
    'source_signature',
    'weekly_menu_status',
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
  'weekly_menus has only the bounded source, lifecycle, approval, and version fields'
);

select is(
  (
    select array_agg(a.attname order by a.attnum)::text[]
    from pg_attribute a
    where a.attrelid = 'atlas_planning.weekly_menu_lines'::regclass
      and a.attnum > 0
      and not a.attisdropped
  ),
  array[
    'weekly_menu_line_id',
    'weekly_menu_id',
    'school_id',
    'service_date',
    'menu_slot_code',
    'dish_id',
    'line_status',
    'source_row_reference',
    'created_by_actor_id',
    'created_at',
    'updated_by_actor_id',
    'updated_at'
  ]::text[],
  'weekly_menu_lines has only the stable typed assignment and actor/time fields'
);

select is(
  (
    select array_agg(a.attname order by a.attnum)::text[]
    from pg_attribute a
    where a.attrelid = 'atlas_planning.weekly_menu_approval_snapshots'::regclass
      and a.attnum > 0
      and not a.attisdropped
  ),
  array[
    'weekly_menu_approval_snapshot_id',
    'weekly_menu_id',
    'weekly_menu_version',
    'approved_by_actor_id',
    'approved_at'
  ]::text[],
  'approval snapshot headers contain only exact menu/version and approval evidence'
);

select is(
  (
    select array_agg(a.attname order by a.attnum)::text[]
    from pg_attribute a
    where a.attrelid = 'atlas_planning.weekly_menu_approval_snapshot_lines'::regclass
      and a.attnum > 0
      and not a.attisdropped
  ),
  array[
    'weekly_menu_approval_snapshot_line_id',
    'weekly_menu_approval_snapshot_id',
    'weekly_menu_id',
    'weekly_menu_version',
    'weekly_menu_line_id',
    'school_id',
    'service_date',
    'menu_slot_code',
    'dish_id',
    'source_row_reference'
  ]::text[],
  'approval snapshot lines contain only the approved typed line copy'
);

select is(
  (
    select count(*)::integer
    from pg_attrdef ad
    join pg_attribute a
      on a.attrelid = ad.adrelid
     and a.attnum = ad.adnum
    where ad.adrelid in (
      'atlas_planning.weekly_menus'::regclass,
      'atlas_planning.weekly_menu_lines'::regclass,
      'atlas_planning.weekly_menu_approval_snapshots'::regclass,
      'atlas_planning.weekly_menu_approval_snapshot_lines'::regclass
    )
      and a.attname in (
        'weekly_menu_id',
        'weekly_menu_line_id',
        'weekly_menu_approval_snapshot_id',
        'weekly_menu_approval_snapshot_line_id'
      )
      and pg_get_expr(ad.adbin, ad.adrelid) = 'gen_random_uuid()'
  ),
  4,
  'all four H0A3a identities are database-generated UUIDs'
);

select ok(
  to_regclass('atlas_planning.weekly_menu_slots') is null
  and to_regclass('atlas_planning.weekly_menu_issues') is null
  and to_regclass('atlas_planning.weekly_menu_events') is null,
  'H0A3a creates no slot catalogue, issue, or event relation'
);

select ok(
  to_regclass('public.weekly_menus') is null
  and to_regclass('ops_v2.weekly_menus') is null,
  'H0A3a creates no public or OPS v2 Weekly Menu relation'
);

insert into atlas_core.actors (
  actor_id,
  actor_type,
  display_name
) values
  (
    '9a000000-0000-0000-0000-000000000001',
    'HUMAN',
    'PA-06E-H0A3a menu importer'
  ),
  (
    '9a000000-0000-0000-0000-000000000002',
    'HUMAN',
    'PA-06E-H0A3a menu approver'
  ),
  (
    '9a000000-0000-0000-0000-000000000003',
    'HUMAN',
    'PA-06E-H0A3a alternate actor'
  );

insert into atlas_admin.customers (
  customer_id,
  customer_code,
  customer_name,
  customer_type
) values (
  '9a000000-0000-0000-0000-000000000100',
  'pa06e-h0a3a-school-customer',
  'PA-06E-H0A3a synthetic school customer',
  'SCHOOL_CATERING'
);

insert into atlas_admin.delivery_locations (
  delivery_location_id,
  customer_id,
  location_code,
  location_name,
  address_text,
  timezone_name
) values (
  '9a000000-0000-0000-0000-000000000101',
  '9a000000-0000-0000-0000-000000000100',
  'pa06e-h0a3a-location',
  'PA-06E-H0A3a synthetic location',
  'Synthetic local-only address',
  'Asia/Ho_Chi_Minh'
);

insert into atlas_admin.school_types (
  school_type_id,
  school_type_code,
  school_type_name
) values (
  '9a000000-0000-0000-0000-000000000110',
  'pa06e-h0a3a-primary',
  'PA-06E-H0A3a Primary'
);

insert into atlas_admin.schools (
  school_id,
  customer_id,
  school_code,
  school_name,
  school_type_id,
  default_delivery_location_id,
  display_order
) values
  (
    '9a000000-0000-0000-0000-000000000120',
    '9a000000-0000-0000-0000-000000000100',
    'pa06e-h0a3a-school-a',
    'PA-06E-H0A3a School A',
    '9a000000-0000-0000-0000-000000000110',
    '9a000000-0000-0000-0000-000000000101',
    10
  ),
  (
    '9a000000-0000-0000-0000-000000000121',
    '9a000000-0000-0000-0000-000000000100',
    'pa06e-h0a3a-school-b',
    'PA-06E-H0A3a School B',
    '9a000000-0000-0000-0000-000000000110',
    '9a000000-0000-0000-0000-000000000101',
    20
  );

insert into atlas_admin.dishes (
  dish_id,
  dish_code,
  dish_name,
  dish_status,
  display_order
) values
  (
    '9a000000-0000-0000-0000-000000000130',
    'pa06e-h0a3a-soup',
    'PA-06E-H0A3a Soup',
    'ACTIVE',
    10
  ),
  (
    '9a000000-0000-0000-0000-000000000131',
    'pa06e-h0a3a-rice',
    'PA-06E-H0A3a Rice',
    'ACTIVE',
    20
  ),
  (
    '9a000000-0000-0000-0000-000000000132',
    'pa06e-h0a3a-dessert',
    'PA-06E-H0A3a Dessert',
    'ACTIVE',
    30
  );

select lives_ok(
  $$
    insert into atlas_planning.weekly_menus (
      weekly_menu_id,
      week_start,
      week_end,
      source_type,
      source_name,
      source_signature,
      row_count,
      imported_by_actor_id,
      imported_at
    ) values (
      '9a000000-0000-0000-0000-000000000200',
      date '2026-07-21',
      date '2026-07-27',
      'SYNTHETIC_FIXTURE',
      'PA-06E-H0A3a week one',
      'sha256:week-one',
      3,
      '9a000000-0000-0000-0000-000000000001',
      timestamptz '2026-07-19 08:00:00+07'
    )
  $$,
  'a service week may start on Tuesday and remains exactly seven calendar days'
);

select is(
  (
    select row(weekly_menu_status, version, row_count)::text
    from atlas_planning.weekly_menus
    where weekly_menu_id = '9a000000-0000-0000-0000-000000000200'
  ),
  '(DRAFT,1,3)',
  'new Weekly Menu lifecycle, positive version, and nonnegative row-count defaults are exact'
);

select lives_ok(
  $$
    update atlas_planning.weekly_menus
    set source_type = 'SYNTHETIC_FIXTURE_CORRECTED',
        source_name = 'PA-06E-H0A3a corrected week one',
        source_signature = 'sha256:week-one-corrected',
        row_count = 4,
        imported_by_actor_id = '9a000000-0000-0000-0000-000000000003',
        imported_at = timestamptz '2026-07-19 08:15:00+07',
        updated_at = updated_at + interval '1 second'
    where weekly_menu_id = '9a000000-0000-0000-0000-000000000200'
  $$,
  'same-state DRAFT refreshes may replace the complete working source and import evidence'
);

select ok(
  exists (
    select 1
    from atlas_planning.weekly_menus
    where weekly_menu_id = '9a000000-0000-0000-0000-000000000200'
      and source_type = 'SYNTHETIC_FIXTURE_CORRECTED'
      and source_name = 'PA-06E-H0A3a corrected week one'
      and source_signature = 'sha256:week-one-corrected'
      and row_count = 4
      and imported_by_actor_id = '9a000000-0000-0000-0000-000000000003'
      and imported_at = timestamptz '2026-07-19 08:15:00+07'
      and updated_at = created_at + interval '1 second'
  ),
  'all refreshed DRAFT source, import, row-count, and update-time values persist exactly'
);

select ok(
  exists (
    select 1
    from atlas_planning.weekly_menus
    where weekly_menu_id = '9a000000-0000-0000-0000-000000000200'
      and week_start = date '2026-07-21'
      and week_end = date '2026-07-27'
      and version = 1
      and latest_approved_by_actor_id is null
      and latest_approved_at is null
      and latest_approval_snapshot_id is null
  ),
  'DRAFT refresh preserves root identity, week scope, version, and empty approval history'
);

select throws_ok(
  $$
    insert into atlas_planning.weekly_menus (
      weekly_menu_id, week_start, week_end, source_type, source_name,
      source_signature, weekly_menu_status, imported_by_actor_id
    ) values (
      '9a000000-0000-0000-0000-000000000201',
      date '2026-08-04', date '2026-08-10', 'FIXTURE', 'invalid state',
      'invalid-state', 'VALIDATED', '9a000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514',
  'new weekly menus must enter as DRAFT',
  'every Weekly Menu must enter through DRAFT'
);

select throws_ok(
  $$
    insert into atlas_planning.weekly_menus (
      weekly_menu_id, week_start, week_end, source_type, source_name,
      source_signature, weekly_menu_status, imported_by_actor_id
    ) values (
      '9a000000-0000-0000-0000-000000000207',
      date '2026-08-18', date '2026-08-24', 'FIXTURE', 'invalid approved state',
      'invalid-approved', 'APPROVED', '9a000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514',
  'new weekly menus must enter as DRAFT',
  'a new Weekly Menu cannot enter directly as APPROVED'
);

select throws_ok(
  $$
    insert into atlas_planning.weekly_menus (
      weekly_menu_id, week_start, week_end, source_type, source_name,
      source_signature, weekly_menu_status, imported_by_actor_id
    ) values (
      '9a000000-0000-0000-0000-000000000208',
      date '2026-08-25', date '2026-08-31', 'FIXTURE', 'invalid requested state',
      'invalid-requested', 'NEED_GENERATION_REQUESTED',
      '9a000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514',
  'new weekly menus must enter as DRAFT',
  'a new Weekly Menu cannot enter directly as NEED_GENERATION_REQUESTED'
);

select throws_ok(
  $$
    insert into atlas_planning.weekly_menus (
      weekly_menu_id, week_start, week_end, source_type, source_name,
      source_signature, weekly_menu_status, imported_by_actor_id
    ) values (
      '9a000000-0000-0000-0000-000000000209',
      date '2026-09-01', date '2026-09-07', 'FIXTURE', 'invalid reopened state',
      'invalid-reopened', 'REOPENED', '9a000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514',
  'new weekly menus must enter as DRAFT',
  'a new Weekly Menu cannot enter directly as REOPENED'
);

select throws_ok(
  $$
    insert into atlas_planning.weekly_menus (
      weekly_menu_id, week_start, week_end, source_type, source_name,
      source_signature, imported_by_actor_id
    ) values (
      '9a000000-0000-0000-0000-000000000202',
      date '2026-08-04', date '2026-08-11', 'FIXTURE', 'bad week',
      'bad-week', '9a000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514',
  'new row for relation "weekly_menus" violates check constraint "weekly_menus_service_week_check"',
  'week_end must be the inclusive seventh calendar day'
);

select throws_ok(
  $$
    insert into atlas_planning.weekly_menus (
      weekly_menu_id, week_start, week_end, source_type, source_name,
      source_signature, imported_by_actor_id
    ) values (
      '9a000000-0000-0000-0000-000000000203',
      date '2026-07-21', date '2026-07-27', 'FIXTURE', 'duplicate week',
      'duplicate-week', '9a000000-0000-0000-0000-000000000001'
    )
  $$,
  '23505',
  'duplicate key value violates unique constraint "weekly_menus_week_start_key"',
  'only one stable Weekly Menu root exists for a service week'
);

select throws_ok(
  $$
    insert into atlas_planning.weekly_menus (
      weekly_menu_id, week_start, week_end, source_type, source_name,
      source_signature, imported_by_actor_id
    ) values (
      '9a000000-0000-0000-0000-000000000204',
      date '2026-08-04', date '2026-08-10', ' ', 'blank source',
      'blank-source', '9a000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514',
  'new row for relation "weekly_menus" violates check constraint "weekly_menus_source_type_check"',
  'source type must be nonblank'
);

select throws_ok(
  $$
    insert into atlas_planning.weekly_menus (
      weekly_menu_id, week_start, week_end, source_type, source_name,
      source_signature, row_count, imported_by_actor_id
    ) values (
      '9a000000-0000-0000-0000-000000000205',
      date '2026-08-04', date '2026-08-10', 'FIXTURE', 'negative rows',
      'negative-rows', -1, '9a000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514',
  'new row for relation "weekly_menus" violates check constraint "weekly_menus_row_count_check"',
  'row count cannot be negative'
);

select throws_ok(
  $$
    insert into atlas_planning.weekly_menus (
      weekly_menu_id, week_start, week_end, source_type, source_name,
      source_signature, version, imported_by_actor_id
    ) values (
      '9a000000-0000-0000-0000-000000000206',
      date '2026-08-04', date '2026-08-10', 'FIXTURE', 'zero version',
      'zero-version', 0, '9a000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514',
  'new row for relation "weekly_menus" violates check constraint "weekly_menus_version_check"',
  'Weekly Menu version must be positive'
);

select lives_ok(
  $$
    insert into atlas_planning.weekly_menu_lines (
      weekly_menu_line_id, weekly_menu_id, school_id, service_date,
      menu_slot_code, dish_id, source_row_reference,
      created_by_actor_id, updated_by_actor_id
    ) values (
      '9a000000-0000-0000-0000-000000000210',
      '9a000000-0000-0000-0000-000000000200',
      '9a000000-0000-0000-0000-000000000120',
      date '2026-07-21', 'soup',
      '9a000000-0000-0000-0000-000000000130', 'Sheet1!A2',
      '9a000000-0000-0000-0000-000000000001',
      '9a000000-0000-0000-0000-000000000001'
    ), (
      '9a000000-0000-0000-0000-000000000211',
      '9a000000-0000-0000-0000-000000000200',
      '9a000000-0000-0000-0000-000000000120',
      date '2026-07-21', 'savory',
      '9a000000-0000-0000-0000-000000000131', 'Sheet1!B2',
      '9a000000-0000-0000-0000-000000000001',
      '9a000000-0000-0000-0000-000000000001'
    )
  $$,
  'typed active Weekly Menu lines can be recorded while the root is DRAFT'
);

select lives_ok(
  $$
    insert into atlas_planning.weekly_menu_lines (
      weekly_menu_line_id, weekly_menu_id, school_id, service_date,
      menu_slot_code, dish_id, line_status, source_row_reference,
      created_by_actor_id, updated_by_actor_id
    ) values (
      '9a000000-0000-0000-0000-000000000212',
      '9a000000-0000-0000-0000-000000000200',
      '9a000000-0000-0000-0000-000000000121',
      date '2026-07-22', 'dessert',
      '9a000000-0000-0000-0000-000000000132', 'INVALID', 'Sheet1!C2',
      '9a000000-0000-0000-0000-000000000001',
      '9a000000-0000-0000-0000-000000000001'
    )
  $$,
  'an invalid working line remains typed but is distinguishable from ACTIVE input'
);

select throws_ok(
  $$
    insert into atlas_planning.weekly_menu_lines (
      weekly_menu_line_id, weekly_menu_id, school_id, service_date,
      menu_slot_code, dish_id, created_by_actor_id, updated_by_actor_id
    ) values (
      '9a000000-0000-0000-0000-000000000213',
      '9a000000-0000-0000-0000-000000000200',
      '9a000000-0000-0000-0000-000000000120',
      date '2026-07-28', 'outside',
      '9a000000-0000-0000-0000-000000000130',
      '9a000000-0000-0000-0000-000000000001',
      '9a000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514',
  'weekly menu line service date must be inside the menu service week',
  'line service dates outside the root week are rejected'
);

select throws_ok(
  $$
    insert into atlas_planning.weekly_menu_lines (
      weekly_menu_line_id, weekly_menu_id, school_id, service_date,
      menu_slot_code, dish_id, created_by_actor_id, updated_by_actor_id
    ) values (
      '9a000000-0000-0000-0000-000000000214',
      '9a000000-0000-0000-0000-000000000200',
      '9a000000-0000-0000-0000-000000000121',
      date '2026-07-23', 'Soup',
      '9a000000-0000-0000-0000-000000000130',
      '9a000000-0000-0000-0000-000000000001',
      '9a000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514',
  'new row for relation "weekly_menu_lines" violates check constraint "weekly_menu_lines_menu_slot_code_check"',
  'menu slot evidence is normalized before the RMVP-03A typed catalog foreign key'
);

select throws_ok(
  $$
    insert into atlas_planning.weekly_menu_lines (
      weekly_menu_line_id, weekly_menu_id, school_id, service_date,
      menu_slot_code, dish_id, created_by_actor_id, updated_by_actor_id
    ) values (
      '9a000000-0000-0000-0000-000000000216',
      '9a000000-0000-0000-0000-000000000200',
      '9a000000-0000-0000-0000-000000000121',
      date '2026-07-24', ' soup',
      '9a000000-0000-0000-0000-000000000130',
      '9a000000-0000-0000-0000-000000000001',
      '9a000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514',
  'new row for relation "weekly_menu_lines" violates check constraint "weekly_menu_lines_menu_slot_code_check"',
  'working menu-slot evidence rejects leading whitespace'
);

select throws_ok(
  $$
    insert into atlas_planning.weekly_menu_lines (
      weekly_menu_line_id, weekly_menu_id, school_id, service_date,
      menu_slot_code, dish_id, created_by_actor_id, updated_by_actor_id
    ) values (
      '9a000000-0000-0000-0000-000000000217',
      '9a000000-0000-0000-0000-000000000200',
      '9a000000-0000-0000-0000-000000000121',
      date '2026-07-25', 'soup ',
      '9a000000-0000-0000-0000-000000000130',
      '9a000000-0000-0000-0000-000000000001',
      '9a000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514',
  'new row for relation "weekly_menu_lines" violates check constraint "weekly_menu_lines_menu_slot_code_check"',
  'working menu-slot evidence rejects trailing whitespace'
);

select throws_ok(
  $$
    insert into atlas_planning.weekly_menu_lines (
      weekly_menu_line_id, weekly_menu_id, school_id, service_date,
      menu_slot_code, dish_id, created_by_actor_id, updated_by_actor_id
    ) values (
      '9a000000-0000-0000-0000-000000000218',
      '9a000000-0000-0000-0000-000000000200',
      '9a000000-0000-0000-0000-000000000121',
      date '2026-07-26', '',
      '9a000000-0000-0000-0000-000000000130',
      '9a000000-0000-0000-0000-000000000001',
      '9a000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514',
  'new row for relation "weekly_menu_lines" violates check constraint "weekly_menu_lines_menu_slot_code_check"',
  'working menu-slot evidence rejects an empty code'
);

select throws_ok(
  $$
    insert into atlas_planning.weekly_menu_lines (
      weekly_menu_line_id, weekly_menu_id, school_id, service_date,
      menu_slot_code, dish_id, created_by_actor_id, updated_by_actor_id
    ) values (
      '9a000000-0000-0000-0000-000000000219',
      '9a000000-0000-0000-0000-000000000200',
      '9a000000-0000-0000-0000-000000000121',
      date '2026-07-27', '   ',
      '9a000000-0000-0000-0000-000000000130',
      '9a000000-0000-0000-0000-000000000001',
      '9a000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514',
  'new row for relation "weekly_menu_lines" violates check constraint "weekly_menu_lines_menu_slot_code_check"',
  'working menu-slot evidence rejects a whitespace-only code'
);

select throws_ok(
  $$
    insert into atlas_planning.weekly_menu_lines (
      weekly_menu_line_id, weekly_menu_id, school_id, service_date,
      menu_slot_code, dish_id, created_by_actor_id, updated_by_actor_id
    ) values (
      '9a000000-0000-0000-0000-000000000225',
      '9a000000-0000-0000-0000-000000000200',
      '9a000000-0000-0000-0000-000000000120',
      date '2026-07-21', ' soup ',
      '9a000000-0000-0000-0000-000000000132',
      '9a000000-0000-0000-0000-000000000001',
      '9a000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514',
  'new row for relation "weekly_menu_lines" violates check constraint "weekly_menu_lines_menu_slot_code_check"',
  'surrounding whitespace cannot bypass the existing soup assignment uniqueness'
);

select throws_ok(
  $$
    update atlas_planning.weekly_menu_lines
    set menu_slot_code = ' Soup '
    where weekly_menu_line_id = '9a000000-0000-0000-0000-000000000210'
  $$,
  '23514',
  'new row for relation "weekly_menu_lines" violates check constraint "weekly_menu_lines_menu_slot_code_check"',
  'working-line updates cannot introduce noncanonical menu-slot storage'
);

select is(
  (
    select count(*)::integer
    from pg_constraint
    where conname in (
      'weekly_menu_lines_menu_slot_code_check',
      'weekly_menu_approval_snapshot_lines_menu_slot_code_check'
    )
      and pg_get_constraintdef(oid) like '%lower(btrim(menu_slot_code))%'
  ),
  2,
  'working and snapshot menu-slot checks both require trimmed lowercase storage'
);

select throws_ok(
  $$
    insert into atlas_planning.weekly_menu_lines (
      weekly_menu_line_id, weekly_menu_id, school_id, service_date,
      menu_slot_code, dish_id, created_by_actor_id, updated_by_actor_id
    ) values (
      '9a000000-0000-0000-0000-000000000215',
      '9a000000-0000-0000-0000-000000000200',
      '9a000000-0000-0000-0000-000000000120',
      date '2026-07-21', 'soup',
      '9a000000-0000-0000-0000-000000000132',
      '9a000000-0000-0000-0000-000000000001',
      '9a000000-0000-0000-0000-000000000001'
    )
  $$,
  '23505',
  'duplicate key value violates unique constraint "weekly_menu_lines_assignment_key"',
  'school, service date, and slot are unique within one Weekly Menu'
);

select throws_ok(
  $$
    update atlas_planning.weekly_menu_lines
    set weekly_menu_id = '9a000000-0000-0000-0000-000000000999'
    where weekly_menu_line_id = '9a000000-0000-0000-0000-000000000210'
  $$,
  '23514',
  'stable weekly menu line identity and ownership are immutable',
  'stable Weekly Menu line ownership cannot be reassigned'
);

select throws_ok(
  $$
    update atlas_planning.weekly_menus
    set weekly_menu_status = 'VALIDATED',
        source_type = 'SMUGGLED_SOURCE_TYPE'
    where weekly_menu_id = '9a000000-0000-0000-0000-000000000200'
  $$,
  '23514',
  'weekly menu import and source evidence may change only during same-state DRAFT or REOPENED refreshes',
  'validation cannot rewrite the imported source type'
);

select throws_ok(
  $$
    update atlas_planning.weekly_menus
    set weekly_menu_status = 'VALIDATED',
        updated_at = updated_at + interval '1 second'
    where weekly_menu_id = '9a000000-0000-0000-0000-000000000200'
  $$,
  '23514',
  'weekly menu import and source evidence may change only during same-state DRAFT or REOPENED refreshes',
  'validation cannot rewrite the working update timestamp'
);

select lives_ok(
  $$
    update atlas_planning.weekly_menus
    set weekly_menu_status = 'VALIDATED'
    where weekly_menu_id = '9a000000-0000-0000-0000-000000000200'
  $$,
  'DRAFT advances to VALIDATED without skipping a lifecycle state'
);

select throws_ok(
  $$
    update atlas_planning.weekly_menus
    set source_type = 'IMMUTABLE_VALIDATED_SOURCE'
    where weekly_menu_id = '9a000000-0000-0000-0000-000000000200'
  $$,
  '23514',
  'weekly menu import and source evidence may change only during same-state DRAFT or REOPENED refreshes',
  'same-state VALIDATED updates cannot rewrite source or import evidence'
);

select throws_ok(
  $$
    update atlas_planning.weekly_menus
    set weekly_menu_status = 'DRAFT'
    where weekly_menu_id = '9a000000-0000-0000-0000-000000000200'
  $$,
  '23514',
  'weekly menu lifecycle transition is invalid',
  'reverse lifecycle transitions are rejected'
);

select throws_ok(
  $$
    update atlas_planning.weekly_menu_lines
    set dish_id = '9a000000-0000-0000-0000-000000000132'
    where weekly_menu_line_id = '9a000000-0000-0000-0000-000000000210'
  $$,
  '23514',
  'weekly menu lines are mutable only while the menu is DRAFT or REOPENED',
  'validated Weekly Menu lines cannot be edited'
);

select throws_ok(
  $$
    delete from atlas_planning.weekly_menu_lines
    where weekly_menu_line_id = '9a000000-0000-0000-0000-000000000210'
  $$,
  '23514',
  'weekly menu lines are mutable only while the menu is DRAFT or REOPENED',
  'validated Weekly Menu lines cannot be deleted'
);

insert into atlas_planning.weekly_menu_approval_snapshots (
  weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version,
  approved_by_actor_id, approved_at
) values (
  '9a000000-0000-0000-0000-000000000220',
  '9a000000-0000-0000-0000-000000000200', 1,
  '9a000000-0000-0000-0000-000000000002',
  timestamptz '2026-07-19 09:00:00+07'
);

insert into atlas_planning.weekly_menu_approval_snapshot_lines (
  weekly_menu_approval_snapshot_line_id,
  weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version,
  weekly_menu_line_id, school_id, service_date, menu_slot_code, dish_id,
  source_row_reference
) values
  (
    '9a000000-0000-0000-0000-000000000221',
    '9a000000-0000-0000-0000-000000000220',
    '9a000000-0000-0000-0000-000000000200', 1,
    '9a000000-0000-0000-0000-000000000210',
    '9a000000-0000-0000-0000-000000000120', date '2026-07-21', 'soup',
    '9a000000-0000-0000-0000-000000000130', 'Sheet1!A2'
  ),
  (
    '9a000000-0000-0000-0000-000000000222',
    '9a000000-0000-0000-0000-000000000220',
    '9a000000-0000-0000-0000-000000000200', 1,
    '9a000000-0000-0000-0000-000000000211',
    '9a000000-0000-0000-0000-000000000120', date '2026-07-21', 'savory',
    '9a000000-0000-0000-0000-000000000131', 'Sheet1!B2'
  );

select throws_ok(
  $$
    insert into atlas_planning.weekly_menu_approval_snapshot_lines (
      weekly_menu_approval_snapshot_line_id,
      weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version,
      weekly_menu_line_id, school_id, service_date, menu_slot_code, dish_id,
      source_row_reference
    ) values (
      '9a000000-0000-0000-0000-000000000223',
      '9a000000-0000-0000-0000-000000000220',
      '9a000000-0000-0000-0000-000000000200', 1,
      '9a000000-0000-0000-0000-000000000210',
      '9a000000-0000-0000-0000-000000000120', date '2026-07-21', ' soup',
      '9a000000-0000-0000-0000-000000000130', 'Sheet1!A2'
    )
  $$,
  '23514',
  'approval snapshot lines must exactly copy active weekly menu lines',
  'snapshot menu-slot evidence rejects leading whitespace'
);

select throws_ok(
  $$
    insert into atlas_planning.weekly_menu_approval_snapshot_lines (
      weekly_menu_approval_snapshot_line_id,
      weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version,
      weekly_menu_line_id, school_id, service_date, menu_slot_code, dish_id,
      source_row_reference
    ) values (
      '9a000000-0000-0000-0000-000000000224',
      '9a000000-0000-0000-0000-000000000220',
      '9a000000-0000-0000-0000-000000000200', 1,
      '9a000000-0000-0000-0000-000000000210',
      '9a000000-0000-0000-0000-000000000120', date '2026-07-21', 'soup ',
      '9a000000-0000-0000-0000-000000000130', 'Sheet1!A2'
    )
  $$,
  '23514',
  'approval snapshot lines must exactly copy active weekly menu lines',
  'snapshot menu-slot evidence rejects trailing whitespace'
);

select throws_ok(
  $$
    update atlas_planning.weekly_menus
    set weekly_menu_status = 'APPROVED',
        source_signature = 'smuggled-approval-signature',
        latest_approved_by_actor_id = '9a000000-0000-0000-0000-000000000002',
        latest_approved_at = timestamptz '2026-07-19 09:00:00+07',
        latest_approval_snapshot_id = '9a000000-0000-0000-0000-000000000220'
    where weekly_menu_id = '9a000000-0000-0000-0000-000000000200'
  $$,
  '23514',
  'weekly menu import and source evidence may change only during same-state DRAFT or REOPENED refreshes',
  'approval cannot rewrite the imported source signature'
);

select lives_ok(
  $$
    update atlas_planning.weekly_menus
    set weekly_menu_status = 'APPROVED',
        latest_approved_by_actor_id = '9a000000-0000-0000-0000-000000000002',
        latest_approved_at = timestamptz '2026-07-19 09:00:00+07',
        latest_approval_snapshot_id = '9a000000-0000-0000-0000-000000000220'
    where weekly_menu_id = '9a000000-0000-0000-0000-000000000200';

    set constraints all immediate;
    set constraints all deferred
  $$,
  'VALIDATED advances to APPROVED only with one complete exact active-line snapshot'
);

select is(
  (
    select count(*)::integer
    from atlas_planning.weekly_menu_approval_snapshot_lines
    where weekly_menu_approval_snapshot_id = '9a000000-0000-0000-0000-000000000220'
  ),
  2,
  'the first approval snapshot contains every ACTIVE line and excludes the INVALID line'
);

select is(
  (
    select row(
      weekly_menu_status,
      latest_approved_by_actor_id,
      latest_approved_at,
      latest_approval_snapshot_id,
      version
    )::text
    from atlas_planning.weekly_menus
    where weekly_menu_id = '9a000000-0000-0000-0000-000000000200'
  ),
  '(APPROVED,9a000000-0000-0000-0000-000000000002,"2026-07-19 02:00:00+00",9a000000-0000-0000-0000-000000000220,1)',
  'approved root evidence points to the exact current snapshot and actor/time'
);

select throws_ok(
  $$
    update atlas_planning.weekly_menus
    set source_name = 'immutable approved source'
    where weekly_menu_id = '9a000000-0000-0000-0000-000000000200'
  $$,
  '23514',
  'weekly menu import and source evidence may change only during same-state DRAFT or REOPENED refreshes',
  'same-state APPROVED updates cannot rewrite source or import evidence'
);

select throws_ok(
  $$
    update atlas_planning.weekly_menu_approval_snapshots
    set approved_at = timestamptz '2026-07-19 10:00:00+07'
    where weekly_menu_approval_snapshot_id = '9a000000-0000-0000-0000-000000000220'
  $$,
  '23514',
  'weekly menu approval snapshots and snapshot lines are immutable',
  'approval snapshot headers are immutable'
);

select throws_ok(
  $$
    delete from atlas_planning.weekly_menu_approval_snapshot_lines
    where weekly_menu_approval_snapshot_line_id = '9a000000-0000-0000-0000-000000000221'
  $$,
  '23514',
  'weekly menu approval snapshots and snapshot lines are immutable',
  'approval snapshot lines are immutable'
);

select throws_ok(
  $$
    update atlas_planning.weekly_menu_lines
    set dish_id = '9a000000-0000-0000-0000-000000000132'
    where weekly_menu_line_id = '9a000000-0000-0000-0000-000000000210'
  $$,
  '23514',
  'weekly menu lines are mutable only while the menu is DRAFT or REOPENED',
  'approved Weekly Menu lines cannot be edited'
);

select throws_ok(
  $$
    update atlas_planning.weekly_menus
    set weekly_menu_status = 'NEED_GENERATION_REQUESTED',
        row_count = row_count + 1
    where weekly_menu_id = '9a000000-0000-0000-0000-000000000200'
  $$,
  '23514',
  'weekly menu import and source evidence may change only during same-state DRAFT or REOPENED refreshes',
  'Need Generation request cannot rewrite the imported row count'
);

select lives_ok(
  $$
    update atlas_planning.weekly_menus
    set weekly_menu_status = 'NEED_GENERATION_REQUESTED'
    where weekly_menu_id = '9a000000-0000-0000-0000-000000000200';
    set constraints all immediate;
    set constraints all deferred
  $$,
  'APPROVED advances to NEED_GENERATION_REQUESTED with the same exact snapshot'
);

select is(
  (
    select row(
      latest_approved_by_actor_id,
      latest_approved_at,
      latest_approval_snapshot_id
    )::text
    from atlas_planning.weekly_menus
    where weekly_menu_id = '9a000000-0000-0000-0000-000000000200'
  ),
  '(9a000000-0000-0000-0000-000000000002,"2026-07-19 02:00:00+00",9a000000-0000-0000-0000-000000000220)',
  'request transition preserves established approval actor, timestamp, and snapshot evidence'
);

select throws_ok(
  $$
    update atlas_planning.weekly_menus
    set source_signature = 'immutable-requested-signature'
    where weekly_menu_id = '9a000000-0000-0000-0000-000000000200'
  $$,
  '23514',
  'weekly menu import and source evidence may change only during same-state DRAFT or REOPENED refreshes',
  'same-state NEED_GENERATION_REQUESTED updates cannot rewrite source or import evidence'
);

select throws_ok(
  $$
    update atlas_planning.weekly_menus
    set weekly_menu_status = 'REOPENED'
    where weekly_menu_id = '9a000000-0000-0000-0000-000000000200'
  $$,
  '23514',
  'reopening a weekly menu must create the next working version',
  'reopen cannot reuse the approved version'
);

select throws_ok(
  $$
    update atlas_planning.weekly_menus
    set weekly_menu_status = 'REOPENED',
        version = version + 1,
        imported_by_actor_id = '9a000000-0000-0000-0000-000000000001'
    where weekly_menu_id = '9a000000-0000-0000-0000-000000000200'
  $$,
  '23514',
  'weekly menu import and source evidence may change only during same-state DRAFT or REOPENED refreshes',
  'reopen cannot rewrite the importing actor'
);

select lives_ok(
  $$
    update atlas_planning.weekly_menus
    set weekly_menu_status = 'REOPENED',
        version = version + 1
    where weekly_menu_id = '9a000000-0000-0000-0000-000000000200'
  $$,
  'NEED_GENERATION_REQUESTED reopens as the next working version'
);

select is(
  (
    select row(
      weekly_menu_status,
      version,
      latest_approved_by_actor_id,
      latest_approved_at,
      latest_approval_snapshot_id
    )::text
    from atlas_planning.weekly_menus
    where weekly_menu_id = '9a000000-0000-0000-0000-000000000200'
  ),
  '(REOPENED,2,9a000000-0000-0000-0000-000000000002,"2026-07-19 02:00:00+00",9a000000-0000-0000-0000-000000000220)',
  'reopen preserves the complete established approval evidence while advancing the version'
);

select lives_ok(
  $$
    update atlas_planning.weekly_menus
    set source_type = 'SYNTHETIC_REIMPORT',
        source_name = 'PA-06E-H0A3a reopened reimport',
        source_signature = 'sha256:week-one-reopened',
        row_count = 3,
        imported_by_actor_id = '9a000000-0000-0000-0000-000000000001',
        imported_at = timestamptz '2026-07-19 08:20:00+07',
        updated_at = updated_at + interval '1 second'
    where weekly_menu_id = '9a000000-0000-0000-0000-000000000200'
  $$,
  'same-state REOPENED refreshes may replace the complete working source and import evidence'
);

select ok(
  exists (
    select 1
    from atlas_planning.weekly_menus
    where weekly_menu_id = '9a000000-0000-0000-0000-000000000200'
      and source_type = 'SYNTHETIC_REIMPORT'
      and source_name = 'PA-06E-H0A3a reopened reimport'
      and source_signature = 'sha256:week-one-reopened'
      and row_count = 3
      and imported_by_actor_id = '9a000000-0000-0000-0000-000000000001'
      and imported_at = timestamptz '2026-07-19 08:20:00+07'
      and updated_at = created_at + interval '2 seconds'
  ),
  'all refreshed REOPENED source, import, row-count, and update-time values persist exactly'
);

select ok(
  exists (
    select 1
    from atlas_planning.weekly_menus
    where weekly_menu_id = '9a000000-0000-0000-0000-000000000200'
      and week_start = date '2026-07-21'
      and week_end = date '2026-07-27'
      and version = 2
      and latest_approved_by_actor_id = '9a000000-0000-0000-0000-000000000002'
      and latest_approved_at = timestamptz '2026-07-19 09:00:00+07'
      and latest_approval_snapshot_id = '9a000000-0000-0000-0000-000000000220'
  ),
  'REOPENED refresh preserves root identity, week scope, version, and prior approval history'
);

select lives_ok(
  $$
    update atlas_planning.weekly_menu_lines
    set dish_id = '9a000000-0000-0000-0000-000000000132',
        source_row_reference = 'Sheet1!A2-corrected',
        updated_by_actor_id = '9a000000-0000-0000-0000-000000000003',
        updated_at = transaction_timestamp()
    where weekly_menu_line_id = '9a000000-0000-0000-0000-000000000210'
  $$,
  'a stable line may be corrected after explicit reopen'
);

select is(
  (
    select row(dish_id, source_row_reference)::text
    from atlas_planning.weekly_menu_approval_snapshot_lines
    where weekly_menu_approval_snapshot_line_id = '9a000000-0000-0000-0000-000000000221'
  ),
  '(9a000000-0000-0000-0000-000000000130,Sheet1!A2)',
  'reopened line correction does not rewrite the prior approval snapshot'
);

select throws_ok(
  $$
    update atlas_planning.weekly_menus
    set weekly_menu_status = 'DRAFT',
        imported_at = timestamptz '2026-07-19 08:30:00+07'
    where weekly_menu_id = '9a000000-0000-0000-0000-000000000200'
  $$,
  '23514',
  'weekly menu import and source evidence may change only during same-state DRAFT or REOPENED refreshes',
  'return to DRAFT cannot rewrite the imported timestamp'
);

select lives_ok(
  $$
    update atlas_planning.weekly_menus
    set weekly_menu_status = 'DRAFT'
    where weekly_menu_id = '9a000000-0000-0000-0000-000000000200'
  $$,
  'REOPENED advances only to DRAFT while retaining its stable root'
);

select lives_ok(
  $$
    update atlas_planning.weekly_menus
    set weekly_menu_status = 'VALIDATED'
    where weekly_menu_id = '9a000000-0000-0000-0000-000000000200'
  $$,
  'the corrected later working version returns through VALIDATED'
);

select lives_ok(
  $test$
    do $body$
    begin
      insert into atlas_planning.weekly_menu_approval_snapshots (
        weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version,
        approved_by_actor_id, approved_at
      ) values (
        '9a000000-0000-0000-0000-000000000230',
        '9a000000-0000-0000-0000-000000000200', 2,
        '9a000000-0000-0000-0000-000000000003',
        timestamptz '2026-07-19 11:00:00+07'
      );

      insert into atlas_planning.weekly_menu_approval_snapshot_lines (
        weekly_menu_approval_snapshot_line_id,
        weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version,
        weekly_menu_line_id, school_id, service_date, menu_slot_code, dish_id,
        source_row_reference
      ) values
        (
          '9a000000-0000-0000-0000-000000000231',
          '9a000000-0000-0000-0000-000000000230',
          '9a000000-0000-0000-0000-000000000200', 2,
          '9a000000-0000-0000-0000-000000000210',
          '9a000000-0000-0000-0000-000000000120', date '2026-07-21', 'soup',
          '9a000000-0000-0000-0000-000000000132', 'Sheet1!A2-corrected'
        ),
        (
          '9a000000-0000-0000-0000-000000000232',
          '9a000000-0000-0000-0000-000000000230',
          '9a000000-0000-0000-0000-000000000200', 2,
          '9a000000-0000-0000-0000-000000000211',
          '9a000000-0000-0000-0000-000000000120', date '2026-07-21', 'savory',
          '9a000000-0000-0000-0000-000000000131', 'Sheet1!B2'
        );

      update atlas_planning.weekly_menus
      set weekly_menu_status = 'APPROVED',
          latest_approved_by_actor_id = '9a000000-0000-0000-0000-000000000003',
          latest_approved_at = timestamptz '2026-07-19 11:00:00+07',
          latest_approval_snapshot_id = '9a000000-0000-0000-0000-000000000230'
      where weekly_menu_id = '9a000000-0000-0000-0000-000000000200';

      set constraints all immediate;
      set constraints all deferred;
    end
    $body$
  $test$,
  'a later version receives a new complete immutable approval snapshot'
);

select is(
  (
    select count(*)::integer
    from atlas_planning.weekly_menu_approval_snapshots
    where weekly_menu_id = '9a000000-0000-0000-0000-000000000200'
  ),
  2,
  'both historical approval snapshots remain after later-version approval'
);

select is(
  (
    select row(
      weekly_menu_status,
      version,
      latest_approved_by_actor_id,
      latest_approval_snapshot_id
    )::text
    from atlas_planning.weekly_menus
    where weekly_menu_id = '9a000000-0000-0000-0000-000000000200'
  ),
  '(APPROVED,2,9a000000-0000-0000-0000-000000000003,9a000000-0000-0000-0000-000000000230)',
  'the stable root points to the exact latest approved version without deleting history'
);

select throws_ok(
  $$
    update atlas_planning.weekly_menus
    set week_start = date '2026-07-20',
        week_end = date '2026-07-26'
    where weekly_menu_id = '9a000000-0000-0000-0000-000000000200'
  $$,
  '23514',
  'weekly menu identity and service-week scope are immutable',
  'stable root service-week scope cannot be reassigned'
);

insert into atlas_planning.weekly_menus (
  weekly_menu_id, week_start, week_end, source_type, source_name,
  source_signature, row_count, imported_by_actor_id
) values
  (
    '9a000000-0000-0000-0000-000000000300',
    date '2026-07-28', date '2026-08-03', 'FIXTURE', 'week two',
    'week-two', 3, '9a000000-0000-0000-0000-000000000001'
  ),
  (
    '9a000000-0000-0000-0000-000000000400',
    date '2026-08-11', date '2026-08-17', 'FIXTURE', 'week three',
    'week-three', 0, '9a000000-0000-0000-0000-000000000001'
  );

insert into atlas_planning.weekly_menu_lines (
  weekly_menu_line_id, weekly_menu_id, school_id, service_date,
  menu_slot_code, dish_id, line_status, source_row_reference,
  created_by_actor_id, updated_by_actor_id
) values
  (
    '9a000000-0000-0000-0000-000000000310',
    '9a000000-0000-0000-0000-000000000300',
    '9a000000-0000-0000-0000-000000000120', date '2026-07-28', 'soup',
    '9a000000-0000-0000-0000-000000000130', 'ACTIVE', 'Sheet2!A2',
    '9a000000-0000-0000-0000-000000000001',
    '9a000000-0000-0000-0000-000000000001'
  ),
  (
    '9a000000-0000-0000-0000-000000000311',
    '9a000000-0000-0000-0000-000000000300',
    '9a000000-0000-0000-0000-000000000121', date '2026-07-29', 'savory',
    '9a000000-0000-0000-0000-000000000131', 'ACTIVE', 'Sheet2!B2',
    '9a000000-0000-0000-0000-000000000001',
    '9a000000-0000-0000-0000-000000000001'
  ),
  (
    '9a000000-0000-0000-0000-000000000312',
    '9a000000-0000-0000-0000-000000000300',
    '9a000000-0000-0000-0000-000000000121', date '2026-07-30', 'dessert',
    '9a000000-0000-0000-0000-000000000132', 'INVALID', 'Sheet2!C2',
    '9a000000-0000-0000-0000-000000000001',
    '9a000000-0000-0000-0000-000000000001'
  );

update atlas_planning.weekly_menus
set weekly_menu_status = 'VALIDATED'
where weekly_menu_id = '9a000000-0000-0000-0000-000000000300';

select throws_ok(
  $$
    insert into atlas_planning.weekly_menu_approval_snapshots (
      weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version,
      approved_by_actor_id, approved_at
    ) values (
      '9a000000-0000-0000-0000-000000000410',
      '9a000000-0000-0000-0000-000000000400', 1,
      '9a000000-0000-0000-0000-000000000002', transaction_timestamp()
    )
  $$,
  '23514',
  'an approval snapshot requires the exact current validated weekly menu version',
  'a DRAFT Weekly Menu cannot receive an approval snapshot'
);

select throws_ok(
  $test$
    do $body$
    begin
      insert into atlas_planning.weekly_menu_approval_snapshots (
        weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version,
        approved_by_actor_id, approved_at
      ) values (
        '9a000000-0000-0000-0000-000000000320',
        '9a000000-0000-0000-0000-000000000300', 1,
        '9a000000-0000-0000-0000-000000000002',
        timestamptz '2026-07-19 12:00:00+07'
      );

      insert into atlas_planning.weekly_menu_approval_snapshot_lines (
        weekly_menu_approval_snapshot_line_id,
        weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version,
        weekly_menu_line_id, school_id, service_date, menu_slot_code, dish_id,
        source_row_reference
      ) values (
        '9a000000-0000-0000-0000-000000000321',
        '9a000000-0000-0000-0000-000000000320',
        '9a000000-0000-0000-0000-000000000300', 1,
        '9a000000-0000-0000-0000-000000000310',
        '9a000000-0000-0000-0000-000000000120', date '2026-07-28', 'soup',
        '9a000000-0000-0000-0000-000000000132', 'Sheet2!A2'
      );
    end
    $body$
  $test$,
  '23514',
  'approval snapshot lines must exactly copy active weekly menu lines',
  'a snapshot line cannot substitute a different Dish'
);

select throws_ok(
  $test$
    do $body$
    begin
      insert into atlas_planning.weekly_menu_approval_snapshots (
        weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version,
        approved_by_actor_id, approved_at
      ) values (
        '9a000000-0000-0000-0000-000000000322',
        '9a000000-0000-0000-0000-000000000300', 1,
        '9a000000-0000-0000-0000-000000000002',
        timestamptz '2026-07-19 12:00:00+07'
      );

      insert into atlas_planning.weekly_menu_approval_snapshot_lines (
        weekly_menu_approval_snapshot_line_id,
        weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version,
        weekly_menu_line_id, school_id, service_date, menu_slot_code, dish_id,
        source_row_reference
      ) values (
        '9a000000-0000-0000-0000-000000000323',
        '9a000000-0000-0000-0000-000000000322',
        '9a000000-0000-0000-0000-000000000300', 1,
        '9a000000-0000-0000-0000-000000000312',
        '9a000000-0000-0000-0000-000000000121', date '2026-07-30', 'dessert',
        '9a000000-0000-0000-0000-000000000132', 'Sheet2!C2'
      );
    end
    $body$
  $test$,
  '23514',
  'approval snapshot lines must exactly copy active weekly menu lines',
  'an INVALID line cannot enter an approval snapshot'
);

select throws_ok(
  $test$
    do $body$
    begin
      insert into atlas_planning.weekly_menu_approval_snapshots (
        weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version,
        approved_by_actor_id, approved_at
      ) values (
        '9a000000-0000-0000-0000-000000000324',
        '9a000000-0000-0000-0000-000000000300', 1,
        '9a000000-0000-0000-0000-000000000002',
        timestamptz '2026-07-19 12:00:00+07'
      );

      insert into atlas_planning.weekly_menu_approval_snapshot_lines (
        weekly_menu_approval_snapshot_line_id,
        weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version,
        weekly_menu_line_id, school_id, service_date, menu_slot_code, dish_id,
        source_row_reference
      ) values (
        '9a000000-0000-0000-0000-000000000325',
        '9a000000-0000-0000-0000-000000000324',
        '9a000000-0000-0000-0000-000000000300', 1,
        '9a000000-0000-0000-0000-000000000210',
        '9a000000-0000-0000-0000-000000000120', date '2026-07-21', 'soup',
        '9a000000-0000-0000-0000-000000000130', 'Sheet1!A2'
      );
    end
    $body$
  $test$,
  '23514',
  'approval snapshot lines must exactly copy active weekly menu lines',
  'a snapshot cannot cross-wire a stable line from another Weekly Menu'
);

select throws_ok(
  $test$
    do $body$
    begin
      insert into atlas_planning.weekly_menu_approval_snapshots (
        weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version,
        approved_by_actor_id, approved_at
      ) values (
        '9a000000-0000-0000-0000-000000000326',
        '9a000000-0000-0000-0000-000000000300', 1,
        '9a000000-0000-0000-0000-000000000002',
        timestamptz '2026-07-19 12:00:00+07'
      );

      insert into atlas_planning.weekly_menu_approval_snapshot_lines (
        weekly_menu_approval_snapshot_line_id,
        weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version,
        weekly_menu_line_id, school_id, service_date, menu_slot_code, dish_id,
        source_row_reference
      ) values (
        '9a000000-0000-0000-0000-000000000327',
        '9a000000-0000-0000-0000-000000000326',
        '9a000000-0000-0000-0000-000000000300', 1,
        '9a000000-0000-0000-0000-000000000310',
        '9a000000-0000-0000-0000-000000000120', date '2026-07-28', 'soup',
        '9a000000-0000-0000-0000-000000000130', 'Sheet2!A2'
      );

      update atlas_planning.weekly_menus
      set weekly_menu_status = 'APPROVED',
          latest_approved_by_actor_id = '9a000000-0000-0000-0000-000000000002',
          latest_approved_at = timestamptz '2026-07-19 12:00:00+07',
          latest_approval_snapshot_id = '9a000000-0000-0000-0000-000000000326'
      where weekly_menu_id = '9a000000-0000-0000-0000-000000000300';

      set constraints all immediate;
    end
    $body$
  $test$,
  '23514',
  'approval snapshot must contain every active weekly menu line exactly once',
  'approval fails when any ACTIVE line is missing from the snapshot'
);

select lives_ok(
  $test$
    do $body$
    begin
      insert into atlas_planning.weekly_menu_approval_snapshots (
        weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version,
        approved_by_actor_id, approved_at
      ) values (
        '9a000000-0000-0000-0000-000000000330',
        '9a000000-0000-0000-0000-000000000300', 1,
        '9a000000-0000-0000-0000-000000000002',
        timestamptz '2026-07-19 12:00:00+07'
      );

      insert into atlas_planning.weekly_menu_approval_snapshot_lines (
        weekly_menu_approval_snapshot_line_id,
        weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version,
        weekly_menu_line_id, school_id, service_date, menu_slot_code, dish_id,
        source_row_reference
      ) values
        (
          '9a000000-0000-0000-0000-000000000331',
          '9a000000-0000-0000-0000-000000000330',
          '9a000000-0000-0000-0000-000000000300', 1,
          '9a000000-0000-0000-0000-000000000310',
          '9a000000-0000-0000-0000-000000000120', date '2026-07-28', 'soup',
          '9a000000-0000-0000-0000-000000000130', 'Sheet2!A2'
        ),
        (
          '9a000000-0000-0000-0000-000000000332',
          '9a000000-0000-0000-0000-000000000330',
          '9a000000-0000-0000-0000-000000000300', 1,
          '9a000000-0000-0000-0000-000000000311',
          '9a000000-0000-0000-0000-000000000121', date '2026-07-29', 'savory',
          '9a000000-0000-0000-0000-000000000131', 'Sheet2!B2'
        );

      update atlas_planning.weekly_menus
      set weekly_menu_status = 'APPROVED',
          latest_approved_by_actor_id = '9a000000-0000-0000-0000-000000000002',
          latest_approved_at = timestamptz '2026-07-19 12:00:00+07',
          latest_approval_snapshot_id = '9a000000-0000-0000-0000-000000000330'
      where weekly_menu_id = '9a000000-0000-0000-0000-000000000300';

      set constraints all immediate;
      set constraints all deferred;
    end
    $body$
  $test$,
  'a complete snapshot with every and only ACTIVE lines approves atomically'
);

select is(
  (
    select count(*)::integer
    from atlas_planning.weekly_menu_approval_snapshot_lines
    where weekly_menu_approval_snapshot_id = '9a000000-0000-0000-0000-000000000330'
  ),
  2,
  'the complete second-menu snapshot excludes its INVALID line'
);

select throws_ok(
  $$
    update atlas_planning.weekly_menus
    set weekly_menu_status = 'REOPENED',
        version = version + 1,
        latest_approved_by_actor_id = '9a000000-0000-0000-0000-000000000003',
        latest_approved_at = transaction_timestamp()
    where weekly_menu_id = '9a000000-0000-0000-0000-000000000300'
  $$,
  '23514',
  'established weekly menu approval evidence is immutable across later transitions',
  'reopen cannot rewrite established lifecycle actor or timestamp evidence'
);

select throws_ok(
  $$
    update atlas_planning.weekly_menus
    set weekly_menu_status = 'REOPENED',
        version = version + 1,
        latest_approval_snapshot_id = '9a000000-0000-0000-0000-000000000220'
    where weekly_menu_id = '9a000000-0000-0000-0000-000000000300'
  $$,
  '23514',
  'established weekly menu approval evidence is immutable across later transitions',
  'reopen cannot reassign established snapshot evidence'
);

select throws_ok(
  $$
    update atlas_planning.weekly_menus
    set weekly_menu_status = 'REOPENED',
        version = version + 1,
        source_name = 'smuggled approved reopen source'
    where weekly_menu_id = '9a000000-0000-0000-0000-000000000300'
  $$,
  '23514',
  'weekly menu import and source evidence may change only during same-state DRAFT or REOPENED refreshes',
  'an APPROVED-to-REOPENED transition cannot rewrite source evidence'
);

select lives_ok(
  $$
    update atlas_planning.weekly_menus
    set weekly_menu_status = 'REOPENED',
        version = version + 1
    where weekly_menu_id = '9a000000-0000-0000-0000-000000000300'
  $$,
  'APPROVED advances legitimately to REOPENED with immutable evidence unchanged'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'atlas_planning.weekly_menu_approval_snapshots'::regclass
      and conname = 'weekly_menu_approval_snapshots_menu_version_key'
      and contype = 'u'
  ),
  'one immutable approval snapshot is allowed per Weekly Menu version'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'atlas_planning.weekly_menu_approval_snapshot_lines'::regclass
      and conname = 'weekly_menu_approval_snapshot_lines_line_key'
      and contype = 'u'
  ),
  'one snapshot line is allowed per stable Weekly Menu line'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'atlas_planning.weekly_menu_approval_snapshot_lines'::regclass
      and conname = 'weekly_menu_approval_snapshot_lines_assignment_key'
      and contype = 'u'
  ),
  'approval snapshots prohibit duplicate school/date/slot assignments'
);

select throws_ok(
  $$
    update atlas_planning.weekly_menus
    set weekly_menu_status = 'REOPENED'
    where weekly_menu_id = '9a000000-0000-0000-0000-000000000400'
  $$,
  '23514',
  'weekly menu lifecycle transition is invalid',
  'a DRAFT Weekly Menu cannot skip directly to REOPENED'
);

select throws_ok(
  $$
    delete from atlas_planning.weekly_menus
    where weekly_menu_id = '9a000000-0000-0000-0000-000000000300'
  $$,
  '23514',
  'validated or historically approved weekly menus cannot be deleted',
  'historically approved stable roots cannot be deleted'
);

select throws_ok(
  $$
    delete from atlas_admin.schools
    where school_id = '9a000000-0000-0000-0000-000000000120'
  $$,
  '23503',
  'update or delete on table "schools" violates foreign key constraint "weekly_menu_lines_school_fkey" on table "weekly_menu_lines"',
  'School references use ON DELETE RESTRICT'
);

select throws_ok(
  $$
    delete from atlas_admin.dishes
    where dish_id = '9a000000-0000-0000-0000-000000000130'
  $$,
  '23503',
  'update or delete on table "dishes" violates foreign key constraint "weekly_menu_lines_dish_fkey" on table "weekly_menu_lines"',
  'Dish references use ON DELETE RESTRICT'
);

select ok(
  (
    select count(*) = 14 and bool_and(con.confdeltype = 'r')
    from pg_constraint con
    where con.conname in (
      'weekly_menus_imported_by_actor_fkey',
      'weekly_menus_latest_approved_by_actor_fkey',
      'weekly_menus_latest_approval_snapshot_fkey',
      'weekly_menu_lines_menu_fkey',
      'weekly_menu_lines_school_fkey',
      'weekly_menu_lines_dish_fkey',
      'weekly_menu_lines_created_by_actor_fkey',
      'weekly_menu_lines_updated_by_actor_fkey',
      'weekly_menu_approval_snapshots_menu_fkey',
      'weekly_menu_approval_snapshots_approved_by_actor_fkey',
      'weekly_menu_approval_snapshot_lines_snapshot_fkey',
      'weekly_menu_approval_snapshot_lines_menu_line_fkey',
      'weekly_menu_approval_snapshot_lines_school_fkey',
      'weekly_menu_approval_snapshot_lines_dish_fkey'
    )
  ),
  'every H0A3a operational foreign key uses ON DELETE RESTRICT'
);

select ok(
  not exists (
    select 1
    from pg_constraint con
    where con.conrelid in (
      'atlas_planning.weekly_menus'::regclass,
      'atlas_planning.weekly_menu_lines'::regclass,
      'atlas_planning.weekly_menu_approval_snapshots'::regclass,
      'atlas_planning.weekly_menu_approval_snapshot_lines'::regclass
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
  'every H0A3a foreign key has a matching leading-column index'
);

select ok(
  not exists (
    select 1
    from pg_class c
    where c.oid in (
      'atlas_planning.weekly_menus'::regclass,
      'atlas_planning.weekly_menu_lines'::regclass,
      'atlas_planning.weekly_menu_approval_snapshots'::regclass,
      'atlas_planning.weekly_menu_approval_snapshot_lines'::regclass
    )
      and (not c.relrowsecurity or not c.relforcerowsecurity)
  ),
  'all four H0A3a relations have RLS enabled and forced'
);

select is(
  (
    select jsonb_agg(
      jsonb_build_object(
        'relation', policy.polrelid::regclass::text,
        'name', policy.polname,
        'command', policy.polcmd,
        'permissive', policy.polpermissive,
        'roles', (
          select jsonb_agg(role.rolname order by role.rolname)
          from unnest(policy.polroles) policy_role(role_oid)
          left join pg_roles role on role.oid = policy_role.role_oid
        ),
        'using', pg_get_expr(policy.polqual, policy.polrelid),
        'with_check', pg_get_expr(policy.polwithcheck, policy.polrelid)
      )
      order by policy.polrelid::regclass::text, policy.polname
    )
    from pg_policy policy
    where policy.polrelid in (
      'atlas_planning.weekly_menus'::regclass,
      'atlas_planning.weekly_menu_lines'::regclass,
      'atlas_planning.weekly_menu_approval_snapshots'::regclass,
      'atlas_planning.weekly_menu_approval_snapshot_lines'::regclass
    )
      and policy.polroles = array['atlas_planning_materialization_runtime'::regrole::oid]
  ),
  (
    select jsonb_agg(
      jsonb_build_object(
        'relation', expected.relation_name,
        'name', 'pa_06e_h0cb_materialization_select',
        'command', 'r',
        'permissive', true,
        'roles', jsonb_build_array('atlas_planning_materialization_runtime'),
        'using', 'true',
        'with_check', null
      )
      order by expected.relation_name
    )
    from (
      values
        ('atlas_planning.weekly_menus'),
        ('atlas_planning.weekly_menu_lines'),
        ('atlas_planning.weekly_menu_approval_snapshots'),
        ('atlas_planning.weekly_menu_approval_snapshot_lines')
    ) expected(relation_name)
  ),
  'H0A3a retains exactly four materialization-runtime permissive SELECT policies'
);

select is(
  (
    select count(*)::integer
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'atlas_planning'
      and c.relkind = 'S'
      and c.relname like 'weekly_menu%'
  ),
  0,
  'database-generated UUID identities add no H0A3a sequences or sequence grants'
);

select is(
  (
    select array_agg(owner.rolname order by c.relname)::text[]
    from pg_class c
    join pg_roles owner on owner.oid = c.relowner
    where c.oid in (
      'atlas_planning.weekly_menus'::regclass,
      'atlas_planning.weekly_menu_lines'::regclass,
      'atlas_planning.weekly_menu_approval_snapshots'::regclass,
      'atlas_planning.weekly_menu_approval_snapshot_lines'::regclass
    )
  ),
  array['atlas_owner', 'atlas_owner', 'atlas_owner', 'atlas_owner']::text[],
  'all four H0A3a relations are owned by atlas_owner'
);

select is(
  (
    select count(*)::integer
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    join pg_roles owner on owner.oid = p.proowner
    where n.nspname = 'atlas_planning'
      and p.proname like 'pa_06e_h0a3a_%'
      and owner.rolname = 'atlas_owner'
  ),
  4,
  'the four minimum private H0A3a guard functions are owned by atlas_owner'
);

select ok(
  not exists (
    select 1
    from pg_class c
    cross join lateral aclexplode(
      coalesce(c.relacl, acldefault('r', c.relowner))
    ) relation_acl
    left join pg_roles grantee on grantee.oid = relation_acl.grantee
    where c.oid in (
      'atlas_planning.weekly_menus'::regclass,
      'atlas_planning.weekly_menu_lines'::regclass,
      'atlas_planning.weekly_menu_approval_snapshots'::regclass,
      'atlas_planning.weekly_menu_approval_snapshot_lines'::regclass
    )
      and (
        relation_acl.grantee = 0
        or grantee.rolname in ('anon', 'authenticated', 'service_role')
      )
      and relation_acl.privilege_type in ('SELECT', 'INSERT', 'UPDATE', 'DELETE')
  ),
  'PUBLIC and API roles have no H0A3a relation privileges'
);

select ok(
  not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    cross join lateral aclexplode(
      coalesce(p.proacl, acldefault('f', p.proowner))
    ) function_acl
    left join pg_roles grantee on grantee.oid = function_acl.grantee
    where n.nspname = 'atlas_planning'
      and p.proname like 'pa_06e_h0a3a_%'
      and (
        function_acl.grantee = 0
        or grantee.rolname in ('anon', 'authenticated', 'service_role')
      )
      and function_acl.privilege_type = 'EXECUTE'
  ),
  'PUBLIC and API roles cannot execute private H0A3a guard functions'
);

select ok(
  not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_planning'
      and p.proname like 'pa_06e_h0a3a_%'
      and not coalesce(p.proconfig, array[]::text[]) @> array['search_path=""']
  ),
  'every private H0A3a guard function has a hardened empty search path'
);

select * from finish();

rollback;
