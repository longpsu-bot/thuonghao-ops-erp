begin;
select no_plan();
\ir ../packages/atlas-staging-school54.sql
create function pg_temp.signed(v jsonb) returns jsonb language sql as $$ select (v-'snapshot_checksum')||jsonb_build_object('snapshot_checksum',atlas_legacy.master_snapshot_hash(v-'snapshot_checksum')) $$;
create function pg_temp.content(v jsonb) returns text language sql as $$ select pg_temp.school54_content(v) $$;
create function pg_temp.fixture() returns jsonb language plpgsql as $$
declare records jsonb:='{}';entity text;v jsonb;
begin
 foreach entity in array array['customers','delivery_locations','dish_types','dishes','ingredient_order_groups','ingredient_types','ingredients','recipe_lines','recipes','school_types','schools','supplier_eligibilities','suppliers','units'] loop records:=records||jsonb_build_object(entity,'[]'::jsonb);end loop;
 records:=records||jsonb_build_object(
 'school_types','[{"legacy_id":"1","school_type_code":"v1-school-type-1","school_type_name":"TIỂU HỌC","school_type_status":"ACTIVE"}]'::jsonb,
 'customers','[{"legacy_id":"school:54:customer","customer_code":"v1-customer-54","customer_name":"Synthetic full School54 name","customer_type":"SCHOOL_CATERING","customer_status":"ACTIVE"}]'::jsonb,
 'delivery_locations','[{"legacy_id":"school:54:delivery-location","customer_legacy_id":"school:54:customer","location_code":"v1-location-54","location_name":"TÂN AN HỘI (Mặn 2)","address_text":"Synthetic explicit source address","delivery_instructions":null,"timezone_name":"Asia/Ho_Chi_Minh","location_status":"ACTIVE"}]'::jsonb,
 'schools','[{"legacy_id":"54","customer_legacy_id":"school:54:customer","delivery_location_legacy_id":"school:54:delivery-location","school_type_legacy_id":"1","school_code":"v1-school-54","school_name":"TÂN AN HỘI (Mặn 2)","school_status":"ACTIVE","display_order":34,"default_student_portions":0,"default_teacher_portions":0,"dispatch_document_issuer_name":"CƠ SỞ CUNG CẤP THỰC PHẨM THƯỢNG HẢO","dispatch_document_issuer_address":"ĐC: 96/3 KP. Thạnh Lợi, Phường Thuận An, Tp Hồ Chí Minh, Việt Nam"}]'::jsonb);
 v:=jsonb_build_object('contract_version','OPS-V1-MASTER-SNAPSHOT.v1','source_system','OPS_V1','source_project_ref','qnthofvccilhnefdcxnz','snapshot_id','school54-fixture','extractor_version','synthetic','exported_at','2026-11-05T00:00:00Z','records',records,'complete_entities',(select jsonb_agg(key order by key) from jsonb_each(records)),
 'source_counts','{"schools":1}'::jsonb,'source_diagnostics','[]'::jsonb,'source_access','{"role_name":"supabase_read_only_user","bypass_rls":true,"superuser":false,"create_role":false,"create_db":false,"has_required_select":true,"has_non_select_privilege":false}'::jsonb);
 return pg_temp.signed(v);
end $$;
create function pg_temp.unselected(v jsonb) returns jsonb language sql as $$ select pg_temp.signed(jsonb_set(v,'{records,suppliers}','[{"legacy_id":"999","supplier_code":"v1-supplier-999","supplier_name":"Changed unrelated supplier","supplier_status":"ACTIVE"}]')) $$;
create function pg_temp.run(v jsonb, apply_requested boolean default false, checksum text default null) returns jsonb language sql as $$ select pg_temp.run_staging_school54(v,(select jsonb_agg(version order by version) from supabase_migrations.schema_migrations),apply_requested,checksum,pg_temp.content(v)) $$;
insert into atlas_core.actors(actor_id,actor_type,display_name) values(extensions.uuid_generate_v5('6ab4d3f5-0b6c-5fcb-b589-10d9f3db63c7','atlas-staging-master-import-actor'),'MIGRATION','Atlas Staging OPS v1 Master Import (GitHub Actions)') on conflict do nothing;
insert into atlas_legacy.import_batches(import_batch_id,source_system,snapshot_id,snapshot_checksum,exported_at,import_status,completed_at,operator_actor_id,execution_database_principal,plan_checksum,snapshot_contract_version,source_counts)
values('bb540000-0000-4000-8000-000000000001','OPS_V1','school54-synthetic-prior',repeat('a',64),'2026-11-05','COMPLETED','2026-11-05',extensions.uuid_generate_v5('6ab4d3f5-0b6c-5fcb-b589-10d9f3db63c7','atlas-staging-master-import-actor'),'postgres',repeat('b',64),'OPS-V1-MASTER-SNAPSHOT.v1','{}');
do $$declare a jsonb;r jsonb;target uuid;begin
 if not exists(select 1 from atlas_legacy.master_data_mappings where source_system='OPS_V1' and object_type='SCHOOL_TYPE' and legacy_id='1') then
 r:=pg_temp.fixture()#>'{records,school_types,0}';target:=atlas_legacy.master_import_target_id(pg_temp.fixture(),'SCHOOL_TYPE','1');
 a:=jsonb_build_object('object_type','SCHOOL_TYPE','legacy_id','1','target_id',target,'action','CREATE','values',atlas_legacy.master_import_values(pg_temp.fixture(),'SCHOOL_TYPE',r,target),'source_fingerprint',atlas_legacy.master_snapshot_hash(r));perform atlas_legacy.master_import_write_core(a);perform atlas_legacy.master_import_record_mapping(a,'bb540000-0000-4000-8000-000000000001');end if;
end $$;
create temp table before_counts as select (select count(*) from atlas_admin.schools) schools,(select count(*) from atlas_admin.customers) customers,(select count(*) from atlas_admin.delivery_locations) locations,(select count(*) from atlas_legacy.master_data_mappings) mappings,(select count(*) from atlas_legacy.import_batches) receipts;
create temp table evidence(label text primary key,value jsonb);
insert into evidence values('protected',pg_temp.school54_protected(pg_temp.school54_source(pg_temp.fixture()))),('preview',pg_temp.run(pg_temp.fixture()));
select is((select value->>'status' from evidence where label='preview'),'PREVIEW','default preview succeeds');
-- Independently computed by school54ContentChecksum from this exact normalized fixture.
select is(pg_temp.content(pg_temp.fixture()),'0bfa922922e06ea09262b06f86f10196ea18128f4059f91b307903d56fefc781','closed content hash matches JavaScript canonicalization');
select isnt(pg_temp.content(pg_temp.signed(jsonb_set(pg_temp.fixture(),'{records,school_types,0,additional_normalized_fact}','"Changed type fact"'))),pg_temp.content(pg_temp.fixture()),'complete selected SchoolType row participates in source checksum');
select is(pg_temp.run(pg_temp.signed(jsonb_set(pg_temp.fixture(),'{records,schools,0,display_order}','35')),true,(select value->>'plan_checksum' from evidence where label='preview'))->>'error_code','REVIEWED_PLAN_CHANGED','changed selected School fact invalidates plan');
select is(pg_temp.run(pg_temp.signed(jsonb_set(pg_temp.fixture(),'{records,delivery_locations,0,address_text}','"Different explicit address"')),true,(select value->>'plan_checksum' from evidence where label='preview'))->>'error_code','REVIEWED_PLAN_CHANGED','changed selected Location fact invalidates plan');
select is(pg_temp.run(pg_temp.signed(jsonb_set(pg_temp.fixture(),'{records,suppliers}','[{"legacy_id":"999"},{"legacy_id":"999"}]')))->>'error_code','SOURCE_IDENTITIES_INVALID','duplicate unselected identities invalidate complete source before narrowing');
select is(pg_temp.run(jsonb_set(pg_temp.fixture(),'{source_counts,schools}','2'))->>'error_code','SNAPSHOT_CHECKSUM_MISMATCH','outer full snapshot checksum still binds unselected metadata');

savepoint readonly_preview;
set local transaction_read_only=on;
select pg_temp.run(pg_temp.fixture())->>'status' as readonly_status \gset
rollback to savepoint readonly_preview;
select is(:'readonly_status'::text,'PREVIEW'::text,'Preview executes under database READ ONLY enforcement');
select is((select value->>'create_count' from evidence where label='preview'),'3','only three CREATE roots');
select is((select count(*) from atlas_admin.schools),(select schools from before_counts),'preview has no School writes');
select is((select count(*) from atlas_legacy.import_batches),(select receipts from before_counts),'preview has no receipt writes');
select is(pg_temp.run(pg_temp.signed(pg_temp.fixture()||'{"snapshot_id":"fresh-extraction","exported_at":"2026-11-05T02:00:00Z","extractor_version":"fresh-sha"}')) ->>'plan_checksum',(select value->>'plan_checksum' from evidence where label='preview'),'technical extraction identity does not change reviewed plan');
select is(pg_temp.run(pg_temp.unselected(pg_temp.fixture()))->>'plan_checksum',(select value->>'plan_checksum' from evidence where label='preview'),'valid unselected source record does not change closed plan');
select is(pg_temp.run(pg_temp.signed(jsonb_set(pg_temp.fixture(),'{source_access,has_non_select_privilege}','true')))->>'error_code','SOURCE_NOT_PROVEN_READ_ONLY','source writable role is rejected');
select is(pg_temp.run(pg_temp.signed(jsonb_set(pg_temp.fixture(),'{records,schools,0,school_name}','"Different"')))->>'error_code','SCHOOL54_SOURCE_IDENTITY_DRIFT','identity name drift rejected');
select is(pg_temp.run(pg_temp.signed(jsonb_set(pg_temp.fixture(),'{records,delivery_locations}','[]')))->>'error_code','SCHOOL54_SOURCE_CLOSURE_REQUIRED','missing Location blocks closure');
select is(pg_temp.run(pg_temp.signed(jsonb_set(pg_temp.fixture(),'{records,delivery_locations,0,address_text}','null')))->>'error_code','SCHOOL54_SOURCE_FACTS_BLOCKED','missing address not invented');
select is(pg_temp.run(pg_temp.signed(jsonb_set(pg_temp.fixture(),'{records,school_types}','[]')))->>'error_code','EXISTING_SCHOOL_TYPE_REQUIRED','missing source SchoolType rejected');
select is(pg_temp.run_staging_school54(pg_temp.fixture(),'[]',false,null,pg_temp.content(pg_temp.fixture()))->>'error_code','EXACT_MIGRATION_HISTORY_REQUIRED','wrong migration ledger rejected');
select is(pg_temp.run(pg_temp.fixture(),true,repeat('f',64))->>'error_code','REVIEWED_PLAN_CHANGED','wrong reviewed plan rejects without writes');
select is(pg_temp.run(pg_temp.signed(jsonb_set(pg_temp.fixture(),'{records,customers,0,customer_name}','"Changed full name"')),true,(select value->>'plan_checksum' from evidence where label='preview'))->>'error_code','REVIEWED_PLAN_CHANGED','complete source facts bind external plan');
update atlas_core.actors set actor_status='INACTIVE',deactivated_at=clock_timestamp() where actor_id=extensions.uuid_generate_v5('6ab4d3f5-0b6c-5fcb-b589-10d9f3db63c7','atlas-staging-master-import-actor');
select is(pg_temp.run(pg_temp.fixture())->>'error_code','STAGING_IMPORT_ACTOR_REQUIRED','inactive technical Actor fails closed');
update atlas_core.actors set actor_status='ACTIVE',deactivated_at=null where actor_id=extensions.uuid_generate_v5('6ab4d3f5-0b6c-5fcb-b589-10d9f3db63c7','atlas-staging-master-import-actor');
insert into atlas_admin.customers(customer_id,customer_code,customer_name,customer_type) values('bb540000-0000-4000-8000-000000000099','v1-customer-54','Conflicting preexisting','SCHOOL_CATERING');
select is(pg_temp.run(pg_temp.fixture())->>'error_code','SCHOOL54_EXISTING_IDENTITY_CONFLICT','unmapped code conflict rejected');
update atlas_admin.customers set customer_code='school54-conflicting-other-code' where customer_id='bb540000-0000-4000-8000-000000000099';
select atlas_legacy.master_import_record_mapping(jsonb_build_object('object_type','CUSTOMER','legacy_id','school:54:customer','target_id','bb540000-0000-4000-8000-000000000099','action','NO_CHANGE','source_fingerprint',repeat('c',64)),'bb540000-0000-4000-8000-000000000001');
select is(pg_temp.run(pg_temp.fixture())->>'error_code','SCHOOL54_EXISTING_IDENTITY_CONFLICT','preexisting typed mapping is never silently adopted');
delete from atlas_legacy.master_data_mappings where source_system='OPS_V1' and object_type='CUSTOMER' and legacy_id='school:54:customer';
delete from atlas_admin.customers where customer_id='bb540000-0000-4000-8000-000000000099';
insert into atlas_admin.suppliers(supplier_id,supplier_code,supplier_name) values('bb540000-0000-4000-8000-000000000098','school54-unrelated','Unrelated concurrent fact');
select is(pg_temp.run(pg_temp.fixture(),true,(select value->>'plan_checksum' from evidence where label='preview'))->>'error_code','REVIEWED_PLAN_CHANGED','unrelated target change invalidates external plan');
delete from atlas_admin.suppliers where supplier_id='bb540000-0000-4000-8000-000000000098';
create function pg_temp.block_school54() returns trigger language plpgsql as $$ begin raise exception 'SYNTHETIC_SCHOOL54_WRITE_FAILURE'; end $$;
create trigger school54_atomic_test before insert on atlas_admin.schools for each row when (new.school_code='v1-school-54') execute function pg_temp.block_school54();
select is(pg_temp.run(pg_temp.fixture(),true,(select value->>'plan_checksum' from evidence where label='preview'))->>'error_code','SYNTHETIC_SCHOOL54_WRITE_FAILURE','late School failure rejects entire transaction');
select is((select count(*) from atlas_admin.customers),(select customers from before_counts),'late failure rolls back Customer');
select is((select count(*) from atlas_admin.delivery_locations),(select locations from before_counts),'late failure rolls back Location');
select is((select count(*) from atlas_legacy.master_data_mappings),(select mappings from before_counts),'late failure rolls back typed mappings');
select is((select count(*) from atlas_legacy.import_batches),(select receipts from before_counts),'late failure rolls back receipt');
drop trigger school54_atomic_test on atlas_admin.schools;
insert into evidence values('applied',pg_temp.run(pg_temp.unselected(pg_temp.fixture()),true,(select value->>'plan_checksum' from evidence where label='preview')));
select is((select value->>'status' from evidence where label='applied'),'APPLIED','exact reviewed plan applies');
select is((select reconciliation->>'source_snapshot_checksum' from atlas_legacy.import_batches where snapshot_id='atlas-staging-school54-prerequisite-v1'),pg_temp.unselected(pg_temp.fixture())->>'snapshot_checksum','receipt retains exact full applied extraction checksum');
select is((select count(*) from atlas_admin.suppliers where supplier_code='v1-supplier-999'),0::bigint,'unselected source supplier is never materialized');

select is((select count(*) from atlas_admin.schools),(select schools+1 from before_counts),'only one School added');
select is((select count(*) from atlas_admin.customers),(select customers+1 from before_counts),'only one Customer added');
select is((select count(*) from atlas_admin.delivery_locations),(select locations+1 from before_counts),'only one Location added');
select is((select count(*) from atlas_legacy.master_data_mappings),(select mappings+3 from before_counts),'exactly three typed mappings added');
select is((select count(*) from atlas_legacy.import_batches),(select receipts+1 from before_counts),'exactly one completed receipt added');
select is((select default_student_portions from atlas_admin.schools where school_code='v1-school-54'),0,'null source general student default normalizes to zero');
select is((select default_teacher_portions from atlas_admin.schools where school_code='v1-school-54'),0,'null source general teacher default normalizes to zero');
select is((select weekday_portion_defaults from atlas_admin.schools where school_code='v1-school-54'),'{}'::jsonb,'weekday values left for normal governed sync');
select is(pg_temp.school54_protected(pg_temp.school54_source(pg_temp.fixture())),(select value from evidence where label='protected'),'every preexisting Atlas row mapping and receipt unchanged');
insert into evidence values('replayed',pg_temp.run(pg_temp.fixture(),true,(select value->>'plan_checksum' from evidence where label='preview')));
select is((select value->>'status' from evidence where label='replayed'),'REPLAYED','identical known-success replay');
select is((select value-'status' from evidence where label='replayed'),(select value-'status' from evidence where label='applied'),'replay returns identical receipt');
select is((select count(*) from atlas_legacy.import_batches),(select receipts+1 from before_counts),'replay creates no receipt');
update atlas_admin.schools set default_student_portions=1 where school_code='v1-school-54';
select is(pg_temp.run(pg_temp.fixture(),true,(select value->>'plan_checksum' from evidence where label='preview'))->>'error_code','SCHOOL54_REPLAY_DRIFT','changed created facts block replay');
select * from finish();
rollback;
