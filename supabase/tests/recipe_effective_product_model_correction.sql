begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
select no_plan();

grant usage on schema extensions to authenticated;
grant execute on all functions in schema extensions to authenticated;

insert into atlas_core.actors (
  actor_id, actor_type, display_name
) values (
  'd1000000-0000-0000-0000-000000000001',
  'HUMAN',
  'Recipe product-model correction operator'
);

insert into atlas_core.actor_auth_subjects (
  actor_auth_subject_id, actor_id, auth_subject_id
) values (
  'd1000000-0000-0000-0000-000000000002',
  'd1000000-0000-0000-0000-000000000001',
  'd1000000-0000-0000-0000-000000000101'
);

insert into atlas_core.roles (
  role_id, role_code, role_name
) values (
  'd1000000-0000-0000-0000-000000000003',
  'recipe-product-model-correction.operator',
  'Recipe product-model correction operator'
);

insert into atlas_core.role_capabilities (role_id, capability_id)
select 'd1000000-0000-0000-0000-000000000003', capability_id
from atlas_core.capabilities
where capability_code in (
  'master_data.recipe_adjustments.read',
  'master_data.recipes.read',
  'master_data.recipes.write'
);

insert into atlas_core.actor_role_memberships (actor_id, role_id) values (
  'd1000000-0000-0000-0000-000000000001',
  'd1000000-0000-0000-0000-000000000003'
);

insert into atlas_core.actor_scopes (actor_id, scope_kind) values (
  'd1000000-0000-0000-0000-000000000001',
  'GLOBAL'
);

insert into atlas_admin.school_types (
  school_type_id, school_type_code, school_type_name, school_type_status
) values
  (
    'd1100000-0000-0000-0000-000000000001',
    'v1-school-type-1',
    'TIỂU HỌC',
    'ACTIVE'
  ),
  (
    'd1100000-0000-0000-0000-000000000002',
    'v1-school-type-2',
    'TRUNG HỌC',
    'ACTIVE'
  )
on conflict (school_type_code) do update
set school_type_name = excluded.school_type_name,
    school_type_status = excluded.school_type_status;

create temporary table recipe_canonical_types as
select school_type_id, school_type_code
from atlas_admin.school_types
where school_type_code in ('v1-school-type-1', 'v1-school-type-2');
grant select on recipe_canonical_types to authenticated;

insert into atlas_admin.customers (
  customer_id, customer_code, customer_name, customer_type
) values (
  'd1100000-0000-0000-0000-000000000010',
  'recipe-correction-customer',
  'Recipe correction customer',
  'SCHOOL_CATERING'
);

insert into atlas_admin.delivery_locations (
  delivery_location_id, customer_id, location_code, location_name,
  address_text, timezone_name
) values (
  'd1100000-0000-0000-0000-000000000011',
  'd1100000-0000-0000-0000-000000000010',
  'recipe-correction-location',
  'Recipe correction location',
  'Synthetic local address',
  'Asia/Ho_Chi_Minh'
);

insert into atlas_admin.schools (
  school_id, customer_id, school_code, school_name, school_type_id,
  default_delivery_location_id, display_order
) values (
  'd1100000-0000-0000-0000-000000000012',
  'd1100000-0000-0000-0000-000000000010',
  'recipe-correction-school',
  'Recipe correction School',
  (
    select school_type_id from recipe_canonical_types
    where school_type_code = 'v1-school-type-1'
  ),
  'd1100000-0000-0000-0000-000000000011',
  1
);

insert into atlas_admin.units (
  unit_id, unit_code, unit_name, dimension_code, decimal_scale
) values (
  'd1200000-0000-0000-0000-000000000001',
  'recipe-correction-kg',
  'Recipe correction kilogram',
  'MASS',
  3
);

insert into atlas_admin.ingredients (
  ingredient_id, ingredient_code, ingredient_name, ingredient_group,
  purchase_unit_id, ingredient_type, shopping_type, order_step
) values (
  'd1200000-0000-0000-0000-000000000002',
  'recipe-correction-ingredient',
  'Recipe correction ingredient',
  'Food',
  'd1200000-0000-0000-0000-000000000001',
  'Food',
  'Planned',
  1
);

create function pg_temp.recipe_correction_command(
  p_name text,
  p_payload jsonb
)
returns jsonb
language sql
as $$
  select pg_catalog.jsonb_build_object(
    'contract_version', 'RMVP-02A.v1',
    'command_id', pg_catalog.md5('recipe-correction-command:' || p_name)::uuid,
    'correlation_id', 'd1000000-0000-0000-0000-000000000201',
    'idempotency_key', 'recipe-correction:' || p_name,
    'expected_version', 1,
    'requested_by_auth_subject',
      'd1000000-0000-0000-0000-000000000101',
    'requested_at', pg_catalog.transaction_timestamp() - interval '1 second',
    'reason_code', 'RECIPE_PRODUCT_MODEL_CORRECTION_TEST',
    'reason_note', 'Rolled-back Recipe product-model correction test.',
    'payload', p_payload
  );
$$;

create function pg_temp.recipe_correction_read(p_payload jsonb)
returns jsonb
language sql
as $$
  select pg_catalog.jsonb_build_object(
    'contract_version', 'RECIPE-EFFECTIVE.v1',
    'requested_by_auth_subject',
      'd1000000-0000-0000-0000-000000000101',
    'correlation_id', 'd1000000-0000-0000-0000-000000000202',
    'payload', p_payload
  );
$$;

create temporary table recipe_correction_results (
  result_name text primary key,
  response_payload jsonb not null
);
grant select, insert on recipe_correction_results to authenticated;

set local role authenticated;
select pg_catalog.set_config(
  'request.jwt.claim.sub',
  'd1000000-0000-0000-0000-000000000101',
  true
);

insert into recipe_correction_results values (
  'create-dish',
  atlas_api.create_dish(
    pg_temp.recipe_correction_command(
      'create-dish',
      pg_catalog.jsonb_build_object(
        'dish_code', 'recipe-correction-new-dish',
        'dish_name', 'Recipe correction new Dish',
        'dish_type_id', 'd1500000-0000-4000-8000-000000000001'
      )
    )
  )
);

reset role;

select is(
  (
    select response_payload ->> 'success'
    from recipe_correction_results
    where result_name = 'create-dish'
  ),
  'true',
  'create_dish succeeds when both canonical School Types are active'
);

select is(
  (
    select pg_catalog.count(*)
    from atlas_admin.recipes recipe
    where recipe.dish_id = (
      select (response_payload #>> '{affected_aggregate_ids,dish_id}')::uuid
      from recipe_correction_results
      where result_name = 'create-dish'
    )
      and recipe.recipe_status = 'ACTIVE'
  ),
  2::bigint,
  'A. create_dish provisions exactly two active Recipe roots'
);

select is(
  (
    select pg_catalog.count(*)
    from atlas_admin.recipes recipe
    join atlas_admin.school_types school_type
      on school_type.school_type_id = recipe.school_type_id
    where recipe.dish_id = (
      select (response_payload #>> '{affected_aggregate_ids,dish_id}')::uuid
      from recipe_correction_results
      where result_name = 'create-dish'
    )
      and school_type.school_type_code = 'v1-school-type-1'
  ),
  1::bigint,
  'B. exactly one TIỂU HỌC Recipe root exists'
);

select is(
  (
    select pg_catalog.count(*)
    from atlas_admin.recipes recipe
    join atlas_admin.school_types school_type
      on school_type.school_type_id = recipe.school_type_id
    where recipe.dish_id = (
      select (response_payload #>> '{affected_aggregate_ids,dish_id}')::uuid
      from recipe_correction_results
      where result_name = 'create-dish'
    )
      and school_type.school_type_code = 'v1-school-type-2'
  ),
  1::bigint,
  'C. exactly one TRUNG HỌC Recipe root exists'
);

select is(
  (
    select pg_catalog.count(*)
    from atlas_admin.recipe_versions version
    join atlas_admin.recipes recipe on recipe.recipe_id = version.recipe_id
    where recipe.dish_id = (
      select (response_payload #>> '{affected_aggregate_ids,dish_id}')::uuid
      from recipe_correction_results
      where result_name = 'create-dish'
    )
  ),
  0::bigint,
  'create_dish creates no RecipeVersion'
);

select is(
  (
    select pg_catalog.jsonb_array_length(
      response_payload #> '{affected_aggregate_ids,recipe_ids}'
    )
    from recipe_correction_results
    where result_name = 'create-dish'
  ),
  2,
  'create_dish returns both canonical Recipe identities'
);

insert into atlas_admin.dishes (
  dish_id, dish_code, dish_name, dish_status, display_order
) values
  (
    'd1300000-0000-0000-0000-000000000001',
    'recipe-correction-null-fallback',
    'Recipe correction NULL fallback fixture',
    'ACTIVE',
    1
  ),
  (
    'd1300000-0000-0000-0000-000000000002',
    'recipe-correction-root-only',
    'Recipe correction root-only fixture',
    'ACTIVE',
    2
  );

insert into atlas_admin.recipes (
  recipe_id, dish_id, school_type_id
) values
  (
    'd1400000-0000-0000-0000-000000000001',
    'd1300000-0000-0000-0000-000000000001',
    null
  ),
  (
    'd1400000-0000-0000-0000-000000000002',
    'd1300000-0000-0000-0000-000000000002',
    (
      select school_type_id from recipe_canonical_types
      where school_type_code = 'v1-school-type-1'
    )
  );

insert into atlas_admin.recipe_versions (
  recipe_version_id, recipe_id, version_number, basis_portions,
  created_by_actor_id, source_evidence
) values (
  'd1500000-0000-0000-0000-000000000001',
  'd1400000-0000-0000-0000-000000000001',
  1,
  100,
  'd1000000-0000-0000-0000-000000000001',
  '{"source_kind":"RECIPE_PRODUCT_MODEL_CORRECTION_TEST"}'::jsonb
);

insert into atlas_admin.recipe_lines (
  recipe_line_id, recipe_id, line_code
) values (
  'd1600000-0000-0000-0000-000000000001',
  'd1400000-0000-0000-0000-000000000001',
  'recipe-correction-null-line'
);

insert into atlas_admin.recipe_line_revisions (
  recipe_line_revision_id, recipe_id, recipe_version_id, recipe_line_id,
  line_revision_number, ingredient_id, quantity_per_basis, unit_id,
  created_by_actor_id
) values (
  'd1700000-0000-0000-0000-000000000001',
  'd1400000-0000-0000-0000-000000000001',
  'd1500000-0000-0000-0000-000000000001',
  'd1600000-0000-0000-0000-000000000001',
  1,
  'd1200000-0000-0000-0000-000000000002',
  1,
  'd1200000-0000-0000-0000-000000000001',
  'd1000000-0000-0000-0000-000000000001'
);

set constraints all immediate;

update atlas_admin.recipe_versions
set recipe_version_status = 'VALIDATED',
    validated_by_actor_id = 'd1000000-0000-0000-0000-000000000001',
    validated_at = pg_catalog.transaction_timestamp() - interval '2 hours'
where recipe_version_id = 'd1500000-0000-0000-0000-000000000001';

update atlas_admin.recipe_versions
set recipe_version_status = 'RELEASED_FOR_PLANNING',
    released_by_actor_id = 'd1000000-0000-0000-0000-000000000001',
    released_at = pg_catalog.transaction_timestamp() - interval '1 hour'
where recipe_version_id = 'd1500000-0000-0000-0000-000000000001';

set constraints all deferred;

select is(
  atlas_core.recipe_effective_select_base_recipe(
    'd1300000-0000-0000-0000-000000000001',
    (
      select school_type_id from recipe_canonical_types
      where school_type_code = 'v1-school-type-1'
    )
  ) ->> 'status',
  'BLOCKED',
  'D/E. RECIPE-EFFECTIVE never falls back to NULL-general for TIỂU HỌC'
);

select is(
  atlas_core.recipe_effective_select_base_recipe(
    'd1300000-0000-0000-0000-000000000001',
    (
      select school_type_id from recipe_canonical_types
      where school_type_code = 'v1-school-type-2'
    )
  ) ->> 'status',
  'BLOCKED',
  'F. RECIPE-EFFECTIVE never falls back to NULL-general for TRUNG HỌC'
);

set local role authenticated;

insert into recipe_correction_results values (
  'root-only-workbench',
  atlas_api.get_dish_recipe_operator_workbench(
    pg_temp.recipe_correction_read(
      pg_catalog.jsonb_build_object(
        'as_of_date', '2026-09-05',
        'dish_id', 'd1300000-0000-0000-0000-000000000002',
        'school_type_id', (
          select school_type_id from recipe_canonical_types
          where school_type_code = 'v1-school-type-1'
        )
      )
    )
  )
);

reset role;

select is(
  (
    select response_payload #>> '{workbench,editable_state}'
    from recipe_correction_results
    where result_name = 'root-only-workbench'
  ),
  'EDITABLE_BASE',
  'Q. root-only unlocked Recipe is an editable base-authoring context'
);

select is(
  (
    select response_payload #>> '{workbench,is_editable}'
    from recipe_correction_results
    where result_name = 'root-only-workbench'
  ),
  'true',
  'Q. root-only unlocked Recipe remains editable before effective readiness'
);

select is(
  (
    select response_payload #> '{workbench,allowed_actions}'
    from recipe_correction_results
    where result_name = 'root-only-workbench'
  ),
  '[]'::jsonb,
  'Q. copy is not advertised until both canonical target roots exist'
);

insert into atlas_admin.recipe_versions (
  recipe_version_id, recipe_id, version_number, basis_portions,
  recipe_version_status, created_by_actor_id, source_evidence,
  draft_composition
) values (
  'd1500000-0000-0000-0000-000000000002',
  'd1400000-0000-0000-0000-000000000002',
  1,
  100,
  'DRAFT',
  'd1000000-0000-0000-0000-000000000001',
  '{"source_kind":"RECIPE_PRODUCT_MODEL_CORRECTION_TEST"}'::jsonb,
  pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
    'recipe_line_id', 'd1600000-0000-0000-0000-000000000002',
    'predecessor_recipe_line_revision_id', null,
    'ingredient_id', 'd1200000-0000-0000-0000-000000000002',
    'quantity_per_basis', 2,
    'unit_id', 'd1200000-0000-0000-0000-000000000001',
    'line_disposition', 'PRESENT',
    'operational_note', null
  ))
);

insert into atlas_admin.recipe_lines (
  recipe_line_id, recipe_id, line_code
) values (
  'd1600000-0000-0000-0000-000000000002',
  'd1400000-0000-0000-0000-000000000002',
  'recipe-correction-typed-line'
);

insert into atlas_admin.recipe_line_revisions (
  recipe_line_revision_id, recipe_id, recipe_version_id, recipe_line_id,
  line_revision_number, ingredient_id, quantity_per_basis, unit_id,
  created_by_actor_id
) values (
  'd1700000-0000-0000-0000-000000000002',
  'd1400000-0000-0000-0000-000000000002',
  'd1500000-0000-0000-0000-000000000002',
  'd1600000-0000-0000-0000-000000000002',
  1,
  'd1200000-0000-0000-0000-000000000002',
  2,
  'd1200000-0000-0000-0000-000000000001',
  'd1000000-0000-0000-0000-000000000001'
);

set local role authenticated;
insert into recipe_correction_results values (
  'draft-workbench',
  atlas_api.get_dish_recipe_operator_workbench(
    pg_temp.recipe_correction_read(pg_catalog.jsonb_build_object(
      'as_of_date', '2026-09-05',
      'dish_id', 'd1300000-0000-0000-0000-000000000002',
      'school_type_id', (
        select school_type_id from recipe_canonical_types
        where school_type_code = 'v1-school-type-1'
      )
    ))
  )
);
reset role;

select ok(
  (
    select response_payload #>> '{workbench,editable_state}' = 'EDITABLE_BASE'
      and response_payload #>> '{workbench,is_editable}' = 'true'
      and response_payload #>> '{workbench,base_authoring,business_status}' = 'SAVED'
    from recipe_correction_results
    where result_name = 'draft-workbench'
  ),
  'Q. an unlocked DRAFT version remains in editable base authoring'
);

set constraints all immediate;
update atlas_admin.recipe_versions
set recipe_version_status = 'VALIDATED',
    validated_by_actor_id = 'd1000000-0000-0000-0000-000000000001',
    validated_at = pg_catalog.transaction_timestamp()
where recipe_version_id = 'd1500000-0000-0000-0000-000000000002';
set constraints all deferred;

set local role authenticated;
insert into recipe_correction_results values (
  'validated-workbench',
  atlas_api.get_dish_recipe_operator_workbench(
    pg_temp.recipe_correction_read(pg_catalog.jsonb_build_object(
      'as_of_date', '2026-09-05',
      'dish_id', 'd1300000-0000-0000-0000-000000000002',
      'school_type_id', (
        select school_type_id from recipe_canonical_types
        where school_type_code = 'v1-school-type-1'
      )
    ))
  )
);
reset role;

select ok(
  (
    select response_payload #>> '{workbench,editable_state}' = 'EDITABLE_BASE'
      and response_payload #>> '{workbench,is_editable}' = 'true'
    from recipe_correction_results
    where result_name = 'validated-workbench'
  ),
  'Q. an unlocked VALIDATED version remains in editable base authoring'
);

set constraints all immediate;
update atlas_admin.recipe_versions
set recipe_version_status = 'RELEASED_FOR_PLANNING',
    released_by_actor_id = 'd1000000-0000-0000-0000-000000000001',
    released_at = pg_catalog.transaction_timestamp()
where recipe_version_id = 'd1500000-0000-0000-0000-000000000002';
set constraints all deferred;

set local role authenticated;
insert into recipe_correction_results values (
  'released-workbench',
  atlas_api.get_dish_recipe_operator_workbench(
    pg_temp.recipe_correction_read(pg_catalog.jsonb_build_object(
      'as_of_date', '2026-09-05',
      'dish_id', 'd1300000-0000-0000-0000-000000000002',
      'school_type_id', (
        select school_type_id from recipe_canonical_types
        where school_type_code = 'v1-school-type-1'
      )
    ))
  )
);
reset role;

select ok(
  (
    select response_payload #>> '{workbench,editable_state}' = 'EDITABLE_BASE'
      and response_payload #>> '{workbench,is_editable}' = 'true'
      and response_payload #>> '{workbench,effective_readiness,status}' = 'READY'
    from recipe_correction_results
    where result_name = 'released-workbench'
  ),
  'Q. an unlocked released version remains editable and effective-ready'
);

insert into atlas_planning.weekly_menus (
  weekly_menu_id, week_start, week_end, source_type, source_name,
  source_signature, weekly_menu_status, row_count, imported_by_actor_id
) values (
  'd1800000-0000-0000-0000-000000000001',
  '2026-09-07', '2026-09-13', 'TEST', 'Recipe correction lock evidence',
  'recipe-correction-lock', 'DRAFT', 1,
  'd1000000-0000-0000-0000-000000000001'
);

insert into atlas_planning.weekly_menu_lines (
  weekly_menu_line_id, weekly_menu_id, school_id, service_date,
  menu_slot_code, dish_id, created_by_actor_id, updated_by_actor_id
) values (
  'd1800000-0000-0000-0000-000000000002',
  'd1800000-0000-0000-0000-000000000001',
  'd1100000-0000-0000-0000-000000000012', '2026-09-08',
  'soup', 'd1300000-0000-0000-0000-000000000002',
  'd1000000-0000-0000-0000-000000000001',
  'd1000000-0000-0000-0000-000000000001'
);

update atlas_planning.weekly_menus
set weekly_menu_status = 'VALIDATED'
where weekly_menu_id = 'd1800000-0000-0000-0000-000000000001';

insert into atlas_planning.weekly_menu_approval_snapshots (
  weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version,
  approved_by_actor_id, approved_at
) values (
  'd1800000-0000-0000-0000-000000000003',
  'd1800000-0000-0000-0000-000000000001', 1,
  'd1000000-0000-0000-0000-000000000001',
  pg_catalog.transaction_timestamp()
);

insert into atlas_planning.weekly_menu_approval_snapshot_lines (
  weekly_menu_approval_snapshot_line_id,
  weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version,
  weekly_menu_line_id, school_id, service_date, menu_slot_code, dish_id
) values (
  'd1800000-0000-0000-0000-000000000004',
  'd1800000-0000-0000-0000-000000000003',
  'd1800000-0000-0000-0000-000000000001', 1,
  'd1800000-0000-0000-0000-000000000002',
  'd1100000-0000-0000-0000-000000000012', '2026-09-08',
  'soup', 'd1300000-0000-0000-0000-000000000002'
);

set local role authenticated;
insert into recipe_correction_results values (
  'locked-workbench',
  atlas_api.get_dish_recipe_operator_workbench(
    pg_temp.recipe_correction_read(pg_catalog.jsonb_build_object(
      'as_of_date', '2026-09-05',
      'dish_id', 'd1300000-0000-0000-0000-000000000002',
      'school_type_id', (
        select school_type_id from recipe_canonical_types
        where school_type_code = 'v1-school-type-1'
      )
    ))
  )
);
reset role;

select ok(
  (
    select response_payload #>> '{workbench,editable_state}' = 'LOCKED_CHANGE_ORDER'
      and response_payload #>> '{workbench,is_editable}' = 'false'
      and response_payload #> '{workbench,allowed_actions}'
        = '["CREATE_CHANGE_ORDER"]'::jsonb
    from recipe_correction_results
    where result_name = 'locked-workbench'
  ),
  'R. approved-Menu use locks base editing and exposes only Change Order action'
);

select * from finish();
rollback;
