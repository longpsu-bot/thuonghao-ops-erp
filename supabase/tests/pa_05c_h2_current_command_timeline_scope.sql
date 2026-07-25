begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
select plan(42);

grant usage on schema extensions to authenticated;
grant execute on all functions in schema extensions to authenticated;

-- Private-helper hardening and permanent READ-04 behavior.
select ok(
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    join pg_roles r on r.oid = p.proowner
    where n.nspname = 'atlas_core'
      and p.proname = 'pa_05c_aggregate_scope'
      and pg_get_function_identity_arguments(p.oid) = 'aggregate_type text, aggregate_id uuid'
      and pg_get_function_result(p.oid) =
        'TABLE(customer_id uuid, delivery_location_id uuid, dispatch_trip_id uuid, public_reference text)'
      and r.rolname = 'atlas_owner'
      and p.provolatile = 's'
      and not p.prosecdef
      and p.proconfig @> array['search_path=""']
      and pg_get_functiondef(p.oid) !~* '\mexecute\M'
      and pg_get_functiondef(p.oid) !~* '\mformat\s*\('
  ),
  'aggregate scope helper keeps its owner signature rows stability invoker security fixed path and static SQL'
);

select ok(
  has_function_privilege(
    'atlas_read_runtime',
    'atlas_core.pa_05c_aggregate_scope(text,uuid)',
    'EXECUTE'
  )
  and not exists (
    select 1
    from unnest(array[
      'anon', 'authenticated', 'service_role', 'atlas_command_runtime',
      'atlas_evidence_command_runtime', 'atlas_dispatch_command_runtime',
      'atlas_planning_command_runtime', 'atlas_procurement_command_runtime'
    ]) blocked_role(role_name)
    where has_function_privilege(
      blocked_role.role_name,
      'atlas_core.pa_05c_aggregate_scope(text,uuid)',
      'EXECUTE'
    )
  ),
  'only atlas_read_runtime among API and runtime roles executes the private helper'
);

select ok(
  not exists (
    select 1
    from information_schema.role_table_grants g
    where g.grantee = 'atlas_read_runtime'
      and g.table_schema like 'atlas\_%' escape '\'
      and g.privilege_type <> 'SELECT'
  )
  and not exists (
    select 1
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname like 'atlas\_%' escape '\'
      and c.relkind = 'S'
      and (
        has_sequence_privilege('atlas_read_runtime', c.oid, 'USAGE')
        or has_sequence_privilege('atlas_read_runtime', c.oid, 'UPDATE')
      )
  )
  and not exists (
    select 1
    from unnest(array[
      'atlas_core', 'atlas_admin', 'atlas_planning', 'atlas_procurement',
      'atlas_evidence', 'atlas_dispatch', 'atlas_audit', 'atlas_reporting', 'atlas_api'
    ]) atlas_schema(schema_name)
    where has_schema_privilege('atlas_read_runtime', atlas_schema.schema_name, 'CREATE')
  )
  and not pg_has_role('atlas_read_runtime', 'atlas_command_runtime', 'MEMBER')
  and not pg_has_role('atlas_read_runtime', 'atlas_evidence_command_runtime', 'MEMBER')
  and not pg_has_role('atlas_read_runtime', 'atlas_dispatch_command_runtime', 'MEMBER')
  and not pg_has_role('atlas_read_runtime', 'atlas_planning_command_runtime', 'MEMBER')
  and not pg_has_role('atlas_read_runtime', 'atlas_procurement_command_runtime', 'MEMBER'),
  'atlas_read_runtime has no write sequence schema-create or command-runtime authority'
);

select ok(
  has_table_privilege('atlas_read_runtime', 'atlas_planning.confirmed_need_batches', 'SELECT')
  and has_table_privilege('atlas_read_runtime', 'atlas_planning.purchase_handoff_batches', 'SELECT')
  and has_table_privilege('atlas_read_runtime', 'atlas_planning.purchase_handoff_revisions', 'SELECT')
  and has_table_privilege('atlas_read_runtime', 'atlas_procurement.fulfilment_allocations', 'SELECT')
  and has_table_privilege('atlas_read_runtime', 'atlas_dispatch.dispatch_plan_requirements', 'SELECT')
  and (
    select count(*)
    from pg_policy p
    join pg_class c on c.oid = p.polrelid
    join pg_namespace n on n.oid = c.relnamespace
    where p.polname = 'pa_05c_h2_read_select'
      and p.polcmd = 'r'
      and (select oid from pg_roles where rolname = 'atlas_read_runtime') = any(p.polroles)
      and n.nspname || '.' || c.relname in (
        'atlas_planning.confirmed_need_batches',
        'atlas_planning.purchase_handoff_batches',
        'atlas_planning.purchase_handoff_revisions',
        'atlas_procurement.fulfilment_allocations',
        'atlas_dispatch.dispatch_plan_requirements'
      )
  ) = 5,
  'the five missing helper joins have SELECT grants and SELECT-only read-runtime policies'
);

-- Rolled-back actor/capability fixtures.
insert into atlas_core.actors
  (actor_id, actor_type, display_name, actor_status, deactivated_at)
values
  ('16000000-0000-0000-0000-000000000001', 'HUMAN', 'PA-05C-H2 global reader', 'ACTIVE', null),
  ('16000000-0000-0000-0000-000000000002', 'HUMAN', 'PA-05C-H2 trip reader', 'ACTIVE', null),
  ('16000000-0000-0000-0000-000000000003', 'HUMAN', 'PA-05C-H2 wrong-trip reader', 'ACTIVE', null);

insert into atlas_core.actor_auth_subjects
  (actor_auth_subject_id, actor_id, auth_subject_id, subject_status, revoked_at)
values
  ('16000000-0000-0000-0000-000000000011', '16000000-0000-0000-0000-000000000001', '16000000-0000-0000-0000-000000000101', 'ACTIVE', null),
  ('16000000-0000-0000-0000-000000000012', '16000000-0000-0000-0000-000000000002', '16000000-0000-0000-0000-000000000102', 'ACTIVE', null),
  ('16000000-0000-0000-0000-000000000013', '16000000-0000-0000-0000-000000000003', '16000000-0000-0000-0000-000000000103', 'ACTIVE', null);

insert into atlas_core.roles (role_id, role_code, role_name)
values ('16100000-0000-0000-0000-000000000001', 'pa05c_h2.reader', 'PA-05C-H2 reader');

insert into atlas_core.capabilities
  (capability_id, capability_code, capability_name, owning_domain)
values
  ('16200000-0000-0000-0000-000000000001', 'command_audit_timeline.read', 'Read command audit timeline', 'AUDIT');

insert into atlas_core.role_capabilities (role_id, capability_id)
values ('16100000-0000-0000-0000-000000000001', '16200000-0000-0000-0000-000000000001');

insert into atlas_core.actor_role_memberships (actor_id, role_id)
values
  ('16000000-0000-0000-0000-000000000001', '16100000-0000-0000-0000-000000000001'),
  ('16000000-0000-0000-0000-000000000002', '16100000-0000-0000-0000-000000000001'),
  ('16000000-0000-0000-0000-000000000003', '16100000-0000-0000-0000-000000000001');

insert into atlas_core.actor_scopes (actor_id, scope_kind)
values ('16000000-0000-0000-0000-000000000001', 'GLOBAL');

-- One complete supplier-direct relational lineage.
insert into atlas_admin.customers (customer_id, customer_code, customer_name)
values ('26000000-0000-0000-0000-000000000100', 'pa05c-h2-customer', 'PA-05C-H2 customer');

insert into atlas_admin.delivery_locations
  (delivery_location_id, customer_id, location_code, location_name, address_text)
values
  ('26000000-0000-0000-0000-000000000101', '26000000-0000-0000-0000-000000000100', 'pa05c-h2-main', 'PA-05C-H2 main location', 'Main address'),
  ('26000000-0000-0000-0000-000000000105', '26000000-0000-0000-0000-000000000100', 'pa05c-h2-other', 'PA-05C-H2 other location', 'Other address');

insert into atlas_admin.units (unit_id, unit_code, unit_name, dimension_code)
values ('26000000-0000-0000-0000-000000000102', 'pa05c-h2-kg', 'PA-05C-H2 kilogram', 'mass');

insert into atlas_admin.ingredients (ingredient_id, ingredient_code, ingredient_name)
values ('26000000-0000-0000-0000-000000000103', 'pa05c-h2-rice', 'PA-05C-H2 rice');

insert into atlas_admin.suppliers (supplier_id, supplier_code, supplier_name)
values ('26000000-0000-0000-0000-000000000104', 'pa05c-h2-supplier', 'PA-05C-H2 supplier');

insert into atlas_planning.wholesale_orders
  (wholesale_order_id, customer_id, delivery_location_id, customer_order_reference,
   service_date, order_status, created_by_actor_id)
values
  ('36000000-0000-0000-0000-000000000200', '26000000-0000-0000-0000-000000000100',
   '26000000-0000-0000-0000-000000000101', 'PA05C-H2-ORDER-001', date '2026-07-17',
   'RELEASED', '16000000-0000-0000-0000-000000000001');

insert into atlas_planning.wholesale_order_lines
  (wholesale_order_line_id, wholesale_order_id, source_line_number)
values ('36000000-0000-0000-0000-000000000201', '36000000-0000-0000-0000-000000000200', 1);

insert into atlas_planning.wholesale_order_line_revisions
  (wholesale_order_line_revision_id, wholesale_order_line_id, revision_number,
   ingredient_id, requested_quantity, unit_id, revision_status, created_by_actor_id)
values
  ('36000000-0000-0000-0000-000000000202', '36000000-0000-0000-0000-000000000201', 1,
   '26000000-0000-0000-0000-000000000103', 10, '26000000-0000-0000-0000-000000000102',
   'RELEASED', '16000000-0000-0000-0000-000000000001');

insert into atlas_planning.confirmed_need_batches
  (confirmed_need_batch_id, wholesale_order_id, period_start, period_end, batch_status, created_by_actor_id)
values
  ('36000000-0000-0000-0000-000000000300', '36000000-0000-0000-0000-000000000200',
   date '2026-07-17', date '2026-07-17', 'RELEASED_FOR_PURCHASE_HANDOFF',
   '16000000-0000-0000-0000-000000000001');

insert into atlas_planning.confirmed_need_lines
  (confirmed_need_line_id, confirmed_need_batch_id, wholesale_order_line_id)
values
  ('36000000-0000-0000-0000-000000000301', '36000000-0000-0000-0000-000000000300',
   '36000000-0000-0000-0000-000000000201');

insert into atlas_planning.confirmed_need_line_revisions
  (confirmed_need_line_revision_id, confirmed_need_line_id, revision_number,
   wholesale_order_line_revision_id, ingredient_id, theoretical_quantity,
   confirmed_quantity, unit_id, revision_status, created_by_actor_id)
values
  ('36000000-0000-0000-0000-000000000302', '36000000-0000-0000-0000-000000000301', 1,
   '36000000-0000-0000-0000-000000000202', '26000000-0000-0000-0000-000000000103',
   10, 10, '26000000-0000-0000-0000-000000000102', 'RELEASED',
   '16000000-0000-0000-0000-000000000001');

insert into atlas_planning.purchase_handoff_batches
  (purchase_handoff_batch_id, confirmed_need_batch_id, period_start, period_end,
   handoff_status, created_by_actor_id)
values
  ('36000000-0000-0000-0000-000000000400', '36000000-0000-0000-0000-000000000300',
   date '2026-07-17', date '2026-07-17', 'RELEASED_TO_PROCUREMENT',
   '16000000-0000-0000-0000-000000000001');

insert into atlas_planning.purchase_handoff_revisions
  (purchase_handoff_revision_id, purchase_handoff_batch_id, revision_number,
   revision_status, released_by_actor_id, released_at)
values
  ('36000000-0000-0000-0000-000000000401', '36000000-0000-0000-0000-000000000400',
   1, 'RELEASED_TO_PROCUREMENT', '16000000-0000-0000-0000-000000000001',
   timestamptz '2026-07-17 01:00:00+00');

insert into atlas_planning.purchase_handoff_lines
  (purchase_handoff_line_id, purchase_handoff_batch_id, confirmed_need_line_id)
values
  ('36000000-0000-0000-0000-000000000402', '36000000-0000-0000-0000-000000000400',
   '36000000-0000-0000-0000-000000000301');

insert into atlas_planning.purchase_handoff_line_revisions
  (purchase_handoff_line_revision_id, purchase_handoff_revision_id,
   purchase_handoff_line_id, confirmed_need_line_revision_id, ingredient_id,
   handoff_quantity, unit_id, service_date, delivery_location_id)
values
  ('36000000-0000-0000-0000-000000000403', '36000000-0000-0000-0000-000000000401',
   '36000000-0000-0000-0000-000000000402', '36000000-0000-0000-0000-000000000302',
   '26000000-0000-0000-0000-000000000103', 10, '26000000-0000-0000-0000-000000000102',
   date '2026-07-17', '26000000-0000-0000-0000-000000000101');

insert into atlas_planning.dispatch_requirements
  (dispatch_requirement_id, customer_id, delivery_location_id, service_date, requirement_status)
values
  ('36000000-0000-0000-0000-000000000500', '26000000-0000-0000-0000-000000000100',
   '26000000-0000-0000-0000-000000000101', date '2026-07-17', 'RELEASED');

insert into atlas_planning.dispatch_requirement_revisions
  (dispatch_requirement_revision_id, dispatch_requirement_id, purchase_handoff_revision_id,
   revision_number, revision_status, customer_name_snapshot, location_name_snapshot,
   address_snapshot, released_by_actor_id, released_at)
values
  ('36000000-0000-0000-0000-000000000501', '36000000-0000-0000-0000-000000000500',
   '36000000-0000-0000-0000-000000000401', 1, 'RELEASED', 'PA-05C-H2 customer',
   'PA-05C-H2 main location', 'Main address', '16000000-0000-0000-0000-000000000001',
   timestamptz '2026-07-17 01:10:00+00');

insert into atlas_planning.dispatch_requirement_lines
  (dispatch_requirement_line_id, dispatch_requirement_id, purchase_handoff_line_id)
values
  ('36000000-0000-0000-0000-000000000502', '36000000-0000-0000-0000-000000000500',
   '36000000-0000-0000-0000-000000000402');

insert into atlas_planning.dispatch_requirement_line_revisions
  (dispatch_requirement_line_revision_id, dispatch_requirement_revision_id,
   dispatch_requirement_line_id, purchase_handoff_line_revision_id, ingredient_id,
   required_quantity, unit_id)
values
  ('36000000-0000-0000-0000-000000000503', '36000000-0000-0000-0000-000000000501',
   '36000000-0000-0000-0000-000000000502', '36000000-0000-0000-0000-000000000403',
   '26000000-0000-0000-0000-000000000103', 10, '26000000-0000-0000-0000-000000000102');

insert into atlas_procurement.fulfilment_allocations
  (fulfilment_allocation_id, dispatch_requirement_id, allocation_status)
values
  ('46000000-0000-0000-0000-000000000600', '36000000-0000-0000-0000-000000000500',
   'READY_FOR_DISPATCH');

insert into atlas_procurement.fulfilment_allocation_revisions
  (fulfilment_allocation_revision_id, fulfilment_allocation_id, revision_number,
   revision_status, allocated_by_actor_id)
values
  ('46000000-0000-0000-0000-000000000601', '46000000-0000-0000-0000-000000000600',
   1, 'READY_FOR_DISPATCH', '16000000-0000-0000-0000-000000000001');

insert into atlas_procurement.fulfilment_allocation_lines
  (fulfilment_allocation_line_id, fulfilment_allocation_id,
   dispatch_requirement_line_id, portion_sequence)
values
  ('46000000-0000-0000-0000-000000000602', '46000000-0000-0000-0000-000000000600',
   '36000000-0000-0000-0000-000000000502', 1);

insert into atlas_procurement.fulfilment_allocation_line_revisions
  (fulfilment_allocation_line_revision_id, fulfilment_allocation_revision_id,
   fulfilment_allocation_line_id, dispatch_requirement_line_revision_id, supplier_id,
   allocated_quantity, unit_id, line_status)
values
  ('46000000-0000-0000-0000-000000000603', '46000000-0000-0000-0000-000000000601',
   '46000000-0000-0000-0000-000000000602', '36000000-0000-0000-0000-000000000503',
   '26000000-0000-0000-0000-000000000104', 10, '26000000-0000-0000-0000-000000000102',
   'EVIDENCED');

insert into atlas_procurement.purchase_orders
  (purchase_order_id, supplier_id, document_number, purchase_order_status)
values
  ('46000000-0000-0000-0000-000000000700', '26000000-0000-0000-0000-000000000104',
   'PA05C-H2-PO-001', 'RELEASED_TO_SUPPLIER');

insert into atlas_procurement.purchase_order_revisions
  (purchase_order_revision_id, purchase_order_id, revision_number, revision_status,
   service_date, delivery_location_id, supplier_name_snapshot,
   delivery_location_snapshot, released_by_actor_id, released_at)
values
  ('46000000-0000-0000-0000-000000000701', '46000000-0000-0000-0000-000000000700', 1,
   'RELEASED_TO_SUPPLIER', date '2026-07-17', '26000000-0000-0000-0000-000000000101',
   'PA-05C-H2 supplier', 'PA-05C-H2 main location',
   '16000000-0000-0000-0000-000000000001', timestamptz '2026-07-17 01:20:00+00');

insert into atlas_procurement.purchase_order_lines
  (purchase_order_line_id, purchase_order_id, fulfilment_allocation_line_id)
values
  ('46000000-0000-0000-0000-000000000702', '46000000-0000-0000-0000-000000000700',
   '46000000-0000-0000-0000-000000000602');

insert into atlas_procurement.purchase_order_line_revisions
  (purchase_order_line_revision_id, purchase_order_revision_id, purchase_order_line_id,
   fulfilment_allocation_line_revision_id, ingredient_id, ordered_quantity, unit_id,
   delivery_location_id, service_date)
values
  ('46000000-0000-0000-0000-000000000703', '46000000-0000-0000-0000-000000000701',
   '46000000-0000-0000-0000-000000000702', '46000000-0000-0000-0000-000000000603',
   '26000000-0000-0000-0000-000000000103', 10, '26000000-0000-0000-0000-000000000102',
   '26000000-0000-0000-0000-000000000101', date '2026-07-17');

insert into atlas_evidence.supplier_receiving_evidence
  (supplier_receiving_evidence_id, supplier_id, purchase_order_line_revision_id,
   ingredient_id, evidence_reference, evidence_quantity, unit_id, evidence_status,
   occurred_at, recorded_by_actor_id, command_id, correlation_id)
values
  ('66000000-0000-0000-0000-000000000001', '26000000-0000-0000-0000-000000000104',
   '46000000-0000-0000-0000-000000000703', '26000000-0000-0000-0000-000000000103',
   'PA05C-H2-EVIDENCE-001', 10, '26000000-0000-0000-0000-000000000102', 'VALID',
   timestamptz '2026-07-17 01:30:00+00', '16000000-0000-0000-0000-000000000001',
   '96000000-0000-0000-0000-000000000006', '96000000-0000-0000-0000-000000000100');

insert into atlas_evidence.evidence_applications
  (evidence_application_id, supplier_receiving_evidence_id,
   fulfilment_allocation_line_revision_id, applied_quantity, unit_id,
   application_status, occurred_at, recorded_by_actor_id, command_id, correlation_id)
values
  ('66000000-0000-0000-0000-000000000002', '66000000-0000-0000-0000-000000000001',
   '46000000-0000-0000-0000-000000000603', 10, '26000000-0000-0000-0000-000000000102',
   'VALID', timestamptz '2026-07-17 01:31:00+00', '16000000-0000-0000-0000-000000000001',
   '96000000-0000-0000-0000-000000000007', '96000000-0000-0000-0000-000000000100');

insert into atlas_dispatch.dispatch_plans
  (dispatch_plan_id, plan_reference, service_date, plan_status, created_by_actor_id)
values
  ('56000000-0000-0000-0000-000000000900', 'PA05C-H2-PLAN-001', date '2026-07-17',
   'PLANNED', '16000000-0000-0000-0000-000000000001');

insert into atlas_dispatch.dispatch_plan_requirements
  (dispatch_plan_requirement_id, dispatch_plan_id,
   dispatch_requirement_revision_id, fulfilment_allocation_revision_id)
values
  ('56000000-0000-0000-0000-000000000901', '56000000-0000-0000-0000-000000000900',
   '36000000-0000-0000-0000-000000000501', '46000000-0000-0000-0000-000000000601');

insert into atlas_dispatch.dispatch_trips
  (dispatch_trip_id, dispatch_plan_id, trip_reference, trip_status,
   driver_actor_id, departed_at, completed_at)
values
  ('56000000-0000-0000-0000-000000000902', '56000000-0000-0000-0000-000000000900',
   'PA05C-H2-TRIP-001', 'DELIVERED', '16000000-0000-0000-0000-000000000001',
   timestamptz '2026-07-17 02:00:00+00', timestamptz '2026-07-17 03:00:00+00');

insert into atlas_dispatch.dispatch_stops
  (dispatch_stop_id, dispatch_trip_id, stop_sequence,
   dispatch_requirement_revision_id, customer_id, delivery_location_id, stop_status)
values
  ('56000000-0000-0000-0000-000000000903', '56000000-0000-0000-0000-000000000902', 1,
   '36000000-0000-0000-0000-000000000501', '26000000-0000-0000-0000-000000000100',
   '26000000-0000-0000-0000-000000000101', 'DELIVERED');

insert into atlas_dispatch.dispatch_loads
  (dispatch_load_id, dispatch_trip_id, dispatch_requirement_revision_id,
   fulfilment_allocation_revision_id, load_status, loaded_by_actor_id, loaded_at)
values
  ('56000000-0000-0000-0000-000000000904', '56000000-0000-0000-0000-000000000902',
   '36000000-0000-0000-0000-000000000501', '46000000-0000-0000-0000-000000000601',
   'CONFIRMED', '16000000-0000-0000-0000-000000000001', timestamptz '2026-07-17 01:50:00+00');

insert into atlas_dispatch.delivery_confirmations
  (delivery_confirmation_id, dispatch_stop_id, revision_number, delivery_outcome,
   confirmation_status, confirmed_by_actor_id, confirmed_at, command_id, correlation_id)
values
  ('56000000-0000-0000-0000-000000000905', '56000000-0000-0000-0000-000000000903',
   1, 'DELIVERED', 'VALID', '16000000-0000-0000-0000-000000000001',
   timestamptz '2026-07-17 02:30:00+00', '96000000-0000-0000-0000-000000000011',
   '96000000-0000-0000-0000-000000000100');

-- Isolated relational scopes for mixed-location and mixed-trip failure tests.
insert into atlas_planning.dispatch_requirements
  (dispatch_requirement_id, customer_id, delivery_location_id, service_date, requirement_status)
values
  ('36000000-0000-0000-0000-000000000510', '26000000-0000-0000-0000-000000000100',
   '26000000-0000-0000-0000-000000000101', date '2026-07-17', 'DRAFT'),
  ('36000000-0000-0000-0000-000000000520', '26000000-0000-0000-0000-000000000100',
   '26000000-0000-0000-0000-000000000105', date '2026-07-17', 'DRAFT');

insert into atlas_planning.dispatch_requirement_revisions
  (dispatch_requirement_revision_id, dispatch_requirement_id, purchase_handoff_revision_id,
   revision_number, revision_status, customer_name_snapshot, location_name_snapshot, address_snapshot)
values
  ('36000000-0000-0000-0000-000000000511', '36000000-0000-0000-0000-000000000510',
   '36000000-0000-0000-0000-000000000401', 1, 'PREPARED', 'PA-05C-H2 customer',
   'PA-05C-H2 main location', 'Main address'),
  ('36000000-0000-0000-0000-000000000521', '36000000-0000-0000-0000-000000000520',
   '36000000-0000-0000-0000-000000000401', 1, 'PREPARED', 'PA-05C-H2 customer',
   'PA-05C-H2 other location', 'Other address');

insert into atlas_dispatch.dispatch_trips
  (dispatch_trip_id, dispatch_plan_id, trip_reference, trip_status, driver_actor_id)
values
  ('56000000-0000-0000-0000-000000000912', '56000000-0000-0000-0000-000000000900',
   'PA05C-H2-TRIP-002', 'ASSIGNED', '16000000-0000-0000-0000-000000000001'),
  ('56000000-0000-0000-0000-000000000922', '56000000-0000-0000-0000-000000000900',
   'PA05C-H2-TRIP-003', 'ASSIGNED', '16000000-0000-0000-0000-000000000001');

insert into atlas_dispatch.dispatch_stops
  (dispatch_stop_id, dispatch_trip_id, stop_sequence,
   dispatch_requirement_revision_id, customer_id, delivery_location_id, stop_status)
values
  ('56000000-0000-0000-0000-000000000913', '56000000-0000-0000-0000-000000000912', 1,
   '36000000-0000-0000-0000-000000000511', '26000000-0000-0000-0000-000000000100',
   '26000000-0000-0000-0000-000000000101', 'PENDING'),
  ('56000000-0000-0000-0000-000000000923', '56000000-0000-0000-0000-000000000922', 1,
   '36000000-0000-0000-0000-000000000521', '26000000-0000-0000-0000-000000000100',
   '26000000-0000-0000-0000-000000000105', 'PENDING');

insert into atlas_core.actor_scopes (actor_id, scope_kind, dispatch_trip_id)
values
  ('16000000-0000-0000-0000-000000000002', 'DISPATCH_TRIP', '56000000-0000-0000-0000-000000000902'),
  ('16000000-0000-0000-0000-000000000003', 'DISPATCH_TRIP', '56000000-0000-0000-0000-000000000912');

-- One complete correlation with both domain and audit rows for every current
-- aggregate class. All rows resolve to the same customer/location/trip tuple.
insert into atlas_audit.domain_events
  (domain_event_id, event_type, source_domain, aggregate_type, aggregate_id,
   aggregate_version, command_id, correlation_id, actor_id, occurred_at)
select
  v.domain_event_id, v.event_type, v.source_domain, v.aggregate_type, v.aggregate_id,
  1, v.command_id, '96000000-0000-0000-0000-000000000100'::uuid,
  '16000000-0000-0000-0000-000000000001'::uuid,
  timestamptz '2026-07-17 03:10:00+00'
from (values
  ('76000000-0000-0000-0000-000000000001'::uuid, 'WholesaleOrderReleased', 'PLANNING', 'WholesaleOrder', '36000000-0000-0000-0000-000000000200'::uuid, '96000000-0000-0000-0000-000000000001'::uuid),
  ('76000000-0000-0000-0000-000000000002'::uuid, 'PurchaseHandoffReleased', 'PLANNING', 'PurchaseHandoff', '36000000-0000-0000-0000-000000000400'::uuid, '96000000-0000-0000-0000-000000000002'::uuid),
  ('76000000-0000-0000-0000-000000000003'::uuid, 'DispatchRequirementReleased', 'PLANNING', 'DispatchRequirement', '36000000-0000-0000-0000-000000000500'::uuid, '96000000-0000-0000-0000-000000000003'::uuid),
  ('76000000-0000-0000-0000-000000000004'::uuid, 'SupplierDirectFulfilmentAllocated', 'PROCUREMENT', 'FulfilmentAllocation', '46000000-0000-0000-0000-000000000600'::uuid, '96000000-0000-0000-0000-000000000004'::uuid),
  ('76000000-0000-0000-0000-000000000005'::uuid, 'SupplierPurchaseOrderReleased', 'PROCUREMENT', 'PurchaseOrder', '46000000-0000-0000-0000-000000000700'::uuid, '96000000-0000-0000-0000-000000000005'::uuid),
  ('76000000-0000-0000-0000-000000000006'::uuid, 'SupplierReceivingEvidenceRecorded', 'EVIDENCE', 'SupplierReceivingEvidence', '66000000-0000-0000-0000-000000000001'::uuid, '96000000-0000-0000-0000-000000000006'::uuid),
  ('76000000-0000-0000-0000-000000000007'::uuid, 'EvidenceAppliedToAllocation', 'EVIDENCE', 'EvidenceApplication', '66000000-0000-0000-0000-000000000002'::uuid, '96000000-0000-0000-0000-000000000007'::uuid),
  ('76000000-0000-0000-0000-000000000008'::uuid, 'DispatchPlanCreated', 'DISPATCH', 'DispatchPlan', '56000000-0000-0000-0000-000000000900'::uuid, '96000000-0000-0000-0000-000000000008'::uuid),
  ('76000000-0000-0000-0000-000000000009'::uuid, 'SuccessfulDispatchTripClosed', 'DISPATCH', 'DispatchTrip', '56000000-0000-0000-0000-000000000902'::uuid, '96000000-0000-0000-0000-000000000009'::uuid),
  ('76000000-0000-0000-0000-000000000010'::uuid, 'DispatchLoadConfirmed', 'DISPATCH', 'DispatchLoad', '56000000-0000-0000-0000-000000000904'::uuid, '96000000-0000-0000-0000-000000000010'::uuid),
  ('76000000-0000-0000-0000-000000000011'::uuid, 'SuccessfulDeliveryConfirmed', 'DISPATCH', 'DeliveryConfirmation', '56000000-0000-0000-0000-000000000905'::uuid, '96000000-0000-0000-0000-000000000011'::uuid)
) v(domain_event_id, event_type, source_domain, aggregate_type, aggregate_id, command_id);

insert into atlas_audit.audit_events
  (audit_event_id, event_type, source_domain, aggregate_type, aggregate_id,
   aggregate_version_after, command_id, correlation_id, actor_id, reason_code,
   reason_note, source_interface, occurred_at)
select
  v.audit_event_id, v.event_type, v.source_domain, v.aggregate_type, v.aggregate_id,
  1, v.command_id, '96000000-0000-0000-0000-000000000100'::uuid,
  '16000000-0000-0000-0000-000000000001'::uuid, 'PA05C_H2_TEST',
  'Safe synthetic audit reason', 'PGTAP', timestamptz '2026-07-17 03:10:00+00'
from (values
  ('77000000-0000-0000-0000-000000000001'::uuid, 'WholesaleOrderReleased', 'PLANNING', 'WholesaleOrder', '36000000-0000-0000-0000-000000000200'::uuid, '96000000-0000-0000-0000-000000000001'::uuid),
  ('77000000-0000-0000-0000-000000000002'::uuid, 'PurchaseHandoffReleased', 'PLANNING', 'PurchaseHandoff', '36000000-0000-0000-0000-000000000400'::uuid, '96000000-0000-0000-0000-000000000002'::uuid),
  ('77000000-0000-0000-0000-000000000003'::uuid, 'DispatchRequirementReleased', 'PLANNING', 'DispatchRequirement', '36000000-0000-0000-0000-000000000500'::uuid, '96000000-0000-0000-0000-000000000003'::uuid),
  ('77000000-0000-0000-0000-000000000004'::uuid, 'SupplierDirectFulfilmentAllocated', 'PROCUREMENT', 'FulfilmentAllocation', '46000000-0000-0000-0000-000000000600'::uuid, '96000000-0000-0000-0000-000000000004'::uuid),
  ('77000000-0000-0000-0000-000000000005'::uuid, 'SupplierPurchaseOrderReleased', 'PROCUREMENT', 'PurchaseOrder', '46000000-0000-0000-0000-000000000700'::uuid, '96000000-0000-0000-0000-000000000005'::uuid),
  ('77000000-0000-0000-0000-000000000006'::uuid, 'SupplierReceivingEvidenceRecorded', 'EVIDENCE', 'SupplierReceivingEvidence', '66000000-0000-0000-0000-000000000001'::uuid, '96000000-0000-0000-0000-000000000006'::uuid),
  ('77000000-0000-0000-0000-000000000007'::uuid, 'EvidenceAppliedToAllocation', 'EVIDENCE', 'EvidenceApplication', '66000000-0000-0000-0000-000000000002'::uuid, '96000000-0000-0000-0000-000000000007'::uuid),
  ('77000000-0000-0000-0000-000000000008'::uuid, 'DispatchPlanCreated', 'DISPATCH', 'DispatchPlan', '56000000-0000-0000-0000-000000000900'::uuid, '96000000-0000-0000-0000-000000000008'::uuid),
  ('77000000-0000-0000-0000-000000000009'::uuid, 'SuccessfulDispatchTripClosed', 'DISPATCH', 'DispatchTrip', '56000000-0000-0000-0000-000000000902'::uuid, '96000000-0000-0000-0000-000000000009'::uuid),
  ('77000000-0000-0000-0000-000000000010'::uuid, 'DispatchLoadConfirmed', 'DISPATCH', 'DispatchLoad', '56000000-0000-0000-0000-000000000904'::uuid, '96000000-0000-0000-0000-000000000010'::uuid),
  ('77000000-0000-0000-0000-000000000011'::uuid, 'SuccessfulDeliveryConfirmed', 'DISPATCH', 'DeliveryConfirmation', '56000000-0000-0000-0000-000000000905'::uuid, '96000000-0000-0000-0000-000000000011'::uuid)
) v(audit_event_id, event_type, source_domain, aggregate_type, aggregate_id, command_id);

-- Separate correlations prove mixed location/trip and unsupported resolution.
insert into atlas_audit.domain_events
  (domain_event_id, event_type, source_domain, aggregate_type, aggregate_id,
   aggregate_version, command_id, correlation_id, actor_id, occurred_at)
values
  ('76000000-0000-0000-0000-000000000021', 'ScopeObserved', 'DISPATCH', 'DISPATCH_STOP', '56000000-0000-0000-0000-000000000903', 1, '96000000-0000-0000-0000-000000000021', '96000000-0000-0000-0000-000000000110', '16000000-0000-0000-0000-000000000001', timestamptz '2026-07-17 03:20:00+00'),
  ('76000000-0000-0000-0000-000000000022', 'ScopeObserved', 'DISPATCH', 'DISPATCH_STOP', '56000000-0000-0000-0000-000000000923', 1, '96000000-0000-0000-0000-000000000022', '96000000-0000-0000-0000-000000000110', '16000000-0000-0000-0000-000000000001', timestamptz '2026-07-17 03:20:00+00'),
  ('76000000-0000-0000-0000-000000000023', 'ScopeObserved', 'DISPATCH', 'DISPATCH_STOP', '56000000-0000-0000-0000-000000000903', 1, '96000000-0000-0000-0000-000000000023', '96000000-0000-0000-0000-000000000120', '16000000-0000-0000-0000-000000000001', timestamptz '2026-07-17 03:21:00+00'),
  ('76000000-0000-0000-0000-000000000024', 'ScopeObserved', 'DISPATCH', 'DISPATCH_STOP', '56000000-0000-0000-0000-000000000913', 1, '96000000-0000-0000-0000-000000000024', '96000000-0000-0000-0000-000000000120', '16000000-0000-0000-0000-000000000001', timestamptz '2026-07-17 03:21:00+00'),
  ('76000000-0000-0000-0000-000000000025', 'UnsupportedObserved', 'PLANNING', 'UnknownAggregate', '76000000-0000-0000-0000-000000000025', 1, '96000000-0000-0000-0000-000000000025', '96000000-0000-0000-0000-000000000130', '16000000-0000-0000-0000-000000000001', timestamptz '2026-07-17 03:22:00+00'),
  ('76000000-0000-0000-0000-000000000026', 'UnresolvableObserved', 'DISPATCH', 'DispatchTrip', '56000000-0000-0000-0000-000000000999', 1, '96000000-0000-0000-0000-000000000026', '96000000-0000-0000-0000-000000000140', '16000000-0000-0000-0000-000000000001', timestamptz '2026-07-17 03:22:00+00');

-- Every exact current aggregate type maps to the same canonical tuple.
select is(
  (select customer_id::text || '|' || delivery_location_id::text || '|' || dispatch_trip_id::text
   from atlas_core.pa_05c_aggregate_scope(v.aggregate_type, v.aggregate_id)),
  '26000000-0000-0000-0000-000000000100|26000000-0000-0000-0000-000000000101|56000000-0000-0000-0000-000000000902',
  v.aggregate_type || ' resolves to the canonical same-trip tuple'
)
from (values
  ('WholesaleOrder', '36000000-0000-0000-0000-000000000200'::uuid),
  ('PurchaseHandoff', '36000000-0000-0000-0000-000000000400'::uuid),
  ('DispatchRequirement', '36000000-0000-0000-0000-000000000500'::uuid),
  ('FulfilmentAllocation', '46000000-0000-0000-0000-000000000600'::uuid),
  ('PurchaseOrder', '46000000-0000-0000-0000-000000000700'::uuid),
  ('SupplierReceivingEvidence', '66000000-0000-0000-0000-000000000001'::uuid),
  ('EvidenceApplication', '66000000-0000-0000-0000-000000000002'::uuid),
  ('DispatchPlan', '56000000-0000-0000-0000-000000000900'::uuid),
  ('DispatchTrip', '56000000-0000-0000-0000-000000000902'::uuid),
  ('DispatchLoad', '56000000-0000-0000-0000-000000000904'::uuid),
  ('DeliveryConfirmation', '56000000-0000-0000-0000-000000000905'::uuid)
) v(aggregate_type, aggregate_id);

-- Every retained uppercase alias remains equivalent.
select is(
  (select customer_id::text || '|' || delivery_location_id::text || '|' || dispatch_trip_id::text
   from atlas_core.pa_05c_aggregate_scope(v.aggregate_type, v.aggregate_id)),
  '26000000-0000-0000-0000-000000000100|26000000-0000-0000-0000-000000000101|56000000-0000-0000-0000-000000000902',
  v.aggregate_type || ' remains a supported exact alias'
)
from (values
  ('SUPPLIER_RECEIVING_EVIDENCE', '66000000-0000-0000-0000-000000000001'::uuid),
  ('EVIDENCE_APPLICATION', '66000000-0000-0000-0000-000000000002'::uuid),
  ('DISPATCH_TRIP', '56000000-0000-0000-0000-000000000902'::uuid),
  ('DISPATCH_STOP', '56000000-0000-0000-0000-000000000903'::uuid),
  ('DISPATCH_LOAD', '56000000-0000-0000-0000-000000000904'::uuid),
  ('DELIVERY_CONFIRMATION', '56000000-0000-0000-0000-000000000905'::uuid),
  ('DISPATCH_REQUIREMENT', '36000000-0000-0000-0000-000000000500'::uuid)
) v(aggregate_type, aggregate_id);

select is(
  (select count(*)::integer
   from atlas_core.pa_05c_aggregate_scope(
     'wholesaleorder', '36000000-0000-0000-0000-000000000200'
   )),
  0,
  'arbitrary case-folded aggregate names remain unsupported'
);

create function pg_temp.pa05c_h2_request(subject uuid, payload jsonb)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'contract_version', 'PA-05C.v1',
    'requested_by_auth_subject', subject,
    'correlation_id', '96000000-0000-0000-0000-000000000199'::uuid,
    'payload', payload
  )
$$;

set local role authenticated;
set local request.jwt.claim.sub = '16000000-0000-0000-0000-000000000101';

select is(
  (atlas_api.get_command_audit_timeline(pg_temp.pa05c_h2_request(
    '16000000-0000-0000-0000-000000000101',
    jsonb_build_object('correlation_id', '96000000-0000-0000-0000-000000000100')
  )) ->> 'success'),
  'true',
  'GLOBAL actor reads the complete current same-trip correlation'
);

select is(
  jsonb_array_length(atlas_api.get_command_audit_timeline(pg_temp.pa05c_h2_request(
    '16000000-0000-0000-0000-000000000101',
    jsonb_build_object('correlation_id', '96000000-0000-0000-0000-000000000100')
  )) -> 'domain_events'),
  11,
  'complete correlation returns every selected domain event'
);

select is(
  jsonb_array_length(atlas_api.get_command_audit_timeline(pg_temp.pa05c_h2_request(
    '16000000-0000-0000-0000-000000000101',
    jsonb_build_object('correlation_id', '96000000-0000-0000-0000-000000000100')
  )) -> 'audit_events'),
  11,
  'complete correlation returns every selected audit event'
);

select ok(
  exists (
    select 1
    from jsonb_array_elements(atlas_api.get_command_audit_timeline(pg_temp.pa05c_h2_request(
      '16000000-0000-0000-0000-000000000101',
      jsonb_build_object('correlation_id', '96000000-0000-0000-0000-000000000100')
    )) -> 'domain_events') e
    where e ->> 'event_type' = 'SuccessfulDispatchTripClosed'
  ),
  'complete correlation includes SuccessfulDispatchTripClosed'
);

select ok(
  (atlas_api.get_command_audit_timeline(pg_temp.pa05c_h2_request(
    '16000000-0000-0000-0000-000000000101',
    jsonb_build_object('correlation_id', '96000000-0000-0000-0000-000000000100')
  )) ->> 'event_limit')::integer = 100
  and jsonb_array_length(atlas_api.get_command_audit_timeline(pg_temp.pa05c_h2_request(
    '16000000-0000-0000-0000-000000000101',
    jsonb_build_object('correlation_id', '96000000-0000-0000-0000-000000000100')
  )) -> 'domain_events')
    + jsonb_array_length(atlas_api.get_command_audit_timeline(pg_temp.pa05c_h2_request(
      '16000000-0000-0000-0000-000000000101',
      jsonb_build_object('correlation_id', '96000000-0000-0000-0000-000000000100')
    )) -> 'audit_events') < 100,
  'complete correlation remains below the unchanged 100-event bound'
);

select is(
  (atlas_api.get_command_audit_timeline(pg_temp.pa05c_h2_request(
    '16000000-0000-0000-0000-000000000101',
    jsonb_build_object('aggregate_type', 'DispatchPlan', 'aggregate_id', '56000000-0000-0000-0000-000000000900')
  )) ->> 'success'),
  'true',
  'current CamelCase aggregate selector succeeds'
);

select is(
  (atlas_api.get_command_audit_timeline(pg_temp.pa05c_h2_request(
    '16000000-0000-0000-0000-000000000101',
    jsonb_build_object('command_id', '96000000-0000-0000-0000-000000000001')
  )) ->> 'success'),
  'true',
  'current command-ID selector succeeds'
);

set local request.jwt.claim.sub = '16000000-0000-0000-0000-000000000102';

select is(
  (atlas_api.get_command_audit_timeline(pg_temp.pa05c_h2_request(
    '16000000-0000-0000-0000-000000000102',
    jsonb_build_object('correlation_id', '96000000-0000-0000-0000-000000000100')
  )) ->> 'success'),
  'true',
  'matching DISPATCH_TRIP-scoped actor reads the complete upstream-to-trip correlation'
);

select ok(
  jsonb_array_length(atlas_api.get_command_audit_timeline(pg_temp.pa05c_h2_request(
    '16000000-0000-0000-0000-000000000102',
    jsonb_build_object('correlation_id', '96000000-0000-0000-0000-000000000100')
  )) -> 'domain_events') = 11
  and jsonb_array_length(atlas_api.get_command_audit_timeline(pg_temp.pa05c_h2_request(
    '16000000-0000-0000-0000-000000000102',
    jsonb_build_object('correlation_id', '96000000-0000-0000-0000-000000000100')
  )) -> 'audit_events') = 11,
  'trip-scoped actor receives every selected domain and audit row'
);

set local request.jwt.claim.sub = '16000000-0000-0000-0000-000000000103';

select is(
  (atlas_api.get_command_audit_timeline(pg_temp.pa05c_h2_request(
    '16000000-0000-0000-0000-000000000103',
    jsonb_build_object('correlation_id', '96000000-0000-0000-0000-000000000100')
  )) ->> 'error_code'),
  'SCOPE_DENIED',
  'actor missing the required trip scope is denied'
);

set local request.jwt.claim.sub = '16000000-0000-0000-0000-000000000101';

select is(
  (atlas_api.get_command_audit_timeline(pg_temp.pa05c_h2_request(
    '16000000-0000-0000-0000-000000000101',
    jsonb_build_object('correlation_id', '96000000-0000-0000-0000-000000000110')
  )) ->> 'error_code'),
  'AMBIGUOUS_SCOPE',
  'correlation spanning another delivery location fails closed'
);

select is(
  (atlas_api.get_command_audit_timeline(pg_temp.pa05c_h2_request(
    '16000000-0000-0000-0000-000000000101',
    jsonb_build_object('correlation_id', '96000000-0000-0000-0000-000000000120')
  )) ->> 'error_code'),
  'AMBIGUOUS_SCOPE',
  'correlation spanning another trip fails closed'
);

select is(
  (atlas_api.get_command_audit_timeline(pg_temp.pa05c_h2_request(
    '16000000-0000-0000-0000-000000000101',
    jsonb_build_object('aggregate_type', 'UnknownAggregate', 'aggregate_id', '76000000-0000-0000-0000-000000000025')
  )) ->> 'error_code'),
  'NOT_FOUND_OR_UNSUPPORTED',
  'unsupported aggregate type fails with the established safe behavior'
);

select is(
  (atlas_api.get_command_audit_timeline(pg_temp.pa05c_h2_request(
    '16000000-0000-0000-0000-000000000101',
    jsonb_build_object('aggregate_type', 'DispatchTrip', 'aggregate_id', '56000000-0000-0000-0000-000000000999')
  )) ->> 'error_code'),
  'NOT_FOUND_OR_UNSUPPORTED',
  'supported but unresolvable aggregate fails closed'
);

select ok(
  atlas_api.get_command_audit_timeline(pg_temp.pa05c_h2_request(
    '16000000-0000-0000-0000-000000000101',
    jsonb_build_object('correlation_id', '96000000-0000-0000-0000-000000000100')
  ))::text !~* '(request_hash|response_payload|credential|jwt|service.role|sql internals|policy internals|stack trace)',
  'timeline excludes request hashes stored responses credentials JWT service-role SQL policy and stack internals'
);

reset role;

select is((select count(*)::integer from atlas_core.command_receipts), 0, 'reads create no command receipt');
select is((select count(*)::integer from atlas_audit.domain_events), 17, 'reads create no domain event');
select is((select count(*)::integer from atlas_audit.audit_events), 11, 'reads create no audit event');
select is((select count(*)::integer from atlas_dispatch.dispatch_loads), 1, 'reads create no business mutation');

select * from finish();
rollback;
