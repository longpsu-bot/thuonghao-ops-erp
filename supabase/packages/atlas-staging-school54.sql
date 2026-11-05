-- Fixed three-root prerequisite; session-local, no persistent API or grants.
create or replace function pg_temp.school54_source(snapshot jsonb)
returns jsonb language plpgsql stable set search_path='' as $$
declare entities text[]:=array['customers','delivery_locations','dish_types','dishes','ingredient_order_groups','ingredient_types','ingredients','recipe_lines','recipes','school_types','schools','supplier_eligibilities','suppliers','units']; r jsonb; k text; expected text; roots jsonb:='[]'; type_row jsonb; type_id uuid; vals jsonb;
begin
 if snapshot->>'contract_version' is distinct from 'OPS-V1-MASTER-SNAPSHOT.v1' or snapshot->>'source_system' is distinct from 'OPS_V1' or snapshot->>'source_project_ref' is distinct from 'qnthofvccilhnefdcxnz'
 or nullif(snapshot->>'snapshot_id','') is null or nullif(snapshot->>'extractor_version','') is null or atlas_core.pa_05b_safe_timestamptz(snapshot->>'exported_at') is null
 or jsonb_typeof(snapshot->'records') is distinct from 'object' or jsonb_typeof(snapshot->'source_diagnostics') is distinct from 'array'
 or snapshot->'complete_entities' is distinct from to_jsonb(entities) or (select array_agg(key order by key) from jsonb_object_keys(snapshot->'records') key) is distinct from entities
 or exists(select 1 from jsonb_each(snapshot->'records') x where jsonb_typeof(x.value)<>'array') then raise exception 'INVALID_FULL_SNAPSHOT_ENVELOPE'; end if;
 if snapshot->>'snapshot_checksum' is distinct from atlas_legacy.master_snapshot_hash(snapshot-'snapshot_checksum') then raise exception 'SNAPSHOT_CHECKSUM_MISMATCH'; end if;
 if snapshot#>>'{source_access,role_name}' is distinct from 'supabase_read_only_user' or snapshot#>'{source_access,has_required_select}' is distinct from 'true'::jsonb
 or snapshot#>'{source_access,has_non_select_privilege}' is distinct from 'false'::jsonb or snapshot#>'{source_access,bypass_rls}' is distinct from 'true'::jsonb
 or snapshot#>'{source_access,superuser}' is distinct from 'false'::jsonb or snapshot#>'{source_access,create_role}' is distinct from 'false'::jsonb or snapshot#>'{source_access,create_db}' is distinct from 'false'::jsonb then raise exception 'SOURCE_NOT_PROVEN_READ_ONLY'; end if;
 if exists(select 1 from jsonb_each(snapshot->'records') e cross join lateral jsonb_array_elements(e.value) x group by e.key,x.value->>'legacy_id' having nullif(btrim(x.value->>'legacy_id'),'') is null or count(*)<>1) then raise exception 'SOURCE_IDENTITIES_INVALID'; end if;
 select value into r from jsonb_array_elements(snapshot#>'{records,schools}') where value->>'legacy_id'='54';
 if r is null or r->>'school_name' is distinct from 'TÂN AN HỘI (Mặn 2)' or r->>'school_code' is distinct from 'v1-school-54' or r->>'school_status' is distinct from 'ACTIVE'
 or r->>'customer_legacy_id' is distinct from 'school:54:customer' or r->>'delivery_location_legacy_id' is distinct from 'school:54:delivery-location' then raise exception 'SCHOOL54_SOURCE_IDENTITY_DRIFT'; end if;
 select value into type_row from jsonb_array_elements(snapshot#>'{records,school_types}') where value->>'legacy_id'=r->>'school_type_legacy_id';
 type_id:=atlas_legacy.master_import_target_id(snapshot,'SCHOOL_TYPE',r->>'school_type_legacy_id');
 vals:=atlas_legacy.master_import_values(snapshot,'SCHOOL_TYPE',type_row,type_id);
 if type_row is null or not exists(select 1 from atlas_legacy.master_data_mappings m where m.source_system='OPS_V1' and m.object_type='SCHOOL_TYPE' and m.legacy_id=type_row->>'legacy_id' and m.school_type_id=type_id)
 or atlas_legacy.master_import_read('SCHOOL_TYPE',type_id) is null or jsonb_array_length(atlas_legacy.master_import_validate_values('SCHOOL_TYPE',type_row->>'legacy_id',type_row,vals))<>0
 or exists(select 1 from jsonb_each(vals) x where x.value is distinct from atlas_legacy.master_import_read('SCHOOL_TYPE',type_id)->x.key) then raise exception 'EXISTING_SCHOOL_TYPE_REQUIRED'; end if;
 if exists(select 1 from jsonb_array_elements(snapshot->'source_diagnostics') d where d.value->>'severity'='BLOCKER' and ((d.value->>'entity'='schools' and d.value->>'legacy_id'='54') or d.value->>'entity' in ('customers','delivery_locations') and d.value->>'legacy_id' in ('school:54:customer','school:54:delivery-location') or d.value->>'entity'='school_types' and d.value->>'legacy_id'=type_row->>'legacy_id')) then raise exception 'SCHOOL54_SOURCE_FACTS_BLOCKED'; end if;
 foreach k in array array['CUSTOMER','DELIVERY_LOCATION','SCHOOL'] loop
 expected:=case k when 'CUSTOMER' then 'school:54:customer' when 'DELIVERY_LOCATION' then 'school:54:delivery-location' else '54' end;
 select value into r from jsonb_array_elements(snapshot#>array['records',atlas_legacy.master_import_entity(k)]) where value->>'legacy_id'=expected;
 if r is null then raise exception 'SCHOOL54_SOURCE_CLOSURE_REQUIRED'; end if;
 type_id:=atlas_legacy.master_import_target_id(snapshot,k,expected);vals:=atlas_legacy.master_import_values(snapshot,k,r,type_id);
 if jsonb_array_length(atlas_legacy.master_import_validate_values(k,expected,r,vals))<>0 then raise exception 'SCHOOL54_SOURCE_FACTS_BLOCKED'; end if;
 if k='CUSTOMER' and (r->>'customer_code' is distinct from 'v1-customer-54' or r->>'customer_status' is distinct from 'ACTIVE')
 or k='DELIVERY_LOCATION' and (r->>'location_code' is distinct from 'v1-location-54' or r->>'customer_legacy_id' is distinct from 'school:54:customer' or r->>'location_status' is distinct from 'ACTIVE' or nullif(btrim(r->>'address_text'),'') is null)
 then raise exception 'SCHOOL54_SOURCE_CLOSURE_REQUIRED'; end if;
 roots:=roots||jsonb_build_array(jsonb_build_object('object_type',k,'legacy_id',expected,'target_id',type_id,'action','CREATE','values',vals,'source_fingerprint',atlas_legacy.master_snapshot_hash(r)));
 end loop;
 return roots;
end $$;

create or replace function pg_temp.school54_protected(roots jsonb)
returns jsonb language plpgsql stable set search_path='' as $$
declare t record; value jsonb; result jsonb:='{}'; predicate text; k text;
begin
 for t in select n.nspname,c.relname from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace where n.nspname like 'atlas\_%' escape '\' and c.relkind in ('r','p') order by 1,2 loop
 predicate:='true';
 if t.nspname='atlas_admin' and t.relname in ('customers','delivery_locations','schools') then
 k:=case t.relname when 'customers' then 'CUSTOMER' when 'delivery_locations' then 'DELIVERY_LOCATION' else 'SCHOOL' end;
 predicate:=format('t.%I not in (select (value->>''target_id'')::uuid from jsonb_array_elements($1) where value->>''object_type''=%L)',atlas_legacy.master_import_mapping_column(k),k);
 elsif t.nspname='atlas_legacy' and t.relname='master_data_mappings' then predicate:='not (t.source_system=''OPS_V1'' and exists(select 1 from jsonb_array_elements($1) a where a.value->>''object_type''=t.object_type and a.value->>''legacy_id''=t.legacy_id))';
 elsif t.nspname='atlas_legacy' and t.relname='import_batches' then predicate:='not (t.source_system=''OPS_V1'' and t.snapshot_id=''atlas-staging-school54-prerequisite-v1'')'; end if;
 execute format('select jsonb_build_object(''rows'',count(*),''sha256'',atlas_legacy.master_snapshot_hash(coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text),''[]''::jsonb))) from %I.%I t where %s',t.nspname,t.relname,predicate) into value using roots;
 result:=result||jsonb_build_object(t.nspname||'.'||t.relname,value);
 end loop;return result;
end $$;
create or replace function pg_temp.school54_created_facts(roots jsonb)
returns jsonb language sql stable set search_path='' as $$
select jsonb_build_object('roots',(select jsonb_agg(jsonb_build_object('kind',a->>'object_type','value',atlas_legacy.master_import_read(a->>'object_type',(a->>'target_id')::uuid)) order by a->>'object_type') from jsonb_array_elements(roots) a),
'mappings',(select jsonb_agg(to_jsonb(m) order by m.object_type,m.legacy_id) from atlas_legacy.master_data_mappings m where m.source_system='OPS_V1' and exists(select 1 from jsonb_array_elements(roots) a where a->>'object_type'=m.object_type and a->>'legacy_id'=m.legacy_id)))
$$;

create or replace function pg_temp.run_staging_school54(snapshot jsonb, expected_versions jsonb, apply_requested boolean, expected_plan_checksum text, expected_content_checksum text)
returns jsonb language plpgsql volatile set search_path='' as $$
declare roots jsonb; a jsonb; protected jsonb; content_hash text; plan jsonb; response jsonb; prior atlas_legacy.import_batches%rowtype; batch uuid:=gen_random_uuid();
 actor uuid:=extensions.uuid_generate_v5('6ab4d3f5-0b6c-5fcb-b589-10d9f3db63c7','atlas-staging-master-import-actor'); t record; school jsonb; root_ids jsonb;
begin
 begin
 if current_user<>'postgres' or to_regclass('public.schools') is not null then raise exception 'STAGING_MASTER_TARGET_DENIED'; end if;
 perform pg_advisory_xact_lock(hashtextextended('atlas-staging-master-load',0));
 if apply_requested then for t in select n.nspname,c.relname from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace where n.nspname like 'atlas\_%' escape '\' and c.relkind in ('r','p') order by 1,2 loop execute format('lock table %I.%I in share row exclusive mode',t.nspname,t.relname); end loop; end if;
 if jsonb_array_length(expected_versions)<>138 or expected_versions->>-1 is distinct from '20261105090000' or (select jsonb_agg(version order by version) from supabase_migrations.schema_migrations) is distinct from expected_versions then raise exception 'EXACT_MIGRATION_HISTORY_REQUIRED'; end if;
 if not exists(select 1 from atlas_core.actors where actor_id=actor and actor_type='MIGRATION' and actor_status='ACTIVE' and display_name='Atlas Staging OPS v1 Master Import (GitHub Actions)') or exists(select 1 from atlas_core.actor_auth_subjects where actor_id=actor) then raise exception 'STAGING_IMPORT_ACTOR_REQUIRED'; end if;
 roots:=pg_temp.school54_source(snapshot);
 content_hash:=atlas_legacy.master_snapshot_hash(snapshot-array['snapshot_id','exported_at','extractor_version','snapshot_checksum']);
 if content_hash is distinct from expected_content_checksum then raise exception 'SOURCE_CONTENT_CHECKSUM_MISMATCH'; end if;
 protected:=pg_temp.school54_protected(roots);
 select * into prior from atlas_legacy.import_batches where source_system='OPS_V1' and snapshot_id='atlas-staging-school54-prerequisite-v1';
 if found then
 if prior.snapshot_contract_version is distinct from 'ATLAS-STAGING-SCHOOL54.v1' or prior.import_status is distinct from 'COMPLETED' or prior.operator_actor_id is distinct from actor or prior.snapshot_checksum is distinct from content_hash
 or prior.reconciliation->'protected_fingerprints' is distinct from protected or prior.reconciliation->'created_facts' is distinct from pg_temp.school54_created_facts(roots) then raise exception 'SCHOOL54_REPLAY_DRIFT'; end if;
 if apply_requested and expected_plan_checksum is distinct from prior.plan_checksum then raise exception 'REVIEWED_PLAN_CHANGED'; end if;
 return prior.result_payload||jsonb_build_object('status',case when apply_requested then 'REPLAYED' else 'ALREADY_APPLIED' end);
 end if;
 for a in select value from jsonb_array_elements(roots) loop
 if atlas_legacy.master_import_read(a->>'object_type',(a->>'target_id')::uuid) is not null or atlas_legacy.master_import_collision(a->>'object_type',(a->>'target_id')::uuid,a->'values')
 or exists(select 1 from atlas_legacy.master_data_mappings m where m.source_system='OPS_V1' and (m.object_type=a->>'object_type' and m.legacy_id=a->>'legacy_id' or (to_jsonb(m)->>atlas_legacy.master_import_mapping_column(a->>'object_type'))::uuid=(a->>'target_id')::uuid)) then raise exception 'SCHOOL54_EXISTING_IDENTITY_CONFLICT'; end if;
 end loop;
 if exists(select 1 from atlas_admin.schools where school_code='v1-school-54') or exists(select 1 from atlas_admin.customers where customer_code='v1-customer-54') or exists(select 1 from atlas_admin.delivery_locations where location_code='v1-location-54') then raise exception 'SCHOOL54_EXISTING_IDENTITY_CONFLICT'; end if;
 select jsonb_object_agg(atlas_legacy.master_import_mapping_column(j.value->>'object_type'),j.value->'target_id') into root_ids from jsonb_array_elements(roots) j;
 select j.value->'values' into school from jsonb_array_elements(roots) j where j.value->>'object_type'='SCHOOL';
 school:=(school-array['customer_type','default_delivery_location_id','dispatch_document_issuer_name','dispatch_document_issuer_address'])||jsonb_build_object('weekday_portion_defaults','{}'::jsonb,'delivery_location_id',root_ids->'delivery_location_id');
 plan:=jsonb_build_object('contract_version','ATLAS-STAGING-SCHOOL54.v1','content_checksum',content_hash,'actions',roots,'protected_fingerprints',protected,'expected_migration_versions',expected_versions,'actor_id',actor);
 response:=jsonb_build_object('success',true,'status','PREVIEW','content_checksum',content_hash,'plan_checksum',atlas_legacy.master_snapshot_hash(plan),'root_ids',root_ids,'school',school,'create_count',3,'protected_table_count',(select count(*) from jsonb_object_keys(protected)));
 if not apply_requested then return response; end if;
 if expected_plan_checksum is distinct from response->>'plan_checksum' then raise exception 'REVIEWED_PLAN_CHANGED'; end if;
 insert into atlas_legacy.import_batches(import_batch_id,source_system,snapshot_id,snapshot_checksum,exported_at,import_status,completed_at,operator_actor_id,execution_database_principal,plan_checksum,snapshot_contract_version,source_counts)
 values(batch,'OPS_V1','atlas-staging-school54-prerequisite-v1',content_hash,(snapshot->>'exported_at')::timestamptz,'COMPLETED',clock_timestamp(),actor,session_user,expected_plan_checksum,'ATLAS-STAGING-SCHOOL54.v1',snapshot->'source_counts');
 for a in select value from jsonb_array_elements(roots) loop perform atlas_legacy.master_import_write_core(a);perform atlas_legacy.master_import_record_mapping(a,batch);end loop;
 if protected is distinct from pg_temp.school54_protected(roots) then raise exception 'PROTECTED_DATA_CHANGED'; end if;
 for a in select value from jsonb_array_elements(roots) loop
 if exists(select 1 from jsonb_each(a->'values') v where v.value is distinct from atlas_legacy.master_import_read(a->>'object_type',(a->>'target_id')::uuid)->v.key) then raise exception 'ROOT_READBACK_DRIFT'; end if;
 end loop;
 if (select weekday_portion_defaults from atlas_admin.schools where school_id=(root_ids->>'school_id')::uuid) is distinct from '{}'::jsonb or (select count(*) from atlas_legacy.master_data_mappings where import_batch_id=batch)<>3 then raise exception 'ROOT_READBACK_DRIFT'; end if;
 response:=response||jsonb_build_object('status','APPLIED','import_batch_id',batch,'reconciled',true,'protected_unchanged',true);
 update atlas_legacy.import_batches set operation_counts='{"CREATE":3}',reconciliation=jsonb_build_object('protected_fingerprints',protected,'created_facts',pg_temp.school54_created_facts(roots),'source_snapshot_id',snapshot->>'snapshot_id','source_snapshot_checksum',snapshot->>'snapshot_checksum'),result_payload=response where import_batch_id=batch;
 return response;
 exception when others then return jsonb_build_object('success',false,'status','REJECTED','error_code',case when sqlerrm ~ '^[A-Z0-9_]+$' then sqlerrm else 'SCHOOL54_DATABASE_INVARIANT_FAILURE' end);end;
end $$;
