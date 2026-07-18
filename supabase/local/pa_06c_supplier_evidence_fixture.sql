do $pa_06c_fixture$
begin

-- Reuse the PA-06B synthetic Auth subject, Atlas actor, and customer. Add only
-- the bounded Evidence role, four new capabilities, the existing PA-06B
-- operator-blocker capability, and fixture lineage required by the pilot.
insert into atlas_core.roles (
  role_id,
  role_code,
  role_name
) values (
  'b6c00000-0000-0000-0000-000000000001',
  'pa06c_local_evidence_operator',
  'PA-06C local Evidence operator'
)
on conflict (role_id) do update set
  role_code = excluded.role_code,
  role_name = excluded.role_name,
  role_status = 'ACTIVE',
  updated_at = transaction_timestamp();

insert into atlas_core.capabilities (
  capability_id,
  capability_code,
  capability_name,
  owning_domain
) values
  ('b6c00000-0000-0000-0000-000000000010', 'dispatch_evidence_readiness.read', 'Read bounded Evidence readiness', 'DISPATCH'),
  ('b6c00000-0000-0000-0000-000000000012', 'command_audit_timeline.read', 'Read bounded command audit timeline', 'AUDIT'),
  ('b6c00000-0000-0000-0000-000000000013', 'supplier_receiving_evidence.record', 'Record supplier receiving Evidence', 'EVIDENCE'),
  ('b6c00000-0000-0000-0000-000000000014', 'supplier_evidence_application.apply', 'Apply supplier Evidence to allocation', 'EVIDENCE')
on conflict (capability_id) do update set
  capability_code = excluded.capability_code,
  capability_name = excluded.capability_name,
  owning_domain = excluded.owning_domain,
  capability_status = 'ACTIVE';

insert into atlas_core.role_capabilities (
  role_capability_id,
  role_id,
  capability_id,
  granted_by_actor_id
) values
  ('b6c00000-0000-0000-0000-000000000020', 'b6c00000-0000-0000-0000-000000000001', 'b6c00000-0000-0000-0000-000000000010', 'b6000000-0000-0000-0000-000000000001'),
  ('b6c00000-0000-0000-0000-000000000021', 'b6c00000-0000-0000-0000-000000000001', 'b6000000-0000-0000-0000-000000000004', 'b6000000-0000-0000-0000-000000000001'),
  ('b6c00000-0000-0000-0000-000000000022', 'b6c00000-0000-0000-0000-000000000001', 'b6c00000-0000-0000-0000-000000000012', 'b6000000-0000-0000-0000-000000000001'),
  ('b6c00000-0000-0000-0000-000000000023', 'b6c00000-0000-0000-0000-000000000001', 'b6c00000-0000-0000-0000-000000000013', 'b6000000-0000-0000-0000-000000000001'),
  ('b6c00000-0000-0000-0000-000000000024', 'b6c00000-0000-0000-0000-000000000001', 'b6c00000-0000-0000-0000-000000000014', 'b6000000-0000-0000-0000-000000000001')
on conflict (role_capability_id) do update set
  role_id = excluded.role_id,
  capability_id = excluded.capability_id,
  granted_by_actor_id = excluded.granted_by_actor_id;

insert into atlas_core.actor_role_memberships (
  actor_role_membership_id,
  actor_id,
  role_id,
  granted_by_actor_id,
  reason_note
) values (
  'b6c00000-0000-0000-0000-000000000030',
  'b6000000-0000-0000-0000-000000000001',
  'b6c00000-0000-0000-0000-000000000001',
  'b6000000-0000-0000-0000-000000000001',
  'Deterministic PA-06C local Evidence pilot only.'
)
on conflict (actor_role_membership_id) do update set
  membership_status = 'ACTIVE',
  effective_to = null,
  reason_note = excluded.reason_note;

insert into atlas_admin.delivery_locations (
  delivery_location_id,
  customer_id,
  location_code,
  location_name,
  address_text
) values (
  'b6c10000-0000-0000-0000-000000000101',
  'b6000000-0000-0000-0000-000000000201',
  'PA06C-LOCATION',
  'PA-06C Synthetic Delivery Location',
  'Local fixture address only'
)
on conflict (delivery_location_id) do nothing;

insert into atlas_core.actor_scopes (
  actor_scope_id,
  actor_id,
  scope_kind,
  delivery_location_id,
  granted_by_actor_id,
  reason_note
) values (
  'b6c00000-0000-0000-0000-000000000031',
  'b6000000-0000-0000-0000-000000000001',
  'DELIVERY_LOCATION',
  'b6c10000-0000-0000-0000-000000000101',
  'b6000000-0000-0000-0000-000000000001',
  'Least-privilege synthetic location scope for PA-06C.'
)
on conflict (actor_scope_id) do update set
  scope_status = 'ACTIVE',
  effective_to = null,
  reason_note = excluded.reason_note;

insert into atlas_admin.units (
  unit_id,
  unit_code,
  unit_name,
  dimension_code
) values (
  'b6c10000-0000-0000-0000-000000000102',
  'pa06c-kg',
  'PA-06C kilogram',
  'mass'
)
on conflict (unit_id) do nothing;

insert into atlas_admin.ingredients (
  ingredient_id,
  ingredient_code,
  ingredient_name
) values (
  'b6c10000-0000-0000-0000-000000000103',
  'PA06C-RICE',
  'PA-06C Synthetic Rice'
)
on conflict (ingredient_id) do nothing;

insert into atlas_admin.suppliers (
  supplier_id,
  supplier_code,
  supplier_name
) values (
  'b6c10000-0000-0000-0000-000000000104',
  'PA06C-SUPPLIER',
  'PA-06C Synthetic Supplier'
)
on conflict (supplier_id) do nothing;

insert into atlas_admin.supplier_eligibilities (
  supplier_eligibility_id,
  supplier_id,
  ingredient_id,
  effective_from,
  reason_note
) values (
  'b6c10000-0000-0000-0000-000000000105',
  'b6c10000-0000-0000-0000-000000000104',
  'b6c10000-0000-0000-0000-000000000103',
  date '2026-07-18',
  'Deterministic PA-06C local fixture eligibility.'
)
on conflict (supplier_eligibility_id) do nothing;

insert into atlas_planning.wholesale_orders (
  wholesale_order_id,
  customer_id,
  delivery_location_id,
  customer_order_reference,
  service_date,
  order_status,
  created_by_actor_id,
  released_by_actor_id,
  released_at
) values (
  'b6c20000-0000-0000-0000-000000000200',
  'b6000000-0000-0000-0000-000000000201',
  'b6c10000-0000-0000-0000-000000000101',
  'PA06C-ORDER-001',
  date '2026-07-18',
  'RELEASED',
  'b6000000-0000-0000-0000-000000000001',
  'b6000000-0000-0000-0000-000000000001',
  timestamptz '2026-07-18 00:05:00+00'
)
on conflict (wholesale_order_id) do nothing;

insert into atlas_planning.wholesale_order_lines (
  wholesale_order_line_id,
  wholesale_order_id,
  source_line_number
) values (
  'b6c20000-0000-0000-0000-000000000201',
  'b6c20000-0000-0000-0000-000000000200',
  1
)
on conflict (wholesale_order_line_id) do nothing;

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
  'b6c20000-0000-0000-0000-000000000202',
  'b6c20000-0000-0000-0000-000000000201',
  1,
  'b6c10000-0000-0000-0000-000000000103',
  10,
  'b6c10000-0000-0000-0000-000000000102',
  'RELEASED',
  'b6000000-0000-0000-0000-000000000001'
)
on conflict (wholesale_order_line_revision_id) do nothing;

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
  'b6c20000-0000-0000-0000-000000000300',
  'b6c20000-0000-0000-0000-000000000200',
  date '2026-07-18',
  date '2026-07-18',
  'RELEASED_FOR_PURCHASE_HANDOFF',
  'b6000000-0000-0000-0000-000000000001',
  'b6000000-0000-0000-0000-000000000001',
  timestamptz '2026-07-18 00:10:00+00',
  'b6000000-0000-0000-0000-000000000001',
  timestamptz '2026-07-18 00:12:00+00'
)
on conflict (confirmed_need_batch_id) do nothing;

insert into atlas_planning.confirmed_need_lines (
  confirmed_need_line_id,
  confirmed_need_batch_id,
  wholesale_order_line_id
) values (
  'b6c20000-0000-0000-0000-000000000301',
  'b6c20000-0000-0000-0000-000000000300',
  'b6c20000-0000-0000-0000-000000000201'
)
on conflict (confirmed_need_line_id) do nothing;

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
  'b6c20000-0000-0000-0000-000000000302',
  'b6c20000-0000-0000-0000-000000000301',
  1,
  'b6c20000-0000-0000-0000-000000000202',
  'b6c10000-0000-0000-0000-000000000103',
  10,
  10,
  'b6c10000-0000-0000-0000-000000000102',
  'RELEASED',
  'b6000000-0000-0000-0000-000000000001'
)
on conflict (confirmed_need_line_revision_id) do nothing;

insert into atlas_planning.confirmed_need_approval_snapshots (
  confirmed_need_approval_snapshot_id,
  confirmed_need_batch_id,
  approved_version,
  approved_by_actor_id,
  approved_at,
  command_id
) values (
  'b6c20000-0000-0000-0000-000000000310',
  'b6c20000-0000-0000-0000-000000000300',
  1,
  'b6000000-0000-0000-0000-000000000001',
  timestamptz '2026-07-18 00:10:00+00',
  'b6c90000-0000-0000-0000-000000000001'
)
on conflict (confirmed_need_approval_snapshot_id) do nothing;

insert into atlas_planning.confirmed_need_snapshot_lines (
  confirmed_need_snapshot_line_id,
  confirmed_need_approval_snapshot_id,
  confirmed_need_line_revision_id,
  ingredient_id,
  approved_quantity,
  unit_id,
  ingredient_name_snapshot
) values (
  'b6c20000-0000-0000-0000-000000000311',
  'b6c20000-0000-0000-0000-000000000310',
  'b6c20000-0000-0000-0000-000000000302',
  'b6c10000-0000-0000-0000-000000000103',
  10,
  'b6c10000-0000-0000-0000-000000000102',
  'PA-06C Synthetic Rice'
)
on conflict (confirmed_need_snapshot_line_id) do nothing;

insert into atlas_planning.purchase_handoff_batches (
  purchase_handoff_batch_id,
  confirmed_need_batch_id,
  period_start,
  period_end,
  handoff_status,
  created_by_actor_id
) values (
  'b6c20000-0000-0000-0000-000000000400',
  'b6c20000-0000-0000-0000-000000000300',
  date '2026-07-18',
  date '2026-07-18',
  'RELEASED_TO_PROCUREMENT',
  'b6000000-0000-0000-0000-000000000001'
)
on conflict (purchase_handoff_batch_id) do nothing;

insert into atlas_planning.purchase_handoff_revisions (
  purchase_handoff_revision_id,
  purchase_handoff_batch_id,
  revision_number,
  revision_status,
  released_by_actor_id,
  released_at
) values (
  'b6c20000-0000-0000-0000-000000000401',
  'b6c20000-0000-0000-0000-000000000400',
  1,
  'RELEASED_TO_PROCUREMENT',
  'b6000000-0000-0000-0000-000000000001',
  timestamptz '2026-07-18 00:15:00+00'
)
on conflict (purchase_handoff_revision_id) do nothing;

insert into atlas_planning.purchase_handoff_lines (
  purchase_handoff_line_id,
  purchase_handoff_batch_id,
  confirmed_need_line_id
) values (
  'b6c20000-0000-0000-0000-000000000402',
  'b6c20000-0000-0000-0000-000000000400',
  'b6c20000-0000-0000-0000-000000000301'
)
on conflict (purchase_handoff_line_id) do nothing;

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
  'b6c20000-0000-0000-0000-000000000403',
  'b6c20000-0000-0000-0000-000000000401',
  'b6c20000-0000-0000-0000-000000000402',
  'b6c20000-0000-0000-0000-000000000302',
  'b6c10000-0000-0000-0000-000000000103',
  10,
  'b6c10000-0000-0000-0000-000000000102',
  date '2026-07-18',
  'b6c10000-0000-0000-0000-000000000101'
)
on conflict (purchase_handoff_line_revision_id) do nothing;

insert into atlas_planning.purchase_demand_references (
  purchase_demand_reference_id,
  purchase_handoff_line_revision_id,
  confirmed_need_snapshot_line_id,
  wholesale_order_line_revision_id,
  approved_quantity,
  unit_id
) values (
  'b6c20000-0000-0000-0000-000000000410',
  'b6c20000-0000-0000-0000-000000000403',
  'b6c20000-0000-0000-0000-000000000311',
  'b6c20000-0000-0000-0000-000000000202',
  10,
  'b6c10000-0000-0000-0000-000000000102'
)
on conflict (purchase_demand_reference_id) do nothing;

insert into atlas_planning.dispatch_requirements (
  dispatch_requirement_id,
  customer_id,
  delivery_location_id,
  service_date,
  requirement_status
) values (
  'b6c20000-0000-0000-0000-000000000500',
  'b6000000-0000-0000-0000-000000000201',
  'b6c10000-0000-0000-0000-000000000101',
  date '2026-07-18',
  'RELEASED'
)
on conflict (dispatch_requirement_id) do nothing;

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
  'b6c20000-0000-0000-0000-000000000501',
  'b6c20000-0000-0000-0000-000000000500',
  'b6c20000-0000-0000-0000-000000000401',
  1,
  'RELEASED',
  'PA-06B Synthetic Local Customer',
  'PA-06C Synthetic Delivery Location',
  'Local fixture address only',
  'b6000000-0000-0000-0000-000000000001',
  timestamptz '2026-07-18 00:20:00+00'
)
on conflict (dispatch_requirement_revision_id) do nothing;

insert into atlas_planning.dispatch_requirement_lines (
  dispatch_requirement_line_id,
  dispatch_requirement_id,
  purchase_handoff_line_id
) values (
  'b6c20000-0000-0000-0000-000000000502',
  'b6c20000-0000-0000-0000-000000000500',
  'b6c20000-0000-0000-0000-000000000402'
)
on conflict (dispatch_requirement_line_id) do nothing;

insert into atlas_planning.dispatch_requirement_line_revisions (
  dispatch_requirement_line_revision_id,
  dispatch_requirement_revision_id,
  dispatch_requirement_line_id,
  purchase_handoff_line_revision_id,
  ingredient_id,
  required_quantity,
  unit_id
) values (
  'b6c20000-0000-0000-0000-000000000503',
  'b6c20000-0000-0000-0000-000000000501',
  'b6c20000-0000-0000-0000-000000000502',
  'b6c20000-0000-0000-0000-000000000403',
  'b6c10000-0000-0000-0000-000000000103',
  10,
  'b6c10000-0000-0000-0000-000000000102'
)
on conflict (dispatch_requirement_line_revision_id) do nothing;

insert into atlas_procurement.fulfilment_allocations (
  fulfilment_allocation_id,
  dispatch_requirement_id,
  allocation_status
) values (
  'b6c30000-0000-0000-0000-000000000600',
  'b6c20000-0000-0000-0000-000000000500',
  'READY_FOR_DISPATCH'
)
on conflict (fulfilment_allocation_id) do nothing;

insert into atlas_procurement.fulfilment_allocation_revisions (
  fulfilment_allocation_revision_id,
  fulfilment_allocation_id,
  revision_number,
  revision_status,
  allocated_by_actor_id
) values (
  'b6c30000-0000-0000-0000-000000000601',
  'b6c30000-0000-0000-0000-000000000600',
  1,
  'READY_FOR_DISPATCH',
  'b6000000-0000-0000-0000-000000000001'
)
on conflict (fulfilment_allocation_revision_id) do nothing;

insert into atlas_procurement.fulfilment_allocation_lines (
  fulfilment_allocation_line_id,
  fulfilment_allocation_id,
  dispatch_requirement_line_id,
  portion_sequence
) values (
  'b6c30000-0000-0000-0000-000000000602',
  'b6c30000-0000-0000-0000-000000000600',
  'b6c20000-0000-0000-0000-000000000502',
  1
)
on conflict (fulfilment_allocation_line_id) do nothing;

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
  'b6c30000-0000-0000-0000-000000000603',
  'b6c30000-0000-0000-0000-000000000601',
  'b6c30000-0000-0000-0000-000000000602',
  'b6c20000-0000-0000-0000-000000000503',
  'b6c10000-0000-0000-0000-000000000104',
  10,
  'b6c10000-0000-0000-0000-000000000102',
  'READY_FOR_EVIDENCE'
)
on conflict (fulfilment_allocation_line_revision_id) do nothing;

insert into atlas_procurement.purchase_orders (
  purchase_order_id,
  supplier_id,
  document_number,
  purchase_order_status
) values (
  'b6c30000-0000-0000-0000-000000000700',
  'b6c10000-0000-0000-0000-000000000104',
  'PA06C-PO-001',
  'RELEASED_TO_SUPPLIER'
)
on conflict (purchase_order_id) do nothing;

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
  'b6c30000-0000-0000-0000-000000000701',
  'b6c30000-0000-0000-0000-000000000700',
  1,
  'RELEASED_TO_SUPPLIER',
  date '2026-07-18',
  'b6c10000-0000-0000-0000-000000000101',
  'PA-06C Synthetic Supplier',
  'PA-06C Synthetic Delivery Location',
  'b6000000-0000-0000-0000-000000000001',
  timestamptz '2026-07-18 00:25:00+00'
)
on conflict (purchase_order_revision_id) do nothing;

insert into atlas_procurement.purchase_order_lines (
  purchase_order_line_id,
  purchase_order_id,
  fulfilment_allocation_line_id
) values (
  'b6c30000-0000-0000-0000-000000000702',
  'b6c30000-0000-0000-0000-000000000700',
  'b6c30000-0000-0000-0000-000000000602'
)
on conflict (purchase_order_line_id) do nothing;

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
  'b6c30000-0000-0000-0000-000000000703',
  'b6c30000-0000-0000-0000-000000000701',
  'b6c30000-0000-0000-0000-000000000702',
  'b6c30000-0000-0000-0000-000000000603',
  'b6c10000-0000-0000-0000-000000000103',
  10,
  'b6c10000-0000-0000-0000-000000000102',
  'b6c10000-0000-0000-0000-000000000101',
  date '2026-07-18'
)
on conflict (purchase_order_line_revision_id) do nothing;

end;
$pa_06c_fixture$;
