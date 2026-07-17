begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
select no_plan();

grant usage on schema extensions to authenticated;
grant execute on all functions in schema extensions to authenticated;

select ok(
  not exists (
    select 1 from unnest(array['atlas_command_runtime', 'atlas_evidence_command_runtime', 'atlas_dispatch_command_runtime', 'atlas_planning_command_runtime', 'atlas_procurement_command_runtime', 'atlas_read_runtime']) r(role_name)
    cross join unnest(array['atlas_core','atlas_admin','atlas_planning','atlas_procurement','atlas_evidence','atlas_dispatch','atlas_audit','atlas_reporting','atlas_api']) s(schema_name)
    where has_schema_privilege(r.role_name, s.schema_name, 'CREATE')
  ),
  'all Atlas runtime roles lack CREATE on every Atlas schema after function ownership transfer'
);

select ok(
  not exists (
    select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname like 'atlas\_%' escape '\'
      and c.relkind in ('r','v','m','S')
      and (has_table_privilege('atlas_command_runtime', c.oid, 'SELECT')
        or has_table_privilege('atlas_command_runtime', c.oid, 'INSERT')
        or has_table_privilege('atlas_command_runtime', c.oid, 'UPDATE')
        or has_table_privilege('atlas_command_runtime', c.oid, 'DELETE')
        or has_table_privilege('atlas_command_runtime', c.oid, 'TRUNCATE')
        or (c.relkind = 'S' and has_sequence_privilege('atlas_command_runtime', c.oid, 'USAGE')))
  ),
  'retired atlas_command_runtime has no Atlas relation or sequence privileges'
);

select ok(
  not exists (
    select 1 from information_schema.role_table_grants
    where grantee = 'atlas_read_runtime' and table_schema like 'atlas\_%' escape '\'
      and privilege_type <> 'SELECT'
  )
  and not exists (
    select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname like 'atlas\_%' escape '\' and c.relkind = 'S'
      and (has_sequence_privilege('atlas_read_runtime', c.oid, 'USAGE')
        or has_sequence_privilege('atlas_read_runtime', c.oid, 'UPDATE'))
  ),
  'atlas_read_runtime remains select-only with no sequence mutation privilege'
);

select ok(
  not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    cross join unnest(array['anon','service_role']) r(role_name)
    where n.nspname = 'atlas_api' and has_function_privilege(r.role_name, p.oid, 'EXECUTE')
  ),
  'anon and service_role cannot execute any Atlas API function'
);

select is(
  (select count(*)::integer from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'atlas_api' and has_function_privilege('authenticated', p.oid, 'EXECUTE')),
  18,
  'authenticated can execute exactly the 18 reviewed functions through PA-05B-H3'
);

select ok(
  not exists (
    select 1 from unnest(array['anon','authenticated','service_role']) r(role_name)
    cross join pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname like 'atlas\_%' escape '\' and c.relkind in ('r','v','m','S')
      and (has_table_privilege(r.role_name, c.oid, 'SELECT') or has_table_privilege(r.role_name, c.oid, 'INSERT')
        or has_table_privilege(r.role_name, c.oid, 'UPDATE') or has_table_privilege(r.role_name, c.oid, 'DELETE')
        or (c.relkind = 'S' and has_sequence_privilege(r.role_name, c.oid, 'USAGE')))
  ),
  'API roles have no direct private table view or sequence privileges'
);

select ok(
  not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace join pg_roles r on r.oid = p.proowner
    where n.nspname = 'atlas_api' and (
      (p.proname in ('record_supplier_receiving_evidence','apply_supplier_evidence_to_allocation') and r.rolname <> 'atlas_evidence_command_runtime')
      or (p.proname in ('confirm_dispatch_load','record_dispatch_departure','confirm_successful_delivery','create_dispatch_plan','create_or_assign_dispatch_trip','close_successful_trip') and r.rolname <> 'atlas_dispatch_command_runtime')
      or (p.proname in ('record_wholesale_source','release_wholesale_order','release_purchase_handoff','release_dispatch_requirement') and r.rolname <> 'atlas_planning_command_runtime')
      or (p.proname in ('allocate_supplier_direct_fulfilment','release_supplier_purchase_order') and r.rolname <> 'atlas_procurement_command_runtime')
      or (p.proname in ('get_supplier_direct_trace','get_dispatch_evidence_readiness','get_operator_blockers','get_command_audit_timeline') and r.rolname <> 'atlas_read_runtime')
    )
  ),
  'each reviewed Atlas API function is owned by its least-privilege runtime role'
);

select is(
  (select count(*)::integer from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'atlas_api'),
  18,
  'no Atlas API functions beyond the reviewed surface through PA-05B-H3 exist'
);

select ok(
  not has_schema_privilege('atlas_evidence_command_runtime', 'atlas_dispatch', 'USAGE')
  and not has_table_privilege('atlas_evidence_command_runtime', 'atlas_dispatch.dispatch_trips', 'UPDATE')
  and not has_table_privilege('atlas_dispatch_command_runtime', 'atlas_evidence.supplier_receiving_evidence', 'INSERT')
  and not has_table_privilege('atlas_dispatch_command_runtime', 'atlas_procurement.fulfilment_allocations', 'INSERT'),
  'Evidence cannot access Dispatch and Dispatch cannot manufacture Evidence or Procurement facts'
);

select ok(
  not exists (
    select 1 from pg_policy p join pg_class c on c.oid = p.polrelid join pg_namespace n on n.oid = c.relnamespace
    where n.nspname like 'atlas\_%' escape '\'
      and (p.polroles && array[
        (select oid from pg_roles where rolname = 'anon'),
        (select oid from pg_roles where rolname = 'authenticated'),
        (select oid from pg_roles where rolname = 'service_role'),
        (select oid from pg_roles where rolname = 'atlas_command_runtime')
      ])
  ),
  'no Atlas RLS policy exposes a private relation to API roles or the retired shared runtime'
);

select * from finish();
rollback;
