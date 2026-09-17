-- Local/CI only: realistic assignment volume, exact RPC, no committed data.
begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set local search_path = pg_catalog, public, extensions;
select plan(10);

insert into atlas_core.actors(actor_id, actor_type, display_name)
values ('a7300000-0000-4000-8000-000000000001','HUMAN','Menu scale test');
insert into atlas_core.actor_auth_subjects(actor_auth_subject_id,actor_id,auth_subject_id)
values ('a7300000-0000-4000-8000-000000000002','a7300000-0000-4000-8000-000000000001','a7300000-0000-4000-8000-000000000003');
insert into atlas_core.roles(role_id,role_code,role_name)
values ('a7300000-0000-4000-8000-000000000004','menu-scale-test','Menu scale test');
insert into atlas_core.role_capabilities(role_id,capability_id)
select 'a7300000-0000-4000-8000-000000000004',capability_id
from atlas_core.capabilities where capability_code like 'planning.%';
insert into atlas_core.actor_role_memberships(actor_id,role_id)
values ('a7300000-0000-4000-8000-000000000001','a7300000-0000-4000-8000-000000000004');
insert into atlas_core.actor_scopes(actor_id,scope_kind)
values ('a7300000-0000-4000-8000-000000000001','GLOBAL');
insert into atlas_admin.customers(customer_id,customer_code,customer_name,customer_type)
values ('a7300000-0000-4000-8000-000000000010','menu-scale-customer','Menu scale customer','SCHOOL_CATERING');
insert into atlas_admin.delivery_locations(delivery_location_id,customer_id,location_code,location_name,address_text,timezone_name)
values ('a7300000-0000-4000-8000-000000000011','a7300000-0000-4000-8000-000000000010','menu-scale-location','Menu scale location','Local test only','Asia/Ho_Chi_Minh');
insert into atlas_admin.school_types(school_type_id,school_type_code,school_type_name)
values ('a7300000-0000-4000-8000-000000000012','menu-scale-type','Menu scale type');
insert into atlas_admin.schools(school_id,customer_id,school_code,school_name,school_type_id,default_delivery_location_id,display_order)
select md5('menu-scale-school-'||i)::uuid,'a7300000-0000-4000-8000-000000000010',
'menu-scale-school-'||i,'Menu scale school '||i,'a7300000-0000-4000-8000-000000000012',
'a7300000-0000-4000-8000-000000000011',i
from generate_series(1,20) i;
insert into atlas_admin.dishes(dish_id,dish_code,dish_name,dish_type_id,dish_status,requires_need_generation)
select md5('menu-scale-dish-'||dish_type_code)::uuid,'menu-scale-dish-'||dish_type_code,
'Menu scale '||dish_type_code,dish_type_id,'ACTIVE',false
from atlas_admin.dish_types where dish_type_status='ACTIVE'
and dish_type_code in ('soup','savory','stir_fry','dessert','afternoon_snack');

create temp table menu_scale_request(request jsonb);
with rows as (
  select s.school_id,date '2050-09-19'+g.i as service_date,t.dish_type_code as menu_slot_code,
    d.dish_id,'scale:'||s.school_code||':'||g.i||':'||t.dish_type_code as source_row_reference
  from atlas_admin.schools s cross join generate_series(0,4) g(i)
  cross join atlas_admin.dishes d join atlas_admin.dish_types t on t.dish_type_id=d.dish_type_id
  where s.school_code like 'menu-scale-school-%' and d.dish_code like 'menu-scale-dish-%'
  order by s.school_code,g.i,t.dish_type_code limit 471
), payload as (
  select atlas_core.rmvp_03a_canonical_menu_rows(jsonb_agg(to_jsonb(rows))) as rows from rows
)
insert into menu_scale_request
select jsonb_build_object('contract_version','RMVP-03A.v2',
'command_id','a7300000-0000-4000-8000-000000000020',
'correlation_id','a7300000-0000-4000-8000-000000000021',
'idempotency_key','menu-scale-471','expected_version',1,
'requested_by_auth_subject','a7300000-0000-4000-8000-000000000003',
'requested_at',clock_timestamp(),'reason_code','WEEKLY_MENU_SAVED','reason_note','Local scale test',
'payload',jsonb_build_object('week_start','2050-09-19','source_type','GOOGLE_SHEET',
'source_name','Local scale test','source_signature',atlas_core.rmvp_03a_menu_signature(rows),
'expected_source_signature',null,'rows',rows)) from payload;
create temp table menu_scale_result(response jsonb);
grant select on menu_scale_request to authenticated;
grant select,insert on menu_scale_result to authenticated;
select is((select jsonb_array_length(request#>'{payload,rows}') from menu_scale_request),471,'471 distinct assignments prepared');
select set_config('request.jwt.claims','{"sub":"a7300000-0000-4000-8000-000000000003","role":"authenticated"}',true);
set local role authenticated;
-- Match the hosted authenticated statement budget. Do not increase it to hide regression.
set local statement_timeout='8s';
select lives_ok($$insert into menu_scale_result select atlas_api.save_weekly_menu(request) from menu_scale_request$$,
  '471-assignment consequential Menu Save completes inside the hosted eight-second budget');
select is((select response->>'success' from menu_scale_result limit 1),'true','scale Save succeeds');
select is((select response#>>'{authoritative_readback,planning_inputs,weekly_menu,weekly_menu_status}' from menu_scale_result limit 1),
  'APPROVED','scale Save includes the completed approval readback');
select is((select (response#>>'{authoritative_readback,planning_inputs,weekly_menu,row_count}')::integer from menu_scale_result limit 1),
  471,'readback retains all 471 assignments');
select lives_ok($$insert into menu_scale_result select atlas_api.save_weekly_menu(request) from menu_scale_request$$,
  'an explicit identical idempotent replay is safe');
reset role;
select is((select count(*) from atlas_core.command_receipts where command_id='a7300000-0000-4000-8000-000000000020'),
  1::bigint,'replay creates no duplicate command receipt');
select is((select count(*) from atlas_planning.weekly_menu_approval_snapshots a join atlas_planning.weekly_menus m using(weekly_menu_id)
  where m.week_start='2050-09-19'),1::bigint,'replay creates no duplicate approval snapshot');
select is((select count(*) from atlas_planning.weekly_menu_approval_snapshot_lines a join atlas_planning.weekly_menus m using(weekly_menu_id)
  where m.week_start='2050-09-19'),471::bigint,'snapshot preserves every assignment exactly once');
select throws_ok($$update atlas_planning.weekly_menu_approval_snapshot_lines set source_row_reference='tampered'
  where weekly_menu_approval_snapshot_line_id=(select a.weekly_menu_approval_snapshot_line_id
  from atlas_planning.weekly_menu_approval_snapshot_lines a join atlas_planning.weekly_menus m using(weekly_menu_id)
  where m.week_start='2050-09-19' limit 1)$$,'23514',
  'weekly menu approval snapshots and snapshot lines are immutable','scale snapshots remain immutable');
select * from finish();
rollback;
