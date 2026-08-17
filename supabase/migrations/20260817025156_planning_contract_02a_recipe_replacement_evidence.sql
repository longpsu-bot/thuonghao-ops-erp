-- PLANNING-CONTRACT-02A: governed Recipe replacement corrections.
--
-- A stable Weekly Menu assignment may select a different governed Dish/Recipe.
-- Prior Recipe-derived contributions then receive explicit REMOVED successors
-- bound to the exact predecessor and to typed predecessor/successor Recipe
-- selections. New Recipe contributions remain independent ACTIVE lineage.

alter table atlas_planning.theoretical_need_lines
  add column recipe_replacement_predecessor_selection_id uuid,
  add column recipe_replacement_successor_selection_id uuid,
  add constraint theoretical_need_lines_recipe_replacement_predecessor_fkey
    foreign key (recipe_replacement_predecessor_selection_id)
    references atlas_planning.need_generation_recipe_selections (
      need_generation_recipe_selection_id
    ) on delete restrict,
  add constraint theoretical_need_lines_recipe_replacement_successor_fkey
    foreign key (recipe_replacement_successor_selection_id)
    references atlas_planning.need_generation_recipe_selections (
      need_generation_recipe_selection_id
    ) on delete restrict;

create index theoretical_need_lines_recipe_replacement_predecessor_idx
  on atlas_planning.theoretical_need_lines (
    recipe_replacement_predecessor_selection_id
  )
  where recipe_replacement_predecessor_selection_id is not null;

create index theoretical_need_lines_recipe_replacement_successor_idx
  on atlas_planning.theoretical_need_lines (
    recipe_replacement_successor_selection_id
  )
  where recipe_replacement_successor_selection_id is not null;

alter table atlas_planning.theoretical_need_lines
  drop constraint theoretical_need_lines_source_family_check,
  add constraint theoretical_need_lines_source_family_check check (
    (
      contribution_family = 'RECIPE_DERIVED'
      and recipe_replacement_predecessor_selection_id is null
      and recipe_replacement_successor_selection_id is null
      and need_generation_recipe_selection_id is not null
      and need_generation_recipe_line_use_id is not null
      and weekly_menu_approval_snapshot_line_id is not null
      and weekly_menu_approval_snapshot_id is not null
      and weekly_menu_id is not null
      and weekly_menu_version is not null
      and weekly_menu_line_id is not null
      and attendance_approval_snapshot_line_id is not null
      and attendance_approval_snapshot_id is not null
      and attendance_batch_id is not null
      and attendance_version is not null
      and attendance_line_id is not null
      and dish_id is not null
      and recipe_id is not null
      and recipe_version_id is not null
      and recipe_line_id is not null
      and recipe_line_revision_id is not null
      and need_generation_calculation_contract_id is not null
      and need_generation_calculation_contract_revision_id is not null
      and calculation_contract_revision_number is not null
      and delivery_location_id is null
      and pantry_need_batch_id is null
      and pantry_need_batch_version is null
      and pantry_need_approval_snapshot_id is null
      and pantry_need_line_id is null
      and pantry_active_snapshot_member_line_id is null
    )
    or (
      contribution_family = 'RECIPE_DERIVED'
      and line_disposition = 'REMOVED'
      and recipe_replacement_predecessor_selection_id is not null
      and recipe_replacement_successor_selection_id is not null
      and need_generation_recipe_selection_id is null
      and need_generation_recipe_line_use_id is null
      and weekly_menu_approval_snapshot_line_id is not null
      and weekly_menu_approval_snapshot_id is not null
      and weekly_menu_id is not null
      and weekly_menu_version is not null
      and weekly_menu_line_id is not null
      and attendance_approval_snapshot_line_id is not null
      and attendance_approval_snapshot_id is not null
      and attendance_batch_id is not null
      and attendance_version is not null
      and attendance_line_id is not null
      and dish_id is not null
      and recipe_id is not null
      and recipe_version_id is not null
      and recipe_line_id is not null
      and recipe_line_revision_id is not null
      and need_generation_calculation_contract_id is not null
      and need_generation_calculation_contract_revision_id is not null
      and calculation_contract_revision_number is not null
      and delivery_location_id is null
      and pantry_need_batch_id is null
      and pantry_need_batch_version is null
      and pantry_need_approval_snapshot_id is null
      and pantry_need_line_id is null
      and pantry_active_snapshot_member_line_id is null
    )
    or (
      contribution_family = 'PANTRY_DIRECT'
      and recipe_replacement_predecessor_selection_id is null
      and recipe_replacement_successor_selection_id is null
      and need_generation_recipe_selection_id is null
      and need_generation_recipe_line_use_id is null
      and weekly_menu_approval_snapshot_line_id is null
      and weekly_menu_approval_snapshot_id is null
      and weekly_menu_id is null
      and weekly_menu_version is null
      and weekly_menu_line_id is null
      and attendance_approval_snapshot_line_id is null
      and attendance_approval_snapshot_id is null
      and attendance_batch_id is null
      and attendance_version is null
      and attendance_line_id is null
      and dish_id is null
      and recipe_id is null
      and recipe_version_id is null
      and recipe_line_id is null
      and recipe_line_revision_id is null
      and need_generation_calculation_contract_id is null
      and need_generation_calculation_contract_revision_id is null
      and calculation_contract_revision_number is null
      and delivery_location_id is not null
      and pantry_need_batch_id is not null
      and pantry_need_batch_version is not null
      and pantry_need_batch_version > 0
      and pantry_need_approval_snapshot_id is not null
      and pantry_need_line_id is not null
      and (
        (
          line_disposition = 'ACTIVE'
          and pantry_active_snapshot_member_line_id is not null
          and pantry_active_snapshot_member_line_id = pantry_need_line_id
        )
        or (
          line_disposition = 'REMOVED'
          and pantry_active_snapshot_member_line_id is null
        )
      )
    )
  );

grant atlas_need_generation_runtime to postgres with set true;
grant create on schema atlas_core, atlas_api to atlas_need_generation_runtime;

create function atlas_core.planning_contract_02a_recipe_replacement_removal(
  prior_theoretical_need_line_id uuid,
  current_menu_snapshot_id uuid,
  current_attendance_snapshot_id uuid,
  current_selections jsonb
)
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $$
  with candidates as (
    select
      prior.need_generation_run_id as predecessor_run_id,
      prior.theoretical_need_line_id as predecessor_line_id,
      prior.need_generation_recipe_selection_id
        as predecessor_selection_id,
      current_selection.id as successor_selection_id,
      current_menu.weekly_menu_approval_snapshot_line_id
        as menu_snapshot_line_id,
      current_menu.weekly_menu_line_id as menu_line_id,
      current_attendance.attendance_approval_snapshot_line_id
        as attendance_snapshot_line_id,
      current_attendance.attendance_line_id,
      prior.school_id,
      prior.service_date,
      prior.dish_id,
      prior.recipe_id,
      prior.recipe_version_id,
      prior.recipe_line_id,
      prior.recipe_line_revision_id,
      prior.ingredient_id,
      prior.unit_id,
      count(*) over () as candidate_count
    from atlas_planning.theoretical_need_lines prior
    join atlas_planning.need_generation_recipe_selections prior_selection
      on prior_selection.need_generation_recipe_selection_id =
        prior.need_generation_recipe_selection_id
    join atlas_planning.weekly_menu_approval_snapshot_lines prior_menu
      on prior_menu.weekly_menu_approval_snapshot_line_id =
        prior.weekly_menu_approval_snapshot_line_id
    join atlas_planning.weekly_menu_approval_snapshot_lines current_menu
      on current_menu.weekly_menu_approval_snapshot_id = current_menu_snapshot_id
     and current_menu.weekly_menu_id = prior.weekly_menu_id
     and current_menu.weekly_menu_line_id = prior.weekly_menu_line_id
     and current_menu.school_id = prior.school_id
     and current_menu.service_date = prior.service_date
     and current_menu.menu_slot_code = prior_menu.menu_slot_code
    join atlas_planning.weekly_menus current_menu_root
      on current_menu_root.weekly_menu_id = current_menu.weekly_menu_id
     and current_menu_root.version = current_menu.weekly_menu_version
     and current_menu_root.latest_approval_snapshot_id =
       current_menu.weekly_menu_approval_snapshot_id
     and current_menu_root.weekly_menu_status in (
       'APPROVED', 'NEED_GENERATION_REQUESTED'
     )
    join atlas_planning.weekly_menu_lines current_live_menu
      on current_live_menu.weekly_menu_id = current_menu.weekly_menu_id
     and current_live_menu.weekly_menu_line_id = current_menu.weekly_menu_line_id
     and current_live_menu.school_id = current_menu.school_id
     and current_live_menu.service_date = current_menu.service_date
     and current_live_menu.menu_slot_code = current_menu.menu_slot_code
     and current_live_menu.dish_id = current_menu.dish_id
     and current_live_menu.line_status = 'ACTIVE'
    join pg_catalog.jsonb_to_recordset(current_selections) current_selection(
      id uuid,
      menu_snapshot_line_id uuid,
      menu_line_id uuid,
      school_id uuid,
      dish_id uuid,
      recipe_id uuid,
      recipe_version_id uuid
    )
      on current_selection.menu_snapshot_line_id =
        current_menu.weekly_menu_approval_snapshot_line_id
     and current_selection.menu_line_id = current_menu.weekly_menu_line_id
     and current_selection.school_id = current_menu.school_id
     and current_selection.dish_id = current_menu.dish_id
    join atlas_planning.attendance_approval_snapshot_lines current_attendance
      on current_attendance.attendance_approval_snapshot_id =
        current_attendance_snapshot_id
     and current_attendance.school_id = current_menu.school_id
     and current_attendance.service_date = current_menu.service_date
     and current_attendance.attendance_line_id = prior.attendance_line_id
    join atlas_planning.attendance_batches current_attendance_root
      on current_attendance_root.attendance_batch_id =
        current_attendance.attendance_batch_id
     and current_attendance_root.version = current_attendance.attendance_version
     and current_attendance_root.latest_approval_snapshot_id =
       current_attendance.attendance_approval_snapshot_id
     and current_attendance_root.attendance_status in (
       'APPROVED', 'USED_FOR_NEED_GENERATION'
     )
    where prior.theoretical_need_line_id = prior_theoretical_need_line_id
      and prior.contribution_family = 'RECIPE_DERIVED'
      and prior.line_disposition = 'ACTIVE'
      and prior_selection.need_generation_run_id = prior.need_generation_run_id
      and prior_selection.weekly_menu_line_id = prior.weekly_menu_line_id
      and prior_selection.school_id = prior.school_id
      and row(
        current_selection.dish_id,
        current_selection.recipe_id,
        current_selection.recipe_version_id
      ) is distinct from row(
        prior_selection.dish_id,
        prior_selection.recipe_id,
        prior_selection.recipe_version_id
      )
  )
  select pg_catalog.jsonb_build_object(
    'id', gen_random_uuid(),
    'family', 'RECIPE_DERIVED',
    'selection_id', null,
    'use_id', null,
    'replacement_predecessor_selection_id', predecessor_selection_id,
    'replacement_successor_selection_id', successor_selection_id,
    'menu_snapshot_line_id', menu_snapshot_line_id,
    'menu_line_id', menu_line_id,
    'attendance_snapshot_line_id', attendance_snapshot_line_id,
    'attendance_line_id', attendance_line_id,
    'school_id', school_id,
    'service_date', service_date,
    'dish_id', dish_id,
    'recipe_id', recipe_id,
    'recipe_version_id', recipe_version_id,
    'recipe_line_id', recipe_line_id,
    'recipe_line_revision_id', recipe_line_revision_id,
    'ingredient_id', ingredient_id,
    'unit_id', unit_id,
    'predecessor_run_id', predecessor_run_id,
    'predecessor_line_id', predecessor_line_id,
    'disposition', 'REMOVED',
    'quantity', 0
  )
  from candidates
  where candidate_count = 1;
$$;

revoke all on function
  atlas_core.planning_contract_02a_recipe_replacement_removal(
    uuid, uuid, uuid, jsonb
  ) from public, anon, authenticated, service_role;

alter function
  atlas_core.planning_contract_02a_recipe_replacement_removal(
    uuid, uuid, uuid, jsonb
  ) owner to atlas_need_generation_runtime;

create function atlas_planning.planning_contract_02a_recipe_replacement_guard()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if exists (
    select 1
    from atlas_planning.theoretical_need_lines removed
    where removed.recipe_replacement_predecessor_selection_id is not null
      and not exists (
        select 1
        from atlas_planning.need_generation_runs current_run
        join atlas_planning.need_generation_input_snapshots current_input
          on current_input.need_generation_input_snapshot_id =
            removed.need_generation_input_snapshot_id
         and current_input.need_generation_run_id =
            removed.need_generation_run_id
        join atlas_planning.theoretical_need_lines predecessor
          on predecessor.theoretical_need_line_id =
            removed.predecessor_theoretical_need_line_id
         and predecessor.need_generation_run_id =
            removed.predecessor_need_generation_run_id
        join atlas_planning.need_generation_recipe_selections
          predecessor_selection
          on predecessor_selection.need_generation_recipe_selection_id =
            removed.recipe_replacement_predecessor_selection_id
        join atlas_planning.need_generation_recipe_selections
          successor_selection
          on successor_selection.need_generation_recipe_selection_id =
            removed.recipe_replacement_successor_selection_id
        join atlas_planning.weekly_menu_approval_snapshot_lines
          predecessor_menu
          on predecessor_menu.weekly_menu_approval_snapshot_line_id =
            predecessor.weekly_menu_approval_snapshot_line_id
        join atlas_planning.weekly_menu_approval_snapshot_lines successor_menu
          on successor_menu.weekly_menu_approval_snapshot_line_id =
            removed.weekly_menu_approval_snapshot_line_id
        join atlas_planning.weekly_menus successor_menu_root
          on successor_menu_root.weekly_menu_id = successor_menu.weekly_menu_id
        join atlas_planning.weekly_menu_lines successor_live_menu
          on successor_live_menu.weekly_menu_line_id =
            successor_menu.weekly_menu_line_id
         and successor_live_menu.weekly_menu_id = successor_menu.weekly_menu_id
        join atlas_planning.attendance_approval_snapshot_lines
          successor_attendance
          on successor_attendance.attendance_approval_snapshot_line_id =
            removed.attendance_approval_snapshot_line_id
        join atlas_planning.attendance_batches successor_attendance_root
          on successor_attendance_root.attendance_batch_id =
            successor_attendance.attendance_batch_id
        where current_run.need_generation_run_id =
            removed.need_generation_run_id
          and removed.recipe_replacement_successor_selection_id is not null
          and removed.contribution_family = 'RECIPE_DERIVED'
          and removed.line_disposition = 'REMOVED'
          and removed.theoretical_quantity = 0
          and current_run.predecessor_need_generation_run_id =
            predecessor.need_generation_run_id
          and predecessor.contribution_family = 'RECIPE_DERIVED'
          and predecessor.line_disposition = 'ACTIVE'
          and predecessor.need_generation_recipe_selection_id =
            predecessor_selection.need_generation_recipe_selection_id
          and predecessor_selection.need_generation_run_id =
            predecessor.need_generation_run_id
          and predecessor_selection.need_generation_input_snapshot_id =
            predecessor.need_generation_input_snapshot_id
          and predecessor_selection.weekly_menu_line_id =
            predecessor.weekly_menu_line_id
          and predecessor_selection.school_id = predecessor.school_id
          and row(
            predecessor_selection.dish_id,
            predecessor_selection.recipe_id,
            predecessor_selection.recipe_version_id
          ) = row(
            predecessor.dish_id,
            predecessor.recipe_id,
            predecessor.recipe_version_id
          )
          and successor_selection.need_generation_run_id =
            removed.need_generation_run_id
          and successor_selection.need_generation_input_snapshot_id =
            removed.need_generation_input_snapshot_id
          and successor_selection.weekly_menu_approval_snapshot_line_id =
            removed.weekly_menu_approval_snapshot_line_id
          and successor_selection.weekly_menu_line_id =
            removed.weekly_menu_line_id
          and successor_selection.school_id = removed.school_id
          and successor_menu.weekly_menu_approval_snapshot_id =
            current_input.weekly_menu_approval_snapshot_id
          and successor_menu.weekly_menu_approval_snapshot_id =
            removed.weekly_menu_approval_snapshot_id
          and successor_menu.weekly_menu_id = current_input.weekly_menu_id
          and successor_menu.weekly_menu_id = removed.weekly_menu_id
          and successor_menu.weekly_menu_version =
            current_input.weekly_menu_version
          and successor_menu.weekly_menu_version = removed.weekly_menu_version
          and successor_menu.weekly_menu_line_id =
            predecessor.weekly_menu_line_id
          and successor_menu.weekly_menu_line_id = removed.weekly_menu_line_id
          and successor_menu.school_id = predecessor.school_id
          and successor_menu.school_id = removed.school_id
          and successor_menu.service_date = predecessor.service_date
          and successor_menu.service_date = removed.service_date
          and successor_menu.menu_slot_code = predecessor_menu.menu_slot_code
          and successor_menu.dish_id = successor_selection.dish_id
          and successor_menu_root.version = successor_menu.weekly_menu_version
          and successor_menu_root.latest_approval_snapshot_id =
            successor_menu.weekly_menu_approval_snapshot_id
          and successor_menu_root.weekly_menu_status in (
            'APPROVED', 'NEED_GENERATION_REQUESTED'
          )
          and successor_live_menu.line_status = 'ACTIVE'
          and successor_live_menu.school_id = successor_menu.school_id
          and successor_live_menu.service_date = successor_menu.service_date
          and successor_live_menu.menu_slot_code = successor_menu.menu_slot_code
          and successor_live_menu.dish_id = successor_menu.dish_id
          and successor_attendance.attendance_approval_snapshot_id =
            current_input.attendance_approval_snapshot_id
          and successor_attendance.attendance_approval_snapshot_id =
            removed.attendance_approval_snapshot_id
          and successor_attendance.attendance_batch_id =
            current_input.attendance_batch_id
          and successor_attendance.attendance_batch_id =
            removed.attendance_batch_id
          and successor_attendance.attendance_version =
            current_input.attendance_version
          and successor_attendance.attendance_version =
            removed.attendance_version
          and successor_attendance.attendance_line_id =
            predecessor.attendance_line_id
          and successor_attendance.attendance_line_id =
            removed.attendance_line_id
          and successor_attendance.school_id = predecessor.school_id
          and successor_attendance.school_id = removed.school_id
          and successor_attendance.service_date = predecessor.service_date
          and successor_attendance.service_date = removed.service_date
          and successor_attendance_root.version =
            successor_attendance.attendance_version
          and successor_attendance_root.latest_approval_snapshot_id =
            successor_attendance.attendance_approval_snapshot_id
          and successor_attendance_root.attendance_status in (
            'APPROVED', 'USED_FOR_NEED_GENERATION'
          )
          and row(
            successor_selection.dish_id,
            successor_selection.recipe_id,
            successor_selection.recipe_version_id
          ) is distinct from row(
            predecessor_selection.dish_id,
            predecessor_selection.recipe_id,
            predecessor_selection.recipe_version_id
          )
          and row(
            removed.dish_id,
            removed.recipe_id,
            removed.recipe_version_id,
            removed.recipe_line_id,
            removed.recipe_line_revision_id,
            removed.ingredient_id,
            removed.unit_id
          ) = row(
            predecessor.dish_id,
            predecessor.recipe_id,
            predecessor.recipe_version_id,
            predecessor.recipe_line_id,
            predecessor.recipe_line_revision_id,
            predecessor.ingredient_id,
            predecessor.unit_id
          )
      )
  ) then
    raise exception using
      errcode = '23514',
      message = 'governed Recipe replacement removal requires exact stable Menu, Attendance, predecessor, and typed selection evidence';
  end if;

  return null;
end;
$$;

create constraint trigger theoretical_need_lines_recipe_replacement_integrity
after insert or update or delete
on atlas_planning.theoretical_need_lines
deferrable initially deferred
for each row execute function
  atlas_planning.planning_contract_02a_recipe_replacement_guard();

revoke all on function
  atlas_planning.planning_contract_02a_recipe_replacement_guard()
  from public, anon, authenticated, service_role;

alter function
  atlas_planning.planning_contract_02a_recipe_replacement_guard()
  owner to atlas_owner;

create or replace function atlas_api.create_need_generation_run(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'create_need_generation_run';
  v_payload jsonb := request -> 'payload';
  v_error jsonb;
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_set_id uuid := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'planning_input_set_id'
  );
  v_evaluation_id uuid := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'planning_input_evaluation_id'
  );
  v_start date := atlas_core.rmvp_04_safe_date(
    v_payload ->> 'period_start'
  );
  v_end date := atlas_core.rmvp_04_safe_date(v_payload ->> 'period_end');
  v_set atlas_planning.planning_input_sets%rowtype;
  v_evaluation atlas_planning.planning_input_evaluations%rowtype;
  v_terminal atlas_planning.need_generation_runs%rowtype;
  v_contract atlas_planning.need_generation_calculation_contracts%rowtype;
  v_run_id uuid := gen_random_uuid();
  v_snapshot_id uuid := gen_random_uuid();
  v_now timestamptz := pg_catalog.transaction_timestamp();
  v_attempt bigint;
  v_selections jsonb := '[]'::jsonb;
  v_uses jsonb := '[]'::jsonb;
  v_lines jsonb := '[]'::jsonb;
  v_issues jsonb := '[]'::jsonb;
  v_selection_id uuid;
  v_use_id uuid;
  v_line_id uuid;
  v_quantity numeric(20, 6);
  v_predecessor atlas_planning.theoretical_need_lines%rowtype;
  v_menu record;
  v_revision record;
  v_attendance atlas_planning.attendance_approval_snapshot_lines%rowtype;
  v_pantry record;
  v_prior record;
  v_recipe_replacement jsonb;
  v_line_count integer;
  v_blocker_count integer;
  v_warning_count integer;
  v_before jsonb;
  v_after jsonb;
begin
  v_error := atlas_core.rmvp_04_validate_command(request, v_name);
  if v_error is not null then return v_error; end if;
  v_prepare := atlas_core.rmvp_04_prepare_command(
    request, v_name, 'need-generation:' || v_set_id::text
  );
  if v_prepare ->> 'status' <> 'READY' then
    return v_prepare -> 'response';
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');

  select input_set.* into v_set
  from atlas_planning.planning_input_sets as input_set
  where input_set.planning_input_set_id = v_set_id
  for update;
  if not found or v_set.period_start <> v_start or v_set.period_end <> v_end then
    v_error := atlas_core.rmvp_04_error(
      request, v_name, 'READINESS_NOT_REQUESTED',
      'The exact Planning Input Set is not ready for Need Generation.'
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if v_set.readiness_status <> 'NEED_GENERATION_REQUESTED' then
    v_error := atlas_core.rmvp_04_error(
      request, v_name, 'READINESS_NOT_REQUESTED',
      'Request Need Generation from the current Planning Input Readiness decision first.'
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  select evaluation.* into v_evaluation
  from atlas_planning.planning_input_evaluations as evaluation
  where evaluation.planning_input_evaluation_id = v_evaluation_id
    and evaluation.planning_input_set_id = v_set_id
  for update;
  if not found
    or v_set.current_evaluation_id <> v_evaluation_id
    or v_evaluation.evaluation_result <> 'READY'
    or v_evaluation.blocking_issue_count <> 0
  then
    v_error := atlas_core.rmvp_04_error(
      request, v_name, 'CURRENT_EVALUATION_NOT_READY',
      'The current Planning Input Evaluation is not READY without blockers.'
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') <>
    v_evaluation.evaluation_version
  then
    v_error := atlas_core.rmvp_04_error(
      request, v_name, 'STALE_VERSION',
      'The current Planning Input Evaluation version changed.',
      false, false, '[]'::jsonb, '[]'::jsonb,
      v_evaluation.evaluation_version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  select run.* into v_terminal
  from atlas_planning.need_generation_runs as run
  where run.planning_input_set_id = v_set_id
  order by run.attempt_ordinal desc
  limit 1
  for update;
  if v_terminal.need_generation_run_id is not null
    and v_terminal.run_status <> 'INVALIDATED'
  then
    v_error := atlas_core.rmvp_04_error(
      request, v_name, 'NEED_GENERATION_RUN_ALREADY_ACTIVE',
      'The exact period already has a noninvalidated terminal Need Generation run.'
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  v_attempt := coalesce(v_terminal.attempt_ordinal, 0) + 1;

  -- Deterministically lock the exact source roots before checking current pointers.
  perform menu.weekly_menu_id
  from atlas_planning.weekly_menus as menu
  where menu.weekly_menu_id = v_evaluation.weekly_menu_id
  order by menu.weekly_menu_id for update;
  perform attendance.attendance_batch_id
  from atlas_planning.attendance_batches as attendance
  where attendance.attendance_batch_id = v_evaluation.attendance_batch_id
  order by attendance.attendance_batch_id for update;
  perform pantry.pantry_need_batch_id
  from atlas_planning.pantry_need_batches as pantry
  where pantry.pantry_need_batch_id = v_evaluation.pantry_need_batch_id
  order by pantry.pantry_need_batch_id for update;

  if not exists (
    select 1 from atlas_planning.weekly_menus as menu
    where menu.weekly_menu_id = v_evaluation.weekly_menu_id
      and menu.version = v_evaluation.weekly_menu_version
      and menu.latest_approval_snapshot_id =
        v_evaluation.weekly_menu_approval_snapshot_id
      and menu.week_start <= v_start and menu.week_end >= v_end
      and menu.weekly_menu_status in ('APPROVED', 'NEED_GENERATION_REQUESTED')
  ) or not exists (
    select 1 from atlas_planning.attendance_batches as attendance
    where attendance.attendance_batch_id = v_evaluation.attendance_batch_id
      and attendance.version = v_evaluation.attendance_version
      and attendance.latest_approval_snapshot_id =
        v_evaluation.attendance_approval_snapshot_id
      and attendance.period_start <= v_start
      and attendance.period_end >= v_end
      and attendance.attendance_status in ('APPROVED', 'USED_FOR_NEED_GENERATION')
  ) or not exists (
    select 1 from atlas_planning.pantry_need_batches as pantry
    where pantry.pantry_need_batch_id = v_evaluation.pantry_need_batch_id
      and pantry.version = v_evaluation.pantry_need_batch_version
      and pantry.latest_approval_snapshot_id =
        v_evaluation.pantry_need_approval_snapshot_id
      and pantry.week_start <= v_start and pantry.week_end >= v_end
      and pantry.pantry_need_batch_status = 'APPROVED'
  ) then
    v_error := atlas_core.rmvp_04_error(
      request, v_name, 'STALE_SOURCE_BINDING',
      'One or more approved source bindings changed after readiness evaluation.'
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  select contract.* into v_contract
  from atlas_planning.need_generation_calculation_contracts as contract
  where contract.contract_code = 'school_catering_proportional_per_basis'
  for key share;
  if not found then
    v_error := atlas_core.rmvp_04_error(
      request, v_name, 'INVARIANT_VIOLATION',
      'The approved Need Generation calculation contract is unavailable.'
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  for v_menu in
    select menu_line.*, school.school_type_id,
      dish.dish_status, dish.requires_need_generation,
      recipe.recipe_id, recipe.recipe_version_id,
      recipe.recipe_version_number, recipe.basis_portions,
      recipe.selection_scope, recipe.typed_eligible_count,
      recipe.general_eligible_count
    from atlas_planning.weekly_menu_approval_snapshot_lines as menu_line
    join atlas_admin.schools as school on school.school_id = menu_line.school_id
    join atlas_admin.dishes as dish on dish.dish_id = menu_line.dish_id
    left join lateral (
      with eligible as materialized (
        select candidate.recipe_id, candidate.school_type_id,
          version.recipe_version_id,
          version.version_number as recipe_version_number,
          version.basis_portions
        from atlas_admin.recipes as candidate
        join atlas_admin.recipe_versions as version
          on version.recipe_id = candidate.recipe_id
         and version.recipe_version_status = 'RELEASED_FOR_PLANNING'
        where candidate.dish_id = menu_line.dish_id
          and candidate.recipe_status = 'ACTIVE'
          and (candidate.school_type_id = school.school_type_id
            or candidate.school_type_id is null)
      ), candidate_counts as (
        select
          count(*) filter (
            where eligible.school_type_id = school.school_type_id
          ) as typed_eligible_count,
          count(*) filter (
            where eligible.school_type_id is null
          ) as general_eligible_count
        from eligible
      )
      select selected.recipe_id, selected.recipe_version_id,
        selected.recipe_version_number, selected.basis_portions,
        case when selected.school_type_id is null
          then 'GENERAL' else 'SCHOOL_TYPE' end as selection_scope,
        candidate_counts.typed_eligible_count,
        candidate_counts.general_eligible_count
      from candidate_counts
      left join lateral (
        select eligible.*
        from eligible
        where (
          candidate_counts.typed_eligible_count = 1
          and eligible.school_type_id = school.school_type_id
        ) or (
          candidate_counts.typed_eligible_count = 0
          and candidate_counts.general_eligible_count = 1
          and eligible.school_type_id is null
        )
      ) as selected on true
    ) as recipe on true
    where menu_line.weekly_menu_approval_snapshot_id =
      v_evaluation.weekly_menu_approval_snapshot_id
      and menu_line.service_date between v_start and v_end
    order by menu_line.service_date, menu_line.school_id,
      menu_line.weekly_menu_approval_snapshot_line_id
  loop
    if v_menu.dish_status <> 'ACTIVE' then
      v_issues := v_issues || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'id', gen_random_uuid(), 'severity', 'BLOCKING',
          'code', 'INACTIVE_OR_INVALID_DISH',
          'message', 'This Menu line references a Dish that is not active.',
          'menu_snapshot_line_id', v_menu.weekly_menu_approval_snapshot_line_id,
          'school_id', v_menu.school_id, 'service_date', v_menu.service_date,
          'dish_id', v_menu.dish_id
        )
      );
      continue;
    end if;
    if not v_menu.requires_need_generation then
      continue;
    end if;
    if v_menu.typed_eligible_count > 1
      or (
        v_menu.typed_eligible_count = 0
        and v_menu.general_eligible_count > 1
      )
    then
      v_issues := v_issues || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'id', gen_random_uuid(), 'severity', 'BLOCKING',
          'code', 'AMBIGUOUS_ELIGIBLE_RECIPE',
          'message', 'More than one released active Recipe is eligible in the selected tier for this Menu line.',
          'menu_snapshot_line_id', v_menu.weekly_menu_approval_snapshot_line_id,
          'school_id', v_menu.school_id, 'service_date', v_menu.service_date,
          'dish_id', v_menu.dish_id
        )
      );
      continue;
    end if;
    if v_menu.recipe_id is null then
      v_issues := v_issues || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'id', gen_random_uuid(), 'severity', 'BLOCKING',
          'code', 'MISSING_ELIGIBLE_RECIPE',
          'message', 'No released active Recipe is eligible for this Menu line.',
          'menu_snapshot_line_id', v_menu.weekly_menu_approval_snapshot_line_id,
          'school_id', v_menu.school_id, 'service_date', v_menu.service_date,
          'dish_id', v_menu.dish_id
        )
      );
      continue;
    end if;

    v_selection_id := gen_random_uuid();
    v_selections := v_selections || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'id', v_selection_id,
        'menu_snapshot_line_id', v_menu.weekly_menu_approval_snapshot_line_id,
        'menu_line_id', v_menu.weekly_menu_line_id,
        'school_id', v_menu.school_id,
        'school_type_id', v_menu.school_type_id,
        'dish_id', v_menu.dish_id,
        'recipe_id', v_menu.recipe_id,
        'recipe_version_id', v_menu.recipe_version_id,
        'recipe_version_number', v_menu.recipe_version_number,
        'selection_scope', v_menu.selection_scope
      )
    );

    select attendance.* into v_attendance
    from atlas_planning.attendance_approval_snapshot_lines as attendance
    where attendance.attendance_approval_snapshot_id =
      v_evaluation.attendance_approval_snapshot_id
      and attendance.school_id = v_menu.school_id
      and attendance.service_date = v_menu.service_date;

    for v_revision in
      select revision.*, ingredient.ingredient_status,
        unit.unit_status
      from atlas_admin.recipe_line_revisions as revision
      join atlas_admin.ingredients as ingredient
        on ingredient.ingredient_id = revision.ingredient_id
      join atlas_admin.units as unit on unit.unit_id = revision.unit_id
      where revision.recipe_version_id = v_menu.recipe_version_id
        and revision.recipe_id = v_menu.recipe_id
      order by revision.recipe_line_id
    loop
      v_use_id := gen_random_uuid();
      v_uses := v_uses || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'id', v_use_id, 'selection_id', v_selection_id,
          'recipe_id', v_menu.recipe_id,
          'recipe_version_id', v_menu.recipe_version_id,
          'recipe_line_id', v_revision.recipe_line_id,
          'recipe_line_revision_id', v_revision.recipe_line_revision_id
        )
      );
      if v_attendance.attendance_approval_snapshot_line_id is null then
        v_issues := v_issues || pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object(
            'id', gen_random_uuid(), 'severity', 'BLOCKING',
            'code', 'MISSING_ATTENDANCE_SNAPSHOT_LINE',
            'message', 'Approved Attendance is missing for this Recipe contribution.',
            'menu_snapshot_line_id', v_menu.weekly_menu_approval_snapshot_line_id,
            'school_id', v_menu.school_id, 'service_date', v_menu.service_date,
            'dish_id', v_menu.dish_id, 'recipe_id', v_menu.recipe_id,
            'recipe_line_id', v_revision.recipe_line_id,
            'ingredient_id', v_revision.ingredient_id,
            'unit_id', v_revision.unit_id
          )
        );
        continue;
      end if;
      if v_revision.ingredient_status <> 'ACTIVE'
        or v_revision.unit_status <> 'ACTIVE'
      then
        v_issues := v_issues || pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object(
            'id', gen_random_uuid(), 'severity', 'BLOCKING',
            'code', case when v_revision.ingredient_status <> 'ACTIVE'
              then 'INACTIVE_OR_INVALID_INGREDIENT'
              else 'INACTIVE_OR_INVALID_UNIT' end,
            'message', 'A Recipe contribution references inactive master data.',
            'menu_snapshot_line_id', v_menu.weekly_menu_approval_snapshot_line_id,
            'attendance_snapshot_line_id',
              v_attendance.attendance_approval_snapshot_line_id,
            'school_id', v_menu.school_id, 'service_date', v_menu.service_date,
            'dish_id', v_menu.dish_id, 'recipe_id', v_menu.recipe_id,
            'recipe_line_id', v_revision.recipe_line_id,
            'ingredient_id', v_revision.ingredient_id,
            'unit_id', v_revision.unit_id
          )
        );
        continue;
      end if;

      v_predecessor := null;
      if v_terminal.need_generation_run_id is not null then
        select prior.* into v_predecessor
        from atlas_planning.theoretical_need_lines as prior
        where prior.need_generation_run_id = v_terminal.need_generation_run_id
          and prior.contribution_family = 'RECIPE_DERIVED'
          and prior.line_disposition = 'ACTIVE'
          and prior.weekly_menu_line_id = v_menu.weekly_menu_line_id
          and prior.attendance_line_id = v_attendance.attendance_line_id
          and prior.recipe_line_id = v_revision.recipe_line_id;
      end if;

      if v_revision.line_disposition = 'PRESENT' then
        if exists (
          select 1
          from atlas_planning.theoretical_need_lines as removed
          join atlas_planning.need_generation_runs as removed_run
            on removed_run.need_generation_run_id = removed.need_generation_run_id
          where removed_run.planning_input_set_id = v_set_id
            and removed.contribution_family = 'RECIPE_DERIVED'
            and removed.line_disposition = 'REMOVED'
            and removed.weekly_menu_line_id = v_menu.weekly_menu_line_id
            and removed.attendance_line_id = v_attendance.attendance_line_id
            and removed.recipe_line_id = v_revision.recipe_line_id
        ) then
          v_issues := v_issues || pg_catalog.jsonb_build_array(
            pg_catalog.jsonb_build_object(
              'id', gen_random_uuid(), 'severity', 'BLOCKING',
              'code', 'UNSUPPORTED_REINTRODUCTION_AFTER_REMOVAL',
              'message', 'This Recipe lineage was previously removed and needs separate governance.',
              'menu_snapshot_line_id', v_menu.weekly_menu_approval_snapshot_line_id,
              'attendance_snapshot_line_id',
                v_attendance.attendance_approval_snapshot_line_id,
              'school_id', v_menu.school_id, 'service_date', v_menu.service_date,
              'dish_id', v_menu.dish_id, 'recipe_id', v_menu.recipe_id,
              'recipe_line_id', v_revision.recipe_line_id,
              'ingredient_id', v_revision.ingredient_id,
              'unit_id', v_revision.unit_id
            )
          );
          continue;
        end if;
        v_quantity := (
          (
            (
              v_attendance.student_portions::bigint
              + v_attendance.teacher_portions::bigint
            )::numeric
            * v_revision.quantity_per_basis::numeric
          ) / v_menu.basis_portions::numeric
        )::numeric(20, 6);
        v_line_id := gen_random_uuid();
        v_lines := v_lines || pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object(
            'id', v_line_id, 'family', 'RECIPE_DERIVED',
            'selection_id', v_selection_id, 'use_id', v_use_id,
            'menu_snapshot_line_id', v_menu.weekly_menu_approval_snapshot_line_id,
            'menu_line_id', v_menu.weekly_menu_line_id,
            'attendance_snapshot_line_id',
              v_attendance.attendance_approval_snapshot_line_id,
            'attendance_line_id', v_attendance.attendance_line_id,
            'school_id', v_menu.school_id, 'service_date', v_menu.service_date,
            'dish_id', v_menu.dish_id, 'recipe_id', v_menu.recipe_id,
            'recipe_version_id', v_menu.recipe_version_id,
            'recipe_line_id', v_revision.recipe_line_id,
            'recipe_line_revision_id', v_revision.recipe_line_revision_id,
            'ingredient_id', v_revision.ingredient_id,
            'unit_id', v_revision.unit_id,
            'predecessor_run_id', v_predecessor.need_generation_run_id,
            'predecessor_line_id', v_predecessor.theoretical_need_line_id,
            'disposition', 'ACTIVE', 'quantity', v_quantity
          )
        );
        if v_quantity = 0 then
          v_issues := v_issues || pg_catalog.jsonb_build_array(
            pg_catalog.jsonb_build_object(
              'id', gen_random_uuid(), 'severity', 'WARNING',
              'code', 'ZERO_ACTIVE_THEORETICAL_QUANTITY',
              'message', 'This active Recipe contribution calculated to zero.',
              'theoretical_line_id', v_line_id,
              'menu_snapshot_line_id', v_menu.weekly_menu_approval_snapshot_line_id,
              'attendance_snapshot_line_id',
                v_attendance.attendance_approval_snapshot_line_id,
              'school_id', v_menu.school_id, 'service_date', v_menu.service_date,
              'dish_id', v_menu.dish_id, 'recipe_id', v_menu.recipe_id,
              'recipe_line_id', v_revision.recipe_line_id,
              'ingredient_id', v_revision.ingredient_id,
              'unit_id', v_revision.unit_id
            )
          );
        end if;
      elsif v_predecessor.theoretical_need_line_id is not null then
        v_line_id := gen_random_uuid();
        v_lines := v_lines || pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object(
            'id', v_line_id, 'family', 'RECIPE_DERIVED',
            'selection_id', v_selection_id, 'use_id', v_use_id,
            'menu_snapshot_line_id', v_menu.weekly_menu_approval_snapshot_line_id,
            'menu_line_id', v_menu.weekly_menu_line_id,
            'attendance_snapshot_line_id',
              v_attendance.attendance_approval_snapshot_line_id,
            'attendance_line_id', v_attendance.attendance_line_id,
            'school_id', v_menu.school_id, 'service_date', v_menu.service_date,
            'dish_id', v_menu.dish_id, 'recipe_id', v_menu.recipe_id,
            'recipe_version_id', v_menu.recipe_version_id,
            'recipe_line_id', v_revision.recipe_line_id,
            'recipe_line_revision_id', v_revision.recipe_line_revision_id,
            'ingredient_id', v_revision.ingredient_id,
            'unit_id', v_revision.unit_id,
            'predecessor_run_id', v_predecessor.need_generation_run_id,
            'predecessor_line_id', v_predecessor.theoretical_need_line_id,
            'disposition', 'REMOVED', 'quantity', 0
          )
        );
      end if;
    end loop;
  end loop;

  for v_pantry in
    select pantry.*
    from atlas_planning.pantry_need_approval_snapshot_lines as pantry
    where pantry.pantry_need_approval_snapshot_id =
      v_evaluation.pantry_need_approval_snapshot_id
      and pantry.service_date between v_start and v_end
      and pantry.requested_quantity > 0
    order by pantry.service_date, pantry.school_id,
      pantry.pantry_need_line_id
  loop
    v_predecessor := null;
    if v_terminal.need_generation_run_id is not null then
      select prior.* into v_predecessor
      from atlas_planning.theoretical_need_lines as prior
      where prior.need_generation_run_id = v_terminal.need_generation_run_id
        and prior.contribution_family = 'PANTRY_DIRECT'
        and prior.line_disposition = 'ACTIVE'
        and prior.pantry_need_line_id = v_pantry.pantry_need_line_id;
    end if;
    if exists (
      select 1
      from atlas_planning.theoretical_need_lines as removed
      join atlas_planning.need_generation_runs as removed_run
        on removed_run.need_generation_run_id = removed.need_generation_run_id
      where removed_run.planning_input_set_id = v_set_id
        and removed.contribution_family = 'PANTRY_DIRECT'
        and removed.line_disposition = 'REMOVED'
        and removed.pantry_need_line_id = v_pantry.pantry_need_line_id
    ) then
      v_issues := v_issues || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'id', gen_random_uuid(), 'severity', 'BLOCKING',
          'code', 'UNSUPPORTED_REINTRODUCTION_AFTER_REMOVAL',
          'message', 'This Pantry lineage was previously removed and needs separate governance.',
          'school_id', v_pantry.school_id,
          'service_date', v_pantry.service_date,
          'ingredient_id', v_pantry.ingredient_id,
          'unit_id', v_pantry.unit_id,
          'pantry_snapshot_id', v_evaluation.pantry_need_approval_snapshot_id,
          'pantry_line_id', v_pantry.pantry_need_line_id,
          'pantry_active_line_id', v_pantry.pantry_need_line_id
        )
      );
      continue;
    end if;
    v_line_id := gen_random_uuid();
    v_lines := v_lines || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'id', v_line_id, 'family', 'PANTRY_DIRECT',
        'school_id', v_pantry.school_id,
        'service_date', v_pantry.service_date,
        'delivery_location_id', v_pantry.delivery_location_id,
        'ingredient_id', v_pantry.ingredient_id,
        'unit_id', v_pantry.unit_id,
        'pantry_line_id', v_pantry.pantry_need_line_id,
        'pantry_active_line_id', v_pantry.pantry_need_line_id,
        'predecessor_run_id', v_predecessor.need_generation_run_id,
        'predecessor_line_id', v_predecessor.theoretical_need_line_id,
        'disposition', 'ACTIVE',
        'quantity', v_pantry.requested_quantity
      )
    );
    if v_predecessor.theoretical_need_line_id is not null
      and (v_predecessor.school_id, v_predecessor.service_date,
        v_predecessor.delivery_location_id, v_predecessor.ingredient_id,
        v_predecessor.unit_id) is distinct from
        (v_pantry.school_id, v_pantry.service_date,
        v_pantry.delivery_location_id, v_pantry.ingredient_id,
        v_pantry.unit_id)
    then
      v_issues := v_issues || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'id', gen_random_uuid(), 'severity', 'BLOCKING',
          'code', 'INVALID_PREDECESSOR',
          'message', 'The Pantry correction changed a fixed operational anchor.',
          'theoretical_line_id', v_line_id,
          'school_id', v_pantry.school_id,
          'service_date', v_pantry.service_date,
          'ingredient_id', v_pantry.ingredient_id,
          'unit_id', v_pantry.unit_id,
          'pantry_snapshot_id', v_evaluation.pantry_need_approval_snapshot_id,
          'pantry_line_id', v_pantry.pantry_need_line_id,
          'pantry_active_line_id', v_pantry.pantry_need_line_id
        )
      );
    end if;
  end loop;

  if v_terminal.need_generation_run_id is not null then
    for v_prior in
      select prior.*
      from atlas_planning.theoretical_need_lines as prior
      where prior.need_generation_run_id = v_terminal.need_generation_run_id
        and prior.line_disposition = 'ACTIVE'
        and not exists (
          select 1 from pg_catalog.jsonb_array_elements(v_lines) as item
          where atlas_core.pa_05b_safe_uuid(
            item ->> 'predecessor_line_id'
          ) = prior.theoretical_need_line_id
        )
      order by prior.contribution_family, prior.theoretical_need_line_id
    loop
      if v_prior.contribution_family = 'PANTRY_DIRECT' then
        v_lines := v_lines || pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object(
            'id', gen_random_uuid(), 'family', 'PANTRY_DIRECT',
            'school_id', v_prior.school_id,
            'service_date', v_prior.service_date,
            'delivery_location_id', v_prior.delivery_location_id,
            'ingredient_id', v_prior.ingredient_id,
            'unit_id', v_prior.unit_id,
            'pantry_line_id', v_prior.pantry_need_line_id,
            'predecessor_run_id', v_terminal.need_generation_run_id,
            'predecessor_line_id', v_prior.theoretical_need_line_id,
            'disposition', 'REMOVED', 'quantity', 0
          )
        );
      else
        v_recipe_replacement :=
          atlas_core.planning_contract_02a_recipe_replacement_removal(
            v_prior.theoretical_need_line_id,
            v_evaluation.weekly_menu_approval_snapshot_id,
            v_evaluation.attendance_approval_snapshot_id,
            v_selections
          );
        if v_recipe_replacement is not null then
          v_lines := v_lines || pg_catalog.jsonb_build_array(
            v_recipe_replacement
          );
        else
          v_issues := v_issues || pg_catalog.jsonb_build_array(
            pg_catalog.jsonb_build_object(
              'id', gen_random_uuid(), 'severity', 'BLOCKING',
              'code', 'SILENT_PREDECESSOR_OMISSION',
              'message', 'A prior Recipe contribution has no typed successor or removal.',
              'school_id', v_prior.school_id,
              'service_date', v_prior.service_date,
              'dish_id', v_prior.dish_id,
              'recipe_id', v_prior.recipe_id,
              'recipe_line_id', v_prior.recipe_line_id,
              'ingredient_id', v_prior.ingredient_id,
              'unit_id', v_prior.unit_id
            )
          );
        end if;
      end if;
    end loop;
  end if;

  v_line_count := pg_catalog.jsonb_array_length(v_lines);
  select count(*) filter (where item ->> 'severity' = 'BLOCKING'),
    count(*) filter (where item ->> 'severity' = 'WARNING')
  into v_blocker_count, v_warning_count
  from pg_catalog.jsonb_array_elements(v_issues) as item;

  insert into atlas_planning.need_generation_runs (
    need_generation_run_id, planning_input_set_id,
    planning_input_evaluation_id, evaluation_version,
    period_start, period_end, attempt_ordinal,
    predecessor_need_generation_run_id, input_snapshot_id,
    run_status, version, generated_line_count, blocking_issue_count,
    warning_count, generated_by_actor_id, generated_at, updated_at
  ) values (
    v_run_id, v_set_id, v_evaluation_id, v_evaluation.evaluation_version,
    v_start, v_end, v_attempt, v_terminal.need_generation_run_id,
    v_snapshot_id, 'GENERATED', 1, v_line_count, v_blocker_count,
    v_warning_count, v_actor_id, v_now, v_now
  );

  insert into atlas_planning.need_generation_input_snapshots (
    need_generation_input_snapshot_id, need_generation_run_id,
    planning_input_set_id, planning_input_evaluation_id, evaluation_version,
    weekly_menu_id, weekly_menu_version, weekly_menu_approval_snapshot_id,
    attendance_batch_id, attendance_version, attendance_approval_snapshot_id,
    need_generation_calculation_contract_id,
    need_generation_calculation_contract_revision_id,
    calculation_contract_revision_number, captured_at,
    pantry_need_batch_id, pantry_need_batch_version,
    pantry_need_approval_snapshot_id
  ) values (
    v_snapshot_id, v_run_id, v_set_id, v_evaluation_id,
    v_evaluation.evaluation_version, v_evaluation.weekly_menu_id,
    v_evaluation.weekly_menu_version,
    v_evaluation.weekly_menu_approval_snapshot_id,
    v_evaluation.attendance_batch_id, v_evaluation.attendance_version,
    v_evaluation.attendance_approval_snapshot_id,
    v_contract.need_generation_calculation_contract_id,
    v_contract.current_revision_id, v_contract.version, v_now,
    v_evaluation.pantry_need_batch_id,
    v_evaluation.pantry_need_batch_version,
    v_evaluation.pantry_need_approval_snapshot_id
  );

  insert into atlas_planning.need_generation_recipe_selections (
    need_generation_recipe_selection_id, need_generation_input_snapshot_id,
    need_generation_run_id, weekly_menu_approval_snapshot_line_id,
    weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version,
    weekly_menu_line_id, school_id, school_type_id, dish_id, recipe_id,
    recipe_version_id, recipe_version_number, selection_scope, selected_at
  )
  select item.id, v_snapshot_id, v_run_id, item.menu_snapshot_line_id,
    v_evaluation.weekly_menu_approval_snapshot_id,
    v_evaluation.weekly_menu_id, v_evaluation.weekly_menu_version,
    item.menu_line_id, item.school_id, item.school_type_id, item.dish_id,
    item.recipe_id, item.recipe_version_id, item.recipe_version_number,
    item.selection_scope, v_now
  from pg_catalog.jsonb_to_recordset(v_selections) as item(
    id uuid, menu_snapshot_line_id uuid, menu_line_id uuid, school_id uuid,
    school_type_id uuid, dish_id uuid, recipe_id uuid,
    recipe_version_id uuid, recipe_version_number integer,
    selection_scope text
  );

  insert into atlas_planning.need_generation_recipe_line_uses (
    need_generation_recipe_line_use_id, need_generation_input_snapshot_id,
    need_generation_run_id, need_generation_recipe_selection_id,
    recipe_id, recipe_version_id, recipe_line_id,
    recipe_line_revision_id, captured_at
  )
  select item.id, v_snapshot_id, v_run_id, item.selection_id,
    item.recipe_id, item.recipe_version_id, item.recipe_line_id,
    item.recipe_line_revision_id, v_now
  from pg_catalog.jsonb_to_recordset(v_uses) as item(
    id uuid, selection_id uuid, recipe_id uuid, recipe_version_id uuid,
    recipe_line_id uuid, recipe_line_revision_id uuid
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
    calculation_contract_revision_number,
    predecessor_need_generation_run_id, predecessor_theoretical_need_line_id,
    line_disposition, theoretical_quantity, created_at,
    contribution_family, delivery_location_id, pantry_need_batch_id,
    pantry_need_batch_version, pantry_need_approval_snapshot_id,
    pantry_need_line_id, pantry_active_snapshot_member_line_id,
    recipe_replacement_predecessor_selection_id,
    recipe_replacement_successor_selection_id
  )
  select item.id, v_run_id, v_snapshot_id,
    item.selection_id, item.use_id, item.menu_snapshot_line_id,
    case when item.family = 'RECIPE_DERIVED'
      then v_evaluation.weekly_menu_approval_snapshot_id end,
    case when item.family = 'RECIPE_DERIVED'
      then v_evaluation.weekly_menu_id end,
    case when item.family = 'RECIPE_DERIVED'
      then v_evaluation.weekly_menu_version end,
    item.menu_line_id, item.attendance_snapshot_line_id,
    case when item.family = 'RECIPE_DERIVED'
      then v_evaluation.attendance_approval_snapshot_id end,
    case when item.family = 'RECIPE_DERIVED'
      then v_evaluation.attendance_batch_id end,
    case when item.family = 'RECIPE_DERIVED'
      then v_evaluation.attendance_version end,
    item.attendance_line_id, item.school_id, item.service_date,
    item.dish_id, item.recipe_id, item.recipe_version_id,
    item.recipe_line_id, item.recipe_line_revision_id,
    item.ingredient_id, item.unit_id,
    case when item.family = 'RECIPE_DERIVED'
      then v_contract.need_generation_calculation_contract_id end,
    case when item.family = 'RECIPE_DERIVED'
      then v_contract.current_revision_id end,
    case when item.family = 'RECIPE_DERIVED' then v_contract.version end,
    item.predecessor_run_id, item.predecessor_line_id,
    item.disposition, item.quantity, v_now, item.family,
    item.delivery_location_id,
    case when item.family = 'PANTRY_DIRECT'
      then v_evaluation.pantry_need_batch_id end,
    case when item.family = 'PANTRY_DIRECT'
      then v_evaluation.pantry_need_batch_version end,
    case when item.family = 'PANTRY_DIRECT'
      then v_evaluation.pantry_need_approval_snapshot_id end,
    item.pantry_line_id, item.pantry_active_line_id,
    item.replacement_predecessor_selection_id,
    item.replacement_successor_selection_id
  from pg_catalog.jsonb_to_recordset(v_lines) as item(
    id uuid, family text, selection_id uuid, use_id uuid,
    menu_snapshot_line_id uuid, menu_line_id uuid,
    attendance_snapshot_line_id uuid, attendance_line_id uuid,
    school_id uuid, service_date date, dish_id uuid, recipe_id uuid,
    recipe_version_id uuid, recipe_line_id uuid,
    recipe_line_revision_id uuid, ingredient_id uuid, unit_id uuid,
    predecessor_run_id uuid, predecessor_line_id uuid,
    disposition text, quantity numeric(20, 6), delivery_location_id uuid,
    pantry_line_id uuid, pantry_active_line_id uuid,
    replacement_predecessor_selection_id uuid,
    replacement_successor_selection_id uuid
  );

  insert into atlas_planning.need_generation_issues (
    need_generation_issue_id, need_generation_run_id,
    theoretical_need_line_id, severity, issue_code, message,
    weekly_menu_approval_snapshot_line_id,
    attendance_approval_snapshot_line_id, school_id, service_date,
    dish_id, recipe_id, recipe_line_id, ingredient_id, unit_id, created_at,
    pantry_need_approval_snapshot_id, pantry_need_line_id,
    pantry_active_snapshot_member_line_id
  )
  select item.id, v_run_id, item.theoretical_line_id,
    item.severity, item.code, item.message, item.menu_snapshot_line_id,
    item.attendance_snapshot_line_id, item.school_id, item.service_date,
    item.dish_id, item.recipe_id, item.recipe_line_id,
    item.ingredient_id, item.unit_id, v_now, item.pantry_snapshot_id,
    item.pantry_line_id, item.pantry_active_line_id
  from pg_catalog.jsonb_to_recordset(v_issues) as item(
    id uuid, theoretical_line_id uuid, severity text, code text,
    message text, menu_snapshot_line_id uuid,
    attendance_snapshot_line_id uuid, school_id uuid, service_date date,
    dish_id uuid, recipe_id uuid, recipe_line_id uuid,
    ingredient_id uuid, unit_id uuid, pantry_snapshot_id uuid,
    pantry_line_id uuid, pantry_active_line_id uuid
  );

  set constraints all immediate;
  set constraints all deferred;

  v_before := pg_catalog.jsonb_build_object(
    'planning_input_evaluation_id', v_evaluation_id,
    'evaluation_version', v_evaluation.evaluation_version,
    'terminal_need_generation_run_id', v_terminal.need_generation_run_id
  );
  v_after := pg_catalog.jsonb_build_object(
    'need_generation_run_id', v_run_id,
    'attempt_ordinal', v_attempt, 'status', 'GENERATED', 'version', 1,
    'generated_line_count', v_line_count,
    'blocking_issue_count', v_blocker_count,
    'warning_count', v_warning_count
  );
  return atlas_core.rmvp_04_success(
    request, v_actor_id, v_receipt_id, 'NeedGenerationCreated',
    v_run_id, null, 1, 'Need Generation was created from exact approved inputs.',
    v_before, v_after
  );
exception when serialization_failure or deadlock_detected then
  return atlas_core.rmvp_04_error(
    request, v_name, 'RETRYABLE_CONCURRENCY_FAILURE',
    'Need Generation evidence is being updated. Retry the exact unchanged request.',
    false, true
  );
when others then
  return atlas_core.rmvp_04_error(
    request, v_name, 'INVARIANT_VIOLATION',
    'Need Generation could not be created safely.'
  );
end;
$$;

alter function atlas_api.create_need_generation_run(jsonb)
  owner to atlas_need_generation_runtime;

comment on function atlas_api.create_need_generation_run(jsonb) is
  'RMVP-04.v1 create: exact approved sources, atomic Recipe/Pantry lineage, and PLANNING-CONTRACT-02A governed Recipe replacement removals.';

revoke create on schema atlas_core, atlas_api from atlas_need_generation_runtime;
revoke atlas_need_generation_runtime from postgres;
