begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
select plan(8);

select is(
  (
    select count(*)
    from atlas_legacy.master_data_mappings
    where source_system = 'OPS_V1'
      and object_type = 'UNIT'
      and unit_id = 'd0480000-0000-0000-0000-000000000011'
  ),
  0::bigint,
  'fixture omits the corrected purchase-Unit mapping for the sole mismatch'
);

select is(
  (
    select count(*)
    from atlas_legacy.recipe_unit_adoption_evidence
    where import_batch_id = 'd0480000-0000-0000-0000-000000000080'
  ),
  0::bigint,
  'missing corrected-Unit mapping produces no correction evidence'
);

select is(
  (
    select count(*)
    from atlas_admin.recipe_versions
    where predecessor_recipe_version_id = 'd0480000-0000-0000-0000-000000000050'
  ),
  0::bigint,
  'missing corrected-Unit mapping produces no Recipe successor'
);

select is(
  (
    select recipe_version_status
    from atlas_admin.recipe_versions
    where recipe_version_id = 'd0480000-0000-0000-0000-000000000050'
  ),
  'RELEASED_FOR_PLANNING',
  'the rejected predecessor remains released and unchanged'
);

select ok(
  exists(
    select 1
    from atlas_admin.recipe_line_revisions revision
    join atlas_admin.ingredients ingredient
      on ingredient.ingredient_id = revision.ingredient_id
    where revision.recipe_line_revision_id = 'd0480000-0000-0000-0000-000000000070'
      and revision.quantity_per_basis = 3.8
      and revision.unit_id = 'd0480000-0000-0000-0000-000000000010'
      and ingredient.purchase_unit_id = 'd0480000-0000-0000-0000-000000000011'
  ),
  'the incomplete-authority mismatch is not rewritten in place'
);

select is(
  (
    select count(*)
    from atlas_admin.recipe_line_revisions revision
    join atlas_admin.ingredients ingredient
      on ingredient.ingredient_id = revision.ingredient_id
    where revision.recipe_version_id = 'd0480000-0000-0000-0000-000000000050'
      and revision.line_disposition = 'PRESENT'
      and revision.unit_id is distinct from ingredient.purchase_unit_id
  ),
  1::bigint,
  'the fixture isolates exactly one missing-authority mismatch'
);

select is(
  (
    select count(*)
    from atlas_admin.recipe_versions
    where recipe_id = 'd0480000-0000-0000-0000-000000000041'
  ),
  1::bigint,
  'native UIQ03A_SAVE history remains untouched'
);

select is(
  (
    select count(*)
    from supabase_migrations.schema_migrations
    where version = '20260924030542'
  ),
  1::bigint,
  'D-047 applies while declining the incomplete candidate'
);

select * from finish();
rollback;
