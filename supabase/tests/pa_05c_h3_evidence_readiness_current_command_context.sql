begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
select plan(35);

grant usage on schema extensions to authenticated;
grant execute on all functions in schema extensions to authenticated;

-- Structural READ-02 contract and least-privilege boundary.
select ok(
  not has_function_privilege('anon', 'atlas_api.get_dispatch_evidence_readiness(jsonb)', 'EXECUTE'),
  'anon cannot execute READ-02'
);
select ok(
  not has_function_privilege('service_role', 'atlas_api.get_dispatch_evidence_readiness(jsonb)', 'EXECUTE'),
  'service_role cannot execute READ-02'
);
select ok(
  has_function_privilege('authenticated', 'atlas_api.get_dispatch_evidence_readiness(jsonb)', 'EXECUTE'),
  'authenticated retains shaped READ-02 execution'
);
select ok(
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    join pg_roles r on r.oid = p.proowner
    where n.nspname = 'atlas_api'
      and p.proname = 'get_dispatch_evidence_readiness'
      and pg_get_function_identity_arguments(p.oid) = 'request jsonb'
      and p.prosecdef
      and p.provolatile = 's'
      and r.rolname = 'atlas_read_runtime'
      and p.proconfig::text like '%search_path=%'
      and pg_get_functiondef(p.oid) !~* '\mexecute\M'
      and pg_get_functiondef(p.oid) !~* '\mformat\s*\('
  ),
  'READ-02 remains stable security-definer, read-runtime-owned, fixed-search-path, and static SQL'
);
select ok(
  not exists (
    select 1
    from information_schema.role_table_grants g
    where g.grantee = 'atlas_read_runtime'
      and g.table_schema like 'atlas\_%' escape '\'
      and g.privilege_type <> 'SELECT'
  )
  and not has_schema_privilege('atlas_read_runtime', 'atlas_procurement', 'CREATE')
  and not pg_has_role('atlas_read_runtime', 'atlas_command_runtime', 'MEMBER')
  and not exists (
    select 1
    from pg_auth_members membership
    join pg_roles granted_role on granted_role.oid = membership.roleid
    join pg_roles member_role on member_role.oid = membership.member
    where granted_role.rolname = 'atlas_read_runtime'
      and member_role.rolname = 'postgres'
      and membership.set_option
  ),
  'atlas_read_runtime remains SELECT-only without schema-CREATE or command-runtime authority'
);
-- Rolled-back authorization fixture.
insert into atlas_core.actors
  (actor_id, actor_type, display_name, actor_status, deactivated_at) values
  ('15800000-0000-0000-0000-000000000001', 'HUMAN', 'PA-05C-H3 operator', 'ACTIVE', null),
  ('15800000-0000-0000-0000-000000000004', 'HUMAN', 'PA-05C-H3 no capability', 'ACTIVE', null),
  ('15800000-0000-0000-0000-000000000005', 'HUMAN', 'PA-05C-H3 wrong scope', 'ACTIVE', null);

insert into atlas_core.actor_auth_subjects
  (actor_auth_subject_id, actor_id, auth_subject_id, subject_status, revoked_at) values
  ('15800000-0000-0000-0000-000000000011', '15800000-0000-0000-0000-000000000001', '15800000-0000-0000-0000-000000000101', 'ACTIVE', null),
  ('15800000-0000-0000-0000-000000000014', '15800000-0000-0000-0000-000000000004', '15800000-0000-0000-0000-000000000104', 'ACTIVE', null),
  ('15800000-0000-0000-0000-000000000015', '15800000-0000-0000-0000-000000000005', '15800000-0000-0000-0000-000000000105', 'ACTIVE', null);

insert into atlas_core.roles (role_id, role_code, role_name) values
  ('15810000-0000-0000-0000-000000000001', 'pa05c_h3.operator', 'PA-05C-H3 operator'),
  ('15810000-0000-0000-0000-000000000002', 'pa05c_h3.none', 'PA-05C-H3 no capability');

insert into atlas_core.capabilities
  (capability_id, capability_code, capability_name, owning_domain) values
  ('15820000-0000-0000-0000-000000000001', 'dispatch_evidence_readiness.read', 'Read Evidence readiness', 'DISPATCH'),
  ('15820000-0000-0000-0000-000000000002', 'supplier_receiving_evidence.record', 'Record supplier Evidence', 'EVIDENCE'),
  ('15820000-0000-0000-0000-000000000003', 'supplier_evidence_application.apply', 'Apply supplier Evidence', 'EVIDENCE');

insert into atlas_core.role_capabilities (role_id, capability_id)
select '15810000-0000-0000-0000-000000000001'::uuid, capability_id
from atlas_core.capabilities
where capability_code in (
  'dispatch_evidence_readiness.read',
  'supplier_receiving_evidence.record',
  'supplier_evidence_application.apply'
);

insert into atlas_core.actor_role_memberships (actor_id, role_id) values
  ('15800000-0000-0000-0000-000000000001', '15810000-0000-0000-0000-000000000001'),
  ('15800000-0000-0000-0000-000000000004', '15810000-0000-0000-0000-000000000002'),
  ('15800000-0000-0000-0000-000000000005', '15810000-0000-0000-0000-000000000001');

insert into atlas_admin.customers (customer_id, customer_code, customer_name) values
  ('25800000-0000-0000-0000-000000000100', 'pa05c-h3-customer', 'PA-05C-H3 customer'),
  ('25800000-0000-0000-0000-000000000110', 'pa05c-h3-other', 'PA-05C-H3 other customer');
insert into atlas_admin.delivery_locations
  (delivery_location_id, customer_id, location_code, location_name, address_text) values
  ('25800000-0000-0000-0000-000000000101', '25800000-0000-0000-0000-000000000100', 'pa05c-h3-location', 'PA-05C-H3 location', 'Test address'),
  ('25800000-0000-0000-0000-000000000111', '25800000-0000-0000-0000-000000000110', 'pa05c-h3-other', 'PA-05C-H3 other', 'Other address');
insert into atlas_admin.units (unit_id, unit_code, unit_name, dimension_code) values
  ('25800000-0000-0000-0000-000000000102', 'pa05c-h3-kg', 'PA-05C-H3 kilogram', 'mass');
insert into atlas_admin.ingredients (ingredient_id, ingredient_code, ingredient_name) values
  ('25800000-0000-0000-0000-000000000103', 'pa05c-h3-rice', 'PA-05C-H3 rice'),
  ('25800000-0000-0000-0000-000000000113', 'pa05c-h3-bean', 'PA-05C-H3 bean');
insert into atlas_admin.suppliers (supplier_id, supplier_code, supplier_name) values
  ('25800000-0000-0000-0000-000000000104', 'pa05c-h3-supplier', 'PA-05C-H3 supplier');

insert into atlas_core.actor_scopes (actor_id, scope_kind) values
  ('15800000-0000-0000-0000-000000000001', 'GLOBAL'),
  ('15800000-0000-0000-0000-000000000004', 'GLOBAL');
insert into atlas_core.actor_scopes (actor_id, scope_kind, customer_id) values
  ('15800000-0000-0000-0000-000000000005', 'CUSTOMER', '25800000-0000-0000-0000-000000000110');

-- One complete supplier-direct source, allocation, PO, and dispatch lineage.
insert into atlas_planning.wholesale_orders
  (wholesale_order_id, customer_id, delivery_location_id, customer_order_reference, service_date, order_status, created_by_actor_id) values
  ('35800000-0000-0000-0000-000000000200', '25800000-0000-0000-0000-000000000100', '25800000-0000-0000-0000-000000000101', 'PA05C-H3-ORDER-001', date '2026-07-18', 'RELEASED', '15800000-0000-0000-0000-000000000001');
insert into atlas_planning.wholesale_order_lines
  (wholesale_order_line_id, wholesale_order_id, source_line_number) values
  ('35800000-0000-0000-0000-000000000201', '35800000-0000-0000-0000-000000000200', 1);
insert into atlas_planning.wholesale_order_line_revisions
  (wholesale_order_line_revision_id, wholesale_order_line_id, revision_number, ingredient_id, requested_quantity, unit_id, revision_status, created_by_actor_id) values
  ('35800000-0000-0000-0000-000000000202', '35800000-0000-0000-0000-000000000201', 1, '25800000-0000-0000-0000-000000000103', 10, '25800000-0000-0000-0000-000000000102', 'RELEASED', '15800000-0000-0000-0000-000000000001');
insert into atlas_planning.confirmed_need_batches
  (confirmed_need_batch_id, wholesale_order_id, period_start, period_end, batch_status, created_by_actor_id) values
  ('35800000-0000-0000-0000-000000000300', '35800000-0000-0000-0000-000000000200', date '2026-07-18', date '2026-07-18', 'RELEASED_FOR_PURCHASE_HANDOFF', '15800000-0000-0000-0000-000000000001');
insert into atlas_planning.confirmed_need_lines
  (confirmed_need_line_id, confirmed_need_batch_id, wholesale_order_line_id) values
  ('35800000-0000-0000-0000-000000000301', '35800000-0000-0000-0000-000000000300', '35800000-0000-0000-0000-000000000201');
insert into atlas_planning.confirmed_need_line_revisions
  (confirmed_need_line_revision_id, confirmed_need_line_id, revision_number, wholesale_order_line_revision_id, ingredient_id, theoretical_quantity, confirmed_quantity, unit_id, revision_status, created_by_actor_id) values
  ('35800000-0000-0000-0000-000000000302', '35800000-0000-0000-0000-000000000301', 1, '35800000-0000-0000-0000-000000000202', '25800000-0000-0000-0000-000000000103', 10, 10, '25800000-0000-0000-0000-000000000102', 'RELEASED', '15800000-0000-0000-0000-000000000001');
insert into atlas_planning.purchase_handoff_batches
  (purchase_handoff_batch_id, confirmed_need_batch_id, period_start, period_end, handoff_status, created_by_actor_id) values
  ('35800000-0000-0000-0000-000000000400', '35800000-0000-0000-0000-000000000300', date '2026-07-18', date '2026-07-18', 'RELEASED_TO_PROCUREMENT', '15800000-0000-0000-0000-000000000001');
insert into atlas_planning.purchase_handoff_revisions
  (purchase_handoff_revision_id, purchase_handoff_batch_id, revision_number, revision_status, released_by_actor_id, released_at) values
  ('35800000-0000-0000-0000-000000000401', '35800000-0000-0000-0000-000000000400', 1, 'RELEASED_TO_PROCUREMENT', '15800000-0000-0000-0000-000000000001', timestamptz '2026-07-18 00:10:00+00');
insert into atlas_planning.purchase_handoff_lines
  (purchase_handoff_line_id, purchase_handoff_batch_id, confirmed_need_line_id) values
  ('35800000-0000-0000-0000-000000000402', '35800000-0000-0000-0000-000000000400', '35800000-0000-0000-0000-000000000301');
insert into atlas_planning.purchase_handoff_line_revisions
  (purchase_handoff_line_revision_id, purchase_handoff_revision_id, purchase_handoff_line_id, confirmed_need_line_revision_id, ingredient_id, handoff_quantity, unit_id, service_date, delivery_location_id) values
  ('35800000-0000-0000-0000-000000000403', '35800000-0000-0000-0000-000000000401', '35800000-0000-0000-0000-000000000402', '35800000-0000-0000-0000-000000000302', '25800000-0000-0000-0000-000000000103', 10, '25800000-0000-0000-0000-000000000102', date '2026-07-18', '25800000-0000-0000-0000-000000000101');
insert into atlas_planning.dispatch_requirements
  (dispatch_requirement_id, customer_id, delivery_location_id, service_date, requirement_status) values
  ('35800000-0000-0000-0000-000000000500', '25800000-0000-0000-0000-000000000100', '25800000-0000-0000-0000-000000000101', date '2026-07-18', 'RELEASED');
insert into atlas_planning.dispatch_requirement_revisions
  (dispatch_requirement_revision_id, dispatch_requirement_id, purchase_handoff_revision_id, revision_number, revision_status, customer_name_snapshot, location_name_snapshot, address_snapshot, released_by_actor_id, released_at) values
  ('35800000-0000-0000-0000-000000000501', '35800000-0000-0000-0000-000000000500', '35800000-0000-0000-0000-000000000401', 1, 'RELEASED', 'PA-05C-H3 customer', 'PA-05C-H3 location', 'Test address', '15800000-0000-0000-0000-000000000001', timestamptz '2026-07-18 00:20:00+00');
insert into atlas_planning.dispatch_requirement_lines
  (dispatch_requirement_line_id, dispatch_requirement_id, purchase_handoff_line_id) values
  ('35800000-0000-0000-0000-000000000502', '35800000-0000-0000-0000-000000000500', '35800000-0000-0000-0000-000000000402');
insert into atlas_planning.dispatch_requirement_line_revisions
  (dispatch_requirement_line_revision_id, dispatch_requirement_revision_id, dispatch_requirement_line_id, purchase_handoff_line_revision_id, ingredient_id, required_quantity, unit_id) values
  ('35800000-0000-0000-0000-000000000503', '35800000-0000-0000-0000-000000000501', '35800000-0000-0000-0000-000000000502', '35800000-0000-0000-0000-000000000403', '25800000-0000-0000-0000-000000000103', 10, '25800000-0000-0000-0000-000000000102');

insert into atlas_procurement.fulfilment_allocations
  (fulfilment_allocation_id, dispatch_requirement_id, allocation_status) values
  ('45800000-0000-0000-0000-000000000600', '35800000-0000-0000-0000-000000000500', 'READY_FOR_DISPATCH');
insert into atlas_procurement.fulfilment_allocation_revisions
  (fulfilment_allocation_revision_id, fulfilment_allocation_id, revision_number, revision_status, allocated_by_actor_id) values
  ('45800000-0000-0000-0000-000000000601', '45800000-0000-0000-0000-000000000600', 1, 'READY_FOR_DISPATCH', '15800000-0000-0000-0000-000000000001');
insert into atlas_procurement.fulfilment_allocation_lines
  (fulfilment_allocation_line_id, fulfilment_allocation_id, dispatch_requirement_line_id, portion_sequence) values
  ('45800000-0000-0000-0000-000000000602', '45800000-0000-0000-0000-000000000600', '35800000-0000-0000-0000-000000000502', 1);
insert into atlas_procurement.fulfilment_allocation_line_revisions
  (fulfilment_allocation_line_revision_id, fulfilment_allocation_revision_id, fulfilment_allocation_line_id, dispatch_requirement_line_revision_id, supplier_id, allocated_quantity, unit_id, line_status) values
  ('45800000-0000-0000-0000-000000000603', '45800000-0000-0000-0000-000000000601', '45800000-0000-0000-0000-000000000602', '35800000-0000-0000-0000-000000000503', '25800000-0000-0000-0000-000000000104', 6, '25800000-0000-0000-0000-000000000102', 'READY_FOR_EVIDENCE');

insert into atlas_procurement.purchase_orders
  (purchase_order_id, supplier_id, document_number, purchase_order_status) values
  ('45800000-0000-0000-0000-000000000700', '25800000-0000-0000-0000-000000000104', 'PA05C-H3-PO-001', 'RELEASED_TO_SUPPLIER');
insert into atlas_procurement.purchase_order_revisions
  (purchase_order_revision_id, purchase_order_id, revision_number, revision_status, service_date, delivery_location_id, supplier_name_snapshot, delivery_location_snapshot, released_by_actor_id, released_at) values
  ('45800000-0000-0000-0000-000000000701', '45800000-0000-0000-0000-000000000700', 1, 'RELEASED_TO_SUPPLIER', date '2026-07-18', '25800000-0000-0000-0000-000000000101', 'PA-05C-H3 supplier', 'PA-05C-H3 location', '15800000-0000-0000-0000-000000000001', timestamptz '2026-07-18 00:25:00+00');
insert into atlas_procurement.purchase_order_lines
  (purchase_order_line_id, purchase_order_id, fulfilment_allocation_line_id) values
  ('45800000-0000-0000-0000-000000000702', '45800000-0000-0000-0000-000000000700', '45800000-0000-0000-0000-000000000602');
insert into atlas_procurement.purchase_order_line_revisions
  (purchase_order_line_revision_id, purchase_order_revision_id, purchase_order_line_id, fulfilment_allocation_line_revision_id, ingredient_id, ordered_quantity, unit_id, delivery_location_id, service_date) values
  ('45800000-0000-0000-0000-000000000703', '45800000-0000-0000-0000-000000000701', '45800000-0000-0000-0000-000000000702', '45800000-0000-0000-0000-000000000603', '25800000-0000-0000-0000-000000000103', 6, '25800000-0000-0000-0000-000000000102', '25800000-0000-0000-0000-000000000101', date '2026-07-18');

insert into atlas_dispatch.dispatch_plans
  (dispatch_plan_id, plan_reference, service_date, created_by_actor_id) values
  ('55800000-0000-0000-0000-000000000900', 'PA05C-H3-PLAN-001', date '2026-07-18', '15800000-0000-0000-0000-000000000001');
insert into atlas_dispatch.dispatch_plan_requirements
  (dispatch_plan_requirement_id, dispatch_plan_id, dispatch_requirement_revision_id, fulfilment_allocation_revision_id) values
  ('55800000-0000-0000-0000-000000000901', '55800000-0000-0000-0000-000000000900', '35800000-0000-0000-0000-000000000501', '45800000-0000-0000-0000-000000000601');
insert into atlas_dispatch.dispatch_trips
  (dispatch_trip_id, dispatch_plan_id, trip_reference, trip_status, driver_actor_id) values
  ('55800000-0000-0000-0000-000000000902', '55800000-0000-0000-0000-000000000900', 'PA05C-H3-TRIP-001', 'PLANNED', '15800000-0000-0000-0000-000000000001');
insert into atlas_dispatch.dispatch_stops
  (dispatch_stop_id, dispatch_trip_id, stop_sequence, dispatch_requirement_revision_id, customer_id, delivery_location_id, stop_status) values
  ('55800000-0000-0000-0000-000000000903', '55800000-0000-0000-0000-000000000902', 1, '35800000-0000-0000-0000-000000000501', '25800000-0000-0000-0000-000000000100', '25800000-0000-0000-0000-000000000101', 'PENDING');

create function pg_temp.pa05c_h3_read_request(subject uuid, payload jsonb)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'contract_version', 'PA-05C.v1',
    'requested_by_auth_subject', subject,
    'correlation_id', '95800000-0000-0000-0000-000000000099'::uuid,
    'payload', payload
  )
$$;

create function pg_temp.pa05c_h3_command_request(
  command_id uuid,
  idempotency_key text,
  expected_version bigint,
  payload jsonb
)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'contract_version', 'PA-05B.v1',
    'command_id', command_id,
    'correlation_id', '95800000-0000-0000-0000-000000000099'::uuid,
    'idempotency_key', idempotency_key,
    'expected_version', expected_version,
    'requested_by_auth_subject', '15800000-0000-0000-0000-000000000101'::uuid,
    'requested_at', '2026-07-18T00:30:00+00:00',
    'reason_code', 'PA05C_H3_TEST',
    'reason_note', 'PA-05C-H3 rolled-back pgTAP',
    'payload', payload
  )
$$;

create temporary table pa05c_h3_results (
  result_name text primary key,
  response_payload jsonb not null
) on commit drop;
grant select, insert on pa05c_h3_results to authenticated;

-- Existing selectors, authorization, response fields, and the one-commitment shape.
set local role authenticated;
select set_config('request.jwt.claim.sub', '15800000-0000-0000-0000-000000000101', true);
insert into pa05c_h3_results values
  ('source_initial', atlas_api.get_dispatch_evidence_readiness(pg_temp.pa05c_h3_read_request(
    '15800000-0000-0000-0000-000000000101',
    jsonb_build_object('wholesale_order_line_revision_id', '35800000-0000-0000-0000-000000000202')
  ))),
  ('requirement_initial', atlas_api.get_dispatch_evidence_readiness(pg_temp.pa05c_h3_read_request(
    '15800000-0000-0000-0000-000000000101',
    jsonb_build_object('dispatch_requirement_revision_id', '35800000-0000-0000-0000-000000000501')
  ))),
  ('trip_initial', atlas_api.get_dispatch_evidence_readiness(pg_temp.pa05c_h3_read_request(
    '15800000-0000-0000-0000-000000000101',
    jsonb_build_object('dispatch_trip_id', '55800000-0000-0000-0000-000000000902')
  )));
reset role;

select ok(
  (select bool_and((response_payload ->> 'success')::boolean)
   from pa05c_h3_results
   where result_name in ('source_initial', 'requirement_initial', 'trip_initial')),
  'READ-02 retains all three bounded selectors and authorized execution'
);
select ok(
  (select response_payload -> 'readiness_items' -> 0 ?& array[
    'trip_reference', 'dispatch_trip_id', 'trip_status', 'dispatch_stop_id',
    'stop_sequence', 'stop_status', 'dispatch_requirement_id',
    'dispatch_requirement_revision_id', 'dispatch_requirement_line_revision_id',
    'fulfilment_allocation_line_revision_id', 'unit_id', 'allocated_quantity',
    'loaded_quantity', 'applied_evidence_quantity', 'evidence_references',
    'evidence_status', 'evidence_application_status', 'readiness_status',
    'blockers', 'warnings'
  ] from pa05c_h3_results where result_name = 'source_initial'),
  'all existing readiness item fields remain present'
);
select is(
  (select response_payload ->> 'contract_version' from pa05c_h3_results where result_name = 'source_initial'),
  'PA-05C.v1',
  'READ-02 keeps PA-05C.v1'
);
select is(
  (select (response_payload ->> 'advisory_only')::boolean from pa05c_h3_results where result_name = 'source_initial'),
  true,
  'advisory_only remains true'
);
select is(
  (select response_payload -> 'readiness_items' -> 0 -> 'command_context' ->
    'fulfilment_allocation' ->> 'fulfilment_allocation_id'
   from pa05c_h3_results where result_name = 'source_initial'),
  '45800000-0000-0000-0000-000000000600',
  'current allocation root ID is returned'
);
select is(
  (select (response_payload -> 'readiness_items' -> 0 -> 'command_context' ->
    'fulfilment_allocation' ->> 'fulfilment_allocation_version')::bigint
   from pa05c_h3_results where result_name = 'source_initial'),
  1::bigint,
  'current allocation root version is returned directly'
);
select is(
  (select response_payload -> 'readiness_items' -> 0 -> 'command_context' ->
    'fulfilment_allocation' ->> 'fulfilment_allocation_revision_id'
   from pa05c_h3_results where result_name = 'source_initial'),
  '45800000-0000-0000-0000-000000000601',
  'current allocation revision is returned'
);
select is(
  (select response_payload -> 'readiness_items' -> 0 -> 'command_context' ->
    'fulfilment_allocation' ->> 'fulfilment_allocation_line_revision_id'
   from pa05c_h3_results where result_name = 'source_initial'),
  '45800000-0000-0000-0000-000000000603',
  'line revision belonging to the current allocation revision is returned'
);
select is(
  (select jsonb_array_length(response_payload -> 'readiness_items' -> 0 ->
    'command_context' -> 'purchase_commitments')
   from pa05c_h3_results where result_name = 'source_initial'),
  1,
  'one current purchase commitment is returned as one array item'
);
select ok(
  (select response_payload -> 'readiness_items' -> 0 -> 'command_context' ->
    'purchase_commitments' -> 0 @> jsonb_build_object(
      'purchase_order_id', '45800000-0000-0000-0000-000000000700',
      'purchase_order_version', 1,
      'purchase_order_revision_id', '45800000-0000-0000-0000-000000000701',
      'purchase_order_line_id', '45800000-0000-0000-0000-000000000702',
      'purchase_order_line_revision_id', '45800000-0000-0000-0000-000000000703'
    ) from pa05c_h3_results where result_name = 'source_initial'),
  'current PO root, direct version, revision, stable line, and line revision are returned'
);
select ok(
  (select response_payload -> 'readiness_items' -> 0 -> 'command_context' ->
    'fulfilment_allocation' @> jsonb_build_object(
      'supplier_id', '25800000-0000-0000-0000-000000000104',
      'ingredient_id', '25800000-0000-0000-0000-000000000103',
      'unit_id', '25800000-0000-0000-0000-000000000102',
      'allocated_quantity', 6
    ) from pa05c_h3_results where result_name = 'source_initial')
  and
  (select response_payload -> 'readiness_items' -> 0 -> 'command_context' ->
    'purchase_commitments' -> 0 @> jsonb_build_object(
      'supplier_id', '25800000-0000-0000-0000-000000000104',
      'ingredient_id', '25800000-0000-0000-0000-000000000103',
      'unit_id', '25800000-0000-0000-0000-000000000102',
      'ordered_quantity', 6,
      'service_date', '2026-07-18',
      'delivery_location_id', '25800000-0000-0000-0000-000000000101'
    ) from pa05c_h3_results where result_name = 'source_initial'),
  'allocation and PO supplier, ingredient, unit, quantity, date, and destination lineage is exact'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '15800000-0000-0000-0000-000000000104', true);
insert into pa05c_h3_results values
  ('capability_denied', atlas_api.get_dispatch_evidence_readiness(pg_temp.pa05c_h3_read_request(
    '15800000-0000-0000-0000-000000000104',
    jsonb_build_object('wholesale_order_line_revision_id', '35800000-0000-0000-0000-000000000202')
  )));
select set_config('request.jwt.claim.sub', '15800000-0000-0000-0000-000000000105', true);
insert into pa05c_h3_results values
  ('scope_denied', atlas_api.get_dispatch_evidence_readiness(pg_temp.pa05c_h3_read_request(
    '15800000-0000-0000-0000-000000000105',
    jsonb_build_object('wholesale_order_line_revision_id', '35800000-0000-0000-0000-000000000202')
  )));
reset role;
select is(
  (select response_payload ->> 'error_code' from pa05c_h3_results where result_name = 'capability_denied'),
  'CAPABILITY_DENIED',
  'missing readiness capability fails closed'
);
select is(
  (select response_payload ->> 'error_code' from pa05c_h3_results where result_name = 'scope_denied'),
  'SCOPE_DENIED',
  'out-of-scope readiness selection fails closed'
);

-- A second legitimate allocation portion and PO prove that commitments
-- across the selected readiness line are deterministic and not collapsed.
-- PA-05E deliberately permits at most one PO per stable allocation line.
insert into atlas_procurement.fulfilment_allocation_lines
  (fulfilment_allocation_line_id, fulfilment_allocation_id, dispatch_requirement_line_id, portion_sequence) values
  ('45800000-0000-0000-0000-000000000604', '45800000-0000-0000-0000-000000000600', '35800000-0000-0000-0000-000000000502', 2);
insert into atlas_procurement.fulfilment_allocation_line_revisions
  (fulfilment_allocation_line_revision_id, fulfilment_allocation_revision_id, fulfilment_allocation_line_id, dispatch_requirement_line_revision_id, supplier_id, allocated_quantity, unit_id, line_status) values
  ('45800000-0000-0000-0000-000000000605', '45800000-0000-0000-0000-000000000601', '45800000-0000-0000-0000-000000000604', '35800000-0000-0000-0000-000000000503', '25800000-0000-0000-0000-000000000104', 4, '25800000-0000-0000-0000-000000000102', 'READY_FOR_EVIDENCE');
insert into atlas_procurement.purchase_orders
  (purchase_order_id, supplier_id, document_number, purchase_order_status) values
  ('45800000-0000-0000-0000-000000000710', '25800000-0000-0000-0000-000000000104', 'PA05C-H3-PO-002', 'SUPPLIER_CONFIRMED');
insert into atlas_procurement.purchase_order_revisions
  (purchase_order_revision_id, purchase_order_id, revision_number, revision_status, service_date, delivery_location_id, supplier_name_snapshot, delivery_location_snapshot, released_by_actor_id, released_at) values
  ('45800000-0000-0000-0000-000000000711', '45800000-0000-0000-0000-000000000710', 1, 'SUPPLIER_CONFIRMED', date '2026-07-18', '25800000-0000-0000-0000-000000000101', 'PA-05C-H3 supplier', 'PA-05C-H3 location', '15800000-0000-0000-0000-000000000001', timestamptz '2026-07-18 00:26:00+00');
insert into atlas_procurement.purchase_order_lines
  (purchase_order_line_id, purchase_order_id, fulfilment_allocation_line_id) values
  ('45800000-0000-0000-0000-000000000712', '45800000-0000-0000-0000-000000000710', '45800000-0000-0000-0000-000000000604');
insert into atlas_procurement.purchase_order_line_revisions
  (purchase_order_line_revision_id, purchase_order_revision_id, purchase_order_line_id, fulfilment_allocation_line_revision_id, ingredient_id, ordered_quantity, unit_id, delivery_location_id, service_date) values
  ('45800000-0000-0000-0000-000000000713', '45800000-0000-0000-0000-000000000711', '45800000-0000-0000-0000-000000000712', '45800000-0000-0000-0000-000000000605', '25800000-0000-0000-0000-000000000103', 4, '25800000-0000-0000-0000-000000000102', '25800000-0000-0000-0000-000000000101', date '2026-07-18');

set local role authenticated;
select set_config('request.jwt.claim.sub', '15800000-0000-0000-0000-000000000101', true);
insert into pa05c_h3_results values
  ('multiple_commitments', atlas_api.get_dispatch_evidence_readiness(pg_temp.pa05c_h3_read_request(
    '15800000-0000-0000-0000-000000000101',
    jsonb_build_object('wholesale_order_line_revision_id', '35800000-0000-0000-0000-000000000202')
  )));
reset role;
select is(
  (select sum(jsonb_array_length(item -> 'command_context' -> 'purchase_commitments'))::integer
   from pa05c_h3_results r
   cross join lateral jsonb_array_elements(r.response_payload -> 'readiness_items') item
   where r.result_name = 'multiple_commitments'),
  2,
  'multiple legitimate current commitments across allocation portions are not collapsed'
);
select is(
  (select jsonb_path_query_array(
    response_payload,
    '$.readiness_items[*].command_context.purchase_commitments[*].purchase_order_id'
  ) from pa05c_h3_results where result_name = 'multiple_commitments'),
  '["45800000-0000-0000-0000-000000000700", "45800000-0000-0000-0000-000000000710"]'::jsonb,
  'multiple commitments are ordered deterministically by stable identifiers'
);

update atlas_procurement.purchase_orders
set purchase_order_status = 'CANCELLED'
where purchase_order_id in (
  '45800000-0000-0000-0000-000000000700',
  '45800000-0000-0000-0000-000000000710'
);
update atlas_procurement.purchase_order_revisions
set revision_status = 'CANCELLED'
where purchase_order_revision_id in (
  '45800000-0000-0000-0000-000000000701',
  '45800000-0000-0000-0000-000000000711'
);
set local role authenticated;
select set_config('request.jwt.claim.sub', '15800000-0000-0000-0000-000000000101', true);
insert into pa05c_h3_results values
  ('zero_commitments', atlas_api.get_dispatch_evidence_readiness(pg_temp.pa05c_h3_read_request(
    '15800000-0000-0000-0000-000000000101',
    jsonb_build_object('wholesale_order_line_revision_id', '35800000-0000-0000-0000-000000000202')
  )));
reset role;
select is(
  (select response_payload -> 'readiness_items' -> 0 -> 'command_context' -> 'purchase_commitments'
   from pa05c_h3_results where result_name = 'zero_commitments'),
  '[]'::jsonb,
  'zero active commitments are represented as a safe empty array'
);
select is(
  (select response_payload -> 'readiness_items' -> 0 ->> 'readiness_status'
   from pa05c_h3_results where result_name = 'zero_commitments'),
  'NOT_LOADED',
  'zero commitments preserve bounded readiness and blocker semantics'
);
update atlas_procurement.purchase_orders
set purchase_order_status = case purchase_order_id
  when '45800000-0000-0000-0000-000000000700' then 'RELEASED_TO_SUPPLIER'
  else 'SUPPLIER_CONFIRMED' end
where purchase_order_id in (
  '45800000-0000-0000-0000-000000000700',
  '45800000-0000-0000-0000-000000000710'
);
update atlas_procurement.purchase_order_revisions
set revision_status = case purchase_order_revision_id
  when '45800000-0000-0000-0000-000000000701' then 'RELEASED_TO_SUPPLIER'
  else 'SUPPLIER_CONFIRMED' end
where purchase_order_revision_id in (
  '45800000-0000-0000-0000-000000000701',
  '45800000-0000-0000-0000-000000000711'
);

-- Required Purchase Order stale-recovery proof: refresh from READ-02, never from actual_version.
update atlas_procurement.purchase_orders
set version = 2
where purchase_order_id = '45800000-0000-0000-0000-000000000700';
set local role authenticated;
select set_config('request.jwt.claim.sub', '15800000-0000-0000-0000-000000000101', true);
insert into pa05c_h3_results values
  ('po_stale', atlas_api.record_supplier_receiving_evidence(pg_temp.pa05c_h3_command_request(
    '95800000-0000-0000-0000-000000000201', 'pa05c-h3-po-stale', 1,
    jsonb_build_object(
      'purchase_order_line_revision_id', '45800000-0000-0000-0000-000000000703',
      'supplier_id', '25800000-0000-0000-0000-000000000104',
      'ingredient_id', '25800000-0000-0000-0000-000000000103',
      'unit_id', '25800000-0000-0000-0000-000000000102',
      'evidence_quantity', 4,
      'evidence_reference', 'PA05C-H3-STALE',
      'occurred_at', '2026-07-18T00:31:00+00:00'
    )
  ))),
  ('po_refresh', atlas_api.get_dispatch_evidence_readiness(pg_temp.pa05c_h3_read_request(
    '15800000-0000-0000-0000-000000000101',
    jsonb_build_object('wholesale_order_line_revision_id', '35800000-0000-0000-0000-000000000202')
  )));
reset role;
select is(
  (select response_payload ->> 'error_code' from pa05c_h3_results where result_name = 'po_stale'),
  'STALE_VERSION',
  'record Evidence rejects the retained stale PO version'
);
select is(
  (select (commitment ->> 'purchase_order_version')::bigint
   from pa05c_h3_results r
   cross join lateral jsonb_array_elements(
     r.response_payload -> 'readiness_items' -> 0 -> 'command_context' -> 'purchase_commitments'
   ) commitment
   where r.result_name = 'po_refresh'
     and commitment ->> 'purchase_order_id' = '45800000-0000-0000-0000-000000000700'),
  2::bigint,
  'READ-02 refresh returns the authoritative current PO version'
);
set local role authenticated;
select set_config('request.jwt.claim.sub', '15800000-0000-0000-0000-000000000101', true);
insert into pa05c_h3_results
select 'po_refreshed_command',
  atlas_api.record_supplier_receiving_evidence(pg_temp.pa05c_h3_command_request(
    '95800000-0000-0000-0000-000000000202', 'pa05c-h3-po-refreshed',
    (commitment ->> 'purchase_order_version')::bigint,
    jsonb_build_object(
      'purchase_order_line_revision_id', '45800000-0000-0000-0000-000000000703',
      'supplier_id', '25800000-0000-0000-0000-000000000104',
      'ingredient_id', '25800000-0000-0000-0000-000000000103',
      'unit_id', '25800000-0000-0000-0000-000000000102',
      'evidence_quantity', 4,
      'evidence_reference', 'PA05C-H3-REFRESHED',
      'occurred_at', '2026-07-18T00:32:00+00:00'
    )
  ))
from pa05c_h3_results r
cross join lateral jsonb_array_elements(
  r.response_payload -> 'readiness_items' -> 0 -> 'command_context' -> 'purchase_commitments'
) commitment
where r.result_name = 'po_refresh'
  and commitment ->> 'purchase_order_id' = '45800000-0000-0000-0000-000000000700';
reset role;
select ok(
  (select (response_payload ->> 'success')::boolean
   from pa05c_h3_results where result_name = 'po_refreshed_command'),
  'a newly reviewed Evidence command using the READ-02 PO version passes the guard'
);

-- Required allocation stale-recovery proof using the Evidence created above.
update atlas_procurement.fulfilment_allocations
set version = 2
where fulfilment_allocation_id = '45800000-0000-0000-0000-000000000600';
set local role authenticated;
select set_config('request.jwt.claim.sub', '15800000-0000-0000-0000-000000000101', true);
insert into pa05c_h3_results
select 'allocation_stale', atlas_api.apply_supplier_evidence_to_allocation(
  pg_temp.pa05c_h3_command_request(
    '95800000-0000-0000-0000-000000000301', 'pa05c-h3-allocation-stale', 1,
    jsonb_build_object(
      'supplier_receiving_evidence_id', response_payload -> 'affected_aggregate_ids' ->> 'supplier_receiving_evidence_id',
      'fulfilment_allocation_line_revision_id', '45800000-0000-0000-0000-000000000603',
      'unit_id', '25800000-0000-0000-0000-000000000102',
      'applied_quantity', 4,
      'occurred_at', '2026-07-18T00:33:00+00:00'
    )
  )
)
from pa05c_h3_results where result_name = 'po_refreshed_command';
insert into pa05c_h3_results values
  ('allocation_refresh', atlas_api.get_dispatch_evidence_readiness(pg_temp.pa05c_h3_read_request(
    '15800000-0000-0000-0000-000000000101',
    jsonb_build_object('wholesale_order_line_revision_id', '35800000-0000-0000-0000-000000000202')
  )));
reset role;
select is(
  (select response_payload ->> 'error_code' from pa05c_h3_results where result_name = 'allocation_stale'),
  'STALE_VERSION',
  'apply Evidence rejects the retained stale allocation version'
);
select is(
  (select (response_payload -> 'readiness_items' -> 0 -> 'command_context' ->
    'fulfilment_allocation' ->> 'fulfilment_allocation_version')::bigint
   from pa05c_h3_results where result_name = 'allocation_refresh'),
  2::bigint,
  'READ-02 refresh returns the authoritative current allocation version'
);
set local role authenticated;
select set_config('request.jwt.claim.sub', '15800000-0000-0000-0000-000000000101', true);
insert into pa05c_h3_results
select 'allocation_refreshed_command', atlas_api.apply_supplier_evidence_to_allocation(
  pg_temp.pa05c_h3_command_request(
    '95800000-0000-0000-0000-000000000302', 'pa05c-h3-allocation-refreshed',
    (refresh.response_payload -> 'readiness_items' -> 0 -> 'command_context' ->
      'fulfilment_allocation' ->> 'fulfilment_allocation_version')::bigint,
    jsonb_build_object(
      'supplier_receiving_evidence_id', evidence.response_payload ->
        'affected_aggregate_ids' ->> 'supplier_receiving_evidence_id',
      'fulfilment_allocation_line_revision_id', '45800000-0000-0000-0000-000000000603',
      'unit_id', '25800000-0000-0000-0000-000000000102',
      'applied_quantity', 4,
      'occurred_at', '2026-07-18T00:34:00+00:00'
    )
  )
)
from pa05c_h3_results evidence
cross join pa05c_h3_results refresh
where evidence.result_name = 'po_refreshed_command'
  and refresh.result_name = 'allocation_refresh';
reset role;
select ok(
  (select (response_payload ->> 'success')::boolean
   from pa05c_h3_results where result_name = 'allocation_refreshed_command'),
  'a newly reviewed application command using the READ-02 allocation version passes the guard'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '15800000-0000-0000-0000-000000000101', true);
insert into pa05c_h3_results values
  ('historical_evidence', atlas_api.get_dispatch_evidence_readiness(pg_temp.pa05c_h3_read_request(
    '15800000-0000-0000-0000-000000000101',
    jsonb_build_object('wholesale_order_line_revision_id', '35800000-0000-0000-0000-000000000202')
  )));
reset role;
select ok(
  (select jsonb_array_length(response_payload -> 'readiness_items' -> 0 -> 'evidence_references') > 0
   from pa05c_h3_results where result_name = 'historical_evidence'),
  'existing Evidence references remain available before lineage supersession'
);

-- Superseding one PO revision excludes its old current commitment.
update atlas_procurement.purchase_order_revisions
set is_current = false, revision_status = 'SUPERSEDED'
where purchase_order_revision_id = '45800000-0000-0000-0000-000000000701';
update atlas_procurement.purchase_orders
set version = 3
where purchase_order_id = '45800000-0000-0000-0000-000000000700';
insert into atlas_procurement.purchase_order_revisions
  (purchase_order_revision_id, purchase_order_id, revision_number, revision_kind, revision_status, is_current, predecessor_revision_id, service_date, delivery_location_id, supplier_name_snapshot, delivery_location_snapshot, released_by_actor_id, released_at) values
  ('45800000-0000-0000-0000-000000000721', '45800000-0000-0000-0000-000000000700', 2, 'SUPERSEDING', 'RELEASED_TO_SUPPLIER', true, '45800000-0000-0000-0000-000000000701', date '2026-07-18', '25800000-0000-0000-0000-000000000101', 'PA-05C-H3 supplier', 'PA-05C-H3 location', '15800000-0000-0000-0000-000000000001', timestamptz '2026-07-18 00:35:00+00');
insert into atlas_procurement.purchase_order_line_revisions
  (purchase_order_line_revision_id, purchase_order_revision_id, purchase_order_line_id, fulfilment_allocation_line_revision_id, ingredient_id, ordered_quantity, unit_id, delivery_location_id, service_date, predecessor_revision_id) values
  ('45800000-0000-0000-0000-000000000723', '45800000-0000-0000-0000-000000000721', '45800000-0000-0000-0000-000000000702', '45800000-0000-0000-0000-000000000603', '25800000-0000-0000-0000-000000000103', 6, '25800000-0000-0000-0000-000000000102', '25800000-0000-0000-0000-000000000101', date '2026-07-18', '45800000-0000-0000-0000-000000000703');
set local role authenticated;
select set_config('request.jwt.claim.sub', '15800000-0000-0000-0000-000000000101', true);
insert into pa05c_h3_results values
  ('po_superseded', atlas_api.get_dispatch_evidence_readiness(pg_temp.pa05c_h3_read_request(
    '15800000-0000-0000-0000-000000000101',
    jsonb_build_object('wholesale_order_line_revision_id', '35800000-0000-0000-0000-000000000202')
  )));
reset role;
select ok(
  (select not response_payload @> jsonb_build_object(
      'readiness_items', jsonb_build_array(jsonb_build_object(
        'command_context', jsonb_build_object(
          'purchase_commitments', jsonb_build_array(jsonb_build_object(
            'purchase_order_revision_id', '45800000-0000-0000-0000-000000000701'
          ))
        )
      ))
    )
   from pa05c_h3_results where result_name = 'po_superseded')
  and
  (select response_payload::text like '%45800000-0000-0000-0000-000000000721%'
   from pa05c_h3_results where result_name = 'po_superseded'),
  'superseding a PO revision exposes only its new current commitment'
);

-- Supersede the allocation and advance both POs to exact new-line commitments.
update atlas_procurement.fulfilment_allocation_revisions
set is_current = false
where fulfilment_allocation_revision_id = '45800000-0000-0000-0000-000000000601';
update atlas_procurement.fulfilment_allocation_line_revisions
set line_status = 'SUPERSEDED'
where fulfilment_allocation_line_revision_id in (
  '45800000-0000-0000-0000-000000000603',
  '45800000-0000-0000-0000-000000000605'
);
update atlas_procurement.fulfilment_allocations
set version = 3, allocation_status = 'REVISED_WITH_REASON'
where fulfilment_allocation_id = '45800000-0000-0000-0000-000000000600';
insert into atlas_procurement.fulfilment_allocation_revisions
  (fulfilment_allocation_revision_id, fulfilment_allocation_id, revision_number, revision_kind, revision_status, is_current, predecessor_revision_id, allocated_by_actor_id, reason_note) values
  ('45800000-0000-0000-0000-000000000611', '45800000-0000-0000-0000-000000000600', 2, 'SUPERSEDING', 'REVISED_WITH_REASON', true, '45800000-0000-0000-0000-000000000601', '15800000-0000-0000-0000-000000000001', 'PA-05C-H3 supersession proof');
insert into atlas_procurement.fulfilment_allocation_line_revisions
  (fulfilment_allocation_line_revision_id, fulfilment_allocation_revision_id, fulfilment_allocation_line_id, dispatch_requirement_line_revision_id, supplier_id, allocated_quantity, unit_id, line_status, predecessor_revision_id) values
  ('45800000-0000-0000-0000-000000000613', '45800000-0000-0000-0000-000000000611', '45800000-0000-0000-0000-000000000602', '35800000-0000-0000-0000-000000000503', '25800000-0000-0000-0000-000000000104', 6, '25800000-0000-0000-0000-000000000102', 'READY_FOR_EVIDENCE', '45800000-0000-0000-0000-000000000603'),
  ('45800000-0000-0000-0000-000000000615', '45800000-0000-0000-0000-000000000611', '45800000-0000-0000-0000-000000000604', '35800000-0000-0000-0000-000000000503', '25800000-0000-0000-0000-000000000104', 4, '25800000-0000-0000-0000-000000000102', 'READY_FOR_EVIDENCE', '45800000-0000-0000-0000-000000000605');

update atlas_procurement.purchase_order_revisions
set is_current = false, revision_status = 'SUPERSEDED'
where purchase_order_revision_id in (
  '45800000-0000-0000-0000-000000000721',
  '45800000-0000-0000-0000-000000000711'
);
update atlas_procurement.purchase_orders
set version = case purchase_order_id
  when '45800000-0000-0000-0000-000000000700' then 4 else 2 end
where purchase_order_id in (
  '45800000-0000-0000-0000-000000000700',
  '45800000-0000-0000-0000-000000000710'
);
insert into atlas_procurement.purchase_order_revisions
  (purchase_order_revision_id, purchase_order_id, revision_number, revision_kind, revision_status, is_current, predecessor_revision_id, service_date, delivery_location_id, supplier_name_snapshot, delivery_location_snapshot, released_by_actor_id, released_at) values
  ('45800000-0000-0000-0000-000000000731', '45800000-0000-0000-0000-000000000700', 3, 'SUPERSEDING', 'RELEASED_TO_SUPPLIER', true, '45800000-0000-0000-0000-000000000721', date '2026-07-18', '25800000-0000-0000-0000-000000000101', 'PA-05C-H3 supplier', 'PA-05C-H3 location', '15800000-0000-0000-0000-000000000001', timestamptz '2026-07-18 00:40:00+00'),
  ('45800000-0000-0000-0000-000000000741', '45800000-0000-0000-0000-000000000710', 2, 'SUPERSEDING', 'SUPPLIER_CONFIRMED', true, '45800000-0000-0000-0000-000000000711', date '2026-07-18', '25800000-0000-0000-0000-000000000101', 'PA-05C-H3 supplier', 'PA-05C-H3 location', '15800000-0000-0000-0000-000000000001', timestamptz '2026-07-18 00:41:00+00');
insert into atlas_procurement.purchase_order_line_revisions
  (purchase_order_line_revision_id, purchase_order_revision_id, purchase_order_line_id, fulfilment_allocation_line_revision_id, ingredient_id, ordered_quantity, unit_id, delivery_location_id, service_date, predecessor_revision_id) values
  ('45800000-0000-0000-0000-000000000733', '45800000-0000-0000-0000-000000000731', '45800000-0000-0000-0000-000000000702', '45800000-0000-0000-0000-000000000613', '25800000-0000-0000-0000-000000000103', 6, '25800000-0000-0000-0000-000000000102', '25800000-0000-0000-0000-000000000101', date '2026-07-18', '45800000-0000-0000-0000-000000000723'),
  ('45800000-0000-0000-0000-000000000743', '45800000-0000-0000-0000-000000000741', '45800000-0000-0000-0000-000000000712', '45800000-0000-0000-0000-000000000615', '25800000-0000-0000-0000-000000000103', 4, '25800000-0000-0000-0000-000000000102', '25800000-0000-0000-0000-000000000101', date '2026-07-18', '45800000-0000-0000-0000-000000000713');

set local role authenticated;
select set_config('request.jwt.claim.sub', '15800000-0000-0000-0000-000000000101', true);
insert into pa05c_h3_results values
  ('allocation_superseded', atlas_api.get_dispatch_evidence_readiness(pg_temp.pa05c_h3_read_request(
    '15800000-0000-0000-0000-000000000101',
    jsonb_build_object('wholesale_order_line_revision_id', '35800000-0000-0000-0000-000000000202')
  )));
reset role;
select ok(
  (select not exists (
    select 1
    from jsonb_array_elements(response_payload -> 'readiness_items') item
    where item -> 'command_context' -> 'fulfilment_allocation' ->>
      'fulfilment_allocation_revision_id' <> '45800000-0000-0000-0000-000000000611'
      or (
        item -> 'command_context' -> 'fulfilment_allocation' ->>
          'fulfilment_allocation_line_id' = '45800000-0000-0000-0000-000000000602'
        and item -> 'command_context' -> 'fulfilment_allocation' ->>
          'fulfilment_allocation_line_revision_id' <> '45800000-0000-0000-0000-000000000613'
      )
      or (
        item -> 'command_context' -> 'fulfilment_allocation' ->>
          'fulfilment_allocation_line_id' = '45800000-0000-0000-0000-000000000604'
        and item -> 'command_context' -> 'fulfilment_allocation' ->>
          'fulfilment_allocation_line_revision_id' <> '45800000-0000-0000-0000-000000000615'
      )
  ) from pa05c_h3_results where result_name = 'allocation_superseded'),
  'superseding an allocation revision exposes only the new current allocation context'
);
select ok(
  (select not exists (
    select 1
    from jsonb_array_elements(response_payload -> 'readiness_items') item
    left join lateral jsonb_array_elements(
      item -> 'command_context' -> 'purchase_commitments'
    ) commitment on true
    where item -> 'command_context' -> 'fulfilment_allocation' ->>
        'fulfilment_allocation_revision_id' = '45800000-0000-0000-0000-000000000601'
      or item -> 'command_context' -> 'fulfilment_allocation' ->>
        'fulfilment_allocation_line_revision_id' in (
          '45800000-0000-0000-0000-000000000603',
          '45800000-0000-0000-0000-000000000605'
        )
      or commitment ->> 'purchase_order_revision_id' in (
        '45800000-0000-0000-0000-000000000721',
        '45800000-0000-0000-0000-000000000711'
      )
   ) from pa05c_h3_results where result_name = 'allocation_superseded'),
  'superseded allocation and PO revisions are excluded from current command context'
);
select ok(
  (select exists (
    select 1
    from jsonb_array_elements(response_payload -> 'readiness_items') item
    where item ->> 'fulfilment_allocation_line_revision_id' = '45800000-0000-0000-0000-000000000603'
      and jsonb_array_length(item -> 'evidence_references') > 0
      and item -> 'command_context' -> 'fulfilment_allocation' ->>
        'fulfilment_allocation_line_revision_id' = '45800000-0000-0000-0000-000000000613'
  ) from pa05c_h3_results where result_name = 'allocation_superseded'),
  'historical Evidence references retain existing semantics while command context advances'
);

-- An active current PO line with mismatched ingredient lineage must fail closed.
update atlas_procurement.purchase_order_line_revisions
set ingredient_id = '25800000-0000-0000-0000-000000000113'
where purchase_order_line_revision_id = '45800000-0000-0000-0000-000000000743';
set local role authenticated;
select set_config('request.jwt.claim.sub', '15800000-0000-0000-0000-000000000101', true);
insert into pa05c_h3_results values
  ('lineage_conflict', atlas_api.get_dispatch_evidence_readiness(pg_temp.pa05c_h3_read_request(
    '15800000-0000-0000-0000-000000000101',
    jsonb_build_object('wholesale_order_line_revision_id', '35800000-0000-0000-0000-000000000202')
  )));
reset role;
select is(
  (select response_payload ->> 'error_code' from pa05c_h3_results where result_name = 'lineage_conflict'),
  'CURRENT_LINEAGE_CONFLICT',
  'contradictory active current lineage returns the documented safe read error'
);
select ok(
  (select not response_payload ? 'readiness_items'
   from pa05c_h3_results where result_name = 'lineage_conflict'),
  'contradictory lineage exposes no partial command context'
);

select * from finish();
rollback;
