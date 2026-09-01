begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
select plan(74);

grant usage on schema extensions to authenticated;
grant execute on all functions in schema extensions to authenticated;

select ok(
  not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    join pg_roles r on r.oid = p.proowner
    where n.nspname = 'atlas_api'
      and p.proname in ('allocate_supplier_direct_fulfilment', 'release_supplier_purchase_order')
      and (
        r.rolname <> 'atlas_procurement_command_runtime'
        or not p.prosecdef
        or p.provolatile <> 'v'
        or p.proconfig is null
        or p.proconfig::text not like '%search_path=%'
      )
  ),
  'both PA-05E functions are hardened volatile definers owned by Procurement runtime'
);

select ok(
  not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
      and p.proname in ('allocate_supplier_direct_fulfilment', 'release_supplier_purchase_order')
      and pg_get_functiondef(p.oid) ~* '\\mexecute\\M'
  ),
  'PA-05E functions contain no dynamic SQL'
);

select ok(
  exists (
    select 1 from pg_roles
    where rolname = 'atlas_procurement_command_runtime' and not rolcanlogin and not rolinherit
  ),
  'Procurement runtime is NOLOGIN and NOINHERIT'
);

select is(
  (
    select array_agg(p.proname order by p.proname)
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    join pg_roles r on r.oid = p.proowner
    where n.nspname = 'atlas_api'
      and p.proname in ('allocate_supplier_direct_fulfilment', 'release_supplier_purchase_order')
      and pg_get_function_identity_arguments(p.oid) = 'request jsonb'
      and r.rolname = 'atlas_procurement_command_runtime'
      and p.prosecdef
      and p.provolatile = 'v'
      and p.proconfig is not null
      and p.proconfig::text like '%search_path=%'
  ),
  array['allocate_supplier_direct_fulfilment', 'release_supplier_purchase_order']::name[],
  'Procurement runtime retains both hardened PA-05E entry functions'
);

select ok(
  not has_schema_privilege('atlas_procurement_command_runtime', 'atlas_api', 'CREATE')
  and not exists (
    select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname like 'atlas\_%' escape '\' and c.relkind = 'S'
      and (
        has_sequence_privilege('atlas_procurement_command_runtime', c.oid, 'USAGE')
        or has_sequence_privilege('atlas_procurement_command_runtime', c.oid, 'UPDATE')
      )
  ),
  'Procurement runtime has no Atlas schema CREATE or sequence mutation privilege'
);

select ok(
  not has_schema_privilege('atlas_procurement_command_runtime', 'atlas_evidence', 'USAGE')
  and not has_schema_privilege('atlas_procurement_command_runtime', 'atlas_dispatch', 'USAGE')
  and not has_schema_privilege('atlas_procurement_command_runtime', 'atlas_reporting', 'USAGE')
  and not has_table_privilege('atlas_procurement_command_runtime', 'atlas_planning.dispatch_requirements', 'INSERT')
  and not has_table_privilege('atlas_procurement_command_runtime', 'atlas_planning.dispatch_requirements', 'DELETE')
  and not exists (
    select 1 from pg_policy p
    join pg_class c on c.oid = p.polrelid
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'atlas_planning' and c.relname = 'dispatch_requirements'
      and p.polcmd = 'w'
      and p.polroles && array[(select oid from pg_roles where rolname='atlas_procurement_command_runtime')]
  )
  and not has_table_privilege('atlas_procurement_command_runtime', 'atlas_evidence.supplier_receiving_evidence', 'INSERT')
  and not has_table_privilege('atlas_procurement_command_runtime', 'atlas_dispatch.dispatch_plans', 'INSERT'),
  'Procurement runtime cannot manufacture or mutate Planning, Evidence, Dispatch, or reporting facts'
);

select ok(
  not has_table_privilege('atlas_planning_command_runtime','atlas_procurement.fulfilment_allocations','INSERT')
  and not has_table_privilege('atlas_evidence_command_runtime','atlas_procurement.fulfilment_allocations','INSERT')
  and not has_table_privilege('atlas_dispatch_command_runtime','atlas_procurement.fulfilment_allocations','INSERT')
  and not has_table_privilege('atlas_read_runtime','atlas_procurement.fulfilment_allocations','INSERT')
  and not has_table_privilege('atlas_planning_command_runtime','atlas_procurement.purchase_orders','INSERT')
  and not has_table_privilege('atlas_evidence_command_runtime','atlas_procurement.purchase_orders','INSERT')
  and not has_table_privilege('atlas_dispatch_command_runtime','atlas_procurement.purchase_orders','INSERT')
  and not has_table_privilege('atlas_read_runtime','atlas_procurement.purchase_orders','INSERT'),
  'other Atlas runtimes cannot manufacture PA-05E Procurement facts'
);

select ok(
  not exists (
    select 1 from pg_policy p
    join pg_class c on c.oid=p.polrelid
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='atlas_procurement'
      and c.relname in (
        'fulfilment_allocations',
        'fulfilment_allocation_revisions',
        'fulfilment_allocation_lines',
        'fulfilment_allocation_line_revisions',
        'purchase_order_lines',
        'purchase_order_line_revisions'
      )
      and p.polcmd in ('w','d')
      and p.polroles && array[(select oid from pg_roles where rolname='atlas_procurement_command_runtime')]
  )
  and not exists (
    select 1 from pg_policy p
    join pg_class c on c.oid=p.polrelid
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='atlas_procurement'
      and c.relname in ('purchase_orders','purchase_order_revisions')
      and p.polcmd='d'
      and p.polroles && array[(select oid from pg_roles where rolname='atlas_procurement_command_runtime')]
  )
  and (
    select array_agg(p.polname order by p.polname)
    from pg_policy p
    where p.polrelid in (
      'atlas_procurement.purchase_orders'::regclass,
      'atlas_procurement.purchase_order_revisions'::regclass
    )
      and p.polcmd='w'
      and p.polroles && array[(select oid from pg_roles where rolname='atlas_procurement_command_runtime')]
  )=array['school_catering_po_revision_update','school_catering_po_root_update']::name[]
  and not exists (
    select 1 from pg_policy p
    where p.polname in ('school_catering_po_revision_update','school_catering_po_root_update')
      and (
        pg_get_expr(p.polqual,p.polrelid) not ilike '%SCHOOL_CATERING%'
        or pg_get_expr(p.polwithcheck,p.polrelid) not ilike '%SCHOOL_CATERING%'
      )
  ),
  'Procurement runtime update policies are limited to school-catering PO lifecycle facts'
);

select ok(
  exists (
    select 1 from pg_indexes
    where schemaname = 'atlas_procurement'
      and indexname = 'purchase_order_lines_allocation_line_key'
      and indexdef ilike '%unique%'
  )
  and (
    select position('for update' in lower(pg_get_functiondef(p.oid))) > 0
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api' and p.proname = 'allocate_supplier_direct_fulfilment'
  )
  and (
    select pg_get_functiondef(p.oid) ~* 'pg_advisory_xact_lock'
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api' and p.proname = 'release_supplier_purchase_order'
  ),
  'allocation and PO race safety combine deterministic locks with narrow uniqueness'
);

insert into atlas_core.actors (actor_id, actor_type, display_name, actor_status, deactivated_at) values
  ('e0000000-0000-0000-0000-000000000001','HUMAN','PA-05E operator','ACTIVE',null),
  ('e0000000-0000-0000-0000-000000000002','HUMAN','PA-05E no capability','ACTIVE',null),
  ('e0000000-0000-0000-0000-000000000003','HUMAN','PA-05E wrong scope','ACTIVE',null),
  ('e0000000-0000-0000-0000-000000000004','HUMAN','PA-05E inactive actor','INACTIVE',timestamptz '2026-07-15 00:00:00+00'),
  ('e0000000-0000-0000-0000-000000000005','HUMAN','PA-05E revoked subject','ACTIVE',null);

insert into atlas_core.actor_auth_subjects (actor_id, auth_subject_id, subject_status, revoked_at) values
  ('e0000000-0000-0000-0000-000000000001','e0000000-0000-0000-0000-000000000101','ACTIVE',null),
  ('e0000000-0000-0000-0000-000000000002','e0000000-0000-0000-0000-000000000102','ACTIVE',null),
  ('e0000000-0000-0000-0000-000000000003','e0000000-0000-0000-0000-000000000103','ACTIVE',null),
  ('e0000000-0000-0000-0000-000000000004','e0000000-0000-0000-0000-000000000104','ACTIVE',null),
  ('e0000000-0000-0000-0000-000000000005','e0000000-0000-0000-0000-000000000105','REVOKED',timestamptz '2026-07-15 00:00:00+00');

insert into atlas_core.roles (role_id, role_code, role_name) values
  ('e1000000-0000-0000-0000-000000000001','pa05e.operator','PA-05E operator'),
  ('e1000000-0000-0000-0000-000000000002','pa05e.empty','PA-05E empty');

insert into atlas_core.capabilities (capability_id, capability_code, capability_name, owning_domain) values
  ('e2000000-0000-0000-0000-000000000001','wholesale_source.record','Record wholesale source','PLANNING'),
  ('e2000000-0000-0000-0000-000000000002','wholesale_order.release','Release wholesale order','PLANNING'),
  ('e2000000-0000-0000-0000-000000000003','purchase_handoff.release','Release purchase handoff','PLANNING'),
  ('e2000000-0000-0000-0000-000000000004','dispatch_requirement.release','Release dispatch requirement','PLANNING'),
  ('e2000000-0000-0000-0000-000000000005','supplier_direct_fulfilment.allocate','Allocate supplier-direct fulfilment','PROCUREMENT'),
  ('e2000000-0000-0000-0000-000000000006','supplier_purchase_order.release','Release supplier purchase order','PROCUREMENT');

insert into atlas_core.role_capabilities (role_id, capability_id)
select 'e1000000-0000-0000-0000-000000000001', capability_id
from atlas_core.capabilities where capability_id::text like 'e2000000-0000-0000-0000-00000000000%';

insert into atlas_core.actor_role_memberships (actor_id, role_id) values
  ('e0000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001'),
  ('e0000000-0000-0000-0000-000000000002','e1000000-0000-0000-0000-000000000002'),
  ('e0000000-0000-0000-0000-000000000003','e1000000-0000-0000-0000-000000000001'),
  ('e0000000-0000-0000-0000-000000000004','e1000000-0000-0000-0000-000000000001'),
  ('e0000000-0000-0000-0000-000000000005','e1000000-0000-0000-0000-000000000001');

insert into atlas_admin.customers (customer_id, customer_code, customer_name) values
  ('e3000000-0000-0000-0000-000000000001','pa05e-customer','PA-05E customer'),
  ('e3000000-0000-0000-0000-000000000002','pa05e-other','PA-05E other customer');
insert into atlas_admin.delivery_locations (
  delivery_location_id, customer_id, location_code, location_name, address_text, timezone_name
) values
  ('e3000000-0000-0000-0000-000000000011','e3000000-0000-0000-0000-000000000001','pa05e-location','PA-05E location','PA-05E address','Asia/Bangkok'),
  ('e3000000-0000-0000-0000-000000000012','e3000000-0000-0000-0000-000000000002','pa05e-other-location','PA-05E other location','Other address','Asia/Bangkok');
insert into atlas_admin.units (unit_id, unit_code, unit_name, dimension_code) values
  ('e3000000-0000-0000-0000-000000000021','pa05e-kg','kilogram','mass'),
  ('e3000000-0000-0000-0000-000000000022','pa05e-box','box','count'),
  ('e3000000-0000-0000-0000-000000000023','pa05e-litre','litre','volume');
insert into atlas_admin.ingredients (ingredient_id, ingredient_code, ingredient_name) values
  ('e3000000-0000-0000-0000-000000000031','pa05e-rice','Rice'),
  ('e3000000-0000-0000-0000-000000000032','pa05e-oil','Oil'),
  ('e3000000-0000-0000-0000-000000000033','pa05e-salt','Salt');
insert into atlas_admin.suppliers (supplier_id, supplier_code, supplier_name) values
  ('e3000000-0000-0000-0000-000000000041','pa05e-supplier-a','PA-05E Supplier A'),
  ('e3000000-0000-0000-0000-000000000042','pa05e-supplier-b','PA-05E Supplier B');
insert into atlas_admin.suppliers (supplier_id, supplier_code, supplier_name, supplier_status) values
  ('e3000000-0000-0000-0000-000000000043','pa05e-suspended','PA-05E Suspended','SUSPENDED');

insert into atlas_core.actor_scopes (actor_id, scope_kind, customer_id) values
  ('e0000000-0000-0000-0000-000000000001','CUSTOMER','e3000000-0000-0000-0000-000000000001'),
  ('e0000000-0000-0000-0000-000000000003','CUSTOMER','e3000000-0000-0000-0000-000000000002');
insert into atlas_core.actor_scopes (actor_id, scope_kind) values
  ('e0000000-0000-0000-0000-000000000002','GLOBAL'),
  ('e0000000-0000-0000-0000-000000000004','GLOBAL'),
  ('e0000000-0000-0000-0000-000000000005','GLOBAL');

create temporary table pa05e_results (result_name text primary key, response_payload jsonb not null);
grant select, insert, update on pa05e_results to authenticated;

create function pg_temp.pa05d_request(command_id uuid, idempotency_key text, expected_version bigint, payload jsonb)
returns jsonb language sql immutable set search_path = '' as $$
  select pg_catalog.jsonb_build_object(
    'contract_version','PA-05D.v1','command_id',command_id,
    'correlation_id','e9000000-0000-0000-0000-000000000001'::uuid,
    'idempotency_key',idempotency_key,'expected_version',expected_version,
    'requested_by_auth_subject','e0000000-0000-0000-0000-000000000101'::uuid,
    'requested_at','2026-07-15T00:00:00+00:00','reason_code','PA05E_TEST',
    'reason_note','PA-05E pgTAP predecessor setup','payload',payload
  )
$$;

create function pg_temp.pa05e_request(
  command_id uuid, idempotency_key text, expected_version bigint, subject uuid, payload jsonb
) returns jsonb language sql immutable set search_path = '' as $$
  select pg_catalog.jsonb_build_object(
    'contract_version','PA-05E.v1','command_id',command_id,
    'correlation_id','e9000000-0000-0000-0000-000000000002'::uuid,
    'idempotency_key',idempotency_key,'expected_version',expected_version,
    'requested_by_auth_subject',subject,'requested_at','2026-07-15T00:00:00+00:00',
    'reason_code','PA05E_TEST','reason_note','PA-05E pgTAP','payload',payload
  )
$$;

set local role authenticated;
select set_config('request.jwt.claim.sub','e0000000-0000-0000-0000-000000000101',true);

insert into pa05e_results values ('source', atlas_api.record_wholesale_source(pg_temp.pa05d_request(
  'e9000000-0000-0000-0000-000000000101','source-main',1,
  jsonb_build_object(
    'customer_id','e3000000-0000-0000-0000-000000000001',
    'delivery_location_id','e3000000-0000-0000-0000-000000000011',
    'customer_order_reference','PA05E-ORDER-1','service_date','2026-07-16',
    'lines',jsonb_build_array(
      jsonb_build_object('source_line_number',1,'ingredient_id','e3000000-0000-0000-0000-000000000031','requested_quantity',10,'unit_id','e3000000-0000-0000-0000-000000000021'),
      jsonb_build_object('source_line_number',2,'ingredient_id','e3000000-0000-0000-0000-000000000032','requested_quantity',3,'unit_id','e3000000-0000-0000-0000-000000000022'),
      jsonb_build_object('source_line_number',3,'ingredient_id','e3000000-0000-0000-0000-000000000033','requested_quantity',2,'unit_id','e3000000-0000-0000-0000-000000000021')
    )
  )
)));
insert into pa05e_results values ('release', atlas_api.release_wholesale_order(pg_temp.pa05d_request(
  'e9000000-0000-0000-0000-000000000102','release-main',1,
  jsonb_build_object('wholesale_order_id',(select response_payload #>> '{affected_aggregate_ids,wholesale_order_id}' from pa05e_results where result_name='source'))
)));
insert into pa05e_results values ('handoff', atlas_api.release_purchase_handoff(pg_temp.pa05d_request(
  'e9000000-0000-0000-0000-000000000103','handoff-main',1,
  jsonb_build_object('confirmed_need_batch_id',(select response_payload #>> '{affected_aggregate_ids,confirmed_need_batch_id}' from pa05e_results where result_name='release'))
)));
insert into pa05e_results values ('requirement', atlas_api.release_dispatch_requirement(pg_temp.pa05d_request(
  'e9000000-0000-0000-0000-000000000104','requirement-main',1,
  jsonb_build_object('purchase_handoff_revision_id',(select response_payload #>> '{affected_aggregate_ids,purchase_handoff_revision_id}' from pa05e_results where result_name='handoff'))
)));

insert into pa05e_results values ('source-other', atlas_api.record_wholesale_source(pg_temp.pa05d_request(
  'e9000000-0000-0000-0000-000000000111','source-other',1,
  jsonb_build_object(
    'customer_id','e3000000-0000-0000-0000-000000000001',
    'delivery_location_id','e3000000-0000-0000-0000-000000000011',
    'customer_order_reference','PA05E-ORDER-2','service_date','2026-07-17',
    'lines',jsonb_build_array(
      jsonb_build_object('source_line_number',1,'ingredient_id','e3000000-0000-0000-0000-000000000031','requested_quantity',1,'unit_id','e3000000-0000-0000-0000-000000000021')
    )
  )
)));
insert into pa05e_results values ('release-other', atlas_api.release_wholesale_order(pg_temp.pa05d_request(
  'e9000000-0000-0000-0000-000000000112','release-other',1,
  jsonb_build_object('wholesale_order_id',(select response_payload #>> '{affected_aggregate_ids,wholesale_order_id}' from pa05e_results where result_name='source-other'))
)));
insert into pa05e_results values ('handoff-other', atlas_api.release_purchase_handoff(pg_temp.pa05d_request(
  'e9000000-0000-0000-0000-000000000113','handoff-other',1,
  jsonb_build_object('confirmed_need_batch_id',(select response_payload #>> '{affected_aggregate_ids,confirmed_need_batch_id}' from pa05e_results where result_name='release-other'))
)));
insert into pa05e_results values ('requirement-other', atlas_api.release_dispatch_requirement(pg_temp.pa05d_request(
  'e9000000-0000-0000-0000-000000000114','requirement-other',1,
  jsonb_build_object('purchase_handoff_revision_id',(select response_payload #>> '{affected_aggregate_ids,purchase_handoff_revision_id}' from pa05e_results where result_name='handoff-other'))
)));
reset role;

select ok(
  not exists (
    select 1 from pa05e_results
    where result_name in ('source','release','handoff','requirement','source-other','release-other','handoff-other','requirement-other')
      and coalesce((response_payload ->> 'success')::boolean,false) is not true
  ),
  'real PA-05D predecessor chains are released for PA-05E tests'
);

create function pg_temp.pa05e_allocation_payload(requirement_revision_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  with exact_lines as (
    select drlr.dispatch_requirement_line_revision_id, drlr.required_quantity,
           drlr.unit_id,
           row_number() over (order by drlr.dispatch_requirement_line_revision_id) as line_rank
    from atlas_planning.dispatch_requirement_line_revisions drlr
    join atlas_planning.dispatch_requirement_revisions drr
      on drr.dispatch_requirement_revision_id = drlr.dispatch_requirement_revision_id
    join atlas_planning.dispatch_requirement_lines drl
      on drl.dispatch_requirement_line_id = drlr.dispatch_requirement_line_id
     and drl.dispatch_requirement_id = drr.dispatch_requirement_id
    where drlr.dispatch_requirement_revision_id = requirement_revision_id
  )
  select pg_catalog.jsonb_build_object(
    'dispatch_requirement_revision_id', requirement_revision_id,
    'lines', pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'dispatch_requirement_line_revision_id', dispatch_requirement_line_revision_id,
        'supplier_id', case when line_rank <= 2
          then 'e3000000-0000-0000-0000-000000000041'::uuid
          else 'e3000000-0000-0000-0000-000000000042'::uuid end,
        'allocated_quantity', required_quantity,
        'unit_id', unit_id
      ) order by line_rank
    )
  )
  from exact_lines
$$;

set local role authenticated;
select set_config('request.jwt.claim.sub','e0000000-0000-0000-0000-000000000101',true);

insert into pa05e_results values ('malformed', atlas_api.allocate_supplier_direct_fulfilment('{}'::jsonb));
select set_config('request.jwt.claim.sub','',true);
insert into pa05e_results values ('missing-auth', atlas_api.allocate_supplier_direct_fulfilment(pg_temp.pa05e_request(
  'e9000000-0000-0000-0000-000000000201','missing-auth',1,'e0000000-0000-0000-0000-000000000101',
  pg_temp.pa05e_allocation_payload((select (response_payload #>> '{affected_aggregate_ids,dispatch_requirement_revision_id}')::uuid from pa05e_results where result_name='requirement'))
)));
select set_config('request.jwt.claim.sub','e0000000-0000-0000-0000-000000000102',true);
insert into pa05e_results values ('wrong-capability', atlas_api.allocate_supplier_direct_fulfilment(pg_temp.pa05e_request(
  'e9000000-0000-0000-0000-000000000202','wrong-capability',1,'e0000000-0000-0000-0000-000000000102',
  pg_temp.pa05e_allocation_payload((select (response_payload #>> '{affected_aggregate_ids,dispatch_requirement_revision_id}')::uuid from pa05e_results where result_name='requirement'))
)));
select set_config('request.jwt.claim.sub','e0000000-0000-0000-0000-000000000103',true);
insert into pa05e_results values ('wrong-scope', atlas_api.allocate_supplier_direct_fulfilment(pg_temp.pa05e_request(
  'e9000000-0000-0000-0000-000000000203','wrong-scope',1,'e0000000-0000-0000-0000-000000000103',
  pg_temp.pa05e_allocation_payload((select (response_payload #>> '{affected_aggregate_ids,dispatch_requirement_revision_id}')::uuid from pa05e_results where result_name='requirement'))
)));
select set_config('request.jwt.claim.sub','e0000000-0000-0000-0000-000000000101',true);

insert into pa05e_results values ('subject-mismatch', atlas_api.allocate_supplier_direct_fulfilment(pg_temp.pa05e_request(
  'e9000000-0000-0000-0000-000000000212','subject-mismatch',1,'e0000000-0000-0000-0000-000000000102',
  pg_temp.pa05e_allocation_payload((select (response_payload #>> '{affected_aggregate_ids,dispatch_requirement_revision_id}')::uuid from pa05e_results where result_name='requirement'))
)));
select set_config('request.jwt.claim.sub','e0000000-0000-0000-0000-000000000104',true);
insert into pa05e_results values ('inactive-actor', atlas_api.allocate_supplier_direct_fulfilment(pg_temp.pa05e_request(
  'e9000000-0000-0000-0000-000000000213','inactive-actor',1,'e0000000-0000-0000-0000-000000000104',
  pg_temp.pa05e_allocation_payload((select (response_payload #>> '{affected_aggregate_ids,dispatch_requirement_revision_id}')::uuid from pa05e_results where result_name='requirement'))
)));
select set_config('request.jwt.claim.sub','e0000000-0000-0000-0000-000000000105',true);
insert into pa05e_results values ('inactive-subject', atlas_api.allocate_supplier_direct_fulfilment(pg_temp.pa05e_request(
  'e9000000-0000-0000-0000-000000000214','inactive-subject',1,'e0000000-0000-0000-0000-000000000105',
  pg_temp.pa05e_allocation_payload((select (response_payload #>> '{affected_aggregate_ids,dispatch_requirement_revision_id}')::uuid from pa05e_results where result_name='requirement'))
)));
select set_config('request.jwt.claim.sub','e0000000-0000-0000-0000-000000000101',true);

insert into pa05e_results values ('delegation', atlas_api.allocate_supplier_direct_fulfilment(pg_temp.pa05e_request(
  'e9000000-0000-0000-0000-000000000204','delegation',1,'e0000000-0000-0000-0000-000000000101',
  pg_temp.pa05e_allocation_payload((select (response_payload #>> '{affected_aggregate_ids,dispatch_requirement_revision_id}')::uuid from pa05e_results where result_name='requirement'))
  || jsonb_build_object('delegated_actor_id','e0000000-0000-0000-0000-000000000002')
)));
insert into pa05e_results values ('unknown-envelope', atlas_api.allocate_supplier_direct_fulfilment(
  pg_temp.pa05e_request(
    'e9000000-0000-0000-0000-000000000205','unknown-envelope',1,'e0000000-0000-0000-0000-000000000101',
    pg_temp.pa05e_allocation_payload((select (response_payload #>> '{affected_aggregate_ids,dispatch_requirement_revision_id}')::uuid from pa05e_results where result_name='requirement'))
  ) || jsonb_build_object('unexpected',true)
));
insert into pa05e_results values ('zero-lines', atlas_api.allocate_supplier_direct_fulfilment(pg_temp.pa05e_request(
  'e9000000-0000-0000-0000-000000000215','zero-lines',1,'e0000000-0000-0000-0000-000000000101',
  jsonb_build_object(
    'dispatch_requirement_revision_id',(select response_payload #>> '{affected_aggregate_ids,dispatch_requirement_revision_id}' from pa05e_results where result_name='requirement'),
    'lines','[]'::jsonb
  )
)));
insert into pa05e_results values ('oversized-lines', atlas_api.allocate_supplier_direct_fulfilment(pg_temp.pa05e_request(
  'e9000000-0000-0000-0000-000000000216','oversized-lines',1,'e0000000-0000-0000-0000-000000000101',
  jsonb_set(
    pg_temp.pa05e_allocation_payload((select (response_payload #>> '{affected_aggregate_ids,dispatch_requirement_revision_id}')::uuid from pa05e_results where result_name='requirement')),
    '{lines}',(
      select jsonb_agg(
        pg_temp.pa05e_allocation_payload((select (response_payload #>> '{affected_aggregate_ids,dispatch_requirement_revision_id}')::uuid from pa05e_results where result_name='requirement')) #> '{lines,0}'
      ) from generate_series(1,101)
    )
  )
)));
insert into pa05e_results values ('unknown-line-field', atlas_api.allocate_supplier_direct_fulfilment(pg_temp.pa05e_request(
  'e9000000-0000-0000-0000-000000000217','unknown-line-field',1,'e0000000-0000-0000-0000-000000000101',
  jsonb_set(
    pg_temp.pa05e_allocation_payload((select (response_payload #>> '{affected_aggregate_ids,dispatch_requirement_revision_id}')::uuid from pa05e_results where result_name='requirement')),
    '{lines,0}',
    (pg_temp.pa05e_allocation_payload((select (response_payload #>> '{affected_aggregate_ids,dispatch_requirement_revision_id}')::uuid from pa05e_results where result_name='requirement')) #> '{lines,0}')
      || jsonb_build_object('portion_sequence',1)
  )
)));
insert into pa05e_results values ('inactive-supplier', atlas_api.allocate_supplier_direct_fulfilment(pg_temp.pa05e_request(
  'e9000000-0000-0000-0000-000000000218','inactive-supplier',1,'e0000000-0000-0000-0000-000000000101',
  jsonb_set(
    pg_temp.pa05e_allocation_payload((select (response_payload #>> '{affected_aggregate_ids,dispatch_requirement_revision_id}')::uuid from pa05e_results where result_name='requirement')),
    '{lines,0,supplier_id}',to_jsonb('e3000000-0000-0000-0000-000000000043'::text)
  )
)));
insert into pa05e_results values ('stale', atlas_api.allocate_supplier_direct_fulfilment(pg_temp.pa05e_request(
  'e9000000-0000-0000-0000-000000000206','stale',2,'e0000000-0000-0000-0000-000000000101',
  pg_temp.pa05e_allocation_payload((select (response_payload #>> '{affected_aggregate_ids,dispatch_requirement_revision_id}')::uuid from pa05e_results where result_name='requirement'))
)));
insert into pa05e_results values ('bad-quantity', atlas_api.allocate_supplier_direct_fulfilment(pg_temp.pa05e_request(
  'e9000000-0000-0000-0000-000000000207','bad-quantity',1,'e0000000-0000-0000-0000-000000000101',
  jsonb_set(
    pg_temp.pa05e_allocation_payload((select (response_payload #>> '{affected_aggregate_ids,dispatch_requirement_revision_id}')::uuid from pa05e_results where result_name='requirement')),
    '{lines,0,allocated_quantity}','999'::jsonb
  )
)));
insert into pa05e_results values ('partial-quantity', atlas_api.allocate_supplier_direct_fulfilment(pg_temp.pa05e_request(
  'e9000000-0000-0000-0000-000000000220','partial-quantity',1,'e0000000-0000-0000-0000-000000000101',
  jsonb_set(
    pg_temp.pa05e_allocation_payload((select (response_payload #>> '{affected_aggregate_ids,dispatch_requirement_revision_id}')::uuid from pa05e_results where result_name='requirement')),
    '{lines,0,allocated_quantity}','0.5'::jsonb
  )
)));
insert into pa05e_results values ('bad-unit', atlas_api.allocate_supplier_direct_fulfilment(pg_temp.pa05e_request(
  'e9000000-0000-0000-0000-000000000208','bad-unit',1,'e0000000-0000-0000-0000-000000000101',
  jsonb_set(
    pg_temp.pa05e_allocation_payload((select (response_payload #>> '{affected_aggregate_ids,dispatch_requirement_revision_id}')::uuid from pa05e_results where result_name='requirement')),
    '{lines,0,unit_id}',to_jsonb('e3000000-0000-0000-0000-000000000023'::text)
  )
)));
insert into pa05e_results values ('missing-line', atlas_api.allocate_supplier_direct_fulfilment(pg_temp.pa05e_request(
  'e9000000-0000-0000-0000-000000000209','missing-line',1,'e0000000-0000-0000-0000-000000000101',
  jsonb_set(
    pg_temp.pa05e_allocation_payload((select (response_payload #>> '{affected_aggregate_ids,dispatch_requirement_revision_id}')::uuid from pa05e_results where result_name='requirement')),
    '{lines}',(pg_temp.pa05e_allocation_payload((select (response_payload #>> '{affected_aggregate_ids,dispatch_requirement_revision_id}')::uuid from pa05e_results where result_name='requirement'))->'lines') - 2
  )
)));
insert into pa05e_results values ('duplicate-line', atlas_api.allocate_supplier_direct_fulfilment(pg_temp.pa05e_request(
  'e9000000-0000-0000-0000-000000000210','duplicate-line',1,'e0000000-0000-0000-0000-000000000101',
  jsonb_set(
    pg_temp.pa05e_allocation_payload((select (response_payload #>> '{affected_aggregate_ids,dispatch_requirement_revision_id}')::uuid from pa05e_results where result_name='requirement')),
    '{lines,1,dispatch_requirement_line_revision_id}',
    (pg_temp.pa05e_allocation_payload((select (response_payload #>> '{affected_aggregate_ids,dispatch_requirement_revision_id}')::uuid from pa05e_results where result_name='requirement')) #> '{lines,0,dispatch_requirement_line_revision_id}')
  )
)));
insert into pa05e_results values ('split-line', atlas_api.allocate_supplier_direct_fulfilment(pg_temp.pa05e_request(
  'e9000000-0000-0000-0000-000000000221','split-line',1,'e0000000-0000-0000-0000-000000000101',
  jsonb_set(
    pg_temp.pa05e_allocation_payload((select (response_payload #>> '{affected_aggregate_ids,dispatch_requirement_revision_id}')::uuid from pa05e_results where result_name='requirement')),
    '{lines}',
    (pg_temp.pa05e_allocation_payload((select (response_payload #>> '{affected_aggregate_ids,dispatch_requirement_revision_id}')::uuid from pa05e_results where result_name='requirement'))->'lines')
      || jsonb_build_array(
        jsonb_set(
          pg_temp.pa05e_allocation_payload((select (response_payload #>> '{affected_aggregate_ids,dispatch_requirement_revision_id}')::uuid from pa05e_results where result_name='requirement')) #> '{lines,0}',
          '{supplier_id}',to_jsonb('e3000000-0000-0000-0000-000000000042'::text)
        )
      )
  )
)));
insert into pa05e_results values ('crosswire', atlas_api.allocate_supplier_direct_fulfilment(pg_temp.pa05e_request(
  'e9000000-0000-0000-0000-000000000211','crosswire',1,'e0000000-0000-0000-0000-000000000101',
  jsonb_set(
    pg_temp.pa05e_allocation_payload((select (response_payload #>> '{affected_aggregate_ids,dispatch_requirement_revision_id}')::uuid from pa05e_results where result_name='requirement-other')),
    '{dispatch_requirement_revision_id}',
    to_jsonb((select response_payload #>> '{affected_aggregate_ids,dispatch_requirement_revision_id}' from pa05e_results where result_name='requirement'))
  )
)));

reset role;
insert into atlas_planning.dispatch_requirement_line_revisions (
  dispatch_requirement_line_revision_id, dispatch_requirement_revision_id,
  dispatch_requirement_line_id, purchase_handoff_line_revision_id,
  ingredient_id, required_quantity, unit_id
)
select
  'e6000000-0000-0000-0000-000000000001',
  (select (response_payload #>> '{affected_aggregate_ids,dispatch_requirement_revision_id}')::uuid
   from pa05e_results where result_name='requirement'),
  drlr.dispatch_requirement_line_id, drlr.purchase_handoff_line_revision_id,
  drlr.ingredient_id, drlr.required_quantity, drlr.unit_id
from atlas_planning.dispatch_requirement_line_revisions drlr
where drlr.dispatch_requirement_revision_id = (
  select (response_payload #>> '{affected_aggregate_ids,dispatch_requirement_revision_id}')::uuid
  from pa05e_results where result_name='requirement-other'
);

set local role authenticated;
select set_config('request.jwt.claim.sub','e0000000-0000-0000-0000-000000000101',true);
insert into pa05e_results values ('crosswire-child', atlas_api.allocate_supplier_direct_fulfilment(pg_temp.pa05e_request(
  'e9000000-0000-0000-0000-000000000222','crosswire-child',1,'e0000000-0000-0000-0000-000000000101',
  pg_temp.pa05e_allocation_payload((select (response_payload #>> '{affected_aggregate_ids,dispatch_requirement_revision_id}')::uuid from pa05e_results where result_name='requirement'))
)));
reset role;

select is((select response_payload ->> 'error_code' from pa05e_results where result_name='crosswire-child'),'INVARIANT_VIOLATION','allocation rejects an extra selected-revision child cross-wired to another requirement root');
select ok(
  (select count(*) = 0 from atlas_procurement.fulfilment_allocations)
  and not exists (select 1 from atlas_audit.domain_events where command_id='e9000000-0000-0000-0000-000000000222')
  and not exists (select 1 from atlas_audit.audit_events where command_id='e9000000-0000-0000-0000-000000000222'),
  'cross-wired requirement child creates no allocation, Procurement domain event, or audit event'
);

delete from atlas_planning.dispatch_requirement_line_revisions
where dispatch_requirement_line_revision_id='e6000000-0000-0000-0000-000000000001';

update atlas_planning.dispatch_requirements
set requirement_status='DRAFT'
where dispatch_requirement_id=(
  select (response_payload #>> '{affected_aggregate_ids,dispatch_requirement_id}')::uuid
  from pa05e_results where result_name='requirement-other'
);
set local role authenticated;
select set_config('request.jwt.claim.sub','e0000000-0000-0000-0000-000000000101',true);
insert into pa05e_results values ('wrong-lifecycle', atlas_api.allocate_supplier_direct_fulfilment(pg_temp.pa05e_request(
  'e9000000-0000-0000-0000-000000000219','wrong-lifecycle',1,'e0000000-0000-0000-0000-000000000101',
  pg_temp.pa05e_allocation_payload((select (response_payload #>> '{affected_aggregate_ids,dispatch_requirement_revision_id}')::uuid from pa05e_results where result_name='requirement-other'))
)));

insert into pa05e_results values ('allocate', atlas_api.allocate_supplier_direct_fulfilment(pg_temp.pa05e_request(
  'e9000000-0000-0000-0000-000000000301','allocate-main',1,'e0000000-0000-0000-0000-000000000101',
  pg_temp.pa05e_allocation_payload((select (response_payload #>> '{affected_aggregate_ids,dispatch_requirement_revision_id}')::uuid from pa05e_results where result_name='requirement'))
)));
insert into pa05e_results values ('allocate-replay', atlas_api.allocate_supplier_direct_fulfilment(pg_temp.pa05e_request(
  'e9000000-0000-0000-0000-000000000301','allocate-main',1,'e0000000-0000-0000-0000-000000000101',
  pg_temp.pa05e_allocation_payload((select (response_payload #>> '{affected_aggregate_ids,dispatch_requirement_revision_id}')::uuid from pa05e_results where result_name='requirement'))
)));
insert into pa05e_results values ('allocate-conflict', atlas_api.allocate_supplier_direct_fulfilment(pg_temp.pa05e_request(
  'e9000000-0000-0000-0000-000000000301','allocate-main',1,'e0000000-0000-0000-0000-000000000101',
  jsonb_set(
    pg_temp.pa05e_allocation_payload((select (response_payload #>> '{affected_aggregate_ids,dispatch_requirement_revision_id}')::uuid from pa05e_results where result_name='requirement')),
    '{lines,0,allocated_quantity}','999'::jsonb
  )
)));
insert into pa05e_results values ('allocate-duplicate', atlas_api.allocate_supplier_direct_fulfilment(pg_temp.pa05e_request(
  'e9000000-0000-0000-0000-000000000302','allocate-duplicate',1,'e0000000-0000-0000-0000-000000000101',
  pg_temp.pa05e_allocation_payload((select (response_payload #>> '{affected_aggregate_ids,dispatch_requirement_revision_id}')::uuid from pa05e_results where result_name='requirement'))
)));

reset role;
select is((select count(*)::integer from atlas_procurement.purchase_orders),0,'allocation creates no purchase order fact');
select is((select count(*)::integer from atlas_evidence.supplier_receiving_evidence),0,'allocation creates no Evidence fact');
select is((select count(*)::integer from atlas_dispatch.dispatch_plans),0,'allocation creates no Dispatch execution fact');

update atlas_planning.dispatch_requirements
set requirement_status='RELEASED'
where dispatch_requirement_id=(
  select (response_payload #>> '{affected_aggregate_ids,dispatch_requirement_id}')::uuid
  from pa05e_results where result_name='requirement-other'
);

insert into atlas_procurement.fulfilment_allocations (
  fulfilment_allocation_id, dispatch_requirement_id, allocation_status, version
) values (
  'e7000000-0000-0000-0000-000000000001',
  (select (response_payload #>> '{affected_aggregate_ids,dispatch_requirement_id}')::uuid
   from pa05e_results where result_name='requirement-other'),
  'READY_FOR_DISPATCH', 1
);
insert into atlas_procurement.fulfilment_allocation_revisions (
  fulfilment_allocation_revision_id, fulfilment_allocation_id, revision_number,
  revision_kind, revision_status, is_current, allocated_by_actor_id
) values (
  'e7000000-0000-0000-0000-000000000002',
  'e7000000-0000-0000-0000-000000000001', 1, 'BASE',
  'READY_FOR_DISPATCH', true, 'e0000000-0000-0000-0000-000000000001'
);
insert into atlas_procurement.fulfilment_allocation_lines (
  fulfilment_allocation_line_id, fulfilment_allocation_id,
  dispatch_requirement_line_id, portion_sequence
)
select
  'e7000000-0000-0000-0000-000000000003',
  'e7000000-0000-0000-0000-000000000001',
  drlr.dispatch_requirement_line_id, 1
from atlas_planning.dispatch_requirement_line_revisions drlr
where drlr.dispatch_requirement_revision_id=(
  select (response_payload #>> '{affected_aggregate_ids,dispatch_requirement_revision_id}')::uuid
  from pa05e_results where result_name='requirement-other'
);
insert into atlas_procurement.fulfilment_allocation_line_revisions (
  fulfilment_allocation_line_revision_id, fulfilment_allocation_revision_id,
  fulfilment_allocation_line_id, dispatch_requirement_line_revision_id,
  fulfilment_source_type, supplier_id, allocated_quantity, unit_id, line_status
)
select
  'e7000000-0000-0000-0000-000000000004',
  'e7000000-0000-0000-0000-000000000002',
  'e7000000-0000-0000-0000-000000000003',
  drlr.dispatch_requirement_line_revision_id, 'SUPPLIER_PO',
  'e3000000-0000-0000-0000-000000000041', drlr.required_quantity,
  drlr.unit_id, 'READY_FOR_EVIDENCE'
from atlas_planning.dispatch_requirement_line_revisions drlr
where drlr.dispatch_requirement_revision_id=(
  select (response_payload #>> '{affected_aggregate_ids,dispatch_requirement_revision_id}')::uuid
  from pa05e_results where result_name='requirement-other'
);
insert into atlas_procurement.fulfilment_allocation_line_revisions (
  fulfilment_allocation_line_revision_id, fulfilment_allocation_revision_id,
  fulfilment_allocation_line_id, dispatch_requirement_line_revision_id,
  fulfilment_source_type, supplier_id, allocated_quantity, unit_id, line_status
)
select
  'e7000000-0000-0000-0000-000000000005',
  (select (response_payload #>> '{affected_aggregate_ids,fulfilment_allocation_revision_id}')::uuid
   from pa05e_results where result_name='allocate'),
  'e7000000-0000-0000-0000-000000000003',
  drlr.dispatch_requirement_line_revision_id, 'SUPPLIER_PO',
  'e3000000-0000-0000-0000-000000000041', drlr.required_quantity,
  drlr.unit_id, 'READY_FOR_EVIDENCE'
from atlas_planning.dispatch_requirement_line_revisions drlr
where drlr.dispatch_requirement_revision_id=(
  select (response_payload #>> '{affected_aggregate_ids,dispatch_requirement_revision_id}')::uuid
  from pa05e_results where result_name='requirement-other'
);

set local role authenticated;
select set_config('request.jwt.claim.sub','e0000000-0000-0000-0000-000000000101',true);

insert into pa05e_results values ('po-crosswire-child', atlas_api.release_supplier_purchase_order(pg_temp.pa05e_request(
  'e9000000-0000-0000-0000-000000000407','po-crosswire-child',1,'e0000000-0000-0000-0000-000000000101',
  jsonb_build_object(
    'fulfilment_allocation_revision_id',(select response_payload #>> '{affected_aggregate_ids,fulfilment_allocation_revision_id}' from pa05e_results where result_name='allocate'),
    'supplier_id','e3000000-0000-0000-0000-000000000041','document_number','PA05E-PO-CROSSWIRE'
  )
)));
reset role;

select is((select response_payload ->> 'error_code' from pa05e_results where result_name='po-crosswire-child'),'INVARIANT_VIOLATION','PO release rejects an extra selected-revision allocation child cross-wired to another allocation root');
select ok(
  (select count(*) = 0 from atlas_procurement.purchase_orders)
  and (select count(*) = 0 from atlas_procurement.purchase_order_revisions)
  and (select count(*) = 0 from atlas_procurement.purchase_order_lines)
  and (select count(*) = 0 from atlas_procurement.purchase_order_line_revisions)
  and not exists (select 1 from atlas_audit.domain_events where command_id='e9000000-0000-0000-0000-000000000407')
  and not exists (select 1 from atlas_audit.audit_events where command_id='e9000000-0000-0000-0000-000000000407'),
  'cross-wired allocation child creates no PO root, revision, line, domain event, or audit event'
);

delete from atlas_procurement.fulfilment_allocation_line_revisions
where fulfilment_allocation_line_revision_id in (
  'e7000000-0000-0000-0000-000000000005',
  'e7000000-0000-0000-0000-000000000004'
);
delete from atlas_procurement.fulfilment_allocation_lines
where fulfilment_allocation_line_id='e7000000-0000-0000-0000-000000000003';
delete from atlas_procurement.fulfilment_allocation_revisions
where fulfilment_allocation_revision_id='e7000000-0000-0000-0000-000000000002';
delete from atlas_procurement.fulfilment_allocations
where fulfilment_allocation_id='e7000000-0000-0000-0000-000000000001';

set local role authenticated;
select set_config('request.jwt.claim.sub','e0000000-0000-0000-0000-000000000101',true);

insert into pa05e_results values ('po-caller-lines', atlas_api.release_supplier_purchase_order(pg_temp.pa05e_request(
  'e9000000-0000-0000-0000-000000000400','po-caller-lines',1,'e0000000-0000-0000-0000-000000000101',
  jsonb_build_object(
    'fulfilment_allocation_revision_id',(select response_payload #>> '{affected_aggregate_ids,fulfilment_allocation_revision_id}' from pa05e_results where result_name='allocate'),
    'supplier_id','e3000000-0000-0000-0000-000000000041','document_number','PA05E-PO-CALLER-LINES','lines','[]'::jsonb
  )
)));

insert into pa05e_results values ('po-stale', atlas_api.release_supplier_purchase_order(pg_temp.pa05e_request(
  'e9000000-0000-0000-0000-000000000401','po-stale',2,'e0000000-0000-0000-0000-000000000101',
  jsonb_build_object(
    'fulfilment_allocation_revision_id',(select response_payload #>> '{affected_aggregate_ids,fulfilment_allocation_revision_id}' from pa05e_results where result_name='allocate'),
    'supplier_id','e3000000-0000-0000-0000-000000000041','document_number','PA05E-PO-STALE'
  )
)));
insert into pa05e_results values ('po-a', atlas_api.release_supplier_purchase_order(pg_temp.pa05e_request(
  'e9000000-0000-0000-0000-000000000402','po-a',1,'e0000000-0000-0000-0000-000000000101',
  jsonb_build_object(
    'fulfilment_allocation_revision_id',(select response_payload #>> '{affected_aggregate_ids,fulfilment_allocation_revision_id}' from pa05e_results where result_name='allocate'),
    'supplier_id','e3000000-0000-0000-0000-000000000041','document_number','PA05E-PO-A'
  )
)));
insert into pa05e_results values ('po-a-replay', atlas_api.release_supplier_purchase_order(pg_temp.pa05e_request(
  'e9000000-0000-0000-0000-000000000402','po-a',1,'e0000000-0000-0000-0000-000000000101',
  jsonb_build_object(
    'fulfilment_allocation_revision_id',(select response_payload #>> '{affected_aggregate_ids,fulfilment_allocation_revision_id}' from pa05e_results where result_name='allocate'),
    'supplier_id','e3000000-0000-0000-0000-000000000041','document_number','PA05E-PO-A'
  )
)));
insert into pa05e_results values ('po-a-duplicate', atlas_api.release_supplier_purchase_order(pg_temp.pa05e_request(
  'e9000000-0000-0000-0000-000000000403','po-a-duplicate',1,'e0000000-0000-0000-0000-000000000101',
  jsonb_build_object(
    'fulfilment_allocation_revision_id',(select response_payload #>> '{affected_aggregate_ids,fulfilment_allocation_revision_id}' from pa05e_results where result_name='allocate'),
    'supplier_id','e3000000-0000-0000-0000-000000000041','document_number','PA05E-PO-A-SECOND'
  )
)));
insert into pa05e_results values ('po-global-document', atlas_api.release_supplier_purchase_order(pg_temp.pa05e_request(
  'e9000000-0000-0000-0000-000000000404','po-global-document',1,'e0000000-0000-0000-0000-000000000101',
  jsonb_build_object(
    'fulfilment_allocation_revision_id',(select response_payload #>> '{affected_aggregate_ids,fulfilment_allocation_revision_id}' from pa05e_results where result_name='allocate'),
    'supplier_id','e3000000-0000-0000-0000-000000000042','document_number','PA05E-PO-A'
  )
)));
insert into pa05e_results values ('po-no-lines', atlas_api.release_supplier_purchase_order(pg_temp.pa05e_request(
  'e9000000-0000-0000-0000-000000000405','po-no-lines',1,'e0000000-0000-0000-0000-000000000101',
  jsonb_build_object(
    'fulfilment_allocation_revision_id',(select response_payload #>> '{affected_aggregate_ids,fulfilment_allocation_revision_id}' from pa05e_results where result_name='allocate'),
    'supplier_id','e3000000-0000-0000-0000-000000000043','document_number','PA05E-PO-NONE'
  )
)));
insert into pa05e_results values ('po-b', atlas_api.release_supplier_purchase_order(pg_temp.pa05e_request(
  'e9000000-0000-0000-0000-000000000406','po-b',1,'e0000000-0000-0000-0000-000000000101',
  jsonb_build_object(
    'fulfilment_allocation_revision_id',(select response_payload #>> '{affected_aggregate_ids,fulfilment_allocation_revision_id}' from pa05e_results where result_name='allocate'),
    'supplier_id','e3000000-0000-0000-0000-000000000042','document_number','PA05E-PO-B'
  )
)));
reset role;

select is((select response_payload ->> 'error_code' from pa05e_results where result_name='malformed'),'VALIDATION_FAILED','malformed PA-05E envelope fails safely');
select is((select response_payload ->> 'error_code' from pa05e_results where result_name='missing-auth'),'AUTHENTICATION_REQUIRED','missing authentication fails closed');
select is((select response_payload ->> 'error_code' from pa05e_results where result_name='wrong-capability'),'CAPABILITY_DENIED','missing allocation capability fails closed');
select is((select response_payload ->> 'error_code' from pa05e_results where result_name='wrong-scope'),'SCOPE_DENIED','wrong relational scope fails closed');
select is((select response_payload ->> 'error_code' from pa05e_results where result_name='subject-mismatch'),'AUTH_SUBJECT_MISMATCH','asserted subject mismatch fails closed');
select is((select response_payload ->> 'error_code' from pa05e_results where result_name='inactive-actor'),'ACTOR_INACTIVE','inactive actor fails closed');
select is((select response_payload ->> 'error_code' from pa05e_results where result_name='inactive-subject'),'AUTH_SUBJECT_INACTIVE','revoked authentication subject fails closed');
select is((select response_payload ->> 'error_code' from pa05e_results where result_name='delegation'),'DELEGATION_NOT_SUPPORTED','delegation fails closed');
select is((select response_payload ->> 'error_code' from pa05e_results where result_name='unknown-envelope'),'VALIDATION_FAILED','unknown envelope fields fail safely');
select is((select response_payload ->> 'error_code' from pa05e_results where result_name='zero-lines'),'VALIDATION_FAILED','zero allocation lines fail safely');
select is((select response_payload ->> 'error_code' from pa05e_results where result_name='oversized-lines'),'VALIDATION_FAILED','more than 100 allocation lines fail safely');
select is((select response_payload ->> 'error_code' from pa05e_results where result_name='unknown-line-field'),'VALIDATION_FAILED','unknown allocation-line fields fail safely');
select is((select response_payload ->> 'error_code' from pa05e_results where result_name='inactive-supplier'),'INVARIANT_VIOLATION','inactive supplier reference fails safely');
select is((select response_payload ->> 'error_code' from pa05e_results where result_name='stale'),'STALE_VERSION','allocation rejects a stale requirement version');
select is((select response_payload ->> 'error_code' from pa05e_results where result_name='bad-quantity'),'INVARIANT_VIOLATION','allocation rejects an excess quantity');
select is((select response_payload ->> 'error_code' from pa05e_results where result_name='partial-quantity'),'INVARIANT_VIOLATION','allocation rejects a partial or rounded quantity');
select is((select response_payload ->> 'error_code' from pa05e_results where result_name='bad-unit'),'INVARIANT_VIOLATION','allocation rejects a non-exact unit');
select is((select response_payload ->> 'error_code' from pa05e_results where result_name='missing-line'),'INVARIANT_VIOLATION','allocation rejects incomplete line coverage');
select is((select response_payload ->> 'error_code' from pa05e_results where result_name='duplicate-line'),'VALIDATION_FAILED','allocation rejects duplicate line identities');
select is((select response_payload ->> 'error_code' from pa05e_results where result_name='split-line'),'VALIDATION_FAILED','allocation rejects split supplier portions for one requirement line');
select is((select response_payload ->> 'error_code' from pa05e_results where result_name='crosswire'),'INVARIANT_VIOLATION','allocation rejects cross-wired requirement lineage');
select is((select response_payload ->> 'error_code' from pa05e_results where result_name='wrong-lifecycle'),'INVARIANT_VIOLATION','allocation rejects a non-released requirement lifecycle');
select ok((select (response_payload ->> 'success')::boolean from pa05e_results where result_name='allocate'),'exact multi-supplier allocation succeeds atomically');
select ok(
  (select response_payload ?& array[
    'success','command_id','correlation_id','idempotency_status','affected_aggregate_ids',
    'new_versions','emitted_event_ids','audit_event_ids','safe_operator_message','warnings','blockers'
  ] from pa05e_results where result_name='allocate'),
  'allocation returns the complete safe command response envelope'
);
select is((select response_payload from pa05e_results where result_name='allocate-replay'),(select response_payload from pa05e_results where result_name='allocate'),'allocation replay returns the original response');
select is((select response_payload ->> 'error_code' from pa05e_results where result_name='allocate-conflict'),'IDEMPOTENCY_CONFLICT','changed allocation payload with the same command identity conflicts');
select is((select response_payload ->> 'error_code' from pa05e_results where result_name='allocate-duplicate'),'INVARIANT_VIOLATION','a second allocation for the requirement is rejected');

select is((select count(*)::integer from atlas_procurement.fulfilment_allocations),1,'one allocation root is created');
select is((select count(*)::integer from atlas_procurement.fulfilment_allocation_revisions),1,'one current base allocation revision is created');
select is((select count(*)::integer from atlas_procurement.fulfilment_allocation_lines),3,'every requirement line creates one stable allocation line');
select is((select count(*)::integer from atlas_procurement.fulfilment_allocation_line_revisions),3,'every allocation line creates one exact line revision');
select ok(
  not exists (
    select 1
    from atlas_procurement.fulfilment_allocation_line_revisions falr
    join atlas_planning.dispatch_requirement_line_revisions drlr using (dispatch_requirement_line_revision_id)
    where falr.allocated_quantity <> drlr.required_quantity or falr.unit_id <> drlr.unit_id
      or falr.fulfilment_source_type <> 'SUPPLIER_PO' or falr.line_status <> 'READY_FOR_EVIDENCE'
  ),
  'allocation line revisions preserve exact quantity, unit, source, and readiness'
);
select is((select count(distinct supplier_id)::integer from atlas_procurement.fulfilment_allocation_line_revisions),2,'one supplier per line permits multiple suppliers across lines');

select is((select response_payload ->> 'error_code' from pa05e_results where result_name='po-stale'),'STALE_VERSION','PO release rejects a stale allocation version');
select is((select response_payload ->> 'error_code' from pa05e_results where result_name='po-caller-lines'),'VALIDATION_FAILED','PO release rejects caller-selected line input');
select ok((select (response_payload ->> 'success')::boolean from pa05e_results where result_name='po-a'),'first supplier PO releases successfully');
select is((select response_payload from pa05e_results where result_name='po-a-replay'),(select response_payload from pa05e_results where result_name='po-a'),'PO replay returns the original response');
select is((select response_payload ->> 'error_code' from pa05e_results where result_name='po-a-duplicate'),'INVARIANT_VIOLATION','a second PO for the same allocation supplier is rejected');
select is((select response_payload ->> 'error_code' from pa05e_results where result_name='po-global-document'),'INVARIANT_VIOLATION','document number uniqueness is global');
select is((select response_payload ->> 'error_code' from pa05e_results where result_name='po-no-lines'),'INVARIANT_VIOLATION','PO release rejects suppliers with no allocation lines');
select ok((select (response_payload ->> 'success')::boolean from pa05e_results where result_name='po-b'),'second supplier releases through a separate PO command');
select ok(
  (select response_payload ?& array[
    'success','command_id','correlation_id','idempotency_status','affected_aggregate_ids',
    'new_versions','emitted_event_ids','audit_event_ids','safe_operator_message','warnings','blockers'
  ] from pa05e_results where result_name='po-b'),
  'PO release returns the complete safe command response envelope'
);
select is((select count(*)::integer from atlas_procurement.purchase_orders),2,'separate suppliers create separate purchase orders');
select is((select count(*)::integer from atlas_procurement.purchase_order_lines pol join atlas_procurement.purchase_orders po using (purchase_order_id) where po.supplier_id='e3000000-0000-0000-0000-000000000041'),2,'supplier A PO contains all and only its two allocation lines');
select is((select count(*)::integer from atlas_procurement.purchase_order_lines pol join atlas_procurement.purchase_orders po using (purchase_order_id) where po.supplier_id='e3000000-0000-0000-0000-000000000042'),1,'supplier B PO contains all and only its one allocation line');
select ok(
  not exists (
    select 1
    from atlas_procurement.purchase_order_line_revisions polr
    join atlas_procurement.purchase_order_revisions por using (purchase_order_revision_id)
    join atlas_procurement.purchase_orders po using (purchase_order_id)
    join atlas_procurement.fulfilment_allocation_line_revisions falr using (fulfilment_allocation_line_revision_id)
    join atlas_planning.dispatch_requirement_line_revisions drlr using (dispatch_requirement_line_revision_id)
    where po.supplier_id <> falr.supplier_id
      or polr.ingredient_id <> drlr.ingredient_id
      or polr.ordered_quantity <> falr.allocated_quantity
      or polr.unit_id <> falr.unit_id
      or por.revision_status <> 'RELEASED_TO_SUPPLIER'
  ),
  'PO revisions and lines preserve supplier, ingredient, quantity, unit, and released lineage'
);
select ok(
  exists (
    select 1 from atlas_procurement.purchase_order_revisions
    where supplier_name_snapshot='PA-05E Supplier A'
      and delivery_location_snapshot='PA-05E location'
      and service_date=date '2026-07-16'
  ),
  'PO release snapshots supplier, destination, and service date'
);
select is((select version::integer from atlas_procurement.fulfilment_allocations),1,'PO releases do not mutate allocation version');

select is((select count(*)::integer from atlas_audit.domain_events where source_domain='PROCUREMENT'),3,'three successful Procurement commands emit three domain events');
select is((select count(*)::integer from atlas_audit.audit_events where source_domain='PROCUREMENT'),3,'three successful Procurement commands emit three audit events');
select is((select count(*)::integer from atlas_core.command_receipts where command_name in ('allocate_supplier_direct_fulfilment','release_supplier_purchase_order') and outcome='COMPLETED'),3,'three successful first executions create three completed Procurement receipts');
select ok(
  not exists (
    select 1 from atlas_audit.domain_events
    where command_id in (
      'e9000000-0000-0000-0000-000000000206'::uuid,
      'e9000000-0000-0000-0000-000000000207'::uuid,
      'e9000000-0000-0000-0000-000000000208'::uuid,
      'e9000000-0000-0000-0000-000000000211'::uuid,
      'e9000000-0000-0000-0000-000000000401'::uuid,
      'e9000000-0000-0000-0000-000000000403'::uuid,
      'e9000000-0000-0000-0000-000000000404'::uuid
    )
  )
  and not exists (
    select 1 from atlas_audit.audit_events
    where command_id in (
      'e9000000-0000-0000-0000-000000000206'::uuid,
      'e9000000-0000-0000-0000-000000000207'::uuid,
      'e9000000-0000-0000-0000-000000000208'::uuid,
      'e9000000-0000-0000-0000-000000000211'::uuid,
      'e9000000-0000-0000-0000-000000000401'::uuid,
      'e9000000-0000-0000-0000-000000000403'::uuid,
      'e9000000-0000-0000-0000-000000000404'::uuid
    )
  ),
  'failed commands create no misleading Procurement domain or audit event'
);
select ok(
  not exists (
    select 1
    from atlas_audit.domain_events de
    left join atlas_core.command_receipts cr on cr.command_receipt_id = de.command_receipt_id
    where de.source_domain='PROCUREMENT'
      and (cr.outcome <> 'COMPLETED' or cr.command_id <> de.command_id or cr.actor_id <> de.actor_id)
  ),
  'Procurement domain events retain completed receipt, command, and actor linkage'
);
select ok(
  exists (
    select 1 from atlas_core.command_receipts
    where command_id='e9000000-0000-0000-0000-000000000206'
      and outcome='FAILED_NON_RETRYABLE' and error_code='STALE_VERSION'
  ),
  'deterministic failures retain a safe failed receipt'
);
select is((select count(*)::integer from atlas_evidence.supplier_receiving_evidence),0,'PA-05E creates no Evidence facts');
select is((select count(*)::integer from atlas_dispatch.dispatch_plans),0,'PA-05E creates no Dispatch execution facts');
select ok(
  not exists (
    select fulfilment_allocation_line_id
    from atlas_procurement.purchase_order_lines
    group by fulfilment_allocation_line_id having count(*) > 1
  ),
  'sequential release attempts preserve one PO assignment per allocation line'
);

select * from finish();
rollback;
