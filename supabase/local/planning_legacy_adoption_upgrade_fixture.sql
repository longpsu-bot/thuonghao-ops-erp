-- Local-only pre-D-047 fixture. The upgrade harness resets to 20260923041223
-- before loading this data, applies the real D-047 migration, and then resets
-- to the current schema. This file must never be run against a hosted target.

do $planning_legacy_adoption_upgrade_fixture$
begin

insert into atlas_core.actors(actor_id, actor_type, display_name)
values (
  'd0480000-0000-0000-0000-000000000001',
  'HUMAN',
  'D-047 upgrade fixture operator'
);

insert into atlas_admin.units(unit_id, unit_code, unit_name, dimension_code)
values
  ('d0480000-0000-0000-0000-000000000010', 'd048-raw-qua', 'Quả', 'COUNT'),
  ('d0480000-0000-0000-0000-000000000011', 'd048-trai', 'Trái', 'COUNT'),
  ('d0480000-0000-0000-0000-000000000012', 'd048-raw-bich', 'Bịch', 'COUNT'),
  ('d0480000-0000-0000-0000-000000000013', 'd048-chai', 'Chai', 'COUNT'),
  ('d0480000-0000-0000-0000-000000000014', 'd048-kg', 'Kilogram', 'MASS'),
  ('d0480000-0000-0000-0000-000000000015', 'd048-raw-cai', 'Cái', 'COUNT');

insert into atlas_admin.ingredients(
  ingredient_id,
  ingredient_code,
  ingredient_name,
  purchase_unit_id,
  order_step
)
values
  ('d0480000-0000-0000-0000-000000000020', 'd048-thom', 'Thơm', 'd0480000-0000-0000-0000-000000000011', 1),
  ('d0480000-0000-0000-0000-000000000021', 'd048-sauce', 'Sauce', 'd0480000-0000-0000-0000-000000000013', 1),
  ('d0480000-0000-0000-0000-000000000022', 'd048-rice', 'Rice', 'd0480000-0000-0000-0000-000000000014', 1),
  ('d0480000-0000-0000-0000-000000000023', 'd048-chicken-wing', 'Cánh gà', 'd0480000-0000-0000-0000-000000000014', 1);

insert into atlas_admin.dishes(dish_id, dish_code, dish_name, dish_status)
values
  ('d0480000-0000-0000-0000-000000000030', 'd048-adopted-dish', 'D-047 adopted dish', 'ACTIVE'),
  ('d0480000-0000-0000-0000-000000000031', 'd048-native-dish', 'D-047 native dish', 'ACTIVE');

insert into atlas_admin.recipes(recipe_id, dish_id, recipe_status)
values
  ('d0480000-0000-0000-0000-000000000040', 'd0480000-0000-0000-0000-000000000030', 'ACTIVE'),
  ('d0480000-0000-0000-0000-000000000041', 'd0480000-0000-0000-0000-000000000031', 'ACTIVE');

insert into atlas_admin.recipe_versions(
  recipe_version_id,
  recipe_id,
  version_number,
  basis_portions,
  created_by_actor_id,
  source_evidence
)
values
  (
    'd0480000-0000-0000-0000-000000000050',
    'd0480000-0000-0000-0000-000000000040',
    1,
    100,
    'd0480000-0000-0000-0000-000000000001',
    '{"source_kind":"OPS_V1_MASTER_IMPORT"}'::jsonb
  ),
  (
    'd0480000-0000-0000-0000-000000000051',
    'd0480000-0000-0000-0000-000000000041',
    1,
    100,
    'd0480000-0000-0000-0000-000000000001',
    '{"source_kind":"UIQ03A_SAVE"}'::jsonb
  );

insert into atlas_admin.recipe_lines(recipe_line_id, recipe_id, line_code)
values
  ('d0480000-0000-0000-0000-000000000060', 'd0480000-0000-0000-0000-000000000040', 'd048-adopted-thom'),
  ('d0480000-0000-0000-0000-000000000061', 'd0480000-0000-0000-0000-000000000040', 'd048-adopted-sauce'),
  ('d0480000-0000-0000-0000-000000000062', 'd0480000-0000-0000-0000-000000000040', 'd048-adopted-sibling'),
  ('d0480000-0000-0000-0000-000000000063', 'd0480000-0000-0000-0000-000000000041', 'd048-native-wing');

insert into atlas_admin.recipe_line_revisions(
  recipe_line_revision_id,
  recipe_id,
  recipe_version_id,
  recipe_line_id,
  line_revision_number,
  ingredient_id,
  quantity_per_basis,
  unit_id,
  line_disposition,
  calculation_kind,
  operational_note,
  created_by_actor_id
)
values
  (
    'd0480000-0000-0000-0000-000000000070',
    'd0480000-0000-0000-0000-000000000040',
    'd0480000-0000-0000-0000-000000000050',
    'd0480000-0000-0000-0000-000000000060',
    1,
    'd0480000-0000-0000-0000-000000000020',
    3.8,
    'd0480000-0000-0000-0000-000000000010',
    'PRESENT',
    'PROPORTIONAL_PER_BASIS',
    'OPS-v1 retained Quả',
    'd0480000-0000-0000-0000-000000000001'
  ),
  (
    'd0480000-0000-0000-0000-000000000071',
    'd0480000-0000-0000-0000-000000000040',
    'd0480000-0000-0000-0000-000000000050',
    'd0480000-0000-0000-0000-000000000061',
    1,
    'd0480000-0000-0000-0000-000000000021',
    2.5,
    'd0480000-0000-0000-0000-000000000012',
    'PRESENT',
    'PROPORTIONAL_PER_BASIS',
    'OPS-v1 retained Bịch',
    'd0480000-0000-0000-0000-000000000001'
  ),
  (
    'd0480000-0000-0000-0000-000000000072',
    'd0480000-0000-0000-0000-000000000040',
    'd0480000-0000-0000-0000-000000000050',
    'd0480000-0000-0000-0000-000000000062',
    1,
    'd0480000-0000-0000-0000-000000000022',
    15,
    'd0480000-0000-0000-0000-000000000014',
    'PRESENT',
    'PROPORTIONAL_PER_BASIS',
    'Exact sibling',
    'd0480000-0000-0000-0000-000000000001'
  ),
  (
    'd0480000-0000-0000-0000-000000000073',
    'd0480000-0000-0000-0000-000000000041',
    'd0480000-0000-0000-0000-000000000051',
    'd0480000-0000-0000-0000-000000000063',
    1,
    'd0480000-0000-0000-0000-000000000023',
    8,
    'd0480000-0000-0000-0000-000000000015',
    'PRESENT',
    'PROPORTIONAL_PER_BASIS',
    'Native UIQ03A_SAVE mismatch',
    'd0480000-0000-0000-0000-000000000001'
  );

update atlas_admin.recipe_versions
set recipe_version_status = 'VALIDATED',
  validated_by_actor_id = 'd0480000-0000-0000-0000-000000000001',
  validated_at = '2026-09-01T00:00:00Z'
where recipe_version_id in (
  'd0480000-0000-0000-0000-000000000050',
  'd0480000-0000-0000-0000-000000000051'
);
set constraints atlas_admin.recipe_versions_integrity_guard immediate;
set constraints atlas_admin.recipe_versions_integrity_guard deferred;

update atlas_admin.recipe_versions
set recipe_version_status = 'RELEASED_FOR_PLANNING',
  released_by_actor_id = 'd0480000-0000-0000-0000-000000000001',
  released_at = '2026-09-01T00:01:00Z'
where recipe_version_id in (
  'd0480000-0000-0000-0000-000000000050',
  'd0480000-0000-0000-0000-000000000051'
);
set constraints atlas_admin.recipe_versions_integrity_guard immediate;
set constraints atlas_admin.recipe_versions_integrity_guard deferred;

insert into atlas_legacy.import_batches(
  import_batch_id,
  source_system,
  snapshot_id,
  snapshot_checksum,
  exported_at,
  import_status,
  source_counts,
  reconciliation,
  completed_at,
  operator_actor_id,
  execution_database_principal,
  plan_checksum,
  snapshot_contract_version
)
values (
  'd0480000-0000-0000-0000-000000000080',
  'OPS_V1',
  'd048-upgrade-snapshot',
  repeat('b', 64),
  '2026-09-01T00:00:00Z',
  'COMPLETED',
  '{"recipe_line_revisions":2}'::jsonb,
  jsonb_build_object(
    'actions',
    jsonb_build_array(
      jsonb_build_object(
        'object_type', 'RECIPE_LINE_REVISION',
        'target_id', 'd0480000-0000-0000-0000-000000000070',
        'values', jsonb_build_object(
          'recipe_id', 'd0480000-0000-0000-0000-000000000040',
          'recipe_line_id', 'd0480000-0000-0000-0000-000000000060',
          'ingredient_id', 'd0480000-0000-0000-0000-000000000020',
          'quantity_per_basis', 3.8,
          'unit_id', 'd0480000-0000-0000-0000-000000000010'
        )
      ),
      jsonb_build_object(
        'object_type', 'RECIPE_LINE_REVISION',
        'target_id', 'd0480000-0000-0000-0000-000000000071',
        'values', jsonb_build_object(
          'recipe_id', 'd0480000-0000-0000-0000-000000000040',
          'recipe_line_id', 'd0480000-0000-0000-0000-000000000061',
          'ingredient_id', 'd0480000-0000-0000-0000-000000000021',
          'quantity_per_basis', 2.5,
          'unit_id', 'd0480000-0000-0000-0000-000000000012'
        )
      )
    )
  ),
  '2026-09-01T00:02:00Z',
  'd0480000-0000-0000-0000-000000000001',
  'postgres',
  repeat('c', 64),
  'OPS-V1-MASTER-SNAPSHOT.v1'
);

insert into atlas_legacy.master_data_mappings(
  master_data_mapping_id,
  import_batch_id,
  source_system,
  object_type,
  legacy_id,
  unit_id,
  ingredient_id,
  recipe_id,
  recipe_version_id,
  recipe_line_id,
  recipe_line_revision_id,
  last_seen_import_batch_id,
  last_source_fingerprint,
  last_target_version
)
values
  ('d0480000-0000-0000-0000-000000000081', 'd0480000-0000-0000-0000-000000000080', 'OPS_V1', 'RECIPE', 'd048-recipe', null, null, 'd0480000-0000-0000-0000-000000000040', null, null, null, 'd0480000-0000-0000-0000-000000000080', repeat('a', 64), 1),
  ('d0480000-0000-0000-0000-000000000082', 'd0480000-0000-0000-0000-000000000080', 'OPS_V1', 'RECIPE_VERSION', 'd048-recipe:version:1', null, null, null, 'd0480000-0000-0000-0000-000000000050', null, null, 'd0480000-0000-0000-0000-000000000080', repeat('a', 64), 1),
  ('d0480000-0000-0000-0000-000000000083', 'd0480000-0000-0000-0000-000000000080', 'OPS_V1', 'RECIPE_LINE', 'd048-line-thom', null, null, null, null, 'd0480000-0000-0000-0000-000000000060', null, 'd0480000-0000-0000-0000-000000000080', repeat('a', 64), 1),
  ('d0480000-0000-0000-0000-000000000084', 'd0480000-0000-0000-0000-000000000080', 'OPS_V1', 'RECIPE_LINE_REVISION', 'd048-line-thom:revision:1', null, null, null, null, null, 'd0480000-0000-0000-0000-000000000070', 'd0480000-0000-0000-0000-000000000080', repeat('1', 64), 1),
  ('d0480000-0000-0000-0000-000000000085', 'd0480000-0000-0000-0000-000000000080', 'OPS_V1', 'RECIPE_LINE', 'd048-line-sauce', null, null, null, null, 'd0480000-0000-0000-0000-000000000061', null, 'd0480000-0000-0000-0000-000000000080', repeat('a', 64), 1),
  ('d0480000-0000-0000-0000-000000000086', 'd0480000-0000-0000-0000-000000000080', 'OPS_V1', 'RECIPE_LINE_REVISION', 'd048-line-sauce:revision:1', null, null, null, null, null, 'd0480000-0000-0000-0000-000000000071', 'd0480000-0000-0000-0000-000000000080', repeat('2', 64), 1),
  ('d0480000-0000-0000-0000-000000000087', 'd0480000-0000-0000-0000-000000000080', 'OPS_V1', 'INGREDIENT', '956', null, 'd0480000-0000-0000-0000-000000000020', null, null, null, null, 'd0480000-0000-0000-0000-000000000080', repeat('a', 64), 1),
  ('d0480000-0000-0000-0000-000000000088', 'd0480000-0000-0000-0000-000000000080', 'OPS_V1', 'INGREDIENT', '1012', null, 'd0480000-0000-0000-0000-000000000021', null, null, null, null, 'd0480000-0000-0000-0000-000000000080', repeat('a', 64), 1),
  ('d0480000-0000-0000-0000-000000000089', 'd0480000-0000-0000-0000-000000000080', 'OPS_V1', 'UNIT', 'Quả', 'd0480000-0000-0000-0000-000000000010', null, null, null, null, null, 'd0480000-0000-0000-0000-000000000080', repeat('a', 64), 1),
  ('d0480000-0000-0000-0000-000000000090', 'd0480000-0000-0000-0000-000000000080', 'OPS_V1', 'UNIT', 'Bịch', 'd0480000-0000-0000-0000-000000000012', null, null, null, null, null, 'd0480000-0000-0000-0000-000000000080', repeat('a', 64), 1);

end
$planning_legacy_adoption_upgrade_fixture$;
