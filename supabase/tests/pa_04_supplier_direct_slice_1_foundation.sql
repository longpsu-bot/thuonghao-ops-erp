begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;

select plan(23);

select is(
  (
    select count(*)::integer
    from pg_namespace
    where nspname in (
      'atlas_core',
      'atlas_admin',
      'atlas_planning',
      'atlas_procurement',
      'atlas_evidence',
      'atlas_dispatch',
      'atlas_audit',
      'atlas_reporting',
      'atlas_api'
    )
  ),
  9,
  'PA-04 creates the nine authorized Atlas schemas'
);

select ok(
  not exists (select 1 from pg_namespace where nspname = 'atlas_warehouse'),
  'PA-04 does not create the deferred Warehouse schema'
);

select is(
  (
    select count(*)::integer
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname like 'atlas\_%' escape '\'
      and c.relkind = 'r'
  ),
  52,
  'PA-04 creates only the bounded Slice 1 table set'
);

select is(
  (
    select count(*)::integer
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'atlas_reporting'
      and c.relkind = 'v'
  ),
  2,
  'PA-04 creates two private derived verification views'
);

select ok(
  not exists (
    select 1
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname in (
      'atlas_core',
      'atlas_admin',
      'atlas_planning',
      'atlas_procurement',
      'atlas_evidence',
      'atlas_dispatch',
      'atlas_audit'
    )
      and c.relkind = 'r'
      and (not c.relrowsecurity or not c.relforcerowsecurity)
  ),
  'every authoritative Atlas table has RLS enabled and forced'
);

select ok(
  not exists (
    select 1
    from unnest(array['anon', 'authenticated', 'service_role']) as api_role(role_name)
    cross join unnest(
      array[
        'atlas_core',
        'atlas_admin',
        'atlas_planning',
        'atlas_procurement',
        'atlas_evidence',
        'atlas_dispatch',
        'atlas_audit',
        'atlas_reporting'
      ]
    ) as atlas_schema(schema_name)
    where has_schema_privilege(api_role.role_name, atlas_schema.schema_name, 'USAGE')
  ),
  'API roles have no usage on private Atlas schemas'
);

select ok(
  not exists (
    select 1
    from unnest(array['anon', 'authenticated', 'service_role']) as api_role(role_name)
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
  'API roles have no direct Atlas table or view privileges'
);

select is(
  (
    select count(*)::integer
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
  ),
  13,
  'atlas_api contains only the reviewed PA-05B, PA-05C, and PA-05D entry functions'
);

select ok(
  not exists (
    select 1
    from pg_attribute a
    join pg_class c on c.oid = a.attrelid
    join pg_namespace n on n.oid = c.relnamespace
    join pg_type t on t.oid = a.atttypid
    where n.nspname like 'atlas\_%' escape '\'
      and c.relkind = 'r'
      and a.attnum > 0
      and not a.attisdropped
      and t.typname in ('float4', 'float8')
  ),
  'authoritative Atlas tables contain no binary floating-point columns'
);

select ok(
  exists (
    select 1
    from pg_indexes
    where schemaname = 'atlas_evidence'
      and indexname = 'evidence_applications_valid_pair_key'
      and indexdef ilike '%unique%'
      and indexdef ilike '%where (application_status = ''VALID''%'
  ),
  'duplicate active evidence applications are prevented'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'atlas_evidence.evidence_applications'::regclass
      and conname = 'evidence_applications_quantity_check'
      and pg_get_constraintdef(oid) ilike '%applied_quantity >%'
  ),
  'evidence application quantity must be positive'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'atlas_evidence.evidence_applications'::regclass
      and conname = 'evidence_applications_allocation_line_revision_fkey'
  ),
  'evidence applications reference an exact allocation-line revision'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'atlas_dispatch.dispatch_load_line_applications'::regclass
      and conname = 'dispatch_load_line_applications_evidence_application_fkey'
  ),
  'dispatch load lines consume evidence through applications'
);

select ok(
  coalesce(
    (
      select c.reloptions @> array['security_invoker=true']
      from pg_class c
      where c.oid = 'atlas_reporting.dispatch_evidence_readiness'::regclass
    ),
    false
  ),
  'dispatch evidence readiness is a security-invoker view'
);

select ok(
  coalesce(
    (
      select c.reloptions @> array['security_invoker=true']
      from pg_class c
      where c.oid = 'atlas_reporting.supplier_direct_slice_trace'::regclass
    ),
    false
  ),
  'supplier-direct trace is a security-invoker view'
);

select ok(
  not exists (
    select 1
    from pg_roles
    where rolname in ('atlas_owner', 'atlas_command_runtime', 'atlas_read_runtime')
      and rolcanlogin
  ),
  'Atlas database boundary roles cannot log in'
);

select ok(
  exists (
    select 1
    from pg_indexes
    where schemaname = 'atlas_audit'
      and indexname = 'audit_events_correlation_recorded_idx'
  ),
  'audit correlation timeline is indexed'
);

select ok(
  exists (
    select 1
    from pg_indexes
    where schemaname = 'atlas_dispatch'
      and indexname = 'dispatch_trips_status_departure_idx'
  ),
  'dispatch trip status and departure work is indexed'
);

insert into atlas_core.actors (
  actor_id,
  actor_type,
  display_name
) values (
  '00000000-0000-0000-0000-000000000001',
  'HUMAN',
  'PA-04 synthetic operator'
);

insert into atlas_core.actor_auth_subjects (
  actor_auth_subject_id,
  actor_id,
  auth_subject_id
) values (
  '00000000-0000-0000-0000-000000000010',
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000011'
);

update atlas_core.actor_auth_subjects
set subject_status = 'REVOKED',
    revoked_at = timestamptz '2026-07-15 00:01:00+00'
where actor_auth_subject_id = '00000000-0000-0000-0000-000000000010';

insert into atlas_core.actor_auth_subjects (
  actor_auth_subject_id,
  actor_id,
  auth_subject_id
) values (
  '00000000-0000-0000-0000-000000000012',
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000013'
);

update atlas_core.actor_auth_subjects
set subject_status = 'REVOKED',
    revoked_at = timestamptz '2026-07-15 00:02:00+00'
where actor_auth_subject_id = '00000000-0000-0000-0000-000000000012';

insert into atlas_core.actor_auth_subjects (
  actor_auth_subject_id,
  actor_id,
  auth_subject_id
) values (
  '00000000-0000-0000-0000-000000000014',
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000015'
);

select is(
  (
    select count(*)::integer
    from atlas_core.actor_auth_subjects
    where actor_id = '00000000-0000-0000-0000-000000000001'
      and subject_status = 'ACTIVE'
  ),
  1,
  'an actor can replace revoked auth subjects and retain one active subject'
);

select throws_ok(
  $$
    insert into atlas_core.actor_auth_subjects (
      actor_auth_subject_id,
      actor_id,
      auth_subject_id
    ) values (
      '00000000-0000-0000-0000-000000000016',
      '00000000-0000-0000-0000-000000000001',
      '00000000-0000-0000-0000-000000000017'
    )
  $$,
  '23505',
  'duplicate key value violates unique constraint "actor_auth_subjects_active_actor_key"',
  'actor_auth_subjects_active_actor_key rejects a second active subject for one actor'
);

select is(
  (
    select count(*)::integer
    from atlas_core.actor_auth_subjects
    where actor_id = '00000000-0000-0000-0000-000000000001'
      and subject_status = 'REVOKED'
      and auth_subject_id in (
        '00000000-0000-0000-0000-000000000011',
        '00000000-0000-0000-0000-000000000013'
      )
  ),
  2,
  'revoked historical auth-subject links remain queryable and unchanged'
);

insert into atlas_admin.customers (
  customer_id,
  customer_code,
  customer_name
) values (
  '00000000-0000-0000-0000-000000000100',
  'pa04-customer',
  'PA-04 synthetic wholesale customer'
);

insert into atlas_admin.delivery_locations (
  delivery_location_id,
  customer_id,
  location_code,
  location_name,
  address_text
) values (
  '00000000-0000-0000-0000-000000000101',
  '00000000-0000-0000-0000-000000000100',
  'pa04-location',
  'PA-04 synthetic delivery location',
  'Synthetic test address'
);

insert into atlas_admin.units (
  unit_id,
  unit_code,
  unit_name,
  dimension_code
) values (
  '00000000-0000-0000-0000-000000000102',
  'kg',
  'kilogram',
  'mass'
);

insert into atlas_admin.ingredients (
  ingredient_id,
  ingredient_code,
  ingredient_name
) values (
  '00000000-0000-0000-0000-000000000103',
  'pa04-rice',
  'PA-04 synthetic rice'
);

insert into atlas_admin.suppliers (
  supplier_id,
  supplier_code,
  supplier_name
) values (
  '00000000-0000-0000-0000-000000000104',
  'pa04-supplier',
  'PA-04 synthetic supplier'
);

insert into atlas_planning.wholesale_orders (
  wholesale_order_id,
  customer_id,
  delivery_location_id,
  customer_order_reference,
  service_date,
  order_status,
  created_by_actor_id,
  approved_by_actor_id,
  approved_at,
  released_by_actor_id,
  released_at
) values (
  '00000000-0000-0000-0000-000000000200',
  '00000000-0000-0000-0000-000000000100',
  '00000000-0000-0000-0000-000000000101',
  'PA04-ORDER-001',
  date '2026-07-15',
  'RELEASED',
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  timestamptz '2026-07-15 00:05:00+00',
  '00000000-0000-0000-0000-000000000001',
  timestamptz '2026-07-15 00:10:00+00'
);

insert into atlas_planning.wholesale_order_lines (
  wholesale_order_line_id,
  wholesale_order_id,
  source_line_number
) values (
  '00000000-0000-0000-0000-000000000201',
  '00000000-0000-0000-0000-000000000200',
  1
);

insert into atlas_planning.wholesale_order_line_revisions (
  wholesale_order_line_revision_id,
  wholesale_order_line_id,
  revision_number,
  ingredient_id,
  requested_quantity,
  unit_id,
  revision_status,
  created_by_actor_id
) values (
  '00000000-0000-0000-0000-000000000202',
  '00000000-0000-0000-0000-000000000201',
  1,
  '00000000-0000-0000-0000-000000000103',
  10,
  '00000000-0000-0000-0000-000000000102',
  'RELEASED',
  '00000000-0000-0000-0000-000000000001'
);

insert into atlas_planning.confirmed_need_batches (
  confirmed_need_batch_id,
  wholesale_order_id,
  period_start,
  period_end,
  batch_status,
  created_by_actor_id,
  approved_by_actor_id,
  approved_at,
  released_by_actor_id,
  released_at
) values (
  '00000000-0000-0000-0000-000000000300',
  '00000000-0000-0000-0000-000000000200',
  date '2026-07-15',
  date '2026-07-15',
  'RELEASED_FOR_PURCHASE_HANDOFF',
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  timestamptz '2026-07-15 00:15:00+00',
  '00000000-0000-0000-0000-000000000001',
  timestamptz '2026-07-15 00:20:00+00'
);

insert into atlas_planning.confirmed_need_lines (
  confirmed_need_line_id,
  confirmed_need_batch_id,
  wholesale_order_line_id
) values (
  '00000000-0000-0000-0000-000000000301',
  '00000000-0000-0000-0000-000000000300',
  '00000000-0000-0000-0000-000000000201'
);

insert into atlas_planning.confirmed_need_line_revisions (
  confirmed_need_line_revision_id,
  confirmed_need_line_id,
  revision_number,
  wholesale_order_line_revision_id,
  ingredient_id,
  theoretical_quantity,
  confirmed_quantity,
  unit_id,
  revision_status,
  created_by_actor_id
) values (
  '00000000-0000-0000-0000-000000000302',
  '00000000-0000-0000-0000-000000000301',
  1,
  '00000000-0000-0000-0000-000000000202',
  '00000000-0000-0000-0000-000000000103',
  10,
  10,
  '00000000-0000-0000-0000-000000000102',
  'RELEASED',
  '00000000-0000-0000-0000-000000000001'
);

insert into atlas_planning.purchase_handoff_batches (
  purchase_handoff_batch_id,
  confirmed_need_batch_id,
  period_start,
  period_end,
  handoff_status,
  created_by_actor_id
) values (
  '00000000-0000-0000-0000-000000000400',
  '00000000-0000-0000-0000-000000000300',
  date '2026-07-15',
  date '2026-07-15',
  'RELEASED_TO_PROCUREMENT',
  '00000000-0000-0000-0000-000000000001'
);

insert into atlas_planning.purchase_handoff_revisions (
  purchase_handoff_revision_id,
  purchase_handoff_batch_id,
  revision_number,
  revision_status,
  released_by_actor_id,
  released_at
) values (
  '00000000-0000-0000-0000-000000000401',
  '00000000-0000-0000-0000-000000000400',
  1,
  'RELEASED_TO_PROCUREMENT',
  '00000000-0000-0000-0000-000000000001',
  timestamptz '2026-07-15 00:25:00+00'
);

insert into atlas_planning.purchase_handoff_lines (
  purchase_handoff_line_id,
  purchase_handoff_batch_id,
  confirmed_need_line_id
) values (
  '00000000-0000-0000-0000-000000000402',
  '00000000-0000-0000-0000-000000000400',
  '00000000-0000-0000-0000-000000000301'
);

insert into atlas_planning.purchase_handoff_line_revisions (
  purchase_handoff_line_revision_id,
  purchase_handoff_revision_id,
  purchase_handoff_line_id,
  confirmed_need_line_revision_id,
  ingredient_id,
  handoff_quantity,
  unit_id,
  service_date,
  delivery_location_id
) values (
  '00000000-0000-0000-0000-000000000403',
  '00000000-0000-0000-0000-000000000401',
  '00000000-0000-0000-0000-000000000402',
  '00000000-0000-0000-0000-000000000302',
  '00000000-0000-0000-0000-000000000103',
  10,
  '00000000-0000-0000-0000-000000000102',
  date '2026-07-15',
  '00000000-0000-0000-0000-000000000101'
);

insert into atlas_planning.dispatch_requirements (
  dispatch_requirement_id,
  customer_id,
  delivery_location_id,
  service_date,
  requirement_status
) values (
  '00000000-0000-0000-0000-000000000500',
  '00000000-0000-0000-0000-000000000100',
  '00000000-0000-0000-0000-000000000101',
  date '2026-07-15',
  'RELEASED'
);

insert into atlas_planning.dispatch_requirement_revisions (
  dispatch_requirement_revision_id,
  dispatch_requirement_id,
  purchase_handoff_revision_id,
  revision_number,
  revision_status,
  customer_name_snapshot,
  location_name_snapshot,
  address_snapshot,
  released_by_actor_id,
  released_at
) values (
  '00000000-0000-0000-0000-000000000501',
  '00000000-0000-0000-0000-000000000500',
  '00000000-0000-0000-0000-000000000401',
  1,
  'RELEASED',
  'PA-04 synthetic wholesale customer',
  'PA-04 synthetic delivery location',
  'Synthetic test address',
  '00000000-0000-0000-0000-000000000001',
  timestamptz '2026-07-15 00:30:00+00'
);

insert into atlas_planning.dispatch_requirement_lines (
  dispatch_requirement_line_id,
  dispatch_requirement_id,
  purchase_handoff_line_id
) values (
  '00000000-0000-0000-0000-000000000502',
  '00000000-0000-0000-0000-000000000500',
  '00000000-0000-0000-0000-000000000402'
);

insert into atlas_planning.dispatch_requirement_line_revisions (
  dispatch_requirement_line_revision_id,
  dispatch_requirement_revision_id,
  dispatch_requirement_line_id,
  purchase_handoff_line_revision_id,
  ingredient_id,
  required_quantity,
  unit_id
) values (
  '00000000-0000-0000-0000-000000000503',
  '00000000-0000-0000-0000-000000000501',
  '00000000-0000-0000-0000-000000000502',
  '00000000-0000-0000-0000-000000000403',
  '00000000-0000-0000-0000-000000000103',
  10,
  '00000000-0000-0000-0000-000000000102'
);

insert into atlas_procurement.fulfilment_allocations (
  fulfilment_allocation_id,
  dispatch_requirement_id,
  allocation_status
) values (
  '00000000-0000-0000-0000-000000000600',
  '00000000-0000-0000-0000-000000000500',
  'READY_FOR_DISPATCH'
);

insert into atlas_procurement.fulfilment_allocation_revisions (
  fulfilment_allocation_revision_id,
  fulfilment_allocation_id,
  revision_number,
  revision_status,
  allocated_by_actor_id
) values (
  '00000000-0000-0000-0000-000000000601',
  '00000000-0000-0000-0000-000000000600',
  1,
  'READY_FOR_DISPATCH',
  '00000000-0000-0000-0000-000000000001'
);

insert into atlas_procurement.fulfilment_allocation_lines (
  fulfilment_allocation_line_id,
  fulfilment_allocation_id,
  dispatch_requirement_line_id
) values (
  '00000000-0000-0000-0000-000000000602',
  '00000000-0000-0000-0000-000000000600',
  '00000000-0000-0000-0000-000000000502'
);

insert into atlas_procurement.fulfilment_allocation_line_revisions (
  fulfilment_allocation_line_revision_id,
  fulfilment_allocation_revision_id,
  fulfilment_allocation_line_id,
  dispatch_requirement_line_revision_id,
  supplier_id,
  allocated_quantity,
  unit_id,
  line_status
) values (
  '00000000-0000-0000-0000-000000000603',
  '00000000-0000-0000-0000-000000000601',
  '00000000-0000-0000-0000-000000000602',
  '00000000-0000-0000-0000-000000000503',
  '00000000-0000-0000-0000-000000000104',
  10,
  '00000000-0000-0000-0000-000000000102',
  'EVIDENCED'
);

insert into atlas_procurement.purchase_orders (
  purchase_order_id,
  supplier_id,
  document_number,
  purchase_order_status
) values (
  '00000000-0000-0000-0000-000000000700',
  '00000000-0000-0000-0000-000000000104',
  'PA04-PO-001',
  'RELEASED_TO_SUPPLIER'
);

insert into atlas_procurement.purchase_order_revisions (
  purchase_order_revision_id,
  purchase_order_id,
  revision_number,
  revision_status,
  service_date,
  delivery_location_id,
  supplier_name_snapshot,
  delivery_location_snapshot,
  released_by_actor_id,
  released_at
) values (
  '00000000-0000-0000-0000-000000000701',
  '00000000-0000-0000-0000-000000000700',
  1,
  'RELEASED_TO_SUPPLIER',
  date '2026-07-15',
  '00000000-0000-0000-0000-000000000101',
  'PA-04 synthetic supplier',
  'PA-04 synthetic delivery location',
  '00000000-0000-0000-0000-000000000001',
  timestamptz '2026-07-15 00:40:00+00'
);

insert into atlas_procurement.purchase_order_lines (
  purchase_order_line_id,
  purchase_order_id,
  fulfilment_allocation_line_id
) values (
  '00000000-0000-0000-0000-000000000702',
  '00000000-0000-0000-0000-000000000700',
  '00000000-0000-0000-0000-000000000602'
);

insert into atlas_procurement.purchase_order_line_revisions (
  purchase_order_line_revision_id,
  purchase_order_revision_id,
  purchase_order_line_id,
  fulfilment_allocation_line_revision_id,
  ingredient_id,
  ordered_quantity,
  unit_id,
  delivery_location_id,
  service_date
) values (
  '00000000-0000-0000-0000-000000000703',
  '00000000-0000-0000-0000-000000000701',
  '00000000-0000-0000-0000-000000000702',
  '00000000-0000-0000-0000-000000000603',
  '00000000-0000-0000-0000-000000000103',
  10,
  '00000000-0000-0000-0000-000000000102',
  '00000000-0000-0000-0000-000000000101',
  date '2026-07-15'
);

insert into atlas_evidence.supplier_receiving_evidence (
  supplier_receiving_evidence_id,
  supplier_id,
  purchase_order_line_revision_id,
  ingredient_id,
  evidence_reference,
  evidence_quantity,
  unit_id,
  occurred_at,
  recorded_at,
  recorded_by_actor_id,
  command_id,
  correlation_id
) values (
  '00000000-0000-0000-0000-000000000800',
  '00000000-0000-0000-0000-000000000104',
  '00000000-0000-0000-0000-000000000703',
  '00000000-0000-0000-0000-000000000103',
  'PA04-EVIDENCE-001',
  10,
  '00000000-0000-0000-0000-000000000102',
  timestamptz '2026-07-15 00:50:00+00',
  timestamptz '2026-07-15 00:51:00+00',
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000009800',
  '00000000-0000-0000-0000-000000009999'
);

insert into atlas_evidence.evidence_applications (
  evidence_application_id,
  supplier_receiving_evidence_id,
  fulfilment_allocation_line_revision_id,
  applied_quantity,
  unit_id,
  occurred_at,
  recorded_at,
  recorded_by_actor_id,
  command_id,
  correlation_id
) values (
  '00000000-0000-0000-0000-000000000801',
  '00000000-0000-0000-0000-000000000800',
  '00000000-0000-0000-0000-000000000603',
  10,
  '00000000-0000-0000-0000-000000000102',
  timestamptz '2026-07-15 00:50:00+00',
  timestamptz '2026-07-15 00:52:00+00',
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000009801',
  '00000000-0000-0000-0000-000000009999'
);

insert into atlas_dispatch.dispatch_plans (
  dispatch_plan_id,
  plan_reference,
  service_date,
  created_by_actor_id
) values (
  '00000000-0000-0000-0000-000000000900',
  'PA04-PLAN-001',
  date '2026-07-15',
  '00000000-0000-0000-0000-000000000001'
);

insert into atlas_dispatch.dispatch_plan_requirements (
  dispatch_plan_requirement_id,
  dispatch_plan_id,
  dispatch_requirement_revision_id,
  fulfilment_allocation_revision_id
) values (
  '00000000-0000-0000-0000-000000000901',
  '00000000-0000-0000-0000-000000000900',
  '00000000-0000-0000-0000-000000000501',
  '00000000-0000-0000-0000-000000000601'
);

insert into atlas_dispatch.dispatch_trips (
  dispatch_trip_id,
  dispatch_plan_id,
  trip_reference,
  trip_status,
  driver_actor_id,
  vehicle_reference,
  planned_departure_at,
  departed_at
) values (
  '00000000-0000-0000-0000-000000000902',
  '00000000-0000-0000-0000-000000000900',
  'PA04-TRIP-001',
  'IN_TRANSIT',
  '00000000-0000-0000-0000-000000000001',
  'PA04-VEHICLE-REF',
  timestamptz '2026-07-15 01:00:00+00',
  timestamptz '2026-07-15 01:00:00+00'
);

insert into atlas_dispatch.dispatch_stops (
  dispatch_stop_id,
  dispatch_trip_id,
  stop_sequence,
  dispatch_requirement_revision_id,
  customer_id,
  delivery_location_id,
  stop_status
) values (
  '00000000-0000-0000-0000-000000000903',
  '00000000-0000-0000-0000-000000000902',
  1,
  '00000000-0000-0000-0000-000000000501',
  '00000000-0000-0000-0000-000000000100',
  '00000000-0000-0000-0000-000000000101',
  'IN_TRANSIT'
);

insert into atlas_dispatch.dispatch_loads (
  dispatch_load_id,
  dispatch_trip_id,
  dispatch_requirement_revision_id,
  fulfilment_allocation_revision_id,
  load_status,
  loaded_by_actor_id,
  loaded_at
) values (
  '00000000-0000-0000-0000-000000000904',
  '00000000-0000-0000-0000-000000000902',
  '00000000-0000-0000-0000-000000000501',
  '00000000-0000-0000-0000-000000000601',
  'CONFIRMED',
  '00000000-0000-0000-0000-000000000001',
  timestamptz '2026-07-15 00:58:00+00'
);

insert into atlas_dispatch.dispatch_load_lines (
  dispatch_load_line_id,
  dispatch_load_id,
  dispatch_stop_id,
  dispatch_requirement_line_revision_id,
  fulfilment_allocation_line_revision_id,
  ingredient_id,
  loaded_quantity,
  unit_id,
  command_id
) values (
  '00000000-0000-0000-0000-000000000905',
  '00000000-0000-0000-0000-000000000904',
  '00000000-0000-0000-0000-000000000903',
  '00000000-0000-0000-0000-000000000503',
  '00000000-0000-0000-0000-000000000603',
  '00000000-0000-0000-0000-000000000103',
  10,
  '00000000-0000-0000-0000-000000000102',
  '00000000-0000-0000-0000-000000009905'
);

insert into atlas_dispatch.dispatch_load_line_applications (
  dispatch_load_line_application_id,
  dispatch_load_line_id,
  evidence_application_id,
  applied_to_load_quantity,
  unit_id
) values (
  '00000000-0000-0000-0000-000000000906',
  '00000000-0000-0000-0000-000000000905',
  '00000000-0000-0000-0000-000000000801',
  10,
  '00000000-0000-0000-0000-000000000102'
);

insert into atlas_dispatch.delivery_confirmations (
  delivery_confirmation_id,
  dispatch_stop_id,
  revision_number,
  delivery_outcome,
  confirmed_by_actor_id,
  confirmed_at,
  command_id,
  correlation_id,
  recorded_at
) values (
  '00000000-0000-0000-0000-000000001000',
  '00000000-0000-0000-0000-000000000903',
  1,
  'DELIVERED',
  '00000000-0000-0000-0000-000000000001',
  timestamptz '2026-07-15 02:00:00+00',
  '00000000-0000-0000-0000-000000009000',
  '00000000-0000-0000-0000-000000009999',
  timestamptz '2026-07-15 02:01:00+00'
);

insert into atlas_dispatch.delivery_confirmation_lines (
  delivery_confirmation_line_id,
  delivery_confirmation_id,
  dispatch_load_line_id,
  delivered_quantity,
  unit_id
) values (
  '00000000-0000-0000-0000-000000001001',
  '00000000-0000-0000-0000-000000001000',
  '00000000-0000-0000-0000-000000000905',
  10,
  '00000000-0000-0000-0000-000000000102'
);

select ok(
  (
    select evidence_sufficient
      and valid_applied_quantity = 10
      and valid_loaded_quantity = 10
      and uncovered_quantity = 0
    from atlas_reporting.dispatch_evidence_readiness
    where fulfilment_allocation_line_revision_id = '00000000-0000-0000-0000-000000000603'
  ),
  'synthetic supplier evidence fully covers the exact allocation and load'
);

select is(
  (
    select count(*)::integer
    from atlas_reporting.supplier_direct_slice_trace
    where wholesale_order_line_revision_id = '00000000-0000-0000-0000-000000000202'
      and delivered_quantity = 10
  ),
  1,
  'synthetic wholesale source traces once through supplier evidence to delivery'
);

select * from finish();

rollback;
