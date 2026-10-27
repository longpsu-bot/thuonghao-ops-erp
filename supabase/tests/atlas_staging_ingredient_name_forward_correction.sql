begin;
select plan(18);
-- FIXTURE
\ir ../packages/atlas-staging-ingredient-name-forward-correction.sql

select ok(
 to_regprocedure('pg_temp.run_ingredient_name_forward_correction(jsonb,boolean,text,text)') is not null,
 'session-local Ingredient-name correction command exists'
);

insert into atlas_core.actors(actor_id,actor_type,display_name)
values(
 extensions.uuid_generate_v5('6ab4d3f5-0b6c-5fcb-b589-10d9f3db63c7','atlas-staging-master-import-actor'),
 'MIGRATION','Atlas Staging OPS v1 Master Import (GitHub Actions)'
);
insert into atlas_legacy.import_batches(
 import_batch_id,source_system,snapshot_id,snapshot_checksum,exported_at,import_status,completed_at,source_counts
) values(
 'a1100000-0000-4000-8000-000000000001','OPS_V1','ingredient-name-before',repeat('a',64),
 '2026-10-27','COMPLETED','2026-10-27','{"ingredients":8}'
);
insert into atlas_admin.units(unit_id,unit_code,unit_name,dimension_code)
values('a1100000-0000-4000-8000-000000000002','kg','Kilogram','MASS');
insert into atlas_admin.ingredients(
 ingredient_id,ingredient_code,ingredient_name,ingredient_type_id,
 ingredient_order_group_id,purchase_unit_id,order_step,ingredient_status
)
select
 md5('OPS_V1:INGREDIENT:'||(r.value->>'legacy_id'))::uuid,
 'v1-ingredient-'||(r.value->>'legacy_id'),r.value->>'expected_before_name',
 (select ingredient_type_id from atlas_admin.ingredient_types order by display_order limit 1),
 (select ingredient_order_group_id from atlas_admin.ingredient_order_groups order by display_order limit 1),
 (select unit_id from atlas_admin.units where unit_code='kg'),1,'ACTIVE'
from fixture f cross join lateral jsonb_array_elements(f.value->'records') r;
insert into atlas_legacy.master_data_mappings(
 import_batch_id,source_system,object_type,legacy_id,ingredient_type_id,
 ingredient_order_group_id,unit_id,last_seen_import_batch_id,last_source_fingerprint
)
select 'a1100000-0000-4000-8000-000000000001','OPS_V1',kind,legacy_id,
 case when kind='INGREDIENT_TYPE' then target_id end,
 case when kind='INGREDIENT_ORDER_GROUP' then target_id end,
 case when kind='UNIT' then target_id end,
 'a1100000-0000-4000-8000-000000000001',repeat('b',64)
from (
 select 'INGREDIENT_TYPE' kind,'1' legacy_id,(select ingredient_type_id from atlas_admin.ingredient_types order by display_order limit 1) target_id
 union all
 select 'INGREDIENT_ORDER_GROUP','1',(select ingredient_order_group_id from atlas_admin.ingredient_order_groups order by display_order limit 1)
 union all
 select 'UNIT','kg','a1100000-0000-4000-8000-000000000002'::uuid
) dependencies;
insert into atlas_legacy.master_data_mappings(
 import_batch_id,source_system,object_type,legacy_id,ingredient_id,
 last_seen_import_batch_id,last_source_fingerprint,last_target_version
)
select
 'a1100000-0000-4000-8000-000000000001','OPS_V1','INGREDIENT',r.value->>'legacy_id',
 md5('OPS_V1:INGREDIENT:'||(r.value->>'legacy_id'))::uuid,
 'a1100000-0000-4000-8000-000000000001',repeat('a',64),1
from fixture f cross join lateral jsonb_array_elements(f.value->'records') r;

create temp table evidence(label text primary key,value jsonb);
create temp table protected_before as
 select pg_temp.ingredient_name_correction_protected_fingerprints() value;
insert into evidence
select 'preview',pg_temp.run_ingredient_name_forward_correction(
 value,false,null,'ops-v1-ingredient-name-forward-correction-20261027-v1'
) from fixture;
select is((select value->>'status' from evidence where label='preview'),'PREVIEW','reviewed eight-row scope previews');
select is((select value->>'update_count' from evidence where label='preview'),'8','preview contains exactly eight name updates');
select is((select count(*) from atlas_legacy.import_batches),1::bigint,'preview writes no receipt');
select is(pg_temp.ingredient_name_correction_protected_fingerprints(),(select value from protected_before),'preview changes no fact');

select is(
 pg_temp.run_ingredient_name_forward_correction(
  (select value from fixture),true,repeat('f',64),'ops-v1-ingredient-name-forward-correction-20261027-v1'
 )->>'error_code',
 'INGREDIENT_NAME_FORWARD_CORRECTION_REQUIRED_REVIEW','wrong plan checksum fails closed'
);
update atlas_admin.ingredients set order_step=2 where ingredient_code='v1-ingredient-931';
select is(
 pg_temp.run_ingredient_name_forward_correction(
  (select value from fixture),false,null,'ops-v1-ingredient-name-forward-correction-20261027-v1'
 )->>'error_code',
 'INGREDIENT_NAME_FORWARD_CORRECTION_REQUIRED_REVIEW','non-name Ingredient drift blocks preview'
);
update atlas_admin.ingredients set order_step=1 where ingredient_code='v1-ingredient-931';
select is(
 pg_temp.run_ingredient_name_forward_correction(
  jsonb_set((select value from fixture),'{records,0,expected_after_name}','"Unreviewed"'),
  false,null,'ops-v1-ingredient-name-forward-correction-20261027-v1'
 )->>'error_code',
 'INGREDIENT_NAME_FORWARD_CORRECTION_REQUIRED_REVIEW','source payload drift fails closed'
);

insert into evidence
select 'apply',pg_temp.run_ingredient_name_forward_correction(
 f.value,true,e.value->>'plan_checksum','ops-v1-ingredient-name-forward-correction-20261027-v1'
) from fixture f cross join evidence e where e.label='preview';
select is((select value->>'status' from evidence where label='apply'),'APPLIED','reviewed plan applies atomically');
select is((select value->>'updated_count' from evidence where label='apply'),'8','all eight names update');
select is(
 (select count(*) from atlas_admin.ingredients i join lateral jsonb_array_elements((select value->'records' from fixture)) r on r.value->>'legacy_id'=replace(i.ingredient_code,'v1-ingredient-','') where i.ingredient_name=r.value->>'expected_after_name' and i.version=2),
 8::bigint,'corrected names read back with one version advance'
);
select is(
 (select count(*) from atlas_legacy.master_data_mappings m join lateral jsonb_array_elements((select value->'records' from fixture)) r on r.value->>'legacy_id'=m.legacy_id where m.last_source_fingerprint=r.value->>'source_fingerprint' and m.last_target_version=2),
 8::bigint,'typed mappings retain current source fingerprints and versions'
);
select is((select count(*) from atlas_legacy.import_batches),2::bigint,'one correction receipt is retained');
select is(pg_temp.ingredient_name_correction_protected_fingerprints(),(select value from protected_before),'operational and unrelated facts remain unchanged');

create temp table applied_rows as select jsonb_agg(to_jsonb(i) order by ingredient_id) value from atlas_admin.ingredients i;
create temp table applied_mappings as select jsonb_agg(to_jsonb(m) order by legacy_id) value from atlas_legacy.master_data_mappings m;
insert into evidence
select 'replay',pg_temp.run_ingredient_name_forward_correction(
 f.value,true,e.value->>'plan_checksum','ops-v1-ingredient-name-forward-correction-20261027-v1'
) from fixture f cross join evidence e where e.label='preview';
select is((select value->>'status' from evidence where label='replay'),'REPLAYED','same reviewed plan replays without writes');
select is((select jsonb_agg(to_jsonb(i) order by ingredient_id) from atlas_admin.ingredients i),(select value from applied_rows),'replay advances no Ingredient version');
select is((select jsonb_agg(to_jsonb(m) order by legacy_id) from atlas_legacy.master_data_mappings m),(select value from applied_mappings),'replay rewrites no mapping');

update atlas_admin.units set unit_name='Unexpected' where unit_code='kg';
select is(
 pg_temp.run_ingredient_name_forward_correction(
  (select value from fixture),false,null,'ops-v1-ingredient-name-forward-correction-20261027-v1'
 )->>'error_code',
 'INGREDIENT_NAME_FORWARD_CORRECTION_REQUIRED_REVIEW','replay refuses unrelated master-data drift'
);
update atlas_admin.units set unit_name='Kilogram' where unit_code='kg';

select * from finish();
rollback;
