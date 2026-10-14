-- Disposable local/CI only. All source and generation constraints stay enabled.
-- Two synthetic Schools, four Dishes and four base lines; no pilot data.
begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = pg_catalog, public, extensions;
set local track_functions = 'all';
select no_plan();
create function pg_temp.ng_id(n bigint) returns uuid language sql immutable as $$
  select ('a7400000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
$$;
create function pg_temp.ng_request(contract text, reason text, payload jsonb)
returns jsonb language sql volatile as $$
  select jsonb_build_object('contract_version',contract,'command_id',id,
    'correlation_id',gen_random_uuid(),'idempotency_key','effective-generation:'||id,
    'requested_by_auth_subject',pg_temp.ng_id(101),'requested_at',now(),
    'expected_version',1,'reason_code',reason,'reason_note','Local scale acceptance',
    'payload',payload) from (select gen_random_uuid() as id) ids;
$$;
insert into atlas_core.actors(actor_id,actor_type,display_name)
values(pg_temp.ng_id(1),'HUMAN','Need scale operator');
insert into atlas_core.actor_auth_subjects(actor_auth_subject_id,actor_id,auth_subject_id)
values(pg_temp.ng_id(2),pg_temp.ng_id(1),pg_temp.ng_id(101));
insert into atlas_core.roles(role_id,role_code,role_name)
values(pg_temp.ng_id(3),'effective-generation-operator','Need scale operator');
insert into atlas_core.role_capabilities(role_id,capability_id)
select pg_temp.ng_id(3),capability_id from atlas_core.capabilities
where capability_code like 'planning.%' or capability_code like 'confirmed_need%';
insert into atlas_core.actor_role_memberships(actor_id,role_id)
values(pg_temp.ng_id(1),pg_temp.ng_id(3));
insert into atlas_core.actor_scopes(actor_id,scope_kind) values(pg_temp.ng_id(1),'GLOBAL');
insert into atlas_admin.customers(customer_id,customer_code,customer_name,customer_type)
values(pg_temp.ng_id(10),'effective-generation-customer','Need scale customer','SCHOOL_CATERING');
insert into atlas_admin.delivery_locations(delivery_location_id,customer_id,location_code,location_name,address_text,timezone_name)
values(pg_temp.ng_id(11),pg_temp.ng_id(10),'effective-generation-kitchen','Need scale kitchen','Disposable fixture','Asia/Ho_Chi_Minh');
insert into atlas_admin.school_types(school_type_id,school_type_code,school_type_name)
values
 (pg_temp.ng_id(12),'v1-school-type-1','Need scale type A'),
 (pg_temp.ng_id(14),'v1-school-type-2','Need scale type B');
insert into atlas_admin.units(unit_id,unit_code,unit_name,dimension_code)
values(pg_temp.ng_id(13),'effective-generation-kg','Need scale kilogram','mass');
insert into atlas_admin.schools(school_id,customer_id,school_code,school_name,school_type_id,default_delivery_location_id,display_order)
select pg_temp.ng_id(5000+i),pg_temp.ng_id(10),'effective-generation-school-'||i,'Need scale school '||i,
  case when i<3 then pg_temp.ng_id(12) else pg_temp.ng_id(14) end,pg_temp.ng_id(11),i
from generate_series(1,2) i;
insert into atlas_admin.ingredients(ingredient_id,ingredient_code,ingredient_name,purchase_unit_id,order_step)
select pg_temp.ng_id(2000+i),'effective-generation-ingredient-'||i,'Need scale ingredient '||i,pg_temp.ng_id(13),0.1
from generate_series(1,16) i;
insert into atlas_admin.dishes(dish_id,dish_code,dish_name,dish_type_id,requires_need_generation,dish_status)
select pg_temp.ng_id(1000+i),'effective-generation-dish-'||i,'Need scale dish '||i,t.dish_type_id,true,'ACTIVE'
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
from generate_series(1,4) i cross join generate_series(1,4) j;
insert into atlas_admin.recipe_line_revisions(recipe_line_revision_id,recipe_id,recipe_version_id,recipe_line_id,line_revision_number,ingredient_id,quantity_per_basis,unit_id,created_by_actor_id)
select pg_temp.ng_id(4000+i*100+j),pg_temp.ng_id(1100+i),pg_temp.ng_id(1200+i),
 pg_temp.ng_id(3000+i*100+j),1,pg_temp.ng_id(2000+case
   when i<=4 and (i-1)*4+j>13 then (i-1)*4+j-13
   when i>4 and (i-5)*4+j>14 then (i-5)*4+j-14
   when i<=4 then (i-1)*4+j else (i-5)*4+j end),
 case when i=1 and j=2 then 9.5 else 1.234567 end,pg_temp.ng_id(13),pg_temp.ng_id(1)
from generate_series(1,4) i cross join generate_series(1,4) j;
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
values(pg_temp.ng_id(31),pg_temp.ng_id(30),pg_temp.ng_id(13),1,null,0.1,'2050-01-01','DRAFT',pg_temp.ng_id(1));
update atlas_planning.planning_quantity_policy_revisions set policy_revision_status='ACTIVE',approved_by_actor_id=pg_temp.ng_id(1),
 approved_at=now(),activated_by_actor_id=pg_temp.ng_id(1),activated_at=now()
where planning_quantity_policy_revision_id=pg_temp.ng_id(31);
set constraints all immediate;
set constraints all deferred;
create temp table ng_requests(name text primary key,request jsonb not null);
create temp table ng_results(name text primary key,response jsonb not null,elapsed_ms numeric);
grant select,insert,update on ng_results to authenticated;
grant select on ng_requests to authenticated;
with rows as (
 select pg_temp.ng_id(5000+s) as school_id,date '2050-09-19'+day as service_date,
   t.dish_type_code as menu_slot_code,d.dish_id,'scale:'||s||':'||day||':'||d.dish_code as source_row_reference
 from generate_series(1,2) s cross join generate_series(0,4) day
 cross join atlas_admin.dishes d join atlas_admin.dish_types t using(dish_type_id)
 where d.dish_code like 'effective-generation-dish-%'
), canonical as (select atlas_core.rmvp_03a_canonical_menu_rows(jsonb_agg(to_jsonb(rows))) as rows from rows)
insert into ng_requests select 'menu',pg_temp.ng_request('RMVP-03A.v2','WEEKLY_MENU_SAVED',
jsonb_build_object('week_start','2050-09-19','source_type','GOOGLE_SHEET','source_name','Local scale Menu',
'source_signature',atlas_core.rmvp_03a_menu_signature(rows),'expected_source_signature',null,'rows',rows)) from canonical;
with rows as (
 select pg_temp.ng_id(5000+s) as school_id,date '2050-09-19'+day as service_date,
  case when day=2 then 0 else 95 end as student_portions,case when day=2 then 0 else 5 end as teacher_portions,'scale:'||s||':'||day as source_row_reference
 from generate_series(1,2) s cross join generate_series(0,4) day
), canonical as (select atlas_core.rmvp_03a_canonical_attendance_rows(jsonb_agg(to_jsonb(rows))) as rows from rows)
insert into ng_requests select 'attendance',pg_temp.ng_request('RMVP-03A.v2','ATTENDANCE_SAVED',
jsonb_build_object('week_start','2050-09-19','source_type','BULK_PASTE','source_name','Local scale Attendance',
'source_signature',atlas_core.rmvp_03a_attendance_signature(rows),'expected_source_signature',null,'rows',rows)) from canonical;
insert into atlas_planning.pantry_need_purposes(pantry_need_purpose_id,purpose_code,purpose_name_vi,purpose_description,note_rule,display_order)
values(pg_temp.ng_id(40),'effective_generation_pantry','Synthetic Pantry','Effective composition regression','OPTIONAL',1);
with rows as (select jsonb_build_array(jsonb_build_object(
 'service_date','2050-09-19','school_id',pg_temp.ng_id(5001),'ingredient_id',pg_temp.ng_id(2001),
 'pantry_need_purpose_id',pg_temp.ng_id(40),'requested_quantity','2.500000','note',null,
 'source_request_reference','Synthetic Pantry','source_row_reference','effective-pantry')) as rows)
insert into ng_requests select 'pantry',pg_temp.ng_request('PANTRY-02.v2','PANTRY_SAVED',
jsonb_build_object('week_start','2050-09-19','no_additions_confirmed',false,'source_signature',
atlas_core.pantry_02_signature('2050-09-19',false,atlas_core.pantry_02_canonical_rows('2050-09-19',rows)),
'expected_source_signature',null,'rows',rows)) from rows;
insert into ng_requests select 'generate',pg_temp.ng_request('RMVP-04.v3','NEED_GENERATION_EXECUTED',
jsonb_build_object('service_date','2050-09-19','expected_current_need_generation_run_id',null));
select set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.ng_id(101),'role','authenticated')::text,true);
set local role authenticated;
insert into ng_results select 'menu',atlas_api.save_weekly_menu(request),null from ng_requests where name='menu';
select is((select response->>'success' from ng_results where name='menu'),'true','40-assignment weekly Menu is saved through the real command');
select diag(jsonb_build_object('error_code',response->>'error_code','first_blocker',response#>'{blocking_references,0}')::text) from ng_results where name='menu' and response->>'success'<>'true';
insert into ng_results select 'attendance',atlas_api.save_attendance(request),null from ng_requests where name='attendance';
select is((select response->>'success' from ng_results where name='attendance'),'true','10-row Attendance is saved through the real command');
insert into ng_results select 'pantry',atlas_api.save_pantry(request),null from ng_requests where name='pantry';
select is((select response->>'success' from ng_results where name='pantry'),'true','exact Pantry source is saved');
insert into ng_results select 'preflight',atlas_api.get_planning_input_preflight(jsonb_build_object(
 'contract_version','RMVP-03B.v2','requested_by_auth_subject',pg_temp.ng_id(101),'correlation_id',gen_random_uuid(),
 'payload',jsonb_build_object('period_start','2050-09-19','period_end','2050-09-19'))),null;
select is((select response#>>'{preflight,readiness_state}' from ng_results where name='preflight'),'READY','all three completed sources are ready');
insert into ng_results select 'base',atlas_api.execute_need_generation(request),null from ng_requests where name='generate';
select is((select response->>'success' from ng_results where name='base'),'true','no-adjustment generation succeeds');
select diag(response::text) from ng_results where name='base' and response->>'success'<>'true';
reset role;
select ok((select bool_and(theoretical_quantity=case when contribution_family='PANTRY_DIRECT' then 2.5 when recipe_line_id=pg_temp.ng_id(3102) then 9.5 else 1.234567 end) from atlas_planning.theoretical_need_lines),'no-adjustment numeric output is identical');
create temp table original_evidence as select * from atlas_planning.theoretical_need_lines;

-- Synthetic cutover: replacement, 9.5-style quantity change, ADD, REMOVE and School layer.
insert into atlas_admin.recipe_composition_adjustments(
 recipe_composition_adjustment_id,scope_kind,action_kind,school_id,dish_id,school_type_id,
 target_ingredient_id,target_recipe_line_id,adjustment_line_id,created_by_actor_id,updated_by_actor_id)
values
 (pg_temp.ng_id(6001),'SYSTEM_INGREDIENT','REPLACE',null,null,null,pg_temp.ng_id(2001),null,null,pg_temp.ng_id(1),pg_temp.ng_id(1)),
 (pg_temp.ng_id(6002),'SYSTEM_DISH','ADJUST_QUANTITY',null,pg_temp.ng_id(1001),pg_temp.ng_id(12),null,pg_temp.ng_id(3102),null,pg_temp.ng_id(1),pg_temp.ng_id(1)),
 (pg_temp.ng_id(6003),'SYSTEM_DISH','ADD',null,pg_temp.ng_id(1001),pg_temp.ng_id(12),pg_temp.ng_id(2016),null,pg_temp.ng_id(6103),pg_temp.ng_id(1),pg_temp.ng_id(1)),
 (pg_temp.ng_id(6004),'SYSTEM_DISH','REMOVE',null,pg_temp.ng_id(1001),pg_temp.ng_id(12),null,pg_temp.ng_id(3104),null,pg_temp.ng_id(1),pg_temp.ng_id(1)),
 (pg_temp.ng_id(6005),'SCHOOL_DISH','ADJUST_QUANTITY',pg_temp.ng_id(5001),pg_temp.ng_id(1001),null,null,pg_temp.ng_id(3102),null,pg_temp.ng_id(1),pg_temp.ng_id(1)),
 (pg_temp.ng_id(6006),'SYSTEM_DISH','ADD',null,pg_temp.ng_id(1001),pg_temp.ng_id(12),pg_temp.ng_id(2014),null,pg_temp.ng_id(6106),pg_temp.ng_id(1),pg_temp.ng_id(1));
insert into atlas_admin.recipe_composition_adjustment_revisions(
 recipe_composition_adjustment_revision_id,recipe_composition_adjustment_id,scope_kind,action_kind,
 revision_number,effective_from,substitute_ingredient_id,quantity_per_basis,unit_id,reason_code,reason_note,created_by_actor_id)
select pg_temp.ng_id(6200+n),pg_temp.ng_id(6000+n),scope_kind,action_kind,1,'2050-09-19',
 case when n=1 then pg_temp.ng_id(2015) end,
 case n when 2 then 10 when 3 then 2 when 5 then 11 when 6 then 3 end,
 case when n in (3,6) then pg_temp.ng_id(13) end,
 'EFFECTIVE_GENERATION_FIXTURE','Synthetic Product contract regression',pg_temp.ng_id(1)
from generate_series(1,6) n join atlas_admin.recipe_composition_adjustments a on a.recipe_composition_adjustment_id=pg_temp.ng_id(6000+n);
update atlas_admin.recipe_composition_adjustments set current_revision_id=pg_temp.ng_id(6200+n),current_revision_number=1
from generate_series(1,6) n where recipe_composition_adjustment_id=pg_temp.ng_id(6000+n);
set constraints all immediate;
set constraints all deferred;

select is(atlas_core.recipe_effective_resolve_composition('2050-09-19',pg_temp.ng_id(5001),pg_temp.ng_id(1001),pg_temp.ng_id(12))->>'status','READY','canonical effective read resolves synthetic cutover');
set local role authenticated;
insert into ng_results select 'changed-preflight',atlas_api.get_planning_input_preflight(jsonb_build_object(
 'contract_version','RMVP-03B.v2','requested_by_auth_subject',pg_temp.ng_id(101),'correlation_id',gen_random_uuid(),
 'payload',jsonb_build_object('period_start','2050-09-19','period_end','2050-09-19'))),null;
select is((select response#>>'{preflight,downstream_currentness}' from ng_results where name='changed-preflight'),'OUTDATED','applicable Change Order makes prior generation outdated');
insert into ng_results select 'effective',atlas_api.execute_need_generation(
 jsonb_set(pg_temp.ng_request('RMVP-04.v3','NEED_GENERATION_EXECUTED',jsonb_build_object(
 'service_date','2050-09-19','expected_current_need_generation_run_id',response#>'{affected_aggregate_ids,need_generation_run_id}')), '{expected_version}',
 response#>'{new_versions,need_generation_run_version}')),null from ng_results where name='base';
select is((select response->>'success' from ng_results where name='effective'),'true','effective correction succeeds through authenticated atomic generation');
select diag(response::text) from ng_results where name='effective' and response->>'success'<>'true';
reset role;
select is((select theoretical_quantity from atlas_planning.theoretical_need_lines where
 need_generation_run_id=(select (response#>>'{affected_aggregate_ids,need_generation_run_id}')::uuid from ng_results where name='effective')
 and school_id=pg_temp.ng_id(5001) and recipe_line_id=pg_temp.ng_id(3102)),11::numeric,'School layer quantity overrides system quantity');
select is((select theoretical_quantity from atlas_planning.theoretical_need_lines where
 need_generation_run_id=(select (response#>>'{affected_aggregate_ids,need_generation_run_id}')::uuid from ng_results where name='effective')
 and school_id=pg_temp.ng_id(5002) and recipe_line_id=pg_temp.ng_id(3102)),10::numeric,'other School uses adjusted system quantity');
select ok(exists(select 1 from atlas_planning.theoretical_need_lines where
 need_generation_run_id=(select (response#>>'{affected_aggregate_ids,need_generation_run_id}')::uuid from ng_results where name='effective')
 and recipe_line_id=pg_temp.ng_id(3101) and ingredient_id=pg_temp.ng_id(2015)),'system Ingredient replacement changes Need Ingredient');
select ok(exists(select 1 from atlas_planning.theoretical_need_lines where
 need_generation_run_id=(select (response#>>'{affected_aggregate_ids,need_generation_run_id}')::uuid from ng_results where name='effective')
 and dish_id=pg_temp.ng_id(1001) and ingredient_id=pg_temp.ng_id(2016) and recipe_line_id is null and recipe_line_revision_id is null and theoretical_quantity=2),'ADD creates Need without fabricated RecipeLine');
select ok(not exists(select 1 from atlas_planning.theoretical_need_lines where
 need_generation_run_id=(select (response#>>'{affected_aggregate_ids,need_generation_run_id}')::uuid from ng_results where name='effective')
 and recipe_line_id=pg_temp.ng_id(3104) and theoretical_quantity>0),'REMOVE has no positive contribution');
select is((select theoretical_quantity from atlas_planning.theoretical_need_lines where contribution_family='PANTRY_DIRECT'
 and need_generation_run_id=(select (response#>>'{affected_aggregate_ids,need_generation_run_id}')::uuid from ng_results where name='effective')),
 2.5::numeric,'mixed Recipe/Pantry Need preserves exact Pantry quantity');
select is((select ingredient_id from atlas_planning.theoretical_need_lines where contribution_family='PANTRY_DIRECT'
 and need_generation_run_id=(select (response#>>'{affected_aggregate_ids,need_generation_run_id}')::uuid from ng_results where name='effective')),
 pg_temp.ng_id(2001),'system Recipe Ingredient replacement does not change Pantry Ingredient');
select results_eq('select to_jsonb(o) from original_evidence o order by theoretical_need_line_id',
 'select to_jsonb(l) from atlas_planning.theoretical_need_lines l join original_evidence o using(theoretical_need_line_id) order by l.theoretical_need_line_id','prior generated evidence remains byte equivalent');
select results_eq($$select captured.effective_line from atlas_planning.need_generation_recipe_line_uses captured
 join atlas_planning.need_generation_recipe_selections selected using(need_generation_recipe_selection_id)
 where captured.need_generation_run_id=(select (response#>>'{affected_aggregate_ids,need_generation_run_id}')::uuid from ng_results where name='effective')
 order by selected.school_id,selected.dish_id,coalesce(captured.recipe_line_id,captured.adjustment_line_id)$$,
 $$select line from atlas_planning.need_generation_recipe_selections selected
 cross join lateral jsonb_array_elements(atlas_core.recipe_effective_resolve_composition(
 '2050-09-19',selected.school_id,selected.dish_id,selected.school_type_id)->'lines') line
 where selected.need_generation_run_id=(select (response#>>'{affected_aggregate_ids,need_generation_run_id}')::uuid from ng_results where name='effective')
 order by selected.school_id,selected.dish_id,coalesce((line->>'base_recipe_line_id')::uuid,(line->>'adjustment_line_id')::uuid)$$,
 'effective read and generated evidence use exactly the same full composition and lineage');
select ok((select bool_and(adjustment_id=pg_temp.ng_id(6003) and adjustment_revision_id=pg_temp.ng_id(6203)
 and adjustment_line_id=pg_temp.ng_id(6103)) from atlas_planning.need_generation_recipe_line_uses
 where need_generation_run_id=(select (response#>>'{affected_aggregate_ids,need_generation_run_id}')::uuid from ng_results where name='effective')
 and adjustment_line_id=pg_temp.ng_id(6103)),'ADD evidence retains exact stable adjustment and revision identity');
select throws_ok($$update atlas_planning.need_generation_recipe_line_uses set effective_line=effective_line where effective_line is not null$$,
 '23514',null,'effective evidence cannot be rewritten');

create function pg_temp.effective_regenerate(result_name text,previous_name text,service_day date default '2050-09-19')
returns void language sql volatile as $$
 insert into ng_results select result_name,atlas_api.execute_need_generation(
 jsonb_set(pg_temp.ng_request('RMVP-04.v3','NEED_GENERATION_EXECUTED',jsonb_build_object(
 'service_date',service_day,'expected_current_need_generation_run_id',response#>'{affected_aggregate_ids,need_generation_run_id}')),
 '{expected_version}',response#>'{new_versions,need_generation_run_version}')),null
 from ng_results where name=previous_name;
$$;

-- Supersede only the system quantity; the School override still wins.
insert into atlas_admin.recipe_composition_adjustment_revisions(
 recipe_composition_adjustment_revision_id,recipe_composition_adjustment_id,scope_kind,action_kind,
 revision_number,predecessor_revision_id,effective_from,effective_to,quantity_per_basis,reason_code,reason_note,created_by_actor_id)
values(pg_temp.ng_id(6302),pg_temp.ng_id(6002),'SYSTEM_DISH','ADJUST_QUANTITY',2,pg_temp.ng_id(6202),'2050-09-19','2050-09-20',12,
 'EFFECTIVE_GENERATION_FIXTURE','Synthetic successor',pg_temp.ng_id(1));
update atlas_admin.recipe_composition_adjustments set current_revision_id=pg_temp.ng_id(6302),current_revision_number=2,version=2
 where recipe_composition_adjustment_id=pg_temp.ng_id(6002);
create function pg_temp.cross_add_predecessor() returns trigger language plpgsql as $$
begin
 if new.recipe_line_id is null and new.ingredient_id in (pg_temp.ng_id(2014),pg_temp.ng_id(2016)) then
   select prior.theoretical_need_line_id into new.predecessor_theoretical_need_line_id
   from atlas_planning.theoretical_need_lines prior
   where prior.need_generation_run_id=new.predecessor_need_generation_run_id
     and prior.weekly_menu_line_id=new.weekly_menu_line_id
     and prior.attendance_line_id=new.attendance_line_id and prior.recipe_line_id is null
     and prior.ingredient_id=case when new.ingredient_id=pg_temp.ng_id(2014) then pg_temp.ng_id(2016) else pg_temp.ng_id(2014) end;
 end if;
 return new;
end $$;
create trigger effective_cross_add_fault before insert on atlas_planning.theoretical_need_lines
 for each row execute function pg_temp.cross_add_predecessor();
set local role authenticated;
select pg_temp.effective_regenerate('crossed-add','effective');
select is((select response->>'error_code' from ng_results where name='crossed-add'),'INVARIANT_VIOLATION','deferred 23514 integrity rejects crossed stable ADD predecessors');
reset role;
drop trigger effective_cross_add_fault on atlas_planning.theoretical_need_lines;
select is((select count(*) from atlas_planning.need_generation_runs where period_start='2050-09-19'),2::bigint,'crossed ADD lineage commits no successor');
set local role authenticated;
select pg_temp.effective_regenerate('superseded','effective');
select is((select response->>'success' from ng_results where name='superseded'),'true','superseded adjustment triggers correction');
select diag(response::text) from ng_results where name='superseded' and response->>'success'<>'true';
reset role;
select is((select theoretical_quantity from atlas_planning.theoretical_need_lines where
 need_generation_run_id=(select (response#>>'{affected_aggregate_ids,need_generation_run_id}')::uuid from ng_results where name='superseded')
 and school_id=pg_temp.ng_id(5002) and recipe_line_id=pg_temp.ng_id(3102)),12::numeric,'only the effective successor supplies system quantity');

-- A dated cancellation removes the ADD and reverses the native REMOVE.
insert into atlas_admin.recipe_composition_adjustment_revisions(
 recipe_composition_adjustment_revision_id,recipe_composition_adjustment_id,scope_kind,action_kind,
 revision_number,predecessor_revision_id,revision_status,effective_from,reason_code,reason_note,created_by_actor_id)
select pg_temp.ng_id(6300+n),pg_temp.ng_id(6000+n),'SYSTEM_DISH',action_kind,2,pg_temp.ng_id(6200+n),'CANCELLED','2050-09-19',
 'EFFECTIVE_GENERATION_FIXTURE','Synthetic dated cancellation',pg_temp.ng_id(1)
 from generate_series(3,4) n join atlas_admin.recipe_composition_adjustments a on a.recipe_composition_adjustment_id=pg_temp.ng_id(6000+n);
update atlas_admin.recipe_composition_adjustments set current_revision_id=pg_temp.ng_id(6300+n),current_revision_number=2,
 lifecycle_status='CANCELLED',version=2 from generate_series(3,4) n where recipe_composition_adjustment_id=pg_temp.ng_id(6000+n);
set local role authenticated;
select pg_temp.effective_regenerate('cancelled','superseded');
select is((select response->>'success' from ng_results where name='cancelled'),'true','cancelled ADD and REMOVE safely regenerate');
select diag(response::text) from ng_results where name='cancelled' and response->>'success'<>'true';
reset role;
select ok(not exists(select 1 from atlas_planning.theoretical_need_lines where
 need_generation_run_id=(select (response#>>'{affected_aggregate_ids,need_generation_run_id}')::uuid from ng_results where name='cancelled')
 and dish_id=pg_temp.ng_id(1001) and ingredient_id=pg_temp.ng_id(2016) and theoretical_quantity>0),'cancelled ADD creates no positive contribution');
select is((select count(*) from atlas_planning.theoretical_need_lines where
 need_generation_run_id=(select (response#>>'{affected_aggregate_ids,need_generation_run_id}')::uuid from ng_results where name='cancelled')
 and recipe_line_id=pg_temp.ng_id(3104) and theoretical_quantity=1.234567),2::bigint,'cancellation reverses native REMOVE at both Schools');

-- Zero attendance keeps immutable zero audit rows and no actionable batch.
set local role authenticated;
insert into ng_results values('expired',atlas_api.execute_need_generation(pg_temp.ng_request('RMVP-04.v3','NEED_GENERATION_EXECUTED',
 jsonb_build_object('service_date','2050-09-20','expected_current_need_generation_run_id',null))),null);
select is((select response->>'success' from ng_results where name='expired'),'true','finite successor expiry generates normally');
reset role;
select is((select theoretical_quantity from atlas_planning.theoretical_need_lines where service_date='2050-09-20'
 and school_id=pg_temp.ng_id(5002) and recipe_line_id=pg_temp.ng_id(3102)),10::numeric,'expired successor resumes the applicable predecessor quantity');
set local role authenticated;
insert into ng_results values('zero',atlas_api.execute_need_generation(pg_temp.ng_request('RMVP-04.v3','NEED_GENERATION_EXECUTED',
 jsonb_build_object('service_date','2050-09-21','expected_current_need_generation_run_id',null))),null);
select is((select response->>'success' from ng_results where name='zero'),'true','zero-demand effective composition still generates successfully');
select is((select response#>>'{affected_aggregate_ids,confirmed_need_batch_id}' from ng_results where name='zero'),null::text,'zero demand creates no Confirmed Need batch');
reset role;
select ok((select bool_and(theoretical_quantity=0) from atlas_planning.theoretical_need_lines where service_date='2050-09-21'),'zero Recipe contributions retain audit evidence');

create function pg_temp.effective_v1_create(service_day date) returns jsonb language plpgsql as $$
declare evaluated jsonb; requested jsonb; readiness_request jsonb; sources jsonb; candidates jsonb;
begin
 select response#>'{preflight,source_evidence}' into sources from ng_results where name='preflight';
 candidates:=jsonb_build_object('weekly_menu',jsonb_build_object(
 'weekly_menu_id',sources#>'{weekly_menu,selected,weekly_menu_id}',
 'weekly_menu_version',sources#>'{weekly_menu,selected,weekly_menu_version}',
 'weekly_menu_approval_snapshot_id',sources#>'{weekly_menu,selected,weekly_menu_approval_snapshot_id}'),
 'attendance',jsonb_build_object('attendance_batch_id',sources#>'{attendance,selected,attendance_batch_id}',
 'attendance_version',sources#>'{attendance,selected,attendance_version}',
 'attendance_approval_snapshot_id',sources#>'{attendance,selected,attendance_approval_snapshot_id}'),
 'pantry',jsonb_build_object('pantry_need_batch_id',sources#>'{pantry,selected,pantry_need_batch_id}',
 'pantry_need_batch_version',sources#>'{pantry,selected,pantry_need_batch_version}',
 'pantry_need_approval_snapshot_id',sources#>'{pantry,selected,pantry_need_approval_snapshot_id}'));
 readiness_request:=(pg_temp.ng_request('RMVP-03B.v1','READINESS_EVALUATION_REQUESTED',jsonb_build_object(
   'period_start',service_day,'period_end',service_day,'source_candidates',candidates))-'expected_version')
   ||jsonb_build_object('reason_note',null,'expected_root_status','ABSENT','expected_current_evaluation_id',null,'expected_current_evaluation_version',null);
 evaluated:=atlas_api.evaluate_planning_input_readiness(readiness_request);
 if evaluated->>'success'<>'true' then return evaluated; end if;
 requested:=atlas_api.request_planning_input_need_generation(
   (pg_temp.ng_request('RMVP-03B.v1','NEED_GENERATION_HANDOFF_REQUESTED',jsonb_build_object('period_start',service_day,
    'period_end',service_day,'planning_input_set_id',evaluated#>'{affected_aggregate_ids,planning_input_set_id}'))-'expected_version')
   ||jsonb_build_object('reason_note',null,'expected_root_status','READY',
    'expected_current_evaluation_id',evaluated#>'{affected_aggregate_ids,planning_input_evaluation_id}',
    'expected_current_evaluation_version',evaluated#>'{new_versions,current_evaluation_version}'));
 if requested->>'success'<>'true' then return requested; end if;
 return atlas_api.create_need_generation_run(pg_temp.ng_request('RMVP-04.v1','NEED_GENERATION_CREATED',jsonb_build_object(
   'planning_input_set_id',requested#>'{affected_aggregate_ids,planning_input_set_id}',
   'planning_input_evaluation_id',evaluated#>'{affected_aggregate_ids,planning_input_evaluation_id}',
   'period_start',service_day,'period_end',service_day))||jsonb_build_object('reason_note',null,
   'expected_version',evaluated#>'{new_versions,current_evaluation_version}'));
end $$;
set local role authenticated;
insert into ng_results values('v1-generated',pg_temp.effective_v1_create('2050-09-22'),null),
 ('v1-for-validation',pg_temp.effective_v1_create('2050-09-23'),null);
select diag(response::text) from ng_results where name='v1-generated' and response->>'success'<>'true';
select is((select response->>'success' from ng_results where name='v1-generated'),'true','retained v1 can create exact effective generated evidence');
insert into ng_results select 'v1-validated',atlas_api.validate_need_generation_run(
 pg_temp.ng_request('RMVP-04.v1','NEED_GENERATION_VALIDATED',jsonb_build_object('need_generation_run_id',response#>'{affected_aggregate_ids,need_generation_run_id}'))
 ||jsonb_build_object('reason_note',null)),null from ng_results where name='v1-for-validation';
select is((select response->>'success' from ng_results where name='v1-validated'),'true','retained v1 validates unchanged effective evidence');
reset role;
create temp table stale_before as select jsonb_build_object(
 'runs',(select jsonb_agg(to_jsonb(r) order by need_generation_run_id) from atlas_planning.need_generation_runs r),
 'releases',(select jsonb_agg(to_jsonb(r) order by need_generation_release_snapshot_id) from atlas_planning.need_generation_release_snapshots r),
 'batches',(select jsonb_agg(to_jsonb(b) order by confirmed_need_batch_id) from atlas_planning.confirmed_need_batches b)
) as captured;
insert into atlas_admin.recipe_composition_adjustment_revisions(
 recipe_composition_adjustment_revision_id,recipe_composition_adjustment_id,scope_kind,action_kind,
 revision_number,predecessor_revision_id,effective_from,quantity_per_basis,reason_code,reason_note,created_by_actor_id)
values(pg_temp.ng_id(6502),pg_temp.ng_id(6002),'SYSTEM_DISH','ADJUST_QUANTITY',3,pg_temp.ng_id(6302),'2050-09-21',13,
 'EFFECTIVE_GENERATION_FIXTURE','Synthetic change after v1 progression',pg_temp.ng_id(1));
update atlas_admin.recipe_composition_adjustments set current_revision_id=pg_temp.ng_id(6502),current_revision_number=3,version=3
 where recipe_composition_adjustment_id=pg_temp.ng_id(6002);
set local role authenticated;
insert into ng_results select 'stale-validate',atlas_api.validate_need_generation_run(
 pg_temp.ng_request('RMVP-04.v1','NEED_GENERATION_VALIDATED',jsonb_build_object('need_generation_run_id',response#>'{affected_aggregate_ids,need_generation_run_id}'))
 ||jsonb_build_object('reason_note',null)),null from ng_results where name='v1-generated';
insert into ng_results select 'stale-release',atlas_api.release_need_generation_run(
 pg_temp.ng_request('RMVP-04.v1','NEED_GENERATION_RELEASED',jsonb_build_object('need_generation_run_id',response#>'{affected_aggregate_ids,need_generation_run_id}'))
 ||jsonb_build_object('reason_note',null,'expected_version',response#>'{new_versions,need_generation_run_version}')), null from ng_results where name='v1-validated';
insert into ng_results select 'stale-materialize',atlas_api.create_confirmed_needs_from_generation(
 pg_temp.ng_request('PA-06E-H0C.v1','EFFECTIVE_GENERATION_FIXTURE',jsonb_build_object(
 'need_generation_run_id',response#>'{affected_aggregate_ids,need_generation_run_id}',
 'need_generation_run_version',response#>'{new_versions,need_generation_run_version}','confirmed_need_batch_id',null))),null from ng_results where name='zero';
select is((select response->>'error_code' from ng_results where name='stale-validate'),'STALE_SOURCE_BINDING','v1 validate rejects changed composition');
select is((select response->>'error_code' from ng_results where name='stale-release'),'STALE_SOURCE_BINDING','v1 release rejects changed composition');
select is((select response->>'error_code' from ng_results where name='stale-materialize'),'STALE_SOURCE_BINDING','CMD-15 rejects changed released composition');
reset role;
select is(jsonb_build_object(
 'runs',(select jsonb_agg(to_jsonb(r) order by need_generation_run_id) from atlas_planning.need_generation_runs r),
 'releases',(select jsonb_agg(to_jsonb(r) order by need_generation_release_snapshot_id) from atlas_planning.need_generation_release_snapshots r),
 'batches',(select jsonb_agg(to_jsonb(b) order by confirmed_need_batch_id) from atlas_planning.confirmed_need_batches b)
),(select captured from stale_before),'stale lifecycle attempts preserve exact run/release/batch evidence');

-- Canonical blocked resolution must roll back the whole generation package.
insert into atlas_admin.recipe_composition_adjustments(
 recipe_composition_adjustment_id,scope_kind,action_kind,target_ingredient_id,created_by_actor_id,updated_by_actor_id)
values(pg_temp.ng_id(6401),'SYSTEM_INGREDIENT','REPLACE',pg_temp.ng_id(2015),pg_temp.ng_id(1),pg_temp.ng_id(1));
insert into atlas_admin.recipe_composition_adjustment_revisions(
 recipe_composition_adjustment_revision_id,recipe_composition_adjustment_id,scope_kind,action_kind,revision_number,
 effective_from,substitute_ingredient_id,reason_code,reason_note,created_by_actor_id)
values(pg_temp.ng_id(6402),pg_temp.ng_id(6401),'SYSTEM_INGREDIENT','REPLACE',1,'2050-09-19',pg_temp.ng_id(2001),
 'EFFECTIVE_GENERATION_FIXTURE','Synthetic replacement cycle',pg_temp.ng_id(1));
update atlas_admin.recipe_composition_adjustments set current_revision_id=pg_temp.ng_id(6402),current_revision_number=1
 where recipe_composition_adjustment_id=pg_temp.ng_id(6401);
create temp table effective_before_block as select count(*) as run_count from atlas_planning.need_generation_runs;
set local role authenticated;
select pg_temp.effective_regenerate('blocked','cancelled');
select is((select response->>'success' from ng_results where name='blocked'),'false','blocked effective resolution cannot generate');
reset role;
select is((select count(*) from atlas_planning.need_generation_runs),(select run_count from effective_before_block),'blocked effective resolution commits no partial run');
select ok(not has_function_privilege('authenticated','atlas_core.need_generation_effective_current(uuid)','EXECUTE')
 and not has_function_privilege('anon','atlas_core.need_generation_effective_current(uuid)','EXECUTE'),'private currentness helper is inaccessible to browser roles');
select ok(not has_table_privilege('authenticated','atlas_admin.recipe_composition_adjustment_revisions','SELECT'),'resolver reuse adds no browser table privilege');
set constraints all immediate;
select * from finish();
rollback;
