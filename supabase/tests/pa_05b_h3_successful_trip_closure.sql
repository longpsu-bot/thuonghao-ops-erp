begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
select no_plan();

grant usage on schema extensions to authenticated;
grant execute on all functions in schema extensions to authenticated;

-- Public surface and least-privilege ownership.
select is(
  (select count(*)::integer from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='atlas_api'),
  18,
  'Atlas API contains exactly 18 reviewed functions'
);
select is(
  (select count(*)::integer from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='atlas_api' and has_function_privilege('authenticated',p.oid,'EXECUTE')),
  18,
  'authenticated can execute exactly the 18 reviewed Atlas API functions'
);
select ok(
  not has_function_privilege('anon','atlas_api.close_successful_trip(jsonb)'::regprocedure,'EXECUTE')
  and not has_function_privilege('service_role','atlas_api.close_successful_trip(jsonb)'::regprocedure,'EXECUTE'),
  'anon and service_role cannot execute successful trip closure'
);
select ok(
  (select r.rolname='atlas_dispatch_command_runtime' and p.prosecdef and p.provolatile='v'
          and p.proconfig is not null and p.proconfig::text like '%search_path=%'
   from pg_proc p join pg_roles r on r.oid=p.proowner
   where p.oid='atlas_api.close_successful_trip(jsonb)'::regprocedure),
  'closure is a hardened volatile definer owned by Dispatch runtime'
);
select ok(
  pg_get_functiondef('atlas_api.close_successful_trip(jsonb)'::regprocedure) !~* '\\mexecute\\M',
  'closure contains no dynamic SQL'
);
select is(
  (select count(*)::integer from pg_proc p join pg_roles r on r.oid=p.proowner
   where r.rolname='atlas_dispatch_command_runtime'),
  6,
  'Dispatch runtime owns exactly the three H2, two PA-05F, and one H3 entry functions'
);
select ok(
  (select r.rolname from pg_proc p join pg_roles r on r.oid=p.proowner
   where p.oid='atlas_core.pa_05b_h3_trip_closure_signature(uuid,timestamptz)'::regprocedure)='atlas_owner'
  and has_function_privilege(
    'atlas_dispatch_command_runtime',
    'atlas_core.pa_05b_h3_trip_closure_signature(uuid,timestamptz)'::regprocedure,
    'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'atlas_core.pa_05b_h3_trip_closure_signature(uuid,timestamptz)'::regprocedure,
    'EXECUTE'
  ),
  'the single H3 helper is private and owner-hardened'
);
select ok(
  has_table_privilege('atlas_dispatch_command_runtime','atlas_dispatch.dispatch_trips','UPDATE')
  and has_table_privilege('atlas_dispatch_command_runtime','atlas_dispatch.delivery_confirmation_lines','UPDATE')
  and not has_table_privilege('atlas_dispatch_command_runtime','atlas_planning.dispatch_requirements','INSERT')
  and not has_table_privilege('atlas_dispatch_command_runtime','atlas_procurement.fulfilment_allocations','INSERT')
  and not has_table_privilege('atlas_dispatch_command_runtime','atlas_evidence.supplier_receiving_evidence','INSERT')
  and not exists (
    select 1 from pg_policy p join pg_class c on c.oid=p.polrelid
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname in ('atlas_planning','atlas_procurement','atlas_evidence')
      and p.polcmd='w'
      and p.polroles && array[(select oid from pg_roles where rolname='atlas_dispatch_command_runtime')]
  )
  and not has_schema_privilege('atlas_dispatch_command_runtime','atlas_api','CREATE'),
  'H3 runtime privileges permit bounded Dispatch locking and trip update only'
);
select ok(
  not exists (
    select 1 from pg_policy p join pg_class c on c.oid=p.polrelid
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='atlas_dispatch' and c.relname='delivery_confirmation_lines'
      and p.polcmd='w'
      and p.polroles && array[(select oid from pg_roles where rolname='atlas_dispatch_command_runtime')]
  ),
  'lock-only delivery-line UPDATE grant has no writable RLS path'
);

-- One actor authors the complete PA-05D -> PA-05E -> Evidence -> PA-05F ->
-- PA-05B-H2 -> PA-05B-H3 journey. A separate delegated driver is assigned.
insert into atlas_core.actors (actor_id,actor_type,display_name,actor_status,deactivated_at) values
  ('a7000000-0000-0000-0000-000000000001','HUMAN','PA-05B-H3 operator','ACTIVE',null),
  ('a7000000-0000-0000-0000-000000000002','DELEGATED_DRIVER','PA-05B-H3 driver','ACTIVE',null),
  ('a7000000-0000-0000-0000-000000000003','HUMAN','PA-05B-H3 narrow operator','ACTIVE',null),
  ('a7000000-0000-0000-0000-000000000004','DELEGATED_DRIVER','PA-05B-H3 inactive driver','INACTIVE',timestamptz '2026-07-17 00:00:00+00'),
  ('a7000000-0000-0000-0000-000000000005','HUMAN','PA-05B-H3 no capability','ACTIVE',null);
insert into atlas_core.actor_auth_subjects (actor_id,auth_subject_id) values
  ('a7000000-0000-0000-0000-000000000001','a7000000-0000-0000-0000-000000000101'),
  ('a7000000-0000-0000-0000-000000000003','a7000000-0000-0000-0000-000000000103'),
  ('a7000000-0000-0000-0000-000000000005','a7000000-0000-0000-0000-000000000105');
insert into atlas_core.roles (role_id,role_code,role_name) values
  ('a7100000-0000-0000-0000-000000000001','pa05b_h3.operator','PA-05B-H3 operator');
insert into atlas_core.capabilities (capability_id,capability_code,capability_name,owning_domain) values
  ('a7200000-0000-0000-0000-000000000001','wholesale_source.record','Record wholesale source','PLANNING'),
  ('a7200000-0000-0000-0000-000000000002','wholesale_order.release','Release wholesale order','PLANNING'),
  ('a7200000-0000-0000-0000-000000000003','purchase_handoff.release','Release purchase handoff','PLANNING'),
  ('a7200000-0000-0000-0000-000000000004','dispatch_requirement.release','Release dispatch requirement','PLANNING'),
  ('a7200000-0000-0000-0000-000000000005','supplier_direct_fulfilment.allocate','Allocate supplier-direct fulfilment','PROCUREMENT'),
  ('a7200000-0000-0000-0000-000000000006','supplier_purchase_order.release','Release supplier purchase order','PROCUREMENT'),
  ('a7200000-0000-0000-0000-000000000007','supplier_receiving_evidence.record','Record supplier evidence','EVIDENCE'),
  ('a7200000-0000-0000-0000-000000000008','supplier_evidence_application.apply','Apply supplier evidence','EVIDENCE'),
  ('a7200000-0000-0000-0000-000000000009','dispatch_plan.create','Create Dispatch Plan','DISPATCH'),
  ('a7200000-0000-0000-0000-00000000000a','dispatch_trip.assign','Assign Dispatch Trip','DISPATCH'),
  ('a7200000-0000-0000-0000-00000000000b','dispatch_load.confirm','Confirm Dispatch load','DISPATCH'),
  ('a7200000-0000-0000-0000-00000000000c','dispatch_departure.record','Record Dispatch departure','DISPATCH'),
  ('a7200000-0000-0000-0000-00000000000d','delivery_success.confirm','Confirm successful delivery','DISPATCH'),
  ('a7200000-0000-0000-0000-00000000000e','dispatch_trip.close_successful','Close successful Dispatch Trip','DISPATCH');
insert into atlas_core.role_capabilities (role_id,capability_id)
select 'a7100000-0000-0000-0000-000000000001',capability_id
from atlas_core.capabilities where capability_id::text like 'a7200000-0000-0000-0000-00000000000%';
insert into atlas_core.actor_role_memberships (actor_id,role_id) values
  ('a7000000-0000-0000-0000-000000000001','a7100000-0000-0000-0000-000000000001'),
  ('a7000000-0000-0000-0000-000000000003','a7100000-0000-0000-0000-000000000001');
insert into atlas_core.actor_scopes (actor_id,scope_kind) values
  ('a7000000-0000-0000-0000-000000000001','GLOBAL'),
  ('a7000000-0000-0000-0000-000000000005','GLOBAL');

insert into atlas_admin.customers (customer_id,customer_code,customer_name) values
  ('a7300000-0000-0000-0000-000000000001','pa05b-h3-customer','PA-05B-H3 Customer');
insert into atlas_admin.delivery_locations (
  delivery_location_id,customer_id,location_code,location_name,address_text,timezone_name
) values (
  'a7300000-0000-0000-0000-000000000011','a7300000-0000-0000-0000-000000000001',
  'pa05b-h3-location','PA-05B-H3 Location','PA-05B-H3 Address','Asia/Bangkok'
);
insert into atlas_admin.units (unit_id,unit_code,unit_name,dimension_code) values
  ('a7300000-0000-0000-0000-000000000021','pa05b-h3-kg','kilogram','mass');
insert into atlas_admin.ingredients (ingredient_id,ingredient_code,ingredient_name) values
  ('a7300000-0000-0000-0000-000000000031','pa05b-h3-rice','Rice');
insert into atlas_admin.suppliers (supplier_id,supplier_code,supplier_name) values
  ('a7300000-0000-0000-0000-000000000041','pa05b-h3-supplier','PA-05B-H3 Supplier');

create temporary table h3_results (
  result_name text primary key,
  response_payload jsonb not null
);
grant select,insert,update on h3_results to authenticated;
create temporary table h3_ids (id_name text primary key,id_value uuid not null);
grant select on h3_ids to authenticated;

create function pg_temp.h3_request(
  contract text,command_id uuid,idempotency_key text,expected_version bigint,payload jsonb,
  subject uuid default 'a7000000-0000-0000-0000-000000000101'
) returns jsonb language sql immutable set search_path='' as $$
  select pg_catalog.jsonb_build_object(
    'contract_version',contract,'command_id',command_id,
    'correlation_id','a7900000-0000-0000-0000-000000000001'::uuid,
    'idempotency_key',idempotency_key,'expected_version',expected_version,
    'requested_by_auth_subject',subject,'requested_at','2026-07-17T00:00:00+00:00',
    'reason_code','PA05B_H3_TEST','reason_note','PA-05B-H3 pgTAP','payload',payload
  )
$$;

set local role authenticated;
select set_config('request.jwt.claim.sub','a7000000-0000-0000-0000-000000000101',true);
insert into h3_results values ('source',atlas_api.record_wholesale_source(pg_temp.h3_request(
  'PA-05D.v1','a7900000-0000-0000-0000-000000000101','h3-source',1,
  pg_catalog.jsonb_build_object(
    'customer_id','a7300000-0000-0000-0000-000000000001',
    'delivery_location_id','a7300000-0000-0000-0000-000000000011',
    'customer_order_reference','PA05B-H3-ORDER','service_date','2026-07-17',
    'lines',pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'source_line_number',1,'ingredient_id','a7300000-0000-0000-0000-000000000031',
      'requested_quantity',10,'unit_id','a7300000-0000-0000-0000-000000000021'
    ))
  )
)));
insert into h3_results values ('release',atlas_api.release_wholesale_order(pg_temp.h3_request(
  'PA-05D.v1','a7900000-0000-0000-0000-000000000102','h3-release',1,
  pg_catalog.jsonb_build_object('wholesale_order_id',(
    select response_payload#>>'{affected_aggregate_ids,wholesale_order_id}' from h3_results where result_name='source'
  ))
)));
insert into h3_results values ('handoff',atlas_api.release_purchase_handoff(pg_temp.h3_request(
  'PA-05D.v1','a7900000-0000-0000-0000-000000000103','h3-handoff',1,
  pg_catalog.jsonb_build_object('confirmed_need_batch_id',(
    select response_payload#>>'{affected_aggregate_ids,confirmed_need_batch_id}' from h3_results where result_name='release'
  ))
)));
insert into h3_results values ('requirement',atlas_api.release_dispatch_requirement(pg_temp.h3_request(
  'PA-05D.v1','a7900000-0000-0000-0000-000000000104','h3-requirement',1,
  pg_catalog.jsonb_build_object('purchase_handoff_revision_id',(
    select response_payload#>>'{affected_aggregate_ids,purchase_handoff_revision_id}' from h3_results where result_name='handoff'
  ))
)));
reset role;

insert into h3_ids values
  ('requirement',(select (response_payload#>>'{affected_aggregate_ids,dispatch_requirement_id}')::uuid from h3_results where result_name='requirement')),
  ('requirement_revision',(select (response_payload#>>'{affected_aggregate_ids,dispatch_requirement_revision_id}')::uuid from h3_results where result_name='requirement'));
insert into h3_ids
select 'requirement_line_revision',drlr.dispatch_requirement_line_revision_id
from atlas_planning.dispatch_requirement_line_revisions drlr
where drlr.dispatch_requirement_revision_id=(select id_value from h3_ids where id_name='requirement_revision');

set local role authenticated;
select set_config('request.jwt.claim.sub','a7000000-0000-0000-0000-000000000101',true);
insert into h3_results values ('allocation',atlas_api.allocate_supplier_direct_fulfilment(pg_temp.h3_request(
  'PA-05E.v1','a7900000-0000-0000-0000-000000000201','h3-allocation',1,
  pg_catalog.jsonb_build_object(
    'dispatch_requirement_revision_id',(select id_value from h3_ids where id_name='requirement_revision'),
    'lines',pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'dispatch_requirement_line_revision_id',(select id_value from h3_ids where id_name='requirement_line_revision'),
      'supplier_id','a7300000-0000-0000-0000-000000000041','allocated_quantity',10,
      'unit_id','a7300000-0000-0000-0000-000000000021'
    ))
  )
)));
insert into h3_results values ('purchase-order',atlas_api.release_supplier_purchase_order(pg_temp.h3_request(
  'PA-05E.v1','a7900000-0000-0000-0000-000000000202','h3-purchase-order',1,
  pg_catalog.jsonb_build_object(
    'fulfilment_allocation_revision_id',(
      select response_payload#>>'{affected_aggregate_ids,fulfilment_allocation_revision_id}'
      from h3_results where result_name='allocation'
    ),
    'supplier_id','a7300000-0000-0000-0000-000000000041','document_number','PA05B-H3-PO'
  )
)));
reset role;

insert into h3_ids values
  ('allocation',(select (response_payload#>>'{affected_aggregate_ids,fulfilment_allocation_id}')::uuid from h3_results where result_name='allocation')),
  ('allocation_revision',(select (response_payload#>>'{affected_aggregate_ids,fulfilment_allocation_revision_id}')::uuid from h3_results where result_name='allocation')),
  ('purchase_order',(select (response_payload#>>'{affected_aggregate_ids,purchase_order_id}')::uuid from h3_results where result_name='purchase-order'));
insert into h3_ids
select 'allocation_line_revision',falr.fulfilment_allocation_line_revision_id
from atlas_procurement.fulfilment_allocation_line_revisions falr
where falr.fulfilment_allocation_revision_id=(select id_value from h3_ids where id_name='allocation_revision');
insert into h3_ids
select 'purchase_order_line_revision',polr.purchase_order_line_revision_id
from atlas_procurement.purchase_order_line_revisions polr
where polr.purchase_order_revision_id=(
  select por.purchase_order_revision_id from atlas_procurement.purchase_order_revisions por
  where por.purchase_order_id=(select id_value from h3_ids where id_name='purchase_order') and por.is_current
);

set local role authenticated;
select set_config('request.jwt.claim.sub','a7000000-0000-0000-0000-000000000101',true);
insert into h3_results values ('evidence',atlas_api.record_supplier_receiving_evidence(pg_temp.h3_request(
  'PA-05B.v1','a7900000-0000-0000-0000-000000000301','h3-evidence',1,
  pg_catalog.jsonb_build_object(
    'purchase_order_line_revision_id',(select id_value from h3_ids where id_name='purchase_order_line_revision'),
    'supplier_id','a7300000-0000-0000-0000-000000000041',
    'ingredient_id','a7300000-0000-0000-0000-000000000031',
    'unit_id','a7300000-0000-0000-0000-000000000021','evidence_quantity',10,
    'evidence_reference','PA05B-H3-EVIDENCE','occurred_at','2026-07-17T00:10:00+00:00'
  )
)));
insert into h3_results values ('application',atlas_api.apply_supplier_evidence_to_allocation(pg_temp.h3_request(
  'PA-05B.v1','a7900000-0000-0000-0000-000000000302','h3-application',1,
  pg_catalog.jsonb_build_object(
    'supplier_receiving_evidence_id',(
      select response_payload#>>'{affected_aggregate_ids,supplier_receiving_evidence_id}' from h3_results where result_name='evidence'
    ),
    'fulfilment_allocation_line_revision_id',(select id_value from h3_ids where id_name='allocation_line_revision'),
    'unit_id','a7300000-0000-0000-0000-000000000021','applied_quantity',10,
    'occurred_at','2026-07-17T00:15:00+00:00'
  )
)));
insert into h3_results values ('plan',atlas_api.create_dispatch_plan(pg_temp.h3_request(
  'PA-05F.v1','a7900000-0000-0000-0000-000000000401','h3-plan',1,
  pg_catalog.jsonb_build_object(
    'plan_reference','PA05B-H3-PLAN','dispatch_wave','MORNING',
    'requirements',pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'dispatch_requirement_revision_id',(select id_value from h3_ids where id_name='requirement_revision'),
      'fulfilment_allocation_revision_id',(select id_value from h3_ids where id_name='allocation_revision'),
      'expected_dispatch_requirement_version',1,'expected_fulfilment_allocation_version',1
    ))
  )
)));
insert into h3_results values ('trip',atlas_api.create_or_assign_dispatch_trip(pg_temp.h3_request(
  'PA-05F.v1','a7900000-0000-0000-0000-000000000402','h3-trip',1,
  pg_catalog.jsonb_build_object(
    'dispatch_plan_id',(select response_payload#>>'{affected_aggregate_ids,dispatch_plan_id}' from h3_results where result_name='plan'),
    'trip_reference','PA05B-H3-TRIP','driver_actor_id','a7000000-0000-0000-0000-000000000002',
    'vehicle_reference','PA05B-H3-TRUCK','planned_departure_at','2026-07-17T00:30:00+00:00',
    'stops',pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'dispatch_plan_requirement_id',(
        select response_payload#>>'{affected_aggregate_ids,dispatch_plan_requirement_ids,0}'
        from h3_results where result_name='plan'
      ),'stop_sequence',1
    ))
  )
)));
reset role;

insert into h3_ids values
  ('plan',(select (response_payload#>>'{affected_aggregate_ids,dispatch_plan_id}')::uuid from h3_results where result_name='plan')),
  ('plan_requirement',(select (response_payload#>>'{affected_aggregate_ids,dispatch_plan_requirement_ids,0}')::uuid from h3_results where result_name='plan')),
  ('trip',(select (response_payload#>>'{affected_aggregate_ids,dispatch_trip_id}')::uuid from h3_results where result_name='trip'));
insert into h3_ids
select 'stop',ds.dispatch_stop_id from atlas_dispatch.dispatch_stops ds
where ds.dispatch_trip_id=(select id_value from h3_ids where id_name='trip');
insert into h3_ids values
  ('evidence_application',(select (response_payload#>>'{affected_aggregate_ids,evidence_application_id}')::uuid from h3_results where result_name='application'));

set local role authenticated;
select set_config('request.jwt.claim.sub','a7000000-0000-0000-0000-000000000101',true);
insert into h3_results values ('load',atlas_api.confirm_dispatch_load(pg_temp.h3_request(
  'PA-05B-H2.v1','a7900000-0000-0000-0000-000000000501','h3-load',1,
  pg_catalog.jsonb_build_object(
    'dispatch_trip_id',(select id_value from h3_ids where id_name='trip'),
    'dispatch_stop_id',(select id_value from h3_ids where id_name='stop'),
    'dispatch_requirement_revision_id',(select id_value from h3_ids where id_name='requirement_revision'),
    'fulfilment_allocation_revision_id',(select id_value from h3_ids where id_name='allocation_revision'),
    'loaded_at','2026-07-17T00:45:00+00:00',
    'lines',pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'dispatch_requirement_line_revision_id',(select id_value from h3_ids where id_name='requirement_line_revision'),
      'fulfilment_allocation_line_revision_id',(select id_value from h3_ids where id_name='allocation_line_revision'),
      'loaded_quantity',10,'unit_id','a7300000-0000-0000-0000-000000000021',
      'evidence_applications',pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'evidence_application_id',(select id_value from h3_ids where id_name='evidence_application'),
        'applied_to_load_quantity',10,'unit_id','a7300000-0000-0000-0000-000000000021'
      ))
    ))
  )
)));
insert into h3_results values ('departure',atlas_api.record_dispatch_departure(pg_temp.h3_request(
  'PA-05B-H2.v1','a7900000-0000-0000-0000-000000000502','h3-departure',2,
  pg_catalog.jsonb_build_object(
    'dispatch_trip_id',(select id_value from h3_ids where id_name='trip'),
    'departed_at','2026-07-17T01:00:00+00:00'
  )
)));
reset role;

insert into h3_ids
select 'load_line',dll.dispatch_load_line_id
from atlas_dispatch.dispatch_loads dl join atlas_dispatch.dispatch_load_lines dll on dll.dispatch_load_id=dl.dispatch_load_id
where dl.dispatch_trip_id=(select id_value from h3_ids where id_name='trip');

set local role authenticated;
select set_config('request.jwt.claim.sub','a7000000-0000-0000-0000-000000000101',true);
insert into h3_results values ('delivery',atlas_api.confirm_successful_delivery(pg_temp.h3_request(
  'PA-05B-H2.v1','a7900000-0000-0000-0000-000000000503','h3-delivery',3,
  pg_catalog.jsonb_build_object(
    'dispatch_trip_id',(select id_value from h3_ids where id_name='trip'),
    'dispatch_stop_id',(select id_value from h3_ids where id_name='stop'),
    'lines',pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'dispatch_load_line_id',(select id_value from h3_ids where id_name='load_line'),
      'unit_id','a7300000-0000-0000-0000-000000000021',
      'delivered_quantity',10,'returned_quantity',0,'exception_quantity',0
    )),
    'confirmed_at','2026-07-17T01:15:00+00:00',
    'received_by_reference','PA05B-H3-RECEIVER','notes','exact successful delivery'
  )
)));
reset role;

-- Closure rejects invalid requests and every incomplete/corrupt terminal state
-- without changing the delivered trip or emitting closure audit facts.
insert into atlas_dispatch.dispatch_plans (
  dispatch_plan_id,plan_reference,service_date,plan_status,version,created_by_actor_id
) values (
  'a7800000-0000-0000-0000-000000000001','PA05B-H3-NO-STOPS',date '2026-07-17',
  'PLANNED',1,'a7000000-0000-0000-0000-000000000001'
);
insert into atlas_dispatch.dispatch_trips (
  dispatch_trip_id,dispatch_plan_id,trip_reference,trip_status,driver_actor_id,
  vehicle_reference,departed_at,version
) values (
  'a7800000-0000-0000-0000-000000000002','a7800000-0000-0000-0000-000000000001',
  'PA05B-H3-NO-STOPS','DELIVERED','a7000000-0000-0000-0000-000000000002',
  'PA05B-H3-NO-STOPS-TRUCK',timestamptz '2026-07-17 01:00:00+00',1
);

set local role authenticated;
select set_config('request.jwt.claim.sub','a7000000-0000-0000-0000-000000000101',true);
insert into h3_results values ('malformed',atlas_api.close_successful_trip('{}'::jsonb));
insert into h3_results values ('stale',atlas_api.close_successful_trip(pg_temp.h3_request(
  'PA-05B-H3.v1','a7900000-0000-0000-0000-000000000610','h3-stale',99,
  pg_catalog.jsonb_build_object('dispatch_trip_id',(select id_value from h3_ids where id_name='trip'),
    'completed_at','2026-07-17T01:30:00+00:00')
)));
insert into h3_results values ('timestamp-before-confirmation',atlas_api.close_successful_trip(pg_temp.h3_request(
  'PA-05B-H3.v1','a7900000-0000-0000-0000-000000000611','h3-time',4,
  pg_catalog.jsonb_build_object('dispatch_trip_id',(select id_value from h3_ids where id_name='trip'),
    'completed_at','2026-07-17T01:10:00+00:00')
)));
insert into h3_results values ('future-completion',atlas_api.close_successful_trip(pg_temp.h3_request(
  'PA-05B-H3.v1','a7900000-0000-0000-0000-000000000624','h3-future',4,
  pg_catalog.jsonb_build_object('dispatch_trip_id',(select id_value from h3_ids where id_name='trip'),
    'completed_at','2099-01-01T00:00:00+00:00')
)));
insert into h3_results values ('unknown-field',atlas_api.close_successful_trip(
  pg_temp.h3_request(
    'PA-05B-H3.v1','a7900000-0000-0000-0000-000000000625','h3-unknown',4,
    pg_catalog.jsonb_build_object('dispatch_trip_id',(select id_value from h3_ids where id_name='trip'),
      'completed_at','2026-07-17T01:30:00+00:00')
  ) || pg_catalog.jsonb_build_object('unknown_field',true)
));
insert into h3_results values ('no-stops',atlas_api.close_successful_trip(pg_temp.h3_request(
  'PA-05B-H3.v1','a7900000-0000-0000-0000-000000000612','h3-no-stops',1,
  pg_catalog.jsonb_build_object('dispatch_trip_id','a7800000-0000-0000-0000-000000000002',
    'completed_at','2026-07-17T01:30:00+00:00')
)));
select set_config('request.jwt.claim.sub','a7000000-0000-0000-0000-000000000105',true);
insert into h3_results values ('capability-denied',atlas_api.close_successful_trip(pg_temp.h3_request(
  'PA-05B-H3.v1','a7900000-0000-0000-0000-000000000626','h3-capability',4,
  pg_catalog.jsonb_build_object('dispatch_trip_id',(select id_value from h3_ids where id_name='trip'),
    'completed_at','2026-07-17T01:30:00+00:00'),
  'a7000000-0000-0000-0000-000000000105'
)));
select set_config('request.jwt.claim.sub','a7000000-0000-0000-0000-000000000103',true);
insert into h3_results values ('partial-scope',atlas_api.close_successful_trip(pg_temp.h3_request(
  'PA-05B-H3.v1','a7900000-0000-0000-0000-000000000613','h3-partial-scope',4,
  pg_catalog.jsonb_build_object('dispatch_trip_id',(select id_value from h3_ids where id_name='trip'),
    'completed_at','2026-07-17T01:30:00+00:00'),
  'a7000000-0000-0000-0000-000000000103'
)));
reset role;

update atlas_dispatch.dispatch_trips set trip_status='IN_TRANSIT'
where dispatch_trip_id=(select id_value from h3_ids where id_name='trip');
set local role authenticated;
select set_config('request.jwt.claim.sub','a7000000-0000-0000-0000-000000000101',true);
insert into h3_results values ('not-delivered',atlas_api.close_successful_trip(pg_temp.h3_request(
  'PA-05B-H3.v1','a7900000-0000-0000-0000-000000000614','h3-not-delivered',4,
  pg_catalog.jsonb_build_object('dispatch_trip_id',(select id_value from h3_ids where id_name='trip'),
    'completed_at','2026-07-17T01:30:00+00:00')
)));
reset role;
update atlas_dispatch.dispatch_trips set trip_status='DELIVERED'
where dispatch_trip_id=(select id_value from h3_ids where id_name='trip');

update atlas_dispatch.dispatch_trips set driver_actor_id=null,vehicle_reference=null
where dispatch_trip_id=(select id_value from h3_ids where id_name='trip');
set local role authenticated;
select set_config('request.jwt.claim.sub','a7000000-0000-0000-0000-000000000101',true);
insert into h3_results values ('missing-assignment',atlas_api.close_successful_trip(pg_temp.h3_request(
  'PA-05B-H3.v1','a7900000-0000-0000-0000-000000000615','h3-missing-assignment',4,
  pg_catalog.jsonb_build_object('dispatch_trip_id',(select id_value from h3_ids where id_name='trip'),
    'completed_at','2026-07-17T01:30:00+00:00')
)));
reset role;
update atlas_dispatch.dispatch_trips
set driver_actor_id='a7000000-0000-0000-0000-000000000002',vehicle_reference='PA05B-H3-TRUCK'
where dispatch_trip_id=(select id_value from h3_ids where id_name='trip');

update atlas_dispatch.dispatch_trips set driver_actor_id='a7000000-0000-0000-0000-000000000004'
where dispatch_trip_id=(select id_value from h3_ids where id_name='trip');
set local role authenticated;
select set_config('request.jwt.claim.sub','a7000000-0000-0000-0000-000000000101',true);
insert into h3_results values ('inactive-assignment',atlas_api.close_successful_trip(pg_temp.h3_request(
  'PA-05B-H3.v1','a7900000-0000-0000-0000-000000000616','h3-inactive-assignment',4,
  pg_catalog.jsonb_build_object('dispatch_trip_id',(select id_value from h3_ids where id_name='trip'),
    'completed_at','2026-07-17T01:30:00+00:00')
)));
reset role;
update atlas_dispatch.dispatch_trips set driver_actor_id='a7000000-0000-0000-0000-000000000002'
where dispatch_trip_id=(select id_value from h3_ids where id_name='trip');

update atlas_dispatch.dispatch_stops set stop_status='IN_TRANSIT'
where dispatch_stop_id=(select id_value from h3_ids where id_name='stop');
set local role authenticated;
select set_config('request.jwt.claim.sub','a7000000-0000-0000-0000-000000000101',true);
insert into h3_results values ('incomplete-stop',atlas_api.close_successful_trip(pg_temp.h3_request(
  'PA-05B-H3.v1','a7900000-0000-0000-0000-000000000617','h3-incomplete-stop',4,
  pg_catalog.jsonb_build_object('dispatch_trip_id',(select id_value from h3_ids where id_name='trip'),
    'completed_at','2026-07-17T01:30:00+00:00')
)));
reset role;
update atlas_dispatch.dispatch_stops set stop_status='DELIVERED'
where dispatch_stop_id=(select id_value from h3_ids where id_name='stop');

update atlas_dispatch.dispatch_loads set load_status='VOIDED'
where dispatch_trip_id=(select id_value from h3_ids where id_name='trip');
set local role authenticated;
select set_config('request.jwt.claim.sub','a7000000-0000-0000-0000-000000000101',true);
insert into h3_results values ('missing-current-load',atlas_api.close_successful_trip(pg_temp.h3_request(
  'PA-05B-H3.v1','a7900000-0000-0000-0000-000000000618','h3-missing-load',4,
  pg_catalog.jsonb_build_object('dispatch_trip_id',(select id_value from h3_ids where id_name='trip'),
    'completed_at','2026-07-17T01:30:00+00:00')
)));
reset role;
update atlas_dispatch.dispatch_loads set load_status='CONFIRMED'
where dispatch_trip_id=(select id_value from h3_ids where id_name='trip');

update atlas_dispatch.delivery_confirmations set confirmation_status='VOIDED'
where dispatch_stop_id=(select id_value from h3_ids where id_name='stop');
set local role authenticated;
select set_config('request.jwt.claim.sub','a7000000-0000-0000-0000-000000000101',true);
insert into h3_results values ('missing-current-delivery',atlas_api.close_successful_trip(pg_temp.h3_request(
  'PA-05B-H3.v1','a7900000-0000-0000-0000-000000000619','h3-missing-delivery',4,
  pg_catalog.jsonb_build_object('dispatch_trip_id',(select id_value from h3_ids where id_name='trip'),
    'completed_at','2026-07-17T01:30:00+00:00')
)));
reset role;
update atlas_dispatch.delivery_confirmations set confirmation_status='VALID'
where dispatch_stop_id=(select id_value from h3_ids where id_name='stop');

update atlas_dispatch.delivery_confirmation_lines set delivered_quantity=9
where dispatch_load_line_id=(select id_value from h3_ids where id_name='load_line');
set local role authenticated;
select set_config('request.jwt.claim.sub','a7000000-0000-0000-0000-000000000101',true);
insert into h3_results values ('line-corruption',atlas_api.close_successful_trip(pg_temp.h3_request(
  'PA-05B-H3.v1','a7900000-0000-0000-0000-000000000620','h3-line-corruption',4,
  pg_catalog.jsonb_build_object('dispatch_trip_id',(select id_value from h3_ids where id_name='trip'),
    'completed_at','2026-07-17T01:30:00+00:00')
)));
reset role;
update atlas_dispatch.delivery_confirmation_lines set delivered_quantity=10
where dispatch_load_line_id=(select id_value from h3_ids where id_name='load_line');

insert into atlas_dispatch.delivery_confirmations (
  delivery_confirmation_id,dispatch_stop_id,revision_number,delivery_outcome,confirmation_status,
  confirmed_by_actor_id,confirmed_at,received_by_reference,command_id,correlation_id
) values (
  'a7800000-0000-0000-0000-000000000010',(select id_value from h3_ids where id_name='stop'),
  2,'DELIVERED','VOIDED','a7000000-0000-0000-0000-000000000001',
  timestamptz '2026-07-17 01:16:00+00','PA05B-H3-EXTRA',
  'a7800000-0000-0000-0000-000000000011','a7900000-0000-0000-0000-000000000001'
);
insert into atlas_dispatch.delivery_confirmation_lines (
  delivery_confirmation_line_id,delivery_confirmation_id,dispatch_load_line_id,
  delivered_quantity,returned_quantity,exception_quantity,unit_id
) values (
  'a7800000-0000-0000-0000-000000000012','a7800000-0000-0000-0000-000000000010',
  (select id_value from h3_ids where id_name='load_line'),10,0,0,
  'a7300000-0000-0000-0000-000000000021'
);
set local role authenticated;
select set_config('request.jwt.claim.sub','a7000000-0000-0000-0000-000000000101',true);
insert into h3_results values ('extra-delivery',atlas_api.close_successful_trip(pg_temp.h3_request(
  'PA-05B-H3.v1','a7900000-0000-0000-0000-000000000621','h3-extra-delivery',4,
  pg_catalog.jsonb_build_object('dispatch_trip_id',(select id_value from h3_ids where id_name='trip'),
    'completed_at','2026-07-17T01:30:00+00:00')
)));
reset role;
delete from atlas_dispatch.delivery_confirmation_lines
where delivery_confirmation_id='a7800000-0000-0000-0000-000000000010';
delete from atlas_dispatch.delivery_confirmations
where delivery_confirmation_id='a7800000-0000-0000-0000-000000000010';

insert into atlas_procurement.fulfilment_allocation_revisions (
  fulfilment_allocation_revision_id,fulfilment_allocation_id,revision_number,revision_kind,
  revision_status,is_current,predecessor_revision_id,allocated_by_actor_id
) values (
  'a7800000-0000-0000-0000-000000000020',(select id_value from h3_ids where id_name='allocation'),
  2,'SUPERSEDING','READY_FOR_DISPATCH',false,(select id_value from h3_ids where id_name='allocation_revision'),
  'a7000000-0000-0000-0000-000000000001'
);
insert into atlas_dispatch.dispatch_loads (
  dispatch_load_id,dispatch_trip_id,dispatch_requirement_revision_id,
  fulfilment_allocation_revision_id,load_status,loaded_by_actor_id,loaded_at,version
) values (
  'a7800000-0000-0000-0000-000000000021',(select id_value from h3_ids where id_name='trip'),
  (select id_value from h3_ids where id_name='requirement_revision'),
  'a7800000-0000-0000-0000-000000000020','CONFIRMED',
  'a7000000-0000-0000-0000-000000000001',timestamptz '2026-07-17 00:50:00+00',1
);
set local role authenticated;
select set_config('request.jwt.claim.sub','a7000000-0000-0000-0000-000000000101',true);
insert into h3_results values ('extra-load',atlas_api.close_successful_trip(pg_temp.h3_request(
  'PA-05B-H3.v1','a7900000-0000-0000-0000-000000000622','h3-extra-load',4,
  pg_catalog.jsonb_build_object('dispatch_trip_id',(select id_value from h3_ids where id_name='trip'),
    'completed_at','2026-07-17T01:30:00+00:00')
)));
reset role;
delete from atlas_dispatch.dispatch_loads where dispatch_load_id='a7800000-0000-0000-0000-000000000021';
delete from atlas_procurement.fulfilment_allocation_revisions
where fulfilment_allocation_revision_id='a7800000-0000-0000-0000-000000000020';

select throws_ok(
  $$insert into atlas_dispatch.delivery_confirmations (
      dispatch_stop_id,revision_number,delivery_outcome,confirmation_status,
      confirmed_by_actor_id,confirmed_at,command_id,correlation_id
    ) values (
      (select id_value from h3_ids where id_name='stop'),2,'DELIVERED','VALID',
      'a7000000-0000-0000-0000-000000000001',timestamptz '2026-07-17 01:16:00+00',
      'a7800000-0000-0000-0000-000000000013','a7900000-0000-0000-0000-000000000001'
    )$$,
  '23505','duplicate key value violates unique constraint "delivery_confirmations_valid_stop_key"',
  'database uniqueness prevents duplicate current successful confirmations'
);
select throws_ok(
  $$insert into atlas_dispatch.dispatch_loads (
      dispatch_trip_id,dispatch_requirement_revision_id,fulfilment_allocation_revision_id,
      load_status,loaded_by_actor_id,loaded_at,version
    ) values (
      (select id_value from h3_ids where id_name='trip'),
      (select id_value from h3_ids where id_name='requirement_revision'),
      (select id_value from h3_ids where id_name='allocation_revision'),
      'CONFIRMED','a7000000-0000-0000-0000-000000000001',timestamptz '2026-07-17 00:55:00+00',1
    )$$,
  '23505','duplicate key value violates unique constraint "dispatch_loads_scope_key"',
  'database uniqueness prevents duplicate exact current load roots'
);
select throws_ok(
  $$insert into atlas_dispatch.delivery_confirmation_lines (
      delivery_confirmation_id,dispatch_load_line_id,delivered_quantity,returned_quantity,exception_quantity,unit_id
    ) select dc.delivery_confirmation_id,(select id_value from h3_ids where id_name='load_line'),10,0,0,
             'a7300000-0000-0000-0000-000000000021'
      from atlas_dispatch.delivery_confirmations dc
      where dc.dispatch_stop_id=(select id_value from h3_ids where id_name='stop')$$,
  '23505','duplicate key value violates unique constraint "delivery_confirmation_lines_confirmation_load_key"',
  'database uniqueness prevents duplicate current delivery lines'
);

-- A receipt trigger simulates authorization changing after the pre-check but
-- before post-lock revalidation. The command must roll the trigger change and
-- receipt back, returning the retryable public error with no partial facts.
create function pg_temp.h3_revoke_scope_after_receipt()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.command_id='a7900000-0000-0000-0000-000000000623'::uuid then
    delete from atlas_core.actor_scopes
    where actor_id='a7000000-0000-0000-0000-000000000001'::uuid and scope_kind='GLOBAL';
  end if;
  return new;
end
$$;
create trigger h3_revoke_scope_after_receipt
after insert on atlas_core.command_receipts
for each row execute function pg_temp.h3_revoke_scope_after_receipt();

set local role authenticated;
select set_config('request.jwt.claim.sub','a7000000-0000-0000-0000-000000000101',true);
insert into h3_results values ('post-lock-auth-change',atlas_api.close_successful_trip(pg_temp.h3_request(
  'PA-05B-H3.v1','a7900000-0000-0000-0000-000000000623','h3-post-lock-auth',4,
  pg_catalog.jsonb_build_object('dispatch_trip_id',(select id_value from h3_ids where id_name='trip'),
    'completed_at','2026-07-17T01:30:00+00:00')
)));
reset role;
drop trigger h3_revoke_scope_after_receipt on atlas_core.command_receipts;

select ok(
  (select trip_status='DELIVERED' and completed_at is null and version=4
   from atlas_dispatch.dispatch_trips where dispatch_trip_id=(select id_value from h3_ids where id_name='trip')),
  'every failed closure leaves the delivered trip uncompleted at version 4'
);

set local role authenticated;
select set_config('request.jwt.claim.sub','a7000000-0000-0000-0000-000000000101',true);
insert into h3_results values ('closure',atlas_api.close_successful_trip(pg_temp.h3_request(
  'PA-05B-H3.v1','a7900000-0000-0000-0000-000000000601','h3-closure',4,
  pg_catalog.jsonb_build_object(
    'dispatch_trip_id',(select id_value from h3_ids where id_name='trip'),
    'completed_at','2026-07-17T01:30:00+00:00'
  )
)));
insert into h3_results values ('closure-replay',atlas_api.close_successful_trip(pg_temp.h3_request(
  'PA-05B-H3.v1','a7900000-0000-0000-0000-000000000601','h3-closure',4,
  pg_catalog.jsonb_build_object(
    'dispatch_trip_id',(select id_value from h3_ids where id_name='trip'),
    'completed_at','2026-07-17T01:30:00+00:00'
  )
)));
insert into h3_results values ('closure-conflict',atlas_api.close_successful_trip(pg_temp.h3_request(
  'PA-05B-H3.v1','a7900000-0000-0000-0000-000000000602','h3-closure',4,
  pg_catalog.jsonb_build_object(
    'dispatch_trip_id',(select id_value from h3_ids where id_name='trip'),
    'completed_at','2026-07-17T01:31:00+00:00'
  )
)));
insert into h3_results values ('already-completed',atlas_api.close_successful_trip(pg_temp.h3_request(
  'PA-05B-H3.v1','a7900000-0000-0000-0000-000000000603','h3-already-completed',5,
  pg_catalog.jsonb_build_object(
    'dispatch_trip_id',(select id_value from h3_ids where id_name='trip'),
    'completed_at','2026-07-17T01:31:00+00:00'
  )
)));
reset role;

select is((select response_payload->>'error_code' from h3_results where result_name='malformed'),
  'VALIDATION_FAILED','malformed closure envelope fails before mutation');
select is((select response_payload->>'error_code' from h3_results where result_name='stale'),
  'STALE_VERSION','stale trip version fails deterministically');
select is((select response_payload->>'error_code' from h3_results where result_name='timestamp-before-confirmation'),
  'TRIP_RECONCILIATION_FAILED','completion before the successful confirmation is rejected');
select is((select response_payload->>'error_code' from h3_results where result_name='future-completion'),
  'VALIDATION_FAILED','future completion time fails exact envelope validation');
select is((select response_payload->>'error_code' from h3_results where result_name='unknown-field'),
  'VALIDATION_FAILED','unknown closure envelope fields fail exact allowlist validation');
select is((select response_payload->>'error_code' from h3_results where result_name='no-stops'),
  'TRIP_RECONCILIATION_FAILED','a delivered-looking trip with no stops cannot close');
select is((select response_payload->>'error_code' from h3_results where result_name='capability-denied'),
  'CAPABILITY_DENIED','closure requires the dedicated Dispatch capability');
select is((select response_payload->>'error_code' from h3_results where result_name='partial-scope'),
  'SCOPE_DENIED','closure requires authorization for every authoritative destination');
select is((select response_payload->>'error_code' from h3_results where result_name='not-delivered'),
  'TRIP_NOT_READY','a non-delivered trip cannot close');
select is((select response_payload->>'error_code' from h3_results where result_name='missing-assignment'),
  'TRIP_NOT_READY','closure requires a driver or vehicle assignment');
select is((select response_payload->>'error_code' from h3_results where result_name='inactive-assignment'),
  'TRIP_NOT_READY','an inactive assigned driver blocks closure');
select is((select response_payload->>'error_code' from h3_results where result_name='incomplete-stop'),
  'TRIP_RECONCILIATION_FAILED','every trip stop must be delivered');
select is((select response_payload->>'error_code' from h3_results where result_name='missing-current-load'),
  'TRIP_RECONCILIATION_FAILED','a voided or missing current confirmed load blocks closure');
select is((select response_payload->>'error_code' from h3_results where result_name='missing-current-delivery'),
  'TRIP_RECONCILIATION_FAILED','a voided or missing current successful confirmation blocks closure');
select is((select response_payload->>'error_code' from h3_results where result_name='line-corruption'),
  'DELIVERY_RECONCILIATION_FAILED','line quantity corruption fails exact reconciliation');
select is((select response_payload->>'error_code' from h3_results where result_name='extra-delivery'),
  'TRIP_RECONCILIATION_FAILED','an extra current delivery confirmation blocks closure');
select is((select response_payload->>'error_code' from h3_results where result_name='extra-load'),
  'TRIP_RECONCILIATION_FAILED','an extra Dispatch load root blocks closure');
select is((select response_payload->>'error_code' from h3_results where result_name='post-lock-auth-change'),
  'RETRYABLE_CONCURRENCY_FAILURE','post-lock authorization change returns the retryable public error');
select is(
  (select count(*)::integer from atlas_audit.domain_events
   where command_id between 'a7900000-0000-0000-0000-000000000610'::uuid
                        and 'a7900000-0000-0000-0000-000000000626'::uuid),
  0,'failed closure probes emit no domain event'
);
select is(
  (select count(*)::integer from atlas_audit.audit_events
   where command_id between 'a7900000-0000-0000-0000-000000000610'::uuid
                        and 'a7900000-0000-0000-0000-000000000626'::uuid),
  0,'failed closure probes emit no audit event'
);
select ok(
  not exists (select 1 from atlas_core.command_receipts where command_id in (
    'a7900000-0000-0000-0000-000000000613','a7900000-0000-0000-0000-000000000623',
    'a7900000-0000-0000-0000-000000000624','a7900000-0000-0000-0000-000000000625',
    'a7900000-0000-0000-0000-000000000626'
  ))
  and exists (
    select 1 from atlas_core.actor_scopes
    where actor_id='a7000000-0000-0000-0000-000000000001' and scope_kind='GLOBAL'
  ),
  'pre-receipt scope denial and post-lock retry leave no receipt and roll authorization back'
);
select ok(
  not exists (
    select 1 from h3_results
    where result_name in ('malformed','stale','timestamp-before-confirmation','future-completion','unknown-field',
      'no-stops','capability-denied','partial-scope',
      'not-delivered','missing-assignment','inactive-assignment','incomplete-stop','missing-current-load',
      'missing-current-delivery','line-corruption','extra-delivery','extra-load','post-lock-auth-change')
      and response_payload ?| array['sqlstate','sqlerrm','table_name','schema_name','internal_query']
  ),
  'all closure failures expose no internal database details'
);

select ok(
  not exists (
    select 1 from h3_results
    where result_name in ('source','release','handoff','requirement','allocation','purchase-order',
      'evidence','application','plan','trip','load','departure','delivery','closure')
      and coalesce((response_payload->>'success')::boolean,false) is not true
  ),
  'the complete command-authored PA-05D through PA-05B-H3 journey succeeds'
);
select is(
  (select response_payload from h3_results where result_name='closure-replay'),
  (select response_payload from h3_results where result_name='closure'),
  'exact closure replay returns the original response and IDs'
);
select is(
  (select response_payload->>'error_code' from h3_results where result_name='closure-conflict'),
  'IDEMPOTENCY_CONFLICT',
  'same closure idempotency key with a changed request conflicts'
);
select is(
  (select response_payload->>'error_code' from h3_results where result_name='already-completed'),
  'TRIP_NOT_READY',
  'a new command cannot close an already completed trip again'
);
select ok(
  not exists (select 1 from atlas_audit.domain_events where command_id='a7900000-0000-0000-0000-000000000603')
  and not exists (select 1 from atlas_audit.audit_events where command_id='a7900000-0000-0000-0000-000000000603'),
  'already-completed rejection emits no event or audit fact'
);
select ok(
  (select trip_status='DELIVERED' and completed_at=timestamptz '2026-07-17 01:30:00+00' and version=5
   from atlas_dispatch.dispatch_trips where dispatch_trip_id=(select id_value from h3_ids where id_name='trip')),
  'closure preserves DELIVERED, stamps completed_at, and increments the trip version once'
);
select is(
  (select count(*)::integer from atlas_audit.domain_events
   where command_id='a7900000-0000-0000-0000-000000000601'),
  1,
  'closure emits exactly one SuccessfulDispatchTripClosed domain event'
);
select is(
  (select count(*)::integer from atlas_audit.audit_events
   where command_id='a7900000-0000-0000-0000-000000000601'),
  1,
  'closure emits exactly one matching audit event'
);
select ok(
  exists (
    select 1 from atlas_core.command_receipts cr
    join atlas_audit.domain_events de on de.command_receipt_id=cr.command_receipt_id
    join atlas_audit.audit_events ae on ae.command_receipt_id=cr.command_receipt_id
    where cr.command_id='a7900000-0000-0000-0000-000000000601'
      and cr.command_name='close_successful_trip' and cr.outcome='COMPLETED'
      and de.event_type='SuccessfulDispatchTripClosed'
      and ae.event_type='SuccessfulDispatchTripClosed'
  ),
  'closure receipt, domain event, and audit event share one atomic identity'
);
select is(
  (select count(*)::integer from atlas_dispatch.dispatch_loads dl
   where dl.dispatch_trip_id=(select id_value from h3_ids where id_name='trip')),
  1,
  'closure does not add or mutate Dispatch load facts'
);
select is(
  (select count(*)::integer from atlas_dispatch.delivery_confirmations dc
   join atlas_dispatch.dispatch_stops ds on ds.dispatch_stop_id=dc.dispatch_stop_id
   where ds.dispatch_trip_id=(select id_value from h3_ids where id_name='trip')),
  1,
  'closure does not add or mutate delivery confirmation facts'
);

select * from finish();
rollback;
