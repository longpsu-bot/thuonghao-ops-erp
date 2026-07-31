begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;

select plan(76);

insert into atlas_core.actors (actor_id, actor_type, display_name) values
  ('b5200000-0000-0000-0000-000000000001', 'HUMAN', 'H0A5b lineage generator'),
  ('b5200000-0000-0000-0000-000000000002', 'HUMAN', 'H0A5b lineage approver');
insert into atlas_admin.customers (customer_id, customer_code, customer_name, customer_type)
values ('b5200000-0000-0000-0000-000000000100', 'pa06e-h0a5b-lineage-customer', 'H0A5b lineage customer', 'SCHOOL_CATERING');
insert into atlas_admin.delivery_locations (delivery_location_id, customer_id, location_code, location_name, address_text, timezone_name)
values ('b5200000-0000-0000-0000-000000000101', 'b5200000-0000-0000-0000-000000000100', 'pa06e-h0a5b-lineage-location', 'H0A5b lineage location', 'Local-only fixture', 'Asia/Ho_Chi_Minh');
insert into atlas_admin.school_types (school_type_id, school_type_code, school_type_name)
values ('b5200000-0000-0000-0000-000000000110', 'pa06e-h0a5b-lineage-type', 'H0A5b lineage type');
insert into atlas_admin.schools (school_id, customer_id, school_code, school_name, school_type_id, default_delivery_location_id, display_order)
values ('b5200000-0000-0000-0000-000000000120', 'b5200000-0000-0000-0000-000000000100', 'pa06e-h0a5b-lineage-school', 'H0A5b Lineage School', 'b5200000-0000-0000-0000-000000000110', 'b5200000-0000-0000-0000-000000000101', 10);
insert into atlas_admin.units (unit_id, unit_code, unit_name, dimension_code)
values ('b5200000-0000-0000-0000-000000000130', 'kg-h0a5b-lineage', 'kilogram H0A5b lineage', 'mass');
insert into atlas_admin.ingredients (ingredient_id, ingredient_code, ingredient_name) values
  ('b5200000-0000-0000-0000-000000000140', 'h0a5b-lineage-rice', 'H0A5b lineage rice'),
  ('b5200000-0000-0000-0000-000000000141', 'h0a5b-lineage-salt', 'H0A5b lineage salt'),
  ('b5200000-0000-0000-0000-000000000142', 'h0a5b-lineage-pepper', 'H0A5b lineage pepper');
insert into atlas_admin.dishes (dish_id, dish_code, dish_name, dish_status, display_order, requires_need_generation)
values ('b5200000-0000-0000-0000-000000000150', 'h0a5b-lineage-dish', 'H0A5b lineage dish', 'ACTIVE', 10, true);
insert into atlas_admin.recipes (recipe_id, dish_id)
values ('b5200000-0000-0000-0000-000000000160', 'b5200000-0000-0000-0000-000000000150');
insert into atlas_admin.recipe_versions (recipe_version_id, recipe_id, version_number, basis_portions, created_by_actor_id)
values ('b5200000-0000-0000-0000-000000000161', 'b5200000-0000-0000-0000-000000000160', 1, 100, 'b5200000-0000-0000-0000-000000000001');
insert into atlas_admin.recipe_lines (recipe_line_id, recipe_id, line_code)
values
  ('b5200000-0000-0000-0000-000000000162', 'b5200000-0000-0000-0000-000000000160', 'rice'),
  ('b5200000-0000-0000-0000-000000000174', 'b5200000-0000-0000-0000-000000000160', 'pepper');
insert into atlas_admin.recipe_line_revisions (recipe_line_revision_id, recipe_id, recipe_version_id, recipe_line_id, line_revision_number, ingredient_id, quantity_per_basis, unit_id, created_by_actor_id)
values
  ('b5200000-0000-0000-0000-000000000163', 'b5200000-0000-0000-0000-000000000160', 'b5200000-0000-0000-0000-000000000161', 'b5200000-0000-0000-0000-000000000162', 1, 'b5200000-0000-0000-0000-000000000140', 10, 'b5200000-0000-0000-0000-000000000130', 'b5200000-0000-0000-0000-000000000001'),
  ('b5200000-0000-0000-0000-000000000175', 'b5200000-0000-0000-0000-000000000160', 'b5200000-0000-0000-0000-000000000161', 'b5200000-0000-0000-0000-000000000174', 1, 'b5200000-0000-0000-0000-000000000142', 2, 'b5200000-0000-0000-0000-000000000130', 'b5200000-0000-0000-0000-000000000001');
set constraints all immediate;
set constraints all deferred;
update atlas_admin.recipe_versions set recipe_version_status = 'VALIDATED', validated_by_actor_id = 'b5200000-0000-0000-0000-000000000002', validated_at = timestamptz '2026-12-01 07:00:00+07' where recipe_version_id = 'b5200000-0000-0000-0000-000000000161';
update atlas_admin.recipe_versions set recipe_version_status = 'RELEASED_FOR_PLANNING', released_by_actor_id = 'b5200000-0000-0000-0000-000000000002', released_at = timestamptz '2026-12-01 07:01:00+07' where recipe_version_id = 'b5200000-0000-0000-0000-000000000161';

insert into atlas_planning.weekly_menus (weekly_menu_id, week_start, week_end, source_type, source_name, source_signature, row_count, imported_by_actor_id)
values ('b5200000-0000-0000-0000-000000000200', date '2026-12-07', date '2026-12-13', 'FIXTURE', 'H0A5b lineage menu', 'sha256:h0a5b-lineage-menu', 1, 'b5200000-0000-0000-0000-000000000001');
insert into atlas_planning.weekly_menu_lines (weekly_menu_line_id, weekly_menu_id, school_id, service_date, menu_slot_code, dish_id, created_by_actor_id, updated_by_actor_id)
values ('b5200000-0000-0000-0000-000000000210', 'b5200000-0000-0000-0000-000000000200', 'b5200000-0000-0000-0000-000000000120', date '2026-12-07', 'savory', 'b5200000-0000-0000-0000-000000000150', 'b5200000-0000-0000-0000-000000000001', 'b5200000-0000-0000-0000-000000000001');
update atlas_planning.weekly_menus set weekly_menu_status = 'VALIDATED' where weekly_menu_id = 'b5200000-0000-0000-0000-000000000200';
insert into atlas_planning.weekly_menu_approval_snapshots (weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version, approved_by_actor_id, approved_at)
values ('b5200000-0000-0000-0000-000000000220', 'b5200000-0000-0000-0000-000000000200', 1, 'b5200000-0000-0000-0000-000000000002', timestamptz '2026-12-01 08:00:00+07');
insert into atlas_planning.weekly_menu_approval_snapshot_lines (weekly_menu_approval_snapshot_line_id, weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version, weekly_menu_line_id, school_id, service_date, menu_slot_code, dish_id)
values ('b5200000-0000-0000-0000-000000000221', 'b5200000-0000-0000-0000-000000000220', 'b5200000-0000-0000-0000-000000000200', 1, 'b5200000-0000-0000-0000-000000000210', 'b5200000-0000-0000-0000-000000000120', date '2026-12-07', 'savory', 'b5200000-0000-0000-0000-000000000150');
update atlas_planning.weekly_menus set weekly_menu_status = 'APPROVED', latest_approved_by_actor_id = 'b5200000-0000-0000-0000-000000000002', latest_approved_at = timestamptz '2026-12-01 08:00:00+07', latest_approval_snapshot_id = 'b5200000-0000-0000-0000-000000000220' where weekly_menu_id = 'b5200000-0000-0000-0000-000000000200';

insert into atlas_planning.attendance_batches (attendance_batch_id, period_start, period_end, source_type, source_name, source_signature, row_count, imported_by_actor_id)
values ('b5200000-0000-0000-0000-000000000300', date '2026-12-07', date '2026-12-13', 'FIXTURE', 'H0A5b lineage attendance', 'sha256:h0a5b-lineage-attendance', 1, 'b5200000-0000-0000-0000-000000000001');
insert into atlas_planning.attendance_lines (attendance_line_id, attendance_batch_id, school_id, service_date, student_portions, teacher_portions, created_by_actor_id, updated_by_actor_id)
values ('b5200000-0000-0000-0000-000000000310', 'b5200000-0000-0000-0000-000000000300', 'b5200000-0000-0000-0000-000000000120', date '2026-12-07', 90, 10, 'b5200000-0000-0000-0000-000000000001', 'b5200000-0000-0000-0000-000000000001');
update atlas_planning.attendance_batches set attendance_status = 'VALIDATED' where attendance_batch_id = 'b5200000-0000-0000-0000-000000000300';
insert into atlas_planning.attendance_approval_snapshots (attendance_approval_snapshot_id, attendance_batch_id, attendance_version, approved_by_actor_id, approved_at)
values ('b5200000-0000-0000-0000-000000000320', 'b5200000-0000-0000-0000-000000000300', 1, 'b5200000-0000-0000-0000-000000000002', timestamptz '2026-12-01 08:05:00+07');
insert into atlas_planning.attendance_approval_snapshot_lines (attendance_approval_snapshot_line_id, attendance_approval_snapshot_id, attendance_batch_id, attendance_version, attendance_line_id, school_id, service_date, student_portions, teacher_portions)
values ('b5200000-0000-0000-0000-000000000321', 'b5200000-0000-0000-0000-000000000320', 'b5200000-0000-0000-0000-000000000300', 1, 'b5200000-0000-0000-0000-000000000310', 'b5200000-0000-0000-0000-000000000120', date '2026-12-07', 90, 10);
update atlas_planning.attendance_batches set attendance_status = 'APPROVED', latest_approved_by_actor_id = 'b5200000-0000-0000-0000-000000000002', latest_approved_at = timestamptz '2026-12-01 08:05:00+07', latest_approval_snapshot_id = 'b5200000-0000-0000-0000-000000000320' where attendance_batch_id = 'b5200000-0000-0000-0000-000000000300';

insert into atlas_planning.pantry_need_batches (pantry_need_batch_id, week_start, source_signature, no_additions_confirmed, requesting_actor_id)
values ('b5200000-0000-0000-0000-000000000330', date '2026-12-07', repeat('f', 64), true, 'b5200000-0000-0000-0000-000000000001');
update atlas_planning.pantry_need_batches set pantry_need_batch_status = 'VALIDATED', version = 2, updated_at = updated_at + interval '1 second' where pantry_need_batch_id = 'b5200000-0000-0000-0000-000000000330';
insert into atlas_planning.pantry_need_approval_snapshots (pantry_need_approval_snapshot_id, pantry_need_batch_id, approved_batch_version, approved_by_actor_id, approved_at, source_signature, no_additions_confirmed, line_count)
values ('b5200000-0000-0000-0000-000000000332', 'b5200000-0000-0000-0000-000000000330', 3, 'b5200000-0000-0000-0000-000000000002', timestamptz '2026-12-01 08:07:00+07', repeat('f', 64), true, 0);
update atlas_planning.pantry_need_batches set pantry_need_batch_status = 'APPROVED', version = 3, latest_approved_by_actor_id = 'b5200000-0000-0000-0000-000000000002', latest_approved_at = timestamptz '2026-12-01 08:07:00+07', latest_approval_snapshot_id = 'b5200000-0000-0000-0000-000000000332', updated_at = updated_at + interval '1 second' where pantry_need_batch_id = 'b5200000-0000-0000-0000-000000000330';
set constraints all immediate;
set constraints all deferred;

insert into atlas_planning.planning_input_sets (planning_input_set_id, period_start, period_end, readiness_status, current_evaluation_id)
values ('b5200000-0000-0000-0000-000000000400', date '2026-12-07', date '2026-12-07', 'READY', 'b5200000-0000-0000-0000-000000000401');
insert into atlas_planning.planning_input_evaluations (planning_input_evaluation_id, planning_input_set_id, evaluation_version, evaluation_result, weekly_menu_id, weekly_menu_version, weekly_menu_approval_snapshot_id, attendance_batch_id, attendance_version, attendance_approval_snapshot_id, pantry_need_batch_id, pantry_need_batch_version, pantry_need_approval_snapshot_id, blocking_issue_count, warning_count, evaluated_by_actor_id, evaluated_at)
values ('b5200000-0000-0000-0000-000000000401', 'b5200000-0000-0000-0000-000000000400', 1, 'READY', 'b5200000-0000-0000-0000-000000000200', 1, 'b5200000-0000-0000-0000-000000000220', 'b5200000-0000-0000-0000-000000000300', 1, 'b5200000-0000-0000-0000-000000000320', 'b5200000-0000-0000-0000-000000000330', 3, 'b5200000-0000-0000-0000-000000000332', 0, 0, 'b5200000-0000-0000-0000-000000000001', timestamptz '2026-12-01 08:10:00+07');
set constraints all immediate;
set constraints all deferred;
update atlas_planning.planning_input_sets set readiness_status = 'NEED_GENERATION_REQUESTED', updated_at = updated_at + interval '1 second' where planning_input_set_id = 'b5200000-0000-0000-0000-000000000400';

insert into atlas_planning.need_generation_calculation_contracts (need_generation_calculation_contract_id, contract_code, current_revision_id, version)
values ('b5200000-0000-0000-0000-000000000700', 'school_catering_proportional_per_basis', 'b5200000-0000-0000-0000-000000000701', 1);
insert into atlas_planning.need_generation_calculation_contract_revisions (need_generation_calculation_contract_revision_id, need_generation_calculation_contract_id, revision_number, formula_kind, quantity_precision, quantity_scale, factor_precision, factor_scale, final_coercion_mode, approved_by_actor_id, approved_at)
values ('b5200000-0000-0000-0000-000000000701', 'b5200000-0000-0000-0000-000000000700', 1, 'STUDENT_TEACHER_PORTIONS_X_RECIPE_QTY_DIV_BASIS', 20, 6, 24, 12, 'POSTGRES_NUMERIC_SCALE_HALF_AWAY_FROM_ZERO', 'b5200000-0000-0000-0000-000000000002', timestamptz '2026-12-01 06:00:00+07');
set constraints all immediate;
set constraints all deferred;

create function pg_temp.h0a5b_run_shell(
  p_run uuid, p_snapshot uuid, p_selection uuid, p_attempt bigint,
  p_predecessor uuid, p_recipe_version uuid, p_recipe_number integer,
  p_line_count integer, p_blocker_count integer
) returns void language plpgsql as $$
begin
  insert into atlas_planning.need_generation_runs (need_generation_run_id, planning_input_set_id, planning_input_evaluation_id, evaluation_version, period_start, period_end, attempt_ordinal, predecessor_need_generation_run_id, input_snapshot_id, run_status, version, generated_line_count, blocking_issue_count, warning_count, generated_by_actor_id, generated_at, updated_at)
  values (p_run, 'b5200000-0000-0000-0000-000000000400', 'b5200000-0000-0000-0000-000000000401', 1, date '2026-12-07', date '2026-12-07', p_attempt, p_predecessor, p_snapshot, 'GENERATED', 1, p_line_count, p_blocker_count, 0, 'b5200000-0000-0000-0000-000000000001', timestamptz '2026-12-01 10:00:00+07' + p_attempt * interval '1 hour', timestamptz '2026-12-01 10:00:00+07' + p_attempt * interval '1 hour');
  insert into atlas_planning.need_generation_input_snapshots (need_generation_input_snapshot_id, need_generation_run_id, planning_input_set_id, planning_input_evaluation_id, evaluation_version, weekly_menu_id, weekly_menu_version, weekly_menu_approval_snapshot_id, attendance_batch_id, attendance_version, attendance_approval_snapshot_id, need_generation_calculation_contract_id, need_generation_calculation_contract_revision_id, calculation_contract_revision_number, captured_at)
  values (p_snapshot, p_run, 'b5200000-0000-0000-0000-000000000400', 'b5200000-0000-0000-0000-000000000401', 1, 'b5200000-0000-0000-0000-000000000200', 1, 'b5200000-0000-0000-0000-000000000220', 'b5200000-0000-0000-0000-000000000300', 1, 'b5200000-0000-0000-0000-000000000320', 'b5200000-0000-0000-0000-000000000700', 'b5200000-0000-0000-0000-000000000701', 1, timestamptz '2026-12-01 10:00:00+07' + p_attempt * interval '1 hour');
  insert into atlas_planning.need_generation_recipe_selections (need_generation_recipe_selection_id, need_generation_input_snapshot_id, need_generation_run_id, weekly_menu_approval_snapshot_line_id, weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version, weekly_menu_line_id, school_id, school_type_id, dish_id, recipe_id, recipe_version_id, recipe_version_number, selection_scope, selected_at)
  values (p_selection, p_snapshot, p_run, 'b5200000-0000-0000-0000-000000000221', 'b5200000-0000-0000-0000-000000000220', 'b5200000-0000-0000-0000-000000000200', 1, 'b5200000-0000-0000-0000-000000000210', 'b5200000-0000-0000-0000-000000000120', 'b5200000-0000-0000-0000-000000000110', 'b5200000-0000-0000-0000-000000000150', 'b5200000-0000-0000-0000-000000000160', p_recipe_version, p_recipe_number, 'GENERAL', timestamptz '2026-12-01 10:00:00+07' + p_attempt * interval '1 hour');
end;
$$;

create function pg_temp.h0a5b_use(p_use uuid, p_run uuid, p_snapshot uuid, p_selection uuid, p_recipe_version uuid, p_line uuid, p_revision uuid)
returns void language sql as $$
  insert into atlas_planning.need_generation_recipe_line_uses (need_generation_recipe_line_use_id, need_generation_input_snapshot_id, need_generation_run_id, need_generation_recipe_selection_id, recipe_id, recipe_version_id, recipe_line_id, recipe_line_revision_id, captured_at)
  values (p_use, p_snapshot, p_run, p_selection, 'b5200000-0000-0000-0000-000000000160', p_recipe_version, p_line, p_revision, timestamptz '2026-12-01 10:00:00+07')
$$;

create function pg_temp.h0a5b_line(p_id uuid, p_run uuid, p_snapshot uuid, p_selection uuid, p_use uuid, p_recipe_version uuid, p_line uuid, p_revision uuid, p_ingredient uuid, p_predecessor_run uuid, p_predecessor_line uuid, p_disposition text, p_quantity numeric)
returns void language sql as $$
  insert into atlas_planning.theoretical_need_lines (theoretical_need_line_id, need_generation_run_id, need_generation_input_snapshot_id, need_generation_recipe_selection_id, need_generation_recipe_line_use_id, weekly_menu_approval_snapshot_line_id, weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version, weekly_menu_line_id, attendance_approval_snapshot_line_id, attendance_approval_snapshot_id, attendance_batch_id, attendance_version, attendance_line_id, school_id, service_date, dish_id, recipe_id, recipe_version_id, recipe_line_id, recipe_line_revision_id, ingredient_id, unit_id, need_generation_calculation_contract_id, need_generation_calculation_contract_revision_id, calculation_contract_revision_number, predecessor_need_generation_run_id, predecessor_theoretical_need_line_id, line_disposition, theoretical_quantity, created_at)
  values (p_id, p_run, p_snapshot, p_selection, p_use, 'b5200000-0000-0000-0000-000000000221', 'b5200000-0000-0000-0000-000000000220', 'b5200000-0000-0000-0000-000000000200', 1, 'b5200000-0000-0000-0000-000000000210', 'b5200000-0000-0000-0000-000000000321', 'b5200000-0000-0000-0000-000000000320', 'b5200000-0000-0000-0000-000000000300', 1, 'b5200000-0000-0000-0000-000000000310', 'b5200000-0000-0000-0000-000000000120', date '2026-12-07', 'b5200000-0000-0000-0000-000000000150', 'b5200000-0000-0000-0000-000000000160', p_recipe_version, p_line, p_revision, p_ingredient, 'b5200000-0000-0000-0000-000000000130', 'b5200000-0000-0000-0000-000000000700', 'b5200000-0000-0000-0000-000000000701', 1, p_predecessor_run, p_predecessor_line, p_disposition, p_quantity, timestamptz '2026-12-01 10:00:00+07')
$$;

select throws_ok(
  $$
    select pg_temp.h0a5b_run_shell('b5200000-0000-0000-0000-000000000490', 'b5200000-0000-0000-0000-000000000491', 'b5200000-0000-0000-0000-000000000492', 1, null, 'b5200000-0000-0000-0000-000000000161', 1, 0, 0);
    select pg_temp.h0a5b_use('b5200000-0000-0000-0000-000000000493', 'b5200000-0000-0000-0000-000000000490', 'b5200000-0000-0000-0000-000000000491', 'b5200000-0000-0000-0000-000000000492', 'b5200000-0000-0000-0000-000000000161', 'b5200000-0000-0000-0000-000000000162', 'b5200000-0000-0000-0000-000000000163');
    select pg_temp.h0a5b_use('b5200000-0000-0000-0000-000000000494', 'b5200000-0000-0000-0000-000000000490', 'b5200000-0000-0000-0000-000000000491', 'b5200000-0000-0000-0000-000000000492', 'b5200000-0000-0000-0000-000000000161', 'b5200000-0000-0000-0000-000000000174', 'b5200000-0000-0000-0000-000000000175');
    set constraints all immediate
  $$,
  '23514',
  'every PRESENT RecipeLine use with exact Attendance requires one ACTIVE theoretical line or exact permitted blocker',
  'complete PRESENT composition and exact Attendance cannot silently omit theoretical output'
);
set constraints all deferred;

select pg_temp.h0a5b_run_shell('b5200000-0000-0000-0000-000000000500', 'b5200000-0000-0000-0000-000000000501', 'b5200000-0000-0000-0000-000000000510', 1, null, 'b5200000-0000-0000-0000-000000000161', 1, 2, 0);
select pg_temp.h0a5b_use('b5200000-0000-0000-0000-000000000520', 'b5200000-0000-0000-0000-000000000500', 'b5200000-0000-0000-0000-000000000501', 'b5200000-0000-0000-0000-000000000510', 'b5200000-0000-0000-0000-000000000161', 'b5200000-0000-0000-0000-000000000162', 'b5200000-0000-0000-0000-000000000163');
select pg_temp.h0a5b_use('b5200000-0000-0000-0000-000000000521', 'b5200000-0000-0000-0000-000000000500', 'b5200000-0000-0000-0000-000000000501', 'b5200000-0000-0000-0000-000000000510', 'b5200000-0000-0000-0000-000000000161', 'b5200000-0000-0000-0000-000000000174', 'b5200000-0000-0000-0000-000000000175');
select pg_temp.h0a5b_line('b5200000-0000-0000-0000-000000000530', 'b5200000-0000-0000-0000-000000000500', 'b5200000-0000-0000-0000-000000000501', 'b5200000-0000-0000-0000-000000000510', 'b5200000-0000-0000-0000-000000000520', 'b5200000-0000-0000-0000-000000000161', 'b5200000-0000-0000-0000-000000000162', 'b5200000-0000-0000-0000-000000000163', 'b5200000-0000-0000-0000-000000000140', null, null, 'ACTIVE', 10);
select pg_temp.h0a5b_line('b5200000-0000-0000-0000-000000000531', 'b5200000-0000-0000-0000-000000000500', 'b5200000-0000-0000-0000-000000000501', 'b5200000-0000-0000-0000-000000000510', 'b5200000-0000-0000-0000-000000000521', 'b5200000-0000-0000-0000-000000000161', 'b5200000-0000-0000-0000-000000000174', 'b5200000-0000-0000-0000-000000000175', 'b5200000-0000-0000-0000-000000000142', null, null, 'ACTIVE', 2);

select lives_ok($$ set constraints all immediate; set constraints all deferred $$, 'the first attempt stores one exact ACTIVE atomic contribution');
select lives_ok($$ update atlas_planning.need_generation_runs set run_status = 'VALIDATED', version = 2, validated_by_actor_id = 'b5200000-0000-0000-0000-000000000002', validated_at = timestamptz '2026-12-01 12:00:00+07', updated_at = timestamptz '2026-12-01 12:00:00+07' where need_generation_run_id = 'b5200000-0000-0000-0000-000000000500'; set constraints all immediate; set constraints all deferred $$, 'zero-blocker run validates');
select lives_ok(
  $$
    update atlas_planning.need_generation_runs set run_status = 'RELEASED_FOR_CONFIRMATION', version = 3, released_by_actor_id = 'b5200000-0000-0000-0000-000000000002', released_at = timestamptz '2026-12-01 12:05:00+07', updated_at = timestamptz '2026-12-01 12:05:00+07' where need_generation_run_id = 'b5200000-0000-0000-0000-000000000500';
    insert into atlas_planning.need_generation_release_snapshots (need_generation_release_snapshot_id, need_generation_run_id, released_run_version, need_generation_input_snapshot_id, released_by_actor_id, released_at, generated_line_count, active_line_count, removed_line_count, blocking_issue_count, warning_count) values ('b5200000-0000-0000-0000-000000000540', 'b5200000-0000-0000-0000-000000000500', 3, 'b5200000-0000-0000-0000-000000000501', 'b5200000-0000-0000-0000-000000000002', timestamptz '2026-12-01 12:05:00+07', 2, 2, 0, 0, 0);
    insert into atlas_planning.need_generation_release_snapshot_lines (need_generation_release_snapshot_line_id, need_generation_release_snapshot_id, need_generation_run_id, released_run_version, theoretical_need_line_id) values ('b5200000-0000-0000-0000-000000000541', 'b5200000-0000-0000-0000-000000000540', 'b5200000-0000-0000-0000-000000000500', 3, 'b5200000-0000-0000-0000-000000000530');
    insert into atlas_planning.need_generation_release_snapshot_lines (need_generation_release_snapshot_line_id, need_generation_release_snapshot_id, need_generation_run_id, released_run_version, theoretical_need_line_id) values ('b5200000-0000-0000-0000-000000000542', 'b5200000-0000-0000-0000-000000000540', 'b5200000-0000-0000-0000-000000000500', 3, 'b5200000-0000-0000-0000-000000000531');
    set constraints all immediate; set constraints all deferred
  $$,
  'release commits only with exact immutable header and complete membership'
);
select lives_ok($$ update atlas_planning.need_generation_runs set run_status = 'INVALIDATED', version = 4, invalidated_by_actor_id = 'b5200000-0000-0000-0000-000000000002', invalidated_at = timestamptz '2026-12-01 12:10:00+07', updated_at = timestamptz '2026-12-01 12:10:00+07' where need_generation_run_id = 'b5200000-0000-0000-0000-000000000500'; set constraints all immediate; set constraints all deferred $$, 'released evidence remains immutable when its run is later invalidated');

update atlas_admin.recipe_versions set recipe_version_status = 'LOCKED', locked_by_actor_id = 'b5200000-0000-0000-0000-000000000002', locked_at = timestamptz '2026-12-01 12:15:00+07' where recipe_version_id = 'b5200000-0000-0000-0000-000000000161';
insert into atlas_admin.recipe_versions (recipe_version_id, recipe_id, version_number, predecessor_recipe_version_id, basis_portions, created_by_actor_id)
values ('b5200000-0000-0000-0000-000000000164', 'b5200000-0000-0000-0000-000000000160', 2, 'b5200000-0000-0000-0000-000000000161', 100, 'b5200000-0000-0000-0000-000000000001');
insert into atlas_admin.recipe_lines (recipe_line_id, recipe_id, line_code)
values ('b5200000-0000-0000-0000-000000000167', 'b5200000-0000-0000-0000-000000000160', 'salt');
insert into atlas_admin.recipe_line_revisions (recipe_line_revision_id, recipe_id, recipe_version_id, recipe_line_id, line_revision_number, predecessor_recipe_line_revision_id, ingredient_id, quantity_per_basis, unit_id, line_disposition, created_by_actor_id)
values ('b5200000-0000-0000-0000-000000000165', 'b5200000-0000-0000-0000-000000000160', 'b5200000-0000-0000-0000-000000000164', 'b5200000-0000-0000-0000-000000000162', 2, 'b5200000-0000-0000-0000-000000000163', 'b5200000-0000-0000-0000-000000000140', 0, 'b5200000-0000-0000-0000-000000000130', 'REMOVED', 'b5200000-0000-0000-0000-000000000001');
insert into atlas_admin.recipe_line_revisions (recipe_line_revision_id, recipe_id, recipe_version_id, recipe_line_id, line_revision_number, ingredient_id, quantity_per_basis, unit_id, created_by_actor_id)
values ('b5200000-0000-0000-0000-000000000168', 'b5200000-0000-0000-0000-000000000160', 'b5200000-0000-0000-0000-000000000164', 'b5200000-0000-0000-0000-000000000167', 1, 'b5200000-0000-0000-0000-000000000141', 5, 'b5200000-0000-0000-0000-000000000130', 'b5200000-0000-0000-0000-000000000001');
insert into atlas_admin.recipe_line_revisions (recipe_line_revision_id, recipe_id, recipe_version_id, recipe_line_id, line_revision_number, predecessor_recipe_line_revision_id, ingredient_id, quantity_per_basis, unit_id, line_disposition, created_by_actor_id)
values ('b5200000-0000-0000-0000-000000000176', 'b5200000-0000-0000-0000-000000000160', 'b5200000-0000-0000-0000-000000000164', 'b5200000-0000-0000-0000-000000000174', 2, 'b5200000-0000-0000-0000-000000000175', 'b5200000-0000-0000-0000-000000000142', 0, 'b5200000-0000-0000-0000-000000000130', 'REMOVED', 'b5200000-0000-0000-0000-000000000001');
set constraints all immediate; set constraints all deferred;
update atlas_admin.recipe_versions set recipe_version_status = 'VALIDATED', validated_by_actor_id = 'b5200000-0000-0000-0000-000000000002', validated_at = timestamptz '2026-12-01 12:20:00+07' where recipe_version_id = 'b5200000-0000-0000-0000-000000000164';
update atlas_admin.recipe_versions set recipe_version_status = 'RELEASED_FOR_PLANNING', released_by_actor_id = 'b5200000-0000-0000-0000-000000000002', released_at = timestamptz '2026-12-01 12:21:00+07' where recipe_version_id = 'b5200000-0000-0000-0000-000000000164';
select pg_temp.h0a5b_run_shell('b5200000-0000-0000-0000-000000000600', 'b5200000-0000-0000-0000-000000000601', 'b5200000-0000-0000-0000-000000000610', 2, 'b5200000-0000-0000-0000-000000000500', 'b5200000-0000-0000-0000-000000000164', 2, 3, 0);
select pg_temp.h0a5b_use('b5200000-0000-0000-0000-000000000620', 'b5200000-0000-0000-0000-000000000600', 'b5200000-0000-0000-0000-000000000601', 'b5200000-0000-0000-0000-000000000610', 'b5200000-0000-0000-0000-000000000164', 'b5200000-0000-0000-0000-000000000162', 'b5200000-0000-0000-0000-000000000165');
select pg_temp.h0a5b_use('b5200000-0000-0000-0000-000000000621', 'b5200000-0000-0000-0000-000000000600', 'b5200000-0000-0000-0000-000000000601', 'b5200000-0000-0000-0000-000000000610', 'b5200000-0000-0000-0000-000000000164', 'b5200000-0000-0000-0000-000000000167', 'b5200000-0000-0000-0000-000000000168');
select pg_temp.h0a5b_use('b5200000-0000-0000-0000-000000000622', 'b5200000-0000-0000-0000-000000000600', 'b5200000-0000-0000-0000-000000000601', 'b5200000-0000-0000-0000-000000000610', 'b5200000-0000-0000-0000-000000000164', 'b5200000-0000-0000-0000-000000000174', 'b5200000-0000-0000-0000-000000000176');
select pg_temp.h0a5b_line('b5200000-0000-0000-0000-000000000630', 'b5200000-0000-0000-0000-000000000600', 'b5200000-0000-0000-0000-000000000601', 'b5200000-0000-0000-0000-000000000610', 'b5200000-0000-0000-0000-000000000620', 'b5200000-0000-0000-0000-000000000164', 'b5200000-0000-0000-0000-000000000162', 'b5200000-0000-0000-0000-000000000165', 'b5200000-0000-0000-0000-000000000140', 'b5200000-0000-0000-0000-000000000500', 'b5200000-0000-0000-0000-000000000530', 'REMOVED', 0);
select pg_temp.h0a5b_line('b5200000-0000-0000-0000-000000000631', 'b5200000-0000-0000-0000-000000000600', 'b5200000-0000-0000-0000-000000000601', 'b5200000-0000-0000-0000-000000000610', 'b5200000-0000-0000-0000-000000000621', 'b5200000-0000-0000-0000-000000000164', 'b5200000-0000-0000-0000-000000000167', 'b5200000-0000-0000-0000-000000000168', 'b5200000-0000-0000-0000-000000000141', null, null, 'ACTIVE', 5);
select pg_temp.h0a5b_line('b5200000-0000-0000-0000-000000000632', 'b5200000-0000-0000-0000-000000000600', 'b5200000-0000-0000-0000-000000000601', 'b5200000-0000-0000-0000-000000000610', 'b5200000-0000-0000-0000-000000000622', 'b5200000-0000-0000-0000-000000000164', 'b5200000-0000-0000-0000-000000000174', 'b5200000-0000-0000-0000-000000000176', 'b5200000-0000-0000-0000-000000000142', 'b5200000-0000-0000-0000-000000000500', 'b5200000-0000-0000-0000-000000000531', 'REMOVED', 0);
select lives_ok($$ set constraints all immediate; set constraints all deferred $$, 'a removed revision produces an exact zero REMOVED successor');
update atlas_planning.need_generation_runs set run_status = 'INVALIDATED', version = 2, invalidated_by_actor_id = 'b5200000-0000-0000-0000-000000000002', invalidated_at = timestamptz '2026-12-01 13:30:00+07', updated_at = timestamptz '2026-12-01 13:30:00+07' where need_generation_run_id = 'b5200000-0000-0000-0000-000000000600';
set constraints all immediate; set constraints all deferred;

update atlas_admin.recipe_versions set recipe_version_status = 'LOCKED', locked_by_actor_id = 'b5200000-0000-0000-0000-000000000002', locked_at = timestamptz '2026-12-01 13:35:00+07' where recipe_version_id = 'b5200000-0000-0000-0000-000000000164';
insert into atlas_admin.recipe_versions (recipe_version_id, recipe_id, version_number, predecessor_recipe_version_id, basis_portions, created_by_actor_id)
values ('b5200000-0000-0000-0000-000000000166', 'b5200000-0000-0000-0000-000000000160', 3, 'b5200000-0000-0000-0000-000000000164', 100, 'b5200000-0000-0000-0000-000000000001');
insert into atlas_admin.recipe_line_revisions (recipe_line_revision_id, recipe_id, recipe_version_id, recipe_line_id, line_revision_number, predecessor_recipe_line_revision_id, ingredient_id, quantity_per_basis, unit_id, created_by_actor_id)
values ('b5200000-0000-0000-0000-000000000170', 'b5200000-0000-0000-0000-000000000160', 'b5200000-0000-0000-0000-000000000166', 'b5200000-0000-0000-0000-000000000162', 3, 'b5200000-0000-0000-0000-000000000165', 'b5200000-0000-0000-0000-000000000140', 10, 'b5200000-0000-0000-0000-000000000130', 'b5200000-0000-0000-0000-000000000001');
insert into atlas_admin.recipe_line_revisions (recipe_line_revision_id, recipe_id, recipe_version_id, recipe_line_id, line_revision_number, predecessor_recipe_line_revision_id, ingredient_id, quantity_per_basis, unit_id, created_by_actor_id)
values ('b5200000-0000-0000-0000-000000000172', 'b5200000-0000-0000-0000-000000000160', 'b5200000-0000-0000-0000-000000000166', 'b5200000-0000-0000-0000-000000000167', 2, 'b5200000-0000-0000-0000-000000000168', 'b5200000-0000-0000-0000-000000000141', 5, 'b5200000-0000-0000-0000-000000000130', 'b5200000-0000-0000-0000-000000000001');
set constraints all immediate; set constraints all deferred;
update atlas_admin.recipe_versions set recipe_version_status = 'VALIDATED', validated_by_actor_id = 'b5200000-0000-0000-0000-000000000002', validated_at = timestamptz '2026-12-01 13:40:00+07' where recipe_version_id = 'b5200000-0000-0000-0000-000000000166';
update atlas_admin.recipe_versions set recipe_version_status = 'RELEASED_FOR_PLANNING', released_by_actor_id = 'b5200000-0000-0000-0000-000000000002', released_at = timestamptz '2026-12-01 13:41:00+07' where recipe_version_id = 'b5200000-0000-0000-0000-000000000166';
select pg_temp.h0a5b_run_shell('b5200000-0000-0000-0000-000000000800', 'b5200000-0000-0000-0000-000000000801', 'b5200000-0000-0000-0000-000000000810', 3, 'b5200000-0000-0000-0000-000000000600', 'b5200000-0000-0000-0000-000000000166', 3, 1, 1);
select pg_temp.h0a5b_use('b5200000-0000-0000-0000-000000000820', 'b5200000-0000-0000-0000-000000000800', 'b5200000-0000-0000-0000-000000000801', 'b5200000-0000-0000-0000-000000000810', 'b5200000-0000-0000-0000-000000000166', 'b5200000-0000-0000-0000-000000000167', 'b5200000-0000-0000-0000-000000000172');
select pg_temp.h0a5b_use('b5200000-0000-0000-0000-000000000822', 'b5200000-0000-0000-0000-000000000800', 'b5200000-0000-0000-0000-000000000801', 'b5200000-0000-0000-0000-000000000810', 'b5200000-0000-0000-0000-000000000166', 'b5200000-0000-0000-0000-000000000162', 'b5200000-0000-0000-0000-000000000170');
select pg_temp.h0a5b_line('b5200000-0000-0000-0000-000000000830', 'b5200000-0000-0000-0000-000000000800', 'b5200000-0000-0000-0000-000000000801', 'b5200000-0000-0000-0000-000000000810', 'b5200000-0000-0000-0000-000000000820', 'b5200000-0000-0000-0000-000000000166', 'b5200000-0000-0000-0000-000000000167', 'b5200000-0000-0000-0000-000000000172', 'b5200000-0000-0000-0000-000000000141', 'b5200000-0000-0000-0000-000000000600', 'b5200000-0000-0000-0000-000000000631', 'ACTIVE', 5);
insert into atlas_planning.need_generation_issues (need_generation_issue_id, need_generation_run_id, severity, issue_code, message, recipe_id, recipe_line_id, created_at)
values ('b5200000-0000-0000-0000-000000000840', 'b5200000-0000-0000-0000-000000000800', 'BLOCKING', 'UNSUPPORTED_REINTRODUCTION_AFTER_REMOVAL', 'Removed stable line reappeared and remains unsupported.', 'b5200000-0000-0000-0000-000000000160', 'b5200000-0000-0000-0000-000000000162', timestamptz '2026-12-01 14:00:00+07');
select lives_ok($$ set constraints all immediate; set constraints all deferred $$, 'one removed line may remain absent while another reintroduced line is blocked and unrelated lineage continues');

select is((select row(line_disposition, theoretical_quantity)::text from atlas_planning.theoretical_need_lines where theoretical_need_line_id = 'b5200000-0000-0000-0000-000000000530'), '(ACTIVE,10.000000)', 'first contribution is exact and active');
select is((select row(line_disposition, theoretical_quantity, predecessor_theoretical_need_line_id)::text from atlas_planning.theoretical_need_lines where theoretical_need_line_id = 'b5200000-0000-0000-0000-000000000630'), '(REMOVED,0.000000,b5200000-0000-0000-0000-000000000530)', 'removal is zero and points to the direct predecessor line');
select is((select predecessor_need_generation_run_id from atlas_planning.theoretical_need_lines where theoretical_need_line_id = 'b5200000-0000-0000-0000-000000000630'), 'b5200000-0000-0000-0000-000000000500'::uuid, 'removal points to the direct predecessor run');
select is((select predecessor_theoretical_need_line_id from atlas_planning.theoretical_need_lines where theoretical_need_line_id = 'b5200000-0000-0000-0000-000000000631'), null::uuid, 'genuinely new stable RecipeLine has no predecessor');
select is((select count(*)::integer from atlas_planning.theoretical_need_lines where need_generation_run_id = 'b5200000-0000-0000-0000-000000000800' and recipe_line_id = 'b5200000-0000-0000-0000-000000000174'), 0, 'a prior REMOVED line is permitted to remain absent');
select is((select count(*)::integer from atlas_planning.theoretical_need_lines where predecessor_theoretical_need_line_id = 'b5200000-0000-0000-0000-000000000632'), 0, 'permitted removed-line absence requires no inferred successor');
select is((select count(*)::integer from atlas_planning.theoretical_need_lines where need_generation_run_id = 'b5200000-0000-0000-0000-000000000800' and recipe_line_id = 'b5200000-0000-0000-0000-000000000162'), 0, 'reintroduced stable line creates no new no-predecessor line');
select is((select count(*)::integer from atlas_planning.theoretical_need_lines where need_generation_run_id = 'b5200000-0000-0000-0000-000000000800' and predecessor_theoretical_need_line_id = 'b5200000-0000-0000-0000-000000000630'), 0, 'reintroduction does not infer REMOVED to ACTIVE lineage');
select is((select issue_code from atlas_planning.need_generation_issues where need_generation_issue_id = 'b5200000-0000-0000-0000-000000000840'), 'UNSUPPORTED_REINTRODUCTION_AFTER_REMOVAL', 'reintroduction owns the exact blocker');
select is((select blocking_issue_count from atlas_planning.need_generation_runs where need_generation_run_id = 'b5200000-0000-0000-0000-000000000800'), 1, 'reintroduction blocker count is exact');
select is((select predecessor_theoretical_need_line_id from atlas_planning.theoretical_need_lines where theoretical_need_line_id = 'b5200000-0000-0000-0000-000000000830'), 'b5200000-0000-0000-0000-000000000631'::uuid, 'unaffected stable line continues from the direct predecessor');
select is((select row(released_run_version, generated_line_count, active_line_count, removed_line_count)::text from atlas_planning.need_generation_release_snapshots where need_generation_release_snapshot_id = 'b5200000-0000-0000-0000-000000000540'), '(3,2,2,0)', 'release header preserves exact run-version counts');
select is((select array_agg(theoretical_need_line_id order by theoretical_need_line_id)::text from atlas_planning.need_generation_release_snapshot_lines where need_generation_release_snapshot_id = 'b5200000-0000-0000-0000-000000000540'), '{b5200000-0000-0000-0000-000000000530,b5200000-0000-0000-0000-000000000531}', 'release membership contains every-and-only the released atomic lines');
select is((select count(*)::integer from atlas_planning.need_generation_release_snapshot_issues where need_generation_release_snapshot_id = 'b5200000-0000-0000-0000-000000000540'), 0, 'zero-warning release has an empty exact issue summary');
select is((select run_status from atlas_planning.need_generation_runs where need_generation_run_id = 'b5200000-0000-0000-0000-000000000800'), 'GENERATED', 'blocked reintroduction remains GENERATED');

select throws_ok($$ update atlas_planning.theoretical_need_lines set theoretical_quantity = theoretical_quantity where theoretical_need_line_id = 'b5200000-0000-0000-0000-000000000530' $$, '23514', 'need generation input, lineage, issue, and release evidence is immutable and nondeletable', 'theoretical lines are immutable');
select throws_ok($$ delete from atlas_planning.theoretical_need_lines where theoretical_need_line_id = 'b5200000-0000-0000-0000-000000000530' $$, '23514', 'need generation input, lineage, issue, and release evidence is immutable and nondeletable', 'theoretical lines are nondeletable');
select throws_ok($$ update atlas_planning.need_generation_release_snapshots set released_at = released_at where need_generation_release_snapshot_id = 'b5200000-0000-0000-0000-000000000540' $$, '23514', 'need generation input, lineage, issue, and release evidence is immutable and nondeletable', 'release headers are immutable');
select throws_ok($$ delete from atlas_planning.need_generation_release_snapshot_lines where need_generation_release_snapshot_line_id = 'b5200000-0000-0000-0000-000000000541' $$, '23514', 'need generation input, lineage, issue, and release evidence is immutable and nondeletable', 'release membership is nondeletable');
select throws_ok($$ update atlas_planning.need_generation_runs set run_status = 'VALIDATED', version = 2, validated_by_actor_id = 'b5200000-0000-0000-0000-000000000002', validated_at = timestamptz '2026-12-01 16:00:00+07', updated_at = timestamptz '2026-12-01 16:00:00+07' where need_generation_run_id = 'b5200000-0000-0000-0000-000000000800'; set constraints all immediate $$, '23514', 'validation and release require zero blocking issues', 'reintroduction blocker rejects validation');

select ok(check_ok, description)
from (
  values
    (exists (select 1 from pg_constraint where conrelid = 'atlas_planning.theoretical_need_lines'::regclass and conname = 'theoretical_need_lines_atomic_anchor_key'), 'atomic source anchor is unique inside the run'),
    (exists (select 1 from pg_constraint where conrelid = 'atlas_planning.theoretical_need_lines'::regclass and conname = 'theoretical_need_lines_predecessor_line_fkey'), 'predecessor line and run form a typed composite FK'),
    (exists (select 1 from pg_constraint where conrelid = 'atlas_planning.theoretical_need_lines'::regclass and conname = 'theoretical_need_lines_menu_snapshot_fkey'), 'line owns the exact Menu snapshot triple'),
    (exists (select 1 from pg_constraint where conrelid = 'atlas_planning.theoretical_need_lines'::regclass and conname = 'theoretical_need_lines_attendance_snapshot_fkey'), 'line owns the exact Attendance snapshot triple'),
    (exists (select 1 from pg_constraint where conrelid = 'atlas_planning.theoretical_need_lines'::regclass and conname = 'theoretical_need_lines_recipe_revision_fkey'), 'line owns the exact RecipeLineRevision triple'),
    (exists (select 1 from pg_constraint where conrelid = 'atlas_planning.theoretical_need_lines'::regclass and conname = 'theoretical_need_lines_contract_revision_fkey'), 'line owns the exact calculation revision triple'),
    (exists (select 1 from pg_constraint where conrelid = 'atlas_planning.need_generation_release_snapshots'::regclass and conname = 'need_generation_release_snapshots_run_key'), 'one run owns at most one release snapshot'),
    (exists (select 1 from pg_constraint where conrelid = 'atlas_planning.need_generation_release_snapshot_lines'::regclass and conname = 'need_generation_release_snapshot_lines_member_key'), 'release line membership cannot duplicate a member'),
    (exists (select 1 from pg_constraint where conrelid = 'atlas_planning.need_generation_release_snapshot_issues'::regclass and conname = 'need_generation_release_snapshot_issues_member_key'), 'release issue membership cannot duplicate a member'),
    ((select unit_id = 'b5200000-0000-0000-0000-000000000130' from atlas_planning.theoretical_need_lines where theoretical_need_line_id = 'b5200000-0000-0000-0000-000000000530'), 'line Unit equals the exact RecipeLineRevision Unit'),
    ((select ingredient_id = 'b5200000-0000-0000-0000-000000000140' from atlas_planning.theoretical_need_lines where theoretical_need_line_id = 'b5200000-0000-0000-0000-000000000530'), 'line Ingredient equals the exact RecipeLineRevision Ingredient'),
    ((select weekly_menu_line_id = 'b5200000-0000-0000-0000-000000000210' from atlas_planning.theoretical_need_lines where theoretical_need_line_id = 'b5200000-0000-0000-0000-000000000530'), 'line retains the stable Menu line'),
    ((select attendance_line_id = 'b5200000-0000-0000-0000-000000000310' from atlas_planning.theoretical_need_lines where theoretical_need_line_id = 'b5200000-0000-0000-0000-000000000530'), 'line retains the stable Attendance line'),
    ((select school_id = 'b5200000-0000-0000-0000-000000000120' from atlas_planning.theoretical_need_lines where theoretical_need_line_id = 'b5200000-0000-0000-0000-000000000530'), 'line retains exact School ownership'),
    ((select service_date = date '2026-12-07' from atlas_planning.theoretical_need_lines where theoretical_need_line_id = 'b5200000-0000-0000-0000-000000000530'), 'line retains exact service date'),
    ((select dish_id = 'b5200000-0000-0000-0000-000000000150' from atlas_planning.theoretical_need_lines where theoretical_need_line_id = 'b5200000-0000-0000-0000-000000000530'), 'line retains exact Dish'),
    ((select calculation_contract_revision_number = 1 from atlas_planning.theoretical_need_lines where theoretical_need_line_id = 'b5200000-0000-0000-0000-000000000530'), 'line retains exact calculation revision number'),
    ((select line_disposition = 'REMOVED' from atlas_admin.recipe_line_revisions where recipe_line_revision_id = 'b5200000-0000-0000-0000-000000000165'), 'REMOVED theoretical evidence is backed by H0A2 REMOVED source evidence'),
    ((select line_disposition = 'PRESENT' from atlas_admin.recipe_line_revisions where recipe_line_revision_id = 'b5200000-0000-0000-0000-000000000170'), 'reintroduction is observable as a PRESENT source revision'),
    ((select count(*) = 2 from atlas_planning.need_generation_recipe_line_uses where need_generation_run_id = 'b5200000-0000-0000-0000-000000000800'), 'reintroduction run captures every-and-only its two-row source composition'),
    ((select count(*) = 0 from atlas_planning.need_generation_recipe_line_uses where need_generation_run_id = 'b5200000-0000-0000-0000-000000000800' and recipe_line_id = 'b5200000-0000-0000-0000-000000000174'), 'a still-absent removed line creates no composition use'),
    ((select count(*) = 3 from atlas_planning.need_generation_runs where planning_input_set_id = 'b5200000-0000-0000-0000-000000000400'), 'attempt history contains three contiguous runs'),
    ((select max(attempt_ordinal) = 3 from atlas_planning.need_generation_runs where planning_input_set_id = 'b5200000-0000-0000-0000-000000000400'), 'attempt ordinal advances exactly through the history'),
    ((select count(*) = 1 from atlas_planning.theoretical_need_lines where predecessor_theoretical_need_line_id = 'b5200000-0000-0000-0000-000000000530'), 'one prior ACTIVE contribution has at most one successor'),
    ((select count(*) = 1 from atlas_planning.theoretical_need_lines where predecessor_theoretical_need_line_id = 'b5200000-0000-0000-0000-000000000631'), 'unaffected new contribution has exactly one direct successor'),
    ((select count(*) = 0 from atlas_planning.need_generation_release_snapshot_issues where need_generation_run_id = 'b5200000-0000-0000-0000-000000000500'), 'release issue membership matches the zero-warning summary'),
    ((select released_by_actor_id = 'b5200000-0000-0000-0000-000000000002' from atlas_planning.need_generation_release_snapshots where need_generation_release_snapshot_id = 'b5200000-0000-0000-0000-000000000540'), 'release actor is preserved exactly'),
    ((select released_at = timestamptz '2026-12-01 12:05:00+07' from atlas_planning.need_generation_release_snapshots where need_generation_release_snapshot_id = 'b5200000-0000-0000-0000-000000000540'), 'release timestamp is preserved exactly'),
    ((select need_generation_input_snapshot_id = 'b5200000-0000-0000-0000-000000000501' from atlas_planning.need_generation_release_snapshots where need_generation_release_snapshot_id = 'b5200000-0000-0000-0000-000000000540'), 'release header retains the exact input snapshot'),
    ((select version = 4 from atlas_planning.need_generation_runs where need_generation_run_id = 'b5200000-0000-0000-0000-000000000500'), 'post-release invalidation advances history without altering released version'),
    ((select released_run_version = 3 from atlas_planning.need_generation_release_snapshots where need_generation_release_snapshot_id = 'b5200000-0000-0000-0000-000000000540'), 'immutable release remains tied to its exact earlier run version'),
    ((select generated_line_count = 1 from atlas_planning.need_generation_runs where need_generation_run_id = 'b5200000-0000-0000-0000-000000000800'), 'blocked reintroduction counts only the unaffected generated line'),
    ((select count(*) = 1 from atlas_planning.need_generation_issues where need_generation_run_id = 'b5200000-0000-0000-0000-000000000800'), 'blocked reintroduction owns exactly one classified issue'),
    ((select severity = 'BLOCKING' from atlas_planning.need_generation_issues where need_generation_issue_id = 'b5200000-0000-0000-0000-000000000840'), 'unsupported reintroduction is physically blocking'),
    ((select recipe_line_id = 'b5200000-0000-0000-0000-000000000162' from atlas_planning.need_generation_issues where need_generation_issue_id = 'b5200000-0000-0000-0000-000000000840'), 'reintroduction blocker names the exact stable RecipeLine'),
    ((select predecessor_need_generation_run_id = 'b5200000-0000-0000-0000-000000000600' from atlas_planning.need_generation_runs where need_generation_run_id = 'b5200000-0000-0000-0000-000000000800'), 'blocked run points to the exact direct predecessor run'),
    ((select run_status = 'GENERATED' from atlas_planning.need_generation_runs where need_generation_run_id = 'b5200000-0000-0000-0000-000000000800'), 'blocked run remains the terminal GENERATED attempt'),
    ((select run_status = 'INVALIDATED' from atlas_planning.need_generation_runs where need_generation_run_id = 'b5200000-0000-0000-0000-000000000600'), 'removal run is historical and invalidated before its successor'),
    ((select run_status = 'INVALIDATED' from atlas_planning.need_generation_runs where need_generation_run_id = 'b5200000-0000-0000-0000-000000000500'), 'released run is historical and invalidated before regeneration'),
    ((select theoretical_quantity = 5.000000 from atlas_planning.theoretical_need_lines where theoretical_need_line_id = 'b5200000-0000-0000-0000-000000000830'), 'unaffected successor retains its exact authoritative quantity'),
    ((select theoretical_quantity = 0.000000 from atlas_planning.theoretical_need_lines where theoretical_need_line_id = 'b5200000-0000-0000-0000-000000000630'), 'removal quantity remains exactly zero'),
    ((select count(*) = 0 from atlas_planning.need_generation_release_snapshots where need_generation_run_id = 'b5200000-0000-0000-0000-000000000800'), 'blocked run owns no release snapshot'),
    ((select count(*) = 0 from atlas_planning.need_generation_release_snapshot_lines where need_generation_run_id = 'b5200000-0000-0000-0000-000000000800'), 'blocked run owns no release membership'),
    ((select count(*) = 0 from atlas_planning.need_generation_release_snapshot_issues where need_generation_run_id = 'b5200000-0000-0000-0000-000000000800'), 'blocked run owns no release issue summary'),
    ((select recipe_version_id = 'b5200000-0000-0000-0000-000000000166' from atlas_planning.need_generation_recipe_selections where need_generation_run_id = 'b5200000-0000-0000-0000-000000000800'), 'blocked run still selects the exact current released RecipeVersion'),
    ((select count(*) = blocking_issue_count from atlas_planning.need_generation_issues i cross join atlas_planning.need_generation_runs r where i.need_generation_run_id = r.need_generation_run_id and r.need_generation_run_id = 'b5200000-0000-0000-0000-000000000800' group by r.blocking_issue_count), 'blocked run stored blocker count equals exact issue rows'),
    ((select count(*) = 1 from atlas_planning.need_generation_release_snapshots where need_generation_run_id = 'b5200000-0000-0000-0000-000000000500'), 'released historical run owns exactly one snapshot'),
    ((select count(*) = generated_line_count from atlas_planning.need_generation_release_snapshot_lines m join atlas_planning.need_generation_release_snapshots s using (need_generation_release_snapshot_id) where s.need_generation_release_snapshot_id = 'b5200000-0000-0000-0000-000000000540' group by s.generated_line_count), 'release line membership count equals exact released line count'),
    ((select need_generation_run_id = 'b5200000-0000-0000-0000-000000000500' from atlas_planning.need_generation_release_snapshot_lines where need_generation_release_snapshot_line_id = 'b5200000-0000-0000-0000-000000000541'), 'release member cannot cross run ownership')
) as checks(check_ok, description);

select * from finish();
rollback;
