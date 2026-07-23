begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
select plan(104);

set local session_replication_role = replica;

insert into atlas_core.actors (actor_id,actor_type,display_name)
values ('cb200000-0000-0000-0000-000000000001','HUMAN','H0Cb correction planner');
insert into atlas_core.actor_auth_subjects (actor_id,auth_subject_id)
values ('cb200000-0000-0000-0000-000000000001','cb200000-0000-0000-0000-000000000002');
insert into atlas_core.roles (role_id,role_code,role_name)
values ('cb200000-0000-0000-0000-000000000003','h0cb.correction.planner','H0Cb correction planner');
insert into atlas_core.role_capabilities (role_id,capability_id)
select 'cb200000-0000-0000-0000-000000000003',capability_id from atlas_core.capabilities where capability_code='confirmed_need_generation.materialize';
insert into atlas_core.actor_role_memberships (actor_id,role_id)
values ('cb200000-0000-0000-0000-000000000001','cb200000-0000-0000-0000-000000000003');
insert into atlas_core.actor_scopes (actor_id,scope_kind)
values ('cb200000-0000-0000-0000-000000000001','GLOBAL');

insert into atlas_admin.customers (customer_id,customer_code,customer_name,customer_type)
values ('cb200000-0000-0000-0000-000000000010','h0cb-correction-customer','H0Cb correction customer','SCHOOL_CATERING');
insert into atlas_admin.delivery_locations (delivery_location_id,customer_id,location_code,location_name,address_text)
values ('cb200000-0000-0000-0000-000000000011','cb200000-0000-0000-0000-000000000010','h0cb-correction-location','H0Cb correction location','Local fixture');
insert into atlas_admin.school_types (school_type_id,school_type_code,school_type_name)
values ('cb200000-0000-0000-0000-000000000012','h0cb-correction-type','H0Cb correction type');
insert into atlas_admin.schools (school_id,customer_id,school_code,school_name,school_type_id,default_delivery_location_id)
values ('cb200000-0000-0000-0000-000000000013','cb200000-0000-0000-0000-000000000010','h0cb-correction-school','H0Cb correction school','cb200000-0000-0000-0000-000000000012','cb200000-0000-0000-0000-000000000011');
insert into atlas_admin.units (unit_id,unit_code,unit_name,dimension_code)
values ('cb200000-0000-0000-0000-000000000014','h0cb-correction-kg','H0Cb kilogram','mass');
insert into atlas_admin.ingredients (ingredient_id,ingredient_code,ingredient_name) values
 ('cb200000-0000-0000-0000-000000000015','h0cb-correction-rice','H0Cb rice'),
 ('cb200000-0000-0000-0000-000000000016','h0cb-correction-salt','H0Cb salt'),
 ('cb200000-0000-0000-0000-000000000017','h0cb-correction-oil','H0Cb oil'),
 ('cb200000-0000-0000-0000-000000000018','h0cb-correction-beans','H0Cb beans'),
 ('cb200000-0000-0000-0000-000000000019','h0cb-correction-pepper','H0Cb pepper');

insert into atlas_planning.need_generation_runs (
 need_generation_run_id,planning_input_set_id,planning_input_evaluation_id,evaluation_version,
 period_start,period_end,attempt_ordinal,predecessor_need_generation_run_id,input_snapshot_id,
 run_status,version,generated_line_count,blocking_issue_count,warning_count,generated_by_actor_id,
 generated_at,validated_by_actor_id,validated_at,released_by_actor_id,released_at,
 invalidated_by_actor_id,invalidated_at,updated_at
) values
 ('cb200000-0000-0000-0000-000000000100','cb200000-0000-0000-0000-000000000101','cb200000-0000-0000-0000-000000000102',1,date '2026-07-22',date '2026-07-23',1,null,'cb200000-0000-0000-0000-000000000103','INVALIDATED',1,4,0,0,'cb200000-0000-0000-0000-000000000001',timestamptz '2026-07-22 07:00+07','cb200000-0000-0000-0000-000000000001',timestamptz '2026-07-22 07:01+07','cb200000-0000-0000-0000-000000000001',timestamptz '2026-07-22 07:02+07','cb200000-0000-0000-0000-000000000001',timestamptz '2026-07-22 09:00+07',timestamptz '2026-07-22 09:00+07'),
 ('cb200000-0000-0000-0000-000000000200','cb200000-0000-0000-0000-000000000101','cb200000-0000-0000-0000-000000000102',1,date '2026-07-22',date '2026-07-23',2,'cb200000-0000-0000-0000-000000000100','cb200000-0000-0000-0000-000000000203','RELEASED_FOR_CONFIRMATION',1,6,0,0,'cb200000-0000-0000-0000-000000000001',timestamptz '2026-07-22 10:00+07','cb200000-0000-0000-0000-000000000001',timestamptz '2026-07-22 10:01+07','cb200000-0000-0000-0000-000000000001',timestamptz '2026-07-22 10:02+07',null,null,timestamptz '2026-07-22 10:02+07');

insert into atlas_planning.need_generation_input_snapshots (
 need_generation_input_snapshot_id,need_generation_run_id,planning_input_set_id,planning_input_evaluation_id,
 evaluation_version,weekly_menu_id,weekly_menu_version,weekly_menu_approval_snapshot_id,
 attendance_batch_id,attendance_version,attendance_approval_snapshot_id,
 need_generation_calculation_contract_id,need_generation_calculation_contract_revision_id,
 calculation_contract_revision_number,captured_at
) values
 ('cb200000-0000-0000-0000-000000000103','cb200000-0000-0000-0000-000000000100','cb200000-0000-0000-0000-000000000101','cb200000-0000-0000-0000-000000000102',1,'cb200000-0000-0000-0000-000000000104',1,'cb200000-0000-0000-0000-000000000105','cb200000-0000-0000-0000-000000000106',1,'cb200000-0000-0000-0000-000000000107','cb200000-0000-0000-0000-000000000108','cb200000-0000-0000-0000-000000000109',1,timestamptz '2026-07-22 07:00+07'),
 ('cb200000-0000-0000-0000-000000000203','cb200000-0000-0000-0000-000000000200','cb200000-0000-0000-0000-000000000101','cb200000-0000-0000-0000-000000000102',1,'cb200000-0000-0000-0000-000000000104',1,'cb200000-0000-0000-0000-000000000105','cb200000-0000-0000-0000-000000000106',1,'cb200000-0000-0000-0000-000000000107','cb200000-0000-0000-0000-000000000108','cb200000-0000-0000-0000-000000000109',1,timestamptz '2026-07-22 10:00+07');

create temporary table h0cb_correction_source (
 ordinal integer primary key,run_id uuid not null,snapshot_id uuid not null,theoretical_id uuid not null,
 predecessor_run_id uuid,predecessor_id uuid,ingredient_id uuid not null,quantity numeric not null,
 service_date date not null,selection_id uuid default gen_random_uuid(),use_id uuid default gen_random_uuid(),
 menu_snapshot_line_id uuid default gen_random_uuid(),menu_line_id uuid default gen_random_uuid(),
 attendance_snapshot_line_id uuid default gen_random_uuid(),attendance_line_id uuid default gen_random_uuid(),
 recipe_line_id uuid default gen_random_uuid(),recipe_revision_id uuid default gen_random_uuid()
);
insert into h0cb_correction_source (ordinal,run_id,snapshot_id,theoretical_id,predecessor_run_id,predecessor_id,ingredient_id,quantity,service_date) values
 (1,'cb200000-0000-0000-0000-000000000100','cb200000-0000-0000-0000-000000000103','cb200000-0000-0000-0000-000000000301',null,null,'cb200000-0000-0000-0000-000000000015',10,date '2026-07-22'),
 (2,'cb200000-0000-0000-0000-000000000100','cb200000-0000-0000-0000-000000000103','cb200000-0000-0000-0000-000000000302',null,null,'cb200000-0000-0000-0000-000000000015',2,date '2026-07-22'),
 (3,'cb200000-0000-0000-0000-000000000100','cb200000-0000-0000-0000-000000000103','cb200000-0000-0000-0000-000000000303',null,null,'cb200000-0000-0000-0000-000000000016',4,date '2026-07-22'),
 (4,'cb200000-0000-0000-0000-000000000100','cb200000-0000-0000-0000-000000000103','cb200000-0000-0000-0000-000000000304',null,null,'cb200000-0000-0000-0000-000000000017',5,date '2026-07-22'),
 (5,'cb200000-0000-0000-0000-000000000200','cb200000-0000-0000-0000-000000000203','cb200000-0000-0000-0000-000000000401','cb200000-0000-0000-0000-000000000100','cb200000-0000-0000-0000-000000000301','cb200000-0000-0000-0000-000000000015',11,date '2026-07-22'),
 (6,'cb200000-0000-0000-0000-000000000200','cb200000-0000-0000-0000-000000000203','cb200000-0000-0000-0000-000000000402','cb200000-0000-0000-0000-000000000100','cb200000-0000-0000-0000-000000000302','cb200000-0000-0000-0000-000000000018',2,date '2026-07-22'),
 (7,'cb200000-0000-0000-0000-000000000200','cb200000-0000-0000-0000-000000000203','cb200000-0000-0000-0000-000000000403','cb200000-0000-0000-0000-000000000100','cb200000-0000-0000-0000-000000000303','cb200000-0000-0000-0000-000000000019',4,date '2026-07-22'),
 (8,'cb200000-0000-0000-0000-000000000200','cb200000-0000-0000-0000-000000000203','cb200000-0000-0000-0000-000000000404','cb200000-0000-0000-0000-000000000100','cb200000-0000-0000-0000-000000000304','cb200000-0000-0000-0000-000000000017',5,date '2026-07-22'),
 (9,'cb200000-0000-0000-0000-000000000200','cb200000-0000-0000-0000-000000000203','cb200000-0000-0000-0000-000000000405',null,null,'cb200000-0000-0000-0000-000000000015',3,date '2026-07-22'),
 (10,'cb200000-0000-0000-0000-000000000200','cb200000-0000-0000-0000-000000000203','cb200000-0000-0000-0000-000000000406',null,null,'cb200000-0000-0000-0000-000000000015',1,date '2026-07-23');

insert into atlas_planning.need_generation_recipe_selections (
 need_generation_recipe_selection_id,need_generation_input_snapshot_id,need_generation_run_id,
 weekly_menu_approval_snapshot_line_id,weekly_menu_approval_snapshot_id,weekly_menu_id,
 weekly_menu_version,weekly_menu_line_id,school_id,dish_id,recipe_id,recipe_version_id,
 recipe_version_number,selection_scope,selected_at
)
select selection_id,snapshot_id,run_id,menu_snapshot_line_id,'cb200000-0000-0000-0000-000000000105','cb200000-0000-0000-0000-000000000104',1,menu_line_id,'cb200000-0000-0000-0000-000000000013','cb200000-0000-0000-0000-000000000140','cb200000-0000-0000-0000-000000000141','cb200000-0000-0000-0000-000000000142',1,'GENERAL',timestamptz '2026-07-22 10:00+07'
from h0cb_correction_source;
insert into atlas_planning.need_generation_recipe_line_uses (
 need_generation_recipe_line_use_id,need_generation_input_snapshot_id,need_generation_run_id,
 need_generation_recipe_selection_id,recipe_id,recipe_version_id,recipe_line_id,recipe_line_revision_id,captured_at
)
select use_id,snapshot_id,run_id,selection_id,'cb200000-0000-0000-0000-000000000141','cb200000-0000-0000-0000-000000000142',recipe_line_id,recipe_revision_id,timestamptz '2026-07-22 10:00+07'
from h0cb_correction_source;
insert into atlas_planning.theoretical_need_lines (
 theoretical_need_line_id,need_generation_run_id,need_generation_input_snapshot_id,
 need_generation_recipe_selection_id,need_generation_recipe_line_use_id,
 weekly_menu_approval_snapshot_line_id,weekly_menu_approval_snapshot_id,weekly_menu_id,
 weekly_menu_version,weekly_menu_line_id,attendance_approval_snapshot_line_id,
 attendance_approval_snapshot_id,attendance_batch_id,attendance_version,attendance_line_id,
 school_id,service_date,dish_id,recipe_id,recipe_version_id,recipe_line_id,recipe_line_revision_id,
 ingredient_id,unit_id,need_generation_calculation_contract_id,
 need_generation_calculation_contract_revision_id,calculation_contract_revision_number,
 predecessor_need_generation_run_id,predecessor_theoretical_need_line_id,line_disposition,
 theoretical_quantity,created_at
)
select theoretical_id,run_id,snapshot_id,selection_id,use_id,menu_snapshot_line_id,
 'cb200000-0000-0000-0000-000000000105','cb200000-0000-0000-0000-000000000104',1,
 menu_line_id,attendance_snapshot_line_id,'cb200000-0000-0000-0000-000000000107',
 'cb200000-0000-0000-0000-000000000106',1,attendance_line_id,
 'cb200000-0000-0000-0000-000000000013',service_date,
 'cb200000-0000-0000-0000-000000000140','cb200000-0000-0000-0000-000000000141',
 'cb200000-0000-0000-0000-000000000142',recipe_line_id,recipe_revision_id,ingredient_id,
 'cb200000-0000-0000-0000-000000000014','cb200000-0000-0000-0000-000000000108',
 'cb200000-0000-0000-0000-000000000109',1,predecessor_run_id,predecessor_id,'ACTIVE',quantity,
 timestamptz '2026-07-22 10:00+07'
from h0cb_correction_source;

insert into atlas_planning.need_generation_release_snapshots (
 need_generation_release_snapshot_id,need_generation_run_id,released_run_version,
 need_generation_input_snapshot_id,released_by_actor_id,released_at,generated_line_count,
 active_line_count,removed_line_count,blocking_issue_count,warning_count
) values
 ('cb200000-0000-0000-0000-000000000190','cb200000-0000-0000-0000-000000000100',1,'cb200000-0000-0000-0000-000000000103','cb200000-0000-0000-0000-000000000001',timestamptz '2026-07-22 07:02+07',4,4,0,0,0),
 ('cb200000-0000-0000-0000-000000000290','cb200000-0000-0000-0000-000000000200',1,'cb200000-0000-0000-0000-000000000203','cb200000-0000-0000-0000-000000000001',timestamptz '2026-07-22 10:02+07',6,6,0,0,0);
insert into atlas_planning.need_generation_release_snapshot_lines (
 need_generation_release_snapshot_line_id,need_generation_release_snapshot_id,
 need_generation_run_id,released_run_version,theoretical_need_line_id
)
select gen_random_uuid(),case when ordinal<=4 then 'cb200000-0000-0000-0000-000000000190'::uuid else 'cb200000-0000-0000-0000-000000000290'::uuid end,run_id,1,theoretical_id
from h0cb_correction_source;

-- Exact old materialization, including a two-member rice group.
insert into atlas_planning.confirmed_need_batches (
 confirmed_need_batch_id,wholesale_order_id,period_start,period_end,batch_status,version,
 created_by_actor_id,source_kind,origin_need_generation_run_id,origin_need_generation_run_version,
 origin_need_generation_release_snapshot_id,current_need_generation_run_id,
 current_need_generation_run_version,current_need_generation_release_snapshot_id
) values ('cb200000-0000-0000-0000-000000000500',null,date '2026-07-22',date '2026-07-23','DRAFT_REVIEW',1,'cb200000-0000-0000-0000-000000000001','NEED_GENERATION','cb200000-0000-0000-0000-000000000100',1,'cb200000-0000-0000-0000-000000000190','cb200000-0000-0000-0000-000000000100',1,'cb200000-0000-0000-0000-000000000190');
insert into atlas_planning.confirmed_need_lines (
 confirmed_need_line_id,confirmed_need_batch_id,wholesale_order_line_id,source_kind,service_date,
 customer_id,school_id,delivery_location_id,ingredient_id,controlled_unit_id
) values
 ('cb200000-0000-0000-0000-000000000510','cb200000-0000-0000-0000-000000000500',null,'NEED_GENERATION',date '2026-07-22','cb200000-0000-0000-0000-000000000010','cb200000-0000-0000-0000-000000000013','cb200000-0000-0000-0000-000000000011','cb200000-0000-0000-0000-000000000015','cb200000-0000-0000-0000-000000000014'),
 ('cb200000-0000-0000-0000-000000000511','cb200000-0000-0000-0000-000000000500',null,'NEED_GENERATION',date '2026-07-22','cb200000-0000-0000-0000-000000000010','cb200000-0000-0000-0000-000000000013','cb200000-0000-0000-0000-000000000011','cb200000-0000-0000-0000-000000000016','cb200000-0000-0000-0000-000000000014'),
 ('cb200000-0000-0000-0000-000000000512','cb200000-0000-0000-0000-000000000500',null,'NEED_GENERATION',date '2026-07-22','cb200000-0000-0000-0000-000000000010','cb200000-0000-0000-0000-000000000013','cb200000-0000-0000-0000-000000000011','cb200000-0000-0000-0000-000000000017','cb200000-0000-0000-0000-000000000014');
insert into atlas_planning.confirmed_need_line_revisions (
 confirmed_need_line_revision_id,confirmed_need_line_id,revision_number,wholesale_order_line_revision_id,
 ingredient_id,theoretical_quantity,confirmed_quantity,unit_id,revision_status,is_current,
 created_by_actor_id,source_kind,confirmed_need_batch_id,need_generation_run_id,
 need_generation_run_version,need_generation_release_snapshot_id,service_date,customer_id,
 school_id,delivery_location_id
) values
 ('cb200000-0000-0000-0000-000000000520','cb200000-0000-0000-0000-000000000510',1,null,'cb200000-0000-0000-0000-000000000015',12,12,'cb200000-0000-0000-0000-000000000014','DRAFT',true,'cb200000-0000-0000-0000-000000000001','NEED_GENERATION','cb200000-0000-0000-0000-000000000500','cb200000-0000-0000-0000-000000000100',1,'cb200000-0000-0000-0000-000000000190',date '2026-07-22','cb200000-0000-0000-0000-000000000010','cb200000-0000-0000-0000-000000000013','cb200000-0000-0000-0000-000000000011'),
 ('cb200000-0000-0000-0000-000000000521','cb200000-0000-0000-0000-000000000511',1,null,'cb200000-0000-0000-0000-000000000016',4,4,'cb200000-0000-0000-0000-000000000014','DRAFT',true,'cb200000-0000-0000-0000-000000000001','NEED_GENERATION','cb200000-0000-0000-0000-000000000500','cb200000-0000-0000-0000-000000000100',1,'cb200000-0000-0000-0000-000000000190',date '2026-07-22','cb200000-0000-0000-0000-000000000010','cb200000-0000-0000-0000-000000000013','cb200000-0000-0000-0000-000000000011'),
 ('cb200000-0000-0000-0000-000000000522','cb200000-0000-0000-0000-000000000512',1,null,'cb200000-0000-0000-0000-000000000017',5,5,'cb200000-0000-0000-0000-000000000014','DRAFT',true,'cb200000-0000-0000-0000-000000000001','NEED_GENERATION','cb200000-0000-0000-0000-000000000500','cb200000-0000-0000-0000-000000000100',1,'cb200000-0000-0000-0000-000000000190',date '2026-07-22','cb200000-0000-0000-0000-000000000010','cb200000-0000-0000-0000-000000000013','cb200000-0000-0000-0000-000000000011');
insert into atlas_planning.confirmed_need_line_revision_contributions (
 confirmed_need_batch_id,confirmed_need_line_id,confirmed_need_line_revision_id,
 need_generation_run_id,need_generation_run_version,need_generation_release_snapshot_id,
 need_generation_release_snapshot_line_id,theoretical_need_line_id,service_date,customer_id,
 school_id,delivery_location_id,ingredient_id,source_unit_id,controlled_unit_id,
 source_theoretical_quantity,controlled_contribution_quantity
)
select 'cb200000-0000-0000-0000-000000000500',
 case when source.ordinal in (1,2) then 'cb200000-0000-0000-0000-000000000510'::uuid when source.ordinal=3 then 'cb200000-0000-0000-0000-000000000511'::uuid else 'cb200000-0000-0000-0000-000000000512'::uuid end,
 case when source.ordinal in (1,2) then 'cb200000-0000-0000-0000-000000000520'::uuid when source.ordinal=3 then 'cb200000-0000-0000-0000-000000000521'::uuid else 'cb200000-0000-0000-0000-000000000522'::uuid end,
 source.run_id,1,'cb200000-0000-0000-0000-000000000190',release_line.need_generation_release_snapshot_line_id,
 source.theoretical_id,source.service_date,'cb200000-0000-0000-0000-000000000010','cb200000-0000-0000-0000-000000000013','cb200000-0000-0000-0000-000000000011',source.ingredient_id,'cb200000-0000-0000-0000-000000000014','cb200000-0000-0000-0000-000000000014',source.quantity,source.quantity
from h0cb_correction_source source
join atlas_planning.need_generation_release_snapshot_lines release_line on release_line.theoretical_need_line_id=source.theoretical_id
where source.ordinal<=4;

set local session_replication_role = origin;

create temporary table h0cb_correction_results(result_name text primary key,response_payload jsonb not null);
grant select,insert on h0cb_correction_results to authenticated;
create function pg_temp.h0cb_correction_request(p_command uuid,p_key text,p_expected bigint,p_note text default 'correction')
returns jsonb language sql stable set search_path='' as $$
 select pg_catalog.jsonb_build_object(
  'contract_version','PA-06E-H0C.v1','command_id',p_command,
  'correlation_id','cb200000-0000-0000-0000-000000000901'::uuid,
  'idempotency_key',p_key,'expected_version',p_expected,
  'requested_by_auth_subject','cb200000-0000-0000-0000-000000000002'::uuid,
  'requested_at',pg_catalog.transaction_timestamp(),'reason_code','H0CB_CORRECTION_TEST',
  'reason_note',p_note,'payload',pg_catalog.jsonb_build_object(
   'need_generation_run_id','cb200000-0000-0000-0000-000000000200'::uuid,
   'need_generation_run_version',1,'confirmed_need_batch_id','cb200000-0000-0000-0000-000000000500'::uuid
  )
 )
$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','cb200000-0000-0000-0000-000000000002',true);
insert into h0cb_correction_results values ('corrected',atlas_api.create_confirmed_needs_from_generation(pg_temp.h0cb_correction_request('cb200000-0000-0000-0000-000000000900','h0cb-correction',1)));
insert into h0cb_correction_results values ('replay',atlas_api.create_confirmed_needs_from_generation(pg_temp.h0cb_correction_request('cb200000-0000-0000-0000-000000000900','h0cb-correction',1)));
insert into h0cb_correction_results values ('changed',atlas_api.create_confirmed_needs_from_generation(pg_temp.h0cb_correction_request('cb200000-0000-0000-0000-000000000900','h0cb-correction',1,'changed')));
reset role;

-- Response and one-step source advancement (1-25).
select is((select response_payload->>'success' from h0cb_correction_results where result_name='corrected'),'true','correction succeeds');
select is((select response_payload->>'idempotency_status' from h0cb_correction_results where result_name='corrected'),'COMPLETED','correction completes');
select is((select response_payload#>>'{affected_aggregate_ids,need_generation_run_id}' from h0cb_correction_results where result_name='corrected'),'cb200000-0000-0000-0000-000000000200','response identifies successor run');
select is((select response_payload#>>'{affected_aggregate_ids,confirmed_need_batch_id}' from h0cb_correction_results where result_name='corrected'),'cb200000-0000-0000-0000-000000000500','response identifies existing batch');
select is((select response_payload#>>'{new_versions,need_generation_run_version}' from h0cb_correction_results where result_name='corrected'),'1','response reports released source version');
select is((select response_payload#>>'{new_versions,confirmed_need_batch_version}' from h0cb_correction_results where result_name='corrected'),'2','batch advances exactly once');
select is((select response_payload#>>'{result_counts,created_confirmed_need_line_count}' from h0cb_correction_results where result_name='corrected'),'3','three new identities create lines');
select is((select response_payload#>>'{result_counts,reused_confirmed_need_line_count}' from h0cb_correction_results where result_name='corrected'),'2','two exact identities reuse lines');
select is((select response_payload#>>'{result_counts,retired_confirmed_need_line_count}' from h0cb_correction_results where result_name='corrected'),'1','one historical line is retired');
select is((select response_payload#>>'{result_counts,created_line_revision_count}' from h0cb_correction_results where result_name='corrected'),'5','every new group gets a revision');
select is((select response_payload#>>'{result_counts,created_revision_contribution_count}' from h0cb_correction_results where result_name='corrected'),'6','all six successor members are captured');
select is((select response_payload#>>'{result_counts,current_line_revision_count}' from h0cb_correction_results where result_name='corrected'),'5','five new revisions are current');
select is((select response_payload#>>'{result_counts,superseded_line_revision_count}' from h0cb_correction_results where result_name='corrected'),'3','three old current revisions are superseded');
select is((select count(*)::integer from jsonb_object_keys((select response_payload->'result_counts' from h0cb_correction_results where result_name='corrected'))),7,'correction returns exactly seven counts');
select is((select count(*)::integer from jsonb_object_keys((select response_payload->'affected_aggregate_ids' from h0cb_correction_results where result_name='corrected'))),2,'correction returns bounded aggregate IDs');
select is((select version from atlas_planning.confirmed_need_batches where confirmed_need_batch_id='cb200000-0000-0000-0000-000000000500'),2::bigint,'stored batch version is two');
select is((select current_need_generation_run_id from atlas_planning.confirmed_need_batches where confirmed_need_batch_id='cb200000-0000-0000-0000-000000000500'),'cb200000-0000-0000-0000-000000000200'::uuid,'batch advances to direct successor');
select is((select current_need_generation_run_version from atlas_planning.confirmed_need_batches where confirmed_need_batch_id='cb200000-0000-0000-0000-000000000500'),1::bigint,'batch stores successor version');
select is((select current_need_generation_release_snapshot_id from atlas_planning.confirmed_need_batches where confirmed_need_batch_id='cb200000-0000-0000-0000-000000000500'),'cb200000-0000-0000-0000-000000000290'::uuid,'batch stores successor release');
select is((select origin_need_generation_run_id from atlas_planning.confirmed_need_batches where confirmed_need_batch_id='cb200000-0000-0000-0000-000000000500'),'cb200000-0000-0000-0000-000000000100'::uuid,'origin run stays immutable');
select is((select origin_need_generation_release_snapshot_id from atlas_planning.confirmed_need_batches where confirmed_need_batch_id='cb200000-0000-0000-0000-000000000500'),'cb200000-0000-0000-0000-000000000190'::uuid,'origin release stays immutable');
select is((select batch_status from atlas_planning.confirmed_need_batches where confirmed_need_batch_id='cb200000-0000-0000-0000-000000000500'),'DRAFT_REVIEW','H0C does not reopen or advance lifecycle');
select is((select count(*)::integer from atlas_planning.confirmed_need_batches where confirmed_need_batch_id='cb200000-0000-0000-0000-000000000500'),1,'correction reuses one authoritative batch');

-- Stable identity reuse, new identities, retirement, and successor history (26-75).
select is((select count(*)::integer from atlas_planning.confirmed_need_lines where confirmed_need_batch_id='cb200000-0000-0000-0000-000000000500'),6,'three historical plus three new stable lines exist');
select ok(exists(select 1 from atlas_planning.confirmed_need_lines where confirmed_need_line_id='cb200000-0000-0000-0000-000000000510'),'rice stable line is reused');
select ok(exists(select 1 from atlas_planning.confirmed_need_lines where confirmed_need_line_id='cb200000-0000-0000-0000-000000000512'),'oil stable line is reused');
select is((select count(*)::integer from atlas_planning.confirmed_need_lines where ingredient_id='cb200000-0000-0000-0000-000000000018'),1,'Ingredient move creates beans identity');
select is((select count(*)::integer from atlas_planning.confirmed_need_lines where ingredient_id='cb200000-0000-0000-0000-000000000019'),1,'emptying move creates pepper identity');
select is((select count(*)::integer from atlas_planning.confirmed_need_lines where service_date=date '2026-07-23'),1,'genuinely new date creates identity');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions where confirmed_need_batch_id='cb200000-0000-0000-0000-000000000500'),8,'three old plus five successor revisions exist');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions where need_generation_run_id='cb200000-0000-0000-0000-000000000100'),3,'old revision set is retained');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions where need_generation_run_id='cb200000-0000-0000-0000-000000000200'),5,'successor has one revision per group');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions where is_current),5,'current partition has five revisions');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions where revision_status='SUPERSEDED'),3,'old current revisions become superseded');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions where need_generation_run_id='cb200000-0000-0000-0000-000000000100' and not is_current),3,'all old revisions are historical');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions where need_generation_run_id='cb200000-0000-0000-0000-000000000200' and revision_status='DRAFT'),5,'all successors are Draft');
select is((select revision_number from atlas_planning.confirmed_need_line_revisions where confirmed_need_line_id='cb200000-0000-0000-0000-000000000510' and is_current),2,'retained rice line advances to revision two');
select is((select revision_number from atlas_planning.confirmed_need_line_revisions where confirmed_need_line_id='cb200000-0000-0000-0000-000000000512' and is_current),2,'retained oil line advances to revision two');
select is((select predecessor_revision_id from atlas_planning.confirmed_need_line_revisions where confirmed_need_line_id='cb200000-0000-0000-0000-000000000510' and is_current),'cb200000-0000-0000-0000-000000000520'::uuid,'rice successor links exact predecessor');
select is((select predecessor_revision_id from atlas_planning.confirmed_need_line_revisions where confirmed_need_line_id='cb200000-0000-0000-0000-000000000512' and is_current),'cb200000-0000-0000-0000-000000000522'::uuid,'oil successor links exact predecessor');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions where confirmed_need_line_id='cb200000-0000-0000-0000-000000000511' and is_current),0,'emptied salt line has no current revision');
select is((select revision_status from atlas_planning.confirmed_need_line_revisions where confirmed_need_line_revision_id='cb200000-0000-0000-0000-000000000521'),'SUPERSEDED','retired salt history is superseded');
select isnt((select is_current from atlas_planning.confirmed_need_line_revisions where confirmed_need_line_revision_id='cb200000-0000-0000-0000-000000000521'),true,'retired salt history is not current');
select is((select theoretical_quantity from atlas_planning.confirmed_need_line_revisions where confirmed_need_line_id='cb200000-0000-0000-0000-000000000510' and is_current),14::numeric,'rice successor includes changed and new contribution');
select is((select confirmed_quantity from atlas_planning.confirmed_need_line_revisions where confirmed_need_line_id='cb200000-0000-0000-0000-000000000510' and is_current),14::numeric,'rice proposal resets to exact new total');
select is((select theoretical_quantity from atlas_planning.confirmed_need_line_revisions where confirmed_need_line_id='cb200000-0000-0000-0000-000000000512' and is_current),5::numeric,'unchanged oil still receives successor revision');
select is((select confirmed_quantity from atlas_planning.confirmed_need_line_revisions where confirmed_need_line_id='cb200000-0000-0000-0000-000000000512' and is_current),5::numeric,'unchanged oil proposal is recreated');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions where ingredient_id='cb200000-0000-0000-0000-000000000018' and is_current),1,'beans move has current revision');
select is((select theoretical_quantity from atlas_planning.confirmed_need_line_revisions where ingredient_id='cb200000-0000-0000-0000-000000000018' and is_current),2::numeric,'beans move retains exact quantity');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions where ingredient_id='cb200000-0000-0000-0000-000000000019' and is_current),1,'pepper move has current revision');
select is((select theoretical_quantity from atlas_planning.confirmed_need_line_revisions where ingredient_id='cb200000-0000-0000-0000-000000000019' and is_current),4::numeric,'pepper move retains exact quantity');
select is((select theoretical_quantity from atlas_planning.confirmed_need_line_revisions where service_date=date '2026-07-23' and is_current),1::numeric,'new date identity has exact quantity');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revision_contributions),10,'four historical and six current memberships coexist');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revision_contributions where need_generation_run_id='cb200000-0000-0000-0000-000000000100'),4,'historical membership remains complete');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revision_contributions where need_generation_run_id='cb200000-0000-0000-0000-000000000200'),6,'new membership is complete');
select is((select count(distinct theoretical_need_line_id)::integer from atlas_planning.confirmed_need_line_revision_contributions where need_generation_run_id='cb200000-0000-0000-0000-000000000200'),6,'each new source line appears once');
select is((select count(distinct need_generation_release_snapshot_line_id)::integer from atlas_planning.confirmed_need_line_revision_contributions where need_generation_run_id='cb200000-0000-0000-0000-000000000200'),6,'each new release member appears once');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revision_contributions c join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_revision_id) where r.is_current),6,'all current memberships attach to current revisions');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions r where r.is_current and r.theoretical_quantity=(select sum(c.controlled_contribution_quantity) from atlas_planning.confirmed_need_line_revision_contributions c where c.confirmed_need_line_revision_id=r.confirmed_need_line_revision_id)),5,'every current total equals complete membership');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions r where r.is_current and r.confirmed_quantity=r.theoretical_quantity),5,'every new proposal equals theory');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revision_contributions where theoretical_need_line_id='cb200000-0000-0000-0000-000000000402' and ingredient_id='cb200000-0000-0000-0000-000000000018'),1,'first one-to-one Ingredient move is explicit');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revision_contributions where theoretical_need_line_id='cb200000-0000-0000-0000-000000000403' and ingredient_id='cb200000-0000-0000-0000-000000000019'),1,'emptying Ingredient move is explicit');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revision_contributions where theoretical_need_line_id='cb200000-0000-0000-0000-000000000405' and ingredient_id='cb200000-0000-0000-0000-000000000015'),1,'new same-Ingredient contribution joins rice');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revision_contributions where theoretical_need_line_id='cb200000-0000-0000-0000-000000000406' and service_date=date '2026-07-23'),1,'new operational identity is captured');
select is((select theoretical_quantity from atlas_planning.confirmed_need_line_revisions where confirmed_need_line_revision_id='cb200000-0000-0000-0000-000000000520'),12::numeric,'historical rice total is immutable');
select is((select confirmed_quantity from atlas_planning.confirmed_need_line_revisions where confirmed_need_line_revision_id='cb200000-0000-0000-0000-000000000520'),12::numeric,'historical rice proposal is immutable');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revision_contributions where confirmed_need_line_revision_id='cb200000-0000-0000-0000-000000000520'),2,'historical rice membership is immutable');
select is((select sum(controlled_contribution_quantity) from atlas_planning.confirmed_need_line_revision_contributions where confirmed_need_line_revision_id='cb200000-0000-0000-0000-000000000520'),12::numeric,'historical rice membership total is immutable');
select is((select count(*)::integer from atlas_planning.confirmed_need_lines where delivery_location_id='cb200000-0000-0000-0000-000000000011'),6,'all identities retain captured destination');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions where delivery_location_id='cb200000-0000-0000-0000-000000000011'),8,'all revisions retain destination identity');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revision_contributions where delivery_location_id='cb200000-0000-0000-0000-000000000011'),10,'all memberships retain destination identity');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revision_contributions where source_unit_id=controlled_unit_id),10,'history and successors preserve no conversion');
select is((select count(*)::integer from atlas_planning.confirmed_need_approval_snapshots),0,'correction creates no approval');
select is((select count(*)::integer from atlas_planning.purchase_handoff_batches),0,'correction creates no downstream fact');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions where command_id='cb200000-0000-0000-0000-000000000900'),5,'one command owns all successor revisions');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions where need_generation_release_snapshot_id='cb200000-0000-0000-0000-000000000290' and is_current),5,'current revisions all bind exact new release');

-- Event/audit/receipt/replay and immutable partition certainty (76-104).
select is((select count(*)::integer from atlas_core.command_receipts where command_name='create_confirmed_needs_from_generation'),1,'one correction receipt exists');
select is((select outcome from atlas_core.command_receipts where command_name='create_confirmed_needs_from_generation'),'COMPLETED','correction receipt completes');
select is((select expected_version from atlas_core.command_receipts where command_name='create_confirmed_needs_from_generation'),1::bigint,'receipt stores expected batch version');
select is((select count(*)::integer from atlas_audit.domain_events where event_type='ConfirmedNeedsRematerialized'),1,'one rematerialization event exists');
select is((select aggregate_id from atlas_audit.domain_events where event_type='ConfirmedNeedsRematerialized'),'cb200000-0000-0000-0000-000000000500'::uuid,'event aggregate is the batch');
select is((select aggregate_version from atlas_audit.domain_events where event_type='ConfirmedNeedsRematerialized'),2::bigint,'event version is two');
select is((select payload_summary->>'need_generation_run_id' from atlas_audit.domain_events where event_type='ConfirmedNeedsRematerialized'),'cb200000-0000-0000-0000-000000000200','event names exact successor');
select is((select payload_summary->>'need_generation_release_snapshot_id' from atlas_audit.domain_events where event_type='ConfirmedNeedsRematerialized'),'cb200000-0000-0000-0000-000000000290','event names exact release');
select is((select payload_summary#>>'{result_counts,retired_confirmed_need_line_count}' from atlas_audit.domain_events where event_type='ConfirmedNeedsRematerialized'),'1','event records retirement count');
select isnt((select payload_summary ? 'membership_ids' from atlas_audit.domain_events where event_type='ConfirmedNeedsRematerialized'),true,'event has no membership IDs');
select is((select count(*)::integer from atlas_audit.audit_events where event_type='ConfirmedNeedsRematerialized'),1,'one rematerialization audit exists');
select is((select aggregate_version_before from atlas_audit.audit_events where event_type='ConfirmedNeedsRematerialized'),1::bigint,'audit before version is one');
select is((select aggregate_version_after from atlas_audit.audit_events where event_type='ConfirmedNeedsRematerialized'),2::bigint,'audit after version is two');
select is((select before_summary#>>'{current_source,need_generation_run_id}' from atlas_audit.audit_events where event_type='ConfirmedNeedsRematerialized'),'cb200000-0000-0000-0000-000000000100','audit before names old source');
select is((select after_summary#>>'{current_source,need_generation_run_id}' from atlas_audit.audit_events where event_type='ConfirmedNeedsRematerialized'),'cb200000-0000-0000-0000-000000000200','audit after names new source');
select is((select after_summary#>>'{result_counts,created_line_revision_count}' from atlas_audit.audit_events where event_type='ConfirmedNeedsRematerialized'),'5','audit contains bounded revision count');
select is((select response_payload from h0cb_correction_results where result_name='replay'),(select response_payload from h0cb_correction_results where result_name='corrected'),'exact correction replay returns stored response');
select is((select response_payload->>'error_code' from h0cb_correction_results where result_name='changed'),'IDEMPOTENCY_CONFLICT','changed correction reuse conflicts');
select is((select response_payload->>'retryable' from h0cb_correction_results where result_name='changed'),'false','changed correction reuse is nonretryable');
select is((select count(*)::integer from atlas_audit.domain_events where event_type='ConfirmedNeedsRematerialized'),1,'replay emits no event');
select is((select count(*)::integer from atlas_audit.audit_events where event_type='ConfirmedNeedsRematerialized'),1,'replay emits no audit');
select is((select version from atlas_planning.confirmed_need_batches where confirmed_need_batch_id='cb200000-0000-0000-0000-000000000500'),2::bigint,'replay does not increment batch again');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions where is_current),5,'replay preserves current partition');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions where revision_status='SUPERSEDED'),3,'replay preserves superseded partition');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revision_contributions),10,'replay preserves immutable memberships');
select is((select count(*)::integer from atlas_planning.confirmed_need_lines l where l.confirmed_need_batch_id='cb200000-0000-0000-0000-000000000500' and not exists(select 1 from atlas_planning.confirmed_need_line_revisions r where r.confirmed_need_line_id=l.confirmed_need_line_id and r.is_current)),1,'exactly one historical line is intentionally retired');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions r where r.is_current and r.need_generation_run_id='cb200000-0000-0000-0000-000000000200'),5,'every current revision belongs to controlled current run');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revision_contributions c join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_revision_id) where r.is_current and c.need_generation_release_snapshot_id='cb200000-0000-0000-0000-000000000290'),6,'current membership exactly partitions new active release');

select * from finish();
rollback;
