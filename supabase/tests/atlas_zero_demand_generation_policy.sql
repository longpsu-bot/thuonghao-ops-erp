-- Disposable local/CI only. All source and generation constraints stay enabled.
-- Reproduces 12/10/2026: three Hùng Vương zero-attendance Schools retain
-- 4 + 1 + 4 Menu lines alongside one positive School. No hosted identities.
begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = pg_catalog, public, extensions;

select plan(71);
select function_owner_is('atlas_core','zero_demand_predecessor_contribution',array['uuid','uuid'],'atlas_planning_materialization_runtime','zero ancestry helper keeps the bounded materialization runtime');
select ok(not has_function_privilege('anon','atlas_core.zero_demand_predecessor_contribution(uuid,uuid)','EXECUTE') and not has_function_privilege('authenticated','atlas_core.zero_demand_predecessor_contribution(uuid,uuid)','EXECUTE') and not has_function_privilege('service_role','atlas_core.zero_demand_predecessor_contribution(uuid,uuid)','EXECUTE'),'zero ancestry helper is not a public API');
select ok((select prosecdef and proisstrict and proconfig @> array['search_path=""'] from pg_proc where oid='atlas_core.zero_demand_predecessor_contribution(uuid,uuid)'::regprocedure),'private ancestry helper has fixed path and skips null predecessor work');
create function pg_temp.ng_id(n bigint) returns uuid language sql immutable as $$
  select ('a7500000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
$$;
create function pg_temp.ng_request(contract text, reason text, payload jsonb)
returns jsonb language sql volatile as $$
  select jsonb_build_object('contract_version',contract,'command_id',id,
    'correlation_id',gen_random_uuid(),'idempotency_key','ng-scale:'||id,
    'requested_by_auth_subject',pg_temp.ng_id(101),'requested_at',now(),
    'expected_version',1,'reason_code',reason,'reason_note','Local scale acceptance',
    'payload',payload) from (select gen_random_uuid() as id) ids;
$$;
insert into atlas_core.actors(actor_id,actor_type,display_name)
values(pg_temp.ng_id(1),'HUMAN','Need scale operator');
insert into atlas_core.actor_auth_subjects(actor_auth_subject_id,actor_id,auth_subject_id)
values(pg_temp.ng_id(2),pg_temp.ng_id(1),pg_temp.ng_id(101));
insert into atlas_core.roles(role_id,role_code,role_name)
values(pg_temp.ng_id(3),'zero-demand-operator','Need scale operator');
insert into atlas_core.role_capabilities(role_id,capability_id)
select pg_temp.ng_id(3),capability_id from atlas_core.capabilities
where capability_code like 'planning.%' or capability_code like 'confirmed_need%' or capability_code like 'procurement.%';
insert into atlas_core.actor_role_memberships(actor_id,role_id)
values(pg_temp.ng_id(1),pg_temp.ng_id(3));
insert into atlas_core.actor_scopes(actor_id,scope_kind) values(pg_temp.ng_id(1),'GLOBAL');
insert into atlas_core.actors(actor_id,actor_type,display_name) values(pg_temp.ng_id(4),'HUMAN','Scoped zero withdrawal operator');
insert into atlas_core.actor_auth_subjects(actor_auth_subject_id,actor_id,auth_subject_id) values(pg_temp.ng_id(5),pg_temp.ng_id(4),pg_temp.ng_id(102));
insert into atlas_core.actor_role_memberships(actor_id,role_id) values(pg_temp.ng_id(4),pg_temp.ng_id(3));

insert into atlas_admin.customers(customer_id,customer_code,customer_name,customer_type)
values(pg_temp.ng_id(10),'zero-demand-customer','Need scale customer','SCHOOL_CATERING');
insert into atlas_admin.delivery_locations(delivery_location_id,customer_id,location_code,location_name,address_text,timezone_name)
values(pg_temp.ng_id(11),pg_temp.ng_id(10),'zero-demand-kitchen','Need scale kitchen','Disposable fixture','Asia/Ho_Chi_Minh');
insert into atlas_admin.school_types(school_type_id,school_type_code,school_type_name)
values
 (pg_temp.ng_id(12),'zero-demand-type-a','Need scale type A'),
 (pg_temp.ng_id(14),'zero-demand-type-b','Need scale type B');
insert into atlas_admin.units(unit_id,unit_code,unit_name,dimension_code)
values(pg_temp.ng_id(13),'zero-demand-kg','Need scale kilogram','mass');
insert into atlas_admin.schools(school_id,customer_id,school_code,school_name,school_type_id,default_delivery_location_id,display_order)
select pg_temp.ng_id(5000+i),pg_temp.ng_id(10),'zero-demand-school-'||i,case i when 1 then 'CHUYÊN HÙNG VƯƠNG (Chiều)' when 2 then 'CHUYÊN HÙNG VƯƠNG (Trưa Mặn 2)' when 3 then 'CHUYÊN HÙNG VƯƠNG (Trưa)' else 'Positive School' end,
  case when i<5 then pg_temp.ng_id(12) else pg_temp.ng_id(14) end,pg_temp.ng_id(11),i
from generate_series(1,4) i;
insert into atlas_core.actor_scopes(actor_id,scope_kind,school_id) values(pg_temp.ng_id(4),'SCHOOL',pg_temp.ng_id(5001));
insert into atlas_admin.ingredients(ingredient_id,ingredient_code,ingredient_name,purchase_unit_id,order_step,document_code)
select pg_temp.ng_id(2000+i),'zero-demand-ingredient-'||i,'Need scale ingredient '||i,pg_temp.ng_id(13),0.1,'ZD-I-'||i
from generate_series(1,4) i;
insert into atlas_admin.dishes(dish_id,dish_code,dish_name,dish_type_id,requires_need_generation,dish_status)
select pg_temp.ng_id(1000+i),'zero-demand-dish-'||i,'Need scale dish '||i,t.dish_type_id,true,'ACTIVE'
from unnest(array['soup','savory','stir_fry','dessert']) with ordinality d(code,i)
join atlas_admin.dish_types t on t.dish_type_code=d.code;
insert into atlas_admin.recipes(recipe_id,dish_id,school_type_id)
select pg_temp.ng_id(1100+i),pg_temp.ng_id(1000+((i-1)%4)+1),
 case when i<=4 then pg_temp.ng_id(12) else pg_temp.ng_id(14) end
from generate_series(1,4) i;
insert into atlas_admin.recipe_versions(recipe_version_id,recipe_id,version_number,basis_portions,created_by_actor_id)
select pg_temp.ng_id(1200+i),pg_temp.ng_id(1100+i),1,100,pg_temp.ng_id(1) from generate_series(1,4) i;
insert into atlas_admin.recipe_lines(recipe_line_id,recipe_id,line_code)
select pg_temp.ng_id(3000+i*100+j),pg_temp.ng_id(1100+i),'ingredient-'||j
from generate_series(1,4) i cross join generate_series(1,1) j;
insert into atlas_admin.recipe_line_revisions(recipe_line_revision_id,recipe_id,recipe_version_id,recipe_line_id,line_revision_number,ingredient_id,quantity_per_basis,unit_id,created_by_actor_id)
select pg_temp.ng_id(4000+i*100+j),pg_temp.ng_id(1100+i),pg_temp.ng_id(1200+i),
 pg_temp.ng_id(3000+i*100+j),1,pg_temp.ng_id(2000+i),
 1.234567,pg_temp.ng_id(13),pg_temp.ng_id(1)
from generate_series(1,4) i cross join generate_series(1,1) j;
update atlas_admin.recipe_versions set recipe_version_status='VALIDATED',validated_by_actor_id=pg_temp.ng_id(1),validated_at=now()
where recipe_version_id in(select pg_temp.ng_id(1200+i) from generate_series(1,4) i);
update atlas_admin.recipe_versions set recipe_version_status='RELEASED_FOR_PLANNING',released_by_actor_id=pg_temp.ng_id(1),released_at=now()
where recipe_version_id in(select pg_temp.ng_id(1200+i) from generate_series(1,4) i);
insert into atlas_planning.need_generation_calculation_contracts(need_generation_calculation_contract_id,contract_code,current_revision_id,version)
values(pg_temp.ng_id(20),'school_catering_proportional_per_basis',pg_temp.ng_id(21),1);
insert into atlas_planning.need_generation_calculation_contract_revisions(need_generation_calculation_contract_revision_id,need_generation_calculation_contract_id,revision_number,formula_kind,quantity_precision,quantity_scale,factor_precision,factor_scale,final_coercion_mode,approved_by_actor_id,approved_at)
values(pg_temp.ng_id(21),pg_temp.ng_id(20),1,'STUDENT_TEACHER_PORTIONS_X_RECIPE_QTY_DIV_BASIS',20,6,24,12,'POSTGRES_NUMERIC_SCALE_HALF_AWAY_FROM_ZERO',pg_temp.ng_id(1),now());
insert into atlas_planning.planning_quantity_policies(planning_quantity_policy_id,unit_id,created_by_actor_id)
values(pg_temp.ng_id(30),pg_temp.ng_id(13),pg_temp.ng_id(1));
insert into atlas_planning.planning_quantity_policy_revisions(planning_quantity_policy_revision_id,planning_quantity_policy_id,unit_id,
 revision_number,predecessor_policy_revision_id,planning_step,effective_from,policy_revision_status,created_by_actor_id)
values(pg_temp.ng_id(31),pg_temp.ng_id(30),pg_temp.ng_id(13),1,null,0.1,'2026-01-01','DRAFT',pg_temp.ng_id(1));
update atlas_planning.planning_quantity_policy_revisions set policy_revision_status='ACTIVE',approved_by_actor_id=pg_temp.ng_id(1),
 approved_at=now(),activated_by_actor_id=pg_temp.ng_id(1),activated_at=now()
where planning_quantity_policy_revision_id=pg_temp.ng_id(31);
set constraints all immediate;
set constraints all deferred;
create temp table ng_requests(name text primary key,request jsonb not null);
create temp table ng_results(name text primary key,response jsonb not null,elapsed_ms numeric);
grant select,insert,update on ng_results to authenticated;
grant select,insert,update on ng_requests to authenticated;
with rows as (
 select pg_temp.ng_id(5000+s) as school_id,date '2026-10-12'+day as service_date,
   t.dish_type_code as menu_slot_code,d.dish_id,'scale:'||s||':'||day||':'||d.dish_code as source_row_reference
 from generate_series(1,4) s cross join generate_series(0,4) day
 cross join atlas_admin.dishes d join atlas_admin.dish_types t using(dish_type_id)
 where (s<>2 or d.dish_id=pg_temp.ng_id(1001)) and d.dish_code like 'zero-demand-dish-%'
), canonical as (select atlas_core.rmvp_03a_canonical_menu_rows(jsonb_agg(to_jsonb(rows))) as rows from rows)
insert into ng_requests select 'menu',pg_temp.ng_request('RMVP-03A.v2','WEEKLY_MENU_SAVED',
jsonb_build_object('week_start','2026-10-12','source_type','GOOGLE_SHEET','source_name','Local scale Menu',
'source_signature',atlas_core.rmvp_03a_menu_signature(rows),'expected_source_signature',null,'rows',rows)) from canonical;
with rows as (
 select pg_temp.ng_id(5000+s) as school_id,date '2026-10-12'+day as service_date,
  case when day=3 or (s=4 and day=0) then 95 else 0 end as student_portions,case when day=3 or (s=4 and day=0) then 5 else 0 end as teacher_portions,'scale:'||s||':'||day as source_row_reference
 from generate_series(1,4) s cross join generate_series(0,4) day
), canonical as (select atlas_core.rmvp_03a_canonical_attendance_rows(jsonb_agg(to_jsonb(rows))) as rows from rows)
insert into ng_requests select 'attendance',pg_temp.ng_request('RMVP-03A.v2','ATTENDANCE_SAVED',
jsonb_build_object('week_start','2026-10-12','source_type','BULK_PASTE','source_name','Local scale Attendance',
'source_signature',atlas_core.rmvp_03a_attendance_signature(rows),'expected_source_signature',null,'rows',rows)) from canonical;
insert into atlas_planning.pantry_need_purposes(pantry_need_purpose_id,purpose_code,purpose_name_vi,purpose_description,note_rule,display_order)
values(pg_temp.ng_id(40),'zero_demand_positive_pantry','Pantry test','Local zero-demand fixture','OPTIONAL',1);
with rows as (select jsonb_build_array(jsonb_build_object(
'service_date','2026-10-14','school_id',pg_temp.ng_id(5001),'ingredient_id',pg_temp.ng_id(2001),
'pantry_need_purpose_id',pg_temp.ng_id(40),'requested_quantity','2.500000','note',null,
'source_request_reference','Zero demand Pantry fixture','source_row_reference','pantry-positive')) as rows)
insert into ng_requests select 'pantry',pg_temp.ng_request('PANTRY-02.v2','PANTRY_SAVED',
jsonb_build_object('week_start','2026-10-12','no_additions_confirmed',false,'source_signature',
atlas_core.pantry_02_signature('2026-10-12',false,atlas_core.pantry_02_canonical_rows('2026-10-12',rows)),'expected_source_signature',null,'rows',rows)) from rows;
insert into ng_requests select 'generate',pg_temp.ng_request('RMVP-04.v3','NEED_GENERATION_EXECUTED',
jsonb_build_object('service_date','2026-10-12','expected_current_need_generation_run_id',null));
select set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.ng_id(101),'role','authenticated')::text,true);
set local role authenticated;
insert into ng_results select 'menu',atlas_api.save_weekly_menu(request),null from ng_requests where name='menu';
select is((select response->>'success' from ng_results where name='menu'),'true','65-line weekly Menu is saved through the real command');
select diag(jsonb_build_object('error_code',response->>'error_code','first_blocker',response#>'{blocking_references,0}')::text) from ng_results where name='menu' and response->>'success'<>'true';
insert into ng_results select 'attendance',atlas_api.save_attendance(request),null from ng_requests where name='attendance';
select is((select response->>'success' from ng_results where name='attendance'),'true','20-row Attendance is saved through the real command');
insert into ng_results select 'pantry',atlas_api.save_pantry(request),null from ng_requests where name='pantry';
select is((select response->>'success' from ng_results where name='pantry'),'true','positive Pantry is saved');

insert into ng_results select 'mixed',atlas_api.execute_need_generation(request),null from ng_requests where name='generate';
select is((select response->>'success' from ng_results where name='mixed'),'true','the three Hùng Vương zero Schools do not block positive School on 12 October');
select diag(response::text) from ng_results where name='mixed' and response->>'success'<>'true';
reset role;
select is((select count(*) from atlas_planning.theoretical_need_lines where service_date='2026-10-12' and theoretical_quantity=0 and line_disposition='ACTIVE'),9::bigint,'4 + 1 + 4 zero observations retain ACTIVE source meaning');
select is((select count(*) from atlas_planning.confirmed_need_line_revisions where service_date='2026-10-12' and is_current),4::bigint,'only four positive groups materialize');
select ok((select bool_and(theoretical_quantity=1.234567) from atlas_planning.confirmed_need_line_revisions where service_date='2026-10-12' and is_current),'exact positive quantities remain unchanged');
insert into ng_requests select 'all-zero',pg_temp.ng_request('RMVP-04.v3','NEED_GENERATION_EXECUTED',jsonb_build_object('service_date','2026-10-13','expected_current_need_generation_run_id',null));
insert into ng_requests select 'pantry-positive',pg_temp.ng_request('RMVP-04.v3','NEED_GENERATION_EXECUTED',jsonb_build_object('service_date','2026-10-14','expected_current_need_generation_run_id',null));
set local role authenticated;
insert into ng_results select 'all-zero',atlas_api.execute_need_generation(request),null from ng_requests where name='all-zero';
select is((select response->>'success' from ng_results where name='all-zero'),'true','all-zero day completes normally');
select is((select response#>>'{authoritative_readback,preflight,demand_state}' from ng_results where name='all-zero'),'NO_DEMAND','all-zero is derived NO_DEMAND');
insert into ng_results select 'pantry-positive',atlas_api.execute_need_generation(request),null from ng_requests where name='pantry-positive';
select is((select response->>'success' from ng_results where name='pantry-positive'),'true','zero Recipe plus positive Pantry completes');
reset role;
select is((select count(*) from atlas_planning.confirmed_need_batches where period_start='2026-10-13'),0::bigint,'all-zero day creates no fake Confirmed Need batch');
insert into ng_requests select 'cmd15-zero',pg_temp.ng_request('PA-06E-H0C.v1','CONFIRMED_NEED_MATERIALIZED',jsonb_build_object('need_generation_run_id',response#>'{affected_aggregate_ids,need_generation_run_id}','need_generation_run_version',3,'confirmed_need_batch_id',null))||jsonb_build_object('reason_note',null) from ng_results where name='all-zero';
set local role authenticated;
insert into ng_results select 'cmd15-zero',atlas_api.create_confirmed_needs_from_generation(request),null from ng_requests where name='cmd15-zero';
insert into ng_results select 'cmd15-zero-replay',atlas_api.create_confirmed_needs_from_generation(request),null from ng_requests where name='cmd15-zero';
select is((select response from ng_results where name='cmd15-zero-replay'),(select response from ng_results where name='cmd15-zero'),'retained CMD-15 zero success exactly replays its receipt');
reset role;
select ok((select response->>'success'='true' and response#>'{affected_aggregate_ids,confirmed_need_batch_id}'='null'::jsonb and response#>'{new_versions,confirmed_need_batch_version}'='null'::jsonb and response->'emitted_event_ids'='[]'::jsonb and response->'audit_event_ids'='[]'::jsonb and (select count(*)=12 and bool_and(value::integer=0) from jsonb_each_text(response->'result_counts')) from ng_results where name='cmd15-zero') and not exists(select 1 from atlas_audit.domain_events where command_id=(select (request->>'command_id')::uuid from ng_requests where name='cmd15-zero')) and not exists(select 1 from atlas_audit.audit_events where command_id=(select (request->>'command_id')::uuid from ng_requests where name='cmd15-zero')),'retained CMD-15 preserves the full zero-count envelope without invented aggregate events');

select is((select count(*) from atlas_planning.confirmed_need_line_revisions where service_date='2026-10-14' and is_current and theoretical_quantity=2.5),1::bigint,'positive Pantry quantity alone materializes');
select is((select count(*) from atlas_planning.confirmed_need_line_revision_contributions where source_theoretical_quantity=0),0::bigint,'no zero actionable contribution exists');
select is((select count(*) from atlas_planning.confirmed_need_line_revisions where is_current and theoretical_quantity=0),0::bigint,'no zero actionable Confirmed Need revision exists');


-- Read actual Shopping List and Supplier Allocation authority, not only counts.
set local role authenticated;
insert into ng_results select 'shopping-mixed',atlas_api.get_confirmed_need_shopping_list_export(jsonb_build_object(
 'contract_version','RMVP-05.v1','requested_by_auth_subject',pg_temp.ng_id(101),'correlation_id',gen_random_uuid(),
 'payload',jsonb_build_object('confirmed_need_batch_id',response#>'{affected_aggregate_ids,confirmed_need_batch_id}',
 'filters','{}'::jsonb,'line_offset',0,'line_limit',10000))),null from ng_results where name='mixed';
select is((select response->>'success' from ng_results where name='shopping-mixed'),'true','Shopping List reads the mixed-demand result');
select is((select jsonb_array_length(response#>'{workbench,lines}') from ng_results where name='shopping-mixed'),4,'Shopping List contains only the positive School groups');
insert into ng_results values('allocation-mixed',atlas_api.get_confirmed_supplier_allocation_workbench(jsonb_build_object(
 'contract_version','CONFIRMED-SUPPLIER-ALLOCATION.v1','requested_by_auth_subject',pg_temp.ng_id(101),'correlation_id',gen_random_uuid(),
 'payload',jsonb_build_object('date_start','2026-10-12','date_end','2026-10-12','school_ids','[]'::jsonb,'states','[]'::jsonb,'search',null))),null);
select is((select response->>'success' from ng_results where name='allocation-mixed'),'true','Supplier Allocation reads the mixed-demand result');
select is((select jsonb_array_length(response->'rows') from ng_results where name='allocation-mixed'),4,'Supplier Allocation selection contains only positive Ingredient families');
insert into ng_results values('allocation-zero',atlas_api.get_confirmed_supplier_allocation_workbench(jsonb_build_object('contract_version','CONFIRMED-SUPPLIER-ALLOCATION.v1','requested_by_auth_subject',pg_temp.ng_id(101),'correlation_id',gen_random_uuid(),'payload',jsonb_build_object('date_start','2026-10-13','date_end','2026-10-13'))),null);
select is((select jsonb_array_length(response->'rows') from ng_results where name='allocation-zero'),0,'no-demand exposes no Supplier Allocation family');
reset role;
-- Replays and derived no-demand readback use the real authenticated boundary.
set local role authenticated;
insert into ng_results select 'mixed-replay',atlas_api.execute_need_generation(request),null from ng_requests where name='generate';
insert into ng_results select 'zero-replay',atlas_api.execute_need_generation(request),null from ng_requests where name='all-zero';
select is((select response from ng_results where name='mixed-replay'),(select response from ng_results where name='mixed'),'positive result exact replay remains unchanged');
select is((select response from ng_results where name='zero-replay'),(select response from ng_results where name='all-zero'),'no-demand exact replay remains unchanged');
reset role;
select is((select count(*) from atlas_procurement.purchase_orders),0::bigint,'generation creates no Purchase authority from zero');
select is((select count(*) from atlas_procurement.school_catering_allocation_families),0::bigint,'generation creates no Supplier Allocation authority from zero');
select is((select count(*) from atlas_planning.purchase_demand_references),0::bigint,'generation creates no purchase demand from zero');

create function pg_temp.ng_change_attendance(p_name text,p_date date,p_portions integer) returns void language plpgsql as $$
declare v_rows jsonb; v_batch atlas_planning.attendance_batches%rowtype;
begin
 select batch.* into strict v_batch from atlas_planning.attendance_batches batch where period_start='2026-10-12';
 select atlas_core.rmvp_03a_canonical_attendance_rows(jsonb_agg(row || case
 when row->>'service_date'=p_date::text and row->>'school_id'=pg_temp.ng_id(5004)::text
 then jsonb_build_object('student_portions',p_portions,'teacher_portions',0) else '{}'::jsonb end))
 into v_rows from ng_requests,jsonb_array_elements(request#>'{payload,rows}') row where name='attendance';
 insert into ng_requests values(p_name,pg_temp.ng_request('RMVP-03A.v2','ATTENDANCE_SAVED',jsonb_build_object(
 'week_start','2026-10-12','source_type','BULK_PASTE','source_name','Zero correction Attendance',
 'source_signature',atlas_core.rmvp_03a_attendance_signature(v_rows),'expected_source_signature',v_batch.source_signature,'rows',v_rows))
 ||jsonb_build_object('expected_version',v_batch.version));
 update ng_requests set request=(select request from ng_requests where name=p_name) where name='attendance';
end; $$;
create function pg_temp.ng_generate_request(p_name text,p_date date) returns void language sql as $$
 insert into ng_requests select p_name,
 pg_temp.ng_request('RMVP-04.v3','NEED_GENERATION_EXECUTED',jsonb_build_object(
 'service_date',p_date,'expected_current_need_generation_run_id',run.need_generation_run_id))
 ||jsonb_build_object('expected_version',coalesce(run.version,1))
 from (select 1) seed left join lateral(select * from atlas_planning.need_generation_runs
 where period_start=p_date and period_end=p_date order by attempt_ordinal desc limit 1) run on true;
$$;
-- Retained v1 APIs can release a successor before standalone CMD-15. This
-- rolled-back subcase must not hide an existing positive Confirmed Need batch.
create function pg_temp.ng_readiness_request(p_reason text,p_payload jsonb,p_note text default null)
returns jsonb language sql volatile as $$
 select (pg_temp.ng_request('RMVP-03B.v1',p_reason,p_payload)-'expected_version')||jsonb_build_object(
 'reason_note',p_note,'expected_root_status',input_set.readiness_status,
 'expected_current_evaluation_id',input_set.current_evaluation_id,
 'expected_current_evaluation_version',evaluation.evaluation_version)
 from atlas_planning.planning_input_sets input_set left join atlas_planning.planning_input_evaluations evaluation
 on evaluation.planning_input_evaluation_id=input_set.current_evaluation_id where input_set.period_start='2026-10-12' and input_set.period_end='2026-10-12';
$$;
create function pg_temp.ng_staged_failure() returns trigger language plpgsql as $$ begin raise exception 'Disposable R3 failure after zero bridge'; end $$;
create function pg_temp.ng_staged_zero_successor(p_drift boolean default false,p_fail boolean default false) returns jsonb language plpgsql as $$
declare v_result jsonb;v_preflight jsonb;v_snapshot jsonb;v_run uuid;v_old_run uuid;v_old_batch uuid;v_set uuid;v_eval uuid;v_version bigint;v_request jsonb;v_replay jsonb;v_batch_version bigint;v_child_id uuid;
begin
 begin
  select current_need_generation_run_id,confirmed_need_batch_id into strict v_old_run,v_old_batch from atlas_planning.confirmed_need_batches where period_start='2026-10-12';
  select version into v_batch_version from atlas_planning.confirmed_need_batches where confirmed_need_batch_id=v_old_batch;
  v_result:=atlas_api.invalidate_need_generation_run(pg_temp.ng_request('RMVP-04.v1','UPSTREAM_SOURCE_CHANGED',jsonb_build_object('need_generation_run_id',v_old_run))||jsonb_build_object('expected_version',3));
  if v_result->>'success'<>'true' then raise exception 'Staged v1 invalidation failed: %',v_result; end if;
  select planning_input_set_id into strict v_set from atlas_planning.planning_input_sets where period_start='2026-10-12' and period_end='2026-10-12';
  v_result:=atlas_api.invalidate_planning_input_readiness(pg_temp.ng_readiness_request('UPSTREAM_SOURCE_CHANGED',jsonb_build_object('planning_input_set_id',v_set,'period_start','2026-10-12','period_end','2026-10-12')));
  if v_result->>'success'<>'true' then raise exception 'Staged v1 readiness invalidation failed: %',v_result; end if;
  v_preflight:=atlas_core.planning_contract_01_preflight_payload('2026-10-12','2026-10-12',null);
  v_result:=atlas_api.evaluate_planning_input_readiness(pg_temp.ng_readiness_request('READINESS_EVALUATION_REQUESTED',jsonb_build_object(
   'period_start','2026-10-12','period_end','2026-10-12','source_candidates',jsonb_build_object(
   'weekly_menu',jsonb_build_object('weekly_menu_id',v_preflight#>'{source_evidence,weekly_menu,selected,weekly_menu_id}','weekly_menu_version',v_preflight#>'{source_evidence,weekly_menu,selected,weekly_menu_version}','weekly_menu_approval_snapshot_id',v_preflight#>'{source_evidence,weekly_menu,selected,weekly_menu_approval_snapshot_id}'),
   'attendance',jsonb_build_object('attendance_batch_id',v_preflight#>'{source_evidence,attendance,selected,attendance_batch_id}','attendance_version',v_preflight#>'{source_evidence,attendance,selected,attendance_version}','attendance_approval_snapshot_id',v_preflight#>'{source_evidence,attendance,selected,attendance_approval_snapshot_id}'),
   'pantry',jsonb_build_object('pantry_need_batch_id',v_preflight#>'{source_evidence,pantry,selected,pantry_need_batch_id}','pantry_need_batch_version',v_preflight#>'{source_evidence,pantry,selected,pantry_need_batch_version}','pantry_need_approval_snapshot_id',v_preflight#>'{source_evidence,pantry,selected,pantry_need_approval_snapshot_id}')))));
  if v_result->>'success'<>'true' then raise exception 'Staged v1 readiness failed: %',v_result; end if;
  select input_set.current_evaluation_id,evaluation.evaluation_version into v_eval,v_version from atlas_planning.planning_input_sets input_set join atlas_planning.planning_input_evaluations evaluation on evaluation.planning_input_evaluation_id=input_set.current_evaluation_id where input_set.planning_input_set_id=v_set;
  v_result:=atlas_api.request_planning_input_need_generation(pg_temp.ng_readiness_request('NEED_GENERATION_HANDOFF_REQUESTED',jsonb_build_object('planning_input_set_id',v_set,'period_start','2026-10-12','period_end','2026-10-12')));
  if v_result->>'success'<>'true' then raise exception 'Staged v1 request failed: %',v_result; end if;
  v_result:=atlas_api.create_need_generation_run(pg_temp.ng_request('RMVP-04.v1','NEED_GENERATION_CREATED',jsonb_build_object('planning_input_set_id',v_set,'planning_input_evaluation_id',v_eval,'period_start','2026-10-12','period_end','2026-10-12'))||jsonb_build_object('expected_version',v_version,'reason_note',null));
  if v_result->>'success'<>'true' then raise exception 'Staged v1 creation failed: %',v_result; end if;
  v_run:=(v_result#>>'{affected_aggregate_ids,need_generation_run_id}')::uuid;
  v_result:=atlas_api.validate_need_generation_run(pg_temp.ng_request('RMVP-04.v1','NEED_GENERATION_VALIDATED',jsonb_build_object('need_generation_run_id',v_run))||jsonb_build_object('expected_version',1,'reason_note',null));
  if v_result->>'success'<>'true' then raise exception 'Staged v1 validation failed: %',v_result; end if;
  v_result:=atlas_api.release_need_generation_run(pg_temp.ng_request('RMVP-04.v1','NEED_GENERATION_RELEASED',jsonb_build_object('need_generation_run_id',v_run))||jsonb_build_object('expected_version',2,'reason_note',null));
  if v_result->>'success'<>'true' then raise exception 'Staged v1 release failed: %',v_result; end if;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.ng_id(102),'role','authenticated')::text,true);
  v_result:=atlas_api.create_confirmed_needs_from_generation(pg_temp.ng_request('PA-06E-H0C.v1','CONFIRMED_NEED_CORRECTED',jsonb_build_object('need_generation_run_id',v_run,'need_generation_run_version',3,'confirmed_need_batch_id',v_old_batch))||jsonb_build_object('requested_by_auth_subject',pg_temp.ng_id(102),'expected_version',(select version from atlas_planning.confirmed_need_batches where confirmed_need_batch_id=v_old_batch),'reason_note',null));
  if v_result->>'error_code'<>'SCOPE_DENIED' then raise exception 'Zero withdrawal escaped complete audit scope: %',v_result; end if;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.ng_id(101),'role','authenticated')::text,true);
  if p_drift then
    perform pg_temp.ng_change_attendance('staged-source-drift','2026-10-12',100);
    v_result:=atlas_api.save_attendance((select request from ng_requests where name='staged-source-drift'));
    if v_result->>'success'<>'true' then raise exception 'Staged source drift save failed: %',v_result; end if;
  end if;
  v_preflight:=atlas_core.planning_contract_01_preflight_payload('2026-10-12','2026-10-12',null);
  if v_preflight#>>'{current_need,need_generation_release_snapshot_id}'<>(select need_generation_release_snapshot_id::text from atlas_planning.need_generation_release_snapshots where need_generation_run_id=v_run) then raise exception 'Staged cursor paired R2 with the wrong release'; end if;
  v_snapshot:=jsonb_build_object('currentness',v_preflight->>'downstream_currentness',
  'selected_old_batch',v_preflight#>>'{current_need,confirmed_need_batch_id}'=v_old_batch::text,
  'selected_old_run',v_preflight#>>'{current_need,need_generation_run_id}'=v_old_run::text,
  'old_positive_revisions',(select count(*) from atlas_planning.confirmed_need_line_revisions where confirmed_need_batch_id=v_old_batch and is_current and theoretical_quantity>0),
  'zero_observations',(select count(*) from atlas_planning.theoretical_need_lines where need_generation_run_id=v_run and line_disposition='ACTIVE' and theoretical_quantity=0));
  v_request:=pg_temp.ng_request('RMVP-04.v2','NEED_GENERATION_EXECUTED',jsonb_build_object(
   'period_start','2026-10-12','period_end','2026-10-12',
   'expected_current_need_generation_run_id',v_preflight#>'{current_need,need_generation_run_id}'))
   ||jsonb_build_object('expected_version',(v_preflight#>>'{current_need,need_generation_run_version}')::bigint,'idempotency_key',repeat('x',200));
  v_child_id:=md5((v_request->>'command_id')||':zero-bridge:'||v_run::text)::uuid;
  if p_fail then
    execute 'create trigger ng_staged_rollback before insert on atlas_planning.confirmed_need_line_revisions for each row execute function pg_temp.ng_staged_failure()';
  end if;
  v_result:=atlas_api.execute_need_generation(v_request);
  v_replay:=atlas_api.execute_need_generation(v_request);
  if v_result is distinct from v_replay then raise exception 'Staged command replay drifted'; end if;
  if v_result->>'success'='true' and v_result-array['success','contract_version','command_id','correlation_id',
    'idempotency_status','affected_aggregate_ids','new_versions','result_counts','emitted_event_ids','audit_event_ids',
    'authoritative_readback','downstream_currentness','safe_operator_message','warnings','blockers']<>'{}'::jsonb then
    raise exception 'Atomic success exposed internal orchestration evidence';
  end if;
  if p_drift and not p_fail and v_result->>'success'='true' then
    if (select version from atlas_planning.confirmed_need_batches where confirmed_need_batch_id=v_old_batch)<>v_batch_version+2
       or (select count(*) from atlas_audit.domain_events where command_id in ((v_request->>'command_id')::uuid,v_child_id) and event_type='ConfirmedNeedsRematerialized')<>2
       or (select count(*) from atlas_audit.audit_events where command_id in ((v_request->>'command_id')::uuid,v_child_id) and event_type='ConfirmedNeedsRematerialized')<>2
       or (select count(*) from atlas_core.command_receipts receipt
           join atlas_audit.domain_events event using(command_receipt_id,command_id,correlation_id)
           join atlas_audit.audit_events audit using(command_receipt_id,command_id,correlation_id)
           where receipt.command_id=v_child_id and receipt.outcome='COMPLETED'
             and receipt.correlation_id=(v_request->>'correlation_id')::uuid
             and receipt.response_payload->>'success'='true'
             and (receipt.response_payload#>>'{new_versions,confirmed_need_batch_version}')::bigint=v_batch_version+1
             and event.event_type='ConfirmedNeedsRematerialized'
             and audit.event_type='ConfirmedNeedsRematerialized')<>1 then
      raise exception 'Staged source drift did not preserve both receipt/event/version transitions';
    end if;
  end if;
  if p_fail then
    if v_result->>'success'<>'false' or v_result->>'write_certainty'<>'NO_COMMITTED_CHANGE'
      or exists(select 1 from atlas_core.command_receipts where command_id=v_child_id)
      or exists(select 1 from atlas_audit.domain_events where command_id=v_child_id)
      or exists(select 1 from atlas_audit.audit_events where command_id=v_child_id)
      or (select version from atlas_planning.confirmed_need_batches where confirmed_need_batch_id=v_old_batch)<>v_batch_version
      or (select current_need_generation_run_id from atlas_planning.confirmed_need_batches where confirmed_need_batch_id=v_old_batch)<>v_old_run then
      raise exception 'Failed R3 retained intermediate zero correction';
    end if;
    v_snapshot:=jsonb_build_object('rolled_back_child',true,'exact_failure_replay',true);
    raise sqlstate 'ZD001' using message='Rollback retained-v1 failure regression';
  end if;
  if v_result->>'success'<>'true' then raise notice 'Staged atomic result: %',v_result; end if;
  v_snapshot:=v_snapshot||jsonb_build_object('adopted',v_result->>'success'='true',
   'adopted_staged_run',(select current_need_generation_run_id=v_run from atlas_planning.confirmed_need_batches where confirmed_need_batch_id=v_old_batch),
   'current_revisions_after',(select count(*) from atlas_planning.confirmed_need_line_revisions where confirmed_need_batch_id=v_old_batch and is_current),
   'run_count_after',(select count(*) from atlas_planning.need_generation_runs where period_start='2026-10-12'));
  raise sqlstate 'ZD001' using message='Rollback retained-v1 regression subcase';
 exception when sqlstate 'ZD001' then return v_snapshot; end;
end; $$;
create temp table original_revisions as select * from atlas_planning.confirmed_need_line_revisions where service_date='2026-10-12';
select pg_temp.ng_change_attendance('attendance-zero','2026-10-12',0);
set local role authenticated;
insert into ng_results select 'attendance-zero',atlas_api.save_attendance(request),null from ng_requests where name='attendance-zero';
select is((select response->>'success' from ng_results where name='attendance-zero'),'true','legitimate positive-to-zero source correction saves');
reset role;
select is(pg_temp.ng_staged_zero_successor(),jsonb_build_object('currentness','OUTDATED','selected_old_batch',true,'selected_old_run',false,'old_positive_revisions',4,'zero_observations',13,'adopted',true,'adopted_staged_run',true,'current_revisions_after',0,'run_count_after',2),'retained v1 zero successor cannot hide unmaterialized positive Confirmed Need authority');
select is(pg_temp.ng_staged_zero_successor(true),jsonb_build_object('currentness','OUTDATED','selected_old_batch',true,'selected_old_run',false,'old_positive_revisions',4,'zero_observations',13,'adopted',true,'adopted_staged_run',false,'current_revisions_after',4,'run_count_after',3),'staged zero bridges before newer factual source demand generates R3; scoped withdrawal stays denied');
select is(pg_temp.ng_staged_zero_successor(true,true),jsonb_build_object('rolled_back_child',true,'exact_failure_replay',true),'failure after zero bridge rolls back child receipt/event/audit/batch and exactly replays outer failure');
select pg_temp.ng_generate_request('correct-to-zero','2026-10-12');
set local role authenticated;
insert into ng_results select 'correct-to-zero',atlas_api.execute_need_generation(request),null from ng_requests where name='correct-to-zero';
select is((select response->>'success' from ng_results where name='correct-to-zero'),'true','previous positive demand corrects to no-demand');
select diag(response::text) from ng_results where name='correct-to-zero' and response->>'success'<>'true';
reset role;
select is((select count(*) from atlas_planning.confirmed_need_line_revisions where service_date='2026-10-12' and is_current),0::bigint,'zero correction retires current demand without zero successor');
select is((select count(*) from atlas_planning.confirmed_need_line_revisions revision join original_revisions original using(confirmed_need_line_revision_id)
 where revision.theoretical_quantity=original.theoretical_quantity and revision.revision_status='SUPERSEDED' and not revision.is_current),4::bigint,'original exact quantities and history are preserved');
select is((select count(*) from atlas_planning.need_generation_runs where period_start='2026-10-12'),2::bigint,'correction retains both run generations');
set local role authenticated;
insert into ng_results select 'prepare-zero',atlas_api.prepare_school_catering_purchase_orders(
 pg_temp.ng_request('PURCHASE-COMMITMENT.v1','PURCHASE_ORDERS_PREPARED',jsonb_build_object(
 'service_date','2026-10-12','confirmed_need_batch_id',response#>'{affected_aggregate_ids,confirmed_need_batch_id}'))
 ||jsonb_build_object('expected_version',(response#>>'{new_versions,confirmed_need_batch_version}')::bigint,'reason_note',null)),null
 from ng_results where name='correct-to-zero';
select is((select response->>'success' from ng_results where name='prepare-zero'),'false','all-zero current batch cannot prepare purchase authority');
reset role;
select is((select count(*) from atlas_planning.purchase_handoff_batches),0::bigint,'rejected zero preparation creates no Purchase Handoff');
select is((select count(*) from atlas_procurement.purchase_orders),0::bigint,'rejected zero preparation creates no PO');
-- A zero-only predecessor never had a materialized contribution.
select pg_temp.ng_change_attendance('attendance-reactivate','2026-10-12',100);
set local role authenticated;
insert into ng_results select 'attendance-reactivate',atlas_api.save_attendance(request),null from ng_requests where name='attendance-reactivate';
reset role;
insert into atlas_admin.delivery_locations(delivery_location_id,customer_id,location_code,location_name,address_text)
values(pg_temp.ng_id(91),pg_temp.ng_id(10),'zero-gap-new-location','Changed default during zero gap','Local fixture');
update atlas_admin.schools set default_delivery_location_id=pg_temp.ng_id(91) where school_id=pg_temp.ng_id(5004);
set local role authenticated;
insert into ng_results select 'zero-audit-destination',atlas_api.get_need_generation_workbench(jsonb_build_object(
 'contract_version','RMVP-04.v1','requested_by_auth_subject',pg_temp.ng_id(101),'correlation_id',gen_random_uuid(),
 'payload',jsonb_build_object('period_start','2026-10-12','period_end','2026-10-12','need_generation_run_id',response#>'{affected_aggregate_ids,need_generation_run_id}',
 'filters','{}'::jsonb,'group_offset',0,'group_limit',100,'detail_group',jsonb_build_object('service_date','2026-10-12','school_id',pg_temp.ng_id(5004),'delivery_location_id',pg_temp.ng_id(11),'ingredient_id',pg_temp.ng_id(2001),'unit_id',pg_temp.ng_id(13))))),null from ng_results where name='correct-to-zero';
select is((select count(*) from ng_results,jsonb_array_elements(response#>'{workbench,grouped_requirements}') row where name='zero-audit-destination' and row->>'school_id'=pg_temp.ng_id(5004)::text and row->>'delivery_location_id'=pg_temp.ng_id(11)::text),4::bigint,'zero audit groups retain captured destination after a School-default change');
select is((select jsonb_array_length(response#>'{workbench,atomic_detail}') from ng_results where name='zero-audit-destination'),1,'zero atomic audit detail remains findable under its captured destination');
reset role;
select pg_temp.ng_generate_request('reactivate-destination','2026-10-12');
set local role authenticated;
insert into ng_results select 'reactivate-destination',atlas_api.execute_need_generation(request),null from ng_requests where name='reactivate-destination';
select is((select response->>'error_code' from ng_results where name='reactivate-destination'),'OPERATIONAL_IDENTITY_UNAPPROVED','zero gap cannot silently move an existing operational identity');
reset role;
select is((select count(*) from atlas_planning.need_generation_runs where period_start='2026-10-12'),2::bigint,'rejected destination change rolls back the successor run');
update atlas_admin.schools set default_delivery_location_id=pg_temp.ng_id(11) where school_id=pg_temp.ng_id(5004);
select pg_temp.ng_generate_request('reactivate','2026-10-12');
set local role authenticated;
insert into ng_results select 'reactivate',atlas_api.execute_need_generation(request),null from ng_requests where name='reactivate';
select is((select response->>'success' from ng_results where name='reactivate'),'true','positive demand can return across a zero-only gap');
select diag(response::text) from ng_results where name='reactivate' and response->>'success'<>'true';
reset role;
select is((select count(*) from atlas_planning.confirmed_need_line_revisions current_revision join original_revisions original using(confirmed_need_line_id)
 where current_revision.is_current and current_revision.predecessor_revision_id=original.confirmed_need_line_revision_id),4::bigint,'reactivation reuses stable line identity and immutable predecessor revisions');
select pg_temp.ng_change_attendance('attendance-zero-to-positive','2026-10-13',100);
set local role authenticated;
insert into ng_results select 'attendance-zero-to-positive',atlas_api.save_attendance(request),null from ng_requests where name='attendance-zero-to-positive';
select is((select response->>'success' from ng_results where name='attendance-zero-to-positive'),'true','initial no-demand does not block factual Attendance correction');
reset role;
select pg_temp.ng_generate_request('zero-to-positive','2026-10-13');
set local role authenticated;
insert into ng_results select 'zero-to-positive',atlas_api.execute_need_generation(request),null from ng_requests where name='zero-to-positive';
select is((select response->>'success' from ng_results where name='zero-to-positive'),'true','initial no-demand can become positive without fake predecessor contribution');
select is((select response#>>'{authoritative_readback,preflight,demand_state}' from ng_results where name='zero-to-positive'),'POSITIVE_DEMAND','zero-to-positive readback proves positive authority');
select diag(response::text) from ng_results where name='zero-to-positive' and response->>'success'<>'true';
reset role;
-- Force rejection after run/release/materialization writes, inside the atomic command.
create function pg_temp.ng_reject_materialization() returns trigger language plpgsql as $$
begin raise exception 'Forced atomic rollback'; end; $$;
create trigger ng_forced_rollback before insert on atlas_planning.confirmed_need_line_revisions
for each row execute function pg_temp.ng_reject_materialization();
select pg_temp.ng_generate_request('rollback','2026-10-15');
set local role authenticated;
insert into ng_results select 'rollback',atlas_api.execute_need_generation(request),null from ng_requests where name='rollback';
select is((select response->>'success' from ng_results where name='rollback'),'false','forced late materialization rejection returns failure');
select is((select response->>'write_certainty' from ng_results where name='rollback'),'NO_COMMITTED_CHANGE','atomic failure proves no committed business change');
insert into ng_results select 'rollback-replay',atlas_api.execute_need_generation(request),null from ng_requests where name='rollback';
select is((select response from ng_results where name='rollback-replay'),(select response from ng_results where name='rollback'),'deterministic failure exact replay retains certainty');
reset role;
select is((select count(*) from atlas_planning.need_generation_runs where period_start='2026-10-15'),0::bigint,'rollback leaves no partial run');
select is((select count(*) from atlas_planning.need_generation_release_snapshots release join atlas_planning.need_generation_runs run using(need_generation_run_id) where run.period_start='2026-10-15'),0::bigint,'rollback leaves no partial release');
select is((select count(*) from atlas_planning.confirmed_need_batches where period_start='2026-10-15'),0::bigint,'rollback leaves no partial Confirmed Need');
select is((select count(*) from atlas_core.command_receipts where command_id=(select (request->>'command_id')::uuid from ng_requests where name='rollback')),1::bigint,'only deterministic failure receipt remains');
drop trigger ng_forced_rollback on atlas_planning.confirmed_need_line_revisions;
select pg_temp.ng_generate_request('positive-only','2026-10-15');
set local role authenticated;
insert into ng_results select 'positive-only',atlas_api.execute_need_generation(request),null from ng_requests where name='positive-only';
select is((select response->>'success' from ng_results where name='positive-only'),'true','positive-only day remains unchanged');
reset role;
select is((select count(*) from atlas_planning.confirmed_need_line_revisions where service_date='2026-10-15' and is_current and theoretical_quantity=1.234567),13::bigint,'all 13 positive-only groups retain exact quantities');

-- Early rejection has explicit certainty; no malformed intent is submitted.
set local role authenticated;
insert into ng_results select 'auth-rejection',atlas_api.execute_need_generation(jsonb_set(request,'{requested_by_auth_subject}',to_jsonb(pg_temp.ng_id(999)))),null from ng_requests where name='positive-only';
select is((select response->>'error_code' from ng_results where name='auth-rejection'),'AUTH_SUBJECT_MISMATCH','pre-execution rejection is deterministic');
select is((select response->>'write_certainty' from ng_results where name='auth-rejection'),'NO_COMMITTED_CHANGE','pre-execution rejection proves no business write');
reset role;

-- Confirm and release positive Need using the existing commands, then attempt
-- a zero successor. Its released authority must remain unchanged.
insert into ng_requests select 'save-positive',pg_temp.ng_request('RMVP-05.v2','CONFIRMED_NEED_SAVED',jsonb_build_object(
 'confirmed_need_batch_id',batch.confirmed_need_batch_id,'lines',jsonb_agg(jsonb_build_object(
 'confirmed_need_line_id',line.confirmed_need_line_id,'expected_current_revision_id',revision.confirmed_need_line_revision_id,
 'expected_current_decision_id',line.current_confirmed_need_line_decision_id,'proposed_confirmed_quantity',revision.confirmed_quantity::text,
 'reason_code','PROPOSAL_ACCEPTED','reason_note',null))))||jsonb_build_object('expected_version',batch.version,'reason_note',null)
from atlas_planning.confirmed_need_batches batch join atlas_planning.confirmed_need_lines line using(confirmed_need_batch_id)
join atlas_planning.confirmed_need_line_revisions revision using(confirmed_need_line_id)
where batch.period_start='2026-10-15' and revision.is_current group by batch.confirmed_need_batch_id,batch.version;
set local role authenticated;
insert into ng_results select 'save-positive',atlas_api.save_confirmed_needs(request),null from ng_requests where name='save-positive';
select is((select response->>'success' from ng_results where name='save-positive'),'true','positive-only Need is confirmed through the real command');
reset role;
insert into atlas_admin.suppliers(supplier_id,supplier_code,supplier_name,document_code) values(pg_temp.ng_id(90),'ZERO-DEMAND-SUPPLIER','Positive-demand test Supplier','ZD-SUPPLIER');
insert into atlas_admin.supplier_eligibilities(supplier_id,ingredient_id,effective_from,priority,reason_note)
select pg_temp.ng_id(90),ingredient_id,'2020-01-01',1,'Local positive allocation fixture' from atlas_admin.ingredients where ingredient_code like 'zero-demand-%';
set local role authenticated;
insert into ng_results values('allocation-positive',atlas_api.get_confirmed_supplier_allocation_workbench(jsonb_build_object(
 'contract_version','CONFIRMED-SUPPLIER-ALLOCATION.v1','requested_by_auth_subject',pg_temp.ng_id(101),'correlation_id',gen_random_uuid(),
 'payload',jsonb_build_object('date_start','2026-10-15','date_end','2026-10-15'))),null);
insert into ng_results select 'allocated-'||(row->>'ingredient_id'),atlas_api.save_confirmed_supplier_allocation(
 pg_temp.ng_request('CONFIRMED-SUPPLIER-ALLOCATION.v1','CONFIRMED_SUPPLIER_ALLOCATION_SAVED',jsonb_build_object(
 'family',jsonb_build_object('service_date',row->'service_date','delivery_location_id',row->'delivery_location_id','ingredient_id',row->'ingredient_id','unit_id',row->'unit_id',
 'expected_source_fingerprint',row#>'{family,source_fingerprint}','expected_source_batch_id',row#>'{family,source_confirmed_need_batch_id}',
 'expected_source_batch_version',row#>'{family,source_confirmed_need_batch_version}'),'splits',jsonb_build_array(jsonb_build_object('supplier_id',pg_temp.ng_id(90),'allocated_quantity',row->'family_quantity'))))
 ||jsonb_build_object('expected_version',(row#>>'{family,version}')::bigint,'reason_note',null)),null
from ng_results,jsonb_array_elements(response->'rows') row where name='allocation-positive';
select is((select count(*) from ng_results where name like 'allocated-%' and response->>'success'='true'),4::bigint,'all positive allocation families save through the real command');
select diag(response::text) from ng_results where name like 'allocated-%' and response->>'success'<>'true';
reset role;
insert into ng_requests select 'release-positive',pg_temp.ng_request('RMVP-07.v2','CONFIRMED_NEED_RELEASED',jsonb_build_object(
 'confirmed_need_batch_id',confirmed_need_batch_id))||jsonb_build_object('expected_version',version,'reason_note',null)
from atlas_planning.confirmed_need_batches where period_start='2026-10-15';
set local role authenticated;
insert into ng_results select 'release-positive',atlas_api.release_confirmed_needs(request),null from ng_requests where name='release-positive';
select is((select response->>'success' from ng_results where name='release-positive'),'true','positive authority is released through the real command');
select diag(response::text) from ng_results where name='release-positive' and response->>'success'<>'true';
reset role;
insert into ng_requests select 'prepare-positive',pg_temp.ng_request('PURCHASE-COMMITMENT.v1','PURCHASE_ORDERS_PREPARED',jsonb_build_object(
 'confirmed_need_batch_id',confirmed_need_batch_id,'service_date','2026-10-15'))||jsonb_build_object('expected_version',version,'reason_note',null)
from atlas_planning.confirmed_need_batches where period_start='2026-10-15';
set local role authenticated;
insert into ng_results select 'prepare-positive',atlas_api.prepare_school_catering_purchase_orders(request),null from ng_requests where name='prepare-positive';
select is((select response->>'success' from ng_results where name='prepare-positive'),'true','positive released Need prepares real purchase authority');
select diag(response::text) from ng_results where name='prepare-positive' and response->>'success'<>'true';
reset role;
insert into ng_requests select 'release-po',pg_temp.ng_request('SCHOOL-CATERING-PROCUREMENT.v1','SCHOOL_CATERING_PO_RELEASED',jsonb_build_object(
 'purchase_order_id',po.purchase_order_id,'expected_purchase_order_revision_id',revision.purchase_order_revision_id))||jsonb_build_object('expected_version',po.version,'reason_note',null)
from atlas_procurement.purchase_orders po join atlas_procurement.purchase_order_revisions revision using(purchase_order_id)
where po.school_catering_service_date='2026-10-15' and revision.is_current;
set local role authenticated;
insert into ng_results select 'release-po',atlas_api.release_school_catering_purchase_order(request),null from ng_requests where name='release-po';
select is((select response->>'success' from ng_results where name='release-po'),'true','positive supplier PO is released through the real command');
select diag(response::text) from ng_results where name='release-po' and response->>'success'<>'true';
reset role;
create temp table released_po_before as select to_jsonb(po) as fact from atlas_procurement.purchase_orders po where school_catering_service_date='2026-10-15';
create temp table released_po_line_before as select to_jsonb(line) as fact from atlas_procurement.purchase_order_line_revisions line;
create temp table released_before as select to_jsonb(batch) as fact from atlas_planning.confirmed_need_batches batch where period_start='2026-10-15';
create temp table released_revision_before as select to_jsonb(revision) as fact from atlas_planning.confirmed_need_line_revisions revision where service_date='2026-10-15';
select pg_temp.ng_change_attendance('attendance-downstream-zero','2026-10-15',0);
set local role authenticated;
insert into ng_results select 'attendance-downstream-zero',atlas_api.save_attendance(request),null from ng_requests where name='attendance-downstream-zero';
select is((select response->>'success' from ng_results where name='attendance-downstream-zero'),'false','factual zero correction cannot bypass released downstream authority');
reset role;
-- Save may first require the existing upstream correction workflow. Either
-- way the atomic generation command must not silently rewrite released Need.
select pg_temp.ng_generate_request('downstream-correction','2026-10-15');
insert into ng_requests select 'invalidate-released',pg_temp.ng_request('RMVP-04.v1','PLANNING_CORRECTION',jsonb_build_object('need_generation_run_id',need_generation_run_id))
||jsonb_build_object('expected_version',version,'reason_note','Zero demand correction requires downstream workflow')
from atlas_planning.need_generation_runs where period_start='2026-10-15';
set local role authenticated;
insert into ng_results select 'invalidate-released',atlas_api.invalidate_need_generation_run(request),null from ng_requests where name='invalidate-released';
select is((select response->>'error_code' from ng_results where name='invalidate-released'),'DOWNSTREAM_CORRECTION_REQUIRED','released positive authority requires the existing correction boundary before zero regeneration');
reset role;
select is((select to_jsonb(batch) from atlas_planning.confirmed_need_batches batch where period_start='2026-10-15'),(select fact from released_before),'released batch facts are unchanged by rejected zero correction');
select is((select jsonb_agg(to_jsonb(revision) order by confirmed_need_line_revision_id) from atlas_planning.confirmed_need_line_revisions revision where service_date='2026-10-15'),
 (select jsonb_agg(fact order by fact->>'confirmed_need_line_revision_id') from released_revision_before),'released quantities and revision facts are unchanged');
select is((select to_jsonb(po) from atlas_procurement.purchase_orders po where school_catering_service_date='2026-10-15'),(select fact from released_po_before),'released supplier PO remains byte-for-byte unchanged');
select is((select jsonb_agg(to_jsonb(line) order by purchase_order_line_revision_id) from atlas_procurement.purchase_order_line_revisions line),
 (select jsonb_agg(fact order by fact->>'purchase_order_line_revision_id') from released_po_line_before),'released purchase quantities remain byte-for-byte unchanged');
select * from finish();
rollback;
