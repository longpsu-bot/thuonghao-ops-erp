-- Disposable local/CI only. All source and generation constraints stay enabled.
-- Two synthetic Schools, four Dishes and four base lines; no pilot data.
begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = pg_catalog, public, extensions;
set local track_functions = 'all';
select no_plan();
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
-- The public read must classify immutable Purpose evidence and survive copied
-- memberships after a reasoned human override. No new calculation authority.
create function pg_temp.b1_need_read_request() returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('contract_version','RMVP-04.v1',
 'requested_by_auth_subject',pg_temp.ng_id(101),'correlation_id',gen_random_uuid(),
 'payload',jsonb_build_object('period_start','2050-09-19','period_end','2050-09-19',
 'need_generation_run_id',(select need_generation_run_id from atlas_planning.need_generation_runs
 where generated_by_actor_id=pg_temp.ng_id(1) and period_start='2050-09-19'),
 'filters',jsonb_build_object('school_id',pg_temp.ng_id(5001),'ingredient_id',pg_temp.ng_id(2001)),
 'detail_group',jsonb_build_object('service_date','2050-09-19','school_id',pg_temp.ng_id(5001),
 'delivery_location_id',pg_temp.ng_id(11),'ingredient_id',pg_temp.ng_id(2001),'unit_id',pg_temp.ng_id(13))));
$$;
grant execute on function pg_temp.b1_need_read_request() to authenticated;
set local role authenticated;
insert into ng_results values('source_read',atlas_api.get_need_generation_workbench(pg_temp.b1_need_read_request()),null);
reset role;
select is((select response#>'{workbench,grouped_requirements,0,source_breakdown}' from ng_results where name='source_read'),
 jsonb_build_object('recipe_derived_quantity','20.000000','planning_supplement_quantity','5.000000',
 'recipe_associated_quantity','25.000000','special_order_quantity','3.000000',
 'unclassified_direct_quantity','0','total_theoretical_quantity','28.000000'),
 'B1 public read separates exact R20 B5 R+B25 H3 total28');
select ok((select count(*)=3 and count(*) filter(where value->>'exact_theoretical_quantity' is not null)=3
 and count(distinct value->>'pantry_need_line_id')=2
 and count(*) filter(where value->>'pantry_purpose_code' in('planning_identified_supplement','school_requested_supplement'))=2
 from ng_results cross join lateral jsonb_array_elements(response#>'{workbench,atomic_detail}')
 where name='source_read'),'B1 atomic read retains exact quantities, two stable Pantry IDs and Purpose codes');
create function pg_temp.b1_confirmation_case(target_quantity text,with_documents boolean default false) returns jsonb language plpgsql as $$
declare command jsonb; saved jsonb; readback jsonb; answer jsonb; allocation_read jsonb;
 entry jsonb; response jsonb; prepared jsonb; preview jsonb; batch_id uuid;
 po record; school record; releases jsonb:='[]'; documents jsonb:='[]';
begin
 select pg_temp.ng_request('RMVP-05.v2','CONFIRMED_NEED_SAVED',jsonb_build_object(
 'confirmed_need_batch_id',b.confirmed_need_batch_id,'lines',(
 select jsonb_agg(jsonb_build_object('confirmed_need_line_id',l.confirmed_need_line_id,
 'expected_current_revision_id',r.confirmed_need_line_revision_id,
 'expected_current_decision_id',l.current_confirmed_need_line_decision_id,
 'proposed_confirmed_quantity',case when l.school_id=pg_temp.ng_id(5001) and l.ingredient_id=pg_temp.ng_id(2001)
 then target_quantity else r.confirmed_quantity::text end,
 'reason_code',case when l.school_id=pg_temp.ng_id(5001) and l.ingredient_id=pg_temp.ng_id(2001)
 and target_quantity::numeric<>r.confirmed_quantity then 'OPERATIONAL_QUANTITY_ADJUSTMENT' else 'PROPOSAL_ACCEPTED' end,
 'reason_note',case when l.school_id=pg_temp.ng_id(5001) and l.ingredient_id=pg_temp.ng_id(2001)
 and target_quantity::numeric<>r.confirmed_quantity then 'Explicit B1 operational decision' else null end)
 order by l.confirmed_need_line_id)
 from atlas_planning.confirmed_need_lines l join atlas_planning.confirmed_need_line_revisions r
 on r.confirmed_need_line_id=l.confirmed_need_line_id and r.is_current
 where l.confirmed_need_batch_id=b.confirmed_need_batch_id)))||jsonb_build_object('expected_version',b.version,'reason_note',null)
 into command from atlas_planning.confirmed_need_batches b where b.current_need_generation_run_id=(
 select need_generation_run_id from atlas_planning.need_generation_runs
 where generated_by_actor_id=pg_temp.ng_id(1) and period_start='2050-09-19');
 execute 'set local role authenticated';
 saved:=atlas_api.save_confirmed_needs(command);
 readback:=atlas_api.get_need_generation_workbench(pg_temp.b1_need_read_request());
 execute 'reset role';
 answer:=jsonb_build_object('saved',saved,'readback',readback);
 if with_documents then
  batch_id:=(command#>>'{payload,confirmed_need_batch_id}')::uuid;
  answer:=answer||jsonb_build_object('facts',(
   select jsonb_build_object('revision_id',r.confirmed_need_line_revision_id,'theoretical',r.theoretical_quantity::text,'confirmed',r.confirmed_quantity::text,
    'decision',to_jsonb(d),'sources',(
     select jsonb_agg(jsonb_build_object('family',t.contribution_family,'quantity',c.controlled_contribution_quantity::text,
      'pantry_line',t.pantry_need_line_id,'recipe',t.recipe_id,'recipe_version',t.recipe_version_id)
      order by t.contribution_family,t.theoretical_need_line_id)
     from atlas_planning.confirmed_need_line_revision_contributions c
     join atlas_planning.theoretical_need_lines t using(theoretical_need_line_id)
     where c.confirmed_need_line_revision_id=r.confirmed_need_line_revision_id))
   from atlas_planning.confirmed_need_lines l join atlas_planning.confirmed_need_line_revisions r
    on r.confirmed_need_line_id=l.confirmed_need_line_id and r.is_current
   left join atlas_planning.confirmed_need_line_decisions d
    on d.confirmed_need_line_decision_id=l.current_confirmed_need_line_decision_id
   where l.confirmed_need_batch_id=batch_id and l.school_id=pg_temp.ng_id(5001) and l.ingredient_id=pg_temp.ng_id(2001)));
  execute 'set local role authenticated';
  allocation_read:=atlas_api.get_confirmed_supplier_allocation_workbench(jsonb_build_object(
   'contract_version','CONFIRMED-SUPPLIER-ALLOCATION.v1','requested_by_auth_subject',pg_temp.ng_id(101),
   'correlation_id',gen_random_uuid(),'payload',jsonb_build_object('date_start','2050-09-19','date_end','2050-09-19')));
  for entry in select value from jsonb_array_elements(allocation_read->'rows') loop
   response:=atlas_api.save_confirmed_supplier_allocation(pg_temp.ng_request('CONFIRMED-SUPPLIER-ALLOCATION.v1',
    'CONFIRMED_SUPPLIER_ALLOCATION_SAVED',jsonb_build_object('family',jsonb_build_object(
     'service_date',entry->'service_date','delivery_location_id',entry->'delivery_location_id',
     'ingredient_id',entry->'ingredient_id','unit_id',entry->'unit_id',
     'expected_source_fingerprint',entry#>'{family,source_fingerprint}',
     'expected_source_batch_id',entry->'source_confirmed_need_batch_id',
     'expected_source_batch_version',entry->'source_confirmed_need_batch_version'),
    'splits',jsonb_build_array(
     jsonb_build_object('supplier_id',pg_temp.ng_id(60),'allocated_quantity',round((entry->>'family_quantity')::numeric*0.6,6)::text),
     jsonb_build_object('supplier_id',pg_temp.ng_id(61),'allocated_quantity',((entry->>'family_quantity')::numeric-round((entry->>'family_quantity')::numeric*0.6,6))::text))))
    ||jsonb_build_object('expected_version',(entry#>>'{family,version}')::bigint,'reason_note',null));
   if response->>'success' is distinct from 'true' then raise exception 'B1 allocation failed: %',response; end if;
  end loop;
  execute 'reset role';
  select pg_temp.ng_request('PURCHASE-COMMITMENT.v1','PURCHASE_ORDERS_PREPARED',jsonb_build_object(
   'confirmed_need_batch_id',batch_id,'service_date','2050-09-19'))||jsonb_build_object('expected_version',b.version)
  into command from atlas_planning.confirmed_need_batches b where b.confirmed_need_batch_id=batch_id;
  execute 'set local role authenticated';
  prepared:=atlas_api.prepare_school_catering_purchase_orders(command);
  execute 'reset role';
  if prepared->>'success' is distinct from 'true' then raise exception 'B1 preparation failed: %',prepared; end if;
  for po in select p.purchase_order_id,p.version,r.purchase_order_revision_id from atlas_procurement.purchase_orders p
   join atlas_procurement.purchase_order_revisions r using(purchase_order_id)
   where r.service_date='2050-09-19' and r.is_current loop
   command:=pg_temp.ng_request('SCHOOL-CATERING-PROCUREMENT.v1','SCHOOL_CATERING_PO_RELEASED',jsonb_build_object(
    'purchase_order_id',po.purchase_order_id,'expected_purchase_order_revision_id',po.purchase_order_revision_id))
    ||jsonb_build_object('expected_version',po.version);
   execute 'set local role authenticated';
   response:=atlas_api.release_school_catering_purchase_order(command);
   execute 'reset role';
   if response->>'success' is distinct from 'true' then raise exception 'B1 PO release failed: %',response; end if;
   releases:=releases||jsonb_build_array(response);
  end loop;
  for school in select school_id from atlas_admin.schools where school_id in(pg_temp.ng_id(5001),pg_temp.ng_id(5002)) loop
   preview:=atlas_core.school_dispatch_release_preview('2050-09-19',school.school_id,pg_temp.ng_id(11));
   command:=pg_temp.ng_request('SCHOOL-DISPATCH-RELEASE.v1','SCHOOL_DISPATCH_DOCUMENT_RELEASED',jsonb_build_object(
    'service_date','2050-09-19','school_id',school.school_id,'delivery_location_id',pg_temp.ng_id(11),
    'expected_source_fingerprint',preview->>'source_fingerprint','predecessor_release_id',null))
    ||jsonb_build_object('expected_version',0);
   execute 'set local role authenticated';
   response:=atlas_api.release_school_dispatch_document(command);
   execute 'reset role';
   if response->>'success' is distinct from 'true' then raise exception 'B1 PXK release failed: %',response; end if;
   documents:=documents||jsonb_build_array(jsonb_build_object('school',school.school_id,'preview',preview,'release',response));
  end loop;
  answer:=answer||jsonb_build_object('prepared',prepared,'po_releases',releases,'pxk',documents,
   'po_coverage',(select jsonb_agg(jsonb_build_object('school',s->>'school_id','ingredient',l.ingredient_id,
    'unit',l.unit_id,'quantity',s->>'ordered_quantity','supplier',p.supplier_id,
    'po_id',p.purchase_order_id,'po_revision',r.purchase_order_revision_id,'po_line',l.purchase_order_line_revision_id))
    from atlas_procurement.purchase_orders p join atlas_procurement.purchase_order_revisions r using(purchase_order_id)
    join atlas_procurement.purchase_order_line_revisions l using(purchase_order_revision_id)
    cross join lateral jsonb_array_elements(l.school_breakdown_snapshot) s
    where r.service_date='2050-09-19' and r.revision_status='RELEASED_TO_SUPPLIER'),
   'recipe_versions',(select count(*) from atlas_admin.recipe_versions));
  set constraints all immediate;
  set constraints all deferred;
 end if;
 raise exception using errcode='PB199',message='Rollback B1 confirmation case';
exception when sqlstate 'PB199' then return answer;
end $$;
insert into ng_results values('human30',pg_temp.b1_confirmation_case('30'),null);
select is((select response#>>'{saved,success}' from ng_results where name='human30'),'true','B1 explicit pre-commitment human confirmation30 succeeds');
select is((select response#>>'{readback,workbench,grouped_requirements,0,total_theoretical_quantity}' from ng_results where name='human30'),
 '28.000000','B1 human override does not multiply theoretical group by historical revision memberships');
select is((select jsonb_array_length(response#>'{readback,workbench,atomic_detail}') from ng_results where name='human30'),3,
 'B1 human override retains three atomic rows without revision fan-out');
-- Exact current authoring remains ADDITIVE; an Ingredient with no Recipe member
-- follows the same source-authoritative downstream path.
insert into atlas_admin.suppliers(supplier_id,supplier_code,supplier_name,document_code)
values(pg_temp.ng_id(60),'b1-product-a','B1 Supplier A','B1-A'),(pg_temp.ng_id(61),'b1-product-b','B1 Supplier B','B1-B');
insert into atlas_admin.supplier_eligibilities(supplier_id,ingredient_id,effective_from,priority)
select pg_temp.ng_id(s),pg_temp.ng_id(2000+i),'2050-01-01',s-59 from generate_series(60,61) s cross join generate_series(1,16) i;
update atlas_admin.ingredients set document_code='B1-'||ingredient_code where ingredient_id in(select pg_temp.ng_id(2000+i) from generate_series(1,16)i);
update atlas_admin.schools set dispatch_document_issuer_name='B1 local issuer',dispatch_document_issuer_address='Disposable local only'
where school_id in(pg_temp.ng_id(5001),pg_temp.ng_id(5002));
insert into ng_results values('documents28',pg_temp.b1_confirmation_case('28',true),null),('documents30',pg_temp.b1_confirmation_case('30',true),null);
select is(response#>>'{prepared,success}','true',name||' real preparation succeeds') from ng_results where name like 'documents%';
select is(jsonb_array_length(response->'po_releases'),2,name||' releases two independently numbered Supplier POs') from ng_results where name like 'documents%';
select is((select sum((p->>'quantity')::numeric) from jsonb_array_elements(response->'po_coverage')p
 where p->>'school'=pg_temp.ng_id(5001)::text and p->>'ingredient'=pg_temp.ng_id(2001)::text),
 case when name='documents30' then 30 else 28 end::numeric,name||' PO exact School coverage follows final confirmation') from ng_results where name like 'documents%';
select is((select sum((l->>'quantity')::numeric) from jsonb_array_elements(response->'pxk')p
 cross join lateral jsonb_array_elements(p#>'{release,authoritative_readback,lines}')l
 where p->>'school'=pg_temp.ng_id(5001)::text and l->>'ingredient_id'=pg_temp.ng_id(2001)::text),
 case when name='documents30' then 30 else 28 end::numeric,name||' official School PXK covers final confirmation') from ng_results where name like 'documents%';
select is((select sum((p->>'quantity')::numeric) from jsonb_array_elements(response->'po_coverage')p
 where p->>'school'=pg_temp.ng_id(5002)::text and p->>'ingredient'=pg_temp.ng_id(2001)::text),20::numeric,
 name||' shared-location School B remains20') from ng_results where name like 'documents%';
select is(response#>>'{facts,theoretical}','28.000000',name||' human decision retains original theoretical28') from ng_results where name like 'documents%';
select ok((select count(*)=3 and count(distinct s->>'pantry_line')=2 and sum((s->>'quantity')::numeric)=28
 from jsonb_array_elements(response#>'{facts,sources}')s),name||' original R20/B5/H3 source membership survives downstream') from ng_results where name like 'documents%';
select is((select (response#>>'{facts,decision,confirmed_quantity_after}')::numeric-(response#>>'{facts,decision,theoretical_quantity_before}')::numeric
 from ng_results where name='documents30'),2::numeric,'human +2 is explicit, separate from all Pantry and Recipe sources');
select is((select response->>'recipe_versions' from ng_results where name='documents30'),'4','no artificial Recipe or BOM revision from human confirmation');
select is((select sum((p->>'quantity')::numeric) from jsonb_array_elements(response->'po_coverage')p
 where p->>'school'=pg_temp.ng_id(5001)::text and p->>'ingredient'=pg_temp.ng_id(2016)::text),8::numeric,
 name||' Pantry-only Ingredient reaches Supplier PO with exact8') from ng_results where name like 'documents%';
select is((select sum((l->>'quantity')::numeric) from jsonb_array_elements(response->'pxk')p
 cross join lateral jsonb_array_elements(p#>'{release,authoritative_readback,lines}')l
 where p->>'school'=pg_temp.ng_id(5001)::text and l->>'ingredient_id'=pg_temp.ng_id(2016)::text),8::numeric,
 name||' Pantry-only Ingredient reaches School PXK with exact8') from ng_results where name like 'documents%';
select ok(not exists(select 1 from atlas_planning.theoretical_need_lines
 where ingredient_id=pg_temp.ng_id(2016) and contribution_family='RECIPE_DERIVED'),
 'Pantry-only Ingredient requires no fabricated Recipe, Menu or Attendance contribution');
select is((select sum((p->>'quantity')::numeric) from jsonb_array_elements(response->'po_coverage')p
 where p->>'supplier'=pg_temp.ng_id(60)::text and p->>'ingredient'=pg_temp.ng_id(2001)::text),
 (case when name='documents30' then 50 else 48 end*0.6)::numeric,
 name||' released Supplier A retains exact requested60percent across Schools') from ng_results where name like 'documents%';
select is((select sum((p->>'quantity')::numeric) from jsonb_array_elements(response->'po_coverage')p
 where p->>'supplier'=pg_temp.ng_id(61)::text and p->>'ingredient'=pg_temp.ng_id(2001)::text),
 (case when name='documents30' then 50 else 48 end*0.4)::numeric,
 name||' released Supplier B retains exact residual40percent across Schools') from ng_results where name like 'documents%';
select ok((select count(distinct s->>'confirmed_need_line_revision_id')=1
 and min(s->>'confirmed_need_line_revision_id')=response#>>'{facts,revision_id}'
 and sum((s->>'covered_quantity')::numeric)=case when name='documents30' then 30 else 28 end
 from jsonb_array_elements(response->'pxk')p
 cross join lateral jsonb_array_elements(p#>'{release,authoritative_readback,lines}')l
 cross join lateral jsonb_array_elements(l->'sources')s
 where p->>'school'=pg_temp.ng_id(5001)::text and l->>'ingredient_id'=pg_temp.ng_id(2001)::text),
 name||' frozen PXK sources reconcile to the exact final School revision') from ng_results where name like 'documents%';
select diag(jsonb_build_object('case',name,'facts',response->'facts','po_coverage',response->'po_coverage',
 'pxk',response->'pxk')::text) from ng_results where name like 'documents%';
create function pg_temp.b1_source_variant(variant text) returns jsonb language plpgsql as $$
declare payload jsonb; rows jsonb; command jsonb; generation_command jsonb; old_request jsonb; saved jsonb; generated jsonb; current_read jsonb; old_read jsonb;
 old_run uuid; answer jsonb; target_date date:='2050-09-19';
begin
 select need_generation_run_id into old_run from atlas_planning.need_generation_runs
 where generated_by_actor_id=pg_temp.ng_id(1) and period_start=target_date;
 old_request:=pg_temp.b1_need_read_request();
 select request->'payload' into payload from ng_requests where name='pantry';
 if variant='legacy' then
  target_date:='2050-09-26';
  rows:=jsonb_build_array(jsonb_build_object('service_date',target_date,'school_id',pg_temp.ng_id(5001),
   'ingredient_id',pg_temp.ng_id(2016),'pantry_need_purpose_id','3c3de399-b88f-575a-a3ce-eff9e16deb55',
   'requested_quantity','5.123456','note',null,'source_request_reference','Legacy neutral compatibility','source_row_reference','legacy-neutral'));
  payload:=jsonb_build_object('week_start',target_date,'no_additions_confirmed',false,'rows',rows,
   'expected_source_signature',null,'school_date_modes',jsonb_build_array(jsonb_build_object(
    'school_id',pg_temp.ng_id(5001),'service_date',target_date,'direct_need_mode','COMPLETE')));
  old_run:=null;
 else
  select jsonb_agg(case when value->>'ingredient_id'=pg_temp.ng_id(2001)::text
   then value||jsonb_build_object('requested_quantity',case
    when value->>'pantry_need_purpose_id'=pg_temp.ng_id(40)::text
     then case when variant='decimal' then '5.000001' else '6' end
    else case when variant='decimal' then '3.000002' else '2' end end) else value end)
  into rows from jsonb_array_elements(payload->'rows');
  select payload||jsonb_build_object('rows',rows,'expected_source_signature',b.source_signature)
  into payload from atlas_planning.pantry_need_batches b where b.week_start=target_date;
 end if;
 payload:=payload||jsonb_build_object('source_signature',atlas_core.pantry_02_signature(target_date,false,
  atlas_core.pantry_02_canonical_rows(target_date,rows)));
 command:=pg_temp.ng_request('PANTRY-02.v3','PANTRY_SAVED',payload)||jsonb_build_object('expected_version',
  coalesce((select version from atlas_planning.pantry_need_batches where week_start=target_date),1));
 generation_command:=pg_temp.ng_request('RMVP-04.v3','NEED_GENERATION_EXECUTED',
  jsonb_build_object('service_date',target_date,'expected_current_need_generation_run_id',old_run))
  ||jsonb_build_object('expected_version',coalesce((select version from atlas_planning.need_generation_runs where need_generation_run_id=old_run),1));
 execute 'set local role authenticated';
 saved:=atlas_api.save_pantry(command);
 if saved->>'success' is distinct from 'true' then raise exception 'Source variant Save failed: %',saved; end if;
 generated:=atlas_api.execute_need_generation(generation_command);
 if generated->>'success' is distinct from 'true' then raise exception 'Source variant generation failed: %',generated; end if;
 execute 'reset role';
 command:=old_request;
 command:=jsonb_set(command,'{payload}',(command->'payload')||jsonb_build_object(
  'period_start',target_date,'period_end',target_date,'need_generation_run_id',null,'detail_group',null,
  'filters',jsonb_build_object('school_id',pg_temp.ng_id(5001),'ingredient_id',pg_temp.ng_id(case when variant='legacy' then 2016 else 2001 end))));
 execute 'set local role authenticated';
 current_read:=atlas_api.get_need_generation_workbench(command);
 if old_run is not null then old_read:=atlas_api.get_need_generation_workbench(old_request); end if;
 execute 'reset role';
 answer:=jsonb_build_object('current',current_read,'old',old_read,'generated',generated);
 raise exception using errcode='PB199',message='Rollback B1 source variant';
exception when sqlstate 'PB199' then return answer;
end $$;
insert into ng_results values('decimal',pg_temp.b1_source_variant('decimal'),null),
 ('same_total',pg_temp.b1_source_variant('same_total'),null),('legacy',pg_temp.b1_source_variant('legacy'),null);
select is((select response#>>'{current,workbench,grouped_requirements,0,source_breakdown,total_theoretical_quantity}' from ng_results where name='decimal'),
 '28.000003','exact six-place quantities stay exact in the backend read');
select is((select response#>>'{current,workbench,grouped_requirements,0,source_breakdown,recipe_associated_quantity}' from ng_results where name='decimal'),
 '25.000001','R+B is an exact PostgreSQL subtotal');
select is((select response#>>'{current,workbench,grouped_requirements,0,source_breakdown,planning_supplement_quantity}' from ng_results where name='same_total'),
 '6.000000','same-total source change retains independent new B6');
select is((select response#>>'{current,workbench,grouped_requirements,0,source_breakdown,special_order_quantity}' from ng_results where name='same_total'),
 '2.000000','same-total source change retains independent new H2');
select is((select response#>>'{current,workbench,grouped_requirements,0,source_breakdown,total_theoretical_quantity}' from ng_results where name='same_total'),
 '28.000000','same total never hides changed source lineage');
select is((select response#>>'{current,workbench,grouped_requirements,0,source_breakdown,unclassified_direct_quantity}' from ng_results where name='legacy'),
 '5.123456','legacy neutral purpose stays explicitly unclassified');
select ok((select response#>>'{current,workbench,grouped_requirements,0,source_breakdown,recipe_derived_quantity}'='0'
 and response#>>'{current,workbench,grouped_requirements,0,source_breakdown,planning_supplement_quantity}'='0'
 and response#>>'{current,workbench,grouped_requirements,0,source_breakdown,special_order_quantity}'='0'
 and response#>>'{current,workbench,grouped_requirements,0,source_breakdown,total_theoretical_quantity}'='5.123456'
 from ng_results where name='legacy'),'historical COMPLETE does not fabricate Recipe or reinterpret neutral as B/H');
select is(response#>'{old,workbench,grouped_requirements,0,source_breakdown}',
 (select response#>'{workbench,grouped_requirements,0,source_breakdown}' from ng_results where name='source_read'),
 name||' historical source breakdown remains immutable') from ng_results where name in('decimal','same_total');
select * from finish();
rollback;
