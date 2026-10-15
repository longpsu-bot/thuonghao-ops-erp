-- A2: current human Unit labels, future-only immutable PO name evidence and
-- exact revision-based Draft School projection. No historical backfill/grants.
begin;
alter table atlas_procurement.purchase_order_line_revisions
  add column unit_name_snapshot text;

do $a2$
declare d text; old text;
begin
  d:=pg_get_functiondef('atlas_core.freeze_school_catering_po_line_output()'::regprocedure);
  old:='select ingredient.document_code,ingredient.ingredient_name,unit.unit_code';
  if strpos(d,old)=0 then raise exception 'A2 Unit capture SELECT anchor missing'; end if;
  d:=replace(d,old,old||',unit.unit_name');
  old:='into new.ingredient_document_code_snapshot,new.ingredient_name_snapshot,new.unit_code_snapshot';
  if strpos(d,old)=0 then raise exception 'A2 Unit capture INTO anchor missing'; end if;
  d:=replace(d,old,old||',new.unit_name_snapshot');
  old:='or new.ingredient_name_snapshot is not null or new.unit_code_snapshot is not null then';
  if strpos(d,old)=0 then raise exception 'A2 Draft snapshot guard anchor missing'; end if;
  execute replace(d,old,'or new.ingredient_name_snapshot is not null or new.unit_code_snapshot is not null or new.unit_name_snapshot is not null then');

  d:=pg_get_functiondef('atlas_core.guard_po_document_identity_snapshot()'::regprocedure);
  old:='or new.unit_code_snapshot is distinct from old.unit_code_snapshot';
  if strpos(d,old)=0 then raise exception 'A2 immutable Unit anchor missing'; end if;
  execute replace(d,old,old||' or new.unit_name_snapshot is distinct from old.unit_name_snapshot');

  d:=pg_get_functiondef('atlas_api.get_school_catering_procurement_workbench(jsonb)'::regprocedure);
  old:='pg_catalog.jsonb_set(row.value,''{splits}''';
  if strpos(d,old)=0 then raise exception 'A2 Allocation shape anchor missing'; end if;
  d:=replace(d,old,'pg_catalog.jsonb_set(row.value || pg_catalog.jsonb_build_object(''unit_name'',unit.unit_name),''{splits}''');
  old:='with ordinality row(value,ordinality);';
  if strpos(d,old)=0 then raise exception 'A2 Allocation Unit join anchor missing'; end if;
  execute replace(d,old,'with ordinality row(value,ordinality) join atlas_admin.units unit on unit.unit_id=(row.value->>''unit_id'')::uuid;');

  d:=pg_get_functiondef('atlas_api.get_confirmed_supplier_allocation_workbench(jsonb)'::regprocedure);
  old:='select l.location_name,i.ingredient_name,u.unit_code,';
  if strpos(d,old)=0 then raise exception 'A2 confirmed Allocation Unit anchor missing'; end if;
  execute replace(d,old,'select l.location_name,i.ingredient_name,u.unit_code,u.unit_name,');

  d:=pg_get_functiondef('atlas_api.get_generated_purchase_review(jsonb)'::regprocedure);
  old:='''unit_id'',g.unit_id,''unit_code'',u.unit_code,';
  if strpos(d,old)=0 then raise exception 'A2 Generated Review Unit anchor missing'; end if;
  execute replace(d,old,old||'''unit_name'',u.unit_name,');

  d:=pg_get_functiondef('atlas_api.get_school_catering_purchase_orders(jsonb)'::regprocedure);
  old:='''unit_code_snapshot'',revision.unit_code_snapshot,';
  if strpos(d,old)=0 then raise exception 'A2 PO Unit snapshot shape anchor missing'; end if;
  d:=replace(d,old,old||'''unit_name_snapshot'',revision.unit_name_snapshot,');
  old:='''unit'',(line.value->''unit'')||jsonb_build_object(''unit_code'',';
  if strpos(d,old)=0 then raise exception 'A2 PO Unit label anchor missing'; end if;
  d:=replace(d,old,'''unit'',(line.value->''unit'')||jsonb_build_object(''unit_name'',case when v_official then revision.unit_name_snapshot else unit.unit_name end,''unit_code'',');
  old:='''school_breakdown'',coalesce(revision.school_breakdown_snapshot,''[]''::jsonb),';
  if strpos(d,old)=0 then raise exception 'A2 Draft School projection anchor missing'; end if;
  d:=replace(d,old,'''school_breakdown'',case when v_official then coalesce(revision.school_breakdown_snapshot,''[]''::jsonb) else atlas_core.school_catering_po_school_breakdown(revision.school_catering_allocation_supplier_split_id) end,');
  old:=$old$or nullif(btrim(line->>'unit_code_snapshot',U&'\0009\000A\000B\000C\000D\0020\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000\FEFF'),'') is null$old$;
  if strpos(d,old)=0 then raise exception 'A2 official Unit completeness anchor missing'; end if;
  execute replace(d,old,old||E'\n          '||$new$or not exists (
            select 1 from jsonb_array_elements_text(jsonb_build_array(
              line->>'unit_name_snapshot',line->>'unit_code_snapshot')) raw(label)
            cross join lateral (select btrim(raw.label,U&'\0009\000A\000B\000C\000D\0020\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000\FEFF') label) candidate
            where candidate.label<>'' and candidate.label<>'?'
              and candidate.label !~ '[[:cntrl:]]'
              and candidate.label !~* '^(v1-unit-|atlas[-_:]|unit[-_:])'
              and candidate.label !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
          )$new$);
end;
$a2$;

drop trigger guard_po_line_document_identity on atlas_procurement.purchase_order_line_revisions;
create trigger guard_po_line_document_identity before update of
  ingredient_document_code_snapshot,ingredient_name_snapshot,unit_code_snapshot,unit_name_snapshot
  on atlas_procurement.purchase_order_line_revisions for each row
  execute function atlas_core.guard_po_document_identity_snapshot();
-- Existing CREATE OR REPLACE owners, paths, ACLs and RLS remain unchanged.
-- Forward rollback retains the nullable column and frozen evidence; never backfill.
commit;
