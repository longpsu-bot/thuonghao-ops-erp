-- Rule administration before and after a saved menu, through authenticated RPCs.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = pg_catalog,public,extensions;
select no_plan();
-- Emulate the constraint flush between PostgREST requests inside this rollback-only test.
create procedure pg_temp.check_commit_constraints() language plpgsql security definer set search_path='' as $$
begin
 set constraints all immediate;
 set constraints all deferred;
end $$;
create function pg_temp.id(n int) returns uuid language sql immutable as $$
  select ('f1f00000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
$$;
insert into atlas_core.actors(actor_id,actor_type,display_name) values(pg_temp.id(1),'HUMAN','Rule operator');
insert into atlas_core.actor_auth_subjects(actor_id,auth_subject_id) values(pg_temp.id(1),pg_temp.id(2));
insert into atlas_core.roles(role_id,role_code,role_name) values(pg_temp.id(3),'weekly-rule-test','Rule test');
insert into atlas_core.role_capabilities(role_id,capability_id) select pg_temp.id(3),capability_id
  from atlas_core.capabilities where capability_code in ('planning.inputs.read','planning.pantry.write','planning.weekly_menu.write');
insert into atlas_core.actor_role_memberships(actor_id,role_id) values(pg_temp.id(1),pg_temp.id(3));
insert into atlas_core.actor_scopes(actor_id,scope_kind) values(pg_temp.id(1),'GLOBAL');
insert into atlas_admin.customers(customer_id,customer_code,customer_name,customer_type)
  values(pg_temp.id(4),'rule-customer','Rule customer','SCHOOL_CATERING');
insert into atlas_admin.delivery_locations(delivery_location_id,customer_id,location_code,location_name,address_text)
  values(pg_temp.id(5),pg_temp.id(4),'rule-door','Door','Rule test');
insert into atlas_admin.schools(school_id,customer_id,school_code,school_name,default_delivery_location_id)
  values(pg_temp.id(6),pg_temp.id(4),'rule-school','Rule school',pg_temp.id(5));
insert into atlas_admin.units(unit_id,unit_code,unit_name,dimension_code) values(pg_temp.id(7),'rule-kg','kg','mass');
insert into atlas_admin.ingredients(ingredient_id,ingredient_code,ingredient_name,purchase_unit_id,order_step)
  values(pg_temp.id(8),'rule-garlic','Garlic',pg_temp.id(7),0.1);
create function pg_temp.read_rules(w date) returns jsonb language sql volatile as $$
  select atlas_api.get_weekly_pantry_rules(jsonb_build_object('contract_version','PANTRY-02.v1',
    'correlation_id',gen_random_uuid(),'requested_by_auth_subject',pg_temp.id(2),
    'payload',jsonb_build_object('week_start',w,'school_id',pg_temp.id(6),'preview',
      jsonb_build_object('school_id',pg_temp.id(6),'quantity_per_day','0.4'))));
$$;
create function pg_temp.rule_command(w date, v int, rate text, enabled boolean) returns jsonb language sql volatile as $$
  select jsonb_build_object('contract_version','PANTRY-02.v1','command_id',command_id,'idempotency_key',command_id::text,
    'correlation_id',gen_random_uuid(),'requested_by_auth_subject',pg_temp.id(2),'requested_at',now(),
    'expected_version',v,'reason_code','WEEKLY_PANTRY_RULE_SAVED','reason_note',null,
    'payload',jsonb_build_object('week_start',w,'school_id',pg_temp.id(6),'ingredient_id',pg_temp.id(8),
      'quantity_per_day',rate,'enabled',enabled,'expected_unit_id',pg_temp.id(7),
      'expected_menu_token',pg_temp.read_rules(w)->>'menu_token')) from (select gen_random_uuid() command_id) ids;
$$;

insert into atlas_admin.schools(school_id,customer_id,school_code,school_name,default_delivery_location_id,display_order)
 values(pg_temp.id(16),pg_temp.id(4),'week-school-b','School B',pg_temp.id(5),1);
insert into atlas_admin.dishes(dish_id,dish_code,dish_name,dish_type_id,dish_status,requires_need_generation)
 select pg_temp.id(n),'week-'||code,code,dish_type_id,'ACTIVE',false from (values(9,'soup'),(10,'savory')) d(n,code)
 join atlas_admin.dish_types on dish_type_code=code;
insert into atlas_planning.pantry_need_purposes(pantry_need_purpose_id,purpose_code,purpose_name_vi,purpose_description,note_rule,display_order)
 values(pg_temp.id(11),'school_requested_supplement','Đặt riêng','Đặt riêng','OPTIONAL',2)
 on conflict(purpose_code) do nothing;
create function pg_temp.row_for(s int, day_no int, dish int) returns jsonb language sql as $$
 select jsonb_build_object('school_id',pg_temp.id(s),'service_date',date '2050-09-19'+day_no,
  'menu_slot_code',case dish when 9 then 'soup' else 'savory' end,'dish_id',pg_temp.id(dish),
  'source_row_reference',s||'/'||day_no||'/'||dish);
$$;
create function pg_temp.menu_request(raw_rows jsonb) returns jsonb language sql volatile security definer as $$
 with proposal as (select atlas_core.rmvp_03a_canonical_menu_rows(raw_rows) rows,gen_random_uuid() id)
 select jsonb_build_object('contract_version','RMVP-03A.v2','command_id',p.id,'idempotency_key',p.id::text,
 'correlation_id',gen_random_uuid(),'requested_by_auth_subject',pg_temp.id(2),'requested_at',now(),
 'expected_version',coalesce(m.version,1),'reason_code','WEEKLY_MENU_SAVED','reason_note',null,
 'payload',jsonb_build_object('week_start','2050-09-19','source_type','GOOGLE_SHEET','source_name','Weekly test',
  'source_signature',atlas_core.rmvp_03a_menu_signature(p.rows),'expected_source_signature',m.source_signature,'rows',p.rows))
 from proposal p left join atlas_planning.weekly_menus m on m.week_start='2050-09-19';
$$;
create function pg_temp.pantry_request(extra jsonb default '[]'::jsonb) returns jsonb language sql volatile security definer as $$
 with proposal as (select jsonb_build_array(jsonb_build_object('school_id',pg_temp.id(6),'service_date','2050-09-20',
  'ingredient_id',pg_temp.id(8),'pantry_need_purpose_id',p.pantry_need_purpose_id,'requested_quantity','0.5','note','staff'))||extra rows
  from atlas_planning.pantry_need_purposes p where p.purpose_code='school_requested_supplement'), id as (select gen_random_uuid() cid)
 select jsonb_build_object('contract_version','PANTRY-02.v3','command_id',cid,'idempotency_key',cid::text,
 'correlation_id',gen_random_uuid(),'requested_by_auth_subject',pg_temp.id(2),'requested_at',now(),
 'expected_version',coalesce(b.version,1),'reason_code','SOURCE_COMPLETION_SAVED','reason_note',null,
 'payload',jsonb_build_object('week_start','2050-09-19','no_additions_confirmed',false,
  'source_signature',atlas_core.pantry_02_signature('2050-09-19',false,atlas_core.weekly_pantry_canonical_rows('2050-09-19',rows)),
  'expected_source_signature',b.source_signature,'rows',rows,'school_date_modes',jsonb_build_array(jsonb_build_object(
   'school_id',pg_temp.id(6),'service_date','2050-09-20','direct_need_mode','ADDITIVE'))))
 from proposal cross join id left join atlas_planning.pantry_need_batches b on b.week_start='2050-09-19';
$$;
create temp table scenarios as select
 jsonb_build_array(pg_temp.row_for(6,1,9),pg_temp.row_for(6,1,10),pg_temp.row_for(6,2,9),pg_temp.row_for(6,3,9),pg_temp.row_for(16,3,9)) initial,
 jsonb_build_array(pg_temp.row_for(6,4,9)) friday;
create temp table menu_result(label text,response jsonb);
grant select on scenarios to authenticated;
grant insert,select on menu_result to authenticated;
select set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.id(2),'role','authenticated')::text,true);
set local role authenticated;
insert into menu_result values('rule',atlas_api.save_weekly_pantry_rule(pg_temp.rule_command('2050-09-19',0,'0.4',true)));
call pg_temp.check_commit_constraints();
insert into menu_result values('rule B',atlas_api.save_weekly_pantry_rule(jsonb_set(pg_temp.rule_command('2050-09-19',0,'0.4',true),
 '{payload,school_id}',to_jsonb(pg_temp.id(16)))));
call pg_temp.check_commit_constraints();
insert into menu_result values('manual',atlas_api.save_pantry(pg_temp.pantry_request()));
call pg_temp.check_commit_constraints();
create temporary table first_menu_request as select pg_temp.menu_request(initial) request from scenarios;
insert into menu_result select 'menu',atlas_api.save_weekly_menu(request) from first_menu_request;
call pg_temp.check_commit_constraints();
select ok(response->>'success'='true',label||' command saved') from menu_result order by label;
select diag(response::text) from menu_result where response->>'success' is distinct from 'true';
insert into menu_result select 'replay',atlas_api.save_weekly_menu(request) from first_menu_request;
call pg_temp.check_commit_constraints();
reset role;

create temp view current_snapshot as select l.* from atlas_planning.pantry_need_batches b
 join atlas_planning.pantry_need_approval_snapshot_lines l on l.pantry_need_approval_snapshot_id=b.latest_approval_snapshot_id
 where b.week_start='2050-09-19';
select is((select requested_quantity from current_snapshot where school_id=pg_temp.id(6) and purpose_code_snapshot='auto_weekly_pantry'),
 1.2::numeric,'three distinct menu days, including two dishes on Tuesday, give 1.2 without attendance');
select is((select requested_quantity from current_snapshot where school_id=pg_temp.id(16)),0.4::numeric,'second school uses its own single Thursday');
select is((select counted_menu_days from current_snapshot where school_id=pg_temp.id(6) and purpose_code_snapshot='auto_weekly_pantry'),
 array['2050-09-20','2050-09-21','2050-09-22']::date[],'snapshot stores exact counted dates');
select ok((select bool_and(weekly_rule_revision_id is not null and weekly_menu_snapshot_id is not null) from current_snapshot
 where purpose_code_snapshot='auto_weekly_pantry'),'immutable generated lines identify rule and menu approvals');
select is((select count(*) from current_snapshot where school_id=pg_temp.id(6)),2::bigint,'manual H and recurring H have separate line identities');
select is((select count(*) from atlas_planning.pantry_need_approval_snapshots),2::bigint,'replaying menu does not append a Pantry snapshot');
select is(atlas_core.issue_222_affected_dates('WEEKLY_MENU',(pg_temp.menu_request(initial||friday))->'payload'),
 array['2050-09-20','2050-09-23']::date[],'Friday preview guards both Tuesday and Friday') from scenarios;
set local role authenticated;
create temporary table friday_request as select pg_temp.menu_request(initial||friday) request from scenarios;
insert into menu_result select 'add Friday',atlas_api.save_weekly_menu(request) from friday_request;
call pg_temp.check_commit_constraints();
reset role;

select is((select sum(requested_quantity) from current_snapshot where school_id=pg_temp.id(6)),2.1::numeric,
 'new snapshot contributes 1.6 automatic plus 0.5 manual');
set local role authenticated;
insert into menu_result select 'manual roundtrip',atlas_api.save_pantry(pg_temp.pantry_request(jsonb_build_array(jsonb_build_object(
 'school_id',pg_temp.id(6),'ingredient_id',pg_temp.id(8),'pantry_need_purpose_id','69c413ef-4c9d-4671-b9c5-73a7901cd9f1',
 'requested_quantity','300','service_date','2050-09-20'))));
call pg_temp.check_commit_constraints();
insert into menu_result select 'remove Friday',atlas_api.save_weekly_menu(pg_temp.menu_request(initial)) from scenarios;
call pg_temp.check_commit_constraints();
insert into menu_result select 'remove school A',atlas_api.save_weekly_menu(pg_temp.menu_request(jsonb_build_array(pg_temp.row_for(16,3,9))));
call pg_temp.check_commit_constraints();
reset role;

select is((select sum(requested_quantity) from current_snapshot where school_id=pg_temp.id(6)),0.5::numeric,
 'removing the last menu date removes the generated contribution and retains the manual row');
select ok((select bool_and(l.requested_quantity<2) from atlas_planning.pantry_need_approval_snapshot_lines l
 where purpose_code_snapshot='auto_weekly_pantry'),'a submitted automatic quantity cannot override the server');
select ok((select bool_and(response->>'success'='true') from menu_result),'all source changes completed');
select diag(label||': '||response::text) from menu_result where response->>'success' is distinct from 'true';
create temp table expected_blocks(label text,response jsonb);
grant insert,select on expected_blocks to authenticated;
insert into atlas_admin.units(unit_id,unit_code,unit_name,dimension_code) values(pg_temp.id(12),'rule-g','g','mass');
update atlas_admin.ingredients set purchase_unit_id=pg_temp.id(12) where ingredient_id=pg_temp.id(8);
set local role authenticated;
insert into expected_blocks select 'unit',atlas_api.save_weekly_menu(pg_temp.menu_request(initial)) from scenarios;
reset role;
select is((select response->>'error_code' from expected_blocks where label='unit'),'WEEKLY_PANTRY_UNIT_CHANGED',
 'changed purchase unit requires an explicit new rule rate');
update atlas_admin.ingredients set purchase_unit_id=pg_temp.id(7) where ingredient_id=pg_temp.id(8);
insert into atlas_admin.delivery_locations(delivery_location_id,customer_id,location_code,location_name,address_text)
 values(pg_temp.id(13),pg_temp.id(4),'alternate-gate','Gate B','Test address B');
update atlas_admin.schools set default_delivery_location_id=pg_temp.id(13) where school_id=pg_temp.id(6);
set local role authenticated;
insert into expected_blocks select 'manual location',atlas_api.save_weekly_menu(pg_temp.menu_request(initial)) from scenarios;
reset role;
select is((select response->>'error_code' from expected_blocks where label='manual location'),'STALE_SOURCE_SIGNATURE',
 'automatic refresh preserves the approved manual delivery location after catalog drift');
update atlas_admin.schools set default_delivery_location_id=pg_temp.id(5) where school_id=pg_temp.id(6);
-- Make Tuesday a protected Need through the existing COMPLETE compatibility flow.
insert into atlas_core.role_capabilities(role_id,capability_id)
 select pg_temp.id(3),capability_id from atlas_core.capabilities
 where capability_code like 'planning.%' or capability_code like 'confirmed_need%' or capability_code like 'procurement.%'
 on conflict do nothing;
insert into atlas_planning.need_generation_calculation_contracts(need_generation_calculation_contract_id,contract_code,current_revision_id,version)
 values(pg_temp.id(20),'school_catering_proportional_per_basis',pg_temp.id(21),1);
insert into atlas_planning.need_generation_calculation_contract_revisions(need_generation_calculation_contract_revision_id,need_generation_calculation_contract_id,revision_number,formula_kind,quantity_precision,quantity_scale,factor_precision,factor_scale,final_coercion_mode,approved_by_actor_id,approved_at)
 values(pg_temp.id(21),pg_temp.id(20),1,'STUDENT_TEACHER_PORTIONS_X_RECIPE_QTY_DIV_BASIS',20,6,24,12,'POSTGRES_NUMERIC_SCALE_HALF_AWAY_FROM_ZERO',pg_temp.id(1),now());
insert into atlas_planning.planning_quantity_policies(planning_quantity_policy_id,unit_id,created_by_actor_id)
 values(pg_temp.id(30),pg_temp.id(7),pg_temp.id(1));
insert into atlas_planning.planning_quantity_policy_revisions(planning_quantity_policy_revision_id,planning_quantity_policy_id,unit_id,
 revision_number,planning_step,effective_from,policy_revision_status,created_by_actor_id)
 values(pg_temp.id(31),pg_temp.id(30),pg_temp.id(7),1,0.000001,'2020-01-01','DRAFT',pg_temp.id(1));
update atlas_planning.planning_quantity_policy_revisions set policy_revision_status='ACTIVE',approved_by_actor_id=pg_temp.id(1),approved_at=now(),
 activated_by_actor_id=pg_temp.id(1),activated_at=now() where planning_quantity_policy_revision_id=pg_temp.id(31);
create function pg_temp.op(contract text,reason text,version bigint,payload jsonb) returns jsonb language sql as $$
 select jsonb_build_object('contract_version',contract,'command_id',id,'idempotency_key',id::text,'correlation_id',gen_random_uuid(),
  'requested_by_auth_subject',pg_temp.id(2),'requested_at',now(),'expected_version',version,'reason_code',reason,'reason_note',null,
  'payload',payload) from (select gen_random_uuid() id) q;
$$;
set local role authenticated;
insert into menu_result select 'legacy reopen',atlas_api.reopen_weekly_menu(pg_temp.menu_request(initial)||
 jsonb_build_object('contract_version','RMVP-03A.v1','reason_note','Legacy approval test','payload',jsonb_build_object('week_start','2050-09-19'))) from scenarios;
insert into menu_result select 'legacy draft',atlas_api.save_weekly_menu_draft(pg_temp.menu_request(initial)||'{"contract_version":"RMVP-03A.v1"}') from scenarios;
insert into menu_result select 'legacy validate',atlas_api.validate_weekly_menu(pg_temp.menu_request(initial)||
 jsonb_build_object('contract_version','RMVP-03A.v1','payload',jsonb_build_object('week_start','2050-09-19'))) from scenarios;
insert into menu_result select 'legacy approve',atlas_api.approve_weekly_menu(pg_temp.menu_request(initial)||
 jsonb_build_object('contract_version','RMVP-03A.v1','payload',jsonb_build_object('week_start','2050-09-19'))) from scenarios;
select ok((select bool_and(response->>'success'='true') from menu_result where label like 'legacy %'),'standalone Menu approval also refreshes Pantry');
call pg_temp.check_commit_constraints();
insert into menu_result select 'complete',atlas_api.save_pantry(jsonb_set(pg_temp.pantry_request(),'{payload,school_date_modes,0,direct_need_mode}','"COMPLETE"'));
call pg_temp.check_commit_constraints();
insert into menu_result select 'generation',atlas_api.execute_need_generation(pg_temp.op('RMVP-04.v3','NEED_GENERATION_EXECUTED',1,
 '{"service_date":"2050-09-20","expected_current_need_generation_run_id":null}'));
call pg_temp.check_commit_constraints();
reset role;

select diag(label||': '||response::text) from menu_result where response->>'success' is distinct from 'true';
select is((select response->>'success' from menu_result where label='generation'),'true','Tuesday Need is actually generated');
create temporary table confirm_tuesday as
 select pg_temp.op('RMVP-05.v2','CONFIRMED_NEED_SAVED',b.version,jsonb_build_object(
 'confirmed_need_batch_id',b.confirmed_need_batch_id,'lines',jsonb_agg(jsonb_build_object('confirmed_need_line_id',l.confirmed_need_line_id,
 'expected_current_revision_id',r.confirmed_need_line_revision_id,'expected_current_decision_id',l.current_confirmed_need_line_decision_id,
 'proposed_confirmed_quantity',r.confirmed_quantity::text,'reason_code','PROPOSAL_ACCEPTED','reason_note',null)))) request
 from atlas_planning.confirmed_need_batches b join atlas_planning.confirmed_need_lines l using(confirmed_need_batch_id)
 join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_id)
 where b.period_start='2050-09-20' and r.is_current group by b.confirmed_need_batch_id,b.version;
grant select on confirm_tuesday to authenticated;
set local role authenticated;
insert into menu_result select 'confirm',atlas_api.save_confirmed_needs(request) from confirm_tuesday;
call pg_temp.check_commit_constraints();
reset role;

insert into atlas_admin.suppliers(supplier_id,supplier_code,supplier_name,document_code)
 values(pg_temp.id(40),'weekly-pantry-supplier','Weekly pantry supplier','WP-SUP');
insert into atlas_admin.supplier_eligibilities(supplier_id,ingredient_id,effective_from,priority,reason_note)
 values(pg_temp.id(40),pg_temp.id(8),'2020-01-01',1,'Weekly pantry test');
set local role authenticated;
insert into menu_result values('supplier read',atlas_api.get_confirmed_supplier_allocation_workbench(jsonb_build_object(
 'contract_version','CONFIRMED-SUPPLIER-ALLOCATION.v1','requested_by_auth_subject',pg_temp.id(2),'correlation_id',gen_random_uuid(),
 'payload',jsonb_build_object('date_start','2050-09-20','date_end','2050-09-20'))));
insert into menu_result select 'allocate',atlas_api.save_confirmed_supplier_allocation(pg_temp.op('CONFIRMED-SUPPLIER-ALLOCATION.v1',
 'CONFIRMED_SUPPLIER_ALLOCATION_SAVED',(r#>>'{family,version}')::bigint,jsonb_build_object('family',jsonb_build_object(
 'service_date',r->'service_date','delivery_location_id',r->'delivery_location_id','ingredient_id',r->'ingredient_id','unit_id',r->'unit_id',
 'expected_source_fingerprint',r#>'{family,source_fingerprint}','expected_source_batch_id',r->'source_confirmed_need_batch_id',
 'expected_source_batch_version',r->'source_confirmed_need_batch_version'),'splits',jsonb_build_array(jsonb_build_object(
 'supplier_id',pg_temp.id(40),'allocated_quantity',r->'family_quantity')))))
 from menu_result cross join lateral jsonb_array_elements(response->'rows') r where label='supplier read';
call pg_temp.check_commit_constraints();
reset role;
create temporary table release_tuesday as select pg_temp.op('RMVP-07.v2','CONFIRMED_NEED_RELEASED',version,
 jsonb_build_object('confirmed_need_batch_id',confirmed_need_batch_id)) request from atlas_planning.confirmed_need_batches
 where period_start='2050-09-20';
grant select on release_tuesday to authenticated;
set local role authenticated;
insert into menu_result select 'release',atlas_api.release_confirmed_needs(request) from release_tuesday;
call pg_temp.check_commit_constraints();
reset role;
select is((select response->>'success' from menu_result where label='release'),'true','Tuesday Need released through supplier allocation');
select diag(label||': '||response::text) from menu_result where response->>'success' is distinct from 'true';
set local role authenticated;
insert into menu_result select 'guard',atlas_api.save_weekly_menu(pg_temp.menu_request(initial||friday)) from scenarios;
call pg_temp.check_commit_constraints();
reset role;

select is((select response->>'success' from menu_result where label='confirm'),'true','Tuesday Need confirmation succeeds');
select is((select response->>'error_code' from menu_result where label='guard'),'PLANNING_RELEASE_CORRECTION_REQUIRED',
 'Friday menu edit stops at the existing Tuesday correction boundary');
select is((select requested_quantity from current_snapshot where school_id=pg_temp.id(6) and purpose_code_snapshot='auto_weekly_pantry'),
 1.2::numeric,'protected Friday change leaves the current Tuesday snapshot intact');
set local role authenticated;
select is((select atlas_api.save_weekly_menu(request) from friday_request),(select response from menu_result where label='add Friday'),
 'an exact authorized Friday replay returns its original receipt after Tuesday release');
reset role;
select * from finish();
rollback;
