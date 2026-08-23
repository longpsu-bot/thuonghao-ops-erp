begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = pg_catalog, public, extensions;

select plan(164);

select is(
  (
    select array_agg(p.proname order by p.proname)::text[]
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
      and p.proname in (
        'save_weekly_menu', 'save_attendance', 'save_pantry',
        'get_planning_input_preflight', 'execute_need_generation'
      )
  ),
  array[
    'execute_need_generation', 'get_planning_input_preflight',
    'save_attendance', 'save_pantry', 'save_weekly_menu'
  ]::text[],
  'PCT01-01 exact additive public registry exists'
);
select is(
  (
    select array_agg(pg_get_userbyid(p.proowner) order by p.proname)::text[]
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
      and p.proname in ('save_attendance','save_pantry','save_weekly_menu')
  ),
  array_fill('atlas_planning_command_runtime'::text, array[3]),
  'PCT01-02 all consequential source Saves use the existing Planning runtime'
);
select is(
  (
    select pg_get_userbyid(p.proowner)
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api' and p.proname = 'get_planning_input_preflight'
  ),
  'atlas_read_runtime',
  'PCT01-03 preflight uses the existing read runtime'
);
select is(
  (
    select pg_get_userbyid(p.proowner)
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api' and p.proname = 'execute_need_generation'
  ),
  'atlas_need_generation_runtime',
  'PCT01-04 atomic generation uses the existing Need Generation runtime'
);
select ok(
  (
    select bool_and(p.proconfig = array['search_path=""'])
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
      and p.proname in (
        'save_weekly_menu', 'save_attendance', 'save_pantry',
        'get_planning_input_preflight', 'execute_need_generation'
      )
  ),
  'PCT01-05 every v2 function fixes an empty search_path'
);
select ok(
  (
    select bool_and(p.prosecdef)
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
      and p.proname in (
        'save_weekly_menu', 'save_attendance', 'save_pantry',
        'get_planning_input_preflight', 'execute_need_generation'
      )
  ),
  'PCT01-06 every v2 function is a security-definer boundary'
);
select ok(
  (
    select bool_and(has_function_privilege('authenticated', p.oid, 'EXECUTE'))
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
      and p.proname in (
        'save_weekly_menu', 'save_attendance', 'save_pantry',
        'get_planning_input_preflight', 'execute_need_generation'
      )
  ),
  'PCT01-07 authenticated receives exact function execution'
);
select ok(
  (
    select bool_and(not has_function_privilege('anon', p.oid, 'EXECUTE'))
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
      and p.proname in (
        'save_weekly_menu', 'save_attendance', 'save_pantry',
        'get_planning_input_preflight', 'execute_need_generation'
      )
  ),
  'PCT01-08 anon cannot execute v2 functions'
);
select ok(
  (
    select bool_and(not has_function_privilege('service_role', p.oid, 'EXECUTE'))
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
      and p.proname in (
        'save_weekly_menu', 'save_attendance', 'save_pantry',
        'get_planning_input_preflight', 'execute_need_generation'
      )
  ),
  'PCT01-09 service_role cannot execute v2 functions'
);
select ok(
  (
    select bool_and(not has_function_privilege('public', p.oid, 'EXECUTE'))
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
      and p.proname in (
        'save_weekly_menu', 'save_attendance', 'save_pantry',
        'get_planning_input_preflight', 'execute_need_generation'
      )
  ),
  'PCT01-10 PUBLIC cannot execute v2 functions'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'atlas_core.planning_contract_01_materialize_confirmed_needs(jsonb)'::regprocedure,
    'EXECUTE'
  ),
  'PCT01-11 browser roles cannot execute the private H0C helper'
);
select is(
  (select count(*) from atlas_core.capabilities where capability_code = 'planning.inputs.complete'),
  0::bigint,
  'PCT01-12 no cross-source completion capability exists'
);
select ok(has_function_privilege('authenticated','atlas_api.save_weekly_menu_draft(jsonb)'::regprocedure,'EXECUTE'),'PCT01-13 RMVP-03A.v1 remains callable');
select ok(has_function_privilege('authenticated','atlas_api.evaluate_planning_input_readiness(jsonb)'::regprocedure,'EXECUTE'),'PCT01-14 RMVP-03B.v1 remains callable');
select ok(has_function_privilege('authenticated','atlas_api.create_need_generation_run(jsonb)'::regprocedure,'EXECUTE'),'PCT01-15 RMVP-04.v1 remains callable');
select ok(has_function_privilege('authenticated','atlas_api.create_confirmed_needs_from_generation(jsonb)'::regprocedure,'EXECUTE'),'PCT01-16 PA-06E-H0C.v1 remains callable');
select is(
  (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname like 'atlas\_%' escape '\' and c.relkind='r' and c.relname like 'planning_contract_01%'),
  0::bigint,
  'PCT01-17 no convenience persistence was added'
);
select is(
  (
    select pg_get_userbyid(p.proowner)
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='atlas_core'
      and p.proname='planning_contract_01_materialize_confirmed_needs'
  ),
  'atlas_planning_materialization_runtime',
  'PCT01-18 the single private H0C algorithm retains its dedicated runtime'
);

-- H0A2 normally prevents duplicate active Recipe roots in either scope. The
-- rolled-back test transaction relaxes only those indexes so RMVP-04's
-- required defensive behavior can be proven against ambiguous source facts.
drop index atlas_admin.recipes_active_general_dish_key;
drop index atlas_admin.recipes_active_typed_dish_school_type_key;

create function pg_temp.rmvp04_read(
  p_run_id uuid default null,
  p_subject uuid default 'e4000000-0000-0000-0000-000000000101',
  p_period_start date default '2026-11-02',
  p_period_end date default '2026-11-02'
)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'contract_version', 'RMVP-04.v1',
    'requested_by_auth_subject', p_subject,
    'correlation_id', pg_catalog.gen_random_uuid(),
    'payload', pg_catalog.jsonb_build_object(
      'period_start', p_period_start,
      'period_end', p_period_end,
      'need_generation_run_id', p_run_id,
      'filters', pg_catalog.jsonb_build_object(),
      'group_offset', 0,
      'group_limit', 100
    )
  );
$$;

create function pg_temp.rmvp04_command(
  p_command_id uuid,
  p_key text,
  p_expected_version bigint,
  p_reason text,
  p_note text,
  p_payload jsonb,
  p_subject uuid default 'e4000000-0000-0000-0000-000000000101'
)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'contract_version', 'RMVP-04.v1',
    'command_id', p_command_id,
    'correlation_id', pg_catalog.gen_random_uuid(),
    'idempotency_key', p_key,
    'expected_version', p_expected_version,
    'requested_by_auth_subject', p_subject,
    'requested_at', pg_catalog.transaction_timestamp(),
    'reason_code', p_reason,
    'reason_note', p_note,
    'payload', p_payload
  );
$$;

create function pg_temp.rmvp04_readiness_command(
  p_command_id uuid,
  p_key text,
  p_expected_status text,
  p_expected_evaluation_id uuid,
  p_expected_version bigint,
  p_reason text,
  p_payload jsonb,
  p_subject uuid default 'e4000000-0000-0000-0000-000000000101'
)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'contract_version', 'RMVP-03B.v1',
    'command_id', p_command_id,
    'correlation_id', pg_catalog.gen_random_uuid(),
    'idempotency_key', p_key,
    'requested_by_auth_subject', p_subject,
    'requested_at', pg_catalog.transaction_timestamp(),
    'expected_root_status', p_expected_status,
    'expected_current_evaluation_id', p_expected_evaluation_id,
    'expected_current_evaluation_version', p_expected_version,
    'reason_code', p_reason,
    'reason_note', null,
    'payload', p_payload
  );
$$;

create function pg_temp.rmvp04_cmd15(
  p_run_id uuid,
  p_run_version bigint
)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'contract_version', 'PA-06E-H0C.v1',
    'command_id', 'e4500000-0000-0000-0000-000000000006'::uuid,
    'correlation_id', pg_catalog.gen_random_uuid(),
    'idempotency_key', 'rmvp04-materialize',
    'expected_version', 1,
    'requested_by_auth_subject', 'e4000000-0000-0000-0000-000000000101'::uuid,
    'requested_at', pg_catalog.transaction_timestamp(),
    'reason_code', 'RMVP04_MATERIALIZATION',
    'reason_note', 'Connected Need Generation acceptance',
    'payload', pg_catalog.jsonb_build_object(
      'need_generation_run_id', p_run_id,
      'need_generation_run_version', p_run_version,
      'confirmed_need_batch_id', null
    )
  );
$$;

-- Synthetic Actors and exact capabilities.
insert into atlas_core.actors (actor_id, actor_type, display_name) values
  ('e4000000-0000-0000-0000-000000000001', 'HUMAN', 'RMVP-04 connected operator'),
  ('e4000000-0000-0000-0000-000000000002', 'HUMAN', 'RMVP-04 unauthorized operator'),
  ('e4000000-0000-0000-0000-000000000003', 'HUMAN', 'RMVP-04 wrong-scope operator');
insert into atlas_core.actor_auth_subjects (actor_auth_subject_id, actor_id, auth_subject_id) values
  ('e4000000-0000-0000-0000-000000000011', 'e4000000-0000-0000-0000-000000000001', 'e4000000-0000-0000-0000-000000000101'),
  ('e4000000-0000-0000-0000-000000000012', 'e4000000-0000-0000-0000-000000000002', 'e4000000-0000-0000-0000-000000000102'),
  ('e4000000-0000-0000-0000-000000000013', 'e4000000-0000-0000-0000-000000000003', 'e4000000-0000-0000-0000-000000000103');
insert into atlas_core.roles (role_id, role_code, role_name) values
  ('e4000000-0000-0000-0000-000000000020', 'rmvp04.operator', 'RMVP-04 operator'),
  ('e4000000-0000-0000-0000-000000000021', 'rmvp04.denied', 'RMVP-04 denied');
insert into atlas_core.role_capabilities (role_id, capability_id)
select 'e4000000-0000-0000-0000-000000000020', capability_id
from atlas_core.capabilities
where capability_code in (
  'planning.inputs.read',
  'planning.input_readiness.write',
  'planning.need_generation.write',
  'confirmed_need_generation.materialize',
  'planning.weekly_menu.write',
  'planning.attendance.write',
  'planning.pantry.write'
);
insert into atlas_core.role_capabilities (role_id, capability_id)
select 'e4000000-0000-0000-0000-000000000021', capability_id
from atlas_core.capabilities
where capability_code = 'planning.weekly_menu.write';
insert into atlas_core.actor_role_memberships (actor_id, role_id) values
  ('e4000000-0000-0000-0000-000000000001', 'e4000000-0000-0000-0000-000000000020'),
  ('e4000000-0000-0000-0000-000000000002', 'e4000000-0000-0000-0000-000000000021'),
  ('e4000000-0000-0000-0000-000000000003', 'e4000000-0000-0000-0000-000000000020');
insert into atlas_core.actor_scopes (actor_id, scope_kind) values
  ('e4000000-0000-0000-0000-000000000001', 'GLOBAL'),
  ('e4000000-0000-0000-0000-000000000002', 'GLOBAL');

-- Compact approved Menu, Attendance, Pantry and Recipe source evidence.
set local session_replication_role = replica;

insert into atlas_admin.customers (customer_id, customer_code, customer_name, customer_type)
values ('e4100000-0000-0000-0000-000000000001', 'rmvp04-customer', 'RMVP-04 Customer', 'SCHOOL_CATERING');
insert into atlas_admin.delivery_locations (delivery_location_id, customer_id, location_code, location_name, address_text, timezone_name) values
  ('e4100000-0000-0000-0000-000000000002', 'e4100000-0000-0000-0000-000000000001', 'rmvp04-kitchen', 'RMVP-04 School Kitchen', 'Fixture kitchen', 'Asia/Ho_Chi_Minh'),
  ('e4100000-0000-0000-0000-000000000003', 'e4100000-0000-0000-0000-000000000001', 'rmvp04-pantry', 'RMVP-04 Pantry Store', 'Fixture pantry', 'Asia/Ho_Chi_Minh');
insert into atlas_admin.school_types (school_type_id, school_type_code, school_type_name)
values ('e4100000-0000-0000-0000-000000000004', 'rmvp04-type', 'RMVP-04 Type');
insert into atlas_admin.schools (
  school_id, customer_id, school_code, school_name, school_type_id,
  default_delivery_location_id, display_order,
  default_student_portions, default_teacher_portions
)
values (
  'e4100000-0000-0000-0000-000000000005',
  'e4100000-0000-0000-0000-000000000001',
  'rmvp04-school', 'RMVP-04 School',
  'e4100000-0000-0000-0000-000000000004',
  'e4100000-0000-0000-0000-000000000002', 10, 100, 10
);
insert into atlas_admin.units (unit_id, unit_code, unit_name, dimension_code)
values ('e4100000-0000-0000-0000-000000000006', 'rmvp04-kg', 'RMVP-04 kilogram', 'mass');
insert into atlas_admin.ingredients (
  ingredient_id, ingredient_code, ingredient_name, purchase_unit_id
)
values
  (
    'e4100000-0000-0000-0000-000000000007', 'rmvp04-rice',
    'RMVP-04 rice', 'e4100000-0000-0000-0000-000000000006'
  ),
  (
    'e4100000-0000-0000-0000-000000000013', 'rmvp04-oil',
    'RMVP-04 oil', 'e4100000-0000-0000-0000-000000000006'
  ),
  (
    'e4100000-0000-0000-0000-000000000016', 'rmvp04-carrot',
    'RMVP-04 carrot', 'e4100000-0000-0000-0000-000000000006'
  ),
  (
    'e4100000-0000-0000-0000-000000000019', 'rmvp04-potato',
    'RMVP-04 potato', 'e4100000-0000-0000-0000-000000000006'
  ),
  (
    'e4100000-0000-0000-0000-000000000020', 'rmvp04-spinach',
    'RMVP-04 spinach', 'e4100000-0000-0000-0000-000000000006'
  ),
  (
    'e4100000-0000-0000-0000-000000000021', 'rmvp04-celery',
    'RMVP-04 celery', 'e4100000-0000-0000-0000-000000000006'
  );
insert into atlas_admin.dishes (
  dish_id, dish_code, dish_name, dish_type_id, dish_status, display_order,
  requires_need_generation
) values
  ('e4100000-0000-0000-0000-000000000008', 'rmvp04-dish', 'RMVP-04 dish', 'd1500000-0000-4000-8000-000000000002', 'ACTIVE', 10, true),
  ('e4600000-0000-0000-0000-000000000001', 'rmvp04-typed-ambiguous', 'RMVP-04 typed ambiguity dish', 'd1500000-0000-4000-8000-000000000002', 'ACTIVE', 20, true),
  ('e4700000-0000-0000-0000-000000000001', 'rmvp04-general-ambiguous', 'RMVP-04 general ambiguity dish', 'd1500000-0000-4000-8000-000000000002', 'ACTIVE', 30, true);
insert into atlas_admin.recipes (recipe_id, dish_id, school_type_id, recipe_status) values
  ('e4100000-0000-0000-0000-000000000009', 'e4100000-0000-0000-0000-000000000008', null, 'ACTIVE'),
  ('e4600000-0000-0000-0000-000000000002', 'e4600000-0000-0000-0000-000000000001', 'e4100000-0000-0000-0000-000000000004', 'ACTIVE'),
  ('e4600000-0000-0000-0000-000000000003', 'e4600000-0000-0000-0000-000000000001', 'e4100000-0000-0000-0000-000000000004', 'ACTIVE'),
  ('e4600000-0000-0000-0000-000000000004', 'e4600000-0000-0000-0000-000000000001', null, 'ACTIVE'),
  ('e4700000-0000-0000-0000-000000000002', 'e4700000-0000-0000-0000-000000000001', null, 'ACTIVE'),
  ('e4700000-0000-0000-0000-000000000003', 'e4700000-0000-0000-0000-000000000001', null, 'ACTIVE');
insert into atlas_admin.recipe_versions (recipe_version_id, recipe_id, version_number, basis_portions, recipe_version_status, created_by_actor_id, validated_by_actor_id, validated_at, released_by_actor_id, released_at)
values
  ('e4100000-0000-0000-0000-000000000010', 'e4100000-0000-0000-0000-000000000009', 1, 100, 'RELEASED_FOR_PLANNING', 'e4000000-0000-0000-0000-000000000001', 'e4000000-0000-0000-0000-000000000001', '2026-11-01 08:00:00+07', 'e4000000-0000-0000-0000-000000000001', '2026-11-01 08:05:00+07'),
  ('e4600000-0000-0000-0000-000000000005', 'e4600000-0000-0000-0000-000000000002', 1, 100, 'RELEASED_FOR_PLANNING', 'e4000000-0000-0000-0000-000000000001', 'e4000000-0000-0000-0000-000000000001', '2026-11-01 08:00:00+07', 'e4000000-0000-0000-0000-000000000001', '2026-11-01 08:05:00+07'),
  ('e4600000-0000-0000-0000-000000000006', 'e4600000-0000-0000-0000-000000000003', 1, 100, 'RELEASED_FOR_PLANNING', 'e4000000-0000-0000-0000-000000000001', 'e4000000-0000-0000-0000-000000000001', '2026-11-01 08:00:00+07', 'e4000000-0000-0000-0000-000000000001', '2026-11-01 08:05:00+07'),
  ('e4600000-0000-0000-0000-000000000007', 'e4600000-0000-0000-0000-000000000004', 1, 100, 'RELEASED_FOR_PLANNING', 'e4000000-0000-0000-0000-000000000001', 'e4000000-0000-0000-0000-000000000001', '2026-11-01 08:00:00+07', 'e4000000-0000-0000-0000-000000000001', '2026-11-01 08:05:00+07'),
  ('e4700000-0000-0000-0000-000000000005', 'e4700000-0000-0000-0000-000000000002', 1, 100, 'RELEASED_FOR_PLANNING', 'e4000000-0000-0000-0000-000000000001', 'e4000000-0000-0000-0000-000000000001', '2026-11-01 08:00:00+07', 'e4000000-0000-0000-0000-000000000001', '2026-11-01 08:05:00+07'),
  ('e4700000-0000-0000-0000-000000000006', 'e4700000-0000-0000-0000-000000000003', 1, 100, 'RELEASED_FOR_PLANNING', 'e4000000-0000-0000-0000-000000000001', 'e4000000-0000-0000-0000-000000000001', '2026-11-01 08:00:00+07', 'e4000000-0000-0000-0000-000000000001', '2026-11-01 08:05:00+07');
insert into atlas_admin.recipe_lines (recipe_line_id, recipe_id, line_code)
values
  ('e4100000-0000-0000-0000-000000000011', 'e4100000-0000-0000-0000-000000000009', 'rice'),
  ('e4100000-0000-0000-0000-000000000014', 'e4100000-0000-0000-0000-000000000009', 'oil'),
  ('e4100000-0000-0000-0000-000000000017', 'e4100000-0000-0000-0000-000000000009', 'carrot'),
  ('e4600000-0000-0000-0000-000000000008', 'e4600000-0000-0000-0000-000000000002', 'rice'),
  ('e4600000-0000-0000-0000-000000000009', 'e4600000-0000-0000-0000-000000000003', 'rice'),
  ('e4600000-0000-0000-0000-000000000010', 'e4600000-0000-0000-0000-000000000004', 'rice'),
  ('e4700000-0000-0000-0000-000000000008', 'e4700000-0000-0000-0000-000000000002', 'rice'),
  ('e4700000-0000-0000-0000-000000000009', 'e4700000-0000-0000-0000-000000000003', 'rice');
insert into atlas_admin.recipe_line_revisions (recipe_line_revision_id, recipe_id, recipe_version_id, recipe_line_id, line_revision_number, ingredient_id, quantity_per_basis, unit_id, created_by_actor_id)
values
  ('e4100000-0000-0000-0000-000000000012', 'e4100000-0000-0000-0000-000000000009', 'e4100000-0000-0000-0000-000000000010', 'e4100000-0000-0000-0000-000000000011', 1, 'e4100000-0000-0000-0000-000000000007', 12.5, 'e4100000-0000-0000-0000-000000000006', 'e4000000-0000-0000-0000-000000000001'),
  ('e4100000-0000-0000-0000-000000000015', 'e4100000-0000-0000-0000-000000000009', 'e4100000-0000-0000-0000-000000000010', 'e4100000-0000-0000-0000-000000000014', 1, 'e4100000-0000-0000-0000-000000000013', 500, 'e4100000-0000-0000-0000-000000000006', 'e4000000-0000-0000-0000-000000000001'),
  ('e4100000-0000-0000-0000-000000000018', 'e4100000-0000-0000-0000-000000000009', 'e4100000-0000-0000-0000-000000000010', 'e4100000-0000-0000-0000-000000000017', 1, 'e4100000-0000-0000-0000-000000000016', 2.5, 'e4100000-0000-0000-0000-000000000006', 'e4000000-0000-0000-0000-000000000001'),
  ('e4600000-0000-0000-0000-000000000011', 'e4600000-0000-0000-0000-000000000002', 'e4600000-0000-0000-0000-000000000005', 'e4600000-0000-0000-0000-000000000008', 1, 'e4100000-0000-0000-0000-000000000007', 12.5, 'e4100000-0000-0000-0000-000000000006', 'e4000000-0000-0000-0000-000000000001'),
  ('e4600000-0000-0000-0000-000000000012', 'e4600000-0000-0000-0000-000000000003', 'e4600000-0000-0000-0000-000000000006', 'e4600000-0000-0000-0000-000000000009', 1, 'e4100000-0000-0000-0000-000000000007', 12.5, 'e4100000-0000-0000-0000-000000000006', 'e4000000-0000-0000-0000-000000000001'),
  ('e4600000-0000-0000-0000-000000000013', 'e4600000-0000-0000-0000-000000000004', 'e4600000-0000-0000-0000-000000000007', 'e4600000-0000-0000-0000-000000000010', 1, 'e4100000-0000-0000-0000-000000000007', 12.5, 'e4100000-0000-0000-0000-000000000006', 'e4000000-0000-0000-0000-000000000001'),
  ('e4700000-0000-0000-0000-000000000011', 'e4700000-0000-0000-0000-000000000002', 'e4700000-0000-0000-0000-000000000005', 'e4700000-0000-0000-0000-000000000008', 1, 'e4100000-0000-0000-0000-000000000007', 12.5, 'e4100000-0000-0000-0000-000000000006', 'e4000000-0000-0000-0000-000000000001'),
  ('e4700000-0000-0000-0000-000000000012', 'e4700000-0000-0000-0000-000000000003', 'e4700000-0000-0000-0000-000000000006', 'e4700000-0000-0000-0000-000000000009', 1, 'e4100000-0000-0000-0000-000000000007', 12.5, 'e4100000-0000-0000-0000-000000000006', 'e4000000-0000-0000-0000-000000000001');

insert into atlas_planning.weekly_menus (weekly_menu_id, week_start, week_end, source_type, source_name, source_signature, row_count, imported_by_actor_id, weekly_menu_status, latest_approved_by_actor_id, latest_approved_at, latest_approval_snapshot_id)
values ('e4200000-0000-0000-0000-000000000001', '2026-11-02', '2026-11-08', 'FIXTURE', 'RMVP-04 menu', 'rmvp04-menu-signature', 6, 'e4000000-0000-0000-0000-000000000001', 'APPROVED', 'e4000000-0000-0000-0000-000000000001', '2026-11-01 09:00:00+07', 'e4200000-0000-0000-0000-000000000002');
insert into atlas_planning.weekly_menu_lines (weekly_menu_line_id, weekly_menu_id, school_id, service_date, menu_slot_code, dish_id, created_by_actor_id, updated_by_actor_id) values
  ('e4200000-0000-0000-0000-000000000003', 'e4200000-0000-0000-0000-000000000001', 'e4100000-0000-0000-0000-000000000005', '2026-11-02', 'savory', 'e4100000-0000-0000-0000-000000000008', 'e4000000-0000-0000-0000-000000000001', 'e4000000-0000-0000-0000-000000000001'),
  ('e4200000-0000-0000-0000-000000000004', 'e4200000-0000-0000-0000-000000000001', 'e4100000-0000-0000-0000-000000000005', '2026-11-03', 'savory', 'e4100000-0000-0000-0000-000000000008', 'e4000000-0000-0000-0000-000000000001', 'e4000000-0000-0000-0000-000000000001'),
  ('e4600000-0000-0000-0000-000000000020', 'e4200000-0000-0000-0000-000000000001', 'e4100000-0000-0000-0000-000000000005', '2026-11-04', 'savory', 'e4600000-0000-0000-0000-000000000001', 'e4000000-0000-0000-0000-000000000001', 'e4000000-0000-0000-0000-000000000001'),
  ('e4600000-0000-0000-0000-000000000021', 'e4200000-0000-0000-0000-000000000001', 'e4100000-0000-0000-0000-000000000005', '2026-11-04', 'soup', 'e4100000-0000-0000-0000-000000000008', 'e4000000-0000-0000-0000-000000000001', 'e4000000-0000-0000-0000-000000000001'),
  ('e4700000-0000-0000-0000-000000000020', 'e4200000-0000-0000-0000-000000000001', 'e4100000-0000-0000-0000-000000000005', '2026-11-05', 'savory', 'e4700000-0000-0000-0000-000000000001', 'e4000000-0000-0000-0000-000000000001', 'e4000000-0000-0000-0000-000000000001'),
  ('e4700000-0000-0000-0000-000000000021', 'e4200000-0000-0000-0000-000000000001', 'e4100000-0000-0000-0000-000000000005', '2026-11-05', 'soup', 'e4100000-0000-0000-0000-000000000008', 'e4000000-0000-0000-0000-000000000001', 'e4000000-0000-0000-0000-000000000001');
insert into atlas_planning.weekly_menu_approval_snapshots (weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version, approved_by_actor_id, approved_at)
values ('e4200000-0000-0000-0000-000000000002', 'e4200000-0000-0000-0000-000000000001', 1, 'e4000000-0000-0000-0000-000000000001', '2026-11-01 09:00:00+07');
insert into atlas_planning.weekly_menu_approval_snapshot_lines (weekly_menu_approval_snapshot_line_id, weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version, weekly_menu_line_id, school_id, service_date, menu_slot_code, dish_id) values
  ('e4200000-0000-0000-0000-000000000005', 'e4200000-0000-0000-0000-000000000002', 'e4200000-0000-0000-0000-000000000001', 1, 'e4200000-0000-0000-0000-000000000003', 'e4100000-0000-0000-0000-000000000005', '2026-11-02', 'savory', 'e4100000-0000-0000-0000-000000000008'),
  ('e4200000-0000-0000-0000-000000000006', 'e4200000-0000-0000-0000-000000000002', 'e4200000-0000-0000-0000-000000000001', 1, 'e4200000-0000-0000-0000-000000000004', 'e4100000-0000-0000-0000-000000000005', '2026-11-03', 'savory', 'e4100000-0000-0000-0000-000000000008'),
  ('e4600000-0000-0000-0000-000000000022', 'e4200000-0000-0000-0000-000000000002', 'e4200000-0000-0000-0000-000000000001', 1, 'e4600000-0000-0000-0000-000000000020', 'e4100000-0000-0000-0000-000000000005', '2026-11-04', 'savory', 'e4600000-0000-0000-0000-000000000001'),
  ('e4600000-0000-0000-0000-000000000023', 'e4200000-0000-0000-0000-000000000002', 'e4200000-0000-0000-0000-000000000001', 1, 'e4600000-0000-0000-0000-000000000021', 'e4100000-0000-0000-0000-000000000005', '2026-11-04', 'soup', 'e4100000-0000-0000-0000-000000000008'),
  ('e4700000-0000-0000-0000-000000000022', 'e4200000-0000-0000-0000-000000000002', 'e4200000-0000-0000-0000-000000000001', 1, 'e4700000-0000-0000-0000-000000000020', 'e4100000-0000-0000-0000-000000000005', '2026-11-05', 'savory', 'e4700000-0000-0000-0000-000000000001'),
  ('e4700000-0000-0000-0000-000000000023', 'e4200000-0000-0000-0000-000000000002', 'e4200000-0000-0000-0000-000000000001', 1, 'e4700000-0000-0000-0000-000000000021', 'e4100000-0000-0000-0000-000000000005', '2026-11-05', 'soup', 'e4100000-0000-0000-0000-000000000008');

insert into atlas_planning.attendance_batches (attendance_batch_id, period_start, period_end, source_type, source_name, source_signature, row_count, imported_by_actor_id, attendance_status, latest_approved_by_actor_id, latest_approved_at, latest_approval_snapshot_id)
values ('e4300000-0000-0000-0000-000000000001', '2026-11-02', '2026-11-08', 'FIXTURE', 'RMVP-04 attendance', 'rmvp04-attendance-signature', 4, 'e4000000-0000-0000-0000-000000000001', 'APPROVED', 'e4000000-0000-0000-0000-000000000001', '2026-11-01 09:05:00+07', 'e4300000-0000-0000-0000-000000000002');
insert into atlas_planning.attendance_lines (attendance_line_id, attendance_batch_id, school_id, service_date, student_portions, teacher_portions, created_by_actor_id, updated_by_actor_id) values
  ('e4300000-0000-0000-0000-000000000003', 'e4300000-0000-0000-0000-000000000001', 'e4100000-0000-0000-0000-000000000005', '2026-11-02', 15, 5, 'e4000000-0000-0000-0000-000000000001', 'e4000000-0000-0000-0000-000000000001'),
  ('e4300000-0000-0000-0000-000000000004', 'e4300000-0000-0000-0000-000000000001', 'e4100000-0000-0000-0000-000000000005', '2026-11-03', 10, 0, 'e4000000-0000-0000-0000-000000000001', 'e4000000-0000-0000-0000-000000000001'),
  ('e4600000-0000-0000-0000-000000000030', 'e4300000-0000-0000-0000-000000000001', 'e4100000-0000-0000-0000-000000000005', '2026-11-04', 10, 2, 'e4000000-0000-0000-0000-000000000001', 'e4000000-0000-0000-0000-000000000001'),
  ('e4700000-0000-0000-0000-000000000030', 'e4300000-0000-0000-0000-000000000001', 'e4100000-0000-0000-0000-000000000005', '2026-11-05', 10, 2, 'e4000000-0000-0000-0000-000000000001', 'e4000000-0000-0000-0000-000000000001');
insert into atlas_planning.attendance_approval_snapshots (attendance_approval_snapshot_id, attendance_batch_id, attendance_version, approved_by_actor_id, approved_at)
values ('e4300000-0000-0000-0000-000000000002', 'e4300000-0000-0000-0000-000000000001', 1, 'e4000000-0000-0000-0000-000000000001', '2026-11-01 09:05:00+07');
insert into atlas_planning.attendance_approval_snapshot_lines (attendance_approval_snapshot_line_id, attendance_approval_snapshot_id, attendance_batch_id, attendance_version, attendance_line_id, school_id, service_date, student_portions, teacher_portions) values
  ('e4300000-0000-0000-0000-000000000005', 'e4300000-0000-0000-0000-000000000002', 'e4300000-0000-0000-0000-000000000001', 1, 'e4300000-0000-0000-0000-000000000003', 'e4100000-0000-0000-0000-000000000005', '2026-11-02', 15, 5),
  ('e4300000-0000-0000-0000-000000000006', 'e4300000-0000-0000-0000-000000000002', 'e4300000-0000-0000-0000-000000000001', 1, 'e4300000-0000-0000-0000-000000000004', 'e4100000-0000-0000-0000-000000000005', '2026-11-03', 10, 0),
  ('e4600000-0000-0000-0000-000000000031', 'e4300000-0000-0000-0000-000000000002', 'e4300000-0000-0000-0000-000000000001', 1, 'e4600000-0000-0000-0000-000000000030', 'e4100000-0000-0000-0000-000000000005', '2026-11-04', 10, 2),
  ('e4700000-0000-0000-0000-000000000031', 'e4300000-0000-0000-0000-000000000002', 'e4300000-0000-0000-0000-000000000001', 1, 'e4700000-0000-0000-0000-000000000030', 'e4100000-0000-0000-0000-000000000005', '2026-11-05', 10, 2);

insert into atlas_planning.pantry_need_purposes (pantry_need_purpose_id, purpose_code, purpose_name_vi, purpose_description, note_rule, purpose_status, display_order)
values ('e4400000-0000-0000-0000-000000000001', 'rmvp04_supplement', 'Bá»• sung RMVP-04', 'Synthetic connected Need Generation fixture.', 'OPTIONAL', 'ACTIVE', 10);
insert into atlas_planning.pantry_need_batches (pantry_need_batch_id, week_start, source_signature, no_additions_confirmed, requesting_actor_id, pantry_need_batch_status, latest_approved_by_actor_id, latest_approved_at, latest_approval_snapshot_id)
values ('e4400000-0000-0000-0000-000000000002', '2026-11-02', repeat('e', 64), false, 'e4000000-0000-0000-0000-000000000001', 'APPROVED', 'e4000000-0000-0000-0000-000000000001', '2026-11-01 09:07:00+07', 'e4400000-0000-0000-0000-000000000003');
insert into atlas_planning.pantry_need_lines (pantry_need_line_id, pantry_need_batch_id, service_date, school_id, delivery_location_id, ingredient_id, unit_id, pantry_need_purpose_id, requested_quantity, note, source_request_reference, source_row_reference, updated_by_actor_id) values
  ('e4400000-0000-0000-0000-000000000004', 'e4400000-0000-0000-0000-000000000002', '2026-11-02', 'e4100000-0000-0000-0000-000000000005', 'e4100000-0000-0000-0000-000000000003', 'e4100000-0000-0000-0000-000000000007', 'e4100000-0000-0000-0000-000000000006', 'e4400000-0000-0000-0000-000000000001', 2, 'Separate Pantry delivery', 'RMVP04', '1', 'e4000000-0000-0000-0000-000000000001'),
  ('e4600000-0000-0000-0000-000000000040', 'e4400000-0000-0000-0000-000000000002', '2026-11-04', 'e4100000-0000-0000-0000-000000000005', 'e4100000-0000-0000-0000-000000000003', 'e4100000-0000-0000-0000-000000000007', 'e4100000-0000-0000-0000-000000000006', 'e4400000-0000-0000-0000-000000000001', 3, 'Typed ambiguity Pantry line', 'RMVP04-TYPED', '1', 'e4000000-0000-0000-0000-000000000001'),
  ('e4700000-0000-0000-0000-000000000040', 'e4400000-0000-0000-0000-000000000002', '2026-11-05', 'e4100000-0000-0000-0000-000000000005', 'e4100000-0000-0000-0000-000000000003', 'e4100000-0000-0000-0000-000000000007', 'e4100000-0000-0000-0000-000000000006', 'e4400000-0000-0000-0000-000000000001', 4, 'General ambiguity Pantry line', 'RMVP04-GENERAL', '1', 'e4000000-0000-0000-0000-000000000001');
insert into atlas_planning.pantry_need_approval_snapshots (pantry_need_approval_snapshot_id, pantry_need_batch_id, approved_batch_version, approved_by_actor_id, approved_at, source_signature, no_additions_confirmed, line_count)
values ('e4400000-0000-0000-0000-000000000003', 'e4400000-0000-0000-0000-000000000002', 1, 'e4000000-0000-0000-0000-000000000001', '2026-11-01 09:07:00+07', repeat('e', 64), false, 3);
/* Replaced below with the relation's composite snapshot/member identity.
insert into atlas_planning.pantry_need_approval_snapshot_lines (pantry_need_approval_snapshot_line_id, pantry_need_approval_snapshot_id, pantry_need_line_id, service_date, school_id, school_code_snapshot, school_name_snapshot, delivery_location_id, delivery_location_code_snapshot, delivery_location_name_snapshot, delivery_location_address_snapshot, ingredient_id, ingredient_code_snapshot, ingredient_name_snapshot, unit_id, unit_code_snapshot, unit_name_snapshot, pantry_need_purpose_id, purpose_code_snapshot, purpose_name_snapshot, purpose_description_snapshot, purpose_note_rule_snapshot, note, source_request_reference, source_row_reference, requested_quantity)
values ('e4400000-0000-0000-0000-000000000005', 'e4400000-0000-0000-0000-000000000003', 'e4400000-0000-0000-0000-000000000004', '2026-11-02', 'e4100000-0000-0000-000000000005', 'rmvp04-school', 'RMVP-04 School', 'e4100000-0000-0000-0000-000000000003', 'rmvp04-pantry', 'RMVP-04 Pantry Store', 'Fixture pantry', 'e4100000-0000-0000-0000-000000000007', 'rmvp04-rice', 'RMVP-04 rice', 'e4100000-0000-0000-0000-000000000006', 'rmvp04-kg', 'RMVP-04 kilogram', 'e4400000-0000-0000-0000-000000000001', 'rmvp04_supplement', 'Bá»• sung RMVP-04', 'Synthetic connected Need Generation fixture.', 'OPTIONAL', 'Separate Pantry delivery', 'RMVP04', '1', 2);

*/
insert into atlas_planning.pantry_need_approval_snapshot_lines (
  pantry_need_approval_snapshot_id,
  pantry_need_line_id,
  service_date,
  school_id,
  school_code_snapshot,
  school_name_snapshot,
  delivery_location_id,
  delivery_location_code_snapshot,
  delivery_location_name_snapshot,
  delivery_location_address_snapshot,
  ingredient_id,
  ingredient_code_snapshot,
  ingredient_name_snapshot,
  unit_id,
  unit_code_snapshot,
  unit_name_snapshot,
  pantry_need_purpose_id,
  purpose_code_snapshot,
  purpose_name_snapshot,
  purpose_description_snapshot,
  purpose_note_rule_snapshot,
  note,
  source_request_reference,
  source_row_reference,
  requested_quantity
) values (
  'e4400000-0000-0000-0000-000000000003',
  'e4400000-0000-0000-0000-000000000004',
  '2026-11-02',
  'e4100000-0000-0000-0000-000000000005',
  'rmvp04-school',
  'RMVP-04 School',
  'e4100000-0000-0000-0000-000000000003',
  'rmvp04-pantry',
  'RMVP-04 Pantry Store',
  'Fixture pantry',
  'e4100000-0000-0000-0000-000000000007',
  'rmvp04-rice',
  'RMVP-04 rice',
  'e4100000-0000-0000-0000-000000000006',
  'rmvp04-kg',
  'RMVP-04 kilogram',
  'e4400000-0000-0000-0000-000000000001',
  'rmvp04_supplement',
  'Bá»• sung RMVP-04',
  'Synthetic connected Need Generation fixture.',
  'OPTIONAL',
  'Separate Pantry delivery',
  'RMVP04',
  '1',
  2
);

insert into atlas_planning.pantry_need_approval_snapshot_lines (
  pantry_need_approval_snapshot_id,
  pantry_need_line_id,
  service_date,
  school_id,
  school_code_snapshot,
  school_name_snapshot,
  delivery_location_id,
  delivery_location_code_snapshot,
  delivery_location_name_snapshot,
  delivery_location_address_snapshot,
  ingredient_id,
  ingredient_code_snapshot,
  ingredient_name_snapshot,
  unit_id,
  unit_code_snapshot,
  unit_name_snapshot,
  pantry_need_purpose_id,
  purpose_code_snapshot,
  purpose_name_snapshot,
  purpose_description_snapshot,
  purpose_note_rule_snapshot,
  note,
  source_request_reference,
  source_row_reference,
  requested_quantity
) values
  (
    'e4400000-0000-0000-0000-000000000003',
    'e4600000-0000-0000-0000-000000000040',
    '2026-11-04',
    'e4100000-0000-0000-0000-000000000005',
    'rmvp04-school',
    'RMVP-04 School',
    'e4100000-0000-0000-0000-000000000003',
    'rmvp04-pantry',
    'RMVP-04 Pantry Store',
    'Fixture pantry',
    'e4100000-0000-0000-0000-000000000007',
    'rmvp04-rice',
    'RMVP-04 rice',
    'e4100000-0000-0000-0000-000000000006',
    'rmvp04-kg',
    'RMVP-04 kilogram',
    'e4400000-0000-0000-0000-000000000001',
    'rmvp04_supplement',
    'BÃ¡Â»â€¢ sung RMVP-04',
    'Synthetic connected Need Generation fixture.',
    'OPTIONAL',
    'Typed ambiguity Pantry line',
    'RMVP04-TYPED',
    '1',
    3
  ),
  (
    'e4400000-0000-0000-0000-000000000003',
    'e4700000-0000-0000-0000-000000000040',
    '2026-11-05',
    'e4100000-0000-0000-0000-000000000005',
    'rmvp04-school',
    'RMVP-04 School',
    'e4100000-0000-0000-0000-000000000003',
    'rmvp04-pantry',
    'RMVP-04 Pantry Store',
    'Fixture pantry',
    'e4100000-0000-0000-0000-000000000007',
    'rmvp04-rice',
    'RMVP-04 rice',
    'e4100000-0000-0000-0000-000000000006',
    'rmvp04-kg',
    'RMVP-04 kilogram',
    'e4400000-0000-0000-0000-000000000001',
    'rmvp04_supplement',
    'BÃ¡Â»â€¢ sung RMVP-04',
    'Synthetic connected Need Generation fixture.',
    'OPTIONAL',
    'General ambiguity Pantry line',
    'RMVP04-GENERAL',
    '1',
    4
  );

insert into atlas_planning.need_generation_calculation_contracts (need_generation_calculation_contract_id, contract_code, current_revision_id, version, created_at, updated_at)
values ('e4400000-0000-0000-0000-000000000010', 'school_catering_proportional_per_basis', 'e4400000-0000-0000-0000-000000000011', 1, '2026-11-01 07:00:00+07', '2026-11-01 07:00:00+07');
insert into atlas_planning.need_generation_calculation_contract_revisions (need_generation_calculation_contract_revision_id, need_generation_calculation_contract_id, revision_number, formula_kind, quantity_precision, quantity_scale, factor_precision, factor_scale, final_coercion_mode, approved_by_actor_id, approved_at)
values ('e4400000-0000-0000-0000-000000000011', 'e4400000-0000-0000-0000-000000000010', 1, 'STUDENT_TEACHER_PORTIONS_X_RECIPE_QTY_DIV_BASIS', 20, 6, 24, 12, 'POSTGRES_NUMERIC_SCALE_HALF_AWAY_FROM_ZERO', 'e4000000-0000-0000-0000-000000000001', '2026-11-01 07:00:00+07');

set local session_replication_role = origin;
set constraints all immediate;
set constraints all deferred;


create temporary table pct01_responses (
  response_name text primary key,
  response jsonb not null
);
grant select, insert, update on pct01_responses to authenticated;

select set_config('request.jwt.claim.sub','e4000000-0000-0000-0000-000000000101',true);

set local role authenticated;
insert into pct01_responses values (
  'preflight-initial',
  atlas_api.get_planning_input_preflight(jsonb_build_object(
    'contract_version','RMVP-03B.v2',
    'requested_by_auth_subject','e4000000-0000-0000-0000-000000000101',
    'correlation_id',gen_random_uuid(),
    'payload',jsonb_build_object(
      'period_start','2026-11-02','period_end','2026-11-02'
    )
  ))
);
reset role;

select ok((select response->>'success'='true' and response->'preflight'->>'readiness_state'='READY' from pct01_responses where response_name='preflight-initial'),'PCT01-19 automatic preflight derives READY');
select is((select response->'preflight'->>'downstream_currentness' from pct01_responses where response_name='preflight-initial'),'NOT_GENERATED','PCT01-20 initial currentness is NOT_GENERATED');
select is((select count(*) from atlas_planning.planning_input_evaluations),0::bigint,'PCT01-21 read-only preflight creates no lifecycle evidence');

create temporary table pct01_requests (
  request_name text primary key,
  request jsonb not null
);
grant select on pct01_requests to authenticated;
insert into pct01_requests values (
  'execute-initial',
  jsonb_build_object(
    'contract_version','RMVP-04.v3',
    'command_id','e4800000-0000-0000-0000-000000000001',
    'correlation_id','e4800000-0000-0000-0000-000000000002',
    'idempotency_key','pct01-execute-initial',
    'expected_version',1,
    'requested_by_auth_subject','e4000000-0000-0000-0000-000000000101',
    'requested_at',transaction_timestamp() + interval '30 seconds',
    'reason_code','NEED_GENERATION_EXECUTED',
    'reason_note',null,
    'payload',jsonb_build_object(
      'service_date','2026-11-02',
      'expected_current_need_generation_run_id',null
    )
  )
);

set local role authenticated;
insert into pct01_responses
select 'execute-initial',atlas_api.execute_need_generation(request)
from pct01_requests where request_name='execute-initial';
reset role;

select ok((select response->>'success'='true' from pct01_responses where response_name='execute-initial'),'PCT01-22 atomic mixed generation accepts bounded positive client skew');
select is((select response->>'contract_version' from pct01_responses where response_name='execute-initial'),'RMVP-04.v3','PCT01-23 atomic response uses the daily RMVP-04.v3 contract');
select is((select response->>'downstream_currentness' from pct01_responses where response_name='execute-initial'),'CURRENT','PCT01-24 committed result is CURRENT');
select is((select count(*) from atlas_core.command_receipts where command_id='e4800000-0000-0000-0000-000000000001'),1::bigint,'PCT01-25 one top-level receipt exists');
select is((select command_name from atlas_core.command_receipts where command_id='e4800000-0000-0000-0000-000000000001'),'execute_need_generation','PCT01-26 receipt owns the public generation intent');
select is((select run_status from atlas_planning.need_generation_runs where need_generation_run_id=(select (response->'affected_aggregate_ids'->>'need_generation_run_id')::uuid from pct01_responses where response_name='execute-initial')),'RELEASED_FOR_CONFIRMATION','PCT01-27 run is deterministically validated and released');
select ok((
  select snapshot.weekly_menu_approval_snapshot_id='e4200000-0000-0000-0000-000000000002'
    and snapshot.attendance_approval_snapshot_id='e4300000-0000-0000-0000-000000000002'
    and snapshot.pantry_need_approval_snapshot_id='e4400000-0000-0000-0000-000000000003'
  from atlas_planning.need_generation_input_snapshots snapshot
  where snapshot.need_generation_run_id=(select (response->'affected_aggregate_ids'->>'need_generation_run_id')::uuid from pct01_responses where response_name='execute-initial')
),'PCT01-28 exact completed source identities are bound');
select is((
  select array_agg(distinct contribution_family order by contribution_family)::text[]
  from atlas_planning.theoretical_need_lines
  where need_generation_run_id=(select (response->'affected_aggregate_ids'->>'need_generation_run_id')::uuid from pct01_responses where response_name='execute-initial')
),array['PANTRY_DIRECT','RECIPE_DERIVED']::text[],'PCT01-29 mixed Recipe and Pantry families are generated');
select is((
  select sum(theoretical_quantity) from atlas_planning.theoretical_need_lines
  where need_generation_run_id=(select (response->'affected_aggregate_ids'->>'need_generation_run_id')::uuid from pct01_responses where response_name='execute-initial')
    and contribution_family='RECIPE_DERIVED' and line_disposition='ACTIVE'
    and ingredient_id='e4100000-0000-0000-0000-000000000007'
),2.500000::numeric,'PCT01-30 Recipe quantity is exact');
select is((
  select sum(theoretical_quantity) from atlas_planning.theoretical_need_lines
  where need_generation_run_id=(select (response->'affected_aggregate_ids'->>'need_generation_run_id')::uuid from pct01_responses where response_name='execute-initial')
    and contribution_family='PANTRY_DIRECT' and line_disposition='ACTIVE'
),2.000000::numeric,'PCT01-31 Pantry quantity is exact');
select is((
  select count(*) from atlas_planning.need_generation_release_snapshot_lines
  where need_generation_run_id=(select (response->'affected_aggregate_ids'->>'need_generation_run_id')::uuid from pct01_responses where response_name='execute-initial')
),4::bigint,'PCT01-32 immutable release membership is every generated line');
select is((
  select batch_status from atlas_planning.confirmed_need_batches
  where confirmed_need_batch_id=(select (response->'affected_aggregate_ids'->>'confirmed_need_batch_id')::uuid from pct01_responses where response_name='execute-initial')
),'DRAFT_REVIEW','PCT01-33 Confirmed Need remains at the human review boundary');
select is((
  select count(*) from atlas_planning.confirmed_need_lines
  where confirmed_need_batch_id=(select (response->'affected_aggregate_ids'->>'confirmed_need_batch_id')::uuid from pct01_responses where response_name='execute-initial')
),4::bigint,'PCT01-34 H0C grouping preserves ingredient and delivery-location identity');
select is((
  select count(*) from atlas_planning.confirmed_need_line_revision_contributions
  where confirmed_need_batch_id=(select (response->'affected_aggregate_ids'->>'confirmed_need_batch_id')::uuid from pct01_responses where response_name='execute-initial')
),4::bigint,'PCT01-35 H0C membership retains every theoretical contribution');
select is((
  select array_agg(distinct service_date order by service_date)::text[]
  from atlas_planning.theoretical_need_lines
  where need_generation_run_id=(select (response->'affected_aggregate_ids'->>'need_generation_run_id')::uuid from pct01_responses where response_name='execute-initial')
),array['2026-11-02']::text[],'PCT01-D01 daily theoretical lines contain only the commanded service date');
select ok((
  select period_start=period_end and period_start='2026-11-02'
  from atlas_planning.need_generation_runs
  where need_generation_run_id=(select (response->'affected_aggregate_ids'->>'need_generation_run_id')::uuid from pct01_responses where response_name='execute-initial')
),'PCT01-D02 daily Need run persists as D..D');
select ok((
  select period_start=period_end and period_start='2026-11-02'
  from atlas_planning.confirmed_need_batches
  where confirmed_need_batch_id=(select (response->'affected_aggregate_ids'->>'confirmed_need_batch_id')::uuid from pct01_responses where response_name='execute-initial')
),'PCT01-D03 daily Confirmed Need persists as D..D');
select is((
  select count(*) from atlas_planning.need_generation_runs
  where period_start='2026-11-03' and period_end='2026-11-03'
),0::bigint,'PCT01-D04 Monday generation creates no Tuesday Need');
select ok(exists(select 1 from atlas_audit.domain_events where command_id='e4800000-0000-0000-0000-000000000001' and event_type='NeedGenerationExecuted'),'PCT01-36 composite execution event exists');
select ok(exists(select 1 from atlas_audit.domain_events where command_id='e4800000-0000-0000-0000-000000000001' and event_type='ConfirmedNeedsCreated'),'PCT01-37 internal H0C evidence is retained');

set local role authenticated;
insert into pct01_responses
select 'execute-replay',atlas_api.execute_need_generation(request)
from pct01_requests where request_name='execute-initial';
reset role;
select is((select response from pct01_responses where response_name='execute-replay'),(select response from pct01_responses where response_name='execute-initial'),'PCT01-38 exact replay returns the committed response');
select is((select count(*) from atlas_core.command_receipts where command_id='e4800000-0000-0000-0000-000000000001'),1::bigint,'PCT01-39 replay creates no receipt');
set local role authenticated;
insert into pct01_responses
select 'execute-conflict',atlas_api.execute_need_generation(request||jsonb_build_object('idempotency_key','pct01-changed'))
from pct01_requests where request_name='execute-initial';
reset role;
select is((select response->>'error_code' from pct01_responses where response_name='execute-conflict'),'IDEMPOTENCY_CONFLICT','PCT01-40 changed command reuse is rejected');

-- PLANNING-CONTRACT-02B integration setup: bind all current lines to one exact
-- policy, save one adjusted and one accepted human decision, then let the real
-- public correction below decide continuity from aggregate business facts.
insert into atlas_planning.planning_quantity_policies (
  planning_quantity_policy_id, unit_id, created_by_actor_id
) values (
  'e4810000-0000-0000-0000-000000000001',
  'e4100000-0000-0000-0000-000000000006',
  'e4000000-0000-0000-0000-000000000001'
);
insert into atlas_planning.planning_quantity_policy_revisions (
  planning_quantity_policy_revision_id, planning_quantity_policy_id, unit_id,
  revision_number, predecessor_policy_revision_id, planning_step,
  effective_from, policy_revision_status, created_by_actor_id, created_at
) values (
  'e4810000-0000-0000-0000-000000000002',
  'e4810000-0000-0000-0000-000000000001',
  'e4100000-0000-0000-0000-000000000006',
  1, null, 0.500000, '2026-01-01', 'DRAFT',
  'e4000000-0000-0000-0000-000000000001', transaction_timestamp()
);
update atlas_planning.planning_quantity_policy_revisions
set policy_revision_status='ACTIVE',
    approved_by_actor_id='e4000000-0000-0000-0000-000000000001',
    approved_at=transaction_timestamp(),
    activated_by_actor_id='e4000000-0000-0000-0000-000000000001',
    activated_at=transaction_timestamp()
where planning_quantity_policy_revision_id=
  'e4810000-0000-0000-0000-000000000002';

insert into atlas_core.role_capabilities (role_id, capability_id)
select 'e4000000-0000-0000-0000-000000000020', capability.capability_id
from atlas_core.capabilities capability
where capability.capability_code in (
  'confirmed_need_review.read',
  'confirmed_need_quantities.preview',
  'confirmed_need_quantities.confirm'
)
on conflict (role_id, capability_id) do nothing;

insert into pct01_requests
select '02b-save-initial', pg_catalog.jsonb_build_object(
  'contract_version','RMVP-05.v2',
  'command_id','e4810000-0000-0000-0000-000000000010',
  'correlation_id','e4810000-0000-0000-0000-000000000011',
  'idempotency_key','pct02b-save-initial',
  'expected_version',1,
  'requested_by_auth_subject','e4000000-0000-0000-0000-000000000101',
  'requested_at',transaction_timestamp(),
  'reason_code','CONFIRMED_NEED_SAVED',
  'reason_note',null,
  'payload',pg_catalog.jsonb_build_object(
    'confirmed_need_batch_id', batch.confirmed_need_batch_id,
    'lines', (
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'confirmed_need_line_id', line.confirmed_need_line_id,
        'expected_current_revision_id', revision.confirmed_need_line_revision_id,
        'expected_current_decision_id', null,
        'proposed_confirmed_quantity', case
          when line.ingredient_id='e4100000-0000-0000-0000-000000000013'
            then '98.000000'
          else revision.confirmed_quantity::text end,
        'reason_code', case
          when line.ingredient_id='e4100000-0000-0000-0000-000000000013'
            then 'OPERATIONAL_QUANTITY_ADJUSTMENT'
          else 'PROPOSAL_ACCEPTED' end,
        'reason_note', case
          when line.ingredient_id='e4100000-0000-0000-0000-000000000013'
            then 'Approved operational yield allowance'
          else null end
      ) order by line.confirmed_need_line_id)
      from atlas_planning.confirmed_need_lines line
      join atlas_planning.confirmed_need_line_revisions revision
        on revision.confirmed_need_line_id=line.confirmed_need_line_id
       and revision.is_current
      where line.confirmed_need_batch_id=batch.confirmed_need_batch_id
    )
  )
)
from atlas_planning.confirmed_need_batches batch
where batch.confirmed_need_batch_id=(
  select (response->'affected_aggregate_ids'->>'confirmed_need_batch_id')::uuid
  from pct01_responses where response_name='execute-initial'
);

set local role authenticated;
insert into pct01_responses
select '02b-save-initial', atlas_api.save_confirmed_needs(request)
from pct01_requests where request_name='02b-save-initial';
reset role;

create temporary table pct02b_original_decisions as
select line.confirmed_need_line_id, line.delivery_location_id, line.ingredient_id,
  revision.theoretical_quantity,
  decision.confirmed_need_line_decision_id, decision.confirmed_quantity_after,
  decision.reason_code, decision.reason_note, decision.decided_by_actor_id,
  decision.decided_at
from atlas_planning.confirmed_need_lines line
join atlas_planning.confirmed_need_line_decisions decision
  on decision.confirmed_need_line_decision_id=
    line.current_confirmed_need_line_decision_id
join atlas_planning.confirmed_need_line_revisions revision
  on revision.confirmed_need_line_revision_id=
    decision.confirmed_need_line_revision_id
where line.confirmed_need_batch_id=(
  select (response->'affected_aggregate_ids'->>'confirmed_need_batch_id')::uuid
  from pct01_responses where response_name='execute-initial'
);

select ok((select response->>'success'='true' from pct01_responses
  where response_name='02b-save-initial'),
  'PCT02B-01 all initial human decisions save through RMVP-05.v2');
select is((select count(*) from pct02b_original_decisions),4::bigint,
  'PCT02B-02 every predecessor current line has human authority');
select is((select count(*) from pct02b_original_decisions
  where reason_code='OPERATIONAL_QUANTITY_ADJUSTMENT'
    and theoretical_quantity=100.000000
    and confirmed_quantity_after=98.000000),1::bigint,
  'PCT02B-03 exact 100-to-98 human adjustment is recorded before correction');

set local role authenticated;
insert into pct01_responses values (
  'preflight-missing',
  atlas_api.get_planning_input_preflight(jsonb_build_object(
    'contract_version','RMVP-03B.v2',
    'requested_by_auth_subject','e4000000-0000-0000-0000-000000000101',
    'correlation_id',gen_random_uuid(),
    'payload',jsonb_build_object(
      'period_start','2026-12-01','period_end','2026-12-01'
    )
  ))
);
insert into pct01_responses values (
  'execute-missing',
  atlas_api.execute_need_generation(jsonb_build_object(
    'contract_version','RMVP-04.v2',
    'command_id','e4800000-0000-0000-0000-000000000010',
    'correlation_id','e4800000-0000-0000-0000-000000000011',
    'idempotency_key','pct01-execute-missing',
    'expected_version',1,
    'requested_by_auth_subject','e4000000-0000-0000-0000-000000000101',
    'requested_at',transaction_timestamp(),
    'reason_code','NEED_GENERATION_EXECUTED',
    'reason_note',null,
    'payload',jsonb_build_object(
      'period_start','2026-12-01','period_end','2026-12-01',
      'expected_current_need_generation_run_id',null
    )
  ))
);
reset role;
select is((select response->'preflight'->>'readiness_state' from pct01_responses where response_name='preflight-missing'),'BLOCKED','PCT01-41 MISSING sources remain blocked');
select is((select response->>'error_code' from pct01_responses where response_name='execute-missing'),'PLANNING_INPUTS_NOT_READY','PCT01-42 blocked execute returns all-source preflight error');
select is((select count(*) from atlas_planning.need_generation_runs where period_start='2026-12-01'),0::bigint,'PCT01-43 blocker creates no partial run');
select is((select count(*) from atlas_planning.confirmed_need_batches where period_start='2026-12-01'),0::bigint,'PCT01-44 blocker creates no partial Confirmed Need');

with proposed(rows) as (
  values (jsonb_build_array(
    jsonb_build_object(
      'service_date','2026-11-02','school_id','e4100000-0000-0000-0000-000000000005',
      'ingredient_id','e4100000-0000-0000-0000-000000000007',
      'pantry_need_purpose_id','e4400000-0000-0000-0000-000000000001',
      'requested_quantity','2.500000','note','Separate Pantry delivery corrected',
      'source_request_reference','RMVP04','source_row_reference','1'
    ),
    jsonb_build_object(
      'service_date','2026-11-04','school_id','e4100000-0000-0000-0000-000000000005',
      'ingredient_id','e4100000-0000-0000-0000-000000000007',
      'pantry_need_purpose_id','e4400000-0000-0000-0000-000000000001',
      'requested_quantity','3.000000','note','Typed ambiguity Pantry line',
      'source_request_reference','RMVP04-TYPED','source_row_reference','1'
    ),
    jsonb_build_object(
      'service_date','2026-11-05','school_id','e4100000-0000-0000-0000-000000000005',
      'ingredient_id','e4100000-0000-0000-0000-000000000007',
      'pantry_need_purpose_id','e4400000-0000-0000-0000-000000000001',
      'requested_quantity','4.000000','note','General ambiguity Pantry line',
      'source_request_reference','RMVP04-GENERAL','source_row_reference','1'
    ),
    jsonb_build_object(
      'service_date','2026-11-02','school_id','e4100000-0000-0000-0000-000000000005',
      'ingredient_id','e4100000-0000-0000-0000-000000000019',
      'pantry_need_purpose_id','e4400000-0000-0000-0000-000000000001',
      'requested_quantity','1.500000','note','New Potato requirement',
      'source_request_reference','RMVP04-POTATO','source_row_reference','1'
    ),
    jsonb_build_object(
      'service_date','2026-11-02','school_id','e4100000-0000-0000-0000-000000000005',
      'ingredient_id','e4100000-0000-0000-0000-000000000020',
      'pantry_need_purpose_id','e4400000-0000-0000-0000-000000000001',
      'requested_quantity','1.000000','note','Temporary reviewed Spinach requirement',
      'source_request_reference','RMVP04-SPINACH','source_row_reference','1'
    ),
    jsonb_build_object(
      'service_date','2026-11-02','school_id','e4100000-0000-0000-0000-000000000005',
      'ingredient_id','e4100000-0000-0000-0000-000000000021',
      'pantry_need_purpose_id','e4400000-0000-0000-0000-000000000001',
      'requested_quantity','0.750000','note','Temporary unreviewed Celery requirement',
      'source_request_reference','RMVP04-CELERY','source_row_reference','1'
    )
  ))
), canonical(raw_rows, canonical_rows) as (
  select rows, atlas_core.pantry_02_canonical_rows('2026-11-02', rows)
  from proposed
)
insert into pct01_requests
select 'pantry-source-correction', jsonb_build_object(
  'contract_version','PANTRY-02.v2',
  'command_id','e4800000-0000-0000-0000-000000000030',
  'correlation_id','e4800000-0000-0000-0000-000000000031',
  'idempotency_key','pct01-pantry-source-correction',
  'expected_version',1,
  'requested_by_auth_subject','e4000000-0000-0000-0000-000000000101',
  'requested_at',transaction_timestamp(),
  'reason_code','PANTRY_SAVED',
  'reason_note','Upstream correction acceptance',
  'payload',jsonb_build_object(
    'week_start','2026-11-02','no_additions_confirmed',false,
    'source_signature',atlas_core.pantry_02_signature('2026-11-02',false,canonical_rows),
    'expected_source_signature',repeat('e',64),'rows',raw_rows
  )
)
from canonical;

set local role authenticated;
insert into pct01_responses
select 'pantry-source-correction', atlas_api.save_pantry(request)
from pct01_requests where request_name='pantry-source-correction';
reset role;
select ok((select response->>'success'='true' from pct01_responses where response_name='pantry-source-correction'),'PCT01-S01 consequential Pantry correction completes atomically');
select is((select response->>'downstream_currentness' from pct01_responses where response_name='pantry-source-correction'),'OUTDATED','PCT01-S02 Pantry successor Save reports consumed Need as OUTDATED');

set local role authenticated;
insert into pct01_responses values (
  'preflight-outdated',
  atlas_api.get_planning_input_preflight(jsonb_build_object(
    'contract_version','RMVP-03B.v2',
    'requested_by_auth_subject','e4000000-0000-0000-0000-000000000101',
    'correlation_id',gen_random_uuid(),
    'payload',jsonb_build_object('period_start','2026-11-02','period_end','2026-11-02')
  ))
);
reset role;
select is((select response->'preflight'->>'downstream_currentness' from pct01_responses where response_name='preflight-outdated'),'OUTDATED','PCT01-45 successor source identity makes Need OUTDATED');
select is((select count(*) from atlas_planning.pantry_need_approval_snapshots where pantry_need_batch_id='e4400000-0000-0000-0000-000000000002'),2::bigint,'PCT01-46 prior source snapshot remains immutable');

insert into pct01_requests
select 'execute-correction',jsonb_build_object(
  'contract_version','RMVP-04.v3',
  'command_id','e4800000-0000-0000-0000-000000000020',
  'correlation_id','e4800000-0000-0000-0000-000000000021',
  'idempotency_key','pct01-execute-correction',
  'expected_version',(response->'new_versions'->>'need_generation_run_version')::bigint,
  'requested_by_auth_subject','e4000000-0000-0000-0000-000000000101',
  'requested_at',transaction_timestamp(),
  'reason_code','UPSTREAM_SOURCE_CHANGED',
  'reason_note','Pantry successor',
  'payload',jsonb_build_object(
    'service_date','2026-11-02',
    'expected_current_need_generation_run_id',response->'affected_aggregate_ids'->>'need_generation_run_id'
  )
)
from pct01_responses where response_name='execute-initial';

set local role authenticated;
insert into pct01_responses
select 'execute-correction',atlas_api.execute_need_generation(request)
from pct01_requests where request_name='execute-correction';
reset role;
select ok((select response->>'success'='true' from pct01_responses where response_name='execute-correction'),'PCT01-47 atomic successor correction succeeds');
select is((
  select predecessor_need_generation_run_id
  from atlas_planning.need_generation_runs
  where need_generation_run_id=(select (response->'affected_aggregate_ids'->>'need_generation_run_id')::uuid from pct01_responses where response_name='execute-correction')
),(select (response->'affected_aggregate_ids'->>'need_generation_run_id')::uuid from pct01_responses where response_name='execute-initial'),'PCT01-48 successor points directly to prior run');
select is((select count(*) from atlas_planning.need_generation_release_snapshots),2::bigint,'PCT01-49 prior immutable release remains');
select is((select response->'affected_aggregate_ids'->>'confirmed_need_batch_id' from pct01_responses where response_name='execute-correction'),(select response->'affected_aggregate_ids'->>'confirmed_need_batch_id' from pct01_responses where response_name='execute-initial'),'PCT01-50 correction reuses the accepted Confirmed Need batch');
select is((select (response->'new_versions'->>'confirmed_need_batch_version')::bigint from pct01_responses where response_name='execute-correction'),3::bigint,'PCT01-51 Confirmed Need correction advances one version after the human Save');
select is((select response->'authoritative_readback'->'preflight'->>'downstream_currentness' from pct01_responses where response_name='execute-correction'),'CURRENT','PCT01-52 corrected result is CURRENT');
select is((
  select run_status from atlas_planning.need_generation_runs
  where need_generation_run_id=(select (response->'affected_aggregate_ids'->>'need_generation_run_id')::uuid from pct01_responses where response_name='execute-initial')
),'INVALIDATED','PCT01-53 prior run is invalidated without deletion');
select is((
  select run_status from atlas_planning.need_generation_runs
  where need_generation_run_id=(select (response->'affected_aggregate_ids'->>'need_generation_run_id')::uuid from pct01_responses where response_name='execute-correction')
),'RELEASED_FOR_CONFIRMATION','PCT01-54 successor run is released');
select is((select count(*) from atlas_core.command_receipts where command_id='e4800000-0000-0000-0000-000000000020'),1::bigint,'PCT01-55 correction owns one receipt');
select is((select count(*) from atlas_planning.planning_input_evaluations),2::bigint,'PCT01-56 automatic readiness preserves both evaluations');
select is((select count(*) from atlas_planning.pantry_need_approval_snapshot_lines where pantry_need_approval_snapshot_id='e4400000-0000-0000-0000-000000000003'),3::bigint,'PCT01-57 prior source membership is unchanged');
select ok(exists(
  select 1 from atlas_planning.confirmed_need_line_revisions revision
  where revision.confirmed_need_batch_id=(select (response->'affected_aggregate_ids'->>'confirmed_need_batch_id')::uuid from pct01_responses where response_name='execute-correction')
    and not revision.is_current
),'PCT01-58 superseded Confirmed Need revisions remain historical');
select ok(not exists(
  select 1 from atlas_planning.confirmed_need_line_revision_contributions contribution
  join atlas_planning.confirmed_need_line_revisions revision
    on revision.confirmed_need_line_revision_id=contribution.confirmed_need_line_revision_id
  where contribution.confirmed_need_batch_id=(select (response->'affected_aggregate_ids'->>'confirmed_need_batch_id')::uuid from pct01_responses where response_name='execute-correction')
    and revision.is_current
    and contribution.need_generation_run_id<>(select (response->'affected_aggregate_ids'->>'need_generation_run_id')::uuid from pct01_responses where response_name='execute-correction')
),'PCT01-59 current contribution membership points only to the successor');
select ok(exists(select 1 from atlas_audit.domain_events where command_id='e4800000-0000-0000-0000-000000000020' and event_type='ConfirmedNeedsRematerialized'),'PCT01-60 correction retains H0C domain evidence');

select is((select response->'result_counts'->>'carried_forward_count'
  from pct01_responses where response_name='execute-correction'),'2',
  'PCT02B-04 public correction reports two backend-carried decisions');
select is((select response->'result_counts'->>'needs_review_count'
  from pct01_responses where response_name='execute-correction'),'4',
  'PCT02B-05 public correction reports only changed and three new lines for review');
select is((select response->'result_counts'->>'changed_count'
  from pct01_responses where response_name='execute-correction'),'1',
  'PCT02B-06 public correction reports one materially changed line');
select is((select response->'result_counts'->>'new_count'
  from pct01_responses where response_name='execute-correction'),'3',
  'PCT02B-07 correction reports all three exact new aggregates');
select is((select response->'result_counts'->>'removed_count'
  from pct01_responses where response_name='execute-correction'),'1',
  'PCT02B-08 correction reports the exact removed aggregate');
select is((
  select count(*)
  from atlas_planning.confirmed_need_line_decision_continuity continuity
  where continuity.command_id='e4800000-0000-0000-0000-000000000020'
    and continuity.continuity_kind='CARRIED_FORWARD'
),2::bigint,'PCT02B-09 both unchanged aggregates get exact CARRIED_FORWARD evidence');
select is((
  select count(*)
  from atlas_planning.confirmed_need_line_decision_continuity continuity
  where continuity.command_id='e4800000-0000-0000-0000-000000000020'
    and continuity.continuity_kind='INVALIDATED_PROPOSAL_CHANGE'
),1::bigint,'PCT02B-10 changed aggregate gets exact proposal invalidation evidence');
select ok((
  select bool_and(
    case continuity.continuity_kind
      when 'CARRIED_FORWARD' then
        line.current_confirmed_need_line_decision_id=
          original.confirmed_need_line_decision_id
        and revision.confirmed_quantity=original.confirmed_quantity_after
      else line.current_confirmed_need_line_decision_id is null end
  )
  from atlas_planning.confirmed_need_line_decision_continuity continuity
  join atlas_planning.confirmed_need_lines line
    on line.confirmed_need_line_id=continuity.confirmed_need_line_id
  left join atlas_planning.confirmed_need_line_revisions revision
    on revision.confirmed_need_line_id=line.confirmed_need_line_id
   and revision.is_current
  join pct02b_original_decisions original
    on original.confirmed_need_line_id=line.confirmed_need_line_id
  where continuity.command_id='e4800000-0000-0000-0000-000000000020'
), 'PCT02B-11 carry preserves authority and quantity while change clears only affected authority');
select is((
  select count(*)
  from atlas_planning.confirmed_need_line_decisions decision
  join pct02b_original_decisions original
    on original.confirmed_need_line_decision_id=
      decision.confirmed_need_line_decision_id
  where row(decision.reason_code,decision.reason_note,
      decision.decided_by_actor_id,decision.decided_at)
    is not distinct from row(original.reason_code,original.reason_note,
      original.decided_by_actor_id,original.decided_at)
),4::bigint,'PCT02B-12 original human reason, actor, and time remain immutable');
select is((
  select count(*)
  from atlas_planning.confirmed_need_line_decisions decision
  where decision.command_id='e4800000-0000-0000-0000-000000000020'
),0::bigint,'PCT02B-13 system carry manufactures no human decision');

set local role authenticated;
insert into pct01_responses values (
  '02b-read-after-correction',
  atlas_api.get_confirmed_need_review(pg_catalog.jsonb_build_object(
    'contract_version','RMVP-05.v1',
    'requested_by_auth_subject','e4000000-0000-0000-0000-000000000101',
    'correlation_id',gen_random_uuid(),
    'payload',pg_catalog.jsonb_build_object(
      'confirmed_need_batch_id',(
        select response->'affected_aggregate_ids'->>'confirmed_need_batch_id'
        from pct01_responses where response_name='execute-correction'
      ),
      'filters','{}'::jsonb,'line_offset',0,'line_limit',100
    )
  ))
);
reset role;

select is((
  select response->'workbench'->'line_counts'
  from pct01_responses where response_name='02b-read-after-correction'
),pg_catalog.jsonb_build_object(
  'total',6,'unreviewed',4,'confirmed',2,'adjusted',1,
  'carried_forward',2,'needs_review',4,'changed',1,'new',3,'removed',1
),'PCT02B-14 authoritative read-model counts preserve compatibility and add 02B state');
select is((
  select array_agg(line->>'confirmation_state' order by line->>'confirmation_state')
  from pct01_responses readback
  cross join lateral pg_catalog.jsonb_array_elements(
    readback.response->'workbench'->'lines'
  ) line
  where readback.response_name='02b-read-after-correction'
),array['CARRIED_FORWARD','CARRIED_FORWARD','CHANGED','NEW','NEW','NEW']::text[],
  'PCT02B-15 backend classifies carried, changed, and new current lines exactly');
select throws_ok(
  $$update atlas_planning.confirmed_need_line_decision_continuity
    set recorded_at=recorded_at
    where command_id='e4800000-0000-0000-0000-000000000020'$$,
  '55000','Confirmed Need decision continuity evidence is immutable and undeletable',
  'PCT02B-16 continuity evidence rejects update');
select throws_ok(
  $$delete from atlas_planning.confirmed_need_line_decision_continuity
    where command_id='e4800000-0000-0000-0000-000000000020'$$,
  '55000','Confirmed Need decision continuity evidence is immutable and undeletable',
  'PCT02B-17 continuity evidence rejects delete');
select throws_ok(
  $$update atlas_planning.confirmed_need_lines
    set current_confirmed_need_line_decision_id=null
    where current_confirmed_need_line_decision_id is not null$$,
  '23514','Decision authority may be cleared only by exact immutable invalidation evidence',
  'PCT02B-18 arbitrary pointer clearing remains rejected');

insert into pct01_requests
select '02b-confirm-temporary-spinach', jsonb_build_object(
  'contract_version','RMVP-05.v2',
  'command_id','e4820000-0000-0000-0000-000000000005',
  'correlation_id','e4820000-0000-0000-0000-000000000006',
  'idempotency_key','pct02b-confirm-temporary-spinach',
  'expected_version',(
    select (response->'new_versions'->>'confirmed_need_batch_version')::bigint
    from pct01_responses where response_name='execute-correction'
  ),
  'requested_by_auth_subject','e4000000-0000-0000-0000-000000000101',
  'requested_at',transaction_timestamp(),
  'reason_code','CONFIRMED_NEED_SAVED','reason_note',null,
  'payload',jsonb_build_object(
    'confirmed_need_batch_id', line.confirmed_need_batch_id,
    'lines',jsonb_build_array(jsonb_build_object(
      'confirmed_need_line_id',line.confirmed_need_line_id,
      'expected_current_revision_id',revision.confirmed_need_line_revision_id,
      'expected_current_decision_id',null,
      'proposed_confirmed_quantity',revision.confirmed_quantity::text,
      'reason_code','PROPOSAL_ACCEPTED','reason_note',null
    ))
  )
)
from atlas_planning.confirmed_need_lines line
join atlas_planning.confirmed_need_line_revisions revision
  on revision.confirmed_need_line_id=line.confirmed_need_line_id
 and revision.is_current
where line.confirmed_need_batch_id=(
    select (response->'affected_aggregate_ids'->>'confirmed_need_batch_id')::uuid
    from pct01_responses where response_name='execute-correction'
  )
  and line.ingredient_id='e4100000-0000-0000-0000-000000000020';

set local role authenticated;
insert into pct01_responses
select '02b-confirm-temporary-spinach',atlas_api.save_confirmed_needs(request)
from pct01_requests where request_name='02b-confirm-temporary-spinach';
reset role;

select is((
  select jsonb_build_object(
    'success',response->>'success',
    'decisions',(
      select count(*)
      from atlas_planning.confirmed_need_lines line
      where line.ingredient_id='e4100000-0000-0000-0000-000000000020'
        and line.current_confirmed_need_line_decision_id is not null
    )
  )
  from pct01_responses where response_name='02b-confirm-temporary-spinach'
),jsonb_build_object('success','true','decisions',1),
  'PCT02B-18A temporary Spinach has one real human decision before its removal');

-- A later source version returns Rice to its original proposal. The run-1
-- decision was invalidated in run 2, so it must not resurrect. Oil and Carrot
-- continue from the direct predecessor while prior-unreviewed Potato remains
-- unreviewed. This correction also removes reviewed Spinach and one unreviewed
-- business fact, but only Spinach may receive decision-invalidation evidence.
with proposed(rows) as (
  values (jsonb_build_array(
    jsonb_build_object(
      'service_date','2026-11-04','school_id','e4100000-0000-0000-0000-000000000005',
      'ingredient_id','e4100000-0000-0000-0000-000000000007',
      'pantry_need_purpose_id','e4400000-0000-0000-0000-000000000001',
      'requested_quantity','3.000000','note','Typed ambiguity Pantry line',
      'source_request_reference','RMVP04-TYPED','source_row_reference','1'
    ),
    jsonb_build_object(
      'service_date','2026-11-05','school_id','e4100000-0000-0000-0000-000000000005',
      'ingredient_id','e4100000-0000-0000-0000-000000000007',
      'pantry_need_purpose_id','e4400000-0000-0000-0000-000000000001',
      'requested_quantity','4.000000','note','General ambiguity Pantry line',
      'source_request_reference','RMVP04-GENERAL','source_row_reference','1'
    ),
    jsonb_build_object(
      'service_date','2026-11-02','school_id','e4100000-0000-0000-0000-000000000005',
      'ingredient_id','e4100000-0000-0000-0000-000000000019',
      'pantry_need_purpose_id','e4400000-0000-0000-0000-000000000001',
      'requested_quantity','1.500000','note','New Potato requirement',
      'source_request_reference','RMVP04-POTATO','source_row_reference','1'
    )
  ))
), canonical(raw_rows, canonical_rows) as (
  select rows, atlas_core.pantry_02_canonical_rows('2026-11-02', rows)
  from proposed
)
insert into pct01_requests
select '02b-source-run3', jsonb_build_object(
  'contract_version','PANTRY-02.v2',
  'command_id','e4820000-0000-0000-0000-000000000001',
  'correlation_id','e4820000-0000-0000-0000-000000000002',
  'idempotency_key','pct02b-source-run3',
  'expected_version',(
    select (response->'new_versions'->>'aggregate_version')::bigint
    from pct01_responses where response_name='pantry-source-correction'
  ),
  'requested_by_auth_subject','e4000000-0000-0000-0000-000000000101',
  'requested_at',transaction_timestamp(),
  'reason_code','PANTRY_SAVED','reason_note','Return Rice to Recipe-only need',
  'payload',jsonb_build_object(
    'week_start','2026-11-02','no_additions_confirmed',false,
    'source_signature',atlas_core.pantry_02_signature('2026-11-02',false,canonical_rows),
    'expected_source_signature',(
      select request#>>'{payload,source_signature}' from pct01_requests
      where request_name='pantry-source-correction'
    ),
    'rows',raw_rows
  )
)
from canonical;

set local role authenticated;
insert into pct01_responses
select '02b-source-run3',atlas_api.save_pantry(request)
from pct01_requests where request_name='02b-source-run3';
reset role;

insert into pct01_requests
select '02b-execute-run3',jsonb_build_object(
  'contract_version','RMVP-04.v2',
  'command_id','e4820000-0000-0000-0000-000000000010',
  'correlation_id','e4820000-0000-0000-0000-000000000011',
  'idempotency_key','pct02b-execute-run3',
  'expected_version',(response->'new_versions'->>'need_generation_run_version')::bigint,
  'requested_by_auth_subject','e4000000-0000-0000-0000-000000000101',
  'requested_at',transaction_timestamp(),
  'reason_code','UPSTREAM_SOURCE_CHANGED','reason_note','No resurrection regression',
  'payload',jsonb_build_object(
    'period_start','2026-11-02','period_end','2026-11-02',
    'expected_current_need_generation_run_id',response->'affected_aggregate_ids'->>'need_generation_run_id'
  )
)
from pct01_responses where response_name='execute-correction';

set local role authenticated;
insert into pct01_responses
select '02b-execute-run3',atlas_api.execute_need_generation(request)
from pct01_requests where request_name='02b-execute-run3';
reset role;

select ok((select response->>'success'='true' from pct01_responses
  where response_name='02b-source-run3'),
  'PCT02B-19 successor source removes reviewed Spinach and one unreviewed business fact');
select ok((select response->>'success'='true' from pct01_responses
  where response_name='02b-execute-run3'),
  'PCT02B-20 third generation completes atomically');
select is((select response->'result_counts'->>'carried_forward_count'
  from pct01_responses where response_name='02b-execute-run3'),'2',
  'PCT02B-21 only Oil and Carrot carry from the direct predecessor');
select is((select response->'result_counts'->>'removed_count'
  from pct01_responses where response_name='02b-execute-run3'),'2',
  'PCT02B-21A reviewed and unreviewed removals both count as removed business facts');
select is((
  select jsonb_build_object(
    'all_continuity',count(*),
    'removed_invalidation',count(*) filter (
      where c.continuity_kind='INVALIDATED_LINE_REMOVED'
    )
  )
  from atlas_planning.confirmed_need_line_decision_continuity c
  where c.command_id='e4820000-0000-0000-0000-000000000010'
),jsonb_build_object('all_continuity',3,'removed_invalidation',1),
  'PCT02B-22 two removals create only one invalidation row because the other predecessor was unreviewed');
select ok((
  select line.current_confirmed_need_line_decision_id is null
    and revision.theoretical_quantity=2.500000
  from atlas_planning.confirmed_need_lines line
  join atlas_planning.confirmed_need_line_revisions revision
    on revision.confirmed_need_line_id=line.confirmed_need_line_id
   and revision.is_current
  where line.confirmed_need_batch_id=(select
      (response->'affected_aggregate_ids'->>'confirmed_need_batch_id')::uuid
    from pct01_responses where response_name='02b-execute-run3')
    and line.ingredient_id='e4100000-0000-0000-0000-000000000007'
    and line.delivery_location_id='e4100000-0000-0000-0000-000000000002'
), 'PCT02B-23 returning to the old Rice proposal does not resurrect decision #1');
select is((select response->'result_counts'->>'needs_review_count'
  from pct01_responses where response_name='02b-execute-run3'),'2',
  'PCT02B-24 Rice and prior-unreviewed Potato still require review');
set local role authenticated;
insert into pct01_responses values (
  '02b-read-run3',
  atlas_api.get_confirmed_need_review(jsonb_build_object(
    'contract_version','RMVP-05.v1',
    'requested_by_auth_subject','e4000000-0000-0000-0000-000000000101',
    'correlation_id',gen_random_uuid(),
    'payload',jsonb_build_object(
      'confirmed_need_batch_id',(
        select response->'affected_aggregate_ids'->>'confirmed_need_batch_id'
        from pct01_responses where response_name='02b-execute-run3'
      ),
      'filters','{}'::jsonb,'line_offset',0,'line_limit',100
    )
  ))
);
reset role;
select is((
  select jsonb_build_object(
    'total',response->'workbench'->'line_counts'->>'total',
    'needs_review',response->'workbench'->'line_counts'->>'needs_review',
    'removed',response->'workbench'->'line_counts'->>'removed'
  )
  from pct01_responses where response_name='02b-read-run3'
),jsonb_build_object('total','4','needs_review','2','removed','2'),
  'PCT02B-24A RMVP-05 excludes both removals from current totals and reports the same removed count');
select is((
  select count(*)
  from atlas_planning.confirmed_need_line_decision_continuity c
  join pct02b_original_decisions original
    on original.confirmed_need_line_decision_id=c.source_confirmed_need_line_decision_id
  where c.command_id='e4820000-0000-0000-0000-000000000010'
    and original.ingredient_id in (
      'e4100000-0000-0000-0000-000000000013',
      'e4100000-0000-0000-0000-000000000016'
    )
),2::bigint,'PCT02B-25 multi-generation carry retains both original human IDs');

-- Reconfirm only the two unreviewed lines. Rice must continue its historical
-- human chain as decision #2; truly new Potato starts at decision #1. Accepting
-- source-driven proposals requires no invented operator note.
insert into pct01_requests
select '02b-reconfirm-run3',jsonb_build_object(
  'contract_version','RMVP-05.v2',
  'command_id','e4820000-0000-0000-0000-000000000020',
  'correlation_id','e4820000-0000-0000-0000-000000000021',
  'idempotency_key','pct02b-reconfirm-run3',
  'expected_version',(select (response->'new_versions'->>'confirmed_need_batch_version')::bigint
    from pct01_responses where response_name='02b-execute-run3'),
  'requested_by_auth_subject','e4000000-0000-0000-0000-000000000101',
  'requested_at',transaction_timestamp(),
  'reason_code','CONFIRMED_NEED_SAVED','reason_note',null,
  'payload',jsonb_build_object(
    'confirmed_need_batch_id',batch.confirmed_need_batch_id,
    'lines',(
      select jsonb_agg(jsonb_build_object(
        'confirmed_need_line_id',line.confirmed_need_line_id,
        'expected_current_revision_id',revision.confirmed_need_line_revision_id,
        'expected_current_decision_id',null,
        'proposed_confirmed_quantity',revision.confirmed_quantity::text,
        'reason_code','PROPOSAL_ACCEPTED','reason_note',null
      ) order by line.confirmed_need_line_id)
      from atlas_planning.confirmed_need_lines line
      join atlas_planning.confirmed_need_line_revisions revision
        on revision.confirmed_need_line_id=line.confirmed_need_line_id
       and revision.is_current
      where line.confirmed_need_batch_id=batch.confirmed_need_batch_id
        and line.current_confirmed_need_line_decision_id is null
    )
  )
)
from atlas_planning.confirmed_need_batches batch
where batch.confirmed_need_batch_id=(select
  (response->'affected_aggregate_ids'->>'confirmed_need_batch_id')::uuid
  from pct01_responses where response_name='02b-execute-run3');

set local role authenticated;
insert into pct01_responses
select '02b-reconfirm-run3',atlas_api.save_confirmed_needs(request)
from pct01_requests where request_name='02b-reconfirm-run3';
reset role;

select ok((select response->>'success'='true' from pct01_responses
  where response_name='02b-reconfirm-run3'),
  'PCT02B-26 source-driven reconfirmation succeeds without fake notes');
select ok((
  select decision.decision_number=2
    and decision.predecessor_decision_id=original.confirmed_need_line_decision_id
  from atlas_planning.confirmed_need_lines line
  join atlas_planning.confirmed_need_line_decisions decision
    on decision.confirmed_need_line_decision_id=line.current_confirmed_need_line_decision_id
  join pct02b_original_decisions original
    on original.confirmed_need_line_id=line.confirmed_need_line_id
  where line.ingredient_id='e4100000-0000-0000-0000-000000000007'
    and line.delivery_location_id='e4100000-0000-0000-0000-000000000002'
), 'PCT02B-27 reconfirmed Rice is the direct human successor decision #2');
select ok((
  select decision.decision_number=1 and decision.predecessor_decision_id is null
  from atlas_planning.confirmed_need_lines line
  join atlas_planning.confirmed_need_line_decisions decision
    on decision.confirmed_need_line_decision_id=line.current_confirmed_need_line_decision_id
  where line.ingredient_id='e4100000-0000-0000-0000-000000000019'
), 'PCT02B-28 truly new Potato starts its human chain at decision #1');
select is((
  select count(*) from atlas_planning.confirmed_need_line_decisions decision
  where decision.command_id='e4820000-0000-0000-0000-000000000020'
    and decision.reason_code='PROPOSAL_ACCEPTED'
    and decision.reason_note is null
),2::bigint,'PCT02B-29 both source-driven proposal acceptances require no note');
select is((
  select count(*) from atlas_planning.confirmed_need_line_decisions decision
  where decision.confirmed_need_line_id in (
    select original.confirmed_need_line_id from pct02b_original_decisions original
    where original.ingredient_id in (
      'e4100000-0000-0000-0000-000000000013',
      'e4100000-0000-0000-0000-000000000016'
    )
  )
),2::bigint,'PCT02B-30 saving other lines creates no new decision for carried lines');

-- One irrelevant out-of-period Pantry change makes the source version newer
-- while preserving every current business fact in the evaluated day. All four
-- current decisions must carry, including the original adjustment and the two
-- newly confirmed decisions.
with proposed(rows) as (
  values (jsonb_build_array(
    jsonb_build_object(
      'service_date','2026-11-04','school_id','e4100000-0000-0000-0000-000000000005',
      'ingredient_id','e4100000-0000-0000-0000-000000000007',
      'pantry_need_purpose_id','e4400000-0000-0000-0000-000000000001',
      'requested_quantity','3.100000','note','Typed ambiguity Pantry line updated',
      'source_request_reference','RMVP04-TYPED','source_row_reference','1'
    ),
    jsonb_build_object(
      'service_date','2026-11-05','school_id','e4100000-0000-0000-0000-000000000005',
      'ingredient_id','e4100000-0000-0000-0000-000000000007',
      'pantry_need_purpose_id','e4400000-0000-0000-0000-000000000001',
      'requested_quantity','4.000000','note','General ambiguity Pantry line',
      'source_request_reference','RMVP04-GENERAL','source_row_reference','1'
    ),
    jsonb_build_object(
      'service_date','2026-11-02','school_id','e4100000-0000-0000-0000-000000000005',
      'ingredient_id','e4100000-0000-0000-0000-000000000019',
      'pantry_need_purpose_id','e4400000-0000-0000-0000-000000000001',
      'requested_quantity','1.500000','note','New Potato requirement',
      'source_request_reference','RMVP04-POTATO','source_row_reference','1'
    )
  ))
), canonical(raw_rows, canonical_rows) as (
  select rows, atlas_core.pantry_02_canonical_rows('2026-11-02', rows)
  from proposed
)
insert into pct01_requests
select '02b-source-run4',jsonb_build_object(
  'contract_version','PANTRY-02.v2',
  'command_id','e4820000-0000-0000-0000-000000000030',
  'correlation_id','e4820000-0000-0000-0000-000000000031',
  'idempotency_key','pct02b-source-run4',
  'expected_version',(select (response->'new_versions'->>'aggregate_version')::bigint
    from pct01_responses where response_name='02b-source-run3'),
  'requested_by_auth_subject','e4000000-0000-0000-0000-000000000101',
  'requested_at',transaction_timestamp(),
  'reason_code','PANTRY_SAVED','reason_note','Unchanged evaluated business facts',
  'payload',jsonb_build_object(
    'week_start','2026-11-02','no_additions_confirmed',false,
    'source_signature',atlas_core.pantry_02_signature('2026-11-02',false,canonical_rows),
    'expected_source_signature',(select request#>>'{payload,source_signature}'
      from pct01_requests where request_name='02b-source-run3'),
    'rows',raw_rows
  )
)
from canonical;

set local role authenticated;
insert into pct01_responses
select '02b-source-run4',atlas_api.save_pantry(request)
from pct01_requests where request_name='02b-source-run4';
reset role;

insert into pct01_requests
select '02b-execute-run4',jsonb_build_object(
  'contract_version','RMVP-04.v2',
  'command_id','e4820000-0000-0000-0000-000000000040',
  'correlation_id','e4820000-0000-0000-0000-000000000041',
  'idempotency_key','pct02b-execute-run4',
  'expected_version',(response->'new_versions'->>'need_generation_run_version')::bigint,
  'requested_by_auth_subject','e4000000-0000-0000-0000-000000000101',
  'requested_at',transaction_timestamp(),
  'reason_code','UPSTREAM_SOURCE_CHANGED','reason_note','All current facts unchanged',
  'payload',jsonb_build_object(
    'period_start','2026-11-02','period_end','2026-11-02',
    'expected_current_need_generation_run_id',response->'affected_aggregate_ids'->>'need_generation_run_id'
  )
)
from pct01_responses where response_name='02b-execute-run3';

set local role authenticated;
insert into pct01_responses
select '02b-execute-run4',atlas_api.execute_need_generation(request)
from pct01_requests where request_name='02b-execute-run4';
insert into pct01_responses
select '02b-execute-run4-replay',atlas_api.execute_need_generation(request)
from pct01_requests where request_name='02b-execute-run4';
reset role;

select ok((select response->>'success'='true' from pct01_responses
  where response_name='02b-source-run4'),
  'PCT02B-31 irrelevant source change completes through its public boundary');
select ok((select response->>'success'='true' from pct01_responses
  where response_name='02b-execute-run4'),
  'PCT02B-32 fourth generation completes atomically');
select is((select response->'result_counts'->>'carried_forward_count'
  from pct01_responses where response_name='02b-execute-run4'),'4',
  'PCT02B-33 all four valid current decisions carry on unchanged facts');
select is((select response->'result_counts'->>'needs_review_count'
  from pct01_responses where response_name='02b-execute-run4'),'0',
  'PCT02B-34 all-unchanged successor requires no human review');
select is((
  select count(*) from atlas_planning.confirmed_need_line_decision_continuity
  where command_id='e4820000-0000-0000-0000-000000000040'
    and continuity_kind='CARRIED_FORWARD'
),4::bigint,'PCT02B-35 every carried line has exact successor evidence');
select is((
  select count(*) from atlas_planning.confirmed_need_line_decisions
  where confirmed_need_batch_id=(select
    (response->'affected_aggregate_ids'->>'confirmed_need_batch_id')::uuid
    from pct01_responses where response_name='02b-execute-run4')
),7::bigint,'PCT02B-36 four system carries manufacture zero human decisions');
select is((
  select count(*) from atlas_planning.confirmed_need_line_decision_continuity c
  join pct02b_original_decisions original
    on original.confirmed_need_line_decision_id=c.source_confirmed_need_line_decision_id
  where original.ingredient_id='e4100000-0000-0000-0000-000000000013'
    and c.continuity_kind='CARRIED_FORWARD'
),3::bigint,'PCT02B-37 one original manual adjustment carries through three successors');
select is((select response from pct01_responses where response_name='02b-execute-run4-replay'),
  (select response from pct01_responses where response_name='02b-execute-run4'),
  'PCT02B-38 exact generation replay returns the committed result');
select is((
  select count(*) from atlas_planning.confirmed_need_line_decision_continuity
  where command_id='e4820000-0000-0000-0000-000000000040'
),4::bigint,'PCT02B-39 exact replay creates no duplicate continuity evidence');
select is((
  select count(distinct line.current_confirmed_need_line_decision_id)
  from atlas_planning.confirmed_need_lines line
  join atlas_planning.confirmed_need_line_revisions revision
    on revision.confirmed_need_line_id=line.confirmed_need_line_id
   and revision.is_current
  where line.confirmed_need_batch_id=(select
    (response->'affected_aggregate_ids'->>'confirmed_need_batch_id')::uuid
    from pct01_responses where response_name='02b-execute-run4')
),4::bigint,'PCT02B-40 every current fact has one valid human authority');

-- A carried line remains editable through the ordinary human Save boundary.
-- Editing it appends one direct human successor and does not rewrite or replace
-- the prior carried authority evidence.
insert into pct01_requests
select '02b-edit-carried-oil',jsonb_build_object(
  'contract_version','RMVP-05.v2',
  'command_id','e4820000-0000-0000-0000-000000000045',
  'correlation_id','e4820000-0000-0000-0000-000000000046',
  'idempotency_key','pct02b-edit-carried-oil',
  'expected_version',(select (response->'new_versions'->>'confirmed_need_batch_version')::bigint
    from pct01_responses where response_name='02b-execute-run4'),
  'requested_by_auth_subject','e4000000-0000-0000-0000-000000000101',
  'requested_at',transaction_timestamp(),
  'reason_code','CONFIRMED_NEED_SAVED','reason_note',null,
  'payload',jsonb_build_object(
    'confirmed_need_batch_id',batch.confirmed_need_batch_id,
    'lines',jsonb_build_array(jsonb_build_object(
      'confirmed_need_line_id',line.confirmed_need_line_id,
      'expected_current_revision_id',revision.confirmed_need_line_revision_id,
      'expected_current_decision_id',line.current_confirmed_need_line_decision_id,
      'proposed_confirmed_quantity','98.500000',
      'reason_code','OPERATIONAL_QUANTITY_ADJUSTMENT',
      'reason_note','Carried line edited after source correction'
    ))
  )
)
from atlas_planning.confirmed_need_batches batch
join atlas_planning.confirmed_need_lines line
  on line.confirmed_need_batch_id=batch.confirmed_need_batch_id
join atlas_planning.confirmed_need_line_revisions revision
  on revision.confirmed_need_line_id=line.confirmed_need_line_id
 and revision.is_current
where batch.confirmed_need_batch_id=(select
    (response->'affected_aggregate_ids'->>'confirmed_need_batch_id')::uuid
  from pct01_responses where response_name='02b-execute-run4')
  and line.ingredient_id='e4100000-0000-0000-0000-000000000013';

set local role authenticated;
insert into pct01_responses
select '02b-edit-carried-oil',atlas_api.save_confirmed_needs(request)
from pct01_requests where request_name='02b-edit-carried-oil';
reset role;

select ok((select response->>'success'='true' from pct01_responses
  where response_name='02b-edit-carried-oil'),
  'PCT02B-40A a carried line remains editable through normal human Save');
select ok((
  select decision.decision_number=2
    and decision.predecessor_decision_id=original.confirmed_need_line_decision_id
    and decision.confirmed_quantity_after=98.500000
  from atlas_planning.confirmed_need_lines line
  join atlas_planning.confirmed_need_line_decisions decision
    on decision.confirmed_need_line_decision_id=line.current_confirmed_need_line_decision_id
  join pct02b_original_decisions original
    on original.confirmed_need_line_id=line.confirmed_need_line_id
  where line.ingredient_id='e4100000-0000-0000-0000-000000000013'
), 'PCT02B-40B carried-line edit appends one direct human successor');

-- Identical proposals under a new effective Planning policy revision are not
-- eligible. Make the source outdated first, then change the policy inside the
-- same test transaction so the atomic generation can create exact invalidation
-- evidence before deferred H1B1 integrity is forced.
with proposed(rows) as (
  values (jsonb_build_array(
    jsonb_build_object(
      'service_date','2026-11-04','school_id','e4100000-0000-0000-0000-000000000005',
      'ingredient_id','e4100000-0000-0000-0000-000000000007',
      'pantry_need_purpose_id','e4400000-0000-0000-0000-000000000001',
      'requested_quantity','3.200000','note','Typed ambiguity Pantry line updated again',
      'source_request_reference','RMVP04-TYPED','source_row_reference','1'
    ),
    jsonb_build_object(
      'service_date','2026-11-05','school_id','e4100000-0000-0000-0000-000000000005',
      'ingredient_id','e4100000-0000-0000-0000-000000000007',
      'pantry_need_purpose_id','e4400000-0000-0000-0000-000000000001',
      'requested_quantity','4.000000','note','General ambiguity Pantry line',
      'source_request_reference','RMVP04-GENERAL','source_row_reference','1'
    ),
    jsonb_build_object(
      'service_date','2026-11-02','school_id','e4100000-0000-0000-0000-000000000005',
      'ingredient_id','e4100000-0000-0000-0000-000000000019',
      'pantry_need_purpose_id','e4400000-0000-0000-0000-000000000001',
      'requested_quantity','1.500000','note','New Potato requirement',
      'source_request_reference','RMVP04-POTATO','source_row_reference','1'
    )
  ))
), canonical(raw_rows, canonical_rows) as (
  select rows, atlas_core.pantry_02_canonical_rows('2026-11-02', rows)
  from proposed
)
insert into pct01_requests
select '02b-source-policy',jsonb_build_object(
  'contract_version','PANTRY-02.v2',
  'command_id','e4820000-0000-0000-0000-000000000050',
  'correlation_id','e4820000-0000-0000-0000-000000000051',
  'idempotency_key','pct02b-source-policy',
  'expected_version',(select (response->'new_versions'->>'aggregate_version')::bigint
    from pct01_responses where response_name='02b-source-run4'),
  'requested_by_auth_subject','e4000000-0000-0000-0000-000000000101',
  'requested_at',transaction_timestamp(),
  'reason_code','PANTRY_SAVED','reason_note','Prepare policy invalidation run',
  'payload',jsonb_build_object(
    'week_start','2026-11-02','no_additions_confirmed',false,
    'source_signature',atlas_core.pantry_02_signature('2026-11-02',false,canonical_rows),
    'expected_source_signature',(select request#>>'{payload,source_signature}'
      from pct01_requests where request_name='02b-source-run4'),
    'rows',raw_rows
  )
)
from canonical;

set local role authenticated;
insert into pct01_responses
select '02b-source-policy',atlas_api.save_pantry(request)
from pct01_requests where request_name='02b-source-policy';
reset role;

insert into atlas_planning.planning_quantity_policy_revisions (
  planning_quantity_policy_revision_id, planning_quantity_policy_id, unit_id,
  revision_number, predecessor_policy_revision_id, planning_step,
  effective_from, policy_revision_status, created_by_actor_id, created_at
) values (
  'e4810000-0000-0000-0000-000000000003',
  'e4810000-0000-0000-0000-000000000001',
  'e4100000-0000-0000-0000-000000000006',
  2, 'e4810000-0000-0000-0000-000000000002', 0.500000,
  '2026-10-01', 'DRAFT',
  'e4000000-0000-0000-0000-000000000001', transaction_timestamp()
);
update atlas_planning.planning_quantity_policy_revisions
set policy_revision_status='RETIRED', effective_to='2026-10-01',
    retired_by_actor_id='e4000000-0000-0000-0000-000000000001',
    retired_at=transaction_timestamp()
where planning_quantity_policy_revision_id=
  'e4810000-0000-0000-0000-000000000002';
update atlas_planning.planning_quantity_policy_revisions
set policy_revision_status='ACTIVE',
    approved_by_actor_id='e4000000-0000-0000-0000-000000000001',
    approved_at=transaction_timestamp(),
    activated_by_actor_id='e4000000-0000-0000-0000-000000000001',
    activated_at=transaction_timestamp()
where planning_quantity_policy_revision_id=
  'e4810000-0000-0000-0000-000000000003';

insert into pct01_requests
select '02b-execute-policy',jsonb_build_object(
  'contract_version','RMVP-04.v2',
  'command_id','e4820000-0000-0000-0000-000000000060',
  'correlation_id','e4820000-0000-0000-0000-000000000061',
  'idempotency_key','pct02b-execute-policy',
  'expected_version',(response->'new_versions'->>'need_generation_run_version')::bigint,
  'requested_by_auth_subject','e4000000-0000-0000-0000-000000000101',
  'requested_at',transaction_timestamp(),
  'reason_code','UPSTREAM_SOURCE_CHANGED','reason_note','Policy compatibility regression',
  'payload',jsonb_build_object(
    'period_start','2026-11-02','period_end','2026-11-02',
    'expected_current_need_generation_run_id',response->'affected_aggregate_ids'->>'need_generation_run_id'
  )
)
from pct01_responses where response_name='02b-execute-run4';

set local role authenticated;
insert into pct01_responses
select '02b-execute-policy',atlas_api.execute_need_generation(request)
from pct01_requests where request_name='02b-execute-policy';
reset role;

select ok((select response->>'success'='true' from pct01_responses
  where response_name='02b-source-policy'),
  'PCT02B-41 source becomes outdated before the policy transition');
select ok((select response->>'success'='true' from pct01_responses
  where response_name='02b-execute-policy'),
  'PCT02B-42 policy-incompatible successor completes atomically');
select is((select response->'result_counts'->>'carried_forward_count'
  from pct01_responses where response_name='02b-execute-policy'),'0',
  'PCT02B-43 equal quantities under a different policy do not carry');
select is((select response->'result_counts'->>'changed_count'
  from pct01_responses where response_name='02b-execute-policy'),'4',
  'PCT02B-44 every prior authority is invalidated by policy incompatibility');
select is((select response->'result_counts'->>'needs_review_count'
  from pct01_responses where response_name='02b-execute-policy'),'4',
  'PCT02B-45 every current line requires review after the policy change');
select is((
  select count(*) from atlas_planning.confirmed_need_line_decision_continuity
  where command_id='e4820000-0000-0000-0000-000000000060'
    and continuity_kind='INVALIDATED_POLICY_INCOMPATIBLE'
),4::bigint,'PCT02B-46 policy invalidation has exact immutable evidence per line');
select ok(not exists(
  select 1 from atlas_planning.confirmed_need_lines line
  join atlas_planning.confirmed_need_line_revisions revision
    on revision.confirmed_need_line_id=line.confirmed_need_line_id
   and revision.is_current
  where line.confirmed_need_batch_id=(select
    (response->'affected_aggregate_ids'->>'confirmed_need_batch_id')::uuid
    from pct01_responses where response_name='02b-execute-policy')
    and line.current_confirmed_need_line_decision_id is not null
), 'PCT02B-47 policy invalidation clears only the current authority pointers');

-- Consequential source completion: one public Save per source, with exact
-- capability isolation, immutable snapshots, replay, concurrency, and no-change.
with proposed(rows) as (
  values (jsonb_build_array(jsonb_build_object(
    'school_id','e4100000-0000-0000-0000-000000000005',
    'service_date','2026-11-09','menu_slot_code','savory',
    'dish_id','e4100000-0000-0000-0000-000000000008',
    'source_row_reference','pct01-menu-1'
  )))
), canonical(rows) as (
  select atlas_core.rmvp_03a_canonical_menu_rows(rows) from proposed
)
insert into pct01_requests
select 'source-menu', jsonb_build_object(
  'contract_version','RMVP-03A.v2',
  'command_id','e4900000-0000-0000-0000-000000000001',
  'correlation_id','e4900000-0000-0000-0000-000000000002',
  'idempotency_key','pct01-source-menu','expected_version',1,
  'requested_by_auth_subject','e4000000-0000-0000-0000-000000000102',
  'requested_at',transaction_timestamp() + interval '30 seconds','reason_code','WEEKLY_MENU_SAVED',
  'reason_note',null,
  'payload',jsonb_build_object(
    'week_start','2026-11-09','source_type','MANUAL','source_name','Atlas',
    'source_signature',atlas_core.rmvp_03a_menu_signature(rows),
    'expected_source_signature',null,'rows',rows
  )
) from canonical;

with proposed(rows) as (
  values (jsonb_build_array(jsonb_build_object(
    'school_id','e4100000-0000-0000-0000-000000000005',
    'service_date','2026-11-09','student_portions',111,
    'teacher_portions',10,'source_row_reference','pct01-attendance-1'
  )))
), canonical(rows) as (
  select atlas_core.rmvp_03a_canonical_attendance_rows(rows) from proposed
)
insert into pct01_requests
select 'source-attendance', jsonb_build_object(
  'contract_version','RMVP-03A.v2',
  'command_id','e4900000-0000-0000-0000-000000000003',
  'correlation_id','e4900000-0000-0000-0000-000000000004',
  'idempotency_key','pct01-source-attendance','expected_version',1,
  'requested_by_auth_subject','e4000000-0000-0000-0000-000000000101',
  'requested_at',transaction_timestamp() + interval '30 seconds','reason_code','ATTENDANCE_SAVED',
  'reason_note',null,
  'payload',jsonb_build_object(
    'week_start','2026-11-09','source_type','MANUAL','source_name','Atlas',
    'source_signature',atlas_core.rmvp_03a_attendance_signature(rows),
    'expected_source_signature',null,'rows',rows
  )
) from canonical;

with proposed(rows) as (
  values (jsonb_build_array(jsonb_build_object(
    'service_date','2026-11-09','school_id','e4100000-0000-0000-0000-000000000005',
    'ingredient_id','e4100000-0000-0000-0000-000000000007',
    'pantry_need_purpose_id','e4400000-0000-0000-0000-000000000001',
    'requested_quantity','1.500000','note','Source completion acceptance',
    'source_request_reference','PCT01','source_row_reference','pct01-pantry-1'
  )))
), canonical(raw_rows, canonical_rows) as (
  select rows, atlas_core.pantry_02_canonical_rows('2026-11-09',rows) from proposed
)
insert into pct01_requests
select 'source-pantry', jsonb_build_object(
  'contract_version','PANTRY-02.v2',
  'command_id','e4900000-0000-0000-0000-000000000005',
  'correlation_id','e4900000-0000-0000-0000-000000000006',
  'idempotency_key','pct01-source-pantry','expected_version',1,
  'requested_by_auth_subject','e4000000-0000-0000-0000-000000000101',
  'requested_at',transaction_timestamp() + interval '30 seconds','reason_code','PANTRY_SAVED',
  'reason_note',null,
  'payload',jsonb_build_object(
    'week_start','2026-11-09','no_additions_confirmed',false,
    'source_signature',atlas_core.pantry_02_signature('2026-11-09',false,canonical_rows),
    'expected_source_signature',null,'rows',raw_rows
  )
) from canonical;

select set_config('request.jwt.claim.sub','e4000000-0000-0000-0000-000000000101',true);
set local role authenticated;
insert into pct01_responses
select 'source-attendance-preview', atlas_api.preview_attendance_import(
  jsonb_build_object(
    'contract_version','RMVP-03A.v1',
    'requested_by_auth_subject','e4000000-0000-0000-0000-000000000101',
    'correlation_id',gen_random_uuid(),
    'payload',jsonb_build_object(
      'week_start','2026-11-09','rows',request #> '{payload,rows}'
    )
  )
)
from pct01_requests where request_name='source-attendance';
reset role;
select ok(
  (select response->>'success'='true'
    and response->'preview'->>'can_save'='true'
   from pct01_responses where response_name='source-attendance-preview'),
  'PCT01-S01 hosted Attendance 111/10 preview can save against defaults 100/10'
);
select is(
  (select jsonb_array_length(response->'preview'->'issues'->'blockers')
   from pct01_responses where response_name='source-attendance-preview'),
  0,
  'PCT01-S02 hosted Attendance 111/10 preview has zero blockers'
);
select is(
  (select array_agg(issue->>'code' order by issue->>'code')::text[]
   from pct01_responses response
   cross join lateral jsonb_array_elements(
     response.response->'preview'->'issues'->'warnings'
   ) issue
   where response.response_name='source-attendance-preview'),
  array['PORTIONS_DIFFER_FROM_DEFAULT']::text[],
  'PCT01-S02A hosted Attendance 111/10 preview retains only the defaults warning'
);

select set_config('request.jwt.claim.sub','e4000000-0000-0000-0000-000000000102',true);
set local role authenticated;
insert into pct01_responses
select 'source-menu',atlas_api.save_weekly_menu(request)
from pct01_requests where request_name='source-menu';
reset role;
select set_config('request.jwt.claim.sub','e4000000-0000-0000-0000-000000000101',true);
set local role authenticated;
insert into pct01_responses
select 'source-attendance',atlas_api.save_attendance(request)
from pct01_requests where request_name='source-attendance';
insert into pct01_responses
select 'source-pantry',atlas_api.save_pantry(request)
from pct01_requests where request_name='source-pantry';
reset role;
select is(
  (select array_agg(response->>'success' order by response_name)::text[] from pct01_responses where response_name in ('source-menu','source-attendance','source-pantry')),
  array['true','true','true']::text[],
  'PCT01-S03 each source-specific consequential Save completes in one call'
);
select is(
  (select array_agg(response->>'contract_version' order by response_name)::text[] from pct01_responses where response_name in ('source-menu','source-attendance','source-pantry')),
  array['RMVP-03A.v2','RMVP-03A.v2','PANTRY-02.v2']::text[],
  'PCT01-S04 source completions return their exact successor contracts'
);
select is(
  (select count(*) from atlas_core.command_receipts where command_id in ('e4900000-0000-0000-0000-000000000001','e4900000-0000-0000-0000-000000000003','e4900000-0000-0000-0000-000000000005')),
  3::bigint,
  'PCT01-S05 each source completion owns exactly one top-level receipt'
);
select is(
  jsonb_build_object(
    'menu',(select weekly_menu_status from atlas_planning.weekly_menus where week_start='2026-11-09'),
    'attendance',(select attendance_status from atlas_planning.attendance_batches where period_start='2026-11-09'),
    'pantry',(select pantry_need_batch_status from atlas_planning.pantry_need_batches where week_start='2026-11-09')
  ),
  jsonb_build_object('menu','APPROVED','attendance','APPROVED','pantry','APPROVED'),
  'PCT01-S06 each consequential Save establishes authoritative completed state'
);
select is(
  jsonb_build_object(
    'menu',(select count(*) from atlas_planning.weekly_menu_approval_snapshot_lines line join atlas_planning.weekly_menus root on root.latest_approval_snapshot_id=line.weekly_menu_approval_snapshot_id where root.week_start='2026-11-09'),
    'attendance',(select count(*) from atlas_planning.attendance_approval_snapshot_lines line join atlas_planning.attendance_batches root on root.latest_approval_snapshot_id=line.attendance_approval_snapshot_id where root.period_start='2026-11-09'),
    'pantry',(select count(*) from atlas_planning.pantry_need_approval_snapshot_lines line join atlas_planning.pantry_need_batches root on root.latest_approval_snapshot_id=line.pantry_need_approval_snapshot_id where root.week_start='2026-11-09')
  ),
  jsonb_build_object('menu',1,'attendance',1,'pantry',1),
  'PCT01-S07 completed snapshots contain every-and-only submitted member'
);
select is(
  (select jsonb_build_object(
      'student_portions', line.student_portions,
      'teacher_portions', line.teacher_portions
    )
   from atlas_planning.attendance_approval_snapshot_lines line
   join atlas_planning.attendance_batches root
     on root.latest_approval_snapshot_id=line.attendance_approval_snapshot_id
   where root.period_start='2026-11-09'),
  jsonb_build_object('student_portions',111,'teacher_portions',10),
  'PCT01-S08 Attendance 111/10 is authoritative in the completed snapshot'
);
select ok(
  (select line.delivery_location_id='e4100000-0000-0000-0000-000000000002' and line.unit_id='e4100000-0000-0000-0000-000000000006' from atlas_planning.pantry_need_approval_snapshot_lines line join atlas_planning.pantry_need_batches root on root.latest_approval_snapshot_id=line.pantry_need_approval_snapshot_id where root.week_start='2026-11-09'),
  'PCT01-S09 Pantry derives Delivery Location and Unit on the server'
);
select ok(
  not exists (
    select 1 from pct01_responses response
    where response.response_name in ('source-menu','source-attendance','source-pantry')
      and response.response->>'downstream_currentness'<>'NOT_GENERATED'
  ),
  'PCT01-S10 new completed sources report downstream Need as NOT_GENERATED'
);

select set_config('request.jwt.claim.sub','e4000000-0000-0000-0000-000000000102',true);
set local role authenticated;
insert into pct01_responses select 'source-menu-replay',atlas_api.save_weekly_menu(request) from pct01_requests where request_name='source-menu';
reset role;
select set_config('request.jwt.claim.sub','e4000000-0000-0000-0000-000000000101',true);
set local role authenticated;
insert into pct01_responses select 'source-attendance-replay',atlas_api.save_attendance(request) from pct01_requests where request_name='source-attendance';
insert into pct01_responses select 'source-pantry-replay',atlas_api.save_pantry(request) from pct01_requests where request_name='source-pantry';
reset role;
select ok(
  (select response from pct01_responses where response_name='source-menu-replay')=(select response from pct01_responses where response_name='source-menu')
  and (select response from pct01_responses where response_name='source-attendance-replay')=(select response from pct01_responses where response_name='source-attendance')
  and (select response from pct01_responses where response_name='source-pantry-replay')=(select response from pct01_responses where response_name='source-pantry'),
  'PCT01-S11 exact replay returns each original committed source response'
);
select is(
  (select count(*) from atlas_core.command_receipts where command_id in ('e4900000-0000-0000-0000-000000000001','e4900000-0000-0000-0000-000000000003','e4900000-0000-0000-0000-000000000005')),
  3::bigint,
  'PCT01-S12 source replay creates no duplicate receipt'
);

select set_config('request.jwt.claim.sub','e4000000-0000-0000-0000-000000000102',true);
set local role authenticated;
insert into pct01_responses select 'source-menu-conflict',atlas_api.save_weekly_menu(request||jsonb_build_object('idempotency_key','changed')) from pct01_requests where request_name='source-menu';
reset role;
select set_config('request.jwt.claim.sub','e4000000-0000-0000-0000-000000000101',true);
set local role authenticated;
insert into pct01_responses select 'source-attendance-conflict',atlas_api.save_attendance(request||jsonb_build_object('idempotency_key','changed')) from pct01_requests where request_name='source-attendance';
insert into pct01_responses select 'source-pantry-conflict',atlas_api.save_pantry(request||jsonb_build_object('idempotency_key','changed')) from pct01_requests where request_name='source-pantry';
reset role;
select is(
  (select array_agg(response->>'error_code' order by response_name)::text[] from pct01_responses where response_name like 'source-%-conflict'),
  array_fill('IDEMPOTENCY_CONFLICT'::text,array[3]),
  'PCT01-S13 changed idempotency reuse is rejected for every source'
);

select set_config('request.jwt.claim.sub','e4000000-0000-0000-0000-000000000102',true);
set local role authenticated;
insert into pct01_responses select 'source-menu-stale-version',atlas_api.save_weekly_menu(request||jsonb_build_object('command_id','e4900000-0000-0000-0000-000000000011','idempotency_key','stale-menu-version','expected_version',999)) from pct01_requests where request_name='source-menu';
reset role;
select set_config('request.jwt.claim.sub','e4000000-0000-0000-0000-000000000101',true);
set local role authenticated;
insert into pct01_responses select 'source-attendance-stale-version',atlas_api.save_attendance(request||jsonb_build_object('command_id','e4900000-0000-0000-0000-000000000012','idempotency_key','stale-attendance-version','expected_version',999)) from pct01_requests where request_name='source-attendance';
insert into pct01_responses select 'source-pantry-stale-version',atlas_api.save_pantry(request||jsonb_build_object('command_id','e4900000-0000-0000-0000-000000000013','idempotency_key','stale-pantry-version','expected_version',999)) from pct01_requests where request_name='source-pantry';
reset role;
select is(
  (select array_agg(response->>'error_code' order by response_name)::text[] from pct01_responses where response_name like 'source-%-stale-version'),
  array_fill('STALE_VERSION'::text,array[3]),
  'PCT01-S14 stale versions are rejected for every source'
);

select set_config('request.jwt.claim.sub','e4000000-0000-0000-0000-000000000102',true);
set local role authenticated;
insert into pct01_responses
select 'source-menu-stale-signature',atlas_api.save_weekly_menu(jsonb_set(request||jsonb_build_object('command_id','e4900000-0000-0000-0000-000000000014','idempotency_key','stale-menu-signature','expected_version',(select (response->'new_versions'->>'aggregate_version')::bigint from pct01_responses where response_name='source-menu')),'{payload,expected_source_signature}',to_jsonb(repeat('f',64)))) from pct01_requests where request_name='source-menu';
reset role;
select set_config('request.jwt.claim.sub','e4000000-0000-0000-0000-000000000101',true);
set local role authenticated;
insert into pct01_responses
select 'source-attendance-stale-signature',atlas_api.save_attendance(jsonb_set(request||jsonb_build_object('command_id','e4900000-0000-0000-0000-000000000015','idempotency_key','stale-attendance-signature','expected_version',(select (response->'new_versions'->>'aggregate_version')::bigint from pct01_responses where response_name='source-attendance')),'{payload,expected_source_signature}',to_jsonb(repeat('f',64)))) from pct01_requests where request_name='source-attendance';
insert into pct01_responses
select 'source-pantry-stale-signature',atlas_api.save_pantry(jsonb_set(request||jsonb_build_object('command_id','e4900000-0000-0000-0000-000000000016','idempotency_key','stale-pantry-signature','expected_version',(select (response->'new_versions'->>'aggregate_version')::bigint from pct01_responses where response_name='source-pantry')),'{payload,expected_source_signature}',to_jsonb(repeat('f',64)))) from pct01_requests where request_name='source-pantry';
reset role;
select is(
  (select array_agg(response->>'error_code' order by response_name)::text[] from pct01_responses where response_name like 'source-%-stale-signature'),
  array_fill('STALE_SOURCE_SIGNATURE'::text,array[3]),
  'PCT01-S15 stale source signatures are rejected for every source'
);

set local role authenticated;
insert into pct01_responses
select 'source-menu-invalid',atlas_api.save_weekly_menu(jsonb_set(jsonb_set(request||jsonb_build_object('command_id','e4900000-0000-0000-0000-000000000017','idempotency_key','invalid-menu','expected_version',1),'{payload,week_start}',to_jsonb('2026-11-16'::text)),'{payload,source_signature}',to_jsonb('bad'::text))) from pct01_requests where request_name='source-menu';
insert into pct01_responses
select 'source-attendance-invalid',atlas_api.save_attendance(jsonb_set(jsonb_set(request||jsonb_build_object('command_id','e4900000-0000-0000-0000-000000000018','idempotency_key','invalid-attendance','expected_version',1),'{payload,week_start}',to_jsonb('2026-11-16'::text)),'{payload,source_signature}',to_jsonb('bad'::text))) from pct01_requests where request_name='source-attendance';
insert into pct01_responses
select 'source-pantry-invalid',atlas_api.save_pantry(jsonb_set(jsonb_set(request||jsonb_build_object('command_id','e4900000-0000-0000-0000-000000000019','idempotency_key','invalid-pantry','expected_version',1),'{payload,week_start}',to_jsonb('2026-11-16'::text)),'{payload,source_signature}',to_jsonb('bad'::text))) from pct01_requests where request_name='source-pantry';
reset role;
select is(
  (select array_agg(response->>'error_code' order by response_name)::text[] from pct01_responses where response_name like 'source-%-invalid'),
  array_fill('CHECKSUM_MISMATCH'::text,array[3]),
  'PCT01-S16 deterministic invalid submissions fail before partial completion'
);
select is(
  (select count(*) from atlas_planning.weekly_menus where week_start='2026-11-16')+
  (select count(*) from atlas_planning.attendance_batches where period_start='2026-11-16')+
  (select count(*) from atlas_planning.pantry_need_batches where week_start='2026-11-16'),
  0::bigint,
  'PCT01-S17 invalid source submissions create no partial aggregate'
);

select set_config('request.jwt.claim.sub','e4000000-0000-0000-0000-000000000102',true);
set local role authenticated;
insert into pct01_responses
select 'source-menu-no-change',atlas_api.save_weekly_menu(jsonb_set(request||jsonb_build_object('command_id','e4900000-0000-0000-0000-000000000020','idempotency_key','no-change-menu','expected_version',(select (response->'new_versions'->>'aggregate_version')::bigint from pct01_responses where response_name='source-menu')),'{payload,expected_source_signature}',request#>'{payload,source_signature}')) from pct01_requests where request_name='source-menu';
reset role;
select set_config('request.jwt.claim.sub','e4000000-0000-0000-0000-000000000101',true);
set local role authenticated;
insert into pct01_responses
select 'source-attendance-no-change',atlas_api.save_attendance(jsonb_set(request||jsonb_build_object('command_id','e4900000-0000-0000-0000-000000000021','idempotency_key','no-change-attendance','expected_version',(select (response->'new_versions'->>'aggregate_version')::bigint from pct01_responses where response_name='source-attendance')),'{payload,expected_source_signature}',request#>'{payload,source_signature}')) from pct01_requests where request_name='source-attendance';
insert into pct01_responses
select 'source-pantry-no-change',atlas_api.save_pantry(jsonb_set(request||jsonb_build_object('command_id','e4900000-0000-0000-0000-000000000022','idempotency_key','no-change-pantry','expected_version',(select (response->'new_versions'->>'aggregate_version')::bigint from pct01_responses where response_name='source-pantry')),'{payload,expected_source_signature}',request#>'{payload,source_signature}')) from pct01_requests where request_name='source-pantry';
reset role;
select is(
  (select array_agg(response->>'idempotency_status' order by response_name)::text[] from pct01_responses where response_name like 'source-%-no-change'),
  array_fill('NO_CHANGE'::text,array[3]),
  'PCT01-S18 exact completed content returns explicit NO_CHANGE for every source'
);
select is(
  jsonb_build_object(
    'menu',(select count(*) from atlas_planning.weekly_menu_approval_snapshots snapshot join atlas_planning.weekly_menus root on root.weekly_menu_id=snapshot.weekly_menu_id where root.week_start='2026-11-09'),
    'attendance',(select count(*) from atlas_planning.attendance_approval_snapshots snapshot join atlas_planning.attendance_batches root on root.attendance_batch_id=snapshot.attendance_batch_id where root.period_start='2026-11-09'),
    'pantry',(select count(*) from atlas_planning.pantry_need_approval_snapshots snapshot join atlas_planning.pantry_need_batches root on root.pantry_need_batch_id=snapshot.pantry_need_batch_id where root.week_start='2026-11-09')
  ),
  jsonb_build_object('menu',1,'attendance',1,'pantry',1),
  'PCT01-S19 replay and no-change preserve one immutable completed snapshot'
);

select set_config('request.jwt.claim.sub','e4000000-0000-0000-0000-000000000102',true);
set local role authenticated;
insert into pct01_responses
select 'source-attendance-cross-capability',atlas_api.save_attendance(jsonb_set(request||jsonb_build_object('command_id','e4900000-0000-0000-0000-000000000023','idempotency_key','cross-attendance','requested_by_auth_subject','e4000000-0000-0000-0000-000000000102','expected_version',(select (response->'new_versions'->>'aggregate_version')::bigint from pct01_responses where response_name='source-attendance')),'{payload,expected_source_signature}',request#>'{payload,source_signature}')) from pct01_requests where request_name='source-attendance';
insert into pct01_responses
select 'source-pantry-cross-capability',atlas_api.save_pantry(jsonb_set(request||jsonb_build_object('command_id','e4900000-0000-0000-0000-000000000024','idempotency_key','cross-pantry','requested_by_auth_subject','e4000000-0000-0000-0000-000000000102','expected_version',(select (response->'new_versions'->>'aggregate_version')::bigint from pct01_responses where response_name='source-pantry')),'{payload,expected_source_signature}',request#>'{payload,source_signature}')) from pct01_requests where request_name='source-pantry';
reset role;
select set_config('request.jwt.claim.sub','e4000000-0000-0000-0000-000000000101',true);
select is(
  (select array_agg(response->>'error_code' order by response_name)::text[] from pct01_responses where response_name like 'source-%-cross-capability'),
  array_fill('CAPABILITY_DENIED'::text,array[2]),
  'PCT01-S20 Weekly Menu capability cannot authorize Attendance or Pantry Save'
);
select is(
  (
    select array_agg(capability.capability_code order by capability.capability_code)::text[]
    from atlas_core.role_capabilities binding
    join atlas_core.capabilities capability on capability.capability_id=binding.capability_id
    where binding.role_id='e4000000-0000-0000-0000-000000000021'
      and capability.capability_code in ('planning.weekly_menu.write','planning.attendance.write','planning.pantry.write')
  ),
  array['planning.weekly_menu.write']::text[],
  'PCT01-S21 source-specific capabilities remain independent'
);
select ok(
  (select latest_approval_snapshot_id=(select (response->'affected_aggregate_ids'->>'weekly_menu_approval_snapshot_id')::uuid from pct01_responses where response_name='source-menu') from atlas_planning.weekly_menus where week_start='2026-11-09')
  and (select latest_approval_snapshot_id=(select (response->'affected_aggregate_ids'->>'attendance_approval_snapshot_id')::uuid from pct01_responses where response_name='source-attendance') from atlas_planning.attendance_batches where period_start='2026-11-09')
  and (select latest_approval_snapshot_id=(select (response->'affected_aggregate_ids'->>'pantry_need_approval_snapshot_id')::uuid from pct01_responses where response_name='source-pantry') from atlas_planning.pantry_need_batches where week_start='2026-11-09'),
  'PCT01-S22 authoritative current snapshot pointers match each Save response'
);
select is(
  jsonb_build_object(
    'menu',(select version from atlas_planning.weekly_menus where week_start='2026-11-09'),
    'attendance',(select version from atlas_planning.attendance_batches where period_start='2026-11-09'),
    'pantry',(select version from atlas_planning.pantry_need_batches where week_start='2026-11-09')
  ),
  jsonb_build_object(
    'menu',(select (response->'new_versions'->>'aggregate_version')::bigint from pct01_responses where response_name='source-menu'),
    'attendance',(select (response->'new_versions'->>'aggregate_version')::bigint from pct01_responses where response_name='source-attendance'),
    'pantry',(select (response->'new_versions'->>'aggregate_version')::bigint from pct01_responses where response_name='source-pantry')
  ),
  'PCT01-S23 authoritative current versions match each Save response'
);
select is(
  (select requested_quantity from atlas_planning.pantry_need_approval_snapshot_lines where pantry_need_approval_snapshot_id='e4400000-0000-0000-0000-000000000003' and service_date='2026-11-02'),
  2.000000::numeric,
  'PCT01-S24 Pantry correction preserves the prior immutable snapshot value'
);
select is(
  (select source_signature from atlas_planning.pantry_need_approval_snapshots where pantry_need_approval_snapshot_id='e4400000-0000-0000-0000-000000000003'),
  repeat('e',64),
  'PCT01-S25 Pantry correction preserves the prior immutable snapshot signature'
);

-- Issue #215 fail-closed boundary: commands materially beyond the explicit
-- 60-second allowance, plus malformed time, must fail before business writes.
create temporary table pct01_clock_skew_counts as
select jsonb_build_object(
  'menu_version',(select version from atlas_planning.weekly_menus where week_start='2026-11-09'),
  'attendance_version',(select version from atlas_planning.attendance_batches where period_start='2026-11-09'),
  'pantry_version',(select version from atlas_planning.pantry_need_batches where week_start='2026-11-09'),
  'run_count',(select count(*) from atlas_planning.need_generation_runs),
  'confirmed_need_batch_count',(select count(*) from atlas_planning.confirmed_need_batches)
) as counts;

select set_config('request.jwt.claim.sub','e4000000-0000-0000-0000-000000000102',true);
set local role authenticated;
insert into pct01_responses
select 'clock-skew-menu-future', atlas_api.save_weekly_menu(
  jsonb_set(
    request || jsonb_build_object(
      'command_id','e4900000-0000-0000-0000-000000000031',
      'idempotency_key','clock-skew-menu-future',
      'expected_version',(select (response->'new_versions'->>'aggregate_version')::bigint from pct01_responses where response_name='source-menu'),
      'requested_at',transaction_timestamp() + interval '61 seconds'
    ),
    '{payload,expected_source_signature}', request #> '{payload,source_signature}'
  )
) from pct01_requests where request_name='source-menu';
reset role;

select set_config('request.jwt.claim.sub','e4000000-0000-0000-0000-000000000101',true);
set local role authenticated;
insert into pct01_responses
select 'clock-skew-attendance-future', atlas_api.save_attendance(
  jsonb_set(
    request || jsonb_build_object(
      'command_id','e4900000-0000-0000-0000-000000000032',
      'idempotency_key','clock-skew-attendance-future',
      'expected_version',(select (response->'new_versions'->>'aggregate_version')::bigint from pct01_responses where response_name='source-attendance'),
      'requested_at',transaction_timestamp() + interval '61 seconds'
    ),
    '{payload,expected_source_signature}', request #> '{payload,source_signature}'
  )
) from pct01_requests where request_name='source-attendance';
insert into pct01_responses
select 'clock-skew-pantry-future', atlas_api.save_pantry(
  jsonb_set(
    request || jsonb_build_object(
      'command_id','e4900000-0000-0000-0000-000000000033',
      'idempotency_key','clock-skew-pantry-future',
      'expected_version',(select (response->'new_versions'->>'aggregate_version')::bigint from pct01_responses where response_name='source-pantry'),
      'requested_at',transaction_timestamp() + interval '61 seconds'
    ),
    '{payload,expected_source_signature}', request #> '{payload,source_signature}'
  )
) from pct01_requests where request_name='source-pantry';
insert into pct01_responses
select 'clock-skew-execute-future', atlas_api.execute_need_generation(
  request || jsonb_build_object(
    'command_id','e4900000-0000-0000-0000-000000000034',
    'idempotency_key','clock-skew-execute-future',
    'requested_at',transaction_timestamp() + interval '61 seconds'
  )
) from pct01_requests where request_name='execute-initial';
insert into pct01_responses
select 'clock-skew-attendance-malformed', atlas_api.save_attendance(
  jsonb_set(
    request || jsonb_build_object(
      'command_id','e4900000-0000-0000-0000-000000000035',
      'idempotency_key','clock-skew-attendance-malformed',
      'expected_version',(select (response->'new_versions'->>'aggregate_version')::bigint from pct01_responses where response_name='source-attendance'),
      'requested_at','not-a-timestamp'
    ),
    '{payload,expected_source_signature}', request #> '{payload,source_signature}'
  )
) from pct01_requests where request_name='source-attendance';
reset role;

select is(
  (select array_agg(response->>'error_code' order by response_name)::text[]
   from pct01_responses where response_name like 'clock-skew-%-future'),
  array_fill('VALIDATION_FAILED'::text,array[4]),
  'PCT01-CS01 materially future Planning v2 commands fail closed'
);
select ok(
  not exists (
    select 1 from pct01_responses response
    where response.response_name like 'clock-skew-%-future'
      and not exists (
        select 1 from jsonb_array_elements(response.response->'field_errors') field_error
        where field_error->>'field'='requested_at'
      )
  ),
  'PCT01-CS02 materially future responses identify requested_at safely'
);
select is(
  (select response->>'error_code' from pct01_responses where response_name='clock-skew-attendance-malformed'),
  'VALIDATION_FAILED',
  'PCT01-CS03 malformed requested_at remains rejected'
);
select ok(
  (select exists (
    select 1 from jsonb_array_elements(response->'field_errors') field_error
    where field_error->>'field'='requested_at'
  ) from pct01_responses where response_name='clock-skew-attendance-malformed'),
  'PCT01-CS04 malformed requested_at retains field evidence'
);
select is(
  (select counts from pct01_clock_skew_counts),
  jsonb_build_object(
    'menu_version',(select version from atlas_planning.weekly_menus where week_start='2026-11-09'),
    'attendance_version',(select version from atlas_planning.attendance_batches where period_start='2026-11-09'),
    'pantry_version',(select version from atlas_planning.pantry_need_batches where week_start='2026-11-09'),
    'run_count',(select count(*) from atlas_planning.need_generation_runs),
    'confirmed_need_batch_count',(select count(*) from atlas_planning.confirmed_need_batches)
  ),
  'PCT01-CS05 rejected time envelopes create no source, run, or Confirmed Need mutation'
);

-- ISSUE-223 assembled daily isolation: the same approved parent week can
-- produce Tuesday without changing the already-governed Monday chain.
create temporary table pct01_daily_isolation as
select pg_catalog.jsonb_build_object(
  'monday_run_id', batch.current_need_generation_run_id,
  'monday_run_version', run.version,
  'monday_batch_id', batch.confirmed_need_batch_id,
  'monday_batch_version', batch.version,
  'purchase_handoffs', (select count(*) from atlas_planning.purchase_handoff_batches),
  'allocations', (select count(*) from atlas_procurement.fulfilment_allocations),
  'purchase_orders', (select count(*) from atlas_procurement.purchase_orders),
  'receiving', (select count(*) from atlas_evidence.supplier_receiving_evidence),
  'dispatch', (select count(*) from atlas_dispatch.dispatch_plans)
) counts
from atlas_planning.confirmed_need_batches batch
join atlas_planning.need_generation_runs run
  on run.need_generation_run_id=batch.current_need_generation_run_id
where batch.period_start='2026-11-02' and batch.period_end='2026-11-02';

set local role authenticated;
insert into pct01_responses values (
  'daily-range-rejected',
  atlas_api.execute_need_generation(jsonb_build_object(
    'contract_version','RMVP-04.v3',
    'command_id','e4800000-0000-0000-0000-000000000090',
    'correlation_id','e4800000-0000-0000-0000-000000000091',
    'idempotency_key','pct01-daily-range-rejected',
    'expected_version',1,
    'requested_by_auth_subject','e4000000-0000-0000-0000-000000000101',
    'requested_at',transaction_timestamp(),
    'reason_code','NEED_GENERATION_EXECUTED','reason_note',null,
    'payload',jsonb_build_object(
      'period_start','2026-11-03','period_end','2026-11-07',
      'expected_current_need_generation_run_id',null
    )
  ))
), (
  'execute-tuesday',
  atlas_api.execute_need_generation(jsonb_build_object(
    'contract_version','RMVP-04.v3',
    'command_id','e4800000-0000-0000-0000-000000000092',
    'correlation_id','e4800000-0000-0000-0000-000000000093',
    'idempotency_key','pct01-execute-tuesday',
    'expected_version',1,
    'requested_by_auth_subject','e4000000-0000-0000-0000-000000000101',
    'requested_at',transaction_timestamp(),
    'reason_code','NEED_GENERATION_EXECUTED','reason_note',null,
    'payload',jsonb_build_object(
      'service_date','2026-11-03',
      'expected_current_need_generation_run_id',null
    )
  ))
);
reset role;

set local role authenticated;
insert into pct01_responses
select 'execute-tuesday-replay',atlas_api.execute_need_generation(
  jsonb_build_object(
    'contract_version','RMVP-04.v3',
    'command_id','e4800000-0000-0000-0000-000000000092',
    'correlation_id','e4800000-0000-0000-0000-000000000093',
    'idempotency_key','pct01-execute-tuesday',
    'expected_version',1,
    'requested_by_auth_subject','e4000000-0000-0000-0000-000000000101',
    'requested_at',transaction_timestamp(),
    'reason_code','NEED_GENERATION_EXECUTED','reason_note',null,
    'payload',jsonb_build_object(
      'service_date','2026-11-03',
      'expected_current_need_generation_run_id',null
    )
  )
);
reset role;

select is((select response->>'error_code' from pct01_responses where response_name='daily-range-rejected'),'VALIDATION_FAILED','PCT01-D05 v3 rejects caller-authored multi-day ranges');
select is((select count(*) from atlas_planning.need_generation_runs where period_start='2026-11-03'),1::bigint,'PCT01-D06 rejected range writes nothing and Tuesday writes one chain');
select ok((select response->>'success'='true' and response->>'contract_version'='RMVP-04.v3' from pct01_responses where response_name='execute-tuesday'),'PCT01-D07 Tuesday daily generation succeeds');
select ok((select period_start=period_end and period_start='2026-11-03' from atlas_planning.need_generation_runs where need_generation_run_id=(select (response->'affected_aggregate_ids'->>'need_generation_run_id')::uuid from pct01_responses where response_name='execute-tuesday')),'PCT01-D08 Tuesday run is D..D');
select is((select array_agg(distinct service_date order by service_date)::text[] from atlas_planning.theoretical_need_lines where need_generation_run_id=(select (response->'affected_aggregate_ids'->>'need_generation_run_id')::uuid from pct01_responses where response_name='execute-tuesday')),array['2026-11-03']::text[],'PCT01-D09 Tuesday theoretical evidence is date-isolated');
select ok((select batch.period_start=batch.period_end and batch.period_start='2026-11-03' and not exists (select 1 from atlas_planning.confirmed_need_lines line where line.confirmed_need_batch_id=batch.confirmed_need_batch_id and line.service_date<>'2026-11-03') from atlas_planning.confirmed_need_batches batch where batch.confirmed_need_batch_id=(select (response->'affected_aggregate_ids'->>'confirmed_need_batch_id')::uuid from pct01_responses where response_name='execute-tuesday')),'PCT01-D10 Tuesday Confirmed Need and every line are daily');
select ok((select snapshot.weekly_menu_approval_snapshot_id='e4200000-0000-0000-0000-000000000002' and snapshot.attendance_approval_snapshot_id='e4300000-0000-0000-0000-000000000002' from atlas_planning.need_generation_input_snapshots snapshot where snapshot.need_generation_run_id=(select (response->'affected_aggregate_ids'->>'need_generation_run_id')::uuid from pct01_responses where response_name='execute-tuesday')),'PCT01-D11 Tuesday binds the exact approved parent snapshots');
select is((select counts - array['purchase_handoffs','allocations','purchase_orders','receiving','dispatch'] from pct01_daily_isolation),(select pg_catalog.jsonb_build_object('monday_run_id',batch.current_need_generation_run_id,'monday_run_version',run.version,'monday_batch_id',batch.confirmed_need_batch_id,'monday_batch_version',batch.version) from atlas_planning.confirmed_need_batches batch join atlas_planning.need_generation_runs run on run.need_generation_run_id=batch.current_need_generation_run_id where batch.period_start='2026-11-02' and batch.period_end='2026-11-02'),'PCT01-D12 Tuesday does not mutate Monday identity or versions');
select is((select count(*) from atlas_planning.confirmed_need_batches where period_start='2026-11-03' and period_end='2026-11-03'),1::bigint,'PCT01-D13 exactly one current Tuesday Confirmed Need chain exists');
select is((select pg_catalog.jsonb_build_object('purchase_handoffs',counts->'purchase_handoffs','allocations',counts->'allocations','purchase_orders',counts->'purchase_orders','receiving',counts->'receiving','dispatch',counts->'dispatch') from pct01_daily_isolation),pg_catalog.jsonb_build_object('purchase_handoffs',(select count(*) from atlas_planning.purchase_handoff_batches),'allocations',(select count(*) from atlas_procurement.fulfilment_allocations),'purchase_orders',(select count(*) from atlas_procurement.purchase_orders),'receiving',(select count(*) from atlas_evidence.supplier_receiving_evidence),'dispatch',(select count(*) from atlas_dispatch.dispatch_plans)),'PCT01-D14 daily generation creates no downstream operational facts');
select is((select response from pct01_responses where response_name='execute-tuesday-replay'),(select response from pct01_responses where response_name='execute-tuesday'),'PCT01-D15 exact Tuesday retry replays without history');
select is((select response->'authoritative_readback'->'preflight'->>'downstream_currentness' from pct01_responses where response_name='execute-tuesday'),'CURRENT','PCT01-D16 committed Tuesday result is current');
select is((select count(*) from atlas_core.command_receipts where command_id='e4800000-0000-0000-0000-000000000092'),1::bigint,'PCT01-D18 Tuesday replay owns one receipt and no extra history');

-- Change Thursday only after Tuesday exists. The exact parent snapshot advances,
-- but Tuesday's stable date-line facts remain identical and therefore current.
with proposed(rows) as (
  select jsonb_set(
    jsonb_set(request#>'{payload,rows}','{0,requested_quantity}','"3.300000"'::jsonb),
    '{0,note}','"Thursday-only change after Tuesday generation"'::jsonb
  )
  from pct01_requests where request_name='02b-source-policy'
), canonical(raw_rows,canonical_rows) as (
  select rows,atlas_core.pantry_02_canonical_rows('2026-11-02',rows)
  from proposed
)
insert into pct01_requests
select 'daily-thursday-source-successor',jsonb_build_object(
  'contract_version','PANTRY-02.v2',
  'command_id','e4800000-0000-0000-0000-000000000094',
  'correlation_id','e4800000-0000-0000-0000-000000000095',
  'idempotency_key','pct01-daily-thursday-source-successor',
  'expected_version',(select (response->'new_versions'->>'aggregate_version')::bigint from pct01_responses where response_name='02b-source-policy'),
  'requested_by_auth_subject','e4000000-0000-0000-0000-000000000101',
  'requested_at',transaction_timestamp(),
  'reason_code','PANTRY_SAVED','reason_note','Thursday-only daily-isolation proof',
  'payload',jsonb_build_object(
    'week_start','2026-11-02','no_additions_confirmed',false,
    'source_signature',atlas_core.pantry_02_signature('2026-11-02',false,canonical_rows),
    'expected_source_signature',(select request#>>'{payload,source_signature}' from pct01_requests where request_name='02b-source-policy'),
    'rows',raw_rows
  )
) from canonical;

set local role authenticated;
insert into pct01_responses
select 'daily-thursday-source-successor',atlas_api.save_pantry(request)
from pct01_requests where request_name='daily-thursday-source-successor';
insert into pct01_responses values (
  'daily-tuesday-after-thursday-change',
  atlas_api.get_planning_input_preflight(jsonb_build_object(
    'contract_version','RMVP-03B.v2',
    'requested_by_auth_subject','e4000000-0000-0000-0000-000000000101',
    'correlation_id','e4800000-0000-0000-0000-000000000096',
    'payload',jsonb_build_object('period_start','2026-11-03','period_end','2026-11-03')
  ))
);
reset role;

select ok((select response->>'success'='true' from pct01_responses where response_name='daily-thursday-source-successor'),'PCT01-D19 unrelated Thursday source successor is accepted');
select is((select response->'preflight'->>'downstream_currentness' from pct01_responses where response_name='daily-tuesday-after-thursday-change'),'CURRENT','PCT01-D20 Thursday-only source change leaves Tuesday current');

select * from finish();
rollback;
