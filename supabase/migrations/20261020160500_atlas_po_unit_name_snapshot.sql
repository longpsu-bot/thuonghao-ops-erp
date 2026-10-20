-- Capture human Unit labels on future releases. Historical nulls stay null.
-- Existing code snapshots, quantities, identities and official history stay intact.
begin;

alter table atlas_procurement.purchase_order_line_revisions
  add column unit_name_snapshot text,
  add constraint po_unit_name_snapshot_nonblank check (
    unit_name_snapshot is null or nullif(btrim(unit_name_snapshot),'') is not null);
comment on column atlas_procurement.purchase_order_line_revisions.unit_name_snapshot is
  'Unit name captured by the backend on future School-catering PO release; immutable, including historical nulls.';

do $migration$
declare
  definition text;
  anchor text;
begin
  definition := pg_get_functiondef('atlas_core.freeze_school_catering_po_line_output()'::regprocedure);
  anchor := 'select ingredient.document_code,ingredient.ingredient_name,unit.unit_code';
  if (length(definition)-length(replace(definition,anchor,'')))/length(anchor) <> 1 then
    raise exception 'Expected one released Unit capture source';
  end if;
  definition := replace(definition,anchor,
    anchor||',case when nullif(btrim(unit.unit_name),'''') is null then null else unit.unit_name end');
  anchor := 'into new.ingredient_document_code_snapshot,new.ingredient_name_snapshot,new.unit_code_snapshot';
  if (length(definition)-length(replace(definition,anchor,'')))/length(anchor) <> 1 then
    raise exception 'Expected one released Unit capture target';
  end if;
  definition := replace(definition,anchor,anchor||',new.unit_name_snapshot');
  anchor := 'or new.unit_code_snapshot is not null then';
  if (length(definition)-length(replace(definition,anchor,'')))/length(anchor) <> 1 then
    raise exception 'Expected one Draft Unit snapshot prohibition';
  end if;
  execute replace(definition,anchor,'or new.unit_code_snapshot is not null or new.unit_name_snapshot is not null then');

  definition := pg_get_functiondef('atlas_core.guard_po_document_identity_snapshot()'::regprocedure);
  anchor := 'or new.unit_code_snapshot is distinct from old.unit_code_snapshot';
  if (length(definition)-length(replace(definition,anchor,'')))/length(anchor) <> 1 then
    raise exception 'Expected one immutable Unit snapshot guard';
  end if;
  execute replace(definition,anchor,
    anchor||' or new.unit_name_snapshot is distinct from old.unit_name_snapshot');

  definition := pg_get_functiondef('atlas_api.get_school_catering_purchase_orders(jsonb)'::regprocedure);
  anchor := '''unit_code_snapshot'',revision.unit_code_snapshot,';
  if (length(definition)-length(replace(definition,anchor,'')))/length(anchor) <> 1 then
    raise exception 'Expected one PO frozen Unit read projection';
  end if;
  execute replace(definition,anchor,anchor||'''unit_name_snapshot'',revision.unit_name_snapshot,');
end;
$migration$;

drop trigger guard_po_line_document_identity on atlas_procurement.purchase_order_line_revisions;
create trigger guard_po_line_document_identity before update of
  ingredient_document_code_snapshot,ingredient_name_snapshot,unit_code_snapshot,unit_name_snapshot
  on atlas_procurement.purchase_order_line_revisions
  for each row execute function atlas_core.guard_po_document_identity_snapshot();

commit;
