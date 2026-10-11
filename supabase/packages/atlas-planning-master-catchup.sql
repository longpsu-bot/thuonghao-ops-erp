-- Protected session-local tooling. No persistent RPC, grant, role or business aggregate.
create or replace function pg_temp.planning_catchup_scope(snapshot jsonb, prior_scope jsonb default null)
returns jsonb language plpgsql stable set search_path='' as $$
declare records jsonb:=snapshot->'records'; scoped jsonb:=records; dish_ids jsonb; recipe_ids jsonb; ingredient_ids jsonb; supplier_ids jsonb; unit_ids jsonb; entity text;
begin
 select coalesce(prior_scope,coalesce(jsonb_agg(r.value->'legacy_id' order by r.value->>'legacy_id'),'[]')) into dish_ids
 from jsonb_array_elements(records->'dishes') r where r.value->>'dish_status'='ACTIVE' and not exists
 (select 1 from atlas_legacy.master_data_mappings m where m.source_system='OPS_V1' and m.object_type='DISH' and m.legacy_id=r.value->>'legacy_id');
 select coalesce(jsonb_agg(r.value),'[]') into recipe_ids from jsonb_array_elements(records->'recipes') r where dish_ids @> jsonb_build_array(r.value->'dish_legacy_id');
 scoped:=jsonb_set(scoped,'{recipes}',recipe_ids);
 select coalesce(jsonb_agg(r.value),'[]') into recipe_ids from jsonb_array_elements(records->'recipe_lines') r where exists
 (select 1 from jsonb_array_elements(scoped->'recipes') p where p.value->>'legacy_id'=r.value->>'recipe_legacy_id');
 scoped:=jsonb_set(scoped,'{recipe_lines}',recipe_ids);
 select coalesce(jsonb_agg(r.value),'[]') into ingredient_ids from jsonb_array_elements(records->'ingredients') r where exists
 (select 1 from jsonb_array_elements(scoped->'recipe_lines') l where l.value->>'ingredient_legacy_id'=r.value->>'legacy_id');
 scoped:=jsonb_set(scoped,'{ingredients}',ingredient_ids);
 select coalesce(jsonb_agg(r.value),'[]') into supplier_ids from jsonb_array_elements(records->'supplier_eligibilities') r where exists
 (select 1 from jsonb_array_elements(scoped->'ingredients') i where i.value->>'legacy_id'=r.value->>'ingredient_legacy_id');
 scoped:=jsonb_set(scoped,'{supplier_eligibilities}',supplier_ids);
 select coalesce(jsonb_agg(r.value),'[]') into supplier_ids from jsonb_array_elements(records->'suppliers') r where exists
 (select 1 from jsonb_array_elements(scoped->'supplier_eligibilities') e where e.value->>'supplier_legacy_id'=r.value->>'legacy_id');
 scoped:=jsonb_set(scoped,'{suppliers}',supplier_ids);
 select coalesce(jsonb_agg(r.value),'[]') into unit_ids from jsonb_array_elements(records->'units') r where exists
 (select 1 from jsonb_array_elements(scoped->'ingredients') i where i.value->>'purchase_unit_legacy_id'=r.value->>'legacy_id') or exists
 (select 1 from jsonb_array_elements(scoped->'recipe_lines') l where l.value->>'unit_legacy_id'=r.value->>'legacy_id');
 scoped:=jsonb_set(scoped,'{units}',unit_ids);
 select coalesce(jsonb_agg(r.value),'[]') into recipe_ids from jsonb_array_elements(records->'dishes') r where dish_ids @> jsonb_build_array(r.value->'legacy_id');
 scoped:=jsonb_set(scoped,'{dishes}',recipe_ids);
 foreach entity in array array['customers','delivery_locations','schools'] loop scoped:=jsonb_set(scoped,array[entity],'[]'); end loop;
 -- Restrict catalogues to references in this closure, never all source masters.
 select coalesce(jsonb_agg(r.value),'[]') into recipe_ids from jsonb_array_elements(records->'school_types') r where exists
 (select 1 from jsonb_array_elements(scoped->'recipes') p where p.value->>'school_type_legacy_id'=r.value->>'legacy_id');
 scoped:=jsonb_set(scoped,'{school_types}',recipe_ids);
 select coalesce(jsonb_agg(r.value),'[]') into recipe_ids from jsonb_array_elements(records->'dish_types') r where exists
 (select 1 from jsonb_array_elements(scoped->'dishes') p where p.value->>'dish_type_legacy_id'=r.value->>'legacy_id');
 scoped:=jsonb_set(scoped,'{dish_types}',recipe_ids);
 select coalesce(jsonb_agg(r.value),'[]') into ingredient_ids from jsonb_array_elements(records->'ingredient_types') r where exists
 (select 1 from jsonb_array_elements(scoped->'ingredients') i where i.value->>'ingredient_type_legacy_id'=r.value->>'legacy_id');
 scoped:=jsonb_set(scoped,'{ingredient_types}',ingredient_ids);
 select coalesce(jsonb_agg(r.value),'[]') into ingredient_ids from jsonb_array_elements(records->'ingredient_order_groups') r where exists
 (select 1 from jsonb_array_elements(scoped->'ingredients') i where i.value->>'ingredient_order_group_legacy_id'=r.value->>'legacy_id');
 scoped:=jsonb_set(scoped,'{ingredient_order_groups}',ingredient_ids);
 return snapshot||jsonb_build_object('records',scoped,'catchup_dish_ids',dish_ids);
end $$;

create or replace function pg_temp.planning_catchup_protected(actions jsonb)
returns jsonb language plpgsql stable set search_path='' as $$
declare t record; result jsonb:='{}'; v jsonb; predicate text; kind text; col text; fp text;
begin
 for t in select n.nspname,c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where n.nspname in ('atlas_admin','atlas_planning','atlas_procurement','atlas_dispatch','atlas_warehouse','atlas_core','atlas_identity') and c.relkind in ('r','p') order by 1,2 loop
  predicate:='true'; kind:=case t.relname when 'ingredient_types' then 'INGREDIENT_TYPE' when 'ingredient_order_groups' then 'INGREDIENT_ORDER_GROUP' when 'dish_types' then 'DISH_TYPE' when 'units' then 'UNIT' when 'school_types' then 'SCHOOL_TYPE' when 'schools' then 'SCHOOL' when 'ingredients' then 'INGREDIENT' when 'suppliers' then 'SUPPLIER' when 'supplier_eligibilities' then 'SUPPLIER_ELIGIBILITY' when 'dishes' then 'DISH' when 'recipes' then 'RECIPE' when 'recipe_versions' then 'RECIPE_VERSION' when 'recipe_lines' then 'RECIPE_LINE' when 'recipe_line_revisions' then 'RECIPE_LINE_REVISION' end;
  if t.nspname='atlas_admin' and kind is not null then
   col:=atlas_legacy.master_import_mapping_column(kind);
   predicate:=format('not exists(select 1 from jsonb_array_elements($1) a where a.value->>''object_type''=%L and a.value->>''action'' in (''CREATE'',''UPDATE'') and a.value->>''target_id''=t.%I::text)',kind,col);
  end if;
  -- Internal protection fingerprint: retain every included row/column and
  -- duplicate, but sort fixed-width digests instead of complete history JSON.
  -- Source canonical hashes and mapping fingerprints remain unchanged.
  execute format($fingerprint$
   with row_fingerprints as materialized (
    select encode(extensions.digest(convert_to(to_jsonb(t)::text,'UTF8'),'sha256'),'hex') as row_sha
    from %I.%I t where %s
   )
   select jsonb_build_object('rows',count(*),'sha256',
    encode(extensions.digest(convert_to(coalesce(string_agg(row_sha,'' order by row_sha collate "C"),''),'UTF8'),'sha256'),'hex'))
   from row_fingerprints
  $fingerprint$,t.nspname,t.relname,predicate) into v using actions;
  result:=result||jsonb_build_object(t.nspname||'.'||t.relname,v);
 end loop;
 select atlas_legacy.master_snapshot_hash(coalesce(jsonb_agg(to_jsonb(m) order by m.object_type,m.legacy_id),'[]')) into fp from atlas_legacy.master_data_mappings m where not exists
 (select 1 from jsonb_array_elements(actions) a where m.source_system='OPS_V1' and m.object_type=a.value->>'object_type' and m.legacy_id=a.value->>'legacy_id' and a.value->>'action' in ('CREATE','UPDATE'));
 result:=result||jsonb_build_object('unrelated_mappings',fp);
 select atlas_legacy.master_snapshot_hash(coalesce(jsonb_agg(to_jsonb(e) order by e.recipe_unit_adoption_evidence_id),'[]')) into fp from atlas_legacy.recipe_unit_adoption_evidence e where not exists
 (select 1 from jsonb_array_elements(actions) a where a.value->>'object_type'='RECIPE_LINE_REVISION' and a.value->>'action'='CREATE' and a.value->>'target_id'=e.target_recipe_line_revision_id::text);
 return result||jsonb_build_object('unrelated_unit_adoption_evidence',fp);
end $$;

-- Owner-approved zero-BoM policy is confined to this catch-up. The general
-- importer still rejects empty effective compositions. This helper emits roots
-- only; execution continues through the existing Recipe writer and guards.
create or replace function pg_temp.planning_catchup_empty_roots(snapshot jsonb)
returns jsonb language plpgsql stable set search_path='' as $$
declare r jsonb; key text; target uuid; dish uuid; school_type uuid; vals jsonb; observed jsonb; evidence jsonb; actions jsonb:='[]'; issues jsonb:='[]';
begin
 for r in select p.value from jsonb_array_elements(snapshot#>'{records,recipes}') p where not exists
 (select 1 from jsonb_array_elements(snapshot#>'{records,recipe_lines}') l where l.value->>'recipe_legacy_id'=p.value->>'legacy_id') order by p.value->>'legacy_id' collate "C" loop
  key:=r->>'legacy_id'; target:=atlas_legacy.master_import_target_id(snapshot,'RECIPE',key);
  dish:=atlas_legacy.master_import_target_id(snapshot,'DISH',r->>'dish_legacy_id');
  school_type:=atlas_legacy.master_import_target_id(snapshot,'SCHOOL_TYPE',r->>'school_type_legacy_id');
  if key is distinct from 'dish:'||(r->>'dish_legacy_id')||':school-type:'||(r->>'school_type_legacy_id') or target is null or dish is null or school_type is null
   or not exists(select 1 from jsonb_array_elements(snapshot#>'{records,dishes}') d where d.value->>'legacy_id'=r->>'dish_legacy_id' and d.value->>'dish_status'='ACTIVE')
   or not exists(select 1 from jsonb_array_elements(snapshot#>'{records,school_types}') s where s.value->>'legacy_id'=r->>'school_type_legacy_id' and s.value->>'school_type_status'='ACTIVE') then raise exception 'INVALID_RECIPE_SCOPE'; end if;
  if r->>'basis_portions' is distinct from '100' then raise exception 'INVALID_RECIPE_BASIS'; end if;
  if r->>'recipe_status' is distinct from 'ACTIVE' then raise exception 'INVALID_RECIPE_LIFECYCLE'; end if;
  if nullif(btrim(r->>'source_record_id'),'') is null then raise exception 'RECIPE_SOURCE_EVIDENCE_REQUIRED'; end if;
  vals:=jsonb_build_object('dish_id',dish,'school_type_id',school_type,'recipe_status','ACTIVE');
  observed:=atlas_legacy.master_import_read('RECIPE',target);
  if observed is null and exists(select 1 from atlas_legacy.master_data_mappings m where m.source_system='OPS_V1' and m.object_type='RECIPE' and m.legacy_id=key) then raise exception 'TYPED_DEPENDENCY_MISSING'; end if;
  if observed is not null and not exists(select 1 from atlas_legacy.master_data_mappings m where m.source_system='OPS_V1' and m.object_type='RECIPE' and m.legacy_id=key and m.recipe_id=target) then raise exception 'UNOWNED_EXISTING_RECIPE'; end if;
  if observed is not null and (observed->'dish_id' is distinct from vals->'dish_id' or observed->'school_type_id' is distinct from vals->'school_type_id' or observed->>'recipe_status' is distinct from 'ACTIVE') then raise exception 'RECIPE_SCOPE_IMMUTABLE'; end if;
  if exists(select 1 from atlas_admin.recipes x where x.recipe_id<>target and x.dish_id=dish and x.school_type_id=school_type and x.recipe_status='ACTIVE') then raise exception 'RECIPE_SCOPE_CONFLICT'; end if;
  if exists(select 1 from atlas_admin.recipe_versions v where v.recipe_id=target) or exists(select 1 from atlas_admin.recipe_lines l where l.recipe_id=target) then raise exception 'EMPTY_RECIPE_TARGET_COMPOSITION_EXISTS'; end if;
  if observed is null and atlas_core.uiq03a_dish_used_operationally(dish) then raise exception 'RECIPE_COMMITTED_USE'; end if;
  evidence:=jsonb_build_object('source_kind','OPS_V1_MASTER_SNAPSHOT','source_system','OPS_V1','snapshot_id',snapshot->>'snapshot_id','snapshot_checksum',snapshot->>'snapshot_checksum','stable_recipe_key',key,'source_record_id',r->>'source_record_id','diagnostic','SOURCE_RECIPE_EMPTY');
  actions:=actions||jsonb_build_array(atlas_legacy.master_recipe_action('RECIPE',key,case when observed is null then 'CREATE' else 'NO_CHANGE' end,target,vals,atlas_legacy.master_snapshot_hash((r-'source_record_id')||jsonb_build_object('composition','[]'::jsonb)))
   ||jsonb_build_object('before_values',observed,'source_evidence',evidence,'dependency_reason','SOURCE_RECIPE_EMPTY: source_recipe_id='||(r->>'source_record_id')||'; preserve typed root only; no effective composition, RECIPE_NOT_READY'));
  issues:=issues||jsonb_build_array(jsonb_build_object('severity','INFO','code','SOURCE_RECIPE_EMPTY','entity','recipes','object_type','RECIPE','legacy_id',key,'source_record_id',r->>'source_record_id'));
 end loop;
 return jsonb_build_object('actions',actions,'issues',issues);
end $$;

create or replace function pg_temp.planning_catchup_plan(snapshot jsonb)
returns jsonb language plpgsql stable set search_path='' as $$
declare scoped jsonb; composed jsonb; empty_roots jsonb; prior atlas_legacy.import_batches%rowtype; r jsonb; a jsonb; vals jsonb; observed jsonb; target uuid; kind text; key text; action text; actions jsonb:='[]'; issues jsonb:='[]'; extension jsonb; orders jsonb; report jsonb; summary jsonb; plan jsonb; next_tail integer; prior_fp text; mapped boolean;
begin
 if current_user<>'postgres' or to_regclass('public.schools') is not null then raise exception 'STAGING_MASTER_TARGET_DENIED'; end if;
 if snapshot->>'contract_version' is distinct from 'OPS-V1-MASTER-SNAPSHOT.v1' or snapshot->>'source_system' is distinct from 'OPS_V1' or snapshot->>'source_project_ref' is distinct from 'qnthofvccilhnefdcxnz' then raise exception 'SOURCE_CONTRACT_INVALID'; end if;
 if snapshot->>'snapshot_checksum' is distinct from atlas_legacy.master_snapshot_hash(snapshot-'snapshot_checksum') then raise exception 'SNAPSHOT_CHECKSUM_MISMATCH'; end if;
 if snapshot->'source_access' is distinct from '{"role_name":"supabase_read_only_user","has_required_select":true,"has_non_select_privilege":false,"bypass_rls":true,"superuser":false,"create_role":false,"create_db":false}'::jsonb then raise exception 'SOURCE_NOT_PROVEN_READ_ONLY'; end if;
 if jsonb_typeof(snapshot->'records') is distinct from 'object' or jsonb_typeof(snapshot->'source_diagnostics') is distinct from 'array' or nullif(snapshot->>'snapshot_id','') is null then raise exception 'SOURCE_CONTRACT_INVALID'; end if;
 if exists(select 1 from jsonb_each(snapshot->'records') e cross join lateral jsonb_array_elements(e.value) r group by e.key,r.value->>'legacy_id' having count(*)<>1) then raise exception 'DUPLICATE_SOURCE_IDENTITY'; end if;
 select * into prior from atlas_legacy.import_batches where source_system='OPS_V1' and snapshot_id=snapshot->>'snapshot_id';
 if found and (prior.snapshot_contract_version<>'ATLAS-PLANNING-CATCHUP.v1' or prior.snapshot_checksum<>snapshot->>'snapshot_checksum') then raise exception 'SNAPSHOT_ID_CONFLICT'; end if;
 scoped:=pg_temp.planning_catchup_scope(snapshot,prior.reconciliation->'catchup_dish_ids');
 select coalesce(jsonb_agg(i.value),'[]') into issues from jsonb_array_elements(snapshot->'source_diagnostics') i where i.value->>'severity'='BLOCKER' and
 (i.value->>'entity'='schools' or exists(select 1 from jsonb_array_elements(scoped#>array['records',i.value->>'entity']) r where i.value->>'legacy_id' is null or r.value->>'legacy_id'=i.value->>'legacy_id'));
 if jsonb_array_length(issues)>0 then raise exception using message='SOURCE_DEPENDENCY_BLOCKED',detail=issues::text; end if;
 -- Exact closure completeness, including references excluded from the source normalizer.
 if exists(select 1 from jsonb_array_elements(scoped#>'{records,dishes}') d where not exists(select 1 from jsonb_array_elements(scoped#>'{records,recipes}') r where r.value->>'dish_legacy_id'=d.value->>'legacy_id')) then raise exception 'MISSING_RECIPE_SCOPE'; end if;
 if exists(select 1 from jsonb_array_elements(scoped#>'{records,recipe_lines}') l where not exists(select 1 from jsonb_array_elements(scoped#>'{records,ingredients}') i where i.value->>'legacy_id'=l.value->>'ingredient_legacy_id') or not exists(select 1 from jsonb_array_elements(scoped#>'{records,units}') u where u.value->>'legacy_id'=l.value->>'unit_legacy_id')) then raise exception 'MISSING_RECIPE_DEPENDENCY'; end if;
  foreach kind in array array['SCHOOL_TYPE','UNIT','INGREDIENT_TYPE','INGREDIENT_ORDER_GROUP','DISH_TYPE','SUPPLIER','INGREDIENT','SUPPLIER_ELIGIBILITY'] loop
  for r in select value from jsonb_array_elements(scoped#>array['records',atlas_legacy.master_import_entity(kind)]) order by value->>'legacy_id' collate "C" loop
   key:=r->>'legacy_id'; target:=atlas_legacy.master_import_target_id(scoped,kind,key); observed:=atlas_legacy.master_import_read(kind,target);
   select exists(select 1 from atlas_legacy.master_data_mappings m where m.source_system='OPS_V1' and m.object_type=kind and m.legacy_id=key) into mapped;
   if target is null or (mapped and observed is null) then raise exception 'TYPED_DEPENDENCY_MISSING'; end if;
   vals:=atlas_legacy.master_import_values(scoped,kind,r,target);
   if jsonb_array_length(atlas_legacy.master_import_validate_values(kind,key,r,vals))<>0 or atlas_legacy.master_import_collision(kind,target,vals) then raise exception 'DEPENDENCY_COLLISION_OR_INVALID'; end if;
   action:=case when observed is null then 'CREATE' else 'NO_CHANGE' end;
   if observed is not null then
    if not mapped then raise exception 'UNOWNED_DEPENDENCY_TARGET'; end if;
    if kind in ('INGREDIENT','UNIT','SCHOOL_TYPE','SUPPLIER') and coalesce(observed->>'ingredient_status',observed->>'unit_status',observed->>'school_type_status',observed->>'supplier_status')<>'ACTIVE' then raise exception 'INACTIVE_DEPENDENCY'; end if;
    if kind='INGREDIENT' and observed->'purchase_unit_id' is distinct from vals->'purchase_unit_id' then raise exception 'INGREDIENT_UNIT_DRIFT'; end if;
    if kind='SUPPLIER_ELIGIBILITY' and (observed->>'eligibility_status'<>'ACTIVE' or observed->'priority' is distinct from vals->'priority') then raise exception 'SUPPLIER_ELIGIBILITY_DRIFT'; end if;
   end if;
   actions:=actions||jsonb_build_array(atlas_legacy.master_recipe_action(kind,key,action,target,vals,atlas_legacy.master_snapshot_hash(r))||jsonb_build_object('before_values',observed,'dependency_reason','Missing Dish dependency closure'));
  end loop;
 end loop;
 empty_roots:=pg_temp.planning_catchup_empty_roots(scoped);
 -- Only the old Recipe composition planner receives this projection. The
 -- immutable scoped snapshot and source evidence retain every Recipe root.
 select jsonb_set(scoped,'{records,recipes}',coalesce(jsonb_agg(r.value),'[]')) into composed
 from jsonb_array_elements(scoped#>'{records,recipes}') r where exists
 (select 1 from jsonb_array_elements(scoped#>'{records,recipe_lines}') l where l.value->>'recipe_legacy_id'=r.value->>'legacy_id');
 extension:=atlas_legacy.master_import_recipe_plan(composed);
 issues:=coalesce(extension->'issues','[]')||(empty_roots->'issues');
 for a in select value from jsonb_array_elements(extension->'actions') where value->>'action'<>'MISSING_FROM_SOURCE' loop
  if a->>'action' not in ('CREATE','NO_CHANGE','BLOCKED') then raise exception 'EXISTING_RECIPE_CHANGE_FORBIDDEN'; end if;
  if a->>'action'='CREATE' and atlas_legacy.master_import_read(a->>'object_type',(a->>'target_id')::uuid) is not null then raise exception 'TARGET_ID_COLLISION'; end if;
  actions:=actions||jsonb_build_array(a||jsonb_build_object('before_values',atlas_legacy.master_import_read(a->>'object_type',(a->>'target_id')::uuid),'dependency_reason','Missing active source Dish and complete Recipes/BoM'));
 end loop;
 -- Dish actions precede root actions for the existing FK-preserving writer.
 actions:=actions||(empty_roots->'actions');
 select coalesce(max((s.value->>'display_order')::integer),0) into next_tail from jsonb_array_elements(snapshot#>'{records,schools}') s where not exists
 (select 1 from jsonb_array_elements(snapshot->'source_diagnostics') d where d.value->>'code'='INACTIVE_SCHOOL_DISPLAY_ORDER_DEFAULTED' and d.value->>'legacy_id'=s.value->>'legacy_id');
 orders:='[]';
 for r in select s.value from jsonb_array_elements(snapshot#>'{records,schools}') s order by
 case when exists(select 1 from jsonb_array_elements(snapshot->'source_diagnostics') d where d.value->>'code'='INACTIVE_SCHOOL_DISPLAY_ORDER_DEFAULTED' and d.value->>'legacy_id'=s.value->>'legacy_id') then 1 else 0 end,
 (s.value->>'display_order')::integer,s.value->>'school_name',s.value->>'legacy_id' loop
  key:=r->>'legacy_id';
  if exists(select 1 from jsonb_array_elements(snapshot->'source_diagnostics') d where d.value->>'code'='INACTIVE_SCHOOL_DISPLAY_ORDER_DEFAULTED' and d.value->>'legacy_id'=key) then next_tail:=next_tail+1;r:=r||jsonb_build_object('display_order',next_tail); end if;
  select m.school_id into target from atlas_legacy.master_data_mappings m where m.source_system='OPS_V1' and m.object_type='SCHOOL' and m.legacy_id=key;
  observed:=atlas_legacy.master_import_read('SCHOOL',target);
  if observed is null or observed->>'school_code'<>'v1-school-'||key then raise exception 'SCHOOL_TYPED_MAPPING_REQUIRED'; end if;
  vals:=(observed-'school_id'-'version')||jsonb_build_object('display_order',(r->>'display_order')::integer);
  if key='33' then
   if r->>'school_name'<>'THUẬN AN - PHÂN HIỆU' or observed->>'school_name' not in ('TRẦN ĐẠI NGHĨA','THUẬN AN - PHÂN HIỆU') then raise exception 'SCHOOL_33_SOURCE_DRIFT'; end if;
   vals:=vals||jsonb_build_object('school_name',r->>'school_name');
  end if;
  action:=case when vals=(observed-'school_id'-'version') then 'NO_CHANGE' else 'UPDATE' end;
  actions:=actions||jsonb_build_array(atlas_legacy.master_recipe_action('SCHOOL',key,action,target,vals,atlas_legacy.master_snapshot_hash(r))||jsonb_build_object('before_values',observed,'dependency_reason',case when key='33' then 'Canonical School 33 name and V1 display order' else 'Owner-approved V1 display order; NULLs deterministic tail' end));
  orders:=orders||jsonb_build_array(jsonb_build_object('legacy_id',key,'school_id',target,'display_order',(r->>'display_order')::integer));
 end loop;
 -- Owner sequences remain exact. Future source drift requires a newly reviewed plan.
 if exists(select 1 from (values (array['40','38']), (array['52','10']), (array['47','48','49','50','53'])) b(ids)
 where (select array_agg(value->>'legacy_id' order by ordinality) from jsonb_array_elements(orders) with ordinality where value->>'legacy_id'=any(b.ids)) is distinct from b.ids
 or b.ids<>array['40','38'] and (select max(ordinality)-min(ordinality)+1 from jsonb_array_elements(orders) with ordinality where value->>'legacy_id'=any(b.ids))<>cardinality(b.ids)) then raise exception 'OWNER_SCHOOL_SEQUENCE_DRIFT'; end if;
 if prior.import_batch_id is not null and (prior.reconciliation->'target_fingerprints' is distinct from pg_temp.planning_catchup_fingerprints(prior.reconciliation->'actions')) then raise exception 'TARGET_DRIFT'; end if;
 select coalesce(jsonb_agg(jsonb_build_object('SOURCE_SYSTEM','OPS_V1','OBJECT_TYPE',a.value->>'object_type','LEGACY_ID',a.value->>'legacy_id',
 'SOURCE_NAME',coalesce(a.value#>>'{values,school_name}',a.value#>>'{values,dish_name}',a.value#>>'{values,ingredient_name}',a.value#>>'{values,supplier_name}',a.value->>'legacy_id'),
 'CURRENT_ATLAS_ID',case when a.value->'before_values'<>'null'::jsonb then a.value->>'target_id' end,'CURRENT_ATLAS_VALUE',a.value->'before_values',
 'PROPOSED_ATLAS_ID',a.value->>'target_id','ACTION',case a.value->>'action' when 'NO_CHANGE' then 'DEPENDENCY_ONLY' else a.value->>'action' end,'SOURCE_RECIPE_ID',a.value#>>'{source_evidence,source_record_id}','DEPENDENCY_REASON',a.value->>'dependency_reason') order by a.value->>'object_type',a.value->>'legacy_id'),'[]') into report from jsonb_array_elements(actions) a;
 select jsonb_object_agg(x.kind,x.n) into summary from (select value->>'object_type' kind,count(*) n from jsonb_array_elements(actions) group by 1)x;
 plan:=jsonb_build_object('success',not exists(select 1 from jsonb_array_elements(issues) i where i.value->>'severity'='BLOCKER'),'snapshot_id',snapshot->>'snapshot_id','snapshot_checksum',snapshot->>'snapshot_checksum','actions',actions,'issues',issues,'report',report,'summary',summary,'school_orders',orders,'catchup_dish_ids',scoped->'catchup_dish_ids','protected',pg_temp.planning_catchup_protected(actions),'mapping_fingerprint',atlas_legacy.master_snapshot_hash((select coalesce(jsonb_agg(to_jsonb(m) order by m.object_type,m.legacy_id),'[]') from atlas_legacy.master_data_mappings m where m.source_system='OPS_V1')));
 return plan||jsonb_build_object('plan_checksum',atlas_legacy.master_snapshot_hash(plan));
end $$;

create or replace function pg_temp.planning_catchup_fingerprints(actions jsonb)
returns jsonb language sql stable set search_path='' as $$
 select coalesce(jsonb_object_agg(a.value->>'object_type'||':'||(a.value->>'legacy_id'),jsonb_build_object('target',atlas_legacy.master_snapshot_hash(atlas_legacy.master_import_read(a.value->>'object_type',(a.value->>'target_id')::uuid)),'mapping',
 (select atlas_legacy.master_snapshot_hash(to_jsonb(m)) from atlas_legacy.master_data_mappings m where m.source_system='OPS_V1' and m.object_type=a.value->>'object_type' and m.legacy_id=a.value->>'legacy_id'),
 'unit_adoption_evidence',(select atlas_legacy.master_snapshot_hash(coalesce(jsonb_agg(to_jsonb(e) order by e.recipe_unit_adoption_evidence_id),'[]')) from atlas_legacy.recipe_unit_adoption_evidence e where a.value->>'object_type'='RECIPE_LINE_REVISION' and e.target_recipe_line_revision_id=(a.value->>'target_id')::uuid))),'{}') from jsonb_array_elements(actions) a
$$;

create or replace function pg_temp.run_planning_master_catchup(snapshot jsonb, apply_requested boolean, expected_plan_checksum text, actor uuid)
returns jsonb language plpgsql volatile set search_path='' as $$
declare plan jsonb; prior atlas_legacy.import_batches%rowtype; batch uuid; a jsonb; scoped jsonb; result jsonb; protected jsonb; current_values jsonb; error_detail text;
begin
 begin
  if apply_requested then
   lock table atlas_admin.schools,atlas_admin.ingredients,atlas_admin.suppliers,atlas_admin.supplier_eligibilities,atlas_admin.units,atlas_admin.school_types,atlas_admin.ingredient_types,atlas_admin.ingredient_order_groups,atlas_admin.dish_types,atlas_admin.dishes,atlas_admin.recipes,atlas_admin.recipe_versions,atlas_admin.recipe_lines,atlas_admin.recipe_line_revisions,atlas_legacy.import_batches,atlas_legacy.master_data_mappings,atlas_legacy.recipe_unit_adoption_evidence in share row exclusive mode;
   lock table atlas_planning.weekly_menu_approval_snapshot_lines in share mode;
  end if;
  plan:=pg_temp.planning_catchup_plan(snapshot);
  if not apply_requested then return plan||jsonb_build_object('status','PREVIEW','business_writes',0); end if;
  if plan->>'success'<>'true' then return plan||jsonb_build_object('status','BLOCKED'); end if;
  if actor is null or not exists(select 1 from atlas_core.actors where actor_id=actor and actor_status='ACTIVE') then raise exception 'IMPORT_ACTOR_REQUIRED'; end if;
  select * into prior from atlas_legacy.import_batches where source_system='OPS_V1' and snapshot_id=snapshot->>'snapshot_id';
  if found then
   if prior.operator_actor_id is distinct from actor or prior.plan_checksum is distinct from expected_plan_checksum then raise exception 'REPLAY_AUTHORITY_MISMATCH'; end if;
   return prior.result_payload||jsonb_build_object('status','REPLAYED');
  end if;
  if expected_plan_checksum is distinct from plan->>'plan_checksum' then raise exception 'SOURCE_OR_TARGET_PLAN_DRIFT'; end if;
  protected:=plan->'protected';scoped:=pg_temp.planning_catchup_scope(snapshot);batch:=gen_random_uuid();
  insert into atlas_legacy.import_batches(import_batch_id,source_system,snapshot_id,snapshot_checksum,exported_at,import_status,completed_at,operator_actor_id,execution_database_principal,plan_checksum,snapshot_contract_version,source_counts)
  values(batch,'OPS_V1',snapshot->>'snapshot_id',snapshot->>'snapshot_checksum',(snapshot->>'exported_at')::timestamptz,'COMPLETED',clock_timestamp(),actor,session_user,expected_plan_checksum,'ATLAS-PLANNING-CATCHUP.v1',snapshot->'source_counts');
  for a in select value from jsonb_array_elements(plan->'actions') where value->>'object_type' not in ('DISH','RECIPE','RECIPE_VERSION','RECIPE_LINE','RECIPE_LINE_REVISION') loop perform atlas_legacy.master_import_write_core(a); end loop;
  perform atlas_legacy.master_import_apply_recipes(scoped,plan,actor);
  for a in select value from jsonb_array_elements(plan->'actions') where value->>'action' in ('CREATE','UPDATE') loop perform atlas_legacy.master_import_record_mapping(a,batch); end loop;
  perform atlas_legacy.record_master_recipe_unit_adoption_evidence(scoped,plan,batch,actor);
  for a in select value from jsonb_array_elements(plan->'actions') where value->>'object_type'='SCHOOL' loop
   current_values:=atlas_legacy.master_import_read('SCHOOL',(a->>'target_id')::uuid);
   if current_values-'school_id'-'version' is distinct from a->'values' then raise exception 'SCHOOL_READBACK_MISMATCH'; end if;
  end loop;
  if protected is distinct from pg_temp.planning_catchup_protected(plan->'actions') then raise exception 'UNRELATED_FACTS_CHANGED'; end if;
  set constraints all immediate;
  result:=jsonb_build_object('success',true,'status','APPLIED','import_batch_id',batch,'snapshot_checksum',snapshot->>'snapshot_checksum','plan_checksum',expected_plan_checksum,'operational_data_unchanged',true,'unrelated_master_facts_unchanged',true,'report',plan->'report','summary',plan->'summary','issues',plan->'issues');
  update atlas_legacy.import_batches set reconciliation=jsonb_build_object('actions',plan->'actions','catchup_dish_ids',plan->'catchup_dish_ids','target_fingerprints',pg_temp.planning_catchup_fingerprints(plan->'actions'),'protected',protected),result_payload=result,completed_at=clock_timestamp() where import_batch_id=batch;
  return result;
 exception when others then
  get stacked diagnostics error_detail=PG_EXCEPTION_DETAIL;
  if sqlerrm='SOURCE_DEPENDENCY_BLOCKED' then
   scoped:=pg_temp.planning_catchup_scope(snapshot);
   select jsonb_object_agg(e.key,jsonb_array_length(e.value)) into result from jsonb_each(scoped->'records') e;
  end if;
  return jsonb_build_object('success',false,'status','BLOCKED','error_code',case when sqlerrm ~ '^[A-Z][A-Z0-9_]+$' then sqlerrm else 'CATCHUP_DATABASE_INVARIANT_FAILURE' end,'sqlstate',sqlstate)
   ||case when sqlerrm='SOURCE_DEPENDENCY_BLOCKED' then jsonb_build_object('issues',error_detail::jsonb,'scope_counts',result) else '{}'::jsonb end;
 end;
end $$;
