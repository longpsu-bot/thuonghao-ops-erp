-- Leave one mapped mismatch and remove its corrected purchase-Unit mapping.
-- The D-047 migration must not treat the incomplete authority as eligible.
do $planning_legacy_adoption_missing_corrected_unit_mapping$
begin
  update atlas_admin.ingredients
  set purchase_unit_id = 'd0480000-0000-0000-0000-000000000012'
  where ingredient_id = 'd0480000-0000-0000-0000-000000000021';

  delete from atlas_legacy.master_data_mappings
  where source_system = 'OPS_V1'
    and object_type = 'UNIT'
    and unit_id = 'd0480000-0000-0000-0000-000000000011';
end
$planning_legacy_adoption_missing_corrected_unit_mapping$;
