begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
select no_plan();

-- Codes deliberately disagree with names; equal names also exercise UUID ties.
insert into atlas_core.actors (actor_id, actor_type, display_name)
values ('ed110000-0000-4000-8000-000000000001', 'HUMAN', 'School order test');
insert into atlas_admin.customers (customer_id, customer_code, customer_name, customer_type)
values ('ed110000-0000-4000-8000-000000000002', 'school-order', 'School order', 'SCHOOL_CATERING');
insert into atlas_admin.delivery_locations (
  delivery_location_id, customer_id, location_code, location_name, address_text
) values (
  'ed110000-0000-4000-8000-000000000003', 'ed110000-0000-4000-8000-000000000002',
  'school-order', 'School order', 'Local test'
);
insert into atlas_admin.schools (
  school_id, customer_id, school_code, school_name, default_delivery_location_id, display_order
) select id::uuid, 'ed110000-0000-4000-8000-000000000002', code, name,
  'ed110000-0000-4000-8000-000000000003', ord
from (values
  ('ed110000-0000-4000-8000-000000000010', 'order-z', 'Zulu', 1),
  ('ed110000-0000-4000-8000-000000000011', 'order-y', 'Alpha', 2),
  ('ed110000-0000-4000-8000-000000000012', 'order-x', 'Alpha', 2),
  ('ed110000-0000-4000-8000-000000000013', 'order-a', 'Beta', 2),
  ('ed110000-0000-4000-8000-000000000014', 'order-b', 'Tail', 99)
) fixture(id, code, name, ord);

create temporary table expected_school_order as
select jsonb_agg(school_id::text order by display_order, school_name, school_id) ids
from atlas_admin.schools where customer_id = 'ed110000-0000-4000-8000-000000000002';

select is(
  (select jsonb_agg(s->>'school_id' order by ord)
   from jsonb_array_elements(atlas_core.rmvp_03a_planning_workbench_payload('2026-10-12')->'schools') with ordinality item(s, ord)
   where s->>'school_code' like 'order-%'),
  (select ids from expected_school_order),
  'Planning School catalogue uses display order, name, stable identity instead of code'
);
select is(
  (select jsonb_agg(s->>'school_id' order by ord)
   from jsonb_array_elements(atlas_core.pantry_02_workbench_payload('2026-10-12', 'ed110000-0000-4000-8000-000000000001')->'schools') with ordinality item(s, ord)
   where s->>'school_code' like 'order-%'),
  (select ids from expected_school_order),
  'Pantry wrapper retains canonical School catalogue order'
);
select is(
  (select jsonb_agg(s->>'school_id' order by ord)
   from jsonb_array_elements(atlas_core.rmvp_03a_default_attendance_rows('2026-10-12')) with ordinality item(s, ord)
   where s->>'service_date' = '2026-10-12' and s->>'school_id' like 'ed110000-%'),
  (select ids from expected_school_order),
  'Default Attendance preview follows the same canonical School order'
);

insert into atlas_admin.dishes (dish_id, dish_code, dish_name, dish_type_id, requires_need_generation)
values ('ed110000-0000-4000-8000-000000000020', 'school-order-dish', 'School order dish', 'd1500000-0000-4000-8000-000000000001', false);
insert into atlas_planning.weekly_menus (
  weekly_menu_id, week_start, week_end, source_type, source_name, source_signature, imported_by_actor_id
) values (
  'ed110000-0000-4000-8000-000000000021', '2026-10-12', '2026-10-18',
  'GOOGLE_SHEET', 'School order', 'school-order', 'ed110000-0000-4000-8000-000000000001'
);
insert into atlas_planning.weekly_menu_lines (
  weekly_menu_id, school_id, service_date, menu_slot_code, dish_id, created_by_actor_id, updated_by_actor_id
) select 'ed110000-0000-4000-8000-000000000021', school_id, '2026-10-12', 'soup',
  'ed110000-0000-4000-8000-000000000020', 'ed110000-0000-4000-8000-000000000001', 'ed110000-0000-4000-8000-000000000001'
from atlas_admin.schools where customer_id = 'ed110000-0000-4000-8000-000000000002';
insert into atlas_planning.attendance_batches (
  attendance_batch_id, period_start, period_end, source_type, source_name, source_signature, imported_by_actor_id
) values (
  'ed110000-0000-4000-8000-000000000022', '2026-10-12', '2026-10-18',
  'SCHOOL_DEFAULTS', 'School order', 'school-order', 'ed110000-0000-4000-8000-000000000001'
);
insert into atlas_planning.attendance_lines (
  attendance_batch_id, school_id, service_date, student_portions, teacher_portions, created_by_actor_id, updated_by_actor_id
) select 'ed110000-0000-4000-8000-000000000022', school_id, '2026-10-12', 100, 10,
  'ed110000-0000-4000-8000-000000000001', 'ed110000-0000-4000-8000-000000000001'
from atlas_admin.schools where customer_id = 'ed110000-0000-4000-8000-000000000002';

select is(
  (select jsonb_agg(s->>'school_id' order by ord)
   from jsonb_array_elements(atlas_core.rmvp_03a_planning_workbench_payload('2026-10-12')#>'{weekly_menu,lines}') with ordinality item(s, ord)),
  (select ids from expected_school_order),
  'Weekly Menu lines use canonical School order without changing line identity'
);
select is(
  (select jsonb_agg(s->>'school_id' order by ord)
   from jsonb_array_elements(atlas_core.rmvp_03a_planning_workbench_payload('2026-10-12')#>'{attendance,lines}') with ordinality item(s, ord)),
  (select ids from expected_school_order),
  'Attendance lines use canonical School order without changing quantities'
);
select ok(
  (select bool_and(
    p.proconfig = array['search_path=""']::text[]
    and not has_function_privilege('authenticated', p.oid, 'execute')
    and not has_function_privilege('anon', p.oid, 'execute')
    and not has_function_privilege('service_role', p.oid, 'execute')
  ) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'atlas_core' and p.proname in (
     'rmvp_03a_planning_workbench_payload', 'rmvp_03a_default_attendance_rows', 'direct_need_legacy_pantry_workbench_payload'
   )),
  'Ordering-only replacements retain fixed search paths and private privilege boundaries'
);

select * from finish();
rollback;
