-- Session-local planner. The catch-up transaction owns locks, writes and receipts.
create or replace function pg_temp.planning_catalog_recipe_differences(snapshot jsonb, dish_actions jsonb)
returns jsonb language sql stable set search_path='' as $$
  with source_roots as (
    select r.legacy_id,r.recipe_status from jsonb_to_recordset(snapshot#>'{records,recipes}')
      r(legacy_id text,recipe_status text)
  ), source_lines as (
    select l.recipe_legacy_id, jsonb_agg(jsonb_build_array(i.ingredient_id,
      case when exists (
        select 1 from atlas_legacy.recipe_unit_adoption_evidence e
        join atlas_admin.recipe_line_revisions revision on revision.recipe_line_revision_id=e.target_recipe_line_revision_id
        where e.recipe_id=rm.recipe_id and e.ingredient_id=i.ingredient_id
          and e.source_unit_id=u.unit_id and e.corrected_unit_id=ingredient.purchase_unit_id
          and exists(select 1 from jsonb_array_elements(snapshot#>'{records,ingredients}') source_ingredient
            join atlas_legacy.master_data_mappings source_unit on source_unit.source_system='OPS_V1' and source_unit.object_type='UNIT'
              and source_unit.legacy_id=source_ingredient.value->>'purchase_unit_legacy_id'
            where source_ingredient.value->>'legacy_id'=l.ingredient_legacy_id and source_unit.unit_id=e.corrected_unit_id)
          and e.quantity_per_basis=l.quantity_per_basis and revision.unit_id=e.corrected_unit_id
          and revision.quantity_per_basis=e.quantity_per_basis and revision.line_disposition='PRESENT'
          and e.target_recipe_version_id=(select v.recipe_version_id from atlas_admin.recipe_versions v
            where v.recipe_id=rm.recipe_id and v.recipe_version_status='RELEASED_FOR_PLANNING'
            order by v.version_number desc limit 1)
      ) then ingredient.purchase_unit_id else u.unit_id end,
      l.quantity_per_basis,l.operational_note)
      order by i.ingredient_id,l.ingredient_legacy_id) as facts
    from jsonb_to_recordset(snapshot#>'{records,recipe_lines}')
      l(recipe_legacy_id text,ingredient_legacy_id text,unit_legacy_id text,quantity_per_basis numeric,operational_note text)
    left join atlas_legacy.master_data_mappings i on i.source_system='OPS_V1' and i.object_type='INGREDIENT' and i.legacy_id=l.ingredient_legacy_id
    left join atlas_legacy.master_data_mappings u on u.source_system='OPS_V1' and u.object_type='UNIT' and u.legacy_id=l.unit_legacy_id
    left join atlas_admin.ingredients ingredient on ingredient.ingredient_id=i.ingredient_id
    left join atlas_legacy.master_data_mappings rm on rm.source_system='OPS_V1' and rm.object_type='RECIPE' and rm.legacy_id=l.recipe_legacy_id
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
  actions jsonb := '[]'; differences jsonb := '[]'; candidates jsonb; blocked_groups text[];
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
      if kind in ('INGREDIENT','SUPPLIER','SUPPLIER_ELIGIBILITY') and exists (
        select 1 from jsonb_array_elements(snapshot->'source_diagnostics') i
        where i.value->>'severity'='BLOCKER' and i.value->>'entity'=entity
          and (i.value->>'legacy_id' is null or i.value->>'legacy_id'=legacy)
      ) then
        differences := differences || jsonb_build_array(jsonb_build_object(
          'object_type',kind,'legacy_id',legacy,'code','SOURCE_VALIDATION_BLOCKED'));
        continue;
      end if;
      target := atlas_legacy.master_import_target_id(snapshot,kind,legacy);
      select * into mapping from atlas_legacy.master_data_mappings m
        where m.source_system='OPS_V1' and m.object_type=kind and m.legacy_id=legacy;
      current_row := atlas_legacy.master_import_read(kind,target);
      desired := case kind
        when 'DISH' then jsonb_build_object('dish_code',row_source->>'dish_code','dish_name',row_source->>'dish_name',
          'dish_type_id',atlas_legacy.master_import_target_id(snapshot,'DISH_TYPE',row_source->>'dish_type_legacy_id'),'dish_status',row_source->>'dish_status')
        when 'INGREDIENT_TYPE' then jsonb_build_object('ingredient_type_name',row_source->>'ingredient_type_name')
        when 'INGREDIENT_ORDER_GROUP' then jsonb_build_object('ingredient_order_group_name',row_source->>'ingredient_order_group_name')
        when 'DISH_TYPE' then jsonb_build_object('dish_type_code',row_source->>'dish_type_code','dish_type_name',row_source->>'source_name')
        else atlas_legacy.master_import_values(snapshot,kind,row_source,target)
      end;
      select coalesce(jsonb_agg(k order by k),'[]') into fields
        from jsonb_object_keys(desired) k
        where current_row->k is distinct from desired->k
          and (kind<>'SUPPLIER_ELIGIBILITY' or k not in ('effective_from','reason_note'));
      if mapping.legacy_id is not null and current_row is not null and fields='[]'::jsonb then continue; end if;

      action := null;
      reason := null;
      name_field := case kind when 'INGREDIENT' then 'ingredient_name' when 'SUPPLIER' then 'supplier_name' end;
      status := coalesce(desired->>'ingredient_status',desired->>'supplier_status',desired->>'eligibility_status');
      source_hash := atlas_legacy.master_snapshot_hash(row_source-'source_record_id');
      candidates := dish_actions || actions;
      if desired is null or target is null
        or atlas_legacy.master_import_validate_values(kind,legacy,row_source,desired)<>'[]'::jsonb then
        reason := 'CATALOG_VALUE_INVALID';
      elsif atlas_legacy.master_import_collision(kind,target,desired) then
        reason := 'CATALOG_CODE_COLLISION';
      elsif kind='SUPPLIER_ELIGIBILITY' and (
        (select count(*) from jsonb_array_elements(snapshot#>'{records,supplier_eligibilities}') sr
          where sr.value->>'ingredient_legacy_id'=row_source->>'ingredient_legacy_id'
            and sr.value->>'priority'=row_source->>'priority')<>1
        or exists(select 1 from atlas_admin.supplier_eligibilities e
          where e.supplier_eligibility_id<>target and e.ingredient_id=(desired->>'ingredient_id')::uuid and e.eligibility_status='ACTIVE'
            and (e.supplier_id=(desired->>'supplier_id')::uuid or e.priority=(desired->>'priority')::int)
            and not exists(select 1 from atlas_legacy.master_data_mappings em
              where em.source_system='OPS_V1' and em.object_type='SUPPLIER_ELIGIBILITY' and em.supplier_eligibility_id=e.supplier_eligibility_id))
      ) then
        reason := 'SUPPLIER_RELATIONSHIP_CONFLICT';
      elsif kind='INGREDIENT' and (
        not exists(select 1 from atlas_admin.ingredient_types t where t.ingredient_type_id=(desired->>'ingredient_type_id')::uuid and t.ingredient_type_status='ACTIVE')
        or not exists(select 1 from atlas_admin.ingredient_order_groups g where g.ingredient_order_group_id=(desired->>'ingredient_order_group_id')::uuid and g.ingredient_order_group_status='ACTIVE')
        or not exists(select 1 from atlas_admin.units u where u.unit_id=(desired->>'purchase_unit_id')::uuid and u.unit_status='ACTIVE')) then
        reason := 'INACTIVE_OR_MISSING_CATALOG_DEPENDENCY';
      elsif (kind='INGREDIENT' and exists(select 1 from atlas_admin.ingredients i where i.ingredient_id<>target and i.ingredient_status='ACTIVE' and lower(btrim(i.ingredient_name))=lower(btrim(desired->>name_field))))
        or (kind='SUPPLIER' and exists(select 1 from atlas_admin.suppliers s where s.supplier_id<>target and s.supplier_status='ACTIVE'
          and lower(btrim(s.supplier_name))=lower(btrim(desired->>name_field))
          and not exists(select 1 from atlas_legacy.master_data_mappings sm join jsonb_array_elements(snapshot#>'{records,suppliers}') sr
            on sr.value->>'legacy_id'=sm.legacy_id where sm.source_system='OPS_V1' and sm.object_type='SUPPLIER' and sm.supplier_id=s.supplier_id
            and lower(btrim(sr.value->>'supplier_name'))<>lower(btrim(desired->>name_field)))))
        or (name_field is not null and exists(select 1 from jsonb_array_elements(candidates) a where a.value->>'object_type'=kind and a.value->>'action' in ('CREATE','UPDATE')
          and lower(btrim(a.value->'values'->>name_field))=lower(btrim(desired->>name_field)))) then
        reason := 'CATALOG_NAME_COLLISION';
      elsif mapping.legacy_id is not null then
        if current_row is not null then
          action := 'UPDATE';
        else
          reason := 'MAPPED_CATALOG_TARGET_MISSING';
        end if;
      elsif current_row is not null then
        reason := 'UNMAPPED_ATLAS_IDENTITY';
      elsif status is distinct from 'ACTIVE' then
        reason := 'SOURCE_NOT_ACTIVE';
      elsif kind='SUPPLIER_ELIGIBILITY' and (
        not (exists(select 1 from atlas_admin.ingredients i join atlas_legacy.master_data_mappings m using(ingredient_id)
          where i.ingredient_id=(desired->>'ingredient_id')::uuid and i.ingredient_status='ACTIVE'
          and m.source_system='OPS_V1' and m.object_type='INGREDIENT' and m.legacy_id=row_source->>'ingredient_legacy_id')
          or exists(select 1 from jsonb_array_elements(candidates) a where a.value->>'object_type'='INGREDIENT' and a.value->>'target_id'=desired->>'ingredient_id' and a.value->>'action'='CREATE'))
        or not (exists(select 1 from atlas_admin.suppliers s join atlas_legacy.master_data_mappings m using(supplier_id)
          where s.supplier_id=(desired->>'supplier_id')::uuid and s.supplier_status='ACTIVE'
          and m.source_system='OPS_V1' and m.object_type='SUPPLIER' and m.legacy_id=row_source->>'supplier_legacy_id')
          or exists(select 1 from jsonb_array_elements(candidates) a where a.value->>'object_type'='SUPPLIER' and a.value->>'target_id'=desired->>'supplier_id' and a.value->>'action'='CREATE'))) then
        reason := 'UNAVAILABLE_RELATIONSHIP_ENDPOINT';
      elsif kind='SUPPLIER_ELIGIBILITY' and (
        exists(select 1 from atlas_admin.supplier_eligibilities e where e.ingredient_id=(desired->>'ingredient_id')::uuid
          and e.eligibility_status='ACTIVE'
          and (e.supplier_id=(desired->>'supplier_id')::uuid or e.priority=(desired->>'priority')::int)
          and not exists(select 1 from atlas_legacy.master_data_mappings em
            where em.source_system='OPS_V1' and em.object_type='SUPPLIER_ELIGIBILITY' and em.supplier_eligibility_id=e.supplier_eligibility_id))
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
    for mapping in select * from atlas_legacy.master_data_mappings m
      where m.source_system='OPS_V1' and m.object_type=kind
        and not exists(select 1 from jsonb_array_elements(snapshot#>array['records',entity]) r where r.value->>'legacy_id'=m.legacy_id)
    loop
      target := (to_jsonb(mapping)->>atlas_legacy.master_import_mapping_column(kind))::uuid;
      current_row := atlas_legacy.master_import_read(kind,target);
      if kind='SUPPLIER_ELIGIBILITY' and current_row->>'eligibility_status'='ACTIVE' then
        desired := (current_row-'supplier_eligibility_id'-'version') || jsonb_build_object(
          'eligibility_status','INACTIVE','effective_to',greatest((snapshot->>'exported_at')::timestamptz::date,(current_row->>'effective_from')::date+1));
        actions := actions || jsonb_build_array(atlas_legacy.master_recipe_action(kind,mapping.legacy_id,'UPDATE',target,desired,
          atlas_legacy.master_snapshot_hash(jsonb_build_object('membership','ABSENT','legacy_id',mapping.legacy_id)))
          || jsonb_build_object('before_values',current_row,'absent_from_source',true,'dependency_reason','V1 authoritative relationship membership'));
      elsif kind<>'SUPPLIER_ELIGIBILITY' then
        differences := differences || jsonb_build_array(jsonb_build_object('object_type',kind,'legacy_id',mapping.legacy_id,'code','MISSING_FROM_SOURCE'));
      end if;
    end loop;
  end loop;
  -- A source-invalid membership blocks the whole Ingredient list, including slot moves.
  select array_agg(distinct split_part(d.value->>'legacy_id',':',2)) into blocked_groups
    from jsonb_array_elements(differences) d where d.value->>'object_type'='SUPPLIER_ELIGIBILITY';
  if coalesce(cardinality(blocked_groups),0)>0 then
    select differences || coalesce(jsonb_agg(jsonb_build_object('object_type','SUPPLIER_ELIGIBILITY',
      'legacy_id',a.value->>'legacy_id','code','SOURCE_RELATIONSHIP_GROUP_BLOCKED')),'[]')
    into differences from jsonb_array_elements(actions) a where a.value->>'object_type'='SUPPLIER_ELIGIBILITY'
      and split_part(a.value->>'legacy_id',':',2)=any(blocked_groups);
    select coalesce(jsonb_agg(a.value order by a.ordinality),'[]') into actions
      from jsonb_array_elements(actions) with ordinality a(value,ordinality)
      where not (a.value->>'object_type'='SUPPLIER_ELIGIBILITY' and split_part(a.value->>'legacy_id',':',2)=any(blocked_groups));
  end if;
  return jsonb_build_object('actions',actions,'catalog_differences',
    differences || pg_temp.planning_catalog_recipe_differences(snapshot,dish_actions));
end $$;
