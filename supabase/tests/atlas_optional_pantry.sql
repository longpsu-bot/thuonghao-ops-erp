-- Optional daily Pantry source: disposable local/CI only, all integrity guards enabled.
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

select set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.ng_id(101),'role','authenticated')::text,true);
set local role authenticated;
insert into ng_results select 'menu',atlas_api.save_weekly_menu(request),null from ng_requests where name='menu';
select is((select response->>'success' from ng_results where name='menu'),'true','Menu source saved');
select diag(response::text) from ng_results where name='menu' and response->>'success'<>'true';
insert into ng_results select 'attendance',atlas_api.save_attendance(request),null from ng_requests where name='attendance';
select is((select response->>'success' from ng_results where name='attendance'),'true','Attendance source saved');
select diag(response::text) from ng_results where name='attendance' and response->>'success'<>'true';
insert into ng_results select 'preflight',atlas_api.get_planning_input_preflight(jsonb_build_object(
 'contract_version','RMVP-03B.v2','requested_by_auth_subject',pg_temp.ng_id(101),'correlation_id',gen_random_uuid(),
 'payload',jsonb_build_object('period_start','2050-09-19','period_end','2050-09-19'))),null;
select is((select response#>>'{preflight,readiness_state}' from ng_results where name='preflight'),'READY','untouched optional additions do not block daily Need');
select diag(response::text) from ng_results where name='preflight' and response->>'success'<>'true';
reset role;
select is((select count(*) from atlas_planning.pantry_need_batches where week_start='2050-09-19'),0::bigint,'preflight creates no Pantry batch');
insert into ng_requests select 'generate',pg_temp.ng_request('RMVP-04.v3','NEED_GENERATION_EXECUTED',
jsonb_build_object('service_date','2050-09-19','expected_current_need_generation_run_id',null));
set local role authenticated;
insert into ng_results select 'generate',atlas_api.execute_need_generation(request),null from ng_requests where name='generate';
select is((select response->>'success' from ng_results where name='generate'),'true','daily Recipe Need generates without a weekly zero confirmation');
select diag(response::text) from ng_results where name='generate' and response->>'success'<>'true';
insert into ng_results select 'replay',atlas_api.execute_need_generation(request),null from ng_requests where name='generate';
select is((select response from ng_results where name='replay'),(select response from ng_results where name='generate'),'exact retry returns the same command response');
reset role;
insert into ng_requests select 'unchanged',jsonb_set(pg_temp.ng_request('RMVP-04.v3','NEED_GENERATION_EXECUTED',
jsonb_build_object('service_date','2050-09-19','expected_current_need_generation_run_id',response#>'{affected_aggregate_ids,need_generation_run_id}')),
'{expected_version}',response#>'{new_versions,need_generation_run_version}')
from ng_results where name='generate';
set local role authenticated;
insert into ng_results select 'unchanged',atlas_api.execute_need_generation(request),null from ng_requests where name='unchanged';
select is((select response->>'idempotency_status' from ng_results where name='unchanged'),'NO_CHANGE','a fresh unchanged intent does not regenerate absence-based Need');
select diag(response::text) from ng_results where name='unchanged' and response->>'success'<>'true';
reset role;
select ok(not exists(select 1 from (values('anon'),('authenticated'),('service_role')) r(role_name)
 where has_function_privilege(r.role_name,'atlas_core.optional_pantry_absent(date,date)','EXECUTE')),'absence predicate remains private');
select ok((select bool_and(e.pantry_absent and e.pantry_need_batch_id is null
 and e.pantry_need_batch_version is null and e.pantry_need_approval_snapshot_id is null)
 from atlas_planning.planning_input_evaluations e join atlas_planning.planning_input_sets s using(planning_input_set_id)
 where s.period_start='2050-09-19' and s.period_end=s.period_start),'immutable evaluation records verified absence without a fabricated approval');
select is((select count(*) from atlas_planning.pantry_need_batches where week_start='2050-09-19'),0::bigint,'generation creates no Pantry source or placeholder');
select ok(exists(select 1 from atlas_planning.theoretical_need_lines line
 join atlas_planning.need_generation_runs run using(need_generation_run_id)
 where run.period_start='2050-09-19' and line.contribution_family='RECIPE_DERIVED'),'Recipe contribution lineage is retained');
set constraints all immediate;
set constraints all deferred;
select ok(exists(select 1 from atlas_planning.planning_input_sets s,
 lateral jsonb_array_elements(atlas_core.rmvp_03b_all_history_items(s.planning_input_set_id)) item
 where s.period_start='2050-09-19' and item#>>'{evaluation,historical_pantry_state}'='OPTIONAL_ABSENT'
 and item#>>'{evaluation,can_authorize_need_generation_request}'='true'),'history distinguishes verified absence from pre-Pantry null bindings');

create function pg_temp.unmarked_evaluation() returns void language plpgsql as $$
begin
 insert into atlas_planning.planning_input_sets(planning_input_set_id,period_start,period_end,readiness_status,current_evaluation_id)
 values(pg_temp.ng_id(9000),'2050-09-20','2050-09-20','READY',pg_temp.ng_id(9001));
 insert into atlas_planning.planning_input_evaluations(planning_input_evaluation_id,planning_input_set_id,evaluation_version,
 evaluation_result,weekly_menu_id,weekly_menu_version,weekly_menu_approval_snapshot_id,attendance_batch_id,
 attendance_version,attendance_approval_snapshot_id,blocking_issue_count,warning_count,evaluated_by_actor_id)
 select pg_temp.ng_id(9001),pg_temp.ng_id(9000),1,'READY',weekly_menu_id,weekly_menu_version,weekly_menu_approval_snapshot_id,
 attendance_batch_id,attendance_version,attendance_approval_snapshot_id,0,0,pg_temp.ng_id(1)
 from atlas_planning.planning_input_evaluations where pantry_absent limit 1;
 set constraints all immediate;
end $$;
select throws_ok('select pg_temp.unmarked_evaluation()','23514',
 'READY requires either all three exact sources or one exact direct-complete Pantry source',
 'an unmarked null Pantry binding still cannot authorize READY');

-- Zero Attendance still records its warning, while an empty service date stays blocked.
insert into ng_requests select 'zero-attendance',pg_temp.ng_request('RMVP-04.v3','NEED_GENERATION_EXECUTED',
jsonb_build_object('service_date','2050-09-21','expected_current_need_generation_run_id',null));
set local role authenticated;
insert into ng_results select 'zero-attendance',atlas_api.execute_need_generation(request),null from ng_requests where name='zero-attendance';
select is((select response->>'success' from ng_results where name='zero-attendance'),'true','zero Attendance remains valid with optional additions');
insert into ng_results select 'empty-day',atlas_api.get_planning_input_preflight(jsonb_build_object(
 'contract_version','RMVP-03B.v2','requested_by_auth_subject',pg_temp.ng_id(101),'correlation_id',gen_random_uuid(),
 'payload',jsonb_build_object('period_start','2050-09-24','period_end','2050-09-24'))),null;
select is((select response#>>'{preflight,readiness_state}' from ng_results where name='empty-day'),'BLOCKED','optional additions do not bypass the no-source guard');
reset role;
select ok(exists(select 1 from atlas_planning.planning_input_evaluation_issues issue
 join atlas_planning.planning_input_sets s using(planning_input_set_id)
 where s.period_start='2050-09-21' and issue.severity='WARNING'),'exact zero-Attendance warning evidence survives');

-- Approve through real commands inside a subtransaction, then roll it back.
create function pg_temp.protected_first_source() returns jsonb language plpgsql as $$
declare command jsonb; saved jsonb; released jsonb; legacy jsonb; modern jsonb; answer jsonb; phase text;
begin
 begin
  select pg_temp.ng_request('RMVP-05.v2','CONFIRMED_NEED_SAVED',jsonb_build_object(
   'confirmed_need_batch_id',b.confirmed_need_batch_id,'lines',(
    select jsonb_agg(jsonb_build_object('confirmed_need_line_id',l.confirmed_need_line_id,
     'expected_current_revision_id',r.confirmed_need_line_revision_id,
     'expected_current_decision_id',l.current_confirmed_need_line_decision_id,
     'proposed_confirmed_quantity',r.confirmed_quantity::text,
     'reason_code','PROPOSAL_ACCEPTED','reason_note',null) order by l.confirmed_need_line_id)
    from atlas_planning.confirmed_need_lines l join atlas_planning.confirmed_need_line_revisions r
     on r.confirmed_need_line_id=l.confirmed_need_line_id and r.is_current
    where l.confirmed_need_batch_id=b.confirmed_need_batch_id)))||jsonb_build_object('expected_version',b.version,'reason_note',null)
  into command from atlas_planning.confirmed_need_batches b where b.period_start='2050-09-19';
  execute 'set local role authenticated';
  saved:=atlas_api.save_confirmed_needs(command);
  execute 'reset role';
  if saved->>'success'<>'true' then raise exception 'Protected fixture Save failed: %',saved; end if;
  foreach phase in array array['validate','approve'] loop
   select pg_temp.ng_request(case when phase='validate' then 'RMVP-06.v1' else 'RMVP-07.v1' end,
    case phase when 'validate' then 'BATCH_VALIDATION_REQUESTED' when 'approve' then 'CONFIRMED_NEED_APPROVAL_REQUESTED'
     else 'CONFIRMED_NEED_RELEASE_REQUESTED' end,jsonb_build_object('confirmed_need_batch_id',confirmed_need_batch_id))
     ||jsonb_build_object('expected_version',version)
   into command from atlas_planning.confirmed_need_batches where period_start='2050-09-19';
   execute 'set local role authenticated';
   released:=case phase when 'validate' then atlas_api.validate_confirmed_needs(command)
    when 'approve' then atlas_api.approve_confirmed_needs(command)
    else atlas_api.release_confirmed_needs_for_purchase_handoff(command) end;
   execute 'reset role';
   if released->>'success'<>'true' then raise exception 'Protected fixture % failed: %',phase,released; end if;
  end loop;
  command:=pg_temp.ng_request('PANTRY-02.v1','PANTRY02_TEST',jsonb_build_object(
   'week_start','2050-09-19','no_additions_confirmed',true,'rows','[]'::jsonb,
   'source_signature',atlas_core.pantry_02_signature('2050-09-19',true,'[]'::jsonb),'expected_source_signature',null));
  execute 'set local role authenticated';
  legacy:=atlas_api.save_pantry_draft(command);
  execute 'reset role';
  command:=pg_temp.ng_request('PANTRY-02.v2','PANTRY_SAVED',command->'payload');
  execute 'set local role authenticated';
  modern:=atlas_api.save_pantry(command);
  execute 'reset role';
  answer:=jsonb_build_object('legacy',legacy,'modern',modern);
  raise sqlstate 'PT001';
 exception when sqlstate 'PT001' then return answer;
 end;
end $$;
insert into ng_results select 'protected-first-source',pg_temp.protected_first_source(),null;
select is((select response#>>'{legacy,error_code}' from ng_results where name='protected-first-source'),
 'PLANNING_RELEASE_CORRECTION_REQUIRED','legacy first empty source cannot bypass a committed absence-based Need');
select is((select response#>>'{modern,error_code}' from ng_results where name='protected-first-source'),
 'PLANNING_RELEASE_CORRECTION_REQUIRED','modern first empty source cannot bypass a committed absence-based Need');
select is((select count(*) from atlas_planning.pantry_need_batches where week_start='2050-09-19'),0::bigint,
 'protected-source test leaves source and released history unchanged');
select ok('2050-09-19'::date=any(atlas_core.issue_222_affected_dates('PANTRY',jsonb_build_object(
 'week_start','2050-09-19','no_additions_confirmed',false,'rows',jsonb_build_array(jsonb_build_object(
 'service_date','2050-09-20','school_id',pg_temp.ng_id(5001),'ingredient_id',pg_temp.ng_id(2001),
 'pantry_need_purpose_id','3c3de399-b88f-575a-a3ce-eff9e16deb55','requested_quantity','1'))))),
 'a first Tuesday source also checks Monday absence-based commitments');

-- A later real source participates in freshness and preserves the original generation.
insert into atlas_planning.pantry_need_purposes(pantry_need_purpose_id,purpose_code,purpose_name_vi,purpose_description,note_rule,display_order)
values(pg_temp.ng_id(40),'optional_pantry_test','Synthetic addition','Optional Pantry regression','OPTIONAL',1);
with rows as (select jsonb_build_array(jsonb_build_object(
 'service_date','2050-09-19','school_id',pg_temp.ng_id(5001),'ingredient_id',pg_temp.ng_id(2001),
 'pantry_need_purpose_id',pg_temp.ng_id(40),'requested_quantity','2.500000','note',null,
 'source_request_reference','Synthetic Pantry','source_row_reference','optional-pantry')) as rows)
insert into ng_requests select 'pantry',pg_temp.ng_request('PANTRY-02.v2','PANTRY_SAVED',
jsonb_build_object('week_start','2050-09-19','no_additions_confirmed',false,'source_signature',
atlas_core.pantry_02_signature('2050-09-19',false,atlas_core.pantry_02_canonical_rows('2050-09-19',rows)),
'expected_source_signature',null,'rows',rows)) from rows;
set local role authenticated;
insert into ng_results select 'pantry',atlas_api.save_pantry(request),null from ng_requests where name='pantry';
select is((select response->>'success' from ng_results where name='pantry'),'true','first real addition is saved through existing correction checks');
select diag(response::text) from ng_results where name='pantry' and response->>'success'<>'true';
insert into ng_results select 'changed-preflight',atlas_api.get_planning_input_preflight(jsonb_build_object(
 'contract_version','RMVP-03B.v2','requested_by_auth_subject',pg_temp.ng_id(101),'correlation_id',gen_random_uuid(),
 'payload',jsonb_build_object('period_start','2050-09-19','period_end','2050-09-19'))),null;
select is((select response#>>'{preflight,downstream_currentness}' from ng_results where name='changed-preflight'),'OUTDATED','first addition makes the absent-source Need outdated');
reset role;
select ok(not atlas_core.optional_pantry_absent('2050-09-19','2050-09-19'),'an existing Pantry batch cannot be inferred away');
select ok(exists(select 1 from atlas_planning.planning_input_evaluations e
 join atlas_planning.planning_input_sets s using(planning_input_set_id)
 where s.period_start='2050-09-19' and e.pantry_absent),'original immutable absence evidence is preserved');
set constraints all immediate;
set constraints all deferred;
insert into ng_requests select 'reopen-pantry',jsonb_set(pg_temp.ng_request('PANTRY-02.v1','PLANNING_REVIEW_CORRECTION',
 jsonb_build_object('week_start',week_start,'expected_source_signature',source_signature)),
 '{expected_version}',to_jsonb(version)) from atlas_planning.pantry_need_batches where week_start='2050-09-19';
set local role authenticated;
insert into ng_results select 'reopen-pantry',atlas_api.reopen_pantry(request),null from ng_requests where name='reopen-pantry';
select is((select response->>'success' from ng_results where name='reopen-pantry'),'true','existing additions reopen through the original command');
insert into ng_results select 'unfinished',atlas_api.get_planning_input_preflight(jsonb_build_object(
 'contract_version','RMVP-03B.v2','requested_by_auth_subject',pg_temp.ng_id(101),'correlation_id',gen_random_uuid(),
 'payload',jsonb_build_object('period_start','2050-09-19','period_end','2050-09-19'))),null;
select is((select response#>>'{preflight,readiness_state}' from ng_results where name='unfinished'),'BLOCKED','unfinished existing additions still block Need');
select is((select response#>>'{preflight,source_evidence,pantry,optional_absent}' from ng_results where name='unfinished'),'false','a reopened batch is never interpreted as absent');
reset role;
select ok(not atlas_core.optional_pantry_absent('2050-09-19','2050-09-25'),'historical multi-day periods retain their mandatory binding');
set constraints all immediate;
select * from finish();
rollback;
