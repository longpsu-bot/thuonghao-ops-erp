-- Owner-reviewed master-data resolution: Dish display names are type-scoped.
-- Distinct Dish Types may legitimately use the same operator-facing Dish name.
-- Same-type duplicate active names remain ambiguous and fail closed.
set role atlas_owner;

do $owner_reviewed_dish_identity$
declare
  v_definition text;
  v_old constant text := $old$   if exists(select 1 from atlas_admin.dishes x where x.dish_id<>dish and (x.dish_code=r->>'dish_code' or (x.dish_status='ACTIVE' and r->>'dish_status'='ACTIVE' and lower(btrim(x.dish_name))=lower(btrim(r->>'dish_name'))))) or
      (select count(*) from jsonb_array_elements(snapshot#>'{records,dishes}') x where x.value->>'dish_status'='ACTIVE' and lower(btrim(x.value->>'dish_name'))=lower(btrim(r->>'dish_name')))>1 then code:='DISH_IDENTITY_CONFLICT'; end if;$old$;
  v_new constant text := $new$   if exists(select 1 from atlas_admin.dishes x where x.dish_id<>dish and (x.dish_code=r->>'dish_code' or (x.dish_status='ACTIVE' and r->>'dish_status'='ACTIVE' and x.dish_type_id=(v->>'dish_type_id')::uuid and lower(btrim(x.dish_name))=lower(btrim(r->>'dish_name'))))) or
      (select count(*) from jsonb_array_elements(snapshot#>'{records,dishes}') x where x.value->>'dish_status'='ACTIVE' and x.value->>'dish_type_legacy_id'=r->>'dish_type_legacy_id' and lower(btrim(x.value->>'dish_name'))=lower(btrim(r->>'dish_name')))>1 then code:='DISH_IDENTITY_CONFLICT'; end if;$new$;
begin
  select pg_get_functiondef('atlas_legacy.master_import_recipe_plan(jsonb)'::regprocedure)
    into v_definition;
  if strpos(v_definition,v_old)=0 then
    raise exception 'OWNER_REVIEWED_DISH_IDENTITY_PREDECESSOR_DRIFT';
  end if;
  if strpos(substr(v_definition,strpos(v_definition,v_old)+char_length(v_old)),v_old)>0 then
    raise exception 'OWNER_REVIEWED_DISH_IDENTITY_PREDECESSOR_AMBIGUOUS';
  end if;
  execute replace(v_definition,v_old,v_new);
end
$owner_reviewed_dish_identity$;

comment on function atlas_legacy.master_import_recipe_plan(jsonb) is
  'Private OPS v1 master Recipe/Dish planner. Active Dish display names are unique only within Dish Type; source ID remains migration identity.';

reset role;
