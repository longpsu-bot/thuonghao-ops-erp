-- PA-06E-H0A5b: private Need Generation persistence and typed lineage.
--
-- This additive migration creates persistence and invariant enforcement only.
-- It adds no command, RPC, API read, role, capability, policy, seed, legacy
-- write, hosted action, Confirmed Need, Procurement, or application surface.

set role atlas_owner;

create table atlas_planning.need_generation_calculation_contracts (
  need_generation_calculation_contract_id uuid not null default gen_random_uuid(),
  contract_code text not null,
  current_revision_id uuid not null,
  version bigint not null,
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp(),
  constraint need_generation_calculation_contracts_pkey primary key (
    need_generation_calculation_contract_id
  ),
  constraint need_generation_calculation_contracts_code_key unique (contract_code),
  constraint need_generation_calculation_contracts_id_version_key unique (
    need_generation_calculation_contract_id,
    version
  ),
  constraint need_generation_calculation_contracts_code_check check (
    contract_code = 'school_catering_proportional_per_basis'
  ),
  constraint need_generation_calculation_contracts_version_check check (version > 0),
  constraint need_generation_calculation_contracts_timestamps_check check (
    updated_at >= created_at
  )
);

create table atlas_planning.need_generation_calculation_contract_revisions (
  need_generation_calculation_contract_revision_id uuid not null default gen_random_uuid(),
  need_generation_calculation_contract_id uuid not null,
  revision_number bigint not null,
  predecessor_revision_id uuid,
  formula_kind text not null,
  quantity_precision integer not null,
  quantity_scale integer not null,
  factor_precision integer not null,
  factor_scale integer not null,
  final_coercion_mode text not null,
  approved_by_actor_id uuid not null,
  approved_at timestamptz not null,
  constraint need_generation_contract_revisions_pkey primary key (
    need_generation_calculation_contract_revision_id
  ),
  constraint need_generation_contract_revisions_id_owner_key unique (
    need_generation_calculation_contract_revision_id,
    need_generation_calculation_contract_id
  ),
  constraint need_generation_contract_revisions_id_full_key unique (
    need_generation_calculation_contract_revision_id,
    need_generation_calculation_contract_id,
    revision_number
  ),
  constraint need_generation_contract_revisions_owner_number_key unique (
    need_generation_calculation_contract_id,
    revision_number
  ),
  constraint need_generation_contract_revisions_contract_fkey foreign key (
    need_generation_calculation_contract_id
  ) references atlas_planning.need_generation_calculation_contracts (
    need_generation_calculation_contract_id
  ) on delete restrict deferrable initially deferred,
  constraint need_generation_contract_revisions_predecessor_fkey foreign key (
    predecessor_revision_id,
    need_generation_calculation_contract_id
  ) references atlas_planning.need_generation_calculation_contract_revisions (
    need_generation_calculation_contract_revision_id,
    need_generation_calculation_contract_id
  ) on delete restrict,
  constraint need_generation_contract_revisions_actor_fkey foreign key (
    approved_by_actor_id
  ) references atlas_core.actors (actor_id) on delete restrict,
  constraint need_generation_contract_revisions_number_check check (
    revision_number > 0
  ),
  constraint need_generation_contract_revisions_predecessor_check check (
    predecessor_revision_id is null
    or predecessor_revision_id <> need_generation_calculation_contract_revision_id
  ),
  constraint need_generation_contract_revisions_formula_check check (
    formula_kind = 'STUDENT_TEACHER_PORTIONS_X_RECIPE_QTY_DIV_BASIS'
  ),
  constraint need_generation_contract_revisions_quantity_precision_check check (
    quantity_precision = 20
  ),
  constraint need_generation_contract_revisions_quantity_scale_check check (
    quantity_scale = 6
  ),
  constraint need_generation_contract_revisions_factor_precision_check check (
    factor_precision = 24
  ),
  constraint need_generation_contract_revisions_factor_scale_check check (
    factor_scale = 12
  ),
  constraint need_generation_contract_revisions_coercion_check check (
    final_coercion_mode = 'POSTGRES_NUMERIC_SCALE_HALF_AWAY_FROM_ZERO'
  )
);

alter table atlas_planning.need_generation_calculation_contracts
  add constraint need_generation_contracts_current_revision_fkey foreign key (
    current_revision_id,
    need_generation_calculation_contract_id,
    version
  ) references atlas_planning.need_generation_calculation_contract_revisions (
    need_generation_calculation_contract_revision_id,
    need_generation_calculation_contract_id,
    revision_number
  ) on delete restrict deferrable initially deferred;

create unique index need_generation_contract_revision_successor_key
  on atlas_planning.need_generation_calculation_contract_revisions (
    predecessor_revision_id
  ) where predecessor_revision_id is not null;
create index need_generation_contract_revision_owner_idx
  on atlas_planning.need_generation_calculation_contract_revisions (
    need_generation_calculation_contract_id
  );
create index need_generation_contract_revision_predecessor_idx
  on atlas_planning.need_generation_calculation_contract_revisions (
    predecessor_revision_id,
    need_generation_calculation_contract_id
  ) where predecessor_revision_id is not null;
create index need_generation_contract_revision_actor_idx
  on atlas_planning.need_generation_calculation_contract_revisions (
    approved_by_actor_id
  );
create index need_generation_contract_current_revision_idx
  on atlas_planning.need_generation_calculation_contracts (
    current_revision_id,
    need_generation_calculation_contract_id,
    version
  );

create table atlas_planning.need_generation_runs (
  need_generation_run_id uuid not null default gen_random_uuid(),
  planning_input_set_id uuid not null,
  planning_input_evaluation_id uuid not null,
  evaluation_version bigint not null,
  period_start date not null,
  period_end date not null,
  attempt_ordinal bigint not null,
  predecessor_need_generation_run_id uuid,
  input_snapshot_id uuid not null,
  run_status text not null,
  version bigint not null,
  generated_line_count integer not null,
  blocking_issue_count integer not null,
  warning_count integer not null,
  generated_by_actor_id uuid not null,
  generated_at timestamptz not null,
  validated_by_actor_id uuid,
  validated_at timestamptz,
  released_by_actor_id uuid,
  released_at timestamptz,
  invalidated_by_actor_id uuid,
  invalidated_at timestamptz,
  updated_at timestamptz not null,
  constraint need_generation_runs_pkey primary key (need_generation_run_id),
  constraint need_generation_runs_id_input_set_key unique (
    need_generation_run_id,
    planning_input_set_id
  ),
  constraint need_generation_runs_id_snapshot_key unique (
    need_generation_run_id,
    input_snapshot_id
  ),
  constraint need_generation_runs_attempt_key unique (
    planning_input_set_id,
    attempt_ordinal
  ),
  constraint need_generation_runs_evaluation_fkey foreign key (
    planning_input_evaluation_id,
    planning_input_set_id,
    evaluation_version
  ) references atlas_planning.planning_input_evaluations (
    planning_input_evaluation_id,
    planning_input_set_id,
    evaluation_version
  ) on delete restrict,
  constraint need_generation_runs_predecessor_fkey foreign key (
    predecessor_need_generation_run_id,
    planning_input_set_id
  ) references atlas_planning.need_generation_runs (
    need_generation_run_id,
    planning_input_set_id
  ) on delete restrict,
  constraint need_generation_runs_generated_actor_fkey foreign key (
    generated_by_actor_id
  ) references atlas_core.actors (actor_id) on delete restrict,
  constraint need_generation_runs_validated_actor_fkey foreign key (
    validated_by_actor_id
  ) references atlas_core.actors (actor_id) on delete restrict,
  constraint need_generation_runs_released_actor_fkey foreign key (
    released_by_actor_id
  ) references atlas_core.actors (actor_id) on delete restrict,
  constraint need_generation_runs_invalidated_actor_fkey foreign key (
    invalidated_by_actor_id
  ) references atlas_core.actors (actor_id) on delete restrict,
  constraint need_generation_runs_period_check check (period_end >= period_start),
  constraint need_generation_runs_evaluation_version_check check (
    evaluation_version > 0
  ),
  constraint need_generation_runs_attempt_ordinal_check check (attempt_ordinal > 0),
  constraint need_generation_runs_predecessor_check check (
    predecessor_need_generation_run_id is null
    or predecessor_need_generation_run_id <> need_generation_run_id
  ),
  constraint need_generation_runs_status_check check (
    run_status in (
      'GENERATED',
      'VALIDATED',
      'RELEASED_FOR_CONFIRMATION',
      'INVALIDATED'
    )
  ),
  constraint need_generation_runs_version_check check (version > 0),
  constraint need_generation_runs_line_count_check check (generated_line_count >= 0),
  constraint need_generation_runs_blocker_count_check check (blocking_issue_count >= 0),
  constraint need_generation_runs_warning_count_check check (warning_count >= 0),
  constraint need_generation_runs_validation_evidence_check check (
    (validated_by_actor_id is null and validated_at is null)
    or (validated_by_actor_id is not null and validated_at is not null)
  ),
  constraint need_generation_runs_release_evidence_check check (
    (released_by_actor_id is null and released_at is null)
    or (released_by_actor_id is not null and released_at is not null)
  ),
  constraint need_generation_runs_invalidation_evidence_check check (
    (invalidated_by_actor_id is null and invalidated_at is null)
    or (invalidated_by_actor_id is not null and invalidated_at is not null)
  ),
  constraint need_generation_runs_status_evidence_check check (
    (
      run_status = 'GENERATED'
      and validated_at is null
      and released_at is null
      and invalidated_at is null
    ) or (
      run_status = 'VALIDATED'
      and validated_at is not null
      and released_at is null
      and invalidated_at is null
    ) or (
      run_status = 'RELEASED_FOR_CONFIRMATION'
      and validated_at is not null
      and released_at is not null
      and invalidated_at is null
    ) or (
      run_status = 'INVALIDATED'
      and invalidated_at is not null
    )
  ),
  constraint need_generation_runs_timestamp_order_check check (
    updated_at >= generated_at
    and (validated_at is null or validated_at >= generated_at)
    and (released_at is null or released_at >= validated_at)
    and (invalidated_at is null or invalidated_at >= generated_at)
  )
);

create unique index need_generation_runs_predecessor_successor_key
  on atlas_planning.need_generation_runs (predecessor_need_generation_run_id)
  where predecessor_need_generation_run_id is not null;
create index need_generation_runs_evaluation_idx
  on atlas_planning.need_generation_runs (
    planning_input_evaluation_id,
    planning_input_set_id,
    evaluation_version
  );
create index need_generation_runs_predecessor_idx
  on atlas_planning.need_generation_runs (
    predecessor_need_generation_run_id,
    planning_input_set_id
  ) where predecessor_need_generation_run_id is not null;
create index need_generation_runs_input_snapshot_idx
  on atlas_planning.need_generation_runs (
    input_snapshot_id,
    need_generation_run_id
  );
create index need_generation_runs_generated_actor_idx
  on atlas_planning.need_generation_runs (generated_by_actor_id);
create index need_generation_runs_validated_actor_idx
  on atlas_planning.need_generation_runs (validated_by_actor_id)
  where validated_by_actor_id is not null;
create index need_generation_runs_released_actor_idx
  on atlas_planning.need_generation_runs (released_by_actor_id)
  where released_by_actor_id is not null;
create index need_generation_runs_invalidated_actor_idx
  on atlas_planning.need_generation_runs (invalidated_by_actor_id)
  where invalidated_by_actor_id is not null;

create table atlas_planning.need_generation_input_snapshots (
  need_generation_input_snapshot_id uuid not null default gen_random_uuid(),
  need_generation_run_id uuid not null,
  planning_input_set_id uuid not null,
  planning_input_evaluation_id uuid not null,
  evaluation_version bigint not null,
  weekly_menu_id uuid not null,
  weekly_menu_version bigint not null,
  weekly_menu_approval_snapshot_id uuid not null,
  attendance_batch_id uuid not null,
  attendance_version bigint not null,
  attendance_approval_snapshot_id uuid not null,
  need_generation_calculation_contract_id uuid not null,
  need_generation_calculation_contract_revision_id uuid not null,
  calculation_contract_revision_number bigint not null,
  captured_at timestamptz not null,
  constraint need_generation_input_snapshots_pkey primary key (
    need_generation_input_snapshot_id
  ),
  constraint need_generation_input_snapshots_run_key unique (
    need_generation_run_id
  ),
  constraint need_generation_input_snapshots_id_run_key unique (
    need_generation_input_snapshot_id,
    need_generation_run_id
  ),
  constraint need_generation_input_snapshots_run_fkey foreign key (
    need_generation_run_id,
    need_generation_input_snapshot_id
  ) references atlas_planning.need_generation_runs (
    need_generation_run_id,
    input_snapshot_id
  ) on delete restrict deferrable initially deferred,
  constraint need_generation_input_snapshots_evaluation_fkey foreign key (
    planning_input_evaluation_id,
    planning_input_set_id,
    evaluation_version
  ) references atlas_planning.planning_input_evaluations (
    planning_input_evaluation_id,
    planning_input_set_id,
    evaluation_version
  ) on delete restrict,
  constraint need_generation_input_snapshots_menu_fkey foreign key (
    weekly_menu_approval_snapshot_id,
    weekly_menu_id,
    weekly_menu_version
  ) references atlas_planning.weekly_menu_approval_snapshots (
    weekly_menu_approval_snapshot_id,
    weekly_menu_id,
    weekly_menu_version
  ) on delete restrict,
  constraint need_generation_input_snapshots_attendance_fkey foreign key (
    attendance_approval_snapshot_id,
    attendance_batch_id,
    attendance_version
  ) references atlas_planning.attendance_approval_snapshots (
    attendance_approval_snapshot_id,
    attendance_batch_id,
    attendance_version
  ) on delete restrict,
  constraint need_generation_input_snapshots_contract_revision_fkey foreign key (
    need_generation_calculation_contract_revision_id,
    need_generation_calculation_contract_id,
    calculation_contract_revision_number
  ) references atlas_planning.need_generation_calculation_contract_revisions (
    need_generation_calculation_contract_revision_id,
    need_generation_calculation_contract_id,
    revision_number
  ) on delete restrict,
  constraint need_generation_input_snapshots_evaluation_version_check check (
    evaluation_version > 0
  ),
  constraint need_generation_input_snapshots_menu_version_check check (
    weekly_menu_version > 0
  ),
  constraint need_generation_input_snapshots_attendance_version_check check (
    attendance_version > 0
  ),
  constraint need_generation_input_snapshots_contract_version_check check (
    calculation_contract_revision_number > 0
  )
);

alter table atlas_planning.need_generation_runs
  add constraint need_generation_runs_input_snapshot_fkey foreign key (
    input_snapshot_id,
    need_generation_run_id
  ) references atlas_planning.need_generation_input_snapshots (
    need_generation_input_snapshot_id,
    need_generation_run_id
  ) on delete restrict deferrable initially deferred;

create index need_generation_input_snapshots_evaluation_idx
  on atlas_planning.need_generation_input_snapshots (
    planning_input_evaluation_id,
    planning_input_set_id,
    evaluation_version
  );
create index need_generation_input_snapshots_run_idx
  on atlas_planning.need_generation_input_snapshots (
    need_generation_run_id,
    need_generation_input_snapshot_id
  );
create index need_generation_input_snapshots_menu_idx
  on atlas_planning.need_generation_input_snapshots (
    weekly_menu_approval_snapshot_id,
    weekly_menu_id,
    weekly_menu_version
  );
create index need_generation_input_snapshots_attendance_idx
  on atlas_planning.need_generation_input_snapshots (
    attendance_approval_snapshot_id,
    attendance_batch_id,
    attendance_version
  );
create index need_generation_input_snapshots_contract_revision_idx
  on atlas_planning.need_generation_input_snapshots (
    need_generation_calculation_contract_revision_id,
    need_generation_calculation_contract_id,
    calculation_contract_revision_number
  );

create table atlas_planning.need_generation_recipe_selections (
  need_generation_recipe_selection_id uuid not null default gen_random_uuid(),
  need_generation_input_snapshot_id uuid not null,
  need_generation_run_id uuid not null,
  weekly_menu_approval_snapshot_line_id uuid not null,
  weekly_menu_approval_snapshot_id uuid not null,
  weekly_menu_id uuid not null,
  weekly_menu_version bigint not null,
  weekly_menu_line_id uuid not null,
  school_id uuid not null,
  school_type_id uuid,
  dish_id uuid not null,
  recipe_id uuid not null,
  recipe_version_id uuid not null,
  recipe_version_number integer not null,
  selection_scope text not null,
  selected_at timestamptz not null,
  constraint need_generation_recipe_selections_pkey primary key (
    need_generation_recipe_selection_id
  ),
  constraint need_generation_recipe_selections_id_owner_key unique (
    need_generation_recipe_selection_id,
    need_generation_input_snapshot_id,
    need_generation_run_id
  ),
  constraint need_generation_recipe_selections_menu_line_key unique (
    need_generation_input_snapshot_id,
    weekly_menu_approval_snapshot_line_id
  ),
  constraint need_generation_recipe_selections_snapshot_fkey foreign key (
    need_generation_input_snapshot_id,
    need_generation_run_id
  ) references atlas_planning.need_generation_input_snapshots (
    need_generation_input_snapshot_id,
    need_generation_run_id
  ) on delete restrict,
  constraint need_generation_recipe_selections_menu_snapshot_fkey foreign key (
    weekly_menu_approval_snapshot_id,
    weekly_menu_id,
    weekly_menu_version
  ) references atlas_planning.weekly_menu_approval_snapshots (
    weekly_menu_approval_snapshot_id,
    weekly_menu_id,
    weekly_menu_version
  ) on delete restrict,
  constraint need_generation_recipe_selections_snapshot_line_fkey foreign key (
    weekly_menu_approval_snapshot_line_id
  ) references atlas_planning.weekly_menu_approval_snapshot_lines (
    weekly_menu_approval_snapshot_line_id
  ) on delete restrict,
  constraint need_generation_recipe_selections_menu_line_fkey foreign key (
    weekly_menu_line_id,
    weekly_menu_id
  ) references atlas_planning.weekly_menu_lines (
    weekly_menu_line_id,
    weekly_menu_id
  ) on delete restrict,
  constraint need_generation_recipe_selections_school_fkey foreign key (
    school_id
  ) references atlas_admin.schools (school_id) on delete restrict,
  constraint need_generation_recipe_selections_school_type_fkey foreign key (
    school_type_id
  ) references atlas_admin.school_types (school_type_id) on delete restrict,
  constraint need_generation_recipe_selections_dish_fkey foreign key (
    dish_id
  ) references atlas_admin.dishes (dish_id) on delete restrict,
  constraint need_generation_recipe_selections_recipe_fkey foreign key (
    recipe_id
  ) references atlas_admin.recipes (recipe_id) on delete restrict,
  constraint need_generation_recipe_selections_recipe_version_fkey foreign key (
    recipe_version_id,
    recipe_id
  ) references atlas_admin.recipe_versions (
    recipe_version_id,
    recipe_id
  ) on delete restrict,
  constraint need_generation_recipe_selections_menu_version_check check (
    weekly_menu_version > 0
  ),
  constraint need_generation_recipe_selections_recipe_version_check check (
    recipe_version_number > 0
  ),
  constraint need_generation_recipe_selections_scope_check check (
    selection_scope in ('SCHOOL_TYPE', 'GENERAL')
  )
);

create index need_generation_recipe_selections_snapshot_idx
  on atlas_planning.need_generation_recipe_selections (
    need_generation_input_snapshot_id,
    need_generation_run_id
  );
create index need_generation_recipe_selections_menu_snapshot_idx
  on atlas_planning.need_generation_recipe_selections (
    weekly_menu_approval_snapshot_id,
    weekly_menu_id,
    weekly_menu_version
  );
create index need_generation_recipe_selections_snapshot_line_idx
  on atlas_planning.need_generation_recipe_selections (
    weekly_menu_approval_snapshot_line_id
  );
create index need_generation_recipe_selections_menu_line_idx
  on atlas_planning.need_generation_recipe_selections (
    weekly_menu_line_id,
    weekly_menu_id
  );
create index need_generation_recipe_selections_school_idx
  on atlas_planning.need_generation_recipe_selections (school_id);
create index need_generation_recipe_selections_school_type_idx
  on atlas_planning.need_generation_recipe_selections (school_type_id)
  where school_type_id is not null;
create index need_generation_recipe_selections_dish_idx
  on atlas_planning.need_generation_recipe_selections (dish_id);
create index need_generation_recipe_selections_recipe_idx
  on atlas_planning.need_generation_recipe_selections (recipe_id);
create index need_generation_recipe_selections_recipe_version_idx
  on atlas_planning.need_generation_recipe_selections (
    recipe_version_id,
    recipe_id
  );

create table atlas_planning.need_generation_recipe_line_uses (
  need_generation_recipe_line_use_id uuid not null default gen_random_uuid(),
  need_generation_input_snapshot_id uuid not null,
  need_generation_run_id uuid not null,
  need_generation_recipe_selection_id uuid not null,
  recipe_id uuid not null,
  recipe_version_id uuid not null,
  recipe_line_id uuid not null,
  recipe_line_revision_id uuid not null,
  captured_at timestamptz not null,
  constraint need_generation_recipe_line_uses_pkey primary key (
    need_generation_recipe_line_use_id
  ),
  constraint need_generation_recipe_line_uses_id_owner_key unique (
    need_generation_recipe_line_use_id,
    need_generation_recipe_selection_id,
    need_generation_input_snapshot_id,
    need_generation_run_id
  ),
  constraint need_generation_recipe_line_uses_selection_line_key unique (
    need_generation_recipe_selection_id,
    recipe_line_id
  ),
  constraint need_generation_recipe_line_uses_snapshot_fkey foreign key (
    need_generation_input_snapshot_id,
    need_generation_run_id
  ) references atlas_planning.need_generation_input_snapshots (
    need_generation_input_snapshot_id,
    need_generation_run_id
  ) on delete restrict,
  constraint need_generation_recipe_line_uses_selection_fkey foreign key (
    need_generation_recipe_selection_id,
    need_generation_input_snapshot_id,
    need_generation_run_id
  ) references atlas_planning.need_generation_recipe_selections (
    need_generation_recipe_selection_id,
    need_generation_input_snapshot_id,
    need_generation_run_id
  ) on delete restrict,
  constraint need_generation_recipe_line_uses_recipe_fkey foreign key (
    recipe_id
  ) references atlas_admin.recipes (recipe_id) on delete restrict,
  constraint need_generation_recipe_line_uses_version_fkey foreign key (
    recipe_version_id,
    recipe_id
  ) references atlas_admin.recipe_versions (
    recipe_version_id,
    recipe_id
  ) on delete restrict,
  constraint need_generation_recipe_line_uses_line_fkey foreign key (
    recipe_line_id,
    recipe_id
  ) references atlas_admin.recipe_lines (
    recipe_line_id,
    recipe_id
  ) on delete restrict,
  constraint need_generation_recipe_line_uses_revision_fkey foreign key (
    recipe_line_revision_id,
    recipe_id,
    recipe_line_id
  ) references atlas_admin.recipe_line_revisions (
    recipe_line_revision_id,
    recipe_id,
    recipe_line_id
  ) on delete restrict
);

create index need_generation_recipe_line_uses_snapshot_idx
  on atlas_planning.need_generation_recipe_line_uses (
    need_generation_input_snapshot_id,
    need_generation_run_id
  );
create index need_generation_recipe_line_uses_selection_idx
  on atlas_planning.need_generation_recipe_line_uses (
    need_generation_recipe_selection_id,
    need_generation_input_snapshot_id,
    need_generation_run_id
  );
create index need_generation_recipe_line_uses_recipe_idx
  on atlas_planning.need_generation_recipe_line_uses (recipe_id);
create index need_generation_recipe_line_uses_version_idx
  on atlas_planning.need_generation_recipe_line_uses (
    recipe_version_id,
    recipe_id
  );
create index need_generation_recipe_line_uses_line_idx
  on atlas_planning.need_generation_recipe_line_uses (
    recipe_line_id,
    recipe_id
  );
create index need_generation_recipe_line_uses_revision_idx
  on atlas_planning.need_generation_recipe_line_uses (
    recipe_line_revision_id,
    recipe_id,
    recipe_line_id
  );

create table atlas_planning.theoretical_need_lines (
  theoretical_need_line_id uuid not null default gen_random_uuid(),
  need_generation_run_id uuid not null,
  need_generation_input_snapshot_id uuid not null,
  need_generation_recipe_selection_id uuid not null,
  need_generation_recipe_line_use_id uuid not null,
  weekly_menu_approval_snapshot_line_id uuid not null,
  weekly_menu_approval_snapshot_id uuid not null,
  weekly_menu_id uuid not null,
  weekly_menu_version bigint not null,
  weekly_menu_line_id uuid not null,
  attendance_approval_snapshot_line_id uuid not null,
  attendance_approval_snapshot_id uuid not null,
  attendance_batch_id uuid not null,
  attendance_version bigint not null,
  attendance_line_id uuid not null,
  school_id uuid not null,
  service_date date not null,
  dish_id uuid not null,
  recipe_id uuid not null,
  recipe_version_id uuid not null,
  recipe_line_id uuid not null,
  recipe_line_revision_id uuid not null,
  ingredient_id uuid not null,
  unit_id uuid not null,
  need_generation_calculation_contract_id uuid not null,
  need_generation_calculation_contract_revision_id uuid not null,
  calculation_contract_revision_number bigint not null,
  predecessor_need_generation_run_id uuid,
  predecessor_theoretical_need_line_id uuid,
  line_disposition text not null,
  theoretical_quantity numeric(20, 6) not null,
  created_at timestamptz not null,
  constraint theoretical_need_lines_pkey primary key (theoretical_need_line_id),
  constraint theoretical_need_lines_id_run_key unique (
    theoretical_need_line_id,
    need_generation_run_id
  ),
  constraint theoretical_need_lines_atomic_anchor_key unique (
    need_generation_run_id,
    weekly_menu_approval_snapshot_line_id,
    attendance_approval_snapshot_line_id,
    recipe_line_revision_id,
    need_generation_calculation_contract_revision_id
  ),
  constraint theoretical_need_lines_run_fkey foreign key (
    need_generation_run_id,
    need_generation_input_snapshot_id
  ) references atlas_planning.need_generation_runs (
    need_generation_run_id,
    input_snapshot_id
  ) on delete restrict,
  constraint theoretical_need_lines_snapshot_fkey foreign key (
    need_generation_input_snapshot_id,
    need_generation_run_id
  ) references atlas_planning.need_generation_input_snapshots (
    need_generation_input_snapshot_id,
    need_generation_run_id
  ) on delete restrict,
  constraint theoretical_need_lines_selection_fkey foreign key (
    need_generation_recipe_selection_id,
    need_generation_input_snapshot_id,
    need_generation_run_id
  ) references atlas_planning.need_generation_recipe_selections (
    need_generation_recipe_selection_id,
    need_generation_input_snapshot_id,
    need_generation_run_id
  ) on delete restrict,
  constraint theoretical_need_lines_use_fkey foreign key (
    need_generation_recipe_line_use_id,
    need_generation_recipe_selection_id,
    need_generation_input_snapshot_id,
    need_generation_run_id
  ) references atlas_planning.need_generation_recipe_line_uses (
    need_generation_recipe_line_use_id,
    need_generation_recipe_selection_id,
    need_generation_input_snapshot_id,
    need_generation_run_id
  ) on delete restrict,
  constraint theoretical_need_lines_menu_snapshot_fkey foreign key (
    weekly_menu_approval_snapshot_id,
    weekly_menu_id,
    weekly_menu_version
  ) references atlas_planning.weekly_menu_approval_snapshots (
    weekly_menu_approval_snapshot_id,
    weekly_menu_id,
    weekly_menu_version
  ) on delete restrict,
  constraint theoretical_need_lines_menu_snapshot_line_fkey foreign key (
    weekly_menu_approval_snapshot_line_id
  ) references atlas_planning.weekly_menu_approval_snapshot_lines (
    weekly_menu_approval_snapshot_line_id
  ) on delete restrict,
  constraint theoretical_need_lines_menu_line_fkey foreign key (
    weekly_menu_line_id,
    weekly_menu_id
  ) references atlas_planning.weekly_menu_lines (
    weekly_menu_line_id,
    weekly_menu_id
  ) on delete restrict,
  constraint theoretical_need_lines_attendance_snapshot_fkey foreign key (
    attendance_approval_snapshot_id,
    attendance_batch_id,
    attendance_version
  ) references atlas_planning.attendance_approval_snapshots (
    attendance_approval_snapshot_id,
    attendance_batch_id,
    attendance_version
  ) on delete restrict,
  constraint theoretical_need_lines_attendance_snapshot_line_fkey foreign key (
    attendance_approval_snapshot_line_id
  ) references atlas_planning.attendance_approval_snapshot_lines (
    attendance_approval_snapshot_line_id
  ) on delete restrict,
  constraint theoretical_need_lines_attendance_line_fkey foreign key (
    attendance_line_id,
    attendance_batch_id
  ) references atlas_planning.attendance_lines (
    attendance_line_id,
    attendance_batch_id
  ) on delete restrict,
  constraint theoretical_need_lines_school_fkey foreign key (school_id)
    references atlas_admin.schools (school_id) on delete restrict,
  constraint theoretical_need_lines_dish_fkey foreign key (dish_id)
    references atlas_admin.dishes (dish_id) on delete restrict,
  constraint theoretical_need_lines_recipe_fkey foreign key (recipe_id)
    references atlas_admin.recipes (recipe_id) on delete restrict,
  constraint theoretical_need_lines_recipe_version_fkey foreign key (
    recipe_version_id,
    recipe_id
  ) references atlas_admin.recipe_versions (
    recipe_version_id,
    recipe_id
  ) on delete restrict,
  constraint theoretical_need_lines_recipe_line_fkey foreign key (
    recipe_line_id,
    recipe_id
  ) references atlas_admin.recipe_lines (
    recipe_line_id,
    recipe_id
  ) on delete restrict,
  constraint theoretical_need_lines_recipe_revision_fkey foreign key (
    recipe_line_revision_id,
    recipe_id,
    recipe_line_id
  ) references atlas_admin.recipe_line_revisions (
    recipe_line_revision_id,
    recipe_id,
    recipe_line_id
  ) on delete restrict,
  constraint theoretical_need_lines_ingredient_fkey foreign key (ingredient_id)
    references atlas_admin.ingredients (ingredient_id) on delete restrict,
  constraint theoretical_need_lines_unit_fkey foreign key (unit_id)
    references atlas_admin.units (unit_id) on delete restrict,
  constraint theoretical_need_lines_contract_revision_fkey foreign key (
    need_generation_calculation_contract_revision_id,
    need_generation_calculation_contract_id,
    calculation_contract_revision_number
  ) references atlas_planning.need_generation_calculation_contract_revisions (
    need_generation_calculation_contract_revision_id,
    need_generation_calculation_contract_id,
    revision_number
  ) on delete restrict,
  constraint theoretical_need_lines_predecessor_run_fkey foreign key (
    predecessor_need_generation_run_id
  ) references atlas_planning.need_generation_runs (
    need_generation_run_id
  ) on delete restrict,
  constraint theoretical_need_lines_predecessor_line_fkey foreign key (
    predecessor_theoretical_need_line_id,
    predecessor_need_generation_run_id
  ) references atlas_planning.theoretical_need_lines (
    theoretical_need_line_id,
    need_generation_run_id
  ) on delete restrict,
  constraint theoretical_need_lines_menu_version_check check (
    weekly_menu_version > 0
  ),
  constraint theoretical_need_lines_attendance_version_check check (
    attendance_version > 0
  ),
  constraint theoretical_need_lines_contract_version_check check (
    calculation_contract_revision_number > 0
  ),
  constraint theoretical_need_lines_predecessor_family_check check (
    (
      predecessor_need_generation_run_id is null
      and predecessor_theoretical_need_line_id is null
    ) or (
      predecessor_need_generation_run_id is not null
      and predecessor_theoretical_need_line_id is not null
      and predecessor_need_generation_run_id <> need_generation_run_id
      and predecessor_theoretical_need_line_id <> theoretical_need_line_id
    )
  ),
  constraint theoretical_need_lines_disposition_check check (
    line_disposition in ('ACTIVE', 'REMOVED')
  ),
  constraint theoretical_need_lines_quantity_disposition_check check (
    (
      line_disposition = 'ACTIVE'
      and theoretical_quantity >= 0
    ) or (
      line_disposition = 'REMOVED'
      and theoretical_quantity = 0
      and predecessor_theoretical_need_line_id is not null
    )
  )
);

create unique index theoretical_need_lines_predecessor_successor_key
  on atlas_planning.theoretical_need_lines (predecessor_theoretical_need_line_id)
  where predecessor_theoretical_need_line_id is not null;
create index theoretical_need_lines_run_snapshot_idx
  on atlas_planning.theoretical_need_lines (
    need_generation_run_id,
    need_generation_input_snapshot_id
  );
create index theoretical_need_lines_snapshot_idx
  on atlas_planning.theoretical_need_lines (
    need_generation_input_snapshot_id,
    need_generation_run_id
  );
create index theoretical_need_lines_selection_idx
  on atlas_planning.theoretical_need_lines (
    need_generation_recipe_selection_id,
    need_generation_input_snapshot_id,
    need_generation_run_id
  );
create index theoretical_need_lines_use_idx
  on atlas_planning.theoretical_need_lines (
    need_generation_recipe_line_use_id,
    need_generation_recipe_selection_id,
    need_generation_input_snapshot_id,
    need_generation_run_id
  );
create index theoretical_need_lines_menu_snapshot_idx
  on atlas_planning.theoretical_need_lines (
    weekly_menu_approval_snapshot_id,
    weekly_menu_id,
    weekly_menu_version
  );
create index theoretical_need_lines_menu_snapshot_line_idx
  on atlas_planning.theoretical_need_lines (
    weekly_menu_approval_snapshot_line_id
  );
create index theoretical_need_lines_menu_line_idx
  on atlas_planning.theoretical_need_lines (
    weekly_menu_line_id,
    weekly_menu_id
  );
create index theoretical_need_lines_attendance_snapshot_idx
  on atlas_planning.theoretical_need_lines (
    attendance_approval_snapshot_id,
    attendance_batch_id,
    attendance_version
  );
create index theoretical_need_lines_attendance_snapshot_line_idx
  on atlas_planning.theoretical_need_lines (
    attendance_approval_snapshot_line_id
  );
create index theoretical_need_lines_attendance_line_idx
  on atlas_planning.theoretical_need_lines (
    attendance_line_id,
    attendance_batch_id
  );
create index theoretical_need_lines_school_idx
  on atlas_planning.theoretical_need_lines (school_id);
create index theoretical_need_lines_dish_idx
  on atlas_planning.theoretical_need_lines (dish_id);
create index theoretical_need_lines_recipe_idx
  on atlas_planning.theoretical_need_lines (recipe_id);
create index theoretical_need_lines_recipe_version_idx
  on atlas_planning.theoretical_need_lines (recipe_version_id, recipe_id);
create index theoretical_need_lines_recipe_line_idx
  on atlas_planning.theoretical_need_lines (recipe_line_id, recipe_id);
create index theoretical_need_lines_recipe_revision_idx
  on atlas_planning.theoretical_need_lines (
    recipe_line_revision_id,
    recipe_id,
    recipe_line_id
  );
create index theoretical_need_lines_ingredient_idx
  on atlas_planning.theoretical_need_lines (ingredient_id);
create index theoretical_need_lines_unit_idx
  on atlas_planning.theoretical_need_lines (unit_id);
create index theoretical_need_lines_contract_revision_idx
  on atlas_planning.theoretical_need_lines (
    need_generation_calculation_contract_revision_id,
    need_generation_calculation_contract_id,
    calculation_contract_revision_number
  );
create index theoretical_need_lines_predecessor_run_idx
  on atlas_planning.theoretical_need_lines (
    predecessor_need_generation_run_id
  ) where predecessor_need_generation_run_id is not null;
create index theoretical_need_lines_predecessor_line_idx
  on atlas_planning.theoretical_need_lines (
    predecessor_theoretical_need_line_id,
    predecessor_need_generation_run_id
  ) where predecessor_theoretical_need_line_id is not null;

create table atlas_planning.need_generation_issues (
  need_generation_issue_id uuid not null default gen_random_uuid(),
  need_generation_run_id uuid not null,
  theoretical_need_line_id uuid,
  severity text not null,
  issue_code text not null,
  message text not null,
  weekly_menu_approval_snapshot_line_id uuid,
  attendance_approval_snapshot_line_id uuid,
  school_id uuid,
  service_date date,
  dish_id uuid,
  recipe_id uuid,
  recipe_line_id uuid,
  ingredient_id uuid,
  unit_id uuid,
  created_at timestamptz not null,
  constraint need_generation_issues_pkey primary key (need_generation_issue_id),
  constraint need_generation_issues_id_run_key unique (
    need_generation_issue_id,
    need_generation_run_id
  ),
  constraint need_generation_issues_context_key unique nulls not distinct (
    need_generation_run_id,
    issue_code,
    theoretical_need_line_id,
    weekly_menu_approval_snapshot_line_id,
    attendance_approval_snapshot_line_id,
    school_id,
    service_date,
    dish_id,
    recipe_id,
    recipe_line_id,
    ingredient_id,
    unit_id
  ),
  constraint need_generation_issues_run_fkey foreign key (
    need_generation_run_id
  ) references atlas_planning.need_generation_runs (
    need_generation_run_id
  ) on delete restrict,
  constraint need_generation_issues_line_fkey foreign key (
    theoretical_need_line_id,
    need_generation_run_id
  ) references atlas_planning.theoretical_need_lines (
    theoretical_need_line_id,
    need_generation_run_id
  ) on delete restrict,
  constraint need_generation_issues_menu_snapshot_line_fkey foreign key (
    weekly_menu_approval_snapshot_line_id
  ) references atlas_planning.weekly_menu_approval_snapshot_lines (
    weekly_menu_approval_snapshot_line_id
  ) on delete restrict,
  constraint need_generation_issues_attendance_snapshot_line_fkey foreign key (
    attendance_approval_snapshot_line_id
  ) references atlas_planning.attendance_approval_snapshot_lines (
    attendance_approval_snapshot_line_id
  ) on delete restrict,
  constraint need_generation_issues_school_fkey foreign key (school_id)
    references atlas_admin.schools (school_id) on delete restrict,
  constraint need_generation_issues_dish_fkey foreign key (dish_id)
    references atlas_admin.dishes (dish_id) on delete restrict,
  constraint need_generation_issues_recipe_fkey foreign key (recipe_id)
    references atlas_admin.recipes (recipe_id) on delete restrict,
  constraint need_generation_issues_recipe_line_fkey foreign key (recipe_line_id)
    references atlas_admin.recipe_lines (recipe_line_id) on delete restrict,
  constraint need_generation_issues_ingredient_fkey foreign key (ingredient_id)
    references atlas_admin.ingredients (ingredient_id) on delete restrict,
  constraint need_generation_issues_unit_fkey foreign key (unit_id)
    references atlas_admin.units (unit_id) on delete restrict,
  constraint need_generation_issues_severity_check check (
    severity in ('BLOCKING', 'WARNING')
  ),
  constraint need_generation_issues_code_check check (
    issue_code in (
      'MISSING_ATTENDANCE_SNAPSHOT_LINE',
      'MISSING_ELIGIBLE_RECIPE',
      'AMBIGUOUS_ELIGIBLE_RECIPE',
      'MISSING_OR_INCOMPLETE_RELEASED_RECIPE_COMPOSITION',
      'INVALID_NONPOSITIVE_RECIPE_BASIS',
      'MISSING_EXACT_RECIPE_LINE_REVISION',
      'INACTIVE_OR_INVALID_DISH',
      'INACTIVE_OR_INVALID_RECIPE',
      'INACTIVE_OR_INVALID_INGREDIENT',
      'INACTIVE_OR_INVALID_UNIT',
      'MISSING_REQUIRED_CONVERSION_RULE',
      'INVALID_CONVERSION_FACTOR',
      'NEGATIVE_OR_INVALID_CALCULATION_RESULT',
      'MISSING_TYPED_SOURCE_TRACE',
      'DUPLICATE_ATOMIC_SOURCE_ANCHOR',
      'INVALID_PREDECESSOR',
      'PREDECESSOR_FORK',
      'UNSUPPORTED_SPLIT',
      'UNSUPPORTED_MERGE',
      'SILENT_PREDECESSOR_OMISSION',
      'INVALID_REMOVAL_EVIDENCE',
      'UNSUPPORTED_REINTRODUCTION_AFTER_REMOVAL',
      'ZERO_ACTIVE_THEORETICAL_QUANTITY',
      'RELEASE_ATTEMPTED_WITH_BLOCKING_ISSUES',
      'RELEASE_MEMBERSHIP_MISSING',
      'RELEASE_MEMBERSHIP_EXTRA',
      'RELEASE_MEMBERSHIP_ALTERED',
      'RELEASE_MEMBERSHIP_DUPLICATED',
      'RELEASE_MEMBERSHIP_CROSS_RUN',
      'RELEASE_MEMBERSHIP_WRONG_VERSION',
      'RELEASE_ISSUE_SUMMARY_MISMATCH'
    )
  ),
  constraint need_generation_issues_severity_code_check check (
    (
      issue_code = 'ZERO_ACTIVE_THEORETICAL_QUANTITY'
      and severity = 'WARNING'
    ) or (
      issue_code <> 'ZERO_ACTIVE_THEORETICAL_QUANTITY'
      and severity = 'BLOCKING'
    )
  ),
  constraint need_generation_issues_message_check check (btrim(message) <> '')
);

create index need_generation_issues_run_idx
  on atlas_planning.need_generation_issues (need_generation_run_id);
create index need_generation_issues_line_idx
  on atlas_planning.need_generation_issues (
    theoretical_need_line_id,
    need_generation_run_id
  ) where theoretical_need_line_id is not null;
create index need_generation_issues_menu_snapshot_line_idx
  on atlas_planning.need_generation_issues (
    weekly_menu_approval_snapshot_line_id
  ) where weekly_menu_approval_snapshot_line_id is not null;
create index need_generation_issues_attendance_snapshot_line_idx
  on atlas_planning.need_generation_issues (
    attendance_approval_snapshot_line_id
  ) where attendance_approval_snapshot_line_id is not null;
create index need_generation_issues_school_idx
  on atlas_planning.need_generation_issues (school_id)
  where school_id is not null;
create index need_generation_issues_dish_idx
  on atlas_planning.need_generation_issues (dish_id)
  where dish_id is not null;
create index need_generation_issues_recipe_idx
  on atlas_planning.need_generation_issues (recipe_id)
  where recipe_id is not null;
create index need_generation_issues_recipe_line_idx
  on atlas_planning.need_generation_issues (recipe_line_id)
  where recipe_line_id is not null;
create index need_generation_issues_ingredient_idx
  on atlas_planning.need_generation_issues (ingredient_id)
  where ingredient_id is not null;
create index need_generation_issues_unit_idx
  on atlas_planning.need_generation_issues (unit_id)
  where unit_id is not null;

create table atlas_planning.need_generation_release_snapshots (
  need_generation_release_snapshot_id uuid not null default gen_random_uuid(),
  need_generation_run_id uuid not null,
  released_run_version bigint not null,
  need_generation_input_snapshot_id uuid not null,
  released_by_actor_id uuid not null,
  released_at timestamptz not null,
  generated_line_count integer not null,
  active_line_count integer not null,
  removed_line_count integer not null,
  blocking_issue_count integer not null,
  warning_count integer not null,
  constraint need_generation_release_snapshots_pkey primary key (
    need_generation_release_snapshot_id
  ),
  constraint need_generation_release_snapshots_run_key unique (
    need_generation_run_id
  ),
  constraint need_generation_release_snapshots_id_owner_key unique (
    need_generation_release_snapshot_id,
    need_generation_run_id,
    released_run_version
  ),
  constraint need_generation_release_snapshots_run_fkey foreign key (
    need_generation_run_id,
    need_generation_input_snapshot_id
  ) references atlas_planning.need_generation_runs (
    need_generation_run_id,
    input_snapshot_id
  ) on delete restrict,
  constraint need_generation_release_snapshots_input_fkey foreign key (
    need_generation_input_snapshot_id,
    need_generation_run_id
  ) references atlas_planning.need_generation_input_snapshots (
    need_generation_input_snapshot_id,
    need_generation_run_id
  ) on delete restrict,
  constraint need_generation_release_snapshots_actor_fkey foreign key (
    released_by_actor_id
  ) references atlas_core.actors (actor_id) on delete restrict,
  constraint need_generation_release_snapshots_version_check check (
    released_run_version > 0
  ),
  constraint need_generation_release_snapshots_line_count_check check (
    generated_line_count >= 0
    and active_line_count >= 0
    and removed_line_count >= 0
    and generated_line_count = active_line_count + removed_line_count
  ),
  constraint need_generation_release_snapshots_issue_count_check check (
    blocking_issue_count = 0
    and warning_count >= 0
  )
);

create index need_generation_release_snapshots_run_input_idx
  on atlas_planning.need_generation_release_snapshots (
    need_generation_run_id,
    need_generation_input_snapshot_id
  );
create index need_generation_release_snapshots_input_idx
  on atlas_planning.need_generation_release_snapshots (
    need_generation_input_snapshot_id,
    need_generation_run_id
  );
create index need_generation_release_snapshots_actor_idx
  on atlas_planning.need_generation_release_snapshots (released_by_actor_id);

create table atlas_planning.need_generation_release_snapshot_lines (
  need_generation_release_snapshot_line_id uuid not null default gen_random_uuid(),
  need_generation_release_snapshot_id uuid not null,
  need_generation_run_id uuid not null,
  released_run_version bigint not null,
  theoretical_need_line_id uuid not null,
  constraint need_generation_release_snapshot_lines_pkey primary key (
    need_generation_release_snapshot_line_id
  ),
  constraint need_generation_release_snapshot_lines_member_key unique (
    need_generation_release_snapshot_id,
    theoretical_need_line_id
  ),
  constraint need_generation_release_snapshot_lines_snapshot_fkey foreign key (
    need_generation_release_snapshot_id,
    need_generation_run_id,
    released_run_version
  ) references atlas_planning.need_generation_release_snapshots (
    need_generation_release_snapshot_id,
    need_generation_run_id,
    released_run_version
  ) on delete restrict,
  constraint need_generation_release_snapshot_lines_line_fkey foreign key (
    theoretical_need_line_id,
    need_generation_run_id
  ) references atlas_planning.theoretical_need_lines (
    theoretical_need_line_id,
    need_generation_run_id
  ) on delete restrict,
  constraint need_generation_release_snapshot_lines_version_check check (
    released_run_version > 0
  )
);

create index need_generation_release_snapshot_lines_snapshot_idx
  on atlas_planning.need_generation_release_snapshot_lines (
    need_generation_release_snapshot_id,
    need_generation_run_id,
    released_run_version
  );
create index need_generation_release_snapshot_lines_line_idx
  on atlas_planning.need_generation_release_snapshot_lines (
    theoretical_need_line_id,
    need_generation_run_id
  );

create table atlas_planning.need_generation_release_snapshot_issues (
  need_generation_release_snapshot_issue_id uuid not null default gen_random_uuid(),
  need_generation_release_snapshot_id uuid not null,
  need_generation_run_id uuid not null,
  released_run_version bigint not null,
  need_generation_issue_id uuid not null,
  constraint need_generation_release_snapshot_issues_pkey primary key (
    need_generation_release_snapshot_issue_id
  ),
  constraint need_generation_release_snapshot_issues_member_key unique (
    need_generation_release_snapshot_id,
    need_generation_issue_id
  ),
  constraint need_generation_release_snapshot_issues_snapshot_fkey foreign key (
    need_generation_release_snapshot_id,
    need_generation_run_id,
    released_run_version
  ) references atlas_planning.need_generation_release_snapshots (
    need_generation_release_snapshot_id,
    need_generation_run_id,
    released_run_version
  ) on delete restrict,
  constraint need_generation_release_snapshot_issues_issue_fkey foreign key (
    need_generation_issue_id,
    need_generation_run_id
  ) references atlas_planning.need_generation_issues (
    need_generation_issue_id,
    need_generation_run_id
  ) on delete restrict,
  constraint need_generation_release_snapshot_issues_version_check check (
    released_run_version > 0
  )
);

create index need_generation_release_snapshot_issues_snapshot_idx
  on atlas_planning.need_generation_release_snapshot_issues (
    need_generation_release_snapshot_id,
    need_generation_run_id,
    released_run_version
  );
create index need_generation_release_snapshot_issues_issue_idx
  on atlas_planning.need_generation_release_snapshot_issues (
    need_generation_issue_id,
    need_generation_run_id
  );

create function atlas_planning.pa_06e_h0a5b_calculation_contract_guard()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_root atlas_planning.need_generation_calculation_contracts%rowtype;
  v_predecessor atlas_planning.need_generation_calculation_contract_revisions%rowtype;
begin
  if tg_table_name = 'need_generation_calculation_contracts' then
    if tg_op = 'DELETE' then
      raise exception using
        errcode = '23514',
        message = 'need generation calculation contracts are nondeletable';
    end if;

    if tg_op = 'INSERT' then
      if new.version <> 1 then
        raise exception using
          errcode = '23514',
          message = 'the initial calculation contract version must be one';
      end if;
      return new;
    end if;

    if new.need_generation_calculation_contract_id is distinct from old.need_generation_calculation_contract_id
      or new.contract_code is distinct from old.contract_code
      or new.created_at is distinct from old.created_at
    then
      raise exception using
        errcode = '23514',
        message = 'calculation contract identity, code, and creation time are immutable';
    end if;

    if new.current_revision_id is not distinct from old.current_revision_id
      or new.version <> old.version + 1
      or new.updated_at < old.updated_at
    then
      raise exception using
        errcode = '23514',
        message = 'calculation contract pointer advances by exactly one revision';
    end if;

    select revision.*
    into v_predecessor
    from atlas_planning.need_generation_calculation_contract_revisions as revision
    where revision.need_generation_calculation_contract_revision_id = new.current_revision_id
      and revision.need_generation_calculation_contract_id = new.need_generation_calculation_contract_id;

    if v_predecessor.need_generation_calculation_contract_revision_id is null
      or v_predecessor.revision_number <> new.version
      or v_predecessor.predecessor_revision_id is distinct from old.current_revision_id
    then
      raise exception using
        errcode = '23514',
        message = 'calculation contract pointer requires the exact direct successor revision';
    end if;

    return new;
  end if;

  if tg_op in ('UPDATE', 'DELETE') then
    raise exception using
      errcode = '23514',
      message = 'calculation contract revisions are immutable and nondeletable';
  end if;

  select contract.*
  into v_root
  from atlas_planning.need_generation_calculation_contracts as contract
  where contract.need_generation_calculation_contract_id = new.need_generation_calculation_contract_id
  for update;

  if v_root.need_generation_calculation_contract_id is null then
    raise exception using
      errcode = '23503',
      message = 'calculation contract revision requires its exact root';
  end if;

  if new.revision_number = 1 then
    if new.predecessor_revision_id is not null
      or v_root.version <> 1
      or v_root.current_revision_id <> new.need_generation_calculation_contract_revision_id
      or exists (
        select 1
        from atlas_planning.need_generation_calculation_contract_revisions as existing
        where existing.need_generation_calculation_contract_id = new.need_generation_calculation_contract_id
      )
    then
      raise exception using
        errcode = '23514',
        message = 'the first calculation contract revision is exact revision one without a predecessor';
    end if;
    return new;
  end if;

  select revision.*
  into v_predecessor
  from atlas_planning.need_generation_calculation_contract_revisions as revision
  where revision.need_generation_calculation_contract_revision_id = new.predecessor_revision_id
    and revision.need_generation_calculation_contract_id = new.need_generation_calculation_contract_id;

  if v_predecessor.need_generation_calculation_contract_revision_id is null
    or new.revision_number <> v_predecessor.revision_number + 1
    or v_root.current_revision_id <> v_predecessor.need_generation_calculation_contract_revision_id
    or v_root.version <> v_predecessor.revision_number
  then
    raise exception using
      errcode = '23514',
      message = 'a calculation contract revision must directly follow the current revision';
  end if;

  return new;
end;
$$;

-- Declare the remaining trigger signatures before attaching the exact catalog;
-- their complete bodies replace these declarations below in the same migration.
create function atlas_planning.pa_06e_h0a5b_need_generation_run_guard()
returns trigger language plpgsql security invoker set search_path = ''
as $$ begin return new; end; $$;

create function atlas_planning.pa_06e_h0a5b_immutable_evidence_guard()
returns trigger language plpgsql security invoker set search_path = ''
as $$ begin return new; end; $$;

create function atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()
returns trigger language plpgsql security invoker set search_path = ''
as $$ begin return new; end; $$;

create trigger need_generation_calculation_contracts_guard
before insert or update or delete
on atlas_planning.need_generation_calculation_contracts
for each row execute function atlas_planning.pa_06e_h0a5b_calculation_contract_guard();

create trigger need_generation_calculation_contract_revisions_guard
before insert or update or delete
on atlas_planning.need_generation_calculation_contract_revisions
for each row execute function atlas_planning.pa_06e_h0a5b_calculation_contract_guard();

create trigger need_generation_runs_guard
before insert or update or delete
on atlas_planning.need_generation_runs
for each row execute function atlas_planning.pa_06e_h0a5b_need_generation_run_guard();

create trigger need_generation_input_snapshots_guard
before insert or update or delete
on atlas_planning.need_generation_input_snapshots
for each row execute function atlas_planning.pa_06e_h0a5b_immutable_evidence_guard();

create trigger need_generation_recipe_selections_guard
before insert or update or delete
on atlas_planning.need_generation_recipe_selections
for each row execute function atlas_planning.pa_06e_h0a5b_immutable_evidence_guard();

create trigger need_generation_recipe_line_uses_guard
before insert or update or delete
on atlas_planning.need_generation_recipe_line_uses
for each row execute function atlas_planning.pa_06e_h0a5b_immutable_evidence_guard();

create trigger theoretical_need_lines_guard
before insert or update or delete
on atlas_planning.theoretical_need_lines
for each row execute function atlas_planning.pa_06e_h0a5b_immutable_evidence_guard();

create trigger need_generation_issues_guard
before insert or update or delete
on atlas_planning.need_generation_issues
for each row execute function atlas_planning.pa_06e_h0a5b_immutable_evidence_guard();

create trigger need_generation_release_snapshots_guard
before insert or update or delete
on atlas_planning.need_generation_release_snapshots
for each row execute function atlas_planning.pa_06e_h0a5b_immutable_evidence_guard();

create trigger need_generation_release_snapshot_lines_guard
before insert or update or delete
on atlas_planning.need_generation_release_snapshot_lines
for each row execute function atlas_planning.pa_06e_h0a5b_immutable_evidence_guard();

create trigger need_generation_release_snapshot_issues_guard
before insert or update or delete
on atlas_planning.need_generation_release_snapshot_issues
for each row execute function atlas_planning.pa_06e_h0a5b_immutable_evidence_guard();

create constraint trigger need_generation_calculation_contracts_integrity
after insert or update or delete
on atlas_planning.need_generation_calculation_contracts
deferrable initially deferred
for each row execute function atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard();

create constraint trigger need_generation_calculation_contract_revisions_integrity
after insert or update or delete
on atlas_planning.need_generation_calculation_contract_revisions
deferrable initially deferred
for each row execute function atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard();

create constraint trigger need_generation_runs_integrity
after insert or update or delete
on atlas_planning.need_generation_runs
deferrable initially deferred
for each row execute function atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard();

create constraint trigger need_generation_input_snapshots_integrity
after insert or update or delete
on atlas_planning.need_generation_input_snapshots
deferrable initially deferred
for each row execute function atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard();

create constraint trigger need_generation_recipe_selections_integrity
after insert or update or delete
on atlas_planning.need_generation_recipe_selections
deferrable initially deferred
for each row execute function atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard();

create constraint trigger need_generation_recipe_line_uses_integrity
after insert or update or delete
on atlas_planning.need_generation_recipe_line_uses
deferrable initially deferred
for each row execute function atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard();

create constraint trigger theoretical_need_lines_integrity
after insert or update or delete
on atlas_planning.theoretical_need_lines
deferrable initially deferred
for each row execute function atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard();

create constraint trigger need_generation_issues_integrity
after insert or update or delete
on atlas_planning.need_generation_issues
deferrable initially deferred
for each row execute function atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard();

create constraint trigger need_generation_release_snapshots_integrity
after insert or update or delete
on atlas_planning.need_generation_release_snapshots
deferrable initially deferred
for each row execute function atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard();

create constraint trigger need_generation_release_snapshot_lines_integrity
after insert or update or delete
on atlas_planning.need_generation_release_snapshot_lines
deferrable initially deferred
for each row execute function atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard();

create constraint trigger need_generation_release_snapshot_issues_integrity
after insert or update or delete
on atlas_planning.need_generation_release_snapshot_issues
deferrable initially deferred
for each row execute function atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard();

alter table atlas_planning.need_generation_calculation_contracts enable row level security;
alter table atlas_planning.need_generation_calculation_contracts force row level security;
alter table atlas_planning.need_generation_calculation_contract_revisions enable row level security;
alter table atlas_planning.need_generation_calculation_contract_revisions force row level security;
alter table atlas_planning.need_generation_runs enable row level security;
alter table atlas_planning.need_generation_runs force row level security;
alter table atlas_planning.need_generation_input_snapshots enable row level security;
alter table atlas_planning.need_generation_input_snapshots force row level security;
alter table atlas_planning.need_generation_recipe_selections enable row level security;
alter table atlas_planning.need_generation_recipe_selections force row level security;
alter table atlas_planning.need_generation_recipe_line_uses enable row level security;
alter table atlas_planning.need_generation_recipe_line_uses force row level security;
alter table atlas_planning.theoretical_need_lines enable row level security;
alter table atlas_planning.theoretical_need_lines force row level security;
alter table atlas_planning.need_generation_issues enable row level security;
alter table atlas_planning.need_generation_issues force row level security;
alter table atlas_planning.need_generation_release_snapshots enable row level security;
alter table atlas_planning.need_generation_release_snapshots force row level security;
alter table atlas_planning.need_generation_release_snapshot_lines enable row level security;
alter table atlas_planning.need_generation_release_snapshot_lines force row level security;
alter table atlas_planning.need_generation_release_snapshot_issues enable row level security;
alter table atlas_planning.need_generation_release_snapshot_issues force row level security;

revoke all on table atlas_planning.need_generation_calculation_contracts
  from public, anon, authenticated, service_role;
revoke all on table atlas_planning.need_generation_calculation_contract_revisions
  from public, anon, authenticated, service_role;
revoke all on table atlas_planning.need_generation_runs
  from public, anon, authenticated, service_role;
revoke all on table atlas_planning.need_generation_input_snapshots
  from public, anon, authenticated, service_role;
revoke all on table atlas_planning.need_generation_recipe_selections
  from public, anon, authenticated, service_role;
revoke all on table atlas_planning.need_generation_recipe_line_uses
  from public, anon, authenticated, service_role;
revoke all on table atlas_planning.theoretical_need_lines
  from public, anon, authenticated, service_role;
revoke all on table atlas_planning.need_generation_issues
  from public, anon, authenticated, service_role;
revoke all on table atlas_planning.need_generation_release_snapshots
  from public, anon, authenticated, service_role;
revoke all on table atlas_planning.need_generation_release_snapshot_lines
  from public, anon, authenticated, service_role;
revoke all on table atlas_planning.need_generation_release_snapshot_issues
  from public, anon, authenticated, service_role;

revoke all on function atlas_planning.pa_06e_h0a5b_calculation_contract_guard()
  from public, anon, authenticated, service_role;
revoke all on function atlas_planning.pa_06e_h0a5b_need_generation_run_guard()
  from public, anon, authenticated, service_role;
revoke all on function atlas_planning.pa_06e_h0a5b_immutable_evidence_guard()
  from public, anon, authenticated, service_role;
revoke all on function atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()
  from public, anon, authenticated, service_role;

reset role;

set role atlas_owner;

create or replace function atlas_planning.pa_06e_h0a5b_need_generation_run_guard()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_expected atlas_planning.need_generation_runs%rowtype;
begin
  if tg_op = 'DELETE' then
    raise exception using
      errcode = '23514',
      message = 'need generation runs are nondeletable';
  end if;

  if tg_op = 'INSERT' then
    if new.run_status <> 'GENERATED'
      or new.version <> 1
      or new.validated_at is not null
      or new.released_at is not null
      or new.invalidated_at is not null
    then
      raise exception using
        errcode = '23514',
        message = 'new need generation runs enter GENERATED at version one';
    end if;
    return new;
  end if;

  if new.need_generation_run_id is distinct from old.need_generation_run_id
    or new.planning_input_set_id is distinct from old.planning_input_set_id
    or new.planning_input_evaluation_id is distinct from old.planning_input_evaluation_id
    or new.evaluation_version is distinct from old.evaluation_version
    or new.period_start is distinct from old.period_start
    or new.period_end is distinct from old.period_end
    or new.attempt_ordinal is distinct from old.attempt_ordinal
    or new.predecessor_need_generation_run_id is distinct from old.predecessor_need_generation_run_id
    or new.input_snapshot_id is distinct from old.input_snapshot_id
    or new.generated_line_count is distinct from old.generated_line_count
    or new.generated_by_actor_id is distinct from old.generated_by_actor_id
    or new.generated_at is distinct from old.generated_at
  then
    raise exception using
      errcode = '23514',
      message = 'need generation run identity, source, predecessor, snapshot, and generated facts are immutable';
  end if;

  if new.version <> old.version + 1 or new.updated_at < old.updated_at then
    raise exception using
      errcode = '23514',
      message = 'a need generation run update increments version exactly once';
  end if;

  if new.run_status = old.run_status then
    if old.run_status not in ('GENERATED', 'VALIDATED')
      or new.blocking_issue_count < old.blocking_issue_count
      or new.warning_count < old.warning_count
      or (
        new.blocking_issue_count = old.blocking_issue_count
        and new.warning_count = old.warning_count
      )
    then
      raise exception using
        errcode = '23514',
        message = 'same-status updates are only append-only failed validation or release evidence';
    end if;

    v_expected := old;
    v_expected.blocking_issue_count := new.blocking_issue_count;
    v_expected.warning_count := new.warning_count;
    v_expected.version := new.version;
    v_expected.updated_at := new.updated_at;
    if new is distinct from v_expected then
      raise exception using
        errcode = '23514',
        message = 'same-status evidence updates may change only issue counts, version, and updated time';
    end if;
    return new;
  end if;

  v_expected := old;
  v_expected.run_status := new.run_status;
  v_expected.version := new.version;
  v_expected.updated_at := new.updated_at;

  if old.run_status = 'GENERATED' and new.run_status = 'VALIDATED' then
    v_expected.validated_by_actor_id := new.validated_by_actor_id;
    v_expected.validated_at := new.validated_at;
  elsif old.run_status = 'VALIDATED'
    and new.run_status = 'RELEASED_FOR_CONFIRMATION'
  then
    v_expected.released_by_actor_id := new.released_by_actor_id;
    v_expected.released_at := new.released_at;
  elsif new.run_status = 'INVALIDATED'
    and old.run_status in ('GENERATED', 'VALIDATED', 'RELEASED_FOR_CONFIRMATION')
  then
    v_expected.invalidated_by_actor_id := new.invalidated_by_actor_id;
    v_expected.invalidated_at := new.invalidated_at;
  else
    raise exception using
      errcode = '23514',
      message = 'need generation lifecycle transition is invalid';
  end if;

  if new is distinct from v_expected then
    raise exception using
      errcode = '23514',
      message = 'need generation lifecycle transition changed unauthorized root fields';
  end if;

  return new;
end;
$$;

create or replace function atlas_planning.pa_06e_h0a5b_immutable_evidence_guard()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if tg_op in ('UPDATE', 'DELETE') then
    raise exception using
      errcode = '23514',
      message = 'need generation input, lineage, issue, and release evidence is immutable and nondeletable';
  end if;
  return new;
end;
$$;

create or replace function atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_contract_id uuid;
  v_contract atlas_planning.need_generation_calculation_contracts%rowtype;
  v_revision_count bigint;
  v_min_revision bigint;
  v_max_revision bigint;
  v_run_id uuid;
  v_run atlas_planning.need_generation_runs%rowtype;
  v_predecessor_run atlas_planning.need_generation_runs%rowtype;
  v_root atlas_planning.planning_input_sets%rowtype;
  v_evaluation atlas_planning.planning_input_evaluations%rowtype;
  v_snapshot atlas_planning.need_generation_input_snapshots%rowtype;
  v_line_count bigint;
  v_blocker_count bigint;
  v_warning_count bigint;
  v_release_count bigint;
  v_initial_check boolean := false;
  v_progress_check boolean := false;
begin
  if tg_table_name = 'need_generation_calculation_contracts' then
    v_contract_id := new.need_generation_calculation_contract_id;
  elsif tg_table_name = 'need_generation_calculation_contract_revisions' then
    v_contract_id := new.need_generation_calculation_contract_id;
  end if;

  if v_contract_id is not null then
    select contract.*
    into v_contract
    from atlas_planning.need_generation_calculation_contracts as contract
    where contract.need_generation_calculation_contract_id = v_contract_id;

    if v_contract.need_generation_calculation_contract_id is null then
      raise exception using
        errcode = '23514',
        message = 'calculation contract revision history requires its root';
    end if;

    select count(*), min(revision.revision_number), max(revision.revision_number)
    into v_revision_count, v_min_revision, v_max_revision
    from atlas_planning.need_generation_calculation_contract_revisions as revision
    where revision.need_generation_calculation_contract_id = v_contract_id;

    if v_revision_count <> v_contract.version
      or v_min_revision <> 1
      or v_max_revision <> v_contract.version
      or not exists (
        select 1
        from atlas_planning.need_generation_calculation_contract_revisions as revision
        where revision.need_generation_calculation_contract_revision_id = v_contract.current_revision_id
          and revision.need_generation_calculation_contract_id = v_contract_id
          and revision.revision_number = v_contract.version
      )
      or exists (
        select 1
        from atlas_planning.need_generation_calculation_contract_revisions as revision
        left join atlas_planning.need_generation_calculation_contract_revisions as predecessor
          on predecessor.need_generation_calculation_contract_revision_id = revision.predecessor_revision_id
         and predecessor.need_generation_calculation_contract_id = revision.need_generation_calculation_contract_id
        where revision.need_generation_calculation_contract_id = v_contract_id
          and (
            (revision.revision_number = 1 and revision.predecessor_revision_id is not null)
            or (
              revision.revision_number > 1
              and (
                predecessor.need_generation_calculation_contract_revision_id is null
                or predecessor.revision_number <> revision.revision_number - 1
              )
            )
          )
      )
    then
      raise exception using
        errcode = '23514',
        message = 'calculation contract history must be contiguous and point to the exact latest revision';
    end if;

    return new;
  end if;

  if tg_table_name = 'need_generation_runs' then
    v_run_id := new.need_generation_run_id;
    v_initial_check := tg_op = 'INSERT';
    v_progress_check := tg_op = 'UPDATE'
      and new.run_status in ('VALIDATED', 'RELEASED_FOR_CONFIRMATION')
      and new.run_status is distinct from old.run_status;
  elsif tg_table_name = 'need_generation_input_snapshots' then
    v_run_id := new.need_generation_run_id;
  elsif tg_table_name = 'need_generation_recipe_selections' then
    v_run_id := new.need_generation_run_id;
  elsif tg_table_name = 'need_generation_recipe_line_uses' then
    v_run_id := new.need_generation_run_id;
  elsif tg_table_name = 'theoretical_need_lines' then
    v_run_id := new.need_generation_run_id;
  elsif tg_table_name = 'need_generation_issues' then
    v_run_id := new.need_generation_run_id;
  elsif tg_table_name = 'need_generation_release_snapshots' then
    v_run_id := new.need_generation_run_id;
  elsif tg_table_name = 'need_generation_release_snapshot_lines' then
    v_run_id := new.need_generation_run_id;
  elsif tg_table_name = 'need_generation_release_snapshot_issues' then
    v_run_id := new.need_generation_run_id;
  end if;

  select run.*
  into v_run
  from atlas_planning.need_generation_runs as run
  where run.need_generation_run_id = v_run_id;

  if v_run.need_generation_run_id is null then
    raise exception using
      errcode = '23514',
      message = 'need generation evidence requires its exact run';
  end if;

  select input_set.*
  into v_root
  from atlas_planning.planning_input_sets as input_set
  where input_set.planning_input_set_id = v_run.planning_input_set_id;

  select evaluation.*
  into v_evaluation
  from atlas_planning.planning_input_evaluations as evaluation
  where evaluation.planning_input_evaluation_id = v_run.planning_input_evaluation_id
    and evaluation.planning_input_set_id = v_run.planning_input_set_id
    and evaluation.evaluation_version = v_run.evaluation_version;

  select snapshot.*
  into v_snapshot
  from atlas_planning.need_generation_input_snapshots as snapshot
  where snapshot.need_generation_input_snapshot_id = v_run.input_snapshot_id
    and snapshot.need_generation_run_id = v_run.need_generation_run_id;

  if v_root.planning_input_set_id is null
    or v_evaluation.planning_input_evaluation_id is null
    or v_snapshot.need_generation_input_snapshot_id is null
    or v_run.period_start <> v_root.period_start
    or v_run.period_end <> v_root.period_end
    or v_snapshot.planning_input_set_id <> v_run.planning_input_set_id
    or v_snapshot.planning_input_evaluation_id <> v_run.planning_input_evaluation_id
    or v_snapshot.evaluation_version <> v_run.evaluation_version
    or v_snapshot.weekly_menu_id <> v_evaluation.weekly_menu_id
    or v_snapshot.weekly_menu_version <> v_evaluation.weekly_menu_version
    or v_snapshot.weekly_menu_approval_snapshot_id <> v_evaluation.weekly_menu_approval_snapshot_id
    or v_snapshot.attendance_batch_id <> v_evaluation.attendance_batch_id
    or v_snapshot.attendance_version <> v_evaluation.attendance_version
    or v_snapshot.attendance_approval_snapshot_id <> v_evaluation.attendance_approval_snapshot_id
  then
    raise exception using
      errcode = '23514',
      message = 'run and input snapshot must repeat the exact evaluation and source bindings';
  end if;

  if v_run.attempt_ordinal = 1 then
    if v_run.predecessor_need_generation_run_id is not null then
      raise exception using
        errcode = '23514',
        message = 'the first generation attempt has no predecessor';
    end if;
  else
    select run.*
    into v_predecessor_run
    from atlas_planning.need_generation_runs as run
    where run.need_generation_run_id = v_run.predecessor_need_generation_run_id
      and run.planning_input_set_id = v_run.planning_input_set_id;

    if v_predecessor_run.need_generation_run_id is null
      or v_predecessor_run.attempt_ordinal + 1 <> v_run.attempt_ordinal
      or v_predecessor_run.run_status <> 'INVALIDATED'
      or v_predecessor_run.period_start <> v_run.period_start
      or v_predecessor_run.period_end <> v_run.period_end
    then
      raise exception using
        errcode = '23514',
        message = 'successor run requires the exact invalidated direct predecessor and next ordinal';
    end if;
  end if;

  if v_run.run_status in ('VALIDATED', 'RELEASED_FOR_CONFIRMATION')
    and exists (
      select 1
      from atlas_planning.need_generation_runs as successor
      where successor.predecessor_need_generation_run_id = v_run.need_generation_run_id
    )
  then
    raise exception using
      errcode = '23514',
      message = 'only the terminal run may validate or release';
  end if;

  if v_initial_check or v_progress_check then
    if v_root.readiness_status <> 'NEED_GENERATION_REQUESTED'
      or v_root.current_evaluation_id <> v_run.planning_input_evaluation_id
      or v_evaluation.evaluation_result <> 'READY'
      or v_evaluation.blocking_issue_count <> 0
      or v_evaluation.weekly_menu_id is null
      or v_evaluation.attendance_batch_id is null
      or not exists (
        select 1
        from atlas_planning.weekly_menus as menu
        where menu.weekly_menu_id = v_evaluation.weekly_menu_id
          and menu.version = v_evaluation.weekly_menu_version
          and menu.latest_approval_snapshot_id = v_evaluation.weekly_menu_approval_snapshot_id
          and menu.weekly_menu_status in ('APPROVED', 'NEED_GENERATION_REQUESTED')
          and menu.week_start <= v_run.period_start
          and menu.week_end >= v_run.period_end
      )
      or not exists (
        select 1
        from atlas_planning.attendance_batches as attendance
        where attendance.attendance_batch_id = v_evaluation.attendance_batch_id
          and attendance.version = v_evaluation.attendance_version
          and attendance.latest_approval_snapshot_id = v_evaluation.attendance_approval_snapshot_id
          and attendance.attendance_status in ('APPROVED', 'USED_FOR_NEED_GENERATION')
          and attendance.period_start <= v_run.period_start
          and attendance.period_end >= v_run.period_end
      )
    then
      raise exception using
        errcode = '23514',
        message = 'generation entry and progression require the exact current requested READY evaluation and source snapshots';
    end if;
  end if;

  if v_initial_check and not exists (
    select 1
    from atlas_planning.need_generation_calculation_contracts as contract
    where contract.need_generation_calculation_contract_id = v_snapshot.need_generation_calculation_contract_id
      and contract.current_revision_id = v_snapshot.need_generation_calculation_contract_revision_id
      and contract.version = v_snapshot.calculation_contract_revision_number
  ) then
    raise exception using
      errcode = '23514',
      message = 'the run input snapshot must bind the exact current calculation contract revision';
  end if;

  select count(*)
  into v_line_count
  from atlas_planning.theoretical_need_lines as line
  where line.need_generation_run_id = v_run.need_generation_run_id;

  select
    count(*) filter (where issue.severity = 'BLOCKING'),
    count(*) filter (where issue.severity = 'WARNING')
  into v_blocker_count, v_warning_count
  from atlas_planning.need_generation_issues as issue
  where issue.need_generation_run_id = v_run.need_generation_run_id;

  if v_line_count <> v_run.generated_line_count
    or v_blocker_count <> v_run.blocking_issue_count
    or v_warning_count <> v_run.warning_count
  then
    raise exception using
      errcode = '23514',
      message = 'stored generation line and issue counts must equal exact owned rows';
  end if;

  if exists (
    select 1
    from atlas_planning.need_generation_recipe_selections as selection
    join atlas_planning.weekly_menu_approval_snapshot_lines as menu_line
      on menu_line.weekly_menu_approval_snapshot_line_id = selection.weekly_menu_approval_snapshot_line_id
    join atlas_admin.recipes as recipe
      on recipe.recipe_id = selection.recipe_id
    join atlas_admin.recipe_versions as recipe_version
      on recipe_version.recipe_version_id = selection.recipe_version_id
     and recipe_version.recipe_id = selection.recipe_id
    where selection.need_generation_run_id = v_run.need_generation_run_id
      and (
        selection.need_generation_input_snapshot_id <> v_run.input_snapshot_id
        or selection.weekly_menu_approval_snapshot_id <> v_snapshot.weekly_menu_approval_snapshot_id
        or selection.weekly_menu_id <> v_snapshot.weekly_menu_id
        or selection.weekly_menu_version <> v_snapshot.weekly_menu_version
        or menu_line.weekly_menu_approval_snapshot_id <> selection.weekly_menu_approval_snapshot_id
        or menu_line.weekly_menu_id <> selection.weekly_menu_id
        or menu_line.weekly_menu_version <> selection.weekly_menu_version
        or menu_line.weekly_menu_line_id <> selection.weekly_menu_line_id
        or menu_line.school_id <> selection.school_id
        or menu_line.dish_id <> selection.dish_id
        or recipe.dish_id <> selection.dish_id
        or recipe_version.version_number <> selection.recipe_version_number
        or (
          selection.selection_scope = 'SCHOOL_TYPE'
          and (
            selection.school_type_id is null
            or recipe.school_type_id is distinct from selection.school_type_id
          )
        )
        or (
          selection.selection_scope = 'GENERAL'
          and recipe.school_type_id is not null
        )
      )
  ) then
    raise exception using
      errcode = '23514',
      message = 'recipe selection must preserve exact Menu, School, Dish, Recipe, and RecipeVersion ownership';
  end if;

  if exists (
    select 1
    from atlas_planning.need_generation_recipe_line_uses as line_use
    join atlas_planning.need_generation_recipe_selections as selection
      on selection.need_generation_recipe_selection_id = line_use.need_generation_recipe_selection_id
    join atlas_admin.recipe_line_revisions as revision
      on revision.recipe_line_revision_id = line_use.recipe_line_revision_id
    where line_use.need_generation_run_id = v_run.need_generation_run_id
      and (
        line_use.need_generation_input_snapshot_id <> v_run.input_snapshot_id
        or selection.need_generation_run_id <> line_use.need_generation_run_id
        or selection.need_generation_input_snapshot_id <> line_use.need_generation_input_snapshot_id
        or selection.recipe_id <> line_use.recipe_id
        or selection.recipe_version_id <> line_use.recipe_version_id
        or revision.recipe_id <> line_use.recipe_id
        or revision.recipe_version_id <> line_use.recipe_version_id
        or revision.recipe_line_id <> line_use.recipe_line_id
      )
  ) then
    raise exception using
      errcode = '23514',
      message = 'Recipe composition uses must preserve exact selection and H0A2 ownership';
  end if;

  if exists (
    select 1
    from atlas_planning.need_generation_recipe_selections as selection
    where selection.need_generation_run_id = v_run.need_generation_run_id
      and (
        select count(*)
        from atlas_planning.need_generation_recipe_line_uses as line_use
        where line_use.need_generation_recipe_selection_id = selection.need_generation_recipe_selection_id
      ) <> (
        select count(*)
        from atlas_admin.recipe_line_revisions as revision
        where revision.recipe_version_id = selection.recipe_version_id
      )
  ) or exists (
    select 1
    from atlas_planning.need_generation_recipe_selections as selection
    join atlas_admin.recipe_line_revisions as revision
      on revision.recipe_version_id = selection.recipe_version_id
    where selection.need_generation_run_id = v_run.need_generation_run_id
      and not exists (
        select 1
        from atlas_planning.need_generation_recipe_line_uses as line_use
        where line_use.need_generation_recipe_selection_id = selection.need_generation_recipe_selection_id
          and line_use.recipe_line_revision_id = revision.recipe_line_revision_id
      )
  ) then
    raise exception using
      errcode = '23514',
      message = 'every selected RecipeVersion requires every-and-only its exact composition use';
  end if;

  if v_initial_check and exists (
    select 1
    from atlas_planning.need_generation_recipe_selections as selection
    join atlas_admin.schools as school on school.school_id = selection.school_id
    join atlas_admin.dishes as dish on dish.dish_id = selection.dish_id
    join atlas_admin.recipes as recipe on recipe.recipe_id = selection.recipe_id
    join atlas_admin.recipe_versions as recipe_version
      on recipe_version.recipe_version_id = selection.recipe_version_id
    where selection.need_generation_run_id = v_run.need_generation_run_id
      and (
        dish.dish_status <> 'ACTIVE'
        or not dish.requires_need_generation
        or recipe.recipe_status <> 'ACTIVE'
        or recipe_version.recipe_version_status <> 'RELEASED_FOR_PLANNING'
        or school.school_type_id is distinct from selection.school_type_id
        or (
          selection.selection_scope = 'SCHOOL_TYPE'
          and recipe.school_type_id is distinct from school.school_type_id
        )
        or (
          selection.selection_scope = 'GENERAL'
          and exists (
            select 1
            from atlas_admin.recipes as typed_recipe
            join atlas_admin.recipe_versions as typed_version
              on typed_version.recipe_id = typed_recipe.recipe_id
             and typed_version.recipe_version_status = 'RELEASED_FOR_PLANNING'
            where typed_recipe.dish_id = selection.dish_id
              and typed_recipe.school_type_id = school.school_type_id
              and typed_recipe.recipe_status = 'ACTIVE'
          )
        )
      )
  ) then
    raise exception using
      errcode = '23514',
      message = 'new generation requires the deterministic eligible SchoolType-then-general Recipe';
  end if;

  if v_initial_check and exists (
    select 1
    from atlas_planning.weekly_menu_approval_snapshot_lines as menu_line
    join atlas_admin.dishes as dish on dish.dish_id = menu_line.dish_id
    where menu_line.weekly_menu_approval_snapshot_id = v_snapshot.weekly_menu_approval_snapshot_id
      and menu_line.service_date between v_run.period_start and v_run.period_end
      and not dish.requires_need_generation
      and exists (
        select 1
        from atlas_planning.need_generation_recipe_selections as selection
        where selection.need_generation_run_id = v_run.need_generation_run_id
          and selection.weekly_menu_approval_snapshot_line_id = menu_line.weekly_menu_approval_snapshot_line_id
      )
  ) then
    raise exception using
      errcode = '23514',
      message = 'Dishes excluded from Need Generation produce no selection';
  end if;

  if exists (
    select 1
    from atlas_planning.theoretical_need_lines as line
    join atlas_planning.need_generation_recipe_selections as selection
      on selection.need_generation_recipe_selection_id = line.need_generation_recipe_selection_id
    join atlas_planning.need_generation_recipe_line_uses as line_use
      on line_use.need_generation_recipe_line_use_id = line.need_generation_recipe_line_use_id
    join atlas_planning.weekly_menu_approval_snapshot_lines as menu_line
      on menu_line.weekly_menu_approval_snapshot_line_id = line.weekly_menu_approval_snapshot_line_id
    join atlas_planning.attendance_approval_snapshot_lines as attendance_line
      on attendance_line.attendance_approval_snapshot_line_id = line.attendance_approval_snapshot_line_id
    join atlas_admin.recipe_versions as recipe_version
      on recipe_version.recipe_version_id = line.recipe_version_id
    join atlas_admin.recipe_line_revisions as recipe_revision
      on recipe_revision.recipe_line_revision_id = line.recipe_line_revision_id
    where line.need_generation_run_id = v_run.need_generation_run_id
      and (
        line.need_generation_input_snapshot_id <> v_run.input_snapshot_id
        or selection.need_generation_run_id <> line.need_generation_run_id
        or selection.need_generation_input_snapshot_id <> line.need_generation_input_snapshot_id
        or line_use.need_generation_run_id <> line.need_generation_run_id
        or line_use.need_generation_input_snapshot_id <> line.need_generation_input_snapshot_id
        or line_use.need_generation_recipe_selection_id <> line.need_generation_recipe_selection_id
        or line.weekly_menu_approval_snapshot_id <> v_snapshot.weekly_menu_approval_snapshot_id
        or line.weekly_menu_id <> v_snapshot.weekly_menu_id
        or line.weekly_menu_version <> v_snapshot.weekly_menu_version
        or menu_line.weekly_menu_approval_snapshot_id <> line.weekly_menu_approval_snapshot_id
        or menu_line.weekly_menu_id <> line.weekly_menu_id
        or menu_line.weekly_menu_version <> line.weekly_menu_version
        or menu_line.weekly_menu_line_id <> line.weekly_menu_line_id
        or line.attendance_approval_snapshot_id <> v_snapshot.attendance_approval_snapshot_id
        or line.attendance_batch_id <> v_snapshot.attendance_batch_id
        or line.attendance_version <> v_snapshot.attendance_version
        or attendance_line.attendance_approval_snapshot_id <> line.attendance_approval_snapshot_id
        or attendance_line.attendance_batch_id <> line.attendance_batch_id
        or attendance_line.attendance_version <> line.attendance_version
        or attendance_line.attendance_line_id <> line.attendance_line_id
        or menu_line.school_id <> line.school_id
        or attendance_line.school_id <> line.school_id
        or menu_line.service_date <> line.service_date
        or attendance_line.service_date <> line.service_date
        or menu_line.dish_id <> line.dish_id
        or selection.weekly_menu_approval_snapshot_line_id <> line.weekly_menu_approval_snapshot_line_id
        or selection.weekly_menu_line_id <> line.weekly_menu_line_id
        or selection.school_id <> line.school_id
        or selection.dish_id <> line.dish_id
        or selection.recipe_id <> line.recipe_id
        or selection.recipe_version_id <> line.recipe_version_id
        or line_use.recipe_id <> line.recipe_id
        or line_use.recipe_version_id <> line.recipe_version_id
        or line_use.recipe_line_id <> line.recipe_line_id
        or line_use.recipe_line_revision_id <> line.recipe_line_revision_id
        or recipe_revision.recipe_id <> line.recipe_id
        or recipe_revision.recipe_version_id <> line.recipe_version_id
        or recipe_revision.recipe_line_id <> line.recipe_line_id
        or recipe_revision.ingredient_id <> line.ingredient_id
        or recipe_revision.unit_id <> line.unit_id
        or line.need_generation_calculation_contract_id <> v_snapshot.need_generation_calculation_contract_id
        or line.need_generation_calculation_contract_revision_id <> v_snapshot.need_generation_calculation_contract_revision_id
        or line.calculation_contract_revision_number <> v_snapshot.calculation_contract_revision_number
        or (
          line.line_disposition = 'ACTIVE'
          and (
            recipe_revision.line_disposition <> 'PRESENT'
            or line.theoretical_quantity <> (
              (
                (attendance_line.student_portions::bigint + attendance_line.teacher_portions::bigint)::numeric
                * recipe_revision.quantity_per_basis::numeric
                / recipe_version.basis_portions::numeric
              )::numeric(20, 6)
            )
          )
        )
        or (
          line.line_disposition = 'REMOVED'
          and recipe_revision.line_disposition <> 'REMOVED'
        )
      )
  ) then
    raise exception using
      errcode = '23514',
      message = 'theoretical lines require exact typed sources, source Unit, disposition, and authoritative numeric result';
  end if;

  if v_initial_check and exists (
    select 1
    from atlas_planning.theoretical_need_lines as line
    join atlas_admin.ingredients as ingredient
      on ingredient.ingredient_id = line.ingredient_id
    join atlas_admin.units as unit
      on unit.unit_id = line.unit_id
    where line.need_generation_run_id = v_run.need_generation_run_id
      and line.line_disposition = 'ACTIVE'
      and (
        ingredient.ingredient_status <> 'ACTIVE'
        or unit.unit_status <> 'ACTIVE'
      )
  ) then
    raise exception using
      errcode = '23514',
      message = 'new ACTIVE theoretical lines require active Ingredients and Units';
  end if;

  if v_initial_check and exists (
    select 1
    from atlas_planning.need_generation_recipe_selections as selection
    join atlas_planning.need_generation_recipe_line_uses as line_use
      on line_use.need_generation_recipe_selection_id = selection.need_generation_recipe_selection_id
     and line_use.need_generation_run_id = selection.need_generation_run_id
    join atlas_admin.recipe_line_revisions as recipe_revision
      on recipe_revision.recipe_line_revision_id = line_use.recipe_line_revision_id
     and recipe_revision.line_disposition = 'PRESENT'
    join atlas_planning.weekly_menu_approval_snapshot_lines as menu_line
      on menu_line.weekly_menu_approval_snapshot_line_id = selection.weekly_menu_approval_snapshot_line_id
    join atlas_planning.attendance_approval_snapshot_lines as attendance_line
      on attendance_line.attendance_approval_snapshot_id = v_snapshot.attendance_approval_snapshot_id
     and attendance_line.school_id = menu_line.school_id
     and attendance_line.service_date = menu_line.service_date
    join atlas_admin.ingredients as ingredient
      on ingredient.ingredient_id = recipe_revision.ingredient_id
    where selection.need_generation_run_id = v_run.need_generation_run_id
      and ingredient.ingredient_status <> 'ACTIVE'
      and not exists (
        select 1
        from atlas_planning.theoretical_need_lines as line
        where line.need_generation_run_id = v_run.need_generation_run_id
          and line.need_generation_recipe_line_use_id = line_use.need_generation_recipe_line_use_id
          and line.attendance_approval_snapshot_line_id = attendance_line.attendance_approval_snapshot_line_id
          and line.line_disposition = 'ACTIVE'
      )
      and not exists (
        select 1
        from atlas_planning.need_generation_issues as issue
        where issue.need_generation_run_id = v_run.need_generation_run_id
          and issue.theoretical_need_line_id is null
          and issue.issue_code = 'INACTIVE_OR_INVALID_INGREDIENT'
          and issue.severity = 'BLOCKING'
          and issue.weekly_menu_approval_snapshot_line_id = menu_line.weekly_menu_approval_snapshot_line_id
          and issue.attendance_approval_snapshot_line_id = attendance_line.attendance_approval_snapshot_line_id
          and issue.school_id = menu_line.school_id
          and issue.service_date = menu_line.service_date
          and issue.dish_id = menu_line.dish_id
          and issue.recipe_id = selection.recipe_id
          and issue.recipe_line_id = line_use.recipe_line_id
          and issue.ingredient_id = recipe_revision.ingredient_id
          and issue.unit_id = recipe_revision.unit_id
      )
  ) then
    raise exception using
      errcode = '23514',
      message = 'an inactive Ingredient produces no ACTIVE line and requires its exact blocker';
  end if;

  if v_initial_check and exists (
    select 1
    from atlas_planning.need_generation_recipe_selections as selection
    join atlas_planning.need_generation_recipe_line_uses as line_use
      on line_use.need_generation_recipe_selection_id = selection.need_generation_recipe_selection_id
     and line_use.need_generation_run_id = selection.need_generation_run_id
    join atlas_admin.recipe_line_revisions as recipe_revision
      on recipe_revision.recipe_line_revision_id = line_use.recipe_line_revision_id
     and recipe_revision.line_disposition = 'PRESENT'
    join atlas_planning.weekly_menu_approval_snapshot_lines as menu_line
      on menu_line.weekly_menu_approval_snapshot_line_id = selection.weekly_menu_approval_snapshot_line_id
    join atlas_planning.attendance_approval_snapshot_lines as attendance_line
      on attendance_line.attendance_approval_snapshot_id = v_snapshot.attendance_approval_snapshot_id
     and attendance_line.school_id = menu_line.school_id
     and attendance_line.service_date = menu_line.service_date
    join atlas_admin.units as unit
      on unit.unit_id = recipe_revision.unit_id
    where selection.need_generation_run_id = v_run.need_generation_run_id
      and unit.unit_status <> 'ACTIVE'
      and not exists (
        select 1
        from atlas_planning.theoretical_need_lines as line
        where line.need_generation_run_id = v_run.need_generation_run_id
          and line.need_generation_recipe_line_use_id = line_use.need_generation_recipe_line_use_id
          and line.attendance_approval_snapshot_line_id = attendance_line.attendance_approval_snapshot_line_id
          and line.line_disposition = 'ACTIVE'
      )
      and not exists (
        select 1
        from atlas_planning.need_generation_issues as issue
        where issue.need_generation_run_id = v_run.need_generation_run_id
          and issue.theoretical_need_line_id is null
          and issue.issue_code = 'INACTIVE_OR_INVALID_UNIT'
          and issue.severity = 'BLOCKING'
          and issue.weekly_menu_approval_snapshot_line_id = menu_line.weekly_menu_approval_snapshot_line_id
          and issue.attendance_approval_snapshot_line_id = attendance_line.attendance_approval_snapshot_line_id
          and issue.school_id = menu_line.school_id
          and issue.service_date = menu_line.service_date
          and issue.dish_id = menu_line.dish_id
          and issue.recipe_id = selection.recipe_id
          and issue.recipe_line_id = line_use.recipe_line_id
          and issue.ingredient_id = recipe_revision.ingredient_id
          and issue.unit_id = recipe_revision.unit_id
      )
  ) then
    raise exception using
      errcode = '23514',
      message = 'an inactive Unit produces no ACTIVE line and requires its exact blocker';
  end if;

  if v_initial_check and exists (
    select 1
    from atlas_planning.need_generation_recipe_selections as selection
    join atlas_planning.need_generation_recipe_line_uses as line_use
      on line_use.need_generation_recipe_selection_id = selection.need_generation_recipe_selection_id
     and line_use.need_generation_run_id = selection.need_generation_run_id
    join atlas_admin.recipe_line_revisions as recipe_revision
      on recipe_revision.recipe_line_revision_id = line_use.recipe_line_revision_id
     and recipe_revision.line_disposition = 'PRESENT'
    join atlas_planning.weekly_menu_approval_snapshot_lines as menu_line
      on menu_line.weekly_menu_approval_snapshot_line_id = selection.weekly_menu_approval_snapshot_line_id
    join atlas_planning.attendance_approval_snapshot_lines as attendance_line
      on attendance_line.attendance_approval_snapshot_id = v_snapshot.attendance_approval_snapshot_id
     and attendance_line.school_id = menu_line.school_id
     and attendance_line.service_date = menu_line.service_date
    join atlas_admin.ingredients as ingredient
      on ingredient.ingredient_id = recipe_revision.ingredient_id
    join atlas_admin.units as unit
      on unit.unit_id = recipe_revision.unit_id
    where selection.need_generation_run_id = v_run.need_generation_run_id
      and (
        select count(*)
        from atlas_planning.theoretical_need_lines as line
        where line.need_generation_run_id = v_run.need_generation_run_id
          and line.need_generation_recipe_selection_id = selection.need_generation_recipe_selection_id
          and line.need_generation_recipe_line_use_id = line_use.need_generation_recipe_line_use_id
          and line.attendance_approval_snapshot_line_id = attendance_line.attendance_approval_snapshot_line_id
          and line.line_disposition = 'ACTIVE'
      ) <> 1
      and not (
        v_run.predecessor_need_generation_run_id is not null
        and exists (
          select 1
          from atlas_planning.theoretical_need_lines as prior
          where prior.need_generation_run_id = v_run.predecessor_need_generation_run_id
            and prior.recipe_line_id = line_use.recipe_line_id
            and prior.line_disposition = 'REMOVED'
        )
        and exists (
          select 1
          from atlas_planning.need_generation_issues as issue
          where issue.need_generation_run_id = v_run.need_generation_run_id
            and issue.theoretical_need_line_id is null
            and issue.issue_code = 'UNSUPPORTED_REINTRODUCTION_AFTER_REMOVAL'
            and issue.severity = 'BLOCKING'
            and issue.recipe_id = selection.recipe_id
            and issue.recipe_line_id = line_use.recipe_line_id
        )
      )
      and not (
        ingredient.ingredient_status <> 'ACTIVE'
        and exists (
          select 1
          from atlas_planning.need_generation_issues as issue
          where issue.need_generation_run_id = v_run.need_generation_run_id
            and issue.theoretical_need_line_id is null
            and issue.issue_code = 'INACTIVE_OR_INVALID_INGREDIENT'
            and issue.severity = 'BLOCKING'
            and issue.weekly_menu_approval_snapshot_line_id = menu_line.weekly_menu_approval_snapshot_line_id
            and issue.attendance_approval_snapshot_line_id = attendance_line.attendance_approval_snapshot_line_id
            and issue.school_id = menu_line.school_id
            and issue.service_date = menu_line.service_date
            and issue.dish_id = menu_line.dish_id
            and issue.recipe_id = selection.recipe_id
            and issue.recipe_line_id = line_use.recipe_line_id
            and issue.ingredient_id = recipe_revision.ingredient_id
            and issue.unit_id = recipe_revision.unit_id
        )
      )
      and not (
        unit.unit_status <> 'ACTIVE'
        and exists (
          select 1
          from atlas_planning.need_generation_issues as issue
          where issue.need_generation_run_id = v_run.need_generation_run_id
            and issue.theoretical_need_line_id is null
            and issue.issue_code = 'INACTIVE_OR_INVALID_UNIT'
            and issue.severity = 'BLOCKING'
            and issue.weekly_menu_approval_snapshot_line_id = menu_line.weekly_menu_approval_snapshot_line_id
            and issue.attendance_approval_snapshot_line_id = attendance_line.attendance_approval_snapshot_line_id
            and issue.school_id = menu_line.school_id
            and issue.service_date = menu_line.service_date
            and issue.dish_id = menu_line.dish_id
            and issue.recipe_id = selection.recipe_id
            and issue.recipe_line_id = line_use.recipe_line_id
            and issue.ingredient_id = recipe_revision.ingredient_id
            and issue.unit_id = recipe_revision.unit_id
        )
      )
      and not exists (
        select 1
        from atlas_planning.need_generation_issues as issue
        where issue.need_generation_run_id = v_run.need_generation_run_id
          and issue.theoretical_need_line_id is null
          and issue.issue_code = 'NEGATIVE_OR_INVALID_CALCULATION_RESULT'
          and issue.severity = 'BLOCKING'
          and issue.weekly_menu_approval_snapshot_line_id = menu_line.weekly_menu_approval_snapshot_line_id
          and issue.attendance_approval_snapshot_line_id = attendance_line.attendance_approval_snapshot_line_id
          and issue.school_id = menu_line.school_id
          and issue.service_date = menu_line.service_date
          and issue.dish_id = menu_line.dish_id
          and issue.recipe_id = selection.recipe_id
          and issue.recipe_line_id = line_use.recipe_line_id
          and issue.ingredient_id = recipe_revision.ingredient_id
          and issue.unit_id = recipe_revision.unit_id
      )
  ) then
    raise exception using
      errcode = '23514',
      message = 'every PRESENT RecipeLine use with exact Attendance requires one ACTIVE theoretical line or exact permitted blocker';
  end if;

  if exists (
    select 1
    from atlas_planning.theoretical_need_lines as line
    where line.need_generation_run_id = v_run.need_generation_run_id
      and line.line_disposition = 'ACTIVE'
      and line.theoretical_quantity = 0
      and not exists (
        select 1
        from atlas_planning.need_generation_issues as issue
        where issue.need_generation_run_id = line.need_generation_run_id
          and issue.theoretical_need_line_id = line.theoretical_need_line_id
          and issue.issue_code = 'ZERO_ACTIVE_THEORETICAL_QUANTITY'
          and issue.severity = 'WARNING'
      )
  ) or exists (
    select 1
    from atlas_planning.need_generation_issues as issue
    left join atlas_planning.theoretical_need_lines as line
      on line.theoretical_need_line_id = issue.theoretical_need_line_id
     and line.need_generation_run_id = issue.need_generation_run_id
    where issue.need_generation_run_id = v_run.need_generation_run_id
      and issue.issue_code = 'ZERO_ACTIVE_THEORETICAL_QUANTITY'
      and (
        line.theoretical_need_line_id is null
        or line.line_disposition <> 'ACTIVE'
        or line.theoretical_quantity <> 0
      )
  ) then
    raise exception using
      errcode = '23514',
      message = 'every-and-only active zero quantity requires one exact warning';
  end if;

  if exists (
    select 1
    from atlas_planning.theoretical_need_lines as line
    join atlas_planning.theoretical_need_lines as predecessor
      on predecessor.theoretical_need_line_id = line.predecessor_theoretical_need_line_id
    where line.need_generation_run_id = v_run.need_generation_run_id
      and (
        v_run.predecessor_need_generation_run_id is null
        or line.predecessor_need_generation_run_id <> v_run.predecessor_need_generation_run_id
        or predecessor.need_generation_run_id <> v_run.predecessor_need_generation_run_id
        or predecessor.weekly_menu_line_id <> line.weekly_menu_line_id
        or predecessor.attendance_line_id <> line.attendance_line_id
        or predecessor.recipe_line_id <> line.recipe_line_id
      )
  ) then
    raise exception using
      errcode = '23514',
      message = 'theoretical predecessor must be the exact compatible line in the direct predecessor run';
  end if;

  if v_run.predecessor_need_generation_run_id is not null and exists (
    select 1
    from atlas_planning.theoretical_need_lines as prior
    where prior.need_generation_run_id = v_run.predecessor_need_generation_run_id
      and prior.line_disposition = 'ACTIVE'
      and not exists (
        select 1
        from atlas_planning.theoretical_need_lines as successor
        where successor.need_generation_run_id = v_run.need_generation_run_id
          and successor.predecessor_theoretical_need_line_id = prior.theoretical_need_line_id
      )
      and not exists (
        select 1
        from atlas_planning.need_generation_issues as issue
        where issue.need_generation_run_id = v_run.need_generation_run_id
          and issue.issue_code = 'SILENT_PREDECESSOR_OMISSION'
          and issue.recipe_line_id = prior.recipe_line_id
      )
  ) then
    raise exception using
      errcode = '23514',
      message = 'every prior active contribution needs one successor or the exact omission blocker';
  end if;

  if v_run.predecessor_need_generation_run_id is not null and exists (
    select 1
    from atlas_planning.theoretical_need_lines as prior
    join atlas_planning.need_generation_runs as prior_run
      on prior_run.need_generation_run_id = prior.need_generation_run_id
    join atlas_planning.need_generation_recipe_line_uses as current_use
      on current_use.need_generation_run_id = v_run.need_generation_run_id
     and current_use.recipe_line_id = prior.recipe_line_id
    join atlas_admin.recipe_line_revisions as current_revision
      on current_revision.recipe_line_revision_id = current_use.recipe_line_revision_id
    where prior_run.planning_input_set_id = v_run.planning_input_set_id
      and prior_run.attempt_ordinal < v_run.attempt_ordinal
      and prior.line_disposition = 'REMOVED'
      and current_revision.line_disposition = 'PRESENT'
      and (
        exists (
          select 1
          from atlas_planning.theoretical_need_lines as current_line
          where current_line.need_generation_run_id = v_run.need_generation_run_id
            and current_line.recipe_line_id = prior.recipe_line_id
        )
        or not exists (
          select 1
          from atlas_planning.need_generation_issues as issue
          where issue.need_generation_run_id = v_run.need_generation_run_id
            and issue.issue_code = 'UNSUPPORTED_REINTRODUCTION_AFTER_REMOVAL'
            and issue.recipe_line_id = prior.recipe_line_id
        )
      )
  ) then
    raise exception using
      errcode = '23514',
      message = 'removed-line reintroduction creates no line and requires the exact blocker';
  end if;

  if v_initial_check and exists (
    select 1
    from atlas_planning.weekly_menu_approval_snapshot_lines as menu_line
    join atlas_admin.dishes as dish on dish.dish_id = menu_line.dish_id
    where menu_line.weekly_menu_approval_snapshot_id = v_snapshot.weekly_menu_approval_snapshot_id
      and menu_line.service_date between v_run.period_start and v_run.period_end
      and dish.requires_need_generation
      and not exists (
        select 1
        from atlas_planning.need_generation_recipe_selections as selection
        where selection.need_generation_run_id = v_run.need_generation_run_id
          and selection.weekly_menu_approval_snapshot_line_id = menu_line.weekly_menu_approval_snapshot_line_id
      )
      and not exists (
        select 1
        from atlas_planning.need_generation_issues as issue
        where issue.need_generation_run_id = v_run.need_generation_run_id
          and issue.weekly_menu_approval_snapshot_line_id = menu_line.weekly_menu_approval_snapshot_line_id
          and issue.issue_code in (
            'MISSING_ELIGIBLE_RECIPE',
            'AMBIGUOUS_ELIGIBLE_RECIPE',
            'MISSING_OR_INCOMPLETE_RELEASED_RECIPE_COMPOSITION',
            'INACTIVE_OR_INVALID_DISH',
            'INACTIVE_OR_INVALID_RECIPE'
          )
      )
  ) then
    raise exception using
      errcode = '23514',
      message = 'every generation-required Menu line needs one selection or exact Recipe blocker';
  end if;

  if v_initial_check and exists (
    select 1
    from atlas_planning.need_generation_recipe_selections as selection
    where selection.need_generation_run_id = v_run.need_generation_run_id
      and not exists (
        select 1
        from atlas_planning.attendance_approval_snapshot_lines as attendance_line
        where attendance_line.attendance_approval_snapshot_id = v_snapshot.attendance_approval_snapshot_id
          and attendance_line.school_id = selection.school_id
          and attendance_line.service_date = (
            select menu_line.service_date
            from atlas_planning.weekly_menu_approval_snapshot_lines as menu_line
            where menu_line.weekly_menu_approval_snapshot_line_id = selection.weekly_menu_approval_snapshot_line_id
          )
      )
      and (
        exists (
          select 1
          from atlas_planning.theoretical_need_lines as line
          where line.need_generation_recipe_selection_id = selection.need_generation_recipe_selection_id
        )
        or not exists (
          select 1
          from atlas_planning.need_generation_issues as issue
          where issue.need_generation_run_id = v_run.need_generation_run_id
            and issue.weekly_menu_approval_snapshot_line_id = selection.weekly_menu_approval_snapshot_line_id
            and issue.issue_code = 'MISSING_ATTENDANCE_SNAPSHOT_LINE'
        )
      )
  ) then
    raise exception using
      errcode = '23514',
      message = 'missing exact Attendance produces no line and requires its exact blocker';
  end if;

  if v_progress_check and v_run.blocking_issue_count <> 0 then
    raise exception using
      errcode = '23514',
      message = 'validation and release require zero blocking issues';
  end if;

  select count(*)
  into v_release_count
  from atlas_planning.need_generation_release_snapshots as release_snapshot
  where release_snapshot.need_generation_run_id = v_run.need_generation_run_id;

  if v_run.released_at is not null and v_release_count <> 1 then
    raise exception using
      errcode = '23514',
      message = 'a released run requires exactly one immutable release snapshot';
  end if;

  if v_run.released_at is null and v_release_count <> 0 then
    raise exception using
      errcode = '23514',
      message = 'an unreleased run cannot own release evidence';
  end if;

  if v_release_count = 1 and exists (
    select 1
    from atlas_planning.need_generation_release_snapshots as release_snapshot
    where release_snapshot.need_generation_run_id = v_run.need_generation_run_id
      and (
        release_snapshot.need_generation_input_snapshot_id <> v_run.input_snapshot_id
        or release_snapshot.released_by_actor_id <> v_run.released_by_actor_id
        or release_snapshot.released_at <> v_run.released_at
        or release_snapshot.generated_line_count <> v_run.generated_line_count
        or release_snapshot.active_line_count <> (
          select count(*)
          from atlas_planning.theoretical_need_lines as line
          where line.need_generation_run_id = v_run.need_generation_run_id
            and line.line_disposition = 'ACTIVE'
        )
        or release_snapshot.removed_line_count <> (
          select count(*)
          from atlas_planning.theoretical_need_lines as line
          where line.need_generation_run_id = v_run.need_generation_run_id
            and line.line_disposition = 'REMOVED'
        )
        or release_snapshot.blocking_issue_count <> 0
        or release_snapshot.warning_count <> v_run.warning_count
        or (
          v_run.run_status = 'RELEASED_FOR_CONFIRMATION'
          and release_snapshot.released_run_version <> v_run.version
        )
        or (
          v_run.run_status = 'INVALIDATED'
          and release_snapshot.released_run_version >= v_run.version
        )
        or (
          select count(*)
          from atlas_planning.need_generation_release_snapshot_lines as member
          where member.need_generation_release_snapshot_id = release_snapshot.need_generation_release_snapshot_id
        ) <> v_run.generated_line_count
        or exists (
          select 1
          from atlas_planning.theoretical_need_lines as line
          where line.need_generation_run_id = v_run.need_generation_run_id
            and not exists (
              select 1
              from atlas_planning.need_generation_release_snapshot_lines as member
              where member.need_generation_release_snapshot_id = release_snapshot.need_generation_release_snapshot_id
                and member.need_generation_run_id = v_run.need_generation_run_id
                and member.released_run_version = release_snapshot.released_run_version
                and member.theoretical_need_line_id = line.theoretical_need_line_id
            )
        )
        or (
          select count(*)
          from atlas_planning.need_generation_release_snapshot_issues as member
          where member.need_generation_release_snapshot_id = release_snapshot.need_generation_release_snapshot_id
        ) <> v_run.warning_count
        or exists (
          select 1
          from atlas_planning.need_generation_issues as issue
          where issue.need_generation_run_id = v_run.need_generation_run_id
            and not exists (
              select 1
              from atlas_planning.need_generation_release_snapshot_issues as member
              where member.need_generation_release_snapshot_id = release_snapshot.need_generation_release_snapshot_id
                and member.need_generation_run_id = v_run.need_generation_run_id
                and member.released_run_version = release_snapshot.released_run_version
                and member.need_generation_issue_id = issue.need_generation_issue_id
            )
        )
      )
  ) then
    raise exception using
      errcode = '23514',
      message = 'release header, line membership, and issue membership must be exact and complete';
  end if;

  return new;
end;
$$;

reset role;
