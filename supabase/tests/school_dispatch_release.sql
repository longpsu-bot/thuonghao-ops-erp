begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set search_path = extensions, public, pg_catalog;

select plan(139);

select has_function('atlas_api','get_school_dispatch_release_workbench',array['jsonb']);
select has_function('atlas_api','release_school_dispatch_document',array['jsonb']);
select function_owner_is('atlas_api','get_school_dispatch_release_workbench',array['jsonb'],
  'atlas_read_runtime');
select function_owner_is('atlas_api','release_school_dispatch_document',array['jsonb'],
  'atlas_dispatch_command_runtime');
select function_privs_are('atlas_api','get_school_dispatch_release_workbench',array['jsonb'],
  'authenticated',array['EXECUTE']);
select function_privs_are('atlas_api','release_school_dispatch_document',array['jsonb'],
  'authenticated',array['EXECUTE']);
select function_privs_are('atlas_api','get_school_dispatch_release_workbench',array['jsonb'],
  'anon',array[]::text[]);
select function_privs_are('atlas_api','release_school_dispatch_document',array['jsonb'],
  'anon',array[]::text[]);

select has_table('atlas_dispatch','school_dispatch_releases','School PXK headers exist');
select has_table('atlas_dispatch','school_dispatch_release_lines','School PXK lines exist');
select has_table('atlas_dispatch','school_dispatch_release_line_sources','School PXK lineage exists');
select has_column('atlas_admin','schools','dispatch_document_issuer_name',
  'School master configures the direct PXK issuer name');
select has_column('atlas_admin','schools','dispatch_document_issuer_address',
  'School master configures the direct PXK issuer address');
select has_column('atlas_dispatch','school_dispatch_releases','school_display_order_snapshot',
  'released PXK freezes School display order');
select has_column('atlas_dispatch','school_dispatch_releases','document_issuer_name_snapshot',
  'released PXK freezes its issuer name');
select has_column('atlas_dispatch','school_dispatch_releases','document_issuer_address_snapshot',
  'released PXK freezes its issuer address');
select ok((select relrowsecurity and relforcerowsecurity from pg_class
  where oid='atlas_dispatch.school_dispatch_releases'::regclass),
  'School PXK headers have forced RLS');
select ok((select relrowsecurity and relforcerowsecurity from pg_class
  where oid='atlas_dispatch.school_dispatch_release_lines'::regclass),
  'School PXK lines have forced RLS');
select ok((select relrowsecurity and relforcerowsecurity from pg_class
  where oid='atlas_dispatch.school_dispatch_release_line_sources'::regclass),
  'School PXK lineage has forced RLS');
select ok(not exists(
  select 1 from information_schema.role_table_grants
  where table_schema='atlas_dispatch'
    and table_name in ('school_dispatch_releases','school_dispatch_release_lines',
      'school_dispatch_release_line_sources')
    and grantee in ('anon','authenticated','service_role')
), 'browser and service roles receive no direct School PXK relation grants');
select ok(exists(select 1 from atlas_core.capabilities
  where capability_code='dispatch.school_release.read' and capability_status='ACTIVE'),
  'bounded School PXK read capability exists');
select ok(exists(select 1 from atlas_core.capabilities
  where capability_code='dispatch.school_release.release' and capability_status='ACTIVE'),
  'bounded School PXK release capability exists');

insert into atlas_core.actors(actor_id,actor_type,display_name)
values('26000000-0000-4000-8000-000000000001','HUMAN','School PXK operator');
insert into atlas_core.actor_auth_subjects(actor_id,auth_subject_id)
values('26000000-0000-4000-8000-000000000001','26000000-0000-4000-8000-000000000101');
insert into atlas_core.roles(role_id,role_code,role_name)
values('26010000-0000-4000-8000-000000000001','school_pxk_operator','School PXK operator');
insert into atlas_core.role_capabilities(role_id,capability_id)
select '26010000-0000-4000-8000-000000000001',capability_id
from atlas_core.capabilities
where capability_code in ('dispatch.school_release.read','dispatch.school_release.release');
insert into atlas_core.role_capabilities(role_id,capability_id)
select '26010000-0000-4000-8000-000000000001',capability_id
from atlas_core.capabilities
where capability_code='procurement.school_catering.write';
insert into atlas_core.actor_role_memberships(actor_id,role_id)
values('26000000-0000-4000-8000-000000000001','26010000-0000-4000-8000-000000000001');
insert into atlas_core.actor_scopes(actor_id,scope_kind)
values('26000000-0000-4000-8000-000000000001','GLOBAL');

insert into atlas_admin.customers(customer_id,customer_code,customer_name,customer_type)
values
  ('26020000-0000-4000-8000-000000000001','pxk-school-customer',
    'PXK School Customer','SCHOOL_CATERING'),
  ('26020000-0000-4000-8000-000000000002','pxk-other-customer',
    'PXK Other Customer','SCHOOL_CATERING');
insert into atlas_admin.delivery_locations(
  delivery_location_id,customer_id,location_code,location_name,address_text)
values
  ('26020000-0000-4000-8000-000000000011','26020000-0000-4000-8000-000000000001',
    'pxk-location-a','Bếp chính Nguyễn Du','Số 1 Nguyễn Du'),
  ('26020000-0000-4000-8000-000000000012','26020000-0000-4000-8000-000000000001',
    'pxk-location-b','Bếp phụ Nguyễn Du','Số 2 Nguyễn Du'),
  ('26020000-0000-4000-8000-000000000013','26020000-0000-4000-8000-000000000002',
    'pxk-cross-customer','Bếp khác khách hàng','Số 3 Nguyễn Du');
insert into atlas_admin.schools(
  school_id,customer_id,school_code,school_name,default_delivery_location_id,display_order,
  dispatch_document_issuer_name,dispatch_document_issuer_address)
values
  ('26020000-0000-4000-8000-000000000021','26020000-0000-4000-8000-000000000001',
    'pxk-school','Trường Tiểu học Nguyễn Du','26020000-0000-4000-8000-000000000011',1,
    'CƠ SỞ CUNG CẤP THỰC PHẨM THƯỢNG HẢO','Địa chỉ PXK đã cấu hình'),
  ('26020000-0000-4000-8000-000000000022','26020000-0000-4000-8000-000000000001',
    'pxk-school-b','Trường Tiểu học Trưng Vương','26020000-0000-4000-8000-000000000012',2,
    'CÔNG TY TNHH MTV TM - DV THƯỢNG HẢO','Địa chỉ PXK đã cấu hình');

-- Relational-scope operators for cutover authorization regression.
insert into atlas_core.actors(actor_id,actor_type,display_name) values
  ('26000000-0000-4000-8000-000000000002','HUMAN','PXK School A operator'),
  ('26000000-0000-4000-8000-000000000003','HUMAN','PXK School B operator'),
  ('26000000-0000-4000-8000-000000000004','HUMAN','PXK no-capability operator');
insert into atlas_core.actor_auth_subjects(actor_id,auth_subject_id) values
  ('26000000-0000-4000-8000-000000000002','26000000-0000-4000-8000-000000000102'),
  ('26000000-0000-4000-8000-000000000003','26000000-0000-4000-8000-000000000103'),
  ('26000000-0000-4000-8000-000000000004','26000000-0000-4000-8000-000000000104');
insert into atlas_core.actor_role_memberships(actor_id,role_id) values
  ('26000000-0000-4000-8000-000000000002','26010000-0000-4000-8000-000000000001'),
  ('26000000-0000-4000-8000-000000000003','26010000-0000-4000-8000-000000000001');
insert into atlas_core.roles(role_id,role_code,role_name)
values('26010000-0000-4000-8000-000000000004','school_pxk_no_cap','School PXK no-capability role');
insert into atlas_core.actor_role_memberships(actor_id,role_id)
values('26000000-0000-4000-8000-000000000004','26010000-0000-4000-8000-000000000004');
insert into atlas_core.actor_scopes(actor_id,scope_kind,school_id) values
  ('26000000-0000-4000-8000-000000000002','SCHOOL','26020000-0000-4000-8000-000000000021'),
  ('26000000-0000-4000-8000-000000000003','SCHOOL','26020000-0000-4000-8000-000000000022'),
  ('26000000-0000-4000-8000-000000000004','SCHOOL','26020000-0000-4000-8000-000000000021');
insert into atlas_admin.units(unit_id,unit_code,unit_name,dimension_code)
values('26020000-0000-4000-8000-000000000031','pxk-kg','Kilôgam','mass');
insert into atlas_admin.ingredients(ingredient_id,ingredient_code,ingredient_name,purchase_unit_id,document_code)
values('26020000-0000-4000-8000-000000000041','pxk-rice','Gạo thơm',
  '26020000-0000-4000-8000-000000000031','1082');
insert into atlas_admin.suppliers(supplier_id,supplier_code,supplier_name,supplier_status,document_code)
values
  ('26020000-0000-4000-8000-000000000051','pxk-supplier-a','NCC An Phú','ACTIVE','53'),
  ('26020000-0000-4000-8000-000000000052','pxk-supplier-b','NCC Bình Minh','ACTIVE','54'),
  ('26020000-0000-4000-8000-000000000053','pxk-supplier-c','NCC Cửu Long','ACTIVE','55');
insert into atlas_admin.supplier_eligibilities(
  supplier_id,ingredient_id,effective_from,priority,reason_note)
values
  ('26020000-0000-4000-8000-000000000051','26020000-0000-4000-8000-000000000041',
    '2026-01-01',1,'PXK test'),
  ('26020000-0000-4000-8000-000000000052','26020000-0000-4000-8000-000000000041',
    '2026-01-01',2,'PXK test'),
  ('26020000-0000-4000-8000-000000000053','26020000-0000-4000-8000-000000000041',
    '2026-01-01',3,'PXK test');

-- Exact current Confirmed Need -> Handoff -> Allocation -> released PO evidence.
set session_replication_role=replica;
-- These downstream fixtures now need their referenced run roots for source locks.
insert into atlas_planning.need_generation_runs(
  need_generation_run_id,planning_input_set_id,planning_input_evaluation_id,evaluation_version,
  period_start,period_end,attempt_ordinal,input_snapshot_id,run_status,version,
  generated_line_count,blocking_issue_count,warning_count,generated_by_actor_id,generated_at,
  validated_by_actor_id,validated_at,released_by_actor_id,released_at,updated_at)
select run_id,run_id,run_id,1,service_date,service_date,1,run_id,'RELEASED_FOR_CONFIRMATION',1,
  1,0,0,'26000000-0000-4000-8000-000000000001',transaction_timestamp(),
  '26000000-0000-4000-8000-000000000001',transaction_timestamp(),
  '26000000-0000-4000-8000-000000000001',transaction_timestamp(),transaction_timestamp()
from (values('26030000-0000-4000-8000-000000000002'::uuid,'2026-09-24'::date),
  ('26130000-0000-4000-8000-000000000002'::uuid,'2026-09-25'::date)) source(run_id,service_date);
insert into atlas_planning.confirmed_need_batches(
  confirmed_need_batch_id,period_start,period_end,batch_status,version,
  created_by_actor_id,source_kind,origin_need_generation_run_id,
  origin_need_generation_run_version,origin_need_generation_release_snapshot_id,
  current_need_generation_run_id,current_need_generation_run_version,
  current_need_generation_release_snapshot_id)
values('26030000-0000-4000-8000-000000000001','2026-09-24','2026-09-24',
  'RELEASED_FOR_PURCHASE_HANDOFF',1,'26000000-0000-4000-8000-000000000001',
  'NEED_GENERATION','26030000-0000-4000-8000-000000000002',1,
  '26030000-0000-4000-8000-000000000003','26030000-0000-4000-8000-000000000002',1,
  '26030000-0000-4000-8000-000000000003');
insert into atlas_planning.confirmed_need_lines(
  confirmed_need_line_id,confirmed_need_batch_id,source_kind,service_date,customer_id,
  school_id,delivery_location_id,ingredient_id,controlled_unit_id,
  current_confirmed_need_line_decision_id)
values('26030000-0000-4000-8000-000000000011','26030000-0000-4000-8000-000000000001',
  'NEED_GENERATION','2026-09-24','26020000-0000-4000-8000-000000000001',
  '26020000-0000-4000-8000-000000000021','26020000-0000-4000-8000-000000000011',
  '26020000-0000-4000-8000-000000000041','26020000-0000-4000-8000-000000000031',
  '26030000-0000-4000-8000-000000000013');
insert into atlas_planning.confirmed_need_line_revisions(
  confirmed_need_line_revision_id,confirmed_need_line_id,revision_number,ingredient_id,
  theoretical_quantity,confirmed_quantity,unit_id,revision_status,is_current,
  created_by_actor_id,source_kind,confirmed_need_batch_id,need_generation_run_id,
  need_generation_run_version,need_generation_release_snapshot_id,service_date,
  customer_id,school_id,delivery_location_id)
values('26030000-0000-4000-8000-000000000012','26030000-0000-4000-8000-000000000011',
  1,'26020000-0000-4000-8000-000000000041',100,100,
  '26020000-0000-4000-8000-000000000031','RELEASED',true,
  '26000000-0000-4000-8000-000000000001','NEED_GENERATION',
  '26030000-0000-4000-8000-000000000001','26030000-0000-4000-8000-000000000002',1,
  '26030000-0000-4000-8000-000000000003','2026-09-24',
  '26020000-0000-4000-8000-000000000001','26020000-0000-4000-8000-000000000021',
  '26020000-0000-4000-8000-000000000011');
insert into atlas_planning.confirmed_need_line_decisions(
  confirmed_need_line_decision_id,confirmed_need_batch_id,confirmed_need_line_id,
  confirmed_need_line_revision_id,source_kind,service_date,customer_id,school_id,
  delivery_location_id,ingredient_id,unit_id,decision_number,decision_kind,
  planning_quantity_policy_id,planning_quantity_policy_revision_id,
  theoretical_quantity_before,proposed_quantity_before,confirmed_quantity_after,
  planning_tick_count,reason_code,decided_by_actor_id,decided_at,command_id,
  confirmed_need_batch_version)
values('26030000-0000-4000-8000-000000000013','26030000-0000-4000-8000-000000000001',
  '26030000-0000-4000-8000-000000000011','26030000-0000-4000-8000-000000000012',
  'NEED_GENERATION','2026-09-24','26020000-0000-4000-8000-000000000001',
  '26020000-0000-4000-8000-000000000021','26020000-0000-4000-8000-000000000011',
  '26020000-0000-4000-8000-000000000041','26020000-0000-4000-8000-000000000031',
  1,'UNCHANGED_PROPOSAL_ACCEPTED','26030000-0000-4000-8000-000000000014',
  '26030000-0000-4000-8000-000000000015',100,100,100,100000000,
  'PROPOSAL_ACCEPTED','26000000-0000-4000-8000-000000000001',transaction_timestamp(),
  '26030000-0000-4000-8000-000000000016',1);
insert into atlas_planning.purchase_handoff_batches(
  purchase_handoff_batch_id,confirmed_need_batch_id,period_start,period_end,
  handoff_status,created_by_actor_id)
values('26030000-0000-4000-8000-000000000021','26030000-0000-4000-8000-000000000001',
  '2026-09-24','2026-09-24','RELEASED_TO_PROCUREMENT',
  '26000000-0000-4000-8000-000000000001');
insert into atlas_planning.purchase_handoff_revisions(
  purchase_handoff_revision_id,purchase_handoff_batch_id,revision_number,
  revision_status,is_current,released_by_actor_id,released_at)
values('26030000-0000-4000-8000-000000000022','26030000-0000-4000-8000-000000000021',
  1,'RELEASED_TO_PROCUREMENT',true,'26000000-0000-4000-8000-000000000001',
  transaction_timestamp());
insert into atlas_planning.purchase_handoff_lines(
  purchase_handoff_line_id,purchase_handoff_batch_id,confirmed_need_line_id)
values('26030000-0000-4000-8000-000000000023','26030000-0000-4000-8000-000000000021',
  '26030000-0000-4000-8000-000000000011');
insert into atlas_planning.purchase_handoff_line_revisions(
  purchase_handoff_line_revision_id,purchase_handoff_revision_id,purchase_handoff_line_id,
  confirmed_need_line_revision_id,ingredient_id,handoff_quantity,unit_id,service_date,
  delivery_location_id)
values('26030000-0000-4000-8000-000000000024','26030000-0000-4000-8000-000000000022',
  '26030000-0000-4000-8000-000000000023','26030000-0000-4000-8000-000000000012',
  '26020000-0000-4000-8000-000000000041',100,'26020000-0000-4000-8000-000000000031',
  '2026-09-24','26020000-0000-4000-8000-000000000011');
insert into atlas_planning.purchase_demand_references(
  purchase_demand_reference_id,purchase_handoff_line_revision_id,
  confirmed_need_snapshot_line_id,approved_quantity,unit_id,source_kind)
values('26030000-0000-4000-8000-000000000025','26030000-0000-4000-8000-000000000024',
  '26030000-0000-4000-8000-000000000026',100,'26020000-0000-4000-8000-000000000031',
  'NEED_GENERATION');
insert into atlas_procurement.school_catering_allocation_families(
  family_id,service_date,delivery_location_id,ingredient_id,unit_id)
values('26040000-0000-4000-8000-000000000001','2026-09-24',
  '26020000-0000-4000-8000-000000000011','26020000-0000-4000-8000-000000000041',
  '26020000-0000-4000-8000-000000000031');
insert into atlas_procurement.school_catering_allocation_family_revisions(
  family_revision_id,family_id,revision_number,is_current,
  source_purchase_handoff_revision_id,source_fingerprint,family_quantity,unit_id,
  accepted_by_actor_id,command_id,decision_origin,source_kind)
select '26040000-0000-4000-8000-000000000002','26040000-0000-4000-8000-000000000001',
  1,true,'26030000-0000-4000-8000-000000000022',
  atlas_core.school_catering_family_projection('2026-09-24',
    '26020000-0000-4000-8000-000000000011','26020000-0000-4000-8000-000000000041',
    '26020000-0000-4000-8000-000000000031')->>'source_fingerprint',
  100,'26020000-0000-4000-8000-000000000031',
  '26000000-0000-4000-8000-000000000001','26040000-0000-4000-8000-000000000003',
  'MANUAL','PURCHASE_HANDOFF';
insert into atlas_procurement.school_catering_allocation_family_contributions(
  family_contribution_id,family_revision_id,purchase_handoff_line_revision_id,
  contribution_quantity)
values('26040000-0000-4000-8000-000000000004','26040000-0000-4000-8000-000000000002',
  '26030000-0000-4000-8000-000000000024',100);
insert into atlas_procurement.school_catering_allocation_supplier_splits(
  supplier_split_id,family_revision_id,supplier_id,allocated_quantity,split_ratio,
  decision_origin)
values('26040000-0000-4000-8000-000000000005','26040000-0000-4000-8000-000000000002',
  '26020000-0000-4000-8000-000000000051',100,1,'MANUAL');
insert into atlas_procurement.purchase_orders(
  purchase_order_id,supplier_id,document_number,purchase_order_status,version,
  purchase_order_kind,school_catering_service_date)
values('26050000-0000-4000-8000-000000000001','26020000-0000-4000-8000-000000000051',
  'PO-20260924-INITIAL','RELEASED_TO_SUPPLIER',2,'SCHOOL_CATERING','2026-09-24');
insert into atlas_procurement.purchase_order_revisions(
  purchase_order_revision_id,purchase_order_id,revision_number,revision_kind,
  revision_status,is_current,service_date,delivery_location_id,supplier_name_snapshot,
  delivery_location_snapshot,released_by_actor_id,released_at)
values('26050000-0000-4000-8000-000000000002','26050000-0000-4000-8000-000000000001',
  2,'SUPERSEDING','RELEASED_TO_SUPPLIER',true,'2026-09-24',null,'NCC An Phú',
  'Nhiều điểm giao','26000000-0000-4000-8000-000000000001',transaction_timestamp());
insert into atlas_procurement.purchase_order_lines(
  purchase_order_line_id,purchase_order_id,school_catering_allocation_family_id)
values('26050000-0000-4000-8000-000000000003','26050000-0000-4000-8000-000000000001',
  '26040000-0000-4000-8000-000000000001');
insert into atlas_procurement.purchase_order_line_revisions(
  purchase_order_line_revision_id,purchase_order_revision_id,purchase_order_line_id,
  school_catering_allocation_supplier_split_id,ingredient_id,ordered_quantity,unit_id,
  delivery_location_id,service_date)
values('26050000-0000-4000-8000-000000000004','26050000-0000-4000-8000-000000000002',
  '26050000-0000-4000-8000-000000000003','26040000-0000-4000-8000-000000000005',
  '26020000-0000-4000-8000-000000000041',100,'26020000-0000-4000-8000-000000000031',
  '26020000-0000-4000-8000-000000000011','2026-09-24');
set session_replication_role=origin;

-- The operational chain remains captured at Location A while mutable School
-- master data later changes its default to same-Customer Location B.
update atlas_admin.schools
set default_delivery_location_id='26020000-0000-4000-8000-000000000012'
where school_id='26020000-0000-4000-8000-000000000021';

create temporary table pxk_results(name text primary key,response jsonb not null);
grant select,insert on pxk_results to authenticated;
create function pg_temp.pxk_read() returns jsonb language sql stable set search_path='' as $$
  select jsonb_build_object('contract_version','SCHOOL-DISPATCH-RELEASE.v1',
    'requested_by_auth_subject','26000000-0000-4000-8000-000000000101'::uuid,
    'correlation_id',gen_random_uuid(),'payload',jsonb_build_object(
      'date_start','2026-09-24','date_end','2026-09-24','school_ids','[]'::jsonb,
      'search',null));
$$;
create function pg_temp.pxk_release(
  p_command uuid,p_expected bigint,p_predecessor uuid,p_note text default null)
returns jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object('contract_version','SCHOOL-DISPATCH-RELEASE.v1',
    'command_id',p_command,'correlation_id',p_command,
    'idempotency_key','pxk:'||p_command,'expected_version',p_expected,
    'requested_by_auth_subject','26000000-0000-4000-8000-000000000101'::uuid,
    'requested_at',transaction_timestamp()+interval '30 seconds',
    'reason_code','SCHOOL_DISPATCH_DOCUMENT_RELEASED','reason_note',p_note,
    'payload',jsonb_build_object('service_date','2026-09-24',
      'school_id','26020000-0000-4000-8000-000000000021',
      'delivery_location_id','26020000-0000-4000-8000-000000000011',
      'expected_source_fingerprint',preview->>'source_fingerprint',
      'predecessor_release_id',p_predecessor))
  from (select atlas_core.school_dispatch_release_preview('2026-09-24',
    '26020000-0000-4000-8000-000000000021',
    '26020000-0000-4000-8000-000000000011') preview) source;
$$;
create function pg_temp.pxk_release_isolated(p_request jsonb)
returns jsonb language plpgsql volatile set search_path='' as $pxk_release_isolated$
declare v_response jsonb;
begin
  v_response:=atlas_api.release_school_dispatch_document(p_request);
  raise exception using errcode='PXS99';
exception when sqlstate 'PXS99' then
  return v_response;
end;
$pxk_release_isolated$;
grant execute on function pg_temp.pxk_release_isolated(jsonb) to authenticated;

create function pg_temp.pxk_procurement_command(
  p_command uuid,p_expected bigint,p_reason text,p_payload jsonb
) returns jsonb language sql stable set search_path='' as $pxk_procurement$
  select jsonb_build_object(
    'contract_version','SCHOOL-CATERING-PROCUREMENT.v1',
    'command_id',p_command,'correlation_id',p_command,
    'idempotency_key','pxk-procurement:'||p_command,'expected_version',p_expected,
    'requested_by_auth_subject','26000000-0000-4000-8000-000000000101'::uuid,
    'requested_at',transaction_timestamp()-interval '1 second',
    'reason_code',p_reason,'reason_note',null,'payload',p_payload);
$pxk_procurement$;
create function pg_temp.pxk_ungrouped_release_isolated(p_request jsonb)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare v_response jsonb; v_document jsonb;
begin
  delete from atlas_admin.school_cooking_group_memberships
    where school_id='26020000-0000-4000-8000-000000000021';
  v_response:=atlas_api.release_school_dispatch_document(p_request);
  v_document:=atlas_core.school_dispatch_release_json((v_response->>'school_dispatch_release_id')::uuid);
  v_response:=v_response||jsonb_build_object('captured_release',v_document);
  raise exception using errcode='PXK99';
exception when sqlstate 'PXK99' then return v_response;
end;
$$;
create function pg_temp.pxk_procurement_family(p_location uuid)
returns jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object(
    'service_date','2026-09-25'::date,'delivery_location_id',p_location,
    'ingredient_id','26020000-0000-4000-8000-000000000041'::uuid,
    'unit_id','26020000-0000-4000-8000-000000000031'::uuid,
    'expected_source_fingerprint',projection->>'source_fingerprint')
  from (select atlas_core.school_catering_family_projection(
    '2026-09-25',p_location,'26020000-0000-4000-8000-000000000041',
    '26020000-0000-4000-8000-000000000031') projection) source;
$$;
create function pg_temp.pxk_po_replace(p_command uuid,p_replaced uuid)
returns jsonb language sql stable security definer set search_path='' as $$
  select pg_temp.pxk_procurement_command(p_command,po.version,
    'SCHOOL_CATERING_PO_REPLACEMENT_CREATED',jsonb_build_object(
      'replaced_purchase_order_id',po.purchase_order_id,
      'expected_purchase_order_revision_id',revision.purchase_order_revision_id))
  from atlas_procurement.purchase_orders po
  join atlas_procurement.purchase_order_revisions revision
    on revision.purchase_order_id=po.purchase_order_id and revision.is_current
  where po.purchase_order_id=p_replaced;
$$;
create function pg_temp.pxk_po_release(p_command uuid,p_purchase_order uuid)
returns jsonb language sql stable security definer set search_path='' as $$
  select pg_temp.pxk_procurement_command(p_command,po.version,
    'SCHOOL_CATERING_PO_RELEASED',jsonb_build_object(
      'purchase_order_id',po.purchase_order_id,
      'expected_purchase_order_revision_id',revision.purchase_order_revision_id))
  from atlas_procurement.purchase_orders po
  join atlas_procurement.purchase_order_revisions revision
    on revision.purchase_order_id=po.purchase_order_id and revision.is_current
  where po.purchase_order_id=p_purchase_order;
$$;
grant execute on function pg_temp.pxk_read(),
  pg_temp.pxk_release(uuid,bigint,uuid,text),
  pg_temp.pxk_procurement_command(uuid,bigint,text,jsonb),
  pg_temp.pxk_procurement_family(uuid),pg_temp.pxk_po_replace(uuid,uuid),
  pg_temp.pxk_po_release(uuid,uuid)
  to authenticated;

set local role authenticated;
select set_config('request.jwt.claim.sub','26000000-0000-4000-8000-000000000101',true);
insert into pxk_results values('preview',
  atlas_api.get_school_dispatch_release_workbench(pg_temp.pxk_read()));
reset role;
select ok((select (response->>'success')::boolean
    and response #>> '{rows,0,state}'='READY'
  from pxk_results where name='preview'),
  'captured Location A PXK preview stays ready after the School default changes to B');
select is((select count(*)::integer from atlas_dispatch.school_dispatch_releases),0,
  'preview creates no PXK draft or other supporting write');
select ok((select response #>> '{rows,0,preview,lines,0,quantity}'='100.000000'
    and jsonb_array_length(response #> '{rows,0,preview,lines,0,sources}')=1
  from pxk_results where name='preview'),
  'preview returns lossless quantity and exact Confirmed Need/allocation/PO lineage');
select ok(not coalesce((atlas_core.school_dispatch_release_preview('2026-09-24',
    '26020000-0000-4000-8000-000000000021',
    '26020000-0000-4000-8000-000000000012')->>'ready')::boolean,false)
    and atlas_core.school_dispatch_release_preview('2026-09-24',
      '26020000-0000-4000-8000-000000000021',
      '26020000-0000-4000-8000-000000000012')->'blockers'
      @> '["NO_CURRENT_NEED"]'::jsonb
    and not (atlas_core.school_dispatch_release_preview('2026-09-24',
      '26020000-0000-4000-8000-000000000021',
      '26020000-0000-4000-8000-000000000012')->'blockers'
      @> '["SCHOOL_SCOPE_INVALID"]'::jsonb),
  'new same-Customer default Location B inherits no captured Location A Need');
select ok(not coalesce((atlas_core.school_dispatch_release_preview('2026-09-24',
    '26020000-0000-4000-8000-000000000021',
    '26020000-0000-4000-8000-000000000013')->>'ready')::boolean,false)
    and atlas_core.school_dispatch_release_preview('2026-09-24',
      '26020000-0000-4000-8000-000000000021',
      '26020000-0000-4000-8000-000000000013')->'blockers'
      @> '["SCHOOL_SCOPE_INVALID"]'::jsonb,
  'cross-Customer Delivery Location remains outside the School boundary');

set local role authenticated;
select set_config('request.jwt.claim.sub','26000000-0000-4000-8000-000000000101',true);
select is((atlas_api.release_school_dispatch_document(jsonb_set(
    pg_temp.pxk_release('26060000-0000-4000-8000-000000000010',0,null),
    '{reason_note}',to_jsonb(' padded note '::text)))->>'error_code'),
  'VALIDATION_FAILED','PXK release rejects an unnormalized document note');
reset role;

-- Relational authorization happens after capability verification and before any
-- document mutation. Use isolated success so the canonical GLOBAL path remains.
set local role authenticated;
select set_config('request.jwt.claim.sub','26000000-0000-4000-8000-000000000102',true);
select is((
  pg_temp.pxk_release_isolated(
    jsonb_set(
      pg_temp.pxk_release('26060000-0000-4000-8000-000000000011',0,null),
      '{requested_by_auth_subject}',
      to_jsonb('26000000-0000-4000-8000-000000000102'::uuid)
    )
  )->>'success'),'true',
  'School-scoped operator can release its authorized PXK');

select set_config('request.jwt.claim.sub','26000000-0000-4000-8000-000000000103',true);
select is((
  atlas_api.release_school_dispatch_document(
    jsonb_set(
      pg_temp.pxk_release('26060000-0000-4000-8000-000000000012',0,null),
      '{requested_by_auth_subject}',
      to_jsonb('26000000-0000-4000-8000-000000000103'::uuid)
    )
  )->>'error_code'),'SCOPE_DENIED',
  'wrong School scope cannot release another School PXK');

select set_config('request.jwt.claim.sub','26000000-0000-4000-8000-000000000104',true);
select is((
  atlas_api.get_school_dispatch_release_workbench(
    jsonb_set(
      pg_temp.pxk_read(),
      '{requested_by_auth_subject}',
      to_jsonb('26000000-0000-4000-8000-000000000104'::uuid)
    )
  )->>'error_code'),'CAPABILITY_DENIED',
  'relational scope never bypasses the required dispatch read capability');
select is((atlas_api.release_school_dispatch_document(jsonb_set(
    pg_temp.pxk_release('26060000-0000-4000-8000-000000000013',0,null),
    '{requested_by_auth_subject}',
    to_jsonb('26000000-0000-4000-8000-000000000104'::uuid)))->>'error_code'),
  'CAPABILITY_DENIED','School scope cannot bypass missing PXK release capability');
select is((atlas_api.get_school_fulfilment_reconciliation_workbench(
  jsonb_build_object('contract_version','SCHOOL-FULFILMENT-RECONCILIATION.v1',
    'requested_by_auth_subject','26000000-0000-4000-8000-000000000104',
    'correlation_id',gen_random_uuid(),'payload',jsonb_build_object(
      'date_start','2026-09-24','date_end','2026-09-24',
      'school_ids','[]'::jsonb,'search',null)))->>'error_code'),
  'CAPABILITY_DENIED','reconciliation independently requires dispatch read capability');
select set_config('request.jwt.claim.sub','26000000-0000-4000-8000-000000000101',true);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','26000000-0000-4000-8000-000000000101',true);
reset role;
insert into atlas_admin.cooking_groups(cooking_group_id,cooking_group_name,location_kind,host_school_id) values
 ('c7000000-0000-4000-8000-000000000001','Cooking X','SCHOOL','26020000-0000-4000-8000-000000000021'),
 ('c7000000-0000-4000-8000-000000000002','Công ty Thượng Hảo','COMPANY',null);
insert into atlas_admin.dispatch_groups(dispatch_group_id,dispatch_group_name) values('c7000000-0000-4000-8000-000000000031','Dispatch route X');
insert into atlas_admin.dispatch_group_members(school_id,dispatch_group_id) values('26020000-0000-4000-8000-000000000021','c7000000-0000-4000-8000-000000000031');
insert into atlas_admin.school_cooking_group_memberships(school_id,cooking_group_id) values
 ('26020000-0000-4000-8000-000000000021','c7000000-0000-4000-8000-000000000001');
select ok((select response->>'success'='true'
  and response#>'{captured_release,cooking_group_id}'='null'::jsonb
  and response#>'{captured_release,cooking_group_name}'='null'::jsonb
  from (select pg_temp.pxk_ungrouped_release_isolated(pg_temp.pxk_release(
    'c7000000-0000-4000-8000-000000000011',0,null)) response) captured),
  'actual new PXK release after clearing assignment freezes null cooking facts');
set local role authenticated;
insert into pxk_results values('release',atlas_api.release_school_dispatch_document(
  pg_temp.pxk_release('26060000-0000-4000-8000-000000000001',0,null,
    'Giao tại cổng phụ trước 06:00')));
insert into pxk_results values('release-replay',atlas_api.release_school_dispatch_document(
  pg_temp.pxk_release('26060000-0000-4000-8000-000000000001',0,null,
    'Giao tại cổng phụ trước 06:00')));
insert into pxk_results values('read-released',
  atlas_api.get_school_dispatch_release_workbench(pg_temp.pxk_read()));
reset role;
select ok((select (response->>'success')::boolean
    and response->>'document_number' like 'PXK-20260924-%'
  from pxk_results where name='release'),
  'explicit PXK release succeeds and assigns a server-owned official number');
select is((select response#>>'{rows,0,preview,lines,0,unit_name}' from pxk_results where name='preview'),
  'Kilôgam','PXK preview exposes the current human Unit name');
select is((select response#>>'{rows,0,current_release,lines,0,unit_name}' from pxk_results where name='read-released'),
  'Kilôgam','new PXK freezes the human Unit name');
select throws_ok($$update atlas_dispatch.school_dispatch_release_lines set unit_name_snapshot='Changed'$$,
  '23514','School dispatch release history is immutable.','PXK Unit name snapshot is immutable');
savepoint pxk_unit_history;
update atlas_admin.units set unit_name='Renamed master' where unit_id='26020000-0000-4000-8000-000000000031';
select is((select atlas_core.school_dispatch_release_json(school_dispatch_release_id)#>>'{lines,0,unit_name}'
  from atlas_dispatch.school_dispatch_releases where school_dispatch_release_id=
    (select (response->>'school_dispatch_release_id')::uuid from pxk_results where name='release')),
  'Kilôgam','PXK Unit output never follows later master changes');
set session_replication_role=replica;
update atlas_dispatch.school_dispatch_release_lines set unit_name_snapshot=null;
set session_replication_role=origin;
select ok((select atlas_core.school_dispatch_release_json(school_dispatch_release_id)#>'{lines,0,unit_name}'='null'::jsonb
  from atlas_dispatch.school_dispatch_releases where school_dispatch_release_id=
    (select (response->>'school_dispatch_release_id')::uuid from pxk_results where name='release')),
  'legacy Unit snapshot stays null without live-name backfill');
rollback to savepoint pxk_unit_history;
select ok((select release_status='RELEASED' and source_fingerprint is not null
    and school_name_snapshot='Trường Tiểu học Nguyễn Du'
    and school_display_order_snapshot=1
    and document_issuer_name_snapshot='CƠ SỞ CUNG CẤP THỰC PHẨM THƯỢNG HẢO'
    and document_issuer_address_snapshot='Địa chỉ PXK đã cấu hình'
    and note='Giao tại cổng phụ trước 06:00'
  from atlas_dispatch.school_dispatch_releases),
  'released PXK header stores immutable scope, display snapshots, and note');
select ok((select delivery_location_id='26020000-0000-4000-8000-000000000011'
    and delivery_location_id<>'26020000-0000-4000-8000-000000000012'
  from atlas_dispatch.school_dispatch_releases),
  'released PXK preserves captured Location A and never substitutes mutable default B');
select ok((select count(*)=1 from atlas_dispatch.school_dispatch_release_lines)
    and (select count(*)=1 from atlas_dispatch.school_dispatch_release_line_sources),
  'released PXK stores one immutable line and its exact typed source coverage');
select is((select response from pxk_results where name='release-replay'),
  (select response from pxk_results where name='release'),
  'exact PXK release replay returns the original outcome');
select ok((select response #>> '{rows,0,state}'='CURRENT'
    and (response #>> '{rows,0,current_release,export_ready}')::boolean
  from pxk_results where name='read-released'),
  'read model exposes the released immutable PXK as current and exportable');
select is((select cooking_group_name_snapshot from atlas_dispatch.school_dispatch_releases),
  'Cooking X','new PXK release freezes cooking X');
select ok((select bool_and(cooking_location_kind_snapshot='SCHOOL' and cooking_location_host_school_id_snapshot='26020000-0000-4000-8000-000000000021' and cooking_location_id_snapshot='c7000000-0000-4000-8000-000000000001' and dispatch_group_name_snapshot='Dispatch route X') from atlas_dispatch.school_dispatch_releases),'official capture includes explicit host and independent Dispatch facts');
select throws_ok($$update atlas_dispatch.school_dispatch_releases set dispatch_group_name_snapshot='Mutated'$$,'23514','School dispatch release history is immutable.','PXK Dispatch snapshot cannot be mutated');
update atlas_admin.dispatch_groups set dispatch_group_name='Dispatch renamed' where dispatch_group_id='c7000000-0000-4000-8000-000000000031';
delete from atlas_admin.dispatch_group_members where school_id='26020000-0000-4000-8000-000000000021';
update atlas_admin.school_cooking_group_memberships set cooking_group_id='c7000000-0000-4000-8000-000000000002'
where school_id='26020000-0000-4000-8000-000000000021';
update atlas_admin.cooking_groups set cooking_group_name='Cooking X renamed'
where cooking_group_id='c7000000-0000-4000-8000-000000000001';
select ok((select bool_and(cooking_location_kind_snapshot='SCHOOL' and cooking_location_host_school_id_snapshot='26020000-0000-4000-8000-000000000021' and cooking_location_id_snapshot='c7000000-0000-4000-8000-000000000001' and dispatch_group_name_snapshot='Dispatch route X') from atlas_dispatch.school_dispatch_releases),'historical canonical location and Dispatch facts remain frozen');
select is((select atlas_core.school_dispatch_release_json(school_dispatch_release_id)->>'cooking_group_name'
  from atlas_dispatch.school_dispatch_releases),'Cooking X','historical PXK read retains X after assignment and rename');
update atlas_admin.schools
set school_name='Tên trường đã đổi',display_order=9,
  dispatch_document_issuer_name='Tên đơn vị đã đổi',
  dispatch_document_issuer_address='Địa chỉ đơn vị đã đổi'
where school_id='26020000-0000-4000-8000-000000000021';
set local role authenticated;
select set_config('request.jwt.claim.sub','26000000-0000-4000-8000-000000000101',true);
insert into pxk_results values('read-released-after-school-change',
  atlas_api.get_school_dispatch_release_workbench(pg_temp.pxk_read()));
reset role;
select ok((select
    response#>>'{rows,0,current_release,school_name}'='Trường Tiểu học Nguyễn Du'
    and response#>>'{rows,0,current_release,school_display_order}'='1'
    and response#>>'{rows,0,current_release,document_issuer_name}'=
      'CƠ SỞ CUNG CẤP THỰC PHẨM THƯỢNG HẢO'
    and response#>>'{rows,0,current_release,document_issuer_address}'=
      'Địa chỉ PXK đã cấu hình'
  from pxk_results where name='read-released-after-school-change'),
  'released PXK header and School order do not follow later master changes');
update atlas_admin.schools
set school_name='Trường Tiểu học Nguyễn Du',display_order=1,
  dispatch_document_issuer_name='CƠ SỞ CUNG CẤP THỰC PHẨM THƯỢNG HẢO',
  dispatch_document_issuer_address='Địa chỉ PXK đã cấu hình'
where school_id='26020000-0000-4000-8000-000000000021';

savepoint legacy_pxk_export_guard;
set session_replication_role=replica;
update atlas_dispatch.school_dispatch_releases
set document_issuer_name_snapshot=null
where release_status='RELEASED';
set session_replication_role=origin;
set local role authenticated;
select set_config('request.jwt.claim.sub','26000000-0000-4000-8000-000000000101',true);
insert into pxk_results values('read-legacy-release',
  atlas_api.get_school_dispatch_release_workbench(pg_temp.pxk_read()));
reset role;
select ok((select
    not (response#>>'{rows,0,current_release,export_ready}')::boolean
    and not (response#>>'{rows,0,allowed_actions,export}')::boolean
  from pxk_results where name='read-legacy-release'),
  'legacy PXK without the direct header snapshot fails closed for export');
rollback to savepoint legacy_pxk_export_guard;
select ok((select definition !~* '\m(stock|inventory|lot|reservation|pick|trip|vehicle|driver|load)\M'
  from (select pg_get_functiondef(
    'atlas_core.school_dispatch_release_preview(date,uuid,uuid)'::regprocedure)
    ||pg_get_functiondef(
      'atlas_core.procurement_read_school_dispatch_release_preview(date,uuid,uuid,jsonb)'::regprocedure)
    definition) source),
  'PXK readiness has no stock, receiving, trip, vehicle, driver, or load dependency');
select ok((select wrapper ~ 'atlas_core.procurement_read_school_dispatch_release_preview'
    and calculation ~ 'contribution_start'
    and calculation !~ 'contribution_quantity\s*\*\s*split\.split_ratio'
  from (select pg_get_functiondef(
    'atlas_core.school_dispatch_release_preview(date,uuid,uuid)'::regprocedure) wrapper,
    pg_get_functiondef(
      'atlas_core.procurement_read_school_dispatch_release_preview(date,uuid,uuid,jsonb)'::regprocedure)
      calculation) source),
  'PXK source coverage uses exact residual-preserving contribution/supplier ranges');
select throws_ok($$update atlas_dispatch.school_dispatch_release_lines set quantity=99$$,
  '23514','School dispatch release history is immutable.',
  'released PXK line facts cannot be edited');

-- Exact evidence changes require an explicit successor PXK. Direct fixture updates
-- model already-approved upstream successor facts without invoking unrelated APIs.
set session_replication_role=replica;
update atlas_procurement.school_catering_allocation_family_revisions set is_current=false
where family_revision_id='26040000-0000-4000-8000-000000000002';
insert into atlas_procurement.school_catering_allocation_family_revisions(
  family_revision_id,family_id,revision_number,is_current,predecessor_revision_id,
  source_purchase_handoff_revision_id,source_fingerprint,family_quantity,unit_id,
  accepted_by_actor_id,command_id,decision_origin,source_kind)
select '26040000-0000-4000-8000-000000000012','26040000-0000-4000-8000-000000000001',
  2,true,'26040000-0000-4000-8000-000000000002',
  '26030000-0000-4000-8000-000000000022',
  atlas_core.school_catering_family_projection('2026-09-24',
    '26020000-0000-4000-8000-000000000011','26020000-0000-4000-8000-000000000041',
    '26020000-0000-4000-8000-000000000031')->>'source_fingerprint',100,
  '26020000-0000-4000-8000-000000000031','26000000-0000-4000-8000-000000000001',
  '26040000-0000-4000-8000-000000000013','MANUAL','PURCHASE_HANDOFF';
insert into atlas_procurement.school_catering_allocation_family_contributions(
  family_contribution_id,family_revision_id,purchase_handoff_line_revision_id,
  contribution_quantity)
values('26040000-0000-4000-8000-000000000014','26040000-0000-4000-8000-000000000012',
  '26030000-0000-4000-8000-000000000024',100);
insert into atlas_procurement.school_catering_allocation_supplier_splits(
  supplier_split_id,family_revision_id,supplier_id,allocated_quantity,split_ratio,
  decision_origin)
values('26040000-0000-4000-8000-000000000015','26040000-0000-4000-8000-000000000012',
  '26020000-0000-4000-8000-000000000051',100,1,'MANUAL');
update atlas_procurement.purchase_orders set purchase_order_status='SUPERSEDED'
where purchase_order_id='26050000-0000-4000-8000-000000000001';
insert into atlas_procurement.purchase_orders(
  purchase_order_id,supplier_id,document_number,purchase_order_status,version,
  purchase_order_kind,school_catering_service_date,replaces_purchase_order_id)
values('26050000-0000-4000-8000-000000000011','26020000-0000-4000-8000-000000000051',
  'PO-20260924-REPLACEMENT','RELEASED_TO_SUPPLIER',2,'SCHOOL_CATERING','2026-09-24',
  '26050000-0000-4000-8000-000000000001');
insert into atlas_procurement.purchase_order_revisions(
  purchase_order_revision_id,purchase_order_id,revision_number,revision_kind,
  revision_status,is_current,service_date,delivery_location_id,supplier_name_snapshot,
  delivery_location_snapshot,released_by_actor_id,released_at)
values('26050000-0000-4000-8000-000000000012','26050000-0000-4000-8000-000000000011',
  2,'SUPERSEDING','RELEASED_TO_SUPPLIER',true,'2026-09-24',null,'NCC An Phú',
  'Nhiều điểm giao','26000000-0000-4000-8000-000000000001',transaction_timestamp());
insert into atlas_procurement.purchase_order_lines(
  purchase_order_line_id,purchase_order_id,school_catering_allocation_family_id)
values('26050000-0000-4000-8000-000000000013','26050000-0000-4000-8000-000000000011',
  '26040000-0000-4000-8000-000000000001');
insert into atlas_procurement.purchase_order_line_revisions(
  purchase_order_line_revision_id,purchase_order_revision_id,purchase_order_line_id,
  school_catering_allocation_supplier_split_id,ingredient_id,ordered_quantity,unit_id,
  delivery_location_id,service_date)
values('26050000-0000-4000-8000-000000000014','26050000-0000-4000-8000-000000000012',
  '26050000-0000-4000-8000-000000000013','26040000-0000-4000-8000-000000000015',
  '26020000-0000-4000-8000-000000000041',100,'26020000-0000-4000-8000-000000000031',
  '26020000-0000-4000-8000-000000000011','2026-09-24');
set session_replication_role=origin;

set local role authenticated;
select set_config('request.jwt.claim.sub','26000000-0000-4000-8000-000000000101',true);
insert into pxk_results values('read-replacement-required',
  atlas_api.get_school_dispatch_release_workbench(pg_temp.pxk_read()));
insert into pxk_results values('release-successor',atlas_api.release_school_dispatch_document(
  pg_temp.pxk_release('26060000-0000-4000-8000-000000000002',1,
    (select (response->>'school_dispatch_release_id')::uuid
     from pxk_results where name='release'))));
reset role;
select is((select response #>> '{rows,0,state}' from pxk_results
  where name='read-replacement-required'),'REPLACEMENT_REQUIRED',
  'changed exact allocation/PO membership derives PXK replacement-required');
select ok((select (response->>'success')::boolean and response->>'document_number'
    is distinct from (select response->>'document_number' from pxk_results where name='release')
  from pxk_results where name='release-successor'),
  'explicit PXK successor release creates a distinct official document');
select ok((select count(*) filter(where release_status='SUPERSEDED')=1
    and count(*) filter(where release_status='RELEASED')=1
    and count(distinct document_number)=2
  from atlas_dispatch.school_dispatch_releases),
  'successor release atomically supersedes the prior PXK and preserves both documents');

select is((select cooking_group_name_snapshot from atlas_dispatch.school_dispatch_releases where release_status='RELEASED'),
  'Công ty Thượng Hảo','new PXK successor captures current cooking Y');
delete from atlas_admin.school_cooking_group_memberships where school_id='26020000-0000-4000-8000-000000000021';
select ok((select bool_and(cooking_group_name_snapshot=case release_status when 'SUPERSEDED' then 'Cooking X' else 'Công ty Thượng Hảo' end)
  from atlas_dispatch.school_dispatch_releases),'removal preserves both historical PXK snapshots');
-- Move the allocation entirely to supplier B without recording cancellation or
-- replacement PO evidence. The factual correction stands; PXK must stop.
set session_replication_role=replica;
update atlas_procurement.school_catering_allocation_family_revisions set is_current=false
where family_revision_id='26040000-0000-4000-8000-000000000012';
insert into atlas_procurement.school_catering_allocation_family_revisions(
  family_revision_id,family_id,revision_number,is_current,predecessor_revision_id,
  source_purchase_handoff_revision_id,source_fingerprint,family_quantity,unit_id,
  accepted_by_actor_id,command_id,decision_origin,source_kind)
select '26040000-0000-4000-8000-000000000022','26040000-0000-4000-8000-000000000001',
  3,true,'26040000-0000-4000-8000-000000000012',
  '26030000-0000-4000-8000-000000000022',
  atlas_core.school_catering_family_projection('2026-09-24',
    '26020000-0000-4000-8000-000000000011','26020000-0000-4000-8000-000000000041',
    '26020000-0000-4000-8000-000000000031')->>'source_fingerprint',100,
  '26020000-0000-4000-8000-000000000031','26000000-0000-4000-8000-000000000001',
  '26040000-0000-4000-8000-000000000023','MANUAL','PURCHASE_HANDOFF';
insert into atlas_procurement.school_catering_allocation_family_contributions(
  family_contribution_id,family_revision_id,purchase_handoff_line_revision_id,
  contribution_quantity)
values('26040000-0000-4000-8000-000000000024','26040000-0000-4000-8000-000000000022',
  '26030000-0000-4000-8000-000000000024',100);
insert into atlas_procurement.school_catering_allocation_supplier_splits(
  supplier_split_id,family_revision_id,supplier_id,allocated_quantity,split_ratio,
  decision_origin)
values('26040000-0000-4000-8000-000000000025','26040000-0000-4000-8000-000000000022',
  '26020000-0000-4000-8000-000000000052',100,1,'MANUAL');
set session_replication_role=origin;

set local role authenticated;
select set_config('request.jwt.claim.sub','26000000-0000-4000-8000-000000000101',true);
insert into pxk_results values('read-cancellation-blocked',
  atlas_api.get_school_dispatch_release_workbench(pg_temp.pxk_read()));
insert into pxk_results values('release-cancellation-blocked',
  atlas_api.release_school_dispatch_document(pg_temp.pxk_release(
    '26060000-0000-4000-8000-000000000003',1,
    (select (response->>'school_dispatch_release_id')::uuid
     from pxk_results where name='release-successor'))));
reset role;
select ok((select response #>> '{rows,0,state}'='BLOCKED'
    and response #> '{rows,0,blockers}' @> '["CANCELLATION_REQUIRED"]'::jsonb
  from pxk_results where name='read-cancellation-blocked'),
  'PXK-SCOPE-04 relevant removed-supplier commitment blocks PXK');
select is((select response->>'error_code' from pxk_results
  where name='release-cancellation-blocked'),'PXK_NOT_READY',
  'PXK command rechecks and rejects unresolved removed-supplier commitment');
select ok(not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='atlas_api' and p.proname ilike '%school%catering%cancel%'),
  'PXK slice introduces no supplier-cancellation command');
select ok((select count(*)=2 from atlas_core.command_receipts
    where command_name='release_school_dispatch_document' and outcome='COMPLETED')
  and (select count(*)=2 from atlas_audit.domain_events
    where event_type='SchoolDispatchDocumentReleased')
  and (select count(*)=2 from atlas_audit.audit_events
    where event_type='SchoolDispatchDocumentReleased'),
  'each successful PXK release records exactly one receipt, event, and audit record');

-- Scope-currentness regression at one separate service date. School A and B start
-- on one complete Supplier 1 PO, then only B's allocation/commitment changes.
set session_replication_role=replica;
insert into atlas_planning.confirmed_need_batches(
  confirmed_need_batch_id,period_start,period_end,batch_status,version,
  created_by_actor_id,source_kind,origin_need_generation_run_id,
  origin_need_generation_run_version,origin_need_generation_release_snapshot_id,
  current_need_generation_run_id,current_need_generation_run_version,
  current_need_generation_release_snapshot_id)
values('26130000-0000-4000-8000-000000000001','2026-09-25','2026-09-25',
  'RELEASED_FOR_PURCHASE_HANDOFF',1,'26000000-0000-4000-8000-000000000001',
  'NEED_GENERATION','26130000-0000-4000-8000-000000000002',1,
  '26130000-0000-4000-8000-000000000003','26130000-0000-4000-8000-000000000002',1,
  '26130000-0000-4000-8000-000000000003');
insert into atlas_planning.confirmed_need_lines(
  confirmed_need_line_id,confirmed_need_batch_id,source_kind,service_date,customer_id,
  school_id,delivery_location_id,ingredient_id,controlled_unit_id,
  current_confirmed_need_line_decision_id)
values
  ('26130000-0000-4000-8000-000000000011','26130000-0000-4000-8000-000000000001',
    'NEED_GENERATION','2026-09-25','26020000-0000-4000-8000-000000000001',
    '26020000-0000-4000-8000-000000000021','26020000-0000-4000-8000-000000000011',
    '26020000-0000-4000-8000-000000000041','26020000-0000-4000-8000-000000000031',
    '26130000-0000-4000-8000-000000000013'),
  ('26130000-0000-4000-8000-000000000021','26130000-0000-4000-8000-000000000001',
    'NEED_GENERATION','2026-09-25','26020000-0000-4000-8000-000000000001',
    '26020000-0000-4000-8000-000000000022','26020000-0000-4000-8000-000000000012',
    '26020000-0000-4000-8000-000000000041','26020000-0000-4000-8000-000000000031',
    '26130000-0000-4000-8000-000000000023');
insert into atlas_planning.confirmed_need_line_revisions(
  confirmed_need_line_revision_id,confirmed_need_line_id,revision_number,ingredient_id,
  theoretical_quantity,confirmed_quantity,unit_id,revision_status,is_current,
  created_by_actor_id,source_kind,confirmed_need_batch_id,need_generation_run_id,
  need_generation_run_version,need_generation_release_snapshot_id,service_date,
  customer_id,school_id,delivery_location_id)
values
  ('26130000-0000-4000-8000-000000000012','26130000-0000-4000-8000-000000000011',
    1,'26020000-0000-4000-8000-000000000041',100,100,
    '26020000-0000-4000-8000-000000000031','RELEASED',true,
    '26000000-0000-4000-8000-000000000001','NEED_GENERATION',
    '26130000-0000-4000-8000-000000000001','26130000-0000-4000-8000-000000000002',1,
    '26130000-0000-4000-8000-000000000003','2026-09-25',
    '26020000-0000-4000-8000-000000000001','26020000-0000-4000-8000-000000000021',
    '26020000-0000-4000-8000-000000000011'),
  ('26130000-0000-4000-8000-000000000022','26130000-0000-4000-8000-000000000021',
    1,'26020000-0000-4000-8000-000000000041',40,40,
    '26020000-0000-4000-8000-000000000031','RELEASED',true,
    '26000000-0000-4000-8000-000000000001','NEED_GENERATION',
    '26130000-0000-4000-8000-000000000001','26130000-0000-4000-8000-000000000002',1,
    '26130000-0000-4000-8000-000000000003','2026-09-25',
    '26020000-0000-4000-8000-000000000001','26020000-0000-4000-8000-000000000022',
    '26020000-0000-4000-8000-000000000012');
insert into atlas_planning.confirmed_need_line_decisions(
  confirmed_need_line_decision_id,confirmed_need_batch_id,confirmed_need_line_id,
  confirmed_need_line_revision_id,source_kind,service_date,customer_id,school_id,
  delivery_location_id,ingredient_id,unit_id,decision_number,decision_kind,
  planning_quantity_policy_id,planning_quantity_policy_revision_id,
  theoretical_quantity_before,proposed_quantity_before,confirmed_quantity_after,
  planning_tick_count,reason_code,decided_by_actor_id,decided_at,command_id,
  confirmed_need_batch_version)
values
  ('26130000-0000-4000-8000-000000000013','26130000-0000-4000-8000-000000000001',
    '26130000-0000-4000-8000-000000000011','26130000-0000-4000-8000-000000000012',
    'NEED_GENERATION','2026-09-25','26020000-0000-4000-8000-000000000001',
    '26020000-0000-4000-8000-000000000021','26020000-0000-4000-8000-000000000011',
    '26020000-0000-4000-8000-000000000041','26020000-0000-4000-8000-000000000031',
    1,'UNCHANGED_PROPOSAL_ACCEPTED','26130000-0000-4000-8000-000000000014',
    '26130000-0000-4000-8000-000000000015',100,100,100,100000000,
    'PROPOSAL_ACCEPTED','26000000-0000-4000-8000-000000000001',transaction_timestamp(),
    '26130000-0000-4000-8000-000000000016',1),
  ('26130000-0000-4000-8000-000000000023','26130000-0000-4000-8000-000000000001',
    '26130000-0000-4000-8000-000000000021','26130000-0000-4000-8000-000000000022',
    'NEED_GENERATION','2026-09-25','26020000-0000-4000-8000-000000000001',
    '26020000-0000-4000-8000-000000000022','26020000-0000-4000-8000-000000000012',
    '26020000-0000-4000-8000-000000000041','26020000-0000-4000-8000-000000000031',
    1,'UNCHANGED_PROPOSAL_ACCEPTED','26130000-0000-4000-8000-000000000024',
    '26130000-0000-4000-8000-000000000025',40,40,40,40000000,
    'PROPOSAL_ACCEPTED','26000000-0000-4000-8000-000000000001',transaction_timestamp(),
    '26130000-0000-4000-8000-000000000026',1);
insert into atlas_planning.purchase_handoff_batches(
  purchase_handoff_batch_id,confirmed_need_batch_id,period_start,period_end,
  handoff_status,created_by_actor_id)
values('26130000-0000-4000-8000-000000000031','26130000-0000-4000-8000-000000000001',
  '2026-09-25','2026-09-25','RELEASED_TO_PROCUREMENT',
  '26000000-0000-4000-8000-000000000001');
insert into atlas_planning.purchase_handoff_revisions(
  purchase_handoff_revision_id,purchase_handoff_batch_id,revision_number,
  revision_status,is_current,released_by_actor_id,released_at)
values('26130000-0000-4000-8000-000000000032','26130000-0000-4000-8000-000000000031',
  1,'RELEASED_TO_PROCUREMENT',true,'26000000-0000-4000-8000-000000000001',
  transaction_timestamp());
insert into atlas_planning.purchase_handoff_lines(
  purchase_handoff_line_id,purchase_handoff_batch_id,confirmed_need_line_id)
values
  ('26130000-0000-4000-8000-000000000033','26130000-0000-4000-8000-000000000031',
    '26130000-0000-4000-8000-000000000011'),
  ('26130000-0000-4000-8000-000000000034','26130000-0000-4000-8000-000000000031',
    '26130000-0000-4000-8000-000000000021');
insert into atlas_planning.purchase_handoff_line_revisions(
  purchase_handoff_line_revision_id,purchase_handoff_revision_id,purchase_handoff_line_id,
  confirmed_need_line_revision_id,ingredient_id,handoff_quantity,unit_id,service_date,
  delivery_location_id)
values
  ('26130000-0000-4000-8000-000000000035','26130000-0000-4000-8000-000000000032',
    '26130000-0000-4000-8000-000000000033','26130000-0000-4000-8000-000000000012',
    '26020000-0000-4000-8000-000000000041',100,'26020000-0000-4000-8000-000000000031',
    '2026-09-25','26020000-0000-4000-8000-000000000011'),
  ('26130000-0000-4000-8000-000000000036','26130000-0000-4000-8000-000000000032',
    '26130000-0000-4000-8000-000000000034','26130000-0000-4000-8000-000000000022',
    '26020000-0000-4000-8000-000000000041',40,'26020000-0000-4000-8000-000000000031',
    '2026-09-25','26020000-0000-4000-8000-000000000012');
insert into atlas_planning.purchase_demand_references(
  purchase_demand_reference_id,purchase_handoff_line_revision_id,
  confirmed_need_snapshot_line_id,approved_quantity,unit_id,source_kind)
values
  ('26130000-0000-4000-8000-000000000037','26130000-0000-4000-8000-000000000035',
    '26130000-0000-4000-8000-000000000039',100,'26020000-0000-4000-8000-000000000031',
    'NEED_GENERATION'),
  ('26130000-0000-4000-8000-000000000038','26130000-0000-4000-8000-000000000036',
    '26130000-0000-4000-8000-000000000040',40,'26020000-0000-4000-8000-000000000031',
    'NEED_GENERATION');
insert into atlas_procurement.school_catering_allocation_families(
  family_id,service_date,delivery_location_id,ingredient_id,unit_id)
values
  ('26140000-0000-4000-8000-000000000001','2026-09-25',
    '26020000-0000-4000-8000-000000000011','26020000-0000-4000-8000-000000000041',
    '26020000-0000-4000-8000-000000000031'),
  ('26140000-0000-4000-8000-000000000011','2026-09-25',
    '26020000-0000-4000-8000-000000000012','26020000-0000-4000-8000-000000000041',
    '26020000-0000-4000-8000-000000000031');
insert into atlas_procurement.school_catering_allocation_family_revisions(
  family_revision_id,family_id,revision_number,is_current,
  source_purchase_handoff_revision_id,source_fingerprint,family_quantity,unit_id,
  accepted_by_actor_id,command_id,decision_origin,source_kind)
select '26140000-0000-4000-8000-000000000002'::uuid,
  '26140000-0000-4000-8000-000000000001'::uuid,
  1,true,'26130000-0000-4000-8000-000000000032'::uuid,
  atlas_core.school_catering_family_projection('2026-09-25',
    '26020000-0000-4000-8000-000000000011','26020000-0000-4000-8000-000000000041',
    '26020000-0000-4000-8000-000000000031')->>'source_fingerprint',100,
  '26020000-0000-4000-8000-000000000031'::uuid,
  '26000000-0000-4000-8000-000000000001'::uuid,
  '26140000-0000-4000-8000-000000000003'::uuid,'MANUAL','PURCHASE_HANDOFF'
union all
select '26140000-0000-4000-8000-000000000012','26140000-0000-4000-8000-000000000011',
  1,true,'26130000-0000-4000-8000-000000000032',
  atlas_core.school_catering_family_projection('2026-09-25',
    '26020000-0000-4000-8000-000000000012','26020000-0000-4000-8000-000000000041',
    '26020000-0000-4000-8000-000000000031')->>'source_fingerprint',40,
  '26020000-0000-4000-8000-000000000031','26000000-0000-4000-8000-000000000001',
  '26140000-0000-4000-8000-000000000013','MANUAL','PURCHASE_HANDOFF';
insert into atlas_procurement.school_catering_allocation_family_contributions(
  family_contribution_id,family_revision_id,purchase_handoff_line_revision_id,
  contribution_quantity)
values
  ('26140000-0000-4000-8000-000000000003','26140000-0000-4000-8000-000000000002',
    '26130000-0000-4000-8000-000000000035',100),
  ('26140000-0000-4000-8000-000000000013','26140000-0000-4000-8000-000000000012',
    '26130000-0000-4000-8000-000000000036',40);
insert into atlas_procurement.school_catering_allocation_supplier_splits(
  supplier_split_id,family_revision_id,supplier_id,allocated_quantity,split_ratio,
  decision_origin)
values
  ('26140000-0000-4000-8000-000000000004','26140000-0000-4000-8000-000000000002',
    '26020000-0000-4000-8000-000000000051',100,1,'MANUAL'),
  ('26140000-0000-4000-8000-000000000014','26140000-0000-4000-8000-000000000012',
    '26020000-0000-4000-8000-000000000051',40,1,'MANUAL');
insert into atlas_procurement.purchase_orders(
  purchase_order_id,supplier_id,document_number,purchase_order_status,version,
  purchase_order_kind,school_catering_service_date)
values('26150000-0000-4000-8000-000000000001','26020000-0000-4000-8000-000000000051',
  'PO-20260925-SHARED','RELEASED_TO_SUPPLIER',2,'SCHOOL_CATERING','2026-09-25');
insert into atlas_procurement.purchase_order_revisions(
  purchase_order_revision_id,purchase_order_id,revision_number,revision_kind,
  revision_status,is_current,service_date,delivery_location_id,supplier_name_snapshot,
  delivery_location_snapshot,released_by_actor_id,released_at)
values('26150000-0000-4000-8000-000000000002','26150000-0000-4000-8000-000000000001',
  2,'SUPERSEDING','RELEASED_TO_SUPPLIER',true,'2026-09-25',null,'NCC An Phú',
  'Nhiều điểm giao','26000000-0000-4000-8000-000000000001',transaction_timestamp());
insert into atlas_procurement.purchase_order_lines(
  purchase_order_line_id,purchase_order_id,school_catering_allocation_family_id)
values
  ('26150000-0000-4000-8000-000000000003','26150000-0000-4000-8000-000000000001',
    '26140000-0000-4000-8000-000000000001'),
  ('26150000-0000-4000-8000-000000000004','26150000-0000-4000-8000-000000000001',
    '26140000-0000-4000-8000-000000000011');
insert into atlas_procurement.purchase_order_line_revisions(
  purchase_order_line_revision_id,purchase_order_revision_id,purchase_order_line_id,
  school_catering_allocation_supplier_split_id,ingredient_id,ordered_quantity,unit_id,
  delivery_location_id,service_date)
values
  ('26150000-0000-4000-8000-000000000005','26150000-0000-4000-8000-000000000002',
    '26150000-0000-4000-8000-000000000003','26140000-0000-4000-8000-000000000004',
    '26020000-0000-4000-8000-000000000041',100,'26020000-0000-4000-8000-000000000031',
    '26020000-0000-4000-8000-000000000011','2026-09-25'),
  ('26150000-0000-4000-8000-000000000006','26150000-0000-4000-8000-000000000002',
    '26150000-0000-4000-8000-000000000004','26140000-0000-4000-8000-000000000014',
    '26020000-0000-4000-8000-000000000041',40,'26020000-0000-4000-8000-000000000031',
    '26020000-0000-4000-8000-000000000012','2026-09-25');

set session_replication_role=origin;

-- ATLAS-PXK-EXACT-SCHOOL-SCOPE-01: A's mutable default now equals B's captured
-- location. School A must keep captured Location A without acquiring School B.
update atlas_admin.schools set default_delivery_location_id='26020000-0000-4000-8000-000000000012'
where school_id='26020000-0000-4000-8000-000000000021';
create function pg_temp.pxk_exact_read(p_reconciliation boolean,p_date date default '2026-09-25')
returns jsonb language plpgsql volatile as $read$
declare request jsonb; response jsonb;
begin
 request:=jsonb_build_object('contract_version',case when p_reconciliation
   then 'SCHOOL-FULFILMENT-RECONCILIATION.v1' else 'SCHOOL-DISPATCH-RELEASE.v1' end,
   'requested_by_auth_subject','26000000-0000-4000-8000-000000000102',
   'correlation_id',gen_random_uuid(),'payload',jsonb_build_object(
    'date_start',p_date,'date_end',p_date,'school_ids','[]'::jsonb,'search',null));
 perform set_config('request.jwt.claim.sub','26000000-0000-4000-8000-000000000102',true);
 set local role authenticated;
 if p_reconciliation then response:=atlas_api.get_school_fulfilment_reconciliation_workbench(request);
 else response:=atlas_api.get_school_dispatch_release_workbench(request); end if;
 reset role;
 return response;
end;
$read$;
create function pg_temp.pxk_exact_release_request(p_school uuid,p_location uuid)
returns jsonb language sql volatile as $request$
 select jsonb_build_object('contract_version','SCHOOL-DISPATCH-RELEASE.v1',
  'requested_by_auth_subject','26000000-0000-4000-8000-000000000102',
  'command_id',command,'correlation_id',command,'idempotency_key','exact-school:'||command,
  'requested_at',transaction_timestamp(),'reason_code','SCHOOL_DISPATCH_DOCUMENT_RELEASED',
  'reason_note',null,'expected_version',0,'payload',jsonb_build_object(
   'service_date','2026-09-25','school_id',p_school,'delivery_location_id',p_location,
   'expected_source_fingerprint',atlas_core.school_dispatch_release_preview(
     '2026-09-25',p_school,p_location)->>'source_fingerprint','predecessor_release_id',null))
 from (select gen_random_uuid() command) generated;
$request$;
create function pg_temp.pxk_exact_write_counts() returns jsonb language sql stable as $counts$
 select jsonb_build_array(
  (select count(*) from atlas_core.command_receipts),
  (select count(*) from atlas_audit.domain_events),
  (select count(*) from atlas_audit.audit_events),
  (select count(*) from atlas_dispatch.school_dispatch_releases),
  (select count(*) from atlas_dispatch.school_dispatch_release_lines),
  (select count(*) from atlas_dispatch.school_dispatch_release_line_sources));
$counts$;
create function pg_temp.pxk_exact_scope_cases() returns setof text language plpgsql as $cases$
declare
 c record; response jsonb; request jsonb; before_counts jsonb; actual text[];
 school_a uuid:='26020000-0000-4000-8000-000000000021';
 school_b uuid:='26020000-0000-4000-8000-000000000022';
 location_a uuid:='26020000-0000-4000-8000-000000000011';
 location_b uuid:='26020000-0000-4000-8000-000000000012';
 actor uuid:='26000000-0000-4000-8000-000000000002';
 frozen text; first_response jsonb; second_response jsonb; replay jsonb; same_actor_audit boolean;
 missing_capability uuid;
begin
 select md5(string_agg(to_jsonb(r)::text,'' order by r.school_dispatch_release_id)) into frozen
 from atlas_dispatch.school_dispatch_releases r;
 for c in select * from (values
  ('School A','SCHOOL',21,null,null,'ACTIVE',false,false,array['A'],false),
  ('School B','SCHOOL',22,null,null,'ACTIVE',false,false,array['B'],true),
  ('Location A','DELIVERY_LOCATION',null,11,null,'ACTIVE',false,false,array['A'],false),
  ('Location B','DELIVERY_LOCATION',null,12,null,'ACTIVE',false,false,array['B'],true),
  ('Customer','CUSTOMER',null,null,1,'ACTIVE',false,false,array['A','B'],true),
  ('GLOBAL','GLOBAL',null,null,null,'ACTIVE',false,false,array['A','B'],true),
  ('other Customer','CUSTOMER',null,null,2,'ACTIVE',false,false,array[]::text[],false),
  ('other location','DELIVERY_LOCATION',null,13,null,'ACTIVE',false,false,array[]::text[],false),
  ('revoked','SCHOOL',21,null,null,'REVOKED',false,false,array[]::text[],false),
  ('inactive expired status','SCHOOL',21,null,null,'EXPIRED',false,false,array[]::text[],false),
  ('expired time','SCHOOL',21,null,null,'ACTIVE',false,true,array[]::text[],false),
  ('future time','SCHOOL',21,null,null,'ACTIVE',true,false,array[]::text[],false)
 ) test(name,kind,school,location,customer,status,future,expired,want,release_b)
 loop
  delete from atlas_core.actor_scopes where actor_id=actor;
  insert into atlas_core.actor_scopes(actor_id,scope_kind,school_id,delivery_location_id,
   customer_id,scope_status,effective_from,effective_to)
  values(actor,c.kind,
   case c.school when 21 then school_a when 22 then school_b end,
   case c.location when 11 then location_a when 12 then location_b
    when 13 then '26020000-0000-4000-8000-000000000013'::uuid end,
   case c.customer when 1 then '26020000-0000-4000-8000-000000000001'::uuid
    when 2 then '26020000-0000-4000-8000-000000000002'::uuid end,c.status,
   transaction_timestamp()+case when c.future then interval '1 day' else interval '-2 days' end,
   case when c.expired then transaction_timestamp()-interval '1 day' end);
  before_counts:=pg_temp.pxk_exact_write_counts();
  response:=pg_temp.pxk_exact_read(false);
  select coalesce(array_agg(case row->>'school_id' when school_a::text then 'A'
   when school_b::text then 'B' else 'UNEXPECTED' end order by row->>'school_id'),array[]::text[])
  into actual from jsonb_array_elements(response->'rows') row;
  return next ok(response->>'success'='true' and actual=c.want,
   'EXACT-SCHOOL PXK read: '||c.name);
  response:=pg_temp.pxk_exact_read(true);
  select coalesce(array_agg(case row->>'school_id' when school_a::text then 'A'
   when school_b::text then 'B' else 'UNEXPECTED' end order by row->>'school_id'),array[]::text[])
  into actual from jsonb_array_elements(response->'rows') row;
  return next ok(response->>'success'='true' and actual=c.want,
   'EXACT-SCHOOL reconciliation: '||c.name);
  request:=pg_temp.pxk_exact_release_request(school_b,location_b);
  set local role authenticated;
  response:=pg_temp.pxk_release_isolated(request);
  reset role;
  return next ok(case when c.release_b then response->>'success'='true'
   else response->>'error_code'='SCOPE_DENIED' end,
   'EXACT-SCHOOL release B: '||c.name);
  return next is(pg_temp.pxk_exact_write_counts(),before_counts,
   'EXACT-SCHOOL reads and denied/isolated release leave zero writes: '||c.name);
 end loop;
 -- One staff member has both task capabilities and two explicit School scopes.
 delete from atlas_core.actor_scopes where actor_id=actor;
 insert into atlas_core.actor_scopes(actor_id,scope_kind,school_id)
 values(actor,'SCHOOL',school_a),(actor,'SCHOOL',school_b);
 for c in select * from (values
   ('dispatch.school_release.read'),('dispatch.school_release.release')) missing(code)
 loop
  select capability_id into missing_capability from atlas_core.capabilities where capability_code=c.code;
  delete from atlas_core.role_capabilities
  where role_id='26010000-0000-4000-8000-000000000001' and capability_id=missing_capability;
  before_counts:=pg_temp.pxk_exact_write_counts();
  response:=pg_temp.pxk_exact_read(false);
  return next ok(case when c.code='dispatch.school_release.read'
   then response->>'error_code'='CAPABILITY_DENIED' else response->>'success'='true' end,
   'PXK read independently checks its task capability without '||c.code);
  response:=pg_temp.pxk_exact_read(true);
  return next ok(case when c.code='dispatch.school_release.read'
   then response->>'error_code'='CAPABILITY_DENIED' else response->>'success'='true' end,
   'reconciliation independently checks its task capability without '||c.code);
  request:=pg_temp.pxk_exact_release_request(school_a,location_a);
  set local role authenticated;
  response:=pg_temp.pxk_release_isolated(request);
  reset role;
  return next ok(case when c.code='dispatch.school_release.release'
   then response->>'error_code'='CAPABILITY_DENIED' else response->>'success'='true' end,
   'PXK release independently checks its task capability without '||c.code);
  return next is(pg_temp.pxk_exact_write_counts(),before_counts,
   'capability denial/isolated control leaves zero writes without '||c.code);
  insert into atlas_core.role_capabilities(role_id,capability_id)
  values('26010000-0000-4000-8000-000000000001',missing_capability);
 end loop;
 response:=pg_temp.pxk_exact_read(false);
 second_response:=pg_temp.pxk_exact_read(true);
 return next ok(jsonb_array_length(response->'rows')=2 and
  jsonb_array_length(second_response->'rows')=2,'one Actor reads both explicitly authorized Schools');
 response:=pg_temp.pxk_exact_read(false,'2026-09-24');
 return next ok(response->>'success'='true' and response#>>'{rows,0,school_id}'=school_a::text
  and response#>>'{rows,0,delivery_location_id}'=location_a::text,
  'exact School retains historical captured location after its default changes');
 begin
  request:=pg_temp.pxk_exact_release_request(school_a,location_a);
  set local role authenticated;
  first_response:=atlas_api.release_school_dispatch_document(request);
  replay:=atlas_api.release_school_dispatch_document(request);
  reset role;
  request:=pg_temp.pxk_exact_release_request(school_b,location_b);
  set local role authenticated;
  second_response:=atlas_api.release_school_dispatch_document(request);
  reset role;
  select (select count(*)=2 and bool_and(released_by_actor_id=actor)
    from atlas_dispatch.school_dispatch_releases where service_date='2026-09-25')
   and (select count(*)=2 and bool_and(actor_id=actor and delegated_actor_id is null)
    from atlas_audit.audit_events where command_id in (
     (first_response->>'command_id')::uuid,(second_response->>'command_id')::uuid))
  into same_actor_audit;
  raise exception using errcode='XS109',message='Rollback isolated same-Actor releases';
 exception when sqlstate 'XS109' then null;
 end;
 return next is(first_response->>'success','true','same Actor releases School A with captured location');
 return next ok(replay->>'success'='true' and
  replay->>'document_number'=first_response->>'document_number' and
  replay->>'school_dispatch_release_id'=first_response->>'school_dispatch_release_id',
  'same Actor replay preserves immutable release identity and number');
 return next is(second_response->>'success','true','same Actor releases School B without another staff member');
 return next ok(same_actor_audit,'both release snapshots and audit events retain the same initiating Actor');
 return next is((select md5(string_agg(to_jsonb(r)::text,'' order by r.school_dispatch_release_id))
   from atlas_dispatch.school_dispatch_releases r where service_date<>'2026-09-25'),frozen,
   'default changes and scoped commands never rewrite historical frozen PXK');
 for c in select * from (values(location_b),( '26020000-0000-4000-8000-000000000013'::uuid)) target(location)
 loop
  request:=pg_temp.pxk_exact_release_request(school_a,c.location);
  set local role authenticated;
  response:=pg_temp.pxk_release_isolated(request);
  reset role;
  return next ok(response->>'success'='false','wrong captured/cross-Customer location cannot release a PXK');
 end loop;
 delete from atlas_core.actor_scopes where actor_id=actor;
 insert into atlas_core.actor_scopes(actor_id,scope_kind,school_id) values(actor,'SCHOOL',school_a);
 perform set_config('request.jwt.claim.sub','26000000-0000-4000-8000-000000000101',true);
end;
$cases$;
select * from pg_temp.pxk_exact_scope_cases();

set session_replication_role=replica;

-- PXK-SCOPE-02: only B changes, but A still depends on the same complete Supplier 1 PO.
update atlas_procurement.school_catering_allocation_family_revisions set is_current=false
where family_revision_id='26140000-0000-4000-8000-000000000012';
insert into atlas_procurement.school_catering_allocation_family_revisions(
  family_revision_id,family_id,revision_number,is_current,predecessor_revision_id,
  source_purchase_handoff_revision_id,source_fingerprint,family_quantity,unit_id,
  accepted_by_actor_id,command_id,decision_origin,source_kind)
select '26140000-0000-4000-8000-000000000022','26140000-0000-4000-8000-000000000011',
  2,true,'26140000-0000-4000-8000-000000000012',
  '26130000-0000-4000-8000-000000000032',
  atlas_core.school_catering_family_projection('2026-09-25',
    '26020000-0000-4000-8000-000000000012','26020000-0000-4000-8000-000000000041',
    '26020000-0000-4000-8000-000000000031')->>'source_fingerprint',40,
  '26020000-0000-4000-8000-000000000031','26000000-0000-4000-8000-000000000001',
  '26140000-0000-4000-8000-000000000023','MANUAL','PURCHASE_HANDOFF';
insert into atlas_procurement.school_catering_allocation_family_contributions(
  family_contribution_id,family_revision_id,purchase_handoff_line_revision_id,
  contribution_quantity)
values('26140000-0000-4000-8000-000000000023','26140000-0000-4000-8000-000000000022',
  '26130000-0000-4000-8000-000000000036',40);
insert into atlas_procurement.school_catering_allocation_supplier_splits(
  supplier_split_id,family_revision_id,supplier_id,allocated_quantity,split_ratio,
  decision_origin)
values('26140000-0000-4000-8000-000000000024','26140000-0000-4000-8000-000000000022',
  '26020000-0000-4000-8000-000000000051',40,1,'MANUAL');
set session_replication_role=origin;
select ok(not coalesce((atlas_core.school_dispatch_release_preview('2026-09-25',
    '26020000-0000-4000-8000-000000000021',
    '26020000-0000-4000-8000-000000000011')->>'ready')::boolean,false)
    and atlas_core.school_dispatch_release_preview('2026-09-25',
      '26020000-0000-4000-8000-000000000021',
      '26020000-0000-4000-8000-000000000011')->'blockers'
      @> '["PO_COVERAGE_INCOMPLETE"]'::jsonb,
  'PXK-SCOPE-02 shared stale Supplier 1 PO blocks unchanged School A');

-- Separate current documents for A and B, then make only B's Supplier 2 PO stale.
set session_replication_role=replica;
update atlas_procurement.school_catering_allocation_family_revisions set is_current=false
where family_revision_id='26140000-0000-4000-8000-000000000022';
insert into atlas_procurement.school_catering_allocation_family_revisions(
  family_revision_id,family_id,revision_number,is_current,predecessor_revision_id,
  source_purchase_handoff_revision_id,source_fingerprint,family_quantity,unit_id,
  accepted_by_actor_id,command_id,decision_origin,source_kind)
select '26140000-0000-4000-8000-000000000032','26140000-0000-4000-8000-000000000011',
  3,true,'26140000-0000-4000-8000-000000000022',
  '26130000-0000-4000-8000-000000000032',
  atlas_core.school_catering_family_projection('2026-09-25',
    '26020000-0000-4000-8000-000000000012','26020000-0000-4000-8000-000000000041',
    '26020000-0000-4000-8000-000000000031')->>'source_fingerprint',40,
  '26020000-0000-4000-8000-000000000031','26000000-0000-4000-8000-000000000001',
  '26140000-0000-4000-8000-000000000033','MANUAL','PURCHASE_HANDOFF';
insert into atlas_procurement.school_catering_allocation_family_contributions
  (family_contribution_id,family_revision_id,purchase_handoff_line_revision_id,
   contribution_quantity)
values('26140000-0000-4000-8000-000000000033','26140000-0000-4000-8000-000000000032',
  '26130000-0000-4000-8000-000000000036',40);
insert into atlas_procurement.school_catering_allocation_supplier_splits
  (supplier_split_id,family_revision_id,supplier_id,allocated_quantity,split_ratio,
   decision_origin)
values('26140000-0000-4000-8000-000000000034','26140000-0000-4000-8000-000000000032',
  '26020000-0000-4000-8000-000000000052',40,1,'MANUAL');
update atlas_procurement.purchase_orders set purchase_order_status='SUPERSEDED'
where purchase_order_id='26150000-0000-4000-8000-000000000001';
insert into atlas_procurement.purchase_orders(
  purchase_order_id,supplier_id,document_number,purchase_order_status,version,
  purchase_order_kind,school_catering_service_date,replaces_purchase_order_id)
values
  ('26150000-0000-4000-8000-000000000011','26020000-0000-4000-8000-000000000051',
    'PO-20260925-A','RELEASED_TO_SUPPLIER',2,'SCHOOL_CATERING','2026-09-25',
    '26150000-0000-4000-8000-000000000001'),
  ('26150000-0000-4000-8000-000000000021','26020000-0000-4000-8000-000000000052',
    'PO-20260925-B1','RELEASED_TO_SUPPLIER',2,'SCHOOL_CATERING','2026-09-25',null);
insert into atlas_procurement.purchase_order_revisions(
  purchase_order_revision_id,purchase_order_id,revision_number,revision_kind,
  revision_status,is_current,service_date,delivery_location_id,supplier_name_snapshot,
  delivery_location_snapshot,released_by_actor_id,released_at)
values
  ('26150000-0000-4000-8000-000000000012','26150000-0000-4000-8000-000000000011',
    2,'SUPERSEDING','RELEASED_TO_SUPPLIER',true,'2026-09-25',null,'NCC An Phú',
    'Nhiều điểm giao','26000000-0000-4000-8000-000000000001',transaction_timestamp()),
  ('26150000-0000-4000-8000-000000000022','26150000-0000-4000-8000-000000000021',
    2,'SUPERSEDING','RELEASED_TO_SUPPLIER',true,'2026-09-25',null,'NCC Bình Minh',
    'Bếp phụ Nguyễn Du','26000000-0000-4000-8000-000000000001',transaction_timestamp());
insert into atlas_procurement.purchase_order_lines(
  purchase_order_line_id,purchase_order_id,school_catering_allocation_family_id)
values
  ('26150000-0000-4000-8000-000000000013','26150000-0000-4000-8000-000000000011',
    '26140000-0000-4000-8000-000000000001'),
  ('26150000-0000-4000-8000-000000000023','26150000-0000-4000-8000-000000000021',
    '26140000-0000-4000-8000-000000000011');
insert into atlas_procurement.purchase_order_line_revisions(
  purchase_order_line_revision_id,purchase_order_revision_id,purchase_order_line_id,
  school_catering_allocation_supplier_split_id,ingredient_id,ordered_quantity,unit_id,
  delivery_location_id,service_date)
values
  ('26150000-0000-4000-8000-000000000014','26150000-0000-4000-8000-000000000012',
    '26150000-0000-4000-8000-000000000013','26140000-0000-4000-8000-000000000004',
    '26020000-0000-4000-8000-000000000041',100,'26020000-0000-4000-8000-000000000031',
    '26020000-0000-4000-8000-000000000011','2026-09-25'),
  ('26150000-0000-4000-8000-000000000024','26150000-0000-4000-8000-000000000022',
    '26150000-0000-4000-8000-000000000023','26140000-0000-4000-8000-000000000034',
    '26020000-0000-4000-8000-000000000041',40,'26020000-0000-4000-8000-000000000031',
    '26020000-0000-4000-8000-000000000012','2026-09-25');
update atlas_procurement.school_catering_allocation_family_revisions set is_current=false
where family_revision_id='26140000-0000-4000-8000-000000000032';
insert into atlas_procurement.school_catering_allocation_family_revisions(
  family_revision_id,family_id,revision_number,is_current,predecessor_revision_id,
  source_purchase_handoff_revision_id,source_fingerprint,family_quantity,unit_id,
  accepted_by_actor_id,command_id,decision_origin,source_kind)
select '26140000-0000-4000-8000-000000000042','26140000-0000-4000-8000-000000000011',
  4,true,'26140000-0000-4000-8000-000000000032',
  '26130000-0000-4000-8000-000000000032',
  atlas_core.school_catering_family_projection('2026-09-25',
    '26020000-0000-4000-8000-000000000012','26020000-0000-4000-8000-000000000041',
    '26020000-0000-4000-8000-000000000031')->>'source_fingerprint',40,
  '26020000-0000-4000-8000-000000000031','26000000-0000-4000-8000-000000000001',
  '26140000-0000-4000-8000-000000000043','MANUAL','PURCHASE_HANDOFF';
insert into atlas_procurement.school_catering_allocation_family_contributions
  (family_contribution_id,family_revision_id,purchase_handoff_line_revision_id,
   contribution_quantity)
values('26140000-0000-4000-8000-000000000043','26140000-0000-4000-8000-000000000042',
  '26130000-0000-4000-8000-000000000036',40);
insert into atlas_procurement.school_catering_allocation_supplier_splits
  (supplier_split_id,family_revision_id,supplier_id,allocated_quantity,split_ratio,
   decision_origin)
values('26140000-0000-4000-8000-000000000044','26140000-0000-4000-8000-000000000042',
  '26020000-0000-4000-8000-000000000052',40,1,'MANUAL');
set session_replication_role=origin;

select ok(coalesce((atlas_core.school_dispatch_release_preview('2026-09-25',
    '26020000-0000-4000-8000-000000000021',
    '26020000-0000-4000-8000-000000000011')->>'ready')::boolean,false)
    and not (atlas_core.school_dispatch_release_preview('2026-09-25',
      '26020000-0000-4000-8000-000000000021',
      '26020000-0000-4000-8000-000000000011')->'blockers'
      ?| array['PROCUREMENT_NOT_CURRENT','PO_COVERAGE_INCOMPLETE','CANCELLATION_REQUIRED']),
  'PXK-SCOPE-01/PXK-SCOPE-05C unrelated replacement-required PO does not block A');
select ok(not coalesce((atlas_core.school_dispatch_release_preview('2026-09-25',
    '26020000-0000-4000-8000-000000000022',
    '26020000-0000-4000-8000-000000000012')->>'ready')::boolean,false)
    and atlas_core.school_dispatch_release_preview('2026-09-25',
      '26020000-0000-4000-8000-000000000022',
      '26020000-0000-4000-8000-000000000012')->'blockers'
      @> '["PO_COVERAGE_INCOMPLETE"]'::jsonb,
  'PXK-SCOPE-01 stale Supplier 2 PO still blocks School B');

-- Repair B's Supplier 2 PO, then move B entirely to Supplier 3. Supplier 2 is an
-- unresolved historical cancellation only for B and must not block A.
set session_replication_role=replica;
update atlas_procurement.purchase_orders set purchase_order_status='SUPERSEDED'
where purchase_order_id='26150000-0000-4000-8000-000000000021';
insert into atlas_procurement.purchase_orders(
  purchase_order_id,supplier_id,document_number,purchase_order_status,version,
  purchase_order_kind,school_catering_service_date,replaces_purchase_order_id)
values('26150000-0000-4000-8000-000000000031','26020000-0000-4000-8000-000000000052',
  'PO-20260925-B2','RELEASED_TO_SUPPLIER',2,'SCHOOL_CATERING','2026-09-25',
  '26150000-0000-4000-8000-000000000021');
insert into atlas_procurement.purchase_order_revisions(
  purchase_order_revision_id,purchase_order_id,revision_number,revision_kind,
  revision_status,is_current,service_date,delivery_location_id,supplier_name_snapshot,
  delivery_location_snapshot,released_by_actor_id,released_at)
values('26150000-0000-4000-8000-000000000032','26150000-0000-4000-8000-000000000031',
  2,'SUPERSEDING','RELEASED_TO_SUPPLIER',true,'2026-09-25',null,'NCC Bình Minh',
  'Bếp phụ Nguyễn Du','26000000-0000-4000-8000-000000000001',transaction_timestamp());
insert into atlas_procurement.purchase_order_lines(
  purchase_order_line_id,purchase_order_id,school_catering_allocation_family_id)
values('26150000-0000-4000-8000-000000000033','26150000-0000-4000-8000-000000000031',
  '26140000-0000-4000-8000-000000000011');
insert into atlas_procurement.purchase_order_line_revisions(
  purchase_order_line_revision_id,purchase_order_revision_id,purchase_order_line_id,
  school_catering_allocation_supplier_split_id,ingredient_id,ordered_quantity,unit_id,
  delivery_location_id,service_date)
values('26150000-0000-4000-8000-000000000034','26150000-0000-4000-8000-000000000032',
  '26150000-0000-4000-8000-000000000033','26140000-0000-4000-8000-000000000044',
  '26020000-0000-4000-8000-000000000041',40,'26020000-0000-4000-8000-000000000031',
  '26020000-0000-4000-8000-000000000012','2026-09-25');
update atlas_procurement.school_catering_allocation_family_revisions set is_current=false
where family_revision_id='26140000-0000-4000-8000-000000000042';
insert into atlas_procurement.school_catering_allocation_family_revisions(
  family_revision_id,family_id,revision_number,is_current,predecessor_revision_id,
  source_purchase_handoff_revision_id,source_fingerprint,family_quantity,unit_id,
  accepted_by_actor_id,command_id,decision_origin,source_kind)
select '26140000-0000-4000-8000-000000000052','26140000-0000-4000-8000-000000000011',
  5,true,'26140000-0000-4000-8000-000000000042',
  '26130000-0000-4000-8000-000000000032',
  atlas_core.school_catering_family_projection('2026-09-25',
    '26020000-0000-4000-8000-000000000012','26020000-0000-4000-8000-000000000041',
    '26020000-0000-4000-8000-000000000031')->>'source_fingerprint',40,
  '26020000-0000-4000-8000-000000000031','26000000-0000-4000-8000-000000000001',
  '26140000-0000-4000-8000-000000000053','MANUAL','PURCHASE_HANDOFF';
insert into atlas_procurement.school_catering_allocation_family_contributions
  (family_contribution_id,family_revision_id,purchase_handoff_line_revision_id,
   contribution_quantity)
values('26140000-0000-4000-8000-000000000053','26140000-0000-4000-8000-000000000052',
  '26130000-0000-4000-8000-000000000036',40);
insert into atlas_procurement.school_catering_allocation_supplier_splits
  (supplier_split_id,family_revision_id,supplier_id,allocated_quantity,split_ratio,
   decision_origin)
values('26140000-0000-4000-8000-000000000054','26140000-0000-4000-8000-000000000052',
  '26020000-0000-4000-8000-000000000053',40,1,'MANUAL');
insert into atlas_procurement.purchase_orders(
  purchase_order_id,supplier_id,document_number,purchase_order_status,version,
  purchase_order_kind,school_catering_service_date)
values('26150000-0000-4000-8000-000000000041','26020000-0000-4000-8000-000000000053',
  'PO-20260925-B3','RELEASED_TO_SUPPLIER',2,'SCHOOL_CATERING','2026-09-25');
insert into atlas_procurement.purchase_order_revisions(
  purchase_order_revision_id,purchase_order_id,revision_number,revision_kind,
  revision_status,is_current,service_date,delivery_location_id,supplier_name_snapshot,
  delivery_location_snapshot,released_by_actor_id,released_at)
values('26150000-0000-4000-8000-000000000042','26150000-0000-4000-8000-000000000041',
  2,'SUPERSEDING','RELEASED_TO_SUPPLIER',true,'2026-09-25',null,'NCC Cửu Long',
  'Bếp phụ Nguyễn Du','26000000-0000-4000-8000-000000000001',transaction_timestamp());
insert into atlas_procurement.purchase_order_lines(
  purchase_order_line_id,purchase_order_id,school_catering_allocation_family_id)
values('26150000-0000-4000-8000-000000000043','26150000-0000-4000-8000-000000000041',
  '26140000-0000-4000-8000-000000000011');
insert into atlas_procurement.purchase_order_line_revisions(
  purchase_order_line_revision_id,purchase_order_revision_id,purchase_order_line_id,
  school_catering_allocation_supplier_split_id,ingredient_id,ordered_quantity,unit_id,
  delivery_location_id,service_date)
values('26150000-0000-4000-8000-000000000044','26150000-0000-4000-8000-000000000042',
  '26150000-0000-4000-8000-000000000043','26140000-0000-4000-8000-000000000054',
  '26020000-0000-4000-8000-000000000041',40,'26020000-0000-4000-8000-000000000031',
  '26020000-0000-4000-8000-000000000012','2026-09-25');
set session_replication_role=origin;

select ok(atlas_core.school_catering_po_commitment_state(
    '26150000-0000-4000-8000-000000000031',
    '26150000-0000-4000-8000-000000000032')='CANCELLATION_REQUIRED'
    and coalesce((atlas_core.school_dispatch_release_preview('2026-09-25',
      '26020000-0000-4000-8000-000000000021',
      '26020000-0000-4000-8000-000000000011')->>'ready')::boolean,false)
    and not (atlas_core.school_dispatch_release_preview('2026-09-25',
      '26020000-0000-4000-8000-000000000021',
      '26020000-0000-4000-8000-000000000011')->'blockers'
      ?| array['PROCUREMENT_NOT_CURRENT','PO_COVERAGE_INCOMPLETE','CANCELLATION_REQUIRED']),
  'PXK-SCOPE-03 unrelated School B cancellation-required PO does not block School A');

-- PXK-SCOPE-05: build one current Supplier 1 document containing A + B through the
-- approved replacement commands, then move A to Supplier 2 and release its exact PO.
-- The still-active Supplier 1 document remains an immutable duplicate instruction for A.
set local role authenticated;
select set_config('request.jwt.claim.sub','26000000-0000-4000-8000-000000000101',true);
insert into pxk_results values('scope05-b-to-s1',
  atlas_api.save_school_catering_supplier_allocation(
    pg_temp.pxk_procurement_command('26200000-0000-4000-8000-000000000001',1,
      'SCHOOL_CATERING_SUPPLIER_ALLOCATION_SAVED',jsonb_build_object(
        'family',pg_temp.pxk_procurement_family(
          '26020000-0000-4000-8000-000000000012'),
        'splits',jsonb_build_array(jsonb_build_object(
          'supplier_id','26020000-0000-4000-8000-000000000051',
          'allocated_quantity',40))))));
insert into pxk_results values('scope05-s1-shared-draft',
  atlas_api.create_school_catering_purchase_order_replacement(
    pg_temp.pxk_po_replace('26200000-0000-4000-8000-000000000002',
      '26150000-0000-4000-8000-000000000011')));
insert into pxk_results values('scope05-s1-shared-release',
  atlas_api.release_school_catering_purchase_order(pg_temp.pxk_po_release(
    '26200000-0000-4000-8000-000000000003',
    (select (response->>'purchase_order_id')::uuid from pxk_results
      where name='scope05-s1-shared-draft'))));
insert into pxk_results values('scope05-a-to-s2',
  atlas_api.save_school_catering_supplier_allocation(
    pg_temp.pxk_procurement_command('26200000-0000-4000-8000-000000000004',1,
      'SCHOOL_CATERING_SUPPLIER_ALLOCATION_SAVED',jsonb_build_object(
        'family',pg_temp.pxk_procurement_family(
          '26020000-0000-4000-8000-000000000011'),
        'splits',jsonb_build_array(jsonb_build_object(
          'supplier_id','26020000-0000-4000-8000-000000000052',
          'allocated_quantity',100))))));
insert into pxk_results values('scope05-s2-a-draft',
  atlas_api.create_school_catering_purchase_order_replacement(
    pg_temp.pxk_po_replace('26200000-0000-4000-8000-000000000005',
      '26150000-0000-4000-8000-000000000031')));
insert into pxk_results values('scope05-s2-a-release',
  atlas_api.release_school_catering_purchase_order(pg_temp.pxk_po_release(
    '26200000-0000-4000-8000-000000000006',
    (select (response->>'purchase_order_id')::uuid from pxk_results
      where name='scope05-s2-a-draft'))));
reset role;

select ok((select bool_and((response->>'success')::boolean) from pxk_results
    where name in ('scope05-b-to-s1','scope05-s1-shared-draft',
      'scope05-s1-shared-release','scope05-a-to-s2','scope05-s2-a-draft',
      'scope05-s2-a-release'))
    and atlas_core.school_catering_po_commitment_state(
      (select (response->>'purchase_order_id')::uuid from pxk_results
        where name='scope05-s1-shared-draft'),
      (select revision.purchase_order_revision_id
       from atlas_procurement.purchase_order_revisions revision
       where revision.purchase_order_id=(select (response->>'purchase_order_id')::uuid
         from pxk_results where name='scope05-s1-shared-draft')
         and revision.is_current))='REPLACEMENT_REQUIRED'
    and not coalesce((atlas_core.school_dispatch_release_preview('2026-09-25',
      '26020000-0000-4000-8000-000000000021',
      '26020000-0000-4000-8000-000000000011')->>'ready')::boolean,false)
    and atlas_core.school_dispatch_release_preview('2026-09-25',
      '26020000-0000-4000-8000-000000000021',
      '26020000-0000-4000-8000-000000000011')->'blockers'
      @> '["PROCUREMENT_NOT_CURRENT"]'::jsonb
    and not (atlas_core.school_dispatch_release_preview('2026-09-25',
      '26020000-0000-4000-8000-000000000021',
      '26020000-0000-4000-8000-000000000011')->'blockers'
      ? 'PO_COVERAGE_INCOMPLETE'),
  'PXK-SCOPE-05A relevant active replacement-required PO blocks covered School A');

set local role authenticated;
select set_config('request.jwt.claim.sub','26000000-0000-4000-8000-000000000101',true);
insert into pxk_results values('scope05-s1-b-draft',
  atlas_api.create_school_catering_purchase_order_replacement(
    pg_temp.pxk_po_replace('26200000-0000-4000-8000-000000000007',
      (select (response->>'purchase_order_id')::uuid from pxk_results
        where name='scope05-s1-shared-draft'))));
reset role;
select ok((select (response->>'success')::boolean from pxk_results
      where name='scope05-s1-b-draft')
    and (select purchase_order_status='RELEASED_TO_SUPPLIER'
      from atlas_procurement.purchase_orders
      where purchase_order_id=(select (response->>'purchase_order_id')::uuid
        from pxk_results where name='scope05-s1-shared-draft'))
    and (select count(*)=1 and bool_and(line.delivery_location_id=
        '26020000-0000-4000-8000-000000000012')
      from atlas_procurement.purchase_order_revisions revision
      join atlas_procurement.purchase_order_line_revisions line
        on line.purchase_order_revision_id=revision.purchase_order_revision_id
      where revision.purchase_order_id=(select (response->>'purchase_order_id')::uuid
        from pxk_results where name='scope05-s1-b-draft') and revision.is_current)
    and not coalesce((atlas_core.school_dispatch_release_preview('2026-09-25',
      '26020000-0000-4000-8000-000000000021',
      '26020000-0000-4000-8000-000000000011')->>'ready')::boolean,false),
  'PXK-SCOPE-05B replacement draft excludes A while old Supplier 1 PO stays active');

set local role authenticated;
select set_config('request.jwt.claim.sub','26000000-0000-4000-8000-000000000101',true);
insert into pxk_results values('scope05-s1-b-release',
  atlas_api.release_school_catering_purchase_order(pg_temp.pxk_po_release(
    '26200000-0000-4000-8000-000000000008',
    (select (response->>'purchase_order_id')::uuid from pxk_results
      where name='scope05-s1-b-draft'))));
reset role;
select ok((select (response->>'success')::boolean from pxk_results
      where name='scope05-s1-b-release')
    and (select purchase_order_status='SUPERSEDED'
      from atlas_procurement.purchase_orders
      where purchase_order_id=(select (response->>'purchase_order_id')::uuid
        from pxk_results where name='scope05-s1-shared-draft'))
    and (select purchase_order_status='RELEASED_TO_SUPPLIER'
      from atlas_procurement.purchase_orders
      where purchase_order_id=(select (response->>'purchase_order_id')::uuid
        from pxk_results where name='scope05-s1-b-draft'))
    and coalesce((atlas_core.school_dispatch_release_preview('2026-09-25',
      '26020000-0000-4000-8000-000000000021',
      '26020000-0000-4000-8000-000000000011')->>'ready')::boolean,false)
    and not (atlas_core.school_dispatch_release_preview('2026-09-25',
      '26020000-0000-4000-8000-000000000021',
      '26020000-0000-4000-8000-000000000011')->'blockers'
      ? 'PROCUREMENT_NOT_CURRENT'),
  'PXK-SCOPE-05B replacement release atomically resolves and unblocks School A');

set local role authenticated;
select set_config('request.jwt.claim.sub','26000000-0000-4000-8000-000000000101',true);
insert into pxk_results values('fulfilment-reconciliation',
  atlas_api.get_school_fulfilment_reconciliation_workbench(jsonb_build_object(
    'contract_version','SCHOOL-FULFILMENT-RECONCILIATION.v1',
    'requested_by_auth_subject','26000000-0000-4000-8000-000000000101',
    'correlation_id','26200000-0000-4000-8000-000000000009',
    'payload',jsonb_build_object('date_start','2026-09-24','date_end','2026-09-24',
      'school_ids',jsonb_build_array('26020000-0000-4000-8000-000000000021'),
      'search',null))));
reset role;
select ok((select response->>'success'='true'
    and response#>>'{rows,0,comparison_status}'='NO_PO'
    and response#>'{rows,0,blockers}' @> '["CANCELLATION_REQUIRED"]'::jsonb
    and jsonb_array_length(response#>'{rows,0,history}')=2
    and response#>>'{rows,0,delivery_location_id}'=
      '26020000-0000-4000-8000-000000000011'
  from pxk_results where name='fulfilment-reconciliation'),
  'reconciliation excludes stale PO quantity, retains PXK history and captured location');

-- Restore distinct defaults after the captured-location regressions above.
-- The inherited dispatch predicate also matches a School's default location.
update atlas_admin.schools
set default_delivery_location_id='26020000-0000-4000-8000-000000000011'
where school_id='26020000-0000-4000-8000-000000000021';
set local role authenticated;
select set_config('request.jwt.claim.sub','26000000-0000-4000-8000-000000000102',true);
insert into pxk_results values('scoped-a-workbench',
  atlas_api.get_school_dispatch_release_workbench(jsonb_build_object(
    'contract_version','SCHOOL-DISPATCH-RELEASE.v1',
    'requested_by_auth_subject','26000000-0000-4000-8000-000000000102',
    'correlation_id',gen_random_uuid(),
    'payload',jsonb_build_object(
      'date_start','2026-09-25','date_end','2026-09-25',
      'school_ids','[]'::jsonb,'search',null
    )
  )));
insert into pxk_results values('scoped-a-reconciliation',
  atlas_api.get_school_fulfilment_reconciliation_workbench(jsonb_build_object(
    'contract_version','SCHOOL-FULFILMENT-RECONCILIATION.v1',
    'requested_by_auth_subject','26000000-0000-4000-8000-000000000102',
    'correlation_id',gen_random_uuid(),
    'payload',jsonb_build_object(
      'date_start','2026-09-25','date_end','2026-09-25',
      'school_ids','[]'::jsonb,'search',null
    )
  )));
select set_config('request.jwt.claim.sub','26000000-0000-4000-8000-000000000101',true);
reset role;

select ok((select jsonb_array_length(response->'rows')>0
    and not exists(
      select 1 from jsonb_array_elements(response->'rows') row
      where row->>'school_id'<>'26020000-0000-4000-8000-000000000021'
    )
  from pxk_results where name='scoped-a-workbench'),
  'PXK workbench returns only relationally authorized School rows');
select ok((select jsonb_array_length(response->'rows')>0
    and not exists(
      select 1 from jsonb_array_elements(response->'rows') row
      where row->>'school_id'<>'26020000-0000-4000-8000-000000000021'
    )
  from pxk_results where name='scoped-a-reconciliation'),
  'PO/PXK reconciliation returns only relationally authorized School rows');


select * from finish();
rollback;
