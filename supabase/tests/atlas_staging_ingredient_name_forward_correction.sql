begin;
select no_plan();
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
 ingredient_order_group_id,purchase_unit_id,order_step,ingredient_status,version
)
select
 md5('OPS_V1:INGREDIENT:'||(r.value->>'legacy_id'))::uuid,
 'v1-ingredient-'||(r.value->>'legacy_id'),r.value->>'expected_before_name',
 case when r.value->>'legacy_id'='1047' then (select ingredient_type_id from atlas_admin.ingredient_types where ingredient_type_code='heo') else (select ingredient_type_id from atlas_admin.ingredient_types order by display_order limit 1) end,
 (select ingredient_order_group_id from atlas_admin.ingredient_order_groups order by display_order limit 1),
 (select unit_id from atlas_admin.units where unit_code='kg'),1,'ACTIVE',2
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
 select 'INGREDIENT_TYPE','36',(select ingredient_type_id from atlas_admin.ingredient_types where ingredient_type_code='heo')
 union all
 select 'INGREDIENT_TYPE','43',(select ingredient_type_id from atlas_admin.ingredient_types where ingredient_type_code='thuy_hai_san')
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
 'a1100000-0000-4000-8000-000000000001',repeat('a',64),2
from fixture f cross join lateral jsonb_array_elements(f.value->'records') r;

create temp table evidence(label text primary key,value jsonb);
create temp table protected_before as
 select pg_temp.ingredient_name_correction_protected_fingerprints() value;
create temp table receipt_count_before as select count(*) value from atlas_legacy.import_batches;
insert into evidence
select 'preview',pg_temp.run_ingredient_name_forward_correction(
 value,false,null,'ops-v1-ingredient-factual-correction-20261105-v1'
) from fixture;
select is((select value->>'status' from evidence where label='preview'),'PREVIEW','reviewed eight-row scope previews');
select is((select value->>'update_count' from evidence where label='preview'),'8','preview contains exactly eight name updates');
select is((select r.value->>'proposed_type_legacy_id' from evidence e cross join lateral jsonb_array_elements(e.value->'report') r where e.label='preview' and r.value->>'legacy_id'='1047'),'43','preview explicitly reports seafood classification');
select is((select count(*) from atlas_legacy.import_batches),(select value from receipt_count_before),'preview writes no receipt');
select is(pg_temp.ingredient_name_correction_protected_fingerprints(),(select value from protected_before),'preview changes no fact');

select is(
 pg_temp.run_ingredient_name_forward_correction(
  (select value from fixture),true,repeat('f',64),'ops-v1-ingredient-factual-correction-20261105-v1'
 )->>'error_code',
 'INGREDIENT_NAME_FORWARD_CORRECTION_REQUIRED_REVIEW','wrong plan checksum fails closed'
);
update atlas_admin.ingredients set order_step=2 where ingredient_code='v1-ingredient-931';
select is(
 pg_temp.run_ingredient_name_forward_correction(
  (select value from fixture),false,null,'ops-v1-ingredient-factual-correction-20261105-v1'
 )->>'error_code',
 'INGREDIENT_NAME_FORWARD_CORRECTION_REQUIRED_REVIEW','non-name Ingredient drift blocks preview'
);
update atlas_admin.ingredients set order_step=1 where ingredient_code='v1-ingredient-931';
select is(
 pg_temp.run_ingredient_name_forward_correction(
  jsonb_set((select value from fixture),'{records,0,expected_after_name}','"Unreviewed"'),
  false,null,'ops-v1-ingredient-factual-correction-20261105-v1'
 )->>'error_code',
 'INGREDIENT_NAME_FORWARD_CORRECTION_REQUIRED_REVIEW','source payload drift fails closed'
);

create temp table replaced_migration as
 select min(version) original_version from supabase_migrations.schema_migrations;
update supabase_migrations.schema_migrations set version='00000000000000'
where version=(select original_version from replaced_migration);
select is(
 pg_temp.run_ingredient_name_forward_correction(
  (select value from fixture),false,null,'ops-v1-ingredient-factual-correction-20261105-v1'
 )->>'error_code',
 'INGREDIENT_NAME_FORWARD_CORRECTION_REQUIRED_REVIEW','same-count and same-tip migration substitution fails closed'
);
update supabase_migrations.schema_migrations set version=(select original_version from replaced_migration)
where version='00000000000000';

update atlas_legacy.master_data_mappings set last_seen_import_batch_id=null
where source_system='OPS_V1' and object_type='INGREDIENT';
select is(
 pg_temp.run_ingredient_name_forward_correction(
  f.value,true,e.value->>'plan_checksum','ops-v1-ingredient-factual-correction-20261105-v1'
 )->>'error_code',
 'INGREDIENT_NAME_FORWARD_CORRECTION_REQUIRED_REVIEW','reviewed plan rejects last-seen batch drift'
) from fixture f cross join evidence e where e.label='preview';
update atlas_legacy.master_data_mappings set last_seen_import_batch_id='a1100000-0000-4000-8000-000000000001'
where source_system='OPS_V1' and object_type='INGREDIENT';

update atlas_legacy.master_data_mappings set last_source_fingerprint=repeat('c',64)
where source_system='OPS_V1' and object_type='INGREDIENT';
select is(
 pg_temp.run_ingredient_name_forward_correction(
  f.value,true,e.value->>'plan_checksum','ops-v1-ingredient-factual-correction-20261105-v1'
 )->>'error_code',
 'INGREDIENT_NAME_FORWARD_CORRECTION_REQUIRED_REVIEW','reviewed plan rejects source-fingerprint drift'
) from fixture f cross join evidence e where e.label='preview';
update atlas_legacy.master_data_mappings set last_source_fingerprint=repeat('a',64)
where source_system='OPS_V1' and object_type='INGREDIENT';

update atlas_legacy.master_data_mappings set last_target_version=3
where source_system='OPS_V1' and object_type='INGREDIENT';
select is(
 pg_temp.run_ingredient_name_forward_correction(
  f.value,true,e.value->>'plan_checksum','ops-v1-ingredient-factual-correction-20261105-v1'
 )->>'error_code',
 'INGREDIENT_NAME_FORWARD_CORRECTION_REQUIRED_REVIEW','reviewed plan rejects target-version drift'
) from fixture f cross join evidence e where e.label='preview';
update atlas_legacy.master_data_mappings set last_target_version=2
where source_system='OPS_V1' and object_type='INGREDIENT';

create function pg_temp.preview_factual(p jsonb) returns jsonb language sql as $$ select pg_temp.run_ingredient_name_forward_correction(p,false,null,'ops-v1-ingredient-factual-correction-20261105-v1') $$;
create function pg_temp.forge_shrimp_source(p jsonb) returns jsonb language plpgsql as $$ declare rows jsonb; r jsonb; result jsonb:='[]'; begin for r in select value from jsonb_array_elements(p->'records') loop if r->>'legacy_id'='1047' then r:=jsonb_set(r,'{source_record,ingredient_type_legacy_id}','"36"');r:=r||jsonb_build_object('source_fingerprint',atlas_legacy.master_snapshot_hash(r->'source_record'));end if;result:=result||jsonb_build_array(r);end loop;return jsonb_set(p,'{records}',result);end $$;
select is(pg_temp.preview_factual(pg_temp.forge_shrimp_source((select value from fixture)))->>'status','REJECTED','forged source36 rejected even with a self-consistent row fingerprint');

select is(pg_temp.preview_factual(jsonb_set((select value from fixture),'{type_correction,source_catalog_access,has_select}','false'))->>'status','REJECTED','catalog read-only proof required');
select is(pg_temp.preview_factual(jsonb_set((select value from fixture),'{type_correction,source_types,1,ingredient_type_name}','"Heo"'))->>'status','REJECTED','actual source seafood catalog name required');
update atlas_admin.ingredient_types set ingredient_type_status='INACTIVE' where ingredient_type_code='thuy_hai_san';
select is(pg_temp.preview_factual((select value from fixture))->>'status','REJECTED','inactive seafood catalogue blocks correction');
update atlas_admin.ingredient_types set ingredient_type_status='ACTIVE' where ingredient_type_code='thuy_hai_san';
update atlas_legacy.master_data_mappings set ingredient_type_id=(select ingredient_type_id from atlas_admin.ingredient_types where ingredient_type_code='heo') where source_system='OPS_V1' and object_type='INGREDIENT_TYPE' and legacy_id='43';
select is(pg_temp.preview_factual((select value from fixture))->>'status','REJECTED','wrong seafood typed mapping blocks correction');
update atlas_legacy.master_data_mappings set ingredient_type_id=(select ingredient_type_id from atlas_admin.ingredient_types where ingredient_type_code='thuy_hai_san') where source_system='OPS_V1' and object_type='INGREDIENT_TYPE' and legacy_id='43';
update atlas_admin.ingredients set ingredient_type_id=(select ingredient_type_id from atlas_admin.ingredient_types where ingredient_type_code='thuy_hai_san') where ingredient_code='v1-ingredient-1047';
select is(pg_temp.preview_factual((select value from fixture))->>'status','REJECTED','unexpected shrimp before type fails closed');
update atlas_admin.ingredients set ingredient_type_id=(select ingredient_type_id from atlas_admin.ingredient_types where ingredient_type_code='heo') where ingredient_code='v1-ingredient-1047';
update atlas_admin.ingredients set ingredient_type_id=(select ingredient_type_id from atlas_admin.ingredient_types where ingredient_type_code='thuy_hai_san') where ingredient_code='v1-ingredient-931';
select is(pg_temp.preview_factual((select value from fixture))->>'status','REJECTED','other Ingredient type drift still blocks correction');
update atlas_admin.ingredients set ingredient_type_id=(select ingredient_type_id from atlas_admin.ingredient_types order by display_order limit 1) where ingredient_code='v1-ingredient-931';
update atlas_admin.ingredients set version=3 where ingredient_code='v1-ingredient-931';
update atlas_legacy.master_data_mappings set last_target_version=3 where object_type='INGREDIENT' and legacy_id='931';
select is(pg_temp.preview_factual((select value from fixture))->>'status','REJECTED','unexpected matching row and mapping version rejected');
update atlas_admin.ingredients set version=2 where ingredient_code='v1-ingredient-931';
update atlas_legacy.master_data_mappings set last_target_version=2 where object_type='INGREDIENT' and legacy_id='931';
insert into atlas_legacy.import_batches(import_batch_id,source_system,snapshot_id,snapshot_checksum,exported_at,import_status,completed_at,source_counts) values('a1100000-0000-4000-8000-000000000099','OPS_V1','ops-v1-ingredient-name-forward-correction-20261027-v1',repeat('a',64),'2026-11-05','COMPLETED','2026-11-05','{}');
select is(pg_temp.preview_factual((select value from fixture))->>'status','REJECTED','unexpected obsolete name-only receipt rejects');
delete from atlas_legacy.import_batches where import_batch_id='a1100000-0000-4000-8000-000000000099';
create temp table before_late_rows as select jsonb_agg(to_jsonb(i) order by ingredient_id) value from atlas_admin.ingredients i;
create temp table before_late_mappings as select jsonb_agg(to_jsonb(m) order by legacy_id) value from atlas_legacy.master_data_mappings m;
create function pg_temp.reject_late_factual() returns trigger language plpgsql as $$ begin raise exception 'SYNTHETIC_LATE_FAILURE'; end $$;
create trigger late_factual_test before update on atlas_admin.ingredients for each row when (new.ingredient_code='v1-ingredient-1154') execute function pg_temp.reject_late_factual();
select is(pg_temp.run_ingredient_name_forward_correction((select value from fixture),true,(select value->>'plan_checksum' from evidence where label='preview'),'ops-v1-ingredient-factual-correction-20261105-v1')->>'status','REJECTED','late update failure rejects atomically');
select is((select jsonb_agg(to_jsonb(i) order by ingredient_id) from atlas_admin.ingredients i),(select value from before_late_rows),'late failure rolls back names type and versions');
select is((select jsonb_agg(to_jsonb(m) order by legacy_id) from atlas_legacy.master_data_mappings m),(select value from before_late_mappings),'late failure rolls back mapping changes');
select is((select count(*) from atlas_legacy.import_batches),(select value from receipt_count_before),'late failure rolls back receipt');
drop trigger late_factual_test on atlas_admin.ingredients;
insert into evidence
select 'apply',pg_temp.run_ingredient_name_forward_correction(
 f.value,true,e.value->>'plan_checksum','ops-v1-ingredient-factual-correction-20261105-v1'
) from fixture f cross join evidence e where e.label='preview';
select is((select value->>'status' from evidence where label='apply'),'APPLIED','reviewed plan applies atomically');
select is((select value->>'updated_count' from evidence where label='apply'),'8','all eight names update');
select is((select ingredient_type_id from atlas_admin.ingredients where ingredient_code='v1-ingredient-1047'),(select ingredient_type_id from atlas_admin.ingredient_types where ingredient_type_code='thuy_hai_san'),'shrimp canonical type reads back seafood43');
select is((select count(*) from atlas_admin.ingredients i where i.ingredient_code<>'v1-ingredient-1047' and i.ingredient_type_id is distinct from (select ingredient_type_id from atlas_admin.ingredient_types order by display_order limit 1)),0::bigint,'all other canonical types preserved');
select is((select r.value#>>'{source_record,ingredient_type_legacy_id}' from fixture f cross join lateral jsonb_array_elements(f.value->'records') r where r.value->>'legacy_id'='1047'),'43','mapping fingerprint input truthfully retains source type43');

select is(
 (select count(*) from atlas_admin.ingredients i join lateral jsonb_array_elements((select value->'records' from fixture)) r on r.value->>'legacy_id'=replace(i.ingredient_code,'v1-ingredient-','') where i.ingredient_name=r.value->>'expected_after_name' and i.version=3),
 8::bigint,'corrected names read back with one version advance'
);
select is(
 (select count(*) from atlas_legacy.master_data_mappings m join lateral jsonb_array_elements((select value->'records' from fixture)) r on r.value->>'legacy_id'=m.legacy_id where m.last_seen_import_batch_id=(select import_batch_id from atlas_legacy.import_batches where snapshot_id='ops-v1-ingredient-factual-correction-20261105-v1') and m.last_source_fingerprint=r.value->>'source_fingerprint' and m.last_target_version=3),
 8::bigint,'typed mappings retain current source fingerprints and versions'
);
select is((select count(*) from atlas_legacy.import_batches),(select value+1 from receipt_count_before),'one correction receipt is retained');
select is(pg_temp.ingredient_name_correction_protected_fingerprints(),(select value from protected_before),'operational and unrelated facts remain unchanged');

create temp table applied_rows as select jsonb_agg(to_jsonb(i) order by ingredient_id) value from atlas_admin.ingredients i;
create temp table applied_mappings as select jsonb_agg(to_jsonb(m) order by legacy_id) value from atlas_legacy.master_data_mappings m;
insert into evidence
select 'replay',pg_temp.run_ingredient_name_forward_correction(
 f.value,true,e.value->>'plan_checksum','ops-v1-ingredient-factual-correction-20261105-v1'
) from fixture f cross join evidence e where e.label='preview';
select is((select value->>'status' from evidence where label='replay'),'REPLAYED','same reviewed plan replays without writes');
select is((select jsonb_agg(to_jsonb(i) order by ingredient_id) from atlas_admin.ingredients i),(select value from applied_rows),'replay advances no Ingredient version');
select is((select jsonb_agg(to_jsonb(m) order by legacy_id) from atlas_legacy.master_data_mappings m),(select value from applied_mappings),'replay rewrites no mapping');

update atlas_admin.units set unit_name='Unexpected' where unit_code='kg';
select is(
 pg_temp.run_ingredient_name_forward_correction(
  (select value from fixture),false,null,'ops-v1-ingredient-factual-correction-20261105-v1'
 )->>'error_code',
 'INGREDIENT_NAME_FORWARD_CORRECTION_REQUIRED_REVIEW','replay refuses unrelated master-data drift'
);
update atlas_admin.units set unit_name='Kilogram' where unit_code='kg';

select * from finish();
rollback;
