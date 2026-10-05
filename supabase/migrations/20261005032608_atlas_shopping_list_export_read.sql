-- Shopping List V1 export projection. Same RMVP-05 read authorization and
-- pagination; only advice names are added. No table, writer or lifecycle.
begin;
reset role;
grant atlas_owner,atlas_confirmed_need_review_runtime to postgres with set true;
set role atlas_owner;
grant create on schema atlas_api to atlas_confirmed_need_review_runtime;
create function atlas_api.get_confirmed_need_shopping_list_export(request jsonb)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_review jsonb; v_advice jsonb;
begin
  v_review := atlas_api.get_confirmed_need_review(request);
  if not coalesce((v_review->>'success')::boolean,false) then return v_review; end if;
  select coalesce(jsonb_object_agg(line->>'confirmed_need_line_id',
    coalesce(atlas_core.purchase_review_supplier_advice(
      (line->>'service_date')::date,(line#>>'{ingredient,id}')::uuid,
      coalesce(line->>'confirmed_quantity_after',line->>'proposed_confirmed_quantity')::numeric
    )#>>'{recommendation,supplier_name}','')),'{}'::jsonb)
    into v_advice from jsonb_array_elements(v_review#>'{workbench,lines}') line;
  return v_review || jsonb_build_object('shopping_list_supplier_advice',v_advice);
exception when others then
  return atlas_core.rmvp_05_error(request,'get_confirmed_need_shopping_list_export',
    'INTERNAL_READ_FAILURE','The Shopping List could not be returned safely.',true);
end; $$;
reset role;
alter function atlas_api.get_confirmed_need_shopping_list_export(jsonb)
  owner to atlas_confirmed_need_review_runtime;
set role atlas_confirmed_need_review_runtime;
revoke all on function atlas_api.get_confirmed_need_shopping_list_export(jsonb)
  from public,anon,authenticated,service_role;
grant execute on function atlas_api.get_confirmed_need_shopping_list_export(jsonb) to authenticated;
comment on function atlas_api.get_confirmed_need_shopping_list_export(jsonb) is
  'ATLAS_SHOPPING_LIST_V1: authorized complete-page export advice; read-only, no Supplier allocation.';
notify pgrst,'reload schema';
reset role;
set role atlas_owner;
revoke create on schema atlas_api from atlas_confirmed_need_review_runtime;
reset role;
grant atlas_owner,atlas_confirmed_need_review_runtime to postgres with set false;
commit;
