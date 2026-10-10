-- Session-local protected School reconciliation; never a persistent API or seed.
-- Exact current-main + Staging target checks belong to the protected workflow.
create or replace function pg_temp.school_reconciliation_identities()
returns jsonb language sql immutable set search_path='' as $$
select '{"10":"BÌNH QUỚI - PHÂN HIỆU","52":"BÌNH QUỚI","47":"CHUYÊN HÙNG VƯƠNG (Sáng)","48":"CHUYÊN HÙNG VƯƠNG (Trưa)","49":"CHUYÊN HÙNG VƯƠNG (Trưa Mặn 2)","50":"CHUYÊN HÙNG VƯƠNG (Chiều)","53":"CHUYÊN HÙNG VƯƠNG (Chiều Mặn 2)","40":"VĨNH TÂN","38":"VĨNH TÂN - PHÂN HIỆU","19":"PHÚ HOÀ ĐÔNG 1","46":"PHÚ HOÀ ĐÔNG 1 - PHÂN HIỆU 1","27":"PHÚ HOÀ ĐÔNG 1 - PHÂN HIỆU 2","28":"PHÚ HOÀ ĐÔNG 1 - PHÂN HIỆU 3","17":"PHẠM VĂN CỘI","14":"LÊ VĂN THẾ"}'::jsonb
$$;

create or replace function pg_temp.school_reconciliation_roots(snapshot jsonb)
returns table(object_type text,legacy_id text,target_id uuid)
language sql stable set search_path='' as $$
select k.kind,r.value->>'legacy_id',atlas_legacy.master_import_target_id(snapshot,k.kind,r.value->>'legacy_id')
from (values ('CUSTOMER','customers'),('DELIVERY_LOCATION','delivery_locations'),('SCHOOL','schools')) k(kind,entity)
cross join lateral jsonb_array_elements(snapshot#>array['records',k.entity]) r
where case k.kind
when 'SCHOOL' then pg_temp.school_reconciliation_identities() ? (r.value->>'legacy_id')
when 'CUSTOMER' then exists(select 1 from jsonb_object_keys(pg_temp.school_reconciliation_identities()) s(id) where r.value->>'legacy_id'='school:'||s.id||':customer')
else exists(select 1 from jsonb_object_keys(pg_temp.school_reconciliation_identities()) s(id) where r.value->>'legacy_id'='school:'||s.id||':delivery-location') end
$$;

create or replace function pg_temp.school_reconciliation_protected(snapshot jsonb)
returns jsonb language plpgsql stable set search_path='' as $$
declare t record; v jsonb; result jsonb:='{}'; predicate text; expression text;
begin
 for t in select n.nspname,c.relname from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
 where n.nspname in ('atlas_admin','atlas_planning','atlas_procurement','atlas_dispatch','atlas_warehouse','atlas_core','atlas_identity')
 and c.relkind in ('r','p') order by 1,2 loop
  predicate:='true'; expression:='to_jsonb(t)';
  if t.nspname='atlas_admin' and t.relname in ('customers','delivery_locations','schools') then
   predicate:=format('t.%I not in (select target_id from pg_temp.school_reconciliation_roots($1) where object_type=%L)',
    case t.relname when 'customers' then 'customer_id' when 'delivery_locations' then 'delivery_location_id' else 'school_id' end,
    case t.relname when 'customers' then 'CUSTOMER' when 'delivery_locations' then 'DELIVERY_LOCATION' else 'SCHOOL' end);
   if t.relname='schools' then expression:='to_jsonb(t)-''display_order''-''version''-''created_at''-''updated_at'''; end if;
  end if;
  execute format('select jsonb_build_object(''rows'',count(*),''sha256'',atlas_legacy.master_snapshot_hash(coalesce(jsonb_agg(%s order by (%s)::text),''[]''::jsonb))) from %I.%I t where %s',expression,expression,t.nspname,t.relname,predicate) into v using snapshot;
  result:=result||jsonb_build_object(t.nspname||'.'||t.relname,v);
 end loop;
 select jsonb_build_object('rows',count(*),'sha256',atlas_legacy.master_snapshot_hash(coalesce(jsonb_agg(to_jsonb(m) order by m.object_type,m.legacy_id),'[]')))
 into v from atlas_legacy.master_data_mappings m where not exists(select 1 from pg_temp.school_reconciliation_roots(snapshot) r
 where m.source_system='OPS_V1' and m.object_type=r.object_type and m.legacy_id=r.legacy_id);
 return result||jsonb_build_object('atlas_legacy.unrelated_mappings',v);
end $$;

create or replace function pg_temp.school_reconciliation_mapping_fingerprint(snapshot jsonb)
returns text language sql stable set search_path='' as $$
select atlas_legacy.master_snapshot_hash(coalesce(jsonb_agg(to_jsonb(m) order by m.object_type,m.legacy_id),'[]'))
from atlas_legacy.master_data_mappings m where m.source_system='OPS_V1' and exists(
 select 1 from pg_temp.school_reconciliation_roots(snapshot) r where m.object_type=r.object_type and m.legacy_id=r.legacy_id)
$$;

create or replace function pg_temp.school_reconciliation_order(schools jsonb,mappings jsonb)
returns jsonb language plpgsql immutable set search_path='' as $$
declare result jsonb; block jsonb; members jsonb; remaining jsonb; insertion integer; first_position integer;
begin
 select coalesce(jsonb_agg(r.value->'school_id' order by (r.value->>'display_order')::integer,r.ordinality),'[]')
 into result from jsonb_array_elements(schools) with ordinality r;
 for block in select value from jsonb_array_elements('[["52","10"],["47","48","49","50","53"]]'::jsonb) loop
  select jsonb_agg(m.value->'school_id' order by b.ordinality) into members
  from jsonb_array_elements(block) with ordinality b
  join lateral jsonb_array_elements(mappings) m on m.value->>'source_system'='OPS_V1' and m.value->>'object_type'='SCHOOL' and m.value->>'legacy_id'=b.value#>>'{}';
  if jsonb_array_length(members)<>jsonb_array_length(block) then raise exception 'SCHOOL_MASTER_RECONCILIATION_REQUIRED'; end if;
  select min(r.ordinality)::integer into first_position from jsonb_array_elements(result) with ordinality r where members @> jsonb_build_array(r.value);
  select count(*)::integer into insertion from jsonb_array_elements(result) with ordinality r where r.ordinality<first_position and not members @> jsonb_build_array(r.value);
  select coalesce(jsonb_agg(r.value order by r.ordinality),'[]') into remaining from jsonb_array_elements(result) with ordinality r where not members @> jsonb_build_array(r.value);
  select coalesce(jsonb_agg(r.value order by r.ordinality),'[]') into result from jsonb_array_elements(remaining) with ordinality r where r.ordinality<=insertion;
  result:=result||members;
  select result||coalesce(jsonb_agg(r.value order by r.ordinality),'[]') into result from jsonb_array_elements(remaining) with ordinality r where r.ordinality>insertion;
 end loop;
 return result;
end $$;

-- Keep existing numeric positions wherever possible; shift only collisions.
-- The two Owner blocks alone receive consecutive positions.
create or replace function pg_temp.school_reconciliation_positions(schools jsonb,mappings jsonb,ordered_ids jsonb)
returns jsonb language plpgsql immutable set search_path='' as $$
declare result jsonb:='[]'; item record; legacy text; members text[]; previous_position integer:=-1; position integer;
begin
 for item in select value id from jsonb_array_elements_text(ordered_ids) loop
  select m.value->>'legacy_id' into legacy from jsonb_array_elements(mappings) m where m.value->>'source_system'='OPS_V1' and m.value->>'object_type'='SCHOOL' and m.value->>'school_id'=item.id;
  if legacy in ('52','47') then
   members:=case when legacy='52' then array['52','10'] else array['47','48','49','50','53'] end;
   select min((s.value->>'display_order')::integer) into position from jsonb_array_elements(schools) s join jsonb_array_elements(mappings) m on m.value->>'school_id'=s.value->>'school_id' where m.value->>'source_system'='OPS_V1' and m.value->>'object_type'='SCHOOL' and m.value->>'legacy_id'=any(members);
   position:=greatest(position,previous_position+1);
  elsif legacy in ('10','48','49','50','53') then position:=previous_position+1;
  else select greatest((s.value->>'display_order')::integer,previous_position+1) into position from jsonb_array_elements(schools) s where s.value->>'school_id'=item.id;
  end if;
  if position is null then raise exception 'SCHOOL_OWNER_ORDER_ASSERTION_FAILED'; end if;
  result:=result||jsonb_build_array(jsonb_build_object('school_id',item.id,'display_order',position));
  previous_position:=position;
 end loop;
 return result;
end $$;

create or replace function pg_temp.school_reconciliation_plan(snapshot jsonb)
returns jsonb language plpgsql stable set search_path='' as $$
declare entities text[]:=array['customers','delivery_locations','dish_types','dishes','ingredient_order_groups','ingredient_types','ingredients','recipe_lines','recipes','school_types','schools','supplier_eligibilities','suppliers','units'];
 identities jsonb:=pg_temp.school_reconciliation_identities(); expected record; root record; r jsonb; vals jsonb; current_values jsonb; projected jsonb; issues jsonb;
 source_count integer; previous_fp text; act text; actions jsonb:='[]'; current_schools jsonb; current_mappings jsonb; projected_schools jsonb; projected_mappings jsonb;
 target_order jsonb; protected jsonb; plan jsonb; type_row jsonb; type_id uuid;
begin
 if current_user<>'postgres' or to_regclass('public.schools') is not null then raise exception 'STAGING_MASTER_TARGET_DENIED'; end if;
 if snapshot is null or jsonb_typeof(snapshot)<>'object'
 or snapshot->>'contract_version' is distinct from 'OPS-V1-MASTER-SNAPSHOT.v1'
 or snapshot->>'source_system' is distinct from 'OPS_V1' or snapshot->>'source_project_ref' is distinct from 'qnthofvccilhnefdcxnz'
 or nullif(btrim(snapshot->>'snapshot_id'),'') is null or nullif(btrim(snapshot->>'extractor_version'),'') is null
 or atlas_core.pa_05b_safe_timestamptz(snapshot->>'exported_at') is null
 or jsonb_typeof(snapshot->'records') is distinct from 'object' or jsonb_typeof(snapshot->'source_diagnostics') is distinct from 'array'
 or snapshot->'complete_entities' is distinct from to_jsonb(entities)
 or (select array_agg(x order by x) from jsonb_object_keys(snapshot->'records') x) is distinct from entities
 or exists(select 1 from jsonb_each(snapshot->'records') x where jsonb_typeof(x.value)<>'array') then raise exception 'INVALID_FULL_SNAPSHOT_ENVELOPE'; end if;
 if snapshot->>'snapshot_checksum' is distinct from atlas_legacy.master_snapshot_hash(snapshot-'snapshot_checksum') then raise exception 'SNAPSHOT_CHECKSUM_MISMATCH'; end if;
 if snapshot#>>'{source_access,role_name}' is distinct from 'supabase_read_only_user'
 or snapshot#>'{source_access,has_required_select}' is distinct from 'true'::jsonb
 or snapshot#>'{source_access,has_non_select_privilege}' is distinct from 'false'::jsonb
 or snapshot#>'{source_access,bypass_rls}' is distinct from 'true'::jsonb
 or snapshot#>'{source_access,superuser}' is distinct from 'false'::jsonb
 or snapshot#>'{source_access,create_role}' is distinct from 'false'::jsonb
 or snapshot#>'{source_access,create_db}' is distinct from 'false'::jsonb then raise exception 'SOURCE_NOT_PROVEN_READ_ONLY'; end if;
 if exists(select 1 from jsonb_array_elements(snapshot->'source_diagnostics') i where i.value->>'severity'='BLOCKER'
 and (i.value->>'entity'='school_types' or (i.value->>'entity'='schools' and identities ? (i.value->>'legacy_id')))) then raise exception 'SCHOOL_SOURCE_FACTS_BLOCKED'; end if;
 for expected in select key,value#>>'{}' as name from jsonb_each(identities) order by key loop
  select count(*) into source_count from jsonb_array_elements(snapshot#>'{records,schools}') x where x.value->>'legacy_id'=expected.key;
  if source_count<>1 then raise exception 'SCHOOL_MASTER_RECONCILIATION_REQUIRED'; end if;
  select value into r from jsonb_array_elements(snapshot#>'{records,schools}') x where x.value->>'legacy_id'=expected.key;
  if r->>'school_name' is distinct from expected.name or r->>'school_code' is distinct from 'v1-school-'||expected.key
  or r->>'customer_legacy_id' is distinct from 'school:'||expected.key||':customer'
  or r->>'delivery_location_legacy_id' is distinct from 'school:'||expected.key||':delivery-location'
  or r->>'school_type_legacy_id' not in ('1','2') then raise exception 'SCHOOL_MASTER_RECONCILIATION_REQUIRED'; end if;
  select count(*) into source_count from jsonb_array_elements(snapshot#>'{records,school_types}') x where x.value->>'legacy_id'=r->>'school_type_legacy_id';
  if source_count<>1 then raise exception 'SCHOOL_TYPE_REFERENCE_REQUIRED'; end if;
  select value into type_row from jsonb_array_elements(snapshot#>'{records,school_types}') x where x.value->>'legacy_id'=r->>'school_type_legacy_id';
  type_id:=atlas_legacy.master_import_target_id(snapshot,'SCHOOL_TYPE',r->>'school_type_legacy_id');
  if not exists(select 1 from atlas_legacy.master_data_mappings m where m.source_system='OPS_V1' and m.object_type='SCHOOL_TYPE' and m.legacy_id=r->>'school_type_legacy_id' and m.school_type_id=type_id)
  or atlas_legacy.master_import_read('SCHOOL_TYPE',type_id) is null
  or jsonb_array_length(atlas_legacy.master_import_validate_values('SCHOOL_TYPE',r->>'school_type_legacy_id',type_row,atlas_legacy.master_import_values(snapshot,'SCHOOL_TYPE',type_row,type_id)))<>0
  or exists(select 1 from jsonb_each(atlas_legacy.master_import_values(snapshot,'SCHOOL_TYPE',type_row,type_id)) x where x.value is distinct from atlas_legacy.master_import_read('SCHOOL_TYPE',type_id)->x.key) then raise exception 'SCHOOL_TYPE_REFERENCE_REQUIRED'; end if;
 end loop;
 if (select count(*) from pg_temp.school_reconciliation_roots(snapshot))<>45 then raise exception 'SCHOOL_PARENT_SOURCE_REQUIRED'; end if;
 if exists(select 1 from pg_temp.school_reconciliation_roots(snapshot) group by object_type,legacy_id having count(*)<>1)
 or exists(select 1 from pg_temp.school_reconciliation_roots(snapshot) group by object_type,target_id having count(*)<>1) then raise exception 'SCHOOL_MASTER_RECONCILIATION_REQUIRED'; end if;
 for root in select * from pg_temp.school_reconciliation_roots(snapshot) order by case object_type when 'CUSTOMER' then 1 when 'DELIVERY_LOCATION' then 2 else 3 end,legacy_id collate "C" loop
  select value into r from jsonb_array_elements(snapshot#>array['records',atlas_legacy.master_import_entity(root.object_type)]) x where x.value->>'legacy_id'=root.legacy_id;
  current_values:=atlas_legacy.master_import_read(root.object_type,root.target_id);
  vals:=atlas_legacy.master_import_values(snapshot,root.object_type,r,root.target_id);
  if root.object_type='SCHOOL' and current_values is not null then vals:=jsonb_set(vals,'{display_order}',current_values->'display_order'); end if;
  if jsonb_array_length(atlas_legacy.master_import_validate_values(root.object_type,root.legacy_id,r,vals))<>0
  or atlas_legacy.master_import_collision(root.object_type,root.target_id,vals) then raise exception 'SCHOOL_SOURCE_FACTS_BLOCKED'; end if;
  if exists(select 1 from atlas_legacy.master_data_mappings m where m.source_system='OPS_V1' and m.object_type=root.object_type and m.legacy_id<>root.legacy_id and (to_jsonb(m)->>atlas_legacy.master_import_mapping_column(root.object_type))::uuid=root.target_id) then raise exception 'SCHOOL_MASTER_RECONCILIATION_REQUIRED'; end if;
  if root.object_type='SCHOOL' and exists(select 1 from atlas_admin.schools s where s.school_code=vals->>'school_code' and s.school_id<>root.target_id) then raise exception 'SCHOOL_MASTER_RECONCILIATION_REQUIRED'; end if;
  if current_values is not null then
   if not exists(select 1 from atlas_legacy.master_data_mappings m where m.source_system='OPS_V1' and m.object_type=root.object_type and m.legacy_id=root.legacy_id) then raise exception 'SCHOOL_MASTER_RECONCILIATION_REQUIRED'; end if;
   select b.reconciliation#>>array['target_fingerprints',root.object_type,root.legacy_id] into previous_fp
   from atlas_legacy.import_batches b where b.source_system='OPS_V1' and b.import_status='COMPLETED'
    and b.snapshot_contract_version in ('OPS-V1-MASTER-SNAPSHOT.v1','OPS-V1-SCHOOL-RECONCILIATION.v1')
    and b.reconciliation#>>array['target_fingerprints',root.object_type,root.legacy_id] is not null
   order by b.completed_at desc,b.import_batch_id desc limit 1;
   if previous_fp is distinct from atlas_legacy.master_snapshot_hash(current_values) then raise exception 'SCHOOL_TARGET_DRIFT'; end if;
   if root.object_type='SCHOOL' and (current_values->>'school_code' is distinct from vals->>'school_code'
    or current_values->'customer_id' is distinct from vals->'customer_id'
    or current_values->'default_delivery_location_id' is distinct from vals->'default_delivery_location_id') then raise exception 'SCHOOL_MASTER_RECONCILIATION_REQUIRED'; end if;
  elsif exists(select 1 from atlas_legacy.master_data_mappings m where m.source_system='OPS_V1' and m.object_type=root.object_type and m.legacy_id=root.legacy_id) then raise exception 'SCHOOL_MASTER_RECONCILIATION_REQUIRED';
  end if;
  select coalesce(jsonb_object_agg(x.key,current_values->x.key),'{}') into projected from jsonb_each(vals) x;
  act:=case when current_values is null then 'CREATE' when projected=vals then 'NO_CHANGE' else 'UPDATE' end;
  actions:=actions||jsonb_build_array(jsonb_build_object('object_type',root.object_type,'legacy_id',root.legacy_id,'target_id',root.target_id,'action',act,'values',vals,'before_values',current_values,'source_fingerprint',atlas_legacy.master_snapshot_hash(r)));
 end loop;
 if exists(select 1 from atlas_admin.schools s where not identities ? substr(s.school_code,11) and (
   s.customer_id in (select target_id from pg_temp.school_reconciliation_roots(snapshot) where object_type='CUSTOMER')
   or s.default_delivery_location_id in (select target_id from pg_temp.school_reconciliation_roots(snapshot) where object_type='DELIVERY_LOCATION'))) then raise exception 'SCHOOL_PARENT_SHARED_OUTSIDE_SCOPE'; end if;
 select coalesce(jsonb_agg(jsonb_build_object('school_id',s.school_id,'school_code',s.school_code,'school_name',s.school_name,'display_order',s.display_order,'version',s.version) order by s.display_order,s.school_name,s.school_id),'[]')
 into current_schools from atlas_admin.schools s;
 select coalesce(jsonb_agg(jsonb_build_object('source_system',m.source_system,'object_type',m.object_type,'legacy_id',m.legacy_id,'school_id',m.school_id) order by m.legacy_id),'[]')
 into current_mappings from atlas_legacy.master_data_mappings m where m.source_system='OPS_V1' and m.object_type='SCHOOL';
 select coalesce(jsonb_agg(x.value order by (x.value->>'display_order')::integer,x.value->>'school_name',x.value->>'school_id'),'[]') into projected_schools from (
  select s.value from jsonb_array_elements(current_schools) s where not exists(select 1 from jsonb_array_elements(actions) a where a.value->>'object_type'='SCHOOL' and a.value->'target_id'=s.value->'school_id')
  union all select jsonb_build_object('school_id',a.value->'target_id','school_code',a.value#>'{values,school_code}','school_name',a.value#>'{values,school_name}','display_order',a.value#>'{values,display_order}')
  from jsonb_array_elements(actions) a where a.value->>'object_type'='SCHOOL'
 ) x;
 select coalesce(jsonb_agg(x.value order by x.value->>'legacy_id'),'[]') into projected_mappings from (
  select m.value from jsonb_array_elements(current_mappings) m where not identities ? (m.value->>'legacy_id')
  union all select jsonb_build_object('source_system','OPS_V1','object_type','SCHOOL','legacy_id',a.value->>'legacy_id','school_id',a.value->'target_id') from jsonb_array_elements(actions) a where a.value->>'object_type'='SCHOOL'
 ) x;
 target_order:=pg_temp.school_reconciliation_order(projected_schools,projected_mappings);
 protected:=pg_temp.school_reconciliation_protected(snapshot);
 plan:=jsonb_build_object('success',true,'status','PREVIEW','snapshot_id',snapshot->>'snapshot_id','snapshot_checksum',snapshot->>'snapshot_checksum',
 'actions',actions,'current_schools',current_schools,'current_mappings',current_mappings,'projected_schools',projected_schools,'projected_mappings',projected_mappings,
 'target_school_order_ids',target_order,'target_school_display_orders',pg_temp.school_reconciliation_positions(projected_schools,projected_mappings,target_order),'protected_fingerprints',protected,'scoped_mapping_fingerprint',pg_temp.school_reconciliation_mapping_fingerprint(snapshot));
 return plan||jsonb_build_object('plan_checksum',atlas_legacy.master_snapshot_hash(plan));

end $$;

create or replace function pg_temp.run_staging_school_reconciliation(snapshot jsonb,apply_requested boolean,expected_plan_checksum text,requested_order jsonb)
returns jsonb language plpgsql volatile set search_path='' as $$
declare plan jsonb; response jsonb; a jsonb; receipt atlas_legacy.import_batches%rowtype; batch_id uuid:=gen_random_uuid();
 v_actor_id uuid:=extensions.uuid_generate_v5('6ab4d3f5-0b6c-5fcb-b589-10d9f3db63c7','atlas-staging-master-import-actor');
 before_guard jsonb; after_guard jsonb; fp jsonb; all_school_fp jsonb; safe_error text; v_operation_counts jsonb; owner_order_updates integer;
begin
 begin
  if current_user<>'postgres' or to_regclass('public.schools') is not null then raise exception 'STAGING_MASTER_TARGET_DENIED'; end if;
  perform pg_advisory_xact_lock(hashtextextended('atlas-staging-master-load',0));
  lock table atlas_admin.customers,atlas_admin.delivery_locations,atlas_admin.school_types,atlas_admin.schools,
   atlas_legacy.import_batches,atlas_legacy.master_data_mappings in share row exclusive mode;
  if not exists(select 1 from atlas_core.actors a where a.actor_id=v_actor_id and a.actor_type='MIGRATION' and a.actor_status='ACTIVE' and a.display_name='Atlas Staging OPS v1 Master Import (GitHub Actions)') then raise exception 'STAGING_IMPORT_ACTOR_REQUIRED'; end if;
  if snapshot->>'snapshot_checksum' is distinct from atlas_legacy.master_snapshot_hash(snapshot-'snapshot_checksum') then raise exception 'SNAPSHOT_CHECKSUM_MISMATCH'; end if;
  select * into receipt from atlas_legacy.import_batches b where b.source_system='OPS_V1' and b.snapshot_id=snapshot->>'snapshot_id';
  if found then
   if receipt.snapshot_contract_version<>'OPS-V1-SCHOOL-RECONCILIATION.v1' or receipt.snapshot_checksum<>snapshot->>'snapshot_checksum'
    or receipt.operator_actor_id<>v_actor_id or receipt.import_status<>'COMPLETED' then raise exception 'SNAPSHOT_ID_CONFLICT'; end if;
   select jsonb_object_agg(s.school_id::text,atlas_legacy.master_snapshot_hash(atlas_legacy.master_import_read('SCHOOL',s.school_id))) into all_school_fp from atlas_admin.schools s;
   if all_school_fp is distinct from receipt.reconciliation->'all_school_fingerprints'
    or pg_temp.school_reconciliation_mapping_fingerprint(snapshot) is distinct from receipt.reconciliation->>'scoped_mapping_fingerprint'
    or pg_temp.school_reconciliation_protected(snapshot) is distinct from receipt.reconciliation->'protected_fingerprints'
    or exists(select 1 from pg_temp.school_reconciliation_roots(snapshot) r where receipt.reconciliation#>>array['target_fingerprints',r.object_type,r.legacy_id] is distinct from atlas_legacy.master_snapshot_hash(atlas_legacy.master_import_read(r.object_type,r.target_id)))
   then raise exception 'SCHOOL_TARGET_DRIFT'; end if;
   if not apply_requested then return receipt.result_payload||jsonb_build_object('status','ALREADY_RECONCILED'); end if;
   if expected_plan_checksum is distinct from receipt.plan_checksum or requested_order is distinct from receipt.reconciliation->'target_school_order_ids' then raise exception 'STAGING_REVIEWED_PLAN_CHANGED'; end if;
   return receipt.result_payload||jsonb_build_object('status','REPLAYED');
  end if;
  plan:=pg_temp.school_reconciliation_plan(snapshot);
  response:=plan-'actions';
  if not apply_requested then return response; end if;
  if expected_plan_checksum is distinct from plan->>'plan_checksum' or requested_order is distinct from plan->'target_school_order_ids' then raise exception 'STAGING_REVIEWED_PLAN_CHANGED'; end if;
  before_guard:=plan->'protected_fingerprints';
  select jsonb_object_agg(action,n) into v_operation_counts from (select x.value->>'action' action,count(*) n from jsonb_array_elements(plan->'actions') x group by x.value->>'action') c;
  insert into atlas_legacy.import_batches(import_batch_id,source_system,snapshot_id,snapshot_checksum,exported_at,import_status,completed_at,operator_actor_id,execution_database_principal,plan_checksum,snapshot_contract_version,source_counts)
  values(batch_id,'OPS_V1',snapshot->>'snapshot_id',snapshot->>'snapshot_checksum',(snapshot->>'exported_at')::timestamptz,'COMPLETED',clock_timestamp(),v_actor_id,session_user,expected_plan_checksum,'OPS-V1-SCHOOL-RECONCILIATION.v1',snapshot->'source_counts');
  for a in select value from jsonb_array_elements(plan->'actions') loop
   perform atlas_legacy.master_import_write_core(a);
  end loop;
  -- The connected Admin contract has no School order writer. This explicit
  -- owner-order step is part of the controlled transaction and receipt.
  update atlas_admin.schools s set display_order=(o.value->>'display_order')::integer,version=s.version+1,updated_at=clock_timestamp()
  from jsonb_array_elements(plan->'target_school_display_orders') o
  where s.school_id=(o.value->>'school_id')::uuid and s.display_order is distinct from (o.value->>'display_order')::integer;
  get diagnostics owner_order_updates=row_count;
  if exists(select 1 from jsonb_array_elements(plan->'actions') x cross join lateral jsonb_each(x.value->'values') v
   where v.key<>'display_order' and v.value is distinct from atlas_legacy.master_import_read(x.value->>'object_type',(x.value->>'target_id')::uuid)->v.key)
  or exists(select 1 from jsonb_array_elements(plan->'target_school_display_orders') o join atlas_admin.schools s on s.school_id=(o.value->>'school_id')::uuid where s.display_order<>(o.value->>'display_order')::integer) then raise exception 'IMPORT_READBACK_DID_NOT_RECONCILE'; end if;
  for a in select value from jsonb_array_elements(plan->'actions') loop
   perform atlas_legacy.master_import_record_mapping(a,batch_id);
  end loop;
  after_guard:=pg_temp.school_reconciliation_protected(snapshot);
  if before_guard is distinct from after_guard then raise exception 'STAGING_PROTECTED_DATA_CHANGED'; end if;
  select jsonb_object_agg(kind,fps) into fp from (
   select r.object_type kind,jsonb_object_agg(r.legacy_id,atlas_legacy.master_snapshot_hash(atlas_legacy.master_import_read(r.object_type,r.target_id))) fps
   from pg_temp.school_reconciliation_roots(snapshot) r group by r.object_type
  ) x;
  select jsonb_object_agg(s.school_id::text,atlas_legacy.master_snapshot_hash(atlas_legacy.master_import_read('SCHOOL',s.school_id))) into all_school_fp from atlas_admin.schools s;
  response:=response||jsonb_build_object('success',true,'status','APPLIED','import_batch_id',batch_id,'operator_actor_id',v_actor_id,'reconciled',true,'operational_data_unchanged',true,'unrelated_master_facts_unchanged',true,'operation_counts',v_operation_counts,'owner_order_update_count',owner_order_updates);
  update atlas_legacy.import_batches set reconciliation=jsonb_build_object('actions',plan->'actions','target_fingerprints',fp,'all_school_fingerprints',all_school_fp,
   'target_school_order_ids',requested_order,'protected_fingerprints',after_guard,'scoped_mapping_fingerprint',pg_temp.school_reconciliation_mapping_fingerprint(snapshot),'source_snapshot_contract',snapshot->>'contract_version'),
   operation_counts=v_operation_counts||jsonb_build_object('OWNER_ORDER_UPDATE',owner_order_updates),result_payload=response,completed_at=clock_timestamp() where import_batch_id=batch_id;
  return response;
 exception when others then
  safe_error:=case when sqlerrm ~ '^[A-Z_]+$' then sqlerrm else 'STAGING_DATABASE_INVARIANT_FAILURE' end;
  return jsonb_build_object('success',false,'status','REJECTED','error_code',safe_error,'sqlstate',sqlstate);
 end;
end $$;
