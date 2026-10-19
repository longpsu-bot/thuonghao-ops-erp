-- Disposable local/CI only. All source and generation constraints stay enabled.
-- Two synthetic Schools, four Dishes and four base lines; no pilot data.
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = pg_catalog, public, extensions;
set local track_functions = 'all';
select ok(has_function_privilege('atlas_need_generation_runtime','atlas_core.pa_05b_safe_numeric(text)','EXECUTE')
  and not exists(select 1 from (values('anon'),('authenticated'),('service_role')) roles(role_name)
    where has_function_privilege(role_name,'atlas_core.pa_05b_safe_numeric(text)','EXECUTE')),
  'conditional effective rules retain private numeric parsing without browser execution');
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
where capability_code like 'planning.%' or capability_code like 'confirmed_need%'
 or capability_code in('procurement.school_catering.read','procurement.school_catering.write',
 'dispatch.school_release.read','dispatch.school_release.release');
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
 case when i=1 and j=1 then 20 else 1.234567 end,pg_temp.ng_id(13),pg_temp.ng_id(1)
from generate_series(1,4) i cross join generate_series(1,4) j;
update atlas_admin.recipe_versions set recipe_version_status='VALIDATED',validated_by_actor_id=pg_temp.ng_id(1),validated_at=now()
where recipe_version_id in(select pg_temp.ng_id(1200+i) from generate_series(1,4) i);
update atlas_admin.recipe_versions set recipe_version_status='RELEASED_FOR_PLANNING',released_by_actor_id=pg_temp.ng_id(1),released_at=now()
where recipe_version_id in(select pg_temp.ng_id(1200+i) from generate_series(1,4) i);
-- Reuse the canonical proportional calculation contract from the first fixture.
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
 where d.dish_id=pg_temp.ng_id(1001)
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
values(pg_temp.ng_id(40),'planning_identified_supplement','Bổ sung','B1 Planning source','OPTIONAL',1),
(pg_temp.ng_id(41),'school_requested_supplement','Đặt theo yêu cầu nhà trường','B1 School source','OPTIONAL',2);
with rows as (select jsonb_agg(jsonb_build_object('service_date','2050-09-19','school_id',pg_temp.ng_id(5001),
'ingredient_id',pg_temp.ng_id(ingredient),'pantry_need_purpose_id',pg_temp.ng_id(purpose),'requested_quantity',quantity,
'note',null,'source_request_reference','B1:'||purpose||':'||ingredient,'source_row_reference','B1:'||purpose||':'||ingredient)) rows
from (values(40,5),(41,3)) sources(purpose,quantity) cross join (values(2001),(2016)) ingredients(ingredient))
insert into ng_requests select 'pantry',pg_temp.ng_request('PANTRY-02.v3','PANTRY_SAVED',jsonb_build_object(
'week_start','2050-09-19','no_additions_confirmed',false,'rows',rows,'source_signature',
atlas_core.pantry_02_signature('2050-09-19',false,atlas_core.pantry_02_canonical_rows('2050-09-19',rows)),
'expected_source_signature',null,'school_date_modes',jsonb_build_array(jsonb_build_object('school_id',pg_temp.ng_id(5001),
'service_date','2050-09-19','direct_need_mode','ADDITIVE')))) from rows;
select set_config('request.jwt.claim.sub',pg_temp.ng_id(101)::text,true);
select set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.ng_id(101),'role','authenticated')::text,true);
set local role authenticated;
insert into ng_results select 'menu',atlas_api.save_weekly_menu(request),null from ng_requests where name='menu';
select is((select response->>'success' from ng_results where name='menu'),'true','B1 real Menu Save');
insert into ng_results select 'attendance',atlas_api.save_attendance(request),null from ng_requests where name='attendance';
select is((select response->>'success' from ng_results where name='attendance'),'true','B1 real Attendance Save');
insert into ng_results select 'pantry',atlas_api.save_pantry(request),null from ng_requests where name='pantry';
select is((select response->>'success' from ng_results where name='pantry'),'true','B1 two-source ADDITIVE Save');
insert into ng_results values('additive',atlas_api.execute_need_generation(pg_temp.ng_request('RMVP-04.v3','NEED_GENERATION_EXECUTED',
jsonb_build_object('service_date','2050-09-19','expected_current_need_generation_run_id',null))),null);
select is((select response->>'success' from ng_results where name='additive'),'true','B1 ADDITIVE generation');
select diag(name||':'||response::text) from ng_results where response->>'success'<>'true';
set constraints all immediate;
set constraints all deferred;
reset role;
select is((select sum(theoretical_quantity) from atlas_planning.theoretical_need_lines where school_id=pg_temp.ng_id(5001)
and ingredient_id=pg_temp.ng_id(2001) and contribution_family='RECIPE_DERIVED' and line_disposition='ACTIVE'),20::numeric,'Recipe contribution is exactly 20 kg');
select ok((select count(*)=2 and count(distinct pantry_need_line_id)=2 and sum(theoretical_quantity)=8
from atlas_planning.theoretical_need_lines where school_id=pg_temp.ng_id(5001) and ingredient_id=pg_temp.ng_id(2001)
and contribution_family='PANTRY_DIRECT' and line_disposition='ACTIVE'),'both direct sources contribute exactly 5+3');
select is((select sum(theoretical_quantity) from atlas_planning.theoretical_need_lines where school_id=pg_temp.ng_id(5001)
and ingredient_id=pg_temp.ng_id(2001) and line_disposition='ACTIVE'),28::numeric,'ADDITIVE derives exactly 20+5+3=28');
select is((select sum(theoretical_quantity) from atlas_planning.theoretical_need_lines where school_id=pg_temp.ng_id(5002)
and ingredient_id=pg_temp.ng_id(2001) and line_disposition='ACTIVE'),20::numeric,'another School retains its own 20, without Pantry leakage');
select ok((select count(*)=3 and sum(c.controlled_contribution_quantity)=28 and count(distinct t.pantry_need_line_id)=2
from atlas_planning.confirmed_need_line_revision_contributions c join atlas_planning.theoretical_need_lines t using(theoretical_need_line_id)
where t.school_id=pg_temp.ng_id(5001) and t.ingredient_id=pg_temp.ng_id(2001)),
'confirmed purchasing lineage retains Recipe and both Pantry contributions at exact 28');

insert into atlas_admin.suppliers(supplier_id,supplier_code,supplier_name,document_code)
values(pg_temp.ng_id(60),'k1-b1-supplier','K1 B1 Supplier','K1-B1');
insert into atlas_admin.supplier_eligibilities(supplier_id,ingredient_id,effective_from,priority)
select pg_temp.ng_id(60),pg_temp.ng_id(2000+i),'2050-01-01',1 from generate_series(1,16)i;
