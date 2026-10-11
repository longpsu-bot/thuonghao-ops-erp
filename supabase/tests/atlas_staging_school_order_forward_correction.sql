begin;
select no_plan();
-- FIXTURE
\ir ../packages/atlas-staging-school-order-forward-correction.sql
select ok(to_regprocedure('pg_temp.run_school_order_forward_correction(boolean,text)') is not null,
 'protected session-local correction command exists');
-- Local transaction mirrors hosted migration gate, never changes hosted history.
delete from supabase_migrations.schema_migrations where version>'20261010034834';
insert into atlas_core.actors(actor_id,actor_type,display_name)
values(extensions.uuid_generate_v5('6ab4d3f5-0b6c-5fcb-b589-10d9f3db63c7','atlas-staging-master-import-actor'),'MIGRATION','Atlas Staging OPS v1 Master Import (GitHub Actions)');
insert into atlas_legacy.import_batches(import_batch_id,source_system,snapshot_id,snapshot_checksum,exported_at,import_status,completed_at,operator_actor_id,execution_database_principal,plan_checksum,snapshot_contract_version,source_counts,result_payload)
select (value#>>'{receipt,import_batch_id}')::uuid,'OPS_V1',value#>>'{receipt,snapshot_id}',value#>>'{receipt,snapshot_checksum}','2026-10-10','COMPLETED','2026-10-10',extensions.uuid_generate_v5('6ab4d3f5-0b6c-5fcb-b589-10d9f3db63c7','atlas-staging-master-import-actor'),'postgres',value#>>'{receipt,plan_checksum}',value#>>'{receipt,snapshot_contract_version}','{}',value#>'{receipt,result_payload}' from fixture;
insert into atlas_admin.customers(customer_id,customer_code,customer_name,customer_type)
select (s.value->>'customer_id')::uuid,'fixture-'||(s.value->>'customer_id'),'Fixture Customer','SCHOOL_CATERING' from fixture f cross join lateral jsonb_array_elements(f.value->'school_scope') s;
insert into atlas_admin.delivery_locations(delivery_location_id,customer_id,location_code,location_name,address_text)
select (s.value->>'school_id')::uuid,(s.value->>'customer_id')::uuid,'fixture-location','Fixture location','Fixture address' from fixture f cross join lateral jsonb_array_elements(f.value->'school_scope') s;
insert into atlas_admin.schools(school_id,customer_id,school_code,school_name,school_status,default_delivery_location_id,display_order,version)
select (s.value->>'school_id')::uuid,(s.value->>'customer_id')::uuid,s.value->>'school_code',s.value->>'school_name',scope.value->>'school_status',(s.value->>'school_id')::uuid,(s.value->>'display_order')::integer,(s.value->>'version')::bigint
from fixture f cross join lateral jsonb_array_elements(f.value->'current_schools') s join lateral jsonb_array_elements(f.value->'school_scope') scope on scope.value->'school_id'=s.value->'school_id';
insert into atlas_legacy.master_data_mappings(import_batch_id,source_system,object_type,legacy_id,school_id,last_source_fingerprint,last_target_version)
select (f.value#>>'{receipt,import_batch_id}')::uuid,'OPS_V1','SCHOOL',m.value->>'legacy_id',(m.value->>'school_id')::uuid,repeat('a',64),s.version from fixture f cross join lateral jsonb_array_elements(f.value->'current_mappings') m join atlas_admin.schools s on s.school_id=(m.value->>'school_id')::uuid;
update atlas_legacy.import_batches set reconciliation=jsonb_build_object('all_school_fingerprints',pg_temp.school_order_all_school_fingerprints());
-- The production package pins the actual immutable hosted receipt. Only this
-- rolled-back fixture overrides its expected hash; no command input can do so.
create or replace function pg_temp.school_order_original_receipt_hash() returns text language sql stable as $$ select atlas_legacy.master_snapshot_hash(to_jsonb(b)) from atlas_legacy.import_batches b where snapshot_id='ops-v1-school-reconciliation-38071834975-1' $$;
create temp table original_hash as select pg_temp.school_order_original_receipt_hash() value;
create or replace function pg_temp.school_order_original_receipt_hash() returns text language sql stable as $$ select value from pg_temp.original_hash $$;
create temp table original_map_hash as select atlas_legacy.master_snapshot_hash(jsonb_agg(to_jsonb(m) order by source_system,object_type,legacy_id)) value from atlas_legacy.master_data_mappings m;
create or replace function pg_temp.school_order_original_mapping_hash() returns text language sql stable as $$ select value from pg_temp.original_map_hash $$;
create temp table before_schools as select to_jsonb(s) value from atlas_admin.schools s;
create temp table before_platform as select pg_temp.school_order_platform_fingerprints() value;
create temp table evidence(label text primary key,value jsonb);
insert into evidence values('preview',pg_temp.run_school_order_forward_correction(false,null));
select is((select value->>'status' from evidence where label='preview'),'PREVIEW','actual dense fifty-row fixture previews');
select is((select jsonb_array_length(value->'report') from evidence where label='preview'),50,'complete report includes every School');
select is((select jsonb_agg(o.value order by o.value->>'school_id') from evidence e cross join lateral jsonb_array_elements(e.value->'target_school_display_orders') o where label='preview'),(select jsonb_agg(o.value order by o.value->>'school_id') from fixture f cross join lateral jsonb_array_elements(f.value->'expected_corrected_orders') o),'independently reviewed complete fifty-row orders match');
select is((select count(*) from evidence e cross join lateral jsonb_array_elements(e.value->'report') r where label='preview' and r.value->'pre_reconciliation_order'=r.value->'corrected_order'),39::bigint,'thirty-nine old numeric orders retained exactly');
select is((select count(*) from evidence e cross join lateral jsonb_array_elements(e.value->'report') r where label='preview' and r.value->'pre_reconciliation_order'<>'null'::jsonb and r.value->'pre_reconciliation_order'<>r.value->'corrected_order'),5::bigint,'only five old Schools move relative to immutable baseline');
select is((select count(*) from evidence e cross join lateral jsonb_array_elements(e.value->'report') r where label='preview' and (r.value->>'changed_by_forward_correction')::boolean),49::bigint,'forty-nine current dense rows require a forward write');
select is((select count(*) from evidence e cross join lateral jsonb_array_elements(e.value->'report') r where label='preview' and r.value->>'corrected_order'='0'),3::bigint,'three valid zero ties retained');
select is((select count(*) from evidence e cross join lateral jsonb_array_elements(e.value->'report') r where label='preview' and r.value->>'corrected_order'='1'),2::bigint,'valid one tie retained');
select is((select array_agg((r.value->>'corrected_order')::integer order by r.ordinality) from evidence e cross join lateral jsonb_array_elements(e.value->'report') with ordinality r where label='preview' and r.value->>'block'='BINH_QUOI'),array[14,14],'Bình Quới tie is valid under PostgreSQL secondary comparator');
select is((select array_agg((r.value->>'corrected_order')::integer order by r.ordinality) from evidence e cross join lateral jsonb_array_elements(e.value->'report') with ordinality r where label='preview' and r.value->>'block'='HUNG_VUONG'),array[18,19,20,21,22],'Hùng Vương block starts at smallest feasible tie and increments consecutively');
select is((select count(*) from evidence e cross join lateral jsonb_array_elements(e.value->'report') r where label='preview' and (r.value->>'pre_reconciliation_order')::integer<14 and r.value->'pre_reconciliation_order'<>r.value->'corrected_order'),0::bigint,'prefix before earliest block retains all old numbers');
select is((select count(*) from atlas_legacy.import_batches),1::bigint,'preview adds no technical receipt');
select is(pg_temp.school_order_platform_fingerprints(),(select value from before_platform),'preview changes no protected fact');
select ok(pg_temp.school_order_platform_fingerprints() ? 'atlas_audit.audit_events','protected platform includes private audit facts');
select is(pg_temp.run_school_order_forward_correction(true,repeat('f',64))->>'error_code','SCHOOL_ORDER_FORWARD_CORRECTION_REQUIRED_REVIEW','wrong plan checksum fails closed');
savepoint drift;
update atlas_admin.schools set operational_notes='unexpected fact' where school_code='v1-school-10';
select is(pg_temp.run_school_order_forward_correction(true,(select value->>'plan_checksum' from evidence where label='preview'))->>'error_code','SCHOOL_ORDER_FORWARD_CORRECTION_REQUIRED_REVIEW','non-order School drift blocks apply');
rollback to drift;
savepoint drift;
update atlas_legacy.master_data_mappings set last_source_fingerprint=repeat('b',64) where legacy_id='10';
select is(pg_temp.run_school_order_forward_correction(false,null)->>'error_code','SCHOOL_ORDER_FORWARD_CORRECTION_REQUIRED_REVIEW','mapping metadata drift blocks preview');
rollback to drift;
savepoint drift;
update atlas_legacy.import_batches set source_counts='{"unexpected":1}';
select is(pg_temp.run_school_order_forward_correction(false,null)->>'error_code','SCHOOL_ORDER_FORWARD_CORRECTION_REQUIRED_REVIEW','complete original receipt drift blocks preview');
rollback to drift;
savepoint drift;
update atlas_admin.schools set display_order=display_order+100 where school_code='v1-school-10';
select is(pg_temp.run_school_order_forward_correction(false,null)->>'error_code','SCHOOL_ORDER_FORWARD_CORRECTION_REQUIRED_REVIEW','current dense order drift blocks preview');
rollback to drift;
savepoint drift;
insert into supabase_migrations.schema_migrations(version) values('99999999999999');
select is(pg_temp.run_school_order_forward_correction(false,null)->>'error_code','SCHOOL_ORDER_FORWARD_CORRECTION_REQUIRED_REVIEW','migration tip drift blocks preview');
rollback to drift;
insert into evidence values('apply',pg_temp.run_school_order_forward_correction(true,(select value->>'plan_checksum' from evidence where label='preview')));
select is((select value->>'status' from evidence where label='apply'),'APPLIED','reviewed plan applies atomically');
select is((select array_agg(school_id order by display_order,school_name,school_id) from atlas_admin.schools),(select array_agg(id::uuid order by ordinality) from evidence e cross join lateral jsonb_array_elements_text(e.value->'target_school_order_ids') with ordinality r(id,ordinality) where label='preview'),'entire corrected PostgreSQL sort equals approved sequence');
select is(pg_temp.school_order_platform_fingerprints(),(select value from before_platform),'all private facts, mappings, created_at and historical receipts unchanged');
select is((select count(*) from atlas_admin.schools s join before_schools b on s.school_id=(b.value->>'school_id')::uuid where s.version=(b.value->>'version')::bigint+1),49::bigint,'safe temporary order phase increments versions only once');
select is((select count(*) from atlas_legacy.import_batches),2::bigint,'one separate correction receipt inserted');
create temp table after_schools as select jsonb_agg(to_jsonb(s) order by school_id) value from atlas_admin.schools s;
create temp table after_receipts as select jsonb_agg(to_jsonb(b) order by snapshot_id) value from atlas_legacy.import_batches b;
insert into evidence values('replay',pg_temp.run_school_order_forward_correction(true,(select value->>'plan_checksum' from evidence where label='preview')));
select is((select value->>'status' from evidence where label='replay'),'REPLAYED','same approved checksum safely replays');
select is((select jsonb_agg(to_jsonb(s) order by school_id) from atlas_admin.schools s),(select value from after_schools),'replay rewrites no School and advances no version');
select is((select jsonb_agg(to_jsonb(b) order by snapshot_id) from atlas_legacy.import_batches b),(select value from after_receipts),'replay rewrites no receipt');
select is(pg_temp.run_school_order_forward_correction(false,null)->>'correction_already_applied','true','preview verifies correction already applied');
savepoint drift;
update atlas_admin.schools set default_student_portions=151 where school_code='v1-school-10';
select is(pg_temp.run_school_order_forward_correction(true,(select value->>'plan_checksum' from evidence where label='preview'))->>'error_code','SCHOOL_ORDER_FORWARD_CORRECTION_REQUIRED_REVIEW','replay refuses corrected School fact drift');
rollback to drift;
savepoint drift;
update atlas_admin.customers set customer_name='unexpected' where customer_code like 'fixture-%';
select is(pg_temp.run_school_order_forward_correction(false,null)->>'error_code','SCHOOL_ORDER_FORWARD_CORRECTION_REQUIRED_REVIEW','replay refuses other private fact drift');
rollback to drift;
-- Same ACTIVE Customer within a valid secondary tie must advance minimally.
create temp table scoped_positions as
select pg_temp.school_order_corrected_positions(f.value#>'{receipt,result_payload}',
 (select jsonb_agg(to_jsonb(s)||jsonb_build_object('customer_id',case when s.school_code in ('atlas_staging_school','v1-school-24') then 'a1020000-0000-4000-8000-000000000201' else s.customer_id::text end)) from atlas_admin.schools s),f.value->'current_mappings') value from fixture f;
select is((select (r.value->>'corrected_order')::integer from scoped_positions p cross join lateral jsonb_array_elements(p.value) r where r.value->>'school_code'='v1-school-24'),2,'ACTIVE Customer collision raises tied row by minimum one');
select is((select (r.value->>'corrected_order')::integer from scoped_positions p cross join lateral jsonb_array_elements(p.value) r where r.value->>'school_code'='v1-school-39'),2,'next unrelated different Customer keeps feasible tie');
select throws_ok($test$
 select pg_temp.school_order_corrected_positions(jsonb_set(jsonb_set(f.value#>'{receipt,result_payload}','{target_school_order_ids,0}',f.value#>'{receipt,result_payload,target_school_order_ids,1}'),'{target_school_order_ids,1}',f.value#>'{receipt,result_payload,target_school_order_ids,0}'),(select jsonb_agg(value) from before_schools),f.value->'current_mappings') from fixture f
$test$,'P0001','SCHOOL_ORDER_FORWARD_CORRECTION_REQUIRED_REVIEW','swapping unrelated target Schools is forbidden');
create temp table dense_input as
select jsonb_agg(s.value||jsonb_build_object('display_order',ids.ordinality-1,'school_name',lpad((100-ids.ordinality)::text,3,'0')) order by ids.ordinality) schools,
jsonb_agg(s.value||jsonb_build_object('display_order',ids.ordinality-1,'school_name',lpad((100-ids.ordinality)::text,3,'0')) order by ids.ordinality) filter(where f.value#>'{receipt,result_payload,current_schools}' @> jsonb_build_array(jsonb_build_object('school_id',s.value->'school_id'))) baseline
from fixture f cross join lateral jsonb_array_elements(f.value#>'{receipt,result_payload,target_school_order_ids}') with ordinality ids join before_schools s on s.value->'school_id'=ids.value;
select throws_ok($test$
 select pg_temp.school_order_corrected_positions(jsonb_set(f.value#>'{receipt,result_payload}','{current_schools}',d.baseline),d.schools,f.value->'current_mappings') from fixture f cross join dense_input d
$test$,'P0001','SCHOOL_ORDER_FORWARD_CORRECTION_REQUIRED_REVIEW','global dense zero-to-N allocation is expressly forbidden');
select is((select array_agg(s.school_id order by s.display_order,s.school_name,s.school_id) from atlas_admin.schools s where not s.school_code in ('v1-school-52','v1-school-10','v1-school-47','v1-school-48','v1-school-49','v1-school-50','v1-school-53')),
 (select array_agg((r.value->>'school_id')::uuid order by (r.value->>'display_order')::integer,r.value->>'school_name',(r.value->>'school_id')::uuid) from fixture f cross join lateral jsonb_array_elements(f.value#>'{receipt,result_payload,current_schools}') r where not r.value->>'school_code' in ('v1-school-10')),'all unrelated relative order remains identical to pre-reconciliation receipt');
select is((select (r.value->>'corrected_order')::integer from evidence e cross join lateral jsonb_array_elements(e.value->'report') r where label='preview' and r.value->>'school_code'='v1-school-16'),23,'minimum Hùng Vương start retains Nguyễn Văn Sách old twenty-three');
-- A separate synthetic scope variant exercises the actual immediate unique
-- index while current order 1 must be vacated before another row takes it.
savepoint scoped_write;
delete from atlas_legacy.import_batches where snapshot_id='ops-v1-school-order-forward-correction-38071834975-1-v1';
update atlas_admin.schools s set display_order=(b.value->>'display_order')::integer,version=(b.value->>'version')::bigint,updated_at=(b.value->>'updated_at')::timestamptz from before_schools b where s.school_id=(b.value->>'school_id')::uuid;
update atlas_admin.schools s set customer_id=t.customer_id,default_delivery_location_id=t.default_delivery_location_id from atlas_admin.schools t where s.school_code='v1-school-5' and t.school_code='v1-school-24';
update atlas_legacy.import_batches set reconciliation=jsonb_build_object('all_school_fingerprints',pg_temp.school_order_all_school_fingerprints());
update original_hash set value=(select atlas_legacy.master_snapshot_hash(to_jsonb(b)) from atlas_legacy.import_batches b where snapshot_id='ops-v1-school-reconciliation-38071834975-1');
insert into evidence values('scoped-preview',pg_temp.run_school_order_forward_correction(false,null));
select is((select value->>'status' from evidence where label='scoped-preview'),'PREVIEW','same Customer variant has valid final scoped orders');
select is(pg_temp.run_school_order_forward_correction(true,(select value->>'plan_checksum' from evidence where label='scoped-preview'))->>'status','APPLIED','two safe order phases satisfy immediate ACTIVE Customer index');
select ok(not exists(select 1 from atlas_admin.schools where school_status='ACTIVE' group by customer_id,display_order having count(*)>1),'real scoped Customer uniqueness holds after transactional apply');
release savepoint scoped_write;
select * from finish();
rollback;
