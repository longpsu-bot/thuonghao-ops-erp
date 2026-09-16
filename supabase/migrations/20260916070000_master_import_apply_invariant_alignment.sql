-- Repair approved typed Dish identity and transactional supplier-priority replacement.
-- Keep existing index names/ACLs/validation; no data edits, disabled checks or new API.
set role atlas_owner;
do $typed_dish_index$
begin
lock table atlas_admin.dishes in share row exclusive mode;
drop index atlas_admin.dishes_active_normalized_name_key;
create unique index dishes_active_normalized_name_key
  on atlas_admin.dishes(dish_type_id,lower(btrim(dish_name))) nulls not distinct
  where dish_status='ACTIVE';
comment on index atlas_admin.dishes_active_normalized_name_key is
  'Active normalized Dish names are unique inside their Dish Type; unclassified null types share one uniqueness scope.';

end $typed_dish_index$;

reset role;
do $align_runtime$
declare item record; definition text;
begin
 for item in select * from (values
   ('atlas_api.create_dish(jsonb)',
     '      and pg_catalog.lower(pg_catalog.btrim(dish.dish_name)) = v_normalized_name',
     E'      and dish.dish_type_id is not distinct from v_dish_type_id\n      and pg_catalog.lower(pg_catalog.btrim(dish.dish_name)) = v_normalized_name'),
   ('atlas_api.update_dish(jsonb)',
     '      and other_dish.dish_status = ''ACTIVE''',
     E'      and other_dish.dish_status = ''ACTIVE''\n      and other_dish.dish_type_id is not distinct from v_dish_type_id'),
   ('atlas_api.set_dish_lifecycle(jsonb)',
     '      and other_dish.dish_status = ''ACTIVE''',
     E'      and other_dish.dish_status = ''ACTIVE''\n      and other_dish.dish_type_id is not distinct from v_dish.dish_type_id'),
   ('atlas_api.save_recipe(jsonb)',
     '      and other_dish.dish_status = ''ACTIVE''',
     E'      and other_dish.dish_status = ''ACTIVE''\n      and other_dish.dish_type_id is not distinct from v_dish.dish_type_id')
 ) patches(signature,old_text,new_text) loop
   select pg_get_functiondef(item.signature::regprocedure) into definition;
   if (length(definition)-length(replace(definition,item.old_text,'')))/length(item.old_text)<>1 then
     raise exception 'TYPED_DISH_RUNTIME_PREDECESSOR_DRIFT: %',item.signature;
   end if;
   execute replace(definition,item.old_text,item.new_text);
 end loop;
end $align_runtime$;

set role atlas_owner;
do $priority_apply$
declare definition text;
 marker constant text := $old$  for a in select x.value from jsonb_array_elements(p->'actions') x where x.value->>'object_type' not in ('DISH','RECIPE','RECIPE_VERSION','RECIPE_LINE','RECIPE_LINE_REVISION') loop$old$;
 replacement constant text := $new$  -- Release only changed mapped priority slots inside this locked transaction.
  -- All final values are then assigned by the normal writer; no intermediate value commits.
  update atlas_admin.supplier_eligibilities e set priority=null
    where e.supplier_eligibility_id in (
      select (x.value->>'target_id')::uuid from jsonb_array_elements(p->'actions') x
      where x.value->>'object_type'='SUPPLIER_ELIGIBILITY'
        and x.value->>'action' in ('UPDATE','REMOVE_RELATIONSHIP','EXPLICIT_INACTIVATE')
    ) and e.priority is not null;
  for a in select x.value from jsonb_array_elements(p->'actions') x where x.value->>'object_type' not in ('DISH','RECIPE','RECIPE_VERSION','RECIPE_LINE','RECIPE_LINE_REVISION') loop$new$;
begin
 select pg_get_functiondef('atlas_legacy.apply_master_data_snapshot(jsonb,text,uuid)'::regprocedure) into definition;
 if (length(definition)-length(replace(definition,marker,'')))/length(marker)<>1 then
   raise exception 'MASTER_PRIORITY_APPLY_PREDECESSOR_DRIFT';
 end if;
 execute replace(definition,marker,replacement);
end $priority_apply$;
reset role;

-- Preserve machine-safe constraint identity through the private importer; never log row/error text.
set role atlas_owner;
do $diagnostics$
declare definition text; item record;
begin
 select pg_get_functiondef('atlas_legacy.apply_master_data_snapshot(jsonb,text,uuid)'::regprocedure) into definition;
 for item in select * from (values
  ($old$counts jsonb; target_before jsonb; fps jsonb;$old$,
   $new$counts jsonb; target_before jsonb; fps jsonb; apply_phase text:='PREVIEW'; failed_constraint text; failed_table text; failed_schema text;$new$),
  ($old$  for a in select x.value from jsonb_array_elements(p->'actions') x where x.value->>'object_type' not in ($old$,
   $new$  apply_phase:='CORE_ROWS';
  for a in select x.value from jsonb_array_elements(p->'actions') x where x.value->>'object_type' not in ($new$),
  ($old$  perform atlas_legacy.master_import_apply_recipes(snapshot,p,operator_actor_id);$old$,
   $new$  apply_phase:='RECIPES';
  perform atlas_legacy.master_import_apply_recipes(snapshot,p,operator_actor_id);$new$),
  ($old$  for a in select x.value from jsonb_array_elements(p->'actions') x loop$old$,
   $new$  apply_phase:='MAPPINGS';
  for a in select x.value from jsonb_array_elements(p->'actions') x loop$new$),
  ($old$  after_plan:=atlas_legacy.preview_master_data_snapshot(snapshot);$old$,
   $new$  apply_phase:='READBACK';
  after_plan:=atlas_legacy.preview_master_data_snapshot(snapshot);$new$),
  ($old$  when check_violation or foreign_key_violation or unique_violation or not_null_violation then return jsonb_build_object('success',false,'status','REJECTED','error_code','APPLY_INVARIANT_FAILURE','constraint_state',sqlstate);$old$,
   $new$  when check_violation or foreign_key_violation or unique_violation or not_null_violation then
    get stacked diagnostics failed_constraint=constraint_name,failed_table=table_name,failed_schema=schema_name;
    return jsonb_build_object('success',false,'status','REJECTED','error_code','APPLY_INVARIANT_FAILURE','constraint_state',sqlstate,
      'apply_phase',apply_phase,
      'constraint_name',case when failed_constraint ~ '^[a-z_][a-z0-9_]{0,62}$' then failed_constraint end,
      'constraint_table',case when failed_table ~ '^[a-z_][a-z0-9_]{0,62}$' then failed_table end,
      'constraint_schema',case when failed_schema ~ '^atlas_[a-z_]+$' then failed_schema end);$new$)
 ) patches(old_text,new_text) loop
   if (length(definition)-length(replace(definition,item.old_text,'')))/length(item.old_text)<>1 then
     raise exception 'MASTER_APPLY_DIAGNOSTIC_PREDECESSOR_DRIFT';
   end if;
   definition:=replace(definition,item.old_text,item.new_text);
 end loop;
 execute definition;
end $diagnostics$;
reset role;
