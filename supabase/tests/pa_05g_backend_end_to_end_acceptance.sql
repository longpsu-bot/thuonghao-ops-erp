begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
select no_plan();

grant usage on schema extensions to authenticated;
grant execute on all functions in schema extensions to authenticated;

-- PA-05G uses only rolled-back administration prerequisites. Every Planning,
-- Procurement, Evidence, Dispatch, receipt, event, and audit fact below is
-- authored by the reviewed atlas_api boundary.
insert into atlas_core.actors (
  actor_id, actor_type, display_name, actor_status, deactivated_at
) values
  ('f5000000-0000-0000-0000-000000000001','HUMAN','PA-05G operator','ACTIVE',null),
  ('f5000000-0000-0000-0000-000000000002','DELEGATED_DRIVER','PA-05G driver','ACTIVE',null);

insert into atlas_core.actor_auth_subjects (actor_id, auth_subject_id) values
  ('f5000000-0000-0000-0000-000000000001','f5000000-0000-0000-0000-000000000101');

insert into atlas_core.roles (role_id, role_code, role_name) values
  ('f5100000-0000-0000-0000-000000000001','pa05g.operator','PA-05G operator');

insert into atlas_core.capabilities (
  capability_id, capability_code, capability_name, owning_domain
) values
  ('f5200000-0000-0000-0000-000000000001','wholesale_source.record','Record wholesale source','PLANNING'),
  ('f5200000-0000-0000-0000-000000000002','wholesale_order.release','Release wholesale order','PLANNING'),
  ('f5200000-0000-0000-0000-000000000003','purchase_handoff.release','Release Purchase Handoff','PLANNING'),
  ('f5200000-0000-0000-0000-000000000004','dispatch_requirement.release','Release Dispatch Requirement','PLANNING'),
  ('f5200000-0000-0000-0000-000000000005','supplier_direct_fulfilment.allocate','Allocate supplier-direct fulfilment','PROCUREMENT'),
  ('f5200000-0000-0000-0000-000000000006','supplier_purchase_order.release','Release supplier purchase order','PROCUREMENT'),
  ('f5200000-0000-0000-0000-000000000007','supplier_receiving_evidence.record','Record supplier evidence','EVIDENCE'),
  ('f5200000-0000-0000-0000-000000000008','supplier_evidence_application.apply','Apply supplier evidence','EVIDENCE'),
  ('f5200000-0000-0000-0000-000000000009','dispatch_plan.create','Create Dispatch Plan','DISPATCH'),
  ('f5200000-0000-0000-0000-00000000000a','dispatch_trip.assign','Assign Dispatch Trip','DISPATCH'),
  ('f5200000-0000-0000-0000-00000000000b','dispatch_load.confirm','Confirm Dispatch load','DISPATCH'),
  ('f5200000-0000-0000-0000-00000000000c','dispatch_departure.record','Record Dispatch departure','DISPATCH'),
  ('f5200000-0000-0000-0000-00000000000d','delivery_success.confirm','Confirm successful delivery','DISPATCH'),
  ('f5200000-0000-0000-0000-00000000000e','dispatch_trip.close_successful','Close successful Dispatch Trip','DISPATCH'),
  ('f5200000-0000-0000-0000-00000000000f','supplier_direct_trace.read','Read supplier-direct trace','AUDIT'),
  ('f5200000-0000-0000-0000-000000000010','dispatch_evidence_readiness.read','Read evidence readiness','DISPATCH'),
  ('f5200000-0000-0000-0000-000000000011','operator_blockers.read','Read operator blockers','DISPATCH'),
  ('f5200000-0000-0000-0000-000000000012','command_audit_timeline.read','Read command audit timeline','AUDIT');

insert into atlas_core.role_capabilities (role_id, capability_id)
select 'f5100000-0000-0000-0000-000000000001', capability_id
from atlas_core.capabilities
where capability_id::text like 'f5200000-0000-0000-0000-0000000000%';

insert into atlas_core.actor_role_memberships (actor_id, role_id) values
  ('f5000000-0000-0000-0000-000000000001','f5100000-0000-0000-0000-000000000001');
insert into atlas_core.actor_scopes (actor_id, scope_kind) values
  ('f5000000-0000-0000-0000-000000000001','GLOBAL');

insert into atlas_admin.customers (customer_id, customer_code, customer_name) values
  ('f5300000-0000-0000-0000-000000000001','pa05g-wholesale','PA-05G Wholesale Customer');
insert into atlas_admin.delivery_locations (
  delivery_location_id, customer_id, location_code, location_name, address_text, timezone_name
) values (
  'f5300000-0000-0000-0000-000000000011','f5300000-0000-0000-0000-000000000001',
  'pa05g-location','PA-05G Delivery Location','PA-05G Address','Asia/Bangkok'
);
insert into atlas_admin.units (unit_id, unit_code, unit_name, dimension_code) values
  ('f5300000-0000-0000-0000-000000000021','pa05g-kg','kilogram','mass'),
  ('f5300000-0000-0000-0000-000000000022','pa05g-box','box','count');
insert into atlas_admin.ingredients (ingredient_id, ingredient_code, ingredient_name) values
  ('f5300000-0000-0000-0000-000000000031','pa05g-rice','PA-05G Rice'),
  ('f5300000-0000-0000-0000-000000000032','pa05g-oil','PA-05G Oil');
insert into atlas_admin.suppliers (supplier_id, supplier_code, supplier_name) values
  ('f5300000-0000-0000-0000-000000000041','pa05g-supplier-a','PA-05G Supplier A'),
  ('f5300000-0000-0000-0000-000000000042','pa05g-supplier-b','PA-05G Supplier B');
insert into atlas_admin.supplier_eligibilities (
  supplier_eligibility_id, supplier_id, ingredient_id, eligibility_status, effective_from
) values
  ('f5300000-0000-0000-0000-000000000051','f5300000-0000-0000-0000-000000000041','f5300000-0000-0000-0000-000000000031','ACTIVE',date '2026-01-01'),
  ('f5300000-0000-0000-0000-000000000052','f5300000-0000-0000-0000-000000000042','f5300000-0000-0000-0000-000000000032','ACTIVE',date '2026-01-01');

create temporary table pa05g_results (
  execution_order integer primary key,
  result_name text unique not null,
  command_name text not null,
  command_id uuid unique not null,
  response_payload jsonb not null
);
grant select, insert on pa05g_results to authenticated;

create temporary table pa05g_ids (
  id_name text not null,
  line_number integer not null default 0,
  id_value uuid not null,
  primary key (id_name, line_number)
);
grant select on pa05g_ids to authenticated;

create temporary table pa05g_read_results (
  read_name text primary key,
  response_payload jsonb not null
);
grant select, insert on pa05g_read_results to authenticated;

create temporary table pa05g_pre_read_counts (
  count_name text primary key,
  row_count bigint not null
);

create function pg_temp.pa05g_request(
  contract text,
  command_id uuid,
  idempotency_key text,
  expected_version bigint,
  payload jsonb
) returns jsonb
language sql immutable set search_path = '' as $$
  select pg_catalog.jsonb_build_object(
    'contract_version', contract,
    'command_id', command_id,
    'correlation_id', 'f5900000-0000-0000-0000-000000000001'::uuid,
    'idempotency_key', idempotency_key,
    'expected_version', expected_version,
    'requested_by_auth_subject', 'f5000000-0000-0000-0000-000000000101'::uuid,
    'requested_at', '2026-07-16T17:00:00+00:00',
    'reason_code', 'PA05G_ACCEPTANCE',
    'reason_note', 'PA-05G command-authored backend acceptance',
    'payload', payload
  )
$$;

set local role authenticated;
select set_config('request.jwt.claim.sub','f5000000-0000-0000-0000-000000000101',true);

insert into pa05g_results values (
  1,'source','record_wholesale_source','f5910000-0000-0000-0000-000000000001',
  atlas_api.record_wholesale_source(pg_temp.pa05g_request(
    'PA-05D.v1','f5910000-0000-0000-0000-000000000001','pa05g-01-source',1,
    pg_catalog.jsonb_build_object(
      'customer_id','f5300000-0000-0000-0000-000000000001',
      'delivery_location_id','f5300000-0000-0000-0000-000000000011',
      'customer_order_reference','PA05G-ORDER-001','service_date','2026-07-17',
      'lines',pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'source_line_number',1,'ingredient_id','f5300000-0000-0000-0000-000000000031',
          'requested_quantity',10,'unit_id','f5300000-0000-0000-0000-000000000021'
        ),
        pg_catalog.jsonb_build_object(
          'source_line_number',2,'ingredient_id','f5300000-0000-0000-0000-000000000032',
          'requested_quantity',3,'unit_id','f5300000-0000-0000-0000-000000000022'
        )
      )
    )
  ))
);

insert into pa05g_results values (
  2,'release','release_wholesale_order','f5910000-0000-0000-0000-000000000002',
  atlas_api.release_wholesale_order(pg_temp.pa05g_request(
    'PA-05D.v1','f5910000-0000-0000-0000-000000000002','pa05g-02-release',1,
    pg_catalog.jsonb_build_object(
      'wholesale_order_id',(select response_payload#>>'{affected_aggregate_ids,wholesale_order_id}' from pa05g_results where result_name='source')
    )
  ))
);

insert into pa05g_results values (
  3,'handoff','release_purchase_handoff','f5910000-0000-0000-0000-000000000003',
  atlas_api.release_purchase_handoff(pg_temp.pa05g_request(
    'PA-05D.v1','f5910000-0000-0000-0000-000000000003','pa05g-03-handoff',1,
    pg_catalog.jsonb_build_object(
      'confirmed_need_batch_id',(select response_payload#>>'{affected_aggregate_ids,confirmed_need_batch_id}' from pa05g_results where result_name='release')
    )
  ))
);

insert into pa05g_results values (
  4,'requirement','release_dispatch_requirement','f5910000-0000-0000-0000-000000000004',
  atlas_api.release_dispatch_requirement(pg_temp.pa05g_request(
    'PA-05D.v1','f5910000-0000-0000-0000-000000000004','pa05g-04-requirement',1,
    pg_catalog.jsonb_build_object(
      'purchase_handoff_revision_id',(select response_payload#>>'{affected_aggregate_ids,purchase_handoff_revision_id}' from pa05g_results where result_name='handoff')
    )
  ))
);
reset role;

insert into pa05g_ids values
  ('wholesale_order',0,(select (response_payload#>>'{affected_aggregate_ids,wholesale_order_id}')::uuid from pa05g_results where result_name='source')),
  ('confirmed_need_batch',0,(select (response_payload#>>'{affected_aggregate_ids,confirmed_need_batch_id}')::uuid from pa05g_results where result_name='release')),
  ('purchase_handoff_revision',0,(select (response_payload#>>'{affected_aggregate_ids,purchase_handoff_revision_id}')::uuid from pa05g_results where result_name='handoff')),
  ('dispatch_requirement',0,(select (response_payload#>>'{affected_aggregate_ids,dispatch_requirement_id}')::uuid from pa05g_results where result_name='requirement')),
  ('dispatch_requirement_revision',0,(select (response_payload#>>'{affected_aggregate_ids,dispatch_requirement_revision_id}')::uuid from pa05g_results where result_name='requirement'));

insert into pa05g_ids
select 'wholesale_order_line_revision', wol.source_line_number, wolr.wholesale_order_line_revision_id
from atlas_planning.wholesale_order_lines wol
join atlas_planning.wholesale_order_line_revisions wolr using (wholesale_order_line_id)
where wol.wholesale_order_id=(select id_value from pa05g_ids where id_name='wholesale_order' and line_number=0)
  and wolr.is_current;
insert into pa05g_ids
select 'dispatch_requirement_line_revision', wol.source_line_number, drlr.dispatch_requirement_line_revision_id
from atlas_planning.dispatch_requirement_line_revisions drlr
join atlas_planning.dispatch_requirement_lines drl using (dispatch_requirement_line_id)
join atlas_planning.purchase_handoff_lines phl using (purchase_handoff_line_id)
join atlas_planning.confirmed_need_lines cnl using (confirmed_need_line_id)
join atlas_planning.wholesale_order_lines wol using (wholesale_order_line_id)
where drlr.dispatch_requirement_revision_id=(select id_value from pa05g_ids where id_name='dispatch_requirement_revision' and line_number=0);

set local role authenticated;
select set_config('request.jwt.claim.sub','f5000000-0000-0000-0000-000000000101',true);
insert into pa05g_results values (
  5,'allocation','allocate_supplier_direct_fulfilment','f5910000-0000-0000-0000-000000000005',
  atlas_api.allocate_supplier_direct_fulfilment(pg_temp.pa05g_request(
    'PA-05E.v1','f5910000-0000-0000-0000-000000000005','pa05g-05-allocation',1,
    pg_catalog.jsonb_build_object(
      'dispatch_requirement_revision_id',(select id_value from pa05g_ids where id_name='dispatch_requirement_revision' and line_number=0),
      'lines',pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'dispatch_requirement_line_revision_id',(select id_value from pa05g_ids where id_name='dispatch_requirement_line_revision' and line_number=1),
          'supplier_id','f5300000-0000-0000-0000-000000000041','allocated_quantity',10,
          'unit_id','f5300000-0000-0000-0000-000000000021'
        ),
        pg_catalog.jsonb_build_object(
          'dispatch_requirement_line_revision_id',(select id_value from pa05g_ids where id_name='dispatch_requirement_line_revision' and line_number=2),
          'supplier_id','f5300000-0000-0000-0000-000000000042','allocated_quantity',3,
          'unit_id','f5300000-0000-0000-0000-000000000022'
        )
      )
    )
  ))
);

insert into pa05g_results values (
  6,'po-a','release_supplier_purchase_order','f5910000-0000-0000-0000-000000000006',
  atlas_api.release_supplier_purchase_order(pg_temp.pa05g_request(
    'PA-05E.v1','f5910000-0000-0000-0000-000000000006','pa05g-06-po-a',1,
    pg_catalog.jsonb_build_object(
      'fulfilment_allocation_revision_id',(select response_payload#>>'{affected_aggregate_ids,fulfilment_allocation_revision_id}' from pa05g_results where result_name='allocation'),
      'supplier_id','f5300000-0000-0000-0000-000000000041','document_number','PA05G-PO-A'
    )
  ))
);

insert into pa05g_results values (
  7,'po-b','release_supplier_purchase_order','f5910000-0000-0000-0000-000000000007',
  atlas_api.release_supplier_purchase_order(pg_temp.pa05g_request(
    'PA-05E.v1','f5910000-0000-0000-0000-000000000007','pa05g-07-po-b',1,
    pg_catalog.jsonb_build_object(
      'fulfilment_allocation_revision_id',(select response_payload#>>'{affected_aggregate_ids,fulfilment_allocation_revision_id}' from pa05g_results where result_name='allocation'),
      'supplier_id','f5300000-0000-0000-0000-000000000042','document_number','PA05G-PO-B'
    )
  ))
);
reset role;

insert into pa05g_ids values
  ('fulfilment_allocation',0,(select (response_payload#>>'{affected_aggregate_ids,fulfilment_allocation_id}')::uuid from pa05g_results where result_name='allocation')),
  ('fulfilment_allocation_revision',0,(select (response_payload#>>'{affected_aggregate_ids,fulfilment_allocation_revision_id}')::uuid from pa05g_results where result_name='allocation')),
  ('purchase_order',1,(select (response_payload#>>'{affected_aggregate_ids,purchase_order_id}')::uuid from pa05g_results where result_name='po-a')),
  ('purchase_order',2,(select (response_payload#>>'{affected_aggregate_ids,purchase_order_id}')::uuid from pa05g_results where result_name='po-b'));

insert into pa05g_ids
select 'fulfilment_allocation_line_revision', wol.source_line_number, falr.fulfilment_allocation_line_revision_id
from atlas_procurement.fulfilment_allocation_line_revisions falr
join atlas_planning.dispatch_requirement_line_revisions drlr using (dispatch_requirement_line_revision_id)
join atlas_planning.dispatch_requirement_lines drl using (dispatch_requirement_line_id)
join atlas_planning.purchase_handoff_lines phl using (purchase_handoff_line_id)
join atlas_planning.confirmed_need_lines cnl using (confirmed_need_line_id)
join atlas_planning.wholesale_order_lines wol using (wholesale_order_line_id)
where falr.fulfilment_allocation_revision_id=(select id_value from pa05g_ids where id_name='fulfilment_allocation_revision' and line_number=0);

insert into pa05g_ids
select 'purchase_order_line_revision',
       case when po.supplier_id='f5300000-0000-0000-0000-000000000041' then 1 else 2 end,
       polr.purchase_order_line_revision_id
from atlas_procurement.purchase_orders po
join atlas_procurement.purchase_order_revisions por using (purchase_order_id)
join atlas_procurement.purchase_order_line_revisions polr using (purchase_order_revision_id)
where po.purchase_order_id in (select id_value from pa05g_ids where id_name='purchase_order') and por.is_current;

set local role authenticated;
select set_config('request.jwt.claim.sub','f5000000-0000-0000-0000-000000000101',true);
insert into pa05g_results values (
  8,'evidence-a','record_supplier_receiving_evidence','f5910000-0000-0000-0000-000000000008',
  atlas_api.record_supplier_receiving_evidence(pg_temp.pa05g_request(
    'PA-05B.v1','f5910000-0000-0000-0000-000000000008','pa05g-08-evidence-a',1,
    pg_catalog.jsonb_build_object(
      'purchase_order_line_revision_id',(select id_value from pa05g_ids where id_name='purchase_order_line_revision' and line_number=1),
      'supplier_id','f5300000-0000-0000-0000-000000000041',
      'ingredient_id','f5300000-0000-0000-0000-000000000031',
      'unit_id','f5300000-0000-0000-0000-000000000021','evidence_quantity',10,
      'evidence_reference','PA05G-EVIDENCE-A','occurred_at','2026-07-16T17:10:00+00:00'
    )
  ))
);

insert into pa05g_results values (
  9,'evidence-b','record_supplier_receiving_evidence','f5910000-0000-0000-0000-000000000009',
  atlas_api.record_supplier_receiving_evidence(pg_temp.pa05g_request(
    'PA-05B.v1','f5910000-0000-0000-0000-000000000009','pa05g-09-evidence-b',1,
    pg_catalog.jsonb_build_object(
      'purchase_order_line_revision_id',(select id_value from pa05g_ids where id_name='purchase_order_line_revision' and line_number=2),
      'supplier_id','f5300000-0000-0000-0000-000000000042',
      'ingredient_id','f5300000-0000-0000-0000-000000000032',
      'unit_id','f5300000-0000-0000-0000-000000000022','evidence_quantity',3,
      'evidence_reference','PA05G-EVIDENCE-B','occurred_at','2026-07-16T17:11:00+00:00'
    )
  ))
);

insert into pa05g_results values (
  10,'application-a','apply_supplier_evidence_to_allocation','f5910000-0000-0000-0000-00000000000a',
  atlas_api.apply_supplier_evidence_to_allocation(pg_temp.pa05g_request(
    'PA-05B.v1','f5910000-0000-0000-0000-00000000000a','pa05g-10-application-a',1,
    pg_catalog.jsonb_build_object(
      'supplier_receiving_evidence_id',(select response_payload#>>'{affected_aggregate_ids,supplier_receiving_evidence_id}' from pa05g_results where result_name='evidence-a'),
      'fulfilment_allocation_line_revision_id',(select id_value from pa05g_ids where id_name='fulfilment_allocation_line_revision' and line_number=1),
      'unit_id','f5300000-0000-0000-0000-000000000021','applied_quantity',10,
      'occurred_at','2026-07-16T17:15:00+00:00'
    )
  ))
);

insert into pa05g_results values (
  11,'application-b','apply_supplier_evidence_to_allocation','f5910000-0000-0000-0000-00000000000b',
  atlas_api.apply_supplier_evidence_to_allocation(pg_temp.pa05g_request(
    'PA-05B.v1','f5910000-0000-0000-0000-00000000000b','pa05g-11-application-b',1,
    pg_catalog.jsonb_build_object(
      'supplier_receiving_evidence_id',(select response_payload#>>'{affected_aggregate_ids,supplier_receiving_evidence_id}' from pa05g_results where result_name='evidence-b'),
      'fulfilment_allocation_line_revision_id',(select id_value from pa05g_ids where id_name='fulfilment_allocation_line_revision' and line_number=2),
      'unit_id','f5300000-0000-0000-0000-000000000022','applied_quantity',3,
      'occurred_at','2026-07-16T17:16:00+00:00'
    )
  ))
);

insert into pa05g_results values (
  12,'plan','create_dispatch_plan','f5910000-0000-0000-0000-00000000000c',
  atlas_api.create_dispatch_plan(pg_temp.pa05g_request(
    'PA-05F.v1','f5910000-0000-0000-0000-00000000000c','pa05g-12-plan',1,
    pg_catalog.jsonb_build_object(
      'plan_reference','PA05G-PLAN-001','dispatch_wave','MORNING',
      'requirements',pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'dispatch_requirement_revision_id',(select id_value from pa05g_ids where id_name='dispatch_requirement_revision' and line_number=0),
        'fulfilment_allocation_revision_id',(select id_value from pa05g_ids where id_name='fulfilment_allocation_revision' and line_number=0),
        'expected_dispatch_requirement_version',1,'expected_fulfilment_allocation_version',1
      ))
    )
  ))
);

insert into pa05g_results values (
  13,'trip','create_or_assign_dispatch_trip','f5910000-0000-0000-0000-00000000000d',
  atlas_api.create_or_assign_dispatch_trip(pg_temp.pa05g_request(
    'PA-05F.v1','f5910000-0000-0000-0000-00000000000d','pa05g-13-trip',1,
    pg_catalog.jsonb_build_object(
      'dispatch_plan_id',(select response_payload#>>'{affected_aggregate_ids,dispatch_plan_id}' from pa05g_results where result_name='plan'),
      'trip_reference','PA05G-TRIP-001','driver_actor_id','f5000000-0000-0000-0000-000000000002',
      'vehicle_reference','PA05G-TRUCK-001','planned_departure_at','2026-07-16T17:30:00+00:00',
      'stops',pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'dispatch_plan_requirement_id',(select response_payload#>>'{affected_aggregate_ids,dispatch_plan_requirement_ids,0}' from pa05g_results where result_name='plan'),
        'stop_sequence',1
      ))
    )
  ))
);
reset role;

insert into pa05g_ids values
  ('evidence_application',1,(select (response_payload#>>'{affected_aggregate_ids,evidence_application_id}')::uuid from pa05g_results where result_name='application-a')),
  ('evidence_application',2,(select (response_payload#>>'{affected_aggregate_ids,evidence_application_id}')::uuid from pa05g_results where result_name='application-b')),
  ('dispatch_plan',0,(select (response_payload#>>'{affected_aggregate_ids,dispatch_plan_id}')::uuid from pa05g_results where result_name='plan')),
  ('dispatch_plan_requirement',0,(select (response_payload#>>'{affected_aggregate_ids,dispatch_plan_requirement_ids,0}')::uuid from pa05g_results where result_name='plan')),
  ('dispatch_trip',0,(select (response_payload#>>'{affected_aggregate_ids,dispatch_trip_id}')::uuid from pa05g_results where result_name='trip'));
insert into pa05g_ids
select 'dispatch_stop',0,dispatch_stop_id from atlas_dispatch.dispatch_stops
where dispatch_trip_id=(select id_value from pa05g_ids where id_name='dispatch_trip' and line_number=0);

set local role authenticated;
select set_config('request.jwt.claim.sub','f5000000-0000-0000-0000-000000000101',true);
insert into pa05g_results values (
  14,'load','confirm_dispatch_load','f5910000-0000-0000-0000-00000000000e',
  atlas_api.confirm_dispatch_load(pg_temp.pa05g_request(
    'PA-05B-H2.v1','f5910000-0000-0000-0000-00000000000e','pa05g-14-load',1,
    pg_catalog.jsonb_build_object(
      'dispatch_trip_id',(select id_value from pa05g_ids where id_name='dispatch_trip' and line_number=0),
      'dispatch_stop_id',(select id_value from pa05g_ids where id_name='dispatch_stop' and line_number=0),
      'dispatch_requirement_revision_id',(select id_value from pa05g_ids where id_name='dispatch_requirement_revision' and line_number=0),
      'fulfilment_allocation_revision_id',(select id_value from pa05g_ids where id_name='fulfilment_allocation_revision' and line_number=0),
      'loaded_at','2026-07-16T17:45:00+00:00',
      'lines',pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'dispatch_requirement_line_revision_id',(select id_value from pa05g_ids where id_name='dispatch_requirement_line_revision' and line_number=1),
          'fulfilment_allocation_line_revision_id',(select id_value from pa05g_ids where id_name='fulfilment_allocation_line_revision' and line_number=1),
          'loaded_quantity',10,'unit_id','f5300000-0000-0000-0000-000000000021',
          'evidence_applications',pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
            'evidence_application_id',(select id_value from pa05g_ids where id_name='evidence_application' and line_number=1),
            'applied_to_load_quantity',10,'unit_id','f5300000-0000-0000-0000-000000000021'
          ))
        ),
        pg_catalog.jsonb_build_object(
          'dispatch_requirement_line_revision_id',(select id_value from pa05g_ids where id_name='dispatch_requirement_line_revision' and line_number=2),
          'fulfilment_allocation_line_revision_id',(select id_value from pa05g_ids where id_name='fulfilment_allocation_line_revision' and line_number=2),
          'loaded_quantity',3,'unit_id','f5300000-0000-0000-0000-000000000022',
          'evidence_applications',pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
            'evidence_application_id',(select id_value from pa05g_ids where id_name='evidence_application' and line_number=2),
            'applied_to_load_quantity',3,'unit_id','f5300000-0000-0000-0000-000000000022'
          ))
        )
      )
    )
  ))
);

insert into pa05g_results values (
  15,'departure','record_dispatch_departure','f5910000-0000-0000-0000-00000000000f',
  atlas_api.record_dispatch_departure(pg_temp.pa05g_request(
    'PA-05B-H2.v1','f5910000-0000-0000-0000-00000000000f','pa05g-15-departure',2,
    pg_catalog.jsonb_build_object(
      'dispatch_trip_id',(select id_value from pa05g_ids where id_name='dispatch_trip' and line_number=0),
      'departed_at','2026-07-16T18:00:00+00:00'
    )
  ))
);
reset role;

insert into pa05g_ids
select 'dispatch_load_line', wol.source_line_number, dll.dispatch_load_line_id
from atlas_dispatch.dispatch_loads dl
join atlas_dispatch.dispatch_load_lines dll using (dispatch_load_id)
join atlas_planning.dispatch_requirement_line_revisions drlr using (dispatch_requirement_line_revision_id)
join atlas_planning.dispatch_requirement_lines drl using (dispatch_requirement_line_id)
join atlas_planning.purchase_handoff_lines phl using (purchase_handoff_line_id)
join atlas_planning.confirmed_need_lines cnl using (confirmed_need_line_id)
join atlas_planning.wholesale_order_lines wol using (wholesale_order_line_id)
where dl.dispatch_trip_id=(select id_value from pa05g_ids where id_name='dispatch_trip' and line_number=0);

set local role authenticated;
select set_config('request.jwt.claim.sub','f5000000-0000-0000-0000-000000000101',true);
insert into pa05g_results values (
  16,'delivery','confirm_successful_delivery','f5910000-0000-0000-0000-000000000010',
  atlas_api.confirm_successful_delivery(pg_temp.pa05g_request(
    'PA-05B-H2.v1','f5910000-0000-0000-0000-000000000010','pa05g-16-delivery',3,
    pg_catalog.jsonb_build_object(
      'dispatch_trip_id',(select id_value from pa05g_ids where id_name='dispatch_trip' and line_number=0),
      'dispatch_stop_id',(select id_value from pa05g_ids where id_name='dispatch_stop' and line_number=0),
      'lines',pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'dispatch_load_line_id',(select id_value from pa05g_ids where id_name='dispatch_load_line' and line_number=1),
          'unit_id','f5300000-0000-0000-0000-000000000021',
          'delivered_quantity',10,'returned_quantity',0,'exception_quantity',0
        ),
        pg_catalog.jsonb_build_object(
          'dispatch_load_line_id',(select id_value from pa05g_ids where id_name='dispatch_load_line' and line_number=2),
          'unit_id','f5300000-0000-0000-0000-000000000022',
          'delivered_quantity',3,'returned_quantity',0,'exception_quantity',0
        )
      ),
      'confirmed_at','2026-07-16T18:15:00+00:00',
      'received_by_reference','PA05G-RECEIVER','notes','Exact successful two-line delivery'
    )
  ))
);

insert into pa05g_results values (
  17,'closure','close_successful_trip','f5910000-0000-0000-0000-000000000011',
  atlas_api.close_successful_trip(pg_temp.pa05g_request(
    'PA-05B-H3.v1','f5910000-0000-0000-0000-000000000011','pa05g-17-closure',4,
    pg_catalog.jsonb_build_object(
      'dispatch_trip_id',(select id_value from pa05g_ids where id_name='dispatch_trip' and line_number=0),
      'completed_at','2026-07-16T18:30:00+00:00'
    )
  ))
);
reset role;

-- Every first execution has the complete safe success shape, one exact event,
-- and one exact audit event. The response event IDs must be the authoritative
-- rows for that command rather than merely non-null UUIDs.
select is((select count(*)::integer from pa05g_results),17,'the scenario executes exactly 17 first commands');
select ok(
  not exists (
    select 1 from pa05g_results
    where coalesce((response_payload->>'success')::boolean,false) is not true
  ),
  'all 17 first command executions succeed'
);
select ok(
  not exists (
    select 1 from pa05g_results
    where response_payload->>'command_id' <> command_id::text
       or response_payload->>'correlation_id' <> 'f5900000-0000-0000-0000-000000000001'
       or response_payload->>'idempotency_status' <> 'COMPLETED'
  ),
  'all command responses preserve command identity, shared correlation, and completed idempotency'
);
select ok(
  not exists (
    select 1 from pa05g_results
    where jsonb_typeof(response_payload->'affected_aggregate_ids') <> 'object'
       or response_payload->'affected_aggregate_ids' = '{}'::jsonb
       or jsonb_typeof(response_payload->'new_versions') <> 'object'
       or response_payload->'new_versions' = '{}'::jsonb
  ),
  'all command responses return required affected IDs and new versions'
);
select ok(
  not exists (
    select 1 from pa05g_results
    where jsonb_array_length(response_payload->'emitted_event_ids') <> 1
       or jsonb_array_length(response_payload->'audit_event_ids') <> 1
       or not exists (
         select 1 from atlas_audit.domain_events de
         where de.command_id=pa05g_results.command_id
           and de.domain_event_id=(response_payload#>>'{emitted_event_ids,0}')::uuid
       )
       or not exists (
         select 1 from atlas_audit.audit_events ae
         where ae.command_id=pa05g_results.command_id
           and ae.audit_event_id=(response_payload#>>'{audit_event_ids,0}')::uuid
       )
  ),
  'all command responses contain exactly their authoritative event and audit IDs'
);
select ok(
  not exists (
    select 1 from pa05g_results
    where coalesce(response_payload->>'safe_operator_message','')=''
       or jsonb_typeof(response_payload->'warnings') <> 'array'
       or jsonb_typeof(response_payload->'blockers') <> 'array'
       or response_payload ? 'error_code'
  ),
  'all command responses contain safe operator messaging and array warnings/blockers with no error code'
);
select ok(
  not exists (
    select 1 from pa05g_results
    where response_payload::text ~* '(request_hash|response_payload|sqlstate|sqlerrm|internal_query|stack.trace|credential|service.role|jwt|policy|raw.stored)'
  ),
  'no command response exposes SQL, role, policy, JWT, credential, stack, or raw stored-response internals'
);

-- Planning authoritative reconciliation.
select ok((
  select order_status='RELEASED' and version=2 and customer_id='f5300000-0000-0000-0000-000000000001'
    and delivery_location_id='f5300000-0000-0000-0000-000000000011' and service_date=date '2026-07-17'
  from atlas_planning.wholesale_orders
  where wholesale_order_id=(select id_value from pa05g_ids where id_name='wholesale_order' and line_number=0)
),'the single Wholesale Order is released at exact version 2 with its customer, location, and service date');
select is((select count(*)::integer from atlas_planning.wholesale_order_lines),2,'Planning contains exactly two stable Wholesale Order lines');
select is((select count(*)::integer from atlas_planning.wholesale_order_line_revisions where is_current and revision_status='RELEASED'),2,'both current Wholesale Order line revisions are released');
select ok(not exists(
  select 1 from atlas_planning.wholesale_order_lines wol
  join atlas_planning.wholesale_order_line_revisions wolr using (wholesale_order_line_id)
  where (wol.source_line_number=1 and (wolr.ingredient_id<>'f5300000-0000-0000-0000-000000000031' or wolr.requested_quantity<>10 or wolr.unit_id<>'f5300000-0000-0000-0000-000000000021'))
     or (wol.source_line_number=2 and (wolr.ingredient_id<>'f5300000-0000-0000-0000-000000000032' or wolr.requested_quantity<>3 or wolr.unit_id<>'f5300000-0000-0000-0000-000000000022'))
),'Wholesale Order line ingredient, quantity, and unit values are exact');
select is((select count(*)::integer from atlas_planning.confirmed_need_batches where batch_status='RELEASED_FOR_PURCHASE_HANDOFF'),1,'one released Confirmed Need exists');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions where is_current and revision_status='RELEASED'),2,'Confirmed Need contains exactly two current released lines');
select is((select count(*)::integer from atlas_planning.confirmed_need_approval_snapshots),1,'one exact Confirmed Need approval snapshot exists');
select is((select count(*)::integer from atlas_planning.confirmed_need_snapshot_lines),2,'the approval snapshot contains exactly two lines');
select is((select count(*)::integer from atlas_planning.purchase_handoff_batches where handoff_status='RELEASED_TO_PROCUREMENT'),1,'one released Purchase Handoff exists');
select is((select count(*)::integer from atlas_planning.purchase_handoff_revisions where is_current and revision_status='RELEASED_TO_PROCUREMENT'),1,'one current released Handoff revision exists');
select is((select count(*)::integer from atlas_planning.purchase_handoff_line_revisions),2,'the Handoff contains exactly two lines');
select is((select count(*)::integer from atlas_planning.purchase_demand_references),2,'the Handoff contains one immutable source reference per line');
select is((select count(*)::integer from atlas_planning.dispatch_requirements where requirement_status='RELEASED'),1,'one released Dispatch Requirement exists');
select is((select count(*)::integer from atlas_planning.dispatch_requirement_revisions where is_current and revision_status='RELEASED'),1,'one current released Requirement revision exists');
select is((select count(*)::integer from atlas_planning.dispatch_requirement_line_revisions),2,'the Dispatch Requirement contains exactly two lines');
select ok(not exists(
  select 1
  from atlas_planning.wholesale_orders wo
  join atlas_planning.wholesale_order_lines wol using (wholesale_order_id)
  join atlas_planning.wholesale_order_line_revisions wolr using (wholesale_order_line_id)
  join atlas_planning.confirmed_need_lines cnl using (wholesale_order_line_id)
  join atlas_planning.confirmed_need_line_revisions cnlr using (confirmed_need_line_id)
  join atlas_planning.purchase_handoff_lines phl using (confirmed_need_line_id)
  join atlas_planning.purchase_handoff_line_revisions phlr using (purchase_handoff_line_id)
  join atlas_planning.purchase_demand_references pdr using (purchase_handoff_line_revision_id)
  join atlas_planning.dispatch_requirement_lines drl using (purchase_handoff_line_id)
  join atlas_planning.dispatch_requirement_line_revisions drlr using (dispatch_requirement_line_id)
  join atlas_planning.dispatch_requirements dr using (dispatch_requirement_id)
  where wo.wholesale_order_id=(select id_value from pa05g_ids where id_name='wholesale_order' and line_number=0)
    and (cnlr.wholesale_order_line_revision_id<>wolr.wholesale_order_line_revision_id
      or pdr.wholesale_order_line_revision_id<>wolr.wholesale_order_line_revision_id
      or cnlr.ingredient_id<>wolr.ingredient_id or phlr.ingredient_id<>wolr.ingredient_id or drlr.ingredient_id<>wolr.ingredient_id
      or cnlr.confirmed_quantity<>wolr.requested_quantity or phlr.handoff_quantity<>wolr.requested_quantity or drlr.required_quantity<>wolr.requested_quantity
      or cnlr.unit_id<>wolr.unit_id or phlr.unit_id<>wolr.unit_id or drlr.unit_id<>wolr.unit_id
      or phlr.service_date<>wo.service_date or dr.service_date<>wo.service_date
      or phlr.delivery_location_id<>wo.delivery_location_id or dr.delivery_location_id<>wo.delivery_location_id
      or dr.customer_id<>wo.customer_id)
),'customer, destination, date, ingredient, quantity, unit, revision, and snapshot lineage reconcile through Planning');

-- Procurement and Evidence authoritative reconciliation.
select ok((select allocation_status='READY_FOR_DISPATCH' and version=1 from atlas_procurement.fulfilment_allocations where fulfilment_allocation_id=(select id_value from pa05g_ids where id_name='fulfilment_allocation' and line_number=0)),'the allocation root is READY_FOR_DISPATCH at version 1');
select is((select count(*)::integer from atlas_procurement.fulfilment_allocation_revisions where is_current and revision_status='READY_FOR_DISPATCH'),1,'one current READY_FOR_DISPATCH allocation revision exists');
select is((select count(*)::integer from atlas_procurement.fulfilment_allocation_lines),2,'the allocation has exactly two stable lines');
select is((select count(*)::integer from atlas_procurement.fulfilment_allocation_line_revisions),2,'the allocation has exactly two line revisions');
select is((select count(distinct dispatch_requirement_line_revision_id)::integer from atlas_procurement.fulfilment_allocation_line_revisions),2,'each Requirement line is allocated exactly once');
select is((select count(distinct supplier_id)::integer from atlas_procurement.fulfilment_allocation_line_revisions),2,'Supplier A and Supplier B own different allocation lines');
select ok(not exists(
  select 1 from atlas_procurement.fulfilment_allocation_line_revisions falr
  join atlas_planning.dispatch_requirement_line_revisions drlr using (dispatch_requirement_line_revision_id)
  where falr.allocated_quantity<>drlr.required_quantity or falr.unit_id<>drlr.unit_id
),'allocated quantities and units exactly equal Planning');
select is((select count(*)::integer from atlas_procurement.purchase_orders where purchase_order_status='RELEASED_TO_SUPPLIER'),2,'exactly two supplier POs are released');
select ok(not exists(
  select 1 from atlas_procurement.purchase_orders po
  where (po.document_number='PA05G-PO-A' and po.supplier_id<>'f5300000-0000-0000-0000-000000000041')
     or (po.document_number='PA05G-PO-B' and po.supplier_id<>'f5300000-0000-0000-0000-000000000042')
),'each PO belongs to its exact supplier');
select is((select count(*)::integer from atlas_procurement.purchase_order_line_revisions),2,'each supplier PO contains every and only its one allocation line');
select ok(not exists(
  select 1 from atlas_procurement.purchase_orders po
  join atlas_procurement.purchase_order_revisions por using (purchase_order_id)
  join atlas_procurement.purchase_order_line_revisions polr using (purchase_order_revision_id)
  join atlas_procurement.purchase_order_lines pol using (purchase_order_line_id)
  join atlas_procurement.fulfilment_allocation_line_revisions falr using (fulfilment_allocation_line_revision_id)
  join atlas_planning.dispatch_requirement_line_revisions drlr using (dispatch_requirement_line_revision_id)
  join atlas_planning.dispatch_requirement_revisions drr using (dispatch_requirement_revision_id)
  join atlas_planning.dispatch_requirements dr using (dispatch_requirement_id)
  where po.supplier_id<>falr.supplier_id or polr.ingredient_id<>drlr.ingredient_id
     or polr.ordered_quantity<>drlr.required_quantity or polr.unit_id<>drlr.unit_id
     or por.delivery_location_id<>dr.delivery_location_id or por.service_date<>dr.service_date
),'PO line ingredient, quantity, unit, supplier, destination, and service date preserve upstream lineage');
select is((select count(*)::integer from atlas_evidence.supplier_receiving_evidence where evidence_status='VALID'),2,'exactly two current VALID supplier Evidence roots exist');
select is((select count(*)::integer from atlas_evidence.evidence_applications where application_status='VALID'),2,'exactly two current VALID Evidence Applications exist');
select ok(not exists(
  select 1 from atlas_evidence.supplier_receiving_evidence sre
  join atlas_procurement.purchase_order_line_revisions polr using (purchase_order_line_revision_id)
  join atlas_procurement.purchase_order_revisions por using (purchase_order_revision_id)
  join atlas_procurement.purchase_orders po using (purchase_order_id)
  where sre.supplier_id<>po.supplier_id or sre.ingredient_id<>polr.ingredient_id
     or sre.evidence_quantity<>polr.ordered_quantity or sre.unit_id<>polr.unit_id
),'each Evidence root points to its exact released PO line and supplier/ingredient/quantity/unit');
select ok(not exists(
  select 1 from atlas_evidence.evidence_applications ea
  join atlas_evidence.supplier_receiving_evidence sre using (supplier_receiving_evidence_id)
  join atlas_procurement.fulfilment_allocation_line_revisions falr using (fulfilment_allocation_line_revision_id)
  where ea.applied_quantity<>falr.allocated_quantity or ea.unit_id<>falr.unit_id
     or sre.supplier_id<>falr.supplier_id or sre.ingredient_id<>(
       select drlr.ingredient_id from atlas_planning.dispatch_requirement_line_revisions drlr
       where drlr.dispatch_requirement_line_revision_id=falr.dispatch_requirement_line_revision_id
     )
),'each Evidence Application exactly covers its own allocation line');
select ok(not exists(select 1 from atlas_evidence.supplier_receiving_evidence where evidence_status in ('VOIDED','SUPERSEDED')) and not exists(select 1 from atlas_evidence.evidence_applications where application_status in ('VOIDED','SUPERSEDED')),'no Evidence or application is voided or superseded');
select ok(not exists(
  select 1 from atlas_evidence.supplier_receiving_evidence sre
  join lateral (select coalesce(sum(ea.applied_quantity),0) applied from atlas_evidence.evidence_applications ea where ea.supplier_receiving_evidence_id=sre.supplier_receiving_evidence_id and ea.application_status='VALID') x on true
  where x.applied>sre.evidence_quantity
) and not exists(
  select 1 from atlas_procurement.fulfilment_allocation_line_revisions falr
  join lateral (select coalesce(sum(ea.applied_quantity),0) applied from atlas_evidence.evidence_applications ea where ea.fulfilment_allocation_line_revision_id=falr.fulfilment_allocation_line_revision_id and ea.application_status='VALID') x on true
  where x.applied>falr.allocated_quantity
),'no Evidence is over-applied and no allocation line is over-covered');

-- Dispatch authoritative reconciliation.
select ok((select plan_status='PLANNED' and version=2 from atlas_dispatch.dispatch_plans where dispatch_plan_id=(select id_value from pa05g_ids where id_name='dispatch_plan' and line_number=0)),'the PA-05F Dispatch Plan remains PLANNED and assignment increments it exactly once to version 2');
select is((select count(*)::integer from atlas_dispatch.dispatch_plan_requirements),1,'one exact Plan Requirement membership exists');
select ok((select trip_status='DELIVERED' and driver_actor_id='f5000000-0000-0000-0000-000000000002' and vehicle_reference='PA05G-TRUCK-001' and departed_at=timestamptz '2026-07-16 18:00:00+00' and completed_at=timestamptz '2026-07-16 18:30:00+00' and version=5 from atlas_dispatch.dispatch_trips where dispatch_trip_id=(select id_value from pa05g_ids where id_name='dispatch_trip' and line_number=0)),'the assigned Trip preserves driver/vehicle, exact departure/completion, DELIVERED, and final version 5');
select is((select count(*)::integer from atlas_dispatch.dispatch_stops),1,'one Planning-derived Stop exists');
select ok((select stop_status='DELIVERED' and customer_id='f5300000-0000-0000-0000-000000000001' and delivery_location_id='f5300000-0000-0000-0000-000000000011' and version=4 from atlas_dispatch.dispatch_stops),'the Stop matches Planning and is DELIVERED at version 4');
select is((select count(*)::integer from atlas_dispatch.dispatch_loads where load_status='CONFIRMED'),1,'one CONFIRMED Load exists for the Requirement/allocation pair');
select is((select count(*)::integer from atlas_dispatch.dispatch_load_lines where line_status='CONFIRMED'),2,'the Load contains exactly two current confirmed lines');
select is((select count(*)::integer from atlas_dispatch.dispatch_load_line_applications where application_status='VALID'),2,'the Load contains exactly two valid Evidence bridges');
select ok(not exists(
  select 1 from atlas_dispatch.dispatch_load_line_applications dlla
  join atlas_dispatch.dispatch_load_lines dll using (dispatch_load_line_id)
  join atlas_evidence.evidence_applications ea using (evidence_application_id)
  where dlla.applied_to_load_quantity<>dll.loaded_quantity or dlla.applied_to_load_quantity<>ea.applied_quantity or dlla.unit_id<>dll.unit_id or dlla.unit_id<>ea.unit_id or dll.fulfilment_allocation_line_revision_id<>ea.fulfilment_allocation_line_revision_id
),'each Load bridge consumes its exact Evidence Application with no partial or cross-wired Evidence');
select is((select count(*)::integer from atlas_dispatch.delivery_confirmations where confirmation_status='VALID' and delivery_outcome='DELIVERED'),1,'one VALID successful Delivery Confirmation exists');
select is((select count(*)::integer from atlas_dispatch.delivery_confirmation_lines),2,'the Delivery Confirmation contains exactly two lines');
select ok(not exists(
  select 1 from atlas_dispatch.delivery_confirmation_lines dcl
  join atlas_dispatch.dispatch_load_lines dll using (dispatch_load_line_id)
  where dcl.delivered_quantity<>dll.loaded_quantity or dcl.returned_quantity<>0 or dcl.exception_quantity<>0 or dcl.unit_id<>dll.unit_id
),'each delivered quantity exactly equals its Load line and return/exception quantities are zero');
select ok(
  not exists(select 1 from atlas_dispatch.dispatch_loads where load_status<>'CONFIRMED')
  and not exists(select 1 from atlas_dispatch.dispatch_load_lines where line_status<>'CONFIRMED')
  and not exists(select 1 from atlas_dispatch.dispatch_load_line_applications where application_status<>'VALID')
  and not exists(select 1 from atlas_dispatch.delivery_confirmations where confirmation_status<>'VALID' or delivery_outcome<>'DELIVERED')
  and not exists(select 1 from atlas_dispatch.dispatch_stops where stop_status<>'DELIVERED')
  and not exists(select 1 from atlas_dispatch.dispatch_trips where trip_status<>'DELIVERED' or completed_at is null),
  'no return, exception, void, superseding, extra load, extra confirmation, unresolved Stop, or unresolved Trip fact exists'
);

-- Receipt, event, and audit identity under the shared correlation.
select is((select count(*)::integer from atlas_core.command_receipts where correlation_id='f5900000-0000-0000-0000-000000000001'),17,'the shared correlation has exactly 17 command receipts');
select is((select count(*)::integer from atlas_core.command_receipts where correlation_id='f5900000-0000-0000-0000-000000000001' and outcome='COMPLETED'),17,'all 17 receipts are COMPLETED');
select is((select count(*)::integer from atlas_core.command_receipts where correlation_id='f5900000-0000-0000-0000-000000000001' and outcome<>'COMPLETED'),0,'no shared-correlation receipt is failed or in progress');
select is((select count(*)::integer from atlas_audit.domain_events where correlation_id='f5900000-0000-0000-0000-000000000001'),17,'the shared correlation has exactly 17 domain events');
select is((select count(*)::integer from atlas_audit.audit_events where correlation_id='f5900000-0000-0000-0000-000000000001'),17,'the shared correlation has exactly 17 audit events');
select is((select count(*)::integer from atlas_audit.domain_events where correlation_id='f5900000-0000-0000-0000-000000000001' and event_type='SuccessfulDispatchTripClosed'),1,'exactly one SuccessfulDispatchTripClosed domain event exists');
select is((select count(*)::integer from atlas_audit.audit_events where correlation_id='f5900000-0000-0000-0000-000000000001' and event_type='SuccessfulDispatchTripClosed'),1,'exactly one matching closure audit event exists');
select ok(not exists(
  select 1 from atlas_core.command_receipts cr
  left join atlas_audit.domain_events de using (command_receipt_id)
  left join atlas_audit.audit_events ae using (command_receipt_id)
  where cr.correlation_id='f5900000-0000-0000-0000-000000000001'
    and (de.command_id<>cr.command_id or ae.command_id<>cr.command_id or de.actor_id<>cr.actor_id or ae.actor_id<>cr.actor_id or de.correlation_id<>cr.correlation_id or ae.correlation_id<>cr.correlation_id)
),'command, actor, receipt, and correlation identities reconcile for every event/audit tuple');
select is((select count(distinct command_id)::integer from atlas_core.command_receipts where correlation_id='f5900000-0000-0000-0000-000000000001'),17,'no duplicate command receipt exists');

-- Record exact authoritative counts before the four read function types.
insert into pa05g_pre_read_counts values
  ('command_receipts',(select count(*) from atlas_core.command_receipts)),
  ('domain_events',(select count(*) from atlas_audit.domain_events)),
  ('audit_events',(select count(*) from atlas_audit.audit_events)),
  ('planning',(
    select (select count(*) from atlas_planning.wholesale_orders)+(select count(*) from atlas_planning.wholesale_order_lines)+(select count(*) from atlas_planning.wholesale_order_line_revisions)
      +(select count(*) from atlas_planning.confirmed_need_batches)+(select count(*) from atlas_planning.confirmed_need_lines)+(select count(*) from atlas_planning.confirmed_need_line_revisions)
      +(select count(*) from atlas_planning.confirmed_need_approval_snapshots)+(select count(*) from atlas_planning.confirmed_need_snapshot_lines)
      +(select count(*) from atlas_planning.purchase_handoff_batches)+(select count(*) from atlas_planning.purchase_handoff_revisions)+(select count(*) from atlas_planning.purchase_handoff_lines)
      +(select count(*) from atlas_planning.purchase_handoff_line_revisions)+(select count(*) from atlas_planning.purchase_demand_references)
      +(select count(*) from atlas_planning.dispatch_requirements)+(select count(*) from atlas_planning.dispatch_requirement_revisions)+(select count(*) from atlas_planning.dispatch_requirement_lines)+(select count(*) from atlas_planning.dispatch_requirement_line_revisions)
  )),
  ('procurement',(
    select (select count(*) from atlas_procurement.fulfilment_allocations)+(select count(*) from atlas_procurement.fulfilment_allocation_revisions)
      +(select count(*) from atlas_procurement.fulfilment_allocation_lines)+(select count(*) from atlas_procurement.fulfilment_allocation_line_revisions)
      +(select count(*) from atlas_procurement.purchase_orders)+(select count(*) from atlas_procurement.purchase_order_revisions)
      +(select count(*) from atlas_procurement.purchase_order_lines)+(select count(*) from atlas_procurement.purchase_order_line_revisions)
  )),
  ('evidence',(select (select count(*) from atlas_evidence.supplier_receiving_evidence)+(select count(*) from atlas_evidence.evidence_applications))),
  ('dispatch',(
    select (select count(*) from atlas_dispatch.dispatch_plans)+(select count(*) from atlas_dispatch.dispatch_plan_requirements)
      +(select count(*) from atlas_dispatch.dispatch_trips)+(select count(*) from atlas_dispatch.dispatch_stops)
      +(select count(*) from atlas_dispatch.dispatch_loads)+(select count(*) from atlas_dispatch.dispatch_load_lines)+(select count(*) from atlas_dispatch.dispatch_load_line_applications)
      +(select count(*) from atlas_dispatch.delivery_confirmations)+(select count(*) from atlas_dispatch.delivery_confirmation_lines)
  ));

set local role authenticated;
select set_config('request.jwt.claim.sub','f5000000-0000-0000-0000-000000000101',true);
insert into pa05g_read_results values ('trace-1',atlas_api.get_supplier_direct_trace(pg_catalog.jsonb_build_object(
  'contract_version','PA-05B.v1','requested_by_auth_subject','f5000000-0000-0000-0000-000000000101',
  'payload',pg_catalog.jsonb_build_object('wholesale_order_line_revision_id',(select id_value from pa05g_ids where id_name='wholesale_order_line_revision' and line_number=1))
)));
insert into pa05g_read_results values ('trace-2',atlas_api.get_supplier_direct_trace(pg_catalog.jsonb_build_object(
  'contract_version','PA-05B.v1','requested_by_auth_subject','f5000000-0000-0000-0000-000000000101',
  'payload',pg_catalog.jsonb_build_object('wholesale_order_line_revision_id',(select id_value from pa05g_ids where id_name='wholesale_order_line_revision' and line_number=2))
)));
insert into pa05g_read_results values ('readiness',atlas_api.get_dispatch_evidence_readiness(pg_catalog.jsonb_build_object(
  'contract_version','PA-05C.v1','requested_by_auth_subject','f5000000-0000-0000-0000-000000000101',
  'correlation_id','f5900000-0000-0000-0000-000000000001',
  'payload',pg_catalog.jsonb_build_object('dispatch_trip_id',(select id_value from pa05g_ids where id_name='dispatch_trip' and line_number=0))
)));
insert into pa05g_read_results values ('blockers',atlas_api.get_operator_blockers(pg_catalog.jsonb_build_object(
  'contract_version','PA-05C.v1','requested_by_auth_subject','f5000000-0000-0000-0000-000000000101',
  'correlation_id','f5900000-0000-0000-0000-000000000001',
  'payload',pg_catalog.jsonb_build_object('dispatch_trip_id',(select id_value from pa05g_ids where id_name='dispatch_trip' and line_number=0))
)));
insert into pa05g_read_results values ('timeline',atlas_api.get_command_audit_timeline(pg_catalog.jsonb_build_object(
  'contract_version','PA-05C.v1','requested_by_auth_subject','f5000000-0000-0000-0000-000000000101',
  'correlation_id','f5900000-0000-0000-0000-000000000001',
  'payload',pg_catalog.jsonb_build_object('correlation_id','f5900000-0000-0000-0000-000000000001')
)));
reset role;

select ok(not exists(select 1 from pa05g_read_results where coalesce((response_payload->>'success')::boolean,false) is not true),'all four authorized read function types succeed as the same operator');
select ok((select response_payload#>>'{trace,quantities,delivered}'='10.000000' and response_payload#>>'{trace,stage_statuses,dispatch_trip}'='DELIVERED' from pa05g_read_results where read_name='trace-1'),'line one trace returns exact delivered quantity and DELIVERED Trip status');
select ok((select response_payload#>>'{trace,quantities,delivered}'='3.000000' and response_payload#>>'{trace,stage_statuses,dispatch_trip}'='DELIVERED' from pa05g_read_results where read_name='trace-2'),'line two trace returns exact delivered quantity and DELIVERED Trip status');
select ok(not exists(select 1 from pa05g_read_results where read_name like 'trace-%' and response_payload::text ~* '(command_receipt|request_hash|response_payload|audit_event|credential|jwt|sqlstate|policy)'),'supplier traces expose no receipt, request hash, raw response, or audit internals');
select is((select jsonb_array_length(response_payload->'readiness_items') from pa05g_read_results where read_name='readiness'),2,'readiness returns exactly two items');
select ok(not exists(select 1 from pa05g_read_results r cross join lateral jsonb_array_elements(r.response_payload->'readiness_items') item where r.read_name='readiness' and (item->>'readiness_status'<>'DELIVERED' or jsonb_array_length(item->'blockers')<>0)),'both readiness items use DELIVERED with no unresolved Evidence blocker');
select ok(not exists(select 1 from pa05g_read_results r cross join lateral jsonb_array_elements(r.response_payload->'blockers') blocker where r.read_name='blockers' and blocker->>'severity'='ERROR'),'operator blockers contains no unresolved actionable ERROR blocker');
select is((select jsonb_array_length(response_payload->'blockers') from pa05g_read_results where read_name='blockers'),2,'completion is represented by two current DELIVERY_COMPLETED information items');
select ok(not exists(select 1 from pa05g_read_results r cross join lateral jsonb_array_elements(r.response_payload->'blockers') blocker where r.read_name='blockers' and (blocker->>'blocker_type'<>'DELIVERY_COMPLETED' or blocker->>'severity'<>'INFO')),'operator blockers uses the existing completion vocabulary only');
select is((select jsonb_array_length(response_payload->'domain_events') from pa05g_read_results where read_name='timeline'),17,'timeline returns all 17 domain events');
select is((select jsonb_array_length(response_payload->'audit_events') from pa05g_read_results where read_name='timeline'),17,'timeline returns all 17 audit events');
select ok((select exists(select 1 from jsonb_array_elements(response_payload->'domain_events') e where e->>'event_type'='SuccessfulDispatchTripClosed') from pa05g_read_results where read_name='timeline'),'timeline contains SuccessfulDispatchTripClosed');
select is((select (response_payload->>'event_limit')::integer from pa05g_read_results where read_name='timeline'),100,'timeline preserves the existing 100-event limit');
select ok(not exists(select 1 from pa05g_read_results where response_payload::text ~* '(request_hash|response_payload|credential|jwt|service.role|sqlstate|sqlerrm|internal_query|policy|stack.trace|private.diagnostic)'),'all authorized reads exclude prohibited internal fields');

select ok(
  (select row_count from pa05g_pre_read_counts where count_name='command_receipts')=(select count(*) from atlas_core.command_receipts)
  and (select row_count from pa05g_pre_read_counts where count_name='domain_events')=(select count(*) from atlas_audit.domain_events)
  and (select row_count from pa05g_pre_read_counts where count_name='audit_events')=(select count(*) from atlas_audit.audit_events),
  'authorized reads create or change no command receipt, domain event, or audit event'
);
select ok(
  (select row_count from pa05g_pre_read_counts where count_name='planning')=(
    select (select count(*) from atlas_planning.wholesale_orders)+(select count(*) from atlas_planning.wholesale_order_lines)+(select count(*) from atlas_planning.wholesale_order_line_revisions)
      +(select count(*) from atlas_planning.confirmed_need_batches)+(select count(*) from atlas_planning.confirmed_need_lines)+(select count(*) from atlas_planning.confirmed_need_line_revisions)
      +(select count(*) from atlas_planning.confirmed_need_approval_snapshots)+(select count(*) from atlas_planning.confirmed_need_snapshot_lines)
      +(select count(*) from atlas_planning.purchase_handoff_batches)+(select count(*) from atlas_planning.purchase_handoff_revisions)+(select count(*) from atlas_planning.purchase_handoff_lines)
      +(select count(*) from atlas_planning.purchase_handoff_line_revisions)+(select count(*) from atlas_planning.purchase_demand_references)
      +(select count(*) from atlas_planning.dispatch_requirements)+(select count(*) from atlas_planning.dispatch_requirement_revisions)+(select count(*) from atlas_planning.dispatch_requirement_lines)+(select count(*) from atlas_planning.dispatch_requirement_line_revisions)
  ) and (select row_count from pa05g_pre_read_counts where count_name='procurement')=(
    select (select count(*) from atlas_procurement.fulfilment_allocations)+(select count(*) from atlas_procurement.fulfilment_allocation_revisions)
      +(select count(*) from atlas_procurement.fulfilment_allocation_lines)+(select count(*) from atlas_procurement.fulfilment_allocation_line_revisions)
      +(select count(*) from atlas_procurement.purchase_orders)+(select count(*) from atlas_procurement.purchase_order_revisions)
      +(select count(*) from atlas_procurement.purchase_order_lines)+(select count(*) from atlas_procurement.purchase_order_line_revisions)
  ) and (select row_count from pa05g_pre_read_counts where count_name='evidence')=(select (select count(*) from atlas_evidence.supplier_receiving_evidence)+(select count(*) from atlas_evidence.evidence_applications))
  and (select row_count from pa05g_pre_read_counts where count_name='dispatch')=(
    select (select count(*) from atlas_dispatch.dispatch_plans)+(select count(*) from atlas_dispatch.dispatch_plan_requirements)
      +(select count(*) from atlas_dispatch.dispatch_trips)+(select count(*) from atlas_dispatch.dispatch_stops)
      +(select count(*) from atlas_dispatch.dispatch_loads)+(select count(*) from atlas_dispatch.dispatch_load_lines)+(select count(*) from atlas_dispatch.dispatch_load_line_applications)
      +(select count(*) from atlas_dispatch.delivery_confirmations)+(select count(*) from atlas_dispatch.delivery_confirmation_lines)
  ),
  'authorized reads create or change no Planning, Procurement, Evidence, or Dispatch row'
);

-- Reviewed surface and direct-access boundary.
select is((select count(*)::integer from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='atlas_api'),19,'Atlas API contains exactly 19 reviewed functions');
select is((select count(*)::integer from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='atlas_api' and has_function_privilege('authenticated',p.oid,'EXECUTE')),19,'authenticated executes exactly the 19 reviewed Atlas API functions');
select ok(not exists(
  select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  cross join unnest(array['anon','service_role']) x(role_name)
  where n.nspname='atlas_api' and has_function_privilege(x.role_name,p.oid,'EXECUTE')
),'anon and service_role execute no Atlas API function');
select ok(not exists(
  select 1 from unnest(array['anon','authenticated','service_role']) x(role_name)
  cross join pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname like 'atlas\_%' escape '\' and c.relkind in ('r','v','m','S')
    and (has_table_privilege(x.role_name,c.oid,'SELECT') or has_table_privilege(x.role_name,c.oid,'INSERT')
      or has_table_privilege(x.role_name,c.oid,'UPDATE') or has_table_privilege(x.role_name,c.oid,'DELETE')
      or (c.relkind='S' and has_sequence_privilege(x.role_name,c.oid,'USAGE')))
),'API roles have no direct private relation or sequence access');

-- Durable diagnostic evidence for the implementation report when the file is
-- run directly with psql; pg_prove may suppress these comments on success.
select diag('PA-05G commands=' || (select jsonb_agg(jsonb_build_object(
  'order',execution_order,'name',command_name,'command_id',command_id,
  'affected',response_payload->'affected_aggregate_ids','versions',response_payload->'new_versions',
  'event_ids',response_payload->'emitted_event_ids','audit_ids',response_payload->'audit_event_ids'
) order by execution_order)::text from pa05g_results));
select diag('PA-05G authoritative=' || jsonb_build_object(
  'wholesale_order_id',(select id_value from pa05g_ids where id_name='wholesale_order' and line_number=0),
  'dispatch_requirement_revision_id',(select id_value from pa05g_ids where id_name='dispatch_requirement_revision' and line_number=0),
  'fulfilment_allocation_revision_id',(select id_value from pa05g_ids where id_name='fulfilment_allocation_revision' and line_number=0),
  'dispatch_plan_id',(select id_value from pa05g_ids where id_name='dispatch_plan' and line_number=0),
  'dispatch_trip_id',(select id_value from pa05g_ids where id_name='dispatch_trip' and line_number=0),
  'trip_status',(select trip_status from atlas_dispatch.dispatch_trips where dispatch_trip_id=(select id_value from pa05g_ids where id_name='dispatch_trip' and line_number=0)),
  'trip_version',(select version from atlas_dispatch.dispatch_trips where dispatch_trip_id=(select id_value from pa05g_ids where id_name='dispatch_trip' and line_number=0)),
  'departed_at',(select departed_at from atlas_dispatch.dispatch_trips where dispatch_trip_id=(select id_value from pa05g_ids where id_name='dispatch_trip' and line_number=0)),
  'completed_at',(select completed_at from atlas_dispatch.dispatch_trips where dispatch_trip_id=(select id_value from pa05g_ids where id_name='dispatch_trip' and line_number=0))
)::text);
select diag('PA-05G reads=' || (select jsonb_object_agg(read_name,response_payload)::text from pa05g_read_results));

select * from finish();
rollback;
