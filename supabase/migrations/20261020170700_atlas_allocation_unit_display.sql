-- Advisory allocation labels use current Unit metadata; identities/codes stay intact.
begin;
do $migration$
declare
  definition text := pg_get_functiondef('atlas_api.get_confirmed_supplier_allocation_workbench(jsonb)'::regprocedure);
  anchor constant text := '  return jsonb_build_object(''success'',true,''contract_version'',''CONFIRMED-SUPPLIER-ALLOCATION.v1'',';
begin
  if (length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>1
    or position('Current Unit names are display metadata' in definition)>0 then
    raise exception 'Expected one confirmed-allocation Unit presentation anchor';
  end if;
  execute replace(definition,anchor,$shape$  -- Current Unit names are display metadata, never quantity or source authority.
  select coalesce(jsonb_agg(row.value||jsonb_build_object('unit_name',unit.unit_name)
    order by row.ordinal),'[]'::jsonb) into v_rows
  from jsonb_array_elements(v_rows) with ordinality row(value,ordinal)
  left join atlas_admin.units unit on unit.unit_id=(row.value->>'unit_id')::uuid;
$shape$||anchor);
end $migration$;
commit;
