-- B1: authored Purpose is source identity, never a second calculation mode.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=extensions,public;
select no_plan();

select ok((select pg_get_constraintdef(oid) from pg_constraint
  where conrelid='atlas_planning.pantry_need_lines'::regclass
    and conname='pantry_need_lines_stable_grain_key') like
  '%ingredient_id, pantry_need_purpose_id)%',
  'stable source grain includes Purpose');

create temp table b1_signature_rows as
select jsonb_build_array(
  jsonb_build_object('service_date','2026-10-19','school_id',gen_random_uuid(),
    'delivery_location_id',gen_random_uuid(),'ingredient_id',gen_random_uuid(),
    'unit_id',gen_random_uuid(),'pantry_need_purpose_id','00000000-0000-0000-0000-000000000002',
    'requested_quantity',5,'note',null,'source_request_reference','planning'),
  '{}'::jsonb) rows;
update b1_signature_rows set rows=jsonb_set(rows,'{1}',
  (rows->0)||jsonb_build_object('pantry_need_purpose_id','00000000-0000-0000-0000-000000000001',
    'requested_quantity',3,'source_request_reference','school'));
select is(atlas_core.pantry_02_signature('2026-10-19',false,rows),
  atlas_core.pantry_02_signature('2026-10-19',false,jsonb_build_array(rows->1,rows->0)),
  'two-source signature ignores input order even when the former grain ties')
from b1_signature_rows;
select ok(not jsonb_path_exists(atlas_core.pantry_02_issues('2026-10-19',false,rows),
  '$.blockers[*] ? (@.code == "DUPLICATE_ACTIVE_GRAIN")'),
  'different Purposes are not duplicate authored source grain') from b1_signature_rows;

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


insert into atlas_planning.pantry_need_purposes
(pantry_need_purpose_id,purpose_code,purpose_name_vi,purpose_description,note_rule,purpose_status,display_order)
values ('a7200000-0000-4000-8000-000000000001','planning_identified_supplement','Bổ sung','Planning source','OPTIONAL','ACTIVE',20),
('a7200000-0000-4000-8000-000000000002','school_requested_supplement','Đặt theo yêu cầu nhà trường','School source','OPTIONAL','ACTIVE',10);
insert into atlas_core.role_capabilities(role_id,capability_id)
select 'a7200000-0000-0000-0000-000000000014',capability_id from atlas_core.capabilities
where capability_code like 'planning.%' or capability_code like 'confirmed_need%' or capability_code like 'procurement.%'
on conflict do nothing;
create temp table b1_commands(name text primary key,request jsonb,response jsonb);
grant select,insert,update on b1_commands to authenticated;
grant usage on schema extensions to authenticated;
grant execute on all functions in schema extensions to authenticated;

create function pg_temp.b1_payload(school_quantity text default '3',include_school boolean default true)
returns jsonb language sql as $$
select jsonb_build_object('week_start','2026-08-24','no_additions_confirmed',false,
'rows',jsonb_build_array(jsonb_build_object('service_date','2026-08-24',
'school_id','a7200000-0000-0000-0000-000000000026','ingredient_id','a7200000-0000-0000-0000-000000000032',
'pantry_need_purpose_id','a7200000-0000-4000-8000-000000000001','requested_quantity','5','note',null,
'source_row_reference','B1:planning','source_request_reference','request-planning')) ||
case when include_school then jsonb_build_array(jsonb_build_object('service_date','2026-08-24',
'school_id','a7200000-0000-0000-0000-000000000026','ingredient_id','a7200000-0000-0000-0000-000000000032',
'pantry_need_purpose_id','a7200000-0000-4000-8000-000000000002','requested_quantity',school_quantity,'note',null,
'source_row_reference','B1:school','source_request_reference','request-school')) else '[]'::jsonb end,
'school_date_modes','[{"school_id":"a7200000-0000-0000-0000-000000000026","service_date":"2026-08-24","direct_need_mode":"COMPLETE"}]'::jsonb);
$$;
create function pg_temp.b1_save(label text,payload jsonb) returns jsonb language plpgsql as $$
declare current_read jsonb; preview jsonb; request jsonb; result jsonb;
begin
current_read:=atlas_api.get_pantry_source_workbench(pg_temp.pantry02_read('{"week_start":"2026-08-24"}'));
preview:=atlas_api.preview_pantry_source(pg_temp.pantry02_read(payload)||'{"contract_version":"PANTRY-02.v3"}');
request:=pg_temp.pantry02_command(label,coalesce((current_read#>>'{workbench,batch,version}')::bigint,1),
payload||jsonb_build_object('source_signature',preview#>>'{preview,source_signature}',
'expected_source_signature',current_read#>'{workbench,batch,source_signature}'))||'{"contract_version":"PANTRY-02.v3","reason_code":"PANTRY_SAVED"}';
result:=atlas_api.save_pantry(request);
insert into b1_commands values(label,request,result);
return result;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','a7200000-0000-0000-0000-000000000110',true);
select is(pg_temp.b1_save('initial',pg_temp.b1_payload())->>'success','true','B1-01 public v3 Save approves two sources with optional notes');
select diag(response::text) from b1_commands where name='initial' and response->>'success'<>'true';
set constraints all immediate;
set constraints all deferred;
select is(jsonb_array_length(atlas_api.get_pantry_source_workbench(pg_temp.pantry02_read('{"week_start":"2026-08-24"}'))#>'{workbench,batch,active_lines}'),2,'reopening authoritative workbench retains both sources');
reset role;
create temp table b1_original as select pantry_need_line_id,pantry_need_purpose_id,requested_quantity,source_row_reference,source_request_reference
from atlas_planning.pantry_need_lines where line_status='ACTIVE';
select ok((select count(*)=2 and count(distinct pantry_need_line_id)=2 and sum(requested_quantity)=8
and count(distinct pantry_need_purpose_id)=2 and count(distinct source_request_reference)=2 from b1_original),
'two stable IDs, purposes, references and exact 5+3=8 authored facts');
select diag('B1 source proof: '||jsonb_agg(to_jsonb(o) order by source_row_reference)::text) from b1_original o;
create temp table b1_history as select to_jsonb(s) evidence from atlas_planning.pantry_need_approval_snapshot_lines s;
select is((select count(*) from b1_history),2::bigint,'approval snapshot includes both sources');
set local role authenticated;
select is(jsonb_array_length(atlas_api.preview_pantry_source(pg_temp.pantry02_read(pg_temp.b1_payload('4'))||'{"contract_version":"PANTRY-02.v3"}')#>'{preview,comparison,changed_lines}'),1,'Preview matches Purpose and reports exactly one changed source');
select is(pg_temp.b1_save('correct-school',pg_temp.b1_payload('4'))->>'success','true','B1-03 correct only School-requested quantity');
set constraints all immediate;
set constraints all deferred;
reset role;
select ok((select count(*)=2 and sum(requested_quantity)=9 from atlas_planning.pantry_need_lines where line_status='ACTIVE')
and not exists(select pantry_need_line_id from b1_original except select pantry_need_line_id from atlas_planning.pantry_need_lines where line_status='ACTIVE'),
'correction retains both stable source IDs and exact 5+4=9');
select ok((select requested_quantity=5 and source_request_reference='request-planning' from atlas_planning.pantry_need_lines where source_row_reference='B1:planning'),
'Planning source stays exact after School-source correction');
select ok(not exists(select evidence from b1_history except select to_jsonb(s) from atlas_planning.pantry_need_approval_snapshot_lines s),'first approved source evidence remains byte-for-byte immutable');
set local role authenticated;
select is(pg_temp.b1_save('remove-school',pg_temp.b1_payload('4',false))->>'success','true','B1-04 omit only School source');
set constraints all immediate;
set constraints all deferred;
reset role;
select ok((select count(*)=1 and sum(requested_quantity)=5 from atlas_planning.pantry_need_lines where line_status='ACTIVE')
and (select line_status='INVALID' from atlas_planning.pantry_need_lines where source_row_reference='B1:school'),
'omission preserves the Planning 5 and invalidates only the School source');
set local role authenticated;
select is(pg_temp.b1_save('restore-school',pg_temp.b1_payload())->>'success','true','reintroduce exact original 5+3 facts');
set constraints all immediate;
set constraints all deferred;
reset role;
select ok(not exists(select pantry_need_line_id from b1_original except select pantry_need_line_id from atlas_planning.pantry_need_lines where line_status='ACTIVE'),
'reintroduction reuses each original stable grain ID');
select throws_ok($q$update atlas_planning.pantry_need_lines set pantry_need_purpose_id='3c3de399-b88f-575a-a3ce-eff9e16deb55' where source_row_reference='B1:school'$q$,
'23514','stable Pantry line grain and creation evidence are immutable','Purpose cannot overwrite an existing source identity');
set local role authenticated;
select ok(jsonb_path_exists(atlas_api.preview_pantry_source(pg_temp.pantry02_read(jsonb_set(pg_temp.b1_payload(),'{rows,1,pantry_need_purpose_id}','"a7200000-0000-4000-8000-000000000001"'))||'{"contract_version":"PANTRY-02.v3"}'),
'$.preview.issues.blockers[*] ? (@.code == "DUPLICATE_ACTIVE_GRAIN")'),'same-category grain is rejected');
select ok(jsonb_path_exists(atlas_api.preview_pantry_source(pg_temp.pantry02_read(jsonb_set(pg_temp.b1_payload(),'{rows,1,pantry_need_purpose_id}','"ffffffff-ffff-ffff-ffff-ffffffffffff"'))||'{"contract_version":"PANTRY-02.v3"}'),
'$.preview.issues.blockers[*] ? (@.code == "UNKNOWN_PURPOSE")'),'spoofed Purpose is rejected');
select is(atlas_api.save_pantry(jsonb_set(jsonb_set((select request from b1_commands where name='initial'),'{command_id}',to_jsonb(gen_random_uuid())),'{idempotency_key}','"B1:stale"'))->>'error_code','STALE_VERSION','stale new intent cannot overwrite newer sources');

-- Genuine COMPLETE generation. No mock result or direct business-state UPDATE.
insert into b1_commands select 'generate',request,atlas_api.execute_need_generation(request) from
(select pg_temp.pantry02_command('generate',1,'{"service_date":"2026-08-24","expected_current_need_generation_run_id":null}')||
'{"contract_version":"RMVP-04.v3","reason_code":"NEED_GENERATION_EXECUTED"}'::jsonb request) q;
select is((select response->>'success' from b1_commands where name='generate'),'true','B1-02 genuine Need generation from two-source COMPLETE snapshot');
select diag(response::text) from b1_commands where name='generate' and response->>'success'<>'true';
set constraints all immediate;
set constraints all deferred;
reset role;
select ok((select count(*)=2 and sum(theoretical_quantity)=8 and count(distinct pantry_need_line_id)=2
from atlas_planning.theoretical_need_lines where contribution_family='PANTRY_DIRECT' and line_disposition='ACTIVE'),
'COMPLETE derives exact 8 from two original Pantry source IDs without multiplication');
select ok((select count(*)=2 and sum(c.controlled_contribution_quantity)=8 and count(distinct t.pantry_need_line_id)=2
from atlas_planning.confirmed_need_line_revision_contributions c join atlas_planning.theoretical_need_lines t using(theoretical_need_line_id)
where t.contribution_family='PANTRY_DIRECT'), 'Confirmed Need retains both independent contributions and exact quantities');
select diag('B1 theoretical lineage: '||jsonb_agg(jsonb_build_object('pantry_need_line_id',pantry_need_line_id,'theoretical_need_line_id',theoretical_need_line_id,'quantity',theoretical_quantity))::text)
from atlas_planning.theoretical_need_lines where contribution_family='PANTRY_DIRECT';

-- Use the existing real confirmation/allocation/release journey with B1's
-- two-source generated evidence. No PO or Supplier commitment is created.
create temp table p4_requests(name text primary key,request jsonb);
create temp table p4_results(name text primary key,response jsonb);
grant select,insert,update on p4_requests,p4_results to authenticated;
create function pg_temp.p4_request(name text,version bigint,payload jsonb,contract text default 'PANTRY-02.v4')
returns jsonb language sql as $$
 select pg_temp.pantry02_command('v4:'||name,version,payload)||jsonb_build_object(
 'contract_version',contract,'reason_note',case when contract in ('RMVP-05.v2','RMVP-07.v2') then null else 'Rolled-back PANTRY-02 acceptance test.' end,'reason_code',case contract when 'RMVP-04.v3' then 'NEED_GENERATION_EXECUTED'
 when 'RMVP-05.v2' then 'CONFIRMED_NEED_SAVED' when 'RMVP-07.v2' then 'CONFIRMED_NEED_RELEASED' else 'PANTRY_SAVED' end);
$$;

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
-- Genuine confirmed allocation is a mandatory release prerequisite, not a test status shortcut.
insert into atlas_admin.suppliers(supplier_id,supplier_code,supplier_name,document_code)
values('a7200000-0000-4000-8000-000000000090','PANTRY-V4-SUPPLIER','Pantry v4 test Supplier','P4-SUPPLIER');
insert into atlas_admin.supplier_eligibilities(supplier_id,ingredient_id,effective_from,priority,reason_note)
values('a7200000-0000-4000-8000-000000000090','a7200000-0000-0000-0000-000000000032','2020-01-01',1,'Local Pantry v4 release prerequisite');
set constraints all immediate;
set constraints all deferred;
set local role authenticated;
insert into p4_results values('allocation-read',atlas_api.get_confirmed_supplier_allocation_workbench(jsonb_build_object(
 'contract_version','CONFIRMED-SUPPLIER-ALLOCATION.v1','requested_by_auth_subject','a7200000-0000-0000-0000-000000000110',
 'correlation_id',gen_random_uuid(),'payload',jsonb_build_object('date_start','2026-08-24','date_end','2026-08-24'))));
insert into p4_results select 'allocation-save-'||ordinality,atlas_api.save_confirmed_supplier_allocation(
 pg_temp.p4_request('allocation-'||ordinality,(row#>>'{family,version}')::bigint,jsonb_build_object(
 'family',jsonb_build_object('service_date',row->'service_date','delivery_location_id',row->'delivery_location_id',
 'ingredient_id',row->'ingredient_id','unit_id',row->'unit_id',
 'expected_source_fingerprint',row#>'{family,source_fingerprint}',
 'expected_source_batch_id',row->'source_confirmed_need_batch_id',
 'expected_source_batch_version',row->'source_confirmed_need_batch_version'),
 'splits',jsonb_build_array(jsonb_build_object('supplier_id','a7200000-0000-4000-8000-000000000090',
 'allocated_quantity',row->'family_quantity'))),'CONFIRMED-SUPPLIER-ALLOCATION.v1')
 ||jsonb_build_object('reason_code','CONFIRMED_SUPPLIER_ALLOCATION_SAVED','reason_note',null))
from p4_results cross join lateral jsonb_array_elements(response->'rows')with ordinality as item(row,ordinality)
where name='allocation-read';
set constraints all immediate;
set constraints all deferred;
select ok((select count(*)=1 and bool_and(response->>'success'='true')from p4_results where name like 'allocation-save-%'),
 'complete positive family is allocated through the public command before Need release');
select diag(response::text)from p4_results where name like 'allocation-save-%'and response->>'success'<>'true';
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

select ok((select count(*)=2 and count(distinct t.pantry_need_line_id)=2 and sum(c.controlled_contribution_quantity)=8
from atlas_planning.confirmed_need_line_revision_contributions c join atlas_planning.theoretical_need_lines t using(theoretical_need_line_id)
where t.contribution_family='PANTRY_DIRECT'),'released purchasing Need retains both original source contributions totaling 8');
set local role authenticated;
select is(pg_temp.b1_save('protected-correction',pg_temp.b1_payload('4'))->>'success','false',
'released downstream evidence blocks an unprepared material source correction');
select is((select response->>'error_code' from b1_commands where name='protected-correction'),
'PLANNING_RELEASE_CORRECTION_REQUIRED','valid material correction hits the exact released-Need guard, not an unrelated failure');
reset role;
select ok((select sum(requested_quantity)=8 and count(*)=2 from atlas_planning.pantry_need_lines where line_status='ACTIVE'),
'failed protected correction rolls back every source quantity and preserves both lines');
set local role authenticated;
select is(atlas_api.save_pantry((select request from b1_commands where name='initial')),
(select response from b1_commands where name='initial'),'exact v3 retry resolves the durable receipt after later Saves and generation');
select is(atlas_api.save_pantry(jsonb_set((select request from b1_commands where name='initial'),'{payload,rows,1,requested_quantity}','"99"'))->>'error_code',
'IDEMPOTENCY_CONFLICT','changed content under old command identity conflicts');

-- Rejected proposal/identity cases share existing hardened backend validation.
select ok(jsonb_path_exists(atlas_api.preview_pantry_source(pg_temp.pantry02_read(jsonb_set(pg_temp.b1_payload(),'{rows,1,unit_id}','"spoof"'))||'{"contract_version":"PANTRY-02.v3"}'),
'$.preview.issues.blockers[*] ? (@.code == "CALLER_UNIT_NOT_ALLOWED")'),'browser Unit authority is rejected');
select ok(jsonb_path_exists(atlas_api.preview_pantry_source(pg_temp.pantry02_read(jsonb_set(pg_temp.b1_payload(),'{rows,1,requested_quantity}','"-1"'))||'{"contract_version":"PANTRY-02.v3"}'),
'$.preview.issues.blockers[*] ? (@.code == "QUANTITY_NOT_POSITIVE")'),'negative source quantities are rejected');
select ok(jsonb_path_exists(atlas_api.preview_pantry_source(pg_temp.pantry02_read(jsonb_set(
jsonb_set(pg_temp.b1_payload(),'{rows,1,school_id}','"ffffffff-ffff-ffff-ffff-ffffffffffff"'),
'{school_date_modes}',(pg_temp.b1_payload()->'school_date_modes')||jsonb_build_array(jsonb_build_object(
'school_id','ffffffff-ffff-ffff-ffff-ffffffffffff','service_date','2026-08-24','direct_need_mode','COMPLETE'))))||'{"contract_version":"PANTRY-02.v3"}'),
'$.preview.issues.blockers[*] ? (@.code == "UNKNOWN_SCHOOL")'),'unknown School is rejected');
select ok(jsonb_path_exists(atlas_api.preview_pantry_source(pg_temp.pantry02_read(jsonb_set(pg_temp.b1_payload(),'{rows,1,ingredient_id}','"ffffffff-ffff-ffff-ffff-ffffffffffff"'))||'{"contract_version":"PANTRY-02.v3"}'),
'$.preview.issues.blockers[*] ? (@.code == "UNKNOWN_INGREDIENT")'),'unknown Ingredient is rejected');
select is(atlas_api.save_pantry(jsonb_set((select request from b1_commands where name='initial'),'{requested_by_auth_subject}','"a7200000-0000-0000-0000-000000000111"'))->>'error_code',
'AUTH_SUBJECT_MISMATCH','B1 receipt lookup preserves authenticated subject binding');
select set_config('request.jwt.claim.sub','a7200000-0000-0000-0000-000000000111',true);
select is(atlas_api.save_pantry(jsonb_set((select request from b1_commands where name='initial'),'{requested_by_auth_subject}','"a7200000-0000-0000-0000-000000000111"'))->>'error_code',
'CAPABILITY_DENIED','Actor without write capability cannot replay a B1 receipt');
select set_config('request.jwt.claim.sub','a7200000-0000-0000-0000-000000000110',true);
reset role;
update atlas_core.actor_scopes set scope_status='REVOKED' where actor_id='a7200000-0000-0000-0000-000000000010';
set local role authenticated;
select is(atlas_api.save_pantry((select request from b1_commands where name='initial'))->>'error_code','SCOPE_DENIED',
'wrong-scope Actor cannot read a B1 receipt or mutate cross-School sources');
reset role;
select * from finish();
rollback;
