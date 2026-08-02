begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;

select plan(64);

insert into atlas_core.actors (actor_id, actor_type, display_name) values
  ('b5300000-0000-0000-0000-000000000001', 'HUMAN', 'H0A5b lifecycle generator'),
  ('b5300000-0000-0000-0000-000000000002', 'HUMAN', 'H0A5b lifecycle reviewer');
insert into atlas_admin.customers (customer_id, customer_code, customer_name, customer_type)
values ('b5300000-0000-0000-0000-000000000100', 'pa06e-h0a5b-lifecycle-customer', 'H0A5b lifecycle customer', 'SCHOOL_CATERING');
insert into atlas_admin.delivery_locations (delivery_location_id, customer_id, location_code, location_name, address_text, timezone_name)
values ('b5300000-0000-0000-0000-000000000101', 'b5300000-0000-0000-0000-000000000100', 'pa06e-h0a5b-lifecycle-location', 'H0A5b lifecycle location', 'Local-only fixture', 'Asia/Ho_Chi_Minh');
insert into atlas_admin.school_types (school_type_id, school_type_code, school_type_name)
values ('b5300000-0000-0000-0000-000000000110', 'pa06e-h0a5b-lifecycle-type', 'H0A5b lifecycle type');
insert into atlas_admin.schools (school_id, customer_id, school_code, school_name, school_type_id, default_delivery_location_id, display_order)
values ('b5300000-0000-0000-0000-000000000120', 'b5300000-0000-0000-0000-000000000100', 'pa06e-h0a5b-lifecycle-school', 'H0A5b Lifecycle School', 'b5300000-0000-0000-0000-000000000110', 'b5300000-0000-0000-0000-000000000101', 10);
insert into atlas_admin.units (unit_id, unit_code, unit_name, dimension_code)
values ('b5300000-0000-0000-0000-000000000130', 'kg-h0a5b-lifecycle', 'kilogram H0A5b lifecycle', 'mass');
insert into atlas_admin.ingredients (ingredient_id, ingredient_code, ingredient_name)
values ('b5300000-0000-0000-0000-000000000140', 'h0a5b-lifecycle-rice', 'H0A5b lifecycle rice');
insert into atlas_admin.dishes (dish_id, dish_code, dish_name, dish_status, display_order, requires_need_generation)
values ('b5300000-0000-0000-0000-000000000150', 'h0a5b-lifecycle-dish', 'H0A5b lifecycle dish', 'ACTIVE', 10, true);
insert into atlas_admin.recipes (recipe_id, dish_id)
values ('b5300000-0000-0000-0000-000000000160', 'b5300000-0000-0000-0000-000000000150');
insert into atlas_admin.recipe_versions (recipe_version_id, recipe_id, version_number, basis_portions, created_by_actor_id)
values ('b5300000-0000-0000-0000-000000000161', 'b5300000-0000-0000-0000-000000000160', 1, 100, 'b5300000-0000-0000-0000-000000000001');
insert into atlas_admin.recipe_lines (recipe_line_id, recipe_id, line_code)
values ('b5300000-0000-0000-0000-000000000162', 'b5300000-0000-0000-0000-000000000160', 'rice');
insert into atlas_admin.recipe_line_revisions (recipe_line_revision_id, recipe_id, recipe_version_id, recipe_line_id, line_revision_number, ingredient_id, quantity_per_basis, unit_id, created_by_actor_id)
values ('b5300000-0000-0000-0000-000000000163', 'b5300000-0000-0000-0000-000000000160', 'b5300000-0000-0000-0000-000000000161', 'b5300000-0000-0000-0000-000000000162', 1, 'b5300000-0000-0000-0000-000000000140', 10, 'b5300000-0000-0000-0000-000000000130', 'b5300000-0000-0000-0000-000000000001');
set constraints all immediate; set constraints all deferred;
update atlas_admin.recipe_versions set recipe_version_status = 'VALIDATED', validated_by_actor_id = 'b5300000-0000-0000-0000-000000000002', validated_at = timestamptz '2027-01-01 07:00:00+07' where recipe_version_id = 'b5300000-0000-0000-0000-000000000161';
update atlas_admin.recipe_versions set recipe_version_status = 'RELEASED_FOR_PLANNING', released_by_actor_id = 'b5300000-0000-0000-0000-000000000002', released_at = timestamptz '2027-01-01 07:01:00+07' where recipe_version_id = 'b5300000-0000-0000-0000-000000000161';

insert into atlas_planning.weekly_menus (weekly_menu_id, week_start, week_end, source_type, source_name, source_signature, row_count, imported_by_actor_id)
values ('b5300000-0000-0000-0000-000000000200', date '2027-01-04', date '2027-01-10', 'FIXTURE', 'H0A5b lifecycle menu', 'sha256:h0a5b-lifecycle-menu', 1, 'b5300000-0000-0000-0000-000000000001');
insert into atlas_planning.weekly_menu_lines (weekly_menu_line_id, weekly_menu_id, school_id, service_date, menu_slot_code, dish_id, created_by_actor_id, updated_by_actor_id)
values ('b5300000-0000-0000-0000-000000000210', 'b5300000-0000-0000-0000-000000000200', 'b5300000-0000-0000-0000-000000000120', date '2027-01-04', 'savory', 'b5300000-0000-0000-0000-000000000150', 'b5300000-0000-0000-0000-000000000001', 'b5300000-0000-0000-0000-000000000001');
update atlas_planning.weekly_menus set weekly_menu_status = 'VALIDATED' where weekly_menu_id = 'b5300000-0000-0000-0000-000000000200';
insert into atlas_planning.weekly_menu_approval_snapshots (weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version, approved_by_actor_id, approved_at)
values ('b5300000-0000-0000-0000-000000000220', 'b5300000-0000-0000-0000-000000000200', 1, 'b5300000-0000-0000-0000-000000000002', timestamptz '2027-01-01 08:00:00+07');
insert into atlas_planning.weekly_menu_approval_snapshot_lines (weekly_menu_approval_snapshot_line_id, weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version, weekly_menu_line_id, school_id, service_date, menu_slot_code, dish_id)
values ('b5300000-0000-0000-0000-000000000221', 'b5300000-0000-0000-0000-000000000220', 'b5300000-0000-0000-0000-000000000200', 1, 'b5300000-0000-0000-0000-000000000210', 'b5300000-0000-0000-0000-000000000120', date '2027-01-04', 'savory', 'b5300000-0000-0000-0000-000000000150');
update atlas_planning.weekly_menus set weekly_menu_status = 'APPROVED', latest_approved_by_actor_id = 'b5300000-0000-0000-0000-000000000002', latest_approved_at = timestamptz '2027-01-01 08:00:00+07', latest_approval_snapshot_id = 'b5300000-0000-0000-0000-000000000220' where weekly_menu_id = 'b5300000-0000-0000-0000-000000000200';

insert into atlas_planning.attendance_batches (attendance_batch_id, period_start, period_end, source_type, source_name, source_signature, row_count, imported_by_actor_id)
values ('b5300000-0000-0000-0000-000000000300', date '2027-01-04', date '2027-01-10', 'FIXTURE', 'H0A5b lifecycle attendance', 'sha256:h0a5b-lifecycle-attendance', 1, 'b5300000-0000-0000-0000-000000000001');
insert into atlas_planning.attendance_lines (attendance_line_id, attendance_batch_id, school_id, service_date, student_portions, teacher_portions, created_by_actor_id, updated_by_actor_id)
values ('b5300000-0000-0000-0000-000000000310', 'b5300000-0000-0000-0000-000000000300', 'b5300000-0000-0000-0000-000000000120', date '2027-01-04', 90, 10, 'b5300000-0000-0000-0000-000000000001', 'b5300000-0000-0000-0000-000000000001');
update atlas_planning.attendance_batches set attendance_status = 'VALIDATED' where attendance_batch_id = 'b5300000-0000-0000-0000-000000000300';
insert into atlas_planning.attendance_approval_snapshots (attendance_approval_snapshot_id, attendance_batch_id, attendance_version, approved_by_actor_id, approved_at)
values ('b5300000-0000-0000-0000-000000000320', 'b5300000-0000-0000-0000-000000000300', 1, 'b5300000-0000-0000-0000-000000000002', timestamptz '2027-01-01 08:05:00+07');
insert into atlas_planning.attendance_approval_snapshot_lines (attendance_approval_snapshot_line_id, attendance_approval_snapshot_id, attendance_batch_id, attendance_version, attendance_line_id, school_id, service_date, student_portions, teacher_portions)
values ('b5300000-0000-0000-0000-000000000321', 'b5300000-0000-0000-0000-000000000320', 'b5300000-0000-0000-0000-000000000300', 1, 'b5300000-0000-0000-0000-000000000310', 'b5300000-0000-0000-0000-000000000120', date '2027-01-04', 90, 10);
update atlas_planning.attendance_batches set attendance_status = 'APPROVED', latest_approved_by_actor_id = 'b5300000-0000-0000-0000-000000000002', latest_approved_at = timestamptz '2027-01-01 08:05:00+07', latest_approval_snapshot_id = 'b5300000-0000-0000-0000-000000000320' where attendance_batch_id = 'b5300000-0000-0000-0000-000000000300';

insert into atlas_planning.pantry_need_batches (pantry_need_batch_id, week_start, source_signature, no_additions_confirmed, requesting_actor_id)
values ('b5300000-0000-0000-0000-000000000330', date '2027-01-04', repeat('f', 64), true, 'b5300000-0000-0000-0000-000000000001');
update atlas_planning.pantry_need_batches set pantry_need_batch_status = 'VALIDATED', version = 2, updated_at = updated_at + interval '1 second' where pantry_need_batch_id = 'b5300000-0000-0000-0000-000000000330';
insert into atlas_planning.pantry_need_approval_snapshots (pantry_need_approval_snapshot_id, pantry_need_batch_id, approved_batch_version, approved_by_actor_id, approved_at, source_signature, no_additions_confirmed, line_count)
values ('b5300000-0000-0000-0000-000000000332', 'b5300000-0000-0000-0000-000000000330', 3, 'b5300000-0000-0000-0000-000000000002', timestamptz '2027-01-01 08:07:00+07', repeat('f', 64), true, 0);
update atlas_planning.pantry_need_batches set pantry_need_batch_status = 'APPROVED', version = 3, latest_approved_by_actor_id = 'b5300000-0000-0000-0000-000000000002', latest_approved_at = timestamptz '2027-01-01 08:07:00+07', latest_approval_snapshot_id = 'b5300000-0000-0000-0000-000000000332', updated_at = updated_at + interval '1 second' where pantry_need_batch_id = 'b5300000-0000-0000-0000-000000000330';
set constraints all immediate; set constraints all deferred;

insert into atlas_planning.planning_input_sets (planning_input_set_id, period_start, period_end, readiness_status, current_evaluation_id)
values ('b5300000-0000-0000-0000-000000000400', date '2027-01-04', date '2027-01-04', 'READY', 'b5300000-0000-0000-0000-000000000401');
insert into atlas_planning.planning_input_evaluations (planning_input_evaluation_id, planning_input_set_id, evaluation_version, evaluation_result, weekly_menu_id, weekly_menu_version, weekly_menu_approval_snapshot_id, attendance_batch_id, attendance_version, attendance_approval_snapshot_id, pantry_need_batch_id, pantry_need_batch_version, pantry_need_approval_snapshot_id, blocking_issue_count, warning_count, evaluated_by_actor_id, evaluated_at)
values ('b5300000-0000-0000-0000-000000000401', 'b5300000-0000-0000-0000-000000000400', 1, 'READY', 'b5300000-0000-0000-0000-000000000200', 1, 'b5300000-0000-0000-0000-000000000220', 'b5300000-0000-0000-0000-000000000300', 1, 'b5300000-0000-0000-0000-000000000320', 'b5300000-0000-0000-0000-000000000330', 3, 'b5300000-0000-0000-0000-000000000332', 0, 0, 'b5300000-0000-0000-0000-000000000001', timestamptz '2027-01-01 08:10:00+07');
set constraints all immediate; set constraints all deferred;
update atlas_planning.planning_input_sets set readiness_status = 'NEED_GENERATION_REQUESTED', updated_at = updated_at + interval '1 second' where planning_input_set_id = 'b5300000-0000-0000-0000-000000000400';

insert into atlas_planning.need_generation_calculation_contracts (need_generation_calculation_contract_id, contract_code, current_revision_id, version)
values ('b5300000-0000-0000-0000-000000000700', 'school_catering_proportional_per_basis', 'b5300000-0000-0000-0000-000000000701', 1);
insert into atlas_planning.need_generation_calculation_contract_revisions (need_generation_calculation_contract_revision_id, need_generation_calculation_contract_id, revision_number, formula_kind, quantity_precision, quantity_scale, factor_precision, factor_scale, final_coercion_mode, approved_by_actor_id, approved_at)
values ('b5300000-0000-0000-0000-000000000701', 'b5300000-0000-0000-0000-000000000700', 1, 'STUDENT_TEACHER_PORTIONS_X_RECIPE_QTY_DIV_BASIS', 20, 6, 24, 12, 'POSTGRES_NUMERIC_SCALE_HALF_AWAY_FROM_ZERO', 'b5300000-0000-0000-0000-000000000002', timestamptz '2027-01-01 06:00:00+07');
set constraints all immediate; set constraints all deferred;

create function pg_temp.h0a5b_lifecycle_run(p_run uuid, p_snapshot uuid, p_selection uuid, p_use uuid, p_line uuid, p_attempt bigint, p_predecessor_run uuid, p_predecessor_line uuid)
returns void language plpgsql as $$
begin
  insert into atlas_planning.need_generation_runs (need_generation_run_id, planning_input_set_id, planning_input_evaluation_id, evaluation_version, period_start, period_end, attempt_ordinal, predecessor_need_generation_run_id, input_snapshot_id, run_status, version, generated_line_count, blocking_issue_count, warning_count, generated_by_actor_id, generated_at, updated_at)
  values (p_run, 'b5300000-0000-0000-0000-000000000400', 'b5300000-0000-0000-0000-000000000401', 1, date '2027-01-04', date '2027-01-04', p_attempt, p_predecessor_run, p_snapshot, 'GENERATED', 1, 1, 0, 0, 'b5300000-0000-0000-0000-000000000001', timestamptz '2027-01-01 10:00:00+07' + p_attempt * interval '1 hour', timestamptz '2027-01-01 10:00:00+07' + p_attempt * interval '1 hour');
  insert into atlas_planning.need_generation_input_snapshots (need_generation_input_snapshot_id, need_generation_run_id, planning_input_set_id, planning_input_evaluation_id, evaluation_version, weekly_menu_id, weekly_menu_version, weekly_menu_approval_snapshot_id, attendance_batch_id, attendance_version, attendance_approval_snapshot_id, pantry_need_batch_id, pantry_need_batch_version, pantry_need_approval_snapshot_id, need_generation_calculation_contract_id, need_generation_calculation_contract_revision_id, calculation_contract_revision_number, captured_at)
  values (p_snapshot, p_run, 'b5300000-0000-0000-0000-000000000400', 'b5300000-0000-0000-0000-000000000401', 1, 'b5300000-0000-0000-0000-000000000200', 1, 'b5300000-0000-0000-0000-000000000220', 'b5300000-0000-0000-0000-000000000300', 1, 'b5300000-0000-0000-0000-000000000320', 'b5300000-0000-0000-0000-000000000330', 3, 'b5300000-0000-0000-0000-000000000332', 'b5300000-0000-0000-0000-000000000700', 'b5300000-0000-0000-0000-000000000701', 1, timestamptz '2027-01-01 10:00:00+07' + p_attempt * interval '1 hour');
  insert into atlas_planning.need_generation_recipe_selections (need_generation_recipe_selection_id, need_generation_input_snapshot_id, need_generation_run_id, weekly_menu_approval_snapshot_line_id, weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version, weekly_menu_line_id, school_id, school_type_id, dish_id, recipe_id, recipe_version_id, recipe_version_number, selection_scope, selected_at)
  values (p_selection, p_snapshot, p_run, 'b5300000-0000-0000-0000-000000000221', 'b5300000-0000-0000-0000-000000000220', 'b5300000-0000-0000-0000-000000000200', 1, 'b5300000-0000-0000-0000-000000000210', 'b5300000-0000-0000-0000-000000000120', 'b5300000-0000-0000-0000-000000000110', 'b5300000-0000-0000-0000-000000000150', 'b5300000-0000-0000-0000-000000000160', 'b5300000-0000-0000-0000-000000000161', 1, 'GENERAL', timestamptz '2027-01-01 10:00:00+07' + p_attempt * interval '1 hour');
  insert into atlas_planning.need_generation_recipe_line_uses (need_generation_recipe_line_use_id, need_generation_input_snapshot_id, need_generation_run_id, need_generation_recipe_selection_id, recipe_id, recipe_version_id, recipe_line_id, recipe_line_revision_id, captured_at)
  values (p_use, p_snapshot, p_run, p_selection, 'b5300000-0000-0000-0000-000000000160', 'b5300000-0000-0000-0000-000000000161', 'b5300000-0000-0000-0000-000000000162', 'b5300000-0000-0000-0000-000000000163', timestamptz '2027-01-01 10:00:00+07');
  insert into atlas_planning.theoretical_need_lines (theoretical_need_line_id, need_generation_run_id, need_generation_input_snapshot_id, need_generation_recipe_selection_id, need_generation_recipe_line_use_id, weekly_menu_approval_snapshot_line_id, weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version, weekly_menu_line_id, attendance_approval_snapshot_line_id, attendance_approval_snapshot_id, attendance_batch_id, attendance_version, attendance_line_id, school_id, service_date, dish_id, recipe_id, recipe_version_id, recipe_line_id, recipe_line_revision_id, ingredient_id, unit_id, need_generation_calculation_contract_id, need_generation_calculation_contract_revision_id, calculation_contract_revision_number, predecessor_need_generation_run_id, predecessor_theoretical_need_line_id, line_disposition, theoretical_quantity, created_at)
  values (p_line, p_run, p_snapshot, p_selection, p_use, 'b5300000-0000-0000-0000-000000000221', 'b5300000-0000-0000-0000-000000000220', 'b5300000-0000-0000-0000-000000000200', 1, 'b5300000-0000-0000-0000-000000000210', 'b5300000-0000-0000-0000-000000000321', 'b5300000-0000-0000-0000-000000000320', 'b5300000-0000-0000-0000-000000000300', 1, 'b5300000-0000-0000-0000-000000000310', 'b5300000-0000-0000-0000-000000000120', date '2027-01-04', 'b5300000-0000-0000-0000-000000000150', 'b5300000-0000-0000-0000-000000000160', 'b5300000-0000-0000-0000-000000000161', 'b5300000-0000-0000-0000-000000000162', 'b5300000-0000-0000-0000-000000000163', 'b5300000-0000-0000-0000-000000000140', 'b5300000-0000-0000-0000-000000000130', 'b5300000-0000-0000-0000-000000000700', 'b5300000-0000-0000-0000-000000000701', 1, p_predecessor_run, p_predecessor_line, 'ACTIVE', 10, timestamptz '2027-01-01 10:00:00+07');
end;
$$;

select pg_temp.h0a5b_lifecycle_run('b5300000-0000-0000-0000-000000000500', 'b5300000-0000-0000-0000-000000000501', 'b5300000-0000-0000-0000-000000000510', 'b5300000-0000-0000-0000-000000000520', 'b5300000-0000-0000-0000-000000000530', 1, null, null);
select lives_ok($$ set constraints all immediate; set constraints all deferred $$, 'first run enters GENERATED with immutable evidence');
select lives_ok($$ update atlas_planning.need_generation_runs set run_status = 'VALIDATED', version = 2, validated_by_actor_id = 'b5300000-0000-0000-0000-000000000002', validated_at = timestamptz '2027-01-01 12:00:00+07', updated_at = timestamptz '2027-01-01 12:00:00+07' where need_generation_run_id = 'b5300000-0000-0000-0000-000000000500'; set constraints all immediate; set constraints all deferred $$, 'GENERATED transitions to VALIDATED exactly once');
select lives_ok(
  $$
    update atlas_planning.need_generation_runs set run_status = 'RELEASED_FOR_CONFIRMATION', version = 3, released_by_actor_id = 'b5300000-0000-0000-0000-000000000002', released_at = timestamptz '2027-01-01 12:05:00+07', updated_at = timestamptz '2027-01-01 12:05:00+07' where need_generation_run_id = 'b5300000-0000-0000-0000-000000000500';
    insert into atlas_planning.need_generation_release_snapshots (need_generation_release_snapshot_id, need_generation_run_id, released_run_version, need_generation_input_snapshot_id, released_by_actor_id, released_at, generated_line_count, active_line_count, removed_line_count, blocking_issue_count, warning_count) values ('b5300000-0000-0000-0000-000000000540', 'b5300000-0000-0000-0000-000000000500', 3, 'b5300000-0000-0000-0000-000000000501', 'b5300000-0000-0000-0000-000000000002', timestamptz '2027-01-01 12:05:00+07', 1, 1, 0, 0, 0);
    insert into atlas_planning.need_generation_release_snapshot_lines (need_generation_release_snapshot_line_id, need_generation_release_snapshot_id, need_generation_run_id, released_run_version, theoretical_need_line_id) values ('b5300000-0000-0000-0000-000000000541', 'b5300000-0000-0000-0000-000000000540', 'b5300000-0000-0000-0000-000000000500', 3, 'b5300000-0000-0000-0000-000000000530');
    set constraints all immediate; set constraints all deferred
  $$,
  'VALIDATED transitions to RELEASED_FOR_CONFIRMATION with exact evidence'
);
select lives_ok($$ update atlas_planning.need_generation_runs set run_status = 'INVALIDATED', version = 4, invalidated_by_actor_id = 'b5300000-0000-0000-0000-000000000002', invalidated_at = timestamptz '2027-01-01 12:10:00+07', updated_at = timestamptz '2027-01-01 12:10:00+07' where need_generation_run_id = 'b5300000-0000-0000-0000-000000000500'; set constraints all immediate; set constraints all deferred $$, 'released run may be invalidated without rewriting released evidence');

select pg_temp.h0a5b_lifecycle_run('b5300000-0000-0000-0000-000000000600', 'b5300000-0000-0000-0000-000000000601', 'b5300000-0000-0000-0000-000000000610', 'b5300000-0000-0000-0000-000000000620', 'b5300000-0000-0000-0000-000000000630', 2, 'b5300000-0000-0000-0000-000000000500', 'b5300000-0000-0000-0000-000000000530');
select lives_ok($$ set constraints all immediate; set constraints all deferred $$, 'successor run enters as the exact next attempt after invalidation');
select lives_ok(
  $$
    insert into atlas_planning.need_generation_issues (need_generation_issue_id, need_generation_run_id, severity, issue_code, message, created_at) values ('b5300000-0000-0000-0000-000000000640', 'b5300000-0000-0000-0000-000000000600', 'BLOCKING', 'RELEASE_ATTEMPTED_WITH_BLOCKING_ISSUES', 'Validation discovered a blocking issue.', timestamptz '2027-01-01 13:30:00+07');
    update atlas_planning.need_generation_runs set blocking_issue_count = 1, version = 2, updated_at = timestamptz '2027-01-01 13:30:00+07' where need_generation_run_id = 'b5300000-0000-0000-0000-000000000600';
    set constraints all immediate; set constraints all deferred
  $$,
  'failed validation appends immutable issue evidence and advances version without changing status'
);
select lives_ok($$ update atlas_planning.need_generation_runs set run_status = 'INVALIDATED', version = 3, invalidated_by_actor_id = 'b5300000-0000-0000-0000-000000000002', invalidated_at = timestamptz '2027-01-01 13:35:00+07', updated_at = timestamptz '2027-01-01 13:35:00+07' where need_generation_run_id = 'b5300000-0000-0000-0000-000000000600'; set constraints all immediate; set constraints all deferred $$, 'blocked GENERATED run can be explicitly invalidated');

select is((select row(run_status, version)::text from atlas_planning.need_generation_runs where need_generation_run_id = 'b5300000-0000-0000-0000-000000000500'), '(INVALIDATED,4)', 'released history remains INVALIDATED at version four');
select is((select row(run_status, version, blocking_issue_count)::text from atlas_planning.need_generation_runs where need_generation_run_id = 'b5300000-0000-0000-0000-000000000600'), '(INVALIDATED,3,1)', 'failed-validation history remains INVALIDATED with its blocker');
select is((select row(validated_by_actor_id, released_by_actor_id, invalidated_by_actor_id)::text from atlas_planning.need_generation_runs where need_generation_run_id = 'b5300000-0000-0000-0000-000000000500'), '(b5300000-0000-0000-0000-000000000002,b5300000-0000-0000-0000-000000000002,b5300000-0000-0000-0000-000000000002)', 'lifecycle actors remain exact immutable evidence');
select is((select issue_code from atlas_planning.need_generation_issues where need_generation_issue_id = 'b5300000-0000-0000-0000-000000000640'), 'RELEASE_ATTEMPTED_WITH_BLOCKING_ISSUES', 'failed progression stores an exact classified issue');
select is((select severity from atlas_planning.need_generation_issues where need_generation_issue_id = 'b5300000-0000-0000-0000-000000000640'), 'BLOCKING', 'all non-zero-quantity catalog issues are blocking');
select is((select count(*)::integer from atlas_planning.need_generation_issues where need_generation_run_id = 'b5300000-0000-0000-0000-000000000600'), 1, 'stored blocker count has one exact issue row');
select is((select predecessor_need_generation_run_id from atlas_planning.need_generation_runs where need_generation_run_id = 'b5300000-0000-0000-0000-000000000600'), 'b5300000-0000-0000-0000-000000000500'::uuid, 'attempt history retains the exact predecessor run');
select is((select predecessor_theoretical_need_line_id from atlas_planning.theoretical_need_lines where theoretical_need_line_id = 'b5300000-0000-0000-0000-000000000630'), 'b5300000-0000-0000-0000-000000000530'::uuid, 'successor history retains the exact predecessor contribution');
select is((select released_run_version from atlas_planning.need_generation_release_snapshots where need_generation_run_id = 'b5300000-0000-0000-0000-000000000500'), 3::bigint, 'release evidence remains tied to the exact released version');
select is((select count(*)::integer from atlas_planning.need_generation_release_snapshots where need_generation_run_id = 'b5300000-0000-0000-0000-000000000600'), 0, 'blocked successor owns no release evidence');

select throws_ok($$ update atlas_planning.need_generation_issues set message = message where need_generation_issue_id = 'b5300000-0000-0000-0000-000000000640' $$, '23514', 'need generation input, lineage, issue, and release evidence is immutable and nondeletable', 'issues are immutable');
select throws_ok($$ delete from atlas_planning.need_generation_issues where need_generation_issue_id = 'b5300000-0000-0000-0000-000000000640' $$, '23514', 'need generation input, lineage, issue, and release evidence is immutable and nondeletable', 'issues are nondeletable');
select throws_ok($$ update atlas_planning.need_generation_runs set run_status = 'VALIDATED', version = 4, validated_by_actor_id = 'b5300000-0000-0000-0000-000000000002', validated_at = timestamptz '2027-01-01 14:00:00+07', updated_at = timestamptz '2027-01-01 14:00:00+07' where need_generation_run_id = 'b5300000-0000-0000-0000-000000000600' $$, '23514', 'need generation lifecycle transition is invalid', 'INVALIDATED cannot return to VALIDATED');
select throws_ok($$ update atlas_planning.need_generation_runs set version = 4, updated_at = timestamptz '2027-01-01 14:00:00+07' where need_generation_run_id = 'b5300000-0000-0000-0000-000000000600' $$, '23514', 'same-status updates are only append-only failed validation or release evidence', 'INVALIDATED cannot receive same-status maintenance');
select throws_ok($$ update atlas_planning.need_generation_runs set run_status = 'GENERATED', version = 5, updated_at = timestamptz '2027-01-01 14:00:00+07' where need_generation_run_id = 'b5300000-0000-0000-0000-000000000500' $$, '23514', 'need generation lifecycle transition is invalid', 'INVALIDATED cannot return to GENERATED');
select throws_ok($$ insert into atlas_planning.need_generation_issues (need_generation_issue_id, need_generation_run_id, severity, issue_code, message, created_at) values ('b5300000-0000-0000-0000-000000000641', 'b5300000-0000-0000-0000-000000000600', 'WARNING', 'INVALID_PREDECESSOR', 'Wrong severity.', timestamptz '2027-01-01 14:00:00+07') $$, '23514', 'new row for relation "need_generation_issues" violates check constraint "need_generation_issues_severity_code_check"', 'blocking classifications cannot be stored as warnings');
select throws_ok($$ insert into atlas_planning.need_generation_issues (need_generation_issue_id, need_generation_run_id, severity, issue_code, message, theoretical_need_line_id, created_at) values ('b5300000-0000-0000-0000-000000000642', 'b5300000-0000-0000-0000-000000000600', 'BLOCKING', 'ZERO_ACTIVE_THEORETICAL_QUANTITY', 'Wrong severity.', 'b5300000-0000-0000-0000-000000000630', timestamptz '2027-01-01 14:00:00+07') $$, '23514', 'new row for relation "need_generation_issues" violates check constraint "need_generation_issues_severity_code_check"', 'the sole warning classification cannot be stored as blocking');
select throws_ok($$ update atlas_planning.need_generation_runs set blocking_issue_count = 0, version = 4, updated_at = timestamptz '2027-01-01 14:00:00+07' where need_generation_run_id = 'b5300000-0000-0000-0000-000000000600' $$, '23514', 'same-status updates are only append-only failed validation or release evidence', 'issue counts never decrease');

select ok(check_ok, description)
from (
  values
    (exists (select 1 from pg_constraint where conrelid = 'atlas_planning.need_generation_runs'::regclass and conname = 'need_generation_runs_status_check'), 'run lifecycle vocabulary is physically closed'),
    (exists (select 1 from pg_constraint where conrelid = 'atlas_planning.need_generation_runs'::regclass and conname = 'need_generation_runs_status_evidence_check'), 'run states require exact lifecycle evidence'),
    (exists (select 1 from pg_constraint where conrelid = 'atlas_planning.need_generation_issues'::regclass and conname = 'need_generation_issues_context_key'), 'issue context uniqueness is deterministic across nulls'),
    (exists (select 1 from pg_index where indrelid = 'atlas_planning.need_generation_issues'::regclass and indisunique and indnullsnotdistinct), 'issue contextual uniqueness treats nulls as equal'),
    ((select validated_at = timestamptz '2027-01-01 12:00:00+07' from atlas_planning.need_generation_runs where need_generation_run_id = 'b5300000-0000-0000-0000-000000000500'), 'validation timestamp is preserved'),
    ((select released_at = timestamptz '2027-01-01 12:05:00+07' from atlas_planning.need_generation_runs where need_generation_run_id = 'b5300000-0000-0000-0000-000000000500'), 'release timestamp is preserved'),
    ((select invalidated_at = timestamptz '2027-01-01 12:10:00+07' from atlas_planning.need_generation_runs where need_generation_run_id = 'b5300000-0000-0000-0000-000000000500'), 'post-release invalidation timestamp is preserved'),
    ((select invalidated_at = timestamptz '2027-01-01 13:35:00+07' from atlas_planning.need_generation_runs where need_generation_run_id = 'b5300000-0000-0000-0000-000000000600'), 'blocked-run invalidation timestamp is preserved'),
    ((select updated_at = invalidated_at from atlas_planning.need_generation_runs where need_generation_run_id = 'b5300000-0000-0000-0000-000000000600'), 'terminal update time matches explicit invalidation evidence'),
    ((select generated_by_actor_id = 'b5300000-0000-0000-0000-000000000001' from atlas_planning.need_generation_runs where need_generation_run_id = 'b5300000-0000-0000-0000-000000000500'), 'generation actor remains immutable'),
    ((select generated_line_count = 1 from atlas_planning.need_generation_runs where need_generation_run_id = 'b5300000-0000-0000-0000-000000000600'), 'same-status issue evidence cannot rewrite generated line count'),
    ((select warning_count = 0 from atlas_planning.need_generation_runs where need_generation_run_id = 'b5300000-0000-0000-0000-000000000600'), 'same-status blocker evidence leaves warning count exact'),
    ((select count(*) = blocking_issue_count from atlas_planning.need_generation_issues i join atlas_planning.need_generation_runs r using (need_generation_run_id) where r.need_generation_run_id = 'b5300000-0000-0000-0000-000000000600' group by r.blocking_issue_count), 'stored blocker count equals exact immutable rows'),
    ((select count(*) = generated_line_count from atlas_planning.theoretical_need_lines l join atlas_planning.need_generation_runs r using (need_generation_run_id) where r.need_generation_run_id = 'b5300000-0000-0000-0000-000000000600' group by r.generated_line_count), 'stored generated line count equals exact immutable rows'),
    ((select count(*) = 2 from atlas_planning.need_generation_runs where planning_input_set_id = 'b5300000-0000-0000-0000-000000000400'), 'history retains both accepted attempts'),
    ((select array_agg(attempt_ordinal order by attempt_ordinal) = array[1,2]::bigint[] from atlas_planning.need_generation_runs where planning_input_set_id = 'b5300000-0000-0000-0000-000000000400'), 'attempt history is contiguous'),
    ((select count(*) = 1 from atlas_planning.theoretical_need_lines where predecessor_theoretical_need_line_id = 'b5300000-0000-0000-0000-000000000530'), 'predecessor history does not fork'),
    ((select count(*) = 1 from atlas_planning.need_generation_release_snapshots where need_generation_run_id = 'b5300000-0000-0000-0000-000000000500'), 'released history has exactly one snapshot'),
    ((select count(*) = 1 from atlas_planning.need_generation_release_snapshot_lines where need_generation_run_id = 'b5300000-0000-0000-0000-000000000500'), 'released history has complete line membership'),
    ((select count(*) = 0 from atlas_planning.need_generation_release_snapshot_issues where need_generation_run_id = 'b5300000-0000-0000-0000-000000000500'), 'zero-warning release has exact empty issue membership'),
    ((select blocking_issue_count = 0 from atlas_planning.need_generation_release_snapshots where need_generation_release_snapshot_id = 'b5300000-0000-0000-0000-000000000540'), 'released summary has zero blockers'),
    ((select warning_count = 0 from atlas_planning.need_generation_release_snapshots where need_generation_release_snapshot_id = 'b5300000-0000-0000-0000-000000000540'), 'released summary has zero warnings'),
    ((select message = 'Validation discovered a blocking issue.' from atlas_planning.need_generation_issues where need_generation_issue_id = 'b5300000-0000-0000-0000-000000000640'), 'issue message is retained as immutable evidence'),
    ((select created_at = timestamptz '2027-01-01 13:30:00+07' from atlas_planning.need_generation_issues where need_generation_issue_id = 'b5300000-0000-0000-0000-000000000640'), 'issue creation time is retained'),
    ((select version = 3 from atlas_planning.need_generation_runs where need_generation_run_id = 'b5300000-0000-0000-0000-000000000600'), 'failed progression and invalidation each increment version exactly once'),
    ((select version = 4 from atlas_planning.need_generation_runs where need_generation_run_id = 'b5300000-0000-0000-0000-000000000500'), 'validation release and invalidation each increment version exactly once'),
    ((select run_status = 'INVALIDATED' from atlas_planning.need_generation_runs where need_generation_run_id = 'b5300000-0000-0000-0000-000000000500'), 'released run ends only through explicit invalidation'),
    ((select run_status = 'INVALIDATED' from atlas_planning.need_generation_runs where need_generation_run_id = 'b5300000-0000-0000-0000-000000000600'), 'blocked run ends only through explicit invalidation'),
    ((select validated_at is null and released_at is null from atlas_planning.need_generation_runs where need_generation_run_id = 'b5300000-0000-0000-0000-000000000600'), 'failed validation creates no successful validation or release evidence'),
    ((select count(*) = 0 from atlas_planning.need_generation_release_snapshots where need_generation_run_id = 'b5300000-0000-0000-0000-000000000600'), 'failed validation creates no partial release snapshot'),
    ((select count(*) = 0 from atlas_planning.need_generation_release_snapshot_lines where need_generation_run_id = 'b5300000-0000-0000-0000-000000000600'), 'failed validation creates no partial release line membership'),
    ((select count(*) = 0 from atlas_planning.need_generation_release_snapshot_issues where need_generation_run_id = 'b5300000-0000-0000-0000-000000000600'), 'failed validation creates no partial release issue membership'),
    ((select predecessor_need_generation_run_id is null from atlas_planning.need_generation_runs where need_generation_run_id = 'b5300000-0000-0000-0000-000000000500'), 'first attempt has no predecessor'),
    ((select attempt_ordinal = 2 from atlas_planning.need_generation_runs where need_generation_run_id = 'b5300000-0000-0000-0000-000000000600'), 'successor attempt ordinal is exact'),
    ((select updated_at >= generated_at from atlas_planning.need_generation_runs where need_generation_run_id = 'b5300000-0000-0000-0000-000000000500'), 'historical run timestamps remain ordered'),
    ((select updated_at >= generated_at from atlas_planning.need_generation_runs where need_generation_run_id = 'b5300000-0000-0000-0000-000000000600'), 'blocked run timestamps remain ordered'),
    ((select count(*) = 1 from atlas_planning.need_generation_issues where severity = 'BLOCKING' and need_generation_run_id = 'b5300000-0000-0000-0000-000000000600'), 'history owns one blocking issue'),
    ((select count(*) = 0 from atlas_planning.need_generation_issues where severity = 'WARNING' and need_generation_run_id = 'b5300000-0000-0000-0000-000000000600'), 'history owns no warning issue'),
    ((select theoretical_quantity = 10.000000 from atlas_planning.theoretical_need_lines where theoretical_need_line_id = 'b5300000-0000-0000-0000-000000000630'), 'successor contribution remains immutable after invalidation')
) as checks(check_ok, description);

select * from finish();
rollback;
