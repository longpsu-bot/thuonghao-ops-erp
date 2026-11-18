-- Session-local planner. The catch-up transaction owns locks, writes and receipts.
create or replace function pg_temp.planning_catalog_recipe_differences(snapshot jsonb, dish_actions jsonb)
returns jsonb language sql stable set search_path='' as $$
  with source_roots as (
    select r.legacy_id,r.recipe_status from jsonb_to_recordset(snapshot#>'{records,recipes}')
      r(legacy_id text,recipe_status text)
  ), source_lines as (
    select l.recipe_legacy_id, jsonb_agg(jsonb_build_array(i.ingredient_id,u.unit_id,l.quantity_per_basis,l.operational_note)
      order by i.ingredient_id,l.ingredient_legacy_id) as facts
    from jsonb_to_recordset(snapshot#>'{records,recipe_lines}')
      l(recipe_legacy_id text,ingredient_legacy_id text,unit_legacy_id text,quantity_per_basis numeric,operational_note text)
    left join atlas_legacy.master_data_mappings i on i.source_system='OPS_V1' and i.object_type='INGREDIENT' and i.legacy_id=l.ingredient_legacy_id
    left join atlas_legacy.master_data_mappings u on u.source_system='OPS_V1' and u.object_type='UNIT' and u.legacy_id=l.unit_legacy_id
    group by l.recipe_legacy_id
  ), target_roots as (
    select m.legacy_id,r.recipe_status,v.basis_portions,l.facts
    from atlas_legacy.master_data_mappings m
    join atlas_admin.recipes r on r.recipe_id=m.recipe_id
    left join lateral (select v.recipe_version_id,v.basis_portions from atlas_admin.recipe_versions v
      where v.recipe_id=r.recipe_id and v.recipe_version_status='RELEASED_FOR_PLANNING'
      order by v.version_number desc limit 1) v on true
    left join lateral (select jsonb_agg(jsonb_build_array(l.ingredient_id,l.unit_id,l.quantity_per_basis,l.operational_note)
      order by l.ingredient_id) as facts from atlas_admin.recipe_line_revisions l
      where l.recipe_version_id=v.recipe_version_id and l.line_disposition='PRESENT') l on true
    where m.source_system='OPS_V1' and m.object_type='RECIPE'
  )
  select coalesce(jsonb_agg(jsonb_build_object('object_type','RECIPE','legacy_id',coalesce(s.legacy_id,t.legacy_id),
    'code',case when s.legacy_id is null then 'MISSING_FROM_SOURCE' when t.legacy_id is null then 'RECIPE_MAPPING_MISSING' else 'RECIPE_COMPOSITION_REVIEW' end)
    order by coalesce(s.legacy_id,t.legacy_id) collate "C"),'[]')
  from source_roots s full join target_roots t using(legacy_id) left join source_lines l on l.recipe_legacy_id=s.legacy_id
  where (s.legacy_id is null or t.legacy_id is null or s.recipe_status is distinct from t.recipe_status
    or coalesce(l.facts,'[]') is distinct from coalesce(t.facts,'[]') or coalesce(t.basis_portions,100)<>100)
    and not exists(select 1 from jsonb_array_elements(dish_actions) a where a.value->>'object_type'='RECIPE'
      and a.value->>'legacy_id'=s.legacy_id and a.value->>'action'='CREATE');
$$;

create or replace function pg_temp.planning_catalog_actions(snapshot jsonb, dish_actions jsonb)
returns jsonb language plpgsql stable set search_path='' as $$
declare
  kind text; entity text; row_source jsonb; legacy text; target uuid;
  mapping atlas_legacy.master_data_mappings%rowtype;
  current_row jsonb; desired jsonb; fields jsonb; name_field text;
  action text; reason text; status text; source_hash text;
  actions jsonb := '[]'; differences jsonb := '[]'; candidates jsonb;
begin
  foreach kind in array array['SCHOOL_TYPE','CUSTOMER','DELIVERY_LOCATION','SCHOOL',
    'UNIT','INGREDIENT_TYPE','INGREDIENT_ORDER_GROUP','DISH_TYPE','DISH','INGREDIENT','SUPPLIER','SUPPLIER_ELIGIBILITY']
  loop
    entity := atlas_legacy.master_import_entity(kind);
    for row_source in select r.value from jsonb_array_elements(snapshot#>array['records',entity]) r
      order by r.value->>'legacy_id' collate "C"
    loop
      legacy := row_source->>'legacy_id';
      if exists (select 1 from jsonb_array_elements(dish_actions) a
        where a.value->>'object_type'=kind and a.value->>'legacy_id'=legacy and a.value->>'action'='CREATE') then continue; end if;
      target := atlas_legacy.master_import_target_id(snapshot,kind,legacy);
      select * into mapping from atlas_legacy.master_data_mappings m
        where m.source_system='OPS_V1' and m.object_type=kind and m.legacy_id=legacy;
      current_row := atlas_legacy.master_import_read(kind,target);
      desired := case kind
        when 'DISH' then jsonb_build_object('dish_code',row_source->>'dish_code','dish_name',row_source->>'dish_name',
          'dish_type_id',atlas_legacy.master_import_target_id(snapshot,'DISH_TYPE',row_source->>'dish_type_legacy_id'),'dish_status',row_source->>'dish_status')
        when 'INGREDIENT_TYPE' then jsonb_build_object('ingredient_type_name',row_source->>'ingredient_type_name')
        when 'INGREDIENT_ORDER_GROUP' then jsonb_build_object('ingredient_order_group_name',row_source->>'ingredient_order_group_name')
        when 'DISH_TYPE' then jsonb_build_object('dish_type_code',row_source->>'dish_type_code','dish_type_name',row_source->>'dish_type_name')
        else atlas_legacy.master_import_values(snapshot,kind,row_source,target)
      end;
      select coalesce(jsonb_agg(k order by k),'[]') into fields
        from jsonb_object_keys(desired) k
        where current_row->k is distinct from desired->k
          and (kind<>'SUPPLIER_ELIGIBILITY' or k not in ('effective_from','effective_to','reason_note'));
      if mapping.legacy_id is not null and current_row is not null and fields='[]'::jsonb then continue; end if;

      action := null;
      reason := null;
      name_field := case kind when 'INGREDIENT' then 'ingredient_name' when 'SUPPLIER' then 'supplier_name' end;
      status := coalesce(desired->>'ingredient_status',desired->>'supplier_status',desired->>'eligibility_status');
      source_hash := atlas_legacy.master_snapshot_hash(row_source-'source_record_id');
      candidates := dish_actions || actions;
      if kind not in ('INGREDIENT','SUPPLIER','SUPPLIER_ELIGIBILITY') then
        reason := 'CATALOG_AUTHORITY_REVIEW';
      elsif exists (select 1 from jsonb_array_elements(snapshot->'source_diagnostics') i
        where i.value->>'severity'='BLOCKER' and i.value->>'entity'=entity
          and (i.value->>'legacy_id' is null or i.value->>'legacy_id'=legacy)) then
        reason := 'SOURCE_VALIDATION_BLOCKED';
      elsif desired is null or target is null
        or atlas_legacy.master_import_validate_values(kind,legacy,row_source,desired)<>'[]'::jsonb then
        reason := 'CATALOG_VALUE_INVALID';
      elsif atlas_legacy.master_import_collision(kind,target,desired) then
        reason := 'CATALOG_CODE_COLLISION';
      elsif kind='INGREDIENT' and (
        not exists(select 1 from atlas_admin.ingredient_types t where t.ingredient_type_id=(desired->>'ingredient_type_id')::uuid and t.ingredient_type_status='ACTIVE')
        or not exists(select 1 from atlas_admin.ingredient_order_groups g where g.ingredient_order_group_id=(desired->>'ingredient_order_group_id')::uuid and g.ingredient_order_group_status='ACTIVE')
        or not exists(select 1 from atlas_admin.units u where u.unit_id=(desired->>'purchase_unit_id')::uuid and u.unit_status='ACTIVE')) then
        reason := 'INACTIVE_OR_MISSING_CATALOG_DEPENDENCY';
      elsif kind='SUPPLIER' and lower(desired->>'supplier_name') ~ '(xoá|xóa) hoặc thay thế' then
        reason := 'SOURCE_NAME_REQUIRES_REVIEW';
      elsif (kind='INGREDIENT' and exists(select 1 from atlas_admin.ingredients i where i.ingredient_id<>target and i.ingredient_status='ACTIVE' and lower(btrim(i.ingredient_name))=lower(btrim(desired->>name_field))))
        or (kind='SUPPLIER' and exists(select 1 from atlas_admin.suppliers s where s.supplier_id<>target and s.supplier_status='ACTIVE' and lower(btrim(s.supplier_name))=lower(btrim(desired->>name_field))))
        or (name_field is not null and exists(select 1 from jsonb_array_elements(candidates) a where a.value->>'object_type'=kind and a.value->>'action' in ('CREATE','UPDATE')
          and lower(btrim(a.value->'values'->>name_field))=lower(btrim(desired->>name_field)))) then
        reason := 'CATALOG_NAME_COLLISION';
      elsif mapping.legacy_id is not null then
        if current_row is not null and name_field is not null and fields=jsonb_build_array(name_field)
          and status='ACTIVE' and coalesce(current_row->>'ingredient_status',current_row->>'supplier_status')='ACTIVE'
          and mapping.last_target_version=(current_row->>'version')::bigint
          and mapping.last_source_fingerprint is not null
          and mapping.last_source_fingerprint not in (source_hash,atlas_legacy.master_snapshot_hash(row_source)) then
          action := 'UPDATE';
        else
          reason := 'EXISTING_CATALOG_CHANGE_REQUIRES_REVIEW';
        end if;
      elsif current_row is not null then
        reason := 'UNMAPPED_ATLAS_IDENTITY';
      elsif status is distinct from 'ACTIVE' then
        reason := 'SOURCE_NOT_ACTIVE';
      elsif kind='SUPPLIER_ELIGIBILITY' and (
        not (exists(select 1 from atlas_admin.ingredients i where i.ingredient_id=(desired->>'ingredient_id')::uuid and i.ingredient_status='ACTIVE')
          or exists(select 1 from jsonb_array_elements(candidates) a where a.value->>'object_type'='INGREDIENT' and a.value->>'target_id'=desired->>'ingredient_id' and a.value->>'action'='CREATE'))
        or not (exists(select 1 from atlas_admin.suppliers s where s.supplier_id=(desired->>'supplier_id')::uuid and s.supplier_status='ACTIVE')
          or exists(select 1 from jsonb_array_elements(candidates) a where a.value->>'object_type'='SUPPLIER' and a.value->>'target_id'=desired->>'supplier_id' and a.value->>'action'='CREATE'))) then
        reason := 'UNAVAILABLE_RELATIONSHIP_ENDPOINT';
      elsif kind='SUPPLIER_ELIGIBILITY' and (
        exists(select 1 from atlas_admin.supplier_eligibilities e where e.ingredient_id=(desired->>'ingredient_id')::uuid
          and e.eligibility_status='ACTIVE' and coalesce(e.effective_to,'infinity'::date)>=(desired->>'effective_from')::date
          and (e.supplier_id=(desired->>'supplier_id')::uuid or e.priority=(desired->>'priority')::int))
        or exists(select 1 from jsonb_array_elements(candidates) a where a.value->>'object_type'='SUPPLIER_ELIGIBILITY' and a.value->>'action'='CREATE'
          and a.value#>>'{values,ingredient_id}'=desired->>'ingredient_id'
          and (a.value#>>'{values,supplier_id}'=desired->>'supplier_id' or a.value#>>'{values,priority}'=desired->>'priority'))) then
        reason := 'SUPPLIER_RELATIONSHIP_CONFLICT';
      else
        action := 'CREATE';
      end if;

      if action is not null then
        actions := actions || jsonb_build_array(atlas_legacy.master_recipe_action(kind,legacy,action,target,desired,source_hash)
          || jsonb_build_object('before_values',current_row,'dependency_reason','Reviewed standalone catalog sync'));
      else
        differences := differences || jsonb_build_array(jsonb_build_object(
          'object_type',kind,'legacy_id',legacy,'fields',fields,'code',reason));
      end if;
    end loop;
    select differences || coalesce(jsonb_agg(jsonb_build_object(
      'object_type',kind,'legacy_id',m.legacy_id,'code','MISSING_FROM_SOURCE') order by m.legacy_id),'[]')
    into differences from atlas_legacy.master_data_mappings m
    where m.source_system='OPS_V1' and m.object_type=kind
      and not exists(select 1 from jsonb_array_elements(snapshot#>array['records',entity]) r where r.value->>'legacy_id'=m.legacy_id);
  end loop;
  return jsonb_build_object('actions',actions,'catalog_differences',
    differences || pg_temp.planning_catalog_recipe_differences(snapshot,dish_actions));
end $$;
