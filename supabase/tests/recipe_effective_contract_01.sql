begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into atlas_core.actors (
  actor_id, actor_type, display_name
) values (
  'c1000000-0000-0000-0000-000000000001',
  'HUMAN',
  'Recipe effective contract operator'
);

insert into atlas_core.actor_auth_subjects (
  actor_auth_subject_id, actor_id, auth_subject_id
) values (
  'c1000000-0000-0000-0000-000000000002',
  'c1000000-0000-0000-0000-000000000001',
  'c1000000-0000-0000-0000-000000000101'
);

insert into atlas_core.roles (
  role_id, role_code, role_name
) values (
  'c1000000-0000-0000-0000-000000000003',
  'recipe-effective.contract-operator',
  'Recipe effective contract operator'
);

insert into atlas_core.role_capabilities (role_id, capability_id)
select 'c1000000-0000-0000-0000-000000000003', capability_id
from atlas_core.capabilities
where capability_code in (
  'master_data.recipe_adjustments.read',
  'master_data.recipe_adjustments.write',
  'master_data.recipe_adjustments.cancel',
  'master_data.recipes.read',
  'master_data.recipes.write'
);

insert into atlas_core.actor_role_memberships (actor_id, role_id) values (
  'c1000000-0000-0000-0000-000000000001',
  'c1000000-0000-0000-0000-000000000003'
);

insert into atlas_core.actor_scopes (actor_id, scope_kind) values (
  'c1000000-0000-0000-0000-000000000001',
  'GLOBAL'
);

insert into atlas_admin.customers (
  customer_id, customer_code, customer_name, customer_type
) values (
  'c1100000-0000-0000-0000-000000000001',
  'recipe-effective-school-customer',
  'Recipe effective school customer',
  'SCHOOL_CATERING'
);

insert into atlas_admin.delivery_locations (
  delivery_location_id, customer_id, location_code, location_name,
  address_text, timezone_name
) values (
  'c1100000-0000-0000-0000-000000000002',
  'c1100000-0000-0000-0000-000000000001',
  'recipe-effective-location',
  'Recipe effective location',
  'Synthetic local address',
  'Asia/Ho_Chi_Minh'
);

insert into atlas_admin.school_types (
  school_type_id, school_type_code, school_type_name
) values
  (
    'c1100000-0000-0000-0000-000000000010',
    'recipe-effective-primary',
    'Tiểu học'
  ),
  (
    'c1100000-0000-0000-0000-000000000011',
    'recipe-effective-secondary',
    'Trung học'
  );

insert into atlas_admin.schools (
  school_id, customer_id, school_code, school_name, school_type_id,
  default_delivery_location_id, display_order
) values (
  'c1100000-0000-0000-0000-000000000020',
  'c1100000-0000-0000-0000-000000000001',
  'recipe-effective-primary-school',
  'Trường Tiểu học Recipe Effective',
  'c1100000-0000-0000-0000-000000000010',
  'c1100000-0000-0000-0000-000000000002',
  1
);

insert into atlas_admin.units (
  unit_id, unit_code, unit_name, dimension_code, decimal_scale
) values (
  'c1200000-0000-0000-0000-000000000001',
  'recipe-effective-kg',
  'Kilôgam',
  'MASS',
  3
);

insert into atlas_admin.ingredients (
  ingredient_id, ingredient_code, ingredient_name, ingredient_group,
  purchase_unit_id, ingredient_type, shopping_type, order_step
) values
  (
    'c1200000-0000-0000-0000-000000000010',
    'recipe-effective-chicken',
    'Cánh gà',
    'Food',
    'c1200000-0000-0000-0000-000000000001',
    'Food',
    'Planned',
    1
  ),
  (
    'c1200000-0000-0000-0000-000000000011',
    'recipe-effective-onion',
    'Hành tây',
    'Food',
    'c1200000-0000-0000-0000-000000000001',
    'Food',
    'Planned',
    1
  ),
  (
    'c1200000-0000-0000-0000-000000000012',
    'recipe-effective-garlic',
    'Tỏi',
    'Food',
    'c1200000-0000-0000-0000-000000000001',
    'Food',
    'Planned',
    1
  ),
  (
    'c1200000-0000-0000-0000-000000000013',
    'recipe-effective-ginger',
    'Gừng',
    'Food',
    'c1200000-0000-0000-0000-000000000001',
    'Food',
    'Planned',
    1
  );

insert into atlas_admin.dishes (
  dish_id, dish_code, dish_name, dish_status, display_order
) values
  (
    'c1300000-0000-0000-0000-000000000001',
    'recipe-effective-typed-dish',
    'Món có công thức theo loại trường',
    'ACTIVE',
    1
  ),
  (
    'c1300000-0000-0000-0000-000000000002',
    'recipe-effective-fallback-dish',
    'Món dùng công thức chung',
    'ACTIVE',
    2
  ),
  (
    'c1300000-0000-0000-0000-000000000003',
    'recipe-effective-ambiguous-dish',
    'Món lỗi nhiều công thức',
    'ACTIVE',
    3
  );

-- The production unique index prevents this corruption. Dropping it only
-- inside this rolled-back test proves that the selector still fails closed
-- if historical or concurrently imported data is ambiguous.
drop index atlas_admin.recipes_active_typed_dish_school_type_key;

insert into atlas_admin.recipes (
  recipe_id, dish_id, school_type_id
) values
  (
    'c1400000-0000-0000-0000-000000000001',
    'c1300000-0000-0000-0000-000000000001',
    null
  ),
  (
    'c1400000-0000-0000-0000-000000000002',
    'c1300000-0000-0000-0000-000000000001',
    'c1100000-0000-0000-0000-000000000010'
  ),
  (
    'c1400000-0000-0000-0000-000000000003',
    'c1300000-0000-0000-0000-000000000002',
    null
  ),
  (
    'c1400000-0000-0000-0000-000000000004',
    'c1300000-0000-0000-0000-000000000003',
    'c1100000-0000-0000-0000-000000000010'
  ),
  (
    'c1400000-0000-0000-0000-000000000005',
    'c1300000-0000-0000-0000-000000000003',
    'c1100000-0000-0000-0000-000000000010'
  );

insert into atlas_admin.recipe_versions (
  recipe_version_id, recipe_id, version_number, basis_portions,
  created_by_actor_id, source_evidence
) values
  (
    'c1500000-0000-0000-0000-000000000001',
    'c1400000-0000-0000-0000-000000000001',
    1, 100,
    'c1000000-0000-0000-0000-000000000001',
    '{"source_kind":"RECIPE_EFFECTIVE_TEST"}'::jsonb
  ),
  (
    'c1500000-0000-0000-0000-000000000002',
    'c1400000-0000-0000-0000-000000000002',
    1, 100,
    'c1000000-0000-0000-0000-000000000001',
    '{"source_kind":"RECIPE_EFFECTIVE_TEST"}'::jsonb
  ),
  (
    'c1500000-0000-0000-0000-000000000003',
    'c1400000-0000-0000-0000-000000000003',
    1, 100,
    'c1000000-0000-0000-0000-000000000001',
    '{"source_kind":"RECIPE_EFFECTIVE_TEST"}'::jsonb
  ),
  (
    'c1500000-0000-0000-0000-000000000004',
    'c1400000-0000-0000-0000-000000000004',
    1, 100,
    'c1000000-0000-0000-0000-000000000001',
    '{"source_kind":"RECIPE_EFFECTIVE_TEST"}'::jsonb
  ),
  (
    'c1500000-0000-0000-0000-000000000005',
    'c1400000-0000-0000-0000-000000000005',
    1, 100,
    'c1000000-0000-0000-0000-000000000001',
    '{"source_kind":"RECIPE_EFFECTIVE_TEST"}'::jsonb
  );

insert into atlas_admin.recipe_lines (
  recipe_line_id, recipe_id, line_code
)
select
  ('c1600000-0000-0000-0000-' || pg_catalog.lpad(ordinality::text, 12, '0'))::uuid,
  recipe_id,
  'recipe-effective-line-' || ordinality
from pg_catalog.unnest(array[
  'c1400000-0000-0000-0000-000000000001'::uuid,
  'c1400000-0000-0000-0000-000000000002'::uuid,
  'c1400000-0000-0000-0000-000000000003'::uuid,
  'c1400000-0000-0000-0000-000000000004'::uuid,
  'c1400000-0000-0000-0000-000000000005'::uuid
]) with ordinality as source(recipe_id, ordinality);

insert into atlas_admin.recipe_line_revisions (
  recipe_line_revision_id, recipe_id, recipe_version_id, recipe_line_id,
  line_revision_number, ingredient_id, quantity_per_basis, unit_id,
  created_by_actor_id
)
select
  ('c1700000-0000-0000-0000-' || pg_catalog.lpad(ordinality::text, 12, '0'))::uuid,
  recipe_id,
  recipe_version_id,
  ('c1600000-0000-0000-0000-' || pg_catalog.lpad(ordinality::text, 12, '0'))::uuid,
  1,
  'c1200000-0000-0000-0000-000000000010',
  ordinality::numeric,
  'c1200000-0000-0000-0000-000000000001',
  'c1000000-0000-0000-0000-000000000001'
from (
  values
    (
      'c1400000-0000-0000-0000-000000000001'::uuid,
      'c1500000-0000-0000-0000-000000000001'::uuid,
      1
    ),
    (
      'c1400000-0000-0000-0000-000000000002'::uuid,
      'c1500000-0000-0000-0000-000000000002'::uuid,
      2
    ),
    (
      'c1400000-0000-0000-0000-000000000003'::uuid,
      'c1500000-0000-0000-0000-000000000003'::uuid,
      3
    ),
    (
      'c1400000-0000-0000-0000-000000000004'::uuid,
      'c1500000-0000-0000-0000-000000000004'::uuid,
      4
    ),
    (
      'c1400000-0000-0000-0000-000000000005'::uuid,
      'c1500000-0000-0000-0000-000000000005'::uuid,
      5
    )
) as source(recipe_id, recipe_version_id, ordinality);

set constraints all immediate;

update atlas_admin.recipe_versions
set recipe_version_status = 'VALIDATED',
    validated_by_actor_id = 'c1000000-0000-0000-0000-000000000001',
    validated_at = transaction_timestamp() - interval '2 hours';

update atlas_admin.recipe_versions
set recipe_version_status = 'RELEASED_FOR_PLANNING',
    released_by_actor_id = 'c1000000-0000-0000-0000-000000000001',
    released_at = transaction_timestamp() - interval '1 hour';

set constraints all deferred;

insert into atlas_admin.recipe_composition_adjustments (
  recipe_composition_adjustment_id, scope_kind, action_kind, school_id,
  dish_id, school_type_id, target_ingredient_id, target_recipe_line_id,
  adjustment_line_id, created_by_actor_id, updated_by_actor_id
) values
  (
    'c1800000-0000-0000-0000-000000000001',
    'SYSTEM_INGREDIENT', 'REPLACE', null, null, null,
    'c1200000-0000-0000-0000-000000000010', null, null,
    'c1000000-0000-0000-0000-000000000001',
    'c1000000-0000-0000-0000-000000000001'
  ),
  (
    'c1800000-0000-0000-0000-000000000002',
    'SYSTEM_DISH', 'ADJUST_QUANTITY', null,
    'c1300000-0000-0000-0000-000000000001',
    'c1100000-0000-0000-0000-000000000010',
    null, 'c1600000-0000-0000-0000-000000000002', null,
    'c1000000-0000-0000-0000-000000000001',
    'c1000000-0000-0000-0000-000000000001'
  ),
  (
    'c1800000-0000-0000-0000-000000000003',
    'SYSTEM_DISH', 'ADD', null,
    'c1300000-0000-0000-0000-000000000001',
    'c1100000-0000-0000-0000-000000000010',
    'c1200000-0000-0000-0000-000000000012', null,
    'c1a00000-0000-0000-0000-000000000001',
    'c1000000-0000-0000-0000-000000000001',
    'c1000000-0000-0000-0000-000000000001'
  ),
  (
    'c1800000-0000-0000-0000-000000000004',
    'SCHOOL', 'REPLACE',
    'c1100000-0000-0000-0000-000000000020', null, null,
    'c1200000-0000-0000-0000-000000000011', null, null,
    'c1000000-0000-0000-0000-000000000001',
    'c1000000-0000-0000-0000-000000000001'
  ),
  (
    'c1800000-0000-0000-0000-000000000005',
    'SCHOOL_DISH', 'ADJUST_QUANTITY',
    'c1100000-0000-0000-0000-000000000020',
    'c1300000-0000-0000-0000-000000000001', null,
    null, 'c1600000-0000-0000-0000-000000000002', null,
    'c1000000-0000-0000-0000-000000000001',
    'c1000000-0000-0000-0000-000000000001'
  );

insert into atlas_admin.recipe_composition_adjustment_revisions (
  recipe_composition_adjustment_revision_id,
  recipe_composition_adjustment_id, scope_kind, action_kind,
  revision_number, effective_from, substitute_ingredient_id,
  quantity_per_basis, unit_id, reason_code, reason_note,
  source_evidence, created_by_actor_id
) values
  (
    'c1900000-0000-0000-0000-000000000001',
    'c1800000-0000-0000-0000-000000000001',
    'SYSTEM_INGREDIENT', 'REPLACE', 1, '2026-09-01',
    'c1200000-0000-0000-0000-000000000011', null, null,
    'RECIPE_EFFECTIVE_TEST', 'Thay nguyên liệu hệ thống.',
    '{}'::jsonb, 'c1000000-0000-0000-0000-000000000001'
  ),
  (
    'c1900000-0000-0000-0000-000000000002',
    'c1800000-0000-0000-0000-000000000002',
    'SYSTEM_DISH', 'ADJUST_QUANTITY', 1, '2026-09-01',
    null, 2, null,
    'RECIPE_EFFECTIVE_TEST', 'Đổi định lượng hệ thống.',
    '{}'::jsonb, 'c1000000-0000-0000-0000-000000000001'
  ),
  (
    'c1900000-0000-0000-0000-000000000003',
    'c1800000-0000-0000-0000-000000000003',
    'SYSTEM_DISH', 'ADD', 1, '2026-09-01',
    null, 0.5, 'c1200000-0000-0000-0000-000000000001',
    'RECIPE_EFFECTIVE_TEST', 'Thêm nguyên liệu hệ thống.',
    '{}'::jsonb, 'c1000000-0000-0000-0000-000000000001'
  ),
  (
    'c1900000-0000-0000-0000-000000000004',
    'c1800000-0000-0000-0000-000000000004',
    'SCHOOL', 'REPLACE', 1, '2026-09-01',
    'c1200000-0000-0000-0000-000000000013', null, null,
    'RECIPE_EFFECTIVE_TEST', 'Thay nguyên liệu tại trường.',
    '{}'::jsonb, 'c1000000-0000-0000-0000-000000000001'
  ),
  (
    'c1900000-0000-0000-0000-000000000005',
    'c1800000-0000-0000-0000-000000000005',
    'SCHOOL_DISH', 'ADJUST_QUANTITY', 1, '2026-09-01',
    null, 4, null,
    'RECIPE_EFFECTIVE_TEST', 'Đổi định lượng món tại trường.',
    '{}'::jsonb, 'c1000000-0000-0000-0000-000000000001'
  );

update atlas_admin.recipe_composition_adjustments root
set current_revision_id = revision.recipe_composition_adjustment_revision_id,
    current_revision_number = 1
from atlas_admin.recipe_composition_adjustment_revisions revision
where revision.recipe_composition_adjustment_id =
  root.recipe_composition_adjustment_id;

select is(
  atlas_core.recipe_effective_select_base_recipe(
    'c1300000-0000-0000-0000-000000000001',
    'c1100000-0000-0000-0000-000000000010'
  ) -> 'selected_recipe' ->> 'recipe_version_id',
  'c1500000-0000-0000-0000-000000000002',
  'A. explicit Tiểu học selects its exact School-Type Recipe'
);

select is(
  atlas_core.recipe_effective_select_base_recipe(
    'c1300000-0000-0000-0000-000000000002',
    'c1100000-0000-0000-0000-000000000010'
  ) -> 'selected_recipe' ->> 'selection_scope',
  'GENERAL',
  'B. Tiểu học falls back to GENERAL'
);

select is(
  atlas_core.recipe_effective_select_base_recipe(
    'c1300000-0000-0000-0000-000000000003',
    'c1100000-0000-0000-0000-000000000010'
  ) ->> 'status',
  'BLOCKED',
  'C. ambiguity blocks selection'
);

select is(
  atlas_core.recipe_effective_resolve_composition(
    '2026-09-05',
    null,
    'c1300000-0000-0000-0000-000000000001',
    'c1100000-0000-0000-0000-000000000010',
    null,
    null,
    null
  ) -> 'selected_recipe' ->> 'recipe_version_id',
  atlas_core.rmvp_02b_resolve_effective_composition(
    '2026-09-05',
    'c1100000-0000-0000-0000-000000000020',
    'c1300000-0000-0000-0000-000000000001'
  ) -> 'selected_recipe' ->> 'recipe_version_id',
  'D. School and explicit School-Type resolution select identically'
);

create function pg_temp.recipe_effective_read(payload jsonb)
returns jsonb
language sql
as $$
  select pg_catalog.jsonb_build_object(
    'contract_version', 'RECIPE-EFFECTIVE.v1',
    'requested_by_auth_subject',
      'c1000000-0000-0000-0000-000000000101',
    'correlation_id', 'c1000000-0000-0000-0000-000000000201',
    'payload', payload
  );
$$;

create temporary table recipe_effective_results (
  result_name text primary key,
  response_payload jsonb not null
);
grant select, insert on recipe_effective_results to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'c1000000-0000-0000-0000-000000000101',
  true
);

insert into recipe_effective_results values (
  'system-resolution',
  atlas_api.resolve_system_effective_recipe_composition(
    pg_temp.recipe_effective_read(
      pg_catalog.jsonb_build_object(
        'as_of_date', '2026-09-05',
        'dish_id', 'c1300000-0000-0000-0000-000000000001',
        'school_type_id', 'c1100000-0000-0000-0000-000000000010'
      )
    )
  )
),
(
  'fallback-target-context',
  atlas_api.get_recipe_effective_target_context(
    pg_temp.recipe_effective_read(
      pg_catalog.jsonb_build_object(
        'as_of_date', '2026-09-05',
        'dish_id', 'c1300000-0000-0000-0000-000000000002',
        'school_type_id', 'c1100000-0000-0000-0000-000000000010'
      )
    )
  )
),
(
  'school-target-context',
  atlas_api.get_recipe_effective_target_context(
    pg_temp.recipe_effective_read(
      pg_catalog.jsonb_build_object(
        'as_of_date', '2026-09-05',
        'dish_id', 'c1300000-0000-0000-0000-000000000001',
        'school_id', 'c1100000-0000-0000-0000-000000000020'
      )
    )
  )
);

reset role;

select ok(
  (
    select response_payload -> 'resolution' -> 'lines'
      @? '$[*].lineage[*] ? (@.scope_kind == "SYSTEM_INGREDIENT")'
    from recipe_effective_results
    where result_name = 'system-resolution'
  ),
  'E. system effective composition includes SYSTEM_INGREDIENT'
);

select ok(
  (
    select response_payload -> 'resolution' -> 'lines'
      @? '$[*] ? (@.source_layer == "SYSTEM_DISH")'
    from recipe_effective_results
    where result_name = 'system-resolution'
  ),
  'F. system effective composition includes SYSTEM_DISH'
);

select ok(
  not (
    select response_payload -> 'resolution' -> 'lines'
      @? '$[*].lineage[*] ? (@.scope_kind == "SCHOOL" || @.scope_kind == "SCHOOL_DISH")'
    from recipe_effective_results
    where result_name = 'system-resolution'
  ),
  'G. system effective composition excludes SCHOOL and SCHOOL_DISH'
);

select is(
  (
    select response_payload -> 'target_context' -> 'selected_recipe'
      ->> 'selection_scope'
    from recipe_effective_results
    where result_name = 'fallback-target-context'
  ),
  'GENERAL',
  'Q. GENERAL fallback lines appear for an explicit Tiểu học context'
);

select ok(
  (
    select response_payload -> 'target_context' -> 'effective_lines'
      @? '$[*] ? (@.ingredient_name == "Gừng" && @.quantity_per_basis == 4)'
    from recipe_effective_results
    where result_name = 'school-target-context'
  ),
  'R. School context returns the final currently visible effective lines'
);

select * from finish();
rollback;
