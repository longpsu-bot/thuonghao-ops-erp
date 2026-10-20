-- Preserve ordinary incomplete-Need guidance; corrected sources retain K3 guidance.
begin;

do $ordinary_blocker$
declare
  definition text;
  original text := $old$v_row_blockers:=jsonb_build_array('Nguồn nhu cầu chưa đầy đủ hoặc đã thay đổi. Tải lại và kiểm tra trước khi phân bổ.');$old$;
  replacement text := $new$v_row_blockers:=case when v_post_release then
        jsonb_build_array('Nguồn nhu cầu chưa đầy đủ hoặc đã thay đổi. Tải lại và kiểm tra trước khi phân bổ.')
      else jsonb_build_array('Hoàn tất xác nhận nhu cầu trước khi phân bổ NCC.') end;$new$;
begin
  definition := pg_get_functiondef('atlas_api.get_confirmed_supplier_allocation_workbench(jsonb)'::regprocedure);
  if position(original in definition)=0 then
    raise exception 'K3 ordinary blocker source anchor changed';
  end if;
  execute replace(definition,original,replacement);
end $ordinary_blocker$;

commit;
