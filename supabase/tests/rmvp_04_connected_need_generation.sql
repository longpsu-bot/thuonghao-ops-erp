begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
select plan(48);

grant usage on schema extensions to authenticated;
grant execute on all functions in schema extensions to authenticated;

-- Bounded public surface and runtime posture (1-10).
select is(
  (select count(*)::integer from atlas_core.capabilities where capability_code = 'planning.need_generation.write'),
  1,
  'RMVP04-01 exactly one Need Generation write capability exists'
);
select is(
  (select count(*)::integer from atlas_core.role_capabilities rc join atlas_core.capabilities c using (capability_id) where c.capability_code = 'planning.need_generation.write'),
  0,
  'RMVP04-02 the new capability has no production application-role binding'
);
select is(
  (
    select array_agg(p.proname order by p.proname)::text[]
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
      and p.proname in (
        'get_need_generation_workbench',
        'create_need_generation_run',
        'validate_need_generation_run',
        'release_need_generation_run',
        'invalidate_need_generation_run'
      )
  ),
  array[
    'create_need_generation_run',
    'get_need_generation_workbench',
    'invalidate_need_generation_run',
    'release_need_generation_run',
    'validate_need_generation_run'
  ]::text[],
  'RMVP04-03 exactly five RMVP-04 APIs exist'
);
select ok(
  (
    select bool_and(pg_get_userbyid(p.proowner) = 'atlas_need_generation_runtime')
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
      and p.proname in (
        'get_need_generation_workbench',
        'create_need_generation_run',
        'validate_need_generation_run',
        'release_need_generation_run',
        'invalidate_need_generation_run'
      )
  ),
  'RMVP04-04 the dedicated runtime owns all five APIs'
);
select ok(
  (
    select bool_and(p.prosecdef and p.proconfig = array['search_path=""']::text[])
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
      and p.proname in (
        'get_need_generation_workbench',
        'create_need_generation_run',
        'validate_need_generation_run',
        'release_need_generation_run',
        'invalidate_need_generation_run'
      )
  ),
  'RMVP04-05 every RMVP-04 API is a fixed-search-path definer'
);
select ok(
  (
    select bool_and(has_function_privilege('authenticated', p.oid, 'EXECUTE'))
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
      and p.proname in (
        'get_need_generation_workbench',
        'create_need_generation_run',
        'validate_need_generation_run',
        'release_need_generation_run',
        'invalidate_need_generation_run'
      )
  ),
  'RMVP04-06 authenticated can execute the reviewed surface'
);
select ok(
  (
    select bool_and(not has_function_privilege('anon', p.oid, 'EXECUTE'))
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
      and p.proname like '%need_generation%'
      and p.proname <> 'create_confirmed_needs_from_generation'
  ),
  'RMVP04-07 anon cannot execute an RMVP-04 API'
);
select ok(
  (
    select bool_and(not has_function_privilege('service_role', p.oid, 'EXECUTE'))
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
      and p.proname like '%need_generation%'
      and p.proname <> 'create_confirmed_needs_from_generation'
  ),
  'RMVP04-08 service_role cannot execute an RMVP-04 API'
);
select is(
  (
    select jsonb_build_object(
      'login', rolcanlogin,
      'inherit', rolinherit,
      'superuser', rolsuper,
      'create_role', rolcreaterole,
      'create_db', rolcreatedb,
      'replication', rolreplication,
      'bypass_rls', rolbypassrls
    )
    from pg_roles
    where rolname = 'atlas_need_generation_runtime'
  ),
  jsonb_build_object(
    'login', false,
    'inherit', false,
    'superuser', false,
    'create_role', false,
    'create_db', false,
    'replication', false,
    'bypass_rls', false
  ),
  'RMVP04-09 the dedicated runtime is NOLOGIN NOINHERIT and unprivileged'
);
select is(
  jsonb_build_object(
    'tables', (select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname like 'atlas\_%' escape '\' and c.relkind = 'r'),
    'views', (select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname like 'atlas\_%' escape '\' and c.relkind in ('v', 'm')),
    'rmvp04_triggers', (select count(*) from pg_trigger where not tgisinternal and tgname like 'rmvp_04_%'),
    'rmvp06_validation_relations', (
      select array_agg(format('%I.%I', n.nspname, c.relname) order by n.nspname, c.relname)::text[]
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'atlas_planning'
        and c.relkind = 'r'
        and c.relname in (
          'confirmed_need_validation_attempts',
          'confirmed_need_validation_issues',
          'confirmed_need_validation_lines'
        )
    ),
    'rmvp07_release_relations', (
      select array_agg(format('%I.%I', n.nspname, c.relname) order by n.nspname, c.relname)::text[]
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'atlas_planning'
        and c.relkind = 'r'
        and c.relname = 'confirmed_need_releases'
    )
  ),
  jsonb_build_object(
    'tables', 102,
    'views', 2,
    'rmvp04_triggers', 0,
    'rmvp06_validation_relations', array[
      'atlas_planning.confirmed_need_validation_attempts',
      'atlas_planning.confirmed_need_validation_issues',
      'atlas_planning.confirmed_need_validation_lines'
    ]::text[],
    'rmvp07_release_relations', array[
      'atlas_planning.confirmed_need_releases'
    ]::text[]
  ),
  'RMVP04-10 RMVP-04 adds no relation, view, or source trigger while the current platform includes the exact RMVP-06/07 evidence relations'
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
  'confirmed_need_generation.materialize'
);
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
insert into atlas_admin.schools (school_id, customer_id, school_code, school_name, school_type_id, default_delivery_location_id, display_order)
values ('e4100000-0000-0000-0000-000000000005', 'e4100000-0000-0000-0000-000000000001', 'rmvp04-school', 'RMVP-04 School', 'e4100000-0000-0000-0000-000000000004', 'e4100000-0000-0000-0000-000000000002', 10);
insert into atlas_admin.units (unit_id, unit_code, unit_name, dimension_code)
values ('e4100000-0000-0000-0000-000000000006', 'rmvp04-kg', 'RMVP-04 kilogram', 'mass');
insert into atlas_admin.ingredients (ingredient_id, ingredient_code, ingredient_name)
values ('e4100000-0000-0000-0000-000000000007', 'rmvp04-rice', 'RMVP-04 rice');
insert into atlas_admin.dishes (dish_id, dish_code, dish_name, dish_status, display_order, requires_need_generation) values
  ('e4100000-0000-0000-0000-000000000008', 'rmvp04-dish', 'RMVP-04 dish', 'ACTIVE', 10, true),
  ('e4600000-0000-0000-0000-000000000001', 'rmvp04-typed-ambiguous', 'RMVP-04 typed ambiguity dish', 'ACTIVE', 20, true),
  ('e4700000-0000-0000-0000-000000000001', 'rmvp04-general-ambiguous', 'RMVP-04 general ambiguity dish', 'ACTIVE', 30, true);
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
  ('e4600000-0000-0000-0000-000000000008', 'e4600000-0000-0000-0000-000000000002', 'rice'),
  ('e4600000-0000-0000-0000-000000000009', 'e4600000-0000-0000-0000-000000000003', 'rice'),
  ('e4600000-0000-0000-0000-000000000010', 'e4600000-0000-0000-0000-000000000004', 'rice'),
  ('e4700000-0000-0000-0000-000000000008', 'e4700000-0000-0000-0000-000000000002', 'rice'),
  ('e4700000-0000-0000-0000-000000000009', 'e4700000-0000-0000-0000-000000000003', 'rice');
insert into atlas_admin.recipe_line_revisions (recipe_line_revision_id, recipe_id, recipe_version_id, recipe_line_id, line_revision_number, ingredient_id, quantity_per_basis, unit_id, created_by_actor_id)
values
  ('e4100000-0000-0000-0000-000000000012', 'e4100000-0000-0000-0000-000000000009', 'e4100000-0000-0000-0000-000000000010', 'e4100000-0000-0000-0000-000000000011', 1, 'e4100000-0000-0000-0000-000000000007', 12.5, 'e4100000-0000-0000-0000-000000000006', 'e4000000-0000-0000-0000-000000000001'),
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
  ('e4300000-0000-0000-0000-000000000004', 'e4300000-0000-0000-0000-000000000001', 'e4100000-0000-0000-0000-000000000005', '2026-11-03', 0, 0, 'e4000000-0000-0000-0000-000000000001', 'e4000000-0000-0000-0000-000000000001'),
  ('e4600000-0000-0000-0000-000000000030', 'e4300000-0000-0000-0000-000000000001', 'e4100000-0000-0000-0000-000000000005', '2026-11-04', 10, 2, 'e4000000-0000-0000-0000-000000000001', 'e4000000-0000-0000-0000-000000000001'),
  ('e4700000-0000-0000-0000-000000000030', 'e4300000-0000-0000-0000-000000000001', 'e4100000-0000-0000-0000-000000000005', '2026-11-05', 10, 2, 'e4000000-0000-0000-0000-000000000001', 'e4000000-0000-0000-0000-000000000001');
insert into atlas_planning.attendance_approval_snapshots (attendance_approval_snapshot_id, attendance_batch_id, attendance_version, approved_by_actor_id, approved_at)
values ('e4300000-0000-0000-0000-000000000002', 'e4300000-0000-0000-0000-000000000001', 1, 'e4000000-0000-0000-0000-000000000001', '2026-11-01 09:05:00+07');
insert into atlas_planning.attendance_approval_snapshot_lines (attendance_approval_snapshot_line_id, attendance_approval_snapshot_id, attendance_batch_id, attendance_version, attendance_line_id, school_id, service_date, student_portions, teacher_portions) values
  ('e4300000-0000-0000-0000-000000000005', 'e4300000-0000-0000-0000-000000000002', 'e4300000-0000-0000-0000-000000000001', 1, 'e4300000-0000-0000-0000-000000000003', 'e4100000-0000-0000-0000-000000000005', '2026-11-02', 15, 5),
  ('e4300000-0000-0000-0000-000000000006', 'e4300000-0000-0000-0000-000000000002', 'e4300000-0000-0000-0000-000000000001', 1, 'e4300000-0000-0000-0000-000000000004', 'e4100000-0000-0000-0000-000000000005', '2026-11-03', 0, 0),
  ('e4600000-0000-0000-0000-000000000031', 'e4300000-0000-0000-0000-000000000002', 'e4300000-0000-0000-0000-000000000001', 1, 'e4600000-0000-0000-0000-000000000030', 'e4100000-0000-0000-0000-000000000005', '2026-11-04', 10, 2),
  ('e4700000-0000-0000-0000-000000000031', 'e4300000-0000-0000-0000-000000000002', 'e4300000-0000-0000-0000-000000000001', 1, 'e4700000-0000-0000-0000-000000000030', 'e4100000-0000-0000-0000-000000000005', '2026-11-05', 10, 2);

insert into atlas_planning.pantry_need_purposes (pantry_need_purpose_id, purpose_code, purpose_name_vi, purpose_description, note_rule, purpose_status, display_order)
values ('e4400000-0000-0000-0000-000000000001', 'rmvp04_supplement', 'Bổ sung RMVP-04', 'Synthetic connected Need Generation fixture.', 'OPTIONAL', 'ACTIVE', 10);
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
values ('e4400000-0000-0000-0000-000000000005', 'e4400000-0000-0000-0000-000000000003', 'e4400000-0000-0000-0000-000000000004', '2026-11-02', 'e4100000-0000-0000-000000000005', 'rmvp04-school', 'RMVP-04 School', 'e4100000-0000-0000-0000-000000000003', 'rmvp04-pantry', 'RMVP-04 Pantry Store', 'Fixture pantry', 'e4100000-0000-0000-0000-000000000007', 'rmvp04-rice', 'RMVP-04 rice', 'e4100000-0000-0000-0000-000000000006', 'rmvp04-kg', 'RMVP-04 kilogram', 'e4400000-0000-0000-0000-000000000001', 'rmvp04_supplement', 'Bổ sung RMVP-04', 'Synthetic connected Need Generation fixture.', 'OPTIONAL', 'Separate Pantry delivery', 'RMVP04', '1', 2);

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
  'Bổ sung RMVP-04',
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
    'Bá»• sung RMVP-04',
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
    'Bá»• sung RMVP-04',
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

create temporary table rmvp04_responses (
  response_name text primary key,
  response jsonb not null
);
grant select, insert on rmvp04_responses to authenticated;

create temporary table rmvp04_requests (
  request_name text primary key,
  request jsonb not null
);
grant select, insert on rmvp04_requests to authenticated;

insert into rmvp04_requests values (
  'evaluate',
  pg_temp.rmvp04_readiness_command(
    'e4500000-0000-0000-0000-000000000001',
    'rmvp04-evaluate',
    'ABSENT',
    null,
    null,
    'READINESS_EVALUATION_REQUESTED',
    jsonb_build_object(
      'period_start', '2026-11-02',
      'period_end', '2026-11-02',
      'source_candidates', jsonb_build_object(
        'weekly_menu', jsonb_build_object('weekly_menu_id', 'e4200000-0000-0000-0000-000000000001', 'weekly_menu_version', 1, 'weekly_menu_approval_snapshot_id', 'e4200000-0000-0000-0000-000000000002'),
        'attendance', jsonb_build_object('attendance_batch_id', 'e4300000-0000-0000-0000-000000000001', 'attendance_version', 1, 'attendance_approval_snapshot_id', 'e4300000-0000-0000-0000-000000000002'),
        'pantry', jsonb_build_object('pantry_need_batch_id', 'e4400000-0000-0000-0000-000000000002', 'pantry_need_batch_version', 1, 'pantry_need_approval_snapshot_id', 'e4400000-0000-0000-0000-000000000003')
      )
    )
  )
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'e4000000-0000-0000-0000-000000000101', true);
insert into rmvp04_responses
select 'evaluate', atlas_api.evaluate_planning_input_readiness(request)
from rmvp04_requests where request_name = 'evaluate';
reset role;

select ok(
  (select response->>'success' = 'true' and response->'authoritative_readback'->>'decision' = 'READY' from rmvp04_responses where response_name = 'evaluate'),
  'RMVP04-11 real readiness evaluation succeeds as READY'
);

insert into rmvp04_requests
select
  'request',
  pg_temp.rmvp04_readiness_command(
    'e4500000-0000-0000-0000-000000000002',
    'rmvp04-request',
    'READY',
    (response->'affected_aggregate_ids'->>'planning_input_evaluation_id')::uuid,
    (response->'new_versions'->>'current_evaluation_version')::bigint,
    'NEED_GENERATION_HANDOFF_REQUESTED',
    jsonb_build_object(
      'planning_input_set_id', response->'affected_aggregate_ids'->>'planning_input_set_id',
      'period_start', '2026-11-02',
      'period_end', '2026-11-02'
    )
  )
from rmvp04_responses where response_name = 'evaluate';

set local role authenticated;
insert into rmvp04_responses
select 'request', atlas_api.request_planning_input_need_generation(request)
from rmvp04_requests where request_name = 'request';
reset role;

select ok(
  (select response->>'success' = 'true' and response->'authoritative_readback'->>'decision' = 'NEED_GENERATION_REQUESTED' from rmvp04_responses where response_name = 'request'),
  'RMVP04-12 readiness advances through the real Need Generation request command'
);

insert into rmvp04_requests
select
  'create',
  pg_temp.rmvp04_command(
    'e4500000-0000-0000-0000-000000000003',
    'rmvp04-create',
    (evaluation.response->'new_versions'->>'current_evaluation_version')::bigint,
    'NEED_GENERATION_CREATED',
    null,
    jsonb_build_object(
      'planning_input_set_id', requested.response->'affected_aggregate_ids'->>'planning_input_set_id',
      'planning_input_evaluation_id', evaluation.response->'affected_aggregate_ids'->>'planning_input_evaluation_id',
      'period_start', '2026-11-02',
      'period_end', '2026-11-02'
    )
  )
from rmvp04_responses evaluation
cross join rmvp04_responses requested
where evaluation.response_name = 'evaluate' and requested.response_name = 'request';

set local role authenticated;
insert into rmvp04_responses
select 'create', atlas_api.create_need_generation_run(request)
from rmvp04_requests where request_name = 'create';
reset role;

select ok(
  (select response->>'success' = 'true' and response->'new_versions'->>'need_generation_run_version' = '1' and response->'authoritative_readback'->'selected_run'->>'status' = 'GENERATED' from rmvp04_responses where response_name = 'create'),
  'RMVP04-13 generation creates one version-one GENERATED run'
);
select is(
  (
    select jsonb_object_agg(contribution_family, family_count order by contribution_family)
    from (
      select contribution_family, count(*) as family_count
      from atlas_planning.theoretical_need_lines
      where need_generation_run_id = (select (response->'affected_aggregate_ids'->>'need_generation_run_id')::uuid from rmvp04_responses where response_name = 'create')
      group by contribution_family
    ) counts
  ),
  jsonb_build_object('PANTRY_DIRECT', 1, 'RECIPE_DERIVED', 1),
  'RMVP04-14 atomic Recipe and Pantry contributions coexist'
);

set local role authenticated;
insert into rmvp04_responses
select 'read-generated', atlas_api.get_need_generation_workbench(pg_temp.rmvp04_read((response->'affected_aggregate_ids'->>'need_generation_run_id')::uuid))
from rmvp04_responses where response_name = 'create';
reset role;

select is(
  (
    select jsonb_agg(jsonb_build_object(
      'date', item->>'service_date',
      'location', item->>'delivery_location_id',
      'recipe', item->'recipe_derived_quantity',
      'pantry', item->'pantry_direct_quantity',
      'total', item->'total_theoretical_quantity'
    ) order by item->>'service_date', item->>'delivery_location_id')
    from rmvp04_responses response_row
    cross join lateral jsonb_array_elements(response_row.response->'workbench'->'grouped_requirements') item
    where response_row.response_name = 'read-generated'
  ),
  jsonb_build_array(
    jsonb_build_object('date', '2026-11-02', 'location', 'e4100000-0000-0000-0000-000000000002', 'recipe', 2.500000, 'pantry', 0, 'total', 2.500000),
    jsonb_build_object('date', '2026-11-02', 'location', 'e4100000-0000-0000-0000-000000000003', 'recipe', 0, 'pantry', 2.000000, 'total', 2.000000)
  ),
  'RMVP04-15 grouped totals remain separated by date and Delivery Location without Unit collapse'
);
select is(
  (
    select jsonb_build_object(
      'run_blockers', blocking_issue_count,
      'persisted_blockers', (select count(*) from atlas_planning.need_generation_issues issue where issue.need_generation_run_id = run.need_generation_run_id and issue.severity = 'BLOCKING'),
      'run_warnings', warning_count,
      'persisted_warnings', (select count(*) from atlas_planning.need_generation_issues issue where issue.need_generation_run_id = run.need_generation_run_id and issue.severity = 'WARNING')
    )
    from atlas_planning.need_generation_runs run
    where run.need_generation_run_id = (select (response->'affected_aggregate_ids'->>'need_generation_run_id')::uuid from rmvp04_responses where response_name = 'create')
  ),
  jsonb_build_object('run_blockers', 0, 'persisted_blockers', 0, 'run_warnings', 0, 'persisted_warnings', 0),
  'RMVP04-16 run issue counts are every-and-only persisted blockers and warnings'
);
select is(
  (
    select jsonb_build_object(
      'blockers', jsonb_array_length(response->'workbench'->'blocking_issues'),
      'warnings', jsonb_array_length(response->'workbench'->'warnings'),
      'warning_code', response->'workbench'->'warnings'->0->>'issue_code'
    )
    from rmvp04_responses where response_name = 'read-generated'
  ),
  jsonb_build_object('blockers', 0, 'warnings', 0, 'warning_code', null),
  'RMVP04-17 positive mixed workbench returns the complete empty issue evidence'
);

set local role authenticated;
insert into rmvp04_responses
select 'create-replay', atlas_api.create_need_generation_run(request)
from rmvp04_requests where request_name = 'create';
insert into rmvp04_responses
select 'create-conflict', atlas_api.create_need_generation_run(request || jsonb_build_object('idempotency_key', 'rmvp04-create-changed'))
from rmvp04_requests where request_name = 'create';
reset role;

select is(
  (select response from rmvp04_responses where response_name = 'create-replay'),
  (select response from rmvp04_responses where response_name = 'create'),
  'RMVP04-18 exact create replay returns the immutable original response'
);
select is(
  (select response->>'error_code' from rmvp04_responses where response_name = 'create-conflict'),
  'IDEMPOTENCY_CONFLICT',
  'RMVP04-19 changed idempotency reuse fails'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'e4000000-0000-0000-0000-000000000102', true);
insert into rmvp04_responses
select 'unauthorized', atlas_api.create_need_generation_run(pg_temp.rmvp04_command('e4500000-0000-0000-0000-000000000020', 'rmvp04-unauthorized', 1, 'NEED_GENERATION_CREATED', null, request->'payload', 'e4000000-0000-0000-0000-000000000102'))
from rmvp04_requests where request_name = 'create';
select set_config('request.jwt.claim.sub', 'e4000000-0000-0000-0000-000000000103', true);
insert into rmvp04_responses
select 'wrong-scope', atlas_api.create_need_generation_run(pg_temp.rmvp04_command('e4500000-0000-0000-0000-000000000021', 'rmvp04-wrong-scope', 1, 'NEED_GENERATION_CREATED', null, request->'payload', 'e4000000-0000-0000-0000-000000000103'))
from rmvp04_requests where request_name = 'create';
reset role;

select is((select response->>'error_code' from rmvp04_responses where response_name = 'unauthorized'), 'CAPABILITY_DENIED', 'RMVP04-20 capability-free human call fails');
select is((select response->>'error_code' from rmvp04_responses where response_name = 'wrong-scope'), 'SCOPE_DENIED', 'RMVP04-21 wrong-scope human call fails');

insert into rmvp04_requests
select 'validate', pg_temp.rmvp04_command(
  'e4500000-0000-0000-0000-000000000004', 'rmvp04-validate', 1,
  'NEED_GENERATION_VALIDATED', null,
  jsonb_build_object('need_generation_run_id', response->'affected_aggregate_ids'->>'need_generation_run_id')
)
from rmvp04_responses where response_name = 'create';
set local role authenticated;
select set_config('request.jwt.claim.sub', 'e4000000-0000-0000-0000-000000000101', true);
insert into rmvp04_responses
select 'validate', atlas_api.validate_need_generation_run(request)
from rmvp04_requests where request_name = 'validate';
reset role;
select ok((select response->>'success' = 'true' and response->'new_versions'->>'need_generation_run_version' = '2' from rmvp04_responses where response_name = 'validate'), 'RMVP04-22 blocker-free warning-bearing run validates to version two');

insert into rmvp04_requests
select 'release', pg_temp.rmvp04_command(
  'e4500000-0000-0000-0000-000000000005', 'rmvp04-release', 2,
  'NEED_GENERATION_RELEASED', null,
  jsonb_build_object('need_generation_run_id', response->'affected_aggregate_ids'->>'need_generation_run_id')
)
from rmvp04_responses where response_name = 'create';
set local role authenticated;
insert into rmvp04_responses
select 'release', atlas_api.release_need_generation_run(request)
from rmvp04_requests where request_name = 'release';
reset role;
select is(
  (
    select jsonb_build_object(
      'success', response->>'success',
      'version', response->'new_versions'->>'need_generation_run_version',
      'line_members', (select count(*) from atlas_planning.need_generation_release_snapshot_lines where need_generation_release_snapshot_id = (response->'affected_aggregate_ids'->>'need_generation_release_snapshot_id')::uuid),
      'issue_members', (select count(*) from atlas_planning.need_generation_release_snapshot_issues where need_generation_release_snapshot_id = (response->'affected_aggregate_ids'->>'need_generation_release_snapshot_id')::uuid)
    )
    from rmvp04_responses where response_name = 'release'
  ),
  jsonb_build_object('success', 'true', 'version', '3', 'line_members', 2, 'issue_members', 0),
  'RMVP04-23 release advances once and captures every line and issue'
);

set local role authenticated;
insert into rmvp04_responses
select 'materialize', atlas_api.create_confirmed_needs_from_generation(pg_temp.rmvp04_cmd15((response->'affected_aggregate_ids'->>'need_generation_run_id')::uuid, 3))
from rmvp04_responses where response_name = 'create';
reset role;
-- The API executes each command in its own transaction. Flush CMD-15's
-- deferred guards while its source run is still released, then restore the
-- suite transaction's deferred mode before testing later correction.
set constraints all immediate;
set constraints all deferred;
select ok((select response->>'success' = 'true' and response->'new_versions'->>'confirmed_need_batch_version' = '1' from rmvp04_responses where response_name = 'materialize'), 'RMVP04-24 existing CMD-15 performs initial materialization');
select is(
  (
    select jsonb_agg(jsonb_build_object('location', delivery_location_id, 'quantity', theoretical_quantity) order by delivery_location_id)
    from atlas_planning.confirmed_need_line_revisions
    where confirmed_need_batch_id = (select (response->'affected_aggregate_ids'->>'confirmed_need_batch_id')::uuid from rmvp04_responses where response_name = 'materialize')
      and is_current
  ),
  jsonb_build_array(
    jsonb_build_object('location', 'e4100000-0000-0000-0000-000000000002', 'quantity', 2.500000),
    jsonb_build_object('location', 'e4100000-0000-0000-0000-000000000003', 'quantity', 2.000000)
  ),
  'RMVP04-25 Confirmed Need quantities stay separated by destination'
);
select is(
  (
    select count(distinct revision.delivery_location_id)::integer
    from atlas_planning.confirmed_need_line_revisions revision
    where revision.confirmed_need_batch_id = (select (response->'affected_aggregate_ids'->>'confirmed_need_batch_id')::uuid from rmvp04_responses where response_name = 'materialize')
      and revision.is_current
  ),
  2,
  'RMVP04-26 Confirmed Need retains both exact Delivery Locations'
);
select is(
  (
    select jsonb_build_object(
      'memberships', count(*),
      'families', count(distinct source.contribution_family),
      'member_total', sum(membership.controlled_contribution_quantity)
    )
    from atlas_planning.confirmed_need_line_revision_contributions membership
    join atlas_planning.theoretical_need_lines source using (theoretical_need_line_id)
    where membership.confirmed_need_batch_id = (select (response->'affected_aggregate_ids'->>'confirmed_need_batch_id')::uuid from rmvp04_responses where response_name = 'materialize')
  ),
  jsonb_build_object('memberships', 2, 'families', 2, 'member_total', 4.500000),
  'RMVP04-27 materialization membership is every positive Recipe and Pantry contribution'
);

set local role authenticated;
insert into rmvp04_responses
select 'read-materialized', atlas_api.get_need_generation_workbench(pg_temp.rmvp04_read((response->'affected_aggregate_ids'->>'need_generation_run_id')::uuid))
from rmvp04_responses where response_name = 'create';
reset role;
select is(
  (
    select jsonb_build_object(
      'batch_id', response->'workbench'->'materialization'->>'confirmed_need_batch_id',
      'version', response->'workbench'->'materialization'->>'confirmed_need_batch_version',
      'status', response->'workbench'->'materialization'->>'confirmed_need_status',
      'mode', response->'workbench'->'materialization'->>'materialization_mode'
    )
    from rmvp04_responses where response_name = 'read-materialized'
  ),
  (
    select jsonb_build_object(
      'batch_id', response->'affected_aggregate_ids'->>'confirmed_need_batch_id',
      'version', '1',
      'status', 'DRAFT_REVIEW',
      'mode', 'INITIAL'
    )
    from rmvp04_responses where response_name = 'materialize'
  ),
  'RMVP04-28 workbench reports the authoritative CMD-15 materialization state'
);

insert into rmvp04_requests
select 'invalidate', pg_temp.rmvp04_command(
  'e4500000-0000-0000-0000-000000000007', 'rmvp04-invalidate', 3,
  'PLANNING_CORRECTION', 'Corrected approved planning evidence',
  jsonb_build_object('need_generation_run_id', response->'affected_aggregate_ids'->>'need_generation_run_id')
)
from rmvp04_responses where response_name = 'create';
set local role authenticated;
insert into rmvp04_responses
select 'invalidate', atlas_api.invalidate_need_generation_run(request)
from rmvp04_requests where request_name = 'invalidate';
reset role;
select is(
  (
    select jsonb_build_object(
      'success', response->>'success',
      'error_code', response->>'error_code',
      'version', response->'new_versions'->>'need_generation_run_version'
    )
    from rmvp04_responses where response_name = 'invalidate'
  ),
  jsonb_build_object('success', 'true', 'error_code', null, 'version', '4'),
  'RMVP04-29 released run remains safely invalidatable while Confirmed Need is DRAFT_REVIEW'
);

insert into rmvp04_requests
select 'successor', pg_temp.rmvp04_command(
  'e4500000-0000-0000-0000-000000000008', 'rmvp04-successor', 1,
  'NEED_GENERATION_CREATED', null,
  request->'payload'
)
from rmvp04_requests where request_name = 'create';
set local role authenticated;
insert into rmvp04_responses
select 'successor', atlas_api.create_need_generation_run(request)
from rmvp04_requests where request_name = 'successor';
reset role;
select ok((select response->>'success' = 'true' and response->'authoritative_readback'->'selected_run'->>'attempt_ordinal' = '2' from rmvp04_responses where response_name = 'successor'), 'RMVP04-30 correction creates the direct second attempt');
select is(
  (
    select jsonb_build_object(
      'successor_lines', count(*),
      'predecessor_lines', count(*) filter (where predecessor_theoretical_need_line_id is not null),
      'predecessor_runs', count(distinct predecessor_need_generation_run_id)
    )
    from atlas_planning.theoretical_need_lines
    where need_generation_run_id = (select (response->'affected_aggregate_ids'->>'need_generation_run_id')::uuid from rmvp04_responses where response_name = 'successor')
  ),
  jsonb_build_object('successor_lines', 2, 'predecessor_lines', 2, 'predecessor_runs', 1),
  'RMVP04-31 every successor contribution preserves direct predecessor lineage'
);
select is(
  (
    select jsonb_build_object(
      'runs', count(*),
      'attempts', array_agg(attempt_ordinal order by attempt_ordinal),
      'statuses', array_agg(run_status order by attempt_ordinal)
    )
    from atlas_planning.need_generation_runs
    where planning_input_set_id = (select (response->'affected_aggregate_ids'->>'planning_input_set_id')::uuid from rmvp04_responses where response_name = 'create')
  ),
  jsonb_build_object('runs', 2, 'attempts', array[1, 2]::bigint[], 'statuses', array['INVALIDATED', 'GENERATED']::text[]),
  'RMVP04-32 invalidation preserves first-attempt history beside the terminal successor'
);
select is(
  (
    select jsonb_build_object(
      'receipts', count(*),
      'events', (select count(*) from atlas_audit.domain_events where command_id in ('e4500000-0000-0000-0000-000000000003', 'e4500000-0000-0000-0000-000000000004', 'e4500000-0000-0000-0000-000000000005', 'e4500000-0000-0000-0000-000000000007', 'e4500000-0000-0000-0000-000000000008')),
      'audits', (select count(*) from atlas_audit.audit_events where command_id in ('e4500000-0000-0000-0000-000000000003', 'e4500000-0000-0000-0000-000000000004', 'e4500000-0000-0000-0000-000000000005', 'e4500000-0000-0000-0000-000000000007', 'e4500000-0000-0000-0000-000000000008'))
    )
    from atlas_core.command_receipts
    where command_id in ('e4500000-0000-0000-0000-000000000003', 'e4500000-0000-0000-0000-000000000004', 'e4500000-0000-0000-0000-000000000005', 'e4500000-0000-0000-0000-000000000007', 'e4500000-0000-0000-0000-000000000008')
  ),
  jsonb_build_object('receipts', 5, 'events', 5, 'audits', 5),
  'RMVP04-33 each successful RMVP-04 write has one receipt, event, and audit despite replay'
);

-- A separate real run proves the sole warning case without violating CMD-15's
-- approved rejection of active zero-quantity contributions.
insert into rmvp04_requests values (
  'warning-evaluate',
  pg_temp.rmvp04_readiness_command(
    'e4500000-0000-0000-0000-000000000009',
    'rmvp04-warning-evaluate',
    'ABSENT',
    null,
    null,
    'READINESS_EVALUATION_REQUESTED',
    jsonb_build_object(
      'period_start', '2026-11-03',
      'period_end', '2026-11-03',
      'source_candidates', jsonb_build_object(
        'weekly_menu', jsonb_build_object('weekly_menu_id', 'e4200000-0000-0000-0000-000000000001', 'weekly_menu_version', 1, 'weekly_menu_approval_snapshot_id', 'e4200000-0000-0000-0000-000000000002'),
        'attendance', jsonb_build_object('attendance_batch_id', 'e4300000-0000-0000-0000-000000000001', 'attendance_version', 1, 'attendance_approval_snapshot_id', 'e4300000-0000-0000-0000-000000000002'),
        'pantry', jsonb_build_object('pantry_need_batch_id', 'e4400000-0000-0000-0000-000000000002', 'pantry_need_batch_version', 1, 'pantry_need_approval_snapshot_id', 'e4400000-0000-0000-0000-000000000003')
      )
    )
  )
);
set local role authenticated;
insert into rmvp04_responses
select 'warning-evaluate', atlas_api.evaluate_planning_input_readiness(request)
from rmvp04_requests where request_name = 'warning-evaluate';
reset role;

insert into rmvp04_requests
select
  'warning-request',
  pg_temp.rmvp04_readiness_command(
    'e4500000-0000-0000-0000-000000000010',
    'rmvp04-warning-request',
    'READY',
    (response->'affected_aggregate_ids'->>'planning_input_evaluation_id')::uuid,
    (response->'new_versions'->>'current_evaluation_version')::bigint,
    'NEED_GENERATION_HANDOFF_REQUESTED',
    jsonb_build_object(
      'planning_input_set_id', response->'affected_aggregate_ids'->>'planning_input_set_id',
      'period_start', '2026-11-03',
      'period_end', '2026-11-03'
    )
  )
from rmvp04_responses where response_name = 'warning-evaluate';
set local role authenticated;
insert into rmvp04_responses
select 'warning-request', atlas_api.request_planning_input_need_generation(request)
from rmvp04_requests where request_name = 'warning-request';
reset role;

insert into rmvp04_requests
select
  'warning-create',
  pg_temp.rmvp04_command(
    'e4500000-0000-0000-0000-000000000011',
    'rmvp04-warning-create',
    (evaluation.response->'new_versions'->>'current_evaluation_version')::bigint,
    'NEED_GENERATION_CREATED',
    null,
    jsonb_build_object(
      'planning_input_set_id', requested.response->'affected_aggregate_ids'->>'planning_input_set_id',
      'planning_input_evaluation_id', evaluation.response->'affected_aggregate_ids'->>'planning_input_evaluation_id',
      'period_start', '2026-11-03',
      'period_end', '2026-11-03'
    )
  )
from rmvp04_responses evaluation
cross join rmvp04_responses requested
where evaluation.response_name = 'warning-evaluate'
  and requested.response_name = 'warning-request';
set local role authenticated;
insert into rmvp04_responses
select 'warning-create', atlas_api.create_need_generation_run(request)
from rmvp04_requests where request_name = 'warning-create';
reset role;

insert into rmvp04_requests
select 'warning-validate', pg_temp.rmvp04_command(
  'e4500000-0000-0000-0000-000000000012',
  'rmvp04-warning-validate',
  1,
  'NEED_GENERATION_VALIDATED',
  null,
  jsonb_build_object(
    'need_generation_run_id', response->'affected_aggregate_ids'->>'need_generation_run_id'
  )
)
from rmvp04_responses where response_name = 'warning-create';
set local role authenticated;
insert into rmvp04_responses
select 'warning-validate', atlas_api.validate_need_generation_run(request)
from rmvp04_requests where request_name = 'warning-validate';
reset role;

insert into rmvp04_requests
select 'warning-release', pg_temp.rmvp04_command(
  'e4500000-0000-0000-0000-000000000013',
  'rmvp04-warning-release',
  2,
  'NEED_GENERATION_RELEASED',
  null,
  jsonb_build_object(
    'need_generation_run_id', response->'affected_aggregate_ids'->>'need_generation_run_id'
  )
)
from rmvp04_responses where response_name = 'warning-create';
set local role authenticated;
insert into rmvp04_responses
select 'warning-release', atlas_api.release_need_generation_run(request)
from rmvp04_requests where request_name = 'warning-release';
reset role;

select is(
  (
    select jsonb_object_agg(
      response_name,
      jsonb_build_object(
        'success', response->>'success',
        'error_code', response->>'error_code'
      ) order by response_name
    )
    from rmvp04_responses
    where response_name in (
      'warning-evaluate', 'warning-request', 'warning-create',
      'warning-validate', 'warning-release'
    )
  ),
  jsonb_build_object(
    'warning-evaluate', jsonb_build_object('success', 'true', 'error_code', null),
    'warning-request', jsonb_build_object('success', 'true', 'error_code', null),
    'warning-create', jsonb_build_object('success', 'true', 'error_code', null),
    'warning-validate', jsonb_build_object('success', 'true', 'error_code', null),
    'warning-release', jsonb_build_object('success', 'true', 'error_code', null)
  ),
  'RMVP04-34 the warning-bearing run completes readiness, generation, validation, and release'
);
select is(
  (
    select jsonb_build_object(
      'run_blockers', blocking_issue_count,
      'persisted_blockers', (select count(*) from atlas_planning.need_generation_issues issue where issue.need_generation_run_id = run.need_generation_run_id and issue.severity = 'BLOCKING'),
      'run_warnings', warning_count,
      'persisted_warnings', (select count(*) from atlas_planning.need_generation_issues issue where issue.need_generation_run_id = run.need_generation_run_id and issue.severity = 'WARNING')
    )
    from atlas_planning.need_generation_runs run
    where run.need_generation_run_id = (select (response->'affected_aggregate_ids'->>'need_generation_run_id')::uuid from rmvp04_responses where response_name = 'warning-create')
  ),
  jsonb_build_object('run_blockers', 0, 'persisted_blockers', 0, 'run_warnings', 1, 'persisted_warnings', 1),
  'RMVP04-35 warning-run counts are every-and-only persisted issue evidence'
);

set local role authenticated;
insert into rmvp04_responses
select
  'warning-read',
  atlas_api.get_need_generation_workbench(
    pg_temp.rmvp04_read(
      p_run_id => (response->'affected_aggregate_ids'->>'need_generation_run_id')::uuid,
      p_period_start => '2026-11-03',
      p_period_end => '2026-11-03'
    )
  )
from rmvp04_responses where response_name = 'warning-create';
reset role;
select is(
  (
    select jsonb_build_object(
      'blockers', jsonb_array_length(response->'workbench'->'blocking_issues'),
      'warnings', jsonb_array_length(response->'workbench'->'warnings'),
      'warning_code', response->'workbench'->'warnings'->0->>'issue_code',
      'can_materialize', response->'workbench'->'allowed_actions'->'materialize',
      'materialize_reason', response->'workbench'->'disabled_reasons'->>'materialize'
    )
    from rmvp04_responses where response_name = 'warning-read'
  ),
  jsonb_build_object(
    'blockers', 0,
    'warnings', 1,
    'warning_code', 'ZERO_ACTIVE_THEORETICAL_QUANTITY',
    'can_materialize', false,
    'materialize_reason', 'CMD-15 requires corrected source evidence before materializing an active zero-quantity contribution.'
  ),
  'RMVP04-36 workbench returns the complete warning and the CMD-15 correction boundary'
);

-- Two isolated runs prove that the chosen Recipe tier must contain exactly
-- one candidate. Each period also retains one valid Recipe contribution and
-- one Pantry contribution while the ambiguous Menu line produces no lineage.
insert into rmvp04_requests values (
  'typed-ambiguity-evaluate',
  pg_temp.rmvp04_readiness_command(
    'e4800000-0000-0000-0000-000000000001',
    'rmvp04-typed-ambiguity-evaluate',
    'ABSENT',
    null,
    null,
    'READINESS_EVALUATION_REQUESTED',
    jsonb_build_object(
      'period_start', '2026-11-04',
      'period_end', '2026-11-04',
      'source_candidates', jsonb_build_object(
        'weekly_menu', jsonb_build_object('weekly_menu_id', 'e4200000-0000-0000-0000-000000000001', 'weekly_menu_version', 1, 'weekly_menu_approval_snapshot_id', 'e4200000-0000-0000-0000-000000000002'),
        'attendance', jsonb_build_object('attendance_batch_id', 'e4300000-0000-0000-0000-000000000001', 'attendance_version', 1, 'attendance_approval_snapshot_id', 'e4300000-0000-0000-0000-000000000002'),
        'pantry', jsonb_build_object('pantry_need_batch_id', 'e4400000-0000-0000-0000-000000000002', 'pantry_need_batch_version', 1, 'pantry_need_approval_snapshot_id', 'e4400000-0000-0000-0000-000000000003')
      )
    )
  )
);
set local role authenticated;
insert into rmvp04_responses
select 'typed-ambiguity-evaluate', atlas_api.evaluate_planning_input_readiness(request)
from rmvp04_requests where request_name = 'typed-ambiguity-evaluate';
reset role;

insert into rmvp04_requests
select
  'typed-ambiguity-request',
  pg_temp.rmvp04_readiness_command(
    'e4800000-0000-0000-0000-000000000002',
    'rmvp04-typed-ambiguity-request',
    'READY',
    (response->'affected_aggregate_ids'->>'planning_input_evaluation_id')::uuid,
    (response->'new_versions'->>'current_evaluation_version')::bigint,
    'NEED_GENERATION_HANDOFF_REQUESTED',
    jsonb_build_object(
      'planning_input_set_id', response->'affected_aggregate_ids'->>'planning_input_set_id',
      'period_start', '2026-11-04',
      'period_end', '2026-11-04'
    )
  )
from rmvp04_responses where response_name = 'typed-ambiguity-evaluate';
set local role authenticated;
insert into rmvp04_responses
select 'typed-ambiguity-request', atlas_api.request_planning_input_need_generation(request)
from rmvp04_requests where request_name = 'typed-ambiguity-request';
reset role;

insert into rmvp04_requests
select
  'typed-ambiguity-create',
  pg_temp.rmvp04_command(
    'e4800000-0000-0000-0000-000000000003',
    'rmvp04-typed-ambiguity-create',
    (evaluation.response->'new_versions'->>'current_evaluation_version')::bigint,
    'NEED_GENERATION_CREATED',
    null,
    jsonb_build_object(
      'planning_input_set_id', requested.response->'affected_aggregate_ids'->>'planning_input_set_id',
      'planning_input_evaluation_id', evaluation.response->'affected_aggregate_ids'->>'planning_input_evaluation_id',
      'period_start', '2026-11-04',
      'period_end', '2026-11-04'
    )
  )
from rmvp04_responses evaluation
cross join rmvp04_responses requested
where evaluation.response_name = 'typed-ambiguity-evaluate'
  and requested.response_name = 'typed-ambiguity-request';
set local role authenticated;
insert into rmvp04_responses
select 'typed-ambiguity-create', atlas_api.create_need_generation_run(request)
from rmvp04_requests where request_name = 'typed-ambiguity-create';
reset role;

select ok(
  (
    select response->>'success' = 'true'
      and response->'authoritative_readback'->'selected_run'->>'status' = 'GENERATED'
      and response->'authoritative_readback'->'selected_run'->>'blocking_issue_count' = '1'
    from rmvp04_responses where response_name = 'typed-ambiguity-create'
  ),
  'RMVP04-37 typed-tier ambiguity still creates one GENERATED run'
);
select is(
  (
    select jsonb_build_object(
      'run_blockers', run.blocking_issue_count,
      'issues', (
        select jsonb_agg(
          jsonb_build_object(
            'severity', issue.severity,
            'code', issue.issue_code,
            'menu_snapshot_line_id', issue.weekly_menu_approval_snapshot_line_id,
            'school_id', issue.school_id,
            'service_date', issue.service_date,
            'dish_id', issue.dish_id
          ) order by issue.need_generation_issue_id
        )
        from atlas_planning.need_generation_issues issue
        where issue.need_generation_run_id = run.need_generation_run_id
      )
    )
    from atlas_planning.need_generation_runs run
    where run.need_generation_run_id = (
      select (response->'affected_aggregate_ids'->>'need_generation_run_id')::uuid
      from rmvp04_responses where response_name = 'typed-ambiguity-create'
    )
  ),
  jsonb_build_object(
    'run_blockers', 1,
    'issues', jsonb_build_array(jsonb_build_object(
      'severity', 'BLOCKING',
      'code', 'AMBIGUOUS_ELIGIBLE_RECIPE',
      'menu_snapshot_line_id', 'e4600000-0000-0000-0000-000000000022',
      'school_id', 'e4100000-0000-0000-0000-000000000005',
      'service_date', '2026-11-04',
      'dish_id', 'e4600000-0000-0000-0000-000000000001'
    ))
  ),
  'RMVP04-38 typed-tier ambiguity persists exactly one fully typed blocker'
);
select is(
  (
    select jsonb_build_object(
      'ambiguous_selections', (
        select count(*) from atlas_planning.need_generation_recipe_selections selection
        where selection.need_generation_run_id = run.need_generation_run_id
          and selection.weekly_menu_approval_snapshot_line_id = 'e4600000-0000-0000-0000-000000000022'
      ),
      'ambiguous_uses', (
        select count(*)
        from atlas_planning.need_generation_recipe_line_uses line_use
        join atlas_planning.need_generation_recipe_selections selection
          using (need_generation_recipe_selection_id)
        where line_use.need_generation_run_id = run.need_generation_run_id
          and selection.weekly_menu_approval_snapshot_line_id = 'e4600000-0000-0000-0000-000000000022'
      ),
      'ambiguous_lines', (
        select count(*) from atlas_planning.theoretical_need_lines line
        where line.need_generation_run_id = run.need_generation_run_id
          and line.weekly_menu_approval_snapshot_line_id = 'e4600000-0000-0000-0000-000000000022'
      ),
      'valid_selections', (
        select count(*) from atlas_planning.need_generation_recipe_selections selection
        where selection.need_generation_run_id = run.need_generation_run_id
          and selection.weekly_menu_approval_snapshot_line_id = 'e4600000-0000-0000-0000-000000000023'
      ),
      'recipe_lines', (
        select count(*) from atlas_planning.theoretical_need_lines line
        where line.need_generation_run_id = run.need_generation_run_id
          and line.contribution_family = 'RECIPE_DERIVED'
      ),
      'pantry_lines', (
        select count(*) from atlas_planning.theoretical_need_lines line
        where line.need_generation_run_id = run.need_generation_run_id
          and line.contribution_family = 'PANTRY_DIRECT'
      )
    )
    from atlas_planning.need_generation_runs run
    where run.need_generation_run_id = (
      select (response->'affected_aggregate_ids'->>'need_generation_run_id')::uuid
      from rmvp04_responses where response_name = 'typed-ambiguity-create'
    )
  ),
  jsonb_build_object(
    'ambiguous_selections', 0,
    'ambiguous_uses', 0,
    'ambiguous_lines', 0,
    'valid_selections', 1,
    'recipe_lines', 1,
    'pantry_lines', 1
  ),
  'RMVP04-39 typed-tier ambiguity emits no Recipe lineage while valid Recipe and Pantry lines generate'
);

insert into rmvp04_requests
select 'typed-ambiguity-validate', pg_temp.rmvp04_command(
  'e4800000-0000-0000-0000-000000000004',
  'rmvp04-typed-ambiguity-validate',
  1,
  'NEED_GENERATION_VALIDATED',
  null,
  jsonb_build_object(
    'need_generation_run_id', response->'affected_aggregate_ids'->>'need_generation_run_id'
  )
)
from rmvp04_responses where response_name = 'typed-ambiguity-create';
set local role authenticated;
insert into rmvp04_responses
select 'typed-ambiguity-validate', atlas_api.validate_need_generation_run(request)
from rmvp04_requests where request_name = 'typed-ambiguity-validate';
reset role;
select is(
  (select response->>'error_code' from rmvp04_responses where response_name = 'typed-ambiguity-validate'),
  'NEED_GENERATION_HAS_BLOCKERS',
  'RMVP04-40 typed-tier ambiguous run cannot validate'
);

insert into rmvp04_requests values (
  'general-ambiguity-evaluate',
  pg_temp.rmvp04_readiness_command(
    'e4800000-0000-0000-0000-000000000011',
    'rmvp04-general-ambiguity-evaluate',
    'ABSENT',
    null,
    null,
    'READINESS_EVALUATION_REQUESTED',
    jsonb_build_object(
      'period_start', '2026-11-05',
      'period_end', '2026-11-05',
      'source_candidates', jsonb_build_object(
        'weekly_menu', jsonb_build_object('weekly_menu_id', 'e4200000-0000-0000-0000-000000000001', 'weekly_menu_version', 1, 'weekly_menu_approval_snapshot_id', 'e4200000-0000-0000-0000-000000000002'),
        'attendance', jsonb_build_object('attendance_batch_id', 'e4300000-0000-0000-0000-000000000001', 'attendance_version', 1, 'attendance_approval_snapshot_id', 'e4300000-0000-0000-0000-000000000002'),
        'pantry', jsonb_build_object('pantry_need_batch_id', 'e4400000-0000-0000-0000-000000000002', 'pantry_need_batch_version', 1, 'pantry_need_approval_snapshot_id', 'e4400000-0000-0000-0000-000000000003')
      )
    )
  )
);
set local role authenticated;
insert into rmvp04_responses
select 'general-ambiguity-evaluate', atlas_api.evaluate_planning_input_readiness(request)
from rmvp04_requests where request_name = 'general-ambiguity-evaluate';
reset role;

insert into rmvp04_requests
select
  'general-ambiguity-request',
  pg_temp.rmvp04_readiness_command(
    'e4800000-0000-0000-0000-000000000012',
    'rmvp04-general-ambiguity-request',
    'READY',
    (response->'affected_aggregate_ids'->>'planning_input_evaluation_id')::uuid,
    (response->'new_versions'->>'current_evaluation_version')::bigint,
    'NEED_GENERATION_HANDOFF_REQUESTED',
    jsonb_build_object(
      'planning_input_set_id', response->'affected_aggregate_ids'->>'planning_input_set_id',
      'period_start', '2026-11-05',
      'period_end', '2026-11-05'
    )
  )
from rmvp04_responses where response_name = 'general-ambiguity-evaluate';
set local role authenticated;
insert into rmvp04_responses
select 'general-ambiguity-request', atlas_api.request_planning_input_need_generation(request)
from rmvp04_requests where request_name = 'general-ambiguity-request';
reset role;

insert into rmvp04_requests
select
  'general-ambiguity-create',
  pg_temp.rmvp04_command(
    'e4800000-0000-0000-0000-000000000013',
    'rmvp04-general-ambiguity-create',
    (evaluation.response->'new_versions'->>'current_evaluation_version')::bigint,
    'NEED_GENERATION_CREATED',
    null,
    jsonb_build_object(
      'planning_input_set_id', requested.response->'affected_aggregate_ids'->>'planning_input_set_id',
      'planning_input_evaluation_id', evaluation.response->'affected_aggregate_ids'->>'planning_input_evaluation_id',
      'period_start', '2026-11-05',
      'period_end', '2026-11-05'
    )
  )
from rmvp04_responses evaluation
cross join rmvp04_responses requested
where evaluation.response_name = 'general-ambiguity-evaluate'
  and requested.response_name = 'general-ambiguity-request';
set local role authenticated;
insert into rmvp04_responses
select 'general-ambiguity-create', atlas_api.create_need_generation_run(request)
from rmvp04_requests where request_name = 'general-ambiguity-create';
reset role;

select ok(
  (
    select response->>'success' = 'true'
      and response->'authoritative_readback'->'selected_run'->>'status' = 'GENERATED'
      and response->'authoritative_readback'->'selected_run'->>'blocking_issue_count' = '1'
    from rmvp04_responses where response_name = 'general-ambiguity-create'
  ),
  'RMVP04-41 general-tier ambiguity still creates one GENERATED run'
);
select is(
  (
    select jsonb_build_object(
      'run_blockers', run.blocking_issue_count,
      'issues', (
        select jsonb_agg(
          jsonb_build_object(
            'severity', issue.severity,
            'code', issue.issue_code,
            'menu_snapshot_line_id', issue.weekly_menu_approval_snapshot_line_id,
            'school_id', issue.school_id,
            'service_date', issue.service_date,
            'dish_id', issue.dish_id
          ) order by issue.need_generation_issue_id
        )
        from atlas_planning.need_generation_issues issue
        where issue.need_generation_run_id = run.need_generation_run_id
      )
    )
    from atlas_planning.need_generation_runs run
    where run.need_generation_run_id = (
      select (response->'affected_aggregate_ids'->>'need_generation_run_id')::uuid
      from rmvp04_responses where response_name = 'general-ambiguity-create'
    )
  ),
  jsonb_build_object(
    'run_blockers', 1,
    'issues', jsonb_build_array(jsonb_build_object(
      'severity', 'BLOCKING',
      'code', 'AMBIGUOUS_ELIGIBLE_RECIPE',
      'menu_snapshot_line_id', 'e4700000-0000-0000-0000-000000000022',
      'school_id', 'e4100000-0000-0000-0000-000000000005',
      'service_date', '2026-11-05',
      'dish_id', 'e4700000-0000-0000-0000-000000000001'
    ))
  ),
  'RMVP04-42 general-tier ambiguity persists exactly one fully typed blocker'
);
select is(
  (
    select jsonb_build_object(
      'ambiguous_selections', (
        select count(*) from atlas_planning.need_generation_recipe_selections selection
        where selection.need_generation_run_id = run.need_generation_run_id
          and selection.weekly_menu_approval_snapshot_line_id = 'e4700000-0000-0000-0000-000000000022'
      ),
      'ambiguous_uses', (
        select count(*)
        from atlas_planning.need_generation_recipe_line_uses line_use
        join atlas_planning.need_generation_recipe_selections selection
          using (need_generation_recipe_selection_id)
        where line_use.need_generation_run_id = run.need_generation_run_id
          and selection.weekly_menu_approval_snapshot_line_id = 'e4700000-0000-0000-0000-000000000022'
      ),
      'ambiguous_lines', (
        select count(*) from atlas_planning.theoretical_need_lines line
        where line.need_generation_run_id = run.need_generation_run_id
          and line.weekly_menu_approval_snapshot_line_id = 'e4700000-0000-0000-0000-000000000022'
      ),
      'valid_selections', (
        select count(*) from atlas_planning.need_generation_recipe_selections selection
        where selection.need_generation_run_id = run.need_generation_run_id
          and selection.weekly_menu_approval_snapshot_line_id = 'e4700000-0000-0000-0000-000000000023'
      ),
      'recipe_lines', (
        select count(*) from atlas_planning.theoretical_need_lines line
        where line.need_generation_run_id = run.need_generation_run_id
          and line.contribution_family = 'RECIPE_DERIVED'
      ),
      'pantry_lines', (
        select count(*) from atlas_planning.theoretical_need_lines line
        where line.need_generation_run_id = run.need_generation_run_id
          and line.contribution_family = 'PANTRY_DIRECT'
      )
    )
    from atlas_planning.need_generation_runs run
    where run.need_generation_run_id = (
      select (response->'affected_aggregate_ids'->>'need_generation_run_id')::uuid
      from rmvp04_responses where response_name = 'general-ambiguity-create'
    )
  ),
  jsonb_build_object(
    'ambiguous_selections', 0,
    'ambiguous_uses', 0,
    'ambiguous_lines', 0,
    'valid_selections', 1,
    'recipe_lines', 1,
    'pantry_lines', 1
  ),
  'RMVP04-43 general-tier ambiguity emits no Recipe lineage while valid Recipe and Pantry lines generate'
);

insert into rmvp04_requests
select 'general-ambiguity-validate', pg_temp.rmvp04_command(
  'e4800000-0000-0000-0000-000000000014',
  'rmvp04-general-ambiguity-validate',
  1,
  'NEED_GENERATION_VALIDATED',
  null,
  jsonb_build_object(
    'need_generation_run_id', response->'affected_aggregate_ids'->>'need_generation_run_id'
  )
)
from rmvp04_responses where response_name = 'general-ambiguity-create';
set local role authenticated;
insert into rmvp04_responses
select 'general-ambiguity-validate', atlas_api.validate_need_generation_run(request)
from rmvp04_requests where request_name = 'general-ambiguity-validate';
reset role;
select is(
  (select response->>'error_code' from rmvp04_responses where response_name = 'general-ambiguity-validate'),
  'NEED_GENERATION_HAS_BLOCKERS',
  'RMVP04-44 general-tier ambiguous run cannot validate'
);

create temporary table rmvp04_access_results (
  role_name text primary key,
  call_denied boolean not null
);
grant insert, select on rmvp04_access_results to anon, service_role;

set local role anon;
do $$
begin
  begin
    perform atlas_api.get_need_generation_workbench(pg_temp.rmvp04_read());
    insert into rmvp04_access_results values ('anon', false);
  exception when insufficient_privilege then
    insert into rmvp04_access_results values ('anon', true);
  end;
end;
$$;
reset role;

set local role service_role;
do $$
begin
  begin
    perform atlas_api.get_need_generation_workbench(pg_temp.rmvp04_read());
    insert into rmvp04_access_results values ('service_role', false);
  exception when insufficient_privilege then
    insert into rmvp04_access_results values ('service_role', true);
  end;
end;
$$;
reset role;

select ok((select call_denied from rmvp04_access_results where role_name = 'anon'), 'RMVP04-45 an anonymous API call is rejected by PostgreSQL');
select ok((select call_denied from rmvp04_access_results where role_name = 'service_role'), 'RMVP04-46 a service-role API call is rejected by PostgreSQL');
select ok(
  lower(pg_get_functiondef(
    'atlas_core.rmvp_03b_finish_success(jsonb,uuid,uuid,text,uuid,uuid,bigint,jsonb,jsonb,text,jsonb)'::regprocedure
  )) like '%set constraints all immediate;%'
  and lower(pg_get_functiondef(
    'atlas_core.rmvp_03b_finish_success(jsonb,uuid,uuid,text,uuid,uuid,bigint,jsonb,jsonb,text,jsonb)'::regprocedure
  )) like '%set constraints all deferred;%',
  'RMVP04-47 readiness commands flush deferred H0A4B integrity inside the bounded runtime'
);
select ok(
  (
    select wrapper_definition like '%set constraints atlas_planning.confirmed_need_batches_current_source_consistency, atlas_planning.confirmed_need_lines_current_source_consistency, atlas_planning.confirmed_need_line_revisions_current_source_consistency, atlas_planning.confirmed_need_line_revisions_membership_total, atlas_planning.confirmed_need_line_revision_contributions_membership_total, atlas_planning.confirmed_need_lines_h1b1_decision_integrity, atlas_planning.confirmed_need_line_revisions_h1b1_decision_integrity, atlas_planning.confirmed_need_batches_validation_integrity immediate;%'
      and wrapper_definition like '%set constraints atlas_planning.confirmed_need_batches_current_source_consistency, atlas_planning.confirmed_need_lines_current_source_consistency, atlas_planning.confirmed_need_line_revisions_current_source_consistency, atlas_planning.confirmed_need_line_revisions_membership_total, atlas_planning.confirmed_need_line_revision_contributions_membership_total, atlas_planning.confirmed_need_lines_h1b1_decision_integrity, atlas_planning.confirmed_need_line_revisions_h1b1_decision_integrity, atlas_planning.confirmed_need_batches_validation_integrity deferred;%'
      and wrapper_definition not like '%set constraints all immediate;%'
      and wrapper_definition not like '%set constraints all deferred;%'
      and wrapper_definition not like '%confirmed_need_batches_rmvp07_integrity%'
      and wrapper_definition not like '%confirmed_need_approval_snapshots_rmvp07_integrity%'
      and wrapper_definition not like '%confirmed_need_snapshot_lines_rmvp07_integrity%'
      and wrapper_definition not like '%confirmed_need_releases_rmvp07_integrity%'
      and regexp_count(wrapper_definition, 'set constraints') = 2
    from (
      select regexp_replace(
        lower(pg_get_functiondef(
          'atlas_api.create_confirmed_needs_from_generation(jsonb)'::regprocedure
        )),
        '[[:space:]]+',
        ' ',
        'g'
      ) as wrapper_definition
    ) wrapper
  ),
  'RMVP04-48 CMD-15 flushes exactly eight queued H0B1/H1B1/RMVP-06 constraints and excludes RMVP-07 inside its bounded runtime'
);

select * from finish();
rollback;
