begin;
create extension if not exists pgtap with schema extensions;
set local search_path=extensions,public;
grant usage on schema extensions to authenticated;
grant execute on all functions in schema extensions to authenticated;
select plan(37);

select is(atlas_core.pantry_v4_rows('[]'), '[]'::jsonb,
  'v4 accepts an explicit empty row set without inventing demand');
select is(atlas_core.pantry_v4_rows('[{"note":" \t "}]')->0->'note', 'null'::jsonb,
  'optional whitespace notes normalize to null');
select is(atlas_core.pantry_v4_rows('[{"note":"  Giao cổng phụ  "}]')->0->>'note',
  'Giao cổng phụ', 'meaningful line notes are retained');
select is(atlas_core.pantry_v4_rows('[{}]')->0->>'pantry_need_purpose_id',
  '3c3de399-b88f-575a-a3ce-eff9e16deb55', 'classification is fixed by the backend');
select ok(atlas_core.pantry_v4_rows('[{"pantry_need_purpose_id":null}]') is null,
  'even a null client Purpose authority field is rejected');
select ok(atlas_core.pantry_v4_rows('[{"unit_id":"spoof"}]') is null,
  'client Unit authority remains forbidden');
select ok(atlas_core.pantry_v4_rows('[{"delivery_location_id":"spoof"}]') is null,
  'client Location authority remains forbidden');
select is(jsonb_array_length(atlas_core.pantry_v4_rows('[{},{}]')), 2,
  'normalization preserves duplicate-row multiplicity for canonical validation');
select ok(atlas_core.pantry_v4_source_payload('WEEKLY_MENU',
  '{"source_contract_version":"PANTRY-02.v4","rows":[]}') is null,
  'v4 marker is forbidden on another source kind');
select ok(atlas_core.pantry_v4_source_payload('PANTRY',
  '{"source_contract_version":"PANTRY-02.v3","rows":[]}') is null,
  'unknown or mixed source markers fail closed');
select is(atlas_core.pantry_v4_source_payload('PANTRY',
  '{"source_contract_version":"PANTRY-02.v4","rows":[{"note":" "}]}')->'rows',
  atlas_core.pantry_v4_rows('[{"note":" "}]'),
  'impact uses the exact same normalized raw rows as preview and Save');
select ok(not has_function_privilege('authenticated',
    'atlas_core.pantry_v4_rows(jsonb)', 'EXECUTE')
  and not has_function_privilege('anon',
    'atlas_core.pantry_v4_source_payload(text,jsonb)', 'EXECUTE')
  and not has_function_privilege('service_role',
    'atlas_core.pantry_v4_rows(jsonb)', 'EXECUTE'),
  'normalizers are private backend helpers');


-- Reference-only fixture shared in substance with Pantry v1 acceptance.
insert into atlas_core.actors (
  actor_id,
  actor_type,
  display_name
) values
  (
    'a7200000-0000-0000-0000-000000000010',
    'HUMAN',
    'PANTRY-02 authorized operator'
  ),
  (
    'a7200000-0000-0000-0000-000000000011',
    'HUMAN',
    'PANTRY-02 denied operator'
  );

insert into atlas_core.actor_auth_subjects (
  actor_auth_subject_id,
  actor_id,
  auth_subject_id
) values
  (
    'a7200000-0000-0000-0000-000000000012',
    'a7200000-0000-0000-0000-000000000010',
    'a7200000-0000-0000-0000-000000000110'
  ),
  (
    'a7200000-0000-0000-0000-000000000013',
    'a7200000-0000-0000-0000-000000000011',
    'a7200000-0000-0000-0000-000000000111'
  );

insert into atlas_core.roles (
  role_id,
  role_code,
  role_name
) values
  (
    'a7200000-0000-0000-0000-000000000014',
    'pantry02.test_operator',
    'PANTRY-02 test operator'
  ),
  (
    'a7200000-0000-0000-0000-000000000015',
    'pantry02.test_denied',
    'PANTRY-02 denied test operator'
  );

insert into atlas_core.role_capabilities (role_id, capability_id)
select
  'a7200000-0000-0000-0000-000000000014',
  capability.capability_id
from atlas_core.capabilities capability
where capability.capability_code in (
  'planning.inputs.read',
  'planning.inputs.approve',
  'planning.pantry.write'
);

insert into atlas_core.actor_role_memberships (actor_id, role_id) values
  (
    'a7200000-0000-0000-0000-000000000010',
    'a7200000-0000-0000-0000-000000000014'
  ),
  (
    'a7200000-0000-0000-0000-000000000011',
    'a7200000-0000-0000-0000-000000000015'
  );

insert into atlas_core.actor_scopes (actor_id, scope_kind) values
  ('a7200000-0000-0000-0000-000000000010', 'GLOBAL'),
  ('a7200000-0000-0000-0000-000000000011', 'GLOBAL');

insert into atlas_admin.customers (
  customer_id,
  customer_code,
  customer_name,
  customer_type
) values
  (
    'a7200000-0000-0000-0000-000000000020',
    'pantry02-school-customer',
    'PANTRY-02 School Customer',
    'SCHOOL_CATERING'
  ),
  (
    'a7200000-0000-0000-0000-000000000021',
    'pantry02-inactive-customer',
    'PANTRY-02 Inactive School Customer',
    'SCHOOL_CATERING'
  );

insert into atlas_admin.delivery_locations (
  delivery_location_id,
  customer_id,
  location_code,
  location_name,
  address_text
) values
  (
    'a7200000-0000-0000-0000-000000000022',
    'a7200000-0000-0000-0000-000000000020',
    'pantry02-default',
    'PANTRY-02 Default Kitchen',
    'PANTRY-02 default address'
  ),
  (
    'a7200000-0000-0000-0000-000000000023',
    'a7200000-0000-0000-0000-000000000020',
    'pantry02-alternative',
    'PANTRY-02 Alternative Kitchen',
    'PANTRY-02 alternative address'
  ),
  (
    'a7200000-0000-0000-0000-000000000024',
    'a7200000-0000-0000-0000-000000000021',
    'pantry02-inactive-customer-location',
    'PANTRY-02 Inactive Customer Location',
    'PANTRY-02 inactive customer address'
  );

insert into atlas_admin.school_types (
  school_type_id,
  school_type_code,
  school_type_name
) values (
  'a7200000-0000-0000-0000-000000000025',
  'pantry02-primary',
  'PANTRY-02 Primary'
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
    'a7200000-0000-0000-0000-000000000026',
    'a7200000-0000-0000-0000-000000000020',
    'pantry02-school',
    'PANTRY-02 School',
    'a7200000-0000-0000-0000-000000000025',
    'a7200000-0000-0000-0000-000000000022',
    1,
    100,
    10
  ),
  (
    'a7200000-0000-0000-0000-000000000027',
    'a7200000-0000-0000-0000-000000000021',
    'pantry02-inactive-customer-school',
    'PANTRY-02 Inactive Customer School',
    'a7200000-0000-0000-0000-000000000025',
    'a7200000-0000-0000-0000-000000000024',
    2,
    100,
    10
  );

update atlas_admin.customers
set
  customer_status = 'INACTIVE',
  updated_at = transaction_timestamp()
where customer_id = 'a7200000-0000-0000-0000-000000000021';

insert into atlas_admin.units (
  unit_id,
  unit_code,
  unit_name,
  dimension_code,
  decimal_scale
) values
  (
    'a7200000-0000-0000-0000-000000000030',
    'pantry02-kg',
    'PANTRY-02 kilogram',
    'MASS',
    6
  ),
  (
    'a7200000-0000-0000-0000-000000000031',
    'pantry02-each',
    'PANTRY-02 each',
    'COUNT',
    0
  );

insert into atlas_admin.ingredients (
  ingredient_id,
  ingredient_code,
  ingredient_name,
  ingredient_group,
  purchase_unit_id,
  ingredient_type,
  shopping_type,
  order_step
) values
  (
    'a7200000-0000-0000-0000-000000000032',
    'pantry02-rice',
    'PANTRY-02 Rice',
    'Food',
    'a7200000-0000-0000-0000-000000000030',
    'Food',
    'Planned',
    1
  ),
  (
    'a7200000-0000-0000-0000-000000000033',
    'pantry02-eggs',
    'PANTRY-02 Eggs',
    'Food',
    'a7200000-0000-0000-0000-000000000031',
    'Food',
    'Planned',
    1
  );

create or replace function pg_temp.pantry02_read(
  payload jsonb,
  subject uuid default 'a7200000-0000-0000-0000-000000000110'
)
returns jsonb
language sql
as $$
  select jsonb_build_object(
    'contract_version', 'PANTRY-02.v1',
    'requested_by_auth_subject', subject,
    'correlation_id', 'a7200000-0000-0000-0000-000000000120',
    'payload', payload
  );
$$;

create or replace function pg_temp.pantry02_command(
  command_name text,
  expected_version bigint,
  payload jsonb,
  note text default 'Rolled-back PANTRY-02 acceptance test.'
)
returns jsonb
language sql
as $$
  select jsonb_build_object(
    'contract_version', 'PANTRY-02.v1',
    'command_id', md5('pantry02-command:' || command_name)::uuid,
    'correlation_id', 'a7200000-0000-0000-0000-000000000121',
    'idempotency_key', 'pantry02:' || command_name,
    'expected_version', expected_version,
    'requested_by_auth_subject',
      'a7200000-0000-0000-0000-000000000110',
    'requested_at', transaction_timestamp() - interval '1 second',
    'reason_code', 'PANTRY02_TEST',
    'reason_note', note,
    'payload', payload
  );
$$;

-- V4 public journey follows the unchanged v1 history/permission assertions.
update atlas_core.actor_scopes set scope_status='ACTIVE'
where actor_id='a7200000-0000-0000-0000-000000000010' and scope_kind='GLOBAL';
insert into atlas_core.role_capabilities(role_id,capability_id)
select 'a7200000-0000-0000-0000-000000000014',capability_id from atlas_core.capabilities
where capability_code like 'planning.%' or capability_code like 'confirmed_need%' or capability_code like 'procurement.%'
on conflict do nothing;
create temp table p4_requests(name text primary key,request jsonb);
create temp table p4_results(name text primary key,response jsonb);
grant select,insert,update on p4_requests,p4_results to authenticated;
create function pg_temp.p4_payload(quantity text) returns jsonb language sql as $$
 select jsonb_build_object('week_start','2026-08-24','no_additions_confirmed',false,
 'rows',jsonb_build_array(jsonb_build_object('service_date','2026-08-24',
 'school_id','a7200000-0000-0000-0000-000000000026',
 'ingredient_id','a7200000-0000-0000-0000-000000000032',
 'requested_quantity',quantity,'note',E' \t\n ', 'source_row_reference','v4:1')),
 'school_date_modes',jsonb_build_array(jsonb_build_object(
 'school_id','a7200000-0000-0000-0000-000000000026','service_date','2026-08-24','direct_need_mode','COMPLETE')));
$$;
create function pg_temp.p4_request(name text,version bigint,payload jsonb,contract text default 'PANTRY-02.v4')
returns jsonb language sql as $$
 select pg_temp.pantry02_command('v4:'||name,version,payload)||jsonb_build_object(
 'contract_version',contract,'reason_note',case when contract in ('RMVP-05.v2','RMVP-07.v2') then null else 'Rolled-back PANTRY-02 acceptance test.' end,'reason_code',case contract when 'RMVP-04.v3' then 'NEED_GENERATION_EXECUTED'
 when 'RMVP-05.v2' then 'CONFIRMED_NEED_SAVED' when 'RMVP-07.v2' then 'CONFIRMED_NEED_RELEASED' else 'PANTRY_SAVED' end);
$$;
-- Same approved calculation-contract fixture as atlas_zero_demand_generation_policy.sql.
insert into atlas_planning.need_generation_calculation_contracts(need_generation_calculation_contract_id,contract_code,current_revision_id,version)
values('a7200000-0000-4000-8000-000000000082','school_catering_proportional_per_basis','a7200000-0000-4000-8000-000000000083',1);
insert into atlas_planning.need_generation_calculation_contract_revisions(need_generation_calculation_contract_revision_id,need_generation_calculation_contract_id,revision_number,formula_kind,quantity_precision,quantity_scale,factor_precision,factor_scale,final_coercion_mode,approved_by_actor_id,approved_at)
values('a7200000-0000-4000-8000-000000000083','a7200000-0000-4000-8000-000000000082',1,'STUDENT_TEACHER_PORTIONS_X_RECIPE_QTY_DIV_BASIS',20,6,24,12,'POSTGRES_NUMERIC_SCALE_HALF_AWAY_FROM_ZERO','a7200000-0000-0000-0000-000000000010',now());
insert into atlas_planning.planning_quantity_policies(planning_quantity_policy_id,unit_id,created_by_actor_id)
select 'a7200000-0000-4000-8000-000000000080',purchase_unit_id,'a7200000-0000-0000-0000-000000000010'
from atlas_admin.ingredients where ingredient_id='a7200000-0000-0000-0000-000000000032';
insert into atlas_planning.planning_quantity_policy_revisions(planning_quantity_policy_revision_id,planning_quantity_policy_id,unit_id,
 revision_number,planning_step,effective_from,policy_revision_status,created_by_actor_id)
select 'a7200000-0000-4000-8000-000000000081',planning_quantity_policy_id,unit_id,1,0.000001,'2020-01-01','DRAFT','a7200000-0000-0000-0000-000000000010'
from atlas_planning.planning_quantity_policies where planning_quantity_policy_id='a7200000-0000-4000-8000-000000000080';
update atlas_planning.planning_quantity_policy_revisions set policy_revision_status='ACTIVE',approved_by_actor_id='a7200000-0000-0000-0000-000000000010',approved_at=now(),
activated_by_actor_id='a7200000-0000-0000-0000-000000000010',activated_at=now() where planning_quantity_policy_revision_id='a7200000-0000-4000-8000-000000000081';
set constraints all immediate;
set constraints all deferred;

set local role authenticated;
select set_config('request.jwt.claim.sub','a7200000-0000-0000-0000-000000000110',true);
insert into p4_results values('preview1',atlas_api.preview_pantry_source(
 pg_temp.pantry02_read(pg_temp.p4_payload('2.500001'))||'{"contract_version":"PANTRY-02.v4"}'));
select is((select response#>>'{preview,can_save}' from p4_results where name='preview1'),'true','v4 purpose-free whitespace-note preview is eligible');
insert into p4_requests select 'save1',pg_temp.p4_request('save1',1,pg_temp.p4_payload('2.500001')||jsonb_build_object(
 'source_signature',response#>>'{preview,source_signature}','expected_source_signature',null)) from p4_results where name='preview1';
insert into p4_results select 'impact1',atlas_api.get_planning_source_correction_impact(
 jsonb_build_object('contract_version','PLANNING-CORRECTION.v1','requested_by_auth_subject','a7200000-0000-0000-0000-000000000110',
 'correlation_id',gen_random_uuid(),'payload',jsonb_build_object('source_kind','PANTRY',
 'source_payload',(request->'payload')||'{"source_contract_version":"PANTRY-02.v4"}'))) from p4_requests where name='save1';
select is((select response#>'{impact,affected_service_dates}' from p4_results where name='impact1'),'["2026-08-24"]'::jsonb,'v4 impact dates bind the same School/date proposal');
insert into p4_results select 'save1',atlas_api.save_pantry(request) from p4_requests where name='save1';
set constraints all immediate;
set constraints all deferred;
select is((select response->>'success' from p4_results where name='save1'),'true','v4 blank-note source saves through the public atomic command');
select diag(response::text) from p4_results where name='save1' and response->>'success'<>'true';
reset role;
select ok((select bool_and(l.note is null and l.pantry_need_purpose_id='3c3de399-b88f-575a-a3ce-eff9e16deb55'
 and l.requested_quantity=2.500001 and l.school_id='a7200000-0000-0000-0000-000000000026'
 and l.delivery_location_id=s.default_delivery_location_id and l.unit_id=i.purchase_unit_id)
 from atlas_planning.pantry_need_lines l join atlas_planning.pantry_need_batches b using(pantry_need_batch_id)
 join atlas_admin.schools s using(school_id) join atlas_admin.ingredients i using(ingredient_id)
 where b.week_start='2026-08-24'), 'v4 persists exact quantities and server-derived scope/Unit with optional null note');
select is((select b.source_signature from atlas_planning.pantry_need_batches b where b.week_start='2026-08-24'),
 (select response#>>'{preview,source_signature}' from p4_results where name='preview1'),'preview and saved signature agree exactly');
select ok((select count(*)=1 and bool_and(l.note is null and l.requested_quantity=2.500001
 and l.pantry_need_purpose_id='3c3de399-b88f-575a-a3ce-eff9e16deb55')
 from atlas_planning.pantry_need_approval_snapshot_lines l),
 'first immutable snapshot captures the exact v4 quantity and null note');
create temp table p4_first_snapshot as select to_jsonb(s) snapshot from atlas_planning.pantry_need_approval_snapshots s;
create temp table p4_first_lines as select to_jsonb(s) snapshot from atlas_planning.pantry_need_approval_snapshot_lines s;
set local role authenticated;
insert into p4_results values('preview2',atlas_api.preview_pantry_source(
 pg_temp.pantry02_read(pg_temp.p4_payload('3.500001'))||'{"contract_version":"PANTRY-02.v4"}'));
reset role;
insert into p4_requests select 'save2',pg_temp.p4_request('save2',b.version,pg_temp.p4_payload('3.500001')||jsonb_build_object(
 'source_signature',p.response#>>'{preview,source_signature}','expected_source_signature',b.source_signature))
 from atlas_planning.pantry_need_batches b cross join p4_results p where b.week_start='2026-08-24' and p.name='preview2';
set local role authenticated;
insert into p4_results select 'save2',atlas_api.save_pantry(request) from p4_requests where name='save2';
set constraints all immediate;
set constraints all deferred;
select is((select response->>'success' from p4_results where name='save2'),'true','a later distinct v4 Source Save completes');
reset role;
select ok((select count(*) from p4_first_snapshot)=1 and not exists(select snapshot from p4_first_snapshot except select to_jsonb(s) from atlas_planning.pantry_need_approval_snapshots s) and not exists(select snapshot from p4_first_lines except select to_jsonb(s) from atlas_planning.pantry_need_approval_snapshot_lines s),'later v4 Save preserves the actual first immutable approval snapshot and lines');
set local role authenticated;
insert into p4_results select 'stale',atlas_api.save_pantry(jsonb_set(jsonb_set(request,'{command_id}',to_jsonb(gen_random_uuid())),
'{idempotency_key}','"v4:stale-new-intent"')) from p4_requests where name='save1';
select is((select response->>'error_code' from p4_results where name='stale'),'STALE_VERSION','new stale intent retains version rejection');
reset role;
-- A real COMPLETE source generates and releases current Need, making the old
-- proposal impactful. Replay must resolve its original receipt first.
set local role authenticated;
insert into p4_results values('generate',atlas_api.execute_need_generation(pg_temp.p4_request('generate',1,
jsonb_build_object('service_date','2026-08-24','expected_current_need_generation_run_id',null),'RMVP-04.v3')));
set constraints all immediate;
set constraints all deferred;
select is((select response->>'success' from p4_results where name='generate'),'true','later Source Save creates genuine current Need');
select diag(response::text) from p4_results where name='generate' and response->>'success'<>'true';
reset role;
insert into p4_requests select 'confirm',pg_temp.p4_request('confirm',b.version,jsonb_build_object('confirmed_need_batch_id',b.confirmed_need_batch_id,
'lines',jsonb_agg(jsonb_build_object('confirmed_need_line_id',l.confirmed_need_line_id,
'expected_current_revision_id',r.confirmed_need_line_revision_id,'expected_current_decision_id',l.current_confirmed_need_line_decision_id,
'proposed_confirmed_quantity',r.confirmed_quantity::text,'reason_code','PROPOSAL_ACCEPTED','reason_note',null))),'RMVP-05.v2')
from atlas_planning.confirmed_need_batches b join atlas_planning.confirmed_need_lines l using(confirmed_need_batch_id)
join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_id)
where b.period_start='2026-08-24' and r.is_current group by b.confirmed_need_batch_id,b.version;
set local role authenticated;
insert into p4_results select 'confirm',atlas_api.save_confirmed_needs(request) from p4_requests where name='confirm';
set constraints all immediate;
set constraints all deferred;
select is((select response->>'success' from p4_results where name='confirm'),'true','current Need is explicitly confirmed');
reset role;
insert into p4_requests select 'release',pg_temp.p4_request('release',version,
jsonb_build_object('confirmed_need_batch_id',confirmed_need_batch_id),'RMVP-07.v2')
from atlas_planning.confirmed_need_batches where period_start='2026-08-24';
set local role authenticated;
insert into p4_results select 'release',atlas_api.release_confirmed_needs(request) from p4_requests where name='release';
set constraints all immediate;
set constraints all deferred;
select is((select response->>'success' from p4_results where name='release'),'true','later current Need is genuinely released');
select diag(response::text) from p4_results where name='release' and response->>'success'<>'true';
reset role;
create temp table p4_receipts as select to_jsonb(r) receipt from atlas_core.command_receipts r;
set local role authenticated;
insert into p4_results select 'replay',atlas_api.save_pantry(request) from p4_requests where name='save1';
select is((select response from p4_results where name='replay'),(select response from p4_results where name='save1'),'exact v4 replay after later Source Save and released Need returns original durable response');
insert into p4_results select 'conflict',atlas_api.save_pantry(jsonb_set(request,'{payload,rows,0,requested_quantity}','"9"')) from p4_requests where name='save1';
select is((select response->>'error_code' from p4_results where name='conflict'),'IDEMPOTENCY_CONFLICT','changed content under original identity conflicts before mutable impact');
insert into p4_results select 'key-conflict',atlas_api.save_pantry(jsonb_set(request,'{command_id}',to_jsonb(gen_random_uuid()))) from p4_requests where name='save1';
select is((select response->>'error_code' from p4_results where name='key-conflict'),'IDEMPOTENCY_CONFLICT','changed command under an existing scoped idempotency key conflicts');
insert into p4_results select 'spoof',atlas_api.preview_pantry_source(pg_temp.pantry02_read(
jsonb_set(pg_temp.p4_payload('2'),'{rows,0,pantry_need_purpose_id}','null'))||'{"contract_version":"PANTRY-02.v4"}');
select is((select response->>'error_code' from p4_results where name='spoof'),'VALIDATION_FAILED','v4 rejects a client-authored Purpose even null');
insert into p4_results select 'denied',atlas_api.save_pantry(jsonb_set(request,'{requested_by_auth_subject}','"a7200000-0000-0000-0000-000000000111"')) from p4_requests where name='save1';
select is((select response->>'error_code' from p4_results where name='denied'),'AUTH_SUBJECT_MISMATCH','receipt responses remain behind authenticated-subject binding');
select set_config('request.jwt.claim.sub','a7200000-0000-0000-0000-000000000111',true);
insert into p4_results select 'capability-denied',atlas_api.save_pantry(jsonb_set(request,'{requested_by_auth_subject}','"a7200000-0000-0000-0000-000000000111"')) from p4_requests where name='save1';
select is((select response->>'error_code' from p4_results where name='capability-denied'),'CAPABILITY_DENIED','existing receipt remains behind current capability authorization');
reset role;
insert into atlas_core.actor_role_memberships(actor_id,role_id) values('a7200000-0000-0000-0000-000000000011','a7200000-0000-0000-0000-000000000014');
set local role authenticated;
insert into p4_results select 'actor-conflict',atlas_api.save_pantry(jsonb_set(request,'{requested_by_auth_subject}','"a7200000-0000-0000-0000-000000000111"')) from p4_requests where name='save1';
select is((select response->>'error_code' from p4_results where name='actor-conflict'),'IDEMPOTENCY_CONFLICT','another authorized Actor cannot replay a colliding command ID');
reset role;
select is((select jsonb_agg(to_jsonb(r) order by r.command_receipt_id) from atlas_core.command_receipts r),
(select jsonb_agg(receipt order by receipt->>'command_receipt_id') from p4_receipts),'replay, conflicts and rejected requests create or change no receipt');

-- Mechanically redirect the existing strict proof into disposable test rowsets.
create temp table p4_evaluations as table atlas_planning.planning_input_evaluations;
create temp table p4_menus as table atlas_planning.weekly_menus;
create temp table p4_attendance as table atlas_planning.attendance_batches;
create temp table p4_batches as table atlas_planning.pantry_need_batches;
create temp table p4_snapshots as table atlas_planning.pantry_need_approval_snapshots;
create temp table p4_members as table atlas_planning.pantry_need_approval_snapshot_lines;
create temp table p4_modes as table atlas_planning.pantry_need_approval_snapshot_school_date_modes;
do $test_rows$ declare signature text; definition text; pair text[]; begin
 foreach signature in array array['atlas_core.direct_need_effective_mode(uuid,uuid,date)',
 'atlas_core.direct_need_snapshot_complete_only(uuid,date)','atlas_core.direct_need_evaluation_ready(uuid,date,date)'] loop
  definition:=pg_get_functiondef(signature::regprocedure);
  definition:=replace(definition,'atlas_core.direct_need_effective_mode','pg_temp.p4_effective_mode');
  definition:=replace(definition,'atlas_core.direct_need_snapshot_complete_only','pg_temp.p4_complete_only');
  definition:=replace(definition,'atlas_core.direct_need_evaluation_ready','pg_temp.p4_ready');
  foreach pair slice 1 in array array[
    ['atlas_planning.planning_input_evaluations','pg_temp.p4_evaluations'],
    ['atlas_planning.weekly_menus','pg_temp.p4_menus'],
    ['atlas_planning.attendance_batches','pg_temp.p4_attendance'],
    ['atlas_planning.pantry_need_batches','pg_temp.p4_batches'],
    ['atlas_planning.pantry_need_approval_snapshots','pg_temp.p4_snapshots'],
    ['atlas_planning.pantry_need_approval_snapshot_lines','pg_temp.p4_members'],
    ['atlas_planning.pantry_need_approval_snapshot_school_date_modes','pg_temp.p4_modes']
  ] loop definition:=replace(definition,pair[1],pair[2]); end loop;
  execute definition;
 end loop;
end $test_rows$;
select ok((select pg_temp.p4_ready(planning_input_evaluation_id,'2026-08-24','2026-08-24') from p4_evaluations where evaluation_result='READY' order by evaluation_version desc limit 1),
 'controlled proof starts from genuinely current complete evidence');
update p4_evaluations set pantry_need_batch_version=pantry_need_batch_version+1;
select ok(not exists(select 1 from p4_evaluations where pg_temp.p4_ready(planning_input_evaluation_id,'2026-08-24','2026-08-24')),'stale source version remains rejected');
update p4_evaluations set pantry_need_batch_version=pantry_need_batch_version-1;
delete from p4_batches;
select ok(not exists(select 1 from p4_evaluations where pg_temp.p4_ready(planning_input_evaluation_id,'2026-08-24','2026-08-24')),'missing source remains rejected');
insert into p4_batches select * from atlas_planning.pantry_need_batches;
insert into p4_members select member.* from p4_members member join p4_evaluations e
 on e.pantry_need_approval_snapshot_id=member.pantry_need_approval_snapshot_id
 where e.evaluation_result='READY' order by e.evaluation_version desc limit 1;
select ok(not exists(select 1 from p4_evaluations where pg_temp.p4_ready(planning_input_evaluation_id,'2026-08-24','2026-08-24')),'partial or surplus snapshot membership remains rejected');
delete from p4_members;
insert into p4_members select * from atlas_planning.pantry_need_approval_snapshot_lines;
update p4_modes set direct_need_mode='ADDITIVE';
select ok(not exists(select 1 from p4_evaluations where pg_temp.p4_ready(planning_input_evaluation_id,'2026-08-24','2026-08-24')),'non-COMPLETE source cannot bypass missing catering sources');

select * from finish();
rollback;
