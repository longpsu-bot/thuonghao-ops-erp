begin;
create extension if not exists pgtap with schema extensions;
set search_path=extensions,public,pg_catalog;
select no_plan();
grant usage on schema extensions to authenticated;
grant execute on all functions in schema extensions to authenticated;
insert into atlas_core.actors (
  actor_id, actor_type, display_name
) values
  (
    'd1000000-0000-0000-0000-000000000001',
    'HUMAN',
    'RMVP-01 authorized operator'
  ),
  (
    'd1000000-0000-0000-0000-000000000002',
    'HUMAN',
    'RMVP-01 denied operator'
  );

insert into atlas_core.actor_auth_subjects (
  actor_auth_subject_id, actor_id, auth_subject_id
) values
  (
    'd1000000-0000-0000-0000-000000000011',
    'd1000000-0000-0000-0000-000000000001',
    'd1000000-0000-0000-0000-000000000101'
  ),
  (
    'd1000000-0000-0000-0000-000000000012',
    'd1000000-0000-0000-0000-000000000002',
    'd1000000-0000-0000-0000-000000000102'
  );

insert into atlas_core.roles (
  role_id, role_code, role_name
) values
  (
    'd1000000-0000-0000-0000-000000000020',
    'rmvp01.master_data_operator',
    'RMVP-01 master data operator'
  ),
  (
    'd1000000-0000-0000-0000-000000000021',
    'rmvp01.no_capability',
    'RMVP-01 no capability'
  );

insert into atlas_core.role_capabilities (role_id, capability_id)
select
  'd1000000-0000-0000-0000-000000000020',
  capability_id
from atlas_core.capabilities
where capability_code like 'master_data.%';

insert into atlas_core.actor_role_memberships (actor_id, role_id) values
  (
    'd1000000-0000-0000-0000-000000000001',
    'd1000000-0000-0000-0000-000000000020'
  ),
  (
    'd1000000-0000-0000-0000-000000000002',
    'd1000000-0000-0000-0000-000000000021'
  );

insert into atlas_core.actor_scopes (actor_id, scope_kind) values
  ('d1000000-0000-0000-0000-000000000001', 'GLOBAL'),
  ('d1000000-0000-0000-0000-000000000002', 'GLOBAL');

insert into atlas_admin.customers (
  customer_id, customer_code, customer_name, customer_type
) values (
  'd2000000-0000-0000-0000-000000000001',
  'rmvp01-school-customer',
  'RMVP-01 School Customer',
  'SCHOOL_CATERING'
);
insert into atlas_admin.delivery_locations (
  delivery_location_id, customer_id, location_code, location_name,
  address_text, delivery_instructions
) values (
  'd2000000-0000-0000-0000-000000000002',
  'd2000000-0000-0000-0000-000000000001',
  'rmvp01-main-gate',
  'RMVP-01 Main Gate',
  'RMVP-01 address',
  'Before 05:30'
);
insert into atlas_admin.school_types (
  school_type_id, school_type_code, school_type_name
) values (
  'd2000000-0000-0000-0000-000000000003',
  'rmvp01-primary',
  'Primary'
);
insert into atlas_admin.schools (
  school_id, customer_id, school_code, school_name, school_type_id,
  default_delivery_location_id, display_order, operational_notes,
  default_student_portions, default_teacher_portions
) values (
  'd2000000-0000-0000-0000-000000000004',
  'd2000000-0000-0000-0000-000000000001',
  'rmvp01-school',
  'RMVP-01 School',
  'd2000000-0000-0000-0000-000000000003',
  'd2000000-0000-0000-0000-000000000002',
  1,
  'Supported contract context',
  100,
  10
);
create function pg_temp.cg_request(p_payload jsonb,p_version bigint,p_reason text,p_key text)
returns jsonb language sql as $$
  select jsonb_build_object('contract_version','RMVP-01.v1',
    'command_id',md5(p_key)::uuid,'correlation_id','d9000000-0000-0000-0000-000000000001',
    'idempotency_key',p_key,'expected_version',p_version,
    'requested_by_auth_subject','d1000000-0000-0000-0000-000000000101',
    'requested_at',transaction_timestamp()-interval '1 second',
    'reason_code',p_reason,'reason_note',null,'payload',p_payload);
$$;
create function pg_temp.cg_read() returns jsonb language sql as $$
  select jsonb_build_object('contract_version','RMVP-01.v1',
    'correlation_id','d9000000-0000-0000-0000-000000000001',
    'requested_by_auth_subject','d1000000-0000-0000-0000-000000000101','payload','{}'::jsonb);
$$;
create temporary table cg_results(name text primary key,response jsonb);
grant select,insert on cg_results to authenticated;
select ok((select count(*)=2 and bool_and(relrowsecurity and relforcerowsecurity)
  from pg_class where oid in('atlas_admin.cooking_groups'::regclass,
    'atlas_admin.school_cooking_group_memberships'::regclass)), 'both current fact tables force RLS');
select ok(not exists(select 1 from unnest(array['anon','authenticated','service_role']) role_name
  cross join unnest(array['atlas_admin.cooking_groups','atlas_admin.school_cooking_group_memberships']) relation_name
  where has_table_privilege(role_name,relation_name,'SELECT,INSERT,UPDATE,DELETE')),
  'browser and service roles have no cooking table privileges');
select ok((select count(*)=3 and bool_and(prosecdef and proconfig=array['search_path=""']::text[])
  from pg_proc where oid in('atlas_api.get_cooking_groups(jsonb)'::regprocedure,
    'atlas_api.upsert_cooking_group(jsonb)'::regprocedure,'atlas_api.set_school_cooking_group(jsonb)'::regprocedure)),
  'only three shaped APIs with fixed empty search paths');
select function_owner_is('atlas_api','upsert_cooking_group',array['jsonb'],'atlas_master_data_command_runtime');
select function_owner_is('atlas_api','set_school_cooking_group',array['jsonb'],'atlas_master_data_command_runtime');
select function_owner_is('atlas_api','get_cooking_groups',array['jsonb'],'atlas_read_runtime');
set local role authenticated;
select set_config('request.jwt.claim.sub','d1000000-0000-0000-0000-000000000101',true);
insert into cg_results values('create',atlas_api.upsert_cooking_group(pg_temp.cg_request(
  jsonb_build_object('cooking_group_id',null,'cooking_group_name','Group X','active',true),1,'COOKING_GROUP_SAVED','create')));
insert into cg_results values('replay',atlas_api.upsert_cooking_group(pg_temp.cg_request(
  jsonb_build_object('cooking_group_id',null,'cooking_group_name','Group X','active',true),1,'COOKING_GROUP_SAVED','create')));
select is((select response->>'success' from cg_results where name='create'),'true','group create succeeds');
select is((select response from cg_results where name='replay'),(select response from cg_results where name='create'),
  'exact group replay returns original immutable receipt');
select is((atlas_api.upsert_cooking_group(pg_temp.cg_request(
  jsonb_build_object('cooking_group_id',null,'cooking_group_name','Conflicting','active',true),1,'COOKING_GROUP_SAVED','create'))->>'error_code'),
  'IDEMPOTENCY_CONFLICT','conflicting group replay rejects');
select is((atlas_api.upsert_cooking_group(pg_temp.cg_request(
  jsonb_build_object('cooking_group_id',null,'cooking_group_name',repeat('x',201),'active',true),1,'COOKING_GROUP_SAVED','too-long'))->>'error_code'),
  'VALIDATION_FAILED','group name length over 200 rejects');
select is((atlas_api.upsert_cooking_group(pg_temp.cg_request(
  jsonb_build_object('cooking_group_id',null,'cooking_group_name','Group Bad','active',null),1,'COOKING_GROUP_SAVED','null-active'))->>'error_code'),
  'VALIDATION_FAILED','null active field rejects');
insert into cg_results values('assign',atlas_api.set_school_cooking_group(pg_temp.cg_request(
  jsonb_build_object('school_id','d2000000-0000-0000-0000-000000000004',
    'cooking_group_id',(select response#>>'{affected_aggregate_ids,cooking_group_id}' from cg_results where name='create')),
    1,'SCHOOL_COOKING_GROUP_SET','assign')));
select is((select response->>'success' from cg_results where name='assign'),'true','assignment succeeds');
select is(atlas_api.set_school_cooking_group(pg_temp.cg_request(
  jsonb_build_object('school_id','d2000000-0000-0000-0000-000000000004',
    'cooking_group_id',(select response#>>'{affected_aggregate_ids,cooking_group_id}' from cg_results where name='create')),
    1,'SCHOOL_COOKING_GROUP_SET','assign')),(select response from cg_results where name='assign'),
  'assignment replay does not increment School version');
select is((atlas_api.get_school_master_data(pg_temp.cg_read())#>>'{schools,0,cooking_group_name}'),
  'Group X','School shaped read includes explicit current group');
select is((atlas_api.get_cooking_groups(pg_temp.cg_read())#>>'{cooking_groups,0,cooking_group_name}'),
  'Group X','group shaped read includes governed identity');
insert into cg_results values('stale',atlas_api.set_school_cooking_group(pg_temp.cg_request(
  jsonb_build_object('school_id','d2000000-0000-0000-0000-000000000004','cooking_group_id',null),
    1,'SCHOOL_COOKING_GROUP_SET','stale')));
select is((select response->>'error_code' from cg_results where name='stale'),'STALE_VERSION','stale assignment cannot overwrite');
insert into cg_results values('deactivate-blocked',atlas_api.upsert_cooking_group(pg_temp.cg_request(
  jsonb_build_object('cooking_group_id',(select response#>>'{affected_aggregate_ids,cooking_group_id}' from cg_results where name='create'),
    'cooking_group_name','Group X','active',false),1,'COOKING_GROUP_SAVED','deactivate-blocked')));
select is((select response->>'error_code' from cg_results where name='deactivate-blocked'),
  'COOKING_GROUP_HAS_MEMBERS','deactivation cannot strand assigned Schools');
select is((atlas_api.set_school_cooking_group(pg_temp.cg_request(
  jsonb_build_object('school_id','d2000000-0000-0000-0000-000000000004','cooking_group_id','ffffffff-0000-0000-0000-000000000000'),
    2,'SCHOOL_COOKING_GROUP_SET','missing'))->>'error_code'),'NOT_FOUND','missing group rejects');
select is((atlas_api.set_school_cooking_group(pg_temp.cg_request(
  jsonb_build_object('school_id','d2000000-0000-0000-0000-000000000004'),
    2,'SCHOOL_COOKING_GROUP_SET','omitted'))->>'error_code'),'VALIDATION_FAILED','removal requires explicit null');
insert into cg_results values('clear',atlas_api.set_school_cooking_group(pg_temp.cg_request(
  jsonb_build_object('school_id','d2000000-0000-0000-0000-000000000004','cooking_group_id',null),
    2,'SCHOOL_COOKING_GROUP_SET','clear')));
select is((select response->>'success' from cg_results where name='clear'),'true','explicit null clears membership');
select is((atlas_api.get_school_master_data(pg_temp.cg_read())#>'{schools,0,cooking_group_id}'),'null'::jsonb,
  'ungrouped School read returns null');
insert into cg_results values('deactivate',atlas_api.upsert_cooking_group(pg_temp.cg_request(
  jsonb_build_object('cooking_group_id',(select response#>>'{affected_aggregate_ids,cooking_group_id}' from cg_results where name='create'),
    'cooking_group_name','Group X','active',false),1,'COOKING_GROUP_SAVED','deactivate')));
select is((select response->>'success' from cg_results where name='deactivate'),'true','empty group can deactivate');
select is((atlas_api.set_school_cooking_group(pg_temp.cg_request(
  jsonb_build_object('school_id','d2000000-0000-0000-0000-000000000004',
    'cooking_group_id',(select response#>>'{affected_aggregate_ids,cooking_group_id}' from cg_results where name='create')),
    3,'SCHOOL_COOKING_GROUP_SET','inactive'))->>'error_code'),'COOKING_GROUP_INACTIVE','inactive group rejects');
reset role;
select is((select count(*)::integer from atlas_audit.audit_events where event_type in('CookingGroupSaved','SchoolCookingGroupSet')),
  4,'exactly successful mutations emit audit evidence; replay and failures do not');
update atlas_admin.cooking_groups set active=true;
insert into atlas_admin.school_cooking_group_memberships(school_id,cooking_group_id)
  select 'd2000000-0000-0000-0000-000000000004',cooking_group_id from atlas_admin.cooking_groups;
insert into atlas_admin.schools(school_id,customer_id,school_code,school_name,default_delivery_location_id)
  select 'd2000000-0000-0000-0000-000000000005',customer_id,'cg-school-b','Cooking School B',default_delivery_location_id
  from atlas_admin.schools where school_id='d2000000-0000-0000-0000-000000000004';
insert into atlas_admin.school_cooking_group_memberships(school_id,cooking_group_id)
  select 'd2000000-0000-0000-0000-000000000005',cooking_group_id from atlas_admin.cooking_groups;
select is((select count(*)::integer from atlas_admin.school_cooking_group_memberships),2,
  'two distinct Schools can share one authoritative group');
select throws_ok($$update atlas_admin.cooking_groups set active=false$$,'23514',
  'Clear or move cooking memberships before deactivation.','relational guard blocks deactivation with current members');
select throws_ok($$update atlas_admin.schools set school_status='INACTIVE'
  where school_id='d2000000-0000-0000-0000-000000000004'$$,'23514',
  'Clear cooking membership before School deactivation.','relational guard blocks inactive current School membership');
select throws_ok($$insert into atlas_admin.school_cooking_group_memberships(school_id,cooking_group_id)
  select 'd2000000-0000-0000-0000-000000000004',cooking_group_id from atlas_admin.cooking_groups$$,
  '23505',null,'School PK prevents two current memberships');
delete from atlas_admin.school_cooking_group_memberships;
update atlas_admin.schools set school_status='INACTIVE' where school_id='d2000000-0000-0000-0000-000000000004';
set local role authenticated;
select is((atlas_api.set_school_cooking_group(pg_temp.cg_request(
  jsonb_build_object('school_id','d2000000-0000-0000-0000-000000000004',
    'cooking_group_id',(select response#>>'{affected_aggregate_ids,cooking_group_id}' from cg_results where name='create')),
    3,'SCHOOL_COOKING_GROUP_SET','inactive-school'))->>'error_code'),'SCHOOL_INACTIVE','inactive School rejects');
select set_config('request.jwt.claim.sub','d1000000-0000-0000-0000-000000000102',true);
select is((atlas_api.get_cooking_groups(jsonb_set(pg_temp.cg_read(),'{requested_by_auth_subject}',
  to_jsonb('d1000000-0000-0000-0000-000000000102'::text)))->>'error_code'),
  'CAPABILITY_DENIED','GLOBAL actor without read capability is denied');
select is((atlas_api.upsert_cooking_group(jsonb_set(pg_temp.cg_request(
  jsonb_build_object('cooking_group_id',null,'cooking_group_name','Denied','active',true),1,'COOKING_GROUP_SAVED','denied'),
  '{requested_by_auth_subject}',to_jsonb('d1000000-0000-0000-0000-000000000102'::text)))->>'error_code'),
  'CAPABILITY_DENIED','GLOBAL actor without write capability is denied');
reset role;
delete from atlas_core.actor_scopes where actor_id='d1000000-0000-0000-0000-000000000001';
insert into atlas_core.actor_scopes(actor_id,scope_kind,school_id)
  values('d1000000-0000-0000-0000-000000000001','SCHOOL','d2000000-0000-0000-0000-000000000004');
set local role authenticated;
select set_config('request.jwt.claim.sub','d1000000-0000-0000-0000-000000000101',true);
select is((atlas_api.get_cooking_groups(pg_temp.cg_read())->>'error_code'),
  'SCOPE_DENIED','School-only scope cannot read GLOBAL Admin groups');
select is((atlas_api.set_school_cooking_group(pg_temp.cg_request(
  jsonb_build_object('school_id','d2000000-0000-0000-0000-000000000004','cooking_group_id',null),
    3,'SCHOOL_COOKING_GROUP_SET','scope-denied'))->>'error_code'),
  'SCOPE_DENIED','School-only scope cannot maintain GLOBAL Admin facts');
reset role;
select * from finish();
rollback;
