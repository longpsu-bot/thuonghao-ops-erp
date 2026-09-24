-- Leave one mapped mismatch and duplicate its exact reconciliation action.
-- The D-047 migration must not treat the duplicate as authoritative.
do $planning_legacy_adoption_duplicate_action$
begin
  update atlas_admin.ingredients
  set purchase_unit_id = 'd0480000-0000-0000-0000-000000000012'
  where ingredient_id = 'd0480000-0000-0000-0000-000000000021';

  update atlas_legacy.import_batches
  set reconciliation = jsonb_set(
    reconciliation,
    '{actions}',
    (reconciliation -> 'actions') || (reconciliation -> 'actions' -> 0)
  )
  where import_batch_id = 'd0480000-0000-0000-0000-000000000080';
end
$planning_legacy_adoption_duplicate_action$;
