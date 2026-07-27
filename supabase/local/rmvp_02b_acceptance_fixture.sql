do $rmvp_02b_fixture$
begin

insert into atlas_admin.customers (
  customer_id, customer_code, customer_name, customer_type
) values (
  'b6200000-0000-0000-0000-000000000100',
  'RMVP02B-LOCAL-SCHOOL',
  'RMVP-02B Synthetic Local School Customer',
  'SCHOOL_CATERING'
)
on conflict (customer_id) do nothing;

insert into atlas_admin.delivery_locations (
  delivery_location_id, customer_id, location_code, location_name,
  address_text, timezone_name
) values (
  'b6200000-0000-0000-0000-000000000101',
  'b6200000-0000-0000-0000-000000000100',
  'rmvp02b-local-location',
  'RMVP-02B Synthetic Local Location',
  'Synthetic local-only address',
  'Asia/Ho_Chi_Minh'
)
on conflict (delivery_location_id) do nothing;

insert into atlas_admin.school_types (
  school_type_id, school_type_code, school_type_name
) values (
  'b6200000-0000-0000-0000-000000000110',
  'rmvp02b-local-primary',
  'RMVP-02B Local Primary'
)
on conflict (school_type_id) do nothing;

insert into atlas_admin.schools (
  school_id, customer_id, school_code, school_name, school_type_id,
  default_delivery_location_id, display_order
) values (
  'b6200000-0000-0000-0000-000000000120',
  'b6200000-0000-0000-0000-000000000100',
  'rmvp02b-local-school',
  'RMVP-02B Synthetic Local School',
  'b6200000-0000-0000-0000-000000000110',
  'b6200000-0000-0000-0000-000000000101',
  6200
)
on conflict (school_id) do nothing;

insert into atlas_admin.units (
  unit_id, unit_code, unit_name, dimension_code, decimal_scale
) values (
  'b6200000-0000-0000-0000-000000000200',
  'rmvp02b-local-kg',
  'RMVP-02B Local Kilogram',
  'MASS',
  3
)
on conflict (unit_id) do nothing;

insert into atlas_admin.ingredients (
  ingredient_id, ingredient_code, ingredient_name, ingredient_group,
  purchase_unit_id, ingredient_type, shopping_type, order_step
) values
  (
    'b6200000-0000-0000-0000-000000000210',
    'rmvp02b-local-base',
    'RMVP-02B Local Base Ingredient',
    'Acceptance',
    'b6200000-0000-0000-0000-000000000200',
    'Food',
    'Planned',
    1
  ),
  (
    'b6200000-0000-0000-0000-000000000211',
    'rmvp02b-local-substitute',
    'RMVP-02B Local Substitute Ingredient',
    'Acceptance',
    'b6200000-0000-0000-0000-000000000200',
    'Food',
    'Planned',
    1
  ),
  (
    'b6200000-0000-0000-0000-000000000212',
    'rmvp02b-local-base-b',
    'RMVP-02B Local Base Ingredient B',
    'Acceptance',
    'b6200000-0000-0000-0000-000000000200',
    'Food',
    'Planned',
    1
  ),
  (
    'b6200000-0000-0000-0000-000000000213',
    'rmvp02b-local-substitute-b',
    'RMVP-02B Local Substitute Ingredient B',
    'Acceptance',
    'b6200000-0000-0000-0000-000000000200',
    'Food',
    'Planned',
    1
  ),
  (
    'b6200000-0000-0000-0000-000000000214',
    'rmvp02b-local-base-c',
    'RMVP-02B Local Base Ingredient C',
    'Acceptance',
    'b6200000-0000-0000-0000-000000000200',
    'Food',
    'Planned',
    1
  ),
  (
    'b6200000-0000-0000-0000-000000000215',
    'rmvp02b-local-substitute-c',
    'RMVP-02B Local Substitute Ingredient C',
    'Acceptance',
    'b6200000-0000-0000-0000-000000000200',
    'Food',
    'Planned',
    1
  ),
  (
    'b6200000-0000-0000-0000-000000000216',
    'rmvp02b-local-base-d',
    'RMVP-02B Local Base Ingredient D',
    'Acceptance',
    'b6200000-0000-0000-0000-000000000200',
    'Food',
    'Planned',
    1
  ),
  (
    'b6200000-0000-0000-0000-000000000217',
    'rmvp02b-local-base-e',
    'RMVP-02B Local Base Ingredient E',
    'Acceptance',
    'b6200000-0000-0000-0000-000000000200',
    'Food',
    'Planned',
    1
  ),
  (
    'b6200000-0000-0000-0000-000000000218',
    'rmvp02b-local-base-f',
    'RMVP-02B Local Base Ingredient F',
    'Acceptance',
    'b6200000-0000-0000-0000-000000000200',
    'Food',
    'Planned',
    1
  ),
  (
    'b6200000-0000-0000-0000-000000000219',
    'rmvp02b-local-substitute-f',
    'RMVP-02B Local Substitute Ingredient F',
    'Acceptance',
    'b6200000-0000-0000-0000-000000000200',
    'Food',
    'Planned',
    1
  ),
  (
    'b6200000-0000-0000-0000-000000000220',
    'rmvp02b-local-system-add',
    'RMVP-02B Local System Add Ingredient',
    'Acceptance',
    'b6200000-0000-0000-0000-000000000200',
    'Food',
    'Planned',
    1
  ),
  (
    'b6200000-0000-0000-0000-000000000221',
    'rmvp02b-local-school-dish-add',
    'RMVP-02B Local School Dish Add Ingredient',
    'Acceptance',
    'b6200000-0000-0000-0000-000000000200',
    'Food',
    'Planned',
    1
  )
on conflict (ingredient_id) do nothing;

end;
$rmvp_02b_fixture$;
