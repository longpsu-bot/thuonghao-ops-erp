begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
select no_plan();

grant usage on schema extensions to authenticated;
grant execute on all functions in schema extensions to authenticated;

insert into atlas_core.actors (
  actor_id, actor_type, display_name
) values (
  'e2000000-0000-0000-0000-000000000001',
  'HUMAN',
  'Recipe ACTIVE-on-create correction operator'
);

insert into atlas_core.actor_auth_subjects (
  actor_auth_subject_id, actor_id, auth_subject_id
) values (
  'e2000000-0000-0000-0000-000000000002',
  'e2000000-0000-0000-0000-000000000001',
  'e2000000-0000-0000-0000-000000000101'
);

insert into atlas_core.roles (
  role_id, role_code, role_name
) values (
  'e2000000-0000-0000-0000-000000000003',
  'recipe-active-on-create.operator',
  'Recipe ACTIVE-on-create correction operator'
);

insert into atlas_core.role_capabilities (role_id, capability_id)
select 'e2000000-0000-0000-0000-000000000003', capability_id
from atlas_core.capabilities
where capability_code in (
  'master_data.recipe_adjustments.read',
  'master_data.recipes.read',
  'master_data.recipes.write'
);

insert into atlas_core.actor_role_memberships (actor_id, role_id) values (
  'e2000000-0000-0000-0000-000000000001',
  'e2000000-0000-0000-0000-000000000003'
);

insert into atlas_core.actor_scopes (actor_id, scope_kind) values (
  'e2000000-0000-0000-0000-000000000001',
  'GLOBAL'
);

insert into atlas_admin.school_types (
  school_type_id, school_type_code, school_type_name, school_type_status
) values
  (
    'e2100000-0000-0000-0000-000000000001',
    'v1-school-type-1',
    'TIỂU HỌC',
    'ACTIVE'
  ),
  (
    'e2100000-0000-0000-0000-000000000002',
    'v1-school-type-2',
    'TRUNG HỌC',
    'ACTIVE'
  )
on conflict (school_type_code) do update
set school_type_name = excluded.school_type_name,
    school_type_status = excluded.school_type_status;

create temporary table active_create_school_types as
select school_type_id, school_type_code
from atlas_admin.school_types
where school_type_code in ('v1-school-type-1', 'v1-school-type-2');
grant select on active_create_school_types to authenticated;

insert into atlas_admin.dish_types (
  dish_type_id, dish_type_code, dish_type_name, source_header_aliases,
  display_order, dish_type_status
) values
  (
    'e2100000-0000-4000-8000-000000000010',
    'recipe_active_create',
    'Recipe ACTIVE create type',
    array['Recipe ACTIVE create']::text[],
    201,
    'ACTIVE'
  ),
  (
    'e2100000-0000-4000-8000-000000000011',
    'recipe_inactive_create',
    'Recipe inactive create type',
    array['Recipe inactive create']::text[],
    202,
    'INACTIVE'
  );

insert into atlas_admin.customers (
  customer_id, customer_code, customer_name, customer_type
) values (
  'e2100000-0000-0000-0000-000000000020',
  'recipe-active-create-customer',
  'Recipe ACTIVE create customer',
  'SCHOOL_CATERING'
);

insert into atlas_admin.delivery_locations (
  delivery_location_id, customer_id, location_code, location_name,
  address_text
) values (
  'e2100000-0000-0000-0000-000000000021',
  'e2100000-0000-0000-0000-000000000020',
  'recipe-active-create-location',
  'Recipe ACTIVE create location',
  'Rolled-back lifecycle correction fixture'
);

insert into atlas_admin.schools (
  school_id, customer_id, school_code, school_name, school_type_id,
  default_delivery_location_id, default_student_portions,
  default_teacher_portions
) values (
  'e2100000-0000-0000-0000-000000000022',
  'e2100000-0000-0000-0000-000000000020',
  'recipe-active-create-school',
  'Recipe ACTIVE create School',
  (
    select school_type_id from active_create_school_types
    where school_type_code = 'v1-school-type-1'
  ),
  'e2100000-0000-0000-0000-000000000021',
  100,
  10
);

insert into atlas_admin.units (
  unit_id, unit_code, unit_name, dimension_code, decimal_scale
) values (
  'e2200000-0000-0000-0000-000000000001',
  'recipe-active-create-kg',
  'Recipe ACTIVE create kilogram',
  'MASS',
  3
);

insert into atlas_admin.ingredients (
  ingredient_id, ingredient_code, ingredient_name, ingredient_group,
  purchase_unit_id, ingredient_type, shopping_type, order_step
) values (
  'e2200000-0000-0000-0000-000000000002',
  'recipe-active-create-ingredient',
  'Recipe ACTIVE create ingredient',
  'Food',
  'e2200000-0000-0000-0000-000000000001',
  'Food',
  'Planned',
  1
);

create function pg_temp.active_create_command(
  p_name text,
  p_payload jsonb,
  p_expected_version bigint default 1
)
returns jsonb
language sql
as $$
  select pg_catalog.jsonb_build_object(
    'contract_version', 'RMVP-02A.v1',
    'command_id', pg_catalog.md5('active-create-command:' || p_name)::uuid,
    'correlation_id', 'e2000000-0000-0000-0000-000000000201',
    'idempotency_key', 'active-create:' || p_name,
    'expected_version', p_expected_version,
    'requested_by_auth_subject',
      'e2000000-0000-0000-0000-000000000101',
    'requested_at', pg_catalog.transaction_timestamp() - interval '1 second',
    'reason_code', 'RECIPE_ACTIVE_ON_CREATE_TEST',
    'reason_note', 'Rolled-back ACTIVE-on-create correction regression.',
    'payload', p_payload
  );
$$;

create function pg_temp.active_create_dish_payload(
  p_code text,
  p_name text,
  p_dish_type_id uuid default
    'e2100000-0000-4000-8000-000000000010'
)
returns jsonb
language sql
as $$
  select pg_catalog.jsonb_build_object(
    'dish_code', p_code,
    'dish_name', p_name,
    'dish_category', 'Lifecycle correction',
    'dish_type_id', p_dish_type_id,
    'display_order', 220,
    'requires_need_generation', true
  );
$$;

create function pg_temp.active_create_read(p_payload jsonb)
returns jsonb
language sql
as $$
  select pg_catalog.jsonb_build_object(
    'contract_version', 'RECIPE-EFFECTIVE.v1',
    'requested_by_auth_subject',
      'e2000000-0000-0000-0000-000000000101',
    'correlation_id', 'e2000000-0000-0000-0000-000000000202',
    'payload', p_payload
  );
$$;

create function pg_temp.active_create_save(p_dish_id uuid)
returns jsonb
language sql
as $$
  select pg_catalog.jsonb_build_object(
    'contract_version', 'RMVP-02A.v2',
    'command_id', pg_catalog.md5('active-create-save:first')::uuid,
    'correlation_id', 'e2000000-0000-0000-0000-000000000203',
    'idempotency_key', 'active-create-save:first',
    'expected_version', 1,
    'requested_by_auth_subject',
      'e2000000-0000-0000-0000-000000000101',
    'requested_at', pg_catalog.transaction_timestamp() - interval '1 second',
    'reason_code', 'RECIPE_SAVED',
    'reason_note', null,
    'payload', pg_catalog.jsonb_build_object(
      'dish_id', p_dish_id,
      'school_type_id', (
        select school_type_id from active_create_school_types
        where school_type_code = 'v1-school-type-1'
      ),
      'recipe_version_id', null,
      'basis_portions', 100,
      'lines', pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'recipe_line_id', 'e2600000-0000-0000-0000-000000000001',
        'ingredient_id', 'e2200000-0000-0000-0000-000000000002',
        'quantity_per_basis', 5,
        'unit_id', 'e2200000-0000-0000-0000-000000000001',
        'operational_note', 'Recipe-only Save evidence'
      ))
    )
  );
$$;

create function pg_temp.active_create_copy(
  p_name text,
  p_source_dish_id uuid,
  p_target_dish_id uuid
)
returns jsonb
language sql
as $$
  select pg_catalog.jsonb_build_object(
    'contract_version', 'RECIPE-EFFECTIVE.v1',
    'command_id', pg_catalog.md5('active-create-copy:' || p_name)::uuid,
    'correlation_id', 'e2000000-0000-0000-0000-000000000204',
    'idempotency_key', 'active-create-copy:' || p_name,
    'expected_version', 1,
    'requested_by_auth_subject',
      'e2000000-0000-0000-0000-000000000101',
    'requested_at', pg_catalog.transaction_timestamp() - interval '1 second',
    'reason_code', 'RECIPE_ACTIVE_ON_CREATE_COPY_TEST',
    'reason_note', 'Copy into a newly created ACTIVE Dish.',
    'payload', pg_catalog.jsonb_build_object(
      'source_dish_id', p_source_dish_id,
      'target_dish_id', p_target_dish_id,
      'as_of_date', '2026-09-06'
    )
  );
$$;

create temporary table active_create_results (
  result_name text primary key,
  response_payload jsonb not null
);
grant select, insert on active_create_results to authenticated;

set local role authenticated;
select pg_catalog.set_config(
  'request.jwt.claim.sub',
  'e2000000-0000-0000-0000-000000000101',
  true
);

insert into active_create_results values
  (
    'create-save-dish',
    atlas_api.create_dish(pg_temp.active_create_command(
      'create-save-dish',
      pg_temp.active_create_dish_payload(
        'active-create-save-dish',
        'ACTIVE create save Dish'
      )
    ))
  ),
  (
    'create-copy-target',
    atlas_api.create_dish(pg_temp.active_create_command(
      'create-copy-target',
      pg_temp.active_create_dish_payload(
        'active-create-copy-target',
        'ACTIVE create copy target'
      )
    ))
  );

insert into active_create_results values (
  'create-duplicate-name',
  atlas_api.create_dish(pg_temp.active_create_command(
    'create-duplicate-name',
    pg_temp.active_create_dish_payload(
      'active-create-duplicate-name',
      '  active CREATE copy TARGET  '
    )
  ))
);

insert into active_create_results values (
  'create-inactive-type',
  atlas_api.create_dish(pg_temp.active_create_command(
    'create-inactive-type',
    pg_temp.active_create_dish_payload(
      'active-create-inactive-type',
      'ACTIVE create inactive type Dish',
      'e2100000-0000-4000-8000-000000000011'
    )
  ))
);

insert into active_create_results values (
  'create-save-dish-replay',
  atlas_api.create_dish(pg_temp.active_create_command(
    'create-save-dish',
    pg_temp.active_create_dish_payload(
      'active-create-save-dish',
      'ACTIVE create save Dish'
    )
  ))
);

reset role;

create function pg_temp.active_created_dish_id(p_result_name text)
returns uuid
language sql
stable
as $$
  select (response_payload #>> '{affected_aggregate_ids,dish_id}')::uuid
  from active_create_results
  where result_name = p_result_name;
$$;

select ok(
  (
    select response_payload ->> 'success' = 'true'
      and pg_catalog.jsonb_path_exists(
        response_payload,
        '$.authoritative_readback.dishes[*] ? (
          @.dish_status == "ACTIVE" && @.version == 1
        )'
      )
    from active_create_results
    where result_name = 'create-save-dish'
  ),
  'A/B. create_dish succeeds with immediate ACTIVE version-1 readback'
);

select is(
  (
    select pg_catalog.jsonb_build_object(
      'status', dish.dish_status,
      'version', dish.version
    )
    from atlas_admin.dishes dish
    where dish.dish_id = pg_temp.active_created_dish_id('create-save-dish')
  ),
  '{"status":"ACTIVE","version":1}'::jsonb,
  'A. create_dish persists an ACTIVE Dish at version 1'
);

select is(
  (
    select pg_catalog.count(*)
    from atlas_admin.recipes recipe
    join active_create_school_types school_type
      on school_type.school_type_id = recipe.school_type_id
    where recipe.dish_id =
      pg_temp.active_created_dish_id('create-copy-target')
      and recipe.recipe_status = 'ACTIVE'
  ),
  2::bigint,
  'C. create_dish provisions exactly two canonical active Recipe roots'
);

select is(
  (
    select pg_catalog.count(*)
    from atlas_admin.recipe_versions version
    join atlas_admin.recipes recipe on recipe.recipe_id = version.recipe_id
    where recipe.dish_id =
      pg_temp.active_created_dish_id('create-copy-target')
  ),
  0::bigint,
  'D. create_dish creates zero RecipeVersions'
);

select ok(
  (
    select response_payload ->> 'success' = 'false'
      and response_payload ->> 'error_code' = 'CONFLICT'
    from active_create_results
    where result_name = 'create-duplicate-name'
  )
  and (
    select pg_catalog.count(*) = 1
    from atlas_admin.dishes dish
    where dish.dish_status = 'ACTIVE'
      and pg_catalog.lower(pg_catalog.btrim(dish.dish_name)) =
        'active create copy target'
  ),
  'E. duplicate normalized ACTIVE Dish name remains blocked'
);

select ok(
  (
    select response_payload ->> 'success' = 'false'
      and response_payload ->> 'error_code' = 'VALIDATION_FAILED'
    from active_create_results
    where result_name = 'create-inactive-type'
  )
  and not exists (
    select 1 from atlas_admin.dishes
    where dish_code = 'active-create-inactive-type'
  ),
  'F. inactive Dish Type blocks Dish and Recipe-root creation'
);

select ok(
  (
    select replay.response_payload ->> 'success' = 'true'
      and replay.response_payload ->> 'idempotency_status' = 'COMPLETED'
      and replay.response_payload #>> '{affected_aggregate_ids,dish_id}'
        = original.response_payload #>> '{affected_aggregate_ids,dish_id}'
    from active_create_results replay
    join active_create_results original
      on original.result_name = 'create-save-dish'
    where replay.result_name = 'create-save-dish-replay'
  )
  and (
    select pg_catalog.jsonb_build_object(
      'receipts', (
        select pg_catalog.count(*)
        from atlas_core.command_receipts receipt
        where receipt.command_id =
          pg_catalog.md5('active-create-command:create-save-dish')::uuid
          and receipt.outcome = 'COMPLETED'
      ),
      'events', (
        select pg_catalog.count(*)
        from atlas_audit.domain_events event
        where event.command_id =
          pg_catalog.md5('active-create-command:create-save-dish')::uuid
          and event.event_type = 'DishCreated'
      ),
      'audits', (
        select pg_catalog.count(*)
        from atlas_audit.audit_events audit
        where audit.command_id =
          pg_catalog.md5('active-create-command:create-save-dish')::uuid
          and audit.event_type = 'DishCreated'
      )
    ) = '{"receipts":1,"events":1,"audits":1}'::jsonb
  ),
  'create_dish replay returns the original ACTIVE identity with one receipt/event/audit set'
);

select ok(
  pg_catalog.strpos(
    pg_catalog.pg_get_functiondef(
      'atlas_api.create_dish(jsonb)'::regprocedure
    ),
    'pg_advisory_xact_lock'
  ) > 0
  and exists (
    select 1
    from pg_catalog.pg_class index_relation
    join pg_catalog.pg_index index_metadata
      on index_metadata.indexrelid = index_relation.oid
    where index_relation.relname = 'dishes_active_normalized_name_key'
      and index_metadata.indisunique
      and index_metadata.indpred is not null
  ),
  'E. normalized-name advisory serialization retains the unique-index race guard'
);

set local role authenticated;

insert into active_create_results values (
  'root-only-workbench',
  atlas_api.get_dish_recipe_operator_workbench(
    pg_temp.active_create_read(pg_catalog.jsonb_build_object(
      'as_of_date', '2026-09-06',
      'dish_id', pg_temp.active_created_dish_id('create-copy-target'),
      'school_type_id', (
        select school_type_id from active_create_school_types
        where school_type_code = 'v1-school-type-1'
      )
    ))
  )
);

insert into active_create_results values (
  'first-save',
  atlas_api.save_recipe(pg_temp.active_create_save(
    pg_temp.active_created_dish_id('create-save-dish')
  ))
);

insert into active_create_results values (
  'released-unused-workbench',
  atlas_api.get_dish_recipe_operator_workbench(
    pg_temp.active_create_read(pg_catalog.jsonb_build_object(
      'as_of_date', '2026-09-06',
      'dish_id', pg_temp.active_created_dish_id('create-save-dish'),
      'school_type_id', (
        select school_type_id from active_create_school_types
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
      and response_payload #>> '{workbench,effective_readiness,status}'
        = 'BLOCKED'
      and response_payload #> '{workbench,allowed_actions}'
        = '["COPY_DISH_RECIPES"]'::jsonb
    from active_create_results
    where result_name = 'root-only-workbench'
  ),
  'G/H/O. new ACTIVE root-only Dish is editable, not ready, and copy-eligible'
);

select is(
  (
    select pg_catalog.jsonb_build_object(
      'status', dish.dish_status,
      'version', dish.version
    )
    from atlas_admin.dishes dish
    where dish.dish_id = pg_temp.active_created_dish_id('create-save-dish')
  ),
  '{"status":"ACTIVE","version":1}'::jsonb,
  'I/K. first Recipe Save does not change Dish status or version'
);

select is(
  (
    select pg_catalog.jsonb_build_object(
      'dish_version', response_payload #>> '{new_versions,dish_version}',
      'event_count', pg_catalog.jsonb_array_length(
        response_payload -> 'emitted_event_ids'
      ),
      'audit_count', pg_catalog.jsonb_array_length(
        response_payload -> 'audit_event_ids'
      )
    )
    from active_create_results
    where result_name = 'first-save'
  ),
  '{"dish_version":"1","event_count":1,"audit_count":1}'::jsonb,
  'J/K. first Recipe Save returns unchanged Dish version and Recipe-only evidence'
);

select is(
  (
    select pg_catalog.count(*)
    from atlas_audit.domain_events event
    where event.command_id = pg_catalog.md5('active-create-save:first')::uuid
      and event.event_type = 'DishActivated'
  ),
  0::bigint,
  'J. first Recipe Save emits no DishActivated event'
);

select ok(
  (
    select response_payload #>> '{workbench,editable_state}' = 'EDITABLE_BASE'
      and response_payload #>> '{workbench,is_editable}' = 'true'
      and response_payload #>> '{workbench,effective_readiness,status}'
        = 'READY'
    from active_create_results
    where result_name = 'released-unused-workbench'
  ),
  'L. released Recipe without approved Menu use remains EDITABLE_BASE'
);

insert into atlas_admin.dishes (
  dish_id, dish_code, dish_name, dish_type_id, dish_status, display_order
) values (
  'e2300000-0000-0000-0000-000000000001',
  'active-create-copy-source',
  'ACTIVE create copy source',
  'e2100000-0000-4000-8000-000000000010',
  'ACTIVE',
  230
);

insert into atlas_admin.recipes (
  recipe_id, dish_id, school_type_id, recipe_status
)
select
  case school_type.school_type_code
    when 'v1-school-type-1'
      then 'e2400000-0000-0000-0000-000000000001'::uuid
    else 'e2400000-0000-0000-0000-000000000002'::uuid
  end,
  'e2300000-0000-0000-0000-000000000001',
  school_type.school_type_id,
  'ACTIVE'
from active_create_school_types school_type;

insert into atlas_admin.recipe_versions (
  recipe_version_id, recipe_id, version_number, basis_portions,
  created_by_actor_id, source_evidence
) values
  (
    'e2500000-0000-0000-0000-000000000001',
    'e2400000-0000-0000-0000-000000000001',
    1, 100, 'e2000000-0000-0000-0000-000000000001',
    '{"source_kind":"ACTIVE_CREATE_COPY_SOURCE"}'::jsonb
  ),
  (
    'e2500000-0000-0000-0000-000000000002',
    'e2400000-0000-0000-0000-000000000002',
    1, 100, 'e2000000-0000-0000-0000-000000000001',
    '{"source_kind":"ACTIVE_CREATE_COPY_SOURCE"}'::jsonb
  );

insert into atlas_admin.recipe_lines (
  recipe_line_id, recipe_id, line_code
) values
  (
    'e2600000-0000-0000-0000-000000000011',
    'e2400000-0000-0000-0000-000000000001',
    'active-create-copy-primary'
  ),
  (
    'e2600000-0000-0000-0000-000000000012',
    'e2400000-0000-0000-0000-000000000002',
    'active-create-copy-secondary'
  );

insert into atlas_admin.recipe_line_revisions (
  recipe_line_revision_id, recipe_id, recipe_version_id, recipe_line_id,
  line_revision_number, ingredient_id, quantity_per_basis, unit_id,
  created_by_actor_id
) values
  (
    'e2700000-0000-0000-0000-000000000011',
    'e2400000-0000-0000-0000-000000000001',
    'e2500000-0000-0000-0000-000000000001',
    'e2600000-0000-0000-0000-000000000011',
    1, 'e2200000-0000-0000-0000-000000000002', 6,
    'e2200000-0000-0000-0000-000000000001',
    'e2000000-0000-0000-0000-000000000001'
  ),
  (
    'e2700000-0000-0000-0000-000000000012',
    'e2400000-0000-0000-0000-000000000002',
    'e2500000-0000-0000-0000-000000000002',
    'e2600000-0000-0000-0000-000000000012',
    1, 'e2200000-0000-0000-0000-000000000002', 7,
    'e2200000-0000-0000-0000-000000000001',
    'e2000000-0000-0000-0000-000000000001'
  );

set constraints all immediate;
update atlas_admin.recipe_versions
set recipe_version_status = 'VALIDATED',
    validated_by_actor_id = 'e2000000-0000-0000-0000-000000000001',
    validated_at = pg_catalog.transaction_timestamp()
where recipe_version_id in (
  'e2500000-0000-0000-0000-000000000001',
  'e2500000-0000-0000-0000-000000000002'
);
update atlas_admin.recipe_versions
set recipe_version_status = 'RELEASED_FOR_PLANNING',
    released_by_actor_id = 'e2000000-0000-0000-0000-000000000001',
    released_at = pg_catalog.transaction_timestamp()
where recipe_version_id in (
  'e2500000-0000-0000-0000-000000000001',
  'e2500000-0000-0000-0000-000000000002'
);
set constraints all deferred;

set local role authenticated;
insert into active_create_results values (
  'copy-into-new-dish',
  atlas_api.copy_dish_recipes(pg_temp.active_create_copy(
    'copy-into-new-dish',
    'e2300000-0000-0000-0000-000000000001',
    pg_temp.active_created_dish_id('create-copy-target')
  ))
);
reset role;

select ok(
  (
    select response_payload ->> 'success' = 'true'
      and response_payload -> 'scope_results'
        @? '$[*] ? (@.school_type_code == "v1-school-type-1" && @.status == "COPIED")'
      and response_payload -> 'scope_results'
        @? '$[*] ? (@.school_type_code == "v1-school-type-2" && @.status == "COPIED")'
    from active_create_results
    where result_name = 'copy-into-new-dish'
  )
  and (
    select pg_catalog.count(*) = 2
    from atlas_admin.recipe_versions version
    join atlas_admin.recipes recipe on recipe.recipe_id = version.recipe_id
    where recipe.dish_id =
      pg_temp.active_created_dish_id('create-copy-target')
      and version.recipe_version_status = 'DRAFT'
  )
  and (
    select dish.dish_status = 'ACTIVE' and dish.version = 1
    from atlas_admin.dishes dish
    where dish.dish_id =
      pg_temp.active_created_dish_id('create-copy-target')
  ),
  'O. newly created ACTIVE Dish immediately receives both copied DRAFT Recipes without lifecycle mutation'
);

insert into atlas_planning.weekly_menus (
  weekly_menu_id, week_start, week_end, source_type, source_name,
  source_signature, weekly_menu_status, row_count, imported_by_actor_id
) values (
  'e2800000-0000-0000-0000-000000000001',
  '2026-09-07', '2026-09-13', 'TEST', 'ACTIVE create lock evidence',
  'active-create-lock', 'DRAFT', 1,
  'e2000000-0000-0000-0000-000000000001'
);

insert into atlas_planning.weekly_menu_lines (
  weekly_menu_line_id, weekly_menu_id, school_id, service_date,
  menu_slot_code, dish_id, created_by_actor_id, updated_by_actor_id
) values (
  'e2800000-0000-0000-0000-000000000002',
  'e2800000-0000-0000-0000-000000000001',
  'e2100000-0000-0000-0000-000000000022',
  '2026-09-08',
  'soup',
  pg_temp.active_created_dish_id('create-save-dish'),
  'e2000000-0000-0000-0000-000000000001',
  'e2000000-0000-0000-0000-000000000001'
);

update atlas_planning.weekly_menus
set weekly_menu_status = 'VALIDATED'
where weekly_menu_id = 'e2800000-0000-0000-0000-000000000001';

insert into atlas_planning.weekly_menu_approval_snapshots (
  weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version,
  approved_by_actor_id, approved_at
) values (
  'e2800000-0000-0000-0000-000000000003',
  'e2800000-0000-0000-0000-000000000001',
  1,
  'e2000000-0000-0000-0000-000000000001',
  pg_catalog.transaction_timestamp()
);

insert into atlas_planning.weekly_menu_approval_snapshot_lines (
  weekly_menu_approval_snapshot_line_id,
  weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version,
  weekly_menu_line_id, school_id, service_date, menu_slot_code, dish_id
) values (
  'e2800000-0000-0000-0000-000000000004',
  'e2800000-0000-0000-0000-000000000003',
  'e2800000-0000-0000-0000-000000000001',
  1,
  'e2800000-0000-0000-0000-000000000002',
  'e2100000-0000-0000-0000-000000000022',
  '2026-09-08',
  'soup',
  pg_temp.active_created_dish_id('create-save-dish')
);

set local role authenticated;
insert into active_create_results values (
  'locked-workbench',
  atlas_api.get_dish_recipe_operator_workbench(
    pg_temp.active_create_read(pg_catalog.jsonb_build_object(
      'as_of_date', '2026-09-06',
      'dish_id', pg_temp.active_created_dish_id('create-save-dish'),
      'school_type_id', (
        select school_type_id from active_create_school_types
        where school_type_code = 'v1-school-type-1'
      )
    ))
  )
);

insert into active_create_results values (
  'copy-into-locked-dish',
  atlas_api.copy_dish_recipes(pg_temp.active_create_copy(
    'copy-into-locked-dish',
    'e2300000-0000-0000-0000-000000000001',
    pg_temp.active_created_dish_id('create-save-dish')
  ))
);
reset role;

select ok(
  (
    select response_payload #>> '{workbench,editable_state}'
        = 'LOCKED_CHANGE_ORDER'
      and response_payload #>> '{workbench,is_operationally_locked}' = 'true'
      and response_payload #> '{workbench,allowed_actions}'
        = '["CREATE_CHANGE_ORDER"]'::jsonb
    from active_create_results
    where result_name = 'locked-workbench'
  ),
  'M. approved Menu evidence derives LOCKED_CHANGE_ORDER'
);

select is(
  (
    select pg_catalog.jsonb_build_object(
      'status', dish.dish_status,
      'version', dish.version
    )
    from atlas_admin.dishes dish
    where dish.dish_id = pg_temp.active_created_dish_id('create-save-dish')
  ),
  '{"status":"ACTIVE","version":1}'::jsonb,
  'N. approved Menu lock causes no Dish status or version mutation'
);

select ok(
  (
    select response_payload ->> 'success' = 'false'
      and response_payload ->> 'error_code' = 'INVARIANT_VIOLATION'
    from active_create_results
    where result_name = 'copy-into-locked-dish'
  )
  and (
    select pg_catalog.count(*) = 1
    from atlas_admin.recipe_versions version
    join atlas_admin.recipes recipe on recipe.recipe_id = version.recipe_id
    where recipe.dish_id = pg_temp.active_created_dish_id('create-save-dish')
  ),
  'P. approved-Menu lock blocks copy without changing target Recipe history'
);

select * from finish();
rollback;
