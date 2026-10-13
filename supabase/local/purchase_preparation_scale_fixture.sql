-- Disposable one-day Purchase Preparation scale fixture.
--
-- Reuse the guarded RMVP-05 source template, then create two independent daily
-- Planning chains. Each has 4 Schools / 4 locations x 59 Ingredients = 236
-- positive Confirmed Need lines. All business triggers remain enabled. The
-- paired test supplies the human quantity decisions through public Save calls.
\ir purchase_review_confirm_release_fixture.sql

set constraints all deferred;

create temporary table scale_results (
  name text primary key,
  response jsonb not null,
  started_at timestamptz,
  command_finished_at timestamptz,
  guards_finished_at timestamptz
);
create temporary table scale_requests (
  name text primary key,
  request jsonb not null
);
grant select, insert, update on scale_results, scale_requests to authenticated;

create function pg_temp.seed_purchase_preparation_scale(
  p_seed text,
  p_code_prefix text,
  p_service_date date,
  p_master_seed text default null
) returns uuid
language plpgsql
set search_path=''
as $purchase_preparation_scale_fixture$
declare
  v_actor_id constant uuid := 'b6000000-0000-0000-0000-000000000001';
  v_master_seed constant text := coalesce(p_master_seed,p_seed);
  v_customer_id constant uuid := md5(v_master_seed || ':customer')::uuid;
  v_batch_id constant uuid := md5(p_seed || ':confirmed-need-batch')::uuid;
  v_week_end constant date := p_service_date + 6;
  v_period_end constant date := case when p_master_seed is null then p_service_date else v_week_end end;
  v_weekly_menu_id constant uuid := md5(v_master_seed || ':weekly-menu')::uuid;
  v_weekly_menu_snapshot_id constant uuid := md5(v_master_seed || ':weekly-menu-snapshot')::uuid;
  v_attendance_id constant uuid := md5(v_master_seed || ':attendance')::uuid;
  v_attendance_snapshot_id constant uuid := md5(v_master_seed || ':attendance-snapshot')::uuid;
  v_pantry_id constant uuid := md5(v_master_seed || ':pantry')::uuid;
  v_pantry_snapshot_id constant uuid := md5(v_master_seed || ':pantry-snapshot')::uuid;
  v_input_set_id constant uuid := md5(p_seed || ':input-set')::uuid;
  v_evaluation_id constant uuid := md5(p_seed || ':evaluation')::uuid;
  v_run_id constant uuid := md5(p_seed || ':need-run')::uuid;
  v_input_snapshot_id constant uuid := md5(p_seed || ':input-snapshot')::uuid;
  v_release_snapshot_id constant uuid := md5(p_seed || ':release-snapshot')::uuid;
  v_now timestamptz := pg_catalog.transaction_timestamp();
begin
  if p_seed is null or p_seed = ''
    or p_code_prefix is null or p_code_prefix = ''
    or p_service_date is null then
    raise exception 'Purchase Preparation scale fixture requires a seed, code prefix and service date.';
  end if;

  if exists (
    select 1
    from atlas_planning.confirmed_need_batches
    where confirmed_need_batch_id = v_batch_id
  ) then
    raise exception 'Purchase Preparation scale fixture already exists.';
  end if;

  -- Overlap reuses approved weekly facts in an independent seven-day input
  -- set; the normal scale chain keeps its original one-day input set.
  if p_master_seed is null then
  insert into atlas_admin.customers
  select (pg_catalog.jsonb_populate_record(
    null::atlas_admin.customers,
    pg_catalog.to_jsonb(template) || pg_catalog.jsonb_build_object(
      'customer_id', v_customer_id,
      'customer_code', p_seed,
      'customer_name', p_seed || ' customer'
    )
  )).*
  from atlas_admin.customers template
  where template.customer_id = 'b6500000-0000-0000-0000-000000000001';

  insert into atlas_admin.delivery_locations
  select (pg_catalog.jsonb_populate_record(
    null::atlas_admin.delivery_locations,
    pg_catalog.to_jsonb(template) || pg_catalog.jsonb_build_object(
      'delivery_location_id', md5(v_master_seed || ':location:' || source.location_number)::uuid,
      'customer_id', v_customer_id,
      'location_code', p_code_prefix || '-location-' || source.location_number,
      'location_name', p_code_prefix || ' kitchen ' || source.location_number,
      'address_text', p_code_prefix || ' synthetic address ' || source.location_number
    )
  )).*
  from pg_catalog.generate_series(1, 4) source(location_number)
  cross join atlas_admin.delivery_locations template
  where template.delivery_location_id = 'b6500000-0000-0000-0000-000000000002';

  insert into atlas_admin.schools
  select (pg_catalog.jsonb_populate_record(
    null::atlas_admin.schools,
    pg_catalog.to_jsonb(template) || pg_catalog.jsonb_build_object(
      'school_id', md5(v_master_seed || ':school:' || source.school_number)::uuid,
      'customer_id', v_customer_id,
      'school_code', p_code_prefix || '-school-' || source.school_number,
      'school_name', p_code_prefix || ' school ' || source.school_number,
      'default_delivery_location_id', md5(v_master_seed || ':location:' || source.school_number)::uuid,
      'display_order', 100 + source.school_number
    )
  )).*
  from pg_catalog.generate_series(1, 4) source(school_number)
  cross join atlas_admin.schools template
  where template.school_id = 'b6500000-0000-0000-0000-000000000004';

  insert into atlas_admin.ingredients
  select (pg_catalog.jsonb_populate_record(
    null::atlas_admin.ingredients,
    pg_catalog.to_jsonb(template) || pg_catalog.jsonb_build_object(
      'ingredient_id', md5(v_master_seed || ':ingredient:' || source.ingredient_number)::uuid,
      'ingredient_code', p_code_prefix || '-ingredient-' || source.ingredient_number,
      'ingredient_name', p_code_prefix || ' ingredient ' || source.ingredient_number,
      'document_code', pg_catalog.upper(p_code_prefix) || '-I-' || source.ingredient_number,
      'order_step', 0.1
    )
  )).*
  from pg_catalog.generate_series(1, 59) source(ingredient_number)
  cross join atlas_admin.ingredients template
  where template.ingredient_id = 'b6500000-0000-0000-0000-000000000006';

  insert into atlas_admin.suppliers
  select (pg_catalog.jsonb_populate_record(
    null::atlas_admin.suppliers,
    pg_catalog.to_jsonb(template) || pg_catalog.jsonb_build_object(
      'supplier_id', md5(v_master_seed || ':supplier:' || source.supplier_number)::uuid,
      'supplier_code', p_code_prefix || '-supplier-' || source.supplier_number,
      'supplier_name', p_code_prefix || ' supplier ' || source.supplier_number,
      'supplier_status', 'ACTIVE',
      'document_code', pg_catalog.upper(p_code_prefix) || '-S-' || source.supplier_number
    )
  )).*
  from pg_catalog.generate_series(1, 12) source(supplier_number)
  cross join atlas_admin.suppliers template
  where template.supplier_id = 'c7100000-0000-4000-8000-000000000001';

  -- Every Ingredient has one unique best Supplier plus one eligible alternate.
  insert into atlas_admin.supplier_eligibilities (
    supplier_id,
    ingredient_id,
    effective_from,
    priority,
    reason_note
  )
  select
    md5(v_master_seed || ':supplier:' || eligibility.supplier_number)::uuid,
    md5(v_master_seed || ':ingredient:' || ingredient.ingredient_number)::uuid,
    date '2020-01-01',
    eligibility.priority,
    'Disposable Purchase Preparation scale fixture'
  from pg_catalog.generate_series(1, 59) ingredient(ingredient_number)
  cross join lateral (
    values
      (((ingredient.ingredient_number - 1) % 12) + 1, 1),
      ((ingredient.ingredient_number % 12) + 1, 2)
  ) eligibility(supplier_number, priority);

  insert into atlas_planning.weekly_menus
  select (pg_catalog.jsonb_populate_record(
    null::atlas_planning.weekly_menus,
    pg_catalog.to_jsonb(template) || pg_catalog.jsonb_build_object(
      'weekly_menu_id', v_weekly_menu_id,
      'week_start', p_service_date,
      'week_end', v_week_end,
      'source_name', p_code_prefix || ' empty menu',
      'source_signature', p_seed || '-menu',
      'weekly_menu_status', 'DRAFT',
      'latest_approved_by_actor_id', null,
      'latest_approved_at', null,
      'latest_approval_snapshot_id', null,
      'version', 1,
      'created_at', v_now,
      'updated_at', v_now,
      'imported_at', v_now
    )
  )).*
  from atlas_planning.weekly_menus template
  where template.weekly_menu_id = 'b6510000-0000-0000-0000-000000000001';

  update atlas_planning.weekly_menus
  set weekly_menu_status = 'VALIDATED'
  where weekly_menu_id = v_weekly_menu_id;

  insert into atlas_planning.weekly_menu_approval_snapshots
  select (pg_catalog.jsonb_populate_record(
    null::atlas_planning.weekly_menu_approval_snapshots,
    pg_catalog.to_jsonb(template) || pg_catalog.jsonb_build_object(
      'weekly_menu_approval_snapshot_id', v_weekly_menu_snapshot_id,
      'weekly_menu_id', v_weekly_menu_id,
      'weekly_menu_version', 1,
      'approved_by_actor_id', v_actor_id,
      'approved_at', v_now
    )
  )).*
  from atlas_planning.weekly_menu_approval_snapshots template
  where template.weekly_menu_approval_snapshot_id = 'b6510000-0000-0000-0000-000000000002';

  update atlas_planning.weekly_menus
  set weekly_menu_status = 'APPROVED',
      latest_approved_by_actor_id = v_actor_id,
      latest_approved_at = v_now,
      latest_approval_snapshot_id = v_weekly_menu_snapshot_id
  where weekly_menu_id = v_weekly_menu_id;

  insert into atlas_planning.attendance_batches
  select (pg_catalog.jsonb_populate_record(
    null::atlas_planning.attendance_batches,
    pg_catalog.to_jsonb(template) || pg_catalog.jsonb_build_object(
      'attendance_batch_id', v_attendance_id,
      'period_start', p_service_date,
      'period_end', v_week_end,
      'source_name', p_code_prefix || ' empty attendance',
      'source_signature', p_seed || '-attendance',
      'attendance_status', 'DRAFT',
      'latest_approved_by_actor_id', null,
      'latest_approved_at', null,
      'latest_approval_snapshot_id', null,
      'version', 1,
      'created_at', v_now,
      'updated_at', v_now,
      'imported_at', v_now
    )
  )).*
  from atlas_planning.attendance_batches template
  where template.attendance_batch_id = 'b6520000-0000-0000-0000-000000000001';

  update atlas_planning.attendance_batches
  set attendance_status = 'VALIDATED'
  where attendance_batch_id = v_attendance_id;

  insert into atlas_planning.attendance_approval_snapshots
  select (pg_catalog.jsonb_populate_record(
    null::atlas_planning.attendance_approval_snapshots,
    pg_catalog.to_jsonb(template) || pg_catalog.jsonb_build_object(
      'attendance_approval_snapshot_id', v_attendance_snapshot_id,
      'attendance_batch_id', v_attendance_id,
      'attendance_version', 1,
      'approved_by_actor_id', v_actor_id,
      'approved_at', v_now
    )
  )).*
  from atlas_planning.attendance_approval_snapshots template
  where template.attendance_approval_snapshot_id = 'b6520000-0000-0000-0000-000000000002';

  update atlas_planning.attendance_batches
  set attendance_status = 'APPROVED',
      latest_approved_by_actor_id = v_actor_id,
      latest_approved_at = v_now,
      latest_approval_snapshot_id = v_attendance_snapshot_id
  where attendance_batch_id = v_attendance_id;

  insert into atlas_planning.pantry_need_batches (
    pantry_need_batch_id,
    week_start,
    pantry_need_batch_status,
    version,
    source_type,
    source_name,
    source_signature,
    no_additions_confirmed,
    requesting_actor_id,
    creation_method,
    latest_approved_by_actor_id,
    latest_approved_at,
    latest_approval_snapshot_id,
    created_at,
    updated_at
  )
  select
    populated.pantry_need_batch_id,
    populated.week_start,
    populated.pantry_need_batch_status,
    populated.version,
    populated.source_type,
    populated.source_name,
    populated.source_signature,
    populated.no_additions_confirmed,
    populated.requesting_actor_id,
    populated.creation_method,
    populated.latest_approved_by_actor_id,
    populated.latest_approved_at,
    populated.latest_approval_snapshot_id,
    populated.created_at,
    populated.updated_at
  from atlas_planning.pantry_need_batches template
  cross join lateral pg_catalog.jsonb_populate_record(
    null::atlas_planning.pantry_need_batches,
    pg_catalog.to_jsonb(template) || pg_catalog.jsonb_build_object(
      'pantry_need_batch_id', v_pantry_id,
      'week_start', p_service_date,
      'pantry_need_batch_status', 'DRAFT',
      'version', 1,
      'source_name', 'Nhập thủ công Atlas',
      'source_signature', repeat('c', 64),
      'latest_approved_by_actor_id', null,
      'latest_approved_at', null,
      'latest_approval_snapshot_id', null,
      'created_at', v_now,
      'updated_at', v_now
    )
  ) populated
  where template.pantry_need_batch_id = 'b6530000-0000-0000-0000-000000000002';

  insert into atlas_planning.pantry_need_lines
  select (pg_catalog.jsonb_populate_record(
    null::atlas_planning.pantry_need_lines,
    pg_catalog.to_jsonb(template) || pg_catalog.jsonb_build_object(
      'pantry_need_line_id', md5(p_seed || ':pantry-line:' || source.line_number)::uuid,
      'pantry_need_batch_id', v_pantry_id,
      'service_date', p_service_date,
      'school_id', md5(v_master_seed || ':school:' || source.school_number)::uuid,
      'delivery_location_id', md5(v_master_seed || ':location:' || source.school_number)::uuid,
      'ingredient_id', md5(v_master_seed || ':ingredient:' || source.ingredient_number)::uuid,
      'requested_quantity', source.family_quantity,
      'note', p_code_prefix || ' family ' || source.line_number,
      'source_request_reference', pg_catalog.upper(p_code_prefix),
      'source_row_reference', source.line_number::text,
      'created_at', v_now,
      'updated_at', v_now
    )
  )).*
  from (
    select
      line_number,
      ((line_number - 1) / 59) + 1 as school_number,
      ((line_number - 1) % 59) + 1 as ingredient_number,
      (1 + (line_number % 20))::numeric + ((line_number % 10)::numeric / 10) as family_quantity
    from pg_catalog.generate_series(1, 236) generated(line_number)
  ) source
  cross join atlas_planning.pantry_need_lines template
  where template.pantry_need_line_id = 'b6530000-0000-0000-0000-000000000004';

  update atlas_planning.pantry_need_batches
  set pantry_need_batch_status = 'VALIDATED',
      version = 2,
      updated_at = v_now
  where pantry_need_batch_id = v_pantry_id;

  insert into atlas_planning.pantry_need_approval_snapshots
  select (pg_catalog.jsonb_populate_record(
    null::atlas_planning.pantry_need_approval_snapshots,
    pg_catalog.to_jsonb(template) || pg_catalog.jsonb_build_object(
      'pantry_need_approval_snapshot_id', v_pantry_snapshot_id,
      'pantry_need_batch_id', v_pantry_id,
      'approved_batch_version', 3,
      'approved_by_actor_id', v_actor_id,
      'approved_at', v_now,
      'source_signature', repeat('c', 64),
      'line_count', 236,
      'created_at', v_now
    )
  )).*
  from atlas_planning.pantry_need_approval_snapshots template
  where template.pantry_need_approval_snapshot_id = 'b6530000-0000-0000-0000-000000000003';

  insert into atlas_planning.pantry_need_approval_snapshot_lines
  select (pg_catalog.jsonb_populate_record(
    null::atlas_planning.pantry_need_approval_snapshot_lines,
    pg_catalog.to_jsonb(template) || pg_catalog.jsonb_build_object(
      'pantry_need_approval_snapshot_id', v_pantry_snapshot_id,
      'pantry_need_line_id', line.pantry_need_line_id,
      'service_date', p_service_date,
      'school_id', line.school_id,
      'school_code_snapshot', school.school_code,
      'school_name_snapshot', school.school_name,
      'delivery_location_id', line.delivery_location_id,
      'delivery_location_code_snapshot', location.location_code,
      'delivery_location_name_snapshot', location.location_name,
      'delivery_location_address_snapshot', location.address_text,
      'ingredient_id', line.ingredient_id,
      'ingredient_code_snapshot', ingredient.ingredient_code,
      'ingredient_name_snapshot', ingredient.ingredient_name,
      'requested_quantity', line.requested_quantity,
      'note', line.note,
      'source_request_reference', line.source_request_reference,
      'source_row_reference', line.source_row_reference,
      'created_at', v_now
    )
  )).*
  from atlas_planning.pantry_need_lines line
  join atlas_admin.schools school using (school_id)
  join atlas_admin.delivery_locations location using (delivery_location_id)
  join atlas_admin.ingredients ingredient using (ingredient_id)
  cross join atlas_planning.pantry_need_approval_snapshot_lines template
  where line.pantry_need_batch_id = v_pantry_id
    and template.pantry_need_line_id = 'b6530000-0000-0000-0000-000000000004';

  update atlas_planning.pantry_need_batches
  set pantry_need_batch_status = 'APPROVED',
      version = 3,
      latest_approved_by_actor_id = v_actor_id,
      latest_approved_at = v_now,
      latest_approval_snapshot_id = v_pantry_snapshot_id,
      updated_at = v_now
  where pantry_need_batch_id = v_pantry_id;

  end if;

  insert into atlas_planning.planning_input_sets
  select (pg_catalog.jsonb_populate_record(
    null::atlas_planning.planning_input_sets,
    pg_catalog.to_jsonb(template) || pg_catalog.jsonb_build_object(
      'planning_input_set_id', v_input_set_id,
      'period_start', p_service_date,
      'period_end', v_period_end,
      'readiness_status', 'READY',
      'current_evaluation_id', v_evaluation_id,
      'created_at', v_now,
      'updated_at', v_now
    )
  )).*
  from atlas_planning.planning_input_sets template
  where template.planning_input_set_id = 'b6540000-0000-0000-0000-000000000020';

  insert into atlas_planning.planning_input_evaluations
  select (pg_catalog.jsonb_populate_record(
    null::atlas_planning.planning_input_evaluations,
    pg_catalog.to_jsonb(template) || pg_catalog.jsonb_build_object(
      'planning_input_evaluation_id', v_evaluation_id,
      'planning_input_set_id', v_input_set_id,
      'weekly_menu_id', v_weekly_menu_id,
      'weekly_menu_approval_snapshot_id', v_weekly_menu_snapshot_id,
      'attendance_batch_id', v_attendance_id,
      'attendance_approval_snapshot_id', v_attendance_snapshot_id,
      'pantry_need_batch_id', v_pantry_id,
      'pantry_need_approval_snapshot_id', v_pantry_snapshot_id,
      'evaluated_by_actor_id', v_actor_id,
      'evaluated_at', v_now
    )
  )).*
  from atlas_planning.planning_input_evaluations template
  where template.planning_input_evaluation_id = 'b6540000-0000-0000-0000-000000000021';

  update atlas_planning.planning_input_sets
  set readiness_status = 'NEED_GENERATION_REQUESTED',
      updated_at = v_now
  where planning_input_set_id = v_input_set_id;

  insert into atlas_planning.need_generation_runs
  select (pg_catalog.jsonb_populate_record(
    null::atlas_planning.need_generation_runs,
    pg_catalog.to_jsonb(template) || pg_catalog.jsonb_build_object(
      'need_generation_run_id', v_run_id,
      'planning_input_set_id', v_input_set_id,
      'planning_input_evaluation_id', v_evaluation_id,
      'period_start', p_service_date,
      'period_end', v_period_end,
      'input_snapshot_id', v_input_snapshot_id,
      'run_status', 'GENERATED',
      'version', 1,
      'generated_line_count', 236,
      'generated_by_actor_id', v_actor_id,
      'generated_at', v_now,
      'validated_by_actor_id', null,
      'validated_at', null,
      'released_by_actor_id', null,
      'released_at', null,
      'updated_at', v_now
    )
  )).*
  from atlas_planning.need_generation_runs template
  where template.need_generation_run_id = 'b6550000-0000-0000-0000-000000000001';

  insert into atlas_planning.need_generation_input_snapshots
  select (pg_catalog.jsonb_populate_record(
    null::atlas_planning.need_generation_input_snapshots,
    pg_catalog.to_jsonb(template) || pg_catalog.jsonb_build_object(
      'need_generation_input_snapshot_id', v_input_snapshot_id,
      'need_generation_run_id', v_run_id,
      'planning_input_set_id', v_input_set_id,
      'planning_input_evaluation_id', v_evaluation_id,
      'weekly_menu_id', v_weekly_menu_id,
      'weekly_menu_approval_snapshot_id', v_weekly_menu_snapshot_id,
      'attendance_batch_id', v_attendance_id,
      'attendance_approval_snapshot_id', v_attendance_snapshot_id,
      'pantry_need_batch_id', v_pantry_id,
      'pantry_need_approval_snapshot_id', v_pantry_snapshot_id,
      'captured_at', v_now
    )
  )).*
  from atlas_planning.need_generation_input_snapshots template
  where template.need_generation_input_snapshot_id = 'b6550000-0000-0000-0000-000000000002';

  insert into atlas_planning.theoretical_need_lines
  select (pg_catalog.jsonb_populate_record(
    null::atlas_planning.theoretical_need_lines,
    pg_catalog.to_jsonb(template) || pg_catalog.jsonb_build_object(
      'theoretical_need_line_id', md5(p_seed || ':theoretical-line:' || line.source_row_reference)::uuid,
      'need_generation_run_id', v_run_id,
      'need_generation_input_snapshot_id', v_input_snapshot_id,
      'school_id', line.school_id,
      'service_date', p_service_date,
      'ingredient_id', line.ingredient_id,
      'theoretical_quantity', line.requested_quantity,
      'created_at', v_now,
      'delivery_location_id', line.delivery_location_id,
      'pantry_need_batch_id', v_pantry_id,
      'pantry_need_approval_snapshot_id', v_pantry_snapshot_id,
      'pantry_need_line_id', line.pantry_need_line_id,
      'pantry_active_snapshot_member_line_id', line.pantry_need_line_id
    )
  )).*
  from atlas_planning.pantry_need_lines line
  cross join atlas_planning.theoretical_need_lines template
  where line.pantry_need_batch_id = v_pantry_id
    and template.theoretical_need_line_id = 'b6550000-0000-0000-0000-000000000003';

  update atlas_planning.need_generation_runs
  set run_status = 'VALIDATED',
      version = 2,
      validated_by_actor_id = v_actor_id,
      validated_at = v_now,
      updated_at = v_now
  where need_generation_run_id = v_run_id;

  update atlas_planning.need_generation_runs
  set run_status = 'RELEASED_FOR_CONFIRMATION',
      version = 3,
      released_by_actor_id = v_actor_id,
      released_at = v_now,
      updated_at = v_now
  where need_generation_run_id = v_run_id;

  insert into atlas_planning.need_generation_release_snapshots
  select (pg_catalog.jsonb_populate_record(
    null::atlas_planning.need_generation_release_snapshots,
    pg_catalog.to_jsonb(template) || pg_catalog.jsonb_build_object(
      'need_generation_release_snapshot_id', v_release_snapshot_id,
      'need_generation_run_id', v_run_id,
      'need_generation_input_snapshot_id', v_input_snapshot_id,
      'released_by_actor_id', v_actor_id,
      'released_at', v_now,
      'generated_line_count', 236,
      'active_line_count', 236
    )
  )).*
  from atlas_planning.need_generation_release_snapshots template
  where template.need_generation_release_snapshot_id = 'b6550000-0000-0000-0000-000000000005';

  insert into atlas_planning.need_generation_release_snapshot_lines
  select (pg_catalog.jsonb_populate_record(
    null::atlas_planning.need_generation_release_snapshot_lines,
    pg_catalog.to_jsonb(template) || pg_catalog.jsonb_build_object(
      'need_generation_release_snapshot_line_id', md5(p_seed || ':release-line:' || line.source_row_reference)::uuid,
      'need_generation_release_snapshot_id', v_release_snapshot_id,
      'need_generation_run_id', v_run_id,
      'theoretical_need_line_id', md5(p_seed || ':theoretical-line:' || line.source_row_reference)::uuid
    )
  )).*
  from atlas_planning.pantry_need_lines line
  cross join atlas_planning.need_generation_release_snapshot_lines template
  where line.pantry_need_batch_id = v_pantry_id
    and template.need_generation_release_snapshot_line_id = 'b6550000-0000-0000-0000-000000000006';

  insert into atlas_planning.confirmed_need_batches
  select (pg_catalog.jsonb_populate_record(
    null::atlas_planning.confirmed_need_batches,
    pg_catalog.to_jsonb(template) || pg_catalog.jsonb_build_object(
      'confirmed_need_batch_id', v_batch_id,
      'period_start', p_service_date,
      'period_end', v_period_end,
      'batch_status', 'DRAFT_REVIEW',
      'version', 1,
      'created_by_actor_id', v_actor_id,
      'created_at', v_now,
      'updated_at', v_now,
      'origin_need_generation_run_id', v_run_id,
      'origin_need_generation_release_snapshot_id', v_release_snapshot_id,
      'current_need_generation_run_id', v_run_id,
      'current_need_generation_release_snapshot_id', v_release_snapshot_id,
      'current_confirmed_need_validation_attempt_id', null,
      'current_confirmed_need_approval_snapshot_id', null,
      'current_confirmed_need_release_id', null,
      'approved_by_actor_id', null,
      'approved_at', null,
      'released_by_actor_id', null,
      'released_at', null
    )
  )).*
  from atlas_planning.confirmed_need_batches template
  where template.confirmed_need_batch_id = 'b6500000-0000-0000-0000-000000000050';

  insert into atlas_planning.confirmed_need_lines
  select (pg_catalog.jsonb_populate_record(
    null::atlas_planning.confirmed_need_lines,
    pg_catalog.to_jsonb(template) || pg_catalog.jsonb_build_object(
      'confirmed_need_line_id', md5(p_seed || ':confirmed-line:' || line.source_row_reference)::uuid,
      'confirmed_need_batch_id', v_batch_id,
      'service_date', p_service_date,
      'customer_id', v_customer_id,
      'school_id', line.school_id,
      'delivery_location_id', line.delivery_location_id,
      'ingredient_id', line.ingredient_id,
      'current_confirmed_need_line_decision_id', null,
      'created_at', v_now
    )
  )).*
  from atlas_planning.pantry_need_lines line
  cross join atlas_planning.confirmed_need_lines template
  where line.pantry_need_batch_id = v_pantry_id
    and template.confirmed_need_line_id = 'b6560000-0000-0000-0000-000000000001';

  insert into atlas_planning.confirmed_need_line_revisions
  select (pg_catalog.jsonb_populate_record(
    null::atlas_planning.confirmed_need_line_revisions,
    pg_catalog.to_jsonb(template) || pg_catalog.jsonb_build_object(
      'confirmed_need_line_revision_id', md5(p_seed || ':confirmed-revision:' || line.source_row_reference)::uuid,
      'confirmed_need_line_id', md5(p_seed || ':confirmed-line:' || line.source_row_reference)::uuid,
      'ingredient_id', line.ingredient_id,
      'theoretical_quantity', line.requested_quantity,
      'confirmed_quantity', line.requested_quantity,
      'confirmed_need_batch_id', v_batch_id,
      'need_generation_run_id', v_run_id,
      'need_generation_release_snapshot_id', v_release_snapshot_id,
      'service_date', p_service_date,
      'customer_id', v_customer_id,
      'school_id', line.school_id,
      'delivery_location_id', line.delivery_location_id,
      'created_at', v_now
    )
  )).*
  from atlas_planning.pantry_need_lines line
  cross join atlas_planning.confirmed_need_line_revisions template
  where line.pantry_need_batch_id = v_pantry_id
    and template.confirmed_need_line_revision_id = 'b6560000-0000-0000-0000-000000000011';

  insert into atlas_planning.confirmed_need_line_revision_contributions
  select (pg_catalog.jsonb_populate_record(
    null::atlas_planning.confirmed_need_line_revision_contributions,
    pg_catalog.to_jsonb(template) || pg_catalog.jsonb_build_object(
      'confirmed_need_line_revision_contribution_id', md5(p_seed || ':confirmed-contribution:' || line.source_row_reference)::uuid,
      'confirmed_need_batch_id', v_batch_id,
      'confirmed_need_line_id', md5(p_seed || ':confirmed-line:' || line.source_row_reference)::uuid,
      'confirmed_need_line_revision_id', md5(p_seed || ':confirmed-revision:' || line.source_row_reference)::uuid,
      'need_generation_run_id', v_run_id,
      'need_generation_release_snapshot_id', v_release_snapshot_id,
      'need_generation_release_snapshot_line_id', md5(p_seed || ':release-line:' || line.source_row_reference)::uuid,
      'theoretical_need_line_id', md5(p_seed || ':theoretical-line:' || line.source_row_reference)::uuid,
      'service_date', p_service_date,
      'customer_id', v_customer_id,
      'school_id', line.school_id,
      'delivery_location_id', line.delivery_location_id,
      'ingredient_id', line.ingredient_id,
      'source_theoretical_quantity', line.requested_quantity,
      'controlled_contribution_quantity', line.requested_quantity,
      'created_at', v_now
    )
  )).*
  from atlas_planning.pantry_need_lines line
  cross join atlas_planning.confirmed_need_line_revision_contributions template
  where line.pantry_need_batch_id = v_pantry_id
    and template.confirmed_need_line_revision_contribution_id = 'b6560000-0000-0000-0000-000000000021';

  set constraints all immediate;

  if (select count(*) from atlas_planning.confirmed_need_lines
      where confirmed_need_batch_id = v_batch_id) <> 236
    or (select count(*) from atlas_planning.confirmed_need_line_revision_contributions
      where confirmed_need_batch_id = v_batch_id) <> 236
    or exists (
      select 1
      from atlas_planning.confirmed_need_lines line
      where line.confirmed_need_batch_id = v_batch_id
        and line.current_confirmed_need_line_decision_id is not null
    )
    or exists (
      select 1
      from atlas_procurement.school_catering_allocation_families family
      where family.service_date = p_service_date
    ) then
    raise exception 'Scale fixture did not create exactly 236 undecided lines with zero persisted allocations.';
  end if;

  if (select count(*) from atlas_admin.suppliers supplier
      where supplier.supplier_id in (
        select md5(v_master_seed || ':supplier:' || generated.supplier_number)::uuid
        from pg_catalog.generate_series(1, 12) generated(supplier_number)
      )
        and supplier.supplier_status = 'ACTIVE') <> 12
    or exists (
      select ingredient.ingredient_id
      from atlas_admin.ingredients ingredient
      where ingredient.ingredient_id in (
        select md5(v_master_seed || ':ingredient:' || generated.ingredient_number)::uuid
        from pg_catalog.generate_series(1, 59) generated(ingredient_number)
      )
      group by ingredient.ingredient_id
      having (
        select count(*)
        from atlas_admin.supplier_eligibilities eligibility
        join atlas_admin.suppliers supplier using (supplier_id)
        where eligibility.ingredient_id = ingredient.ingredient_id
          and eligibility.eligibility_status = 'ACTIVE'
          and eligibility.effective_from <= p_service_date
          and (eligibility.effective_to is null or eligibility.effective_to > p_service_date)
          and supplier.supplier_status = 'ACTIVE'
          and eligibility.priority = 1
      ) <> 1
    ) then
    raise exception 'Scale fixture requires 12 active Suppliers and one unique effective priority-1 Supplier per Ingredient.';
  end if;

  if exists (
    select 1
    from pg_catalog.pg_trigger catalog_trigger
    where catalog_trigger.tgrelid in (
      'atlas_planning.need_generation_runs'::regclass,
      'atlas_planning.theoretical_need_lines'::regclass,
      'atlas_planning.confirmed_need_batches'::regclass,
      'atlas_planning.confirmed_need_lines'::regclass,
      'atlas_planning.confirmed_need_line_revisions'::regclass,
      'atlas_planning.confirmed_need_line_revision_contributions'::regclass
    )
      and not catalog_trigger.tgisinternal
      and catalog_trigger.tgenabled = 'D'
  ) then
    raise exception 'Scale fixture found a disabled business integrity trigger.';
  end if;

  set constraints all deferred;
  return v_batch_id;
end;
$purchase_preparation_scale_fixture$;

create function pg_temp.scale_command(
  identity_label text,
  contract text,
  reason text,
  expected_version bigint,
  payload jsonb
) returns jsonb
language sql volatile
set search_path=''
as $$
  select pg_catalog.jsonb_build_object(
    'contract_version', contract,
    'command_id', md5('purchase-preparation-scale:' || identity_label || ':command')::uuid,
    'correlation_id', md5('purchase-preparation-scale:' || identity_label || ':correlation')::uuid,
    'idempotency_key', md5('purchase-preparation-scale:' || identity_label || ':idempotency')::uuid::text,
    'expected_version', expected_version,
    'requested_by_auth_subject', 'b6000000-0000-0000-0000-000000000101',
    'requested_at', pg_catalog.transaction_timestamp() - interval '1 second',
    'reason_code', reason,
    'reason_note', null,
    'payload', payload
  );
$$;
grant execute on function pg_temp.scale_command(text,text,text,bigint,jsonb) to authenticated;

create function pg_temp.scale_confirmed_need_save_command(
  identity_label text,
  p_batch_id uuid
) returns jsonb
language sql volatile
set search_path=''
as $$
  select pg_temp.scale_command(
    identity_label,
    'RMVP-05.v2',
    'CONFIRMED_NEED_SAVED',
    batch.version,
    pg_catalog.jsonb_build_object(
      'confirmed_need_batch_id', batch.confirmed_need_batch_id,
      'lines', (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'confirmed_need_line_id', line.confirmed_need_line_id,
            'expected_current_revision_id', revision.confirmed_need_line_revision_id,
            'expected_current_decision_id', line.current_confirmed_need_line_decision_id,
            'proposed_confirmed_quantity', revision.confirmed_quantity::numeric(20,6)::text,
            'reason_code', 'PROPOSAL_ACCEPTED',
            'reason_note', null
          ) order by line.confirmed_need_line_id
        )
        from atlas_planning.confirmed_need_lines line
        join atlas_planning.confirmed_need_line_revisions revision
          on revision.confirmed_need_line_id = line.confirmed_need_line_id
         and revision.is_current
        where line.confirmed_need_batch_id = batch.confirmed_need_batch_id
      )
    )
  )
  from atlas_planning.confirmed_need_batches batch
  where batch.confirmed_need_batch_id = p_batch_id;
$$;

-- Snapshot all downstream facts that preparation can touch. Exact JSON equality
-- catches partial versions, lineage rows, events, or audit evidence left behind.
create function pg_temp.scale_business_snapshot() returns jsonb
language sql stable
set search_path=''
as $$
  select pg_catalog.jsonb_build_object(
    'batches', (select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(r) order by pg_catalog.to_jsonb(r)::text) from atlas_planning.confirmed_need_batches r),
    'lines', (select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(r) order by pg_catalog.to_jsonb(r)::text) from atlas_planning.confirmed_need_lines r),
    'line_revisions', (select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(r) order by pg_catalog.to_jsonb(r)::text) from atlas_planning.confirmed_need_line_revisions r),
    'line_revision_contributions', (select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(r) order by pg_catalog.to_jsonb(r)::text) from atlas_planning.confirmed_need_line_revision_contributions r),
    'decisions', (select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(r) order by pg_catalog.to_jsonb(r)::text) from atlas_planning.confirmed_need_line_decisions r),
    'releases', (select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(r) order by pg_catalog.to_jsonb(r)::text) from atlas_planning.confirmed_need_releases r),
    'approvals', (select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(r) order by pg_catalog.to_jsonb(r)::text) from atlas_planning.confirmed_need_approval_snapshots r),
    'need_snapshot_lines', (select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(r) order by pg_catalog.to_jsonb(r)::text) from atlas_planning.confirmed_need_snapshot_lines r),
    'validation_attempts', (select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(r) order by pg_catalog.to_jsonb(r)::text) from atlas_planning.confirmed_need_validation_attempts r),
    'validation_lines', (select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(r) order by pg_catalog.to_jsonb(r)::text) from atlas_planning.confirmed_need_validation_lines r),
    'validation_issues', (select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(r) order by pg_catalog.to_jsonb(r)::text) from atlas_planning.confirmed_need_validation_issues r),
    'purchase_demand_references', (select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(r) order by pg_catalog.to_jsonb(r)::text) from atlas_planning.purchase_demand_references r),
    'handoff_batches', (select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(r) order by pg_catalog.to_jsonb(r)::text) from atlas_planning.purchase_handoff_batches r),
    'handoff_revisions', (select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(r) order by pg_catalog.to_jsonb(r)::text) from atlas_planning.purchase_handoff_revisions r),
    'handoff_lines', (select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(r) order by pg_catalog.to_jsonb(r)::text) from atlas_planning.purchase_handoff_lines r),
    'handoff_line_revisions', (select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(r) order by pg_catalog.to_jsonb(r)::text) from atlas_planning.purchase_handoff_line_revisions r),
    'allocation_families', (select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(r) order by pg_catalog.to_jsonb(r)::text) from atlas_procurement.school_catering_allocation_families r),
    'allocation_revisions', (select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(r) order by pg_catalog.to_jsonb(r)::text) from atlas_procurement.school_catering_allocation_family_revisions r),
    'allocation_contributions', (select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(r) order by pg_catalog.to_jsonb(r)::text) from atlas_procurement.school_catering_allocation_family_contributions r),
    'allocation_splits', (select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(r) order by pg_catalog.to_jsonb(r)::text) from atlas_procurement.school_catering_allocation_supplier_splits r),
    'purchase_orders', (select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(r) order by pg_catalog.to_jsonb(r)::text) from atlas_procurement.purchase_orders r),
    'purchase_order_revisions', (select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(r) order by pg_catalog.to_jsonb(r)::text) from atlas_procurement.purchase_order_revisions r),
    'purchase_order_lines', (select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(r) order by pg_catalog.to_jsonb(r)::text) from atlas_procurement.purchase_order_lines r),
    'purchase_order_line_revisions', (select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(r) order by pg_catalog.to_jsonb(r)::text) from atlas_procurement.purchase_order_line_revisions r),
    'domain_events', (select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(r) order by pg_catalog.to_jsonb(r)::text) from atlas_audit.domain_events r),
    'audit_events', (select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(r) order by pg_catalog.to_jsonb(r)::text) from atlas_audit.audit_events r)
  );
$$;
