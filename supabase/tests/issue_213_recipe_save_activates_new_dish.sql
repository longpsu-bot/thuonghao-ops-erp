begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
select no_plan();

grant usage on schema extensions to authenticated;
grant execute on all functions in schema extensions to authenticated;

insert into atlas_core.actors (
  actor_id, actor_type, display_name
) values (
  '21300000-0000-4000-8000-000000000001',
  'HUMAN',
  'Issue 213 Recipe operator'
);

insert into atlas_core.actor_auth_subjects (
  actor_auth_subject_id, actor_id, auth_subject_id
) values (
  '21300000-0000-4000-8000-000000000002',
  '21300000-0000-4000-8000-000000000001',
  '21300000-0000-4000-8000-000000000003'
);

insert into atlas_core.roles (
  role_id, role_code, role_name
) values (
  '21300000-0000-4000-8000-000000000004',
  'issue213.recipe_operator',
  'Issue 213 Recipe operator'
);

insert into atlas_core.role_capabilities (role_id, capability_id)
select '21300000-0000-4000-8000-000000000004', capability_id
from atlas_core.capabilities
where capability_code in (
  'master_data.recipes.read',
  'master_data.recipes.write',
  'planning.inputs.read'
);

insert into atlas_core.actor_role_memberships (
  actor_id, role_id
) values (
  '21300000-0000-4000-8000-000000000001',
  '21300000-0000-4000-8000-000000000004'
);

insert into atlas_core.actor_scopes (
  actor_id, scope_kind
) values (
  '21300000-0000-4000-8000-000000000001',
  'GLOBAL'
);

insert into atlas_admin.units (
  unit_id, unit_code, unit_name, dimension_code, decimal_scale
) values (
  '21310000-0000-4000-8000-000000000001',
  'issue213-kg',
  'Issue 213 kilogram',
  'MASS',
  3
);

insert into atlas_admin.ingredients (
  ingredient_id, ingredient_code, ingredient_name, ingredient_group,
  purchase_unit_id, ingredient_type, shopping_type, order_step
) values (
  '21310000-0000-4000-8000-000000000002',
  'issue213-chicken',
  'Issue 213 chicken',
  'Food',
  '21310000-0000-4000-8000-000000000001',
  'Food',
  'Planned',
  1
);

insert into atlas_admin.customers (
  customer_id, customer_code, customer_name, customer_type
) values (
  '21310000-0000-4000-8000-000000000003',
  'issue213-customer',
  'Issue 213 customer',
  'SCHOOL_CATERING'
);

insert into atlas_admin.delivery_locations (
  delivery_location_id, customer_id, location_code, location_name, address_text
) values (
  '21310000-0000-4000-8000-000000000004',
  '21310000-0000-4000-8000-000000000003',
  'issue213-location',
  'Issue 213 location',
  'Local rolled-back regression'
);

insert into atlas_admin.school_types (
  school_type_id, school_type_code, school_type_name
) values (
  '21310000-0000-4000-8000-000000000005',
  'issue213-school-type',
  'Issue 213 school type'
);

insert into atlas_admin.schools (
  school_id, customer_id, school_code, school_name, school_type_id,
  default_delivery_location_id, default_student_portions,
  default_teacher_portions
) values (
  '21310000-0000-4000-8000-000000000006',
  '21310000-0000-4000-8000-000000000003',
  'issue213-school',
  'Issue 213 school',
  '21310000-0000-4000-8000-000000000005',
  '21310000-0000-4000-8000-000000000004',
  100,
  10
);

insert into atlas_admin.dish_types (
  dish_type_id, dish_type_code, dish_type_name, display_order
) values (
  '21310000-0000-4000-8000-000000000007',
  'issue213_inactive_type',
  'Issue 213 inactive type',
  213
);

create or replace function pg_temp.issue213_v1_request(
  p_name text,
  p_expected_version bigint,
  p_payload jsonb
)
returns jsonb
language sql
as $$
  select pg_catalog.jsonb_build_object(
    'contract_version', 'RMVP-02A.v1',
    'command_id', pg_catalog.md5('issue213-v1-command:' || p_name)::uuid,
    'correlation_id', '21390000-0000-4000-8000-000000000001',
    'idempotency_key', 'issue213-v1:' || p_name,
    'expected_version', p_expected_version,
    'requested_by_auth_subject', '21300000-0000-4000-8000-000000000003',
    'requested_at', pg_catalog.transaction_timestamp() - interval '1 second',
    'reason_code', 'ISSUE_213_TEST',
    'reason_note', 'Rolled-back Issue 213 regression: ' || p_name,
    'payload', p_payload
  );
$$;

create or replace function pg_temp.issue213_save_request(
  p_name text,
  p_expected_version bigint,
  p_dish_id uuid,
  p_line_id uuid,
  p_ingredient_id uuid default
    '21310000-0000-4000-8000-000000000002'
)
returns jsonb
language sql
as $$
  select pg_catalog.jsonb_build_object(
    'contract_version', 'RMVP-02A.v2',
    'command_id', pg_catalog.md5('issue213-command:' || p_name)::uuid,
    'correlation_id', '21390000-0000-4000-8000-000000000002',
    'idempotency_key', 'issue213:' || p_name,
    'expected_version', p_expected_version,
    'requested_by_auth_subject', '21300000-0000-4000-8000-000000000003',
    'requested_at', pg_catalog.transaction_timestamp() - interval '1 second',
    'reason_code', 'RECIPE_SAVED',
    'reason_note', null,
    'payload', pg_catalog.jsonb_build_object(
      'dish_id', p_dish_id,
      'school_type_id', null,
      'recipe_version_id', null,
      'basis_portions', 100,
      'lines', pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'recipe_line_id', p_line_id,
          'ingredient_id', p_ingredient_id,
          'quantity_per_basis', 10,
          'unit_id', '21310000-0000-4000-8000-000000000001',
          'operational_note', 'Issue 213 valid composition'
        )
      )
    )
  );
$$;

create or replace function pg_temp.issue213_menu_read(
  p_dish_id uuid
)
returns jsonb
language sql
as $$
  select pg_catalog.jsonb_build_object(
    'contract_version', 'RMVP-03A.v1',
    'requested_by_auth_subject', '21300000-0000-4000-8000-000000000003',
    'correlation_id', '21390000-0000-4000-8000-000000000003',
    'payload', pg_catalog.jsonb_build_object(
      'week_start', '2026-08-24',
      'rows', pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'school_id', '21310000-0000-4000-8000-000000000006',
          'service_date', '2026-08-24',
          'menu_slot_code', 'soup',
          'dish_id', p_dish_id,
          'source_row_reference', 'issue213:1'
        )
      )
    )
  );
$$;

create temporary table issue213_results (
  result_name text primary key,
  response_payload jsonb not null
);
grant select, insert on issue213_results to authenticated;

create or replace function pg_temp.issue213_created_dish_id(
  p_fixture text
)
returns uuid
language sql
stable
as $$
  select (response_payload #>> '{affected_aggregate_ids,dish_id}')::uuid
  from issue213_results
  where result_name = 'create-' || p_fixture;
$$;

create temporary table issue213_downstream_before as
select pg_catalog.jsonb_build_object(
  'weekly_menus', (select count(*) from atlas_planning.weekly_menus),
  'need_generation_runs',
    (select count(*) from atlas_planning.need_generation_runs),
  'confirmed_need_batches',
    (select count(*) from atlas_planning.confirmed_need_batches),
  'confirmed_need_releases',
    (select count(*) from atlas_planning.confirmed_need_releases),
  'purchase_handoffs',
    (select count(*) from atlas_planning.purchase_handoff_batches),
  'purchase_orders',
    (select count(*) from atlas_procurement.purchase_orders),
  'receiving_evidence',
    (select count(*) from atlas_evidence.supplier_receiving_evidence),
  'dispatch_plans',
    (select count(*) from atlas_dispatch.dispatch_plans)
) as fact_counts;
grant select on issue213_downstream_before to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '21300000-0000-4000-8000-000000000003',
  true
);

insert into issue213_results
select
  'create-' || fixture.fixture_name,
  atlas_api.create_dish(
    pg_temp.issue213_v1_request(
      'create-' || fixture.fixture_name,
      1,
      pg_catalog.jsonb_build_object(
        'dish_code', 'issue213-' || fixture.fixture_name,
        'dish_name', fixture.dish_name,
        'dish_category', 'Regression',
        'dish_type_id', fixture.dish_type_id,
        'operational_notes', 'Rolled-back Issue 213 fixture',
        'display_order', fixture.display_order,
        'requires_need_generation', true
      ) - case when fixture.fixture_name = 'primary'
        then array['dish_code', 'display_order', 'requires_need_generation']
        else array[]::text[] end
    )
  )
from (
  values
    ('primary', 'Issue 213 primary', 'd1500000-0000-4000-8000-000000000001'::uuid, 21301),
    ('stale', 'Issue 213 stale', 'd1500000-0000-4000-8000-000000000001'::uuid, 21302),
    ('invalid', 'Issue 213 invalid', 'd1500000-0000-4000-8000-000000000001'::uuid, 21303),
    ('active', 'Issue 213 active', 'd1500000-0000-4000-8000-000000000001'::uuid, 21304),
    ('inactive', 'Issue 213 inactive', 'd1500000-0000-4000-8000-000000000001'::uuid, 21305),
    ('inactive-type', 'Issue 213 inactive type', '21310000-0000-4000-8000-000000000007'::uuid, 21306),
    ('duplicate-active', 'Issue 213 Duplicate', 'd1500000-0000-4000-8000-000000000001'::uuid, 21307),
    ('duplicate-draft', '  issue 213 duplicate  ', 'd1500000-0000-4000-8000-000000000001'::uuid, 21308)
) fixture(fixture_name, dish_name, dish_type_id, display_order);

reset role;

select is(
  (
    select count(*)::integer
    from issue213_results
    where result_name like 'create-%'
      and response_payload -> 'success' = 'true'::jsonb
  ),
  8,
  'actual create_dish path creates every Issue 213 fixture successfully'
);

select is(
  (
    select count(*)::integer
    from atlas_admin.dishes
    where dish_id in (
      select (response_payload #>> '{affected_aggregate_ids,dish_id}')::uuid
      from issue213_results where result_name like 'create-%'
    )
      and dish_status = 'DRAFT'
      and version = 1
  ),
  8,
  'create_dish leaves every new Dish DRAFT at version 1'
);

update atlas_admin.dish_types
set dish_type_status = 'INACTIVE',
    version = version + 1,
    updated_at = pg_catalog.transaction_timestamp()
where dish_type_id = '21310000-0000-4000-8000-000000000007';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '21300000-0000-4000-8000-000000000003',
  true
);

insert into issue213_results values (
  'primary-save',
  atlas_api.save_recipe(
    pg_temp.issue213_save_request(
      'primary-save',
      1,
      pg_temp.issue213_created_dish_id('primary'),
      '21320000-0000-4000-8000-000000000001'
    )
  )
);

insert into issue213_results values (
  'primary-replay',
  atlas_api.save_recipe(
    pg_temp.issue213_save_request(
      'primary-save',
      1,
      pg_temp.issue213_created_dish_id('primary'),
      '21320000-0000-4000-8000-000000000001'
    )
  )
);

insert into issue213_results values (
  'stale-save',
  atlas_api.save_recipe(
    pg_temp.issue213_save_request(
      'stale-save',
      2,
      pg_temp.issue213_created_dish_id('stale'),
      '21320000-0000-4000-8000-000000000002'
    )
  )
);

insert into issue213_results values (
  'invalid-save',
  atlas_api.save_recipe(
    pg_temp.issue213_save_request(
      'invalid-save',
      1,
      pg_temp.issue213_created_dish_id('invalid'),
      '21320000-0000-4000-8000-000000000003',
      '21310000-0000-4000-8000-000000000099'
    )
  )
);

insert into issue213_results values (
  'activate-existing',
  atlas_api.set_dish_lifecycle(
    pg_temp.issue213_v1_request(
      'activate-existing',
      1,
      pg_catalog.jsonb_build_object(
        'dish_id', pg_temp.issue213_created_dish_id('active'),
        'dish_status', 'ACTIVE'
      )
    )
  )
);

insert into issue213_results values (
  'active-save',
  atlas_api.save_recipe(
    pg_temp.issue213_save_request(
      'active-save',
      2,
      pg_temp.issue213_created_dish_id('active'),
      '21320000-0000-4000-8000-000000000004'
    )
  )
);

insert into issue213_results values (
  'activate-inactive',
  atlas_api.set_dish_lifecycle(
    pg_temp.issue213_v1_request(
      'activate-inactive',
      1,
      pg_catalog.jsonb_build_object(
        'dish_id', pg_temp.issue213_created_dish_id('inactive'),
        'dish_status', 'ACTIVE'
      )
    )
  )
);

insert into issue213_results values (
  'deactivate-inactive',
  atlas_api.set_dish_lifecycle(
    pg_temp.issue213_v1_request(
      'deactivate-inactive',
      2,
      pg_catalog.jsonb_build_object(
        'dish_id', pg_temp.issue213_created_dish_id('inactive'),
        'dish_status', 'INACTIVE'
      )
    )
  )
);

insert into issue213_results values (
  'inactive-save',
  atlas_api.save_recipe(
    pg_temp.issue213_save_request(
      'inactive-save',
      3,
      pg_temp.issue213_created_dish_id('inactive'),
      '21320000-0000-4000-8000-000000000005'
    )
  )
);

insert into issue213_results values (
  'inactive-type-save',
  atlas_api.save_recipe(
    pg_temp.issue213_save_request(
      'inactive-type-save',
      1,
      pg_temp.issue213_created_dish_id('inactive-type'),
      '21320000-0000-4000-8000-000000000006'
    )
  )
);

insert into issue213_results values (
  'activate-duplicate-existing',
  atlas_api.set_dish_lifecycle(
    pg_temp.issue213_v1_request(
      'activate-duplicate-existing',
      1,
      pg_catalog.jsonb_build_object(
        'dish_id', pg_temp.issue213_created_dish_id('duplicate-active'),
        'dish_status', 'ACTIVE'
      )
    )
  )
);

insert into issue213_results values (
  'duplicate-name-save',
  atlas_api.save_recipe(
    pg_temp.issue213_save_request(
      'duplicate-name-save',
      1,
      pg_temp.issue213_created_dish_id('duplicate-draft'),
      '21320000-0000-4000-8000-000000000007'
    )
  )
);

insert into issue213_results values (
  'menu-preview',
  atlas_api.preview_weekly_menu_import(
    pg_temp.issue213_menu_read(
      pg_temp.issue213_created_dish_id('primary')
    )
  )
);

insert into issue213_results values (
  'inactive-menu-preview',
  atlas_api.preview_weekly_menu_import(
    pg_temp.issue213_menu_read(pg_temp.issue213_created_dish_id('inactive'))
  )
);

reset role;

select is(
  (
    select pg_catalog.jsonb_build_object(
      'dish_status', dish.dish_status,
      'dish_version', dish.version,
      'recipe_status', recipe.recipe_status,
      'recipe_version_status', version.recipe_version_status,
      'basis_portions', version.basis_portions,
      'line_count', (
        select count(*) from atlas_admin.recipe_line_revisions revision
        where revision.recipe_version_id = version.recipe_version_id
          and revision.line_disposition = 'PRESENT'
          and revision.ingredient_id =
            '21310000-0000-4000-8000-000000000002'
          and revision.quantity_per_basis = 10
          and revision.unit_id =
            '21310000-0000-4000-8000-000000000001'
      )
    )
    from atlas_admin.dishes dish
    join atlas_admin.recipes recipe on recipe.dish_id = dish.dish_id
      and recipe.school_type_id is null
    join atlas_admin.recipe_versions version
      on version.recipe_id = recipe.recipe_id
    where dish.dish_id = pg_temp.issue213_created_dish_id('primary')
  ),
  pg_catalog.jsonb_build_object(
    'dish_status', 'ACTIVE',
    'dish_version', 2,
    'recipe_status', 'ACTIVE',
    'recipe_version_status', 'RELEASED_FOR_PLANNING',
    'basis_portions', 100,
    'line_count', 1
  ),
  'one normal Save atomically activates Dish 1 to 2 and releases valid Recipe composition'
);

select ok(
  (
    select response_payload #>> '{new_versions,dish_version}' = '2'
      and response_payload
        #>> '{authoritative_readback,selected_recipe,business_status}'
        = 'AVAILABLE'
      and pg_catalog.jsonb_path_exists(
        response_payload,
        '$.authoritative_readback.dishes[*] ? (
          @.dish_name == "Issue 213 primary"
          && @.dish_status == "ACTIVE"
          && @.version == 2
        )'
      )
    from issue213_results
    where result_name = 'primary-save'
  ),
  'Save returns authoritative readback with the Dish ACTIVE at version 2'
);

select is(
  (
    select pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'event_type', event.event_type,
        'aggregate_type', event.aggregate_type,
        'aggregate_version', event.aggregate_version
      )
      order by event.event_type
    )
    from atlas_audit.domain_events event
    where event.command_id =
      pg_catalog.md5('issue213-command:primary-save')::uuid
  ),
  pg_catalog.jsonb_build_array(
    pg_catalog.jsonb_build_object(
      'event_type', 'DishActivated',
      'aggregate_type', 'Dish',
      'aggregate_version', 2
    ),
    pg_catalog.jsonb_build_object(
      'event_type', 'RecipeSaved',
      'aggregate_type', 'RecipeVersion',
      'aggregate_version', 4
    )
  ),
  'initial Save emits separate Dish activation and Recipe Save domain evidence'
);

select is(
  (
    select pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'event_type', audit.event_type,
        'before', audit.aggregate_version_before,
        'after', audit.aggregate_version_after,
        'before_status', audit.before_summary ->> 'dish_status',
        'after_status', audit.after_summary ->> 'dish_status'
      )
      order by audit.event_type
    )
    from atlas_audit.audit_events audit
    where audit.command_id =
      pg_catalog.md5('issue213-command:primary-save')::uuid
  ),
  pg_catalog.jsonb_build_array(
    pg_catalog.jsonb_build_object(
      'event_type', 'DishActivated',
      'before', 1,
      'after', 2,
      'before_status', 'DRAFT',
      'after_status', 'ACTIVE'
    ),
    pg_catalog.jsonb_build_object(
      'event_type', 'RecipeSaved',
      'before', null,
      'after', 4,
      'before_status', null,
      'after_status', null
    )
  ),
  'initial Save preserves exact Dish and Recipe audit before/after evidence'
);

select ok(
  (
    select pg_catalog.jsonb_array_length(
      response_payload -> 'emitted_event_ids'
    ) = 2
      and pg_catalog.jsonb_array_length(
        response_payload -> 'audit_event_ids'
      ) = 2
    from issue213_results
    where result_name = 'primary-save'
  ),
  'initial Save response exposes both event and audit identifiers'
);

select is(
  (
    select first.response_payload
    from issue213_results first
    where first.result_name = 'primary-save'
  ),
  (
    select replay.response_payload
    from issue213_results replay
    where replay.result_name = 'primary-replay'
  ),
  'idempotent replay returns the original authoritative response'
);

select is(
  (
    select pg_catalog.jsonb_build_object(
      'dish_version', dish.version,
      'event_count', (
        select count(*) from atlas_audit.domain_events event
        where event.command_id =
          pg_catalog.md5('issue213-command:primary-save')::uuid
      ),
      'audit_count', (
        select count(*) from atlas_audit.audit_events audit
        where audit.command_id =
          pg_catalog.md5('issue213-command:primary-save')::uuid
      ),
      'receipt_count', (
        select count(*) from atlas_core.command_receipts receipt
        where receipt.command_id =
          pg_catalog.md5('issue213-command:primary-save')::uuid
      )
    )
    from atlas_admin.dishes dish
    where dish.dish_id = pg_temp.issue213_created_dish_id('primary')
  ),
  pg_catalog.jsonb_build_object(
    'dish_version', 2,
    'event_count', 2,
    'audit_count', 2,
    'receipt_count', 1
  ),
  'replay does not activate, increment, or emit evidence twice'
);

select is(
  (
    select pg_catalog.jsonb_build_object(
      'stale_error', stale.response_payload ->> 'error_code',
      'stale_status', stale_dish.dish_status,
      'stale_version', stale_dish.version,
      'stale_recipes', (
        select count(*) from atlas_admin.recipes recipe
        where recipe.dish_id = stale_dish.dish_id
      ),
      'invalid_error', invalid.response_payload ->> 'error_code',
      'invalid_status', invalid_dish.dish_status,
      'invalid_version', invalid_dish.version,
      'invalid_recipes', (
        select count(*) from atlas_admin.recipes recipe
        where recipe.dish_id = invalid_dish.dish_id
      )
    )
    from issue213_results stale
    cross join issue213_results invalid
    join atlas_admin.dishes stale_dish
      on stale_dish.dish_code = 'issue213-stale'
    join atlas_admin.dishes invalid_dish
      on invalid_dish.dish_code = 'issue213-invalid'
    where stale.result_name = 'stale-save'
      and invalid.result_name = 'invalid-save'
  ),
  pg_catalog.jsonb_build_object(
    'stale_error', 'STALE_VERSION',
    'stale_status', 'DRAFT',
    'stale_version', 1,
    'stale_recipes', 0,
    'invalid_error', 'VALIDATION_FAILED',
    'invalid_status', 'DRAFT',
    'invalid_version', 1,
    'invalid_recipes', 0
  ),
  'stale and invalid Saves leave their Dishes and Recipe state unchanged'
);

select is(
  (
    select pg_catalog.jsonb_build_object(
      'dish_status', dish.dish_status,
      'dish_version', dish.version,
      'recipe_status', recipe.recipe_status,
      'recipe_version_status', version.recipe_version_status,
      'save_event_count', pg_catalog.jsonb_array_length(
        result.response_payload -> 'emitted_event_ids'
      )
    )
    from atlas_admin.dishes dish
    join atlas_admin.recipes recipe on recipe.dish_id = dish.dish_id
    join atlas_admin.recipe_versions version
      on version.recipe_id = recipe.recipe_id
    join issue213_results result on result.result_name = 'active-save'
    where dish.dish_code = 'issue213-active'
  ),
  pg_catalog.jsonb_build_object(
    'dish_status', 'ACTIVE',
    'dish_version', 2,
    'recipe_status', 'ACTIVE',
    'recipe_version_status', 'RELEASED_FOR_PLANNING',
    'save_event_count', 1
  ),
  'saving an already-ACTIVE Dish remains valid without another lifecycle change'
);

select is(
  (
    select pg_catalog.jsonb_build_object(
      'error_code', result.response_payload ->> 'error_code',
      'dish_status', dish.dish_status,
      'dish_version', dish.version,
      'recipe_count', (
        select count(*) from atlas_admin.recipes recipe
        where recipe.dish_id = dish.dish_id
      )
    )
    from issue213_results result
    join atlas_admin.dishes dish
      on dish.dish_code = 'issue213-inactive'
    where result.result_name = 'inactive-save'
  ),
  pg_catalog.jsonb_build_object(
    'error_code', 'INVARIANT_VIOLATION',
    'dish_status', 'INACTIVE',
    'dish_version', 3,
    'recipe_count', 0
  ),
  'existing INACTIVE-Dish Save denial remains unchanged'
);

select is(
  (
    select pg_catalog.jsonb_build_object(
      'error_code', result.response_payload ->> 'error_code',
      'safe_message', result.response_payload ->> 'safe_message',
      'dish_status', dish.dish_status,
      'dish_version', dish.version,
      'recipe_roots', (
        select count(*) from atlas_admin.recipes recipe
        where recipe.dish_id = dish.dish_id
      ),
      'recipe_versions', (
        select count(*) from atlas_admin.recipe_versions version
        join atlas_admin.recipes recipe on recipe.recipe_id = version.recipe_id
        where recipe.dish_id = dish.dish_id
      ),
      'recipe_lines', (
        select count(*) from atlas_admin.recipe_lines line
        join atlas_admin.recipes recipe on recipe.recipe_id = line.recipe_id
        where recipe.dish_id = dish.dish_id
      ),
      'recipe_line_revisions', (
        select count(*) from atlas_admin.recipe_line_revisions revision
        where revision.recipe_id in (
          select recipe.recipe_id from atlas_admin.recipes recipe
          where recipe.dish_id = dish.dish_id
        )
      ),
      'domain_events', (
        select count(*) from atlas_audit.domain_events event
        where event.command_id =
          pg_catalog.md5('issue213-command:inactive-type-save')::uuid
      ),
      'audit_events', (
        select count(*) from atlas_audit.audit_events audit
        where audit.command_id =
          pg_catalog.md5('issue213-command:inactive-type-save')::uuid
      ),
      'completed_receipts', (
        select count(*) from atlas_core.command_receipts receipt
        where receipt.command_id =
          pg_catalog.md5('issue213-command:inactive-type-save')::uuid
          and receipt.outcome = 'COMPLETED'
      )
    )
    from issue213_results result
    join atlas_admin.dishes dish
      on dish.dish_code = 'issue213-inactive-type'
    where result.result_name = 'inactive-type-save'
  ),
  pg_catalog.jsonb_build_object(
    'error_code', 'INVARIANT_VIOLATION',
    'safe_message',
      'An active database-backed Dish Type is required before activation.',
    'dish_status', 'DRAFT',
    'dish_version', 1,
    'recipe_roots', 0,
    'recipe_versions', 0,
    'recipe_lines', 0,
    'recipe_line_revisions', 0,
    'domain_events', 0,
    'audit_events', 0,
    'completed_receipts', 0
  ),
  'inactive Dish Type rejects Save before Recipe writes or success evidence'
);

select is(
  (
    select pg_catalog.jsonb_build_object(
      'error_code', result.response_payload ->> 'error_code',
      'safe_message', result.response_payload ->> 'safe_message',
      'existing_status', existing.dish_status,
      'existing_version', existing.version,
      'draft_status', draft.dish_status,
      'draft_version', draft.version,
      'recipe_roots', (
        select count(*) from atlas_admin.recipes recipe
        where recipe.dish_id = draft.dish_id
      ),
      'recipe_versions', (
        select count(*) from atlas_admin.recipe_versions version
        join atlas_admin.recipes recipe on recipe.recipe_id = version.recipe_id
        where recipe.dish_id = draft.dish_id
      ),
      'recipe_lines', (
        select count(*) from atlas_admin.recipe_lines line
        join atlas_admin.recipes recipe on recipe.recipe_id = line.recipe_id
        where recipe.dish_id = draft.dish_id
      ),
      'recipe_line_revisions', (
        select count(*) from atlas_admin.recipe_line_revisions revision
        where revision.recipe_id in (
          select recipe.recipe_id from atlas_admin.recipes recipe
          where recipe.dish_id = draft.dish_id
        )
      ),
      'domain_events', (
        select count(*) from atlas_audit.domain_events event
        where event.command_id =
          pg_catalog.md5('issue213-command:duplicate-name-save')::uuid
      ),
      'audit_events', (
        select count(*) from atlas_audit.audit_events audit
        where audit.command_id =
          pg_catalog.md5('issue213-command:duplicate-name-save')::uuid
      ),
      'completed_receipts', (
        select count(*) from atlas_core.command_receipts receipt
        where receipt.command_id =
          pg_catalog.md5('issue213-command:duplicate-name-save')::uuid
          and receipt.outcome = 'COMPLETED'
      )
    )
    from issue213_results result
    join atlas_admin.dishes existing
      on existing.dish_code = 'issue213-duplicate-active'
    join atlas_admin.dishes draft
      on draft.dish_code = 'issue213-duplicate-draft'
    where result.result_name = 'duplicate-name-save'
  ),
  pg_catalog.jsonb_build_object(
    'error_code', 'CONFLICT',
    'safe_message',
      'An active dish with this normalized name already exists.',
    'existing_status', 'ACTIVE',
    'existing_version', 2,
    'draft_status', 'DRAFT',
    'draft_version', 1,
    'recipe_roots', 0,
    'recipe_versions', 0,
    'recipe_lines', 0,
    'recipe_line_revisions', 0,
    'domain_events', 0,
    'audit_events', 0,
    'completed_receipts', 0
  ),
  'duplicate active normalized name conflicts before Recipe writes or success evidence'
);

select ok(
  (
    select response_payload #>> '{preview,can_save}' = 'true'
      and not pg_catalog.jsonb_path_exists(
        response_payload,
        '$.preview.issues.blockers[*] ? (@.code == "INACTIVE_DISH")'
      )
    from issue213_results
    where result_name = 'menu-preview'
  ),
  'normal Weekly Menu preview accepts the saved Dish without INACTIVE_DISH'
);

select is(
  pg_catalog.jsonb_build_object(
    'weekly_menus', (select count(*) from atlas_planning.weekly_menus),
    'need_generation_runs',
      (select count(*) from atlas_planning.need_generation_runs),
    'confirmed_need_batches',
      (select count(*) from atlas_planning.confirmed_need_batches),
    'confirmed_need_releases',
      (select count(*) from atlas_planning.confirmed_need_releases),
    'purchase_handoffs',
      (select count(*) from atlas_planning.purchase_handoff_batches),
    'purchase_orders',
      (select count(*) from atlas_procurement.purchase_orders),
    'receiving_evidence',
      (select count(*) from atlas_evidence.supplier_receiving_evidence),
    'dispatch_plans',
      (select count(*) from atlas_dispatch.dispatch_plans)
  ),
  (
    select fact_counts from issue213_downstream_before
  ),
  'Admin Save and preview create no Menu, Need, Confirmed Need, Handoff, Procurement, Warehouse, or Dispatch facts'
);

select ok(
  (select response_payload #>> '{preview,can_save}' = 'false'
    and pg_catalog.jsonb_path_exists(response_payload,
      '$.preview.issues.blockers[*] ? (@.code == "INACTIVE_DISH")')
   from issue213_results where result_name = 'inactive-menu-preview'),
  'inactive Dish remains explicitly blocked for future Menu planning'
);

select is(
  (select requires_need_generation from atlas_admin.dishes
   where dish_id = pg_temp.issue213_created_dish_id('primary')),
  true,
  'normal creation and initial Recipe Save retain demand participation'
);

select * from finish();
rollback;
