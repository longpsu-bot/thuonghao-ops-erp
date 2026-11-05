begin;
create extension if not exists pgtap with schema extensions;
set search_path=public,extensions;
select no_plan();
\ir ../packages/atlas-staging-recipe-history.sql

insert into atlas_core.actors(actor_id,actor_type,display_name)
values('a217bdd5-2858-58c2-8964-45c465225a59','MIGRATION','Disposable archive import test') on conflict do nothing;
create temp table history_fixture(snapshot jsonb,migrations jsonb);
insert into history_fixture
select jsonb_build_object('contract_version','OPS-V1-RECIPE-HISTORY.v1','source_system','OPS_V1_RECIPE_HISTORY','source_project_ref','qnthofvccilhnefdcxnz','snapshot_id','staging-history-pgtap','exported_at','2099-11-05T00:00:00Z','extractor_version','test',
  'source_access',jsonb_build_object('superuser',false,'bypassRls',true,'createRole',false,'createDb',false,'hasRequiredSelect',true,'hasNonSelectTablePrivilege',false),
  'source_counts',jsonb_build_object('ingredient_change_orders',0,'system_bom_change_orders',1,'school_wide_overrides',0,'school_recipe_overrides',0),
  'records',jsonb_build_array(jsonb_build_object('source_table','system_bom_change_orders','legacy_id','9012345678901234','scope_kind','SYSTEM_DISH','action','ADJUST_QUANTITY','source_active',false,'effective_from','2026-01-19','quantity','1.000001','source_created_at',null,'source_school_type_id','1','dish_name','Fixture Dish','school_name',null,'ingredient_name','Fixture Salt','substitute_name',null,'unit_name','kg','note','Source inactive; cancellation unknown','source_record',jsonb_build_object('id','9012345678901234')))),
  (select jsonb_agg(version order by version) from supabase_migrations.schema_migrations);
update history_fixture set snapshot=snapshot||jsonb_build_object('snapshot_checksum',atlas_legacy.master_snapshot_hash(snapshot));

select throws_ok($$select pg_temp.run_recipe_history_archive(snapshot,'[]',false) from history_fixture$$,'P0001','MIGRATION_HISTORY_MISMATCH','Incomplete migration history rejects preview');
select is((select pg_temp.run_recipe_history_archive(snapshot,migrations,false)->>'status' from history_fixture),'PREVIEW','Guarded preview succeeds');
select is((select count(*) from atlas_legacy.import_batches where snapshot_id='staging-history-pgtap'),0::bigint,'Preview makes no receipt writes');
select is((select pg_temp.run_recipe_history_archive(snapshot,migrations,true)->>'status' from history_fixture),'IMPORTED','Archive apply succeeds');
select is((select pg_temp.run_recipe_history_archive(snapshot,migrations,true)->>'status' from history_fixture),'REPLAYED','Same snapshot replays');
select is((select pg_temp.run_recipe_history_archive(snapshot,migrations,true)->>'matched_records' from history_fixture),'1','Exact source readback reconciles');
select is((select count(*) from atlas_legacy.import_batches where snapshot_id='staging-history-pgtap'),1::bigint,'Only one receipt is retained');
select is((select pg_temp.run_recipe_history_archive(snapshot,migrations,true)->>'preserved' from history_fixture),'true','All other Atlas tables and receipts remain unchanged');
select is(jsonb_path_query_first(atlas_legacy.recipe_change_order_history(),'$[*] ? (@.legacy_id == "9012345678901234")')->>'source_active','false','Inactive source evidence retained');
select ok(not(jsonb_path_query_first(atlas_legacy.recipe_change_order_history(),'$[*] ? (@.legacy_id == "9012345678901234")')?'cancelled_at'),'No cancellation date invented');

select * from finish();
rollback;
