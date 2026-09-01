begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set search_path = extensions, public, pg_catalog;

select plan(18);

select ok(to_regprocedure('atlas_api.prepare_planning_source_correction(jsonb)') is not null,
  'D-042 keeps the existing public correction command');
select ok(to_regprocedure('atlas_api.get_planning_source_correction_impact(jsonb)') is not null,
  'D-042 keeps the existing public impact read');
select ok(to_regprocedure('atlas_api.release_school_catering_purchase_handoff(jsonb)') is not null,
  'corrected Planning release has a school-catering Handoff command');
select ok(to_regclass('atlas_procurement.school_catering_allocation_family_revisions') is not null,
  'school-catering allocation revisions can remain as historical evidence');
select ok(to_regprocedure('atlas_core.issue_222_chain_payload(uuid)') is not null,
  'the D-042 chain classifier remains available to its governed wrappers');
select ok(to_regprocedure('atlas_core.school_catering_purchase_handoff_source_kind(uuid)') is not null,
  'D-042 has a source-aware Handoff classifier for school catering versus WHOLESALE');

set session_replication_role = replica;
insert into atlas_planning.confirmed_need_batches(
  confirmed_need_batch_id,period_start,period_end,batch_status,version,created_by_actor_id,
  source_kind,origin_need_generation_run_id,origin_need_generation_run_version,
  origin_need_generation_release_snapshot_id,current_need_generation_run_id,
  current_need_generation_run_version,current_need_generation_release_snapshot_id,
  current_confirmed_need_approval_snapshot_id,current_confirmed_need_release_id)
values('51000000-0000-4000-8000-000000000001','2026-09-02','2026-09-02',
  'RELEASED_FOR_PURCHASE_HANDOFF',7,'51000000-0000-4000-8000-000000000099',
  'NEED_GENERATION','51000000-0000-4000-8000-000000000011',1,
  '51000000-0000-4000-8000-000000000012','51000000-0000-4000-8000-000000000011',1,
  '51000000-0000-4000-8000-000000000012','51000000-0000-4000-8000-000000000013',
  '51000000-0000-4000-8000-000000000014'),
 ('51000000-0000-4000-8000-000000000003','2026-09-04','2026-09-04',
  'RELEASED_FOR_PURCHASE_HANDOFF',7,'51000000-0000-4000-8000-000000000099',
  'NEED_GENERATION','51000000-0000-4000-8000-000000000031',1,
  '51000000-0000-4000-8000-000000000032','51000000-0000-4000-8000-000000000031',1,
  '51000000-0000-4000-8000-000000000032','51000000-0000-4000-8000-000000000033',
  '51000000-0000-4000-8000-000000000034');
insert into atlas_planning.purchase_handoff_batches(
  purchase_handoff_batch_id,confirmed_need_batch_id,period_start,period_end,handoff_status,version,created_by_actor_id)
values
 ('52000000-0000-4000-8000-000000000001','51000000-0000-4000-8000-000000000001',
  '2026-09-02','2026-09-02','RELEASED_TO_PROCUREMENT',1,'51000000-0000-4000-8000-000000000099'),
 ('52000000-0000-4000-8000-000000000002','51000000-0000-4000-8000-000000000002',
  '2026-09-03','2026-09-03','RELEASED_TO_PROCUREMENT',1,'51000000-0000-4000-8000-000000000099'),
 ('52000000-0000-4000-8000-000000000003','51000000-0000-4000-8000-000000000003',
  '2026-09-04','2026-09-04','RELEASED_TO_PROCUREMENT',1,'51000000-0000-4000-8000-000000000099');
insert into atlas_planning.purchase_handoff_revisions(
  purchase_handoff_revision_id,purchase_handoff_batch_id,revision_number,revision_kind,
  revision_status,is_current,released_by_actor_id,released_at,command_id)
values
 ('53000000-0000-4000-8000-000000000001','52000000-0000-4000-8000-000000000001',1,'BASE',
  'RELEASED_TO_PROCUREMENT',true,'51000000-0000-4000-8000-000000000099',transaction_timestamp(),
  '53000000-0000-4000-8000-000000000011'),
 ('53000000-0000-4000-8000-000000000002','52000000-0000-4000-8000-000000000002',1,'BASE',
  'RELEASED_TO_PROCUREMENT',true,'51000000-0000-4000-8000-000000000099',transaction_timestamp(),
  '53000000-0000-4000-8000-000000000012'),
 ('53000000-0000-4000-8000-000000000003','52000000-0000-4000-8000-000000000003',1,'BASE',
  'RELEASED_TO_PROCUREMENT',true,'51000000-0000-4000-8000-000000000099',transaction_timestamp(),
  '53000000-0000-4000-8000-000000000013');
insert into atlas_planning.purchase_handoff_lines(
  purchase_handoff_line_id,purchase_handoff_batch_id,confirmed_need_line_id)
values
 ('54000000-0000-4000-8000-000000000001','52000000-0000-4000-8000-000000000001','54000000-0000-4000-8000-000000000011'),
 ('54000000-0000-4000-8000-000000000002','52000000-0000-4000-8000-000000000002','54000000-0000-4000-8000-000000000012');
insert into atlas_planning.purchase_handoff_lines(
  purchase_handoff_line_id,purchase_handoff_batch_id,confirmed_need_line_id)
values('54000000-0000-4000-8000-000000000003','52000000-0000-4000-8000-000000000003',
  '54000000-0000-4000-8000-000000000013');
insert into atlas_planning.purchase_handoff_line_revisions(
  purchase_handoff_line_revision_id,purchase_handoff_revision_id,purchase_handoff_line_id,
  confirmed_need_line_revision_id,ingredient_id,handoff_quantity,unit_id,service_date,
  delivery_location_id,command_id)
values
 ('55000000-0000-4000-8000-000000000001','53000000-0000-4000-8000-000000000001',
  '54000000-0000-4000-8000-000000000001','55000000-0000-4000-8000-000000000011',
  '55000000-0000-4000-8000-000000000021',100,'55000000-0000-4000-8000-000000000022',
  '2026-09-02','55000000-0000-4000-8000-000000000023','53000000-0000-4000-8000-000000000011'),
 ('55000000-0000-4000-8000-000000000002','53000000-0000-4000-8000-000000000002',
  '54000000-0000-4000-8000-000000000002','55000000-0000-4000-8000-000000000012',
  '55000000-0000-4000-8000-000000000021',100,'55000000-0000-4000-8000-000000000022',
  '2026-09-03','55000000-0000-4000-8000-000000000023','53000000-0000-4000-8000-000000000012'),
 ('55000000-0000-4000-8000-000000000003','53000000-0000-4000-8000-000000000003',
  '54000000-0000-4000-8000-000000000003','55000000-0000-4000-8000-000000000013',
  '55000000-0000-4000-8000-000000000021',100,'55000000-0000-4000-8000-000000000022',
  '2026-09-04','55000000-0000-4000-8000-000000000023','53000000-0000-4000-8000-000000000013');
insert into atlas_planning.purchase_demand_references(
  purchase_demand_reference_id,purchase_handoff_line_revision_id,confirmed_need_snapshot_line_id,
  wholesale_order_line_revision_id,approved_quantity,unit_id,source_kind)
values
 ('56000000-0000-4000-8000-000000000001','55000000-0000-4000-8000-000000000001',
  '56000000-0000-4000-8000-000000000011',null,100,'55000000-0000-4000-8000-000000000022','NEED_GENERATION'),
 ('56000000-0000-4000-8000-000000000002','55000000-0000-4000-8000-000000000002',
  '56000000-0000-4000-8000-000000000012','56000000-0000-4000-8000-000000000013',100,
  '55000000-0000-4000-8000-000000000022','WHOLESALE'),
 ('56000000-0000-4000-8000-000000000003','55000000-0000-4000-8000-000000000003',
  '56000000-0000-4000-8000-000000000033',null,100,
  '55000000-0000-4000-8000-000000000022','NEED_GENERATION');

insert into atlas_procurement.school_catering_allocation_families(
  family_id,service_date,delivery_location_id,ingredient_id,unit_id)
values
 ('57000000-0000-4000-8000-000000000001','2026-09-02','55000000-0000-4000-8000-000000000023',
  '55000000-0000-4000-8000-000000000021','55000000-0000-4000-8000-000000000022'),
 ('57000000-0000-4000-8000-000000000003','2026-09-04','55000000-0000-4000-8000-000000000023',
  '55000000-0000-4000-8000-000000000021','55000000-0000-4000-8000-000000000022');
insert into atlas_procurement.school_catering_allocation_family_revisions(
  family_revision_id,family_id,revision_number,is_current,source_purchase_handoff_revision_id,
  source_fingerprint,family_quantity,unit_id,accepted_by_actor_id,command_id,decision_origin)
values
 ('58000000-0000-4000-8000-000000000001','57000000-0000-4000-8000-000000000001',1,true,
  '53000000-0000-4000-8000-000000000001','draft-source',100,
  '55000000-0000-4000-8000-000000000022','51000000-0000-4000-8000-000000000099',
  '58000000-0000-4000-8000-000000000011','MANUAL'),
 ('58000000-0000-4000-8000-000000000003','57000000-0000-4000-8000-000000000003',1,true,
  '53000000-0000-4000-8000-000000000003','released-source',100,
  '55000000-0000-4000-8000-000000000022','51000000-0000-4000-8000-000000000099',
  '58000000-0000-4000-8000-000000000013','MANUAL');
insert into atlas_procurement.school_catering_allocation_family_contributions(
  family_revision_id,purchase_handoff_line_revision_id,contribution_quantity)
values
 ('58000000-0000-4000-8000-000000000001','55000000-0000-4000-8000-000000000001',100),
 ('58000000-0000-4000-8000-000000000003','55000000-0000-4000-8000-000000000003',100);
insert into atlas_procurement.school_catering_allocation_supplier_splits(
  supplier_split_id,family_revision_id,supplier_id,allocated_quantity,split_ratio,decision_origin)
values
 ('59000000-0000-4000-8000-000000000001','58000000-0000-4000-8000-000000000001',
  '59000000-0000-4000-8000-000000000010',100,1,'MANUAL'),
 ('59000000-0000-4000-8000-000000000003','58000000-0000-4000-8000-000000000003',
  '59000000-0000-4000-8000-000000000010',100,1,'MANUAL');
insert into atlas_procurement.purchase_orders(
  purchase_order_id,supplier_id,document_number,purchase_order_status,version,
  purchase_order_kind,school_catering_service_date)
values
 ('5a000000-0000-4000-8000-000000000001','59000000-0000-4000-8000-000000000010',null,
  'DRAFT',1,'SCHOOL_CATERING','2026-09-02'),
 ('5a000000-0000-4000-8000-000000000003','59000000-0000-4000-8000-000000000010',
  'PO-20260904-5A00000000004000','RELEASED_TO_SUPPLIER',2,'SCHOOL_CATERING','2026-09-04');
insert into atlas_procurement.purchase_order_revisions(
  purchase_order_revision_id,purchase_order_id,revision_number,revision_kind,revision_status,
  is_current,service_date,delivery_location_id,supplier_name_snapshot,
  delivery_location_snapshot,command_id)
values
 ('5b000000-0000-4000-8000-000000000001','5a000000-0000-4000-8000-000000000001',1,'BASE',
  'DRAFT',true,'2026-09-02',null,'D-042 Supplier','Nhiều điểm giao',
  '5b000000-0000-4000-8000-000000000011'),
 ('5b000000-0000-4000-8000-000000000003','5a000000-0000-4000-8000-000000000003',2,
  'SUPERSEDING','RELEASED_TO_SUPPLIER',true,'2026-09-04',null,'D-042 Supplier',
  'Nhiều điểm giao','5b000000-0000-4000-8000-000000000013');
insert into atlas_procurement.purchase_order_lines(
  purchase_order_line_id,purchase_order_id,school_catering_allocation_family_id)
values
 ('5c000000-0000-4000-8000-000000000001','5a000000-0000-4000-8000-000000000001',
  '57000000-0000-4000-8000-000000000001'),
 ('5c000000-0000-4000-8000-000000000003','5a000000-0000-4000-8000-000000000003',
  '57000000-0000-4000-8000-000000000003');
insert into atlas_procurement.purchase_order_line_revisions(
  purchase_order_revision_id,purchase_order_line_id,
  school_catering_allocation_supplier_split_id,ingredient_id,ordered_quantity,unit_id,
  delivery_location_id,service_date)
values
 ('5b000000-0000-4000-8000-000000000001','5c000000-0000-4000-8000-000000000001',
  '59000000-0000-4000-8000-000000000001','55000000-0000-4000-8000-000000000021',100,
  '55000000-0000-4000-8000-000000000022','55000000-0000-4000-8000-000000000023','2026-09-02'),
 ('5b000000-0000-4000-8000-000000000003','5c000000-0000-4000-8000-000000000003',
  '59000000-0000-4000-8000-000000000003','55000000-0000-4000-8000-000000000021',100,
  '55000000-0000-4000-8000-000000000022','55000000-0000-4000-8000-000000000023','2026-09-04');
set session_replication_role = origin;

select is(atlas_core.school_catering_purchase_handoff_source_kind(
  '52000000-0000-4000-8000-000000000001'),'SCHOOL_CATERING',
  'NEED_GENERATION Purchase Demand References classify the Handoff as school catering');
select is(atlas_core.school_catering_purchase_handoff_source_kind(
  '52000000-0000-4000-8000-000000000002'),'WHOLESALE',
  'WHOLESALE Purchase Demand References retain the wholesale Handoff boundary');

set session_replication_role = replica;
select atlas_core.issue_222_reopen_confirmed_need(
  '51000000-0000-4000-8000-000000000001',7);
set session_replication_role = origin;
select is((select batch_status from atlas_planning.confirmed_need_batches
  where confirmed_need_batch_id='51000000-0000-4000-8000-000000000001'),'REOPENED',
  'school-catering correction reopens Confirmed Need');
select is((select handoff_status from atlas_planning.purchase_handoff_batches
  where purchase_handoff_batch_id='52000000-0000-4000-8000-000000000001'),'INVALIDATED',
  'school-catering correction invalidates the active Handoff batch');
select ok((select revision_status='INVALIDATED' and not is_current
  from atlas_planning.purchase_handoff_revisions
  where purchase_handoff_revision_id='53000000-0000-4000-8000-000000000001'),
  'school-catering correction invalidates the current Handoff revision without deleting it');
select is((select count(*)::integer from atlas_planning.purchase_demand_references
  where purchase_handoff_line_revision_id='55000000-0000-4000-8000-000000000001'),1,
  'school-catering correction retains Purchase Demand Reference history');
select is((select purchase_order_status from atlas_procurement.purchase_orders
  where purchase_order_id='5a000000-0000-4000-8000-000000000001'),'DRAFT',
  'school-catering correction leaves the derived DRAFT PO untouched');
select ok(atlas_core.school_catering_po_draft_is_stale(
  '5a000000-0000-4000-8000-000000000001','5b000000-0000-4000-8000-000000000001'),
  'the untouched DRAFT PO becomes derived-stale after Handoff invalidation');
set session_replication_role = replica;
select throws_ok($$select atlas_core.issue_222_reopen_confirmed_need(
  '51000000-0000-4000-8000-000000000003',7)$$,'P0001',
  'Released school-catering PO blocks Planning correction',
  'released school-catering supplier commitment blocks D-042');
set session_replication_role = origin;
select is((select handoff_status from atlas_planning.purchase_handoff_batches
  where purchase_handoff_batch_id='52000000-0000-4000-8000-000000000003'),
  'RELEASED_TO_PROCUREMENT','released-PO blocker leaves the school-catering Handoff unchanged');
select throws_ok($$select atlas_core.issue_222_reopen_confirmed_need(
  '51000000-0000-4000-8000-000000000002',7)$$,'P0001',
  'Wholesale Purchase Handoff correction remains blocked',
  'WHOLESALE active Handoff remains blocked by D-042');
select is((select handoff_status from atlas_planning.purchase_handoff_batches
  where purchase_handoff_batch_id='52000000-0000-4000-8000-000000000002'),
  'RELEASED_TO_PROCUREMENT','blocked WHOLESALE Handoff remains current and unchanged');

select * from finish();
rollback;
