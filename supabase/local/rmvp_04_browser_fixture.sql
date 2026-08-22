do $$
begin
  drop table if exists extensions.pantry_02_downstream_baseline;

  insert into atlas_admin.ingredients (
    ingredient_id,
    ingredient_code,
    ingredient_name,
    ingredient_group,
    ingredient_status,
    purchase_unit_id,
    ingredient_type,
    shopping_type,
    order_step
  )
  select
    'b6400000-0000-0000-0000-000000000050'::uuid,
    'rmvp05-browser-pantry',
    'RMVP-05 browser pantry ingredient',
    'LOCAL_ACCEPTANCE',
    'ACTIVE',
    unit.unit_id,
    'LOCAL_ACCEPTANCE',
    'LOCAL_ACCEPTANCE',
    0.000001
  from atlas_admin.units unit
  where unit.unit_status = 'ACTIVE'
  order by unit.unit_id
  limit 1
  on conflict (ingredient_code) do nothing;

end;
$$;
