begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
select no_plan();

grant usage on schema extensions to authenticated;
grant execute on all functions in schema extensions to authenticated;

select is(
  (
    select array_agg(capability_code order by capability_code)::text[]
    from atlas_core.capabilities
    where capability_code like 'master_data.recipes.%'
  ),
  array[
    'master_data.recipes.import',
    'master_data.recipes.read',
    'master_data.recipes.release',
    'master_data.recipes.validate',
    'master_data.recipes.write'
  ]::text[],
  'RMVP-02A registers exactly five recipe capabilities'
);

select is(
  (
    select array_agg(p.proname order by p.proname)::text[]
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
      and p.proname in (
        'get_dish_recipe_workbench',
        'create_dish',
        'update_dish',
        'set_dish_lifecycle',
        'set_recipe_lifecycle',
        'create_recipe_draft',
        'create_recipe_successor_version',
        'replace_recipe_draft_composition',
        'validate_recipe_version',
        'release_recipe_version_for_planning',
        'copy_recipe_version',
        'apply_recipe_import'
      )
  ),
  array[
    'apply_recipe_import',
    'copy_recipe_version',
    'create_dish',
    'create_recipe_draft',
    'create_recipe_successor_version',
    'get_dish_recipe_workbench',
    'release_recipe_version_for_planning',
    'replace_recipe_draft_composition',
    'set_dish_lifecycle',
    'set_recipe_lifecycle',
    'update_dish',
    'validate_recipe_version'
  ]::text[],
  'RMVP-02A exposes exactly twelve bounded APIs'
);

select ok(
  (
    select bool_and(
      p.prosecdef
      and p.proconfig = array['search_path=""']::text[]
      and has_function_privilege('authenticated', p.oid, 'EXECUTE')
      and not has_function_privilege('anon', p.oid, 'EXECUTE')
      and not has_function_privilege('service_role', p.oid, 'EXECUTE')
    )
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
      and p.proname in (
        'get_dish_recipe_workbench',
        'create_dish',
        'update_dish',
        'set_dish_lifecycle',
        'set_recipe_lifecycle',
        'create_recipe_draft',
        'create_recipe_successor_version',
        'replace_recipe_draft_composition',
        'validate_recipe_version',
        'release_recipe_version_for_planning',
        'copy_recipe_version',
        'apply_recipe_import'
      )
  ),
  'all RMVP-02A APIs are fixed-search-path definers with the exact API-role boundary'
);

select is(
  (
    select array_agg(
      p.proname || '=' || r.rolname
      order by p.proname
    )::text[]
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    join pg_roles r on r.oid = p.proowner
    where n.nspname = 'atlas_api'
      and p.proname in (
        'get_dish_recipe_workbench',
        'create_dish',
        'update_dish',
        'set_dish_lifecycle',
        'set_recipe_lifecycle',
        'create_recipe_draft',
        'create_recipe_successor_version',
        'replace_recipe_draft_composition',
        'validate_recipe_version',
        'release_recipe_version_for_planning',
        'copy_recipe_version',
        'apply_recipe_import'
      )
  ),
  array[
    'apply_recipe_import=atlas_master_data_command_runtime',
    'copy_recipe_version=atlas_master_data_command_runtime',
    'create_dish=atlas_master_data_command_runtime',
    'create_recipe_draft=atlas_master_data_command_runtime',
    'create_recipe_successor_version=atlas_master_data_command_runtime',
    'get_dish_recipe_workbench=atlas_read_runtime',
    'release_recipe_version_for_planning=atlas_master_data_command_runtime',
    'replace_recipe_draft_composition=atlas_master_data_command_runtime',
    'set_dish_lifecycle=atlas_master_data_command_runtime',
    'set_recipe_lifecycle=atlas_master_data_command_runtime',
    'update_dish=atlas_master_data_command_runtime',
    'validate_recipe_version=atlas_master_data_command_runtime'
  ]::text[],
  'recipe read and command APIs have the approved runtime ownership split'
);

select ok(
  not has_schema_privilege('authenticated', 'atlas_admin', 'USAGE')
  and not has_schema_privilege('authenticated', 'atlas_legacy', 'USAGE')
  and not has_schema_privilege('anon', 'atlas_admin', 'USAGE')
  and not has_schema_privilege('service_role', 'atlas_admin', 'USAGE'),
  'physical recipe and reconciliation relations remain private'
);

select is(
  (
    select array_agg(column_name order by ordinal_position)::text[]
    from information_schema.columns
    where table_schema = 'atlas_legacy'
      and table_name = 'master_data_mappings'
      and column_name in (
        'dish_id',
        'recipe_id',
        'recipe_version_id',
        'recipe_line_id',
        'recipe_line_revision_id'
      )
  ),
  array[
    'dish_id',
    'recipe_id',
    'recipe_version_id',
    'recipe_line_id',
    'recipe_line_revision_id'
  ]::text[],
  'legacy reconciliation has typed recipe object references'
);

insert into atlas_core.actors (
  actor_id, actor_type, display_name
) values
  (
    'e2000000-0000-0000-0000-000000000001',
    'HUMAN',
    'RMVP-02A authorized recipe operator'
  ),
  (
    'e2000000-0000-0000-0000-000000000002',
    'HUMAN',
    'RMVP-02A denied operator'
  );

insert into atlas_core.actor_auth_subjects (
  actor_auth_subject_id, actor_id, auth_subject_id
) values
  (
    'e2000000-0000-0000-0000-000000000011',
    'e2000000-0000-0000-0000-000000000001',
    'e2000000-0000-0000-0000-000000000101'
  ),
  (
    'e2000000-0000-0000-0000-000000000012',
    'e2000000-0000-0000-0000-000000000002',
    'e2000000-0000-0000-0000-000000000102'
  );

insert into atlas_core.roles (
  role_id, role_code, role_name
) values
  (
    'e2000000-0000-0000-0000-000000000020',
    'rmvp02a.recipe_operator',
    'RMVP-02A recipe operator'
  ),
  (
    'e2000000-0000-0000-0000-000000000021',
    'rmvp02a.no_capability',
    'RMVP-02A no capability'
  );

insert into atlas_core.role_capabilities (role_id, capability_id)
select 'e2000000-0000-0000-0000-000000000020', capability_id
from atlas_core.capabilities
where capability_code like 'master_data.recipes.%';

insert into atlas_core.actor_role_memberships (actor_id, role_id) values
  (
    'e2000000-0000-0000-0000-000000000001',
    'e2000000-0000-0000-0000-000000000020'
  ),
  (
    'e2000000-0000-0000-0000-000000000002',
    'e2000000-0000-0000-0000-000000000021'
  );

insert into atlas_core.actor_scopes (actor_id, scope_kind) values
  ('e2000000-0000-0000-0000-000000000001', 'GLOBAL'),
  ('e2000000-0000-0000-0000-000000000002', 'GLOBAL');

insert into atlas_admin.school_types (
  school_type_id, school_type_code, school_type_name
) values
  (
    'e2100000-0000-0000-0000-000000000001',
    'v1-school-type-1',
    'TIỂU HỌC'
  ),
  (
    'e2100000-0000-0000-0000-000000000002',
    'v1-school-type-2',
    'TRUNG HỌC'
  );

insert into atlas_admin.units (
  unit_id, unit_code, unit_name, dimension_code, decimal_scale
) values (
  'e2100000-0000-0000-0000-000000000010',
  'rmvp02a-kg',
  'RMVP-02A kilogram',
  'MASS',
  3
);

insert into atlas_admin.ingredients (
  ingredient_id, ingredient_code, ingredient_name, ingredient_group,
  purchase_unit_id, ingredient_type, shopping_type, order_step
) values
  (
    'e2100000-0000-0000-0000-000000000020',
    'rmvp02a-pork',
    'RMVP-02A Pork',
    'Food',
    'e2100000-0000-0000-0000-000000000010',
    'Food',
    'Planned',
    1
  ),
  (
    'e2100000-0000-0000-0000-000000000021',
    'rmvp02a-pumpkin',
    'RMVP-02A Pumpkin',
    'Food',
    'e2100000-0000-0000-0000-000000000010',
    'Food',
    'Planned',
    1
  );

insert into atlas_admin.dish_types (
  dish_type_id,
  dish_type_code,
  dish_type_name,
  source_header_aliases,
  display_order,
  dish_type_status
) values (
  'e2100000-0000-4000-8000-000000000030',
  'rmvp02a_inactive',
  'RMVP-02A Inactive Dish Type',
  array['Inactive fixture']::text[],
  99,
  'INACTIVE'
);

create or replace function pg_temp.rmvp02a_request(
  p_name text,
  p_expected_version bigint,
  p_payload jsonb,
  p_subject uuid default 'e2000000-0000-0000-0000-000000000101'
)
returns jsonb
language sql
as $$
  select jsonb_build_object(
    'contract_version', 'RMVP-02A.v1',
    'command_id', md5('rmvp02a-command:' || p_name)::uuid,
    'correlation_id', 'e2900000-0000-0000-0000-000000000001',
    'idempotency_key', 'rmvp02a:' || p_name,
    'expected_version', p_expected_version,
    'requested_by_auth_subject', p_subject,
    'requested_at', transaction_timestamp() - interval '1 second',
    'reason_code', 'RMVP02A_TEST',
    'reason_note', 'Rolled-back RMVP-02A acceptance test: ' || p_name,
    'payload', p_payload
  );
$$;

create temporary table rmvp02a_results (
  result_name text primary key,
  response_payload jsonb not null
);
grant select, insert on rmvp02a_results to authenticated;

create temporary table rmvp02a_import_documents (
  document_name text primary key,
  canonical_json text not null,
  checksum text not null
);
grant select on rmvp02a_import_documents to authenticated;

insert into rmvp02a_import_documents (document_name, canonical_json, checksum)
select document_name, canonical_json, encode(
  extensions.digest(convert_to(canonical_json, 'UTF8'), 'sha256'),
  'hex'
)
from (
  values
    (
      'valid',
      jsonb_build_object(
        'rows',
        jsonb_build_array(
          jsonb_build_object(
            'legacy_line_id', 'ops-v1:line:rmvp02a-import:pork',
            'dish_legacy_id', 'ops-v1:dish:rmvp02a-import',
            'recipe_legacy_id', 'ops-v1:recipe:rmvp02a-import:general',
            'dish_code', 'rmvp02a-import',
            'dish_name', 'RMVP-02A Imported Dish',
            'dish_category', 'Imported',
            'operational_notes', 'Reviewed workbook fixture',
            'requires_need_generation', true,
            'school_type_id', null,
            'basis_portions', 100,
            'ingredient_id', 'e2100000-0000-0000-0000-000000000020',
            'quantity_per_basis', 12.5,
            'unit_id', 'e2100000-0000-0000-0000-000000000010',
            'operational_note', 'Imported as draft'
          )
        )
      )::text
    ),
    (
      'missing-reference',
      jsonb_build_object(
        'rows',
        jsonb_build_array(
          jsonb_build_object(
            'legacy_line_id', 'ops-v1:line:rmvp02a-missing:unknown',
            'dish_legacy_id', 'ops-v1:dish:rmvp02a-missing',
            'recipe_legacy_id', 'ops-v1:recipe:rmvp02a-missing:general',
            'dish_code', 'rmvp02a-missing',
            'dish_name', 'RMVP-02A Missing Reference',
            'requires_need_generation', true,
            'school_type_id', null,
            'basis_portions', 100,
            'ingredient_id', 'e2100000-0000-0000-0000-000000009999',
            'quantity_per_basis', 1,
            'unit_id', 'e2100000-0000-0000-0000-000000000010'
          )
        )
      )::text
    )
) documents(document_name, canonical_json);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'e2000000-0000-0000-0000-000000000101',
  true
);

-- Normal creation omits operator-managed reference metadata. Each omission is
-- independent so validation cannot accidentally hide a missing default.
insert into rmvp02a_results
select fixture_name, atlas_api.create_dish(pg_temp.rmvp02a_request(
  fixture_name, 1, payload
))
from (values
  ('auto-all', jsonb_build_object('dish_name', 'Auto Dish', 'dish_type_id', 'd1500000-0000-4000-8000-000000000001')),
  ('auto-code', jsonb_build_object('dish_name', 'Auto Code', 'dish_type_id', 'd1500000-0000-4000-8000-000000000001', 'display_order', 4, 'requires_need_generation', true)),
  ('auto-order', jsonb_build_object('dish_code', 'auto-order', 'dish_name', 'Auto Order', 'dish_type_id', 'd1500000-0000-4000-8000-000000000001', 'requires_need_generation', true)),
  ('auto-requires', jsonb_build_object('dish_code', 'auto-requires', 'dish_name', 'Auto Requires', 'dish_type_id', 'd1500000-0000-4000-8000-000000000001', 'display_order', 4)),
  ('explicit-compat', jsonb_build_object('dish_code', '  EXPLICIT-COMPAT  ', 'dish_name', 'Explicit Compatibility', 'dish_type_id', 'd1500000-0000-4000-8000-000000000001', 'display_order', 9, 'requires_need_generation', true))
) fixture(fixture_name, payload);

select is(response_payload ->> 'success', 'true', result_name || ' creates successfully')
from rmvp02a_results where result_name in ('auto-all', 'auto-code', 'auto-order', 'auto-requires', 'explicit-compat')
order by result_name;

insert into rmvp02a_results values ('auto-replay', atlas_api.create_dish(
  pg_temp.rmvp02a_request('auto-all', 1, jsonb_build_object(
    'dish_name', 'Auto Dish', 'dish_type_id', 'd1500000-0000-4000-8000-000000000001'
  ))
));
select is(
  (select response_payload from rmvp02a_results where result_name = 'auto-replay'),
  (select response_payload from rmvp02a_results where result_name = 'auto-all'),
  'automatic-code replay returns the exact original identity and code readback'
);

insert into rmvp02a_results values ('explicit-code-conflict', atlas_api.create_dish(
  pg_temp.rmvp02a_request('explicit-code-conflict', 1, jsonb_build_object(
    'dish_code', 'explicit-compat', 'dish_name', 'Different name',
    'dish_type_id', 'd1500000-0000-4000-8000-000000000001'
  ))
));
select is((select response_payload ->> 'error_code' from rmvp02a_results
  where result_name = 'explicit-code-conflict'), 'CONFLICT',
  'explicit normalized code uniqueness remains enforced');

reset role;
select is((select count(*)::integer from atlas_admin.dishes
  where dish_name in ('Auto Dish', 'Auto Code')), 2,
  'two automatic creations persist exactly two Dishes despite replay');
select is((select count(distinct dish_code)::integer from atlas_admin.dishes
  where dish_name in ('Auto Dish', 'Auto Code') and dish_code ~ '^dish-[0-9a-f-]{36}$'), 2,
  'generated codes are nonempty unique opaque UUID codes');
select is((select display_order from atlas_admin.dishes where dish_name = 'Auto Dish'), 0,
  'all-omitted creation defaults display order to zero');
select is((select display_order from atlas_admin.dishes where dish_code = 'auto-order'), 0,
  'explicit-code creation can omit display order');
select is((select requires_need_generation from atlas_admin.dishes where dish_name = 'Auto Dish'), true,
  'all-omitted creation participates in Need Generation');
select is((select requires_need_generation from atlas_admin.dishes where dish_code = 'auto-requires'), true,
  'explicit-code creation can omit demand participation');
select is((select jsonb_build_array(display_order, requires_need_generation)
  from atlas_admin.dishes where dish_code = 'explicit-compat'), '[9, true]'::jsonb,
  'controlled explicit metadata remains compatible without rewriting persisted history');
select is((select item ->> 'dish_code'
  from rmvp02a_results result,
  jsonb_array_elements(result.response_payload #> '{authoritative_readback,dishes}') item
  where result.result_name = 'auto-all'
    and item ->> 'dish_id' = result.response_payload #>> '{affected_aggregate_ids,dish_id}'),
  (select dish_code from atlas_admin.dishes where dish_name = 'Auto Dish'),
  'server readback exposes the persisted generated code');

set local role authenticated;
insert into rmvp02a_results values ('explicit-false', atlas_api.create_dish(
  pg_temp.rmvp02a_request('explicit-false', 1, jsonb_build_object(
    'dish_name', 'Rejected False Dish',
    'dish_type_id', 'd1500000-0000-4000-8000-000000000001',
    'requires_need_generation', false
  ))
));
select is((select response_payload ->> 'error_code' from rmvp02a_results
  where result_name = 'explicit-false'), 'VALIDATION_FAILED',
  'explicit false creation rejects the obsolete business decision');
reset role;
select is((select count(*) from atlas_admin.dishes
  where dish_name = 'Rejected False Dish'), 0::bigint,
  'explicit false is not silently coerced or persisted');

-- A name edit must not regenerate permanent reference identity.
create temporary table auto_dish_identity as
select dish_id, dish_code from atlas_admin.dishes where dish_name = 'Auto Dish';
update atlas_admin.dishes set dish_name = 'Renamed Auto Dish' where dish_name = 'Auto Dish';
select is((select dish.dish_code from atlas_admin.dishes dish
  join auto_dish_identity original using (dish_id)),
  (select dish_code from auto_dish_identity), 'renaming preserves the generated code');
set local role authenticated;

insert into rmvp02a_results values (
  'create-main-dish',
  atlas_api.create_dish(
    pg_temp.rmvp02a_request(
      'create-main-dish',
      1,
      jsonb_build_object(
        'dish_code', 'rmvp02a-soup',
        'dish_name', 'RMVP-02A Pumpkin Soup',
        'dish_category', 'Soup',
        'dish_type_id', 'd1500000-0000-4000-8000-000000000001',
        'operational_notes', 'Cook on service day',
        'display_order', 1,
        'requires_need_generation', true
      )
    )
  )
);

insert into rmvp02a_results values (
  'create-target-dish',
  atlas_api.create_dish(
    pg_temp.rmvp02a_request(
      'create-target-dish',
      1,
      jsonb_build_object(
        'dish_code', 'rmvp02a-target',
        'dish_name', 'RMVP-02A Copy Target',
        'dish_type_id', 'd1500000-0000-4000-8000-000000000002',
        'display_order', 2,
        'requires_need_generation', true
      )
    )
  )
);

insert into rmvp02a_results values (
  'create-inactive-type-dish',
  atlas_api.create_dish(
    pg_temp.rmvp02a_request(
      'create-inactive-type-dish',
      1,
      jsonb_build_object(
        'dish_code', 'rmvp02a-inactive-type',
        'dish_name', 'RMVP-02A Inactive Type Dish',
        'dish_type_id', 'e2100000-0000-4000-8000-000000000030',
        'display_order', 3,
        'requires_need_generation', true
      )
    )
  )
);

insert into rmvp02a_results
select
  'update-main-to-inactive-type',
  atlas_api.update_dish(
    pg_temp.rmvp02a_request(
      'update-main-to-inactive-type',
      1,
      jsonb_build_object(
        'dish_id',
          created.response_payload #>> '{affected_aggregate_ids,dish_id}',
        'dish_code', 'rmvp02a-soup',
        'dish_name', 'RMVP-02A Pumpkin Soup',
        'dish_category', 'Soup',
        'dish_type_id', 'e2100000-0000-4000-8000-000000000030',
        'operational_notes', 'Cook on service day',
        'display_order', 1,
        'requires_need_generation', true
      )
    )
  )
from rmvp02a_results created
where created.result_name = 'create-main-dish';

insert into rmvp02a_results values (
  'create-draft',
  atlas_api.create_recipe_draft(
    pg_temp.rmvp02a_request(
      'create-draft',
      1,
      jsonb_build_object(
        'dish_id',
        (
          select response_payload #>> '{affected_aggregate_ids,dish_id}'
          from rmvp02a_results
          where result_name = 'create-main-dish'
        ),
        'school_type_id', null,
        'basis_portions', 100
      )
    )
  )
);

insert into rmvp02a_results values (
  'replace-initial-bom',
  atlas_api.replace_recipe_draft_composition(
    pg_temp.rmvp02a_request(
      'replace-initial-bom',
      1,
      jsonb_build_object(
        'recipe_version_id',
        (
          select response_payload #>> '{affected_aggregate_ids,recipe_version_id}'
          from rmvp02a_results
          where result_name = 'create-draft'
        ),
        'basis_portions', 100,
        'lines', jsonb_build_array(
          jsonb_build_object(
            'ingredient_id', 'e2100000-0000-0000-0000-000000000020',
            'quantity_per_basis', 12.5,
            'unit_id', 'e2100000-0000-0000-0000-000000000010',
            'line_disposition', 'PRESENT',
            'operational_note', 'Trim before cooking',
            'line_code', 'pork'
          ),
          jsonb_build_object(
            'ingredient_id', 'e2100000-0000-0000-0000-000000000021',
            'quantity_per_basis', 25,
            'unit_id', 'e2100000-0000-0000-0000-000000000010',
            'line_disposition', 'PRESENT',
            'operational_note', 'Peel and dice',
            'line_code', 'pumpkin'
          )
        )
      )
    )
  )
);

insert into rmvp02a_results values (
  'stale-bom-save',
  atlas_api.replace_recipe_draft_composition(
    pg_temp.rmvp02a_request(
      'stale-bom-save',
      1,
      (
        select jsonb_build_object(
          'recipe_version_id',
          response_payload #>> '{affected_aggregate_ids,recipe_version_id}',
          'basis_portions', 100,
          'lines', response_payload #> '{authoritative_readback,recipe_versions,0,composition}'
        )
        from rmvp02a_results
        where result_name = 'replace-initial-bom'
      )
    )
  )
);

insert into rmvp02a_results values (
  'validate-initial',
  atlas_api.validate_recipe_version(
    pg_temp.rmvp02a_request(
      'validate-initial',
      2,
      jsonb_build_object(
        'recipe_version_id',
        (
          select response_payload #>> '{affected_aggregate_ids,recipe_version_id}'
          from rmvp02a_results
          where result_name = 'create-draft'
        )
      )
    )
  )
);

set constraints all immediate;
set constraints all deferred;

insert into rmvp02a_results values (
  'mutate-validated',
  atlas_api.replace_recipe_draft_composition(
    pg_temp.rmvp02a_request(
      'mutate-validated',
      3,
      jsonb_build_object(
        'recipe_version_id',
        (
          select response_payload #>> '{affected_aggregate_ids,recipe_version_id}'
          from rmvp02a_results
          where result_name = 'create-draft'
        ),
        'basis_portions', 100,
        'lines', jsonb_build_array()
      )
    )
  )
);

insert into rmvp02a_results values (
  'release-initial',
  atlas_api.release_recipe_version_for_planning(
    pg_temp.rmvp02a_request(
      'release-initial',
      3,
      jsonb_build_object(
        'recipe_version_id',
        (
          select response_payload #>> '{affected_aggregate_ids,recipe_version_id}'
          from rmvp02a_results
          where result_name = 'create-draft'
        )
      )
    )
  )
);

set constraints all immediate;
set constraints all deferred;

insert into rmvp02a_results values (
  'create-successor',
  atlas_api.create_recipe_successor_version(
    pg_temp.rmvp02a_request(
      'create-successor',
      4,
      jsonb_build_object(
        'recipe_version_id',
        (
          select response_payload #>> '{affected_aggregate_ids,recipe_version_id}'
          from rmvp02a_results
          where result_name = 'create-draft'
        )
      )
    )
  )
);

insert into rmvp02a_results values (
  'replace-successor-explicit-removal',
  atlas_api.replace_recipe_draft_composition(
    pg_temp.rmvp02a_request(
      'replace-successor-explicit-removal',
      1,
      (
        select jsonb_build_object(
          'recipe_version_id',
          successor.response_payload #>> '{affected_aggregate_ids,recipe_version_id}',
          'basis_portions', 100,
          'lines',
          (
            select jsonb_agg(
              case
                when line ->> 'line_code' = 'pumpkin' then
                  line
                    || jsonb_build_object(
                      'quantity_per_basis', 0,
                      'line_disposition', 'REMOVED'
                    )
                else line
              end
              order by line ->> 'line_code'
            )
            from jsonb_array_elements(
              successor.response_payload
                #> '{authoritative_readback,recipe_versions}'
            ) version,
            jsonb_array_elements(version -> 'composition') line
            where version ->> 'recipe_version_id' =
              successor.response_payload
                #>> '{affected_aggregate_ids,recipe_version_id}'
          )
        )
        from rmvp02a_results successor
        where successor.result_name = 'create-successor'
      )
    )
  )
);

insert into rmvp02a_results values (
  'validate-successor',
  atlas_api.validate_recipe_version(
    pg_temp.rmvp02a_request(
      'validate-successor',
      2,
      jsonb_build_object(
        'recipe_version_id',
        (
          select response_payload #>> '{affected_aggregate_ids,recipe_version_id}'
          from rmvp02a_results
          where result_name = 'create-successor'
        )
      )
    )
  )
);

insert into rmvp02a_results values (
  'release-successor',
  atlas_api.release_recipe_version_for_planning(
    pg_temp.rmvp02a_request(
      'release-successor',
      3,
      jsonb_build_object(
        'recipe_version_id',
        (
          select response_payload #>> '{affected_aggregate_ids,recipe_version_id}'
          from rmvp02a_results
          where result_name = 'create-successor'
        )
      )
    )
  )
);

insert into rmvp02a_results values (
  'copy-locked-version',
  atlas_api.copy_recipe_version(
    pg_temp.rmvp02a_request(
      'copy-locked-version',
      1,
      jsonb_build_object(
        'source_recipe_version_id',
        (
          select response_payload #>> '{affected_aggregate_ids,recipe_version_id}'
          from rmvp02a_results
          where result_name = 'create-draft'
        ),
        'target_dish_id',
        (
          select response_payload #>> '{affected_aggregate_ids,dish_id}'
          from rmvp02a_results
          where result_name = 'create-target-dish'
        ),
        'target_school_type_id', null
      )
    )
  )
);

insert into rmvp02a_results values (
  'import-missing-reference',
  atlas_api.apply_recipe_import(
    pg_temp.rmvp02a_request(
      'import-missing-reference',
      1,
      (
        select jsonb_build_object(
          'canonical_json', canonical_json,
          'workbook_checksum', checksum
        )
        from rmvp02a_import_documents
        where document_name = 'missing-reference'
      )
    )
  )
);

insert into rmvp02a_results values (
  'import-valid',
  atlas_api.apply_recipe_import(
    pg_temp.rmvp02a_request(
      'import-valid',
      1,
      (
        select jsonb_build_object(
          'canonical_json', canonical_json,
          'workbook_checksum', checksum
        )
        from rmvp02a_import_documents
        where document_name = 'valid'
      )
    )
  )
);

insert into rmvp02a_results values (
  'import-valid-rerun',
  atlas_api.apply_recipe_import(
    pg_temp.rmvp02a_request(
      'import-valid-rerun',
      1,
      (
        select jsonb_build_object(
          'canonical_json', canonical_json,
          'workbook_checksum', checksum
        )
        from rmvp02a_import_documents
        where document_name = 'valid'
      )
    )
  )
);

insert into rmvp02a_results values (
  'authorized-read',
  atlas_api.get_dish_recipe_workbench(
    jsonb_build_object(
      'contract_version', 'RMVP-02A.v1',
      'requested_by_auth_subject',
        'e2000000-0000-0000-0000-000000000101',
      'correlation_id', 'e2900000-0000-0000-0000-000000000001',
      'payload', '{}'::jsonb
    )
  )
);

select set_config(
  'request.jwt.claim.sub',
  'e2000000-0000-0000-0000-000000000102',
  true
);

insert into rmvp02a_results values (
  'denied-read',
  atlas_api.get_dish_recipe_workbench(
    jsonb_build_object(
      'contract_version', 'RMVP-02A.v1',
      'requested_by_auth_subject',
        'e2000000-0000-0000-0000-000000000102',
      'correlation_id', 'e2900000-0000-0000-0000-000000000002',
      'payload', '{}'::jsonb
    )
  )
);

insert into rmvp02a_results values (
  'denied-command',
  atlas_api.create_dish(
    pg_temp.rmvp02a_request(
      'denied-command',
      1,
      jsonb_build_object(
        'dish_code', 'rmvp02a-denied',
        'dish_name', 'Denied Dish',
        'dish_type_id', 'd1500000-0000-4000-8000-000000000001',
        'display_order', 99,
        'requires_need_generation', true
      ),
      'e2000000-0000-0000-0000-000000000102'
    )
  )
);

select throws_ok(
  $$select count(*) from atlas_admin.recipe_versions$$,
  '42501',
  'permission denied for schema atlas_admin',
  'authenticated cannot bypass the API to read private recipe versions'
);

reset role;

select ok(
  (
    select bool_and((response_payload ->> 'success')::boolean)
    from rmvp02a_results
    where result_name in (
      'create-main-dish',
      'create-target-dish',
      'create-draft',
      'replace-initial-bom',
      'validate-initial',
      'release-initial',
      'create-successor',
      'replace-successor-explicit-removal',
      'validate-successor',
      'release-successor',
      'copy-locked-version',
      'import-valid',
      'import-valid-rerun',
      'authorized-read'
    )
  ),
  'the full dish, draft, validate, release, successor, copy, import, and read workflow succeeds'
);

select is(
  (
    select response_payload ->> 'error_code'
    from rmvp02a_results
    where result_name = 'create-inactive-type-dish'
  ),
  'VALIDATION_FAILED',
  'Dish creation rejects an inactive database Dish Type'
);

select is(
  (
    select response_payload ->> 'error_code'
    from rmvp02a_results
    where result_name = 'update-main-to-inactive-type'
  ),
  'VALIDATION_FAILED',
  'Dish updates reject an inactive database Dish Type'
);

select is(
  (
    select response_payload ->> 'error_code'
    from rmvp02a_results
    where result_name = 'stale-bom-save'
  ),
  'STALE_VERSION',
  'stale draft save fails closed'
);

select is(
  (
    select response_payload ->> 'error_code'
    from rmvp02a_results
    where result_name = 'mutate-validated'
  ),
  'INVARIANT_VIOLATION',
  'validated composition is immutable through the command API'
);

select is(
  (
    select response_payload ->> 'error_code'
    from rmvp02a_results
    where result_name = 'import-missing-reference'
  ),
  'VALIDATION_FAILED',
  'missing import references are rejected without auto-creation'
);

select ok(
  (
    select jsonb_array_length(response_payload -> 'blocking_references') > 0
    from rmvp02a_results
    where result_name = 'import-missing-reference'
  ),
  'rejected import returns bounded missing-reference evidence'
);

select ok(
  (
    select (response_payload #>> '{import_result,rerun}')::boolean
      and (
        response_payload #>> '{import_result,operation_counts,inserted}'
      )::integer = 0
      and (
        response_payload #>> '{import_result,operation_counts,updated}'
      )::integer = 0
    from rmvp02a_results
    where result_name = 'import-valid-rerun'
  ),
  'identical workbook rerun is idempotent and performs no duplicate writes'
);

select is(
  (
    select recipe_version_status
    from atlas_admin.recipe_versions
    where recipe_version_id = (
      select (
        response_payload #>> '{affected_aggregate_ids,recipe_version_id}'
      )::uuid
      from rmvp02a_results
      where result_name = 'create-draft'
    )
  ),
  'LOCKED',
  'releasing a successor locks the prior planning release'
);

select is(
  (
    select recipe_version_status
    from atlas_admin.recipe_versions
    where recipe_version_id = (
      select (
        response_payload #>> '{affected_aggregate_ids,recipe_version_id}'
      )::uuid
      from rmvp02a_results
      where result_name = 'create-successor'
    )
  ),
  'RELEASED_FOR_PLANNING',
  'the successor is the only planning-released version'
);

select is(
  (
    select count(*)::integer
    from atlas_admin.recipe_line_revisions
    where recipe_version_id = (
      select (
        response_payload #>> '{affected_aggregate_ids,recipe_version_id}'
      )::uuid
      from rmvp02a_results
      where result_name = 'create-successor'
    )
      and line_disposition = 'REMOVED'
      and predecessor_recipe_line_revision_id is not null
  ),
  1,
  'successor materialization retains one explicit removed-line revision'
);

select ok(
  (
    select source_evidence #>> '{source_kind}' = 'RECIPE_COPY'
      and recipe_version_status = 'DRAFT'
      and jsonb_array_length(draft_composition) = 2
    from atlas_admin.recipe_versions
    where recipe_version_id = (
      select (
        response_payload #>> '{affected_aggregate_ids,recipe_version_id}'
      )::uuid
      from rmvp02a_results
      where result_name = 'copy-locked-version'
    )
  ),
  'copy creates a traceable draft with the source materialized composition'
);

select ok(
  (
    select recipe_version_status = 'DRAFT'
      and source_evidence #>> '{source_kind}' = 'WORKBOOK_IMPORT'
    from atlas_admin.recipe_versions
    where recipe_version_id = (
      select mapping.recipe_version_id
      from atlas_legacy.master_data_mappings mapping
      where mapping.import_batch_id = (
        select (
          response_payload #>> '{affected_aggregate_ids,import_batch_id}'
        )::uuid
        from rmvp02a_results
        where result_name = 'import-valid'
      )
        and mapping.object_type = 'RECIPE_VERSION'
    )
  ),
  'workbook import creates draft-only recipe evidence'
);

select is(
  (
    select array_agg(distinct object_type order by object_type)::text[]
    from atlas_legacy.master_data_mappings
    where import_batch_id = (
      select (
        response_payload #>> '{affected_aggregate_ids,import_batch_id}'
      )::uuid
      from rmvp02a_results
      where result_name = 'import-valid'
    )
  ),
  array[
    'DISH',
    'RECIPE',
    'RECIPE_LINE',
    'RECIPE_VERSION'
  ]::text[],
  'successful draft import writes the four target mappings that exist before validation materializes revisions'
);

select is(
  (
    select response_payload ->> 'error_code'
    from rmvp02a_results
    where result_name = 'denied-read'
  ),
  'CAPABILITY_DENIED',
  'read capability denial fails closed'
);

select is(
  (
    select response_payload ->> 'error_code'
    from rmvp02a_results
    where result_name = 'denied-command'
  ),
  'CAPABILITY_DENIED',
  'write capability denial fails closed'
);

select ok(
  (
    select jsonb_typeof(response_payload #> '{workbench,dishes}') = 'array'
      and jsonb_typeof(
        response_payload #> '{workbench,dish_types}'
      ) = 'array'
      and jsonb_typeof(response_payload #> '{workbench,recipes}') = 'array'
      and jsonb_typeof(
        response_payload #> '{workbench,recipe_versions}'
      ) = 'array'
      and jsonb_path_exists(
        response_payload,
        '$.workbench.dish_types[*] ? (
          @.dish_type_code == "soup"
          && @.dish_type_status == "ACTIVE"
        )'
      )
      and jsonb_path_exists(
        response_payload,
        '$.workbench.dish_types[*] ? (
          @.dish_type_code == "rmvp02a_inactive"
          && @.dish_type_status == "INACTIVE"
        )'
      )
      and jsonb_path_exists(
        response_payload,
        '$.workbench.dishes[*] ? (
          @.dish_code == "rmvp02a-soup"
          && @.dish_type_code == "soup"
          && @.dish_type_name == "Món canh"
        )'
      )
    from rmvp02a_results
    where result_name = 'authorized-read'
  ),
  'authorized read returns the full Dish Type catalog and resolved Dish references'
);

select * from finish();
rollback;
