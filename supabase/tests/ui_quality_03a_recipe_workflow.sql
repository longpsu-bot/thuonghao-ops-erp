begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
select no_plan();

grant usage on schema extensions to authenticated;
grant execute on all functions in schema extensions to authenticated;

select is(
  (
    select array_agg(p.proname order by p.proname)::text[]
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
      and p.proname in ('save_recipe', 'release_recipe')
  ),
  array['release_recipe', 'save_recipe']::text[],
  'v2 Save and compatibility Release remain physically callable'
);

select ok(
  (
    select bool_and(
      p.prosecdef
      and p.proconfig = array['search_path=""']::text[]
      and has_function_privilege('authenticated', p.oid, 'EXECUTE')
      and not has_function_privilege('anon', p.oid, 'EXECUTE')
      and not has_function_privilege('service_role', p.oid, 'EXECUTE')
      and r.rolname = 'atlas_master_data_command_runtime'
    )
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    join pg_roles r on r.oid = p.proowner
    where n.nspname = 'atlas_api'
      and p.proname in ('save_recipe', 'release_recipe')
  ),
  'v2 commands retain fixed-path least-privilege runtime ownership'
);

select is(
  (
    select count(*)::integer
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
      and p.proname in (
        'create_recipe_draft',
        'replace_recipe_draft_composition',
        'validate_recipe_version',
        'release_recipe_version_for_planning',
        'create_recipe_successor_version'
      )
      and has_function_privilege('authenticated', p.oid, 'EXECUTE')
  ),
  5,
  'all five v1 lifecycle commands remain physically callable'
);

insert into atlas_core.actors (
  actor_id, actor_type, display_name
) values
  ('f3000000-0000-0000-0000-000000000001', 'HUMAN', '03A operator'),
  ('f3000000-0000-0000-0000-000000000002', 'HUMAN', '03A denied');

insert into atlas_core.actor_auth_subjects (
  actor_auth_subject_id, actor_id, auth_subject_id
) values
  (
    'f3000000-0000-0000-0000-000000000011',
    'f3000000-0000-0000-0000-000000000001',
    'f3000000-0000-0000-0000-000000000101'
  ),
  (
    'f3000000-0000-0000-0000-000000000012',
    'f3000000-0000-0000-0000-000000000002',
    'f3000000-0000-0000-0000-000000000102'
  );

insert into atlas_core.roles (role_id, role_code, role_name) values
  (
    'f3000000-0000-0000-0000-000000000020',
    'uiq03a.recipe_operator',
    '03A Recipe operator'
  ),
  (
    'f3000000-0000-0000-0000-000000000021',
    'uiq03a.no_capability',
    '03A no capability'
  );

insert into atlas_core.role_capabilities (role_id, capability_id)
select 'f3000000-0000-0000-0000-000000000020', capability_id
from atlas_core.capabilities
where capability_code in (
  'master_data.recipes.read',
  'master_data.recipes.write',
  'master_data.recipes.validate',
  'master_data.recipes.release',
  'master_data.recipes.import'
);

insert into atlas_core.actor_role_memberships (actor_id, role_id) values
  (
    'f3000000-0000-0000-0000-000000000001',
    'f3000000-0000-0000-0000-000000000020'
  ),
  (
    'f3000000-0000-0000-0000-000000000002',
    'f3000000-0000-0000-0000-000000000021'
  );

insert into atlas_core.actor_scopes (actor_id, scope_kind) values
  ('f3000000-0000-0000-0000-000000000001', 'GLOBAL'),
  ('f3000000-0000-0000-0000-000000000002', 'GLOBAL');

insert into atlas_admin.school_types (
  school_type_id, school_type_code, school_type_name
) values
  (
    'f3100000-0000-0000-0000-000000000001',
    'uiq03a-primary',
    'UIQ03A Primary'
  ),
  (
    'f3100000-0000-0000-0000-000000000002',
    'uiq03a-secondary',
    'UIQ03A Secondary'
  );

insert into atlas_admin.units (
  unit_id, unit_code, unit_name, dimension_code, decimal_scale
) values (
  'f3100000-0000-0000-0000-000000000010',
  'uiq03a-kg',
  'UIQ03A kilogram',
  'MASS',
  3
);

insert into atlas_admin.ingredients (
  ingredient_id, ingredient_code, ingredient_name, ingredient_group,
  purchase_unit_id, ingredient_type, shopping_type, order_step
) values
  (
    'f3100000-0000-0000-0000-000000000020',
    'uiq03a-pumpkin',
    'UIQ03A Pumpkin',
    'Food',
    'f3100000-0000-0000-0000-000000000010',
    'Food',
    'Planned',
    1
  ),
  (
    'f3100000-0000-0000-0000-000000000021',
    'uiq03a-pork',
    'UIQ03A Pork',
    'Food',
    'f3100000-0000-0000-0000-000000000010',
    'Food',
    'Planned',
    1
  );

insert into atlas_admin.dishes (
  dish_id, dish_code, dish_name, dish_category, dish_status,
  dish_type_id, display_order, requires_need_generation, version
) values (
  'f3100000-0000-0000-0000-000000000030',
  'uiq03a-soup',
  'UIQ03A Soup',
  'Acceptance',
  'ACTIVE',
  'd1500000-0000-4000-8000-000000000001',
  9300,
  true,
  1
);

create or replace function pg_temp.uiq03a_request(
  p_name text,
  p_expected_version bigint,
  p_payload jsonb,
  p_subject uuid default 'f3000000-0000-0000-0000-000000000101',
  p_reason_code text default 'RECIPE_SAVED'
)
returns jsonb
language sql
as $$
  select jsonb_build_object(
    'contract_version', 'RMVP-02A.v2',
    'command_id', md5('uiq03a-command:' || p_name)::uuid,
    'correlation_id', 'f3900000-0000-0000-0000-000000000001',
    'idempotency_key', 'uiq03a:' || p_name,
    'expected_version', p_expected_version,
    'requested_by_auth_subject', p_subject,
    'requested_at', transaction_timestamp() - interval '1 second',
    'reason_code', p_reason_code,
    'reason_note', null,
    'payload', p_payload
  );
$$;

create or replace function pg_temp.uiq03a_v1_request(
  p_name text,
  p_expected_version bigint,
  p_payload jsonb,
  p_reason_code text default 'UIQ03A_TEST'
)
returns jsonb
language sql
as $$
  select jsonb_build_object(
    'contract_version', 'RMVP-02A.v1',
    'command_id', md5('uiq03a-v1-command:' || p_name)::uuid,
    'correlation_id', 'f3900000-0000-0000-0000-000000000003',
    'idempotency_key', 'uiq03a-v1:' || p_name,
    'expected_version', p_expected_version,
    'requested_by_auth_subject',
      'f3000000-0000-0000-0000-000000000101',
    'requested_at', transaction_timestamp() - interval '1 second',
    'reason_code', p_reason_code,
    'reason_note', 'Rolled-back UIQ-03A Dish-wide lock test: ' || p_name,
    'payload', p_payload
  );
$$;

create temporary table uiq03a_results (
  result_name text primary key,
  response_payload jsonb not null
);
grant select, insert on uiq03a_results to authenticated;

create temporary table uiq03a_import_documents (
  document_name text primary key,
  canonical_json text not null,
  checksum text not null
);
grant select on uiq03a_import_documents to authenticated;

insert into uiq03a_import_documents (document_name, canonical_json, checksum)
select document_name, canonical_json, encode(
  extensions.digest(convert_to(canonical_json, 'UTF8'), 'sha256'),
  'hex'
)
from (
  values (
    'locked-dish',
    jsonb_build_object(
      'rows',
      jsonb_build_array(
        jsonb_build_object(
          'legacy_line_id', 'ops-v1:line:uiq03a-soup:pumpkin',
          'dish_legacy_id', 'ops-v1:dish:uiq03a-soup',
          'recipe_legacy_id', 'ops-v1:recipe:uiq03a-soup:general',
          'dish_code', 'uiq03a-soup',
          'dish_name', 'UIQ03A Soup changed by import',
          'dish_category', 'Imported mutation',
          'requires_need_generation', true,
          'school_type_id', null,
          'basis_portions', 100,
          'ingredient_id', 'f3100000-0000-0000-0000-000000000020',
          'quantity_per_basis', 99,
          'unit_id', 'f3100000-0000-0000-0000-000000000010',
          'operational_note', 'must not be imported'
        )
      )
    )::text
  )
) documents(document_name, canonical_json);

create temporary table uiq03a_scope_snapshot as
select
  (select count(*) from atlas_admin.recipe_composition_adjustments)
    as adjustment_count,
  (select count(*) from atlas_procurement.purchase_orders)
    as procurement_count,
  (select count(*) from atlas_dispatch.dispatch_plans)
    as dispatch_count;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f3000000-0000-0000-0000-000000000102',
  true
);
insert into uiq03a_results values (
  'save-denied-capability',
  atlas_api.save_recipe(
    pg_temp.uiq03a_request(
      'save-denied-capability',
      1,
      jsonb_build_object(
        'dish_id', 'f3100000-0000-0000-0000-000000000030',
        'school_type_id', null,
        'recipe_version_id', null,
        'basis_portions', 100,
        'lines', jsonb_build_array(
          jsonb_build_object(
            'recipe_line_id', 'f3200000-0000-0000-0000-000000000001',
            'ingredient_id', 'f3100000-0000-0000-0000-000000000020',
            'quantity_per_basis', 12.5,
            'unit_id', 'f3100000-0000-0000-0000-000000000010',
            'operational_note', null
          )
        )
      ),
      'f3000000-0000-0000-0000-000000000102'
    )
  )
);

select set_config(
  'request.jwt.claim.sub',
  'f3000000-0000-0000-0000-000000000101',
  true
);
insert into uiq03a_results values (
  'save-new',
  atlas_api.save_recipe(
    pg_temp.uiq03a_request(
      'save-new',
      1,
      jsonb_build_object(
        'dish_id', 'f3100000-0000-0000-0000-000000000030',
        'school_type_id', null,
        'recipe_version_id', null,
        'basis_portions', 80,
        'lines', jsonb_build_array(
          jsonb_build_object(
            'recipe_line_id', 'f3200000-0000-0000-0000-000000000001',
            'ingredient_id', 'f3100000-0000-0000-0000-000000000020',
            'quantity_per_basis', 12.5,
            'unit_id', 'f3100000-0000-0000-0000-000000000010',
            'operational_note', 'Initial creation'
          )
        )
      )
    )
  )
);
reset role;

select is(
  (
    select response_payload ->> 'error_code'
    from uiq03a_results where result_name = 'save-denied-capability'
  ),
  'CAPABILITY_DENIED',
  'Save requires the narrow Recipe write capability'
);

select is(
  (
    select response_payload #>> '{authoritative_readback,selected_recipe,business_status}'
    from uiq03a_results where result_name = 'save-new'
  ),
  'AVAILABLE',
  'one creation Save makes an eligible pre-use Recipe available'
);

select is(
  (
    select jsonb_build_object(
      'basis', version.basis_portions,
      'status', version.recipe_version_status,
      'validated', version.validated_at is not null,
      'released', version.released_at is not null,
      'revision_count', (
        select count(*) from atlas_admin.recipe_line_revisions revision
        where revision.recipe_version_id = version.recipe_version_id
      )
    )
    from atlas_admin.recipe_versions version
    join atlas_admin.recipes recipe on recipe.recipe_id = version.recipe_id
    where recipe.dish_id = 'f3100000-0000-0000-0000-000000000030'
  ),
  jsonb_build_object(
    'basis', 80,
    'status', 'RELEASED_FOR_PLANNING',
    'validated', true,
    'released', true,
    'revision_count', 1
  ),
  'Save validates, materializes, and releases for future Planning atomically'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f3000000-0000-0000-0000-000000000101',
  true
);
insert into uiq03a_results
select
  'save-pre-use',
  atlas_api.save_recipe(
    pg_temp.uiq03a_request(
      'save-pre-use',
      (first.response_payload #>> '{authoritative_readback,selected_recipe,expected_version}')::bigint,
      jsonb_build_object(
        'dish_id', 'f3100000-0000-0000-0000-000000000030',
        'school_type_id', null,
        'recipe_version_id',
          first.response_payload #>> '{authoritative_readback,selected_recipe,recipe_version_id}',
        'basis_portions', 90,
        'lines', jsonb_build_array(
          jsonb_build_object(
            'recipe_line_id', 'f3200000-0000-0000-0000-000000000001',
            'ingredient_id', 'f3100000-0000-0000-0000-000000000020',
            'quantity_per_basis', 14,
            'unit_id', 'f3100000-0000-0000-0000-000000000010',
            'operational_note', 'Pre-use correction'
          ),
          jsonb_build_object(
            'recipe_line_id', 'f3200000-0000-0000-0000-000000000002',
            'ingredient_id', 'f3100000-0000-0000-0000-000000000021',
            'quantity_per_basis', 4,
            'unit_id', 'f3100000-0000-0000-0000-000000000010',
            'operational_note', null
          )
        )
      )
    )
  )
from uiq03a_results first
where first.result_name = 'save-new';

insert into uiq03a_results values (
  'setup-create-draft',
  atlas_api.create_recipe_draft(
    pg_temp.uiq03a_v1_request(
      'setup-create-draft',
      1,
      jsonb_build_object(
        'dish_id', 'f3100000-0000-0000-0000-000000000030',
        'school_type_id', 'f3100000-0000-0000-0000-000000000001',
        'basis_portions', 100
      )
    )
  )
);
insert into uiq03a_results
select
  'setup-replace-draft',
  atlas_api.replace_recipe_draft_composition(
    pg_temp.uiq03a_v1_request(
      'setup-replace-draft',
      1,
      jsonb_build_object(
        'recipe_version_id',
          created.response_payload #>> '{affected_aggregate_ids,recipe_version_id}',
        'basis_portions', 100,
        'lines', jsonb_build_array(
          jsonb_build_object(
            'ingredient_id', 'f3100000-0000-0000-0000-000000000020',
            'quantity_per_basis', 10,
            'unit_id', 'f3100000-0000-0000-0000-000000000010',
            'line_disposition', 'PRESENT',
            'operational_note', 'Draft denial fixture',
            'line_code', 'draft-pumpkin'
          )
        )
      )
    )
  )
from uiq03a_results created
where created.result_name = 'setup-create-draft';

insert into uiq03a_results values (
  'setup-create-validated',
  atlas_api.create_recipe_draft(
    pg_temp.uiq03a_v1_request(
      'setup-create-validated',
      1,
      jsonb_build_object(
        'dish_id', 'f3100000-0000-0000-0000-000000000030',
        'school_type_id', 'f3100000-0000-0000-0000-000000000002',
        'basis_portions', 100
      )
    )
  )
);
insert into uiq03a_results
select
  'setup-replace-validated',
  atlas_api.replace_recipe_draft_composition(
    pg_temp.uiq03a_v1_request(
      'setup-replace-validated',
      1,
      jsonb_build_object(
        'recipe_version_id',
          created.response_payload #>> '{affected_aggregate_ids,recipe_version_id}',
        'basis_portions', 100,
        'lines', jsonb_build_array(
          jsonb_build_object(
            'ingredient_id', 'f3100000-0000-0000-0000-000000000021',
            'quantity_per_basis', 8,
            'unit_id', 'f3100000-0000-0000-0000-000000000010',
            'line_disposition', 'PRESENT',
            'operational_note', 'Validated denial fixture',
            'line_code', 'validated-pork'
          )
        )
      )
    )
  )
from uiq03a_results created
where created.result_name = 'setup-create-validated';
insert into uiq03a_results
select
  'setup-validate',
  atlas_api.validate_recipe_version(
    pg_temp.uiq03a_v1_request(
      'setup-validate',
      2,
      jsonb_build_object(
        'recipe_version_id',
          created.response_payload #>> '{affected_aggregate_ids,recipe_version_id}'
      )
    )
  )
from uiq03a_results created
where created.result_name = 'setup-create-validated';
reset role;

select is(
  (
    select jsonb_build_object(
      'versions', count(*),
      'released', count(*) filter (
        where recipe_version_status = 'RELEASED_FOR_PLANNING'
      ),
      'locked_history', count(*) filter (
        where recipe_version_status = 'LOCKED'
      )
    )
    from atlas_admin.recipe_versions version
    join atlas_admin.recipes recipe on recipe.recipe_id = version.recipe_id
    where recipe.dish_id = 'f3100000-0000-0000-0000-000000000030'
  ),
  jsonb_build_object('versions', 4, 'released', 1, 'locked_history', 1),
  'pre-use Save may advance internal lineage while keeping one current release'
);

create temporary table uiq03a_before_lock as
select
  count(*)::integer as version_count,
  jsonb_agg(
    jsonb_build_object(
      'id', version.recipe_version_id,
      'status', version.recipe_version_status,
      'composition', atlas_core.rmvp_02a_recipe_version_composition(
        version.recipe_version_id
      )
    ) order by version.version_number
  ) as recipe_evidence
from atlas_admin.recipe_versions version
join atlas_admin.recipes recipe on recipe.recipe_id = version.recipe_id
where recipe.dish_id = 'f3100000-0000-0000-0000-000000000030';
grant select on uiq03a_before_lock to authenticated;

insert into atlas_admin.customers (
  customer_id, customer_code, customer_name, customer_type
) values (
  'f3300000-0000-0000-0000-000000000001',
  'uiq03a-school-customer',
  'UIQ03A School Customer',
  'SCHOOL_CATERING'
);
insert into atlas_admin.delivery_locations (
  delivery_location_id, customer_id, location_code, location_name, address_text
) values (
  'f3300000-0000-0000-0000-000000000002',
  'f3300000-0000-0000-0000-000000000001',
  'uiq03a-location',
  'UIQ03A Location',
  'Local test only'
);
insert into atlas_admin.schools (
  school_id, customer_id, school_code, school_name, school_type_id,
  default_delivery_location_id
) values (
  'f3300000-0000-0000-0000-000000000003',
  'f3300000-0000-0000-0000-000000000001',
  'uiq03a-school',
  'UIQ03A School',
  'f3100000-0000-0000-0000-000000000001',
  'f3300000-0000-0000-0000-000000000002'
);
insert into atlas_planning.weekly_menus (
  weekly_menu_id, week_start, week_end, source_type, source_name,
  source_signature, weekly_menu_status, row_count, imported_by_actor_id
) values (
  'f3400000-0000-0000-0000-000000000001',
  date '2026-08-10',
  date '2026-08-16',
  'TEST',
  'UIQ03A approved menu evidence',
  'uiq03a-signature',
  'DRAFT',
  1,
  'f3000000-0000-0000-0000-000000000001'
);
insert into atlas_planning.weekly_menu_lines (
  weekly_menu_line_id, weekly_menu_id, school_id, service_date,
  menu_slot_code, dish_id, created_by_actor_id, updated_by_actor_id
) values (
  'f3400000-0000-0000-0000-000000000002',
  'f3400000-0000-0000-0000-000000000001',
  'f3300000-0000-0000-0000-000000000003',
  date '2026-08-11',
  'soup',
  'f3100000-0000-0000-0000-000000000030',
  'f3000000-0000-0000-0000-000000000001',
  'f3000000-0000-0000-0000-000000000001'
);
update atlas_planning.weekly_menus
set weekly_menu_status = 'VALIDATED'
where weekly_menu_id = 'f3400000-0000-0000-0000-000000000001';
insert into atlas_planning.weekly_menu_approval_snapshots (
  weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version,
  approved_by_actor_id, approved_at
) values (
  'f3400000-0000-0000-0000-000000000003',
  'f3400000-0000-0000-0000-000000000001',
  1,
  'f3000000-0000-0000-0000-000000000001',
  transaction_timestamp()
);
insert into atlas_planning.weekly_menu_approval_snapshot_lines (
  weekly_menu_approval_snapshot_line_id,
  weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version,
  weekly_menu_line_id, school_id, service_date, menu_slot_code, dish_id
) values (
  'f3400000-0000-0000-0000-000000000004',
  'f3400000-0000-0000-0000-000000000003',
  'f3400000-0000-0000-0000-000000000001',
  1,
  'f3400000-0000-0000-0000-000000000002',
  'f3300000-0000-0000-0000-000000000003',
  date '2026-08-11',
  'soup',
  'f3100000-0000-0000-0000-000000000030'
);

create temporary table uiq03a_lock_targets as
select
  dish.version as dish_version,
  general.recipe_id as general_recipe_id,
  general.version as general_recipe_version,
  released.recipe_version_id as released_version_id,
  released.version as released_version,
  draft.recipe_id as draft_recipe_id,
  draft.recipe_version_id as draft_version_id,
  draft.version as draft_version,
  validated.recipe_id as validated_recipe_id,
  validated.recipe_version_id as validated_version_id,
  validated.version as validated_version
from atlas_admin.dishes dish
join atlas_admin.recipes general
  on general.dish_id = dish.dish_id
  and general.school_type_id is null
join atlas_admin.recipe_versions released
  on released.recipe_id = general.recipe_id
  and released.recipe_version_status = 'RELEASED_FOR_PLANNING'
join atlas_admin.recipes draft_recipe
  on draft_recipe.dish_id = dish.dish_id
  and draft_recipe.school_type_id = 'f3100000-0000-0000-0000-000000000001'
join atlas_admin.recipe_versions draft
  on draft.recipe_id = draft_recipe.recipe_id
  and draft.recipe_version_status = 'DRAFT'
join atlas_admin.recipes validated_recipe
  on validated_recipe.dish_id = dish.dish_id
  and validated_recipe.school_type_id = 'f3100000-0000-0000-0000-000000000002'
join atlas_admin.recipe_versions validated
  on validated.recipe_id = validated_recipe.recipe_id
  and validated.recipe_version_status = 'VALIDATED'
where dish.dish_id = 'f3100000-0000-0000-0000-000000000030';
grant select on uiq03a_lock_targets to authenticated;

create temporary table uiq03a_locked_business_baseline as
select jsonb_build_object(
  'dish', (
    select to_jsonb(dish)
    from atlas_admin.dishes dish
    where dish.dish_id = 'f3100000-0000-0000-0000-000000000030'
  ),
  'recipes', (
    select jsonb_agg(to_jsonb(recipe) order by recipe.recipe_id)
    from atlas_admin.recipes recipe
    where recipe.dish_id = 'f3100000-0000-0000-0000-000000000030'
  ),
  'versions', (
    select jsonb_agg(to_jsonb(rv) order by rv.recipe_version_id)
    from atlas_admin.recipe_versions rv
    join atlas_admin.recipes recipe on recipe.recipe_id = rv.recipe_id
    where recipe.dish_id = 'f3100000-0000-0000-0000-000000000030'
  ),
  'lines', (
    select jsonb_agg(to_jsonb(line) order by line.recipe_line_id)
    from atlas_admin.recipe_lines line
    join atlas_admin.recipes recipe on recipe.recipe_id = line.recipe_id
    where recipe.dish_id = 'f3100000-0000-0000-0000-000000000030'
  ),
  'line_revisions', (
    select jsonb_agg(to_jsonb(revision) order by revision.recipe_line_revision_id)
    from atlas_admin.recipe_line_revisions revision
    join atlas_admin.recipe_versions rv
      on rv.recipe_version_id = revision.recipe_version_id
    join atlas_admin.recipes recipe on recipe.recipe_id = rv.recipe_id
    where recipe.dish_id = 'f3100000-0000-0000-0000-000000000030'
  ),
  'adjustment_count', (
    select count(*) from atlas_admin.recipe_composition_adjustments
  ),
  'import_batch_count', (select count(*) from atlas_legacy.import_batches),
  'mapping_count', (select count(*) from atlas_legacy.master_data_mappings),
  'approval_evidence', (
    select jsonb_agg(to_jsonb(line) order by line.weekly_menu_approval_snapshot_line_id)
    from atlas_planning.weekly_menu_approval_snapshot_lines line
    where line.dish_id = 'f3100000-0000-0000-0000-000000000030'
  )
) as business_state;
grant select on uiq03a_locked_business_baseline to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'f3000000-0000-0000-0000-000000000101',
  true
);
insert into uiq03a_results values (
  'read-locked',
  atlas_api.get_dish_recipe_workbench(
    jsonb_build_object(
      'contract_version', 'RMVP-02A.v2',
      'requested_by_auth_subject',
        'f3000000-0000-0000-0000-000000000101',
      'correlation_id', 'f3900000-0000-0000-0000-000000000002',
      'payload', jsonb_build_object(
        'dish_id', 'f3100000-0000-0000-0000-000000000030',
        'school_type_id', null
      )
    )
  )
);
insert into uiq03a_results
select
  'save-locked',
  atlas_api.save_recipe(
    pg_temp.uiq03a_request(
      'save-locked',
      (used.response_payload #>> '{workbench,selected_recipe,expected_version}')::bigint,
      jsonb_build_object(
        'dish_id', 'f3100000-0000-0000-0000-000000000030',
        'school_type_id', null,
        'recipe_version_id',
          used.response_payload #>> '{workbench,selected_recipe,recipe_version_id}',
        'basis_portions', 100,
        'lines', jsonb_build_array(
          jsonb_build_object(
            'recipe_line_id', 'f3200000-0000-0000-0000-000000000001',
            'ingredient_id', 'f3100000-0000-0000-0000-000000000020',
            'quantity_per_basis', 99,
            'unit_id', 'f3100000-0000-0000-0000-000000000010',
            'operational_note', 'must not be written'
          )
        )
      )
    )
  )
from uiq03a_results used
where used.result_name = 'read-locked';

insert into uiq03a_results
select 'update-dish-locked', atlas_api.update_dish(
  pg_temp.uiq03a_v1_request(
    'update-dish-locked', target.dish_version,
    jsonb_build_object(
      'dish_id', 'f3100000-0000-0000-0000-000000000030',
      'dish_code', 'uiq03a-soup',
      'dish_name', 'UIQ03A Soup must not change',
      'dish_category', 'Acceptance',
      'dish_type_id', 'd1500000-0000-4000-8000-000000000001',
      'operational_notes', 'must not be written',
      'display_order', 9300,
      'requires_need_generation', true
    )
  )
)
from uiq03a_lock_targets target;

insert into uiq03a_results
select 'set-dish-lifecycle-locked', atlas_api.set_dish_lifecycle(
  pg_temp.uiq03a_v1_request(
    'set-dish-lifecycle-locked', target.dish_version,
    jsonb_build_object(
      'dish_id', 'f3100000-0000-0000-0000-000000000030',
      'dish_status', 'INACTIVE'
    )
  )
)
from uiq03a_lock_targets target;

insert into uiq03a_results
select 'set-recipe-lifecycle-locked', atlas_api.set_recipe_lifecycle(
  pg_temp.uiq03a_v1_request(
    'set-recipe-lifecycle-locked', target.general_recipe_version,
    jsonb_build_object(
      'recipe_id', target.general_recipe_id,
      'recipe_status', 'INACTIVE'
    )
  )
)
from uiq03a_lock_targets target;

insert into uiq03a_results
select 'create-draft-locked', atlas_api.create_recipe_draft(
  pg_temp.uiq03a_v1_request(
    'create-draft-locked', target.dish_version,
    jsonb_build_object(
      'dish_id', 'f3100000-0000-0000-0000-000000000030',
      'school_type_id', null,
      'basis_portions', 100
    )
  )
)
from uiq03a_lock_targets target;

insert into uiq03a_results
select 'create-successor-locked', atlas_api.create_recipe_successor_version(
  pg_temp.uiq03a_v1_request(
    'create-successor-locked', target.released_version,
    jsonb_build_object('recipe_version_id', target.released_version_id)
  )
)
from uiq03a_lock_targets target;

insert into uiq03a_results
select 'replace-composition-locked', atlas_api.replace_recipe_draft_composition(
  pg_temp.uiq03a_v1_request(
    'replace-composition-locked', target.draft_version,
    jsonb_build_object(
      'recipe_version_id', target.draft_version_id,
      'basis_portions', 100,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'ingredient_id', 'f3100000-0000-0000-0000-000000000020',
          'quantity_per_basis', 99,
          'unit_id', 'f3100000-0000-0000-0000-000000000010',
          'line_disposition', 'PRESENT',
          'operational_note', 'must not replace composition',
          'line_code', 'draft-pumpkin'
        )
      )
    )
  )
)
from uiq03a_lock_targets target;

insert into uiq03a_results
select 'validate-locked', atlas_api.validate_recipe_version(
  pg_temp.uiq03a_v1_request(
    'validate-locked', target.draft_version,
    jsonb_build_object('recipe_version_id', target.draft_version_id)
  )
)
from uiq03a_lock_targets target;

insert into uiq03a_results
select 'release-v1-locked', atlas_api.release_recipe_version_for_planning(
  pg_temp.uiq03a_v1_request(
    'release-v1-locked', target.validated_version,
    jsonb_build_object('recipe_version_id', target.validated_version_id)
  )
)
from uiq03a_lock_targets target;

insert into uiq03a_results
select 'release-v2-locked', atlas_api.release_recipe(
  pg_temp.uiq03a_request(
    'release-v2-locked', target.draft_version,
    jsonb_build_object('recipe_version_id', target.draft_version_id),
    'f3000000-0000-0000-0000-000000000101',
    'RECIPE_PUT_INTO_USE'
  )
)
from uiq03a_lock_targets target;

insert into uiq03a_results
select 'copy-locked', atlas_api.copy_recipe_version(
  pg_temp.uiq03a_v1_request(
    'copy-locked', target.dish_version,
    jsonb_build_object(
      'source_recipe_version_id', target.released_version_id,
      'target_dish_id', 'f3100000-0000-0000-0000-000000000030',
      'target_school_type_id', null
    )
  )
)
from uiq03a_lock_targets target;

insert into uiq03a_results
select 'import-locked', atlas_api.apply_recipe_import(
  pg_temp.uiq03a_v1_request(
    'import-locked', target.dish_version,
    jsonb_build_object(
      'canonical_json', document.canonical_json,
      'workbook_checksum', document.checksum
    )
  )
)
from uiq03a_lock_targets target
cross join uiq03a_import_documents document
where document.document_name = 'locked-dish';
reset role;

select is(
  (
    select response_payload #>> '{workbench,selected_recipe,business_status}'
    from uiq03a_results where result_name = 'read-locked'
  ),
  'LOCKED',
  'authoritative readback marks the operationally used Dish locked'
);

select is(
  (
    select response_payload #>> '{workbench,selected_recipe,disabled_reason_codes,save_recipe}'
    from uiq03a_results where result_name = 'read-locked'
  ),
  'SAVE_OPERATIONALLY_LOCKED',
  'readback denies normal Save with the specific lock reason code'
);

select is(
  (
    select response_payload ->> 'safe_message'
    from uiq03a_results where result_name = 'save-locked'
  ),
  'Món này đã có trong thực đơn đã duyệt. Muốn thay đổi công thức, hãy dùng Điều chỉnh.',
  'locked Save returns a safe Vietnamese Change Order direction'
);

select is(
  (
    select count(*)::integer
    from uiq03a_results result
    where result.result_name in (
      'save-locked',
      'update-dish-locked',
      'set-dish-lifecycle-locked',
      'set-recipe-lifecycle-locked',
      'create-draft-locked',
      'create-successor-locked',
      'replace-composition-locked',
      'validate-locked',
      'release-v1-locked',
      'release-v2-locked',
      'copy-locked',
      'import-locked'
    )
      and (
        result.response_payload ->> 'error_code' is distinct from
          'INVARIANT_VIOLATION'
        or result.response_payload ->> 'safe_message' is distinct from
          'Món này đã có trong thực đơn đã duyệt. Muốn thay đổi công thức, hãy dùng Điều chỉnh.'
      )
  ),
  0,
  'every Dish and Recipe base mutation returns the canonical approved-menu denial'
);

select is(
  (
    select jsonb_build_object(
      'version_count', count(*),
      'recipe_evidence', jsonb_agg(
        jsonb_build_object(
          'id', version.recipe_version_id,
          'status', version.recipe_version_status,
          'composition', atlas_core.rmvp_02a_recipe_version_composition(
            version.recipe_version_id
          )
        ) order by version.version_number
      )
    )
    from atlas_admin.recipe_versions version
    join atlas_admin.recipes recipe on recipe.recipe_id = version.recipe_id
    where recipe.dish_id = 'f3100000-0000-0000-0000-000000000030'
  ),
  (
    select jsonb_build_object(
      'version_count', version_count,
      'recipe_evidence', recipe_evidence
    )
    from uiq03a_before_lock
  ),
  'locked Save creates no successor and changes no immutable Recipe evidence'
);

select is(
  jsonb_build_object(
    'dish', (
      select to_jsonb(dish)
      from atlas_admin.dishes dish
      where dish.dish_id = 'f3100000-0000-0000-0000-000000000030'
    ),
    'recipes', (
      select jsonb_agg(to_jsonb(recipe) order by recipe.recipe_id)
      from atlas_admin.recipes recipe
      where recipe.dish_id = 'f3100000-0000-0000-0000-000000000030'
    ),
    'versions', (
      select jsonb_agg(to_jsonb(rv) order by rv.recipe_version_id)
      from atlas_admin.recipe_versions rv
      join atlas_admin.recipes recipe on recipe.recipe_id = rv.recipe_id
      where recipe.dish_id = 'f3100000-0000-0000-0000-000000000030'
    ),
    'lines', (
      select jsonb_agg(to_jsonb(line) order by line.recipe_line_id)
      from atlas_admin.recipe_lines line
      join atlas_admin.recipes recipe on recipe.recipe_id = line.recipe_id
      where recipe.dish_id = 'f3100000-0000-0000-0000-000000000030'
    ),
    'line_revisions', (
      select jsonb_agg(to_jsonb(revision) order by revision.recipe_line_revision_id)
      from atlas_admin.recipe_line_revisions revision
      join atlas_admin.recipe_versions rv
        on rv.recipe_version_id = revision.recipe_version_id
      join atlas_admin.recipes recipe on recipe.recipe_id = rv.recipe_id
      where recipe.dish_id = 'f3100000-0000-0000-0000-000000000030'
    ),
    'adjustment_count', (
      select count(*) from atlas_admin.recipe_composition_adjustments
    ),
    'import_batch_count', (select count(*) from atlas_legacy.import_batches),
    'mapping_count', (select count(*) from atlas_legacy.master_data_mappings),
    'approval_evidence', (
      select jsonb_agg(to_jsonb(line) order by line.weekly_menu_approval_snapshot_line_id)
      from atlas_planning.weekly_menu_approval_snapshot_lines line
      where line.dish_id = 'f3100000-0000-0000-0000-000000000030'
    )
  ),
  (
    select business_state from uiq03a_locked_business_baseline
  ),
  'all denied mutation paths leave Dish, Recipe, BOM, import, Adjustment, and approval evidence unchanged'
);

select is(
  (
    select count(*)::integer
    from atlas_planning.weekly_menu_approval_snapshot_lines
    where dish_id = 'f3100000-0000-0000-0000-000000000030'
  ),
  1,
  'locked Save leaves the authoritative approved Menu evidence unchanged'
);

select is(
  (
    select jsonb_build_object(
      'adjustments',
        (select count(*) from atlas_admin.recipe_composition_adjustments),
      'procurement',
        (select count(*) from atlas_procurement.purchase_orders),
      'dispatch',
        (select count(*) from atlas_dispatch.dispatch_plans)
    )
  ),
  (
    select jsonb_build_object(
      'adjustments', adjustment_count,
      'procurement', procurement_count,
      'dispatch', dispatch_count
    )
    from uiq03a_scope_snapshot
  ),
  'creation Save changes no Adjustment, Procurement, or Dispatch behavior'
);

select * from finish();
rollback;
