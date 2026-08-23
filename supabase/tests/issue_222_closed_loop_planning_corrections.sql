begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = pg_catalog, public, extensions;

select plan(47);

-- Contract and privilege surface: two public APIs, existing capabilities only.
select is(
  (
    select array_agg(p.proname order by p.proname)::text[]
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
      and p.proname in (
        'get_planning_source_correction_impact',
        'prepare_planning_source_correction'
      )
  ),
  array[
    'get_planning_source_correction_impact',
    'prepare_planning_source_correction'
  ]::text[],
  'I222-01 exact two-function public correction surface exists'
);
select is(
  (
    select array_agg(pg_get_userbyid(p.proowner) order by p.proname)::text[]
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
      and p.proname in (
        'get_planning_source_correction_impact',
        'prepare_planning_source_correction'
      )
  ),
  array['atlas_read_runtime', 'atlas_need_generation_runtime']::text[],
  'I222-02 read and command retain least-privileged existing runtimes'
);
select ok(
  (
    select bool_and(p.prosecdef and p.proconfig = array['search_path=""'])
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
      and p.proname in (
        'get_planning_source_correction_impact',
        'prepare_planning_source_correction'
      )
  ),
  'I222-03 both boundaries are hardened security definers'
);
select ok(
  (
    select bool_and(
      has_function_privilege('authenticated', p.oid, 'EXECUTE')
      and not has_function_privilege('anon', p.oid, 'EXECUTE')
      and not has_function_privilege('service_role', p.oid, 'EXECUTE')
      and not has_function_privilege('public', p.oid, 'EXECUTE')
    )
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
      and p.proname in (
        'get_planning_source_correction_impact',
        'prepare_planning_source_correction'
      )
  ),
  'I222-04 only authenticated receives public execution'
);
select is(
  (
    select count(*) from atlas_core.capabilities
    where capability_code like 'planning.%correction%'
  ),
  0::bigint,
  'I222-05 no correction-specific capability was introduced'
);
select is(
  (
    select count(*) from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname like 'atlas\_%' escape '\'
      and c.relkind = 'r'
      and c.relname like 'issue_222%'
  ),
  0::bigint,
  'I222-06 no convenience persistence was introduced'
);

create function pg_temp.menu_payload(
  changed_dates date[] default '{}'::date[],
  reference_prefix text default 'proposed'
)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'week_start', '2027-05-03',
    'source_type', 'MANUAL',
    'source_name', 'Atlas',
    'rows', coalesce(pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'school_id', line.school_id,
        'service_date', line.service_date,
        'menu_slot_code', line.menu_slot_code,
        'dish_id', case when line.service_date = any(changed_dates)
          then 'a2220000-0000-0000-0000-000000000308'::uuid
          else line.dish_id end,
        'source_row_reference', reference_prefix || ':' || line.service_date
      ) order by line.service_date
    ), '[]'::jsonb)
  )
  from atlas_planning.weekly_menu_approval_snapshot_lines line
  where line.weekly_menu_approval_snapshot_id =
    'a2221000-0000-0000-0000-000000000102';
$$;

create function pg_temp.correction_request(
  command_id uuid,
  idempotency_key text,
  run_id uuid,
  run_version bigint,
  batch_id uuid,
  batch_version bigint,
  auth_subject uuid default
    'a2220000-0000-0000-0000-000000000101'::uuid
)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'contract_version', 'PLANNING-CORRECTION.v1',
    'command_id', command_id,
    'correlation_id', pg_catalog.gen_random_uuid(),
    'idempotency_key', idempotency_key,
    'expected_version', run_version,
    'requested_by_auth_subject', auth_subject,
    'requested_at', pg_catalog.transaction_timestamp(),
    'reason_code', 'PLANNING_SOURCE_CORRECTION_PREPARED',
    'reason_note', 'Issue 222 governed correction acceptance',
    'payload', pg_catalog.jsonb_build_object(
      'need_generation_run_id', run_id,
      'confirmed_need_batch_id', batch_id,
      'expected_confirmed_need_batch_version', batch_version
    )
  );
$$;

-- A compact, rolled-back fixture. Replica mode is used only to establish
-- already-released historical shapes; all API execution runs with triggers on.
set local session_replication_role = replica;

insert into atlas_core.actors (actor_id, actor_type, display_name)
values
  ('a2220000-0000-0000-0000-000000000001', 'HUMAN', 'Issue 222 Need operator'),
  ('a2220000-0000-0000-0000-000000000002', 'HUMAN', 'Issue 222 release operator');
insert into atlas_core.actor_auth_subjects
  (actor_auth_subject_id, actor_id, auth_subject_id)
values
  (
    'a2220000-0000-0000-0000-000000000011',
    'a2220000-0000-0000-0000-000000000001',
    'a2220000-0000-0000-0000-000000000101'
  ),
  (
    'a2220000-0000-0000-0000-000000000012',
    'a2220000-0000-0000-0000-000000000002',
    'a2220000-0000-0000-0000-000000000102'
  );
insert into atlas_core.roles (role_id, role_code, role_name)
values
  (
    'a2220000-0000-0000-0000-000000000201',
    'issue222.need_operator', 'Issue 222 Need operator'
  ),
  (
    'a2220000-0000-0000-0000-000000000202',
    'issue222.release_operator', 'Issue 222 release operator'
  );
insert into atlas_core.role_capabilities (role_id, capability_id)
select 'a2220000-0000-0000-0000-000000000201', capability_id
from atlas_core.capabilities
where capability_code in (
  'planning.inputs.read',
  'planning.need_generation.write',
  'planning.weekly_menu.write'
);
insert into atlas_core.role_capabilities (role_id, capability_id)
select 'a2220000-0000-0000-0000-000000000202', capability_id
from atlas_core.capabilities
where capability_code in (
  'planning.need_generation.write',
  'confirmed_need_release.release'
);
insert into atlas_core.actor_role_memberships (actor_id, role_id)
values
  (
    'a2220000-0000-0000-0000-000000000001',
    'a2220000-0000-0000-0000-000000000201'
  ),
  (
    'a2220000-0000-0000-0000-000000000002',
    'a2220000-0000-0000-0000-000000000202'
  );
insert into atlas_core.actor_scopes (actor_id, scope_kind)
values
  ('a2220000-0000-0000-0000-000000000001', 'GLOBAL'),
  ('a2220000-0000-0000-0000-000000000002', 'GLOBAL');

insert into atlas_admin.customers
  (customer_id, customer_code, customer_name, customer_type)
values (
  'a2220000-0000-0000-0000-000000000301',
  'issue222-customer', 'Issue 222 customer', 'SCHOOL_CATERING'
);
insert into atlas_admin.delivery_locations
  (delivery_location_id, customer_id, location_code, location_name, address_text)
values (
  'a2220000-0000-0000-0000-000000000302',
  'a2220000-0000-0000-0000-000000000301',
  'issue222-kitchen', 'Issue 222 kitchen', 'Fixture'
);
insert into atlas_admin.school_types
  (school_type_id, school_type_code, school_type_name)
values (
  'a2220000-0000-0000-0000-000000000303',
  'issue222-type', 'Issue 222 type'
);
insert into atlas_admin.schools (
  school_id, customer_id, school_code, school_name, school_type_id,
  default_delivery_location_id, display_order
) values (
  'a2220000-0000-0000-0000-000000000304',
  'a2220000-0000-0000-0000-000000000301',
  'issue222-school', 'Issue 222 school',
  'a2220000-0000-0000-0000-000000000303',
  'a2220000-0000-0000-0000-000000000302', 1
);
insert into atlas_admin.units (unit_id, unit_code, unit_name, dimension_code)
values (
  'a2220000-0000-0000-0000-000000000305',
  'issue222-kg', 'Issue 222 kg', 'mass'
);
insert into atlas_admin.ingredients
  (ingredient_id, ingredient_code, ingredient_name, purchase_unit_id)
values (
  'a2220000-0000-0000-0000-000000000306',
  'issue222-rice', 'Issue 222 rice',
  'a2220000-0000-0000-0000-000000000305'
);
insert into atlas_admin.suppliers
  (supplier_id, supplier_code, supplier_name)
values (
  'a2220000-0000-0000-0000-000000000310',
  'issue222-supplier', 'Issue 222 supplier'
);
insert into atlas_admin.dishes
  (dish_id, dish_code, dish_name, dish_status, display_order)
values
  ('a2220000-0000-0000-0000-000000000307', 'issue222-dish-a', 'Dish A', 'ACTIVE', 1),
  ('a2220000-0000-0000-0000-000000000308', 'issue222-dish-b', 'Dish B', 'ACTIVE', 2);
insert into atlas_planning.pantry_need_purposes (
  pantry_need_purpose_id, purpose_code, purpose_name_vi,
  purpose_description, note_rule, display_order
) values (
  'a2220000-0000-0000-0000-000000000309',
  'issue222_purpose', 'Bổ sung', 'Fixture', 'OPTIONAL', 1
);

insert into atlas_planning.weekly_menus (
  weekly_menu_id, week_start, week_end, source_type, source_name,
  source_signature, weekly_menu_status, row_count, imported_by_actor_id,
  latest_approved_by_actor_id, latest_approved_at, latest_approval_snapshot_id,
  version
) values (
  'a2221000-0000-0000-0000-000000000101',
  '2027-05-03', '2027-05-09', 'MANUAL', 'Atlas', repeat('a', 64),
  'APPROVED', 7, 'a2220000-0000-0000-0000-000000000001',
  'a2220000-0000-0000-0000-000000000001',
  pg_catalog.transaction_timestamp(),
  'a2221000-0000-0000-0000-000000000102', 1
);
insert into atlas_planning.weekly_menu_approval_snapshots (
  weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version,
  approved_by_actor_id, approved_at
) values (
  'a2221000-0000-0000-0000-000000000102',
  'a2221000-0000-0000-0000-000000000101', 1,
  'a2220000-0000-0000-0000-000000000001',
  pg_catalog.transaction_timestamp()
);
insert into atlas_planning.weekly_menu_approval_snapshot_lines (
  weekly_menu_approval_snapshot_line_id, weekly_menu_approval_snapshot_id,
  weekly_menu_id, weekly_menu_version, weekly_menu_line_id, school_id,
  service_date, menu_slot_code, dish_id, source_row_reference
)
select
  ('a2221000-0000-0000-0000-' || pg_catalog.lpad(n::text, 12, '0'))::uuid,
  'a2221000-0000-0000-0000-000000000102',
  'a2221000-0000-0000-0000-000000000101', 1,
  ('a2221100-0000-0000-0000-' || pg_catalog.lpad(n::text, 12, '0'))::uuid,
  'a2220000-0000-0000-0000-000000000304',
  '2027-05-02'::date + n, 'lunch',
  'a2220000-0000-0000-0000-000000000307', 'current:' || n
from pg_catalog.generate_series(1, 7) n;

insert into atlas_planning.attendance_batches (
  attendance_batch_id, period_start, period_end, source_type, source_name,
  source_signature, attendance_status, row_count, imported_by_actor_id,
  latest_approved_by_actor_id, latest_approved_at, latest_approval_snapshot_id
) values (
  'a2221000-0000-0000-0000-000000000201',
  '2027-05-03', '2027-05-09', 'MANUAL', 'Atlas', repeat('b', 64),
  'APPROVED', 1, 'a2220000-0000-0000-0000-000000000001',
  'a2220000-0000-0000-0000-000000000001',
  pg_catalog.transaction_timestamp(),
  'a2221000-0000-0000-0000-000000000202'
);
insert into atlas_planning.attendance_approval_snapshots (
  attendance_approval_snapshot_id, attendance_batch_id, attendance_version,
  approved_by_actor_id, approved_at
) values (
  'a2221000-0000-0000-0000-000000000202',
  'a2221000-0000-0000-0000-000000000201', 1,
  'a2220000-0000-0000-0000-000000000001',
  pg_catalog.transaction_timestamp()
);
insert into atlas_planning.attendance_approval_snapshot_lines (
  attendance_approval_snapshot_line_id, attendance_approval_snapshot_id,
  attendance_batch_id, attendance_version, attendance_line_id, school_id,
  service_date, student_portions, teacher_portions, source_row_reference
) values (
  'a2221000-0000-0000-0000-000000000203',
  'a2221000-0000-0000-0000-000000000202',
  'a2221000-0000-0000-0000-000000000201', 1,
  'a2221000-0000-0000-0000-000000000204',
  'a2220000-0000-0000-0000-000000000304',
  '2027-05-03', 100, 10, 'current'
);

insert into atlas_planning.pantry_need_batches (
  pantry_need_batch_id, week_start, pantry_need_batch_status,
  version, source_signature, requesting_actor_id,
  latest_approved_by_actor_id, latest_approved_at, latest_approval_snapshot_id
) values (
  'a2221000-0000-0000-0000-000000000301',
  '2027-05-03', 'APPROVED', 1, repeat('c', 64),
  'a2220000-0000-0000-0000-000000000001',
  'a2220000-0000-0000-0000-000000000001',
  pg_catalog.transaction_timestamp(),
  'a2221000-0000-0000-0000-000000000302'
);
insert into atlas_planning.pantry_need_approval_snapshots (
  pantry_need_approval_snapshot_id, pantry_need_batch_id,
  approved_batch_version, approved_by_actor_id, approved_at,
  source_signature, no_additions_confirmed, line_count
) values (
  'a2221000-0000-0000-0000-000000000302',
  'a2221000-0000-0000-0000-000000000301', 1,
  'a2220000-0000-0000-0000-000000000001',
  pg_catalog.transaction_timestamp(), repeat('c', 64), false, 1
);
insert into atlas_planning.pantry_need_approval_snapshot_lines (
  pantry_need_approval_snapshot_id, pantry_need_line_id, service_date,
  school_id, school_code_snapshot, school_name_snapshot,
  delivery_location_id, delivery_location_code_snapshot,
  delivery_location_name_snapshot, delivery_location_address_snapshot,
  ingredient_id, ingredient_code_snapshot, ingredient_name_snapshot,
  unit_id, unit_code_snapshot, unit_name_snapshot,
  pantry_need_purpose_id, purpose_code_snapshot, purpose_name_snapshot,
  purpose_description_snapshot, purpose_note_rule_snapshot,
  requested_quantity, note, source_request_reference, source_row_reference
) values (
  'a2221000-0000-0000-0000-000000000302',
  'a2221000-0000-0000-0000-000000000303', '2027-05-03',
  'a2220000-0000-0000-0000-000000000304', 'school', 'School',
  'a2220000-0000-0000-0000-000000000302', 'kitchen', 'Kitchen', 'Fixture',
  'a2220000-0000-0000-0000-000000000306', 'rice', 'Rice',
  'a2220000-0000-0000-0000-000000000305', 'kg', 'Kg',
  'a2220000-0000-0000-0000-000000000309', 'purpose', 'Bổ sung',
  'Fixture', 'OPTIONAL', 2, 'old note', 'old request', 'old row'
);

insert into atlas_planning.need_generation_calculation_contracts (
  need_generation_calculation_contract_id, contract_code,
  current_revision_id, version
) values (
  'a2221000-0000-0000-0000-000000000401',
  'school_catering_proportional_per_basis',
  'a2221000-0000-0000-0000-000000000402', 1
);
insert into atlas_planning.need_generation_calculation_contract_revisions (
  need_generation_calculation_contract_revision_id,
  need_generation_calculation_contract_id, revision_number,
  formula_kind, quantity_precision, quantity_scale,
  factor_precision, factor_scale, final_coercion_mode,
  approved_by_actor_id, approved_at
) values (
  'a2221000-0000-0000-0000-000000000402',
  'a2221000-0000-0000-0000-000000000401', 1,
  'STUDENT_TEACHER_PORTIONS_X_RECIPE_QTY_DIV_BASIS', 20, 6, 24, 12,
  'POSTGRES_NUMERIC_SCALE_HALF_AWAY_FROM_ZERO',
  'a2220000-0000-0000-0000-000000000001', now()
);

-- Eight active daily/range chains establish every policy branch. All source
-- lineage identifiers are stable history and need not be rewritten.
insert into atlas_planning.planning_input_sets (
  planning_input_set_id, period_start, period_end, readiness_status,
  current_evaluation_id
) values
  ('a2222100-0000-0000-0000-000000000204', '2027-05-04', '2027-05-04', 'READY', 'a2222200-0000-0000-0000-000000000204'),
  ('a2222100-0000-0000-0000-000000000205', '2027-05-05', '2027-05-05', 'READY', 'a2222200-0000-0000-0000-000000000205'),
  ('a2222100-0000-0000-0000-000000000206', '2027-05-05', '2027-05-06', 'READY', 'a2222200-0000-0000-0000-000000000206'),
  ('a2222100-0000-0000-0000-000000000216', '2027-05-06', '2027-05-08', 'READY', 'a2222200-0000-0000-0000-000000000216'),
  ('a2222100-0000-0000-0000-000000000207', '2027-05-07', '2027-05-07', 'READY', 'a2222200-0000-0000-0000-000000000207'),
  ('a2222100-0000-0000-0000-000000000208', '2027-05-08', '2027-05-08', 'READY', 'a2222200-0000-0000-0000-000000000208'),
  ('a2222100-0000-0000-0000-000000000209', '2027-05-09', '2027-05-09', 'READY', 'a2222200-0000-0000-0000-000000000209'),
  ('a2222100-0000-0000-0000-000000000210', '2027-05-10', '2027-05-10', 'READY', 'a2222200-0000-0000-0000-000000000210');

insert into atlas_planning.planning_input_evaluations (
  planning_input_evaluation_id, planning_input_set_id, evaluation_version,
  evaluation_result, weekly_menu_id, weekly_menu_version,
  weekly_menu_approval_snapshot_id, attendance_batch_id, attendance_version,
  attendance_approval_snapshot_id, blocking_issue_count, warning_count,
  evaluated_by_actor_id, evaluated_at
)
select
  ('a2222200-0000-0000-0000-' || right(s.planning_input_set_id::text, 12))::uuid,
  s.planning_input_set_id, 1, 'READY',
  'a2221000-0000-0000-0000-000000000101', 1,
  'a2221000-0000-0000-0000-000000000102',
  'a2221000-0000-0000-0000-000000000201', 1,
  'a2221000-0000-0000-0000-000000000202', 0, 0,
  'a2220000-0000-0000-0000-000000000001', now()
from atlas_planning.planning_input_sets s
where s.planning_input_set_id::text like 'a2222100-%';

insert into atlas_planning.need_generation_runs (
  need_generation_run_id, planning_input_set_id, planning_input_evaluation_id,
  evaluation_version, period_start, period_end, attempt_ordinal,
  input_snapshot_id, run_status, version, generated_line_count,
  blocking_issue_count, warning_count, generated_by_actor_id,
  generated_at, released_by_actor_id, released_at, updated_at
) values
  ('a2222000-0000-0000-0000-000000000204', 'a2222100-0000-0000-0000-000000000204', 'a2222200-0000-0000-0000-000000000204', 1, '2027-05-04', '2027-05-04', 1, 'a2222300-0000-0000-0000-000000000204', 'GENERATED', 1, 0, 0, 0, 'a2220000-0000-0000-0000-000000000001', now(), null, null, now()),
  ('a2222000-0000-0000-0000-000000000205', 'a2222100-0000-0000-0000-000000000205', 'a2222200-0000-0000-0000-000000000205', 1, '2027-05-05', '2027-05-05', 1, 'a2222300-0000-0000-0000-000000000205', 'GENERATED', 1, 0, 0, 0, 'a2220000-0000-0000-0000-000000000001', now(), null, null, now()),
  ('a2222000-0000-0000-0000-000000000206', 'a2222100-0000-0000-0000-000000000206', 'a2222200-0000-0000-0000-000000000206', 1, '2027-05-05', '2027-05-06', 1, 'a2222300-0000-0000-0000-000000000206', 'GENERATED', 1, 0, 0, 0, 'a2220000-0000-0000-0000-000000000001', now(), null, null, now()),
  ('a2222000-0000-0000-0000-000000000216', 'a2222100-0000-0000-0000-000000000216', 'a2222200-0000-0000-0000-000000000216', 1, '2027-05-06', '2027-05-08', 1, 'a2222300-0000-0000-0000-000000000216', 'GENERATED', 1, 0, 0, 0, 'a2220000-0000-0000-0000-000000000001', now(), null, null, now()),
  ('a2222000-0000-0000-0000-000000000207', 'a2222100-0000-0000-0000-000000000207', 'a2222200-0000-0000-0000-000000000207', 1, '2027-05-07', '2027-05-07', 1, 'a2222300-0000-0000-0000-000000000207', 'GENERATED', 1, 0, 0, 0, 'a2220000-0000-0000-0000-000000000001', now(), null, null, now()),
  ('a2222000-0000-0000-0000-000000000208', 'a2222100-0000-0000-0000-000000000208', 'a2222200-0000-0000-0000-000000000208', 1, '2027-05-08', '2027-05-08', 1, 'a2222300-0000-0000-0000-000000000208', 'GENERATED', 1, 0, 0, 0, 'a2220000-0000-0000-0000-000000000001', now(), null, null, now()),
  ('a2222000-0000-0000-0000-000000000209', 'a2222100-0000-0000-0000-000000000209', 'a2222200-0000-0000-0000-000000000209', 1, '2027-05-09', '2027-05-09', 1, 'a2222300-0000-0000-0000-000000000209', 'GENERATED', 1, 0, 0, 0, 'a2220000-0000-0000-0000-000000000001', now(), null, null, now()),
  ('a2222000-0000-0000-0000-000000000210', 'a2222100-0000-0000-0000-000000000210', 'a2222200-0000-0000-0000-000000000210', 1, '2027-05-10', '2027-05-10', 1, 'a2222300-0000-0000-0000-000000000210', 'GENERATED', 1, 0, 0, 0, 'a2220000-0000-0000-0000-000000000001', now(), null, null, now());

update atlas_planning.need_generation_runs
set run_status = 'RELEASED_FOR_CONFIRMATION',
    validated_by_actor_id = 'a2220000-0000-0000-0000-000000000001',
    validated_at = generated_at,
    released_by_actor_id = 'a2220000-0000-0000-0000-000000000001',
    released_at = generated_at
where need_generation_run_id::text like 'a2222000-%';

insert into atlas_planning.need_generation_input_snapshots (
  need_generation_input_snapshot_id, need_generation_run_id,
  planning_input_set_id, planning_input_evaluation_id, evaluation_version,
  weekly_menu_id, weekly_menu_version, weekly_menu_approval_snapshot_id,
  attendance_batch_id, attendance_version, attendance_approval_snapshot_id,
  need_generation_calculation_contract_id,
  need_generation_calculation_contract_revision_id,
  calculation_contract_revision_number, captured_at
)
select
  ('a2222300-0000-0000-0000-' || right(r.need_generation_run_id::text, 12))::uuid,
  r.need_generation_run_id, r.planning_input_set_id,
  r.planning_input_evaluation_id, r.evaluation_version,
  'a2221000-0000-0000-0000-000000000101', 1,
  'a2221000-0000-0000-0000-000000000102',
  'a2221000-0000-0000-0000-000000000201', 1,
  'a2221000-0000-0000-0000-000000000202',
  c.need_generation_calculation_contract_id,
  cr.need_generation_calculation_contract_revision_id,
  cr.revision_number, now()
from atlas_planning.need_generation_runs r
cross join lateral (
  select need_generation_calculation_contract_id, current_revision_id, version
  from atlas_planning.need_generation_calculation_contracts
  order by contract_code
  limit 1
) c
join atlas_planning.need_generation_calculation_contract_revisions cr
  on cr.need_generation_calculation_contract_revision_id = c.current_revision_id
 and cr.need_generation_calculation_contract_id = c.need_generation_calculation_contract_id
 and cr.revision_number = c.version
where r.need_generation_run_id::text like 'a2222000-%';

insert into atlas_planning.need_generation_release_snapshots (
  need_generation_release_snapshot_id, need_generation_run_id,
  released_run_version, need_generation_input_snapshot_id,
  released_by_actor_id, released_at, generated_line_count,
  active_line_count, removed_line_count, blocking_issue_count, warning_count
)
select
  ('a2222400-0000-0000-0000-' || right(r.need_generation_run_id::text, 12))::uuid,
  r.need_generation_run_id, 1, r.input_snapshot_id,
  'a2220000-0000-0000-0000-000000000001', now(), 0, 0, 0, 0, 0
from atlas_planning.need_generation_runs r
where r.need_generation_run_id::text like 'a2222000-%';

insert into atlas_planning.confirmed_need_batches (
  confirmed_need_batch_id, period_start, period_end, batch_status, version,
  created_by_actor_id, released_by_actor_id, released_at, source_kind,
  origin_need_generation_run_id, origin_need_generation_run_version,
  origin_need_generation_release_snapshot_id,
  current_need_generation_run_id, current_need_generation_run_version,
  current_need_generation_release_snapshot_id,
  current_confirmed_need_approval_snapshot_id,
  current_confirmed_need_release_id
)
select
  ('a2223000-0000-0000-0000-' || right(run.need_generation_run_id::text, 12))::uuid,
  run.period_start, run.period_end,
  case when run.need_generation_run_id in (
    'a2222000-0000-0000-0000-000000000204'::uuid,
    'a2222000-0000-0000-0000-000000000206'::uuid,
    'a2222000-0000-0000-0000-000000000216'::uuid,
    'a2222000-0000-0000-0000-000000000208'::uuid
  ) then 'DRAFT_REVIEW' else 'RELEASED_FOR_PURCHASE_HANDOFF' end,
  case when run.need_generation_run_id in (
    'a2222000-0000-0000-0000-000000000204'::uuid,
    'a2222000-0000-0000-0000-000000000206'::uuid,
    'a2222000-0000-0000-0000-000000000216'::uuid,
    'a2222000-0000-0000-0000-000000000208'::uuid
  ) then 1 else 4 end,
  'a2220000-0000-0000-0000-000000000001',
  case when run.need_generation_run_id in (
    'a2222000-0000-0000-0000-000000000205'::uuid,
    'a2222000-0000-0000-0000-000000000207'::uuid,
    'a2222000-0000-0000-0000-000000000209'::uuid,
    'a2222000-0000-0000-0000-000000000210'::uuid
  ) then 'a2220000-0000-0000-0000-000000000001'::uuid end,
  case when run.need_generation_run_id in (
    'a2222000-0000-0000-0000-000000000205'::uuid,
    'a2222000-0000-0000-0000-000000000207'::uuid,
    'a2222000-0000-0000-0000-000000000209'::uuid,
    'a2222000-0000-0000-0000-000000000210'::uuid
  ) then now() end,
  'NEED_GENERATION', run.need_generation_run_id, 1,
  ('a2222400-0000-0000-0000-' || right(run.need_generation_run_id::text, 12))::uuid,
  run.need_generation_run_id, 1,
  ('a2222400-0000-0000-0000-' || right(run.need_generation_run_id::text, 12))::uuid,
  case when run.need_generation_run_id in (
    'a2222000-0000-0000-0000-000000000205'::uuid,
    'a2222000-0000-0000-0000-000000000207'::uuid,
    'a2222000-0000-0000-0000-000000000209'::uuid,
    'a2222000-0000-0000-0000-000000000210'::uuid
  ) then ('a2223100-0000-0000-0000-' || right(run.need_generation_run_id::text, 12))::uuid end,
  case when run.need_generation_run_id in (
    'a2222000-0000-0000-0000-000000000205'::uuid,
    'a2222000-0000-0000-0000-000000000207'::uuid,
    'a2222000-0000-0000-0000-000000000209'::uuid,
    'a2222000-0000-0000-0000-000000000210'::uuid
  ) then ('a2223200-0000-0000-0000-' || right(run.need_generation_run_id::text, 12))::uuid end
from atlas_planning.need_generation_runs run
where run.need_generation_run_id::text like 'a2222000-%';

insert into atlas_planning.confirmed_need_validation_attempts (
  confirmed_need_validation_attempt_id, confirmed_need_batch_id,
  attempt_number, source_kind, evaluated_batch_version,
  resulting_batch_version, prior_batch_status, resulting_batch_status,
  outcome, line_count, blocking_issue_count, warning_count,
  validation_fingerprint, evaluated_by_actor_id, evaluated_at,
  command_id, correlation_id, reason_code
)
select
  ('a2223300-0000-0000-0000-' || right(b.confirmed_need_batch_id::text, 12))::uuid,
  b.confirmed_need_batch_id, 1, 'NEED_GENERATION', 1, 2,
  'DRAFT_REVIEW', 'VALIDATED', 'VALIDATED', 0, 0, 0,
  repeat('d', 64), 'a2220000-0000-0000-0000-000000000001', now(),
  gen_random_uuid(), gen_random_uuid(), 'BATCH_VALIDATION_REQUESTED'
from atlas_planning.confirmed_need_batches b
where b.confirmed_need_batch_id in (
  'a2223000-0000-0000-0000-000000000205',
  'a2223000-0000-0000-0000-000000000207',
  'a2223000-0000-0000-0000-000000000209',
  'a2223000-0000-0000-0000-000000000210'
);

insert into atlas_planning.confirmed_need_approval_snapshots (
  confirmed_need_approval_snapshot_id, confirmed_need_batch_id,
  approved_version, approved_by_actor_id, approved_at, command_id, source_kind,
  confirmed_need_validation_attempt_id, validated_fact_fingerprint
)
select current_confirmed_need_approval_snapshot_id, confirmed_need_batch_id, 3,
  'a2220000-0000-0000-0000-000000000001', now(), gen_random_uuid(),
  'NEED_GENERATION',
  ('a2223300-0000-0000-0000-' || right(confirmed_need_batch_id::text, 12))::uuid,
  repeat('d', 64)
from atlas_planning.confirmed_need_batches
where confirmed_need_batch_id::text like 'a2223000-%'
  and current_confirmed_need_approval_snapshot_id is not null;
insert into atlas_planning.confirmed_need_releases (
  confirmed_need_release_id, confirmed_need_batch_id, source_kind,
  confirmed_need_approval_snapshot_id, source_approved_batch_version,
  resulting_released_batch_version, released_by_actor_id, released_at,
  command_id
)
select current_confirmed_need_release_id, confirmed_need_batch_id,
  'NEED_GENERATION', current_confirmed_need_approval_snapshot_id, 3, 4,
  'a2220000-0000-0000-0000-000000000001', now(), gen_random_uuid()
from atlas_planning.confirmed_need_batches
where confirmed_need_batch_id::text like 'a2223000-%'
  and current_confirmed_need_release_id is not null;

insert into atlas_planning.purchase_handoff_batches (
  purchase_handoff_batch_id, confirmed_need_batch_id, period_start,
  period_end, handoff_status, version, created_by_actor_id
) values
  ('a2224000-0000-0000-0000-000000000207', 'a2223000-0000-0000-0000-000000000207', '2027-05-07', '2027-05-07', 'RELEASED_TO_PROCUREMENT', 3, 'a2220000-0000-0000-0000-000000000001'),
  ('a2224000-0000-0000-0000-000000000208', 'a2223000-0000-0000-0000-000000000208', '2027-05-08', '2027-05-08', 'INVALIDATED', 2, 'a2220000-0000-0000-0000-000000000001'),
  ('a2224000-0000-0000-0000-000000000209', 'a2223000-0000-0000-0000-000000000209', '2027-05-09', '2027-05-09', 'INVALIDATED', 2, 'a2220000-0000-0000-0000-000000000001'),
  ('a2224000-0000-0000-0000-000000000210', 'a2223000-0000-0000-0000-000000000210', '2027-05-10', '2027-05-10', 'RELEASED_TO_PROCUREMENT', 3, 'a2220000-0000-0000-0000-000000000001');
insert into atlas_planning.purchase_handoff_revisions (
  purchase_handoff_revision_id, purchase_handoff_batch_id, revision_number,
  revision_kind, revision_status, is_current, released_by_actor_id, released_at
) values
  ('a2224000-0000-0000-0000-000000000247', 'a2224000-0000-0000-0000-000000000207', 1, 'BASE', 'RELEASED_TO_PROCUREMENT', true, 'a2220000-0000-0000-0000-000000000001', now()),
  ('a2224000-0000-0000-0000-000000000248', 'a2224000-0000-0000-0000-000000000208', 1, 'BASE', 'INVALIDATED', true, null, null),
  ('a2224000-0000-0000-0000-000000000249', 'a2224000-0000-0000-0000-000000000209', 1, 'BASE', 'INVALIDATED', true, null, null),
  ('a2224000-0000-0000-0000-000000000250', 'a2224000-0000-0000-0000-000000000210', 1, 'BASE', 'RELEASED_TO_PROCUREMENT', true, 'a2220000-0000-0000-0000-000000000001', now());
insert into atlas_planning.purchase_handoff_lines (
  purchase_handoff_line_id, purchase_handoff_batch_id, confirmed_need_line_id
) values
  ('a2224000-0000-0000-0000-000000000217', 'a2224000-0000-0000-0000-000000000207', 'a2224000-0000-0000-0000-000000000227'),
  ('a2224000-0000-0000-0000-000000000218', 'a2224000-0000-0000-0000-000000000208', 'a2224000-0000-0000-0000-000000000228'),
  ('a2224000-0000-0000-0000-000000000219', 'a2224000-0000-0000-0000-000000000209', 'a2224000-0000-0000-0000-000000000229'),
  ('a2224000-0000-0000-0000-000000000220', 'a2224000-0000-0000-0000-000000000210', 'a2224000-0000-0000-0000-000000000230');
insert into atlas_planning.purchase_handoff_line_revisions (
  purchase_handoff_line_revision_id, purchase_handoff_revision_id,
  purchase_handoff_line_id, confirmed_need_line_revision_id, ingredient_id,
  handoff_quantity, unit_id, service_date, delivery_location_id
) values
  ('a2224000-0000-0000-0000-000000000237', 'a2224000-0000-0000-0000-000000000247', 'a2224000-0000-0000-0000-000000000217', 'a2224000-0000-0000-0000-000000000257', 'a2220000-0000-0000-0000-000000000306', 1, 'a2220000-0000-0000-0000-000000000305', '2027-05-07', 'a2220000-0000-0000-0000-000000000302'),
  ('a2224000-0000-0000-0000-000000000238', 'a2224000-0000-0000-0000-000000000248', 'a2224000-0000-0000-0000-000000000218', 'a2224000-0000-0000-0000-000000000258', 'a2220000-0000-0000-0000-000000000306', 1, 'a2220000-0000-0000-0000-000000000305', '2027-05-08', 'a2220000-0000-0000-0000-000000000302'),
  ('a2224000-0000-0000-0000-000000000239', 'a2224000-0000-0000-0000-000000000249', 'a2224000-0000-0000-0000-000000000219', 'a2224000-0000-0000-0000-000000000259', 'a2220000-0000-0000-0000-000000000306', 1, 'a2220000-0000-0000-0000-000000000305', '2027-05-09', 'a2220000-0000-0000-0000-000000000302'),
  ('a2224000-0000-0000-0000-000000000240', 'a2224000-0000-0000-0000-000000000250', 'a2224000-0000-0000-0000-000000000220', 'a2224000-0000-0000-0000-000000000260', 'a2220000-0000-0000-0000-000000000306', 1, 'a2220000-0000-0000-0000-000000000305', '2027-05-10', 'a2220000-0000-0000-0000-000000000302');
insert into atlas_planning.purchase_demand_references (
  purchase_demand_reference_id, purchase_handoff_line_revision_id,
  confirmed_need_snapshot_line_id, wholesale_order_line_revision_id,
  approved_quantity, unit_id
) values
  ('a2224000-0000-0000-0000-000000000267', 'a2224000-0000-0000-0000-000000000237', 'a2224000-0000-0000-0000-000000000277', 'a2224000-0000-0000-0000-000000000287', 1, 'a2220000-0000-0000-0000-000000000305'),
  ('a2224000-0000-0000-0000-000000000268', 'a2224000-0000-0000-0000-000000000238', 'a2224000-0000-0000-0000-000000000278', 'a2224000-0000-0000-0000-000000000288', 1, 'a2220000-0000-0000-0000-000000000305'),
  ('a2224000-0000-0000-0000-000000000269', 'a2224000-0000-0000-0000-000000000239', 'a2224000-0000-0000-0000-000000000279', 'a2224000-0000-0000-0000-000000000289', 1, 'a2220000-0000-0000-0000-000000000305'),
  ('a2224000-0000-0000-0000-000000000270', 'a2224000-0000-0000-0000-000000000240', 'a2224000-0000-0000-0000-000000000280', 'a2224000-0000-0000-0000-000000000290', 1, 'a2220000-0000-0000-0000-000000000305');

insert into atlas_planning.dispatch_requirements (
  dispatch_requirement_id, source_of_need, customer_id,
  delivery_location_id, service_date, requirement_status, version
) values
  ('a2224000-0000-0000-0000-000000000407', 'WHOLESALE', 'a2220000-0000-0000-0000-000000000301', 'a2220000-0000-0000-0000-000000000302', '2027-05-07', 'RELEASED', 1),
  ('a2224000-0000-0000-0000-000000000408', 'WHOLESALE', 'a2220000-0000-0000-0000-000000000301', 'a2220000-0000-0000-0000-000000000302', '2027-05-08', 'CANCELLED', 1),
  ('a2224000-0000-0000-0000-000000000409', 'WHOLESALE', 'a2220000-0000-0000-0000-000000000301', 'a2220000-0000-0000-0000-000000000302', '2027-05-09', 'CANCELLED', 1),
  ('a2224000-0000-0000-0000-000000000410', 'WHOLESALE', 'a2220000-0000-0000-0000-000000000301', 'a2220000-0000-0000-0000-000000000302', '2027-05-10', 'RELEASED', 1);
insert into atlas_planning.dispatch_requirement_revisions (
  dispatch_requirement_revision_id, dispatch_requirement_id,
  purchase_handoff_revision_id, revision_number, revision_kind,
  revision_status, is_current, customer_name_snapshot,
  location_name_snapshot, address_snapshot, released_by_actor_id, released_at
) values
  ('a2224000-0000-0000-0000-000000000417', 'a2224000-0000-0000-0000-000000000407', 'a2224000-0000-0000-0000-000000000247', 1, 'BASE', 'RELEASED', true, 'Issue 222 customer', 'Issue 222 kitchen', 'Fixture', 'a2220000-0000-0000-0000-000000000001', now()),
  ('a2224000-0000-0000-0000-000000000418', 'a2224000-0000-0000-0000-000000000408', 'a2224000-0000-0000-0000-000000000248', 1, 'BASE', 'CANCELLED', true, 'Issue 222 customer', 'Issue 222 kitchen', 'Fixture', null, null),
  ('a2224000-0000-0000-0000-000000000419', 'a2224000-0000-0000-0000-000000000409', 'a2224000-0000-0000-0000-000000000249', 1, 'BASE', 'CANCELLED', true, 'Issue 222 customer', 'Issue 222 kitchen', 'Fixture', null, null),
  ('a2224000-0000-0000-0000-000000000420', 'a2224000-0000-0000-0000-000000000410', 'a2224000-0000-0000-0000-000000000250', 1, 'BASE', 'RELEASED', true, 'Issue 222 customer', 'Issue 222 kitchen', 'Fixture', 'a2220000-0000-0000-0000-000000000001', now());
insert into atlas_planning.dispatch_requirement_lines (
  dispatch_requirement_line_id, dispatch_requirement_id,
  purchase_handoff_line_id
) values
  ('a2224000-0000-0000-0000-000000000427', 'a2224000-0000-0000-0000-000000000407', 'a2224000-0000-0000-0000-000000000217'),
  ('a2224000-0000-0000-0000-000000000428', 'a2224000-0000-0000-0000-000000000408', 'a2224000-0000-0000-0000-000000000218'),
  ('a2224000-0000-0000-0000-000000000429', 'a2224000-0000-0000-0000-000000000409', 'a2224000-0000-0000-0000-000000000219'),
  ('a2224000-0000-0000-0000-000000000430', 'a2224000-0000-0000-0000-000000000410', 'a2224000-0000-0000-0000-000000000220');
insert into atlas_planning.dispatch_requirement_line_revisions (
  dispatch_requirement_line_revision_id, dispatch_requirement_revision_id,
  dispatch_requirement_line_id, purchase_handoff_line_revision_id,
  ingredient_id, required_quantity, unit_id
) values
  ('a2224000-0000-0000-0000-000000000437', 'a2224000-0000-0000-0000-000000000417', 'a2224000-0000-0000-0000-000000000427', 'a2224000-0000-0000-0000-000000000237', 'a2220000-0000-0000-0000-000000000306', 1, 'a2220000-0000-0000-0000-000000000305'),
  ('a2224000-0000-0000-0000-000000000438', 'a2224000-0000-0000-0000-000000000418', 'a2224000-0000-0000-0000-000000000428', 'a2224000-0000-0000-0000-000000000238', 'a2220000-0000-0000-0000-000000000306', 1, 'a2220000-0000-0000-0000-000000000305'),
  ('a2224000-0000-0000-0000-000000000439', 'a2224000-0000-0000-0000-000000000419', 'a2224000-0000-0000-0000-000000000429', 'a2224000-0000-0000-0000-000000000239', 'a2220000-0000-0000-0000-000000000306', 1, 'a2220000-0000-0000-0000-000000000305'),
  ('a2224000-0000-0000-0000-000000000440', 'a2224000-0000-0000-0000-000000000420', 'a2224000-0000-0000-0000-000000000430', 'a2224000-0000-0000-0000-000000000240', 'a2220000-0000-0000-0000-000000000306', 1, 'a2220000-0000-0000-0000-000000000305');

insert into atlas_procurement.fulfilment_allocations (
  fulfilment_allocation_id, dispatch_requirement_id,
  allocation_status, version
) values
  ('a2224000-0000-0000-0000-000000000448', 'a2224000-0000-0000-0000-000000000408', 'READY_FOR_DISPATCH', 1),
  ('a2224000-0000-0000-0000-000000000449', 'a2224000-0000-0000-0000-000000000410', 'READY_FOR_DISPATCH', 1);
insert into atlas_procurement.fulfilment_allocation_revisions (
  fulfilment_allocation_revision_id, fulfilment_allocation_id,
  revision_number, revision_kind, revision_status, is_current,
  allocated_by_actor_id
) values
  ('a2224000-0000-0000-0000-000000000458', 'a2224000-0000-0000-0000-000000000448', 1, 'BASE', 'READY_FOR_DISPATCH', true, 'a2220000-0000-0000-0000-000000000001'),
  ('a2224000-0000-0000-0000-000000000459', 'a2224000-0000-0000-0000-000000000449', 1, 'BASE', 'READY_FOR_DISPATCH', true, 'a2220000-0000-0000-0000-000000000001');
insert into atlas_procurement.fulfilment_allocation_lines (
  fulfilment_allocation_line_id, fulfilment_allocation_id,
  dispatch_requirement_line_id, portion_sequence
) values
  ('a2224000-0000-0000-0000-000000000468', 'a2224000-0000-0000-0000-000000000448', 'a2224000-0000-0000-0000-000000000428', 1),
  ('a2224000-0000-0000-0000-000000000469', 'a2224000-0000-0000-0000-000000000449', 'a2224000-0000-0000-0000-000000000430', 1);
insert into atlas_procurement.fulfilment_allocation_line_revisions (
  fulfilment_allocation_line_revision_id,
  fulfilment_allocation_revision_id, fulfilment_allocation_line_id,
  dispatch_requirement_line_revision_id, fulfilment_source_type,
  supplier_id, allocated_quantity, unit_id, line_status
) values
  ('a2224000-0000-0000-0000-000000000478', 'a2224000-0000-0000-0000-000000000458', 'a2224000-0000-0000-0000-000000000468', 'a2224000-0000-0000-0000-000000000438', 'SUPPLIER_PO', 'a2220000-0000-0000-0000-000000000310', 1, 'a2220000-0000-0000-0000-000000000305', 'READY_FOR_EVIDENCE'),
  ('a2224000-0000-0000-0000-000000000479', 'a2224000-0000-0000-0000-000000000459', 'a2224000-0000-0000-0000-000000000469', 'a2224000-0000-0000-0000-000000000440', 'SUPPLIER_PO', 'a2220000-0000-0000-0000-000000000310', 1, 'a2220000-0000-0000-0000-000000000305', 'READY_FOR_EVIDENCE');

set local session_replication_role = origin;

create temp table issue_222_downstream_history_before as
select jsonb_build_object(
  'handoff_batches',
    (select count(*) from atlas_planning.purchase_handoff_batches
      where purchase_handoff_batch_id::text like 'a2224000-%'),
  'handoff_revisions',
    (select count(*) from atlas_planning.purchase_handoff_revisions
      where purchase_handoff_revision_id::text like 'a2224000-%'),
  'dispatch_requirements',
    (select count(*) from atlas_planning.dispatch_requirements
      where dispatch_requirement_id::text like 'a2224000-%'),
  'dispatch_requirement_revisions',
    (select count(*) from atlas_planning.dispatch_requirement_revisions
      where dispatch_requirement_revision_id::text like 'a2224000-%'),
  'fulfilment_allocations',
    (select count(*) from atlas_procurement.fulfilment_allocations
      where fulfilment_allocation_id::text like 'a2224000-%'),
  'fulfilment_allocation_revisions',
    (select count(*) from atlas_procurement.fulfilment_allocation_revisions
      where fulfilment_allocation_revision_id::text like 'a2224000-%')
) as footprint;

-- Material fact comparison is date-scoped and ignores source-row metadata.
grant atlas_planning_command_runtime to postgres with set true;
set local role atlas_planning_command_runtime;
select is(
  atlas_core.issue_222_affected_dates(
    'WEEKLY_MENU', pg_temp.menu_payload(array['2027-05-05'::date])
  ),
  array['2027-05-05'::date],
  'I222-07 Menu returns only the materially changed service date'
);
select is(
  atlas_core.issue_222_affected_dates(
    'WEEKLY_MENU', pg_temp.menu_payload('{}'::date[], 'metadata-only')
  ),
  '{}'::date[],
  'I222-08 Menu source-row metadata is not a downstream fact'
);
select is(
  atlas_core.issue_222_affected_dates(
    'ATTENDANCE', jsonb_build_object(
      'week_start', '2027-05-03',
      'rows', jsonb_build_array(jsonb_build_object(
        'school_id', 'a2220000-0000-0000-0000-000000000304',
        'service_date', '2027-05-03', 'student_portions', 101,
        'teacher_portions', 10, 'source_row_reference', 'changed'
      ))
    )
  ),
  array['2027-05-03'::date],
  'I222-09 Attendance detects portion changes on the exact date'
);
select is(
  atlas_core.issue_222_affected_dates(
    'ATTENDANCE', jsonb_build_object(
      'week_start', '2027-05-03',
      'rows', jsonb_build_array(jsonb_build_object(
        'school_id', 'a2220000-0000-0000-0000-000000000304',
        'service_date', '2027-05-03', 'student_portions', 100,
        'teacher_portions', 10, 'source_row_reference', 'metadata-only'
      ))
    )
  ),
  '{}'::date[],
  'I222-10 Attendance source-row metadata is not consequential'
);
select is(
  atlas_core.issue_222_affected_dates(
    'PANTRY', jsonb_build_object(
      'week_start', '2027-05-03',
      'rows', jsonb_build_array(jsonb_build_object(
        'service_date', '2027-05-03',
        'school_id', 'a2220000-0000-0000-0000-000000000304',
        'ingredient_id', 'a2220000-0000-0000-0000-000000000306',
        'pantry_need_purpose_id', 'a2220000-0000-0000-0000-000000000309',
        'requested_quantity', 3, 'note', 'changed note',
        'source_request_reference', 'changed',
        'source_row_reference', 'changed'
      ))
    )
  ),
  array['2027-05-03'::date],
  'I222-11 Pantry detects quantity changes on the exact date'
);
select is(
  atlas_core.issue_222_affected_dates(
    'PANTRY', jsonb_build_object(
      'week_start', '2027-05-03',
      'rows', jsonb_build_array(jsonb_build_object(
        'service_date', '2027-05-03',
        'school_id', 'a2220000-0000-0000-0000-000000000304',
        'ingredient_id', 'a2220000-0000-0000-0000-000000000306',
        'pantry_need_purpose_id', 'a2220000-0000-0000-0000-000000000309',
        'requested_quantity', 2, 'note', 'metadata-only',
        'source_request_reference', 'metadata-only',
        'source_row_reference', 'metadata-only'
      ))
    )
  ),
  '{}'::date[],
  'I222-12 Pantry notes and references remain non-consequential metadata'
);
reset role;

create temp table issue_222_results (result_name text primary key, response jsonb);
create temp table issue_222_payloads (payload_name text primary key, payload jsonb);
grant select, insert on issue_222_results to atlas_planning_command_runtime;
grant select, insert on issue_222_results to authenticated;
grant select, insert on issue_222_payloads to atlas_planning_command_runtime;
grant select on issue_222_payloads to authenticated;
set local role atlas_planning_command_runtime;
insert into issue_222_results values (
  'all-policies',
  atlas_core.issue_222_source_impact_payload(
    'WEEKLY_MENU',
    pg_temp.menu_payload(array[
      '2027-05-03'::date, '2027-05-04'::date, '2027-05-05'::date,
      '2027-05-06'::date, '2027-05-07'::date, '2027-05-08'::date
    ])
  )
);
select is(
  (select response -> 'affected_service_dates' from issue_222_results
    where result_name = 'all-policies'),
  '["2027-05-03", "2027-05-04", "2027-05-05", "2027-05-06", "2027-05-07", "2027-05-08"]'::jsonb,
  'I222-13 impact exposes every and only materially affected date'
);
select is(
  (
    select jsonb_object_agg(item ->> 'service_date', item ->> 'correction_policy')
    from issue_222_results result
    cross join lateral jsonb_array_elements(result.response -> 'date_impacts') item
    where result.result_name = 'all-policies'
  ),
  '{
    "2027-05-03":"SAFE_NOT_GENERATED",
    "2027-05-04":"SAFE_REGENERATE",
    "2027-05-05":"PLANNING_RELEASE_CORRECTION_REQUIRED",
    "2027-05-06":"LEGACY_RANGE_CORRECTION_REQUIRED",
    "2027-05-07":"BLOCKED_BY_PURCHASE_HANDOFF",
    "2027-05-08":"BLOCKED_BY_DOWNSTREAM_COMMITMENT"
  }'::jsonb,
  'I222-14 backend owns the full precedence-aware policy classification'
);
select is(
  (
    select jsonb_array_length(item -> 'chains')
    from issue_222_results result
    cross join lateral jsonb_array_elements(result.response -> 'date_impacts') item
    where result.result_name = 'all-policies'
      and item ->> 'service_date' = '2027-05-06'
  ),
  2,
  'I222-15 both overlapping legacy ranges are exposed without splitting'
);
select ok(
  not (select (response ->> 'save_allowed')::boolean
    from issue_222_results where result_name = 'all-policies'),
  'I222-16 any governed or blocked date prevents the source Save'
);

insert into issue_222_results values (
  'safe-not-generated',
  atlas_core.issue_222_source_impact_payload(
    'WEEKLY_MENU', pg_temp.menu_payload(array['2027-05-03'::date])
  )
);
select is(
  (select response #>> '{date_impacts,0,correction_policy}'
    from issue_222_results where result_name = 'safe-not-generated'),
  'SAFE_NOT_GENERATED',
  'I222-17 an ungenerated date is safe to save'
);
select ok(
  (select (response ->> 'save_allowed')::boolean
    from issue_222_results where result_name = 'safe-not-generated'),
  'I222-18 safe-not-generated impact allows Save'
);
insert into issue_222_payloads
select 'planning-release', payload || jsonb_build_object(
  'source_signature', atlas_core.rmvp_03a_menu_signature(payload -> 'rows'),
  'expected_source_signature', repeat('a', 64)
)
from (select pg_temp.menu_payload(array['2027-05-05'::date]) payload) proposed;
reset role;

select set_config(
  'request.jwt.claim.sub',
  'a2220000-0000-0000-0000-000000000101', true
);
set local role authenticated;
insert into issue_222_results values (
  'authorized-read',
  atlas_api.get_planning_source_correction_impact(jsonb_build_object(
    'contract_version', 'PLANNING-CORRECTION.v1',
    'requested_by_auth_subject',
      'a2220000-0000-0000-0000-000000000101',
    'correlation_id', gen_random_uuid(),
    'payload', jsonb_build_object(
      'source_kind', 'WEEKLY_MENU',
      'source_payload', (select payload from issue_222_payloads
        where payload_name = 'planning-release')
    )
  ))
);
reset role;
select ok(
  (select response ->> 'success' = 'true'
    from issue_222_results where result_name = 'authorized-read'),
  'I222-19 authorized shaped impact read succeeds'
);
select is(
  (select response #>> '{impact,affected_service_dates,0}'
    from issue_222_results where result_name = 'authorized-read'),
  '2027-05-05',
  'I222-20 public read returns the exact affected date'
);

-- Consequential Save rechecks the policy and leaves the source untouched.
set local role authenticated;
insert into issue_222_results
select 'blocked-save', atlas_api.save_weekly_menu(jsonb_build_object(
  'contract_version', 'RMVP-03A.v2',
  'command_id', 'a2225000-0000-0000-0000-000000000001',
  'correlation_id', 'a2225000-0000-0000-0000-000000000002',
  'idempotency_key', 'issue222-blocked-save',
  'expected_version', 1,
  'requested_by_auth_subject', 'a2220000-0000-0000-0000-000000000101',
  'requested_at', transaction_timestamp(),
  'reason_code', 'WEEKLY_MENU_SAVED', 'reason_note', null,
  'payload', payload
))
from (select payload from issue_222_payloads
  where payload_name = 'planning-release') proposed;
reset role;
select is(
  (select response ->> 'error_code' from issue_222_results
    where result_name = 'blocked-save'),
  'PLANNING_RELEASE_CORRECTION_REQUIRED',
  'I222-21 Save rejects a stale preview when Planning release is current'
);
select is(
  (select row(version, source_signature)::text
    from atlas_planning.weekly_menus
    where weekly_menu_id = 'a2221000-0000-0000-0000-000000000101'),
  '(1,aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa)',
  'I222-22 blocked Save creates no source mutation'
);

-- Releasing authority is distinct from Need correction authority.
set local role authenticated;
insert into issue_222_results values (
  'reopen-release-denied',
  atlas_api.prepare_planning_source_correction(pg_temp.correction_request(
    'a2225000-0000-0000-0000-000000000091', 'issue222-release-denied',
    'a2222000-0000-0000-0000-000000000205', 1,
    'a2223000-0000-0000-0000-000000000205', 4
  ))
);
reset role;
select is(
  (select response ->> 'error_code' from issue_222_results
    where result_name = 'reopen-release-denied'),
  'CAPABILITY_DENIED',
  'I222-AUTH-01 Need authority alone cannot reverse a Confirmed Need release'
);
select is(
  (select row(batch_status, version,
    current_confirmed_need_approval_snapshot_id,
    current_confirmed_need_release_id)::text
   from atlas_planning.confirmed_need_batches
   where confirmed_need_batch_id = 'a2223000-0000-0000-0000-000000000205'),
  '(RELEASED_FOR_PURCHASE_HANDOFF,4,a2223100-0000-0000-0000-000000000205,a2223200-0000-0000-0000-000000000205)',
  'I222-AUTH-02 denied release reversal preserves current release authority'
);
select is(
  (select row(run_status, version)::text
   from atlas_planning.need_generation_runs
   where need_generation_run_id = 'a2222000-0000-0000-0000-000000000205'),
  '(RELEASED_FOR_CONFIRMATION,1)',
  'I222-AUTH-03 denied release reversal preserves the Need run'
);

-- Actor B has both capabilities: explicit reopen, immutable history, replay.
select set_config(
  'request.jwt.claim.sub',
  'a2220000-0000-0000-0000-000000000102', true
);
set local role authenticated;
insert into issue_222_results values (
  'reopen-released',
  atlas_api.prepare_planning_source_correction(pg_temp.correction_request(
    'a2225000-0000-0000-0000-000000000101', 'issue222-reopen',
    'a2222000-0000-0000-0000-000000000205', 1,
    'a2223000-0000-0000-0000-000000000205', 4,
    'a2220000-0000-0000-0000-000000000102'
  ))
);
insert into issue_222_results values (
  'reopen-replay',
  atlas_api.prepare_planning_source_correction(pg_temp.correction_request(
    'a2225000-0000-0000-0000-000000000101', 'issue222-reopen',
    'a2222000-0000-0000-0000-000000000205', 1,
    'a2223000-0000-0000-0000-000000000205', 4,
    'a2220000-0000-0000-0000-000000000102'
  ))
);
reset role;
select is(
  (select response ->> 'correction_action' from issue_222_results
    where result_name = 'reopen-released'),
  'CONFIRMED_NEED_REOPENED',
  'I222-23 released Planning commitment is explicitly reopened'
);
select is(
  (select row(batch_status, version,
    current_confirmed_need_approval_snapshot_id,
    current_confirmed_need_release_id)::text
   from atlas_planning.confirmed_need_batches
   where confirmed_need_batch_id = 'a2223000-0000-0000-0000-000000000205'),
  '(REOPENED,5,,)',
  'I222-24 reopen increments once and clears only current authority pointers'
);
select is(
  (select count(*) from atlas_planning.confirmed_need_releases
   where confirmed_need_batch_id = 'a2223000-0000-0000-0000-000000000205'),
  1::bigint,
  'I222-25 immutable release history remains present'
);
select is(
  (select response from issue_222_results where result_name = 'reopen-replay'),
  (select response from issue_222_results where result_name = 'reopen-released'),
  'I222-26 exact command replay returns the committed response'
);
select is(
  (select run_status from atlas_planning.need_generation_runs
   where need_generation_run_id = 'a2222000-0000-0000-0000-000000000205'),
  'RELEASED_FOR_CONFIRMATION',
  'I222-27 reopen does not silently regenerate or rewrite the Need run'
);

-- Each overlapping historical range is retired independently.
select set_config(
  'request.jwt.claim.sub',
  'a2220000-0000-0000-0000-000000000101', true
);
set local role authenticated;
insert into issue_222_results values (
  'retire-legacy-a',
  atlas_api.prepare_planning_source_correction(pg_temp.correction_request(
    'a2225000-0000-0000-0000-000000000201', 'issue222-legacy-a',
    'a2222000-0000-0000-0000-000000000206', 1,
    'a2223000-0000-0000-0000-000000000206', 1
  ))
);
insert into issue_222_results values (
  'retire-legacy-b',
  atlas_api.prepare_planning_source_correction(pg_temp.correction_request(
    'a2225000-0000-0000-0000-000000000202', 'issue222-legacy-b',
    'a2222000-0000-0000-0000-000000000216', 1,
    'a2223000-0000-0000-0000-000000000216', 1
  ))
);
reset role;
select is(
  (select array_agg(response ->> 'correction_action' order by result_name)
   from issue_222_results where result_name like 'retire-legacy-%'),
  array['LEGACY_RANGE_INVALIDATED', 'LEGACY_RANGE_INVALIDATED']::text[],
  'I222-28 both overlapping ranges require and receive separate actions'
);
select is(
  (select array_agg(run_status order by need_generation_run_id)::text[]
   from atlas_planning.need_generation_runs
   where need_generation_run_id in (
     'a2222000-0000-0000-0000-000000000206',
     'a2222000-0000-0000-0000-000000000216'
   )),
  array['INVALIDATED', 'INVALIDATED']::text[],
  'I222-29 legacy runs remain whole and are retired independently'
);
select is(
  (select count(*) from atlas_planning.need_generation_runs
   where need_generation_run_id in (
     'a2222000-0000-0000-0000-000000000206',
     'a2222000-0000-0000-0000-000000000216'
   )),
  2::bigint,
  'I222-30 retirement never splits or deletes historical ranges'
);

-- Active Handoff and later commitments remain hard downstream boundaries.
grant atlas_planning_command_runtime to postgres with set true;
set local role atlas_planning_command_runtime;
select is(
  (
    select row(
      (payload ->> 'active_purchase_handoff_exists')::boolean,
      (payload ->> 'later_downstream_commitment_exists')::boolean
    )::text
    from (select atlas_core.issue_222_chain_payload(
      'a2222000-0000-0000-0000-000000000207'
    ) payload) classified
  ),
  '(t,f)',
  'I222-DOWN-01 active Handoff with no allocation is not later downstream'
);
select is(
  (
    select row(
      (payload ->> 'active_purchase_handoff_exists')::boolean,
      (payload ->> 'later_downstream_commitment_exists')::boolean
    )::text
    from (select atlas_core.issue_222_chain_payload(
      'a2222000-0000-0000-0000-000000000208'
    ) payload) classified
  ),
  '(f,t)',
  'I222-DOWN-02 invalidated Handoff with allocation remains downstream'
);
select is(
  (
    select row(
      (payload ->> 'active_purchase_handoff_exists')::boolean,
      (payload ->> 'later_downstream_commitment_exists')::boolean
    )::text
    from (select atlas_core.issue_222_chain_payload(
      'a2222000-0000-0000-0000-000000000209'
    ) payload) classified
  ),
  '(f,f)',
  'I222-DOWN-03 invalidated Handoff without allocation is not downstream'
);
select is(
  (
    select row(
      (payload ->> 'active_purchase_handoff_exists')::boolean,
      (payload ->> 'later_downstream_commitment_exists')::boolean
    )::text
    from (select atlas_core.issue_222_chain_payload(
      'a2222000-0000-0000-0000-000000000210'
    ) payload) classified
  ),
  '(t,t)',
  'I222-DOWN-04 active Handoff with allocation is later downstream'
);
select is(
  atlas_core.issue_222_source_impact_payload(
    'WEEKLY_MENU', pg_temp.menu_payload(array['2027-05-09'::date])
  ) #>> '{date_impacts,0,correction_policy}',
  'PLANNING_RELEASE_CORRECTION_REQUIRED',
  'I222-DOWN-05 invalidated Handoff without allocation remains correctable'
);
reset role;

set local role authenticated;
insert into issue_222_results values (
  'blocked-handoff',
  atlas_api.prepare_planning_source_correction(pg_temp.correction_request(
    'a2225000-0000-0000-0000-000000000301', 'issue222-handoff',
    'a2222000-0000-0000-0000-000000000207', 1,
    'a2223000-0000-0000-0000-000000000207', 4
  ))
);
insert into issue_222_results values (
  'blocked-downstream',
  atlas_api.prepare_planning_source_correction(pg_temp.correction_request(
    'a2225000-0000-0000-0000-000000000302', 'issue222-downstream',
    'a2222000-0000-0000-0000-000000000208', 1,
    'a2223000-0000-0000-0000-000000000208', 1
  ))
);
insert into issue_222_results values (
  'blocked-active-downstream',
  atlas_api.prepare_planning_source_correction(pg_temp.correction_request(
    'a2225000-0000-0000-0000-000000000303', 'issue222-active-downstream',
    'a2222000-0000-0000-0000-000000000210', 1,
    'a2223000-0000-0000-0000-000000000210', 4
  ))
);
reset role;
select is(
  (select response ->> 'error_code' from issue_222_results
    where result_name = 'blocked-handoff'),
  'BLOCKED_BY_PURCHASE_HANDOFF',
  'I222-31 active Purchase Handoff blocks Planning correction'
);
select is(
  (select response ->> 'error_code' from issue_222_results
    where result_name = 'blocked-downstream'),
  'BLOCKED_BY_DOWNSTREAM_COMMITMENT',
  'I222-32 Procurement allocation blocks even an invalidated Handoff'
);
select is(
  (select response ->> 'error_code' from issue_222_results
    where result_name = 'blocked-active-downstream'),
  'BLOCKED_BY_DOWNSTREAM_COMMITMENT',
  'I222-DOWN-06 allocation takes precedence over an active Handoff blocker'
);
select is(
  (select batch_status from atlas_planning.confirmed_need_batches
   where confirmed_need_batch_id = 'a2223000-0000-0000-0000-000000000207'),
  'RELEASED_FOR_PURCHASE_HANDOFF',
  'I222-33 blocked Handoff path mutates no Planning commitment'
);
select is(
  (select run_status from atlas_planning.need_generation_runs
   where need_generation_run_id = 'a2222000-0000-0000-0000-000000000208'),
  'RELEASED_FOR_CONFIRMATION',
  'I222-34 blocked later path mutates no Need history'
);
select is(
  (select footprint from issue_222_downstream_history_before),
  jsonb_build_object(
    'handoff_batches',
      (select count(*) from atlas_planning.purchase_handoff_batches
        where purchase_handoff_batch_id::text like 'a2224000-%'),
    'handoff_revisions',
      (select count(*) from atlas_planning.purchase_handoff_revisions
        where purchase_handoff_revision_id::text like 'a2224000-%'),
    'dispatch_requirements',
      (select count(*) from atlas_planning.dispatch_requirements
        where dispatch_requirement_id::text like 'a2224000-%'),
    'dispatch_requirement_revisions',
      (select count(*) from atlas_planning.dispatch_requirement_revisions
        where dispatch_requirement_revision_id::text like 'a2224000-%'),
    'fulfilment_allocations',
      (select count(*) from atlas_procurement.fulfilment_allocations
        where fulfilment_allocation_id::text like 'a2224000-%'),
    'fulfilment_allocation_revisions',
      (select count(*) from atlas_procurement.fulfilment_allocation_revisions
        where fulfilment_allocation_revision_id::text like 'a2224000-%')
  ),
  'I222-DOWN-07 correction attempts never rewrite Planning or Procurement history'
);
select is(
  (select count(*) from atlas_audit.domain_events
   where event_type = 'PlanningSourceCorrectionPrepared'),
  3::bigint,
  'I222-35 successful governed actions emit one immutable event each'
);
select is(
  (select count(*) from atlas_audit.audit_events
   where event_type = 'PlanningSourceCorrectionPrepared'),
  3::bigint,
  'I222-36 successful governed actions emit one audit record each'
);
select is(
  (select count(*) from atlas_core.command_receipts
   where command_name = 'prepare_planning_source_correction'
     and outcome = 'COMPLETED'),
  3::bigint,
  'I222-37 replay and blocked attempts do not duplicate completed receipts'
);

select * from finish();
rollback;
