begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
select no_plan();

select ok(
  exists (
    select 1
    from pg_proc function_object
    join pg_namespace namespace_object
      on namespace_object.oid = function_object.pronamespace
    join pg_roles owner_role on owner_role.oid = function_object.proowner
    where namespace_object.nspname = 'atlas_api'
      and function_object.proname = 'update_school_portion_defaults_bulk'
      and pg_get_function_identity_arguments(function_object.oid) = 'request jsonb'
      and function_object.prosecdef
      and function_object.proconfig::text like '%search_path=%'
      and owner_role.rolname = 'atlas_master_data_command_runtime'
  ),
  '03C-A bulk command is an empty-search-path definer owned by the existing runtime'
);

select ok(
  has_function_privilege(
    'authenticated',
    'atlas_api.update_school_portion_defaults_bulk(jsonb)',
    'EXECUTE'
  ),
  'authenticated may execute the bulk command'
);
select ok(
  not has_function_privilege(
    'anon',
    'atlas_api.update_school_portion_defaults_bulk(jsonb)',
    'EXECUTE'
  ),
  'anon cannot execute the bulk command'
);
select ok(
  not has_function_privilege(
    'service_role',
    'atlas_api.update_school_portion_defaults_bulk(jsonb)',
    'EXECUTE'
  ),
  'service_role cannot execute the bulk command'
);
select is(
  (
    select count(*)::integer
    from atlas_core.capabilities
    where capability_code = 'master_data.schools.write'
      and capability_status = 'ACTIVE'
  ),
  1,
  'the existing active master_data.schools.write capability is reused'
);
select ok(
  not exists (
    select 1
    from atlas_core.capabilities
    where capability_code like '%school%bulk%'
       or capability_code like '%bulk%school%'
  ),
  'no bulk-specific School capability exists'
);

insert into atlas_core.actors (actor_id, actor_type, display_name) values
  (
    'c3100000-0000-0000-0000-000000000001',
    'HUMAN',
    'UI-QUALITY-03C-A authorized operator'
  ),
  (
    'c3100000-0000-0000-0000-000000000002',
    'HUMAN',
    'UI-QUALITY-03C-A denied operator'
  );

insert into atlas_core.actor_auth_subjects (
  actor_auth_subject_id,
  actor_id,
  auth_subject_id
) values
  (
    'c3100000-0000-0000-0000-000000000011',
    'c3100000-0000-0000-0000-000000000001',
    'c3100000-0000-0000-0000-000000000101'
  ),
  (
    'c3100000-0000-0000-0000-000000000012',
    'c3100000-0000-0000-0000-000000000002',
    'c3100000-0000-0000-0000-000000000102'
  );

insert into atlas_core.roles (role_id, role_code, role_name) values
  (
    'c3100000-0000-0000-0000-000000000020',
    'ui_quality_03c_a.school_defaults_operator',
    'UI-QUALITY-03C-A School defaults operator'
  ),
  (
    'c3100000-0000-0000-0000-000000000021',
    'ui_quality_03c_a.no_capability',
    'UI-QUALITY-03C-A no capability'
  );

insert into atlas_core.role_capabilities (role_id, capability_id)
select
  'c3100000-0000-0000-0000-000000000020',
  capability_id
from atlas_core.capabilities
where capability_code = 'master_data.schools.write';

insert into atlas_core.actor_role_memberships (actor_id, role_id) values
  (
    'c3100000-0000-0000-0000-000000000001',
    'c3100000-0000-0000-0000-000000000020'
  ),
  (
    'c3100000-0000-0000-0000-000000000002',
    'c3100000-0000-0000-0000-000000000021'
  );

insert into atlas_core.actor_scopes (actor_id, scope_kind) values
  ('c3100000-0000-0000-0000-000000000001', 'GLOBAL'),
  ('c3100000-0000-0000-0000-000000000002', 'GLOBAL');

insert into atlas_admin.customers (
  customer_id,
  customer_code,
  customer_name,
  customer_type
) values (
  'c3200000-0000-0000-0000-000000000001',
  'uiq03ca-customer',
  'UI-QUALITY-03C-A Customer',
  'SCHOOL_CATERING'
);

insert into atlas_admin.delivery_locations (
  delivery_location_id,
  customer_id,
  location_code,
  location_name,
  address_text
) values (
  'c3200000-0000-0000-0000-000000000002',
  'c3200000-0000-0000-0000-000000000001',
  'uiq03ca-main-gate',
  'UI-QUALITY-03C-A Main Gate',
  'UI-QUALITY-03C-A address'
);

insert into atlas_admin.school_types (
  school_type_id,
  school_type_code,
  school_type_name
) values (
  'c3200000-0000-0000-0000-000000000003',
  'uiq03ca-primary',
  'Primary'
);

insert into atlas_admin.schools (
  school_id,
  customer_id,
  school_code,
  school_name,
  school_type_id,
  default_delivery_location_id,
  display_order,
  default_student_portions,
  default_teacher_portions
) values
  (
    'c3200000-0000-0000-0000-000000000011',
    'c3200000-0000-0000-0000-000000000001',
    'uiq03ca-school-a',
    'UI-QUALITY-03C-A School A',
    'c3200000-0000-0000-0000-000000000003',
    'c3200000-0000-0000-0000-000000000002',
    1,
    100,
    10
  ),
  (
    'c3200000-0000-0000-0000-000000000012',
    'c3200000-0000-0000-0000-000000000001',
    'uiq03ca-school-b',
    'UI-QUALITY-03C-A School B',
    'c3200000-0000-0000-0000-000000000003',
    'c3200000-0000-0000-0000-000000000002',
    2,
    200,
    20
  ),
  (
    'c3200000-0000-0000-0000-000000000013',
    'c3200000-0000-0000-0000-000000000001',
    'uiq03ca-school-c',
    'UI-QUALITY-03C-A School C',
    'c3200000-0000-0000-0000-000000000003',
    'c3200000-0000-0000-0000-000000000002',
    3,
    300,
    30
  );

create temporary table uiq03ca_school_c_before as
select
  school_id,
  default_student_portions,
  default_teacher_portions,
  version,
  updated_at
from atlas_admin.schools
where school_id = 'c3200000-0000-0000-0000-000000000013';

create or replace function pg_temp.uiq03ca_bulk_request(
  p_command_id uuid,
  p_idempotency_key text,
  p_subject uuid,
  p_changes jsonb
)
returns jsonb
language sql
as $$
  select jsonb_build_object(
    'contract_version', 'RMVP-01.v2',
    'command_id', p_command_id,
    'correlation_id', 'c3900000-0000-0000-0000-000000000001',
    'idempotency_key', p_idempotency_key,
    'requested_by_auth_subject', p_subject,
    'requested_at', transaction_timestamp() - interval '1 second',
    'reason_code', 'SCHOOL_PORTION_DEFAULTS_BULK_UPDATE',
    'reason_note', 'Rolled-back UI-QUALITY-03C-A test',
    'payload', jsonb_build_object('changes', p_changes)
  );
$$;

create function pg_temp.weekday_request(overrides jsonb, expected bigint default 1)
returns jsonb language sql as $$
select pg_temp.uiq03ca_bulk_request(gen_random_uuid(), gen_random_uuid()::text,
'c3100000-0000-0000-0000-000000000101', jsonb_build_array(jsonb_build_object(
'school_id','c3200000-0000-0000-0000-000000000011', 'expected_version',expected,
'default_student_portions',100,'default_teacher_portions',10,
'weekday_portion_defaults',overrides)))
$$;
-- Keep explicit saved and approved attendance as immutable comparison evidence.
insert into atlas_planning.attendance_batches(attendance_batch_id,period_start,period_end,source_type,source_name,source_signature,imported_by_actor_id)
values ('c3300000-0000-0000-0000-000000000001','2026-11-02','2026-11-08','MANUAL','Saved zero','saved-zero','c3100000-0000-0000-0000-000000000001'),
('c3300000-0000-0000-0000-000000000002','2026-10-26','2026-11-01','MANUAL','Approved zero','approved-zero','c3100000-0000-0000-0000-000000000001');
insert into atlas_planning.attendance_lines(attendance_batch_id,school_id,service_date,student_portions,teacher_portions,created_by_actor_id,updated_by_actor_id)
select attendance_batch_id,'c3200000-0000-0000-0000-000000000011',period_start,0,0,imported_by_actor_id,imported_by_actor_id
from atlas_planning.attendance_batches where attendance_batch_id in ('c3300000-0000-0000-0000-000000000001','c3300000-0000-0000-0000-000000000002');
update atlas_planning.attendance_batches set attendance_status='VALIDATED' where attendance_batch_id='c3300000-0000-0000-0000-000000000002';
insert into atlas_planning.attendance_approval_snapshots(attendance_approval_snapshot_id,attendance_batch_id,attendance_version,approved_by_actor_id,approved_at)
values ('c3300000-0000-0000-0000-000000000003','c3300000-0000-0000-0000-000000000002',1,'c3100000-0000-0000-0000-000000000001',transaction_timestamp());
insert into atlas_planning.attendance_approval_snapshot_lines(attendance_approval_snapshot_id,attendance_batch_id,attendance_version,attendance_line_id,school_id,service_date,student_portions,teacher_portions,source_row_reference) select 'c3300000-0000-0000-0000-000000000003',attendance_batch_id,1,attendance_line_id,school_id,service_date,student_portions,teacher_portions,source_row_reference from atlas_planning.attendance_lines where attendance_batch_id='c3300000-0000-0000-0000-000000000002';
update atlas_planning.attendance_batches set attendance_status='APPROVED',latest_approval_snapshot_id='c3300000-0000-0000-0000-000000000003',latest_approved_by_actor_id=imported_by_actor_id,latest_approved_at=transaction_timestamp()
where attendance_batch_id='c3300000-0000-0000-0000-000000000002';
create temporary table saved_attendance_before as select to_jsonb(b) as fact from atlas_planning.attendance_batches b
union all select to_jsonb(l) from atlas_planning.attendance_lines l
union all select to_jsonb(s) from atlas_planning.attendance_approval_snapshots s
union all select to_jsonb(sl) from atlas_planning.attendance_approval_snapshot_lines sl;
set local role authenticated;
select set_config('request.jwt.claim.sub','c3100000-0000-0000-0000-000000000101',true);
select is(atlas_api.update_school_portion_defaults_bulk(pg_temp.weekday_request(
'{"1":{"student_portions":0},"2":{"teacher_portions":22},"3":{"student_portions":33},"4":{"student_portions":44},"5":{"teacher_portions":55}}'
))->>'success','true','weekday-only update accepts all five closed weekdays and explicit zero');
select is(atlas_api.update_school_portion_defaults_bulk(pg_temp.weekday_request('{}'))->>'error_code',
'STALE_VERSION','weekday updates retain School optimistic concurrency');
select is(atlas_api.update_school_portion_defaults_bulk(pg_temp.weekday_request(value,2))->>'error_code',
'VALIDATION_FAILED','reject invalid weekday payload '||value::text)
from (values ('{"0":{}}'::jsonb),('{"6":{}}'),('{"01":{}}'),('{"1":{"x":1}}'),
('{"1":{"student_portions":-1}}'),('{"1":{"student_portions":1.1}}'),
('{"1":{"student_portions":2147483648}}'),('{"1":{"student_portions":"1"}}'),
('{"1":{"student_portions":null}}'),('{"1":[]}'),('[]'),('null')) invalid(value);
select set_config('request.jwt.claim.sub','c3100000-0000-0000-0000-000000000102',true);
select is(atlas_api.update_school_portion_defaults_bulk(jsonb_set(pg_temp.weekday_request('{}',2),
'{requested_by_auth_subject}','"c3100000-0000-0000-0000-000000000102"'))->>'error_code',
'CAPABILITY_DENIED','weekday changes require existing School write capability');
reset role;
select is((select (r->>'student_portions')::integer from jsonb_array_elements(
atlas_core.rmvp_03a_default_attendance_rows('2026-11-02')) r where r->>'school_id'='c3200000-0000-0000-0000-000000000011' and r->>'service_date'='2026-11-02'),
0,'Monday explicit zero is generated');
select is((select (r->>'teacher_portions')::integer from jsonb_array_elements(
atlas_core.rmvp_03a_default_attendance_rows('2026-11-02')) r where r->>'school_id'='c3200000-0000-0000-0000-000000000011' and r->>'service_date'='2026-11-03'),
22,'Tuesday overrides teacher while other fields fallback');
select is((select (r->>'student_portions')::integer from jsonb_array_elements(
atlas_core.rmvp_03a_default_attendance_rows('2026-11-02')) r where r->>'school_id'='c3200000-0000-0000-0000-000000000011' and r->>'service_date'='2026-11-03'),
100,'missing weekday population field falls back to current School default');
select is((select (r->>'student_portions')::integer from jsonb_array_elements(
atlas_core.rmvp_03a_default_attendance_rows('2026-11-02')) r where r->>'school_id'='c3200000-0000-0000-0000-000000000011' and r->>'service_date'='2026-11-07'),
100,'weekend retains existing fallback');
select results_eq(
$$select fact from saved_attendance_before$$,
$$select to_jsonb(b) from atlas_planning.attendance_batches b union all select to_jsonb(l) from atlas_planning.attendance_lines l union all select to_jsonb(s) from atlas_planning.attendance_approval_snapshots s union all select to_jsonb(sl) from atlas_planning.attendance_approval_snapshot_lines sl$$,
'School defaults never rewrite saved Attendance zero, approved batches, snapshots or versions');
select ok(not exists(select 1 from jsonb_array_elements(atlas_core.rmvp_03a_attendance_issues('2026-11-02',
'[{"school_id":"c3200000-0000-0000-0000-000000000011","service_date":"2026-11-02","student_portions":0,"teacher_portions":10}]')->'warnings') warning where warning->>'code'='PORTIONS_DIFFER_FROM_DEFAULT'),
'Attendance warnings compare against effective weekday defaults');
-- The original single-School caller may omit weekday data and must retain it.
set local role authenticated;
select set_config('request.jwt.claim.sub','c3100000-0000-0000-0000-000000000101',true);
select is(atlas_api.update_school_portion_defaults(
(jsonb_set(pg_temp.weekday_request('{}',2),'{contract_version}','"RMVP-01.v1"') - 'payload') || jsonb_build_object('expected_version',2,'payload',jsonb_build_object(
'school_id','c3200000-0000-0000-0000-000000000011','default_student_portions',101,'default_teacher_portions',10))) ->> 'success','true','old single-School default caller remains valid');
reset role;
select is((select weekday_portion_defaults#>>'{1,student_portions}' from atlas_admin.schools where school_id='c3200000-0000-0000-0000-000000000011'),'0','omitted weekday field preserves existing overrides');
set local role authenticated;
select set_config('request.jwt.claim.sub','c3100000-0000-0000-0000-000000000101',true);
select is(atlas_api.update_school_portion_defaults_bulk(pg_temp.uiq03ca_bulk_request(gen_random_uuid(),gen_random_uuid()::text,
'c3100000-0000-0000-0000-000000000101',jsonb_build_array(
jsonb_build_object('school_id','c3200000-0000-0000-0000-000000000011','expected_version',3,'default_student_portions',102,'default_teacher_portions',10),
jsonb_build_object('school_id','c3200000-0000-0000-0000-000000000012','expected_version',1,'default_student_portions',201,'default_teacher_portions',20,'weekday_portion_defaults','{"7":{}}'::jsonb))))->>'error_code',
'VALIDATION_FAILED','one invalid weekday rejects the entire multi-School Save');
reset role;
select is((select default_student_portions from atlas_admin.schools where school_id='c3200000-0000-0000-0000-000000000011'),101,'invalid bulk never partially updates neighboring School');
-- Menu-aware population is still an exact School/date selection.
insert into atlas_admin.dishes(dish_id,dish_code,dish_name,dish_status) values('c3400000-0000-0000-0000-000000000001','weekday-test','Weekday test','ACTIVE');
insert into atlas_planning.weekly_menus(weekly_menu_id,week_start,week_end,source_type,source_name,source_signature,imported_by_actor_id)
values ('c3400000-0000-0000-0000-000000000002','2026-11-02','2026-11-08','MANUAL','weekday test','weekday-test','c3100000-0000-0000-0000-000000000001');
insert into atlas_planning.weekly_menu_lines(weekly_menu_id,school_id,service_date,menu_slot_code,dish_id,created_by_actor_id,updated_by_actor_id)
values('c3400000-0000-0000-0000-000000000002','c3200000-0000-0000-0000-000000000011','2026-11-06','soup','c3400000-0000-0000-0000-000000000001','c3100000-0000-0000-0000-000000000001','c3100000-0000-0000-0000-000000000001');
select is(jsonb_array_length(atlas_core.rmvp_03a_default_attendance_rows('2026-11-02')),1,'selected Menu restricts defaults to its active School/date population');
select is(atlas_core.rmvp_03a_default_attendance_rows('2026-11-02')#>>'{0,teacher_portions}','55','menu-aware Friday uses Friday override');
select is(atlas_core.rmvp_03a_planning_workbench_payload('2026-11-02')#>>'{schools,0,weekday_portion_defaults,1,student_portions}','0','Planning read shapes weekday defaults');
select ok(not has_function_privilege(role_name,'atlas_core.valid_weekday_portion_defaults(jsonb)','EXECUTE'),'private validator denies '||role_name) from (values ('anon'),('authenticated'),('service_role')) roles(role_name);
set local role authenticated;
select set_config('request.jwt.claim.sub','c3100000-0000-0000-0000-000000000101',true);
select is(atlas_api.update_school_portion_defaults_bulk(pg_temp.weekday_request('{}',3))->>'success','true','explicit empty weekday object clears overrides');
reset role;
select is((select weekday_portion_defaults from atlas_admin.schools where school_id='c3200000-0000-0000-0000-000000000011'),'{}'::jsonb,'clearing overrides restores fallback');
select throws_ok($$update atlas_admin.schools set weekday_portion_defaults='{"6":{}}' where school_id='c3200000-0000-0000-0000-000000000011'$$,'23514',null,'table constraint rejects invalid weekday facts even for the database owner');
update atlas_admin.schools set weekday_portion_defaults='{"5":{"student_portions":1.0}}' where school_id='c3200000-0000-0000-0000-000000000011';
select lives_ok($$select atlas_core.rmvp_03a_default_attendance_rows('2026-11-02')$$,'whole JSON numeric decimals generate safely');
select * from finish();
rollback;
