-- Rule administration before and after a saved menu, through authenticated RPCs.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = pg_catalog,public,extensions;
select no_plan();
create function pg_temp.id(n int) returns uuid language sql immutable as $$
  select ('f1f00000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
$$;
insert into atlas_core.actors(actor_id,actor_type,display_name) values(pg_temp.id(1),'HUMAN','Rule operator');
insert into atlas_core.actor_auth_subjects(actor_id,auth_subject_id) values(pg_temp.id(1),pg_temp.id(2));
insert into atlas_core.roles(role_id,role_code,role_name) values(pg_temp.id(3),'weekly-rule-test','Rule test');
insert into atlas_core.role_capabilities(role_id,capability_id) select pg_temp.id(3),capability_id
  from atlas_core.capabilities where capability_code in ('planning.inputs.read','planning.pantry.write');
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
select ok(not has_table_privilege('authenticated','atlas_planning.weekly_pantry_rule_revisions','SELECT')
  and not has_table_privilege('atlas_planning_command_runtime','atlas_planning.weekly_pantry_rule_revisions','UPDATE')
  and not has_function_privilege('anon','atlas_api.save_weekly_pantry_rule(jsonb)','EXECUTE'),
  'browser roles cannot access rule history directly and revisions cannot be updated by Planning');
select set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.id(2),'role','authenticated')::text,true);
set local role authenticated;
select is(pg_temp.read_rules('2050-09-19')->'rules','[]'::jsonb,'empty rule history before first save');
select is((pg_temp.read_rules('2050-09-19')#>>'{preview,total_quantity}')::numeric,0::numeric,'empty-week preview has zero quantity');
create temporary table first_command as select pg_temp.rule_command('2050-09-19',0,'0.4',true) request;
create temporary table first_result as select atlas_api.save_weekly_pantry_rule(request) response from first_command;
select is((select response->>'success' from first_result),'true','authorized operator creates a rule with an exact decimal rate');
select diag(response::text) from first_result where response->>'success' is distinct from 'true';
select is((select atlas_api.save_weekly_pantry_rule(request) from first_command),(select response from first_result),'exact replay returns original receipt');
select is((select atlas_api.save_weekly_pantry_rule(jsonb_set(request,'{payload,quantity_per_day}','"0.5"')) from first_command)->>'error_code',
  'IDEMPOTENCY_CONFLICT','same command cannot change the submitted rate');
select is(atlas_api.save_weekly_pantry_rule(pg_temp.rule_command('2050-09-19',0,'1',true))->>'error_code',
  'STALE_VERSION','competing creator loses optimistic concurrency check');
select is(atlas_api.save_weekly_pantry_rule(jsonb_set(pg_temp.rule_command('2050-09-19',1,'1',true),
  '{payload,expected_menu_token}',to_jsonb(repeat('0',64))))->>'error_code','STALE_VERSION','stale menu preview is rejected');
select is(atlas_api.save_weekly_pantry_rule(pg_temp.rule_command('2050-09-19',1,'0.1234567',true))->>'error_code',
  'VALIDATION_FAILED','over-precision is rejected rather than rounded');
select is(atlas_api.save_weekly_pantry_rule(pg_temp.rule_command('2050-10-03',1,null,false))->>'version','2',
  'disable takes effect on its own Monday with a new revision');
select is(atlas_api.save_weekly_pantry_rule(pg_temp.rule_command('2050-09-26',2,'0.6',true))->>'version','3',
  'editing an earlier week preserves the pre-existing future stop');
select is((pg_temp.read_rules('2050-09-19')#>>'{rules,0,quantity_per_day}')::numeric,0.4::numeric,'first week keeps its rate');
select is((pg_temp.read_rules('2050-09-26')#>>'{rules,0,quantity_per_day}')::numeric,0.6::numeric,'middle week gets its new rate');
select is(pg_temp.read_rules('2050-10-03')#>>'{rules,0,enabled}','false','later stop still applies');
select ok(pg_temp.read_rules('2050-09-12')#>>'{rules,0,enabled}'='false'
  and pg_temp.read_rules('2050-09-12')#>>'{rules,0,version}'='3','future-only rule has CAS head but no current contribution');
select is(atlas_api.save_weekly_pantry_rule(pg_temp.rule_command('2050-09-26',3,'0.6',true))->>'version','3',
  'identical values do not create another revision');
reset role;
select is((select count(*) from atlas_planning.weekly_pantry_rule_revisions where school_id=pg_temp.id(6)),3::bigint,
  'only three accepted changes create revisions');
delete from atlas_core.role_capabilities where role_id=pg_temp.id(3)
  and capability_id=(select capability_id from atlas_core.capabilities where capability_code='planning.pantry.write');
set local role authenticated;
select is(pg_temp.read_rules('2050-09-19')->>'can_manage','false','read-only operator has no write action');
select is(atlas_api.save_weekly_pantry_rule(pg_temp.rule_command('2050-09-26',3,'1',true))->>'success','false',
  'write privilege is checked again at command time');
reset role;
-- Two already approved menus should be reconciled in the same rule command.
insert into atlas_core.role_capabilities(role_id,capability_id)
select pg_temp.id(3),capability_id from atlas_core.capabilities where capability_code like 'planning.%'
on conflict do nothing;
insert into atlas_admin.ingredients(ingredient_id,ingredient_code,ingredient_name,purchase_unit_id,order_step)
  values(pg_temp.id(9),'rule-onion','Onion',pg_temp.id(7),0.1);
insert into atlas_admin.school_types(school_type_id,school_type_code,school_type_name)
  values(pg_temp.id(10),'wk-rule-type','Rule school type');
update atlas_admin.schools set school_type_id=pg_temp.id(10) where school_id=pg_temp.id(6);
insert into atlas_admin.dishes(dish_id,dish_code,dish_name,dish_type_id,dish_status,requires_need_generation)
select pg_temp.id(11),'wk-rule-dish','Rule dish',dish_type_id,'ACTIVE',false
from atlas_admin.dish_types where dish_type_code='soup';
create temporary table prior_menus as
with rows as (
  select w::date week_start,pg_temp.id(6) school_id,w::date+d service_date,'soup' menu_slot_code,
    pg_temp.id(11) dish_id,'fixture:'||d source_row_reference
  from (values(date '2050-10-10'),(date '2050-10-17')) weeks(w) cross join (values(1),(3)) days(d)
), payloads as (
  select week_start,atlas_core.rmvp_03a_canonical_menu_rows(jsonb_agg(to_jsonb(rows)-'week_start')) items
  from rows group by week_start
)
select week_start,pg_temp.rule_command(week_start,1,null,true) || jsonb_build_object(
  'contract_version','RMVP-03A.v2','reason_code','WEEKLY_MENU_SAVED',
  'payload',jsonb_build_object('week_start',week_start,'source_type','GOOGLE_SHEET','source_name','Rule test',
    'source_signature',atlas_core.rmvp_03a_menu_signature(items),'expected_source_signature',null,'rows',items)) request
from payloads;
grant select on prior_menus to authenticated;
create function pg_temp.onion_command(v int, rate text, enabled boolean)
returns jsonb language sql volatile as $$
  select jsonb_set(pg_temp.rule_command('2050-10-10',v,rate,enabled),'{payload,ingredient_id}',to_jsonb(pg_temp.id(9)));
$$;
create temporary table rule_steps(step text primary key,response jsonb);
grant select,insert on rule_steps to authenticated;
set local role authenticated;
insert into rule_steps values('before-menu',pg_temp.onion_command(0,'0.4',true));
insert into rule_steps select 'menu-'||week_start,atlas_api.save_weekly_menu(request) from prior_menus order by week_start;
select is((select count(*) from rule_steps where step like 'menu-%' and response->>'success'='true'),2::bigint,
  'both menus are saved before creating this Ingredient rule');
select diag(response::text) from rule_steps where step like 'menu-%' and response->>'success' is distinct from 'true';
select is((select atlas_api.save_weekly_pantry_rule(response)->>'error_code' from rule_steps where step='before-menu'),
  'STALE_VERSION','newly saved menu invalidates an earlier rule preview in a fresh command');
select is((pg_temp.read_rules('2050-10-10')#>>'{preview,total_quantity}')::numeric,0.8::numeric,
  'draft rate preview uses two distinct menu days without Attendance');
insert into rule_steps values('create',atlas_api.save_weekly_pantry_rule(pg_temp.onion_command(0,'0.4',true)));
select is((select response->'affected_weeks' from rule_steps where step='create'),
  '["2050-10-10","2050-10-17"]'::jsonb,'rule creation reconciles both weeks with existing menus');
select diag(response::text) from rule_steps where step='create' and response->>'success' is distinct from 'true';
reset role;
create temporary view current_onions as
select b.week_start,l.service_date,l.requested_quantity,l.weekly_rule_revision_id,l.counted_menu_days
from atlas_planning.pantry_need_batches b join atlas_planning.pantry_need_approval_snapshot_lines l
  on l.pantry_need_approval_snapshot_id=b.latest_approval_snapshot_id
where l.school_id=pg_temp.id(6) and l.ingredient_id=pg_temp.id(9) and l.purpose_code_snapshot='auto_weekly_pantry';
select is((select count(*) from current_onions where requested_quantity=0.8 and service_date=week_start+1
  and counted_menu_days=array[week_start+1,week_start+3]),2::bigint,'approved Pantry receives exact first-day quantities with menu-day evidence');
set local role authenticated;
insert into rule_steps values('change',atlas_api.save_weekly_pantry_rule(pg_temp.onion_command(1,'0.6',true)));
reset role;
select is((select count(*) from current_onions where requested_quantity=1.2),2::bigint,'changed rate updates both current approved snapshots');
select is((select count(*) from atlas_planning.pantry_need_approval_snapshot_lines l
  where l.weekly_rule_revision_id=(select (response->>'rule_revision_id')::uuid from rule_steps where step='create')
  and l.requested_quantity=0.8),2::bigint,'both earlier approved quantities survive the replacement');
set local role authenticated;
insert into rule_steps values('stop',atlas_api.save_weekly_pantry_rule(pg_temp.onion_command(2,null,false)));
select is((select response->>'success' from rule_steps where step='stop'),'true','stop succeeds with existing approved menus');
reset role;
select is((select count(*) from current_onions),0::bigint,'stopping removes automatic demand from both current snapshots');
set local role authenticated;
insert into rule_steps values('resume',atlas_api.save_weekly_pantry_rule(pg_temp.onion_command(3,'0.5',true)));
reset role;
select is((select count(*) from current_onions where requested_quantity=1),2::bigint,'resuming restores each weekly contribution exactly once');
create temporary table reopen_week as
select pg_temp.rule_command(b.week_start,b.version::int,null,true) || jsonb_build_object('reason_note','Review draft edits',
  'payload',jsonb_build_object('week_start',b.week_start,'expected_source_signature',b.source_signature)) request
from atlas_planning.pantry_need_batches b where b.week_start='2050-10-17';
grant select on reopen_week to authenticated;
set local role authenticated;
insert into rule_steps select 'reopen',atlas_api.reopen_pantry(request) from reopen_week;
select is((select response->>'success' from rule_steps where step='reopen'),'true','operator reopens the second week for editing');
insert into rule_steps values('blocked',atlas_api.save_weekly_pantry_rule(pg_temp.onion_command(4,'0.7',true)));
select is((select response->>'error_code' from rule_steps where step='blocked'),'PANTRY_DRAFT_IN_PROGRESS',
  'the second week blocks a rate change while its draft is open');
reset role;
select is((select count(*) from atlas_planning.weekly_pantry_rule_revisions where ingredient_id=pg_temp.id(9)),4::bigint,
  'blocked multi-week command rolls back its appended revision');
select is((select count(*) from current_onions where requested_quantity=1),2::bigint,
  'blocked second week rolls back first-week regeneration and preserves both approved quantities');
select is((select count(*) from atlas_planning.pantry_need_approval_snapshot_lines where ingredient_id=pg_temp.id(9)
  and requested_quantity=1.4),0::bigint,'failed refresh leaves no partial intermediate snapshot');
select * from finish();
rollback;
