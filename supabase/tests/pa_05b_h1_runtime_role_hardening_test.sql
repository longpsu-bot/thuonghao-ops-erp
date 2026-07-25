begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
select plan(1);

grant usage on schema extensions to authenticated;
grant execute on all functions in schema extensions to authenticated;

select ok(
  not has_schema_privilege('atlas_evidence_command_runtime', 'atlas_dispatch', 'USAGE')
  and not has_table_privilege('atlas_evidence_command_runtime', 'atlas_dispatch.dispatch_trips', 'UPDATE')
  and not has_table_privilege('atlas_dispatch_command_runtime', 'atlas_evidence.supplier_receiving_evidence', 'INSERT')
  and not has_table_privilege('atlas_dispatch_command_runtime', 'atlas_procurement.fulfilment_allocations', 'INSERT'),
  'Evidence cannot access Dispatch and Dispatch cannot manufacture Evidence or Procurement facts'
);

select * from finish();
rollback;
