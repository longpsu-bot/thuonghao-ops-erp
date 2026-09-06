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
    'v1-school-type-1',
    'Tiểu học'
  ),
  (
    'c1100000-0000-0000-0000-000000000011',
    'v1-school-type-2',
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
  ),
  (
    'c1200000-0000-0000-0000-000000000015',
    'recipe-effective-salt',
    'Muối',
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
    'c1100000-0000-0000-0000-000000000010'
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

-- The history scenarios below have a fixed September 2026 timeline. Anchor
-- base release at the asserted September 5 first history boundary. An earlier
-- release coalesces identical BOM periods back to that earlier date; a
-- wall-clock release eventually hides the asserted period altogether.
update atlas_admin.recipe_versions
set recipe_version_status = 'VALIDATED',
    validated_by_actor_id = 'c1000000-0000-0000-0000-000000000001',
    validated_at = timestamptz '2026-08-31 23:00:00+00';

update atlas_admin.recipe_versions
set recipe_version_status = 'RELEASED_FOR_PLANNING',
    released_by_actor_id = 'c1000000-0000-0000-0000-000000000001',
    released_at = timestamptz '2026-09-05 00:00:00+00';

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
  ),
  (
    'c1800000-0000-0000-0000-000000000006',
    'SCHOOL_DISH', 'ADD',
    'c1100000-0000-0000-0000-000000000020',
    'c1300000-0000-0000-0000-000000000001', null,
    'c1200000-0000-0000-0000-000000000010', null,
    'c1a00000-0000-0000-0000-000000000002',
    'c1000000-0000-0000-0000-000000000001',
    'c1000000-0000-0000-0000-000000000001'
  ),
  (
    'c1800000-0000-0000-0000-000000000007',
    'SCHOOL_DISH', 'ADJUST_QUANTITY',
    'c1100000-0000-0000-0000-000000000020',
    'c1300000-0000-0000-0000-000000000001', null,
    null, null, 'c1a00000-0000-0000-0000-000000000002',
    'c1000000-0000-0000-0000-000000000001',
    'c1000000-0000-0000-0000-000000000001'
  );

insert into atlas_admin.recipe_composition_adjustment_revisions (
  recipe_composition_adjustment_revision_id,
  recipe_composition_adjustment_id, scope_kind, action_kind,
  revision_number, effective_from, effective_to, substitute_ingredient_id,
  quantity_per_basis, unit_id, reason_code, reason_note,
  source_evidence, created_by_actor_id
) values
  (
    'c1900000-0000-0000-0000-000000000001',
    'c1800000-0000-0000-0000-000000000001',
    'SYSTEM_INGREDIENT', 'REPLACE', 1, '2026-09-01', null,
    'c1200000-0000-0000-0000-000000000011', null, null,
    'RECIPE_EFFECTIVE_TEST', 'Thay nguyên liệu hệ thống.',
    '{}'::jsonb, 'c1000000-0000-0000-0000-000000000001'
  ),
  (
    'c1900000-0000-0000-0000-000000000002',
    'c1800000-0000-0000-0000-000000000002',
    'SYSTEM_DISH', 'ADJUST_QUANTITY', 1, '2026-09-01', null,
    null, 2, null,
    'RECIPE_EFFECTIVE_TEST', 'Đổi định lượng hệ thống.',
    '{}'::jsonb, 'c1000000-0000-0000-0000-000000000001'
  ),
  (
    'c1900000-0000-0000-0000-000000000003',
    'c1800000-0000-0000-0000-000000000003',
    'SYSTEM_DISH', 'ADD', 1, '2026-09-01', '2026-09-10',
    null, 0.5, 'c1200000-0000-0000-0000-000000000001',
    'RECIPE_EFFECTIVE_TEST', 'Thêm nguyên liệu hệ thống.',
    '{}'::jsonb, 'c1000000-0000-0000-0000-000000000001'
  ),
  (
    'c1900000-0000-0000-0000-000000000004',
    'c1800000-0000-0000-0000-000000000004',
    'SCHOOL', 'REPLACE', 1, '2026-09-01', null,
    'c1200000-0000-0000-0000-000000000013', null, null,
    'RECIPE_EFFECTIVE_TEST', 'Thay nguyên liệu tại trường.',
    '{}'::jsonb, 'c1000000-0000-0000-0000-000000000001'
  ),
  (
    'c1900000-0000-0000-0000-000000000005',
    'c1800000-0000-0000-0000-000000000005',
    'SCHOOL_DISH', 'ADJUST_QUANTITY', 1, '2026-09-01', null,
    null, 4, null,
    'RECIPE_EFFECTIVE_TEST', 'Đổi định lượng món tại trường.',
    '{}'::jsonb, 'c1000000-0000-0000-0000-000000000001'
  ),
  (
    'c1900000-0000-0000-0000-000000000006',
    'c1800000-0000-0000-0000-000000000006',
    'SCHOOL_DISH', 'ADD', 1, '2026-09-01', null,
    null, 0.25, 'c1200000-0000-0000-0000-000000000001',
    'RECIPE_EFFECTIVE_TEST', 'Thêm nguyên liệu tại trường.',
    '{}'::jsonb, 'c1000000-0000-0000-0000-000000000001'
  ),
  (
    'c1900000-0000-0000-0000-000000000007',
    'c1800000-0000-0000-0000-000000000007',
    'SCHOOL_DISH', 'ADJUST_QUANTITY', 1, '2026-10-20', null,
    null, 0.6, null,
    'RECIPE_EFFECTIVE_TEST', 'Đổi định lượng tương lai.',
    '{}'::jsonb, 'c1000000-0000-0000-0000-000000000001'
  );

update atlas_admin.recipe_composition_adjustments root
set current_revision_id = revision.recipe_composition_adjustment_revision_id,
    current_revision_number = 1
from atlas_admin.recipe_composition_adjustment_revisions revision
where revision.recipe_composition_adjustment_id =
  root.recipe_composition_adjustment_id;

insert into atlas_admin.recipe_composition_adjustments (
  recipe_composition_adjustment_id, scope_kind, action_kind, school_id,
  dish_id, target_ingredient_id, adjustment_line_id,
  created_by_actor_id, updated_by_actor_id
) values (
  'c1800000-0000-0000-0000-000000000008',
  'SCHOOL_DISH', 'ADD',
  'c1100000-0000-0000-0000-000000000020',
  'c1300000-0000-0000-0000-000000000001',
  'c1200000-0000-0000-0000-000000000012',
  'c1a00000-0000-0000-0000-000000000003',
  'c1000000-0000-0000-0000-000000000001',
  'c1000000-0000-0000-0000-000000000001'
);

insert into atlas_admin.recipe_composition_adjustment_revisions (
  recipe_composition_adjustment_revision_id,
  recipe_composition_adjustment_id, scope_kind, action_kind,
  revision_number, predecessor_revision_id, revision_status,
  effective_from, effective_to, quantity_per_basis, unit_id,
  reason_code, reason_note, source_evidence, created_by_actor_id
) values
  (
    'c1900000-0000-0000-0000-000000000081',
    'c1800000-0000-0000-0000-000000000008',
    'SCHOOL_DISH', 'ADD', 1, null, 'ACTIVE',
    '2026-10-20', '2026-10-25', 0.8,
    'c1200000-0000-0000-0000-000000000001',
    'RECIPE_EFFECTIVE_HISTORY', 'Thêm Tỏi tại trường.',
    '{}'::jsonb, 'c1000000-0000-0000-0000-000000000001'
  ),
  (
    'c1900000-0000-0000-0000-000000000082',
    'c1800000-0000-0000-0000-000000000008',
    'SCHOOL_DISH', 'ADD', 2,
    'c1900000-0000-0000-0000-000000000081', 'CANCELLED',
    '2026-10-25', '2026-10-30', null, null,
    'RECIPE_EFFECTIVE_HISTORY', 'Tạm hủy thêm Tỏi.',
    '{}'::jsonb, 'c1000000-0000-0000-0000-000000000001'
  ),
  (
    'c1900000-0000-0000-0000-000000000083',
    'c1800000-0000-0000-0000-000000000008',
    'SCHOOL_DISH', 'ADD', 3,
    'c1900000-0000-0000-0000-000000000082', 'ACTIVE',
    '2026-10-30', null, 0.9,
    'c1200000-0000-0000-0000-000000000001',
    'RECIPE_EFFECTIVE_HISTORY', 'Khôi phục Tỏi với định lượng đúng.',
    '{}'::jsonb, 'c1000000-0000-0000-0000-000000000001'
  );

update atlas_admin.recipe_composition_adjustments
set current_revision_id = 'c1900000-0000-0000-0000-000000000083',
    current_revision_number = 3,
    version = 3
where recipe_composition_adjustment_id =
  'c1800000-0000-0000-0000-000000000008';

-- These active rules share the selected context but target an Ingredient that
-- never occurs in this Dish. They are candidate boundaries only and must not
-- become Dish history or School-exception evidence.
insert into atlas_admin.recipe_composition_adjustments (
  recipe_composition_adjustment_id, scope_kind, action_kind, school_id,
  target_ingredient_id, created_by_actor_id, updated_by_actor_id
) values
  (
    'c1800000-0000-0000-0000-000000000050',
    'SYSTEM_INGREDIENT', 'REPLACE', null,
    'c1200000-0000-0000-0000-000000000015',
    'c1000000-0000-0000-0000-000000000001',
    'c1000000-0000-0000-0000-000000000001'
  ),
  (
    'c1800000-0000-0000-0000-000000000051',
    'SCHOOL', 'REMOVE',
    'c1100000-0000-0000-0000-000000000020',
    'c1200000-0000-0000-0000-000000000015',
    'c1000000-0000-0000-0000-000000000001',
    'c1000000-0000-0000-0000-000000000001'
  );

insert into atlas_admin.recipe_composition_adjustment_revisions (
  recipe_composition_adjustment_revision_id,
  recipe_composition_adjustment_id, scope_kind, action_kind,
  revision_number, effective_from, substitute_ingredient_id,
  reason_code, reason_note, source_evidence, created_by_actor_id
) values
  (
    'c1900000-0000-0000-0000-000000000050',
    'c1800000-0000-0000-0000-000000000050',
    'SYSTEM_INGREDIENT', 'REPLACE', 1, '2026-09-06',
    'c1200000-0000-0000-0000-000000000013',
    'RECIPE_EFFECTIVE_RELEVANCE', 'Unrelated system rule.', '{}'::jsonb,
    'c1000000-0000-0000-0000-000000000001'
  ),
  (
    'c1900000-0000-0000-0000-000000000051',
    'c1800000-0000-0000-0000-000000000051',
    'SCHOOL', 'REMOVE', 1, '2026-09-03', null,
    'RECIPE_EFFECTIVE_RELEVANCE', 'Unrelated School rule.', '{}'::jsonb,
    'c1000000-0000-0000-0000-000000000001'
  );

update atlas_admin.recipe_composition_adjustments root
set current_revision_id = revision.recipe_composition_adjustment_revision_id,
    current_revision_number = 1
from atlas_admin.recipe_composition_adjustment_revisions revision
where revision.recipe_composition_adjustment_id =
    root.recipe_composition_adjustment_id
  and root.recipe_composition_adjustment_id in (
    'c1800000-0000-0000-0000-000000000050',
    'c1800000-0000-0000-0000-000000000051'
  );

create function pg_temp.recipe_effective_modifier(
  p_scope text,
  p_action text,
  p_adjustment_id uuid,
  p_revision_id uuid,
  p_target_recipe_line_id uuid,
  p_adjustment_line_id uuid,
  p_dish_id uuid default 'c1300000-0000-0000-0000-000000000001'
)
returns jsonb
language sql
as $$
  select pg_catalog.jsonb_strip_nulls(
    pg_catalog.jsonb_build_object(
      'adjustment_id', p_adjustment_id,
      'revision_id', p_revision_id,
      'revision_number', 1,
      'scope_kind', p_scope,
      'action_kind', p_action,
      'school_id', case when p_scope = 'SCHOOL_DISH'
        then 'c1100000-0000-0000-0000-000000000020'::uuid end,
      'dish_id', p_dish_id,
      'school_type_id', case when p_scope = 'SYSTEM_DISH'
        then 'c1100000-0000-0000-0000-000000000010'::uuid end,
      'target_recipe_line_id', p_target_recipe_line_id,
      'adjustment_line_id', p_adjustment_line_id,
      'substitute_ingredient_id', case when p_action = 'REPLACE'
        and p_scope = 'SYSTEM_DISH'
          then 'c1200000-0000-0000-0000-000000000013'::uuid
        when p_action = 'REPLACE'
          then 'c1200000-0000-0000-0000-000000000011'::uuid end,
      'quantity_per_basis', case when p_action = 'ADJUST_QUANTITY'
        then 0.75 end,
      'effective_from', '2026-09-01',
      'reason_code', 'RECIPE_EFFECTIVE_TARGET_TEST',
      'reason_note', 'Stable effective-line target regression.'
    )
  );
$$;

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
  'SCHOOL_TYPE',
  'B. Tiểu học requires its exact typed Recipe'
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

select ok(
  (
    select pg_catalog.bool_and(
      exists (
        select 1
        from pg_catalog.jsonb_array_elements(
          resolution.payload -> 'lines'
        ) line
        where line ->> 'base_recipe_line_id' =
            'c1600000-0000-0000-0000-000000000003'
          and line -> 'applied_adjustment_ids' ? case_row.adjustment_id::text
      )
    )
    from (
      values
        ('REPLACE', 'c1b00000-0000-0000-0000-000000000101'::uuid,
          'c1c00000-0000-0000-0000-000000000101'::uuid),
        ('ADJUST_QUANTITY', 'c1b00000-0000-0000-0000-000000000102'::uuid,
          'c1c00000-0000-0000-0000-000000000102'::uuid),
        ('REMOVE', 'c1b00000-0000-0000-0000-000000000103'::uuid,
          'c1c00000-0000-0000-0000-000000000103'::uuid)
    ) case_row(action_kind, adjustment_id, revision_id)
    cross join lateral (
      select atlas_core.recipe_effective_resolve_composition(
        '2026-09-05', null,
        'c1300000-0000-0000-0000-000000000002',
        'c1100000-0000-0000-0000-000000000010',
        pg_temp.recipe_effective_modifier(
          'SYSTEM_DISH', case_row.action_kind,
          case_row.adjustment_id, case_row.revision_id,
          'c1600000-0000-0000-0000-000000000003', null,
          'c1300000-0000-0000-0000-000000000002'
        )
      ) payload
    ) resolution
  ),
  'H. SYSTEM_DISH modifiers target a base Recipe line'
);

select ok(
  (
    select pg_catalog.bool_and(
      exists (
        select 1
        from pg_catalog.jsonb_array_elements(
          resolution.payload -> 'lines'
        ) line
        where line ->> 'adjustment_line_id' =
            'c1a00000-0000-0000-0000-000000000001'
          and line -> 'applied_adjustment_ids' ? case_row.adjustment_id::text
      )
    )
    from (
      values
        ('REPLACE', 'c1b00000-0000-0000-0000-000000000111'::uuid,
          'c1c00000-0000-0000-0000-000000000111'::uuid),
        ('ADJUST_QUANTITY', 'c1b00000-0000-0000-0000-000000000112'::uuid,
          'c1c00000-0000-0000-0000-000000000112'::uuid),
        ('REMOVE', 'c1b00000-0000-0000-0000-000000000113'::uuid,
          'c1c00000-0000-0000-0000-000000000113'::uuid)
    ) case_row(action_kind, adjustment_id, revision_id)
    cross join lateral (
      select atlas_core.recipe_effective_resolve_composition(
        '2026-09-05', null,
        'c1300000-0000-0000-0000-000000000001',
        'c1100000-0000-0000-0000-000000000010',
        pg_temp.recipe_effective_modifier(
          'SYSTEM_DISH', case_row.action_kind,
          case_row.adjustment_id, case_row.revision_id, null,
          'c1a00000-0000-0000-0000-000000000001'
        )
      ) payload
    ) resolution
  ),
  'I. SYSTEM_DISH modifiers target a prior ADD adjustment line'
);

select ok(
  (
    select pg_catalog.bool_and(
      exists (
        select 1
        from pg_catalog.jsonb_array_elements(
          resolution.payload -> 'lines'
        ) line
        where line ->> 'base_recipe_line_id' =
            'c1600000-0000-0000-0000-000000000003'
          and line -> 'applied_adjustment_ids' ? case_row.adjustment_id::text
      )
    )
    from (
      values
        ('REPLACE', 'c1b00000-0000-0000-0000-000000000121'::uuid,
          'c1c00000-0000-0000-0000-000000000121'::uuid),
        ('ADJUST_QUANTITY', 'c1b00000-0000-0000-0000-000000000122'::uuid,
          'c1c00000-0000-0000-0000-000000000122'::uuid),
        ('REMOVE', 'c1b00000-0000-0000-0000-000000000123'::uuid,
          'c1c00000-0000-0000-0000-000000000123'::uuid)
    ) case_row(action_kind, adjustment_id, revision_id)
    cross join lateral (
      select atlas_core.recipe_effective_resolve_composition(
        '2026-09-05',
        'c1100000-0000-0000-0000-000000000020',
        'c1300000-0000-0000-0000-000000000002', null,
        pg_temp.recipe_effective_modifier(
          'SCHOOL_DISH', case_row.action_kind,
          case_row.adjustment_id, case_row.revision_id,
          'c1600000-0000-0000-0000-000000000003', null,
          'c1300000-0000-0000-0000-000000000002'
        )
      ) payload
    ) resolution
  ),
  'J. SCHOOL_DISH modifiers target a base Recipe line'
);

select ok(
  (
    select pg_catalog.bool_and(
      exists (
        select 1
        from pg_catalog.jsonb_array_elements(
          resolution.payload -> 'lines'
        ) line
        where line ->> 'adjustment_line_id' =
            'c1a00000-0000-0000-0000-000000000001'
          and line -> 'applied_adjustment_ids' ? case_row.adjustment_id::text
      )
    )
    from (
      values
        ('REPLACE', 'c1b00000-0000-0000-0000-000000000131'::uuid,
          'c1c00000-0000-0000-0000-000000000131'::uuid),
        ('ADJUST_QUANTITY', 'c1b00000-0000-0000-0000-000000000132'::uuid,
          'c1c00000-0000-0000-0000-000000000132'::uuid),
        ('REMOVE', 'c1b00000-0000-0000-0000-000000000133'::uuid,
          'c1c00000-0000-0000-0000-000000000133'::uuid)
    ) case_row(action_kind, adjustment_id, revision_id)
    cross join lateral (
      select atlas_core.recipe_effective_resolve_composition(
        '2026-09-05',
        'c1100000-0000-0000-0000-000000000020',
        'c1300000-0000-0000-0000-000000000001', null,
        pg_temp.recipe_effective_modifier(
          'SCHOOL_DISH', case_row.action_kind,
          case_row.adjustment_id, case_row.revision_id, null,
          'c1a00000-0000-0000-0000-000000000001'
        )
      ) payload
    ) resolution
  ),
  'K. SCHOOL_DISH modifiers target a system ADD line'
);

select ok(
  (
    select pg_catalog.bool_and(
      exists (
        select 1
        from pg_catalog.jsonb_array_elements(
          resolution.payload -> 'lines'
        ) line
        where line ->> 'adjustment_line_id' =
            'c1a00000-0000-0000-0000-000000000002'
          and line -> 'applied_adjustment_ids' ? case_row.adjustment_id::text
      )
    )
    from (
      values
        ('REPLACE', 'c1b00000-0000-0000-0000-000000000141'::uuid,
          'c1c00000-0000-0000-0000-000000000141'::uuid),
        ('ADJUST_QUANTITY', 'c1b00000-0000-0000-0000-000000000142'::uuid,
          'c1c00000-0000-0000-0000-000000000142'::uuid),
        ('REMOVE', 'c1b00000-0000-0000-0000-000000000143'::uuid,
          'c1c00000-0000-0000-0000-000000000143'::uuid)
    ) case_row(action_kind, adjustment_id, revision_id)
    cross join lateral (
      select atlas_core.recipe_effective_resolve_composition(
        '2026-09-05',
        'c1100000-0000-0000-0000-000000000020',
        'c1300000-0000-0000-0000-000000000001', null,
        pg_temp.recipe_effective_modifier(
          'SCHOOL_DISH', case_row.action_kind,
          case_row.adjustment_id, case_row.revision_id, null,
          'c1a00000-0000-0000-0000-000000000002'
        )
      ) payload
    ) resolution
  ),
  'L. SCHOOL_DISH modifiers target a prior applicable SCHOOL_DISH ADD line'
);

select ok(
  atlas_core.rmvp_02b_validate_proposed_adjustment(
    pg_temp.recipe_effective_modifier(
      'SCHOOL_DISH', 'REMOVE',
      'c1b00000-0000-0000-0000-000000000151',
      'c1c00000-0000-0000-0000-000000000151',
      'c1600000-0000-0000-0000-000000000002',
      'c1a00000-0000-0000-0000-000000000001'
    ),
    '2026-09-05'
  ) -> 'blockers' @? '$[*] ? (@.code == "TYPED_SCOPE_INVALID")',
  'M. both stable target IDs fail typed validation'
);

select ok(
  atlas_core.rmvp_02b_validate_proposed_adjustment(
    pg_temp.recipe_effective_modifier(
      'SCHOOL_DISH', 'REMOVE',
      'c1b00000-0000-0000-0000-000000000152',
      'c1c00000-0000-0000-0000-000000000152', null, null
    ),
    '2026-09-05'
  ) -> 'blockers' @? '$[*] ? (@.code == "TYPED_SCOPE_INVALID")',
  'N. a missing stable target ID fails typed validation'
);

select ok(
  atlas_core.recipe_effective_resolve_composition(
    '2026-09-05',
    'c1100000-0000-0000-0000-000000000020',
    'c1300000-0000-0000-0000-000000000001', null,
    pg_temp.recipe_effective_modifier(
      'SCHOOL_DISH', 'REMOVE',
      'c1b00000-0000-0000-0000-000000000153',
      'c1c00000-0000-0000-0000-000000000153', null,
      'c1afffff-0000-0000-0000-000000000099'
    )
  ) -> 'blockers' @? '$[*] ? (@.code == "TARGET_NOT_APPLICABLE")',
  'O. a non-effective adjustment-line target is blocked'
);

select ok(
  atlas_core.rmvp_02b_typed_target_lock_key(
    'SCHOOL_DISH', 'ADD',
    'c1100000-0000-0000-0000-000000000020',
    'c1300000-0000-0000-0000-000000000001', null, null, null,
    'c1a00000-0000-0000-0000-000000000001'
  ) <> atlas_core.rmvp_02b_typed_target_lock_key(
    'SCHOOL_DISH', 'REMOVE',
    'c1100000-0000-0000-0000-000000000020',
    'c1300000-0000-0000-0000-000000000001', null, null, null,
    'c1a00000-0000-0000-0000-000000000001'
  )
  and atlas_core.rmvp_02b_typed_target_lock_key(
    'SCHOOL_DISH', 'REMOVE',
    'c1100000-0000-0000-0000-000000000020',
    'c1300000-0000-0000-0000-000000000001', null, null, null,
    'c1a00000-0000-0000-0000-000000000001'
  ) = atlas_core.rmvp_02b_typed_target_lock_key(
    'SCHOOL_DISH', 'ADJUST_QUANTITY',
    'c1100000-0000-0000-0000-000000000020',
    'c1300000-0000-0000-0000-000000000001', null, null, null,
    'c1a00000-0000-0000-0000-000000000001'
  )
  and atlas_core.rmvp_02b_typed_target_lock_key(
    'SCHOOL_DISH', 'REMOVE',
    'c1100000-0000-0000-0000-000000000020',
    'c1300000-0000-0000-0000-000000000001', null, null, null,
    'c1a00000-0000-0000-0000-000000000001'
  ) <> atlas_core.rmvp_02b_typed_target_lock_key(
    'SCHOOL_DISH', 'REMOVE',
    'c1100000-0000-0000-0000-000000000020',
    'c1300000-0000-0000-0000-000000000001', null, null, null,
    'c1a00000-0000-0000-0000-000000000002'
  )
  and atlas_core.rmvp_02b_validate_proposed_adjustment(
    pg_temp.recipe_effective_modifier(
      'SCHOOL_DISH', 'REMOVE',
      'c1b00000-0000-0000-0000-000000000154',
      'c1c00000-0000-0000-0000-000000000154', null,
      'c1a00000-0000-0000-0000-000000000002'
    ) || pg_catalog.jsonb_build_object(
      'effective_from', '2026-10-15'
    ),
    '2026-10-15'
  ) -> 'blockers' @? '$[*] ? (@.code == "OVERLAPPING_ACTIVE_RULE")',
  'P. target locks distinguish owners and serialize modifiers by stable origin'
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
  'SCHOOL_TYPE',
  'Q. typed lines appear for an explicit Tiểu học context'
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

create function pg_temp.recipe_effective_rmvp_read(payload jsonb)
returns jsonb
language sql
as $$
  select pg_catalog.jsonb_build_object(
    'contract_version', 'RMVP-02B.v1',
    'requested_by_auth_subject',
      'c1000000-0000-0000-0000-000000000101',
    'correlation_id', 'c1000000-0000-0000-0000-000000000202',
    'payload', payload
  );
$$;

create function pg_temp.recipe_effective_rmvp_command(payload jsonb)
returns jsonb
language sql
as $$
  select pg_catalog.jsonb_build_object(
    'contract_version', 'RMVP-02B.v1',
    'command_id', 'c1d00000-0000-0000-0000-000000000201',
    'correlation_id', 'c1000000-0000-0000-0000-000000000202',
    'idempotency_key', 'recipe-effective-target-roundtrip',
    'expected_version', 1,
    'requested_by_auth_subject',
      'c1000000-0000-0000-0000-000000000101',
    'requested_at', pg_catalog.transaction_timestamp() + interval '1 second',
    'reason_code', 'RECIPE_EFFECTIVE_TARGET_TEST',
    'reason_note', 'Preview and create stable target round-trip.',
    'payload', payload
  );
$$;

create temporary table recipe_effective_roundtrip_target as
select line ->> 'target_id' as target_id
from recipe_effective_results result
cross join lateral pg_catalog.jsonb_array_elements(
  result.response_payload -> 'target_context' -> 'effective_lines'
) line
where result.result_name = 'school-target-context'
  and line ->> 'target_kind' = 'ADJUSTMENT_LINE'
  and line ->> 'source_layer' = 'SYSTEM_DISH';
grant select on recipe_effective_roundtrip_target to authenticated;

set local role authenticated;

insert into recipe_effective_results values (
  'adjustment-target-preview',
  atlas_api.preview_recipe_composition_adjustment(
    pg_temp.recipe_effective_rmvp_read(
      pg_catalog.jsonb_build_object(
        'as_of_date', '2026-09-05',
        'school_id', 'c1100000-0000-0000-0000-000000000020',
        'dish_id', 'c1300000-0000-0000-0000-000000000001',
        'proposed_adjustment', pg_temp.recipe_effective_modifier(
          'SCHOOL_DISH', 'ADJUST_QUANTITY',
          'c1b00000-0000-0000-0000-000000000201',
          'c1c00000-0000-0000-0000-000000000201', null,
          (select target_id::uuid from recipe_effective_roundtrip_target)
        )
      )
    )
  )
),
(
  'adjustment-target-create',
  atlas_api.create_recipe_composition_adjustment(
    pg_temp.recipe_effective_rmvp_command(
      pg_temp.recipe_effective_modifier(
        'SCHOOL_DISH', 'ADJUST_QUANTITY',
        'c1b00000-0000-0000-0000-000000000201',
        'c1c00000-0000-0000-0000-000000000201', null,
        (select target_id::uuid from recipe_effective_roundtrip_target)
      ) || pg_catalog.jsonb_build_object(
        'as_of_date', '2026-09-05',
        'preview_school_id',
          'c1100000-0000-0000-0000-000000000020',
        'preview_dish_id',
          'c1300000-0000-0000-0000-000000000001',
        'source_evidence', pg_catalog.jsonb_build_object(
          'source', 'recipe-effective-contract-test'
        )
      )
    )
  )
);

reset role;

select ok(
  (
    select response_payload #>> '{preview,can_save}' = 'true'
      and response_payload #>>
        '{preview,proposed_adjustment,adjustment_line_id}' =
        (select target_id from recipe_effective_roundtrip_target)
    from recipe_effective_results
    where result_name = 'adjustment-target-preview'
  )
  and (
    select response_payload ->> 'success' = 'true'
    from recipe_effective_results
    where result_name = 'adjustment-target-create'
  )
  and exists (
    select 1
    from atlas_admin.recipe_composition_adjustments root
    where root.recipe_composition_adjustment_id =
        'c1b00000-0000-0000-0000-000000000201'
      and root.target_recipe_line_id is null
      and root.adjustment_line_id =
        (select target_id::uuid from recipe_effective_roundtrip_target)
  ),
  'S. stable target identity round-trips through Preview and Create'
);

create function pg_temp.recipe_effective_rmvp_v2_read(payload jsonb)
returns jsonb
language sql
as $$
  select pg_catalog.jsonb_build_object(
    'contract_version', 'RMVP-02B.v2',
    'requested_by_auth_subject',
      'c1000000-0000-0000-0000-000000000101',
    'correlation_id', 'c1000000-0000-0000-0000-000000000203',
    'payload', payload
  );
$$;

set local role authenticated;

insert into recipe_effective_results values
(
  'system-operator',
  atlas_api.get_dish_recipe_operator_workbench(
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
  'school-operator',
  atlas_api.get_dish_recipe_operator_workbench(
    pg_temp.recipe_effective_read(
      pg_catalog.jsonb_build_object(
        'as_of_date', '2026-09-05',
        'dish_id', 'c1300000-0000-0000-0000-000000000001',
        'school_id', 'c1100000-0000-0000-0000-000000000020'
      )
    )
  )
),
(
  'adjustment-ledger',
  atlas_api.get_recipe_adjustment_operator_workbench(
    pg_temp.recipe_effective_rmvp_v2_read(
      pg_catalog.jsonb_build_object('as_of_date', '2026-09-05')
    )
  )
);

reset role;

select ok(
  not exists (
    select 1
    from recipe_effective_results result
    cross join lateral pg_catalog.jsonb_array_elements(
      result.response_payload -> 'workbench' -> 'history_periods'
    ) period
    cross join lateral pg_catalog.jsonb_array_elements(
      period -> 'change_orders'
    ) change_order
    where result.result_name in ('system-operator', 'school-operator')
      and change_order ->> 'adjustment_id' in (
        'c1800000-0000-0000-0000-000000000050',
        'c1800000-0000-0000-0000-000000000051'
      )
  )
  and not exists (
    select 1
    from recipe_effective_results result
    cross join lateral pg_catalog.jsonb_array_elements(
      result.response_payload -> 'workbench' -> 'history_periods'
    ) period
    where result.result_name in ('system-operator', 'school-operator')
      and period ->> 'period_from' = '2026-09-03'
  ),
  'T. unrelated system and School rules create no Dish history tag or panel'
);

select ok(
  (
    select response_payload #>> '{workbench,school_exception_count}' = '4'
    from recipe_effective_results
    where result_name = 'system-operator'
  )
  and (
    select response_payload #>> '{workbench,school_exception_count}' = '4'
    from recipe_effective_results
    where result_name = 'school-operator'
  ),
  'U. School exception count includes only distinct materially applicable roots'
);

select ok(
  exists (
    select 1
    from recipe_effective_results result
    cross join lateral pg_catalog.jsonb_array_elements(
      result.response_payload -> 'workbench' -> 'history_periods'
    ) period
    where result.result_name = 'system-operator'
      and period ->> 'period_from' = '2026-09-05'
      and pg_catalog.jsonb_array_length(period -> 'effective_bom') = 2
      and period -> 'effective_bom'
        @? '$[*] ? (@.adjustment_line_id == "c1a00000-0000-0000-0000-000000000001")'
  )
  and exists (
    select 1
    from recipe_effective_results result
    cross join lateral pg_catalog.jsonb_array_elements(
      result.response_payload -> 'workbench' -> 'history_periods'
    ) period
    where result.result_name = 'system-operator'
      and period ->> 'period_from' = '2026-09-10'
      and pg_catalog.jsonb_array_length(period -> 'effective_bom') = 1
  ),
  'V. system history periods contain each complete effective BOM'
);

select ok(
  exists (
    select 1
    from recipe_effective_results result
    cross join lateral pg_catalog.jsonb_array_elements(
      result.response_payload -> 'workbench' -> 'history_periods'
    ) period
    where result.result_name = 'school-operator'
      and period ->> 'period_from' = '2026-09-05'
      and pg_catalog.jsonb_array_length(period -> 'effective_bom') = 3
      and period -> 'change_orders'
        @? '$[*] ? (@.scope_kind == "SYSTEM_INGREDIENT")'
      and period -> 'change_orders'
        @? '$[*] ? (@.scope_kind == "SYSTEM_DISH")'
      and period -> 'change_orders'
        @? '$[*] ? (@.scope_kind == "SCHOOL")'
      and period -> 'change_orders'
        @? '$[*] ? (@.scope_kind == "SCHOOL_DISH")'
  ),
  'W. School history includes system and School-specific full-BOM changes'
);

select ok(
  (
    select pg_catalog.count(*) = 1
    from recipe_effective_results result
    cross join lateral pg_catalog.jsonb_array_elements(
      result.response_payload -> 'workbench' -> 'history_periods'
    ) period
    where result.result_name = 'school-operator'
      and period ->> 'period_from' = '2026-10-20'
      and period -> 'change_orders'
        @? '$[*] ? (@.adjustment_id == "c1800000-0000-0000-0000-000000000007")'
      and period -> 'change_orders'
        @? '$[*] ? (@.adjustment_id == "c1800000-0000-0000-0000-000000000008")'
  ),
  'X. simultaneous Change Orders share one effective history boundary'
);

select ok(
  exists (
    select 1
    from recipe_effective_results result
    cross join lateral pg_catalog.jsonb_array_elements(
      result.response_payload -> 'workbench' -> 'history_periods'
    ) period
    where result.result_name = 'system-operator'
      and period ->> 'period_from' = '2026-09-05'
      and period ->> 'period_to' = '2026-09-10'
  )
  and exists (
    select 1
    from recipe_effective_results result
    cross join lateral pg_catalog.jsonb_array_elements(
      result.response_payload -> 'workbench' -> 'history_periods'
    ) period
    where result.result_name = 'system-operator'
      and period ->> 'period_from' = '2026-09-10'
      and not (
        period -> 'effective_bom'
          @? '$[*] ? (@.adjustment_line_id == "c1a00000-0000-0000-0000-000000000001")'
      )
  ),
  'Y. effective_to creates the next full-BOM history period'
);

select ok(
  exists (
    select 1
    from recipe_effective_results result
    cross join lateral pg_catalog.jsonb_array_elements(
      result.response_payload -> 'workbench' -> 'history_periods'
    ) period
    where result.result_name = 'school-operator'
      and period ->> 'period_from' = '2026-10-20'
      and period -> 'effective_bom'
        @? '$[*] ? (@.adjustment_line_id == "c1a00000-0000-0000-0000-000000000003" && @.quantity_per_basis == 0.8)'
  )
  and exists (
    select 1
    from recipe_effective_results result
    cross join lateral pg_catalog.jsonb_array_elements(
      result.response_payload -> 'workbench' -> 'history_periods'
    ) period
    where result.result_name = 'school-operator'
      and period ->> 'period_from' = '2026-10-25'
      and not (
        period -> 'effective_bom'
          @? '$[*] ? (@.adjustment_line_id == "c1a00000-0000-0000-0000-000000000003")'
      )
      and period -> 'change_orders'
        @? '$[*] ? (@.revision_status == "CANCELLED")'
  )
  and exists (
    select 1
    from recipe_effective_results result
    cross join lateral pg_catalog.jsonb_array_elements(
      result.response_payload -> 'workbench' -> 'history_periods'
    ) period
    where result.result_name = 'school-operator'
      and period ->> 'period_from' = '2026-10-30'
      and period -> 'effective_bom'
        @? '$[*] ? (@.adjustment_line_id == "c1a00000-0000-0000-0000-000000000003" && @.quantity_per_basis == 0.9)'
  ),
  'Z. cancelled and corrected revisions preserve their historical BOM periods'
);

select is(
  (
    select pg_catalog.array_agg(
      atlas_core.recipe_effective_is_effective_temporal_state(state_name)
      order by ordinality
    )
    from pg_catalog.unnest(array[
      'ACTIVE', 'ACTIVE_RESUMED', 'ACTIVE_CHANGE_SCHEDULED',
      'ACTIVE_CANCELLATION_SCHEDULED', 'SCHEDULED', 'EXPIRED',
      'CANCELLED'
    ]) with ordinality as state(state_name, ordinality)
  ),
  array[true, true, true, true, false, false, false],
  'AA. is_effective_now is backend-derived for every temporal state'
);

select ok(
  exists (
    select 1
    from recipe_effective_results result
    cross join lateral pg_catalog.jsonb_array_elements(
      result.response_payload -> 'workbench' -> 'operator_rows'
    ) row
    where result.result_name = 'adjustment-ledger'
      and row ->> 'adjustment_id' =
        'c1800000-0000-0000-0000-000000000003'
      and row ->> 'is_effective_now' = 'true'
      and row #>> '{display_revision,effective_to}' = '2026-09-10'
  ),
  'AB. backend effectiveness and effective_to remain independent ledger fields'
);

insert into atlas_admin.ingredients (
  ingredient_id, ingredient_code, ingredient_name, ingredient_group,
  purchase_unit_id, ingredient_type, shopping_type, order_step,
  ingredient_status
) values (
  'c1200000-0000-0000-0000-000000000014',
  'recipe-effective-inactive', 'Nguyên liệu ngưng dùng', 'Food',
  'c1200000-0000-0000-0000-000000000001', 'Food', 'Planned', 1,
  'INACTIVE'
);

insert into atlas_admin.dishes (
  dish_id, dish_code, dish_name, dish_status, display_order
) values
  ('c1300000-0000-0000-0000-000000000004',
    'recipe-copy-primary-only', 'Món nguồn chỉ Tiểu học', 'ACTIVE', 4),
  ('c1300000-0000-0000-0000-000000000005',
    'recipe-copy-target-all', 'Món đích đủ phạm vi', 'ACTIVE', 5),
  ('c1300000-0000-0000-0000-000000000006',
    'recipe-copy-target-partial', 'Món đích thiếu phạm vi', 'ACTIVE', 6),
  ('c1300000-0000-0000-0000-000000000007',
    'recipe-copy-target-locked', 'Món đích đã khóa', 'ACTIVE', 7),
  ('c1300000-0000-0000-0000-000000000008',
    'recipe-copy-source-failure', 'Món nguồn lỗi phạm vi hai', 'ACTIVE', 8),
  ('c1300000-0000-0000-0000-000000000009',
    'recipe-copy-target-atomic', 'Món đích kiểm tra nguyên tử', 'ACTIVE', 9);

insert into atlas_admin.recipes (recipe_id, dish_id, school_type_id) values
  ('c1400000-0000-0000-0000-000000000009',
    'c1300000-0000-0000-0000-000000000001',
    'c1100000-0000-0000-0000-000000000011'),
  ('c1400000-0000-0000-0000-000000000006',
    'c1300000-0000-0000-0000-000000000004',
    'c1100000-0000-0000-0000-000000000010'),
  ('c1400000-0000-0000-0000-000000000007',
    'c1300000-0000-0000-0000-000000000008',
    'c1100000-0000-0000-0000-000000000010'),
  ('c1400000-0000-0000-0000-000000000008',
    'c1300000-0000-0000-0000-000000000008',
    'c1100000-0000-0000-0000-000000000011'),
  ('c1400000-0000-0000-0000-000000000010',
    'c1300000-0000-0000-0000-000000000005',
    'c1100000-0000-0000-0000-000000000010'),
  ('c1400000-0000-0000-0000-000000000011',
    'c1300000-0000-0000-0000-000000000005',
    'c1100000-0000-0000-0000-000000000011'),
  ('c1400000-0000-0000-0000-000000000012',
    'c1300000-0000-0000-0000-000000000006',
    'c1100000-0000-0000-0000-000000000010'),
  ('c1400000-0000-0000-0000-000000000013',
    'c1300000-0000-0000-0000-000000000007',
    'c1100000-0000-0000-0000-000000000010'),
  ('c1400000-0000-0000-0000-000000000014',
    'c1300000-0000-0000-0000-000000000007',
    'c1100000-0000-0000-0000-000000000011'),
  ('c1400000-0000-0000-0000-000000000015',
    'c1300000-0000-0000-0000-000000000009',
    'c1100000-0000-0000-0000-000000000010'),
  ('c1400000-0000-0000-0000-000000000016',
    'c1300000-0000-0000-0000-000000000009',
    'c1100000-0000-0000-0000-000000000011');

insert into atlas_admin.recipe_versions (
  recipe_version_id, recipe_id, version_number, basis_portions,
  created_by_actor_id, source_evidence
) values
  ('c1500000-0000-0000-0000-000000000009',
    'c1400000-0000-0000-0000-000000000009', 1, 100,
    'c1000000-0000-0000-0000-000000000001', '{}'::jsonb),
  ('c1500000-0000-0000-0000-000000000006',
    'c1400000-0000-0000-0000-000000000006', 1, 100,
    'c1000000-0000-0000-0000-000000000001', '{}'::jsonb),
  ('c1500000-0000-0000-0000-000000000007',
    'c1400000-0000-0000-0000-000000000007', 1, 100,
    'c1000000-0000-0000-0000-000000000001', '{}'::jsonb),
  ('c1500000-0000-0000-0000-000000000008',
    'c1400000-0000-0000-0000-000000000008', 1, 100,
    'c1000000-0000-0000-0000-000000000001', '{}'::jsonb);

insert into atlas_admin.recipe_lines (recipe_line_id, recipe_id, line_code)
values
  ('c1600000-0000-0000-0000-000000000009',
    'c1400000-0000-0000-0000-000000000009', 'copy-line-9'),
  ('c1600000-0000-0000-0000-000000000006',
    'c1400000-0000-0000-0000-000000000006', 'copy-line-6'),
  ('c1600000-0000-0000-0000-000000000007',
    'c1400000-0000-0000-0000-000000000007', 'copy-line-7'),
  ('c1600000-0000-0000-0000-000000000008',
    'c1400000-0000-0000-0000-000000000008', 'copy-line-8');

insert into atlas_admin.recipe_line_revisions (
  recipe_line_revision_id, recipe_id, recipe_version_id, recipe_line_id,
  line_revision_number, ingredient_id, quantity_per_basis, unit_id,
  created_by_actor_id
) values
  ('c1700000-0000-0000-0000-000000000009',
    'c1400000-0000-0000-0000-000000000009',
    'c1500000-0000-0000-0000-000000000009',
    'c1600000-0000-0000-0000-000000000009', 1,
    'c1200000-0000-0000-0000-000000000010', 9,
    'c1200000-0000-0000-0000-000000000001',
    'c1000000-0000-0000-0000-000000000001'),
  ('c1700000-0000-0000-0000-000000000006',
    'c1400000-0000-0000-0000-000000000006',
    'c1500000-0000-0000-0000-000000000006',
    'c1600000-0000-0000-0000-000000000006', 1,
    'c1200000-0000-0000-0000-000000000010', 1,
    'c1200000-0000-0000-0000-000000000001',
    'c1000000-0000-0000-0000-000000000001'),
  ('c1700000-0000-0000-0000-000000000007',
    'c1400000-0000-0000-0000-000000000007',
    'c1500000-0000-0000-0000-000000000007',
    'c1600000-0000-0000-0000-000000000007', 1,
    'c1200000-0000-0000-0000-000000000010', 1,
    'c1200000-0000-0000-0000-000000000001',
    'c1000000-0000-0000-0000-000000000001'),
  ('c1700000-0000-0000-0000-000000000008',
    'c1400000-0000-0000-0000-000000000008',
    'c1500000-0000-0000-0000-000000000008',
    'c1600000-0000-0000-0000-000000000008', 1,
    'c1200000-0000-0000-0000-000000000014', 1,
    'c1200000-0000-0000-0000-000000000001',
    'c1000000-0000-0000-0000-000000000001');

update atlas_admin.recipe_versions
set recipe_version_status = 'VALIDATED',
    validated_by_actor_id = 'c1000000-0000-0000-0000-000000000001',
    validated_at = pg_catalog.transaction_timestamp()
where recipe_version_id in (
  'c1500000-0000-0000-0000-000000000009',
  'c1500000-0000-0000-0000-000000000006',
  'c1500000-0000-0000-0000-000000000007',
  'c1500000-0000-0000-0000-000000000008'
);
update atlas_admin.recipe_versions
set recipe_version_status = 'RELEASED_FOR_PLANNING',
    released_by_actor_id = 'c1000000-0000-0000-0000-000000000001',
    released_at = pg_catalog.transaction_timestamp()
where recipe_version_id in (
  'c1500000-0000-0000-0000-000000000009',
  'c1500000-0000-0000-0000-000000000006',
  'c1500000-0000-0000-0000-000000000007',
  'c1500000-0000-0000-0000-000000000008'
);

insert into atlas_planning.weekly_menus (
  weekly_menu_id, week_start, week_end, source_type, source_name,
  source_signature, weekly_menu_status, row_count, imported_by_actor_id
) values (
  'c1e00000-0000-0000-0000-000000000001',
  '2026-09-07', '2026-09-13', 'TEST', 'Recipe copy lock evidence',
  'recipe-effective-copy-lock', 'DRAFT', 1,
  'c1000000-0000-0000-0000-000000000001'
);
insert into atlas_planning.weekly_menu_lines (
  weekly_menu_line_id, weekly_menu_id, school_id, service_date,
  menu_slot_code, dish_id, created_by_actor_id, updated_by_actor_id
) values (
  'c1e00000-0000-0000-0000-000000000002',
  'c1e00000-0000-0000-0000-000000000001',
  'c1100000-0000-0000-0000-000000000020', '2026-09-08',
  'soup', 'c1300000-0000-0000-0000-000000000007',
  'c1000000-0000-0000-0000-000000000001',
  'c1000000-0000-0000-0000-000000000001'
);
update atlas_planning.weekly_menus
set weekly_menu_status = 'VALIDATED'
where weekly_menu_id = 'c1e00000-0000-0000-0000-000000000001';
insert into atlas_planning.weekly_menu_approval_snapshots (
  weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version,
  approved_by_actor_id, approved_at
) values (
  'c1e00000-0000-0000-0000-000000000003',
  'c1e00000-0000-0000-0000-000000000001', 1,
  'c1000000-0000-0000-0000-000000000001',
  pg_catalog.transaction_timestamp()
);
insert into atlas_planning.weekly_menu_approval_snapshot_lines (
  weekly_menu_approval_snapshot_line_id,
  weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version,
  weekly_menu_line_id, school_id, service_date, menu_slot_code, dish_id
) values (
  'c1e00000-0000-0000-0000-000000000004',
  'c1e00000-0000-0000-0000-000000000003',
  'c1e00000-0000-0000-0000-000000000001', 1,
  'c1e00000-0000-0000-0000-000000000002',
  'c1100000-0000-0000-0000-000000000020', '2026-09-08',
  'soup', 'c1300000-0000-0000-0000-000000000007'
);

create function pg_temp.recipe_effective_copy_command(
  command_id uuid,
  idempotency_key text,
  source_dish_id uuid,
  target_dish_id uuid
)
returns jsonb
language sql
as $$
  select pg_catalog.jsonb_build_object(
    'contract_version', 'RECIPE-EFFECTIVE.v1',
    'command_id', command_id,
    'correlation_id', 'c1000000-0000-0000-0000-000000000204',
    'idempotency_key', idempotency_key,
    'expected_version', 1,
    'requested_by_auth_subject',
      'c1000000-0000-0000-0000-000000000101',
    'requested_at', pg_catalog.transaction_timestamp(),
    'reason_code', 'RECIPE_EFFECTIVE_COPY_TEST',
    'reason_note', 'Atomic Dish-level Recipe copy regression.',
    'payload', pg_catalog.jsonb_build_object(
      'source_dish_id', source_dish_id,
      'target_dish_id', target_dish_id,
      'as_of_date', '2026-09-05'
    )
  );
$$;

set local role authenticated;
insert into recipe_effective_results values
  ('copy-all', atlas_api.copy_dish_recipes(
    pg_temp.recipe_effective_copy_command(
      'c1d00000-0000-0000-0000-000000000301', 'copy-all',
      'c1300000-0000-0000-0000-000000000001',
      'c1300000-0000-0000-0000-000000000005'))),
  ('copy-all-replay', atlas_api.copy_dish_recipes(
    pg_temp.recipe_effective_copy_command(
      'c1d00000-0000-0000-0000-000000000301', 'copy-all',
      'c1300000-0000-0000-0000-000000000001',
      'c1300000-0000-0000-0000-000000000005'))),
  ('copy-all-conflict', atlas_api.copy_dish_recipes(
    pg_temp.recipe_effective_copy_command(
      'c1d00000-0000-0000-0000-000000000301', 'copy-all',
      'c1300000-0000-0000-0000-000000000004',
      'c1300000-0000-0000-0000-000000000005'))),
  ('copy-missing', atlas_api.copy_dish_recipes(
    pg_temp.recipe_effective_copy_command(
      'c1d00000-0000-0000-0000-000000000302', 'copy-missing',
      'c1300000-0000-0000-0000-000000000004',
      'c1300000-0000-0000-0000-000000000006'))),
  ('copy-locked', atlas_api.copy_dish_recipes(
    pg_temp.recipe_effective_copy_command(
      'c1d00000-0000-0000-0000-000000000303', 'copy-locked',
      'c1300000-0000-0000-0000-000000000001',
      'c1300000-0000-0000-0000-000000000007'))),
  ('copy-atomic-failure', atlas_api.copy_dish_recipes(
    pg_temp.recipe_effective_copy_command(
      'c1d00000-0000-0000-0000-000000000304', 'copy-atomic-failure',
      'c1300000-0000-0000-0000-000000000008',
      'c1300000-0000-0000-0000-000000000009')));
reset role;

select ok(
  (select response_payload ->> 'success' = 'true'
   from recipe_effective_results where result_name = 'copy-all')
  and (select response_payload -> 'scope_results'
    @? '$[*] ? (@.school_type_code == "v1-school-type-1" && @.status == "COPIED")'
    from recipe_effective_results where result_name = 'copy-all')
  and (select response_payload -> 'scope_results'
    @? '$[*] ? (@.school_type_code == "v1-school-type-2" && @.status == "COPIED")'
    from recipe_effective_results where result_name = 'copy-all')
  and (select pg_catalog.count(*) = 2 from atlas_admin.recipes
    where dish_id = 'c1300000-0000-0000-0000-000000000005'),
  'AA. one command copies Tiểu học and Trung học scopes'
);

select ok(
  exists (
    select 1
    from atlas_admin.recipe_versions version
    where version.recipe_id = 'c1400000-0000-0000-0000-000000000010'
      and version.source_evidence ->> 'source_kind' = 'RECIPE_EFFECTIVE_COPY'
      and version.source_evidence ->> 'copy_as_of_date' = '2026-09-05'
      and version.draft_composition @? '$[*] ? (@.ingredient_id == "c1200000-0000-0000-0000-000000000011" && @.quantity_per_basis == 2)'
      and version.draft_composition @? '$[*] ? (@.ingredient_id == "c1200000-0000-0000-0000-000000000012" && @.quantity_per_basis == 0.5)'
      and not version.draft_composition @? '$[*] ? (@.ingredient_id == "c1200000-0000-0000-0000-000000000013")'
  ),
  'AB. Tiểu học copy snapshots system-effective BOM and excludes School layers'
);

select ok(
  exists (
    select 1
    from atlas_admin.recipe_versions version
    where version.recipe_id = 'c1400000-0000-0000-0000-000000000011'
      and version.source_evidence ->> 'source_kind' = 'RECIPE_EFFECTIVE_COPY'
      and version.draft_composition @? '$[*] ? (@.ingredient_id == "c1200000-0000-0000-0000-000000000011" && @.quantity_per_basis == 9)'
  ),
  'AC. Trung học copy snapshots its independent system-effective BOM'
);

select ok(
  (select response_payload ->> 'success' = 'false'
   from recipe_effective_results where result_name = 'copy-missing')
  and not exists (
    select 1 from atlas_admin.recipe_versions version
    where version.recipe_id = 'c1400000-0000-0000-0000-000000000012'
  ),
  'AD. a missing required source scope leaves every target scope unchanged'
);

select ok(
  (select response_payload ->> 'success' = 'false'
   from recipe_effective_results where result_name = 'copy-locked')
  and not exists (
    select 1 from atlas_admin.recipe_versions version
    where version.recipe_id in (
      'c1400000-0000-0000-0000-000000000013',
      'c1400000-0000-0000-0000-000000000014'
    )
  ),
  'AE. an approved-menu-locked target rejects the command with no writes'
);

select ok(
  (select response_payload ->> 'success' = 'false'
   from recipe_effective_results where result_name = 'copy-atomic-failure')
  and not exists (
    select 1 from atlas_admin.recipe_versions version
    where version.recipe_id in (
      'c1400000-0000-0000-0000-000000000015',
      'c1400000-0000-0000-0000-000000000016'
    )
  ),
  'AF. a required second-scope failure rolls back both target Recipes atomically'
);

select is(
  (select response_payload from recipe_effective_results
   where result_name = 'copy-all-replay'),
  (select response_payload from recipe_effective_results
   where result_name = 'copy-all'),
  'AG. an exact Dish-copy replay returns one authoritative result'
);

select is(
  (select response_payload ->> 'error_code'
   from recipe_effective_results where result_name = 'copy-all-conflict'),
  'IDEMPOTENCY_CONFLICT',
  'AH. changed payload with the same idempotency key remains protected'
);

select ok(
  (select pg_catalog.count(*) = 1
   from atlas_admin.recipe_versions version
   where version.recipe_id = 'c1400000-0000-0000-0000-000000000002')
  and exists (
    select 1
    from atlas_admin.recipe_line_revisions revision
    where revision.recipe_version_id =
        'c1500000-0000-0000-0000-000000000002'
      and revision.ingredient_id =
        'c1200000-0000-0000-0000-000000000010'
      and revision.quantity_per_basis = 2
  )
  and exists (
    select 1
    from atlas_admin.recipe_line_revisions revision
    where revision.recipe_version_id =
        'c1500000-0000-0000-0000-000000000009'
      and revision.ingredient_id =
        'c1200000-0000-0000-0000-000000000010'
      and revision.quantity_per_basis = 9
  ),
  'AI. Dish copy does not mutate either source base Recipe or BOM'
);

select ok(
  exists (
    select 1
    from atlas_admin.recipe_versions version
    where version.recipe_id = 'c1400000-0000-0000-0000-000000000010'
      and version.source_evidence -> 'contributing_system_adjustments'
        @? '$[*] ? (@.adjustment_id == "c1800000-0000-0000-0000-000000000001")'
      and version.source_evidence -> 'contributing_system_adjustments'
        @? '$[*] ? (@.adjustment_id == "c1800000-0000-0000-0000-000000000002")'
      and version.source_evidence -> 'contributing_system_adjustments'
        @? '$[*] ? (@.adjustment_id == "c1800000-0000-0000-0000-000000000003")'
  ),
  'AJ. copied RecipeVersion records distinct contributing system provenance'
);

insert into atlas_admin.recipe_composition_adjustments (
  recipe_composition_adjustment_id, scope_kind, action_kind, dish_id,
  school_type_id, target_ingredient_id, adjustment_line_id,
  created_by_actor_id, updated_by_actor_id
) values (
  'c1800000-0000-0000-0000-000000000099',
  'SYSTEM_DISH', 'ADD',
  'c1300000-0000-0000-0000-000000000001',
  'c1100000-0000-0000-0000-000000000010',
  'c1200000-0000-0000-0000-000000000013',
  'c1a00000-0000-0000-0000-000000000099',
  'c1000000-0000-0000-0000-000000000001',
  'c1000000-0000-0000-0000-000000000001'
);

insert into atlas_admin.recipe_composition_adjustment_revisions (
  recipe_composition_adjustment_revision_id,
  recipe_composition_adjustment_id, scope_kind, action_kind,
  revision_number, effective_from, quantity_per_basis, unit_id,
  reason_code, reason_note, source_evidence, created_by_actor_id
) values (
  'c1900000-0000-0000-0000-000000000099',
  'c1800000-0000-0000-0000-000000000099',
  'SYSTEM_DISH', 'ADD', 1, '2026-09-05', 0.75,
  'c1200000-0000-0000-0000-000000000001',
  'RECIPE_EFFECTIVE_COPY_TEST', 'Later source rule.', '{}'::jsonb,
  'c1000000-0000-0000-0000-000000000001'
);

update atlas_admin.recipe_composition_adjustments
set current_revision_id = 'c1900000-0000-0000-0000-000000000099',
    current_revision_number = 1
where recipe_composition_adjustment_id =
  'c1800000-0000-0000-0000-000000000099';

select ok(
  atlas_core.recipe_effective_resolve_composition(
    '2026-09-05', null,
    'c1300000-0000-0000-0000-000000000001',
    'c1100000-0000-0000-0000-000000000010'
  ) -> 'lines'
    @? '$[*] ? (@.final_ingredient_id == "c1200000-0000-0000-0000-000000000013" && @.final_disposition == "PRESENT")'
  and not exists (
    select 1
    from atlas_admin.recipe_versions version
    where version.recipe_id = 'c1400000-0000-0000-0000-000000000010'
      and version.draft_composition
        @? '$[*] ? (@.ingredient_id == "c1200000-0000-0000-0000-000000000013")'
  ),
  'AK. a later source system rule cannot alter the copied target snapshot'
);

create function pg_temp.recipe_system_context_command(
  p_name text,
  p_expected_version bigint,
  p_payload jsonb
)
returns jsonb
language sql
as $$
  select pg_catalog.jsonb_build_object(
    'contract_version', 'RMVP-02B.v1',
    'command_id', pg_catalog.md5(
      'recipe-system-context:' || p_name
    )::uuid,
    'correlation_id', 'c1000000-0000-0000-0000-000000000205',
    'idempotency_key', 'recipe-system-context:' || p_name,
    'expected_version', p_expected_version,
    'requested_by_auth_subject',
      'c1000000-0000-0000-0000-000000000101',
    'requested_at', pg_catalog.transaction_timestamp() + interval '2 seconds',
    'reason_code', 'RECIPE_SYSTEM_COMMAND_CONTEXT_TEST',
    'reason_note', 'System command context regression.',
    'payload', p_payload
  );
$$;

insert into atlas_admin.school_types (
  school_type_id, school_type_code, school_type_name
) values (
  'c1100000-0000-0000-0000-000000000012',
  'recipe-effective-noncanonical',
  'Loại trường ngoài danh mục chuẩn'
);

set local role authenticated;

insert into recipe_effective_results values
(
  'system-base-preview',
  atlas_api.preview_recipe_composition_adjustment(
    pg_temp.recipe_effective_rmvp_read(
      pg_catalog.jsonb_build_object(
        'as_of_date', '2026-09-05',
        'dish_id', 'c1300000-0000-0000-0000-000000000002',
        'school_type_id', 'c1100000-0000-0000-0000-000000000010',
        'proposed_adjustment', pg_temp.recipe_effective_modifier(
          'SYSTEM_DISH', 'ADJUST_QUANTITY',
          'c1b00000-0000-0000-0000-000000000401',
          'c1c00000-0000-0000-0000-000000000401',
          'c1600000-0000-0000-0000-000000000003', null,
          'c1300000-0000-0000-0000-000000000002'
        )
      )
    )
  )
),
(
  'system-add-origin-preview',
  atlas_api.preview_recipe_composition_adjustment(
    pg_temp.recipe_effective_rmvp_read(
      pg_catalog.jsonb_build_object(
        'as_of_date', '2026-09-05',
        'dish_id', 'c1300000-0000-0000-0000-000000000001',
        'school_type_id', 'c1100000-0000-0000-0000-000000000010',
        'proposed_adjustment', pg_temp.recipe_effective_modifier(
          'SYSTEM_DISH', 'ADJUST_QUANTITY',
          'c1b00000-0000-0000-0000-000000000402',
          'c1c00000-0000-0000-0000-000000000402', null,
          'c1a00000-0000-0000-0000-000000000001'
        )
      )
    )
  )
),
(
  'system-no-school-preview',
  atlas_api.preview_recipe_composition_adjustment(
    pg_temp.recipe_effective_rmvp_read(
      pg_catalog.jsonb_build_object(
        'as_of_date', '2026-09-05',
        'dish_id', 'c1300000-0000-0000-0000-000000000001',
        'school_type_id', 'c1100000-0000-0000-0000-000000000011',
        'proposed_adjustment', pg_catalog.jsonb_set(
          pg_temp.recipe_effective_modifier(
            'SYSTEM_DISH', 'ADJUST_QUANTITY',
            'c1b00000-0000-0000-0000-000000000403',
            'c1c00000-0000-0000-0000-000000000403',
            'c1600000-0000-0000-0000-000000000009', null
          ),
          '{school_type_id}',
          '"c1100000-0000-0000-0000-000000000011"'::jsonb
        )
      )
    )
  )
),
(
  'system-school-exception-authority',
  atlas_api.resolve_system_effective_recipe_composition(
    pg_temp.recipe_effective_read(
      pg_catalog.jsonb_build_object(
        'as_of_date', '2026-09-05',
        'dish_id', 'c1300000-0000-0000-0000-000000000001',
        'school_type_id', 'c1100000-0000-0000-0000-000000000010'
      )
    )
  )
);

insert into recipe_effective_results values
(
  'system-base-create',
  atlas_api.create_recipe_composition_adjustment(
    pg_temp.recipe_system_context_command(
      'base-create', 1,
      pg_temp.recipe_effective_modifier(
        'SYSTEM_DISH', 'ADJUST_QUANTITY',
        'c1b00000-0000-0000-0000-000000000401',
        'c1c00000-0000-0000-0000-000000000401',
        'c1600000-0000-0000-0000-000000000003', null,
        'c1300000-0000-0000-0000-000000000002'
      ) || pg_catalog.jsonb_build_object(
        'as_of_date', '2026-09-05',
        'preview_dish_id', 'c1300000-0000-0000-0000-000000000002',
        'preview_school_type_id',
          'c1100000-0000-0000-0000-000000000010'
      )
    )
  )
),
(
  'system-add-origin-create',
  atlas_api.create_recipe_composition_adjustment(
    pg_temp.recipe_system_context_command(
      'add-origin-create', 1,
      pg_temp.recipe_effective_modifier(
        'SYSTEM_DISH', 'ADJUST_QUANTITY',
        'c1b00000-0000-0000-0000-000000000402',
        'c1c00000-0000-0000-0000-000000000402', null,
        'c1a00000-0000-0000-0000-000000000001'
      ) || pg_catalog.jsonb_build_object(
        'as_of_date', '2026-09-05',
        'preview_dish_id', 'c1300000-0000-0000-0000-000000000001',
        'preview_school_type_id',
          'c1100000-0000-0000-0000-000000000010'
      )
    )
  )
),
(
  'system-base-create-replay',
  atlas_api.create_recipe_composition_adjustment(
    pg_temp.recipe_system_context_command(
      'base-create', 1,
      pg_temp.recipe_effective_modifier(
        'SYSTEM_DISH', 'ADJUST_QUANTITY',
        'c1b00000-0000-0000-0000-000000000401',
        'c1c00000-0000-0000-0000-000000000401',
        'c1600000-0000-0000-0000-000000000003', null,
        'c1300000-0000-0000-0000-000000000002'
      ) || pg_catalog.jsonb_build_object(
        'as_of_date', '2026-09-05',
        'preview_dish_id', 'c1300000-0000-0000-0000-000000000002',
        'preview_school_type_id',
          'c1100000-0000-0000-0000-000000000010'
      )
    )
  )
),
(
  'system-base-create-context-conflict',
  atlas_api.create_recipe_composition_adjustment(
    pg_temp.recipe_system_context_command(
      'base-create', 1,
      pg_catalog.jsonb_set(
        pg_catalog.jsonb_set(
          pg_temp.recipe_effective_modifier(
            'SYSTEM_DISH', 'ADJUST_QUANTITY',
            'c1b00000-0000-0000-0000-000000000401',
            'c1c00000-0000-0000-0000-000000000401',
            'c1600000-0000-0000-0000-000000000003', null,
            'c1300000-0000-0000-0000-000000000002'
          ) || pg_catalog.jsonb_build_object(
            'as_of_date', '2026-09-05',
            'preview_dish_id',
              'c1300000-0000-0000-0000-000000000002',
            'preview_school_type_id',
              'c1100000-0000-0000-0000-000000000010'
          ),
          '{school_type_id}',
          '"c1100000-0000-0000-0000-000000000011"'::jsonb
        ),
        '{preview_school_type_id}',
        '"c1100000-0000-0000-0000-000000000011"'::jsonb
      )
    )
  )
),
(
  'system-create-context-mismatch',
  atlas_api.create_recipe_composition_adjustment(
    pg_temp.recipe_system_context_command(
      'create-context-mismatch', 1,
      pg_temp.recipe_effective_modifier(
        'SYSTEM_DISH', 'ADJUST_QUANTITY',
        'c1b00000-0000-0000-0000-000000000416',
        'c1c00000-0000-0000-0000-000000000416',
        'c1600000-0000-0000-0000-000000000003', null,
        'c1300000-0000-0000-0000-000000000002'
      ) || pg_catalog.jsonb_build_object(
        'as_of_date', '2026-09-05',
        'preview_dish_id', 'c1300000-0000-0000-0000-000000000002',
        'preview_school_type_id',
          'c1100000-0000-0000-0000-000000000011'
      )
    )
  )
),
(
  'system-create-proxy-school',
  atlas_api.create_recipe_composition_adjustment(
    pg_temp.recipe_system_context_command(
      'create-proxy-school', 1,
      pg_temp.recipe_effective_modifier(
        'SYSTEM_DISH', 'ADJUST_QUANTITY',
        'c1b00000-0000-0000-0000-000000000417',
        'c1c00000-0000-0000-0000-000000000417',
        'c1600000-0000-0000-0000-000000000003', null,
        'c1300000-0000-0000-0000-000000000002'
      ) || pg_catalog.jsonb_build_object(
        'as_of_date', '2026-09-05',
        'preview_school_id', 'c1100000-0000-0000-0000-000000000020',
        'preview_dish_id', 'c1300000-0000-0000-0000-000000000002'
      )
    )
  )
);

reset role;

create temporary table recipe_system_old_revision as
select pg_catalog.to_jsonb(revision) as revision_payload
from atlas_admin.recipe_composition_adjustment_revisions revision
where revision.recipe_composition_adjustment_revision_id =
  'c1c00000-0000-0000-0000-000000000401';
grant select on recipe_system_old_revision to authenticated;

set local role authenticated;
insert into recipe_effective_results values
(
  'system-base-supersede',
  atlas_api.supersede_recipe_composition_adjustment(
    pg_temp.recipe_system_context_command(
      'base-supersede', 1,
      pg_catalog.jsonb_build_object(
        'adjustment_id', 'c1b00000-0000-0000-0000-000000000401',
        'revision_id', 'c1c00000-0000-0000-0000-000000000404',
        'predecessor_revision_id',
          'c1c00000-0000-0000-0000-000000000401',
        'effective_from', '2026-09-06',
        'quantity_per_basis', 0.85,
        'as_of_date', '2026-09-06',
        'preview_dish_id', 'c1300000-0000-0000-0000-000000000002',
        'preview_school_type_id',
          'c1100000-0000-0000-0000-000000000010'
      )
    )
  )
),
(
  'system-base-supersede-stale',
  atlas_api.supersede_recipe_composition_adjustment(
    pg_temp.recipe_system_context_command(
      'base-supersede-stale', 1,
      pg_catalog.jsonb_build_object(
        'adjustment_id', 'c1b00000-0000-0000-0000-000000000401',
        'revision_id', 'c1c00000-0000-0000-0000-000000000405',
        'predecessor_revision_id',
          'c1c00000-0000-0000-0000-000000000401',
        'effective_from', '2026-09-07',
        'quantity_per_basis', 0.95,
        'as_of_date', '2026-09-07',
        'preview_dish_id', 'c1300000-0000-0000-0000-000000000002',
        'preview_school_type_id',
          'c1100000-0000-0000-0000-000000000010'
      )
    )
  )
),
(
  'system-base-supersede-context-mismatch',
  atlas_api.supersede_recipe_composition_adjustment(
    pg_temp.recipe_system_context_command(
      'base-supersede-context-mismatch', 2,
      pg_catalog.jsonb_build_object(
        'adjustment_id', 'c1b00000-0000-0000-0000-000000000401',
        'revision_id', 'c1c00000-0000-0000-0000-000000000406',
        'predecessor_revision_id',
          'c1c00000-0000-0000-0000-000000000404',
        'effective_from', '2026-09-07',
        'quantity_per_basis', 0.95,
        'as_of_date', '2026-09-07',
        'preview_dish_id', 'c1300000-0000-0000-0000-000000000002',
        'preview_school_type_id',
          'c1100000-0000-0000-0000-000000000011'
      )
    )
  )
),
(
  'system-mismatched-type',
  atlas_api.preview_recipe_composition_adjustment(
    pg_temp.recipe_effective_rmvp_read(
      pg_catalog.jsonb_build_object(
        'as_of_date', '2026-09-05',
        'dish_id', 'c1300000-0000-0000-0000-000000000001',
        'school_type_id', 'c1100000-0000-0000-0000-000000000010',
        'proposed_adjustment', pg_catalog.jsonb_set(
          pg_temp.recipe_effective_modifier(
            'SYSTEM_DISH', 'ADJUST_QUANTITY',
            'c1b00000-0000-0000-0000-000000000410',
            'c1c00000-0000-0000-0000-000000000410',
            'c1600000-0000-0000-0000-000000000002', null
          ),
          '{school_type_id}',
          '"c1100000-0000-0000-0000-000000000011"'::jsonb
        )
      )
    )
  )
),
(
  'system-noncanonical-type',
  atlas_api.preview_recipe_composition_adjustment(
    pg_temp.recipe_effective_rmvp_read(
      pg_catalog.jsonb_build_object(
        'as_of_date', '2026-09-05',
        'dish_id', 'c1300000-0000-0000-0000-000000000001',
        'school_type_id', 'c1100000-0000-0000-0000-000000000012',
        'proposed_adjustment', pg_catalog.jsonb_set(
          pg_temp.recipe_effective_modifier(
            'SYSTEM_DISH', 'ADJUST_QUANTITY',
            'c1b00000-0000-0000-0000-000000000411',
            'c1c00000-0000-0000-0000-000000000411',
            'c1600000-0000-0000-0000-000000000002', null
          ),
          '{school_type_id}',
          '"c1100000-0000-0000-0000-000000000012"'::jsonb
        )
      )
    )
  )
),
(
  'system-mixed-context',
  atlas_api.preview_recipe_composition_adjustment(
    pg_temp.recipe_effective_rmvp_read(
      pg_catalog.jsonb_build_object(
        'as_of_date', '2026-09-05',
        'school_id', 'c1100000-0000-0000-0000-000000000020',
        'dish_id', 'c1300000-0000-0000-0000-000000000001',
        'school_type_id', 'c1100000-0000-0000-0000-000000000010',
        'proposed_adjustment', pg_temp.recipe_effective_modifier(
          'SYSTEM_DISH', 'ADJUST_QUANTITY',
          'c1b00000-0000-0000-0000-000000000412',
          'c1c00000-0000-0000-0000-000000000412',
          'c1600000-0000-0000-0000-000000000002', null
        )
      )
    )
  )
),
(
  'system-invalid-proxy-school',
  atlas_api.preview_recipe_composition_adjustment(
    pg_temp.recipe_effective_rmvp_read(
      pg_catalog.jsonb_build_object(
        'as_of_date', '2026-09-05',
        'school_id', 'not-a-uuid',
        'dish_id', 'c1300000-0000-0000-0000-000000000001',
        'school_type_id', 'c1100000-0000-0000-0000-000000000010',
        'proposed_adjustment', pg_temp.recipe_effective_modifier(
          'SYSTEM_DISH', 'ADJUST_QUANTITY',
          'c1b00000-0000-0000-0000-000000000420',
          'c1c00000-0000-0000-0000-000000000420',
          'c1600000-0000-0000-0000-000000000002', null
        )
      )
    )
  )
),
(
  'system-missing-context',
  atlas_api.preview_recipe_composition_adjustment(
    pg_temp.recipe_effective_rmvp_read(
      pg_catalog.jsonb_build_object(
        'as_of_date', '2026-09-05',
        'dish_id', 'c1300000-0000-0000-0000-000000000001',
        'proposed_adjustment', pg_temp.recipe_effective_modifier(
          'SYSTEM_DISH', 'ADJUST_QUANTITY',
          'c1b00000-0000-0000-0000-000000000413',
          'c1c00000-0000-0000-0000-000000000413',
          'c1600000-0000-0000-0000-000000000002', null
        )
      )
    )
  )
),
(
  'system-wrong-dish',
  atlas_api.preview_recipe_composition_adjustment(
    pg_temp.recipe_effective_rmvp_read(
      pg_catalog.jsonb_build_object(
        'as_of_date', '2026-09-05',
        'dish_id', 'c1300000-0000-0000-0000-000000000001',
        'school_type_id', 'c1100000-0000-0000-0000-000000000010',
        'proposed_adjustment', pg_temp.recipe_effective_modifier(
          'SYSTEM_DISH', 'ADJUST_QUANTITY',
          'c1b00000-0000-0000-0000-000000000414',
          'c1c00000-0000-0000-0000-000000000414',
          'c1600000-0000-0000-0000-000000000003', null,
          'c1300000-0000-0000-0000-000000000002'
        )
      )
    )
  )
),
(
  'system-subject-mismatch',
  atlas_api.preview_recipe_composition_adjustment(
    pg_catalog.jsonb_set(
      pg_temp.recipe_effective_rmvp_read(
        pg_catalog.jsonb_build_object(
          'as_of_date', '2026-09-05',
          'dish_id', 'c1300000-0000-0000-0000-000000000002',
          'school_type_id', 'c1100000-0000-0000-0000-000000000010',
          'proposed_adjustment', pg_temp.recipe_effective_modifier(
            'SYSTEM_DISH', 'ADJUST_QUANTITY',
            'c1b00000-0000-0000-0000-000000000418',
            'c1c00000-0000-0000-0000-000000000418',
            'c1600000-0000-0000-0000-000000000003', null,
            'c1300000-0000-0000-0000-000000000002'
          )
        )
      ),
      '{requested_by_auth_subject}',
      '"c1000000-0000-0000-0000-000000000999"'::jsonb
    )
  )
);
reset role;

update atlas_admin.school_types
set school_type_status = 'INACTIVE'
where school_type_id = 'c1100000-0000-0000-0000-000000000011';

set local role authenticated;
insert into recipe_effective_results values (
  'system-inactive-type',
  atlas_api.preview_recipe_composition_adjustment(
    pg_temp.recipe_effective_rmvp_read(
      pg_catalog.jsonb_build_object(
        'as_of_date', '2026-09-05',
        'dish_id', 'c1300000-0000-0000-0000-000000000001',
        'school_type_id', 'c1100000-0000-0000-0000-000000000011',
        'proposed_adjustment', pg_catalog.jsonb_set(
          pg_temp.recipe_effective_modifier(
            'SYSTEM_DISH', 'ADJUST_QUANTITY',
            'c1b00000-0000-0000-0000-000000000415',
            'c1c00000-0000-0000-0000-000000000415',
            'c1600000-0000-0000-0000-000000000009', null
          ),
          '{school_type_id}',
          '"c1100000-0000-0000-0000-000000000011"'::jsonb
        )
      )
    )
  )
);
reset role;

delete from atlas_core.role_capabilities
where role_id = 'c1000000-0000-0000-0000-000000000003'
  and capability_id = (
    select capability_id
    from atlas_core.capabilities
    where capability_code = 'master_data.recipe_adjustments.write'
  );

set local role authenticated;
insert into recipe_effective_results values (
  'system-capability-denied',
  atlas_api.preview_recipe_composition_adjustment(
    pg_temp.recipe_effective_rmvp_read(
      pg_catalog.jsonb_build_object(
        'as_of_date', '2026-09-05',
        'dish_id', 'c1300000-0000-0000-0000-000000000002',
        'school_type_id', 'c1100000-0000-0000-0000-000000000010',
        'proposed_adjustment', pg_temp.recipe_effective_modifier(
          'SYSTEM_DISH', 'ADJUST_QUANTITY',
          'c1b00000-0000-0000-0000-000000000419',
          'c1c00000-0000-0000-0000-000000000419',
          'c1600000-0000-0000-0000-000000000003', null,
          'c1300000-0000-0000-0000-000000000002'
        )
      )
    )
  )
);
reset role;

select ok(
  (select response_payload ->> 'success' = 'true'
   from recipe_effective_results where result_name = 'system-base-preview')
  and (select response_payload #>> '{preview,can_save}' = 'true'
   from recipe_effective_results where result_name = 'system-base-preview')
  and (select response_payload #>> '{preview,school_id}' is null
   from recipe_effective_results where result_name = 'system-base-preview')
  and (select response_payload #>> '{preview,school_type_id}' =
    'c1100000-0000-0000-0000-000000000010'
   from recipe_effective_results where result_name = 'system-base-preview'),
  'A07-1. SYSTEM_DISH Preview accepts Dish plus School Type without School'
);

select ok(
  exists (
    select 1
    from atlas_admin.recipe_composition_adjustments root
    where root.school_id = 'c1100000-0000-0000-0000-000000000020'
      and (
        root.scope_kind = 'SCHOOL'
        or (
          root.scope_kind = 'SCHOOL_DISH'
          and root.dish_id = 'c1300000-0000-0000-0000-000000000001'
        )
      )
  )
  and (
    select response_payload #> '{preview,before}' =
      (select authority.response_payload -> 'resolution'
       from recipe_effective_results authority
       where authority.result_name = 'system-school-exception-authority')
    from recipe_effective_results
    where result_name = 'system-add-origin-preview'
  )
  and not (
    select response_payload #> '{preview,before,lines}'
      @? '$[*].lineage[*] ? (@.scope_kind == "SCHOOL" || @.scope_kind == "SCHOOL_DISH")'
    from recipe_effective_results
    where result_name = 'system-add-origin-preview'
  ),
  'A07-2. system Preview excludes School and School-Dish layers'
);

select ok(
  not exists (
    select 1 from atlas_admin.schools school
    where school.school_type_id =
      'c1100000-0000-0000-0000-000000000011'
  )
  and (select response_payload #>> '{preview,can_save}' = 'true'
    from recipe_effective_results
    where result_name = 'system-no-school-preview'),
  'A07-3. a valid system Preview has no representative School dependency'
);

select ok(
  (select response_payload #>>
      '{preview,proposed_adjustment,target_recipe_line_id}' =
      'c1600000-0000-0000-0000-000000000003'
    and response_payload #>>
      '{preview,proposed_adjustment,adjustment_line_id}' is null
   from recipe_effective_results where result_name = 'system-base-preview')
  and exists (
    select 1
    from atlas_admin.recipe_composition_adjustments root
    where root.recipe_composition_adjustment_id =
        'c1b00000-0000-0000-0000-000000000401'
      and root.target_recipe_line_id =
        'c1600000-0000-0000-0000-000000000003'
      and root.adjustment_line_id is null
  ),
  'A07-4. base RecipeLine identity survives system Preview and Create'
);

select ok(
  (select response_payload #>>
      '{preview,proposed_adjustment,adjustment_line_id}' =
      'c1a00000-0000-0000-0000-000000000001'
    and response_payload #>>
      '{preview,proposed_adjustment,target_recipe_line_id}' is null
   from recipe_effective_results
   where result_name = 'system-add-origin-preview')
  and exists (
    select 1
    from atlas_admin.recipe_composition_adjustments root
    where root.recipe_composition_adjustment_id =
        'c1b00000-0000-0000-0000-000000000402'
      and root.adjustment_line_id =
        'c1a00000-0000-0000-0000-000000000001'
      and root.target_recipe_line_id is null
  ),
  'A07-5. prior SYSTEM_DISH ADD identity survives system Preview and Create'
);

select ok(
  (select response_payload ->> 'success' = 'true'
   from recipe_effective_results where result_name = 'system-base-create')
  and (select pg_catalog.count(*) = 1
    from atlas_admin.recipe_composition_adjustments root
    where root.recipe_composition_adjustment_id =
      'c1b00000-0000-0000-0000-000000000401')
  and (select pg_catalog.count(*) = 1
    from atlas_admin.recipe_composition_adjustment_revisions revision
    where revision.recipe_composition_adjustment_id =
      'c1b00000-0000-0000-0000-000000000401'
      and revision.revision_number = 1)
  and (select pg_catalog.count(*) = 1
    from atlas_core.command_receipts receipt
    where receipt.idempotency_key = 'recipe-system-context:base-create')
  and (select pg_catalog.count(*) = 1
    from atlas_audit.domain_events event
    where event.aggregate_id =
      'c1b00000-0000-0000-0000-000000000401'
      and event.event_type = 'RecipeCompositionAdjustmentCreated')
  and (select pg_catalog.count(*) = 1
    from atlas_audit.audit_events event
    where event.aggregate_id =
      'c1b00000-0000-0000-0000-000000000401'
      and event.event_type = 'RecipeCompositionAdjustmentCreated'),
  'A07-6. Create persists one root, revision, receipt, event, and audit record'
);

select ok(
  (select response_payload ->> 'success' = 'true'
   from recipe_effective_results where result_name = 'system-base-supersede')
  and exists (
    select 1
    from atlas_admin.recipe_composition_adjustments root
    where root.recipe_composition_adjustment_id =
        'c1b00000-0000-0000-0000-000000000401'
      and root.version = 2
      and root.current_revision_number = 2
      and root.current_revision_id =
        'c1c00000-0000-0000-0000-000000000404'
      and root.target_recipe_line_id =
        'c1600000-0000-0000-0000-000000000003'
      and root.adjustment_line_id is null
  )
  and exists (
    select 1
    from atlas_admin.recipe_composition_adjustment_revisions revision
    where revision.recipe_composition_adjustment_revision_id =
        'c1c00000-0000-0000-0000-000000000404'
      and revision.predecessor_revision_id =
        'c1c00000-0000-0000-0000-000000000401'
  )
  and (select revision_payload = pg_catalog.to_jsonb(revision)
    from recipe_system_old_revision snapshot
    cross join atlas_admin.recipe_composition_adjustment_revisions revision
    where revision.recipe_composition_adjustment_revision_id =
      'c1c00000-0000-0000-0000-000000000401')
  and atlas_core.recipe_effective_resolve_composition(
    '2026-09-06', null,
    'c1300000-0000-0000-0000-000000000002',
    'c1100000-0000-0000-0000-000000000010'
  ) -> 'lines' @? '$[*] ? (@.base_recipe_line_id == "c1600000-0000-0000-0000-000000000003" && @.final_quantity_per_basis == 0.85)'
  and not atlas_core.recipe_effective_resolve_composition(
    '2026-09-06', null,
    'c1300000-0000-0000-0000-000000000002',
    'c1100000-0000-0000-0000-000000000010'
  ) -> 'lines'
    @? '$[*].lineage[*] ? (@.scope_kind == "SCHOOL" || @.scope_kind == "SCHOOL_DISH")',
  'A07-7. Supersede preserves predecessor, version, target, system resolution, and old revision'
);

select ok(
  (select response_payload ->> 'error_code' = 'VALIDATION_FAILED'
   from recipe_effective_results where result_name = 'system-mismatched-type')
  and (select response_payload ->> 'error_code' = 'VALIDATION_FAILED'
   from recipe_effective_results where result_name = 'system-noncanonical-type')
  and (select response_payload ->> 'error_code' = 'VALIDATION_FAILED'
   from recipe_effective_results where result_name = 'system-inactive-type')
  and (select response_payload ->> 'error_code' = 'VALIDATION_FAILED'
   from recipe_effective_results where result_name = 'system-mixed-context')
  and (select response_payload ->> 'error_code' = 'VALIDATION_FAILED'
   from recipe_effective_results
   where result_name = 'system-invalid-proxy-school')
  and (select response_payload ->> 'error_code' = 'VALIDATION_FAILED'
   from recipe_effective_results where result_name = 'system-missing-context')
  and (select response_payload ->> 'error_code' = 'VALIDATION_FAILED'
   from recipe_effective_results where result_name = 'system-wrong-dish')
  and (select response_payload ->> 'error_code' = 'VALIDATION_FAILED'
   from recipe_effective_results
   where result_name = 'system-create-context-mismatch')
  and (select response_payload ->> 'error_code' = 'VALIDATION_FAILED'
   from recipe_effective_results
   where result_name = 'system-create-proxy-school')
  and (select response_payload ->> 'error_code' = 'VALIDATION_FAILED'
   from recipe_effective_results
   where result_name = 'system-base-supersede-context-mismatch')
  and not exists (
    select 1
    from atlas_admin.recipe_composition_adjustments root
    where root.recipe_composition_adjustment_id in (
      'c1b00000-0000-0000-0000-000000000416',
      'c1b00000-0000-0000-0000-000000000417'
    )
  ),
  'A07-8. mismatched, noncanonical, inactive, mixed, missing, and wrong-Dish contexts fail closed'
);

select ok(
  (select response_payload ->> 'success' = 'true'
   from recipe_effective_results where result_name = 'adjustment-target-create')
  and (select response_payload #>> '{preview,can_save}' = 'true'
   from recipe_effective_results where result_name = 'adjustment-target-preview'),
  'A07-9. existing School and School-Dish context remains compatible'
);

select ok(
  (select response_payload from recipe_effective_results
   where result_name = 'system-base-create-replay') =
  (select response_payload from recipe_effective_results
   where result_name = 'system-base-create')
  and (select response_payload ->> 'error_code' = 'IDEMPOTENCY_CONFLICT'
   from recipe_effective_results
   where result_name = 'system-base-create-context-conflict')
  and (select response_payload ->> 'error_code' = 'STALE_VERSION'
   from recipe_effective_results
   where result_name = 'system-base-supersede-stale'),
  'A07-10. exact replay, context-hash conflict, and stale version remain protected'
);

select ok(
  has_function_privilege(
    'authenticated',
    'atlas_api.preview_recipe_composition_adjustment(jsonb)',
    'EXECUTE'
  )
  and has_function_privilege(
    'authenticated',
    'atlas_api.create_recipe_composition_adjustment(jsonb)',
    'EXECUTE'
  )
  and has_function_privilege(
    'authenticated',
    'atlas_api.supersede_recipe_composition_adjustment(jsonb)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'atlas_api.preview_recipe_composition_adjustment(jsonb)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'atlas_api.create_recipe_composition_adjustment(jsonb)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'atlas_api.supersede_recipe_composition_adjustment(jsonb)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'service_role',
    'atlas_api.preview_recipe_composition_adjustment(jsonb)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'service_role',
    'atlas_api.create_recipe_composition_adjustment(jsonb)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'service_role',
    'atlas_api.supersede_recipe_composition_adjustment(jsonb)',
    'EXECUTE'
  )
  and not exists (
    select 1
    from (values
      ('preview_recipe_composition_adjustment', 'atlas_read_runtime', 's'),
      ('create_recipe_composition_adjustment',
        'atlas_master_data_command_runtime', 'v'),
      ('supersede_recipe_composition_adjustment',
        'atlas_master_data_command_runtime', 'v')
    ) expected(function_name, owner_name, volatility)
    left join pg_catalog.pg_proc procedure
      on procedure.proname = expected.function_name
    left join pg_catalog.pg_namespace namespace
      on namespace.oid = procedure.pronamespace
      and namespace.nspname = 'atlas_api'
    where namespace.oid is null
      or pg_catalog.pg_get_userbyid(procedure.proowner) <> expected.owner_name
      or not procedure.prosecdef
      or procedure.provolatile::text <> expected.volatility
      or procedure.proconfig is distinct from array['search_path=""']::text[]
  )
  and (select response_payload ->> 'error_code' = 'AUTH_SUBJECT_MISMATCH'
   from recipe_effective_results where result_name = 'system-subject-mismatch')
  and (select response_payload ->> 'error_code' = 'CAPABILITY_DENIED'
   from recipe_effective_results where result_name = 'system-capability-denied')
  and not has_table_privilege(
    'authenticated',
    'atlas_admin.recipe_composition_adjustments',
    'SELECT'
  )
  and not has_table_privilege(
    'authenticated',
    'atlas_admin.recipe_composition_adjustment_revisions',
    'SELECT'
  ),
  'A07-11. browser-key execution retains authenticated-only RPC grants'
);

select * from finish();
rollback;
