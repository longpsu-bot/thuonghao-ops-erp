-- Carry the existing v1-backed rank through scoped operational reads.
-- Only read projections and their pagination order change.
begin;

create function pg_temp.patch_school_order(target regprocedure, variadic edits text[])
returns void language plpgsql as $$
declare
  definition text := pg_get_functiondef(target);
  anchor text;
  i integer;
begin
  for i in 1..cardinality(edits) by 2 loop
    anchor := edits[i];
    if (length(definition) - length(replace(definition, anchor, ''))) <> length(anchor) then
      raise exception 'Expected one school-order anchor in %: %', target, anchor;
    end if;
    definition := replace(definition, anchor, edits[i+1]);
  end loop;
  execute definition;
end $$;

select pg_temp.patch_school_order('atlas_core.rmvp_05_workbench_payload(uuid,jsonb,integer,integer)',
  'school.school_name,', 'school.school_name, school.display_order,',
  $a$'name', line.school_name)$a$, $a$'name', line.school_name, 'display_order', line.display_order)$a$,
  'order by service_date, school_name,', 'order by display_order, school_name, school_id, service_date,',
  'order by line.service_date, line.school_name,', 'order by line.display_order, line.school_name, line.school_id, line.service_date,');

select pg_temp.patch_school_order('atlas_core.rmvp_04_workbench_payload(date,date,uuid,jsonb,integer,integer,jsonb)',
  'school.school_name,', 'school.school_name, school.display_order,',
  E'line.school_name,\n', E'line.school_name, min(line.display_order) as display_order,\n',
  $a$'school_name', page.school_name,$a$, $a$'school_name', page.school_name, 'display_order', page.display_order,$a$,
  'order by service_date, school_name,', 'order by display_order, school_name, school_id, service_date,',
  'order by page.service_date, page.school_name,', 'order by page.display_order, page.school_name, page.school_id, page.service_date,');

select pg_temp.patch_school_order('atlas_api.get_confirmed_supplier_allocation_workbench(jsonb)',
  $a$'school_name',s.school_name)$a$, $a$'school_name',s.school_name,'display_order',s.display_order)$a$,
  'order by s.school_name,s.school_id)', 'order by s.display_order,s.school_name,s.school_id)',
  $a$v_row||jsonb_build_object('complete',v_complete,$a$,
  $a$v_row||jsonb_build_object('complete',v_complete,'display_order',
        (select s.display_order from atlas_admin.schools s where s.school_id=(v_row->>'school_id')::uuid),$a$);

select pg_temp.patch_school_order('atlas_core.procurement_read_school_dispatch_release_preview(date,uuid,uuid,jsonb)',
  'school.school_id,school.school_name,location.delivery_location_id,',
  'school.school_id,school.school_name,school.display_order,location.delivery_location_id,',
  $a$'school_name',(select school_name from scope),$a$,
  $a$'school_name',(select school_name from scope),'display_order',(select display_order from scope),$a$);

select pg_temp.patch_school_order(target,
  $a$'school_name',preview.value->>'school_name',$a$,
  $a$'school_name',preview.value->>'school_name','display_order',preview.value->'display_order',$a$)
from unnest(array[
  'atlas_core.school_fulfilment_reconciliation_scope(date,uuid,uuid)'::regprocedure,
  'atlas_core.procurement_read_school_fulfilment_reconciliation_scope(date,uuid,uuid,jsonb)'::regprocedure
]) as scopes(target);

drop function pg_temp.patch_school_order(regprocedure,text[]);
commit;
