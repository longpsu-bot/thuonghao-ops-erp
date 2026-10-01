begin;
create extension if not exists pgtap with schema extensions;
set search_path=extensions,public,pg_catalog;
select no_plan();

select has_column('atlas_procurement','school_catering_allocation_supplier_splits',
  'supplier_note','supplier note is an explicit immutable split fact');
select has_column('atlas_procurement','purchase_order_line_revisions',
  'supplier_note_snapshot','PO line owns its generated historical note');
select col_is_null('atlas_procurement','school_catering_allocation_supplier_splits',
  'supplier_note','existing splits default to null');
select col_is_null('atlas_procurement','purchase_order_line_revisions',
  'supplier_note_snapshot','existing PO lines default to null');
select ok(not has_table_privilege('authenticated',
  'atlas_procurement.school_catering_allocation_supplier_splits','INSERT'),
  'browser cannot insert or forge an allocation split note');
select ok(not has_table_privilege('authenticated',
  'atlas_procurement.purchase_order_line_revisions','INSERT'),
  'browser cannot insert or forge a PO note snapshot');
select ok((select relrowsecurity and relforcerowsecurity from pg_class
  where oid='atlas_procurement.school_catering_allocation_supplier_splits'::regclass),
  'allocation split forced RLS remains enabled');
select ok((select relrowsecurity and relforcerowsecurity from pg_class
  where oid='atlas_procurement.purchase_order_line_revisions'::regclass),
  'PO line forced RLS remains enabled');
select ok(exists(select 1 from pg_trigger where tgrelid=
  'atlas_procurement.purchase_order_line_revisions'::regclass
  and tgname='freeze_school_catering_po_line_output' and not tgisinternal),
  'backend snapshot freeze remains attached to every PO line insert');
select function_owner_is('atlas_core','freeze_school_catering_po_line_output',
  array[]::text[],'atlas_procurement_command_runtime');
select ok((select prosecdef and proconfig[1] in ('search_path=','search_path=""')
  from pg_proc where oid='atlas_core.freeze_school_catering_po_line_output()'::regprocedure),
  'snapshot guard keeps fixed empty search_path');
select function_owner_is('atlas_api','get_school_catering_purchase_orders',
  array['jsonb'],'atlas_read_runtime');
select function_owner_is('atlas_api','get_confirmed_supplier_allocation_workbench',
  array['jsonb'],'atlas_read_runtime');

select * from finish();
rollback;
