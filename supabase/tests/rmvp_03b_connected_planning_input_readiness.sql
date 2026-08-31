begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
select plan(84);

grant usage on schema extensions to authenticated;
grant execute on all functions in schema extensions to authenticated;

-- Catalog, security, ownership, and bounded-delta assertions.
-- 01
select is((select count(*)::integer from atlas_core.capabilities where capability_code = 'planning.input_readiness.write'), 1, 'R3B-01 exactly one readiness-write capability exists');
-- 02
select is((select count(*)::integer from atlas_core.role_capabilities rc join atlas_core.capabilities c on c.capability_id = rc.capability_id where c.capability_code = 'planning.input_readiness.write'), 0, 'R3B-02 the capability has no production role binding');
-- 03
select is((select array_agg(p.proname order by p.proname)::text[] from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'atlas_api' and p.proname like '%planning_input%readiness%' or n.nspname = 'atlas_api' and p.proname = 'request_planning_input_need_generation'), array['evaluate_planning_input_readiness','get_planning_input_readiness_workbench','invalidate_planning_input_readiness','request_planning_input_need_generation']::text[], 'R3B-03 exactly four RMVP-03B APIs exist');
-- 04
select ok((select bool_and(case when p.proname = 'get_planning_input_readiness_workbench' then pg_get_userbyid(p.proowner) = 'atlas_read_runtime' else pg_get_userbyid(p.proowner) = 'atlas_planning_command_runtime' end) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'atlas_api' and p.proname in ('get_planning_input_readiness_workbench','evaluate_planning_input_readiness','request_planning_input_need_generation','invalidate_planning_input_readiness')), 'R3B-04 read and command APIs have exact runtime owners');
-- 05
select ok((select bool_and(p.prosecdef and p.proconfig = array['search_path=""']::text[]) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'atlas_api' and p.proname in ('get_planning_input_readiness_workbench','evaluate_planning_input_readiness','request_planning_input_need_generation','invalidate_planning_input_readiness')), 'R3B-05 every public API is a fixed-search-path definer');
-- 06
select ok((select bool_and(has_function_privilege('authenticated', p.oid, 'EXECUTE')) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'atlas_api' and p.proname in ('get_planning_input_readiness_workbench','evaluate_planning_input_readiness','request_planning_input_need_generation','invalidate_planning_input_readiness')), 'R3B-06 authenticated can execute all four APIs');
-- 07
select ok((select bool_and(not has_function_privilege('anon', p.oid, 'EXECUTE')) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'atlas_api' and p.proname in ('get_planning_input_readiness_workbench','evaluate_planning_input_readiness','request_planning_input_need_generation','invalidate_planning_input_readiness')), 'R3B-07 anon executes none of the four APIs');
-- 08
select ok((select bool_and(not has_function_privilege('service_role', p.oid, 'EXECUTE')) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'atlas_api' and p.proname in ('get_planning_input_readiness_workbench','evaluate_planning_input_readiness','request_planning_input_need_generation','invalidate_planning_input_readiness')), 'R3B-08 service_role executes none of the four APIs');
-- 09
select is((select jsonb_build_object('helper_count',count(*),'atlas_owner_invokers',count(*) filter (where pg_get_userbyid(p.proowner) = 'atlas_owner' and not p.prosecdef),'read_runtime_history_definers',count(*) filter (where p.proname = 'rmvp_03b_workbench_payload' and pg_get_userbyid(p.proowner) = 'atlas_read_runtime' and p.prosecdef),'fixed_search_paths',count(*) filter (where p.proconfig = array['search_path=""']::text[])) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'atlas_core' and p.proname like 'rmvp_03b_%'), jsonb_build_object('helper_count',20,'atlas_owner_invokers',19,'read_runtime_history_definers',1,'fixed_search_paths',20), 'R3B-09 exactly one shaped history/readback helper is a fixed-search-path read-runtime definer and the other nineteen helpers remain atlas_owner invokers');
-- 10
select ok((select bool_and(not has_function_privilege('authenticated', p.oid, 'EXECUTE') and not has_function_privilege('anon', p.oid, 'EXECUTE') and not has_function_privilege('service_role', p.oid, 'EXECUTE')) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'atlas_core' and p.proname like 'rmvp_03b_%'), 'R3B-10 private helpers are browser-inaccessible');
-- 11
select is((select jsonb_build_object('tables', count(*) filter (where c.relkind='r'), 'views', count(*) filter (where c.relkind in ('v','m')), 'rmvp_06_relations', array_agg(c.relname order by c.relname) filter (where c.relkind='r' and n.nspname='atlas_planning' and c.relname like 'confirmed_need_validation_%'), 'rmvp_07_relations', array_agg(c.relname order by c.relname) filter (where c.relkind='r' and n.nspname='atlas_planning' and c.relname='confirmed_need_releases')) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname like 'atlas\_%' escape '\'), jsonb_build_object('tables',107,'views',2,'rmvp_06_relations',array['confirmed_need_validation_attempts','confirmed_need_validation_issues','confirmed_need_validation_lines']::text[],'rmvp_07_relations',array['confirmed_need_releases']::text[]), 'R3B-11 RMVP-03B itself owns no new relation or view; the current Atlas catalog is exactly 107 tables and 2 views while the bounded RMVP-06/07 relations remain unchanged');
-- 12
select is((select count(*)::integer from pg_roles where rolname like 'atlas\_%' escape '\'), 11, 'R3B-12 current catalogue includes the dedicated RMVP-05 Confirmed Need review runtime');
-- 13
select is((select jsonb_build_object('capabilities',count(*),'rmvp_06_capabilities',array_agg(capability_code order by capability_code) filter (where capability_code like 'confirmed_need_validation.%'),'rmvp_07_capabilities',array_agg(capability_code order by capability_code) filter (where capability_code in ('confirmed_need_approval.approve','confirmed_need_release.release'))) from atlas_core.capabilities), jsonb_build_object('capabilities',29,'rmvp_06_capabilities',array['confirmed_need_validation.validate']::text[],'rmvp_07_capabilities',array['confirmed_need_approval.approve','confirmed_need_release.release']::text[]), 'R3B-13 current catalogue has exactly 29 capabilities while retaining the RMVP-06 validation and two RMVP-07 lifecycle capabilities');
-- 14
select is((select jsonb_build_object('rmvp_06_apis',array_agg(p.proname order by p.proname) filter (where p.proname='validate_confirmed_needs'),'rmvp_07_apis',array_agg(p.proname order by p.proname) filter (where p.proname in ('approve_confirmed_needs','release_confirmed_needs_for_purchase_handoff'))) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='atlas_api'), jsonb_build_object('rmvp_06_apis',array['validate_confirmed_needs']::text[],'rmvp_07_apis',array['approve_confirmed_needs','release_confirmed_needs_for_purchase_handoff']::text[]), 'R3B-14 exact RMVP-06/07 APIs remain while the four RMVP-03B identities are asserted separately');
-- 15
select is((select count(*)::integer from pg_policy p join pg_class c on c.oid=p.polrelid join pg_namespace n on n.oid=c.relnamespace where p.polname like 'rmvp_03b_%'), 12, 'R3B-15 exactly twelve bounded RLS policies were added');
-- 16
select is((select count(*)::integer from pg_trigger where not tgisinternal and tgname like 'rmvp_03b_%'), 0, 'R3B-16 no automatic source trigger was added');
-- 17
select ok(has_table_privilege('atlas_read_runtime','atlas_planning.planning_input_sets','SELECT') and not has_table_privilege('atlas_read_runtime','atlas_planning.planning_input_sets','INSERT,UPDATE,DELETE') and has_table_privilege('atlas_read_runtime','atlas_planning.need_generation_runs','SELECT') and not has_table_privilege('atlas_read_runtime','atlas_planning.need_generation_runs','INSERT,UPDATE,DELETE') and not has_table_privilege('atlas_planning_command_runtime','atlas_audit.domain_events','SELECT') and not has_table_privilege('atlas_planning_command_runtime','atlas_audit.audit_events','SELECT') and not has_function_privilege('atlas_planning_command_runtime','atlas_core.rmvp_03b_all_history_items(uuid)'::regprocedure,'EXECUTE') and not has_function_privilege('atlas_planning_command_runtime','atlas_core.rmvp_03b_history_page(uuid,date,date,integer,text)'::regprocedure,'EXECUTE') and not exists (select 1 from pg_auth_members membership join pg_roles granted_role on granted_role.oid=membership.roleid join pg_roles member_role on member_role.oid=membership.member where granted_role.rolname in ('atlas_read_runtime','atlas_planning_command_runtime') and member_role.rolname='postgres' and membership.set_option) and (select array_agg(format('%s|%s|grantable=%s',r.rolname,acl.privilege_type,acl.is_grantable) order by r.rolname,acl.privilege_type)::text[] from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(p.proacl) acl join pg_roles r on r.oid=acl.grantee where n.nspname='atlas_core' and p.proname='rmvp_03b_workbench_payload') = array['atlas_planning_command_runtime|EXECUTE|grantable=f','atlas_read_runtime|EXECUTE|grantable=f']::text[], 'R3B-17 shaped history/readback is owned by the read runtime while the command runtime has only exact workbench-helper execution, no lower history-helper or raw audit access, and no postgres set-role membership');
-- 18
select ok(has_table_privilege('atlas_planning_command_runtime','atlas_planning.planning_input_sets','SELECT,INSERT,UPDATE') and not has_table_privilege('atlas_planning_command_runtime','atlas_planning.planning_input_sets','DELETE') and has_table_privilege('atlas_planning_command_runtime','atlas_planning.planning_input_evaluations','SELECT,INSERT') and not has_table_privilege('atlas_planning_command_runtime','atlas_planning.planning_input_evaluations','UPDATE,DELETE'), 'R3B-18 command runtime has bounded root/evaluation privileges');
-- 19
select ok(has_table_privilege('atlas_planning_command_runtime','atlas_planning.need_generation_runs','SELECT') and not has_table_privilege('atlas_planning_command_runtime','atlas_planning.need_generation_runs','INSERT,UPDATE,DELETE'), 'R3B-19 Need Generation runs remain read-only evidence');
-- 20
select ok(not has_schema_privilege('authenticated','atlas_planning','USAGE') and not has_table_privilege('authenticated','atlas_planning.planning_input_sets','SELECT') and not has_table_privilege('authenticated','atlas_core.command_receipts','SELECT'), 'R3B-20 browser roles retain no private relation access');

create function pg_temp.r3b_read(
  p_start date,
  p_end date,
  p_selection jsonb default null,
  p_limit integer default null,
  p_cursor text default null,
  p_subject uuid default 'd3000000-0000-0000-0000-000000000101'
)
returns jsonb language sql stable as $$
  select jsonb_build_object(
    'contract_version','RMVP-03B.v1',
    'requested_by_auth_subject',p_subject,
    'correlation_id',gen_random_uuid(),
    'payload',jsonb_strip_nulls(jsonb_build_object(
      'period_start',p_start,
      'period_end',p_end,
      'source_selection',p_selection,
      'history_limit',p_limit,
      'history_cursor',p_cursor
    ))
  );
$$;

create function pg_temp.r3b_command(
  p_command_id uuid,
  p_idempotency text,
  p_expected_status text,
  p_expected_evaluation_id uuid,
  p_expected_version bigint,
  p_reason text,
  p_note text,
  p_payload jsonb,
  p_subject uuid default 'd3000000-0000-0000-0000-000000000101'
)
returns jsonb language sql stable as $$
  select jsonb_build_object(
    'contract_version','RMVP-03B.v1',
    'command_id',p_command_id,
    'correlation_id',gen_random_uuid(),
    'idempotency_key',p_idempotency,
    'requested_by_auth_subject',p_subject,
    'requested_at',transaction_timestamp(),
    'expected_root_status',p_expected_status,
    'expected_current_evaluation_id',p_expected_evaluation_id,
    'expected_current_evaluation_version',p_expected_version,
    'reason_code',p_reason,
    'reason_note',p_note,
    'payload',p_payload
  );
$$;

insert into atlas_core.actors (actor_id,actor_type,display_name) values
  ('d3000000-0000-0000-0000-000000000001','HUMAN','RMVP-03B authorized operator'),
  ('d3000000-0000-0000-0000-000000000002','HUMAN','RMVP-03B no-capability operator'),
  ('d3000000-0000-0000-0000-000000000003','HUMAN','RMVP-03B no-scope operator');
insert into atlas_core.actor_auth_subjects (actor_auth_subject_id,actor_id,auth_subject_id) values
  ('d3000000-0000-0000-0000-000000000011','d3000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000101'),
  ('d3000000-0000-0000-0000-000000000012','d3000000-0000-0000-0000-000000000002','d3000000-0000-0000-0000-000000000102'),
  ('d3000000-0000-0000-0000-000000000013','d3000000-0000-0000-0000-000000000003','d3000000-0000-0000-0000-000000000103');
insert into atlas_core.roles (role_id,role_code,role_name) values
  ('d3000000-0000-0000-0000-000000000020','rmvp03b.operator','RMVP-03B operator'),
  ('d3000000-0000-0000-0000-000000000021','rmvp03b.denied','RMVP-03B denied');
insert into atlas_core.role_capabilities (role_id,capability_id)
select 'd3000000-0000-0000-0000-000000000020',capability_id from atlas_core.capabilities
where capability_code in ('planning.inputs.read','planning.input_readiness.write');
insert into atlas_core.actor_role_memberships (actor_id,role_id) values
  ('d3000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000020'),
  ('d3000000-0000-0000-0000-000000000002','d3000000-0000-0000-0000-000000000021'),
  ('d3000000-0000-0000-0000-000000000003','d3000000-0000-0000-0000-000000000020');
insert into atlas_core.actor_scopes (actor_id,scope_kind) values
  ('d3000000-0000-0000-0000-000000000001','GLOBAL'),
  ('d3000000-0000-0000-0000-000000000002','GLOBAL');

set session_replication_role = replica;

insert into atlas_admin.schools (school_id,customer_id,school_code,school_name,school_type_id,default_delivery_location_id,display_order)
values ('d3400000-0000-0000-0000-000000000001','d3400000-0000-0000-0000-000000000002','r3b-school','RMVP-03B school','d3400000-0000-0000-0000-000000000003','d3400000-0000-0000-0000-000000000004',1);

insert into atlas_planning.weekly_menus (weekly_menu_id,week_start,week_end,source_type,source_name,source_signature,row_count,imported_by_actor_id) values
  ('d3100000-0000-0000-0000-000000000001','2026-11-02','2026-11-08','FIXTURE','RMVP-03B menu A','sig-menu-a',2,'d3000000-0000-0000-0000-000000000001'),
  ('d3100000-0000-0000-0000-000000000011','2026-11-09','2026-11-15','FIXTURE','RMVP-03B menu B','sig-menu-b',0,'d3000000-0000-0000-0000-000000000001');
insert into atlas_planning.weekly_menu_approval_snapshots (weekly_menu_approval_snapshot_id,weekly_menu_id,weekly_menu_version,approved_by_actor_id,approved_at) values
  ('d3100000-0000-0000-0000-000000000002','d3100000-0000-0000-0000-000000000001',1,'d3000000-0000-0000-0000-000000000001',transaction_timestamp()),
  ('d3100000-0000-0000-0000-000000000012','d3100000-0000-0000-0000-000000000011',1,'d3000000-0000-0000-0000-000000000001',transaction_timestamp());
update atlas_planning.weekly_menus set weekly_menu_status='APPROVED',latest_approved_by_actor_id='d3000000-0000-0000-0000-000000000001',latest_approved_at=transaction_timestamp(),latest_approval_snapshot_id=case weekly_menu_id when 'd3100000-0000-0000-0000-000000000001' then 'd3100000-0000-0000-0000-000000000002'::uuid else 'd3100000-0000-0000-0000-000000000012'::uuid end;
insert into atlas_planning.weekly_menu_approval_snapshot_lines (weekly_menu_approval_snapshot_id,weekly_menu_id,weekly_menu_version,weekly_menu_line_id,school_id,service_date,menu_slot_code,dish_id) values
  ('d3100000-0000-0000-0000-000000000002','d3100000-0000-0000-0000-000000000001',1,'d3100000-0000-0000-0000-000000000003','d3400000-0000-0000-0000-000000000001','2026-11-02','savory','d3400000-0000-0000-0000-000000000005'),
  ('d3100000-0000-0000-0000-000000000002','d3100000-0000-0000-0000-000000000001',1,'d3100000-0000-0000-0000-000000000004','d3400000-0000-0000-0000-000000000001','2026-11-04','savory','d3400000-0000-0000-0000-000000000005');

insert into atlas_planning.attendance_batches (attendance_batch_id,period_start,period_end,source_type,source_name,source_signature,row_count,imported_by_actor_id) values
  ('d3200000-0000-0000-0000-000000000001','2026-11-02','2026-11-08','FIXTURE','RMVP-03B attendance A','sig-att-a',2,'d3000000-0000-0000-0000-000000000001'),
  ('d3200000-0000-0000-0000-000000000011','2026-11-09','2026-11-15','FIXTURE','RMVP-03B attendance B','sig-att-b',0,'d3000000-0000-0000-0000-000000000001');
insert into atlas_planning.attendance_approval_snapshots (attendance_approval_snapshot_id,attendance_batch_id,attendance_version,approved_by_actor_id,approved_at) values
  ('d3200000-0000-0000-0000-000000000002','d3200000-0000-0000-0000-000000000001',1,'d3000000-0000-0000-0000-000000000001',transaction_timestamp()),
  ('d3200000-0000-0000-0000-000000000012','d3200000-0000-0000-0000-000000000011',1,'d3000000-0000-0000-0000-000000000001',transaction_timestamp());
update atlas_planning.attendance_batches set attendance_status='APPROVED',latest_approved_by_actor_id='d3000000-0000-0000-0000-000000000001',latest_approved_at=transaction_timestamp(),latest_approval_snapshot_id=case attendance_batch_id when 'd3200000-0000-0000-0000-000000000001' then 'd3200000-0000-0000-0000-000000000002'::uuid else 'd3200000-0000-0000-0000-000000000012'::uuid end;
insert into atlas_planning.attendance_approval_snapshot_lines (attendance_approval_snapshot_id,attendance_batch_id,attendance_version,attendance_line_id,school_id,service_date,student_portions,teacher_portions) values
  ('d3200000-0000-0000-0000-000000000002','d3200000-0000-0000-0000-000000000001',1,'d3200000-0000-0000-0000-000000000003','d3400000-0000-0000-0000-000000000001','2026-11-02',0,0),
  ('d3200000-0000-0000-0000-000000000002','d3200000-0000-0000-0000-000000000001',1,'d3200000-0000-0000-0000-000000000004','d3400000-0000-0000-0000-000000000001','2026-11-03',10,1);

insert into atlas_planning.pantry_need_batches (pantry_need_batch_id,week_start,source_signature,no_additions_confirmed,requesting_actor_id) values
  ('d3300000-0000-0000-0000-000000000001','2026-11-02',repeat('a',64),true,'d3000000-0000-0000-0000-000000000001'),
  ('d3300000-0000-0000-0000-000000000011','2026-11-09',repeat('b',64),false,'d3000000-0000-0000-0000-000000000001');
insert into atlas_planning.pantry_need_approval_snapshots (pantry_need_approval_snapshot_id,pantry_need_batch_id,approved_batch_version,approved_by_actor_id,approved_at,source_signature,no_additions_confirmed,line_count) values
  ('d3300000-0000-0000-0000-000000000002','d3300000-0000-0000-0000-000000000001',1,'d3000000-0000-0000-0000-000000000001',transaction_timestamp(),repeat('a',64),true,0),
  ('d3300000-0000-0000-0000-000000000012','d3300000-0000-0000-0000-000000000011',1,'d3000000-0000-0000-0000-000000000001',transaction_timestamp(),repeat('b',64),false,1);
update atlas_planning.pantry_need_batches set pantry_need_batch_status='APPROVED',latest_approved_by_actor_id='d3000000-0000-0000-0000-000000000001',latest_approved_at=transaction_timestamp(),latest_approval_snapshot_id=case pantry_need_batch_id when 'd3300000-0000-0000-0000-000000000001' then 'd3300000-0000-0000-0000-000000000002'::uuid else 'd3300000-0000-0000-0000-000000000012'::uuid end;
insert into atlas_planning.pantry_need_approval_snapshot_lines (pantry_need_approval_snapshot_id,pantry_need_line_id,service_date,school_id,school_code_snapshot,school_name_snapshot,delivery_location_id,delivery_location_code_snapshot,delivery_location_name_snapshot,delivery_location_address_snapshot,ingredient_id,ingredient_code_snapshot,ingredient_name_snapshot,unit_id,unit_code_snapshot,unit_name_snapshot,pantry_need_purpose_id,purpose_code_snapshot,purpose_name_snapshot,purpose_description_snapshot,purpose_note_rule_snapshot,requested_quantity) values
  ('d3300000-0000-0000-0000-000000000012','d3300000-0000-0000-0000-000000000013','2026-11-09','d3400000-0000-0000-0000-000000000001','r3b-school','RMVP-03B school','d3400000-0000-0000-0000-000000000004','r3b-location','RMVP-03B location','Local fixture','d3400000-0000-0000-0000-000000000006','r3b-ingredient','RMVP-03B ingredient','d3400000-0000-0000-0000-000000000007','kg','Kilogram','d3400000-0000-0000-0000-000000000008','supplement','Supplement','Fixture purpose','OPTIONAL',1);

set session_replication_role = origin;

create temporary table r3b_responses (name text primary key,response jsonb not null);
grant select,insert,update on r3b_responses to authenticated;

set local role authenticated;
select set_config('request.jwt.claim.sub','d3000000-0000-0000-0000-000000000101',true);

insert into r3b_responses values ('absent',atlas_api.get_planning_input_readiness_workbench(pg_temp.r3b_read('2026-12-01','2026-12-03')));
reset role;
-- 21
select ok((select response->>'success'='true' from r3b_responses where name='absent'), 'R3B-21 exact-period read succeeds');
-- 22
select is((select response->'workbench'->>'decision' from r3b_responses where name='absent'),'NOT_EVALUATED','R3B-22 absent exact-period root is explicit');
-- 23
select is((select count(*)::integer from atlas_planning.planning_input_sets where period_start='2026-12-01' and period_end='2026-12-03'),0,'R3B-23 read never creates a root');
-- 24
select is((select jsonb_build_array(response->'workbench'->'source_evidence'->'weekly_menu'->>'selection_state',response->'workbench'->'source_evidence'->'attendance'->>'selection_state',response->'workbench'->'source_evidence'->'pantry'->>'selection_state') from r3b_responses where name='absent'),'["MISSING","MISSING","MISSING"]'::jsonb,'R3B-24 all absent source families are MISSING');
-- 25
select is((select response->'workbench'->'source_evidence'->'pantry'->>'pantry_evidence_kind' from r3b_responses where name='absent'),'MISSING','R3B-25 missing Pantry is not explicit zero');
-- 26
select ok((select (response->'workbench'->'allowed_actions'->>'can_evaluate')::boolean from r3b_responses where name='absent'),'R3B-26 missing evidence can be evaluated into blockers');
-- 27
select is((select jsonb_array_length(response->'workbench'->'history_items') from r3b_responses where name='absent'),0,'R3B-27 absent history is empty');
set local role authenticated;
-- 28
select is((atlas_api.get_planning_input_readiness_workbench(pg_temp.r3b_read('2026-12-01','2026-12-03',null,51))->>'error_code'),'VALIDATION_FAILED','R3B-28 history limit above fifty fails');
-- 29
select is((atlas_api.get_planning_input_readiness_workbench(pg_temp.r3b_read('2026-12-01','2026-12-03',null,1,'not-a-cursor'))->>'error_code'),'INVALID_HISTORY_CURSOR','R3B-29 malformed cursor fails safely');
-- 30
select is((atlas_api.get_planning_input_readiness_workbench(pg_temp.r3b_read('2026-12-03','2026-12-01'))->>'error_code'),'VALIDATION_FAILED','R3B-30 reversed period fails validation');
-- 31
select is((atlas_api.get_planning_input_readiness_workbench(pg_temp.r3b_read('2026-12-01','2026-12-03',null,null,null,'d3000000-0000-0000-0000-000000000102'))->>'error_code'),'AUTH_SUBJECT_MISMATCH','R3B-31 asserted subject must match JWT');

select set_config('request.jwt.claim.sub','d3000000-0000-0000-0000-000000000102',true);
-- 32
select is((atlas_api.get_planning_input_readiness_workbench(pg_temp.r3b_read('2026-12-01','2026-12-03',null,null,null,'d3000000-0000-0000-0000-000000000102'))->>'error_code'),'CAPABILITY_DENIED','R3B-32 read capability is enforced');
select set_config('request.jwt.claim.sub','d3000000-0000-0000-0000-000000000103',true);
-- 33
select is((atlas_api.get_planning_input_readiness_workbench(pg_temp.r3b_read('2026-12-01','2026-12-03',null,null,null,'d3000000-0000-0000-0000-000000000103'))->>'error_code'),'SCOPE_DENIED','R3B-33 active GLOBAL scope is enforced');
select set_config('request.jwt.claim.sub','d3000000-0000-0000-0000-000000000101',true);

insert into r3b_responses values ('ready-read',atlas_api.get_planning_input_readiness_workbench(pg_temp.r3b_read('2026-11-02','2026-11-08')));
-- 34
select ok((select response->>'success'='true' from r3b_responses where name='ready-read'),'R3B-34 source-backed read succeeds');
-- 35
select is((select jsonb_build_array(response->'workbench'->'source_evidence'->'weekly_menu'->>'selection_state',response->'workbench'->'source_evidence'->'attendance'->>'selection_state',response->'workbench'->'source_evidence'->'pantry'->>'selection_state') from r3b_responses where name='ready-read'),'["SELECTED","SELECTED","SELECTED"]'::jsonb,'R3B-35 exactly one candidate auto-selects in every family');
-- 36
select is((select jsonb_build_array(response->'workbench'->'source_evidence'->'weekly_menu'->>'coverage',response->'workbench'->'source_evidence'->'attendance'->>'coverage',response->'workbench'->'source_evidence'->'pantry'->>'coverage') from r3b_responses where name='ready-read'),'["COVERS","COVERS","COVERS"]'::jsonb,'R3B-36 all three exact-week sources cover the period');
-- 37
select is((select response->'workbench'->'source_evidence'->'pantry'->>'pantry_evidence_kind' from r3b_responses where name='ready-read'),'EXPLICIT_ZERO_LINES','R3B-37 accepted Pantry zero evidence is explicit');
-- 38
select is((select (response->'workbench'->'source_evidence'->'pantry'->'selected'->>'line_count')::integer from r3b_responses where name='ready-read'),0,'R3B-38 explicit-zero Pantry line count is authoritative');

insert into r3b_responses values ('ambiguous',atlas_api.get_planning_input_readiness_workbench(pg_temp.r3b_read('2026-11-08','2026-11-09')));
-- 39
select is((select jsonb_build_array(response->'workbench'->'source_evidence'->'weekly_menu'->>'selection_state',response->'workbench'->'source_evidence'->'attendance'->>'selection_state',response->'workbench'->'source_evidence'->'pantry'->>'selection_state') from r3b_responses where name='ambiguous'),'["AMBIGUOUS","AMBIGUOUS","AMBIGUOUS"]'::jsonb,'R3B-39 multiple overlapping candidates are AMBIGUOUS');
-- 40
select ok(not (select (response->'workbench'->'allowed_actions'->>'can_evaluate')::boolean from r3b_responses where name='ambiguous'),'R3B-40 ambiguity disables evaluation');

insert into r3b_responses values ('chosen',atlas_api.get_planning_input_readiness_workbench(pg_temp.r3b_read('2026-11-08','2026-11-09',jsonb_build_object(
  'weekly_menu',jsonb_build_object('weekly_menu_id','d3100000-0000-0000-0000-000000000001','weekly_menu_version',1,'weekly_menu_approval_snapshot_id','d3100000-0000-0000-0000-000000000002'),
  'attendance',jsonb_build_object('attendance_batch_id','d3200000-0000-0000-0000-000000000001','attendance_version',1,'attendance_approval_snapshot_id','d3200000-0000-0000-0000-000000000002'),
  'pantry',jsonb_build_object('pantry_need_batch_id','d3300000-0000-0000-0000-000000000001','pantry_need_batch_version',1,'pantry_need_approval_snapshot_id','d3300000-0000-0000-0000-000000000002')
))));
-- 41
select is((select jsonb_build_array(response->'workbench'->'source_evidence'->'weekly_menu'->>'selection_state',response->'workbench'->'source_evidence'->'attendance'->>'selection_state',response->'workbench'->'source_evidence'->'pantry'->>'selection_state') from r3b_responses where name='chosen'),'["SELECTED","SELECTED","SELECTED"]'::jsonb,'R3B-41 exact supplied current candidates resolve ambiguity');
-- 42
select is((select jsonb_build_array(response->'workbench'->'source_evidence'->'weekly_menu'->>'coverage',response->'workbench'->'source_evidence'->'attendance'->>'coverage',response->'workbench'->'source_evidence'->'pantry'->>'coverage') from r3b_responses where name='chosen'),'["DOES_NOT_COVER","DOES_NOT_COVER","DOES_NOT_COVER"]'::jsonb,'R3B-42 overlap is distinct from full coverage');
-- 43
select is((atlas_api.get_planning_input_readiness_workbench(pg_temp.r3b_read('2026-11-02','2026-11-08',jsonb_build_object('weekly_menu',jsonb_build_object('weekly_menu_id','bad'))))->>'error_code'),'VALIDATION_FAILED','R3B-43 malformed typed selection fails');
-- 44
select is((atlas_api.get_planning_input_readiness_workbench(pg_temp.r3b_read('2026-11-02','2026-11-08',jsonb_build_object('weekly_menu',jsonb_build_object('weekly_menu_id','d3100000-0000-0000-0000-000000000099','weekly_menu_version',1,'weekly_menu_approval_snapshot_id','d3100000-0000-0000-0000-000000000098'))))->>'error_code'),'SOURCE_CANDIDATE_OWNERSHIP_MISMATCH','R3B-44 ownership-mismatched selection fails');

reset role;
create temporary table r3b_requests (name text primary key,request jsonb not null);
grant select,insert on r3b_requests to authenticated;

insert into r3b_requests values ('evaluate-a',pg_temp.r3b_command(
  'd3500000-0000-0000-0000-000000000001','evaluate-a','ABSENT',null,null,
  'READINESS_EVALUATION_REQUESTED',null,
  jsonb_build_object(
    'period_start','2026-11-02','period_end','2026-11-08',
    'source_candidates',jsonb_build_object(
      'weekly_menu',jsonb_build_object('weekly_menu_id','d3100000-0000-0000-0000-000000000001','weekly_menu_version',1,'weekly_menu_approval_snapshot_id','d3100000-0000-0000-0000-000000000002'),
      'attendance',jsonb_build_object('attendance_batch_id','d3200000-0000-0000-0000-000000000001','attendance_version',1,'attendance_approval_snapshot_id','d3200000-0000-0000-0000-000000000002'),
      'pantry',jsonb_build_object('pantry_need_batch_id','d3300000-0000-0000-0000-000000000001','pantry_need_batch_version',1,'pantry_need_approval_snapshot_id','d3300000-0000-0000-0000-000000000002')
    )
  )
));

set local role authenticated;
select set_config('request.jwt.claim.sub','d3000000-0000-0000-0000-000000000101',true);
insert into r3b_responses select 'evaluate-a',atlas_api.evaluate_planning_input_readiness(request) from r3b_requests where name='evaluate-a';
reset role;

-- 45
select ok((select response->>'success'='true' from r3b_responses where name='evaluate-a'),'R3B-45 first exact-period evaluation succeeds atomically');
-- 46
select is((select response->'authoritative_readback'->>'decision' from r3b_responses where name='evaluate-a'),'READY','R3B-46 nonblocking warnings retain READY');
-- 47
select is((select jsonb_build_object('version',response->'new_versions'->'current_evaluation_version','blockers',jsonb_array_length(response->'blockers'),'warnings',jsonb_array_length(response->'warnings')) from r3b_responses where name='evaluate-a'),jsonb_build_object('version',1,'blockers',0,'warnings',3),'R3B-47 backend derives version and exact issue counts');
-- 48
select is((select array_agg(issue_code order by issue_code)::text[] from atlas_planning.planning_input_evaluation_issues),array['ATTENDANCE_SCHOOL_DATE_WITHOUT_MENU','MENU_SCHOOL_DATE_WITHOUT_ATTENDANCE','ZERO_ATTENDANCE_FOR_PLANNED_MENU']::text[],'R3B-48 every-and-only warning rows are persisted');
-- 49
select is((select jsonb_build_object('roots',(select count(*) from atlas_planning.planning_input_sets),'evaluations',(select count(*) from atlas_planning.planning_input_evaluations),'issues',(select count(*) from atlas_planning.planning_input_evaluation_issues))),jsonb_build_object('roots',1,'evaluations',1,'issues',3),'R3B-49 root, evaluation, and issues persist once');
-- 50
select is((select jsonb_build_object('outcome',outcome,'expected_version',expected_version,'hash_length',length(request_hash)) from atlas_core.command_receipts where command_id='d3500000-0000-0000-0000-000000000001'),jsonb_build_object('outcome','COMPLETED','expected_version',null,'hash_length',64),'R3B-50 absent-root receipt stores nullable evaluation version and complete hash');
-- 51
select is((select jsonb_build_object('events',(select count(*) from atlas_audit.domain_events where command_id='d3500000-0000-0000-0000-000000000001'),'audits',(select count(*) from atlas_audit.audit_events where command_id='d3500000-0000-0000-0000-000000000001'))),jsonb_build_object('events',1,'audits',1),'R3B-51 successful evaluation emits one event and one audit');
-- 52
select ok((select aggregate_version is null from atlas_audit.domain_events where command_id='d3500000-0000-0000-0000-000000000001') and (select aggregate_version_before is null and aggregate_version_after is null from atlas_audit.audit_events where command_id='d3500000-0000-0000-0000-000000000001'),'R3B-52 unversioned root does not simulate aggregate versions');
-- 53
select ok((select after_summary->'source_bindings'->'weekly_menu' is not null and after_summary->'source_bindings'->'attendance' is not null and after_summary->'source_bindings'->'pantry' is not null from atlas_audit.audit_events where command_id='d3500000-0000-0000-0000-000000000001'),'R3B-53 event/audit evidence carries all exact source bindings');
-- 54
select is((select count(*)::integer from atlas_planning.need_generation_runs),0,'R3B-54 evaluation creates no Need Generation run');
-- 55
select is((select (select count(*) from atlas_planning.theoretical_need_lines)+(select count(*) from atlas_planning.confirmed_need_batches)+(select count(*) from atlas_planning.purchase_handoff_batches)),0::bigint,'R3B-55 evaluation mutates no downstream quantity or handoff fact');

set local role authenticated;
insert into r3b_responses select 'evaluate-a-replay',atlas_api.evaluate_planning_input_readiness(request) from r3b_requests where name='evaluate-a';
reset role;
-- 56
select is((select response from r3b_responses where name='evaluate-a-replay'),(select response from r3b_responses where name='evaluate-a'),'R3B-56 exact replay returns the original response');
-- 57
select is((select jsonb_build_object('receipts',(select count(*) from atlas_core.command_receipts where command_id='d3500000-0000-0000-0000-000000000001'),'events',(select count(*) from atlas_audit.domain_events where command_id='d3500000-0000-0000-0000-000000000001'),'audits',(select count(*) from atlas_audit.audit_events where command_id='d3500000-0000-0000-0000-000000000001'))),jsonb_build_object('receipts',1,'events',1,'audits',1),'R3B-57 replay creates no duplicate side effect');

do $test$
declare
  v_definition text;
begin
  select pg_get_functiondef(
    'atlas_core.rmvp_03b_source_evidence(text,date,date,jsonb)'::regprocedure
  ) into v_definition;
  execute replace(
    v_definition,
    'CREATE OR REPLACE FUNCTION atlas_core.rmvp_03b_source_evidence',
    'CREATE FUNCTION atlas_core.rmvp_03b_source_evidence_concurrency_base'
  );
end
$test$;

create or replace function atlas_core.rmvp_03b_source_evidence(
  source_kind text,
  p_period_start date,
  p_period_end date,
  supplied jsonb default null
)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = ''
as $$
declare
  v_evidence jsonb;
  v_pantry_call integer;
  v_transition text;
begin
  v_evidence := atlas_core.rmvp_03b_source_evidence_concurrency_base(
    source_kind, p_period_start, p_period_end, supplied
  );
  if source_kind <> 'PANTRY' or supplied is not null then
    return v_evidence;
  end if;
  v_pantry_call := coalesce(
    pg_catalog.current_setting('rmvp03b_test.pantry_call', true), '0'
  )::integer + 1;
  perform pg_catalog.set_config(
    'rmvp03b_test.pantry_call', v_pantry_call::text, true
  );
  v_transition := pg_catalog.current_setting(
    'rmvp03b_test.null_source_transition', true
  );
  if v_pantry_call = 2 and v_transition in ('SELECTED', 'AMBIGUOUS', 'STALE') then
    return v_evidence || pg_catalog.jsonb_build_object(
      'selection_state', v_transition,
      'safe_message', 'Simulated post-lock source transition.'
    );
  end if;
  return v_evidence;
end;
$$;

insert into r3b_requests values
  ('missing-to-selected',pg_temp.r3b_command(
    'd3500000-0000-0000-0000-000000000099','missing-to-selected','ABSENT',null,null,
    'READINESS_EVALUATION_REQUESTED',null,
    jsonb_build_object('period_start','2026-12-07','period_end','2026-12-13','source_candidates',jsonb_build_object('weekly_menu',null,'attendance',null,'pantry',null))
  )),
  ('missing-to-ambiguous',pg_temp.r3b_command(
    'd3500000-0000-0000-0000-000000000098','missing-to-ambiguous','ABSENT',null,null,
    'READINESS_EVALUATION_REQUESTED',null,
    jsonb_build_object('period_start','2026-12-14','period_end','2026-12-20','source_candidates',jsonb_build_object('weekly_menu',null,'attendance',null,'pantry',null))
  )),
  ('missing-to-stale',pg_temp.r3b_command(
    'd3500000-0000-0000-0000-000000000097','missing-to-stale','ABSENT',null,null,
    'READINESS_EVALUATION_REQUESTED',null,
    jsonb_build_object('period_start','2026-12-21','period_end','2026-12-27','source_candidates',jsonb_build_object('weekly_menu',null,'attendance',null,'pantry',null))
  ));

set local role authenticated;
select set_config('rmvp03b_test.pantry_call','0',true);
select set_config('rmvp03b_test.null_source_transition','SELECTED',true);
insert into r3b_responses select 'missing-to-selected',atlas_api.evaluate_planning_input_readiness(request) from r3b_requests where name='missing-to-selected';
select set_config('rmvp03b_test.pantry_call','0',true);
select set_config('rmvp03b_test.null_source_transition','AMBIGUOUS',true);
insert into r3b_responses select 'missing-to-ambiguous',atlas_api.evaluate_planning_input_readiness(request) from r3b_requests where name='missing-to-ambiguous';
select set_config('rmvp03b_test.pantry_call','0',true);
select set_config('rmvp03b_test.null_source_transition','STALE',true);
insert into r3b_responses select 'missing-to-stale',atlas_api.evaluate_planning_input_readiness(request) from r3b_requests where name='missing-to-stale';
reset role;

do $test$
declare
  v_definition text;
begin
  select pg_get_functiondef(
    'atlas_core.rmvp_03b_source_evidence_concurrency_base(text,date,date,jsonb)'::regprocedure
  ) into v_definition;
  execute replace(
    v_definition,
    'CREATE OR REPLACE FUNCTION atlas_core.rmvp_03b_source_evidence_concurrency_base',
    'CREATE OR REPLACE FUNCTION atlas_core.rmvp_03b_source_evidence'
  );
end
$test$;
drop function atlas_core.rmvp_03b_source_evidence_concurrency_base(text,date,date,jsonb);

set local role authenticated;
insert into r3b_responses values ('conflict',atlas_api.evaluate_planning_input_readiness(pg_temp.r3b_command('d3500000-0000-0000-0000-000000000001','changed-intent','ABSENT',null,null,'READINESS_EVALUATION_REQUESTED',null,jsonb_build_object('period_start','2026-11-02','period_end','2026-11-08','source_candidates',jsonb_build_object('weekly_menu',null,'attendance',null,'pantry',null)))));
insert into r3b_responses values ('stale-absent',atlas_api.evaluate_planning_input_readiness(pg_temp.r3b_command('d3500000-0000-0000-0000-000000000002','stale-absent','ABSENT',null,null,'READINESS_EVALUATION_REQUESTED',null,(select request->'payload' from r3b_requests where name='evaluate-a'))));
reset role;
-- 58
select is((select response->>'error_code' from r3b_responses where name='conflict'),'IDEMPOTENCY_CONFLICT','R3B-58 changed command identity reuse conflicts');
-- 59
select is(
  jsonb_build_object(
    'stale_absent_error', (select response->>'error_code' from r3b_responses where name='stale-absent'),
    'null_source_transition_errors', (
      select jsonb_object_agg(name, response->>'error_code' order by name)
      from r3b_responses
      where name in ('missing-to-selected','missing-to-ambiguous','missing-to-stale')
    ),
    'retained_effects', jsonb_build_object(
      'roots', (select count(*) from atlas_planning.planning_input_sets where period_start between '2026-12-07' and '2026-12-21'),
      'evaluations', (select count(*) from atlas_planning.planning_input_evaluations evaluation join atlas_planning.planning_input_sets input_set using (planning_input_set_id) where input_set.period_start between '2026-12-07' and '2026-12-21'),
      'receipts', (select count(*) from atlas_core.command_receipts where command_id in ('d3500000-0000-0000-0000-000000000097','d3500000-0000-0000-0000-000000000098','d3500000-0000-0000-0000-000000000099')),
      'events', (select count(*) from atlas_audit.domain_events where command_id in ('d3500000-0000-0000-0000-000000000097','d3500000-0000-0000-0000-000000000098','d3500000-0000-0000-0000-000000000099')),
      'audits', (select count(*) from atlas_audit.audit_events where command_id in ('d3500000-0000-0000-0000-000000000097','d3500000-0000-0000-0000-000000000098','d3500000-0000-0000-0000-000000000099'))
    )
  ),
  jsonb_build_object(
    'stale_absent_error', 'STALE_ROOT_STATE',
    'null_source_transition_errors', jsonb_build_object(
      'missing-to-ambiguous', 'AMBIGUOUS_SOURCE_CANDIDATE',
      'missing-to-selected', 'STALE_SOURCE_CANDIDATE',
      'missing-to-stale', 'STALE_SOURCE_CANDIDATE'
    ),
    'retained_effects', jsonb_build_object('roots',0,'evaluations',0,'receipts',0,'events',0,'audits',0)
  ),
  'R3B-59 stale root and post-lock null-source transitions fail with exact shaped errors and retain no root, evaluation, receipt, event, or audit'
);

insert into r3b_requests
select 'request-a',pg_temp.r3b_command(
  'd3500000-0000-0000-0000-000000000003','request-a','READY',
  (response->'affected_aggregate_ids'->>'planning_input_evaluation_id')::uuid,
  (response->'new_versions'->>'current_evaluation_version')::bigint,
  'NEED_GENERATION_HANDOFF_REQUESTED',null,
  jsonb_build_object('planning_input_set_id',response->'affected_aggregate_ids'->>'planning_input_set_id','period_start','2026-11-02','period_end','2026-11-08')
) from r3b_responses where name='evaluate-a';
set local role authenticated;
insert into r3b_responses select 'request-a',atlas_api.request_planning_input_need_generation(request) from r3b_requests where name='request-a';
reset role;
-- 60
select ok((select response->>'success'='true' from r3b_responses where name='request-a'),'R3B-60 handoff-only request succeeds');
-- 61
select is((select response->'authoritative_readback'->>'decision' from r3b_responses where name='request-a'),'NEED_GENERATION_REQUESTED','R3B-61 request changes only readiness status');
-- 62
select is((select jsonb_build_object('evaluations',(select count(*) from atlas_planning.planning_input_evaluations),'issues',(select count(*) from atlas_planning.planning_input_evaluation_issues),'current',(select current_evaluation_id from atlas_planning.planning_input_sets))),jsonb_build_object('evaluations',1,'issues',3,'current',(select (response->'affected_aggregate_ids'->>'planning_input_evaluation_id')::uuid from r3b_responses where name='evaluate-a')),'R3B-62 request retains immutable evaluation and issues');
-- 63
select is((select count(*)::integer from atlas_planning.need_generation_runs),0,'R3B-63 request creates no Need Generation run');

set local role authenticated;
insert into r3b_responses select 'request-a-replay',atlas_api.request_planning_input_need_generation(request) from r3b_requests where name='request-a';
insert into r3b_responses values ('request-source-payload',atlas_api.request_planning_input_need_generation((select request || jsonb_build_object('command_id','d3500000-0000-0000-0000-000000000004','idempotency_key','bad-request-source','payload',request->'payload'||jsonb_build_object('source_candidates',jsonb_build_object())) from r3b_requests where name='request-a')));
reset role;
-- 64
select is((select response from r3b_responses where name='request-a-replay'),(select response from r3b_responses where name='request-a'),'R3B-64 request replay is exact and side-effect free');
-- 65
select is((select response->>'error_code' from r3b_responses where name='request-source-payload'),'VALIDATION_FAILED','R3B-65 browser-authored source payload is rejected');

insert into r3b_requests
select 'withdraw-a',pg_temp.r3b_command(
  'd3500000-0000-0000-0000-000000000005','withdraw-a','NEED_GENERATION_REQUESTED',
  (response->'affected_aggregate_ids'->>'planning_input_evaluation_id')::uuid,
  (response->'new_versions'->>'current_evaluation_version')::bigint,
  'NEED_GENERATION_REQUEST_WITHDRAWN','Operator withdrew unconsumed handoff',
  jsonb_build_object('planning_input_set_id',response->'affected_aggregate_ids'->>'planning_input_set_id','period_start','2026-11-02','period_end','2026-11-08')
) from r3b_responses where name='request-a';
set local role authenticated;
insert into r3b_responses select 'withdraw-a',atlas_api.invalidate_planning_input_readiness(request) from r3b_requests where name='withdraw-a';
reset role;
-- 66
select ok((select response->>'success'='true' from r3b_responses where name='withdraw-a'),'R3B-66 unconsumed requested handoff can be withdrawn');
-- 67
select ok((select response->'authoritative_readback'->>'decision'='INVALIDATED' and response->'affected_aggregate_ids'->>'planning_input_evaluation_id'=(select response->'affected_aggregate_ids'->>'planning_input_evaluation_id' from r3b_responses where name='request-a') from r3b_responses where name='withdraw-a'),'R3B-67 invalidation retains the current evaluation');

insert into r3b_requests
select 'reevaluate-a2',pg_temp.r3b_command('d3500000-0000-0000-0000-000000000006','reevaluate-a2','INVALIDATED',(response->'affected_aggregate_ids'->>'planning_input_evaluation_id')::uuid,1,'READINESS_EVALUATION_REQUESTED',null,(select request->'payload' from r3b_requests where name='evaluate-a')) from r3b_responses where name='withdraw-a';
set local role authenticated;
insert into r3b_responses select 'reevaluate-a2',atlas_api.evaluate_planning_input_readiness(request) from r3b_requests where name='reevaluate-a2';
insert into r3b_responses
select 'correction-note-required',atlas_api.invalidate_planning_input_readiness(pg_temp.r3b_command('d3500000-0000-0000-0000-000000000007','correction-note-required','READY',(response->'affected_aggregate_ids'->>'planning_input_evaluation_id')::uuid,2,'PLANNING_REVIEW_CORRECTION',null,jsonb_build_object('planning_input_set_id',response->'affected_aggregate_ids'->>'planning_input_set_id','period_start','2026-11-02','period_end','2026-11-08'))) from r3b_responses where name='reevaluate-a2';
reset role;
-- 68
select ok((select response->>'success'='true' and response->'new_versions'->>'current_evaluation_version'='2' from r3b_responses where name='reevaluate-a2'),'R3B-68 INVALIDATED permits exact contiguous re-evaluation');
-- 69
select is((select response->>'error_code' from r3b_responses where name='correction-note-required'),'REASON_NOTE_REQUIRED','R3B-69 correction requires a normalized nonblank note');

insert into r3b_requests
select 'correction-a',pg_temp.r3b_command('d3500000-0000-0000-0000-000000000008','correction-a','READY',(response->'affected_aggregate_ids'->>'planning_input_evaluation_id')::uuid,2,'PLANNING_REVIEW_CORRECTION','Reviewed correction',jsonb_build_object('planning_input_set_id',response->'affected_aggregate_ids'->>'planning_input_set_id','period_start','2026-11-02','period_end','2026-11-08')) from r3b_responses where name='reevaluate-a2';
set local role authenticated;
insert into r3b_responses select 'correction-a',atlas_api.invalidate_planning_input_readiness(request) from r3b_requests where name='correction-a';
reset role;
-- 70
select ok((select response->>'success'='true' from r3b_responses where name='correction-a'),'R3B-70 reviewed correction invalidates READY');

insert into r3b_requests
select 'reevaluate-a3',pg_temp.r3b_command('d3500000-0000-0000-0000-000000000009','reevaluate-a3','INVALIDATED',(response->'affected_aggregate_ids'->>'planning_input_evaluation_id')::uuid,2,'READINESS_EVALUATION_REQUESTED',null,(select request->'payload' from r3b_requests where name='evaluate-a')) from r3b_responses where name='correction-a';
set local role authenticated;
insert into r3b_responses select 'reevaluate-a3',atlas_api.evaluate_planning_input_readiness(request) from r3b_requests where name='reevaluate-a3';
insert into r3b_responses
select 'upstream-mismatch',atlas_api.invalidate_planning_input_readiness(pg_temp.r3b_command('d3500000-0000-0000-0000-000000000010','upstream-mismatch','READY',(response->'affected_aggregate_ids'->>'planning_input_evaluation_id')::uuid,3,'UPSTREAM_SOURCE_CHANGED',null,jsonb_build_object('planning_input_set_id',response->'affected_aggregate_ids'->>'planning_input_set_id','period_start','2026-11-02','period_end','2026-11-08'))) from r3b_responses where name='reevaluate-a3';
reset role;
-- 71
select ok((select response->>'success'='true' and response->'new_versions'->>'current_evaluation_version'='3' from r3b_responses where name='reevaluate-a3'),'R3B-71 evaluation history remains contiguous after correction');
-- 72
select is((select response->>'error_code' from r3b_responses where name='upstream-mismatch'),'INVALIDATION_REASON_MISMATCH','R3B-72 upstream-change reason requires backend proof');

set session_replication_role = replica;
update atlas_planning.weekly_menus set weekly_menu_status='REOPENED' where weekly_menu_id='d3100000-0000-0000-0000-000000000001';
set session_replication_role = origin;
insert into r3b_requests
select 'upstream-a',pg_temp.r3b_command('d3500000-0000-0000-0000-000000000011','upstream-a','READY',(response->'affected_aggregate_ids'->>'planning_input_evaluation_id')::uuid,3,'UPSTREAM_SOURCE_CHANGED',null,jsonb_build_object('planning_input_set_id',response->'affected_aggregate_ids'->>'planning_input_set_id','period_start','2026-11-02','period_end','2026-11-08')) from r3b_responses where name='reevaluate-a3';
set local role authenticated;
insert into r3b_responses select 'upstream-a',atlas_api.invalidate_planning_input_readiness(request) from r3b_requests where name='upstream-a';
insert into r3b_responses values ('stale-read',atlas_api.get_planning_input_readiness_workbench(pg_temp.r3b_read('2026-11-02','2026-11-08',jsonb_build_object('weekly_menu',jsonb_build_object('weekly_menu_id','d3100000-0000-0000-0000-000000000001','weekly_menu_version',1,'weekly_menu_approval_snapshot_id','d3100000-0000-0000-0000-000000000002')))));
reset role;
-- 73
select ok((select response->>'success'='true' and response->'authoritative_readback'->>'decision'='INVALIDATED' from r3b_responses where name='upstream-a'),'R3B-73 proven source change invalidates readiness');
-- 74
select ok((select response->'workbench'->'source_evidence'->'weekly_menu'->>'selection_state'='STALE' and not (response->'workbench'->'allowed_actions'->>'can_evaluate')::boolean from r3b_responses where name='stale-read'),'R3B-74 stale prior-read selection is displayed and disables evaluation');

insert into r3b_requests values ('evaluate-b',pg_temp.r3b_command(
  'd3500000-0000-0000-0000-000000000012','evaluate-b','ABSENT',null,null,
  'READINESS_EVALUATION_REQUESTED',null,
  jsonb_build_object(
    'period_start','2026-11-09','period_end','2026-11-15',
    'source_candidates',jsonb_build_object(
      'weekly_menu',jsonb_build_object('weekly_menu_id','d3100000-0000-0000-0000-000000000011','weekly_menu_version',1,'weekly_menu_approval_snapshot_id','d3100000-0000-0000-0000-000000000012'),
      'attendance',jsonb_build_object('attendance_batch_id','d3200000-0000-0000-0000-000000000011','attendance_version',1,'attendance_approval_snapshot_id','d3200000-0000-0000-0000-000000000012'),
      'pantry',jsonb_build_object('pantry_need_batch_id','d3300000-0000-0000-0000-000000000011','pantry_need_batch_version',1,'pantry_need_approval_snapshot_id','d3300000-0000-0000-0000-000000000012')
    )
  )
));
set local role authenticated;
insert into r3b_responses select 'evaluate-b',atlas_api.evaluate_planning_input_readiness(request) from r3b_requests where name='evaluate-b';
reset role;
-- 75
select ok((select response->>'success'='true' and response->'authoritative_readback'->>'decision'='READY' and response->'authoritative_readback'->'source_evidence'->'pantry'->>'pantry_evidence_kind'='POSITIVE_LINES' and response->'authoritative_readback'->'source_evidence'->'pantry'->'selected'->>'line_count'='1' from r3b_responses where name='evaluate-b'),'R3B-75 positive Pantry evidence produces a READY second period');

insert into r3b_requests
select 'request-b',pg_temp.r3b_command(
  'd3500000-0000-0000-0000-000000000013','request-b','READY',
  (response->'affected_aggregate_ids'->>'planning_input_evaluation_id')::uuid,1,
  'NEED_GENERATION_HANDOFF_REQUESTED',null,
  jsonb_build_object('planning_input_set_id',response->'affected_aggregate_ids'->>'planning_input_set_id','period_start','2026-11-09','period_end','2026-11-15')
) from r3b_responses where name='evaluate-b';
set local role authenticated;
insert into r3b_responses select 'request-b',atlas_api.request_planning_input_need_generation(request) from r3b_requests where name='request-b';
reset role;
-- 76
select ok((select response->>'success'='true' and response->'authoritative_readback'->>'decision'='NEED_GENERATION_REQUESTED' from r3b_responses where name='request-b') and (select count(*) from atlas_planning.need_generation_runs)=0,'R3B-76 second handoff request remains marker-only');

set session_replication_role = replica;
insert into atlas_planning.need_generation_runs (
  need_generation_run_id,planning_input_set_id,planning_input_evaluation_id,
  evaluation_version,period_start,period_end,attempt_ordinal,
  input_snapshot_id,run_status,version,generated_line_count,
  blocking_issue_count,warning_count,generated_by_actor_id,generated_at,updated_at
)
select 'd3600000-0000-0000-0000-000000000001',
  (response->'affected_aggregate_ids'->>'planning_input_set_id')::uuid,
  (response->'affected_aggregate_ids'->>'planning_input_evaluation_id')::uuid,
  1,'2026-11-09','2026-11-15',1,
  'd3600000-0000-0000-0000-000000000002','GENERATED',1,0,0,0,
  'd3000000-0000-0000-0000-000000000001',transaction_timestamp(),transaction_timestamp()
from r3b_responses where name='request-b';
set session_replication_role = origin;

insert into r3b_requests
select 'withdraw-b-generated',pg_temp.r3b_command(
  'd3500000-0000-0000-0000-000000000014','withdraw-b-generated','NEED_GENERATION_REQUESTED',
  (response->'affected_aggregate_ids'->>'planning_input_evaluation_id')::uuid,1,
  'NEED_GENERATION_REQUEST_WITHDRAWN','Withdraw generated handoff',
  jsonb_build_object('planning_input_set_id',response->'affected_aggregate_ids'->>'planning_input_set_id','period_start','2026-11-09','period_end','2026-11-15')
) from r3b_responses where name='request-b';
set local role authenticated;
insert into r3b_responses select 'withdraw-b-generated',atlas_api.invalidate_planning_input_readiness(request) from r3b_requests where name='withdraw-b-generated';
reset role;
-- 77
select is((select response->>'error_code' from r3b_responses where name='withdraw-b-generated'),'NEED_GENERATION_HANDOFF_ALREADY_CONSUMED','R3B-77 GENERATED run proves the handoff is consumed');

set session_replication_role = replica;
update atlas_planning.need_generation_runs set run_status='INVALIDATED',version=2,invalidated_by_actor_id='d3000000-0000-0000-0000-000000000001',invalidated_at=transaction_timestamp(),updated_at=transaction_timestamp() where need_generation_run_id='d3600000-0000-0000-0000-000000000001';
set session_replication_role = origin;
insert into r3b_requests
select 'withdraw-b-invalidated',request || jsonb_build_object('command_id','d3500000-0000-0000-0000-000000000015','correlation_id',gen_random_uuid(),'idempotency_key','withdraw-b-invalidated') from r3b_requests where name='withdraw-b-generated';
set local role authenticated;
insert into r3b_responses select 'withdraw-b-invalidated',atlas_api.invalidate_planning_input_readiness(request) from r3b_requests where name='withdraw-b-invalidated';
reset role;
-- 78
select is((select response->>'error_code' from r3b_responses where name='withdraw-b-invalidated'),'NEED_GENERATION_HANDOFF_ALREADY_CONSUMED','R3B-78 INVALIDATED run still proves consumption');

set session_replication_role = replica;
update atlas_planning.need_generation_runs set run_status='RELEASED_FOR_CONFIRMATION',version=3,validated_by_actor_id='d3000000-0000-0000-0000-000000000001',validated_at=transaction_timestamp(),released_by_actor_id='d3000000-0000-0000-0000-000000000001',released_at=transaction_timestamp(),invalidated_by_actor_id=null,invalidated_at=null,updated_at=transaction_timestamp() where need_generation_run_id='d3600000-0000-0000-0000-000000000001';
set session_replication_role = origin;
insert into r3b_requests
select 'withdraw-b-released',request || jsonb_build_object('command_id','d3500000-0000-0000-0000-000000000016','correlation_id',gen_random_uuid(),'idempotency_key','withdraw-b-released') from r3b_requests where name='withdraw-b-generated';
set local role authenticated;
insert into r3b_responses select 'withdraw-b-released',atlas_api.invalidate_planning_input_readiness(request) from r3b_requests where name='withdraw-b-released';
reset role;
-- 79
select is((select response->>'error_code' from r3b_responses where name='withdraw-b-released'),'NEED_GENERATION_HANDOFF_ALREADY_CONSUMED','R3B-79 RELEASED run still proves consumption');

insert into r3b_requests
select 'correction-b',pg_temp.r3b_command(
  'd3500000-0000-0000-0000-000000000017','correction-b','NEED_GENERATION_REQUESTED',
  (response->'affected_aggregate_ids'->>'planning_input_evaluation_id')::uuid,1,
  'PLANNING_REVIEW_CORRECTION','Correction after consumed handoff',
  jsonb_build_object('planning_input_set_id',response->'affected_aggregate_ids'->>'planning_input_set_id','period_start','2026-11-09','period_end','2026-11-15')
) from r3b_responses where name='request-b';
set local role authenticated;
insert into r3b_responses select 'correction-b',atlas_api.invalidate_planning_input_readiness(request) from r3b_requests where name='correction-b';
reset role;
-- 80
select ok((select response->>'success'='true' and response->'authoritative_readback'->>'decision'='INVALIDATED' from r3b_responses where name='correction-b') and (select run_status='RELEASED_FOR_CONFIRMATION' and version=3 from atlas_planning.need_generation_runs where need_generation_run_id='d3600000-0000-0000-0000-000000000001'),'R3B-80 correction may invalidate readiness without mutating a consumed run');

set local role authenticated;
insert into r3b_responses values ('history-b-1',atlas_api.get_planning_input_readiness_workbench(pg_temp.r3b_read('2026-11-09','2026-11-15',null,1,null)));
insert into r3b_responses
select 'history-b-2',atlas_api.get_planning_input_readiness_workbench(pg_temp.r3b_read('2026-11-09','2026-11-15',null,1,response->'workbench'->>'history_next_cursor')) from r3b_responses where name='history-b-1';
insert into r3b_responses
select 'history-b-3',atlas_api.get_planning_input_readiness_workbench(pg_temp.r3b_read('2026-11-09','2026-11-15',null,1,response->'workbench'->>'history_next_cursor')) from r3b_responses where name='history-b-2';
reset role;
-- 81
select ok((select response->>'success'='true' and response->'workbench'->>'decision'='INVALIDATED' and (response->'workbench'->>'history_has_more')::boolean and response->'workbench'->>'history_next_cursor' is not null and jsonb_array_length(response->'workbench'->'history_items')=1 from r3b_responses where name='history-b-1'),'R3B-81 first bounded page returns current state plus opaque continuation');
-- 82
select ok((select response->>'success'='true' and jsonb_array_length(response->'workbench'->'history_items')=1 from r3b_responses where name='history-b-2') and (select a.response->'workbench'->'history_items'->0->>'history_item_id' <> b.response->'workbench'->'history_items'->0->>'history_item_id' from r3b_responses a cross join r3b_responses b where a.name='history-b-1' and b.name='history-b-2'),'R3B-82 keyset continuation returns no duplicate');
-- 83
select is((select jsonb_build_array(a.response->'workbench'->'history_items'->0->>'history_kind',b.response->'workbench'->'history_items'->0->>'history_kind',c.response->'workbench'->'history_items'->0->>'history_kind') from r3b_responses a cross join r3b_responses b cross join r3b_responses c where a.name='history-b-1' and b.name='history-b-2' and c.name='history-b-3'),'["EVALUATION","NEED_GENERATION_REQUEST","INVALIDATION"]'::jsonb,'R3B-83 combined history uses fixed evaluation/request/invalidation tie order');
-- 84
select is((select jsonb_build_object('manual_runs',(select count(*) from atlas_planning.need_generation_runs),'theoretical_lines',(select count(*) from atlas_planning.theoretical_need_lines),'confirmed_batches',(select count(*) from atlas_planning.confirmed_need_batches),'purchase_handoffs',(select count(*) from atlas_planning.purchase_handoff_batches))),jsonb_build_object('manual_runs',1,'theoretical_lines',0,'confirmed_batches',0,'purchase_handoffs',0),'R3B-84 readiness APIs create no downstream run, quantity, confirmation, or purchase fact');

select * from finish();
rollback;
