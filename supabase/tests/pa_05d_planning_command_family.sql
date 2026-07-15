begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
select no_plan();

grant usage on schema extensions to authenticated;
grant execute on all functions in schema extensions to authenticated;

select is(
  (select count(*)::integer from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'atlas_api'),
  13,
  'Atlas API contains exactly 13 reviewed functions'
);

select ok(
  not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    join pg_roles r on r.oid = p.proowner
    where n.nspname = 'atlas_api'
      and p.proname in ('record_wholesale_source','release_wholesale_order','release_purchase_handoff','release_dispatch_requirement')
      and (r.rolname <> 'atlas_planning_command_runtime' or not p.prosecdef
        or p.proconfig is null or p.proconfig::text not like '%search_path=%')
  ),
  'all four PA-05D functions are hardened definers owned by Planning runtime'
);

select ok(
  not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
      and p.proname in ('record_wholesale_source','release_wholesale_order','release_purchase_handoff','release_dispatch_requirement')
      and pg_get_functiondef(p.oid) ~* '\\mexecute\\M'
  ),
  'PA-05D functions contain no dynamic SQL'
);

select ok(
  exists (select 1 from pg_roles where rolname = 'atlas_planning_command_runtime' and not rolcanlogin and not rolinherit),
  'Planning runtime is NOLOGIN and NOINHERIT'
);

select is(
  (select count(*)::integer from pg_proc p join pg_roles r on r.oid = p.proowner where r.rolname = 'atlas_planning_command_runtime'),
  4,
  'Planning runtime owns only the four PA-05D entry functions'
);

select ok(
  not exists (
    select 1 from pg_auth_members
    where member = (select oid from pg_roles where rolname = 'atlas_planning_command_runtime')
  ),
  'Planning runtime is not a member of another runtime role'
);

select ok(
  not has_schema_privilege('atlas_planning_command_runtime', 'atlas_api', 'CREATE')
  and not exists (
    select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname like 'atlas\_%' escape '\' and c.relkind = 'S'
      and (has_sequence_privilege('atlas_planning_command_runtime', c.oid, 'USAGE')
        or has_sequence_privilege('atlas_planning_command_runtime', c.oid, 'UPDATE'))
  ),
  'Planning runtime has no Atlas schema CREATE or sequence mutation privilege'
);

select ok(
  not has_schema_privilege('atlas_planning_command_runtime', 'atlas_procurement', 'USAGE')
  and not has_schema_privilege('atlas_planning_command_runtime', 'atlas_evidence', 'USAGE')
  and not has_schema_privilege('atlas_planning_command_runtime', 'atlas_dispatch', 'USAGE')
  and not has_table_privilege('atlas_planning_command_runtime', 'atlas_procurement.fulfilment_allocations', 'INSERT')
  and not has_table_privilege('atlas_planning_command_runtime', 'atlas_evidence.supplier_receiving_evidence', 'INSERT')
  and not has_table_privilege('atlas_planning_command_runtime', 'atlas_dispatch.dispatch_plans', 'INSERT'),
  'Planning runtime cannot write Procurement, Evidence, or Dispatch facts'
);

select ok(
  not has_table_privilege('atlas_evidence_command_runtime', 'atlas_planning.wholesale_orders', 'INSERT')
  and not has_table_privilege('atlas_dispatch_command_runtime', 'atlas_planning.wholesale_orders', 'INSERT'),
  'Evidence and Dispatch runtimes cannot write Planning facts'
);

select is(
  (select count(*)::integer from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'atlas_api' and has_function_privilege('authenticated', p.oid, 'EXECUTE')),
  13,
  'authenticated can execute exactly the 13 reviewed functions'
);

select ok(
  not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    cross join unnest(array['anon','service_role']) x(role_name)
    where n.nspname = 'atlas_api' and has_function_privilege(x.role_name, p.oid, 'EXECUTE')
  ),
  'anon and service_role cannot execute Atlas API functions'
);

select ok(
  not exists (
    select 1 from unnest(array['anon','authenticated','service_role']) x(role_name)
    cross join pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname like 'atlas\_%' escape '\' and c.relkind in ('r','v','m','S')
      and (has_table_privilege(x.role_name, c.oid, 'SELECT')
        or has_table_privilege(x.role_name, c.oid, 'INSERT')
        or has_table_privilege(x.role_name, c.oid, 'UPDATE')
        or has_table_privilege(x.role_name, c.oid, 'DELETE')
        or (c.relkind = 'S' and has_sequence_privilege(x.role_name, c.oid, 'USAGE')))
  ),
  'API roles retain no direct private relation or sequence access'
);

select ok(
  exists (select 1 from pg_indexes where schemaname = 'atlas_planning' and indexname = 'wholesale_orders_active_customer_reference_key' and indexdef ilike '%unique%')
  and exists (select 1 from pg_indexes where schemaname = 'atlas_planning' and indexname = 'confirmed_need_batches_wholesale_order_key' and indexdef ilike '%unique%')
  and exists (select 1 from pg_indexes where schemaname = 'atlas_planning' and indexname = 'dispatch_requirement_revisions_released_handoff_key' and indexdef ilike '%unique%'),
  'narrow PA-05D race-safety uniqueness is present'
);

insert into atlas_core.actors (actor_id, actor_type, display_name, actor_status, deactivated_at) values
  ('d0000000-0000-0000-0000-000000000001','HUMAN','PA-05D planner','ACTIVE',null),
  ('d0000000-0000-0000-0000-000000000002','HUMAN','PA-05D no capability','ACTIVE',null),
  ('d0000000-0000-0000-0000-000000000003','HUMAN','PA-05D wrong scope','ACTIVE',null),
  ('d0000000-0000-0000-0000-000000000004','HUMAN','PA-05D inactive','INACTIVE',timestamptz '2026-07-15 00:00:00+00'),
  ('d0000000-0000-0000-0000-000000000005','HUMAN','PA-05D revoked subject','ACTIVE',null);

insert into atlas_core.actor_auth_subjects (actor_id, auth_subject_id, subject_status, revoked_at) values
  ('d0000000-0000-0000-0000-000000000001','d0000000-0000-0000-0000-000000000101','ACTIVE',null),
  ('d0000000-0000-0000-0000-000000000002','d0000000-0000-0000-0000-000000000102','ACTIVE',null),
  ('d0000000-0000-0000-0000-000000000003','d0000000-0000-0000-0000-000000000103','ACTIVE',null),
  ('d0000000-0000-0000-0000-000000000004','d0000000-0000-0000-0000-000000000104','ACTIVE',null),
  ('d0000000-0000-0000-0000-000000000005','d0000000-0000-0000-0000-000000000105','REVOKED',timestamptz '2026-07-15 00:00:00+00');

insert into atlas_core.roles (role_id, role_code, role_name) values
  ('d1000000-0000-0000-0000-000000000001','pa05d.planner','PA-05D planner'),
  ('d1000000-0000-0000-0000-000000000002','pa05d.empty','PA-05D empty');

insert into atlas_core.capabilities (capability_id, capability_code, capability_name, owning_domain) values
  ('d2000000-0000-0000-0000-000000000001','wholesale_source.record','Record wholesale source','PLANNING'),
  ('d2000000-0000-0000-0000-000000000002','wholesale_order.release','Release wholesale order','PLANNING'),
  ('d2000000-0000-0000-0000-000000000003','purchase_handoff.release','Release purchase handoff','PLANNING'),
  ('d2000000-0000-0000-0000-000000000004','dispatch_requirement.release','Release dispatch requirement','PLANNING');

insert into atlas_core.role_capabilities (role_id, capability_id)
select 'd1000000-0000-0000-0000-000000000001', capability_id from atlas_core.capabilities
where capability_code in ('wholesale_source.record','wholesale_order.release','purchase_handoff.release','dispatch_requirement.release');

insert into atlas_core.actor_role_memberships (actor_id, role_id) values
  ('d0000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001'),
  ('d0000000-0000-0000-0000-000000000002','d1000000-0000-0000-0000-000000000002'),
  ('d0000000-0000-0000-0000-000000000003','d1000000-0000-0000-0000-000000000001'),
  ('d0000000-0000-0000-0000-000000000004','d1000000-0000-0000-0000-000000000001'),
  ('d0000000-0000-0000-0000-000000000005','d1000000-0000-0000-0000-000000000001');

insert into atlas_admin.customers (customer_id, customer_code, customer_name) values
  ('d3000000-0000-0000-0000-000000000001','pa05d-customer','PA-05D customer'),
  ('d3000000-0000-0000-0000-000000000002','pa05d-other','PA-05D other customer');
insert into atlas_admin.customers (customer_id, customer_code, customer_name, customer_status) values
  ('d3000000-0000-0000-0000-000000000003','pa05d-inactive','PA-05D inactive customer','INACTIVE');
insert into atlas_admin.delivery_locations (delivery_location_id, customer_id, location_code, location_name, address_text, timezone_name) values
  ('d3000000-0000-0000-0000-000000000011','d3000000-0000-0000-0000-000000000001','pa05d-location','PA-05D location','PA-05D address','Asia/Bangkok'),
  ('d3000000-0000-0000-0000-000000000012','d3000000-0000-0000-0000-000000000002','pa05d-other-location','PA-05D other address','Other address','Asia/Bangkok');
insert into atlas_admin.units (unit_id, unit_code, unit_name, dimension_code) values
  ('d3000000-0000-0000-0000-000000000021','pa05d-kg','kilogram','mass'),
  ('d3000000-0000-0000-0000-000000000022','pa05d-box','box','count');
insert into atlas_admin.units (unit_id, unit_code, unit_name, dimension_code, unit_status) values
  ('d3000000-0000-0000-0000-000000000023','pa05d-inactive-unit','inactive unit','count','INACTIVE');
insert into atlas_admin.ingredients (ingredient_id, ingredient_code, ingredient_name) values
  ('d3000000-0000-0000-0000-000000000031','pa05d-rice','Rice'),
  ('d3000000-0000-0000-0000-000000000032','pa05d-oil','Oil');
insert into atlas_admin.ingredients (ingredient_id, ingredient_code, ingredient_name, ingredient_status) values
  ('d3000000-0000-0000-0000-000000000033','pa05d-inactive-ingredient','Inactive ingredient','INACTIVE');

insert into atlas_core.actor_scopes (actor_id, scope_kind, customer_id) values
  ('d0000000-0000-0000-0000-000000000001','CUSTOMER','d3000000-0000-0000-0000-000000000001'),
  ('d0000000-0000-0000-0000-000000000003','CUSTOMER','d3000000-0000-0000-0000-000000000002');
insert into atlas_core.actor_scopes (actor_id, scope_kind) values
  ('d0000000-0000-0000-0000-000000000002','GLOBAL'),
  ('d0000000-0000-0000-0000-000000000004','GLOBAL'),
  ('d0000000-0000-0000-0000-000000000005','GLOBAL');

create temporary table pa05d_results (result_name text primary key, response_payload jsonb not null);
grant select, insert, update on pa05d_results to authenticated;

create function pg_temp.pa05d_request(command_id uuid, idempotency_key text, expected_version bigint, subject uuid, payload jsonb)
returns jsonb language sql immutable set search_path = '' as $$
  select pg_catalog.jsonb_build_object(
    'contract_version','PA-05D.v1','command_id',command_id,
    'correlation_id','d9000000-0000-0000-0000-000000000001'::uuid,
    'idempotency_key',idempotency_key,'expected_version',expected_version,
    'requested_by_auth_subject',subject,'requested_at','2026-07-15T00:00:00+00:00',
    'reason_code','PA05D_TEST','reason_note','PA-05D pgTAP','payload',payload
  )
$$;

set local role authenticated;
select set_config('request.jwt.claim.sub','d0000000-0000-0000-0000-000000000101',true);

insert into pa05d_results values ('malformed', atlas_api.record_wholesale_source('{}'::jsonb));
select set_config('request.jwt.claim.sub','',true);
insert into pa05d_results values ('missing_auth', atlas_api.record_wholesale_source(pg_temp.pa05d_request(
  'd9000000-0000-0000-0000-000000000002','missing-auth',1,'d0000000-0000-0000-0000-000000000101',
  jsonb_build_object('customer_id','d3000000-0000-0000-0000-000000000001','delivery_location_id','d3000000-0000-0000-0000-000000000011','customer_order_reference','PA05D-AUTH','service_date','2026-07-16','lines',jsonb_build_array(
    jsonb_build_object('source_line_number',1,'ingredient_id','d3000000-0000-0000-0000-000000000031','requested_quantity',1,'unit_id','d3000000-0000-0000-0000-000000000021'))))));
select set_config('request.jwt.claim.sub','d0000000-0000-0000-0000-000000000101',true);
insert into pa05d_results values ('subject_mismatch', atlas_api.record_wholesale_source(pg_temp.pa05d_request(
  'd9000000-0000-0000-0000-000000000003','subject-mismatch',1,'d0000000-0000-0000-0000-000000000102',
  jsonb_build_object('customer_id','d3000000-0000-0000-0000-000000000001','delivery_location_id','d3000000-0000-0000-0000-000000000011','customer_order_reference','PA05D-AUTH','service_date','2026-07-16','lines',jsonb_build_array(
    jsonb_build_object('source_line_number',1,'ingredient_id','d3000000-0000-0000-0000-000000000031','requested_quantity',1,'unit_id','d3000000-0000-0000-0000-000000000021'))))));
select set_config('request.jwt.claim.sub','d0000000-0000-0000-0000-000000000104',true);
insert into pa05d_results values ('inactive_actor', atlas_api.record_wholesale_source(pg_temp.pa05d_request(
  'd9000000-0000-0000-0000-000000000004','inactive-actor',1,'d0000000-0000-0000-0000-000000000104',
  jsonb_build_object('customer_id','d3000000-0000-0000-0000-000000000001','delivery_location_id','d3000000-0000-0000-0000-000000000011','customer_order_reference','PA05D-AUTH','service_date','2026-07-16','lines',jsonb_build_array(
    jsonb_build_object('source_line_number',1,'ingredient_id','d3000000-0000-0000-0000-000000000031','requested_quantity',1,'unit_id','d3000000-0000-0000-0000-000000000021'))))));
select set_config('request.jwt.claim.sub','d0000000-0000-0000-0000-000000000105',true);
insert into pa05d_results values ('inactive_subject', atlas_api.record_wholesale_source(pg_temp.pa05d_request(
  'd9000000-0000-0000-0000-000000000005','inactive-subject',1,'d0000000-0000-0000-0000-000000000105',
  jsonb_build_object('customer_id','d3000000-0000-0000-0000-000000000001','delivery_location_id','d3000000-0000-0000-0000-000000000011','customer_order_reference','PA05D-AUTH','service_date','2026-07-16','lines',jsonb_build_array(
    jsonb_build_object('source_line_number',1,'ingredient_id','d3000000-0000-0000-0000-000000000031','requested_quantity',1,'unit_id','d3000000-0000-0000-0000-000000000021'))))));
select set_config('request.jwt.claim.sub','d0000000-0000-0000-0000-000000000102',true);
insert into pa05d_results values ('wrong_capability', atlas_api.record_wholesale_source(pg_temp.pa05d_request(
  'd9000000-0000-0000-0000-000000000006','wrong-capability',1,'d0000000-0000-0000-0000-000000000102',
  jsonb_build_object('customer_id','d3000000-0000-0000-0000-000000000001','delivery_location_id','d3000000-0000-0000-0000-000000000011','customer_order_reference','PA05D-AUTH','service_date','2026-07-16','lines',jsonb_build_array(
    jsonb_build_object('source_line_number',1,'ingredient_id','d3000000-0000-0000-0000-000000000031','requested_quantity',1,'unit_id','d3000000-0000-0000-0000-000000000021'))))));
select set_config('request.jwt.claim.sub','d0000000-0000-0000-0000-000000000103',true);
insert into pa05d_results values ('wrong_scope', atlas_api.record_wholesale_source(pg_temp.pa05d_request(
  'd9000000-0000-0000-0000-000000000007','wrong-scope',1,'d0000000-0000-0000-0000-000000000103',
  jsonb_build_object('customer_id','d3000000-0000-0000-0000-000000000001','delivery_location_id','d3000000-0000-0000-0000-000000000011','customer_order_reference','PA05D-AUTH','service_date','2026-07-16','lines',jsonb_build_array(
    jsonb_build_object('source_line_number',1,'ingredient_id','d3000000-0000-0000-0000-000000000031','requested_quantity',1,'unit_id','d3000000-0000-0000-0000-000000000021'))))));
select set_config('request.jwt.claim.sub','d0000000-0000-0000-0000-000000000101',true);
insert into pa05d_results values ('delegation', atlas_api.record_wholesale_source(pg_temp.pa05d_request(
  'd9000000-0000-0000-0000-000000000008','delegation',1,'d0000000-0000-0000-0000-000000000101',
  jsonb_build_object('customer_id','d3000000-0000-0000-0000-000000000001','delivery_location_id','d3000000-0000-0000-0000-000000000011','customer_order_reference','PA05D-AUTH','service_date','2026-07-16','delegated_actor_id','d0000000-0000-0000-0000-000000000002','lines',jsonb_build_array(
    jsonb_build_object('source_line_number',1,'ingredient_id','d3000000-0000-0000-0000-000000000031','requested_quantity',1,'unit_id','d3000000-0000-0000-0000-000000000021'))))));
insert into pa05d_results values ('zero_lines', atlas_api.record_wholesale_source(pg_temp.pa05d_request(
  'd9000000-0000-0000-0000-000000000010','zero-lines',1,'d0000000-0000-0000-0000-000000000101',
  jsonb_build_object('customer_id','d3000000-0000-0000-0000-000000000001','delivery_location_id','d3000000-0000-0000-0000-000000000011','customer_order_reference','PA05D-ZERO','service_date','2026-07-16','lines','[]'::jsonb))));
insert into pa05d_results values ('duplicate_lines', atlas_api.record_wholesale_source(pg_temp.pa05d_request(
  'd9000000-0000-0000-0000-000000000011','duplicate-lines',1,'d0000000-0000-0000-0000-000000000101',
  jsonb_build_object('customer_id','d3000000-0000-0000-0000-000000000001','delivery_location_id','d3000000-0000-0000-0000-000000000011','customer_order_reference','PA05D-DUP-LINES','service_date','2026-07-16','lines',jsonb_build_array(
    jsonb_build_object('source_line_number',1,'ingredient_id','d3000000-0000-0000-0000-000000000031','requested_quantity',1,'unit_id','d3000000-0000-0000-0000-000000000021'),
    jsonb_build_object('source_line_number',1,'ingredient_id','d3000000-0000-0000-0000-000000000032','requested_quantity',1,'unit_id','d3000000-0000-0000-0000-000000000022'))))));
insert into pa05d_results values ('nonpositive', atlas_api.record_wholesale_source(pg_temp.pa05d_request(
  'd9000000-0000-0000-0000-000000000012','nonpositive',1,'d0000000-0000-0000-0000-000000000101',
  jsonb_build_object('customer_id','d3000000-0000-0000-0000-000000000001','delivery_location_id','d3000000-0000-0000-0000-000000000011','customer_order_reference','PA05D-NONPOS','service_date','2026-07-16','lines',jsonb_build_array(
    jsonb_build_object('source_line_number',1,'ingredient_id','d3000000-0000-0000-0000-000000000031','requested_quantity',0,'unit_id','d3000000-0000-0000-0000-000000000021'))))));
insert into pa05d_results values ('oversized', atlas_api.record_wholesale_source(pg_temp.pa05d_request(
  'd9000000-0000-0000-0000-000000000014','oversized',1,'d0000000-0000-0000-0000-000000000101',
  jsonb_build_object('customer_id','d3000000-0000-0000-0000-000000000001','delivery_location_id','d3000000-0000-0000-0000-000000000011','customer_order_reference','PA05D-OVERSIZED','service_date','2026-07-16','lines',(
    select jsonb_agg(jsonb_build_object('source_line_number',g,'ingredient_id','d3000000-0000-0000-0000-000000000031','requested_quantity',1,'unit_id','d3000000-0000-0000-0000-000000000021')) from generate_series(1,101) g
  )))));
insert into pa05d_results values ('inactive_reference', atlas_api.record_wholesale_source(pg_temp.pa05d_request(
  'd9000000-0000-0000-0000-000000000015','inactive-reference',1,'d0000000-0000-0000-0000-000000000101',
  jsonb_build_object('customer_id','d3000000-0000-0000-0000-000000000001','delivery_location_id','d3000000-0000-0000-0000-000000000011','customer_order_reference','PA05D-INACTIVE','service_date','2026-07-16','lines',jsonb_build_array(
    jsonb_build_object('source_line_number',1,'ingredient_id','d3000000-0000-0000-0000-000000000033','requested_quantity',1,'unit_id','d3000000-0000-0000-0000-000000000023'))))));
insert into pa05d_results values ('wrong_location', atlas_api.record_wholesale_source(pg_temp.pa05d_request(
  'd9000000-0000-0000-0000-000000000013','wrong-location',1,'d0000000-0000-0000-0000-000000000101',
  jsonb_build_object('customer_id','d3000000-0000-0000-0000-000000000001','delivery_location_id','d3000000-0000-0000-0000-000000000012','customer_order_reference','PA05D-WRONG-LOC','service_date','2026-07-16','lines',jsonb_build_array(
    jsonb_build_object('source_line_number',1,'ingredient_id','d3000000-0000-0000-0000-000000000031','requested_quantity',1,'unit_id','d3000000-0000-0000-0000-000000000021'))))));

insert into pa05d_results values ('record', atlas_api.record_wholesale_source(pg_temp.pa05d_request(
  'd9000000-0000-0000-0000-000000000101','record-main',1,'d0000000-0000-0000-0000-000000000101',
  jsonb_build_object('customer_id','d3000000-0000-0000-0000-000000000001','delivery_location_id','d3000000-0000-0000-0000-000000000011','customer_order_reference','PA05D-ORDER-1','service_date','2026-07-16','lines',jsonb_build_array(
    jsonb_build_object('source_line_number',1,'ingredient_id','d3000000-0000-0000-0000-000000000031','requested_quantity',10,'unit_id','d3000000-0000-0000-0000-000000000021'),
    jsonb_build_object('source_line_number',2,'ingredient_id','d3000000-0000-0000-0000-000000000032','requested_quantity',3,'unit_id','d3000000-0000-0000-0000-000000000022'))))));
insert into pa05d_results values ('record_replay', atlas_api.record_wholesale_source(pg_temp.pa05d_request(
  'd9000000-0000-0000-0000-000000000101','record-main',1,'d0000000-0000-0000-0000-000000000101',
  jsonb_build_object('customer_id','d3000000-0000-0000-0000-000000000001','delivery_location_id','d3000000-0000-0000-0000-000000000011','customer_order_reference','PA05D-ORDER-1','service_date','2026-07-16','lines',jsonb_build_array(
    jsonb_build_object('source_line_number',1,'ingredient_id','d3000000-0000-0000-0000-000000000031','requested_quantity',10,'unit_id','d3000000-0000-0000-0000-000000000021'),
    jsonb_build_object('source_line_number',2,'ingredient_id','d3000000-0000-0000-0000-000000000032','requested_quantity',3,'unit_id','d3000000-0000-0000-0000-000000000022'))))));
insert into pa05d_results values ('record_conflict', atlas_api.record_wholesale_source(
  pg_temp.pa05d_request('d9000000-0000-0000-0000-000000000101','record-main',1,'d0000000-0000-0000-0000-000000000101',
  jsonb_build_object('customer_id','d3000000-0000-0000-0000-000000000001','delivery_location_id','d3000000-0000-0000-0000-000000000011','customer_order_reference','PA05D-ORDER-CHANGED','service_date','2026-07-16','lines',jsonb_build_array(
    jsonb_build_object('source_line_number',1,'ingredient_id','d3000000-0000-0000-0000-000000000031','requested_quantity',10,'unit_id','d3000000-0000-0000-0000-000000000021'))))));
insert into pa05d_results values ('duplicate_reference', atlas_api.record_wholesale_source(pg_temp.pa05d_request(
  'd9000000-0000-0000-0000-000000000102','duplicate-reference',1,'d0000000-0000-0000-0000-000000000101',
  jsonb_build_object('customer_id','d3000000-0000-0000-0000-000000000001','delivery_location_id','d3000000-0000-0000-0000-000000000011','customer_order_reference','PA05D-ORDER-1','service_date','2026-07-16','lines',jsonb_build_array(
    jsonb_build_object('source_line_number',1,'ingredient_id','d3000000-0000-0000-0000-000000000031','requested_quantity',1,'unit_id','d3000000-0000-0000-0000-000000000021'))))));

insert into pa05d_results values ('release_stale', atlas_api.release_wholesale_order(pg_temp.pa05d_request(
  'd9000000-0000-0000-0000-000000000201','release-stale',2,'d0000000-0000-0000-0000-000000000101',
  jsonb_build_object('wholesale_order_id',(select response_payload #>> '{affected_aggregate_ids,wholesale_order_id}' from pa05d_results where result_name='record')))));
insert into pa05d_results values ('release', atlas_api.release_wholesale_order(pg_temp.pa05d_request(
  'd9000000-0000-0000-0000-000000000202','release-main',1,'d0000000-0000-0000-0000-000000000101',
  jsonb_build_object('wholesale_order_id',(select response_payload #>> '{affected_aggregate_ids,wholesale_order_id}' from pa05d_results where result_name='record')))));
insert into pa05d_results values ('release_replay', atlas_api.release_wholesale_order(pg_temp.pa05d_request(
  'd9000000-0000-0000-0000-000000000202','release-main',1,'d0000000-0000-0000-0000-000000000101',
  jsonb_build_object('wholesale_order_id',(select response_payload #>> '{affected_aggregate_ids,wholesale_order_id}' from pa05d_results where result_name='record')))));
insert into pa05d_results values ('release_wrong_lifecycle', atlas_api.release_wholesale_order(pg_temp.pa05d_request(
  'd9000000-0000-0000-0000-000000000203','release-again',2,'d0000000-0000-0000-0000-000000000101',
  jsonb_build_object('wholesale_order_id',(select response_payload #>> '{affected_aggregate_ids,wholesale_order_id}' from pa05d_results where result_name='record')))));

insert into pa05d_results values ('handoff', atlas_api.release_purchase_handoff(pg_temp.pa05d_request(
  'd9000000-0000-0000-0000-000000000301','handoff-main',1,'d0000000-0000-0000-0000-000000000101',
  jsonb_build_object('confirmed_need_batch_id',(select response_payload #>> '{affected_aggregate_ids,confirmed_need_batch_id}' from pa05d_results where result_name='release')))));
insert into pa05d_results values ('handoff_replay', atlas_api.release_purchase_handoff(pg_temp.pa05d_request(
  'd9000000-0000-0000-0000-000000000301','handoff-main',1,'d0000000-0000-0000-0000-000000000101',
  jsonb_build_object('confirmed_need_batch_id',(select response_payload #>> '{affected_aggregate_ids,confirmed_need_batch_id}' from pa05d_results where result_name='release')))));

insert into pa05d_results values ('requirement', atlas_api.release_dispatch_requirement(pg_temp.pa05d_request(
  'd9000000-0000-0000-0000-000000000401','requirement-main',1,'d0000000-0000-0000-0000-000000000101',
  jsonb_build_object('purchase_handoff_revision_id',(select response_payload #>> '{affected_aggregate_ids,purchase_handoff_revision_id}' from pa05d_results where result_name='handoff')))));
insert into pa05d_results values ('requirement_replay', atlas_api.release_dispatch_requirement(pg_temp.pa05d_request(
  'd9000000-0000-0000-0000-000000000401','requirement-main',1,'d0000000-0000-0000-0000-000000000101',
  jsonb_build_object('purchase_handoff_revision_id',(select response_payload #>> '{affected_aggregate_ids,purchase_handoff_revision_id}' from pa05d_results where result_name='handoff')))));
reset role;

select is((select response_payload ->> 'error_code' from pa05d_results where result_name='malformed'),'VALIDATION_FAILED','malformed request fails safely');
select is((select response_payload ->> 'error_code' from pa05d_results where result_name='missing_auth'),'AUTHENTICATION_REQUIRED','missing authentication fails closed');
select is((select response_payload ->> 'error_code' from pa05d_results where result_name='subject_mismatch'),'AUTH_SUBJECT_MISMATCH','asserted subject mismatch fails closed');
select is((select response_payload ->> 'error_code' from pa05d_results where result_name='inactive_actor'),'ACTOR_INACTIVE','inactive actor fails closed');
select is((select response_payload ->> 'error_code' from pa05d_results where result_name='inactive_subject'),'AUTH_SUBJECT_INACTIVE','revoked authentication subject fails closed');
select is((select response_payload ->> 'error_code' from pa05d_results where result_name='wrong_capability'),'CAPABILITY_DENIED','missing capability fails closed');
select is((select response_payload ->> 'error_code' from pa05d_results where result_name='wrong_scope'),'SCOPE_DENIED','wrong relational scope fails closed');
select is((select response_payload ->> 'error_code' from pa05d_results where result_name='delegation'),'DELEGATION_NOT_SUPPORTED','delegation fails closed with the established safe code');
select is((select response_payload ->> 'error_code' from pa05d_results where result_name='zero_lines'),'VALIDATION_FAILED','zero source lines fail safely');
select is((select response_payload ->> 'error_code' from pa05d_results where result_name='duplicate_lines'),'VALIDATION_FAILED','duplicate source line numbers fail safely');
select is((select response_payload ->> 'error_code' from pa05d_results where result_name='nonpositive'),'VALIDATION_FAILED','nonpositive quantity fails safely');
select is((select response_payload ->> 'error_code' from pa05d_results where result_name='oversized'),'VALIDATION_FAILED','more than 100 source lines fail safely');
select is((select response_payload ->> 'error_code' from pa05d_results where result_name='inactive_reference'),'INVARIANT_VIOLATION','inactive ingredient and unit references fail safely');
select is((select response_payload ->> 'error_code' from pa05d_results where result_name='wrong_location'),'INVARIANT_VIOLATION','wrong customer/location relation fails closed');
select ok((select (response_payload ->> 'success')::boolean from pa05d_results where result_name='record'),'multi-line wholesale source records atomically');
select is((select response_payload from pa05d_results where result_name='record_replay'),(select response_payload from pa05d_results where result_name='record'),'source replay returns original response');
select is((select response_payload ->> 'error_code' from pa05d_results where result_name='record_conflict'),'IDEMPOTENCY_CONFLICT','different payload with same command identity conflicts');
select is((select response_payload ->> 'error_code' from pa05d_results where result_name='duplicate_reference'),'INVARIANT_VIOLATION','duplicate customer order reference is rejected');
select is((select count(*)::integer from atlas_planning.wholesale_orders where customer_order_reference='PA05D-ORDER-1'),1,'replay and duplicate reference create one source root');
select is((select count(*)::integer from atlas_planning.wholesale_order_lines),2,'source creation writes exact stable line count');
select is((select response_payload ->> 'error_code' from pa05d_results where result_name='release_stale'),'STALE_VERSION','wholesale release rejects stale version');
select ok((select (response_payload ->> 'success')::boolean from pa05d_results where result_name='release'),'wholesale order releases successfully');
select is((select response_payload from pa05d_results where result_name='release_replay'),(select response_payload from pa05d_results where result_name='release'),'wholesale release replay returns original response');
select is((select response_payload ->> 'error_code' from pa05d_results where result_name='release_wrong_lifecycle'),'INVARIANT_VIOLATION','wholesale release rejects wrong lifecycle');
select is((select order_status from atlas_planning.wholesale_orders where customer_order_reference='PA05D-ORDER-1'),'RELEASED','wholesale root is released');
select is((select version::integer from atlas_planning.wholesale_orders where customer_order_reference='PA05D-ORDER-1'),2,'wholesale release increments root version once');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions where revision_status='RELEASED'),2,'release creates exact released Confirmed Need revisions');
select ok(not exists(select 1 from atlas_planning.confirmed_need_line_revisions where theoretical_quantity<>confirmed_quantity),'pass-through theoretical and confirmed quantities are equal');
select is((select count(*)::integer from atlas_planning.confirmed_need_snapshot_lines),2,'release creates exact approval snapshot lines');
select ok((select (response_payload ->> 'success')::boolean from pa05d_results where result_name='handoff'),'Purchase Handoff releases successfully');
select is((select response_payload from pa05d_results where result_name='handoff_replay'),(select response_payload from pa05d_results where result_name='handoff'),'handoff replay returns original response');
select is((select count(*)::integer from atlas_planning.purchase_handoff_line_revisions),2,'handoff creates exact line revisions');
select is((select count(*)::integer from atlas_planning.purchase_demand_references),2,'handoff creates one immutable demand reference per line');
select ok(not exists(select 1 from atlas_planning.purchase_handoff_line_revisions phlr join atlas_planning.purchase_demand_references pdr using (purchase_handoff_line_revision_id) where phlr.handoff_quantity<>pdr.approved_quantity or phlr.unit_id<>pdr.unit_id),'handoff preserves snapshot quantity and unit lineage');
select is((select count(*)::integer from atlas_procurement.fulfilment_allocations),0,'handoff creates no Procurement fact');
select ok((select (response_payload ->> 'success')::boolean from pa05d_results where result_name='requirement'),'Dispatch Requirement releases successfully');
select is((select response_payload from pa05d_results where result_name='requirement_replay'),(select response_payload from pa05d_results where result_name='requirement'),'requirement replay returns original response');
select is((select count(*)::integer from atlas_planning.dispatch_requirement_line_revisions),2,'requirement creates exact line revisions');
select ok(not exists(select 1 from atlas_planning.dispatch_requirement_line_revisions drlr join atlas_planning.purchase_handoff_line_revisions phlr using (purchase_handoff_line_revision_id) where drlr.required_quantity<>phlr.handoff_quantity or drlr.ingredient_id<>phlr.ingredient_id or drlr.unit_id<>phlr.unit_id),'requirement preserves handoff line lineage');
select ok(exists(select 1 from atlas_planning.dispatch_requirement_revisions where customer_name_snapshot='PA-05D customer' and location_name_snapshot='PA-05D location' and address_snapshot='PA-05D address' and timezone_name='Asia/Bangkok'),'requirement snapshots active destination facts');
select is((select count(*)::integer from atlas_dispatch.dispatch_plans),0,'requirement creates no Dispatch execution fact');
select is((select count(*)::integer from atlas_core.command_receipts where outcome='COMPLETED'),4,'four successful first executions create four completed receipts');
select is((select count(*)::integer from atlas_audit.domain_events where source_domain='PLANNING'),4,'four successful commands create four Planning domain events');
select is((select count(*)::integer from atlas_audit.audit_events where source_domain='PLANNING'),4,'four successful commands create four Planning audit events');
select is((select count(*)::integer from atlas_audit.domain_events where command_id='d9000000-0000-0000-0000-000000000201'),0,'deterministic stale failure creates no domain event');
select is((select count(*)::integer from atlas_audit.audit_events where command_id='d9000000-0000-0000-0000-000000000201'),0,'deterministic stale failure creates no audit event');
select ok(exists(select 1 from atlas_core.command_receipts where command_id='d9000000-0000-0000-0000-000000000201' and outcome='FAILED_NON_RETRYABLE' and error_code='STALE_VERSION'),'deterministic stale failure is retained safely');

select * from finish();
rollback;
