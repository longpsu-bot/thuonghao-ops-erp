-- Independent read-only check: run before and after each acceptance batch.
begin read only;
set local statement_timeout='8s';
do $postflight$
declare target record; remaining bigint;
begin
  for target in select * from (values
    ('atlas_core','actors','actor_id'),
    ('atlas_core','actor_auth_subjects','actor_id'),
    ('atlas_core','roles','role_id'),
    ('atlas_core','role_capabilities','role_id'),
    ('atlas_core','actor_role_memberships','actor_id'),
    ('atlas_core','actor_scopes','actor_id'),
    ('atlas_core','command_receipts','actor_id'),
    ('atlas_admin','customers','customer_id'),
    ('atlas_admin','delivery_locations','delivery_location_id'),
    ('atlas_admin','schools','school_id'),
    ('atlas_admin','units','unit_id'),
    ('atlas_admin','ingredients','ingredient_id'),
    ('atlas_admin','suppliers','supplier_id'),
    ('atlas_admin','supplier_eligibilities','supplier_id'),
    ('atlas_planning','confirmed_need_batches','confirmed_need_batch_id'),
    ('atlas_planning','confirmed_need_lines','confirmed_need_batch_id'),
    ('atlas_planning','confirmed_need_line_revisions','confirmed_need_batch_id'),
    ('atlas_planning','confirmed_need_line_decisions','confirmed_need_batch_id'),
    ('atlas_planning','purchase_handoff_batches','purchase_handoff_batch_id'),
    ('atlas_planning','purchase_handoff_revisions','purchase_handoff_batch_id'),
    ('atlas_planning','purchase_handoff_lines','purchase_handoff_batch_id'),
    ('atlas_planning','purchase_handoff_line_revisions','purchase_handoff_line_id'),
    ('atlas_planning','purchase_demand_references','purchase_handoff_line_revision_id'),
    ('atlas_procurement','school_catering_allocation_families','family_id'),
    ('atlas_procurement','school_catering_allocation_family_revisions','family_id'),
    ('atlas_procurement','school_catering_allocation_family_contributions','family_revision_id'),
    ('atlas_procurement','school_catering_allocation_supplier_splits','family_revision_id'),
    ('atlas_procurement','purchase_orders','supplier_id'),
    ('atlas_procurement','purchase_order_revisions','purchase_order_id'),
    ('atlas_procurement','purchase_order_lines','purchase_order_id'),
    ('atlas_procurement','purchase_order_line_revisions','purchase_order_line_id'),
    ('atlas_dispatch','school_dispatch_releases','school_id'),
    ('atlas_dispatch','school_dispatch_release_lines','ingredient_id'),
    ('atlas_dispatch','school_dispatch_release_line_sources','confirmed_need_line_revision_id'),
    ('atlas_audit','domain_events','actor_id'),
    ('atlas_audit','audit_events','actor_id')
  ) target(schema_name,table_name,column_name) loop
    execute format('select count(*) from %I.%I where %I >= $1 and %I < $2',
      target.schema_name,target.table_name,target.column_name,target.column_name)
    into remaining using 'f1080000-0000-0000-0000-000000000000'::uuid,
      'f1090000-0000-0000-0000-000000000000'::uuid;
    if remaining<>0 then raise exception 'A108 probe remains in %.%: %',
      target.schema_name,target.table_name,remaining; end if;
  end loop;
end;
$postflight$;
select jsonb_build_object('success',true,'probe_relation_checks',36,'probe_rows',0,
  'migration_108_present',exists(select 1 from supabase_migrations.schema_migrations
    where version='20261014090000'),
  'draft_po_count',(select count(*) from atlas_procurement.purchase_orders
    where purchase_order_kind='SCHOOL_CATERING' and purchase_order_status='DRAFT'),
  'draft_po_fingerprint',(
    select md5(string_agg(to_jsonb(po)::text||to_jsonb(revision)::text||coalesce((
      select string_agg(to_jsonb(line)::text,'' order by line.purchase_order_line_revision_id)
      from atlas_procurement.purchase_order_line_revisions line
      where line.purchase_order_revision_id=revision.purchase_order_revision_id),''),
      '' order by po.purchase_order_id))
    from atlas_procurement.purchase_orders po
    join atlas_procurement.purchase_order_revisions revision
      on revision.purchase_order_id=po.purchase_order_id and revision.is_current
    where po.purchase_order_kind='SCHOOL_CATERING' and po.purchase_order_status='DRAFT'
  ));
rollback;
