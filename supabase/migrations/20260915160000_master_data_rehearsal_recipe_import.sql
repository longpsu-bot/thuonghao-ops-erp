-- Current OPS v1 Recipe/BOM materialization through the existing immutable lineage.
-- No historical author actions or operational documents are fabricated.
set role atlas_owner;
create function atlas_legacy.master_recipe_action(kind text, legacy text, action text, target uuid, vals jsonb, source_fp text)
returns jsonb language sql stable security invoker set search_path='' as $$
 select jsonb_build_object('object_type',kind,'legacy_id',legacy,'action',action,'target_id',target,'values',vals,'source_fingerprint',source_fp,
 'target_fingerprint',atlas_legacy.master_snapshot_hash(atlas_legacy.master_import_read(kind,target)),
 'target_version',atlas_legacy.master_import_read(kind,target)->'version')
$$;
create function atlas_legacy.master_recipe_composition(snapshot jsonb, legacy text)
returns jsonb language sql stable security invoker set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object(
   'ingredient_id',atlas_legacy.master_import_target_id(snapshot,'INGREDIENT',r.value->>'ingredient_legacy_id'),
   'unit_id',atlas_legacy.master_import_target_id(snapshot,'UNIT',r.value->>'unit_legacy_id'),
   'quantity_per_basis',(r.value->>'quantity_per_basis')::numeric,
   'operational_note',r.value->>'operational_note') order by r.value->>'ingredient_legacy_id' collate "C"),'[]')
 from jsonb_array_elements(snapshot#>'{records,recipe_lines}') r where r.value->>'recipe_legacy_id'=legacy
$$;
create or replace function atlas_legacy.master_import_recipe_plan(snapshot jsonb)
returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare
 actions jsonb:='[]'; issues jsonb:='[]'; r jsonb; v jsonb; current_values jsonb; desired jsonb; observed jsonb;
 d jsonb; src_line jsonb; prior record; mapped record; source_rec record;
 dish uuid; recipe uuid; recipe_version uuid; line uuid; revision uuid; ingredient uuid; unit uuid;
 key text; version_key text; line_key text; revision_key text; act text; code text;
 changed boolean; n integer; next_line_revision integer;
 latest atlas_admin.recipe_versions%rowtype; root_row atlas_admin.recipes%rowtype;
 physical_recipe text;
begin
 if current_user<>'postgres' then raise exception using errcode='42501',message='Private master import requires the privileged database operator'; end if;
 -- Every source Dish is represented, including inactive roots.
 for r in select x.value from jsonb_array_elements(snapshot#>'{records,dishes}') x order by x.value->>'legacy_id' collate "C" loop
   key:=r->>'legacy_id'; dish:=atlas_legacy.master_import_target_id(snapshot,'DISH',key);
   current_values:=atlas_legacy.master_import_read('DISH',dish);
   v:=jsonb_build_object('dish_code',r->>'dish_code','dish_name',r->>'dish_name','dish_type_id',atlas_legacy.master_import_target_id(snapshot,'DISH_TYPE',r->>'dish_type_legacy_id'),'dish_status',r->>'dish_status');
   code:=null;
   if nullif(btrim(r->>'dish_name'),'') is null or r->>'dish_status' not in ('ACTIVE','INACTIVE') or r->>'dish_code'<>'v1-dish-'||key or v->>'dish_type_id' is null then code:='INVALID_DISH_REFERENCE'; end if;
   if current_values is not null and not exists(select 1 from atlas_legacy.master_data_mappings m where m.source_system='OPS_V1' and m.object_type='DISH' and m.legacy_id=key) then code:='UNOWNED_EXISTING_DISH'; end if;
   if exists(select 1 from atlas_admin.dishes x where x.dish_id<>dish and (x.dish_code=r->>'dish_code' or (x.dish_status='ACTIVE' and r->>'dish_status'='ACTIVE' and lower(btrim(x.dish_name))=lower(btrim(r->>'dish_name'))))) or
      (select count(*) from jsonb_array_elements(snapshot#>'{records,dishes}') x where x.value->>'dish_status'='ACTIVE' and lower(btrim(x.value->>'dish_name'))=lower(btrim(r->>'dish_name')))>1 then code:='DISH_IDENTITY_CONFLICT'; end if;
   select coalesce(jsonb_object_agg(x.key,current_values->x.key),'{}') into observed from jsonb_each(v) x;
   act:=case when current_values is null then 'CREATE' when observed=v then 'NO_CHANGE' when r->>'dish_status'='INACTIVE' then 'EXPLICIT_INACTIVATE' else 'UPDATE' end;
   if act<>'NO_CHANGE' and atlas_core.uiq03a_dish_used_operationally(dish) then code:='RECIPE_COMMITTED_USE'; end if;
   if code is not null then act:='BLOCKED'; issues:=issues||jsonb_build_array(jsonb_build_object('severity','BLOCKER','code',code,'object_type','DISH','legacy_id',key)); end if;
   actions:=actions||jsonb_build_array(atlas_legacy.master_recipe_action('DISH',key,act,dish,v,atlas_legacy.master_snapshot_hash(r-'source_record_id')));
 end loop;
 -- Independently revalidate source composition; never trust client diagnostics alone.
 for r in select x.value from jsonb_array_elements(snapshot#>'{records,recipe_lines}') x loop
   code:=null;
   if not exists(select 1 from jsonb_array_elements(snapshot#>'{records,recipes}') p where p.value->>'legacy_id'=r->>'recipe_legacy_id') then code:='MISSING_RECIPE'; end if;
   ingredient:=atlas_legacy.master_import_target_id(snapshot,'INGREDIENT',r->>'ingredient_legacy_id');
   unit:=atlas_legacy.master_import_target_id(snapshot,'UNIT',r->>'unit_legacy_id');
   if ingredient is null or unit is null then code:='INVALID_COMPOSITION_REFERENCE'; end if;
   if not exists(select 1 from jsonb_array_elements(snapshot#>'{records,ingredients}') i where i.value->>'legacy_id'=r->>'ingredient_legacy_id' and i.value->>'ingredient_status'='ACTIVE') then code:='INACTIVE_INGREDIENT_REFERENCE'; end if;
   if r->>'legacy_id' is distinct from 'recipe:'||(r->>'recipe_legacy_id')||':ingredient:'||(r->>'ingredient_legacy_id') then code:='INVALID_COMPOSITION_IDENTITY'; end if;
   if coalesce(r->>'quantity_per_basis','') !~ '^\d{1,14}(\.\d{1,6})?$' or coalesce(atlas_core.pa_05b_safe_numeric(r->>'quantity_per_basis'),0)<=0 then code:='INVALID_RECIPE_QUANTITY'; end if;
   if code is not null then issues:=issues||jsonb_build_array(jsonb_build_object('severity','BLOCKER','code',code,'object_type','RECIPE_LINE','legacy_id',r->>'legacy_id')); end if;
 end loop;
 for r in select x.value from jsonb_array_elements(snapshot#>'{records,recipes}') x order by x.value->>'legacy_id' collate "C" loop
  key:=r->>'legacy_id'; recipe:=atlas_legacy.master_import_target_id(snapshot,'RECIPE',key);
  dish:=atlas_legacy.master_import_target_id(snapshot,'DISH',r->>'dish_legacy_id');
  select x.value into d from jsonb_array_elements(snapshot#>'{records,dishes}') x where x.value->>'legacy_id'=r->>'dish_legacy_id';
  code:=null;
  if key is distinct from 'dish:'||(r->>'dish_legacy_id')||':school-type:'||(r->>'school_type_legacy_id') or dish is null or atlas_legacy.master_import_target_id(snapshot,'SCHOOL_TYPE',r->>'school_type_legacy_id') is null then code:='INVALID_RECIPE_SCOPE'; end if;
  if (r->>'basis_portions')::integer is distinct from 100 then code:='INVALID_RECIPE_BASIS'; end if;
  if r->>'recipe_status' not in ('ACTIVE','INACTIVE') then code:='INVALID_RECIPE_LIFECYCLE'; end if;
  select * into root_row from atlas_admin.recipes where recipe_id=recipe;
  if found and (root_row.dish_id<>dish or root_row.school_type_id<>atlas_legacy.master_import_target_id(snapshot,'SCHOOL_TYPE',r->>'school_type_legacy_id')) then code:='RECIPE_SCOPE_IMMUTABLE'; end if;
  if root_row.recipe_id is not null and not exists(select 1 from atlas_legacy.master_data_mappings m where m.source_system='OPS_V1' and m.object_type='RECIPE' and m.legacy_id=key) then code:='UNOWNED_EXISTING_RECIPE'; end if;
  if exists(select 1 from atlas_admin.recipes x where x.recipe_id<>recipe and x.dish_id=dish and x.school_type_id=atlas_legacy.master_import_target_id(snapshot,'SCHOOL_TYPE',r->>'school_type_legacy_id') and x.recipe_status='ACTIVE') then code:='RECIPE_SCOPE_CONFLICT'; end if;
  begin desired:=atlas_legacy.master_recipe_composition(snapshot,key);
  exception when invalid_text_representation or numeric_value_out_of_range then desired:='[]'; code:='INVALID_RECIPE_QUANTITY'; end;
  if jsonb_array_length(desired)=0 then code:='RECIPE_EMPTY'; end if;
  select * into latest from atlas_admin.recipe_versions where recipe_id=recipe order by version_number desc limit 1;
  select coalesce(jsonb_agg(jsonb_build_object('ingredient_id',x.ingredient_id,'unit_id',x.unit_id,'quantity_per_basis',x.quantity_per_basis,'operational_note',x.operational_note) order by m.legacy_id collate "C"),'[]') into observed
  from atlas_admin.recipe_line_revisions x left join atlas_legacy.master_data_mappings m on m.source_system='OPS_V1' and m.object_type='INGREDIENT' and m.ingredient_id=x.ingredient_id
  where x.recipe_version_id=latest.recipe_version_id and x.line_disposition='PRESENT';
  changed:=latest.recipe_version_id is null or desired is distinct from observed or latest.basis_portions<>100;
  if latest.recipe_version_id is not null and latest.recipe_version_status<>'RELEASED_FOR_PLANNING' and changed then code:='UNEXPECTED_RECIPE_VERSION_STATE'; end if;
  if changed and (r->>'recipe_status'<>'ACTIVE' or d->>'dish_status'<>'ACTIVE') then code:='INACTIVE_RECIPE_CANNOT_MATERIALIZE'; end if;
  if (changed or root_row.recipe_status is distinct from r->>'recipe_status') and atlas_core.uiq03a_dish_used_operationally(dish) then code:='RECIPE_COMMITTED_USE'; end if;
  v:=jsonb_build_object('dish_id',dish,'school_type_id',atlas_legacy.master_import_target_id(snapshot,'SCHOOL_TYPE',r->>'school_type_legacy_id'),'recipe_status',r->>'recipe_status');
  act:=case when root_row.recipe_id is null then 'CREATE' when changed then 'UPDATE' when root_row.recipe_status=r->>'recipe_status' then 'NO_CHANGE' else 'EXPLICIT_INACTIVATE' end;
  if code is not null then act:='BLOCKED'; issues:=issues||jsonb_build_array(jsonb_build_object('severity','BLOCKER','code',code,'object_type','RECIPE','legacy_id',key)); end if;
  actions:=actions||jsonb_build_array(atlas_legacy.master_recipe_action('RECIPE',key,act,recipe,v,atlas_legacy.master_snapshot_hash((r-'source_record_id')||jsonb_build_object('composition',desired))));
  if code is not null or not changed then continue; end if;
  n:=coalesce(latest.version_number,0)+1; version_key:=key||':version:'||n;
  recipe_version:=md5('OPS_V1:RECIPE_VERSION:'||version_key)::uuid;
  v:=jsonb_build_object('recipe_id',recipe,'version_number',n,'basis_portions',100,'predecessor_recipe_version_id',latest.recipe_version_id,
    'source_evidence',jsonb_build_object('source_kind','OPS_V1_MASTER_SNAPSHOT','source_system','OPS_V1','snapshot_id',snapshot->>'snapshot_id','snapshot_checksum',snapshot->>'snapshot_checksum','stable_recipe_key',key,'source_record_id',r->>'source_record_id'));
  actions:=actions||jsonb_build_array(atlas_legacy.master_recipe_action('RECIPE_VERSION',version_key,'CREATE',recipe_version,v,atlas_legacy.master_snapshot_hash(v)));
  -- Union includes prior REMOVED tombstones so later reintroduction retains an exact predecessor.
  for source_rec in select union_lines.* from (
    select s.value as source_line,s.value->>'legacy_id' as stable_key from jsonb_array_elements(snapshot#>'{records,recipe_lines}') s where s.value->>'recipe_legacy_id'=key
    union all
    select null,m.legacy_id from atlas_admin.recipe_line_revisions x join atlas_legacy.master_data_mappings m on m.source_system='OPS_V1' and m.object_type='RECIPE_LINE' and m.recipe_line_id=x.recipe_line_id
    where x.recipe_version_id=latest.recipe_version_id and not exists(select 1 from jsonb_array_elements(snapshot#>'{records,recipe_lines}') s where s.value->>'legacy_id'=m.legacy_id)
    ) union_lines order by union_lines.stable_key collate "C"
  loop
    src_line:=source_rec.source_line; line_key:=source_rec.stable_key;
    select m.recipe_line_id into line from atlas_legacy.master_data_mappings m where m.source_system='OPS_V1' and m.object_type='RECIPE_LINE' and m.legacy_id=line_key;
    line:=coalesce(line,md5('OPS_V1:RECIPE_LINE:'||line_key)::uuid);
    select x.* into prior from atlas_admin.recipe_line_revisions x where x.recipe_version_id=latest.recipe_version_id and x.recipe_line_id=line;
    next_line_revision:=coalesce(prior.line_revision_number,0)+1;
    revision_key:=line_key||':revision:'||next_line_revision; revision:=md5('OPS_V1:RECIPE_LINE_REVISION:'||revision_key)::uuid;
    actions:=actions||jsonb_build_array(atlas_legacy.master_recipe_action('RECIPE_LINE',line_key,case when exists(select 1 from atlas_admin.recipe_lines x where x.recipe_line_id=line) then 'NO_CHANGE' else 'CREATE' end,line,jsonb_build_object('recipe_id',recipe,'line_code','v1-'||md5(line_key)),atlas_legacy.master_snapshot_hash(jsonb_build_object('recipe_id',recipe,'line_key',line_key))));
    v:=jsonb_build_object('recipe_id',recipe,'recipe_version_id',recipe_version,'recipe_line_id',line,'line_revision_number',next_line_revision,
      'predecessor_recipe_line_revision_id',prior.recipe_line_revision_id,
      'ingredient_id',case when src_line is null then prior.ingredient_id else atlas_legacy.master_import_target_id(snapshot,'INGREDIENT',src_line->>'ingredient_legacy_id') end,
      'unit_id',case when src_line is null then prior.unit_id else atlas_legacy.master_import_target_id(snapshot,'UNIT',src_line->>'unit_legacy_id') end,
      'quantity_per_basis',case when src_line is null then 0 else (src_line->>'quantity_per_basis')::numeric end,
      'line_disposition',case when src_line is null then 'REMOVED' else 'PRESENT' end,
      'operational_note',case when src_line is null then prior.operational_note else src_line->>'operational_note' end);
    actions:=actions||jsonb_build_array(atlas_legacy.master_recipe_action('RECIPE_LINE_REVISION',revision_key,'CREATE',revision,v,atlas_legacy.master_snapshot_hash(v)));
  end loop;
 end loop;
 for mapped in select m.*,to_jsonb(m) as mapped from atlas_legacy.master_data_mappings m where m.source_system='OPS_V1' and m.object_type in ('DISH','RECIPE') loop
  if not exists(select 1 from jsonb_array_elements(snapshot#>array['records',atlas_legacy.master_import_entity(mapped.object_type)]) r where r.value->>'legacy_id'=mapped.legacy_id) then
    actions:=actions||jsonb_build_array(atlas_legacy.master_recipe_action(mapped.object_type,mapped.legacy_id,'MISSING_FROM_SOURCE',(mapped.mapped->>atlas_legacy.master_import_mapping_column(mapped.object_type))::uuid,null,mapped.last_source_fingerprint));
  end if;
 end loop;
 return jsonb_build_object('actions',actions,'issues',issues);
exception when invalid_text_representation or numeric_value_out_of_range then
 return jsonb_build_object('actions',actions,'issues',issues||jsonb_build_array(jsonb_build_object('severity','BLOCKER','code','INVALID_RECIPE_VALUE')));
end $$;

create or replace function atlas_legacy.master_import_apply_recipes(snapshot jsonb, plan jsonb, actor uuid)
returns void language plpgsql volatile security invoker set search_path='' as $$
declare a jsonb; v jsonb; target uuid; version_id uuid; composition jsonb;
begin
 if current_user<>'postgres' then raise exception using errcode='42501',message='Private master import requires the privileged database operator'; end if;
 if actor is null or not exists(select 1 from atlas_core.actors x where x.actor_id=actor and x.actor_status='ACTIVE') then raise exception 'IMPORT_ACTOR_INACTIVE_OR_MISSING'; end if;
 for a in select x.value from jsonb_array_elements(plan->'actions') x where x.value->>'object_type' in ('DISH','RECIPE') loop
  if a->>'action' not in ('CREATE','UPDATE','EXPLICIT_INACTIVATE') then continue; end if;
  target:=(a->>'target_id')::uuid; v:=a->'values';
  if a->>'object_type'='DISH' then
    if atlas_core.uiq03a_dish_used_operationally(target) then raise exception 'RECIPE_COMMITTED_USE'; end if;
    if a->>'action'='CREATE' then
      insert into atlas_admin.dishes(dish_id,dish_code,dish_name,dish_type_id,dish_status)
      values(target,v->>'dish_code',v->>'dish_name',(v->>'dish_type_id')::uuid,v->>'dish_status');
    else
      update atlas_admin.dishes set dish_name=v->>'dish_name',dish_type_id=(v->>'dish_type_id')::uuid,dish_status=v->>'dish_status',version=version+1,updated_at=clock_timestamp() where dish_id=target;
    end if;
  else
    if atlas_core.uiq03a_dish_used_operationally((v->>'dish_id')::uuid) then raise exception 'RECIPE_COMMITTED_USE'; end if;
    if a->>'action'='CREATE' then
      insert into atlas_admin.recipes(recipe_id,dish_id,school_type_id,recipe_status) values(target,(v->>'dish_id')::uuid,(v->>'school_type_id')::uuid,v->>'recipe_status');
    else
      update atlas_admin.recipes set recipe_status=v->>'recipe_status',version=version+1,updated_at=clock_timestamp() where recipe_id=target;
    end if;
  end if;
 end loop;
 for a in select x.value from jsonb_array_elements(plan->'actions') x where x.value->>'object_type'='RECIPE_VERSION' and x.value->>'action'='CREATE' loop
   v:=a->'values'; target:=(a->>'target_id')::uuid;
   select coalesce(jsonb_agg(x.value->'values' order by x.value->>'legacy_id' collate "C"),'[]') into composition from jsonb_array_elements(plan->'actions') x
   where x.value->>'object_type'='RECIPE_LINE_REVISION' and x.value#>>'{values,recipe_version_id}'=target::text;
   insert into atlas_admin.recipe_versions(recipe_version_id,recipe_id,version_number,predecessor_recipe_version_id,basis_portions,created_by_actor_id,draft_composition,source_evidence)
   values(target,(v->>'recipe_id')::uuid,(v->>'version_number')::integer,(v->>'predecessor_recipe_version_id')::uuid,100,actor,composition,v->'source_evidence');
 end loop;
 for a in select x.value from jsonb_array_elements(plan->'actions') x where x.value->>'object_type'='RECIPE_LINE' and x.value->>'action'='CREATE' loop
   v:=a->'values';
   insert into atlas_admin.recipe_lines(recipe_line_id,recipe_id,line_code) values((a->>'target_id')::uuid,(v->>'recipe_id')::uuid,v->>'line_code');
 end loop;
 for a in select x.value from jsonb_array_elements(plan->'actions') x where x.value->>'object_type'='RECIPE_LINE_REVISION' and x.value->>'action'='CREATE' loop
   v:=a->'values';
   if v->>'line_disposition'='PRESENT' and (not exists(select 1 from atlas_admin.ingredients i where i.ingredient_id=(v->>'ingredient_id')::uuid and i.ingredient_status='ACTIVE') or not exists(select 1 from atlas_admin.units u where u.unit_id=(v->>'unit_id')::uuid and u.unit_status='ACTIVE') or (v->>'quantity_per_basis')::numeric<=0) then raise exception 'INVALID_COMPOSITION_REFERENCE'; end if;
   insert into atlas_admin.recipe_line_revisions(recipe_line_revision_id,recipe_id,recipe_version_id,recipe_line_id,line_revision_number,predecessor_recipe_line_revision_id,ingredient_id,quantity_per_basis,unit_id,line_disposition,operational_note,created_by_actor_id)
   values((a->>'target_id')::uuid,(v->>'recipe_id')::uuid,(v->>'recipe_version_id')::uuid,(v->>'recipe_line_id')::uuid,(v->>'line_revision_number')::integer,(v->>'predecessor_recipe_line_revision_id')::uuid,(v->>'ingredient_id')::uuid,(v->>'quantity_per_basis')::numeric,(v->>'unit_id')::uuid,v->>'line_disposition',v->>'operational_note',actor);
 end loop;
 for a in select x.value from jsonb_array_elements(plan->'actions') x where x.value->>'object_type'='RECIPE_VERSION' and x.value->>'action'='CREATE' loop
   v:=a->'values'; version_id:=(a->>'target_id')::uuid;
   update atlas_admin.recipe_versions set recipe_version_status='VALIDATED',validated_by_actor_id=actor,validated_at=clock_timestamp(),version=version+1 where recipe_version_id=version_id;
   set constraints atlas_admin.recipe_versions_integrity_guard immediate;
   set constraints atlas_admin.recipe_versions_integrity_guard deferred;
   update atlas_admin.recipe_versions set recipe_version_status='LOCKED',locked_by_actor_id=actor,locked_at=clock_timestamp(),version=version+1
   where recipe_version_id=(v->>'predecessor_recipe_version_id')::uuid and recipe_version_status='RELEASED_FOR_PLANNING';
   update atlas_admin.recipe_versions set recipe_version_status='RELEASED_FOR_PLANNING',released_by_actor_id=actor,released_at=clock_timestamp(),version=version+1 where recipe_version_id=version_id;
   set constraints atlas_admin.recipe_versions_integrity_guard immediate;
   set constraints atlas_admin.recipe_versions_integrity_guard deferred;
 end loop;
 -- Advancing a released predecessor to LOCKED is an importer-owned version change,
 -- not external drift. Preserve its initial mapping provenance and last-seen source batch.
 update atlas_legacy.master_data_mappings m set last_target_version=r.version,updated_at=clock_timestamp()
 from atlas_admin.recipe_versions r where m.source_system='OPS_V1' and m.object_type='RECIPE_VERSION' and m.recipe_version_id=r.recipe_version_id and m.last_target_version is distinct from r.version;
end $$;
revoke all on function atlas_legacy.master_recipe_action(text,text,text,uuid,jsonb,text) from public,anon,authenticated,service_role;
revoke all on function atlas_legacy.master_recipe_composition(jsonb,text) from public,anon,authenticated,service_role;
revoke all on function atlas_legacy.master_import_recipe_plan(jsonb) from public,anon,authenticated,service_role;
revoke all on function atlas_legacy.master_import_apply_recipes(jsonb,jsonb,uuid) from public,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION atlas_legacy.apply_master_data_snapshot(snapshot jsonb, expected_plan_checksum text, operator_actor_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare p jsonb; a jsonb; b atlas_legacy.import_batches%rowtype; batch uuid:=gen_random_uuid(); result jsonb; after_plan jsonb;
  counts jsonb; target_before jsonb; fps jsonb;
begin
  if current_user<>'postgres' then raise exception using errcode='42501',message='Private master import requires the privileged database operator'; end if;
  if operator_actor_id is null then return jsonb_build_object('success',false,'status','REJECTED','error_code','IMPORT_ACTOR_REQUIRED'); end if;
  perform 1 from atlas_core.actors actor where actor.actor_id=operator_actor_id and actor.actor_status='ACTIVE' for share;
  if not found then return jsonb_build_object('success',false,'status','REJECTED','error_code','IMPORT_ACTOR_INACTIVE_OR_MISSING'); end if;
  -- Explicit, deterministic table locking also protects uncreated identities and immutable Menu-use evidence.
  -- No hosted execution is authorized by installing these private functions.
  lock table atlas_admin.customers,atlas_admin.delivery_locations,atlas_admin.dish_types,atlas_admin.dishes,
    atlas_admin.ingredient_order_groups,atlas_admin.ingredient_types,atlas_admin.ingredients,
    atlas_admin.recipe_line_revisions,atlas_admin.recipe_lines,atlas_admin.recipe_versions,atlas_admin.recipes,
    atlas_admin.school_types,atlas_admin.schools,atlas_admin.supplier_eligibilities,atlas_admin.suppliers,atlas_admin.units,
    atlas_legacy.import_batches,atlas_legacy.master_data_mappings in share row exclusive mode;
  lock table atlas_planning.weekly_menu_approval_snapshot_lines in share mode;
  perform 1 from atlas_admin.dishes d order by d.dish_id for update;
  p:=atlas_legacy.preview_master_data_snapshot(snapshot);
  if p->>'success' is distinct from 'true' then
    return jsonb_build_object('success',false,'status','REJECTED','error_code',case when exists(select 1 from jsonb_array_elements(coalesce(p->'issues','[]')) i where i->>'code'='TARGET_DRIFT') then 'TARGET_DRIFT' else coalesce(p->>'error_code','SNAPSHOT_BLOCKED') end,'preview',p);
  end if;
  select * into b from atlas_legacy.import_batches where source_system='OPS_V1' and snapshot_id=snapshot->>'snapshot_id';
  if found then
    if b.snapshot_checksum is distinct from snapshot->>'snapshot_checksum' then return jsonb_build_object('success',false,'status','REJECTED','error_code','SNAPSHOT_ID_CONFLICT'); end if;
    if b.operator_actor_id is distinct from operator_actor_id then return jsonb_build_object('success',false,'status','REJECTED','error_code','IMPORT_ACTOR_REPLAY_CONFLICT'); end if;
    if expected_plan_checksum is null or (expected_plan_checksum<>b.plan_checksum and expected_plan_checksum<>p->>'plan_checksum') then return jsonb_build_object('success',false,'status','REJECTED','error_code','PLAN_CHECKSUM_MISMATCH'); end if;
    return b.result_payload||jsonb_build_object('status','REPLAYED','current_preview',p);
  end if;
  if expected_plan_checksum is null or expected_plan_checksum is distinct from p->>'plan_checksum' then return jsonb_build_object('success',false,'status','REJECTED','error_code','PLAN_CHECKSUM_MISMATCH'); end if;
  target_before:=atlas_legacy.master_import_counts();
  insert into atlas_legacy.import_batches(import_batch_id,source_system,snapshot_id,snapshot_checksum,exported_at,import_status,completed_at,operator_actor_id,execution_database_principal,plan_checksum,snapshot_contract_version,source_counts)
  values(batch,'OPS_V1',snapshot->>'snapshot_id',snapshot->>'snapshot_checksum',(snapshot->>'exported_at')::timestamptz,'COMPLETED',clock_timestamp(),operator_actor_id,session_user,expected_plan_checksum,'OPS-V1-MASTER-SNAPSHOT.v1',snapshot->'source_counts');
  for a in select x.value from jsonb_array_elements(p->'actions') x where x.value->>'object_type' not in ('DISH','RECIPE','RECIPE_VERSION','RECIPE_LINE','RECIPE_LINE_REVISION') loop
    perform atlas_legacy.master_import_write_core(a);
  end loop;
  -- Membership/priority change is part of the Ingredient master aggregate's versioned state.
  update atlas_admin.ingredients i set version=i.version+1,updated_at=clock_timestamp()
    where i.ingredient_id in (select distinct (x.value#>>'{values,ingredient_id}')::uuid from jsonb_array_elements(p->'actions') x where x.value->>'object_type'='SUPPLIER_ELIGIBILITY' and x.value->>'action' in ('CREATE','UPDATE','REMOVE_RELATIONSHIP'));
  perform atlas_legacy.master_import_apply_recipes(snapshot,p,operator_actor_id);
  for a in select x.value from jsonb_array_elements(p->'actions') x loop
    perform atlas_legacy.master_import_record_mapping(a,batch);
  end loop;
  fps:=atlas_legacy.master_import_capture_fingerprints();
  select coalesce(jsonb_object_agg(s.action,s.n),'{}') into counts from (select x.value->>'action' action,count(*) n from jsonb_array_elements(p->'actions') x group by 1) s;
  result:=jsonb_build_object('success',true,'status','COMPLETED','gate','REHEARSAL_ACCEPTED','import_batch_id',batch,'operator_actor_id',operator_actor_id,
    'snapshot_id',snapshot->>'snapshot_id','snapshot_checksum',snapshot->>'snapshot_checksum','plan_checksum',expected_plan_checksum,
    'source_counts',snapshot->'source_counts','operation_counts',counts,'target_counts_before',target_before,'target_counts_after',atlas_legacy.master_import_counts(),'issues',p->'issues');
  update atlas_legacy.import_batches set target_counts=result->'target_counts_after',operation_counts=counts,
    reconciliation=jsonb_build_object('target_fingerprints',fps,'actions',p->'actions','issues',p->'issues'),result_payload=result,completed_at=clock_timestamp()
    where import_batch_id=batch;
  after_plan:=atlas_legacy.preview_master_data_snapshot(snapshot);
  if after_plan->>'success' is distinct from 'true' or exists(select 1 from jsonb_array_elements(after_plan->'actions') x where x.value->>'action' not in ('NO_CHANGE','MISSING_FROM_SOURCE')) then
    raise exception using errcode='23514',message='IMPORT_READBACK_DID_NOT_RECONCILE';
  end if;
  return result;
exception
  when serialization_failure or deadlock_detected then return jsonb_build_object('success',false,'status','REJECTED','error_code','RETRYABLE_CONCURRENCY_FAILURE');
  when check_violation or foreign_key_violation or unique_violation or not_null_violation then return jsonb_build_object('success',false,'status','REJECTED','error_code','APPLY_INVARIANT_FAILURE','constraint_state',sqlstate);
end $function$

;

-- Preserve the approved source-ID to catalogue-code mapping even after a crosswalk exists.
CREATE OR REPLACE FUNCTION atlas_legacy.master_import_validate_values(kind text, legacy text, source_row jsonb, v jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
declare result jsonb:='[]'; f text; status text;
begin
  if v is null then return result; end if;
  if kind='DISH_TYPE' and (legacy not in ('1','2','3','4','5','6') or source_row->>'dish_type_code' is distinct from ('{"1":"soup","2":"savory","3":"stir_fry","4":"dessert","5":"afternoon_snack","6":"beverage"}'::jsonb->>legacy)) then
    result:=result||jsonb_build_array(jsonb_build_object('code','DISH_TYPE_MAPPING_MISMATCH','field','dish_type_code'));
  end if;
  for f in select key from jsonb_each(v) e where e.key not in ('delivery_instructions','effective_to') and (e.value='null'::jsonb or (jsonb_typeof(e.value)='string' and nullif(btrim(e.value #>> '{}'),'') is null)) loop
    result:=result||jsonb_build_array(jsonb_build_object('code','INVALID_REQUIRED_VALUE','field',f));
  end loop;
  status:=coalesce(v->>'school_type_status',v->>'customer_status',v->>'location_status',v->>'school_status',v->>'unit_status',v->>'ingredient_status',v->>'supplier_status',v->>'eligibility_status');
  if status is not null and status not in ('ACTIVE','INACTIVE','ARCHIVED','SUSPENDED') then
    result:=result||jsonb_build_array(jsonb_build_object('code','INVALID_LIFECYCLE','field','status'));
  end if;
  if kind='SCHOOL_TYPE' and (legacy not in ('1','2') or v->>'school_type_code'<>'v1-school-type-'||legacy or v->>'school_type_name'<>case legacy when '1' then 'TIỂU HỌC' when '2' then 'TRUNG HỌC' end) then
    result:=result||jsonb_build_array(jsonb_build_object('code','UNKNOWN_SCHOOL_TYPE','field','school_type_code'));
  end if;
  if kind='SCHOOL' and ((v->>'display_order')::integer<0 or (v->>'default_student_portions')::integer<0 or (v->>'default_teacher_portions')::integer<0 or v->>'school_code'<>'v1-school-'||legacy or v->>'dispatch_document_issuer_name' not in ('CƠ SỞ CUNG CẤP THỰC PHẨM THƯỢNG HẢO','CÔNG TY TNHH MTV TM - DV THƯỢNG HẢO')) then
    result:=result||jsonb_build_array(jsonb_build_object('code','INVALID_SCHOOL_VALUE','field','school'));
  end if;
  if kind='UNIT' then
    if legacy not in ('kg','Bịch','Bó','Cái','Cây','Chai','Cốc','Gói','Hộp','Hũ','Lon','Miếng','Ổ','Quả','Trái') or
      v->>'unit_name'<>(case when legacy='kg' then 'Kilogram' else legacy end) or
      v->>'unit_code'<>(case when legacy='kg' then 'kg' else 'v1-unit-'||substr(encode(extensions.digest(convert_to(legacy,'UTF8'),'sha256'),'hex'),1,12) end) or
      v->>'dimension_code'<>(case when legacy='kg' then 'MASS' else 'COUNT' end) or
      (v->>'decimal_scale')::integer<>(case when legacy='kg' then 6 else 0 end) then
      result:=result||jsonb_build_array(jsonb_build_object('code','UNSUPPORTED_UNIT','field','unit'));
    end if;
  end if;
  if kind='INGREDIENT' and (coalesce(source_row->>'order_step','') !~ '^\d{1,14}(\.\d{1,6})?$' or (v->>'order_step')::numeric<=0 or v->>'ingredient_code'<>'v1-ingredient-'||legacy) then
    result:=result||jsonb_build_array(jsonb_build_object('code','INVALID_INGREDIENT_VALUE','field','order_step'));
  end if;
  if kind='SUPPLIER_ELIGIBILITY' and ((v->>'priority')::integer not between 1 and 6) then
    result:=result||jsonb_build_array(jsonb_build_object('code','INVALID_PRIORITY','field','priority'));
  end if;
  return result;
end $function$

;
reset role;
