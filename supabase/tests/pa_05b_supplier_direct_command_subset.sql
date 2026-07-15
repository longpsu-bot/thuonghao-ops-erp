begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;

select no_plan();

-- These grants exist only inside this rolled-back test transaction so the
-- authenticated role can invoke pgTAP assertions and write temporary results.
grant usage on schema extensions to authenticated;
grant execute on all functions in schema extensions to authenticated;

select ok(
  not exists (
    select 1
    from unnest(array['anon', 'authenticated', 'service_role']) api_role(role_name)
    cross join unnest(
      array[
        'atlas_core', 'atlas_admin', 'atlas_planning', 'atlas_procurement',
        'atlas_evidence', 'atlas_dispatch', 'atlas_audit', 'atlas_reporting'
      ]
    ) private_schema(schema_name)
    where has_schema_privilege(api_role.role_name, private_schema.schema_name, 'USAGE')
  ),
  'API roles retain no usage on private Atlas schemas'
);

select ok(
  has_schema_privilege('authenticated', 'atlas_api', 'USAGE')
  and not has_schema_privilege('anon', 'atlas_api', 'USAGE')
  and not has_schema_privilege('service_role', 'atlas_api', 'USAGE'),
  'only authenticated receives atlas_api schema usage'
);

select ok(
  not exists (
    select 1
    from unnest(array['anon', 'authenticated', 'service_role']) api_role(role_name)
    cross join pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname like 'atlas\_%' escape '\'
      and c.relkind in ('r', 'v', 'm')
      and (
        has_table_privilege(api_role.role_name, c.oid, 'SELECT')
        or has_table_privilege(api_role.role_name, c.oid, 'INSERT')
        or has_table_privilege(api_role.role_name, c.oid, 'UPDATE')
        or has_table_privilege(api_role.role_name, c.oid, 'DELETE')
      )
  ),
  'anon, authenticated, and service_role have no direct Atlas table or view access'
);

select is(
  (
    select count(*)::integer
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
      and p.proname in (
        'record_supplier_receiving_evidence',
        'apply_supplier_evidence_to_allocation',
        'confirm_dispatch_load',
        'record_dispatch_departure',
        'confirm_successful_delivery',
        'get_supplier_direct_trace'
      )
      and has_function_privilege('authenticated', p.oid, 'EXECUTE')
  ),
  6,
  'authenticated can execute exactly the six approved PA-05B functions'
);

select ok(
  not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    cross join unnest(array['anon', 'service_role']) api_role(role_name)
    where n.nspname = 'atlas_api'
      and has_function_privilege(api_role.role_name, p.oid, 'EXECUTE')
  ),
  'anon and service_role cannot execute PA-05B functions'
);

select ok(
  not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    join pg_roles r on r.oid = p.proowner
    where n.nspname = 'atlas_api'
      and p.proname in (
        'record_supplier_receiving_evidence',
        'apply_supplier_evidence_to_allocation',
        'confirm_dispatch_load',
        'record_dispatch_departure',
        'confirm_successful_delivery',
        'get_supplier_direct_trace'
      )
      and (
        not p.prosecdef
        or p.proconfig is null
        or p.proconfig::text not like '%search_path=%'
        or (
          p.proname = 'get_supplier_direct_trace'
          and r.rolname <> 'atlas_read_runtime'
        )
        or (
          p.proname <> 'get_supplier_direct_trace'
          and r.rolname <> 'atlas_evidence_command_runtime'
          and p.proname in (
            'record_supplier_receiving_evidence',
            'apply_supplier_evidence_to_allocation'
          )
        )
        or (
          p.proname in (
            'confirm_dispatch_load',
            'record_dispatch_departure',
            'confirm_successful_delivery'
          )
          and r.rolname <> 'atlas_dispatch_command_runtime'
        )
      )
  ),
  'all PA-05B entry functions are hardened definers owned by their narrowed runtime roles'
);

set local role authenticated;
select throws_ok(
  $$
    insert into atlas_evidence.supplier_receiving_evidence (
      supplier_id, purchase_order_line_revision_id, ingredient_id,
      evidence_reference, evidence_quantity, unit_id, occurred_at,
      recorded_by_actor_id, command_id, correlation_id
    ) values (
      gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
      'denied', 1, gen_random_uuid(), transaction_timestamp(),
      gen_random_uuid(), gen_random_uuid(), gen_random_uuid()
    )
  $$,
  '42501',
  'permission denied for schema atlas_evidence',
  'authenticated direct insert into a private domain table is denied'
);
reset role;

-- Authorization vocabulary and actors are synthetic, rolled back fixtures.
insert into atlas_core.actors (
  actor_id, actor_type, display_name, actor_status, deactivated_at
) values
  ('10000000-0000-0000-0000-000000000001', 'HUMAN', 'PA-05B authorized operator', 'ACTIVE', null),
  ('10000000-0000-0000-0000-000000000002', 'HUMAN', 'PA-05B inactive actor', 'INACTIVE', timestamptz '2026-07-15 00:00:00+00'),
  ('10000000-0000-0000-0000-000000000003', 'HUMAN', 'PA-05B revoked subject actor', 'ACTIVE', null),
  ('10000000-0000-0000-0000-000000000004', 'HUMAN', 'PA-05B wrong capability actor', 'ACTIVE', null),
  ('10000000-0000-0000-0000-000000000005', 'HUMAN', 'PA-05B wrong scope actor', 'ACTIVE', null);

insert into atlas_core.actor_auth_subjects (
  actor_auth_subject_id, actor_id, auth_subject_id, subject_status, revoked_at
) values
  ('10000000-0000-0000-0000-000000000011', '10000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000101', 'ACTIVE', null),
  ('10000000-0000-0000-0000-000000000012', '10000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000102', 'ACTIVE', null),
  ('10000000-0000-0000-0000-000000000013', '10000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000103', 'REVOKED', timestamptz '2026-07-15 00:01:00+00'),
  ('10000000-0000-0000-0000-000000000014', '10000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000104', 'ACTIVE', null),
  ('10000000-0000-0000-0000-000000000015', '10000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000105', 'ACTIVE', null);

insert into atlas_core.roles (role_id, role_code, role_name) values
  ('11000000-0000-0000-0000-000000000001', 'pa05b.operator', 'PA-05B operator'),
  ('11000000-0000-0000-0000-000000000002', 'pa05b.trace_only', 'PA-05B trace-only role');

insert into atlas_core.capabilities (
  capability_id, capability_code, capability_name, owning_domain
) values
  ('12000000-0000-0000-0000-000000000001', 'supplier_receiving_evidence.record', 'Record supplier evidence', 'EVIDENCE'),
  ('12000000-0000-0000-0000-000000000002', 'supplier_evidence_application.apply', 'Apply supplier evidence', 'EVIDENCE'),
  ('12000000-0000-0000-0000-000000000003', 'dispatch_load.confirm', 'Confirm dispatch load', 'DISPATCH'),
  ('12000000-0000-0000-0000-000000000004', 'dispatch_departure.record', 'Record dispatch departure', 'DISPATCH'),
  ('12000000-0000-0000-0000-000000000005', 'delivery_success.confirm', 'Confirm successful delivery', 'DISPATCH'),
  ('12000000-0000-0000-0000-000000000006', 'supplier_direct_trace.read', 'Read supplier-direct trace', 'AUDIT');

insert into atlas_core.role_capabilities (role_id, capability_id)
select '11000000-0000-0000-0000-000000000001'::uuid, c.capability_id
from atlas_core.capabilities c
where c.capability_code in (
  'supplier_receiving_evidence.record',
  'supplier_evidence_application.apply',
  'dispatch_load.confirm',
  'dispatch_departure.record',
  'delivery_success.confirm',
  'supplier_direct_trace.read'
);

insert into atlas_core.role_capabilities (role_id, capability_id)
select '11000000-0000-0000-0000-000000000002'::uuid, c.capability_id
from atlas_core.capabilities c
where c.capability_code = 'supplier_direct_trace.read';

insert into atlas_core.actor_role_memberships (actor_id, role_id) values
  ('10000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000001'),
  ('10000000-0000-0000-0000-000000000002', '11000000-0000-0000-0000-000000000001'),
  ('10000000-0000-0000-0000-000000000003', '11000000-0000-0000-0000-000000000001'),
  ('10000000-0000-0000-0000-000000000004', '11000000-0000-0000-0000-000000000002'),
  ('10000000-0000-0000-0000-000000000005', '11000000-0000-0000-0000-000000000001');

insert into atlas_admin.customers (
  customer_id, customer_code, customer_name
) values
  ('20000000-0000-0000-0000-000000000100', 'pa05b-customer', 'PA-05B wholesale customer'),
  ('20000000-0000-0000-0000-000000000110', 'pa05b-other-customer', 'PA-05B other customer');

insert into atlas_admin.delivery_locations (
  delivery_location_id, customer_id, location_code, location_name, address_text
) values
  ('20000000-0000-0000-0000-000000000101', '20000000-0000-0000-0000-000000000100', 'pa05b-location', 'PA-05B delivery location', 'PA-05B test address'),
  ('20000000-0000-0000-0000-000000000111', '20000000-0000-0000-0000-000000000110', 'pa05b-other-location', 'PA-05B other location', 'PA-05B other address');

insert into atlas_admin.units (unit_id, unit_code, unit_name, dimension_code) values
  ('20000000-0000-0000-0000-000000000102', 'pa05b-kg', 'PA-05B kilogram', 'mass');

insert into atlas_admin.ingredients (ingredient_id, ingredient_code, ingredient_name) values
  ('20000000-0000-0000-0000-000000000103', 'pa05b-rice', 'PA-05B rice');

insert into atlas_admin.suppliers (supplier_id, supplier_code, supplier_name) values
  ('20000000-0000-0000-0000-000000000104', 'pa05b-supplier', 'PA-05B supplier');

insert into atlas_core.actor_scopes (actor_id, scope_kind, customer_id) values
  ('10000000-0000-0000-0000-000000000001', 'CUSTOMER', '20000000-0000-0000-0000-000000000100'),
  ('10000000-0000-0000-0000-000000000005', 'CUSTOMER', '20000000-0000-0000-0000-000000000110');
insert into atlas_core.actor_scopes (actor_id, scope_kind) values
  ('10000000-0000-0000-0000-000000000002', 'GLOBAL'),
  ('10000000-0000-0000-0000-000000000003', 'GLOBAL'),
  ('10000000-0000-0000-0000-000000000004', 'GLOBAL');

-- Synthetic released Planning and Procurement prerequisites.
insert into atlas_planning.wholesale_orders (
  wholesale_order_id, customer_id, delivery_location_id,
  customer_order_reference, service_date, order_status,
  created_by_actor_id, approved_by_actor_id, approved_at,
  released_by_actor_id, released_at
) values (
  '30000000-0000-0000-0000-000000000200',
  '20000000-0000-0000-0000-000000000100',
  '20000000-0000-0000-0000-000000000101',
  'PA05B-ORDER-001', date '2026-07-15', 'RELEASED',
  '10000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001', timestamptz '2026-07-15 00:05:00+00',
  '10000000-0000-0000-0000-000000000001', timestamptz '2026-07-15 00:10:00+00'
);

insert into atlas_planning.wholesale_order_lines (
  wholesale_order_line_id, wholesale_order_id, source_line_number
) values
  ('30000000-0000-0000-0000-000000000201', '30000000-0000-0000-0000-000000000200', 1),
  ('30000000-0000-0000-0000-000000000203', '30000000-0000-0000-0000-000000000200', 2),
  ('30000000-0000-0000-0000-000000000205', '30000000-0000-0000-0000-000000000200', 3);

insert into atlas_planning.wholesale_order_line_revisions (
  wholesale_order_line_revision_id, wholesale_order_line_id, revision_number,
  ingredient_id, requested_quantity, unit_id, revision_status, created_by_actor_id
) values
  ('30000000-0000-0000-0000-000000000202', '30000000-0000-0000-0000-000000000201', 1, '20000000-0000-0000-0000-000000000103', 10, '20000000-0000-0000-0000-000000000102', 'RELEASED', '10000000-0000-0000-0000-000000000001'),
  ('30000000-0000-0000-0000-000000000204', '30000000-0000-0000-0000-000000000203', 1, '20000000-0000-0000-0000-000000000103', 10, '20000000-0000-0000-0000-000000000102', 'RELEASED', '10000000-0000-0000-0000-000000000001'),
  ('30000000-0000-0000-0000-000000000206', '30000000-0000-0000-0000-000000000205', 1, '20000000-0000-0000-0000-000000000103', 5, '20000000-0000-0000-0000-000000000102', 'RELEASED', '10000000-0000-0000-0000-000000000001');

insert into atlas_planning.confirmed_need_batches (
  confirmed_need_batch_id, wholesale_order_id, period_start, period_end,
  batch_status, created_by_actor_id, approved_by_actor_id, approved_at,
  released_by_actor_id, released_at
) values (
  '30000000-0000-0000-0000-000000000300',
  '30000000-0000-0000-0000-000000000200',
  date '2026-07-15', date '2026-07-15', 'RELEASED_FOR_PURCHASE_HANDOFF',
  '10000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001', timestamptz '2026-07-15 00:15:00+00',
  '10000000-0000-0000-0000-000000000001', timestamptz '2026-07-15 00:20:00+00'
);

insert into atlas_planning.confirmed_need_lines (
  confirmed_need_line_id, confirmed_need_batch_id, wholesale_order_line_id
) values
  ('30000000-0000-0000-0000-000000000301', '30000000-0000-0000-0000-000000000300', '30000000-0000-0000-0000-000000000201'),
  ('30000000-0000-0000-0000-000000000303', '30000000-0000-0000-0000-000000000300', '30000000-0000-0000-0000-000000000203'),
  ('30000000-0000-0000-0000-000000000305', '30000000-0000-0000-0000-000000000300', '30000000-0000-0000-0000-000000000205');

insert into atlas_planning.confirmed_need_line_revisions (
  confirmed_need_line_revision_id, confirmed_need_line_id, revision_number,
  wholesale_order_line_revision_id, ingredient_id, theoretical_quantity,
  confirmed_quantity, unit_id, revision_status, created_by_actor_id
) values
  ('30000000-0000-0000-0000-000000000302', '30000000-0000-0000-0000-000000000301', 1, '30000000-0000-0000-0000-000000000202', '20000000-0000-0000-0000-000000000103', 10, 10, '20000000-0000-0000-0000-000000000102', 'RELEASED', '10000000-0000-0000-0000-000000000001'),
  ('30000000-0000-0000-0000-000000000304', '30000000-0000-0000-0000-000000000303', 1, '30000000-0000-0000-0000-000000000204', '20000000-0000-0000-0000-000000000103', 10, 10, '20000000-0000-0000-0000-000000000102', 'RELEASED', '10000000-0000-0000-0000-000000000001'),
  ('30000000-0000-0000-0000-000000000306', '30000000-0000-0000-0000-000000000305', 1, '30000000-0000-0000-0000-000000000206', '20000000-0000-0000-0000-000000000103', 5, 5, '20000000-0000-0000-0000-000000000102', 'RELEASED', '10000000-0000-0000-0000-000000000001');

insert into atlas_planning.purchase_handoff_batches (
  purchase_handoff_batch_id, confirmed_need_batch_id, period_start, period_end,
  handoff_status, created_by_actor_id
) values (
  '30000000-0000-0000-0000-000000000400',
  '30000000-0000-0000-0000-000000000300',
  date '2026-07-15', date '2026-07-15', 'RELEASED_TO_PROCUREMENT',
  '10000000-0000-0000-0000-000000000001'
);

insert into atlas_planning.purchase_handoff_revisions (
  purchase_handoff_revision_id, purchase_handoff_batch_id, revision_number,
  revision_status, released_by_actor_id, released_at
) values (
  '30000000-0000-0000-0000-000000000401',
  '30000000-0000-0000-0000-000000000400', 1, 'RELEASED_TO_PROCUREMENT',
  '10000000-0000-0000-0000-000000000001', timestamptz '2026-07-15 00:25:00+00'
);

insert into atlas_planning.purchase_handoff_lines (
  purchase_handoff_line_id, purchase_handoff_batch_id, confirmed_need_line_id
) values
  ('30000000-0000-0000-0000-000000000402', '30000000-0000-0000-0000-000000000400', '30000000-0000-0000-0000-000000000301'),
  ('30000000-0000-0000-0000-000000000404', '30000000-0000-0000-0000-000000000400', '30000000-0000-0000-0000-000000000303'),
  ('30000000-0000-0000-0000-000000000406', '30000000-0000-0000-0000-000000000400', '30000000-0000-0000-0000-000000000305');

insert into atlas_planning.purchase_handoff_line_revisions (
  purchase_handoff_line_revision_id, purchase_handoff_revision_id,
  purchase_handoff_line_id, confirmed_need_line_revision_id, ingredient_id,
  handoff_quantity, unit_id, service_date, delivery_location_id
) values
  ('30000000-0000-0000-0000-000000000403', '30000000-0000-0000-0000-000000000401', '30000000-0000-0000-0000-000000000402', '30000000-0000-0000-0000-000000000302', '20000000-0000-0000-0000-000000000103', 10, '20000000-0000-0000-0000-000000000102', date '2026-07-15', '20000000-0000-0000-0000-000000000101'),
  ('30000000-0000-0000-0000-000000000405', '30000000-0000-0000-0000-000000000401', '30000000-0000-0000-0000-000000000404', '30000000-0000-0000-0000-000000000304', '20000000-0000-0000-0000-000000000103', 10, '20000000-0000-0000-0000-000000000102', date '2026-07-15', '20000000-0000-0000-0000-000000000101'),
  ('30000000-0000-0000-0000-000000000407', '30000000-0000-0000-0000-000000000401', '30000000-0000-0000-0000-000000000406', '30000000-0000-0000-0000-000000000306', '20000000-0000-0000-0000-000000000103', 5, '20000000-0000-0000-0000-000000000102', date '2026-07-15', '20000000-0000-0000-0000-000000000101');

insert into atlas_planning.dispatch_requirements (
  dispatch_requirement_id, customer_id, delivery_location_id, service_date, requirement_status
) values (
  '30000000-0000-0000-0000-000000000500',
  '20000000-0000-0000-0000-000000000100',
  '20000000-0000-0000-0000-000000000101',
  date '2026-07-15', 'RELEASED'
);

insert into atlas_planning.dispatch_requirement_revisions (
  dispatch_requirement_revision_id, dispatch_requirement_id,
  purchase_handoff_revision_id, revision_number, revision_status,
  customer_name_snapshot, location_name_snapshot, address_snapshot,
  released_by_actor_id, released_at
) values (
  '30000000-0000-0000-0000-000000000501',
  '30000000-0000-0000-0000-000000000500',
  '30000000-0000-0000-0000-000000000401', 1, 'RELEASED',
  'PA-05B wholesale customer', 'PA-05B delivery location', 'PA-05B test address',
  '10000000-0000-0000-0000-000000000001', timestamptz '2026-07-15 00:30:00+00'
);

insert into atlas_planning.dispatch_requirement_lines (
  dispatch_requirement_line_id, dispatch_requirement_id, purchase_handoff_line_id
) values
  ('30000000-0000-0000-0000-000000000502', '30000000-0000-0000-0000-000000000500', '30000000-0000-0000-0000-000000000402'),
  ('30000000-0000-0000-0000-000000000504', '30000000-0000-0000-0000-000000000500', '30000000-0000-0000-0000-000000000404'),
  ('30000000-0000-0000-0000-000000000506', '30000000-0000-0000-0000-000000000500', '30000000-0000-0000-0000-000000000406');

insert into atlas_planning.dispatch_requirement_line_revisions (
  dispatch_requirement_line_revision_id, dispatch_requirement_revision_id,
  dispatch_requirement_line_id, purchase_handoff_line_revision_id,
  ingredient_id, required_quantity, unit_id
) values
  ('30000000-0000-0000-0000-000000000503', '30000000-0000-0000-0000-000000000501', '30000000-0000-0000-0000-000000000502', '30000000-0000-0000-0000-000000000403', '20000000-0000-0000-0000-000000000103', 10, '20000000-0000-0000-0000-000000000102'),
  ('30000000-0000-0000-0000-000000000505', '30000000-0000-0000-0000-000000000501', '30000000-0000-0000-0000-000000000504', '30000000-0000-0000-0000-000000000405', '20000000-0000-0000-0000-000000000103', 10, '20000000-0000-0000-0000-000000000102'),
  ('30000000-0000-0000-0000-000000000507', '30000000-0000-0000-0000-000000000501', '30000000-0000-0000-0000-000000000506', '30000000-0000-0000-0000-000000000407', '20000000-0000-0000-0000-000000000103', 5, '20000000-0000-0000-0000-000000000102');

insert into atlas_procurement.fulfilment_allocations (
  fulfilment_allocation_id, dispatch_requirement_id, allocation_status
) values (
  '40000000-0000-0000-0000-000000000600',
  '30000000-0000-0000-0000-000000000500', 'READY_FOR_DISPATCH'
);

insert into atlas_procurement.fulfilment_allocation_revisions (
  fulfilment_allocation_revision_id, fulfilment_allocation_id,
  revision_number, revision_status, allocated_by_actor_id
) values (
  '40000000-0000-0000-0000-000000000601',
  '40000000-0000-0000-0000-000000000600', 1, 'READY_FOR_DISPATCH',
  '10000000-0000-0000-0000-000000000001'
);

insert into atlas_procurement.fulfilment_allocation_lines (
  fulfilment_allocation_line_id, fulfilment_allocation_id,
  dispatch_requirement_line_id, portion_sequence
) values
  ('40000000-0000-0000-0000-000000000602', '40000000-0000-0000-0000-000000000600', '30000000-0000-0000-0000-000000000502', 1),
  ('40000000-0000-0000-0000-000000000604', '40000000-0000-0000-0000-000000000600', '30000000-0000-0000-0000-000000000504', 1),
  ('40000000-0000-0000-0000-000000000606', '40000000-0000-0000-0000-000000000600', '30000000-0000-0000-0000-000000000506', 1);

insert into atlas_procurement.fulfilment_allocation_line_revisions (
  fulfilment_allocation_line_revision_id, fulfilment_allocation_revision_id,
  fulfilment_allocation_line_id, dispatch_requirement_line_revision_id,
  supplier_id, allocated_quantity, unit_id, line_status
) values
  ('40000000-0000-0000-0000-000000000603', '40000000-0000-0000-0000-000000000601', '40000000-0000-0000-0000-000000000602', '30000000-0000-0000-0000-000000000503', '20000000-0000-0000-0000-000000000104', 10, '20000000-0000-0000-0000-000000000102', 'READY_FOR_EVIDENCE'),
  ('40000000-0000-0000-0000-000000000605', '40000000-0000-0000-0000-000000000601', '40000000-0000-0000-0000-000000000604', '30000000-0000-0000-0000-000000000505', '20000000-0000-0000-0000-000000000104', 10, '20000000-0000-0000-0000-000000000102', 'READY_FOR_EVIDENCE'),
  ('40000000-0000-0000-0000-000000000607', '40000000-0000-0000-0000-000000000601', '40000000-0000-0000-0000-000000000606', '30000000-0000-0000-0000-000000000507', '20000000-0000-0000-0000-000000000104', 5, '20000000-0000-0000-0000-000000000102', 'READY_FOR_EVIDENCE');

insert into atlas_procurement.purchase_orders (
  purchase_order_id, supplier_id, document_number, purchase_order_status
) values (
  '40000000-0000-0000-0000-000000000700',
  '20000000-0000-0000-0000-000000000104', 'PA05B-PO-001', 'RELEASED_TO_SUPPLIER'
);

insert into atlas_procurement.purchase_order_revisions (
  purchase_order_revision_id, purchase_order_id, revision_number,
  revision_status, service_date, delivery_location_id,
  supplier_name_snapshot, delivery_location_snapshot,
  released_by_actor_id, released_at
) values (
  '40000000-0000-0000-0000-000000000701',
  '40000000-0000-0000-0000-000000000700', 1, 'RELEASED_TO_SUPPLIER',
  date '2026-07-15', '20000000-0000-0000-0000-000000000101',
  'PA-05B supplier', 'PA-05B delivery location',
  '10000000-0000-0000-0000-000000000001', timestamptz '2026-07-15 00:40:00+00'
);

insert into atlas_procurement.purchase_order_lines (
  purchase_order_line_id, purchase_order_id, fulfilment_allocation_line_id
) values (
  '40000000-0000-0000-0000-000000000702',
  '40000000-0000-0000-0000-000000000700',
  '40000000-0000-0000-0000-000000000602'
);

insert into atlas_procurement.purchase_order_line_revisions (
  purchase_order_line_revision_id, purchase_order_revision_id,
  purchase_order_line_id, fulfilment_allocation_line_revision_id,
  ingredient_id, ordered_quantity, unit_id, delivery_location_id, service_date
) values (
  '40000000-0000-0000-0000-000000000703',
  '40000000-0000-0000-0000-000000000701',
  '40000000-0000-0000-0000-000000000702',
  '40000000-0000-0000-0000-000000000603',
  '20000000-0000-0000-0000-000000000103', 10,
  '20000000-0000-0000-0000-000000000102',
  '20000000-0000-0000-0000-000000000101', date '2026-07-15'
);

-- Synthetic Dispatch plan/trip/stop prerequisites for independent scenarios.
insert into atlas_dispatch.dispatch_plans (
  dispatch_plan_id, plan_reference, service_date, created_by_actor_id
) values (
  '50000000-0000-0000-0000-000000000900', 'PA05B-PLAN-001', date '2026-07-15',
  '10000000-0000-0000-0000-000000000001'
);

insert into atlas_dispatch.dispatch_plan_requirements (
  dispatch_plan_requirement_id, dispatch_plan_id,
  dispatch_requirement_revision_id, fulfilment_allocation_revision_id
) values (
  '50000000-0000-0000-0000-000000000901',
  '50000000-0000-0000-0000-000000000900',
  '30000000-0000-0000-0000-000000000501',
  '40000000-0000-0000-0000-000000000601'
);

insert into atlas_dispatch.dispatch_trips (
  dispatch_trip_id, dispatch_plan_id, trip_reference, trip_status,
  driver_actor_id, vehicle_reference, planned_departure_at
) values
  ('50000000-0000-0000-0000-000000000902', '50000000-0000-0000-0000-000000000900', 'PA05B-TRIP-MAIN', 'ASSIGNED', '10000000-0000-0000-0000-000000000001', 'PA05B-VEHICLE-1', timestamptz '2026-07-15 01:00:00+00'),
  ('50000000-0000-0000-0000-000000000912', '50000000-0000-0000-0000-000000000900', 'PA05B-TRIP-INSUFFICIENT', 'ASSIGNED', '10000000-0000-0000-0000-000000000001', 'PA05B-VEHICLE-2', timestamptz '2026-07-15 01:05:00+00'),
  ('50000000-0000-0000-0000-000000000922', '50000000-0000-0000-0000-000000000900', 'PA05B-TRIP-VOID', 'ASSIGNED', '10000000-0000-0000-0000-000000000001', 'PA05B-VEHICLE-3', timestamptz '2026-07-15 01:10:00+00');

insert into atlas_dispatch.dispatch_stops (
  dispatch_stop_id, dispatch_trip_id, stop_sequence,
  dispatch_requirement_revision_id, customer_id, delivery_location_id
) values
  ('50000000-0000-0000-0000-000000000903', '50000000-0000-0000-0000-000000000902', 1, '30000000-0000-0000-0000-000000000501', '20000000-0000-0000-0000-000000000100', '20000000-0000-0000-0000-000000000101'),
  ('50000000-0000-0000-0000-000000000913', '50000000-0000-0000-0000-000000000912', 1, '30000000-0000-0000-0000-000000000501', '20000000-0000-0000-0000-000000000100', '20000000-0000-0000-0000-000000000101'),
  ('50000000-0000-0000-0000-000000000923', '50000000-0000-0000-0000-000000000922', 1, '30000000-0000-0000-0000-000000000501', '20000000-0000-0000-0000-000000000100', '20000000-0000-0000-0000-000000000101');

-- Requests are constructed by the fixture owner, then invoked as the actual
-- authenticated API role with an auth.uid()-compatible JWT subject setting.
create temporary table pa05b_requests (
  request_name text primary key,
  request_payload jsonb not null
);

create temporary table pa05b_results (
  result_name text primary key,
  response_payload jsonb not null
);

grant select on pa05b_requests to authenticated;
grant select, insert, update on pa05b_results to authenticated;

create function pg_temp.pa05b_request(
  command_id uuid,
  idempotency_key text,
  expected_version bigint,
  requested_by_auth_subject uuid,
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
    'correlation_id', '90000000-0000-0000-0000-000000000001'::uuid,
    'idempotency_key', idempotency_key,
    'expected_version', expected_version,
    'requested_by_auth_subject', requested_by_auth_subject,
    'requested_at', '2026-07-15T00:45:00+00:00',
    'reason_code', 'PA05B_TEST',
    'reason_note', 'PA-05B pgTAP',
    'payload', payload
  )
$$;

insert into pa05b_requests (request_name, request_payload) values
  (
    'auth_subject_mismatch',
    pg_temp.pa05b_request(
      '90000000-0000-0000-0000-000000000101', 'pa05b-auth-mismatch', 1,
      '10000000-0000-0000-0000-000000000102',
      jsonb_build_object(
        'purchase_order_line_revision_id', '40000000-0000-0000-0000-000000000703',
        'supplier_id', '20000000-0000-0000-0000-000000000104',
        'ingredient_id', '20000000-0000-0000-0000-000000000103',
        'unit_id', '20000000-0000-0000-0000-000000000102',
        'evidence_quantity', 1,
        'evidence_reference', 'PA05B-AUTH-MISMATCH',
        'occurred_at', '2026-07-15T00:46:00+00:00'
      )
    )
  ),
  (
    'inactive_actor',
    pg_temp.pa05b_request(
      '90000000-0000-0000-0000-000000000102', 'pa05b-inactive-actor', 1,
      '10000000-0000-0000-0000-000000000102',
      jsonb_build_object(
        'purchase_order_line_revision_id', '40000000-0000-0000-0000-000000000703',
        'supplier_id', '20000000-0000-0000-0000-000000000104',
        'ingredient_id', '20000000-0000-0000-0000-000000000103',
        'unit_id', '20000000-0000-0000-0000-000000000102',
        'evidence_quantity', 1,
        'evidence_reference', 'PA05B-INACTIVE-ACTOR',
        'occurred_at', '2026-07-15T00:46:00+00:00'
      )
    )
  ),
  (
    'inactive_subject',
    pg_temp.pa05b_request(
      '90000000-0000-0000-0000-000000000103', 'pa05b-inactive-subject', 1,
      '10000000-0000-0000-0000-000000000103',
      jsonb_build_object(
        'purchase_order_line_revision_id', '40000000-0000-0000-0000-000000000703',
        'supplier_id', '20000000-0000-0000-0000-000000000104',
        'ingredient_id', '20000000-0000-0000-0000-000000000103',
        'unit_id', '20000000-0000-0000-0000-000000000102',
        'evidence_quantity', 1,
        'evidence_reference', 'PA05B-INACTIVE-SUBJECT',
        'occurred_at', '2026-07-15T00:46:00+00:00'
      )
    )
  ),
  (
    'wrong_capability',
    pg_temp.pa05b_request(
      '90000000-0000-0000-0000-000000000104', 'pa05b-wrong-capability', 1,
      '10000000-0000-0000-0000-000000000104',
      jsonb_build_object(
        'purchase_order_line_revision_id', '40000000-0000-0000-0000-000000000703',
        'supplier_id', '20000000-0000-0000-0000-000000000104',
        'ingredient_id', '20000000-0000-0000-0000-000000000103',
        'unit_id', '20000000-0000-0000-0000-000000000102',
        'evidence_quantity', 1,
        'evidence_reference', 'PA05B-WRONG-CAPABILITY',
        'occurred_at', '2026-07-15T00:46:00+00:00'
      )
    )
  ),
  (
    'wrong_scope',
    pg_temp.pa05b_request(
      '90000000-0000-0000-0000-000000000105', 'pa05b-wrong-scope', 1,
      '10000000-0000-0000-0000-000000000105',
      jsonb_build_object(
        'purchase_order_line_revision_id', '40000000-0000-0000-0000-000000000703',
        'supplier_id', '20000000-0000-0000-0000-000000000104',
        'ingredient_id', '20000000-0000-0000-0000-000000000103',
        'unit_id', '20000000-0000-0000-0000-000000000102',
        'evidence_quantity', 1,
        'evidence_reference', 'PA05B-WRONG-SCOPE',
        'occurred_at', '2026-07-15T00:46:00+00:00'
      )
    )
  ),
  (
    'unknown_actor',
    pg_temp.pa05b_request(
      '90000000-0000-0000-0000-000000000106', 'pa05b-unknown-actor', 1,
      '10000000-0000-0000-0000-000000000106',
      jsonb_build_object(
        'purchase_order_line_revision_id', '40000000-0000-0000-0000-000000000703',
        'supplier_id', '20000000-0000-0000-0000-000000000104',
        'ingredient_id', '20000000-0000-0000-0000-000000000103',
        'unit_id', '20000000-0000-0000-0000-000000000102',
        'evidence_quantity', 1,
        'evidence_reference', 'PA05B-UNKNOWN-ACTOR',
        'occurred_at', '2026-07-15T00:46:00+00:00'
      )
    )
  );

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000101', true);
insert into pa05b_results select 'auth_subject_mismatch', atlas_api.record_supplier_receiving_evidence(request_payload)
from pa05b_requests where request_name = 'auth_subject_mismatch';

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000102', true);
insert into pa05b_results select 'inactive_actor', atlas_api.record_supplier_receiving_evidence(request_payload)
from pa05b_requests where request_name = 'inactive_actor';

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000103', true);
insert into pa05b_results select 'inactive_subject', atlas_api.record_supplier_receiving_evidence(request_payload)
from pa05b_requests where request_name = 'inactive_subject';

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000104', true);
insert into pa05b_results select 'wrong_capability', atlas_api.record_supplier_receiving_evidence(request_payload)
from pa05b_requests where request_name = 'wrong_capability';

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000105', true);
insert into pa05b_results select 'wrong_scope', atlas_api.record_supplier_receiving_evidence(request_payload)
from pa05b_requests where request_name = 'wrong_scope';

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000106', true);
insert into pa05b_results select 'unknown_actor', atlas_api.record_supplier_receiving_evidence(request_payload)
from pa05b_requests where request_name = 'unknown_actor';
reset role;

select is((select response_payload ->> 'error_code' from pa05b_results where result_name = 'auth_subject_mismatch'), 'AUTH_SUBJECT_MISMATCH', 'JWT subject must match requested_by_auth_subject');
select is((select response_payload ->> 'error_code' from pa05b_results where result_name = 'unknown_actor'), 'ACTOR_NOT_FOUND', 'unregistered authenticated subjects are rejected');
select is((select response_payload ->> 'error_code' from pa05b_results where result_name = 'inactive_actor'), 'ACTOR_INACTIVE', 'inactive actors are rejected');
select is((select response_payload ->> 'error_code' from pa05b_results where result_name = 'inactive_subject'), 'AUTH_SUBJECT_INACTIVE', 'revoked authentication subjects are rejected');
select is((select response_payload ->> 'error_code' from pa05b_results where result_name = 'wrong_capability'), 'CAPABILITY_DENIED', 'missing command capability is rejected');
select is((select response_payload ->> 'error_code' from pa05b_results where result_name = 'wrong_scope'), 'SCOPE_DENIED', 'relational customer scope is enforced');

-- Supplier evidence command: success, validation, replay, conflict, and stale version.
insert into pa05b_requests (request_name, request_payload) values
  (
    'record_main',
    pg_temp.pa05b_request(
      '90000000-0000-0000-0000-000000000201', 'pa05b-record-main', 1,
      '10000000-0000-0000-0000-000000000101',
      jsonb_build_object(
        'purchase_order_line_revision_id', '40000000-0000-0000-0000-000000000703',
        'supplier_id', '20000000-0000-0000-0000-000000000104',
        'ingredient_id', '20000000-0000-0000-0000-000000000103',
        'unit_id', '20000000-0000-0000-0000-000000000102',
        'evidence_quantity', 10,
        'evidence_reference', 'PA05B-EVIDENCE-MAIN',
        'occurred_at', '2026-07-15T00:46:00+00:00'
      )
    )
  ),
  (
    'record_negative',
    pg_temp.pa05b_request(
      '90000000-0000-0000-0000-000000000202', 'pa05b-record-negative', 1,
      '10000000-0000-0000-0000-000000000101',
      jsonb_build_object(
        'purchase_order_line_revision_id', '40000000-0000-0000-0000-000000000703',
        'supplier_id', '20000000-0000-0000-0000-000000000104',
        'ingredient_id', '20000000-0000-0000-0000-000000000103',
        'unit_id', '20000000-0000-0000-0000-000000000102',
        'evidence_quantity', -1,
        'evidence_reference', 'PA05B-EVIDENCE-NEGATIVE',
        'occurred_at', '2026-07-15T00:46:00+00:00'
      )
    )
  ),
  (
    'record_stale',
    pg_temp.pa05b_request(
      '90000000-0000-0000-0000-000000000203', 'pa05b-record-stale', 99,
      '10000000-0000-0000-0000-000000000101',
      jsonb_build_object(
        'purchase_order_line_revision_id', '40000000-0000-0000-0000-000000000703',
        'supplier_id', '20000000-0000-0000-0000-000000000104',
        'ingredient_id', '20000000-0000-0000-0000-000000000103',
        'unit_id', '20000000-0000-0000-0000-000000000102',
        'evidence_quantity', 1,
        'evidence_reference', 'PA05B-EVIDENCE-STALE',
        'occurred_at', '2026-07-15T00:46:00+00:00'
      )
    )
  ),
  (
    'record_conflict',
    pg_temp.pa05b_request(
      '90000000-0000-0000-0000-000000000204', 'pa05b-record-main', 1,
      '10000000-0000-0000-0000-000000000101',
      jsonb_build_object(
        'purchase_order_line_revision_id', '40000000-0000-0000-0000-000000000703',
        'supplier_id', '20000000-0000-0000-0000-000000000104',
        'ingredient_id', '20000000-0000-0000-0000-000000000103',
        'unit_id', '20000000-0000-0000-0000-000000000102',
        'evidence_quantity', 9,
        'evidence_reference', 'PA05B-EVIDENCE-CONFLICT',
        'occurred_at', '2026-07-15T00:46:00+00:00'
      )
    )
  );

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000101', true);
insert into pa05b_results select 'record_main', atlas_api.record_supplier_receiving_evidence(request_payload)
from pa05b_requests where request_name = 'record_main';
insert into pa05b_results select 'record_main_replay', atlas_api.record_supplier_receiving_evidence(request_payload)
from pa05b_requests where request_name = 'record_main';
insert into pa05b_results select 'record_conflict', atlas_api.record_supplier_receiving_evidence(request_payload)
from pa05b_requests where request_name = 'record_conflict';
insert into pa05b_results select 'record_negative', atlas_api.record_supplier_receiving_evidence(request_payload)
from pa05b_requests where request_name = 'record_negative';
insert into pa05b_results select 'record_stale', atlas_api.record_supplier_receiving_evidence(request_payload)
from pa05b_requests where request_name = 'record_stale';
reset role;

select ok((select (response_payload ->> 'success')::boolean from pa05b_results where result_name = 'record_main'), 'valid supplier evidence is recorded');
select is((select response_payload from pa05b_results where result_name = 'record_main_replay'), (select response_payload from pa05b_results where result_name = 'record_main'), 'exact idempotent replay returns the original response');
select is((select count(*)::integer from atlas_evidence.supplier_receiving_evidence where evidence_reference = 'PA05B-EVIDENCE-MAIN'), 1, 'exact replay does not duplicate supplier evidence');
select is((select response_payload ->> 'error_code' from pa05b_results where result_name = 'record_conflict'), 'IDEMPOTENCY_CONFLICT', 'same idempotency key with a different request is rejected');
select is((select response_payload ->> 'error_code' from pa05b_results where result_name = 'record_negative'), 'VALIDATION_FAILED', 'nonpositive evidence quantity is rejected');
select is((select response_payload ->> 'error_code' from pa05b_results where result_name = 'record_stale'), 'STALE_VERSION', 'stale purchase-order version is rejected');
select is((select count(*)::integer from atlas_evidence.supplier_receiving_evidence), 1, 'failed evidence commands do not mutate evidence');

select ok(
  exists (
    select 1 from atlas_core.command_receipts
    where command_id = '90000000-0000-0000-0000-000000000202'
      and outcome = 'FAILED_NON_RETRYABLE'
      and error_code = 'VALIDATION_FAILED'
  ),
  'post-receipt validation failure is stored deterministically'
);
select is((select count(*)::integer from atlas_audit.domain_events where command_id = '90000000-0000-0000-0000-000000000201'), 1, 'successful evidence command emits one domain event');
select is((select count(*)::integer from atlas_audit.audit_events where command_id = '90000000-0000-0000-0000-000000000201'), 1, 'successful evidence command emits one audit event');
select is(
  (
    select count(*)::integer
    from atlas_core.command_receipts cr
    join atlas_audit.domain_events de on de.command_receipt_id = cr.command_receipt_id
    join atlas_audit.audit_events ae on ae.command_receipt_id = cr.command_receipt_id
    where cr.command_id = '90000000-0000-0000-0000-000000000201'
      and cr.outcome = 'COMPLETED'
      and de.command_id = cr.command_id
      and ae.command_id = cr.command_id
  ),
  1,
  'successful command receipt, domain event, and audit event share one atomic identity'
);
select is((select count(*)::integer from atlas_audit.domain_events where command_id = '90000000-0000-0000-0000-000000000202'), 0, 'failed evidence command emits no domain event');
select is((select count(*)::integer from atlas_audit.audit_events where command_id = '90000000-0000-0000-0000-000000000202'), 0, 'failed evidence command emits no audit event');
select ok(
  not ((select response_payload from pa05b_results where result_name = 'record_negative') ?| array['sqlstate', 'sqlerrm', 'table_name', 'schema_name', 'internal_query']),
  'structured command errors expose no internal database details'
);

-- Additional evidence supports quantity-cap and independent dispatch cases.
insert into pa05b_requests (request_name, request_payload) values
  (
    'record_b',
    pg_temp.pa05b_request(
      '90000000-0000-0000-0000-000000000205', 'pa05b-record-b', 1,
      '10000000-0000-0000-0000-000000000101',
      jsonb_build_object(
        'purchase_order_line_revision_id', '40000000-0000-0000-0000-000000000703',
        'supplier_id', '20000000-0000-0000-0000-000000000104',
        'ingredient_id', '20000000-0000-0000-0000-000000000103',
        'unit_id', '20000000-0000-0000-0000-000000000102',
        'evidence_quantity', 5,
        'evidence_reference', 'PA05B-EVIDENCE-B',
        'occurred_at', '2026-07-15T00:47:00+00:00'
      )
    )
  ),
  (
    'record_c',
    pg_temp.pa05b_request(
      '90000000-0000-0000-0000-000000000206', 'pa05b-record-c', 1,
      '10000000-0000-0000-0000-000000000101',
      jsonb_build_object(
        'purchase_order_line_revision_id', '40000000-0000-0000-0000-000000000703',
        'supplier_id', '20000000-0000-0000-0000-000000000104',
        'ingredient_id', '20000000-0000-0000-0000-000000000103',
        'unit_id', '20000000-0000-0000-0000-000000000102',
        'evidence_quantity', 10,
        'evidence_reference', 'PA05B-EVIDENCE-C',
        'occurred_at', '2026-07-15T00:47:00+00:00'
      )
    )
  );

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000101', true);
insert into pa05b_results select 'record_b', atlas_api.record_supplier_receiving_evidence(request_payload)
from pa05b_requests where request_name = 'record_b';
insert into pa05b_results select 'record_c', atlas_api.record_supplier_receiving_evidence(request_payload)
from pa05b_requests where request_name = 'record_c';
reset role;

insert into pa05b_requests (request_name, request_payload)
select
  'apply_main',
  pg_temp.pa05b_request(
    '90000000-0000-0000-0000-000000000301', 'pa05b-apply-main', 1,
    '10000000-0000-0000-0000-000000000101',
    jsonb_build_object(
      'supplier_receiving_evidence_id', response_payload -> 'affected_aggregate_ids' ->> 'supplier_receiving_evidence_id',
      'fulfilment_allocation_line_revision_id', '40000000-0000-0000-0000-000000000603',
      'unit_id', '20000000-0000-0000-0000-000000000102',
      'applied_quantity', 10,
      'occurred_at', '2026-07-15T00:48:00+00:00'
    )
  )
from pa05b_results where result_name = 'record_main';

insert into pa05b_requests (request_name, request_payload)
select
  request_name,
  pg_temp.pa05b_request(command_id, idempotency_key, 1, '10000000-0000-0000-0000-000000000101', payload)
from (
  select
    'apply_b'::text as request_name,
    '90000000-0000-0000-0000-000000000302'::uuid as command_id,
    'pa05b-apply-b'::text as idempotency_key,
    jsonb_build_object(
      'supplier_receiving_evidence_id', response_payload -> 'affected_aggregate_ids' ->> 'supplier_receiving_evidence_id',
      'fulfilment_allocation_line_revision_id', '40000000-0000-0000-0000-000000000605',
      'unit_id', '20000000-0000-0000-0000-000000000102',
      'applied_quantity', 4,
      'occurred_at', '2026-07-15T00:48:00+00:00'
    ) as payload
  from pa05b_results where result_name = 'record_b'
  union all
  select
    'apply_b_duplicate', '90000000-0000-0000-0000-000000000303', 'pa05b-apply-b-duplicate',
    jsonb_build_object(
      'supplier_receiving_evidence_id', response_payload -> 'affected_aggregate_ids' ->> 'supplier_receiving_evidence_id',
      'fulfilment_allocation_line_revision_id', '40000000-0000-0000-0000-000000000605',
      'unit_id', '20000000-0000-0000-0000-000000000102',
      'applied_quantity', 1,
      'occurred_at', '2026-07-15T00:48:00+00:00'
    )
  from pa05b_results where result_name = 'record_b'
  union all
  select
    'apply_b_over_evidence', '90000000-0000-0000-0000-000000000304', 'pa05b-apply-b-over',
    jsonb_build_object(
      'supplier_receiving_evidence_id', response_payload -> 'affected_aggregate_ids' ->> 'supplier_receiving_evidence_id',
      'fulfilment_allocation_line_revision_id', '40000000-0000-0000-0000-000000000607',
      'unit_id', '20000000-0000-0000-0000-000000000102',
      'applied_quantity', 2,
      'occurred_at', '2026-07-15T00:48:00+00:00'
    )
  from pa05b_results where result_name = 'record_b'
  union all
  select
    'apply_c_over_allocation', '90000000-0000-0000-0000-000000000305', 'pa05b-apply-c-over',
    jsonb_build_object(
      'supplier_receiving_evidence_id', response_payload -> 'affected_aggregate_ids' ->> 'supplier_receiving_evidence_id',
      'fulfilment_allocation_line_revision_id', '40000000-0000-0000-0000-000000000607',
      'unit_id', '20000000-0000-0000-0000-000000000102',
      'applied_quantity', 6,
      'occurred_at', '2026-07-15T00:48:00+00:00'
    )
  from pa05b_results where result_name = 'record_c'
) requests;

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000101', true);
insert into pa05b_results select 'apply_main', atlas_api.apply_supplier_evidence_to_allocation(request_payload)
from pa05b_requests where request_name = 'apply_main';
insert into pa05b_results select 'apply_main_replay', atlas_api.apply_supplier_evidence_to_allocation(request_payload)
from pa05b_requests where request_name = 'apply_main';
insert into pa05b_results select 'apply_b', atlas_api.apply_supplier_evidence_to_allocation(request_payload)
from pa05b_requests where request_name = 'apply_b';
insert into pa05b_results select 'apply_b_duplicate', atlas_api.apply_supplier_evidence_to_allocation(request_payload)
from pa05b_requests where request_name = 'apply_b_duplicate';
insert into pa05b_results select 'apply_b_over_evidence', atlas_api.apply_supplier_evidence_to_allocation(request_payload)
from pa05b_requests where request_name = 'apply_b_over_evidence';
insert into pa05b_results select 'apply_c_over_allocation', atlas_api.apply_supplier_evidence_to_allocation(request_payload)
from pa05b_requests where request_name = 'apply_c_over_allocation';
reset role;

select ok((select (response_payload ->> 'success')::boolean from pa05b_results where result_name = 'apply_main'), 'evidence can be applied to its exact allocation line');
select is((select response_payload from pa05b_results where result_name = 'apply_main_replay'), (select response_payload from pa05b_results where result_name = 'apply_main'), 'evidence application supports exact replay');
select ok((select (response_payload ->> 'success')::boolean from pa05b_results where result_name = 'apply_b'), 'a second valid evidence application succeeds');
select is((select response_payload ->> 'error_code' from pa05b_results where result_name = 'apply_b_duplicate'), 'INVARIANT_VIOLATION', 'duplicate active evidence-to-allocation pair is rejected');
select is((select response_payload ->> 'error_code' from pa05b_results where result_name = 'apply_b_over_evidence'), 'EVIDENCE_OVER_APPLIED', 'evidence quantity cannot be over-applied');
select is((select response_payload ->> 'error_code' from pa05b_results where result_name = 'apply_c_over_allocation'), 'EVIDENCE_OVER_APPLIED', 'allocation quantity cannot be exceeded');
select is((select count(*)::integer from atlas_evidence.evidence_applications where application_status = 'VALID'), 2, 'only the two valid evidence applications persist');

-- Load confirmation consumes only current applied evidence and advances trip/stop versions.
insert into pa05b_requests (request_name, request_payload)
select
  request_name,
  pg_temp.pa05b_request(command_id, idempotency_key, 1, '10000000-0000-0000-0000-000000000101', payload)
from (
  select
    'load_main'::text as request_name,
    '90000000-0000-0000-0000-000000000401'::uuid as command_id,
    'pa05b-load-main'::text as idempotency_key,
    jsonb_build_object(
      'dispatch_trip_id', '50000000-0000-0000-0000-000000000902',
      'dispatch_stop_id', '50000000-0000-0000-0000-000000000903',
      'dispatch_requirement_revision_id', '30000000-0000-0000-0000-000000000501',
      'fulfilment_allocation_revision_id', '40000000-0000-0000-0000-000000000601',
      'dispatch_requirement_line_revision_id', '30000000-0000-0000-0000-000000000503',
      'fulfilment_allocation_line_revision_id', '40000000-0000-0000-0000-000000000603',
      'evidence_application_id', response_payload -> 'affected_aggregate_ids' ->> 'evidence_application_id',
      'unit_id', '20000000-0000-0000-0000-000000000102',
      'loaded_quantity', 10,
      'loaded_at', '2026-07-15T00:50:00+00:00'
    ) as payload
  from pa05b_results where result_name = 'apply_main'
  union all
  select
    'load_insufficient', '90000000-0000-0000-0000-000000000402', 'pa05b-load-insufficient',
    jsonb_build_object(
      'dispatch_trip_id', '50000000-0000-0000-0000-000000000912',
      'dispatch_stop_id', '50000000-0000-0000-0000-000000000913',
      'dispatch_requirement_revision_id', '30000000-0000-0000-0000-000000000501',
      'fulfilment_allocation_revision_id', '40000000-0000-0000-0000-000000000601',
      'dispatch_requirement_line_revision_id', '30000000-0000-0000-0000-000000000503',
      'fulfilment_allocation_line_revision_id', '40000000-0000-0000-0000-000000000603',
      'evidence_application_id', response_payload -> 'affected_aggregate_ids' ->> 'evidence_application_id',
      'unit_id', '20000000-0000-0000-0000-000000000102',
      'loaded_quantity', 1,
      'loaded_at', '2026-07-15T00:51:00+00:00'
    )
  from pa05b_results where result_name = 'apply_main'
  union all
  select
    'load_void_case', '90000000-0000-0000-0000-000000000403', 'pa05b-load-void-case',
    jsonb_build_object(
      'dispatch_trip_id', '50000000-0000-0000-0000-000000000922',
      'dispatch_stop_id', '50000000-0000-0000-0000-000000000923',
      'dispatch_requirement_revision_id', '30000000-0000-0000-0000-000000000501',
      'fulfilment_allocation_revision_id', '40000000-0000-0000-0000-000000000601',
      'dispatch_requirement_line_revision_id', '30000000-0000-0000-0000-000000000505',
      'fulfilment_allocation_line_revision_id', '40000000-0000-0000-0000-000000000605',
      'evidence_application_id', response_payload -> 'affected_aggregate_ids' ->> 'evidence_application_id',
      'unit_id', '20000000-0000-0000-0000-000000000102',
      'loaded_quantity', 4,
      'loaded_at', '2026-07-15T00:52:00+00:00'
    )
  from pa05b_results where result_name = 'apply_b'
) requests;

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000101', true);
insert into pa05b_results select 'load_main', atlas_api.confirm_dispatch_load(request_payload)
from pa05b_requests where request_name = 'load_main';
insert into pa05b_results select 'load_main_replay', atlas_api.confirm_dispatch_load(request_payload)
from pa05b_requests where request_name = 'load_main';
insert into pa05b_results select 'load_insufficient', atlas_api.confirm_dispatch_load(request_payload)
from pa05b_requests where request_name = 'load_insufficient';
insert into pa05b_results select 'load_void_case', atlas_api.confirm_dispatch_load(request_payload)
from pa05b_requests where request_name = 'load_void_case';
reset role;

select ok((select (response_payload ->> 'success')::boolean from pa05b_results where result_name = 'load_main'), 'dispatch load is confirmed from exact current evidence');
select is((select response_payload from pa05b_results where result_name = 'load_main_replay'), (select response_payload from pa05b_results where result_name = 'load_main'), 'dispatch load supports exact replay');
select is((select response_payload ->> 'error_code' from pa05b_results where result_name = 'load_insufficient'), 'EVIDENCE_INSUFFICIENT', 'evidence applications cannot be consumed beyond their remaining quantity');
select ok((select (response_payload ->> 'success')::boolean from pa05b_results where result_name = 'load_void_case'), 'independent load fixture succeeds before its evidence is voided');
select is((select trip_status from atlas_dispatch.dispatch_trips where dispatch_trip_id = '50000000-0000-0000-0000-000000000902'), 'LOADED', 'successful load advances the main trip to LOADED');
select is((select version::integer from atlas_dispatch.dispatch_trips where dispatch_trip_id = '50000000-0000-0000-0000-000000000902'), 2, 'successful load increments the trip version exactly once');
select is((select count(*)::integer from atlas_dispatch.dispatch_load_line_applications), 2, 'failed and replayed load commands add no extra load applications');

-- Delivery is blocked before departure even when an exact load exists.
insert into pa05b_requests (request_name, request_payload)
select
  'delivery_before_departure',
  pg_temp.pa05b_request(
    '90000000-0000-0000-0000-000000000501', 'pa05b-delivery-before-departure', 2,
    '10000000-0000-0000-0000-000000000101',
    jsonb_build_object(
      'dispatch_trip_id', '50000000-0000-0000-0000-000000000902',
      'dispatch_stop_id', '50000000-0000-0000-0000-000000000903',
      'dispatch_load_line_id', response_payload -> 'affected_aggregate_ids' ->> 'dispatch_load_line_id',
      'unit_id', '20000000-0000-0000-0000-000000000102',
      'delivered_quantity', 10,
      'returned_quantity', 0,
      'exception_quantity', 0,
      'confirmed_at', '2026-07-15T01:10:00+00:00',
      'received_by_reference', 'PA05B-RECEIVER',
      'notes', 'must be rejected before departure'
    )
  )
from pa05b_results where result_name = 'load_main';

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000101', true);
insert into pa05b_results select 'delivery_before_departure', atlas_api.confirm_successful_delivery(request_payload)
from pa05b_requests where request_name = 'delivery_before_departure';
reset role;

select is((select response_payload ->> 'error_code' from pa05b_results where result_name = 'delivery_before_departure'), 'TRIP_NOT_READY', 'delivery cannot be confirmed before departure');
select is((select count(*)::integer from atlas_dispatch.delivery_confirmations), 0, 'pre-departure delivery rejection is atomic');

-- Simulate upstream voiding after load to prove departure revalidates current evidence.
update atlas_evidence.supplier_receiving_evidence
set evidence_status = 'VOIDED'
where evidence_reference = 'PA05B-EVIDENCE-B';

insert into pa05b_requests (request_name, request_payload) values
  (
    'depart_main',
    pg_temp.pa05b_request(
      '90000000-0000-0000-0000-000000000601', 'pa05b-depart-main', 2,
      '10000000-0000-0000-0000-000000000101',
      jsonb_build_object(
        'dispatch_trip_id', '50000000-0000-0000-0000-000000000902',
        'departed_at', '2026-07-15T01:00:00+00:00'
      )
    )
  ),
  (
    'depart_void_case',
    pg_temp.pa05b_request(
      '90000000-0000-0000-0000-000000000602', 'pa05b-depart-void-case', 2,
      '10000000-0000-0000-0000-000000000101',
      jsonb_build_object(
        'dispatch_trip_id', '50000000-0000-0000-0000-000000000922',
        'departed_at', '2026-07-15T01:05:00+00:00'
      )
    )
  );

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000101', true);
insert into pa05b_results select 'depart_void_case', atlas_api.record_dispatch_departure(request_payload)
from pa05b_requests where request_name = 'depart_void_case';
insert into pa05b_results select 'depart_main', atlas_api.record_dispatch_departure(request_payload)
from pa05b_requests where request_name = 'depart_main';
insert into pa05b_results select 'depart_main_replay', atlas_api.record_dispatch_departure(request_payload)
from pa05b_requests where request_name = 'depart_main';
reset role;

select is((select response_payload ->> 'error_code' from pa05b_results where result_name = 'depart_void_case'), 'DEPARTURE_BLOCKED', 'departure revalidation blocks voided supplier evidence');
select is((select trip_status from atlas_dispatch.dispatch_trips where dispatch_trip_id = '50000000-0000-0000-0000-000000000922'), 'LOADED', 'blocked departure leaves the trip loaded');
select ok((select (response_payload ->> 'success')::boolean from pa05b_results where result_name = 'depart_main'), 'valid exact loaded evidence can depart');
select is((select response_payload from pa05b_results where result_name = 'depart_main_replay'), (select response_payload from pa05b_results where result_name = 'depart_main'), 'departure supports exact replay');
select is((select trip_status from atlas_dispatch.dispatch_trips where dispatch_trip_id = '50000000-0000-0000-0000-000000000902'), 'IN_TRANSIT', 'successful departure advances the trip to IN_TRANSIT');
select is((select version::integer from atlas_dispatch.dispatch_trips where dispatch_trip_id = '50000000-0000-0000-0000-000000000902'), 3, 'successful departure increments the trip version exactly once');

-- Successful-only delivery enforces exact loaded reconciliation.
insert into pa05b_requests (request_name, request_payload)
select
  request_name,
  pg_temp.pa05b_request(command_id, idempotency_key, 3, '10000000-0000-0000-0000-000000000101', payload)
from (
  select
    'delivery_over'::text as request_name,
    '90000000-0000-0000-0000-000000000701'::uuid as command_id,
    'pa05b-delivery-over'::text as idempotency_key,
    jsonb_build_object(
      'dispatch_trip_id', '50000000-0000-0000-0000-000000000902',
      'dispatch_stop_id', '50000000-0000-0000-0000-000000000903',
      'dispatch_load_line_id', response_payload -> 'affected_aggregate_ids' ->> 'dispatch_load_line_id',
      'unit_id', '20000000-0000-0000-0000-000000000102',
      'delivered_quantity', 11,
      'returned_quantity', 0,
      'exception_quantity', 0,
      'confirmed_at', '2026-07-15T01:15:00+00:00',
      'received_by_reference', 'PA05B-RECEIVER',
      'notes', 'over-delivery rejection'
    ) as payload
  from pa05b_results where result_name = 'load_main'
  union all
  select
    'delivery_return', '90000000-0000-0000-0000-000000000702', 'pa05b-delivery-return',
    jsonb_build_object(
      'dispatch_trip_id', '50000000-0000-0000-0000-000000000902',
      'dispatch_stop_id', '50000000-0000-0000-0000-000000000903',
      'dispatch_load_line_id', response_payload -> 'affected_aggregate_ids' ->> 'dispatch_load_line_id',
      'unit_id', '20000000-0000-0000-0000-000000000102',
      'delivered_quantity', 10,
      'returned_quantity', 1,
      'exception_quantity', 0,
      'confirmed_at', '2026-07-15T01:15:00+00:00',
      'received_by_reference', 'PA05B-RECEIVER',
      'notes', 'return path is intentionally unsupported'
    )
  from pa05b_results where result_name = 'load_main'
  union all
  select
    'delivery_main', '90000000-0000-0000-0000-000000000703', 'pa05b-delivery-main',
    jsonb_build_object(
      'dispatch_trip_id', '50000000-0000-0000-0000-000000000902',
      'dispatch_stop_id', '50000000-0000-0000-0000-000000000903',
      'dispatch_load_line_id', response_payload -> 'affected_aggregate_ids' ->> 'dispatch_load_line_id',
      'unit_id', '20000000-0000-0000-0000-000000000102',
      'delivered_quantity', 10,
      'returned_quantity', 0,
      'exception_quantity', 0,
      'confirmed_at', '2026-07-15T01:15:00+00:00',
      'received_by_reference', 'PA05B-RECEIVER',
      'notes', 'exact successful delivery'
    )
  from pa05b_results where result_name = 'load_main'
) requests;

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000101', true);
insert into pa05b_results select 'delivery_over', atlas_api.confirm_successful_delivery(request_payload)
from pa05b_requests where request_name = 'delivery_over';
insert into pa05b_results select 'delivery_return', atlas_api.confirm_successful_delivery(request_payload)
from pa05b_requests where request_name = 'delivery_return';
insert into pa05b_results select 'delivery_main', atlas_api.confirm_successful_delivery(request_payload)
from pa05b_requests where request_name = 'delivery_main';
insert into pa05b_results select 'delivery_main_replay', atlas_api.confirm_successful_delivery(request_payload)
from pa05b_requests where request_name = 'delivery_main';
reset role;

select is((select response_payload ->> 'error_code' from pa05b_results where result_name = 'delivery_over'), 'DELIVERY_RECONCILIATION_FAILED', 'delivered quantity cannot exceed the exact load');
select is((select response_payload ->> 'error_code' from pa05b_results where result_name = 'delivery_return'), 'DELIVERY_RECONCILIATION_FAILED', 'returns and exception paths remain explicitly unsupported');
select ok((select (response_payload ->> 'success')::boolean from pa05b_results where result_name = 'delivery_main'), 'exact successful delivery is confirmed');
select is((select response_payload from pa05b_results where result_name = 'delivery_main_replay'), (select response_payload from pa05b_results where result_name = 'delivery_main'), 'successful delivery supports exact replay');
select is((select count(*)::integer from atlas_dispatch.delivery_confirmations), 1, 'failed and replayed delivery commands create no duplicate confirmation');
select is((select count(*)::integer from atlas_dispatch.delivery_confirmation_lines), 1, 'successful-only delivery writes one exact reconciliation line');
select is((select trip_status from atlas_dispatch.dispatch_trips where dispatch_trip_id = '50000000-0000-0000-0000-000000000902'), 'DELIVERED', 'exact delivery completes the trip');
select is((select version::integer from atlas_dispatch.dispatch_trips where dispatch_trip_id = '50000000-0000-0000-0000-000000000902'), 4, 'delivery increments the trip version exactly once');
select is((select count(*)::integer from atlas_audit.domain_events where command_id = '90000000-0000-0000-0000-000000000703'), 1, 'successful delivery emits one domain event');
select is((select count(*)::integer from atlas_audit.audit_events where command_id = '90000000-0000-0000-0000-000000000703'), 1, 'successful delivery emits one audit event');

-- Shaped trace is authorized relationally and returns no receipt/audit internals.
insert into pa05b_requests (request_name, request_payload) values
  (
    'trace_main',
    jsonb_build_object(
      'contract_version', 'PA-05B.v1',
      'requested_by_auth_subject', '10000000-0000-0000-0000-000000000101',
      'payload', jsonb_build_object(
        'wholesale_order_line_revision_id', '30000000-0000-0000-0000-000000000202'
      )
    )
  ),
  (
    'trace_wrong_scope',
    jsonb_build_object(
      'contract_version', 'PA-05B.v1',
      'requested_by_auth_subject', '10000000-0000-0000-0000-000000000105',
      'payload', jsonb_build_object(
        'wholesale_order_line_revision_id', '30000000-0000-0000-0000-000000000202'
      )
    )
  );

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000101', true);
insert into pa05b_results select 'trace_main', atlas_api.get_supplier_direct_trace(request_payload)
from pa05b_requests where request_name = 'trace_main';
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000105', true);
insert into pa05b_results select 'trace_wrong_scope', atlas_api.get_supplier_direct_trace(request_payload)
from pa05b_requests where request_name = 'trace_wrong_scope';
reset role;

select ok((select (response_payload ->> 'success')::boolean from pa05b_results where result_name = 'trace_main'), 'authorized actor receives the completed supplier-direct trace');
select is((select response_payload -> 'trace' -> 'quantities' ->> 'delivered' from pa05b_results where result_name = 'trace_main'), '10.000000', 'trace preserves the exact delivered quantity');
select is((select response_payload -> 'trace' -> 'stage_statuses' ->> 'dispatch_trip' from pa05b_results where result_name = 'trace_main'), 'DELIVERED', 'trace exposes shaped operational stage status');
select ok(
  not ((select response_payload -> 'trace' from pa05b_results where result_name = 'trace_main') ?| array['command_receipt_id', 'request_hash', 'audit_event_ids', 'response_payload']),
  'trace does not expose command-receipt or audit internals'
);
select is((select response_payload ->> 'error_code' from pa05b_results where result_name = 'trace_wrong_scope'), 'SCOPE_DENIED', 'trace read enforces relational customer scope');

select * from finish();
rollback;
