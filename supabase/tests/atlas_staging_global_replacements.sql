begin;
create extension if not exists pgtap with schema extensions;
set search_path=public,extensions;
select no_plan();
\ir ../packages/atlas-staging-global-replacements.sql

insert into atlas_core.actors(actor_id,actor_type,display_name) values('a217bdd5-2858-58c2-8964-45c465225a59','MIGRATION','Global adoption test') on conflict do nothing;
insert into atlas_admin.units(unit_id,unit_code,unit_name,dimension_code,decimal_scale) values(md5('global-test:unit')::uuid,'global-test-kg','global test kg','MASS',3);
insert into atlas_admin.school_types(school_type_id,school_type_code,school_type_name) select md5('global-test:type:'||id)::uuid,'v1-school-type-'||id,'Global test type '||id from unnest(array['1','2']) id;
insert into atlas_admin.ingredients(ingredient_id,ingredient_code,ingredient_name,ingredient_group,purchase_unit_id,ingredient_type,shopping_type,order_step)
select md5('global-test:ingredient:'||id)::uuid,'global-test-'||id,'Global test '||id,'Food',md5('global-test:unit')::uuid,'Food','Planned',1 from unnest(array['1043','1039','1029','1067','836','904','1040','1208']) id;
insert into atlas_admin.dishes(dish_id,dish_code,dish_name,dish_status) values(md5('global-test:dish')::uuid,'global-test-dish','Global test dish','ACTIVE');
insert into atlas_admin.recipes(recipe_id,dish_id,school_type_id) select md5('global-test:recipe:'||id)::uuid,md5('global-test:dish')::uuid,md5('global-test:type:'||id)::uuid from unnest(array['1','2']) id;
insert into atlas_admin.recipe_versions(recipe_version_id,recipe_id,version_number,basis_portions,created_by_actor_id)
select md5('global-test:version:'||id)::uuid,md5('global-test:recipe:'||id)::uuid,1,100,'a217bdd5-2858-58c2-8964-45c465225a59' from unnest(array['1','2']) id;
insert into atlas_admin.recipe_lines(recipe_line_id,recipe_id,line_code)
select md5('global-test:line:'||t||':'||i)::uuid,md5('global-test:recipe:'||t)::uuid,'line-'||i from unnest(array['1','2']) t cross join unnest(array['1043','1029','836','1040']) i;
insert into atlas_admin.recipe_line_revisions(recipe_line_revision_id,recipe_id,recipe_version_id,recipe_line_id,line_revision_number,ingredient_id,quantity_per_basis,unit_id,created_by_actor_id)
select md5('global-test:revision:'||t||':'||i)::uuid,md5('global-test:recipe:'||t)::uuid,md5('global-test:version:'||t)::uuid,md5('global-test:line:'||t||':'||i)::uuid,1,md5('global-test:ingredient:'||i)::uuid,1.123456,md5('global-test:unit')::uuid,'a217bdd5-2858-58c2-8964-45c465225a59' from unnest(array['1','2']) t cross join unnest(array['1043','1029','836','1040']) i;
set constraints all immediate;
update atlas_admin.recipe_versions set recipe_version_status='VALIDATED',validated_by_actor_id='a217bdd5-2858-58c2-8964-45c465225a59',validated_at='2026-01-01' where recipe_version_id in(select md5('global-test:version:'||id)::uuid from unnest(array['1','2']) id);
update atlas_admin.recipe_versions set recipe_version_status='RELEASED_FOR_PLANNING',released_by_actor_id='a217bdd5-2858-58c2-8964-45c465225a59',released_at='2026-01-01' where recipe_version_id in(select md5('global-test:version:'||id)::uuid from unnest(array['1','2']) id);
set constraints all deferred;
insert into atlas_legacy.import_batches(import_batch_id,source_system,snapshot_id,snapshot_checksum,exported_at,import_status,source_counts,completed_at) values(md5('global-test:batch')::uuid,'GLOBAL_TEST_FIXTURE','global-test-masters',repeat('a',64),'2026-11-09','COMPLETED','{}',transaction_timestamp());
insert into atlas_legacy.master_data_mappings(import_batch_id,source_system,object_type,legacy_id,ingredient_id)
select md5('global-test:batch')::uuid,'OPS_V1','INGREDIENT',id,md5('global-test:ingredient:'||id)::uuid from unnest(array['1043','1039','1029','1067','836','904','1040','1208']) id;
insert into atlas_legacy.master_data_mappings(import_batch_id,source_system,object_type,legacy_id,school_type_id)
select md5('global-test:batch')::uuid,'OPS_V1','SCHOOL_TYPE',id,md5('global-test:type:'||id)::uuid from unnest(array['1','2']) id;
insert into atlas_legacy.master_data_mappings(import_batch_id,source_system,object_type,legacy_id,dish_id) values(md5('global-test:batch')::uuid,'OPS_V1','DISH','2095',md5('global-test:dish')::uuid);

create temp table global_fixture(history jsonb,migrations jsonb,source_checksum text,preview jsonb,baseline jsonb);
insert into global_fixture(history,migrations)
select jsonb_build_object('contract_version','OPS-V1-RECIPE-HISTORY.v1','source_system','OPS_V1_RECIPE_HISTORY','source_project_ref','qnthofvccilhnefdcxnz','snapshot_id','global-test-source','exported_at','2026-11-09T00:00:00Z',
  'records',(select jsonb_agg(jsonb_build_object('source_table','ingredient_change_orders','legacy_id',id,'scope_kind','SYSTEM_INGREDIENT','action','REPLACE','source_active',true,'effective_from',day,
    'source_record',jsonb_build_object('id',id,'is_active',true,'effective_date',day,'old_ingredient_id',old_id,'new_ingredient_id',new_id)) order by id::bigint)
    from (values('7','1043','1039','2025-12-15'),('11','1029','1067','2026-03-03'),('12','836','904','2026-04-03'),('13','1042','1041','2026-10-09'),('14','1040','1208','2026-10-09')) p(id,old_id,new_id,day))),
  (select jsonb_agg(version order by version) from supabase_migrations.schema_migrations);
update global_fixture set history=history||jsonb_build_object('snapshot_checksum',atlas_legacy.master_snapshot_hash(history)), source_checksum=atlas_legacy.master_snapshot_hash(jsonb_build_object('source_project_ref','qnthofvccilhnefdcxnz','adoption_date','2026-11-09','records',history->'records')),baseline=pg_temp.global_adoption_fingerprints();
select throws_ok($$select pg_temp.run_global_replacements(history,'[]',source_checksum,false) from global_fixture$$,'P0001','MIGRATION_HISTORY_MISMATCH','Migration drift blocks');
select throws_ok($$select pg_temp.run_global_replacements(history,migrations,repeat('0',64),false) from global_fixture$$,'P0001','SOURCE_CONTENT_CHECKSUM_INVALID','Changed reviewed source content blocks');
savepoint source_drift;
update global_fixture set history=jsonb_set(history,'{records,0,source_record,new_ingredient_id}','"1041"');
update global_fixture set history=history||jsonb_build_object('snapshot_checksum',atlas_legacy.master_snapshot_hash(history-'snapshot_checksum'));
select throws_ok($$select pg_temp.run_global_replacements(history,migrations,source_checksum,false) from global_fixture$$,'P0001','GLOBAL_SOURCE_DRIFT','SQL independently pins the exact source edges');
rollback to source_drift;
savepoint other_source_target;
update atlas_legacy.master_data_mappings set source_system='OTHER_SOURCE' where source_system='OPS_V1' and object_type='INGREDIENT' and legacy_id='1043';
update global_fixture set baseline=pg_temp.global_adoption_fingerprints();
select throws_ok($$select pg_temp.run_global_replacements(history,migrations,source_checksum,false) from global_fixture$$,'P0001','INGREDIENT_MAPPING_REQUIRED','Other-source target Ingredient mapping cannot substitute for missing OPS mapping');
select is(pg_temp.global_adoption_fingerprints(),(select baseline from global_fixture),'Missing OPS target mapping leaves all facts and receipts unchanged');
rollback to other_source_target;
savepoint other_source_substitute;
update atlas_legacy.master_data_mappings set source_system='OTHER_SOURCE' where source_system='OPS_V1' and object_type='INGREDIENT' and legacy_id='1039';
select throws_ok($$select pg_temp.run_global_replacements(history,migrations,source_checksum,false) from global_fixture$$,'P0001','INGREDIENT_MAPPING_REQUIRED','Other-source substitute mapping cannot substitute for missing OPS mapping');
rollback to other_source_substitute;
savepoint other_source_typed;
update atlas_legacy.master_data_mappings set source_system='OTHER_SOURCE' where source_system='OPS_V1' and object_type='SCHOOL_TYPE' and legacy_id='1';
select throws_ok($$select pg_temp.run_global_replacements(history,migrations,source_checksum,false) from global_fixture$$,'P0001','MAPPED_TYPED_CONTEXTS_REQUIRED','Both canonical contexts require OPS mappings');
rollback to other_source_typed;
savepoint other_source_dish;
update atlas_legacy.master_data_mappings set source_system='OTHER_SOURCE' where source_system='OPS_V1' and object_type='DISH';
select throws_ok($$select pg_temp.run_global_replacements(history,migrations,source_checksum,false) from global_fixture$$,'P0001','MAPPED_TYPED_CONTEXTS_REQUIRED','Other-source Dishes cannot create OPS proof coverage');
rollback to other_source_dish;
savepoint incorrect_canonical_mapping;
update atlas_legacy.master_data_mappings set school_type_id=md5('global-test:type:'||case legacy_id when '1' then '2' else '1' end)::uuid where source_system='OPS_V1' and object_type='SCHOOL_TYPE';
select throws_ok($$select pg_temp.run_global_replacements(history,migrations,source_checksum,false) from global_fixture$$,'P0001','MAPPED_TYPED_CONTEXTS_REQUIRED','Legacy School Types must map to their exact active canonical identities');
rollback to incorrect_canonical_mapping;
savepoint inactive_canonical_type;
update atlas_admin.school_types set school_type_status='INACTIVE' where school_type_id=md5('global-test:type:1')::uuid;
select throws_ok($$select pg_temp.run_global_replacements(history,migrations,source_checksum,false) from global_fixture$$,'P0001','MAPPED_TYPED_CONTEXTS_REQUIRED','Inactive canonical School Type blocks the whole adoption');
rollback to inactive_canonical_type;
savepoint other_source_duplicates;
insert into atlas_legacy.master_data_mappings(import_batch_id,source_system,object_type,legacy_id,ingredient_id,school_type_id,dish_id)
select import_batch_id,'OTHER_SOURCE',object_type,legacy_id,ingredient_id,school_type_id,dish_id from atlas_legacy.master_data_mappings where source_system='OPS_V1';
select is((select pg_temp.run_global_replacements(history,migrations,source_checksum,false)->>'contexts' from global_fixture),'2','Unrelated same-key mappings neither create ambiguity nor expand OPS typed proof');
rollback to other_source_duplicates;
update global_fixture set preview=pg_temp.run_global_replacements(history,migrations,source_checksum,false);
select is((select preview->>'status' from global_fixture),'PREVIEW','Actual four-row import and canonical proof succeeds in preview');
select is((select preview->>'changed_lines' from global_fixture),'8','Both typed contexts retain all four stable lines');
select is((select preview->>'replay_status' from global_fixture),'REPLAYED','Preview tests exact same-snapshot replay');
select is(pg_temp.global_adoption_fingerprints(),(select baseline from global_fixture),'Preview rolls back every Atlas row, receipt and history');
select throws_ok($$select pg_temp.run_global_replacements(history,migrations,source_checksum,true,to_jsonb(repeat('0',64))) from global_fixture$$,'P0001','TARGET_OR_SOURCE_DRIFT','Unreviewed target state blocks apply');

-- A changed unrelated master also invalidates the reviewed target fingerprint.
savepoint target_drift;
update atlas_admin.ingredients set ingredient_name='Changed after preview' where ingredient_id=md5('global-test:ingredient:1043')::uuid;
select throws_ok($$select pg_temp.run_global_replacements(history,migrations,source_checksum,true,preview->'content_checksum') from global_fixture$$,'P0001','TARGET_OR_SOURCE_DRIFT','Whole target state drift blocks apply');
rollback to target_drift;

-- Current/future native ADD on a mapped Dish must block before using a final-line oracle.
savepoint native_interaction;
insert into atlas_admin.recipe_composition_adjustments(recipe_composition_adjustment_id,scope_kind,action_kind,dish_id,school_type_id,target_ingredient_id,adjustment_line_id,created_by_actor_id,updated_by_actor_id)
values(md5('global-test:native')::uuid,'SYSTEM_DISH','ADD',md5('global-test:dish')::uuid,md5('global-test:type:1')::uuid,md5('global-test:ingredient:1039')::uuid,md5('global-test:add-line')::uuid,'a217bdd5-2858-58c2-8964-45c465225a59','a217bdd5-2858-58c2-8964-45c465225a59');
insert into atlas_admin.recipe_composition_adjustment_revisions(recipe_composition_adjustment_revision_id,recipe_composition_adjustment_id,scope_kind,action_kind,revision_number,effective_from,quantity_per_basis,unit_id,reason_code,reason_note,created_by_actor_id)
values(md5('global-test:native-revision')::uuid,md5('global-test:native')::uuid,'SYSTEM_DISH','ADD',1,'2026-12-01',1,md5('global-test:unit')::uuid,'TEST','Future native ADD','a217bdd5-2858-58c2-8964-45c465225a59');
update atlas_admin.recipe_composition_adjustments set current_revision_id=md5('global-test:native-revision')::uuid,current_revision_number=1 where recipe_composition_adjustment_id=md5('global-test:native')::uuid;
select throws_ok($$select pg_temp.run_global_replacements(history,migrations,source_checksum,false) from global_fixture$$,'P0001','NATIVE_INTERACTION_BLOCKED','Future native interactions block even when not yet effective');
rollback to native_interaction;

-- Reusable local fixture only; immutable revisions are inserted, never edited.
create function pg_temp.global_test_native(dish uuid,period_from date,period_to date default null) returns void language plpgsql as $$
begin
  insert into atlas_admin.recipe_composition_adjustments(recipe_composition_adjustment_id,scope_kind,action_kind,dish_id,school_type_id,target_ingredient_id,adjustment_line_id,created_by_actor_id,updated_by_actor_id)
  values(md5('global-test:native')::uuid,'SYSTEM_DISH','ADD',dish,md5('global-test:type:1')::uuid,md5('global-test:ingredient:1039')::uuid,md5('global-test:add-line')::uuid,'a217bdd5-2858-58c2-8964-45c465225a59','a217bdd5-2858-58c2-8964-45c465225a59');
  insert into atlas_admin.recipe_composition_adjustment_revisions(recipe_composition_adjustment_revision_id,recipe_composition_adjustment_id,scope_kind,action_kind,revision_number,effective_from,effective_to,quantity_per_basis,unit_id,reason_code,reason_note,created_by_actor_id)
  values(md5('global-test:native-revision')::uuid,md5('global-test:native')::uuid,'SYSTEM_DISH','ADD',1,period_from,period_to,1,md5('global-test:unit')::uuid,'TEST','Native fixture','a217bdd5-2858-58c2-8964-45c465225a59');
  update atlas_admin.recipe_composition_adjustments set current_revision_id=md5('global-test:native-revision')::uuid,current_revision_number=1 where recipe_composition_adjustment_id=md5('global-test:native')::uuid;
end $$;
savepoint current_native;
select pg_temp.global_test_native(md5('global-test:dish')::uuid,'2026-10-20');
select throws_ok($$select pg_temp.run_global_replacements(history,migrations,source_checksum,false) from global_fixture$$,'P0001','NATIVE_INTERACTION_BLOCKED','Current native ADD blocks before the final-line oracle');
rollback to current_native;
savepoint expired_native;
select pg_temp.global_test_native(md5('global-test:dish')::uuid,'2026-10-20','2026-10-21');
select is((select pg_temp.run_global_replacements(history,migrations,source_checksum,false)->>'preserved' from global_fixture),'true','Expired native history is allowed and preserved exactly');
rollback to expired_native;
savepoint unrelated_native;
insert into atlas_admin.dishes(dish_id,dish_code,dish_name,dish_status) values(md5('global-test:unmapped-dish')::uuid,'global-test-unmapped','Unmapped native fixture','ACTIVE');
insert into atlas_legacy.master_data_mappings(import_batch_id,source_system,object_type,legacy_id,dish_id) values(md5('global-test:batch')::uuid,'OTHER_SOURCE','DISH','2095',md5('global-test:unmapped-dish')::uuid);
select pg_temp.global_test_native(md5('global-test:unmapped-dish')::uuid,'2026-10-20');
select is((select pg_temp.run_global_replacements(history,migrations,source_checksum,false)->>'preserved' from global_fixture),'true','Unrelated native fixture mapped only by another source stays outside OPS interaction scope');
rollback to unrelated_native;

savepoint school_interaction;
insert into atlas_admin.customers(customer_id,customer_code,customer_name,customer_type) values(md5('global-test:customer')::uuid,'global-test-customer','Global test customer','SCHOOL_CATERING');
insert into atlas_admin.delivery_locations(delivery_location_id,customer_id,location_code,location_name,address_text,timezone_name) values(md5('global-test:location')::uuid,md5('global-test:customer')::uuid,'global-test-location','Global test location','Synthetic fixture','Asia/Ho_Chi_Minh');
insert into atlas_admin.schools(school_id,customer_id,school_code,school_name,school_type_id,default_delivery_location_id,display_order) values(md5('global-test:school')::uuid,md5('global-test:customer')::uuid,'global-test-school','Global test school',md5('global-test:type:1')::uuid,md5('global-test:location')::uuid,1);
insert into atlas_admin.recipe_composition_adjustments(recipe_composition_adjustment_id,scope_kind,action_kind,school_id,target_ingredient_id,created_by_actor_id,updated_by_actor_id)
values(md5('global-test:school-rule')::uuid,'SCHOOL','REPLACE',md5('global-test:school')::uuid,md5('global-test:ingredient:1043')::uuid,'a217bdd5-2858-58c2-8964-45c465225a59','a217bdd5-2858-58c2-8964-45c465225a59');
insert into atlas_admin.recipe_composition_adjustment_revisions(recipe_composition_adjustment_revision_id,recipe_composition_adjustment_id,scope_kind,action_kind,revision_number,effective_from,substitute_ingredient_id,reason_code,reason_note,created_by_actor_id)
values(md5('global-test:school-revision')::uuid,md5('global-test:school-rule')::uuid,'SCHOOL','REPLACE',1,'2026-11-09',md5('global-test:ingredient:1039')::uuid,'TEST','School fixture','a217bdd5-2858-58c2-8964-45c465225a59');
update atlas_admin.recipe_composition_adjustments set current_revision_id=md5('global-test:school-revision')::uuid,current_revision_number=1 where recipe_composition_adjustment_id=md5('global-test:school-rule')::uuid;
select throws_ok($$select pg_temp.run_global_replacements(history,migrations,source_checksum,false) from global_fixture$$,'P0001','NATIVE_INTERACTION_BLOCKED','Current School REPLACE blocks before a system-only proof');
rollback to school_interaction;

-- Duplicate final Ingredient must reject the whole four-row import with no receipt.
savepoint duplicate_destination;
insert into atlas_admin.dishes(dish_id,dish_code,dish_name,dish_status) values(md5('global-test:duplicate-dish')::uuid,'global-test-duplicate','Global duplicate test','ACTIVE');
insert into atlas_admin.recipes(recipe_id,dish_id,school_type_id) values(md5('global-test:duplicate-recipe')::uuid,md5('global-test:duplicate-dish')::uuid,md5('global-test:type:1')::uuid);
insert into atlas_admin.recipe_versions(recipe_version_id,recipe_id,version_number,basis_portions,created_by_actor_id) values(md5('global-test:duplicate-version')::uuid,md5('global-test:duplicate-recipe')::uuid,1,100,'a217bdd5-2858-58c2-8964-45c465225a59');
insert into atlas_admin.recipe_lines(recipe_line_id,recipe_id,line_code) select md5('global-test:duplicate-line:'||id)::uuid,md5('global-test:duplicate-recipe')::uuid,'duplicate-'||id from unnest(array['1043','1039']) id;
insert into atlas_admin.recipe_line_revisions(recipe_line_revision_id,recipe_id,recipe_version_id,recipe_line_id,line_revision_number,ingredient_id,quantity_per_basis,unit_id,created_by_actor_id)
select md5('global-test:duplicate-revision:'||id)::uuid,md5('global-test:duplicate-recipe')::uuid,md5('global-test:duplicate-version')::uuid,md5('global-test:duplicate-line:'||id)::uuid,1,md5('global-test:ingredient:'||id)::uuid,1,md5('global-test:unit')::uuid,'a217bdd5-2858-58c2-8964-45c465225a59' from unnest(array['1043','1039']) id;
set constraints all immediate;
update atlas_admin.recipe_versions set recipe_version_status='VALIDATED',validated_by_actor_id='a217bdd5-2858-58c2-8964-45c465225a59',validated_at='2026-01-01' where recipe_version_id=md5('global-test:duplicate-version')::uuid;
update atlas_admin.recipe_versions set recipe_version_status='RELEASED_FOR_PLANNING',released_by_actor_id='a217bdd5-2858-58c2-8964-45c465225a59',released_at='2026-01-01' where recipe_version_id=md5('global-test:duplicate-version')::uuid;
set constraints all deferred;
insert into atlas_legacy.master_data_mappings(import_batch_id,source_system,object_type,legacy_id,dish_id) values(md5('global-test:batch')::uuid,'OPS_V1','DISH','duplicate-test',md5('global-test:duplicate-dish')::uuid);
select throws_like($$select pg_temp.run_global_replacements(history,migrations,source_checksum,false) from global_fixture$$,'%DUPLICATE_EFFECTIVE_INGREDIENT%','Duplicate destination blocks preview rather than silently aggregating');
select is((select count(*) from atlas_legacy.import_batches where snapshot_id='atlas-global-adoption-20261109'),0::bigint,'Failed duplicate proof leaves no receipt');
rollback to duplicate_destination;

create temp table applied_global_result as select pg_temp.run_global_replacements(history,migrations,source_checksum,true,preview->'content_checksum') result from global_fixture;
select is((select result->>'status' from applied_global_result),'APPLIED','Reviewed exact target and source applies');
select is((select result->>'replay_status' from applied_global_result),'REPLAYED','Apply proves exact same-snapshot replay');
select is((select count(*) from atlas_legacy.import_batches where snapshot_id='atlas-global-adoption-20261109'),1::bigint,'Exactly one receipt');
select is((select count(*) from atlas_admin.recipe_composition_adjustments where legacy_source='OPS_V1_INGREDIENT_CHANGE_ORDER'),4::bigint,'Exactly four actual source roots');
select is((select count(*) from atlas_admin.recipe_composition_adjustment_revisions where effective_from='2026-11-09'),4::bigint,'Current Atlas adoption date, no backdating');
select ok((select bool_and(reason_note::jsonb->'original_source'->>'effective_from' in('2025-12-15','2026-03-03','2026-04-03','2026-10-09') and source_evidence->>'historical_actor_approval_claimed'='false') from atlas_admin.recipe_composition_adjustment_revisions where reason_code='LEGACY_IMPORT'),'Original source dates retained; historical Atlas issuance never claimed');
select is((select result->>'preserved' from applied_global_result),'true','Every preexisting Atlas row and prior receipt preserved');
select * from finish();
rollback;
