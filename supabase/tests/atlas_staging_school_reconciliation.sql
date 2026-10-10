begin;
select no_plan();
\ir ../packages/atlas-staging-school-reconciliation.sql
select ok(to_regprocedure('pg_temp.run_staging_school_reconciliation(jsonb,boolean,text,jsonb)') is not null,'a controlled transactional School reconciliation entrypoint is available');
create function pg_temp.signed(value jsonb) returns jsonb language sql as $$ select (value-'snapshot_checksum')||jsonb_build_object('snapshot_checksum',atlas_legacy.master_snapshot_hash(value-'snapshot_checksum')) $$;
create function pg_temp.school_fixture() returns jsonb language plpgsql as $$
declare records jsonb:='{}'; entity text; names jsonb:=pg_temp.school_reconciliation_identities()||'{"21":"Unrelated School"}'::jsonb; s record;
 types jsonb:='[{"legacy_id":"1","school_type_code":"v1-school-type-1","school_type_name":"TIỂU HỌC","school_type_status":"ACTIVE"},{"legacy_id":"2","school_type_code":"v1-school-type-2","school_type_name":"TRUNG HỌC","school_type_status":"ACTIVE"}]'; snapshot jsonb;
begin
 foreach entity in array array['customers','delivery_locations','dish_types','dishes','ingredient_order_groups','ingredient_types','ingredients','recipe_lines','recipes','school_types','schools','supplier_eligibilities','suppliers','units'] loop records:=records||jsonb_build_object(entity,'[]'::jsonb); end loop;
 records:=jsonb_set(records,'{school_types}',types);
 for s in select key,value#>>'{}' as name from jsonb_each(names) order by key loop
  records:=jsonb_set(records,'{customers}',records->'customers'||jsonb_build_array(jsonb_build_object('legacy_id','school:'||s.key||':customer','customer_code','v1-customer-'||s.key,'customer_name','Synthetic customer '||s.key,'customer_type','SCHOOL_CATERING','customer_status','ACTIVE')));
  records:=jsonb_set(records,'{delivery_locations}',records->'delivery_locations'||jsonb_build_array(jsonb_build_object('legacy_id','school:'||s.key||':delivery-location','customer_legacy_id','school:'||s.key||':customer','location_code','v1-location-'||s.key,'location_name',s.name,'address_text','Synthetic address '||s.key,'delivery_instructions',null,'timezone_name','Asia/Ho_Chi_Minh','location_status','ACTIVE')));
  records:=jsonb_set(records,'{schools}',records->'schools'||jsonb_build_array(jsonb_build_object('legacy_id',s.key,'customer_legacy_id','school:'||s.key||':customer','delivery_location_legacy_id','school:'||s.key||':delivery-location','school_type_legacy_id',case when s.key in ('47','48','49','50','53') then '2' else '1' end,'school_code','v1-school-'||s.key,'school_name',s.name,'school_status','ACTIVE','display_order',s.key::integer,'default_student_portions',150,'default_teacher_portions',5,'dispatch_document_issuer_name','CÔNG TY TNHH MTV TM - DV THƯỢNG HẢO','dispatch_document_issuer_address','ĐC: 96/3 KP. Thạnh Lợi, Phường Thuận An, Tp Hồ Chí Minh, Việt Nam')));
 end loop;
 snapshot:=jsonb_build_object('contract_version','OPS-V1-MASTER-SNAPSHOT.v1','source_system','OPS_V1','source_project_ref','qnthofvccilhnefdcxnz','snapshot_id','synthetic-school-reconciliation-03','extractor_version','synthetic-v1','exported_at','2026-10-10T00:00:00Z',
 'complete_entities',(select jsonb_agg(key order by key) from jsonb_each(records)),'records',records,'source_diagnostics','[]'::jsonb,
 'source_counts',jsonb_build_object('schools',16),'source_access','{"role_name":"supabase_read_only_user","bypass_rls":true,"superuser":false,"create_role":false,"create_db":false,"has_required_select":true,"has_non_select_privilege":false}'::jsonb);
 return pg_temp.signed(snapshot);
end $$;
insert into atlas_core.actors(actor_id,actor_type,display_name)
values(extensions.uuid_generate_v5('6ab4d3f5-0b6c-5fcb-b589-10d9f3db63c7','atlas-staging-master-import-actor'),'MIGRATION','Atlas Staging OPS v1 Master Import (GitHub Actions)');
insert into atlas_legacy.import_batches(import_batch_id,source_system,snapshot_id,snapshot_checksum,exported_at,import_status,completed_at,operator_actor_id,execution_database_principal,plan_checksum,snapshot_contract_version,source_counts)
values('bb930000-0000-4000-8000-000000000001','OPS_V1','synthetic-prior-full','a'||repeat('0',63),'2026-09-16','COMPLETED','2026-09-16',extensions.uuid_generate_v5('6ab4d3f5-0b6c-5fcb-b589-10d9f3db63c7','atlas-staging-master-import-actor'),'postgres',repeat('b',64),'OPS-V1-MASTER-SNAPSHOT.v1','{}');
do $$
declare snapshot jsonb:=pg_temp.school_fixture(); kind text; row jsonb; target uuid; vals jsonb; action jsonb;
begin
 foreach kind in array array['SCHOOL_TYPE','CUSTOMER','DELIVERY_LOCATION','SCHOOL'] loop
  for row in select value from jsonb_array_elements(snapshot#>array['records',atlas_legacy.master_import_entity(kind)]) loop
   if kind<>'SCHOOL_TYPE' and (row->>'legacy_id' in ('52','47','48','49','50','53') or row->>'legacy_id' ~ '^school:(52|47|48|49|50|53):') then continue; end if;
   target:=extensions.uuid_generate_v5('6ab4d3f5-0b6c-5fcb-b589-10d9f3db63c7',kind||':'||(row->>'legacy_id'));
   vals:=atlas_legacy.master_import_values(snapshot,kind,row,target);
   if kind='SCHOOL' and row->>'legacy_id'='10' then vals:=vals||jsonb_build_object('school_name','BÌNH QUỚI','display_order',17); end if;
   action:=jsonb_build_object('object_type',kind,'legacy_id',row->>'legacy_id','target_id',target,'action','CREATE','values',vals,'source_fingerprint',atlas_legacy.master_snapshot_hash(row));
   perform atlas_legacy.master_import_write_core(action);
   perform atlas_legacy.master_import_record_mapping(action,'bb930000-0000-4000-8000-000000000001');
  end loop;
 end loop;
end $$;
insert into atlas_admin.suppliers(supplier_id,supplier_code,supplier_name,supplier_status) values('bb930000-0000-4000-8000-000000000999','v1-supplier-999','Prior supplier','ACTIVE');
select atlas_legacy.master_import_record_mapping(jsonb_build_object('object_type','SUPPLIER','legacy_id','999','target_id','bb930000-0000-4000-8000-000000000999','action','NO_CHANGE','source_fingerprint',repeat('c',64)),'bb930000-0000-4000-8000-000000000001');
update atlas_legacy.import_batches set reconciliation=jsonb_build_object('target_fingerprints',atlas_legacy.master_import_capture_fingerprints()) where snapshot_id='synthetic-prior-full';
update atlas_admin.suppliers set supplier_name='Legitimate later Supplier fact',version=version+1 where supplier_code='v1-supplier-999';
select ok(exists(select 1 from jsonb_array_elements(atlas_legacy.preview_master_data_snapshot(pg_temp.school_fixture())->'issues') i where i.value->>'code'='TARGET_DRIFT' and i.value->>'object_type'='SUPPLIER'),'ordinary full import blocks unrelated target drift');
create temp table supplier_before as select to_jsonb(s) value from atlas_admin.suppliers s where supplier_code='v1-supplier-999';
create temp table unrelated_before as select to_jsonb(s) value from atlas_admin.schools s where school_code='v1-school-21';
create temp table other_order_before as select array_agg(school_id order by display_order,school_name,school_id) value from atlas_admin.schools where school_code not in ('v1-school-10','v1-school-52','v1-school-47','v1-school-48','v1-school-49','v1-school-50','v1-school-53');
create temp table evidence(label text primary key,value jsonb);
insert into evidence values('preview',pg_temp.run_staging_school_reconciliation(pg_temp.school_fixture(),false,null,null));
select is((select value->>'success' from evidence where label='preview'),'true','stale/missing targets preview through typed controlled helpers');
select is((select count(*) from atlas_admin.schools),10::bigint,'preview creates no School');
select is((select count(*) from atlas_legacy.import_batches),1::bigint,'preview creates no receipt');
select is((select school_name from atlas_admin.schools where school_code='v1-school-10'),'BÌNH QUỚI','preview preserves stale current name');
select is((select jsonb_array_length(value->'projected_schools') from evidence where label='preview'),16,'all six missing Schools appear only in projected evidence');
select is(pg_temp.run_staging_school_reconciliation(pg_temp.signed(jsonb_set(pg_temp.school_fixture(),'{source_access,has_non_select_privilege}','true')),false,null,null)->>'error_code','SOURCE_NOT_PROVEN_READ_ONLY','source write authority fails closed');
select is(pg_temp.run_staging_school_reconciliation(pg_temp.signed(jsonb_set(pg_temp.school_fixture(),'{records,schools,0,school_name}','"Changed source identity"')),false,null,null)->>'error_code','SCHOOL_MASTER_RECONCILIATION_REQUIRED','source name drift cannot resolve a different identity');
update atlas_admin.schools set version=version+1 where school_code='v1-school-10';
select is(pg_temp.run_staging_school_reconciliation(pg_temp.school_fixture(),true,(select value->>'plan_checksum' from evidence where label='preview'),(select value->'target_school_order_ids' from evidence where label='preview'))->>'error_code','SCHOOL_TARGET_DRIFT','target version change after preview blocks apply');
update atlas_admin.schools set version=version-1 where school_code='v1-school-10';
select is(pg_temp.run_staging_school_reconciliation(pg_temp.school_fixture(),true,repeat('f',64),(select value->'target_school_order_ids' from evidence where label='preview'))->>'error_code','STAGING_REVIEWED_PLAN_CHANGED','wrong exact plan cannot mutate');
select is((select count(*) from atlas_admin.schools),10::bigint,'rejected plan leaves current Schools unchanged');
select is(pg_temp.run_staging_school_reconciliation(pg_temp.school_fixture(),true,(select value->>'plan_checksum' from evidence where label='preview'),'[]')->>'error_code','STAGING_REVIEWED_PLAN_CHANGED','wrong order cannot mutate');
update atlas_legacy.master_data_mappings set last_source_fingerprint=repeat('d',64) where object_type='SCHOOL' and legacy_id='10';
select is(pg_temp.run_staging_school_reconciliation(pg_temp.school_fixture(),true,(select value->>'plan_checksum' from evidence where label='preview'),(select value->'target_school_order_ids' from evidence where label='preview'))->>'error_code','STAGING_REVIEWED_PLAN_CHANGED','mapping metadata drift invalidates reviewed plan before writes');
update atlas_legacy.master_data_mappings set last_source_fingerprint=atlas_legacy.master_snapshot_hash((select value from jsonb_array_elements(pg_temp.school_fixture()#>'{records,schools}') where value->>'legacy_id'='10')) where object_type='SCHOOL' and legacy_id='10';
insert into evidence values('apply',pg_temp.run_staging_school_reconciliation(pg_temp.school_fixture(),true,(select value->>'plan_checksum' from evidence where label='preview'),(select value->'target_school_order_ids' from evidence where label='preview')));
select is((select value->>'success' from evidence where label='apply'),'true','exact preview applies atomically');
select is((select value->>'operational_data_unchanged' from evidence where label='apply'),'true','operational fingerprint guard passes');
select is((select value->>'unrelated_master_facts_unchanged' from evidence where label='apply'),'true','unrelated master fact guard passes');
select is((select to_jsonb(s) from atlas_admin.suppliers s where supplier_code='v1-supplier-999'),(select value from supplier_before),'later Supplier facts and their drift baseline remain untouched');
select is((select count(*) from atlas_admin.schools),16::bigint,'six source-supported missing Schools are created');
select is((select school_id from atlas_admin.schools where school_code='v1-school-10'),extensions.uuid_generate_v5('6ab4d3f5-0b6c-5fcb-b589-10d9f3db63c7','SCHOOL:10'),'existing adopted School UUID is retained');
select is((select school_name from atlas_admin.schools where school_code='v1-school-10'),'BÌNH QUỚI - PHÂN HIỆU','School 10 is canonical branch');
select is((select school_name from atlas_admin.schools where school_code='v1-school-52'),'BÌNH QUỚI','School 52 is canonical main');
select is((select count(*) from atlas_legacy.master_data_mappings where object_type='SCHOOL'),16::bigint,'every School has one typed mapping');
select is((select count(distinct school_id) from atlas_legacy.master_data_mappings where object_type='SCHOOL'),16::bigint,'source Schools never share a UUID');
select is((select to_jsonb(s)-'display_order'-'version'-'updated_at' from atlas_admin.schools s where school_code='v1-school-21'),(select value-'display_order'-'version'-'updated_at' from unrelated_before),'unrelated School facts remain identical except explicit order version');
select is((select b.display_order-a.display_order from atlas_admin.schools a,atlas_admin.schools b where a.school_code='v1-school-52' and b.school_code='v1-school-10'),1,'Bình Quới main and branch are adjacent main first');
select is((select array_agg(substr(school_code,11) order by display_order) from atlas_admin.schools where school_code in ('v1-school-47','v1-school-48','v1-school-49','v1-school-50','v1-school-53')),array['47','48','49','50','53'],'Hùng Vương exact five order retained');
select is((select max(display_order)-min(display_order) from atlas_admin.schools where school_code in ('v1-school-47','v1-school-48','v1-school-49','v1-school-50','v1-school-53')),4,'five Hùng Vương Schools form one adjacent block');
select is((select display_order from atlas_admin.schools where school_code='v1-school-21'),21,'unrelated existing numeric position is preserved where no collision requires a shift');
select is((select count(*) from atlas_legacy.import_batches where snapshot_contract_version='OPS-V1-SCHOOL-RECONCILIATION.v1'),1::bigint,'receipt truthfully describes School scope rather than full import');
select is((select array_agg(school_id order by display_order) from atlas_admin.schools where school_code not in ('v1-school-10','v1-school-52','v1-school-47','v1-school-48','v1-school-49','v1-school-50','v1-school-53')),(select value from other_order_before),'every other School retains its prior relative order');
select ok(not exists(select 1 from atlas_legacy.master_data_mappings m join atlas_admin.schools s on s.school_id=m.school_id where m.object_type='SCHOOL' and m.legacy_id in (select key from jsonb_each(pg_temp.school_reconciliation_identities())) and m.last_target_version<>s.version),'mapping versions include final owner-order update');
insert into evidence values('replay',pg_temp.run_staging_school_reconciliation(pg_temp.school_fixture(),true,(select value->>'plan_checksum' from evidence where label='preview'),(select value->'target_school_order_ids' from evidence where label='preview')));
select is((select value->>'status' from evidence where label='replay'),'REPLAYED','same immutable snapshot replays honestly');
select is((select count(*) from atlas_legacy.import_batches),2::bigint,'replay creates no duplicate receipt');
create temp table mapping_52_before as select * from atlas_legacy.master_data_mappings where object_type='SCHOOL' and legacy_id='52';
delete from atlas_legacy.master_data_mappings where object_type='SCHOOL' and legacy_id='52';
select is(pg_temp.run_staging_school_reconciliation(pg_temp.school_fixture(),true,(select value->>'plan_checksum' from evidence where label='preview'),(select value->'target_school_order_ids' from evidence where label='preview'))->>'error_code','SCHOOL_TARGET_DRIFT','deleted typed mapping cannot replay via deterministic UUID fallback');
select is(pg_temp.run_staging_school_reconciliation(pg_temp.school_fixture(),false,null,null)->>'error_code','SCHOOL_TARGET_DRIFT','same-snapshot preview validates typed mappings');
insert into atlas_legacy.master_data_mappings select * from mapping_52_before;
update atlas_admin.schools set default_student_portions=151 where school_code='v1-school-10';
select is(pg_temp.run_staging_school_reconciliation(pg_temp.school_fixture(),true,(select value->>'plan_checksum' from evidence where label='preview'),(select value->'target_school_order_ids' from evidence where label='preview'))->>'error_code','SCHOOL_TARGET_DRIFT','same-snapshot replay preserves target drift');
select is(pg_temp.run_staging_school_reconciliation(pg_temp.school_fixture(),false,null,null)->>'error_code','SCHOOL_TARGET_DRIFT','same-snapshot preview validates current facts');
select is((select default_student_portions from atlas_admin.schools where school_code='v1-school-10'),151,'target drift is never overwritten');
select is(pg_temp.run_staging_school_reconciliation(pg_temp.signed(jsonb_set(pg_temp.school_fixture(),'{snapshot_id}','"new-school-snapshot"')),false,null,null)->>'error_code','SCHOOL_TARGET_DRIFT','new snapshots also preserve current scoped target drift');
select is(pg_temp.run_staging_school_reconciliation(jsonb_set(pg_temp.school_fixture(),'{snapshot_checksum}','"invalid"'),false,null,null)->>'error_code','SNAPSHOT_CHECKSUM_MISMATCH','corrupted snapshot is rejected before writes');
select * from finish();
rollback;
