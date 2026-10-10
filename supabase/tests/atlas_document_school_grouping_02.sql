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
select ok(exists(select 1 from information_schema.columns where table_schema='atlas_admin' and table_name='cooking_groups' and column_name='location_kind'),'location kind is explicit schema authority');
select ok(to_regclass('atlas_admin.dispatch_groups') is not null,'Dispatch group authority exists independently');
set local role authenticated;
select set_config('request.jwt.claim.sub','d1000000-0000-0000-0000-000000000101',true);
select is((atlas_api.upsert_cooking_group(pg_temp.cg_request(jsonb_build_object('cooking_group_id',null,'cooking_group_name','Unspecified','active',true),1,'COOKING_GROUP_SAVED','untyped'))->>'error_code'),'VALIDATION_FAILED','new cooking location requires explicit kind and host');
insert into cg_results values('typed',atlas_api.upsert_cooking_group(pg_temp.cg_request(jsonb_build_object('cooking_group_id',null,'cooking_group_name','Công ty Thượng Hảo','active',true,'location_kind','COMPANY','host_school_id',null),1,'COOKING_GROUP_SAVED','typed')));
select is((select response->>'success' from cg_results where name='typed'),'true','typed Company kitchen is authored');
select is((atlas_api.get_cooking_groups(pg_temp.cg_read())#>>'{cooking_groups,0,location_kind}'),'COMPANY','read retains typed location kind');
select is((atlas_api.upsert_cooking_group(pg_temp.cg_request(jsonb_build_object('cooking_group_id',null,'cooking_group_name','Bad company','active',true,'location_kind','COMPANY','host_school_id','d2000000-0000-0000-0000-000000000004'),1,'COOKING_GROUP_SAVED','bad-company'))->>'error_code'),'VALIDATION_FAILED','Company cannot invent a School host');
select is((atlas_api.upsert_cooking_group(pg_temp.cg_request(jsonb_build_object('cooking_group_id',null,'cooking_group_name','Missing host','active',true,'location_kind','SCHOOL','host_school_id',null),1,'COOKING_GROUP_SAVED','missing-host'))->>'error_code'),'VALIDATION_FAILED','School location requires an explicit School identity');
insert into cg_results values('cooking-assign',atlas_api.set_school_cooking_group(pg_temp.cg_request(jsonb_build_object('school_id','d2000000-0000-0000-0000-000000000004','cooking_group_id',(select response#>>'{affected_aggregate_ids,cooking_group_id}' from cg_results where name='typed')),1,'SCHOOL_COOKING_GROUP_SET','cooking-assign')));
insert into cg_results values('dispatch',atlas_api.upsert_dispatch_group(pg_temp.cg_request(jsonb_build_object('dispatch_group_id',null,'dispatch_group_name','Route A','active',true),1,'DISPATCH_GROUP_SAVED','dispatch')));
select is((select response->>'success' from cg_results where name='dispatch'),'true','Dispatch authoring is independent');
select is(atlas_api.upsert_dispatch_group(pg_temp.cg_request(jsonb_build_object('dispatch_group_id',null,'dispatch_group_name','Route A','active',true),1,'DISPATCH_GROUP_SAVED','dispatch')),(select response from cg_results where name='dispatch'),'Dispatch exact replay returns receipt');
select is((atlas_api.upsert_dispatch_group(pg_temp.cg_request(jsonb_build_object('dispatch_group_id',null,'dispatch_group_name','Changed','active',true),1,'DISPATCH_GROUP_SAVED','dispatch'))->>'error_code'),'IDEMPOTENCY_CONFLICT','Dispatch conflicting replay is denied');
insert into cg_results values('dispatch-assign',atlas_api.set_school_dispatch_group(pg_temp.cg_request(jsonb_build_object('school_id','d2000000-0000-0000-0000-000000000004','dispatch_group_id',(select response#>>'{affected_aggregate_ids,dispatch_group_id}' from cg_results where name='dispatch')),2,'SCHOOL_DISPATCH_GROUP_SET','dispatch-assign')));
select is((select response->>'success' from cg_results where name='dispatch-assign'),'true','School can author Dispatch independently of cooking');
select is(atlas_api.set_school_dispatch_group(pg_temp.cg_request(jsonb_build_object('school_id','d2000000-0000-0000-0000-000000000004','dispatch_group_id',(select response#>>'{affected_aggregate_ids,dispatch_group_id}' from cg_results where name='dispatch')),2,'SCHOOL_DISPATCH_GROUP_SET','dispatch-assign')),(select response from cg_results where name='dispatch-assign'),'exact Dispatch assignment replay cannot increment School version');
select is((atlas_api.get_school_master_data(pg_temp.cg_read())#>>'{schools,0,version}'),'3','assignment replay keeps exact School version');
select is((atlas_api.get_school_master_data(pg_temp.cg_read())#>>'{schools,0,cooking_location_kind}'),'COMPANY','Dispatch save preserves canonical cooking facts');
select is((atlas_api.get_school_master_data(pg_temp.cg_read())#>>'{schools,0,dispatch_group_name}'),'Route A','School shaped read retains separate Dispatch identity');
select is((atlas_api.set_school_dispatch_group(pg_temp.cg_request(jsonb_build_object('school_id','d2000000-0000-0000-0000-000000000004','dispatch_group_id',null),2,'SCHOOL_DISPATCH_GROUP_SET','stale-dispatch'))->>'error_code'),'STALE_VERSION','stale Dispatch clear cannot overwrite School');
select is((atlas_api.upsert_dispatch_group(pg_temp.cg_request(jsonb_build_object('dispatch_group_id',(select response#>>'{affected_aggregate_ids,dispatch_group_id}' from cg_results where name='dispatch'),'dispatch_group_name','Route A','active',false),1,'DISPATCH_GROUP_SAVED','deactivate-dispatch'))->>'error_code'),'DISPATCH_GROUP_HAS_MEMBERS','Dispatch deactivation cannot strand Schools');
select is((atlas_api.set_school_dispatch_group(pg_temp.cg_request(jsonb_build_object('school_id','d2000000-0000-0000-0000-000000000004','dispatch_group_id',null),3,'SCHOOL_DISPATCH_GROUP_SET','clear-dispatch'))->>'success'),'true','explicit Dispatch null clears only Dispatch');
select is((atlas_api.get_school_master_data(pg_temp.cg_read())#>>'{schools,0,cooking_location_name}'),'Công ty Thượng Hảo','Dispatch clear preserves cooking');
select is((atlas_api.get_school_master_data(pg_temp.cg_read())#>'{schools,0,dispatch_group_id}'),'null'::jsonb,'Dispatch removal reads null');
select set_config('request.jwt.claim.sub','d1000000-0000-0000-0000-000000000102',true);
select is((atlas_api.get_dispatch_groups(jsonb_set(pg_temp.cg_read(),'{requested_by_auth_subject}',to_jsonb('d1000000-0000-0000-0000-000000000102'::text)))->>'error_code'),'CAPABILITY_DENIED','Dispatch reads deny missing capability');
select is((atlas_api.upsert_dispatch_group(jsonb_set(pg_temp.cg_request(jsonb_build_object('dispatch_group_id',null,'dispatch_group_name','Denied','active',true),1,'DISPATCH_GROUP_SAVED','denied-dispatch'),'{requested_by_auth_subject}',to_jsonb('d1000000-0000-0000-0000-000000000102'::text)))->>'error_code'),'CAPABILITY_DENIED','Dispatch commands deny missing capability');
reset role;
select ok((select count(*)=2 and bool_and(relrowsecurity and relforcerowsecurity) from pg_class where oid in('atlas_admin.dispatch_groups'::regclass,'atlas_admin.dispatch_group_members'::regclass)),'Dispatch tables force RLS');
select ok(not exists(select 1 from unnest(array['anon','authenticated','service_role']) role_name cross join unnest(array['atlas_admin.dispatch_groups','atlas_admin.dispatch_group_members']) relation_name where has_table_privilege(role_name,relation_name,'SELECT,INSERT,UPDATE,DELETE')),'API roles have no direct Dispatch table access');
select throws_ok($$insert into atlas_admin.cooking_groups(cooking_group_name,location_kind,host_school_id) values('untyped host',null,'d2000000-0000-0000-0000-000000000004')$$,'23514',null,'relational constraint rejects host without kind');
insert into atlas_admin.cooking_groups(cooking_group_id,cooking_group_name) values('df000000-0000-0000-0000-000000000001','Unresolved legacy location');
set local role authenticated;
select set_config('request.jwt.claim.sub','d1000000-0000-0000-0000-000000000101',true);
select is((atlas_api.set_school_cooking_group(pg_temp.cg_request(jsonb_build_object('school_id','d2000000-0000-0000-0000-000000000004','cooking_group_id','df000000-0000-0000-0000-000000000001'),4,'SCHOOL_COOKING_GROUP_SET','unresolved-assign'))->>'error_code'),'COOKING_LOCATION_RECONCILIATION_REQUIRED','new assignment cannot invent unresolved legacy semantics');
select is((atlas_api.upsert_cooking_group(pg_temp.cg_request(jsonb_build_object('cooking_group_id',(select response#>>'{affected_aggregate_ids,cooking_group_id}' from cg_results where name='typed'),'cooking_group_name','Công ty Thượng Hảo','active',true),1,'COOKING_GROUP_SAVED','legacy-update'))->>'success'),'true','legacy update envelope remains callable without changing typed facts');
select is((atlas_api.get_school_master_data(pg_temp.cg_read())#>>'{schools,0,cooking_location_kind}'),'COMPANY','legacy update retains explicit location kind');
select is((atlas_api.get_school_master_data(pg_temp.cg_read())#>'{schools,0,cooking_location_host_school_id}'),'null'::jsonb,'legacy update never fabricates School host');
select is((atlas_api.upsert_cooking_group(pg_temp.cg_request(jsonb_build_object('cooking_group_id',(select response#>>'{affected_aggregate_ids,cooking_group_id}' from cg_results where name='typed'),'cooking_group_name','Renamed company','active',true),2,'COOKING_GROUP_SAVED','legacy-company-rename'))->>'error_code'),'VALIDATION_FAILED','legacy update cannot rename an explicit Company location');
reset role;
set local role authenticated;
select is((atlas_api.upsert_cooking_group(pg_temp.cg_request(jsonb_build_object('cooking_group_id',null,'cooking_group_name','Host kitchen','active',true,'location_kind','SCHOOL','host_school_id','d2000000-0000-0000-0000-000000000004'),1,'COOKING_GROUP_SAVED','host-kitchen'))->>'success'),'true','explicit School location accepts its reconciled host identity');
select is((atlas_api.upsert_cooking_group(pg_temp.cg_request(jsonb_build_object('cooking_group_id',null,'cooking_group_name','Unknown host','active',true,'location_kind','SCHOOL','host_school_id','df000000-0000-0000-0000-000000000099'),1,'COOKING_GROUP_SAVED','unknown-host'))->>'error_code'),'NOT_FOUND','nonexistent host identity cannot be authored');
reset role;
delete from atlas_core.actor_scopes where actor_id='d1000000-0000-0000-0000-000000000001';
insert into atlas_core.actor_scopes(actor_id,scope_kind,school_id) values('d1000000-0000-0000-0000-000000000001','SCHOOL','d2000000-0000-0000-0000-000000000004');
set local role authenticated;
select is((atlas_api.get_dispatch_groups(pg_temp.cg_read())->>'error_code'),'SCOPE_DENIED','School-only scope cannot read GLOBAL Dispatch authority');
select is((atlas_api.set_school_dispatch_group(pg_temp.cg_request(jsonb_build_object('school_id','d2000000-0000-0000-0000-000000000004','dispatch_group_id',null),4,'SCHOOL_DISPATCH_GROUP_SET','scope-dispatch'))->>'error_code'),'SCOPE_DENIED','School-only scope cannot write GLOBAL Dispatch authority');
reset role;
select is((select count(*)::integer from atlas_audit.audit_events where event_type in('DispatchGroupSaved','SchoolDispatchGroupSet')),3,'Dispatch records only successful command audit evidence; replay/failures add none');
insert into atlas_admin.schools(school_id,customer_id,school_code,school_name,default_delivery_location_id) select 'd2000000-0000-0000-0000-000000000005',customer_id,'dispatch-school-b','Distinct Dispatch School B',default_delivery_location_id from atlas_admin.schools where school_id='d2000000-0000-0000-0000-000000000004';
insert into atlas_admin.dispatch_group_members(school_id,dispatch_group_id) select school_id,(select (response#>>'{affected_aggregate_ids,dispatch_group_id}')::uuid from cg_results where name='dispatch') from atlas_admin.schools;
select is((select count(*)::integer from atlas_admin.dispatch_group_members),2,'two distinct Schools can explicitly share one Dispatch group');
select throws_ok($$insert into atlas_admin.dispatch_group_members select * from atlas_admin.dispatch_group_members limit 1$$,'23505',null,'School PK prevents two current Dispatch memberships');
select throws_ok($$update atlas_admin.dispatch_groups set active=false$$,'23514','Clear or move Dispatch memberships before deactivation.','relational guard prevents stranding Dispatch members');
select throws_ok($$update atlas_admin.schools set school_status='INACTIVE' where school_id='d2000000-0000-0000-0000-000000000005'$$,'23514','Clear Dispatch membership before School deactivation.','School deactivation independently respects Dispatch membership');
set local role authenticated;
select set_config('request.jwt.claim.sub','d1000000-0000-0000-0000-000000000101',true);
select is((atlas_api.upsert_cooking_group(pg_temp.cg_request(jsonb_build_object('cooking_group_id',null,'cooking_group_name','Company kitchen','active',true,'location_kind','COMPANY','host_school_id',null),1,'COOKING_GROUP_SAVED','company-name-invalid'))->>'error_code'),'VALIDATION_FAILED','Company location requires canonical display name');
reset role;
select throws_ok($$insert into atlas_admin.cooking_groups(cooking_group_name,location_kind) values('Wrong company','COMPANY')$$,'23514',null,'relational guard preserves canonical Company name');
select * from finish();
rollback;
