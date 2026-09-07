begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
select plan(47);

grant usage on schema extensions to authenticated;
grant execute on all functions in schema extensions to authenticated;

select ok(
  not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    join pg_roles r on r.oid=p.proowner
    where n.nspname='atlas_api'
      and p.proname in ('create_dispatch_plan','create_or_assign_dispatch_trip')
      and (
        r.rolname <> 'atlas_dispatch_command_runtime'
        or not p.prosecdef or p.provolatile <> 'v'
        or p.proconfig is null or p.proconfig::text not like '%search_path=%'
      )
  ),
  'both PA-05F functions are hardened volatile definers owned by Dispatch runtime'
);
select ok(
  not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='atlas_api'
      and p.proname in ('create_dispatch_plan','create_or_assign_dispatch_trip')
      and pg_get_functiondef(p.oid) ~* '\mexecute\M'
  ),
  'PA-05F functions contain no dynamic SQL'
);
select is(
  (select count(*)::integer from pg_proc p join pg_roles r on r.oid=p.proowner
   where r.rolname='atlas_dispatch_command_runtime'),
  7,
  'Dispatch runtime owns only the three H2, two PA-05F, one PA-05B-H3, and one School PXK release entry functions'
);
select ok(
  not has_schema_privilege('atlas_dispatch_command_runtime','atlas_api','CREATE')
  and not exists (
    select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname like 'atlas\_%' escape '\' and c.relkind='S'
      and (has_sequence_privilege('atlas_dispatch_command_runtime',c.oid,'USAGE')
        or has_sequence_privilege('atlas_dispatch_command_runtime',c.oid,'UPDATE'))
  ),
  'Dispatch runtime has no Atlas schema CREATE or sequence mutation privilege'
);
select ok(
  has_table_privilege('atlas_dispatch_command_runtime','atlas_dispatch.dispatch_plans','INSERT')
  and has_table_privilege('atlas_dispatch_command_runtime','atlas_dispatch.dispatch_plan_requirements','INSERT')
  and has_table_privilege('atlas_dispatch_command_runtime','atlas_dispatch.dispatch_trips','INSERT')
  and has_table_privilege('atlas_dispatch_command_runtime','atlas_dispatch.dispatch_stops','INSERT')
  and has_table_privilege('atlas_dispatch_command_runtime','atlas_dispatch.dispatch_plans','UPDATE')
  and not has_table_privilege('atlas_dispatch_command_runtime','atlas_planning.dispatch_requirements','INSERT')
  and not has_table_privilege('atlas_dispatch_command_runtime','atlas_procurement.fulfilment_allocations','INSERT')
  and not has_table_privilege('atlas_dispatch_command_runtime','atlas_evidence.supplier_receiving_evidence','INSERT'),
  'Dispatch runtime can write only the bounded Dispatch setup facts'
);
select ok(
  (select r.rolname from pg_proc p join pg_roles r on r.oid=p.proowner
   where p.oid='atlas_core.pa_05f_validate_command_request(jsonb,text)'::regprocedure)='atlas_owner'
  and (select r.rolname from pg_proc p join pg_roles r on r.oid=p.proowner
   where p.oid='atlas_core.pa_05f_dispatch_pair_is_ready(uuid,uuid)'::regprocedure)='atlas_owner'
  and not has_function_privilege('authenticated','atlas_core.pa_05f_validate_command_request(jsonb,text)'::regprocedure,'EXECUTE')
  and not has_function_privilege('authenticated','atlas_core.pa_05f_dispatch_pair_is_ready(uuid,uuid)'::regprocedure,'EXECUTE')
  and has_function_privilege('atlas_dispatch_command_runtime','atlas_core.pa_05f_validate_command_request(jsonb,text)'::regprocedure,'EXECUTE')
  and has_function_privilege('atlas_dispatch_command_runtime','atlas_core.pa_05f_dispatch_pair_is_ready(uuid,uuid)'::regprocedure,'EXECUTE'),
  'PA-05F private helpers are owner-hardened and executable only by Dispatch runtime'
);

insert into atlas_core.actors (actor_id,actor_type,display_name,actor_status,deactivated_at) values
  ('f0000000-0000-0000-0000-000000000001','HUMAN','PA-05F operator','ACTIVE',null),
  ('f0000000-0000-0000-0000-000000000002','DELEGATED_DRIVER','PA-05F driver','ACTIVE',null),
  ('f0000000-0000-0000-0000-000000000003','HUMAN','PA-05F narrow operator','ACTIVE',null),
  ('f0000000-0000-0000-0000-000000000004','INTEGRATION','PA-05F invalid driver','ACTIVE',null);
insert into atlas_core.actor_auth_subjects (actor_id,auth_subject_id) values
  ('f0000000-0000-0000-0000-000000000001','f0000000-0000-0000-0000-000000000101'),
  ('f0000000-0000-0000-0000-000000000003','f0000000-0000-0000-0000-000000000103');
insert into atlas_core.roles (role_id,role_code,role_name) values
  ('f1000000-0000-0000-0000-000000000001','pa05f.operator','PA-05F operator');
insert into atlas_core.capabilities (capability_id,capability_code,capability_name,owning_domain) values
  ('f2000000-0000-0000-0000-000000000001','dispatch_plan.create','Create Dispatch Plan','DISPATCH'),
  ('f2000000-0000-0000-0000-000000000002','dispatch_trip.assign','Assign Dispatch Trip','DISPATCH');
insert into atlas_core.role_capabilities (role_id,capability_id) values
  ('f1000000-0000-0000-0000-000000000001','f2000000-0000-0000-0000-000000000001'),
  ('f1000000-0000-0000-0000-000000000001','f2000000-0000-0000-0000-000000000002');
insert into atlas_core.actor_role_memberships (actor_id,role_id) values
  ('f0000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000001'),
  ('f0000000-0000-0000-0000-000000000003','f1000000-0000-0000-0000-000000000001');
insert into atlas_core.actor_scopes (actor_id,scope_kind) values
  ('f0000000-0000-0000-0000-000000000001','GLOBAL');

insert into atlas_admin.customers (customer_id,customer_code,customer_name) values
  ('f3000000-0000-0000-0000-000000000001','pa05f-a','PA-05F Customer A'),
  ('f3000000-0000-0000-0000-000000000002','pa05f-b','PA-05F Customer B');
insert into atlas_admin.delivery_locations (
  delivery_location_id,customer_id,location_code,location_name,address_text,timezone_name
) values
  ('f3000000-0000-0000-0000-000000000011','f3000000-0000-0000-0000-000000000001','pa05f-a','PA-05F Location A','Address A','Asia/Bangkok'),
  ('f3000000-0000-0000-0000-000000000012','f3000000-0000-0000-0000-000000000002','pa05f-b','PA-05F Location B','Address B','Asia/Bangkok');
insert into atlas_core.actor_scopes (actor_id,scope_kind,customer_id) values
  ('f0000000-0000-0000-0000-000000000003','CUSTOMER','f3000000-0000-0000-0000-000000000001');
insert into atlas_admin.units (unit_id,unit_code,unit_name,dimension_code) values
  ('f3000000-0000-0000-0000-000000000021','pa05f-kg','kilogram','mass');
insert into atlas_admin.ingredients (ingredient_id,ingredient_code,ingredient_name) values
  ('f3000000-0000-0000-0000-000000000031','pa05f-rice','Rice');
insert into atlas_admin.suppliers (supplier_id,supplier_code,supplier_name) values
  ('f3000000-0000-0000-0000-000000000041','pa05f-supplier','PA-05F Supplier');

-- Two independent, same-date, single-line PA-05D/PA-05E chains prove the
-- required multi-requirement and multi-destination admission path.
insert into atlas_planning.wholesale_orders (
  wholesale_order_id,customer_id,delivery_location_id,customer_order_reference,
  service_date,order_status,created_by_actor_id,approved_by_actor_id,approved_at,
  released_by_actor_id,released_at
) values
  ('f4000000-0000-0000-0000-000000000101','f3000000-0000-0000-0000-000000000001','f3000000-0000-0000-0000-000000000011','PA05F-A',date '2026-07-16','RELEASED','f0000000-0000-0000-0000-000000000001','f0000000-0000-0000-0000-000000000001',timestamptz '2026-07-16 00:01:00+00','f0000000-0000-0000-0000-000000000001',timestamptz '2026-07-16 00:02:00+00'),
  ('f4000000-0000-0000-0000-000000000201','f3000000-0000-0000-0000-000000000002','f3000000-0000-0000-0000-000000000012','PA05F-B',date '2026-07-16','RELEASED','f0000000-0000-0000-0000-000000000001','f0000000-0000-0000-0000-000000000001',timestamptz '2026-07-16 00:01:00+00','f0000000-0000-0000-0000-000000000001',timestamptz '2026-07-16 00:02:00+00');
insert into atlas_planning.wholesale_order_lines (
  wholesale_order_line_id,wholesale_order_id,source_line_number
) values
  ('f4100000-0000-0000-0000-000000000101','f4000000-0000-0000-0000-000000000101',1),
  ('f4100000-0000-0000-0000-000000000201','f4000000-0000-0000-0000-000000000201',1);
insert into atlas_planning.wholesale_order_line_revisions (
  wholesale_order_line_revision_id,wholesale_order_line_id,revision_number,
  ingredient_id,requested_quantity,unit_id,revision_status,created_by_actor_id
) values
  ('f4110000-0000-0000-0000-000000000101','f4100000-0000-0000-0000-000000000101',1,'f3000000-0000-0000-0000-000000000031',10,'f3000000-0000-0000-0000-000000000021','RELEASED','f0000000-0000-0000-0000-000000000001'),
  ('f4110000-0000-0000-0000-000000000201','f4100000-0000-0000-0000-000000000201',1,'f3000000-0000-0000-0000-000000000031',20,'f3000000-0000-0000-0000-000000000021','RELEASED','f0000000-0000-0000-0000-000000000001');
insert into atlas_planning.confirmed_need_batches (
  confirmed_need_batch_id,wholesale_order_id,period_start,period_end,batch_status,
  created_by_actor_id,approved_by_actor_id,approved_at,released_by_actor_id,released_at
) values
  ('f4200000-0000-0000-0000-000000000101','f4000000-0000-0000-0000-000000000101',date '2026-07-16',date '2026-07-16','RELEASED_FOR_PURCHASE_HANDOFF','f0000000-0000-0000-0000-000000000001','f0000000-0000-0000-0000-000000000001',timestamptz '2026-07-16 00:03:00+00','f0000000-0000-0000-0000-000000000001',timestamptz '2026-07-16 00:04:00+00'),
  ('f4200000-0000-0000-0000-000000000201','f4000000-0000-0000-0000-000000000201',date '2026-07-16',date '2026-07-16','RELEASED_FOR_PURCHASE_HANDOFF','f0000000-0000-0000-0000-000000000001','f0000000-0000-0000-0000-000000000001',timestamptz '2026-07-16 00:03:00+00','f0000000-0000-0000-0000-000000000001',timestamptz '2026-07-16 00:04:00+00');
insert into atlas_planning.confirmed_need_lines (
  confirmed_need_line_id,confirmed_need_batch_id,wholesale_order_line_id
) values
  ('f4210000-0000-0000-0000-000000000101','f4200000-0000-0000-0000-000000000101','f4100000-0000-0000-0000-000000000101'),
  ('f4210000-0000-0000-0000-000000000201','f4200000-0000-0000-0000-000000000201','f4100000-0000-0000-0000-000000000201');
insert into atlas_planning.confirmed_need_line_revisions (
  confirmed_need_line_revision_id,confirmed_need_line_id,revision_number,
  wholesale_order_line_revision_id,ingredient_id,theoretical_quantity,
  confirmed_quantity,unit_id,revision_status,created_by_actor_id
) values
  ('f4220000-0000-0000-0000-000000000101','f4210000-0000-0000-0000-000000000101',1,'f4110000-0000-0000-0000-000000000101','f3000000-0000-0000-0000-000000000031',10,10,'f3000000-0000-0000-0000-000000000021','RELEASED','f0000000-0000-0000-0000-000000000001'),
  ('f4220000-0000-0000-0000-000000000201','f4210000-0000-0000-0000-000000000201',1,'f4110000-0000-0000-0000-000000000201','f3000000-0000-0000-0000-000000000031',20,20,'f3000000-0000-0000-0000-000000000021','RELEASED','f0000000-0000-0000-0000-000000000001');
insert into atlas_planning.confirmed_need_approval_snapshots (
  confirmed_need_approval_snapshot_id,confirmed_need_batch_id,approved_version,
  approved_by_actor_id,approved_at,command_id
) values
  ('f4230000-0000-0000-0000-000000000101','f4200000-0000-0000-0000-000000000101',1,'f0000000-0000-0000-0000-000000000001',timestamptz '2026-07-16 00:03:00+00','f9000000-0000-0000-0000-000000000101'),
  ('f4230000-0000-0000-0000-000000000201','f4200000-0000-0000-0000-000000000201',1,'f0000000-0000-0000-0000-000000000001',timestamptz '2026-07-16 00:03:00+00','f9000000-0000-0000-0000-000000000201');
insert into atlas_planning.confirmed_need_snapshot_lines (
  confirmed_need_snapshot_line_id,confirmed_need_approval_snapshot_id,
  confirmed_need_line_revision_id,ingredient_id,approved_quantity,unit_id,
  ingredient_name_snapshot
) values
  ('f4240000-0000-0000-0000-000000000101','f4230000-0000-0000-0000-000000000101','f4220000-0000-0000-0000-000000000101','f3000000-0000-0000-0000-000000000031',10,'f3000000-0000-0000-0000-000000000021','Rice'),
  ('f4240000-0000-0000-0000-000000000201','f4230000-0000-0000-0000-000000000201','f4220000-0000-0000-0000-000000000201','f3000000-0000-0000-0000-000000000031',20,'f3000000-0000-0000-0000-000000000021','Rice');
insert into atlas_planning.purchase_handoff_batches (
  purchase_handoff_batch_id,confirmed_need_batch_id,period_start,period_end,
  handoff_status,created_by_actor_id
) values
  ('f4300000-0000-0000-0000-000000000101','f4200000-0000-0000-0000-000000000101',date '2026-07-16',date '2026-07-16','RELEASED_TO_PROCUREMENT','f0000000-0000-0000-0000-000000000001'),
  ('f4300000-0000-0000-0000-000000000201','f4200000-0000-0000-0000-000000000201',date '2026-07-16',date '2026-07-16','RELEASED_TO_PROCUREMENT','f0000000-0000-0000-0000-000000000001');
insert into atlas_planning.purchase_handoff_revisions (
  purchase_handoff_revision_id,purchase_handoff_batch_id,revision_number,
  revision_status,released_by_actor_id,released_at
) values
  ('f4310000-0000-0000-0000-000000000101','f4300000-0000-0000-0000-000000000101',1,'RELEASED_TO_PROCUREMENT','f0000000-0000-0000-0000-000000000001',timestamptz '2026-07-16 00:05:00+00'),
  ('f4310000-0000-0000-0000-000000000201','f4300000-0000-0000-0000-000000000201',1,'RELEASED_TO_PROCUREMENT','f0000000-0000-0000-0000-000000000001',timestamptz '2026-07-16 00:05:00+00');
insert into atlas_planning.purchase_handoff_lines (
  purchase_handoff_line_id,purchase_handoff_batch_id,confirmed_need_line_id
) values
  ('f4320000-0000-0000-0000-000000000101','f4300000-0000-0000-0000-000000000101','f4210000-0000-0000-0000-000000000101'),
  ('f4320000-0000-0000-0000-000000000201','f4300000-0000-0000-0000-000000000201','f4210000-0000-0000-0000-000000000201');
insert into atlas_planning.purchase_handoff_line_revisions (
  purchase_handoff_line_revision_id,purchase_handoff_revision_id,
  purchase_handoff_line_id,confirmed_need_line_revision_id,ingredient_id,
  handoff_quantity,unit_id,service_date,delivery_location_id
) values
  ('f4330000-0000-0000-0000-000000000101','f4310000-0000-0000-0000-000000000101','f4320000-0000-0000-0000-000000000101','f4220000-0000-0000-0000-000000000101','f3000000-0000-0000-0000-000000000031',10,'f3000000-0000-0000-0000-000000000021',date '2026-07-16','f3000000-0000-0000-0000-000000000011'),
  ('f4330000-0000-0000-0000-000000000201','f4310000-0000-0000-0000-000000000201','f4320000-0000-0000-0000-000000000201','f4220000-0000-0000-0000-000000000201','f3000000-0000-0000-0000-000000000031',20,'f3000000-0000-0000-0000-000000000021',date '2026-07-16','f3000000-0000-0000-0000-000000000012');
insert into atlas_planning.purchase_demand_references (
  purchase_demand_reference_id,purchase_handoff_line_revision_id,
  confirmed_need_snapshot_line_id,wholesale_order_line_revision_id,
  approved_quantity,unit_id
) values
  ('f4340000-0000-0000-0000-000000000101','f4330000-0000-0000-0000-000000000101','f4240000-0000-0000-0000-000000000101','f4110000-0000-0000-0000-000000000101',10,'f3000000-0000-0000-0000-000000000021'),
  ('f4340000-0000-0000-0000-000000000201','f4330000-0000-0000-0000-000000000201','f4240000-0000-0000-0000-000000000201','f4110000-0000-0000-0000-000000000201',20,'f3000000-0000-0000-0000-000000000021');

insert into atlas_planning.dispatch_requirements (
  dispatch_requirement_id,customer_id,delivery_location_id,service_date,
  requirement_status,version
) values
  ('f4400000-0000-0000-0000-000000000101','f3000000-0000-0000-0000-000000000001','f3000000-0000-0000-0000-000000000011',date '2026-07-16','RELEASED',1),
  ('f4400000-0000-0000-0000-000000000201','f3000000-0000-0000-0000-000000000002','f3000000-0000-0000-0000-000000000012',date '2026-07-16','RELEASED',1);
insert into atlas_planning.dispatch_requirement_revisions (
  dispatch_requirement_revision_id,dispatch_requirement_id,
  purchase_handoff_revision_id,revision_number,revision_status,is_current,
  customer_name_snapshot,location_name_snapshot,address_snapshot,timezone_name,
  released_by_actor_id,released_at
) values
  ('f4410000-0000-0000-0000-000000000101','f4400000-0000-0000-0000-000000000101','f4310000-0000-0000-0000-000000000101',1,'RELEASED',true,'PA-05F Customer A','PA-05F Location A','Address A','Asia/Bangkok','f0000000-0000-0000-0000-000000000001',timestamptz '2026-07-16 00:06:00+00'),
  ('f4410000-0000-0000-0000-000000000201','f4400000-0000-0000-0000-000000000201','f4310000-0000-0000-0000-000000000201',1,'RELEASED',true,'PA-05F Customer B','PA-05F Location B','Address B','Asia/Bangkok','f0000000-0000-0000-0000-000000000001',timestamptz '2026-07-16 00:06:00+00');
insert into atlas_planning.dispatch_requirement_lines (
  dispatch_requirement_line_id,dispatch_requirement_id,purchase_handoff_line_id
) values
  ('f4420000-0000-0000-0000-000000000101','f4400000-0000-0000-0000-000000000101','f4320000-0000-0000-0000-000000000101'),
  ('f4420000-0000-0000-0000-000000000201','f4400000-0000-0000-0000-000000000201','f4320000-0000-0000-0000-000000000201');
insert into atlas_planning.dispatch_requirement_line_revisions (
  dispatch_requirement_line_revision_id,dispatch_requirement_revision_id,
  dispatch_requirement_line_id,purchase_handoff_line_revision_id,ingredient_id,
  required_quantity,unit_id
) values
  ('f4430000-0000-0000-0000-000000000101','f4410000-0000-0000-0000-000000000101','f4420000-0000-0000-0000-000000000101','f4330000-0000-0000-0000-000000000101','f3000000-0000-0000-0000-000000000031',10,'f3000000-0000-0000-0000-000000000021'),
  ('f4430000-0000-0000-0000-000000000201','f4410000-0000-0000-0000-000000000201','f4420000-0000-0000-0000-000000000201','f4330000-0000-0000-0000-000000000201','f3000000-0000-0000-0000-000000000031',20,'f3000000-0000-0000-0000-000000000021');

insert into atlas_procurement.fulfilment_allocations (
  fulfilment_allocation_id,dispatch_requirement_id,allocation_status,version
) values
  ('f5000000-0000-0000-0000-000000000101','f4400000-0000-0000-0000-000000000101','READY_FOR_DISPATCH',1),
  ('f5000000-0000-0000-0000-000000000201','f4400000-0000-0000-0000-000000000201','READY_FOR_DISPATCH',1);
insert into atlas_procurement.fulfilment_allocation_revisions (
  fulfilment_allocation_revision_id,fulfilment_allocation_id,revision_number,
  revision_status,is_current,allocated_by_actor_id
) values
  ('f5010000-0000-0000-0000-000000000101','f5000000-0000-0000-0000-000000000101',1,'READY_FOR_DISPATCH',true,'f0000000-0000-0000-0000-000000000001'),
  ('f5010000-0000-0000-0000-000000000201','f5000000-0000-0000-0000-000000000201',1,'READY_FOR_DISPATCH',true,'f0000000-0000-0000-0000-000000000001');
insert into atlas_procurement.fulfilment_allocation_lines (
  fulfilment_allocation_line_id,fulfilment_allocation_id,
  dispatch_requirement_line_id,portion_sequence
) values
  ('f5020000-0000-0000-0000-000000000101','f5000000-0000-0000-0000-000000000101','f4420000-0000-0000-0000-000000000101',1),
  ('f5020000-0000-0000-0000-000000000201','f5000000-0000-0000-0000-000000000201','f4420000-0000-0000-0000-000000000201',1);
insert into atlas_procurement.fulfilment_allocation_line_revisions (
  fulfilment_allocation_line_revision_id,fulfilment_allocation_revision_id,
  fulfilment_allocation_line_id,dispatch_requirement_line_revision_id,
  supplier_id,allocated_quantity,unit_id,line_status
) values
  ('f5030000-0000-0000-0000-000000000101','f5010000-0000-0000-0000-000000000101','f5020000-0000-0000-0000-000000000101','f4430000-0000-0000-0000-000000000101','f3000000-0000-0000-0000-000000000041',10,'f3000000-0000-0000-0000-000000000021','READY_FOR_EVIDENCE'),
  ('f5030000-0000-0000-0000-000000000201','f5010000-0000-0000-0000-000000000201','f5020000-0000-0000-0000-000000000201','f4430000-0000-0000-0000-000000000201','f3000000-0000-0000-0000-000000000041',20,'f3000000-0000-0000-0000-000000000021','READY_FOR_EVIDENCE');
insert into atlas_procurement.purchase_orders (
  purchase_order_id,supplier_id,document_number,purchase_order_status,version
) values
  ('f5100000-0000-0000-0000-000000000101','f3000000-0000-0000-0000-000000000041','PA05F-PO-A','RELEASED_TO_SUPPLIER',1),
  ('f5100000-0000-0000-0000-000000000201','f3000000-0000-0000-0000-000000000041','PA05F-PO-B','RELEASED_TO_SUPPLIER',1);
insert into atlas_procurement.purchase_order_revisions (
  purchase_order_revision_id,purchase_order_id,revision_number,revision_status,
  is_current,service_date,delivery_location_id,supplier_name_snapshot,
  delivery_location_snapshot,released_by_actor_id,released_at
) values
  ('f5110000-0000-0000-0000-000000000101','f5100000-0000-0000-0000-000000000101',1,'RELEASED_TO_SUPPLIER',true,date '2026-07-16','f3000000-0000-0000-0000-000000000011','PA-05F Supplier','PA-05F Location A','f0000000-0000-0000-0000-000000000001',timestamptz '2026-07-16 00:07:00+00'),
  ('f5110000-0000-0000-0000-000000000201','f5100000-0000-0000-0000-000000000201',1,'RELEASED_TO_SUPPLIER',true,date '2026-07-16','f3000000-0000-0000-0000-000000000012','PA-05F Supplier','PA-05F Location B','f0000000-0000-0000-0000-000000000001',timestamptz '2026-07-16 00:07:00+00');
insert into atlas_procurement.purchase_order_lines (
  purchase_order_line_id,purchase_order_id,fulfilment_allocation_line_id
) values
  ('f5120000-0000-0000-0000-000000000101','f5100000-0000-0000-0000-000000000101','f5020000-0000-0000-0000-000000000101'),
  ('f5120000-0000-0000-0000-000000000201','f5100000-0000-0000-0000-000000000201','f5020000-0000-0000-0000-000000000201');
insert into atlas_procurement.purchase_order_line_revisions (
  purchase_order_line_revision_id,purchase_order_revision_id,
  purchase_order_line_id,fulfilment_allocation_line_revision_id,ingredient_id,
  ordered_quantity,unit_id,delivery_location_id,service_date
) values
  ('f5130000-0000-0000-0000-000000000101','f5110000-0000-0000-0000-000000000101','f5120000-0000-0000-0000-000000000101','f5030000-0000-0000-0000-000000000101','f3000000-0000-0000-0000-000000000031',10,'f3000000-0000-0000-0000-000000000021','f3000000-0000-0000-0000-000000000011',date '2026-07-16'),
  ('f5130000-0000-0000-0000-000000000201','f5110000-0000-0000-0000-000000000201','f5120000-0000-0000-0000-000000000201','f5030000-0000-0000-0000-000000000201','f3000000-0000-0000-0000-000000000031',20,'f3000000-0000-0000-0000-000000000021','f3000000-0000-0000-0000-000000000012',date '2026-07-16');

insert into atlas_evidence.supplier_receiving_evidence (
  supplier_receiving_evidence_id,supplier_id,purchase_order_line_revision_id,
  ingredient_id,evidence_reference,evidence_quantity,unit_id,evidence_status,
  occurred_at,recorded_by_actor_id,command_id,correlation_id
) values
  ('f6000000-0000-0000-0000-000000000101','f3000000-0000-0000-0000-000000000041','f5130000-0000-0000-0000-000000000101','f3000000-0000-0000-0000-000000000031','PA05F-EV-A',10,'f3000000-0000-0000-0000-000000000021','VALID',timestamptz '2026-07-16 00:08:00+00','f0000000-0000-0000-0000-000000000001','f9000000-0000-0000-0000-000000000301','f9000000-0000-0000-0000-000000000001'),
  ('f6000000-0000-0000-0000-000000000201','f3000000-0000-0000-0000-000000000041','f5130000-0000-0000-0000-000000000201','f3000000-0000-0000-0000-000000000031','PA05F-EV-B',20,'f3000000-0000-0000-0000-000000000021','VALID',timestamptz '2026-07-16 00:08:00+00','f0000000-0000-0000-0000-000000000001','f9000000-0000-0000-0000-000000000302','f9000000-0000-0000-0000-000000000001');
insert into atlas_evidence.evidence_applications (
  evidence_application_id,supplier_receiving_evidence_id,
  fulfilment_allocation_line_revision_id,applied_quantity,unit_id,
  application_status,occurred_at,recorded_by_actor_id,command_id,correlation_id
) values
  ('f6100000-0000-0000-0000-000000000101','f6000000-0000-0000-0000-000000000101','f5030000-0000-0000-0000-000000000101',10,'f3000000-0000-0000-0000-000000000021','VALID',timestamptz '2026-07-16 00:09:00+00','f0000000-0000-0000-0000-000000000001','f9000000-0000-0000-0000-000000000311','f9000000-0000-0000-0000-000000000001'),
  ('f6100000-0000-0000-0000-000000000201','f6000000-0000-0000-0000-000000000201','f5030000-0000-0000-0000-000000000201',20,'f3000000-0000-0000-0000-000000000021','VALID',timestamptz '2026-07-16 00:09:00+00','f0000000-0000-0000-0000-000000000001','f9000000-0000-0000-0000-000000000312','f9000000-0000-0000-0000-000000000001');

select ok(
  atlas_core.pa_05f_dispatch_pair_is_ready('f4410000-0000-0000-0000-000000000101','f5010000-0000-0000-0000-000000000101')
  and atlas_core.pa_05f_dispatch_pair_is_ready('f4410000-0000-0000-0000-000000000201','f5010000-0000-0000-0000-000000000201'),
  'both exact PA-05D/PA-05E/PO/Evidence pairs satisfy readiness'
);
update atlas_evidence.evidence_applications set applied_quantity=19
where evidence_application_id='f6100000-0000-0000-0000-000000000201';
select ok(
  not atlas_core.pa_05f_dispatch_pair_is_ready('f4410000-0000-0000-0000-000000000201','f5010000-0000-0000-0000-000000000201'),
  'partial current Evidence application coverage fails readiness'
);
update atlas_evidence.evidence_applications set applied_quantity=20
where evidence_application_id='f6100000-0000-0000-0000-000000000201';
update atlas_evidence.supplier_receiving_evidence set evidence_quantity=19
where supplier_receiving_evidence_id='f6000000-0000-0000-0000-000000000201';
select ok(
  not atlas_core.pa_05f_dispatch_pair_is_ready('f4410000-0000-0000-0000-000000000201','f5010000-0000-0000-0000-000000000201'),
  'source Evidence over-application fails readiness'
);
update atlas_evidence.supplier_receiving_evidence set evidence_quantity=20
where supplier_receiving_evidence_id='f6000000-0000-0000-0000-000000000201';
update atlas_evidence.supplier_receiving_evidence
set purchase_order_line_revision_id='f5130000-0000-0000-0000-000000000101'
where supplier_receiving_evidence_id='f6000000-0000-0000-0000-000000000201';
select ok(
  not atlas_core.pa_05f_dispatch_pair_is_ready('f4410000-0000-0000-0000-000000000201','f5010000-0000-0000-0000-000000000201'),
  'cross-wired Evidence source and purchase-order line fail readiness'
);
update atlas_evidence.supplier_receiving_evidence
set purchase_order_line_revision_id='f5130000-0000-0000-0000-000000000201'
where supplier_receiving_evidence_id='f6000000-0000-0000-0000-000000000201';

create temporary table pa05f_results (
  result_name text primary key,
  response_payload jsonb not null
);
grant select,insert,update on pa05f_results to authenticated;

create function pg_temp.pa05f_request(
  command_id uuid,
  idempotency_key text,
  expected_version bigint,
  subject uuid,
  payload jsonb
) returns jsonb language sql immutable set search_path='' as $$
  select pg_catalog.jsonb_build_object(
    'contract_version','PA-05F.v1','command_id',command_id,
    'correlation_id','f9000000-0000-0000-0000-000000000001'::uuid,
    'idempotency_key',idempotency_key,'expected_version',expected_version,
    'requested_by_auth_subject',subject,
    'requested_at','2026-07-16T00:00:00+00:00',
    'reason_code','PA05F_TEST','reason_note','PA-05F pgTAP',
    'payload',payload
  )
$$;
create function pg_temp.pa05f_plan_payload(plan_reference text)
returns jsonb language sql immutable set search_path='' as $$
  select pg_catalog.jsonb_build_object(
    'plan_reference',plan_reference,'dispatch_wave','MORNING',
    'requirements',pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'dispatch_requirement_revision_id','f4410000-0000-0000-0000-000000000101',
        'fulfilment_allocation_revision_id','f5010000-0000-0000-0000-000000000101',
        'expected_dispatch_requirement_version',1,
        'expected_fulfilment_allocation_version',1
      ),
      pg_catalog.jsonb_build_object(
        'dispatch_requirement_revision_id','f4410000-0000-0000-0000-000000000201',
        'fulfilment_allocation_revision_id','f5010000-0000-0000-0000-000000000201',
        'expected_dispatch_requirement_version',1,
        'expected_fulfilment_allocation_version',1
      )
    )
  )
$$;

update atlas_planning.dispatch_requirements set service_date=date '2026-07-17'
where dispatch_requirement_id='f4400000-0000-0000-0000-000000000201';
set local role authenticated;
select set_config('request.jwt.claim.sub','f0000000-0000-0000-0000-000000000101',true);
insert into pa05f_results values ('mixed-date',atlas_api.create_dispatch_plan(pg_temp.pa05f_request(
  'f9000000-0000-0000-0000-000000000400','mixed-date',1,
  'f0000000-0000-0000-0000-000000000101',pg_temp.pa05f_plan_payload('PA05F-MIXED')
)));
reset role;
update atlas_planning.dispatch_requirements set service_date=date '2026-07-16'
where dispatch_requirement_id='f4400000-0000-0000-0000-000000000201';

set local role authenticated;
select set_config('request.jwt.claim.sub','f0000000-0000-0000-0000-000000000101',true);
insert into pa05f_results values ('malformed',atlas_api.create_dispatch_plan('{}'::jsonb));
insert into pa05f_results values ('duplicate-pair',atlas_api.create_dispatch_plan(pg_temp.pa05f_request(
  'f9000000-0000-0000-0000-000000000401','duplicate-pair',1,
  'f0000000-0000-0000-0000-000000000101',
  pg_catalog.jsonb_build_object(
    'plan_reference','PA05F-DUP','dispatch_wave',null,
    'requirements',pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'dispatch_requirement_revision_id','f4410000-0000-0000-0000-000000000101',
        'fulfilment_allocation_revision_id','f5010000-0000-0000-0000-000000000101',
        'expected_dispatch_requirement_version',1,'expected_fulfilment_allocation_version',1
      ),
      pg_catalog.jsonb_build_object(
        'dispatch_requirement_revision_id','f4410000-0000-0000-0000-000000000101',
        'fulfilment_allocation_revision_id','f5010000-0000-0000-0000-000000000101',
        'expected_dispatch_requirement_version',1,'expected_fulfilment_allocation_version',1
      )
    )
  )
)));
insert into pa05f_results values ('stale-upstream',atlas_api.create_dispatch_plan(pg_temp.pa05f_request(
  'f9000000-0000-0000-0000-000000000402','stale-upstream',1,
  'f0000000-0000-0000-0000-000000000101',
  jsonb_set(pg_temp.pa05f_plan_payload('PA05F-STALE'),'{requirements,0,expected_dispatch_requirement_version}','2'::jsonb)
)));

select set_config('request.jwt.claim.sub','f0000000-0000-0000-0000-000000000103',true);
insert into pa05f_results values ('scope-denied',atlas_api.create_dispatch_plan(pg_temp.pa05f_request(
  'f9000000-0000-0000-0000-000000000403','scope-denied',1,
  'f0000000-0000-0000-0000-000000000103',pg_temp.pa05f_plan_payload('PA05F-DENIED')
)));

select set_config('request.jwt.claim.sub','f0000000-0000-0000-0000-000000000101',true);
insert into pa05f_results values ('plan',atlas_api.create_dispatch_plan(pg_temp.pa05f_request(
  'f9000000-0000-0000-0000-000000000404','plan-main',1,
  'f0000000-0000-0000-0000-000000000101',pg_temp.pa05f_plan_payload('PA05F-PLAN-1')
)));
insert into pa05f_results values ('plan-replay',atlas_api.create_dispatch_plan(pg_temp.pa05f_request(
  'f9000000-0000-0000-0000-000000000404','plan-main',1,
  'f0000000-0000-0000-0000-000000000101',pg_temp.pa05f_plan_payload('PA05F-PLAN-1')
)));
insert into pa05f_results values ('plan-conflict',atlas_api.create_dispatch_plan(pg_temp.pa05f_request(
  'f9000000-0000-0000-0000-000000000404','plan-main',1,
  'f0000000-0000-0000-0000-000000000101',pg_temp.pa05f_plan_payload('PA05F-PLAN-CHANGED')
)));
insert into pa05f_results values ('plan-duplicate-admission',atlas_api.create_dispatch_plan(pg_temp.pa05f_request(
  'f9000000-0000-0000-0000-000000000405','plan-duplicate-admission',1,
  'f0000000-0000-0000-0000-000000000101',pg_temp.pa05f_plan_payload('PA05F-PLAN-2')
)));
reset role;

select is((select response_payload->>'error_code' from pa05f_results where result_name='malformed'),'VALIDATION_FAILED','malformed envelope fails closed');
select is((select response_payload->>'error_code' from pa05f_results where result_name='mixed-date'),'INVARIANT_VIOLATION','mixed authoritative service dates fail atomically');
select is((select response_payload->>'error_code' from pa05f_results where result_name='duplicate-pair'),'VALIDATION_FAILED','duplicate exact pairs fail validation');
select is((select response_payload->>'error_code' from pa05f_results where result_name='stale-upstream'),'STALE_VERSION','named upstream stale version is rejected');
select is((select response_payload->>'error_code' from pa05f_results where result_name='scope-denied'),'SCOPE_DENIED','every authoritative destination is authorized before receipt');
select is((select count(*)::integer from atlas_core.command_receipts where command_id='f9000000-0000-0000-0000-000000000403'),0,'all-scope denial creates no receipt');
select ok((select (response_payload->>'success')::boolean from pa05f_results where result_name='plan'),'same-date multi-destination plan succeeds');
select is((select response_payload from pa05f_results where result_name='plan-replay'),(select response_payload from pa05f_results where result_name='plan'),'exact plan replay returns original response and IDs');
select is((select response_payload->>'error_code' from pa05f_results where result_name='plan-conflict'),'IDEMPOTENCY_CONFLICT','changed canonical plan request conflicts');
select is((select response_payload->>'error_code' from pa05f_results where result_name='plan-duplicate-admission'),'INVARIANT_VIOLATION','active plan membership cannot be admitted twice');
select is((select count(*)::integer from atlas_dispatch.dispatch_plans),1,'only one Dispatch Plan root is created');
select is((select count(*)::integer from atlas_dispatch.dispatch_plan_requirements),2,'one membership is created per exact selected pair');
select ok(
  (select service_date=date '2026-07-16' and plan_status='PLANNED' and version=1
   from atlas_dispatch.dispatch_plans),
  'plan derives the service date and starts PLANNED at version 1'
);
select is((select count(*)::integer from atlas_audit.domain_events where event_type='DispatchPlanCreated'),1,'plan success emits exactly one domain event');
select is((select count(*)::integer from atlas_audit.audit_events where event_type='DispatchPlanCreated'),1,'plan success emits exactly one audit event');
select is((select count(*)::integer from atlas_evidence.supplier_receiving_evidence),2,'plan creation does not manufacture Evidence');
select is((select count(*)::integer from atlas_evidence.evidence_applications),2,'plan creation does not change Evidence applications');

set local role authenticated;
select set_config('request.jwt.claim.sub','f0000000-0000-0000-0000-000000000101',true);
insert into pa05f_results values ('trip-invalid-driver',atlas_api.create_or_assign_dispatch_trip(pg_temp.pa05f_request(
  'f9000000-0000-0000-0000-000000000501','trip-invalid-driver',1,
  'f0000000-0000-0000-0000-000000000101',
  pg_catalog.jsonb_build_object(
    'dispatch_plan_id',(select response_payload#>>'{affected_aggregate_ids,dispatch_plan_id}' from pa05f_results where result_name='plan'),
    'trip_reference','PA05F-TRIP-INVALID','driver_actor_id','f0000000-0000-0000-0000-000000000004',
    'vehicle_reference',null,'planned_departure_at',null,
    'stops',pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'dispatch_plan_requirement_id',(select response_payload#>>'{affected_aggregate_ids,dispatch_plan_requirement_ids,0}' from pa05f_results where result_name='plan'),
      'stop_sequence',1
    ))
  )
)));
insert into pa05f_results values ('trip-a',atlas_api.create_or_assign_dispatch_trip(pg_temp.pa05f_request(
  'f9000000-0000-0000-0000-000000000502','trip-a',1,
  'f0000000-0000-0000-0000-000000000101',
  pg_catalog.jsonb_build_object(
    'dispatch_plan_id',(select response_payload#>>'{affected_aggregate_ids,dispatch_plan_id}' from pa05f_results where result_name='plan'),
    'trip_reference','PA05F-TRIP-A','driver_actor_id','f0000000-0000-0000-0000-000000000002',
    'vehicle_reference',null,'planned_departure_at','2026-07-16T01:00:00+00:00',
    'stops',pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'dispatch_plan_requirement_id',(select response_payload#>>'{affected_aggregate_ids,dispatch_plan_requirement_ids,0}' from pa05f_results where result_name='plan'),
      'stop_sequence',1
    ))
  )
)));
insert into pa05f_results values ('trip-a-replay',atlas_api.create_or_assign_dispatch_trip(pg_temp.pa05f_request(
  'f9000000-0000-0000-0000-000000000502','trip-a',1,
  'f0000000-0000-0000-0000-000000000101',
  pg_catalog.jsonb_build_object(
    'dispatch_plan_id',(select response_payload#>>'{affected_aggregate_ids,dispatch_plan_id}' from pa05f_results where result_name='plan'),
    'trip_reference','PA05F-TRIP-A','driver_actor_id','f0000000-0000-0000-0000-000000000002',
    'vehicle_reference',null,'planned_departure_at','2026-07-16T01:00:00+00:00',
    'stops',pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'dispatch_plan_requirement_id',(select response_payload#>>'{affected_aggregate_ids,dispatch_plan_requirement_ids,0}' from pa05f_results where result_name='plan'),
      'stop_sequence',1
    ))
  )
)));
insert into pa05f_results values ('trip-a-conflict',atlas_api.create_or_assign_dispatch_trip(pg_temp.pa05f_request(
  'f9000000-0000-0000-0000-000000000502','trip-a',1,
  'f0000000-0000-0000-0000-000000000101',
  pg_catalog.jsonb_build_object(
    'dispatch_plan_id',(select response_payload#>>'{affected_aggregate_ids,dispatch_plan_id}' from pa05f_results where result_name='plan'),
    'trip_reference','PA05F-TRIP-CHANGED','driver_actor_id','f0000000-0000-0000-0000-000000000002',
    'vehicle_reference',null,'planned_departure_at','2026-07-16T01:00:00+00:00',
    'stops',pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'dispatch_plan_requirement_id',(select response_payload#>>'{affected_aggregate_ids,dispatch_plan_requirement_ids,0}' from pa05f_results where result_name='plan'),
      'stop_sequence',1
    ))
  )
)));
reset role;

update atlas_evidence.supplier_receiving_evidence
set evidence_status='VOIDED'
where supplier_receiving_evidence_id='f6000000-0000-0000-0000-000000000201';

set local role authenticated;
select set_config('request.jwt.claim.sub','f0000000-0000-0000-0000-000000000101',true);
insert into pa05f_results values ('trip-b-voided-evidence',atlas_api.create_or_assign_dispatch_trip(pg_temp.pa05f_request(
  'f9000000-0000-0000-0000-000000000503','trip-b-voided-evidence',2,
  'f0000000-0000-0000-0000-000000000101',
  pg_catalog.jsonb_build_object(
    'dispatch_plan_id',(select response_payload#>>'{affected_aggregate_ids,dispatch_plan_id}' from pa05f_results where result_name='plan'),
    'trip_reference','PA05F-TRIP-B-VOID','driver_actor_id',null,
    'vehicle_reference','TRUCK-B','planned_departure_at',null,
    'stops',pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'dispatch_plan_requirement_id',(select response_payload#>>'{affected_aggregate_ids,dispatch_plan_requirement_ids,1}' from pa05f_results where result_name='plan'),
      'stop_sequence',1
    ))
  )
)));
reset role;

update atlas_evidence.supplier_receiving_evidence
set evidence_status='VALID'
where supplier_receiving_evidence_id='f6000000-0000-0000-0000-000000000201';

set local role authenticated;
select set_config('request.jwt.claim.sub','f0000000-0000-0000-0000-000000000101',true);
insert into pa05f_results values ('trip-b',atlas_api.create_or_assign_dispatch_trip(pg_temp.pa05f_request(
  'f9000000-0000-0000-0000-000000000504','trip-b',2,
  'f0000000-0000-0000-0000-000000000101',
  pg_catalog.jsonb_build_object(
    'dispatch_plan_id',(select response_payload#>>'{affected_aggregate_ids,dispatch_plan_id}' from pa05f_results where result_name='plan'),
    'trip_reference','PA05F-TRIP-B','driver_actor_id',null,
    'vehicle_reference','TRUCK-B','planned_departure_at',null,
    'stops',pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'dispatch_plan_requirement_id',(select response_payload#>>'{affected_aggregate_ids,dispatch_plan_requirement_ids,1}' from pa05f_results where result_name='plan'),
      'stop_sequence',1
    ))
  )
)));
insert into pa05f_results values ('trip-duplicate-membership',atlas_api.create_or_assign_dispatch_trip(pg_temp.pa05f_request(
  'f9000000-0000-0000-0000-000000000505','trip-duplicate-membership',3,
  'f0000000-0000-0000-0000-000000000101',
  pg_catalog.jsonb_build_object(
    'dispatch_plan_id',(select response_payload#>>'{affected_aggregate_ids,dispatch_plan_id}' from pa05f_results where result_name='plan'),
    'trip_reference','PA05F-TRIP-DUP','driver_actor_id',null,
    'vehicle_reference','TRUCK-DUP','planned_departure_at',null,
    'stops',pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'dispatch_plan_requirement_id',(select response_payload#>>'{affected_aggregate_ids,dispatch_plan_requirement_ids,0}' from pa05f_results where result_name='plan'),
      'stop_sequence',1
    ))
  )
)));
reset role;

select is((select response_payload->>'error_code' from pa05f_results where result_name='trip-invalid-driver'),'VALIDATION_FAILED','invalid driver type is rejected before receipt');
select is((select count(*)::integer from atlas_core.command_receipts where command_id='f9000000-0000-0000-0000-000000000501'),0,'invalid driver creates no receipt');
select ok((select (response_payload->>'success')::boolean from pa05f_results where result_name='trip-a'),'first disjoint membership is assigned successfully');
select is((select response_payload from pa05f_results where result_name='trip-a-replay'),(select response_payload from pa05f_results where result_name='trip-a'),'exact trip replay returns original response and IDs');
select is((select response_payload->>'error_code' from pa05f_results where result_name='trip-a-conflict'),'IDEMPOTENCY_CONFLICT','changed canonical trip request conflicts');
select is((select response_payload->>'error_code' from pa05f_results where result_name='trip-b-voided-evidence'),'INVARIANT_VIOLATION','evidence invalidated after planning blocks trip assignment');
select is((select response_payload#>>'{current_version}' from pa05f_results where result_name='trip-b-voided-evidence'),null,'evidence failure does not masquerade as a stale version');
select ok((select (response_payload->>'success')::boolean from pa05f_results where result_name='trip-b'),'second disjoint membership creates a second assigned trip');
select is((select response_payload->>'error_code' from pa05f_results where result_name='trip-duplicate-membership'),'INVARIANT_VIOLATION','one active membership cannot be assigned to two trips');
select is((select count(*)::integer from atlas_dispatch.dispatch_trips),2,'exactly two disjoint assigned trips exist');
select is((select count(*)::integer from atlas_dispatch.dispatch_stops),2,'each selected membership creates one exact stop');
select ok(
  not exists (
    select 1 from atlas_dispatch.dispatch_stops ds
    join atlas_planning.dispatch_requirement_revisions drr using (dispatch_requirement_revision_id)
    join atlas_planning.dispatch_requirements dr using (dispatch_requirement_id)
    where ds.customer_id<>dr.customer_id or ds.delivery_location_id<>dr.delivery_location_id
      or ds.stop_status<>'PENDING' or ds.version<>1
      or ds.planned_window_start is not null or ds.planned_window_end is not null
  ),
  'stops derive exact Planning destinations and start PENDING at version 1 without windows'
);
select is((select version from atlas_dispatch.dispatch_plans),3::bigint,'each successful trip increments the plan exactly once');
select is((select count(*)::integer from atlas_audit.domain_events where event_type='DispatchTripAssigned'),2,'each first trip success emits one domain event');
select is((select count(*)::integer from atlas_audit.audit_events where event_type='DispatchTripAssigned'),2,'each first trip success emits one audit event');
select is((select count(*)::integer from atlas_core.command_receipts where command_name='create_dispatch_plan' and outcome='COMPLETED'),1,'plan replay creates only one completed receipt');
select is((select count(*)::integer from atlas_core.command_receipts where command_name='create_or_assign_dispatch_trip' and outcome='COMPLETED'),2,'trip replay creates only one receipt per first success');
select is((select count(*)::integer from atlas_dispatch.dispatch_loads),0,'PA-05F creates no load facts');
select is((select count(*)::integer from atlas_evidence.supplier_receiving_evidence),2,'PA-05F leaves source Evidence cardinality unchanged');
select is((select count(*)::integer from atlas_evidence.evidence_applications),2,'PA-05F leaves Evidence application cardinality unchanged');

select * from finish();
rollback;
