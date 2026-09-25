begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
select plan(8);

select is(
  (
    select count(*)
    from atlas_legacy.import_batches batch
    cross join lateral jsonb_array_elements(batch.reconciliation -> 'actions') action(value)
    where batch.import_batch_id = 'd0480000-0000-0000-0000-000000000080'
      and action.value ->> 'object_type' = 'RECIPE_LINE_REVISION'
      and action.value ->> 'target_id' = 'd0480000-0000-0000-0000-000000000070'
      and action.value #>> '{values,recipe_id}' = 'd0480000-0000-0000-0000-000000000040'
      and action.value #>> '{values,recipe_line_id}' = 'd0480000-0000-0000-0000-000000000060'
      and action.value #>> '{values,ingredient_id}' = 'd0480000-0000-0000-0000-000000000020'
      and (action.value #>> '{values,quantity_per_basis}')::numeric = 3.8
      and action.value #>> '{values,unit_id}' = 'd0480000-0000-0000-0000-000000000010'
  ),
  2::bigint,
  'fixture contains two exact actions for the sole mismatch'
);

select is(
  (
    select count(*)
    from atlas_legacy.recipe_unit_adoption_evidence
    where import_batch_id = 'd0480000-0000-0000-0000-000000000080'
  ),
  0::bigint,
  'duplicate exact actions produce no correction evidence'
);

select is(
  (
    select count(*)
    from atlas_admin.recipe_versions
    where predecessor_recipe_version_id = 'd0480000-0000-0000-0000-000000000050'
  ),
  0::bigint,
  'duplicate exact actions produce no Recipe successor'
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
  'the duplicate-action mismatch is not rewritten in place'
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
  'the fixture isolates exactly one duplicate-action mismatch'
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
  'D-047 applies while declining the ambiguous candidate'
);

select * from finish();
rollback;
