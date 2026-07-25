begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;

select plan(124);

-- These grants exist only inside this rolled-back test transaction so the
-- authenticated role can invoke pgTAP assertions and write temporary results.
grant usage on schema extensions to authenticated;
grant execute on all functions in schema extensions to authenticated;

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

select is(
  (
    select r.rolname
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    join pg_roles r on r.oid = p.proowner
    where n.nspname = 'atlas_core'
      and p.proname = 'pa_05b_h2_validate_command_request'
      and pg_get_function_identity_arguments(p.oid) = 'request jsonb, command_name text'
  ),
  'atlas_owner',
  'PA-05B-H2 private request validator is owned by atlas_owner'
);

select ok(
  not exists (
    select 1
    from pg_proc p
    cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
    where p.oid = 'atlas_core.pa_05b_h2_validate_command_request(jsonb,text)'::regprocedure
      and acl.grantee = 0
      and acl.privilege_type = 'EXECUTE'
  )
  and not exists (
    select 1
    from unnest(array['anon', 'authenticated', 'service_role']) api_role(role_name)
    where has_function_privilege(
      api_role.role_name,
      'atlas_core.pa_05b_h2_validate_command_request(jsonb,text)'::regprocedure,
      'EXECUTE'
    )
  ),
  'PUBLIC and API roles cannot execute the PA-05B-H2 private validator'
);

select ok(
  has_function_privilege(
    'atlas_dispatch_command_runtime',
    'atlas_core.pa_05b_h2_validate_command_request(jsonb,text)'::regprocedure,
    'EXECUTE'
  ),
  'atlas_dispatch_command_runtime alone receives private-validator execute'
);

select ok(
  not exists (
    select 1
    from pg_namespace n
    where n.nspname like 'atlas\_%' escape '\'
      and has_schema_privilege('atlas_dispatch_command_runtime', n.oid, 'CREATE')
  )
  and not exists (
    select 1
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname like 'atlas\_%' escape '\'
      and c.relkind = 'S'
      and (
        has_sequence_privilege('atlas_dispatch_command_runtime', c.oid, 'USAGE')
        or has_sequence_privilege('atlas_dispatch_command_runtime', c.oid, 'UPDATE')
      )
  ),
  'Dispatch runtime receives no Atlas schema CREATE or sequence mutation privilege'
);

select ok(
  pg_get_functiondef('atlas_api.record_dispatch_departure(jsonb)'::regprocedure)
    ~ $re$(?s)if v_locked_scope_count <> v_stop_count.*?raise exception using\s+errcode = '40001',\s+message = 'trip stop scope changed during authorization';\s+end if;$re$,
  'post-lock departure scope change raises SQLSTATE 40001'
);

select ok(
  position(
    'pa_05b_finish_command' in coalesce(
      substring(
        pg_get_functiondef('atlas_api.record_dispatch_departure(jsonb)'::regprocedure)
        from $re$(?s)if v_locked_scope_count <> v_stop_count.*?end if;$re$
      ),
      ''
    )
  ) = 0,
  'post-lock departure scope-change branch does not finalize a failed receipt'
);

select ok(
  pg_get_functiondef('atlas_api.record_dispatch_departure(jsonb)'::regprocedure)
    ~ $re$(?s)when serialization_failure or deadlock_detected then.*?'RETRYABLE_CONCURRENCY_FAILURE'$re$
  and position(
    'FAILED_NON_RETRYABLE' in coalesce(
      substring(
        pg_get_functiondef('atlas_api.record_dispatch_departure(jsonb)'::regprocedure)
        from $re$(?s)if v_locked_scope_count <> v_stop_count.*?end if;$re$
      ),
      ''
    )
  ) = 0,
  'SQLSTATE 40001 scope race rolls back the receipt and classifies only as retryable'
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
  ('10000000-0000-0000-0000-000000000005', 'HUMAN', 'PA-05B wrong scope actor', 'ACTIVE', null),
  ('10000000-0000-0000-0000-000000000006', 'HUMAN', 'PA-05B global Dispatch reviewer', 'ACTIVE', null);

insert into atlas_core.actor_auth_subjects (
  actor_auth_subject_id, actor_id, auth_subject_id, subject_status, revoked_at
) values
  ('10000000-0000-0000-0000-000000000011', '10000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000101', 'ACTIVE', null),
  ('10000000-0000-0000-0000-000000000012', '10000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000102', 'ACTIVE', null),
  ('10000000-0000-0000-0000-000000000013', '10000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000103', 'REVOKED', timestamptz '2026-07-15 00:01:00+00'),
  ('10000000-0000-0000-0000-000000000014', '10000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000104', 'ACTIVE', null),
  ('10000000-0000-0000-0000-000000000015', '10000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000105', 'ACTIVE', null),
  ('10000000-0000-0000-0000-000000000016', '10000000-0000-0000-0000-000000000006', '10000000-0000-0000-0000-000000000199', 'ACTIVE', null);

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
  ('10000000-0000-0000-0000-000000000005', '11000000-0000-0000-0000-000000000001'),
  ('10000000-0000-0000-0000-000000000006', '11000000-0000-0000-0000-000000000001');

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
  ('10000000-0000-0000-0000-000000000004', 'GLOBAL'),
  ('10000000-0000-0000-0000-000000000006', 'GLOBAL');

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

insert into atlas_planning.confirmed_need_approval_snapshots (
  confirmed_need_approval_snapshot_id, confirmed_need_batch_id, approved_version,
  approved_by_actor_id, approved_at, command_id
) values (
  '30000000-0000-0000-0000-000000000310',
  '30000000-0000-0000-0000-000000000300', 1,
  '10000000-0000-0000-0000-000000000001', timestamptz '2026-07-15 00:15:00+00',
  '90000000-0000-0000-0000-000000000010'
);

insert into atlas_planning.confirmed_need_snapshot_lines (
  confirmed_need_snapshot_line_id, confirmed_need_approval_snapshot_id,
  confirmed_need_line_revision_id, ingredient_id, approved_quantity,
  unit_id, ingredient_name_snapshot
) values
  ('30000000-0000-0000-0000-000000000311', '30000000-0000-0000-0000-000000000310', '30000000-0000-0000-0000-000000000302', '20000000-0000-0000-0000-000000000103', 10, '20000000-0000-0000-0000-000000000102', 'PA-05B rice'),
  ('30000000-0000-0000-0000-000000000312', '30000000-0000-0000-0000-000000000310', '30000000-0000-0000-0000-000000000304', '20000000-0000-0000-0000-000000000103', 10, '20000000-0000-0000-0000-000000000102', 'PA-05B rice'),
  ('30000000-0000-0000-0000-000000000313', '30000000-0000-0000-0000-000000000310', '30000000-0000-0000-0000-000000000306', '20000000-0000-0000-0000-000000000103', 5, '20000000-0000-0000-0000-000000000102', 'PA-05B rice');

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

insert into atlas_planning.purchase_demand_references (
  purchase_demand_reference_id, purchase_handoff_line_revision_id,
  confirmed_need_snapshot_line_id, wholesale_order_line_revision_id,
  approved_quantity, unit_id
) values
  ('30000000-0000-0000-0000-000000000410', '30000000-0000-0000-0000-000000000403', '30000000-0000-0000-0000-000000000311', '30000000-0000-0000-0000-000000000202', 10, '20000000-0000-0000-0000-000000000102'),
  ('30000000-0000-0000-0000-000000000411', '30000000-0000-0000-0000-000000000405', '30000000-0000-0000-0000-000000000312', '30000000-0000-0000-0000-000000000204', 10, '20000000-0000-0000-0000-000000000102'),
  ('30000000-0000-0000-0000-000000000412', '30000000-0000-0000-0000-000000000407', '30000000-0000-0000-0000-000000000313', '30000000-0000-0000-0000-000000000206', 5, '20000000-0000-0000-0000-000000000102');

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
) values
  ('40000000-0000-0000-0000-000000000702', '40000000-0000-0000-0000-000000000700', '40000000-0000-0000-0000-000000000602'),
  ('40000000-0000-0000-0000-000000000704', '40000000-0000-0000-0000-000000000700', '40000000-0000-0000-0000-000000000604'),
  ('40000000-0000-0000-0000-000000000706', '40000000-0000-0000-0000-000000000700', '40000000-0000-0000-0000-000000000606');

insert into atlas_procurement.purchase_order_line_revisions (
  purchase_order_line_revision_id, purchase_order_revision_id,
  purchase_order_line_id, fulfilment_allocation_line_revision_id,
  ingredient_id, ordered_quantity, unit_id, delivery_location_id, service_date
) values
  ('40000000-0000-0000-0000-000000000703', '40000000-0000-0000-0000-000000000701', '40000000-0000-0000-0000-000000000702', '40000000-0000-0000-0000-000000000603', '20000000-0000-0000-0000-000000000103', 10, '20000000-0000-0000-0000-000000000102', '20000000-0000-0000-0000-000000000101', date '2026-07-15'),
  ('40000000-0000-0000-0000-000000000705', '40000000-0000-0000-0000-000000000701', '40000000-0000-0000-0000-000000000704', '40000000-0000-0000-0000-000000000605', '20000000-0000-0000-0000-000000000103', 10, '20000000-0000-0000-0000-000000000102', '20000000-0000-0000-0000-000000000101', date '2026-07-15'),
  ('40000000-0000-0000-0000-000000000707', '40000000-0000-0000-0000-000000000701', '40000000-0000-0000-0000-000000000706', '40000000-0000-0000-0000-000000000607', '20000000-0000-0000-0000-000000000103', 5, '20000000-0000-0000-0000-000000000102', '20000000-0000-0000-0000-000000000101', date '2026-07-15');

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
        'purchase_order_line_revision_id', '40000000-0000-0000-0000-000000000705',
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
        'purchase_order_line_revision_id', '40000000-0000-0000-0000-000000000705',
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
        'purchase_order_line_revision_id', '40000000-0000-0000-0000-000000000705',
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
  ),
  (
    'record_d',
    pg_temp.pa05b_request(
      '90000000-0000-0000-0000-000000000207', 'pa05b-record-d', 1,
      '10000000-0000-0000-0000-000000000101',
      jsonb_build_object(
        'purchase_order_line_revision_id', '40000000-0000-0000-0000-000000000707',
        'supplier_id', '20000000-0000-0000-0000-000000000104',
        'ingredient_id', '20000000-0000-0000-0000-000000000103',
        'unit_id', '20000000-0000-0000-0000-000000000102',
        'evidence_quantity', 5,
        'evidence_reference', 'PA05B-EVIDENCE-D',
        'occurred_at', '2026-07-15T00:47:00+00:00'
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
        'purchase_order_line_revision_id', '40000000-0000-0000-0000-000000000705',
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
        'purchase_order_line_revision_id', '40000000-0000-0000-0000-000000000705',
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
insert into pa05b_results select 'record_d', atlas_api.record_supplier_receiving_evidence(request_payload)
from pa05b_requests where request_name = 'record_d';
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

-- Additional PA-05B.v1 Evidence applications provide exact multi-line H2
-- load coverage while retaining the existing Evidence command contract.
insert into pa05b_requests (request_name, request_payload)
select request_name,
       pg_temp.pa05b_request(command_id, idempotency_key, 1,
         '10000000-0000-0000-0000-000000000101', payload)
from (
  select 'apply_d'::text as request_name,
         '90000000-0000-0000-0000-000000000306'::uuid as command_id,
         'pa05b-apply-d'::text as idempotency_key,
         jsonb_build_object(
           'supplier_receiving_evidence_id', response_payload -> 'affected_aggregate_ids' ->> 'supplier_receiving_evidence_id',
           'fulfilment_allocation_line_revision_id', '40000000-0000-0000-0000-000000000607',
           'unit_id', '20000000-0000-0000-0000-000000000102',
           'applied_quantity', 5,
           'occurred_at', '2026-07-15T00:48:00+00:00'
         ) as payload
  from pa05b_results where result_name = 'record_d'
  union all
  select 'apply_c_line_two', '90000000-0000-0000-0000-000000000307',
         'pa05b-apply-c-line-two',
         jsonb_build_object(
           'supplier_receiving_evidence_id', response_payload -> 'affected_aggregate_ids' ->> 'supplier_receiving_evidence_id',
           'fulfilment_allocation_line_revision_id', '40000000-0000-0000-0000-000000000605',
           'unit_id', '20000000-0000-0000-0000-000000000102',
           'applied_quantity', 6,
           'occurred_at', '2026-07-15T00:48:00+00:00'
         )
  from pa05b_results where result_name = 'record_c'
) additional_applications;

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000101', true);
insert into pa05b_results select 'apply_d', atlas_api.apply_supplier_evidence_to_allocation(request_payload)
from pa05b_requests where request_name = 'apply_d';
insert into pa05b_results select 'apply_c_line_two', atlas_api.apply_supplier_evidence_to_allocation(request_payload)
from pa05b_requests where request_name = 'apply_c_line_two';
reset role;

select ok((select (response_payload ->> 'success')::boolean from pa05b_results where result_name = 'apply_d'), 'exact third-line evidence application succeeds');
select ok((select (response_payload ->> 'success')::boolean from pa05b_results where result_name = 'apply_c_line_two'), 'second allocation line reaches exact Evidence coverage');

-- Load confirmation consumes only current applied evidence and advances trip/stop versions.
insert into pa05b_requests (request_name, request_payload)
select 'load_main',
       pg_temp.pa05b_request(
         '90000000-0000-0000-0000-000000000401', 'pa05b-load-main', 1,
         '10000000-0000-0000-0000-000000000101',
         jsonb_build_object(
           'dispatch_trip_id', '50000000-0000-0000-0000-000000000902',
           'dispatch_stop_id', '50000000-0000-0000-0000-000000000903',
           'dispatch_requirement_revision_id', '30000000-0000-0000-0000-000000000501',
           'fulfilment_allocation_revision_id', '40000000-0000-0000-0000-000000000601',
           'loaded_at', '2026-07-15T00:50:00+00:00',
           'lines', jsonb_build_array(
             jsonb_build_object(
               'dispatch_requirement_line_revision_id', '30000000-0000-0000-0000-000000000503',
               'fulfilment_allocation_line_revision_id', '40000000-0000-0000-0000-000000000603',
               'loaded_quantity', 10,
               'unit_id', '20000000-0000-0000-0000-000000000102',
               'evidence_applications', jsonb_build_array(jsonb_build_object(
                 'evidence_application_id', (select response_payload -> 'affected_aggregate_ids' ->> 'evidence_application_id' from pa05b_results where result_name = 'apply_main'),
                 'applied_to_load_quantity', 10,
                 'unit_id', '20000000-0000-0000-0000-000000000102'
               ))
             ),
             jsonb_build_object(
               'dispatch_requirement_line_revision_id', '30000000-0000-0000-0000-000000000505',
               'fulfilment_allocation_line_revision_id', '40000000-0000-0000-0000-000000000605',
               'loaded_quantity', 10,
               'unit_id', '20000000-0000-0000-0000-000000000102',
               'evidence_applications', jsonb_build_array(
                 jsonb_build_object(
                   'evidence_application_id', (select response_payload -> 'affected_aggregate_ids' ->> 'evidence_application_id' from pa05b_results where result_name = 'apply_b'),
                   'applied_to_load_quantity', 4,
                   'unit_id', '20000000-0000-0000-0000-000000000102'
                 ),
                 jsonb_build_object(
                   'evidence_application_id', (select response_payload -> 'affected_aggregate_ids' ->> 'evidence_application_id' from pa05b_results where result_name = 'apply_c_line_two'),
                   'applied_to_load_quantity', 6,
                   'unit_id', '20000000-0000-0000-0000-000000000102'
                 )
               )
             ),
             jsonb_build_object(
               'dispatch_requirement_line_revision_id', '30000000-0000-0000-0000-000000000507',
               'fulfilment_allocation_line_revision_id', '40000000-0000-0000-0000-000000000607',
               'loaded_quantity', 5,
               'unit_id', '20000000-0000-0000-0000-000000000102',
               'evidence_applications', jsonb_build_array(jsonb_build_object(
                 'evidence_application_id', (select response_payload -> 'affected_aggregate_ids' ->> 'evidence_application_id' from pa05b_results where result_name = 'apply_d'),
                 'applied_to_load_quantity', 5,
                 'unit_id', '20000000-0000-0000-0000-000000000102'
               ))
             )
           )
         )
       ) || jsonb_build_object('contract_version', 'PA-05B-H2.v1');

insert into pa05b_requests (request_name, request_payload)
select 'load_insufficient',
       pg_temp.pa05b_request(
         '90000000-0000-0000-0000-000000000402', 'pa05b-load-insufficient', 1,
         '10000000-0000-0000-0000-000000000101',
         jsonb_build_object(
           'dispatch_trip_id', '50000000-0000-0000-0000-000000000912',
           'dispatch_stop_id', '50000000-0000-0000-0000-000000000913',
           'dispatch_requirement_revision_id', '30000000-0000-0000-0000-000000000501',
           'fulfilment_allocation_revision_id', '40000000-0000-0000-0000-000000000601',
           'loaded_at', '2026-07-15T00:51:00+00:00',
           'lines', main_request.request_payload -> 'payload' -> 'lines'
         )
       ) || jsonb_build_object('contract_version', 'PA-05B-H2.v1')
from pa05b_requests main_request where main_request.request_name = 'load_main';

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000101', true);
insert into pa05b_results select 'load_main', atlas_api.confirm_dispatch_load(request_payload)
from pa05b_requests where request_name = 'load_main';
insert into pa05b_results select 'load_main_replay', atlas_api.confirm_dispatch_load(request_payload)
from pa05b_requests where request_name = 'load_main';
insert into pa05b_results select 'load_insufficient', atlas_api.confirm_dispatch_load(request_payload)
from pa05b_requests where request_name = 'load_insufficient';
reset role;

select ok((select (response_payload ->> 'success')::boolean from pa05b_results where result_name = 'load_main'), 'dispatch load is confirmed from exact current evidence');
select is((select response_payload from pa05b_results where result_name = 'load_main_replay'), (select response_payload from pa05b_results where result_name = 'load_main'), 'dispatch load supports exact replay');
select is((select response_payload ->> 'error_code' from pa05b_results where result_name = 'load_insufficient'), 'EVIDENCE_INSUFFICIENT', 'evidence applications cannot be consumed beyond their remaining quantity');
select is((select trip_status from atlas_dispatch.dispatch_trips where dispatch_trip_id = '50000000-0000-0000-0000-000000000902'), 'LOADED', 'successful load advances the main trip to LOADED');
select is((select version::integer from atlas_dispatch.dispatch_trips where dispatch_trip_id = '50000000-0000-0000-0000-000000000902'), 2, 'successful load increments the trip version exactly once');
select is((select count(*)::integer from atlas_dispatch.dispatch_load_lines), 3, 'successful multi-line load persists every line exactly once');
select is((select count(*)::integer from atlas_dispatch.dispatch_load_line_applications), 4, 'failed and replayed load commands add no extra load applications');

-- Delivery is blocked before departure even when an exact load exists.
insert into pa05b_requests (request_name, request_payload)
select 'delivery_before_departure',
       pg_temp.pa05b_request(
         '90000000-0000-0000-0000-000000000501', 'pa05b-delivery-before-departure', 2,
         '10000000-0000-0000-0000-000000000101',
         jsonb_build_object(
           'dispatch_trip_id', '50000000-0000-0000-0000-000000000902',
           'dispatch_stop_id', '50000000-0000-0000-0000-000000000903',
           'lines', loaded.lines,
           'confirmed_at', '2026-07-15T01:10:00+00:00',
           'received_by_reference', 'PA05B-RECEIVER',
           'notes', 'must be rejected before departure'
         )
       ) || jsonb_build_object('contract_version', 'PA-05B-H2.v1')
from (
  select jsonb_agg(
           jsonb_build_object(
             'dispatch_load_line_id', dll.dispatch_load_line_id,
             'unit_id', dll.unit_id,
             'delivered_quantity', dll.loaded_quantity,
             'returned_quantity', 0,
             'exception_quantity', 0
           ) order by dll.dispatch_load_line_id
         ) as lines
  from atlas_dispatch.dispatch_loads dl
  join atlas_dispatch.dispatch_load_lines dll on dll.dispatch_load_id = dl.dispatch_load_id
  where dl.dispatch_trip_id = '50000000-0000-0000-0000-000000000902'
) loaded;

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
        'dispatch_trip_id', '50000000-0000-0000-0000-000000000902',
        'departed_at', '2026-07-15T01:05:00+00:00'
      )
    )
  );

update pa05b_requests
set request_payload = request_payload || jsonb_build_object('contract_version', 'PA-05B-H2.v1')
where request_name in ('depart_main', 'depart_void_case');

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000101', true);
insert into pa05b_results select 'depart_void_case', atlas_api.record_dispatch_departure(request_payload)
from pa05b_requests where request_name = 'depart_void_case';
reset role;

select is((select response_payload ->> 'error_code' from pa05b_results where result_name = 'depart_void_case'), 'DEPARTURE_BLOCKED', 'departure revalidation blocks voided supplier evidence');
select is((select trip_status from atlas_dispatch.dispatch_trips where dispatch_trip_id = '50000000-0000-0000-0000-000000000902'), 'LOADED', 'blocked departure leaves the trip loaded');

update atlas_evidence.supplier_receiving_evidence
set evidence_status = 'VALID'
where evidence_reference = 'PA05B-EVIDENCE-B';

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000101', true);
insert into pa05b_results select 'depart_main', atlas_api.record_dispatch_departure(request_payload)
from pa05b_requests where request_name = 'depart_main';
insert into pa05b_results select 'depart_main_replay', atlas_api.record_dispatch_departure(request_payload)
from pa05b_requests where request_name = 'depart_main';
reset role;

select ok((select (response_payload ->> 'success')::boolean from pa05b_results where result_name = 'depart_main'), 'valid exact loaded evidence can depart');
select is((select response_payload from pa05b_results where result_name = 'depart_main_replay'), (select response_payload from pa05b_results where result_name = 'depart_main'), 'departure supports exact replay');
select is((select trip_status from atlas_dispatch.dispatch_trips where dispatch_trip_id = '50000000-0000-0000-0000-000000000902'), 'IN_TRANSIT', 'successful departure advances the trip to IN_TRANSIT');
select is((select version::integer from atlas_dispatch.dispatch_trips where dispatch_trip_id = '50000000-0000-0000-0000-000000000902'), 3, 'successful departure increments the trip version exactly once');

-- Successful-only delivery enforces exact loaded reconciliation.
insert into pa05b_requests (request_name, request_payload)
select scenarios.request_name,
       pg_temp.pa05b_request(
         scenarios.command_id,
         scenarios.idempotency_key,
         3,
         '10000000-0000-0000-0000-000000000101',
         jsonb_build_object(
           'dispatch_trip_id', '50000000-0000-0000-0000-000000000902',
           'dispatch_stop_id', '50000000-0000-0000-0000-000000000903',
           'lines', loaded.lines,
           'confirmed_at', '2026-07-15T01:15:00+00:00',
           'received_by_reference', 'PA05B-RECEIVER',
           'notes', scenarios.notes
         )
       ) || jsonb_build_object('contract_version', 'PA-05B-H2.v1')
from (
  values
    ('delivery_over'::text, '90000000-0000-0000-0000-000000000701'::uuid, 'pa05b-delivery-over'::text, 'over', 'over-delivery rejection'),
    ('delivery_return', '90000000-0000-0000-0000-000000000702', 'pa05b-delivery-return', 'return', 'return path is intentionally unsupported'),
    ('delivery_main', '90000000-0000-0000-0000-000000000703', 'pa05b-delivery-main', 'exact', 'exact successful delivery')
) scenarios(request_name, command_id, idempotency_key, scenario, notes)
cross join lateral (
  select jsonb_agg(
           jsonb_build_object(
             'dispatch_load_line_id', lines.dispatch_load_line_id,
             'unit_id', lines.unit_id,
             'delivered_quantity', lines.loaded_quantity
               + case when scenarios.scenario = 'over' and lines.line_number = 1 then 1 else 0 end,
             'returned_quantity',
               case when scenarios.scenario = 'return' and lines.line_number = 1 then 1 else 0 end,
             'exception_quantity', 0
           ) order by lines.dispatch_load_line_id
         ) as lines
  from (
    select dll.*,
           row_number() over (order by dll.dispatch_load_line_id) as line_number
    from atlas_dispatch.dispatch_loads dl
    join atlas_dispatch.dispatch_load_lines dll on dll.dispatch_load_id = dl.dispatch_load_id
    where dl.dispatch_trip_id = '50000000-0000-0000-0000-000000000902'
  ) lines
) loaded;

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
select is((select count(*)::integer from atlas_dispatch.delivery_confirmation_lines), 3, 'successful-only delivery writes every exact reconciliation line');
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

-- This focused extension retains the rolled-back PA-05B command fixture so H2
-- can prove trip-wide multi-stop behavior without introducing PA-05F authoring.

-- Two released one-line requirements derived from current PA-05D handoff
-- lineage give one trip two independently loadable stops.
insert into atlas_planning.wholesale_orders (
  wholesale_order_id, customer_id, delivery_location_id,
  customer_order_reference, service_date, order_status,
  created_by_actor_id, approved_by_actor_id, approved_at,
  released_by_actor_id, released_at
) values
  ('31000000-0000-0000-0000-000000000800', '20000000-0000-0000-0000-000000000100', '20000000-0000-0000-0000-000000000101', 'PA05B-H2-ORDER-A', date '2026-07-15', 'RELEASED', '10000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', timestamptz '2026-07-15 00:05:00+00', '10000000-0000-0000-0000-000000000001', timestamptz '2026-07-15 00:10:00+00'),
  ('31000000-0000-0000-0000-000000000900', '20000000-0000-0000-0000-000000000100', '20000000-0000-0000-0000-000000000101', 'PA05B-H2-ORDER-B', date '2026-07-15', 'RELEASED', '10000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', timestamptz '2026-07-15 00:05:00+00', '10000000-0000-0000-0000-000000000001', timestamptz '2026-07-15 00:10:00+00');

insert into atlas_planning.wholesale_order_lines (
  wholesale_order_line_id, wholesale_order_id, source_line_number
) values
  ('31000000-0000-0000-0000-000000000801', '31000000-0000-0000-0000-000000000800', 1),
  ('31000000-0000-0000-0000-000000000901', '31000000-0000-0000-0000-000000000900', 1);

insert into atlas_planning.wholesale_order_line_revisions (
  wholesale_order_line_revision_id, wholesale_order_line_id, revision_number,
  ingredient_id, requested_quantity, unit_id, revision_status, created_by_actor_id
) values
  ('31000000-0000-0000-0000-000000000802', '31000000-0000-0000-0000-000000000801', 1, '20000000-0000-0000-0000-000000000103', 10, '20000000-0000-0000-0000-000000000102', 'RELEASED', '10000000-0000-0000-0000-000000000001'),
  ('31000000-0000-0000-0000-000000000902', '31000000-0000-0000-0000-000000000901', 1, '20000000-0000-0000-0000-000000000103', 5, '20000000-0000-0000-0000-000000000102', 'RELEASED', '10000000-0000-0000-0000-000000000001');

insert into atlas_planning.confirmed_need_batches (
  confirmed_need_batch_id, wholesale_order_id, period_start, period_end,
  batch_status, created_by_actor_id, approved_by_actor_id, approved_at,
  released_by_actor_id, released_at
) values
  ('31000000-0000-0000-0000-000000000810', '31000000-0000-0000-0000-000000000800', date '2026-07-15', date '2026-07-15', 'RELEASED_FOR_PURCHASE_HANDOFF', '10000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', timestamptz '2026-07-15 00:15:00+00', '10000000-0000-0000-0000-000000000001', timestamptz '2026-07-15 00:20:00+00'),
  ('31000000-0000-0000-0000-000000000910', '31000000-0000-0000-0000-000000000900', date '2026-07-15', date '2026-07-15', 'RELEASED_FOR_PURCHASE_HANDOFF', '10000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', timestamptz '2026-07-15 00:15:00+00', '10000000-0000-0000-0000-000000000001', timestamptz '2026-07-15 00:20:00+00');

insert into atlas_planning.confirmed_need_lines (
  confirmed_need_line_id, confirmed_need_batch_id, wholesale_order_line_id
) values
  ('31000000-0000-0000-0000-000000000811', '31000000-0000-0000-0000-000000000810', '31000000-0000-0000-0000-000000000801'),
  ('31000000-0000-0000-0000-000000000911', '31000000-0000-0000-0000-000000000910', '31000000-0000-0000-0000-000000000901');

insert into atlas_planning.confirmed_need_line_revisions (
  confirmed_need_line_revision_id, confirmed_need_line_id, revision_number,
  wholesale_order_line_revision_id, ingredient_id, theoretical_quantity,
  confirmed_quantity, unit_id, revision_status, created_by_actor_id
) values
  ('31000000-0000-0000-0000-000000000812', '31000000-0000-0000-0000-000000000811', 1, '31000000-0000-0000-0000-000000000802', '20000000-0000-0000-0000-000000000103', 10, 10, '20000000-0000-0000-0000-000000000102', 'RELEASED', '10000000-0000-0000-0000-000000000001'),
  ('31000000-0000-0000-0000-000000000912', '31000000-0000-0000-0000-000000000911', 1, '31000000-0000-0000-0000-000000000902', '20000000-0000-0000-0000-000000000103', 5, 5, '20000000-0000-0000-0000-000000000102', 'RELEASED', '10000000-0000-0000-0000-000000000001');

insert into atlas_planning.confirmed_need_approval_snapshots (
  confirmed_need_approval_snapshot_id, confirmed_need_batch_id, approved_version,
  approved_by_actor_id, approved_at, command_id
) values
  ('31000000-0000-0000-0000-000000000813', '31000000-0000-0000-0000-000000000810', 1, '10000000-0000-0000-0000-000000000001', timestamptz '2026-07-15 00:15:00+00', '91000000-0000-0000-0000-000000000020'),
  ('31000000-0000-0000-0000-000000000913', '31000000-0000-0000-0000-000000000910', 1, '10000000-0000-0000-0000-000000000001', timestamptz '2026-07-15 00:15:00+00', '91000000-0000-0000-0000-000000000021');

insert into atlas_planning.confirmed_need_snapshot_lines (
  confirmed_need_snapshot_line_id, confirmed_need_approval_snapshot_id,
  confirmed_need_line_revision_id, ingredient_id, approved_quantity,
  unit_id, ingredient_name_snapshot
) values
  ('31000000-0000-0000-0000-000000000814', '31000000-0000-0000-0000-000000000813', '31000000-0000-0000-0000-000000000812', '20000000-0000-0000-0000-000000000103', 10, '20000000-0000-0000-0000-000000000102', 'PA-05B rice'),
  ('31000000-0000-0000-0000-000000000914', '31000000-0000-0000-0000-000000000913', '31000000-0000-0000-0000-000000000912', '20000000-0000-0000-0000-000000000103', 5, '20000000-0000-0000-0000-000000000102', 'PA-05B rice');

insert into atlas_planning.purchase_handoff_batches (
  purchase_handoff_batch_id, confirmed_need_batch_id, period_start, period_end,
  handoff_status, created_by_actor_id
) values
  ('31000000-0000-0000-0000-000000000820', '31000000-0000-0000-0000-000000000810', date '2026-07-15', date '2026-07-15', 'RELEASED_TO_PROCUREMENT', '10000000-0000-0000-0000-000000000001'),
  ('31000000-0000-0000-0000-000000000920', '31000000-0000-0000-0000-000000000910', date '2026-07-15', date '2026-07-15', 'RELEASED_TO_PROCUREMENT', '10000000-0000-0000-0000-000000000001');

insert into atlas_planning.purchase_handoff_revisions (
  purchase_handoff_revision_id, purchase_handoff_batch_id, revision_number,
  revision_status, released_by_actor_id, released_at
) values
  ('31000000-0000-0000-0000-000000000821', '31000000-0000-0000-0000-000000000820', 1, 'RELEASED_TO_PROCUREMENT', '10000000-0000-0000-0000-000000000001', timestamptz '2026-07-15 00:25:00+00'),
  ('31000000-0000-0000-0000-000000000921', '31000000-0000-0000-0000-000000000920', 1, 'RELEASED_TO_PROCUREMENT', '10000000-0000-0000-0000-000000000001', timestamptz '2026-07-15 00:25:00+00');

insert into atlas_planning.purchase_handoff_lines (
  purchase_handoff_line_id, purchase_handoff_batch_id, confirmed_need_line_id
) values
  ('31000000-0000-0000-0000-000000000822', '31000000-0000-0000-0000-000000000820', '31000000-0000-0000-0000-000000000811'),
  ('31000000-0000-0000-0000-000000000922', '31000000-0000-0000-0000-000000000920', '31000000-0000-0000-0000-000000000911');

insert into atlas_planning.purchase_handoff_line_revisions (
  purchase_handoff_line_revision_id, purchase_handoff_revision_id,
  purchase_handoff_line_id, confirmed_need_line_revision_id, ingredient_id,
  handoff_quantity, unit_id, service_date, delivery_location_id
) values
  ('31000000-0000-0000-0000-000000000823', '31000000-0000-0000-0000-000000000821', '31000000-0000-0000-0000-000000000822', '31000000-0000-0000-0000-000000000812', '20000000-0000-0000-0000-000000000103', 10, '20000000-0000-0000-0000-000000000102', date '2026-07-15', '20000000-0000-0000-0000-000000000101'),
  ('31000000-0000-0000-0000-000000000923', '31000000-0000-0000-0000-000000000921', '31000000-0000-0000-0000-000000000922', '31000000-0000-0000-0000-000000000912', '20000000-0000-0000-0000-000000000103', 5, '20000000-0000-0000-0000-000000000102', date '2026-07-15', '20000000-0000-0000-0000-000000000101');

insert into atlas_planning.purchase_demand_references (
  purchase_demand_reference_id, purchase_handoff_line_revision_id,
  confirmed_need_snapshot_line_id, wholesale_order_line_revision_id,
  approved_quantity, unit_id
) values
  ('31000000-0000-0000-0000-000000000824', '31000000-0000-0000-0000-000000000823', '31000000-0000-0000-0000-000000000814', '31000000-0000-0000-0000-000000000802', 10, '20000000-0000-0000-0000-000000000102'),
  ('31000000-0000-0000-0000-000000000924', '31000000-0000-0000-0000-000000000923', '31000000-0000-0000-0000-000000000914', '31000000-0000-0000-0000-000000000902', 5, '20000000-0000-0000-0000-000000000102');

insert into atlas_planning.dispatch_requirements (
  dispatch_requirement_id, customer_id, delivery_location_id,
  service_date, requirement_status
) values
  ('30000000-0000-0000-0000-000000000530', '20000000-0000-0000-0000-000000000100', '20000000-0000-0000-0000-000000000101', date '2026-07-15', 'RELEASED'),
  ('30000000-0000-0000-0000-000000000540', '20000000-0000-0000-0000-000000000100', '20000000-0000-0000-0000-000000000101', date '2026-07-15', 'RELEASED');

insert into atlas_planning.dispatch_requirement_revisions (
  dispatch_requirement_revision_id, dispatch_requirement_id,
  purchase_handoff_revision_id, revision_number, revision_status,
  customer_name_snapshot, location_name_snapshot, address_snapshot,
  released_by_actor_id, released_at
) values
  ('30000000-0000-0000-0000-000000000531', '30000000-0000-0000-0000-000000000530', '31000000-0000-0000-0000-000000000821', 1, 'RELEASED', 'PA-05B wholesale customer', 'PA-05B delivery location', 'PA-05B test address', '10000000-0000-0000-0000-000000000001', timestamptz '2026-07-15 00:30:00+00'),
  ('30000000-0000-0000-0000-000000000541', '30000000-0000-0000-0000-000000000540', '31000000-0000-0000-0000-000000000921', 1, 'RELEASED', 'PA-05B wholesale customer', 'PA-05B delivery location', 'PA-05B test address', '10000000-0000-0000-0000-000000000001', timestamptz '2026-07-15 00:30:00+00');

insert into atlas_planning.dispatch_requirement_lines (
  dispatch_requirement_line_id, dispatch_requirement_id,
  purchase_handoff_line_id
) values
  ('30000000-0000-0000-0000-000000000532', '30000000-0000-0000-0000-000000000530', '31000000-0000-0000-0000-000000000822'),
  ('30000000-0000-0000-0000-000000000542', '30000000-0000-0000-0000-000000000540', '31000000-0000-0000-0000-000000000922');

insert into atlas_planning.dispatch_requirement_line_revisions (
  dispatch_requirement_line_revision_id, dispatch_requirement_revision_id,
  dispatch_requirement_line_id, purchase_handoff_line_revision_id,
  ingredient_id, required_quantity, unit_id
) values
  ('30000000-0000-0000-0000-000000000533', '30000000-0000-0000-0000-000000000531', '30000000-0000-0000-0000-000000000532', '31000000-0000-0000-0000-000000000823', '20000000-0000-0000-0000-000000000103', 10, '20000000-0000-0000-0000-000000000102'),
  ('30000000-0000-0000-0000-000000000543', '30000000-0000-0000-0000-000000000541', '30000000-0000-0000-0000-000000000542', '31000000-0000-0000-0000-000000000923', '20000000-0000-0000-0000-000000000103', 5, '20000000-0000-0000-0000-000000000102');

insert into atlas_procurement.fulfilment_allocations (
  fulfilment_allocation_id, dispatch_requirement_id, allocation_status
) values
  ('40000000-0000-0000-0000-000000000630', '30000000-0000-0000-0000-000000000530', 'READY_FOR_DISPATCH'),
  ('40000000-0000-0000-0000-000000000640', '30000000-0000-0000-0000-000000000540', 'READY_FOR_DISPATCH');

insert into atlas_procurement.fulfilment_allocation_revisions (
  fulfilment_allocation_revision_id, fulfilment_allocation_id,
  revision_number, revision_status, allocated_by_actor_id
) values
  ('40000000-0000-0000-0000-000000000631', '40000000-0000-0000-0000-000000000630', 1, 'READY_FOR_DISPATCH', '10000000-0000-0000-0000-000000000001'),
  ('40000000-0000-0000-0000-000000000641', '40000000-0000-0000-0000-000000000640', 1, 'READY_FOR_DISPATCH', '10000000-0000-0000-0000-000000000001');

insert into atlas_procurement.fulfilment_allocation_lines (
  fulfilment_allocation_line_id, fulfilment_allocation_id,
  dispatch_requirement_line_id, portion_sequence
) values
  ('40000000-0000-0000-0000-000000000632', '40000000-0000-0000-0000-000000000630', '30000000-0000-0000-0000-000000000532', 1),
  ('40000000-0000-0000-0000-000000000642', '40000000-0000-0000-0000-000000000640', '30000000-0000-0000-0000-000000000542', 1);

insert into atlas_procurement.fulfilment_allocation_line_revisions (
  fulfilment_allocation_line_revision_id, fulfilment_allocation_revision_id,
  fulfilment_allocation_line_id, dispatch_requirement_line_revision_id,
  supplier_id, allocated_quantity, unit_id, line_status
) values
  ('40000000-0000-0000-0000-000000000633', '40000000-0000-0000-0000-000000000631', '40000000-0000-0000-0000-000000000632', '30000000-0000-0000-0000-000000000533', '20000000-0000-0000-0000-000000000104', 10, '20000000-0000-0000-0000-000000000102', 'READY_FOR_EVIDENCE'),
  ('40000000-0000-0000-0000-000000000643', '40000000-0000-0000-0000-000000000641', '40000000-0000-0000-0000-000000000642', '30000000-0000-0000-0000-000000000543', '20000000-0000-0000-0000-000000000104', 5, '20000000-0000-0000-0000-000000000102', 'READY_FOR_EVIDENCE');

insert into atlas_procurement.purchase_order_lines (
  purchase_order_line_id, purchase_order_id, fulfilment_allocation_line_id
) values
  ('40000000-0000-0000-0000-000000000710', '40000000-0000-0000-0000-000000000700', '40000000-0000-0000-0000-000000000632'),
  ('40000000-0000-0000-0000-000000000712', '40000000-0000-0000-0000-000000000700', '40000000-0000-0000-0000-000000000642');

insert into atlas_procurement.purchase_order_line_revisions (
  purchase_order_line_revision_id, purchase_order_revision_id,
  purchase_order_line_id, fulfilment_allocation_line_revision_id,
  ingredient_id, ordered_quantity, unit_id, delivery_location_id, service_date
) values
  ('40000000-0000-0000-0000-000000000711', '40000000-0000-0000-0000-000000000701', '40000000-0000-0000-0000-000000000710', '40000000-0000-0000-0000-000000000633', '20000000-0000-0000-0000-000000000103', 10, '20000000-0000-0000-0000-000000000102', '20000000-0000-0000-0000-000000000101', date '2026-07-15'),
  ('40000000-0000-0000-0000-000000000713', '40000000-0000-0000-0000-000000000701', '40000000-0000-0000-0000-000000000712', '40000000-0000-0000-0000-000000000643', '20000000-0000-0000-0000-000000000103', 5, '20000000-0000-0000-0000-000000000102', '20000000-0000-0000-0000-000000000101', date '2026-07-15');

insert into atlas_dispatch.dispatch_plans (
  dispatch_plan_id, plan_reference, service_date, created_by_actor_id
) values (
  '50000000-0000-0000-0000-000000000950', 'PA05B-H2-MULTI-STOP', date '2026-07-15',
  '10000000-0000-0000-0000-000000000001'
);

insert into atlas_dispatch.dispatch_plan_requirements (
  dispatch_plan_requirement_id, dispatch_plan_id,
  dispatch_requirement_revision_id, fulfilment_allocation_revision_id
) values
  ('50000000-0000-0000-0000-000000000951', '50000000-0000-0000-0000-000000000950', '30000000-0000-0000-0000-000000000531', '40000000-0000-0000-0000-000000000631'),
  ('50000000-0000-0000-0000-000000000952', '50000000-0000-0000-0000-000000000950', '30000000-0000-0000-0000-000000000541', '40000000-0000-0000-0000-000000000641');

insert into atlas_dispatch.dispatch_trips (
  dispatch_trip_id, dispatch_plan_id, trip_reference, trip_status,
  driver_actor_id, vehicle_reference, planned_departure_at
) values (
  '50000000-0000-0000-0000-000000000953',
  '50000000-0000-0000-0000-000000000950', 'PA05B-H2-TRIP', 'ASSIGNED',
  '10000000-0000-0000-0000-000000000001', 'PA05B-H2-VEHICLE',
  timestamptz '2026-07-15 02:00:00+00'
);

insert into atlas_dispatch.dispatch_stops (
  dispatch_stop_id, dispatch_trip_id, stop_sequence,
  dispatch_requirement_revision_id, customer_id, delivery_location_id
) values
  ('50000000-0000-0000-0000-000000000954', '50000000-0000-0000-0000-000000000953', 1, '30000000-0000-0000-0000-000000000531', '20000000-0000-0000-0000-000000000100', '20000000-0000-0000-0000-000000000101'),
  ('50000000-0000-0000-0000-000000000955', '50000000-0000-0000-0000-000000000953', 2, '30000000-0000-0000-0000-000000000541', '20000000-0000-0000-0000-000000000100', '20000000-0000-0000-0000-000000000101');

-- Evidence remains command-authored under PA-05B.v1.
insert into pa05b_requests (request_name, request_payload) values
  ('h2_record_stop_one', pg_temp.pa05b_request(
    '90000000-0000-0000-0000-000000000801', 'h2-record-stop-one', 1,
    '10000000-0000-0000-0000-000000000101',
    jsonb_build_object(
      'purchase_order_line_revision_id', '40000000-0000-0000-0000-000000000711',
      'supplier_id', '20000000-0000-0000-0000-000000000104',
      'ingredient_id', '20000000-0000-0000-0000-000000000103',
      'unit_id', '20000000-0000-0000-0000-000000000102',
      'evidence_quantity', 10,
      'evidence_reference', 'PA05B-H2-STOP-ONE',
      'occurred_at', '2026-07-15T01:40:00+00:00'
    )
  )),
  ('h2_record_stop_two', pg_temp.pa05b_request(
    '90000000-0000-0000-0000-000000000802', 'h2-record-stop-two', 1,
    '10000000-0000-0000-0000-000000000101',
    jsonb_build_object(
      'purchase_order_line_revision_id', '40000000-0000-0000-0000-000000000713',
      'supplier_id', '20000000-0000-0000-0000-000000000104',
      'ingredient_id', '20000000-0000-0000-0000-000000000103',
      'unit_id', '20000000-0000-0000-0000-000000000102',
      'evidence_quantity', 5,
      'evidence_reference', 'PA05B-H2-STOP-TWO',
      'occurred_at', '2026-07-15T01:40:00+00:00'
    )
  ));

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000101', true);
insert into pa05b_results select 'h2_record_stop_one', atlas_api.record_supplier_receiving_evidence(request_payload)
from pa05b_requests where request_name = 'h2_record_stop_one';
insert into pa05b_results select 'h2_record_stop_two', atlas_api.record_supplier_receiving_evidence(request_payload)
from pa05b_requests where request_name = 'h2_record_stop_two';
reset role;

insert into pa05b_requests (request_name, request_payload)
select 'h2_apply_stop_one', pg_temp.pa05b_request(
  '90000000-0000-0000-0000-000000000803', 'h2-apply-stop-one', 1,
  '10000000-0000-0000-0000-000000000101',
  jsonb_build_object(
    'supplier_receiving_evidence_id', response_payload -> 'affected_aggregate_ids' ->> 'supplier_receiving_evidence_id',
    'fulfilment_allocation_line_revision_id', '40000000-0000-0000-0000-000000000633',
    'unit_id', '20000000-0000-0000-0000-000000000102',
    'applied_quantity', 10,
    'occurred_at', '2026-07-15T01:41:00+00:00'
  )
) from pa05b_results where result_name = 'h2_record_stop_one';

insert into pa05b_requests (request_name, request_payload)
select 'h2_apply_stop_two', pg_temp.pa05b_request(
  '90000000-0000-0000-0000-000000000804', 'h2-apply-stop-two', 1,
  '10000000-0000-0000-0000-000000000101',
  jsonb_build_object(
    'supplier_receiving_evidence_id', response_payload -> 'affected_aggregate_ids' ->> 'supplier_receiving_evidence_id',
    'fulfilment_allocation_line_revision_id', '40000000-0000-0000-0000-000000000643',
    'unit_id', '20000000-0000-0000-0000-000000000102',
    'applied_quantity', 5,
    'occurred_at', '2026-07-15T01:41:00+00:00'
  )
) from pa05b_results where result_name = 'h2_record_stop_two';

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000101', true);
insert into pa05b_results select 'h2_apply_stop_one', atlas_api.apply_supplier_evidence_to_allocation(request_payload)
from pa05b_requests where request_name = 'h2_apply_stop_one';
insert into pa05b_results select 'h2_apply_stop_two', atlas_api.apply_supplier_evidence_to_allocation(request_payload)
from pa05b_requests where request_name = 'h2_apply_stop_two';
reset role;

select ok((select (response_payload ->> 'success')::boolean from pa05b_results where result_name = 'h2_apply_stop_one'), 'first multi-stop allocation has command-authored Evidence coverage');
select ok((select (response_payload ->> 'success')::boolean from pa05b_results where result_name = 'h2_apply_stop_two'), 'second multi-stop allocation has command-authored Evidence coverage');

insert into pa05b_requests (request_name, request_payload)
select 'h2_load_stop_one', pg_temp.pa05b_request(
  '90000000-0000-0000-0000-000000000805', 'h2-load-stop-one', 1,
  '10000000-0000-0000-0000-000000000101',
  jsonb_build_object(
    'dispatch_trip_id', '50000000-0000-0000-0000-000000000953',
    'dispatch_stop_id', '50000000-0000-0000-0000-000000000954',
    'dispatch_requirement_revision_id', '30000000-0000-0000-0000-000000000531',
    'fulfilment_allocation_revision_id', '40000000-0000-0000-0000-000000000631',
    'loaded_at', '2026-07-15T01:45:00+00:00',
    'lines', jsonb_build_array(jsonb_build_object(
      'dispatch_requirement_line_revision_id', '30000000-0000-0000-0000-000000000533',
      'fulfilment_allocation_line_revision_id', '40000000-0000-0000-0000-000000000633',
      'loaded_quantity', 10,
      'unit_id', '20000000-0000-0000-0000-000000000102',
      'evidence_applications', jsonb_build_array(jsonb_build_object(
        'evidence_application_id', response_payload -> 'affected_aggregate_ids' ->> 'evidence_application_id',
        'applied_to_load_quantity', 10,
        'unit_id', '20000000-0000-0000-0000-000000000102'
      ))
    ))
  )
) || jsonb_build_object('contract_version', 'PA-05B-H2.v1')
from pa05b_results where result_name = 'h2_apply_stop_one';

insert into pa05b_requests (request_name, request_payload)
select 'h2_load_stop_two', pg_temp.pa05b_request(
  '90000000-0000-0000-0000-000000000806', 'h2-load-stop-two', 2,
  '10000000-0000-0000-0000-000000000101',
  jsonb_build_object(
    'dispatch_trip_id', '50000000-0000-0000-0000-000000000953',
    'dispatch_stop_id', '50000000-0000-0000-0000-000000000955',
    'dispatch_requirement_revision_id', '30000000-0000-0000-0000-000000000541',
    'fulfilment_allocation_revision_id', '40000000-0000-0000-0000-000000000641',
    'loaded_at', '2026-07-15T01:46:00+00:00',
    'lines', jsonb_build_array(jsonb_build_object(
      'dispatch_requirement_line_revision_id', '30000000-0000-0000-0000-000000000543',
      'fulfilment_allocation_line_revision_id', '40000000-0000-0000-0000-000000000643',
      'loaded_quantity', 5,
      'unit_id', '20000000-0000-0000-0000-000000000102',
      'evidence_applications', jsonb_build_array(jsonb_build_object(
        'evidence_application_id', response_payload -> 'affected_aggregate_ids' ->> 'evidence_application_id',
        'applied_to_load_quantity', 5,
        'unit_id', '20000000-0000-0000-0000-000000000102'
      ))
    ))
  )
) || jsonb_build_object('contract_version', 'PA-05B-H2.v1')
from pa05b_results where result_name = 'h2_apply_stop_two';

-- A GLOBAL-scoped actor must still fail closed when a Dispatch stop is
-- cross-wired away from the Planning-owned destination.
insert into pa05b_requests (request_name, request_payload)
select 'h2_load_crosswired_destination',
       (request_payload - 'command_id' - 'idempotency_key' - 'requested_by_auth_subject') ||
       jsonb_build_object(
         'command_id', '90000000-0000-0000-0000-000000000818',
         'idempotency_key', 'h2-load-crosswired-destination',
         'requested_by_auth_subject', '10000000-0000-0000-0000-000000000199'
       )
from pa05b_requests where request_name = 'h2_load_stop_one';

update atlas_dispatch.dispatch_stops
set customer_id = '20000000-0000-0000-0000-000000000110',
    delivery_location_id = '20000000-0000-0000-0000-000000000111'
where dispatch_stop_id = '50000000-0000-0000-0000-000000000954';

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000199', true);
insert into pa05b_results
select 'h2_load_crosswired_destination', atlas_api.confirm_dispatch_load(request_payload)
from pa05b_requests where request_name = 'h2_load_crosswired_destination';
reset role;

select is(
  (select response_payload ->> 'error_code' from pa05b_results where result_name = 'h2_load_crosswired_destination'),
  'INVARIANT_VIOLATION',
  'GLOBAL-scoped load rejects a stop cross-wired from its Planning destination'
);
select is(
  (select count(*)::integer from atlas_dispatch.dispatch_loads where dispatch_trip_id = '50000000-0000-0000-0000-000000000953'),
  0,
  'cross-wired load creates no load root'
);
select is(
  (
    select count(*)::integer
    from atlas_dispatch.dispatch_load_lines dll
    join atlas_dispatch.dispatch_loads dl on dl.dispatch_load_id = dll.dispatch_load_id
    where dl.dispatch_trip_id = '50000000-0000-0000-0000-000000000953'
  ),
  0,
  'cross-wired load creates no load line'
);
select is(
  (
    select count(*)::integer
    from atlas_dispatch.dispatch_load_line_applications dlla
    join atlas_dispatch.dispatch_load_lines dll on dll.dispatch_load_line_id = dlla.dispatch_load_line_id
    join atlas_dispatch.dispatch_loads dl on dl.dispatch_load_id = dll.dispatch_load_id
    where dl.dispatch_trip_id = '50000000-0000-0000-0000-000000000953'
  ),
  0,
  'cross-wired load creates no evidence bridge'
);
select is(
  (select count(*)::integer from atlas_audit.domain_events where command_id = '90000000-0000-0000-0000-000000000818'),
  0,
  'cross-wired load emits no domain event'
);
select is(
  (select count(*)::integer from atlas_audit.audit_events where command_id = '90000000-0000-0000-0000-000000000818'),
  0,
  'cross-wired load emits no audit event'
);

update atlas_dispatch.dispatch_stops
set customer_id = '20000000-0000-0000-0000-000000000100',
    delivery_location_id = '20000000-0000-0000-0000-000000000101'
where dispatch_stop_id = '50000000-0000-0000-0000-000000000954';

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000101', true);
insert into pa05b_results select 'h2_load_stop_one', atlas_api.confirm_dispatch_load(request_payload)
from pa05b_requests where request_name = 'h2_load_stop_one';
reset role;

select ok((select (response_payload ->> 'success')::boolean from pa05b_results where result_name = 'h2_load_stop_one'), 'first stop loads and moves the trip to LOADED');
select is((select version::integer from atlas_dispatch.dispatch_trips where dispatch_trip_id = '50000000-0000-0000-0000-000000000953'), 2, 'first stop load increments the trip once');

insert into pa05b_requests (request_name, request_payload) values (
  'h2_depart_incomplete',
  pg_temp.pa05b_request(
    '90000000-0000-0000-0000-000000000807', 'h2-depart-incomplete', 2,
    '10000000-0000-0000-0000-000000000101',
    jsonb_build_object(
      'dispatch_trip_id', '50000000-0000-0000-0000-000000000953',
      'departed_at', '2026-07-15T02:00:00+00:00'
    )
  ) || jsonb_build_object('contract_version', 'PA-05B-H2.v1')
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000101', true);
insert into pa05b_results select 'h2_depart_incomplete', atlas_api.record_dispatch_departure(request_payload)
from pa05b_requests where request_name = 'h2_depart_incomplete';
reset role;

select is((select response_payload ->> 'error_code' from pa05b_results where result_name = 'h2_depart_incomplete'), 'DEPARTURE_BLOCKED', 'departure rejects a multi-stop trip with a missing stop load');
select is((select count(*)::integer from atlas_audit.domain_events where command_id = '90000000-0000-0000-0000-000000000807'), 0, 'blocked incomplete departure emits no domain event');

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000101', true);
insert into pa05b_results select 'h2_load_stop_two', atlas_api.confirm_dispatch_load(request_payload)
from pa05b_requests where request_name = 'h2_load_stop_two';
insert into pa05b_results select 'h2_load_stop_two_replay', atlas_api.confirm_dispatch_load(request_payload)
from pa05b_requests where request_name = 'h2_load_stop_two';
reset role;

select ok((select (response_payload ->> 'success')::boolean from pa05b_results where result_name = 'h2_load_stop_two'), 'second stop loads while trip remains LOADED');
select is((select response_payload from pa05b_results where result_name = 'h2_load_stop_two_replay'), (select response_payload from pa05b_results where result_name = 'h2_load_stop_two'), 'nested second-stop load replay returns original IDs');
select is((select trip_status from atlas_dispatch.dispatch_trips where dispatch_trip_id = '50000000-0000-0000-0000-000000000953'), 'LOADED', 'second stop load keeps the trip LOADED');
select is((select version::integer from atlas_dispatch.dispatch_trips where dispatch_trip_id = '50000000-0000-0000-0000-000000000953'), 3, 'second stop load increments trip exactly once');
select is((select count(*)::integer from atlas_dispatch.dispatch_loads where dispatch_trip_id = '50000000-0000-0000-0000-000000000953'), 2, 'multi-stop trip has exactly one load root per stop');

-- Exact nested hashes conflict, and obsolete or malformed shapes fail before writes.
insert into pa05b_requests (request_name, request_payload)
select 'h2_load_nested_conflict',
       jsonb_set(
         request_payload,
         '{payload,lines,0,loaded_quantity}',
         '4'::jsonb
       )
from pa05b_requests where request_name = 'h2_load_stop_two';

insert into pa05b_requests (request_name, request_payload)
select 'h2_load_old_shape',
       jsonb_set(
         jsonb_set(
           jsonb_set(
             (request_payload - 'command_id' - 'idempotency_key') ||
               jsonb_build_object(
                 'command_id', '90000000-0000-0000-0000-000000000808',
                 'idempotency_key', 'h2-load-old-shape'
               ),
             '{payload}',
             (request_payload -> 'payload') - 'lines'
           ),
           '{payload,loaded_quantity}', '5'::jsonb
         ),
         '{payload,fulfilment_allocation_line_revision_id}',
         to_jsonb('40000000-0000-0000-0000-000000000643'::text)
       )
from pa05b_requests where request_name = 'h2_load_stop_two';

insert into pa05b_requests (request_name, request_payload)
select 'h2_load_unknown_field',
       jsonb_set(
         (request_payload - 'command_id' - 'idempotency_key') ||
           jsonb_build_object(
             'command_id', '90000000-0000-0000-0000-000000000809',
             'idempotency_key', 'h2-load-unknown'
           ),
         '{payload,unexpected}', 'true'::jsonb
       )
from pa05b_requests where request_name = 'h2_load_stop_two';

insert into pa05b_requests (request_name, request_payload)
select 'h2_load_duplicate_line',
       jsonb_set(
         (request_payload - 'command_id' - 'idempotency_key') ||
           jsonb_build_object(
             'command_id', '90000000-0000-0000-0000-000000000810',
             'idempotency_key', 'h2-load-duplicate'
           ),
         '{payload,lines}',
         jsonb_build_array(request_payload -> 'payload' -> 'lines' -> 0, request_payload -> 'payload' -> 'lines' -> 0)
       )
from pa05b_requests where request_name = 'h2_load_stop_two';

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000101', true);
insert into pa05b_results select 'h2_load_nested_conflict', atlas_api.confirm_dispatch_load(request_payload)
from pa05b_requests where request_name = 'h2_load_nested_conflict';
insert into pa05b_results select 'h2_load_old_shape', atlas_api.confirm_dispatch_load(request_payload)
from pa05b_requests where request_name = 'h2_load_old_shape';
insert into pa05b_results select 'h2_load_unknown_field', atlas_api.confirm_dispatch_load(request_payload)
from pa05b_requests where request_name = 'h2_load_unknown_field';
insert into pa05b_results select 'h2_load_duplicate_line', atlas_api.confirm_dispatch_load(request_payload)
from pa05b_requests where request_name = 'h2_load_duplicate_line';
reset role;

select is((select response_payload ->> 'error_code' from pa05b_results where result_name = 'h2_load_nested_conflict'), 'IDEMPOTENCY_CONFLICT', 'changed nested load payload conflicts with completed command identity');
select is((select response_payload ->> 'error_code' from pa05b_results where result_name = 'h2_load_old_shape'), 'VALIDATION_FAILED', 'obsolete single-line load shape is rejected');
select is((select response_payload ->> 'error_code' from pa05b_results where result_name = 'h2_load_unknown_field'), 'VALIDATION_FAILED', 'unknown load payload field is rejected');
select is((select response_payload ->> 'error_code' from pa05b_results where result_name = 'h2_load_duplicate_line'), 'VALIDATION_FAILED', 'duplicate nested load-line identity is rejected');
select is((select count(*)::integer from atlas_dispatch.dispatch_loads where dispatch_trip_id = '50000000-0000-0000-0000-000000000953'), 2, 'failed and replayed load requests add no load roots');

-- A GLOBAL-scoped actor cannot depart a fully loaded trip whose stop is
-- cross-wired away from its authoritative Planning destination.
update atlas_dispatch.dispatch_stops
set customer_id = '20000000-0000-0000-0000-000000000110',
    delivery_location_id = '20000000-0000-0000-0000-000000000111'
where dispatch_stop_id = '50000000-0000-0000-0000-000000000955';

insert into pa05b_requests (request_name, request_payload) values (
  'h2_depart_crosswired_destination',
  pg_temp.pa05b_request(
    '90000000-0000-0000-0000-000000000819', 'h2-depart-crosswired-destination', 3,
    '10000000-0000-0000-0000-000000000199',
    jsonb_build_object(
      'dispatch_trip_id', '50000000-0000-0000-0000-000000000953',
      'departed_at', '2026-07-15T02:00:00+00:00'
    )
  ) || jsonb_build_object('contract_version', 'PA-05B-H2.v1')
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000199', true);
insert into pa05b_results
select 'h2_depart_crosswired_destination', atlas_api.record_dispatch_departure(request_payload)
from pa05b_requests where request_name = 'h2_depart_crosswired_destination';
reset role;

select is(
  (select response_payload ->> 'error_code' from pa05b_results where result_name = 'h2_depart_crosswired_destination'),
  'INVARIANT_VIOLATION',
  'GLOBAL-scoped departure rejects a cross-wired authoritative stop destination'
);
select is(
  (select trip_status from atlas_dispatch.dispatch_trips where dispatch_trip_id = '50000000-0000-0000-0000-000000000953'),
  'LOADED',
  'cross-wired departure leaves the trip LOADED'
);
select is(
  (select count(*)::integer from atlas_dispatch.dispatch_stops where dispatch_trip_id = '50000000-0000-0000-0000-000000000953' and stop_status = 'LOADED'),
  2,
  'cross-wired departure leaves every stop LOADED'
);
select is(
  (select count(*)::integer from atlas_audit.domain_events where command_id = '90000000-0000-0000-0000-000000000819'),
  0,
  'cross-wired departure emits no domain event'
);
select is(
  (select count(*)::integer from atlas_audit.audit_events where command_id = '90000000-0000-0000-0000-000000000819'),
  0,
  'cross-wired departure emits no audit event'
);

update atlas_dispatch.dispatch_stops
set customer_id = '20000000-0000-0000-0000-000000000100',
    delivery_location_id = '20000000-0000-0000-0000-000000000101'
where dispatch_stop_id = '50000000-0000-0000-0000-000000000955';

-- Assignment must exist independently of otherwise valid plan membership.
insert into atlas_dispatch.dispatch_trips (
  dispatch_trip_id, dispatch_plan_id, trip_reference, trip_status,
  driver_actor_id, vehicle_reference, planned_departure_at
) values (
  '50000000-0000-0000-0000-000000000956',
  '50000000-0000-0000-0000-000000000950', 'PA05B-H2-NO-ASSIGNMENT',
  'ASSIGNED', null, null, timestamptz '2026-07-15 02:00:00+00'
);
insert into atlas_dispatch.dispatch_stops (
  dispatch_stop_id, dispatch_trip_id, stop_sequence,
  dispatch_requirement_revision_id, customer_id, delivery_location_id
) values (
  '50000000-0000-0000-0000-000000000957',
  '50000000-0000-0000-0000-000000000956', 1,
  '30000000-0000-0000-0000-000000000541',
  '20000000-0000-0000-0000-000000000100',
  '20000000-0000-0000-0000-000000000101'
);

insert into pa05b_requests (request_name, request_payload)
select 'h2_load_no_assignment',
       jsonb_set(
         jsonb_set(
           jsonb_set(
             (request_payload - 'command_id' - 'idempotency_key') ||
               jsonb_build_object(
                 'command_id', '90000000-0000-0000-0000-000000000811',
                 'idempotency_key', 'h2-load-no-assignment',
                 'expected_version', 1
               ),
             '{payload,dispatch_trip_id}', to_jsonb('50000000-0000-0000-0000-000000000956'::text)
           ),
           '{payload,dispatch_stop_id}', to_jsonb('50000000-0000-0000-0000-000000000957'::text)
         ),
         '{payload,loaded_at}', to_jsonb('2026-07-15T01:47:00+00:00'::text)
       )
from pa05b_requests where request_name = 'h2_load_stop_two';

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000101', true);
insert into pa05b_results select 'h2_load_no_assignment', atlas_api.confirm_dispatch_load(request_payload)
from pa05b_requests where request_name = 'h2_load_no_assignment';
reset role;

select is((select response_payload ->> 'error_code' from pa05b_results where result_name = 'h2_load_no_assignment'), 'TRIP_ASSIGNMENT_REQUIRED', 'load rejects a trip without an active driver or vehicle reference');
select is((select count(*)::integer from atlas_dispatch.dispatch_loads where dispatch_trip_id = '50000000-0000-0000-0000-000000000956'), 0, 'assignment failure creates no load facts');

-- Customer-scoped authorization remains a separate rule: this fixture has
-- two internally valid authoritative Planning destinations, while the actor
-- is scoped only to the first customer.
insert into atlas_planning.dispatch_requirements (
  dispatch_requirement_id, customer_id, delivery_location_id,
  service_date, requirement_status
) values (
  '30000000-0000-0000-0000-000000000550',
  '20000000-0000-0000-0000-000000000110',
  '20000000-0000-0000-0000-000000000111',
  date '2026-07-15', 'RELEASED'
);

insert into atlas_planning.purchase_handoff_revisions (
  purchase_handoff_revision_id, purchase_handoff_batch_id,
  revision_number, revision_kind, revision_status, is_current,
  predecessor_revision_id, released_by_actor_id, released_at
) values (
  '31000000-0000-0000-0000-000000000825',
  '31000000-0000-0000-0000-000000000820',
  2, 'ADDITIVE', 'RELEASED_TO_PROCUREMENT', false,
  '31000000-0000-0000-0000-000000000821',
  '10000000-0000-0000-0000-000000000001',
  timestamptz '2026-07-15 00:29:00+00'
);

insert into atlas_planning.dispatch_requirement_revisions (
  dispatch_requirement_revision_id, dispatch_requirement_id,
  purchase_handoff_revision_id, revision_number, revision_status,
  customer_name_snapshot, location_name_snapshot, address_snapshot,
  released_by_actor_id, released_at
) values (
  '30000000-0000-0000-0000-000000000551',
  '30000000-0000-0000-0000-000000000550',
  '31000000-0000-0000-0000-000000000825', 1, 'RELEASED',
  'PA-05B other customer', 'PA-05B other location', 'PA-05B other address',
  '10000000-0000-0000-0000-000000000001',
  timestamptz '2026-07-15 00:30:00+00'
);

insert into atlas_procurement.fulfilment_allocations (
  fulfilment_allocation_id, dispatch_requirement_id, allocation_status
) values (
  '40000000-0000-0000-0000-000000000650',
  '30000000-0000-0000-0000-000000000550', 'READY_FOR_DISPATCH'
);

insert into atlas_procurement.fulfilment_allocation_revisions (
  fulfilment_allocation_revision_id, fulfilment_allocation_id,
  revision_number, revision_status, allocated_by_actor_id
) values (
  '40000000-0000-0000-0000-000000000651',
  '40000000-0000-0000-0000-000000000650', 1, 'READY_FOR_DISPATCH',
  '10000000-0000-0000-0000-000000000001'
);

insert into atlas_dispatch.dispatch_plan_requirements (
  dispatch_plan_requirement_id, dispatch_plan_id,
  dispatch_requirement_revision_id, fulfilment_allocation_revision_id
) values (
  '50000000-0000-0000-0000-000000000962',
  '50000000-0000-0000-0000-000000000950',
  '30000000-0000-0000-0000-000000000551',
  '40000000-0000-0000-0000-000000000651'
);

insert into atlas_dispatch.dispatch_trips (
  dispatch_trip_id, dispatch_plan_id, trip_reference, trip_status,
  driver_actor_id, vehicle_reference, planned_departure_at
) values (
  '50000000-0000-0000-0000-000000000963',
  '50000000-0000-0000-0000-000000000950', 'PA05B-H2-SCOPE-TRIP', 'LOADED',
  '10000000-0000-0000-0000-000000000001', 'PA05B-H2-SCOPE-VEHICLE',
  timestamptz '2026-07-15 02:00:00+00'
);

insert into atlas_dispatch.dispatch_stops (
  dispatch_stop_id, dispatch_trip_id, stop_sequence,
  dispatch_requirement_revision_id, customer_id, delivery_location_id,
  stop_status
) values
  (
    '50000000-0000-0000-0000-000000000964',
    '50000000-0000-0000-0000-000000000963', 1,
    '30000000-0000-0000-0000-000000000531',
    '20000000-0000-0000-0000-000000000100',
    '20000000-0000-0000-0000-000000000101', 'LOADED'
  ),
  (
    '50000000-0000-0000-0000-000000000965',
    '50000000-0000-0000-0000-000000000963', 2,
    '30000000-0000-0000-0000-000000000551',
    '20000000-0000-0000-0000-000000000110',
    '20000000-0000-0000-0000-000000000111', 'LOADED'
  );

insert into pa05b_requests (request_name, request_payload) values (
  'h2_depart_partial_scope',
  pg_temp.pa05b_request(
    '90000000-0000-0000-0000-000000000812', 'h2-depart-partial-scope', 1,
    '10000000-0000-0000-0000-000000000101',
    jsonb_build_object(
      'dispatch_trip_id', '50000000-0000-0000-0000-000000000963',
      'departed_at', '2026-07-15T02:00:00+00:00'
    )
  ) || jsonb_build_object('contract_version', 'PA-05B-H2.v1')
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000101', true);
insert into pa05b_results select 'h2_depart_partial_scope', atlas_api.record_dispatch_departure(request_payload)
from pa05b_requests where request_name = 'h2_depart_partial_scope';
reset role;

select is((select response_payload ->> 'error_code' from pa05b_results where result_name = 'h2_depart_partial_scope'), 'SCOPE_DENIED', 'customer-scoped departure rejects a second authoritative Planning customer');
select is((select count(*)::integer from atlas_core.command_receipts where command_id = '90000000-0000-0000-0000-000000000812'), 0, 'trip-wide authorization failure occurs before receipt registration');

insert into pa05b_requests (request_name, request_payload) values (
  'h2_depart_multi_stop',
  pg_temp.pa05b_request(
    '90000000-0000-0000-0000-000000000813', 'h2-depart-multi-stop', 3,
    '10000000-0000-0000-0000-000000000101',
    jsonb_build_object(
      'dispatch_trip_id', '50000000-0000-0000-0000-000000000953',
      'departed_at', '2026-07-15T02:00:00+00:00'
    )
  ) || jsonb_build_object('contract_version', 'PA-05B-H2.v1')
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000101', true);
insert into pa05b_results select 'h2_depart_multi_stop', atlas_api.record_dispatch_departure(request_payload)
from pa05b_requests where request_name = 'h2_depart_multi_stop';
insert into pa05b_results select 'h2_depart_multi_stop_replay', atlas_api.record_dispatch_departure(request_payload)
from pa05b_requests where request_name = 'h2_depart_multi_stop';
reset role;

select ok((select (response_payload ->> 'success')::boolean from pa05b_results where result_name = 'h2_depart_multi_stop'), 'fully loaded and authorized multi-stop trip departs');
select is((select response_payload from pa05b_results where result_name = 'h2_depart_multi_stop_replay'), (select response_payload from pa05b_results where result_name = 'h2_depart_multi_stop'), 'multi-stop departure supports exact replay');
select is((select trip_status from atlas_dispatch.dispatch_trips where dispatch_trip_id = '50000000-0000-0000-0000-000000000953'), 'IN_TRANSIT', 'departure advances the multi-stop trip');
select is((select version::integer from atlas_dispatch.dispatch_trips where dispatch_trip_id = '50000000-0000-0000-0000-000000000953'), 4, 'departure increments the trip exactly once');
select is((select count(*)::integer from atlas_dispatch.dispatch_stops where dispatch_trip_id = '50000000-0000-0000-0000-000000000953' and stop_status = 'IN_TRANSIT' and version = 3), 2, 'departure increments every selected-trip stop exactly once');

insert into pa05b_requests (request_name, request_payload)
select 'h2_delivery_stop_one',
       pg_temp.pa05b_request(
         '90000000-0000-0000-0000-000000000814', 'h2-delivery-stop-one', 4,
         '10000000-0000-0000-0000-000000000101',
         jsonb_build_object(
           'dispatch_trip_id', '50000000-0000-0000-0000-000000000953',
           'dispatch_stop_id', '50000000-0000-0000-0000-000000000954',
           'confirmed_at', '2026-07-15T02:10:00+00:00',
           'received_by_reference', 'H2-STOP-ONE-RECEIVER',
           'notes', null,
           'lines', loaded.lines
         )
       ) || jsonb_build_object('contract_version', 'PA-05B-H2.v1')
from (
  select jsonb_agg(jsonb_build_object(
    'dispatch_load_line_id', dll.dispatch_load_line_id,
    'delivered_quantity', dll.loaded_quantity,
    'returned_quantity', 0,
    'exception_quantity', 0,
    'unit_id', dll.unit_id
  ) order by dll.dispatch_load_line_id) as lines
  from atlas_dispatch.dispatch_load_lines dll
  where dll.dispatch_stop_id = '50000000-0000-0000-0000-000000000954'
) loaded;

insert into pa05b_requests (request_name, request_payload)
select 'h2_delivery_stop_two',
       pg_temp.pa05b_request(
         '90000000-0000-0000-0000-000000000815', 'h2-delivery-stop-two', 5,
         '10000000-0000-0000-0000-000000000101',
         jsonb_build_object(
           'dispatch_trip_id', '50000000-0000-0000-0000-000000000953',
           'dispatch_stop_id', '50000000-0000-0000-0000-000000000955',
           'confirmed_at', '2026-07-15T02:15:00+00:00',
           'received_by_reference', null,
           'notes', 'final H2 stop',
           'lines', loaded.lines
         )
       ) || jsonb_build_object('contract_version', 'PA-05B-H2.v1')
from (
  select jsonb_agg(jsonb_build_object(
    'dispatch_load_line_id', dll.dispatch_load_line_id,
    'delivered_quantity', dll.loaded_quantity,
    'returned_quantity', 0,
    'exception_quantity', 0,
    'unit_id', dll.unit_id
  ) order by dll.dispatch_load_line_id) as lines
  from atlas_dispatch.dispatch_load_lines dll
  where dll.dispatch_stop_id = '50000000-0000-0000-0000-000000000955'
) loaded;

-- A GLOBAL-scoped actor cannot confirm delivery through a stop destination
-- that no longer matches the exact Planning membership and confirmed load.
insert into pa05b_requests (request_name, request_payload)
select 'h2_delivery_crosswired_destination',
       (request_payload - 'command_id' - 'idempotency_key' - 'requested_by_auth_subject') ||
       jsonb_build_object(
         'command_id', '90000000-0000-0000-0000-000000000821',
         'idempotency_key', 'h2-delivery-crosswired-destination',
         'requested_by_auth_subject', '10000000-0000-0000-0000-000000000199'
       )
from pa05b_requests where request_name = 'h2_delivery_stop_one';

update atlas_dispatch.dispatch_stops
set customer_id = '20000000-0000-0000-0000-000000000110',
    delivery_location_id = '20000000-0000-0000-0000-000000000111'
where dispatch_stop_id = '50000000-0000-0000-0000-000000000954';

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000199', true);
insert into pa05b_results
select 'h2_delivery_crosswired_destination', atlas_api.confirm_successful_delivery(request_payload)
from pa05b_requests where request_name = 'h2_delivery_crosswired_destination';
reset role;

select is(
  (select response_payload ->> 'error_code' from pa05b_results where result_name = 'h2_delivery_crosswired_destination'),
  'INVARIANT_VIOLATION',
  'GLOBAL-scoped delivery rejects a stop cross-wired from its exact Planning membership'
);
select is(
  (select count(*)::integer from atlas_dispatch.delivery_confirmations where dispatch_stop_id = '50000000-0000-0000-0000-000000000954'),
  0,
  'cross-wired delivery creates no confirmation root'
);
select is(
  (
    select count(*)::integer
    from atlas_dispatch.delivery_confirmation_lines dcl
    join atlas_dispatch.delivery_confirmations dc
      on dc.delivery_confirmation_id = dcl.delivery_confirmation_id
    where dc.dispatch_stop_id = '50000000-0000-0000-0000-000000000954'
  ),
  0,
  'cross-wired delivery creates no confirmation line'
);
select is(
  (select count(*)::integer from atlas_audit.domain_events where command_id = '90000000-0000-0000-0000-000000000821'),
  0,
  'cross-wired delivery emits no domain event'
);
select is(
  (select count(*)::integer from atlas_audit.audit_events where command_id = '90000000-0000-0000-0000-000000000821'),
  0,
  'cross-wired delivery emits no audit event'
);

update atlas_dispatch.dispatch_stops
set customer_id = '20000000-0000-0000-0000-000000000100',
    delivery_location_id = '20000000-0000-0000-0000-000000000101'
where dispatch_stop_id = '50000000-0000-0000-0000-000000000954';

insert into pa05b_requests (request_name, request_payload)
select 'h2_delivery_old_shape',
       jsonb_set(
         jsonb_set(
           (request_payload - 'command_id' - 'idempotency_key') ||
             jsonb_build_object(
               'command_id', '90000000-0000-0000-0000-000000000816',
               'idempotency_key', 'h2-delivery-old-shape'
             ),
           '{payload}', (request_payload -> 'payload') - 'lines'
         ),
         '{payload,dispatch_load_line_id}',
         to_jsonb((request_payload -> 'payload' -> 'lines' -> 0 ->> 'dispatch_load_line_id'))
       )
from pa05b_requests where request_name = 'h2_delivery_stop_one';

insert into pa05b_requests (request_name, request_payload)
select 'h2_delivery_empty_lines',
       jsonb_set(
         (request_payload - 'command_id' - 'idempotency_key') ||
           jsonb_build_object(
             'command_id', '90000000-0000-0000-0000-000000000817',
             'idempotency_key', 'h2-delivery-empty-lines'
           ),
         '{payload,lines}', '[]'::jsonb
       )
from pa05b_requests where request_name = 'h2_delivery_stop_one';

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000101', true);
insert into pa05b_results select 'h2_delivery_old_shape', atlas_api.confirm_successful_delivery(request_payload)
from pa05b_requests where request_name = 'h2_delivery_old_shape';
insert into pa05b_results select 'h2_delivery_empty_lines', atlas_api.confirm_successful_delivery(request_payload)
from pa05b_requests where request_name = 'h2_delivery_empty_lines';
insert into pa05b_results select 'h2_delivery_stop_one', atlas_api.confirm_successful_delivery(request_payload)
from pa05b_requests where request_name = 'h2_delivery_stop_one';
reset role;

select is((select response_payload ->> 'error_code' from pa05b_results where result_name = 'h2_delivery_old_shape'), 'VALIDATION_FAILED', 'obsolete single-load-line delivery shape is rejected');
select is((select response_payload ->> 'error_code' from pa05b_results where result_name = 'h2_delivery_empty_lines'), 'VALIDATION_FAILED', 'empty delivery line set is rejected');
select ok((select (response_payload ->> 'success')::boolean from pa05b_results where result_name = 'h2_delivery_stop_one'), 'first multi-stop delivery confirms atomically');
select is((select trip_status from atlas_dispatch.dispatch_trips where dispatch_trip_id = '50000000-0000-0000-0000-000000000953'), 'PARTIALLY_DELIVERED', 'first delivered stop leaves the trip partially delivered');
select is((select version::integer from atlas_dispatch.dispatch_trips where dispatch_trip_id = '50000000-0000-0000-0000-000000000953'), 5, 'first delivery increments current trip version once');

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000101', true);
insert into pa05b_results select 'h2_delivery_stop_two', atlas_api.confirm_successful_delivery(request_payload)
from pa05b_requests where request_name = 'h2_delivery_stop_two';
insert into pa05b_results select 'h2_delivery_stop_two_replay', atlas_api.confirm_successful_delivery(request_payload)
from pa05b_requests where request_name = 'h2_delivery_stop_two';
reset role;

select ok((select (response_payload ->> 'success')::boolean from pa05b_results where result_name = 'h2_delivery_stop_two'), 'final multi-stop delivery confirms atomically');
select is((select response_payload from pa05b_results where result_name = 'h2_delivery_stop_two_replay'), (select response_payload from pa05b_results where result_name = 'h2_delivery_stop_two'), 'final delivery replay returns original confirmation IDs');
select is((select trip_status from atlas_dispatch.dispatch_trips where dispatch_trip_id = '50000000-0000-0000-0000-000000000953'), 'DELIVERED', 'final stop changes the trip to DELIVERED');
select is((select version::integer from atlas_dispatch.dispatch_trips where dispatch_trip_id = '50000000-0000-0000-0000-000000000953'), 6, 'final delivery increments current trip version once');
select is((select count(*)::integer from atlas_dispatch.delivery_confirmations dc join atlas_dispatch.dispatch_stops ds on ds.dispatch_stop_id = dc.dispatch_stop_id where ds.dispatch_trip_id = '50000000-0000-0000-0000-000000000953'), 2, 'multi-stop delivery creates exactly one confirmation root per stop');
select is((select count(*)::integer from atlas_dispatch.delivery_confirmation_lines dcl join atlas_dispatch.dispatch_load_lines dll on dll.dispatch_load_line_id = dcl.dispatch_load_line_id where dll.dispatch_stop_id in ('50000000-0000-0000-0000-000000000954', '50000000-0000-0000-0000-000000000955')), 2, 'multi-stop delivery creates every exact confirmation line once');
select is((select count(*)::integer from atlas_audit.domain_events where command_id in ('90000000-0000-0000-0000-000000000814', '90000000-0000-0000-0000-000000000815')), 2, 'two successful stop deliveries emit exactly two domain events');
select is((select count(*)::integer from atlas_audit.audit_events where command_id in ('90000000-0000-0000-0000-000000000814', '90000000-0000-0000-0000-000000000815')), 2, 'two successful stop deliveries emit exactly two audit events');

select * from finish();
rollback;
