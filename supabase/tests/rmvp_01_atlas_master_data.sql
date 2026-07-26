begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
select no_plan();

grant usage on schema extensions to authenticated;
grant execute on all functions in schema extensions to authenticated;

select ok(
  exists (
    select 1
    from pg_roles
    where rolname = 'atlas_master_data_command_runtime'
      and not rolcanlogin
      and not rolinherit
      and not rolsuper
      and not rolcreaterole
      and not rolcreatedb
      and not rolreplication
      and not rolbypassrls
  ),
  'RMVP-01 command runtime is NOLOGIN NOINHERIT and non-privileged'
);

select is(
  (
    select array_agg(p.proname order by p.proname)::text[]
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    join pg_roles r on r.oid = p.proowner
    where n.nspname = 'atlas_api'
      and r.rolname = 'atlas_master_data_command_runtime'
      and p.proname in (
        'create_ingredient',
        'create_supplier',
        'replace_ingredient_supplier_priorities',
        'set_ingredient_lifecycle',
        'update_ingredient',
        'update_school_portion_defaults',
        'update_supplier'
      )
  ),
  array[
    'create_ingredient',
    'create_supplier',
    'replace_ingredient_supplier_priorities',
    'set_ingredient_lifecycle',
    'update_ingredient',
    'update_school_portion_defaults',
    'update_supplier'
  ]::text[],
  'runtime still owns all seven RMVP-01 master-data writes'
);

select ok(
  not has_schema_privilege('atlas_read_runtime', 'atlas_legacy', 'USAGE')
  and not has_function_privilege(
    'atlas_master_data_command_runtime',
    'atlas_legacy.import_master_data_snapshot(jsonb)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'atlas_legacy.import_master_data_snapshot(jsonb)',
    'EXECUTE'
  ),
  'the RMVP-01 operator import remains outside authenticated, read, and command runtimes'
);

select ok(
  not exists (
    select 1
    from unnest(
      array[
        'anon',
        'authenticated',
        'service_role',
        'atlas_read_runtime'
      ]
    ) role_name
    where has_table_privilege(
      role_name,
      'atlas_legacy.import_batches',
      'SELECT,INSERT,UPDATE,DELETE'
    )
      or has_table_privilege(
        role_name,
        'atlas_legacy.master_data_mappings',
        'SELECT,INSERT,UPDATE,DELETE'
      )
  )
  and has_table_privilege(
    'atlas_master_data_command_runtime',
    'atlas_legacy.import_batches',
    'SELECT,INSERT,UPDATE'
  )
  and not has_table_privilege(
    'atlas_master_data_command_runtime',
    'atlas_legacy.import_batches',
    'DELETE'
  )
  and has_table_privilege(
    'atlas_master_data_command_runtime',
    'atlas_legacy.master_data_mappings',
    'SELECT,INSERT,UPDATE'
  )
  and not has_table_privilege(
    'atlas_master_data_command_runtime',
    'atlas_legacy.master_data_mappings',
    'DELETE'
  ),
  'legacy evidence is private from API roles and the command runtime has only bounded recipe-import access'
);

select ok(
  not exists (
    select 1
    from unnest(array['anon', 'authenticated', 'service_role']) role_name
    cross join unnest(
      array[
        'atlas_core',
        'atlas_admin',
        'atlas_legacy',
        'atlas_audit',
        'atlas_reporting'
      ]
    ) schema_name
    where has_schema_privilege(role_name, schema_name, 'USAGE')
  ),
  'API roles retain no private Atlas schema usage'
);

select ok(
  (
    select bool_and(
      p.prosecdef
      and p.proconfig::text like '%search_path=%'
      and has_function_privilege('authenticated', p.oid, 'EXECUTE')
      and not has_function_privilege('anon', p.oid, 'EXECUTE')
      and not has_function_privilege('service_role', p.oid, 'EXECUTE')
    )
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
      and p.proname in (
        'get_school_master_data',
        'get_ingredient_supplier_master_data',
        'update_school_portion_defaults',
        'create_ingredient',
        'update_ingredient',
        'set_ingredient_lifecycle',
        'create_supplier',
        'update_supplier',
        'replace_ingredient_supplier_priorities'
      )
  ),
  'all nine RMVP-01 API functions are empty-search-path definers with exact API grants'
);

select is(
  (
    select array_agg(p.proname order by p.proname)::text[]
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
      and has_function_privilege(
        'atlas_master_data_command_runtime',
        p.oid,
        'EXECUTE'
      )
      and p.proname in (
        'create_ingredient',
        'create_supplier',
        'replace_ingredient_supplier_priorities',
        'set_ingredient_lifecycle',
        'update_ingredient',
        'update_school_portion_defaults',
        'update_supplier'
      )
  ),
  array[
    'create_ingredient',
    'create_supplier',
    'replace_ingredient_supplier_priorities',
    'set_ingredient_lifecycle',
    'update_ingredient',
    'update_school_portion_defaults',
    'update_supplier'
  ]::text[],
  'runtime can still execute all seven reviewed RMVP-01 API commands'
);

select ok(
  not exists (
    select 1
    from unnest(
      array[
        'atlas_admin',
        'atlas_api',
        'atlas_audit',
        'atlas_core',
        'atlas_dispatch',
        'atlas_evidence',
        'atlas_legacy',
        'atlas_planning',
        'atlas_procurement',
        'atlas_reporting'
      ]
    ) schema_name
    where has_schema_privilege(
      'atlas_master_data_command_runtime',
      schema_name,
      'CREATE'
    )
  )
  and not exists (
    select 1
    from pg_auth_members membership
    where membership.member = (
      select oid
      from pg_roles
      where rolname = 'atlas_master_data_command_runtime'
    )
  ),
  'runtime has no Atlas schema CREATE privilege and inherits no role membership'
);

select ok(
  not exists (
    select 1
    from pg_class relation
    join pg_namespace namespace on namespace.oid = relation.relnamespace
    where namespace.nspname in (
      'atlas_dispatch',
      'atlas_evidence',
      'atlas_planning',
      'atlas_procurement',
      'atlas_reporting'
    )
      and relation.relkind in ('r', 'p', 'v', 'm', 'f')
      and has_table_privilege(
        'atlas_master_data_command_runtime',
        relation.oid,
        'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER'
      )
  ),
  'runtime has no Planning, Procurement, Evidence, Dispatch, or Reporting relation privilege'
);

select ok(
  not exists (
    with atlas_sequences as materialized (
      select sequence_object.oid
      from pg_class sequence_object
      join pg_namespace namespace on namespace.oid = sequence_object.relnamespace
      where namespace.nspname like 'atlas\_%' escape '\'
        and sequence_object.relkind = 'S'
    )
    select 1
    from atlas_sequences sequence_object
    where has_sequence_privilege(
        'atlas_master_data_command_runtime',
        sequence_object.oid,
        'USAGE,SELECT,UPDATE'
      )
  ),
  'runtime has no Atlas sequence privilege'
);

select is(
  (
    select string_agg(
      table_name || '|' || privilege_type || '|' || columns,
      E'\n'
      order by table_name, privilege_type
    )
    from (
      select
        table_name,
        privilege_type,
        string_agg(column_name, ',' order by column_name) columns
      from information_schema.column_privileges
      where grantee = 'atlas_master_data_command_runtime'
        and table_schema = 'atlas_admin'
        and privilege_type in ('INSERT', 'UPDATE')
        and table_name in (
          'ingredients',
          'schools',
          'supplier_eligibilities',
          'suppliers'
        )
      group by table_name, privilege_type
    ) writable_columns
  ),
  E'ingredients|INSERT|ingredient_code,ingredient_group,ingredient_name,ingredient_type,order_step,purchase_unit_id,shopping_type\n'
    || E'ingredients|UPDATE|ingredient_group,ingredient_name,ingredient_status,ingredient_type,order_step,purchase_unit_id,shopping_type,updated_at,version\n'
    || E'schools|UPDATE|default_student_portions,default_teacher_portions,updated_at,version\n'
    || E'supplier_eligibilities|INSERT|effective_from,eligibility_status,ingredient_id,priority,reason_note,supplier_id\n'
    || E'supplier_eligibilities|UPDATE|effective_to,eligibility_status,priority,reason_note,updated_at,version\n'
    || E'suppliers|INSERT|contact_email,contact_name,contact_phone,supplier_code,supplier_name\n'
    || 'suppliers|UPDATE|contact_email,contact_name,contact_phone,supplier_name,updated_at,version',
  'runtime write grants are column-scoped to the reviewed master-data mutations'
);

insert into atlas_core.actors (
  actor_id, actor_type, display_name
) values
  (
    'd1000000-0000-0000-0000-000000000001',
    'HUMAN',
    'RMVP-01 authorized operator'
  ),
  (
    'd1000000-0000-0000-0000-000000000002',
    'HUMAN',
    'RMVP-01 denied operator'
  );

insert into atlas_core.actor_auth_subjects (
  actor_auth_subject_id, actor_id, auth_subject_id
) values
  (
    'd1000000-0000-0000-0000-000000000011',
    'd1000000-0000-0000-0000-000000000001',
    'd1000000-0000-0000-0000-000000000101'
  ),
  (
    'd1000000-0000-0000-0000-000000000012',
    'd1000000-0000-0000-0000-000000000002',
    'd1000000-0000-0000-0000-000000000102'
  );

insert into atlas_core.roles (
  role_id, role_code, role_name
) values
  (
    'd1000000-0000-0000-0000-000000000020',
    'rmvp01.master_data_operator',
    'RMVP-01 master data operator'
  ),
  (
    'd1000000-0000-0000-0000-000000000021',
    'rmvp01.no_capability',
    'RMVP-01 no capability'
  );

insert into atlas_core.role_capabilities (role_id, capability_id)
select
  'd1000000-0000-0000-0000-000000000020',
  capability_id
from atlas_core.capabilities
where capability_code like 'master_data.%';

insert into atlas_core.actor_role_memberships (actor_id, role_id) values
  (
    'd1000000-0000-0000-0000-000000000001',
    'd1000000-0000-0000-0000-000000000020'
  ),
  (
    'd1000000-0000-0000-0000-000000000002',
    'd1000000-0000-0000-0000-000000000021'
  );

insert into atlas_core.actor_scopes (actor_id, scope_kind) values
  ('d1000000-0000-0000-0000-000000000001', 'GLOBAL'),
  ('d1000000-0000-0000-0000-000000000002', 'GLOBAL');

insert into atlas_admin.customers (
  customer_id, customer_code, customer_name, customer_type
) values (
  'd2000000-0000-0000-0000-000000000001',
  'rmvp01-school-customer',
  'RMVP-01 School Customer',
  'SCHOOL_CATERING'
);
insert into atlas_admin.delivery_locations (
  delivery_location_id, customer_id, location_code, location_name,
  address_text, delivery_instructions
) values (
  'd2000000-0000-0000-0000-000000000002',
  'd2000000-0000-0000-0000-000000000001',
  'rmvp01-main-gate',
  'RMVP-01 Main Gate',
  'RMVP-01 address',
  'Before 05:30'
);
insert into atlas_admin.school_types (
  school_type_id, school_type_code, school_type_name
) values (
  'd2000000-0000-0000-0000-000000000003',
  'rmvp01-primary',
  'Primary'
);
insert into atlas_admin.schools (
  school_id, customer_id, school_code, school_name, school_type_id,
  default_delivery_location_id, display_order, operational_notes,
  default_student_portions, default_teacher_portions
) values (
  'd2000000-0000-0000-0000-000000000004',
  'd2000000-0000-0000-0000-000000000001',
  'rmvp01-school',
  'RMVP-01 School',
  'd2000000-0000-0000-0000-000000000003',
  'd2000000-0000-0000-0000-000000000002',
  1,
  'Supported contract context',
  100,
  10
);
insert into atlas_admin.units (
  unit_id, unit_code, unit_name, dimension_code, decimal_scale
) values (
  'd2000000-0000-0000-0000-000000000010',
  'rmvp01-kg',
  'RMVP-01 kilogram',
  'MASS',
  3
);
insert into atlas_admin.ingredients (
  ingredient_id, ingredient_code, ingredient_name, ingredient_group,
  purchase_unit_id, ingredient_type, shopping_type, order_step
) values (
  'd2000000-0000-0000-0000-000000000011',
  'rmvp01-rice',
  'RMVP-01 rice',
  'Food',
  'd2000000-0000-0000-0000-000000000010',
  'Food',
  'Planned',
  5
);
insert into atlas_admin.suppliers (
  supplier_id, supplier_code, supplier_name
) values
  (
    'd2000000-0000-0000-0000-000000000020',
    'rmvp01-supplier-a',
    'RMVP-01 Supplier A'
  ),
  (
    'd2000000-0000-0000-0000-000000000021',
    'rmvp01-supplier-b',
    'RMVP-01 Supplier B'
  );

create or replace function pg_temp.rmvp01_request(
  p_command_id uuid,
  p_idempotency_key text,
  p_expected_version bigint,
  p_subject uuid,
  p_payload jsonb
)
returns jsonb
language sql
as $$
  select jsonb_build_object(
    'contract_version', 'RMVP-01.v1',
    'command_id', p_command_id,
    'correlation_id', 'd9000000-0000-0000-0000-000000000001',
    'idempotency_key', p_idempotency_key,
    'expected_version', p_expected_version,
    'requested_by_auth_subject', p_subject,
    'requested_at', transaction_timestamp() - interval '1 second',
    'reason_code', 'RMVP01_TEST',
    'reason_note', 'Rolled-back RMVP-01 test',
    'payload', p_payload
  );
$$;

create temporary table rmvp01_results (
  result_name text primary key,
  response_payload jsonb not null
);
grant select, insert on rmvp01_results to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'd1000000-0000-0000-0000-000000000101',
  true
);
insert into rmvp01_results values (
  'school_read_before',
  atlas_api.get_school_master_data(
    jsonb_build_object(
      'contract_version', 'RMVP-01.v1',
      'requested_by_auth_subject', 'd1000000-0000-0000-0000-000000000101',
      'correlation_id', 'd9000000-0000-0000-0000-000000000001',
      'payload', '{}'::jsonb
    )
  )
);
insert into rmvp01_results values (
  'school_update',
  atlas_api.update_school_portion_defaults(
    pg_temp.rmvp01_request(
      'd9000000-0000-0000-0000-000000000101',
      'rmvp01-school-update',
      1,
      'd1000000-0000-0000-0000-000000000101',
      jsonb_build_object(
        'school_id', 'd2000000-0000-0000-0000-000000000004',
        'default_student_portions', 120,
        'default_teacher_portions', 12
      )
    )
  )
);
insert into rmvp01_results values (
  'school_update_replay',
  atlas_api.update_school_portion_defaults(
    pg_temp.rmvp01_request(
      'd9000000-0000-0000-0000-000000000101',
      'rmvp01-school-update',
      1,
      'd1000000-0000-0000-0000-000000000101',
      jsonb_build_object(
        'school_id', 'd2000000-0000-0000-0000-000000000004',
        'default_student_portions', 120,
        'default_teacher_portions', 12
      )
    )
  )
);
insert into rmvp01_results values (
  'school_update_stale',
  atlas_api.update_school_portion_defaults(
    pg_temp.rmvp01_request(
      'd9000000-0000-0000-0000-000000000102',
      'rmvp01-school-stale',
      1,
      'd1000000-0000-0000-0000-000000000101',
      jsonb_build_object(
        'school_id', 'd2000000-0000-0000-0000-000000000004',
        'default_student_portions', 130,
        'default_teacher_portions', 13
      )
    )
  )
);
insert into rmvp01_results values (
  'school_update_invalid',
  atlas_api.update_school_portion_defaults(
    pg_temp.rmvp01_request(
      'd9000000-0000-0000-0000-000000000103',
      'rmvp01-school-invalid',
      2,
      'd1000000-0000-0000-0000-000000000101',
      jsonb_build_object(
        'school_id', 'd2000000-0000-0000-0000-000000000004',
        'default_student_portions', -1,
        'default_teacher_portions', 13
      )
    )
  )
);

insert into rmvp01_results values (
  'supplier_create',
  atlas_api.create_supplier(
    pg_temp.rmvp01_request(
      'd9000000-0000-0000-0000-000000000201',
      'rmvp01-supplier-create',
      1,
      'd1000000-0000-0000-0000-000000000101',
      jsonb_build_object(
        'supplier_code', 'rmvp01-created-supplier',
        'supplier_name', 'Created Supplier',
        'contact_name', 'Operator',
        'contact_phone', '0900000000',
        'contact_email', 'operator@example.invalid'
      )
    )
  )
);
insert into rmvp01_results values (
  'ingredient_create',
  atlas_api.create_ingredient(
    pg_temp.rmvp01_request(
      'd9000000-0000-0000-0000-000000000301',
      'rmvp01-ingredient-create',
      1,
      'd1000000-0000-0000-0000-000000000101',
      jsonb_build_object(
        'ingredient_code', 'rmvp01-created-ingredient',
        'ingredient_name', 'Created Ingredient',
        'purchase_unit_id', 'd2000000-0000-0000-0000-000000000010',
        'ingredient_type', 'Food',
        'shopping_type', 'Planned',
        'order_step', 2
      )
    )
  )
);
insert into rmvp01_results values (
  'priority_replace',
  atlas_api.replace_ingredient_supplier_priorities(
    pg_temp.rmvp01_request(
      'd9000000-0000-0000-0000-000000000401',
      'rmvp01-priority-replace',
      1,
      'd1000000-0000-0000-0000-000000000101',
      jsonb_build_object(
        'ingredient_id', 'd2000000-0000-0000-0000-000000000011',
        'priorities', jsonb_build_array(
          jsonb_build_object(
            'supplier_id', 'd2000000-0000-0000-0000-000000000020',
            'priority', 1
          ),
          jsonb_build_object(
            'supplier_id', 'd2000000-0000-0000-0000-000000000021',
            'priority', 2
          )
        )
      )
    )
  )
);
insert into rmvp01_results values (
  'priority_duplicate',
  atlas_api.replace_ingredient_supplier_priorities(
    pg_temp.rmvp01_request(
      'd9000000-0000-0000-0000-000000000402',
      'rmvp01-priority-duplicate',
      2,
      'd1000000-0000-0000-0000-000000000101',
      jsonb_build_object(
        'ingredient_id', 'd2000000-0000-0000-0000-000000000011',
        'priorities', jsonb_build_array(
          jsonb_build_object(
            'supplier_id', 'd2000000-0000-0000-0000-000000000020',
            'priority', 1
          ),
          jsonb_build_object(
            'supplier_id', 'd2000000-0000-0000-0000-000000000020',
            'priority', 2
          )
        )
      )
    )
  )
);
insert into rmvp01_results values (
  'ingredient_update',
  atlas_api.update_ingredient(
    pg_temp.rmvp01_request(
      'd9000000-0000-0000-0000-000000000403',
      'rmvp01-ingredient-update',
      2,
      'd1000000-0000-0000-0000-000000000101',
      jsonb_build_object(
        'ingredient_id', 'd2000000-0000-0000-0000-000000000011',
        'ingredient_name', 'RMVP-01 rice updated',
        'purchase_unit_id', 'd2000000-0000-0000-0000-000000000010',
        'ingredient_type', 'Food',
        'shopping_type', 'Planned',
        'order_step', 10
      )
    )
  )
);
insert into rmvp01_results values (
  'supplier_update',
  atlas_api.update_supplier(
    pg_temp.rmvp01_request(
      'd9000000-0000-0000-0000-000000000501',
      'rmvp01-supplier-update',
      1,
      'd1000000-0000-0000-0000-000000000101',
      jsonb_build_object(
        'supplier_id', 'd2000000-0000-0000-0000-000000000020',
        'supplier_name', 'RMVP-01 Supplier A updated',
        'contact_name', 'A contact',
        'contact_phone', '0900000001',
        'contact_email', 'a@example.invalid'
      )
    )
  )
);
insert into rmvp01_results values (
  'lifecycle_inactive',
  atlas_api.set_ingredient_lifecycle(
    pg_temp.rmvp01_request(
      'd9000000-0000-0000-0000-000000000601',
      'rmvp01-lifecycle-inactive',
      3,
      'd1000000-0000-0000-0000-000000000101',
      jsonb_build_object(
        'ingredient_id', 'd2000000-0000-0000-0000-000000000011',
        'ingredient_status', 'INACTIVE'
      )
    )
  )
);
insert into rmvp01_results values (
  'master_read_after',
  atlas_api.get_ingredient_supplier_master_data(
    jsonb_build_object(
      'contract_version', 'RMVP-01.v1',
      'requested_by_auth_subject', 'd1000000-0000-0000-0000-000000000101',
      'correlation_id', 'd9000000-0000-0000-0000-000000000001',
      'payload', '{}'::jsonb
    )
  )
);
reset role;

select is(
  (select response_payload ->> 'success' from rmvp01_results where result_name = 'school_update'),
  'true',
  'school portion command succeeds'
);
select is(
  (select response_payload from rmvp01_results where result_name = 'school_update'),
  (select response_payload from rmvp01_results where result_name = 'school_update_replay'),
  'school exact replay returns the authoritative original response'
);
select is(
  (
    select jsonb_build_array(default_student_portions, default_teacher_portions)
    from atlas_admin.schools
    where school_id = 'd2000000-0000-0000-0000-000000000004'
  ),
  jsonb_build_array(120, 12),
  'school defaults persist once and read back'
);
select is(
  (select response_payload ->> 'error_code' from rmvp01_results where result_name = 'school_update_stale'),
  'STALE_VERSION',
  'stale school updates are rejected'
);
select is(
  (select response_payload ->> 'error_code' from rmvp01_results where result_name = 'school_update_invalid'),
  'VALIDATION_FAILED',
  'negative school defaults are rejected'
);
select is(
  (select response_payload ->> 'success' from rmvp01_results where result_name = 'supplier_create'),
  'true',
  'supplier creation succeeds'
);
select is(
  (select response_payload ->> 'success' from rmvp01_results where result_name = 'ingredient_create'),
  'true',
  'ingredient creation succeeds'
);
select is(
  (select response_payload ->> 'success' from rmvp01_results where result_name = 'priority_replace'),
  'true',
  'priority replacement succeeds'
);
select is(
  (select response_payload ->> 'error_code' from rmvp01_results where result_name = 'priority_duplicate'),
  'VALIDATION_FAILED',
  'duplicate supplier priorities are rejected before mutation'
);
select is(
  (
    select count(*)::integer
    from atlas_admin.supplier_eligibilities
    where ingredient_id = 'd2000000-0000-0000-0000-000000000011'
      and eligibility_status = 'ACTIVE'
  ),
  0,
  'ingredient deactivation safely retires active supplier priorities without deleting history'
);
select is(
  (
    select count(*)::integer
    from atlas_admin.supplier_eligibilities
    where ingredient_id = 'd2000000-0000-0000-0000-000000000011'
  ),
  2,
  'priority history survives unrelated ingredient edits and lifecycle deactivation'
);
select is(
  (
    select supplier_name
    from atlas_admin.suppliers
    where supplier_id = 'd2000000-0000-0000-0000-000000000020'
  ),
  'RMVP-01 Supplier A updated',
  'supplier name/contact update reads back'
);
select is(
  (
    select ingredient_name
    from atlas_admin.ingredients
    where ingredient_id = 'd2000000-0000-0000-0000-000000000011'
  ),
  'RMVP-01 rice updated',
  'ingredient field update reads back'
);
select ok(
  (select jsonb_array_length(response_payload -> 'ingredients') > 0
   from rmvp01_results where result_name = 'master_read_after')
  and
  (select jsonb_array_length(response_payload -> 'suppliers') > 0
   from rmvp01_results where result_name = 'master_read_after'),
  'connected ingredient/supplier read returns shaped authoritative arrays'
);
select is(
  (
    select response_payload -> 'schools' -> 0 ->> 'contract_context'
    from rmvp01_results
    where result_name = 'school_read_before'
  ),
  'Supported contract context',
  'school read exposes supported delivery/contract context'
);
select is(
  (
    select count(*)::integer
    from atlas_core.command_receipts
    where command_name in (
      'update_school_portion_defaults',
      'create_ingredient',
      'update_ingredient',
      'set_ingredient_lifecycle',
      'create_supplier',
      'update_supplier',
      'replace_ingredient_supplier_priorities'
    )
      and outcome = 'COMPLETED'
  ),
  7,
  'each successful write has one completed idempotent receipt'
);
select is(
  (
    select count(*)::integer
    from atlas_audit.domain_events
    where source_domain = 'ADMIN'
      and command_id::text like 'd9000000-0000-0000-0000-000000000%'
  ),
  7,
  'each successful master-data write emits one domain event'
);
select is(
  (
    select count(*)::integer
    from atlas_audit.audit_events
    where source_domain = 'ADMIN'
      and command_id::text like 'd9000000-0000-0000-0000-000000000%'
  ),
  7,
  'each successful master-data write emits one audit event'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'd1000000-0000-0000-0000-000000000102',
  true
);
select is(
  atlas_api.get_school_master_data(
    jsonb_build_object(
      'contract_version', 'RMVP-01.v1',
      'requested_by_auth_subject', 'd1000000-0000-0000-0000-000000000102',
      'correlation_id', 'd9000000-0000-0000-0000-000000000001',
      'payload', '{}'::jsonb
    )
  ) ->> 'error_code',
  'CAPABILITY_DENIED',
  'read capability denial is returned safely'
);
select throws_ok(
  $$select count(*) from atlas_admin.schools$$,
  '42501',
  'permission denied for schema atlas_admin',
  'authenticated cannot read private master-data tables directly'
);
select throws_ok(
  $$select atlas_legacy.import_master_data_snapshot('{}'::jsonb)$$,
  '42501',
  'permission denied for schema atlas_legacy',
  'authenticated cannot invoke or inspect the privileged importer'
);
reset role;

create temporary table import_results (
  result_name text primary key,
  response_payload jsonb not null
);
insert into import_results values (
  'valid',
  atlas_legacy.import_master_data_snapshot(
    jsonb_build_object(
      'source_system', 'RMVP01_TEST_EXPORT',
      'snapshot_id', 'valid-snapshot',
      'snapshot_checksum', repeat('a', 64),
      'exported_at', '2026-07-26T08:00:00Z',
      'records', jsonb_build_object(
        'customers', '[]'::jsonb,
        'delivery_locations', '[]'::jsonb,
        'school_types', '[]'::jsonb,
        'schools', '[]'::jsonb,
        'units', jsonb_build_array(
          jsonb_build_object(
            'legacy_id', 'legacy-unit',
            'unit_code', 'rmvp01-import-unit',
            'unit_name', 'Import unit',
            'dimension_code', 'COUNT',
            'decimal_scale', 0,
            'unit_status', 'ACTIVE'
          )
        ),
        'ingredients', jsonb_build_array(
          jsonb_build_object(
            'legacy_id', 'legacy-ingredient',
            'ingredient_code', 'rmvp01-import-ingredient',
            'ingredient_name', 'Import ingredient',
            'ingredient_type', 'Food',
            'shopping_type', 'Planned',
            'purchase_unit_legacy_id', 'legacy-unit',
            'order_step', 1,
            'ingredient_status', 'ACTIVE'
          )
        ),
        'suppliers', jsonb_build_array(
          jsonb_build_object(
            'legacy_id', 'legacy-supplier',
            'supplier_code', 'rmvp01-import-supplier',
            'supplier_name', 'Import supplier',
            'supplier_status', 'ACTIVE'
          )
        ),
        'supplier_priorities', jsonb_build_array(
          jsonb_build_object(
            'ingredient_legacy_id', 'legacy-ingredient',
            'supplier_legacy_id', 'legacy-supplier',
            'priority', 1
          )
        )
      )
    )
  )
);
insert into import_results
select
  'replay',
  atlas_legacy.import_master_data_snapshot(
    jsonb_build_object(
      'source_system', 'RMVP01_TEST_EXPORT',
      'snapshot_id', 'valid-snapshot',
      'snapshot_checksum', repeat('a', 64),
      'exported_at', '2026-07-26T08:00:00Z',
      'records', '{}'::jsonb
    )
  );
insert into import_results values (
  'missing_reference',
  atlas_legacy.import_master_data_snapshot(
    jsonb_build_object(
      'source_system', 'RMVP01_TEST_EXPORT',
      'snapshot_id', 'missing-reference',
      'snapshot_checksum', repeat('b', 64),
      'exported_at', '2026-07-26T08:00:00Z',
      'records', jsonb_build_object(
        'ingredients', jsonb_build_array(
          jsonb_build_object(
            'legacy_id', 'bad-ingredient',
            'ingredient_code', 'rmvp01-bad-import-ingredient',
            'ingredient_name', 'Bad import ingredient',
            'ingredient_type', 'Food',
            'shopping_type', 'Planned',
            'purchase_unit_legacy_id', 'missing-unit',
            'order_step', 1,
            'ingredient_status', 'ACTIVE'
          )
        )
      )
    )
  )
);

select is(
  (select response_payload ->> 'success' from import_results where result_name = 'valid'),
  'true',
  'valid explicit snapshot imports successfully'
);
select is(
  (select response_payload ->> 'rerun' from import_results where result_name = 'replay'),
  'true',
  'identical snapshot rerun replays the stored result'
);
select is(
  (
    select (response_payload #>> '{operation_counts,inserted}')::integer
    from import_results
    where result_name = 'valid'
  ),
  4,
  'completed import reports inserted records explicitly'
);
select is(
  (
    select (response_payload #>> '{operation_counts,skipped}')::integer
    from import_results
    where result_name = 'replay'
  ),
  4,
  'identical snapshot rerun reports every source record as skipped'
);
select is(
  (
    select count(*)::integer
    from atlas_admin.ingredients
    where ingredient_code = 'rmvp01-import-ingredient'
  ),
  1,
  'snapshot rerun does not duplicate target master data'
);
select is(
  (
    select response_payload ->> 'error_code'
    from import_results
    where result_name = 'missing_reference'
  ),
  'SNAPSHOT_REJECTED',
  'snapshot with a missing typed reference is rejected'
);
select is(
  (
    select jsonb_array_length(response_payload -> 'missing_references')
    from import_results
    where result_name = 'missing_reference'
  ),
  1,
  'missing-reference result is explicit and countable'
);
select is(
  (
    select (response_payload #>> '{operation_counts,rejected}')::integer
    from import_results
    where result_name = 'missing_reference'
  ),
  1,
  'rejected snapshot reports rejected source records explicitly'
);
select is(
  (
    select count(*)::integer
    from atlas_admin.ingredients
    where ingredient_code = 'rmvp01-bad-import-ingredient'
  ),
  0,
  'rejected snapshot performs no partial target writes'
);
select is(
  (
    select count(*)::integer
    from atlas_legacy.import_batches
    where source_system = 'RMVP01_TEST_EXPORT'
  ),
  2,
  'import evidence stores one completed and one rejected batch, not the replay'
);
select ok(
  (
    select (reconciliation ->> 'passed')::boolean
    from atlas_legacy.import_batches
    where source_system = 'RMVP01_TEST_EXPORT'
      and snapshot_id = 'valid-snapshot'
  ),
  'completed import stores passed source/target reconciliation'
);

select * from finish();
rollback;
