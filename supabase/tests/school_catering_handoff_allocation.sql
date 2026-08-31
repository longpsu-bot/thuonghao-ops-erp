begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set search_path = extensions, public, pg_catalog;

select plan(48);

select has_table('atlas_procurement', 'school_catering_allocation_families', 'Allocation Family roots exist');
select has_table('atlas_procurement', 'school_catering_allocation_family_revisions', 'Allocation Family revisions exist');
select has_table('atlas_procurement', 'school_catering_allocation_family_contributions', 'Allocation Family contributions exist');
select has_table('atlas_procurement', 'school_catering_allocation_supplier_splits', 'Allocation Family supplier splits exist');

select has_function('atlas_api', 'release_school_catering_purchase_handoff', array['jsonb']);
select has_function('atlas_api', 'save_school_catering_supplier_allocation', array['jsonb']);
select has_function('atlas_api', 'confirm_school_catering_supplier_recommendations', array['jsonb']);
select has_function('atlas_api', 'get_school_catering_procurement_workbench', array['jsonb']);

select ok(exists (
  select 1 from atlas_core.capabilities
  where capability_code = 'procurement.school_catering.read'
    and owning_domain = 'PROCUREMENT' and capability_status = 'ACTIVE'
), 'school-catering Procurement read capability is explicit');
select ok(exists (
  select 1 from atlas_core.capabilities
  where capability_code = 'procurement.school_catering.write'
    and owning_domain = 'PROCUREMENT' and capability_status = 'ACTIVE'
), 'school-catering Procurement write capability is explicit');

select has_column('atlas_planning', 'purchase_demand_references', 'source_kind', 'Purchase Demand Reference is source-qualified');
select ok(exists (
  select 1 from information_schema.columns
  where table_schema='atlas_planning' and table_name='purchase_demand_references'
    and column_name='wholesale_order_line_revision_id' and is_nullable='YES'
), 'wholesale source is nullable for source-qualified demand references');
select has_check('atlas_planning', 'purchase_demand_references', 'purchase_demand_references_source_kind_check');
select has_check('atlas_planning', 'purchase_demand_references', 'purchase_demand_references_source_shape_check');

select ok(exists (
  select 1 from pg_indexes where schemaname='atlas_procurement'
    and tablename='school_catering_allocation_families'
    and indexdef ilike '%unique%service_date%delivery_location_id%ingredient_id%unit_id%'
), 'Allocation Family key is unique');
select ok(exists (
  select 1 from pg_indexes
  where schemaname = 'atlas_procurement'
    and tablename = 'school_catering_allocation_family_revisions'
    and indexdef ilike '%unique%where (is_current = true)%'
), 'only one current revision is permitted per Allocation Family');
select ok(exists (
  select 1 from pg_indexes where schemaname='atlas_procurement'
    and tablename='school_catering_allocation_family_contributions'
    and indexdef ilike '%unique%family_revision_id%purchase_handoff_line_revision_id%'
), 'contribution lineage is unique within a family revision');
select ok(exists (
  select 1 from pg_indexes where schemaname='atlas_procurement'
    and tablename='school_catering_allocation_supplier_splits'
    and indexdef ilike '%unique%family_revision_id%supplier_id%'
), 'supplier is unique within a family revision');

select has_check('atlas_procurement', 'school_catering_allocation_family_revisions',
  'school_catering_allocation_family_revisions_quantity_check');
select has_check('atlas_procurement', 'school_catering_allocation_family_contributions',
  'school_catering_allocation_family_contributions_quantity_check');
select has_check('atlas_procurement', 'school_catering_allocation_supplier_splits',
  'school_catering_allocation_supplier_splits_quantity_check');
select has_check('atlas_procurement', 'school_catering_allocation_supplier_splits',
  'school_catering_allocation_supplier_splits_ratio_check');

select ok((select relrowsecurity and relforcerowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='atlas_procurement' and c.relname='school_catering_allocation_families'), 'family roots use forced RLS');
select ok((select relrowsecurity and relforcerowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='atlas_procurement' and c.relname='school_catering_allocation_family_revisions'), 'family revisions use forced RLS');
select ok((select relrowsecurity and relforcerowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='atlas_procurement' and c.relname='school_catering_allocation_family_contributions'), 'family contributions use forced RLS');
select ok((select relrowsecurity and relforcerowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='atlas_procurement' and c.relname='school_catering_allocation_supplier_splits'), 'supplier splits use forced RLS');

select function_owner_is('atlas_api', 'release_school_catering_purchase_handoff', array['jsonb'], 'atlas_planning_command_runtime');
select function_owner_is('atlas_api', 'save_school_catering_supplier_allocation', array['jsonb'], 'atlas_procurement_command_runtime');
select function_owner_is('atlas_api', 'confirm_school_catering_supplier_recommendations', array['jsonb'], 'atlas_procurement_command_runtime');
select function_owner_is('atlas_api', 'get_school_catering_procurement_workbench', array['jsonb'], 'atlas_read_runtime');

select function_privs_are('atlas_api', 'release_school_catering_purchase_handoff', array['jsonb'], 'authenticated', array['EXECUTE']);
select function_privs_are('atlas_api', 'save_school_catering_supplier_allocation', array['jsonb'], 'authenticated', array['EXECUTE']);
select function_privs_are('atlas_api', 'confirm_school_catering_supplier_recommendations', array['jsonb'], 'authenticated', array['EXECUTE']);
select function_privs_are('atlas_api', 'get_school_catering_procurement_workbench', array['jsonb'], 'authenticated', array['EXECUTE']);

select function_privs_are('atlas_api', 'release_school_catering_purchase_handoff', array['jsonb'], 'anon', array[]::text[]);
select function_privs_are('atlas_api', 'save_school_catering_supplier_allocation', array['jsonb'], 'anon', array[]::text[]);
select function_privs_are('atlas_api', 'confirm_school_catering_supplier_recommendations', array['jsonb'], 'anon', array[]::text[]);
select function_privs_are('atlas_api', 'get_school_catering_procurement_workbench', array['jsonb'], 'anon', array[]::text[]);

select function_privs_are('atlas_api', 'release_school_catering_purchase_handoff', array['jsonb'], 'service_role', array[]::text[]);
select function_privs_are('atlas_api', 'save_school_catering_supplier_allocation', array['jsonb'], 'service_role', array[]::text[]);
select function_privs_are('atlas_api', 'confirm_school_catering_supplier_recommendations', array['jsonb'], 'service_role', array[]::text[]);
select function_privs_are('atlas_api', 'get_school_catering_procurement_workbench', array['jsonb'], 'service_role', array[]::text[]);

select table_privs_are('atlas_procurement', 'school_catering_allocation_families', 'authenticated', array[]::text[]);
select table_privs_are('atlas_procurement', 'school_catering_allocation_family_revisions', 'authenticated', array[]::text[]);
select table_privs_are('atlas_procurement', 'school_catering_allocation_family_contributions', 'authenticated', array[]::text[]);
select table_privs_are('atlas_procurement', 'school_catering_allocation_supplier_splits', 'authenticated', array[]::text[]);

select ok(to_regclass('atlas_procurement.fulfilment_allocations') is not null,
  'PA-05E wholesale fulfilment allocation remains present');
select ok(to_regprocedure('atlas_api.allocate_supplier_direct_fulfilment(jsonb)') is not null,
  'PA-05E wholesale allocation command remains present');

select * from finish();
rollback;
