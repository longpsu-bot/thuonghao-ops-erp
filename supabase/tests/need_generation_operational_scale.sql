-- Disposable local/CI only. All source and generation constraints stay enabled.
-- 30 Schools x 4 Dishes x 4 Recipe Ingredients = 480 daily atomic contributions.
begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = pg_catalog, public, extensions;
select plan(16);
create function pg_temp.ng_id(n bigint) returns uuid language sql immutable as $$
  select ('a7400000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
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
values(pg_temp.ng_id(3),'need-scale-operator','Need scale operator');
insert into atlas_core.role_capabilities(role_id,capability_id)
select pg_temp.ng_id(3),capability_id from atlas_core.capabilities
where capability_code like 'planning.%' or capability_code like 'confirmed_need%';
insert into atlas_core.actor_role_memberships(actor_id,role_id)
values(pg_temp.ng_id(1),pg_temp.ng_id(3));
insert into atlas_core.actor_scopes(actor_id,scope_kind) values(pg_temp.ng_id(1),'GLOBAL');
insert into atlas_admin.customers(customer_id,customer_code,customer_name,customer_type)
values(pg_temp.ng_id(10),'need-scale-customer','Need scale customer','SCHOOL_CATERING');
insert into atlas_admin.delivery_locations(delivery_location_id,customer_id,location_code,location_name,address_text,timezone_name)
values(pg_temp.ng_id(11),pg_temp.ng_id(10),'need-scale-kitchen','Need scale kitchen','Disposable fixture','Asia/Ho_Chi_Minh');
insert into atlas_admin.school_types(school_type_id,school_type_code,school_type_name)
values(pg_temp.ng_id(12),'need-scale-type','Need scale type');
insert into atlas_admin.units(unit_id,unit_code,unit_name,dimension_code)
values(pg_temp.ng_id(13),'need-scale-kg','Need scale kilogram','mass');
insert into atlas_admin.schools(school_id,customer_id,school_code,school_name,school_type_id,default_delivery_location_id,display_order)
select pg_temp.ng_id(5000+i),pg_temp.ng_id(10),'need-scale-school-'||i,'Need scale school '||i,
  pg_temp.ng_id(12),pg_temp.ng_id(11),i from generate_series(1,30) i;
insert into atlas_admin.ingredients(ingredient_id,ingredient_code,ingredient_name,purchase_unit_id)
select pg_temp.ng_id(2000+i),'need-scale-ingredient-'||i,'Need scale ingredient '||i,pg_temp.ng_id(13)
from generate_series(1,4) i;
insert into atlas_admin.dishes(dish_id,dish_code,dish_name,dish_type_id,requires_need_generation,dish_status)
select pg_temp.ng_id(1000+i),'need-scale-dish-'||i,'Need scale dish '||i,t.dish_type_id,true,'ACTIVE'
from unnest(array['soup','savory','stir_fry','dessert']) with ordinality d(code,i)
join atlas_admin.dish_types t on t.dish_type_code=d.code;
insert into atlas_admin.recipes(recipe_id,dish_id,school_type_id)
select pg_temp.ng_id(1100+i),pg_temp.ng_id(1000+i),pg_temp.ng_id(12) from generate_series(1,4) i;
insert into atlas_admin.recipe_versions(recipe_version_id,recipe_id,version_number,basis_portions,created_by_actor_id)
select pg_temp.ng_id(1200+i),pg_temp.ng_id(1100+i),1,100,pg_temp.ng_id(1) from generate_series(1,4) i;
insert into atlas_admin.recipe_lines(recipe_line_id,recipe_id,line_code)
select pg_temp.ng_id(3000+i*100+j),pg_temp.ng_id(1100+i),'ingredient-'||j
from generate_series(1,4) i cross join generate_series(1,4) j;
insert into atlas_admin.recipe_line_revisions(recipe_line_revision_id,recipe_id,recipe_version_id,recipe_line_id,line_revision_number,ingredient_id,quantity_per_basis,unit_id,created_by_actor_id)
select pg_temp.ng_id(4000+i*100+j),pg_temp.ng_id(1100+i),pg_temp.ng_id(1200+i),
 pg_temp.ng_id(3000+i*100+j),1,pg_temp.ng_id(2000+j),1.234567,pg_temp.ng_id(13),pg_temp.ng_id(1)
from generate_series(1,4) i cross join generate_series(1,4) j;
update atlas_admin.recipe_versions set recipe_version_status='VALIDATED',validated_by_actor_id=pg_temp.ng_id(1),validated_at=now()
where recipe_version_id in(select pg_temp.ng_id(1200+i) from generate_series(1,4) i);
update atlas_admin.recipe_versions set recipe_version_status='RELEASED_FOR_PLANNING',released_by_actor_id=pg_temp.ng_id(1),released_at=now()
where recipe_version_id in(select pg_temp.ng_id(1200+i) from generate_series(1,4) i);
insert into atlas_planning.need_generation_calculation_contracts(need_generation_calculation_contract_id,contract_code,current_revision_id,version)
values(pg_temp.ng_id(20),'school_catering_proportional_per_basis',pg_temp.ng_id(21),1);
insert into atlas_planning.need_generation_calculation_contract_revisions(need_generation_calculation_contract_revision_id,need_generation_calculation_contract_id,revision_number,formula_kind,quantity_precision,quantity_scale,factor_precision,factor_scale,final_coercion_mode,approved_by_actor_id,approved_at)
values(pg_temp.ng_id(21),pg_temp.ng_id(20),1,'STUDENT_TEACHER_PORTIONS_X_RECIPE_QTY_DIV_BASIS',20,6,24,12,'POSTGRES_NUMERIC_SCALE_HALF_AWAY_FROM_ZERO',pg_temp.ng_id(1),now());
set constraints all immediate;
set constraints all deferred;
create temp table ng_requests(name text primary key,request jsonb not null);
create temp table ng_results(name text primary key,response jsonb not null,elapsed_ms numeric);
grant select,insert,update on ng_results to authenticated;
grant select on ng_requests to authenticated;
with rows as (
 select pg_temp.ng_id(5000+s) as school_id,date '2050-09-19'+day as service_date,
   t.dish_type_code as menu_slot_code,d.dish_id,'scale:'||s||':'||day||':'||d.dish_code as source_row_reference
 from generate_series(1,30) s cross join generate_series(0,4) day
 cross join atlas_admin.dishes d join atlas_admin.dish_types t using(dish_type_id)
 where d.dish_code like 'need-scale-dish-%'
), canonical as (select atlas_core.rmvp_03a_canonical_menu_rows(jsonb_agg(to_jsonb(rows))) as rows from rows)
insert into ng_requests select 'menu',pg_temp.ng_request('RMVP-03A.v2','WEEKLY_MENU_SAVED',
jsonb_build_object('week_start','2050-09-19','source_type','GOOGLE_SHEET','source_name','Local scale Menu',
'source_signature',atlas_core.rmvp_03a_menu_signature(rows),'expected_source_signature',null,'rows',rows)) from canonical;
with rows as (
 select pg_temp.ng_id(5000+s) as school_id,date '2050-09-19'+day as service_date,
  95 as student_portions,5 as teacher_portions,'scale:'||s||':'||day as source_row_reference
 from generate_series(1,30) s cross join generate_series(0,4) day
), canonical as (select atlas_core.rmvp_03a_canonical_attendance_rows(jsonb_agg(to_jsonb(rows))) as rows from rows)
insert into ng_requests select 'attendance',pg_temp.ng_request('RMVP-03A.v2','ATTENDANCE_SAVED',
jsonb_build_object('week_start','2050-09-19','source_type','BULK_PASTE','source_name','Local scale Attendance',
'source_signature',atlas_core.rmvp_03a_attendance_signature(rows),'expected_source_signature',null,'rows',rows)) from canonical;
insert into ng_requests select 'pantry',pg_temp.ng_request('PANTRY-02.v2','PANTRY_SAVED',
jsonb_build_object('week_start','2050-09-19','no_additions_confirmed',true,'source_signature',
atlas_core.pantry_02_signature('2050-09-19',true,'[]'::jsonb),'expected_source_signature',null,'rows','[]'::jsonb));
insert into ng_requests select 'generate',pg_temp.ng_request('RMVP-04.v3','NEED_GENERATION_EXECUTED',
jsonb_build_object('service_date','2050-09-19','expected_current_need_generation_run_id',null));
select set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.ng_id(101),'role','authenticated')::text,true);
set local role authenticated;
insert into ng_results select 'menu',atlas_api.save_weekly_menu(request),null from ng_requests where name='menu';
select is((select response->>'success' from ng_results where name='menu'),'true','600-assignment weekly Menu is saved through the real command');
select diag(jsonb_build_object('error_code',response->>'error_code','first_blocker',response#>'{blocking_references,0}')::text) from ng_results where name='menu' and response->>'success'<>'true';
insert into ng_results select 'attendance',atlas_api.save_attendance(request),null from ng_requests where name='attendance';
select is((select response->>'success' from ng_results where name='attendance'),'true','150-row Attendance is saved through the real command');
insert into ng_results select 'pantry',atlas_api.save_pantry(request),null from ng_requests where name='pantry';
select is((select response->>'success' from ng_results where name='pantry'),'true','explicit no-additions Pantry is saved');
insert into ng_results select 'preflight',atlas_api.get_planning_input_preflight(jsonb_build_object(
 'contract_version','RMVP-03B.v2','requested_by_auth_subject',pg_temp.ng_id(101),'correlation_id',gen_random_uuid(),
 'payload',jsonb_build_object('period_start','2050-09-19','period_end','2050-09-19'))),null;
select is((select response#>>'{preflight,readiness_state}' from ng_results where name='preflight'),'READY','all three completed sources are ready');
-- This is the production authenticated budget, not a relaxed test timeout.
set local statement_timeout='8s';
with started as materialized(select clock_timestamp() as at), result as materialized(
 select at,atlas_api.execute_need_generation(request) as response from ng_requests cross join started where name='generate'
) insert into ng_results select 'generate',response,1000*extract(epoch from clock_timestamp()-at) from result;
select is((select response->>'success' from ng_results where name='generate'),'true','daily generation completes under eight seconds');
select diag((select jsonb_build_object('elapsed_ms',elapsed_ms,'error_code',response->>'error_code')::text from ng_results where name='generate'));
select is((select response#>>'{authoritative_readback,preflight,downstream_currentness}' from ng_results where name='generate'),'CURRENT','completed Need becomes authoritative current state');
insert into ng_results select 'review',atlas_api.get_confirmed_need_review(jsonb_build_object(
 'contract_version','RMVP-05.v1','requested_by_auth_subject',pg_temp.ng_id(101),'correlation_id',gen_random_uuid(),
 'payload',jsonb_build_object('confirmed_need_batch_id',response#>'{affected_aggregate_ids,confirmed_need_batch_id}',
 'filters',jsonb_build_object('service_date','2050-09-19','school_id',null,'delivery_location_id',null,'ingredient_id',null,'decision_state',null),
 'line_offset',0,'line_limit',10000))),null from ng_results where name='generate';
select is((select response->>'success' from ng_results where name='review'),'true','Confirmed Need review can be read by the operator');
select is((select jsonb_array_length(response#>'{workbench,lines}') from ng_results where name='review'),120,'review contains all 120 School/Ingredient rows');
select is((select response#>>'{workbench,pagination,has_more}' from ng_results where name='review'),'false','review is complete, not silently paginated');
insert into ng_results select 'replay',atlas_api.execute_need_generation(request),null from ng_requests where name='generate';
select is((select response->>'success' from ng_results where name='replay'),'true','explicit identical replay succeeds');
reset role;
select is((select count(*) from atlas_planning.need_generation_runs where period_start='2050-09-19'),1::bigint,'replay creates exactly one generation run');
select is((select count(*) from atlas_planning.theoretical_need_lines where service_date='2050-09-19'),480::bigint,'every atomic Recipe contribution is retained');
select ok((select bool_and(theoretical_quantity=1.234567) from atlas_planning.theoretical_need_lines where service_date='2050-09-19'),'six-decimal proportional quantities are unchanged');
select is((select count(*) from atlas_planning.need_generation_release_snapshot_lines member join atlas_planning.need_generation_runs run using(need_generation_run_id) where run.period_start='2050-09-19'),480::bigint,'release preserves the exact 480-member set');
select throws_ok($$update atlas_planning.theoretical_need_lines set theoretical_quantity=9 where service_date='2050-09-19'$$,'23514',null,'generated evidence remains immutable');
select is((select count(*) from atlas_core.command_receipts where command_id=(select (request->>'command_id')::uuid from ng_requests where name='generate')),1::bigint,'replay retains one command receipt');
select * from finish();
rollback;
