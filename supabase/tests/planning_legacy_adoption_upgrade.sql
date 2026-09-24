begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
select plan(18);

select is(
  (
    select count(*)
    from atlas_legacy.recipe_unit_adoption_evidence
    where import_batch_id = 'd0480000-0000-0000-0000-000000000080'
  ),
  2::bigint,
  'the real migration records one correction evidence row per eligible mismatch'
);

select is(
  (
    select count(*)
    from atlas_admin.recipe_versions
    where predecessor_recipe_version_id = 'd0480000-0000-0000-0000-000000000050'
  ),
  1::bigint,
  'the migration creates exactly one successor for the affected Recipe version'
);

select is(
  (
    select recipe_version_id
    from atlas_admin.recipe_versions
    where predecessor_recipe_version_id = 'd0480000-0000-0000-0000-000000000050'
  ),
  md5(
    'OPS_V1:UNIT_ADOPTION_RECIPE_VERSION:' ||
    'd0480000-0000-0000-0000-000000000050'
  )::uuid,
  'the successor Recipe version identity is deterministic'
);

select is(
  (
    select recipe_version_status
    from atlas_admin.recipe_versions
    where recipe_version_id = 'd0480000-0000-0000-0000-000000000050'
  ),
  'LOCKED',
  'the released predecessor becomes immutable'
);

select is(
  (
    select recipe_version_status
    from atlas_admin.recipe_versions
    where predecessor_recipe_version_id = 'd0480000-0000-0000-0000-000000000050'
  ),
  'RELEASED_FOR_PLANNING',
  'the immutable successor becomes the released Recipe version'
);

select is(
  (
    select version_number
    from atlas_admin.recipe_versions
    where predecessor_recipe_version_id = 'd0480000-0000-0000-0000-000000000050'
  ),
  2,
  'the successor advances the Recipe version number exactly once'
);

select is(
  (
    select count(*)
    from atlas_admin.recipe_line_revisions revision
    join atlas_admin.recipe_versions version
      on version.recipe_version_id = revision.recipe_version_id
    where version.predecessor_recipe_version_id = 'd0480000-0000-0000-0000-000000000050'
      and revision.line_disposition = 'PRESENT'
  ),
  3::bigint,
  'the successor preserves all three PRESENT lines'
);

select is(
  (
    select count(*)
    from atlas_legacy.recipe_unit_adoption_evidence evidence
    join atlas_admin.recipe_line_revisions predecessor
      on predecessor.recipe_line_revision_id = evidence.predecessor_recipe_line_revision_id
    join atlas_admin.recipe_line_revisions successor
      on successor.recipe_line_revision_id = evidence.target_recipe_line_revision_id
    where evidence.import_batch_id = 'd0480000-0000-0000-0000-000000000080'
      and successor.predecessor_recipe_line_revision_id = predecessor.recipe_line_revision_id
      and successor.recipe_id = predecessor.recipe_id
      and successor.recipe_line_id = predecessor.recipe_line_id
      and successor.ingredient_id = predecessor.ingredient_id
      and successor.quantity_per_basis = predecessor.quantity_per_basis
      and successor.unit_id = evidence.corrected_unit_id
      and predecessor.unit_id = evidence.source_unit_id
      and evidence.corrected_unit_id is distinct from evidence.source_unit_id
  ),
  2::bigint,
  'both corrected lines retain direct identity, Ingredient, and numeric quantity lineage'
);

select ok(
  (
    select bool_and(
      evidence.recipe_unit_adoption_evidence_id = md5(
        'OPS_V1:UNIT_ADOPTION_CORRECTION:' ||
        evidence.target_recipe_line_revision_id::text
      )::uuid
    )
    from atlas_legacy.recipe_unit_adoption_evidence evidence
    where evidence.import_batch_id = 'd0480000-0000-0000-0000-000000000080'
  ),
  'correction evidence identities are deterministic and replay-safe'
);

select is(
  (
    select count(*)
    from atlas_admin.recipe_line_revisions predecessor
    join atlas_admin.recipe_line_revisions successor
      on successor.predecessor_recipe_line_revision_id = predecessor.recipe_line_revision_id
    join atlas_admin.recipe_versions version
      on version.recipe_version_id = successor.recipe_version_id
    where predecessor.recipe_line_revision_id = 'd0480000-0000-0000-0000-000000000072'
      and version.predecessor_recipe_version_id = 'd0480000-0000-0000-0000-000000000050'
      and successor.recipe_id = predecessor.recipe_id
      and successor.recipe_line_id = predecessor.recipe_line_id
      and successor.line_revision_number = predecessor.line_revision_number + 1
      and successor.ingredient_id = predecessor.ingredient_id
      and successor.quantity_per_basis = predecessor.quantity_per_basis
      and successor.unit_id = predecessor.unit_id
      and successor.line_disposition = predecessor.line_disposition
      and successor.calculation_kind = predecessor.calculation_kind
      and successor.operational_note is not distinct from predecessor.operational_note
  ),
  1::bigint,
  'the unaffected sibling is copied exactly through direct predecessor lineage'
);

select is(
  (
    select count(*)
    from atlas_admin.recipe_line_revisions
    where recipe_version_id = 'd0480000-0000-0000-0000-000000000050'
      and (
        (recipe_line_revision_id = 'd0480000-0000-0000-0000-000000000070'
          and quantity_per_basis = 3.8
          and unit_id = 'd0480000-0000-0000-0000-000000000010')
        or
        (recipe_line_revision_id = 'd0480000-0000-0000-0000-000000000071'
          and quantity_per_basis = 2.5
          and unit_id = 'd0480000-0000-0000-0000-000000000012')
      )
  ),
  2::bigint,
  'historical predecessor Recipe line evidence is unchanged in place'
);

select is(
  (
    select last_target_version
    from atlas_legacy.master_data_mappings
    where source_system = 'OPS_V1'
      and object_type = 'RECIPE_VERSION'
      and recipe_version_id = 'd0480000-0000-0000-0000-000000000050'
  ),
  2::bigint,
  'legacy mapping bookkeeping follows the locked predecessor version'
);

select is(
  (
    select count(*)
    from atlas_admin.recipe_versions
    where recipe_id = 'd0480000-0000-0000-0000-000000000041'
  ),
  1::bigint,
  'the native UIQ03A_SAVE Cánh gà mismatch receives no successor'
);

select is(
  (
    select recipe_version_status
    from atlas_admin.recipe_versions
    where recipe_version_id = 'd0480000-0000-0000-0000-000000000051'
  ),
  'RELEASED_FOR_PLANNING',
  'the native Cánh gà predecessor remains released and untouched'
);

select ok(
  exists(
    select 1
    from atlas_admin.recipe_line_revisions revision
    join atlas_admin.recipe_versions version
      on version.recipe_version_id = revision.recipe_version_id
    join atlas_admin.ingredients ingredient
      on ingredient.ingredient_id = revision.ingredient_id
    where revision.recipe_line_revision_id = 'd0480000-0000-0000-0000-000000000073'
      and version.source_evidence ->> 'source_kind' = 'UIQ03A_SAVE'
      and revision.unit_id = 'd0480000-0000-0000-0000-000000000015'
      and ingredient.purchase_unit_id = 'd0480000-0000-0000-0000-000000000014'
      and revision.unit_id is distinct from ingredient.purchase_unit_id
  ),
  'the native Cánh gà Unit mismatch still fails closed'
);

select is(
  (
    select count(*)
    from atlas_legacy.recipe_unit_adoption_evidence
    where recipe_id = 'd0480000-0000-0000-0000-000000000041'
  ),
  0::bigint,
  'no bounded legacy-adoption evidence is fabricated for native data'
);

select is(
  (
    select count(*)
    from atlas_admin.recipe_line_revisions revision
    join atlas_admin.recipe_versions version
      on version.recipe_version_id = revision.recipe_version_id
      and version.recipe_version_status = 'RELEASED_FOR_PLANNING'
    join atlas_admin.ingredients ingredient
      on ingredient.ingredient_id = revision.ingredient_id
    join atlas_legacy.master_data_mappings revision_mapping
      on revision_mapping.source_system = 'OPS_V1'
      and revision_mapping.object_type = 'RECIPE_LINE_REVISION'
      and revision_mapping.recipe_line_revision_id = revision.recipe_line_revision_id
    where revision.line_disposition = 'PRESENT'
      and revision.unit_id is distinct from ingredient.purchase_unit_id
      and revision_mapping.last_source_fingerprint is not null
  ),
  0::bigint,
  'the migration leaves no eligible mapped released mismatch for a replay'
);

select is(
  (
    select count(*)
    from atlas_legacy.recipe_unit_adoption_evidence evidence
    where evidence.import_batch_id = 'd0480000-0000-0000-0000-000000000080'
      and evidence.quantity_per_basis in (3.8, 2.5)
      and evidence.evidence_kind = 'OPS_V1_BOM_UNIT_TO_INGREDIENT_PURCHASE_UNIT_CORRECTION'
      and evidence.source_system = 'OPS_V1'
  ),
  2::bigint,
  'the bounded correction carries explicit provenance and unconverted quantities'
);

select * from finish();
rollback;
