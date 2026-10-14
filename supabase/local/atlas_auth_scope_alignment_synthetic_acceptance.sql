-- Migration 109: extends the reviewed 108 fixture; all business writes roll back before reporting.
-- Seed adapted from school_dispatch_release.sql at d254c09; unique f108 IDs/date.
begin;
set local statement_timeout='8s';
set local lock_timeout='1s';
create temporary table a108_checks(label text primary key) on commit drop;
create temporary table a108_report(result jsonb) on commit drop;
create function pg_temp.a108_require(p_label text,p_pass boolean)
returns void language plpgsql set search_path='' as $require$
begin
 if p_pass is distinct from true then raise exception 'A108 acceptance failed: %',p_label; end if;
 insert into pg_temp.a108_checks values(p_label);
end;
$require$;
create function pg_temp.a108_read(p_contract text,p_payload jsonb)
returns jsonb language sql volatile set search_path='' as $read$
 select jsonb_build_object('contract_version',p_contract,'correlation_id',gen_random_uuid(),
  'requested_by_auth_subject',current_setting('request.jwt.claim.sub'),'payload',p_payload);
$read$;
create function pg_temp.a108_command(p_contract text,p_reason text,p_expected bigint,p_payload jsonb)
returns jsonb language sql volatile set search_path='' as $command$
 select jsonb_build_object('contract_version',p_contract,'command_id',command_id,
  'correlation_id','f1080099-0000-4000-8000-000000000001',
  'idempotency_key','a108:'||command_id,'expected_version',p_expected,
  'requested_by_auth_subject',current_setting('request.jwt.claim.sub'),
  'requested_at',transaction_timestamp()-interval '1 second','reason_code',p_reason,
  'reason_note',null,'payload',p_payload)
 from (select gen_random_uuid() command_id) source;
$command$;
create function pg_temp.a108_isolated(p_kind text,p_request jsonb)
returns jsonb language plpgsql volatile set search_path='' as $isolated$
declare response jsonb;
begin
 if p_kind='PO' then response:=atlas_api.release_school_catering_purchase_order(p_request);
 elsif p_kind='PXK' then response:=atlas_api.release_school_dispatch_document(p_request);
 else raise exception 'A108 unsupported command'; end if;
 raise exception using errcode='Z1081',message='Successful isolated command rollback';
exception when sqlstate 'Z1081' then return response;
end;
$isolated$;
do $acceptance$
declare
 v_result jsonb; v_response jsonb; v_replay jsonb; v_request jsonb; v_po_payload jsonb;
 v_pxk_payload jsonb; v_read_payload jsonb; v_count integer; v_po_number text;
 v_frozen_pxk jsonb; v_b_payload jsonb; v_before_counts jsonb; v_control record;
begin
 perform pg_temp.a108_require('migration_108_present',exists(select 1
  from supabase_migrations.schema_migrations where version='20261014090000'));
 perform pg_temp.a108_require('probe_namespace_empty',not exists(select 1
  from atlas_core.actors where actor_id::text like 'f108%'));
 perform pg_temp.a108_require('synthetic_date_empty',not exists(select 1
  from atlas_procurement.purchase_orders where school_catering_service_date='2098-10-14')
  and not exists(select 1 from atlas_dispatch.school_dispatch_releases where service_date='2098-10-14')
  and not exists(select 1 from atlas_planning.confirmed_need_batches
   where period_start<='2098-10-14' and period_end>='2098-10-14'));
 begin
insert into atlas_core.actors(actor_id,actor_type,display_name)
values('f1080000-0000-4000-8000-000000000001','HUMAN','School PXK operator');
insert into atlas_core.actor_auth_subjects(actor_id,auth_subject_id)
values('f1080000-0000-4000-8000-000000000001','f1080000-0000-4000-8000-000000000101');
insert into atlas_core.roles(role_id,role_code,role_name)
values('f1080001-0000-4000-8000-000000000001','a108_synthetic_operator','School PXK operator');
insert into atlas_core.role_capabilities(role_id,capability_id)
select 'f1080001-0000-4000-8000-000000000001',capability_id
from atlas_core.capabilities
where capability_code in ('dispatch.school_release.read','dispatch.school_release.release');
insert into atlas_core.role_capabilities(role_id,capability_id)
select 'f1080001-0000-4000-8000-000000000001',capability_id
from atlas_core.capabilities
where capability_code='procurement.school_catering.write';
insert into atlas_core.actor_role_memberships(actor_id,role_id)
values('f1080000-0000-4000-8000-000000000001','f1080001-0000-4000-8000-000000000001');
insert into atlas_core.actor_scopes(actor_id,scope_kind)
values('f1080000-0000-4000-8000-000000000001','GLOBAL');

insert into atlas_admin.customers(customer_id,customer_code,customer_name,customer_type)
values
  ('f1080002-0000-4000-8000-000000000001','a108-school-customer',
    'PXK School Customer','SCHOOL_CATERING'),
  ('f1080002-0000-4000-8000-000000000002','a108-other-customer',
    'PXK Other Customer','SCHOOL_CATERING');
insert into atlas_admin.delivery_locations(
  delivery_location_id,customer_id,location_code,location_name,address_text)
values
  ('f1080002-0000-4000-8000-000000000011','f1080002-0000-4000-8000-000000000001',
    'a108-location-a','Bếp chính Nguyễn Du','Số 1 Nguyễn Du'),
  ('f1080002-0000-4000-8000-000000000012','f1080002-0000-4000-8000-000000000001',
    'a108-location-b','Bếp phụ Nguyễn Du','Số 2 Nguyễn Du'),
  ('f1080002-0000-4000-8000-000000000013','f1080002-0000-4000-8000-000000000002',
    'a108-cross-customer','Bếp khác khách hàng','Số 3 Nguyễn Du');
insert into atlas_admin.schools(
  school_id,customer_id,school_code,school_name,default_delivery_location_id,display_order,
  dispatch_document_issuer_name,dispatch_document_issuer_address)
values
  ('f1080002-0000-4000-8000-000000000021','f1080002-0000-4000-8000-000000000001',
    'a108-school','Trường Tiểu học Nguyễn Du','f1080002-0000-4000-8000-000000000011',1,
    'CƠ SỞ CUNG CẤP THỰC PHẨM THƯỢNG HẢO','Địa chỉ PXK đã cấu hình'),
  ('f1080002-0000-4000-8000-000000000022','f1080002-0000-4000-8000-000000000001',
    'a108-school-b','Trường Tiểu học Trưng Vương','f1080002-0000-4000-8000-000000000012',2,
    'CÔNG TY TNHH MTV TM - DV THƯỢNG HẢO','Địa chỉ PXK đã cấu hình');

-- Relational-scope operators for cutover authorization regression.
insert into atlas_core.actors(actor_id,actor_type,display_name) values
  ('f1080000-0000-4000-8000-000000000002','HUMAN','PXK School A operator'),
  ('f1080000-0000-4000-8000-000000000003','HUMAN','PXK School B operator'),
  ('f1080000-0000-4000-8000-000000000004','HUMAN','PXK no-capability operator');
insert into atlas_core.actor_auth_subjects(actor_id,auth_subject_id) values
  ('f1080000-0000-4000-8000-000000000002','f1080000-0000-4000-8000-000000000102'),
  ('f1080000-0000-4000-8000-000000000003','f1080000-0000-4000-8000-000000000103'),
  ('f1080000-0000-4000-8000-000000000004','f1080000-0000-4000-8000-000000000104');
insert into atlas_core.actor_role_memberships(actor_id,role_id) values
  ('f1080000-0000-4000-8000-000000000002','f1080001-0000-4000-8000-000000000001'),
  ('f1080000-0000-4000-8000-000000000003','f1080001-0000-4000-8000-000000000001');
insert into atlas_core.roles(role_id,role_code,role_name)
values('f1080001-0000-4000-8000-000000000004','a108_synthetic_no_cap','School PXK no-capability role');
insert into atlas_core.actor_role_memberships(actor_id,role_id)
values('f1080000-0000-4000-8000-000000000004','f1080001-0000-4000-8000-000000000004');
insert into atlas_core.actor_scopes(actor_id,scope_kind,school_id) values
  ('f1080000-0000-4000-8000-000000000002','SCHOOL','f1080002-0000-4000-8000-000000000021'),
  ('f1080000-0000-4000-8000-000000000003','SCHOOL','f1080002-0000-4000-8000-000000000022'),
  ('f1080000-0000-4000-8000-000000000004','SCHOOL','f1080002-0000-4000-8000-000000000021');
insert into atlas_admin.units(unit_id,unit_code,unit_name,dimension_code)
values('f1080002-0000-4000-8000-000000000031','a108-kg','Kilôgam','mass');
insert into atlas_admin.ingredients(ingredient_id,ingredient_code,ingredient_name,purchase_unit_id,document_code)
values('f1080002-0000-4000-8000-000000000041','a108-rice','Gạo thơm',
  'f1080002-0000-4000-8000-000000000031','1082');
insert into atlas_admin.suppliers(supplier_id,supplier_code,supplier_name,supplier_status,document_code)
values
  ('f1080002-0000-4000-8000-000000000051','a108-supplier-a','NCC An Phú','ACTIVE','53'),
  ('f1080002-0000-4000-8000-000000000052','a108-supplier-b','NCC Bình Minh','ACTIVE','54'),
  ('f1080002-0000-4000-8000-000000000053','a108-supplier-c','NCC Cửu Long','ACTIVE','55');
insert into atlas_admin.supplier_eligibilities(
  supplier_id,ingredient_id,effective_from,priority,reason_note)
values
  ('f1080002-0000-4000-8000-000000000051','f1080002-0000-4000-8000-000000000041',
    '2026-01-01',1,'PXK test'),
  ('f1080002-0000-4000-8000-000000000052','f1080002-0000-4000-8000-000000000041',
    '2026-01-01',2,'PXK test'),
  ('f1080002-0000-4000-8000-000000000053','f1080002-0000-4000-8000-000000000041',
    '2026-01-01',3,'PXK test');

-- Exact current Confirmed Need -> Handoff -> Allocation -> released PO evidence.
set local session_replication_role=replica;
insert into atlas_planning.confirmed_need_batches(
  confirmed_need_batch_id,period_start,period_end,batch_status,version,
  created_by_actor_id,source_kind,origin_need_generation_run_id,
  origin_need_generation_run_version,origin_need_generation_release_snapshot_id,
  current_need_generation_run_id,current_need_generation_run_version,
  current_need_generation_release_snapshot_id)
values('f1080003-0000-4000-8000-000000000001','2098-10-14','2098-10-14',
  'RELEASED_FOR_PURCHASE_HANDOFF',1,'f1080000-0000-4000-8000-000000000001',
  'NEED_GENERATION','f1080003-0000-4000-8000-000000000002',1,
  'f1080003-0000-4000-8000-000000000003','f1080003-0000-4000-8000-000000000002',1,
  'f1080003-0000-4000-8000-000000000003');
insert into atlas_planning.confirmed_need_lines(
  confirmed_need_line_id,confirmed_need_batch_id,source_kind,service_date,customer_id,
  school_id,delivery_location_id,ingredient_id,controlled_unit_id,
  current_confirmed_need_line_decision_id)
values('f1080003-0000-4000-8000-000000000011','f1080003-0000-4000-8000-000000000001',
  'NEED_GENERATION','2098-10-14','f1080002-0000-4000-8000-000000000001',
  'f1080002-0000-4000-8000-000000000021','f1080002-0000-4000-8000-000000000011',
  'f1080002-0000-4000-8000-000000000041','f1080002-0000-4000-8000-000000000031',
  'f1080003-0000-4000-8000-000000000013');
insert into atlas_planning.confirmed_need_line_revisions(
  confirmed_need_line_revision_id,confirmed_need_line_id,revision_number,ingredient_id,
  theoretical_quantity,confirmed_quantity,unit_id,revision_status,is_current,
  created_by_actor_id,source_kind,confirmed_need_batch_id,need_generation_run_id,
  need_generation_run_version,need_generation_release_snapshot_id,service_date,
  customer_id,school_id,delivery_location_id)
values('f1080003-0000-4000-8000-000000000012','f1080003-0000-4000-8000-000000000011',
  1,'f1080002-0000-4000-8000-000000000041',100,100,
  'f1080002-0000-4000-8000-000000000031','RELEASED',true,
  'f1080000-0000-4000-8000-000000000001','NEED_GENERATION',
  'f1080003-0000-4000-8000-000000000001','f1080003-0000-4000-8000-000000000002',1,
  'f1080003-0000-4000-8000-000000000003','2098-10-14',
  'f1080002-0000-4000-8000-000000000001','f1080002-0000-4000-8000-000000000021',
  'f1080002-0000-4000-8000-000000000011');
insert into atlas_planning.confirmed_need_line_decisions(
  confirmed_need_line_decision_id,confirmed_need_batch_id,confirmed_need_line_id,
  confirmed_need_line_revision_id,source_kind,service_date,customer_id,school_id,
  delivery_location_id,ingredient_id,unit_id,decision_number,decision_kind,
  planning_quantity_policy_id,planning_quantity_policy_revision_id,
  theoretical_quantity_before,proposed_quantity_before,confirmed_quantity_after,
  planning_tick_count,reason_code,decided_by_actor_id,decided_at,command_id,
  confirmed_need_batch_version)
values('f1080003-0000-4000-8000-000000000013','f1080003-0000-4000-8000-000000000001',
  'f1080003-0000-4000-8000-000000000011','f1080003-0000-4000-8000-000000000012',
  'NEED_GENERATION','2098-10-14','f1080002-0000-4000-8000-000000000001',
  'f1080002-0000-4000-8000-000000000021','f1080002-0000-4000-8000-000000000011',
  'f1080002-0000-4000-8000-000000000041','f1080002-0000-4000-8000-000000000031',
  1,'UNCHANGED_PROPOSAL_ACCEPTED','f1080003-0000-4000-8000-000000000014',
  'f1080003-0000-4000-8000-000000000015',100,100,100,100000000,
  'PROPOSAL_ACCEPTED','f1080000-0000-4000-8000-000000000001',transaction_timestamp(),
  'f1080003-0000-4000-8000-000000000016',1);
insert into atlas_planning.purchase_handoff_batches(
  purchase_handoff_batch_id,confirmed_need_batch_id,period_start,period_end,
  handoff_status,created_by_actor_id)
values('f1080003-0000-4000-8000-000000000021','f1080003-0000-4000-8000-000000000001',
  '2098-10-14','2098-10-14','RELEASED_TO_PROCUREMENT',
  'f1080000-0000-4000-8000-000000000001');
insert into atlas_planning.purchase_handoff_revisions(
  purchase_handoff_revision_id,purchase_handoff_batch_id,revision_number,
  revision_status,is_current,released_by_actor_id,released_at)
values('f1080003-0000-4000-8000-000000000022','f1080003-0000-4000-8000-000000000021',
  1,'RELEASED_TO_PROCUREMENT',true,'f1080000-0000-4000-8000-000000000001',
  transaction_timestamp());
insert into atlas_planning.purchase_handoff_lines(
  purchase_handoff_line_id,purchase_handoff_batch_id,confirmed_need_line_id)
values('f1080003-0000-4000-8000-000000000023','f1080003-0000-4000-8000-000000000021',
  'f1080003-0000-4000-8000-000000000011');
insert into atlas_planning.purchase_handoff_line_revisions(
  purchase_handoff_line_revision_id,purchase_handoff_revision_id,purchase_handoff_line_id,
  confirmed_need_line_revision_id,ingredient_id,handoff_quantity,unit_id,service_date,
  delivery_location_id)
values('f1080003-0000-4000-8000-000000000024','f1080003-0000-4000-8000-000000000022',
  'f1080003-0000-4000-8000-000000000023','f1080003-0000-4000-8000-000000000012',
  'f1080002-0000-4000-8000-000000000041',100,'f1080002-0000-4000-8000-000000000031',
  '2098-10-14','f1080002-0000-4000-8000-000000000011');
insert into atlas_planning.purchase_demand_references(
  purchase_demand_reference_id,purchase_handoff_line_revision_id,
  confirmed_need_snapshot_line_id,approved_quantity,unit_id,source_kind)
values('f1080003-0000-4000-8000-000000000025','f1080003-0000-4000-8000-000000000024',
  'f1080003-0000-4000-8000-000000000026',100,'f1080002-0000-4000-8000-000000000031',
  'NEED_GENERATION');
insert into atlas_procurement.school_catering_allocation_families(
  family_id,service_date,delivery_location_id,ingredient_id,unit_id)
values('f1080004-0000-4000-8000-000000000001','2098-10-14',
  'f1080002-0000-4000-8000-000000000011','f1080002-0000-4000-8000-000000000041',
  'f1080002-0000-4000-8000-000000000031');
insert into atlas_procurement.school_catering_allocation_family_revisions(
  family_revision_id,family_id,revision_number,is_current,
  source_purchase_handoff_revision_id,source_fingerprint,family_quantity,unit_id,
  accepted_by_actor_id,command_id,decision_origin,source_kind)
select 'f1080004-0000-4000-8000-000000000002','f1080004-0000-4000-8000-000000000001',
  1,true,'f1080003-0000-4000-8000-000000000022',
  atlas_core.school_catering_family_projection('2098-10-14',
    'f1080002-0000-4000-8000-000000000011','f1080002-0000-4000-8000-000000000041',
    'f1080002-0000-4000-8000-000000000031')->>'source_fingerprint',
  100,'f1080002-0000-4000-8000-000000000031',
  'f1080000-0000-4000-8000-000000000001','f1080004-0000-4000-8000-000000000003',
  'MANUAL','PURCHASE_HANDOFF';
insert into atlas_procurement.school_catering_allocation_family_contributions(
  family_contribution_id,family_revision_id,purchase_handoff_line_revision_id,
  contribution_quantity)
values('f1080004-0000-4000-8000-000000000004','f1080004-0000-4000-8000-000000000002',
  'f1080003-0000-4000-8000-000000000024',100);
insert into atlas_procurement.school_catering_allocation_supplier_splits(
  supplier_split_id,family_revision_id,supplier_id,allocated_quantity,split_ratio,
  decision_origin)
values('f1080004-0000-4000-8000-000000000005','f1080004-0000-4000-8000-000000000002',
  'f1080002-0000-4000-8000-000000000051',100,1,'MANUAL');
insert into atlas_procurement.purchase_orders(
  purchase_order_id,supplier_id,document_number,purchase_order_status,version,
  purchase_order_kind,school_catering_service_date)
values('f1080005-0000-4000-8000-000000000001','f1080002-0000-4000-8000-000000000051',
  null,'DRAFT',1,'SCHOOL_CATERING','2098-10-14');
insert into atlas_procurement.purchase_order_revisions(
 purchase_order_revision_id,purchase_order_id,revision_number,revision_kind,
 revision_status,is_current,service_date,delivery_location_id,supplier_name_snapshot,
 delivery_location_snapshot)
values('f1080005-0000-4000-8000-000000000002','f1080005-0000-4000-8000-000000000001',
 1,'BASE','DRAFT',true,'2098-10-14',null,'A108 synthetic Supplier','A108 synthetic destinations');
insert into atlas_procurement.purchase_order_lines(
  purchase_order_line_id,purchase_order_id,school_catering_allocation_family_id)
values('f1080005-0000-4000-8000-000000000003','f1080005-0000-4000-8000-000000000001',
  'f1080004-0000-4000-8000-000000000001');
insert into atlas_procurement.purchase_order_line_revisions(
  purchase_order_line_revision_id,purchase_order_revision_id,purchase_order_line_id,
  school_catering_allocation_supplier_split_id,ingredient_id,ordered_quantity,unit_id,
  delivery_location_id,service_date)
values('f1080005-0000-4000-8000-000000000004','f1080005-0000-4000-8000-000000000002',
  'f1080005-0000-4000-8000-000000000003','f1080004-0000-4000-8000-000000000005',
  'f1080002-0000-4000-8000-000000000041',100,'f1080002-0000-4000-8000-000000000031',
  'f1080002-0000-4000-8000-000000000011','2098-10-14');
set local session_replication_role=origin;


-- A second exact School contribution makes the supplier document atomic.
set local session_replication_role=replica;
insert into atlas_planning.confirmed_need_lines
select (jsonb_populate_record(null::atlas_planning.confirmed_need_lines,to_jsonb(source)||
  jsonb_build_object('confirmed_need_line_id','f1080003-0000-4000-8000-000000000031',
    'current_confirmed_need_line_decision_id','f1080003-0000-4000-8000-000000000033',
    'school_id','f1080002-0000-4000-8000-000000000022',
    'delivery_location_id','f1080002-0000-4000-8000-000000000012'))).*
from atlas_planning.confirmed_need_lines source
where confirmed_need_line_id='f1080003-0000-4000-8000-000000000011';
insert into atlas_planning.confirmed_need_line_revisions
select (jsonb_populate_record(null::atlas_planning.confirmed_need_line_revisions,to_jsonb(source)||
  jsonb_build_object('confirmed_need_line_revision_id','f1080003-0000-4000-8000-000000000032',
    'confirmed_need_line_id','f1080003-0000-4000-8000-000000000031',
    'theoretical_quantity',50,'confirmed_quantity',50,
    'school_id','f1080002-0000-4000-8000-000000000022',
    'delivery_location_id','f1080002-0000-4000-8000-000000000012'))).*
from atlas_planning.confirmed_need_line_revisions source
where confirmed_need_line_revision_id='f1080003-0000-4000-8000-000000000012';
insert into atlas_planning.confirmed_need_line_decisions
select (jsonb_populate_record(null::atlas_planning.confirmed_need_line_decisions,to_jsonb(source)||
  jsonb_build_object('confirmed_need_line_decision_id','f1080003-0000-4000-8000-000000000033',
    'confirmed_need_line_revision_id','f1080003-0000-4000-8000-000000000032',
    'confirmed_need_line_id','f1080003-0000-4000-8000-000000000031',
    'school_id','f1080002-0000-4000-8000-000000000022',
    'delivery_location_id','f1080002-0000-4000-8000-000000000012',
    'theoretical_quantity_before',50,'proposed_quantity_before',50,
    'confirmed_quantity_after',50,'planning_tick_count',50000000,
    'command_id','f1080003-0000-4000-8000-000000000036'))).*
from atlas_planning.confirmed_need_line_decisions source
where confirmed_need_line_decision_id='f1080003-0000-4000-8000-000000000013';
insert into atlas_planning.purchase_handoff_lines
select (jsonb_populate_record(null::atlas_planning.purchase_handoff_lines,to_jsonb(source)||
  jsonb_build_object('purchase_handoff_line_id','f1080003-0000-4000-8000-000000000043',
    'confirmed_need_line_id','f1080003-0000-4000-8000-000000000031'))).*
from atlas_planning.purchase_handoff_lines source
where purchase_handoff_line_id='f1080003-0000-4000-8000-000000000023';
insert into atlas_planning.purchase_handoff_line_revisions
select (jsonb_populate_record(null::atlas_planning.purchase_handoff_line_revisions,to_jsonb(source)||
  jsonb_build_object('purchase_handoff_line_revision_id','f1080003-0000-4000-8000-000000000044',
    'purchase_handoff_line_id','f1080003-0000-4000-8000-000000000043',
    'confirmed_need_line_revision_id','f1080003-0000-4000-8000-000000000032',
    'handoff_quantity',50,'delivery_location_id','f1080002-0000-4000-8000-000000000012'))).*
from atlas_planning.purchase_handoff_line_revisions source
where purchase_handoff_line_revision_id='f1080003-0000-4000-8000-000000000024';
insert into atlas_planning.purchase_demand_references
select (jsonb_populate_record(null::atlas_planning.purchase_demand_references,to_jsonb(source)||
  jsonb_build_object('purchase_demand_reference_id','f1080003-0000-4000-8000-000000000045',
    'purchase_handoff_line_revision_id','f1080003-0000-4000-8000-000000000044',
    'confirmed_need_snapshot_line_id','f1080003-0000-4000-8000-000000000046',
    'approved_quantity',50))).*
from atlas_planning.purchase_demand_references source
where purchase_demand_reference_id='f1080003-0000-4000-8000-000000000025';
insert into atlas_procurement.school_catering_allocation_families
select (jsonb_populate_record(null::atlas_procurement.school_catering_allocation_families,
  to_jsonb(source)||jsonb_build_object('family_id','f1080004-0000-4000-8000-000000000011',
    'delivery_location_id','f1080002-0000-4000-8000-000000000012'))).*
from atlas_procurement.school_catering_allocation_families source
where family_id='f1080004-0000-4000-8000-000000000001';
insert into atlas_procurement.school_catering_allocation_family_revisions
select (jsonb_populate_record(null::atlas_procurement.school_catering_allocation_family_revisions,
  to_jsonb(source)||jsonb_build_object('family_revision_id','f1080004-0000-4000-8000-000000000012',
    'family_id','f1080004-0000-4000-8000-000000000011','family_quantity',50,
    'command_id','f1080004-0000-4000-8000-000000000013',
    'source_fingerprint',atlas_core.school_catering_family_projection('2098-10-14',
      'f1080002-0000-4000-8000-000000000012','f1080002-0000-4000-8000-000000000041',
      'f1080002-0000-4000-8000-000000000031')->>'source_fingerprint'))).*
from atlas_procurement.school_catering_allocation_family_revisions source
where family_revision_id='f1080004-0000-4000-8000-000000000002';
insert into atlas_procurement.school_catering_allocation_family_contributions
select (jsonb_populate_record(null::atlas_procurement.school_catering_allocation_family_contributions,
  to_jsonb(source)||jsonb_build_object('family_contribution_id','f1080004-0000-4000-8000-000000000014',
    'family_revision_id','f1080004-0000-4000-8000-000000000012',
    'purchase_handoff_line_revision_id','f1080003-0000-4000-8000-000000000044',
    'contribution_quantity',50))).*
from atlas_procurement.school_catering_allocation_family_contributions source
where family_contribution_id='f1080004-0000-4000-8000-000000000004';
insert into atlas_procurement.school_catering_allocation_supplier_splits
select (jsonb_populate_record(null::atlas_procurement.school_catering_allocation_supplier_splits,
  to_jsonb(source)||jsonb_build_object('supplier_split_id','f1080004-0000-4000-8000-000000000015',
    'family_revision_id','f1080004-0000-4000-8000-000000000012','allocated_quantity',50))).*
from atlas_procurement.school_catering_allocation_supplier_splits source
where supplier_split_id='f1080004-0000-4000-8000-000000000005';
insert into atlas_procurement.purchase_order_lines
select (jsonb_populate_record(null::atlas_procurement.purchase_order_lines,to_jsonb(source)||
  jsonb_build_object('purchase_order_line_id','f1080005-0000-4000-8000-000000000013',
    'school_catering_allocation_family_id','f1080004-0000-4000-8000-000000000011'))).*
from atlas_procurement.purchase_order_lines source
where purchase_order_line_id='f1080005-0000-4000-8000-000000000003';
insert into atlas_procurement.purchase_order_line_revisions
select (jsonb_populate_record(null::atlas_procurement.purchase_order_line_revisions,to_jsonb(source)||
  jsonb_build_object('purchase_order_line_revision_id','f1080005-0000-4000-8000-000000000014',
    'purchase_order_line_id','f1080005-0000-4000-8000-000000000013',
    'school_catering_allocation_supplier_split_id','f1080004-0000-4000-8000-000000000015',
    'ordered_quantity',50,'delivery_location_id','f1080002-0000-4000-8000-000000000012'))).*
from atlas_procurement.purchase_order_line_revisions source
where purchase_order_line_revision_id='f1080005-0000-4000-8000-000000000004';
set local session_replication_role=origin;
insert into atlas_core.role_capabilities(role_id,capability_id)
select 'f1080001-0000-4000-8000-000000000001',capability_id
from atlas_core.capabilities where capability_code in (
  'procurement.school_catering.read','confirmed_need_release.release');

v_read_payload:=jsonb_build_object('date_start','2098-10-14','date_end','2098-10-14',
  'supplier_ids','[]'::jsonb,'statuses','[]'::jsonb,'search',null);
v_po_payload:=jsonb_build_object('purchase_order_id','f1080005-0000-4000-8000-000000000001',
  'expected_purchase_order_revision_id','f1080005-0000-4000-8000-000000000002');
perform set_config('request.jwt.claim.sub','f1080000-0000-4000-8000-000000000102',true);
set local role authenticated;
v_response:=atlas_api.get_school_catering_purchase_orders(
  pg_temp.a108_read('SCHOOL-CATERING-PROCUREMENT.v1',v_read_payload));
reset role;
perform pg_temp.a108_require('po_partial_read_hidden',
  v_response->>'success'='true' and jsonb_array_length(v_response->'purchase_orders')=0);
set local role authenticated;
v_response:=atlas_api.release_school_catering_purchase_order(pg_temp.a108_command(
  'SCHOOL-CATERING-PROCUREMENT.v1','SCHOOL_CATERING_PO_RELEASED',1,v_po_payload));
reset role;
perform pg_temp.a108_require('po_partial_release_denied',v_response->>'error_code'='SCOPE_DENIED');

perform set_config('request.jwt.claim.sub','f1080000-0000-4000-8000-000000000104',true);
set local role authenticated;
v_response:=atlas_api.get_school_catering_purchase_orders(
  pg_temp.a108_read('SCHOOL-CATERING-PROCUREMENT.v1',v_read_payload));
reset role;
perform pg_temp.a108_require('po_missing_read_capability',v_response->>'error_code'='CAPABILITY_DENIED');
set local role authenticated;
v_response:=atlas_api.release_school_catering_purchase_order(pg_temp.a108_command(
  'SCHOOL-CATERING-PROCUREMENT.v1','SCHOOL_CATERING_PO_RELEASED',1,v_po_payload));
reset role;
perform pg_temp.a108_require('po_missing_write_capability',v_response->>'error_code'='CAPABILITY_DENIED');

perform set_config('request.jwt.claim.sub','f1080000-0000-4000-8000-000000000101',true);
set local role authenticated;
v_response:=pg_temp.a108_isolated('PO',pg_temp.a108_command(
  'SCHOOL-CATERING-PROCUREMENT.v1','SCHOOL_CATERING_PO_RELEASED',1,v_po_payload));
reset role;
perform pg_temp.a108_require('po_global_release_control',v_response->>'success'='true');
insert into atlas_core.actor_scopes(actor_id,scope_kind,school_id)
values('f1080000-0000-4000-8000-000000000002','SCHOOL','f1080002-0000-4000-8000-000000000022');
perform set_config('request.jwt.claim.sub','f1080000-0000-4000-8000-000000000102',true);
set local role authenticated;
v_response:=atlas_api.get_school_catering_purchase_orders(
  pg_temp.a108_read('SCHOOL-CATERING-PROCUREMENT.v1',v_read_payload));
reset role;
perform pg_temp.a108_require('po_complete_school_read',v_response->>'success'='true'
  and jsonb_array_length(v_response->'purchase_orders')=1
  and jsonb_array_length(v_response#>'{purchase_orders,0,lines}')=2);
set local role authenticated;
v_response:=atlas_api.release_school_catering_purchase_order(pg_temp.a108_command(
  'SCHOOL-CATERING-PROCUREMENT.v1','SCHOOL_CATERING_PO_RELEASED',99,v_po_payload));
reset role;
perform pg_temp.a108_require('po_stale_version_denied',v_response->>'error_code'='STALE_VERSION');
set local role authenticated;
v_request:=pg_temp.a108_command('SCHOOL-CATERING-PROCUREMENT.v1',
  'SCHOOL_CATERING_PO_RELEASED',1,v_po_payload);
v_response:=atlas_api.release_school_catering_purchase_order(v_request);
v_replay:=atlas_api.release_school_catering_purchase_order(v_request);
reset role;
perform pg_temp.a108_require('po_complete_school_release',v_response->>'success'='true');
perform pg_temp.a108_require('po_replay_preserves_number',v_replay->>'success'='true'
  and v_replay->>'document_number'=v_response->>'document_number'
  and v_replay->>'purchase_order_revision_id'=v_response->>'purchase_order_revision_id');
v_po_number:=v_response->>'document_number';
perform pg_temp.a108_require('po_official_number_and_snapshot',v_po_number like 'PO-20981014-%'
  and (select count(*)=2 and bool_and(jsonb_array_length(line.school_breakdown_snapshot)=1)
    from atlas_procurement.purchase_order_line_revisions line
    where purchase_order_revision_id=(v_response->>'purchase_order_revision_id')::uuid));

delete from atlas_core.actor_scopes where actor_id='f1080000-0000-4000-8000-000000000002'
  and school_id='f1080002-0000-4000-8000-000000000022';
v_read_payload:=jsonb_build_object('date_start','2098-10-14','date_end','2098-10-14',
  'school_ids','[]'::jsonb,'search',null);
v_pxk_payload:=jsonb_build_object('service_date','2098-10-14',
  'school_id','f1080002-0000-4000-8000-000000000021',
  'delivery_location_id','f1080002-0000-4000-8000-000000000011',
  'expected_source_fingerprint',atlas_core.school_dispatch_release_preview('2098-10-14',
    'f1080002-0000-4000-8000-000000000021',
    'f1080002-0000-4000-8000-000000000011')->>'source_fingerprint',
  'predecessor_release_id',null);
perform set_config('request.jwt.claim.sub','f1080000-0000-4000-8000-000000000104',true);
set local role authenticated;
v_response:=atlas_api.get_school_dispatch_release_workbench(
  pg_temp.a108_read('SCHOOL-DISPATCH-RELEASE.v1',v_read_payload));
reset role;
perform pg_temp.a108_require('pxk_missing_read_capability',v_response->>'error_code'='CAPABILITY_DENIED');
set local role authenticated;
v_response:=atlas_api.get_school_fulfilment_reconciliation_workbench(
  pg_temp.a108_read('SCHOOL-FULFILMENT-RECONCILIATION.v1',v_read_payload));
reset role;
perform pg_temp.a108_require('reconciliation_missing_capability',v_response->>'error_code'='CAPABILITY_DENIED');
set local role authenticated;
v_response:=atlas_api.release_school_dispatch_document(pg_temp.a108_command(
  'SCHOOL-DISPATCH-RELEASE.v1','SCHOOL_DISPATCH_DOCUMENT_RELEASED',0,v_pxk_payload));
reset role;
perform pg_temp.a108_require('pxk_missing_release_capability',v_response->>'error_code'='CAPABILITY_DENIED');
perform set_config('request.jwt.claim.sub','f1080000-0000-4000-8000-000000000103',true);
set local role authenticated;
v_response:=atlas_api.release_school_dispatch_document(pg_temp.a108_command(
  'SCHOOL-DISPATCH-RELEASE.v1','SCHOOL_DISPATCH_DOCUMENT_RELEASED',0,v_pxk_payload));
reset role;
perform pg_temp.a108_require('pxk_wrong_school_denied',v_response->>'error_code'='SCOPE_DENIED');
perform set_config('request.jwt.claim.sub','f1080000-0000-4000-8000-000000000101',true);
set local role authenticated;
v_response:=pg_temp.a108_isolated('PXK',pg_temp.a108_command(
  'SCHOOL-DISPATCH-RELEASE.v1','SCHOOL_DISPATCH_DOCUMENT_RELEASED',0,v_pxk_payload));
reset role;
perform pg_temp.a108_require('pxk_global_release_control',v_response->>'success'='true');
perform set_config('request.jwt.claim.sub','f1080000-0000-4000-8000-000000000102',true);
set local role authenticated;
v_request:=pg_temp.a108_command('SCHOOL-DISPATCH-RELEASE.v1','SCHOOL_DISPATCH_DOCUMENT_RELEASED',0,v_pxk_payload);
v_response:=atlas_api.release_school_dispatch_document(v_request);
v_replay:=atlas_api.release_school_dispatch_document(v_request);
reset role;
perform pg_temp.a108_require('pxk_scoped_release',v_response->>'success'='true');
perform pg_temp.a108_require('pxk_replay_and_number',v_replay->>'success'='true'
  and v_replay->>'document_number'=v_response->>'document_number'
  and v_response->>'document_number' like 'PXK-20981014-%');
set local role authenticated;
v_response:=atlas_api.get_school_dispatch_release_workbench(
  pg_temp.a108_read('SCHOOL-DISPATCH-RELEASE.v1',v_read_payload));
reset role;
perform pg_temp.a108_require('pxk_scoped_rows',v_response->>'success'='true'
  and jsonb_array_length(v_response->'rows')=1
  and v_response#>>'{rows,0,school_id}'='f1080002-0000-4000-8000-000000000021');
set local role authenticated;
v_response:=atlas_api.get_school_fulfilment_reconciliation_workbench(
  pg_temp.a108_read('SCHOOL-FULFILMENT-RECONCILIATION.v1',v_read_payload));
reset role;
perform pg_temp.a108_require('reconciliation_scoped_rows',v_response->>'success'='true'
  and jsonb_array_length(v_response->'rows')=1
  and v_response#>>'{rows,0,school_id}'='f1080002-0000-4000-8000-000000000021'
  and v_response#>>'{rows,0,comparison_status}'='OK');
perform set_config('request.jwt.claim.sub','f1080000-0000-4000-8000-000000000101',true);
set local role authenticated;
v_response:=atlas_api.get_school_dispatch_release_workbench(
  pg_temp.a108_read('SCHOOL-DISPATCH-RELEASE.v1',v_read_payload));
reset role;
perform pg_temp.a108_require('pxk_global_read_control',v_response->>'success'='true'
  and jsonb_array_length(v_response->'rows')=2);
set local role authenticated;
v_response:=atlas_api.get_school_fulfilment_reconciliation_workbench(
  pg_temp.a108_read('SCHOOL-FULFILMENT-RECONCILIATION.v1',v_read_payload));
reset role;
perform pg_temp.a108_require('reconciliation_global_control',v_response->>'success'='true'
  and jsonb_array_length(v_response->'rows')=2);

-- Migration 109 policy extension. Earlier 108 reports remain pinned to their
-- reviewed source; this current harness additionally proves exact School scope.
perform pg_temp.a108_require('migration_109_present',exists(select 1
 from supabase_migrations.schema_migrations where version='20261014120320'));
perform pg_temp.a108_require('dispatch_helper_security_unchanged',(
 select pg_get_userbyid(proowner)='atlas_read_runtime' and prosecdef
  and proconfig=array['search_path=""']::text[]
  and not exists(select 1 from aclexplode(proacl) acl where acl.grantee<>proowner
   and (acl.grantee not in ('atlas_read_runtime'::regrole,'atlas_dispatch_command_runtime'::regrole)
    or acl.privilege_type<>'EXECUTE' or acl.is_grantable))
  and has_function_privilege('atlas_read_runtime',oid,'EXECUTE')
  and has_function_privilege('atlas_dispatch_command_runtime',oid,'EXECUTE')
  and not has_function_privilege('authenticated',oid,'EXECUTE')
  and not has_function_privilege('anon',oid,'EXECUTE')
  and not has_function_privilege('service_role',oid,'EXECUTE')
 from pg_proc where oid='atlas_core.school_dispatch_actor_has_scope(uuid,uuid,uuid)'::regprocedure));
v_frozen_pxk:=atlas_core.school_dispatch_release_json((select school_dispatch_release_id
 from atlas_dispatch.school_dispatch_releases where school_id='f1080002-0000-4000-8000-000000000021'));
update atlas_admin.schools set default_delivery_location_id='f1080002-0000-4000-8000-000000000012'
where school_id='f1080002-0000-4000-8000-000000000021';
v_b_payload:=v_pxk_payload||jsonb_build_object('school_id','f1080002-0000-4000-8000-000000000022',
 'delivery_location_id','f1080002-0000-4000-8000-000000000012',
 'expected_source_fingerprint',atlas_core.school_dispatch_release_preview('2098-10-14',
  'f1080002-0000-4000-8000-000000000022','f1080002-0000-4000-8000-000000000012')->>'source_fingerprint');
perform set_config('request.jwt.claim.sub','f1080000-0000-4000-8000-000000000102',true);
v_before_counts:=jsonb_build_array((select count(*) from atlas_core.command_receipts),
 (select count(*) from atlas_dispatch.school_dispatch_releases),(select count(*) from atlas_audit.audit_events));
set local role authenticated;
v_response:=atlas_api.get_school_dispatch_release_workbench(pg_temp.a108_read('SCHOOL-DISPATCH-RELEASE.v1',v_read_payload));
reset role;
perform pg_temp.a108_require('exact_school_shared_default_read',
 v_response->>'success'='true' and jsonb_array_length(v_response->'rows')=1
 and v_response#>>'{rows,0,school_id}'='f1080002-0000-4000-8000-000000000021'
 and v_response#>>'{rows,0,delivery_location_id}'='f1080002-0000-4000-8000-000000000011');
set local role authenticated;
v_response:=atlas_api.get_school_fulfilment_reconciliation_workbench(
 pg_temp.a108_read('SCHOOL-FULFILMENT-RECONCILIATION.v1',v_read_payload));
reset role;
perform pg_temp.a108_require('exact_school_shared_default_reconciliation',
 v_response->>'success'='true' and jsonb_array_length(v_response->'rows')=1
 and v_response#>>'{rows,0,school_id}'='f1080002-0000-4000-8000-000000000021');
set local role authenticated;
v_response:=atlas_api.release_school_dispatch_document(pg_temp.a108_command(
 'SCHOOL-DISPATCH-RELEASE.v1','SCHOOL_DISPATCH_DOCUMENT_RELEASED',0,v_b_payload));
reset role;
perform pg_temp.a108_require('exact_school_shared_default_release_denied',v_response->>'error_code'='SCOPE_DENIED');
perform pg_temp.a108_require('exact_school_denial_zero_writes',v_before_counts=jsonb_build_array(
 (select count(*) from atlas_core.command_receipts),(select count(*) from atlas_dispatch.school_dispatch_releases),
 (select count(*) from atlas_audit.audit_events)));
-- Explicit location/customer/global coverage retains its existing meaning.
for v_control in select * from (values
 ('DELIVERY_LOCATION',1),('CUSTOMER',2),('GLOBAL',2)) control(kind,want)
loop
 update atlas_core.actor_scopes set scope_kind=v_control.kind,school_id=null,
  customer_id=case when v_control.kind='CUSTOMER' then 'f1080002-0000-4000-8000-000000000001'::uuid end,
  delivery_location_id=case when v_control.kind='DELIVERY_LOCATION' then 'f1080002-0000-4000-8000-000000000012'::uuid end
 where actor_id='f1080000-0000-4000-8000-000000000003';
 perform set_config('request.jwt.claim.sub','f1080000-0000-4000-8000-000000000103',true);
 set local role authenticated;
 v_response:=atlas_api.get_school_dispatch_release_workbench(pg_temp.a108_read('SCHOOL-DISPATCH-RELEASE.v1',v_read_payload));
 reset role;
 perform pg_temp.a108_require('explicit_'||v_control.kind||'_read',v_response->>'success'='true'
  and jsonb_array_length(v_response->'rows')=v_control.want);
 set local role authenticated;
 v_response:=atlas_api.get_school_fulfilment_reconciliation_workbench(
  pg_temp.a108_read('SCHOOL-FULFILMENT-RECONCILIATION.v1',v_read_payload));
 reset role;
 perform pg_temp.a108_require('explicit_'||v_control.kind||'_reconciliation',v_response->>'success'='true'
  and jsonb_array_length(v_response->'rows')=v_control.want);
 set local role authenticated;
 v_response:=pg_temp.a108_isolated('PXK',pg_temp.a108_command(
  'SCHOOL-DISPATCH-RELEASE.v1','SCHOOL_DISPATCH_DOCUMENT_RELEASED',0,v_b_payload));
 reset role;
 perform pg_temp.a108_require('explicit_'||v_control.kind||'_release',v_response->>'success'='true');
end loop;
insert into atlas_core.actor_scopes(actor_id,scope_kind,school_id)
values('f1080000-0000-4000-8000-000000000002','SCHOOL','f1080002-0000-4000-8000-000000000022');
perform set_config('request.jwt.claim.sub','f1080000-0000-4000-8000-000000000102',true);
set local role authenticated;
v_response:=atlas_api.get_school_dispatch_release_workbench(pg_temp.a108_read('SCHOOL-DISPATCH-RELEASE.v1',v_read_payload));
reset role;
perform pg_temp.a108_require('single_actor_multiple_school_read',v_response->>'success'='true'
 and jsonb_array_length(v_response->'rows')=2);
set local role authenticated;
v_response:=atlas_api.get_school_fulfilment_reconciliation_workbench(
 pg_temp.a108_read('SCHOOL-FULFILMENT-RECONCILIATION.v1',v_read_payload));
reset role;
perform pg_temp.a108_require('single_actor_multiple_school_reconciliation',v_response->>'success'='true'
 and jsonb_array_length(v_response->'rows')=2);
set local role authenticated;
v_request:=pg_temp.a108_command('SCHOOL-DISPATCH-RELEASE.v1','SCHOOL_DISPATCH_DOCUMENT_RELEASED',0,v_b_payload);
v_response:=atlas_api.release_school_dispatch_document(v_request);
v_replay:=atlas_api.release_school_dispatch_document(v_request);
reset role;
perform pg_temp.a108_require('single_actor_multiple_school_release',v_response->>'success'='true');
perform pg_temp.a108_require('single_actor_release_attribution',(
 select count(*)=2 and bool_and(released_by_actor_id='f1080000-0000-4000-8000-000000000002')
 from atlas_dispatch.school_dispatch_releases where school_id::text like 'f108%')
 and (select count(*)=2 and bool_and(actor_id='f1080000-0000-4000-8000-000000000002'
  and delegated_actor_id is null) from atlas_audit.audit_events
  where aggregate_id in (select school_dispatch_release_id from atlas_dispatch.school_dispatch_releases
   where school_id::text like 'f108%')));
perform pg_temp.a108_require('single_actor_release_replay',v_replay->>'success'='true'
 and v_replay->>'document_number'=v_response->>'document_number'
 and v_replay->>'school_dispatch_release_id'=v_response->>'school_dispatch_release_id');
perform pg_temp.a108_require('default_change_frozen_pxk_unchanged',v_frozen_pxk=
 atlas_core.school_dispatch_release_json((select school_dispatch_release_id
 from atlas_dispatch.school_dispatch_releases where school_id='f1080002-0000-4000-8000-000000000021')));
delete from atlas_core.actor_scopes where actor_id='f1080000-0000-4000-8000-000000000002'
 and school_id='f1080002-0000-4000-8000-000000000022';

-- Exercise the existing v2 lifecycle GLOBAL gate with full synthetic Customer scope.
update atlas_core.actor_scopes set scope_kind='CUSTOMER',school_id=null,
  customer_id='f1080002-0000-4000-8000-000000000001'
where actor_id='f1080000-0000-4000-8000-000000000003';
set local session_replication_role=replica;
update atlas_planning.confirmed_need_batches set batch_status='DRAFT_REVIEW'
where confirmed_need_batch_id='f1080003-0000-4000-8000-000000000001';
set local session_replication_role=origin;
perform set_config('request.jwt.claim.sub','f1080000-0000-4000-8000-000000000103',true);
set local role authenticated;
v_response:=atlas_api.prepare_school_catering_purchase_orders(pg_temp.a108_command(
  'PURCHASE-COMMITMENT.v1','PURCHASE_ORDERS_PREPARED',1,
  jsonb_build_object('confirmed_need_batch_id','f1080003-0000-4000-8000-000000000001',
    'service_date','2098-10-14')));
reset role;
perform pg_temp.a108_require('preparation_still_requires_global',v_response->>'error_code'='ACTOR_NOT_AUTHORIZED');
perform pg_temp.a108_require('preparation_did_not_change_commitments',(
  select version=2 and purchase_order_status='RELEASED_TO_SUPPLIER' and document_number=v_po_number
  from atlas_procurement.purchase_orders where purchase_order_id='f1080005-0000-4000-8000-000000000001'));

-- Whole-PO scope remains unchanged by the later Dispatch-only policy.
update atlas_admin.schools set default_delivery_location_id='f1080002-0000-4000-8000-000000000012'
where school_id='f1080002-0000-4000-8000-000000000021';
perform set_config('request.jwt.claim.sub','f1080000-0000-4000-8000-000000000102',true);
set local role authenticated;
v_response:=atlas_api.release_school_catering_purchase_order(pg_temp.a108_command(
  'SCHOOL-CATERING-PROCUREMENT.v1','SCHOOL_CATERING_PO_RELEASED',2,v_po_payload));
reset role;
perform pg_temp.a108_require('po_shared_default_still_denied',v_response->>'error_code'='SCOPE_DENIED');

select count(*),jsonb_agg(label order by label) into v_count,v_result from pg_temp.a108_checks;
if v_count<>48 then raise exception 'A109 synthetic case count mismatch: %',v_count; end if;
v_result:=jsonb_build_object('case_count',v_count,'cases',v_result,
  'synthetic_date','2098-10-14','synthetic_releases_only',true);
raise exception using errcode='Z1080',message='Successful acceptance rollback';
exception when sqlstate 'Z1080' then null;
 end;
if exists(select 1 from atlas_core.actors where actor_id::text like 'f108%')
  or exists(select 1 from atlas_procurement.purchase_orders
    where supplier_id::text like 'f108%')
  or exists(select 1 from atlas_dispatch.school_dispatch_releases
    where school_id::text like 'f108%') then
  raise exception 'A108 synthetic probe persisted';
end if;
insert into pg_temp.a108_report values(v_result||jsonb_build_object(
  'success',true,'probe_rollback_verified',true));
end;
$acceptance$;
select result from pg_temp.a108_report;
rollback;
