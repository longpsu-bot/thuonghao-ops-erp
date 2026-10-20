-- Draft presentation may show an imported Unit's human name. Official documents
-- continue to use their immutable Unit-code snapshot, with no current-name fallback.
begin;
do $migration$
declare
  definition text := pg_get_functiondef('atlas_api.get_school_catering_purchase_orders(jsonb)'::regprocedure);
  anchor constant text := '''unit'',(line.value->''unit'')||jsonb_build_object(''unit_code'',case when v_official then coalesce(revision.unit_code_snapshot,''Thiếu ĐVT lịch sử'') else unit.unit_code end)';
begin
  if (length(definition)-length(replace(definition,anchor,'')))/length(anchor) <> 1 then
    raise exception 'Expected one PO Unit presentation anchor';
  end if;
  execute replace(definition,anchor,
    left(anchor,length(anchor)-1)||',''unit_name'',case when v_official then null else unit.unit_name end)');
end;
$migration$;
commit;
