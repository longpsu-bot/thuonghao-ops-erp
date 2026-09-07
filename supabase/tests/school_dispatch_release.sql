begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set search_path = extensions, public, pg_catalog;

select plan(39);

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
  school_id,customer_id,school_code,school_name,default_delivery_location_id,display_order)
values('26020000-0000-4000-8000-000000000021','26020000-0000-4000-8000-000000000001',
  'pxk-school','Trường Tiểu học Nguyễn Du','26020000-0000-4000-8000-000000000011',1);
insert into atlas_admin.units(unit_id,unit_code,unit_name,dimension_code)
values('26020000-0000-4000-8000-000000000031','pxk-kg','Kilôgam','mass');
insert into atlas_admin.ingredients(ingredient_id,ingredient_code,ingredient_name,purchase_unit_id)
values('26020000-0000-4000-8000-000000000041','pxk-rice','Gạo thơm',
  '26020000-0000-4000-8000-000000000031');
insert into atlas_admin.suppliers(supplier_id,supplier_code,supplier_name,supplier_status)
values
  ('26020000-0000-4000-8000-000000000051','pxk-supplier-a','NCC An Phú','ACTIVE'),
  ('26020000-0000-4000-8000-000000000052','pxk-supplier-b','NCC Bình Minh','ACTIVE');
insert into atlas_admin.supplier_eligibilities(
  supplier_id,ingredient_id,effective_from,priority,reason_note)
values
  ('26020000-0000-4000-8000-000000000051','26020000-0000-4000-8000-000000000041',
    '2026-01-01',1,'PXK test'),
  ('26020000-0000-4000-8000-000000000052','26020000-0000-4000-8000-000000000041',
    '2026-01-01',2,'PXK test');

-- Exact current Confirmed Need -> Handoff -> Allocation -> released PO evidence.
set session_replication_role=replica;
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
grant execute on function pg_temp.pxk_read(),
  pg_temp.pxk_release(uuid,bigint,uuid,text)
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

set local role authenticated;
select set_config('request.jwt.claim.sub','26000000-0000-4000-8000-000000000101',true);
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
select ok((select release_status='RELEASED' and source_fingerprint is not null
    and school_name_snapshot='Trường Tiểu học Nguyễn Du'
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
select ok((select pg_get_functiondef(
    'atlas_core.school_dispatch_release_preview(date,uuid,uuid)'::regprocedure)
    !~* '\m(stock|inventory|lot|reservation|pick|trip|vehicle|driver|load)\M'),
  'PXK readiness has no stock, receiving, trip, vehicle, driver, or load dependency');
select ok((select pg_get_functiondef(
    'atlas_core.school_dispatch_release_preview(date,uuid,uuid)'::regprocedure)
      ~ 'contribution_start'
    and pg_get_functiondef(
      'atlas_core.school_dispatch_release_preview(date,uuid,uuid)'::regprocedure)
      !~ 'contribution_quantity\s*\*\s*split\.split_ratio'),
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
  'removed-supplier commitment blocks PXK and exposes cancellation-required');
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

select * from finish();
rollback;
