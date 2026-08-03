-- GitHub-only disposable acceptance fixture for RMVP-05.
--
-- This fixture uses existing persistence and lifecycle rules to create one
-- deterministic two-line Confirmed Need review batch. It calls no RMVP-03B,
-- RMVP-04, or CMD-15 API, creates no production seed, and changes no trigger or
-- session-replication setting. All deferred guards are forced before it exits.

do $rmvp_05_browser_fixture$
declare
  v_actor_id constant uuid := 'b6000000-0000-0000-0000-000000000001';
  v_batch_id constant uuid := 'b6500000-0000-0000-0000-000000000050';
  v_contract_id uuid;
  v_contract_revision_id uuid;
  v_contract_version bigint;
  v_now timestamptz := transaction_timestamp();
begin
  if not exists (
    select 1
    from atlas_core.actors actor
    join atlas_core.actor_auth_subjects subject
      on subject.actor_id = actor.actor_id
    join atlas_core.actor_role_memberships membership
      on membership.actor_id = actor.actor_id
    where actor.actor_id = v_actor_id
      and actor.actor_status = 'ACTIVE'
      and subject.auth_subject_id = 'b6000000-0000-0000-0000-000000000101'
      and subject.subject_status = 'ACTIVE'
      and membership.role_id = 'b6000000-0000-0000-0000-000000000003'
      and membership.membership_status = 'ACTIVE'
      and membership.effective_from <= v_now
      and (membership.effective_to is null or membership.effective_to > v_now)
  ) then
    raise exception 'RMVP-05 fixture requires the deterministic active Planning actor.';
  end if;

  if (
    select count(*)
    from atlas_core.role_capabilities role_capability
    join atlas_core.capabilities capability
      on capability.capability_id = role_capability.capability_id
    where role_capability.role_id = 'b6000000-0000-0000-0000-000000000003'
      and capability.capability_code in (
        'confirmed_need_review.read',
        'confirmed_need_quantities.preview',
        'confirmed_need_quantities.confirm'
      )
      and capability.capability_status = 'ACTIVE'
  ) <> 3 or not exists (
    select 1
    from atlas_core.actor_scopes scope
    where scope.actor_id = v_actor_id
      and scope.scope_kind = 'GLOBAL'
      and scope.scope_status = 'ACTIVE'
      and scope.effective_from <= v_now
      and (scope.effective_to is null or scope.effective_to > v_now)
  ) then
    raise exception 'RMVP-05 fixture requires all three capabilities and active GLOBAL scope.';
  end if;

  if exists (
    select 1
    from atlas_planning.confirmed_need_batches
    where confirmed_need_batch_id = v_batch_id
  ) then
    raise exception 'RMVP-05 deterministic fixture batch already exists.';
  end if;

  insert into atlas_admin.customers (
    customer_id,
    customer_code,
    customer_name,
    customer_type
  ) values (
    'b6500000-0000-0000-0000-000000000001',
    'rmvp05-browser-customer',
    'RMVP-05 browser customer',
    'SCHOOL_CATERING'
  );

  insert into atlas_admin.delivery_locations (
    delivery_location_id,
    customer_id,
    location_code,
    location_name,
    address_text,
    timezone_name
  ) values (
    'b6500000-0000-0000-0000-000000000002',
    'b6500000-0000-0000-0000-000000000001',
    'rmvp05-browser-kitchen',
    'RMVP-05 browser kitchen',
    'Disposable fixture kitchen',
    'Asia/Ho_Chi_Minh'
  );

  insert into atlas_admin.school_types (
    school_type_id,
    school_type_code,
    school_type_name
  ) values (
    'b6500000-0000-0000-0000-000000000003',
    'rmvp05-browser-type',
    'RMVP-05 browser type'
  );

  insert into atlas_admin.schools (
    school_id,
    customer_id,
    school_code,
    school_name,
    school_type_id,
    default_delivery_location_id,
    display_order
  ) values (
    'b6500000-0000-0000-0000-000000000004',
    'b6500000-0000-0000-0000-000000000001',
    'rmvp05-browser-school',
    'RMVP-05 browser school',
    'b6500000-0000-0000-0000-000000000003',
    'b6500000-0000-0000-0000-000000000002',
    50
  );

  insert into atlas_admin.units (
    unit_id,
    unit_code,
    unit_name,
    dimension_code
  ) values (
    'b6500000-0000-0000-0000-000000000005',
    'rmvp05-browser-kg',
    'RMVP-05 browser kilogram',
    'mass'
  );

  insert into atlas_admin.ingredients (
    ingredient_id,
    ingredient_code,
    ingredient_name
  ) values
    (
      'b6500000-0000-0000-0000-000000000006',
      'rmvp05-browser-rice',
      'RMVP-05 browser rice'
    ),
    (
      'b6500000-0000-0000-0000-000000000007',
      'rmvp05-browser-beans',
      'RMVP-05 browser beans'
    );

  insert into atlas_planning.weekly_menus (
    weekly_menu_id,
    week_start,
    week_end,
    source_type,
    source_name,
    source_signature,
    row_count,
    imported_by_actor_id,
    weekly_menu_status,
    version,
    imported_at,
    created_at,
    updated_at
  ) values (
    'b6510000-0000-0000-0000-000000000001',
    date '2026-11-02',
    date '2026-11-08',
    'FIXTURE',
    'RMVP-05 empty browser menu',
    'rmvp05-browser-menu',
    0,
    v_actor_id,
    'DRAFT',
    1,
    v_now,
    v_now,
    v_now
  );

  update atlas_planning.weekly_menus
  set weekly_menu_status = 'VALIDATED'
  where weekly_menu_id = 'b6510000-0000-0000-0000-000000000001';

  insert into atlas_planning.weekly_menu_approval_snapshots (
    weekly_menu_approval_snapshot_id,
    weekly_menu_id,
    weekly_menu_version,
    approved_by_actor_id,
    approved_at
  ) values (
    'b6510000-0000-0000-0000-000000000002',
    'b6510000-0000-0000-0000-000000000001',
    1,
    v_actor_id,
    v_now
  );

  update atlas_planning.weekly_menus
  set weekly_menu_status = 'APPROVED',
      latest_approved_by_actor_id = v_actor_id,
      latest_approved_at = v_now,
      latest_approval_snapshot_id = 'b6510000-0000-0000-0000-000000000002'
  where weekly_menu_id = 'b6510000-0000-0000-0000-000000000001';

  insert into atlas_planning.attendance_batches (
    attendance_batch_id,
    period_start,
    period_end,
    source_type,
    source_name,
    source_signature,
    row_count,
    imported_by_actor_id,
    attendance_status,
    version,
    imported_at,
    created_at,
    updated_at
  ) values (
    'b6520000-0000-0000-0000-000000000001',
    date '2026-11-02',
    date '2026-11-08',
    'FIXTURE',
    'RMVP-05 empty browser attendance',
    'rmvp05-browser-attendance',
    0,
    v_actor_id,
    'DRAFT',
    1,
    v_now,
    v_now,
    v_now
  );

  update atlas_planning.attendance_batches
  set attendance_status = 'VALIDATED'
  where attendance_batch_id = 'b6520000-0000-0000-0000-000000000001';

  insert into atlas_planning.attendance_approval_snapshots (
    attendance_approval_snapshot_id,
    attendance_batch_id,
    attendance_version,
    approved_by_actor_id,
    approved_at
  ) values (
    'b6520000-0000-0000-0000-000000000002',
    'b6520000-0000-0000-0000-000000000001',
    1,
    v_actor_id,
    v_now
  );

  update atlas_planning.attendance_batches
  set attendance_status = 'APPROVED',
      latest_approved_by_actor_id = v_actor_id,
      latest_approved_at = v_now,
      latest_approval_snapshot_id = 'b6520000-0000-0000-0000-000000000002'
  where attendance_batch_id = 'b6520000-0000-0000-0000-000000000001';

  insert into atlas_planning.pantry_need_purposes (
    pantry_need_purpose_id,
    purpose_code,
    purpose_name_vi,
    purpose_description,
    note_rule,
    purpose_status,
    display_order
  ) values (
    'b6530000-0000-0000-0000-000000000001',
    'rmvp05_browser_supplement',
    'Bo sung RMVP-05',
    'Disposable focused browser fixture.',
    'OPTIONAL',
    'ACTIVE',
    50
  );

  insert into atlas_planning.pantry_need_batches (
    pantry_need_batch_id,
    week_start,
    pantry_need_batch_status,
    version,
    source_signature,
    no_additions_confirmed,
    requesting_actor_id,
    created_at,
    updated_at
  ) values (
    'b6530000-0000-0000-0000-000000000002',
    date '2026-11-02',
    'DRAFT',
    1,
    repeat('a', 64),
    false,
    v_actor_id,
    v_now,
    v_now
  );

  insert into atlas_planning.pantry_need_lines (
    pantry_need_line_id,
    pantry_need_batch_id,
    service_date,
    school_id,
    delivery_location_id,
    ingredient_id,
    unit_id,
    pantry_need_purpose_id,
    requested_quantity,
    note,
    source_request_reference,
    source_row_reference,
    updated_by_actor_id,
    created_at,
    updated_at
  ) values
    (
      'b6530000-0000-0000-0000-000000000004',
      'b6530000-0000-0000-0000-000000000002',
      date '2026-11-02',
      'b6500000-0000-0000-0000-000000000004',
      'b6500000-0000-0000-0000-000000000002',
      'b6500000-0000-0000-0000-000000000006',
      'b6500000-0000-0000-0000-000000000005',
      'b6530000-0000-0000-0000-000000000001',
      2.000000,
      'Rice supplement',
      'RMVP05-BROWSER',
      '1',
      v_actor_id,
      v_now,
      v_now
    ),
    (
      'b6530000-0000-0000-0000-000000000005',
      'b6530000-0000-0000-0000-000000000002',
      date '2026-11-02',
      'b6500000-0000-0000-0000-000000000004',
      'b6500000-0000-0000-0000-000000000002',
      'b6500000-0000-0000-0000-000000000007',
      'b6500000-0000-0000-0000-000000000005',
      'b6530000-0000-0000-0000-000000000001',
      3.000000,
      'Bean supplement',
      'RMVP05-BROWSER',
      '2',
      v_actor_id,
      v_now,
      v_now
    );

  update atlas_planning.pantry_need_batches
  set pantry_need_batch_status = 'VALIDATED',
      version = 2,
      updated_at = v_now
  where pantry_need_batch_id = 'b6530000-0000-0000-0000-000000000002';

  insert into atlas_planning.pantry_need_approval_snapshots (
    pantry_need_approval_snapshot_id,
    pantry_need_batch_id,
    approved_batch_version,
    approved_by_actor_id,
    approved_at,
    source_signature,
    no_additions_confirmed,
    line_count
  ) values (
    'b6530000-0000-0000-0000-000000000003',
    'b6530000-0000-0000-0000-000000000002',
    3,
    v_actor_id,
    v_now,
    repeat('a', 64),
    false,
    2
  );

  insert into atlas_planning.pantry_need_approval_snapshot_lines (
    pantry_need_approval_snapshot_id,
    pantry_need_line_id,
    service_date,
    school_id,
    school_code_snapshot,
    school_name_snapshot,
    delivery_location_id,
    delivery_location_code_snapshot,
    delivery_location_name_snapshot,
    delivery_location_address_snapshot,
    ingredient_id,
    ingredient_code_snapshot,
    ingredient_name_snapshot,
    unit_id,
    unit_code_snapshot,
    unit_name_snapshot,
    pantry_need_purpose_id,
    purpose_code_snapshot,
    purpose_name_snapshot,
    purpose_description_snapshot,
    purpose_note_rule_snapshot,
    requested_quantity,
    note,
    source_request_reference,
    source_row_reference
  ) values
    (
      'b6530000-0000-0000-0000-000000000003',
      'b6530000-0000-0000-0000-000000000004',
      date '2026-11-02',
      'b6500000-0000-0000-0000-000000000004',
      'rmvp05-browser-school',
      'RMVP-05 browser school',
      'b6500000-0000-0000-0000-000000000002',
      'rmvp05-browser-kitchen',
      'RMVP-05 browser kitchen',
      'Disposable fixture kitchen',
      'b6500000-0000-0000-0000-000000000006',
      'rmvp05-browser-rice',
      'RMVP-05 browser rice',
      'b6500000-0000-0000-0000-000000000005',
      'rmvp05-browser-kg',
      'RMVP-05 browser kilogram',
      'b6530000-0000-0000-0000-000000000001',
      'rmvp05_browser_supplement',
      'Bo sung RMVP-05',
      'Disposable focused browser fixture.',
      'OPTIONAL',
      2.000000,
      'Rice supplement',
      'RMVP05-BROWSER',
      '1'
    ),
    (
      'b6530000-0000-0000-0000-000000000003',
      'b6530000-0000-0000-0000-000000000005',
      date '2026-11-02',
      'b6500000-0000-0000-0000-000000000004',
      'rmvp05-browser-school',
      'RMVP-05 browser school',
      'b6500000-0000-0000-0000-000000000002',
      'rmvp05-browser-kitchen',
      'RMVP-05 browser kitchen',
      'Disposable fixture kitchen',
      'b6500000-0000-0000-0000-000000000007',
      'rmvp05-browser-beans',
      'RMVP-05 browser beans',
      'b6500000-0000-0000-0000-000000000005',
      'rmvp05-browser-kg',
      'RMVP-05 browser kilogram',
      'b6530000-0000-0000-0000-000000000001',
      'rmvp05_browser_supplement',
      'Bo sung RMVP-05',
      'Disposable focused browser fixture.',
      'OPTIONAL',
      3.000000,
      'Bean supplement',
      'RMVP05-BROWSER',
      '2'
    );

  update atlas_planning.pantry_need_batches
  set pantry_need_batch_status = 'APPROVED',
      version = 3,
      latest_approved_by_actor_id = v_actor_id,
      latest_approved_at = v_now,
      latest_approval_snapshot_id = 'b6530000-0000-0000-0000-000000000003',
      updated_at = v_now
  where pantry_need_batch_id = 'b6530000-0000-0000-0000-000000000002';

  select
    contract.need_generation_calculation_contract_id,
    contract.current_revision_id,
    contract.version
  into v_contract_id, v_contract_revision_id, v_contract_version
  from atlas_planning.need_generation_calculation_contracts contract
  where contract.contract_code = 'school_catering_proportional_per_basis';

  if not found then
    v_contract_id := 'b6540000-0000-0000-0000-000000000010';
    v_contract_revision_id := 'b6540000-0000-0000-0000-000000000011';
    v_contract_version := 1;

    insert into atlas_planning.need_generation_calculation_contracts (
      need_generation_calculation_contract_id,
      contract_code,
      current_revision_id,
      version,
      created_at,
      updated_at
    ) values (
      v_contract_id,
      'school_catering_proportional_per_basis',
      v_contract_revision_id,
      v_contract_version,
      v_now,
      v_now
    );

    insert into atlas_planning.need_generation_calculation_contract_revisions (
      need_generation_calculation_contract_revision_id,
      need_generation_calculation_contract_id,
      revision_number,
      formula_kind,
      quantity_precision,
      quantity_scale,
      factor_precision,
      factor_scale,
      final_coercion_mode,
      approved_by_actor_id,
      approved_at
    ) values (
      v_contract_revision_id,
      v_contract_id,
      v_contract_version,
      'STUDENT_TEACHER_PORTIONS_X_RECIPE_QTY_DIV_BASIS',
      20,
      6,
      24,
      12,
      'POSTGRES_NUMERIC_SCALE_HALF_AWAY_FROM_ZERO',
      v_actor_id,
      v_now
    );
  end if;

  insert into atlas_planning.planning_input_sets (
    planning_input_set_id,
    period_start,
    period_end,
    readiness_status,
    current_evaluation_id,
    created_at,
    updated_at
  ) values (
    'b6540000-0000-0000-0000-000000000020',
    date '2026-11-02',
    date '2026-11-02',
    'READY',
    'b6540000-0000-0000-0000-000000000021',
    v_now,
    v_now
  );

  insert into atlas_planning.planning_input_evaluations (
    planning_input_evaluation_id,
    planning_input_set_id,
    evaluation_version,
    evaluation_result,
    weekly_menu_id,
    weekly_menu_version,
    weekly_menu_approval_snapshot_id,
    attendance_batch_id,
    attendance_version,
    attendance_approval_snapshot_id,
    pantry_need_batch_id,
    pantry_need_batch_version,
    pantry_need_approval_snapshot_id,
    blocking_issue_count,
    warning_count,
    evaluated_by_actor_id,
    evaluated_at
  ) values (
    'b6540000-0000-0000-0000-000000000021',
    'b6540000-0000-0000-0000-000000000020',
    1,
    'READY',
    'b6510000-0000-0000-0000-000000000001',
    1,
    'b6510000-0000-0000-0000-000000000002',
    'b6520000-0000-0000-0000-000000000001',
    1,
    'b6520000-0000-0000-0000-000000000002',
    'b6530000-0000-0000-0000-000000000002',
    3,
    'b6530000-0000-0000-0000-000000000003',
    0,
    0,
    v_actor_id,
    v_now
  );

  update atlas_planning.planning_input_sets
  set readiness_status = 'NEED_GENERATION_REQUESTED'
  where planning_input_set_id = 'b6540000-0000-0000-0000-000000000020';

  insert into atlas_planning.need_generation_runs (
    need_generation_run_id,
    planning_input_set_id,
    planning_input_evaluation_id,
    evaluation_version,
    period_start,
    period_end,
    attempt_ordinal,
    predecessor_need_generation_run_id,
    input_snapshot_id,
    run_status,
    version,
    generated_line_count,
    blocking_issue_count,
    warning_count,
    generated_by_actor_id,
    generated_at,
    updated_at
  ) values (
    'b6550000-0000-0000-0000-000000000001',
    'b6540000-0000-0000-0000-000000000020',
    'b6540000-0000-0000-0000-000000000021',
    1,
    date '2026-11-02',
    date '2026-11-02',
    1,
    null,
    'b6550000-0000-0000-0000-000000000002',
    'GENERATED',
    1,
    2,
    0,
    0,
    v_actor_id,
    v_now,
    v_now
  );

  insert into atlas_planning.need_generation_input_snapshots (
    need_generation_input_snapshot_id,
    need_generation_run_id,
    planning_input_set_id,
    planning_input_evaluation_id,
    evaluation_version,
    weekly_menu_id,
    weekly_menu_version,
    weekly_menu_approval_snapshot_id,
    attendance_batch_id,
    attendance_version,
    attendance_approval_snapshot_id,
    need_generation_calculation_contract_id,
    need_generation_calculation_contract_revision_id,
    calculation_contract_revision_number,
    captured_at,
    pantry_need_batch_id,
    pantry_need_batch_version,
    pantry_need_approval_snapshot_id
  ) values (
    'b6550000-0000-0000-0000-000000000002',
    'b6550000-0000-0000-0000-000000000001',
    'b6540000-0000-0000-0000-000000000020',
    'b6540000-0000-0000-0000-000000000021',
    1,
    'b6510000-0000-0000-0000-000000000001',
    1,
    'b6510000-0000-0000-0000-000000000002',
    'b6520000-0000-0000-0000-000000000001',
    1,
    'b6520000-0000-0000-0000-000000000002',
    v_contract_id,
    v_contract_revision_id,
    v_contract_version,
    v_now,
    'b6530000-0000-0000-0000-000000000002',
    3,
    'b6530000-0000-0000-0000-000000000003'
  );

  insert into atlas_planning.theoretical_need_lines (
    theoretical_need_line_id,
    need_generation_run_id,
    need_generation_input_snapshot_id,
    need_generation_recipe_selection_id,
    need_generation_recipe_line_use_id,
    weekly_menu_approval_snapshot_line_id,
    weekly_menu_approval_snapshot_id,
    weekly_menu_id,
    weekly_menu_version,
    weekly_menu_line_id,
    attendance_approval_snapshot_line_id,
    attendance_approval_snapshot_id,
    attendance_batch_id,
    attendance_version,
    attendance_line_id,
    school_id,
    service_date,
    dish_id,
    recipe_id,
    recipe_version_id,
    recipe_line_id,
    recipe_line_revision_id,
    ingredient_id,
    unit_id,
    need_generation_calculation_contract_id,
    need_generation_calculation_contract_revision_id,
    calculation_contract_revision_number,
    predecessor_need_generation_run_id,
    predecessor_theoretical_need_line_id,
    line_disposition,
    theoretical_quantity,
    created_at,
    contribution_family,
    delivery_location_id,
    pantry_need_batch_id,
    pantry_need_batch_version,
    pantry_need_approval_snapshot_id,
    pantry_need_line_id,
    pantry_active_snapshot_member_line_id
  ) values
    (
      'b6550000-0000-0000-0000-000000000003',
      'b6550000-0000-0000-0000-000000000001',
      'b6550000-0000-0000-0000-000000000002',
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      'b6500000-0000-0000-0000-000000000004',
      date '2026-11-02',
      null,
      null,
      null,
      null,
      null,
      'b6500000-0000-0000-0000-000000000006',
      'b6500000-0000-0000-0000-000000000005',
      null,
      null,
      null,
      null,
      null,
      'ACTIVE',
      2.000000,
      v_now,
      'PANTRY_DIRECT',
      'b6500000-0000-0000-0000-000000000002',
      'b6530000-0000-0000-0000-000000000002',
      3,
      'b6530000-0000-0000-0000-000000000003',
      'b6530000-0000-0000-0000-000000000004',
      'b6530000-0000-0000-0000-000000000004'
    ),
    (
      'b6550000-0000-0000-0000-000000000004',
      'b6550000-0000-0000-0000-000000000001',
      'b6550000-0000-0000-0000-000000000002',
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      'b6500000-0000-0000-0000-000000000004',
      date '2026-11-02',
      null,
      null,
      null,
      null,
      null,
      'b6500000-0000-0000-0000-000000000007',
      'b6500000-0000-0000-0000-000000000005',
      null,
      null,
      null,
      null,
      null,
      'ACTIVE',
      3.000000,
      v_now,
      'PANTRY_DIRECT',
      'b6500000-0000-0000-0000-000000000002',
      'b6530000-0000-0000-0000-000000000002',
      3,
      'b6530000-0000-0000-0000-000000000003',
      'b6530000-0000-0000-0000-000000000005',
      'b6530000-0000-0000-0000-000000000005'
    );

  update atlas_planning.need_generation_runs
  set run_status = 'VALIDATED',
      version = 2,
      validated_by_actor_id = v_actor_id,
      validated_at = v_now,
      updated_at = v_now
  where need_generation_run_id = 'b6550000-0000-0000-0000-000000000001';

  update atlas_planning.need_generation_runs
  set run_status = 'RELEASED_FOR_CONFIRMATION',
      version = 3,
      released_by_actor_id = v_actor_id,
      released_at = v_now,
      updated_at = v_now
  where need_generation_run_id = 'b6550000-0000-0000-0000-000000000001';

  insert into atlas_planning.need_generation_release_snapshots (
    need_generation_release_snapshot_id,
    need_generation_run_id,
    released_run_version,
    need_generation_input_snapshot_id,
    released_by_actor_id,
    released_at,
    generated_line_count,
    active_line_count,
    removed_line_count,
    blocking_issue_count,
    warning_count
  ) values (
    'b6550000-0000-0000-0000-000000000005',
    'b6550000-0000-0000-0000-000000000001',
    3,
    'b6550000-0000-0000-0000-000000000002',
    v_actor_id,
    v_now,
    2,
    2,
    0,
    0,
    0
  );

  insert into atlas_planning.need_generation_release_snapshot_lines (
    need_generation_release_snapshot_line_id,
    need_generation_release_snapshot_id,
    need_generation_run_id,
    released_run_version,
    theoretical_need_line_id
  ) values
    (
      'b6550000-0000-0000-0000-000000000006',
      'b6550000-0000-0000-0000-000000000005',
      'b6550000-0000-0000-0000-000000000001',
      3,
      'b6550000-0000-0000-0000-000000000003'
    ),
    (
      'b6550000-0000-0000-0000-000000000007',
      'b6550000-0000-0000-0000-000000000005',
      'b6550000-0000-0000-0000-000000000001',
      3,
      'b6550000-0000-0000-0000-000000000004'
    );

  insert into atlas_planning.confirmed_need_batches (
    confirmed_need_batch_id,
    wholesale_order_id,
    period_start,
    period_end,
    batch_status,
    version,
    created_by_actor_id,
    created_at,
    updated_at,
    source_kind,
    origin_need_generation_run_id,
    origin_need_generation_run_version,
    origin_need_generation_release_snapshot_id,
    current_need_generation_run_id,
    current_need_generation_run_version,
    current_need_generation_release_snapshot_id
  ) values (
    v_batch_id,
    null,
    date '2026-11-02',
    date '2026-11-02',
    'DRAFT_REVIEW',
    1,
    v_actor_id,
    v_now,
    v_now,
    'NEED_GENERATION',
    'b6550000-0000-0000-0000-000000000001',
    3,
    'b6550000-0000-0000-0000-000000000005',
    'b6550000-0000-0000-0000-000000000001',
    3,
    'b6550000-0000-0000-0000-000000000005'
  );

  insert into atlas_planning.confirmed_need_lines (
    confirmed_need_line_id,
    confirmed_need_batch_id,
    wholesale_order_line_id,
    source_kind,
    service_date,
    customer_id,
    school_id,
    delivery_location_id,
    ingredient_id,
    controlled_unit_id,
    created_at
  ) values
    (
      'b6560000-0000-0000-0000-000000000001',
      v_batch_id,
      null,
      'NEED_GENERATION',
      date '2026-11-02',
      'b6500000-0000-0000-0000-000000000001',
      'b6500000-0000-0000-0000-000000000004',
      'b6500000-0000-0000-0000-000000000002',
      'b6500000-0000-0000-0000-000000000006',
      'b6500000-0000-0000-0000-000000000005',
      v_now
    ),
    (
      'b6560000-0000-0000-0000-000000000002',
      v_batch_id,
      null,
      'NEED_GENERATION',
      date '2026-11-02',
      'b6500000-0000-0000-0000-000000000001',
      'b6500000-0000-0000-0000-000000000004',
      'b6500000-0000-0000-0000-000000000002',
      'b6500000-0000-0000-0000-000000000007',
      'b6500000-0000-0000-0000-000000000005',
      v_now
    );

  insert into atlas_planning.confirmed_need_line_revisions (
    confirmed_need_line_revision_id,
    confirmed_need_line_id,
    revision_number,
    wholesale_order_line_revision_id,
    ingredient_id,
    theoretical_quantity,
    confirmed_quantity,
    unit_id,
    revision_status,
    is_current,
    predecessor_revision_id,
    command_id,
    created_by_actor_id,
    created_at,
    source_kind,
    confirmed_need_batch_id,
    need_generation_run_id,
    need_generation_run_version,
    need_generation_release_snapshot_id,
    service_date,
    customer_id,
    school_id,
    delivery_location_id
  ) values
    (
      'b6560000-0000-0000-0000-000000000011',
      'b6560000-0000-0000-0000-000000000001',
      1,
      null,
      'b6500000-0000-0000-0000-000000000006',
      2.000000,
      2.000000,
      'b6500000-0000-0000-0000-000000000005',
      'DRAFT',
      true,
      null,
      null,
      v_actor_id,
      v_now,
      'NEED_GENERATION',
      v_batch_id,
      'b6550000-0000-0000-0000-000000000001',
      3,
      'b6550000-0000-0000-0000-000000000005',
      date '2026-11-02',
      'b6500000-0000-0000-0000-000000000001',
      'b6500000-0000-0000-0000-000000000004',
      'b6500000-0000-0000-0000-000000000002'
    ),
    (
      'b6560000-0000-0000-0000-000000000012',
      'b6560000-0000-0000-0000-000000000002',
      1,
      null,
      'b6500000-0000-0000-0000-000000000007',
      3.000000,
      3.000000,
      'b6500000-0000-0000-0000-000000000005',
      'DRAFT',
      true,
      null,
      null,
      v_actor_id,
      v_now,
      'NEED_GENERATION',
      v_batch_id,
      'b6550000-0000-0000-0000-000000000001',
      3,
      'b6550000-0000-0000-0000-000000000005',
      date '2026-11-02',
      'b6500000-0000-0000-0000-000000000001',
      'b6500000-0000-0000-0000-000000000004',
      'b6500000-0000-0000-0000-000000000002'
    );

  insert into atlas_planning.confirmed_need_line_revision_contributions (
    confirmed_need_line_revision_contribution_id,
    confirmed_need_batch_id,
    confirmed_need_line_id,
    confirmed_need_line_revision_id,
    need_generation_run_id,
    need_generation_run_version,
    need_generation_release_snapshot_id,
    need_generation_release_snapshot_line_id,
    theoretical_need_line_id,
    service_date,
    customer_id,
    school_id,
    delivery_location_id,
    ingredient_id,
    source_unit_id,
    controlled_unit_id,
    source_theoretical_quantity,
    controlled_contribution_quantity,
    created_at
  ) values
    (
      'b6560000-0000-0000-0000-000000000021',
      v_batch_id,
      'b6560000-0000-0000-0000-000000000001',
      'b6560000-0000-0000-0000-000000000011',
      'b6550000-0000-0000-0000-000000000001',
      3,
      'b6550000-0000-0000-0000-000000000005',
      'b6550000-0000-0000-0000-000000000006',
      'b6550000-0000-0000-0000-000000000003',
      date '2026-11-02',
      'b6500000-0000-0000-0000-000000000001',
      'b6500000-0000-0000-0000-000000000004',
      'b6500000-0000-0000-0000-000000000002',
      'b6500000-0000-0000-0000-000000000006',
      'b6500000-0000-0000-0000-000000000005',
      'b6500000-0000-0000-0000-000000000005',
      2.000000,
      2.000000,
      v_now
    ),
    (
      'b6560000-0000-0000-0000-000000000022',
      v_batch_id,
      'b6560000-0000-0000-0000-000000000002',
      'b6560000-0000-0000-0000-000000000012',
      'b6550000-0000-0000-0000-000000000001',
      3,
      'b6550000-0000-0000-0000-000000000005',
      'b6550000-0000-0000-0000-000000000007',
      'b6550000-0000-0000-0000-000000000004',
      date '2026-11-02',
      'b6500000-0000-0000-0000-000000000001',
      'b6500000-0000-0000-0000-000000000004',
      'b6500000-0000-0000-0000-000000000002',
      'b6500000-0000-0000-0000-000000000007',
      'b6500000-0000-0000-0000-000000000005',
      'b6500000-0000-0000-0000-000000000005',
      3.000000,
      3.000000,
      v_now
    );

  insert into atlas_planning.planning_quantity_policies (
    planning_quantity_policy_id,
    unit_id,
    created_by_actor_id
  )
  select
    md5('rmvp05-browser-policy:' || source.unit_id::text)::uuid,
    source.unit_id,
    v_actor_id
  from (
    select distinct line.controlled_unit_id as unit_id
    from atlas_planning.confirmed_need_batches batch
    join atlas_planning.confirmed_need_lines line
      on line.confirmed_need_batch_id = batch.confirmed_need_batch_id
    where batch.source_kind = 'NEED_GENERATION'
      and batch.batch_status = 'DRAFT_REVIEW'
  ) source
  on conflict (unit_id) do nothing;

  insert into atlas_planning.planning_quantity_policy_revisions (
    planning_quantity_policy_revision_id,
    planning_quantity_policy_id,
    unit_id,
    revision_number,
    predecessor_policy_revision_id,
    planning_step,
    effective_from,
    policy_revision_status,
    created_by_actor_id,
    created_at,
    approved_by_actor_id,
    approved_at,
    activated_by_actor_id,
    activated_at
  )
  select
    md5('rmvp05-browser-policy-revision:' || policy.unit_id::text)::uuid,
    policy.planning_quantity_policy_id,
    policy.unit_id,
    1,
    null,
    0.000001,
    date '2000-01-01',
    'DRAFT',
    v_actor_id,
    v_now,
    null,
    null,
    null,
    null
  from atlas_planning.planning_quantity_policies policy
  where exists (
    select 1
    from atlas_planning.confirmed_need_lines line
    join atlas_planning.confirmed_need_batches batch
      on batch.confirmed_need_batch_id = line.confirmed_need_batch_id
    where line.controlled_unit_id = policy.unit_id
      and batch.source_kind = 'NEED_GENERATION'
      and batch.batch_status = 'DRAFT_REVIEW'
  )
  and not exists (
    select 1
    from atlas_planning.planning_quantity_policy_revisions revision
    where revision.planning_quantity_policy_id = policy.planning_quantity_policy_id
  );

  update atlas_planning.planning_quantity_policy_revisions revision
  set policy_revision_status = 'ACTIVE',
      approved_by_actor_id = v_actor_id,
      approved_at = v_now,
      activated_by_actor_id = v_actor_id,
      activated_at = v_now
  where revision.policy_revision_status = 'DRAFT'
    and revision.revision_number = 1
    and revision.planning_step = 0.000001
    and revision.effective_from = date '2000-01-01'
    and revision.created_by_actor_id = v_actor_id
    and exists (
      select 1
      from atlas_planning.confirmed_need_lines line
      join atlas_planning.confirmed_need_batches batch
        on batch.confirmed_need_batch_id = line.confirmed_need_batch_id
      where line.controlled_unit_id = revision.unit_id
        and batch.source_kind = 'NEED_GENERATION'
        and batch.batch_status = 'DRAFT_REVIEW'
    );

  set constraints all immediate;

  if not exists (
    select 1
    from atlas_planning.confirmed_need_batches batch
    join atlas_planning.need_generation_release_snapshots release_snapshot
      on release_snapshot.need_generation_release_snapshot_id =
        batch.current_need_generation_release_snapshot_id
     and release_snapshot.need_generation_run_id =
       batch.current_need_generation_run_id
     and release_snapshot.released_run_version =
       batch.current_need_generation_run_version
    join atlas_planning.need_generation_runs run
      on run.need_generation_run_id = release_snapshot.need_generation_run_id
    where batch.confirmed_need_batch_id = v_batch_id
      and batch.batch_status = 'DRAFT_REVIEW'
      and batch.version = 1
      and batch.source_kind = 'NEED_GENERATION'
      and run.run_status = 'RELEASED_FOR_CONFIRMATION'
      and run.version = 3
  ) then
    raise exception 'RMVP-05 fixture did not preserve its exact released source binding.';
  end if;

  if (
    select count(*)
    from atlas_planning.confirmed_need_lines line
    join atlas_planning.confirmed_need_line_revisions revision
      on revision.confirmed_need_line_id = line.confirmed_need_line_id
     and revision.confirmed_need_batch_id = line.confirmed_need_batch_id
     and revision.is_current
    where line.confirmed_need_batch_id = v_batch_id
      and line.current_confirmed_need_line_decision_id is null
  ) <> 2 or (
    select count(*)
    from atlas_planning.confirmed_need_line_revision_contributions contribution
    where contribution.confirmed_need_batch_id = v_batch_id
  ) <> 2 or exists (
    select 1
    from atlas_planning.confirmed_need_line_revisions revision
    where revision.confirmed_need_batch_id = v_batch_id
      and revision.is_current
      and revision.theoretical_quantity <> (
        select sum(contribution.controlled_contribution_quantity)
        from atlas_planning.confirmed_need_line_revision_contributions contribution
        where contribution.confirmed_need_line_revision_id =
          revision.confirmed_need_line_revision_id
      )
  ) or exists (
    select 1
    from atlas_planning.confirmed_need_line_decisions decision
    where decision.confirmed_need_batch_id = v_batch_id
  ) then
    raise exception 'RMVP-05 fixture requires exactly two current contributed lines and no decisions.';
  end if;

  if exists (
    select 1
    from atlas_planning.confirmed_need_lines line
    where line.confirmed_need_batch_id = v_batch_id
      and (
        select count(*)
        from atlas_planning.planning_quantity_policy_revisions revision
        where revision.unit_id = line.controlled_unit_id
          and revision.policy_revision_status = 'ACTIVE'
          and revision.effective_from <= line.service_date
          and revision.planning_step = 0.000001
      ) <> 1
  ) then
    raise exception 'RMVP-05 fixture requires one exact active Unit policy per line.';
  end if;

  if exists (
    select 1
    from pg_catalog.pg_trigger catalog_trigger
    where catalog_trigger.tgrelid in (
      'atlas_planning.confirmed_need_batches'::regclass,
      'atlas_planning.confirmed_need_lines'::regclass,
      'atlas_planning.confirmed_need_line_revisions'::regclass,
      'atlas_planning.confirmed_need_line_revision_contributions'::regclass,
      'atlas_planning.confirmed_need_line_decisions'::regclass,
      'atlas_planning.planning_quantity_policies'::regclass,
      'atlas_planning.planning_quantity_policy_revisions'::regclass
    )
      and not catalog_trigger.tgisinternal
      and catalog_trigger.tgenabled = 'D'
  ) then
    raise exception 'RMVP-05 fixture found a disabled business integrity trigger.';
  end if;
end;
$rmvp_05_browser_fixture$;
