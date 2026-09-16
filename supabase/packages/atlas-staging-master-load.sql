-- Private, session-local package. Not an API and not an automatic migration seed.
-- Caller must verify exact Atlas Staging project and certified current-main SHA.
create or replace function pg_temp.staging_reference_uuid(name text)
returns uuid language sql immutable set search_path='' as $$
 select extensions.uuid_generate_v5('6ab4d3f5-0b6c-5fcb-b589-10d9f3db63c7'::uuid,name)
$$;

create or replace function pg_temp.staging_reference_inventory()
returns jsonb language sql stable set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object('object_type',kind,'legacy_id',legacy,
   'target_id',target,'uuid_name',uuid_name,'before_values',observed)
   order by kind,legacy),'[]') from (
 select 'SCHOOL_TYPE' kind,substr(school_type_code,16) legacy,school_type_id target,
   'school-type:'||substr(school_type_code,16) uuid_name,to_jsonb(t) observed
 from atlas_admin.school_types t where school_type_code ~ '^v1-school-type-[1-9][0-9]*$'
 union all
 select 'CUSTOMER','school:'||substr(customer_code,13)||':customer',customer_id,
   'customer:school:'||substr(customer_code,13),to_jsonb(t)
 from atlas_admin.customers t where customer_code ~ '^v1-customer-[1-9][0-9]*$'
 union all
 select 'DELIVERY_LOCATION','school:'||substr(location_code,13)||':delivery-location',delivery_location_id,
   'delivery-location:school:'||substr(location_code,13),to_jsonb(t)
 from atlas_admin.delivery_locations t where location_code ~ '^v1-location-[1-9][0-9]*$'
 union all
 select 'SCHOOL',substr(school_code,11),school_id,'school:'||substr(school_code,11),to_jsonb(t)
 from atlas_admin.schools t where school_code ~ '^v1-school-[1-9][0-9]*$'
 union all
 select 'INGREDIENT',substr(ingredient_code,15),ingredient_id,'ingredient:'||substr(ingredient_code,15),to_jsonb(t)
 from atlas_admin.ingredients t where ingredient_code ~ '^v1-ingredient-[1-9][0-9]*$'
 union all
 select 'SUPPLIER',substr(supplier_code,13),supplier_id,'supplier:'||substr(supplier_code,13),to_jsonb(t)
 from atlas_admin.suppliers t where supplier_code ~ '^v1-supplier-[1-9][0-9]*$'
 union all
 select 'SUPPLIER_ELIGIBILITY','ingredient:'||substr(i.ingredient_code,15)||':supplier:'||substr(s.supplier_code,13),
   e.supplier_eligibility_id,'supplier-eligibility:'||substr(i.ingredient_code,15)||':'||substr(s.supplier_code,13),to_jsonb(e)
 from atlas_admin.supplier_eligibilities e
 join atlas_admin.ingredients i using(ingredient_id) join atlas_admin.suppliers s using(supplier_id)
 where e.reason_note='Imported from OPS v1 reference snapshot; source relationship has no effective dating.'
   and e.effective_from='2000-01-01'::date
   and i.ingredient_code ~ '^v1-ingredient-[1-9][0-9]*$'
   and s.supplier_code ~ '^v1-supplier-[1-9][0-9]*$'
 ) inventory;
$$;

create or replace function pg_temp.staging_protected_fingerprints()
returns jsonb language plpgsql stable set search_path='' as $$
declare item record; value jsonb; result jsonb:='{}';
begin
 for item in select n.nspname,c.relname from pg_catalog.pg_class c
   join pg_catalog.pg_namespace n on n.oid=c.relnamespace
   where n.nspname in ('atlas_planning','atlas_procurement','atlas_dispatch','atlas_warehouse')
     and c.relkind in ('r','p') order by 1,2 loop
   execute format('select jsonb_build_object(''rows'',count(*),''sha256'',atlas_legacy.master_snapshot_hash(coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text),''[]''::jsonb))) from %I.%I t',item.nspname,item.relname) into value;
   result:=result||jsonb_build_object(item.nspname||'.'||item.relname,value);
 end loop;
 for item in select * from (values
   ('customers','customer_code','^v1-customer-[1-9][0-9]*$'),
   ('delivery_locations','location_code','^v1-location-[1-9][0-9]*$'),
   ('schools','school_code','^v1-school-[1-9][0-9]*$'),
   ('school_types','school_type_code','^v1-school-type-[1-9][0-9]*$'),
   ('ingredients','ingredient_code','^v1-ingredient-[1-9][0-9]*$'),
   ('suppliers','supplier_code','^v1-supplier-[1-9][0-9]*$'),
   ('dishes','dish_code','^v1-dish-[1-9][0-9]*$')
 ) x(table_name,code_column,owned_pattern) loop
   execute format('select to_jsonb(atlas_legacy.master_snapshot_hash(coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text),''[]''::jsonb))) from atlas_admin.%I t where t.%I !~ $1',item.table_name,item.code_column)
     into value using item.owned_pattern;
   result:=result||jsonb_build_object('unmanaged.'||item.table_name,value);
 end loop;
 return result;
end $$;

create or replace function pg_temp.prepare_staging_master_adoption()
returns jsonb language plpgsql volatile set search_path='' as $$
declare
 v_actor_id constant uuid:=pg_temp.staging_reference_uuid('atlas-staging-master-import-actor');
 batch_id constant uuid:=pg_temp.staging_reference_uuid('atlas-staging-reference-adoption-v1');
 inventory jsonb; item jsonb; receipt atlas_legacy.import_batches%rowtype;
 actor_row atlas_core.actors%rowtype; adopted_counts jsonb;
begin
 if current_user<>'postgres' or to_regclass('public.schools') is not null then
   raise exception 'STAGING_MASTER_TARGET_DENIED';
 end if;
 perform pg_advisory_xact_lock(hashtextextended('atlas-staging-master-load',0));
 select * into actor_row from atlas_core.actors where actors.actor_id=v_actor_id;
 if found and (actor_row.actor_type<>'MIGRATION' or actor_row.actor_status<>'ACTIVE'
   or actor_row.display_name<>'Atlas Staging OPS v1 Master Import (GitHub Actions)') then
   raise exception 'STAGING_MIGRATION_ACTOR_CONFLICT';
 end if;
 insert into atlas_core.actors(actor_id,actor_type,display_name)
 values(v_actor_id,'MIGRATION','Atlas Staging OPS v1 Master Import (GitHub Actions)') on conflict do nothing;
 select * into receipt from atlas_legacy.import_batches where import_batch_id=batch_id;
 if found then
   if receipt.snapshot_contract_version<>'STAGING-REFERENCE-ADOPTION.v1' or receipt.operator_actor_id<>v_actor_id then
     raise exception 'STAGING_ADOPTION_RECEIPT_CONFLICT';
   end if;
   return jsonb_build_object('actor_id',v_actor_id,'receipt_id',batch_id,
     'mappings',receipt.operation_counts->'adopted','already_adopted',true);
 end if;
 if exists(select 1 from atlas_legacy.master_data_mappings where source_system='OPS_V1') then
   raise exception 'STAGING_UNRECOGNIZED_EXISTING_CROSSWALK';
 end if;
 inventory:=pg_temp.staging_reference_inventory();
 for item in select x.value from jsonb_array_elements(inventory) x loop
   if (item->>'target_id')::uuid<>pg_temp.staging_reference_uuid(item->>'uuid_name') then
     raise exception 'STAGING_REFERENCE_IDENTITY_CONFLICT';
   end if;
 end loop;
 if exists(select 1 from atlas_admin.schools s where s.school_code ~ '^v1-school-[1-9][0-9]*$'
   and (s.customer_id<>pg_temp.staging_reference_uuid('customer:school:'||substr(s.school_code,11))
     or s.default_delivery_location_id<>pg_temp.staging_reference_uuid('delivery-location:school:'||substr(s.school_code,11))))
 or exists(select 1 from atlas_admin.delivery_locations l where l.location_code ~ '^v1-location-[1-9][0-9]*$'
   and l.customer_id<>pg_temp.staging_reference_uuid('customer:school:'||substr(l.location_code,13))) then
   raise exception 'STAGING_REFERENCE_LINKAGE_CONFLICT';
 end if;
 select coalesce(jsonb_object_agg(kind,n),'{}') into adopted_counts from (
   select value->>'object_type' kind,count(*) n from jsonb_array_elements(inventory) group by 1) x;
 insert into atlas_legacy.import_batches(import_batch_id,source_system,snapshot_id,snapshot_checksum,
   exported_at,import_status,completed_at,operator_actor_id,execution_database_principal,
   plan_checksum,snapshot_contract_version,source_counts,operation_counts,reconciliation)
 values(batch_id,'OPS_V1','atlas-staging-existing-reference-adoption-v1',atlas_legacy.master_snapshot_hash(inventory),
   clock_timestamp(),'COMPLETED',clock_timestamp(),v_actor_id,session_user,
   atlas_legacy.master_snapshot_hash(inventory),'STAGING-REFERENCE-ADOPTION.v1',adopted_counts,
   jsonb_build_object('adopted',jsonb_array_length(inventory)),jsonb_build_object('before_values',inventory,
     'units_before',(select coalesce(jsonb_agg(to_jsonb(u) order by unit_code),'[]') from atlas_admin.units u)));
 for item in select x.value from jsonb_array_elements(inventory) x loop
   perform atlas_legacy.master_import_record_mapping(item||jsonb_build_object(
     'action','NO_CHANGE','source_fingerprint',atlas_legacy.master_snapshot_hash(item->'before_values')),batch_id);
 end loop;
 update atlas_legacy.import_batches set reconciliation=reconciliation||jsonb_build_object(
   'target_fingerprints',atlas_legacy.master_import_capture_fingerprints()),
   result_payload=jsonb_build_object('status','REFERENCE_ADOPTED','actor_id',v_actor_id,'adopted_counts',adopted_counts)
 where import_batch_id=batch_id;
 return jsonb_build_object('actor_id',v_actor_id,'receipt_id',batch_id,'mappings',jsonb_array_length(inventory),'already_adopted',false);
end $$;

create or replace function pg_temp.run_staging_master_load(snapshot jsonb, apply_requested boolean, expected_plan_checksum text)
returns jsonb language plpgsql volatile set search_path='' as $$
declare adoption jsonb; plan jsonb; applied jsonb; response jsonb; before_guard jsonb; after_guard jsonb;
 old_unit atlas_admin.units%rowtype; prior atlas_legacy.import_batches%rowtype; counts jsonb; safe_error text;
begin
 -- All preparation and apply are one subtransaction. Preview and failures roll it back.
 begin
   if current_user<>'postgres' or to_regclass('public.schools') is not null then
     raise exception 'STAGING_MASTER_TARGET_DENIED';
   end if;
   if snapshot->>'snapshot_checksum' is distinct from atlas_legacy.master_snapshot_hash(snapshot-'snapshot_checksum') then
     raise exception 'SNAPSHOT_CHECKSUM_MISMATCH';
   end if;
   lock table atlas_admin.customers,atlas_admin.delivery_locations,atlas_admin.dish_types,atlas_admin.dishes,
     atlas_admin.ingredient_order_groups,atlas_admin.ingredient_types,atlas_admin.ingredients,
     atlas_admin.recipe_line_revisions,atlas_admin.recipe_lines,atlas_admin.recipe_versions,atlas_admin.recipes,
     atlas_admin.school_types,atlas_admin.schools,atlas_admin.supplier_eligibilities,atlas_admin.suppliers,atlas_admin.units,
     atlas_legacy.import_batches,atlas_legacy.master_data_mappings in share row exclusive mode;
   before_guard:=pg_temp.staging_protected_fingerprints();
   adoption:=pg_temp.prepare_staging_master_adoption();
   plan:=atlas_legacy.preview_master_data_snapshot(snapshot);
   select coalesce(jsonb_object_agg(action,n),'{}') into counts from (
     select value->>'action' action,count(*) n from jsonb_array_elements(coalesce(plan->'actions','[]')) group by 1) x;
   response:=jsonb_build_object('success',plan->'success','status',case when plan->>'success'='true' then 'PREVIEW' else 'REJECTED' end,
     'snapshot_id',snapshot->>'snapshot_id','snapshot_checksum',snapshot->>'snapshot_checksum','plan_checksum',plan->>'plan_checksum',
     'adoption',adoption,'planned_counts',counts,'target_counts',atlas_legacy.master_import_counts(),'issues',coalesce(plan->'issues','[]'));
   if not apply_requested or plan->>'success' is distinct from 'true' then
     raise exception using errcode='P9001',message='STAGING_PREVIEW_ROLLBACK';
   end if;
   select * into prior from atlas_legacy.import_batches where source_system='OPS_V1' and snapshot_id=snapshot->>'snapshot_id';
   if expected_plan_checksum is null or (expected_plan_checksum<>plan->>'plan_checksum' and
     not (prior.snapshot_checksum=snapshot->>'snapshot_checksum' and prior.plan_checksum=expected_plan_checksum)) is not false then
     raise exception 'STAGING_REVIEWED_PLAN_CHANGED';
   end if;
   applied:=atlas_legacy.apply_master_data_snapshot(snapshot,expected_plan_checksum,(adoption->>'actor_id')::uuid);
   if applied->>'success' is distinct from 'true' then
     response:=response||jsonb_build_object('success',false,'status','REJECTED','error_code',applied->>'error_code');
     raise exception using errcode='P9001',message='STAGING_APPLY_ROLLBACK';
   end if;
   -- Never rewrite immutable Unit references. Inactivate only the exact old spelling after current roots converge.
   select * into old_unit from atlas_admin.units where unit_code='v1-unit-a438e15c8427';
   if found then
     if old_unit.unit_id<>pg_temp.staging_reference_uuid('unit:Hủ') or old_unit.unit_name<>'Hủ'
       or old_unit.dimension_code<>'COUNT' or old_unit.decimal_scale<>0 then raise exception 'STAGING_JAR_UNIT_IDENTITY_CONFLICT'; end if;
     if exists(select 1 from atlas_admin.ingredients where purchase_unit_id=old_unit.unit_id) then
       raise exception 'STAGING_JAR_CURRENT_REFERENCE_REMAINS';
     end if;
     update atlas_admin.units set unit_status='INACTIVE' where unit_id=old_unit.unit_id and unit_status='ACTIVE';
   end if;
   after_guard:=pg_temp.staging_protected_fingerprints();
   if before_guard is distinct from after_guard then raise exception 'STAGING_PROTECTED_DATA_CHANGED'; end if;
   return response||jsonb_build_object('success',true,'status',case when applied->>'status'='REPLAYED' then 'REPLAYED' else 'APPLIED' end,
     'reconciled',true,'operational_data_unchanged',true,'unrelated_master_data_unchanged',true,
     'import_batch_id',applied->>'import_batch_id','operator_actor_id',adoption->>'actor_id',
     'target_counts',atlas_legacy.master_import_counts(),'protected_fingerprints',after_guard,
     'mapping_counts',(select jsonb_object_agg(object_type,n) from (select object_type,count(*) n from atlas_legacy.master_data_mappings where source_system='OPS_V1' group by object_type)x));
 exception
   when sqlstate 'P9001' then return response;
   when others then
     safe_error:=case when sqlerrm ~ '^[A-Z_]+$' then sqlerrm else 'STAGING_DATABASE_INVARIANT_FAILURE' end;
     return jsonb_build_object('success',false,'status','REJECTED','error_code',safe_error,'sqlstate',sqlstate);
 end;
end $$;
