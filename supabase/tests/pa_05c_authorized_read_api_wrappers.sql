begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
select no_plan();

grant usage on schema extensions to authenticated;
grant execute on all functions in schema extensions to authenticated;

select ok(
  not has_function_privilege('anon', 'atlas_api.get_dispatch_evidence_readiness(jsonb)', 'EXECUTE')
  and not has_function_privilege('anon', 'atlas_api.get_operator_blockers(jsonb)', 'EXECUTE')
  and not has_function_privilege('anon', 'atlas_api.get_command_audit_timeline(jsonb)', 'EXECUTE'),
  'anon has no execute on PA-05C read functions'
);
select ok(
  not has_function_privilege('service_role', 'atlas_api.get_dispatch_evidence_readiness(jsonb)', 'EXECUTE')
  and not has_function_privilege('service_role', 'atlas_api.get_operator_blockers(jsonb)', 'EXECUTE')
  and not has_function_privilege('service_role', 'atlas_api.get_command_audit_timeline(jsonb)', 'EXECUTE'),
  'service_role has no execute on PA-05C read functions'
);
select ok(
  has_function_privilege('authenticated', 'atlas_api.get_dispatch_evidence_readiness(jsonb)', 'EXECUTE')
  and has_function_privilege('authenticated', 'atlas_api.get_operator_blockers(jsonb)', 'EXECUTE')
  and has_function_privilege('authenticated', 'atlas_api.get_command_audit_timeline(jsonb)', 'EXECUTE'),
  'authenticated can execute all reviewed PA-05C read functions'
);
select ok(
  not exists (
    select 1
    from unnest(array['anon','authenticated','service_role']) r(role_name)
    cross join pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname like 'atlas\_%' escape '\'
      and c.relkind in ('r','v','m','S')
      and (has_table_privilege(r.role_name, c.oid, 'SELECT')
        or has_table_privilege(r.role_name, c.oid, 'INSERT')
        or has_table_privilege(r.role_name, c.oid, 'UPDATE')
        or has_table_privilege(r.role_name, c.oid, 'DELETE'))
  ),
  'API roles retain no direct private table, view, or sequence access'
);
select ok(
  has_function_privilege('authenticated', 'atlas_api.get_supplier_direct_trace(jsonb)', 'EXECUTE')
  and has_function_privilege('authenticated', 'atlas_api.record_supplier_receiving_evidence(jsonb)', 'EXECUTE'),
  'PA-05B callable behavior remains available'
);
select is(
  (select count(*)::integer from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='atlas_api' and p.proname in (
     'record_supplier_receiving_evidence','apply_supplier_evidence_to_allocation',
     'confirm_dispatch_load','record_dispatch_departure','confirm_successful_delivery')),
  5,
  'PA-05C adds no write function'
);
select ok(
  not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='atlas_api'
      and p.proname in ('get_dispatch_evidence_readiness','get_operator_blockers','get_command_audit_timeline')
      and not p.prosecdef
  ),
  'PA-05C functions are security definer'
);
select ok(
  not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    join pg_roles r on r.oid=p.proowner
    where n.nspname='atlas_api'
      and p.proname in ('get_dispatch_evidence_readiness','get_operator_blockers','get_command_audit_timeline')
      and r.rolname <> 'atlas_read_runtime'
  ),
  'PA-05C functions are owned by atlas_read_runtime'
);
select ok(
  not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='atlas_api'
      and p.proname in ('get_dispatch_evidence_readiness','get_operator_blockers','get_command_audit_timeline')
      and (p.proconfig is null or p.proconfig::text not like '%search_path=%')
  ),
  'PA-05C functions have an empty fixed search_path'
);
select ok(
  not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='atlas_api'
      and p.proname in ('get_dispatch_evidence_readiness','get_operator_blockers','get_command_audit_timeline')
      and (pg_get_functiondef(p.oid) ~* '\mexecute\M' or pg_get_functiondef(p.oid) ~* '\mformat\s*\(')
  ),
  'PA-05C source contains no dynamic SQL'
);
select ok(
  not exists (
    select 1 from information_schema.role_table_grants g
    where g.grantee='atlas_read_runtime' and g.privilege_type <> 'SELECT'
      and g.table_schema like 'atlas\_%' escape '\'
  ),
  'atlas_read_runtime retains select-only table privileges'
);

-- Rolled-back authorization and supplier-direct fixtures.
insert into atlas_core.actors (actor_id, actor_type, display_name, actor_status, deactivated_at) values
  ('15000000-0000-0000-0000-000000000001','HUMAN','PA-05C operator','ACTIVE',null),
  ('15000000-0000-0000-0000-000000000002','HUMAN','PA-05C inactive','INACTIVE',timestamptz '2026-07-15 00:00:00+00'),
  ('15000000-0000-0000-0000-000000000003','HUMAN','PA-05C revoked','ACTIVE',null),
  ('15000000-0000-0000-0000-000000000004','HUMAN','PA-05C no capability','ACTIVE',null),
  ('15000000-0000-0000-0000-000000000005','HUMAN','PA-05C wrong scope','ACTIVE',null),
  ('15000000-0000-0000-0000-000000000006','HUMAN','PA-05C location reader','ACTIVE',null);
insert into atlas_core.actor_auth_subjects
  (actor_auth_subject_id,actor_id,auth_subject_id,subject_status,revoked_at) values
  ('15000000-0000-0000-0000-000000000011','15000000-0000-0000-0000-000000000001','15000000-0000-0000-0000-000000000101','ACTIVE',null),
  ('15000000-0000-0000-0000-000000000012','15000000-0000-0000-0000-000000000002','15000000-0000-0000-0000-000000000102','ACTIVE',null),
  ('15000000-0000-0000-0000-000000000013','15000000-0000-0000-0000-000000000003','15000000-0000-0000-0000-000000000103','REVOKED',timestamptz '2026-07-15 00:01:00+00'),
  ('15000000-0000-0000-0000-000000000014','15000000-0000-0000-0000-000000000004','15000000-0000-0000-0000-000000000104','ACTIVE',null),
  ('15000000-0000-0000-0000-000000000015','15000000-0000-0000-0000-000000000005','15000000-0000-0000-0000-000000000105','ACTIVE',null),
  ('15000000-0000-0000-0000-000000000016','15000000-0000-0000-0000-000000000006','15000000-0000-0000-0000-000000000106','ACTIVE',null);
insert into atlas_core.roles (role_id,role_code,role_name) values
  ('15100000-0000-0000-0000-000000000001','pa05c.reader','PA-05C reader'),
  ('15100000-0000-0000-0000-000000000002','pa05c.none','PA-05C no reads');
insert into atlas_core.capabilities (capability_id,capability_code,capability_name,owning_domain) values
  ('15200000-0000-0000-0000-000000000001','dispatch_evidence_readiness.read','Read evidence readiness','DISPATCH'),
  ('15200000-0000-0000-0000-000000000002','operator_blockers.read','Read operator blockers','DISPATCH'),
  ('15200000-0000-0000-0000-000000000003','command_audit_timeline.read','Read command audit timeline','AUDIT');
insert into atlas_core.role_capabilities (role_id,capability_id)
select '15100000-0000-0000-0000-000000000001'::uuid, capability_id
from atlas_core.capabilities where capability_code in (
  'dispatch_evidence_readiness.read','operator_blockers.read','command_audit_timeline.read'
);
insert into atlas_core.actor_role_memberships (actor_id,role_id) values
  ('15000000-0000-0000-0000-000000000001','15100000-0000-0000-0000-000000000001'),
  ('15000000-0000-0000-0000-000000000002','15100000-0000-0000-0000-000000000001'),
  ('15000000-0000-0000-0000-000000000003','15100000-0000-0000-0000-000000000001'),
  ('15000000-0000-0000-0000-000000000004','15100000-0000-0000-0000-000000000002'),
  ('15000000-0000-0000-0000-000000000005','15100000-0000-0000-0000-000000000001'),
  ('15000000-0000-0000-0000-000000000006','15100000-0000-0000-0000-000000000001');

insert into atlas_admin.customers (customer_id,customer_code,customer_name) values
  ('25000000-0000-0000-0000-000000000100','pa05c-customer','PA-05C customer'),
  ('25000000-0000-0000-0000-000000000110','pa05c-other','PA-05C other customer');
insert into atlas_admin.delivery_locations
  (delivery_location_id,customer_id,location_code,location_name,address_text) values
  ('25000000-0000-0000-0000-000000000101','25000000-0000-0000-0000-000000000100','pa05c-location','PA-05C location','Test address'),
  ('25000000-0000-0000-0000-000000000105','25000000-0000-0000-0000-000000000100','pa05c-location-2','PA-05C location 2','Second address'),
  ('25000000-0000-0000-0000-000000000111','25000000-0000-0000-0000-000000000110','pa05c-other','PA-05C other','Other address');
insert into atlas_admin.units (unit_id,unit_code,unit_name,dimension_code) values
  ('25000000-0000-0000-0000-000000000102','pa05c-kg','PA-05C kilogram','mass');
insert into atlas_admin.ingredients (ingredient_id,ingredient_code,ingredient_name) values
  ('25000000-0000-0000-0000-000000000103','pa05c-rice','PA-05C rice');
insert into atlas_admin.suppliers (supplier_id,supplier_code,supplier_name) values
  ('25000000-0000-0000-0000-000000000104','pa05c-supplier','PA-05C supplier');
insert into atlas_core.actor_scopes (actor_id,scope_kind,customer_id) values
  ('15000000-0000-0000-0000-000000000001','CUSTOMER','25000000-0000-0000-0000-000000000100'),
  ('15000000-0000-0000-0000-000000000005','CUSTOMER','25000000-0000-0000-0000-000000000110');
insert into atlas_core.actor_scopes (actor_id,scope_kind,delivery_location_id) values
  ('15000000-0000-0000-0000-000000000006','DELIVERY_LOCATION','25000000-0000-0000-0000-000000000101');
insert into atlas_core.actor_scopes (actor_id,scope_kind) values
  ('15000000-0000-0000-0000-000000000002','GLOBAL'),
  ('15000000-0000-0000-0000-000000000003','GLOBAL'),
  ('15000000-0000-0000-0000-000000000004','GLOBAL');

insert into atlas_planning.wholesale_orders
  (wholesale_order_id,customer_id,delivery_location_id,customer_order_reference,service_date,order_status,created_by_actor_id) values
  ('35000000-0000-0000-0000-000000000200','25000000-0000-0000-0000-000000000100','25000000-0000-0000-0000-000000000101','PA05C-ORDER-001',date '2026-07-15','RELEASED','15000000-0000-0000-0000-000000000001');
insert into atlas_planning.wholesale_order_lines (wholesale_order_line_id,wholesale_order_id,source_line_number) values
  ('35000000-0000-0000-0000-000000000201','35000000-0000-0000-0000-000000000200',1);
insert into atlas_planning.wholesale_order_line_revisions
  (wholesale_order_line_revision_id,wholesale_order_line_id,revision_number,ingredient_id,requested_quantity,unit_id,revision_status,created_by_actor_id) values
  ('35000000-0000-0000-0000-000000000202','35000000-0000-0000-0000-000000000201',1,'25000000-0000-0000-0000-000000000103',10,'25000000-0000-0000-0000-000000000102','RELEASED','15000000-0000-0000-0000-000000000001');
insert into atlas_planning.confirmed_need_batches
  (confirmed_need_batch_id,wholesale_order_id,period_start,period_end,batch_status,created_by_actor_id) values
  ('35000000-0000-0000-0000-000000000300','35000000-0000-0000-0000-000000000200',date '2026-07-15',date '2026-07-15','RELEASED_FOR_PURCHASE_HANDOFF','15000000-0000-0000-0000-000000000001');
insert into atlas_planning.confirmed_need_lines
  (confirmed_need_line_id,confirmed_need_batch_id,wholesale_order_line_id) values
  ('35000000-0000-0000-0000-000000000301','35000000-0000-0000-0000-000000000300','35000000-0000-0000-0000-000000000201');
insert into atlas_planning.confirmed_need_line_revisions
  (confirmed_need_line_revision_id,confirmed_need_line_id,revision_number,wholesale_order_line_revision_id,ingredient_id,theoretical_quantity,confirmed_quantity,unit_id,revision_status,created_by_actor_id) values
  ('35000000-0000-0000-0000-000000000302','35000000-0000-0000-0000-000000000301',1,'35000000-0000-0000-0000-000000000202','25000000-0000-0000-0000-000000000103',10,10,'25000000-0000-0000-0000-000000000102','RELEASED','15000000-0000-0000-0000-000000000001');
insert into atlas_planning.purchase_handoff_batches
  (purchase_handoff_batch_id,confirmed_need_batch_id,period_start,period_end,handoff_status,created_by_actor_id) values
  ('35000000-0000-0000-0000-000000000400','35000000-0000-0000-0000-000000000300',date '2026-07-15',date '2026-07-15','RELEASED_TO_PROCUREMENT','15000000-0000-0000-0000-000000000001');
insert into atlas_planning.purchase_handoff_revisions
  (purchase_handoff_revision_id,purchase_handoff_batch_id,revision_number,revision_status,released_by_actor_id,released_at) values
  ('35000000-0000-0000-0000-000000000401','35000000-0000-0000-0000-000000000400',1,'RELEASED_TO_PROCUREMENT','15000000-0000-0000-0000-000000000001',timestamptz '2026-07-15 00:10:00+00');
insert into atlas_planning.purchase_handoff_lines
  (purchase_handoff_line_id,purchase_handoff_batch_id,confirmed_need_line_id) values
  ('35000000-0000-0000-0000-000000000402','35000000-0000-0000-0000-000000000400','35000000-0000-0000-0000-000000000301');
insert into atlas_planning.purchase_handoff_line_revisions
  (purchase_handoff_line_revision_id,purchase_handoff_revision_id,purchase_handoff_line_id,confirmed_need_line_revision_id,ingredient_id,handoff_quantity,unit_id,service_date,delivery_location_id) values
  ('35000000-0000-0000-0000-000000000403','35000000-0000-0000-0000-000000000401','35000000-0000-0000-0000-000000000402','35000000-0000-0000-0000-000000000302','25000000-0000-0000-0000-000000000103',10,'25000000-0000-0000-0000-000000000102',date '2026-07-15','25000000-0000-0000-0000-000000000101');
insert into atlas_planning.dispatch_requirements
  (dispatch_requirement_id,customer_id,delivery_location_id,service_date,requirement_status) values
  ('35000000-0000-0000-0000-000000000500','25000000-0000-0000-0000-000000000100','25000000-0000-0000-0000-000000000101',date '2026-07-15','RELEASED');
insert into atlas_planning.dispatch_requirement_revisions
  (dispatch_requirement_revision_id,dispatch_requirement_id,purchase_handoff_revision_id,revision_number,revision_status,customer_name_snapshot,location_name_snapshot,address_snapshot,released_by_actor_id,released_at) values
  ('35000000-0000-0000-0000-000000000501','35000000-0000-0000-0000-000000000500','35000000-0000-0000-0000-000000000401',1,'RELEASED','PA-05C customer','PA-05C location','Test address','15000000-0000-0000-0000-000000000001',timestamptz '2026-07-15 00:20:00+00');
insert into atlas_planning.dispatch_requirement_lines
  (dispatch_requirement_line_id,dispatch_requirement_id,purchase_handoff_line_id) values
  ('35000000-0000-0000-0000-000000000502','35000000-0000-0000-0000-000000000500','35000000-0000-0000-0000-000000000402');
insert into atlas_planning.dispatch_requirement_line_revisions
  (dispatch_requirement_line_revision_id,dispatch_requirement_revision_id,dispatch_requirement_line_id,purchase_handoff_line_revision_id,ingredient_id,required_quantity,unit_id) values
  ('35000000-0000-0000-0000-000000000503','35000000-0000-0000-0000-000000000501','35000000-0000-0000-0000-000000000502','35000000-0000-0000-0000-000000000403','25000000-0000-0000-0000-000000000103',10,'25000000-0000-0000-0000-000000000102');
insert into atlas_procurement.fulfilment_allocations
  (fulfilment_allocation_id,dispatch_requirement_id,allocation_status) values
  ('45000000-0000-0000-0000-000000000600','35000000-0000-0000-0000-000000000500','READY_FOR_DISPATCH');
insert into atlas_procurement.fulfilment_allocation_revisions
  (fulfilment_allocation_revision_id,fulfilment_allocation_id,revision_number,revision_status,allocated_by_actor_id) values
  ('45000000-0000-0000-0000-000000000601','45000000-0000-0000-0000-000000000600',1,'READY_FOR_DISPATCH','15000000-0000-0000-0000-000000000001');
insert into atlas_procurement.fulfilment_allocation_lines
  (fulfilment_allocation_line_id,fulfilment_allocation_id,dispatch_requirement_line_id,portion_sequence) values
  ('45000000-0000-0000-0000-000000000602','45000000-0000-0000-0000-000000000600','35000000-0000-0000-0000-000000000502',1);
insert into atlas_procurement.fulfilment_allocation_line_revisions
  (fulfilment_allocation_line_revision_id,fulfilment_allocation_revision_id,fulfilment_allocation_line_id,dispatch_requirement_line_revision_id,supplier_id,allocated_quantity,unit_id,line_status) values
  ('45000000-0000-0000-0000-000000000603','45000000-0000-0000-0000-000000000601','45000000-0000-0000-0000-000000000602','35000000-0000-0000-0000-000000000503','25000000-0000-0000-0000-000000000104',10,'25000000-0000-0000-0000-000000000102','EVIDENCED');
insert into atlas_procurement.purchase_orders
  (purchase_order_id,supplier_id,document_number,purchase_order_status) values
  ('45000000-0000-0000-0000-000000000700','25000000-0000-0000-0000-000000000104','PA05C-PO-001','RELEASED_TO_SUPPLIER');
insert into atlas_procurement.purchase_order_revisions
  (purchase_order_revision_id,purchase_order_id,revision_number,revision_status,service_date,delivery_location_id,supplier_name_snapshot,delivery_location_snapshot,released_by_actor_id,released_at) values
  ('45000000-0000-0000-0000-000000000701','45000000-0000-0000-0000-000000000700',1,'RELEASED_TO_SUPPLIER',date '2026-07-15','25000000-0000-0000-0000-000000000101','PA-05C supplier','PA-05C location','15000000-0000-0000-0000-000000000001',timestamptz '2026-07-15 00:25:00+00');
insert into atlas_procurement.purchase_order_lines
  (purchase_order_line_id,purchase_order_id,fulfilment_allocation_line_id) values
  ('45000000-0000-0000-0000-000000000702','45000000-0000-0000-0000-000000000700','45000000-0000-0000-0000-000000000602');
insert into atlas_procurement.purchase_order_line_revisions
  (purchase_order_line_revision_id,purchase_order_revision_id,purchase_order_line_id,fulfilment_allocation_line_revision_id,ingredient_id,ordered_quantity,unit_id,delivery_location_id,service_date) values
  ('45000000-0000-0000-0000-000000000703','45000000-0000-0000-0000-000000000701','45000000-0000-0000-0000-000000000702','45000000-0000-0000-0000-000000000603','25000000-0000-0000-0000-000000000103',10,'25000000-0000-0000-0000-000000000102','25000000-0000-0000-0000-000000000101',date '2026-07-15');

insert into atlas_dispatch.dispatch_plans
  (dispatch_plan_id,plan_reference,service_date,created_by_actor_id) values
  ('55000000-0000-0000-0000-000000000900','PA05C-PLAN-001',date '2026-07-15','15000000-0000-0000-0000-000000000001');
insert into atlas_dispatch.dispatch_plan_requirements
  (dispatch_plan_requirement_id,dispatch_plan_id,dispatch_requirement_revision_id,fulfilment_allocation_revision_id) values
  ('55000000-0000-0000-0000-000000000901','55000000-0000-0000-0000-000000000900','35000000-0000-0000-0000-000000000501','45000000-0000-0000-0000-000000000601');
insert into atlas_dispatch.dispatch_trips
  (dispatch_trip_id,dispatch_plan_id,trip_reference,trip_status,driver_actor_id) values
  ('55000000-0000-0000-0000-000000000902','55000000-0000-0000-0000-000000000900','PA05C-TRIP-001','LOADED','15000000-0000-0000-0000-000000000001');
insert into atlas_dispatch.dispatch_stops
  (dispatch_stop_id,dispatch_trip_id,stop_sequence,dispatch_requirement_revision_id,customer_id,delivery_location_id,stop_status) values
  ('55000000-0000-0000-0000-000000000903','55000000-0000-0000-0000-000000000902',1,'35000000-0000-0000-0000-000000000501','25000000-0000-0000-0000-000000000100','25000000-0000-0000-0000-000000000101','LOADED');

-- A synthetic second stop and readiness line exercise read-scope expansion
-- without adding a command or operational mutation.
insert into atlas_planning.dispatch_requirements
  (dispatch_requirement_id,customer_id,delivery_location_id,service_date,requirement_status) values
  ('35000000-0000-0000-0000-000000000504','25000000-0000-0000-0000-000000000100','25000000-0000-0000-0000-000000000105',date '2026-07-15','RELEASED');
insert into atlas_planning.dispatch_requirement_revisions
  (dispatch_requirement_revision_id,dispatch_requirement_id,purchase_handoff_revision_id,revision_number,revision_status,customer_name_snapshot,location_name_snapshot,address_snapshot,released_by_actor_id,released_at) values
  ('35000000-0000-0000-0000-000000000505','35000000-0000-0000-0000-000000000504','35000000-0000-0000-0000-000000000401',1,'RELEASED','PA-05C customer','PA-05C location 2','Second address','15000000-0000-0000-0000-000000000001',timestamptz '2026-07-15 00:21:00+00');
insert into atlas_dispatch.dispatch_stops
  (dispatch_stop_id,dispatch_trip_id,stop_sequence,dispatch_requirement_revision_id,customer_id,delivery_location_id,stop_status) values
  ('55000000-0000-0000-0000-000000000907','55000000-0000-0000-0000-000000000902',2,'35000000-0000-0000-0000-000000000505','25000000-0000-0000-0000-000000000100','25000000-0000-0000-0000-000000000105','LOADED');
insert into atlas_planning.dispatch_requirement_lines
  (dispatch_requirement_line_id,dispatch_requirement_id,purchase_handoff_line_id) values
  ('35000000-0000-0000-0000-000000000506','35000000-0000-0000-0000-000000000504','35000000-0000-0000-0000-000000000402');
insert into atlas_planning.dispatch_requirement_line_revisions
  (dispatch_requirement_line_revision_id,dispatch_requirement_revision_id,dispatch_requirement_line_id,purchase_handoff_line_revision_id,ingredient_id,required_quantity,unit_id) values
  ('35000000-0000-0000-0000-000000000507','35000000-0000-0000-0000-000000000505','35000000-0000-0000-0000-000000000506','35000000-0000-0000-0000-000000000403','25000000-0000-0000-0000-000000000103',10,'25000000-0000-0000-0000-000000000102');
insert into atlas_procurement.fulfilment_allocations
  (fulfilment_allocation_id,dispatch_requirement_id,allocation_status) values
  ('45000000-0000-0000-0000-000000000604','35000000-0000-0000-0000-000000000504','READY_FOR_DISPATCH');
insert into atlas_procurement.fulfilment_allocation_revisions
  (fulfilment_allocation_revision_id,fulfilment_allocation_id,revision_number,revision_status,allocated_by_actor_id) values
  ('45000000-0000-0000-0000-000000000605','45000000-0000-0000-0000-000000000604',1,'READY_FOR_DISPATCH','15000000-0000-0000-0000-000000000001');
insert into atlas_procurement.fulfilment_allocation_lines
  (fulfilment_allocation_line_id,fulfilment_allocation_id,dispatch_requirement_line_id,portion_sequence) values
  ('45000000-0000-0000-0000-000000000606','45000000-0000-0000-0000-000000000604','35000000-0000-0000-0000-000000000506',1);
insert into atlas_procurement.fulfilment_allocation_line_revisions
  (fulfilment_allocation_line_revision_id,fulfilment_allocation_revision_id,fulfilment_allocation_line_id,dispatch_requirement_line_revision_id,supplier_id,allocated_quantity,unit_id,line_status) values
  ('45000000-0000-0000-0000-000000000607','45000000-0000-0000-0000-000000000605','45000000-0000-0000-0000-000000000606','35000000-0000-0000-0000-000000000507','25000000-0000-0000-0000-000000000104',10,'25000000-0000-0000-0000-000000000102','EVIDENCED');
insert into atlas_evidence.supplier_receiving_evidence
  (supplier_receiving_evidence_id,supplier_id,purchase_order_line_revision_id,ingredient_id,evidence_reference,evidence_quantity,unit_id,evidence_status,occurred_at,recorded_by_actor_id,command_id,correlation_id) values
  ('65000000-0000-0000-0000-000000000001','25000000-0000-0000-0000-000000000104','45000000-0000-0000-0000-000000000703','25000000-0000-0000-0000-000000000103','PA05C-EVIDENCE-001',10,'25000000-0000-0000-0000-000000000102','VALID',timestamptz '2026-07-15 00:30:00+00','15000000-0000-0000-0000-000000000001','95000000-0000-0000-0000-000000000001','95000000-0000-0000-0000-000000000010');
insert into atlas_evidence.evidence_applications
  (evidence_application_id,supplier_receiving_evidence_id,fulfilment_allocation_line_revision_id,applied_quantity,unit_id,application_status,occurred_at,recorded_by_actor_id,command_id,correlation_id) values
  ('65000000-0000-0000-0000-000000000002','65000000-0000-0000-0000-000000000001','45000000-0000-0000-0000-000000000603',10,'25000000-0000-0000-0000-000000000102','VALID',timestamptz '2026-07-15 00:31:00+00','15000000-0000-0000-0000-000000000001','95000000-0000-0000-0000-000000000002','95000000-0000-0000-0000-000000000010');
insert into atlas_dispatch.dispatch_loads
  (dispatch_load_id,dispatch_trip_id,dispatch_requirement_revision_id,fulfilment_allocation_revision_id,load_status,loaded_by_actor_id,loaded_at) values
  ('55000000-0000-0000-0000-000000000904','55000000-0000-0000-0000-000000000902','35000000-0000-0000-0000-000000000501','45000000-0000-0000-0000-000000000601','CONFIRMED','15000000-0000-0000-0000-000000000001',timestamptz '2026-07-15 00:35:00+00');
insert into atlas_dispatch.dispatch_load_lines
  (dispatch_load_line_id,dispatch_load_id,dispatch_stop_id,dispatch_requirement_line_revision_id,fulfilment_allocation_line_revision_id,ingredient_id,loaded_quantity,unit_id,command_id) values
  ('55000000-0000-0000-0000-000000000905','55000000-0000-0000-0000-000000000904','55000000-0000-0000-0000-000000000903','35000000-0000-0000-0000-000000000503','45000000-0000-0000-0000-000000000603','25000000-0000-0000-0000-000000000103',10,'25000000-0000-0000-0000-000000000102','95000000-0000-0000-0000-000000000003');
insert into atlas_dispatch.dispatch_load_line_applications
  (dispatch_load_line_application_id,dispatch_load_line_id,evidence_application_id,applied_to_load_quantity,unit_id) values
  ('55000000-0000-0000-0000-000000000906','55000000-0000-0000-0000-000000000905','65000000-0000-0000-0000-000000000002',10,'25000000-0000-0000-0000-000000000102');

insert into atlas_core.command_receipts
  (command_receipt_id,command_name,scope_key,idempotency_key,command_id,correlation_id,actor_id,expected_version,request_hash,outcome,completed_at) values
  ('75000000-0000-0000-0000-000000000001','record_dispatch_departure','DISPATCH_TRIP:55000000-0000-0000-0000-000000000902','pa05c-timeline','95000000-0000-0000-0000-000000000004','95000000-0000-0000-0000-000000000010','15000000-0000-0000-0000-000000000001',1,repeat('a',64),'COMPLETED',timestamptz '2026-07-15 00:40:00+00');
insert into atlas_audit.domain_events
  (domain_event_id,event_type,source_domain,aggregate_type,aggregate_id,aggregate_version,command_receipt_id,command_id,correlation_id,actor_id,occurred_at) values
  ('75000000-0000-0000-0000-000000000002','DISPATCH_DEPARTED','DISPATCH','DISPATCH_STOP','55000000-0000-0000-0000-000000000903',2,'75000000-0000-0000-0000-000000000001','95000000-0000-0000-0000-000000000004','95000000-0000-0000-0000-000000000010','15000000-0000-0000-0000-000000000001',timestamptz '2026-07-15 00:39:00+00'),
  ('75000000-0000-0000-0000-000000000004','TRIP_REVIEWED','DISPATCH','DISPATCH_TRIP','55000000-0000-0000-0000-000000000902',2,null,'95000000-0000-0000-0000-000000000005','95000000-0000-0000-0000-000000000011','15000000-0000-0000-0000-000000000001',timestamptz '2026-07-15 00:41:00+00');
insert into atlas_audit.audit_events
  (audit_event_id,event_type,source_domain,aggregate_type,aggregate_id,aggregate_version_before,aggregate_version_after,command_receipt_id,command_id,correlation_id,actor_id,reason_code,reason_note,source_interface,occurred_at) values
  ('75000000-0000-0000-0000-000000000003','DISPATCH_DEPARTED','DISPATCH','DISPATCH_STOP','55000000-0000-0000-0000-000000000903',1,2,'75000000-0000-0000-0000-000000000001','95000000-0000-0000-0000-000000000004','95000000-0000-0000-0000-000000000010','15000000-0000-0000-0000-000000000001','PA05C_TEST','Safe test reason','PGTAP',timestamptz '2026-07-15 00:39:00+00');

create function pg_temp.pa05c_request(subject uuid, payload jsonb)
returns jsonb language sql immutable set search_path='' as $$
  select pg_catalog.jsonb_build_object(
    'contract_version','PA-05C.v1','requested_by_auth_subject',subject,
    'correlation_id','95000000-0000-0000-0000-000000000099'::uuid,'payload',payload
  )
$$;

-- Authentication and authorization failures.
set local role authenticated;
select is(
  (atlas_api.get_dispatch_evidence_readiness(pg_temp.pa05c_request(
    '15000000-0000-0000-0000-000000000101',jsonb_build_object('dispatch_trip_id','55000000-0000-0000-0000-000000000902')))->>'error_code'),
  'AUTHENTICATION_REQUIRED','missing JWT subject fails'
);
set local request.jwt.claim.sub='15000000-0000-0000-0000-000000000101';
select is(
  (atlas_api.get_dispatch_evidence_readiness(pg_temp.pa05c_request(
    '15000000-0000-0000-0000-000000000102',jsonb_build_object('dispatch_trip_id','55000000-0000-0000-0000-000000000902')))->>'error_code'),
  'AUTH_SUBJECT_MISMATCH','subject mismatch fails'
);
set local request.jwt.claim.sub='15000000-0000-0000-0000-000000000102';
select is((atlas_api.get_dispatch_evidence_readiness(pg_temp.pa05c_request(
  '15000000-0000-0000-0000-000000000102',jsonb_build_object('dispatch_trip_id','55000000-0000-0000-0000-000000000902')))->>'error_code'),'ACTOR_INACTIVE','inactive actor fails');
set local request.jwt.claim.sub='15000000-0000-0000-0000-000000000103';
select is((atlas_api.get_dispatch_evidence_readiness(pg_temp.pa05c_request(
  '15000000-0000-0000-0000-000000000103',jsonb_build_object('dispatch_trip_id','55000000-0000-0000-0000-000000000902')))->>'error_code'),'AUTH_SUBJECT_INACTIVE','revoked auth subject fails');
set local request.jwt.claim.sub='15000000-0000-0000-0000-000000000104';
select is((atlas_api.get_dispatch_evidence_readiness(pg_temp.pa05c_request(
  '15000000-0000-0000-0000-000000000104',jsonb_build_object('dispatch_trip_id','55000000-0000-0000-0000-000000000902')))->>'error_code'),'CAPABILITY_DENIED','missing capability fails');
set local request.jwt.claim.sub='15000000-0000-0000-0000-000000000105';
select is((atlas_api.get_dispatch_evidence_readiness(pg_temp.pa05c_request(
  '15000000-0000-0000-0000-000000000105',jsonb_build_object('dispatch_trip_id','55000000-0000-0000-0000-000000000902')))->>'error_code'),'SCOPE_DENIED','wrong relational scope fails');
set local request.jwt.claim.sub='15000000-0000-0000-0000-000000000101';
select is((atlas_api.get_dispatch_evidence_readiness(pg_temp.pa05c_request(
  '15000000-0000-0000-0000-000000000101',jsonb_build_object('dispatch_trip_id','55000000-0000-0000-0000-000000000902')))->>'success'),'true','correct capability and scope succeeds');

select is((atlas_api.get_dispatch_evidence_readiness(pg_temp.pa05c_request(
  '15000000-0000-0000-0000-000000000101',jsonb_build_object('dispatch_trip_id','55000000-0000-0000-0000-000000000902')))->'readiness_items'->0->>'readiness_status'),'READY','readiness returns shaped READY response');
select is((atlas_api.get_dispatch_evidence_readiness(pg_temp.pa05c_request(
  '15000000-0000-0000-0000-000000000101','{}'::jsonb))->>'error_code'),'UNBOUNDED_OR_AMBIGUOUS_SELECTOR','readiness rejects unbounded payload');
reset role;

update atlas_evidence.supplier_receiving_evidence set evidence_status='VOIDED'
where supplier_receiving_evidence_id='65000000-0000-0000-0000-000000000001';
set local role authenticated;
set local request.jwt.claim.sub='15000000-0000-0000-0000-000000000101';
select is((atlas_api.get_dispatch_evidence_readiness(pg_temp.pa05c_request(
  '15000000-0000-0000-0000-000000000101',jsonb_build_object('dispatch_trip_id','55000000-0000-0000-0000-000000000902')))->'readiness_items'->0->>'readiness_status'),'VOIDED_OR_SUPERSEDED_EVIDENCE','readiness safely reports voided evidence');
select ok(jsonb_array_length((atlas_api.get_dispatch_evidence_readiness(pg_temp.pa05c_request(
  '15000000-0000-0000-0000-000000000101',jsonb_build_object('dispatch_trip_id','55000000-0000-0000-0000-000000000902')))->'readiness_items'->0->'blockers')) > 0,'voided readiness includes safe blockers');

select ok((atlas_api.get_operator_blockers(pg_temp.pa05c_request(
  '15000000-0000-0000-0000-000000000101',jsonb_build_object('dispatch_trip_id','55000000-0000-0000-0000-000000000902')))->>'blocker_count')::integer > 0,'operator blockers returns bounded trip blockers');
select is((atlas_api.get_operator_blockers(pg_temp.pa05c_request(
  '15000000-0000-0000-0000-000000000101','{}'::jsonb))->>'error_code'),'UNBOUNDED_OR_AMBIGUOUS_SELECTOR','operator blockers rejects unbounded payload');

-- A location-scoped actor cannot use a customer/date or multi-stop trip selector
-- to expand from the authorized first location into the second location.
set local request.jwt.claim.sub='15000000-0000-0000-0000-000000000106';
select is((atlas_api.get_operator_blockers(pg_temp.pa05c_request(
  '15000000-0000-0000-0000-000000000106',jsonb_build_object(
    'customer_id','25000000-0000-0000-0000-000000000100','service_date','2026-07-15'
  )))->>'error_code'),'SCOPE_DENIED','location-scoped actor is denied a customer/date selector spanning two locations');
select is((atlas_api.get_operator_blockers(pg_temp.pa05c_request(
  '15000000-0000-0000-0000-000000000106',jsonb_build_object(
    'dispatch_trip_id','55000000-0000-0000-0000-000000000902'
  )))->>'error_code'),'SCOPE_DENIED','location-scoped actor is denied a multi-stop trip selector');
select is((atlas_api.get_dispatch_evidence_readiness(pg_temp.pa05c_request(
  '15000000-0000-0000-0000-000000000106',jsonb_build_object(
    'dispatch_trip_id','55000000-0000-0000-0000-000000000902'
  )))->>'error_code'),'SCOPE_DENIED','readiness denies a multi-stop trip before shaping unauthorized rows');
set local request.jwt.claim.sub='15000000-0000-0000-0000-000000000101';
select is((atlas_api.get_operator_blockers(pg_temp.pa05c_request(
  '15000000-0000-0000-0000-000000000101',jsonb_build_object(
    'customer_id','25000000-0000-0000-0000-000000000100','service_date','2026-07-15'
  )))->>'success'),'true','customer-scoped actor may read all selected customer/date locations');

select is((atlas_api.get_command_audit_timeline(pg_temp.pa05c_request(
  '15000000-0000-0000-0000-000000000101',jsonb_build_object(
    'aggregate_type','DISPATCH_STOP','aggregate_id','55000000-0000-0000-0000-000000000903'
  )))->>'success'),'true','audit timeline returns a known single-scope aggregate');
set local request.jwt.claim.sub='15000000-0000-0000-0000-000000000106';
select is((atlas_api.get_command_audit_timeline(pg_temp.pa05c_request(
  '15000000-0000-0000-0000-000000000106',jsonb_build_object(
    'aggregate_type','DISPATCH_TRIP','aggregate_id','55000000-0000-0000-0000-000000000902'
  )))->>'error_code'),'AMBIGUOUS_SCOPE','multi-location trip timeline fails closed');
set local request.jwt.claim.sub='15000000-0000-0000-0000-000000000101';
select is((atlas_api.get_command_audit_timeline(pg_temp.pa05c_request(
  '15000000-0000-0000-0000-000000000101','{}'::jsonb))->>'error_code'),'UNBOUNDED_OR_AMBIGUOUS_SELECTOR','audit timeline rejects unbounded payload');
select ok(
  (atlas_api.get_command_audit_timeline(pg_temp.pa05c_request(
    '15000000-0000-0000-0000-000000000101',jsonb_build_object(
      'aggregate_type','DISPATCH_STOP','aggregate_id','55000000-0000-0000-0000-000000000903'
    )))::text
    !~* '(request_hash|response_payload|sql internals|credential|jwt|service.role|stack trace)'),
  'audit timeline excludes prohibited internals'
);
reset role;

select is((select count(*)::integer from atlas_core.command_receipts),1,'reads create no command receipts');
select is((select count(*)::integer from atlas_audit.domain_events),2,'reads create no domain events');
select is((select count(*)::integer from atlas_audit.audit_events),1,'reads create no audit events');
select is((select count(*)::integer from atlas_dispatch.dispatch_loads),1,'reads do not mutate domain rows');

select * from finish();
rollback;
