begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
select plan(112);

set local session_replication_role = replica;

insert into atlas_admin.customers (customer_id,customer_code,customer_name,customer_type) values
 ('cb300000-0000-0000-0000-000000000010','h0cb-error-customer-a','H0Cb error customer A','SCHOOL_CATERING'),
 ('cb300000-0000-0000-0000-000000000020','h0cb-error-customer-b','H0Cb error customer B','SCHOOL_CATERING');
insert into atlas_admin.delivery_locations (delivery_location_id,customer_id,location_code,location_name,address_text) values
 ('cb300000-0000-0000-0000-000000000011','cb300000-0000-0000-0000-000000000010','h0cb-error-location-a','H0Cb location A','Local fixture'),
 ('cb300000-0000-0000-0000-000000000012','cb300000-0000-0000-0000-000000000010','h0cb-error-location-a2','H0Cb location A2','Local fixture'),
 ('cb300000-0000-0000-0000-000000000021','cb300000-0000-0000-0000-000000000020','h0cb-error-location-b','H0Cb location B','Local fixture');
insert into atlas_admin.school_types (school_type_id,school_type_code,school_type_name)
values ('cb300000-0000-0000-0000-000000000030','h0cb-error-type','H0Cb error type');
insert into atlas_admin.schools (school_id,customer_id,school_code,school_name,school_type_id,default_delivery_location_id) values
 ('cb300000-0000-0000-0000-000000000013','cb300000-0000-0000-0000-000000000010','h0cb-error-school-a','H0Cb school A','cb300000-0000-0000-0000-000000000030','cb300000-0000-0000-0000-000000000011'),
 ('cb300000-0000-0000-0000-000000000023','cb300000-0000-0000-0000-000000000020','h0cb-error-school-b','H0Cb school B','cb300000-0000-0000-0000-000000000030','cb300000-0000-0000-0000-000000000021');
insert into atlas_admin.units (unit_id,unit_code,unit_name,dimension_code) values
 ('cb300000-0000-0000-0000-000000000014','h0cb-error-kg','H0Cb kg','mass'),
 ('cb300000-0000-0000-0000-000000000024','h0cb-error-g','H0Cb gram','mass');
insert into atlas_admin.ingredients (ingredient_id,ingredient_code,ingredient_name)
values ('cb300000-0000-0000-0000-000000000015','h0cb-error-rice','H0Cb rice');

insert into atlas_core.actors (actor_id,actor_type,display_name,actor_status,deactivated_at) values
 ('cb300000-0000-0000-0000-000000000001','HUMAN','Global planner','ACTIVE',null),
 ('cb300000-0000-0000-0000-000000000002','HUMAN','Customer planner','ACTIVE',null),
 ('cb300000-0000-0000-0000-000000000003','HUMAN','School planner','ACTIVE',null),
 ('cb300000-0000-0000-0000-000000000004','HUMAN','Location planner','ACTIVE',null),
 ('cb300000-0000-0000-0000-000000000005','HUMAN','Unscoped planner','ACTIVE',null),
 ('cb300000-0000-0000-0000-000000000006','HUMAN','No capability planner','ACTIVE',null),
 ('cb300000-0000-0000-0000-000000000007','INTEGRATION','Integration planner','ACTIVE',null),
 ('cb300000-0000-0000-0000-000000000008','HUMAN','Inactive planner','INACTIVE',timestamptz '2026-07-22 05:00+07'),
 ('cb300000-0000-0000-0000-000000000009','HUMAN','Inactive subject planner','ACTIVE',null);
insert into atlas_core.actor_auth_subjects (actor_id,auth_subject_id,subject_status,revoked_at)
select actor_id,('cb300000-0000-0000-0000-'||lpad((100+row_number() over(order by actor_id))::text,12,'0'))::uuid,
       case when actor_id='cb300000-0000-0000-0000-000000000009'::uuid then 'REVOKED' else 'ACTIVE' end,
       case when actor_id='cb300000-0000-0000-0000-000000000009'::uuid then timestamptz '2026-07-22 05:00+07' end
from atlas_core.actors where actor_id::text like 'cb300000%';
insert into atlas_core.roles (role_id,role_code,role_name)
values ('cb300000-0000-0000-0000-000000000040','h0cb.error.capable','H0Cb capable role');
insert into atlas_core.role_capabilities (role_id,capability_id)
select 'cb300000-0000-0000-0000-000000000040',capability_id from atlas_core.capabilities where capability_code='confirmed_need_generation.materialize';
insert into atlas_core.actor_role_memberships (actor_id,role_id)
select actor_id,'cb300000-0000-0000-0000-000000000040' from atlas_core.actors
where actor_id::text like 'cb300000%' and actor_id<>'cb300000-0000-0000-0000-000000000006';
insert into atlas_core.actor_scopes (actor_id,scope_kind,customer_id,school_id,delivery_location_id) values
 ('cb300000-0000-0000-0000-000000000001','GLOBAL',null,null,null),
 ('cb300000-0000-0000-0000-000000000002','CUSTOMER','cb300000-0000-0000-0000-000000000010',null,null),
 ('cb300000-0000-0000-0000-000000000003','SCHOOL',null,'cb300000-0000-0000-0000-000000000013',null),
 ('cb300000-0000-0000-0000-000000000004','DELIVERY_LOCATION',null,null,'cb300000-0000-0000-0000-000000000011'),
 ('cb300000-0000-0000-0000-000000000006','GLOBAL',null,null,null),
 ('cb300000-0000-0000-0000-000000000007','GLOBAL',null,null,null),
 ('cb300000-0000-0000-0000-000000000008','GLOBAL',null,null,null),
 ('cb300000-0000-0000-0000-000000000009','GLOBAL',null,null,null);

create function pg_temp.h0cb_error_source(
 p_run uuid,p_snapshot uuid,p_release uuid,p_line uuid,p_school uuid,p_start date,p_end date,
 p_status text,p_quantity numeric,p_disposition text,p_predecessor_run uuid default null,
 p_predecessor_line uuid default null
) returns void language plpgsql as $$
declare v_selection uuid:=gen_random_uuid(); v_use uuid:=gen_random_uuid();
begin
 insert into atlas_planning.need_generation_runs (
  need_generation_run_id,planning_input_set_id,planning_input_evaluation_id,evaluation_version,
  period_start,period_end,attempt_ordinal,predecessor_need_generation_run_id,input_snapshot_id,
  run_status,version,generated_line_count,blocking_issue_count,warning_count,generated_by_actor_id,
  generated_at,validated_by_actor_id,validated_at,released_by_actor_id,released_at,updated_at
 ) values (p_run,gen_random_uuid(),gen_random_uuid(),1,p_start,p_end,case when p_predecessor_run is null then 1 else 2 end,
  p_predecessor_run,p_snapshot,p_status,1,1,0,0,'cb300000-0000-0000-0000-000000000001',
  timestamptz '2026-07-22 06:00+07',case when p_status='RELEASED_FOR_CONFIRMATION' then 'cb300000-0000-0000-0000-000000000001'::uuid end,
  case when p_status='RELEASED_FOR_CONFIRMATION' then timestamptz '2026-07-22 06:01+07' end,
  case when p_status='RELEASED_FOR_CONFIRMATION' then 'cb300000-0000-0000-0000-000000000001'::uuid end,
  case when p_status='RELEASED_FOR_CONFIRMATION' then timestamptz '2026-07-22 06:02+07' end,
  timestamptz '2026-07-22 06:02+07');
 insert into atlas_planning.need_generation_input_snapshots (
  need_generation_input_snapshot_id,need_generation_run_id,planning_input_set_id,planning_input_evaluation_id,evaluation_version,
  weekly_menu_id,weekly_menu_version,weekly_menu_approval_snapshot_id,attendance_batch_id,attendance_version,
  attendance_approval_snapshot_id,need_generation_calculation_contract_id,
  need_generation_calculation_contract_revision_id,calculation_contract_revision_number,captured_at
 ) select p_snapshot,p_run,planning_input_set_id,planning_input_evaluation_id,1,gen_random_uuid(),1,gen_random_uuid(),gen_random_uuid(),1,gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),1,timestamptz '2026-07-22 06:00+07'
   from atlas_planning.need_generation_runs where need_generation_run_id=p_run;
 insert into atlas_planning.need_generation_recipe_selections (
  need_generation_recipe_selection_id,need_generation_input_snapshot_id,need_generation_run_id,
  weekly_menu_approval_snapshot_line_id,weekly_menu_approval_snapshot_id,weekly_menu_id,weekly_menu_version,
  weekly_menu_line_id,school_id,dish_id,recipe_id,recipe_version_id,recipe_version_number,selection_scope,selected_at
 ) select v_selection,p_snapshot,p_run,gen_random_uuid(),weekly_menu_approval_snapshot_id,weekly_menu_id,1,gen_random_uuid(),p_school,gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),1,'GENERAL',timestamptz '2026-07-22 06:00+07'
   from atlas_planning.need_generation_input_snapshots where need_generation_input_snapshot_id=p_snapshot;
 insert into atlas_planning.need_generation_recipe_line_uses (
  need_generation_recipe_line_use_id,need_generation_input_snapshot_id,need_generation_run_id,
  need_generation_recipe_selection_id,recipe_id,recipe_version_id,recipe_line_id,recipe_line_revision_id,captured_at
 ) values (v_use,p_snapshot,p_run,v_selection,gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),timestamptz '2026-07-22 06:00+07');
 insert into atlas_planning.theoretical_need_lines (
  theoretical_need_line_id,need_generation_run_id,need_generation_input_snapshot_id,
  need_generation_recipe_selection_id,need_generation_recipe_line_use_id,
  weekly_menu_approval_snapshot_line_id,weekly_menu_approval_snapshot_id,weekly_menu_id,weekly_menu_version,
  weekly_menu_line_id,attendance_approval_snapshot_line_id,attendance_approval_snapshot_id,
  attendance_batch_id,attendance_version,attendance_line_id,school_id,service_date,dish_id,recipe_id,
  recipe_version_id,recipe_line_id,recipe_line_revision_id,ingredient_id,unit_id,
  need_generation_calculation_contract_id,need_generation_calculation_contract_revision_id,
  calculation_contract_revision_number,predecessor_need_generation_run_id,
  predecessor_theoretical_need_line_id,line_disposition,theoretical_quantity,created_at
 ) values (p_line,p_run,p_snapshot,v_selection,v_use,gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),1,
  gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),1,gen_random_uuid(),p_school,p_start,
  gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),
  'cb300000-0000-0000-0000-000000000015','cb300000-0000-0000-0000-000000000014',
  gen_random_uuid(),gen_random_uuid(),1,p_predecessor_run,p_predecessor_line,p_disposition,p_quantity,
  timestamptz '2026-07-22 06:00+07');
 insert into atlas_planning.need_generation_release_snapshots (
  need_generation_release_snapshot_id,need_generation_run_id,released_run_version,
  need_generation_input_snapshot_id,released_by_actor_id,released_at,generated_line_count,
  active_line_count,removed_line_count,blocking_issue_count,warning_count
 ) values (p_release,p_run,1,p_snapshot,'cb300000-0000-0000-0000-000000000001',timestamptz '2026-07-22 06:02+07',1,
  case when p_disposition='ACTIVE' then 1 else 0 end,case when p_disposition='REMOVED' then 1 else 0 end,0,0);
 insert into atlas_planning.need_generation_release_snapshot_lines (
  need_generation_release_snapshot_line_id,need_generation_release_snapshot_id,
  need_generation_run_id,released_run_version,theoretical_need_line_id
 ) values (gen_random_uuid(),p_release,p_run,1,p_line);
end $$;

select pg_temp.h0cb_error_source('cb300000-0000-0000-0000-000000001000','cb300000-0000-0000-0000-000000001001','cb300000-0000-0000-0000-000000001002','cb300000-0000-0000-0000-000000001003','cb300000-0000-0000-0000-000000000013',date '2026-07-22',date '2026-07-22','RELEASED_FOR_CONFIRMATION',10,'ACTIVE');
select pg_temp.h0cb_error_source('cb300000-0000-0000-0000-000000001100','cb300000-0000-0000-0000-000000001101','cb300000-0000-0000-0000-000000001102','cb300000-0000-0000-0000-000000001103','cb300000-0000-0000-0000-000000000013',date '2026-07-22',date '2026-07-22','RELEASED_FOR_CONFIRMATION',10,'ACTIVE');
select pg_temp.h0cb_error_source('cb300000-0000-0000-0000-000000001200','cb300000-0000-0000-0000-000000001201','cb300000-0000-0000-0000-000000001202','cb300000-0000-0000-0000-000000001203','cb300000-0000-0000-0000-000000000013',date '2026-07-22',date '2026-07-22','RELEASED_FOR_CONFIRMATION',10,'ACTIVE');
select pg_temp.h0cb_error_source('cb300000-0000-0000-0000-000000001300','cb300000-0000-0000-0000-000000001301','cb300000-0000-0000-0000-000000001302','cb300000-0000-0000-0000-000000001303','cb300000-0000-0000-0000-000000000013',date '2026-07-22',date '2026-07-22','RELEASED_FOR_CONFIRMATION',10,'ACTIVE');
select pg_temp.h0cb_error_source('cb300000-0000-0000-0000-000000001400','cb300000-0000-0000-0000-000000001401','cb300000-0000-0000-0000-000000001402','cb300000-0000-0000-0000-000000001403','cb300000-0000-0000-0000-000000000013',date '2026-07-22',date '2026-07-22','RELEASED_FOR_CONFIRMATION',10,'ACTIVE');
select pg_temp.h0cb_error_source('cb300000-0000-0000-0000-000000001500','cb300000-0000-0000-0000-000000001501','cb300000-0000-0000-0000-000000001502','cb300000-0000-0000-0000-000000001503','cb300000-0000-0000-0000-000000000013',date '2026-07-22',date '2026-07-22','RELEASED_FOR_CONFIRMATION',0,'REMOVED','cb300000-0000-0000-0000-000000001800','cb300000-0000-0000-0000-000000001803');
select pg_temp.h0cb_error_source('cb300000-0000-0000-0000-000000001600','cb300000-0000-0000-0000-000000001601','cb300000-0000-0000-0000-000000001602','cb300000-0000-0000-0000-000000001603','cb300000-0000-0000-0000-000000000013',date '2026-07-22',date '2026-07-22','RELEASED_FOR_CONFIRMATION',0,'ACTIVE');
select pg_temp.h0cb_error_source('cb300000-0000-0000-0000-000000001700','cb300000-0000-0000-0000-000000001701','cb300000-0000-0000-0000-000000001702','cb300000-0000-0000-0000-000000001703','cb300000-0000-0000-0000-000000000013',date '2026-07-01',date '2026-07-15','RELEASED_FOR_CONFIRMATION',10,'ACTIVE');
select pg_temp.h0cb_error_source('cb300000-0000-0000-0000-000000001800','cb300000-0000-0000-0000-000000001801','cb300000-0000-0000-0000-000000001802','cb300000-0000-0000-0000-000000001803','cb300000-0000-0000-0000-000000000013',date '2026-07-22',date '2026-07-22','GENERATED',10,'ACTIVE');
select pg_temp.h0cb_error_source('cb300000-0000-0000-0000-000000001900','cb300000-0000-0000-0000-000000001901','cb300000-0000-0000-0000-000000001902','cb300000-0000-0000-0000-000000001903','cb300000-0000-0000-0000-000000000013',date '2026-07-22',date '2026-07-22','RELEASED_FOR_CONFIRMATION',10,'ACTIVE');
select pg_temp.h0cb_error_source('cb300000-0000-0000-0000-000000002000','cb300000-0000-0000-0000-000000002001','cb300000-0000-0000-0000-000000002002','cb300000-0000-0000-0000-000000002003','cb300000-0000-0000-0000-000000000023',date '2026-07-22',date '2026-07-22','RELEASED_FOR_CONFIRMATION',10,'ACTIVE');
select pg_temp.h0cb_error_source('cb300000-0000-0000-0000-000000002100','cb300000-0000-0000-0000-000000002101','cb300000-0000-0000-0000-000000002102','cb300000-0000-0000-0000-000000002103','cb300000-0000-0000-0000-000000000013',date '2026-07-22',date '2026-07-22','RELEASED_FOR_CONFIRMATION',10,'ACTIVE','cb300000-0000-0000-0000-000000001000','cb300000-0000-0000-0000-000000001003');

update atlas_planning.need_generation_runs successor
set planning_input_set_id=predecessor.planning_input_set_id,
    planning_input_evaluation_id=predecessor.planning_input_evaluation_id,
    evaluation_version=predecessor.evaluation_version
from atlas_planning.need_generation_runs predecessor
where successor.need_generation_run_id='cb300000-0000-0000-0000-000000002100'
  and predecessor.need_generation_run_id='cb300000-0000-0000-0000-000000001000';
update atlas_planning.need_generation_input_snapshots successor_snapshot
set planning_input_set_id=predecessor_snapshot.planning_input_set_id,
    planning_input_evaluation_id=predecessor_snapshot.planning_input_evaluation_id,
    evaluation_version=predecessor_snapshot.evaluation_version
from atlas_planning.need_generation_input_snapshots predecessor_snapshot
where successor_snapshot.need_generation_input_snapshot_id='cb300000-0000-0000-0000-000000002101'
  and predecessor_snapshot.need_generation_input_snapshot_id='cb300000-0000-0000-0000-000000001001';

set local session_replication_role = origin;

create function pg_temp.h0cb_error_request(
 p_run uuid,p_command uuid,p_key text,p_subject uuid,p_version bigint default 1,
 p_batch uuid default null,p_expected bigint default 1
) returns jsonb language sql stable set search_path='' as $$
 select pg_catalog.jsonb_build_object(
  'contract_version','PA-06E-H0C.v1','command_id',p_command,
  'correlation_id','cb300000-0000-0000-0000-000000009999'::uuid,
  'idempotency_key',p_key,'expected_version',p_expected,
  'requested_by_auth_subject',p_subject,'requested_at',pg_catalog.transaction_timestamp(),
  'reason_code','H0CB_ERROR_TEST','reason_note','error fixture','payload',pg_catalog.jsonb_build_object(
   'need_generation_run_id',p_run,'need_generation_run_version',p_version,'confirmed_need_batch_id',p_batch
  )
 )
$$;

-- Validator exactness (1-24).
select is(atlas_core.pa_06e_h0cb_validate_materialization_request(null)->>'error_code','VALIDATION_FAILED','null request fails');
select is(atlas_core.pa_06e_h0cb_validate_materialization_request('[]'::jsonb)->>'error_code','VALIDATION_FAILED','array request fails');
select is(atlas_core.pa_06e_h0cb_validate_materialization_request('{}'::jsonb)->>'error_code','VALIDATION_FAILED','empty object fails');
select is((atlas_core.pa_06e_h0cb_validate_materialization_request(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000001000','cb300000-0000-0000-0000-000000008001','validator-1','cb300000-0000-0000-0000-000000000101')||jsonb_build_object('unknown',1)))->>'error_code','VALIDATION_FAILED','unknown envelope field fails');
select is(atlas_core.pa_06e_h0cb_validate_materialization_request(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000001000','cb300000-0000-0000-0000-000000008002','validator-2','cb300000-0000-0000-0000-000000000101')- 'reason_code')->>'error_code','VALIDATION_FAILED','missing envelope field fails');
select is(atlas_core.pa_06e_h0cb_validate_materialization_request(jsonb_set(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000001000','cb300000-0000-0000-0000-000000008003','validator-3','cb300000-0000-0000-0000-000000000101'),'{contract_version}','"wrong"'))->>'error_code','VALIDATION_FAILED','wrong contract fails');
select is(atlas_core.pa_06e_h0cb_validate_materialization_request(jsonb_set(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000001000','cb300000-0000-0000-0000-000000008004','validator-4','cb300000-0000-0000-0000-000000000101'),'{command_id}','"bad"'))->>'error_code','VALIDATION_FAILED','bad command UUID fails');
select is(atlas_core.pa_06e_h0cb_validate_materialization_request(jsonb_set(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000001000','cb300000-0000-0000-0000-000000008005','validator-5','cb300000-0000-0000-0000-000000000101'),'{correlation_id}','"bad"'))->>'error_code','VALIDATION_FAILED','bad correlation UUID fails');
select is(atlas_core.pa_06e_h0cb_validate_materialization_request(jsonb_set(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000001000','cb300000-0000-0000-0000-000000008006','validator-6','cb300000-0000-0000-0000-000000000101'),'{idempotency_key}','""'))->>'error_code','VALIDATION_FAILED','empty idempotency key fails');
select is(atlas_core.pa_06e_h0cb_validate_materialization_request(jsonb_set(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000001000','cb300000-0000-0000-0000-000000008007','validator-7','cb300000-0000-0000-0000-000000000101'),'{idempotency_key}',to_jsonb(repeat('x',201))))->>'error_code','VALIDATION_FAILED','oversized idempotency key fails');
select is(atlas_core.pa_06e_h0cb_validate_materialization_request(jsonb_set(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000001000','cb300000-0000-0000-0000-000000008008','validator-8','cb300000-0000-0000-0000-000000000101'),'{expected_version}','0'))->>'error_code','VALIDATION_FAILED','nonpositive expected version fails');
select is(atlas_core.pa_06e_h0cb_validate_materialization_request(jsonb_set(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000001000','cb300000-0000-0000-0000-000000008009','validator-9','cb300000-0000-0000-0000-000000000101'),'{requested_by_auth_subject}','"bad"'))->>'error_code','VALIDATION_FAILED','bad subject UUID fails');
select is(atlas_core.pa_06e_h0cb_validate_materialization_request(jsonb_set(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000001000','cb300000-0000-0000-0000-000000008010','validator-10','cb300000-0000-0000-0000-000000000101'),'{requested_at}',to_jsonb(pg_catalog.transaction_timestamp()+interval '1 hour')))->>'error_code','VALIDATION_FAILED','future request time fails');
select is(atlas_core.pa_06e_h0cb_validate_materialization_request(jsonb_set(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000001000','cb300000-0000-0000-0000-000000008011','validator-11','cb300000-0000-0000-0000-000000000101'),'{reason_code}','""'))->>'error_code','VALIDATION_FAILED','empty reason code fails');
select is(atlas_core.pa_06e_h0cb_validate_materialization_request(jsonb_set(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000001000','cb300000-0000-0000-0000-000000008012','validator-12','cb300000-0000-0000-0000-000000000101'),'{reason_note}','{}'))->>'error_code','VALIDATION_FAILED','object reason note fails');
select is(atlas_core.pa_06e_h0cb_validate_materialization_request(jsonb_set(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000001000','cb300000-0000-0000-0000-000000008013','validator-13','cb300000-0000-0000-0000-000000000101'),'{payload}','[]'))->>'error_code','VALIDATION_FAILED','array payload fails');
select is(atlas_core.pa_06e_h0cb_validate_materialization_request(jsonb_set(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000001000','cb300000-0000-0000-0000-000000008014','validator-14','cb300000-0000-0000-0000-000000000101'),'{payload}',(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000001000','cb300000-0000-0000-0000-000000008014','validator-14','cb300000-0000-0000-0000-000000000101')->'payload')-'need_generation_run_id'))->>'error_code','VALIDATION_FAILED','missing payload field fails');
select is(atlas_core.pa_06e_h0cb_validate_materialization_request(jsonb_set(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000001000','cb300000-0000-0000-0000-000000008015','validator-15','cb300000-0000-0000-0000-000000000101'),'{payload}',(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000001000','cb300000-0000-0000-0000-000000008015','validator-15','cb300000-0000-0000-0000-000000000101')->'payload')||jsonb_build_object('extra',1)))->>'error_code','VALIDATION_FAILED','extra payload field fails');
select is(atlas_core.pa_06e_h0cb_validate_materialization_request(jsonb_set(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000001000','cb300000-0000-0000-0000-000000008016','validator-16','cb300000-0000-0000-0000-000000000101'),'{payload,need_generation_run_id}','"bad"'))->>'error_code','VALIDATION_FAILED','bad run UUID fails');
select is(atlas_core.pa_06e_h0cb_validate_materialization_request(jsonb_set(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000001000','cb300000-0000-0000-0000-000000008017','validator-17','cb300000-0000-0000-0000-000000000101'),'{payload,need_generation_run_version}','0'))->>'error_code','VALIDATION_FAILED','nonpositive run version fails');
select is(atlas_core.pa_06e_h0cb_validate_materialization_request(jsonb_set(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000001000','cb300000-0000-0000-0000-000000008018','validator-18','cb300000-0000-0000-0000-000000000101'),'{payload,confirmed_need_batch_id}','"bad"'))->>'error_code','VALIDATION_FAILED','bad batch UUID fails');
select is(atlas_core.pa_06e_h0cb_validate_materialization_request(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000001000','cb300000-0000-0000-0000-000000008019','validator-19','cb300000-0000-0000-0000-000000000101',1,null,2))->>'error_code','VALIDATION_FAILED','initial expected version must be one');
select is(atlas_core.pa_06e_h0cb_validate_materialization_request(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000001000','cb300000-0000-0000-0000-000000008020','validator-20','cb300000-0000-0000-0000-000000000101')),null::jsonb,'exact valid request passes validator');
select ok(jsonb_array_length(atlas_core.pa_06e_h0cb_validate_materialization_request('{}'::jsonb)->'field_errors')>0,'validation failure returns safe field errors');

create temporary table h0cb_error_results(result_name text primary key,response_payload jsonb not null);
grant select,insert on h0cb_error_results to authenticated;

-- Auth and all four complete-set scope kinds (25-46).
set local role authenticated;
select set_config('request.jwt.claim.sub','',true);
insert into h0cb_error_results values ('no_auth',atlas_api.create_confirmed_needs_from_generation(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000001000','cb300000-0000-0000-0000-000000008101','auth-no','cb300000-0000-0000-0000-000000000101')));
select set_config('request.jwt.claim.sub','cb300000-0000-0000-0000-000000000101',true);
insert into h0cb_error_results values ('mismatch',atlas_api.create_confirmed_needs_from_generation(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000001000','cb300000-0000-0000-0000-000000008102','auth-mismatch','cb300000-0000-0000-0000-000000000102')));
select set_config('request.jwt.claim.sub','cb300000-0000-0000-0000-000000000999',true);
insert into h0cb_error_results values ('unknown',atlas_api.create_confirmed_needs_from_generation(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000001000','cb300000-0000-0000-0000-000000008103','auth-unknown','cb300000-0000-0000-0000-000000000999')));
select set_config('request.jwt.claim.sub','cb300000-0000-0000-0000-000000000109',true);
insert into h0cb_error_results values ('inactive_subject',atlas_api.create_confirmed_needs_from_generation(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000001000','cb300000-0000-0000-0000-000000008104','auth-subject','cb300000-0000-0000-0000-000000000109')));
select set_config('request.jwt.claim.sub','cb300000-0000-0000-0000-000000000108',true);
insert into h0cb_error_results values ('inactive_actor',atlas_api.create_confirmed_needs_from_generation(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000001000','cb300000-0000-0000-0000-000000008105','auth-actor','cb300000-0000-0000-0000-000000000108')));
select set_config('request.jwt.claim.sub','cb300000-0000-0000-0000-000000000107',true);
insert into h0cb_error_results values ('integration',atlas_api.create_confirmed_needs_from_generation(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000001000','cb300000-0000-0000-0000-000000008106','auth-integration','cb300000-0000-0000-0000-000000000107')));
select set_config('request.jwt.claim.sub','cb300000-0000-0000-0000-000000000106',true);
insert into h0cb_error_results values ('no_capability',atlas_api.create_confirmed_needs_from_generation(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000001000','cb300000-0000-0000-0000-000000008107','auth-capability','cb300000-0000-0000-0000-000000000106')));
select set_config('request.jwt.claim.sub','cb300000-0000-0000-0000-000000000105',true);
insert into h0cb_error_results values ('no_scope',atlas_api.create_confirmed_needs_from_generation(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000001400','cb300000-0000-0000-0000-000000008108','auth-scope','cb300000-0000-0000-0000-000000000105')));
select set_config('request.jwt.claim.sub','cb300000-0000-0000-0000-000000000102',true);
insert into h0cb_error_results values ('partial_scope',atlas_api.create_confirmed_needs_from_generation(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000002000','cb300000-0000-0000-0000-000000008109','auth-partial','cb300000-0000-0000-0000-000000000102')));
select set_config('request.jwt.claim.sub','cb300000-0000-0000-0000-000000000101',true);
insert into h0cb_error_results values ('global',atlas_api.create_confirmed_needs_from_generation(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000001000','cb300000-0000-0000-0000-000000008110','scope-global','cb300000-0000-0000-0000-000000000101')));
select set_config('request.jwt.claim.sub','cb300000-0000-0000-0000-000000000102',true);
insert into h0cb_error_results values ('customer',atlas_api.create_confirmed_needs_from_generation(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000001100','cb300000-0000-0000-0000-000000008111','scope-customer','cb300000-0000-0000-0000-000000000102')));
select set_config('request.jwt.claim.sub','cb300000-0000-0000-0000-000000000103',true);
insert into h0cb_error_results values ('school',atlas_api.create_confirmed_needs_from_generation(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000001200','cb300000-0000-0000-0000-000000008112','scope-school','cb300000-0000-0000-0000-000000000103')));
select set_config('request.jwt.claim.sub','cb300000-0000-0000-0000-000000000104',true);
insert into h0cb_error_results values ('location',atlas_api.create_confirmed_needs_from_generation(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000001300','cb300000-0000-0000-0000-000000008113','scope-location','cb300000-0000-0000-0000-000000000104')));
reset role;

select is((select response_payload->>'error_code' from h0cb_error_results where result_name='no_auth'),'AUTHENTICATION_REQUIRED','unauthenticated request is denied');
select is((select response_payload->>'error_code' from h0cb_error_results where result_name='mismatch'),'AUTH_SUBJECT_MISMATCH','subject mismatch is denied');
select is((select response_payload->>'error_code' from h0cb_error_results where result_name='unknown'),'ACTOR_NOT_FOUND','unknown actor is denied');
select is((select response_payload->>'error_code' from h0cb_error_results where result_name='inactive_subject'),'AUTH_SUBJECT_INACTIVE','inactive subject is denied');
select is((select response_payload->>'error_code' from h0cb_error_results where result_name='inactive_actor'),'ACTOR_INACTIVE','inactive actor is denied');
select is((select response_payload->>'error_code' from h0cb_error_results where result_name='integration'),'DELEGATION_NOT_SUPPORTED','integration actor is denied');
select is((select response_payload->>'error_code' from h0cb_error_results where result_name='no_capability'),'CAPABILITY_DENIED','missing capability is denied');
select is((select response_payload->>'error_code' from h0cb_error_results where result_name='no_scope'),'SCOPE_DENIED','missing scope is denied');
select is((select response_payload->>'error_code' from h0cb_error_results where result_name='partial_scope'),'SCOPE_DENIED','partial complete-set scope is denied');
select is((select response_payload->>'success' from h0cb_error_results where result_name='global'),'true','GLOBAL covers full release');
select is((select response_payload->>'success' from h0cb_error_results where result_name='customer'),'true','exact CUSTOMER covers full release');
select is((select response_payload->>'success' from h0cb_error_results where result_name='school'),'true','exact SCHOOL covers full release');
select is((select response_payload->>'success' from h0cb_error_results where result_name='location'),'true','exact DELIVERY_LOCATION covers full release');
select is((select count(*)::integer from atlas_planning.confirmed_need_batches where source_kind='NEED_GENERATION'),4,'four authorized modes create four batches');
select is((select count(*)::integer from atlas_core.command_receipts where command_name='create_confirmed_needs_from_generation'),4,'pre-receipt auth denials create no receipt');
select is((select count(*)::integer from atlas_audit.domain_events where event_type='ConfirmedNeedsCreated'),4,'authorized modes emit four events');
select is((select count(*)::integer from atlas_audit.audit_events where event_type='ConfirmedNeedsCreated'),4,'authorized modes emit four audits');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revision_contributions where school_id='cb300000-0000-0000-0000-000000000013'),4,'authorized releases are fully materialized');
select is((select count(*)::integer from atlas_planning.confirmed_need_batches where created_by_actor_id in ('cb300000-0000-0000-0000-000000000001','cb300000-0000-0000-0000-000000000002','cb300000-0000-0000-0000-000000000003','cb300000-0000-0000-0000-000000000004')),4,'each authorized human is traced');
select is((select count(*)::integer from atlas_core.command_receipts where outcome='FAILED_NON_RETRYABLE'),0,'pre-receipt denials leave no failed receipt');
select is((select count(*)::integer from atlas_audit.domain_events where actor_id in ('cb300000-0000-0000-0000-000000000005','cb300000-0000-0000-0000-000000000006','cb300000-0000-0000-0000-000000000007','cb300000-0000-0000-0000-000000000008','cb300000-0000-0000-0000-000000000009')),0,'denied actors emit no event');
select is((select count(*)::integer from atlas_audit.audit_events where actor_id in ('cb300000-0000-0000-0000-000000000005','cb300000-0000-0000-0000-000000000006','cb300000-0000-0000-0000-000000000007','cb300000-0000-0000-0000-000000000008','cb300000-0000-0000-0000-000000000009')),0,'denied actors emit no audit');

-- Deterministic source, limit, lifecycle, identity, and receipt errors (47-82).
set local role authenticated;
select set_config('request.jwt.claim.sub','cb300000-0000-0000-0000-000000000101',true);
insert into h0cb_error_results values ('not_released',atlas_api.create_confirmed_needs_from_generation(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000001800','cb300000-0000-0000-0000-000000008201','not-released','cb300000-0000-0000-0000-000000000101')));
insert into h0cb_error_results values ('missing_run',atlas_api.create_confirmed_needs_from_generation(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000009000','cb300000-0000-0000-0000-000000008202','missing-run','cb300000-0000-0000-0000-000000000101')));
insert into h0cb_error_results values ('stale_source',atlas_api.create_confirmed_needs_from_generation(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000001900','cb300000-0000-0000-0000-000000008203','stale-source','cb300000-0000-0000-0000-000000000101',2)));
insert into h0cb_error_results values ('empty',atlas_api.create_confirmed_needs_from_generation(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000001500','cb300000-0000-0000-0000-000000008204','empty-release','cb300000-0000-0000-0000-000000000101')));
insert into h0cb_error_results values ('zero',atlas_api.create_confirmed_needs_from_generation(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000001600','cb300000-0000-0000-0000-000000008205','zero-release','cb300000-0000-0000-0000-000000000101')));
insert into h0cb_error_results values ('limit',atlas_api.create_confirmed_needs_from_generation(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000001700','cb300000-0000-0000-0000-000000008206','limit-release','cb300000-0000-0000-0000-000000000101')));
insert into h0cb_error_results values ('duplicate_initial',atlas_api.create_confirmed_needs_from_generation(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000001000','cb300000-0000-0000-0000-000000008207','duplicate-initial','cb300000-0000-0000-0000-000000000101')));
insert into h0cb_error_results values ('stale_batch',atlas_api.create_confirmed_needs_from_generation(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000002100','cb300000-0000-0000-0000-000000008208','stale-batch','cb300000-0000-0000-0000-000000000101',1,(select (response_payload#>>'{affected_aggregate_ids,confirmed_need_batch_id}')::uuid from h0cb_error_results where result_name='global'),99)));
insert into h0cb_error_results values ('ambiguous',atlas_api.create_confirmed_needs_from_generation(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000001100','cb300000-0000-0000-0000-000000008209','ambiguous','cb300000-0000-0000-0000-000000000101',1,(select (response_payload#>>'{affected_aggregate_ids,confirmed_need_batch_id}')::uuid from h0cb_error_results where result_name='global'),1)));
reset role;

update atlas_planning.confirmed_need_batches set batch_status='VALIDATED' where confirmed_need_batch_id=(select (response_payload#>>'{affected_aggregate_ids,confirmed_need_batch_id}')::uuid from h0cb_error_results where result_name='global');
set local role authenticated; select set_config('request.jwt.claim.sub','cb300000-0000-0000-0000-000000000101',true);
insert into h0cb_error_results values ('reopen',atlas_api.create_confirmed_needs_from_generation(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000002100','cb300000-0000-0000-0000-000000008210','reopen','cb300000-0000-0000-0000-000000000101',1,(select (response_payload#>>'{affected_aggregate_ids,confirmed_need_batch_id}')::uuid from h0cb_error_results where result_name='global'),1)));
reset role;
update atlas_planning.confirmed_need_batches set batch_status='RELEASED_FOR_PURCHASE_HANDOFF' where confirmed_need_batch_id=(select (response_payload#>>'{affected_aggregate_ids,confirmed_need_batch_id}')::uuid from h0cb_error_results where result_name='global');
set local role authenticated; select set_config('request.jwt.claim.sub','cb300000-0000-0000-0000-000000000101',true);
insert into h0cb_error_results values ('downstream',atlas_api.create_confirmed_needs_from_generation(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000002100','cb300000-0000-0000-0000-000000008211','downstream','cb300000-0000-0000-0000-000000000101',1,(select (response_payload#>>'{affected_aggregate_ids,confirmed_need_batch_id}')::uuid from h0cb_error_results where result_name='global'),1)));
reset role;
update atlas_planning.confirmed_need_batches set batch_status='DRAFT_REVIEW' where confirmed_need_batch_id=(select (response_payload#>>'{affected_aggregate_ids,confirmed_need_batch_id}')::uuid from h0cb_error_results where result_name='global');
update atlas_admin.schools set default_delivery_location_id='cb300000-0000-0000-0000-000000000012' where school_id='cb300000-0000-0000-0000-000000000013';
set local role authenticated; select set_config('request.jwt.claim.sub','cb300000-0000-0000-0000-000000000101',true);
insert into h0cb_error_results values ('destination',atlas_api.create_confirmed_needs_from_generation(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000002100','cb300000-0000-0000-0000-000000008212','destination','cb300000-0000-0000-0000-000000000101',1,(select (response_payload#>>'{affected_aggregate_ids,confirmed_need_batch_id}')::uuid from h0cb_error_results where result_name='global'),1)));
reset role;
update atlas_admin.schools set default_delivery_location_id='cb300000-0000-0000-0000-000000000011' where school_id='cb300000-0000-0000-0000-000000000013';

set local session_replication_role=replica;
update atlas_planning.confirmed_need_line_revisions set theoretical_quantity=11 where confirmed_need_batch_id=(select (response_payload#>>'{affected_aggregate_ids,confirmed_need_batch_id}')::uuid from h0cb_error_results where result_name='global') and is_current;
set local session_replication_role=origin;
set local role authenticated; select set_config('request.jwt.claim.sub','cb300000-0000-0000-0000-000000000101',true);
insert into h0cb_error_results values ('total',atlas_api.create_confirmed_needs_from_generation(pg_temp.h0cb_error_request('cb300000-0000-0000-0000-000000002100','cb300000-0000-0000-0000-000000008213','total','cb300000-0000-0000-0000-000000000101',1,(select (response_payload#>>'{affected_aggregate_ids,confirmed_need_batch_id}')::uuid from h0cb_error_results where result_name='global'),1)));
reset role;

select is((select response_payload->>'error_code' from h0cb_error_results where result_name='not_released'),'GENERATION_NOT_RELEASED','generated source is not released');
select is((select response_payload->>'error_code' from h0cb_error_results where result_name='missing_run'),'GENERATION_NOT_RELEASED','missing source is safely not released');
select is((select response_payload->>'error_code' from h0cb_error_results where result_name='stale_source'),'SOURCE_REVISION_STALE','stale released version is denied');
select is((select response_payload->>'error_code' from h0cb_error_results where result_name='empty'),'EMPTY_ACTIVE_RELEASE','empty active release is denied');
select is((select response_payload->>'error_code' from h0cb_error_results where result_name='zero'),'ZERO_ACTIVE_CONTRIBUTION_POLICY_REQUIRED','zero active contribution is denied');
select is((select response_payload->>'error_code' from h0cb_error_results where result_name='limit'),'MATERIALIZATION_LIMIT_EXCEEDED','fifteen-day inclusive period exceeds limit');
select is((select response_payload->>'error_code' from h0cb_error_results where result_name='duplicate_initial'),'INVARIANT_VIOLATION','second initial materialization is denied');
select is((select response_payload->>'error_code' from h0cb_error_results where result_name='stale_batch'),'STALE_VERSION','stale batch version is denied');
select is((select response_payload->>'error_code' from h0cb_error_results where result_name='ambiguous'),'SOURCE_SUCCESSOR_AMBIGUOUS','unrelated run is not a direct successor');
select is((select response_payload->>'error_code' from h0cb_error_results where result_name='reopen'),'REOPEN_REQUIRED','validated batch requires explicit reopen');
select is((select response_payload->>'error_code' from h0cb_error_results where result_name='downstream'),'DOWNSTREAM_CORRECTION_REQUIRED','released batch requires downstream correction');
select is((select response_payload->>'error_code' from h0cb_error_results where result_name='destination'),'OPERATIONAL_IDENTITY_UNAPPROVED','default destination change is not followed silently');
select is((select response_payload->>'error_code' from h0cb_error_results where result_name='total'),'CONTRIBUTION_TOTAL_MISMATCH','corrupt old partition total is denied');
select is((select response_payload->>'retryable' from h0cb_error_results where result_name='empty'),'false','empty release is deterministic');
select is((select response_payload->>'retryable' from h0cb_error_results where result_name='limit'),'false','limit failure is deterministic');
select is((select response_payload->>'retryable' from h0cb_error_results where result_name='stale_batch'),'false','stale batch is deterministic');
select is((select response_payload->>'retryable' from h0cb_error_results where result_name='destination'),'false','identity failure is deterministic');
select is((select count(*)::integer from atlas_planning.confirmed_need_batches where source_kind='NEED_GENERATION'),4,'all deterministic failures create no batch');
select is((select count(*)::integer from atlas_audit.domain_events where event_type like 'ConfirmedNeeds%'),4,'deterministic failures emit no event');
select is((select count(*)::integer from atlas_audit.audit_events where event_type like 'ConfirmedNeeds%'),4,'deterministic failures emit no audit');
select is((select count(*)::integer from atlas_core.command_receipts where outcome='FAILED_NON_RETRYABLE'),10,'ten post-receipt deterministic failures are stored');
select is((select count(*)::integer from atlas_core.command_receipts where outcome='COMPLETED'),4,'only four authorized successes complete');
select is((select count(*)::integer from atlas_core.command_receipts where outcome='IN_PROGRESS'),0,'no receipt remains in progress');
select is((select count(*)::integer from atlas_core.command_receipts where error_code='EMPTY_ACTIVE_RELEASE'),1,'empty failure receipt stores exact code');
select is((select count(*)::integer from atlas_core.command_receipts where error_code='ZERO_ACTIVE_CONTRIBUTION_POLICY_REQUIRED'),1,'zero failure receipt stores exact code');
select is((select count(*)::integer from atlas_core.command_receipts where error_code='MATERIALIZATION_LIMIT_EXCEEDED'),1,'limit failure receipt stores exact code');
select is((select count(*)::integer from atlas_core.command_receipts where error_code='STALE_VERSION'),1,'stale failure receipt stores exact code');
select is((select count(*)::integer from atlas_core.command_receipts where error_code='OPERATIONAL_IDENTITY_UNAPPROVED'),1,'destination failure receipt stores exact code');
select is((select count(*)::integer from atlas_core.command_receipts where error_code='CONTRIBUTION_TOTAL_MISMATCH'),1,'total failure receipt stores exact code');
select is((select count(*)::integer from atlas_core.command_receipts where response_payload is null),0,'every accepted receipt has a safe stored response');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions where need_generation_run_id='cb300000-0000-0000-0000-000000002100'),0,'failed corrections create no successor revision');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revision_contributions where need_generation_run_id='cb300000-0000-0000-0000-000000002100'),0,'failed corrections create no successor membership');
select is((select version from atlas_planning.confirmed_need_batches where confirmed_need_batch_id=(select (response_payload#>>'{affected_aggregate_ids,confirmed_need_batch_id}')::uuid from h0cb_error_results where result_name='global')),1::bigint,'failed corrections do not advance batch version');
select is((select current_need_generation_run_id from atlas_planning.confirmed_need_batches where confirmed_need_batch_id=(select (response_payload#>>'{affected_aggregate_ids,confirmed_need_batch_id}')::uuid from h0cb_error_results where result_name='global')),'cb300000-0000-0000-0000-000000001000'::uuid,'failed corrections preserve current source');
select is((select count(*)::integer from atlas_core.command_receipts where command_id in ('cb300000-0000-0000-0000-000000008201','cb300000-0000-0000-0000-000000008202','cb300000-0000-0000-0000-000000008203')),0,'pre-receipt source failures leave no receipt');

-- Exact safe-code, conversion, concurrency, and forbidden-write catalog (83-112).
select ok((select pg_get_functiondef('atlas_api.create_confirmed_needs_from_generation(jsonb)'::regprocedure) like '%SOURCE_LINEAGE_INCOMPLETE%'),'source-lineage safe error is implemented');
select ok((select pg_get_functiondef('atlas_api.create_confirmed_needs_from_generation(jsonb)'::regprocedure) like '%SOURCE_MAPPING_INCOMPLETE%'),'source-mapping safe error is implemented');
select ok((select pg_get_functiondef('atlas_api.create_confirmed_needs_from_generation(jsonb)'::regprocedure) like '%CONTRIBUTION_MEMBERSHIP_INVALID%'),'membership safe error is implemented');
select ok((select pg_get_functiondef('atlas_api.create_confirmed_needs_from_generation(jsonb)'::regprocedure) like '%SOURCE_REMOVAL_POLICY_REQUIRED%'),'removal policy error is implemented');
select ok((select pg_get_functiondef('atlas_api.create_confirmed_needs_from_generation(jsonb)'::regprocedure) like '%SOURCE_SPLIT_MERGE_POLICY_REQUIRED%'),'split/merge policy error is implemented');
select is((select count(*)::integer from (values
 ('GENERATION_NOT_RELEASED'),('SOURCE_LINEAGE_INCOMPLETE'),('SOURCE_REVISION_STALE'),('SOURCE_MAPPING_INCOMPLETE'),
 ('SOURCE_SUCCESSOR_AMBIGUOUS'),('OPERATIONAL_IDENTITY_UNAPPROVED'),('CONTRIBUTION_MEMBERSHIP_INVALID'),
 ('CONTRIBUTION_TOTAL_MISMATCH'),('EMPTY_ACTIVE_RELEASE'),('ZERO_ACTIVE_CONTRIBUTION_POLICY_REQUIRED'),
 ('SOURCE_REMOVAL_POLICY_REQUIRED'),('SOURCE_SPLIT_MERGE_POLICY_REQUIRED'),('REOPEN_REQUIRED'),
 ('DOWNSTREAM_CORRECTION_REQUIRED'),('MATERIALIZATION_LIMIT_EXCEEDED')) required(code)
 where pg_get_functiondef('atlas_api.create_confirmed_needs_from_generation(jsonb)'::regprocedure) like '%'||code||'%'),15,'all fifteen H0C-specific safe codes are reachable');
select ok((select pg_get_functiondef('atlas_api.create_confirmed_needs_from_generation(jsonb)'::regprocedure) like '%unit_id <> old_contribution.source_unit_id%'),'Unit conversion is rejected as unsupported mapping');
select ok(exists(select 1 from pg_constraint where conrelid='atlas_planning.confirmed_need_line_revision_contributions'::regclass and conname='confirmed_need_line_revision_contributions_unit_check'),'membership enforces source Unit equals controlled Unit');
select isnt(has_column_privilege('atlas_planning_materialization_runtime','atlas_planning.confirmed_need_line_revision_contributions','controlled_unit_id','UPDATE'),true,'runtime cannot rewrite controlled contribution Unit');
select isnt(has_table_privilege('atlas_planning_materialization_runtime','atlas_planning.confirmed_need_line_revision_contributions','DELETE'),true,'runtime cannot delete membership');
select ok(exists(select 1 from pg_index where indexrelid='atlas_planning.need_generation_runs_predecessor_successor_key'::regclass and indisunique),'run successor is unique');
select ok(exists(select 1 from pg_index where indexrelid='atlas_planning.theoretical_need_lines_predecessor_successor_key'::regclass and indisunique),'contribution successor is unique');
select ok(exists(select 1 from pg_index where indexrelid='atlas_planning.confirmed_need_batches_origin_release_key'::regclass and indisunique),'concurrent initial materialization is uniquely fenced');
select ok(exists(select 1 from pg_index where indexrelid='atlas_planning.confirmed_need_lines_operational_identity_key'::regclass and indisunique),'concurrent stable identity creation is uniquely fenced');
select ok(exists(select 1 from pg_index where indexrelid='atlas_planning.confirmed_need_line_revisions_current_key'::regclass and indisunique),'concurrent current revision creation is uniquely fenced');
select ok((select pg_get_functiondef('atlas_api.create_confirmed_needs_from_generation(jsonb)'::regprocedure) like '%for update%'),'command uses row locks');
select ok((select pg_get_functiondef('atlas_api.create_confirmed_needs_from_generation(jsonb)'::regprocedure) like '%order by source_run.need_generation_run_id for update%'),'source-run lock order is deterministic');
select ok((select pg_get_functiondef('atlas_api.create_confirmed_needs_from_generation(jsonb)'::regprocedure) like '%order by target_revision.confirmed_need_line_revision_id for update%'),'revision lock order is deterministic');
select ok((select pg_get_functiondef('atlas_api.create_confirmed_needs_from_generation(jsonb)'::regprocedure) like '%lock_not_available%'),'lock timeout is classified retryable');
select ok((select pg_get_functiondef('atlas_api.create_confirmed_needs_from_generation(jsonb)'::regprocedure) like '%query_canceled%'),'statement timeout is classified retryable');
select ok((select pg_get_functiondef('atlas_api.create_confirmed_needs_from_generation(jsonb)'::regprocedure) like '%serialization_failure%'),'serialization failure is classified retryable');
select ok((select pg_get_functiondef('atlas_api.create_confirmed_needs_from_generation(jsonb)'::regprocedure) like '%deadlock_detected%'),'deadlock is classified retryable');
select ok((select pg_get_functiondef('atlas_api.create_confirmed_needs_from_generation(jsonb)'::regprocedure) not like '%LOOP%'),'command has no internal retry loop');
select ok((select pg_get_functiondef('atlas_api.create_confirmed_needs_from_generation(jsonb)'::regprocedure) like '%RETRYABLE_CONCURRENCY_FAILURE%'),'retryable response requires exact-request retry');
select isnt(has_table_privilege('atlas_planning_materialization_runtime','atlas_planning.confirmed_need_approval_snapshots','INSERT'),true,'runtime cannot approve Confirmed Need');
select isnt(has_table_privilege('atlas_planning_materialization_runtime','atlas_planning.purchase_handoff_batches','SELECT'),true,'runtime cannot read Purchase Handoff');
select isnt(has_table_privilege('atlas_planning_materialization_runtime','atlas_planning.purchase_handoff_batches','INSERT'),true,'runtime cannot write Purchase Handoff');
select isnt(has_schema_privilege('atlas_planning_materialization_runtime','atlas_procurement','USAGE'),true,'runtime cannot use Procurement');
select isnt(has_schema_privilege('atlas_planning_materialization_runtime','atlas_dispatch','USAGE'),true,'runtime cannot use Dispatch');
select is((select count(*)::integer from information_schema.role_table_grants where grantee='atlas_planning_materialization_runtime' and table_schema in ('atlas_procurement','atlas_dispatch','atlas_evidence')),0,'runtime has no forbidden-domain relation grants');
select is((select count(*)::integer from information_schema.role_table_grants where grantee in ('anon','authenticated','service_role') and table_name='confirmed_need_line_revision_contributions'),0,'API roles cannot bypass membership RLS');

select * from finish();
rollback;
