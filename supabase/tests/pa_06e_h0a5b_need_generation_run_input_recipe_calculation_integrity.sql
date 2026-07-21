begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;

select plan(60);

insert into atlas_core.actors (actor_id, actor_type, display_name) values
  ('b5100000-0000-0000-0000-000000000001', 'HUMAN', 'H0A5b generator'),
  ('b5100000-0000-0000-0000-000000000002', 'HUMAN', 'H0A5b approver');

insert into atlas_admin.customers (
  customer_id, customer_code, customer_name, customer_type
) values (
  'b5100000-0000-0000-0000-000000000100',
  'pa06e-h0a5b-run-customer', 'H0A5b run customer', 'SCHOOL_CATERING'
);

insert into atlas_admin.delivery_locations (
  delivery_location_id, customer_id, location_code, location_name,
  address_text, timezone_name
) values (
  'b5100000-0000-0000-0000-000000000101',
  'b5100000-0000-0000-0000-000000000100',
  'pa06e-h0a5b-run-location', 'H0A5b run location',
  'Local-only H0A5b fixture', 'Asia/Ho_Chi_Minh'
);

insert into atlas_admin.school_types (
  school_type_id, school_type_code, school_type_name
) values (
  'b5100000-0000-0000-0000-000000000110',
  'pa06e-h0a5b-run-type', 'H0A5b run type'
);

insert into atlas_admin.schools (
  school_id, customer_id, school_code, school_name, school_type_id,
  default_delivery_location_id, display_order
) values (
  'b5100000-0000-0000-0000-000000000120',
  'b5100000-0000-0000-0000-000000000100',
  'pa06e-h0a5b-run-school', 'H0A5b Run School',
  'b5100000-0000-0000-0000-000000000110',
  'b5100000-0000-0000-0000-000000000101', 10
);

insert into atlas_admin.units (unit_id, unit_code, unit_name, dimension_code)
values (
  'b5100000-0000-0000-0000-000000000130',
  'kg-h0a5b-run', 'kilogram H0A5b run', 'mass'
);

insert into atlas_admin.ingredients (
  ingredient_id, ingredient_code, ingredient_name
) values (
  'b5100000-0000-0000-0000-000000000140',
  'h0a5b-run-rice', 'H0A5b run rice'
);

insert into atlas_admin.dishes (
  dish_id, dish_code, dish_name, dish_status, display_order,
  requires_need_generation
) values (
  'b5100000-0000-0000-0000-000000000150',
  'h0a5b-run-dish', 'H0A5b run dish', 'ACTIVE', 10, true
);

insert into atlas_admin.recipes (recipe_id, dish_id) values (
  'b5100000-0000-0000-0000-000000000160',
  'b5100000-0000-0000-0000-000000000150'
);

insert into atlas_admin.recipe_versions (
  recipe_version_id, recipe_id, version_number, basis_portions,
  created_by_actor_id
) values (
  'b5100000-0000-0000-0000-000000000161',
  'b5100000-0000-0000-0000-000000000160', 1, 100,
  'b5100000-0000-0000-0000-000000000001'
);

insert into atlas_admin.recipe_lines (recipe_line_id, recipe_id, line_code)
values (
  'b5100000-0000-0000-0000-000000000162',
  'b5100000-0000-0000-0000-000000000160', 'rice'
);

insert into atlas_admin.recipe_line_revisions (
  recipe_line_revision_id, recipe_id, recipe_version_id, recipe_line_id,
  line_revision_number, ingredient_id, quantity_per_basis, unit_id,
  created_by_actor_id
) values (
  'b5100000-0000-0000-0000-000000000163',
  'b5100000-0000-0000-0000-000000000160',
  'b5100000-0000-0000-0000-000000000161',
  'b5100000-0000-0000-0000-000000000162', 1,
  'b5100000-0000-0000-0000-000000000140', 12.500000,
  'b5100000-0000-0000-0000-000000000130',
  'b5100000-0000-0000-0000-000000000001'
);

set constraints all immediate;
set constraints all deferred;

update atlas_admin.recipe_versions
set recipe_version_status = 'VALIDATED',
    validated_by_actor_id = 'b5100000-0000-0000-0000-000000000002',
    validated_at = timestamptz '2026-11-01 08:00:00+07'
where recipe_version_id = 'b5100000-0000-0000-0000-000000000161';

update atlas_admin.recipe_versions
set recipe_version_status = 'RELEASED_FOR_PLANNING',
    released_by_actor_id = 'b5100000-0000-0000-0000-000000000002',
    released_at = timestamptz '2026-11-01 08:05:00+07'
where recipe_version_id = 'b5100000-0000-0000-0000-000000000161';

insert into atlas_planning.weekly_menus (
  weekly_menu_id, week_start, week_end, source_type, source_name,
  source_signature, row_count, imported_by_actor_id
) values (
  'b5100000-0000-0000-0000-000000000200',
  date '2026-11-02', date '2026-11-08', 'FIXTURE', 'H0A5b run menu',
  'sha256:h0a5b-run-menu', 1,
  'b5100000-0000-0000-0000-000000000001'
);

insert into atlas_planning.weekly_menu_lines (
  weekly_menu_line_id, weekly_menu_id, school_id, service_date,
  menu_slot_code, dish_id, created_by_actor_id, updated_by_actor_id
) values (
  'b5100000-0000-0000-0000-000000000210',
  'b5100000-0000-0000-0000-000000000200',
  'b5100000-0000-0000-0000-000000000120', date '2026-11-02',
  'savory', 'b5100000-0000-0000-0000-000000000150',
  'b5100000-0000-0000-0000-000000000001',
  'b5100000-0000-0000-0000-000000000001'
);

update atlas_planning.weekly_menus set weekly_menu_status = 'VALIDATED'
where weekly_menu_id = 'b5100000-0000-0000-0000-000000000200';

insert into atlas_planning.weekly_menu_approval_snapshots (
  weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version,
  approved_by_actor_id, approved_at
) values (
  'b5100000-0000-0000-0000-000000000220',
  'b5100000-0000-0000-0000-000000000200', 1,
  'b5100000-0000-0000-0000-000000000002',
  timestamptz '2026-11-01 09:00:00+07'
);

insert into atlas_planning.weekly_menu_approval_snapshot_lines (
  weekly_menu_approval_snapshot_line_id, weekly_menu_approval_snapshot_id,
  weekly_menu_id, weekly_menu_version, weekly_menu_line_id, school_id,
  service_date, menu_slot_code, dish_id
) values (
  'b5100000-0000-0000-0000-000000000221',
  'b5100000-0000-0000-0000-000000000220',
  'b5100000-0000-0000-0000-000000000200', 1,
  'b5100000-0000-0000-0000-000000000210',
  'b5100000-0000-0000-0000-000000000120', date '2026-11-02',
  'savory', 'b5100000-0000-0000-0000-000000000150'
);

update atlas_planning.weekly_menus
set weekly_menu_status = 'APPROVED',
    latest_approved_by_actor_id = 'b5100000-0000-0000-0000-000000000002',
    latest_approved_at = timestamptz '2026-11-01 09:00:00+07',
    latest_approval_snapshot_id = 'b5100000-0000-0000-0000-000000000220'
where weekly_menu_id = 'b5100000-0000-0000-0000-000000000200';

insert into atlas_planning.attendance_batches (
  attendance_batch_id, period_start, period_end, source_type, source_name,
  source_signature, row_count, imported_by_actor_id
) values (
  'b5100000-0000-0000-0000-000000000300',
  date '2026-11-02', date '2026-11-08', 'FIXTURE', 'H0A5b run attendance',
  'sha256:h0a5b-run-attendance', 1,
  'b5100000-0000-0000-0000-000000000001'
);

insert into atlas_planning.attendance_lines (
  attendance_line_id, attendance_batch_id, school_id, service_date,
  student_portions, teacher_portions, created_by_actor_id, updated_by_actor_id
) values (
  'b5100000-0000-0000-0000-000000000310',
  'b5100000-0000-0000-0000-000000000300',
  'b5100000-0000-0000-0000-000000000120', date '2026-11-02', 15, 5,
  'b5100000-0000-0000-0000-000000000001',
  'b5100000-0000-0000-0000-000000000001'
);

update atlas_planning.attendance_batches set attendance_status = 'VALIDATED'
where attendance_batch_id = 'b5100000-0000-0000-0000-000000000300';

insert into atlas_planning.attendance_approval_snapshots (
  attendance_approval_snapshot_id, attendance_batch_id, attendance_version,
  approved_by_actor_id, approved_at
) values (
  'b5100000-0000-0000-0000-000000000320',
  'b5100000-0000-0000-0000-000000000300', 1,
  'b5100000-0000-0000-0000-000000000002',
  timestamptz '2026-11-01 09:05:00+07'
);

insert into atlas_planning.attendance_approval_snapshot_lines (
  attendance_approval_snapshot_line_id, attendance_approval_snapshot_id,
  attendance_batch_id, attendance_version, attendance_line_id, school_id,
  service_date, student_portions, teacher_portions
) values (
  'b5100000-0000-0000-0000-000000000321',
  'b5100000-0000-0000-0000-000000000320',
  'b5100000-0000-0000-0000-000000000300', 1,
  'b5100000-0000-0000-0000-000000000310',
  'b5100000-0000-0000-0000-000000000120', date '2026-11-02', 15, 5
);

update atlas_planning.attendance_batches
set attendance_status = 'APPROVED',
    latest_approved_by_actor_id = 'b5100000-0000-0000-0000-000000000002',
    latest_approved_at = timestamptz '2026-11-01 09:05:00+07',
    latest_approval_snapshot_id = 'b5100000-0000-0000-0000-000000000320'
where attendance_batch_id = 'b5100000-0000-0000-0000-000000000300';

set constraints all immediate;
set constraints all deferred;

insert into atlas_planning.planning_input_sets (
  planning_input_set_id, period_start, period_end, readiness_status,
  current_evaluation_id
) values (
  'b5100000-0000-0000-0000-000000000400',
  date '2026-11-02', date '2026-11-02', 'READY',
  'b5100000-0000-0000-0000-000000000401'
);

insert into atlas_planning.planning_input_evaluations (
  planning_input_evaluation_id, planning_input_set_id, evaluation_version,
  evaluation_result, weekly_menu_id, weekly_menu_version,
  weekly_menu_approval_snapshot_id, attendance_batch_id,
  attendance_version, attendance_approval_snapshot_id,
  blocking_issue_count, warning_count, evaluated_by_actor_id, evaluated_at
) values (
  'b5100000-0000-0000-0000-000000000401',
  'b5100000-0000-0000-0000-000000000400', 1, 'READY',
  'b5100000-0000-0000-0000-000000000200', 1,
  'b5100000-0000-0000-0000-000000000220',
  'b5100000-0000-0000-0000-000000000300', 1,
  'b5100000-0000-0000-0000-000000000320', 0, 0,
  'b5100000-0000-0000-0000-000000000001',
  timestamptz '2026-11-01 09:10:00+07'
);

set constraints all immediate;
set constraints all deferred;

update atlas_planning.planning_input_sets
set readiness_status = 'NEED_GENERATION_REQUESTED',
    updated_at = updated_at + interval '1 second'
where planning_input_set_id = 'b5100000-0000-0000-0000-000000000400';

insert into atlas_planning.need_generation_calculation_contracts (
  need_generation_calculation_contract_id, contract_code,
  current_revision_id, version, created_at, updated_at
) values (
  'b5100000-0000-0000-0000-000000000700',
  'school_catering_proportional_per_basis',
  'b5100000-0000-0000-0000-000000000701', 1,
  timestamptz '2026-11-01 07:00:00+07',
  timestamptz '2026-11-01 07:00:00+07'
);

insert into atlas_planning.need_generation_calculation_contract_revisions (
  need_generation_calculation_contract_revision_id,
  need_generation_calculation_contract_id, revision_number,
  formula_kind, quantity_precision, quantity_scale,
  factor_precision, factor_scale, final_coercion_mode,
  approved_by_actor_id, approved_at
) values (
  'b5100000-0000-0000-0000-000000000701',
  'b5100000-0000-0000-0000-000000000700', 1,
  'STUDENT_TEACHER_PORTIONS_X_RECIPE_QTY_DIV_BASIS', 20, 6, 24, 12,
  'POSTGRES_NUMERIC_SCALE_HALF_AWAY_FROM_ZERO',
  'b5100000-0000-0000-0000-000000000002',
  timestamptz '2026-11-01 07:00:00+07'
);

set constraints all immediate;
set constraints all deferred;

insert into atlas_planning.need_generation_runs (
  need_generation_run_id, planning_input_set_id,
  planning_input_evaluation_id, evaluation_version,
  period_start, period_end, attempt_ordinal, input_snapshot_id,
  run_status, version, generated_line_count, blocking_issue_count,
  warning_count, generated_by_actor_id, generated_at, updated_at
) values (
  'b5100000-0000-0000-0000-000000000500',
  'b5100000-0000-0000-0000-000000000400',
  'b5100000-0000-0000-0000-000000000401', 1,
  date '2026-11-02', date '2026-11-02', 1,
  'b5100000-0000-0000-0000-000000000501',
  'GENERATED', 1, 1, 0, 0,
  'b5100000-0000-0000-0000-000000000001',
  timestamptz '2026-11-01 10:00:00+07',
  timestamptz '2026-11-01 10:00:00+07'
);

insert into atlas_planning.need_generation_input_snapshots (
  need_generation_input_snapshot_id, need_generation_run_id,
  planning_input_set_id, planning_input_evaluation_id, evaluation_version,
  weekly_menu_id, weekly_menu_version, weekly_menu_approval_snapshot_id,
  attendance_batch_id, attendance_version, attendance_approval_snapshot_id,
  need_generation_calculation_contract_id,
  need_generation_calculation_contract_revision_id,
  calculation_contract_revision_number, captured_at
) values (
  'b5100000-0000-0000-0000-000000000501',
  'b5100000-0000-0000-0000-000000000500',
  'b5100000-0000-0000-0000-000000000400',
  'b5100000-0000-0000-0000-000000000401', 1,
  'b5100000-0000-0000-0000-000000000200', 1,
  'b5100000-0000-0000-0000-000000000220',
  'b5100000-0000-0000-0000-000000000300', 1,
  'b5100000-0000-0000-0000-000000000320',
  'b5100000-0000-0000-0000-000000000700',
  'b5100000-0000-0000-0000-000000000701', 1,
  timestamptz '2026-11-01 10:00:00+07'
);

insert into atlas_planning.need_generation_recipe_selections (
  need_generation_recipe_selection_id, need_generation_input_snapshot_id,
  need_generation_run_id, weekly_menu_approval_snapshot_line_id,
  weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version,
  weekly_menu_line_id, school_id, school_type_id, dish_id, recipe_id,
  recipe_version_id, recipe_version_number, selection_scope, selected_at
) values (
  'b5100000-0000-0000-0000-000000000510',
  'b5100000-0000-0000-0000-000000000501',
  'b5100000-0000-0000-0000-000000000500',
  'b5100000-0000-0000-0000-000000000221',
  'b5100000-0000-0000-0000-000000000220',
  'b5100000-0000-0000-0000-000000000200', 1,
  'b5100000-0000-0000-0000-000000000210',
  'b5100000-0000-0000-0000-000000000120',
  'b5100000-0000-0000-0000-000000000110',
  'b5100000-0000-0000-0000-000000000150',
  'b5100000-0000-0000-0000-000000000160',
  'b5100000-0000-0000-0000-000000000161', 1, 'GENERAL',
  timestamptz '2026-11-01 10:00:00+07'
);

insert into atlas_planning.need_generation_recipe_line_uses (
  need_generation_recipe_line_use_id, need_generation_input_snapshot_id,
  need_generation_run_id, need_generation_recipe_selection_id,
  recipe_id, recipe_version_id, recipe_line_id, recipe_line_revision_id,
  captured_at
) values (
  'b5100000-0000-0000-0000-000000000520',
  'b5100000-0000-0000-0000-000000000501',
  'b5100000-0000-0000-0000-000000000500',
  'b5100000-0000-0000-0000-000000000510',
  'b5100000-0000-0000-0000-000000000160',
  'b5100000-0000-0000-0000-000000000161',
  'b5100000-0000-0000-0000-000000000162',
  'b5100000-0000-0000-0000-000000000163',
  timestamptz '2026-11-01 10:00:00+07'
);

insert into atlas_planning.theoretical_need_lines (
  theoretical_need_line_id, need_generation_run_id,
  need_generation_input_snapshot_id, need_generation_recipe_selection_id,
  need_generation_recipe_line_use_id,
  weekly_menu_approval_snapshot_line_id, weekly_menu_approval_snapshot_id,
  weekly_menu_id, weekly_menu_version, weekly_menu_line_id,
  attendance_approval_snapshot_line_id, attendance_approval_snapshot_id,
  attendance_batch_id, attendance_version, attendance_line_id,
  school_id, service_date, dish_id, recipe_id, recipe_version_id,
  recipe_line_id, recipe_line_revision_id, ingredient_id, unit_id,
  need_generation_calculation_contract_id,
  need_generation_calculation_contract_revision_id,
  calculation_contract_revision_number, line_disposition,
  theoretical_quantity, created_at
) values (
  'b5100000-0000-0000-0000-000000000530',
  'b5100000-0000-0000-0000-000000000500',
  'b5100000-0000-0000-0000-000000000501',
  'b5100000-0000-0000-0000-000000000510',
  'b5100000-0000-0000-0000-000000000520',
  'b5100000-0000-0000-0000-000000000221',
  'b5100000-0000-0000-0000-000000000220',
  'b5100000-0000-0000-0000-000000000200', 1,
  'b5100000-0000-0000-0000-000000000210',
  'b5100000-0000-0000-0000-000000000321',
  'b5100000-0000-0000-0000-000000000320',
  'b5100000-0000-0000-0000-000000000300', 1,
  'b5100000-0000-0000-0000-000000000310',
  'b5100000-0000-0000-0000-000000000120', date '2026-11-02',
  'b5100000-0000-0000-0000-000000000150',
  'b5100000-0000-0000-0000-000000000160',
  'b5100000-0000-0000-0000-000000000161',
  'b5100000-0000-0000-0000-000000000162',
  'b5100000-0000-0000-0000-000000000163',
  'b5100000-0000-0000-0000-000000000140',
  'b5100000-0000-0000-0000-000000000130',
  'b5100000-0000-0000-0000-000000000700',
  'b5100000-0000-0000-0000-000000000701', 1,
  'ACTIVE', 2.500000, timestamptz '2026-11-01 10:00:00+07'
);

select lives_ok(
  $$ set constraints all immediate; set constraints all deferred $$,
  'a complete run commits with exact readiness, input, Recipe, composition, and calculation ownership'
);

select is(
  (select row(contract_code, version)::text from atlas_planning.need_generation_calculation_contracts where need_generation_calculation_contract_id = 'b5100000-0000-0000-0000-000000000700'),
  '(school_catering_proportional_per_basis,1)',
  'the fixed calculation contract root is exact'
);

select is(
  (select row(formula_kind, quantity_precision, quantity_scale, factor_precision, factor_scale, final_coercion_mode)::text from atlas_planning.need_generation_calculation_contract_revisions where need_generation_calculation_contract_revision_id = 'b5100000-0000-0000-0000-000000000701'),
  '(STUDENT_TEACHER_PORTIONS_X_RECIPE_QTY_DIV_BASIS,20,6,24,12,POSTGRES_NUMERIC_SCALE_HALF_AWAY_FROM_ZERO)',
  'the immutable calculation revision stores only the approved constants'
);

select is(
  (select row(run_status, version, attempt_ordinal, generated_line_count, blocking_issue_count, warning_count)::text from atlas_planning.need_generation_runs where need_generation_run_id = 'b5100000-0000-0000-0000-000000000500'),
  '(GENERATED,1,1,1,0,0)',
  'the accepted first run enters GENERATED at version one with exact counts'
);

select is(
  (select row(planning_input_set_id, planning_input_evaluation_id, evaluation_version)::text from atlas_planning.need_generation_input_snapshots where need_generation_input_snapshot_id = 'b5100000-0000-0000-0000-000000000501'),
  '(b5100000-0000-0000-0000-000000000400,b5100000-0000-0000-0000-000000000401,1)',
  'the input snapshot repeats exact readiness ownership'
);

select is(
  (select row(selection_scope, school_type_id, recipe_id, recipe_version_number)::text from atlas_planning.need_generation_recipe_selections where need_generation_recipe_selection_id = 'b5100000-0000-0000-0000-000000000510'),
  '(GENERAL,b5100000-0000-0000-0000-000000000110,b5100000-0000-0000-0000-000000000160,1)',
  'general fallback preserves the selected School context and exact RecipeVersion'
);

select is(
  (select row(recipe_id, recipe_version_id, recipe_line_id, recipe_line_revision_id)::text from atlas_planning.need_generation_recipe_line_uses where need_generation_recipe_line_use_id = 'b5100000-0000-0000-0000-000000000520'),
  '(b5100000-0000-0000-0000-000000000160,b5100000-0000-0000-0000-000000000161,b5100000-0000-0000-0000-000000000162,b5100000-0000-0000-0000-000000000163)',
  'composition use retains exact H0A2 ownership'
);

select is(
  (select theoretical_quantity from atlas_planning.theoretical_need_lines where theoretical_need_line_id = 'b5100000-0000-0000-0000-000000000530'),
  2.500000::numeric(20, 6),
  'PostgreSQL computes (15 + 5) x 12.5 / 100 with one final numeric(20,6) coercion'
);

select is((select readiness_status from atlas_planning.planning_input_sets where planning_input_set_id = 'b5100000-0000-0000-0000-000000000400'), 'NEED_GENERATION_REQUESTED', 'entry binds a requested readiness root');
select is((select evaluation_result from atlas_planning.planning_input_evaluations where planning_input_evaluation_id = 'b5100000-0000-0000-0000-000000000401'), 'READY', 'entry binds the current READY evaluation');
select is((select row(weekly_menu_status, version)::text from atlas_planning.weekly_menus where weekly_menu_id = 'b5100000-0000-0000-0000-000000000200'), '(APPROVED,1)', 'entry binds the current approved Menu snapshot');
select is((select row(attendance_status, version)::text from atlas_planning.attendance_batches where attendance_batch_id = 'b5100000-0000-0000-0000-000000000300'), '(APPROVED,1)', 'entry binds the current approved Attendance snapshot');
select is((select row(recipe_status, school_type_id)::text from atlas_admin.recipes where recipe_id = 'b5100000-0000-0000-0000-000000000160'), '(ACTIVE,)', 'the deterministic fallback Recipe is active and general');
select is((select count(*)::integer from atlas_planning.need_generation_recipe_line_uses where need_generation_recipe_selection_id = 'b5100000-0000-0000-0000-000000000510'), 1, 'every-and-only the selected RecipeVersion composition is captured');
select is((select count(*)::integer from atlas_planning.need_generation_recipe_selections where need_generation_run_id = 'b5100000-0000-0000-0000-000000000500'), 1, 'one generation-required Menu line has exactly one selection');
select is((select count(*)::integer from atlas_planning.theoretical_need_lines where need_generation_run_id = 'b5100000-0000-0000-0000-000000000500'), 1, 'the run stores one atomic contribution without aggregation');
select is((select count(*)::integer from atlas_planning.need_generation_issues where need_generation_run_id = 'b5100000-0000-0000-0000-000000000500'), 0, 'the valid positive run owns no issues');
select is((select predecessor_need_generation_run_id from atlas_planning.need_generation_runs where need_generation_run_id = 'b5100000-0000-0000-0000-000000000500'), null::uuid, 'the first attempt has no predecessor');
select is((select count(*)::integer from atlas_planning.need_generation_calculation_contracts), 1, 'the fixture creates only one contract root');
select is((select count(*)::integer from atlas_planning.need_generation_release_snapshots where need_generation_run_id = 'b5100000-0000-0000-0000-000000000500'), 0, 'GENERATED owns no release evidence');
select is((select need_generation_calculation_contract_revision_id from atlas_planning.need_generation_input_snapshots where need_generation_input_snapshot_id = 'b5100000-0000-0000-0000-000000000501'), 'b5100000-0000-0000-0000-000000000701'::uuid, 'the input snapshot binds the exact current calculation revision');

select throws_ok(
  $$ insert into atlas_planning.need_generation_calculation_contracts (need_generation_calculation_contract_id, contract_code, current_revision_id, version) values ('b5100000-0000-0000-0000-000000000710', 'wrong', 'b5100000-0000-0000-0000-000000000711', 1) $$,
  '23514',
  'new row for relation "need_generation_calculation_contracts" violates check constraint "need_generation_calculation_contracts_code_check"',
  'unapproved calculation contract codes are rejected'
);

select throws_ok(
  $$ update atlas_planning.need_generation_calculation_contract_revisions set formula_kind = formula_kind where need_generation_calculation_contract_revision_id = 'b5100000-0000-0000-0000-000000000701' $$,
  '23514', 'calculation contract revisions are immutable and nondeletable',
  'calculation revisions cannot be updated'
);

select throws_ok(
  $$ delete from atlas_planning.need_generation_calculation_contract_revisions where need_generation_calculation_contract_revision_id = 'b5100000-0000-0000-0000-000000000701' $$,
  '23514', 'calculation contract revisions are immutable and nondeletable',
  'calculation revisions cannot be deleted'
);

select throws_ok(
  $$ delete from atlas_planning.need_generation_calculation_contracts where need_generation_calculation_contract_id = 'b5100000-0000-0000-0000-000000000700' $$,
  '23514', 'need generation calculation contracts are nondeletable',
  'calculation contract roots cannot be deleted'
);

select throws_ok(
  $$ update atlas_planning.need_generation_calculation_contracts set updated_at = updated_at + interval '1 second' where need_generation_calculation_contract_id = 'b5100000-0000-0000-0000-000000000700' $$,
  '23514', 'calculation contract pointer advances by exactly one revision',
  'contract maintenance requires an exact direct successor revision'
);

select throws_ok(
  $$ delete from atlas_planning.need_generation_runs where need_generation_run_id = 'b5100000-0000-0000-0000-000000000500' $$,
  '23514', 'need generation runs are nondeletable',
  'accepted runs cannot be deleted'
);

select throws_ok(
  $$ update atlas_planning.need_generation_input_snapshots set captured_at = captured_at where need_generation_input_snapshot_id = 'b5100000-0000-0000-0000-000000000501' $$,
  '23514', 'need generation input, lineage, issue, and release evidence is immutable and nondeletable',
  'input snapshots are immutable'
);

select throws_ok(
  $$ delete from atlas_planning.need_generation_input_snapshots where need_generation_input_snapshot_id = 'b5100000-0000-0000-0000-000000000501' $$,
  '23514', 'need generation input, lineage, issue, and release evidence is immutable and nondeletable',
  'input snapshots are nondeletable'
);

select throws_ok(
  $$ update atlas_planning.need_generation_recipe_selections set selected_at = selected_at where need_generation_recipe_selection_id = 'b5100000-0000-0000-0000-000000000510' $$,
  '23514', 'need generation input, lineage, issue, and release evidence is immutable and nondeletable',
  'Recipe selections are immutable'
);

select throws_ok(
  $$ delete from atlas_planning.need_generation_recipe_selections where need_generation_recipe_selection_id = 'b5100000-0000-0000-0000-000000000510' $$,
  '23514', 'need generation input, lineage, issue, and release evidence is immutable and nondeletable',
  'Recipe selections are nondeletable'
);

select throws_ok(
  $$ update atlas_planning.need_generation_recipe_line_uses set captured_at = captured_at where need_generation_recipe_line_use_id = 'b5100000-0000-0000-0000-000000000520' $$,
  '23514', 'need generation input, lineage, issue, and release evidence is immutable and nondeletable',
  'Recipe composition uses are immutable'
);

select throws_ok(
  $$ delete from atlas_planning.need_generation_recipe_line_uses where need_generation_recipe_line_use_id = 'b5100000-0000-0000-0000-000000000520' $$,
  '23514', 'need generation input, lineage, issue, and release evidence is immutable and nondeletable',
  'Recipe composition uses are nondeletable'
);

select throws_ok(
  $$ insert into atlas_planning.need_generation_runs (need_generation_run_id, planning_input_set_id, planning_input_evaluation_id, evaluation_version, period_start, period_end, attempt_ordinal, input_snapshot_id, run_status, version, generated_line_count, blocking_issue_count, warning_count, generated_by_actor_id, generated_at, validated_by_actor_id, validated_at, updated_at) values ('b5100000-0000-0000-0000-000000000590', 'b5100000-0000-0000-0000-000000000400', 'b5100000-0000-0000-0000-000000000401', 1, date '2026-11-02', date '2026-11-02', 2, 'b5100000-0000-0000-0000-000000000591', 'VALIDATED', 1, 0, 0, 0, 'b5100000-0000-0000-0000-000000000001', timestamptz '2026-11-01 11:00:00+07', 'b5100000-0000-0000-0000-000000000001', timestamptz '2026-11-01 11:00:00+07', timestamptz '2026-11-01 11:00:00+07') $$,
  '23514', 'new need generation runs enter GENERATED at version one',
  'new runs cannot enter as VALIDATED'
);

select throws_ok(
  $$ update atlas_planning.need_generation_runs set generated_line_count = 2, version = 2, updated_at = updated_at + interval '1 second' where need_generation_run_id = 'b5100000-0000-0000-0000-000000000500' $$,
  '23514', 'need generation run identity, source, predecessor, snapshot, and generated facts are immutable',
  'stored generated facts cannot be rewritten'
);

select ok(check_ok, description)
from (
  values
    (exists (select 1 from pg_constraint where conrelid = 'atlas_planning.need_generation_runs'::regclass and conname = 'need_generation_runs_evaluation_fkey'), 'run has exact evaluation/root/version ownership'),
    (exists (select 1 from pg_constraint where conrelid = 'atlas_planning.need_generation_runs'::regclass and conname = 'need_generation_runs_input_snapshot_fkey' and condeferrable and condeferred), 'run and input snapshot circular ownership is deferred'),
    (exists (select 1 from pg_constraint where conrelid = 'atlas_planning.need_generation_input_snapshots'::regclass and conname = 'need_generation_input_snapshots_run_fkey' and condeferrable and condeferred), 'input snapshot and run circular ownership is deferred'),
    (exists (select 1 from pg_constraint where conrelid = 'atlas_planning.need_generation_input_snapshots'::regclass and conname = 'need_generation_input_snapshots_menu_fkey'), 'input snapshot owns an exact Menu triple'),
    (exists (select 1 from pg_constraint where conrelid = 'atlas_planning.need_generation_input_snapshots'::regclass and conname = 'need_generation_input_snapshots_attendance_fkey'), 'input snapshot owns an exact Attendance triple'),
    (exists (select 1 from pg_constraint where conrelid = 'atlas_planning.need_generation_input_snapshots'::regclass and conname = 'need_generation_input_snapshots_contract_revision_fkey'), 'input snapshot owns an exact calculation revision triple'),
    (exists (select 1 from pg_constraint where conrelid = 'atlas_planning.need_generation_recipe_selections'::regclass and conname = 'need_generation_recipe_selections_menu_line_key'), 'one snapshot Menu line has at most one selection'),
    (exists (select 1 from pg_constraint where conrelid = 'atlas_planning.need_generation_recipe_selections'::regclass and conname = 'need_generation_recipe_selections_recipe_version_fkey'), 'selection owns an exact RecipeVersion'),
    (exists (select 1 from pg_constraint where conrelid = 'atlas_planning.need_generation_recipe_line_uses'::regclass and conname = 'need_generation_recipe_line_uses_selection_line_key'), 'one selected RecipeLine has one composition use'),
    (exists (select 1 from pg_constraint where conrelid = 'atlas_planning.need_generation_recipe_line_uses'::regclass and conname = 'need_generation_recipe_line_uses_revision_fkey'), 'composition use owns the exact RecipeLineRevision'),
    ((select basis_portions = 100 from atlas_admin.recipe_versions where recipe_version_id = 'b5100000-0000-0000-0000-000000000161'), 'formula denominator is the exact released basis'),
    ((select quantity_per_basis = 12.500000 from atlas_admin.recipe_line_revisions where recipe_line_revision_id = 'b5100000-0000-0000-0000-000000000163'), 'formula multiplier is the exact immutable Recipe quantity'),
    ((select student_portions = 15 from atlas_planning.attendance_approval_snapshot_lines where attendance_approval_snapshot_line_id = 'b5100000-0000-0000-0000-000000000321'), 'formula uses the exact approved student portions'),
    ((select teacher_portions = 5 from atlas_planning.attendance_approval_snapshot_lines where attendance_approval_snapshot_line_id = 'b5100000-0000-0000-0000-000000000321'), 'formula uses the exact approved teacher portions'),
    ((select recipe_version_status = 'RELEASED_FOR_PLANNING' from atlas_admin.recipe_versions where recipe_version_id = 'b5100000-0000-0000-0000-000000000161'), 'only a released RecipeVersion is selected'),
    ((select dish_status = 'ACTIVE' and requires_need_generation from atlas_admin.dishes where dish_id = 'b5100000-0000-0000-0000-000000000150'), 'selected Dish is active and requires generation'),
    ((select period_start = date '2026-11-02' and period_end = date '2026-11-02' from atlas_planning.need_generation_runs where need_generation_run_id = 'b5100000-0000-0000-0000-000000000500'), 'run period exactly inherits the Planning Input Set'),
    ((select weekly_menu_approval_snapshot_id = 'b5100000-0000-0000-0000-000000000220' from atlas_planning.need_generation_input_snapshots where need_generation_input_snapshot_id = 'b5100000-0000-0000-0000-000000000501'), 'snapshot repeats the evaluation Menu identity'),
    ((select attendance_approval_snapshot_id = 'b5100000-0000-0000-0000-000000000320' from atlas_planning.need_generation_input_snapshots where need_generation_input_snapshot_id = 'b5100000-0000-0000-0000-000000000501'), 'snapshot repeats the evaluation Attendance identity'),
    ((select school_id = 'b5100000-0000-0000-0000-000000000120' from atlas_planning.need_generation_recipe_selections where need_generation_recipe_selection_id = 'b5100000-0000-0000-0000-000000000510'), 'selection preserves exact School ownership'),
    ((select dish_id = 'b5100000-0000-0000-0000-000000000150' from atlas_planning.need_generation_recipe_selections where need_generation_recipe_selection_id = 'b5100000-0000-0000-0000-000000000510'), 'selection preserves exact Dish ownership'),
    ((select weekly_menu_line_id = 'b5100000-0000-0000-0000-000000000210' from atlas_planning.need_generation_recipe_selections where need_generation_recipe_selection_id = 'b5100000-0000-0000-0000-000000000510'), 'selection preserves the stable Menu line'),
    ((select recipe_line_revision_id = 'b5100000-0000-0000-0000-000000000163' from atlas_planning.need_generation_recipe_line_uses where need_generation_recipe_line_use_id = 'b5100000-0000-0000-0000-000000000520'), 'composition use preserves the exact immutable source revision'),
    ((select calculation_contract_revision_number = 1 from atlas_planning.need_generation_input_snapshots where need_generation_input_snapshot_id = 'b5100000-0000-0000-0000-000000000501'), 'calculation revision number is typed and explicit'),
    ((select captured_at = generated_at from atlas_planning.need_generation_input_snapshots s join atlas_planning.need_generation_runs r on r.need_generation_run_id = s.need_generation_run_id where s.need_generation_input_snapshot_id = 'b5100000-0000-0000-0000-000000000501'), 'capture and generation timestamps are preserved exactly')
) as checks(check_ok, description);

select * from finish();
rollback;
