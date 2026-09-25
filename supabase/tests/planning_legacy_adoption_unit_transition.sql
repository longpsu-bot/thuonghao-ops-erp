begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
select plan(20);
set local session_replication_role=replica;

insert into atlas_core.actors(actor_id,actor_type,display_name)
values('d0470000-0000-0000-0000-000000000001','HUMAN','D-047 transition fixture');
insert into atlas_admin.customers(customer_id,customer_code,customer_name,customer_type) values
 ('d0470000-0000-0000-0000-000000000010','d047-customer','D-047 customer','SCHOOL_CATERING'),
 ('d0470000-0000-0000-0000-000000000011','d047-other-customer','D-047 other customer','SCHOOL_CATERING');
insert into atlas_admin.delivery_locations(delivery_location_id,customer_id,location_code,location_name,address_text) values
 ('d0470000-0000-0000-0000-000000000020','d0470000-0000-0000-0000-000000000010','d047-location','D-047 location','Fixture'),
 ('d0470000-0000-0000-0000-000000000021','d0470000-0000-0000-0000-000000000011','d047-other-location','D-047 other location','Fixture');
insert into atlas_admin.school_types(school_type_id,school_type_code,school_type_name)
values('d0470000-0000-0000-0000-000000000030','d047-school-type','D-047 school type');
insert into atlas_admin.schools(school_id,customer_id,school_code,school_name,school_type_id,default_delivery_location_id,display_order) values
 ('d0470000-0000-0000-0000-000000000040','d0470000-0000-0000-0000-000000000010','d047-school','D-047 school','d0470000-0000-0000-0000-000000000030','d0470000-0000-0000-0000-000000000020',0),
 ('d0470000-0000-0000-0000-000000000041','d0470000-0000-0000-0000-000000000010','d047-other-school','D-047 other school','d0470000-0000-0000-0000-000000000030','d0470000-0000-0000-0000-000000000020',1);
insert into atlas_admin.units(unit_id,unit_code,unit_name,dimension_code) values
 ('d0470000-0000-0000-0000-000000000050','d047-raw-cai','Cái','COUNT'),
 ('d0470000-0000-0000-0000-000000000051','d047-kilogram','Kilogram','MASS'),
 ('d0470000-0000-0000-0000-000000000052','d047-other-unit','Other Unit','COUNT'),
 ('d0470000-0000-0000-0000-000000000053','d047-raw-qua','Quả','COUNT'),
 ('d0470000-0000-0000-0000-000000000054','d047-trai','Trái','COUNT'),
 ('d0470000-0000-0000-0000-000000000055','d047-raw-bich','Bịch','COUNT'),
 ('d0470000-0000-0000-0000-000000000056','d047-chai','Chai','COUNT');
insert into atlas_admin.ingredients(ingredient_id,ingredient_code,ingredient_name,purchase_unit_id,order_step) values
 ('d0470000-0000-0000-0000-000000000060','d047-ingredient','D-047 ingredient','d0470000-0000-0000-0000-000000000051',1),
 ('d0470000-0000-0000-0000-000000000061','d047-other-ingredient','D-047 other ingredient','d0470000-0000-0000-0000-000000000051',1);
insert into atlas_admin.dishes(dish_id,dish_code,dish_name,dish_status)
values('d0470000-0000-0000-0000-000000000070','d047-dish','D-047 dish','ACTIVE');
insert into atlas_admin.recipes(recipe_id,dish_id,school_type_id,recipe_status)
values('d0470000-0000-0000-0000-000000000080','d0470000-0000-0000-0000-000000000070','d0470000-0000-0000-0000-000000000030','ACTIVE');
insert into atlas_admin.recipe_versions(recipe_version_id,recipe_id,version_number,predecessor_recipe_version_id,basis_portions,created_by_actor_id) values
 ('d0470000-0000-0000-0000-000000000081','d0470000-0000-0000-0000-000000000080',1,null,100,'d0470000-0000-0000-0000-000000000001'),
 ('d0470000-0000-0000-0000-000000000082','d0470000-0000-0000-0000-000000000080',2,'d0470000-0000-0000-0000-000000000081',100,'d0470000-0000-0000-0000-000000000001');
insert into atlas_admin.recipe_lines(recipe_line_id,recipe_id,line_code)
values('d0470000-0000-0000-0000-000000000090','d0470000-0000-0000-0000-000000000080','d047-line');
insert into atlas_admin.recipe_line_revisions(
 recipe_line_revision_id,recipe_id,recipe_version_id,recipe_line_id,line_revision_number,
 predecessor_recipe_line_revision_id,ingredient_id,quantity_per_basis,unit_id,line_disposition,created_by_actor_id
) values
 ('d0470000-0000-0000-0000-000000000091','d0470000-0000-0000-0000-000000000080','d0470000-0000-0000-0000-000000000081','d0470000-0000-0000-0000-000000000090',1,null,'d0470000-0000-0000-0000-000000000060',12,'d0470000-0000-0000-0000-000000000050','PRESENT','d0470000-0000-0000-0000-000000000001'),
 ('d0470000-0000-0000-0000-000000000092','d0470000-0000-0000-0000-000000000080','d0470000-0000-0000-0000-000000000082','d0470000-0000-0000-0000-000000000090',2,'d0470000-0000-0000-0000-000000000091','d0470000-0000-0000-0000-000000000060',12,'d0470000-0000-0000-0000-000000000051','PRESENT','d0470000-0000-0000-0000-000000000001');

insert into atlas_legacy.import_batches(
 import_batch_id,source_system,snapshot_id,snapshot_checksum,exported_at,import_status,source_counts,
 completed_at,operator_actor_id,execution_database_principal,plan_checksum,snapshot_contract_version
) values(
 'd0470000-0000-0000-0000-000000000100','OPS_V1','d047-snapshot',repeat('b',64),transaction_timestamp(),
 'COMPLETED','{}',transaction_timestamp(),'d0470000-0000-0000-0000-000000000001','postgres',repeat('c',64),'OPS-V1-MASTER-SNAPSHOT.v1'
);
insert into atlas_legacy.master_data_mappings(
 master_data_mapping_id,import_batch_id,source_system,object_type,legacy_id,
 recipe_id,recipe_version_id,recipe_line_id,recipe_line_revision_id,ingredient_id,unit_id,
 last_seen_import_batch_id,last_source_fingerprint,last_target_version
) values
 ('d0470000-0000-0000-0000-000000000101','d0470000-0000-0000-0000-000000000100','OPS_V1','RECIPE','d047-recipe','d0470000-0000-0000-0000-000000000080',null,null,null,null,null,'d0470000-0000-0000-0000-000000000100',repeat('a',64),1),
 ('d0470000-0000-0000-0000-000000000102','d0470000-0000-0000-0000-000000000100','OPS_V1','RECIPE_VERSION','d047-recipe:version:1',null,'d0470000-0000-0000-0000-000000000081',null,null,null,null,'d0470000-0000-0000-0000-000000000100',repeat('a',64),1),
 ('d0470000-0000-0000-0000-000000000103','d0470000-0000-0000-0000-000000000100','OPS_V1','RECIPE_LINE','d047-line',null,null,'d0470000-0000-0000-0000-000000000090',null,null,null,'d0470000-0000-0000-0000-000000000100',repeat('a',64),1),
 ('d0470000-0000-0000-0000-000000000104','d0470000-0000-0000-0000-000000000100','OPS_V1','RECIPE_LINE_REVISION','d047-line:revision:1',null,null,null,'d0470000-0000-0000-0000-000000000091',null,null,'d0470000-0000-0000-0000-000000000100',repeat('a',64),1),
 ('d0470000-0000-0000-0000-000000000105','d0470000-0000-0000-0000-000000000100','OPS_V1','INGREDIENT','956',null,null,null,null,'d0470000-0000-0000-0000-000000000060',null,'d0470000-0000-0000-0000-000000000100',repeat('a',64),1),
 ('d0470000-0000-0000-0000-000000000106','d0470000-0000-0000-0000-000000000100','OPS_V1','UNIT','Cái',null,null,null,null,null,'d0470000-0000-0000-0000-000000000050','d0470000-0000-0000-0000-000000000100',repeat('a',64),1),
 ('d0470000-0000-0000-0000-000000000107','d0470000-0000-0000-0000-000000000100','OPS_V1','UNIT','Quả',null,null,null,null,null,'d0470000-0000-0000-0000-000000000053','d0470000-0000-0000-0000-000000000100',repeat('a',64),1),
 ('d0470000-0000-0000-0000-000000000108','d0470000-0000-0000-0000-000000000100','OPS_V1','UNIT','Bịch',null,null,null,null,null,'d0470000-0000-0000-0000-000000000055','d0470000-0000-0000-0000-000000000100',repeat('a',64),1);
insert into atlas_legacy.recipe_unit_adoption_evidence(
 recipe_unit_adoption_evidence_id,evidence_kind,source_system,import_batch_id,snapshot_id,snapshot_checksum,
 legacy_recipe_line_id,source_fingerprint,recipe_id,recipe_line_id,predecessor_recipe_version_id,target_recipe_version_id,
 predecessor_recipe_line_revision_id,target_recipe_line_revision_id,ingredient_id,quantity_per_basis,
 source_unit_id,corrected_unit_id,recorded_by_actor_id
) values(
 'd0470000-0000-0000-0000-000000000110','OPS_V1_BOM_UNIT_TO_INGREDIENT_PURCHASE_UNIT_CORRECTION','OPS_V1',
 'd0470000-0000-0000-0000-000000000100','d047-snapshot',repeat('b',64),'d047-line',repeat('a',64),
 'd0470000-0000-0000-0000-000000000080','d0470000-0000-0000-0000-000000000090',
 'd0470000-0000-0000-0000-000000000081','d0470000-0000-0000-0000-000000000082',
 'd0470000-0000-0000-0000-000000000091','d0470000-0000-0000-0000-000000000092',
 'd0470000-0000-0000-0000-000000000060',12,'d0470000-0000-0000-0000-000000000050',
 'd0470000-0000-0000-0000-000000000051','d0470000-0000-0000-0000-000000000001'
);

insert into atlas_planning.theoretical_need_lines(
 theoretical_need_line_id,need_generation_run_id,need_generation_input_snapshot_id,
 need_generation_recipe_selection_id,need_generation_recipe_line_use_id,
 weekly_menu_approval_snapshot_line_id,weekly_menu_approval_snapshot_id,weekly_menu_id,weekly_menu_version,weekly_menu_line_id,
 attendance_approval_snapshot_line_id,attendance_approval_snapshot_id,attendance_batch_id,attendance_version,attendance_line_id,
 school_id,service_date,dish_id,recipe_id,recipe_version_id,recipe_line_id,recipe_line_revision_id,
 ingredient_id,unit_id,need_generation_calculation_contract_id,need_generation_calculation_contract_revision_id,
 calculation_contract_revision_number,predecessor_need_generation_run_id,predecessor_theoretical_need_line_id,
 line_disposition,theoretical_quantity,created_at,contribution_family
) values
 ('d0470000-0000-0000-0000-000000000120','d0470000-0000-0000-0000-000000000121','d0470000-0000-0000-0000-000000000122',
  'd0470000-0000-0000-0000-000000000123','d0470000-0000-0000-0000-000000000124','d0470000-0000-0000-0000-000000000125',
  'd0470000-0000-0000-0000-000000000126','d0470000-0000-0000-0000-000000000127',1,'d0470000-0000-0000-0000-000000000128',
  'd0470000-0000-0000-0000-000000000129','d0470000-0000-0000-0000-000000000130','d0470000-0000-0000-0000-000000000131',1,
  'd0470000-0000-0000-0000-000000000132','d0470000-0000-0000-0000-000000000040','2026-09-17','d0470000-0000-0000-0000-000000000070',
  'd0470000-0000-0000-0000-000000000080','d0470000-0000-0000-0000-000000000081','d0470000-0000-0000-0000-000000000090',
  'd0470000-0000-0000-0000-000000000091','d0470000-0000-0000-0000-000000000060','d0470000-0000-0000-0000-000000000050',
  'd0470000-0000-0000-0000-000000000133','d0470000-0000-0000-0000-000000000134',1,null,null,'ACTIVE',12,transaction_timestamp(),'RECIPE_DERIVED'),
 ('d0470000-0000-0000-0000-000000000140','d0470000-0000-0000-0000-000000000141','d0470000-0000-0000-0000-000000000142',
  'd0470000-0000-0000-0000-000000000143','d0470000-0000-0000-0000-000000000144','d0470000-0000-0000-0000-000000000145',
  'd0470000-0000-0000-0000-000000000146','d0470000-0000-0000-0000-000000000147',1,'d0470000-0000-0000-0000-000000000148',
  'd0470000-0000-0000-0000-000000000149','d0470000-0000-0000-0000-000000000150','d0470000-0000-0000-0000-000000000151',1,
  'd0470000-0000-0000-0000-000000000152','d0470000-0000-0000-0000-000000000040','2026-09-17','d0470000-0000-0000-0000-000000000070',
  'd0470000-0000-0000-0000-000000000080','d0470000-0000-0000-0000-000000000082','d0470000-0000-0000-0000-000000000090',
  'd0470000-0000-0000-0000-000000000092','d0470000-0000-0000-0000-000000000060','d0470000-0000-0000-0000-000000000051',
  'd0470000-0000-0000-0000-000000000153','d0470000-0000-0000-0000-000000000154',1,
  'd0470000-0000-0000-0000-000000000121','d0470000-0000-0000-0000-000000000120','ACTIVE',12,transaction_timestamp(),'RECIPE_DERIVED');

insert into atlas_planning.confirmed_need_line_revision_contributions(
 confirmed_need_line_revision_contribution_id,confirmed_need_batch_id,confirmed_need_line_id,confirmed_need_line_revision_id,
 need_generation_run_id,need_generation_run_version,need_generation_release_snapshot_id,need_generation_release_snapshot_line_id,
 theoretical_need_line_id,service_date,customer_id,school_id,delivery_location_id,ingredient_id,source_unit_id,
 controlled_unit_id,source_theoretical_quantity,controlled_contribution_quantity
) values(
 'd0470000-0000-0000-0000-000000000160','d0470000-0000-0000-0000-000000000161','d0470000-0000-0000-0000-000000000162',
 'd0470000-0000-0000-0000-000000000163','d0470000-0000-0000-0000-000000000121',3,'d0470000-0000-0000-0000-000000000164',
 'd0470000-0000-0000-0000-000000000165','d0470000-0000-0000-0000-000000000120','2026-09-17',
 'd0470000-0000-0000-0000-000000000010','d0470000-0000-0000-0000-000000000040','d0470000-0000-0000-0000-000000000020',
 'd0470000-0000-0000-0000-000000000060','d0470000-0000-0000-0000-000000000050','d0470000-0000-0000-0000-000000000050',12,12
);

select ok(atlas_core.planning_legacy_adoption_unit_transition_allowed(
 'd0470000-0000-0000-0000-000000000120','d0470000-0000-0000-0000-000000000140'),
 'proven OPS-v1 transition is eligible');
select is((select theoretical_quantity from atlas_planning.theoretical_need_lines where theoretical_need_line_id='d0470000-0000-0000-0000-000000000140'),12.000000::numeric,'no theoretical quantity conversion occurs');

savepoint transition_pair;
update atlas_admin.recipe_line_revisions set unit_id=case recipe_line_revision_id when 'd0470000-0000-0000-0000-000000000091' then 'd0470000-0000-0000-0000-000000000053'::uuid else 'd0470000-0000-0000-0000-000000000054'::uuid end where recipe_line_revision_id in ('d0470000-0000-0000-0000-000000000091','d0470000-0000-0000-0000-000000000092');
update atlas_admin.ingredients set purchase_unit_id='d0470000-0000-0000-0000-000000000054' where ingredient_id='d0470000-0000-0000-0000-000000000060';
update atlas_planning.theoretical_need_lines set unit_id=case theoretical_need_line_id when 'd0470000-0000-0000-0000-000000000120' then 'd0470000-0000-0000-0000-000000000053'::uuid else 'd0470000-0000-0000-0000-000000000054'::uuid end where theoretical_need_line_id in ('d0470000-0000-0000-0000-000000000120','d0470000-0000-0000-0000-000000000140');
update atlas_planning.confirmed_need_line_revision_contributions set source_unit_id='d0470000-0000-0000-0000-000000000053',controlled_unit_id='d0470000-0000-0000-0000-000000000053' where confirmed_need_line_revision_contribution_id='d0470000-0000-0000-0000-000000000160';
update atlas_legacy.recipe_unit_adoption_evidence set source_unit_id='d0470000-0000-0000-0000-000000000053',corrected_unit_id='d0470000-0000-0000-0000-000000000054' where recipe_unit_adoption_evidence_id='d0470000-0000-0000-0000-000000000110';
select ok(atlas_core.planning_legacy_adoption_unit_transition_allowed('d0470000-0000-0000-0000-000000000120','d0470000-0000-0000-0000-000000000140'),'proven Quả to Trái adoption transition is eligible');
rollback to savepoint transition_pair;

savepoint transition_pair;
update atlas_admin.recipe_line_revisions set unit_id=case recipe_line_revision_id when 'd0470000-0000-0000-0000-000000000091' then 'd0470000-0000-0000-0000-000000000055'::uuid else 'd0470000-0000-0000-0000-000000000056'::uuid end where recipe_line_revision_id in ('d0470000-0000-0000-0000-000000000091','d0470000-0000-0000-0000-000000000092');
update atlas_admin.ingredients set purchase_unit_id='d0470000-0000-0000-0000-000000000056' where ingredient_id='d0470000-0000-0000-0000-000000000060';
update atlas_planning.theoretical_need_lines set unit_id=case theoretical_need_line_id when 'd0470000-0000-0000-0000-000000000120' then 'd0470000-0000-0000-0000-000000000055'::uuid else 'd0470000-0000-0000-0000-000000000056'::uuid end where theoretical_need_line_id in ('d0470000-0000-0000-0000-000000000120','d0470000-0000-0000-0000-000000000140');
update atlas_planning.confirmed_need_line_revision_contributions set source_unit_id='d0470000-0000-0000-0000-000000000055',controlled_unit_id='d0470000-0000-0000-0000-000000000055' where confirmed_need_line_revision_contribution_id='d0470000-0000-0000-0000-000000000160';
update atlas_legacy.recipe_unit_adoption_evidence set source_unit_id='d0470000-0000-0000-0000-000000000055',corrected_unit_id='d0470000-0000-0000-0000-000000000056' where recipe_unit_adoption_evidence_id='d0470000-0000-0000-0000-000000000110';
select ok(atlas_core.planning_legacy_adoption_unit_transition_allowed('d0470000-0000-0000-0000-000000000120','d0470000-0000-0000-0000-000000000140'),'proven Bịch to Chai adoption transition is eligible');
rollback to savepoint transition_pair;

savepoint mutation;
delete from atlas_legacy.master_data_mappings where master_data_mapping_id='d0470000-0000-0000-0000-000000000104';
select isnt(atlas_core.planning_legacy_adoption_unit_transition_allowed('d0470000-0000-0000-0000-000000000120','d0470000-0000-0000-0000-000000000140'),true,'missing predecessor mapping fails closed');
rollback to savepoint mutation;
savepoint mutation;
update atlas_planning.theoretical_need_lines set ingredient_id='d0470000-0000-0000-0000-000000000061' where theoretical_need_line_id='d0470000-0000-0000-0000-000000000140';
select isnt(atlas_core.planning_legacy_adoption_unit_transition_allowed('d0470000-0000-0000-0000-000000000120','d0470000-0000-0000-0000-000000000140'),true,'Ingredient change fails closed');
rollback to savepoint mutation;
savepoint mutation;
update atlas_planning.theoretical_need_lines set theoretical_quantity=13 where theoretical_need_line_id='d0470000-0000-0000-0000-000000000140';
select isnt(atlas_core.planning_legacy_adoption_unit_transition_allowed('d0470000-0000-0000-0000-000000000120','d0470000-0000-0000-0000-000000000140'),true,'quantity change fails closed');
rollback to savepoint mutation;
savepoint mutation;
update atlas_planning.theoretical_need_lines set school_id='d0470000-0000-0000-0000-000000000041' where theoretical_need_line_id='d0470000-0000-0000-0000-000000000140';
select isnt(atlas_core.planning_legacy_adoption_unit_transition_allowed('d0470000-0000-0000-0000-000000000120','d0470000-0000-0000-0000-000000000140'),true,'School change fails closed');
rollback to savepoint mutation;
savepoint mutation;
update atlas_planning.theoretical_need_lines set service_date='2026-09-18' where theoretical_need_line_id='d0470000-0000-0000-0000-000000000140';
select isnt(atlas_core.planning_legacy_adoption_unit_transition_allowed('d0470000-0000-0000-0000-000000000120','d0470000-0000-0000-0000-000000000140'),true,'service date change fails closed');
rollback to savepoint mutation;
savepoint mutation;
update atlas_planning.confirmed_need_line_revision_contributions set customer_id='d0470000-0000-0000-0000-000000000011' where confirmed_need_line_revision_contribution_id='d0470000-0000-0000-0000-000000000160';
select isnt(atlas_core.planning_legacy_adoption_unit_transition_allowed('d0470000-0000-0000-0000-000000000120','d0470000-0000-0000-0000-000000000140'),true,'customer change fails closed');
rollback to savepoint mutation;
savepoint mutation;
update atlas_planning.confirmed_need_line_revision_contributions set delivery_location_id='d0470000-0000-0000-0000-000000000021' where confirmed_need_line_revision_contribution_id='d0470000-0000-0000-0000-000000000160';
select isnt(atlas_core.planning_legacy_adoption_unit_transition_allowed('d0470000-0000-0000-0000-000000000120','d0470000-0000-0000-0000-000000000140'),true,'delivery location change fails closed');
rollback to savepoint mutation;
savepoint mutation;
update atlas_planning.theoretical_need_lines set predecessor_theoretical_need_line_id='d0470000-0000-0000-0000-000000000166' where theoretical_need_line_id='d0470000-0000-0000-0000-000000000140';
select isnt(atlas_core.planning_legacy_adoption_unit_transition_allowed('d0470000-0000-0000-0000-000000000120','d0470000-0000-0000-0000-000000000140'),true,'theoretical predecessor change fails closed');
rollback to savepoint mutation;
savepoint mutation;
update atlas_legacy.recipe_unit_adoption_evidence set source_unit_id='d0470000-0000-0000-0000-000000000052' where recipe_unit_adoption_evidence_id='d0470000-0000-0000-0000-000000000110';
select isnt(atlas_core.planning_legacy_adoption_unit_transition_allowed('d0470000-0000-0000-0000-000000000120','d0470000-0000-0000-0000-000000000140'),true,'raw Unit change fails closed');
rollback to savepoint mutation;
savepoint mutation;
update atlas_legacy.recipe_unit_adoption_evidence set corrected_unit_id='d0470000-0000-0000-0000-000000000052' where recipe_unit_adoption_evidence_id='d0470000-0000-0000-0000-000000000110';
select isnt(atlas_core.planning_legacy_adoption_unit_transition_allowed('d0470000-0000-0000-0000-000000000120','d0470000-0000-0000-0000-000000000140'),true,'corrected Unit change fails closed');
rollback to savepoint mutation;
savepoint mutation;
update atlas_legacy.recipe_unit_adoption_evidence set evidence_kind='OPS_V1_INGREDIENT_PURCHASE_UNIT_ADOPTION',predecessor_recipe_version_id=null,predecessor_recipe_line_revision_id=null where recipe_unit_adoption_evidence_id='d0470000-0000-0000-0000-000000000110';
select isnt(atlas_core.planning_legacy_adoption_unit_transition_allowed('d0470000-0000-0000-0000-000000000120','d0470000-0000-0000-0000-000000000140'),true,'non-correction evidence kind fails closed');
rollback to savepoint mutation;
savepoint mutation;
update atlas_admin.recipe_versions set predecessor_recipe_version_id=null where recipe_version_id='d0470000-0000-0000-0000-000000000082';
select isnt(atlas_core.planning_legacy_adoption_unit_transition_allowed('d0470000-0000-0000-0000-000000000120','d0470000-0000-0000-0000-000000000140'),true,'Recipe-version predecessor change fails closed');
rollback to savepoint mutation;
savepoint mutation;
update atlas_admin.recipe_line_revisions set predecessor_recipe_line_revision_id=null where recipe_line_revision_id='d0470000-0000-0000-0000-000000000092';
select isnt(atlas_core.planning_legacy_adoption_unit_transition_allowed('d0470000-0000-0000-0000-000000000120','d0470000-0000-0000-0000-000000000140'),true,'Recipe-line predecessor change fails closed');
rollback to savepoint mutation;
select isnt(atlas_core.planning_legacy_adoption_unit_transition_allowed('d0470000-0000-0000-0000-000000000120','d0470000-0000-0000-0000-000000000167'),true,'native mismatch without evidence remains blocked');
select ok((select pg_get_functiondef('atlas_core.planning_contract_01_materialize_confirmed_needs(jsonb)'::regprocedure) like '%planning_legacy_adoption_unit_transition_allowed%'),'materializer delegates only Unit changes to the exact private predicate');
select is((select count(*) from atlas_planning.confirmed_need_line_decisions),0::bigint,'changed Unit identity fabricates or carries no decision');

select * from finish();
rollback;
